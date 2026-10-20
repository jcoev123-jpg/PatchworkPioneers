extends SceneTree

var failures: Array[String] = []
var checks := 0
var starter: Array = []


func _initialize() -> void:
	starter = _load_starter()
	_check(starter.size() == 3, "authored starter party has three heroes")
	if starter.size() != 3:
		_finish()
		return
	for i in range(3):
		_check(starter[i] is Dictionary, "starter actor %d is a dictionary" % i)
		if not starter[i] is Dictionary:
			_finish()
			return
	_check(starter[0].get("id") == "warden" and int(starter[0].get("max_hp", -1)) == 40,
		"authored Warden id and max HP")
	_check(starter[1].get("id") == "seamstress" and int(starter[1].get("max_hp", -1)) == 30,
		"authored Seamstress id and max HP")
	_check(starter[2].get("id") == "tinker" and int(starter[2].get("max_hp", -1)) == 26,
		"authored Tinker id and max HP")
	_test_public_contract()
	_test_authored_recovery()
	_test_caps_and_revive()
	_test_duplicate_and_later_visit()
	_test_replay_and_rng()
	_test_snapshot_and_result_isolation()
	_test_invalid_and_defeated()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("run_rest_recovery_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_rest_recovery_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_starter() -> Array:
	var raw := FileAccess.get_file_as_string("res://data/heroes/starter_party.json")
	_check(not raw.is_empty(), "read actual authored starter party JSON")
	if raw.is_empty():
		return []
	var parsed: Variant = JSON.parse_string(raw)
	_check(typeof(parsed) == TYPE_ARRAY, "starter party parses as JSON array")
	if typeof(parsed) != TYPE_ARRAY:
		return []
	return parsed


func _party(hps: Array) -> Array:
	var party: Array = []
	for i in range(starter.size()):
		var hero: Dictionary = starter[i].duplicate(true)
		hero["position"] = i + 1
		hero["hp"] = hps[i]
		hero["block"] = 10 + i
		hero["statuses"] = {"bleed": {"stacks": i + 1}, "weak": [i, "thread"]}
		hero["metadata"] = {
			"tags": [{"label": "hero_%d" % i}],
			"colours": ["felt", {"accent": "blue"}],
		}
		party.append(hero)
	return party


func _assert_success(result: Dictionary, before: Array, expected_hps: Array, context: String) -> void:
	_check(result.get("ok") == true, context + ": success flag")
	_check(result.has("heroes") and typeof(result["heroes"]) == TYPE_ARRAY, context + ": roster array returned")
	if typeof(result.get("heroes")) != TYPE_ARRAY:
		return
	var after: Array = result["heroes"]
	_check(after.size() == 3, context + ": exactly three heroes returned")
	if after.size() != 3:
		return
	for i in range(3):
		_check(typeof(after[i]) == TYPE_DICTIONARY, context + ": actor %d remains a dictionary" % i)
		if typeof(after[i]) != TYPE_DICTIONARY:
			continue
		var expected: Dictionary = before[i].duplicate(true)
		expected["hp"] = expected_hps[i]
		_check(after[i] == expected, context + ": actor %d matches every field except intended HP" % i)
		_check(after[i].get("position") == i + 1, context + ": position %d retained" % (i + 1))


func _test_public_contract() -> void:
	var visit := RunRestRecovery.new()
	_check(visit.has_method("choose_heal"), "public choose_heal method")
	_check(visit.has_method("is_consumed"), "public read-only consumption query")
	_check(not visit.is_consumed(), "unbound visit initially unconsumed")
	var refused := visit.choose_heal()
	_check(refused.get("ok") == false, "unbound visit refuses healing")
	_check(refused.get("heroes") == [], "unbound visit gives no recovered actors")
	_check(not visit.is_consumed(), "unbound failed call does not consume")


func _test_authored_recovery() -> void:
	var party := _party([35, 18, 0])
	var untouched := party.duplicate(true)
	var visit := RunRestRecovery.new(party)
	_check(not visit.is_consumed(), "valid visit starts unconsumed")
	_assert_success(visit.choose_heal(), party, [40, 27, 8], "authored 35/18/0 -> 40/27/8")
	_check(visit.is_consumed(), "success marks visit consumed")
	_check(party == untouched, "caller input unchanged after recovery")


func _test_caps_and_revive() -> void:
	var full := _party([40, 30, 26])
	_assert_success(RunRestRecovery.new(full).choose_heal(), full, [40, 30, 26], "full HP caps")
	var near_cap := _party([39, 29, 25])
	_assert_success(RunRestRecovery.new(near_cap).choose_heal(), near_cap, [40, 30, 26], "near cap")
	var two_downed := _party([0, 0, 1])
	_assert_success(RunRestRecovery.new(two_downed).choose_heal(), two_downed, [13, 10, 8], "two downed revive first")


func _test_duplicate_and_later_visit() -> void:
	var start := _party([35, 18, 0])
	var first := RunRestRecovery.new(start)
	var first_result := first.choose_heal()
	_assert_success(first_result, start, [40, 27, 8], "first visit")
	var repeated := first.choose_heal()
	_check(repeated.get("ok") == false, "same visit refuses second claim")
	_check(repeated.get("heroes") == [], "double claim returns no second roster")
	_check(first.is_consumed(), "rejected double claim retains consumed state")
	_check(start[2]["hp"] == 0, "original downed actor still at zero")
	var next_roster: Array = first_result["heroes"]
	var second := RunRestRecovery.new(next_roster)
	_assert_success(second.choose_heal(), next_roster, [40, 30, 15], "new Rest site heals again")
	_check(second.is_consumed(), "second site independently consumed")
	_check(next_roster[2]["hp"] == 8, "second Rest does not mutate first result")


func _test_replay_and_rng() -> void:
	var input := _party([35, 18, 0])
	var first := RunRestRecovery.new(input)
	var second := RunRestRecovery.new(input.duplicate(true))
	var first_result := first.choose_heal()
	var second_result := second.choose_heal()
	_check(first_result == second_result, "identical independent snapshots replay identically")
	# Verify the very same global RNG stream remains untouched.
	seed(481516)
	var expected_random := randi()
	seed(481516)
	var replay := RunRestRecovery.new(input)
	_assert_success(replay.choose_heal(), input, [40, 27, 8], "seed-independent replay")
	_check(randi() == expected_random, "construction and healing consume no global RNG")


func _test_snapshot_and_result_isolation() -> void:
	var caller := _party([35, 18, 0])
	var original := caller.duplicate(true)
	var visit := RunRestRecovery.new(caller)
	# Changes made after binding cannot alter the privately snapshotted visit.
	caller[0]["statuses"]["bleed"]["stacks"] = 999
	caller[1]["metadata"]["tags"][0]["label"] = "tampered"
	caller[2]["metadata"]["colours"][1]["accent"] = "red"
	caller[2]["hp"] = 26
	var result := visit.choose_heal()
	_assert_success(result, original, [40, 27, 8], "bound snapshot deep isolation")
	var recovered: Array = result["heroes"]
	_check(recovered[0]["statuses"]["bleed"]["stacks"] == 1, "nested status isolated from caller")
	_check(recovered[1]["metadata"]["tags"][0]["label"] == "hero_1", "nested tag isolated from caller")
	_check(recovered[2]["metadata"]["colours"][1]["accent"] == "blue", "nested colour isolated from caller")

	var pristine := _party([35, 18, 0])
	var other_result := RunRestRecovery.new(pristine).choose_heal()
	recovered[0]["statuses"]["bleed"]["stacks"] = -9
	recovered[1]["metadata"]["tags"][0]["label"] = "changed-return"
	recovered[2]["metadata"]["colours"][1]["accent"] = "green"
	recovered[0]["hp"] = 1
	_check(pristine == original, "mutating result has no aliases into original input")
	_assert_success(other_result, original, [40, 27, 8], "independent visit result unaffected")
	_check(other_result["heroes"][0]["statuses"]["bleed"]["stacks"] == 1, "nested returned status independent")
	_check(other_result["heroes"][1]["metadata"]["tags"][0]["label"] == "hero_1", "nested returned tag independent")
	_check(other_result["heroes"][2]["metadata"]["colours"][1]["accent"] == "blue", "nested returned colour independent")


func _assert_refusal(snapshot: Variant, context: String) -> void:
	var copied: Variant = snapshot.duplicate(true) if typeof(snapshot) == TYPE_ARRAY else snapshot
	var visit := RunRestRecovery.new(snapshot)
	_check(not visit.is_consumed(), context + ": starts open")
	for attempt in range(2):
		var result := visit.choose_heal()
		_check(result.has("ok") and result["ok"] == false, context + ": refused attempt %d" % attempt)
		_check(result.has("heroes") and result["heroes"] == [], context + ": no actors leaked")
		_check(not visit.is_consumed(), context + ": refusal does not consume")
	_check(snapshot == copied, context + ": failed transaction leaves input untouched")


func _test_invalid_and_defeated() -> void:
	_assert_refusal(null, "unbound visit")
	_assert_refusal("not a roster", "wrong input type")
	_assert_refusal([], "empty party")
	_assert_refusal(_party([35, 18, 0]).slice(0, 2), "missing hero")
	var too_many := _party([35, 18, 0])
	too_many.append(too_many[0].duplicate(true))
	_assert_refusal(too_many, "extra hero")
	var malformed := _party([35, 18, 0])
	malformed[1] = null
	_assert_refusal(malformed, "non-dictionary hero")

	var invalids: Array = [
		["position", 0], ["position", 3], ["position", 1.5],
		["position", "2"], ["hp", -1], ["hp", 31], ["hp", 1.5],
		["hp", "18"], ["max_hp", 0], ["max_hp", -1], ["max_hp", 30.5],
		["max_hp", "30"], ["id", ""], ["id", "warden"], ["id", 42],
	]
	for probe in invalids:
		var bad := _party([35, 18, 0])
		bad[1][probe[0]] = probe[1]
		_assert_refusal(bad, "invalid %s=%s" % [probe[0], str(probe[1])])
	for missing in ["position", "hp", "max_hp", "id"]:
		var absent := _party([35, 18, 0])
		absent[1].erase(missing)
		_assert_refusal(absent, "missing " + missing)

	var downed := _party([0, 0, 0])
	_assert_refusal(downed, "defeated all-downed run")
	var stale := _party([35, 18, 0])
	stale[1]["hp"] = -1
	var stale_visit := RunRestRecovery.new(stale)
	stale[1]["hp"] = 18
	_check(not stale_visit.choose_heal().get("ok"), "invalid bound visit cannot be repaired by mutating caller")
	_check(not stale_visit.is_consumed(), "invalid snapshot stays unconsumed")
