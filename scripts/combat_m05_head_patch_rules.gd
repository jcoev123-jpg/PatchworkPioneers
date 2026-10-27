class_name CombatM05HeadPatchRules
extends RefCounted
## Read-only M05 wearer-only HEAD modifiers. This is NOT a card executor.
## Bind the genuine wardrobe and torn ledger after every sew, re-sew, battle,
## mend or Rest change. A stale binding always returns zero until re-bound.
## get_bonus(wearer_id, ORIGINAL authored card_id, effect_key) returns only
## the extra integer for ONE positive authored bleed/exposed/weak/block effect.
## The eventual confirmed-play adapter must add it ONCE at the original
## effect's recipient (including an ally for block); previews must not commit.
## This layer never touches cards, statuses, HP, Block, currency or run RNG.

const CATALOG_PATH := "res://data/patches/m05_head_patches.json"
const SLOTS := ["HEAD", "ARM", "COAT"]
const HERO_IDS := ["warden", "seamstress", "tinker"]
const REQUIRED := {
	"bloodstitch_bonnet": {"slot": "HEAD", "effect": "card_bleed_bonus", "amount": 1},
	"button_glass_visor": {"slot": "HEAD", "effect": "card_exposed_bonus", "amount": 1},
	"stern_seam_cap": {"slot": "HEAD", "effect": "card_weak_bonus", "amount": 1},
	"reinforced_browband": {"slot": "HEAD", "effect": "card_block_bonus", "amount": 2},
}
const EFFECT_KEYS := {
	"bleed": "card_bleed_bonus",
	"exposed": "card_exposed_bonus",
	"weak": "card_weak_bonus",
	"block": "card_block_bonus",
}

var _wardrobe: RunPatchWardrobe = null
var _torn: RunTornMending = null
var _wardrobe_snapshot: Dictionary = {}
var _torn_snapshot: Dictionary = {}
var _heads: Dictionary = {}


## Fails closed and clears any previous binding, even on a failed rebind.
## Uses wardrobe.project_active(torn.read_state()) for actual living wearers.
func bind_wardrobe(wardrobe: RunPatchWardrobe, torn: RunTornMending) -> bool:
	_clear()
	if wardrobe == null or torn == null or not wardrobe.is_valid() or not torn.is_valid():
		return false
	if not _catalog_is_authored():
		return false
	var ws: Dictionary = wardrobe.get_snapshot()
	var ts: Dictionary = torn.read_state()
	if ws.get("valid") != true or ts.get("ok") != true:
		return false
	if ws.get("heroes") != ts.get("heroes"):
		return false
	var heroes: Variant = ts.get("heroes")
	var owned: Variant = ws.get("owned")
	var definitions: Variant = ws.get("definitions")
	var worn: Variant = ws.get("worn")
	if typeof(heroes) != TYPE_ARRAY or heroes.size() != HERO_IDS.size() 			or typeof(owned) != TYPE_ARRAY or typeof(definitions) != TYPE_DICTIONARY 			or typeof(worn) != TYPE_DICTIONARY or worn.size() != HERO_IDS.size():
		return false
	var projection: Dictionary = wardrobe.project_active(ts)
	if projection.get("ok") != true or projection.get("worn") != worn:
		return false
	var active: Variant = projection.get("active")
	if typeof(active) != TYPE_DICTIONARY or active.size() != HERO_IDS.size():
		return false

	var seen := {}
	var next_heads := {}
	for hero in heroes:
		if typeof(hero) != TYPE_DICTIONARY:
			return false
		var hero_id: Variant = hero.get("id")
		if typeof(hero_id) != TYPE_STRING or not RunV3PartyAdmission.HERO_IDS.has(hero_id):
			return false
		var slots: Variant = worn.get(hero_id)
		if typeof(slots) != TYPE_DICTIONARY or slots.size() != SLOTS.size():
			return false
		var projected: Variant = active.get(hero_id)
		if typeof(projected) != TYPE_ARRAY:
			return false
		var expected_active := []
		for slot in SLOTS:
			var patch_id: Variant = slots.get(slot)
			if typeof(patch_id) != TYPE_STRING:
				return false
			if patch_id == "":
				continue
			if seen.has(patch_id) or not owned.has(patch_id) 					or definitions.get(patch_id) != slot:
				return false
			seen[patch_id] = true
			# M05 named IDs cannot masquerade as another slot.
			if REQUIRED.has(patch_id) and slot != "HEAD":
				return false
			if hero["hp"] > 0:
				expected_active.append(patch_id)
		if projected != expected_active:
			return false
		var head_id: String = slots["HEAD"]
		if hero["hp"] > 0 and REQUIRED.has(head_id) and projected.has(head_id):
			next_heads[hero_id] = {
				"patch_id": head_id,
				"effect": REQUIRED[head_id]["effect"],
				"amount": REQUIRED[head_id]["amount"],
			}
		else:
			next_heads[hero_id] = {}
	_wardrobe = wardrobe
	_torn = torn
	_wardrobe_snapshot = ws.duplicate(true)
	_torn_snapshot = ts.duplicate(true)
	_heads = next_heads.duplicate(true)
	return true


## Detached, inspectable projection; invalid/stale bindings never leak bonuses.
func read_projection() -> Dictionary:
	if not _current():
		return {"ok": false, "heads": {}}
	return {"ok": true, "heads": _heads.duplicate(true)}


## Returns BONUS ONLY: never the combined effect or an awarded status/Block.
## No heuristic owner-prefix or plus-suffix recognition: all card IDs are
## looked up in the real starter and all three hero pool catalogs.
func get_bonus(wearer_id: Variant, card_id: Variant, effect_key: Variant) -> int:
	if not _current() or typeof(wearer_id) != TYPE_STRING 			or typeof(card_id) != TYPE_STRING or typeof(effect_key) != TYPE_STRING:
		return 0
	if not HERO_IDS.has(wearer_id) or not EFFECT_KEYS.has(effect_key):
		return 0
	var head: Dictionary = _heads.get(wearer_id, {})
	if head.get("effect") != EFFECT_KEYS[effect_key]:
		return 0
	var definition := _authored_definition(card_id)
	if definition.is_empty() or definition.get("id") != card_id 			or definition.get("owner") != wearer_id:
		return 0
	var effects: Variant = definition.get("effects")
	if typeof(effects) != TYPE_DICTIONARY:
		return 0
	var authored: Variant = effects.get(effect_key)
	if typeof(authored) != TYPE_INT or authored <= 0:
		return 0
	return int(head["amount"])


func _current() -> bool:
	return _wardrobe != null and _torn != null 		and _wardrobe.is_valid() and _torn.is_valid() 		and _wardrobe.get_snapshot() == _wardrobe_snapshot 		and _torn.read_state() == _torn_snapshot


func _clear() -> void:
	_wardrobe = null
	_torn = null
	_wardrobe_snapshot = {}
	_torn_snapshot = {}
	_heads = {}


static func _authored_definition(card_id: String) -> Dictionary:
	var starter := StarterCards.new()
	var definition := starter.get_definition(card_id)
	if not definition.is_empty():
		return definition
	for pool in [WardenPoolCards.new(), SeamstressPoolCards.new(), TinkerPoolCards.new()]:
		definition = pool.get_definition(card_id)
		if not definition.is_empty():
			return definition
	return {}


static func _catalog_is_authored() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if typeof(parsed) != TYPE_ARRAY or parsed.size() != REQUIRED.size():
		return false
	var seen := {}
	for entry in parsed:
		if typeof(entry) != TYPE_DICTIONARY or entry.size() != 4:
			return false
		var id: Variant = entry.get("id")
		if typeof(id) != TYPE_STRING or not REQUIRED.has(id) or seen.has(id):
			return false
		seen[id] = true
		var expected: Dictionary = REQUIRED[id]
		if entry.get("slot") != expected["slot"] or entry.get("effect") != expected["effect"]:
			return false
		var amount: Variant = entry.get("amount")
		if typeof(amount) != TYPE_INT and typeof(amount) != TYPE_FLOAT:
			return false
		if amount != expected["amount"]:
			return false
	return seen.size() == REQUIRED.size()
