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
	_test_stitched_actionable_quotes()
	_test_stitched_quote_actual_totals()
	_test_stitched_noop_refusals()
	_test_stitched_lost_dolls_not_mended()
	_test_swap_admission_and_quote()
	_test_swap_exchanges_and_decisions()
	_test_swap_refusals_and_isolation()
	_test_fear_admission_and_shape()
	_test_fear_tell_tales()
	_test_fear_other_choices_and_swap()
	_test_fear_refusals_replay_and_rng()
	_test_tales_clears_unravelled_below_threshold()
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
		and decided.get("quote", {}).get("choices") == [],
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


const FULL_HPS: Array = [40, 30, 26, 48]
const NO_FRAY: Array = [0, 0, 0, 0]


func _quote_for(hps: Array, frays: Array, candle: int) -> Dictionary:
	var visit := RunCampfireVisit.new("camp_q", _stitched_party(hps, frays), "stitched", candle)
	return visit.read_state().get("quote", {})


func _assert_quote(hps: Array, frays: Array, candle: int, expected: Array, label: String) -> void:
	var quote := _quote_for(hps, frays, candle)
	_check(quote.get("choices") == expected, label + ": quote choices " + str(expected))
	var text: String = quote.get("text", "")
	_check(not text.is_empty(), label + ": quote text present")
	_check((text.find("Mend") != -1) == expected.has("mend")
		and (text.find("30%") != -1) == expected.has("mend"),
		label + ": text names Mend and 30% only when advertised")
	_check((text.find("Tell Tales") != -1) == expected.has("tell_tales")
		and (text.find("25 FRAY") != -1) == expected.has("tell_tales"),
		label + ": text names Tell Tales and 25 only when advertised")
	_check((text.find("Trim the Wick") != -1) == expected.has("trim_the_wick")
		and (text.find("50 CANDLE") != -1) == expected.has("trim_the_wick"),
		label + ": text names the Wick and 50 only when advertised")
	_check(text.find("Leave") != -1, label + ": text always names Leave")


func _test_stitched_actionable_quotes() -> void:
	_assert_quote([35, 18, 0, 48], [30, 25, 10, 200], 40,
		["mend", "tell_tales", "trim_the_wick", "leave"], "all effective")
	_assert_quote(FULL_HPS, NO_FRAY, 100, ["leave"], "no benefit")
	_assert_quote([40, 30, 26, 47], NO_FRAY, 100, ["mend", "leave"], "one hero short of max HP")
	_assert_quote([40, 30, 0, 48], NO_FRAY, 100, ["mend", "leave"], "Hanging hero at 0 HP")
	_assert_quote(FULL_HPS, [0, 0, 0, 1], 100, ["tell_tales", "leave"], "FRAY 1")
	_assert_quote(FULL_HPS, NO_FRAY, 99, ["trim_the_wick", "leave"], "CANDLE 99")
	_assert_quote(FULL_HPS, NO_FRAY, 100, ["leave"], "CANDLE 100")
	_assert_quote(FULL_HPS, NO_FRAY, 0, ["trim_the_wick", "leave"], "CANDLE 0")
	_assert_quote([40, 29, 26, 48], [0, 200, 0, 0], 70,
		["mend", "tell_tales", "trim_the_wick", "leave"], "mixed, all three")
	_assert_quote([40, 29, 26, 48], NO_FRAY, 70, ["mend", "trim_the_wick", "leave"],
		"mixed, HP and candle")
	_assert_quote(FULL_HPS, [25, 0, 0, 0], 100, ["tell_tales", "leave"], "mixed, FRAY only")
	# The quote is detached from held state.
	var visit := RunCampfireVisit.new("camp_q", _stitched_party(FULL_HPS, [0, 0, 5, 0]), "stitched", 100)
	var state := visit.read_state()
	state["quote"]["choices"].append("mend")
	state["quote"]["text"] = "forged"
	var reread := visit.read_state()
	_check(reread["quote"]["choices"] == ["tell_tales", "leave"] and reread["quote"]["text"] != "forged",
		"returned quote is detached from the held visit")
	# A decided visit advertises nothing.
	var heroes: Array = reread["heroes"]
	_check(visit.select("leave", "camp_q", heroes, 100).get("ok") == true, "decided fixture commits Leave")
	var decided := visit.read_state()
	_check(decided["status"] == "stitched_decided" and decided["quote"]["choices"] == [],
		"completed visit has no selectable choices")
	_assert_stitched_refused(visit, "leave", "camp_q", heroes, 100, "Leave on a decided visit")
	_assert_stitched_refused(visit, "tell_tales", "camp_q", heroes, 100, "Tell Tales on a decided visit")


## Independent cap-aware oracles for the quoted actual recovery totals.
func _mend_oracle(party: Array) -> int:
	var total: int = 0
	for hero in party:
		if hero.get("lost", false) == true:
			continue
		@warning_ignore("integer_division")
		total += mini((int(hero["max_hp"]) * RunCampfireVisit.MEND_HEAL_PERCENT) / 100,
			int(hero["max_hp"]) - int(hero["hp"]))
	return total


func _fray_oracle(party: Array) -> int:
	var total: int = 0
	for hero in party:
		total += mini(RunCampfireVisit.TALES_FRAY_REDUCTION, int(hero["fray"]))
	return total


## AC1-AC3: each quoted actual recovery total matches an independent fresh
## select() receipt on the same roster, beside the authored maximums, with no
## state, RNG or schema change.
func _test_stitched_quote_actual_totals() -> void:
	seed(474747)
	var expected_next := randi()
	seed(474747)
	# AC1: four distinct dolls at distinct ranks: full, wounded, Hanging and an
	# explicitly LOST doll wounded at 12/48 (still excluded from Mend).
	var mend_source := _lost_party([40, 18, 0, 12], [3], [30, 25, 10, 200])
	var mend_original := mend_source.duplicate(true)
	var ids: Dictionary = {}
	for i in range(4):
		ids[mend_original[i]["id"]] = true
		_check(int(mend_original[i]["position"]) == i + 1,
			"totals fixture doll %d holds rank position %d" % [i + 1, i + 1])
	_check(ids.size() == 4, "totals fixture uses four distinct doll identities")
	var mend_visit := RunCampfireVisit.new("camp_tot_m", mend_source, "stitched", 40)
	var mend_state := mend_visit.read_state()
	var mend_quote: Dictionary = mend_state["quote"]
	_check(mend_state["status"] == "stitched_open"
		and mend_quote["choices"] == ["mend", "tell_tales", "trim_the_wick", "leave"],
		"totals fixture stays open with the same ordered action ids")
	var mend_gain := _mend_oracle(mend_original)
	_check(mend_gain == 16,
		"independent Mend oracle: 0 full + 9 wounded + 7 Hanging, no LOST, no revive bonus")
	_check(mend_quote["text"].find("Mend 30%% max HP (+%d HP now)" % mend_gain) != -1,
		"quote states the exact summed Mend gain beside the literal 30% head")
	_check(mend_quote["text"].find("Leave (free") != -1, "quote keeps Leave present and free")
	var fresh_mend := RunCampfireVisit.new("camp_tot_m2",
		mend_original.duplicate(true), "stitched", 40)
	var mend_receipt: Dictionary = fresh_mend.select("mend", "camp_tot_m2", mend_original, 40)
	var receipt_gain: int = 0
	for i in range(4):
		receipt_gain += int(mend_receipt["heroes"][i]["hp"]) - int(mend_original[i]["hp"])
	_check(mend_receipt.get("ok") == true and receipt_gain == mend_gain
		and mend_receipt["heroes"][3]["hp"] == 12 and mend_receipt["heroes"][3]["lost"] == true
		and mend_receipt["heroes"][2]["hp"] == 7,
		"fresh Mend receipt commits exactly the quoted gain; LOST stays wounded, Hanging gets no bonus")
	_check(mend_visit.read_state() == mend_state,
		"reading the quote and a fresh receipt leave the first visit untouched")
	# AC2: FRAY 0/1/25/200 with and without optional Wren FEAR 0/5/15, plus FEAR-only.
	var fray_source := _stitched_party(FULL_HPS, [0, 1, 25, 200])
	var fray_original := fray_source.duplicate(true)
	var fray_gain := _fray_oracle(fray_original)
	_check(fray_gain == 51, "independent Tales oracle: 0 + 1 + 25 + 25 capped relief")
	var fray_visit := RunCampfireVisit.new("camp_tot_t", fray_source, "stitched", 100)
	var fray_quote: Dictionary = fray_visit.read_state()["quote"]
	_check(fray_quote["choices"] == ["tell_tales", "leave"],
		"full-HP fray fixture offers Tales and Leave only")
	_check(fray_quote["text"].find("Tell Tales up to 25 FRAY each (-%d FRAY now)" % fray_gain) != -1
		and fray_quote["text"].find("Wren FEAR") == -1,
		"quote states the summed FRAY relief beside the literal 25 FRAY head, no fear segment")
	var fray_receipt: Dictionary = fray_visit.select("tell_tales", "camp_tot_t", fray_original, 100)
	var fray_delta: int = 0
	for i in range(4):
		fray_delta += int(fray_original[i]["fray"]) - int(fray_receipt["heroes"][i]["fray"])
	_check(fray_receipt.get("ok") == true and fray_delta == fray_gain
		and not fray_receipt.has("fear"),
		"fresh Tales receipt removes exactly the quoted FRAY and stays fear-free")
	for fear in [0, 5, 15]:
		var fear_visit := RunCampfireVisit.new("camp_tot_f", _stitched_party(FULL_HPS,
			[0, 1, 25, 200]), "stitched", 100, fear)
		var fear_quote: Dictionary = fear_visit.read_state()["quote"]
		_check(fear_quote["text"].find("Tell Tales up to 25 FRAY each (-%d FRAY now; -%d Wren FEAR now)"
			% [fray_gain, mini(RunCampfireVisit.TALES_FEAR_RELIEF, fear)]) != -1,
			"quote at Wren FEAR %d states the actual FRAY and FEAR relief" % fear)
		var fear_receipt: Dictionary = fear_visit.select("tell_tales", "camp_tot_f",
			_stitched_party(FULL_HPS, [0, 1, 25, 200]), 100, fear)
		var fear_fray_delta: int = 0
		for i in range(4):
			fear_fray_delta += int(fray_original[i]["fray"]) - int(fear_receipt["heroes"][i]["fray"])
		_check(fear_receipt.get("ok") == true and fear_fray_delta == fray_gain
			and fear_receipt["fear"] == maxi(0, fear - RunCampfireVisit.TALES_FEAR_RELIEF),
			"fresh Tales receipt at Wren FEAR %d matches the quoted relief" % fear)
	# FEAR alone keeps Tales an actionable choice, truthful about zero FRAY.
	var only_fear := RunCampfireVisit.new("camp_tot_of", _stitched_party(FULL_HPS, NO_FRAY),
		"stitched", 100, 20)
	var only_quote: Dictionary = only_fear.read_state()["quote"]
	_check(only_quote["choices"] == ["tell_tales", "leave"]
		and only_quote["text"].find("Tell Tales up to 25 FRAY each (-0 FRAY now; -15 Wren FEAR now)") != -1,
		"FEAR-only Tales stays offered and truthful about the zero FRAY relief")
	var only_receipt: Dictionary = only_fear.select("tell_tales", "camp_tot_of",
		_stitched_party(FULL_HPS, NO_FRAY), 100, 20)
	_check(only_receipt.get("ok") == true and only_receipt["fear"] == 5
		and only_receipt["heroes"] == _stitched_party(FULL_HPS, NO_FRAY),
		"FEAR-only Tales soothes exactly 15 FEAR and changes no doll")
	# A LOST record still counts toward the Tales relief and stays LOST.
	var lost_fray := _lost_party([40, 30, 26, 0], [3], [0, 0, 0, 200])
	var lost_visit := RunCampfireVisit.new("camp_tot_l", lost_fray, "stitched", 100)
	var lost_quote: Dictionary = lost_visit.read_state()["quote"]
	_check(lost_quote["choices"] == ["tell_tales", "leave"]
		and lost_quote["text"].find("Tell Tales up to 25 FRAY each (-25 FRAY now)") != -1,
		"a LOST doll's FRAY still counts toward the quoted Tales relief")
	var lost_receipt: Dictionary = lost_visit.select("tell_tales", "camp_tot_l", lost_fray, 100)
	_check(lost_receipt.get("ok") == true and lost_receipt["heroes"][3]["fray"] == 175
		and lost_receipt["heroes"][3]["lost"] == true and lost_receipt["heroes"][3]["hp"] == 0,
		"Tales still unravels a LOST doll's FRAY and never revives it")
	# AC3: the quoted Wick gain is cap-aware at CANDLE 0/60/99 and absent at 100.
	for candle in [0, 60, 99]:
		var gain := mini(RunCampfireVisit.WICK_CANDLE_RESTORE,
			RunCampfireVisit.STITCHED_CANDLE_MAX - candle)
		var wick_visit := RunCampfireVisit.new("camp_tot_w",
			_stitched_party(FULL_HPS, NO_FRAY), "stitched", candle)
		var wick_quote: Dictionary = wick_visit.read_state()["quote"]
		_check(wick_quote["choices"] == ["trim_the_wick", "leave"]
			and wick_quote["text"].find("Trim the Wick up to %d CANDLE (+%d now)"
				% [RunCampfireVisit.WICK_CANDLE_RESTORE, gain]) != -1,
			"CANDLE %d quotes the exact cap-aware Wick gain beside the 50 CANDLE head" % candle)
		var wick_receipt: Dictionary = wick_visit.select("trim_the_wick", "camp_tot_w",
			_stitched_party(FULL_HPS, NO_FRAY), candle)
		_check(wick_receipt.get("ok") == true and wick_receipt["candle"] == candle + gain
			and wick_receipt["heroes"] == _stitched_party(FULL_HPS, NO_FRAY),
			"fresh Wick receipt at CANDLE %d commits exactly the quoted gain" % candle)
	var full_visit := RunCampfireVisit.new("camp_tot_w100",
		_stitched_party(FULL_HPS, NO_FRAY), "stitched", 100)
	var full_quote: Dictionary = full_visit.read_state()["quote"]
	_check(full_quote["choices"] == ["leave"]
		and full_quote["text"].find("Trim the Wick") == -1
		and full_quote["text"].find("Mend") == -1
		and full_quote["text"].find("Tell Tales") == -1,
		"CANDLE 100 quotes only the free Leave with no unavailable option")
	_assert_stitched_refused(full_visit, "trim_the_wick", "camp_tot_w100",
		_stitched_party(FULL_HPS, NO_FRAY), 100, "unquoted Wick at CANDLE 100")
	# A closed visit offers nothing further, and none of this drew RNG.
	var closed := fresh_mend.read_state()
	_check(closed["status"] == "stitched_decided" and closed["quote"]["choices"] == []
		and closed["quote"]["text"].find("no choice remains") != -1,
		"a closed visit quotes no further choices")
	_check(randi() == expected_next,
		"quote totals, receipts and refusals draw no global RNG")


func _test_stitched_noop_refusals() -> void:
	seed(404404)
	var expected_next := randi()
	seed(404404)
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 77
	var local_state := local_rng.state
	var source := _stitched_party(FULL_HPS, NO_FRAY)
	var original := source.duplicate(true)
	var visit := RunCampfireVisit.new("camp_noop", source, "stitched", 100)
	for decision in ["mend", "tell_tales", "trim_the_wick"]:
		_assert_stitched_refused(visit, decision, "camp_noop", original, 100,
			"no-op " + decision + " with valid snapshot")
	_check(visit.read_state()["status"] == "stitched_open"
		and visit.read_state()["quote"]["choices"] == ["leave"],
		"no-op attempts keep the visit open with only Leave")
	var leave := visit.select("leave", "camp_noop", original, 100)
	_check(leave == {"ok": true, "decision": "leave", "node_id": "camp_noop",
		"heroes": original, "candle": 100}, "Leave still works after refused no-ops")
	_assert_stitched_refused(visit, "leave", "camp_noop", original, 100, "replay after Leave")
	# Mixed fixture: only the wick is effective; a later valid action still works.
	var wick_visit := RunCampfireVisit.new("camp_noop2", _stitched_party(FULL_HPS, NO_FRAY),
		"stitched", 99)
	_assert_stitched_refused(wick_visit, "mend", "camp_noop2", _stitched_party(FULL_HPS, NO_FRAY), 99,
		"no-op Mend beside effective Wick")
	_assert_stitched_refused(wick_visit, "tell_tales", "camp_noop2",
		_stitched_party(FULL_HPS, NO_FRAY), 99, "no-op Tell Tales beside effective Wick")
	var wick := wick_visit.select("trim_the_wick", "camp_noop2", _stitched_party(FULL_HPS, NO_FRAY), 99)
	_check(wick.get("ok") == true and wick.get("candle") == 100
		and wick.get("heroes") == _stitched_party(FULL_HPS, NO_FRAY),
		"effective Wick at CANDLE 99 still caps at 100 after refusals")
	# Satchel visit: refused no-ops leave swap authority and satchel untouched.
	var party := _swap_party()
	for hero in party:
		hero["hp"] = hero["max_hp"]
		hero["fray"] = 0
	var swap_visit := RunCampfireVisit.open_stitched_with_satchel("camp_noop3", party, 100,
		_swap_satchel(), _swap_catalog())
	var swap_before := swap_visit.read_state()
	_check(swap_before["status"] == "stitched_open" and swap_before["quote"]["choices"] == ["leave"],
		"satchel visit with no benefit quotes only Leave")
	for decision in ["mend", "tell_tales", "trim_the_wick"]:
		_assert_stitched_refused(swap_visit, decision, "camp_noop3", party, 100,
			"satchel no-op " + decision)
	_check(swap_visit.read_state() == swap_before
		and swap_visit.read_state()["swap_quote"]["open"] == true,
		"refused no-ops leave the swap opportunity and satchel unchanged")
	var swapped := swap_visit.swap_part("warden", "arms", 0, "camp_noop3", swap_before["swap_state"])
	_check(swapped.get("ok") == true, "swap still works after refused no-ops")
	var latest := swap_visit.read_state()
	_check(latest["quote"]["choices"] == ["leave"], "quote after a swap uses the latest held heroes")
	_assert_stitched_refused(swap_visit, "mend", "camp_noop3", latest["heroes"], 100,
		"no-op Mend after a swap")
	_check(swap_visit.select("leave", "camp_noop3", latest["heroes"], 100).get("ok") == true,
		"Leave closes the satchel visit after a swap")
	_check(swap_visit.read_state()["swap_quote"]["open"] == false
		and swap_visit.read_state()["quote"]["choices"] == [],
		"decided satchel visit closes swaps and advertises nothing")
	_check(randi() == expected_next and local_rng.state == local_state,
		"quotes and refused no-ops draw no RNG")


## A real four-rank roster where the listed ranks (0-based) are LOST dolls.
func _lost_party(hps: Array, lost_ranks: Array, frays: Array = NO_FRAY) -> Array:
	var party := _stitched_party(hps, frays)
	for rank in lost_ranks:
		party[rank]["lost"] = true
	return party


func _test_stitched_lost_dolls_not_mended() -> void:
	# AC1: lost rank 1 at 0 HP, wounded survivor, Hanging (not lost) doll, full doll.
	var source := _lost_party([0, 18, 0, 48], [0], [30, 25, 10, 200])
	var original := source.duplicate(true)
	_check(source[0]["lost"] == true and source[0]["hp"] == 0 and not source[2].has("lost")
		and source[2]["hp"] == 0 and source[1]["hp"] < source[1]["max_hp"],
		"lost-doll fixture has a lost 0-HP doll, a Hanging doll and a wounded survivor")
	var visit := RunCampfireVisit.new("camp_lost", source, "stitched", 40)
	_check(visit.read_state()["quote"]["choices"] == ["mend", "tell_tales", "trim_the_wick", "leave"],
		"Mend is quoted when a non-lost doll can recover")
	seed(556677)
	var expected_next := randi()
	seed(556677)
	var receipt := visit.select("mend", "camp_lost", original, 40)
	_check(receipt.get("ok") == true and receipt.get("decision") == "mend"
		and receipt.get("node_id") == "camp_lost" and receipt.get("candle") == 40,
		"Mend commits with a lost doll in the party")
	var expected := original.duplicate(true)
	expected[1]["hp"] = 27
	expected[2]["hp"] = 7
	_check(receipt.get("heroes") == expected,
		"Mend heals only non-lost dolls: floor(30%) 9 and Hanging 7; lost doll record unchanged")
	var healed: Array = receipt.get("heroes")
	_check(healed[0]["hp"] == 0 and healed[0]["lost"] == true
		and healed[0] == original[0] and healed[0]["position"] == 1
		and healed[0]["fray"] == 30,
		"lost doll stays at 0 HP, lost, same rank, fray and records")
	_check(healed[2]["hp"] == 7 and not healed[2].has("lost"), "Hanging 0-HP non-lost doll is healed")
	_check(healed[3] == original[3], "full-HP doll is untouched")
	var held := visit.read_state()
	_check(held["status"] == "stitched_decided" and held["heroes"] == expected and held["candle"] == 40
		and held["quote"]["choices"] == [], "held state matches the receipt and the visit is spent")
	_check(source == original, "caller roster untouched")
	_check(randi() == expected_next, "lost-doll Mend draws no global RNG")
	_assert_stitched_refused(visit, "mend", "camp_lost", expected, 40, "duplicate Mend with lost doll")
	# A lost doll wounded above 0 HP is not healed either.
	var partial := _lost_party([12, 30, 26, 48], [0])
	var partial_visit := RunCampfireVisit.new("camp_lost_p", partial, "stitched", 100)
	_check(partial_visit.read_state()["quote"]["choices"] == ["leave"],
		"a lost doll with HP below max alone offers no Mend")
	# Missing or false lost stays non-lost.
	var false_party := _lost_party([0, 30, 26, 48], [])
	false_party[0]["lost"] = false
	var false_visit := RunCampfireVisit.new("camp_lost_f", false_party, "stitched", 100)
	_check(false_visit.read_state()["quote"]["choices"] == ["mend", "leave"],
		"lost == false doll at 0 HP is healable")
	var false_receipt := false_visit.select("mend", "camp_lost_f", false_party, 100)
	_check(false_receipt.get("ok") == true and false_receipt["heroes"][0]["hp"] == 12,
		"lost == false doll heals floor(30% of 40) = 12")

	# AC2: only lost dolls miss HP -> no Mend, forged Mend refused without mutation.
	for lost_ranks in [[0], [1, 3], [0, 1, 2]]:
		var hps: Array = FULL_HPS.duplicate()
		for rank in lost_ranks:
			hps[rank] = 0
		var only_lost := _lost_party(hps, lost_ranks)
		var only_before := only_lost.duplicate(true)
		var only_visit := RunCampfireVisit.new("camp_only", only_lost, "stitched", 100)
		_check(only_visit.read_state()["quote"]["choices"] == ["leave"]
			and only_visit.read_state()["quote"]["text"].find("Mend") == -1,
			"only lost deficits %s: no Mend choice" % str(lost_ranks))
		_assert_stitched_refused(only_visit, "mend", "camp_only", only_before, 100,
			"forged Mend with only lost deficits %s" % str(lost_ranks))
		_check(only_visit.read_state()["status"] == "stitched_open"
			and only_visit.read_state()["heroes"] == only_before
			and only_visit.read_state()["candle"] == 100,
			"refused lost-only Mend leaves visit open and unchanged")
	seed(121314)
	var rng_next := randi()
	seed(121314)
	var rng_state := RandomNumberGenerator.new()
	rng_state.seed = 5
	var rng_before := rng_state.state
	var locked := RunCampfireVisit.new("camp_only2", _lost_party([0, 30, 26, 48], [0]), "stitched", 100)
	_assert_stitched_refused(locked, "mend", "camp_only2", _lost_party([0, 30, 26, 48], [0]), 100,
		"lost-only Mend with candle at 100")
	_check(randi() == rng_next and rng_state.state == rng_before, "refused lost-only Mend draws no RNG")
	# Other choices on the same roster are unchanged.
	var wick_party := _lost_party([0, 30, 26, 48], [0])
	var wick_visit := RunCampfireVisit.new("camp_only3", wick_party, "stitched", 60)
	_check(wick_visit.read_state()["quote"]["choices"] == ["trim_the_wick", "leave"],
		"lost-only deficit still offers the Wick when candle is low")
	var wick := wick_visit.select("trim_the_wick", "camp_only3", wick_party, 60)
	_check(wick.get("ok") == true and wick.get("candle") == 100 and wick.get("heroes") == wick_party,
		"Wick leaves the lost roster unchanged")
	var tales_party := _lost_party([0, 30, 26, 48], [0], [20, 0, 30, 0])
	var tales_visit := RunCampfireVisit.new("camp_only4", tales_party, "stitched", 100)
	var tales := tales_visit.select("tell_tales", "camp_only4", tales_party, 100)
	_check(tales.get("ok") == true and tales["heroes"][0]["fray"] == 0 and tales["heroes"][0]["hp"] == 0
		and tales["heroes"][0]["lost"] == true and tales["heroes"][2]["fray"] == 5,
		"Tell Tales still unravels 25 FRAY and keeps the lost doll lost")
	# Mend stays available when even one non-lost doll can recover, Hanging included.
	var hanging_party := _lost_party([0, 30, 0, 48], [0])
	var hanging_visit := RunCampfireVisit.new("camp_hang", hanging_party, "stitched", 100)
	_check(hanging_visit.read_state()["quote"]["choices"] == ["mend", "leave"],
		"a Hanging non-lost doll keeps Mend available beside a lost doll")
	var hanging := hanging_visit.select("mend", "camp_hang", hanging_party, 100)
	_check(hanging.get("ok") == true and hanging["heroes"][0]["hp"] == 0
		and hanging["heroes"][0]["lost"] == true and hanging["heroes"][2]["hp"] == 7,
		"Hanging doll is mended to 7 while the lost doll stays at 0")
	# Satchel-opened visits share the same rule.
	var swap_party := _swap_party()
	for hero in swap_party:
		hero["hp"] = hero["max_hp"]
		hero["fray"] = 0
	swap_party[0]["hp"] = 0
	swap_party[0]["lost"] = true
	var swap_visit := RunCampfireVisit.open_stitched_with_satchel("camp_lost_s", swap_party, 100,
		_swap_satchel(), _swap_catalog())
	_check(swap_visit.read_state().get("ok") == true
		and swap_visit.read_state()["quote"]["choices"] == ["leave"],
		"satchel visit with only a lost deficit quotes no Mend")


const ARMS_SHIELD := "warden_arms_shield_catch"
const ARMS_RIVET:= "warden_arms_rivet_pummel"
const HEAD_POT := "warden_head_pot_helm_bonk"
const HEAD_RATTLE := "warden_head_helmet_rattle"
const TORSO_IRON := "warden_torso_iron_challenge"
const TORSO_BUCKLE := "warden_torso_buckle_rebound"
const LEGS_RIM := "warden_legs_rim_toss"
const LEGS_SHIELD := "warden_legs_shield_toss"
const SWAP_NODE := "camp_sw"


func _worn(part_id: String, tier: int, torn: bool = false) -> Dictionary:
	return {"id": part_id, "tier": tier, "torn": torn}


func _spare(part_id: String, tier: int, slot: String) -> Dictionary:
	return {"id": part_id, "tier": tier, "torn": false, "slot": slot}


## Four authentic identities with complete worn slot records. The rank-4
## golem wears a torn tier-III arm so the torn-removal refusal is reachable.
func _swap_party() -> Array:
	var party := _stitched_party([35, 18, 0, 48], [30, 25, 10, 200])
	var wear: Array = [
		{"head": _worn(HEAD_POT, 1), "arms": _worn(ARMS_SHIELD, 1),
			"torso": _worn(TORSO_IRON, 1), "legs": _worn(LEGS_RIM, 1)},
		{"head": _worn(HEAD_RATTLE, 2), "arms": _worn(ARMS_RIVET, 1),
			"torso": _worn(TORSO_BUCKLE, 1), "legs": _worn(LEGS_SHIELD, 2)},
		{"head": _worn(HEAD_POT, 3), "arms": _worn(ARMS_SHIELD, 2),
			"torso": _worn(TORSO_IRON, 2), "legs": _worn(LEGS_RIM, 3)},
		{"head": _worn(HEAD_RATTLE, 1), "arms": _worn(ARMS_RIVET, 3, true),
			"torso": _worn(TORSO_BUCKLE, 3), "legs": _worn(LEGS_SHIELD, 1)},
	]
	for i in range(4):
		party[i]["parts"] = wear[i]
	return party


func _swap_satchel() -> Array:
	return [_spare(ARMS_RIVET, 2, "arms"), _spare(HEAD_RATTLE, 3, "head"),
		_spare(LEGS_SHIELD, 1, "legs")]


func _swap_catalog() -> Dictionary:
	var loaded := StitchedParts.load_catalog("res://data/parts/warden_parts.json")
	if loaded.get("ok") != true:
		return {}
	return loaded["by_id"]


func _swap_visit(node: String = SWAP_NODE, candle: int = 40) -> RunCampfireVisit:
	return RunCampfireVisit.open_stitched_with_satchel(node, _swap_party(), candle,
		_swap_satchel(), _swap_catalog())


func _test_swap_admission_and_quote() -> void:
	var catalog := _swap_catalog()
	_check(not catalog.is_empty(), "authentic Warden catalog loads through StitchedParts")
	for needed in [ARMS_SHIELD, ARMS_RIVET, HEAD_POT, HEAD_RATTLE, TORSO_IRON, TORSO_BUCKLE,
			LEGS_RIM, LEGS_SHIELD]:
		_check(catalog.has(needed), "catalog carries named part " + needed)
	var invalid_state := {"ok": false, "node_id": "", "status": "invalid", "heroes": []}
	var visit := _swap_visit()
	var state := visit.read_state()
	_check(state.get("ok") == true and state.get("status") == "stitched_open"
		and state.get("mode") == "stitched" and state.get("candle") == 40
		and state.get("satchel") == _swap_satchel(),
		"opt-in visit opens with four heroes, candle and the full satchel")
	_check(state.get("quote", {}).get("choices") == ["mend", "tell_tales", "trim_the_wick", "leave"],
		"opt-in visit keeps exactly the four ordinary choices")
	var quote: Dictionary = state.get("swap_quote", {})
	_check(quote.get("ok") == true and quote.get("open") == true
		and quote.get("satchel_count") == 3 and quote.get("satchel_max") == 6
		and quote.get("heroes", []).size() == 4,
		"opt-in visit exposes a part-swap quote for four heroes")
	_check(visit.swap_quote() == quote, "swap_quote matches read_state's quote")
	var warden_slots: Array = quote["heroes"][0]["slots"]
	var by_slot: Dictionary = {}
	for entry in warden_slots:
		by_slot[entry["slot"]] = entry
	_check(by_slot["arms"]["can_swap"] == true and by_slot["arms"]["offers"].size() == 1
		and by_slot["arms"]["offers"][0]["satchel_index"] == 0
		and by_slot["arms"]["offers"][0]["part"]["id"] == ARMS_RIVET
		and by_slot["arms"]["offers"][0]["part"]["tier"] == 2,
		"arms slot offers only the tier-II Rivet Pummel spare")
	_check(by_slot["head"]["offers"].size() == 1
		and by_slot["head"]["offers"][0]["part"]["id"] == HEAD_RATTLE
		and by_slot["legs"]["offers"][0]["part"]["id"] == LEGS_SHIELD
		and by_slot["torso"]["can_swap"] == false and by_slot["torso"]["offers"].is_empty(),
		"only same-slot spares are offered; torso has none")
	var golem_arms: Dictionary = {}
	for entry in quote["heroes"][3]["slots"]:
		if entry["slot"] == "arms":
			golem_arms = entry
	_check(golem_arms.get("can_swap") == false and golem_arms.get("offers") == []
		and str(golem_arms.get("blocked")).find("torn") != -1,
		"torn worn arm is quoted as blocked")
	# Ordinary Stitched without the opt-in keeps its exact shape.
	var plain := RunCampfireVisit.new("camp_plain", _stitched_party([35, 18, 0, 48],
		[30, 25, 10, 200]), "stitched", 40)
	var plain_state := plain.read_state()
	_check(plain_state.get("quote", {}).get("choices") == ["mend", "tell_tales", "trim_the_wick", "leave"]
		and not plain_state.has("satchel") and not plain_state.has("swap_quote")
		and not plain_state.has("swap_state") and plain.swap_quote() == {},
		"non-opt-in Stitched quote and state shape are unchanged")
	# Fail-closed opt-in admissions.
	var cases: Array = []
	var missing_slot := _swap_party()
	missing_slot[2]["parts"].erase("arms")
	cases.append(["missing slot", missing_slot, 40, _swap_satchel(), catalog])
	var no_parts := _swap_party()
	no_parts[1].erase("parts")
	cases.append(["missing parts dictionary", no_parts, 40, _swap_satchel(), catalog])
	var wrong_slot := _swap_party()
	wrong_slot[0]["parts"]["arms"] = _worn(HEAD_POT, 1)
	cases.append(["wrong slot", wrong_slot, 40, _swap_satchel(), catalog])
	var unknown_part := _swap_party()
	unknown_part[0]["parts"]["legs"] = _worn("warden_legs_not_real", 1)
	cases.append(["nonexistent part", unknown_part, 40, _swap_satchel(), catalog])
	for bad_tier in [0, 4, 1.5, "1", null]:
		var tiered := _swap_party()
		tiered[3]["parts"]["head"]["tier"] = bad_tier
		cases.append(["invalid tier " + str(bad_tier), tiered, 40, _swap_satchel(), catalog])
	var non_bool_torn := _swap_party()
	non_bool_torn[0]["parts"]["head"]["torn"] = "no"
	cases.append(["malformed torn flag", non_bool_torn, 40, _swap_satchel(), catalog])
	var duplicate_hero := _swap_party()
	duplicate_hero[3]["id"] = "warden"
	cases.append(["duplicate hero", duplicate_hero, 40, _swap_satchel(), catalog])
	for bad_candle in [-1, 101, 1.5, "40", null]:
		cases.append(["malformed candle " + str(bad_candle), _swap_party(), bad_candle,
			_swap_satchel(), catalog])
	var seven: Array = []
	for i in range(7):
		seven.append(_spare(ARMS_RIVET, 1, "arms"))
	cases.append(["satchel of seven", _swap_party(), 40, seven, catalog])
	var six: Array = seven.slice(0, 6)
	var bad_spare_slot := _swap_satchel()
	bad_spare_slot[0]["slot"] = "head"
	cases.append(["spare slot disagrees with part", _swap_party(), 40, bad_spare_slot, catalog])
	var bad_spare_tier := _swap_satchel()
	bad_spare_tier[1]["tier"] = 9
	cases.append(["spare invalid tier", _swap_party(), 40, bad_spare_tier, catalog])
	cases.append(["satchel not an array", _swap_party(), 40, null, catalog])
	cases.append(["catalog missing", _swap_party(), 40, _swap_satchel(), {}])
	cases.append(["three heroes", _swap_party().slice(0, 3), 40, _swap_satchel(), catalog])
	for case in cases:
		var input_heroes: Variant = case[1]
		var before: Variant = input_heroes.duplicate(true) if typeof(input_heroes) == TYPE_ARRAY else input_heroes
		var rejected := RunCampfireVisit.open_stitched_with_satchel(SWAP_NODE, case[1], case[2],
			case[3], case[4])
		_check(rejected.read_state() == invalid_state, "opt-in admission refuses: " + case[0])
		_check(rejected.swap_part("warden", "arms", 0, SWAP_NODE, {})
			== {"ok": false, "error": "no open part-swap opportunity"},
			"refused opt-in visit cannot swap: " + case[0])
		_check(input_heroes == before, "refused opt-in input untouched: " + case[0])
	_check(RunCampfireVisit.open_stitched_with_satchel(" ", _swap_party(), 40, _swap_satchel(),
		catalog).read_state() == invalid_state, "malformed node refused for opt-in")
	_check(RunCampfireVisit.open_stitched_with_satchel(SWAP_NODE, _swap_party(), 40, six,
		catalog).read_state().get("ok") == true, "a full satchel of six is admitted")
	_check(RunCampfireVisit.open_stitched_with_satchel(SWAP_NODE, _swap_party(), 40, [],
		catalog).read_state().get("ok") == true, "an empty satchel is admitted")


func _assert_swap_refused(visit: RunCampfireVisit, hero: Variant, slot: Variant,
		index: Variant, node: Variant, expected: Variant, label: String) -> void:
	var before := visit.read_state()
	var result: Dictionary = visit.swap_part(hero, slot, index, node, expected)
	_check(result.get("ok") == false and not result.has("heroes") and not result.has("satchel")
		and not str(result.get("error", "")).is_empty(), label + ": typed swap refusal")
	_check(visit.read_state() == before, label + ": refused swap changes nothing")


func _test_swap_exchanges_and_decisions() -> void:
	var base := _swap_party()
	var visit := _swap_visit()
	var state0 := visit.read_state()
	var swap_state0: Dictionary = state0["swap_state"]
	var first := visit.swap_part("warden", "arms", 0, SWAP_NODE, swap_state0)
	_check(first.get("ok") == true and first.get("action") == "swap"
		and first.get("node_id") == SWAP_NODE and first.get("hero_id") == "warden"
		and first.get("slot") == "arms" and first.get("satchel_index") == 0,
		"first exchange commits and names hero, slot and index")
	_check(first.get("worn_before") == _worn(ARMS_SHIELD, 1)
		and first.get("worn_after") == _worn(ARMS_RIVET, 2)
		and first.get("satchel_before") == _spare(ARMS_RIVET, 2, "arms")
		and first.get("satchel_after") == _spare(ARMS_SHIELD, 1, "arms"),
		"both item instances keep their ids and tiers across the exchange")
	var expected_heroes := base.duplicate(true)
	expected_heroes[0]["parts"]["arms"] = _worn(ARMS_RIVET, 2)
	var expected_satchel := _swap_satchel()
	expected_satchel[0] = _spare(ARMS_SHIELD, 1, "arms")
	_check(first.get("heroes") == expected_heroes and first.get("satchel") == expected_satchel
		and first.get("candle") == 40 and expected_satchel.size() == 3,
		"only the arms record and the satchel slot changed; satchel size conserved")
	var after1 := visit.read_state()
	_check(after1.get("heroes") == expected_heroes and after1.get("satchel") == expected_satchel
		and after1.get("status") == "stitched_open" and after1.get("candle") == 40
		and after1.get("swap_state") == first.get("swap_state"),
		"held Campfire snapshot reconciles the committed swap and stays open")
	for i in range(4):
		for field in ["hp", "max_hp", "fray", "block", "statuses", "metadata", "position", "passive", "id"]:
			_check(after1["heroes"][i].get(field) == base[i].get(field),
				"swap leaves hero %d field %s alone" % [i, field])
	_assert_swap_refused(visit, "warden", "arms", 0, SWAP_NODE, swap_state0,
		"replay of the previous swap state")
	var second := visit.swap_part("warden", "head", 1, SWAP_NODE, first["swap_state"])
	_check(second.get("ok") == true and second.get("worn_before") == _worn(HEAD_POT, 1)
		and second.get("worn_after") == _worn(HEAD_RATTLE, 3)
		and second.get("satchel_after") == _spare(HEAD_POT, 1, "head"),
		"second exchange works from the fresh snapshot (head)")
	expected_heroes[0]["parts"]["head"] = _worn(HEAD_RATTLE, 3)
	expected_satchel[1] = _spare(HEAD_POT, 1, "head")
	_check(visit.read_state().get("heroes") == expected_heroes
		and visit.read_state().get("satchel") == expected_satchel,
		"two exchanges accumulate in the held snapshot")
	_assert_swap_refused(visit, "warden", "head", 1, SWAP_NODE, first["swap_state"],
		"stale second-swap replay")
	# A complete latest Campfire state is also an accepted expectation.
	var third := visit.swap_part("warden", "arms", 0, SWAP_NODE, visit.read_state())
	_check(third.get("ok") == true and third.get("worn_after") == _worn(ARMS_SHIELD, 1)
		and third.get("satchel_after") == _spare(ARMS_RIVET, 2, "arms"),
		"a full latest read_state also authorises a swap, returning the parts")
	expected_heroes[0]["parts"]["arms"] = _worn(ARMS_SHIELD, 1)
	expected_satchel[0] = _spare(ARMS_RIVET, 2, "arms")
	# One recovery choice, then published receipt and closed swaps.
	var latest := visit.read_state()
	_check(latest.get("heroes") == expected_heroes and latest.get("satchel") == expected_satchel,
		"third exchange restores the arms with the satchel reconciled")
	var tales := visit.select("tell_tales", SWAP_NODE, latest["heroes"], 40)
	var tales_expected := expected_heroes.duplicate(true)
	for hero in tales_expected:
		hero["fray"] = maxi(0, int(hero["fray"]) - 25)
	_check(tales.get("ok") == true and tales.get("decision") == "tell_tales"
		and tales.get("candle") == 40 and tales.get("heroes") == tales_expected
		and tales.get("satchel") == expected_satchel,
		"Tell Tales removes 25 FRAY each and the receipt carries the latest satchel and gear")
	for i in range(4):
		_check(tales["heroes"][i]["hp"] == base[i]["hp"]
			and tales["heroes"][i]["parts"] == expected_heroes[i]["parts"],
			"Tell Tales keeps hero %d HP and equipment" % i)
	_check(visit.read_state().get("status") == "stitched_decided"
		and visit.read_state().get("swap_quote", {}).get("open") == false,
		"the decision closes the swap opportunity")
	var closed_state := visit.read_state()
	_assert_swap_refused(visit, "warden", "head", 1, SWAP_NODE, closed_state["swap_state"],
		"swap after the decision")
	_assert_swap_refused(visit, "warden", "head", 1, SWAP_NODE, closed_state,
		"swap after the decision with the full state")
	_assert_stitched_refused(visit, "mend", SWAP_NODE, tales["heroes"], 40, "second action after Tell Tales")
	_check(tales["satchel"] == expected_satchel and visit.read_state().get("satchel") == expected_satchel,
		"receipt satchel stays the committed one")
	tales["satchel"][0]["tier"] = 3
	tales["heroes"][0]["parts"]["arms"]["tier"] = 3
	_check(visit.read_state().get("satchel") == expected_satchel
		and visit.read_state().get("heroes")[0]["parts"]["arms"]["tier"] == 1,
		"returned receipt never aliases held equipment")
	# Mend with equipment kept.
	var mend_visit := _swap_visit("camp_swm")
	var mend_swap := mend_visit.swap_part("seamstress", "legs", 2, "camp_swm",
		mend_visit.read_state()["swap_state"])
	_check(mend_swap.get("ok") == true and mend_swap.get("worn_after") == _worn(LEGS_SHIELD, 1)
		and mend_swap.get("worn_before") == _worn(LEGS_SHIELD, 2),
		"same part id can swap tiers within a slot")
	var mend_latest := mend_visit.read_state()
	var mend := mend_visit.select("mend", "camp_swm", mend_latest["heroes"], 40)
	_check(mend.get("ok") == true and mend["heroes"][0]["hp"] == 40 and mend["heroes"][1]["hp"] == 27
		and mend["heroes"][2]["hp"] == 7 and mend["heroes"][3]["hp"] == 48
		and mend["candle"] == 40,
		"Mend still heals floor(30%) in an opted-in visit")
	for i in range(4):
		_check(mend["heroes"][i]["parts"] == mend_latest["heroes"][i]["parts"]
			and mend["heroes"][i]["fray"] == base[i]["fray"],
			"Mend keeps hero %d equipment and fray" % i)
	_check(mend.get("satchel") == mend_latest["satchel"]
		and mend["satchel"][2] == _spare(LEGS_SHIELD, 2, "legs"),
		"Mend receipt carries the swapped satchel")
	# Trim the Wick with equipment kept.
	var wick_visit := _swap_visit("camp_swt", 60)
	var wick_swap := wick_visit.swap_part("tinker", "head", 1, "camp_swt",
		wick_visit.read_state()["swap_state"])
	_check(wick_swap.get("ok") == true, "swap precedes Trim the Wick")
	var wick_latest := wick_visit.read_state()
	var wick := wick_visit.select("trim_the_wick", "camp_swt", wick_latest["heroes"], 60)
	_check(wick.get("ok") == true and wick.get("candle") == 100
		and wick.get("heroes") == wick_latest["heroes"] and wick.get("satchel") == wick_latest["satchel"],
		"Trim the Wick caps candle and loses no equipment")
	# Leave with and without a swap.
	var leave_visit := _swap_visit("camp_swl")
	var leave_before := leave_visit.read_state()
	var leave := leave_visit.select("leave", "camp_swl", leave_before["heroes"], 40)
	_check(leave.get("ok") == true and leave.get("heroes") == base and leave.get("candle") == 40
		and leave.get("satchel") == _swap_satchel(),
		"Leave without a swap returns the unchanged gear and satchel")
	_assert_swap_refused(leave_visit, "warden", "arms", 0, "camp_swl",
		leave_visit.read_state()["swap_state"], "swap after Leave")


func _test_swap_refusals_and_isolation() -> void:
	var visit := _swap_visit()
	var state := visit.read_state()
	var swap_state: Dictionary = state["swap_state"]
	_assert_swap_refused(visit, "warden", "head", 0, SWAP_NODE, swap_state, "wrong slot spare")
	_assert_swap_refused(visit, "warden", "torso", 0, SWAP_NODE, swap_state, "slot without a spare")
	_assert_swap_refused(visit, "nobody", "arms", 0, SWAP_NODE, swap_state, "unknown hero")
	_assert_swap_refused(visit, 7, "arms", 0, SWAP_NODE, swap_state, "non-string hero")
	_assert_swap_refused(visit, "warden", "wings", 0, SWAP_NODE, swap_state, "unknown slot")
	_assert_swap_refused(visit, "warden", null, 0, SWAP_NODE, swap_state, "missing slot")
	for bad_index in [-1, 3, 99, "0", 0.0, null]:
		_assert_swap_refused(visit, "warden", "arms", bad_index, SWAP_NODE, swap_state,
			"invalid spare index " + str(bad_index))
	_assert_swap_refused(visit, "button_golem", "arms", 0, SWAP_NODE, swap_state,
		"torn worn arm cannot be swapped out")
	for bad_node in ["other", "", " camp_sw", "camp_sw ", 42, null]:
		_assert_swap_refused(visit, "warden", "arms", 0, bad_node, swap_state,
			"forged node " + str(bad_node))
	var forged := swap_state.duplicate(true)
	forged["heroes"][0]["parts"]["arms"]["tier"] = 3
	_assert_swap_refused(visit, "warden", "arms", 0, SWAP_NODE, forged, "forged swap state")
	var forged_full := visit.read_state()
	forged_full["heroes"][0]["hp"] = 1
	_assert_swap_refused(visit, "warden", "arms", 0, SWAP_NODE, forged_full, "forged full state")
	var stale_full := visit.read_state()
	stale_full["candle"] = 41
	_assert_swap_refused(visit, "warden", "arms", 0, SWAP_NODE, stale_full, "stale candle in full state")
	for bad_state in [null, "state", 5, [], {}]:
		_assert_swap_refused(visit, "warden", "arms", 0, SWAP_NODE, bad_state,
			"malformed expected state " + str(bad_state))
	_check(visit.read_state() == state and visit.read_state().get("status") == "stitched_open",
		"all refusals left the visit and its single decision intact")
	var retry := visit.swap_part("warden", "arms", 0, SWAP_NODE, swap_state)
	_check(retry.get("ok") == true and retry.get("worn_after") == _worn(ARMS_RIVET, 2),
		"a valid swap succeeds after every refusal")
	var duplicate := visit.swap_part("warden", "arms", 0, SWAP_NODE, swap_state)
	_check(duplicate.get("ok") == false, "the same request cannot be replayed")
	var decision := visit.select("leave", SWAP_NODE, visit.read_state()["heroes"], 40)
	_check(decision.get("ok") == true, "the main decision is still available after refusals and a swap")
	_assert_swap_refused(visit, "warden", "head", 1, SWAP_NODE, visit.read_state()["swap_state"],
		"swap attempt after Leave")
	# Legacy and non-opt-in visits reject the swap method untouched.
	var legacy := RunCampfireVisit.new("camp_legacy", _party([35, 18, 0]))
	var legacy_before := legacy.read_state()
	var legacy_result: Dictionary = legacy.swap_part("warden", "arms", 0, "camp_legacy", legacy_before)
	_check(legacy_result.get("ok") == false and legacy.read_state() == legacy_before
		and legacy_before == {"ok": true, "node_id": "camp_legacy", "status": "open",
			"heroes": _party([35, 18, 0])},
		"legacy three-hero visit rejects swaps and keeps its old state shape")
	_check(legacy.choose_heal("camp_legacy", _party([35, 18, 0])).get("ok") == true,
		"legacy visit still heals after a refused swap")
	var plain := RunCampfireVisit.new("camp_plain", _swap_party(), "stitched", 40)
	var plain_before := plain.read_state()
	for expected in [{}, plain_before, plain_before.get("heroes")]:
		var plain_result: Dictionary = plain.swap_part("warden", "arms", 0, "camp_plain", expected)
		_check(plain_result.get("ok") == false and plain.read_state() == plain_before,
			"non-opt-in Stitched visit rejects swaps untouched")
	var plain_receipt := plain.select("leave", "camp_plain", _swap_party(), 40)
	_check(plain_receipt == {"ok": true, "decision": "leave", "node_id": "camp_plain",
		"heroes": _swap_party(), "candle": 40},
		"non-opt-in Stitched receipt has no satchel key")
	# No RNG draw from quotes, valid exchanges or refusals.
	seed(55117)
	var expected_next := randi()
	seed(55117)
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 321
	var local_state := local_rng.state
	var rng_visit := _swap_visit("camp_swr")
	var rng_state := rng_visit.read_state()
	rng_visit.swap_quote()
	_assert_swap_refused(rng_visit, "warden", "head", 0, "camp_swr", rng_state["swap_state"],
		"rng refusal")
	var rng_swap := rng_visit.swap_part("warden", "legs", 2, "camp_swr", rng_state["swap_state"])
	_check(rng_swap.get("ok") == true, "rng fixture commits a real exchange")
	var rng_decision := rng_visit.select("mend", "camp_swr", rng_visit.read_state()["heroes"], 40)
	_check(rng_decision.get("ok") == true, "rng fixture commits a real decision")
	_check(randi() == expected_next, "swap quotes, exchanges and refusals draw no global RNG")
	_check(local_rng.state == local_state, "local RNG state does not move")


const FEAR_NODE := "camp_fear"
const FEAR_FRAYS: Array = [30, 25, 10, 200]


func _fear_visit(fear: Variant, frays: Array = FEAR_FRAYS, candle: int = 40,
		node: String = FEAR_NODE) -> RunCampfireVisit:
	return RunCampfireVisit.new(node, _stitched_party([35, 18, 0, 48], frays), "stitched",
		candle, fear)


func _assert_fear_refused(visit: RunCampfireVisit, decision: Variant, node: Variant,
		heroes: Variant, candle: Variant, fear: Variant, label: String) -> void:
	var before := visit.read_state()
	var result: Dictionary = visit.select(decision, node, heroes, candle, fear)
	_check(result == {"ok": false, "decision": "", "node_id": "", "heroes": [], "candle": 0},
		label + ": uniformly typed fear refusal, no forged receipt")
	_check(visit.read_state() == before, label + ": refusal does not consume or modify visit")


func _test_fear_admission_and_shape() -> void:
	var invalid_state := {"ok": false, "node_id": "", "status": "invalid", "heroes": []}
	var original := _stitched_party([35, 18, 0, 48], FEAR_FRAYS)
	for boundary in [0, 100]:
		var visit := _fear_visit(boundary)
		var state := visit.read_state()
		_check(state.get("ok") == true and state.get("status") == "stitched_open"
			and state.get("fear") == boundary and state.get("candle") == 40
			and state.get("heroes") == original
			and state.get("quote", {}).get("choices")
				== ["mend", "tell_tales", "trim_the_wick", "leave"],
			"boundary fear %d admits an open visit exposing its fear" % boundary)
		var swap_visit := RunCampfireVisit.open_stitched_with_satchel(SWAP_NODE, _swap_party(), 40,
			_swap_satchel(), _swap_catalog(), boundary)
		_check(swap_visit.read_state().get("ok") == true
			and swap_visit.read_state().get("fear") == boundary
			and swap_visit.read_state().get("satchel") == _swap_satchel(),
			"boundary fear %d admits the satchel visit" % boundary)
	for bad_fear in [-1, 101, 1.5, "50", true, 50.0, [], {}]:
		var rejected := _fear_visit(bad_fear)
		_check(rejected.read_state() == invalid_state,
			"invalid fear never admits a stitched visit: " + str(bad_fear))
		_assert_fear_refused(rejected, "leave", FEAR_NODE, original, 40, 50,
			"invalid fear stays inert " + str(bad_fear))
		var rejected_swap := RunCampfireVisit.open_stitched_with_satchel(SWAP_NODE, _swap_party(),
			40, _swap_satchel(), _swap_catalog(), bad_fear)
		_check(rejected_swap.read_state() == invalid_state,
			"invalid fear never admits a satchel visit: " + str(bad_fear))
		_check(rejected_swap.swap_part("warden", "arms", 0, SWAP_NODE, {})
			== {"ok": false, "error": "no open part-swap opportunity"},
			"invalid-fear satchel visit cannot swap: " + str(bad_fear))
	# A fear input is meaningless for the legacy three-hero service.
	_check(RunCampfireVisit.new("camp", _party([35, 18, 0]), null, null, 50).read_state()
		== invalid_state, "legacy three-hero visit refuses a fear input")
	# Without fear nothing about the public shape changes.
	var plain := _fear_visit(null)
	_check(not plain.read_state().has("fear"), "absent fear adds no fear key to read_state")
	var plain_receipt := plain.select("tell_tales", FEAR_NODE, original, 40)
	_check(plain_receipt.get("ok") == true and not plain_receipt.has("fear")
		and not plain.read_state().has("fear"),
		"absent fear adds no fear key to a receipt or decided state")
	var plain_swap := _swap_visit()
	var plain_swap_result := plain_swap.swap_part("warden", "arms", 0, SWAP_NODE,
		plain_swap.read_state()["swap_state"])
	_check(plain_swap_result.get("ok") == true and not plain_swap_result.has("fear")
		and not plain_swap.read_state().has("fear"),
		"absent fear adds no fear key to satchel state or swap receipt")
	_check(plain.select("tell_tales", FEAR_NODE, original, 40, 60)
		== {"ok": false, "decision": "", "node_id": "", "heroes": [], "candle": 0},
		"a spent visit still refuses")
	var plain_open := _fear_visit(null)
	_assert_fear_refused(plain_open, "tell_tales", FEAR_NODE, original, 40, 60,
		"expected fear on a visit without fear")
	_assert_fear_refused(plain_open, "tell_tales", FEAR_NODE, original, 40, 0,
		"expected zero fear on a visit without fear")
	# Detached snapshots.
	var held := _fear_visit(60)
	var exposed := held.read_state()
	exposed["fear"] = 1
	_check(held.read_state()["fear"] == 60, "mutating a projected fear cannot alter the visit")
	var receipt := held.select("leave", FEAR_NODE, original, 40, 60)
	receipt["fear"] = 99
	_check(held.read_state()["fear"] == 60, "mutating a receipt fear cannot alter the visit")


func _test_fear_tell_tales() -> void:
	var original := _stitched_party([35, 18, 0, 48], FEAR_FRAYS)
	for pair in [[60, 45], [9, 0], [0, 0], [15, 0], [100, 85]]:
		var visit := _fear_visit(pair[0])
		_check(visit.read_state()["quote"]["choices"].has("tell_tales"),
			"Tell Tales is offered at fear %d" % pair[0])
		var receipt := visit.select("tell_tales", FEAR_NODE, original, 40, pair[0])
		_check(receipt.get("ok") == true and receipt.get("decision") == "tell_tales"
			and receipt.get("node_id") == FEAR_NODE and receipt.get("candle") == 40
			and receipt.get("fear") == pair[1],
			"Tell Tales fear %d -> %d in one receipt" % [pair[0], pair[1]])
		var expected := original.duplicate(true)
		for hero in expected:
			hero["fray"] = maxi(0, int(hero["fray"]) - 25)
		_check(receipt.get("heroes") == expected
			and [receipt["heroes"][0]["fray"], receipt["heroes"][1]["fray"],
				receipt["heroes"][2]["fray"], receipt["heroes"][3]["fray"]] == [5, 0, 0, 175],
			"fear %d: all four dolls lose exactly 25 FRAY, floored, nothing else changes" % pair[0])
		var decided := visit.read_state()
		_check(decided["status"] == "stitched_decided" and decided["fear"] == pair[1]
			and decided["heroes"] == expected and decided["candle"] == 40,
			"fear %d: decided state holds the soothed fear" % pair[0])
	# Fear alone makes Tell Tales worthwhile; neither FRAY nor fear does not.
	var calm := RunCampfireVisit.new(FEAR_NODE, _stitched_party(FULL_HPS, NO_FRAY), "stitched",
		100, 20)
	_check(calm.read_state()["quote"]["choices"] == ["tell_tales", "leave"],
		"fear above zero keeps Tell Tales offered with no FRAY")
	var calm_original := _stitched_party(FULL_HPS, NO_FRAY)
	var calm_receipt := calm.select("tell_tales", FEAR_NODE, _stitched_party(FULL_HPS, NO_FRAY),
		100, 20)
	_check(calm_receipt.get("ok") == true and calm_receipt.get("fear") == 5
		and calm_receipt.get("heroes") == calm_original,
		"Tell Tales at zero FRAY still soothes fear 20 to 5")
	var spent := RunCampfireVisit.new(FEAR_NODE, _stitched_party(FULL_HPS, NO_FRAY), "stitched",
		100, 0)
	_check(spent.read_state()["quote"]["choices"] == ["leave"],
		"no FRAY and no fear leaves only Leave")
	_assert_fear_refused(spent, "tell_tales", FEAR_NODE, _stitched_party(FULL_HPS, NO_FRAY), 100, 0,
		"no-op Tell Tales at zero fear")


func _test_fear_other_choices_and_swap() -> void:
	var original := _stitched_party([35, 18, 0, 48], FEAR_FRAYS)
	var mend := _fear_visit(60).select("mend", FEAR_NODE, original, 40, 60)
	_check(mend.get("ok") == true and mend.get("fear") == 60 and mend["heroes"][2]["hp"] == 7,
		"Mend keeps fear")
	var wick_visit := _fear_visit(60)
	var wick := wick_visit.select("trim_the_wick", FEAR_NODE, original, 40, 60)
	_check(wick.get("ok") == true and wick.get("fear") == 60 and wick.get("candle") == 90
		and wick.get("heroes") == original and wick_visit.read_state()["fear"] == 60,
		"Trim the Wick keeps fear")
	var leave_visit := _fear_visit(60)
	var leave := leave_visit.select("leave", FEAR_NODE, original, 40, 60)
	_check(leave.get("ok") == true and leave.get("fear") == 60 and leave.get("heroes") == original
		and leave_visit.read_state()["fear"] == 60,
		"Leave keeps fear")
	# Genuine satchel fixture: swap once, then Tell Tales.
	var visit := RunCampfireVisit.open_stitched_with_satchel(SWAP_NODE, _swap_party(), 40,
		_swap_satchel(), _swap_catalog(), 60)
	var opened := visit.read_state()
	_check(opened.get("ok") == true and opened.get("fear") == 60 and opened.get("satchel") == _swap_satchel()
		and opened["swap_quote"]["open"] == true,
		"satchel visit opens with fear and a real swap quote")
	var swap := visit.swap_part("warden", "arms", 0, SWAP_NODE, opened["swap_state"])
	_check(swap.get("ok") == true and swap.get("fear") == 60
		and swap.get("worn_after") == _worn(ARMS_RIVET, 2),
		"the swap commits and its receipt carries the unchanged fear")
	var latest := visit.read_state()
	_check(latest["fear"] == 60 and latest["heroes"][0]["parts"]["arms"] == _worn(ARMS_RIVET, 2)
		and latest["satchel"][0] == _spare(ARMS_SHIELD, 1, "arms"),
		"the held state keeps fear across the swap and reconciles gear")
	# Opening state (before the swap) is stale for a full-state swap request.
	_assert_swap_refused(visit, "warden", "head", 1, SWAP_NODE, opened,
		"stale pre-swap full state with fear")
	_assert_fear_refused(visit, "tell_tales", SWAP_NODE, latest["heroes"], 40, null,
		"swapped visit without expected fear")
	_assert_fear_refused(visit, "tell_tales", SWAP_NODE, latest["heroes"], 40, 59,
		"swapped visit with wrong fear")
	var tales := visit.select("tell_tales", SWAP_NODE, latest["heroes"], 40, 60)
	var expected: Array = latest["heroes"].duplicate(true)
	for hero in expected:
		hero["fray"] = maxi(0, int(hero["fray"]) - 25)
	_check(tales.get("ok") == true and tales.get("fear") == 45 and tales.get("heroes") == expected
		and tales.get("satchel") == latest["satchel"] and tales.get("candle") == 40
		and tales["heroes"][0]["parts"]["arms"] == _worn(ARMS_RIVET, 2),
		"Tell Tales after a swap soothes fear and preserves gear and satchel")
	_check(visit.read_state()["fear"] == 45 and visit.read_state()["swap_quote"]["open"] == false,
		"the decision closes the swap and holds the soothed fear")
	_assert_swap_refused(visit, "warden", "head", 1, SWAP_NODE, visit.read_state()["swap_state"],
		"swap after Tell Tales with fear")
	_assert_fear_refused(visit, "tell_tales", SWAP_NODE, tales["heroes"], 40, 45,
		"replay of Tell Tales with the new fear")
	_assert_fear_refused(visit, "tell_tales", SWAP_NODE, latest["heroes"], 40, 60,
		"replay of Tell Tales with the old snapshot")


func _test_fear_refusals_replay_and_rng() -> void:
	var original := _stitched_party([35, 18, 0, 48], FEAR_FRAYS)
	seed(626262)
	var expected_next := randi()
	seed(626262)
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 91
	var local_state := local_rng.state
	var visit := _fear_visit(60)
	for bad_fear in [null, 0, 59, 61, 100, -1, "60", 60.0, true, [], {}]:
		_assert_fear_refused(visit, "tell_tales", FEAR_NODE, original, 40, bad_fear,
			"missing, wrong or malformed expected fear " + str(bad_fear))
	_assert_fear_refused(visit, "tell_tales", "other", original, 40, 60, "wrong node with fear")
	_assert_fear_refused(visit, "tell_tales", null, original, 40, 60, "null node with fear")
	var stale_hero := original.duplicate(true)
	stale_hero[1]["fray"] += 1
	_assert_fear_refused(visit, "tell_tales", FEAR_NODE, stale_hero, 40, 60, "stale hero with fear")
	var forged_extra := original.duplicate(true)
	forged_extra[0]["unowned_currency"] = 999
	_assert_fear_refused(visit, "tell_tales", FEAR_NODE, forged_extra, 40, 60, "forged hero with fear")
	_assert_fear_refused(visit, "tell_tales", FEAR_NODE, original, 41, 60, "stale candle with fear")
	_assert_fear_refused(visit, "tell_tales", FEAR_NODE, original, "40", 60, "malformed candle with fear")
	_assert_fear_refused(visit, "heal", FEAR_NODE, original, 40, 60, "forged decision with fear")
	_check(visit.read_state()["status"] == "stitched_open" and visit.read_state()["fear"] == 60
		and visit.read_state()["heroes"] == original and visit.read_state()["candle"] == 40,
		"every refusal left the visit open with fear untouched")
	var receipt := visit.select("tell_tales", FEAR_NODE, original, 40, 60)
	_check(receipt.get("ok") == true and receipt.get("fear") == 45,
		"a legal Tell Tales still succeeds after every refusal")
	_assert_fear_refused(visit, "tell_tales", FEAR_NODE, receipt["heroes"], 40, 45, "duplicate Tell Tales")
	_assert_fear_refused(visit, "mend", FEAR_NODE, receipt["heroes"], 40, 45, "second decision")
	_assert_fear_refused(visit, "leave", FEAR_NODE, receipt["heroes"], 40, 45, "Leave after Tell Tales")
	# Two independent opted-in visits replay identically.
	var twin := _fear_visit(60)
	_check(twin.select("tell_tales", FEAR_NODE, original, 40, 60) == receipt
		and twin.read_state() == visit.read_state(),
		"independent opted-in visits replay the same receipt and state")
	# A refused action on a different node spends nothing either.
	var elsewhere := _fear_visit(60, FEAR_FRAYS, 40, "camp_else")
	_assert_fear_refused(elsewhere, "tell_tales", FEAR_NODE, original, 40, 60, "other visit's node")
	_check(elsewhere.read_state()["fear"] == 60 and elsewhere.read_state()["status"] == "stitched_open",
		"a refused foreign-node attempt leaves the visit open")
	_check(randi() == expected_next and local_rng.state == local_state,
		"fear admission, refusals and Tell Tales draw no RNG")


## Tell Tales ends a named Unravelled trait only when the reduced FRAY is
## strictly below 50; exactly 50 keeps it. Other resolve values never change.
func _test_tales_clears_unravelled_below_threshold() -> void:
	var traits: Array = StitchedS1BEffects.RESOLVE_TRAITS
	_check(traits.size() == 5 and traits.has("frantic") and traits.has("hollow")
		and traits.has("bitter") and traits.has("reckless") and traits.has("cowering"),
		"the five named Unravelled traits are the clear candidates")
	var frays: Array = [74, 75, 25, 100]
	var resolves: Array = ["frantic", "hollow", "bitter", "steadfast"]
	var source := _stitched_party([35, 18, 0, 48], frays)
	for i in range(4):
		source[i]["resolve"] = resolves[i]
	var original := source.duplicate(true)
	seed(313131)
	var expected_next := randi()
	seed(313131)
	var visit := RunCampfireVisit.new("camp_unr", source, "stitched", 40)
	var receipt := visit.select("tell_tales", "camp_unr", original, 40)
	_check(receipt.get("ok") == true and receipt.get("decision") == "tell_tales",
		"Unravelled fixture commits Tell Tales")
	var heroes: Array = receipt.get("heroes", [])
	_check(heroes.size() == 4, "receipt keeps four dolls")
	if heroes.size() != 4:
		return
	_check([heroes[0]["fray"], heroes[1]["fray"], heroes[2]["fray"], heroes[3]["fray"]]
		== [49, 50, 0, 75], "exactly -25 FRAY per doll with a floor of zero")
	_check(heroes[0]["resolve"] == "", "74 -> 49 clears Frantic")
	_check(heroes[1]["resolve"] == "hollow", "75 -> 50 keeps Hollow (exactly 50 does not clear)")
	_check(heroes[2]["resolve"] == "", "25 -> 0 clears Bitter")
	_check(heroes[3]["resolve"] == "steadfast", "100 -> 75 keeps Steadfast untouched")
	var expected := original.duplicate(true)
	expected[0]["fray"] = 49
	expected[0]["resolve"] = ""
	expected[1]["fray"] = 50
	expected[2]["fray"] = 0
	expected[2]["resolve"] = ""
	expected[3]["fray"] = 75
	_check(heroes == expected, "only FRAY and the eligible resolve fields change")
	var held := visit.read_state()
	_check(held["heroes"] == expected and held["status"] == "stitched_decided"
		and held["candle"] == 40, "read_state agrees with the receipt")
	_check(source == original, "caller-owned roster is not mutated")
	_check(randi() == expected_next, "Unravelled clearing draws no RNG")
	_assert_stitched_refused(visit, "tell_tales", "camp_unr", heroes, 40, "duplicate Tell Tales")
	# Every named trait clears at 49; a LOST doll stays LOST; missing/empty/unknown unchanged.
	for trait_name in traits:
		var one := _stitched_party(FULL_HPS, [74, 75, 80, 90])
		one[0]["resolve"] = trait_name
		var one_visit := RunCampfireVisit.new("camp_one", one, "stitched", 100)
		var one_receipt := one_visit.select("tell_tales", "camp_one", one, 100)
		_check(one_receipt.get("ok") == true and one_receipt["heroes"][0]["fray"] == 49
			and one_receipt["heroes"][0]["resolve"] == "",
			"%s clears at resulting FRAY 49" % trait_name)
	var mixed := _lost_party([0, 30, 26, 48], [0], [60, 70, 30, 40])
	mixed[0]["resolve"] = "cowering"
	mixed[1]["resolve"] = ""
	mixed[2]["resolve"] = "mystery"
	var mixed_before := mixed.duplicate(true)
	var mixed_visit := RunCampfireVisit.new("camp_mix", mixed, "stitched", 100)
	var mixed_receipt := mixed_visit.select("tell_tales", "camp_mix", mixed_before, 100)
	var mixed_heroes: Array = mixed_receipt.get("heroes", [])
	_check(mixed_receipt.get("ok") == true and mixed_heroes.size() == 4,
		"mixed LOST/empty/unknown/missing fixture commits")
	if mixed_heroes.size() == 4:
		_check(mixed_heroes[0]["lost"] == true and mixed_heroes[0]["hp"] == 0
			and mixed_heroes[0]["fray"] == 35 and mixed_heroes[0]["resolve"] == "",
			"a LOST doll stays LOST at 0 HP and FRAY 35, and its Cowering clears below 50")
		_check(mixed_heroes[1]["fray"] == 45 and mixed_heroes[1]["resolve"] == "",
			"empty resolve stays empty")
		_check(mixed_heroes[2]["fray"] == 5 and mixed_heroes[2]["resolve"] == "mystery",
			"unknown resolve is left unchanged")
		_check(mixed_heroes[3]["fray"] == 15 and not mixed_heroes[3].has("resolve"),
			"missing resolve is not invented")
	# A LOST doll below the threshold after Tales also clears its named trait.
	var lost_low := _lost_party([0, 30, 26, 48], [0], [60, 0, 0, 0])
	lost_low[0]["resolve"] = "reckless"
	lost_low[0]["fray"] = 74
	var lost_visit := RunCampfireVisit.new("camp_lowlost", lost_low, "stitched", 100)
	var lost_receipt := lost_visit.select("tell_tales", "camp_lowlost", lost_low, 100)
	_check(lost_receipt.get("ok") == true and lost_receipt["heroes"][0]["lost"] == true
		and lost_receipt["heroes"][0]["hp"] == 0 and lost_receipt["heroes"][0]["fray"] == 49
		and lost_receipt["heroes"][0]["resolve"] == "",
		"a LOST doll is not revived but its FRAY drop still clears the trait")
	# Optional Wren FEAR: -15 alongside the same FRAY/resolve rule.
	var fear_party := _stitched_party([35, 18, 0, 48], [74, 75, 25, 100])
	fear_party[0]["resolve"] = "frantic"
	fear_party[1]["resolve"] = "hollow"
	var fear_before := fear_party.duplicate(true)
	var fear_visit := RunCampfireVisit.new("camp_unr_fear", fear_party, "stitched", 40, 60)
	var fear_receipt := fear_visit.select("tell_tales", "camp_unr_fear", fear_before, 40, 60)
	_check(fear_receipt.get("ok") == true and fear_receipt.get("fear") == 45
		and fear_receipt["heroes"][0]["resolve"] == "" and fear_receipt["heroes"][0]["fray"] == 49
		and fear_receipt["heroes"][1]["resolve"] == "hollow"
		and fear_receipt["heroes"][1]["fray"] == 50,
		"Wren FEAR 60 -> 45 beside Unravelled clear at 49 and keep at 50")
	_check(fear_visit.read_state()["fear"] == 45
		and fear_visit.read_state()["heroes"] == fear_receipt["heroes"],
		"read_state holds the soothed FEAR and the cleared resolve")
