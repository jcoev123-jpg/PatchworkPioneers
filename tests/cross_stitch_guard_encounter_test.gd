extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_test_cross_stitch_guard_pattern()
	_test_intents_cycle_and_wrap()
	_test_real_combat_phases()
	_test_negative_cases()
	_test_existing_encounters_preserved()
	_test_deterministic_replay_no_rng()
	if failures.is_empty():
		print("cross_stitch_guard_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("cross_stitch_guard_encounter_test: FAIL (", failures.size(), " failures)")
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

func _test_cross_stitch_guard_pattern() -> void:
	var parsed := _load_json("res://data/encounters/cross_stitch_guard.json")
	_check(parsed is Array and parsed.size() == 2, "cross_stitch_guard.json is array of size 2")

	var source1: Dictionary = {}
	var source2: Dictionary = {}
	for entry in parsed:
		if entry is Dictionary:
			if entry.get("enemy_position") == 1:
				source1 = entry
			elif entry.get("enemy_position") == 2:
				source2 = entry
	_check(not source1.is_empty(), "source 1 by enemy_position 1 exists")
	_check(not source2.is_empty(), "source 2 by enemy_position 2 exists")

	# Source 1: Ragling at position 1
	_check(source1.get("enemy_position") == 1, "source 1 position is 1")
	_check(source1.get("pattern") is Array and source1.get("pattern").size() == 2,
		"source 1 has 2-action cycle")
	_check(source1.get("pattern")[0].get("type") == "attack"
		and source1.get("pattern")[0].get("amount") == 1
		and source1.get("pattern")[0].get("target_position") == 3,
		"source 1 turn 0: attack amount 1 target_position 3")
	_check(source1.get("pattern")[1].get("type") == "block"
		and source1.get("pattern")[1].get("amount") == 1,
		"source 1 turn 1: block amount 1")

	# Source 2: Guard Ragling at position 2
	_check(source2.get("enemy_position") == 2, "source 2 position is 2")
	_check(source2.get("pattern") is Array and source2.get("pattern").size() == 2,
		"source 2 has 2-action cycle")
	_check(source2.get("pattern")[0].get("type") == "block"
		and source2.get("pattern")[0].get("amount") == 1,
		"source 2 turn 0: block amount 1")
	_check(source2.get("pattern")[1].get("type") == "attack"
		and source2.get("pattern")[1].get("amount") == 1
		and source2.get("pattern")[1].get("target_position") == 1,
		"source 2 turn 1: attack amount 1 target_position 1")

func _test_intents_cycle_and_wrap() -> void:
	var parsed := _load_json("res://data/encounters/cross_stitch_guard.json")
	var intents := CombatEnemyIntents.new(parsed)
	_check(intents.is_valid(), "CombatEnemyIntents valid from new JSON")

	# Turn 0
	var turn0 := intents.get_intents()
	_check(turn0.size() == 2, "turn 0 announces 2 intents")
	_check(turn0[0].get("enemy_position") == 1 and turn0[0].get("type") == "attack"
		and turn0[0].get("amount") == 1 and turn0[0].get("target_position") == 3,
		"turn 0 source 1: attack 3")
	_check(turn0[1].get("enemy_position") == 2 and turn0[1].get("type") == "block"
		and turn0[1].get("amount") == 1,
		"turn 0 source 2: block 1")

	# Advance turn 1
	_check(intents.advance_turn(), "advance to turn 1 succeeds")
	var turn1 := intents.get_intents()
	_check(turn1.size() == 2, "turn 1 announces 2 intents")
	_check(turn1[0].get("enemy_position") == 1 and turn1[0].get("type") == "block"
		and turn1[0].get("amount") == 1,
		"turn 1 source 1: block 1")
	_check(turn1[1].get("enemy_position") == 2 and turn1[1].get("type") == "attack"
		and turn1[1].get("amount") == 1 and turn1[1].get("target_position") == 1,
		"turn 1 source 2: attack 1")

	# Advance turn 2 (wrap back to turn 0 pattern)
	_check(intents.advance_turn(), "advance to turn 2 succeeds")
	var turn2 := intents.get_intents()
	_check(turn2.size() == 2, "turn 2 announces 2 intents")
	_check(turn2[0].get("enemy_position") == 1 and turn2[0].get("type") == "attack"
		and turn2[0].get("amount") == 1 and turn2[0].get("target_position") == 3,
		"turn 2 (wrap) source 1: attack 3")
	_check(turn2[1].get("enemy_position") == 2 and turn2[1].get("type") == "block"
		and turn2[1].get("amount") == 1,
		"turn 2 (wrap) source 2: block 1")

func _test_real_combat_phases() -> void:
	# Build real party from starter_party by named IDs
	var heroes_raw := _load_json("res://data/heroes/starter_party.json")
	var warden_raw := _find_hero_by_id(heroes_raw, "warden")
	var seamstress_raw := _find_hero_by_id(heroes_raw, "seamstress")
	var tinker_raw := _find_hero_by_id(heroes_raw, "tinker")
	_check(not warden_raw.is_empty(), "warden by id found")
	_check(not seamstress_raw.is_empty(), "seamstress by id found")
	_check(not tinker_raw.is_empty(), "tinker by id found")

	var party_defs := [
		warden_raw.duplicate(true),
		seamstress_raw.duplicate(true),
		tinker_raw.duplicate(true)
	]
	var party := CombatParty.new(party_defs)
	_check(party.is_valid(), "authored party valid")
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("hp") == 40,
		"position 1 Warden 40 HP")
	_check(party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 30,
		"position 2 Seamstress 30 HP")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 26,
		"position 3 Tinker 26 HP")

	var enemies_raw := _load_json("res://data/enemies/starter_enemies.json")
	var ragling_raw := _find_enemy_by_id(enemies_raw, "ragling")
	var guard_raw := _find_enemy_by_id(enemies_raw, "ragling_guard")
	_check(not ragling_raw.is_empty(), "ragling by id found")
	_check(not guard_raw.is_empty(), "ragling_guard by id found")

	var enemy_defs := [ragling_raw.duplicate(true), guard_raw.duplicate(true)]
	var enemies := CombatEnemies.new(enemy_defs)
	_check(enemies.is_valid(), "authored enemies valid")
	_check(enemies.get_enemy(1).get("id") == "ragling" and enemies.get_enemy(1).get("hp") == 12,
		"enemy 1 Ragling 12 HP")
	_check(enemies.get_enemy(2).get("id") == "ragling_guard" and enemies.get_enemy(2).get("hp") == 12,
		"enemy 2 Guard Ragling 12 HP")

	var parsed := _load_json("res://data/encounters/cross_stitch_guard.json")
	var scheduler := CombatEnemyIntents.new(parsed)
	var phase := CombatEnemyPhase.new()
	var starting_block := CombatStartingBlock.new(party)

	# Apply Warden opening Block 6
	_check(starting_block.apply(), "Warden opening block applied")
	_check(party.get_hero(1).get("block") == 6, "Warden has 6 Block")

	# Phase 0
	var turn0_intents := scheduler.get_intents()
	var result0 := phase.execute_phase(party, enemies, turn0_intents)
	_check(result0.get("ok") == true, "phase 0 succeeds")

	# Source 1 (position 1) attacks target 3 (Tinker 26 -> 25); source 2 (position 2) blocks
	_check(enemies.get_enemy(1).get("hp") == 12 and enemies.get_enemy(1).get("block") == 0,
		"phase 0: Ragling 12 HP, 0 Block (attack, no block)")
	_check(enemies.get_enemy(2).get("hp") == 12 and enemies.get_enemy(2).get("block") == 1,
		"phase 0: Guard Ragling 12 HP, 1 Block")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6,
		"phase 0: Warden 40 HP, 6 Block intact")
	_check(party.get_hero(2).get("hp") == 30 and party.get_hero(2).get("block") == 0,
		"phase 0: Seamstress 30 HP, 0 Block")
	_check(party.get_hero(3).get("hp") == 25 and party.get_hero(3).get("block") == 0,
		"phase 0: Tinker 26 -> 25 HP, 0 Block")

	# Advance scheduler to turn 1
	_check(scheduler.advance_turn(), "advance to turn 1 succeeds")

	# Player turn: reset Block (simulates start_player_turn)
	_check(party.start_player_turn(), "player turn resets hero Block")
	_check(party.get_hero(1).get("block") == 0, "Warden Block reset to 0")

	# Phase 1
	var turn1_intents := scheduler.get_intents()
	var result1 := phase.execute_phase(party, enemies, turn1_intents)
	_check(result1.get("ok") == true, "phase 1 succeeds")

	# Source 1 (position 1) blocks; source 2 (position 2) attacks target 1 (Warden 40 -> 39, no Block)
	_check(enemies.get_enemy(1).get("hp") == 12 and enemies.get_enemy(1).get("block") == 1,
		"phase 1: Ragling 12 HP, 1 Block")
	_check(enemies.get_enemy(2).get("hp") == 12 and enemies.get_enemy(2).get("block") == 1,
		"phase 1: Guard Ragling 12 HP, 1 Block (retains previous)")
	_check(party.get_hero(1).get("hp") == 39 and party.get_hero(1).get("block") == 0,
		"phase 1: Warden 40 -> 39 HP, 0 Block")
	_check(party.get_hero(2).get("hp") == 30 and party.get_hero(2).get("block") == 0,
		"phase 1: Seamstress 30 HP, 0 Block")
	_check(party.get_hero(3).get("hp") == 25 and party.get_hero(3).get("block") == 0,
		"phase 1: Tinker 25 HP, 0 Block")

func _test_negative_cases() -> void:
	# Slain attacker is skipped without side effects
	var party := _build_authored_party()
	var enemies := _build_authored_enemies()
	var parsed := _load_json("res://data/encounters/cross_stitch_guard.json")
	var scheduler := CombatEnemyIntents.new(parsed)
	var phase := CombatEnemyPhase.new()
	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "negative: opening block")

	# Slay source 1 (Ragling at position 1)
	_check(enemies.apply_damage(1, 12), "slay source 1")
	_check(enemies.is_slain(1), "source 1 slain")

	var turn0 := scheduler.get_intents()
	var result := phase.execute_phase(party, enemies, turn0)
	_check(result.get("ok") == true, "negative: phase succeeds with slain source 1")
	var events: Array = result.get("events")
	_check(events.size() == 2, "negative: two events reported")
	var event0: Dictionary = {}
	var event1: Dictionary = {}
	for i in range(events.size()):
		if i == 0:
			event0 = events[i]
		elif i == 1:
			event1 = events[i]
	_check(event0 == {"type": "attack", "enemy_position": 1, "target_position": 3, "applied": false},
		"negative: slain source 1 attack skipped (applied false)")
	_check(event1 == {"type": "block", "enemy_position": 2, "applied": true},
		"negative: source 2 block applied")

	# Downed target at position 3 is not attacked or redirected
	party = _build_authored_party()
	_check(party.apply_damage(3, 26), "down Tinker (position 3)")
	_check(party.is_downed(3), "Tinker downed")

	enemies = _build_authored_enemies()
	scheduler = CombatEnemyIntents.new(parsed)
	turn0 = scheduler.get_intents()
	result = phase.execute_phase(party, enemies, turn0)
	_check(result.get("ok") == true, "negative: phase with downed target succeeds")
	events = result.get("events")
	_check(events.size() == 2, "negative: two events with downed target")
	var evt0_down: Dictionary = {}
	var evt1_down: Dictionary = {}
	for i in range(events.size()):
		if i == 0:
			evt0_down = events[i]
		elif i == 1:
			evt1_down = events[i]
	_check(evt0_down.get("enemy_position") == 1 and evt0_down.get("applied") == false
		and evt0_down.get("target_position") == 3,
		"negative: source 1 attacks downed target 3, applied false (not redirected)")
	_check(evt1_down.get("enemy_position") == 2 and evt1_down.get("applied") == true,
		"negative: source 2 block applied")

	# Malformed target_position rejected
	var bad_def := [{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 1}]}]
	var bad_sched := CombatEnemyIntents.new(bad_def)
	_check(not bad_sched.is_valid(), "negative: missing target_position invalid")
	_check(bad_sched.get_intents().is_empty(), "negative: invalid schedule empty intents")

	# Mutating returned intent snapshot does not affect future intentions
	var normal_sched := CombatEnemyIntents.new(parsed)
	var snapshot := normal_sched.get_intents()
	snapshot[0]["type"] = "block"
	snapshot.append({"extra": 1})
	var future := normal_sched.get_intents()
	_check(future[0].get("type") == "attack", "negative: mutation of snapshot does not alter scheduler")
	_check(future.size() == 2, "negative: future intents unchanged size")

func _test_existing_encounters_preserved() -> void:
	# Verify starter_attacks, guard_counterattack, ragling_rearline_feint remain available
	var starter := _load_json("res://data/encounters/starter_attacks.json")
	_check(starter is Array, "existing: starter_attacks.json array")
	var starter_source1: Dictionary = {}
	var starter_source2: Dictionary = {}
	for entry in starter:
		if entry is Dictionary:
			if entry.get("enemy_position") == 1:
				starter_source1 = entry
			elif entry.get("enemy_position") == 2:
				starter_source2 = entry
	_check(starter_source1.get("pattern")[0].get("type") == "attack"
		and starter_source1.get("pattern")[0].get("amount") == 1
		and starter_source1.get("pattern")[0].get("target_position") == 1,
		"existing: starter_attacks source 1 action preserved")

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
		"existing: guard_counterattack actions preserved")

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
		"existing: ragling_rearline_feint source 1 preserved")

func _test_deterministic_replay_no_rng() -> void:
	# Replay by fresh same-seed setup; verify no scheduler mutation or RNG consumption
	var heroes_raw := _load_json("res://data/heroes/starter_party.json")
	var warden_raw := _find_hero_by_id(heroes_raw, "warden")
	var seamstress_raw := _find_hero_by_id(heroes_raw, "seamstress")
	var tinker_raw := _find_hero_by_id(heroes_raw, "tinker")
	var party_defs := [
		warden_raw.duplicate(true),
		seamstress_raw.duplicate(true),
		tinker_raw.duplicate(true)
	]
	var party_a := CombatParty.new(party_defs)
	var enemies_a := CombatEnemies.new([
		_find_enemy_by_id(_load_json("res://data/enemies/starter_enemies.json"), "ragling").duplicate(true),
		_find_enemy_by_id(_load_json("res://data/enemies/starter_enemies.json"), "ragling_guard").duplicate(true)
	])
	var parsed := _load_json("res://data/encounters/cross_stitch_guard.json")
	var scheduler_a := CombatEnemyIntents.new(parsed)
	var phase_a := CombatEnemyPhase.new()
	var opening_a := CombatStartingBlock.new(party_a)
	_check(opening_a.apply(), "replay: opening block A")

	var party_b := CombatParty.new(party_defs)
	var enemies_b := CombatEnemies.new([
		_find_enemy_by_id(_load_json("res://data/enemies/starter_enemies.json"), "ragling").duplicate(true),
		_find_enemy_by_id(_load_json("res://data/enemies/starter_enemies.json"), "ragling_guard").duplicate(true)
	])
	var scheduler_b := CombatEnemyIntents.new(parsed)
	var phase_b := CombatEnemyPhase.new()
	var opening_b := CombatStartingBlock.new(party_b)
	_check(opening_b.apply(), "replay: opening block B")

	for turn in range(4):
		var intents_a := scheduler_a.get_intents()
		var intents_b := scheduler_b.get_intents()
		_check(intents_a == intents_b, "replay turn %d: identical intents" % turn)

		var result_a := phase_a.execute_phase(party_a, enemies_a, intents_a)
		var result_b := phase_b.execute_phase(party_b, enemies_b, intents_b)
		_check(result_a == result_b, "replay turn %d: identical phase results" % turn)
		_check(party_a.get_heroes() == party_b.get_heroes(), "replay turn %d: party states identical" % turn)
		_check(enemies_a.get_enemies() == enemies_b.get_enemies(), "replay turn %d: enemy states identical" % turn)

		scheduler_a.advance_turn()
		scheduler_b.advance_turn()

		if turn % 2 == 1:
			party_a.start_player_turn()
			party_b.start_player_turn()

	# Verify no RNG consumption
	seed(0xDEADBEEF)
	var baseline_randi = randi()

	seed(0xDEADBEEF)
	var unused_intents := scheduler_a.get_intents()
	_check(randi() == baseline_randi, "replay: get_intents does not consume RNG")

	seed(0xDEADBEEF)
	var before_advance = scheduler_a.get_intents()
	var result_before := phase_a.execute_phase(party_a, enemies_a, before_advance)
	_check(result_before.get("ok") == true, "replay: phase executes")
	_check(randi() == baseline_randi, "replay: execute_phase does not consume RNG")

func _build_authored_party() -> CombatParty:
	var heroes_raw := _load_json("res://data/heroes/starter_party.json")
	var warden_raw := _find_hero_by_id(heroes_raw, "warden")
	var seamstress_raw := _find_hero_by_id(heroes_raw, "seamstress")
	var tinker_raw := _find_hero_by_id(heroes_raw, "tinker")
	var party_defs := [
		warden_raw.duplicate(true),
		seamstress_raw.duplicate(true),
		tinker_raw.duplicate(true)
	]
	return CombatParty.new(party_defs)

func _build_authored_enemies() -> CombatEnemies:
	var enemies_raw := _load_json("res://data/enemies/starter_enemies.json")
	var ragling_raw := _find_enemy_by_id(enemies_raw, "ragling")
	var guard_raw := _find_enemy_by_id(enemies_raw, "ragling_guard")
	var enemy_defs := [ragling_raw.duplicate(true), guard_raw.duplicate(true)]
	return CombatEnemies.new(enemy_defs)
