class_name RunFightEncounterSelection
extends RefCounted
## One selector per run, supplied with the SAME seeded RNG used to generate its
## RunMap. The caller must first use RunMap.choose_node() on a legal node.
## The service does not launch combat; the caller creates CombatEnemyIntents
## from result["definitions"] when entering battle.
##
## select_current_fight(map, run_rng, encounter_paths) retains its exact
## {"success": true, "encounter_id": String, "definitions": Array} contract.
## select_current_battle(map, run_rng, pools_by_type) accepts independent
## Fight/Elite/Boss pools and additionally returns "node_type" on success.
## Both reject with {"success": false}; all success results are deep copies.
## A successful current node is cached across both entry points, with no
## further RNG draws. Create a NEW selector and map for a new run;
## regenerating a bound map is not a supported way to start another run.

var _bound_map: RunMap = null
var _selected: Dictionary = {}


func select_current_fight(
		map: RunMap, run_rng: RandomNumberGenerator,
		encounter_paths: Dictionary) -> Dictionary:
	var choice := _select_current_kind(map, run_rng, encounter_paths, "Fight")
	if choice.get("success", false):
		# The legacy API deliberately does not acquire an extra result key.
		choice.erase("node_type")
	return choice


func select_current_battle(
		map: RunMap, run_rng: RandomNumberGenerator,
		pools_by_type: Dictionary) -> Dictionary:
	if map == null or run_rng == null or not map.is_generated():
		return {"success": false}
	if _bound_map != null and map != _bound_map:
		return {"success": false}
	var current_id: String = map.get_current_node_id()
	if current_id.is_empty() or not map.get_route().has(current_id):
		return {"success": false}
	var node: Dictionary = map.get_node(current_id)
	var kind = node.get("type")
	if not kind is String or not kind in ["Fight", "Elite", "Boss"]:
		return {"success": false}
	# Require the chosen kind's pool but never inspect another kind's pool.
	if not pools_by_type.has(kind) or not pools_by_type[kind] is Dictionary:
		return {"success": false}
	return _select_current_kind(map, run_rng, pools_by_type[kind], kind)


func _select_current_kind(
		map: RunMap, run_rng: RandomNumberGenerator,
		encounter_paths: Dictionary, kind: String) -> Dictionary:
	if map == null or run_rng == null or not map.is_generated():
		return {"success": false}
	if _bound_map != null and map != _bound_map:
		return {"success": false}
	var current_id: String = map.get_current_node_id()
	if current_id.is_empty() or not map.get_route().has(current_id):
		return {"success": false}
	var node: Dictionary = map.get_node(current_id)
	if node.is_empty() or node.get("type") != kind:
		return {"success": false}

	if _selected.has(current_id):
		return _copy_choice(_selected[current_id])

	# Fail the ENTIRE chosen-kind candidate pool closed before consuming RNG.
	if encounter_paths.is_empty():
		return {"success": false}
	var ids: Array = encounter_paths.keys()
	for id in ids:
		if not id is String or id.strip_edges().is_empty():
			return {"success": false}
	ids.sort()
	var schedules: Dictionary = {}
	for id in ids:
		var path = encounter_paths[id]
		if not path is String or path.get_base_dir() != "res://data/encounters" \
				or not path.ends_with(".json") or path != path.simplify_path():
			return {"success": false}
		if not FileAccess.file_exists(path):
			return {"success": false}
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return {"success": false}
		var definitions: Array = _parse_schedule_text(file.get_as_text())
		file.close()
		if definitions.is_empty():
			return {"success": false}
		schedules[id] = definitions

	# The only selection draw. Dictionary insertion order is never used.
	var picked_id: String = ids[run_rng.randi_range(0, ids.size() - 1)]
	_bound_map = map
	_selected[current_id] = {
		"success": true,
		"node_type": kind,
		"encounter_id": picked_id,
		"definitions": schedules[picked_id],
	}
	return _copy_choice(_selected[current_id])

static func _copy_choice(choice: Dictionary) -> Dictionary:
	return choice.duplicate(true)


## Shared by file loading and malformed-data regression tests. JSON numeric
## fields must be mathematically integral, finite and exactly representable
## before coercion; CombatEnemyIntents remains the authority for action shape,
## enemy positions, targets, and nonnegative amounts.
static func _parse_schedule_text(json_text: String) -> Array:
	var parser := JSON.new()
	if parser.parse(json_text) != OK:
		return []
	var parsed = parser.data
	if not parsed is Array or parsed.is_empty():
		return []
	var definitions: Array = parsed.duplicate(true)
	for definition in definitions:
		if not definition is Dictionary or not definition.has("enemy_position") \
				or not definition.has("pattern"):
			return []
		if not _coerce_integral_field(definition, "enemy_position"):
			return []
		var pattern = definition["pattern"]
		if not pattern is Array or pattern.is_empty():
			return []
		for action in pattern:
			if not action is Dictionary or not action.has("amount"):
				return []
			if not _coerce_integral_field(action, "amount"):
				return []
			if action.has("target_position") \
					and not _coerce_integral_field(action, "target_position"):
				return []
	var validator := CombatEnemyIntents.new(definitions)
	if not validator.is_valid():
		return []
	return definitions


static func _coerce_integral_field(record: Dictionary, field: String) -> bool:
	var value = record[field]
	if value is int:
		return true
	if not value is float or is_nan(value) or is_inf(value):
		return false
	# JSON parsed doubles lose integer precision beyond 2^53 - 1.
	if absf(value) > 9007199254740991.0 or floorf(value) != value:
		return false
	record[field] = int(value)
	return true
