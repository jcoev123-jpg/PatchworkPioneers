extends SceneTree

const ENCOUNTER := "double_hem_siege"
const POOLS := "res://data/encounters/m03_typed_battle_pools.json"
const SCHEDULE := "res://data/encounters/double_hem_siege.json"
const ENEMY_CATALOG := "res://data/enemies/run_enemies.json"
const HERO_CATALOG := "res://data/heroes/starter_party.json"
const ROSTER := ["fray_scavenger", "seam_ripper"]
const ACTIONS := [
    [
        {"type": "attack", "amount": 3, "target_position": 1},
        {"type": "block", "amount": 2},
        {"type": "attack", "amount": 2, "target_position": 3},
        {"type": "attack", "amount": 2, "target_position": 2},
    ],
    [
        {"type": "attack", "amount": 3, "target_position": 1},
        {"type": "attack", "amount": 2, "target_position": 2},
        {"type": "block", "amount": 2},
        {"type": "attack", "amount": 2, "target_position": 3},
    ],
]
const EVENTS := [
    [
        {"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
        {"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true},
    ],
    [
        {"type": "block", "enemy_position": 1, "applied": true},
        {"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true},
    ],
    [
        {"type": "attack", "enemy_position": 1, "target_position": 3, "applied": true},
        {"type": "block", "enemy_position": 2, "applied": true},
    ],
    [
        {"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
        {"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true},
    ],
]
const HERO_LEDGERS := [
    [[40, 0], [30, 0], [26, 0]],
    [[40, 0], [28, 0], [26, 0]],
    [[40, 0], [28, 0], [24, 0]],
    [[40, 0], [26, 0], [22, 0]],
    [[34, 0], [26, 0], [22, 0]],
]
const ENEMY_LEDGERS := [
    [[14, 0], [18, 0]],
    [[14, 2], [18, 0]],
    [[14, 2], [18, 2]],
    [[14, 2], [18, 2]],
    [[14, 2], [18, 2]],
]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
    _test_authored_data()
    var seed_value := _find_public_seed()
    _check(seed_value > 0, "a seeded legal Fight selects Double-Hem from the full real pool")
    if seed_value > 0:
        _test_public_entry_and_cache(seed_value)
        _test_all_beats(seed_value)
        _test_slain_sources(seed_value)
        _test_invalid_preconditions(seed_value)
    if failures.is_empty():
        print("double_hem_siege_encounter_test: PASS (", checks, " checks)")
    else:
        for failure in failures:
            printerr(failure)
        printerr("double_hem_siege_encounter_test: FAIL (", failures.size(), " failures)")
    quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures.append(label)


func _rng(value: int) -> RandomNumberGenerator:
    var rng := RandomNumberGenerator.new()
    rng.seed = value
    return rng


func _registry() -> Dictionary:
    var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(POOLS))
    _check(result is Dictionary and result.get("Fight") is Dictionary,
        "real typed pool JSON parses with a Fight registry")
    return result if result is Dictionary else {}


func _expected_definitions() -> Array:
    return [
        {"enemy_position": 1, "pattern": ACTIONS[0].duplicate(true)},
        {"enemy_position": 2, "pattern": ACTIONS[1].duplicate(true)},
    ]


func _expected_announced(beat: int) -> Array:
    var result := []
    for source in range(2):
        var action: Dictionary = ACTIONS[source][beat % 4].duplicate(true)
        action["enemy_position"] = source + 1
        result.append(action)
    return result


func _hero_ledger(party: CombatParty) -> Array:
    var result := []
    for hero in party.get_heroes():
        result.append([hero["hp"], hero["block"]])
    return result


func _enemy_ledger(enemies: CombatEnemies) -> Array:
    var result := []
    for enemy in enemies.get_enemies():
        result.append([enemy["hp"], enemy["block"]])
    return result


func _party() -> CombatParty:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(HERO_CATALOG))
    _check(parsed is Array, "actual hero catalog is an array")
    var heroes := []
    if parsed is Array:
        var hp := {"warden": 40, "seamstress": 30, "tinker": 26}
        for id in ["warden", "seamstress", "tinker"]:
            var matches: Array = parsed.filter(
                func(record: Dictionary) -> bool: return record.get("id") == id)
            _check(matches.size() == 1, "exactly one authored hero " + id)
            if matches.size() == 1:
                var record: Dictionary = matches[0].duplicate(true)
                _check(RunFightEncounterSelection._coerce_integral_field(record, "max_hp")
                    and record["max_hp"] == hp[id],
                    "hero %s has authored HP %d" % [id, hp[id]])
                heroes.append(record)
    var party := CombatParty.new(heroes)
    _check(party.is_valid() and _hero_ledger(party) == [[40, 0], [30, 0], [26, 0]],
        "real combat party starts with correct order and HP")
    return party


func _test_authored_data() -> void:
    var registry := _registry()
    _check(registry.get("Fight") is Dictionary and registry["Fight"].has(ENCOUNTER),
        "new named Fight binding exists without fixed pool count")
    if not registry.get("Fight") is Dictionary or not registry["Fight"].has(ENCOUNTER):
        return
    var binding = registry["Fight"][ENCOUNTER]
    _check(binding is Dictionary and binding.size() == 2 and
        binding.get("schedule") == SCHEDULE and binding.get("enemy_ids") == ROSTER,
        "canonical binding points to exact two-source roster")
    for kind in ["Fight", "Elite", "Boss"]:
        _check(registry.get(kind) is Dictionary and not registry[kind].is_empty(),
            "existing typed " + kind + " candidates remain")
    for name in ["starter_attacks", "bobbin_skirmish", "buttonhole_holdout",
            "guard_counterattack", "triple_spool_pinch"]:
        _check(registry["Fight"].has(name), "earlier Fight remains: " + name)
    _check(registry["Elite"].has("thimble_crossfire") and
        registry["Boss"].has("patchwork_behemoth"), "earlier Elite and Boss remain")
    var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(ENEMY_CATALOG))
    _check(catalog is Array, "real run enemy catalog is an array")
    if catalog is Array:
        for index in range(ROSTER.size()):
            var id: String = ROSTER[index]
            var matching: Array = catalog.filter(
                func(record: Dictionary) -> bool: return record.get("id") == id)
            var expected_hp: int = 14 if index == 0 else 18
            _check(matching.size() == 1, "exactly one catalog record for " + id)
            if matching.size() == 1:
                var record: Dictionary = matching[0]
                _check(RunFightEncounterSelection._coerce_integral_field(record, "max_hp")
                    and record["max_hp"] == expected_hp,
                    id + " has exact authored HP")
    _check(FileAccess.file_exists(SCHEDULE), "schedule exists on disk")
    var definitions := RunFightEncounterSelection._parse_schedule_text(
        FileAccess.get_file_as_string(SCHEDULE))
    _check(definitions == _expected_definitions(),
        "full four-beat action order for both sources, starting at beat zero")
    for position in [1, 2]:
        var matches: Array = definitions.filter(
            func(definition: Dictionary) -> bool:
                return definition.get("enemy_position") == position)
        _check(matches.size() == 1, "exactly one authored source at position %d" % position)
    _check(CombatEnemyIntents.new(definitions).is_valid(),
        "real intent validator accepts exactly this authored schedule")
    var drift := _expected_definitions()
    drift[0]["pattern"][0]["amount"] = 3.5
    _check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(drift)).is_empty(),
        "fractional authored attack is rejected, not truncated")


func _opening(map: RunMap) -> String:
    for id in map.get_legal_choices():
        if map.get_node(id).get("type") == "Fight":
            return id
    return ""


func _setup(seed_value: int, choose: bool = true) -> Dictionary:
    var rng := _rng(seed_value)
    var oracle := _rng(seed_value)
    var map := RunMap.new()
    var mirror := RunMap.new()
    _check(map.generate(rng) and mirror.generate(oracle) and
        map.get_floors() == mirror.get_floors(), "seed replay builds equal real maps")
    var node := _opening(map)
    _check(not node.is_empty() and map.get_legal_choices().has(node),
        "opening Fight is actually legal on the generated map")
    if choose and not node.is_empty():
        _check(map.choose_node(node) and mirror.choose_node(node),
            "both maps commit the same legal Fight")
    return {"rng": rng, "oracle": oracle, "map": map, "mirror": mirror,
        "selector": RunFightEncounterSelection.new(), "node": node}


func _find_public_seed() -> int:
    var registry := _registry()
    if not registry.get("Fight") is Dictionary or not registry["Fight"].has(ENCOUNTER):
        return -1
    var names: Array = registry["Fight"].keys()
    names.sort()
    for seed_value in range(1, 129):
        var rng := _rng(seed_value)
        var map := RunMap.new()
        if not map.generate(rng):
            continue
        if _opening(map).is_empty():
            continue
        if names[rng.randi_range(0, names.size() - 1)] == ENCOUNTER:
            return seed_value
    return -1


func _public_entry(setup: Dictionary) -> Dictionary:
    return RunAuthoredBattleEntry.new().entry_current_battle(
        setup["map"], setup["rng"], setup["selector"])


func _check_entry(entry: Dictionary, label: String) -> void:
    _check(entry.get("success") == true and entry.get("node_type") == "Fight"
        and entry.get("encounter_id") == ENCOUNTER, label + ": exact typed selection")
    if not entry.get("success", false):
        return
    _check(entry["definitions"] == _expected_definitions(),
        label + ": four-beat schedule detached from disk")
    _check(entry["enemies"] is CombatEnemies and entry["enemies"].is_valid()
        and entry["intents"] is CombatEnemyIntents and entry["intents"].is_valid(),
        label + ": real assembled models are valid")
    var actors: Array = entry["enemies"].get_enemies()
    _check(actors.size() == 2, label + ": two real actors")
    if actors.size() == 2:
        for i in range(2):
            _check(actors[i]["id"] == ROSTER[i] and actors[i]["position"] == i + 1
                and actors[i]["max_hp"] == (14 if i == 0 else 18)
                and actors[i]["hp"] == actors[i]["max_hp"] and actors[i]["block"] == 0
                and actors[i].get("art_path", "").begins_with("res://assets/paper/enemies/"),
                label + ": authentic slot %d ID, HP, Block and art" % (i + 1))
    _check(entry["intents"].get_intents() == _expected_announced(0),
        label + ": exact opening announcements")


func _test_public_entry_and_cache(seed_value: int) -> void:
    var setup := _setup(seed_value)
    var names: Array = _registry()["Fight"].keys()
    names.sort()
    var expected: String = names[setup["oracle"].randi_range(0, names.size() - 1)]
    _check(expected == ENCOUNTER, "independent sorted-pool oracle selects the new ID")
    var before_files := [FileAccess.get_file_as_string(POOLS),
        FileAccess.get_file_as_string(SCHEDULE), FileAccess.get_file_as_string(ENEMY_CATALOG)]
    seed(772314)
    var expected_global := randi()
    seed(772314)
    var first := _public_entry(setup)
    _check(randi() == expected_global, "entry does not spend global RNG")
    _check(setup["rng"].state == setup["oracle"].state and
        setup["map"].get_route() == [setup["node"]],
        "public entry spends one sorted candidate draw, not an additional map choice")
    _check_entry(first, "public entry")
    if not first.get("success", false):
        return
    var selected_cache: Dictionary = setup["selector"]._selected.duplicate(true)
    var selected_state: int = setup["rng"].state
    var original_defs: Array = first["definitions"].duplicate(true)
    _check(first["enemies"].apply_damage(1, 5) and first["enemies"].gain_block(2, 4)
        and first["intents"].advance_turn(), "first response actors and intents are mutable")
    first["definitions"][0]["pattern"][0]["amount"] = 999
    first["definitions"][1]["pattern"].clear()
    first["intents"].get_intents()[0]["amount"] = 999
    first["encounter_id"] = "tampered"
    var cached := _public_entry(setup)
    _check_entry(cached, "cached entry")
    _check(cached.get("success") and cached["enemies"] != first["enemies"]
        and cached["intents"] != first["intents"]
        and cached["definitions"] == original_defs
        and cached["intents"].get_intents() == _expected_announced(0)
        and _enemy_ledger(cached["enemies"]) == [[14, 0], [18, 0]],
        "cached re-entry returns fresh actors, intent cycles and detached definitions")
    _check(setup["rng"].state == selected_state
        and setup["selector"]._selected == selected_cache,
        "cached re-entry spends no run RNG and retains unpoisoned selector cache")
    var replay := _setup(seed_value)
    var second := _public_entry(replay)
    _check_entry(second, "independent replay")
    _check(second.get("success") and replay["rng"].state == selected_state
        and replay["selector"]._selected == selected_cache
        and replay["map"].get_floors() == setup["map"].get_floors()
        and replay["map"].get_route() == setup["map"].get_route(),
        "independent run repeats entire route, RNG state, selection and cache")
    if second.get("success", false):
        for beat in range(9):
            _check(second["intents"].get_intents() == _expected_announced(beat)
                and cached["intents"].get_intents() == _expected_announced(beat),
                "independent and cached fixed cycles replay at beat %d" % beat)
            second["intents"].advance_turn()
            cached["intents"].advance_turn()
    _check(before_files == [FileAccess.get_file_as_string(POOLS),
        FileAccess.get_file_as_string(SCHEDULE), FileAccess.get_file_as_string(ENEMY_CATALOG)],
        "entry, cache and replay never mutate source files")


func _test_all_beats(seed_value: int) -> void:
    var setup := _setup(seed_value)
    var entry := _public_entry(setup)
    _check_entry(entry, "combat phase")
    if not entry.get("success", false):
        return
    var party := _party()
    if not party.is_valid():
        return
    var enemies: CombatEnemies = entry["enemies"]
    var intents: CombatEnemyIntents = entry["intents"]
    var starting := CombatStartingBlock.new(party)
    _check(starting.apply() and not starting.apply()
        and _hero_ledger(party) == [[40, 6], [30, 0], [26, 0]],
        "Warden gets six opening Block exactly once, no other hero gets Block")
    var phase := CombatEnemyPhase.new()
    var held_rng: int = setup["rng"].state
    for beat in range(5):
        var announced: Array = intents.get_intents()
        _check(announced == _expected_announced(beat),
            "beat %d exact ordered announced intents" % beat)
        var result := phase.execute_phase(party, enemies, announced)
        _check(result.get("ok") == true
            and result.get("events") == EVENTS[beat % 4],
            "beat %d exact ordered applied phase events" % beat)
        _check(intents.get_intents() == announced,
            "phase resolution does not advance beat %d" % beat)
        _check(_hero_ledger(party) == HERO_LEDGERS[beat],
            "beat %d exact hero HP and Block ledger" % beat)
        _check(_enemy_ledger(enemies) == ENEMY_LEDGERS[beat],
            "beat %d exact enemy HP and Block ledger" % beat)
        if beat == 0:
            _check(party.get_hero(1)["hp"] == 40 and party.get_hero(1)["block"] == 0
                and not starting.apply(), "both 3-point ordered hits consume all opening six Block without HP loss")
        _check(intents.advance_turn(), "advance after beat %d" % beat)
    _check(intents.get_intents() == _expected_announced(5),
        "beat four wrapped to beat zero and next announcement is beat one")
    _check(setup["rng"].state == held_rng, "every authored beat resolves without RNG")


func _test_slain_sources(seed_value: int) -> void:
    var setup := _setup(seed_value)
    var entry := _public_entry(setup)
    _check_entry(entry, "slain second source")
    if not entry.get("success", false):
        return
    var party := _party()
    var enemies: CombatEnemies = entry["enemies"]
    _check(enemies.apply_damage(2, 18) and enemies.is_slain(2)
        and enemies.get_enemy(2)["position"] == 2,
        "source 2 actually slain in its original slot")
    _check(CombatStartingBlock.new(party).apply(), "slain second source fixture starts with Warden Block")
    var announced: Array = entry["intents"].get_intents()
    _check(announced == _expected_announced(0), "slain source still appears in announcement")
    var phase := CombatEnemyPhase.new().execute_phase(party, enemies, announced)
    var absent := EVENTS[0].duplicate(true)
    absent[1]["applied"] = false
    _check(phase.get("ok") == true and phase.get("events") == absent,
        "slain second source attack is inert; first source still acts")
    _check(_hero_ledger(party) == [[40, 3], [30, 0], [26, 0]]
        and _enemy_ledger(enemies) == [[14, 0], [0, 0]],
        "slain source cannot consume the remaining three Warden Block")
    var other := _public_entry(_setup(seed_value))
    _check_entry(other, "slain first source")
    if not other.get("success", false):
        return
    var other_party := _party()
    _check(CombatStartingBlock.new(other_party).apply(), "slain first source fixture starts with Warden Block")
    _check(other["enemies"].apply_damage(1, 14) and other["enemies"].is_slain(1),
        "source 1 is really slain before its block beat")
    _check(other["intents"].advance_turn(), "move slain first source to beat 1")
    var beat1 := CombatEnemyPhase.new().execute_phase(other_party,
        other["enemies"], other["intents"].get_intents())
    var inert_block := EVENTS[1].duplicate(true)
    inert_block[0]["applied"] = false
    _check(beat1.get("ok") and beat1.get("events") == inert_block,
        "slain source cannot gain Block while living second source attacks middle")
    _check(_hero_ledger(other_party) == [[40, 6], [28, 0], [26, 0]]
        and _enemy_ledger(other["enemies"]) == [[0, 0], [18, 0]],
        "first source stays slain and second source deals exactly two to middle")


func _snapshot(setup: Dictionary, party: CombatParty, enemies: CombatEnemies) -> Dictionary:
    var map: RunMap = setup["map"]
    return {"floor": map.get_current_floor(), "floors": map.get_floors(),
        "route": map.get_route(), "legal": map.get_legal_choices(),
        "current": map.get_current_node_id(), "rng": setup["rng"].state,
        "cache": setup["selector"]._selected.duplicate(true),
        "bound": setup["selector"]._bound_map,
        "heroes": party.get_heroes(), "enemies": enemies.get_enemies()}


func _reject(setup: Dictionary, registry: Variant, party: CombatParty,
        enemies: CombatEnemies, label: String, public: bool = false) -> void:
    var before := _snapshot(setup, party, enemies)
    var registry_before = registry.duplicate(true) if registry is Dictionary else registry
    var result := (_public_entry(setup) if public else
        RunAuthoredBattleEntry.new()._entry_from_data(
            setup["map"], setup["rng"], setup["selector"], registry))
    _check(result == {"success": false}, label + ": clean rejection")
    _check(_snapshot(setup, party, enemies) == before and
        registry == registry_before, label + ": no map, party, enemy, cache or RNG mutation")


func _test_invalid_preconditions(seed_value: int) -> void:
    var pools := _registry()
    var setup := _setup(seed_value)
    var party := _party()
    var unchanged_party := party.get_heroes()
    var enemies := CombatEnemies.new([
        {"id": "fray_scavenger", "max_hp": 14},
        {"id": "seam_ripper", "max_hp": 18},
    ])
    _check(party.is_valid() and enemies.is_valid(),
        "negative tests use live, non-null party and enemies")
    _reject(_setup(seed_value, false), pools, party, enemies,
        "real generated Fight not yet committed", true)
    var fresh := {"rng": _rng(seed_value), "oracle": _rng(seed_value),
        "map": RunMap.new(), "selector": RunFightEncounterSelection.new()}
    _reject(fresh, pools, party, enemies, "ungenerated map", true)
    _reject(setup, {}, party, enemies, "no chosen-kind pool")
    _reject(setup, {"Fight": {}}, party, enemies, "empty chosen-kind pool")
    var malformed := pools.duplicate(true)
    malformed["Fight"][ENCOUNTER]["schedule"] = "res://data/encounters/bobbin_skirmish.json"
    _reject(setup, malformed, party, enemies, "wrong canonical schedule binding")
    malformed = pools.duplicate(true)
    malformed["Fight"][ENCOUNTER]["enemy_ids"] = ["fray_scavenger"]
    _reject(setup, malformed, party, enemies, "schedule/roster arity mismatch")
    malformed = pools.duplicate(true)
    malformed["Fight"][ENCOUNTER]["enemy_ids"] = ["fray_scavenger", "unknown_enemy"]
    _reject(setup, malformed, party, enemies, "unknown catalog ID")
    malformed = pools.duplicate(true)
    malformed["Fight"][ENCOUNTER]["enemy_ids"] = ["fray_scavenger", "fray_scavenger"]
    _reject(setup, malformed, party, enemies, "duplicate roster ID")
    malformed = pools.duplicate(true)
    malformed["Fight"][ENCOUNTER]["enemy_ids"] = ["seam_ripper", "fray_scavenger", "button_guard"]
    _reject(setup, malformed, party, enemies, "extra roster actor rejected")
    malformed = pools.duplicate(true)
    malformed["Fight"]["bad_other_fight"] = {
        "schedule": "res://data/encounters/absent.json",
        "enemy_ids": ROSTER.duplicate()}
    _reject(setup, malformed, party, enemies, "malformed alternate candidate rejects whole Fight pool")
    var missing := {"Fight": {}}
    _reject(setup, missing, party, enemies, "new Fight absent from focused empty pool")
    _check(setup["rng"].state == setup["oracle"].state,
        "every invalid attempt preserved the preselection run RNG")
    var corrected := _public_entry(setup)
    _check_entry(corrected, "valid public retry after rejections")
    var sorted: Array = pools["Fight"].keys()
    sorted.sort()
    _check(corrected.get("success") and
        sorted[setup["oracle"].randi_range(0, sorted.size() - 1)] == ENCOUNTER
        and setup["rng"].state == setup["oracle"].state,
        "valid retry takes precisely one original sorted-pool draw")
    _check(party.get_heroes() == unchanged_party
        and _enemy_ledger(enemies) == [[14, 0], [18, 0]],
        "entry never edits caller's party or existing enemy roster")
