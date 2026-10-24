extends SceneTree

const POOLS := "res://data/encounters/m03_typed_battle_pools.json"
const SOURCES := [
    "res://data/encounters/buttonfront_pinfall.json",
    "res://data/encounters/front_hem_pivot.json",
    "res://data/encounters/rear_spool_reversal.json",
    "res://data/encounters/rearline_needlemark.json",
    "res://data/encounters/middlemark_clamp.json",
    "res://data/encounters/backhem_pinwheel.json",
    "res://data/encounters/hemdrag_relay.json",
    "res://data/encounters/spoolbridge_staggered_exposure.json",
    "res://data/encounters/hemhook_exposed_swap.json",
    POOLS,
    "res://data/enemies/starter_enemies.json",
    "res://data/enemies/run_enemies.json",
    "res://data/enemies/boss.json",
    "res://data/enemies/m04_elites.json",
    "res://data/encounters/starter_attacks.json",
    "res://data/encounters/bobbin_skirmish.json",
    "res://data/encounters/buttonhole_holdout.json",
    "res://data/encounters/guard_counterattack.json",
    "res://data/encounters/thimble_crossfire.json",
    "res://data/encounters/needle_marshal_elite.json",
    "res://data/encounters/spool_hexer_elite.json",
    "res://data/encounters/patchwork_behemoth.json",
    "res://data/encounters/triple_spool_pinch.json",
    "res://data/encounters/double_hem_siege.json",
    "res://data/encounters/seamshift_tripwire.json",
]
const HP := {
    "ragling": 12, "ragling_guard": 12, "fray_scavenger": 14,
    "spool_stalker": 14, "button_guard": 16, "seam_ripper": 18,
    "needle_marshal": 28, "spool_hexer": 24,
    "patchwork_behemoth": 42,
}
const NAMES := {
    "ragling": "Ragling", "ragling_guard": "Guard Ragling",
    "fray_scavenger": "Fray Scavenger", "spool_stalker": "Spool Stalker",
    "button_guard": "Button Guard", "seam_ripper": "Seam Ripper",
    "needle_marshal": "Needle Marshal", "spool_hexer": "Spool Hexer",
    "patchwork_behemoth": "Patchwork Behemoth",
}
const ART_PATHS := {
    "ragling": "res://assets/paper/enemies/ragling.png",
    "ragling_guard": "res://assets/paper/enemies/ragling_guard.png",
    "fray_scavenger": "res://assets/paper/enemies/fray_scavenger.png",
    "spool_stalker": "res://assets/paper/enemies/spool_stalker.png",
    "button_guard": "res://assets/paper/enemies/button_guard.png",
    "seam_ripper": "res://assets/paper/enemies/seam_ripper.png",
    "needle_marshal": "res://assets/paper/enemies/needle_marshal.png",
    "spool_hexer": "res://assets/paper/enemies/spool_hexer.png",
    "patchwork_behemoth": "res://assets/paper/enemies/patchwork_behemoth.png",
}
const BINDINGS := {
    "Fight": {
        "buttonfront_pinfall": ["button_guard", "fray_scavenger"],
        "front_hem_pivot": ["button_guard", "fray_scavenger"],
        "rear_spool_reversal": ["spool_stalker", "seam_ripper"],
        "rearline_needlemark": ["fray_scavenger", "seam_ripper"],
        "middlemark_clamp": ["spool_stalker", "seam_ripper"],
        "backhem_pinwheel": ["fray_scavenger", "button_guard", "spool_stalker"],
        "hemdrag_relay": ["seam_ripper", "button_guard"],
        "spoolbridge_staggered_exposure": ["spool_stalker", "seam_ripper"],
        "hemhook_exposed_swap": ["spool_stalker", "seam_ripper", "fray_scavenger"],
        "starter_attacks": ["ragling", "ragling_guard"],
        "bobbin_skirmish": ["fray_scavenger", "spool_stalker"],
        "buttonhole_holdout": ["button_guard", "seam_ripper"],
        "guard_counterattack": ["ragling_guard", "button_guard"],
        "triple_spool_pinch": ["fray_scavenger", "button_guard", "spool_stalker"],
        "double_hem_siege": ["fray_scavenger", "seam_ripper"],
        "seamshift_tripwire": ["seam_ripper", "spool_stalker", "fray_scavenger"],
    },
    "Elite": {
        "thimble_crossfire": ["button_guard", "seam_ripper"],
        "needle_marshal_elite": ["needle_marshal", "ragling_guard"],
        "spool_hexer_elite": ["spool_hexer", "spool_stalker"],
    },
    "Boss": {"patchwork_behemoth": ["patchwork_behemoth"]},
}
const SEAMSHIFT := "seamshift_tripwire"
const SEAMSHIFT_ROSTER := ["seam_ripper", "spool_stalker", "fray_scavenger"]
const TRIPLE := "triple_spool_pinch"
const TRIPLE_ROSTER := ["fray_scavenger", "button_guard", "spool_stalker"]
const PARTY_PATH := "res://data/heroes/starter_party.json"
const FIGHT_SEED := 4103
## The exact applied events the ordinary phase transaction records for the
## new encounter's first authored beat, in enemy-position order.
const TRIPLE_BEAT0_EVENTS := [
    {"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
    {"type": "block", "enemy_position": 2, "applied": true},
    {"type": "attack", "enemy_position": 3, "target_position": 3, "applied": true},
]
## The exact applied events of the second authored beat.
const TRIPLE_BEAT1_EVENTS := [
    {"type": "block", "enemy_position": 1, "applied": true},
    {"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true},
    {"type": "attack", "enemy_position": 3, "target_position": 2, "applied": true},
]

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
    _test_authored_bindings()
    _test_m04_elite_pool_bindings()
    _test_m04_elite_direct_entries()
    _test_m04_elite_full_pool_selection()
    _test_m04_elite_rejections_and_isolation()
    _test_triple_spool_pinch_content()
    _test_seamshift_tripwire_content()
    _test_seamshift_full_pool_entry()
    _test_seeded_fight_and_isolation()
    _test_triple_spool_pinch_entry()
    _test_triple_spool_pinch_phase()
    _test_triple_spool_pinch_slain_source()
    _test_triple_spool_pinch_rejection_and_retry()
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
        "buttonfront_pinfall": [
            [{"type": "debuff", "amount": 1, "target_position": 1, "status": "exposed"},
             {"type": "block", "amount": 2},
             {"type": "attack", "amount": 3, "target_position": 2}],
            [{"type": "attack", "amount": 4, "target_position": 1},
             {"type": "attack", "amount": 3, "target_position": 3},
             {"type": "buff", "amount": 2}],
        ],
        "front_hem_pivot": [
            [{"type": "shove", "amount": 0, "target_position": 1, "direction": 1},
             {"type": "block", "amount": 2},
             {"type": "attack", "amount": 2, "target_position": 3}],
            [{"type": "attack", "amount": 2, "target_position": 1},
             {"type": "attack", "amount": 2, "target_position": 2},
             {"type": "buff", "amount": 2}],
        ],
        "rear_spool_reversal": [
            [{"type": "attack", "amount": 2, "target_position": 2},
             {"type": "attack", "amount": 2, "target_position": 2},
             {"type": "buff", "amount": 2}],
            [{"type": "shove", "amount": 0, "target_position": 3, "direction": -1},
             {"type": "block", "amount": 2},
             {"type": "attack", "amount": 2, "target_position": 3}],
        ],
        "rearline_needlemark": [
            [{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed"},
             {"type": "block", "amount": 2},
             {"type": "attack", "amount": 2, "target_position": 2}],
            [{"type": "attack", "amount": 4, "target_position": 3},
             {"type": "attack", "amount": 3, "target_position": 1},
             {"type": "buff", "amount": 2}],
        ],
        "middlemark_clamp": [
            [{"type": "debuff", "amount": 1, "target_position": 2, "status": "exposed"},
             {"type": "block", "amount": 3},
             {"type": "attack", "amount": 2, "target_position": 3}],
            [{"type": "attack", "amount": 4, "target_position": 2},
             {"type": "attack", "amount": 3, "target_position": 1},
             {"type": "buff", "amount": 2}],
        ],
        "backhem_pinwheel": [
            [{"type": "shove", "amount": 0, "target_position": 3, "direction": -1},
             {"type": "attack", "amount": 2, "target_position": 1},
             {"type": "block", "amount": 2}],
            [{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed"},
             {"type": "buff", "amount": 3},
             {"type": "attack", "amount": 3, "target_position": 2}],
            [{"type": "attack", "amount": 3, "target_position": 3},
             {"type": "block", "amount": 1},
             {"type": "attack", "amount": 2, "target_position": 1}],
        ],
        "hemdrag_relay": [
            [{"type": "debuff", "amount": 1, "target_position": 2, "status": "bleed"},
             {"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
             {"type": "attack", "amount": 3, "target_position": 2}],
            [{"type": "block", "amount": 2},
             {"type": "attack", "amount": 3, "target_position": 3},
             {"type": "buff", "amount": 3}],
        ],
        "spoolbridge_staggered_exposure": [
            [{"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
             {"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed"},
             {"type": "attack", "amount": 3, "target_position": 2}],
            [{"type": "attack", "amount": 4, "target_position": 3},
             {"type": "attack", "amount": 5, "target_position": 3},
             {"type": "buff", "amount": 2}],
        ],
        "hemhook_exposed_swap": [
            [{"type": "shove", "amount": 0, "target_position": 1, "direction": 1},
             {"type": "block", "amount": 2},
             {"type": "attack", "amount": 3, "target_position": 1}],
            [{"type": "debuff", "amount": 1, "target_position": 1, "status": "exposed"},
             {"type": "attack", "amount": 4, "target_position": 2},
             {"type": "buff", "amount": 2}],
            [{"type": "attack", "amount": 4, "target_position": 1},
             {"type": "attack", "amount": 3, "target_position": 3},
             {"type": "attack", "amount": 4, "target_position": 2}],
        ],
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
        "double_hem_siege": [
            [{"type": "attack", "amount": 3, "target_position": 1},
             {"type": "block", "amount": 2},
             {"type": "attack", "amount": 2, "target_position": 3},
             {"type": "attack", "amount": 2, "target_position": 2}],
            [{"type": "attack", "amount": 3, "target_position": 1},
             {"type": "attack", "amount": 2, "target_position": 2},
             {"type": "block", "amount": 2},
             {"type": "attack", "amount": 2, "target_position": 3}],
        ],
        "triple_spool_pinch": [
            [{"type": "attack", "amount": 1, "target_position": 2},
             {"type": "block", "amount": 1}],
            [{"type": "block", "amount": 2},
             {"type": "attack", "amount": 1, "target_position": 1}],
            [{"type": "attack", "amount": 1, "target_position": 3},
             {"type": "attack", "amount": 1, "target_position": 2}],
        ],
        "seamshift_tripwire": [
            [{"type": "shove", "amount": 0, "target_position": 1, "direction": 1},
             {"type": "attack", "amount": 2, "target_position": 2},
             {"type": "block", "amount": 2}],
            [{"type": "debuff", "amount": 1, "target_position": 2, "status": "exposed"},
             {"type": "attack", "amount": 2, "target_position": 3},
             {"type": "buff", "amount": 2}],
            [{"type": "attack", "amount": 4, "target_position": 2},
             {"type": "block", "amount": 1},
             {"type": "attack", "amount": 2, "target_position": 1}],
        ],
        "thimble_crossfire": [
            [{"type": "attack", "amount": 1, "target_position": 3},
             {"type": "attack", "amount": 1, "target_position": 2},
             {"type": "block", "amount": 1}],
            [{"type": "attack", "amount": 1, "target_position": 1},
             {"type": "block", "amount": 1}],
        ],
        "needle_marshal_elite": [
            [{"type": "attack", "amount": 3, "target_position": 1},
             {"type": "buff", "amount": 3},
             {"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
             {"type": "attack", "amount": 4, "target_position": 2}],
            [{"type": "block", "amount": 2},
             {"type": "attack", "amount": 1, "target_position": 3}],
        ],
        "spool_hexer_elite": [
            [{"type": "debuff", "amount": 1, "target_position": 1, "status": "exposed"},
             {"type": "attack", "amount": 3, "target_position": 1},
             {"type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
             {"type": "attack", "amount": 3, "target_position": 2}],
            [{"type": "attack", "amount": 1, "target_position": 3},
             {"type": "block", "amount": 2},
             {"type": "attack", "amount": 1, "target_position": 2}],
        ],
        "patchwork_behemoth": [
            [{"type": "attack", "amount": 2, "target_position": 1},
             {"type": "block", "amount": 3},
             {"type": "attack", "amount": 2, "target_position": 3},
             {"type": "debuff", "amount": 1, "target_position": 2, "status": "weak"},
             {"type": "attack", "amount": 2, "target_position": 2}],
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
        _check(enemy.get("id") == ids[i] and enemy.get("name") == NAMES[ids[i]] and
            enemy.get("position") == i + 1 and
            enemy.get("max_hp") == HP[ids[i]] and enemy.get("hp") == HP[ids[i]] and
            enemy.get("block") == 0 and enemy.get("art_path") == ART_PATHS[ids[i]] and
            enemy.get("art_path", "").begins_with(
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
    return _expected_actions_beat(id, 0)


## The complete announced beat for every authored source, in enemy-position
## order; beat indexes wrap independently through each source's own cycle.
func _expected_actions_beat(id: String, beat: int) -> Array:
    var expected := []
    var cycles: Array = _expected_actions()[id]
    for i in range(cycles.size()):
        var pattern: Array = cycles[i]
        var action: Dictionary = pattern[beat % pattern.size()].duplicate(true)
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


## AC1: the typed Fight registry gains exactly one new binding, the on-disk
## schedule holds exactly one source at each enemy position with the authored
## two-beat cycles, and every earlier named Fight/Elite/Boss binding keeps its
## own fields. No pool size, ID order or selected index is asserted.
func _test_triple_spool_pinch_content() -> void:
    var pools := _registry()
    _check(pools.get("Fight") is Dictionary, "typed Fight pool present")
    if not pools.get("Fight") is Dictionary:
        return
    var fight: Dictionary = pools["Fight"]
    _check(fight.has(TRIPLE), "Fight/" + TRIPLE + " present by ID")
    if not fight.has(TRIPLE):
        return
    var binding = fight[TRIPLE]
    _check(binding is Dictionary and binding.size() == 2 and
        binding.get("schedule") == "res://data/encounters/%s.json" % TRIPLE and
        binding.get("enemy_ids") == TRIPLE_ROSTER,
        "canonical schedule path and ordered three-ID roster")
    if not binding is Dictionary:
        return
    var roster = binding.get("enemy_ids")
    _check(roster is Array and roster.size() == 3 and roster[0] != roster[1] and
        roster[1] != roster[2] and roster[0] != roster[2],
        "roster holds three distinct enemy IDs")
    # Authored max HP for the new roster, each catalog ID found exactly once.
    var catalog: Variant = JSON.parse_string(
        FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
    _check(catalog is Array, "authored run enemy catalog parses")
    if catalog is Array:
        var authored_hp := {"fray_scavenger": 14, "button_guard": 16, "spool_stalker": 14}
        for enemy_id in authored_hp:
            var records: Array = catalog.filter(
                func(entry: Dictionary) -> bool: return entry.get("id") == enemy_id)
            _check(records.size() == 1 and records[0].get("max_hp") == authored_hp[enemy_id],
                "authored %s max HP %d appears exactly once" % [enemy_id, authored_hp[enemy_id]])
    # Exactly one authoritative source per position, with the authored beats.
    var text := FileAccess.get_file_as_string(binding.get("schedule", ""))
    _check(not text.is_empty(), "new schedule file is readable on disk")
    var definitions := RunFightEncounterSelection._parse_schedule_text(text)
    _check(definitions.size() == 3, "new schedule parses to three source records")
    for position in [1, 2, 3]:
        var at_position: Array = definitions.filter(
            func(record: Dictionary) -> bool: return record.get("enemy_position") == position)
        _check(at_position.size() == 1,
            "exactly one source record at enemy_position %d" % position)
    var expected_definitions := []
    for source_index in range(3):
        expected_definitions.append({"enemy_position": source_index + 1,
            "pattern": _expected_actions()[TRIPLE][source_index]})
    _check(definitions == expected_definitions,
        "complete authored two-beat cycles for sources 1, 2 and 3 in order")
    _check(CombatEnemyIntents.new(definitions).is_valid(),
        "new schedule passes the authoritative intent validator")
    # Every earlier named binding keeps its own exact fields.
    var earlier_fight := {
        "starter_attacks": ["ragling", "ragling_guard"],
        "bobbin_skirmish": ["fray_scavenger", "spool_stalker"],
        "buttonhole_holdout": ["button_guard", "seam_ripper"],
        "guard_counterattack": ["ragling_guard", "button_guard"],
    }
    for encounter_id in earlier_fight:
        var earlier: Variant = fight.get(encounter_id)
        _check(earlier is Dictionary and earlier.size() == 2 and
            earlier.get("schedule") == "res://data/encounters/%s.json" % encounter_id and
            earlier.get("enemy_ids") == earlier_fight[encounter_id],
            "earlier Fight binding unchanged: " + encounter_id)
    var elite_pool: Variant = pools.get("Elite")
    if elite_pool is Dictionary and elite_pool.has("thimble_crossfire") \
            and elite_pool["thimble_crossfire"] is Dictionary:
        var elite: Dictionary = elite_pool["thimble_crossfire"]
        _check(elite.size() == 2 and
            elite.get("schedule") == "res://data/encounters/thimble_crossfire.json" and
            elite.get("enemy_ids") == ["button_guard", "seam_ripper"],
            "Elite/thimble_crossfire keeps its exact schedule and roster")
    else:
        _check(false, "typed Elite pool still holds thimble_crossfire")
    var boss_pool: Variant = pools.get("Boss")
    if boss_pool is Dictionary and boss_pool.has("patchwork_behemoth") \
            and boss_pool["patchwork_behemoth"] is Dictionary:
        var boss: Dictionary = boss_pool["patchwork_behemoth"]
        _check(boss.size() == 2 and
            boss.get("schedule") == "res://data/encounters/patchwork_behemoth.json" and
            boss.get("enemy_ids") == ["patchwork_behemoth"],
            "Boss/patchwork_behemoth keeps its exact schedule and roster")
    else:
        _check(false, "typed Boss pool still holds patchwork_behemoth")


## AC2/AC3: a genuine seeded legal Fight entered through the existing
## _entry_from_data path with a Fight-only single-candidate registry copy, so
## the new encounter is selected deterministically instead of by selector
## chance: exact actors, complete announced cycle, one selection call, and
## global-RNG, selector-cache and deep-copy isolation.
func _test_triple_spool_pinch_entry() -> void:
    var focused := _checked_focused_registry()
    if not focused.get("Fight") is Dictionary or not focused["Fight"].has(TRIPLE):
        return
    var service := RunAuthoredBattleEntry.new()
    var setup := _focused_setup(FIGHT_SEED)
    var state_before: int = setup["rng"].state
    seed(515015)
    var global_next := randi()
    seed(515015)
    var first := service._entry_from_data(setup["map"], setup["rng"],
        setup["selector"], focused)
    _check(randi() == global_next, "focused entry consumes no global RNG")
    setup["oracle"].randi_range(0, 0)
    _check(first.get("success") == true and first.get("encounter_id") == TRIPLE,
        "single-candidate registry selects the new Fight deterministically")
    _check(setup["rng"].state == state_before and
        setup["rng"].state == setup["after_choose"] and
        setup["rng"].state == setup["oracle"].state,
        "entry spends exactly the one single-candidate selection call of the run RNG")
    # Complete roster, HP/Block/art and the full nine-beat announced timeline.
    var snapshot := _verify_entry(first, "Fight", TRIPLE, "focused Fight")
    if snapshot.is_empty():
        return
    var declared: Array = first["definitions"]
    for position in [1, 2, 3]:
        var at_position: Array = declared.filter(
            func(record: Dictionary) -> bool: return record.get("enemy_position") == position)
        _check(at_position.size() == 1,
            "exactly one authoritative source at enemy position %d" % position)
    var actors: CombatEnemies = first["enemies"]
    _check(actors.get_enemy(1)["id"] == TRIPLE_ROSTER[0] and
        actors.get_enemy(2)["id"] == TRIPLE_ROSTER[1] and
        actors.get_enemy(3)["id"] == TRIPLE_ROSTER[2],
        "actor slots hold the ordered three distinct roster IDs")
    _check(actors.get_enemy(1)["max_hp"] == 14 and actors.get_enemy(2)["max_hp"] == 16 and
        actors.get_enemy(3)["max_hp"] == 14,
        "fresh actor max HP is the authored 14/16/14")
    _check(actors.get_enemy(1)["hp"] == 14 and actors.get_enemy(2)["hp"] == 16 and
        actors.get_enemy(3)["hp"] == 14 and actors.get_enemy(1)["block"] == 0 and
        actors.get_enemy(2)["block"] == 0 and actors.get_enemy(3)["block"] == 0,
        "fresh actors start at full HP and zero Block")
    # A returned result is fully isolated: mutation cannot poison re-entry.
    var cache_before: Dictionary = setup["selector"]._selected.duplicate(true)
    var cached_state: int = setup["rng"].state
    first["definitions"][0]["pattern"][0]["amount"] = 555
    first["definitions"][0]["pattern"].clear()
    first["encounter_id"] = "tampered"
    first["enemies"].apply_damage(1, 7)
    first["enemies"].gain_block(2, 3)
    var again := service._entry_from_data(setup["map"], setup["rng"],
        setup["selector"], focused)
    _check(again.get("success") == true and again.get("encounter_id") == TRIPLE and
        setup["rng"].state == cached_state and
        setup["selector"]._selected == cache_before,
        "cached re-entry succeeds with no new draw and an unchanged selector cache")
    _check(first["enemies"] != again["enemies"] and first["intents"] != again["intents"] and
        again["enemies"].get_enemy(1)["hp"] == 14 and
        again["enemies"].get_enemy(2)["block"] == 0 and
        again["intents"].get_intents() == _expected_actions_beat(TRIPLE, 0),
        "mutated first result cannot poison fresh actors, Block or turn-zero intents")
    var resnapshot := _verify_entry(again, "Fight", TRIPLE, "cached focused Fight")
    _check(not resnapshot.is_empty() and resnapshot == snapshot,
        "cached entry returns an independent full roster and announced timeline")
    # Two independent same-seed instances replay identically, beat for beat.
    var other := _focused_setup(FIGHT_SEED)
    var other_first := service._entry_from_data(other["map"], other["rng"],
        other["selector"], focused)
    other["oracle"].randi_range(0, 0)
    _check(other_first.get("success") == true and
        other_first.get("encounter_id") == snapshot["id"] and
        other["rng"].state == other["after_choose"] and
        other["rng"].state == setup["rng"].state and
        other["map"].get_floors() == setup["map"].get_floors() and
        other["map"].get_route() == setup["map"].get_route() and
        other["selector"]._selected == setup["selector"]._selected,
        "independent same-seed instance reproduces graph, route, choice, cache and run RNG")
    _check(other_first["enemies"].get_enemies() == snapshot["actors"],
        "independent instance reproduces the identical authoritative actors")
    var other_snapshot := _verify_entry(other_first, "Fight", TRIPLE,
        "independent focused Fight")
    _check(not other_snapshot.is_empty() and other_snapshot == snapshot,
        "two independent seeded instances announce and replay every beat identically")


## AC2: the focused entry's authoritative actors resolve both authored beats
## through the ordinary CombatEnemyPhase transaction, with the complete
## actor HP/Block ledger and recorded applied events, then the third
## announced beat wraps to the first.
func _test_triple_spool_pinch_phase() -> void:
    var focused := _checked_focused_registry()
    if not focused.get("Fight") is Dictionary or not focused["Fight"].has(TRIPLE):
        return
    var setup := _focused_setup(FIGHT_SEED)
    var entered := RunAuthoredBattleEntry.new()._entry_from_data(setup["map"],
        setup["rng"], setup["selector"], focused)
    _check(entered.get("success") == true and entered.get("encounter_id") == TRIPLE,
        "phase fixture enters the focused encounter")
    if not entered.get("success", false):
        return
    var party := _triple_party()
    var enemies: CombatEnemies = entered["enemies"]
    var intents: CombatEnemyIntents = entered["intents"]
    _check(party.get_hero(1)["id"] == "warden" and party.get_hero(2)["id"] == "seamstress" and
        party.get_hero(3)["id"] == "tinker" and
        party.get_hero(1)["hp"] == 40 and party.get_hero(2)["hp"] == 30 and
        party.get_hero(3)["hp"] == 26,
        "authored starter party: Warden 40, Seamstress 30, Tinker 26")
    _check(_hero_ledger(party) == [[40, 0], [30, 0], [26, 0]] and
        _enemy_ledger(enemies) == [[14, 0], [16, 0], [14, 0]],
        "fresh 40/30/26 heroes and fresh 14/16/14 enemies all start at zero Block")
    var phase := CombatEnemyPhase.new()
    var beat0: Array = intents.get_intents()
    _check(beat0 == _expected_actions_beat(TRIPLE, 0),
        "beat 0 announces all three sources in enemy-position order")
    var first := phase.execute_phase(party, enemies, beat0)
    _check(first.get("ok") == true and first.get("events") == TRIPLE_BEAT0_EVENTS,
        "beat 0 publishes the source-ordered applied events")
    _check(intents.get_intents() == beat0,
        "executing a phase never advances the announcement")
    _check(_hero_ledger(party) == [[40, 0], [29, 0], [25, 0]] and
        _enemy_ledger(enemies) == [[14, 0], [16, 2], [14, 0]],
        "beat 0 leaves Seamstress 29, Tinker 25 and Button Guard 2 Block")
    _check(intents.advance_turn(), "the schedule advances to beat 1")
    var beat1: Array = intents.get_intents()
    _check(beat1 == _expected_actions_beat(TRIPLE, 1),
        "beat 1 announces the second authored actions in order")
    var second := phase.execute_phase(party, enemies, beat1)
    _check(second.get("ok") == true and second.get("events") == TRIPLE_BEAT1_EVENTS,
        "beat 1 publishes the source-ordered applied events")
    _check(_hero_ledger(party) == [[39, 0], [28, 0], [25, 0]] and
        _enemy_ledger(enemies) == [[14, 1], [16, 2], [14, 0]],
        "beat 1 leaves Warden 39, Seamstress 28 and Fray Scavenger 1 Block")
    _check(intents.advance_turn() and intents.get_intents() == beat0,
        "the third announced beat wraps to the first beat exactly")


## AC3: a slain third source's announced action stays inert while the living
## positions 1 and 2 still resolve through the same ordinary phase transaction.
func _test_triple_spool_pinch_slain_source() -> void:
    var focused := _checked_focused_registry()
    if not focused.get("Fight") is Dictionary or not focused["Fight"].has(TRIPLE):
        return
    var setup := _focused_setup(FIGHT_SEED)
    var entered := RunAuthoredBattleEntry.new()._entry_from_data(setup["map"],
        setup["rng"], setup["selector"], focused)
    _check(entered.get("success") == true and entered.get("encounter_id") == TRIPLE,
        "slain-source fixture enters the focused encounter")
    if not entered.get("success", false):
        return
    var party := _triple_party()
    var enemies: CombatEnemies = entered["enemies"]
    var intents: CombatEnemyIntents = entered["intents"]
    _check(enemies.apply_damage(3, 14) and enemies.is_slain(3),
        "third source is slain before its announced attack")
    var announced: Array = intents.get_intents()
    _check(announced == _expected_actions_beat(TRIPLE, 0),
        "beat 0 still announces all three sources")
    var result := CombatEnemyPhase.new().execute_phase(party, enemies, announced)
    _check(result.get("ok") == true and result.get("events") == [
        {"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
        {"type": "block", "enemy_position": 2, "applied": true},
        {"type": "attack", "enemy_position": 3, "target_position": 3, "applied": false}],
        "slain source is inert while living positions 1 and 2 still resolve")
    _check(_hero_ledger(party) == [[40, 0], [29, 0], [26, 0]],
        "the slain source dealt no damage: only Seamstress took the first hit")
    _check(_enemy_ledger(enemies) == [[14, 0], [16, 2], [0, 0]],
        "slain slot keeps its position and gains no Block; Button Guard still blocks")


## AC3: missing or incorrect new bindings are rejected atomically, leaving
## map, party, selector cache and run RNG untouched, and a corrected retry
## then enters the encounter with exactly the one selection call.
func _test_triple_spool_pinch_rejection_and_retry() -> void:
    var focused := _checked_focused_registry()
    if not focused.get("Fight") is Dictionary or not focused["Fight"].has(TRIPLE):
        return
    var setup := _focused_setup(FIGHT_SEED)
    var map: RunMap = setup["map"]
    var rng: RandomNumberGenerator = setup["rng"]
    var selector: RunFightEncounterSelection = setup["selector"]
    var party := _triple_party()
    var party_before := party.get_heroes()
    var sources_before := _sources()
    var missing := focused.duplicate(true)
    missing["Fight"].erase(TRIPLE)
    _reject(map, rng, selector, missing, "triple_spool_pinch missing binding")
    var wrong_path := focused.duplicate(true)
    wrong_path["Fight"][TRIPLE]["schedule"] = "res://data/encounters/bobbin_skirmish.json"
    _reject(map, rng, selector, wrong_path,
        "triple_spool_pinch binding with another encounter's schedule")
    var wrong_roster := focused.duplicate(true)
    wrong_roster["Fight"][TRIPLE]["enemy_ids"] = [
        "fray_scavenger", "button_guard", "spool_stalker", "seam_ripper"]
    _reject(map, rng, selector, wrong_roster,
        "triple_spool_pinch roster/schedule arity mismatch")
    var unknown_enemy := focused.duplicate(true)
    unknown_enemy["Fight"][TRIPLE]["enemy_ids"][0] = "unknown_normal"
    _reject(map, rng, selector, unknown_enemy,
        "triple_spool_pinch unknown roster ID")
    var duplicate_enemy := focused.duplicate(true)
    duplicate_enemy["Fight"][TRIPLE]["enemy_ids"][2] = "fray_scavenger"
    _reject(map, rng, selector, duplicate_enemy,
        "triple_spool_pinch duplicate roster ID")
    _check(party.get_heroes() == party_before, "party unchanged by every rejection")
    _check(rng.state == setup["after_choose"], "no selection draw spent by any rejection")
    var good := RunAuthoredBattleEntry.new()._entry_from_data(map, rng, selector, focused)
    _check(good.get("success") == true and good.get("encounter_id") == TRIPLE,
        "corrected retry enters triple_spool_pinch")
    setup["oracle"].randi_range(0, 0)
    _check(rng.state == setup["after_choose"] and rng.state == setup["oracle"].state,
        "corrected retry spends exactly the one selection call")
    _check(party.get_heroes() == party_before, "successful entry never mutates the party")
    _check(not _verify_entry(good, "Fight", TRIPLE, "corrected retry").is_empty(),
        "corrected retry produces fully verified actors and intents")
    _check(_sources() == sources_before,
        "authored sources unchanged across every rejection and the retry")


## The focused Fight-only registry copy, checked so a missing binding fails
## loudly instead of letting a focused test pass vacuously.
func _checked_focused_registry() -> Dictionary:
    var focused := _focused_registry(_registry())
    var ok: bool = focused.get("Fight") is Dictionary and focused["Fight"].has(TRIPLE)
    _check(ok, "focused single-candidate registry holds " + TRIPLE)
    return focused


## A Fight-only registry copy holding only the new candidate, so the seeded
## selection cannot land on another encounter by chance.
func _focused_registry(registry: Dictionary) -> Dictionary:
    var focused := {"Fight": {}}
    if registry.get("Fight") is Dictionary and registry["Fight"].has(TRIPLE):
        focused["Fight"][TRIPLE] = registry["Fight"][TRIPLE]
    return focused


## A genuine generated seed whose opening legal set contains a real Fight,
## committed on two independent maps. The oracle mirrors generate + choose
## exactly; each caller additionally mirrors the selector's single-candidate
## selection call when it compares run-RNG accounting.
func _focused_setup(seed_value: int) -> Dictionary:
    var rng := _rng(seed_value)
    var oracle := _rng(seed_value)
    var map := RunMap.new()
    var oracle_map := RunMap.new()
    _check(map.generate(rng) and oracle_map.generate(oracle) and
        map.get_floors() == oracle_map.get_floors(),
        "focused: identical real generated graphs")
    var id := _opening(map)
    _check(not id.is_empty() and map.get_legal_choices().has(id) and
        map.choose_node(id) and oracle_map.choose_node(id),
        "focused: real legal Fight committed on both independent maps")
    var after_choose: int = rng.state
    _check(after_choose != _rng(seed_value).state and after_choose == oracle.state,
        "focused: generation consumed run RNG and both maps stay in step")
    return {"map": map, "rng": rng, "oracle": oracle, "node": id,
        "after_choose": after_choose,
        "selector": RunFightEncounterSelection.new()}


## The authored starter party: Warden 40, Seamstress 30, Tinker 26, all fresh.
## JSON whole numbers arrive as floats, so they are verified integral and
## normalized exactly like the shared schedule parser does before construction.
func _triple_party() -> CombatParty:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PARTY_PATH))
    _check(parsed is Array, "authored starter party parses as an array")
    var authored_hp := {"warden": 40, "seamstress": 30, "tinker": 26}
    var ordered: Array = []
    if parsed is Array:
        for id in ["warden", "seamstress", "tinker"]:
            var records: Array = parsed.filter(
                func(entry: Dictionary) -> bool: return entry.get("id") == id)
            _check(records.size() == 1, "authored hero appears exactly once: " + id)
            if records.size() == 1:
                var record: Dictionary = records[0]
                _check(RunFightEncounterSelection._coerce_integral_field(record, "max_hp")
                    and record["max_hp"] == authored_hp[id],
                    "authored %s carries its exact integral max HP %d" % [id, authored_hp[id]])
                ordered.append(record)
    var party := CombatParty.new(ordered)
    _check(party.is_valid(), "authored starter party is a valid three-hero fixture")
    return party


## [hp, block] for every hero position 1-3.
func _hero_ledger(party: CombatParty) -> Array:
    var ledger := []
    for position in range(1, 4):
        var hero: Dictionary = party.get_hero(position)
        ledger.append([hero.get("hp"), hero.get("block")])
    return ledger


## [hp, block] for every enemy position 1-3.
func _enemy_ledger(enemies: CombatEnemies) -> Array:
    var ledger := []
    for position in range(1, 4):
        var enemy: Dictionary = enemies.get_enemy(position)
        ledger.append([enemy.get("hp"), enemy.get("block")])
    return ledger


## AC1: bind the shipped positional schedule without changing the other typed
## encounters; per-name assertions in _test_authored_bindings cover every prior
## Fight/Elite/Boss source and all authored beats without fixed pool totals.
func _test_seamshift_tripwire_content() -> void:
    var pools := _registry()
    _check(pools.get("Fight") is Dictionary and pools["Fight"].has(SEAMSHIFT),
        "Fight/seamshift_tripwire has an explicit live registry binding")
    if not pools.get("Fight") is Dictionary or not pools["Fight"].has(SEAMSHIFT):
        return
    var binding: Variant = pools["Fight"][SEAMSHIFT]
    _check(binding is Dictionary and binding.size() == 2 and
        binding.get("schedule") == "res://data/encounters/seamshift_tripwire.json" and
        binding.get("enemy_ids") == SEAMSHIFT_ROSTER,
        "Seamshift canonical schedule and ordered three-slot unique enemy roster")
    if not binding is Dictionary:
        return
    var definitions := RunFightEncounterSelection._parse_schedule_text(
        FileAccess.get_file_as_string(binding["schedule"]))
    var expected := []
    for position in [1, 2, 3]:
        var matches: Array = definitions.filter(
            func(record: Dictionary) -> bool: return record.get("enemy_position") == position)
        _check(matches.size() == 1, "Seamshift has one source at slot %d" % position)
        expected.append({"enemy_position": position,
            "pattern": _expected_actions()[SEAMSHIFT][position - 1]})
    _check(definitions == expected and CombatEnemyIntents.new(definitions).is_valid(),
        "Seamshift exact shove/Exposed/attack and subsequent full three-beat cycles")
    var catalog: Variant = JSON.parse_string(
        FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
    _check(catalog is Array, "Seamshift normal-enemy catalog parses")
    if catalog is Array:
        for enemy_id in SEAMSHIFT_ROSTER:
            var matches: Array = catalog.filter(
                func(record: Dictionary) -> bool: return record.get("id") == enemy_id)
            _check(matches.size() == 1, "Seamshift authored actor appears once: " + enemy_id)
            if matches.size() == 1:
                var record: Dictionary = matches[0]
                _check(RunFightEncounterSelection._coerce_integral_field(record, "max_hp")
                    and record["max_hp"] == HP[enemy_id],
                    "Seamshift authored actor %s has exact HP %d" % [enemy_id, HP[enemy_id]])


## Find a reproducible seed for the ACTUAL entire on-disk Fight pool by
## replaying generation, legal opening choice, and exactly one sorted draw.
## Never substitute a one-entry registry for this public live selection test.
func _find_full_pool_seed_for(target_id: String) -> int:
    var pools := _registry()
    if not pools.get("Fight") is Dictionary or not pools["Fight"].has(target_id):
        return -1
    var ids: Array = pools["Fight"].keys()
    ids.sort()
    for seed_value in range(1, 257):
        var rng := _rng(seed_value)
        var map := RunMap.new()
        if not map.generate(rng):
            continue
        var node := _opening(map)
        if node.is_empty() or not map.choose_node(node):
            continue
        if ids[rng.randi_range(0, ids.size() - 1)] == target_id:
            return seed_value
    return -1


## AC2/AC3: a real chosen Fight, real on-disk full-pool entry, and real combat
## services, not just a synthetic selector result or an in-memory encounter.
func _test_seamshift_full_pool_entry() -> void:
    var seed_value := _find_full_pool_seed_for(SEAMSHIFT)
    _check(seed_value > 0, "a reproducible generated Fight selects Seamshift from full disk pool")
    if seed_value < 0:
        return
    var sources_before := _sources()
    var setup := _focused_setup(seed_value)
    var map: RunMap = setup["map"]
    var rng: RandomNumberGenerator = setup["rng"]
    var selector: RunFightEncounterSelection = setup["selector"]
    var pool := _registry()
    var invalid := pool.duplicate(true)
    invalid["Fight"][SEAMSHIFT]["enemy_ids"] = ["seam_ripper", "spool_stalker"]
    _reject(map, rng, selector, invalid, "invalid Seamshift binding fails full pool before RNG")
    var ids: Array = pool["Fight"].keys()
    ids.sort()
    var oracle_id: String = ids[setup["oracle"].randi_range(0, ids.size() - 1)]
    _check(oracle_id == SEAMSHIFT and map.get_node(setup["node"]).get("type") == "Fight",
        "one sorted oracle draw on legitimate selected Fight predicts Seamshift")
    var service := RunAuthoredBattleEntry.new()
    seed(515015)
    var global_next := randi()
    seed(515015)
    var first := service.entry_current_battle(map, rng, selector)
    _check(randi() == global_next and rng.state == setup["oracle"].state,
        "public full-pool entry spends one run draw and no global RNG")
    var snapshot := _verify_entry(first, "Fight", SEAMSHIFT, "public Seamshift Fight")
    if snapshot.is_empty():
        return
    var cache_before := selector._selected.duplicate(true)
    var cached_rng_state := rng.state
    _check(selector._selected.has(setup["node"]) and
        selector._selected[setup["node"]]["encounter_id"] == SEAMSHIFT,
        "public selector caches the chosen Seamshift node by ID")
    first["definitions"][0]["pattern"][0]["amount"] = 777
    first["definitions"][0]["pattern"].clear()
    first["enemies"].gain_block(1, 5)
    first["enemies"].apply_damage(3, 4)
    first["encounter_id"] = "tampered"
    var again := service.entry_current_battle(map, rng, selector)
    _check(again.get("success") == true and again.get("encounter_id") == SEAMSHIFT and
        rng.state == cached_rng_state and selector._selected == cache_before and
        first["enemies"] != again["enemies"] and first["intents"] != again["intents"],
        "public cached replay returns detached actors/intents with zero extra draws")
    var again_snapshot := _verify_entry(again, "Fight", SEAMSHIFT, "cached Seamshift Fight")
    _check(not again_snapshot.is_empty() and again_snapshot == snapshot,
        "mutated public result cannot poison any actor or the nine-beat authored cycle")
    var replay := _focused_setup(seed_value)
    var replay_entry := RunAuthoredBattleEntry.new().entry_current_battle(
        replay["map"], replay["rng"], replay["selector"])
    _check(replay_entry.get("success") and replay_entry.get("encounter_id") == SEAMSHIFT and
        replay["rng"].state == cached_rng_state and
        replay["selector"]._selected == cache_before,
        "independent same-seed public entry repeats selection, cache and RNG")
    _check(_verify_entry(replay_entry, "Fight", SEAMSHIFT, "replayed Seamshift Fight") == snapshot,
        "independent run repeats exact three actors and nine ordered announcements")

    # Phase uses a fresh public entry's authoritative actors and intents.
    var combat := service.entry_current_battle(map, rng, selector)
    _check(combat.get("success") and combat.get("encounter_id") == SEAMSHIFT,
        "real typed entry supplies the actors to the combat phase")
    if not combat.get("success", false):
        return
    var party := _triple_party()
    _check(CombatStartingBlock.new(party).apply() and
        party.get_hero(1).get("block") == 6, "Warden receives exact opening six Block")
    var announced: Array = combat["intents"].get_intents()
    _check(announced == _expected_actions_beat(SEAMSHIFT, 0),
        "public entry announces shove, Exposed, attack in enemy-source order")
    var resolved := CombatEnemyPhase.new().execute_phase(party, combat["enemies"], announced)
    _check(resolved.get("ok") == true and resolved.get("events") == [
        {"type": "shove", "enemy_position": 1, "target_position": 1,
            "direction": 1, "applied": true},
        {"type": "debuff", "enemy_position": 2, "target_position": 2,
            "status": "exposed", "applied": true},
        {"type": "attack", "enemy_position": 3, "target_position": 2, "applied": true}],
        "public actors resolve shove then Exposed 1 then six-damage attack")
    _check(party.get_hero(1).get("id") == "seamstress" and
        party.get_hero(2).get("id") == "warden" and
        party.get_hero(2).get("hp") == 40 and party.get_hero(2).get("block") == 0 and
        party.get_hero(2).get("statuses", {}) == {"exposed": 1} and
        party.get_hero(3).get("id") == "tinker" and
        _enemy_ledger(combat["enemies"]) == [[18, 0], [14, 0], [14, 0]],
        "Warden displaced to middle, marked Exposed, loses six Block not HP")

    var prior_seed := _find_full_pool_seed_for("starter_attacks")
    _check(prior_seed > 0, "an earlier Fight remains selectable through full disk pool")
    if prior_seed > 0:
        var prior := _focused_setup(prior_seed)
        var prior_entry := service.entry_current_battle(
            prior["map"], prior["rng"], prior["selector"])
        _check(not _verify_entry(prior_entry, "Fight", "starter_attacks",
            "earlier full-pool Fight").is_empty(),
            "real selection still reaches and fully verifies earlier Fight")
    _check(_sources() == sources_before, "Seamshift selection never mutates source JSON")


## AC1: inspect per-ID Elite bindings, schedules and four-catalog enemy records
## without asserting a fixed total or complete ordered ID list.
func _test_m04_elite_pool_bindings() -> void:
    _check(RunAuthoredBattleEntry.CATALOG_PATHS == [
        "res://data/enemies/starter_enemies.json",
        "res://data/enemies/run_enemies.json",
        "res://data/enemies/boss.json",
        "res://data/enemies/m04_elites.json",
    ], "RunAuthoredBattleEntry loads all four enemy catalogs with boss.json at index 2")
    var pools := _registry()
    _check(pools.get("Elite") is Dictionary, "typed Elite pool is a Dictionary")
    if not pools.get("Elite") is Dictionary:
        return
    var elite_pool: Dictionary = pools["Elite"]
    var expected_elites := {
        "thimble_crossfire": ["button_guard", "seam_ripper"],
        "needle_marshal_elite": ["needle_marshal", "ragling_guard"],
        "spool_hexer_elite": ["spool_hexer", "spool_stalker"],
    }
    for elite_id in expected_elites:
        _check(elite_pool.has(elite_id), "Elite/" + elite_id + " present by ID")
        if not elite_pool.has(elite_id):
            continue
        var binding: Variant = elite_pool[elite_id]
        var expected_roster: Array = expected_elites[elite_id]
        _check(binding is Dictionary and binding.size() == 2 and
            binding.get("schedule") == "res://data/encounters/%s.json" % elite_id and
            binding.get("enemy_ids") == expected_roster,
            "Elite/" + elite_id + " canonical schedule and ordered two-enemy roster")
        if not binding is Dictionary:
            continue
        var roster: Variant = binding.get("enemy_ids")
        _check(roster is Array and roster.size() == 2 and roster[0] != roster[1],
            "Elite/" + elite_id + " holds two distinct enemy IDs")
        var text := FileAccess.get_file_as_string(binding.get("schedule", ""))
        _check(not text.is_empty(), "Elite/" + elite_id + " schedule readable on disk")
        var definitions := RunFightEncounterSelection._parse_schedule_text(text)
        _check(definitions.size() == 2, "Elite/" + elite_id + " has two source records")
        var expected_defs := []
        for pos in [1, 2]:
            var matches: Array = definitions.filter(
                func(rec: Dictionary) -> bool: return rec.get("enemy_position") == pos)
            _check(matches.size() == 1,
                "Elite/%s has one source at enemy_position %d" % [elite_id, pos])
            expected_defs.append({
                "enemy_position": pos,
                "pattern": _expected_actions()[elite_id][pos - 1],
            })
        _check(definitions == expected_defs and CombatEnemyIntents.new(definitions).is_valid(),
            "Elite/" + elite_id + " matches full authored action cycles and passes validator")

    var catalog_checks := [
        ["res://data/enemies/m04_elites.json", "needle_marshal", "Needle Marshal", 28,
            "res://assets/paper/enemies/needle_marshal.png"],
        ["res://data/enemies/m04_elites.json", "spool_hexer", "Spool Hexer", 24,
            "res://assets/paper/enemies/spool_hexer.png"],
        ["res://data/enemies/starter_enemies.json", "ragling_guard", "Guard Ragling", 12,
            "res://assets/paper/enemies/ragling_guard.png"],
        ["res://data/enemies/run_enemies.json", "spool_stalker", "Spool Stalker", 14,
            "res://assets/paper/enemies/spool_stalker.png"],
    ]
    for spec in catalog_checks:
        var parsed := RunTypedBattleRoster._parse_catalog_text(
            FileAccess.get_file_as_string(spec[0]))
        _check(not parsed.is_empty(), "catalog parses cleanly: " + spec[0])
        var matches: Array = parsed.filter(
            func(rec: Dictionary) -> bool: return rec.get("id") == spec[1])
        _check(matches.size() == 1, "exactly one record for " + spec[1] + " in " + spec[0])
        if matches.size() == 1:
            var rec: Dictionary = matches[0]
            _check(rec.get("name") == spec[2] and rec.get("max_hp") is int and
                rec.get("max_hp") == spec[3] and rec.get("art_path") == spec[4],
                "exact identity, integral HP, and art_path for " + spec[1])


## Deterministically find a seed and legal connected path ending at a committed
## RunMap Elite node within a bounded seed search.
func _find_committed_elite_fixture() -> Dictionary:
    for seed_value in range(1, 129):
        var rng := _rng(seed_value)
        var map := RunMap.new()
        if not map.generate(rng):
            continue
        for node_id in map.get_legal_choices():
            if map.get_node(node_id).get("type") == "Elite":
                return {"seed": seed_value, "path": [node_id]}
        var frontier := []
        for node_id in map.get_legal_choices():
            frontier.append([node_id])
        while not frontier.is_empty():
            var path: Array = frontier.pop_front()
            var last_id: String = path.back()
            if map.get_node(last_id).get("type") == "Elite":
                return {"seed": seed_value, "path": path}
            for next_id in map.get_node(last_id).get("outgoing", []):
                var next_path: Array = path.duplicate()
                next_path.append(next_id)
                frontier.append(next_path)
    return {}


func _elite_setup(seed_value: int, path: Array) -> Dictionary:
    var rng := _rng(seed_value)
    var oracle := _rng(seed_value)
    var map := RunMap.new()
    var oracle_map := RunMap.new()
    _check(map.generate(rng) and oracle_map.generate(oracle) and
        map.get_floors() == oracle_map.get_floors(),
        "Elite setup: identical generated graphs for seed %d" % seed_value)
    var expected_route: Array[String] = []
    for step_id in path:
        _check(map.get_legal_choices().has(step_id) and
            oracle_map.get_legal_choices().has(step_id) and
            map.choose_node(step_id) and oracle_map.choose_node(step_id),
            "Elite setup: commits legal connected node " + str(step_id))
        expected_route.append(step_id)
    var current_id := map.get_current_node_id()
    _check(not current_id.is_empty() and current_id == path.back() and
        map.get_node(current_id).get("type") == "Elite" and
        map.get_route() == expected_route and
        oracle_map.get_route() == expected_route and
        rng.state == oracle.state,
        "Elite setup: current committed node is a genuine RunMap Elite")
    return {
        "map": map,
        "oracle_map": oracle_map,
        "rng": rng,
        "oracle": oracle,
        "node": current_id,
        "route": expected_route,
        "after_choose": rng.state,
        "selector": RunFightEncounterSelection.new(),
    }


## AC2/AC3: direct typed-entry test for each of needle_marshal_elite and
## spool_hexer_elite on a true committed RunMap Elite node using an otherwise
## copied production registry containing only the target Elite candidate.
func _test_m04_elite_direct_entries() -> void:
    var fixture := _find_committed_elite_fixture()
    _check(not fixture.is_empty(), "bounded seed search finds a legal RunMap Elite path")
    if fixture.is_empty():
        return
    var seed_value: int = fixture["seed"]
    var path: Array = fixture["path"]
    var base_registry := _registry()
    if not base_registry.get("Elite") is Dictionary:
        return

    for elite_id in ["needle_marshal_elite", "spool_hexer_elite"]:
        _check(base_registry["Elite"].has(elite_id),
            "production registry contains " + elite_id)
        if not base_registry["Elite"].has(elite_id):
            continue
        var focused := base_registry.duplicate(true)
        focused["Elite"] = {elite_id: base_registry["Elite"][elite_id].duplicate(true)}
        var sources_before := _sources()
        var setup := _elite_setup(seed_value, path)
        var service := RunAuthoredBattleEntry.new()
        seed(515015)
        var global_next := randi()
        seed(515015)
        var first := service._entry_from_data(
            setup["map"], setup["rng"], setup["selector"], focused)
        _check(randi() == global_next, elite_id + " direct entry consumes no global RNG")
        setup["oracle"].randi_range(0, 0)
        _check(first.get("success") == true and first.get("node_type") == "Elite" and
            first.get("encounter_id") == elite_id,
            elite_id + " direct entry selects target Elite encounter")
        _check(setup["rng"].state == setup["after_choose"] and
            setup["rng"].state == setup["oracle"].state and
            setup["map"].get_route() == setup["route"],
            elite_id + " spends exactly the one single-candidate draw and preserves route")

        var expected_ids: Array = BINDINGS["Elite"][elite_id]
        var enemies: CombatEnemies = first.get("enemies")
        var intents: CombatEnemyIntents = first.get("intents")
        _check(enemies is CombatEnemies and enemies.is_valid() and
            enemies.get_enemies().size() == 2 and
            intents is CombatEnemyIntents and intents.is_valid(),
            elite_id + " produces valid two-source CombatEnemies and CombatEnemyIntents")
        if enemies is CombatEnemies and enemies.is_valid():
            for slot in [1, 2]:
                var actor: Dictionary = enemies.get_enemy(slot)
                var expected_enemy_id: String = expected_ids[slot - 1]
                _check(actor.get("id") == expected_enemy_id and
                    actor.get("name") == NAMES[expected_enemy_id] and
                    actor.get("position") == slot and
                    actor.get("max_hp") == HP[expected_enemy_id] and
                    actor.get("hp") == HP[expected_enemy_id] and
                    actor.get("block") == 0 and
                    actor.get("art_path") == ART_PATHS[expected_enemy_id],
                    "%s slot %d exact ID/name/position/HP/zero Block/art" % [elite_id, slot])

        # Verify full joint cycle including wraparound on a fresh intent scheduler.
        var period := 4 if elite_id == "needle_marshal_elite" else 12
        var full_cycle := CombatEnemyIntents.new(first["definitions"])
        _check(full_cycle.is_valid(), elite_id + " detached definitions build valid intents")
        for step in range(period + 1):
            _check(full_cycle.get_intents() == _expected_actions_beat(elite_id, step),
                "%s full cycle beat %d (including wraparound)" % [elite_id, step])
            _check(full_cycle.advance_turn(), "%s advances at step %d" % [elite_id, step])

        var snapshot := _verify_entry(first, "Elite", elite_id, "focused Elite " + elite_id)
        if snapshot.is_empty():
            continue

        # Verify detached copies and cached re-entry with zero extra RNG draws.
        var cache_before: Dictionary = setup["selector"]._selected.duplicate(true)
        var cached_rng_state: int = setup["rng"].state
        first["definitions"][0]["pattern"][0]["amount"] = 888
        first["definitions"][0]["pattern"].clear()
        first["enemies"].apply_damage(1, 5)
        first["enemies"].gain_block(2, 4)
        first["encounter_id"] = "tampered"
        var second := service._entry_from_data(
            setup["map"], setup["rng"], setup["selector"], focused)
        _check(second.get("success") == true and second.get("node_type") == "Elite" and
            second.get("encounter_id") == elite_id and
            setup["rng"].state == cached_rng_state and
            setup["selector"]._selected == cache_before,
            elite_id + " cached re-entry succeeds with no extra RNG draw or cache drift")
        _check(first["enemies"] != second["enemies"] and
            first["intents"] != second["intents"] and
            second["enemies"].get_enemy(1)["hp"] == HP[expected_ids[0]] and
            second["enemies"].get_enemy(2)["block"] == 0 and
            second["intents"].get_intents() == _expected_actions_beat(elite_id, 0),
            elite_id + " mutated first result cannot affect fresh actors or intents")
        var second_snapshot := _verify_entry(
            second, "Elite", elite_id, "cached Elite " + elite_id)
        _check(not second_snapshot.is_empty() and second_snapshot == snapshot,
            elite_id + " cached re-entry produces identical independent snapshot")

        # Independent replay with the same seed matches RNG, graph, route, cache and actors.
        var replay := _elite_setup(seed_value, path)
        var replay_first := RunAuthoredBattleEntry.new()._entry_from_data(
            replay["map"], replay["rng"], replay["selector"], focused)
        replay["oracle"].randi_range(0, 0)
        _check(replay_first.get("success") == true and
            replay_first.get("encounter_id") == elite_id and
            replay["rng"].state == cached_rng_state and
            replay["rng"].state == replay["oracle"].state and
            replay["map"].get_floors() == setup["map"].get_floors() and
            replay["map"].get_route() == setup["map"].get_route() and
            replay["selector"]._selected == setup["selector"]._selected,
            elite_id + " independent same-seed replay matches RNG, graph, route and cache")
        var replay_snapshot := _verify_entry(
            replay_first, "Elite", elite_id, "replayed Elite " + elite_id)
        _check(not replay_snapshot.is_empty() and replay_snapshot == snapshot,
            elite_id + " independent same-seed replay matches actors and timeline")

        # Verify authoritative CombatEnemyPhase execution on assembled Elite actors/intents.
        var combat_entry := service._entry_from_data(
            setup["map"], setup["rng"], setup["selector"], focused)
        _check(combat_entry.get("success") == true and
            setup["rng"].state == cached_rng_state,
            elite_id + " phase fixture reuses cached selection without extra RNG")
        if combat_entry.get("success", false):
            var party := _triple_party()
            _check(CombatStartingBlock.new(party).apply() and
                party.get_hero(1).get("block") == 6,
                elite_id + " Warden starts with 6 opening Block")
            var phase := CombatEnemyPhase.new()
            var phase_enemies: CombatEnemies = combat_entry["enemies"]
            var phase_intents: CombatEnemyIntents = combat_entry["intents"]
            for step in range(4):
                var announced: Array = phase_intents.get_intents()
                _check(announced == _expected_actions_beat(elite_id, step),
                    "%s phase announces beat %d" % [elite_id, step])
                var res := phase.execute_phase(party, phase_enemies, announced)
                _check(res.get("ok") == true and res.get("events", []).size() == 2,
                    "%s phase resolves beat %d" % [elite_id, step])
                _check(phase_intents.advance_turn(),
                    "%s phase advances beat %d" % [elite_id, step])
            if elite_id == "needle_marshal_elite":
                _check(party.get_hero(1).get("id") == "warden" and
                    party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 3 and
                    party.get_hero(2).get("id") == "tinker" and party.get_hero(2).get("hp") == 21 and
                    party.get_hero(3).get("id") == "seamstress" and party.get_hero(3).get("hp") == 29 and
                    phase_enemies.get_enemy(1).get("hp") == 28 and phase_enemies.get_enemy(1).get("block") == 3 and
                    phase_enemies.get_enemy(2).get("hp") == 12 and phase_enemies.get_enemy(2).get("block") == 4,
                    "needle_marshal_elite four-beat phase applies attack, buff, shove swap 2/3, and escort block/attack")
            else:
                _check(party.get_hero(1).get("id") == "warden" and
                    party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 2 and
                    party.get_hero(1).get("statuses", {}) == {"exposed": 1} and
                    party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 26 and
                    party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 24 and
                    party.get_hero(3).get("statuses", {}) == {"weak": 1} and
                    CombatStatuses.new().adjusted_attack_damage(4,
                        party.get_hero(3).get("statuses", {}), {}) == 3 and
                    phase_enemies.get_enemy(1).get("hp") == 24 and phase_enemies.get_enemy(1).get("block") == 0 and
                    phase_enemies.get_enemy(2).get("hp") == 14 and phase_enemies.get_enemy(2).get("block") == 2,
                    "spool_hexer_elite four-beat phase applies Exposed +50% incoming, Weak -25% outgoing, and escort cycle")

        _check(_sources() == sources_before,
            elite_id + " direct entry and replay leave all source JSON unchanged")


## AC3: production full-pool seeded Elite selection reads the actual registered
## Elite IDs, sorts them before the single RNG draw, caches without redraw, and
## replays identically from the same seed.
func _test_m04_elite_full_pool_selection() -> void:
    var fixture := _find_committed_elite_fixture()
    _check(not fixture.is_empty(), "full-pool Elite test has a legal Elite route")
    if fixture.is_empty():
        return
    var seed_value: int = fixture["seed"]
    var path: Array = fixture["path"]
    var pools := _registry()
    if not pools.get("Elite") is Dictionary:
        return
    for required_id in ["thimble_crossfire", "needle_marshal_elite", "spool_hexer_elite"]:
        _check(pools["Elite"].has(required_id),
            "full Elite pool includes " + required_id)
    var sorted_ids: Array = pools["Elite"].keys()
    sorted_ids.sort()
    var sources_before := _sources()
    var setup := _elite_setup(seed_value, path)
    var expected_id: String = sorted_ids[setup["oracle"].randi_range(0, sorted_ids.size() - 1)]
    var service := RunAuthoredBattleEntry.new()
    seed(515015)
    var global_next := randi()
    seed(515015)
    var first := service.entry_current_battle(
        setup["map"], setup["rng"], setup["selector"])
    _check(randi() == global_next, "production Elite selection consumes no global RNG")
    _check(first.get("success") == true and first.get("node_type") == "Elite" and
        first.get("encounter_id") == expected_id and
        setup["rng"].state == setup["oracle"].state,
        "production Elite selection draws once from sorted Elite IDs")
    var snapshot := _verify_entry(first, "Elite", expected_id, "production full-pool Elite")
    if snapshot.is_empty():
        return
    var cache_before: Dictionary = setup["selector"]._selected.duplicate(true)
    var cached_rng_state: int = setup["rng"].state
    first["definitions"][0]["pattern"][0]["amount"] = 777
    first["definitions"][0]["pattern"].clear()
    first["enemies"].apply_damage(1, 6)
    first["enemies"].gain_block(2, 3)
    first["encounter_id"] = "tampered"
    var second := service.entry_current_battle(
        setup["map"], setup["rng"], setup["selector"])
    _check(second.get("success") == true and second.get("encounter_id") == expected_id and
        setup["rng"].state == cached_rng_state and
        setup["selector"]._selected == cache_before and
        first["enemies"] != second["enemies"] and first["intents"] != second["intents"],
        "cached production Elite selection consumes no extra RNG and returns fresh instances")
    var second_snapshot := _verify_entry(
        second, "Elite", expected_id, "cached production full-pool Elite")
    _check(not second_snapshot.is_empty() and second_snapshot == snapshot,
        "cached production Elite selection matches original unmodified snapshot")

    var replay := _elite_setup(seed_value, path)
    var replay_entry := RunAuthoredBattleEntry.new().entry_current_battle(
        replay["map"], replay["rng"], replay["selector"])
    _check(replay_entry.get("success") == true and
        replay_entry.get("encounter_id") == expected_id and
        replay["rng"].state == cached_rng_state and
        replay["map"].get_floors() == setup["map"].get_floors() and
        replay["map"].get_route() == setup["map"].get_route() and
        replay["selector"]._selected == cache_before,
        "independent same-seed production Elite selection replays identically")
    var replay_snapshot := _verify_entry(
        replay_entry, "Elite", expected_id, "replayed production full-pool Elite")
    _check(not replay_snapshot.is_empty() and replay_snapshot == snapshot,
        "independent same-seed production Elite replay matches actors and timeline")
    _check(_sources() == sources_before,
        "production full-pool Elite selection leaves all source JSON unchanged")


## AC3/AC4: malformed Elite candidates fail closed before RNG/cache/map mutation;
## a malformed other-kind pool remains isolated; an Elite enemy ID cannot be
## assembled as a Boss catalog entry.
func _test_m04_elite_rejections_and_isolation() -> void:
    var fixture := _find_committed_elite_fixture()
    _check(not fixture.is_empty(), "Elite rejection test has a legal Elite route")
    if fixture.is_empty():
        return
    var seed_value: int = fixture["seed"]
    var path: Array = fixture["path"]
    var registry := _registry()
    var setup := _elite_setup(seed_value, path)
    var map: RunMap = setup["map"]
    var rng: RandomNumberGenerator = setup["rng"]
    var selector: RunFightEncounterSelection = setup["selector"]

    _reject(map, rng, selector, {}, "Elite missing current kind")
    _reject(map, rng, selector, {"Elite": {}}, "Elite empty pool")
    var null_entry := registry.duplicate(true)
    null_entry["Elite"]["needle_marshal_elite"] = null
    _reject(map, rng, selector, null_entry, "Elite null candidate entry")

    var unknown_marshal := registry.duplicate(true)
    unknown_marshal["Elite"]["needle_marshal_elite"]["enemy_ids"][0] = "unknown_elite"
    _reject(map, rng, selector, unknown_marshal, "unknown Elite enemy ID in needle_marshal_elite")

    var unknown_escort := registry.duplicate(true)
    unknown_escort["Elite"]["spool_hexer_elite"]["enemy_ids"][1] = "unknown_escort"
    _reject(map, rng, selector, unknown_escort, "unknown escort enemy ID in spool_hexer_elite")

    var boss_in_elite := registry.duplicate(true)
    boss_in_elite["Elite"]["needle_marshal_elite"]["enemy_ids"][0] = "patchwork_behemoth"
    _reject(map, rng, selector, boss_in_elite, "Boss catalog ID in Elite roster")

    var dup_marshal := registry.duplicate(true)
    dup_marshal["Elite"]["needle_marshal_elite"]["enemy_ids"] = [
        "needle_marshal", "needle_marshal"]
    _reject(map, rng, selector, dup_marshal, "duplicate roster ID in needle_marshal_elite")

    var dup_hexer := registry.duplicate(true)
    dup_hexer["Elite"]["spool_hexer_elite"]["enemy_ids"] = [
        "spool_hexer", "spool_hexer"]
    _reject(map, rng, selector, dup_hexer, "duplicate roster ID in spool_hexer_elite")

    var short_marshal := registry.duplicate(true)
    short_marshal["Elite"]["needle_marshal_elite"]["enemy_ids"] = ["needle_marshal"]
    _reject(map, rng, selector, short_marshal, "wrong arity (1) in needle_marshal_elite")

    var long_marshal := registry.duplicate(true)
    long_marshal["Elite"]["needle_marshal_elite"]["enemy_ids"] = [
        "needle_marshal", "ragling_guard", "spool_stalker"]
    _reject(map, rng, selector, long_marshal, "wrong arity (3) in needle_marshal_elite")

    var short_hexer := registry.duplicate(true)
    short_hexer["Elite"]["spool_hexer_elite"]["enemy_ids"] = ["spool_hexer"]
    _reject(map, rng, selector, short_hexer, "wrong arity (1) in spool_hexer_elite")

    var missing_schedule := registry.duplicate(true)
    missing_schedule["Elite"]["absent_elite"] = {
        "schedule": "res://data/encounters/absent_elite.json",
        "enemy_ids": ["needle_marshal", "ragling_guard"],
    }
    _reject(map, rng, selector, missing_schedule, "missing Elite schedule file")

    var mismatched_schedule := registry.duplicate(true)
    mismatched_schedule["Elite"]["needle_marshal_elite"]["schedule"] = (
        "res://data/encounters/spool_hexer_elite.json")
    _reject(map, rng, selector, mismatched_schedule, "mismatched Elite schedule path")

    var traversal_schedule := registry.duplicate(true)
    traversal_schedule["Elite"]["spool_hexer_elite"]["schedule"] = (
        "res://data/encounters/../encounters/spool_hexer_elite.json")
    _reject(map, rng, selector, traversal_schedule, "noncanonical Elite schedule path")

    var bad_schedule := registry.duplicate(true)
    bad_schedule["Elite"]["m03_typed_battle_pools"] = {
        "schedule": "res://data/encounters/m03_typed_battle_pools.json",
        "enemy_ids": ["needle_marshal", "ragling_guard"],
    }
    _reject(map, rng, selector, bad_schedule, "bad non-schedule JSON in Elite pool")

    _check(rng.state == setup["after_choose"] and selector._selected.is_empty(),
        "no RNG draw or selector cache entry spent across all Elite rejections")

    # Malformed Fight and Boss pools remain isolated when entering a valid Elite node.
    var other_kind_broken := registry.duplicate(true)
    other_kind_broken["Fight"] = {"broken_fight": null}
    other_kind_broken["Boss"] = {"broken_boss": null}
    var sorted_ids: Array = registry["Elite"].keys()
    sorted_ids.sort()
    var expected_id: String = sorted_ids[setup["oracle"].randi_range(0, sorted_ids.size() - 1)]
    var isolated_ok := RunAuthoredBattleEntry.new()._entry_from_data(
        map, rng, selector, other_kind_broken)
    _check(isolated_ok.get("success") == true and
        isolated_ok.get("node_type") == "Elite" and
        isolated_ok.get("encounter_id") == expected_id and
        rng.state == setup["oracle"].state,
        "malformed Fight/Boss pools do not block valid Elite entry; retry spends one draw")
    _check(not _verify_entry(isolated_ok, "Elite", expected_id,
        "Elite retry after rejections").is_empty(),
        "Elite retry after rejections produces valid actors and intents")

    # An Elite enemy ID cannot be assembled as a Boss catalog entry.
    var boss_map := RunMap.new()
    var boss_rng := _rng(4103)
    boss_map.generate(boss_rng)
    for floor_idx in range(12):
        var legal := boss_map.get_legal_choices()
        _check(not legal.is_empty() and boss_map.choose_node(legal[0]),
            "Elite-as-Boss negative fixture commits floor %d" % (floor_idx + 1))
    var boss_selector := RunFightEncounterSelection.new()
    for elite_enemy_id in ["needle_marshal", "spool_hexer"]:
        var elite_in_boss := registry.duplicate(true)
        elite_in_boss["Boss"]["patchwork_behemoth"]["enemy_ids"] = [elite_enemy_id]
        _reject(boss_map, boss_rng, boss_selector, elite_in_boss,
            "Elite enemy ID " + elite_enemy_id + " rejected in Boss pool")
    var valid_boss := RunAuthoredBattleEntry.new().entry_current_battle(
        boss_map, boss_rng, boss_selector)
    _check(not _verify_entry(valid_boss, "Boss", "patchwork_behemoth",
        "Boss entry after Elite-in-Boss rejections").is_empty(),
        "Boss entry still succeeds after rejecting Elite IDs in Boss pool")

