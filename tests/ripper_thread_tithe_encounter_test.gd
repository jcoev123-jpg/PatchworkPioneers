extends SceneTree
## M04 standalone authored content: the Ripper Thread Tithe Fight schedule.
##
## Seam Ripper (front) and Fray Scavenger (rear) run four authored beats:
##   1. Ripper hits Tinker for 4, then Fray marks Seamstress with Bleed 2.
##   2. Ripper Weakens Tinker, then Fray's 4 is absorbed by Warden's opening
##      Block (6 -> 2; HP stays 40).
##   3. Ripper hits Seamstress for 3, then Fray hits Tinker for 5.
##   4. Ripper buffs himself for 3 Block, then Fray blocks himself for 2.
##
## The four enemy phases are isolated service calls: no player turn, no status
## tick and no turn reset runs between them, so the authored statuses persist
## exactly as staged. Registering this encounter in the published
## data/encounters/m03_typed_battle_pools.json Fight pool and wiring a live
## battle is a separate task and is deliberately not claimed here.

const ENCOUNTER_PATH := "res://data/encounters/ripper_thread_tithe.json"
const ENCOUNTER_ID := "ripper_thread_tithe"
const BUTTONHOLE_PATH := "res://data/encounters/buttonhole_holdout.json"
const HEROES_PATH := "res://data/heroes/starter_party.json"
const ENEMIES_PATH := "res://data/enemies/run_enemies.json"
const RUN_MAP_SEED := 4103
const ENEMY_IDS := ["seam_ripper", "fray_scavenger"]
const HERO_IDS := ["warden", "seamstress", "tinker"]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_authored_file()
	_test_previous_encounter()
	_test_enemy_phase()
	_test_typed_selection()
	_test_downed_target_rejection()
	if failures.is_empty():
		print("ripper_thread_tithe_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("ripper_thread_tithe_encounter_test: FAIL (", failures.size(), " failures)")
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


## The authored schedule, written out by hand rather than copied from the file.
func _expected_schedule() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 4, "target_position": 3},
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
			{"type": "attack", "amount": 3, "target_position": 2},
			{"type": "buff", "amount": 3}]},
		{"enemy_position": 2, "pattern": [
			{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed"},
			{"type": "attack", "amount": 4, "target_position": 1},
			{"type": "attack", "amount": 5, "target_position": 3},
			{"type": "block", "amount": 2}]},
	]


## The earlier M02 authored encounter, asserted independently of this file.
func _expected_buttonhole_schedule() -> Array:
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


## The exact full announcement of every beat, written out by hand, including
## the announcing source position. Beat 5 deliberately repeats beat 1's shapes.
func _expected_beats() -> Array:
	return [
		[
			{"type": "attack", "amount": 4, "target_position": 3, "enemy_position": 1},
			{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed",
				"enemy_position": 2}],
		[
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak",
				"enemy_position": 1},
			{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 2}],
		[
			{"type": "attack", "amount": 3, "target_position": 2, "enemy_position": 1},
			{"type": "attack", "amount": 5, "target_position": 3, "enemy_position": 2}],
		[
			{"type": "buff", "amount": 3, "enemy_position": 1},
			{"type": "block", "amount": 2, "enemy_position": 2}],
		[
			{"type": "attack", "amount": 4, "target_position": 3, "enemy_position": 1},
			{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed",
				"enemy_position": 2}],
	]


func _expected_events(beat: int) -> Array:
	var events: Array = []
	for intent in _expected_beats()[beat]:
		var event := {"type": intent["type"],
			"enemy_position": intent["enemy_position"], "applied": true}
		if intent["type"] == "attack" or intent["type"] == "debuff":
			event["target_position"] = intent["target_position"]
		if intent["type"] == "debuff":
			event["status"] = intent["status"]
		events.append(event)
	return events


func _source_at(definitions: Array, position: int) -> Dictionary:
	var matches: Array = []
	for definition in definitions:
		if definition is Dictionary and definition.get("enemy_position") == position:
			matches.append(definition)
	_check(matches.size() == 1,
		"schedule has exactly one source at enemy_position %d" % position)
	return matches[0].duplicate(true) if matches.size() == 1 else {}


func _record_by_id(records: Array, id: String) -> Dictionary:
	var matches: Array = []
	for record in records:
		if record is Dictionary and record.get("id") == id:
			matches.append(record)
	_check(matches.size() == 1, "catalog has exactly one record named " + id)
	return matches[0].duplicate(true) if matches.size() == 1 else {}


## Loads authored catalog records through the real production catalog parser,
## so both fixtures come from the shipped JSON rather than hand-written stats.
func _load_catalog(path: String) -> Array:
	_check(FileAccess.file_exists(path), "shipped catalog exists: " + path)
	var records: Array = RunTypedBattleRoster._parse_catalog_text(_read_text(path))
	_check(not records.is_empty(), "shipped catalog parses: " + path)
	return records


func _shipped_heroes() -> Array:
	var catalog := _load_catalog(HEROES_PATH)
	var ordered: Array = []
	for id in HERO_IDS:
		ordered.append(_record_by_id(catalog, id))
	return ordered


func _shipped_enemies() -> Array:
	var catalog := _load_catalog(ENEMIES_PATH)
	var ordered: Array = []
	for id in ENEMY_IDS:
		ordered.append(_record_by_id(catalog, id))
	return ordered


## AC1: the new file is a two-source array holding only enemy_position and
## pattern, with the exact four authored beats per source, and the production
## parser plus real CombatEnemyIntents accept it and wrap after four advances.
func _test_authored_file() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH),
		"AC1: the authored ripper_thread_tithe encounter exists")
	var text := _read_text(ENCOUNTER_PATH)
	_check(not text.is_empty(), "AC1: the authored file is readable")
	var definitions: Array = RunFightEncounterSelection._parse_schedule_text(text)
	_check(definitions.size() == 2,
		"AC1: the production parser accepts exactly two source records")
	if definitions.size() != 2:
		return

	var expected := _expected_schedule()
	_check(definitions[0].get("enemy_position") == 1
		and definitions[1].get("enemy_position") == 2,
		"AC1: the sources are enemy positions 1 then 2, in that order")
	var slot1 := _source_at(definitions, 1)
	var slot2 := _source_at(definitions, 2)
	_check(slot1 == expected[0], "AC1: source 1 is the exact authored four-beat pattern")
	_check(slot2 == expected[1], "AC1: source 2 is the exact authored four-beat pattern")
	_check(slot1.get("pattern") != slot2.get("pattern"),
		"AC1: the two sources carry distinct patterns")

	for source in [slot1, slot2]:
		_check(source.size() == 2 and source.has("enemy_position")
			and source.has("pattern"),
			"AC1: a source record carries only enemy_position and pattern")
		var pattern: Array = source.get("pattern", [])
		_check(pattern.size() == 4, "AC1: a source runs exactly four beats")
		for action in pattern:
			_check(action is Dictionary, "AC1: an authored action is a record")
			if not action is Dictionary:
				continue
			_check(action.get("amount") is int,
				"AC1: an authored amount is an int after the integral normalization")
			if action.get("type") == "attack":
				_check(action.size() == 3 and action.get("target_position") is int,
					"AC1: an attack carries exactly one integral hero target")
			elif action.get("type") == "debuff":
				_check(action.size() == 4 and action.get("target_position") is int
					and action.get("status") in ["bleed", "weak"],
					"AC1: a debuff names an integral hero target and a real status")
			else:
				_check(action.size() == 2 and action.get("type") in ["buff", "block"],
					"AC1: a self action is an untargeted buff or Block")

	# Every beat of every source, named explicitly.
	var pattern1: Array = slot1.get("pattern", [])
	var pattern2: Array = slot2.get("pattern", [])
	_check(pattern1.size() == 4
		and pattern1[0] == {"type": "attack", "amount": 4, "target_position": 3},
		"AC1: source 1 beat 1 attacks Tinker for 4")
	_check(pattern1.size() == 4
		and pattern1[1] == {"type": "debuff", "amount": 1, "target_position": 3,
			"status": "weak"},
		"AC1: source 1 beat 2 applies Weak 1 to Tinker")
	_check(pattern1.size() == 4
		and pattern1[2] == {"type": "attack", "amount": 3, "target_position": 2},
		"AC1: source 1 beat 3 attacks Seamstress for 3")
	_check(pattern1.size() == 4 and pattern1[3] == {"type": "buff", "amount": 3},
		"AC1: source 1 beat 4 buffs himself for 3 Block")
	_check(pattern2.size() == 4
		and pattern2[0] == {"type": "debuff", "amount": 2, "target_position": 2,
			"status": "bleed"},
		"AC1: source 2 beat 1 applies Bleed 2 to Seamstress")
	_check(pattern2.size() == 4
		and pattern2[1] == {"type": "attack", "amount": 4, "target_position": 1},
		"AC1: source 2 beat 2 attacks Warden for 4")
	_check(pattern2.size() == 4
		and pattern2[2] == {"type": "attack", "amount": 5, "target_position": 3},
		"AC1: source 2 beat 3 attacks Tinker for 5")
	_check(pattern2.size() == 4 and pattern2[3] == {"type": "block", "amount": 2},
		"AC1: source 2 beat 4 blocks himself for 2")

	var scheduler := CombatEnemyIntents.new(definitions)
	_check(scheduler.is_valid(), "AC1: the authored schedule passes the real intent validator")
	if not scheduler.is_valid():
		return
	var timeline: Array = []
	var beats := _expected_beats()
	for beat in range(5):
		var announced: Array = scheduler.get_intents()
		timeline.append(announced.duplicate(true))
		_check(announced == beats[beat],
			"AC1: beat %d announces the exact full authored actions with sources" % beat)
		_check(announced.size() == 2
			and announced[0].get("enemy_position") == 1
			and announced[1].get("enemy_position") == 2,
			"AC1: beat %d announces source 1 then source 2" % beat)
		if beat < 4:
			_check(scheduler.advance_turn(),
				"AC1: beat %d advances the schedule exactly one step" % beat)
	_check(timeline.size() == 5 and timeline[4] == timeline[0],
		"AC1: after four advances beat 5 announces exactly beat 1 again")

	# A fractional authored value cannot be truncated into a valid schedule.
	var fractional := _expected_schedule().duplicate(true)
	fractional[0]["pattern"][0]["amount"] = 4.5
	_check(RunFightEncounterSelection._parse_schedule_text(
		JSON.stringify(fractional)).is_empty(),
		"AC1: a fractional authored amount is refused before int coercion")
	var whole_float := _expected_schedule().duplicate(true)
	whole_float[0]["pattern"][0]["amount"] = 4.0
	_check(RunFightEncounterSelection._parse_schedule_text(
		JSON.stringify(whole_float)) == _expected_schedule(),
		"AC1: an integral JSON float normalizes back to the exact schedule")


## AC3: the named earlier encounter still parses and validates on its own.
func _test_previous_encounter() -> void:
	_check(FileAccess.file_exists(BUTTONHOLE_PATH),
		"AC3: the named earlier buttonhole_holdout encounter still exists")
	var parsed: Array = RunFightEncounterSelection._parse_schedule_text(
		_read_text(BUTTONHOLE_PATH))
	_check(parsed.size() == 2,
		"AC3: buttonhole_holdout parses into exactly its two sources")
	_check(parsed == _expected_buttonhole_schedule(),
		"AC3: buttonhole_holdout keeps its exact ordered authored actions")
	_check(CombatEnemyIntents.new(parsed).is_valid(),
		"AC3: buttonhole_holdout still passes the real intent validator")


func _expected_heroes(initial: Array, hp: Array, warden_block: int,
		seamstress_statuses: Variant, tinker_statuses: Variant) -> Array:
	var expected: Array = initial.duplicate(true)
	for index in range(3):
		expected[index]["hp"] = hp[index]
	expected[0]["block"] = warden_block
	if seamstress_statuses != null:
		expected[1]["statuses"] = seamstress_statuses
	if tinker_statuses != null:
		expected[2]["statuses"] = tinker_statuses
	return expected


func _expected_roster(initial: Array, first_block: int, second_block: int) -> Array:
	var expected: Array = initial.duplicate(true)
	expected[0]["block"] = first_block
	expected[1]["block"] = second_block
	return expected


func _has_exact_slots(records: Array, ids: Array) -> bool:
	if records.size() != ids.size():
		return false
	var seen_ids: Array = []
	for index in range(records.size()):
		var record: Dictionary = records[index]
		if record.get("id") != ids[index] or record.get("position") != index + 1:
			return false
		if record.get("id") in seen_ids:
			return false
		seen_ids.append(record.get("id"))
	return true


## AC2: four isolated real CombatEnemyPhase calls over shipped catalogs produce
## the exact authored HP, status and Block progression, with no player turn or
## status tick in between and with unchanged caller intents.
func _test_enemy_phase() -> void:
	var hero_records := _shipped_heroes()
	var enemy_records := _shipped_enemies()
	_check(hero_records.size() == 3 and enemy_records.size() == 2,
		"AC2: both shipped catalogs provide the required records")
	if hero_records.size() != 3 or enemy_records.size() != 2:
		return
	_check(hero_records[0].get("name") == "Warden"
		and hero_records[0].get("max_hp") == 40,
		"AC2: slot 1 is the shipped Warden with 40 maximum HP")
	_check(hero_records[1].get("name") == "Seamstress"
		and hero_records[1].get("max_hp") == 30,
		"AC2: slot 2 is the shipped Seamstress with 30 maximum HP")
	_check(hero_records[2].get("name") == "Tinker"
		and hero_records[2].get("max_hp") == 26,
		"AC2: slot 3 is the shipped Tinker with 26 maximum HP")
	_check(enemy_records[0].get("name") == "Seam Ripper"
		and enemy_records[0].get("max_hp") == 18,
		"AC2: the front source is the shipped Seam Ripper with 18 maximum HP")
	_check(enemy_records[1].get("name") == "Fray Scavenger"
		and enemy_records[1].get("max_hp") == 14,
		"AC2: the rear source is the shipped Fray Scavenger with 14 maximum HP")

	var party := CombatParty.new(hero_records)
	var enemies := CombatEnemies.new(enemy_records)
	_check(party.is_valid() and enemies.is_valid(),
		"AC2: the shipped catalogs build a valid party and two-enemy roster")
	if not (party.is_valid() and enemies.is_valid()):
		return
	_check(_has_exact_slots(party.get_heroes(), HERO_IDS),
		"AC2: the party holds the three unique shipped heroes in slots 1-3")
	_check(_has_exact_slots(enemies.get_enemies(), ENEMY_IDS),
		"AC2: the enemies hold the two unique shipped sources in slots 1-2")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(2).get("hp") == 30
		and party.get_hero(3).get("hp") == 26
		and party.get_hero(1).get("block") == 0
		and party.get_hero(2).get("block") == 0
		and party.get_hero(3).get("block") == 0,
		"AC2: the fresh party starts at 40/30/26 with zero Block")
	_check(party.get_hero(1).get("statuses", {}) == {}
		and party.get_hero(2).get("statuses", {}) == {}
		and party.get_hero(3).get("statuses", {}) == {},
		"AC2: the fresh party starts without statuses")
	_check(enemies.get_enemy(1).get("hp") == 18 and enemies.get_enemy(2).get("hp") == 14
		and enemies.get_enemy(1).get("block") == 0
		and enemies.get_enemy(2).get("block") == 0,
		"AC2: the fresh sources start at 18/14 HP with zero Block")

	_check(CombatStartingBlock.new(party).apply(),
		"AC2: the real starting-Block service grants Warden his opening Block")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6
		and party.get_hero(2).get("block") == 0
		and party.get_hero(3).get("block") == 0,
		"AC2: Warden holds exactly 6 opening Block and the others hold none")

	var definitions: Array = RunFightEncounterSelection._parse_schedule_text(
		_read_text(ENCOUNTER_PATH))
	var scheduler := CombatEnemyIntents.new(definitions)
	_check(scheduler.is_valid(),
		"AC2: the authored schedule loads into the real intent scheduler")
	if not scheduler.is_valid():
		return
	var phase := CombatEnemyPhase.new()
	var initial_heroes := party.get_heroes()
	var initial_roster := enemies.get_enemies()
	var hp_after: Array = [[40, 30, 22], [40, 30, 22], [40, 27, 17], [40, 27, 17]]
	var warden_block_after: Array = [6, 2, 2, 2]
	var seamstress_after: Array = [{"bleed": 2}, {"bleed": 2}, {"bleed": 2}, {"bleed": 2}]
	var tinker_after: Array = [null, {"weak": 1}, {"weak": 1}, {"weak": 1}]
	var enemy_block_after: Array = [[0, 0], [0, 0], [0, 0], [3, 2]]
	var beats := _expected_beats()
	for beat in range(4):
		var intents: Array = scheduler.get_intents()
		var untouched := intents.duplicate(true)
		_check(intents == beats[beat], "AC2: beat %d exact intents before the phase" % beat)
		var result: Dictionary = phase.execute_phase(party, enemies, intents)
		_check(result == {"ok": true, "events": _expected_events(beat)},
			"AC2: beat %d produces exactly the ordered two applied events" % beat)
		_check(intents == untouched and scheduler.get_intents() == beats[beat],
			"AC2: beat %d leaves caller intents and the scheduler untouched" % beat)
		var expected_heroes := _expected_heroes(initial_heroes, hp_after[beat],
			warden_block_after[beat], seamstress_after[beat], tinker_after[beat])
		var expected_roster := _expected_roster(initial_roster,
			enemy_block_after[beat][0], enemy_block_after[beat][1])
		_check(party.get_heroes() == expected_heroes,
			"AC2: beat %d leaves exactly the authored party HP, Block and statuses" % beat)
		_check(enemies.get_enemies() == expected_roster,
			"AC2: beat %d leaves exactly the authored enemy HP and Block" % beat)
		_check(scheduler.advance_turn(),
			"AC2: beat %d advances the schedule exactly once" % beat)
	_check(scheduler.get_intents() == beats[4],
		"AC2: after four phases the fifth announcement repeats beat 1")

	# The four beats are an isolated service sequence, so the staged statuses
	# and Warden's remaining Block are still present at the end.
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 2,
		"AC2: Warden ends at 40 HP with the two surviving points of Block")
	_check(party.get_hero(2).get("hp") == 27
		and party.get_hero(2).get("statuses") == {"bleed": 2},
		"AC2: Seamstress ends at 27 HP still holding Bleed 2")
	_check(party.get_hero(3).get("hp") == 17
		and party.get_hero(3).get("statuses") == {"weak": 1},
		"AC2: Tinker ends at 17 HP still holding Weak 1")
	_check(enemies.get_enemy(1).get("hp") == 18 and enemies.get_enemy(1).get("block") == 3
		and enemies.get_enemy(2).get("hp") == 14 and enemies.get_enemy(2).get("block") == 2,
		"AC2: Seam Ripper ends with 3 Block and Fray Scavenger with 2")


func _opening_fight(map: RunMap) -> String:
	for id in map.get_legal_choices():
		if map.get_node(id).get("type") == "Fight":
			return id
	return ""


## AC3: on a genuinely legal opening Fight from seed 4103, a test-local
## one-entry typed pool selects this encounter, the real roster service builds
## the ordered shipped sources, and a repeat selection is cached without RNG.
func _test_typed_selection() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = RUN_MAP_SEED
	var map := RunMap.new()
	_check(map.generate(rng),
		"AC3: RunMap.generate runs on the same seeded RNG that will select")
	if not map.is_generated():
		return
	var opening := _opening_fight(map)
	_check(not opening.is_empty() and map.get_legal_choices().has(opening),
		"AC3: seed 4103 really offers a legal opening Fight")
	if opening.is_empty():
		return
	_check(map.choose_node(opening),
		"AC3: the real map chooses that opening Fight")
	if map.get_current_node_id() != opening:
		return
	_check(map.get_current_node_id() == opening
		and map.get_node(opening).get("type") == "Fight",
		"AC3: the chosen CURRENT node is the opening Fight")

	var pools: Dictionary = {"Fight": {ENCOUNTER_ID: ENCOUNTER_PATH}}
	var oracle_rng := RandomNumberGenerator.new()
	oracle_rng.seed = RUN_MAP_SEED
	var oracle_map := RunMap.new()
	_check(oracle_map.generate(oracle_rng) and oracle_map.choose_node(opening),
		"AC3: a same-seed oracle map reaches the same opening Fight")
	var oracle_ids: Array = pools["Fight"].keys()
	oracle_ids.sort()
	var oracle_id: String = oracle_ids[oracle_rng.randi_range(0, oracle_ids.size() - 1)]

	var selector := RunFightEncounterSelection.new()
	var chosen: Dictionary = selector.select_current_battle(map, rng, pools)
	_check(chosen.get("success", false)
		and chosen.get("encounter_id") == ENCOUNTER_ID,
		"AC3: the real typed selection selects ripper_thread_tithe")
	_check(chosen.get("node_type") == "Fight",
		"AC3: the typed selection reports the real Fight node type")
	_check(chosen.get("definitions") == _expected_schedule(),
		"AC3: the selection returns the complete authored schedule")
	_check(oracle_id == ENCOUNTER_ID and rng.state == oracle_rng.state,
		"AC3: selection matches the same-seed single-draw oracle exactly")

	var cached_state := rng.state
	var reselected: Dictionary = selector.select_current_battle(map, rng, pools)
	_check(reselected == chosen,
		"AC3: a repeated selection returns the same cached choice")
	_check(rng.state == cached_state,
		"AC3: a repeated selection consumes no further run RNG")

	var selected := chosen.duplicate(true)
	chosen["definitions"][0]["pattern"][0]["amount"] = 900
	chosen["encounter_id"] = "mutated"
	var after_mutation: Dictionary = selector.select_current_battle(map, rng, pools)
	_check(after_mutation.get("encounter_id") == ENCOUNTER_ID
		and after_mutation.get("definitions") == _expected_schedule()
		and rng.state == cached_state,
		"AC3: a mutated caller copy cannot corrupt later cached selections")

	var assembled: Dictionary = RunTypedBattleRoster.new().assemble(selected,
		{ENCOUNTER_ID: ENEMY_IDS.duplicate()}, [ENEMIES_PATH])
	_check(assembled.get("ok", false),
		"AC3: the real typed roster service assembles this encounter")
	if not assembled.get("ok", false):
		return
	_check(assembled.get("encounter_id") == ENCOUNTER_ID
		and assembled.get("definitions") == _expected_schedule(),
		"AC3: assembly keeps the chosen ID and complete schedule")
	var enemy_model: CombatEnemies = assembled.get("enemies") as CombatEnemies
	_check(enemy_model != null, "AC3: assembly returns real CombatEnemies state")
	if enemy_model == null:
		return
	var roster: Array = enemy_model.get_enemies()
	_check(roster.size() == 2 and _has_exact_slots(roster, ENEMY_IDS),
		"AC3: the roster holds seam_ripper then fray_scavenger in slots 1-2")
	_check(roster[0].get("name") == "Seam Ripper" and roster[0].get("max_hp") == 18
		and roster[0].get("hp") == 18 and roster[0].get("block") == 0,
		"AC3: slot 1 is a fresh 18 HP Seam Ripper with no Block")
	_check(roster[1].get("name") == "Fray Scavenger" and roster[1].get("max_hp") == 14
		and roster[1].get("hp") == 14 and roster[1].get("block") == 0,
		"AC3: slot 2 is a fresh 14 HP Fray Scavenger with no Block")


## AC3 negative: with Seamstress already downed, Ripper's staged attack on
## Tinker is legal, but Fray's later Bleed on the downed Seamstress makes the
## whole real phase fail closed with both authoritative rosters unchanged.
func _test_downed_target_rejection() -> void:
	var hero_records := _shipped_heroes()
	var enemy_records := _shipped_enemies()
	if hero_records.size() != 3 or enemy_records.size() != 2:
		_check(false, "AC3 negative: shipped catalogs provide both fixtures")
		return
	var party := CombatParty.new(hero_records)
	var enemies := CombatEnemies.new(enemy_records)
	_check(party.is_valid() and enemies.is_valid(),
		"AC3 negative: the fresh party and roster are valid")
	if not (party.is_valid() and enemies.is_valid()):
		return
	_check(party.apply_damage(2, 30) and party.is_downed(2),
		"AC3 negative: Seamstress really starts this fixture at 0 HP")
	_check(not party.is_downed(1) and not party.is_downed(3)
		and party.get_hero(1).get("hp") == 40 and party.get_hero(3).get("hp") == 26,
		"AC3 negative: Warden and Tinker are alive and undamaged")
	_check(enemies.get_enemy(1).get("hp") == 18 and enemies.get_enemy(2).get("hp") == 14,
		"AC3 negative: both sources are alive before the phase")

	var definitions: Array = RunFightEncounterSelection._parse_schedule_text(
		_read_text(ENCOUNTER_PATH))
	var scheduler := CombatEnemyIntents.new(definitions)
	_check(scheduler.is_valid(), "AC3 negative: the authored schedule is valid")
	if not scheduler.is_valid():
		return
	var intents: Array = scheduler.get_intents()
	var beats := _expected_beats()
	_check(intents == beats[0] and intents.size() == 2,
		"AC3 negative: the fixture announces the real first beat from both sources")
	var hero_before := party.get_heroes()
	var enemy_before := enemies.get_enemies()
	var intents_before := intents.duplicate(true)
	var result: Dictionary = CombatEnemyPhase.new().execute_phase(party, enemies, intents)
	_check(result == {"ok": false, "events": []},
		"AC3 negative: the later Bleed on a downed Seamstress rejects the whole phase")
	_check(party.get_heroes() == hero_before
		and JSON.stringify(party.get_heroes()) == JSON.stringify(hero_before),
		"AC3 negative: every hero HP, Block, status and position is byte-identical")
	_check(enemies.get_enemies() == enemy_before
		and JSON.stringify(enemies.get_enemies()) == JSON.stringify(enemy_before),
		"AC3 negative: every enemy record and Block is byte-identical")
	_check(intents == intents_before and scheduler.get_intents() == beats[0],
		"AC3 negative: the rejection edits no intents and advances no scheduler")

	# Control: the same first source alone really does damage Tinker on an
	# identical fresh fixture, so the rejection comes from the later source.
	var control_party := CombatParty.new(hero_records)
	var control_enemies := CombatEnemies.new(enemy_records)
	_check(control_party.is_valid() and control_enemies.is_valid()
		and control_party.apply_damage(2, 30) and control_party.is_downed(2),
		"AC3 negative control: an identical fixture also has a downed Seamstress")
	var control := CombatEnemyPhase.new().execute_phase(control_party, control_enemies,
		[intents[0].duplicate(true)])
	_check(control == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "applied": true, "target_position": 3}]}
		and control_party.get_hero(3).get("hp") == 22,
		"AC3 negative control: the staged Tinker attack succeeds before the later failure")
