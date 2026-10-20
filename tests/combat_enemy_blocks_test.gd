extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_valid_blocks()
	_test_slain_skip()
	_test_empty_phase()
	_test_shuffled_positions()
	_test_n_zero()
	_test_add_to_existing_block()
	_test_block_consumed_by_damage()
	_test_preserve_input_and_neighbors()
	_test_fixed_cycle_integration()
	_test_replay_determinism()
	_test_invalid_enemies()
	_test_malformed_intent()
	_test_wrong_type()
	_test_duplicate_position()
	_test_out_of_roster_position()
	_test_invalid_amount_types()
	_test_negative_amount()
	_test_overflow_rejection()
	_test_partial_mutation_rejected()
	if failures.is_empty():
		print("combat_enemy_blocks_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_enemy_blocks_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _defs(count: int) -> Array:
	var definitions: Array = []
	for index in range(count):
		definitions.append({"id": "fixture_%d" % index, "max_hp": 11 + index})
	return definitions


func _block(position: int, amount: int) -> Dictionary:
	return {"type": "block", "enemy_position": position, "amount": amount}


func _test_valid_blocks() -> void:
	# Living enemy receives Block
	var enemies := CombatEnemies.new(_defs(1))
	var before := enemies.get_enemies()
	var result := CombatEnemyBlocks.execute_blocks(enemies, [_block(1, 5)])
	_check(result["ok"] == true, "valid single block ok=true")
	_check(result["events"].size() == 1, "single event returned")
	_check(result["events"][0] == {"enemy_position": 1, "applied": true}, "event has correct shape")
	_check(enemies.get_enemy(1)["block"] == 5, "block added to living enemy")
	_check(enemies.get_enemy(1)["hp"] == before[0]["hp"], "HP unchanged")


func _test_slain_skip() -> void:
	# Slain enemy is skipped, reports applied=false
	var enemies := CombatEnemies.new(_defs(2))
	_check(enemies.apply_damage(1, CombatEnemies.MAX_INT), "kill enemy 1")
	var before := enemies.get_enemies()
	var result := CombatEnemyBlocks.execute_blocks(enemies, [_block(1, 3), _block(2, 4)])
	_check(result["ok"] == true, "phase with slain source ok=true")
	_check(result["events"].size() == 2, "two events")
	_check(result["events"][0] == {"enemy_position": 1, "applied": false}, "slain source applied=false")
	_check(result["events"][1] == {"enemy_position": 2, "applied": true}, "living source applied=true")
	_check(enemies.get_enemy(1)["block"] == 0, "slain enemy block unchanged")
	_check(enemies.get_enemy(2)["block"] == 4, "living enemy block added")
	# Verify only expected changes: slain enemy unchanged, living enemy block added, HP unchanged
	_check(enemies.get_enemy(1) == before[0], "slain enemy unchanged")
	_check(enemies.get_enemy(2)["hp"] == before[1]["hp"], "living enemy HP unchanged")
	_check(enemies.get_enemy(2)["block"] == before[1]["block"] + 4, "living enemy block increased by 4")


func _test_empty_phase() -> void:
	# Empty phase succeeds with no events
	var enemies := CombatEnemies.new(_defs(2))
	var before := enemies.get_enemies()
	var result := CombatEnemyBlocks.execute_blocks(enemies, [])
	_check(result["ok"] == true, "empty phase ok=true")
	_check(result["events"].size() == 0, "no events for empty phase")
	_check(enemies.get_enemies() == before, "roster unchanged")


func _test_shuffled_positions() -> void:
	# Shuffled positions resolved in ascending order
	var enemies := CombatEnemies.new(_defs(3))
	var blocks := [_block(3, 7), _block(1, 2), _block(2, 5)]
	var result := CombatEnemyBlocks.execute_blocks(enemies, blocks)
	_check(result["ok"] == true, "shuffled phase ok=true")
	_check(result["events"][0]["enemy_position"] == 1, "first event position 1")
	_check(result["events"][1]["enemy_position"] == 2, "second event position 2")
	_check(result["events"][2]["enemy_position"] == 3, "third event position 3")
	_check(enemies.get_enemy(1)["block"] == 2, "block at 1")
	_check(enemies.get_enemy(2)["block"] == 5, "block at 2")
	_check(enemies.get_enemy(3)["block"] == 7, "block at 3")


func _test_n_zero() -> void:
	# N=0 is a no-op on living enemy
	var enemies := CombatEnemies.new(_defs(1))
	var before := enemies.get_enemies()
	var result := CombatEnemyBlocks.execute_blocks(enemies, [_block(1, 0)])
	_check(result["ok"] == true, "zero block ok=true")
	_check(result["events"][0]["applied"] == true, "zero block applied=true")
	_check(enemies.get_enemies() == before, "roster unchanged by zero block")


func _test_add_to_existing_block() -> void:
	# Adding to existing block
	var enemies := CombatEnemies.new(_defs(1))
	_check(enemies.gain_block(1, 4), "pre-add block 4")
	var before := enemies.get_enemies()
	var result := CombatEnemyBlocks.execute_blocks(enemies, [_block(1, 2)])
	_check(result["ok"] == true, "add to existing block ok=true")
	_check(enemies.get_enemy(1)["block"] == 6, "block accumulated to 6")
	_check(enemies.get_enemy(1)["hp"] == before[0]["hp"], "HP unchanged")


func _test_block_consumed_by_damage() -> void:
	# Block is consumed by subsequent damage before HP
	var enemies := CombatEnemies.new(_defs(1))
	_check(CombatEnemyBlocks.execute_blocks(enemies, [_block(1, 5)])["ok"] == true, "add block 5")
	_check(enemies.apply_damage(1, 3), "damage 3 absorbs block")
	_check(enemies.get_enemy(1)["block"] == 2, "block reduced to 2")
	_check(enemies.get_enemy(1)["hp"] == 11, "HP unchanged")
	_check(enemies.apply_damage(1, 5), "damage 5 exceeds block")
	_check(enemies.get_enemy(1)["block"] == 0, "block depleted")
	_check(enemies.get_enemy(1)["hp"] == 8, "HP reduced by remainder")


func _test_preserve_input_and_neighbors() -> void:
	# Caller input dictionaries preserved, other enemies' state preserved
	var enemies := CombatEnemies.new(_defs(3))
	var blocks := [_block(2, 3)]
	var blocks_before := blocks.duplicate(true)
	var before := enemies.get_enemies()
	
	var result := CombatEnemyBlocks.execute_blocks(enemies, blocks)
	_check(result["ok"] == true, "phase ok")
	_check(blocks == blocks_before, "caller blocks array preserved")
	_check(enemies.get_enemy(1) == before[0], "enemy 1 unchanged")
	_check(enemies.get_enemy(3) == before[2], "enemy 3 unchanged")
	_check(enemies.get_enemy(2)["block"] == 3, "enemy 2 block updated")
	_check(enemies.get_enemy(2)["hp"] == before[1]["hp"], "enemy 2 HP unchanged")


func _test_fixed_cycle_integration() -> void:
	# Real CombatEnemyIntents fixed-cycle fixture with both attack and Block actions
	# Filter to Block entries, resolve, verify scheduler's announced turn unchanged until advance_turn()
	var definitions := [
		{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 6, "target_position": 1}, {"type": "block", "amount": 4}]},
		{"enemy_position": 2, "pattern": [{"type": "block", "amount": 2}, {"type": "attack", "amount": 0, "target_position": 3}, {"type": "block", "amount": 0}]},
		{"enemy_position": 3, "pattern": [{"type": "attack", "amount": 8, "target_position": 2}]},
	]
	var scheduler := CombatEnemyIntents.new(definitions)
	_check(scheduler.is_valid(), "scheduler valid")
	
	# Turn 0: filter blocks and resolve (only enemy 2 has block on turn 0)
	var intents_turn0 := scheduler.get_intents()
	var blocks_turn0 := intents_turn0.filter(func(i: Dictionary) -> bool: return i["type"] == "block")
	var expected_blocks_turn0 := [_block(2, 2)]
	_check(blocks_turn0 == expected_blocks_turn0, "turn 0 blocks match expected")
	
	var enemies := CombatEnemies.new(_defs(3))
	var result0 := CombatEnemyBlocks.execute_blocks(enemies, blocks_turn0)
	_check(result0["ok"] == true, "turn 0 blocks resolved")
	_check(enemies.get_enemy(1)["block"] == 0, "enemy 1 block 0")
	_check(enemies.get_enemy(2)["block"] == 2, "enemy 2 block 2")
	_check(enemies.get_enemy(3)["block"] == 0, "enemy 3 block 0")
	
	# Scheduler turn still at 0 until advance_turn()
	var intents_after_resolve := scheduler.get_intents()
	_check(intents_after_resolve == intents_turn0, "scheduler intents unchanged after block resolution")
	
	# Advance turn
	_check(scheduler.advance_turn(), "advance turn 0->1")
	var intents_turn1 := scheduler.get_intents()
	var blocks_turn1 := intents_turn1.filter(func(i: Dictionary) -> bool: return i["type"] == "block")
	# Turn 1: enemy 1 has block(4), enemy 2 has attack(0,3), enemy 3 has attack(8,2)
	var expected_blocks_turn1 := [_block(1, 4)]
	_check(blocks_turn1 == expected_blocks_turn1, "turn 1 blocks match expected")
	
	var result1 := CombatEnemyBlocks.execute_blocks(enemies, blocks_turn1)
	_check(result1["ok"] == true, "turn 1 blocks resolved")
	_check(enemies.get_enemy(1)["block"] == 4, "enemy 1 block 4")
	_check(enemies.get_enemy(2)["block"] == 2, "enemy 2 block unchanged")
	_check(enemies.get_enemy(3)["block"] == 0, "enemy 3 block unchanged")


func _test_replay_determinism() -> void:
	# Repeated fresh fixtures yield identical enemy snapshots and events
	var definitions := _defs(3)
	var blocks := [_block(1, 2), _block(2, 5), _block(3, 7)]
	
	var first_enemies := CombatEnemies.new(definitions)
	var second_enemies := CombatEnemies.new(definitions)
	var blocks_copy1 := blocks.duplicate(true)
	var blocks_copy2 := blocks.duplicate(true)
	
	var result1 := CombatEnemyBlocks.execute_blocks(first_enemies, blocks_copy1)
	var result2 := CombatEnemyBlocks.execute_blocks(second_enemies, blocks_copy2)
	
	_check(result1 == result2, "identical resolution returns identical result")
	_check(first_enemies.get_enemies() == second_enemies.get_enemies(), "identical resolution produces identical state")
	_check(blocks_copy1 == blocks, "first call preserves input")
	_check(blocks_copy2 == blocks, "second call preserves input")


func _test_invalid_enemies() -> void:
	# null/invalid CombatEnemies rejected
	var blocks := [_block(1, 1)]
	
	var result := CombatEnemyBlocks.execute_blocks(null, blocks)
	_check(result["ok"] == false and result["events"].is_empty(), "null enemies rejected")
	
	result = CombatEnemyBlocks.execute_blocks(CombatEnemies.new([]), blocks)
	_check(result["ok"] == false and result["events"].is_empty(), "invalid empty roster rejected")
	
	result = CombatEnemyBlocks.execute_blocks(CombatEnemies.new(_defs(4)), blocks)
	_check(result["ok"] == false and result["events"].is_empty(), "oversized roster rejected")


func _test_malformed_intent() -> void:
	# Non-dictionary, missing/unexpected field
	var enemies := CombatEnemies.new(_defs(1))
	
	var result := CombatEnemyBlocks.execute_blocks(enemies, [null])
	_check(result["ok"] == false, "null intent rejected")
	
	result = CombatEnemyBlocks.execute_blocks(enemies, ["not a dict"])
	_check(result["ok"] == false, "string intent rejected")
	
	result = CombatEnemyBlocks.execute_blocks(enemies, [{"type": "block"}])
	_check(result["ok"] == false, "missing fields rejected")
	
	result = CombatEnemyBlocks.execute_blocks(enemies, [{"type": "block", "enemy_position": 1, "amount": 1, "extra": "field"}])
	_check(result["ok"] == false, "unexpected field rejected")


func _test_wrong_type() -> void:
	# Wrong type ("attack")
	var enemies := CombatEnemies.new(_defs(1))
	var result := CombatEnemyBlocks.execute_blocks(enemies, [{"type": "attack", "enemy_position": 1, "amount": 5}])
	_check(result["ok"] == false and result["events"].is_empty(), "attack type rejected")


func _test_duplicate_position() -> void:
	# Duplicate position rejected
	var enemies := CombatEnemies.new(_defs(2))
	var result := CombatEnemyBlocks.execute_blocks(enemies, [_block(1, 2), _block(1, 3)])
	_check(result["ok"] == false and result["events"].is_empty(), "duplicate position rejected")


func _test_out_of_roster_position() -> void:
	# Position outside roster (0, negative, > roster size)
	var enemies := CombatEnemies.new(_defs(2))
	
	for pos in [-1, 0, 3, 100]:
		var result := CombatEnemyBlocks.execute_blocks(enemies, [_block(pos, 1)])
		_check(result["ok"] == false and result["events"].is_empty(), "out of roster position %d rejected" % pos)


func _test_invalid_amount_types() -> void:
	# Bool/float/string amount rejected
	var enemies := CombatEnemies.new(_defs(1))
	
	for amount in [true, false, 2.5, "3", [], {}]:
		var result := CombatEnemyBlocks.execute_blocks(enemies, [{"type": "block", "enemy_position": 1, "amount": amount}])
		_check(result["ok"] == false and result["events"].is_empty(), "invalid amount type %s rejected" % str(amount))
	
	# Bool/float/string position rejected
	for pos in [true, false, 2.5, "1", [], {}]:
		var result := CombatEnemyBlocks.execute_blocks(enemies, [{"type": "block", "enemy_position": pos, "amount": 1}])
		_check(result["ok"] == false and result["events"].is_empty(), "invalid position type %s rejected" % str(pos))


func _test_negative_amount() -> void:
	# Negative amount rejected
	var enemies := CombatEnemies.new(_defs(1))
	var result := CombatEnemyBlocks.execute_blocks(enemies, [_block(1, -1)])
	_check(result["ok"] == false and result["events"].is_empty(), "negative amount rejected")
	
	result = CombatEnemyBlocks.execute_blocks(enemies, [_block(1, -CombatEnemies.MAX_INT)])
	_check(result["ok"] == false and result["events"].is_empty(), "large negative amount rejected")


func _test_overflow_rejection() -> void:
	# Overflow after earlier valid entry - whole phase rejected
	var enemies := CombatEnemies.new(_defs(2))
	# Set enemy 1 block near MAX_INT
	_check(enemies.gain_block(1, CombatEnemies.MAX_INT - 5), "pre-add near max")
	# Block for enemy 1 would overflow, enemy 2 is valid
	var result := CombatEnemyBlocks.execute_blocks(enemies, [_block(1, 10), _block(2, 3)])
	_check(result["ok"] == false and result["events"].is_empty(), "overflow rejects whole phase")
	# Verify no partial mutation
	_check(enemies.get_enemy(1)["block"] == CombatEnemies.MAX_INT - 5, "enemy 1 block unchanged")
	_check(enemies.get_enemy(2)["block"] == 0, "enemy 2 block unchanged")


func _test_partial_mutation_rejected() -> void:
	# Bad later entry after valid earlier entry - no partial mutation
	var enemies := CombatEnemies.new(_defs(2))
	var before := enemies.get_enemies()
	# First entry valid, second has invalid type
	var result := CombatEnemyBlocks.execute_blocks(enemies, [_block(1, 5), {"type": "heal", "enemy_position": 2, "amount": 3}])
	_check(result["ok"] == false and result["events"].is_empty(), "mixed valid/invalid rejects whole phase")
	_check(enemies.get_enemies() == before, "no partial mutation on rejection")
	
	# Reset and test with invalid position second
	enemies = CombatEnemies.new(_defs(2))
	before = enemies.get_enemies()
	result = CombatEnemyBlocks.execute_blocks(enemies, [_block(1, 5), _block(5, 3)])
	_check(result["ok"] == false and result["events"].is_empty(), "valid then out-of-roster rejects whole phase")
	_check(enemies.get_enemies() == before, "no partial mutation on rejection")