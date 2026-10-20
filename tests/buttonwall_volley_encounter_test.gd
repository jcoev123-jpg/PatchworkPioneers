extends SceneTree
## M03 independent Fight content: the authored Buttonwall Volley schedule
## (two existing starter sources advancing in lockstep) and its reachability
## through the real seeded RunMap + RunFightEncounterSelection service path.
## Live app Fight-pool wiring is deliberately out of scope for this lane.

const ENCOUNTER_PATH := "res://data/encounters/buttonwall_volley.json"
const ENCOUNTER_ID := "buttonwall_volley"
const SEED_VALUE := 4103
const STARTER_PATH := "res://data/encounters/starter_attacks.json"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_authored_file()
	_test_scheduler_beats()
	_test_route_selection()
	_test_invalid_schedules()
	_test_named_previous_schedules()
	if failures.is_empty():
		print("buttonwall_volley_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("buttonwall_volley_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## The exact authored schedule of AC1: slot 1 Ragling and slot 2 Guard Ragling,
## each on a three-beat cycle. Block records never carry a hero target.
func _expected_schedule() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "attack", "amount": 1, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 3},
			{"type": "block", "amount": 1}]},
	]


## Full announcement for one beat, including each source's enemy_position,
## in the ascending source order the scheduler promises.
func _expected_beat(beat: int) -> Array:
	var actions: Array = []
	for definition in _expected_schedule():
		var pattern: Array = definition["pattern"]
		var action: Dictionary = pattern[beat % pattern.size()].duplicate(true)
		action["enemy_position"] = definition["enemy_position"]
		actions.append(action)
	return actions


## JSON numbers arrive as floats; normalize integral values so the raw authored
## text can be compared with the exact expected integer schedule.
func _normalized_raw(value: Variant) -> Variant:
	if value is float and is_finite(value) and floorf(value) == value:
		return int(value)
	if value is Array:
		var items: Array = []
		for item in value:
			items.append(_normalized_raw(item))
		return items
	if value is Dictionary:
		var record: Dictionary = {}
		for key in value:
			record[key] = _normalized_raw(value[key])
		return record
	return value


func _positions_of(announced: Array) -> Array:
	var positions: Array = []
	for action in announced:
		positions.append(action.get("enemy_position"))
	return positions


func _parsed_definitions() -> Array:
	if not FileAccess.file_exists(ENCOUNTER_PATH):
		return []
	var file := FileAccess.open(ENCOUNTER_PATH, FileAccess.READ)
	if file == null:
		return []
	var text := file.get_as_text()
	file.close()
	return RunFightEncounterSelection._parse_schedule_text(text)


func _source_at(definitions: Array, position: int) -> Dictionary:
	var matches: Array = []
	for definition in definitions:
		if definition is Dictionary and definition.get("enemy_position") == position:
			matches.append(definition)
	_check(matches.size() == 1,
		"schedule has exactly one source at enemy_position %d" % position)
	return {} if matches.is_empty() else matches[0]


func _enemy_by_id(roster: Array, enemy_id: String) -> Dictionary:
	var matches: Array = []
	for definition in roster:
		if definition is Dictionary and definition.get("id") == enemy_id:
			matches.append(definition)
	_check(matches.size() == 1, "starter roster has exactly one enemy named " + enemy_id)
	return {} if matches.is_empty() else matches[0]


func _opening_fight(map: RunMap) -> String:
	var choices := map.get_legal_choices()
	for id in choices:
		if map.get_node(id).get("type") == "Fight":
			return id
	return ""


func _named_previous_schedules() -> Dictionary:
	return {
		"starter_attacks": "res://data/encounters/starter_attacks.json",
		"guard_counterattack": "res://data/encounters/guard_counterattack.json",
		"ragling_rearline_feint": "res://data/encounters/ragling_rearline_feint.json",
		"cross_stitch_guard": "res://data/encounters/cross_stitch_guard.json",
		"needleline_pressure": "res://data/encounters/needleline_pressure.json",
	}


func _test_authored_file() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH),
		"buttonwall_volley authored encounter exists")
	var file := FileAccess.open(ENCOUNTER_PATH, FileAccess.READ)
	_check(file != null, "buttonwall_volley authored file opens")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()

	var parser := JSON.new()
	_check(parser.parse(text) == OK, "buttonwall_volley is valid JSON")
	var raw = parser.data
	_check(raw is Array and raw.size() == 2,
		"buttonwall_volley holds exactly two source records")
	_check(raw is Array and _normalized_raw(raw) == _expected_schedule(),
		"raw authored JSON carries exactly the two required source objects")

	var parsed := RunFightEncounterSelection._parse_schedule_text(text)
	_check(not parsed.is_empty(),
		"buttonwall_volley normalizes through the shared schedule parser")
	_check(parsed.size() == 2, "normalized schedule keeps exactly two sources")
	if parsed.size() != 2:
		return

	var slot1 := _source_at(parsed, 1)
	var slot2 := _source_at(parsed, 2)
	_check(slot1 == _expected_schedule()[0],
		"slot 1 Ragling: block 1, attack 1 at hero 1, attack 1 at hero 2")
	_check(slot2 == _expected_schedule()[1],
		"slot 2 Guard Ragling: block 1, attack 1 at hero 3, block 1")
	_check(slot1.size() == 2 and slot1.has("enemy_position") and slot1.has("pattern"),
		"slot 1 carries only enemy_position and pattern")
	_check(slot2.size() == 2 and slot2.has("enemy_position") and slot2.has("pattern"),
		"slot 2 carries only enemy_position and pattern")

	var slot1_pattern: Array = slot1.get("pattern", [])
	var slot2_pattern: Array = slot2.get("pattern", [])
	_check(slot1_pattern.size() == 3, "slot 1 has a three-beat cycle")
	_check(slot2_pattern.size() == 3, "slot 2 has a three-beat cycle")
	_check(slot1_pattern[0] == {"type": "block", "amount": 1},
		"slot 1 beat 0 is an untargeted Block 1")
	_check(slot1_pattern[1] == {"type": "attack", "amount": 1, "target_position": 1},
		"slot 1 beat 1 is Attack 1 at hero position 1")
	_check(slot1_pattern[2] == {"type": "attack", "amount": 1, "target_position": 2},
		"slot 1 beat 2 is Attack 1 at hero position 2")
	_check(slot2_pattern[0] == {"type": "block", "amount": 1},
		"slot 2 beat 0 is an untargeted Block 1")
	_check(slot2_pattern[1] == {"type": "attack", "amount": 1, "target_position": 3},
		"slot 2 beat 1 is Attack 1 at hero position 3")
	_check(slot2_pattern[2] == {"type": "block", "amount": 1},
		"slot 2 beat 2 is an untargeted Block 1")

	# Every record keeps the documented shape exactly: attacks are the only
	# actions that name a hero, and Block never does.
	for source in [slot1, slot2]:
		for action in source["pattern"]:
			var kind: String = action.get("type", "")
			if kind == "block":
				_check(not action.has("target_position") and action.size() == 2,
					"every Block record has only type and amount")
				_check(action.get("amount") == 1, "every Block amount is exactly 1")
			else:
				_check(kind == "attack", "every non-Block action is an attack")
				_check(action.has("target_position") and action.size() == 3,
					"every attack record carries a hero target")
				_check(action.get("target_position") in [1, 2, 3],
					"every attack target position is a real hero slot")
				_check(action.get("amount") == 1, "every attack amount is exactly 1")

	# The sources are the unchanged two-enemy starter roster, not new enemies.
	var enemy_file := FileAccess.open("res://data/enemies/starter_enemies.json", FileAccess.READ)
	_check(enemy_file != null, "starter enemy roster opens")
	if enemy_file == null:
		return
	var enemy_parser := JSON.new()
	_check(enemy_parser.parse(enemy_file.get_as_text()) == OK,
		"starter enemy roster parses")
	enemy_file.close()
	var roster = enemy_parser.data
	_check(roster is Array, "starter enemy roster is a list")
	if not roster is Array:
		return
	var ragling := _enemy_by_id(roster, "ragling")
	var guard := _enemy_by_id(roster, "ragling_guard")
	_check(ragling.get("name") == "Ragling" and int(ragling.get("max_hp", 0)) == 12,
		"slot 1 is the existing Ragling with 12 max HP")
	_check(guard.get("name") == "Guard Ragling" and int(guard.get("max_hp", 0)) == 12,
		"slot 2 is the existing Guard Ragling with 12 max HP")
	_check(not String(ragling.get("art_path", "")).is_empty()
		and ragling.get("art_path") == guard.get("art_path"),
		"both sources still reuse the one existing ragling image path")
	_check(roster.size() >= 2,
		"the two source positions fit the existing starter enemy roster")


func _test_scheduler_beats() -> void:
	var parsed := _parsed_definitions()
	_check(not parsed.is_empty(),
		"real authored file parses into a scheduler fixture")
	if parsed.is_empty():
		return
	var intents := CombatEnemyIntents.new(parsed)
	_check(intents.is_valid(),
		"the real authored schedule passes the intent validator")
	if not intents.is_valid():
		return

	var timeline: Array = []
	for beat in range(4):
		var announced := intents.get_intents()
		timeline.append(announced)
		_check(announced == _expected_beat(beat),
			"beat %d announces the exact full authored actions" % beat)
		_check(_positions_of(announced) == [1, 2],
			"beat %d announces sources in ascending enemy_position order" % beat)
		_check(announced.size() == 2, "beat %d announces one action per source" % beat)
		_check(intents.get_intents() == announced,
			"beat %d repeated read does not advance the schedule" % beat)
		if beat < 3:
			_check(intents.advance_turn(), "beat %d advances explicitly" % beat)
	_check(timeline.size() == 4 and timeline[3] == timeline[0],
		"beat 3 wraps exactly back to the beat 0 double defense")
	_check(timeline[0] == [
		{"type": "block", "amount": 1, "enemy_position": 1},
		{"type": "block", "amount": 1, "enemy_position": 2}],
		"beat 0 is the two-source untargeted Block 1 opening")
	_check(timeline[1] == [
		{"type": "attack", "amount": 1, "target_position": 1, "enemy_position": 1},
		{"type": "attack", "amount": 1, "target_position": 3, "enemy_position": 2}],
		"beat 1 is the split front/back volley")
	_check(timeline[2] == [
		{"type": "attack", "amount": 1, "target_position": 2, "enemy_position": 1},
		{"type": "block", "amount": 1, "enemy_position": 2}],
		"beat 2 presses the middle while the Guard blocks")

	# A completely fresh instance replays the same full timeline.
	var replay := CombatEnemyIntents.new(parsed)
	_check(replay.is_valid(), "a fresh scheduler is valid")
	for beat in range(4):
		_check(replay.get_intents() == timeline[beat],
			"fresh scheduler replays beat %d exactly" % beat)
		if beat < 3:
			_check(replay.advance_turn(), "fresh scheduler advances beat %d" % beat)

	# Authored order is not trusted: the service sorts by source position.
	var reversed := parsed.duplicate(true)
	reversed.reverse()
	var reversed_intents := CombatEnemyIntents.new(reversed)
	_check(reversed_intents.is_valid(), "reversed authored order is still valid")
	_check(_positions_of(reversed_intents.get_intents()) == [1, 2],
		"announcements come out sorted by enemy_position regardless of authored order")

	# Returned announcements are detached deep copies.
	var baseline := intents.get_intents()
	var mutated := intents.get_intents()
	_check(mutated.size() == 2, "a returned announcement is a two-action copy")
	if mutated.size() == 2:
		mutated[0]["amount"] = 900
		mutated[0]["type"] = "invented"
		mutated[1]["target_position"] = 1
		mutated[1]["enemy_position"] = 3
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

	# The scheduler also owns a deep copy of the caller's definition array.
	var caller_owned := parsed.duplicate(true)
	var guarded := CombatEnemyIntents.new(caller_owned)
	caller_owned[0]["pattern"][0]["amount"] = 42
	caller_owned[1]["pattern"].clear()
	_check(guarded.is_valid() and guarded.get_intents() == timeline[0],
		"mutating the caller-owned definition array cannot corrupt the scheduler")


func _test_route_selection() -> void:
	var rng := _rng(SEED_VALUE)
	var map := RunMap.new()
	_check(map.generate(rng), "seeded run map generates")
	if not map.is_generated():
		return
	var fight_id := _opening_fight(map)
	_check(not fight_id.is_empty(), "generated map offers a real opening Fight")
	if fight_id.is_empty():
		return
	_check(map.get_legal_choices().has(fight_id),
		"the opening Fight is a genuinely legal choice")
	var opening_choices := map.get_legal_choices()
	_check(map.choose_node(fight_id), "route chooses the real opening Fight")
	_check(map.get_current_node_id() == fight_id and map.get_current_floor() == 1,
		"the chosen current node is that Fight on floor one")

	var route_before := map.get_route()
	var floors_before := map.get_floors()
	var choices_before := map.get_legal_choices()
	var state_before := rng.state
	# An untouched same-seed stream tells us exactly what the next draw is.
	var oracle := _rng(SEED_VALUE)
	oracle.state = state_before
	var oracle_next := oracle.randi()
	var oracle_after := oracle.state

	# The service must never touch Godot's global RNG stream.
	seed(24680)
	var global_expected := randi()
	seed(24680)
	var selector := RunFightEncounterSelection.new()
	var pool := {ENCOUNTER_ID: ENCOUNTER_PATH}
	var answer := selector.select_current_fight(map, rng, pool)
	_check(randi() == global_expected, "selection leaves the Godot global RNG undrawn")

	var keys := answer.keys()
	keys.sort()
	_check(keys == ["definitions", "encounter_id", "success"],
		"a successful result has exactly the documented keys")
	_check(answer.get("success", false) == true,
		"the real selector accepts the buttonwall_volley candidate")
	_check(answer.get("encounter_id") == ENCOUNTER_ID,
		"selection returns the exact buttonwall_volley encounter ID")
	_check(answer.get("definitions", []) == _expected_schedule(),
		"selection returns the complete parsed authored schedule")

	# The selector reports only; it does not advance or re-choose the route.
	_check(map.get_route() == route_before,
		"selection leaves the chosen route exactly unchanged")
	_check(map.get_floors() == floors_before,
		"selection leaves the generated graph exactly unchanged")
	_check(map.get_current_node_id() == fight_id and map.get_current_floor() == 1,
		"selection does not advance the current node or floor")
	_check(map.get_legal_choices() == choices_before,
		"selection does not change the legal choices")
	_check(rng.state == state_before,
		"a single-ID pool selection draws no run RNG at all")

	# Cached retrieval: same answer, no pool needed, no extra draw.
	var original := answer.duplicate(true)
	var cached := selector.select_current_fight(map, rng, {})
	_check(cached == original,
		"cached re-query returns the same choice even with an empty pool")
	_check(rng.state == state_before, "cached re-query consumes no run RNG")
	_check(selector._selected.get(fight_id, {}).get("definitions", []) == _expected_schedule(),
		"the cached schedule is still the authored one")

	# Caller mutations of the returned result cannot corrupt the cache.
	answer["definitions"][0]["pattern"][1]["target_position"] = 3
	answer["definitions"][0]["pattern"][0]["amount"] = 900
	answer["definitions"][1]["pattern"].clear()
	answer["definitions"].clear()
	answer["encounter_id"] = "mutated"
	answer["success"] = false
	var after_mutation := selector.select_current_fight(map, rng, pool)
	_check(after_mutation == original,
		"a mutated selected-result snapshot cannot alter the next read")
	_check(after_mutation.get("definitions", []) == _expected_schedule(),
		"the next read returns the original authored data")
	_check(rng.state == state_before, "mutated-result re-read consumes no run RNG")

	# The returned selection feeds the real scheduler.
	var selected_intents := CombatEnemyIntents.new(after_mutation.get("definitions", []))
	_check(selected_intents.is_valid(),
		"the selected definitions instantiate a real valid scheduler")
	for beat in range(4):
		_check(selected_intents.get_intents() == _expected_beat(beat),
			"selected definitions announce the authored beat %d" % beat)
		if beat < 3:
			_check(selected_intents.advance_turn(), "selected scheduler advances beat %d" % beat)

	# Same seed reproduces the same map, route, choice and seeded state.
	var replay_rng := _rng(SEED_VALUE)
	var replay_map := RunMap.new()
	_check(replay_map.generate(replay_rng), "same-seed replay map generates")
	_check(replay_map.get_floors() == floors_before,
		"same seed reproduces the identical generated graph")
	_check(replay_map.get_legal_choices() == opening_choices,
		"same seed offers the identical opening choices")
	_check(replay_map.choose_node(fight_id),
		"the same-seed route chooses the same opening Fight")
	_check(replay_map.get_route() == route_before,
		"same seed reproduces the identical chosen route")
	_check(replay_map.get_legal_choices() == choices_before,
		"same seed offers the identical post-choice options")
	var replay_selector := RunFightEncounterSelection.new()
	var replay_answer := replay_selector.select_current_fight(replay_map, replay_rng, pool)
	_check(replay_answer == original,
		"the same seed selects the same authored buttonwall_volley schedule")
	_check(replay_rng.state == state_before,
		"the same seed ends in the identical seeded RNG state")
	_check(replay_map.get_route() == route_before,
		"the replay selection also leaves its route unchanged")

	# Control: a real two-ID pool does draw, so the state checks above are
	# sensitive to an extra selection draw rather than vacuously true.
	var control_rng := _rng(SEED_VALUE)
	var control_map := RunMap.new()
	_check(control_map.generate(control_rng) and control_map.choose_node(fight_id),
		"two-ID control run reaches the same real opening Fight")
	var control_state := control_rng.state
	var control_pool := {ENCOUNTER_ID: ENCOUNTER_PATH, "starter_attacks": STARTER_PATH}
	var control_answer := RunFightEncounterSelection.new().select_current_fight(
		control_map, control_rng, control_pool)
	_check(control_answer.get("success", false)
		and control_pool.has(control_answer.get("encounter_id", "")),
		"the two-ID control pool selects one of its authored candidates")
	_check(control_rng.state != control_state,
		"the two-ID control pool does consume one selection draw")

	# Finally prove the run RNG stream itself was never advanced above.
	_check(rng.randi() == oracle_next,
		"the run RNG stream is still exactly where the same-seed oracle was")
	_check(rng.state == oracle_after,
		"the run RNG state matches the untouched stream after one probe draw")


func _invalid_cases() -> Array:
	return [
		{"label": "duplicate enemy source position", "definitions": [
			{"enemy_position": 1, "pattern": [{"type": "block", "amount": 1}]},
			{"enemy_position": 1, "pattern": [
				{"type": "attack", "amount": 1, "target_position": 2}]}]},
		{"label": "out-of-bounds hero target", "definitions": [
			{"enemy_position": 1, "pattern": [
				{"type": "attack", "amount": 1, "target_position": 4}]}]},
		{"label": "zero hero target", "definitions": [
			{"enemy_position": 1, "pattern": [
				{"type": "attack", "amount": 1, "target_position": 0}]}]},
		{"label": "attack without a hero target", "definitions": [
			{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 1}]}]},
		{"label": "targeted Block", "definitions": [
			{"enemy_position": 1, "pattern": [
				{"type": "block", "amount": 1, "target_position": 2}]}]},
	]


func _test_invalid_schedules() -> void:
	var valid := _parsed_definitions()
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
		{ENCOUNTER_ID: "res://data/encounters/no_such_buttonwall_volley.json"})
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


func _test_named_previous_schedules() -> void:
	# Presence and parseability of the named established entries only: no
	# global encounter total and no full ordered catalog list are asserted.
	var schedules := _named_previous_schedules()
	for id in schedules:
		var path: String = schedules[id]
		_check(FileAccess.file_exists(path), id + ": named previous schedule exists")
		var file := FileAccess.open(path, FileAccess.READ)
		_check(file != null, id + ": named previous schedule opens")
		if file == null:
			continue
		var parsed := RunFightEncounterSelection._parse_schedule_text(file.get_as_text())
		file.close()
		_check(not parsed.is_empty(), id + ": named previous schedule still parses")
		_check(CombatEnemyIntents.new(parsed).is_valid(),
			id + ": named previous schedule still passes the intent validator")
