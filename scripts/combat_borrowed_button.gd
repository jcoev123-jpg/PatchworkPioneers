class_name CombatBorrowedButton
extends RefCounted
## Scene-free MPW P6 COAT power: Borrowed Button.
##
## Once per combat, after a DIFFERENT living hero's successfully committed card or
## authenticated stitched half actually restores at least 1 HP to the living, untorn
## wearer, the wearer gains exactly 3 Block.
##
## This is NOT a card executor and NOT a heal. Every HP change already happened in
## the real committed transaction; this helper only accepts the post-commit receipt
## that follows it, verifies that receipt against the authoritative CombatParty and
## then grants Block through CombatParty.gain_block. It never edits snapshots, HP,
## cards, statuses, inventories or RNG values and never generates a receipt identity.
##
## One instance is one combat. A new combat must bind a new instance, which re-arms
## the single latch. Owners are always canonical hero IDs, never positions, so a
## committed stitched play reports each authenticated half with that half's own
## owner instead of one anonymous composite card.

const CATALOG_PATH := "res://data/patches/m05_coat_patches.json"
const PATCH_ID := "borrowed_button"
const SLOT := "COAT"
const EFFECT := "other_hero_committed_heal_block"
const SLOTS := ["HEAD", "ARM", "COAT"]
## Exact authored contract from MILESTONES.md MPW P6; any other numbers, slot or
## effect mean no combat power is claimed at all.
const AUTHORED := {
	"slot": SLOT,
	"effect": EFFECT,
	"heal_threshold": 1,
	"block": 3,
	"uses_per_combat": 1,
}

var _party: CombatParty = null
var _wardrobe: RunPatchWardrobe = null
var _torn: RunTornMending = null
var _wardrobe_snapshot: Dictionary = {}
var _torn_snapshot: Dictionary = {}
var _heal_threshold := 0
var _block := 0
var _uses_per_combat := 0
var _receipts: Dictionary = {}
var _receipt_ids: Array[String] = []
var _awards := 0
var _wearer_id := ""
var _award_receipt_id := ""


## Opt-in binding for one combat. Fails closed and clears any previous binding,
## even on a failed rebind. The ledgers must agree with each other and the party
## must carry exactly those owners, in those positions, with those maximum HP.
func bind_combat(party: CombatParty, wardrobe: RunPatchWardrobe,
		torn: RunTornMending) -> bool:
	_clear()
	if party == null or wardrobe == null or torn == null:
		return false
	if not party.is_valid() or not wardrobe.is_valid() or not torn.is_valid():
		return false
	var authored: Dictionary = _read_catalog()
	if authored.is_empty():
		return false
	var state: Dictionary = wardrobe.get_snapshot()
	var torn_state: Dictionary = torn.read_state()
	if state.get("valid") != true or torn_state.get("ok") != true:
		return false
	if state.get("heroes") != torn_state.get("heroes"):
		return false
	var projection: Dictionary = wardrobe.project_active(torn_state)
	if projection.get("ok") != true or projection.get("worn") != state.get("worn"):
		return false
	var roster: Variant = torn_state.get("heroes")
	var worn: Variant = state.get("worn")
	var owned: Variant = state.get("owned")
	var definitions: Variant = state.get("definitions")
	if typeof(roster) != TYPE_ARRAY or roster.size() != CombatParty.PARTY_SIZE:
		return false
	if typeof(worn) != TYPE_DICTIONARY or typeof(owned) != TYPE_ARRAY \
			or typeof(definitions) != TYPE_DICTIONARY:
		return false
	var heroes: Array = party.get_heroes()
	if heroes.size() != CombatParty.PARTY_SIZE:
		return false
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = heroes[index]
		var ledger: Dictionary = roster[index]
		if hero.get("id") != ledger.get("id") or hero.get("position") != index + 1:
			return false
		if hero.get("max_hp") != ledger.get("max_hp"):
			return false
		# Every sewn ID must be owned and authored for the slot it occupies.
		var slots: Variant = worn.get(hero["id"])
		if typeof(slots) != TYPE_DICTIONARY or slots.size() != SLOTS.size():
			return false
		for slot in SLOTS:
			var patch_id: Variant = slots.get(slot)
			if typeof(patch_id) != TYPE_STRING:
				return false
			if patch_id == "":
				continue
			if not owned.has(patch_id) or definitions.get(patch_id) != slot:
				return false
	_party = party
	_wardrobe = wardrobe
	_torn = torn
	_wardrobe_snapshot = state
	_torn_snapshot = torn_state
	_heal_threshold = int(authored["heal_threshold"])
	_block = int(authored["block"])
	_uses_per_combat = int(authored["uses_per_combat"])
	return true


## Read-only award facts. `ok` reports whether the bound authorities are still the
## exact ones supplied at combat start; a Block that was already granted is never
## hidden by a stale binding afterwards.
func read_state() -> Dictionary:
	return {
		"ok": _current(),
		"patch_id": PATCH_ID,
		"awarded": _awards > 0,
		"awards": _awards,
		"block_awarded": _block * _awards,
		"wearer_id": _wearer_id,
		"receipt_id": _award_receipt_id,
		"receipts": _receipt_ids.duplicate(),
	}


## One post-commit notification for one committed heal or one authenticated stitched
## half. `healer_id` is that commit's own owner; a whole stitched card has no owner
## and is refused. `before_hp`/`after_hp` are the recipient's real HP around that
## commit and `after_hp` must still be the authoritative HP of that hero.
##
## Liveness is required on both sides of the heal in BOTH authorities: a hero torn
## at a previous battle end keeps 0 HP in RunTornMending even though the next
## CombatParty, built from the reduced-max-HP roster, admits that hero above 0 HP.
## Such a run-torn healer never pays, exactly like a downed one.
## Returns {ok, awarded, block, wearer_id, receipt_id, reason}; a refusal never
## changes the party, the ledgers, the deck or any RNG, and it can never pay later.
func notify_committed_heal(receipt_id: Variant, healer_id: Variant,
		healed_id: Variant, before_hp: Variant, after_hp: Variant) -> Dictionary:
	if not _current():
		return _result(false, false, 0, receipt_id, "invalid_binding")
	if not _valid_id(receipt_id):
		return _result(false, false, 0, receipt_id, "unknown_receipt")
	if _receipts.has(receipt_id):
		return _result(false, false, 0, receipt_id, "duplicate_receipt")
	# Fail closed: an observed receipt is burned even when it is refused, so a
	# replayed or "corrected" claim for the same commit can never pay afterwards.
	_receipts[receipt_id] = true
	_receipt_ids.append(receipt_id)
	if not _valid_id(healer_id) or _position_of(healer_id) == 0:
		return _result(false, false, 0, receipt_id, "unknown_healer")
	if not _valid_id(healed_id) or _position_of(healed_id) == 0:
		return _result(false, false, 0, receipt_id, "unknown_recipient")
	if healer_id == healed_id:
		return _result(false, false, 0, receipt_id, "self_heal")
	var healer_position := _position_of(healer_id)
	var healed_position := _position_of(healed_id)
	if _party.is_downed(healer_position):
		return _result(false, false, 0, receipt_id, "downed_healer")
	# A fresh battle party starts a run-torn hero above 0 HP, so seat liveness alone
	# is not proof: the bound run ledger must also report this precise healer alive.
	if _run_hero_hp(healer_id) <= 0:
		return _result(false, false, 0, receipt_id, "torn_healer")
	if _party.is_downed(healed_position):
		return _result(false, false, 0, receipt_id, "downed_recipient")
	if typeof(before_hp) != TYPE_INT or typeof(after_hp) != TYPE_INT:
		return _result(false, false, 0, receipt_id, "malformed_observation")
	var hero: Dictionary = _party.get_hero(healed_position)
	if after_hp != hero["hp"]:
		return _result(false, false, 0, receipt_id, "stale_observation")
	# True positive effective restoration only: overheal of 0, a full-HP recipient
	# and a forged backwards transition all pay nothing.
	if before_hp < 0 or after_hp > hero["max_hp"] or before_hp >= after_hp:
		return _result(false, false, 0, receipt_id, "no_effective_heal")
	if after_hp - before_hp < _heal_threshold:
		return _result(false, false, 0, receipt_id, "no_effective_heal")
	if not _wearer_is_active(healed_id):
		return _result(false, false, 0, receipt_id, "no_active_patch")
	if _awards >= _uses_per_combat:
		return _result(true, false, 0, receipt_id, "already_awarded")
	if _block > CombatParty.MAX_INT - int(hero["block"]):
		return _result(false, false, 0, receipt_id, "block_overflow")
	if not _party.gain_block(healed_position, _block):
		return _result(false, false, 0, receipt_id, "block_refused")
	_awards += 1
	_wearer_id = healed_id
	_award_receipt_id = receipt_id
	return _result(true, true, _block, receipt_id, "awarded")


func _wearer_is_active(wearer_id: String) -> bool:
	var state: Dictionary = _wardrobe.get_snapshot()
	var worn: Variant = state.get("worn")
	if typeof(worn) != TYPE_DICTIONARY or not worn.has(wearer_id):
		return false
	var slots: Variant = worn[wearer_id]
	if typeof(slots) != TYPE_DICTIONARY or slots.get(SLOT) != PATCH_ID:
		return false
	var owned: Variant = state.get("owned")
	var definitions: Variant = state.get("definitions")
	if typeof(owned) != TYPE_ARRAY or not owned.has(PATCH_ID):
		return false
	if typeof(definitions) != TYPE_DICTIONARY or definitions.get(PATCH_ID) != SLOT:
		return false
	var torn_state: Dictionary = _torn.read_state()
	var projection: Dictionary = _wardrobe.project_active(torn_state)
	if projection.get("ok") != true:
		return false
	var active: Variant = projection.get("active")
	if typeof(active) != TYPE_DICTIONARY:
		return false
	var equipped: Variant = active.get(wearer_id)
	if typeof(equipped) != TYPE_ARRAY or not equipped.has(PATCH_ID):
		return false
	return _run_hero_hp(wearer_id) > 0


## HP of this precise hero in the bound run ledger; a missing identity reads as 0.
func _run_hero_hp(hero_id: String) -> int:
	for hero: Variant in _torn.read_state().get("heroes", []):
		if typeof(hero) == TYPE_DICTIONARY and hero.get("id") == hero_id:
			return int(hero.get("hp", 0))
	return 0


func _position_of(hero_id: String) -> int:
	for hero: Dictionary in _party.get_heroes():
		if hero.get("id") == hero_id:
			return int(hero["position"])
	return 0


func _current() -> bool:
	return _party != null and _wardrobe != null and _torn != null \
		and _party.is_valid() and _wardrobe.is_valid() and _torn.is_valid() \
		and _wardrobe.get_snapshot() == _wardrobe_snapshot \
		and _torn.read_state() == _torn_snapshot


func _clear() -> void:
	_party = null
	_wardrobe = null
	_torn = null
	_wardrobe_snapshot = {}
	_torn_snapshot = {}
	_heal_threshold = 0
	_block = 0
	_uses_per_combat = 0
	_receipts = {}
	_receipt_ids = []
	_awards = 0
	_wearer_id = ""
	_award_receipt_id = ""


func _result(ok: bool, awarded: bool, block: int, receipt_id: Variant,
		reason: String) -> Dictionary:
	return {"ok": ok, "awarded": awarded, "block": block,
		"wearer_id": _wearer_id, "receipt_id": receipt_id, "reason": reason}


static func _valid_id(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not value.is_empty() \
		and value == value.strip_edges()


## The named M05 COAT record is read from the authored data, never hard-coded as
## a live value: exact slot, effect, threshold, Block and per-combat use, or {}.
static func _read_catalog() -> Dictionary:
	var source := FileAccess.get_file_as_string(CATALOG_PATH)
	if source.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(source)
	if typeof(parsed) != TYPE_ARRAY:
		return {}
	var found := {}
	for entry in parsed:
		if typeof(entry) != TYPE_DICTIONARY or entry.get("id") != PATCH_ID:
			continue
		if not found.is_empty():
			return {}
		if entry.get("slot") != AUTHORED["slot"] or entry.get("effect") != AUTHORED["effect"]:
			return {}
		var values := {}
		for field in ["heal_threshold", "block", "uses_per_combat"]:
			var value: Variant = entry.get(field)
			if not _integral(value) or value <= 0:
				return {}
			if int(value) != AUTHORED[field]:
				return {}
			values[field] = int(value)
		found = values
	return found


static func _integral(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and value == floor(value)
