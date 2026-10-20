extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_special_schema()
	_test_one_enemy()
	_test_three_enemies_and_wrap()
	_test_copy_isolation_and_replay()
	_test_no_combat_mutation()
	_test_invalid_schedules()
	if failures.is_empty():
		print("combat_enemy_intents_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_enemy_intents_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _attack(amount: int, target: int) -> Dictionary:
	return {"type": "attack", "amount": amount, "target_position": target}


func _block(amount: int) -> Dictionary:
	return {"type": "block", "amount": amount}


func _enemy(position: int, pattern: Array) -> Dictionary:
	return {"enemy_position": position, "pattern": pattern}


func _announced(position: int, action: Dictionary) -> Dictionary:
	var result := action.duplicate(true)
	result["enemy_position"] = position
	return result


func _three_enemies() -> Array:
	# Deliberately shuffled source positions and independently sized patterns.
	return [
		_enemy(3, [_attack(8, 2)]),
		_enemy(1, [_attack(6, 1), _block(4)]),
		_enemy(2, [_block(2), _attack(0, 3), _block(0)])
	]


func _turns() -> Array:
	return [
		[_announced(1, _attack(6, 1)), _announced(2, _block(2)), _announced(3, _attack(8, 2))],
		[_announced(1, _block(4)), _announced(2, _attack(0, 3)), _announced(3, _attack(8, 2))],
		[_announced(1, _attack(6, 1)), _announced(2, _block(0)), _announced(3, _attack(8, 2))],
		[_announced(1, _block(4)), _announced(2, _block(2)), _announced(3, _attack(8, 2))],
		[_announced(1, _attack(6, 1)), _announced(2, _attack(0, 3)), _announced(3, _attack(8, 2))],
		[_announced(1, _block(4)), _announced(2, _block(0)), _announced(3, _attack(8, 2))]
	]


func _test_one_enemy() -> void:
	var schedule := CombatEnemyIntents.new([_enemy(3, [_block(0), _attack(3, 3)])])
	_check(schedule.is_valid(), "single enemy position 3 is valid without renumbering")
	_check(schedule.get_intents() == [_announced(3, _block(0))],
		"turn zero announces zero Block without a target")
	_check(schedule.advance_turn(), "one-enemy advance succeeds")
	_check(schedule.get_intents() == [_announced(3, _attack(3, 3))],
		"second turn announces exact attack hero target 3")
	_check(schedule.advance_turn(), "one-enemy wrap advances")
	_check(schedule.get_intents() == [_announced(3, _block(0))],
		"single enemy loops back to turn zero")


func _test_three_enemies_and_wrap() -> void:
	var definitions := _three_enemies()
	var original := definitions.duplicate(true)
	var schedule := CombatEnemyIntents.new(definitions)
	_check(schedule.is_valid(), "shuffled three-enemy fixture is valid")
	var expected := _turns()
	for turn in range(13):
		var announced := schedule.get_intents()
		_check(announced == expected[turn % expected.size()],
			"turn %d has exact sorted fixed action shapes and independently wrapping cycles" % turn)
		_check(announced.size() == 3
			and announced[0]["enemy_position"] == 1
			and announced[1]["enemy_position"] == 2
			and announced[2]["enemy_position"] == 3,
			"turn %d returns one intent from each fixed enemy position" % turn)
		_check(schedule.advance_turn(), "turn %d advances explicitly" % turn)
	_check(definitions == original, "turn selection and advance never change caller definitions")


func _test_copy_isolation_and_replay() -> void:
	var definitions := _three_enemies()
	var original := definitions.duplicate(true)
	var schedule := CombatEnemyIntents.new(definitions)
	_check(schedule.is_valid(), "isolation schedule is valid before mutations")
	definitions[0]["pattern"][0]["amount"] = 777
	definitions[1]["pattern"][0]["target_position"] = 3
	definitions[2]["pattern"].append(_attack(900, 1))
	definitions.reverse()
	definitions.clear()
	_check(schedule.get_intents() == _turns()[0],
		"caller mutations of nested dictionaries, arrays and order cannot alter schedule")
	var first := schedule.get_intents()
	first[0]["amount"] = 1000
	first[0]["target_position"] = 3
	first[1]["type"] = "attack"
	first[2]["enemy_position"] = 1
	first.append({"invented": true})
	_check(schedule.get_intents() == _turns()[0],
		"editing returned dictionaries or array cannot modify subsequent announcements")
	_check(schedule.advance_turn(), "isolation schedule advances")
	var another := schedule.get_intents()
	another[0].clear()
	another.remove_at(1)
	_check(schedule.get_intents() == _turns()[1],
		"return values from later turns are also independent defensive snapshots")

	var first_replay := CombatEnemyIntents.new(original)
	var second_replay := CombatEnemyIntents.new(original.duplicate(true))
	_check(first_replay.is_valid() and second_replay.is_valid(), "both replay fixtures are valid")
	var trace_a: Array = []
	var trace_b: Array = []
	for turn in range(18):
		trace_a.append(first_replay.get_intents())
		trace_b.append(second_replay.get_intents())
		_check(first_replay.advance_turn() and second_replay.advance_turn(),
			"both replay instances advance at turn %d" % turn)
	_check(trace_a == trace_b, "identical initial patterns and advances have identical complete sequences")
	for turn in range(trace_a.size()):
		_check(trace_a[turn] == _turns()[turn % 6],
			"deterministic replay turn %d matches exact authored cycle" % turn)
	_check(original == _three_enemies(), "replays do not mutate their input")


func _test_no_combat_mutation() -> void:
	var party := CombatParty.new([
		{"id": "a", "max_hp": 10}, {"id": "b", "max_hp": 12}, {"id": "c", "max_hp": 14}])
	_check(party.is_valid(), "combat party fixture is valid")
	_check(party.gain_block(1, 5) and party.apply_damage(2, 3),
		"combat fixture is actually blocked and wounded")
	var state_before := party.get_heroes()
	var scheduler := CombatEnemyIntents.new(_three_enemies())
	_check(scheduler.is_valid(), "nonmutation scheduler is valid")
	for turn in range(10):
		_check(scheduler.get_intents().size() == 3 and scheduler.advance_turn(),
			"selection-only scheduler announces and advances without execution")
	_check(party.get_heroes() == state_before,
		"announcing attacks and Blocks never changes any party HP or Block")


func _reject(name: String, definitions: Array) -> void:
	var before := definitions.duplicate(true)
	var scheduler := CombatEnemyIntents.new(definitions)
	_check(not scheduler.is_valid(), name + ": entirely invalid")
	_check(scheduler.get_intents().is_empty(), name + ": no partial schedule is exposed")
	_check(not scheduler.advance_turn(), name + ": cannot advance invalid schedule")
	_check(scheduler.get_intents().is_empty(), name + ": remains inert after advance")
	_check(definitions == before, name + ": rejection preserves caller definitions")


func _test_invalid_schedules() -> void:
	_reject("empty lineup", [])
	_reject("more than three enemies", [
		_enemy(1, [_block(1)]), _enemy(2, [_block(1)]),
		_enemy(3, [_block(1)]), _enemy(1, [_block(1)])])
	_reject("duplicate occupied position", [_enemy(1, [_attack(1, 1)]), _enemy(1, [_block(1)])])
	for position in [0, -1, 4, null, true, false, "1", 1.0, [], {}]:
		_reject("invalid position " + str(position), [_enemy(2, [_block(1)]),
			{"enemy_position": position, "pattern": [_block(2)]}])
	for invalid in [null, "enemy", [], 3, {}]:
		_reject("malformed definition " + str(invalid), [_enemy(1, [_block(2)]), invalid])
	_reject("missing enemy position", [_enemy(1, [_block(1)]), {"pattern": [_block(2)]}])
	_reject("missing pattern", [_enemy(1, [_block(1)]), {"enemy_position": 2}])
	_reject("unexpected definition key", [_enemy(1, [_block(1)]),
		{"enemy_position": 2, "pattern": [_block(2)], "hp": 10}])
	for pattern in [[], null, "attack", {}, 10, [null], [42], [[]],
		[_block(2), {}], [_attack(6, 1), {"type": "unknown", "amount": 4}]]:
		_reject("empty or malformed pattern " + str(pattern), [
			_enemy(1, [_attack(5, 1)]), {"enemy_position": 2, "pattern": pattern}])
	var bad_actions: Array = [
		{}, {"type": "attack"}, {"type": "block"},
		{"amount": 1}, {"type": "heal", "amount": 3},
		{"type": 4, "amount": 1}, {"type": "attack", "amount": 2},
		{"type": "block", "amount": 2, "target_position": 1},
		{"type": "attack", "amount": 2, "target_position": 1, "status": "poison"},
		{"type": "attack", "amount": 1, "target_position": null},
		{"type": "attack", "amount": 1, "target_position": 0},
		{"type": "attack", "amount": 1, "target_position": 4},
		{"type": "attack", "amount": 1, "target_position": true},
		{"type": "attack", "amount": 1, "target_position": 1.0},
		{"type": "attack", "amount": 1, "target_position": "2"}
	]
	for kind in ["attack", "block"]:
		for amount in [-1, -100, null, true, false, 2.0, "3", [], {}]:
			var action: Dictionary = _attack(1, 1) if kind == "attack" else _block(1)
			action["amount"] = amount
			bad_actions.append(action)
	for bad in bad_actions:
		# A valid earlier enemy and a valid first action must not leak from a bad later action.
		_reject("invalid late action " + str(bad), [
			_enemy(1, [_attack(7, 1)]), _enemy(2, [_block(3), bad])])


func _test_special_schema() -> void:
	var valid: Array = [
		{"type": "shove", "amount": 0, "target_position": 2, "direction": -1},
		{"type": "debuff", "amount": 2, "target_position": 1, "status": "weak"},
		{"type": "buff", "amount": 3}]
	for action in valid:
		_check(CombatEnemyIntents.new([_enemy(1, [action])]).is_valid(), "special schema accepts " + str(action))
		for key in action:
			var missing: Dictionary = action.duplicate(true)
			missing.erase(key)
			_reject("missing special key", [_enemy(1, [_block(1), missing])])
		var extra: Dictionary = action.duplicate(true)
		extra["extra"] = 1
		_reject("extra special key", [_enemy(1, [_block(1), extra])])
		for field in ["amount", "target_position", "direction", "status"]:
			if not action.has(field):
				continue
			for value in [null, true, 0.5, "1", [], {}]:
				var bad: Dictionary = action.duplicate(true)
				bad[field] = value
				_reject("invalid special field", [_enemy(1, [_block(1), bad])])
	for bad in [
		{"type": "shove", "amount": 1, "target_position": 2, "direction": -1},
		{"type": "shove", "amount": 0, "target_position": 1, "direction": -1},
		{"type": "shove", "amount": 0, "target_position": 2, "direction": 0},
		{"type": "debuff", "amount": 1, "target_position": 1, "status": "poison"},
		{"type": "debuff", "amount": 0, "target_position": 1, "status": "weak"},
		{"type": "buff", "amount": 0}]:
		_reject("special range rejection", [_enemy(1, [_block(1), bad])])
