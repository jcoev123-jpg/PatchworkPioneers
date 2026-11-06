extends SceneTree
## Deterministic headless checks for S6 dark claw candle gate (AC1, AC2, AC3).

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_ac1_in_memory_gate_and_boundaries()
	_test_ac2_real_data_frayed_debt_parcel()
	_test_ac3_malformed_candle_bands_and_invariants()
	_finish()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("stitched_s6_dark_claw_gate_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("stitched_s6_dark_claw_gate_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _entry(preview_res: Dictionary, choice_id: String) -> Dictionary:
	for c in preview_res.get("choices", []):
		if c is Dictionary and c.get("choice_id") == choice_id:
			return c
	return {}


func _four_snapshot(candle: int, frays: Array = [10, 20, 30, 40]) -> Dictionary:
	var hero_ids := ["warden", "seamstress", "tinker", "button_golem"]
	var party: Array = []
	for i in range(hero_ids.size()):
		party.append({"id": hero_ids[i], "fray": frays[i]})
	return {
		"candle": candle,
		"party": party,
		"scraps": 10,
		"gold": 25,
		"satchel_count": 2,
	}


func _test_ac1_in_memory_gate_and_boundaries() -> void:
	var event := {
		"id": "ev_in_memory_dark_claw",
		"title": "Dark Bargain",
		"description": "A shadow deal offered in low candlelight.",
		"choices": [
			{
				"id": "dark_claw",
				"text": "Dark claw bargain.",
				"stitched_effect": {
					"target": "party",
					"candle": 0,
					"fray": 25,
					"required_candle_bands": ["dark", "snuffed"],
				},
			},
			{
				"id": "leave",
				"text": "Leave safely.",
				"stitched_effect": {
					"target": "party",
					"candle": 0,
					"fray": 0,
				},
			},
		],
	}

	var boundary_candles := [0, 1, 25, 26, 50, 51, 75, 76, 100]
	for c in boundary_candles:
		var is_dark_or_snuffed: bool = (c <= 25)
		var snap := _four_snapshot(c)
		var svc := RunStitchedEventConsequence.new(event)
		var prev := svc.preview(snap)
		_check(prev.get("ok") == true, "AC1: preview ok for candle %d" % c)
		var claw_entry := _entry(prev, "dark_claw")
		var leave_entry := _entry(prev, "leave")
		_check(leave_entry.get("available") == true, "AC1: leave always available at candle %d" % c)

		if is_dark_or_snuffed:
			_check(claw_entry.get("available") == true,
				"AC1: dark_claw available at candle %d" % c)
			_check(claw_entry.get("candle") == c,
				"AC1: projected candle matches base candle %d" % c)
			_check(claw_entry.get("fray") == {"warden": 25, "seamstress": 25, "tinker": 25, "button_golem": 25},
				"AC1: projected fray +25 per hero at candle %d" % c)

			# Parity with choose()
			var rec := svc.choose("dark_claw", snap)
			_check(rec.get("ok") == true, "AC1: choose(dark_claw) succeeds at candle %d" % c)
			_check(rec.get("candle") == claw_entry.get("candle"),
				"AC1: receipt candle matches preview at candle %d" % c)
			_check(rec.get("fray") == claw_entry.get("fray"),
				"AC1: receipt fray matches preview at candle %d" % c)
			_check(svc.is_claimed() == true, "AC1: visit claimed after success at candle %d" % c)
		else:
			_check(claw_entry.get("available") == false,
				"AC1: dark_claw unavailable at candle %d" % c)
			_check(claw_entry.get("candle") == c,
				"AC1: projected candle unchanged at candle %d" % c)
			_check(claw_entry.get("fray") == {},
				"AC1: projected fray empty when unavailable at candle %d" % c)

			# Parity with choose()
			var snap_before := snap.duplicate(true)
			var rec := svc.choose("dark_claw", snap)
			_check(rec.get("ok") == false, "AC1: choose(dark_claw) rejected at candle %d" % c)
			_check(rec.get("candle") == c, "AC1: rejection returns base candle %d" % c)
			_check(rec.get("fray") == {}, "AC1: rejection returns empty fray at candle %d" % c)
			_check(svc.is_claimed() == false and svc.is_valid() == true,
				"AC1: refusal does not consume visit at candle %d" % c)
			_check(snap == snap_before, "AC1: snapshot untouched by rejection at candle %d" % c)

			# Alternative choice remains claimable
			var leave_rec := svc.choose("leave", snap)
			_check(leave_rec.get("ok") == true, "AC1: leave succeeds after dark_claw rejection at candle %d" % c)
			_check(svc.is_claimed() == true, "AC1: visit claimed by alternative choice at candle %d" % c)

	# Backward compatibility fixture with singular required_candle_band
	var singular_event := {
		"id": "ev_singular_band",
		"title": "Singular Band Gate",
		"description": "Singular band gate fixture.",
		"choices": [
			{
				"id": "bright_only",
				"text": "Bright only.",
				"stitched_effect": {
					"target": "party",
					"candle": 0,
					"fray": -10,
					"required_candle_band": "bright",
				},
			},
			{
				"id": "leave",
				"text": "Leave.",
				"stitched_effect": {
					"target": "party",
					"candle": 0,
					"fray": 0,
				},
			},
		],
	}
	var svc_singular_bright := RunStitchedEventConsequence.new(singular_event)
	var prev_sing_100 := svc_singular_bright.preview(_four_snapshot(100))
	_check(_entry(prev_sing_100, "bright_only").get("available") == true,
		"AC1: backward compatibility singular required_candle_band available in bright")
	var rec_sing_100 := svc_singular_bright.choose("bright_only", _four_snapshot(100))
	_check(rec_sing_100.get("ok") == true,
		"AC1: backward compatibility singular required_candle_band claims in bright")

	var svc_singular_dark := RunStitchedEventConsequence.new(singular_event)
	var prev_sing_25 := svc_singular_dark.preview(_four_snapshot(25))
	_check(_entry(prev_sing_25, "bright_only").get("available") == false,
		"AC1: backward compatibility singular required_candle_band unavailable outside bright")
	var rec_sing_25 := svc_singular_dark.choose("bright_only", _four_snapshot(25))
	_check(rec_sing_25.get("ok") == false,
		"AC1: backward compatibility singular required_candle_band rejects outside bright")


func _test_ac2_real_data_frayed_debt_parcel() -> void:
	var path := "res://data/events/stitched_route_effects.json"
	_check(FileAccess.file_exists(path), "AC2: stitched_route_effects.json exists")
	var source := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(source)
	_check(parsed is Dictionary and (parsed as Dictionary).has("events"),
		"AC2: successfully parsed stitched_route_effects.json as dictionary with events")
	var events: Array = (parsed as Dictionary).get("events", [])

	# Select frayed_debt_parcel by ID (never hardcoded index or asserted total)
	var parcel_record: Dictionary = {}
	var seen_ids: Dictionary = {}
	for ev in events:
		if ev is Dictionary:
			var ev_id: String = ev.get("id", "")
			seen_ids[ev_id] = true
			if ev_id == "frayed_debt_parcel":
				parcel_record = ev

	_check(not parcel_record.is_empty(), "AC2: found frayed_debt_parcel by id")
	# Verify other expected IDs remain present without asserting list size
	_check(seen_ids.has("moth_infestation"), "AC2: moth_infestation remains in catalog")
	_check(seen_ids.has("dye_vat"), "AC2: dye_vat remains in catalog")
	_check(seen_ids.has("needle_toll"), "AC2: needle_toll remains in catalog")

	var choices: Array = parcel_record.get("choices", [])
	var choice_by_id: Dictionary = {}
	for c in choices:
		if c is Dictionary:
			choice_by_id[c.get("id", "")] = c

	_check(choice_by_id.has("offer_0"), "AC2: frayed_debt_parcel has offer_0")
	_check(choice_by_id.has("offer_1"), "AC2: frayed_debt_parcel has offer_1")
	_check(choice_by_id.has("safe_exit"), "AC2: frayed_debt_parcel has safe_exit")

	var offer_0: Dictionary = choice_by_id.get("offer_0", {})
	var offer_1: Dictionary = choice_by_id.get("offer_1", {})
	var safe_exit: Dictionary = choice_by_id.get("safe_exit", {})

	# Assert offer_0 text amended to state requirement
	var offer_0_text: String = offer_0.get("text", "")
	_check(offer_0_text.contains("DARK or SNUFFED"),
		"AC2: offer_0 text mentions DARK or SNUFFED requirement")
	_check(offer_0_text.contains("candlelight"),
		"AC2: offer_0 text mentions candlelight")

	# Assert offer_0 effect fields
	var eff_0: Dictionary = offer_0.get("stitched_effect", {})
	_check(eff_0.get("target") == "party", "AC2: offer_0 target is party")
	_check(int(eff_0.get("candle")) == 0, "AC2: offer_0 candle delta is 0")
	_check(int(eff_0.get("fray")) == 25, "AC2: offer_0 fray is 25")
	var eff_0_part: Dictionary = eff_0.get("part", {})
	_check(eff_0_part.get("id") == "scissor_crab_claw_arm" and int(eff_0_part.get("tier")) == 2,
		"AC2: offer_0 awards tier-2 scissor_crab_claw_arm")
	_check(eff_0.get("required_candle_bands") == ["dark", "snuffed"],
		"AC2: offer_0 has required_candle_bands [dark, snuffed]")

	# Assert offer_1 unchanged
	var eff_1: Dictionary = offer_1.get("stitched_effect", {})
	_check(eff_1.get("target") == "party" and int(eff_1.get("candle")) == 0 and int(eff_1.get("fray")) == 25,
		"AC2: offer_1 unchanged party fray +25, candle 0")
	var eff_1_part: Dictionary = eff_1.get("part", {})
	_check(eff_1_part.get("id") == "moth_swarm_wings" and int(eff_1_part.get("tier")) == 2,
		"AC2: offer_1 awards tier-2 moth_swarm_wings")
	_check(not eff_1.has("required_candle_bands") and not eff_1.has("required_candle_band"),
		"AC2: offer_1 has no candle gate")

	# Assert safe_exit unchanged
	var eff_exit: Dictionary = safe_exit.get("stitched_effect", {})
	_check(eff_exit.get("target") == "party" and int(eff_exit.get("candle")) == 0 and int(eff_exit.get("fray")) == 0 and int(eff_exit.get("scraps")) == 1,
		"AC2: safe_exit grants +1 scrap, 0 candle, 0 fray")

	# Load valid parts catalog
	var catalog := StitchedParts.load_catalog("res://data/parts/enemy_parts.json")
	_check(bool(catalog.get("ok", false)), "AC2: enemy_parts catalog loads successfully")
	_check(catalog.get("by_id", {}).has("scissor_crab_claw_arm"),
		"AC2: catalog contains scissor_crab_claw_arm")
	_check(catalog.get("by_id", {}).has("moth_swarm_wings"),
		"AC2: catalog contains moth_swarm_wings")

	# Prepare event record with native integer tiers as stitched_run_session._convert_event does
	var live_event := parcel_record.duplicate(true)
	for ch in live_event.get("choices", []):
		if ch.get("stitched_effect", {}).has("part"):
			ch["stitched_effect"]["part"]["tier"] = int(ch["stitched_effect"]["part"]["tier"])

	# Test preview across candle bands with real event record
	var test_candles := [0, 15, 25, 26, 50, 75, 100]
	for c in test_candles:
		var snap := _four_snapshot(c)
		var svc := RunStitchedEventConsequence.new(live_event, catalog)
		var prev := svc.preview(snap)
		_check(prev.get("ok") == true, "AC2: preview succeeds for real parcel at candle %d" % c)
		var p_offer_0 := _entry(prev, "offer_0")
		var p_offer_1 := _entry(prev, "offer_1")
		var p_exit := _entry(prev, "safe_exit")

		# offer_1 and safe_exit are always available
		_check(p_offer_1.get("available") == true, "AC2: offer_1 available at candle %d" % c)
		_check(p_offer_1.get("satchel_count") == 3, "AC2: offer_1 projects satchel_count 3")
		_check(p_exit.get("available") == true, "AC2: safe_exit available at candle %d" % c)
		_check(p_exit.get("scraps") == 11, "AC2: safe_exit projects scraps 10 + 1 = 11")

		if c <= 25:
			_check(p_offer_0.get("available") == true,
				"AC2: offer_0 available in DARK/SNUFFED at candle %d" % c)
			_check(p_offer_0.get("part") == {"id": "scissor_crab_claw_arm", "tier": 2},
				"AC2: offer_0 projects tier-2 claw")
			_check(p_offer_0.get("satchel_count") == 3,
				"AC2: offer_0 projects satchel_count 3 (2 + 1)")
			_check(p_offer_0.get("candle") == c,
				"AC2: offer_0 preserves candle %d" % c)
			_check(p_offer_0.get("fray") == {"warden": 25, "seamstress": 25, "tinker": 25, "button_golem": 25},
				"AC2: offer_0 projects +25 fray to all 4 heroes")
		else:
			_check(p_offer_0.get("available") == false,
				"AC2: offer_0 unavailable outside DARK/SNUFFED at candle %d" % c)
			_check(p_offer_0.get("satchel_count") == 2,
				"AC2: offer_0 retains base satchel_count 2 when unavailable")
			_check(p_offer_0.get("candle") == c,
				"AC2: offer_0 retains base candle %d when unavailable" % c)
			_check(p_offer_0.get("fray") == {},
				"AC2: offer_0 has empty fray map when unavailable")

	# Test choose on fresh instance in DARK (candle 25)
	var snap_dark := _four_snapshot(25)
	var svc_dark := RunStitchedEventConsequence.new(live_event, catalog)
	var prev_dark := svc_dark.preview(snap_dark)
	var rec_dark := svc_dark.choose("offer_0", snap_dark)
	_check(rec_dark.get("ok") == true, "AC2: choose(offer_0) succeeds in DARK (25)")
	_check(rec_dark.get("event_id") == "frayed_debt_parcel", "AC2: receipt event_id matches")
	_check(rec_dark.get("choice_id") == "offer_0", "AC2: receipt choice_id matches")
	_check(rec_dark.get("target") == "party", "AC2: receipt target is party")
	_check(rec_dark.get("candle") == 25, "AC2: receipt candle is 25")
	_check(rec_dark.get("part") == {"id": "scissor_crab_claw_arm", "tier": 2},
		"AC2: receipt part is tier-2 scissor_crab_claw_arm")
	_check(rec_dark.get("satchel_count") == 3, "AC2: receipt satchel_count is 3")
	_check(rec_dark.get("fray") == {"warden": 25, "seamstress": 25, "tinker": 25, "button_golem": 25},
		"AC2: receipt fray is +25 per hero")
	_check(rec_dark.get("candle") == _entry(prev_dark, "offer_0").get("candle"),
		"AC2: receipt candle matches preview equality")
	_check(rec_dark.get("part") == _entry(prev_dark, "offer_0").get("part"),
		"AC2: receipt part matches preview equality")

	# Test choose rejection on fresh instance in GLOOM (candle 50)
	var snap_gloom := _four_snapshot(50)
	var svc_gloom := RunStitchedEventConsequence.new(live_event, catalog)
	var rec_gloom_rej := svc_gloom.choose("offer_0", snap_gloom)
	_check(rec_gloom_rej.get("ok") == false, "AC2: choose(offer_0) rejected in GLOOM (50)")
	_check(rec_gloom_rej.get("candle") == 50, "AC2: rejection carries base candle 50")
	_check(svc_gloom.is_claimed() == false, "AC2: rejection leaves visit unclaimed")
	# Can choose offer_1 afterwards on same visit
	var rec_gloom_offer_1 := svc_gloom.choose("offer_1", snap_gloom)
	_check(rec_gloom_offer_1.get("ok") == true, "AC2: offer_1 succeeds after offer_0 rejection")
	_check(rec_gloom_offer_1.get("part") == {"id": "moth_swarm_wings", "tier": 2},
		"AC2: offer_1 receipt gives tier-2 moth_swarm_wings")
	_check(svc_gloom.is_claimed() == true, "AC2: visit claimed by offer_1")


func _test_ac3_malformed_candle_bands_and_invariants() -> void:
	var malformed_cases: Array = [
		# Non-array types
		{"label": "string", "bands": "dark"},
		{"label": "integer", "bands": 123},
		{"label": "boolean_true", "bands": true},
		{"label": "boolean_false", "bands": false},
		{"label": "dictionary", "bands": {"dark": true}},
		{"label": "float", "bands": 2.5},
		# Empty list
		{"label": "empty_array", "bands": []},
		# Duplicate band
		{"label": "duplicate_dark", "bands": ["dark", "dark"]},
		{"label": "duplicate_multi", "bands": ["snuffed", "dark", "snuffed"]},
		# Unknown band name
		{"label": "unknown_name", "bands": ["twilight"]},
		{"label": "uppercase", "bands": ["DARK"]},
		{"label": "mixed_case", "bands": ["Dark", "Snuffed"]},
		{"label": "whitespace_leading", "bands": [" dark"]},
		{"label": "whitespace_trailing", "bands": ["dark "]},
		{"label": "empty_string_member", "bands": [""]},
		# Non-string members
		{"label": "int_member", "bands": [1]},
		{"label": "null_member", "bands": [null]},
		{"label": "bool_member", "bands": [true]},
		{"label": "mixed_non_string", "bands": ["dark", 25]},
		{"label": "nested_array_member", "bands": [["dark"]]},
		# More than 5 entries
		{"label": "too_many_entries", "bands": ["snuffed", "dark", "gloom", "dim", "bright", "extra"]},
	]

	var snap := _four_snapshot(20) # In DARK
	var snap_orig := snap.duplicate(true)

	for case_item in malformed_cases:
		var bad_eff: Dictionary = {
			"target": "party",
			"candle": 0,
			"fray": 25,
			"required_candle_bands": case_item["bands"],
		}
		var bad_ev := {
			"id": "ev_bad_bands_%s" % case_item["label"],
			"title": "Bad Bands Event",
			"description": "Malformed candle bands test event.",
			"choices": [
				{"id": "bad_choice", "text": "Bad choice.", "stitched_effect": bad_eff},
				{"id": "leave", "text": "Leave.", "stitched_effect": {"target": "party", "candle": 0, "fray": 0}},
			],
		}
		var bad_ev_orig := bad_ev.duplicate(true)
		var svc := RunStitchedEventConsequence.new(bad_ev)

		var prev := svc.preview(snap)
		_check(prev.get("ok") == true, "AC3: preview returns ok:true for event with malformed choice (%s)" % case_item["label"])
		var bad_entry := _entry(prev, "bad_choice")
		_check(bad_entry.get("available") == false,
			"AC3: malformed choice (%s) is unavailable" % case_item["label"])
		_check(bad_entry.get("candle_delta") == null and bad_entry.get("fray_delta") == null,
			"AC3: malformed choice (%s) has null deltas" % case_item["label"])
		_check(bad_entry.get("candle") == 20 and bad_entry.get("fray") == {},
			"AC3: malformed choice (%s) has base candle and empty fray" % case_item["label"])

		var leave_entry := _entry(prev, "leave")
		_check(leave_entry.get("available") == true,
			"AC3: alternative leave choice remains available (%s)" % case_item["label"])

		# choose() rejection
		var rej := svc.choose("bad_choice", snap)
		_check(rej.get("ok") == false, "AC3: choose(bad_choice) rejected (%s)" % case_item["label"])
		_check(rej.get("candle") == 20 and rej.get("fray") == {},
			"AC3: rejection has base candle and empty fray (%s)" % case_item["label"])
		_check(svc.is_claimed() == false and svc.is_valid() == true,
			"AC3: rejection does not consume visit (%s)" % case_item["label"])
		_check(snap == snap_orig, "AC3: snapshot untouched after rejection (%s)" % case_item["label"])
		_check(bad_ev == bad_ev_orig, "AC3: event data untouched after rejection (%s)" % case_item["label"])

		# Legal alternative still succeeds
		var leave_rec := svc.choose("leave", snap)
		_check(leave_rec.get("ok") == true,
			"AC3: leave succeeds after malformed choice rejection (%s)" % case_item["label"])
		_check(svc.is_claimed() == true,
			"AC3: visit claimed after leave success (%s)" % case_item["label"])

	# Simultaneous singular and plural gates
	var simultaneous_ev := {
		"id": "ev_simultaneous_gates",
		"title": "Simultaneous Gates",
		"description": "Simultaneous singular and plural candle band gates.",
		"choices": [
			{
				"id": "both_gates",
				"text": "Both singular and plural.",
				"stitched_effect": {
					"target": "party",
					"candle": 0,
					"fray": 25,
					"required_candle_band": "dark",
					"required_candle_bands": ["dark", "snuffed"],
				},
			},
			{
				"id": "leave",
				"text": "Leave.",
				"stitched_effect": {"target": "party", "candle": 0, "fray": 0},
			},
		],
	}
	var svc_both := RunStitchedEventConsequence.new(simultaneous_ev)
	var prev_both := svc_both.preview(snap)
	var both_entry := _entry(prev_both, "both_gates")
	_check(both_entry.get("available") == false,
		"AC3: choice with both singular and plural gates is unavailable")
	_check(both_entry.get("candle_delta") == null and both_entry.get("fray_delta") == null,
		"AC3: choice with both gates has null deltas")
	_check(svc_both.choose("both_gates", snap).get("ok") == false,
		"AC3: choose(both_gates) is rejected")
	_check(svc_both.is_claimed() == false,
		"AC3: simultaneous gates rejection leaves visit open")
	_check(svc_both.choose("leave", snap).get("ok") == true,
		"AC3: leave succeeds after simultaneous gates rejection")

	# Duplicate commit refusal
	var valid_ev := {
		"id": "ev_dup_commit",
		"title": "Dup Commit Event",
		"description": "Testing replay refusal.",
		"choices": [
			{
				"id": "offer_dark",
				"text": "Offer in dark.",
				"stitched_effect": {
					"target": "party",
					"candle": 0,
					"fray": 25,
					"required_candle_bands": ["dark"],
				},
			},
			{
				"id": "leave",
				"text": "Leave.",
				"stitched_effect": {"target": "party", "candle": 0, "fray": 0},
			},
		],
	}
	var svc_dup := RunStitchedEventConsequence.new(valid_ev)
	var rec_first := svc_dup.choose("offer_dark", snap)
	_check(rec_first.get("ok") == true, "AC3: first claim succeeds")
	_check(svc_dup.is_claimed() == true and svc_dup.is_valid() == false,
		"AC3: service marked claimed and invalid after first claim")
	var rec_second := svc_dup.choose("offer_dark", snap)
	_check(rec_second.get("ok") == false, "AC3: second claim (replay) is rejected")
	var rec_leave := svc_dup.choose("leave", snap)
	_check(rec_leave.get("ok") == false, "AC3: claiming alternative after visit claimed is rejected")

	# Detachment / mutation tests: caller modifying preview or receipt cannot corrupt service
	var prev_snap_check := svc_both.preview(snap)
	if not prev_snap_check.get("choices", []).is_empty():
		var ch: Dictionary = prev_snap_check["choices"][0]
		ch["candle"] = 999
		ch["fray"] = {"warden": 999}
	_check(snap == snap_orig, "AC3: caller mutating preview result does not mutate snapshot")

	# Seeded RNG neutrality
	seed(424242)
	var rng_sample := randi()
	seed(424242)

	var svc_rng := RunStitchedEventConsequence.new(valid_ev)
	var _p := svc_rng.preview(snap)
	_check(randi() == rng_sample, "AC3: preview does not draw seeded RNG")

	seed(424242)
	rng_sample = randi()
	seed(424242)

	var _c := svc_rng.choose("offer_dark", snap)
	_check(randi() == rng_sample, "AC3: choose does not draw seeded RNG")
