extends SceneTree

## Deterministic headless coverage for the standalone authored Threadbite Midline
## Press M03 Fight: slot 1 Seam Ripper (Bleed 2 on the middle, then a front hit,
## then self-Block 2), slot 2 Spool Stalker (a middle hit, then a rear hit, then a
## self-Block buff 2). This file only authors and verifies the schedule and its
## real service resolution; it does NOT wire the encounter into the typed battle
## pools, the app scene or any live play path (that is a separate task).

const ENCOUNTER_PATH := "res://data/encounters/threadbite_midline_press.json"
const ENCOUNTER_ID := "threadbite_midline_press"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMY_PATH := "res://data/enemies/run_enemies.json"
const STARTER_PATH := "res://data/encounters/starter_attacks.json"
const FRAYGUARD_PATH := "res://data/encounters/frayguard_attrition.json"
const POOLS_PATH := "res://data/encounters/m03_typed_battle_pools.json"
const HERO_IDS := ["warden", "seamstress", "tinker"]
# Encounter slot order: 1 Seam Ripper, 2 Spool Stalker.
const ENEMY_IDS := ["seam_ripper", "spool_stalker"]
const CYCLE_TURNS := 5

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_authored_schedule_and_catalog()
	_test_companion_schedules_still_valid()
	_test_intent_cycle()
	_test_beat_zero_real_execution()
	_test_owner_turn_tick()
	_test_beat_one_front_and_rear()
	_test_beat_two_defensive_recovery()
	_test_slain_source_skips_debuff()
	_test_downed_target_rejects_phase()
	_test_cycle_replay()
	_test_parser_rejections()
	if failures.is_empty():
		print("threadbite_midline_press_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("threadbite_midline_press_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## The exact prescribed schedule for this encounter's own two sources.
func _expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed"},
			{"type": "attack", "amount": 3, "target_position": 1},
			{"type": "block", "amount": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 3, "target_position": 2},
			{"type": "attack", "amount": 2, "target_position": 3},
			{"type": "buff", "amount": 2}]},
	]


## Literal announced beats, independent of the parsed file and of _expected().
func _intents_for(turn: int) -> Array:
	var beats: Array = [
		[{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed",
			"enemy_position": 1},
		{"type": "attack", "amount": 3, "target_position": 2, "enemy_position": 2}],
		[{"type": "attack", "amount": 3, "target_position": 1, "enemy_position": 1},
		{"type": "attack", "amount": 2, "target_position": 3, "enemy_position": 2}],
		[{"type": "block", "amount": 2, "enemy_position": 1},
		{"type": "buff", "amount": 2, "enemy_position": 2}],
	]
	return beats[turn % beats.size()]


## Literal per-beat resolution through the real phase services.
func _events_for(turn: int) -> Array:
	var beats: Array = [
		[{"type": "debuff", "enemy_position": 1, "applied": true,
			"target_position": 2, "status": "bleed"},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 2}],
		[{"type": "attack", "enemy_position": 1, "applied": true, "target_position": 1},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 3}],
		[{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "buff", "enemy_position": 2, "applied": true}],
	]
	return beats[turn % beats.size()]


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "opens " + path)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


## Godot may hand whole JSON numbers to the rules as floats; authored catalog
## records are normalized exactly so the real model services see ints.
func _load_records(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(_read_text(path))
	_check(parsed is Array, "catalog parses as an Array: " + path)
	if not parsed is Array:
		return []
	var records: Array = []
	for entry in parsed:
		if not entry is Dictionary or not entry.has("max_hp"):
			return []
		var record: Dictionary = entry.duplicate(true)
		var hp: Variant = record["max_hp"]
		if hp is float:
			if is_nan(hp) or is_inf(hp) or hp <= 0 or hp > 9007199254740991.0 \
					or floorf(hp) != hp:
				return []
			record["max_hp"] = int(hp)
		elif not hp is int or hp <= 0:
			return []
		records.append(record)
	return records


func _parsed() -> Array:
	return RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))


## One named entry, located by its own enemy_position (never by list order or a catalogue total).
func _unique_entry(entries: Array, position: int) -> Dictionary:
	var matches: Array = []
	for entry in entries:
		if entry is Dictionary and entry.get("enemy_position") == position:
			matches.append(entry)
	_check(matches.size() == 1, "exactly one entry at enemy_position %d" % position)
	return {} if matches.is_empty() else matches[0]


func _check_entry(entries: Array, position: int, expected_actions: Array) -> void:
	var entry := _unique_entry(entries, position)
	_check(entry.size() == 2 and entry.has("enemy_position") and entry.has("pattern"),
		"entry %d has exactly enemy_position and pattern" % position)
	var pattern = entry.get("pattern")
	_check(pattern is Array and pattern.size() == expected_actions.size(),
		"entry %d has exactly %d actions" % [position, expected_actions.size()])
	if not pattern is Array or pattern.size() != expected_actions.size():
		return
	for index in range(expected_actions.size()):
		_check(pattern[index] == expected_actions[index],
			"entry %d beat %d is exactly %s" % [position, index + 1,
				JSON.stringify(expected_actions[index])])


func _hero_ledger(heroes: Array) -> Array:
	var result: Array = []
	for hero in heroes:
		result.append([hero.get("hp"), hero.get("block")])
	return result


func _enemy_ledger(enemies: Array) -> Array:
	var result: Array = []
	for enemy in enemies:
		result.append([enemy.get("hp"), enemy.get("block")])
	return result


func _check_enemy(enemies: CombatEnemies, position: int, id: String, hp: int, block: int,
		label: String) -> void:
	var enemy := enemies.get_enemy(position)
	_check(enemy.get("id") == id and enemy.get("position") == position
		and enemy.get("hp") == hp and enemy.get("block") == block,
		"%s: enemy %d is %s with %d HP and %d Block (got %s %d/%d)"
			% [label, position, id, hp, block, enemy.get("id"), enemy.get("hp"), enemy.get("block")])


func _record(records: Array, id: String, label: String) -> Dictionary:
	var matches: Array = []
	for record in records:
		if record is Dictionary and record.get("id") == id:
			matches.append(record)
	_check(matches.size() == 1, "%s %s appears exactly once" % [label, id])
	return {} if matches.is_empty() else matches[0].duplicate(true)


func _build_party() -> CombatParty:
	var records := _load_records(PARTY_PATH)
	var definitions: Array = []
	for id in HERO_IDS:
		definitions.append(_record(records, id, "authored hero"))
	return CombatParty.new(definitions)


func _build_enemies() -> CombatEnemies:
	var records := _load_records(ENEMY_PATH)
	var definitions: Array = []
	for id in ENEMY_IDS:
		definitions.append(_record(records, id, "authored enemy"))
	return CombatEnemies.new(definitions)


## AC1: the shipped file is exactly the prescribed two-source, three-beat
## schedule, and the catalog actors it names keep their identities and stats.
func _test_authored_schedule_and_catalog() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "new authored encounter file exists")
	_check(ENCOUNTER_PATH.get_file().get_basename() == ENCOUNTER_ID,
		"the schedule file name carries the canonical encounter ID %s" % ENCOUNTER_ID)
	var raw := _read_text(ENCOUNTER_PATH)
	var raw_json: Variant = JSON.parse_string(raw)
	_check(raw_json is Array and raw_json.size() == 2,
		"the authored file holds exactly this encounter's two source records")
	var parsed := _parsed()
	var expected := _expected()
	_check(parsed == expected, "real parser accepts the file as the exact prescribed schedule")
	_check(parsed.size() == 2, "the parsed schedule has exactly two sources")
	var positions: Array[int] = []
	for entry in parsed:
		if entry is Dictionary and entry.get("enemy_position") is int:
			positions.append(entry["enemy_position"])
	positions.sort()
	_check(positions == [1, 2], "the parsed schedule has the unique source positions 1 and 2")
	_check(CombatEnemyIntents.new(parsed).is_valid(),
		"CombatEnemyIntents.is_valid() for the new authored JSON")
	_check_entry(parsed, 1, expected[0]["pattern"])
	_check_entry(parsed, 2, expected[1]["pattern"])
	# The loader normalizes every JSON whole number to a real int before the rules see it.
	for entry in parsed:
		_check(entry.get("enemy_position") is int,
			"parsed enemy_position is an int, not a JSON float")
		var pattern: Array = entry["pattern"]
		_check(pattern.size() == 3,
			"source %d has exactly the three-action cycle" % entry["enemy_position"])
		for action in pattern:
			_check(action.get("amount") is int,
				"parsed beat amount is an int, not a JSON float")
			if action.has("target_position"):
				_check(action.get("target_position") is int,
					"parsed beat target_position is an int, not a JSON float")
	_check(parsed[0]["pattern"][0] == {"type": "debuff", "amount": 2,
		"target_position": 2, "status": "bleed"},
		"the Seam Ripper's first beat is the authored Bleed 2 on hero position 2")
	_check(parsed[1]["pattern"][0] == {"type": "attack", "amount": 3,
		"target_position": 2},
		"the Spool Stalker's first beat is the authored 3-damage hit on hero position 2")
	_check(CombatEnemyIntents.new(_expected()).is_valid(),
		"the literal prescription itself validates")
	_check(_read_text(ENCOUNTER_PATH) == raw,
		"the authored file bytes stay unchanged after validation")

	# The named actors really exist, exactly once each, with the stats this
	# schedule is authored against; slot order is 1 Seam Ripper, 2 Spool Stalker.
	var enemy_records := _load_records(ENEMY_PATH)
	var ripper := _record(enemy_records, "seam_ripper", "authored enemy")
	var stalker := _record(enemy_records, "spool_stalker", "authored enemy")
	_check(ripper.get("name") == "Seam Ripper" and ripper.get("max_hp") == 18
		and ripper.get("max_hp") is int,
		"shipped seam_ripper is Seam Ripper with 18 integer max HP")
	_check(stalker.get("name") == "Spool Stalker" and stalker.get("max_hp") == 14
		and stalker.get("max_hp") is int,
		"shipped spool_stalker is Spool Stalker with 14 integer max HP")
	for record in [ripper, stalker]:
		_check(record.get("art_path") is String
				and (record.get("art_path") as String).begins_with("res://assets/paper/enemies/"),
			"shipped enemy %s keeps its art path for later real art" % record.get("id"))

	var enemies := _build_enemies()
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2,
		"authored two-enemy roster is valid")
	var roster_ids: Array = []
	for enemy in enemies.get_enemies():
		roster_ids.append(enemy.get("id"))
	_check(roster_ids == ENEMY_IDS,
		"the constructed roster is exactly the two catalog records in this order")
	_check_enemy(enemies, 1, "seam_ripper", 18, 0, "start")
	_check_enemy(enemies, 2, "spool_stalker", 14, 0, "start")
	_check(enemies.get_enemy(1).get("name") == "Seam Ripper"
		and enemies.get_enemy(1).get("position") == 1,
		"Seam Ripper keeps its name in enemy slot 1")
	_check(enemies.get_enemy(2).get("name") == "Spool Stalker"
		and enemies.get_enemy(2).get("position") == 2,
		"Spool Stalker keeps its name in enemy slot 2")

	var party := _build_party()
	_check(party.is_valid(), "shipped starter party builds a real three-hero party")
	var heroes: Array = party.get_heroes()
	_check(_hero_ledger(heroes) == [[40, 0], [30, 0], [26, 0]],
		"the party starts Warden 40, Seamstress 30, Tinker 26, all with no Block")
	_check(heroes[0].get("name") == "Warden" and heroes[0].get("max_hp") == 40,
		"starter slot 1 is Warden with 40 max HP")
	_check(heroes[1].get("name") == "Seamstress" and heroes[1].get("max_hp") == 30,
		"starter slot 2 is Seamstress with 30 max HP")
	_check(heroes[2].get("name") == "Tinker" and heroes[2].get("max_hp") == 26,
		"starter slot 3 is Tinker with 26 max HP")


## AC4: the two named earlier schedules still parse and validate, judged only by
## their own complete per-source entries, and this standalone schedule stays out
## of the shared typed pool owned by another lane.
func _test_companion_schedules_still_valid() -> void:
	var starter := RunFightEncounterSelection._parse_schedule_text(_read_text(STARTER_PATH))
	_check_entry(starter, 1, [
		{"type": "attack", "amount": 1, "target_position": 1},
		{"type": "attack", "amount": 1, "target_position": 2},
		{"type": "attack", "amount": 1, "target_position": 3}])
	_check_entry(starter, 2, [{"type": "block", "amount": 1}])
	_check(CombatEnemyIntents.new(starter).is_valid(),
		"starter_attacks.json still validates in CombatEnemyIntents")
	var frayguard := RunFightEncounterSelection._parse_schedule_text(_read_text(FRAYGUARD_PATH))
	_check_entry(frayguard, 1, [
		{"type": "debuff", "amount": 2, "target_position": 3, "status": "bleed"},
		{"type": "attack", "amount": 3, "target_position": 3},
		{"type": "attack", "amount": 2, "target_position": 2}])
	_check_entry(frayguard, 2, [
		{"type": "block", "amount": 4},
		{"type": "attack", "amount": 2, "target_position": 1},
		{"type": "buff", "amount": 2}])
	_check(CombatEnemyIntents.new(frayguard).is_valid(),
		"frayguard_attrition.json still validates in CombatEnemyIntents")

	var pools: Variant = JSON.parse_string(_read_text(POOLS_PATH))
	_check(pools is Dictionary, "the shared typed battle pool still parses")
	if pools is Dictionary:
		for kind in ["Fight", "Elite", "Boss"]:
			var entries = pools.get(kind)
			var present := entries is Dictionary and (entries as Dictionary).has(ENCOUNTER_ID)
			_check(not present,
				"the standalone %s is absent from the shared %s pool" % [ENCOUNTER_ID, kind])
		var fight_entries = pools.get("Fight")
		_check(fight_entries is Dictionary and (fight_entries as Dictionary).has("starter_attacks"),
			"an earlier Fight remains present in the shared pool by ID")


## AC1: three announced beats in ascending source order, then an exact repeat,
## with independent snapshots, no implicit advance and no RNG consumption.
func _test_intent_cycle() -> void:
	var definitions := _expected()
	var intents := CombatEnemyIntents.new(definitions)
	_check(intents.is_valid(), "authored schedule builds a valid intent selector")
	_check(intents.get_intents() == _intents_for(0), "turn 0 announces the exact first beats")
	_check(intents.get_intents() == _intents_for(0),
		"querying the first announcement twice returns the same beat")
	_check(intents._turn_index == 0, "querying announcements never advances the cycle")

	# Caller edits to a returned announcement cannot change later reads.
	var snapshot := intents.get_intents()
	_check(snapshot == _intents_for(0), "snapshot is the exact first announced beats")
	snapshot[0]["type"] = "block"
	snapshot[0]["amount"] = 99
	snapshot.append({"enemy_position": 3, "type": "block", "amount": 5})
	_check(intents.get_intents() == _intents_for(0),
		"mutating a returned announcement cannot alter later intents")
	_check(intents._turn_index == 0,
		"mutating a returned announcement cannot advance the cycle")
	var second_read := intents.get_intents()
	second_read[1]["target_position"] = 1
	second_read[1]["amount"] = 0
	_check(intents.get_intents() == _intents_for(0),
		"editing a second returned announcement cannot alter later intents")

	for beat in range(4):
		var announced := intents.get_intents()
		_check(announced == _intents_for(beat),
			"beat %d announces exactly the authored per-source actions" % (beat + 1))
		_check(announced.size() == 2
			and announced[0].get("enemy_position") == 1
			and announced[1].get("enemy_position") == 2,
			"beat %d lists source slot 1 then source slot 2" % (beat + 1))
		_check(intents._turn_index == beat, "beat %d reports turn index %d" % [beat + 1, beat])
		if beat < 3:
			_check(intents.advance_turn(), "advance from beat %d" % (beat + 1))
	_check(intents._turn_index == 3, "beat 4 is the third explicit advance before wrap")
	_check(intents.advance_turn() and intents.get_intents() == _intents_for(1),
		"beat 5 continues the fixed cycle after the wraparound")
	_check(definitions == _expected(), "the parsed source stays exactly as authored")

	# The whole fixed cycle, viewed and advanced, draws no global RNG.
	seed(20261021)
	var baseline := randi()
	seed(20261021)
	var probe := CombatEnemyIntents.new(definitions)
	for turn in range(8):
		probe.get_intents()
		probe.advance_turn()
	_check(randi() == baseline,
		"constructing, viewing and advancing this schedule draws no global RNG")
	seed(20261021)
	var without_extra := randi()
	seed(20261021)
	randi()
	_check(randi() != without_extra, "the global RNG probe detects an injected extra draw")


## AC2: the authored first beat resolves through the real services against the
## untouched starter party and living roster: Seamstress 30 -> 27 HP with Bleed 2.
func _test_beat_zero_real_execution() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	_check(party.is_valid() and enemies.is_valid(), "living fresh party and roster are valid")
	_check(_hero_ledger(party.get_heroes()) == [[40, 0], [30, 0], [26, 0]],
		"beat-0 fixture starts with the untouched starter party")
	_check(_enemy_ledger(enemies.get_enemies()) == [[18, 0], [14, 0]],
		"beat-0 fixture starts with both enemies at full HP and no Block")
	var scheduler := CombatEnemyIntents.new(_parsed())
	var intents: Array = scheduler.get_intents()
	_check(intents == _intents_for(0), "beat 0 announces the authored first beats")
	var input_copy: Array = intents.duplicate(true)
	seed(20261021)
	var expected_global := randi()
	seed(20261021)
	var result := phase.execute_phase(party, enemies, intents)
	_check(randi() == expected_global, "the real beat-0 phase draws no global RNG")
	_check(result.get("ok") == true, "beat 0 succeeds")
	var events: Array = result.get("events", [])
	_check(events == _events_for(0),
		"beat 0 events: source-1 Bleed 2 on hero 2, then source-2 attack 3 on hero 2")
	_check(events.size() == 2 and events[0].get("enemy_position") == 1
		and events[1].get("enemy_position") == 2,
		"the two beat-0 events are in ascending enemy-source order")
	_check(intents == input_copy, "the executed phase leaves caller intents untouched")

	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 0,
		"the front Warden is unhurt by beat 0")
	_check(party.get_hero(2).get("hp") == 27 and party.get_hero(2).get("block") == 0
		and party.get_hero(2).get("statuses") == {"bleed": 2},
		"the middle Seamstress falls to 27 HP with exactly Bleed 2")
	_check(party.get_hero(3).get("hp") == 26 and party.get_hero(3).get("block") == 0
		and party.get_hero(3).get("statuses", {}) == {},
		"the rear Tinker is unhurt by beat 0")
	_check(_hero_ledger(party.get_heroes()) == [[40, 0], [27, 0], [26, 0]],
		"beat 0 hero HP/Block ledger")
	_check(_enemy_ledger(enemies.get_enemies()) == [[18, 0], [14, 0]],
		"beat 0 leaves both enemies at full HP and no Block")

	# Enemy-applied Bleed is exactly 2: the Seamstress passive adds nothing here.
	_check(party.get_hero(2).get("statuses") == {"bleed": 2},
		"enemy-applied Bleed is exactly 2, without the Seamstress passive bonus")
	var passive := CombatOnHitStatuses.new().status_for_confirmed_hit("seamstress_prick", true)
	_check(passive == {"bleed": 3},
		"control: the Seamstress passive still applies to her own authored card")
	_check(scheduler._turn_index == 0 and scheduler.get_intents() == _intents_for(0),
		"the phase does not advance or mutate the first announcement")


## AC2: the independent hero-owner tick, not the phase, is what turns Bleed into
## HP loss: Seamstress 27 -> 25 through her real Block, Bleed 2 -> 1.
func _test_owner_turn_tick() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	_check(CombatStartingBlock.new(party).apply(),
		"owner-tick fixture applies the Warden opening Block 6")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6,
		"owner-tick fixture: Warden 40 HP with 6 Block")
	var scheduler := CombatEnemyIntents.new(_parsed())
	var first := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(first.get("ok") == true and first.get("events") == _events_for(0),
		"owner-tick fixture begins with the authored first beat")
	_check(party.get_hero(2).get("hp") == 27
		and party.get_hero(2).get("statuses") == {"bleed": 2},
		"owner-tick fixture: Seamstress is 27 HP with Bleed 2 before her owner turn")
	_check(party.gain_block(2, 4) and party.get_hero(2).get("block") == 4,
		"precondition: Seamstress holds real Block 4 before her owner turn")
	var party_before: Array = party.get_heroes()
	var enemies_before: Array = enemies.get_enemies()
	var batch := CombatStatusTurnBatch.new()
	var tick := batch.tick_side("heroes", party.get_heroes())
	_check(tick.get("ok") == true and tick.get("actors", []).size() == 3
		and tick.get("events", []).size() == 3,
		"the detached hero-owner tick accepts all three slots")
	var actors: Array = tick.get("actors", [])
	_check(actors[0].get("id") == "warden" and actors[0].get("hp") == 40
		and actors[0].get("block") == 6,
		"the tick leaves the Warden at 40 HP and 6 Block")
	_check(actors[1].get("id") == "seamstress" and actors[1].get("hp") == 25
		and actors[1].get("block") == 4 and actors[1].get("statuses") == {"bleed": 1},
		"Bleed 2 removes 2 HP from shielded Seamstress (27 -> 25) and becomes Bleed 1")
	_check(actors[2].get("id") == "tinker" and actors[2].get("hp") == 26
		and actors[2].get("block") == 0,
		"the tick leaves the rear Tinker unchanged")
	_check(tick.get("events") == [
		{"side": "heroes", "position": 1, "id": "warden", "bleed_hp_loss": 0},
		{"side": "heroes", "position": 2, "id": "seamstress", "bleed_hp_loss": 2},
		{"side": "heroes", "position": 3, "id": "tinker", "bleed_hp_loss": 0}],
		"the tick reports 2 Bleed HP loss on the Seamstress in position order")
	_check(party.get_heroes() == party_before,
		"the detached tick does not write to the real CombatParty")
	_check(enemies.get_enemies() == enemies_before,
		"the detached tick does not alter the enemy roster")
	_check(party.get_hero(2).get("block") == 4 and party.get_hero(1).get("block") == 6,
		"the tick keeps the Seamstress's 4 Block and the Warden's 6 Block")
	_check(party.start_player_turn(), "the normal player-turn reset succeeds")
	_check(party.get_hero(1).get("block") == 0 and party.get_hero(2).get("block") == 0
		and party.get_hero(3).get("block") == 0,
		"the player-turn reset clears every hero's Block")
	_check(party.get_hero(2).get("hp") == 27
		and party.get_hero(2).get("statuses") == {"bleed": 2},
		"the player-turn reset does not touch HP or Bleed")
	_check(scheduler._turn_index == 0 and scheduler.get_intents() == _intents_for(0),
		"owner ticks do not advance the intent cycle")


## AC2: a fresh beat-1 fixture with the Warden's real opening Block 6: the front
## hit is absorbed and the rear hit lands.
func _test_beat_one_front_and_rear() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	_check(CombatStartingBlock.new(party).apply(),
		"beat-1 fixture applies the Warden opening Block 6")
	var scheduler := CombatEnemyIntents.new(_parsed())
	_check(scheduler.advance_turn(), "beat-1 fixture advances the cycle once")
	var announced: Array = scheduler.get_intents()
	_check(announced == _intents_for(1), "beat 1 announces the front-3 and rear-2 attacks")
	var result := phase.execute_phase(party, enemies, announced)
	_check(result.get("ok") == true and result.get("events") == _events_for(1),
		"beat 1 resolves exactly two ordered applied attack events")
	var events: Array = result.get("events", [])
	_check(events.size() == 2 and events[0].get("enemy_position") == 1
		and events[1].get("enemy_position") == 2,
		"beat 1 events remain source-sorted (slot 1 then slot 2)")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 3,
		"beat 1: Warden's 6 Block absorbs the 3-damage front hit (40 HP, 3 Block left)")
	_check(party.get_hero(3).get("hp") == 24 and party.get_hero(3).get("block") == 0,
		"beat 1: the rear Tinker takes the 2-damage hit (26 -> 24 HP)")
	_check(party.get_hero(2).get("hp") == 30
		and party.get_hero(2).get("statuses", {}) == {},
		"beat 1: the middle Seamstress is untouched")
	_check(_hero_ledger(party.get_heroes()) == [[40, 3], [30, 0], [24, 0]],
		"beat 1 hero HP/Block ledger")
	_check(_enemy_ledger(enemies.get_enemies()) == [[18, 0], [14, 0]],
		"beat 1 leaves both enemies unchanged")


## AC3: a fresh beat-2 fixture grants exactly 2 Block to each living enemy and
## leaves every hero untouched.
func _test_beat_two_defensive_recovery() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	var scheduler := CombatEnemyIntents.new(_parsed())
	scheduler.advance_turn()
	_check(scheduler.advance_turn(), "beat-2 fixture advances the cycle twice")
	var announced: Array = scheduler.get_intents()
	_check(announced == _intents_for(2), "beat 2 announces the slot-1 Block and slot-2 Buff")
	var result := phase.execute_phase(party, enemies, announced)
	_check(result.get("ok") == true and result.get("events") == _events_for(2),
		"beat 2 resolves the Block and the Buff events")
	_check(enemies.get_enemy(1).get("id") == "seam_ripper"
		and enemies.get_enemy(1).get("block") == 2 and enemies.get_enemy(1).get("hp") == 18,
		"beat 2: Seam Ripper gains exactly 2 Block at full HP")
	_check(enemies.get_enemy(2).get("id") == "spool_stalker"
		and enemies.get_enemy(2).get("block") == 2 and enemies.get_enemy(2).get("hp") == 14,
		"beat 2: Spool Stalker gains exactly 2 Block at full HP")
	_check(_enemy_ledger(enemies.get_enemies()) == [[18, 2], [14, 2]],
		"beat 2 enemy HP/Block ledger")
	_check(_hero_ledger(party.get_heroes()) == [[40, 0], [30, 0], [26, 0]],
		"beat 2: no hero loses HP or gains Block")


## AC3: a slain Seam Ripper skips only its own debuff; the living Spool Stalker
## still attacks and no hero is bled.
func _test_slain_source_skips_debuff() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	_check(CombatStartingBlock.new(party).apply(),
		"slain-source fixture applies opening Block")
	_check(enemies.apply_damage(1, 18) and enemies.is_slain(1) and not enemies.is_slain(2),
		"negative: Seam Ripper is really slain and Spool Stalker stays alive")
	var dead_before: Dictionary = enemies.get_enemy(1)
	var scheduler := CombatEnemyIntents.new(_parsed())
	var intents: Array = scheduler.get_intents()
	_check(intents == _intents_for(0), "slain-source fixture announces the authored first beats")
	var result := phase.execute_phase(party, enemies, intents)
	_check(result == {"ok": true, "events": [
		{"type": "debuff", "enemy_position": 1, "applied": false,
			"target_position": 2, "status": "bleed"},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 2}]},
		"negative: the slain Seam Ripper's debuff is unapplied; the living Spool Stalker still attacks")
	_check(party.get_hero(2).get("statuses", {}) == {} and party.get_hero(2).get("hp") == 27,
		"negative: Seamstress gets NO Bleed but still takes the 3-damage attack (27 HP)")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(3).get("hp") == 26,
		"negative: the Warden and the rear Tinker are unhurt by the slain-source beat")
	_check(enemies.get_enemy(1) == dead_before,
		"negative: the slain source stays at its original slot with unchanged HP/Block")
	_check_enemy(enemies, 2, "spool_stalker", 14, 0, "slain source")
	_check(scheduler._turn_index == 0 and scheduler.get_intents() == _intents_for(0),
		"negative: the phase leaves the announcement cycle untouched")


## AC3: a downed Seamstress rejects the complete beat-0 phase with no party or
## enemy mutation, no turn advance and no RNG consumption.
func _test_downed_target_rejects_phase() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	_check(party.apply_damage(2, 30) and party.is_downed(2)
		and party.get_hero(2).get("hp") == 0,
		"negative: real party damage downs the Seamstress at position 2 before beat 0")
	var party_before: Array = party.get_heroes()
	var enemies_before: Array = enemies.get_enemies()
	var scheduler := CombatEnemyIntents.new(_parsed())
	var intents: Array = scheduler.get_intents()
	var intents_before: Array = intents.duplicate(true)
	_check(intents == _intents_for(0),
		"negative: beat 0 still announces the Bleed onto the downed hero slot")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261021
	var rng_before := rng.state
	seed(20261021)
	var expected_global := randi()
	seed(20261021)
	var result := phase.execute_phase(party, enemies, intents)
	_check(randi() == expected_global, "negative: the rejected phase draws no global RNG")
	_check(rng.state == rng_before,
		"negative: the rejected phase leaves the seeded RNG stream untouched")
	_check(result == {"ok": false, "events": []},
		"negative: the downed Bleed target rejects the whole first phase")
	_check(party.get_heroes() == party_before,
		"negative: no hero HP, Block, position or status survives the rejected phase")
	_check(party.is_downed(2) and party.get_hero(2).get("id") == "seamstress",
		"negative: downed Seamstress stays in her slot, unbled and unrevived")
	_check(enemies.get_enemies() == enemies_before,
		"negative: the rejected phase grants no enemy Block")
	_check(intents == intents_before and scheduler.get_intents() == _intents_for(0)
		and scheduler._turn_index == 0,
		"negative: the rejected phase leaves caller intents and announcements untouched")

	# Localized control: downing the front Warden instead still lets beat 0 resolve.
	var control_party := _build_party()
	var control_enemies := _build_enemies()
	_check(control_party.apply_damage(1, 40) and control_party.is_downed(1),
		"control: real party damage downs the Warden, not the Bleed target")
	var control := phase.execute_phase(control_party, control_enemies,
		CombatEnemyIntents.new(_parsed()).get_intents())
	_check(control == {"ok": true, "events": _events_for(0)},
		"control: the same beats resolve when the downed hero is not the Bleed target")
	_check(control_party.get_hero(2).get("statuses") == {"bleed": 2}
		and control_party.get_hero(2).get("hp") == 27,
		"control: Seamstress still receives Bleed 2 and takes the 3-damage attack")
	_check(control_party.get_hero(1).get("hp") == 0,
		"control: the already downed Warden stays downed")


## A full three-beat cycle plus the wraparound, captured as complete observations.
func _cycle() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261021
	var rng_before := rng.state
	var party := _build_party()
	var enemies := _build_enemies()
	var opening_applied := CombatStartingBlock.new(party).apply()
	var scheduler := CombatEnemyIntents.new(_parsed())
	var beats: Array = []
	for index in range(CYCLE_TURNS):
		var announced: Array = scheduler.get_intents()
		var result := phase.execute_phase(party, enemies, announced)
		beats.append({"announced": announced, "events": result.get("events", []),
			"ok": result.get("ok"), "heroes": party.get_heroes(),
			"enemies": enemies.get_enemies()})
		scheduler.advance_turn()
	return {
		"opening": opening_applied,
		"beats": beats,
		"final_announcement": scheduler.get_intents(),
		"turn_index": scheduler._turn_index,
		"rng_before": rng_before,
		"rng_after": rng.state,
	}


## AC3: two independently constructed fixtures with independent seeded RNGs agree
## on every beat and reproduce the literal end state, with no consumed RNG.
func _test_cycle_replay() -> void:
	seed(20261021)
	var expected_global := randi()
	seed(20261021)
	var first := _cycle()
	_check(randi() == expected_global, "the whole authored cycle draws no global RNG")
	var second := _cycle()
	_check(first.get("opening") == true and second.get("opening") == true,
		"both fixtures applied the Warden opening Block exactly once")
	_check(first.get("beats") == second.get("beats"),
		"two independently constructed cycles produce identical beats")
	_check(first.get("final_announcement") == second.get("final_announcement")
		and first.get("final_announcement") == _intents_for(2)
		and first.get("turn_index") == CYCLE_TURNS
		and second.get("turn_index") == CYCLE_TURNS,
		"both cycles wrap the fixed three-beat schedule identically")
	_check(first.get("rng_before") == second.get("rng_before")
		and first.get("rng_after") == second.get("rng_after")
		and first.get("rng_before") == first.get("rng_after"),
		"both independent seeded RNGs reach identical, untouched states")

	# Literal checkpoints, so two equally broken runs cannot agree vacuously.
	var beats: Array = first.get("beats", [])
	_check(beats.size() == CYCLE_TURNS, "the cycle captured every beat")
	if beats.size() == CYCLE_TURNS:
		_check(beats[0].get("announced") == _intents_for(0)
			and beats[0].get("events") == _events_for(0),
			"cycle beat 0 announces and resolves the authored first beats")
		_check(_hero_ledger(beats[0]["heroes"]) == [[40, 6], [27, 0], [26, 0]],
			"cycle beat 0 hero ledger")
		_check(_enemy_ledger(beats[0]["enemies"]) == [[18, 0], [14, 0]],
			"cycle beat 0 enemy ledger")
		_check(beats[1].get("announced") == _intents_for(1)
			and beats[1].get("events") == _events_for(1),
			"cycle beat 1 announces and resolves the authored second beats")
		_check(_hero_ledger(beats[1]["heroes"]) == [[40, 3], [27, 0], [24, 0]],
			"cycle beat 1 hero ledger")
		_check(beats[2].get("announced") == _intents_for(2)
			and beats[2].get("events") == _events_for(2),
			"cycle beat 2 announces and resolves the authored third beats")
		_check(_enemy_ledger(beats[2]["enemies"]) == [[18, 2], [14, 2]],
			"cycle beat 2 enemy ledger")
		_check(beats[3].get("events") == _events_for(0),
			"cycle beat 3 repeats the beat-0 events after the wrap")
		_check(_hero_ledger(beats[3]["heroes"]) == [[40, 3], [24, 0], [24, 0]],
			"cycle beat 3 hero ledger (Bleed stacks to 4, then 3 damage)")
		_check(beats[4].get("events") == _events_for(1),
			"cycle beat 4 repeats the beat-1 events after the wrap")
		_check(_hero_ledger(beats[4]["heroes"]) == [[40, 0], [24, 0], [22, 0]],
			"cycle beat 4 hero ledger (Warden's last Block absorbs, Tinker falls to 22)")


## Deep copy of the prescription with one beat replaced in place.
func _with_beat(position: int, beat: int, replacement: Dictionary) -> Array:
	var data: Array = _expected().duplicate(true)
	for entry in data:
		if entry["enemy_position"] == position:
			var pattern: Array = entry["pattern"]
			pattern[beat] = replacement
	return data


## AC1/AC3: malformed schedules fail closed in the canonical parser and in
## CombatEnemyIntents, each judged independently and without mutating input.
func _test_parser_rejections() -> void:
	var pristine := _read_text(ENCOUNTER_PATH)
	var duplicate := _expected().duplicate(true)
	duplicate[1]["enemy_position"] = 1
	var fractional := _with_beat(1, 0, {"type": "debuff", "amount": 2.5,
		"target_position": 2, "status": "bleed"})
	var off_board := _with_beat(1, 1, {"type": "attack", "amount": 3,
		"target_position": 4})
	var negative := _with_beat(2, 1, {"type": "attack", "amount": -1,
		"target_position": 3})
	var cases: Array = [
		{"label": "duplicate enemy_position records", "data": duplicate},
		{"label": "fractional authored amount 2.5", "data": fractional},
		{"label": "out-of-range target_position 4", "data": off_board},
		{"label": "negative attack amount -1", "data": negative},
	]
	for entry_case in cases:
		var data: Array = entry_case["data"]
		var untouched: Array = data.duplicate(true)
		_check(data != _expected(),
			"negative: %s really differs from the authored schedule" % entry_case["label"])
		_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(data)).is_empty(),
			"negative: %s is rejected by the canonical parser" % entry_case["label"])
		_check(data == untouched,
			"negative: %s leaves its local data untouched" % entry_case["label"])
		_check(not CombatEnemyIntents.new(data).is_valid(),
			"negative: %s is rejected by CombatEnemyIntents" % entry_case["label"])
		_check(data == untouched,
			"negative: %s leaves the submitted definitions untouched" % entry_case["label"])
	for broken_text in ["{", "{bad", "not json", "{}", "[]"]:
		_check(RunFightEncounterSelection._parse_schedule_text(broken_text).is_empty(),
			"negative: malformed/empty schedule text %s is rejected" % broken_text)
	_check(_parsed() == _expected(),
		"negative controls: the unmodified authored file still parses exactly")
	_check(CombatEnemyIntents.new(_expected()).is_valid(),
		"negative controls: the unmodified authored schedule still validates")
	_check(_read_text(ENCOUNTER_PATH) == pristine,
		"negative controls: local copies never alter the authored file")
