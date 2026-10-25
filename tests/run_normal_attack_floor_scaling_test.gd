extends SceneTree

const HELPER_SCRIPT := preload("res://scripts/run_normal_attack_floor_scaling.gd")

var failures: Array[String] = []
var checks := 0
var helper := HELPER_SCRIPT.new()


func _initialize() -> void:
	_test_contract()
	_test_band_matrix()
	_test_examples()
	_test_rejections()
	_test_hp_contract()
	_test_hp_band_matrix()
	_test_hp_rejections()
	_test_combined_quotes()
	_test_combined_rejections()
	_test_no_mutation_and_rng()
	_test_hp_no_mutation_and_rng()
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
	_check(HELPER_SCRIPT.scale_normal_attack(5, 1) == {"ok": true, "amount": 5}
		and HELPER_SCRIPT.scale_normal_attack(5, 4) == {"ok": true, "amount": 5}
		and HELPER_SCRIPT.scale_normal_attack(5, 5) == {"ok": true, "amount": 6}
		and HELPER_SCRIPT.scale_normal_attack(5, 8) == {"ok": true, "amount": 6}
		and HELPER_SCRIPT.scale_normal_attack(5, 9) == {"ok": true, "amount": 7}
		and HELPER_SCRIPT.scale_normal_attack(5, 11) == {"ok": true, "amount": 7},
		"example base 5 rows")
	_check(HELPER_SCRIPT.scale_normal_attack(7, 1) == {"ok": true, "amount": 7}
		and HELPER_SCRIPT.scale_normal_attack(7, 4) == {"ok": true, "amount": 7}
		and HELPER_SCRIPT.scale_normal_attack(7, 5) == {"ok": true, "amount": 8}
		and HELPER_SCRIPT.scale_normal_attack(7, 8) == {"ok": true, "amount": 8}
		and HELPER_SCRIPT.scale_normal_attack(7, 9) == {"ok": true, "amount": 10}
		and HELPER_SCRIPT.scale_normal_attack(7, 11) == {"ok": true, "amount": 10},
		"example base 7 rows")
	_check(HELPER_SCRIPT.scale_normal_attack(9, 1) == {"ok": true, "amount": 9}
		and HELPER_SCRIPT.scale_normal_attack(9, 4) == {"ok": true, "amount": 9}
		and HELPER_SCRIPT.scale_normal_attack(9, 5) == {"ok": true, "amount": 11}
		and HELPER_SCRIPT.scale_normal_attack(9, 8) == {"ok": true, "amount": 11}
		and HELPER_SCRIPT.scale_normal_attack(9, 9) == {"ok": true, "amount": 13}
		and HELPER_SCRIPT.scale_normal_attack(9, 11) == {"ok": true, "amount": 13},
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


func _test_hp_contract() -> void:
	_check(helper.has_method("scale_normal_max_hp"),
		"public scale_normal_max_hp method exists")
	_check(helper.has_method("scale_normal_stats"),
		"public scale_normal_stats method exists")

	var result := helper.scale_normal_max_hp(13, 1)
	_check(result == {"ok": true, "max_hp": 13},
		"valid HP call returns ok/max_hp dictionary")
	_check(result.keys().size() == 2 and result.has("ok") and result.has("max_hp"),
		"HP result has precisely ok and max_hp keys")
	_check(typeof(result["max_hp"]) == TYPE_INT,
		"max_hp is an int")

	var combined := helper.scale_normal_stats(14, 5, 4)
	_check(combined.keys().size() == 3 and combined.has("ok")
		and combined.has("max_hp") and combined.has("attack"),
		"stat quote has precisely ok, max_hp and attack keys")
	_check(typeof(combined["max_hp"]) == TYPE_INT and typeof(combined["attack"]) == TYPE_INT,
		"stat quote values are ints")


func _test_hp_band_matrix() -> void:
	# Independent fixed-literal oracle, not derived from the helper.
	var expected: Dictionary = {
		13: {1: 13, 4: 13, 5: 16, 8: 16, 9: 19, 11: 19},
		14: {1: 14, 4: 14, 5: 17, 8: 17, 9: 21, 11: 21},
		18: {1: 18, 4: 18, 5: 22, 8: 22, 9: 27, 11: 27},
	}
	var floors: Array[int] = [1, 4, 5, 8, 9, 11]
	for base in [13, 14, 18]:
		for floor in floors:
			var result := helper.scale_normal_max_hp(base, floor)
			var want: int = expected[base][floor]
			_check(result == {"ok": true, "max_hp": want},
				"hp %d floor %d => %d" % [base, floor, want])

	# Band-boundary x1.0 / x1.25 / x1.5 rows for the minimum HP.
	_check(helper.scale_normal_max_hp(1, 4) == {"ok": true, "max_hp": 1}
		and helper.scale_normal_max_hp(1, 8) == {"ok": true, "max_hp": 1}
		and helper.scale_normal_max_hp(1, 11) == {"ok": true, "max_hp": 1},
		"minimum HP 1 stays positive in every band")
	_check(helper.scale_normal_max_hp(15, 1) == {"ok": true, "max_hp": 15}
		and helper.scale_normal_max_hp(15, 5) == {"ok": true, "max_hp": 18}
		and helper.scale_normal_max_hp(15, 9) == {"ok": true, "max_hp": 22},
		"HP 15 truncated at x1.25 and x1.5")


func _test_hp_rejections() -> void:
	var bad_hps: Array = [0, -1, -13, 13.0, "13", null]
	for bad in bad_hps:
		_check(helper.scale_normal_max_hp(bad, 1) == {"ok": false, "max_hp": 0},
			"invalid HP rejected: " + str(bad))

	var bad_floors: Array = [0, 12, -1, 5.0, "5", null]
	for bad in bad_floors:
		_check(helper.scale_normal_max_hp(14, bad) == {"ok": false, "max_hp": 0},
			"invalid HP floor rejected: " + str(bad))

	_check(helper.scale_normal_max_hp(14, 6) == {"ok": true, "max_hp": 17},
		"valid HP call after rejections still succeeds")


func _test_combined_quotes() -> void:
	_check(helper.scale_normal_stats(14, 5, 4) == {"ok": true, "max_hp": 14, "attack": 5},
		"combined floor 4: HP 14 / attack 5")
	_check(helper.scale_normal_stats(17, 7, 5) == {"ok": true, "max_hp": 21, "attack": 8},
		"combined floor 5: HP 17 / attack 7")
	_check(helper.scale_normal_stats(18, 9, 9) == {"ok": true, "max_hp": 27, "attack": 13},
		"combined floor 9: HP 18 / attack 9")

	# Same-input repeated calls are equal and detached snapshots.
	var first := helper.scale_normal_stats(17, 7, 5)
	var second := helper.scale_normal_stats(17, 7, 5)
	_check(first == second and first == {"ok": true, "max_hp": 21, "attack": 8},
		"repeated combined quotes are deterministic")
	first["max_hp"] = 999
	first["attack"] = 999
	var third := helper.scale_normal_stats(17, 7, 5)
	_check(third == {"ok": true, "max_hp": 21, "attack": 8},
		"combined quote snapshots are detached from later calls")

	# The old attack-only contract is untouched by composition.
	_check(helper.scale_normal_attack(9, 11) == {"ok": true, "amount": 13},
		"attack-only contract unchanged after combined quote")


func _test_combined_rejections() -> void:
	var bad_pairs: Array = [
		[0, 5, 5], [-1, 5, 5], [14.0, 5, 5], ["14", 5, 5], [null, 5, 5],
		[14, 4, 5], [14, 10, 5], [14, -1, 5], [14, 5.0, 5], [14, "5", 5], [14, null, 5],
		[14, 5, 0], [14, 5, 12], [14, 5, -1], [14, 5, 5.0], [14, 5, "5"], [14, 5, null],
	]
	for pair in bad_pairs:
		var result := helper.scale_normal_stats(pair[0], pair[1], pair[2])
		_check(result == {"ok": false, "max_hp": 0, "attack": 0},
			"combined quote fails closed with no partial values: " + str(pair))

	# Bad HP must not leak a scaled attack and vice versa.
	_check(helper.scale_normal_stats(0, 9, 9) == {"ok": false, "max_hp": 0, "attack": 0},
		"invalid HP leaves no partially scaled attack")
	_check(helper.scale_normal_stats(18, 10, 9) == {"ok": false, "max_hp": 0, "attack": 0},
		"invalid attack leaves no partially scaled HP")

	_check(helper.scale_normal_stats(18, 9, 9) == {"ok": true, "max_hp": 27, "attack": 13},
		"valid combined call after rejections still succeeds")


func _test_hp_no_mutation_and_rng() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var state_before := rng.state
	_check(helper.scale_normal_max_hp(18, 9) == {"ok": true, "max_hp": 27},
		"valid HP result for RNG guard")
	_check(rng.state == state_before, "seeded RNG state unchanged by HP helper")

	seed(777)
	helper.scale_normal_max_hp(14, 5)
	var hp_actual := randi()
	seed(777)
	var hp_expected := randi()
	_check(hp_actual == hp_expected, "global RNG not consumed by HP helper")

	seed(778)
	helper.scale_normal_stats(17, 7, 5)
	var combined_actual := randi()
	seed(778)
	var combined_expected := randi()
	_check(combined_actual == combined_expected, "global RNG not consumed by combined quote")

	# Rejections must not consume RNG either.
	var rejection_state := rng.state
	seed(779)
	helper.scale_normal_max_hp(0, 12)
	helper.scale_normal_stats(null, "x", 99)
	var after_rejection := randi()
	seed(779)
	var rejection_expected := randi()
	_check(after_rejection == rejection_expected,
		"global RNG not consumed by rejected HP/quote calls")
	_check(rng.state == rejection_state, "seeded RNG state unchanged after rejections")


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
