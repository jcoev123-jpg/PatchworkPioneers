extends SceneTree

var failures: Array[String] = []
var checks := 0
var resolver := CombatEnemyAttacks.new()


func _initialize() -> void:
	_test_order_and_damage()
	_test_downed_targets()
	_test_rejections()
	_test_empty_zero_and_replay()
	if failures.is_empty():
		print("combat_enemy_attacks_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_enemy_attacks_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _party() -> CombatParty:
	var party := CombatParty.new([
		{"id": "a", "max_hp": 10, "metadata": {"tags": ["front"]}},
		{"id": "b", "max_hp": 12}, {"id": "c", "max_hp": 14}])
	_check(party.is_valid() and party.get_heroes().size() == 3, "fixture has three valid heroes")
	return party


func _attack(source: int, target: int, amount: int) -> Dictionary:
	return {"enemy_position": source, "target_position": target, "amount": amount}


func _event(source: int, target: int, applied: bool) -> Dictionary:
	return {"enemy_position": source, "target_position": target, "applied": applied}


func _test_order_and_damage() -> void:
	var party := _party()
	_check(party.gain_block(1, 5), "prepare Block")
	var unrelated := [party.get_hero(2), party.get_hero(3)]
	var attacks := [_attack(3, 1, 100), _attack(1, 1, 3), _attack(2, 1, 6)]
	var original := attacks.duplicate(true)
	var result := resolver.execute_attacks(party, attacks)
	_check(result == {"ok": true, "events": [_event(1, 1, true), _event(2, 1, true),
		_event(3, 1, true)]}, "shuffled sources resolve in ascending order")
	_check(attacks == original, "resolution preserves caller array order and dictionaries")
	_check(party.get_hero(1)["hp"] == 0 and party.get_hero(1)["block"] == 0
		and party.is_downed(1), "overkill clamps HP and downs target")
	_check([party.get_hero(2), party.get_hero(3)] == unrelated, "fixed hits preserve unrelated heroes")
	party = _party()
	_check(party.gain_block(1, 5), "prepare overflow fixture")
	_check(resolver.execute_attacks(party, [_attack(2, 1, 6), _attack(1, 1, 3)])["ok"],
		"blocked and overflow attacks succeed")
	_check(party.get_hero(1)["block"] == 0 and party.get_hero(1)["hp"] == 6,
		"Block absorbs five and only four damage reaches HP")
	party = _party()
	_check(party.gain_block(2, 5), "prepare fully blocked fixture")
	_check(resolver.execute_attacks(party, [_attack(1, 2, 3)]) ==
		{"ok": true, "events": [_event(1, 2, true)]}, "fully blocked damage still applies")
	_check(party.get_hero(2)["hp"] == 12 and party.get_hero(2)["block"] == 2,
		"fully blocked hit consumes only its amount of Block")


func _test_downed_targets() -> void:
	var party := _party()
	_check(party.apply_damage(2, 12) and party.is_downed(2), "target starts downed")
	_check(party.gain_block(3, 4), "unrelated protected hero")
	var before := party.get_heroes()
	_check(resolver.execute_attacks(party, [_attack(3, 2, 0), _attack(1, 2, 100)]) ==
		{"ok": true, "events": [_event(1, 2, false), _event(3, 2, false)]},
		"already downed targets skip even zero damage")
	_check(party.get_heroes() == before, "skips preserve complete party without revival or retargeting")
	party = _party()
	var allies := [party.get_hero(2), party.get_hero(3)]
	_check(resolver.execute_attacks(party, [_attack(3, 1, 1), _attack(2, 1, 10),
		_attack(1, 1, 10)]) == {"ok": true, "events": [_event(1, 1, true),
		_event(2, 1, false), _event(3, 1, false)]}, "earlier lethal hit causes subsequent fixed hits to skip")
	_check(party.is_downed(1) and party.get_hero(1)["hp"] == 0
		and [party.get_hero(2), party.get_hero(3)] == allies, "sequential lethal hits never retarget")
	_check(party.apply_damage(2, 12) and party.apply_damage(3, 14) and party.is_defeated(),
		"prepare valid defeated party")
	before = party.get_heroes()
	_check(resolver.execute_attacks(party, [_attack(1, 3, 5)]) ==
		{"ok": true, "events": [_event(1, 3, false)]}, "defeated valid party permits skipped phase")
	_check(party.get_heroes() == before, "defeated party stays unchanged")


func _reject(party: CombatParty, attacks: Array) -> void:
	var before := party.get_heroes()
	var original := attacks.duplicate(true)
	_check(resolver.execute_attacks(party, attacks) == {"ok": false, "events": []},
		"malformed phase rejects with no events")
	_check(party.get_heroes() == before, "rejection preserves complete party state")
	_check(attacks == original, "rejection preserves caller intents")


func _test_rejections() -> void:
	_check(resolver.execute_attacks(null, []) == {"ok": false, "events": []}, "null party rejects")
	var invalid := CombatParty.new([])
	_check(not invalid.is_valid(), "invalid party fixture is actually invalid")
	_reject(invalid, [])
	_reject(invalid, [_attack(1, 1, 1)])
	var party := _party()
	_check(party.apply_damage(1, 2) and party.gain_block(1, 4)
		and party.apply_damage(3, 14), "negative fixture is wounded, blocked and downed")
	var malformed: Array = [null, 3, "attack", [], {},
		{"target_position": 1, "amount": 1}, {"enemy_position": 2, "amount": 1},
		{"enemy_position": 2, "target_position": 1}]
	for field in ["enemy_position", "target_position", "amount"]:
		var bad_values: Array = [null, true, false, "2", 2.0, [], {}]
		if field == "amount":
			bad_values.append(-1)
		else:
			bad_values.append_array([-1, 0, 4, CombatParty.MAX_INT])
		for value in bad_values:
			var attack := _attack(2, 2, 1)
			attack[field] = value
			malformed.append(attack)
	for bad in malformed:
		# A valid damaging first entry must not run before later validation fails.
		_reject(party, [_attack(1, 1, 7), bad])
	_reject(party, [_attack(1, 1, 7), _attack(1, 2, 3)])
	_reject(party, [_attack(3, 1, 7), _attack(3, 3, 0)])


func _test_empty_zero_and_replay() -> void:
	var party := _party()
	_check(party.gain_block(2, 3), "prepare zero damage fixture")
	var before := party.get_heroes()
	_check(resolver.execute_attacks(party, []) == {"ok": true, "events": []}, "empty valid phase succeeds")
	_check(resolver.execute_attacks(party, [_attack(2, 2, 0)]) ==
		{"ok": true, "events": [_event(2, 2, true)]}, "zero damage on living target applies")
	_check(party.get_heroes() == before, "empty and zero damage phases preserve all state")
	var attacks := [_attack(3, 1, 1), _attack(1, 1, 14), _attack(2, 2, 7)]
	var original := attacks.duplicate(true)
	var expected_state: Array = []
	var expected_result: Dictionary = {}
	for repetition in range(5):
		party = _party()
		_check(party.gain_block(1, 3) and party.gain_block(2, 2), "replay fixture starts identically")
		var result := resolver.execute_attacks(party, attacks)
		_check(result == {"ok": true, "events": [_event(1, 1, true), _event(2, 2, true),
			_event(3, 1, false)]}, "replay has exact ordered applied and skipped events")
		_check(party.get_hero(1)["hp"] == 0 and party.get_hero(2)["hp"] == 7
			and party.get_hero(2)["block"] == 0 and party.get_hero(3)["hp"] == 14,
			"replay produces exact final HP and Block")
		if repetition == 0:
			expected_state = party.get_heroes()
			expected_result = result.duplicate(true)
		else:
			_check(result == expected_result and party.get_heroes() == expected_state,
				"identical fixtures reproduce complete events and state")
	_check(attacks == original, "repeated execution preserves shared input")
