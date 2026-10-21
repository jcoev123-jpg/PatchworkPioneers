extends SceneTree

## Deterministic headless coverage for the authored Rearline Needlemark encounter:
## slot 1 Fray Scavenger opens with Exposed on the rear hero before slot 2 Seam Ripper's focused attack.
## Data/service only: this file never wires the encounter into live play.

const ENCOUNTER_PATH := "res://data/encounters/rearline_needlemark.json"
const ENCOUNTER_ID := "rearline_needlemark"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMY_PATH := "res://data/enemies/run_enemies.json"

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_authored_schedule_and_parser()
	_test_intent_cycle_and_copies()
	_test_real_phase_sequence()
	_test_double_replay()
	_test_negative_rejections()
	if failures.is_empty():
		print("rearline_needlemark_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("rearline_needlemark_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## The exact prescribed schedule for this encounter's own two sources.
func _expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed"},
			{"type": "block", "amount": 2},
			{"type": "attack", "amount": 2, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 4, "target_position": 3},
			{"type": "attack", "amount": 3, "target_position": 1},
			{"type": "buff", "amount": 2}]}
	]


## Literal announced beats, independent of the parsed file and of _expected().
func _first_intents() -> Array:
	return [
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed",
			"enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 3, "enemy_position": 2}]


func _second_intents() -> Array:
	return [
		{"type": "block", "amount": 2, "enemy_position": 1},
		{"type": "attack", "amount": 3, "target_position": 1, "enemy_position": 2}]


func _third_intents() -> Array:
	return [
		{"type": "attack", "amount": 2, "target_position": 2, "enemy_position": 1},
		{"type": "buff", "amount": 2, "enemy_position": 2}]


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "opens " + path)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _load_json(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(_read_text(path))
	if not parsed is Array:
		return []
	return _normalize_json(parsed)


## Godot's JSON parser yields whole numbers as floats; the real model services
## require ints for max_hp, so authored fixtures are normalized exactly.
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
			if value is float and value == int(value):
				value = int(value)
			else:
				value = _normalize_json(value)
			result[key] = value
		return result
	if data is float and data == int(data):
		return int(data)
	return data


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


func _check_hero(party: CombatParty, position: int, hp: int, block: int, label: String) -> void:
	var hero := party.get_hero(position)
	_check(hero.get("hp") == hp and hero.get("block") == block,
		"%s: hero %d has %d HP and %d Block (got %d/%d)"
			% [label, position, hp, block, hero.get("hp"), hero.get("block")])


func _check_enemy(enemies: CombatEnemies, position: int, id: String, hp: int, block: int,
		label: String) -> void:
	var enemy := enemies.get_enemy(position)
	_check(enemy.get("id") == id and enemy.get("hp") == hp and enemy.get("block") == block,
		"%s: enemy %d is %s with %d HP and %d Block (got %s %d/%d)"
			% [label, position, id, hp, block, enemy.get("id"), enemy.get("hp"), enemy.get("block")])


func _build_authored_party() -> CombatParty:
	var heroes := _load_json(PARTY_PATH)
	var definitions: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		var matches: Array = []
		for hero in heroes:
			if hero is Dictionary and hero.get("id") == id:
				matches.append(hero)
		_check(matches.size() == 1, "authored hero %s found once" % id)
		definitions.append({} if matches.is_empty() else matches[0].duplicate(true))
	return CombatParty.new(definitions)


func _build_authored_enemies() -> CombatEnemies:
	var enemies := _load_json(ENEMY_PATH)
	var definitions: Array = []
	for id in ["fray_scavenger", "seam_ripper"]:
		var matches: Array = []
		for enemy in enemies:
			if enemy is Dictionary and enemy.get("id") == id:
				matches.append(enemy)
		_check(matches.size() == 1, "authored enemy %s found once" % id)
		definitions.append({} if matches.is_empty() else matches[0].duplicate(true))
	return CombatEnemies.new(definitions)


## AC1: the shipped file is exactly the prescribed two-source, three-beat schedule,
## and the earlier named exposed_hem_pincer schedule still behaves by its own data.
func _test_authored_schedule_and_parser() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "new authored encounter file exists")
	_check(ENCOUNTER_PATH.get_file().get_basename() == ENCOUNTER_ID,
		"the schedule file name carries the canonical encounter ID %s" % ENCOUNTER_ID)
	var raw: Variant = JSON.parse_string(_read_text(ENCOUNTER_PATH))
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

	# The named actors really exist with the stats this schedule is authored against.
	var roster := _load_json(ENEMY_PATH)
	for expected_actor in [{"id": "fray_scavenger", "name": "Fray Scavenger", "max_hp": 14},
			{"id": "seam_ripper", "name": "Seam Ripper", "max_hp": 18}]:
		var matches: Array = []
		for enemy in roster:
			if enemy is Dictionary and enemy.get("id") == expected_actor["id"]:
				matches.append(enemy)
		_check(matches.size() == 1, "shipped enemy %s exists exactly once" % expected_actor["id"])
		if matches.size() == 1:
			_check(matches[0].get("name") == expected_actor["name"]
				and matches[0].get("max_hp") == expected_actor["max_hp"],
				"shipped enemy %s is %s with %d max HP"
					% [expected_actor["id"], expected_actor["name"], expected_actor["max_hp"]])

	var party := _build_authored_party()
	_check(party.is_valid(), "shipped starter party builds a real three-hero party")
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("max_hp") == 40
		and party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("max_hp") == 30
		and party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("max_hp") == 26,
		"starter party is Warden/Seamstress/Tinker at 40/30/26 HP in positions 1/2/3")

	# Earlier named schedule stays parsable and is unchanged, identified by its own data only.
	var exposed_hem := RunFightEncounterSelection._parse_schedule_text(
		_read_text("res://data/encounters/exposed_hem_pincer.json"))
	_check(CombatEnemyIntents.new(exposed_hem).is_valid(), "exposed_hem_pincer still valid")
	_check_entry(exposed_hem, 1, [
		{"type": "debuff", "amount": 1, "target_position": 1, "status": "exposed"},
		{"type": "attack", "amount": 1, "target_position": 2},
		{"type": "block", "amount": 1}])
	_check_entry(exposed_hem, 2, [
		{"type": "attack", "amount": 2, "target_position": 1},
		{"type": "buff", "amount": 2},
		{"type": "attack", "amount": 1, "target_position": 3}])
	_check(exposed_hem != parsed,
		"the new schedule differs from exposed_hem_pincer")


## AC1/AC3: three announced beats in ascending source order, then an exact repeat,
## with no run/global RNG consumption and no aliasing of caller data.
func _test_intent_cycle_and_copies() -> void:
	var definitions := _parsed()
	var intents := CombatEnemyIntents.new(definitions)
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
## party and roster, one explicit advance per turn.
func _test_real_phase_sequence() -> void:
	var party := _build_authored_party()
	_check(party.is_valid(), "authored party is valid")
	var enemies := _build_authored_enemies()
	_check(enemies.is_valid(), "authored two-enemy roster is valid")
	_check_enemy(enemies, 1, "fray_scavenger", 14, 0, "start")
	_check_enemy(enemies, 2, "seam_ripper", 18, 0, "start")

	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "Warden opening Block 6 applies once")
	_check_hero(party, 1, 40, 6, "opening")
	_check(not opening.apply(), "opening Block cannot be applied twice")

	var scheduler := CombatEnemyIntents.new(_parsed())
	_check(scheduler.get_intents() == _first_intents(), "T1 announces Exposed then attack")

	# Turn 1: slot 1 Exposed 1 lands before slot 2's attack 4 -> floor(4 * 1.5) = 6.
	var turn1 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(turn1.get("ok") == true, "T1 phase succeeds")
	_check(turn1.get("events") == [
		{"type": "debuff", "enemy_position": 1, "target_position": 3, "status": "exposed",
			"applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true}],
		"T1 events: slot-1 Exposed then slot-2 attack, both applied")
	_check_hero(party, 1, 40, 6, "T1")
	_check_hero(party, 2, 30, 0, "T1")
	_check_hero(party, 3, 20, 0, "T1")
	_check(party.get_hero(3).get("statuses", {}) == {"exposed": 1},
		"T1 Tinker keeps exactly Exposed 1")
	_check(party.get_hero(1).get("statuses", {}) == {} and party.get_hero(2).get("statuses", {}) == {},
		"T1 only the debuffed hero carries a status")
	_check_enemy(enemies, 1, "fray_scavenger", 14, 0, "T1")
	_check_enemy(enemies, 2, "seam_ripper", 18, 0, "T1")

	_check(scheduler.advance_turn(), "explicit advance to turn 2")

	# Turn 2: slot 1 block 2; slot 2 attack 3 on the front hero.
	var turn2 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(turn2.get("ok") == true, "T2 phase succeeds")
	_check(turn2.get("events") == [
		{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true}],
		"T2 events: slot-1 Block then slot-2 attack on slot 1, both applied")
	_check_hero(party, 1, 40, 3, "T2")
	_check_hero(party, 2, 30, 0, "T2")
	_check_hero(party, 3, 20, 0, "T2")
	_check(party.get_hero(3).get("statuses", {}) == {"exposed": 1},
		"T2 Exposed 1 is retained: the enemy phase validates the owner tick but leaves status aging to the round flow")
	_check_enemy(enemies, 1, "fray_scavenger", 14, 2, "T2")
	_check_enemy(enemies, 2, "seam_ripper", 18, 0, "T2")

	_check(scheduler.advance_turn(), "explicit advance to turn 3")

	# Turn 3: slot 1 attack 2 on the middle hero; slot 2 buff 2 grants itself 2 Block.
	var turn3 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(turn3.get("ok") == true, "T3 phase succeeds")
	_check(turn3.get("events") == [
		{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
		{"type": "buff", "enemy_position": 2, "applied": true}],
		"T3 events: slot-1 attack on slot 2 then slot-2 self buff, both applied")
	_check_hero(party, 1, 40, 3, "T3")
	_check_hero(party, 2, 28, 0, "T3")
	_check_hero(party, 3, 20, 0, "T3")
	_check_enemy(enemies, 1, "fray_scavenger", 14, 2, "T3")
	_check_enemy(enemies, 2, "seam_ripper", 18, 2, "T3")

	_check(scheduler.advance_turn(), "explicit advance past the third beat")
	_check(scheduler.get_intents() == _first_intents(),
		"after exactly three advances the schedule announces its first intents again")


## AC3: two independently constructed copies of the same authored data agree in
## every event and every surviving field over the whole three-turn timeline.
func _play_three_turns() -> Dictionary:
	var party := _build_authored_party()
	var enemies := _build_authored_enemies()
	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "replay precondition: Warden opening Block applies")
	var scheduler := CombatEnemyIntents.new(_parsed())
	var events: Array = []
	for turn in range(3):
		events.append(phase.execute_phase(party, enemies, scheduler.get_intents()))
		_check(scheduler.advance_turn(), "replay advance after turn %d" % (turn + 1))
		# Note: no player turn Block resets or status ticks between consecutive enemy beats
		# unless explicitly testing the real owning turn boundary.
	return {"events": events, "heroes": party.get_heroes(), "enemies": enemies.get_enemies(),
		"repeating": scheduler.get_intents()}


func _test_double_replay() -> void:
	seed(20261021)
	var expected_rng := randi()
	seed(20261021)
	var first := _play_three_turns()
	_check(randi() == expected_rng,
		"three real authored phases draw no global RNG")
	var second := _play_three_turns()
	_check(first["events"].size() == 3 and second["events"].size() == 3,
		"each replay resolved exactly three enemy phases")
	_check(first["heroes"].size() == 3 and first["enemies"].size() == 2,
		"each replay ends with the complete authored formation")
	# Literal end state, so two equally broken runs cannot satisfy the comparison below.
	_check(first["heroes"][0]["hp"] == 40 and first["heroes"][0]["block"] == 3
		and first["heroes"][0].get("statuses", {}) == {}
		and first["heroes"][1]["hp"] == 28 and first["heroes"][1]["block"] == 0
		and first["heroes"][2]["hp"] == 20 and first["heroes"][2]["block"] == 0,
		"replay end state is Warden 40/3, Seamstress 28/0, Tinker 20/0")
	_check(first["enemies"][0]["id"] == "fray_scavenger" and first["enemies"][0]["hp"] == 14
		and first["enemies"][0]["block"] == 2
		and first["enemies"][1]["id"] == "seam_ripper" and first["enemies"][1]["hp"] == 18
		and first["enemies"][1]["block"] == 2,
		"replay end state is Fray Scavenger 14/2 and Seam Ripper 18/2")
	_check(first["repeating"] == _first_intents() and second["repeating"] == _first_intents(),
		"both copies return to the first announced intents on turn 4")
	_check(first["events"] == second["events"],
		"two independently constructed copies produce identical phase results")
	_check(first["heroes"] == second["heroes"] and first["enemies"] == second["enemies"],
		"two independently constructed copies end in identical party and enemy state")


## Deep copy of the prescription with one beat replaced in place.
func _with_beat(position: int, beat: int, replacement: Dictionary) -> Array:
	var data: Array = _expected().duplicate(true)
	for entry in data:
		if entry["enemy_position"] == position:
			var pattern: Array = entry["pattern"]
			pattern[beat] = replacement
	return data


## AC3: malformed data and illegal transactions fail closed without a half-applied
## effect, keeping every actor snapshot and the RNG exactly as they were.
func _test_negative_rejections() -> void:
	# Malformed schedule variants: rejected by the canonical loader and the intent validator.
	var malformed: Array = []
	malformed.append({"label": "slot-1 debuff without target_position",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": 1})})
	malformed.append({"label": "slot-1 debuff target 0",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": 1, "target_position": 0})})
	malformed.append({"label": "slot-1 debuff target 4",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": 1, "target_position": 4})})
	malformed.append({"label": "slot-1 debuff with extra key",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed", "extra": 1})})
	malformed.append({"label": "slot-1 debuff amount -1",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": -1, "target_position": 3, "status": "exposed"})})
	malformed.append({"label": "slot-1 debuff amount string",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": "1", "target_position": 3, "status": "exposed"})})
	malformed.append({"label": "slot-1 debuff amount 1.5",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": 1.5, "target_position": 3, "status": "exposed"})})
	malformed.append({"label": "slot-1 debuff target 2.5",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": 1, "target_position": 2.5, "status": "exposed"})})
	malformed.append({"label": "slot-1 Exposed without status",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": 1, "target_position": 3})})
	malformed.append({"label": "slot-1 Exposed with unknown status",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": 1, "target_position": 3,
			"status": "poison"})})
	malformed.append({"label": "slot-1 Exposed amount 0",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": 0, "target_position": 3,
			"status": "exposed"})})
	malformed.append({"label": "slot-1 block with a target",
		"data": _with_beat(1, 1, {"type": "block", "amount": 2, "target_position": 1})})
	malformed.append({"label": "slot-1 attack without target_position",
		"data": _with_beat(1, 2, {"type": "attack", "amount": 2})})
	malformed.append({"label": "slot-1 attack target 0",
		"data": _with_beat(1, 2, {"type": "attack", "amount": 2, "target_position": 0})})
	malformed.append({"label": "slot-1 attack target 4",
		"data": _with_beat(1, 2, {"type": "attack", "amount": 2, "target_position": 4})})
	malformed.append({"label": "slot-1 attack with extra key",
		"data": _with_beat(1, 2, {"type": "attack", "amount": 2, "target_position": 2, "extra": 1})})
	malformed.append({"label": "slot-1 attack amount -1",
		"data": _with_beat(1, 2, {"type": "attack", "amount": -1, "target_position": 2})})
	malformed.append({"label": "slot-1 attack amount string",
		"data": _with_beat(1, 2, {"type": "attack", "amount": "2", "target_position": 2})})
	malformed.append({"label": "slot-1 attack amount 1.5",
		"data": _with_beat(1, 2, {"type": "attack", "amount": 1.5, "target_position": 2})})
	malformed.append({"label": "slot-2 attack without target_position",
		"data": _with_beat(2, 0, {"type": "attack", "amount": 4})})
	malformed.append({"label": "slot-2 attack target 0",
		"data": _with_beat(2, 0, {"type": "attack", "amount": 4, "target_position": 0})})
	malformed.append({"label": "slot-2 attack target 4",
		"data": _with_beat(2, 0, {"type": "attack", "amount": 4, "target_position": 4})})
	malformed.append({"label": "slot-2 attack with extra key",
		"data": _with_beat(2, 0, {"type": "attack", "amount": 4, "target_position": 3, "extra": 1})})
	malformed.append({"label": "slot-2 attack amount -1",
		"data": _with_beat(2, 0, {"type": "attack", "amount": -1, "target_position": 3})})
	malformed.append({"label": "slot-2 attack amount string",
		"data": _with_beat(2, 0, {"type": "attack", "amount": "4", "target_position": 3})})
	malformed.append({"label": "slot-2 attack amount 1.5",
		"data": _with_beat(2, 0, {"type": "attack", "amount": 1.5, "target_position": 3})})
	malformed.append({"label": "slot-2 attack (beat 2) without target_position",
		"data": _with_beat(2, 1, {"type": "attack", "amount": 3})})
	malformed.append({"label": "slot-2 attack (beat 2) target 0",
		"data": _with_beat(2, 1, {"type": "attack", "amount": 3, "target_position": 0})})
	malformed.append({"label": "slot-2 attack (beat 2) target 4",
		"data": _with_beat(2, 1, {"type": "attack", "amount": 3, "target_position": 4})})
	malformed.append({"label": "slot-2 buff amount 0",
		"data": _with_beat(2, 2, {"type": "buff", "amount": 0})})
	malformed.append({"label": "slot-2 buff amount 2.5",
		"data": _with_beat(2, 2, {"type": "buff", "amount": 2.5})})
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
	# Controls, so the rejections above cannot pass vacuously.
	_check(_parsed() == _expected(), "negative: the unmodified authored file still parses exactly")
	_check(CombatEnemyIntents.new(_expected()).is_valid(),
		"negative: the unmodified prescription is still a valid schedule")
	_check(_with_beat(1, 1, {"type": "block", "amount": 1, "target_position": 1}) != _expected(),
		"negative: the beat mutation helper really produces a different schedule")

	# A downed Exposed target fails the whole transaction, after slot-order staging.
	var party := _build_authored_party()
	var enemies := _build_authored_enemies()
	_check(CombatStartingBlock.new(party).apply(), "negative: opening Block applied")
	_check(party.apply_damage(3, 26) and party.is_downed(3), "negative: Tinker is downed")
	var scheduler := CombatEnemyIntents.new(_parsed())
	var downed_intents := scheduler.get_intents()
	var downed_input := downed_intents.duplicate(true)
	var before_party := party.get_heroes()
	var before_enemies := enemies.get_enemies()
	seed(20261021)
	var expected_rng := randi()
	seed(20261021)
	var downed_result := phase.execute_phase(party, enemies, downed_intents)
	_check(randi() == expected_rng, "negative: a rejected phase draws no global RNG")
	_check(downed_result == {"ok": false, "events": []},
		"negative: Exposed on a downed hero rejects the whole phase")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"negative: a rejected downed-target phase changes no hero or enemy")
	_check(downed_intents == downed_input, "negative: a rejected phase leaves caller intents untouched")

	# A downed source skips its action.
	party = _build_authored_party()
	enemies = _build_authored_enemies()
	_check(CombatStartingBlock.new(party).apply(), "negative: second opening Block applied")
	_check(enemies.apply_damage(1, 14) and enemies.is_slain(1), "negative: Fray Scavenger is slain")
	scheduler = CombatEnemyIntents.new(_parsed())
	var slain_source_intents := scheduler.get_intents()
	var slain_source_input := slain_source_intents.duplicate(true)
	before_party = party.get_heroes()
	before_enemies = enemies.get_enemies()
	seed(20261021)
	expected_rng = randi()
	seed(20261021)
	var slain_source_result := phase.execute_phase(party, enemies, slain_source_intents)
	_check(randi() == expected_rng, "negative: a slain source draws no global RNG")
	_check(slain_source_result.get("ok") == true, "negative: phase with slain source succeeds")
	_check(slain_source_result.get("events") == [
		{"type": "debuff", "enemy_position": 1, "target_position": 3, "status": "exposed", "applied": false},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true}],
		"negative: slain Fray Scavenger skips Exposed; Seam Ripper deals 4 damage to Tinker (no Exposed)")
	_check_hero(party, 1, 40, 6, "slain source")
	_check_hero(party, 2, 30, 0, "slain source")
	_check_hero(party, 3, 22, 0, "slain source")
	_check(party.get_hero(3).get("statuses", {}) == {},
		"negative: no Exposed applied when source is slain")
	_check(enemies.get_enemy(1).get("hp") == 0 and enemies.get_enemy(2).get("hp") == 18,
		"negative: enemies unchanged")
	_check(slain_source_intents == slain_source_input,
		"negative: the slain-source phase leaves caller intents untouched")

	# A later source's overflow fails the transaction after the earlier attack was staged.
	party = _build_authored_party()
	enemies = _build_authored_enemies()
	_check(CombatStartingBlock.new(party).apply(), "negative: third opening Block applied")
	_check(enemies.gain_block(2, CombatEnemies.MAX_INT - 1),
		"negative: Seam Ripper sits one short of maximum Block")
	scheduler = CombatEnemyIntents.new(_parsed())
	_check(scheduler.advance_turn(), "negative: advance to the turn-2 beats")
	_check(scheduler.advance_turn(), "negative: advance to the turn-3 beats")
	var overflow_intents := scheduler.get_intents()
	var overflow_input := overflow_intents.duplicate(true)
	before_party = party.get_heroes()
	before_enemies = enemies.get_enemies()
	seed(20261021)
	expected_rng = randi()
	seed(20261021)
	var overflow_result := phase.execute_phase(party, enemies, overflow_intents)
	_check(randi() == expected_rng, "negative: the failed late buff draws no global RNG")
	_check(overflow_result == {"ok": false, "events": []},
		"negative: an overflowing slot-2 buff rejects the whole phase")
	_check(party.get_heroes() == before_party and party.get_hero(2).get("hp") == 30,
		"negative: the earlier slot-1 attack does not partially land")
	_check(enemies.get_enemies() == before_enemies
		and enemies.get_enemy(2).get("block") == CombatEnemies.MAX_INT - 1,
		"negative: no enemy Block or HP change survives the failed transaction")
	_check(overflow_intents == overflow_input,
		"negative: the overflowing phase leaves caller intents untouched")

	# A source outside the two-enemy roster and a malformed action both fail closed.
	party = _build_authored_party()
	enemies = _build_authored_enemies()
	_check(CombatStartingBlock.new(party).apply(), "negative: fourth opening Block applied")
	before_party = party.get_heroes()
	before_enemies = enemies.get_enemies()
	var outside := _first_intents()
	outside.append({"type": "block", "amount": 1, "enemy_position": 3})
	_check(phase.execute_phase(party, enemies, outside) == {"ok": false, "events": []},
		"negative: a source outside the roster rejects the phase")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"negative: the out-of-roster phase changes nothing")
	var bad_action := _first_intents()
	bad_action[1]["amount"] = "4"
	_check(phase.execute_phase(party, enemies, bad_action) == {"ok": false, "events": []},
		"negative: a malformed slot-2 action rejects the phase")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"negative: the malformed phase applies no Exposed and no damage")