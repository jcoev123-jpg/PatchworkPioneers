extends SceneTree

## Deterministic headless coverage for the authored Hemknot Weakguard encounter:
## two enemies, three beats, Block and Weak, data/service boundary only.

const ENCOUNTER_PATH := "res://data/encounters/hemknot_weakguard.json"
const ENCOUNTER_ID := "hemknot_weakguard"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMY_PATH := "res://data/enemies/run_enemies.json"
const STARTER_ATTACKS_PATH := "res://data/encounters/starter_attacks.json"
const REARLINE_PATH := "res://data/encounters/rearline_needlemark.json"

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_authored_schedule_and_parser()
	_test_typed_roster()
	_test_intent_cycle_and_copies()
	_test_real_phase_sequence()
	_test_double_replay()
	_test_negative_rejections()
	_test_weak_status()
	if failures.is_empty():
		print("hemknot_weakguard_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("hemknot_weakguard_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


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


func _expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 4, "target_position": 1},
			{"type": "block", "amount": 3},
			{"type": "attack", "amount": 3, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
			{"type": "attack", "amount": 3, "target_position": 3},
			{"type": "buff", "amount": 2}]}
	]


func _first_intents() -> Array:
	return [
		{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 1},
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak", "enemy_position": 2}]


func _second_intents() -> Array:
	return [
		{"type": "block", "amount": 3, "enemy_position": 1},
		{"type": "attack", "amount": 3, "target_position": 3, "enemy_position": 2}]


func _third_intents() -> Array:
	return [
		{"type": "attack", "amount": 3, "target_position": 2, "enemy_position": 1},
		{"type": "buff", "amount": 2, "enemy_position": 2}]


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
	for id in ["button_guard", "seam_ripper"]:
		var matches: Array = []
		for enemy in enemies:
			if enemy is Dictionary and enemy.get("id") == id:
				matches.append(enemy)
		_check(matches.size() == 1, "authored enemy %s found once" % id)
		definitions.append({} if matches.is_empty() else matches[0].duplicate(true))
	return CombatEnemies.new(definitions)


func _with_beat(position: int, beat: int, replacement: Dictionary) -> Array:
	var data: Array = _expected().duplicate(true)
	for entry in data:
		if entry["enemy_position"] == position:
			var pattern: Array = entry["pattern"]
			pattern[beat] = replacement
	return data


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

	var roster := _load_json(ENEMY_PATH)
	for expected_actor in [{"id": "button_guard", "name": "Button Guard", "max_hp": 16},
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

	var starter := RunFightEncounterSelection._parse_schedule_text(_read_text(STARTER_ATTACKS_PATH))
	_check(CombatEnemyIntents.new(starter).is_valid(), "starter_attacks still parses and validates")
	var rearline := RunFightEncounterSelection._parse_schedule_text(_read_text(REARLINE_PATH))
	_check(CombatEnemyIntents.new(rearline).is_valid(), "rearline_needlemark still parses and validates")
	_check(parsed != starter and parsed != rearline, "the new schedule differs from named existing schedules")


func _test_typed_roster() -> void:
	var typed_choice := {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": _parsed().duplicate(true),
	}
	var choice_before := typed_choice.duplicate(true)
	var roster_bridge := RunTypedBattleRoster.new()
	var assembled := roster_bridge.assemble(typed_choice, {ENCOUNTER_ID: ["button_guard", "seam_ripper"]}, [ENEMY_PATH])
	_check(typed_choice == choice_before, "RunTypedBattleRoster.assemble must not mutate caller typed_choice")
	_check(assembled.get("ok") == true
		and assembled.get("node_type") == "Fight"
		and assembled.get("encounter_id") == ENCOUNTER_ID
		and assembled.get("definitions") == _expected(),
		"typed Fight choice assembles ok with Fight node_type and exact definitions")
	var assembled_enemies: Variant = assembled.get("enemies")
	_check(assembled_enemies is CombatEnemies and assembled_enemies.is_valid(),
		"assembled enemies must be a valid CombatEnemies instance")
	if assembled_enemies is CombatEnemies:
		_check(assembled_enemies.get_enemies().size() == 2, "assembled roster has exactly 2 slots")
		_check(assembled_enemies.get_enemy(1).get("id") == "button_guard"
			and assembled_enemies.get_enemy(1).get("max_hp") == 16
			and assembled_enemies.get_enemy(1).get("hp") == 16
			and assembled_enemies.get_enemy(1).get("block") == 0,
			"slot 1 assembled enemy is Button Guard with 16 HP")
		_check(assembled_enemies.get_enemy(2).get("id") == "seam_ripper"
			and assembled_enemies.get_enemy(2).get("max_hp") == 18
			and assembled_enemies.get_enemy(2).get("hp") == 18
			and assembled_enemies.get_enemy(2).get("block") == 0,
			"slot 2 assembled enemy is Seam Ripper with 18 HP")
	# negative roster assembly
	_check(roster_bridge.assemble(typed_choice, {ENCOUNTER_ID: ["button_guard"]}, [ENEMY_PATH]) == {"ok": false},
		"mismatched 1-enemy roster for 2-source encounter is rejected")
	_check(roster_bridge.assemble(typed_choice, {ENCOUNTER_ID: ["button_guard", "button_guard"]}, [ENEMY_PATH]) == {"ok": false},
		"duplicate enemy IDs in typed roster are rejected")
	_check(roster_bridge.assemble(typed_choice, {ENCOUNTER_ID: ["button_guard", "unknown_enemy"]}, [ENEMY_PATH]) == {"ok": false},
		"unknown enemy ID in typed roster is rejected")


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

	for turn in range(4):
		var announced := intents.get_intents()
		_check(announced.size() == 2 and announced[0].get("enemy_position") == 1
			and announced[1].get("enemy_position") == 2,
			"announcement %d lists slot 1 then slot 2" % (turn + 1))
		intents.advance_turn()

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


func _test_real_phase_sequence() -> void:
	var party := _build_authored_party()
	_check(party.is_valid(), "authored party is valid")
	var enemies := _build_authored_enemies()
	_check(enemies.is_valid(), "authored two-enemy roster is valid")
	_check(enemies.get_enemy(1).get("id") == "button_guard" and enemies.get_enemy(1).get("max_hp") == 16,
		"enemy slot 1 is Button Guard with 16 HP")
	_check(enemies.get_enemy(2).get("id") == "seam_ripper" and enemies.get_enemy(2).get("max_hp") == 18,
		"enemy slot 2 is Seam Ripper with 18 HP")

	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "Warden opening Block 6 applies once")
	_check_hero(party, 1, 40, 6, "opening")
	_check(not opening.apply(), "opening Block cannot be applied twice")

	var scheduler := CombatEnemyIntents.new(_parsed())
	_check(scheduler.get_intents() == _first_intents(), "T1 announces attack then Weak")

	# Turn 1
	var turn1 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(turn1.get("ok") == true, "T1 phase succeeds")
	_check(turn1.get("events") == [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
		{"type": "debuff", "enemy_position": 2, "target_position": 3, "status": "weak", "applied": true}],
		"T1 events: slot-1 attack then slot-2 Weak, both applied")
	_check_hero(party, 1, 40, 2, "T1")
	_check_hero(party, 2, 30, 0, "T1")
	_check_hero(party, 3, 26, 0, "T1")
	_check(party.get_hero(1).get("statuses", {}) == {}, "T1 Warden has no status")
	_check(party.get_hero(3).get("statuses", {}) == {"weak": 1}, "T1 Tinker has Weak 1")
	_check(enemies.get_enemy(1).get("block") == 0, "T1 Button Guard has 0 Block")
	_check(enemies.get_enemy(2).get("block") == 0, "T1 Seam Ripper has 0 Block")

	_check(scheduler.advance_turn(), "explicit advance to turn 2")
	_check(party.start_player_turn(), "player turn resets hero Block")
	_check_hero(party, 1, 40, 0, "T2 opening")
	_check(party.get_hero(3).get("statuses", {}) == {"weak": 1},
		"player Block reset does not consume Weak status")

	# Turn 2
	var turn2 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(turn2.get("ok") == true, "T2 phase succeeds")
	_check(turn2.get("events") == [
		{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true}],
		"T2 events: slot-1 Block then slot-2 attack, both applied")
	_check_hero(party, 1, 40, 0, "T2")
	_check_hero(party, 2, 30, 0, "T2")
	_check_hero(party, 3, 23, 0, "T2")
	_check(enemies.get_enemy(1).get("id") == "button_guard" and enemies.get_enemy(1).get("block") == 3,
		"T2 Button Guard has 3 Block")
	_check(enemies.get_enemy(2).get("block") == 0, "T2 Seam Ripper has 0 Block")

	_check(scheduler.advance_turn(), "explicit advance to turn 3")
	_check(party.start_player_turn(), "second player turn resets hero Block")

	# Turn 3
	var turn3 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(turn3.get("ok") == true, "T3 phase succeeds")
	_check(turn3.get("events") == [
		{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
		{"type": "buff", "enemy_position": 2, "applied": true}],
		"T3 events: slot-1 attack then slot-2 self buff, both applied")
	_check_hero(party, 1, 40, 0, "T3")
	_check_hero(party, 2, 27, 0, "T3")
	_check_hero(party, 3, 23, 0, "T3")
	_check(enemies.get_enemy(1).get("block") == 3, "T3 Button Guard retains 3 Block")
	_check(enemies.get_enemy(2).get("block") == 2, "T3 Seam Ripper has 2 Block")

	_check(scheduler.advance_turn(), "explicit advance past the third beat")
	_check(scheduler.get_intents() == _first_intents(),
		"after exactly three advances the schedule announces its first intents again")


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
		if turn < 2:
			_check(party.start_player_turn(), "replay player reset after turn %d" % (turn + 1))
	return {"events": events, "heroes": party.get_heroes(), "enemies": enemies.get_enemies(),
		"repeating": scheduler.get_intents()}


func _test_double_replay() -> void:
	seed(20261021)
	var expected_rng := randi()
	seed(20261021)
	var first := _play_three_turns()
	_check(randi() == expected_rng, "three real authored phases draw no global RNG")
	var second := _play_three_turns()
	_check(first["events"].size() == 3 and second["events"].size() == 3,
		"each replay resolved exactly three enemy phases")
	_check(first["heroes"].size() == 3 and first["enemies"].size() == 2,
		"each replay ends with the complete authored formation")
	_check(first["heroes"][0]["hp"] == 40 and first["heroes"][0]["block"] == 0
		and first["heroes"][0].get("statuses", {}) == {}
		and first["heroes"][1]["hp"] == 27 and first["heroes"][1]["block"] == 0
		and first["heroes"][1].get("statuses", {}) == {}
		and first["heroes"][2]["hp"] == 23 and first["heroes"][2]["block"] == 0
		and first["heroes"][2].get("statuses", {}) == {"weak": 1},
		"replay end state is Warden 40/0, Seamstress 27/0, Tinker 23/0 Weak 1")
	_check(first["enemies"][0]["id"] == "button_guard" and first["enemies"][0]["hp"] == 16
		and first["enemies"][0]["block"] == 3
		and first["enemies"][1]["id"] == "seam_ripper" and first["enemies"][1]["hp"] == 18
		and first["enemies"][1]["block"] == 2,
		"replay end state is Button Guard 16/3 and Seam Ripper 18/2")
	_check(first["repeating"] == _first_intents() and second["repeating"] == _first_intents(),
		"both copies return to the first announced intents on turn 4")
	_check(first["events"] == second["events"],
		"two independently constructed copies produce identical phase results")
	_check(first["heroes"] == second["heroes"] and first["enemies"] == second["enemies"],
		"two independently constructed copies end in identical party and enemy state")


func _test_negative_rejections() -> void:
	# malformed schedule variants
	var malformed: Array = []
	malformed.append({"label": "slot-1 attack without target_position",
		"data": _with_beat(1, 0, {"type": "attack", "amount": 4})})
	malformed.append({"label": "slot-1 attack target 0",
		"data": _with_beat(1, 0, {"type": "attack", "amount": 4, "target_position": 0})})
	malformed.append({"label": "slot-1 attack target 4",
		"data": _with_beat(1, 0, {"type": "attack", "amount": 4, "target_position": 4})})
	malformed.append({"label": "slot-1 attack with extra key",
		"data": _with_beat(1, 0, {"type": "attack", "amount": 4, "target_position": 1, "extra": 1})})
	malformed.append({"label": "slot-1 attack amount -1",
		"data": _with_beat(1, 0, {"type": "attack", "amount": -1, "target_position": 1})})
	malformed.append({"label": "slot-1 attack amount string",
		"data": _with_beat(1, 0, {"type": "attack", "amount": "4", "target_position": 1})})
	malformed.append({"label": "slot-1 attack amount 1.5",
		"data": _with_beat(1, 0, {"type": "attack", "amount": 1.5, "target_position": 1})})
	malformed.append({"label": "slot-1 block with a target",
		"data": _with_beat(1, 1, {"type": "block", "amount": 3, "target_position": 1})})
	malformed.append({"label": "slot-2 debuff without target_position",
		"data": _with_beat(2, 0, {"type": "debuff", "amount": 1})})
	malformed.append({"label": "slot-2 debuff without status",
		"data": _with_beat(2, 0, {"type": "debuff", "amount": 1, "target_position": 3})})
	malformed.append({"label": "slot-2 debuff unknown status",
		"data": _with_beat(2, 0, {"type": "debuff", "amount": 1, "target_position": 3, "status": "poison"})})
	malformed.append({"label": "slot-2 debuff amount 0",
		"data": _with_beat(2, 0, {"type": "debuff", "amount": 0, "target_position": 3, "status": "weak"})})
	malformed.append({"label": "slot-2 debuff amount string",
		"data": _with_beat(2, 0, {"type": "debuff", "amount": "1", "target_position": 3, "status": "weak"})})
	malformed.append({"label": "slot-2 debuff amount 1.5",
		"data": _with_beat(2, 0, {"type": "debuff", "amount": 1.5, "target_position": 3, "status": "weak"})})
	malformed.append({"label": "slot-2 debuff target float",
		"data": _with_beat(2, 0, {"type": "debuff", "amount": 1, "target_position": 3.5, "status": "weak"})})
	malformed.append({"label": "slot-2 debuff extra key",
		"data": _with_beat(2, 0, {"type": "debuff", "amount": 1, "target_position": 3, "status": "weak", "extra": 1})})
	malformed.append({"label": "slot-2 attack without target_position",
		"data": _with_beat(2, 1, {"type": "attack", "amount": 3})})
	malformed.append({"label": "slot-2 attack target 4",
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
	_check(_parsed() == _expected(), "negative: the unmodified authored file still parses exactly")
	_check(CombatEnemyIntents.new(_expected()).is_valid(),
		"negative: the unmodified prescription is still a valid schedule")

	# downed Tinker: living Seam Ripper tries Weak -> whole phase rejected, no partial Guard attack
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
		"negative: Weak on a downed hero rejects the whole phase")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"negative: a rejected downed-target phase changes no hero or enemy")
	_check(downed_intents == downed_input, "negative: a rejected phase leaves caller intents untouched")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6,
		"negative: Guard's staged attack is rolled back when Weak fails")

	# slain Seam Ripper: its Weak skipped, living Guard's attack still applies
	party = _build_authored_party()
	enemies = _build_authored_enemies()
	_check(CombatStartingBlock.new(party).apply(), "negative: second opening Block applied")
	_check(enemies.apply_damage(2, 18) and enemies.is_slain(2), "negative: Seam Ripper is slain")
	scheduler = CombatEnemyIntents.new(_parsed())
	var slain_intents := scheduler.get_intents()
	var slain_input := slain_intents.duplicate(true)
	before_party = party.get_heroes()
	before_enemies = enemies.get_enemies()
	seed(20261021)
	expected_rng = randi()
	seed(20261021)
	var slain_result := phase.execute_phase(party, enemies, slain_intents)
	_check(randi() == expected_rng, "negative: a slain source draws no global RNG")
	_check(slain_result.get("ok") == true, "negative: phase with slain source succeeds")
	_check(slain_result.get("events") == [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
		{"type": "debuff", "enemy_position": 2, "target_position": 3, "status": "weak", "applied": false}],
		"negative: slain Seam Ripper skips Weak; Button Guard still attacks")
	_check_hero(party, 1, 40, 2, "slain source")
	_check_hero(party, 2, 30, 0, "slain source")
	_check_hero(party, 3, 26, 0, "slain source")
	_check(party.get_hero(3).get("statuses", {}) == {},
		"negative: no Weak applied when source is slain")
	_check(enemies.get_enemy(1).get("hp") == 16 and enemies.get_enemy(2).get("hp") == 0,
		"negative: enemies unchanged except slain HP")
	_check(slain_intents == slain_input, "negative: the slain-source phase leaves caller intents untouched")

	# slain Button Guard: its attack skipped, Seam Ripper Weak applies
	party = _build_authored_party()
	enemies = _build_authored_enemies()
	_check(CombatStartingBlock.new(party).apply(), "negative: third opening Block applied")
	_check(enemies.apply_damage(1, 16) and enemies.is_slain(1), "negative: Button Guard is slain")
	scheduler = CombatEnemyIntents.new(_parsed())
	var slain_guard_intents := scheduler.get_intents()
	var slain_guard_result := phase.execute_phase(party, enemies, slain_guard_intents)
	_check(slain_guard_result.get("ok") == true, "negative: phase with slain Guard succeeds")
	_check(slain_guard_result.get("events") == [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": false},
		{"type": "debuff", "enemy_position": 2, "target_position": 3, "status": "weak", "applied": true}],
		"negative: slain Guard skips attack; Seam Ripper still applies Weak")
	_check(party.get_hero(3).get("statuses", {}) == {"weak": 1},
		"negative: Weak applies when only Ripper is living")

	# invalid phase batches
	var invalid_phase_batches: Array = [
		{"intents": [
			{"type": "block", "amount": 3, "enemy_position": 1},
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "poison", "enemy_position": 2}]},
		{"intents": [
			{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 1},
			{"type": "debuff", "amount": 0, "target_position": 3, "status": "weak", "enemy_position": 2}]},
		{"intents": [
			{"type": "block", "amount": 3, "enemy_position": 1},
			{"type": "attack", "amount": 3, "target_position": 3, "enemy_position": 1}]},
	]
	for batch in invalid_phase_batches:
		var bad_phase := phase.execute_phase(party, enemies, batch["intents"])
		_check(bad_phase == {"ok": false, "events": []},
			"negative: invalid phase batch is rejected")


func _test_weak_status() -> void:
	# Weak 1 modifies outgoing damage while active: 25% less, floor rounded.
	_check(CombatStatuses.new().adjusted_attack_damage(10, {"weak": 1}, {}) == 7,
		"Weak 1 reduces 10 damage to 7 (25% less, floored)")
	_check(CombatStatuses.new().adjusted_attack_damage(4, {"weak": 1}, {}) == 3,
		"Weak 1 reduces 4 damage to 3")
	_check(CombatStatuses.new().adjusted_attack_damage(10, {}, {}) == 10,
		"no Weak leaves 10 damage unchanged")

	# Weak expires at the owner's turn boundary, not by an enemy phase.
	var party := _build_authored_party()
	_check(CombatStartingBlock.new(party).apply(), "weak status precondition: opening Block")
	party.get_hero(3)  # touch
	# attach Weak 1 to Tinker directly via a no-op phase? Use status tick comparison instead.
	var tick := CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())
	# ensure base no weak first; apply weak manually through CombatParty? CombatParty has no status setter; use damage? Use direct array.
	var heroes := party.get_heroes()
	heroes[2]["statuses"] = {"weak": 1}
	party._heroes[2] = heroes[2]
	_check(party.get_hero(3).get("statuses", {}) == {"weak": 1}, "Tinker has Weak 1 before owner tick")

	var detached := CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())
	_check(detached.get("ok", false), "detached owner tick succeeds")
	if detached.get("ok", false):
		var ticked: Array = detached.get("actors", [])
		_check(ticked[2].get("statuses", {}) == {},
			"owner-turn tick expires Weak 1 to empty statuses on detached result")
	_check(party.get_hero(3).get("statuses", {}) == {"weak": 1},
		"detached tick does not mutate CombatParty in place")

	# an enemy phase does not expire Weak
	var enemies := _build_authored_enemies()
	var intents := CombatEnemyIntents.new(_parsed())
	# use turn 2 intents (no debuff on Tinker) to avoid adding Weak
	_check(intents.advance_turn(), "advance to turn 2 for Weak phase check")
	var before_statuses: Dictionary = party.get_hero(3).get("statuses", {}).duplicate(true)
	var result := phase.execute_phase(party, enemies, intents.get_intents())
	_check(result.get("ok") == true, "Weak phase check executes")
	_check(party.get_hero(3).get("statuses", {}) == before_statuses,
		"enemy phase leaves Weak 1 unchanged (no invented expiry)")
	_check(party.get_hero(3).get("hp") == 23, "Tinker takes the turn-2 attack while Weak remains")

	# end_owner_turn confirms expiry semantics
	var end_tick := CombatStatuses.new().end_owner_turn(26, 0, {"weak": 1})
	_check(end_tick.get("ok") == true and end_tick.get("statuses", {}) == {},
		"end_owner_turn expires Weak 1 at the owner boundary")
