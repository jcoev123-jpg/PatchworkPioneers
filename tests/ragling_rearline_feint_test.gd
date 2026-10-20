extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_test_file_parsing_and_shape()
	_test_intents_schedule()
	_test_real_combat_turns()
	_test_negative_paths()
	_test_no_mutation_and_malformed()
	_test_starter_attacks_preserved()
	if failures.is_empty():
		print("ragling_rearline_feint_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("ragling_rearline_feint_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _normalize_int(value) -> int:
	if value is int:
		return value
	if value is float and value == int(value):
		return int(value)
	return value

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
			if value is float:
				if value == int(value):
					value = int(value)
			else:
				value = _normalize_json(value)
			result[key] = value
		return result
	if data is float and data == int(data):
		return int(data)
	return data

func _load_json(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	return _normalize_json(JSON.parse_string(text))

func _find_hero_by_id(heroes: Array, id: String) -> Dictionary:
	var matches: Array = []
	for hero in heroes:
		if hero is Dictionary and hero.get("id") == id:
			matches.append(hero)
	if matches.size() != 1:
		return {}
	return matches[0].duplicate(true)

func _find_enemy_by_id(enemies: Array, id: String) -> Dictionary:
	var matches: Array = []
	for enemy in enemies:
		if enemy is Dictionary and enemy.get("id") == id:
			matches.append(enemy)
	if matches.size() != 1:
		return {}
	return matches[0].duplicate(true)

func _test_file_parsing_and_shape() -> void:
	var parsed := _load_json("res://data/encounters/ragling_rearline_feint.json")
	_check(parsed is Array and parsed.size() == 2,
		"parsed file is array of size 2")
	_check(parsed[0] is Dictionary and parsed[0].size() == 2,
		"first entry has enemy_position and pattern")
	_check(parsed[0].has("enemy_position") and parsed[0].has("pattern"),
		"first entry has required keys")
	_check(parsed[0]["enemy_position"] == 1,
		"first source position is 1")
	_check(parsed[0]["pattern"] is Array and parsed[0]["pattern"].size() == 2,
		"first pattern has two actions")
	_check(parsed[0]["pattern"][0]["type"] == "attack"
		and parsed[0]["pattern"][0]["amount"] == 1
		and parsed[0]["pattern"][0]["target_position"] == 3,
		"first action: attack 1 at position 3")
	_check(parsed[0]["pattern"][1]["type"] == "attack"
		and parsed[0]["pattern"][1]["amount"] == 1
		and parsed[0]["pattern"][1]["target_position"] == 2,
		"second action: attack 1 at position 2")
	_check(parsed[1]["enemy_position"] == 2,
		"second source position is 2")
	_check(parsed[1]["pattern"].size() == 2,
		"second pattern has two actions")
	_check(parsed[1]["pattern"][0]["type"] == "attack"
		and parsed[1]["pattern"][0]["amount"] == 1
		and parsed[1]["pattern"][0]["target_position"] == 2,
		"second first action: attack 1 at position 2")
	_check(parsed[1]["pattern"][1]["type"] == "attack"
		and parsed[1]["pattern"][1]["amount"] == 1
		and parsed[1]["pattern"][1]["target_position"] == 1,
		"second second action: attack 1 at position 1")

func _test_intents_schedule() -> void:
	var parsed := _load_json("res://data/encounters/ragling_rearline_feint.json")
	var original := parsed.duplicate(true)
	var intents := CombatEnemyIntents.new(parsed)
	_check(intents.is_valid(), "intents from file is valid")
	var turn0 := intents.get_intents()
	_check(turn0.size() == 2, "turn 0 has two intents")
	_check(turn0[0]["enemy_position"] == 1
		and turn0[0]["type"] == "attack" and turn0[0]["amount"] == 1
		and turn0[0]["target_position"] == 3,
		"turn 0 source 1 has exact action")
	_check(turn0[1]["enemy_position"] == 2
		and turn0[1]["type"] == "attack" and turn0[1]["amount"] == 1
		and turn0[1]["target_position"] == 2,
		"turn 0 source 2 has exact action")
	_check(intents.advance_turn(), "advance to turn 1 succeeds")
	var turn1 := intents.get_intents()
	_check(turn1[0]["enemy_position"] == 1
		and turn1[0]["type"] == "attack" and turn1[0]["amount"] == 1
		and turn1[0]["target_position"] == 2,
		"turn 1 source 1 attacks position 2")
	_check(turn1[1]["enemy_position"] == 2
		and turn1[1]["type"] == "attack" and turn1[1]["amount"] == 1
		and turn1[1]["target_position"] == 1,
		"turn 1 source 2 attacks position 1")
	_check(intents.advance_turn(), "advance to turn 2 succeeds")
	var turn2 := intents.get_intents()
	_check(turn2[0]["enemy_position"] == 1
		and turn2[0]["type"] == "attack" and turn2[0]["amount"] == 1
		and turn2[0]["target_position"] == 3,
		"turn 2 source 1 wraps back to position 3")
	_check(turn2[1]["enemy_position"] == 2
		and turn2[1]["type"] == "attack" and turn2[1]["amount"] == 1
		and turn2[1]["target_position"] == 2,
		"turn 2 source 2 wraps back to position 2")
	_check(parsed == original, "original parsed JSON unchanged after service")

func _build_authored_party() -> CombatParty:
	# Load authored starter heroes and pick the three required IDs in positions 1/2/3.
	var heroes_raw := _load_json("res://data/heroes/starter_party.json")
	var warden_raw := _find_hero_by_id(heroes_raw, "warden")
	var seamstress_raw := _find_hero_by_id(heroes_raw, "seamstress")
	var tinker_raw := _find_hero_by_id(heroes_raw, "tinker")
	_check(not warden_raw.is_empty(), "warden found by ID in starter_party.json")
	_check(not seamstress_raw.is_empty(), "seamstress found by ID in starter_party.json")
	_check(not tinker_raw.is_empty(), "tinker found by ID in starter_party.json")
	_check(warden_raw.get("name") == "Warden" and warden_raw.get("max_hp") == 40,
		"warden name and HP match authored data")
	_check(seamstress_raw.get("name") == "Seamstress" and seamstress_raw.get("max_hp") == 30,
		"seamstress name and HP match authored data")
	_check(tinker_raw.get("name") == "Tinker" and tinker_raw.get("max_hp") == 26,
		"tinker name and HP match authored data")
	# Order fixes positions: 1=warden, 2=seamstress, 3=tinker
	var party_defs := [warden_raw.duplicate(true), seamstress_raw.duplicate(true), tinker_raw.duplicate(true)]
	var party := CombatParty.new(party_defs)
	_check(party.is_valid(), "authored starter party is valid")
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("hp") == 40,
		"position 1 is Warden at 40 HP")
	_check(party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 30,
		"position 2 is Seamstress at 30 HP")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 26,
		"position 3 is Tinker at 26 HP")
	return party

func _build_authored_enemies() -> CombatEnemies:
	# Load authored starter enemies and pick the two required IDs in positions 1/2.
	var enemies_raw := _load_json("res://data/enemies/starter_enemies.json")
	var ragling_raw := _find_enemy_by_id(enemies_raw, "ragling")
	var guard_raw := _find_enemy_by_id(enemies_raw, "ragling_guard")
	_check(not ragling_raw.is_empty(), "ragling found by ID in starter_enemies.json")
	_check(not guard_raw.is_empty(), "ragling_guard found by ID in starter_enemies.json")
	_check(ragling_raw.get("name") == "Ragling" and ragling_raw.get("max_hp") == 12,
		"ragling name and HP match authored data")
	_check(guard_raw.get("name") == "Guard Ragling" and guard_raw.get("max_hp") == 12,
		"ragling_guard name and HP match authored data")
	# Order fixes positions: 1=ragling, 2=ragling_guard
	var enemy_defs := [ragling_raw.duplicate(true), guard_raw.duplicate(true)]
	var enemies := CombatEnemies.new(enemy_defs)
	_check(enemies.is_valid(), "authored starter enemies is valid")
	_check(enemies.get_enemy(1).get("id") == "ragling" and enemies.get_enemy(1).get("hp") == 12,
		"enemy position 1 is Ragling at 12 HP")
	_check(enemies.get_enemy(2).get("id") == "ragling_guard" and enemies.get_enemy(2).get("hp") == 12,
		"enemy position 2 is Guard Ragling at 12 HP")
	return enemies

func _test_real_combat_turns() -> void:
	# Build real CombatParty and CombatEnemies from on-disk authored definitions.
	var party := _build_authored_party()
	var enemies := _build_authored_enemies()

	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "real Warden opening block applied")
	_check(party.get_hero(1)["block"] == 6, "Warden has 6 block")

	var parsed := _load_json("res://data/encounters/ragling_rearline_feint.json")
	var scheduler := CombatEnemyIntents.new(parsed)
	var phase := CombatEnemyPhase.new()

	# Turn 0: source 1 attacks position 3 for 1 (Tinker 26->25)
	#        source 2 attacks position 2 for 1 (Seamstress 30->29)
	# Warden has 6 block, takes no damage here.
	var turn0 := scheduler.get_intents()
	var result0 := phase.execute_phase(party, enemies, turn0)
	_check(result0["ok"], "turn 0 phase succeeds")
	var events0: Array[Dictionary] = result0["events"]
	_check(events0.size() == 2, "turn 0 produces two events")
	_check(events0[0]["enemy_position"] == 1 and events0[0]["applied"] == true
		and events0[0]["target_position"] == 3,
		"turn 0 event 1: source 1 applied to target 3")
	_check(events0[1]["enemy_position"] == 2 and events0[1]["applied"] == true
		and events0[1]["target_position"] == 2,
		"turn 0 event 2: source 2 applied to target 2")

	# After turn 0: Warden 40 HP / 6 Block (no damage), Seamstress 29 HP, Tinker 25 HP
	_check(party.get_hero(1)["hp"] == 40 and party.get_hero(1)["block"] == 6,
		"after turn 0: Warden 40 HP 6 Block")
	_check(party.get_hero(2)["hp"] == 29,
		"after turn 0: Seamstress 29 HP")
	_check(party.get_hero(3)["hp"] == 25,
		"after turn 0: Tinker 25 HP")

	_check(scheduler.advance_turn(), "advance after turn 0 succeeds")

	# Turn 1: source 1 attacks position 2 for 1 (Seamstress 29->28)
	#        source 2 attacks position 1 for 1, but Warden has 6 block -> absorbs, 40/5
	var turn1 := scheduler.get_intents()
	var result1 := phase.execute_phase(party, enemies, turn1)
	_check(result1["ok"], "turn 1 phase succeeds")
	var events1: Array[Dictionary] = result1["events"]
	_check(events1[0]["enemy_position"] == 1 and events1[0]["applied"] == true
		and events1[0]["target_position"] == 2,
		"turn 1 event 1: source 1 applied to target 2")
	_check(events1[1]["enemy_position"] == 2 and events1[1]["applied"] == true
		and events1[1]["target_position"] == 1,
		"turn 1 event 2: source 2 applied to target 1")

	_check(party.get_hero(1)["hp"] == 40 and party.get_hero(1)["block"] == 5,
		"after turn 1: Warden 40 HP 5 Block")
	_check(party.get_hero(2)["hp"] == 28,
		"after turn 1: Seamstress 28 HP")
	_check(party.get_hero(3)["hp"] == 25,
		"after turn 1: Tinker 25 HP")

func _test_negative_paths() -> void:
	# Kill source 2 and run phase: source 2 must report not applied; source 1 still damages target.
	var party := _build_authored_party()
	var enemies := _build_authored_enemies()

	var parsed := _load_json("res://data/encounters/ragling_rearline_feint.json")
	var scheduler := CombatEnemyIntents.new(parsed)
	var phase := CombatEnemyPhase.new()

	_check(enemies.apply_damage(2, 12), "slay source 2 before phase")
	_check(enemies.is_slain(2), "source 2 is slain")
	_check(not enemies.is_slain(1), "source 1 still alive")

	var turn0 := scheduler.get_intents()
	var result := phase.execute_phase(party, enemies, turn0)
	_check(result["ok"], "phase with dead source 2 succeeds")
	var events: Array[Dictionary] = result["events"]
	_check(events.size() == 2, "two events reported")
	_check(events[0]["enemy_position"] == 1 and events[0]["applied"] == true
		and events[0]["target_position"] == 3,
		"dead-source check: source 1 still applies exact target 3")
	_check(events[1]["enemy_position"] == 2 and events[1]["applied"] == false,
		"dead source 2 reports not applied")

	# Separate party: down target and verify hit is not redirected.
	party = _build_authored_party()
	_check(party.apply_damage(2, 30), "down target position 2")
	_check(party.is_downed(2), "target position 2 is downed")

	enemies = _build_authored_enemies()
	scheduler = CombatEnemyIntents.new(parsed)

	turn0 = scheduler.get_intents()
	result = phase.execute_phase(party, enemies, turn0)
	_check(result["ok"], "phase with downed target succeeds")
	events = result["events"]
	_check(events.size() == 2, "two events for downed target")
	_check(events[0]["enemy_position"] == 1 and events[0]["applied"] == true
		and events[0]["target_position"] == 3,
		"downed target check: source 1 applies to alive target 3")
	_check(events[1]["enemy_position"] == 2 and events[1]["applied"] == false
		and events[1]["target_position"] == 2,
		"downed target check: source 2 skipped for downed target 2")

func _test_no_mutation_and_malformed() -> void:
	var parsed := _load_json("res://data/encounters/ragling_rearline_feint.json")
	var before_mutation := parsed.duplicate(true)
	var scheduler := CombatEnemyIntents.new(parsed)
	_check(scheduler.is_valid(), "valid schedule from file")
	var turn := scheduler.get_intents()
	turn[0]["type"] = "block"
	turn.append({"extra": 1})
	_check(scheduler.get_intents()[0]["type"] == "attack",
		"mutation of returned intents snapshot does not alter scheduler")
	_check(parsed == before_mutation,
		"parsed JSON unchanged after mutation attempt")

	# Malformed in-memory action missing target_position must make intents invalid.
	var bad := [{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 1}]}]
	var bad_scheduler := CombatEnemyIntents.new(bad)
	_check(not bad_scheduler.is_valid(), "missing target_position makes schedule invalid")
	_check(bad_scheduler.get_intents().is_empty(),
		"invalid schedule produces empty intents")
	_check(not bad_scheduler.advance_turn(),
		"invalid schedule cannot advance")

func _test_starter_attacks_preserved() -> void:
	var attacks := _load_json("res://data/encounters/starter_attacks.json")
	_check(attacks is Array, "starter_attacks.json is array")
	# Find by position, not by count/ordering.
	var source1: Dictionary = {}
	var source2: Dictionary = {}
	for entry in attacks:
		if entry is Dictionary and entry.get("enemy_position") == 1:
			source1 = entry.duplicate(true)
		if entry is Dictionary and entry.get("enemy_position") == 2:
			source2 = entry.duplicate(true)
	_check(not source1.is_empty(), "starter source 1 exists by position")
	_check(not source2.is_empty(), "starter source 2 exists by position")
	_check(source1.get("pattern") is Array and source1.get("pattern").size() == 2,
		"starter source 1 pattern preserved")
	_check(source1.get("pattern")[0].get("type") == "attack"
		and source1.get("pattern")[0].get("amount") == 1
		and source1.get("pattern")[0].get("target_position") == 1,
		"starter source 1 first action preserved")
	_check(source1.get("pattern")[1].get("type") == "attack"
		and source1.get("pattern")[1].get("amount") == 1
		and source1.get("pattern")[1].get("target_position") == 2,
		"starter source 1 second action preserved")
	_check(source2.get("pattern") is Array and source2.get("pattern").size() == 1,
		"starter source 2 pattern preserved")
	_check(source2.get("pattern")[0].get("type") == "block"
		and source2.get("pattern")[0].get("amount") == 1,
		"starter source 2 block preserved")