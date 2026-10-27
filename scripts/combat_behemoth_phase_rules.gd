class_name CombatBehemothPhaseRules
extends RefCounted
## Deterministic validator and phase selector for Patchwork Behemoth (M05).
## Pure rules evaluation: scene-free, consumes NO RNG, mutates no source records,
## and returns an explicit detached {ok, phase, intent} specification.

const BOSS_ID := "patchwork_behemoth"
const BOSS_MAX_HP := 84
const PHASE_TWO_THRESHOLD := 21
const PHASE_ONE := 1
const PHASE_TWO := 2
const PHASE_TWO_PATH := "res://data/enemies/m05_behemoth_phase_two.json"

var _boss_definition: Variant = null
var _phase_two_record: Variant = null


func _init(boss_definition: Variant = null, phase_two_record: Variant = null) -> void:
	if boss_definition != null:
		_boss_definition = boss_definition.duplicate(true) if (boss_definition is Dictionary or boss_definition is Array) else boss_definition
	if phase_two_record != null:
		_phase_two_record = phase_two_record.duplicate(true) if (phase_two_record is Dictionary or phase_two_record is Array) else phase_two_record


## Main public selector. Evaluates detached boss definition, current integer HP,
## and parsed phase-two record. Returns explicit detached {ok, phase, intent}.
static func select_phase(boss_definition: Variant, current_hp: Variant, phase_two_record: Variant, tier: int = 0) -> Dictionary:
	if not validate_boss_definition(boss_definition):
		return {"ok": false, "phase": 0, "intent": {}}
	if not validate_phase_two_record(phase_two_record):
		return {"ok": false, "phase": 0, "intent": {}}
	if typeof(current_hp) != TYPE_INT:
		return {"ok": false, "phase": 0, "intent": {}}
	var hp := int(current_hp)
	if tier not in [0, 1, 2]:
		return {"ok": false, "phase": 0, "intent": {}}
	var modifiers := RunDifficulty.new().modifiers_for_tier(tier)
	var maximum := BOSS_MAX_HP + int(ceil(BOSS_MAX_HP * modifiers.max_hp_percent_bonus / 100.0))
	if hp < 1 or hp > maximum:
		return {"ok": false, "phase": 0, "intent": {}}

	if hp > PHASE_TWO_THRESHOLD:
		var boss := _extract_boss_dict(boss_definition)
		var intent: Dictionary = boss["intent"].duplicate(true)
		_normalize_intent_numbers(intent)
		intent = RunDifficulty.scale_intent(intent, modifiers.attack_intent_bonus)
		return {
			"ok": true,
			"phase": PHASE_ONE,
			"intent": intent
		}
	else:
		var p2 := _extract_phase_two_dict(phase_two_record)
		var intent: Dictionary = p2["intent"].duplicate(true)
		_normalize_intent_numbers(intent)
		intent = RunDifficulty.scale_intent(intent, modifiers.attack_intent_bonus)
		return {
			"ok": true,
			"phase": PHASE_TWO,
			"intent": intent
		}


## Aliases for select_phase
static func select(boss_definition: Variant, current_hp: Variant, phase_two_record: Variant) -> Dictionary:
	return select_phase(boss_definition, current_hp, phase_two_record)


static func evaluate(boss_definition: Variant, current_hp: Variant, phase_two_record: Variant) -> Dictionary:
	return select_phase(boss_definition, current_hp, phase_two_record)


static func project(boss_definition: Variant, current_hp: Variant, phase_two_record: Variant) -> Dictionary:
	return select_phase(boss_definition, current_hp, phase_two_record)


static func select_intent(boss_definition: Variant, current_hp: Variant, phase_two_record: Variant) -> Dictionary:
	return select_phase(boss_definition, current_hp, phase_two_record)


## Instance helper for bound rules
func select_for_hp(hp: Variant) -> Dictionary:
	return select_phase(_boss_definition, hp, _phase_two_record)


## Validates that a boss record or catalog contains the exact valid Patchwork Behemoth phase-one definition.
static func validate_boss_definition(boss_definition: Variant) -> bool:
	var boss := _extract_boss_dict(boss_definition)
	if boss.is_empty():
		return false
	if boss.get("id") != BOSS_ID:
		return false
	var max_hp = boss.get("max_hp")
	if not _is_exact_int(max_hp) or int(max_hp) != BOSS_MAX_HP:
		return false
	var intent = boss.get("intent")
	if not intent is Dictionary:
		return false
	var target = intent.get("target")
	if target != "front" or not CombatEnemyIntents.TARGET_POLICIES.has(target):
		return false
	var actions = intent.get("actions")
	if not actions is Array or actions.size() != 3:
		return false
	return _validate_phase_actions(actions, 34, 3, 1)


## Validates that a phase-two record contains the exact valid Patchwork Behemoth phase-two schema.
static func validate_phase_two_record(phase_two_record: Variant) -> bool:
	var record := _extract_phase_two_dict(phase_two_record)
	if record.is_empty():
		return false
	if record.get("boss_id") != BOSS_ID:
		return false
	var phase = record.get("phase")
	if not _is_exact_int(phase) or int(phase) != PHASE_TWO:
		return false
	var threshold = record.get("threshold_hp")
	if not _is_exact_int(threshold) or int(threshold) != PHASE_TWO_THRESHOLD:
		return false
	var intent = record.get("intent")
	if not intent is Dictionary:
		return false
	var target = intent.get("target")
	if target != "lowest_living_hp" or not CombatEnemyIntents.TARGET_POLICIES.has(target):
		return false
	var actions = intent.get("actions")
	if not actions is Array or actions.size() != 3:
		return false
	return _validate_phase_actions(actions, 40, 3, 1)


static func _extract_boss_dict(boss_input: Variant) -> Dictionary:
	if boss_input is Dictionary:
		return boss_input
	if boss_input is Array:
		var found: Dictionary = {}
		for item in boss_input:
			if item is Dictionary and item.get("id") == BOSS_ID:
				if not found.is_empty():
					return {}
				found = item
		return found
	return {}


static func _extract_phase_two_dict(p2_input: Variant) -> Dictionary:
	if p2_input is Dictionary:
		return p2_input
	if p2_input is Array:
		var found: Dictionary = {}
		for item in p2_input:
			if item is Dictionary and item.get("boss_id") == BOSS_ID:
				if not found.is_empty():
					return {}
				found = item
		return found
	return {}


static func _is_exact_int(val: Variant) -> bool:
	if val is int:
		return true
	if val is float and is_finite(val) and floorf(val) == val and absf(val) <= 9007199254740991.0:
		return true
	return false


static func _validate_phase_actions(actions: Array, expected_attack: int, expected_block: int, expected_weak: int) -> bool:
	if actions.size() != 3:
		return false
	var has_attack := false
	var has_block := false
	var has_weak := false
	for raw in actions:
		var weighted := CombatEnemyIntents.weighted_action(raw)
		if weighted.is_empty():
			return false
		if not raw is Dictionary or not raw.has("weight"):
			return false
		var weight = raw["weight"]
		if typeof(weight) == TYPE_FLOAT and floorf(weight) != weight:
			return false
		var int_weight := int(weighted.get("weight", 0))
		var action: Dictionary = weighted.get("action", {})
		var type = action.get("type")
		var amount = action.get("amount")
		if type == "attack":
			if has_attack or int_weight != 4 or amount != expected_attack:
				return false
			has_attack = true
		elif type == "block":
			if has_block or int_weight != 2 or amount != expected_block:
				return false
			has_block = true
		elif type == "debuff":
			if has_weak or int_weight != 1 or amount != expected_weak or action.get("status") != "weak":
				return false
			has_weak = true
		else:
			return false
	return has_attack and has_block and has_weak


static func _normalize_intent_numbers(intent: Dictionary) -> void:
	var actions = intent.get("actions")
	if actions is Array:
		for action in actions:
			if action is Dictionary:
				if action.has("amount") and (action["amount"] is float or action["amount"] is int):
					action["amount"] = int(action["amount"])
				if action.has("weight") and (action["weight"] is float or action["weight"] is int):
					action["weight"] = int(action["weight"])
