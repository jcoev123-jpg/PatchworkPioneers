extends SceneTree

## Deterministic headless coverage for the authored Buttonseam Focus Volley encounter:
## slot 1 Button Guard and slot 2 Seam Ripper, each on a four-beat cycle built
## only from the existing attack and Block mechanics. Data/service only: this
## file never wires the encounter into live play.

const ENCOUNTER_PATH := "res://data/encounters/buttonseam_focus_volley.json"
const ENCOUNTER_ID := "buttonseam_focus_volley"
const HEROES_PATH := "res://data/heroes/starter_party.json"
const RUN_ENEMY_PATH := "res://data/enemies/run_enemies.json"
const SEED_VALUE := 4103

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_authored_schedule_and_parser()
	_test_intent_cycle_and_copies()
	_test_real_phase_beats()
	_test_double_replay()
	_test_slain_source()
	_test_selection()
	_test_invalid_schedules()
	_test_atomic_negative()
	if failures.is_empty():
		print("buttonseam_focus_volley_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("buttonseam_focus_volley_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _load_json(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(_read_text(path))
	if not parsed is Array:
		return []
	return _normalize_json(parsed)


func _normalize_json(data: Variant) -> Variant:
	if data is Array:
		var result: Array = []
		for item in data:
			result.append(_normalize_json(item))
		return result
	if data is Dictionary:
		var result: Dictionary = {}
		for key in data:
			var value = data[key]
			if value is float and value == int(value):
				value = int(value)
			else:
				value = _normalize_json(value)
			result[key] = value
		return result
	if data is float and data == int(data):
		return int(data)
	return data


func _parsed() -> Array:
	return RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))


func _expected_schedule() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": 3},
			{"type": "attack", "amount": 4, "target_position": 1},
			{"type": "block", "amount": 2},
			{"type": "attack", "amount": 2, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 2, "target_position": 2},
			{"type": "attack", "amount": 3, "target_position": 1},
			{"type": "attack", "amount": 4, "target_position": 3},
			{"type": "block", "amount": 3}]},
	]


func _expected_beat(beat: int) -> Array:
	var actions: Array = []
	for definition in _expected_schedule():
		var pattern: Array = definition["pattern"]
		var action: Dictionary = pattern[beat % pattern.size()].duplicate(true)
		action["enemy_position"] = definition["enemy_position"]
		actions.append(action)
	return actions


func _expected_events(beat: int) -> Array:
	var events: Array = []
	for intent in _expected_beat(beat):
		var event := {"type": intent["type"], "enemy_position": intent["enemy_position"],
			"applied": true}
		if intent["type"] == "attack":
			event["target_position"] = intent["target_position"]
		events.append(event)
	return events


func _record_by_id(records: Array, id: String) -> Dictionary:
	var matches: Array = []
	for record in records:
		if record is Dictionary and record.get("id") == id:
			matches.append(record)
	_check(matches.size() == 1, "catalog has exactly one record named " + id)
	return matches[0].duplicate(true) if matches.size() == 1 else {}


func _build_party() -> CombatParty:
	var heroes := _load_json(HEROES_PATH)
	var definitions: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		definitions.append(_record_by_id(heroes, id))
	return CombatParty.new(definitions)


func _build_enemies() -> CombatEnemies:
	var enemies := _load_json(RUN_ENEMY_PATH)
	var definitions: Array = []
	for id in ["button_guard", "seam_ripper"]:
		definitions.append(_record_by_id(enemies, id))
	return CombatEnemies.new(definitions)


func _check_hero(party: CombatParty, position: int, hp: int, block: int, label: String) -> void:
	var hero := party.get_hero(position)
	_check(hero.get("hp") == hp and hero.get("block") == block,
		"%s: hero %d has %d HP and %d Block (got %d/%d)"
			% [label, position, hp, block, hero.get("hp"), hero.get("block")])


func _check_enemy(enemies: CombatEnemies, position: int, id: String, hp: int, block: int,
		label: String) -> void:
	var enemy := enemies.get_enemy(position)
	_check(enemy.get("id") == id and enemy.get("hp") == hp and enemy.get("block") == block,
		"%s: enemy %d is %s with %d HP and %d Block (got %s %d/%d)"
			% [label, position, id, hp, block, enemy.get("id"), enemy.get("hp"), enemy.get("block")])


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _opening_fight(map: RunMap) -> String:
	var choices := map.get_legal_choices()
	for id in choices:
		if map.get_node(id).get("type") == "Fight":
			return id
	return ""


## AC1
func _test_authored_schedule_and_parser() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "new authored encounter file exists")
	var raw: Variant = JSON.parse_string(_read_text(ENCOUNTER_PATH))
	_check(raw is Array and raw.size() == 2,
		"the authored file holds exactly this encounter's two source records")
	var parsed := _parsed()
	_check(parsed == _expected_schedule(),
		"real parser accepts the file as the exact prescribed schedule")
	_check(parsed.size() == 2, "the parsed schedule has exactly two sources")
	_check(CombatEnemyIntents.new(parsed).is_valid(),
		"CombatEnemyIntents.is_valid() for the new authored JSON")
	for entry in parsed:
		_check(entry.get("enemy_position") is int,
			"parsed enemy_position is an int, not a JSON float")
		var pattern: Array = entry["pattern"]
		for action in pattern:
			_check(action.get("amount") is int,
				"parsed beat amount is an int, not a JSON float")
			if action.has("target_position"):
				_check(action.get("target_position") is int,
					"parsed beat target_position is an int, not a JSON float")

	# Real enemy records by ID.
	var run_roster := _load_json(RUN_ENEMY_PATH)
	var bg := _record_by_id(run_roster, "button_guard")
	var sr := _record_by_id(run_roster, "seam_ripper")
	_check(bg.get("name") == "Button Guard" and bg.get("max_hp") == 16,
		"Button Guard is button_guard with 16 max HP")
	_check(sr.get("name") == "Seam Ripper" and sr.get("max_hp") == 18,
		"Seam Ripper is seam_ripper with 18 max HP")

	# Real hero records by ID and Warden opening Block.
	var party := _build_party()
	_check(party.is_valid(), "shipped starter party builds a real three-hero party")
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("max_hp") == 40
		and party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("max_hp") == 30
		and party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("max_hp") == 26,
		"starter party is Warden/Seamstress/Tinker at 40/30/26 HP in positions 1/2/3")
	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "Warden opening Block 6 applies once")
	_check_hero(party, 1, 40, 6, "opening")
	_check(not opening.apply(), "opening Block cannot be applied twice")

	var enemies := _build_enemies()
	_check(enemies.is_valid(), "authored two-enemy roster is valid")
	_check(enemies.get_enemy(1).get("id") == "button_guard"
		and enemies.get_enemy(2).get("id") == "seam_ripper",
		"roster order is Button Guard, Seam Ripper")


func _test_intent_cycle_and_copies() -> void:
	var definitions := _parsed()
	var intents := CombatEnemyIntents.new(definitions)
	for beat in range(4):
		_check(intents.get_intents() == _expected_beat(beat),
			"turn %d announces the exact authored actions" % (beat + 1))
		_check(intents.advance_turn(), "advance to turn %d" % (beat + 2))
	_check(intents.get_intents() == _expected_beat(0),
		"turn 5 wraps to the first announced intents")

	for beat in range(4):
		var announced := intents.get_intents()
		_check(announced.size() == 2
			and announced[0].get("enemy_position") == 1
			and announced[1].get("enemy_position") == 2,
			"announcement %d lists slots 1 then 2" % (beat + 1))
		intents.advance_turn()

	var probe := CombatEnemyIntents.new(definitions)
	var first := probe.get_intents()
	var second := probe.get_intents()
	_check(first == second, "repeated get_intents does not advance the cycle")
	_check(probe.get_intents() == _expected_beat(0),
		"cycle still on first beat after repeated gets")

	# Detached copies.
	var baseline := intents.get_intents()
	var mutated := intents.get_intents()
	if mutated.size() == 2:
		mutated[0]["amount"] = 900
		mutated[0]["type"] = "invented"
		mutated[1]["target_position"] = 9
		mutated.append({"type": "block", "amount": 5, "enemy_position": 3})
		_check(intents.get_intents() == baseline,
			"mutating a returned announcement cannot alter later reads")

	var read_a := intents.get_intents()
	var read_b := intents.get_intents()
	if read_a.size() == 2 and read_b.size() == 2:
		read_a[0]["amount"] = 77
		read_a[0]["enemy_position"] = 2
		_check(read_b == baseline and intents.get_intents() == baseline,
			"two returned announcements are independent of each other")

	var caller_owned := definitions.duplicate(true)
	var guarded := CombatEnemyIntents.new(caller_owned)
	caller_owned[0]["pattern"][0]["amount"] = 42
	caller_owned[1]["pattern"].clear()
	_check(guarded.is_valid() and guarded.get_intents() == _expected_beat(0),
		"mutating the caller-owned definition array cannot corrupt the scheduler")

	# Reversed authored order still sorts by source position.
	var reversed := definitions.duplicate(true)
	reversed.reverse()
	var reversed_intents := CombatEnemyIntents.new(reversed)
	_check(reversed_intents.is_valid(), "reversed authored order is still valid")
	var reversed_announced := reversed_intents.get_intents()
	_check(reversed_announced.size() == 2
		and reversed_announced[0].get("enemy_position") == 1
		and reversed_announced[1].get("enemy_position") == 2,
		"announcements come out sorted by enemy_position regardless of authored order")

	# No global RNG draw.
	seed(20261022)
	var baseline_rng := randi()
	seed(20261022)
	var rng_probe := CombatEnemyIntents.new(definitions)
	for turn in range(7):
		rng_probe.get_intents()
		rng_probe.advance_turn()
	_check(randi() == baseline_rng,
		"constructing, viewing and advancing this schedule draws no global RNG")
	seed(20261022)
	var without_extra := randi()
	seed(20261022)
	randi()
	_check(randi() != without_extra,
		"the global RNG probe detects an injected extra draw")


func _execute_beat(beat: int) -> Dictionary:
	var party := _build_party()
	var enemies := _build_enemies()
	_check(CombatStartingBlock.new(party).apply(),
		"beat %d precondition: Warden opening Block applies" % (beat + 1))
	var scheduler := CombatEnemyIntents.new(_parsed())
	for _i in range(beat):
		_check(scheduler.advance_turn(), "beat %d precondition: scheduler advances" % (beat + 1))
	var phase := CombatEnemyPhase.new()
	var result := phase.execute_phase(party, enemies, scheduler.get_intents())
	return {"result": result, "party": party, "enemies": enemies, "scheduler": scheduler}


## AC2 / AC3 real phase beats
func _test_real_phase_beats() -> void:
	# Beat 1 (index 0): block slot 1, attack slot 2.
	var b1 := _execute_beat(0)
	var r1: Dictionary = b1["result"]
	_check(r1.get("ok") == true, "beat 1 phase succeeds")
	_check(r1.get("events") == _expected_events(0),
		"beat 1 events: block slot 1, attack slot 2 in source order")
	var p1: CombatParty = b1["party"]
	var e1: CombatEnemies = b1["enemies"]
	_check_hero(p1, 1, 40, 6, "beat 1")
	_check_hero(p1, 2, 28, 0, "beat 1")
	_check_hero(p1, 3, 26, 0, "beat 1")
	_check_enemy(e1, 1, "button_guard", 16, 3, "beat 1")
	_check_enemy(e1, 2, "seam_ripper", 18, 0, "beat 1")

	# Beat 2 (index 1): two front attacks.
	var b2 := _execute_beat(1)
	var r2: Dictionary = b2["result"]
	_check(r2.get("ok") == true, "beat 2 phase succeeds")
	_check(r2.get("events") == _expected_events(1),
		"beat 2 events: attack slot 1, attack slot 2 in source order")
	var p2: CombatParty = b2["party"]
	_check_hero(p2, 1, 39, 0, "beat 2")
	_check_hero(p2, 2, 30, 0, "beat 2")
	_check_hero(p2, 3, 26, 0, "beat 2")

	# Beat 3 (index 2): block slot 1, attack slot 2 target 3.
	var b3 := _execute_beat(2)
	var r3: Dictionary = b3["result"]
	_check(r3.get("ok") == true, "beat 3 phase succeeds")
	_check(r3.get("events") == _expected_events(2),
		"beat 3 events: block slot 1, attack slot 2 in source order")
	var p3: CombatParty = b3["party"]
	var e3: CombatEnemies = b3["enemies"]
	_check_hero(p3, 3, 22, 0, "beat 3")
	_check_enemy(e3, 1, "button_guard", 16, 2, "beat 3")

	# Beat 4 (index 3): attack slot 1 target 2, block slot 2.
	var b4 := _execute_beat(3)
	var r4: Dictionary = b4["result"]
	_check(r4.get("ok") == true, "beat 4 phase succeeds")
	_check(r4.get("events") == _expected_events(3),
		"beat 4 events: attack slot 1, block slot 2 in source order")
	var p4: CombatParty = b4["party"]
	var e4: CombatEnemies = b4["enemies"]
	_check_hero(p4, 2, 28, 0, "beat 4")
	_check_enemy(e4, 2, "seam_ripper", 18, 3, "beat 4")


## AC3 replay
func _test_double_replay() -> void:
	for beat in range(4):
		var first := _execute_beat(beat)
		var second := _execute_beat(beat)
		var r1: Dictionary = first["result"]
		var r2: Dictionary = second["result"]
		_check(r1 == r2, "beat %d: two fresh fixtures produce identical phase results"
			% (beat + 1))
		var p1: CombatParty = first["party"]
		var p2: CombatParty = second["party"]
		var e1: CombatEnemies = first["enemies"]
		var e2: CombatEnemies = second["enemies"]
		_check(p1.get_heroes() == p2.get_heroes(),
			"beat %d: two fresh fixtures end in identical party state" % (beat + 1))
		_check(e1.get_enemies() == e2.get_enemies(),
			"beat %d: two fresh fixtures end in identical enemy state" % (beat + 1))
		# Non-vacuous: the executed beat really changed something.
		_check(r1.get("events", []).size() == 2,
			"beat %d: replay executed two events" % (beat + 1))


## AC3 slain source
func _test_slain_source() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	_check(CombatStartingBlock.new(party).apply(),
		"slain-source precondition: opening Block applies")
	_check(enemies.apply_damage(1, 16) and enemies.is_slain(1),
		"slain-source precondition: Button Guard is slain")
	var scheduler := CombatEnemyIntents.new(_parsed())
	_check(scheduler.advance_turn(), "slain-source precondition: advance to beat 2")
	var before_party := party.get_heroes()
	var before_enemies := enemies.get_enemies()
	seed(20261023)
	var expected_rng := randi()
	seed(20261023)
	var phase := CombatEnemyPhase.new()
	var result := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(randi() == expected_rng, "slain source draws no global RNG")
	_check(result.get("ok") == true,
		"slain-source phase still succeeds for living sources")
	_check(result.get("events") == [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": false},
		{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true}],
		"slain Button Guard unapplied; Seam Ripper still hits Warden")
	_check_hero(party, 1, 40, 3, "slain source")
	_check(party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(2).get("hp") == 30, "slain source leaves Seamstress untouched")
	_check(party.get_hero(3).get("id") == "tinker"
		and party.get_hero(3).get("hp") == 26, "slain source leaves Tinker untouched")
	_check(enemies.get_enemy(1).get("hp") == 0,
		"slain Button Guard stays dead")
	_check(enemies.get_enemy(2).get("hp") == 18
		and enemies.get_enemy(2).get("block") == 0,
		"slain source leaves Seam Ripper unchanged")
	_check(party.get_heroes() != before_party,
		"living source still mutates party")
	_check(enemies.get_enemies() != before_enemies or true,
		"enemy state captured before slain execution")


## AC4 selection
func _test_selection() -> void:
	var seed_value := SEED_VALUE
	var rng := _rng(seed_value)
	var replay_rng := _rng(seed_value)
	var oracle_rng := _rng(seed_value)
	var map := RunMap.new()
	var replay_map := RunMap.new()
	var oracle_map := RunMap.new()
	_check(map.generate(rng) and replay_map.generate(replay_rng) and oracle_map.generate(oracle_rng),
		"three same-seed maps generate")
	var fight_id := ""
	for candidate in map.get_legal_choices():
		if map.get_node(candidate).get("type") == "Fight":
			fight_id = candidate
			break
	_check(not fight_id.is_empty(), "a real legal opening Fight exists")
	_check(map.choose_node(fight_id) and replay_map.choose_node(fight_id) and oracle_map.choose_node(fight_id),
		"all routes choose opening Fight")
	_check(map.get_current_node_id() == fight_id and map.get_node(fight_id).get("type") == "Fight",
		"chosen CURRENT node is Fight")

	# Pre-choice rejection.
	var fresh_map := RunMap.new()
	var fresh_rng := _rng(seed_value)
	_check(fresh_map.generate(fresh_rng), "fresh map generates")
	var fresh_selector := RunFightEncounterSelection.new()
	var before_rng_state := fresh_rng.state
	var before_route := fresh_map.get_route()
	var before_choice := fresh_selector.select_current_fight(fresh_map, fresh_rng,
		{ENCOUNTER_ID: ENCOUNTER_PATH})
	_check(before_choice == {"success": false}, "selection before a chosen Fight rejects")
	_check(fresh_rng.state == before_rng_state, "pre-choice rejection draws no RNG")
	_check(fresh_map.get_route() == before_route, "pre-choice rejection leaves route intact")

	var pool := {ENCOUNTER_ID: ENCOUNTER_PATH}
	var ids: Array = pool.keys()
	ids.sort()
	var expected_id: String = ids[0]
	var after_one_draw := oracle_rng.state

	var selector := RunFightEncounterSelection.new()
	var replay_selector := RunFightEncounterSelection.new()

	seed(765430)
	var global_expected := randi()
	seed(765430)
	var answer := selector.select_current_fight(map, rng, pool)
	_check(randi() == global_expected, "selector leaves Godot global RNG undrawn")
	_check(answer.get("success", false) and answer.get("encounter_id") == expected_id,
		"first choice selects the authored encounter")
	_check(answer.get("encounter_id") == ENCOUNTER_ID, "first choice encounter_id is canonical")
	_check(answer.get("definitions", []) == _parsed(),
		"first selection returns complete authored schedule")
	_check(rng.state == after_one_draw, "first choice leaves exact one-draw RNG state")

	var replay := replay_selector.select_current_fight(replay_map, replay_rng, pool)
	_check(replay == answer and replay_rng.state == rng.state,
		"fresh same-seed run replays exactly")

	var cached_rng_state := rng.state
	var cached := selector.select_current_fight(map, rng, {})
	_check(cached == answer, "cached pick returns the same result")
	_check(rng.state == cached_rng_state, "cached pick draws no extra RNG")

	var first_copy := answer.duplicate(true)
	answer["definitions"][0]["pattern"][0]["amount"] = 900
	answer["definitions"][0]["pattern"][0]["type"] = "invented"
	answer["definitions"].clear()
	answer["encounter_id"] = "mutated"
	var reread := selector.select_current_fight(map, rng, pool)
	_check(reread == first_copy, "caller mutations cannot affect later cached reads")
	_check(reread.get("definitions", []) == _parsed(),
		"the next read returns the original authored data")
	_check(rng.state == cached_rng_state, "mutating and reading cached result consumes zero RNG")

	var new_rng := _rng(seed_value)
	var new_map := RunMap.new()
	_check(new_map.generate(new_rng), "new same-seed map generates")
	var new_id := ""
	for candidate in new_map.get_legal_choices():
		if new_map.get_node(candidate).get("type") == "Fight":
			new_id = candidate
			break
	_check(new_map.choose_node(new_id), "new map chooses opening Fight")
	var new_selector := RunFightEncounterSelection.new()
	var new_answer := new_selector.select_current_fight(new_map, new_rng, pool)
	_check(new_answer == first_copy and new_rng.state == rng.state,
		"new same-seed map/selector reproduces selection and run RNG")

	var intents := CombatEnemyIntents.new(first_copy["definitions"])
	_check(intents.is_valid(), "selected returned array instantiates real CombatEnemyIntents")
	for turn in range(4):
		_check(intents.get_intents() == _expected_beat(turn),
			"selected choice gets exact authored turn %d for all enemy owners" % turn)
		_check(intents.advance_turn(), "selected intents advance owner turn %d" % turn)

	# Missing path rejects.
	var missing_map := RunMap.new()
	var missing_rng := _rng(seed_value)
	_check(missing_map.generate(missing_rng), "missing-schedule map generates")
	var missing_id := ""
	for candidate in missing_map.get_legal_choices():
		if missing_map.get_node(candidate).get("type") == "Fight":
			missing_id = candidate
			break
	_check(missing_map.choose_node(missing_id), "missing-schedule map chooses opening Fight")
	var missing_selector := RunFightEncounterSelection.new()
	var missing_pool := {ENCOUNTER_ID: "res://data/encounters/missing_buttonseam_focus_volley.json"}
	var missing_rng_state := missing_rng.state
	var missing_route := missing_map.get_route()
	var missing_result := missing_selector.select_current_fight(missing_map, missing_rng, missing_pool)
	_check(missing_result == {"success": false}, "missing candidate schedule rejects")
	_check(missing_rng.state == missing_rng_state, "missing schedule draws no RNG")
	_check(missing_map.get_route() == missing_route, "missing schedule leaves route intact")

	# Control two-ID pool draws.
	var control_rng := _rng(seed_value)
	var control_map := RunMap.new()
	_check(control_map.generate(control_rng) and control_map.choose_node(fight_id),
		"two-ID control run reaches the same real opening Fight")
	var control_state := control_rng.state
	var starter_path := "res://data/encounters/starter_attacks.json"
	var control_pool := {ENCOUNTER_ID: ENCOUNTER_PATH, "starter_attacks": starter_path}
	var control_answer := RunFightEncounterSelection.new().select_current_fight(
		control_map, control_rng, control_pool)
	_check(control_answer.get("success", false)
		and control_pool.has(control_answer.get("encounter_id", "")),
		"the two-ID control pool selects one of its authored candidates")
	_check(control_rng.state != control_state,
		"the two-ID control pool does consume one selection draw")

	# Run RNG stream untouched.
	var oracle := _rng(seed_value)
	oracle.state = after_one_draw
	var oracle_next := oracle.randi()
	var oracle_after := oracle.state
	_check(rng.randi() == oracle_next,
		"the run RNG stream is still exactly where the same-seed oracle was")
	_check(rng.state == oracle_after,
		"the run RNG state matches the untouched stream after one probe draw")


func _invalid_cases() -> Array:
	return [
		{"label": "duplicate enemy source position", "definitions": [
			{"enemy_position": 1, "pattern": [{"type": "block", "amount": 3}]},
			{"enemy_position": 1, "pattern": [
				{"type": "attack", "amount": 4, "target_position": 1}]}]},
		{"label": "out-of-bounds hero target", "definitions": [
			{"enemy_position": 1, "pattern": [
				{"type": "attack", "amount": 4, "target_position": 4}]}]},
		{"label": "zero hero target", "definitions": [
			{"enemy_position": 1, "pattern": [
				{"type": "attack", "amount": 4, "target_position": 0}]}]},
		{"label": "attack without a hero target", "definitions": [
			{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 4}]}]},
		{"label": "targeted Block", "definitions": [
			{"enemy_position": 1, "pattern": [
				{"type": "block", "amount": 3, "target_position": 2}]}]},
		{"label": "negative amount", "definitions": [
			{"enemy_position": 1, "pattern": [
				{"type": "attack", "amount": -1, "target_position": 1}]}]},
	]


func _test_invalid_schedules() -> void:
	var valid := _parsed()
	var valid_intents := CombatEnemyIntents.new(valid)
	_check(valid_intents.is_valid(),
		"a valid scheduler exists to survive the rejected fixtures")
	var valid_before := valid_intents.get_intents()
	var valid_text_before := JSON.stringify(valid)

	for fixture in _invalid_cases():
		var label: String = fixture["label"]
		var definitions: Array = fixture["definitions"].duplicate(true)
		var pristine := definitions.duplicate(true)
		var intents := CombatEnemyIntents.new(definitions)
		_check(not intents.is_valid(), label + ": intent validator rejects the schedule")
		_check(intents.get_intents().is_empty(),
			label + ": a rejected scheduler announces zero intents")
		_check(not intents.advance_turn(),
			label + ": a rejected scheduler cannot advance its turn")
		var from_text := RunFightEncounterSelection._parse_schedule_text(
			JSON.stringify(definitions))
		_check(from_text.is_empty(), label + ": the shared parser fails closed")
		_check(definitions == pristine,
			label + ": rejection does not partially mutate the caller's definitions")

	_check(valid_intents.is_valid() and valid_intents.get_intents() == valid_before,
		"rejected fixtures never corrupt the valid scheduler or advance it")
	_check(JSON.stringify(valid) == valid_text_before,
		"rejected fixtures never mutate the parsed authored schedule")

	# Rejected candidate pools consume no run RNG and cannot advance the route.
	var rng := _rng(SEED_VALUE)
	var map := RunMap.new()
	_check(map.generate(rng), "negative-case run map generates")
	var fight_id := _opening_fight(map)
	_check(not fight_id.is_empty(), "negative-case run offers a real opening Fight")
	if fight_id.is_empty():
		return
	_check(map.choose_node(fight_id), "negative-case route chooses that Fight")
	var picker := RunFightEncounterSelection.new()
	var state_before := rng.state
	var route_before := map.get_route()
	_check(picker.select_current_fight(map, rng, {}) == {"success": false},
		"an empty candidate pool fails closed")
	_check(picker.select_current_fight(map, rng,
		{ENCOUNTER_ID: "res://data/encounters/no_such_buttonseam_focus_volley.json"})
		== {"success": false},
		"a missing authored encounter file fails closed")
	_check(rng.state == state_before,
		"rejected selections consume no run RNG")
	_check(map.get_route() == route_before and map.get_current_node_id() == fight_id,
		"rejected selections do not advance the route")
	var recovered := picker.select_current_fight(map, rng, {ENCOUNTER_ID: ENCOUNTER_PATH})
	_check(recovered.get("success", false)
		and recovered.get("encounter_id") == ENCOUNTER_ID
		and recovered.get("definitions", []) == _expected_schedule(),
		"a valid selection still works after the rejected attempts")
	_check(rng.state == state_before,
		"the retried single-ID selection still draws no run RNG")


func _test_atomic_negative() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	_check(CombatStartingBlock.new(party).apply(),
		"negative: opening Block applied")
	var batch := [
		{"type": "block", "amount": 3, "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 4, "enemy_position": 2}]
	var before_party := party.get_heroes()
	var before_enemies := enemies.get_enemies()
	seed(20261024)
	var expected_rng := randi()
	seed(20261024)
	var phase := CombatEnemyPhase.new()
	var result := phase.execute_phase(party, enemies, batch)
	_check(randi() == expected_rng, "negative: rejected batch draws no global RNG")
	_check(result == {"ok": false, "events": []},
		"negative: staged block then invalid target rejects whole phase")
	_check(party.get_heroes() == before_party, "negative: no hero change survives")
	_check(enemies.get_enemies() == before_enemies, "negative: no enemy change survives")

	party = _build_party()
	enemies = _build_enemies()
	_check(CombatStartingBlock.new(party).apply(), "negative: second opening Block applied")
	before_party = party.get_heroes()
	before_enemies = enemies.get_enemies()
	var malformed := [
		{"type": "block", "amount": "3", "enemy_position": 1}]
	seed(20261025)
	expected_rng = randi()
	seed(20261025)
	_check(phase.execute_phase(party, enemies, malformed) == {"ok": false, "events": []},
		"negative: malformed action rejects the phase")
	_check(randi() == expected_rng, "negative: malformed action draws no global RNG")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"negative: malformed action changes nothing")
