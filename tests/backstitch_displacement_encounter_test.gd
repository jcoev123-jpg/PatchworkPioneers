extends SceneTree

## Deterministic headless coverage for the authored Backstitch Displacement encounter:
## slot-1 Spool Stalker shoves the middle hero into the back slot before slot-2 Seam
## Ripper attacks that moved hero, then the middle hero attacks and applies Weak.
## Data/service only: this file never wires the encounter into live play.

const ENCOUNTER_PATH := "res://data/encounters/backstitch_displacement.json"
const ENCOUNTER_ID := "backstitch_displacement"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMY_PATH := "res://data/enemies/run_enemies.json"
const HERO_IDS := ["warden", "seamstress", "tinker"]
const ENEMY_IDS := ["spool_stalker", "seam_ripper"]

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_authored_schedule_and_catalog()
	_test_intent_cycle()
	_test_real_three_phase_sequence()
	_test_double_replay()
	_test_negative_rejections()
	if failures.is_empty():
		print("backstitch_displacement_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("backstitch_displacement_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## The exact prescribed schedule for this encounter's own two sources.
func _expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
			{"type": "attack", "amount": 2, "target_position": 2},
			{"type": "block", "amount": 1}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 2, "target_position": 3},
			{"type": "debuff", "amount": 1, "target_position": 2, "status": "weak"},
			{"type": "attack", "amount": 2, "target_position": 1}]},
	]


## Literal announced beats, independent of the parsed file and of _expected().
func _first_intents() -> Array:
	return [
		{"type": "shove", "amount": 0, "target_position": 2, "direction": 1,
			"enemy_position": 1},
		{"type": "attack", "amount": 2, "target_position": 3, "enemy_position": 2}]


func _second_intents() -> Array:
	return [
		{"type": "attack", "amount": 2, "target_position": 2, "enemy_position": 1},
		{"type": "debuff", "amount": 1, "target_position": 2, "status": "weak",
			"enemy_position": 2}]


func _third_intents() -> Array:
	return [
		{"type": "block", "amount": 1, "enemy_position": 1},
		{"type": "attack", "amount": 2, "target_position": 1, "enemy_position": 2}]


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
	for id in ENEMY_IDS:
		definitions.append(_record(enemies, id, "authored enemy"))
	return CombatEnemies.new(definitions)


## AC1: the shipped file is exactly the prescribed two-source, three-beat schedule,
## and the catalog actors it names keep their identities and stats.
func _test_authored_schedule_and_catalog() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "new authored encounter file exists")
	_check(ENCOUNTER_PATH.get_file().get_basename() == ENCOUNTER_ID,
		"the schedule file name carries the canonical encounter ID %s" % ENCOUNTER_ID)
	var raw = JSON.parse_string(_read_text(ENCOUNTER_PATH))
	_check(raw is Array and raw.size() == 2,
		"the authored file holds exactly this encounter's two source records")
	var parsed := _parsed()
	_check(parsed == _expected(), "real parser accepts the file as the exact prescribed schedule")
	_check(parsed.size() == 2, "the parsed schedule has exactly two sources")
	_check(CombatEnemyIntents.new(parsed).is_valid(),
		"CombatEnemyIntents.is_valid() for the new authored JSON")
	_check_entry(parsed, 1, _expected()[0]["pattern"])
	_check_entry(parsed, 2, _expected()[1]["pattern"])
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
	_check(parsed.size() == 2 and parsed[0]["pattern"][0].get("type") == "shove"
		and parsed[0]["pattern"][0].get("direction") == 1
		and parsed[1]["pattern"][0].get("type") == "attack",
		"the parsed file opens with the slot-1 back shove before the slot-2 attack")

	# The named actors really exist with the stats this schedule is authored against.
	var roster := _load_json(ENEMY_PATH)
	for expected_actor in [{"id": "spool_stalker", "name": "Spool Stalker", "max_hp": 14},
			{"id": "seam_ripper", "name": "Seam Ripper", "max_hp": 18}]:
		var matches: Array = []
		for enemy in roster:
			if enemy is Dictionary and enemy.get("id") == expected_actor["id"]:
				matches.append(enemy)
		_check(matches.size() == 1, "shipped enemy %s exists exactly once" % expected_actor["id"])
		if matches.size() == 1:
			_check(matches[0].get("name") == expected_actor["name"]
				and matches[0].get("max_hp") == expected_actor["max_hp"]
				and matches[0].get("max_hp") is int,
				"shipped enemy %s is %s with %d integer max HP"
					% [expected_actor["id"], expected_actor["name"], expected_actor["max_hp"]])
			_check(matches[0].get("art_path") is String and not matches[0].get("art_path", "").is_empty(),
				"shipped enemy %s keeps its art path for later real art" % expected_actor["id"])

	var party := _build_authored_party()
	_check(party.is_valid(), "shipped starter party builds a real three-hero party")
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("max_hp") == 40
		and party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("max_hp") == 30
		and party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("max_hp") == 26,
		"starter party is Warden/Seamstress/Tinker at 40/30/26 HP in positions 1/2/3")


## AC1/AC3: three announced beats in ascending source order, then an exact repeat,
## with no run/global RNG consumption and no aliasing of caller data.
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

	# Announcements are always source-ordered, slot 1 before slot 2.
	for turn in range(4):
		var announced := intents.get_intents()
		_check(announced.size() == 2 and announced[0].get("enemy_position") == 1
			and announced[1].get("enemy_position") == 2,
			"announcement %d lists slot 1 then slot 2" % (turn + 1))
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
	snapshot.append({"enemy_position": 3, "type": "block", "amount": 5})
	_check(snapshot_selector.get_intents() == _first_intents(),
		"mutating a returned announcement cannot alter later intents")
	_check(definitions == _expected(), "parsed schedule starts from its prescribed source")
	var isolated := CombatEnemyIntents.new(definitions)
	var parsed_pattern: Array = definitions[0]["pattern"]
	parsed_pattern[0]["amount"] = 7
	_check(isolated.get_intents() == _first_intents(),
		"mutating the parsed source cannot alter an independently constructed intent selector")


## AC2/AC3: the authored beats resolve through the real services against the real
## party and roster, one explicit advance per phase.
func _test_real_three_phase_sequence() -> void:
	var party := _build_authored_party()
	_check(party.is_valid(), "authored party is valid")
	var enemies := _build_authored_enemies()
	_check(enemies.is_valid(), "authored two-enemy roster is valid")
	_check_enemy(enemies, 1, "spool_stalker", 14, 0, "start")
	_check_enemy(enemies, 2, "seam_ripper", 18, 0, "start")
	_check_hero(party, 1, "warden", 40, 0, {}, "start")
	_check_hero(party, 2, "seamstress", 30, 0, {}, "start")
	_check_hero(party, 3, "tinker", 26, 0, {}, "start")

	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "Warden opening Block 6 applies once")
	_check_hero(party, 1, "warden", 40, 6, {}, "opening")
	_check(not opening.apply(), "opening Block cannot be applied twice")
	_check_hero(party, 1, "warden", 40, 6, {}, "opening once")

	var scheduler := CombatEnemyIntents.new(_parsed())
	_check(scheduler.get_intents() == _first_intents(),
		"phase 1 announces the slot-1 shove before the slot-2 back attack")

	# Phase 1: slot-1 shove swaps Seamstress 2 with living Tinker 3, so slot-2's
	# attack 2 at position 3 hits the MOVED Seamstress.
	var turn1 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(turn1.get("ok") == true, "phase 1 succeeds")
	_check(turn1.get("events") == [
		{"type": "shove", "enemy_position": 1, "target_position": 2, "direction": 1,
			"applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true}],
		"phase 1 events: slot-1 shove then slot-2 attack on the moved back hero, both applied")
	_check_hero(party, 1, "warden", 40, 6, {}, "phase 1")
	_check_hero(party, 2, "tinker", 26, 0, {}, "phase 1")
	_check_hero(party, 3, "seamstress", 28, 0, {}, "phase 1")
	_check_enemy(enemies, 1, "spool_stalker", 14, 0, "phase 1")
	_check_enemy(enemies, 2, "seam_ripper", 18, 0, "phase 1")

	_check(scheduler.advance_turn(), "explicit advance to phase 2")
	_check(scheduler.get_intents() == _second_intents(),
		"phase 2 announces the slot-1 middle attack before the slot-2 Weak")

	# Phase 2: slot-1 attack 2 hits current slot 2 (Tinker), then Weak 1 follows.
	var turn2 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(turn2.get("ok") == true, "phase 2 succeeds")
	_check(turn2.get("events") == [
		{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
		{"type": "debuff", "enemy_position": 2, "target_position": 2, "status": "weak",
			"applied": true}],
		"phase 2 events: slot-1 middle attack then slot-2 Weak, both applied")
	_check_hero(party, 1, "warden", 40, 6, {}, "phase 2")
	_check_hero(party, 2, "tinker", 24, 0, {"weak": 1}, "phase 2")
	_check_hero(party, 3, "seamstress", 28, 0, {}, "phase 2")
	_check_enemy(enemies, 1, "spool_stalker", 14, 0, "phase 2")
	_check_enemy(enemies, 2, "seam_ripper", 18, 0, "phase 2")

	_check(scheduler.advance_turn(), "explicit advance to phase 3")
	_check(scheduler.get_intents() == _third_intents(),
		"phase 3 announces the slot-1 Block before the slot-2 front attack")

	# Phase 3: slot-1 Block 1 stays on Spool Stalker; slot-2 attack 2 is absorbed by
	# the Warden's still-unspent opening Block, so his HP is untouched.
	var turn3 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(turn3.get("ok") == true, "phase 3 succeeds")
	_check(turn3.get("events") == [
		{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true}],
		"phase 3 events: slot-1 Block then slot-2 front attack, both applied")
	_check_hero(party, 1, "warden", 40, 4, {}, "phase 3")
	_check_hero(party, 2, "tinker", 24, 0, {"weak": 1}, "phase 3")
	_check_hero(party, 3, "seamstress", 28, 0, {}, "phase 3")
	_check_enemy(enemies, 1, "spool_stalker", 14, 1, "phase 3")
	_check_enemy(enemies, 2, "seam_ripper", 18, 0, "phase 3")

	_check(scheduler.advance_turn(), "explicit advance past the third beat")
	_check(scheduler.get_intents() == _first_intents(),
		"after exactly three advances the schedule announces its first intents again")


## AC3: two independently constructed copies of the same authored data agree in
## every event and every surviving field over the whole three-phase timeline.
func _play_three_phases() -> Dictionary:
	var party := _build_authored_party()
	var enemies := _build_authored_enemies()
	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "replay precondition: Warden opening Block applies")
	var scheduler := CombatEnemyIntents.new(_parsed())
	var results: Array = []
	for turn in range(3):
		results.append(phase.execute_phase(party, enemies, scheduler.get_intents()))
		_check(scheduler.advance_turn(), "replay advance after phase %d" % (turn + 1))
	return {"phases": results, "heroes": party.get_heroes(), "enemies": enemies.get_enemies(),
		"repeating": scheduler.get_intents(), "turn_index": scheduler._turn_index}


func _test_double_replay() -> void:
	seed(20261021)
	var expected_rng := randi()
	seed(20261021)
	var first := _play_three_phases()
	_check(randi() == expected_rng,
		"three real authored phases draw no global RNG")
	var second := _play_three_phases()
	_check(first["phases"].size() == 3 and second["phases"].size() == 3,
		"each replay resolved exactly three enemy phases")
	_check(first["heroes"].size() == 3 and first["enemies"].size() == 2,
		"each replay ends with the complete authored formation")
	# Literal end state, so two equally broken runs cannot satisfy the comparison below.
	_check(first["heroes"][0]["id"] == "warden" and first["heroes"][0]["hp"] == 40
		and first["heroes"][0]["block"] == 4 and first["heroes"][0].get("statuses", {}) == {}
		and first["heroes"][1]["id"] == "tinker" and first["heroes"][1]["hp"] == 24
		and first["heroes"][1]["block"] == 0
		and first["heroes"][1].get("statuses", {}) == {"weak": 1}
		and first["heroes"][2]["id"] == "seamstress" and first["heroes"][2]["hp"] == 28
		and first["heroes"][2]["block"] == 0 and first["heroes"][2].get("statuses", {}) == {},
		"replay end state is Warden 40/4, Tinker 24/0 with Weak 1, Seamstress 28/0")
	_check(first["enemies"][0]["id"] == "spool_stalker" and first["enemies"][0]["hp"] == 14
		and first["enemies"][0]["block"] == 1
		and first["enemies"][1]["id"] == "seam_ripper" and first["enemies"][1]["hp"] == 18
		and first["enemies"][1]["block"] == 0,
		"replay end state is Spool Stalker 14/1 and Seam Ripper 18/0")
	_check(first["repeating"] == _first_intents() and second["repeating"] == _first_intents()
		and first["turn_index"] == 3 and second["turn_index"] == 3,
		"both copies return to the first announced intents after exactly three advances")
	_check(first["phases"] == second["phases"],
		"two independently constructed copies produce identical phase results")
	_check(first["heroes"] == second["heroes"] and first["enemies"] == second["enemies"],
		"two independently constructed copies end in identical party and enemy state")
	_check(first["heroes"] == _play_three_phases()["heroes"],
		"a third fresh construction reproduces the same literal party end state")


## Deep copy of the prescription with one beat replaced in place.
func _with_beat(position: int, beat: int, replacement: Dictionary) -> Array:
	var data: Array = _expected().duplicate(true)
	for entry in data:
		if entry["enemy_position"] == position:
			var pattern: Array = entry["pattern"]
			pattern[beat] = replacement
	return data


## AC3: malformed data and an illegal second phase fail closed without a half-applied
## effect, keeping every actor snapshot, the intent index and the RNG exactly as they were.
func _test_negative_rejections() -> void:
	# Malformed schedule variants: rejected by the canonical loader and the intent validator.
	var malformed: Array = []
	malformed.append({"label": "slot-1 shove amount 1",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 1, "target_position": 2,
			"direction": 1})})
	malformed.append({"label": "slot-1 shove without direction",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 2})})
	malformed.append({"label": "slot-1 shove direction 0",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 2,
			"direction": 0})})
	malformed.append({"label": "slot-1 shove direction 2",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 2,
			"direction": 2})})
	malformed.append({"label": "slot-1 shove fractional direction 1.5",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 2,
			"direction": 1.5})})
	malformed.append({"label": "slot-1 shove off the front edge",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 1,
			"direction": -1})})
	malformed.append({"label": "slot-1 shove with extra key",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 2,
			"direction": 1, "extra": 1})})
	malformed.append({"label": "slot-1 attack without target_position",
		"data": _with_beat(1, 1, {"type": "attack", "amount": 2})})
	malformed.append({"label": "slot-1 attack target 0",
		"data": _with_beat(1, 1, {"type": "attack", "amount": 2, "target_position": 0})})
	malformed.append({"label": "slot-1 attack target 4",
		"data": _with_beat(1, 1, {"type": "attack", "amount": 2, "target_position": 4})})
	malformed.append({"label": "slot-1 attack amount -1",
		"data": _with_beat(1, 1, {"type": "attack", "amount": -1, "target_position": 2})})
	malformed.append({"label": "slot-1 attack amount string",
		"data": _with_beat(1, 1, {"type": "attack", "amount": "2", "target_position": 2})})
	malformed.append({"label": "slot-1 attack amount 1.5",
		"data": _with_beat(1, 1, {"type": "attack", "amount": 1.5, "target_position": 2})})
	malformed.append({"label": "slot-1 attack target 2.5",
		"data": _with_beat(1, 1, {"type": "attack", "amount": 2, "target_position": 2.5})})
	malformed.append({"label": "slot-1 Block with a target",
		"data": _with_beat(1, 2, {"type": "block", "amount": 1, "target_position": 1})})
	malformed.append({"label": "slot-2 Weak without status",
		"data": _with_beat(2, 1, {"type": "debuff", "amount": 1, "target_position": 2})})
	malformed.append({"label": "slot-2 Weak with unknown status",
		"data": _with_beat(2, 1, {"type": "debuff", "amount": 1, "target_position": 2,
			"status": "poison"})})
	malformed.append({"label": "slot-2 Weak amount 0",
		"data": _with_beat(2, 1, {"type": "debuff", "amount": 0, "target_position": 2,
			"status": "weak"})})
	malformed.append({"label": "slot-2 attack without target_position",
		"data": _with_beat(2, 2, {"type": "attack", "amount": 2})})
	var empty_pattern: Array = _expected().duplicate(true)
	empty_pattern[0]["pattern"].clear()
	malformed.append({"label": "empty slot-1 pattern", "data": empty_pattern})
	var duplicate_positions: Array = _expected().duplicate(true)
	duplicate_positions[1]["enemy_position"] = 1
	malformed.append({"label": "duplicate source position", "data": duplicate_positions})
	var zero_position: Array = _expected().duplicate(true)
	zero_position[0]["enemy_position"] = 0
	malformed.append({"label": "source position 0", "data": zero_position})
	for entry_case in malformed:
		_check(RunFightEncounterSelection._parse_schedule_text(
			JSON.stringify(entry_case["data"])).is_empty(),
			"negative: " + entry_case["label"] + " is rejected by the JSON loader")
		_check(not CombatEnemyIntents.new(entry_case["data"]).is_valid(),
			"negative: " + entry_case["label"] + " is rejected by the intent validator")
	for broken_text in ["{", "{}", "[]"]:
		_check(RunFightEncounterSelection._parse_schedule_text(broken_text).is_empty(),
			"negative: unparsable/empty schedule text %s is rejected" % broken_text)
	# Controls, so the rejections above cannot pass vacuously.
	_check(_parsed() == _expected(), "negative: the unmodified authored file still parses exactly")
	_check(CombatEnemyIntents.new(_expected()).is_valid(),
		"negative: the unmodified prescription is still a valid schedule")
	_check(_with_beat(1, 1, {"type": "attack", "amount": 2, "target_position": 3}) != _expected(),
		"negative: the beat mutation helper really produces a different schedule")

	# The critical fail-closed case: after the real first shove, Tinker sits at slot 2
	# with 1 HP, so phase 2's slot-1 attack would down him and the slot-2 Weak must fail.
	var party := _build_authored_party()
	var enemies := _build_authored_enemies()
	_check(CombatStartingBlock.new(party).apply(), "negative: opening Block applied")
	var scheduler := CombatEnemyIntents.new(_parsed())
	_check(phase.execute_phase(party, enemies, scheduler.get_intents()).get("ok") == true,
		"negative: the real first phase with the shove succeeds")
	_check(scheduler.advance_turn(), "negative: advance to the authored second phase")
	_check(party.get_hero(2).get("id") == "tinker" and party.get_hero(2).get("position") == 2
		and party.get_hero(2).get("hp") == 26,
		"negative: the real shove moved Tinker into the middle slot")
	_check(party.apply_damage(2, 25), "negative: the moved Tinker is placed at 1 HP")
	_check_hero(party, 2, "tinker", 1, 0, {}, "negative setup")
	var before_party: Array = party.get_heroes()
	var before_enemies: Array = enemies.get_enemies()
	var before_turn: int = scheduler._turn_index
	var downed_intents: Array = scheduler.get_intents()
	var downed_input: Array = downed_intents.duplicate(true)
	_check(downed_intents == _second_intents(),
		"negative: phase 2 really announces the middle attack and Weak")
	seed(20261021)
	var expected_rng := randi()
	seed(20261021)
	var downed_result := phase.execute_phase(party, enemies, downed_intents)
	_check(randi() == expected_rng, "negative: the rejected phase draws no global RNG")
	_check(downed_result == {"ok": false, "events": []},
		"negative: downing the Weak target rejects the whole second phase")
	_check(party.get_heroes() == before_party and party.get_hero(2).get("hp") == 1,
		"negative: no hero HP, Block, position or status survives the rejected phase")
	_check(party.get_hero(2).get("id") == "tinker" and party.get_hero(2).get("statuses", {}) == {},
		"negative: the rejected Weak never lands on the middle hero")
	_check(enemies.get_enemies() == before_enemies,
		"negative: no enemy HP or Block changes survive the rejected phase")
	_check(downed_intents == downed_input, "negative: the rejected phase leaves caller intents untouched")
	_check(scheduler._turn_index == before_turn
		and scheduler.get_intents() == _second_intents(),
		"negative: the rejected phase leaves the intent index on the second beat")

	# Positive control for the same fixture: 3 HP leaves the attack non-lethal, so the
	# phase commits the attack and the Weak, proving the rejection above was the downing.
	var control_party := _build_authored_party()
	var control_enemies := _build_authored_enemies()
	_check(CombatStartingBlock.new(control_party).apply(), "control: opening Block applied")
	var control_scheduler := CombatEnemyIntents.new(_parsed())
	_check(phase.execute_phase(control_party, control_enemies,
		control_scheduler.get_intents()).get("ok") == true, "control: first phase succeeds")
	_check(control_scheduler.advance_turn(), "control: advance to phase 2")
	_check(control_party.apply_damage(2, 23), "control: the moved Tinker is placed at 3 HP")
	var control := phase.execute_phase(control_party, control_enemies, control_scheduler.get_intents())
	_check(control.get("ok") == true and control.get("events") == [
		{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
		{"type": "debuff", "enemy_position": 2, "target_position": 2, "status": "weak",
			"applied": true}],
		"control: the same phase commits when its attack leaves the Weak target alive")
	_check_hero(control_party, 2, "tinker", 1, 0, {"weak": 1}, "control")
