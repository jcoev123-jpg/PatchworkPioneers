extends SceneTree

## Scene-free deterministic selector integration: only RunMap-generated, legally
## traversed Fight/Elite/Boss nodes and existing canonical encounter fixtures.

const STARTER := "res://data/encounters/starter_attacks.json"
const GUARD := "res://data/encounters/guard_counterattack.json"
const FEINT := "res://data/encounters/ragling_rearline_feint.json"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_fail_closed_retry_and_wrong_map()
	_test_legal_typed_route_and_replay()
	_test_bad_json_parser()
	if failures.is_empty():
		print("run_typed_encounter_selection_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_typed_encounter_selection_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _rng(value: int) -> RandomNumberGenerator:
	var result := RandomNumberGenerator.new()
	result.seed = value
	return result


func _fight_pool() -> Dictionary:
	# Deliberately reverse sorted insertion order.
	return {"z_fight_feint": FEINT, "a_fight_starter": STARTER}


func _elite_pool() -> Dictionary:
	return {"z_elite_guard": GUARD, "a_elite_feint": FEINT}


func _boss_pool() -> Dictionary:
	return {"boss_fixture_guard": GUARD}


func _pool_for(kind: String) -> Dictionary:
	match kind:
		"Fight":
			return _fight_pool()
		"Elite":
			return _elite_pool()
		"Boss":
			return _boss_pool()
	return {}


func _typed_pools(kind: String, pool: Dictionary) -> Dictionary:
	# Other kinds are deliberately invalid; they must NOT be validated.
	return {"Fight": null if kind != "Fight" else pool,
		"Elite": ["not a pool"] if kind != "Elite" else pool,
		"Boss": {"invalid_other_kind": "not a path"} if kind != "Boss" else pool}


func _snapshot(map: RunMap, rng: RandomNumberGenerator,
		picker: RunFightEncounterSelection) -> Dictionary:
	return {"floors": map.get_floors(), "route": map.get_route(),
		"current": map.get_current_node_id(), "floor": map.get_current_floor(),
		"choices": map.get_legal_choices(), "rng": rng.state,
		"cache": picker._selected.duplicate(true), "bound": picker._bound_map}


func _reject(map: RunMap, rng: RandomNumberGenerator,
		picker: RunFightEncounterSelection, pools: Dictionary, label: String) -> void:
	var before := _snapshot(map, rng, picker)
	var actual := picker.select_current_battle(map, rng, pools)
	_check(actual == {"success": false}, label + ": typed selection rejects")
	_check(_snapshot(map, rng, picker) == before,
		label + ": graph, route, RNG, map binding and entire cache unchanged")


func _first_fight(map: RunMap) -> String:
	for id in map.get_legal_choices():
		if map.get_node(id).get("type") == "Fight":
			return id
	return ""


func _expected_path(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "fixture file opens: " + path)
	if file == null:
		return []
	var result := RunFightEncounterSelection._parse_schedule_text(file.get_as_text())
	file.close()
	_check(not result.is_empty() and CombatEnemyIntents.new(result).is_valid(),
		"fixture file normalizes into valid actual CombatEnemyIntents: " + path)
	return result


func _test_fail_closed_retry_and_wrong_map() -> void:
	var seed_value := 38291
	var rng := _rng(seed_value)
	var map := RunMap.new()
	var picker := RunFightEncounterSelection.new()
	var pools := {"Fight": _fight_pool()}
	_check(picker.select_current_battle(null, rng, pools) == {"success": false}
		and picker._selected.is_empty() and picker._bound_map == null,
		"null map rejected without binding")
	_reject(map, rng, picker, pools, "ungenerated map")
	_check(map.generate(rng), "negative fixture graph generated")
	var opening := _first_fight(map)
	_check(not opening.is_empty() and map.get_legal_choices().has(opening),
		"negative fixture has genuine legal opening Fight")
	_reject(map, rng, picker, pools, "Fight offered but not chosen")
	if opening.is_empty():
		return
	_check(map.choose_node(opening) and map.get_node(opening).get("type") == "Fight",
		"negative fixture enters real Fight node")

	var before := _snapshot(map, rng, picker)
	_check(picker.select_current_battle(map, null, pools) == {"success": false}
		and _snapshot(map, rng, picker) == before, "null run RNG is inert")
	_reject(map, rng, picker, {}, "missing selected kind")
	_reject(map, rng, picker, {"Elite": _elite_pool(), "Boss": _boss_pool()},
		"other kinds provided but selected Fight missing")
	_reject(map, rng, picker, {"Fight": []}, "wrong selected pool type: Array")
	_reject(map, rng, picker, {"Fight": null}, "wrong selected pool type: null")
	_reject(map, rng, picker, {"Fight": {}}, "empty selected pool")
	_reject(map, rng, picker, {"Fight": {3: STARTER}}, "non-string candidate ID")
	_reject(map, rng, picker, {"Fight": {" ": STARTER}}, "blank candidate ID")
	_reject(map, rng, picker, {"Fight": {"invalid": 12}}, "non-string candidate path")
	_reject(map, rng, picker, {"Fight": {"missing": "res://data/encounters/not_here.json"}},
		"missing canonical encounter file")
	_reject(map, rng, picker, {"Fight": {"out": "res://data/enemies/starter_enemies.json"}},
		"wrong data directory")
	_reject(map, rng, picker, {"Fight": {"dotdot": "res://data/encounters/../enemies/starter_enemies.json"}},
		"noncanonical directory traversal")
	_reject(map, rng, picker, {"Fight": {"wrong_ext": "res://data/encounters/starter_attacks.gd"}},
		"wrong extension")
	_reject(map, rng, picker, {"Fight": {"z_valid": STARTER,
		"a_bad": "res://data/encounters/absent.json"}},
		"entire selected pool rejected even with a good candidate")
	var oracle_rng := _rng(seed_value)
	var oracle_map := RunMap.new()
	_check(oracle_map.generate(oracle_rng) and oracle_map.choose_node(opening),
		"independent oracle follows same legal opening route")
	var sorted: Array = _fight_pool().keys()
	sorted.sort()
	var expected_id: String = sorted[oracle_rng.randi_range(0, sorted.size() - 1)]
	seed(58321)
	var expected_global := randi()
	seed(58321)
	var result := picker.select_current_battle(map, rng, _typed_pools("Fight", _fight_pool()))
	_check(randi() == expected_global, "typed selection consumes no global RNG")
	_check(result.get("success", false) and result.get("node_type") == "Fight"
		and result.get("encounter_id") == expected_id
		and result.get("definitions", []) == _expected_path(_fight_pool()[expected_id]),
		"valid retry returns Fight kind and exact oracle-selected normalized schedule")
	_check(rng.state == oracle_rng.state,
		"failed typed attempts consume zero draws; valid retry exactly one")

	var foreign_rng := _rng(910)
	var foreign := RunMap.new()
	_check(foreign.generate(foreign_rng), "foreign map generated")
	var foreign_fight := _first_fight(foreign)
	_check(not foreign_fight.is_empty() and foreign.choose_node(foreign_fight),
		"foreign map legally selects Fight")
	var first_before := _snapshot(map, rng, picker)
	var foreign_before := _snapshot(foreign, foreign_rng, picker)
	_check(picker.select_current_battle(foreign, foreign_rng, pools) == {"success": false},
		"different selected map rejected after binding")
	_check(_snapshot(map, rng, picker) == first_before
		and _snapshot(foreign, foreign_rng, picker) == foreign_before,
		"different map cannot alter either map, RNG or shared cached node")
	_check(picker.select_current_fight(map, rng, {}) == {
		"success": true, "encounter_id": result["encounter_id"],
		"definitions": result["definitions"]},
		"legacy entry sees typed-first Fight cache with exact legacy result keys")


## Graph-only route planner: deduplicate each (node, Elite seen, later Fight seen)
## state, retaining legal parent links. No edits to map or RNG, no fake nodes.
func _route_through_fight_elite_fight_boss(map: RunMap) -> Array:
	var frontier: Array = []
	for opening in map.get_legal_choices():
		if map.get_node(opening).get("type") == "Fight":
			frontier.append({"path": [opening], "elite": false, "later_fight": false})
	for floor_number in range(2, RunMap.FLOOR_COUNT + 1):
		var next_frontier: Array = []
		var visited := {}
		for state in frontier:
			var node_id: String = state["path"].back()
			var links: Array = map.get_node(node_id)["outgoing"]
			for next_id in links:
				var kind: String = map.get_node(next_id).get("type", "")
				var elite: bool = state["elite"] or kind == "Elite"
				var later_fight: bool = state["later_fight"] or (state["elite"] and kind == "Fight")
				var key := "%s/%s/%s" % [next_id, elite, later_fight]
				if visited.has(key):
					continue
				visited[key] = true
				var path: Array = state["path"].duplicate()
				path.append(next_id)
				next_frontier.append({"path": path, "elite": elite, "later_fight": later_fight})
		frontier = next_frontier
		if floor_number == RunMap.FLOOR_COUNT:
			for state in frontier:
				if state["elite"] and state["later_fight"] \
						and map.get_node(state["path"].back()).get("type") == "Boss":
					return state["path"]
	return []


func _test_legal_typed_route_and_replay() -> void:
	var chosen_seed := -1
	var route: Array = []
	# Fixed deterministic seed search; never a hand-constructed graph/route.
	for seed_value in range(1, 129):
		var trial := RunMap.new()
		if not trial.generate(_rng(seed_value)):
			continue
		var candidate := _route_through_fight_elite_fight_boss(trial)
		if candidate.size() == RunMap.FLOOR_COUNT:
			chosen_seed = seed_value
			route = candidate
			break
	_check(chosen_seed > 0 and route.size() == RunMap.FLOOR_COUNT,
		"seed search finds connected twelve-floor Fight -> Elite -> later Fight -> Boss route")
	if route.is_empty():
		return

	var rng := _rng(chosen_seed)
	var replay_rng := _rng(chosen_seed)
	var oracle_rng := _rng(chosen_seed)
	var map := RunMap.new()
	var replay_map := RunMap.new()
	var oracle_map := RunMap.new()
	_check(map.generate(rng) and replay_map.generate(replay_rng)
		and oracle_map.generate(oracle_rng), "three independently seeded full graphs generated")
	_check(map.get_floors() == replay_map.get_floors()
		and map.get_floors() == oracle_map.get_floors(),
		"seed search route has identical complete independent maps")
	var selector := RunFightEncounterSelection.new()
	var replay_selector := RunFightEncounterSelection.new()
	var battle_count := 0
	var fight_count := 0
	var elite_count := 0
	var boss_count := 0
	var nonbattle_count := 0
	var prior_cache := {}
	var before_graph := map.get_floors()

	for i in range(route.size()):
		var node_id: String = route[i]
		var floor_number := i + 1
		var legal := map.get_legal_choices()
		_check(legal.has(node_id) and replay_map.get_legal_choices().has(node_id)
			and oracle_map.get_legal_choices().has(node_id),
			"planned node %s is legally reachable on floor %d" % [node_id, floor_number])
		_check(map.choose_node(node_id) and replay_map.choose_node(node_id)
			and oracle_map.choose_node(node_id), "all three real maps choose legal node " + node_id)
		var node: Dictionary = map.get_node(node_id)
		var kind: String = node.get("type", "")
		_check(node.get("id") == node_id and node.get("floor") == floor_number
			and map.get_current_floor() == floor_number
			and map.get_current_node_id() == node_id
			and map.get_route() == replay_map.get_route(),
			"real current node ID, kind and floor agree with route: " + node_id)
		if not kind in ["Fight", "Elite", "Boss"]:
			nonbattle_count += 1
			_reject(map, rng, selector, _typed_pools("Fight", _fight_pool()),
				"selected nonbattle " + kind + " " + node_id)
			var previous := _snapshot(map, rng, selector)
			_check(selector.select_current_fight(map, rng, _fight_pool()) == {"success": false}
				and _snapshot(map, rng, selector) == previous,
				"legacy Fight rejects nonbattle without RNG/cache/binding changes")
			continue

		var pool := _pool_for(kind)
		_check(not pool.is_empty() and pool.keys().size() > 0,
			"selected " + kind + " has its own nonempty typed fixture pool")
		# Failed attempts are against the actual selected kind, not another.
		_reject(map, rng, selector, {}, node_id + ": missing " + kind + " pool")
		_reject(map, rng, selector, {kind: []}, node_id + ": wrong " + kind + " pool type")
		_reject(map, rng, selector, {kind: {"valid": pool.values()[0],
			"invalid": "res://data/encounters/missing.json"}},
			node_id + ": invalid later candidate in " + kind + " pool")
		var sorted_ids: Array = pool.keys()
		sorted_ids.sort()
		var expected_id: String = sorted_ids[oracle_rng.randi_range(0, sorted_ids.size() - 1)]
		var oracle_after := oracle_rng.state
		var cache_before: Dictionary = selector._selected.duplicate(true)
		var answer: Dictionary
		var replay: Dictionary
		if kind == "Fight" and fight_count == 0:
			# Legacy-first and typed-first must share the same Fight cache.
			answer = selector.select_current_fight(map, rng, pool)
			replay = replay_selector.select_current_battle(
				replay_map, replay_rng, _typed_pools(kind, pool))
			_check(answer.keys().size() == 3 and not answer.has("node_type"),
				"legacy-first selected Fight retains exact three success keys")
		else:
			answer = selector.select_current_battle(map, rng, _typed_pools(kind, pool))
			replay = replay_selector.select_current_battle(
				replay_map, replay_rng, _typed_pools(kind, pool))
		var typed: Dictionary = selector.select_current_battle(map, rng, _typed_pools(kind, pool))
		var typed_keys := typed.keys()
		typed_keys.sort()
		_check(typed_keys == ["definitions", "encounter_id", "node_type", "success"],
			"typed success has exact four keys on " + node_id)
		_check(typed.get("success", false) and typed.get("node_type") == kind
			and typed.get("encounter_id") == expected_id and pool.has(expected_id),
			"typed selected ID and node type come only from actual chosen " + kind + " pool")
		var definitions := _expected_path(pool[expected_id])
		_check(typed.get("definitions", []) == definitions
			and CombatEnemyIntents.new(typed["definitions"]).is_valid(),
			"typed chosen " + kind + " definitions exactly match canonical parsed schedule")
		var comparable := typed.duplicate(true)
		comparable.erase("node_type")
		_check(answer == comparable if kind == "Fight" and fight_count == 0 else answer == typed,
			"legacy-first or typed-first answer matches typed choice for " + node_id)
		_check(replay == typed and replay_rng.state == rng.state,
			"independent replay matches ID, all definitions, node_type and RNG on " + node_id)
		_check(rng.state == oracle_after,
			"one sorted-index draw after map generation for " + kind + " at " + node_id)
		_check(selector._selected.size() == cache_before.size() + 1
			and selector._selected.has(node_id), "new battle caches its actual node ID only")
		for prior_id in cache_before:
			_check(selector._selected.get(prior_id) == cache_before[prior_id],
				"new battle preserves prior node's full cached result " + prior_id)
		var cache_copy := selector.select_current_battle(map, rng, _typed_pools(kind, pool))
		_check(cache_copy == typed and rng.state == oracle_after,
			"cache hit replays typed selection without another RNG draw on " + node_id)
		if kind == "Fight":
			fight_count += 1
			var old: Dictionary = selector.select_current_fight(map, rng, {})
			_check(old == comparable and old.keys().size() == 3
				and rng.state == oracle_after,
				"typed/legacy cross-entry Fight cache identical and no new draw")
		elif kind == "Elite":
			elite_count += 1
		elif kind == "Boss":
			boss_count += 1
			_check(floor_number == RunMap.FLOOR_COUNT,
				"Boss only selected on terminal floor twelve")
		# Damage both returned copies; neither subsequent cache nor replay mutates.
		answer["definitions"][0]["pattern"][0]["amount"] = 999
		answer["encounter_id"] = "corrupted_answer"
		cache_copy["definitions"][0]["pattern"][0]["type"] = "corrupted"
		cache_copy["definitions"].clear()
		_check(selector.select_current_battle(map, rng, _typed_pools(kind, pool)) == typed
			and replay_selector.select_current_battle(replay_map, replay_rng,
				_typed_pools(kind, pool)) == typed,
			"mutating two independent reads cannot affect cached/replay schedules or IDs")
		_check(rng.state == oracle_after and replay_rng.state == oracle_after,
			"deep-copy changes and repeat queries never draw run RNG")
		battle_count += 1
		prior_cache[node_id] = typed.duplicate(true)

	_check(map.is_complete() and map.get_current_floor() == RunMap.FLOOR_COUNT
		and map.get_legal_choices().is_empty(), "real legal route terminates after boss")
	_check(fight_count >= 2 and elite_count >= 1 and boss_count == 1
		and nonbattle_count >= 1, "route actually exercised multiple Fights, Elite, Boss, and nonbattle")
	_check(selector._selected.size() == battle_count
		and replay_selector._selected.size() == battle_count,
		"each battle has exactly one independent cached node on both replays")
	for id in prior_cache:
		_check(selector._selected[id] == prior_cache[id],
			"cached schedule remains independent across advancing floors: " + id)
	_check(map.get_floors() == before_graph
		and map.get_route() == oracle_map.get_route()
		and rng.state == oracle_rng.state,
		"selectors never change authored map graph/route or spend extra RNG")


func _test_bad_json_parser() -> void:
	# The actual pool loader calls this same fail-closed parser after opening
	# every canonical path. No fixture/catalog JSON is modified for the test.
	var invalid := [
		"{broken", "[]", "{}", "[null]",
		'[{"enemy_position":1,"pattern":[{"type":"attack","amount":2.25,"target_position":1}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"block","amount":1.5}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"attack","amount":1,"target_position":2.5}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"block","amount":9007199254740992}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"heal","amount":1}]}]',
	]
	for i in range(invalid.size()):
		_check(RunFightEncounterSelection._parse_schedule_text(invalid[i]).is_empty(),
			"malformed JSON / invalid normalized CombatEnemyIntents pattern rejected %d" % i)
