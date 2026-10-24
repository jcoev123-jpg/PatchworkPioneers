class_name RunAuthoredBattleEntry
extends RefCounted
## Scene-free entry for an ALREADY committed, legal RunMap Fight/Elite/Boss.
## entry_current_battle(map, run_rng, selector) returns {"success": false}
## atomically on rejection; on success it returns {"success": true,
## "node_type": String, "encounter_id": String, "definitions": Array,
## "enemies": CombatEnemies, "intents": CombatEnemyIntents}.
## Uses the run's ONE RNG and selector; does not choose a node, launch a
## scene, modify party/deck/gold, or change any authored JSON. Each call
## creates independent actor and intent instances, including cached reads.

const POOLS_PATH := "res://data/encounters/m03_typed_battle_pools.json"
const CATALOG_PATHS := [
    "res://data/enemies/starter_enemies.json",
    "res://data/enemies/run_enemies.json",
    "res://data/enemies/boss.json",
    "res://data/enemies/m04_elites.json",
]


func entry_current_battle(map: RunMap, run_rng: RandomNumberGenerator,
        selector: RunFightEncounterSelection) -> Dictionary:
    if map == null or run_rng == null or selector == null:
        return {"success": false}
    var file := FileAccess.open(POOLS_PATH, FileAccess.READ)
    if file == null:
        return {"success": false}
    var parser := JSON.new()
    var parse_error := parser.parse(file.get_as_text())
    file.close()
    if parse_error != OK:
        return {"success": false}
    return _entry_from_data(map, run_rng, selector, parser.data)


## Narrow injection seam for negative tests. Does not retain or mutate the
## supplied registry; production always reads POOLS_PATH above.
func _entry_from_data(map: RunMap, run_rng: RandomNumberGenerator,
        selector: RunFightEncounterSelection, registry: Variant) -> Dictionary:
    if map == null or run_rng == null or selector == null or not map.is_generated():
        return {"success": false}
    var current_id: String = map.get_current_node_id()
    if current_id.is_empty() or not map.get_route().has(current_id):
        return {"success": false}
    var node: Dictionary = map.get_node(current_id)
    var kind = node.get("type")
    if not kind is String or kind not in ["Fight", "Elite", "Boss"]:
        return {"success": false}
    if not registry is Dictionary or not registry.has(kind) or not registry[kind] is Dictionary:
        return {"success": false}
    var candidates: Dictionary = registry[kind]
    if candidates.is_empty():
        return {"success": false}

    # A malformed *other* kind cannot prevent entry at the current kind.
    # Validate ALL candidates of this kind before the selector can draw/cache.
    var available_normal := {}
    var available_boss := {}
    for catalog_index in range(CATALOG_PATHS.size()):
        var file := FileAccess.open(CATALOG_PATHS[catalog_index], FileAccess.READ)
        if file == null:
            return {"success": false}
        var records := RunTypedBattleRoster._parse_catalog_text(file.get_as_text())
        file.close()
        if records.is_empty():
            return {"success": false}
        for record in records:
            var enemy_id: String = record["id"]
            # RunTypedBattleRoster.assemble remains responsible for rejecting
            # duplicates spanning multiple catalogs and invalid actor models.
            if catalog_index == 2:
                available_boss[enemy_id] = true
            else:
                available_normal[enemy_id] = true

    # Only these two M05 Fight alternatives intentionally reuse earlier schedules.
    # All pre-existing named encounters must keep their canonical binding.
    var schedule_aliases := {
        "felt_moth_pressure": "res://data/encounters/bobbin_skirmish.json",
        "pin_thread_crossfire": "res://data/encounters/buttonhole_holdout.json",
    }
    var paths := {}
    var rosters := {}
    var schedules := {}
    var assembler := RunTypedBattleRoster.new()
    for id in candidates:
        if not id is String or id.strip_edges().is_empty() or id != id.strip_edges():
            return {"success": false}
        var entry = candidates[id]
        if not entry is Dictionary or entry.size() != 2 or not entry.has("schedule") \
                or not entry.has("enemy_ids"):
            return {"success": false}
        var path = entry["schedule"]
        var ids = entry["enemy_ids"]
        # Several named Fight alternatives intentionally reuse a validated
        # two-source schedule. Keep the path canonical and inside encounters.
        if not path is String or path.get_base_dir() != "res://data/encounters" \
                or not path.ends_with(".json") or path != path.simplify_path() \
                or (path != "res://data/encounters/%s.json" % id
                    and not (kind == "Fight" and schedule_aliases.get(id) == path)) \
                or not FileAccess.file_exists(path) or not ids is Array or ids.is_empty():
            return {"success": false}
        for enemy_id in ids:
            if not enemy_id is String or not (available_boss if kind == "Boss" \
                    else available_normal).has(enemy_id):
                return {"success": false}
        var schedule_file := FileAccess.open(path, FileAccess.READ)
        if schedule_file == null:
            return {"success": false}
        var definitions := RunFightEncounterSelection._parse_schedule_text(
            schedule_file.get_as_text())
        schedule_file.close()
        if definitions.is_empty():
            return {"success": false}
        var binding := {}
        binding[id] = ids
        var probe := assembler.assemble({
            "success": true, "node_type": kind, "encounter_id": id,
            "definitions": definitions,
        }, binding, CATALOG_PATHS)
        if not probe.get("ok", false):
            return {"success": false}
        paths[id] = path
        rosters[id] = ids.duplicate(true)
        schedules[id] = definitions

    var typed_pools := {}
    typed_pools[kind] = paths
    var selected := selector.select_current_battle(map, run_rng, typed_pools)
    if not selected.get("success", false) or selected.get("node_type") != kind:
        return {"success": false}
    var chosen = selected.get("encounter_id")
    # A previously cached encounter from a different pool must not be
    # substituted for the newly validated binding.
    if not chosen is String or not schedules.has(chosen) \
            or selected.get("definitions") != schedules[chosen]:
        return {"success": false}
    var assembled := assembler.assemble(selected, rosters, CATALOG_PATHS)
    if not assembled.get("ok", false):
        return {"success": false}
    var detached: Array = assembled["definitions"].duplicate(true)
    var intents := CombatEnemyIntents.new(detached)
    if not intents.is_valid():
        return {"success": false}
    return {
        "success": true,
        "node_type": kind,
        "encounter_id": chosen,
        "definitions": detached,
        "enemies": assembled["enemies"],
        "intents": intents,
    }
