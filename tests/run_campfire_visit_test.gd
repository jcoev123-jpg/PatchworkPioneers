extends SceneTree

var failures: Array[String] = []
var checks: int = 0
var starter: Array = []


func _initialize() -> void:
	var source := FileAccess.get_file_as_string("res://data/heroes/starter_party.json")
	var parsed: Variant = JSON.parse_string(source)
	_check(not source.is_empty() and typeof(parsed) == TYPE_ARRAY,
		"loads actual authored starter party")
	if typeof(parsed) != TYPE_ARRAY:
		_finish()
		return
	starter = parsed
	_check(starter.size() == 3, "authored party has exactly three slots")
	if starter.size() != 3:
		_finish()
		return
	_check(starter[0].get("id") == "warden" and starter[0].get("max_hp") == 40
		and starter[1].get("id") == "seamstress" and starter[1].get("max_hp") == 30
		and starter[2].get("id") == "tinker" and starter[2].get("max_hp") == 26,
		"real starter hero identities and maxima")
	_test_heals()
	_test_snapshot_isolation_and_stale_guard()
	_test_leave()
	_test_invalid_construction()
	_test_replay_and_rng()
	_finish()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("run_campfire_visit_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_campfire_visit_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _party(hps: Array) -> Array:
	var party: Array = []
	for i in range(3):
		var hero: Dictionary = starter[i].duplicate(true)
		hero["position"] = i + 1
		hero["hp"] = hps[i]
		hero["block"] = 3 + i
		hero["statuses"] = {"bleed": {"stacks": i + 1}, "weak": [i, "felt"]}
		hero["metadata"] = {
			"patches": [{"stitch": "hero_%d" % i}],
			"palette": ["wool", {"trim": "green"}],
		}
		party.append(hero)
	return party


func _assert_refused(visit: RunCampfireVisit, node: Variant, heroes: Variant,
		heal: bool, label: String) -> void:
	var before := visit.read_state()
	var result: Dictionary = visit.choose_heal(node, heroes) if heal else visit.leave(node, heroes)
	_check(result == {"ok": false, "decision": "", "node_id": "", "heroes": []},
		label + ": uniformly typed refusal, no forged receipt")
	_check(visit.read_state() == before, label + ": failure does not consume or modify visit")


func _assert_heal(before: Array, expected_hps: Array, label: String) -> void:
	var original := before.duplicate(true)
	var oracle := RunRestRecovery.new(before)
	var expected: Dictionary = oracle.choose_heal()
	_check(expected.get("ok") == true and oracle.is_consumed(), label + ": independent Rest oracle valid")
	if expected.get("ok") != true:
		return
	var visit := RunCampfireVisit.new("camp_" + label, before)
	var open := visit.read_state()
	_check(open == {"ok": true, "node_id": "camp_" + label,
		"status": "open", "heroes": original}, label + ": visit opens with full detached snapshot")
	var receipt := visit.choose_heal("camp_" + label, original)
	_check(receipt.get("ok") == true and receipt.get("decision") == "heal"
		and receipt.get("node_id") == "camp_" + label,
		label + ": HEAL receipt names node and committed decision")
	_check(receipt.get("heroes") == expected["heroes"],
		label + ": exact full recovered roster agrees with new Rest authority")
	_check(visit.read_state() == {"ok": true, "node_id": "camp_" + label,
		"status": "healed", "heroes": expected["heroes"]},
		label + ": committed visit holds healed snapshot, not rest claim")
	if typeof(receipt.get("heroes")) == TYPE_ARRAY and receipt["heroes"].size() == 3:
		for i in range(3):
			var unchanged: Dictionary = original[i].duplicate(true)
			unchanged["hp"] = expected_hps[i]
			_check(receipt["heroes"][i] == unchanged,
				label + ": slot %d changes only HP, retaining max/Block/status/metadata" % (i + 1))
	_check(before == original, label + ": source records unchanged")
	_assert_refused(visit, "camp_" + label, expected["heroes"], true, label + ": duplicate Heal")
	_assert_refused(visit, "camp_" + label, original, false, label + ": Leave after Heal")


func _test_heals() -> void:
	_assert_heal(_party([35, 18, 0]), [40, 27, 8], "starter")
	var reduced := _party([0, 26, 20])
	reduced[0]["max_hp"] = 37
	reduced[1]["max_hp"] = 27
	reduced[2]["max_hp"] = 23
	_assert_heal(reduced, [12, 27, 23], "torn_caps")
	_assert_heal(_party([40, 30, 26]), [40, 30, 26], "full_caps")
	_assert_heal(_party([0, 0, 1]), [13, 10, 8], "two_torn_one_survivor")
	_assert_heal(_party([0, 18, 0]), [13, 27, 8], "two_torn_middle_survivor")


func _test_snapshot_isolation_and_stale_guard() -> void:
	var source := _party([35, 18, 0])
	var original := source.duplicate(true)
	var visit := RunCampfireVisit.new("camp", source)
	_check(visit.read_state().get("status") == "open", "stale guard starts with real open visit")
	# Changes to caller after binding must neither change held roster nor qualify
	# as expected current state.
	source[0]["statuses"]["bleed"]["stacks"] = 99
	source[1]["metadata"]["patches"][0]["stitch"] = "caller-altered"
	source[2]["hp"] = 21
	_check(visit.read_state()["heroes"] == original, "private input snapshot is deeply copied")
	_assert_refused(visit, "camp", source, true, "changed caller roster")
	var exposed := visit.read_state()
	exposed["heroes"][0]["statuses"]["bleed"]["stacks"] = -100
	exposed["heroes"][1]["metadata"]["palette"][1]["trim"] = "leaked"
	exposed["node_id"] = "fake"
	exposed["status"] = "left"
	_check(visit.read_state()["heroes"] == original and visit.read_state()["status"] == "open",
		"mutating nested state projection and strings cannot alter held visit")
	for wrong_node in ["other", " camp", "camp ", "", " ", 42, null]:
		_assert_refused(visit, wrong_node, original, true, "wrong/malformed heal node " + str(wrong_node))
		_assert_refused(visit, wrong_node, original, false, "wrong/malformed leave node " + str(wrong_node))
	var bad_rosters: Array = [null, "not a roster", [], original.slice(0, 2)]
	var stale_hp := original.duplicate(true)
	stale_hp[1]["hp"] += 1
	bad_rosters.append(stale_hp)
	var stale_max := original.duplicate(true)
	stale_max[0]["max_hp"] -= 3
	bad_rosters.append(stale_max)
	var stale_position := original.duplicate(true)
	stale_position[1]["position"] = 3
	bad_rosters.append(stale_position)
	var stale_block := original.duplicate(true)
	stale_block[1]["block"] += 1
	bad_rosters.append(stale_block)
	var stale_status := original.duplicate(true)
	stale_status[0]["statuses"]["bleed"]["stacks"] += 1
	bad_rosters.append(stale_status)
	var stale_metadata := original.duplicate(true)
	stale_metadata[2]["metadata"]["palette"][1]["trim"] = "pink"
	bad_rosters.append(stale_metadata)
	var forged_extra := original.duplicate(true)
	forged_extra[0]["unowned_currency"] = 999
	bad_rosters.append(forged_extra)
	var duplicate_id := original.duplicate(true)
	duplicate_id[1]["id"] = "warden"
	bad_rosters.append(duplicate_id)
	var all_down := original.duplicate(true)
	for hero in all_down:
		hero["hp"] = 0
	bad_rosters.append(all_down)
	for i in range(bad_rosters.size()):
		_assert_refused(visit, "camp", bad_rosters[i], true, "stale/malformed expected heal %d" % i)
		_assert_refused(visit, "camp", bad_rosters[i], false, "stale/malformed expected Leave %d" % i)
	var receipt := visit.choose_heal("camp", original)
	_check(receipt.get("ok") == true and receipt["heroes"][2]["hp"] == 8,
		"all rejected attempts preserve later legal heal and Torn revival")
	var committed := visit.read_state()
	receipt["heroes"][0]["statuses"]["bleed"]["stacks"] = 998
	receipt["heroes"][1]["metadata"]["patches"][0]["stitch"] = "receipt-mutated"
	receipt["heroes"][2]["hp"] = 0
	committed["heroes"][1]["metadata"]["palette"][1]["trim"] = "read-mutated"
	_check(visit.read_state()["heroes"] == RunRestRecovery.new(original).choose_heal()["heroes"],
		"returned receipt and post-commit nested snapshot never alias held state")
	_check(original[0]["statuses"]["bleed"]["stacks"] == 1
		and original[1]["metadata"]["patches"][0]["stitch"] == "hero_1",
		"source fixture nested fields remain authentic")


func _test_leave() -> void:
	var source := _party([0, 19, 25])
	var initial := source.duplicate(true)
	var visit := RunCampfireVisit.new("camp_leave", source)
	_check(visit.read_state()["status"] == "open", "Leave fixture starts open")
	_assert_refused(visit, "wrong", initial, false, "wrong node cannot Leave")
	var receipt := visit.leave("camp_leave", source)
	_check(receipt == {"ok": true, "decision": "leave", "node_id": "camp_leave",
		"heroes": initial}, "Leave returns explicit receipt and unchanged complete heroes")
	_check(visit.read_state() == {"ok": true, "node_id": "camp_leave",
		"status": "left", "heroes": initial}, "Leave state closes without altering any field")
	_check(source == initial and receipt["heroes"][0]["hp"] == 0,
		"Leave never revives Torn actors or modifies input")
	_assert_refused(visit, "camp_leave", initial, false, "duplicate Leave")
	_assert_refused(visit, "camp_leave", initial, true, "Heal after Leave")
	receipt["heroes"][0]["metadata"]["patches"][0]["stitch"] = "polluted"
	receipt["heroes"][1]["statuses"]["weak"][0] = -50
	_check(visit.read_state()["heroes"] == initial and source == initial,
		"returned Leave roster and nested metadata detached")


func _test_invalid_construction() -> void:
	var valid := _party([35, 18, 0])
	for invalid_id in [null, 1, [], {}, "", "  ", " camp", "camp ", "\tcamp", "camp\n"]:
		var rejected := RunCampfireVisit.new(invalid_id, valid)
		_check(rejected.read_state() == {"ok": false, "node_id": "",
			"status": "invalid", "heroes": []},
			"malformed node never admits a visit: " + str(invalid_id))
		_assert_refused(rejected, invalid_id, valid, true, "invalid node Heal")
		_assert_refused(rejected, invalid_id, valid, false, "invalid node Leave")
	var bad: Array = [null, "not a roster", [], valid.slice(0, 2), _party([0, 0, 0])]
	var too_long := valid.duplicate(true)
	too_long.append(valid[0].duplicate(true))
	bad.append(too_long)
	var non_actor := valid.duplicate(true)
	non_actor[1] = 42
	bad.append(non_actor)
	var same_id := valid.duplicate(true)
	same_id[1]["id"] = "warden"
	bad.append(same_id)
	var wrong_position := valid.duplicate(true)
	wrong_position[1]["position"] = 3
	bad.append(wrong_position)
	var missing_field := valid.duplicate(true)
	missing_field[1].erase("max_hp")
	bad.append(missing_field)
	for pair in [["hp", -1], ["hp", 31], ["hp", 1.5], ["max_hp", 0],
			["max_hp", 30.5], ["position", "2"], ["id", ""]]:
		var actor := valid.duplicate(true)
		actor[1][pair[0]] = pair[1]
		bad.append(actor)
	for i in range(bad.size()):
		var input: Variant = bad[i]
		var before: Variant = input.duplicate(true) if typeof(input) == TYPE_ARRAY else input
		_check(RunRestRecovery.new(input).choose_heal().get("ok") == false,
			"invalid roster %d is independently refused by Rest" % i)
		var rejected := RunCampfireVisit.new("camp", input)
		_check(rejected.read_state() == {"ok": false, "node_id": "",
			"status": "invalid", "heroes": []}, "invalid roster %d cannot open" % i)
		_assert_refused(rejected, "camp", input, true, "invalid roster Heal %d" % i)
		_assert_refused(rejected, "camp", input, false, "invalid roster Leave %d" % i)
		_check(input == before, "invalid roster %d was not touched" % i)


func _test_replay_and_rng() -> void:
	var start := _party([35, 18, 0])
	seed(742195)
	var expected_next := randi()
	seed(742195)
	var a := RunCampfireVisit.new("camp", start)
	var b := RunCampfireVisit.new("camp", start.duplicate(true))
	_assert_refused(a, "other", start, true, "seeded rejected node")
	var first := a.choose_heal("camp", start)
	var second := b.choose_heal("camp", start.duplicate(true))
	_check(first.get("ok") == true and second.get("ok") == true
		and first == second and a.read_state() == b.read_state(),
		"two real independent visits deterministically agree on committed Heal")
	_check(first["heroes"][2]["hp"] == 8 and first["decision"] == "heal",
		"replay reaches successful, non-vacuous Torn revive")
	var leave_a := RunCampfireVisit.new("another", start)
	var leave_b := RunCampfireVisit.new("another", start.duplicate(true))
	_check(leave_a.leave("another", start) == leave_b.leave("another", start)
		and leave_a.read_state() == leave_b.read_state(),
		"independent Leave visits replay with identical no-op receipts")
	_check(randi() == expected_next, "construction, decisions, rejections do not draw global RNG")
