extends SceneTree

const ENEMIES := "res://data/enemies/starter_enemies.json"
const STARTER := "res://data/encounters/starter_attacks.json"
const GUARD := "res://data/encounters/guard_counterattack.json"
const FEINT := "res://data/encounters/ragling_rearline_feint.json"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_real_selected_fight_and_isolation()
	_test_sorted_seed_replay()
	_test_real_typed_elite_and_boss()
	_test_atomic_rejections_and_retry()
	_test_malformed_catalog_parsing()
	if failures.is_empty():
		print("run_typed_battle_roster_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_typed_battle_roster_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


func _rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _start_fight(map: RunMap) -> String:
	for id in map.get_legal_choices():
		if map.get_node(id).get("type") == "Fight":
			if map.choose_node(id):
				return id
	return ""


func _snapshot(map: RunMap, rng: RandomNumberGenerator,
		selector: RunFightEncounterSelection) -> Dictionary:
	return {"floors": map.get_floors(), "route": map.get_route(),
		"choices": map.get_legal_choices(), "current": map.get_current_node_id(),
		"rng": rng.state, "cache": selector._selected.duplicate(true),
		"bound": selector._bound_map}


func _schedule_path(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "real schedule opens: " + path)
	if file == null:
		return []
	var definitions := RunFightEncounterSelection._parse_schedule_text(file.get_as_text())
	file.close()
	_check(not definitions.is_empty() and CombatEnemyIntents.new(definitions).is_valid(),
		"selected schedule is an actual valid authored intent pattern")
	return definitions


func _rosters() -> Dictionary:
	return {"starter_attacks": ["ragling", "ragling_guard"],
		"guard_counterattack": ["ragling", "ragling_guard"],
		"ragling_rearline_feint": ["ragling", "ragling_guard"]}


func _check_roster(answer: Dictionary, choice: Dictionary, expected_ids: Array,
		label: String) -> void:
	_check(answer.get("ok") == true and answer.get("node_type") == choice.get("node_type")
		and answer.get("encounter_id") == choice.get("encounter_id")
		and answer.get("definitions") == choice.get("definitions"),
		label + ": identity, type and complete selected schedule unchanged")
	var enemies = answer.get("enemies")
	_check(enemies is CombatEnemies and enemies.is_valid(),
		label + ": real authoritative CombatEnemies constructed")
	if not enemies is CombatEnemies or not enemies.is_valid():
		return
	_check(enemies.get_enemies().size() == expected_ids.size(),
		label + ": correct number of concrete actors")
	for position in range(1, expected_ids.size() + 1):
		var enemy: Dictionary = enemies.get_enemy(position)
		_check(enemy.get("id") == expected_ids[position - 1]
			and enemy.get("position") == position
			and enemy.get("max_hp") == 12 and enemy.get("hp") == 12
			and enemy.get("block") == 0,
			label + ": source slot %d has authored ID, 12/12 HP and zero Block" % position)
	_check(CombatEnemyIntents.new(answer["definitions"]).is_valid(),
		label + ": detached result retains valid cyclic enemy intents")
	var actual_positions: Array = []
	for definition in answer["definitions"]:
		actual_positions.append(definition["enemy_position"])
	actual_positions.sort()
	var expected_positions: Array = []
	for position in range(1, expected_ids.size() + 1):
		expected_positions.append(position)
	_check(actual_positions == expected_positions,
		label + ": exactly one real actor exists for every selected intent source")


func _test_real_selected_fight_and_isolation() -> void:
	var rng := _rng(4103)
	var map := RunMap.new()
	_check(map.generate(rng), "Fight: real seeded twelve-floor graph generated")
	var node_id := _start_fight(map)
	_check(not node_id.is_empty() and map.get_current_node_id() == node_id
		and map.get_node(node_id).get("type") == "Fight",
		"Fight: selected actually legal current Fight node")
	if node_id.is_empty():
		return
	var selector := RunFightEncounterSelection.new()
	var choice := selector.select_current_battle(map, rng, {
		"Fight": {"starter_attacks": STARTER}})
	_check(choice.get("success") == true and choice.get("node_type") == "Fight"
		and choice.get("encounter_id") == "starter_attacks"
		and choice.get("definitions") == _schedule_path(STARTER),
		"Fight: typed selector chooses actual starter encounter and complete JSON")
	if not choice.get("success", false):
		return
	var before := _snapshot(map, rng, selector)
	var choice_before := choice.duplicate(true)
	var bindings := _rosters()
	var bindings_before := bindings.duplicate(true)
	var paths := [ENEMIES]
	var assembler := RunTypedBattleRoster.new()
	_check(assembler.has_method("assemble"), "public assemble API exists")
	seed(223311)
	var expected_global := randi()
	seed(223311)
	var result := assembler.assemble(choice, bindings, paths)
	_check(randi() == expected_global, "roster assembly makes no global RNG draw")
	_check_roster(result, choice_before, ["ragling", "ragling_guard"],
		"Fight/starter")
	_check(_snapshot(map, rng, selector) == before and choice == choice_before
		and bindings == bindings_before and paths == [ENEMIES],
		"Fight: map, run RNG, complete selection cache and all inputs unchanged")
	if not result.get("ok", false):
		return
	var selected_copy := selector.select_current_battle(map, rng, {"Fight": {}})
	_check(selected_copy == choice_before, "selector's exact cache remains readable")

	var second := assembler.assemble(choice, bindings, paths)
	_check_roster(second, choice_before, ["ragling", "ragling_guard"],
		"Fight/second assembly")
	if not second.get("ok", false):
		return
	_check(result["enemies"] != second["enemies"],
		"two assemblies never share an authoritative CombatEnemies object")
	_check(result["enemies"].gain_block(1, 4)
		and result["enemies"].apply_damage(1, 7)
		and result["enemies"].apply_damage(2, 3),
		"first roster really takes Block and damage on separate actors")
	_check(result["enemies"].get_enemy(1)["hp"] == 9
		and result["enemies"].get_enemy(1)["block"] == 0
		and result["enemies"].get_enemy(2)["hp"] == 9,
		"first roster has the exact independently mutated combat state")
	result["definitions"][0]["pattern"][0]["amount"] = 999
	result["definitions"][1]["pattern"][0]["type"] = "invented"
	result["definitions"].append({"enemy_position": 3, "pattern": []})
	_check(second["definitions"] == choice_before["definitions"]
		and second["enemies"].get_enemy(1)["hp"] == 12
		and second["enemies"].get_enemy(1)["block"] == 0
		and second["enemies"].get_enemy(2)["hp"] == 12,
		"other assembly schedule and both actor records completely isolated")
	var third := assembler.assemble(choice, bindings, paths)
	_check_roster(third, choice_before, ["ragling", "ragling_guard"],
		"Fight/third independent assembly")
	_check(selector.select_current_battle(map, rng, {"Fight": {}}) == choice_before
		and _snapshot(map, rng, selector) == before,
		"mutating output cannot change selected definition, RNG, graph or cache")


func _test_sorted_seed_replay() -> void:
	var rng_a := _rng(87412)
	var rng_b := _rng(87412)
	var map_a := RunMap.new()
	var map_b := RunMap.new()
	_check(map_a.generate(rng_a) and map_b.generate(rng_b)
		and map_a.get_floors() == map_b.get_floors(),
		"replay: independently seeded graphs have identical real floors")
	var id := _start_fight(map_a)
	_check(not id.is_empty() and map_b.get_legal_choices().has(id)
		and map_b.choose_node(id), "replay: two legal routes select identical Fight")
	if id.is_empty():
		return
	var one := RunFightEncounterSelection.new()
	var two := RunFightEncounterSelection.new()
	var pool_a := {"z_feint": FEINT, "a_guard": GUARD, "m_starter": STARTER}
	var pool_b := {"m_starter": STARTER, "a_guard": GUARD, "z_feint": FEINT}
	var a := one.select_current_battle(map_a, rng_a, {"Fight": pool_a})
	var b := two.select_current_battle(map_b, rng_b, {"Fight": pool_b})
	_check(a.get("success") and b == a and rng_a.state == rng_b.state,
		"replay: reversed candidate dictionary order selects identical ID and schedule")
	if not a.get("success", false) or not b.get("success", false):
		return
	var bindings := {"z_feint": ["ragling_guard", "ragling"],
		"a_guard": ["ragling", "ragling_guard"],
		"m_starter": ["ragling", "ragling_guard"]}
	var first_before := _snapshot(map_a, rng_a, one)
	var second_before := _snapshot(map_b, rng_b, two)
	var assembled_a := RunTypedBattleRoster.new().assemble(a, bindings, [ENEMIES])
	var assembled_b := RunTypedBattleRoster.new().assemble(b, bindings, [ENEMIES])
	_check(assembled_a.get("ok") and assembled_b.get("ok"),
		"replay: selected schedule resolves its own explicit encounter binding")
	if assembled_a.get("ok") and assembled_b.get("ok"):
		_check_roster(assembled_a, a, bindings[a["encounter_id"]], "replay A")
		_check_roster(assembled_b, b, bindings[b["encounter_id"]], "replay B")
		_check(assembled_a["enemies"].get_enemies() == assembled_b["enemies"].get_enemies()
			and assembled_a["definitions"] == assembled_b["definitions"],
			"replay: full actor state and schedule exactly deterministic")
		_check(assembled_a["enemies"] != assembled_b["enemies"],
			"replay: independent routes receive independent mutable rosters")
	_check(_snapshot(map_a, rng_a, one) == first_before
		and _snapshot(map_b, rng_b, two) == second_before,
		"replay: assembly spends no run RNG and never changes either selector cache")


## Search a fixed seed range for a connected authentic Fight -> Elite -> Boss
## route. The graph, every legal choice and the 12th-floor Boss are generated.
func _elite_boss_route(map: RunMap) -> Array:
	var frontier: Array = []
	for id in map.get_legal_choices():
		if map.get_node(id).get("type") == "Fight":
			frontier.append({"path": [id], "elite": false})
	for floor_number in range(2, RunMap.FLOOR_COUNT + 1):
		var next_frontier: Array = []
		var visited := {}
		for state in frontier:
			for next_id in map.get_node(state["path"].back())["outgoing"]:
				var saw_elite: bool = state["elite"] or map.get_node(next_id).get("type") == "Elite"
				var key := "%s/%s" % [next_id, saw_elite]
				if visited.has(key):
					continue
				visited[key] = true
				var path: Array = state["path"].duplicate()
				path.append(next_id)
				next_frontier.append({"path": path, "elite": saw_elite})
		frontier = next_frontier
		if floor_number == RunMap.FLOOR_COUNT:
			for state in frontier:
				if state["elite"] and map.get_node(state["path"].back()).get("type") == "Boss":
					return state["path"]
	return []


func _test_real_typed_elite_and_boss() -> void:
	var chosen_seed := -1
	var route: Array = []
	for value in range(1, 129):
		var trial := RunMap.new()
		if not trial.generate(_rng(value)):
			continue
		var candidate := _elite_boss_route(trial)
		if candidate.size() == 12:
			chosen_seed = value
			route = candidate
			break
	_check(chosen_seed > 0 and route.size() == 12,
		"typed: real twelve-floor seeded legal route with an Elite and Boss exists")
	if chosen_seed < 0:
		return
	var rng := _rng(chosen_seed)
	var map := RunMap.new()
	_check(map.generate(rng), "typed: actual route graph created")
	var selector := RunFightEncounterSelection.new()
	var found := {"Fight": 0, "Elite": 0, "Boss": 0}
	var bindings := {"fight_fixture": ["ragling", "ragling_guard"],
		"elite_fixture": ["ragling_guard", "ragling"],
		"boss_fixture": ["ragling", "ragling_guard"]}
	var pools := {"Fight": {"fight_fixture": STARTER},
		"Elite": {"elite_fixture": GUARD}, "Boss": {"boss_fixture": FEINT}}
	var previous_cache := {}
	for i in range(route.size()):
		var id: String = route[i]
		_check(map.get_legal_choices().has(id) and map.choose_node(id),
			"typed: actual legal node entered on floor %d" % (i + 1))
		var kind: String = map.get_node(id).get("type", "")
		if not kind in ["Fight", "Elite", "Boss"]:
			continue
		found[kind] += 1
		var choice := selector.select_current_battle(map, rng, pools)
		_check(choice.get("success") and choice.get("node_type") == kind,
			"typed: real " + kind + " selection made on committed map node")
		if not choice.get("success", false):
			continue
		var before := _snapshot(map, rng, selector)
		var answer := RunTypedBattleRoster.new().assemble(choice, bindings, [ENEMIES])
		_check_roster(answer, choice, bindings[choice["encounter_id"]],
			"typed " + kind)
		_check(_snapshot(map, rng, selector) == before,
			"typed: " + kind + " roster does not reroll, reselect or mutate route")
		var again := RunTypedBattleRoster.new().assemble(choice, bindings, [ENEMIES])
		_check(again.get("ok") and answer.get("ok")
			and again["enemies"] != answer["enemies"]
			and again["enemies"].get_enemies() == answer["enemies"].get_enemies(),
			"typed: " + kind + " repeated assembly is fresh and deterministic")
		previous_cache[id] = choice.duplicate(true)
	_check(found["Fight"] > 0 and found["Elite"] > 0 and found["Boss"] == 1,
		"typed: all three battle kinds exercised using existing Raglings as fixtures")
	_check(map.get_current_floor() == 12 and map.is_complete()
		and map.get_node(map.get_current_node_id()).get("type") == "Boss",
		"typed: Boss truly occupied generated floor 12")
	for id in previous_cache:
		_check(selector._selected[id] == previous_cache[id],
			"typed: per-node selector cache retained intact " + id)


func _reject(assembler: RunTypedBattleRoster, choice: Variant, bindings: Variant,
		paths: Variant, map: RunMap, rng: RandomNumberGenerator,
		selector: RunFightEncounterSelection, label: String) -> void:
	var before := _snapshot(map, rng, selector)
	var source_choice = choice.duplicate(true) if choice is Dictionary else choice
	var source_bindings = bindings.duplicate(true) if bindings is Dictionary else bindings
	var source_paths = paths.duplicate(true) if paths is Array else paths
	var result := assembler.assemble(choice, bindings, paths)
	_check(result == {"ok": false}, label + ": whole roster atomically rejected")
	_check(_snapshot(map, rng, selector) == before
		and choice == source_choice and bindings == source_bindings
		and paths == source_paths,
		label + ": no map, RNG, selector cache or caller-input mutation")


func _test_atomic_rejections_and_retry() -> void:
	var rng := _rng(7123)
	var map := RunMap.new()
	_check(map.generate(rng) and not _start_fight(map).is_empty(),
		"rejection: real map and selected legal Fight exist")
	var selector := RunFightEncounterSelection.new()
	var choice := selector.select_current_battle(map, rng, {
		"Fight": {"starter_attacks": STARTER}})
	_check(choice.get("success") and choice.get("definitions", []).size() == 2,
		"rejection: selected two-source starter schedule truly valid")
	if not choice.get("success", false):
		return
	var good := {"starter_attacks": ["ragling", "ragling_guard"]}
	var assembler := RunTypedBattleRoster.new()
	_reject(assembler, choice, {}, [ENEMIES], map, rng, selector, "missing selected ID binding")
	_reject(assembler, choice, {"other": ["ragling", "ragling_guard"]}, [ENEMIES],
		map, rng, selector, "unrelated encounter's binding cannot be reused")
	for bad in [
		["ragling", "unknown"], ["ragling", "ragling"],
		["ragling"], ["ragling", "ragling_guard", "ragling"],
		["ragling", 4], ["ragling", ""], "ragling", [],
	]:
		_reject(assembler, choice, {"starter_attacks": bad}, [ENEMIES],
			map, rng, selector, "invalid roster binding %s" % str(bad))
	for paths in [
		[], [null], [7], ["res://data/enemies/missing.json"],
		["res://data/enemies/../enemies/starter_enemies.json"],
		["res://data/encounters/starter_attacks.json"],
		["res://data/enemies/starter_enemies.gd"],
		[ENEMIES, ENEMIES], [ENEMIES, "res://data/encounters/guard_counterattack.json"],
	]:
		_reject(assembler, choice, good, paths, map, rng, selector,
			"noncanonical/missing/duplicate/wrong-catalog JSON %s" % str(paths))
	for bad_choice in [
		{"success": false}, {}, null, [], {"success": true, "node_type": "Rest",
			"encounter_id": "starter_attacks", "definitions": choice["definitions"]},
		{"success": true, "node_type": "Event", "encounter_id": "starter_attacks",
			"definitions": choice["definitions"]},
		{"success": true, "node_type": "Fight", "encounter_id": "missing",
			"definitions": choice["definitions"]},
		{"success": "true", "node_type": "Fight", "encounter_id": "starter_attacks",
			"definitions": choice["definitions"]},
		{"success": true, "node_type": "Fight", "encounter_id": 9,
			"definitions": choice["definitions"]},
	]:
		_reject(assembler, bad_choice, good, [ENEMIES],
			map, rng, selector, "fake/failed/nonbattle selection %s" % str(bad_choice))
	var invalid_definitions := [
		[], [{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 1,
			"target_position": 1}]}],
		[{"enemy_position": 1, "pattern": [{"type": "block", "amount": 1}]},
			{"enemy_position": 3, "pattern": [{"type": "block", "amount": 1}]}],
		[{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]},
			{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]}],
		[{"enemy_position": 0, "pattern": [{"type": "block", "amount": 1}]},
			{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]}],
		[{"enemy_position": 4, "pattern": [{"type": "block", "amount": 1}]},
			{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]}],
		[{"enemy_position": 1.5, "pattern": [{"type": "block", "amount": 1}]},
			{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]}],
	]
	for invalid in invalid_definitions:
		var fake := choice.duplicate(true)
		fake["definitions"] = invalid
		_reject(assembler, fake, good, [ENEMIES], map, rng, selector,
			"missing/spurious/duplicate/gapped/out-of-range source %s" % str(invalid))
	var before := _snapshot(map, rng, selector)
	var corrected := assembler.assemble(choice, good, [ENEMIES])
	_check_roster(corrected, choice, ["ragling", "ragling_guard"],
		"corrected retry after all failures")
	_check(_snapshot(map, rng, selector) == before,
		"corrected retry still spends no RNG and changes no selection cache")


func _test_malformed_catalog_parsing() -> void:
	var file := FileAccess.open(ENEMIES, FileAccess.READ)
	_check(file != null, "actual authored enemy catalog opens")
	if file == null:
		return
	var real := RunTypedBattleRoster._parse_catalog_text(file.get_as_text())
	file.close()
	_check(real.size() >= 2 and real[0].get("id") == "ragling"
		and real[1].get("id") == "ragling_guard"
		and real[0].get("max_hp") == 12 and real[1].get("max_hp") == 12,
		"parser reads actual authored Raglings with normalized integral max_hp")
	var malformed := [
		"{broken", "[]", "{}", "[null]", "[4]",
		'[{"id":"ragling","max_hp":0}]',
		'[{"id":"ragling","max_hp":-1}]',
		'[{"id":"ragling","max_hp":2.5}]',
		'[{"id":"ragling","max_hp":"12"}]',
		'[{"id":"ragling","max_hp":true}]',
		'[{"id":"ragling","max_hp":9007199254740992}]',
		'[{"id":"ragling","max_hp":1e309}]',
		'[{"id":7,"max_hp":12}]',
		'[{"id":"  ","max_hp":12}]',
		'[{"id":" ragling","max_hp":12}]',
		'[{"id":"ragling","max_hp":12},{"id":"ragling","max_hp":12}]',
		'[{"id":"ragling","max_hp":12},{"id":"guard","max_hp":0}]',
	]
	for i in range(malformed.size()):
		_check(RunTypedBattleRoster._parse_catalog_text(malformed[i]).is_empty(),
			"entire malformed JSON enemy catalog rejects atomically %d" % i)
	_check(RunTypedBattleRoster._parse_catalog_text(
		'[{"id":"another_enemy","max_hp":13.0,"name":"Fixture"}]') == [
			{"id": "another_enemy", "max_hp": 13, "name": "Fixture"}],
		"valid exact-integral JSON HP normalizes without changing metadata")
