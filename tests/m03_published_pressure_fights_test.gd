extends SceneTree

const POOLS := "res://data/encounters/m03_typed_battle_pools.json"
const ROSTERS := {
    "rearline_needlemark": ["fray_scavenger", "seam_ripper"],
    "middlemark_clamp": ["spool_stalker", "seam_ripper"],
    "backhem_pinwheel": ["fray_scavenger", "button_guard", "spool_stalker"],
    "hemdrag_relay": ["seam_ripper", "button_guard"],
}
var failures: Array[String] = []
var checks := 0
var service := RunAuthoredBattleEntry.new()


func _initialize() -> void:
    var registry: Variant = JSON.parse_string(FileAccess.get_file_as_string(POOLS))
    _check(registry is Dictionary and registry.get("Fight") is Dictionary,
        "real typed registry loads")
    if registry is Dictionary and registry.get("Fight") is Dictionary:
        var before := _sources()
        for id in ROSTERS:
            _check(registry["Fight"].get(id) == {
                "schedule": "res://data/encounters/%s.json" % id,
                "enemy_ids": ROSTERS[id]}, id + " exact named binding")
            if not registry["Fight"].has(id):
                continue
            var isolated := {"Fight": {id: registry["Fight"][id]}}
            _exercise(4103, id, isolated, false)
            var seed_value := _seed_for(registry, id)
            _check(seed_value > 0, id + " has a real full-pool seeded selection")
            if seed_value > 0:
                _exercise(seed_value, id, registry, true)
            _rejections(registry, id)
        _illegal_nodes(registry)
        _check(_sources() == before, "all disk registry, catalog and schedules unchanged")
    for failure in failures:
        printerr(failure)
    print("m03_published_pressure_fights_test: ",
        "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
    quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures.append(message)


func _sources() -> Dictionary:
    var result := {POOLS: FileAccess.get_file_as_string(POOLS)}
    for path in RunAuthoredBattleEntry.CATALOG_PATHS:
        result[path] = FileAccess.get_file_as_string(path)
    for id in ROSTERS:
        var path := "res://data/encounters/%s.json" % id
        result[path] = FileAccess.get_file_as_string(path)
    return result


func _setup(seed_value: int, commit := true) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var map := RunMap.new()
    _check(map.generate(rng), "generated seeded legal map")
    if commit:
        var chosen := ""
        for node in map.get_legal_choices():
            if map.get_node(node).get("type") == "Fight":
                chosen = node
                break
        _check(not chosen.is_empty() and map.choose_node(chosen), "committed legal Fight")
    return {"map": map, "rng": rng, "selector": RunFightEncounterSelection.new()}


func _state(s: Dictionary) -> Dictionary:
    return {"floors": s["map"].get_floors(), "route": s["map"].get_route(),
        "current": s["map"].get_current_node_id(), "floor": s["map"].get_current_floor(),
        "legal": s["map"].get_legal_choices() if s["map"].get_route().is_empty()
            or not s["map"].get_node(s["map"].get_current_node_id()).is_empty() else [],
        "revision": s["map"].get_generation_revision(),
        "rng": s["rng"].state, "cache": s["selector"]._selected.duplicate(true),
        "bound": s["selector"]._bound_map}


func _seed_for(registry: Dictionary, target: String) -> int:
    var ids: Array = registry["Fight"].keys()
    ids.sort()
    for value in range(1, 1025):
        var s := _setup(value)
        if ids[s["rng"].randi_range(0, ids.size() - 1)] == target:
            return value
    return -1


func _enter(s: Dictionary, registry: Dictionary, production: bool) -> Dictionary:
    if production:
        return service.entry_current_battle(s["map"], s["rng"], s["selector"])
    return service._entry_from_data(s["map"], s["rng"], s["selector"], registry)


func _snapshot(entry: Dictionary, id: String) -> Dictionary:
    _check(entry.get("success") == true and entry.get("node_type") == "Fight"
        and entry.get("encounter_id") == id, id + " admitted by real typed service")
    if not entry.get("success", false):
        return {}
    var enemies: CombatEnemies = entry.get("enemies")
    var intents: CombatEnemyIntents = entry.get("intents")
    _check(enemies != null and enemies.is_valid() and intents != null and intents.is_valid(),
        id + " valid independent actor and intent services")
    if enemies == null or intents == null or not enemies.is_valid() or not intents.is_valid():
        return {}
    var definitions := RunFightEncounterSelection._parse_schedule_text(
        FileAccess.get_file_as_string("res://data/encounters/%s.json" % id))
    _check(not definitions.is_empty() and definitions.size() == ROSTERS[id].size()
        and entry.get("definitions") == definitions, id + " actual full authored schedule")
    var catalog := RunTypedBattleRoster._parse_catalog_text(
        FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
    _check(not catalog.is_empty(), "actual normal enemy catalog loads")
    var expected_actors := []
    for index in range(ROSTERS[id].size()):
        var matches := catalog.filter(func(record): return record["id"] == ROSTERS[id][index])
        _check(matches.size() == 1, id + " unique catalog actor at slot " + str(index + 1))
        if matches.size() != 1:
            continue
        var actor: Dictionary = matches[0].duplicate(true)
        actor.merge({"position": index + 1, "hp": actor["max_hp"], "block": 0}, true)
        expected_actors.append(actor)
    _check(enemies.get_enemies() == expected_actors, id + " complete ordered fresh actor snapshots")
    var timeline := []
    # Every new source has three beats: include a full cycle and wraparound.
    for beat in range(4):
        var expected := []
        for definition in definitions:
            var pattern: Array = definition["pattern"]
            var action: Dictionary = pattern[beat % pattern.size()].duplicate(true)
            action["enemy_position"] = definition["enemy_position"]
            expected.append(action)
        _check(intents.get_intents() == expected, id + " all ordered intents beat " + str(beat))
        timeline.append(intents.get_intents())
        _check(intents.advance_turn(), id + " intent cycle advances")
    return {"actors": enemies.get_enemies(), "definitions": definitions, "timeline": timeline}


func _exercise(value: int, id: String, registry: Dictionary, production: bool) -> void:
    var registry_before := registry.duplicate(true)
    var s := _setup(value)
    var before := _state(s)
    var oracle := RandomNumberGenerator.new()
    oracle.state = s["rng"].state
    var ids: Array = registry["Fight"].keys()
    ids.sort()
    _check(ids[oracle.randi_range(0, ids.size() - 1)] == id, id + " sorted seeded oracle")
    seed(91091)
    var expected_global := randi()
    seed(91091)
    var first := _enter(s, registry, production)
    _check(randi() == expected_global, id + " no global RNG draw")
    var snapshot := _snapshot(first, id)
    if snapshot.is_empty():
        return
    var after := _state(s)
    var expected_state := before.duplicate(true)
    expected_state["rng"] = oracle.state
    expected_state["bound"] = s["map"]
    expected_state["cache"] = s["selector"]._selected.duplicate(true)
    _check(after == expected_state and not after["cache"].is_empty(),
        id + " one selection draw and cache; unchanged entire route/map")
    _check(first["enemies"].apply_damage(1, 2) and first["enemies"].gain_block(2, 5),
        id + " first actors mutated through real APIs")
    first["definitions"][0]["pattern"].clear()
    var second := _enter(s, registry, production)
    _check(_state(s) == after, id + " cached re-entry no RNG/map/cache change")
    _check(second.get("enemies") != first["enemies"] and second.get("intents") != first["intents"],
        id + " distinct cached actors and scheduler")
    _check(_snapshot(second, id) == snapshot, id + " detached re-entry restores all state")
    var replay := _setup(value)
    var repeated := _enter(replay, registry, production)
    _check(_snapshot(repeated, id) == snapshot, id + " same-seed complete actor/intent trace")
    var replay_state := _state(replay)
    replay_state["bound"] = s["map"]
    _check(replay_state == after, id + " same-seed complete map/RNG/cache trace")
    _check(registry == registry_before, id + " supplied registry remains detached")


func _reject(s: Dictionary, registry: Variant, label: String) -> void:
    var before := _state(s)
    var data_before: Variant = registry.duplicate(true) if registry is Dictionary else registry
    _check(service._entry_from_data(s["map"], s["rng"], s["selector"], registry)
        == {"success": false}, label + " rejects")
    _check(_state(s) == before and registry == data_before, label + " no map/RNG/cache/data mutation")


func _rejections(registry: Dictionary, id: String) -> void:
    var s := _setup(4103)
    for invalid in [null, [], {}, {"Fight": []}, {"Fight": {}}, {"Fight": {id: null}}]:
        _reject(s, invalid, id + " malformed local registry")
    for field in ["unknown", "duplicate", "arity", "missing", "mismatch", "traversal", "type", "boss"]:
        var bad := registry.duplicate(true)
        var binding: Dictionary = bad["Fight"][id]
        match field:
            "unknown": binding["enemy_ids"][0] = "unknown_enemy"
            "duplicate": binding["enemy_ids"][1] = binding["enemy_ids"][0]
            "arity": binding["enemy_ids"].pop_back()
            "missing":
                bad["Fight"]["missing_pressure"] = {"schedule": "res://data/encounters/missing_pressure.json", "enemy_ids": ROSTERS[id]}
            "mismatch": binding["schedule"] = "res://data/encounters/starter_attacks.json"
            "traversal": binding["schedule"] = "res://data/encounters/../encounters/%s.json" % id
            "type": binding["enemy_ids"][0] = 1
            "boss": binding["enemy_ids"][0] = "patchwork_behemoth"
        _reject(s, bad, id + " bad binding " + field)
    var malformed_schedule := registry.duplicate(true)
    malformed_schedule["Fight"]["m03_typed_battle_pools"] = {"schedule": POOLS, "enemy_ids": ROSTERS[id]}
    _reject(s, malformed_schedule, id + " actual non-schedule JSON")
    var isolated := {"Fight": {id: registry["Fight"][id]}, "Elite": null, "Boss": []}
    _check(not _snapshot(_enter(s, isolated, false), id).is_empty(),
        id + " valid retry with malformed other-kind pools")
    # Repeat rejection with an already bound, nonempty cache.
    var bad_cached := isolated.duplicate(true)
    bad_cached["Fight"][id]["enemy_ids"][0] = "unknown_enemy"
    _reject(s, bad_cached, id + " invalid binding cannot bypass validation through cache")


func _illegal_nodes(registry: Dictionary) -> void:
    var ungenerated := {"map": RunMap.new(), "rng": RandomNumberGenerator.new(),
        "selector": RunFightEncounterSelection.new()}
    ungenerated["rng"].seed = 91091
    _reject(ungenerated, registry, "ungenerated map")
    _reject(_setup(4103, false), registry, "uncommitted opening")
    var s := _setup(4103)
    var node: String = s["map"].get_current_node_id()
    for kind in ["Rest", "Shop", "Event", "Treasure", "Unknown", 1, null]:
        s["map"]._nodes[node]["type"] = kind
        _reject(s, registry, "illegal current type " + str(kind))
    s["map"]._nodes[node]["type"] = "Fight"
    s["map"]._route.append("missing_node")
    _reject(s, registry, "unknown current node")
    s["map"]._route.pop_back()
    _check(service.entry_current_battle(s["map"], s["rng"], s["selector"]).get("success") == true,
        "production retry after invalid nodes succeeds")
