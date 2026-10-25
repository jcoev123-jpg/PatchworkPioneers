extends SceneTree
## Deterministic headless regression for RunV3FloorBandRoster (V3-2).
## The band pools below are synthetic fixtures, never proposed enemy IDs.

const BANDS := ["1-4", "5-8", "9-11"]
const FAILURE := {"ok": false, "band": "", "enemy_ids": []}

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_band_selection_matrix()
	_test_permuted_inputs_and_replay()
	_test_detached_results()
	_test_fail_closed()
	_test_current_combat_cap_untouched()
	if failures.is_empty():
		print("run_v3_floor_band_roster_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_v3_floor_band_roster_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(yes: bool, description: String) -> void:
	checks += 1
	if not yes:
		failures.append(description)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Synthetic three-band fixture: four or more distinct IDs per band, so later
## appended enemies (extra eligible IDs) are covered and no fixed total is
## assumed anywhere.
func _fixture(reordered: bool = false) -> Dictionary:
	if reordered:
		return {
			"9-11": ["high_f", "high_e", "high_d", "high_c", "high_b", "high_a"],
			"5-8": ["mid_d", "mid_c", "mid_b", "mid_a"],
			"1-4": ["low_e", "low_d", "low_c", "low_b", "low_a"],
		}
	return {
		"1-4": ["low_a", "low_b", "low_c", "low_d", "low_e"],
		"5-8": ["mid_a", "mid_b", "mid_c", "mid_d"],
		"9-11": ["high_a", "high_b", "high_c", "high_d", "high_e", "high_f"],
	}


## Independent oracle: duplicate and sort the band, then exactly `count`
## randi_range draws on a shrinking array.
func _oracle(pools: Dictionary, band: String, seed_value: int, count: int) -> Dictionary:
	var remaining: Array = pools[band].duplicate()
	remaining.sort()
	var rng := _rng(seed_value)
	var expected: Array = []
	for _draw in range(count):
		var index: int = rng.randi_range(0, remaining.size() - 1)
		expected.append(remaining[index])
		remaining.remove_at(index)
	return {"enemy_ids": expected, "rng": rng}


func _distinct(ids: Array) -> bool:
	var seen: Array = []
	for id in ids:
		if id in seen:
			return false
		seen.append(id)
	return true


func _sorted_keys(keys: Array) -> Array:
	var copy: Array = keys.duplicate()
	copy.sort()
	return copy


func _test_band_selection_matrix() -> void:
	# Non-vacuous precondition: the positive fixture really is three legal bands.
	var fixture := _fixture()
	for band in BANDS:
		var ids: Array = fixture[band]
		_check(ids.size() >= 4, band + ": fixture has at least four candidates")
		var clean := true
		var seen: Array = []
		for id in ids:
			if not id is String or id.is_empty() or id != id.strip_edges() or id in seen:
				clean = false
			seen.append(id)
		_check(clean, band + ": fixture IDs are distinct, nonempty and trimmed Strings")

	# Both boundaries of every band, every authored group size.
	var cases := [[1, "1-4"], [4, "1-4"], [5, "5-8"], [8, "5-8"], [9, "9-11"], [11, "9-11"]]
	for entry in cases:
		var floor_number: int = entry[0]
		var band: String = entry[1]
		for count_value in [2, 3, 4]:
			var count: int = count_value
			var seed_value := 7000 + floor_number * 10 + count
			var pools := _fixture()
			var before := pools.duplicate(true)
			var rng := _rng(seed_value)
			var answer := RunV3FloorBandRoster.new().pick(floor_number, count, rng, pools)
			var label := "floor %d count %d" % [floor_number, count]
			_check(answer.get("ok") == true, label + ": accepted")
			_check(_sorted_keys(answer.keys()) == ["band", "enemy_ids", "ok"],
				label + ": success shape has exactly ok/band/enemy_ids")
			_check(answer.get("band") == band, label + ": uses exactly the " + band + " band")
			var ids = answer.get("enemy_ids")
			_check(ids is Array, label + ": enemy_ids is an Array")
			if not ids is Array:
				continue
			_check(ids.size() == count, label + ": returns precisely the desired count")
			_check(_distinct(ids), label + ": no ID is selected twice")
			var in_band := true
			for id in ids:
				if not id is String or not pools[band].has(id):
					in_band = false
			_check(in_band, label + ": every ID comes from that band only")
			var oracle := _oracle(pools, band, seed_value, count)
			_check(ids == oracle["enemy_ids"],
				label + ": exact seeded draw order matches the independent oracle")
			_check(rng.state == oracle["rng"].state,
				label + ": exactly one randi_range draw per chosen member")
			_check(pools == before, label + ": caller pools are not mutated")


func _test_permuted_inputs_and_replay() -> void:
	for entry in [[1, "1-4"], [5, "5-8"], [9, "9-11"]]:
		var floor_number: int = entry[0]
		var band: String = entry[1]
		var seed_value := 991
		var first_rng := _rng(seed_value)
		var second_rng := _rng(seed_value)
		var third_rng := _rng(seed_value)
		var first := RunV3FloorBandRoster.new().pick(floor_number, 3, first_rng, _fixture())
		var second := RunV3FloorBandRoster.new().pick(floor_number, 3, second_rng, _fixture(true))
		var third := RunV3FloorBandRoster.new().pick(floor_number, 3, third_rng, _fixture())
		_check(first.get("ok") == true and first.get("band") == band,
			band + ": baseline pick succeeds")
		_check(first == second, band + ": reversed source-array order returns identical ordered IDs")
		_check(first_rng.state == second_rng.state,
			band + ": reversed source-array order leaves the same RNG state")
		_check(first == third and first_rng.state == third_rng.state,
			band + ": repeated same-seed run replays exactly")


func _test_detached_results() -> void:
	seed(424242)
	var expected_global := randi()
	seed(424242)
	var pools := _fixture()
	var rng := _rng(31337)
	var answer := RunV3FloorBandRoster.new().pick(9, 4, rng, pools)
	_check(randi() == expected_global, "sampler leaves the Godot global RNG undrawn")
	_check(answer.get("ok") == true, "detached-result fixture selection succeeds")
	if answer.get("ok") != true:
		return
	var expected := answer.duplicate(true)
	var spent_state := rng.state
	var returned: Array = answer["enemy_ids"]
	_check(returned.size() == 4, "detached-result fixture returns four future IDs")
	returned.clear()
	returned.append("invented_id")
	answer["band"] = "tampered"
	_check(pools == _fixture(),
		"mutating the returned group leaves the caller pools unchanged")
	var replay_rng := _rng(31337)
	var replay := RunV3FloorBandRoster.new().pick(9, 4, replay_rng, _fixture())
	_check(replay == expected,
		"mutating the returned group leaves later seeded picks identical")
	_check(replay_rng.state == spent_state,
		"later seeded pick still spends exactly the same draws")


## Data/shape rejection: a real seeded generator is supplied and must not move.
func _reject(label: String, floor_number: Variant, count: Variant, pools: Variant) -> void:
	var probe := _rng(555)
	var before_state := probe.state
	var answer := RunV3FloorBandRoster.new().pick(floor_number, count, probe, pools)
	_check(answer == FAILURE, label + ": rejected with the documented failure shape")
	_check(answer.keys().size() == 3 and answer.get("band") == "" and answer.get("enemy_ids") == [],
		label + ": failure has an empty band and empty enemy_ids")
	_check(probe.state == before_state, label + ": rejection consumed no RNG")


## Generator-type rejection: the same call with a real seeded generator works,
## so the wrong type is the only defect, and the run generator stays untouched.
func _reject_rng(label: String, rng: Variant) -> void:
	var probe := _rng(555)
	var before_state := probe.state
	var answer := RunV3FloorBandRoster.new().pick(1, 3, rng, _fixture())
	_check(answer == FAILURE, label + ": rejected with the documented failure shape")
	_check(probe.state == before_state, label + ": rejection consumed no RNG")
	if rng is RandomNumberGenerator:
		_check(rng.state == before_state, label + ": supplied seeded RNG state unchanged")
		return
	var control := RunV3FloorBandRoster.new().pick(1, 3, probe, _fixture())
	_check(control.get("ok") == true and control["enemy_ids"].size() == 3
		and probe.state != before_state,
		label + ": identical call with a real seeded generator succeeds and draws")


func _bad_fixture(band: String, value: Variant) -> Dictionary:
	var pools := _fixture()
	pools[band] = value
	return pools


func _test_fail_closed() -> void:
	# Floors: Boss floor 12 and every out-of-range value.
	_reject("floor 0", 0, 3, _fixture())
	_reject("floor -1", -1, 3, _fixture())
	_reject("floor -7", -7, 2, _fixture())
	_reject("floor 12 Boss", 12, 3, _fixture())
	_reject("floor 13", 13, 2, _fixture())
	_reject("non-int floor", "1", 3, _fixture())
	_reject("fractional floor", 1.5, 3, _fixture())
	# Group sizes outside the authored 2-4.
	_reject("count 1", 1, 1, _fixture())
	_reject("count 5", 1, 5, _fixture())
	_reject("count 0", 1, 0, _fixture())
	_reject("count -1", 1, -1, _fixture())
	_reject("non-int count", 1, "3", _fixture())
	_reject("fractional count", 1, 3.0, _fixture())
	# RNG type.
	_reject_rng("null RNG", null)
	_reject_rng("dictionary RNG", {})
	_reject_rng("string RNG", "rng")
	_reject_rng("RefCounted RNG", RefCounted.new())
	# Pool shape.
	_reject("null pool", 1, 3, null)
	_reject("array pool", 1, 3, [_fixture()])
	_reject("empty pool", 1, 3, {})
	_reject("string pool", 1, 3, "1-4")
	var missing_low := _fixture()
	missing_low.erase("1-4")
	_reject("missing 1-4 band", 1, 3, missing_low)
	var missing_low_on_mid_floor := _fixture()
	missing_low_on_mid_floor.erase("1-4")
	_reject("missing unused 1-4 band", 5, 3, missing_low_on_mid_floor)
	var missing_high := _fixture()
	missing_high.erase("9-11")
	_reject("missing 9-11 band", 11, 2, missing_high)
	# Malformed bands, including a bad band the current floor does not use.
	_reject("band not an array", 1, 3, _bad_fixture("9-11", "high_a,high_b"))
	_reject("bad UNUSED band rejects first", 1, 3,
		_bad_fixture("9-11", ["high_a", "high_a", "high_b", "high_c"]))
	_reject("band null", 5, 3, _bad_fixture("1-4", null))
	_reject("fewer than four (requested band)", 5, 2,
		_bad_fixture("5-8", ["mid_a", "mid_b", "mid_c"]))
	_reject("fewer than four (unused band)", 5, 2,
		_bad_fixture("9-11", ["high_a", "high_b"]))
	_reject("empty band", 1, 2, _bad_fixture("1-4", []))
	_reject("duplicate within requested band", 1, 2,
		_bad_fixture("1-4", ["low_a", "low_a", "low_b", "low_c"]))
	_reject("blank ID", 1, 2, _bad_fixture("1-4", ["low_a", "low_b", "low_c", ""]))
	_reject("whitespace-only ID", 9, 2,
		_bad_fixture("9-11", ["   ", "high_b", "high_c", "high_d"]))
	_reject("whitespace-padded ID", 9, 2,
		_bad_fixture("9-11", [" high_a", "high_b", "high_c", "high_d"]))
	_reject("trailing-space ID", 9, 2,
		_bad_fixture("9-11", ["high_a ", "high_b", "high_c", "high_d"]))
	_reject("non-string ID", 1, 2, _bad_fixture("1-4", ["low_a", "low_b", "low_c", 7]))
	_reject("null ID", 5, 2, _bad_fixture("5-8", ["mid_a", "mid_b", "mid_c", null]))

	# The same generator still serves a valid call afterwards: every rejection
	# above spent nothing.
	var rng := _rng(555)
	var oracle := _oracle(_fixture(), "1-4", 555, 2)
	var answer := RunV3FloorBandRoster.new().pick(1, 2, rng, _fixture())
	_check(answer.get("ok") == true and answer["enemy_ids"] == oracle["enemy_ids"]
		and rng.state == oracle["rng"].state,
		"valid call after every rejection selects and spends exactly as a fresh generator")


func _test_current_combat_cap_untouched() -> void:
	_check(CombatEnemies.MAX_ENEMIES == 3,
		"current live combat still admits at most three actors")
	var rng := _rng(2468)
	var answer := RunV3FloorBandRoster.new().pick(1, 4, rng, _fixture())
	_check(answer.get("ok") == true and answer["enemy_ids"].size() == 4,
		"four IDs are selectable as future data")
	if answer.get("ok") != true:
		return
	var definitions: Array = []
	for id in answer["enemy_ids"]:
		definitions.append({"id": id, "max_hp": 10})
	var four := CombatEnemies.new(definitions)
	_check(not four.is_valid() and four.get_enemies().is_empty(),
		"a four-ID group is not admitted by current three-actor combat")
	var three := CombatEnemies.new(definitions.slice(0, 3))
	_check(three.is_valid() and three.get_enemies().size() == 3,
		"the same IDs in a three-actor group remain a valid current roster")
