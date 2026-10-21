extends SceneTree

## Deterministic headless coverage for the authored Knotline Crossfire
## encounter: slot 1 Guard Ragling guards itself, slot 2 Spool Stalker weakens
## the rear Tinker and then hits her, slot 3 Seam Ripper shifts its damage
## among the three heroes. Data/service only: this file never wires the
## encounter into live play, and no typed-pool or registry file is read or
## written here.

const ENCOUNTER_PATH := "res://data/encounters/knotline_crossfire.json"
const ENCOUNTER_ID := "knotline_crossfire"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const STARTER_ENEMY_PATH := "res://data/enemies/starter_enemies.json"
const RUN_ENEMY_PATH := "res://data/enemies/run_enemies.json"
const HERO_IDS := ["warden", "seamstress", "tinker"]
# Encounter slot order: 1 Guard Ragling, 2 Spool Stalker, 3 Seam Ripper.
const ENEMY_IDS := ["ragling_guard", "spool_stalker", "seam_ripper"]

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_authored_schedule_and_catalog()
	_test_intent_cycle()
	_test_three_phase_execution()
	_test_replay_equality()
	_test_illegal_target_rejected()
	_test_downed_debuff_target_rejected()
	_test_slain_source_skips()
	_test_parser_rejections()
	if failures.is_empty():
		print("knotline_crossfire_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("knotline_crossfire_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## The exact prescribed schedule for this encounter's own three sources.
func _expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": 2},
			{"type": "attack", "amount": 2, "target_position": 2},
			{"type": "attack", "amount": 2, "target_position": 1}]},
		{"enemy_position": 2, "pattern": [
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
			{"type": "attack", "amount": 3, "target_position": 3},
			{"type": "block", "amount": 1}]},
		{"enemy_position": 3, "pattern": [
			{"type": "attack", "amount": 3, "target_position": 1},
			{"type": "attack", "amount": 2, "target_position": 2},
			{"type": "attack", "amount": 3, "target_position": 3}]},
	]


## Literal announced beats, independent of the parsed file and of _expected().
func _first_intents() -> Array:
	return [
		{"type": "block", "amount": 2, "enemy_position": 1},
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak",
			"enemy_position": 2},
		{"type": "attack", "amount": 3, "target_position": 1, "enemy_position": 3},
	]


func _second_intents() -> Array:
	return [
		{"type": "attack", "amount": 2, "target_position": 2, "enemy_position": 1},
		{"type": "attack", "amount": 3, "target_position": 3, "enemy_position": 2},
		{"type": "attack", "amount": 2, "target_position": 2, "enemy_position": 3},
	]


func _third_intents() -> Array:
	return [
		{"type": "attack", "amount": 2, "target_position": 1, "enemy_position": 1},
		{"type": "block", "amount": 1, "enemy_position": 2},
		{"type": "attack", "amount": 3, "target_position": 3, "enemy_position": 3},
	]


## Literal resolution of each announced beat through the real phase services.
func _events(beat: int) -> Array:
	match beat:
		0:
			return [
				{"type": "block", "enemy_position": 1, "applied": true},
				{"type": "debuff", "enemy_position": 2, "applied": true,
					"target_position": 3, "status": "weak"},
				{"type": "attack", "enemy_position": 3, "applied": true,
					"target_position": 1},
			]
		1:
			return [
				{"type": "attack", "enemy_position": 1, "applied": true,
					"target_position": 2},
				{"type": "attack", "enemy_position": 2, "applied": true,
					"target_position": 3},
				{"type": "attack", "enemy_position": 3, "applied": true,
					"target_position": 2},
			]
		2:
			return [
				{"type": "attack", "enemy_position": 1, "applied": true,
					"target_position": 1},
				{"type": "block", "enemy_position": 2, "applied": true},
				{"type": "attack", "enemy_position": 3, "applied": true,
					"target_position": 3},
			]
	return []


## The authored ledger after each successive enemy phase. Hero rows are
## [position, id, hp, block, statuses]; enemy rows are [position, id, hp, block].
func _ledger(beat: int) -> Dictionary:
	match beat:
		0:
			return {
				"heroes": [
					[1, "warden", 40, 3, {}],
					[2, "seamstress", 30, 0, {}],
					[3, "tinker", 26, 0, {"weak": 1}],
				],
				"enemies": [
					[1, "ragling_guard", 12, 2],
					[2, "spool_stalker", 14, 0],
					[3, "seam_ripper", 18, 0],
				],
			}
		1:
			return {
				"heroes": [
					[1, "warden", 40, 3, {}],
					[2, "seamstress", 26, 0, {}],
					[3, "tinker", 23, 0, {"weak": 1}],
				],
				"enemies": [
					[1, "ragling_guard", 12, 2],
					[2, "spool_stalker", 14, 0],
					[3, "seam_ripper", 18, 0],
				],
			}
		2:
			return {
				"heroes": [
					[1, "warden", 40, 1, {}],
					[2, "seamstress", 26, 0, {}],
					[3, "tinker", 20, 0, {"weak": 1}],
				],
				"enemies": [
					[1, "ragling_guard", 12, 2],
					[2, "spool_stalker", 14, 1],
					[3, "seam_ripper", 18, 0],
				],
			}
	return {}


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


## One named entry, located by its own enemy_position (never by list order or a
## catalogue total).
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
			% [label, position, id, hp, block, enemy.get("id"), enemy.get("hp"),
				enemy.get("block")])


## One named catalog record, located by its own id and never by a list order or
## a catalogue total.
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
	var records: Array = []
	records.append_array(_load_records(STARTER_ENEMY_PATH))
	records.append_array(_load_records(RUN_ENEMY_PATH))
	var definitions: Array = []
	for id in ENEMY_IDS:
		definitions.append(_record(records, id, "authored enemy"))
	return CombatEnemies.new(definitions)


## AC1: the shipped file is exactly the prescribed three-source, three-beat
## schedule, and the catalog actors it names keep their identities and stats.
func _test_authored_schedule_and_catalog() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "new authored encounter file exists")
	_check(ENCOUNTER_PATH.get_file().get_basename() == ENCOUNTER_ID,
		"the schedule file name carries the canonical encounter ID %s" % ENCOUNTER_ID)
	var raw := _read_text(ENCOUNTER_PATH)
	var raw_json: Variant = JSON.parse_string(raw)
	_check(raw_json is Array and raw_json.size() == 3,
		"the authored file holds exactly this encounter's three source records")
	var parsed := _parsed()
	var expected := _expected()
	_check(parsed == expected, "real parser accepts the file as the exact prescribed schedule")
	_check(parsed.size() == 3, "the parsed schedule has exactly three sources")
	var positions: Array[int] = []
	for entry in parsed:
		if entry is Dictionary and entry.get("enemy_position") is int:
			positions.append(entry["enemy_position"])
	positions.sort()
	_check(positions == [1, 2, 3], "the parsed schedule has the unique source positions 1, 2 and 3")
	_check(CombatEnemyIntents.new(parsed).is_valid(),
		"CombatEnemyIntents.is_valid() for the new authored JSON")
	_check_entry(parsed, 1, expected[0]["pattern"])
	_check_entry(parsed, 2, expected[1]["pattern"])
	_check_entry(parsed, 3, expected[2]["pattern"])
	# The loader normalizes every JSON whole number to a real int before the
	# rules see it.
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
	_check(parsed[0]["pattern"][0] == {"type": "block", "amount": 2},
		"the guard's first beat is the authored self-Block 2")
	_check(parsed[1]["pattern"][0] == {"type": "debuff", "amount": 1,
		"target_position": 3, "status": "weak"},
		"the stalker's first beat is the authored Weak 1 on hero position 3")
	_check(parsed[2]["pattern"][0] == {"type": "attack", "amount": 3,
		"target_position": 1},
		"the ripper's first beat is the authored 3-damage hit on hero position 1")
	_check(CombatEnemyIntents.new(_expected()).is_valid(),
		"the literal prescription itself validates")
	_check(_read_text(ENCOUNTER_PATH) == raw,
		"the authored file bytes stay unchanged after validation")

	# The named actors really exist, exactly once each, in the catalog the
	# schedule is authored against; slot order is 1 Guard Ragling,
	# 2 Spool Stalker, 3 Seam Ripper.
	var starter_records := _load_records(STARTER_ENEMY_PATH)
	var run_records := _load_records(RUN_ENEMY_PATH)
	var guard := _record(starter_records, "ragling_guard", "authored enemy")
	var stalker := _record(run_records, "spool_stalker", "authored enemy")
	var ripper := _record(run_records, "seam_ripper", "authored enemy")
	_check(guard.get("name") == "Guard Ragling" and guard.get("max_hp") == 12
		and guard.get("max_hp") is int,
		"shipped ragling_guard is Guard Ragling with 12 integer max HP")
	_check(stalker.get("name") == "Spool Stalker" and stalker.get("max_hp") == 14
		and stalker.get("max_hp") is int,
		"shipped spool_stalker is Spool Stalker with 14 integer max HP")
	_check(ripper.get("name") == "Seam Ripper" and ripper.get("max_hp") == 18
		and ripper.get("max_hp") is int,
		"shipped seam_ripper is Seam Ripper with 18 integer max HP")
	for record in [guard, stalker, ripper]:
		_check(record.get("art_path") is String
			and not record.get("art_path", "").is_empty(),
			"shipped enemy %s keeps its art path for later real art" % record.get("id"))

	var enemies := _build_enemies()
	_check(enemies.is_valid() and enemies.get_enemies().size() == 3,
		"authored three-enemy roster is valid")
	var roster_ids: Array = []
	for enemy in enemies.get_enemies():
		roster_ids.append(enemy.get("id"))
	_check(roster_ids == ENEMY_IDS,
		"the constructed roster is exactly the three catalog records in this order")
	_check_enemy(enemies, 1, "ragling_guard", 12, 0, "start")
	_check_enemy(enemies, 2, "spool_stalker", 14, 0, "start")
	_check_enemy(enemies, 3, "seam_ripper", 18, 0, "start")
	_check(enemies.get_enemy(1).get("name") == "Guard Ragling"
		and enemies.get_enemy(1).get("position") == 1,
		"Guard Ragling keeps its name in enemy slot 1")
	_check(enemies.get_enemy(2).get("name") == "Spool Stalker"
		and enemies.get_enemy(2).get("position") == 2,
		"Spool Stalker keeps its name in enemy slot 2")
	_check(enemies.get_enemy(3).get("name") == "Seam Ripper"
		and enemies.get_enemy(3).get("position") == 3,
		"Seam Ripper keeps its name in enemy slot 3")

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


## AC2: four announced beats in ascending source order, with the fourth
## repeating the first, independent snapshots, no implicit advance and no RNG
## consumption.
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
	snapshot[0]["type"] = "attack"
	snapshot[0]["amount"] = 99
	snapshot[0]["enemy_position"] = 3
	snapshot.append({"enemy_position": 3, "type": "block", "amount": 5})
	_check(intents.get_intents() == _first_intents(),
		"mutating a returned announcement cannot alter later intents")
	_check(intents._turn_index == 0,
		"mutating a returned announcement cannot advance the cycle")

	var beats: Array = [_first_intents(), _second_intents(), _third_intents(),
		_first_intents()]
	for beat in range(4):
		var announced := intents.get_intents()
		_check(announced == beats[beat],
			"beat %d announces exactly the authored per-source actions" % (beat + 1))
		_check(announced.size() == 3
			and announced[0].get("enemy_position") == 1
			and announced[1].get("enemy_position") == 2
			and announced[2].get("enemy_position") == 3,
			"beat %d lists source slot 1, then 2, then 3" % (beat + 1))
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


## AC3: three successive enemy phases against the real party and roster, with
## the exact authored Block, HP and Weak ledger after each beat.
func _test_three_phase_execution() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	_check(party.is_valid(), "authored party is valid")
	_check(enemies.is_valid(), "authored three-enemy roster is valid")
	_check_hero(party, 1, "warden", 40, 0, {}, "start")
	_check_hero(party, 2, "seamstress", 30, 0, {}, "start")
	_check_hero(party, 3, "tinker", 26, 0, {}, "start")
	_check_enemy(enemies, 1, "ragling_guard", 12, 0, "start")
	_check_enemy(enemies, 2, "spool_stalker", 14, 0, "start")
	_check_enemy(enemies, 3, "seam_ripper", 18, 0, "start")

	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "Warden opening Block 6 applies once")
	_check_hero(party, 1, "warden", 40, 6, {}, "opening")
	var opened := party.get_heroes()
	_check(not opening.apply(), "opening Block cannot be applied twice")
	_check(party.get_heroes() == opened,
		"a second opening attempt grants no additional Block")

	var scheduler := CombatEnemyIntents.new(_parsed())
	var beats: Array = [_first_intents(), _second_intents(), _third_intents()]
	var transcripts: Array = []
	for beat in range(3):
		var announced: Array = scheduler.get_intents()
		_check(announced == beats[beat],
			"beat %d announces the authored per-source actions" % (beat + 1))
		var intents_before: Array = announced.duplicate(true)
		var party_before: Array = party.get_heroes()
		var enemies_before: Array = enemies.get_enemies()
		var result := phase.execute_phase(party, enemies, announced)
		_check(result.get("ok") == true, "beat %d phase succeeds" % (beat + 1))
		var events: Array = result.get("events", [])
		_check(events == _events(beat),
			"beat %d resolves the exact ordered applied events" % (beat + 1))
		_check(events.size() == 3, "beat %d produced exactly three events" % (beat + 1))
		for index in range(events.size()):
			_check(events[index].get("enemy_position") == index + 1,
				"beat %d event %d names source slot %d" % [beat + 1, index + 1, index + 1])
			_check(events[index].get("applied") == true,
				"beat %d event %d is applied" % [beat + 1, index + 1])
		_check(announced == intents_before, "beat %d leaves caller intents untouched" % (beat + 1))
		_check(party.get_heroes() != party_before or enemies.get_enemies() != enemies_before,
			"beat %d actually changed the board" % (beat + 1))
		# The exact authored ledger after this beat.
		var ledger := _ledger(beat)
		for row in ledger.get("heroes", []):
			_check_hero(party, row[0], row[1], row[2], row[3], row[4],
				"beat %d" % (beat + 1))
		for row in ledger.get("enemies", []):
			_check_enemy(enemies, row[0], row[1], row[2], row[3], "beat %d" % (beat + 1))
		transcripts.append({"events": events, "heroes": party.get_heroes(),
			"enemies": enemies.get_enemies()})
		if beat < 2:
			_check(scheduler.advance_turn(), "advance to beat %d" % (beat + 2))

	# The three named shapes the brief prescribes, spelled out once more.
	_check_hero(party, 1, "warden", 40, 1, {}, "after beat 3")
	_check_hero(party, 2, "seamstress", 26, 0, {}, "after beat 3")
	_check_hero(party, 3, "tinker", 20, 0, {"weak": 1}, "after beat 3")
	_check_enemy(enemies, 1, "ragling_guard", 12, 2, "after beat 3")
	_check_enemy(enemies, 2, "spool_stalker", 14, 1, "after beat 3")
	_check_enemy(enemies, 3, "seam_ripper", 18, 0, "after beat 3")

	# Weak on the rear hero does not reduce the enemy's own attack damage, and
	# no owner-turn tick ages it away inside the enemy phase.
	_check(party.get_hero(3).get("statuses") == {"weak": 1},
		"the rear hero still carries Weak 1 after three enemy phases")
	_check(transcripts.size() == 3, "three beat transcripts were recorded")


## AC3: the same fixture run twice from scratch produces identical event,
## status, HP and Block transcripts, and no global RNG is consumed.
func _run_fixture() -> Dictionary:
	var party := _build_party()
	var enemies := _build_enemies()
	var opening := CombatStartingBlock.new(party)
	var opening_applied := opening.apply()
	var scheduler := CombatEnemyIntents.new(_parsed())
	var transcript: Array = []
	for beat in range(3):
		var announced: Array = scheduler.get_intents()
		var result := phase.execute_phase(party, enemies, announced)
		transcript.append({
			"announced": announced,
			"ok": result.get("ok"),
			"events": result.get("events", []),
			"heroes": party.get_heroes(),
			"enemies": enemies.get_enemies(),
		})
		if beat < 2:
			scheduler.advance_turn()
	return {
		"opening": opening_applied,
		"transcript": transcript,
		"next_announcement": scheduler.get_intents(),
		"turn_index": scheduler._turn_index,
	}


func _test_replay_equality() -> void:
	seed(20261021)
	var expected_global := randi()
	seed(20261021)
	var first := _run_fixture()
	_check(randi() == expected_global, "the three authored phases draw no global RNG")
	var second := _run_fixture()

	# Literal end state, so two equally broken runs cannot agree vacuously.
	_check(first.get("opening") == true and second.get("opening") == true,
		"both fixtures applied the Warden opening Block exactly once")
	var first_transcript: Array = first.get("transcript", [])
	var second_transcript: Array = second.get("transcript", [])
	_check(first_transcript.size() == 3 and second_transcript.size() == 3,
		"both fixtures recorded three beats")
	_check(first_transcript == second_transcript,
		"two independently constructed fixtures produce identical event, HP, Block and status transcripts")
	for beat in range(3):
		_check(first_transcript[beat].get("announced") == _expected_intents(beat),
			"replay beat %d announced the authored actions" % (beat + 1))
		_check(first_transcript[beat].get("events") == _events(beat),
			"replay beat %d resolved the authored events" % (beat + 1))
		var heroes: Array = first_transcript[beat].get("heroes", [])
		_check(heroes.size() == 3
			and heroes[0].get("id") == "warden"
			and heroes[0].get("hp") == _ledger(beat)["heroes"][0][2]
			and heroes[0].get("block") == _ledger(beat)["heroes"][0][3]
			and heroes[1].get("id") == "seamstress"
			and heroes[1].get("hp") == _ledger(beat)["heroes"][1][2]
			and heroes[1].get("block") == _ledger(beat)["heroes"][1][3]
			and heroes[2].get("id") == "tinker"
			and heroes[2].get("hp") == _ledger(beat)["heroes"][2][2]
			and heroes[2].get("block") == _ledger(beat)["heroes"][2][3]
			and heroes[2].get("statuses", {}) == _ledger(beat)["heroes"][2][4],
			"replay beat %d ends on the authored hero ledger" % (beat + 1))
		var foes: Array = first_transcript[beat].get("enemies", [])
		_check(foes.size() == 3
			and foes[0].get("id") == "ragling_guard"
			and foes[0].get("hp") == _ledger(beat)["enemies"][0][2]
			and foes[0].get("block") == _ledger(beat)["enemies"][0][3]
			and foes[1].get("id") == "spool_stalker"
			and foes[1].get("hp") == _ledger(beat)["enemies"][1][2]
			and foes[1].get("block") == _ledger(beat)["enemies"][1][3]
			and foes[2].get("id") == "seam_ripper"
			and foes[2].get("hp") == _ledger(beat)["enemies"][2][2]
			and foes[2].get("block") == _ledger(beat)["enemies"][2][3],
			"replay beat %d ends on the authored enemy ledger" % (beat + 1))
	_check(first.get("next_announcement") == second.get("next_announcement")
		and first.get("next_announcement") == _third_intents()
		and first.get("turn_index") == 2 and second.get("turn_index") == 2,
		"both schedulers keep the unadvanced third-beat announcement")


## The literal announced actions of one beat, used by the replay comparison.
func _expected_intents(beat: int) -> Array:
	match beat:
		0:
			return _first_intents()
		1:
			return _second_intents()
		2:
			return _third_intents()
	return []


## AC4: an illegal target_position is rejected atomically: no hero or enemy
## state changes at all.
func _test_illegal_target_rejected() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	_check(CombatStartingBlock.new(party).apply(),
		"illegal-target fixture applies opening Block")
	var party_before: Array = party.get_heroes()
	var enemies_before: Array = enemies.get_enemies()
	var tampered: Array = _second_intents().duplicate(true)
	tampered[0]["target_position"] = 4
	_check(tampered != _second_intents(),
		"negative: the tampered action really differs from the authored beat")
	var result := phase.execute_phase(party, enemies, tampered)
	_check(result == {"ok": false, "events": []},
		"negative: an out-of-range target_position rejects the whole phase")
	_check(party.get_heroes() == party_before,
		"negative: no hero HP, Block, position or status survives the rejected phase")
	_check(enemies.get_enemies() == enemies_before,
		"negative: no enemy Block or HP survives the rejected phase")
	_check(enemies.get_enemy(1).get("block") == 0
		and enemies.get_enemy(2).get("block") == 0,
		"negative: the rejected phase published no earlier Block")

	# A schedule that carries the same illegal target is refused by both the
	# canonical parser and the intent selector.
	var tampered_schedule := _parsed().duplicate(true)
	for entry in tampered_schedule:
		if entry.get("enemy_position") == 1:
			entry["pattern"][1] = {"type": "attack", "amount": 2, "target_position": 4}
	_check(not CombatEnemyIntents.new(tampered_schedule).is_valid(),
		"negative: a schedule with target_position 4 is refused by CombatEnemyIntents")
	_check(RunFightEncounterSelection._parse_schedule_text(
		JSON.stringify(tampered_schedule)).is_empty(),
		"negative: a schedule with target_position 4 is refused by the canonical parser")

	# Control: the unmodified beat still resolves, so the rejection above is
	# about the illegal target and not about the fixture.
	var control_party := _build_party()
	var control_enemies := _build_enemies()
	_check(CombatStartingBlock.new(control_party).apply(),
		"control: control fixture applies opening Block")
	var control := phase.execute_phase(control_party, control_enemies, _second_intents())
	_check(control.get("ok") == true and control.get("events") == _events(1),
		"control: the untampered second beat resolves normally")


## AC4: a Weak debuff aimed at a downed hero rejects the whole phase, and the
## earlier Block from the guarding source is not published.
func _test_downed_debuff_target_rejected() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	_check(CombatStartingBlock.new(party).apply(),
		"downed-target fixture applies opening Block")
	_check(party.apply_damage(3, 26) and party.is_downed(3)
		and party.get_hero(3).get("hp") == 0,
		"negative: real party damage downs Tinker at position 3 before beat 1")
	var party_before: Array = party.get_heroes()
	var enemies_before: Array = enemies.get_enemies()
	var result := phase.execute_phase(party, enemies, _first_intents())
	_check(result == {"ok": false, "events": []},
		"negative: the Weak debuff onto a downed hero rejects the whole first phase")
	_check(party.get_heroes() == party_before,
		"negative: no hero HP, Block, position or status survives the rejected phase")
	_check(party.is_downed(3) and party.get_hero(3).get("id") == "tinker"
		and party.get_hero(3).get("statuses", {}) == {},
		"negative: downed Tinker stays in her slot, unweakened and unrevived")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6,
		"negative: the Warden's opening Block is unchanged by the rejection")
	_check(enemies.get_enemies() == enemies_before,
		"negative: the rejected phase published no enemy Block")
	_check(enemies.get_enemy(1).get("block") == 0,
		"negative: the guarding source's earlier Block 2 was not published")

	# Control: with a living rear hero the same beat resolves.
	var control_party := _build_party()
	var control_enemies := _build_enemies()
	_check(CombatStartingBlock.new(control_party).apply(),
		"control: control fixture applies opening Block")
	var control := phase.execute_phase(control_party, control_enemies, _first_intents())
	_check(control.get("ok") == true and control.get("events") == _events(0),
		"control: the same beat resolves when the rear hero is alive")
	_check(control_party.get_hero(3).get("statuses") == {"weak": 1}
		and control_enemies.get_enemy(1).get("block") == 2,
		"control: Tinker still receives Weak 1 and the guard still gains 2 Block")


## AC4: a slain source is skipped with applied=false instead of acting.
func _test_slain_source_skips() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	_check(CombatStartingBlock.new(party).apply(),
		"slain-source fixture applies opening Block")
	_check(enemies.apply_damage(3, 18) and enemies.is_slain(3)
		and not enemies.is_slain(1) and not enemies.is_slain(2),
		"negative: Seam Ripper is really slain and the other sources stay alive")
	var dead_before: Dictionary = enemies.get_enemy(3)
	var result := phase.execute_phase(party, enemies, _first_intents())
	_check(result.get("ok") == true, "negative: the phase still succeeds with one slain source")
	_check(result.get("events") == [
		{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "debuff", "enemy_position": 2, "applied": true,
			"target_position": 3, "status": "weak"},
		{"type": "attack", "enemy_position": 3, "applied": false,
			"target_position": 1}],
		"negative: the slain source's attack is unapplied; the living sources still act")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6,
		"negative: the slain source deals no damage to the Warden")
	_check(party.get_hero(3).get("statuses") == {"weak": 1},
		"negative: the living stalker still weakens the rear hero")
	_check(enemies.get_enemy(1).get("block") == 2,
		"negative: the living guard still gains its 2 Block")
	_check(enemies.get_enemy(3) == dead_before,
		"negative: the slain source stays at its original slot with unchanged HP/Block")

	# A slain source that would have guarded itself is skipped too.
	var guard_party := _build_party()
	var guard_enemies := _build_enemies()
	_check(CombatStartingBlock.new(guard_party).apply(),
		"slain-guard fixture applies opening Block")
	_check(guard_enemies.apply_damage(1, 12) and guard_enemies.is_slain(1),
		"negative: Guard Ragling is really slain")
	var guard_result := phase.execute_phase(guard_party, guard_enemies, _first_intents())
	_check(guard_result.get("events") == [
		{"type": "block", "enemy_position": 1, "applied": false},
		{"type": "debuff", "enemy_position": 2, "applied": true,
			"target_position": 3, "status": "weak"},
		{"type": "attack", "enemy_position": 3, "applied": true,
			"target_position": 1}],
		"negative: the slain guard's self-Block is unapplied")
	_check(guard_enemies.get_enemy(1).get("block") == 0,
		"negative: the slain guard gains no Block")
	_check(guard_party.get_hero(1).get("hp") == 40
		and guard_party.get_hero(1).get("block") == 3,
		"negative: the living ripper still hits the Warden for 3")


## AC1/AC4: malformed schedules fail closed in the canonical parser and in
## CombatEnemyIntents, each judged independently and without mutating input.
func _test_parser_rejections() -> void:
	var pristine := _read_text(ENCOUNTER_PATH)
	var duplicate := _expected().duplicate(true)
	duplicate[2]["enemy_position"] = 1
	var off_board := _expected().duplicate(true)
	for entry in off_board:
		if entry.get("enemy_position") == 3:
			entry["pattern"][0] = {"type": "attack", "amount": 3, "target_position": 4}
	var negative_amount := _expected().duplicate(true)
	for entry in negative_amount:
		if entry.get("enemy_position") == 2:
			entry["pattern"][1] = {"type": "attack", "amount": -1, "target_position": 3}
	var cases: Array = [
		{"label": "duplicate enemy_position records", "data": duplicate,
			"control": _expected()},
		{"label": "out-of-range target_position 4", "data": off_board,
			"control": _expected()},
		{"label": "negative attack amount -1", "data": negative_amount,
			"control": _expected()},
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
		# Control: the same data with ONLY the offending field restored parses
		# and validates.
		var control: Array = entry_case["control"]
		_check(control != data,
			"control: %s control fixture really differs from the rejected data"
				% entry_case["label"])
		_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(control)) == control,
			"control: %s with only the offending field restored parses exactly"
				% entry_case["label"])
		_check(CombatEnemyIntents.new(control).is_valid(),
			"control: %s with only the offending field restored validates" % entry_case["label"])
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
