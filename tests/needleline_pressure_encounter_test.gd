extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_file_parsing_and_shape()
	_test_intents_schedule()
	_test_real_combat_phases()
	_test_negative_cases()
	_test_existing_encounters_unchanged()
	_test_deterministic_replay_no_rng()
	if failures.is_empty():
		print("needleline_pressure_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("needleline_pressure_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


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
	_check(file != null, "opens " + path)
	if file == null:
		return []
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		return []
	return _normalize_json(parsed)


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
	var parsed := _load_json("res://data/encounters/needleline_pressure.json")
	_check(parsed is Array and parsed.size() == 2,
		"parsed file is array of size 2")

	# Find by enemy_position, not by index
	var source1: Dictionary = {}
	var source2: Dictionary = {}
	for entry in parsed:
		if entry is Dictionary:
			if entry.get("enemy_position") == 1:
				source1 = entry
			elif entry.get("enemy_position") == 2:
				source2 = entry

	_check(not source1.is_empty(), "source 1 exists by enemy_position 1")
	_check(not source2.is_empty(), "source 2 exists by enemy_position 2")

	_check(source1.get("enemy_position") == 1, "source 1 position is 1")
	_check(source1.get("pattern") is Array and source1.get("pattern").size() == 3,
		"source 1 has 3-action cycle")
	# Pattern: [attack 2, attack 1, block 1]
	_check(source1.get("pattern")[0].get("type") == "attack"
		and source1.get("pattern")[0].get("amount") == 1
		and source1.get("pattern")[0].get("target_position") == 2,
		"source 1 turn 0: attack 1 at hero 2")
	_check(source1.get("pattern")[1].get("type") == "attack"
		and source1.get("pattern")[1].get("amount") == 1
		and source1.get("pattern")[1].get("target_position") == 1,
		"source 1 turn 1: attack 1 at hero 1")
	_check(source1.get("pattern")[2].get("type") == "block"
		and source1.get("pattern")[2].get("amount") == 1,
		"source 1 turn 2: block 1")

	_check(source2.get("enemy_position") == 2, "source 2 position is 2")
	_check(source2.get("pattern") is Array and source2.get("pattern").size() == 3,
		"source 2 has 3-action cycle")
	# Pattern: [block 1, attack 3, attack 2]
	_check(source2.get("pattern")[0].get("type") == "block"
		and source2.get("pattern")[0].get("amount") == 1,
		"source 2 turn 0: block 1")
	_check(source2.get("pattern")[1].get("type") == "attack"
		and source2.get("pattern")[1].get("amount") == 1
		and source2.get("pattern")[1].get("target_position") == 3,
		"source 2 turn 1: attack 1 at hero 3")
	_check(source2.get("pattern")[2].get("type") == "attack"
		and source2.get("pattern")[2].get("amount") == 1
		and source2.get("pattern")[2].get("target_position") == 2,
		"source 2 turn 2: attack 1 at hero 2")

	# Verify no fractional values are accepted; reject floats that aren't integral
	_check(source1.get("enemy_position") is int, "enemy_position is integral int")
	for action in source1.get("pattern"):
		if action is Dictionary:
			_check(action.get("amount") is int, "amount is integral int")
			if action.has("target_position"):
				_check(action.get("target_position") is int, "target_position is integral int")


func _test_intents_schedule() -> void:
	var parsed := _load_json("res://data/encounters/needleline_pressure.json")
	var original := parsed.duplicate(true)
	var intents := CombatEnemyIntents.new(parsed)
	_check(intents.is_valid(), "intents from file is valid")

	# Beat 0 (turn index 0): source 1 attacks hero 2, source 2 blocks
	var turn0 := intents.get_intents()
	_check(turn0.size() == 2, "turn 0 announces two intents")
	_check(turn0[0].get("enemy_position") == 1
		and turn0[0].get("type") == "attack"
		and turn0[0].get("amount") == 1
		and turn0[0].get("target_position") == 2,
		"turn 0 source 1: attack 1 at hero 2")
	_check(turn0[1].get("enemy_position") == 2
		and turn0[1].get("type") == "block"
		and turn0[1].get("amount") == 1,
		"turn 0 source 2: block 1")

	# Beat 1 (turn index 1): source 1 attacks hero 1, source 2 attacks hero 3
	_check(intents.advance_turn(), "advance to turn 1 succeeds")
	var turn1 := intents.get_intents()
	_check(turn1.size() == 2, "turn 1 announces two intents")
	_check(turn1[0].get("enemy_position") == 1
		and turn1[0].get("type") == "attack"
		and turn1[0].get("amount") == 1
		and turn1[0].get("target_position") == 1,
		"turn 1 source 1: attack 1 at hero 1")
	_check(turn1[1].get("enemy_position") == 2
		and turn1[1].get("type") == "attack"
		and turn1[1].get("amount") == 1
		and turn1[1].get("target_position") == 3,
		"turn 1 source 2: attack 1 at hero 3")

	# Beat 2 (turn index 2): source 1 blocks, source 2 attacks hero 2
	_check(intents.advance_turn(), "advance to turn 2 succeeds")
	var turn2 := intents.get_intents()
	_check(turn2.size() == 2, "turn 2 announces two intents")
	_check(turn2[0].get("enemy_position") == 1
		and turn2[0].get("type") == "block"
		and turn2[0].get("amount") == 1,
		"turn 2 source 1: block 1")
	_check(turn2[1].get("enemy_position") == 2
		and turn2[1].get("type") == "attack"
		and turn2[1].get("amount") == 1
		and turn2[1].get("target_position") == 2,
		"turn 2 source 2: attack 1 at hero 2")

	# Beat 3 wraps back to beat 0 pattern
	_check(intents.advance_turn(), "advance to turn 3 (wrap) succeeds")
	var turn3 := intents.get_intents()
	_check(turn3[0].get("enemy_position") == 1
		and turn3[0].get("type") == "attack"
		and turn3[0].get("amount") == 1
		and turn3[0].get("target_position") == 2,
		"turn 3 (wrap) source 1: attack 1 at hero 2")
	_check(turn3[1].get("enemy_position") == 2
		and turn3[1].get("type") == "block"
		and turn3[1].get("amount") == 1,
		"turn 3 (wrap) source 2: block 1")

	_check(parsed == original, "original parsed JSON unchanged after service")


func _build_authored_party() -> CombatParty:
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
	var party_defs := [
		warden_raw.duplicate(true),
		seamstress_raw.duplicate(true),
		tinker_raw.duplicate(true)
	]
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
	var enemies_raw := _load_json("res://data/enemies/starter_enemies.json")
	var ragling_raw := _find_enemy_by_id(enemies_raw, "ragling")
	var guard_raw := _find_enemy_by_id(enemies_raw, "ragling_guard")
	_check(not ragling_raw.is_empty(), "ragling found by ID in starter_enemies.json")
	_check(not guard_raw.is_empty(), "ragling_guard found by ID in starter_enemies.json")
	_check(ragling_raw.get("name") == "Ragling" and ragling_raw.get("max_hp") == 12,
		"ragling name and HP match authored data")
	_check(guard_raw.get("name") == "Guard Ragling" and guard_raw.get("max_hp") == 12,
		"guard ragling name and HP match authored data")
	var enemy_defs := [ragling_raw.duplicate(true), guard_raw.duplicate(true)]
	var enemies := CombatEnemies.new(enemy_defs)
	_check(enemies.is_valid(), "authored starter enemies is valid")
	_check(enemies.get_enemy(1).get("id") == "ragling" and enemies.get_enemy(1).get("hp") == 12,
		"enemy position 1 is Ragling at 12 HP")
	_check(enemies.get_enemy(2).get("id") == "ragling_guard" and enemies.get_enemy(2).get("hp") == 12,
		"enemy position 2 is Guard Ragling at 12 HP")
	return enemies


func _test_real_combat_phases() -> void:
	var party := _build_authored_party()
	var enemies := _build_authored_enemies()
	var parsed := _load_json("res://data/encounters/needleline_pressure.json")
	var scheduler := CombatEnemyIntents.new(parsed)
	var phase := CombatEnemyPhase.new()
	var opening := CombatStartingBlock.new(party)

	_check(opening.apply(), "Warden opening block applied")
	_check(party.get_hero(1)["block"] == 6, "Warden has 6 Block after opening")

	# Beat 0
	var turn0 := scheduler.get_intents()
	var result0 := phase.execute_phase(party, enemies, turn0)
	_check(result0.get("ok") == true, "beat 0 phase succeeds")
	var events0: Array = result0.get("events")
	_check(events0.size() == 2, "beat 0 produces two events")
	_check(events0[0].get("enemy_position") == 1
		and events0[0].get("type") == "attack"
		and events0[0].get("target_position") == 2
		and events0[0].get("applied") == true,
		"beat 0 event 0: Ragling attacks hero 2 applied")
	_check(events0[1].get("enemy_position") == 2
		and events0[1].get("type") == "block"
		and events0[1].get("applied") == true,
		"beat 0 event 1: Guard Ragling block applied")

	# After beat 0: Seamstress 30 -> 29, Guard Block 1, Warden 40/6, Tinker 26
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6,
		"after beat 0: Warden 40 HP, 6 Block")
	_check(party.get_hero(2).get("hp") == 29,
		"after beat 0: Seamstress 29 HP")
	_check(party.get_hero(3).get("hp") == 26,
		"after beat 0: Tinker 26 HP")
	_check(enemies.get_enemy(1).get("hp") == 12 and enemies.get_enemy(1).get("block") == 0,
		"after beat 0: Ragling 12 HP, 0 Block")
	_check(enemies.get_enemy(2).get("hp") == 12 and enemies.get_enemy(2).get("block") == 1,
		"after beat 0: Guard Ragling 12 HP, 1 Block")

	# Advance to beat 1 (no player turn reset between enemy phases)
	_check(scheduler.advance_turn(), "advance to beat 1 succeeds")

	# Beat 1
	var turn1 := scheduler.get_intents()
	var result1 := phase.execute_phase(party, enemies, turn1)
	_check(result1.get("ok") == true, "beat 1 phase succeeds")
	var events1: Array = result1.get("events")
	_check(events1.size() == 2, "beat 1 produces two events")
	_check(events1[0].get("enemy_position") == 1
		and events1[0].get("type") == "attack"
		and events1[0].get("target_position") == 1
		and events1[0].get("applied") == true,
		"beat 1 event 0: Ragling attacks hero 1 applied")
	_check(events1[1].get("enemy_position") == 2
		and events1[1].get("type") == "attack"
		and events1[1].get("target_position") == 3
		and events1[1].get("applied") == true,
		"beat 1 event 1: Guard Ragling attacks hero 3 applied")

	# After beat 1: Warden 40/5 (absorbs 1 from 6), Seamstress 29, Tinker 25, Ragling 12/0, Guard 12/1
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 5,
		"after beat 1: Warden 40 HP, 5 Block")
	_check(party.get_hero(2).get("hp") == 29,
		"after beat 1: Seamstress 29 HP")
	_check(party.get_hero(3).get("hp") == 25,
		"after beat 1: Tinker 25 HP")

	# Advance to beat 2 (no player turn reset between enemy phases)
	_check(scheduler.advance_turn(), "advance to beat 2 succeeds")

	# Beat 2
	var turn2 := scheduler.get_intents()
	var result2 := phase.execute_phase(party, enemies, turn2)
	_check(result2.get("ok") == true, "beat 2 phase succeeds")
	var events2: Array = result2.get("events")
	_check(events2.size() == 2, "beat 2 produces two events")
	_check(events2[0].get("enemy_position") == 1
		and events2[0].get("type") == "block"
		and events2[0].get("applied") == true,
		"beat 2 event 0: Ragling block applied")
	_check(events2[1].get("enemy_position") == 2
		and events2[1].get("type") == "attack"
		and events2[1].get("target_position") == 2
		and events2[1].get("applied") == true,
		"beat 2 event 1: Guard Ragling attacks hero 2 applied")

	# After beat 2: Ragling 12/1 (block stacks), Seamstress 28, Warden 40/5, Tinker 25, Guard 12/1
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 5,
		"after beat 2: Warden 40 HP, 5 Block")
	_check(party.get_hero(2).get("hp") == 28,
		"after beat 2: Seamstress 28 HP")
	_check(party.get_hero(3).get("hp") == 25,
		"after beat 2: Tinker 25 HP")
	_check(enemies.get_enemy(1).get("hp") == 12 and enemies.get_enemy(1).get("block") == 1,
		"after beat 2: Ragling 12 HP, 1 Block")
	_check(enemies.get_enemy(2).get("hp") == 12 and enemies.get_enemy(2).get("block") == 1,
		"after beat 2: Guard Ragling 12 HP, 1 Block (retains previous)")

	# Beat 3 re-announces beat 0
	_check(scheduler.advance_turn(), "advance to beat 3 succeeds")
	var turn3 := scheduler.get_intents()
	_check(turn3[0].get("enemy_position") == 1
		and turn3[0].get("type") == "attack"
		and turn3[0].get("target_position") == 2,
		"beat 3 (wrap) announces same as beat 0 for source 1")
	_check(turn3[1].get("enemy_position") == 2
		and turn3[1].get("type") == "block",
		"beat 3 (wrap) announces same as beat 0 for source 2")


func _test_negative_cases() -> void:
	# Slain source 2: its announced action reports applied=false; living source 1 acts
	var party := _build_authored_party()
	var enemies := _build_authored_enemies()
	var parsed := _load_json("res://data/encounters/needleline_pressure.json")
	var scheduler := CombatEnemyIntents.new(parsed)
	var phase := CombatEnemyPhase.new()

	_check(enemies.apply_damage(2, 12), "slay source 2 (Guard Ragling)")
	_check(enemies.is_slain(2), "source 2 is slain")
	_check(not enemies.is_slain(1), "source 1 still alive")

	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "negative: opening block")

	var turn0 := scheduler.get_intents()
	var result := phase.execute_phase(party, enemies, turn0)
	_check(result.get("ok") == true, "negative: phase with slain source succeeds")
	var events: Array = result.get("events")
	_check(events.size() == 2, "negative: two events reported")
	_check(events[0].get("enemy_position") == 1
		and events[0].get("type") == "attack"
		and events[0].get("target_position") == 2
		and events[0].get("applied") == true,
		"negative: living source 1 applies attack")
	_check(events[1].get("enemy_position") == 2
		and events[1].get("type") == "block"
		and events[1].get("applied") == false,
		"negative: slain source 2 reports applied=false")

	# Unaffected actors retain correct HP/Block
	_check(party.get_hero(2).get("hp") == 30 - 1, "Seamstress takes damage from source 1")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6,
		"Warden unchanged after source 1 attack at hero 2")
	_check(enemies.get_enemy(1).get("hp") == 12, "Ragling unchanged")

	# Downed target at position 2: attack reports applied=false, no retarget
	party = _build_authored_party()
	enemies = _build_authored_enemies()
	scheduler = CombatEnemyIntents.new(parsed)
	phase = CombatEnemyPhase.new()
	opening = CombatStartingBlock.new(party)
	_check(opening.apply(), "negative: opening block for downed target")

	_check(party.apply_damage(2, 30), "down target position 2 (Seamstress)")
	_check(party.is_downed(2), "target position 2 is downed")

	var turn0_down := scheduler.get_intents()
	var result_down := phase.execute_phase(party, enemies, turn0_down)
	_check(result_down.get("ok") == true, "negative: phase with downed target succeeds")
	var events_down: Array = result_down.get("events")
	_check(events_down.size() == 2, "negative: two events with downed target")
	_check(events_down[0].get("enemy_position") == 1
		and events_down[0].get("applied") == false
		and events_down[0].get("target_position") == 2,
		"negative: source 1 attack at downed target 2 applied=false (not redirected)")
	_check(events_down[1].get("enemy_position") == 2
		and events_down[1].get("applied") == true,
		"negative: source 2 block applied (unaffected)")

	# Unaffected actors: Tinker and Warden unchanged
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6,
		"negative: Warden unchanged with downed target")
	_check(party.get_hero(3).get("hp") == 26,
		"negative: Tinker unchanged with downed target")


func _test_existing_encounters_unchanged() -> void:
	# Verify starter_attacks, guard_counterattack, ragling_rearline_feint, cross_stitch_guard remain
	var starter := _load_json("res://data/encounters/starter_attacks.json")
	_check(starter is Array, "existing: starter_attacks.json array")
	var starter_s1: Dictionary = {}
	var starter_s2: Dictionary = {}
	for entry in starter:
		if entry is Dictionary:
			if entry.get("enemy_position") == 1:
				starter_s1 = entry
			elif entry.get("enemy_position") == 2:
				starter_s2 = entry
	_check(starter_s1.get("pattern")[0].get("type") == "attack"
		and starter_s1.get("pattern")[0].get("amount") == 1
		and starter_s1.get("pattern")[0].get("target_position") == 1,
		"existing: starter_attacks source 1 preserved")

	var guard := _load_json("res://data/encounters/guard_counterattack.json")
	_check(guard is Array, "existing: guard_counterattack.json array")
	var guard_s1: Dictionary = {}
	var guard_s2: Dictionary = {}
	for entry in guard:
		if entry is Dictionary:
			if entry.get("enemy_position") == 1:
				guard_s1 = entry
			elif entry.get("enemy_position") == 2:
				guard_s2 = entry
	_check(guard_s1.get("pattern")[0].get("type") == "block"
		and guard_s2.get("pattern")[0].get("type") == "attack"
		and guard_s2.get("pattern")[0].get("target_position") == 3,
		"existing: guard_counterattack preserved")

	var ragling := _load_json("res://data/encounters/ragling_rearline_feint.json")
	_check(ragling is Array, "existing: ragling_rearline_feint.json array")
	var rag_s1: Dictionary = {}
	var rag_s2: Dictionary = {}
	for entry in ragling:
		if entry is Dictionary:
			if entry.get("enemy_position") == 1:
				rag_s1 = entry
			elif entry.get("enemy_position") == 2:
				rag_s2 = entry
	_check(rag_s1.get("pattern")[0].get("type") == "attack"
		and rag_s1.get("pattern")[0].get("target_position") == 3,
		"existing: ragling_rearline_feint preserved")

	var cross := _load_json("res://data/encounters/cross_stitch_guard.json")
	_check(cross is Array, "existing: cross_stitch_guard.json array")
	var cross_s1: Dictionary = {}
	var cross_s2: Dictionary = {}
	for entry in cross:
		if entry is Dictionary:
			if entry.get("enemy_position") == 1:
				cross_s1 = entry
			elif entry.get("enemy_position") == 2:
				cross_s2 = entry
	_check(cross_s1.get("pattern")[0].get("type") == "attack"
		and cross_s1.get("pattern")[0].get("target_position") == 3,
		"existing: cross_stitch_guard preserved")


func _test_deterministic_replay_no_rng() -> void:
	var heroes_raw := _load_json("res://data/heroes/starter_party.json")
	var warden_raw := _find_hero_by_id(heroes_raw, "warden")
	var seamstress_raw := _find_hero_by_id(heroes_raw, "seamstress")
	var tinker_raw := _find_hero_by_id(heroes_raw, "tinker")
	var party_defs := [
		warden_raw.duplicate(true),
		seamstress_raw.duplicate(true),
		tinker_raw.duplicate(true)
	]

	var parsed := _load_json("res://data/encounters/needleline_pressure.json")

	# Replay setup A
	var party_a := CombatParty.new(party_defs)
	var enemies_a := CombatEnemies.new([
		_find_enemy_by_id(_load_json("res://data/enemies/starter_enemies.json"), "ragling").duplicate(true),
		_find_enemy_by_id(_load_json("res://data/enemies/starter_enemies.json"), "ragling_guard").duplicate(true)
	])
	var scheduler_a := CombatEnemyIntents.new(parsed)
	var phase_a := CombatEnemyPhase.new()
	var opening_a := CombatStartingBlock.new(party_a)
	_check(opening_a.apply(), "replay A: opening block")

	# Replay setup B
	var party_b := CombatParty.new(party_defs)
	var enemies_b := CombatEnemies.new([
		_find_enemy_by_id(_load_json("res://data/enemies/starter_enemies.json"), "ragling").duplicate(true),
		_find_enemy_by_id(_load_json("res://data/enemies/starter_enemies.json"), "ragling_guard").duplicate(true)
	])
	var scheduler_b := CombatEnemyIntents.new(parsed)
	var phase_b := CombatEnemyPhase.new()
	var opening_b := CombatStartingBlock.new(party_b)
	_check(opening_b.apply(), "replay B: opening block")

	# Replay 6 turns (two full 3-beat cycles) and compare
	for turn in range(6):
		var intents_a := scheduler_a.get_intents()
		var intents_b := scheduler_b.get_intents()
		_check(intents_a == intents_b, "replay turn %d: identical intents" % turn)

		var result_a := phase_a.execute_phase(party_a, enemies_a, intents_a)
		var result_b := phase_b.execute_phase(party_b, enemies_b, intents_b)
		_check(result_a == result_b, "replay turn %d: identical phase results" % turn)

		_check(party_a.get_heroes() == party_b.get_heroes(),
			"replay turn %d: party states identical" % turn)
		_check(enemies_a.get_enemies() == enemies_b.get_enemies(),
			"replay turn %d: enemy states identical" % turn)

		scheduler_a.advance_turn()
		scheduler_b.advance_turn()

		# Simulate player turn Block reset every beat
		party_a.start_player_turn()
		party_b.start_player_turn()

	# Verify same-seed fixed replay produces identical complete traces
	seed(0xCAFEBABE)
	var party_c := CombatParty.new(party_defs)
	var enemies_c := CombatEnemies.new([
		_find_enemy_by_id(_load_json("res://data/enemies/starter_enemies.json"), "ragling").duplicate(true),
		_find_enemy_by_id(_load_json("res://data/enemies/starter_enemies.json"), "ragling_guard").duplicate(true)
	])
	var scheduler_c := CombatEnemyIntents.new(parsed)
	var phase_c := CombatEnemyPhase.new()
	var opening_c := CombatStartingBlock.new(party_c)
	_check(opening_c.apply(), "replay C: opening block")

	seed(0xCAFEBABE)
	var party_d := CombatParty.new(party_defs)
	var enemies_d := CombatEnemies.new([
		_find_enemy_by_id(_load_json("res://data/enemies/starter_enemies.json"), "ragling").duplicate(true),
		_find_enemy_by_id(_load_json("res://data/enemies/starter_enemies.json"), "ragling_guard").duplicate(true)
	])
	var scheduler_d := CombatEnemyIntents.new(parsed)
	var phase_d := CombatEnemyPhase.new()
	var opening_d := CombatStartingBlock.new(party_d)
	_check(opening_d.apply(), "replay D: opening block")

	for turn in range(6):
		var intents_c := scheduler_c.get_intents()
		var intents_d := scheduler_d.get_intents()
		_check(intents_c == intents_d, "replay fixed-seed turn %d: identical intents" % turn)

		var result_c := phase_c.execute_phase(party_c, enemies_c, intents_c)
		var result_d := phase_d.execute_phase(party_d, enemies_d, intents_d)
		_check(result_c == result_d, "replay fixed-seed turn %d: identical phase results" % turn)

		scheduler_c.advance_turn()
		scheduler_d.advance_turn()
		party_c.start_player_turn()
		party_d.start_player_turn()

	# Verify no RNG consumption
	seed(0xDEADBEEF)
	var baseline_randi = randi()

	seed(0xDEADBEEF)
	var _unused_intents := scheduler_c.get_intents()
	_check(randi() == baseline_randi, "replay: get_intents does not consume RNG")

	seed(0xDEADBEEF)
	var before_advance := scheduler_c.get_intents()
	var result_before := phase_c.execute_phase(party_c, enemies_c, before_advance)
	_check(result_before.get("ok") == true, "replay: phase executes")
	_check(randi() == baseline_randi, "replay: execute_phase does not consume RNG")

	# Verify encounter file actions remain present
	var needleline := _load_json("res://data/encounters/needleline_pressure.json")
	var needle_s1: Dictionary = {}
	var needle_s2: Dictionary = {}
	for entry in needleline:
		if entry is Dictionary:
			if entry.get("enemy_position") == 1:
				needle_s1 = entry
			elif entry.get("enemy_position") == 2:
				needle_s2 = entry
	_check(needle_s1.get("pattern")[0].get("type") == "attack"
		and needle_s1.get("pattern")[1].get("type") == "attack"
		and needle_s1.get("pattern")[2].get("type") == "block",
		"named encounter actions remain present")
