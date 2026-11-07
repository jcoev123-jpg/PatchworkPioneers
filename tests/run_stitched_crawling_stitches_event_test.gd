extends SceneTree
## Deterministic headless SceneTree test for RunStitchedCrawlingStitchesEvent.
## Validates atmospheric cue and 25% two-step wrong-turn rule (Design v4 STITCHED section 9b).

const HORRORS_PATH := "res://data/walk/horrors.json"

var checks := 0
var failures: Array[String] = []


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _load_canonical_horror() -> Dictionary:
	var file := FileAccess.open(HORRORS_PATH, FileAccess.READ)
	_check(file != null, "horrors.json file opened successfully")
	if file == null:
		return {}
	var text := file.get_as_text()
	var json: Variant = JSON.parse_string(text)
	_check(json is Dictionary, "horrors.json parsed as Dictionary")
	if not (json is Dictionary):
		return {}
	var list: Array = json.get("horrors", [])
	_check(not list.is_empty(), "horrors list is not empty")
	for record: Variant in list:
		if record is Dictionary and str(record.get("id", "")) == RunStitchedCrawlingStitchesEvent.HORROR_ID:
			return (record as Dictionary).duplicate(true)
	return {}


func _initialize() -> void:
	_test_ac1()
	_test_ac2()
	_test_ac3()
	if failures.is_empty():
		print("run_stitched_crawling_stitches_event_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("run_stitched_crawling_stitches_event_test: FAIL (%d failures)" % failures.size())
		quit(1)


func _test_ac1() -> void:
	var horror := _load_canonical_horror()
	_check(not horror.is_empty(), "AC1: canonical horror record loaded by ID")
	_check(str(horror.get("id", "")) == "wandering_seams", "AC1: horror id is wandering_seams")
	_check(str(horror.get("kind", "")) == "stitches", "AC1: horror kind is stitches")
	_check(str(horror.get("name", "")) == "Crawling Stitches", "AC1: horror name is Crawling Stitches")

	var horror_before := horror.duplicate(true)
	var traits := RunStitchedCrawlingStitchesEvent.UNRAVELLED_TRAITS
	_check(traits.size() == 5, "AC1: exactly five Unravelled traits")

	# Boundary check over all five Unravelled traits at Fray 99, 100, 150
	for trait_name: String in traits:
		var lead_99 := {
			"id": "warden", "rank": 1, "hp": 32, "max_hp": 40,
			"fray": 99, "resolve": trait_name, "lost": false
		}
		var lead_99_before := lead_99.duplicate(true)
		var preview_99 := RunStitchedCrawlingStitchesEvent.preview(horror, lead_99)
		_check(bool(preview_99.get("ok")), "AC1: preview at FRAY 99 succeeds for %s" % trait_name)
		_check(not bool(preview_99.get("cue")), "AC1: FRAY 99 cue is inactive for %s" % trait_name)
		_check(not bool(preview_99.get("cue_visible")), "AC1: FRAY 99 cue_visible is inactive for %s" % trait_name)
		_check(bool(preview_99.get("eligible")), "AC1: FRAY 99 IS eligible for wrong-turn roll for %s" % trait_name)
		_check(bool(preview_99.get("roll_eligible")), "AC1: FRAY 99 roll_eligible is true for %s" % trait_name)
		_check(bool(preview_99.get("unravelled")), "AC1: FRAY 99 unravelled is true for %s" % trait_name)
		_check(int(preview_99.get("extra_steps", -1)) == 0, "AC1: FRAY 99 preview extra_steps is 0 for %s" % trait_name)
		_check(lead_99 == lead_99_before, "AC1: lead 99 fixture unmodified after preview for %s" % trait_name)

		var lead_100 := {
			"id": "warden", "rank": 1, "hp": 32, "max_hp": 40,
			"fray": 100, "resolve": trait_name, "lost": false
		}
		var preview_100 := RunStitchedCrawlingStitchesEvent.preview(horror, lead_100)
		_check(bool(preview_100.get("ok")), "AC1: preview at FRAY 100 succeeds for %s" % trait_name)
		_check(bool(preview_100.get("cue")), "AC1: FRAY 100 cue is active for %s" % trait_name)
		_check(bool(preview_100.get("cue_visible")), "AC1: FRAY 100 cue_visible is active for %s" % trait_name)
		_check(bool(preview_100.get("eligible")), "AC1: FRAY 100 unravelled lead is eligible for %s" % trait_name)
		_check(bool(preview_100.get("roll_eligible")), "AC1: FRAY 100 roll_eligible is true for %s" % trait_name)
		_check(bool(preview_100.get("unravelled")), "AC1: FRAY 100 unravelled is true for %s" % trait_name)

		var lead_150 := {
			"id": "warden", "rank": 1, "hp": 32, "max_hp": 40,
			"fray": 150, "resolve": trait_name, "lost": false
		}
		var preview_150 := RunStitchedCrawlingStitchesEvent.preview(horror, lead_150)
		_check(bool(preview_150.get("ok")), "AC1: preview at FRAY 150 succeeds for %s" % trait_name)
		_check(bool(preview_150.get("cue")), "AC1: FRAY 150 cue is active for %s" % trait_name)
		_check(bool(preview_150.get("cue_visible")), "AC1: FRAY 150 cue_visible is active for %s" % trait_name)
		_check(bool(preview_150.get("eligible")), "AC1: FRAY 150 unravelled lead is eligible for %s" % trait_name)
		_check(bool(preview_150.get("roll_eligible")), "AC1: FRAY 150 roll_eligible is true for %s" % trait_name)
		_check(bool(preview_150.get("unravelled")), "AC1: FRAY 150 unravelled is true for %s" % trait_name)

	# Fray 49 with an Unravelled trait (stale below 50, not eligible)
	var lead_49_frantic := {
		"id": "warden", "rank": 1, "hp": 32, "max_hp": 40,
		"fray": 49, "resolve": "frantic", "lost": false
	}
	var preview_49 := RunStitchedCrawlingStitchesEvent.preview(horror, lead_49_frantic)
	_check(bool(preview_49.get("ok")), "AC1: preview at FRAY 49 succeeds")
	_check(not bool(preview_49.get("cue")), "AC1: FRAY 49 cue is inactive")
	_check(not bool(preview_49.get("cue_visible")), "AC1: FRAY 49 cue_visible is inactive")
	_check(not bool(preview_49.get("eligible")), "AC1: FRAY 49 is NOT eligible for wrong turn")
	_check(not bool(preview_49.get("roll_eligible")), "AC1: FRAY 49 roll_eligible is false")
	_check(bool(preview_49.get("unravelled")), "AC1: FRAY 49 has unravelled trait string")

	# Fray 50 with an Unravelled trait (active interval 50..200, eligible without cue)
	var lead_50_frantic := {
		"id": "warden", "rank": 1, "hp": 32, "max_hp": 40,
		"fray": 50, "resolve": "frantic", "lost": false
	}
	var preview_50 := RunStitchedCrawlingStitchesEvent.preview(horror, lead_50_frantic)
	_check(bool(preview_50.get("ok")), "AC1: preview at FRAY 50 succeeds")
	_check(not bool(preview_50.get("cue")), "AC1: FRAY 50 cue is inactive")
	_check(not bool(preview_50.get("cue_visible")), "AC1: FRAY 50 cue_visible is inactive")
	_check(bool(preview_50.get("eligible")), "AC1: FRAY 50 IS eligible for wrong turn")
	_check(bool(preview_50.get("roll_eligible")), "AC1: FRAY 50 roll_eligible is true")
	_check(bool(preview_50.get("unravelled")), "AC1: FRAY 50 unravelled is true")

	# Unresolved lead at Fray 49, 50, 99, 100, 150
	for fray_val: int in [49, 50, 99, 100, 150]:
		var unres_lead := {
			"id": "warden", "rank": 1, "hp": 30, "max_hp": 40,
			"fray": fray_val, "resolve": "", "lost": false
		}
		var p_unres := RunStitchedCrawlingStitchesEvent.preview(horror, unres_lead)
		_check(bool(p_unres.get("ok")), "AC1: unresolved preview ok at fray %d" % fray_val)
		_check(p_unres.cue == (fray_val >= 100), "AC1: unresolved cue matches threshold at fray %d" % fray_val)
		_check(not bool(p_unres.get("eligible")), "AC1: unresolved is never eligible at fray %d" % fray_val)
		_check(not bool(p_unres.get("roll_eligible")), "AC1: unresolved roll_eligible is false at fray %d" % fray_val)
		_check(not bool(p_unres.get("unravelled")), "AC1: unresolved is not unravelled at fray %d" % fray_val)

	# Steadfast lead at Fray 49, 50, 99, 100, 150
	for fray_val: int in [49, 50, 99, 100, 150]:
		var sf_lead := {
			"id": "warden", "rank": 1, "hp": 30, "max_hp": 40,
			"fray": fray_val, "resolve": "steadfast", "lost": false
		}
		var p_sf := RunStitchedCrawlingStitchesEvent.preview(horror, sf_lead)
		_check(bool(p_sf.get("ok")), "AC1: steadfast preview ok at fray %d" % fray_val)
		_check(p_sf.cue == (fray_val >= 100), "AC1: steadfast cue matches threshold at fray %d" % fray_val)
		_check(not bool(p_sf.get("eligible")), "AC1: steadfast is never eligible at fray %d" % fray_val)
		_check(not bool(p_sf.get("roll_eligible")), "AC1: steadfast roll_eligible is false at fray %d" % fray_val)
		_check(not bool(p_sf.get("unravelled")), "AC1: steadfast is not unravelled at fray %d" % fray_val)

	_check(horror == horror_before, "AC1: horror record completely unmodified")


func _test_ac2() -> void:
	var horror := _load_canonical_horror()
	var traits := RunStitchedCrawlingStitchesEvent.UNRAVELLED_TRAITS
	var boundary_rolls := [1, 25, 26, 100]

	# Test all 5 traits at Fray 50 and Fray 99
	for trait_name: String in traits:
		for fray_val: int in [50, 75, 99]:
			var lead := {
				"id": "lead_" + trait_name,
				"rank": 1,
				"hp": 28,
				"max_hp": 40,
				"fray": fray_val,
				"resolve": trait_name,
				"lost": false
			}
			var lead_before := lead.duplicate(true)

			# Eligible lead without roll is refused
			var no_roll_res := RunStitchedCrawlingStitchesEvent.resolve(horror, lead)
			_check(not bool(no_roll_res.get("ok")), "AC2: resolve without roll refused for eligible lead at fray %d %s" % [fray_val, trait_name])
			_check(str(no_roll_res.get("error", "")).contains("percentile roll required"), "AC2: error explains missing roll")
			_check(lead == lead_before, "AC2: lead untouched on refusal")

			# Eligible lead with null or bad roll is refused
			var null_roll_res := RunStitchedCrawlingStitchesEvent.resolve(horror, lead, null)
			_check(not bool(null_roll_res.get("ok")), "AC2: resolve with null roll refused for eligible lead at fray %d" % fray_val)

			var bad_roll_0 := RunStitchedCrawlingStitchesEvent.resolve(horror, lead, 0)
			_check(not bool(bad_roll_0.get("ok")), "AC2: roll 0 refused for eligible lead at fray %d" % fray_val)

			var bad_roll_101 := RunStitchedCrawlingStitchesEvent.resolve(horror, lead, 101)
			_check(not bool(bad_roll_101.get("ok")), "AC2: roll 101 refused for eligible lead at fray %d" % fray_val)

			var bad_roll_str := RunStitchedCrawlingStitchesEvent.resolve(horror, lead, "25")
			_check(not bool(bad_roll_str.get("ok")), "AC2: string roll refused for eligible lead at fray %d" % fray_val)

			# Test boundary percentile rolls 1, 25, 26, 100
			for roll: int in boundary_rolls:
				var res := RunStitchedCrawlingStitchesEvent.resolve(horror, lead, roll)
				_check(bool(res.get("ok")), "AC2: resolve ok for trait %s fray %d roll %d" % [trait_name, fray_val, roll])
				_check(res.cue == (fray_val >= 100), "AC2: resolve cue matches threshold (%s fray %d roll %d)" % [trait_name, fray_val, roll])
				_check(bool(res.get("eligible")), "AC2: resolve eligible true for %s fray %d roll %d" % [trait_name, fray_val, roll])
				_check(bool(res.get("roll_eligible")), "AC2: roll_eligible true for %s fray %d roll %d" % [trait_name, fray_val, roll])
				if roll <= 25:
					_check(bool(res.get("wrong_turn")), "AC2: roll %d triggers wrong_turn for %s fray %d" % [roll, trait_name, fray_val])
					_check(int(res.get("extra_steps", 0)) == 2, "AC2: roll %d awards +2 extra steps for %s fray %d" % [roll, trait_name, fray_val])
				else:
					_check(not bool(res.get("wrong_turn")), "AC2: roll %d does not trigger wrong_turn for %s fray %d" % [roll, trait_name, fray_val])
					_check(int(res.get("extra_steps", -1)) == 0, "AC2: roll %d awards 0 extra steps for %s fray %d" % [roll, trait_name, fray_val])

	# Fray 49 cannot be active Unravelled for this purpose
	var lead_49 := {
		"id": "lead_frantic_49",
		"rank": 1,
		"hp": 28,
		"max_hp": 40,
		"fray": 49,
		"resolve": "frantic",
		"lost": false
	}
	var res_49_no_roll := RunStitchedCrawlingStitchesEvent.resolve(horror, lead_49)
	_check(bool(res_49_no_roll.get("ok")), "AC2: fray 49 resolve succeeds without roll because not eligible")
	_check(not bool(res_49_no_roll.get("eligible")), "AC2: fray 49 not eligible")
	_check(not bool(res_49_no_roll.get("wrong_turn")), "AC2: fray 49 wrong_turn false")
	_check(int(res_49_no_roll.get("extra_steps", -1)) == 0, "AC2: fray 49 extra_steps 0")

	for roll: int in boundary_rolls:
		var res_49 := RunStitchedCrawlingStitchesEvent.resolve(horror, lead_49, roll)
		_check(bool(res_49.get("ok")), "AC2: fray 49 resolve ok with roll %d" % roll)
		_check(not bool(res_49.get("eligible")), "AC2: fray 49 resolve not eligible with roll %d" % roll)
		_check(not bool(res_49.get("wrong_turn")), "AC2: fray 49 wrong_turn is false with roll %d" % roll)
		_check(int(res_49.get("extra_steps", -1)) == 0, "AC2: fray 49 extra_steps is 0 with roll %d" % roll)

	# Fray 49 with bad roll is still refused
	var res_49_bad_roll := RunStitchedCrawlingStitchesEvent.resolve(horror, lead_49, 101)
	_check(not bool(res_49_bad_roll.get("ok")), "AC2: fray 49 with roll 101 is refused")

	# Steadfast lead at FRAY 99 and 100: cue active only at 100+, NOT eligible, never adds steps.
	for fray_val: int in [99, 100]:
		var steadfast_lead := {
			"id": "warden", "rank": 1, "hp": 30, "max_hp": 40,
			"fray": fray_val, "resolve": "steadfast", "lost": false
		}
		var sf_preview := RunStitchedCrawlingStitchesEvent.preview(horror, steadfast_lead)
		_check(bool(sf_preview.get("ok")), "AC2: steadfast preview ok at fray %d" % fray_val)
		_check(sf_preview.cue == (fray_val >= 100), "AC2: steadfast cue matches threshold at fray %d" % fray_val)
		_check(not bool(sf_preview.get("eligible")), "AC2: steadfast lead is NOT roll eligible at fray %d" % fray_val)
		_check(not bool(sf_preview.get("unravelled")), "AC2: steadfast lead is NOT unravelled at fray %d" % fray_val)

		for roll: int in boundary_rolls:
			var res := RunStitchedCrawlingStitchesEvent.resolve(horror, steadfast_lead, roll)
			_check(bool(res.get("ok")), "AC2: steadfast resolve ok with roll %d at fray %d" % [roll, fray_val])
			_check(res.cue == (fray_val >= 100), "AC2: steadfast resolve cue matches threshold at fray %d" % fray_val)
			_check(not bool(res.get("eligible")), "AC2: steadfast resolve not eligible at fray %d" % fray_val)
			_check(not bool(res.get("wrong_turn")), "AC2: steadfast wrong_turn is false for roll %d at fray %d" % [roll, fray_val])
			_check(int(res.get("extra_steps", -1)) == 0, "AC2: steadfast adds exactly 0 extra steps for roll %d at fray %d" % [roll, fray_val])

	# Un-resolved lead at FRAY 99 and 100: cue active only at 100+, NOT eligible, never adds steps.
	for fray_val: int in [99, 100]:
		var unresolved_lead := {
			"id": "warden", "rank": 1, "hp": 30, "max_hp": 40,
			"fray": fray_val, "resolve": "", "lost": false
		}
		var unres_preview := RunStitchedCrawlingStitchesEvent.preview(horror, unresolved_lead)
		_check(bool(unres_preview.get("ok")), "AC2: un-resolved preview ok at fray %d" % fray_val)
		_check(unres_preview.cue == (fray_val >= 100), "AC2: un-resolved cue matches threshold at fray %d" % fray_val)
		_check(not bool(unres_preview.get("eligible")), "AC2: un-resolved lead is NOT roll eligible at fray %d" % fray_val)
		_check(not bool(unres_preview.get("unravelled")), "AC2: un-resolved lead is NOT unravelled at fray %d" % fray_val)

		for roll: int in boundary_rolls:
			var res := RunStitchedCrawlingStitchesEvent.resolve(horror, unresolved_lead, roll)
			_check(bool(res.get("ok")), "AC2: un-resolved resolve ok with roll %d at fray %d" % [roll, fray_val])
			_check(not bool(res.get("eligible")), "AC2: un-resolved resolve not eligible at fray %d" % fray_val)
			_check(not bool(res.get("wrong_turn")), "AC2: un-resolved wrong_turn is false for roll %d at fray %d" % [roll, fray_val])
			_check(int(res.get("extra_steps", -1)) == 0, "AC2: un-resolved adds exactly 0 extra steps for roll %d at fray %d" % [roll, fray_val])

	# Verify caller's RNG state is completely untouched.
	var test_rng := RandomNumberGenerator.new()
	test_rng.seed = 98765
	var rng_state_before := test_rng.state
	var lead_for_rng := {"id": "warden", "rank": 1, "hp": 30, "max_hp": 40, "fray": 99, "resolve": "frantic", "lost": false}
	RunStitchedCrawlingStitchesEvent.preview(horror, lead_for_rng)
	RunStitchedCrawlingStitchesEvent.resolve(horror, lead_for_rng, 1)
	_check(test_rng.state == rng_state_before, "AC2: helper never draws or mutates caller RNG")


func _test_ac3() -> void:
	var horror := _load_canonical_horror()

	var lead_unravelled_99 := {
		"id": "warden", "rank": 1, "hp": 35, "max_hp": 40,
		"fray": 99, "resolve": "frantic", "lost": false
	}
	var lead_unravelled_100 := {
		"id": "warden", "rank": 1, "hp": 35, "max_hp": 40,
		"fray": 100, "resolve": "frantic", "lost": false
	}
	var lead_steadfast := {
		"id": "warden", "rank": 1, "hp": 35, "max_hp": 40,
		"fray": 100, "resolve": "steadfast", "lost": false
	}
	var lead_low_fray := {
		"id": "warden", "rank": 1, "hp": 35, "max_hp": 40,
		"fray": 45, "resolve": "", "lost": false
	}

	# Preview and resolution agree on cue/eligibility.
	var p1 := RunStitchedCrawlingStitchesEvent.preview(horror, lead_unravelled_99)
	var r1 := RunStitchedCrawlingStitchesEvent.resolve(horror, lead_unravelled_99, 15)
	_check(p1.cue == r1.cue and p1.eligible == r1.eligible, "AC3: preview and resolution agree on cue/eligibility (unravelled 99)")
	_check(not p1.cue and p1.eligible, "AC3: fray 99 cue false and eligible true")

	var p1b := RunStitchedCrawlingStitchesEvent.preview(horror, lead_unravelled_100)
	var r1b := RunStitchedCrawlingStitchesEvent.resolve(horror, lead_unravelled_100, 15)
	_check(p1b.cue == r1b.cue and p1b.eligible == r1b.eligible, "AC3: preview and resolution agree on cue/eligibility (unravelled 100)")
	_check(p1b.cue and p1b.eligible, "AC3: fray 100 cue true and eligible true")

	var p2 := RunStitchedCrawlingStitchesEvent.preview(horror, lead_steadfast)
	var r2 := RunStitchedCrawlingStitchesEvent.resolve(horror, lead_steadfast, 15)
	_check(p2.cue == r2.cue and p2.eligible == r2.eligible, "AC3: preview and resolution agree on cue/eligibility (steadfast)")

	var p3 := RunStitchedCrawlingStitchesEvent.preview(horror, lead_low_fray)
	var r3 := RunStitchedCrawlingStitchesEvent.resolve(horror, lead_low_fray)
	_check(p3.cue == r3.cue and p3.eligible == r3.eligible, "AC3: preview and resolution agree on cue/eligibility (low fray)")

	# Negative case: wrong horror ID.
	var wrong_id_horror := {"id": "extra_thread_shadow", "kind": "stitches"}
	var p_wrong_id := RunStitchedCrawlingStitchesEvent.preview(wrong_id_horror, lead_unravelled_99)
	_check(not bool(p_wrong_id.get("ok")), "AC3: wrong horror id preview refused")
	_check(int(p_wrong_id.get("extra_steps", -1)) == 0, "AC3: wrong horror id extra_steps 0")
	var r_wrong_id := RunStitchedCrawlingStitchesEvent.resolve(wrong_id_horror, lead_unravelled_99, 1)
	_check(not bool(r_wrong_id.get("ok")), "AC3: wrong horror id resolve refused")
	_check(not bool(r_wrong_id.get("wrong_turn")), "AC3: wrong horror id wrong_turn false")
	_check(int(r_wrong_id.get("extra_steps", -1)) == 0, "AC3: wrong horror id extra_steps 0")

	# Negative case: forged / non-stitches horror kind.
	var non_stitches_horror := {"id": "wandering_seams", "kind": "mimic"}
	var p_non_stitches := RunStitchedCrawlingStitchesEvent.preview(non_stitches_horror, lead_unravelled_99)
	_check(not bool(p_non_stitches.get("ok")), "AC3: forged non-stitches kind preview refused")
	var r_non_stitches := RunStitchedCrawlingStitchesEvent.resolve(non_stitches_horror, lead_unravelled_99, 1)
	_check(not bool(r_non_stitches.get("ok")), "AC3: forged non-stitches kind resolve refused")
	_check(int(r_non_stitches.get("extra_steps", -1)) == 0, "AC3: non-stitches extra_steps 0")

	# Negative case: not-rank-1 lead.
	var rank2_lead := {
		"id": "seamstress", "rank": 2, "hp": 30, "max_hp": 40,
		"fray": 120, "resolve": "frantic", "lost": false
	}
	var p_rank2 := RunStitchedCrawlingStitchesEvent.preview(horror, rank2_lead)
	_check(not bool(p_rank2.get("ok")), "AC3: rank 2 lead preview refused")
	var r_rank2 := RunStitchedCrawlingStitchesEvent.resolve(horror, rank2_lead, 1)
	_check(not bool(r_rank2.get("ok")), "AC3: rank 2 lead resolve refused")
	_check(int(r_rank2.get("extra_steps", -1)) == 0, "AC3: rank 2 extra_steps 0")

	# Negative case: viewpoint SWITCH showing rank 1 does NOT make rank 2 the lead.
	var rank2_viewpoint1 := {
		"id": "seamstress", "rank": 2, "viewpoint": 1, "hp": 30, "max_hp": 40,
		"fray": 120, "resolve": "frantic", "lost": false
	}
	var r_vp := RunStitchedCrawlingStitchesEvent.resolve(horror, rank2_viewpoint1, 1)
	_check(not bool(r_vp.get("ok")), "AC3: viewpoint does not alter rank requirement")

	# Negative case: invalid lead FRAY (< 0, > 200, non-int).
	var neg_fray_lead := {"id": "w", "rank": 1, "fray": -1, "resolve": "frantic"}
	var high_fray_lead := {"id": "w", "rank": 1, "fray": 201, "resolve": "frantic"}
	var string_fray_lead := {"id": "w", "rank": 1, "fray": "100", "resolve": "frantic"}
	_check(not bool(RunStitchedCrawlingStitchesEvent.preview(horror, neg_fray_lead).get("ok")), "AC3: negative fray preview refused")
	_check(not bool(RunStitchedCrawlingStitchesEvent.resolve(horror, neg_fray_lead, 1).get("ok")), "AC3: negative fray resolve refused")
	_check(not bool(RunStitchedCrawlingStitchesEvent.preview(horror, high_fray_lead).get("ok")), "AC3: >200 fray preview refused")
	_check(not bool(RunStitchedCrawlingStitchesEvent.resolve(horror, high_fray_lead, 1).get("ok")), "AC3: >200 fray resolve refused")
	_check(not bool(RunStitchedCrawlingStitchesEvent.preview(horror, string_fray_lead).get("ok")), "AC3: string fray preview refused")

	# Negative case: out-of-range percentile for an eligible roll (0, 101, -5, non-int, null).
	var r_roll_0 := RunStitchedCrawlingStitchesEvent.resolve(horror, lead_unravelled_99, 0)
	_check(not bool(r_roll_0.get("ok")), "AC3: roll 0 refused for eligible lead")
	_check(int(r_roll_0.get("extra_steps", -1)) == 0, "AC3: roll 0 gives 0 extra steps")
	_check(r_roll_0.cue == false and r_roll_0.eligible == true, "AC3: roll 0 preserves cue/eligible diagnosis")

	var r_roll_101 := RunStitchedCrawlingStitchesEvent.resolve(horror, lead_unravelled_99, 101)
	_check(not bool(r_roll_101.get("ok")), "AC3: roll 101 refused for eligible lead")
	_check(int(r_roll_101.get("extra_steps", -1)) == 0, "AC3: roll 101 gives 0 extra steps")

	var r_roll_neg := RunStitchedCrawlingStitchesEvent.resolve(horror, lead_unravelled_99, -5)
	_check(not bool(r_roll_neg.get("ok")), "AC3: roll -5 refused for eligible lead")

	var r_roll_null := RunStitchedCrawlingStitchesEvent.resolve(horror, lead_unravelled_99, null)
	_check(not bool(r_roll_null.get("ok")), "AC3: null roll refused for eligible lead")

	var r_roll_str := RunStitchedCrawlingStitchesEvent.resolve(horror, lead_unravelled_99, "20")
	_check(not bool(r_roll_str.get("ok")), "AC3: string roll refused for eligible lead")

	# Determinism and replay: repeat identical inputs, confirm output identical and no side effects.
	var seeded_rng := RandomNumberGenerator.new()
	seeded_rng.seed = 424242
	var rng_state_initial := seeded_rng.state

	var lead_snapshot := {
		"id": "warden", "rank": 1, "hp": 30, "max_hp": 40,
		"fray": 99, "resolve": "cowering", "lost": false
	}
	var lead_snapshot_copy := lead_snapshot.duplicate(true)
	var first_preview := RunStitchedCrawlingStitchesEvent.preview(horror, lead_snapshot)
	var first_resolve := RunStitchedCrawlingStitchesEvent.resolve(horror, lead_snapshot, 12)

	for i in range(10):
		var repeated_preview := RunStitchedCrawlingStitchesEvent.preview(horror, lead_snapshot)
		var repeated_resolve := RunStitchedCrawlingStitchesEvent.resolve(horror, lead_snapshot, 12)
		_check(repeated_preview == first_preview, "AC3: preview replay is deterministic (iteration %d)" % i)
		_check(repeated_resolve == first_resolve, "AC3: resolve replay is deterministic (iteration %d)" % i)

	_check(lead_snapshot == lead_snapshot_copy, "AC3: lead snapshot unchanged after repeated calls")
	_check(seeded_rng.state == rng_state_initial, "AC3: seeded RNG state completely unchanged")
