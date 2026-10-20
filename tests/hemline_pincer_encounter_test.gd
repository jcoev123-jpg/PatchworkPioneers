extends SceneTree
## Deterministic headless regression for the standalone authored M02
## "Hemline Pincer" Fight schedule. It proves the authored JSON, its announced
## intent cycle, defensive copies, the seeded RunFightEncounterSelection path
## and fail-closed handling of corrupted copies. This encounter is a standalone
## data/service candidate: it is deliberately NOT asserted to be live-wired.

const ENCOUNTER_ID := "hemline_pincer"
const ENCOUNTER_PATH := "res://data/encounters/hemline_pincer.json"
const STARTER_PATH := "res://data/encounters/starter_attacks.json"
const REARLINE_PATH := "res://data/encounters/ragling_rearline_feint.json"
const NEEDLELINE_PATH := "res://data/encounters/needleline_pressure.json"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_authored_file_and_parser()
	_test_announced_schedule_and_wrap()
	_test_snapshot_isolation()
	_test_seeded_fight_selection_and_replay()
	_test_fail_closed_paths()
	_test_corrupted_fixtures_rejected()
	_test_prior_encounters_preserved()
	if failures.is_empty():
		print("hemline_pincer_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("hemline_pincer_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _expected_schedule() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 3},
			{"type": "attack", "amount": 1, "target_position": 3},
			{"type": "block", "amount": 1}]},
	]


## Complete announcement for a beat in slot order, written independently of
## the parsed file's own array order.
func _expected_announced(beat: int) -> Array:
	match beat % 3:
		0:
			return [
				{"enemy_position": 1, "type": "attack", "amount": 1, "target_position": 1},
				{"enemy_position": 2, "type": "attack", "amount": 1, "target_position": 3},
			]
		1:
			return [
				{"enemy_position": 1, "type": "block", "amount": 1},
				{"enemy_position": 2, "type": "attack", "amount": 1, "target_position": 3},
			]
	return [
		{"enemy_position": 1, "type": "attack", "amount": 1, "target_position": 2},
		{"enemy_position": 2, "type": "block", "amount": 1},
	]


func _expected_prior(path: String) -> Array:
	match path:
		STARTER_PATH:
			return [
				{"enemy_position": 1, "pattern": [
					{"type": "attack", "amount": 1, "target_position": 1},
					{"type": "attack", "amount": 1, "target_position": 2}]},
				{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]},
			]
		REARLINE_PATH:
			return [
				{"enemy_position": 1, "pattern": [
					{"type": "attack", "amount": 1, "target_position": 3},
					{"type": "attack", "amount": 1, "target_position": 2}]},
				{"enemy_position": 2, "pattern": [
					{"type": "attack", "amount": 1, "target_position": 2},
					{"type": "attack", "amount": 1, "target_position": 1}]},
			]
		NEEDLELINE_PATH:
			return [
				{"enemy_position": 1, "pattern": [
					{"type": "attack", "amount": 1, "target_position": 2},
					{"type": "attack", "amount": 1, "target_position": 1},
					{"type": "block", "amount": 1}]},
				{"enemy_position": 2, "pattern": [
					{"type": "block", "amount": 1},
					{"type": "attack", "amount": 1, "target_position": 3},
					{"type": "attack", "amount": 1, "target_position": 2}]},
			]
	return []


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _parse_authored() -> Array:
	var text := _read_text(ENCOUNTER_PATH)
	_check(not text.is_empty(), "authored encounter file is readable and non-empty")
	if text.is_empty():
		return []
	return RunFightEncounterSelection._parse_schedule_text(text)


func _parse_file(path: String) -> Array:
	var text := _read_text(path)
	_check(not text.is_empty(), "encounter file is readable and non-empty: " + path)
	if text.is_empty():
		return []
	return RunFightEncounterSelection._parse_schedule_text(text)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _opening_fight(map: RunMap) -> String:
	for id in map.get_legal_choices():
		if map.get_node(id).get("type") == "Fight":
			return id
	return ""


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
		pool: Dictionary, label: String) -> void:
	var before := _snapshot(map, rng, picker)
	var answer := picker.select_current_fight(map, rng, pool)
	_check(answer == {"success": false}, label + ": rejected with no encounter")
	_check(_snapshot(map, rng, picker) == before,
		label + ": graph, route, run RNG, binding and cache all unchanged")


func _test_authored_file_and_parser() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH),
		"standalone hemline_pincer file exists at its exact res:// path")
	var parsed := _parse_authored()
	_check(parsed == _expected_schedule(),
		"parser accepts the authored file as the exact two-source three-beat schedule")
	_check(parsed.size() == 2, "hemline_pincer authors exactly two enemy sources")
	if parsed.size() != 2:
		return

	for position in [1, 2]:
		var matches: Array = []
		for entry in parsed:
			if entry is Dictionary and entry.get("enemy_position") == position:
				matches.append(entry)
		_check(matches.size() == 1,
			"exactly one authored source at enemy_position %d" % position)
		if matches.size() != 1:
			continue
		var definition: Dictionary = matches[0]
		_check(definition.get("enemy_position") is int,
			"source %d enemy_position is an integral int" % position)
		_check(definition.get("pattern") is Array and definition.get("pattern").size() == 3,
			"source %d owns a three-action cycle" % position)
		if not definition.get("pattern") is Array or definition.get("pattern").size() != 3:
			continue
		var expected_pattern: Array = _expected_schedule()[position - 1]["pattern"]
		for slot in range(3):
			var action = definition["pattern"][slot]
			_check(action == expected_pattern[slot],
				"source %d slot %d is exactly the authored action" % [position, slot])
			if action is Dictionary:
				_check(action.get("amount") is int,
					"source %d slot %d amount is an integral int" % [position, slot])
				if action.has("target_position"):
					_check(action.get("target_position") is int,
						"source %d slot %d target is an integral int" % [position, slot])
				else:
					_check(action.get("type") == "block",
						"source %d slot %d without a target is a Block" % [position, slot])


func _test_announced_schedule_and_wrap() -> void:
	var parsed := _parse_authored()
	if parsed.is_empty():
		return
	var scheduler := CombatEnemyIntents.new(parsed)
	_check(scheduler.is_valid(), "authored schedule passes CombatEnemyIntents validation")
	if not scheduler.is_valid():
		return

	var announced_by_beat: Array = []
	for beat in range(5):
		var announced := scheduler.get_intents()
		var expected := _expected_announced(beat)
		_check(announced.size() == 2, "beat %d announces both enemy slots" % beat)
		_check(announced == expected,
			"beat %d announces (front/rear pressure cycle) exactly as authored" % beat)
		if announced.size() == 2:
			_check(announced[0].get("enemy_position") == 1
				and announced[1].get("enemy_position") == 2,
				"beat %d announces sources in ascending slot order" % beat)
		announced_by_beat.append(announced.duplicate(true))
		_check(scheduler.advance_turn(), "beat %d advances the intent cycle" % beat)

	_check(announced_by_beat.size() == 5
		and announced_by_beat[3] == announced_by_beat[0],
		"beat 3 wraps exactly to beat 0")
	_check(announced_by_beat.size() == 5
		and announced_by_beat[4] == announced_by_beat[1],
		"beat 4 repeats beat 1 across the wraparound")

	# Announcements are complete: attacks name a target, Blocks never do.
	var beat0: Array = announced_by_beat[0]
	if beat0.size() == 2:
		_check(beat0[0].size() == 4 and beat0[0].has("target_position"),
			"beat 0 source 1 attack carries exactly position, type, amount, target")
		_check(beat0[1].size() == 4 and beat0[1].has("target_position"),
			"beat 0 source 2 attack carries exactly position, type, amount, target")
	var beat1: Array = announced_by_beat[1]
	if beat1.size() == 2:
		_check(beat1[0].size() == 3 and not beat1[0].has("target_position"),
			"beat 1 source 1 Block is announced without a hero target")


func _test_snapshot_isolation() -> void:
	var text_before := _read_text(ENCOUNTER_PATH)
	var parsed := _parse_authored()
	if parsed.is_empty():
		return
	var parsed_before := parsed.duplicate(true)
	var scheduler := CombatEnemyIntents.new(parsed)
	_check(scheduler.is_valid(), "snapshot fixture schedule is valid")
	if not scheduler.is_valid():
		return

	var first := scheduler.get_intents()
	first[0]["amount"] = 999
	first[0]["type"] = "invented"
	first[1].clear()
	first.clear()
	_check(scheduler.get_intents() == _expected_announced(0),
		"mutating one returned snapshot cannot change the next announcement")

	var second := scheduler.get_intents()
	second[0]["target_position"] = 3
	second.append({"enemy_position": 3, "type": "attack", "amount": 5,
		"target_position": 1})
	_check(scheduler.get_intents() == _expected_announced(0),
		"a second caller mutation is also isolated from later snapshots")
	_check(parsed == parsed_before,
		"caller mutations never change the parsed schedule array")
	_check(_read_text(ENCOUNTER_PATH) == text_before,
		"caller mutations never change the authored encounter file")

	var advanced := scheduler.advance_turn()
	_check(advanced and scheduler.get_intents() == _expected_announced(1),
		"isolation holds after advancing to the Block/rear-pressure beat")


func _test_seeded_fight_selection_and_replay() -> void:
	var seed_value := 41041
	var pool := {ENCOUNTER_ID: ENCOUNTER_PATH}
	var rng := _rng(seed_value)
	var map := RunMap.new()
	_check(map.generate(rng), "seeded 12-floor RunMap generates for selection")
	if not map.is_generated():
		return
	_check(map.get_floors().size() == RunMap.FLOOR_COUNT
		and map.get_legal_choices().size() > 0,
		"generated RunMap really has twelve floors and a legal opening floor")
	var fight_id := _opening_fight(map)
	_check(not fight_id.is_empty(), "seeded map genuinely offers a legal opening Fight")
	if fight_id.is_empty():
		return
	_check(map.choose_node(fight_id), "the legal opening Fight is chosen")
	_check(map.get_current_floor() == 1
		and map.get_current_node_id() == fight_id
		and map.get_node(fight_id).get("type") == "Fight",
		"a real current opening Fight is the selection precondition")

	var selector := RunFightEncounterSelection.new()
	seed(0x48454D4C)
	var global_expected := randi()
	seed(0x48454D4C)
	var answer := selector.select_current_fight(map, rng, pool)
	var global_after := randi()
	_check(global_after == global_expected,
		"selection leaves the Godot global RNG undrawn")
	_check(answer.get("success", false) and answer.get("encounter_id") == ENCOUNTER_ID,
		"an explicit one-entry candidate pool selects hemline_pincer")
	_check(answer.get("definitions", []) == _expected_schedule(),
		"selection returns the complete authored schedule")
	_check(map.get_route() == [fight_id],
		"the selector never chooses or advances map nodes")

	var oracle := _rng(seed_value)
	var oracle_map := RunMap.new()
	_check(oracle_map.generate(oracle), "oracle map generates from the same seed")
	_check(oracle_map.choose_node(fight_id), "oracle chooses the same opening Fight")
	_check(oracle_map.get_floors() == map.get_floors(),
		"same-seed map graph matches before the selection draw")
	oracle.randi_range(0, pool.size() - 1)
	_check(rng.state == oracle.state,
		"selection matches an oracle making the identical single-candidate call")

	# Teeth for the zero-draw probes: a real multi-candidate draw from the same
	# stream is observable in the state, so an extra draw could not hide.
	var draw_probe := rng.state
	var probe_rng := _rng(seed_value)
	probe_rng.state = rng.state
	probe_rng.randi_range(0, 1)
	_check(probe_rng.state != draw_probe,
		"a real multi-candidate draw would be detected by the state probe")

	# Cached requery after caller mutation: identical choice, zero new draws.
	var first_copy := answer.duplicate(true)
	var cached_state := rng.state
	seed(0x43414348)
	var cached_global_expected := randi()
	seed(0x43414348)
	answer["definitions"][0]["pattern"][0]["amount"] = 900
	answer["definitions"][0]["pattern"][0]["type"] = "invented"
	answer["definitions"].clear()
	answer["encounter_id"] = "mutated"
	var cached := selector.select_current_fight(map, rng, {})
	_check(cached == first_copy,
		"cached requery returns the unchanged choice after a caller mutation")
	_check(selector.select_current_fight(map, rng, pool) == first_copy,
		"cached requery still ignores a supplied pool once a Fight is cached")
	_check(rng.state == cached_state, "cached requery consumes no run RNG")
	_check(randi() == cached_global_expected,
		"cached requery leaves the Godot global RNG undrawn")
	# Teeth for the global probe: one injected global draw is observable.
	seed(0x43414348)
	var _injected_global := randi()
	_check(randi() != cached_global_expected,
		"an injected global draw would be detected by the global probe")

	# Fresh same-seed map and RNG replay the same ID, definitions and state.
	var replay_rng := _rng(seed_value)
	var replay_map := RunMap.new()
	_check(replay_map.generate(replay_rng), "fresh same-seed map generates for replay")
	_check(replay_map.choose_node(fight_id),
		"fresh map legally chooses the same opening Fight")
	var replay_selector := RunFightEncounterSelection.new()
	var replayed := replay_selector.select_current_fight(replay_map, replay_rng, pool)
	_check(replayed == first_copy,
		"fresh same-seed run replays the identical encounter ID and definitions")
	_check(replay_rng.state == cached_state,
		"fresh same-seed run ends in the identical RNG state")

	var selected_scheduler := CombatEnemyIntents.new(replayed.get("definitions", []))
	_check(selected_scheduler.is_valid(),
		"the selected definitions instantiate a valid CombatEnemyIntents service")
	if not selected_scheduler.is_valid():
		return
	for beat in range(5):
		_check(selected_scheduler.get_intents() == _expected_announced(beat),
			"selected schedule announces authored beat %d through the service" % beat)
		_check(selected_scheduler.advance_turn(),
			"selected schedule advances past beat %d" % beat)


func _test_fail_closed_paths() -> void:
	var seed_value := 90041
	var pool := {ENCOUNTER_ID: ENCOUNTER_PATH}
	var rng := _rng(seed_value)
	var map := RunMap.new()
	var selector := RunFightEncounterSelection.new()
	_reject(map, rng, selector, pool, "ungenerated map")

	_check(map.generate(rng), "fail-closed fixture map generates")
	var generated_state := rng.state
	_check(not _opening_fight(map).is_empty(),
		"generated map offers a real but still unchosen opening Fight")
	_reject(map, rng, selector, pool, "legal but unchosen opening Fight")
	_check(rng.state == generated_state and map.get_route().is_empty(),
		"unchosen-Fight rejection consumed no RNG and left the route empty")

	var fight_id := _opening_fight(map)
	if fight_id.is_empty():
		return
	_check(map.choose_node(fight_id), "fail-closed route chooses the opening Fight")
	_check(selector.select_current_fight(map, rng, pool).get("success", false),
		"the real chosen Fight still selects before later rejections")

	# Walk the real seeded route until a chosen non-Fight (the terminal Boss is
	# always a non-Fight), preferring real Fight nodes on the way.
	var nonfight_found := false
	for floor_number in range(2, RunMap.FLOOR_COUNT + 1):
		var choices := map.get_legal_choices()
		_check(not choices.is_empty(),
			"route offers a real legal next node on floor %d" % floor_number)
		if choices.is_empty():
			return
		var choice: String = choices[0]
		for candidate in choices:
			if map.get_node(candidate).get("type") == "Fight":
				choice = candidate
				break
		_check(map.choose_node(choice),
			"route chooses its real floor %d node" % floor_number)
		var kind: String = map.get_node(choice).get("type", "")
		if kind != "Fight":
			nonfight_found = true
			_reject(map, rng, selector, pool, "chosen non-Fight " + kind)
			break
	_check(nonfight_found, "the seeded route reached a real chosen non-Fight")
	_check(selector._selected.has(fight_id),
		"non-Fight rejection retains the earlier Fight cache")
	_check(map.get_current_node_id() != "" and not map.is_complete(),
		"non-Fight rejection did not roll back or complete the route")


func _test_corrupted_fixtures_rejected() -> void:
	var text_before := _read_text(ENCOUNTER_PATH)
	var good := _parse_authored()
	if good.is_empty():
		return
	var good_before := good.duplicate(true)
	_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(good)) == good_before,
		"an unmodified detached copy still parses, so the probes below have teeth")

	var bad_target := good.duplicate(true)
	bad_target[0]["pattern"][0]["target_position"] = 4
	_check(bad_target != good_before,
		"the out-of-bounds-target fixture really differs from the authored data")
	_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(bad_target)).is_empty(),
		"out-of-bounds attack target 4 is rejected by the encounter parser")
	_check(not CombatEnemyIntents.new(bad_target).is_valid(),
		"out-of-bounds attack target 4 is rejected by the intent validator")

	var bad_block := good.duplicate(true)
	bad_block[1]["pattern"][2]["target_position"] = 2
	_check(bad_block != good_before,
		"the Block-with-target fixture really differs from the authored data")
	_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(bad_block)).is_empty(),
		"a Block action that names a target is rejected by the encounter parser")
	_check(not CombatEnemyIntents.new(bad_block).is_valid(),
		"a Block action that names a target is rejected by the intent validator")

	var duplicate_slot := good.duplicate(true)
	duplicate_slot[1]["enemy_position"] = 1
	_check(duplicate_slot != good_before,
		"the duplicate-slot fixture really differs from the authored data")
	_check(RunFightEncounterSelection._parse_schedule_text(
		JSON.stringify(duplicate_slot)).is_empty(),
		"a duplicate enemy_position 1 is rejected by the encounter parser")
	_check(not CombatEnemyIntents.new(duplicate_slot).is_valid(),
		"a duplicate enemy_position 1 is rejected by the intent validator")

	# Numeric drift cannot be silently truncated into a valid schedule.
	var fractional_text := [
		"[{\"enemy_position\":1.5,\"pattern\":[{\"type\":\"block\",\"amount\":1}]}]",
		"[{\"enemy_position\":1,\"pattern\":[{\"type\":\"block\",\"amount\":1.5}]}]",
		"[{\"enemy_position\":1,\"pattern\":[{\"type\":\"attack\",\"amount\":1,"
			+ "\"target_position\":2.5}]}]",
	]
	for index in range(fractional_text.size()):
		_check(RunFightEncounterSelection._parse_schedule_text(
			fractional_text[index]).is_empty(),
			"fractional authored number fixture %d is rejected, not truncated" % index)

	_check(good == good_before, "corruption probes never change the parsed schedule")
	_check(_read_text(ENCOUNTER_PATH) == text_before,
		"corruption probes never change the authored encounter file")
	var recovered := _parse_authored()
	_check(recovered == good_before,
		"the authored file still parses to the same schedule after corruption probes")
	var scheduler := CombatEnemyIntents.new(recovered)
	_check(scheduler.is_valid()
		and scheduler.get_intents() == _expected_announced(0),
		"a valid scheduler still announces authored beat 0 after corruption probes")


func _test_prior_encounters_preserved() -> void:
	for path in [STARTER_PATH, REARLINE_PATH, NEEDLELINE_PATH]:
		_check(FileAccess.file_exists(path), "prior authored encounter still exists: " + path)
		var expected := _expected_prior(path)
		_check(not expected.is_empty(), "prior encounter has a named expectation: " + path)
		var parsed := _parse_file(path)
		_check(parsed == expected,
			"prior authored encounter keeps its complete ordered actions: " + path)
		var scheduler := CombatEnemyIntents.new(parsed)
		_check(scheduler.is_valid(),
			"prior authored encounter still passes intent validation: " + path)
		for beat in range(4):
			var expected_actions: Array = []
			for definition in expected:
				var action: Dictionary = definition["pattern"][
					beat % definition["pattern"].size()].duplicate(true)
				action["enemy_position"] = definition["enemy_position"]
				expected_actions.append(action)
			_check(scheduler.get_intents() == expected_actions,
				"prior encounter %s announces its own beat %d" % [path, beat])
			_check(scheduler.advance_turn(),
				"prior encounter %s advances past beat %d" % [path, beat])
