extends SceneTree

const POOLS := "res://data/encounters/m03_typed_battle_pools.json"
const SOURCES := [
    POOLS,
    "res://data/enemies/starter_enemies.json",
    "res://data/enemies/run_enemies.json",
    "res://data/enemies/boss.json",
    "res://data/encounters/starter_attacks.json",
    "res://data/encounters/bobbin_skirmish.json",
    "res://data/encounters/buttonhole_holdout.json",
    "res://data/encounters/guard_counterattack.json",
    "res://data/encounters/thimble_crossfire.json",
    "res://data/encounters/patchwork_behemoth.json",
]
const HP := {
    "ragling": 12, "ragling_guard": 12, "fray_scavenger": 14,
    "spool_stalker": 14, "button_guard": 16, "seam_ripper": 18,
    "patchwork_behemoth": 42,
}
const BINDINGS := {
    "Fight": {
        "starter_attacks": ["ragling", "ragling_guard"],
        "bobbin_skirmish": ["fray_scavenger", "spool_stalker"],
        "buttonhole_holdout": ["button_guard", "seam_ripper"],
        "guard_counterattack": ["ragling_guard", "button_guard"],
    },
    "Elite": {"thimble_crossfire": ["button_guard", "seam_ripper"]},
    "Boss": {"patchwork_behemoth": ["patchwork_behemoth"]},
}

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
    _test_authored_bindings()
    _test_seeded_fight_and_isolation()
    _test_twelve_floor_elite_boss_replay()
    _test_atomic_rejection_and_retry()
    if failures.is_empty():
        print("run_authored_battle_entry_test: PASS (", checks, " checks)")
    else:
        for message in failures:
            printerr(message)
        printerr("run_authored_battle_entry_test: FAIL (", failures.size(), " failures)")
    quit(0 if failures.is_empty() else 1)


func _check(ok: bool, why: String) -> void:
    checks += 1
    if not ok:
        failures.append(why)


func _rng(value: int) -> RandomNumberGenerator:
    var rng := RandomNumberGenerator.new()
    rng.seed = value
    return rng


func _sources() -> Dictionary:
    var snapshot := {}
    for path in SOURCES:
        _check(FileAccess.file_exists(path), "required source exists " + path)
        snapshot[path] = FileAccess.get_file_as_string(path)
    # Prior unrelated encounter must remain loadable and unedited by entry.
    var prior := "res://data/encounters/ragling_rearline_feint.json"
    snapshot[prior] = FileAccess.get_file_as_string(prior)
    _check(not snapshot[prior].is_empty() and not
        RunFightEncounterSelection._parse_schedule_text(snapshot[prior]).is_empty(),
        "previous unrelated encounter remains valid")
    return snapshot


func _registry() -> Dictionary:
    var parser := JSON.new()
    var error := parser.parse(FileAccess.get_file_as_string(POOLS))
    _check(error == OK and parser.data is Dictionary, "authored registry is valid JSON object")
    return parser.data if error == OK and parser.data is Dictionary else {}


func _expected_actions() -> Dictionary:
    return {
        "starter_attacks": [
            [{"type": "attack", "amount": 1, "target_position": 1},
             {"type": "attack", "amount": 1, "target_position": 2},
             {"type": "attack", "amount": 1, "target_position": 3}],
            [{"type": "block", "amount": 1}],
        ],
        "bobbin_skirmish": [
            [{"type": "attack", "amount": 1, "target_position": 2},
             {"type": "block", "amount": 1},
             {"type": "attack", "amount": 1, "target_position": 3}],
            [{"type": "attack", "amount": 1, "target_position": 1},
             {"type": "block", "amount": 1}],
        ],
        "buttonhole_holdout": [
            [{"type": "attack", "amount": 1, "target_position": 1},
             {"type": "block", "amount": 1},
             {"type": "block", "amount": 1},
             {"type": "attack", "amount": 1, "target_position": 3}],
            [{"type": "attack", "amount": 1, "target_position": 2},
             {"type": "attack", "amount": 1, "target_position": 2},
             {"type": "attack", "amount": 1, "target_position": 1},
             {"type": "attack", "amount": 1, "target_position": 3}],
        ],
        "guard_counterattack": [
            [{"type": "block", "amount": 1},
             {"type": "attack", "amount": 1, "target_position": 1}],
            [{"type": "attack", "amount": 1, "target_position": 3},
             {"type": "block", "amount": 1}],
        ],
        "thimble_crossfire": [
            [{"type": "attack", "amount": 1, "target_position": 3},
             {"type": "attack", "amount": 1, "target_position": 2},
             {"type": "block", "amount": 1}],
            [{"type": "attack", "amount": 1, "target_position": 1},
             {"type": "block", "amount": 1}],
        ],
        "patchwork_behemoth": [
            [{"type": "attack", "amount": 2, "target_position": 1},
             {"type": "block", "amount": 3},
             {"type": "attack", "amount": 2, "target_position": 3},
             {"type": "debuff", "amount": 1, "target_position": 2, "status": "weak"}],
        ],
    }


func _test_authored_bindings() -> void:
    var pools := _registry()
    var all_normals := {}
    for kind in BINDINGS:
        _check(pools.has(kind) and pools[kind] is Dictionary,
            "registry contains typed " + kind + " pool")
        if not pools.has(kind) or not pools[kind] is Dictionary:
            continue
        for id in BINDINGS[kind]:
            var expected_ids: Array = BINDINGS[kind][id]
            _check(pools[kind].has(id), kind + "/" + id + " explicitly bound")
            if not pools[kind].has(id):
                continue
            var binding = pools[kind][id]
            _check(binding is Dictionary and binding.get("schedule") ==
                "res://data/encounters/%s.json" % id and
                binding.get("enemy_ids") == expected_ids and binding.size() == 2,
                kind + "/" + id + " exact schedule, roster, and owned fields")
            if not binding is Dictionary:
                continue
            var definitions := RunFightEncounterSelection._parse_schedule_text(
                FileAccess.get_file_as_string(binding.get("schedule", "")))
            var expected: Array = []
            var cycles: Array = _expected_actions()[id]
            for i in range(cycles.size()):
                expected.append({"enemy_position": i + 1, "pattern": cycles[i]})
            _check(definitions == expected, id + " all ordered authored beats and owners")
            _check(CombatEnemyIntents.new(definitions).is_valid(),
                id + " passes authoritative intent validator")
            for enemy_id in expected_ids:
                if kind == "Fight":
                    all_normals[enemy_id] = true
    for id in ["ragling", "ragling_guard", "fray_scavenger",
            "button_guard", "spool_stalker", "seam_ripper"]:
        _check(all_normals.has(id), "all six normals occur in explicitly named Fight pool: " + id)


func _snap(map: RunMap, rng: RandomNumberGenerator,
        selector: RunFightEncounterSelection) -> Dictionary:
    return {
        "floors": map.get_floors(), "route": map.get_route(),
        "choices": map.get_legal_choices(), "current": map.get_current_node_id(),
        "floor": map.get_current_floor(), "rng": rng.state,
        "cache": selector._selected.duplicate(true), "bound": selector._bound_map,
    }


func _opening(map: RunMap) -> String:
    for id in map.get_legal_choices():
        if map.get_node(id).get("type") == "Fight":
            return id
    return ""


func _verify_entry(result: Dictionary, kind: String, expected_id: String,
        label: String) -> Dictionary:
    _check(result.get("success") == true and result.get("node_type") == kind and
        result.get("encounter_id") == expected_id, label + " exact type and selected ID")
    if not result.get("success", false):
        return {}
    var ids: Array = BINDINGS[kind][expected_id]
    var enemies = result.get("enemies")
    var intents = result.get("intents")
    _check(enemies is CombatEnemies and enemies.is_valid() and
        intents is CombatEnemyIntents and intents.is_valid(),
        label + " valid real CombatEnemies and CombatEnemyIntents")
    if not enemies is CombatEnemies or not enemies.is_valid() or \
            not intents is CombatEnemyIntents or not intents.is_valid():
        return {}
    var actual: Array = enemies.get_enemies()
    _check(actual.size() == ids.size() and result["definitions"].size() == ids.size(),
        label + " every authored source maps one-to-one to actor")
    for i in range(ids.size()):
        var enemy: Dictionary = enemies.get_enemy(i + 1)
        _check(enemy.get("id") == ids[i] and enemy.get("position") == i + 1 and
            enemy.get("max_hp") == HP[ids[i]] and enemy.get("hp") == HP[ids[i]] and
            enemy.get("block") == 0 and enemy.get("art_path", "").begins_with(
            "res://assets/paper/enemies/"), label + " real slot %d identity/HP/Block/art" % (i+1))
    var snapshots := []
    var cycles: Array = _expected_actions()[expected_id]
    for turn in range(9):
        var expected_intents: Array = []
        for i in range(cycles.size()):
            var pattern: Array = cycles[i]
            var action: Dictionary = pattern[turn % pattern.size()].duplicate(true)
            action["enemy_position"] = i + 1
            expected_intents.append(action)
        var shown: Array = intents.get_intents()
        _check(shown == expected_intents, label + " complete ordered actions turn %d" % turn)
        snapshots.append(shown)
        _check(intents.advance_turn(), label + " advances fixed authored cycle turn %d" % turn)
    return {"actors": actual, "definitions": result["definitions"].duplicate(true),
        "timeline": snapshots, "kind": kind, "id": expected_id}


func _test_seeded_fight_and_isolation() -> void:
    var pools := _registry()
    if not pools.has("Fight"):
        return
    var rng := _rng(4103)
    var oracle := _rng(4103)
    var map := RunMap.new()
    var oracle_map := RunMap.new()
    _check(map.generate(rng) and oracle_map.generate(oracle) and
        map.get_floors() == oracle_map.get_floors(),
        "seeded Fight test starts from identical real generated graphs")
    var id := _opening(map)
    _check(not id.is_empty() and map.get_legal_choices().has(id) and
        map.choose_node(id) and oracle_map.choose_node(id),
        "seeded Fight is legal and independently committed on both maps")
    if id.is_empty():
        return
    var ids: Array = pools["Fight"].keys()
    ids.sort()
    var expected_id: String = ids[oracle.randi_range(0, ids.size() - 1)]
    var selector := RunFightEncounterSelection.new()
    var before_sources := _sources()
    var service := RunAuthoredBattleEntry.new()
    _check(service.has_method("entry_current_battle"), "public required entry_current_battle API")
    seed(515015)
    var global_next := randi()
    seed(515015)
    var first := service.entry_current_battle(map, rng, selector)
    _check(randi() == global_next, "entry never consumes global RNG")
    _check(rng.state == oracle.state and map.get_route() == [id],
        "exactly one sorted-pool RNG draw; map not advanced")
    var snapshot := _verify_entry(first, "Fight", expected_id, "first Fight")
    if snapshot.is_empty():
        return
    var cache_before := selector._selected.duplicate(true)
    var fixed_rng_state := rng.state
    _check(first["enemies"].gain_block(1, 4) and
        first["enemies"].apply_damage(1, 6) and
        first["enemies"].apply_damage(2, 2), "first actors accept actual mutable combat operations")
    first["definitions"][0]["pattern"][0]["amount"] = 555
    first["definitions"][0]["pattern"].clear()
    first["encounter_id"] = "tampered"
    var second := service.entry_current_battle(map, rng, selector)
    _check(second.get("success") and rng.state == fixed_rng_state and
        selector._selected == cache_before, "same committed node never rerolls or poisons selector cache")
    _check(first["enemies"] != second["enemies"] and first["intents"] != second["intents"] and
        second["enemies"].get_enemy(1)["hp"] == HP[BINDINGS["Fight"][expected_id][0]] and
        second["intents"].get_intents() == _expected_first_actions(expected_id),
        "mutated first response cannot affect fresh actors or fresh intent turn zero")
    var resnapshot := _verify_entry(second, "Fight", expected_id, "cached Fight")
    _check(snapshot == resnapshot, "cached result has independent full unmodified roster and intents")
    _check(_sources() == before_sources, "no catalog, registry or schedule source mutated")


func _expected_first_actions(id: String) -> Array:
    var expected := []
    var cycles: Array = _expected_actions()[id]
    for i in range(cycles.size()):
        var action: Dictionary = cycles[i][0].duplicate(true)
        action["enemy_position"] = i + 1
        expected.append(action)
    return expected


## Search deterministic generated graphs, keeping a route to a real Elite.
func _elite_route(map: RunMap) -> Array:
    var frontier := []
    for id in map.get_legal_choices():
        if map.get_node(id).get("type") == "Fight":
            frontier.append({"path": [id], "has_elite": false})
    for floor_number in range(2, RunMap.FLOOR_COUNT + 1):
        var next := []
        var seen := {}
        for entry in frontier:
            for candidate in map.get_node(entry["path"].back())["outgoing"]:
                var elite: bool = entry["has_elite"] or map.get_node(candidate).get("type") == "Elite"
                var key: String = candidate + "/" + str(elite)
                if seen.has(key):
                    continue
                seen[key] = true
                var path: Array = entry["path"].duplicate()
                path.append(candidate)
                next.append({"path": path, "has_elite": elite})
        frontier = next
    for entry in frontier:
        if entry["has_elite"] and entry["path"].size() == 12 and \
                map.get_node(entry["path"].back()).get("type") == "Boss":
            return entry["path"]
    return []


func _play_route(seed_value: int, route: Array, registry: Dictionary) -> Dictionary:
    var rng := _rng(seed_value)
    var oracle := _rng(seed_value)
    var map := RunMap.new()
    var oracle_map := RunMap.new()
    _check(map.generate(rng) and oracle_map.generate(oracle) and
        map.get_floors() == oracle_map.get_floors(), "route: fresh equivalent real maps")
    var selector := RunFightEncounterSelection.new()
    var records := []
    var found := {"Fight": 0, "Elite": 0, "Boss": 0}
    for i in range(route.size()):
        var id: String = route[i]
        _check(map.get_legal_choices().has(id) and oracle_map.get_legal_choices().has(id)
            and map.choose_node(id) and oracle_map.choose_node(id),
            "route: floor %d is a legal connected committed node" % (i + 1))
        var kind: String = map.get_node(id).get("type", "")
        if not kind in ["Fight", "Elite", "Boss"]:
            continue
        found[kind] += 1
        var sorted: Array = registry[kind].keys()
        sorted.sort()
        var expected_id: String = sorted[oracle.randi_range(0, sorted.size() - 1)]
        var chosen := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, selector)
        _check(chosen.get("success") and rng.state == oracle.state,
            "route: " + kind + " spends precisely one sorted choice draw")
        var snap := _verify_entry(chosen, kind, expected_id, "route " + kind + " floor %d" % (i+1))
        if snap.is_empty():
            continue
        snap["node"] = id
        records.append(snap)
        _check(selector._selected.has(id) and selector._selected[id]["encounter_id"] == expected_id,
            "route: selected cache retains same committed node")
    _check(found["Fight"] > 0 and found["Elite"] > 0 and found["Boss"] == 1,
        "route includes a Fight, real Elite placeholder normals and terminal Boss")
    _check(map.get_current_floor() == 12 and map.is_complete() and
        map.get_node(map.get_current_node_id())["type"] == "Boss",
        "route ends at actual generated floor twelve Boss")
    _check(map.get_route() == oracle_map.get_route() and rng.state == oracle.state,
        "complete route and RNG match separate one-draw oracle")
    return {"records": records, "route": map.get_route(), "graph": map.get_floors(),
        "rng": rng.state, "cache": selector._selected.duplicate(true)}


func _test_twelve_floor_elite_boss_replay() -> void:
    var selected_seed := -1
    var route := []
    for value in range(1, 129):
        var candidate := RunMap.new()
        candidate.generate(_rng(value))
        var found := _elite_route(candidate)
        if found.size() == 12:
            selected_seed = value
            route = found
            break
    _check(selected_seed > 0 and route.size() == 12,
        "deterministic graph has a connected twelve-floor Elite and Boss route")
    if selected_seed < 0:
        return
    var sources := _sources()
    var registry := _registry()
    var first := _play_route(selected_seed, route, registry)
    var second := _play_route(selected_seed, route, registry)
    _check(first == second, "complete seed replay matches route, every action cycle, actors, cache and RNG")
    _check(_sources() == sources, "twelve-floor route never mutates any authored source")


func _reject(map: RunMap, rng: RandomNumberGenerator,
        selector: RunFightEncounterSelection, registry: Variant,
        label: String, use_public: bool = false) -> void:
    var before := _snap(map, rng, selector)
    var source_before := _sources()
    var input_before = registry.duplicate(true) if registry is Dictionary else registry
    var helper := RunAuthoredBattleEntry.new()
    var outcome := (helper.entry_current_battle(map, rng, selector) if use_public
        else helper._entry_from_data(map, rng, selector, registry))
    _check(outcome == {"success": false}, label + ": atomic rejection")
    _check(_snap(map, rng, selector) == before and registry == input_before and
        _sources() == source_before,
        label + ": map/route/RNG/selector/entire registry/catalogs unchanged")


func _test_atomic_rejection_and_retry() -> void:
    var registry := _registry()
    var map := RunMap.new()
    var rng := _rng(90210)
    var selector := RunFightEncounterSelection.new()
    _reject(map, rng, selector, registry, "ungenerated")
    _check(map.generate(rng), "invalid-entry map was actually generated")
    _check(not _opening(map).is_empty(), "legal but unchosen Fight exists")
    _reject(map, rng, selector, registry, "legal Fight not selected", true)
    var id := _opening(map)
    _check(map.get_legal_choices().has(id) and map.choose_node(id),
        "rejection node is truly chosen from generated legal set")
    if id.is_empty():
        return
    _reject(map, rng, selector, {}, "missing current kind")
    _reject(map, rng, selector, {"Fight": {}}, "empty current pool")
    var missing := registry.duplicate(true)
    missing["Fight"].erase("starter_attacks")
    missing["Fight"]["bogus"] = {"schedule": "res://data/encounters/absent.json",
        "enemy_ids": ["ragling", "ragling_guard"]}
    _reject(map, rng, selector, missing, "absent candidate schedule rejects whole kind")
    var traversal := registry.duplicate(true)
    traversal["Fight"]["starter_attacks"]["schedule"] = (
        "res://data/encounters/../encounters/starter_attacks.json")
    _reject(map, rng, selector, traversal, "noncanonical traversal path")
    var off_catalog := registry.duplicate(true)
    off_catalog["Fight"]["starter_attacks"]["enemy_ids"][0] = "unknown_normal"
    _reject(map, rng, selector, off_catalog, "unknown normal ID")
    var duplicate := registry.duplicate(true)
    duplicate["Fight"]["starter_attacks"]["enemy_ids"][1] = "ragling"
    _reject(map, rng, selector, duplicate, "duplicate roster enemy ID")
    var arity := registry.duplicate(true)
    arity["Fight"]["starter_attacks"]["enemy_ids"] = ["ragling"]
    _reject(map, rng, selector, arity, "mismatched schedule/source arity")
    var changed_kind := registry.duplicate(true)
    changed_kind["Elite"] = {"invalid": null}
    var oracle := _rng(90210)
    var oracle_map := RunMap.new()
    _check(oracle_map.generate(oracle) and oracle_map.choose_node(id),
        "separate oracle generates same genuine selected node")
    var sorted_ids: Array = registry["Fight"].keys()
    sorted_ids.sort()
    var expected_id: String = sorted_ids[oracle.randi_range(0, sorted_ids.size() - 1)]
    var good := RunAuthoredBattleEntry.new()._entry_from_data(
        map, rng, selector, changed_kind)
    _check(good.get("success") and good.get("encounter_id") == expected_id and
        rng.state == oracle.state,
        "malformed other kind does not invalidate Fight; retry uses exact one draw")
    var rest_node := ""
    var nonbattle_map := RunMap.new()
    var nonbattle_rng := _rng(1)
    for value in range(1, 100):
        nonbattle_rng = _rng(value)
        nonbattle_map = RunMap.new()
        nonbattle_map.generate(nonbattle_rng)
        for choice in nonbattle_map.get_legal_choices():
            if nonbattle_map.get_node(choice).get("type") in ["Rest", "Shop"]:
                rest_node = choice
                break
        if not rest_node.is_empty():
            break
    _check(not rest_node.is_empty() and
        nonbattle_map.get_legal_choices().has(rest_node) and
        nonbattle_map.choose_node(rest_node), "actual legal Rest/Shop chosen")
    if not rest_node.is_empty():
        _reject(nonbattle_map, nonbattle_rng, RunFightEncounterSelection.new(),
            registry, "selected Rest/Shop", true)
    # Boss negative checks must reach an actual selected Boss, not a mock.
    var boss_map := RunMap.new()
    var boss_rng := _rng(4103)
    boss_map.generate(boss_rng)
    for floor in range(12):
        var legal := boss_map.get_legal_choices()
        _check(not legal.is_empty() and boss_map.choose_node(legal[0]),
            "Boss negative fixture commits legal floor " + str(floor + 1))
    _check(boss_map.get_current_floor() == 12 and
        boss_map.get_node(boss_map.get_current_node_id()).get("type") == "Boss",
        "Boss rejection really targets selected final node")
    var bad_boss := registry.duplicate(true)
    bad_boss["Boss"]["patchwork_behemoth"]["enemy_ids"][0] = "unknown_boss"
    var boss_selector := RunFightEncounterSelection.new()
    _reject(boss_map, boss_rng, boss_selector, bad_boss, "unknown boss catalog ID")
    var after_boss := RunAuthoredBattleEntry.new().entry_current_battle(
        boss_map, boss_rng, boss_selector)
    _verify_entry(after_boss, "Boss", "patchwork_behemoth",
        "Boss successful retry after failed validation")
