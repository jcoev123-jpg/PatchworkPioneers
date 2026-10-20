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
			if not action is Dictionary or not action.has("type") or not action.has("amount"):
				return
			var kind = action["type"]
			var amount = action["amount"]
			if not kind is String or not amount is int or amount < 0:
				return
			if kind == "attack":
				if action.size() != 3 or not action.has("target_position"):
					return
				var target = action["target_position"]
				if not target is int or target < 1 or target > 3:
					return
			elif kind == "block":
				# Block has no hero target; it is only announced here.
				if action.size() != 2:
					return
			else:
				return
		seen_positions.append(position)
		validated.append({"enemy_position": position, "pattern": pattern})
	_definitions = validated
	_valid = true


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
