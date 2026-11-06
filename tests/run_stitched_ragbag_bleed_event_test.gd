extends SceneTree
## Deterministic headless SceneTree regression test for RunStitchedRagbagBleedEvent.
## Validates turning authentic unconsumed Ragbag curio Bleed traps into portable Walk
## status receipts for the next battle (Design v4 STITCHED section 9b, Design v4 section 3).

const Walk = preload("res://scripts/stitched/walk/stitched_walk_rules.gd")
const BleedEvent = preload("res://scripts/run_stitched_ragbag_bleed_event.gd")

var checks := 0
var failures: Array[String] = []
var trap_witnesses := 0


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _party(equipped: bool = true) -> Array:
	var result: Array = []
	for index in 4:
		result.append({
			"id": "doll_" + str(index + 1),
			"rank": index + 1,
			"hp": 30,
			"max_hp": 40,
			"lost": false,
			"fray": 0,
			"glass_eye": true,
			"needle_hand": true
		})
	if equipped:
		result[0].parts = {
			"head": {"id": "seamstress_mending_knot_hat", "tier": 1, "torn": false},
			"arms": {"id": "seamstress_thread_prick_needle", "tier": 1, "torn": false}
		}
	return result


func _pockets() -> Dictionary:
	return {
		"doll_1": ["pins", "dye"],
		"doll_2": [],
		"doll_3": [],
		"doll_4": []
	}


func _initialize() -> void:
	_test_ac1_genuine_trap()
	_test_ac2_safe_and_negative_cases()
	_test_ac3_determinism_and_nonmutation()

	if trap_witnesses < 1:
		failures.append("AC1 requirement failed: at least one real trap witness must be observed")

	if failures.is_empty():
		print("run_stitched_ragbag_bleed_event_test: PASS (%d checks, %d trap witnesses)" % [checks, trap_witnesses])
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("run_stitched_ragbag_bleed_event_test: FAIL (%d failures, %d checks)" % [failures.size(), checks])
		quit(1)


## AC1: From a seeded genuine Ragbag trap and a four-doll active roster,
## project exactly one Bleed-2 receipt for the true reacher.
func _test_ac1_genuine_trap() -> void:
	var catalogs := Walk.load_catalogs()
	_check(not catalogs.is_empty(), "AC1: walk catalogs loaded")

	# Seed 24 in floorboards spawns biting_bundle at step 0; reach triggers trap.
	# Reach with doll_1 who is Hanging by a Thread (hp = 0, lost = false).
	var rng := RandomNumberGenerator.new()
	rng.seed = 24
	var party := _party()
	party[0]["hp"] = 0
	var pockets := _pockets()
	var walk := Walk.start(rng, "floorboards", party, pockets, catalogs)
	_check(walk != null, "AC1: walk started on seed 24")
	if walk == null:
		return

	var snap_start := walk.snapshot()
	var ragbag: Dictionary = {}
	for curio in snap_start.curios:
		if curio.id == BleedEvent.CURIO_ID:
			ragbag = curio
			break
	_check(not ragbag.is_empty(), "AC1: genuine biting_bundle curio found at step %d" % int(ragbag.get("step", -1)))

	# Reach curio with doll_1 (rank 1)
	var reach_res := walk.act({
		"kind": "curio",
		"actor": "doll_1",
		"target": ragbag.instance,
		"choice": "reach"
	}, walk.snapshot())
	_check(bool(reach_res.get("ok")), "AC1: reach action accepted")

	var snap_after := walk.snapshot()
	var genuine_trap: Dictionary = {}
	for p in snap_after.pending:
		if p.get("kind") == BleedEvent.TRAP_KIND and p.get("source") == ragbag.instance:
			genuine_trap = p
			break

	_check(not genuine_trap.is_empty(), "AC1: genuine unconsumed curio_trap descriptor emitted")
	if genuine_trap.is_empty():
		return

	trap_witnesses += 1
	_check(genuine_trap.get("target") == "doll_1", "AC1: trap targets true reacher doll_1")
	_check(not bool(genuine_trap.get("consumed")), "AC1: trap descriptor consumed is false")
	_check(genuine_trap.get("effects") == {"status": "bleed", "amount": 2}, "AC1: trap effects status=bleed amount=2")
	_check(snap_after.dolls[0].get("hp") == 0 and not bool(snap_after.dolls[0].get("lost")),
		"AC1: reacher doll_1 is Hanging by a Thread (hp=0, lost=false)")

	# Project via primary API with curio instance
	var result := BleedEvent.project(genuine_trap, ragbag, snap_after.dolls)
	_check(bool(result.get("ok")), "AC1: projection succeeds on genuine trap with Hanging recipient")
	_check(result.get("error", "") == "", "AC1: error is empty on success")

	var expected_carry := {
		"kind": BleedEvent.STATUS_BLEED,
		"target": "doll_1",
		"amount": BleedEvent.DEFAULT_BLEED_AMOUNT
	}
	_check(result.get("carry") == expected_carry, "AC1: carry matches exact {kind: bleed, target, amount: 2}")
	_check(result.get("receipt") == expected_carry, "AC1: receipt matches exact {kind: bleed, target, amount: 2}")
	_check(result.get("intent") == expected_carry, "AC1: intent matches exact {kind: bleed, target, amount: 2}")

	# Check project_carry helper
	var carry_only := BleedEvent.project_carry(genuine_trap, ragbag, snap_after.dolls)
	_check(carry_only == expected_carry, "AC1: project_carry helper returns exact carry intent")

	# Check project_from_snapshot helper
	var from_snap := BleedEvent.project_from_snapshot(snap_after)
	_check(bool(from_snap.get("ok")), "AC1: project_from_snapshot succeeds on genuine snapshot")
	_check(from_snap.get("carry") == expected_carry, "AC1: snapshot projection carry matches")

	# Check with canonical authored record as record argument
	var canonical_rec := BleedEvent.load_canonical_record()
	_check(not canonical_rec.is_empty(), "AC1: canonical curios.json record loaded")
	var result_with_rec := BleedEvent.project(genuine_trap, ragbag, snap_after.dolls, canonical_rec)
	_check(bool(result_with_rec.get("ok")), "AC1: projection with canonical record succeeds")
	_check(result_with_rec.get("carry") == expected_carry, "AC1: carry with canonical record matches")

	# Test with a different rank recipient (e.g. rank 3 doll_3 after switch)
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 33 # Seed 33 also spawns biting_bundle at step 0
	var walk3 := Walk.start(rng3, "floorboards", _party(), _pockets(), catalogs)
	_check(walk3 != null, "AC1: walk started on seed 33")
	if walk3 != null:
		var ragbag3: Dictionary = walk3.snapshot().curios[0]
		# Switch to doll_3
		var switch_res := walk3.act({"kind": "switch", "actor": "doll_1", "target": "doll_3"}, walk3.snapshot())
		_check(bool(switch_res.get("ok")), "AC1: switch to doll_3 accepted")
		var reach_res3 := walk3.act({
			"kind": "curio",
			"actor": "doll_3",
			"target": ragbag3.instance,
			"choice": "reach"
		}, walk3.snapshot())
		_check(bool(reach_res3.get("ok")), "AC1: doll_3 reach accepted")

		var snap3 := walk3.snapshot()
		var trap3: Dictionary = {}
		for p in snap3.pending:
			if p.get("kind") == BleedEvent.TRAP_KIND and p.get("source") == ragbag3.instance:
				trap3 = p
				break
		_check(not trap3.is_empty(), "AC1: trap3 witnessed for rank 3 doll")
		if not trap3.is_empty():
			trap_witnesses += 1
			_check(trap3.get("target") == "doll_3", "AC1: trap3 target is doll_3")
			var result3 := BleedEvent.project(trap3, ragbag3, snap3.dolls)
			_check(bool(result3.get("ok")), "AC1: projection succeeds for rank 3 recipient")
			_check(result3.get("carry") == {"kind": "bleed", "target": "doll_3", "amount": 2},
				"AC1: carry targets rank 3 doll_3 with amount 2")


## AC2: Safe or invalid choices never bleed. Protected/Leave/consumed/malformed/non-Ragbag
## or unavailable-recipient cases project no receipt and do not change resource or status.
func _test_ac2_safe_and_negative_cases() -> void:
	var catalogs := Walk.load_catalogs()

	# 1. Pins protection witness
	var rng_pins := RandomNumberGenerator.new()
	rng_pins.seed = 24
	var walk_pins := Walk.start(rng_pins, "floorboards", _party(), _pockets(), catalogs)
	var bag_pins: Dictionary = walk_pins.snapshot().curios[0]
	var pin_act := walk_pins.act({
		"kind": "use_item",
		"actor": "doll_1",
		"slot": 0,
		"target": bag_pins.instance
	}, walk_pins.snapshot())
	_check(bool(pin_act.get("ok")), "AC2: pins applied to curio")
	walk_pins.act({
		"kind": "curio",
		"actor": "doll_1",
		"target": bag_pins.instance,
		"choice": "reach"
	}, walk_pins.snapshot())

	var snap_pins: Dictionary = walk_pins.snapshot()
	var pins_trap_list: Array = snap_pins.pending.filter(func(e): return e.get("kind") == BleedEvent.TRAP_KIND)
	_check(pins_trap_list.is_empty(), "AC2: pins prevents trap descriptor from emitting")
	var snap_proj_pins: Dictionary = BleedEvent.project_from_snapshot(snap_pins)
	_check(not bool(snap_proj_pins.get("ok")), "AC2: project_from_snapshot fails closed on pinned curio")
	_check(snap_proj_pins.get("carry", {}).is_empty(), "AC2: no carry on pinned curio")

	# Passing the pins descriptor itself to project
	var pins_entry: Dictionary = snap_pins.pending[0]
	var proj_pins_entry: Dictionary = BleedEvent.project(pins_entry, bag_pins, snap_pins.dolls)
	_check(not bool(proj_pins_entry.get("ok")), "AC2: project fails on pins entry descriptor")
	_check(proj_pins_entry.get("carry", {}).is_empty(), "AC2: no carry on pins entry")

	# 2. Dye protection witness
	var rng_dye := RandomNumberGenerator.new()
	rng_dye.seed = 24
	var walk_dye := Walk.start(rng_dye, "floorboards", _party(), _pockets(), catalogs)
	var bag_dye: Dictionary = walk_dye.snapshot().curios[0]
	var dye_act: Dictionary = walk_dye.act({
		"kind": "use_item",
		"actor": "doll_1",
		"slot": 1,
		"target": "doll_1"
	}, walk_dye.snapshot())
	_check(bool(dye_act.get("ok")), "AC2: dye applied to doll_1")
	walk_dye.act({
		"kind": "curio",
		"actor": "doll_1",
		"target": bag_dye.instance,
		"choice": "reach"
	}, walk_dye.snapshot())

	var snap_dye: Dictionary = walk_dye.snapshot()
	var dye_trap_list: Array = snap_dye.pending.filter(func(e): return e.get("kind") == BleedEvent.TRAP_KIND)
	_check(dye_trap_list.is_empty(), "AC2: dye prevents trap descriptor from emitting")
	var snap_proj_dye: Dictionary = BleedEvent.project_from_snapshot(snap_dye)
	_check(not bool(snap_proj_dye.get("ok")), "AC2: project_from_snapshot fails closed on dyed reacher")
	_check(snap_proj_dye.get("carry", {}).is_empty(), "AC2: no carry on dyed reacher")

	# 3. Leave choice
	var rng_leave := RandomNumberGenerator.new()
	rng_leave.seed = 24
	var walk_leave := Walk.start(rng_leave, "floorboards", _party(), _pockets(), catalogs)
	var bag_leave: Dictionary = walk_leave.snapshot().curios[0]
	var leave_act: Dictionary = walk_leave.act({
		"kind": "curio",
		"actor": "doll_1",
		"target": bag_leave.instance,
		"choice": "leave"
	}, walk_leave.snapshot())
	_check(bool(leave_act.get("ok")), "AC2: leave accepted")
	var snap_leave: Dictionary = walk_leave.snapshot()
	var leave_trap_list: Array = snap_leave.pending.filter(func(e): return e.get("kind") == BleedEvent.TRAP_KIND)
	_check(leave_trap_list.is_empty(), "AC2: leave emits no trap descriptor")
	var snap_proj_leave := BleedEvent.project_from_snapshot(snap_leave)
	_check(not bool(snap_proj_leave.get("ok")), "AC2: project_from_snapshot fails closed on leave")
	_check(snap_proj_leave.get("carry", {}).is_empty(), "AC2: no carry on leave")

	# Base genuine descriptors for negative tests
	var base_trap := {
		"kind": "curio_trap",
		"source": "curio_1",
		"target": "doll_1",
		"consumed": false,
		"effects": {"status": "bleed", "amount": 2}
	}
	var base_curio := {"instance": "curio_1", "id": "biting_bundle", "kind": "ragbag"}
	var base_roster: Array = _party()

	# 4. Consumed descriptor
	var consumed_trap := base_trap.duplicate(true)
	consumed_trap["consumed"] = true
	var res_consumed := BleedEvent.project(consumed_trap, base_curio, base_roster)
	_check(not bool(res_consumed.get("ok")), "AC2: consumed descriptor rejected")
	_check(res_consumed.get("carry", {}).is_empty(), "AC2: no carry on consumed descriptor")

	# 5. Forged / mismatched descriptor source
	var forged_source_curio := {"instance": "curio_999", "id": "biting_bundle", "kind": "ragbag"}
	var res_forged := BleedEvent.project(base_trap, forged_source_curio, base_roster)
	_check(not bool(res_forged.get("ok")), "AC2: mismatched source instance rejected")
	_check(res_forged.get("carry", {}).is_empty(), "AC2: no carry on mismatched source")

	# 6. Non-Ragbag curio (e.g. pin_nest or dummy)
	var pincushion_curio := {"instance": "curio_1", "id": "pin_nest", "kind": "pincushion"}
	var res_non_ragbag := BleedEvent.project(base_trap, pincushion_curio, base_roster)
	_check(not bool(res_non_ragbag.get("ok")), "AC2: non-Ragbag curio rejected")
	_check(res_non_ragbag.get("carry", {}).is_empty(), "AC2: no carry on non-Ragbag curio")

	# 7. Wrong / unknown target
	var unknown_target_trap := base_trap.duplicate(true)
	unknown_target_trap["target"] = "doll_phantom"
	var res_unknown := BleedEvent.project(unknown_target_trap, base_curio, base_roster)
	_check(not bool(res_unknown.get("ok")), "AC2: unknown target recipient rejected")
	_check(res_unknown.get("carry", {}).is_empty(), "AC2: no carry on unknown target")

	# 8. Lost doll recipient
	var lost_roster: Array = _party()
	lost_roster[0]["lost"] = true
	var res_lost := BleedEvent.project(base_trap, base_curio, lost_roster)
	_check(not bool(res_lost.get("ok")), "AC2: lost doll recipient rejected")
	_check(res_lost.get("carry", {}).is_empty(), "AC2: no carry on lost doll")

	# 9. Invalid doll rank (< 1 or > 4)
	var bad_rank_roster: Array = _party()
	bad_rank_roster[0]["rank"] = 5
	var res_bad_rank := BleedEvent.project(base_trap, base_curio, bad_rank_roster)
	_check(not bool(res_bad_rank.get("ok")), "AC2: invalid doll rank rejected")
	_check(res_bad_rank.get("carry", {}).is_empty(), "AC2: no carry on invalid rank")

	# 10. Doll with negative HP (hp < 0 remains invalid)
	var negative_hp_roster: Array = _party()
	negative_hp_roster[0]["hp"] = -1
	var res_negative_hp := BleedEvent.project(base_trap, base_curio, negative_hp_roster)
	_check(not bool(res_negative_hp.get("ok")), "AC2: doll with negative HP rejected")
	_check(res_negative_hp.get("carry", {}).is_empty(), "AC2: no carry on negative HP doll")

	# 10b. Doll with hp == 0 and lost == false (Hanging by a Thread) is admitted
	var hanging_roster: Array = _party()
	hanging_roster[0]["hp"] = 0
	hanging_roster[0]["lost"] = false
	var res_hanging := BleedEvent.project(base_trap, base_curio, hanging_roster)
	_check(bool(res_hanging.get("ok")), "AC1: doll with hp==0 and lost==false (Hanging) is admitted")
	_check(res_hanging.get("carry") == {"kind": "bleed", "target": "doll_1", "amount": 2},
		"AC1: carry projected for Hanging doll")

	# 10c. Doll with hp == 0 and lost == true is rejected
	var lost_hanging_roster: Array = _party()
	lost_hanging_roster[0]["hp"] = 0
	lost_hanging_roster[0]["lost"] = true
	var res_lost_hanging := BleedEvent.project(base_trap, base_curio, lost_hanging_roster)
	_check(not bool(res_lost_hanging.get("ok")), "AC2: lost doll with 0 HP rejected")
	_check(res_lost_hanging.get("carry", {}).is_empty(), "AC2: no carry on lost doll with 0 HP")

	# 11. Missing status
	var missing_status_trap := base_trap.duplicate(true)
	missing_status_trap["effects"] = {"amount": 2}
	var res_no_status := BleedEvent.project(missing_status_trap, base_curio, base_roster)
	_check(not bool(res_no_status.get("ok")), "AC2: missing status rejected")
	_check(res_no_status.get("carry", {}).is_empty(), "AC2: no carry on missing status")

	# 12. Non-bleed status
	var wrong_status_trap := base_trap.duplicate(true)
	wrong_status_trap["effects"] = {"status": "stun", "amount": 2}
	var res_wrong_status := BleedEvent.project(wrong_status_trap, base_curio, base_roster)
	_check(not bool(res_wrong_status.get("ok")), "AC2: wrong status rejected")
	_check(res_wrong_status.get("carry", {}).is_empty(), "AC2: no carry on wrong status")

	# 13. Nonpositive amount (0, -1)
	for nonpos in [0, -1, -5]:
		var nonpos_trap := base_trap.duplicate(true)
		nonpos_trap["effects"] = {"status": "bleed", "amount": nonpos}
		var res_nonpos := BleedEvent.project(nonpos_trap, base_curio, base_roster)
		_check(not bool(res_nonpos.get("ok")), "AC2: nonpositive amount %d rejected" % nonpos)
		_check(res_nonpos.get("carry", {}).is_empty(), "AC2: no carry on nonpositive amount")

	# 14. Noninteger amount (float, string, null)
	for nonint in [2.5, "2", null, []]:
		var nonint_trap := base_trap.duplicate(true)
		nonint_trap["effects"] = {"status": "bleed", "amount": nonint}
		var res_nonint := BleedEvent.project(nonint_trap, base_curio, base_roster)
		_check(not bool(res_nonint.get("ok")), "AC2: noninteger amount %s rejected" % str(nonint))
		_check(res_nonint.get("carry", {}).is_empty(), "AC2: no carry on noninteger amount")

	# 15. Non-dictionary inputs
	for bad_input in [null, 42, "trap", []]:
		var res_bad := BleedEvent.project(bad_input, base_curio, base_roster)
		_check(not bool(res_bad.get("ok")), "AC2: non-dictionary pending input rejected")
		_check(res_bad.get("carry", {}).is_empty(), "AC2: no carry on invalid input type")


## AC3: Determinism and nonmutation.
## Preconditions: snapshot/roster/Walk RNG before projection and two calls on the same genuine descriptor.
## Verification: identical receipt results, unchanged original pending and snapshot/roster/pockets/WHIRR/RNG.
func _test_ac3_determinism_and_nonmutation() -> void:
	var catalogs := Walk.load_catalogs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 24
	var party := _party()
	var pockets := _pockets()
	var walk := Walk.start(rng, "floorboards", party, pockets, catalogs)
	var bag: Dictionary = walk.snapshot().curios[0]

	walk.act({"kind": "curio", "actor": "doll_1", "target": bag.instance, "choice": "reach"}, walk.snapshot())

	var snap_before: Dictionary = walk.snapshot()
	var genuine_trap: Dictionary = {}
	for p in snap_before.pending:
		if p.get("kind") == BleedEvent.TRAP_KIND and p.get("source") == bag.instance:
			genuine_trap = p
			break
	_check(not genuine_trap.is_empty(), "AC3: genuine trap descriptor present")

	# Deep snapshots of all inputs before projection
	var trap_input_before: Dictionary = genuine_trap.duplicate(true)
	var curio_input_before: Dictionary = bag.duplicate(true)
	var roster_input_before: Array = snap_before.dolls.duplicate(true)
	var snapshot_before: Dictionary = snap_before.duplicate(true)
	var rng_state_before: int = rng.state

	# Call 1
	var result1: Dictionary = BleedEvent.project(genuine_trap, bag, snap_before.dolls)
	# Call 2
	var result2: Dictionary = BleedEvent.project(genuine_trap, bag, snap_before.dolls)

	# Identical results
	_check(result1 == result2, "AC3: two projections on same descriptor return identical results")
	_check(result1.get("carry") == result2.get("carry"), "AC3: carry intents identical")
	_check(result1.get("receipt") == result2.get("receipt"), "AC3: receipts identical")
	_check(result1.get("intent") == result2.get("intent"), "AC3: intents identical")

	# Check deep equality of all inputs before and after
	_check(genuine_trap == trap_input_before, "AC3: original pending descriptor completely unchanged")
	_check(bag == curio_input_before, "AC3: curio instance dictionary completely unchanged")
	_check(snap_before.dolls == roster_input_before, "AC3: dolls roster completely unchanged")
	_check(walk.snapshot() == snapshot_before, "AC3: entire walk snapshot unchanged")
	_check(walk.snapshot().pockets == snapshot_before.pockets, "AC3: pockets completely unchanged")
	_check(walk.snapshot().whirr == snapshot_before.whirr, "AC3: WHIRR completely unchanged")
	_check(rng.state == rng_state_before, "AC3: RNG state completely unchanged (zero RNG draws)")

	# Verify detached return by mutating result1
	var carry1: Dictionary = result1.get("carry")
	carry1["mutated"] = true
	_check(not result2.get("carry").has("mutated"), "AC3: mutating one result does not affect subsequent results")
	_check(not genuine_trap.has("mutated"), "AC3: mutating result does not affect input descriptor")
