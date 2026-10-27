class_name RunDifficulty
extends RefCounted
## Scene-independent tier selection/unlock state service for P9 Steeper Quilt.
## Reads res://data/difficulty/quilt_tiers.json; never edits it.
## State contract: selected_tier (default 0), highest_cleared_tier (default -1).

const TIERS_PATH := "res://data/difficulty/quilt_tiers.json"

var _selected_tier: int = 0
var _highest_cleared_tier: int = -1
var _catalog: Dictionary = {}

func _init() -> void:
	_load_catalog()


func _load_catalog() -> void:
	var raw := FileAccess.get_file_as_string(TIERS_PATH)
	if raw.is_empty():
		_catalog = {}
		return
	var parser := JSON.new()
	if parser.parse(raw) != OK:
		_catalog = {}
		return
	if parser.data is Dictionary:
		_catalog = parser.data


func _tier_records() -> Array:
	var tiers: Variant = _catalog.get("tiers")
	if tiers is Array:
		return tiers
	return []


func _find_tier_record(tier_id: int) -> Dictionary:
	for raw: Variant in _tier_records():
		if raw is Dictionary:
			var t: Variant = raw.get("tier")
			if _is_integer_number(t) and int(t) == tier_id:
				return raw
	return {}


func _is_integer_number(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_finite(value) and floor(value) == value
	return false


## The highest tier id the shipped catalog authors, or -1 if the catalog is empty.
func _max_authored_tier() -> int:
	var max_tier := -1
	for raw: Variant in _tier_records():
		if not raw is Dictionary:
			continue
		var tier_value: Variant = (raw as Dictionary).get("tier")
		if not _is_integer_number(tier_value):
			continue
		var tier_id := int(tier_value)
		if tier_id > max_tier:
			max_tier = tier_id
	return max_tier


func get_state() -> Dictionary:
	return {
		"highest_cleared_tier": _highest_cleared_tier,
		"selected_tier": _selected_tier,
	}


func get_available_tiers() -> Array[int]:
	var available: Array[int] = []
	for raw: Variant in _tier_records():
		if not raw is Dictionary:
			continue
		var tier_value: Variant = raw.get("tier")
		if not _is_integer_number(tier_value):
			continue
		var tier_id := int(tier_value)
		if tier_id < 0:
			continue
		var requires: Variant = raw.get("requires_cleared_tier")
		var unlocked := false
		if tier_id == 0:
			unlocked = true
		else:
			if _is_integer_number(requires) and int(requires) == tier_id - 1 and _highest_cleared_tier >= int(requires):
				unlocked = true
		if unlocked:
			available.append(tier_id)
	# Sort numerically; the authored data is 0,1,2.
	available.sort()
	return available


func get_selected_tier() -> int:
	return _selected_tier


func get_highest_cleared_tier() -> int:
	return _highest_cleared_tier


func get_modifiers() -> Dictionary:
	return modifiers_for_tier(_selected_tier)


func modifiers_for_tier(tier: int) -> Dictionary:
	var record := _find_tier_record(tier)
	if record.is_empty():
		return {"max_hp_percent_bonus": 0, "attack_intent_bonus": 0}
	var hp_bonus: Variant = record.get("max_hp_percent_bonus")
	var intent_bonus: Variant = record.get("attack_intent_bonus")
	var hp_int := 0
	var intent_int := 0
	if _is_integer_number(hp_bonus):
		hp_int = int(hp_bonus)
	if _is_integer_number(intent_bonus):
		intent_int = int(intent_bonus)
	return {
		"max_hp_percent_bonus": hp_int,
		"attack_intent_bonus": intent_int,
	}


## Detached fresh-entry transformation. Call once after floor scaling, before
## binding intents. It never touches RNG, the source definitions or actor state.
func scale_definitions(definitions: Array) -> Array:
	var scaled := definitions.duplicate(true)
	if _selected_tier == 0:
		return scaled
	var modifiers := get_modifiers()
	for definition in scaled:
		definition.max_hp += int(ceil(definition.max_hp * modifiers.max_hp_percent_bonus / 100.0))
		definition.intent = scale_intent(definition.intent, modifiers.attack_intent_bonus)
	return scaled


static func scale_intent(intent: Dictionary, bonus: int) -> Dictionary:
	var scaled := intent.duplicate(true)
	if bonus == 0:
		return scaled
	for action in scaled.actions:
		if action.get("type") == "attack":
			action.amount = int(action.amount) + bonus
	return scaled


func select_tier(tier: Variant) -> bool:
	if not _is_integer_number(tier):
		return false
	# Only valid tiers from the catalog.
	if tier < 0:
		return false
	# Must exist in catalog and be unlocked.
	var record := _find_tier_record(tier)
	if record.is_empty():
		return false
	if not get_available_tiers().has(tier):
		return false
	_selected_tier = tier
	return true


func complete_run(won: bool) -> bool:
	# Only trusted caller may issue; we only apply to the currently selected tier.
	if _selected_tier < 0:
		return false
	if not won:
		# Losses do not advance unlocks or alter selection.
		return true
	# Win advances the ceiling but never skips a predecessor (highest is a max).
	if _selected_tier > _highest_cleared_tier:
		_highest_cleared_tier = _selected_tier
	return true


func restore_state(state: Variant) -> bool:
	if not state is Dictionary:
		return false
	# Must contain exactly the two contract fields; extra fields rejected to stay atomic.
	if state.has("highest_cleared_tier") and state.has("selected_tier"):
		# Check for extra unexpected keys.
		var expected_keys := ["highest_cleared_tier", "selected_tier"]
		for key: Variant in state.keys():
			if not expected_keys.has(key):
				return false
	else:
		return false

	var highest: Variant = state.get("highest_cleared_tier")
	var selected: Variant = state.get("selected_tier")

	if not _is_integer_number(highest) or not _is_integer_number(selected):
		return false

	var highest_int := int(highest)
	var selected_int := int(selected)

	# Range checks: -1 (no victory yet) through the authored tier ceiling of 2.
	if highest_int < -1:
		return false
	var max_tier := _max_authored_tier()
	if max_tier < 0:
		return false
	if highest_int > max_tier:
		return false
	if selected_int < 0 or selected_int > max_tier:
		return false

	# The selected tier must exist in the catalog and be earned/available.
	var selected_record := _find_tier_record(selected_int)
	if selected_record.is_empty():
		return false

	# For tier > 0, selected tier's predecessor must be cleared (i.e., highest_cleared_tier >= selected - 1).
	# Also preserve lower-tier selection after later wins: selected may be lower than highest.
	if selected_int > 0:
		if not _is_integer_number(selected_record.get("requires_cleared_tier")):
			return false
		var requires_int := int(selected_record.get("requires_cleared_tier"))
		if requires_int != selected_int - 1:
			return false
		if highest_int < requires_int:
			return false
	else:
		# Tier 0 requires cleared predecessor null; highest can be -1 or >= 0.
		var tier0_requires: Variant = selected_record.get("requires_cleared_tier")
		if tier0_requires != null:
			return false

	# If selected > 0 and there are no records above it, still allow if unlocked.
	# The unlocked check is covered by highest >= requires.

	# Apply atomically.
	_highest_cleared_tier = highest_int
	_selected_tier = selected_int
	return true
