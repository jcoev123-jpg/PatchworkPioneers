class_name CombatPatchAttackRules
extends RefCounted
## A single battle's detached wearer projection. No mutation of run ledgers.
## Authoritative M04 attack powers and M05 wearer-only ARM support patches.

const CATALOG := "res://data/patches/m04_attack_patches.json"
const EFFECTS := {
	"button_eye": {"slot": "HEAD", "effect": "first_attack_exposed", "amount": 1},
	"pincushion_arm": {"slot": "ARM", "effect": "card_attack_bonus", "amount": 1}
}

const SUPPORT_CATALOG := "res://data/patches/m05_arm_support_patches.json"
const SUPPORT_EFFECTS := {
	"hemguard_cuff": {"slot": "ARM", "effect": "card_block_bonus", "amount": 2},
	"red_bobbin_cuff": {"slot": "ARM", "effect": "card_bleed_bonus", "amount": 1},
	"loose_thread_glove": {"slot": "ARM", "effect": "card_unravel_bonus", "amount": 1},
	"threadguard_wrap": {"slot": "ARM", "effect": "card_block_bonus", "amount": 1}
}

var _valid := false
var _active: Dictionary = {}
var _consumed: Dictionary = {}
var _worn: Dictionary = {}
var _living: Dictionary = {}
var _wardrobe: RunPatchWardrobe = null
var _torn: RunTornMending = null
var _wardrobe_receipt: Dictionary = {}
var _torn_receipt: Dictionary = {}

var _starter_cards: StarterCards = null
var _warden_cards: WardenPoolCards = null
var _seamstress_cards: SeamstressPoolCards = null
var _tinker_cards: TinkerPoolCards = null


func _init() -> void:
	_starter_cards = StarterCards.new()
	_warden_cards = WardenPoolCards.new()
	_seamstress_cards = SeamstressPoolCards.new()
	_tinker_cards = TinkerPoolCards.new()


func bind_wardrobe(wardrobe: RunPatchWardrobe, torn: RunTornMending) -> bool:
	_valid = false
	_active.clear()
	_consumed.clear()
	_worn.clear()
	_living.clear()
	_wardrobe = null
	_torn = null
	_wardrobe_receipt.clear()
	_torn_receipt.clear()
	if wardrobe == null or torn == null or not wardrobe.is_valid() or not torn.is_valid():
		return false
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if not _valid_catalog(catalog):
		return false
	var support_catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(SUPPORT_CATALOG))
	if not _valid_support_catalog(support_catalog):
		return false
	var state := wardrobe.get_snapshot()
	var torn_state := torn.read_state()
	var projection := wardrobe.project_active(torn_state)
	if not _valid_projection(state, torn_state, projection):
		return false
	_active = projection["active"].duplicate(true)
	_worn = state.get("worn", {}).duplicate(true)
	for hero in torn_state.get("heroes", []):
		if typeof(hero) == TYPE_DICTIONARY and hero.has("id") and hero.has("hp"):
			_living[hero["id"]] = hero["hp"] > 0
	for owner in RunPatchWardrobe.HERO_IDS:
		_consumed[owner] = false
	_valid = true
	_wardrobe = wardrobe
	_torn = torn
	_wardrobe_receipt = state.duplicate(true)
	_torn_receipt = torn_state.duplicate(true)
	return true


func is_valid() -> bool:
	return _valid


## The frozen battle-start projection is only authoritative while the live
## run ledgers still carry the exact receipts it was bound to. A later sew,
## re-sew, refresh or torn-ledger change must fail closed, never replay the
## wearer powers that were active when the battle started.
func is_current() -> bool:
	if not _valid or _wardrobe == null or _torn == null:
		return false
	return _wardrobe.get_snapshot() == _wardrobe_receipt \
		and _torn.read_state() == _torn_receipt


func active_snapshot() -> Dictionary:
	return _active.duplicate(true)


func latch_snapshot() -> Dictionary:
	return _consumed.duplicate(true)


func worn_snapshot() -> Dictionary:
	return _worn.duplicate(true)


func damage_bonus(owner: String) -> int:
	if not _valid:
		return 0
	return 1 if _active.get(owner, []).has("pincushion_arm") else 0


func exposed_for_first_hit(owner: String) -> Dictionary:
	if not _valid or _consumed.get(owner, true):
		return {}
	return {"exposed": 1} if _active.get(owner, []).has("button_eye") else {}


func record_successful_attack(owner: String) -> void:
	if _valid and _consumed.has(owner) and _active.get(owner, []).has("button_eye"):
		_consumed[owner] = true


func card_support_bonuses(owner_id: Variant, card_id: Variant) -> Dictionary:
	var detached_zero := {"block": 0, "bleed": 0, "unravel": 0}
	if not _valid:
		return detached_zero
	if typeof(owner_id) != TYPE_STRING or typeof(card_id) != TYPE_STRING:
		return detached_zero
	var owner: String = owner_id
	var card: String = card_id
	if not RunPatchWardrobe.HERO_IDS.has(owner):
		return detached_zero
	if not _living.get(owner, false):
		return detached_zero

	var active_arm: String = _worn.get(owner, {}).get("ARM", "")
	if active_arm.is_empty():
		return detached_zero
	var active_patches: Array = _active.get(owner, [])
	if not active_patches.has(active_arm):
		return detached_zero
	if not SUPPORT_EFFECTS.has(active_arm):
		return detached_zero

	var def := _get_canonical_card_definition(card)
	if def.is_empty():
		return detached_zero
	if def.get("owner") != owner:
		return detached_zero

	var effects: Variant = def.get("effects")
	if typeof(effects) != TYPE_DICTIONARY:
		return detached_zero

	var result := {"block": 0, "bleed": 0, "unravel": 0}
	match active_arm:
		# Hemguard Cuff (+2) and Threadguard Wrap (+1) are the same wearer-only
		# rule at different authored amounts; both never invent Block on a card
		# that does not already grant it.
		"hemguard_cuff", "threadguard_wrap":
			var val: Variant = effects.get("block")
			if (typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT) and int(val) > 0:
				result["block"] = SUPPORT_EFFECTS[active_arm]["amount"]
		"red_bobbin_cuff":
			var val: Variant = effects.get("bleed")
			if (typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT) and int(val) > 0:
				result["bleed"] = SUPPORT_EFFECTS["red_bobbin_cuff"]["amount"]
		"loose_thread_glove":
			var val: Variant = effects.get("unravel")
			if (typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT) and int(val) > 0:
				result["unravel"] = SUPPORT_EFFECTS["loose_thread_glove"]["amount"]

	return result


func card_block_bonus(owner_id: Variant, card_id: Variant) -> int:
	return int(card_support_bonuses(owner_id, card_id).get("block", 0))


func card_bleed_bonus(owner_id: Variant, card_id: Variant) -> int:
	return int(card_support_bonuses(owner_id, card_id).get("bleed", 0))


func card_unravel_bonus(owner_id: Variant, card_id: Variant) -> int:
	return int(card_support_bonuses(owner_id, card_id).get("unravel", 0))


func project_card_support(owner_id: Variant, card_id: Variant) -> Dictionary:
	if typeof(card_id) != TYPE_STRING:
		return {}
	var def := _get_canonical_card_definition(str(card_id))
	if def.is_empty() or def.get("owner") != owner_id:
		return {}
	var bonuses := card_support_bonuses(owner_id, card_id)
	var projected: Dictionary = def.get("effects", {}).duplicate(true)
	for key in bonuses:
		if bonuses[key] > 0 and projected.has(key):
			projected[key] += bonuses[key]
	return projected


func _get_canonical_card_definition(card_id: String) -> Dictionary:
	if _starter_cards == null:
		_starter_cards = StarterCards.new()
	if _warden_cards == null:
		_warden_cards = WardenPoolCards.new()
	if _seamstress_cards == null:
		_seamstress_cards = SeamstressPoolCards.new()
	if _tinker_cards == null:
		_tinker_cards = TinkerPoolCards.new()
	if _starter_cards.has_card(card_id):
		return _starter_cards.get_definition(card_id)
	if _warden_cards.has_card(card_id):
		return _warden_cards.get_definition(card_id)
	if _seamstress_cards.has_card(card_id):
		return _seamstress_cards.get_definition(card_id)
	if _tinker_cards.has_card(card_id):
		return _tinker_cards.get_definition(card_id)
	return {}


func _valid_catalog(raw: Variant) -> bool:
	if typeof(raw) != TYPE_ARRAY:
		return false
	var seen := {}
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			return false
		var id: Variant = entry.get("id")
		if typeof(id) != TYPE_STRING or id.is_empty() or id != id.strip_edges() or seen.has(id):
			return false
		seen[id] = true
		# Other services own additional catalog powers; validate our required
		# entries exactly without imposing a total on this shared catalog.
		if not EFFECTS.has(id):
			continue
		if entry.size() != 4:
			return false
		var expected: Dictionary = EFFECTS[id]
		for key in expected:
			if not entry.has(key):
				return false
			# JSON.parse_string decodes JSON numbers as floating-point values.
			if key == "amount":
				if typeof(entry[key]) not in [TYPE_FLOAT, TYPE_INT]:
					return false
			elif typeof(entry[key]) != typeof(expected[key]):
				return false
			if entry[key] != expected[key]:
				return false
	for id in EFFECTS:
		if not seen.has(id):
			return false
	return true


static func _valid_support_catalog(raw: Variant) -> bool:
	if typeof(raw) != TYPE_ARRAY:
		return false
	var seen := {}
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY or entry.size() != 4:
			return false
		var id: Variant = entry.get("id")
		if typeof(id) != TYPE_STRING:
			return false
		if not SUPPORT_EFFECTS.has(id):
			continue
		if seen.has(id):
			return false
		var expected: Dictionary = SUPPORT_EFFECTS[id]
		for key in expected:
			if not entry.has(key) or entry[key] != expected[key]:
				return false
			if key == "amount":
				if typeof(entry[key]) not in [TYPE_FLOAT, TYPE_INT]:
					return false
			elif typeof(entry[key]) != typeof(expected[key]):
				return false
		seen[id] = true
	for id in SUPPORT_EFFECTS:
		if not seen.has(id):
			return false
	return true


func _valid_projection(state: Dictionary, torn_state: Dictionary, projection: Dictionary) -> bool:
	if state.get("valid") != true or torn_state.get("ok") != true or projection.get("ok") != true:
		return false
	var definitions: Variant = state.get("definitions")
	var owned: Variant = state.get("owned")
	var worn: Variant = state.get("worn")
	var active: Variant = projection.get("active")
	var heroes: Variant = torn_state.get("heroes")
	if typeof(definitions) != TYPE_DICTIONARY or typeof(owned) != TYPE_ARRAY:
		return false
	if typeof(worn) != TYPE_DICTIONARY or typeof(active) != TYPE_DICTIONARY:
		return false
	if typeof(heroes) != TYPE_ARRAY or heroes.size() != RunPatchWardrobe.HERO_IDS.size():
		return false
	if worn.size() != RunPatchWardrobe.HERO_IDS.size() or active.size() != worn.size():
		return false
	for id in EFFECTS:
		if not definitions.has(id):
			if owned.has(id):
				return false
		elif definitions[id] != EFFECTS[id]["slot"]:
			return false
	for id in SUPPORT_EFFECTS:
		if not definitions.has(id):
			if owned.has(id):
				return false
		elif definitions[id] != SUPPORT_EFFECTS[id]["slot"]:
			return false
	var seen := {}
	var seen_worn := {}
	for hero in heroes:
		if typeof(hero) != TYPE_DICTIONARY:
			return false
		var owner: Variant = hero.get("id")
		if typeof(owner) != TYPE_STRING or not RunPatchWardrobe.HERO_IDS.has(owner) or seen.has(owner):
			return false
		seen[owner] = true
		var slots: Variant = worn.get(owner)
		var projected: Variant = active.get(owner)
		if typeof(slots) != TYPE_DICTIONARY or slots.size() != RunPatchWardrobe.SLOTS.size():
			return false
		if typeof(projected) != TYPE_ARRAY:
			return false
		var expected_active := []
		for slot in RunPatchWardrobe.SLOTS:
			var id: Variant = slots.get(slot)
			if typeof(id) != TYPE_STRING:
				return false
			if id == "":
				continue
			if not owned.has(id) or definitions.get(id) != slot or seen_worn.has(id):
				return false
			seen_worn[id] = true
			if hero.get("hp", 0) > 0:
				expected_active.append(id)
		if projected != expected_active:
			return false
	return seen.size() == RunPatchWardrobe.HERO_IDS.size()
