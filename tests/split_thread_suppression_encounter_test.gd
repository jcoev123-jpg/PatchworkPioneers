extends SceneTree

## Deterministic headless coverage for the authored Split-Thread Suppression encounter:
## slot 1 Seam Ripper inflicts Weak 2 on the REAR Tinker, then a base-3 attack on
## her, then gains 2 self-Block; slot 2 Fray Scavenger attacks the FRONT Warden,
## inflicts Bleed 2 on him, then attacks the MIDDLE Seamstress. The schedule is data
## only: this file never wires the encounter into live play, and no typed-pool or
## registry file is read or written here.

const ENCOUNTER_PATH := "res://data/encounters/split_thread_suppression.json"
const ENCOUNTER_ID := "split_thread_suppression"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMY_PATH := "res://data/enemies/run_enemies.json"
const STARTER_PATH := "res://data/encounters/starter_attacks.json"
const FRAYGUARD_PATH := "res://data/encounters/frayguard_attrition.json"
const HERO_IDS := ["warden", "seamstress", "tinker"]
# Encounter slot order: 1 Seam Ripper, 2 Fray Scavenger.
const ENEMY_SLOTS := [
	{"id": "seam_ripper", "name": "Seam Ripper", "max_hp": 18},
	{"id": "fray_scavenger", "name": "Fray Scavenger", "max_hp": 14},
]

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_authored_schedule_and_catalog()
	_test_companion_schedules_still_valid()
	_test_intent_cycle()
	_test_three_phase_real_execution()
	_test_double_fixture_replay()
	_test_downed_target_rejects_phase()
	_test_invalid_source_rejects_phase()
	_test_parser_rejections()
	if failures.is_empty():
		print("split_thread_suppression_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("split_thread_suppression_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## The exact prescribed schedule for this encounter's own two sources.
func _expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "debuff", "amount": 2, "target_position": 3, "status": "weak"},
			{"type": "attack", "amount": 3, "target_position": 3},
			{"type": "buff", "amount": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 2, "target_position": 1},
			{"type": "debuff", "amount": 2, "target_position": 1, "status": "bleed"},
			{"type": "attack", "amount": 2, "target_position": 2}]},
	]


## Literal announced beats, independent of the parsed file and of _expected().
func _first_intents() -> Array:
	return [
		{"type": "debuff", "amount": 2, "target_position": 3, "status": "weak",
			"enemy_position": 1},
		{"type": "attack", "amount": 2, "target_position": 1, "enemy_position": 2}]


func _second_intents() -> Array:
	return [
		{"type": "attack", "amount": 3, "target_position": 3, "enemy_position": 1},
		{"type": "debuff", "amount": 2, "target_position": 1, "status": "bleed",
			"enemy_position": 2}]


func _third_intents() -> Array:
	return [
		{"type": "buff", "amount": 2, "enemy_position": 1},
		{"type": "attack", "amount": 2, "target_position": 2, "enemy_position": 2}]


## Literal resolution events through the real phase services.
func _first_events() -> Array:
	return [
		{"type": "debuff", "enemy_position": 1, "applied": true,
			"target_position": 3, "status": "weak"},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 1}]


func _second_events() -> Array:
	return [
		{"type": "attack", "enemy_position": 1, "applied": true, "target_position": 3},
		{"type": "debuff", "enemy_position": 2, "applied": true, "target_position": 1,
			"status": "bleed"}]


func _third_events() -> Array:
	return [
		{"type": "buff", "enemy_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 2}]


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
	for slot in ENEMY_SLOTS:
		definitions.append(_record(records, slot["id"], "authored enemy"))
	return CombatEnemies.new(definitions)


## Mirror the real owner-turn commit in combat_round_flow.gd: run the real
## CombatStatusTurnBatch proposal over the party snapshot, then copy only the
## owner-tick fields (hp/block/statuses) back into the authoritative records.
func _apply_owner_tick(party: CombatParty) -> Dictionary:
	var batch := CombatStatusTurnBatch.new()
	var tick := batch.tick_side("heroes", party.get_heroes())
	if not tick["ok"]:
		return tick
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = party._heroes[index]
		var next: Dictionary = tick["actors"][index]
		hero["hp"] = next["hp"]
		hero["block"] = next["block"]
		if hero.has("statuses") or not next["statuses"].is_empty():
			hero["statuses"] = next["statuses"]
	return tick


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
		"target_position": 3, "status": "weak"},
		"the Seam Ripper's first beat is the authored Weak 2 on hero position 3")
	_check(parsed[1]["pattern"][1] == {"type": "debuff", "amount": 2,
		"target_position": 1, "status": "bleed"},
		"the Fray Scavenger's second beat is the authored Bleed 2 on hero position 1")
	_check(parsed[0]["pattern"][2] == {"type": "buff", "amount": 2},
		"the Seam Ripper's third beat is the authored self-Block 2")
	_check(CombatEnemyIntents.new(_expected()).is_valid(),
		"the literal prescription itself validates")
	_check(_read_text(ENCOUNTER_PATH) == raw,
		"the authored file bytes stay unchanged after validation")

	# The named actors really exist, exactly once each, with the stats this
	# schedule is authored against; slot order is 1 Seam Ripper, 2 Fray Scavenger.
	var enemy_records := _load_records(ENEMY_PATH)
	for slot in ENEMY_SLOTS:
		var record := _record(enemy_records, slot["id"], "authored enemy")
		_check(record.get("name") == slot["name"] and record.get("max_hp") == slot["max_hp"]
			and record.get("max_hp") is int,
			"shipped %s is %s with %d integer max HP"
				% [slot["id"], slot["name"], slot["max_hp"]])
		_check(record.get("art_path") is String
			and not record.get("art_path", "").is_empty(),
			"shipped enemy %s keeps its art path for later real art" % slot["id"])

	var enemies := _build_enemies()
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2,
		"authored two-enemy roster is valid")
	var roster_ids: Array = []
	for enemy in enemies.get_enemies():
		roster_ids.append(enemy.get("id"))
	_check(roster_ids == [ENEMY_SLOTS[0]["id"], ENEMY_SLOTS[1]["id"]],
		"the constructed roster is exactly the two catalog records in this order")
	_check_enemy(enemies, 1, "seam_ripper", 18, 0, "start")
	_check_enemy(enemies, 2, "fray_scavenger", 14, 0, "start")
	_check(enemies.get_enemy(1).get("name") == "Seam Ripper"
		and enemies.get_enemy(1).get("position") == 1,
		"Seam Ripper keeps its name in enemy slot 1")
	_check(enemies.get_enemy(2).get("name") == "Fray Scavenger"
		and enemies.get_enemy(2).get("position") == 2,
		"Fray Scavenger keeps its name in enemy slot 2")

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

	# Returned snapshots are defensive copies: mutating them cannot reach the rules.
	var hero_snapshot: Array = party.get_heroes()
	hero_snapshot[0]["hp"] = 1
	hero_snapshot[2]["statuses"] = {"bleed": 99}
	_check(party.get_hero(1).get("hp") == 40
		and party.get_hero(3).get("statuses", {}) == {},
		"mutating a returned party snapshot cannot alter the live party")
	var enemy_snapshot: Array = enemies.get_enemies()
	enemy_snapshot[0]["block"] = 42
	_check(enemies.get_enemy(1).get("block") == 0,
		"mutating a returned enemy snapshot cannot alter the live roster")


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

	# An independently constructed selector cannot read a mutated parsed source.
	var isolated := CombatEnemyIntents.new(definitions)
	var parsed_pattern: Array = definitions[0]["pattern"]
	parsed_pattern[0]["amount"] = 7
	_check(isolated.get_intents() == _first_intents(),
		"mutating the parsed source cannot alter an independently constructed intent selector")


## AC2: three successive real enemy phases resolve against the real party and
## roster, with real owner-turn ticks between them. The opening Block absorbs the
## first Warden hit, Weak lands on Tinker, Bleed lands on Warden, and the third
## beat grants Seam Ripper 2 Block while Seamstress falls to 28 HP.
func _test_three_phase_real_execution() -> void:
	var party := _build_party()
	_check(party.is_valid(), "authored party is valid")
	var enemies := _build_enemies()
	_check(enemies.is_valid(), "authored two-enemy roster is valid")
	_check_enemy(enemies, 1, "seam_ripper", 18, 0, "start")
	_check_enemy(enemies, 2, "fray_scavenger", 14, 0, "start")
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
		"beat 1 announces Weak 2 on Tinker, then the front-line 2 attack")
	var input_intents: Array = scheduler.get_intents()
	var input_copy: Array = input_intents.duplicate(true)
	var before_enemies: Array = enemies.get_enemies()
	seed(20261021)
	var expected_global := randi()
	seed(20261021)
	var result1 := phase.execute_phase(party, enemies, input_intents)
	_check(randi() == expected_global, "the real three-beat timeline draws no global RNG")
	_check(result1.get("ok") == true, "beat 1 succeeds")
	var events1: Array = result1.get("events", [])
	_check(events1 == _first_events(),
		"beat 1 events: slot-1 Weak 2 on hero 3, then slot-2 attack on hero 1")
	_check(events1.size() == 2, "beat 1 produced exactly two events, no extras")
	_check(events1[0].get("enemy_position") == 1 and events1[1].get("enemy_position") == 2,
		"the two applied events are in ascending enemy-source order")
	_check(events1[0].get("type") == "debuff" and events1[0].get("applied") == true
		and events1[0].get("target_position") == 3
		and events1[0].get("status") == "weak",
		"the Seam Ripper's applied event names hero position 3 and Weak")
	_check(events1[1].get("type") == "attack" and events1[1].get("applied") == true
		and events1[1].get("target_position") == 1,
		"the Fray Scavenger's applied event attacks hero position 1")
	_check(input_intents == input_copy, "the executed phase leaves caller intents untouched")

	# Whole party snapshot: only Tinker's Weak was added; Warden's Block absorbed the hit.
	var expected_party: Array = opened.duplicate(true)
	expected_party[0]["block"] = 4
	expected_party[2]["statuses"] = {"weak": 2}
	_check(party.get_heroes() == expected_party,
		"only the opening Block and Tinker's Weak 2 changed; every other field is unchanged")
	_check_hero(party, 1, "warden", 40, 4, {}, "phase 1")
	_check_hero(party, 2, "seamstress", 30, 0, {}, "phase 1")
	_check_hero(party, 3, "tinker", 26, 0, {"weak": 2}, "phase 1")
	_check(party.get_hero(1).get("hp") == 40,
		"the first 2-damage hit is fully absorbed by Warden's Block before any HP loss")
	var expected_enemies: Array = before_enemies.duplicate(true)
	_check(enemies.get_enemies() == expected_enemies,
		"beat 1 leaves both enemy records unchanged")
	_check_enemy(enemies, 1, "seam_ripper", 18, 0, "phase 1")
	_check_enemy(enemies, 2, "fray_scavenger", 14, 0, "phase 1")
	_check(scheduler._turn_index == 0 and scheduler.get_intents() == _first_intents(),
		"beat 1 does not advance the intent cycle")

	# Owner turn 1 ends: Tinker's Weak 2 ages to 1, no Bleed exists yet.
	var tick1 := _apply_owner_tick(party)
	_check(tick1.get("ok") == true and tick1.get("actors", []).size() == 3
		and tick1.get("events", []).size() == 3,
		"the owner tick proposes exactly three hero actors")
	_check(tick1.get("events") == [
		{"side": "heroes", "position": 1, "id": "warden", "bleed_hp_loss": 0},
		{"side": "heroes", "position": 2, "id": "seamstress", "bleed_hp_loss": 0},
		{"side": "heroes", "position": 3, "id": "tinker", "bleed_hp_loss": 0}],
		"owner turn 1 reports no Bleed loss")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 4,
		"owner turn 1 leaves Warden's HP and Block untouched")
	_check(party.get_hero(3).get("statuses", {}) == {"weak": 1},
		"Tinker's Weak 2 ages to 1 at the owner-turn boundary")

	scheduler.advance_turn()
	_check(scheduler.get_intents() == _second_intents(),
		"beat 2 announces the 3-damage rear attack and Bleed 2 on Warden")
	var result2 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(result2.get("ok") == true and result2.get("events") == _second_events(),
		"beat 2 resolves the attack and the Bleed debuff in source order")
	_check_hero(party, 1, "warden", 40, 4, {"bleed": 2}, "phase 2")
	_check_hero(party, 2, "seamstress", 30, 0, {}, "phase 2")
	_check_hero(party, 3, "tinker", 23, 0, {"weak": 1}, "phase 2")
	_check(enemies.get_enemies() == before_enemies, "beat 2 leaves both enemy records unchanged")
	_check_enemy(enemies, 1, "seam_ripper", 18, 0, "phase 2")
	_check_enemy(enemies, 2, "fray_scavenger", 14, 0, "phase 2")

	# Owner turn 2 ends: Warden's Bleed 2 loses 2 HP through Block and becomes 1;
	# Tinker's Weak 1 expires.
	var tick2 := _apply_owner_tick(party)
	_check(tick2.get("ok") == true, "owner turn 2 tick succeeds")
	_check(tick2.get("events") == [
		{"side": "heroes", "position": 1, "id": "warden", "bleed_hp_loss": 2},
		{"side": "heroes", "position": 2, "id": "seamstress", "bleed_hp_loss": 0},
		{"side": "heroes", "position": 3, "id": "tinker", "bleed_hp_loss": 0}],
		"owner turn 2 reports 2 Bleed loss on Warden")
	_check(party.get_hero(1).get("hp") == 38 and party.get_hero(1).get("block") == 4
		and party.get_hero(1).get("statuses", {}) == {"bleed": 1},
		"Warden loses 2 HP to Bleed through his 4 Block, which stays intact")
	_check(party.get_hero(3).get("statuses", {}) == {},
		"Tinker's Weak 1 expires at the owner-turn boundary")
	_check(party.get_hero(2).get("hp") == 30 and party.get_hero(2).get("block") == 0,
		"owner turn 2 leaves Seamstress untouched")

	scheduler.advance_turn()
	_check(scheduler.get_intents() == _third_intents(),
		"beat 3 announces the Seam Ripper self-Buff 2 and the Seamstress attack")
	var result3 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(result3.get("ok") == true and result3.get("events") == _third_events(),
		"beat 3 resolves the self-Buff and the Seamstress attack in source order")
	_check_hero(party, 1, "warden", 38, 4, {"bleed": 1}, "phase 3")
	_check_hero(party, 2, "seamstress", 28, 0, {}, "phase 3")
	_check_hero(party, 3, "tinker", 23, 0, {}, "phase 3")
	_check_enemy(enemies, 1, "seam_ripper", 18, 2, "phase 3")
	_check_enemy(enemies, 2, "fray_scavenger", 14, 0, "phase 3")
	_check(enemies.get_enemy(1).get("statuses", {}) == {},
		"the Seam Ripper itself carries no status after its self-Buff")
	scheduler.advance_turn()
	_check(scheduler.get_intents() == _first_intents(),
		"a fourth advance wraps the cycle back to the first beats exactly")


## AC3: two freshly constructed fixtures with independent seeded RNGs agree on
## every announcement, event, tick, snapshot and RNG state, and reproduce the
## literal end state so two equally broken runs cannot satisfy the comparison.
func _timeline_fixture() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261021
	var rng_before := rng.state
	var party := _build_party()
	var enemies := _build_enemies()
	var opening_applied := CombatStartingBlock.new(party).apply()
	var scheduler := CombatEnemyIntents.new(_parsed())
	var announced1: Array = scheduler.get_intents()
	var result1 := phase.execute_phase(party, enemies, announced1)
	var tick1 := _apply_owner_tick(party)
	scheduler.advance_turn()
	var announced2: Array = scheduler.get_intents()
	var result2 := phase.execute_phase(party, enemies, announced2)
	var tick2 := _apply_owner_tick(party)
	scheduler.advance_turn()
	var announced3: Array = scheduler.get_intents()
	var result3 := phase.execute_phase(party, enemies, announced3)
	scheduler.advance_turn()
	return {
		"opening": opening_applied,
		"announced": [announced1, announced2, announced3],
		"results": [result1, result2, result3],
		"ticks": [tick1, tick2],
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
	var first := _timeline_fixture()
	_check(randi() == expected_global, "a real full timeline draws no global RNG")
	var second := _timeline_fixture()

	# Literal end state, so two equally broken runs cannot agree vacuously.
	_check(first.get("opening") == true and second.get("opening") == true,
		"both fixtures applied the Warden opening Block exactly once")
	var heroes: Array = first.get("heroes", [])
	_check(heroes.size() == 3
		and heroes[0].get("id") == "warden" and heroes[0].get("hp") == 38
		and heroes[0].get("block") == 4 and heroes[0].get("statuses", {}) == {"bleed": 1}
		and heroes[1].get("id") == "seamstress" and heroes[1].get("hp") == 28
		and heroes[1].get("block") == 0 and heroes[1].get("statuses", {}) == {}
		and heroes[2].get("id") == "tinker" and heroes[2].get("hp") == 23
		and heroes[2].get("block") == 0 and heroes[2].get("statuses", {}) == {},
		"replay end state is Warden 38/4 Bleed 1, Seamstress 28/0, Tinker 23/0")
	var foes: Array = first.get("enemies", [])
	_check(foes.size() == 2
		and foes[0].get("id") == "seam_ripper" and foes[0].get("hp") == 18
		and foes[0].get("block") == 2
		and foes[1].get("id") == "fray_scavenger" and foes[1].get("hp") == 14
		and foes[1].get("block") == 0,
		"replay end state is Seam Ripper 18/2, Fray Scavenger 14/0")
	_check(first.get("announced") == [_first_intents(), _second_intents(), _third_intents()]
		and second.get("announced") == first.get("announced"),
		"both fixtures announced the identical authored beats in order")
	_check(first.get("results") == second.get("results")
		and first.get("results", [])[0].get("events") == _first_events()
		and first.get("results", [])[1].get("events") == _second_events()
		and first.get("results", [])[2].get("events") == _third_events(),
		"two independently constructed fixtures produce identical phase events")
	_check(first.get("ticks") == second.get("ticks"),
		"two independently constructed fixtures produce identical owner-turn ticks")
	_check(first.get("heroes") == second.get("heroes")
		and first.get("enemies") == second.get("enemies"),
		"two independently constructed fixtures end in identical actor state")
	_check(first.get("next_announcement") == second.get("next_announcement")
		and first.get("next_announcement") == _first_intents()
		and first.get("turn_index") == 3 and second.get("turn_index") == 3,
		"both schedulers wrap to the first-beat announcement after three advances")
	_check(first.get("rng_before") == second.get("rng_before")
		and first.get("rng_after") == second.get("rng_after"),
		"both independent seeded RNGs reach identical states")
	_check(first.get("rng_before") == first.get("rng_after"),
		"the fixture's own seeded RNG state is untouched by the timeline")


## AC3: a downed Weak target rejects the complete first phase with no committed
## status, no later attack, no turn advance and no RNG consumption.
func _test_downed_target_rejects_phase() -> void:
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
		"negative: beat 1 still announces Weak 2 onto the downed hero slot")
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
		"negative: the downed Weak target rejects the whole first phase")
	_check(party.get_heroes() == party_before,
		"negative: no hero HP, Block, position or status survives the rejected phase")
	_check(party.is_downed(3) and party.get_hero(3).get("id") == "tinker",
		"negative: downed Tinker stays in her slot, unweakened and unrevived")
	_check(party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6,
		"negative: the Warden's opening Block is unchanged by rejection")
	_check(enemies.get_enemies() == enemies_before,
		"negative: the rejected phase leaves the enemy roster untouched")
	_check(intents == intents_before and scheduler.get_intents() == _first_intents()
		and scheduler._turn_index == 0,
		"negative: the rejected phase leaves caller intents and announcements untouched")

	# Localized control: with a living rear hero the same phase succeeds even
	# when an unrelated hero is downed, proving the rejection came from Tinker.
	var control_party := _build_party()
	var control_enemies := _build_enemies()
	_check(CombatStartingBlock.new(control_party).apply(),
		"control: opening Block applies when the Weak target is living")
	_check(control_party.apply_damage(2, 30) and control_party.is_downed(2),
		"control: real party damage downs Seamstress, who is not a beat-1 target")
	var control := phase.execute_phase(control_party, control_enemies,
		CombatEnemyIntents.new(_parsed()).get_intents())
	_check(control == {"ok": true, "events": _first_events()},
		"control: the same beats resolve when the downed hero is not a target")
	_check(control_party.get_hero(3).get("statuses") == {"weak": 2}
		and control_party.get_hero(1).get("block") == 4,
		"control: Tinker still receives Weak 2 and the Warden still absorbs the hit")


## AC3: an invalid source position or a malformed later action fails the whole
## phase closed, rolling back an earlier staged self-Block, with no turn advance
## and no RNG consumption.
func _test_invalid_source_rejects_phase() -> void:
	var cases: Array = [
		{"label": "out-of-range enemy_position 3", "intents": [
			{"type": "debuff", "amount": 2, "target_position": 3, "status": "weak",
				"enemy_position": 3}]},
		{"label": "malformed action on source 1", "intents": [
			{"type": "attack", "amount": 2, "target_position": 4, "enemy_position": 1}]},
	]
	for case in cases:
		var party := _build_party()
		var enemies := _build_enemies()
		_check(CombatStartingBlock.new(party).apply(),
			"negative fixture applies opening Block")
		var party_before: Array = party.get_heroes()
		var enemies_before: Array = enemies.get_enemies()
		var scheduler := CombatEnemyIntents.new(_parsed())
		var intents: Array = case["intents"]
		var intents_before: Array = intents.duplicate(true)
		seed(20261021)
		var expected_global := randi()
		seed(20261021)
		var result := phase.execute_phase(party, enemies, intents)
		_check(randi() == expected_global,
			"negative: %s draws no global RNG" % case["label"])
		_check(result == {"ok": false, "events": []},
			"negative: %s rejects the whole phase" % case["label"])
		_check(party.get_heroes() == party_before and enemies.get_enemies() == enemies_before,
			"negative: %s leaves every actor unchanged" % case["label"])
		_check(intents == intents_before and scheduler._turn_index == 0,
			"negative: %s leaves the intent cycle untouched" % case["label"])

	# A valid staged self-Block from source 1 must also roll back when a later
	# source's action is illegal (the downed Weak target).
	var party := _build_party()
	var enemies := _build_enemies()
	_check(party.apply_damage(3, 26) and party.is_downed(3),
		"negative rollback fixture downs Tinker before the phase")
	var enemies_before: Array = enemies.get_enemies()
	var pair: Array = [
		{"type": "buff", "amount": 2, "enemy_position": 1},
		{"type": "debuff", "amount": 2, "target_position": 3, "status": "weak",
			"enemy_position": 2}]
	var pair_before: Array = pair.duplicate(true)
	var shape1: Dictionary = pair[0].duplicate(true)
	var shape2: Dictionary = pair[1].duplicate(true)
	shape1.erase("enemy_position")
	shape2.erase("enemy_position")
	_check(CombatEnemyIntents.valid_action(shape1)
		and CombatEnemyIntents.valid_action(shape2),
		"negative rollback fixture passes per-action validation")
	var rollback := phase.execute_phase(party, enemies, pair)
	_check(rollback == {"ok": false, "events": []},
		"negative: the downed debuff target fails the whole phase after a valid Block beat")
	_check(enemies.get_enemy(1).get("block") == 0 and enemies.get_enemies() == enemies_before,
		"negative: the earlier staged self-Block rolls back with the rest of the phase")
	_check(pair == pair_before, "negative: the rejected phase leaves caller intents untouched")


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
	var negative_amount := _with_beat(2, 1, {"type": "debuff", "amount": 0,
		"target_position": 1, "status": "bleed"})
	var cases: Array = [
		{"label": "duplicate enemy_position records", "data": duplicate,
			"control": _expected()},
		{"label": "out-of-range target_position 4", "data": off_board,
			"control": _with_beat(1, 1, {"type": "attack", "amount": 3,
				"target_position": 3})},
		{"label": "zero debuff amount 0", "data": negative_amount,
			"control": _with_beat(2, 1, {"type": "debuff", "amount": 2,
				"target_position": 1, "status": "bleed"})},
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
