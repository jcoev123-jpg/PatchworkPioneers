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
	_test_preview_authored_and_caps()
	_test_preview_determinism_and_isolation()
	_test_preview_rejections()
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

## Compare the complete preview to an independent authoritative Rest visit,
## rather than duplicating recovery arithmetic in the test.
func _assert_preview_matches_service(snapshot: Array, expected_hps: Array, label: String) -> Dictionary:
	var before: Array = snapshot.duplicate(true)
	var oracle := RunRestRecovery.new(snapshot)
	_check(not oracle.is_consumed(), label + ": oracle starts unconsumed")
	var committed: Dictionary = oracle.choose_heal()
	_check(committed.get("ok") == true, label + ": recovery oracle accepts the roster")
	if committed.get("ok") != true:
		return {}
	var predicted: Dictionary = RunRestHealPreview.preview(snapshot)
	_check(predicted.get("ok") == true, label + ": preview accepted")
	_check(predicted.get("heroes") == committed["heroes"], label + ": entire forecast roster equals the authoritative service")
	_check(snapshot == before, label + ": caller snapshot unchanged")
	_check(oracle.is_consumed(), label + ": only the oracle's own visit was consumed")
	if typeof(predicted.get("heroes")) != TYPE_ARRAY or typeof(predicted.get("forecasts")) != TYPE_ARRAY:
		_check(false, label + ": both return collections are arrays")
		return predicted
	var heroes: Array = predicted["heroes"]
	var forecasts: Array = predicted["forecasts"]
	_check(heroes.size() == 3 and forecasts.size() == 3, label + ": three heroes and three forecasts")
	if heroes.size() != 3 or forecasts.size() != 3:
		return predicted
	for i in range(3):
		var expected_actor: Dictionary = before[i].duplicate(true)
		expected_actor["hp"] = expected_hps[i]
		_check(heroes[i] == expected_actor, label + ": actor %d preserves all non-HP fields" % i)
		_check(int(heroes[i]["hp"]) <= int(heroes[i]["max_hp"]), label + ": actor %d never exceeds current max" % i)
		var expected_record := {
			"id": before[i]["id"],
			"hp_before": int(before[i]["hp"]),
			"hp_after": int(committed["heroes"][i]["hp"]),
			"hp_delta": int(committed["heroes"][i]["hp"]) - int(before[i]["hp"]),
			"revived": int(before[i]["hp"]) == 0,
		}
		_check(forecasts[i] == expected_record, label + ": full per-hero record %d" % i)
		_check(int(heroes[i]["hp"]) == int(expected_hps[i]), label + ": expected HP %d" % i)
	return predicted


func _test_preview_authored_and_caps() -> void:
	var authored := _party([35, 18, 0])
	var forecast := _assert_preview_matches_service(authored, [40, 27, 8], "preview starter maxima 35/18/0")
	if forecast.get("ok") == true:
		_check(forecast["forecasts"].map(func(f): return f["hp_delta"]) == [5, 9, 8],
			"capped Warden +5, Seamstress +9, revived Tinker +8")
		_check(forecast["forecasts"].map(func(f): return f["revived"]) == [false, false, true],
			"only Tinker is marked revived")
	_assert_preview_matches_service(_party([0, 0, 1]), [13, 10, 8], "preview two downed")
	_assert_preview_matches_service(_party([1, 1, 1]), [13, 10, 8], "preview uncapped 12/9/7 healing")
	_assert_preview_matches_service(_party([40, 30, 26]), [40, 30, 26], "preview full HP capped")
	_assert_preview_matches_service(_party([39, 29, 25]), [40, 30, 26], "preview near-full capped")
	var lower := _party([0, 15, 2])
	lower[0]["max_hp"] = 9
	lower[1]["max_hp"] = 23
	lower[2]["max_hp"] = 17
	_assert_preview_matches_service(lower, [3, 21, 7], "preview current lowered maxima and floor")
	var max_one := _party([0, 1, 1])
	max_one[0]["max_hp"] = 1
	max_one[1]["max_hp"] = 1
	max_one[2]["max_hp"] = 1
	_assert_preview_matches_service(max_one, [1, 1, 1], "preview minimum valid max HP")


func _test_preview_determinism_and_isolation() -> void:
	var snapshot := _party([35, 18, 0])
	var original: Array = snapshot.duplicate(true)
	var real_visit := RunRestRecovery.new(snapshot)
	_check(not real_visit.is_consumed(), "real Rest visit starts open before any previews")
	# Exercise the SAME global RNG stream used by accidental randi() calls.
	seed(74213)
	var expected_random := randi()
	seed(74213)
	var first := _assert_preview_matches_service(snapshot, [40, 27, 8], "first preview")
	var second := RunRestHealPreview.preview(snapshot)
	_check(first == second, "two identical previews replay exactly")
	_check(snapshot == original, "replayed preview does not modify input")
	_check(randi() == expected_random, "preview and independent Rest oracle do not draw global RNG")
	if first.get("ok") != true or second.get("ok") != true:
		return
	_check(not real_visit.is_consumed(), "real Rest visit remains open after previews")
	var real_result := real_visit.choose_heal()
	_check(real_result.get("ok") == true and real_result.get("heroes") == first["heroes"],
		"real visit independently heals to the exact preview")
	_check(real_visit.is_consumed(), "real visit latches after its own successful heal")
	_check(real_visit.choose_heal() == {"ok": false, "heroes": []},
		"real visit refuses a second HEAL after its own claim")
	_check(snapshot == original, "preview and real visit left original party unchanged")

	# Mutate both nested returned data and forecast scalar records: neither
	# another result nor the original caller may follow these changes.
	first["heroes"][0]["statuses"]["bleed"]["stacks"] = 999
	first["heroes"][1]["metadata"]["tags"][0]["label"] = "changed"
	first["heroes"][2]["metadata"]["colours"][1]["accent"] = "red"
	first["heroes"][2]["hp"] = -100
	first["forecasts"][0]["hp_after"] = -100
	first["forecasts"][1]["id"] = "invalid"
	_check(snapshot == original, "mutating preview return never changes caller's nested data")
	_check(second == RunRestHealPreview.preview(original), "another returned preview remains independent")
	_check(second["heroes"][0]["statuses"]["bleed"]["stacks"] == 1,
		"another result's nested statuses are detached")
	_check(second["forecasts"][0]["hp_after"] == 40 and second["forecasts"][1]["id"] == "seamstress",
		"another result's forecast records are detached")

	var held := RunRestHealPreview.preview(snapshot)
	snapshot[0]["statuses"]["bleed"]["stacks"] = -999
	snapshot[1]["metadata"]["tags"][0]["label"] = "caller-mutated"
	snapshot[2]["hp"] = 26
	_check(held == second, "preview retains its own roster and forecasts after caller mutates")
	_check(real_result["heroes"] == second["heroes"], "real committed result remains detached")


func _test_preview_rejections() -> void:
	var bad_position := _party([35, 18, 0])
	bad_position[1]["position"] = 3
	var impossible_hp := _party([35, 18, 0])
	impossible_hp[1]["hp"] = 31
	var fractional_hp := _party([35, 18, 0])
	fractional_hp[1]["hp"] = 1.5
	var missing_id := _party([35, 18, 0])
	missing_id[1].erase("id")
	var duplicate_id := _party([35, 18, 0])
	duplicate_id[1]["id"] = "warden"
	var non_dict := _party([35, 18, 0])
	non_dict[1] = null
	var all_refusals: Array = [
		null, "not a roster", [], _party([0, 0, 0]),
		_party([35, 18, 0]).slice(0, 2),
		bad_position, impossible_hp, fractional_hp, missing_id, duplicate_id, non_dict,
	]
	for i in range(all_refusals.size()):
		var candidate: Variant = all_refusals[i]
		var saved: Variant = candidate.duplicate(true) if typeof(candidate) == TYPE_ARRAY or typeof(candidate) == TYPE_DICTIONARY else candidate
		_check(RunRestRecovery.new(candidate).choose_heal().get("ok") == false,
			"rejection %d is refused by the underlying service" % i)
		for attempt in range(2):
			var prediction: Dictionary = RunRestHealPreview.preview(candidate)
			_check(prediction == {"ok": false, "heroes": [], "forecasts": []},
				"rejection %d attempt %d gives no partial promises" % [i, attempt])
		_check(candidate == saved, "rejection %d keeps complete invalid input unchanged" % i)
