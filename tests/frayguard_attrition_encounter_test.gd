extends SceneTree

## Deterministic headless coverage for the authored Frayguard Attrition encounter:
## slot 1 Fray Scavenger inflicts Bleed 2 on the REAR Tinker, slot 2 Button Guard
## gains 4 Block, then the two sources attack the rear/front/middle and the guard
## self-buffs. Data/service only: this file never wires the encounter into live
## play, and no typed-pool or registry file is read or written here.

const ENCOUNTER_PATH := "res://data/encounters/frayguard_attrition.json"
const ENCOUNTER_ID := "frayguard_attrition"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMY_PATH := "res://data/enemies/run_enemies.json"
const STARTER_PATH := "res://data/encounters/starter_attacks.json"
const SPOOLWHEEL_PATH := "res://data/encounters/spoolwheel_feint.json"
const HERO_IDS := ["warden", "seamstress", "tinker"]
# Encounter slot order: 1 Fray Scavenger, 2 Button Guard.
const ENEMY_IDS := ["fray_scavenger", "button_guard"]

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_authored_schedule_and_catalog()
	_test_companion_schedules_still_valid()
	_test_intent_cycle()
	_test_first_phase_real_execution()
	_test_owner_turn_ticks()
	_test_fresh_beat_fixtures()
	_test_double_fixture_replay()
	_test_slain_source_skips_debuff()
	_test_downed_bleed_target_rejects_phase()
	_test_parser_rejections()
	if failures.is_empty():
		print("frayguard_attrition_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("frayguard_attrition_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## The exact prescribed schedule for this encounter's own two sources.
func _expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "debuff", "amount": 2, "target_position": 3, "status": "bleed"},
			{"type": "attack", "amount": 3, "target_position": 3},
			{"type": "attack", "amount": 2, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "block", "amount": 4},
			{"type": "attack", "amount": 2, "target_position": 1},
			{"type": "buff", "amount": 2}]},
	]


## Literal announced beats, independent of the parsed file and of _expected().
func _first_intents() -> Array:
	return [
		{"type": "debuff", "amount": 2, "target_position": 3, "status": "bleed",
			"enemy_position": 1},
		{"type": "block", "amount": 4, "enemy_position": 2}]


func _second_intents() -> Array:
	return [
		{"type": "attack", "amount": 3, "target_position": 3, "enemy_position": 1},
		{"type": "attack", "amount": 2, "target_position": 1, "enemy_position": 2}]


func _third_intents() -> Array:
	return [
		{"type": "attack", "amount": 2, "target_position": 2, "enemy_position": 1},
		{"type": "buff", "amount": 2, "enemy_position": 2}]


## Literal first-beat resolution through the real phase services.
func _first_events() -> Array:
	return [
		{"type": "debuff", "enemy_position": 1, "applied": true,
			"target_position": 3, "status": "bleed"},
		{"type": "block", "enemy_position": 2, "applied": true}]


func _second_events() -> Array:
	return [
		{"type": "attack", "enemy_position": 1, "applied": true, "target_position": 3},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 1}]


func _third_events() -> Array:
	return [
		{"type": "attack", "enemy_position": 1, "applied": true, "target_position": 2},
		{"type": "buff", "enemy_position": 2, "applied": true}]


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


func _check_hero(party: CombatParty, position: int, id: String, hp: int, block: int,
		statuses: Dictionary, label: String) -> void:
	var hero := party.get_hero(position)
	_check(hero.get("id") == id and hero.get("position") == position
		and hero.get("hp") == hp and hero.get("block") == block
		and hero.get("statuses", {}) == statuses,
		"%s: hero %d is %s at %d HP / %d Block / %s (got %s %d/%d/%s)"
			% [label, position, id, hp, block, statuses, hero.get("id"), hero.get("hp"),
				hero.get("block"), hero.get("statuses", {})])


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
		"target_position": 3, "status": "bleed"},
		"the scavenger's first beat is the authored Bleed 2 on hero position 3")
	_check(parsed[1]["pattern"][0] == {"type": "block", "amount": 4},
		"the guard's first beat is the authored self-Block 4")
	_check(CombatEnemyIntents.new(_expected()).is_valid(),
		"the literal prescription itself validates")
	_check(_read_text(ENCOUNTER_PATH) == raw,
		"the authored file bytes stay unchanged after validation")

	# The named actors really exist, exactly once each, with the stats this
	# schedule is authored against; slot order is 1 Fray Scavenger, 2 Button Guard.
	var enemy_records := _load_records(ENEMY_PATH)
	var scavenger := _record(enemy_records, "fray_scavenger", "authored enemy")
	var guard := _record(enemy_records, "button_guard", "authored enemy")
	_check(scavenger.get("name") == "Fray Scavenger" and scavenger.get("max_hp") == 14
		and scavenger.get("max_hp") is int,
		"shipped fray_scavenger is Fray Scavenger with 14 integer max HP")
	_check(guard.get("name") == "Button Guard" and guard.get("max_hp") == 16
		and guard.get("max_hp") is int,
		"shipped button_guard is Button Guard with 16 integer max HP")
	for record in [scavenger, guard]:
		_check(record.get("art_path") is String
			and not record.get("art_path", "").is_empty(),
			"shipped enemy %s keeps its art path for later real art" % record.get("id"))

	var enemies := _build_enemies()
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2,
		"authored two-enemy roster is valid")
	var roster_ids: Array = []
	for enemy in enemies.get_enemies():
		roster_ids.append(enemy.get("id"))
	_check(roster_ids == ENEMY_IDS,
		"the constructed roster is exactly the two catalog records in this order")
	_check_enemy(enemies, 1, "fray_scavenger", 14, 0, "start")
	_check_enemy(enemies, 2, "button_guard", 16, 0, "start")
	_check(enemies.get_enemy(1).get("name") == "Fray Scavenger"
		and enemies.get_enemy(1).get("position") == 1,
		"Fray Scavenger keeps its name in enemy slot 1")
	_check(enemies.get_enemy(2).get("name") == "Button Guard"
		and enemies.get_enemy(2).get("position") == 2,
		"Button Guard keeps its name in enemy slot 2")

	var party := _build_party()
	_check(party.is_valid(), "shipped starter party builds a real three-hero party")
	_check_hero(party, 1, "warden", 40, 0, {}, "start")
	_check_hero(party, 2, "seamstress", 30, 0, {}, "start")
	_check_hero(party, 3, "tinker", 26, 0, {}, "start")
	_check(party.get_hero(1).get("name") == "Warden"
		and party.get_hero(1).get("max_hp") == 40,
		"starter slot 1 is Warden with 40 max HP")
	_check(party.get_hero(2).get("name") == "Seamstress"
		and party.get_hero(2).get("max_hp") == 30,
		"starter slot 2 is Seamstress with 30 max HP")
	_check(party.get_hero(3).get("name") == "Tinker"
		and party.get_hero(3).get("max_hp") == 26,
		"starter slot 3 is Tinker with 26 max HP")


## AC1: the two named earlier schedules still parse and validate, judged only by
## their own complete per-source entries.
func _test_companion_schedules_still_valid() -> void:
	var starter := RunFightEncounterSelection._parse_schedule_text(_read_text(STARTER_PATH))
	_check_entry(starter, 1, [
		{"type": "attack", "amount": 1, "target_position": 1},
		{"type": "attack", "amount": 1, "target_position": 2},
		{"type": "attack", "amount": 1, "target_position": 3}])
	_check_entry(starter, 2, [{"type": "block", "amount": 1}])
	_check(CombatEnemyIntents.new(starter).is_valid(),
		"starter_attacks.json still validates in CombatEnemyIntents")
	var feint := RunFightEncounterSelection._parse_schedule_text(_read_text(SPOOLWHEEL_PATH))
	_check_entry(feint, 1, [
		{"type": "block", "amount": 1},
		{"type": "attack", "amount": 1, "target_position": 2}])
	_check_entry(feint, 2, [
		{"type": "attack", "amount": 1, "target_position": 1},
		{"type": "attack", "amount": 1, "target_position": 3},
		{"type": "block", "amount": 1}])
	_check(CombatEnemyIntents.new(feint).is_valid(),
		"spoolwheel_feint.json still validates in CombatEnemyIntents")


## AC1/AC3: three announced beats in ascending source order, then an exact
## repeat, with independent snapshots, no implicit advance and no RNG consumption.
func _test_intent_cycle() -> void:
	var definitions := _expected()
	var intents := CombatEnemyIntents.new(definitions)
	_check(intents.is_valid(), "authored schedule builds a valid intent selector")
	_check(intents.get_intents() == _first_intents(), "turn 1 announces the exact first beats")
	_check(intents.get_intents() == _first_intents(),
		"querying the first announcement twice returns the same beat")
	_check(intents._turn_index == 0, "querying announcements never advances the cycle")
	var snapshot := intents.get_intents()
	_check(snapshot == _first_intents(), "snapshot is the exact first announced beats")
	snapshot[0]["type"] = "block"
	snapshot[0]["amount"] = 99
	snapshot.append({"enemy_position": 3, "type": "block", "amount": 5})
	_check(intents.get_intents() == _first_intents(),
		"mutating a returned announcement cannot alter later intents")
	_check(intents._turn_index == 0,
		"mutating a returned announcement cannot advance the cycle")

	var beats: Array = [_first_intents(), _second_intents(), _third_intents(), _first_intents()]
	for beat in range(4):
		var announced := intents.get_intents()
		_check(announced == beats[beat],
			"beat %d announces exactly the authored per-source actions" % (beat + 1))
		_check(announced.size() == 2
			and announced[0].get("enemy_position") == 1
			and announced[1].get("enemy_position") == 2,
			"beat %d lists source slot 1 then source slot 2" % (beat + 1))
		_check(intents._turn_index == beat, "beat %d reports turn index %d" % [beat + 1, beat])
		if beat < 3:
			_check(intents.advance_turn(), "advance from beat %d" % (beat + 1))
	_check(intents._turn_index == 3, "beat 4 is the third explicit advance before wrap")
	_check(intents.advance_turn() and intents.get_intents() == _second_intents(),
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
## real party and roster: Bleed 2 on Tinker, 4 Block on Button Guard, no HP loss.
func _test_first_phase_real_execution() -> void:
	var party := _build_party()
	_check(party.is_valid(), "authored party is valid")
	var enemies := _build_enemies()
	_check(enemies.is_valid(), "authored two-enemy roster is valid")
	_check_enemy(enemies, 1, "fray_scavenger", 14, 0, "start")
	_check_enemy(enemies, 2, "button_guard", 16, 0, "start")
	_check_hero(party, 1, "warden", 40, 0, {}, "start")
	_check_hero(party, 2, "seamstress", 30, 0, {}, "start")
	_check_hero(party, 3, "tinker", 26, 0, {}, "start")

	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "Warden opening Block 6 applies once")
	_check_hero(party, 1, "warden", 40, 6, {}, "opening")
	var opened := party.get_heroes()
	_check(not opening.apply(), "opening Block cannot be applied twice")
	_check(party.get_heroes() == opened,
		"a second opening attempt grants no additional Block")

	var scheduler := CombatEnemyIntents.new(_parsed())
	_check(scheduler.get_intents() == _first_intents(),
		"beat 1 announces Bleed 2 on Tinker, then the guard's self-Block 4")
	var input_intents: Array = scheduler.get_intents()
	var input_copy: Array = input_intents.duplicate(true)
	var before_enemies: Array = enemies.get_enemies()
	seed(20261021)
	var expected_global := randi()
	seed(20261021)
	var result := phase.execute_phase(party, enemies, input_intents)
	_check(randi() == expected_global, "the real beat-1 phase draws no global RNG")
	_check(result.get("ok") == true, "beat 1 succeeds")
	var events: Array = result.get("events", [])
	_check(events == _first_events(),
		"beat 1 events: source-1 Bleed 2 on hero 3, then source-2 self-Block 4")
	_check(events.size() == 2, "beat 1 produced exactly two events, no extras")
	_check(events[0].get("enemy_position") == 1 and events[1].get("enemy_position") == 2,
		"the two applied events are in ascending enemy-source order")
	_check(events[0].get("type") == "debuff" and events[0].get("applied") == true
		and events[0].get("target_position") == 3
		and events[0].get("status") == "bleed",
		"the scavenger's applied event names hero position 3 and Bleed")
	_check(events[1].get("type") == "block" and events[1].get("applied") == true
		and not events[1].has("target_position"),
		"the guard's applied event is a targetless self-Block")
	_check(input_intents == input_copy, "the executed phase leaves caller intents untouched")

	# Whole party snapshot: only Tinker's Bleed was added; no HP changed.
	var expected_party: Array = opened.duplicate(true)
	expected_party[2]["statuses"] = {"bleed": 2}
	_check(party.get_heroes() == expected_party,
		"only Tinker gains Bleed 2; every other hero field is unchanged")
	_check_hero(party, 1, "warden", 40, 6, {}, "phase 1")
	_check_hero(party, 2, "seamstress", 30, 0, {}, "phase 1")
	_check_hero(party, 3, "tinker", 26, 0, {"bleed": 2}, "phase 1")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(2).get("hp") == 30
		and party.get_hero(3).get("hp") == 26,
		"the enemy phase itself removes no hero HP")
	_check(party.get_hero(3).get("block") == 0,
		"the rear Tinker still holds zero Block after the debuff/Block beat")

	# Whole enemy snapshot: only the guard gained exactly 4 Block.
	var expected_enemies: Array = before_enemies.duplicate(true)
	expected_enemies[1]["block"] = 4
	_check(enemies.get_enemies() == expected_enemies,
		"only Button Guard gains exactly 4 Block; both enemy HPs are unchanged")
	_check_enemy(enemies, 1, "fray_scavenger", 14, 0, "phase 1")
	_check_enemy(enemies, 2, "button_guard", 16, 4, "phase 1")
	_check(enemies.get_enemy(1).get("statuses", {}) == {},
		"the scavenger itself carries no status")

	# The isolated phase keeps the first announcement until the caller advances.
	_check(scheduler._turn_index == 0 and scheduler.get_intents() == _first_intents(),
		"the phase does not advance or mutate the first announcement")
	_check(scheduler.get_intents() == _first_intents(),
		"the first announcement stays stable across repeated queries after the phase")


## AC2: the independent hero-owner tick, not the phase, is what turns Bleed into
## HP loss: Tinker 26 -> 24 with Bleed 2 -> 1, then 24 -> 23 with Bleed expired.
func _test_owner_turn_ticks() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	_check(CombatStartingBlock.new(party).apply(), "owner-tick fixture applies opening Block")
	var scheduler := CombatEnemyIntents.new(_parsed())
	var first := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(first.get("ok") == true and first.get("events") == _first_events(),
		"owner-tick fixture begins with the authored first beat")
	var party_before: Array = party.get_heroes()
	var enemies_before: Array = enemies.get_enemies()
	var batch := CombatStatusTurnBatch.new()

	var tick_one := batch.tick_side("heroes", party.get_heroes())
	_check(tick_one.get("ok") == true and tick_one.get("actors", []).size() == 3
		and tick_one.get("events", []).size() == 3,
		"the independent hero-owner tick accepts all three slots")
	var expected_one: Array = party_before.duplicate(true)
	# The owner tick always publishes an explicit statuses dictionary per actor.
	for hero in expected_one:
		hero["statuses"] = hero.get("statuses", {})
	expected_one[2]["hp"] = 24
	expected_one[2]["statuses"] = {"bleed": 1}
	_check(tick_one.get("actors") == expected_one,
		"first owner tick is Tinker 26 -> 24 HP with Bleed 2 -> 1 only (got %s)"
			% str(tick_one.get("actors")))
	_check(tick_one.get("events") == [
		{"side": "heroes", "position": 1, "id": "warden", "bleed_hp_loss": 0},
		{"side": "heroes", "position": 2, "id": "seamstress", "bleed_hp_loss": 0},
		{"side": "heroes", "position": 3, "id": "tinker", "bleed_hp_loss": 2}],
		"first owner tick reports 2 Bleed HP loss on Tinker in position order")

	var tick_two := batch.tick_side("heroes", tick_one.get("actors", []))
	var expected_two: Array = expected_one.duplicate(true)
	expected_two[2]["hp"] = 23
	expected_two[2]["statuses"] = {}
	_check(tick_two.get("ok") == true and tick_two.get("actors") == expected_two,
		"second owner tick is Tinker 24 -> 23 HP with Bleed expired")
	_check(tick_two.get("events") == [
		{"side": "heroes", "position": 1, "id": "warden", "bleed_hp_loss": 0},
		{"side": "heroes", "position": 2, "id": "seamstress", "bleed_hp_loss": 0},
		{"side": "heroes", "position": 3, "id": "tinker", "bleed_hp_loss": 1}],
		"second owner tick reports 1 Bleed HP loss on Tinker")
	_check(party.get_heroes() == party_before,
		"neither owner tick writes to the real CombatParty")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6
		and party.get_hero(2).get("hp") == 30,
		"neither owner tick alters Warden or Seamstress")
	_check(enemies.get_enemies() == enemies_before,
		"owner ticks do not alter the enemy roster")
	_check(scheduler._turn_index == 0 and scheduler.get_intents() == _first_intents(),
		"owner ticks do not advance the intent cycle")

	# Bleed is direct HP loss: a real Block on Tinker neither absorbs nor changes.
	var blocked_party := _build_party()
	var blocked_enemies := _build_enemies()
	_check(CombatStartingBlock.new(blocked_party).apply(),
		"blocked-tick fixture applies opening Block")
	var blocked_scheduler := CombatEnemyIntents.new(_parsed())
	_check(phase.execute_phase(blocked_party, blocked_enemies,
		blocked_scheduler.get_intents()).get("ok") == true,
		"blocked-tick fixture executes the authored first beat")
	_check(blocked_party.gain_block(3, 5),
		"precondition: Tinker holds real Block before her owner turn")
	var blocked_before: Array = blocked_party.get_heroes()
	var blocked_tick := batch.tick_side("heroes", blocked_party.get_heroes())
	var blocked_expected: Array = blocked_before.duplicate(true)
	for hero in blocked_expected:
		hero["statuses"] = hero.get("statuses", {})
	blocked_expected[2]["hp"] = 24
	blocked_expected[2]["statuses"] = {"bleed": 1}
	_check(blocked_tick.get("actors") == blocked_expected,
		"Bleed 2 removes 2 HP from shielded Tinker without touching her Block")
	_check(blocked_tick.get("actors", [])[2].get("block") == 5,
		"the Bleed tick keeps Tinker's 5 Block intact")
	_check(blocked_party.get_heroes() == blocked_before,
		"the blocked tick proposal does not write authoritative HP")


## AC2/AC3: separate fresh beat-2 and beat-3 fixtures resolve through the real
## phase, proving Block-before-HP attacks and the supported self-Buff intent.
func _beat_fixture(beat_index: int) -> Dictionary:
	var party := _build_party()
	var enemies := _build_enemies()
	var opening := CombatStartingBlock.new(party)
	var opening_applied := opening.apply()
	var scheduler := CombatEnemyIntents.new(_parsed())
	for index in range(beat_index):
		scheduler.advance_turn()
	var announced: Array = scheduler.get_intents()
	var result := phase.execute_phase(party, enemies, scheduler.get_intents())
	return {
		"opening": opening_applied,
		"announced": announced,
		"result": result,
		"heroes": party.get_heroes(),
		"enemies": enemies.get_enemies(),
		"next_announcement": scheduler.get_intents(),
		"turn_index": scheduler._turn_index,
	}


func _test_fresh_beat_fixtures() -> void:
	var beat_two := _beat_fixture(1)
	_check(beat_two.get("opening") == true, "beat-2 fixture applies the opening Block")
	_check(beat_two.get("announced") == _second_intents(),
		"beat 2 announces the rear-3 and front-2 attacks in source order")
	_check(beat_two.get("result") == {"ok": true, "events": _second_events()},
		"beat 2 resolves exactly two ordered applied attack events")
	var heroes_two: Array = beat_two.get("heroes", [])
	_check(heroes_two.size() == 3
		and heroes_two[0].get("id") == "warden" and heroes_two[0].get("hp") == 40
		and heroes_two[0].get("block") == 4
		and heroes_two[1].get("id") == "seamstress" and heroes_two[1].get("hp") == 30
		and heroes_two[1].get("block") == 0
		and heroes_two[2].get("id") == "tinker" and heroes_two[2].get("hp") == 23
		and heroes_two[2].get("block") == 0
		and heroes_two[2].get("statuses", {}) == {},
		"beat 2: Warden's 6 Block absorbs the 2-damage hit (40 HP, 4 Block left) and Tinker falls to 23 HP")
	var enemies_two: Array = beat_two.get("enemies", [])
	_check(enemies_two.size() == 2
		and enemies_two[0].get("id") == "fray_scavenger" and enemies_two[0].get("hp") == 14
		and enemies_two[0].get("block") == 0
		and enemies_two[1].get("id") == "button_guard" and enemies_two[1].get("hp") == 16
		and enemies_two[1].get("block") == 0,
		"beat 2 leaves both enemy records unchanged")
	_check(beat_two.get("next_announcement") == _second_intents()
		and beat_two.get("turn_index") == 1,
		"beat 2 does not advance itself")

	var beat_three := _beat_fixture(2)
	_check(beat_three.get("opening") == true, "beat-3 fixture applies the opening Block")
	_check(beat_three.get("announced") == _third_intents(),
		"beat 3 announces the middle-2 attack and the guard self-Buff 2")
	_check(beat_three.get("result") == {"ok": true, "events": _third_events()},
		"beat 3 resolves the attack and the supported self-Buff event")
	var heroes_three: Array = beat_three.get("heroes", [])
	_check(heroes_three.size() == 3
		and heroes_three[0].get("id") == "warden" and heroes_three[0].get("hp") == 40
		and heroes_three[0].get("block") == 6
		and heroes_three[1].get("id") == "seamstress" and heroes_three[1].get("hp") == 28
		and heroes_three[1].get("block") == 0
		and heroes_three[2].get("id") == "tinker" and heroes_three[2].get("hp") == 26
		and heroes_three[2].get("block") == 0,
		"beat 3: Seamstress falls to 28 HP while Warden and Tinker keep their HP")
	var enemies_three: Array = beat_three.get("enemies", [])
	_check(enemies_three.size() == 2
		and enemies_three[0].get("id") == "fray_scavenger" and enemies_three[0].get("hp") == 14
		and enemies_three[0].get("block") == 0
		and enemies_three[1].get("id") == "button_guard" and enemies_three[1].get("hp") == 16
		and enemies_three[1].get("block") == 2,
		"beat 3: the self-Buff grants exactly 2 Block to Button Guard")
	_check(beat_three.get("next_announcement") == _third_intents()
		and beat_three.get("turn_index") == 2,
		"beat 3 does not advance itself")


## AC3: two freshly constructed fixtures with independent seeded RNGs agree on
## every event, snapshot, next announcement and RNG state, and reproduce the
## literal end state so two equally broken runs cannot satisfy the comparison.
func _first_phase_fixture() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261021
	var rng_before := rng.state
	var party := _build_party()
	var enemies := _build_enemies()
	var opening_applied := CombatStartingBlock.new(party).apply()
	var scheduler := CombatEnemyIntents.new(_parsed())
	var announced: Array = scheduler.get_intents()
	var result := phase.execute_phase(party, enemies, scheduler.get_intents())
	return {
		"opening": opening_applied,
		"announced": announced,
		"result": result,
		"heroes": party.get_heroes(),
		"enemies": enemies.get_enemies(),
		"next_announcement": scheduler.get_intents(),
		"turn_index": scheduler._turn_index,
		"rng_before": rng_before,
		"rng_after": rng.state,
	}


func _test_double_fixture_replay() -> void:
	seed(20261021)
	var expected_global := randi()
	seed(20261021)
	var first := _first_phase_fixture()
	_check(randi() == expected_global, "a real authored first phase draws no global RNG")
	var second := _first_phase_fixture()

	# Literal end state, so two equally broken runs cannot agree vacuously.
	_check(first.get("opening") == true and second.get("opening") == true,
		"both fixtures applied the Warden opening Block exactly once")
	_check(first.get("announced") == _first_intents()
		and second.get("announced") == _first_intents(),
		"both fixtures announced the identical authored first beats")
	var heroes: Array = first.get("heroes", [])
	_check(heroes.size() == 3
		and heroes[0].get("id") == "warden" and heroes[0].get("hp") == 40
		and heroes[0].get("block") == 6 and heroes[0].get("statuses", {}) == {}
		and heroes[1].get("id") == "seamstress" and heroes[1].get("hp") == 30
		and heroes[1].get("block") == 0 and heroes[1].get("statuses", {}) == {}
		and heroes[2].get("id") == "tinker" and heroes[2].get("hp") == 26
		and heroes[2].get("block") == 0 and heroes[2].get("statuses", {}) == {"bleed": 2},
		"replay end state is Warden 40/6, Seamstress 30/0, Tinker 26/0 with Bleed 2")
	var foes: Array = first.get("enemies", [])
	_check(foes.size() == 2
		and foes[0].get("id") == "fray_scavenger" and foes[0].get("hp") == 14
		and foes[0].get("block") == 0
		and foes[1].get("id") == "button_guard" and foes[1].get("hp") == 16
		and foes[1].get("block") == 4,
		"replay end state is Fray Scavenger 14/0, Button Guard 16/4")
	_check(first.get("result") == second.get("result")
		and first.get("result", {}).get("events") == _first_events(),
		"two independently constructed fixtures produce identical phase events")
	_check(first.get("heroes") == second.get("heroes")
		and first.get("enemies") == second.get("enemies"),
		"two independently constructed fixtures end in identical actor state")
	_check(first.get("next_announcement") == second.get("next_announcement")
		and first.get("next_announcement") == _first_intents()
		and first.get("turn_index") == 0 and second.get("turn_index") == 0,
		"both schedulers keep the unadvanced first-beat announcement")
	_check(first.get("rng_before") == second.get("rng_before")
		and first.get("rng_after") == second.get("rng_after"),
		"both independent seeded RNGs reach identical states")
	_check(first.get("rng_before") == first.get("rng_after"),
		"the fixture's own seeded RNG state is untouched by the phase")


## AC3: a slain scavenger skips only its own debuff; the living guard still
## gains four Block and no hero is bled.
func _test_slain_source_skips_debuff() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	_check(CombatStartingBlock.new(party).apply(),
		"slain-source fixture applies opening Block")
	_check(enemies.apply_damage(1, 14) and enemies.is_slain(1)
		and not enemies.is_slain(2),
		"negative: Fray Scavenger is really slain and Button Guard stays alive")
	var dead_before: Dictionary = enemies.get_enemy(1)
	var party_before: Array = party.get_heroes()
	var scheduler := CombatEnemyIntents.new(_parsed())
	var intents: Array = scheduler.get_intents()
	_check(intents == _first_intents(), "slain-source fixture announces the authored first beats")
	var result := phase.execute_phase(party, enemies, intents)
	_check(result == {"ok": true, "events": [
		{"type": "debuff", "enemy_position": 1, "applied": false,
			"target_position": 3, "status": "bleed"},
		{"type": "block", "enemy_position": 2, "applied": true}]},
		"negative: the slain source's debuff is unapplied; the living guard still gains 4 Block")
	_check(party.get_heroes() == party_before,
		"negative: the slain scavenger inflicts no Bleed on any hero")
	_check(party.get_hero(3).get("statuses", {}) == {} and party.get_hero(3).get("hp") == 26,
		"negative: Tinker stays at 26 HP with no status")
	_check(enemies.get_enemy(1) == dead_before,
		"negative: the slain source stays at its original slot with unchanged HP/Block")
	_check_enemy(enemies, 2, "button_guard", 16, 4, "slain source")
	_check(scheduler._turn_index == 0 and scheduler.get_intents() == _first_intents(),
		"negative: the phase leaves the announcement cycle untouched")


## AC3: a downed Bleed target rejects the complete phase with no guard Block,
## no actor mutation, no turn advance and no RNG consumption.
func _test_downed_bleed_target_rejects_phase() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	_check(CombatStartingBlock.new(party).apply(),
		"downed-target fixture applies opening Block")
	_check(party.apply_damage(3, 26) and party.is_downed(3)
		and party.get_hero(3).get("hp") == 0,
		"negative: real party damage downs Tinker at position 3 before beat 1")
	var party_before: Array = party.get_heroes()
	var enemies_before: Array = enemies.get_enemies()
	var scheduler := CombatEnemyIntents.new(_parsed())
	var intents: Array = scheduler.get_intents()
	var intents_before: Array = intents.duplicate(true)
	_check(intents == _first_intents(),
		"negative: beat 1 still announces Bleed 2 onto the downed hero slot")
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
	_check(party.is_downed(3) and party.get_hero(3).get("id") == "tinker",
		"negative: downed Tinker stays in her slot, unbled and unrevived")
	_check(party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6,
		"negative: the Warden's opening Block is unchanged by rejection")
	_check(enemies.get_enemies() == enemies_before,
		"negative: the rejected phase grants the living guard no Block")
	_check_enemy(enemies, 2, "button_guard", 16, 0, "downed target")
	_check(intents == intents_before and scheduler.get_intents() == _first_intents()
		and scheduler._turn_index == 0,
		"negative: the rejected phase leaves caller intents and announcements untouched")

	# Localized control: with a living rear hero the same phase succeeds even
	# when a non-target hero is downed, proving the rejection came from Tinker.
	var control_party := _build_party()
	var control_enemies := _build_enemies()
	_check(control_party.apply_damage(1, 40) and control_party.is_downed(1),
		"control: real party damage downs the Warden, not the Bleed target")
	var control := phase.execute_phase(control_party, control_enemies,
		CombatEnemyIntents.new(_parsed()).get_intents())
	_check(control == {"ok": true, "events": _first_events()},
		"control: the same beats resolve when the downed hero is not the Bleed target")
	_check(control_party.get_hero(3).get("statuses") == {"bleed": 2}
		and control_enemies.get_enemy(2).get("block") == 4,
		"control: Tinker still receives Bleed 2 and the guard still gains 4 Block")
	_check(control_party.get_hero(1).get("hp") == 0,
		"control: the already downed Warden stays downed")


## Deep copy of the prescription with one beat replaced in place.
func _with_beat(position: int, beat: int, replacement: Dictionary) -> Array:
	var data: Array = _expected().duplicate(true)
	for entry in data:
		if entry["enemy_position"] == position:
			var pattern: Array = entry["pattern"]
			pattern[beat] = replacement
	return data


## AC3: malformed schedules fail closed in the canonical parser and in
## CombatEnemyIntents, each judged independently and without mutating input.
func _test_parser_rejections() -> void:
	var pristine := _read_text(ENCOUNTER_PATH)
	var duplicate := _expected().duplicate(true)
	duplicate[1]["enemy_position"] = 1
	var off_board := _with_beat(1, 1, {"type": "attack", "amount": 3,
		"target_position": 4})
	var negative_amount := _with_beat(1, 2, {"type": "attack", "amount": -1,
		"target_position": 2})
	var cases: Array = [
		{"label": "duplicate enemy_position records", "data": duplicate,
			"control": _expected()},
		{"label": "out-of-range target_position 4", "data": off_board,
			"control": _with_beat(1, 1, {"type": "attack", "amount": 3,
				"target_position": 3})},
		{"label": "negative attack amount -1", "data": negative_amount,
			"control": _with_beat(1, 2, {"type": "attack", "amount": 2,
				"target_position": 2})},
	]
	for entry_case in cases:
		var data: Array = entry_case["data"]
		var untouched: Array = data.duplicate(true)
		_check(data != _expected(),
			"negative: %s really differs from the authored schedule" % entry_case["label"])
		_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(data)).is_empty(),
			"negative: %s is rejected by the canonical parser" % entry_case["label"])
		_check(data == untouched,
			"negative: %s leaves its parsed input data untouched" % entry_case["label"])
		var intents := CombatEnemyIntents.new(data)
		_check(not intents.is_valid(),
			"negative: %s is rejected by CombatEnemyIntents" % entry_case["label"])
		_check(data == untouched,
			"negative: %s leaves the directly submitted definitions untouched"
				% entry_case["label"])
		# Control: the same data with ONLY the offending field restored parses and validates.
		var control: Array = entry_case["control"]
		_check(control != data,
			"control: %s control fixture really differs from the rejected data"
				% entry_case["label"])
		_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(control)) == control,
			"control: %s with only the offending field restored parses exactly"
				% entry_case["label"])
		_check(CombatEnemyIntents.new(control).is_valid(),
			"control: %s with only the offending field restored validates"
				% entry_case["label"])
	for broken_text in ["{", "{bad", "not json", "{}", "[]"]:
		_check(RunFightEncounterSelection._parse_schedule_text(broken_text).is_empty(),
			"negative: malformed/empty schedule text %s is rejected" % broken_text)
	# Controls, so the rejections above cannot pass vacuously.
	_check(_parsed() == _expected(),
		"negative controls: the unmodified authored file still parses exactly")
	_check(CombatEnemyIntents.new(_expected()).is_valid(),
		"negative controls: the unmodified authored schedule still validates")
	_check(_read_text(ENCOUNTER_PATH) == pristine,
		"negative controls: malformed local copies never alter the authored file")
