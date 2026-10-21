extends SceneTree
## M04 standalone authored content: the Buttonthread Weakflip Fight schedule.
##
## Two existing M04 run-enemy sources (Button Guard in slot 1, Seam Ripper in
## slot 2) share one three-beat cycle: the front source weakens the front
## hero while the rear source shoves the middle hero forward, then the front
## source builds Block while the rear source attacks the middle hero, then the
## front source attacks the front hero while the rear source exposes the rear
## hero.
##
## The schedule is read with the REAL Fight parser
## (RunFightEncounterSelection._parse_schedule_text), the same entry point the
## run map uses, so the standalone file is proved to be accepted by the live
## Fight contract instead of by a test-private reader. The party and the enemy
## roster are built from the authored hero and enemy JSON, so a shipped
## definition that drifts breaks this test.
##
## This lane owns the authored data and its regression only. Registering the
## encounter in the shared Fight pool / run map and the live battle is later
## work and is deliberately not claimed here.

const ENCOUNTER_PATH := "res://data/encounters/buttonthread_weakflip.json"
const ENCOUNTER_ID := "buttonthread_weakflip"
const ENEMIES_PATH := "res://data/enemies/run_enemies.json"
const HEROES_PATH := "res://data/heroes/starter_party.json"
const HOLDOUT_PATH := "res://data/encounters/buttonhole_holdout.json"
const HOLDOUT_ID := "buttonhole_holdout"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_ac1_parse_and_intents()
	_test_ac2_beat_1_weak_and_shove()
	_test_ac3_full_cycle_and_replay()
	_test_ac4_roster_mapping_and_holdout()
	if failures.is_empty():
		print("buttonthread_weakflip_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("buttonthread_weakflip_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


## The authored schedule is read with the REAL Fight parser, the same
## RunFightEncounterSelection._parse_schedule_text entry point the run map
## uses. An empty result means the real parser refused the document.
func _parse_with_real_parser(path: String) -> Array:
	return RunFightEncounterSelection._parse_schedule_text(_load_text(path))


## The unique source at one enemy position. A duplicated position is a
## failure, so a first-match lookup can never hide it.
func _source_at(definitions: Array, position: int, label: String) -> Dictionary:
	var matches: Array = []
	for definition in definitions:
		if definition is Dictionary and definition.get("enemy_position") == position:
			matches.append(definition)
	_check(matches.size() == 1,
		label + ": the schedule holds exactly one source at enemy_position %d" % position)
	return matches[0].duplicate(true) if matches.size() == 1 else {}


## A compact, comparable view of one hero's live state.
func _hero_state(heroes: Array, position: int) -> Dictionary:
	if position < 1 or position > heroes.size():
		return {}
	var hero: Dictionary = heroes[position - 1]
	return {
		"id": hero.get("id", ""),
		"position": hero.get("position", -1),
		"hp": hero.get("hp", -1),
		"max_hp": hero.get("max_hp", -1),
		"block": hero.get("block", -1),
		"statuses": hero.get("statuses", {}).duplicate(true),
	}


## A compact, comparable view of one enemy source's live state.
func _enemy_state(enemies: Array, position: int) -> Dictionary:
	if position < 1 or position > enemies.size():
		return {}
	var enemy: Dictionary = enemies[position - 1]
	return {
		"id": enemy.get("id", ""),
		"position": enemy.get("position", -1),
		"hp": enemy.get("hp", -1),
		"max_hp": enemy.get("max_hp", -1),
		"block": enemy.get("block", -1),
	}


## The authored records of a shared JSON catalog, read as they ship.
func _authored_records(path: String) -> Array:
	var parsed = JSON.parse_string(_load_text(path))
	return parsed if parsed is Array else []


## The unique authored record with one stable ID. A duplicated ID is a
## failure, so a first-match lookup can never hide it.
func _record_by_id(records: Array, id: String, label: String) -> Dictionary:
	var matches: Array = []
	for record in records:
		if record is Dictionary and record.get("id") == id:
			matches.append(record)
	_check(matches.size() == 1,
		label + ": the authored catalog holds exactly one record named " + id)
	return matches[0].duplicate(true) if matches.size() == 1 else {}


## The three-hero party, built from the authored hero JSON so a shipped
## definition that drifts breaks the fixture instead of hiding in it.
func _party_fixture(label: String) -> CombatParty:
	var authored := _authored_records(HEROES_PATH)
	var definitions: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		var record := _record_by_id(authored, id, label)
		_check(record.has("max_hp")
			and RunFightEncounterSelection._coerce_integral_field(record, "max_hp"),
			label + ": the authored hero " + id + " has an integral maximum HP")
		definitions.append({"id": record.get("id", id), "max_hp": record.get("max_hp", 0)})
	return CombatParty.new(definitions)


## The two-enemy roster, built from the authored enemy catalog so the
## shipped Button Guard and Seam Ripper definitions are the ones under test.
func _enemies_fixture(label: String) -> CombatEnemies:
	var authored := _authored_records(ENEMIES_PATH)
	var definitions: Array = []
	for id in ["button_guard", "seam_ripper"]:
		var record := _record_by_id(authored, id, label)
		_check(record.has("max_hp")
			and RunFightEncounterSelection._coerce_integral_field(record, "max_hp"),
			label + ": the authored enemy " + id + " has an integral maximum HP")
		definitions.append({"id": record.get("id", id), "max_hp": record.get("max_hp", 0)})
	return CombatEnemies.new(definitions)


## The authored schedule of this encounter, written out by hand rather than
## copied from the file under test.
func _expected_schedule() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "debuff", "amount": 1, "target_position": 1, "status": "weak"},
			{"type": "block", "amount": 3},
			{"type": "attack", "amount": 4, "target_position": 1}]},
		{"enemy_position": 2, "pattern": [
			{"type": "shove", "amount": 0, "target_position": 2, "direction": -1},
			{"type": "attack", "amount": 5, "target_position": 2},
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed"}]},
	]


## The exact full announcement of every beat, written out by hand.
func _expected_beats() -> Array:
	return [
		[{"enemy_position": 1, "type": "debuff", "amount": 1, "target_position": 1, "status": "weak"},
		 {"enemy_position": 2, "type": "shove", "amount": 0, "target_position": 2, "direction": -1}],
		[{"enemy_position": 1, "type": "block", "amount": 3},
		 {"enemy_position": 2, "type": "attack", "amount": 5, "target_position": 2}],
		[{"enemy_position": 1, "type": "attack", "amount": 4, "target_position": 1},
		 {"enemy_position": 2, "type": "debuff", "amount": 1, "target_position": 3, "status": "exposed"}],
	]


## The exact ordered phase events of every beat, written out by hand.
func _expected_events(beat: int) -> Array:
	return [
		[{"type": "debuff", "enemy_position": 1, "applied": true,
			"target_position": 1, "status": "weak"},
		 {"type": "shove", "enemy_position": 2, "applied": true,
			"target_position": 2, "direction": -1}],
		[{"type": "block", "enemy_position": 1, "applied": true},
		 {"type": "attack", "enemy_position": 2, "applied": true, "target_position": 2}],
		[{"type": "attack", "enemy_position": 1, "applied": true, "target_position": 1},
		 {"type": "debuff", "enemy_position": 2, "applied": true,
			"target_position": 3, "status": "exposed"}],
	][beat]


## The expected hero state after each beat, written out by hand.
func _expected_hero_states(beat: int) -> Array:
	return [
		[{"id": "seamstress", "position": 1, "hp": 30, "max_hp": 30, "block": 0, "statuses": {}},
		 {"id": "warden", "position": 2, "hp": 40, "max_hp": 40, "block": 0, "statuses": {"weak": 1}},
		 {"id": "tinker", "position": 3, "hp": 26, "max_hp": 26, "block": 0, "statuses": {}}],
		[{"id": "seamstress", "position": 1, "hp": 30, "max_hp": 30, "block": 0, "statuses": {}},
		 {"id": "warden", "position": 2, "hp": 35, "max_hp": 40, "block": 0, "statuses": {"weak": 1}},
		 {"id": "tinker", "position": 3, "hp": 26, "max_hp": 26, "block": 0, "statuses": {}}],
		[{"id": "seamstress", "position": 1, "hp": 26, "max_hp": 30, "block": 0, "statuses": {}},
		 {"id": "warden", "position": 2, "hp": 35, "max_hp": 40, "block": 0, "statuses": {"weak": 1}},
		 {"id": "tinker", "position": 3, "hp": 26, "max_hp": 26, "block": 0, "statuses": {"exposed": 1}}],
	][beat]


## The expected enemy state after each beat, written out by hand.
func _expected_enemy_states(beat: int) -> Array:
	return [
		[{"id": "button_guard", "position": 1, "hp": 16, "max_hp": 16, "block": 0},
		 {"id": "seam_ripper", "position": 2, "hp": 18, "max_hp": 18, "block": 0}],
		[{"id": "button_guard", "position": 1, "hp": 16, "max_hp": 16, "block": 3},
		 {"id": "seam_ripper", "position": 2, "hp": 18, "max_hp": 18, "block": 0}],
		[{"id": "button_guard", "position": 1, "hp": 16, "max_hp": 16, "block": 3},
		 {"id": "seam_ripper", "position": 2, "hp": 18, "max_hp": 18, "block": 0}],
	][beat]


## The previously authored holdout schedule, written out by hand. It is
## inspected by its named path; no pool size and no catalog total is claimed.
func _expected_holdout_sources() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "block", "amount": 1},
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 3}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "attack", "amount": 1, "target_position": 3}]},
	]


## AC1: the REAL Fight parser accepts the standalone schedule, which holds
## exactly the two prescribed sources at enemy positions 1 and 2, each with
## the prescribed three-beat cycle.
func _test_ac1_parse_and_intents() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH),
		"AC1: the authored encounter file exists")
	var definitions := _parse_with_real_parser(ENCOUNTER_PATH)
	_check(not definitions.is_empty(),
		"AC1: the REAL Fight parser accepts the authored schedule")
	if definitions.is_empty():
		return
	_check(definitions.size() == 2,
		"AC1: the parsed schedule holds exactly two source records")
	var expected := _expected_schedule()
	_check(_source_at(definitions, 1, "AC1") == expected[0],
		"AC1: source 1 is the authored front three-beat pattern")
	_check(_source_at(definitions, 2, "AC1") == expected[1],
		"AC1: source 2 is the authored rear three-beat pattern")
	_check(CombatEnemyIntents.new(definitions).is_valid(),
		"AC1: the real intent validator accepts the parsed schedule")

	var scheduler := CombatEnemyIntents.new(definitions)
	_check(scheduler.is_valid(), "AC1: the parsed schedule instantiates a scheduler")
	var beats := _expected_beats()
	for beat in range(3):
		var announced := scheduler.get_intents()
		_check(announced == beats[beat],
			"AC1: beat %d announces the exact authored actions" % beat)
		_check(announced.size() == 2,
			"AC1: beat %d announces one action per source" % beat)
		_check(announced[0]["enemy_position"] == 1 and announced[1]["enemy_position"] == 2,
			"AC1: beat %d announces source slot 1 before source slot 2" % beat)
		_check(scheduler.advance_turn(),
			"AC1: beat %d advances the schedule exactly one step" % beat)
	_check(scheduler.get_intents() == beats[0],
		"AC1: the three-beat schedule wraps back to beat 1")

	# The real parser is fail-closed: a fractional amount, an out of range
	# hero target and a duplicated source position are all refused, so a
	# truncation can never make invalid authored data pass.
	var fractional := definitions.duplicate(true)
	fractional[0]["pattern"][0]["amount"] = 1.5
	_check(RunFightEncounterSelection._parse_schedule_text(
		JSON.stringify(fractional)).is_empty(),
		"AC1: the REAL Fight parser refuses a fractional amount")
	var bad_target := definitions.duplicate(true)
	bad_target[1]["pattern"][1]["target_position"] = 4
	_check(RunFightEncounterSelection._parse_schedule_text(
		JSON.stringify(bad_target)).is_empty(),
		"AC1: the REAL Fight parser refuses an out of range hero target")
	var duplicate_source := definitions.duplicate(true)
	duplicate_source[1]["enemy_position"] = 1
	_check(RunFightEncounterSelection._parse_schedule_text(
		JSON.stringify(duplicate_source)).is_empty(),
		"AC1: the REAL Fight parser refuses a duplicated source position")
	# An integral float is accepted and coerced to an int, never truncated.
	var whole_float := definitions.duplicate(true)
	whole_float[0]["pattern"][0]["amount"] = 1.0
	var coerced := RunFightEncounterSelection._parse_schedule_text(
		JSON.stringify(whole_float))
	_check(coerced.size() == 2
		and coerced[0]["pattern"][0]["amount"] == 1
		and coerced[0]["pattern"][0]["amount"] is int,
		"AC1: the REAL Fight parser coerces an integral float amount to an int")


## AC2: beat 1 applies Weak 1 to the front Warden BEFORE the rear source
## shoves hero position 2 toward 1, so the Weak follows the Warden to the
## middle slot.
func _test_ac2_beat_1_weak_and_shove() -> void:
	var definitions := _parse_with_real_parser(ENCOUNTER_PATH)
	_check(not definitions.is_empty(),
		"AC2: the REAL Fight parser accepts the authored schedule")
	if definitions.is_empty():
		return
	var party := _party_fixture("AC2")
	var enemies := _enemies_fixture("AC2")
	_check(party.is_valid() and enemies.is_valid(),
		"AC2: the three-hero party and two-enemy roster are valid")
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("max_hp") == 40,
		"AC2: the Warden starts alive in slot 1 with 40 maximum HP")
	_check(party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 30
		and party.get_hero(2).get("max_hp") == 30,
		"AC2: the Seamstress starts alive in slot 2 with 30 maximum HP")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("max_hp") == 26,
		"AC2: the Tinker starts alive in slot 3 with 26 maximum HP")
	_check(enemies.get_enemy(1).get("id") == "button_guard"
		and enemies.get_enemy(1).get("hp") == 16
		and enemies.get_enemy(1).get("max_hp") == 16,
		"AC2: the Button Guard starts alive in slot 1 with 16 maximum HP")
	_check(enemies.get_enemy(2).get("id") == "seam_ripper"
		and enemies.get_enemy(2).get("hp") == 18
		and enemies.get_enemy(2).get("max_hp") == 18,
		"AC2: the Seam Ripper starts alive in slot 2 with 18 maximum HP")

	var scheduler := CombatEnemyIntents.new(definitions)
	var phase := CombatEnemyPhase.new()
	var intents := scheduler.get_intents()
	_check(intents == _expected_beats()[0],
		"AC2: beat 1 announces Weak 1 on hero 1 and the shove of hero 2 toward 1")

	var result := phase.execute_phase(party, enemies, intents)
	_check(result.get("ok", false) == true, "AC2: the beat 1 phase succeeds")
	_check(result.get("events", []) == _expected_events(0),
		"AC2: beat 1 records the exact ordered source, target and applied events")

	var heroes_after := party.get_heroes()
	var enemies_after := enemies.get_enemies()
	_check(_hero_state(heroes_after, 1) == _expected_hero_states(0)[0],
		"AC2: after the shove the front slot holds the Seamstress at 30 HP")
	_check(_hero_state(heroes_after, 2) == _expected_hero_states(0)[1],
		"AC2: after the shove the middle slot holds the Warden carrying Weak 1")
	_check(_hero_state(heroes_after, 3) == _expected_hero_states(0)[2],
		"AC2: after the shove the rear slot still holds the Tinker")
	_check(_enemy_state(enemies_after, 1) == _expected_enemy_states(0)[0]
		and _enemy_state(enemies_after, 2) == _expected_enemy_states(0)[1],
		"AC2: beat 1 leaves both enemy sources at full HP and without Block")


## Runs the three authored beats against a fresh fixture and returns the
## whole observable trace, so two independent runs can be compared in full.
func _run_cycle(label: String) -> Array:
	var definitions := _parse_with_real_parser(ENCOUNTER_PATH)
	var party := _party_fixture(label)
	var enemies := _enemies_fixture(label)
	_check(not definitions.is_empty(),
		label + ": the REAL Fight parser accepts the authored schedule")
	if definitions.is_empty():
		return []
	var scheduler := CombatEnemyIntents.new(definitions)
	_check(scheduler.is_valid(),
		label + ": the parsed schedule instantiates a scheduler")
	if not scheduler.is_valid():
		return []
	var phase := CombatEnemyPhase.new()
	var beats := _expected_beats()
	var trace: Array = []
	for beat in range(3):
		var intents := scheduler.get_intents()
		var result := phase.execute_phase(party, enemies, intents)
		_check(result.get("ok", false) == true,
			label + ": beat " + str(beat) + " succeeds")
		trace.append({
			"intents": intents.duplicate(true),
			"events": result.get("events", []).duplicate(true),
			"heroes": party.get_heroes(),
			"enemies": enemies.get_enemies(),
		})
		_check(scheduler.advance_turn(),
			label + ": beat " + str(beat) + " advances the schedule once")
	_check(scheduler.get_intents() == beats[0],
		label + ": the schedule wraps back to beat 1 after the third beat")
	return trace


## AC3: three real CombatEnemyPhase calls produce the authored events and
## the authored hero and enemy state, and a fresh fixture repeats the whole
## trace exactly.
func _test_ac3_full_cycle_and_replay() -> void:
	var first := _run_cycle("AC3 first")
	var replay := _run_cycle("AC3 replay")
	_check(first.size() == 3 and replay.size() == 3,
		"AC3: both runs recorded three complete beats")
	if first.size() != 3 or replay.size() != 3:
		return
	_check(first == replay,
		"AC3: the fresh replay repeats the first run's events and state exactly")

	for beat in range(3):
		var entry: Dictionary = first[beat]
		_check(entry["intents"] == _expected_beats()[beat],
			"AC3: beat %d announces the exact authored actions" % beat)
		_check(entry["events"] == _expected_events(beat),
			"AC3: beat %d records the exact ordered source, target and applied events"
			% beat)
		var heroes: Array = entry["heroes"]
		var expected_heroes := _expected_hero_states(beat)
		_check(_hero_state(heroes, 1) == expected_heroes[0],
			"AC3: beat %d leaves the front hero at its expected identity, HP, Block and status"
			% beat)
		_check(_hero_state(heroes, 2) == expected_heroes[1],
			"AC3: beat %d leaves the middle hero at its expected identity, HP, Block and status"
			% beat)
		_check(_hero_state(heroes, 3) == expected_heroes[2],
			"AC3: beat %d leaves the rear hero at its expected identity, HP, Block and status"
			% beat)
		var enemies: Array = entry["enemies"]
		var expected_enemies := _expected_enemy_states(beat)
		_check(_enemy_state(enemies, 1) == expected_enemies[0],
			"AC3: beat %d leaves the front enemy source at its expected identity, HP and Block"
			% beat)
		_check(_enemy_state(enemies, 2) == expected_enemies[1],
			"AC3: beat %d leaves the rear enemy source at its expected identity, HP and Block"
			% beat)

	# Beat 2 in detail: the front source builds 3 Block while the rear source
	# attacks the current occupant of hero position 2 for a base 5.
	var beat_two: Dictionary = first[1]
	_check(beat_two["events"] == [
		{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 2}],
		"AC3: beat 2 records the applied Block of source 1 and the applied attack of source 2 on hero 2")
	var beat_two_heroes: Array = beat_two["heroes"]
	_check(_hero_state(beat_two_heroes, 2) == {
			"id": "warden", "position": 2, "hp": 35, "max_hp": 40, "block": 0,
			"statuses": {"weak": 1}},
		"AC3: beat 2 leaves the Warden at hero 2 with 35 HP, no Block and Weak 1")
	var beat_two_enemies: Array = beat_two["enemies"]
	_check(_enemy_state(beat_two_enemies, 1) == {
			"id": "button_guard", "position": 1, "hp": 16, "max_hp": 16, "block": 3},
		"AC3: beat 2 leaves the Button Guard with 3 Block")
	_check(_enemy_state(beat_two_enemies, 2) == {
			"id": "seam_ripper", "position": 2, "hp": 18, "max_hp": 18, "block": 0},
		"AC3: beat 2 leaves the Seam Ripper without Block")

	# Beat 3 in detail: the front source attacks the then-front hero for a
	# base 4 while the rear source exposes hero position 3.
	var beat_three: Dictionary = first[2]
	_check(beat_three["events"] == [
		{"type": "attack", "enemy_position": 1, "applied": true, "target_position": 1},
		{"type": "debuff", "enemy_position": 2, "applied": true,
			"target_position": 3, "status": "exposed"}],
		"AC3: beat 3 records the applied attack of source 1 on hero 1 and the applied Exposed of source 2 on hero 3")
	var beat_three_heroes: Array = beat_three["heroes"]
	_check(_hero_state(beat_three_heroes, 1) == {
			"id": "seamstress", "position": 1, "hp": 26, "max_hp": 30, "block": 0,
			"statuses": {}},
		"AC3: beat 3 leaves the front Seamstress at 26 HP without Block")
	_check(_hero_state(beat_three_heroes, 3) == {
			"id": "tinker", "position": 3, "hp": 26, "max_hp": 26, "block": 0,
			"statuses": {"exposed": 1}},
		"AC3: beat 3 leaves the rear Tinker with Exposed 1 and no Block")


## AC4: the standalone Fight assembles through RunTypedBattleRoster with a
## test-local encounter-id to roster mapping over the existing enemy catalog,
## and the previously authored holdout still parses with the real parser.
func _test_ac4_roster_mapping_and_holdout() -> void:
	# The baseline is inspected by its named path with the REAL parser; no
	# pool size and no catalog total is claimed.
	_check(FileAccess.file_exists(HOLDOUT_PATH),
		"AC4: the existing " + HOLDOUT_ID + " file exists")
	var holdout := _parse_with_real_parser(HOLDOUT_PATH)
	_check(not holdout.is_empty(),
		"AC4: the REAL Fight parser accepts the existing " + HOLDOUT_ID + " schedule")
	if not holdout.is_empty():
		_check(holdout.size() == 2,
			"AC4: the existing holdout still holds exactly two source records")
		var expected_holdout := _expected_holdout_sources()
		_check(_source_at(holdout, 1, "AC4") == expected_holdout[0],
			"AC4: the existing holdout source 1 keeps its exact authored pattern")
		_check(_source_at(holdout, 2, "AC4") == expected_holdout[1],
			"AC4: the existing holdout source 2 keeps its exact authored pattern")
		_check(CombatEnemyIntents.new(holdout).is_valid(),
			"AC4: the existing holdout still passes the real intent validator")
		var holdout_scheduler := CombatEnemyIntents.new(holdout)
		_check(holdout_scheduler.get_intents() == [
			{"enemy_position": 1, "type": "attack", "amount": 1, "target_position": 1},
			{"enemy_position": 2, "type": "attack", "amount": 1, "target_position": 2}],
			"AC4: the existing holdout still announces its first beat")

	# The new standalone Fight is assembled with a TEST-LOCAL roster mapping.
	# No shared Fight pool entry and no live route is claimed here.
	var definitions := _parse_with_real_parser(ENCOUNTER_PATH)
	_check(not definitions.is_empty(),
		"AC4: the REAL Fight parser accepts the new standalone schedule")
	if definitions.is_empty():
		return
	var typed_choice := {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": definitions,
	}
	var encounter_rosters := {
		ENCOUNTER_ID: ["button_guard", "seam_ripper"]
	}
	var result := RunTypedBattleRoster.new().assemble(
		typed_choice, encounter_rosters, [ENEMIES_PATH])
	_check(result.get("ok", false) == true,
		"AC4: the test-local roster mapping assembles the standalone Fight")
	_check(result.get("encounter_id") == ENCOUNTER_ID,
		"AC4: the assembled roster preserves the encounter id")
	_check(result.get("node_type") == "Fight",
		"AC4: the assembled roster preserves the Fight node type")
	var assembled_enemies: CombatEnemies = result.get("enemies", null)
	_check(assembled_enemies != null and assembled_enemies.is_valid(),
		"AC4: the assembled enemy roster is valid")
	var assembled: Array = []
	if assembled_enemies != null:
		assembled = assembled_enemies.get_enemies()
	_check(assembled.size() == 2,
		"AC4: the assembled roster holds exactly the two mapped sources")
	_check(assembled.size() == 2 and assembled[0].get("id") == "button_guard"
		and assembled[0].get("max_hp") == 16,
		"AC4: assembled source 1 is the authored Button Guard with 16 maximum HP")
	_check(assembled.size() == 2 and assembled[1].get("id") == "seam_ripper"
		and assembled[1].get("max_hp") == 18,
		"AC4: assembled source 2 is the authored Seam Ripper with 18 maximum HP")
	var preserved: Array = result.get("definitions", [])
	_check(preserved == definitions,
		"AC4: the real parser's definitions survive the roster assembly")
