extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_construction()
	_test_invalid_construction()
	_test_required_queries()
	_test_status_transaction()
	for count in range(1, 4):
		_test_damage_and_death(count)
		_test_rejections(count)
		_test_replay(count)
	if failures.is_empty():
		print("combat_enemies_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_enemies_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _test_status_transaction() -> void:
	var enemies := CombatEnemies.new(_definitions(3))
	var identity: Dictionary = enemies._enemies[0]
	var additions := {1: {"bleed": 3}, 3: {"weak": 1}}
	var input := additions.duplicate(true)
	_check(enemies.can_apply_statuses(additions) and enemies.apply_statuses(additions), "valid status batch commits")
	_check(enemies.apply_statuses({1: {"bleed": 3, "exposed": 2}}), "repeated statuses add")
	var expected := _expected(3)
	expected[0]["statuses"] = {"bleed": 6, "exposed": 2}
	expected[2]["statuses"] = {"weak": 1}
	_check(enemies.get_enemies() == expected and is_same(identity, enemies._enemies[0]), "only named counters change, identity and slots retained")
	_check(additions == input, "transaction input immutable")
	for bad in [{1: {"bleed": 1}, 4: {"weak": 1}}, {1: {"bleed": 1}, 3: {"weak": -1}},
		{1: {"bleed": 1}, 3: {"weak": 1.5}}, {"1": {}}, {2: []}, {2: {"poison": 1}},
		{1: {"bleed": CombatEnemies.MAX_INT}}, {1: {"bleed": 1}, 3: {"weak": CombatEnemies.MAX_INT}}, {2: {8: 1}}]:
		_check(not enemies.can_apply_statuses(bad) and not enemies.apply_statuses(bad), "bad late entry or overflow rejects")
		_check(enemies.get_enemies() == expected, "failed status transaction is atomic")
	for malformed in [[], {"weak": -1}, {"exposed": "1"}, {"unknown": 1}]:
		enemies._enemies[2]["statuses"] = malformed
		var before := enemies.get_enemies()
		_check(not enemies.apply_statuses({1: {"bleed": 1}}) and enemies.get_enemies() == before, "malformed untouched slot rejects whole transaction")
	enemies._enemies[2]["statuses"] = {"weak": 1}
	_check(enemies.apply_damage(1, 100) and enemies.apply_statuses({1: {"bleed": 1}}), "confirmed lethal recipient accepts status without revival")
	_check(enemies.is_slain(1) and enemies.get_enemy(1).statuses == {"bleed": 7, "exposed": 2}, "lethal status retains original record")
	var before := enemies.get_enemies()
	_check(enemies.apply_statuses({1: {"bleed": 0}, 2: {}}) and enemies.get_enemies() == before, "zero additions preserve exact records")
	_check(enemies.apply_statuses({3: {"weak": CombatEnemies.MAX_INT - 1}})
		and enemies.get_enemy(3).statuses.weak == CombatEnemies.MAX_INT, "status counter reaches maximum without overflow")
	enemies._enemies[2]["position"] = 2
	before = enemies.get_enemies()
	_check(not enemies.apply_statuses({1: {"bleed": 1}}) and enemies.get_enemies() == before, "invalid original slot rejects atomically")


func _definitions(count: int) -> Array:
	var definitions: Array = []
	for index in range(count):
		definitions.append({"id": "fixture_%d" % index, "max_hp": 11 + index,
			"metadata": {"tags": ["synthetic"]}, "position": -1, "hp": -1, "block": -1})
	return definitions


func _expected(count: int) -> Array:
	var expected := _definitions(count)
	for index in range(count):
		expected[index]["position"] = index + 1
		expected[index]["hp"] = expected[index]["max_hp"]
		expected[index]["block"] = 0
	return expected


func _test_construction() -> void:
	for count in range(1, 4):
		var definitions := _definitions(count)
		var input_before := definitions.duplicate(true)
		var enemies := CombatEnemies.new(definitions)
		var expected := _expected(count)
		_check(enemies.is_valid() and enemies.get_enemies().size() == count, "valid roster has actual requested enemies")
		_check(enemies.get_enemies() == expected, "exact ordered full-HP zero-Block state")
		_check(definitions == input_before, "construction preserves input")
		_check(not enemies.is_defeated() and not enemies.has_method("heal"), "living roster is not victory and has no healing API")
		for position in range(1, count + 1):
			_check(enemies.get_enemy(position) == expected[position - 1] and not enemies.is_slain(position), "individual reader has exact living state")
		definitions[0]["metadata"]["tags"].clear()
		definitions[0]["max_hp"] = 999
		definitions.clear()
		_check(enemies.get_enemies() == expected, "constructor deep copy isolates nested input")
		var enemy := enemies.get_enemy(1)
		enemy["hp"] = 0
		enemy["metadata"]["tags"].append("changed")
		var roster := enemies.get_enemies()
		roster[0]["position"] = 99
		roster[0]["metadata"]["tags"].clear()
		roster.clear()
		_check(enemies.get_enemies() == expected, "both state readers return defensive deep copies")


func _test_invalid_construction() -> void:
	var invalid_sets: Array = [[], _definitions(4)]
	for count in range(1, 4):
		for bad in [null, 1, "bad", [], {}, {"id": "", "max_hp": 1},
			{"id": 4, "max_hp": 1}, {"id": &"name", "max_hp": 1},
			{"id": "bad"}, {"max_hp": 1}, {"id": "bad", "max_hp": null},
			{"id": "bad", "max_hp": 0}, {"id": "bad", "max_hp": -1},
			{"id": "bad", "max_hp": 1.0}, {"id": "bad", "max_hp": true},
			{"id": "bad", "max_hp": "2"}]:
			var definitions := _definitions(count)
			definitions[count - 1] = bad
			invalid_sets.append(definitions)
		if count > 1:
			var duplicate := _definitions(count)
			duplicate[count - 1]["id"] = duplicate[0]["id"]
			invalid_sets.append(duplicate)
	for definitions in invalid_sets:
		var before: Array = definitions.duplicate(true)
		var enemies := CombatEnemies.new(definitions)
		_check(not enemies.is_valid() and enemies.get_enemies() == [], "invalid construction rejects atomically, including late malformed entries")
		_check(definitions == before, "rejected construction preserves input")
		_check(not enemies.is_defeated() and not enemies.is_victorious(), "invalid roster never yields vacuous victory")
		for position in [-1, 0, 1, 3, 4]:
			_check(enemies.get_enemy(position) == {} and not enemies.is_slain(position), "invalid roster readers fail closed")
			_check(not enemies.is_dead(position), "required death query fails closed on invalid rosters")
			_reject(enemies, "apply_damage", position, 1)
			_reject(enemies, "gain_block", position, 1)


func _test_required_queries() -> void:
	var enemies := CombatEnemies.new(_definitions(3))
	_check(enemies.has_method("is_dead") and enemies.has_method("is_victorious"),
		"required public death and victory queries exist")
	for position in range(1, 4):
		_check(not enemies.is_dead(position) and enemies.is_dead(position) == enemies.is_slain(position),
			"living enemy is not dead and required query matches the alias")
	_check(not enemies.is_victorious() and enemies.is_victorious() == enemies.is_defeated(),
		"living roster is not victory and required query matches the alias")
	for position in [-1, 0, 4, 100]:
		_check(not enemies.is_dead(position), "required death query fails closed on invalid positions")
	_check(enemies.apply_damage(2, CombatEnemies.MAX_INT), "required queries exercise an intermediate death")
	_check(enemies.is_dead(2) and enemies.is_dead(2) == enemies.is_slain(2),
		"required death query reports the slain slot after a kill")
	_check(not enemies.is_dead(1) and not enemies.is_dead(3), "surviving neighbors are not dead")
	_check(not enemies.is_victorious() and enemies.is_victorious() == enemies.is_defeated(),
		"required victory query stays false while an enemy lives")
	_check(enemies.apply_damage(1, CombatEnemies.MAX_INT) and not enemies.is_victorious(),
		"required victory query stays false with one enemy alive")
	_check(enemies.apply_damage(3, CombatEnemies.MAX_INT) and enemies.is_victorious(),
		"required victory query is true only after the final death")
	_check(enemies.is_victorious() == enemies.is_defeated(), "required victory query matches the alias at victory")
	_check(not enemies.is_dead(0) and not enemies.is_dead(4), "required death query fails closed after victory")
	var invalid := CombatEnemies.new([])
	_check(not invalid.is_victorious(), "invalid roster never yields required victory")
	for position in [-1, 0, 1, 4]:
		_check(not invalid.is_dead(position), "invalid roster never yields required death")


func _perform(enemies: CombatEnemies, expected: Array, method: String, position: int, amount: int, hp: int, block: int) -> void:
	_check(enemies.get_enemies() == expected, "exact pre-operation roster")
	_check(enemies.call(method, position, amount) == true, method + " succeeds on living target")
	expected[position - 1]["hp"] = hp
	expected[position - 1]["block"] = block
	_check(enemies.get_enemies() == expected, "exact post-operation roster includes unchanged neighbors")


func _test_damage_and_death(count: int) -> void:
	var enemies := CombatEnemies.new(_definitions(count))
	var expected := _expected(count)
	for position in range(1, count + 1):
		_perform(enemies, expected, "gain_block", position, 2, 10 + position, 2)
	_perform(enemies, expected, "gain_block", 1, 5, 11, 7)
	_perform(enemies, expected, "apply_damage", 1, 3, 11, 4)
	_perform(enemies, expected, "apply_damage", 1, 4, 11, 0)
	_perform(enemies, expected, "gain_block", 1, 3, 11, 3)
	_perform(enemies, expected, "apply_damage", 1, 7, 7, 0)
	_check(not enemies.is_defeated() and not enemies.is_victorious(), "partial damage is not victory")
	_perform(enemies, expected, "apply_damage", 1, 7, 0, 0)
	_check(enemies.is_slain(1) and enemies.is_defeated() == (count == 1), "exact lethal hit wins only on final enemy")
	_check(enemies.is_dead(1) and enemies.is_dead(1) == enemies.is_slain(1) and enemies.is_victorious() == enemies.is_defeated(),
		"required queries match the aliases at the first death")
	for amount in [0, 1, CombatEnemies.MAX_INT]:
		_reject(enemies, "apply_damage", 1, amount)
		_reject(enemies, "gain_block", 1, amount)
	_check(enemies.get_enemies() == expected, "single-death late calls preserve slain slot and living neighbors")
	for position in range(2, count + 1):
		_perform(enemies, expected, "apply_damage", position, CombatEnemies.MAX_INT, 0, 0)
		_check(enemies.is_slain(position) and enemies.is_defeated() == (position == count), "overkill clamps at zero; victory waits for last living enemy")
		_check(enemies.is_dead(position) and enemies.is_victorious() == (position == count),
			"required queries track each death and the final-death victory")
	_check(enemies.is_valid() and enemies.get_enemies().size() == count, "slain roster stays valid and retains all slots")
	for position in range(1, count + 1):
		_check(enemies.get_enemy(position)["position"] == position, "death preserves position")
		for amount in [0, 1, CombatEnemies.MAX_INT]:
			_reject(enemies, "apply_damage", position, amount)
			_reject(enemies, "gain_block", position, amount)
	_check(enemies.is_defeated() and enemies.is_victorious(), "late calls preserve victory through the required query")


func _reject(enemies: CombatEnemies, method: String, position: int, amount: int) -> void:
	var before := enemies.get_enemies()
	_check(enemies.call(method, position, amount) == false, method + " rejects invalid target/amount")
	_check(enemies.get_enemies() == before, method + " rejection preserves entire roster")


func _test_rejections(count: int) -> void:
	var enemies := CombatEnemies.new(_definitions(count))
	_check(enemies.apply_damage(1, 3) and enemies.gain_block(count, 4), "rejections exercise wounded/protected state")
	for method in ["apply_damage", "gain_block"]:
		for position in [-100, -1, 0, count + 1, 100]:
			_reject(enemies, method, position, 3)
			_check(enemies.get_enemy(position) == {} and not enemies.is_slain(position), "invalid positions read safely")
		for position in range(1, count + 1):
			_reject(enemies, method, position, -1)
			_reject(enemies, method, position, -CombatEnemies.MAX_INT - 1)
			var before := enemies.get_enemies()
			_check(enemies.call(method, position, 0) == true and enemies.get_enemies() == before, "zero on living target succeeds without mutation")
	_check(enemies.gain_block(count, CombatEnemies.MAX_INT - 4), "Block reaches integer maximum exactly")
	_check(enemies.get_enemy(count)["block"] == CombatEnemies.MAX_INT, "maximum Block is exact")
	_reject(enemies, "gain_block", count, 1)
	_reject(enemies, "gain_block", count, CombatEnemies.MAX_INT)
	var before := enemies.get_enemies()
	_check(enemies.apply_damage(count, CombatEnemies.MAX_INT), "maximum Block safely absorbs maximum damage")
	before[count - 1]["block"] = 0
	_check(enemies.get_enemies() == before, "maximum absorption preserves exact HP and neighbors")
	var large := CombatEnemies.new([{"id": "large_fixture", "max_hp": CombatEnemies.MAX_INT}])
	_check(large.is_valid() and large.apply_damage(1, CombatEnemies.MAX_INT), "maximum HP accepts exact lethal hit without arithmetic overflow")
	_check(large.get_enemy(1)["hp"] == 0 and large.is_defeated(), "maximum HP reaches exact zero and victory")


func _test_replay(count: int) -> void:
	var first := CombatEnemies.new(_definitions(count))
	var second := CombatEnemies.new(_definitions(count))
	var operations: Array = [["gain_block", count, 6], ["apply_damage", count, 2],
		["apply_damage", 0, 4], ["gain_block", 1, -1], ["apply_damage", count, 7]]
	for position in range(1, count + 1):
		operations.append(["apply_damage", position, CombatEnemies.MAX_INT])
		operations.append(["gain_block", position, 2])
	for operation in operations:
		var a = first.call(operation[0], operation[1], operation[2])
		var b = second.call(operation[0], operation[1], operation[2])
		_check(a == b and first.get_enemies() == second.get_enemies(), "identical operation replay has identical return and complete state")
		_check(first.is_defeated() == second.is_defeated(), "identical replay has identical victory boundary")
		_check(first.is_victorious() == second.is_victorious(), "identical replay has identical required victory query")
	_check(first.is_defeated() and second.is_defeated(), "replay actually reaches victory")
	_check(first.is_victorious() and second.is_victorious(), "replay reaches victory through the required query")
