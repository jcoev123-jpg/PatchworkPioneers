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
const PHASE_ACTION_COUNT := 6
## The authored kit this validator authenticates: the original attack, Block
## and Weak plus the three weight-1 named attacks, in their authored order.
const PHASE_ONE_KIT := [
	{"weight": 4, "action": {"type": "attack", "amount": 34}},
	{"weight": 2, "action": {"type": "block", "amount": 3}},
	{"weight": 1, "action": {"type": "debuff", "amount": 1, "status": "weak"}},
	{"weight": 1, "action": {"type": "attack", "amount": 30, "move": "attack2"}},
	{"weight": 1, "action": {"type": "attack", "amount": 22, "hits": 2, "move": "attack3"}},
	{"weight": 1, "action": {"type": "attack", "amount": 38, "move": "attack4"}},
]
const PHASE_TWO_KIT := [
	{"weight": 4, "action": {"type": "attack", "amount": 40}},
	{"weight": 2, "action": {"type": "block", "amount": 3}},
	{"weight": 1, "action": {"type": "debuff", "amount": 1, "status": "weak"}},
	{"weight": 1, "action": {"type": "attack", "amount": 36, "move": "attack2"}},
	{"weight": 1, "action": {"type": "attack", "amount": 28, "hits": 2, "move": "attack3"}},
	{"weight": 1, "action": {"type": "attack", "amount": 44, "move": "attack4"}},
]

var _boss_definition: Variant = null
var _phase_two_record: Variant = null


func _init(boss_definition: Variant = null, phase_two_record: Variant = null) -> void:
	if boss_definition != null:
		_boss_definition = boss_definition.duplicate(true) if (boss_definition is Dictionary or boss_definition is Array) else boss_definition
	if phase_two_record != null:
		_phase_two_record = phase_two_record.duplicate(true) if (phase_two_record is Dictionary or phase_two_record is Array) else phase_two_record


## The authorized maximum for one earned Quilt tier: the authored 84 HP plus
## that tier's RunDifficulty max-HP bonus, which is exactly what
## RunDifficulty.scale_definitions() applies to the real Boss roster. -1 marks
## a tier this rule set does not authorize.
static func maximum_hp_for_tier(tier: int) -> int:
	if tier not in [0, 1, 2]:
		return -1
	var modifiers := RunDifficulty.new().modifiers_for_tier(tier)
	return BOSS_MAX_HP + int(ceil(BOSS_MAX_HP * modifiers.max_hp_percent_bonus / 100.0))


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
	var maximum := maximum_hp_for_tier(tier)
	var modifiers := RunDifficulty.new().modifiers_for_tier(tier)
	if maximum < 1 or hp < 1 or hp > maximum:
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
	if not actions is Array or actions.size() != PHASE_ACTION_COUNT:
		return false
	return _validate_phase_actions(actions, PHASE_ONE_KIT)


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
	if not actions is Array or actions.size() != PHASE_ACTION_COUNT:
		return false
	return _validate_phase_actions(actions, PHASE_TWO_KIT)


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


static func _validate_phase_actions(actions: Array, kit: Array) -> bool:
	if actions.size() != kit.size():
		return false
	# Compare the whole normalized alternative, so a forged amount, weight,
	# hits count, move key, status or invented key all fail closed.
	for index in range(actions.size()):
		if CombatEnemyIntents.weighted_action(actions[index]) != kit[index]:
			return false
	return true


static func _normalize_intent_numbers(intent: Dictionary) -> void:
	var actions = intent.get("actions")
	if actions is Array:
		for action in actions:
			if action is Dictionary:
				if action.has("amount") and (action["amount"] is float or action["amount"] is int):
					action["amount"] = int(action["amount"])
				if action.has("weight") and (action["weight"] is float or action["weight"] is int):
					action["weight"] = int(action["weight"])
