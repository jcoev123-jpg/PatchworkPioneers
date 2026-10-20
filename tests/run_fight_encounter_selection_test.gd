extends SceneTree

const STARTER := "res://data/encounters/starter_attacks.json"
const GUARD := "res://data/encounters/guard_counterattack.json"
const FEINT := "res://data/encounters/ragling_rearline_feint.json"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_real_schedules_and_cycles()
	_test_first_pick_rng_and_replay()
	_test_fail_closed_and_retry()
	_test_selected_nonfight_and_later_fights()
	_test_malformed_data()
	if failures.is_empty():
		print("run_fight_encounter_selection_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_fight_encounter_selection_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(yes: bool, description: String) -> void:
	checks += 1
	if not yes:
		failures.append(description)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _pool(reversed: bool = false) -> Dictionary:
	var result := {}
	if reversed:
		result["ragling_rearline_feint"] = FEINT
		result["guard_counterattack"] = GUARD
		result["starter_attacks"] = STARTER
	else:
		result["starter_attacks"] = STARTER
		result["guard_counterattack"] = GUARD
		result["ragling_rearline_feint"] = FEINT
	return result


func _expected(name: String) -> Array:
	match name:
		"starter_attacks":
			return [
				{"enemy_position": 1, "pattern": [
					{"type": "attack", "amount": 1, "target_position": 1},
					{"type": "attack", "amount": 1, "target_position": 2}]},
				{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]},
			]
		"guard_counterattack":
			return [
				{"enemy_position": 1, "pattern": [
					{"type": "block", "amount": 1},
					{"type": "attack", "amount": 1, "target_position": 1}]},
				{"enemy_position": 2, "pattern": [
					{"type": "attack", "amount": 1, "target_position": 3},
					{"type": "block", "amount": 1}]},
			]
		"ragling_rearline_feint":
			return [
				{"enemy_position": 1, "pattern": [
					{"type": "attack", "amount": 1, "target_position": 3},
					{"type": "attack", "amount": 1, "target_position": 2}]},
				{"enemy_position": 2, "pattern": [
					{"type": "attack", "amount": 1, "target_position": 2},
					{"type": "attack", "amount": 1, "target_position": 1}]},
			]
	return []


func _opening_fight(map: RunMap) -> String:
	for id in map.get_legal_choices():
		if map.get_node(id).get("type") == "Fight":
			return id
	return ""


func _enter_opening(map: RunMap, label: String) -> String:
	var id := _opening_fight(map)
	_check(not id.is_empty() and map.get_legal_choices().has(id),
		label + ": a real legal opening Fight exists")
	if not id.is_empty():
		_check(map.choose_node(id), label + ": route chooses opening Fight")
		_check(map.get_current_node_id() == id and map.get_current_floor() == 1
			and map.get_node(id).get("type") == "Fight",
			label + ": chosen CURRENT node is Fight")
	return id


func _snapshot(map: RunMap, rng: RandomNumberGenerator,
		picker: RunFightEncounterSelection) -> Dictionary:
	return {
		"floors": map.get_floors(),
		"route": map.get_route(),
		"current": map.get_current_node_id(),
		"choices": map.get_legal_choices(),
		"floor": map.get_current_floor(),
		"rng": rng.state,
		"cache": picker._selected.duplicate(true),
		"bound": picker._bound_map,
	}


func _reject(map: RunMap, rng: RandomNumberGenerator, picker: RunFightEncounterSelection,
		pool: Dictionary, label: String, supplied_rng: RandomNumberGenerator = null) -> void:
	var before := _snapshot(map, rng, picker)
	var answer := picker.select_current_fight(map, supplied_rng, pool)
	_check(answer == {"success": false}, label + ": rejected with no encounter")
	_check(_snapshot(map, rng, picker) == before,
		label + ": graph, route, run RNG, binding and cache all unchanged")


func _test_real_schedules_and_cycles() -> void:
	var pool := _pool()
	for id in pool.keys():
		var path: String = pool[id]
		_check(FileAccess.file_exists(path), id + ": real authored encounter exists")
		var file := FileAccess.open(path, FileAccess.READ)
		_check(file != null, id + ": real file opens")
		if file == null:
			continue
		var authored := RunFightEncounterSelection._parse_schedule_text(file.get_as_text())
		file.close()
		_check(authored == _expected(id), id + ": parsed authored actions and positions exact")
		var intents := CombatEnemyIntents.new(authored)
		_check(intents.is_valid(), id + ": real normalized schedule passes intent validator")
		for turn in range(6):
			var announced := intents.get_intents()
			var expected_actions: Array = []
			for def in _expected(id):
				var action: Dictionary = def["pattern"][turn % def["pattern"].size()].duplicate(true)
				action["enemy_position"] = def["enemy_position"]
				expected_actions.append(action)
			_check(announced == expected_actions,
				id + ": announced full fixed actions/owners on turn %d including wrap" % turn)
			_check(intents.advance_turn(), id + ": owner turn advances %d" % turn)


func _test_first_pick_rng_and_replay() -> void:
	var seed_value := 4103
	var rng := _rng(seed_value)
	var replay_rng := _rng(seed_value)
	var oracle_rng := _rng(seed_value)
	var map := RunMap.new()
	var replay_map := RunMap.new()
	var oracle_map := RunMap.new()
	_check(map.generate(rng) and replay_map.generate(replay_rng)
		and oracle_map.generate(oracle_rng), "three same-seed maps generate")
	_check(map.get_floors() == replay_map.get_floors()
		and map.get_floors() == oracle_map.get_floors(),
		"same seed yields identical graph before selection")
	var id := _enter_opening(map, "first")
	_check(replay_map.choose_node(id) and oracle_map.choose_node(id),
		"replay and oracle select same legal opening Fight")
	_check(map.get_route() == replay_map.get_route()
		and map.get_route() == oracle_map.get_route(),
		"replay and oracle have matching chosen routes")
	var ids: Array = _pool().keys()
	ids.sort()
	var expected_id: String = ids[oracle_rng.randi_range(0, ids.size() - 1)]
	var after_one_draw := oracle_rng.state
	var selector := RunFightEncounterSelection.new()
	var replay_selector := RunFightEncounterSelection.new()
	seed(765430)
	var global_expected := randi()
	seed(765430)
	var answer := selector.select_current_fight(map, rng, _pool())
	_check(randi() == global_expected, "selector leaves Godot global RNG undrawn")
	_check(answer.get("success", false) and answer.get("encounter_id") == expected_id,
		"first choice is exactly one sorted-index RNG draw")
	_check(rng.state == after_one_draw, "first choice leaves exact one-draw RNG state")
	_check(answer.get("definitions", []) == _expected(expected_id),
		"first selection returns complete canonical authored schedule")
	_check(map.get_current_node_id() == id and map.get_route() == [id],
		"picker does not choose or advance map nodes")

	var replay := replay_selector.select_current_fight(replay_map, replay_rng, _pool(true))
	_check(replay == answer and replay_rng.state == rng.state,
		"fresh same-seed run with reversed Dictionary insertion order replays exactly")

	# The returned values must be deep copies of both the cached value and
	# other reads. The caller may destroy the copy without affecting the run.
	var first_copy := answer.duplicate(true)
	var second_copy := selector.select_current_fight(map, rng, {})
	_check(second_copy == first_copy and rng.state == after_one_draw,
		"cached re-query returns same choice and consumes no RNG even with no pool")
	answer["definitions"][0]["pattern"][0]["amount"] = 900
	answer["definitions"][0]["pattern"][0]["type"] = "invented"
	answer["definitions"].clear()
	answer["encounter_id"] = "mutated"
	second_copy["definitions"][0]["pattern"][0]["amount"] = 500
	second_copy["definitions"].append({"fake": true})
	_check(selector.select_current_fight(map, rng, _pool()) == first_copy,
		"two caller mutations cannot affect later cached reads")
	_check(rng.state == after_one_draw, "mutating and reading cached result consumes zero RNG")

	var intents := CombatEnemyIntents.new(first_copy["definitions"])
	_check(intents.is_valid(), "selected returned array instantiates real CombatEnemyIntents")
	for turn in range(4):
		var expected_actions: Array = []
		for def in _expected(expected_id):
			var action: Dictionary = def["pattern"][turn % def["pattern"].size()].duplicate(true)
			action["enemy_position"] = def["enemy_position"]
			expected_actions.append(action)
		_check(intents.get_intents() == expected_actions,
			"selected choice gets exact authored turn %d for both enemy owners" % turn)
		_check(intents.advance_turn(), "selected intents advance owner turn %d" % turn)

	# A caller may grow the pool with additional authored aliases; no exact
	# catalogue-size assumption is baked into the service or this oracle.
	var expanded := _pool()
	expanded["additional_guard"] = GUARD
	var expanded_rng := _rng(seed_value)
	var expanded_map := RunMap.new()
	_check(expanded_map.generate(expanded_rng), "expanded-pool replay map generated")
	_enter_opening(expanded_map, "expanded")
	var expanded_oracle := _rng(seed_value)
	var expanded_oracle_map := RunMap.new()
	_check(expanded_oracle_map.generate(expanded_oracle), "expanded oracle generated")
	var sorted_ids: Array = expanded.keys()
	sorted_ids.sort()
	var expanded_id: String = sorted_ids[expanded_oracle.randi_range(0, sorted_ids.size() - 1)]
	var expanded_answer := RunFightEncounterSelection.new().select_current_fight(
		expanded_map, expanded_rng, expanded)
	_check(expanded_answer.get("success", false)
		and expanded_answer.get("encounter_id") == expanded_id
		and expanded_rng.state == expanded_oracle.state,
		"extended candidate set still selects via exactly one sorted draw")


func _test_fail_closed_and_retry() -> void:
	var rng := _rng(90210)
	var picker := RunFightEncounterSelection.new()
	var map := RunMap.new()
	_reject(map, rng, picker, _pool(), "ungenerated map", rng)
	_check(map.generate(rng), "rejection fixture map generates")
	_check(not _opening_fight(map).is_empty(), "unselected Fight genuinely offered as legal option")
	_reject(map, rng, picker, _pool(), "legal but UNCHOSEN Fight", rng)
	var id := _enter_opening(map, "rejection")
	if id.is_empty():
		return
	_reject(map, rng, picker, _pool(), "null RNG")
	_reject(map, rng, picker, {}, "empty candidate pool", rng)
	_reject(map, rng, picker, {"absent": "res://data/encounters/no_such_authored_fight.json"},
		"missing encounter file", rng)
	_reject(map, rng, picker, {"bad": "res://data/enemies/starter_enemies.json"},
		"out-of-directory JSON", rng)
	_reject(map, rng, picker, {"bad": "res://data/encounters/../enemies/starter_enemies.json"},
		"noncanonical path traversal", rng)
	_reject(map, rng, picker, {"valid": STARTER, "broken": "res://data/encounters/unknown.json"},
		"bad later entry rejects whole pool", rng)
	_reject(map, rng, picker, {"bad": null}, "non-string path", rng)
	_reject(map, rng, picker, {1: STARTER}, "non-string encounter ID", rng)
	_reject(map, rng, picker, {"": STARTER}, "empty encounter ID", rng)

	# A failed attempt cannot secretly consume the later valid choice.
	var expected_rng := _rng(90210)
	var expected_map := RunMap.new()
	_check(expected_map.generate(expected_rng) and expected_map.choose_node(id),
		"reference rejection map reaches same real current Fight")
	var expected_ids: Array = _pool().keys()
	expected_ids.sort()
	var expected_id: String = expected_ids[expected_rng.randi_range(0, expected_ids.size() - 1)]
	var result := picker.select_current_fight(map, rng, _pool())
	_check(result.get("success", false) and result.get("encounter_id") == expected_id
		and result.get("definitions", []) == _expected(expected_id),
		"valid retry after all rejections selects real authored encounter")
	_check(rng.state == expected_rng.state, "valid retry spends exactly its one RNG choice")


func _test_selected_nonfight_and_later_fights() -> void:
	# Start at a Fight, then traverse legal links until a non-Fight appears.
	# This covers ordinary alternate route kinds and the guaranteed Boss.
	var rng := _rng(304)
	var map := RunMap.new()
	_check(map.generate(rng), "mixed node route generates")
	var id := _enter_opening(map, "mixed")
	if id.is_empty():
		return
	var picker := RunFightEncounterSelection.new()
	var result := picker.select_current_fight(map, rng, _pool())
	_check(result.get("success", false), "first selected Fight chosen before later route")
	var saw_nonfight := false
	var saw_boss := false
	for floor_number in range(2, 13):
		var choices := map.get_legal_choices()
		_check(not choices.is_empty(), "mixed route has real legal next nodes")
		if choices.is_empty():
			return
		var choice: String = choices[0]
		# Prefer a real next Fight when present to exercise multi-node caching.
		for candidate in choices:
			if map.get_node(candidate).get("type") == "Fight":
				choice = candidate
				break
		_check(map.choose_node(choice), "mixed route chooses real floor %d" % floor_number)
		var kind: String = map.get_node(choice).get("type", "")
		if kind == "Fight":
			var before_state := rng.state
			var next := picker.select_current_fight(map, rng, _pool())
			_check(next.get("success", false)
				and CombatEnemyIntents.new(next.get("definitions", [])).is_valid(),
				"another legal Fight yields valid authored intents on floor %d" % floor_number)
			_check(rng.state != before_state, "different Fight consumes selection RNG")
		else:
			saw_nonfight = true
			saw_boss = saw_boss or kind == "Boss"
			_reject(map, rng, picker, _pool(), "chosen non-Fight " + kind, rng)
	_check(saw_nonfight and saw_boss, "route exercised actual non-Fight and terminal Boss")
	_check(picker._selected.has(id), "rejecting other kinds retains original Fight cache")


func _test_malformed_data() -> void:
	var good := _expected("starter_attacks")
	_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(good)) == good,
		"JSON numeric ints are normalized and accepted through shared validator")
	var invalid_text := [
		"{broken", "[]", "{}", "[null]",
		JSON.stringify([{"enemy_position": 1, "pattern": []}]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 1}]}]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "block", "amount": 1,
			"target_position": 3}]}]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 1,
			"target_position": 0}]}]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "heal", "amount": 1}]}]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "block", "amount": -1}]}]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "block", "amount": 1}]},
			{"enemy_position": 1, "pattern": [{"type": "block", "amount": 1}]}]),
		JSON.stringify([{"enemy_position": 4, "pattern": [{"type": "block", "amount": 1}]}]),
		JSON.stringify([{"enemy_position": 1.5, "pattern": [{"type": "block", "amount": 1}]}]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "block", "amount": 1.5}]}]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 2.5}]}]),
		JSON.stringify([{"enemy_position": true, "pattern": [{"type": "block", "amount": 1}]}]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "block", "amount": "1"}]}]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "block", "amount": 1,
			"extra": 1}]}]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "block", "amount": 1}]},
			{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]},
			{"enemy_position": 3, "pattern": [{"type": "block", "amount": 1}]},
			{"enemy_position": 3, "pattern": [{"type": "block", "amount": 1}]}]),
	]
	for i in range(invalid_text.size()):
		var normalized := RunFightEncounterSelection._parse_schedule_text(invalid_text[i])
		_check(normalized.is_empty(),
			"malformed/mismatched JSON intent fixture %d rejected before selection" % i)
	# Explicit raw numeric literals make sure fractional coercion cannot
	# silently truncate, and that a >2^53 integer is not fabricated.
	for bad_numeric in ["1.00001", "2.5", "9007199254740992", "1e309"]:
		var text_input := ("[{\"enemy_position\":1,\"pattern\":[{\"type\":\"attack\","
			+ "\"amount\":%s,\"target_position\":2}]}]") % bad_numeric
		_check(RunFightEncounterSelection._parse_schedule_text(text_input).is_empty(),
			"non-integral/unsafe raw JSON number " + bad_numeric + " rejected")
