extends SceneTree
## Deterministic headless SceneTree test for Crawling Stitches Walk integration (S8e).
## Validates atmospheric cue and deterministic two-step wrong turn (Design v4 STITCHED section 9b).

const Walk = preload("res://scripts/stitched/walk/stitched_walk_rules.gd")
const CrawlingEvent = preload("res://scripts/run_stitched_crawling_stitches_event.gd")

var checks := 0
var failures: Array[String] = []


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func random(seed_number: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_number
	return rng


func party(lead_fray: int = 0, lead_resolve: String = "", lead_rank: int = 1) -> Array:
	var dolls: Array = []
	for index in 4:
		var rank := index + 1
		var is_lead := (rank == lead_rank)
		var fray := lead_fray if is_lead else 0
		var res := lead_resolve if is_lead else ""
		dolls.append({
			"id": str(index),
			"rank": rank,
			"hp": 30,
			"max_hp": 40,
			"lost": false,
			"fray": fray,
			"resolve": res,
			"parts": {
				"head": {"id": "seamstress_mending_knot_hat", "tier": 1, "torn": false},
				"arms": "seamstress_thread_prick_needle"
			}
		})
	return dolls


func pockets() -> Dictionary:
	return {"0": ["starch"], "1": ["pins", "spare_spool"], "2": [], "3": []}


func act(walk: StitchedWalkRules, kind: String, extra: Dictionary = {}) -> Dictionary:
	var request := {"kind": kind, "actor": walk.snapshot().viewpoint}
	request.merge(extra, true)
	return walk.act(request, walk.snapshot())


func reject(walk: StitchedWalkRules, rng: RandomNumberGenerator, request: Dictionary, expected: Dictionary = {}) -> void:
	var before := walk.snapshot()
	var state := rng.state
	var receipt := walk.act(request, before if expected.is_empty() else expected)
	check(not receipt.ok and not receipt.error.is_empty() and receipt.events.is_empty(), "reject " + str(request))
	check(walk.snapshot() == before and rng.state == state and receipt.snapshot == before,
		"rejection preserves full state and borrowed RNG")
	receipt.snapshot.pockets.clear()
	check(walk.snapshot() == before, "rejected receipt detached")


func finish_walk(walk: StitchedWalkRules) -> int:
	var forward_count := 0
	while walk.snapshot().phase == "walking":
		var result: Dictionary
		if walk.tug_unresolved():
			result = act(walk, "tug", {"target": "thread_tug", "choice": "yield"})
		else:
			result = act(walk, "forward")
			forward_count += 1
		check(result.ok, "forward/tug action succeeds")
		if not result.ok:
			break
	check(walk.snapshot().phase == "complete", "walk reaches complete phase")
	return forward_count


func _initialize() -> void:
	_test_ac1_default_off_parity()
	_test_ac2_cue_and_thresholds()
	_test_ac3_percentile_wrong_turn_and_extra_steps()
	_test_ac3_replay_and_coexistence()
	_test_ac4_rejections_and_atomicity()
	_test_ac5_clean_boundaries()

	if failures.is_empty():
		print("stitched_s8e_crawling_walk_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("stitched_s8e_crawling_walk_test: FAIL (%d failures)" % failures.size())
		quit(1)


func _test_ac1_default_off_parity() -> void:
	for seed_number in range(12):
		for mimic in [false, true]:
			for tug in [false, true]:
				for mannequins in [false, true]:
					var dolls := party(100, "frantic")
					var p := pockets()
					var baseline_rng := random(seed_number)
					var baseline := Walk.start(baseline_rng, "walls", dolls, p, null, mimic, tug, mannequins)

					var off_rng := random(seed_number)
					var off := Walk.start(off_rng, "walls", dolls, p, null, mimic, tug, mannequins, false)

					check(baseline != null and off != null, "AC1: both baseline and explicit-off start")
					check(baseline.snapshot() == off.snapshot(), "AC1: baseline and explicit-off produce identical start snapshot")
					check(baseline_rng.state == off_rng.state, "AC1: RNG state matches across baseline and off")
					check(not off.snapshot().has("stitches"), "AC1: default-off snapshot has no stitches state")
					check(baseline.snapshot().corridor.steps == off.snapshot().corridor.steps, "AC1: corridor steps unchanged")

					# Complete both and compare receipts
					var b_steps := finish_walk(baseline)
					var o_steps := finish_walk(off)
					check(b_steps == o_steps, "AC1: step counts identical")
					check(baseline.snapshot() == off.snapshot(), "AC1: completion snapshots match byte-for-byte")
					check(baseline_rng.state == off_rng.state, "AC1: final RNG states match byte-for-byte")


func _test_ac2_cue_and_thresholds() -> void:
	# FRAY 99 vs 100 vs 150
	for fray_val in [99, 100, 150]:
		var rng := random(42)
		var p_unres := party(fray_val, "")
		var walk_unres := Walk.start(rng, "walls", p_unres, pockets(), null, false, false, false, true)
		check(walk_unres != null, "AC2: walk_unres starts")
		var snap_unres := walk_unres.snapshot()
		check(snap_unres.has("stitches"), "AC2: snapshot contains stitches")
		var expected_cue: bool = (fray_val >= 100)
		check(snap_unres.stitches.cue == expected_cue, "AC2: cue matches threshold for unresolved at fray %d" % fray_val)
		check(snap_unres.stitches.cue_visible == expected_cue, "AC2: cue_visible matches cue at fray %d" % fray_val)
		check(walk_unres.stitches_cue_visible() == expected_cue, "AC2: helper matches cue at fray %d" % fray_val)
		check(not snap_unres.stitches.eligible, "AC2: unresolved lead is never eligible for wrong turn")
		check(not snap_unres.stitches.wrong_turn, "AC2: unresolved lead never takes wrong turn")
		check(snap_unres.stitches.extra_steps == 0, "AC2: unresolved lead extra_steps is 0")

		# Steadfast
		var rng_sf := random(42)
		var p_sf := party(fray_val, "steadfast")
		var walk_sf := Walk.start(rng_sf, "walls", p_sf, pockets(), null, false, false, false, true)
		check(walk_sf != null, "AC2: walk_sf starts")
		var snap_sf := walk_sf.snapshot()
		check(snap_sf.stitches.cue == expected_cue, "AC2: cue matches threshold for steadfast at fray %d" % fray_val)
		check(not snap_sf.stitches.eligible, "AC2: steadfast lead is never eligible for wrong turn")
		check(not snap_sf.stitches.wrong_turn, "AC2: steadfast lead never takes wrong turn")
		check(snap_sf.stitches.extra_steps == 0, "AC2: steadfast lead extra_steps is 0")

	# Test all 5 unravelled traits at FRAY 100 and FRAY 99
	var traits := ["frantic", "hollow", "bitter", "reckless", "cowering"]
	for trait_name in traits:
		# FRAY 99: cue false, eligible false
		var rng_99 := random(42)
		var p_99 := party(99, trait_name)
		var walk_99 := Walk.start(rng_99, "walls", p_99, pockets(), null, false, false, false, true)
		check(walk_99 != null, "AC2: trait %s at 99 starts" % trait_name)
		var snap_99 := walk_99.snapshot()
		check(not snap_99.stitches.cue, "AC2: cue is false at fray 99 for trait %s" % trait_name)
		check(not snap_99.stitches.eligible, "AC2: eligible is false at fray 99 for trait %s" % trait_name)
		check(not snap_99.stitches.wrong_turn, "AC2: wrong_turn is false at fray 99 for trait %s" % trait_name)

		# FRAY 100: cue true, unravelled true, eligible true
		var rng_100 := random(42)
		var p_100 := party(100, trait_name)
		var walk_100 := Walk.start(rng_100, "walls", p_100, pockets(), null, false, false, false, true)
		check(walk_100 != null, "AC2: trait %s at 100 starts" % trait_name)
		var snap_100 := walk_100.snapshot()
		check(snap_100.stitches.cue, "AC2: cue is true at fray 100 for trait %s" % trait_name)
		check(snap_100.stitches.unravelled, "AC2: unravelled is true at fray 100 for trait %s" % trait_name)
		check(snap_100.stitches.eligible, "AC2: eligible is true at fray 100 for trait %s" % trait_name)

	# SWITCH viewpoint tests
	# Case 1: lead rank 1 has FRAY 100, rank 2 has FRAY 0
	var rng_sw1 := random(42)
	var p_sw1 := party(100, "steadfast")
	p_sw1[1].fray = 0
	var walk_sw1 := Walk.start(rng_sw1, "walls", p_sw1, pockets(), null, false, false, false, true)
	check(walk_sw1 != null, "AC2: switch walk 1 starts")
	check(walk_sw1.snapshot().viewpoint == "0", "AC2: initial viewpoint is rank 1 (0)")
	check(walk_sw1.snapshot().stitches.cue, "AC2: cue active initially")
	check(walk_sw1.stitches_cue_visible(), "AC2: cue visible helper initially")
	var sw_res1 := act(walk_sw1, "switch", {"target": "1"})
	check(sw_res1.ok, "AC2: switch to doll 1 succeeds")
	check(walk_sw1.snapshot().viewpoint == "1", "AC2: viewpoint switched to doll 1")
	check(walk_sw1.snapshot().stitches.cue, "AC2: cue remains active after switch to low-fray doll")
	check(walk_sw1.snapshot().stitches.lead_id == "0", "AC2: lead remains rank 1 doll")
	check(walk_sw1.stitches_cue_visible(), "AC2: helper remains visible after switch")

	# Case 2: lead rank 1 has FRAY 99, rank 2 has FRAY 150
	var rng_sw2 := random(42)
	var p_sw2 := party(99, "frantic")
	p_sw2[1].fray = 150
	p_sw2[1].resolve = "frantic"
	var walk_sw2 := Walk.start(rng_sw2, "walls", p_sw2, pockets(), null, false, false, false, true)
	check(walk_sw2 != null, "AC2: switch walk 2 starts")
	check(not walk_sw2.snapshot().stitches.cue, "AC2: cue inactive for rank 1 with fray 99")
	check(not walk_sw2.snapshot().stitches.eligible, "AC2: ineligible despite rank 2 having fray 150")
	var sw_res2 := act(walk_sw2, "switch", {"target": "1"})
	check(sw_res2.ok, "AC2: switch to high fray doll succeeds")
	check(walk_sw2.snapshot().viewpoint == "1", "AC2: viewpoint is now doll 1")
	check(not walk_sw2.snapshot().stitches.cue, "AC2: cue remains inactive when viewing high-fray non-lead")
	check(not walk_sw2.stitches_cue_visible(), "AC2: helper remains false")


func _test_ac3_percentile_wrong_turn_and_extra_steps() -> void:
	var success_witnesses := 0
	var failure_witnesses := 0
	var seen_rolls := {}

	for seed_number in range(50):
		var lead_fray := 100
		var lead_trait := "frantic"

		# Control without stitches
		var ctrl_rng := random(seed_number)
		var ctrl_walk := Walk.start(ctrl_rng, "walls", party(lead_fray, lead_trait), pockets(), null, false, false, false, false)
		check(ctrl_walk != null, "AC3: ctrl_walk starts")
		var ctrl_initial := ctrl_walk.snapshot()
		var orig_steps: int = ctrl_initial.corridor.steps
		var orig_curios: Array = ctrl_initial.curios.duplicate(true)

		# Walk with stitches
		var test_rng := random(seed_number)
		var test_walk := Walk.start(test_rng, "walls", party(lead_fray, lead_trait), pockets(), null, false, false, false, true)
		check(test_walk != null, "AC3: test_walk starts")
		var test_initial := test_walk.snapshot()
		check(test_initial.stitches.eligible, "AC3: stitches is eligible")
		var roll: int = test_initial.stitches.roll
		check(roll >= 1 and roll <= 100, "AC3: roll is in 1..100")
		seen_rolls[roll] = true

		# Curios must not be reordered or modified
		check(test_initial.curios == orig_curios, "AC3: curios placement and ordering identical to control")

		var wrong_turn: bool = test_initial.stitches.wrong_turn
		if roll <= 25:
			success_witnesses += 1
			check(wrong_turn, "AC3: roll %d <= 25 triggers wrong_turn" % roll)
			check(test_initial.stitches.extra_steps == 2, "AC3: extra_steps is 2")
			check(test_initial.corridor.steps == orig_steps + 2, "AC3: in-memory corridor.steps extended by exactly 2")
			check(test_initial.corridor.steps >= 5 and test_initial.corridor.steps <= 8,
				"AC3: exceptional Walk steps run 5..8")

			# Step through both walks and compare forward action counts
			var ctrl_forwards := finish_walk(ctrl_walk)
			var test_forwards := finish_walk(test_walk)
			check(ctrl_forwards == orig_steps, "AC3: control forwards equals original steps")
			check(test_forwards == orig_steps + 2, "AC3: test forwards equals original steps + 2")
			check(test_forwards == ctrl_forwards + 2, "AC3: exactly TWO extra public forward actions")
		else:
			failure_witnesses += 1
			check(not wrong_turn, "AC3: roll %d > 25 does not trigger wrong_turn" % roll)
			check(test_initial.stitches.extra_steps == 0, "AC3: extra_steps is 0")
			check(test_initial.corridor.steps == orig_steps, "AC3: corridor.steps unchanged")

			var ctrl_forwards := finish_walk(ctrl_walk)
			var test_forwards := finish_walk(test_walk)
			check(test_forwards == ctrl_forwards, "AC3: test forwards equals control forwards")

	check(success_witnesses >= 5, "AC3: observed at least 5 wrong_turn successes across seed sweep (got %d)" % success_witnesses)
	check(failure_witnesses >= 5, "AC3: observed at least 5 wrong_turn failures across seed sweep (got %d)" % failure_witnesses)
	check(seen_rolls.size() >= 10, "AC3: nonvacuous variety of percentile rolls observed")


func _test_ac3_replay_and_coexistence() -> void:
	for seed_number in [7, 13, 21]:
		# Two independent instances with all opt-ins enabled
		var rng_a := random(seed_number)
		var rng_b := random(seed_number)
		var walk_a := Walk.start(rng_a, "walls", party(120, "reckless"), pockets(), null, true, true, true, true)
		var walk_b := Walk.start(rng_b, "walls", party(120, "reckless"), pockets(), null, true, true, true, true)
		check(walk_a != null and walk_b != null, "AC3: both coexist walks start")
		check(walk_a.snapshot() == walk_b.snapshot(), "AC3: initial snapshots match byte-for-byte")
		check(rng_a.state == rng_b.state, "AC3: RNG state matches byte-for-byte")

		# Walk both in lockstep
		while walk_a.snapshot().phase == "walking":
			var rec_a: Dictionary
			var rec_b: Dictionary
			if walk_a.tug_unresolved():
				rec_a = act(walk_a, "tug", {"target": "thread_tug", "choice": "yield"})
				rec_b = act(walk_b, "tug", {"target": "thread_tug", "choice": "yield"})
			else:
				rec_a = act(walk_a, "forward")
				rec_b = act(walk_b, "forward")
			check(rec_a.ok and rec_b.ok, "AC3: lockstep action ok")
			check(rec_a == rec_b, "AC3: receipts match byte-for-byte")
			check(walk_a.snapshot() == walk_b.snapshot(), "AC3: snapshots match byte-for-byte at each step")
			check(rng_a.state == rng_b.state, "AC3: RNG state matches byte-for-byte at each step")
		check(walk_a.snapshot().phase == "complete", "AC3: coexistence walk reaches completion")


func _test_ac4_rejections_and_atomicity() -> void:
	var catalogs := Walk.load_catalogs()
	var base_dolls := party(100, "frantic")
	var base_pockets := pockets()

	# 1. Missing wandering_seams record
	var missing_cats := catalogs.duplicate(true)
	var filtered_horrors: Array = []
	for h in missing_cats.horrors:
		if h.id != CrawlingEvent.HORROR_ID:
			filtered_horrors.append(h)
	missing_cats.horrors = filtered_horrors
	var rng1 := random(99)
	var rng1_state := rng1.state
	var dolls1 := base_dolls.duplicate(true)
	var p1 := base_pockets.duplicate(true)
	var w_missing = Walk.start(rng1, "walls", dolls1, p1, missing_cats, false, false, false, true)
	check(w_missing == null, "AC4: missing wandering_seams rejected")
	check(rng1.state == rng1_state, "AC4: RNG untouched on missing horror")
	check(dolls1 == base_dolls and p1 == base_pockets, "AC4: caller dolls and pockets untouched on missing horror")

	# 2. Forged wandering_seams kind
	var forged_cats := catalogs.duplicate(true)
	for h in forged_cats.horrors:
		if h.id == CrawlingEvent.HORROR_ID:
			h.kind = "forged_kind"
	var rng2 := random(99)
	var rng2_state := rng2.state
	var dolls2 := base_dolls.duplicate(true)
	var p2 := base_pockets.duplicate(true)
	var w_forged = Walk.start(rng2, "walls", dolls2, p2, forged_cats, false, false, false, true)
	check(w_forged == null, "AC4: forged horror kind rejected")
	check(rng2.state == rng2_state, "AC4: RNG untouched on forged horror")
	check(dolls2 == base_dolls and p2 == base_pockets, "AC4: caller dolls and pockets untouched on forged horror")

	# 3. Horror ID clashing with doll ID
	var clash_dolls := party(100, "frantic")
	clash_dolls[0].id = CrawlingEvent.HORROR_ID
	var rng3 := random(99)
	var rng3_state := rng3.state
	var w_clash = Walk.start(rng3, "walls", clash_dolls, base_pockets, null, false, false, false, true)
	check(w_clash == null, "AC4: doll ID clashing with horror ID rejected")
	check(rng3.state == rng3_state, "AC4: RNG untouched on doll ID clash")

	# 4. Invalid FRAY values
	for bad_fray in [-1, 201, "invalid"]:
		var bad_dolls := party(0, "frantic")
		bad_dolls[0].fray = bad_fray
		var rng_f := random(99)
		var rng_f_state := rng_f.state
		var w_bad_fray = Walk.start(rng_f, "walls", bad_dolls, base_pockets, null, false, false, false, true)
		check(w_bad_fray == null, "AC4: invalid fray %s rejected" % str(bad_fray))
		check(rng_f.state == rng_f_state, "AC4: RNG untouched on invalid fray")

	# Missing fray field entirely
	var missing_fray_dolls := party(0, "frantic")
	missing_fray_dolls[0].erase("fray")
	var rng_mf := random(99)
	var rng_mf_state := rng_mf.state
	var w_no_fray = Walk.start(rng_mf, "walls", missing_fray_dolls, base_pockets, null, false, false, false, true)
	check(w_no_fray == null, "AC4: missing fray field rejected")
	check(rng_mf.state == rng_mf_state, "AC4: RNG untouched on missing fray")

	# 5. Invalid resolve status
	var bad_resolve_dolls := party(100, "legendary_hero")
	var rng_r := random(99)
	var rng_r_state := rng_r.state
	var w_bad_res = Walk.start(rng_r, "walls", bad_resolve_dolls, base_pockets, null, false, false, false, true)
	check(w_bad_res == null, "AC4: invalid resolve trait rejected")
	check(rng_r.state == rng_r_state, "AC4: RNG untouched on invalid resolve")

	# 6. Action stale protection and malformed commands
	var valid_rng := random(42)
	var valid_walk := Walk.start(valid_rng, "walls", base_dolls, base_pockets, null, false, false, false, true)
	check(valid_walk != null, "AC4: valid walk starts")
	var snap := valid_walk.snapshot()

	# Stale snapshot rejection
	var stale_snap := snap.duplicate(true)
	stale_snap.step = 99
	var stale_rec := valid_walk.act({"kind": "forward", "actor": "0"}, stale_snap)
	check(not stale_rec.ok and stale_rec.error == "stale_snapshot", "AC4: stale snapshot rejected")
	check(valid_walk.snapshot() == snap, "AC4: state untouched after stale rejection")

	# Malformed command rejection
	reject(valid_walk, valid_rng, {"kind": "unsupported_command", "actor": "0"})
	reject(valid_walk, valid_rng, {"kind": "forward", "actor": "wrong_actor"})
	reject(valid_walk, valid_rng, {"kind": "forward"}) # missing actor

	# Snapshot detach test
	var snap_copy := valid_walk.snapshot()
	snap_copy.stitches.cue = false
	snap_copy.stitches.wrong_turn = not snap_copy.stitches.wrong_turn
	snap_copy.corridor.steps = 999
	snap_copy.dolls.clear()
	check(valid_walk.snapshot() == snap, "AC4: mutating snapshot does not affect Walk internal state")

	# Action receipt detach test
	var valid_act_rec := act(valid_walk, "forward")
	check(valid_act_rec.ok, "AC4: valid forward succeeds")
	var after_fwd := valid_walk.snapshot()
	valid_act_rec.snapshot.stitches.clear()
	valid_act_rec.snapshot.corridor.clear()
	check(valid_walk.snapshot() == after_fwd, "AC4: mutating receipt snapshot does not affect Walk internal state")


func _test_ac5_clean_boundaries() -> void:
	# Assert that catalog corridors file has not been modified in memory
	var disk_cats := Walk.load_catalogs()
	for c in disk_cats.corridors:
		check(c.steps >= 3 and c.steps <= 6, "AC5: disk corridor %s steps remain in 3..6" % c.id)
