class_name CombatEnemyIntents
extends RefCounted
## Selects announced fixed-cycle enemy actions; never resolves damage or Block.

var _definitions: Array[Dictionary] = []
var _turn_index := 0
var _valid := false


func _init(definitions: Array) -> void:
	# Validate the entire copied schedule before publishing any of it.
	if definitions.is_empty() or definitions.size() > 3:
		return
	var snapshot := definitions.duplicate(true)
	var seen_positions: Array[int] = []
	var validated: Array[Dictionary] = []
	for definition in snapshot:
		if not definition is Dictionary or definition.size() != 2:
			return
		if not definition.has("enemy_position") or not definition.has("pattern"):
			return
		var position = definition["enemy_position"]
		if not position is int or position < 1 or position > 3 or position in seen_positions:
			return
		var pattern = definition["pattern"]
		if not pattern is Array or pattern.is_empty():
			return
		for action in pattern:
			if not valid_action(action):
				return
		seen_positions.append(position)
		validated.append({"enemy_position": position, "pattern": pattern})
	_definitions = validated
	_valid = true


static func valid_action(action: Variant) -> bool:
	if not action is Dictionary:
		return false
	var kind = action.get("type")
	var amount = action.get("amount")
	if not kind is String or not amount is int or amount < 0:
		return false
	if kind in ["block", "buff"]:
		return action.size() == 2 and (kind == "block" or amount > 0)
	if kind not in ["attack", "shove", "debuff"]:
		return false
	var target = action.get("target_position")
	if not target is int or target < 1 or target > 3:
		return false
	if kind == "attack":
		return action.size() == 3
	if kind == "debuff":
		return action.size() == 4 and amount > 0 and action.get("status") is String \
			and action.status in ["bleed", "weak", "exposed"]
	var direction = action.get("direction")
	return action.size() == 4 and amount == 0 and direction is int \
		and direction in [-1, 1] and target + direction >= 1 and target + direction <= 3


func is_valid() -> bool:
	return _valid


func get_intents() -> Array[Dictionary]:
	var intents: Array[Dictionary] = []
	if not _valid:
		return intents
	for definition in _definitions:
		var pattern: Array = definition["pattern"]
		var action: Dictionary = pattern[_turn_index % pattern.size()].duplicate(true)
		action["enemy_position"] = definition["enemy_position"]
		intents.append(action)
	intents.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["enemy_position"] < b["enemy_position"])
	return intents.duplicate(true)


func advance_turn() -> bool:
	if not _valid:
		return false
	_turn_index += 1
	return true
