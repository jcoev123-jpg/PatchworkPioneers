extends RefCounted
## Preserve exact historical enemy identity/HP/Block/art comparisons while
## independently requiring executable weighted intent metadata on every source.
const POLICIES := ["front", "lowest_living_hp", "exposed", "random"]


static func _valid_intent(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 2:
		return false
	if not value.get("target") is String or not value["target"] in POLICIES:
		return false
	var actions = value.get("actions")
	if not actions is Array or actions.is_empty():
		return false
	for action in actions:
		if CombatEnemyIntents.weighted_action(action).is_empty():
			return false
	return true


static func project(value: Variant) -> Variant:
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(project(item))
		return result
	if value is Dictionary:
		var record: Dictionary = value.duplicate(true)
		if record.has("id") and record.has("max_hp") and record.has("name"):
			if not _valid_intent(record.get("intent")):
				return {"invalid_weighted_enemy": record.get("id")}
			record.erase("intent")
			# S5 appends an authored "stitched" profile beside the legacy card record.
			# This helper protects the historical identity/HP/Block/art fields those
			# tests assert; tests/stitched_s5_enemy_catalog_test.gd owns the profile.
			record.erase("stitched")
		return record
	return value


static func _normalize(value: Variant) -> Variant:
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_normalize(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[key] = _normalize(value[key])
		return result
	if value is float and is_finite(value) and floorf(value) == value:
		return int(value)
	return value


static func same(actual: Variant, expected: Variant) -> bool:
	return _normalize(project(actual)) == _normalize(project(expected))
