class_name RunTypedBattleRoster
extends RefCounted
## Scene-free bridge from a validated typed encounter selection to independent
## CombatEnemies state. The caller owns the ID-to-ordered-roster bindings.
## No map, selector, or RNG is supplied or changed here.


func assemble(typed_choice: Variant, encounter_rosters: Variant,
		enemy_catalog_paths: Variant) -> Dictionary:
	if not typed_choice is Dictionary or not encounter_rosters is Dictionary \
			or not enemy_catalog_paths is Array or enemy_catalog_paths.is_empty():
		return {"ok": false}
	if not typed_choice.get("success") is bool or typed_choice.get("success") != true:
		return {"ok": false}
	var node_type = typed_choice.get("node_type")
	var encounter_id = typed_choice.get("encounter_id")
	var selected = typed_choice.get("definitions")
	if not node_type is String or node_type not in ["Fight", "Elite", "Boss"] \
			or not encounter_id is String or encounter_id.strip_edges().is_empty() \
			or not selected is Array:
		return {"ok": false}
	if not encounter_rosters.has(encounter_id):
		return {"ok": false}
	var ids = encounter_rosters[encounter_id]
	if not ids is Array or ids.is_empty() or ids.size() > CombatEnemies.MAX_ENEMIES:
		return {"ok": false}

	# Validate the entire selected schedule, not just source position keys.
	# Deep copying protects both the caller's selection and the selector cache.
	var definitions: Array = selected.duplicate(true)
	if not CombatEnemyIntents.new(definitions).is_valid():
		return {"ok": false}
	if definitions.size() != ids.size():
		return {"ok": false}
	var seen_positions: Array[int] = []
	for definition in definitions:
		var position: int = definition["enemy_position"]
		if position < 1 or position > ids.size() or position in seen_positions:
			return {"ok": false}
		seen_positions.append(position)
	# With equal counts and distinct in-range positions, every slot has a source.

	var catalog: Dictionary = {}
	for path in enemy_catalog_paths:
		if not path is String or path.get_base_dir() != "res://data/enemies" \
				or not path.ends_with(".json") or path != path.simplify_path() \
				or not FileAccess.file_exists(path):
			return {"ok": false}
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return {"ok": false}
		var parsed := _parse_catalog_text(file.get_as_text())
		file.close()
		if parsed.is_empty():
			return {"ok": false}
		for enemy in parsed:
			var enemy_id: String = enemy["id"]
			if catalog.has(enemy_id):
				return {"ok": false}
			catalog[enemy_id] = enemy

	var ordered: Array = []
	var seen_ids: Array[String] = []
	for id in ids:
		if not id is String or id.strip_edges().is_empty() or id in seen_ids \
				or not catalog.has(id):
			return {"ok": false}
		seen_ids.append(id)
		ordered.append(catalog[id].duplicate(true))
	var enemies := CombatEnemies.new(ordered)
	if not enemies.is_valid() or enemies.get_enemies().size() != ids.size():
		return {"ok": false}
	return {"ok": true, "node_type": node_type, "encounter_id": encounter_id,
		"enemies": enemies, "definitions": definitions}


## Strictly parse authored enemy JSON. JSON numbers are doubles even when
## written as integers; normalize only exactly integral, safely sized HP.
## This parser also allows negative tests without modifying shared catalogs.
static func _parse_catalog_text(json_text: String) -> Array:
	var parser := JSON.new()
	if parser.parse(json_text) != OK or not parser.data is Array:
		return []
	var parsed: Array = parser.data
	if parsed.is_empty():
		return []
	var records: Array = parsed.duplicate(true)
	var seen: Array[String] = []
	for record in records:
		if not record is Dictionary:
			return []
		var id = record.get("id")
		if not id is String or id.strip_edges().is_empty() or id != id.strip_edges() \
				or id in seen or not record.has("max_hp"):
			return []
		if not RunFightEncounterSelection._coerce_integral_field(record, "max_hp") \
				or record["max_hp"] <= 0:
			return []
		seen.append(id)
	return records
