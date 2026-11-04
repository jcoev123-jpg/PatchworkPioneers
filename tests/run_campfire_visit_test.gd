extends SceneTree

var failures: Array[String] = []
var checks: int = 0
var starter: Array = []
var v3_roster: Array = []


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
	var v3_source := FileAccess.get_file_as_string("res://data/heroes/v3_party_roster.json")
	var v3_parsed: Variant = JSON.parse_string(v3_source)
	_check(not v3_source.is_empty() and typeof(v3_parsed) == TYPE_ARRAY,
		"loads actual authored v3 party roster")
	if typeof(v3_parsed) != TYPE_ARRAY:
		_finish()
		return
	v3_roster = v3_parsed
	_check(_v3_hero("button_golem").size() > 0,
		"authored v3 roster contains the button_golem identity")
	_test_heals()
	_test_snapshot_isolation_and_stale_guard()
	_test_leave()
	_test_invalid_construction()
	_test_replay_and_rng()
	_test_stitched_open_quote_and_leave()
	_test_stitched_invalid_construction()
	_test_stitched_decisions()
	_test_stitched_rejections_and_replay()
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


func _v3_hero(hero_id: String) -> Dictionary:
	for entry in v3_roster:
		if entry.get("id") == hero_id:
			return entry
	return {}


## Four authentic identities (starter ranks 1-3 plus the authored v3 button
## golem at rank 4), with position, hp and fray assigned to the run records.
func _stitched_party(hps: Array, frays: Array) -> Array:
	var party: Array = []
	for i in range(3):
		var hero: Dictionary = starter[i].duplicate(true)
		hero["position"] = i + 1
		hero["hp"] = hps[i]
		hero["fray"] = frays[i]
		hero["block"] = 5 + i
		hero["statuses"] = {"bleed": {"stacks": i + 1}, "weak": [i, "felt"]}
		hero["metadata"] = {"patches": [{"stitch": "hero_%d" % i}],
			"palette": ["wool", {"trim": "green"}]}
		party.append(hero)
	var fourth: Dictionary = _v3_hero("button_golem").duplicate(true)
	fourth["position"] = 4
	fourth["hp"] = hps[3]
	fourth["fray"] = frays[3]
	fourth["block"] = 9
	fourth["statuses"] = {"bleed": {"stacks": 4}}
	fourth["metadata"] = {"patches": [{"stitch": "golem"}],
		"palette": ["brass", {"trim": "red"}]}
	party.append(fourth)
	return party


func _assert_stitched_refused(visit: RunCampfireVisit, decision: Variant,
		node: Variant, heroes: Variant, candle: Variant, label: String) -> void:
	var before := visit.read_state()
	var result: Dictionary = visit.select(decision, node, heroes, candle)
	_check(result == {"ok": false, "decision": "", "node_id": "", "heroes": [], "candle": 0},
		label + ": uniformly typed stitched refusal, no forged receipt")
	_check(visit.read_state() == before, label + ": refusal does not consume or modify visit")


func _test_stitched_open_quote_and_leave() -> void:
	var source := _stitched_party([35, 18, 0, 48], [30, 25, 10, 200])
	var original := source.duplicate(true)
	var visit := RunCampfireVisit.new("camp_st", source, "stitched", 40)
	var open := visit.read_state()
	_check(open.get("ok") == true and open.get("node_id") == "camp_st"
		and open.get("status") == "stitched_open" and open.get("mode") == "stitched"
		and open.get("candle") == 40 and open.get("heroes") == original,
		"stitched visit opens with full detached roster, mode and candle")
	var quote: Dictionary = open.get("quote")
	_check(quote.get("choices") == ["mend", "tell_tales", "trim_the_wick", "leave"],
		"quote lists exactly Mend, Tell Tales, Trim the Wick and Leave")
	var text: String = quote.get("text")
	_check(not text.is_empty() and text.find("Mend") != -1 and text.find("Tell Tales") != -1
		and text.find("Trim the Wick") != -1 and text.find("Leave") != -1,
		"quote text names all four choices")
	source[0]["fray"] = 199
	source[3]["passive"]["id"] = "forged"
	_check(visit.read_state().get("heroes") == original,
		"stitched private input snapshot is deeply copied")
	var exposed := visit.read_state()
	exposed["heroes"][1]["metadata"]["palette"][1]["trim"] = "leaked"
	exposed["quote"]["choices"][0] = "forged"
	exposed["candle"] = -5
	var reread := visit.read_state()
	_check(reread.get("heroes") == original and reread.get("candle") == 40
		and reread.get("quote", {}).get("choices") == ["mend", "tell_tales", "trim_the_wick", "leave"],
		"mutating projected heroes, quote or candle cannot alter held visit")
	var before := visit.read_state()
	_check(visit.choose_heal("camp_st", original)
		== {"ok": false, "decision": "", "node_id": "", "heroes": []},
		"legacy heal is refused on a stitched visit")
	_check(visit.leave("camp_st", original)
		== {"ok": false, "decision": "", "node_id": "", "heroes": []},
		"legacy leave is refused on a stitched visit")
	_check(visit.read_state() == before, "legacy attempts leave the stitched visit untouched")
	var receipt := visit.select("leave", "camp_st", original, 40)
	_check(receipt == {"ok": true, "decision": "leave", "node_id": "camp_st",
		"heroes": original, "candle": 40},
		"Leave receipt returns node, decision, detached roster and candle")
	var decided := visit.read_state()
	_check(decided.get("status") == "stitched_decided" and decided.get("heroes") == original
		and decided.get("candle") == 40
		and decided.get("quote", {}).get("choices") == ["mend", "tell_tales", "trim_the_wick", "leave"],
		"the single selection consumes the visit without changing any field")
	_assert_stitched_refused(visit, "mend", "camp_st", original, 40, "decision after Leave")
	_assert_stitched_refused(visit, "leave", "camp_st", receipt.get("heroes"), 40, "duplicate Leave")
	receipt["heroes"][0]["statuses"]["bleed"]["stacks"] = 999
	receipt["candle"] = -1
	_check(visit.read_state().get("heroes") == original
		and visit.read_state().get("candle") == 40,
		"returned stitched receipt never aliases held state")
	var legacy_visit := RunCampfireVisit.new("camp_legacy", _party([35, 18, 0]))
	_assert_stitched_refused(legacy_visit, "mend", "camp_legacy", _party([35, 18, 0]), 40,
		"stitched select on a legacy visit is refused")
	_check(legacy_visit.choose_heal("camp_legacy", _party([35, 18, 0])).get("ok") == true,
		"legacy visit still heals after a refused stitched select")


func _test_stitched_invalid_construction() -> void:
	var valid := _stitched_party([35, 18, 0, 48], [30, 25, 10, 200])
	var invalid_state := {"ok": false, "node_id": "", "status": "invalid", "heroes": []}
	_check(RunCampfireVisit.new("camp_st", valid, "stitched").read_state() == invalid_state,
		"stitched mode without a candle never admits a visit")
	for bad_mode in [["", 40], ["cards", 40], ["Stitched", 40], [42, 40], [true, 40]]:
		var rejected := RunCampfireVisit.new("camp_st", valid, bad_mode[0], bad_mode[1])
		_check(rejected.read_state() == invalid_state,
			"unknown stitched mode never admits a visit: " + str(bad_mode[0]))
		_assert_stitched_refused(rejected, "mend", "camp_st", valid, 40, "invalid mode select")
	_check(RunCampfireVisit.new("camp_st", valid).read_state() == invalid_state,
		"four heroes cannot enter the legacy three-hero service")
	_check(RunCampfireVisit.new(" ", valid, "stitched", 40).read_state() == invalid_state,
		"malformed node never admits a stitched visit")
	var bad: Array = []
	bad.append(valid.slice(0, 3))
	var five := valid.duplicate(true)
	five.append(valid[0].duplicate(true))
	bad.append(five)
	var missing_position := valid.duplicate(true)
	missing_position[2].erase("position")
	bad.append(missing_position)
	var duplicate_position := valid.duplicate(true)
	duplicate_position[2]["position"] = 1
	bad.append(duplicate_position)
	var unordered := valid.duplicate(true)
	unordered[0]["position"] = 2
	unordered[1]["position"] = 1
	bad.append(unordered)
	var duplicate_id := valid.duplicate(true)
	duplicate_id[3]["id"] = "warden"
	bad.append(duplicate_id)
	var blank_id := valid.duplicate(true)
	blank_id[1]["id"] = "  "
	bad.append(blank_id)
	var non_actor := valid.duplicate(true)
	non_actor[2] = 42
	bad.append(non_actor)
	for pair in [["hp", -1], ["hp", 31], ["hp", 1.5], ["max_hp", 0], ["max_hp", 30.5],
			["fray", -1], ["fray", 201], ["fray", 1.5], ["position", "4"]]:
		var actor := valid.duplicate(true)
		actor[2][pair[0]] = pair[1]
		bad.append(actor)
	var missing_hp := valid.duplicate(true)
	missing_hp[1].erase("hp")
	bad.append(missing_hp)
	var missing_fray := valid.duplicate(true)
	missing_fray[3].erase("fray")
	bad.append(missing_fray)
	for i in range(bad.size()):
		var input: Variant = bad[i]
		var before: Variant = input.duplicate(true)
		var rejected := RunCampfireVisit.new("camp_st", input, "stitched", 40)
		_check(rejected.read_state() == invalid_state,
			"invalid stitched roster %d cannot open" % i)
		_assert_stitched_refused(rejected, "mend", "camp_st", input, 40,
			"invalid stitched roster select %d" % i)
		_assert_stitched_refused(rejected, "leave", "camp_st", input, 40,
			"invalid stitched roster leave %d" % i)
		_check(input == before, "invalid stitched roster %d was not touched" % i)
	for bad_candle in [-1, 101, 1.5, "40", null, [], {}]:
		var candle_rejected := RunCampfireVisit.new("camp_st", valid, "stitched", bad_candle)
		_check(candle_rejected.read_state() == invalid_state,
			"out-of-range or malformed candle never admits a visit: " + str(bad_candle))
		_assert_stitched_refused(candle_rejected, "mend", "camp_st", valid, 40,
			"invalid candle select")


func _test_stitched_decisions() -> void:
	var source := _stitched_party([35, 18, 0, 48], [30, 25, 10, 200])
	var original := source.duplicate(true)
	var visit := RunCampfireVisit.new("camp_mend", source, "stitched", 40)
	var receipt := visit.select("mend", "camp_mend", original, 40)
	_check(receipt.get("ok") == true and receipt.get("decision") == "mend"
		and receipt.get("node_id") == "camp_mend" and receipt.get("candle") == 40,
		"Mend receipt names node and decision, keeps candle")
	var healed: Array = receipt.get("heroes")
	_check(healed[0]["hp"] == 40, "warden heals floor(30% of 40) = 12, capped at 40")
	_check(healed[1]["hp"] == 27, "seamstress heals exactly floor(30% of 30) = 9")
	_check(healed[2]["hp"] == 7, "Hanging tinker heals exactly floor(30% of 26) = 7")
	_check(healed[3]["hp"] == 48, "full button golem stays capped at its maximum")
	var legacy := RunRestRecovery.new(original.slice(0, 3)).choose_heal()
	_check(legacy.get("ok") == true and legacy["heroes"][2]["hp"] == 8,
		"legacy Rest still revive-firsts the same trio to 8")
	for i in range(4):
		_check(healed[i]["fray"] == original[i]["fray"]
			and healed[i]["max_hp"] == original[i]["max_hp"]
			and healed[i]["block"] == original[i]["block"]
			and healed[i]["statuses"] == original[i]["statuses"]
			and healed[i]["metadata"] == original[i]["metadata"],
			"Mend slot %d changes only HP" % (i + 1))
	_check(healed[3]["passive"] == original[3]["passive"]
		and healed[3]["name"] == original[3]["name"],
		"Mend preserves unrelated golem identity and passive")
	_check(source == original, "Mend leaves the caller's roster untouched")
	receipt["heroes"][0]["metadata"]["patches"][0]["stitch"] = "receipt-mutated"
	_check(visit.read_state().get("heroes")[0]["metadata"]["patches"][0]["stitch"] == "hero_0",
		"returned Mend roster never aliases held state")
	_assert_stitched_refused(visit, "mend", "camp_mend", healed, 40, "duplicate Mend")
	_assert_stitched_refused(visit, "tell_tales", "camp_mend", healed, 40,
		"second decision after Mend")

	var tales_source := _stitched_party([40, 30, 26, 48], [100, 26, 24, 200])
	var tales_original := tales_source.duplicate(true)
	var tales_visit := RunCampfireVisit.new("camp_tales", tales_source, "stitched", 40)
	var tales_receipt := tales_visit.select("tell_tales", "camp_tales", tales_original, 40)
	_check(tales_receipt.get("ok") == true and tales_receipt.get("decision") == "tell_tales"
		and tales_receipt.get("candle") == 40,
		"Tell Tales receipt names its decision and keeps candle")
	var tales: Array = tales_receipt.get("heroes")
	_check(tales[0]["fray"] == 75 and tales[1]["fray"] == 1 and tales[2]["fray"] == 0
		and tales[3]["fray"] == 175,
		"Tell Tales subtracts 25 fray from each hero, floored at zero")
	for i in range(4):
		_check(tales[i]["hp"] == tales_original[i]["hp"]
			and tales[i]["max_hp"] == tales_original[i]["max_hp"]
			and tales[i]["block"] == tales_original[i]["block"]
			and tales[i]["statuses"] == tales_original[i]["statuses"]
			and tales[i]["metadata"] == tales_original[i]["metadata"],
			"Tell Tales slot %d changes only fray" % (i + 1))
	_check(tales_source == tales_original, "Tell Tales leaves the caller's roster untouched")
	_assert_stitched_refused(tales_visit, "tell_tales", "camp_tales", tales, 40,
		"duplicate Tell Tales")

	var wick_source := _stitched_party([35, 18, 0, 48], [30, 25, 10, 200])
	var wick_original := wick_source.duplicate(true)
	var wick_visit := RunCampfireVisit.new("camp_wick", wick_source, "stitched", 40)
	var wick_receipt := wick_visit.select("trim_the_wick", "camp_wick", wick_original, 40)
	_check(wick_receipt.get("ok") == true and wick_receipt.get("decision") == "trim_the_wick"
		and wick_receipt.get("candle") == 90,
		"Trim the Wick restores exactly 50 candle")
	_check(wick_receipt.get("heroes") == wick_original,
		"Trim the Wick changes no hero field")
	var capped_visit := RunCampfireVisit.new("camp_wick_cap", wick_source.duplicate(true),
		"stitched", 60)
	var capped_receipt := capped_visit.select("trim_the_wick", "camp_wick_cap", wick_original, 60)
	_check(capped_receipt.get("ok") == true and capped_receipt.get("candle") == 100,
		"Trim the Wick caps candle at 100")
	_check(wick_source == wick_original, "Trim the Wick leaves the caller's roster untouched")
	_assert_stitched_refused(wick_visit, "trim_the_wick", "camp_wick", wick_original, 40,
		"duplicate Trim the Wick")


func _test_stitched_rejections_and_replay() -> void:
	var source := _stitched_party([35, 18, 0, 48], [30, 25, 10, 200])
	var original := source.duplicate(true)
	var visit := RunCampfireVisit.new("camp_rep", source, "stitched", 40)
	for wrong_node in ["other", "", " camp_rep", 42, null]:
		_assert_stitched_refused(visit, "mend", wrong_node, original, 40,
			"wrong/malformed stitched node " + str(wrong_node))
	var stale_hp := original.duplicate(true)
	stale_hp[1]["hp"] += 1
	_assert_stitched_refused(visit, "mend", "camp_rep", stale_hp, 40, "stale hp roster")
	var stale_fray := original.duplicate(true)
	stale_fray[3]["fray"] -= 1
	_assert_stitched_refused(visit, "mend", "camp_rep", stale_fray, 40, "stale fray roster")
	var stale_nested := original.duplicate(true)
	stale_nested[2]["metadata"]["palette"][1]["trim"] = "pink"
	_assert_stitched_refused(visit, "mend", "camp_rep", stale_nested, 40,
		"stale nested metadata")
	var forged_extra := original.duplicate(true)
	forged_extra[0]["unowned_currency"] = 999
	_assert_stitched_refused(visit, "mend", "camp_rep", forged_extra, 40,
		"forged extra field cannot pass as the snapshot")
	_assert_stitched_refused(visit, "mend", "camp_rep", original, 41, "stale candle")
	_assert_stitched_refused(visit, "mend", "camp_rep", original, "40",
		"malformed candle snapshot")
	for bad_decision in ["", "heal", "Mend", "mend ", " trim_the_wick", "trim", 42, null, ["mend"]]:
		_assert_stitched_refused(visit, bad_decision, "camp_rep", original, 40,
			"stale/forged decision " + str(bad_decision))
	var a := RunCampfireVisit.new("camp_rep", original.duplicate(true), "stitched", 40)
	var b := RunCampfireVisit.new("camp_rep", original.duplicate(true), "stitched", 40)
	_assert_stitched_refused(a, "tell_tales", "wrong", original, 40, "seeded rejected node")
	var first: Dictionary = a.select("tell_tales", "camp_rep", original, 40)
	var second: Dictionary = b.select("tell_tales", "camp_rep", original, 40)
	_check(first.get("ok") == true and second.get("ok") == true and first == second
		and a.read_state() == b.read_state(),
		"two fresh stitched visits replay the same decision identically")
	_check(first["heroes"][1]["fray"] == 0 and first["heroes"][3]["fray"] == 175,
		"replay reaches a real committed Tell Tales")
	_assert_stitched_refused(a, "mend", "camp_rep", first["heroes"], 40,
		"second decision after use")
	_assert_stitched_refused(a, "tell_tales", "camp_rep", first["heroes"], 40,
		"duplicate decision does not consume anything new")
	_assert_stitched_refused(a, "mend", "camp_rep", original, 40,
		"stale pre-decision snapshot after use")
	_check(a.read_state() == b.read_state(),
		"rejections after use never modify committed visits")
	seed(918273)
	var expected_next := randi()
	seed(918273)
	var c := RunCampfireVisit.new("camp_rng", original.duplicate(true), "stitched", 55)
	_assert_stitched_refused(c, "mend", "nope", original, 55, "rng rejection fixture")
	var rng_receipt: Dictionary = c.select("trim_the_wick", "camp_rng", original, 55)
	_check(rng_receipt.get("ok") == true and rng_receipt.get("candle") == 100,
		"rng fixture commits a capped Trim the Wick")
	_check(randi() == expected_next,
		"stitched construction, quote, rejections and actions draw no global RNG")
