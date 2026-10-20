extends SceneTree
## M03 authored Fight content: the Frayed Backline Barrage schedule.
##
## Slot 1 (Ragling) and slot 2 (Guard Ragling) each run an independent
## three-beat cycle. Beat 0 doubles the backline, beat 1 keeps slot 1 on the
## backline while slot 2 guards, and beat 2 lifts slot 1's guard while slot 2
## turns to the front. This file proves the authored data through the real
## shared parser, the real CombatEnemyIntents service and the real seeded
## RunMap + RunFightEncounterSelection path. Live app Fight-pool wiring is a
## separate later task, so no mounted Fight is claimed here.

const ENCOUNTER_ID := "frayed_backline_barrage"
const ENCOUNTER_PATH := "res://data/encounters/frayed_backline_barrage.json"
const STARTER_ID := "starter_attacks"
const STARTER_PATH := "res://data/encounters/starter_attacks.json"
const SEED_VALUE := 4103
const FAIL_CLOSED_SEED := 90210
const GLOBAL_SEED := 24680

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_authored_file()
	_test_intent_cycle()
	_test_selector_pick_and_replay()
	_test_fail_closed_and_retry()
	_test_named_previous_schedules()
	if failures.is_empty():
		print("frayed_backline_barrage_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("frayed_backline_barrage_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## The exact authored schedule: slot 1 attacks the back hero twice then gains
## Block; slot 2 attacks the back hero, gains Block, then attacks the front.
func _expected_schedule() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 3},
			{"type": "attack", "amount": 1, "target_position": 3},
			{"type": "block", "amount": 1}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 3},
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 1}]},
	]


func _starter_schedule() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "attack", "amount": 1, "target_position": 3}]},
		{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]},
	]


func _expected_by_id(encounter_id: String) -> Array:
	if encounter_id == ENCOUNTER_ID:
		return _expected_schedule()
	if encounter_id == STARTER_ID:
		return _starter_schedule()
	return []


## Full announcement for one beat, including each source's enemy_position, in
## the ascending source order the scheduler promises.
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


func _load_text(path: String) -> String:
	_check(FileAccess.file_exists(path), path + " exists on disk")
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, path + " opens for reading")
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


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


func _pool(reversed_pool: bool = false) -> Dictionary:
	var pool := {}
	if reversed_pool:
		pool[STARTER_ID] = STARTER_PATH
		pool[ENCOUNTER_ID] = ENCOUNTER_PATH
	else:
		pool[ENCOUNTER_ID] = ENCOUNTER_PATH
		pool[STARTER_ID] = STARTER_PATH
	return pool


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


func _test_authored_file() -> void:
	var text := _load_text(ENCOUNTER_PATH)
	if text.is_empty():
		return
	var parser := JSON.new()
	_check(parser.parse(text) == OK, "frayed_backline_barrage is valid JSON")
	var raw = parser.data
	_check(raw is Array and raw.size() == 2,
		"frayed_backline_barrage holds exactly two source records")
	if not raw is Array or raw.size() != 2:
		return
	_check(_normalized_raw(raw) == _expected_schedule(),
		"raw authored JSON is exactly the two required three-beat source objects")
	for definition in raw:
		_check(definition is Dictionary and definition.size() == 2
			and definition.has("enemy_position") and definition.has("pattern"),
			"each raw source record carries only enemy_position and pattern")
		var raw_pattern = definition.get("pattern")
		_check(raw_pattern is Array and raw_pattern.size() == 3,
			"each raw source pattern holds exactly three beats")
		if raw_pattern is Array:
			for action in raw_pattern:
				var kind = action.get("type") if action is Dictionary else null
				if kind == "block":
					_check(action.size() == 2 and action.has("amount")
						and not action.has("target_position"),
						"raw Block actions carry only type and amount")
				else:
					_check(kind == "attack" and action.size() == 3
						and action.has("amount") and action.has("target_position"),
						"raw attack actions carry exactly type, amount and hero target")

	# The shared parser is the authority exercised here, not JSON.parse_string.
	var parsed := RunFightEncounterSelection._parse_schedule_text(text)
	_check(not parsed.is_empty(),
		"frayed_backline_barrage normalizes through the shared schedule parser")
	_check(parsed == _expected_schedule(),
		"parsed schedule is exactly the authored two-source three-beat sequence")
	if parsed.size() != 2:
		return

	var slot1 := _source_at(parsed, 1)
	var slot2 := _source_at(parsed, 2)
	_check(slot1.size() == 2 and slot1.has("enemy_position") and slot1.has("pattern"),
		"slot 1 carries only enemy_position and pattern")
	_check(slot2.size() == 2 and slot2.has("enemy_position") and slot2.has("pattern"),
		"slot 2 carries only enemy_position and pattern")

	var slot1_pattern: Array = slot1.get("pattern", [])
	var slot2_pattern: Array = slot2.get("pattern", [])
	_check(slot1_pattern.size() == 3, "slot 1 has an independent three-beat cycle")
	_check(slot2_pattern.size() == 3, "slot 2 has an independent three-beat cycle")
	_check(slot1_pattern[0] == {"type": "attack", "amount": 1, "target_position": 3},
		"slot 1 beat 0 is Attack 1 at back hero position 3")
	_check(slot1_pattern[1] == {"type": "attack", "amount": 1, "target_position": 3},
		"slot 1 beat 1 is Attack 1 at back hero position 3")
	_check(slot1_pattern[2] == {"type": "block", "amount": 1},
		"slot 1 beat 2 is an untargeted Block 1")
	_check(slot2_pattern[0] == {"type": "attack", "amount": 1, "target_position": 3},
		"slot 2 beat 0 is Attack 1 at back hero position 3")
	_check(slot2_pattern[1] == {"type": "block", "amount": 1},
		"slot 2 beat 1 is an untargeted Block 1")
	_check(slot2_pattern[2] == {"type": "attack", "amount": 1, "target_position": 1},
		"slot 2 beat 2 is Attack 1 at front hero position 1")

	# Beat 0 doubles the backline; beat 1 keeps slot 1's pressure while slot 2
	# guards; beat 2 lifts slot 1's guard and moves slot 2 to the front.
	_check(slot1_pattern[0] == slot2_pattern[0],
		"beat 0 has both sources attacking the back hero")
	_check(slot1_pattern[1].get("type") == "attack"
		and slot1_pattern[1].get("target_position") == 3
		and slot2_pattern[1].get("type") == "block",
		"beat 1 keeps slot 1 on the backline while slot 2 guards")
	_check(slot1_pattern[2].get("type") == "block"
		and slot2_pattern[2].get("type") == "attack"
		and slot2_pattern[2].get("target_position") == 1,
		"beat 2 replaces back pressure with front pressure")

	# Numeric integers and exact record keys only; no float drift or extras.
	for definition in parsed:
		_check(definition.get("enemy_position") is int,
			"parsed enemy_position is an integer, not a float")
		for action in definition["pattern"]:
			_check(action.get("amount") is int, "parsed amount is an integer")
			if action.get("type") == "attack":
				_check(action.get("target_position") is int,
					"parsed attack target_position is an integer")
				_check(action.size() == 3,
					"parsed attack carries no unexpected action keys")
			else:
				_check(action.size() == 2,
					"parsed Block carries no unexpected action keys")

	# The same parser must still fail closed on malformed variants of this text,
	# so the passing checks above are not vacuously permissive.
	var malformed_texts := [
		text.replace("\"target_position\": 3", "\"target_position\": 4"),
		text.replace("\"amount\": 1", "\"amount\": 1.5"),
		text.replace("{\"type\": \"block\", \"amount\": 1}",
			"{\"type\": \"block\", \"amount\": 1, \"extra\": 2}"),
		text.replace("\"enemy_position\": 2", "\"enemy_position\": 1"),
	]
	for i in range(malformed_texts.size()):
		_check(RunFightEncounterSelection._parse_schedule_text(malformed_texts[i]).is_empty(),
			"malformed variant %d of the real text is rejected before selection" % i)


func _test_intent_cycle() -> void:
	var parsed := _parsed_definitions()
	_check(not parsed.is_empty(), "real authored file parses into an intent fixture")
	if parsed.is_empty():
		return
	var original := parsed.duplicate(true)
	var caller_owned := parsed.duplicate(true)
	var intents := CombatEnemyIntents.new(caller_owned)
	_check(intents.is_valid(), "the real authored schedule passes the intent validator")
	if not intents.is_valid():
		return

	# A seeded global probe proves the scheduler never touches Godot's global
	# RNG, with a control that an injected draw would be detected.
	seed(GLOBAL_SEED)
	var probe_expected := randi()
	seed(GLOBAL_SEED)
	randi()
	var probe_with_extra := randi()
	_check(probe_with_extra != probe_expected,
		"global RNG probe detects an injected extra draw")

	seed(GLOBAL_SEED)
	var global_expected_intents := randi()
	seed(GLOBAL_SEED)
	var timeline: Array = []
	for beat in range(6):
		var announced := intents.get_intents()
		timeline.append(announced)
		_check(announced == _expected_beat(beat),
			"beat %d announces the exact full authored actions for both sources" % beat)
		_check(_positions_of(announced) == [1, 2],
			"beat %d announces sources in ascending enemy_position order" % beat)
		_check(announced.size() == 2, "beat %d announces one action per source" % beat)
		_check(intents.get_intents() == announced,
			"beat %d repeated read does not advance the schedule" % beat)
		if beat < 5:
			_check(intents.advance_turn(), "beat %d advances both source patterns" % beat)
	var global_after_intents := randi()
	_check(global_after_intents == global_expected_intents,
		"the full intent cycle leaves the Godot global RNG undrawn")

	_check(timeline.size() == 6, "the timeline covers six beats")
	_check(timeline[3] == timeline[0] and timeline[4] == timeline[1]
		and timeline[5] == timeline[2],
		"beats 3-5 reproduce beats 0-2 exactly by modulo-3 wrap")
	_check(timeline[0] == [
		{"type": "attack", "amount": 1, "target_position": 3, "enemy_position": 1},
		{"type": "attack", "amount": 1, "target_position": 3, "enemy_position": 2}],
		"beat 0 is the double backline barrage")
	_check(timeline[1] == [
		{"type": "attack", "amount": 1, "target_position": 3, "enemy_position": 1},
		{"type": "block", "amount": 1, "enemy_position": 2}],
		"beat 1 keeps slot 1's backline pressure while slot 2 guards")
	_check(timeline[2] == [
		{"type": "block", "amount": 1, "enemy_position": 1},
		{"type": "attack", "amount": 1, "target_position": 1, "enemy_position": 2}],
		"beat 2 trades back pressure for front pressure")

	# A completely fresh instance replays the entire required timeline.
	var replay := CombatEnemyIntents.new(parsed)
	_check(replay.is_valid(), "a fresh scheduler is valid")
	for beat in range(6):
		_check(replay.get_intents() == timeline[beat],
			"fresh scheduler replays beat %d exactly" % beat)
		if beat < 5:
			_check(replay.advance_turn(), "fresh scheduler advances beat %d" % beat)

	# Mutating an already returned announcement cannot alter later reads.
	timeline[1][0]["amount"] = 900
	timeline[1][0]["target_position"] = 2
	timeline[1][1]["enemy_position"] = 3
	timeline[1].append({"type": "block", "amount": 9, "enemy_position": 3})
	_check(intents.get_intents() == timeline[5],
		"mutating an earlier returned announcement leaves the current read intact")
	_check(intents.get_intents() == _expected_beat(5),
		"the current announcement still matches the authored beat 5")
	_check(replay.get_intents() == _expected_beat(5),
		"the replayed scheduler is also unaffected by that mutation")

	# The service owns a deep copy of the supplied definitions.
	caller_owned[0]["pattern"][0]["amount"] = 42
	caller_owned[1]["pattern"].clear()
	_check(intents.is_valid() and intents.get_intents() == _expected_beat(5),
		"mutating the supplied definitions cannot corrupt the scheduler")
	_check(parsed == original,
		"the caller's parsed definitions are unchanged by the scheduler")

	# Authored order is not trusted: the service sorts by source position.
	var reversed := parsed.duplicate(true)
	reversed.reverse()
	var reversed_intents := CombatEnemyIntents.new(reversed)
	_check(reversed_intents.is_valid(), "reversed authored order is still valid")
	_check(_positions_of(reversed_intents.get_intents()) == [1, 2],
		"announcements sort by enemy_position even when authored order is reversed")


func _test_selector_pick_and_replay() -> void:
	var rng := _rng(SEED_VALUE)
	var map := RunMap.new()
	_check(map.generate(rng), "seeded run map generates")
	var fight_id := _opening_fight(map)
	_check(not fight_id.is_empty() and map.get_legal_choices().has(fight_id),
		"the generated map offers a genuinely legal opening Fight")
	if fight_id.is_empty():
		return
	_check(map.choose_node(fight_id), "the route chooses that real opening Fight")
	_check(map.get_current_node_id() == fight_id and map.get_current_floor() == 1
		and map.get_node(fight_id).get("type") == "Fight",
		"the chosen current node is that Fight on floor one")

	# A separate same-seed oracle generates the identical map and then makes the
	# single sorted-ID draw the service is documented to make.
	var oracle_rng := _rng(SEED_VALUE)
	var oracle_map := RunMap.new()
	_check(oracle_map.generate(oracle_rng), "a separate same-seed oracle generates")
	_check(oracle_map.get_floors() == map.get_floors(),
		"the oracle reproduces the identical graph before selection")
	_check(oracle_map.choose_node(fight_id),
		"the oracle reaches the same real Fight")
	var pool := _pool()
	var ids: Array = pool.keys()
	ids.sort()
	_check(ids == [ENCOUNTER_ID, STARTER_ID],
		"the injected pool holds exactly the new encounter and starter_attacks")
	var expected_id: String = ids[oracle_rng.randi_range(0, ids.size() - 1)]
	var expected_state := oracle_rng.state

	var route_before := map.get_route()
	var floors_before := map.get_floors()
	var choices_before := map.get_legal_choices()
	var state_before := rng.state

	seed(GLOBAL_SEED)
	var global_expected := randi()
	seed(GLOBAL_SEED)
	var selector := RunFightEncounterSelection.new()
	var answer := selector.select_current_fight(map, rng, pool)
	var global_after := randi()
	_check(global_after == global_expected,
		"selection leaves the Godot global RNG undrawn")

	_check(answer.get("success", false) == true,
		"the real selector accepts a pool containing frayed_backline_barrage")
	_check(answer.get("encounter_id") == expected_id,
		"selection is exactly one sorted-ID RNG draw")
	_check(answer.get("definitions", []) == _expected_by_id(expected_id),
		"selection returns the complete authored schedule for the drawn ID")
	_check(rng.state == expected_state,
		"selection leaves the exact one-draw run RNG state")
	_check(map.get_route() == route_before and map.get_floors() == floors_before
		and map.get_legal_choices() == choices_before
		and map.get_current_node_id() == fight_id,
		"selection never advances or re-chooses the route")

	# Reversed Dictionary insertion order must replay identically.
	var replay_rng := _rng(SEED_VALUE)
	var replay_map := RunMap.new()
	_check(replay_map.generate(replay_rng) and replay_map.choose_node(fight_id),
		"the same-seed replay reaches the same real Fight")
	var replay_answer := RunFightEncounterSelection.new().select_current_fight(
		replay_map, replay_rng, _pool(true))
	_check(replay_answer == answer and replay_rng.state == rng.state,
		"a fresh same-seed run with reversed pool insertion order replays exactly")

	# Cached retrieval consumes no more run RNG, even with an empty pool.
	var pristine := answer.duplicate(true)
	var cached := selector.select_current_fight(map, rng, {})
	_check(cached == pristine and rng.state == expected_state,
		"a cached re-query returns the same choice with no pool and zero extra RNG")

	# Two caller mutations cannot corrupt later cached reads.
	answer["definitions"][0]["pattern"][0]["amount"] = 900
	answer["definitions"][0]["pattern"][0]["target_position"] = 2
	answer["definitions"].clear()
	answer["encounter_id"] = "mutated"
	answer["success"] = false
	cached["definitions"][0]["pattern"][0]["type"] = "invented"
	cached["definitions"].append({"fake": true})
	var after_mutation := selector.select_current_fight(map, rng, pool)
	_check(after_mutation == pristine,
		"mutating two earlier results cannot alter the later cached read")
	_check(after_mutation.get("definitions", []) == _expected_by_id(expected_id),
		"the later cached read still returns the original authored data")
	_check(rng.state == expected_state,
		"mutating and re-reading the cached result consumes no run RNG")

	# Both injected candidates are genuinely reachable, and the real selector's
	# returned frayed definitions feed the real intent scheduler.
	var seen: Array = []
	var frayed_answer: Dictionary = {}
	for attempt in range(16):
		var attempt_seed := SEED_VALUE + 17 * attempt
		var attempt_rng := _rng(attempt_seed)
		var attempt_map := RunMap.new()
		if not attempt_map.generate(attempt_rng):
			continue
		var attempt_fight := _opening_fight(attempt_map)
		if attempt_fight.is_empty() or not attempt_map.choose_node(attempt_fight):
			continue
		var attempt_oracle := _rng(attempt_seed)
		var attempt_oracle_map := RunMap.new()
		attempt_oracle_map.generate(attempt_oracle)
		var attempt_ids: Array = pool.keys()
		attempt_ids.sort()
		var attempt_expected: String = attempt_ids[
			attempt_oracle.randi_range(0, attempt_ids.size() - 1)]
		var attempt_answer := RunFightEncounterSelection.new().select_current_fight(
			attempt_map, attempt_rng, pool)
		_check(attempt_answer.get("success", false)
			and attempt_answer.get("encounter_id") == attempt_expected,
			"seed %d selects exactly its oracle ID" % attempt_seed)
		_check(attempt_answer.get("definitions", []) == _expected_by_id(attempt_expected),
			"seed %d returns the complete definition of the drawn candidate" % attempt_seed)
		_check(attempt_rng.state == attempt_oracle.state,
			"seed %d ends in the exact one-draw seeded RNG state" % attempt_seed)
		if not seen.has(attempt_expected):
			seen.append(attempt_expected)
		if attempt_expected == ENCOUNTER_ID and frayed_answer.is_empty():
			frayed_answer = attempt_answer
		if seen.size() == 2:
			break
	_check(seen.has(ENCOUNTER_ID) and seen.has(STARTER_ID),
		"the injected pool genuinely returns both authored candidates across seeds")
	_check(seen.size() == 2,
		"the two-candidate pool never returns anything outside it")
	_check(not frayed_answer.is_empty(),
		"the real selector actually returned a frayed_backline_barrage schedule")
	if frayed_answer.is_empty():
		return
	var picked_intents := CombatEnemyIntents.new(frayed_answer.get("definitions", []))
	_check(picked_intents.is_valid(),
		"the selected frayed definitions instantiate a real valid scheduler")
	for beat in range(6):
		_check(picked_intents.get_intents() == _expected_beat(beat),
			"selected frayed definitions announce the authored beat %d" % beat)
		if beat < 5:
			_check(picked_intents.advance_turn(),
				"selected frayed scheduler advances beat %d" % beat)


func _test_fail_closed_and_retry() -> void:
	var rng := _rng(FAIL_CLOSED_SEED)
	var map := RunMap.new()
	_check(map.generate(rng), "fail-closed fixture map generates")
	var fight_id := _opening_fight(map)
	_check(not fight_id.is_empty() and map.get_legal_choices().has(fight_id),
		"fail-closed fixture offers a legal opening Fight")
	if fight_id.is_empty():
		return

	var picker := RunFightEncounterSelection.new()
	var unselected_before := _snapshot(map, rng, picker)
	var unselected_answer := picker.select_current_fight(map, rng, _pool())
	_check(unselected_answer == {"success": false},
		"a legal but UNCHOSEN Fight is rejected")
	_check(_snapshot(map, rng, picker) == unselected_before,
		"unselected Fight rejection leaves graph, run RNG, binding and cache unchanged")
	_check(picker._bound_map == null and picker._selected.is_empty(),
		"unselected Fight rejection binds no selection")

	_check(map.choose_node(fight_id), "the fixture route now chooses that Fight")
	var chosen_before := _snapshot(map, rng, picker)

	# Every rejected candidate pool must fail closed before consuming run RNG
	# or binding a selection, even when a valid encounter sits beside the fault.
	var bad_pools: Array = [
		{"label": "missing companion candidate", "pool": {
			ENCOUNTER_ID: ENCOUNTER_PATH,
			"missing_companion": "res://data/encounters/no_such_backline_barrage.json"}},
		{"label": "out-of-directory companion candidate", "pool": {
			ENCOUNTER_ID: ENCOUNTER_PATH,
			"redirected": "res://data/enemies/starter_enemies.json"}},
		{"label": "noncanonical companion path", "pool": {
			ENCOUNTER_ID: ENCOUNTER_PATH,
			"traversal": "res://data/encounters/../enemies/starter_enemies.json"}},
		{"label": "non-string companion path", "pool": {
			ENCOUNTER_ID: ENCOUNTER_PATH, "bad_path": null}},
		{"label": "non-string companion ID", "pool": {
			ENCOUNTER_ID: ENCOUNTER_PATH, 7: STARTER_PATH}},
	]
	for fixture in bad_pools:
		var label: String = fixture["label"]
		var candidate_pool: Dictionary = fixture["pool"]
		var rejected := picker.select_current_fight(map, rng, candidate_pool)
		_check(rejected == {"success": false}, label + ": rejected fail-closed")
		_check(_snapshot(map, rng, picker) == chosen_before,
			label + ": consumed no run RNG and changed no graph, route or binding")
		_check(picker._bound_map == null and picker._selected.is_empty(),
			label + ": cached and bound nothing")

	# A clean valid retry still succeeds and spends exactly its one draw.
	var expected_ids: Array = _pool().keys()
	expected_ids.sort()
	var retry_oracle := _rng(FAIL_CLOSED_SEED)
	var retry_oracle_map := RunMap.new()
	_check(retry_oracle_map.generate(retry_oracle)
		and retry_oracle_map.choose_node(fight_id),
		"the retry oracle reaches the same real Fight")
	var expected_id: String = expected_ids[
		retry_oracle.randi_range(0, expected_ids.size() - 1)]
	var expected_state := retry_oracle.state
	var retry := picker.select_current_fight(map, rng, _pool())
	_check(retry.get("success", false) == true
		and retry.get("encounter_id") == expected_id
		and retry.get("definitions", []) == _expected_by_id(expected_id),
		"a clean valid retry still selects a real authored encounter")
	_check(rng.state == expected_state,
		"the clean retry spends exactly one draw after zero rejected draws")
	_check(picker._bound_map == map and picker._selected.has(fight_id),
		"the clean retry binds the fixture map and caches its Fight choice")

	# A chosen non-Fight node must also be rejected before RNG or binding.
	var nonfight_found := false
	var nonfight_map: RunMap = null
	var nonfight_rng: RandomNumberGenerator = null
	for attempt in range(24):
		var attempt_rng := _rng(FAIL_CLOSED_SEED + 31 * attempt)
		var attempt_map := RunMap.new()
		if not attempt_map.generate(attempt_rng):
			continue
		for floor_number in range(1, 13):
			var legal := attempt_map.get_legal_choices()
			if legal.is_empty():
				break
			var pick: String = legal[0]
			for candidate in legal:
				if attempt_map.get_node(candidate).get("type") != "Fight":
					pick = candidate
					break
			if not attempt_map.choose_node(pick):
				break
			if attempt_map.get_node(pick).get("type") != "Fight":
				nonfight_map = attempt_map
				nonfight_rng = attempt_rng
				nonfight_found = true
				break
		if nonfight_found:
			break
	_check(nonfight_found, "a seeded route reaches a genuinely chosen non-Fight node")
	if nonfight_found:
		var kind: String = nonfight_map.get_node(
			nonfight_map.get_current_node_id()).get("type")
		_check(kind != "Fight", "the current node is a real non-Fight (" + kind + ")")
		var nonfight_picker := RunFightEncounterSelection.new()
		var nonfight_before := _snapshot(nonfight_map, nonfight_rng, nonfight_picker)
		var nonfight_answer := nonfight_picker.select_current_fight(
			nonfight_map, nonfight_rng, _pool())
		_check(nonfight_answer == {"success": false},
			"a chosen non-Fight node is rejected")
		_check(_snapshot(nonfight_map, nonfight_rng, nonfight_picker)
			== nonfight_before,
			"non-Fight rejection changes no run RNG, binding or route")
		_check(nonfight_picker._bound_map == null
			and nonfight_picker._selected.is_empty(),
			"non-Fight rejection binds and caches nothing")


func _test_named_previous_schedules() -> void:
	# Presence and parseability of the named established entries only: no
	# global encounter total and no full ordered catalog list are asserted.
	var schedules := {
		"starter_attacks": STARTER_PATH,
		"guard_counterattack": "res://data/encounters/guard_counterattack.json",
		"needleline_pressure": "res://data/encounters/needleline_pressure.json",
		"ragling_rearline_feint": "res://data/encounters/ragling_rearline_feint.json",
		"cross_stitch_guard": "res://data/encounters/cross_stitch_guard.json",
	}
	for id in schedules:
		var path: String = schedules[id]
		_check(FileAccess.file_exists(path), id + ": named previous schedule still exists")
		var file := FileAccess.open(path, FileAccess.READ)
		_check(file != null, id + ": named previous schedule still opens")
		if file == null:
			continue
		var parsed := RunFightEncounterSelection._parse_schedule_text(file.get_as_text())
		file.close()
		_check(not parsed.is_empty(), id + ": named previous schedule still parses")
		_check(CombatEnemyIntents.new(parsed).is_valid(),
			id + ": named previous schedule still passes the intent validator")
