extends SceneTree

## Deterministic headless coverage for the authored Seamshift Tripwire encounter:
## slot 1 shoves the FRONT hero into MIDDLE, slot 2 marks whoever is now MIDDLE
## Exposed 1, and slot 3 attacks that moved hero for floor(4 x 1.5) = 6 damage,
## fully spent against the Warden's start-of-combat Block. Data/service only:
## this file never wires the encounter into live play, and no typed-pool or
## registry file is read or written here.

const ENCOUNTER_PATH := "res://data/encounters/seamshift_tripwire.json"
const ENCOUNTER_ID := "seamshift_tripwire"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMY_PATH := "res://data/enemies/run_enemies.json"
const STARTER_PATH := "res://data/encounters/starter_attacks.json"
const FRONT_HEM_PATH := "res://data/encounters/front_hem_pivot.json"
const HERO_IDS := ["warden", "seamstress", "tinker"]
# Encounter slot order: 1 Seam Ripper, 2 Spool Stalker, 3 Fray Scavenger.
const ENEMY_SLOTS := [
	{"id": "seam_ripper", "name": "Seam Ripper", "max_hp": 18},
	{"id": "spool_stalker", "name": "Spool Stalker", "max_hp": 14},
	{"id": "fray_scavenger", "name": "Fray Scavenger", "max_hp": 14},
]

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_authored_schedule_and_catalog()
	_test_companion_schedules_still_valid()
	_test_intent_cycle()
	_test_first_phase_real_execution()
	_test_double_fixture_replay()
	_test_downed_swap_rejects_whole_phase()
	_test_parser_rejections()
	if failures.is_empty():
		print("seamshift_tripwire_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("seamshift_tripwire_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## The exact prescribed schedule for this encounter's own three sources.
func _expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "shove", "amount": 0, "target_position": 1, "direction": 1},
			{"type": "attack", "amount": 2, "target_position": 2},
			{"type": "block", "amount": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "debuff", "amount": 1, "target_position": 2, "status": "exposed"},
			{"type": "attack", "amount": 2, "target_position": 3},
			{"type": "buff", "amount": 2}]},
		{"enemy_position": 3, "pattern": [
			{"type": "attack", "amount": 4, "target_position": 2},
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 2, "target_position": 1}]},
	]


## Literal announced beats, independent of the parsed file and of _expected().
func _first_intents() -> Array:
	return [
		{"type": "shove", "amount": 0, "target_position": 1, "direction": 1,
			"enemy_position": 1},
		{"type": "debuff", "amount": 1, "target_position": 2, "status": "exposed",
			"enemy_position": 2},
		{"type": "attack", "amount": 4, "target_position": 2, "enemy_position": 3}]


func _second_intents() -> Array:
	return [
		{"type": "attack", "amount": 2, "target_position": 2, "enemy_position": 1},
		{"type": "attack", "amount": 2, "target_position": 3, "enemy_position": 2},
		{"type": "block", "amount": 1, "enemy_position": 3}]


func _third_intents() -> Array:
	return [
		{"type": "block", "amount": 2, "enemy_position": 1},
		{"type": "buff", "amount": 2, "enemy_position": 2},
		{"type": "attack", "amount": 2, "target_position": 1, "enemy_position": 3}]


## Literal first-beat resolution through the real phase services.
func _first_phase_events() -> Array:
	return [
		{"type": "shove", "enemy_position": 1, "target_position": 1, "direction": 1,
			"applied": true},
		{"type": "debuff", "enemy_position": 2, "target_position": 2, "status": "exposed",
			"applied": true},
		{"type": "attack", "enemy_position": 3, "target_position": 2, "applied": true}]


## The two named earlier schedules, asserted by their OWN complete entries.
func _starter_expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "attack", "amount": 1, "target_position": 3}]},
		{"enemy_position": 2, "pattern": [
			{"type": "block", "amount": 1}]},
	]


func _front_hem_expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "shove", "amount": 0, "target_position": 1, "direction": 1},
			{"type": "block", "amount": 2},
			{"type": "attack", "amount": 2, "target_position": 3}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 2, "target_position": 1},
			{"type": "attack", "amount": 2, "target_position": 2},
			{"type": "buff", "amount": 2}]},
	]


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "opens " + path)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


## Godot may hand whole JSON numbers to the rules as floats; authored fixtures
## are normalized exactly so the real model services see ints.
func _normalize_json(data) -> Variant:
	if data is Array:
		var result: Array = []
		for item in data:
			result.append(_normalize_json(item))
		return result
	if data is Dictionary:
		var result: Dictionary = {}
		for key in data:
			var value = data[key]
			if value is float and is_finite(value) and value == int(value):
				value = int(value)
			else:
				value = _normalize_json(value)
			result[key] = value
		return result
	if data is float and is_finite(data) and data == int(data):
		return int(data)
	return data


func _load_json(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(_read_text(path))
	if not parsed is Array:
		return []
	return _normalize_json(parsed)


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
		"entry %d has a %d-action cycle" % [position, expected_actions.size()])
	if not pattern is Array or pattern.size() != expected_actions.size():
		return
	for index in range(expected_actions.size()):
		_check(pattern[index] == expected_actions[index],
			"entry %d turn %d is exactly %s" % [position, index + 1,
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


func _build_authored_party() -> CombatParty:
	var heroes := _load_json(PARTY_PATH)
	var definitions: Array = []
	for id in HERO_IDS:
		definitions.append(_record(heroes, id, "authored hero"))
	return CombatParty.new(definitions)


func _build_authored_enemies() -> CombatEnemies:
	var enemies := _load_json(ENEMY_PATH)
	var definitions: Array = []
	for slot in ENEMY_SLOTS:
		definitions.append(_record(enemies, slot["id"], "authored enemy"))
	return CombatEnemies.new(definitions)


## AC1: the shipped file is exactly the prescribed three-source, three-beat
## schedule, and the catalog actors it names keep their identities and stats.
func _test_authored_schedule_and_catalog() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "new authored encounter file exists")
	_check(ENCOUNTER_PATH.get_file().get_basename() == ENCOUNTER_ID,
		"the schedule file name carries the canonical encounter ID %s" % ENCOUNTER_ID)
	var raw = JSON.parse_string(_read_text(ENCOUNTER_PATH))
	_check(raw is Array and raw.size() == 3,
		"the authored file holds exactly this encounter's three source records")
	var parsed := _parsed()
	_check(parsed == _expected(), "real parser accepts the file as the exact prescribed schedule")
	_check(parsed.size() == 3, "the parsed schedule has exactly three sources")
	_check(CombatEnemyIntents.new(parsed).is_valid(),
		"CombatEnemyIntents.is_valid() for the new authored JSON")
	_check_entry(parsed, 1, _expected()[0]["pattern"])
	_check_entry(parsed, 2, _expected()[1]["pattern"])
	_check_entry(parsed, 3, _expected()[2]["pattern"])
	# The loader normalizes every JSON whole number to a real int before the rules see it.
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
			if action.has("direction"):
				_check(action.get("direction") is int,
					"parsed beat direction is an int, not a JSON float")
	_check(CombatEnemyIntents.new(_expected()).is_valid(),
		"the literal prescription itself validates")
	_check(parsed.size() == 3 and parsed[0]["pattern"][0].get("type") == "shove"
		and parsed[0]["pattern"][0].get("direction") == 1
		and parsed[1]["pattern"][0].get("type") == "debuff"
		and parsed[1]["pattern"][0].get("status") == "exposed"
		and parsed[2]["pattern"][0].get("type") == "attack"
		and parsed[2]["pattern"][0].get("amount") == 4,
		"the parsed file opens shove, then Exposed, then the base-4 attack")

	# The named actors really exist, exactly once each, with the stats this
	# schedule is authored against; slot order is 1 Seam Ripper, 2 Spool
	# Stalker, 3 Fray Scavenger.
	var roster := _load_json(ENEMY_PATH)
	for slot in ENEMY_SLOTS:
		var matches: Array = []
		for enemy in roster:
			if enemy is Dictionary and enemy.get("id") == slot["id"]:
				matches.append(enemy)
		_check(matches.size() == 1, "shipped enemy %s exists exactly once" % slot["id"])
		if matches.size() == 1:
			_check(matches[0].get("name") == slot["name"]
				and matches[0].get("max_hp") == slot["max_hp"]
				and matches[0].get("max_hp") is int,
				"shipped enemy %s is %s with %d integer max HP"
					% [slot["id"], slot["name"], slot["max_hp"]])
			_check(matches[0].get("art_path") is String and not matches[0].get("art_path", "").is_empty(),
				"shipped enemy %s keeps its art path for later real art" % slot["id"])

	var party := _build_authored_party()
	_check(party.is_valid(), "shipped starter party builds a real three-hero party")
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("max_hp") == 40
		and party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("max_hp") == 30
		and party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("max_hp") == 26,
		"starter party is Warden/Seamstress/Tinker at 40/30/26 HP in positions 1/2/3")
	var roster_from_catalog := _build_authored_enemies()
	_check(roster_from_catalog.is_valid()
		and roster_from_catalog.get_enemy(1).get("id") == "seam_ripper"
		and roster_from_catalog.get_enemy(1).get("hp") == 18
		and roster_from_catalog.get_enemy(2).get("id") == "spool_stalker"
		and roster_from_catalog.get_enemy(2).get("hp") == 14
		and roster_from_catalog.get_enemy(3).get("id") == "fray_scavenger"
		and roster_from_catalog.get_enemy(3).get("hp") == 14,
		"catalog roster builds Seam Ripper 18 / Spool Stalker 14 / Fray Scavenger 14 in slots 1/2/3")


## AC1: the two named earlier schedules still parse and validate, judged only by
## their own complete per-source entries.
func _test_companion_schedules_still_valid() -> void:
	var starter := RunFightEncounterSelection._parse_schedule_text(_read_text(STARTER_PATH))
	_check(starter == _starter_expected(),
		"starter_attacks.json still parses as exactly its own authored sources")
	_check(starter.size() == 2 and starter[0]["pattern"][0].get("type") == "attack"
		and starter[1]["pattern"][0].get("type") == "block",
		"starter_attacks.json keeps its own slot-1 attacks and slot-2 Block")
	_check(CombatEnemyIntents.new(starter).is_valid(),
		"starter_attacks.json still validates in CombatEnemyIntents")
	var pivot := RunFightEncounterSelection._parse_schedule_text(_read_text(FRONT_HEM_PATH))
	_check(pivot == _front_hem_expected(),
		"front_hem_pivot.json still parses as exactly its own authored sources")
	_check(pivot.size() == 2 and pivot[0]["pattern"][0].get("type") == "shove"
		and pivot[1]["pattern"][1].get("type") == "attack",
		"front_hem_pivot.json keeps its own shove and middle attack beats")
	_check(CombatEnemyIntents.new(pivot).is_valid(),
		"front_hem_pivot.json still validates in CombatEnemyIntents")


## AC1/AC3: three announced beats in ascending source order, then an exact
## repeat, with no run/global RNG consumption and no aliasing of caller data.
func _test_intent_cycle() -> void:
	var definitions := _parsed()
	var intents := CombatEnemyIntents.new(definitions)
	_check(intents.is_valid(), "authored schedule builds a valid intent selector")
	_check(intents.get_intents() == _first_intents(), "turn 1 announces the exact first beats")
	_check(intents.advance_turn(), "advance to turn 2")
	_check(intents.get_intents() == _second_intents(), "turn 2 announces the exact second beats")
	_check(intents.advance_turn(), "advance to turn 3")
	_check(intents.get_intents() == _third_intents(), "turn 3 announces the exact third beats")
	_check(intents.advance_turn(), "advance past the third beat")
	_check(intents.get_intents() == _first_intents(),
		"turn 4 repeats the first announced intents exactly")

	# Announcements are always source-ordered, slots 1, 2, 3.
	for turn in range(4):
		var announced := intents.get_intents()
		_check(announced.size() == 3 and announced[0].get("enemy_position") == 1
			and announced[1].get("enemy_position") == 2
			and announced[2].get("enemy_position") == 3,
			"announcement %d lists slot 1, slot 2 then slot 3" % (turn + 1))
		intents.advance_turn()

	# The whole fixed cycle, viewed and advanced, draws no global RNG.
	seed(20261021)
	var baseline := randi()
	seed(20261021)
	var probe := CombatEnemyIntents.new(definitions)
	for turn in range(7):
		probe.get_intents()
		probe.advance_turn()
	_check(randi() == baseline, "constructing, viewing and advancing this schedule draws no global RNG")
	seed(20261021)
	var without_extra := randi()
	seed(20261021)
	randi()
	_check(randi() != without_extra, "the global RNG probe detects an injected extra draw")

	# Returned announcements and the parsed source cannot alias the selector's state.
	var snapshot_selector := CombatEnemyIntents.new(_expected().duplicate(true))
	var snapshot := snapshot_selector.get_intents()
	_check(snapshot == _first_intents(), "snapshot is the exact first announced beats")
	snapshot[0]["type"] = "block"
	snapshot[0]["amount"] = 99
	snapshot.append({"enemy_position": 4, "type": "block", "amount": 5})
	_check(snapshot_selector.get_intents() == _first_intents(),
		"mutating a returned announcement cannot alter later intents")
	_check(definitions == _expected(), "parsed schedule starts from its prescribed source")
	var isolated := CombatEnemyIntents.new(definitions)
	var parsed_pattern: Array = definitions[0]["pattern"]
	parsed_pattern[0]["amount"] = 7
	_check(isolated.get_intents() == _first_intents(),
		"mutating the parsed source cannot alter an independently constructed intent selector")
	_check(_parsed() == _expected(), "re-reading the authored file reproduces the prescribed source")


## AC2: the authored first beat resolves through the real services against the
## real party and roster: shove FRONT into MIDDLE, Exposed 1 on whoever is now
## MIDDLE, then floor(4 x 1.5) = 6 damage absorbed entirely by Warden Block.
func _test_first_phase_real_execution() -> void:
	var party := _build_authored_party()
	_check(party.is_valid(), "authored party is valid")
	var enemies := _build_authored_enemies()
	_check(enemies.is_valid(), "authored three-enemy roster is valid")
	_check_enemy(enemies, 1, "seam_ripper", 18, 0, "start")
	_check_enemy(enemies, 2, "spool_stalker", 14, 0, "start")
	_check_enemy(enemies, 3, "fray_scavenger", 14, 0, "start")
	_check_hero(party, 1, "warden", 40, 0, {}, "start")
	_check_hero(party, 2, "seamstress", 30, 0, {}, "start")
	_check_hero(party, 3, "tinker", 26, 0, {}, "start")

	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "Warden opening Block 6 applies once")
	_check_hero(party, 1, "warden", 40, 6, {}, "opening")
	_check(not opening.apply(), "opening Block cannot be applied twice")
	_check_hero(party, 1, "warden", 40, 6, {}, "opening once")

	# The exposed multiplier is exactly floor(4 x 1.5) = 6, floored once.
	_check(CombatStatuses.new().adjusted_attack_damage(4, {}, {"exposed": 1}) == 6,
		"a base-4 attack against Exposed 1 adjusts to exactly 6 damage")
	_check(CombatStatuses.new().adjusted_attack_damage(4, {}, {}) == 4,
		"the same attack without Exposed stays at its base 4 (control)")

	var scheduler := CombatEnemyIntents.new(_parsed())
	_check(scheduler.get_intents() == _first_intents(),
		"phase 1 announces shove, Exposed debuff and the base-4 attack in slot order")
	var before_enemies: Array = enemies.get_enemies()
	var input_intents: Array = scheduler.get_intents()
	var input_copy: Array = input_intents.duplicate(true)

	var turn1 := phase.execute_phase(party, enemies, input_intents)
	_check(turn1.get("ok") == true, "phase 1 succeeds")
	_check(turn1.get("events") == _first_phase_events(),
		"phase 1 events: slot-1 shove, slot-2 Exposed 1, slot-3 attack, all applied")
	_check(turn1.get("events").size() == 3, "phase 1 produced exactly three events, no extras")
	_check(input_intents == input_copy, "the executed phase leaves caller intents untouched")

	# The shove moved Warden 1->2 with his Block and metadata; Seamstress 2->1.
	_check_hero(party, 1, "seamstress", 30, 0, {}, "phase 1")
	_check_hero(party, 2, "warden", 40, 0, {"exposed": 1}, "phase 1")
	_check_hero(party, 3, "tinker", 26, 0, {}, "phase 1")
	# Actor identity follows the swap: names and art paths travel with their IDs.
	var warden := party.get_hero(2)
	_check(warden.get("name") == "Warden" and warden.get("max_hp") == 40
		and warden.get("art_path") is String and not warden.get("art_path", "").is_empty(),
		"the moved slot-2 hero keeps Warden's name, max HP and art path")
	var seamstress := party.get_hero(1)
	_check(seamstress.get("name") == "Seamstress" and seamstress.get("max_hp") == 30
		and seamstress.get("art_path") is String and not seamstress.get("art_path", "").is_empty(),
		"the moved slot-1 hero keeps Seamstress's name, max HP and art path")

	# The six damage removed all six opening Block and not a single HP.
	_check(warden.get("hp") == 40 and warden.get("block") == 0,
		"the Exposed attack spent all 6 Block and no HP (floor(4 x 1.5) = 6)")
	var exposed_owners: Array = []
	for hero in party.get_heroes():
		if hero.get("statuses", {}) == {"exposed": 1}:
			exposed_owners.append(hero.get("id"))
	_check(exposed_owners == ["warden"],
		"Exposed 1 sits on exactly one actor: the Warden identity, wherever he stands")
	# Enemy HP and Block are untouched by this first beat.
	_check(enemies.get_enemies() == before_enemies,
		"no enemy HP, Block or statuses changed during the first beat")
	_check_enemy(enemies, 1, "seam_ripper", 18, 0, "phase 1")
	_check_enemy(enemies, 2, "spool_stalker", 14, 0, "phase 1")
	_check_enemy(enemies, 3, "fray_scavenger", 14, 0, "phase 1")

	# The isolated phase did not advance the scheduler and did not age Exposed;
	# expiry belongs only to a CombatStatusTurnBatch owner-turn boundary.
	_check(scheduler._turn_index == 0 and scheduler.get_intents() == _first_intents(),
		"the isolated phase did not advance the scheduler")
	_check(party.get_hero(2).get("statuses", {}) == {"exposed": 1},
		"Exposed does not age during isolated enemy-phase execution")
	var boundary := CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())
	_check(boundary.get("ok") == true
		and boundary.get("actors")[1].get("statuses", {}) == {},
		"control: only a CombatStatusTurnBatch owner-turn boundary proposes the Exposed decrement")
	_check(party.get_hero(2).get("statuses", {}) == {"exposed": 1},
		"the boundary proposal is detached: live Exposed stays at 1")


## AC3: two freshly constructed fixtures with independent seeded RNGs agree on
## every event, snapshot, next announcement and RNG state, and reproduce the
## literal end state so two equally broken runs cannot satisfy the comparison.
func _first_phase_fixture() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261021
	var rng_before := rng.state
	var party := _build_authored_party()
	var enemies := _build_authored_enemies()
	var opening := CombatStartingBlock.new(party)
	var opening_applied := opening.apply()
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
	_check(first["heroes"].size() == 3 and first["enemies"].size() == 3,
		"each replay ends with the complete authored formation")
	_check(first["heroes"][0]["id"] == "seamstress" and first["heroes"][0]["hp"] == 30
		and first["heroes"][0]["block"] == 0
		and first["heroes"][0].get("statuses", {}) == {}
		and first["heroes"][1]["id"] == "warden" and first["heroes"][1]["hp"] == 40
		and first["heroes"][1]["block"] == 0
		and first["heroes"][1].get("statuses", {}) == {"exposed": 1}
		and first["heroes"][2]["id"] == "tinker" and first["heroes"][2]["hp"] == 26
		and first["heroes"][2]["block"] == 0
		and first["heroes"][2].get("statuses", {}) == {},
		"replay end state is Seamstress 30/0, Warden 40/0 Exposed 1, Tinker 26/0")
	_check(first["enemies"][0]["id"] == "seam_ripper" and first["enemies"][0]["hp"] == 18
		and first["enemies"][0]["block"] == 0
		and first["enemies"][1]["id"] == "spool_stalker" and first["enemies"][1]["hp"] == 14
		and first["enemies"][1]["block"] == 0
		and first["enemies"][2]["id"] == "fray_scavenger" and first["enemies"][2]["hp"] == 14
		and first["enemies"][2]["block"] == 0,
		"replay end state is Seam Ripper 18/0, Spool Stalker 14/0, Fray Scavenger 14/0")

	_check(first["opening"] == true and second["opening"] == true,
		"both fixtures applied the Warden opening Block exactly once")
	_check(first["announced"] == _first_intents() and second["announced"] == _first_intents(),
		"both fixtures announced the identical authored first beats")
	_check(first["result"] == second["result"] and first["result"]["events"] == _first_phase_events(),
		"two independently constructed fixtures produce identical phase events")
	_check(first["heroes"] == second["heroes"] and first["enemies"] == second["enemies"],
		"two independently constructed fixtures end in identical party and enemy state")
	_check(first["next_announcement"] == second["next_announcement"]
		and first["next_announcement"] == _first_intents()
		and first["turn_index"] == 0 and second["turn_index"] == 0,
		"both schedulers keep the unadvanced first-beat announcement")
	_check(first["rng_before"] == second["rng_before"] and first["rng_after"] == second["rng_after"],
		"both independent seeded RNGs reach identical states")
	_check(first["rng_before"] == first["rng_after"],
		"the fixture's own seeded RNG state is untouched by the phase")


## AC3: a downed swap participant makes the opening shove illegal, so the whole
## phase rejects with no partial mutation, no later Exposed/damage and no
## scheduler advancement.
func _test_downed_swap_rejects_whole_phase() -> void:
	var party := _build_authored_party()
	var enemies := _build_authored_enemies()
	_check(party.apply_damage(1, 40), "negative: real party damage downs the Warden at slot 1")
	_check(party.is_downed(1) and party.get_hero(1).get("hp") == 0,
		"negative: Warden is downed at slot 1 before any opening Block")
	var opening := CombatStartingBlock.new(party)
	_check(not opening.apply(), "negative: opening Block refuses a downed Warden")
	_check(party.get_hero(1).get("block") == 0,
		"negative: no opening Block reaches the downed fixture")

	var scheduler := CombatEnemyIntents.new(_parsed())
	var before_intents: Array = scheduler.get_intents()
	_check(before_intents == _first_intents(),
		"negative: phase 1 announces the authored first beats")
	var before_party: Array = party.get_heroes()
	var before_enemies: Array = enemies.get_enemies()
	var before_turn: int = scheduler._turn_index
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261021
	var rng_before := rng.state
	seed(20261021)
	var expected_global := randi()
	seed(20261021)
	var result := phase.execute_phase(party, enemies, before_intents)
	_check(randi() == expected_global, "negative: the rejected phase draws no global RNG")
	_check(rng.state == rng_before,
		"negative: the rejected phase leaves the seeded RNG stream untouched")
	_check(result == {"ok": false, "events": []},
		"negative: a downed swap participant rejects the whole first phase")
	_check(party.get_heroes() == before_party,
		"negative: no hero HP, Block, position or status survives the rejected phase")
	_check(party.get_hero(1).get("id") == "warden" and party.is_downed(1),
		"negative: the downed Warden stays in slot 1, unswapped")
	_check(party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(2).get("hp") == 30 and party.get_hero(2).get("statuses", {}) == {},
		"negative: the rejected debuff and attack never reach the middle slot")
	_check(enemies.get_enemies() == before_enemies,
		"negative: no enemy HP or Block survives the rejected phase")
	_check(before_intents == scheduler.get_intents(),
		"negative: the rejected phase leaves caller intents and announcements untouched")
	_check(scheduler._turn_index == before_turn and scheduler.get_intents() == _first_intents(),
		"negative: the rejected phase does not advance the scheduler")

	# Localized control: the same first beats succeed when only the REAR hero is
	# downed, proving the rejection above came from the downed swap participant.
	var control_party := _build_authored_party()
	var control_enemies := _build_authored_enemies()
	_check(CombatStartingBlock.new(control_party).apply(),
		"control: opening Block applies when the swap participants are living")
	_check(control_party.apply_damage(3, 26),
		"control: real party damage downs Tinker at slot 3")
	var control := phase.execute_phase(control_party, control_enemies, _first_intents())
	_check(control.get("ok") == true and control.get("events") == _first_phase_events(),
		"control: the same beats resolve when the downed hero is not a swap participant")
	_check_hero(control_party, 1, "seamstress", 30, 0, {}, "control")
	_check_hero(control_party, 2, "warden", 40, 0, {"exposed": 1}, "control")
	_check_hero(control_party, 3, "tinker", 0, 0, {}, "control")


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
	var duplicate := _expected().duplicate(true)
	duplicate[2]["enemy_position"] = 1
	var off_board := _with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 3,
		"direction": 1})
	var negative_amount := _with_beat(1, 1, {"type": "attack", "amount": -1,
		"target_position": 2})
	var cases: Array = [
		{"label": "duplicate enemy_position records", "data": duplicate,
			"control": _expected()},
		{"label": "off-board shove (target_position 3, direction 1)", "data": off_board,
			"control": _with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 2,
				"direction": 1})},
		{"label": "negative attack amount -1", "data": negative_amount,
			"control": _with_beat(1, 1, {"type": "attack", "amount": 2, "target_position": 2})},
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
			"negative: %s leaves the directly submitted definitions untouched" % entry_case["label"])
		# Control: the same data with ONLY the offending field restored parses and validates.
		var control: Array = entry_case["control"]
		_check(control != data,
			"control: %s control fixture really differs from the rejected data" % entry_case["label"])
		_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(control)) == control,
			"control: %s with only the offending field restored parses exactly"
				% entry_case["label"])
		_check(CombatEnemyIntents.new(control).is_valid(),
			"control: %s with only the offending field restored validates" % entry_case["label"])
	for broken_text in ["{", "{}", "[]"]:
		_check(RunFightEncounterSelection._parse_schedule_text(broken_text).is_empty(),
			"negative: unparsable/empty schedule text %s is rejected" % broken_text)
	# Controls, so the rejections above cannot pass vacuously.
	_check(_parsed() == _expected(),
		"negative controls: the unmodified authored file still parses exactly")
	_check(CombatEnemyIntents.new(_expected()).is_valid(),
		"negative controls: the unmodified authored schedule still validates")
