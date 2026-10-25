extends SceneTree

var failures: Array[String] = []
var checks := 0
var helper := RunNormalAttackFloorScaling.new()


func _initialize() -> void:
	_test_contract()
	_test_band_matrix()
	_test_examples()
	_test_rejections()
	_test_no_mutation_and_rng()
	if failures.is_empty():
		print("run_normal_attack_floor_scaling_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_normal_attack_floor_scaling_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _test_contract() -> void:
	_check(helper.has_method("scale_normal_attack"),
		"public scale_normal_attack method exists")

	var result := helper.scale_normal_attack(5, 1)
	_check(result == {"ok": true, "amount": 5},
		"valid call returns ok/amount dictionary")
	_check(result.keys().size() == 2 and result.has("ok") and result.has("amount"),
		"result has precisely ok and amount keys")
	_check(typeof(result["amount"]) == TYPE_INT,
		"amount is an int")


func _test_band_matrix() -> void:
	# Independent fixed-literal oracle. These values are not derived from the helper.
	var expected: Dictionary = {
		5: {1: 5, 4: 5, 5: 6, 8: 6, 9: 7, 11: 7},
		6: {1: 6, 4: 6, 5: 7, 8: 7, 9: 9, 11: 9},
		7: {1: 7, 4: 7, 5: 8, 8: 8, 9: 10, 11: 10},
		8: {1: 8, 4: 8, 5: 10, 8: 10, 9: 12, 11: 12},
		9: {1: 9, 4: 9, 5: 11, 8: 11, 9: 13, 11: 13},
	}
	var floors: Array[int] = [1, 4, 5, 8, 9, 11]
	for base in range(5, 10):
		for floor in floors:
			var result := helper.scale_normal_attack(base, floor)
			var want: int = expected[base][floor]
			_check(result == {"ok": true, "amount": want},
				"base %d floor %d => %d" % [base, floor, want])


func _test_examples() -> void:
	_check(RunNormalAttackFloorScaling.scale_normal_attack(5, 1) == {"ok": true, "amount": 5}
		and RunNormalAttackFloorScaling.scale_normal_attack(5, 4) == {"ok": true, "amount": 5}
		and RunNormalAttackFloorScaling.scale_normal_attack(5, 5) == {"ok": true, "amount": 6}
		and RunNormalAttackFloorScaling.scale_normal_attack(5, 8) == {"ok": true, "amount": 6}
		and RunNormalAttackFloorScaling.scale_normal_attack(5, 9) == {"ok": true, "amount": 7}
		and RunNormalAttackFloorScaling.scale_normal_attack(5, 11) == {"ok": true, "amount": 7},
		"example base 5 rows")
	_check(RunNormalAttackFloorScaling.scale_normal_attack(7, 1) == {"ok": true, "amount": 7}
		and RunNormalAttackFloorScaling.scale_normal_attack(7, 4) == {"ok": true, "amount": 7}
		and RunNormalAttackFloorScaling.scale_normal_attack(7, 5) == {"ok": true, "amount": 8}
		and RunNormalAttackFloorScaling.scale_normal_attack(7, 8) == {"ok": true, "amount": 8}
		and RunNormalAttackFloorScaling.scale_normal_attack(7, 9) == {"ok": true, "amount": 10}
		and RunNormalAttackFloorScaling.scale_normal_attack(7, 11) == {"ok": true, "amount": 10},
		"example base 7 rows")
	_check(RunNormalAttackFloorScaling.scale_normal_attack(9, 1) == {"ok": true, "amount": 9}
		and RunNormalAttackFloorScaling.scale_normal_attack(9, 4) == {"ok": true, "amount": 9}
		and RunNormalAttackFloorScaling.scale_normal_attack(9, 5) == {"ok": true, "amount": 11}
		and RunNormalAttackFloorScaling.scale_normal_attack(9, 8) == {"ok": true, "amount": 11}
		and RunNormalAttackFloorScaling.scale_normal_attack(9, 9) == {"ok": true, "amount": 13}
		and RunNormalAttackFloorScaling.scale_normal_attack(9, 11) == {"ok": true, "amount": 13},
		"example base 9 rows")


func _test_rejections() -> void:
	var bad_bases: Array = [4, 10, -1, 0, 5.0, "5", null]
	for bad in bad_bases:
		var result := helper.scale_normal_attack(bad, 1)
		_check(result == {"ok": false, "amount": 0},
			"invalid base rejected: " + str(bad))

	var bad_floors: Array = [0, -1, 12, 13, 1.5, "5", null]
	for bad in bad_floors:
		var result := helper.scale_normal_attack(5, bad)
		_check(result == {"ok": false, "amount": 0},
			"invalid floor rejected: " + str(bad))

	# Subsequent correct call still works.
	_check(helper.scale_normal_attack(7, 6) == {"ok": true, "amount": 8},
		"valid call after rejections still succeeds")


func _test_no_mutation_and_rng() -> void:
	# Seeded RNG state must be untouched.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var state_before := rng.state
	var result := helper.scale_normal_attack(9, 11)
	_check(result == {"ok": true, "amount": 13}, "valid result for RNG guard")
	_check(rng.state == state_before, "seeded RNG state unchanged by helper")

	# Global RNG sequence must be unchanged by helper.
	seed(777)
	helper.scale_normal_attack(6, 5)
	var actual_first := randi()
	seed(777)
	var expected_first := randi()
	_check(actual_first == expected_first, "global RNG not consumed by helper")

	# Repeated identical calls are stable.
	var first := helper.scale_normal_attack(8, 9)
	var second := helper.scale_normal_attack(8, 9)
	_check(first == second and first == {"ok": true, "amount": 12},
		"repeated valid calls are deterministic")
