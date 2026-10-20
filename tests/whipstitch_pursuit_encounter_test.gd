extends SceneTree
## M03 authored Fight content: the Whipstitch Pursuit schedule.
##
## Slot 1 (Ragling) and slot 2 (Guard Ragling) each run an independent
## four-beat cycle. Beat 1 opens on the Warden and the Tinker, beat 2 keeps
## slot 1 on the middle while slot 2 guards, beat 3 swaps those roles, and
## beat 4 sends slot 1 to the back while slot 2 turns on the front. This file
## proves the authored data through the real shared parser, the real
## CombatEnemyIntents + CombatEnemyPhase services and the real seeded RunMap +
## RunFightEncounterSelection path. Live app Fight-pool wiring is a separate
## later task, so no mounted Fight is claimed here.

const ENCOUNTER_ID := "whipstitch_pursuit"
const ENCOUNTER_PATH := "res://data/encounters/whipstitch_pursuit.json"
const STARTER_ID := "starter_attacks"
const STARTER_PATH := "res://data/encounters/starter_attacks.json"
const GUARD_ID := "guard_counterattack"
const GUARD_PATH := "res://data/encounters/guard_counterattack.json"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMIES_PATH := "res://data/enemies/starter_enemies.json"
const SEED_VALUE := 4307
const FAIL_CLOSED_SEED := 91173
const GLOBAL_SEED := 31415

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_authored_file()
	_test_intent_cycle()
	_test_enemy_phases()
	_test_slain_source_semantics()
	_test_selector_pick_and_replay()
	_test_fail_closed_and_retry()
	_test_named_previous_schedules()
	if failures.is_empty():
		print("whipstitch_pursuit_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("whipstitch_pursuit_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## The exact authored schedule: slot 1 attacks the front, then the middle,
## guards, then hits the back; slot 2 attacks the back, guards, then the
## middle, then the front. Each source owns its own four-beat pattern.
func _expected_schedule() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 3}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 3},
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "attack", "amount": 1, "target_position": 1}]},
	]


func _starter_schedule() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "attack", "amount": 1, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]},
	]


func _guard_schedule() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 1}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 3},
			{"type": "block", "amount": 1}]},
	]


func _expected_by_id(encounter_id: String) -> Array:
	if encounter_id == ENCOUNTER_ID:
		return _expected_schedule()
	if encounter_id == STARTER_ID:
		return _starter_schedule()
	if encounter_id == GUARD_ID:
		return _guard_schedule()
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


## The exact execution events for each of the four beats on a fresh fixture.
func _expected_events(beat: int) -> Array:
	match beat:
		0:
			return [_attack_event(1, 1, true), _attack_event(2, 3, true)]
		1:
			return [_attack_event(1, 2, true), _block_event(2, true)]
		2:
			return [_block_event(1, true), _attack_event(2, 2, true)]
		3:
			return [_attack_event(1, 3, true), _attack_event(2, 1, true)]
	return []


## Expected [warden_hp, warden_block, seamstress_hp, tinker_hp,
## ragling_hp, ragling_block, guard_hp, guard_block] after each beat.
func _expected_state(beat: int) -> Array:
	match beat:
		0:
			return [40, 5, 30, 25, 12, 0, 12, 0]
		1:
			return [40, 5, 29, 25, 12, 0, 12, 1]
		2:
			return [40, 5, 28, 25, 12, 1, 12, 1]
		3:
			return [40, 4, 28, 24, 12, 1, 12, 1]
	return []


func _attack_event(source: int, target: int, applied: bool) -> Dictionary:
	return {"type": "attack", "enemy_position": source,
		"target_position": target, "applied": applied}


func _block_event(source: int, applied: bool) -> Dictionary:
	return {"type": "block", "enemy_position": source, "applied": applied}


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


## Loads an authored JSON array without trusting the scene tree.
func _load_json_array(path: String) -> Array:
	var text := _load_text(path)
	if text.is_empty():
		return []
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return []
	var parsed = _normalized_raw(parser.data)
	if not parsed is Array:
		return []
	return parsed


func _named_record(records: Array, key: String, value: Variant) -> Dictionary:
	var matches: Array = []
	for record in records:
		if record is Dictionary and record.get(key) == value:
			matches.append(record)
	_check(matches.size() == 1,
		"records contain exactly one %s == %s" % [key, str(value)])
	return {} if matches.is_empty() else matches[0].duplicate(true)


func _parsed_definitions() -> Array:
	var text := _load_text(ENCOUNTER_PATH)
	if text.is_empty():
		return []
	return RunFightEncounterSelection._parse_schedule_text(text)


func _authored_party() -> CombatParty:
	var heroes := _load_json_array(PARTY_PATH)
	var warden := _named_record(heroes, "id", "warden")
	var seamstress := _named_record(heroes, "id", "seamstress")
	var tinker := _named_record(heroes, "id", "tinker")
	_check(not warden.is_empty() and not seamstress.is_empty() and not tinker.is_empty(),
		"precondition: starter_party.json defines Warden, Seamstress and Tinker")
	var party := CombatParty.new([
		warden.duplicate(true), seamstress.duplicate(true), tinker.duplicate(true)])
	_check(party.is_valid(), "precondition: the authored starter party is valid")
	return party


func _authored_enemies() -> CombatEnemies:
	var roster := _load_json_array(ENEMIES_PATH)
	var ragling := _named_record(roster, "id", "ragling")
	var guard := _named_record(roster, "id", "ragling_guard")
	_check(not ragling.is_empty() and not guard.is_empty(),
		"precondition: starter_enemies.json defines ragling and ragling_guard")
	var enemies := CombatEnemies.new([ragling.duplicate(true), guard.duplicate(true)])
	_check(enemies.is_valid(), "precondition: the authored two-enemy roster is valid")
	return enemies


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
	_check(parser.parse(text) == OK, "whipstitch_pursuit.json is valid JSON")
	var raw = parser.data
	_check(raw is Array and raw.size() == 2,
		"whipstitch_pursuit.json holds exactly this encounter's two source records")
	if not raw is Array or raw.size() != 2:
		return
	_check(_normalized_raw(raw) == _expected_schedule(),
		"raw authored JSON is exactly the two required four-beat source objects")
	for definition in raw:
		_check(definition is Dictionary and definition.size() == 2
			and definition.has("enemy_position") and definition.has("pattern"),
			"each raw source record carries only enemy_position and pattern")
		var raw_pattern = definition.get("pattern")
		_check(raw_pattern is Array and raw_pattern.size() == 4,
			"each raw source pattern holds exactly four beats")
		if not raw_pattern is Array:
			continue
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
		"whipstitch_pursuit normalizes through the shared schedule parser")
	_check(parsed == _expected_schedule(),
		"parsed schedule is exactly the authored two-source four-beat sequence")
	if parsed.size() != 2:
		return

	var slot1 := _named_record(parsed, "enemy_position", 1)
	var slot2 := _named_record(parsed, "enemy_position", 2)
	_check(slot1.size() == 2 and slot1.has("enemy_position") and slot1.has("pattern"),
		"slot 1 carries only enemy_position and pattern")
	_check(slot2.size() == 2 and slot2.has("enemy_position") and slot2.has("pattern"),
		"slot 2 carries only enemy_position and pattern")

	var slot1_pattern: Array = slot1.get("pattern", [])
	var slot2_pattern: Array = slot2.get("pattern", [])
	_check(slot1_pattern.size() == 4, "slot 1 has an independent four-beat cycle")
	_check(slot2_pattern.size() == 4, "slot 2 has an independent four-beat cycle")
	_check(slot1_pattern[0] == {"type": "attack", "amount": 1, "target_position": 1},
		"slot 1 beat 1 is Attack 1 at Warden's position 1")
	_check(slot1_pattern[1] == {"type": "attack", "amount": 1, "target_position": 2},
		"slot 1 beat 2 is Attack 1 at Seamstress's position 2")
	_check(slot1_pattern[2] == {"type": "block", "amount": 1},
		"slot 1 beat 3 is an untargeted Block 1")
	_check(slot1_pattern[3] == {"type": "attack", "amount": 1, "target_position": 3},
		"slot 1 beat 4 is Attack 1 at Tinker's position 3")
	_check(slot2_pattern[0] == {"type": "attack", "amount": 1, "target_position": 3},
		"slot 2 beat 1 is Attack 1 at Tinker's position 3")
	_check(slot2_pattern[1] == {"type": "block", "amount": 1},
		"slot 2 beat 2 is an untargeted Block 1")
	_check(slot2_pattern[2] == {"type": "attack", "amount": 1, "target_position": 2},
		"slot 2 beat 3 is Attack 1 at Seamstress's position 2")
	_check(slot2_pattern[3] == {"type": "attack", "amount": 1, "target_position": 1},
		"slot 2 beat 4 is Attack 1 at Warden's position 1")

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
		text.replace("\"target_position\": 1", "\"target_position\": 4"),
		text.replace("\"amount\": 1", "\"amount\": 1.5"),
		text.replace("{\"type\": \"block\", \"amount\": 1}",
			"{\"type\": \"block\", \"amount\": 1, \"extra\": 2}"),
		text.replace("\"enemy_position\": 2", "\"enemy_position\": 1"),
		text.replace("\"enemy_position\": 1", "\"enemy_position\": 0"),
	]
	for i in range(malformed_texts.size()):
		_check(RunFightEncounterSelection._parse_schedule_text(malformed_texts[i]).is_empty(),
			"malformed variant %d of the real text is rejected before selection" % i)

	# Rejecting malformed copies must not spend randomness or touch live services.
	seed(GLOBAL_SEED)
	var malformed_rng_expected := randi()
	seed(GLOBAL_SEED)
	for i in range(malformed_texts.size()):
		RunFightEncounterSelection._parse_schedule_text(malformed_texts[i])
	var malformed_rng_after := randi()
	_check(malformed_rng_after == malformed_rng_expected,
		"malformed schedule validation leaves the Godot global RNG undrawn")

	# AC1: the real starter enemy records, in slot order, back this schedule.
	var enemies := _authored_enemies()
	if not enemies.is_valid():
		return
	_check(enemies.get_enemies().size() == 2,
		"slot 1 and slot 2 are the only occupied slots for this encounter")
	var ragling := enemies.get_enemy(1)
	var guard := enemies.get_enemy(2)
	_check(ragling.get("id") == "ragling" and ragling.get("name") == "Ragling"
		and ragling.get("hp") == 12 and ragling.get("max_hp") == 12,
		"slot 1 contains the 12-HP Ragling")
	_check(guard.get("id") == "ragling_guard" and guard.get("name") == "Guard Ragling"
		and guard.get("hp") == 12 and guard.get("max_hp") == 12,
		"slot 2 contains the 12-HP Guard Ragling")


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
	# Four authored beats plus the first repeated beat prove the wraparound.
	for beat in range(5):
		var announced := intents.get_intents()
		timeline.append(announced)
		_check(announced == _expected_beat(beat),
			"beat %d announces the exact full authored actions for both sources" % beat)
		_check(_positions_of(announced) == [1, 2],
			"beat %d announces sources in ascending enemy_position order" % beat)
		_check(announced.size() == 2, "beat %d announces one action per source" % beat)
		_check(intents.get_intents() == announced,
			"beat %d repeated read does not advance the schedule" % beat)
		if beat < 4:
			_check(intents.advance_turn(), "beat %d advances both source patterns" % beat)
	var global_after_intents := randi()
	_check(global_after_intents == global_expected_intents,
		"the full intent cycle leaves the Godot global RNG undrawn")

	_check(timeline.size() == 5, "the timeline covers four beats plus the wrap")
	_check(timeline[4] == timeline[0],
		"beat 5 wraps exactly back to beat 1 by modulo-4 wrap")
	_check(timeline[0] == [
		{"type": "attack", "amount": 1, "target_position": 1, "enemy_position": 1},
		{"type": "attack", "amount": 1, "target_position": 3, "enemy_position": 2}],
		"beat 1 is the front-and-back opening pursuit")
	_check(timeline[1] == [
		{"type": "attack", "amount": 1, "target_position": 2, "enemy_position": 1},
		{"type": "block", "amount": 1, "enemy_position": 2}],
		"beat 2 keeps slot 1 on the middle while slot 2 guards")
	_check(timeline[2] == [
		{"type": "block", "amount": 1, "enemy_position": 1},
		{"type": "attack", "amount": 1, "target_position": 2, "enemy_position": 2}],
		"beat 3 swaps guard and middle pressure between the sources")
	_check(timeline[3] == [
		{"type": "attack", "amount": 1, "target_position": 3, "enemy_position": 1},
		{"type": "attack", "amount": 1, "target_position": 1, "enemy_position": 2}],
		"beat 4 closes on the back and front heroes")

	# A completely fresh instance replays the entire required timeline.
	var replay := CombatEnemyIntents.new(parsed)
	_check(replay.is_valid(), "a fresh scheduler is valid")
	for beat in range(5):
		_check(replay.get_intents() == timeline[beat],
			"fresh scheduler replays beat %d exactly" % beat)
		if beat < 4:
			_check(replay.advance_turn(), "fresh scheduler advances beat %d" % beat)

	# Mutating an already returned announcement cannot alter later reads.
	timeline[1][0]["amount"] = 900
	timeline[1][0]["target_position"] = 3
	timeline[1][1]["enemy_position"] = 3
	timeline[1].append({"type": "block", "amount": 9, "enemy_position": 3})
	_check(intents.get_intents() == timeline[4],
		"mutating an earlier returned announcement leaves the current read intact")
	_check(intents.get_intents() == _expected_beat(4),
		"the current announcement still matches the authored wrap beat")
	_check(replay.get_intents() == _expected_beat(4),
		"the replayed scheduler is also unaffected by that mutation")

	# The service owns a deep copy of the supplied definitions.
	caller_owned[0]["pattern"][0]["amount"] = 42
	caller_owned[1]["pattern"].clear()
	_check(intents.is_valid() and intents.get_intents() == _expected_beat(4),
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


func _apply_expected_state(party: CombatParty, enemies: CombatEnemies, beat: int) -> void:
	var expected := _expected_state(beat)
	_check(expected.size() == 8, "precondition: beat %d has a complete expected state" % beat)
	if expected.size() != 8:
		return
	var warden := party.get_hero(1)
	var seamstress := party.get_hero(2)
	var tinker := party.get_hero(3)
	var ragling := enemies.get_enemy(1)
	var guard := enemies.get_enemy(2)
	_check(warden.get("hp") == expected[0] and warden.get("block") == expected[1],
		"beat %d leaves Warden at %d HP and %d Block"
			% [beat + 1, expected[0], expected[1]])
	_check(seamstress.get("hp") == expected[2] and seamstress.get("block") == 0,
		"beat %d leaves Seamstress at %d HP and no Block"
			% [beat + 1, expected[2]])
	_check(tinker.get("hp") == expected[3] and tinker.get("block") == 0,
		"beat %d leaves Tinker at %d HP and no Block" % [beat + 1, expected[3]])
	_check(ragling.get("hp") == expected[4] and ragling.get("block") == expected[5],
		"beat %d leaves Ragling at %d HP and %d Block"
			% [beat + 1, expected[4], expected[5]])
	_check(guard.get("hp") == expected[6] and guard.get("block") == expected[7],
		"beat %d leaves Guard Ragling at %d HP and %d Block"
			% [beat + 1, expected[6], expected[7]])


func _test_enemy_phases() -> void:
	var parsed := _parsed_definitions()
	_check(not parsed.is_empty(), "precondition: the real schedule is available for phases")
	if parsed.is_empty():
		return
	var party := _authored_party()
	var enemies := _authored_enemies()
	if not party.is_valid() or not enemies.is_valid():
		return
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("hp") == 40,
		"position 1 starts as Warden with 40 HP")
	_check(party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 30,
		"position 2 starts as Seamstress with 30 HP")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 26,
		"position 3 starts as Tinker with 26 HP")

	var scheduler := CombatEnemyIntents.new(parsed)
	_check(scheduler.is_valid(), "the authored schedule drives the real intent service")
	if not scheduler.is_valid():
		return
	var phase := CombatEnemyPhase.new()
	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "Warden receives the once-per-combat opening Block")
	_check(party.get_hero(1).get("block") == 6, "Warden opens with 6 Block")
	_check(not opening.apply(), "Warden's opening Block cannot be granted twice")
	_check(party.get_hero(1).get("block") == 6,
		"a repeated opening Block attempt adds nothing")

	for beat in range(4):
		var announced := scheduler.get_intents()
		_check(announced == _expected_beat(beat),
			"phase beat %d uses the exact authored announcements" % (beat + 1))
		var result := phase.execute_phase(party, enemies, announced)
		_check(result == {"ok": true, "events": _expected_events(beat)},
			"phase beat %d resolves both sources in slot order" % (beat + 1))
		_apply_expected_state(party, enemies, beat)
		if beat < 3:
			_check(scheduler.advance_turn(),
				"the caller advances the scheduler after beat %d" % (beat + 1))

	# AC3: four isolated intent phases, without a player turn or Block reset.
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 4,
		"after four beats Warden ends at 40 HP and 4 remaining Block")
	_check(party.get_hero(2).get("hp") == 28,
		"after four beats Seamstress ends at 28 HP")
	_check(party.get_hero(3).get("hp") == 24,
		"after four beats Tinker ends at 24 HP")
	_check(enemies.get_enemy(1).get("hp") == 12 and enemies.get_enemy(1).get("block") == 1,
		"after four beats Ragling ends at 12 HP and 1 Block")
	_check(enemies.get_enemy(2).get("hp") == 12 and enemies.get_enemy(2).get("block") == 1,
		"after four beats Guard Ragling ends at 12 HP and 1 Block")
	_check(not party.is_downed(1) and not party.is_downed(2) and not party.is_downed(3),
		"no hero was downed by the authored four-beat pursuit")

	# A fresh fixture replays the identical four-beat state transition.
	var replay_party := _authored_party()
	var replay_enemies := _authored_enemies()
	var replay_scheduler := CombatEnemyIntents.new(parsed)
	var replay_phase := CombatEnemyPhase.new()
	_check(CombatStartingBlock.new(replay_party).apply(),
		"the replay fixture also receives Warden's opening Block")
	for beat in range(4):
		var announced := replay_scheduler.get_intents()
		_check(announced == _expected_beat(beat),
			"replay beat %d announces the same authored actions" % (beat + 1))
		var result := replay_phase.execute_phase(replay_party, replay_enemies, announced)
		_check(result == {"ok": true, "events": _expected_events(beat)},
			"replay beat %d resolves identical events" % (beat + 1))
		_apply_expected_state(replay_party, replay_enemies, beat)
		if beat < 3:
			replay_scheduler.advance_turn()
	_check(replay_party.get_heroes() == party.get_heroes()
		and replay_enemies.get_enemies() == enemies.get_enemies(),
		"a fresh replay ends in the identical party and enemy state")


func _test_slain_source_semantics() -> void:
	var parsed := _parsed_definitions()
	_check(not parsed.is_empty(), "precondition: the real schedule backs the slain-source checks")
	if parsed.is_empty():
		return
	var phase := CombatEnemyPhase.new()

	# Slain slot 1: its announced attack is skipped, the living slot 2 attack
	# still resolves, and the dead record keeps its original slot.
	var party := _authored_party()
	var enemies := _authored_enemies()
	if not party.is_valid() or not enemies.is_valid():
		return
	_check(CombatStartingBlock.new(party).apply(),
		"slain-source fixture applies Warden's opening Block")
	_check(enemies.apply_damage(1, 12) and enemies.is_slain(1) and not enemies.is_slain(2),
		"precondition: slot 1 is slain while slot 2 lives")
	var dead_before := enemies.get_enemy(1)
	var first := CombatEnemyIntents.new(parsed).get_intents()
	var result := phase.execute_phase(party, enemies, first)
	_check(result == {"ok": true, "events": [
		_attack_event(1, 1, false), _attack_event(2, 3, true)]},
		"beat 1 skips the slain slot 1 and resolves the living slot 2 attack")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6,
		"the slain slot 1 attack cannot touch Warden's HP or Block")
	_check(party.get_hero(3).get("hp") == 25,
		"the living slot 2 attack still costs Tinker 1 HP")
	_check(enemies.get_enemy(1) == dead_before and enemies.get_enemies().size() == 2,
		"the slain enemy stays present in slot 1 with unchanged stats")
	_check(enemies.get_enemy(2).get("hp") == 12 and enemies.get_enemy(2).get("block") == 0,
		"the living slot 2 enemy is untouched by slot 1's death")

	# Slain slot 2: its announced beat-4 attack is skipped while the living
	# slot 1 backline attack still resolves.
	party = _authored_party()
	enemies = _authored_enemies()
	if not party.is_valid() or not enemies.is_valid():
		return
	_check(CombatStartingBlock.new(party).apply(),
		"second slain-source fixture applies Warden's opening Block")
	_check(enemies.apply_damage(2, 12) and enemies.is_slain(2) and not enemies.is_slain(1),
		"precondition: slot 2 is slain while slot 1 lives")
	var scheduler := CombatEnemyIntents.new(parsed)
	for beat in range(3):
		_check(scheduler.advance_turn(), "advance to the beat-4 fixture at step %d" % beat)
	var fourth := scheduler.get_intents()
	_check(fourth == _expected_beat(3),
		"the slain-slot-2 fixture announces the exact authored beat 4")
	result = phase.execute_phase(party, enemies, fourth)
	_check(result == {"ok": true, "events": [
		_attack_event(1, 3, true), _attack_event(2, 1, false)]},
		"beat 4 resolves the living slot 1 attack and skips the slain slot 2")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6,
		"the slain slot 2 attack cannot touch Warden's HP or Block")
	_check(party.get_hero(3).get("hp") == 25,
		"the living slot 1 attack still costs Tinker 1 HP")
	_check(enemies.get_enemy(2).get("hp") == 0 and enemies.get_enemies().size() == 2,
		"the slain enemy stays present in slot 2 and cannot act")
	_check(enemies.get_enemy(1).get("hp") == 12 and enemies.get_enemy(1).get("block") == 0,
		"slot 1 is still the original 12-HP Ragling")


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
	_check(ids == [STARTER_ID, ENCOUNTER_ID],
		"the explicit pool holds exactly whipstitch_pursuit and starter_attacks")
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
		"the real selector accepts a pool containing whipstitch_pursuit")
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
	_check(state_before != rng.state,
		"the successful selection genuinely consumed its one draw")

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
	# returned definitions feed the real intent scheduler.
	var seen: Array = []
	var pursuit_answer: Dictionary = {}
	for attempt in range(16):
		var attempt_seed := SEED_VALUE + 19 * attempt
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
		if attempt_expected == ENCOUNTER_ID and pursuit_answer.is_empty():
			pursuit_answer = attempt_answer
		if seen.size() == 2:
			break
	_check(seen.has(ENCOUNTER_ID) and seen.has(STARTER_ID),
		"the explicit pool genuinely returns both authored candidates across seeds")
	_check(seen.size() == 2,
		"the two-candidate pool never returns anything outside it")
	_check(not pursuit_answer.is_empty(),
		"the real selector actually returned a whipstitch_pursuit schedule")
	if pursuit_answer.is_empty():
		return
	var picked_intents := CombatEnemyIntents.new(pursuit_answer.get("definitions", []))
	_check(picked_intents.is_valid(),
		"the selected whipstitch definitions instantiate a real valid scheduler")
	for beat in range(5):
		_check(picked_intents.get_intents() == _expected_beat(beat),
			"selected whipstitch definitions announce the authored beat %d" % beat)
		if beat < 4:
			_check(picked_intents.advance_turn(),
				"selected whipstitch scheduler advances beat %d" % beat)


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
			"missing_companion": "res://data/encounters/no_such_whipstitch.json"}},
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
		{"label": "empty pool", "pool": {}},
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

	# An invalid map or RNG is also rejected without spending anything.
	_check(picker.select_current_fight(null, rng, _pool()) == {"success": false},
		"a null map is rejected fail-closed")
	_check(picker.select_current_fight(map, null, _pool()) == {"success": false},
		"a null run RNG is rejected fail-closed")
	_check(_snapshot(map, rng, picker) == chosen_before,
		"null map and RNG rejection changes no run RNG, binding or route")
	_check(picker._bound_map == null and picker._selected.is_empty(),
		"null map and RNG rejection binds and caches nothing")

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

	# That cached answer still feeds an actual intent service.
	var cached_intents := CombatEnemyIntents.new(retry.get("definitions", []))
	_check(cached_intents.is_valid(),
		"the cached selected definitions instantiate a real valid scheduler")


func _test_named_previous_schedules() -> void:
	# Presence, parseability and the complete ordered action definitions of the
	# two named earlier encounters only: no global encounter total and no full
	# ordered catalog list are asserted, so parallel additions stay safe.
	var schedules := {
		STARTER_ID: {"path": STARTER_PATH, "expected": _starter_schedule()},
		GUARD_ID: {"path": GUARD_PATH, "expected": _guard_schedule()},
	}
	for id in schedules:
		var entry: Dictionary = schedules[id]
		var path: String = entry["path"]
		var text := _load_text(path)
		if text.is_empty():
			continue
		var parsed := RunFightEncounterSelection._parse_schedule_text(text)
		_check(not parsed.is_empty(), id + ": named previous schedule still parses")
		_check(parsed == entry["expected"],
			id + ": named previous schedule keeps its complete authored actions")
		_check(CombatEnemyIntents.new(parsed).is_valid(),
			id + ": named previous schedule still passes the intent validator")
