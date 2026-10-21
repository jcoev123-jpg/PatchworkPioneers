class_name CombatPatchAttackRules
extends RefCounted
## A single battle's detached wearer projection. No mutation of run ledgers.
## Only the two documented, authored M04 powers are recognized.

const CATALOG := "res://data/patches/m04_attack_patches.json"
const EFFECTS := {
	"button_eye": {"slot": "HEAD", "effect": "first_attack_exposed", "amount": 1},
	"pincushion_arm": {"slot": "ARM", "effect": "card_attack_bonus", "amount": 1}
}

var _valid := false
var _active: Dictionary = {}
var _consumed: Dictionary = {}


func bind_wardrobe(wardrobe: RunPatchWardrobe, torn: RunTornMending) -> bool:
	_valid = false
	_active.clear()
	_consumed.clear()
	if wardrobe == null or torn == null or not wardrobe.is_valid() or not torn.is_valid():
		return false
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if not _valid_catalog(catalog):
		return false
	var state := wardrobe.get_snapshot()
	var torn_state := torn.read_state()
	var projection := wardrobe.project_active(torn_state)
	if not _valid_projection(state, torn_state, projection):
		return false
	_active = projection["active"].duplicate(true)
	for owner in RunPatchWardrobe.HERO_IDS:
		_consumed[owner] = false
	_valid = true
	return true


func is_valid() -> bool:
	return _valid


func active_snapshot() -> Dictionary:
	return _active.duplicate(true)


func latch_snapshot() -> Dictionary:
	return _consumed.duplicate(true)


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


func _valid_catalog(raw: Variant) -> bool:
	if typeof(raw) != TYPE_ARRAY or raw.size() != EFFECTS.size():
		return false
	var seen := {}
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY or entry.size() != 4:
			return false
		var id: Variant = entry.get("id")
		if typeof(id) != TYPE_STRING or not EFFECTS.has(id) or seen.has(id):
			return false
		var expected: Dictionary = EFFECTS[id]
		for key in expected:
			if not entry.has(key) or entry[key] != expected[key]:
				return false
			# JSON.parse_string decodes JSON numbers as floating-point values.
			if key == "amount":
				if typeof(entry[key]) not in [TYPE_FLOAT, TYPE_INT]:
					return false
			elif typeof(entry[key]) != typeof(expected[key]):
				return false
		seen[id] = true
	return seen.size() == EFFECTS.size()


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
		if definitions.get(id) != EFFECTS[id]["slot"]:
			return false
	var seen := {}
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
			if not owned.has(id) or definitions.get(id) != slot:
				return false
			if hero.get("hp", 0) > 0:
				expected_active.append(id)
		if projected != expected_active:
			return false
	return seen.size() == RunPatchWardrobe.HERO_IDS.size()
