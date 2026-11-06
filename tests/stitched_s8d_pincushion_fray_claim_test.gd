extends SceneTree

const Walk = preload("res://scripts/stitched/walk/stitched_walk_rules.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_test_ac1_seeded_pin_nest_fray_and_claim()
	_test_ac2_claim_consumption_revision_and_rejections()
	_test_ac3_negative_refusals_and_controlled_checks()
	for failure in failures:
		printerr(failure)
	print("stitched_s8d_pincushion_fray_claim_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _rng(seed_number: int) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = seed_number
	return random


func _dolls() -> Array:
	return [
		{"id": "seamstress", "rank": 1, "hp": 30, "max_hp": 30, "lost": false, "fray": 0,
		 "parts": {"head": {"id": "seamstress_mending_knot_hat", "tier": 1, "torn": false},
		           "arms": {"id": "seamstress_thread_prick_needle", "tier": 1, "torn": false}}},
		{"id": "b", "rank": 2, "hp": 25, "max_hp": 25, "lost": false, "fray": 0},
		{"id": "c", "rank": 3, "hp": 20, "max_hp": 20, "lost": false, "fray": 0},
		{"id": "d", "rank": 4, "hp": 35, "max_hp": 35, "lost": false, "fray": 0}
	]


func _pockets() -> Dictionary:
	return {
		"seamstress": ["pins", "dye"],
		"b": ["thimble_tonic"],
		"c": ["starch"],
		"d": []
	}


func _act(walk: StitchedWalkRules, kind: String, extra: Dictionary = {}) -> Dictionary:
	var command := {"kind": kind, "actor": walk.snapshot().viewpoint}
	command.merge(extra)
	return walk.act(command, walk.snapshot())


func _finish_walk(walk: StitchedWalkRules) -> void:
	while walk.snapshot().phase == "walking":
		var result: Dictionary
		if walk.tug_unresolved():
			result = _act(walk, "tug", {"target": "thread_tug", "choice": "yield"})
		else:
			result = _act(walk, "forward")
		_check(result.ok, "forward step succeeds during walk completion")


func _find_pin_nest(walk: StitchedWalkRules) -> Dictionary:
	for curio in walk.snapshot().curios:
		if curio.id == "pin_nest":
			return curio
	return {}


func _test_ac1_seeded_pin_nest_fray_and_claim() -> void:
	# Bounded search to discover seeds where pin_nest yields fray
	var fray_seed := -1
	for s in range(100):
		var test_rng := _rng(s)
		var test_walk := Walk.start(test_rng, "walls", _dolls(), _pockets())
		if test_walk == null:
			continue
		var c := _find_pin_nest(test_walk)
		if c.is_empty():
			continue
		while test_walk.snapshot().step < c.step:
			_act(test_walk, "forward")
		var r := _act(test_walk, "curio", {"target": c.instance, "choice": "pull"})
		if r.ok:
			for effect in r.snapshot.pending:
				if effect.source == c.instance and effect.kind == "curio_fray":
					fray_seed = s
					break
		if fray_seed >= 0:
			break

	_check(fray_seed >= 0, "AC1: bounded seed search witnesses authentic pin_nest fray outcome")

	# Single-pull witness: Seed 43
	var rng := _rng(43)
	var walk := Walk.start(rng, "walls", _dolls(), _pockets())
	_check(walk != null, "AC1: seeded real Walk starts")
	if walk == null:
		return

	var pin_curio := _find_pin_nest(walk)
	_check(not pin_curio.is_empty(), "AC1: pin_nest curio scheduled in corridor")
	_check(pin_curio.step == 0, "AC1: pin_nest is at step 0 for seed 43")

	var snap_before_pull := walk.snapshot()
	var whirr_before: int = snap_before_pull.whirr
	var fray_before: int = snap_before_pull.dolls[0].fray
	_check(fray_before == 0, "AC1: puller initial fray is 0")

	# Pull pins on the pincushion
	var pull_receipt := _act(walk, "curio", {"target": pin_curio.instance, "choice": "pull"})
	_check(pull_receipt.ok, "AC1: accepted pull on pin_nest succeeds")
	_check(pull_receipt.snapshot.whirr == whirr_before + 5, "AC1: accepted pull adds exactly 5 WHIRR")
	_check(pull_receipt.snapshot.dolls[0].fray == fray_before + 15, "AC1: puller Walk state has exactly +15 fray")

	# Verify unconsumed curio_fray descriptor
	var pending_fray: Array = []
	for effect in pull_receipt.snapshot.pending:
		if effect.source == pin_curio.instance and effect.kind == "curio_fray":
			pending_fray.append(effect)
	_check(pending_fray.size() == 1, "AC1: exactly one matching curio_fray descriptor queued")
	var fray_desc: Dictionary = pending_fray[0]
	_check(fray_desc == {
		"kind": "curio_fray",
		"source": pin_curio.instance,
		"target": "seamstress",
		"consumed": false,
		"effects": {"amount": 15, "already_applied": true}
	}, "AC1: exact authentic unconsumed curio_fray descriptor shape")

	# Multi-pull witness: Seed 6 pulls 4 times with progressive odds, 5 WHIRR each
	var rng_multi := _rng(6)
	var walk_multi := Walk.start(rng_multi, "walls", _dolls(), _pockets())
	var pin_multi := _find_pin_nest(walk_multi)
	_check(not pin_multi.is_empty() and pin_multi.step == 0, "AC1: multi-pull pin_nest at step 0")
	var prev_whirr: int = walk_multi.snapshot().whirr
	for pull_idx in range(4):
		var r := _act(walk_multi, "curio", {"target": pin_multi.instance, "choice": "pull"})
		_check(r.ok, "AC1: multi-pull " + str(pull_idx + 1) + " accepted")
		_check(r.snapshot.whirr == prev_whirr + 5, "AC1: pull " + str(pull_idx + 1) + " adds 5 WHIRR")
		prev_whirr = r.snapshot.whirr
	_check(walk_multi.snapshot().dolls[0].fray == 15, "AC1: multi-pull 4th pull waking branch adds +15 fray")

	# Reproducibility under identical seed
	var rng_replay := _rng(43)
	var walk_replay := Walk.start(rng_replay, "walls", _dolls(), _pockets())
	var r_replay := _act(walk_replay, "curio", {"target": pin_curio.instance, "choice": "pull"})
	_check(r_replay.snapshot == pull_receipt.snapshot, "AC1: identical snapshot under same seed")
	_check(rng_replay.state == rng.state, "AC1: identical RNG state under same seed")

	# Finish walk through accepted forward commands
	_finish_walk(walk)
	_check(walk.snapshot().phase == "complete", "AC1: Walk reaches phase complete")

	# Capture completed snapshot before claim
	var completed_snap := walk.snapshot()
	var dolls_before_claim: Array = completed_snap.dolls.duplicate(true)
	var pockets_before_claim: Dictionary = completed_snap.pockets.duplicate(true)
	var rng_before_claim: int = rng.state

	# Claim the one-shot pincushion fray consequence
	var claim_receipt := walk.claim_pincushion_fray(completed_snap, pin_curio.instance)
	_check(claim_receipt.ok, "AC1: claim_pincushion_fray returns ok=true")
	_check(claim_receipt.error.is_empty(), "AC1: error is empty on success")
	_check(claim_receipt.kind == "curio_fray", "AC1: kind is curio_fray")
	_check(claim_receipt.source == pin_curio.instance, "AC1: actual scheduled source instance")
	_check(claim_receipt.target == "seamstress", "AC1: actual doll target returned")
	_check(claim_receipt.fray_delta == 15, "AC1: fray_delta is 15")
	_check(claim_receipt.already_applied == true, "AC1: already_applied is true")
	_check(claim_receipt.snapshot == walk.snapshot(), "AC1: receipt contains detached resulting snapshot")

	# Verify no additional fray charged and no RNG mutation
	_check(walk.snapshot().dolls == dolls_before_claim, "AC1: dolls unchanged by claim (no second fray)")
	_check(walk.snapshot().dolls[0].fray == 15, "AC1: doll fray remains exactly 15")
	_check(walk.snapshot().pockets == pockets_before_claim, "AC1: pockets unchanged")
	_check(rng.state == rng_before_claim, "AC1: RNG state not drawn during claim")


func _test_ac2_claim_consumption_revision_and_rejections() -> void:
	var rng := _rng(43)
	var walk := Walk.start(rng, "walls", _dolls(), _pockets())
	var pin_curio := _find_pin_nest(walk)
	_act(walk, "curio", {"target": pin_curio.instance, "choice": "pull"})
	_finish_walk(walk)

	var before_snap := walk.snapshot()
	var rng_before: int = rng.state
	var dolls_before: Array = before_snap.dolls.duplicate(true)

	var receipt := walk.claim_pincushion_fray(before_snap, pin_curio.instance)
	_check(receipt.ok, "AC2: first claim accepted")

	var after_snap := walk.snapshot()

	# Compare whole state before and after: ONLY revision and consumed marker differ
	var expected_after := before_snap.duplicate(true)
	expected_after.revision += 1
	for effect in expected_after.pending:
		if effect.source == pin_curio.instance and effect.kind == "curio_fray":
			effect.consumed = true

	_check(after_snap == expected_after, "AC2: claiming commits consumption exactly once and increments revision once")
	_check(rng.state == rng_before, "AC2: claim performs zero RNG draws")
	_check(after_snap.dolls == dolls_before, "AC2: no second +15 charged to puller or any doll")

	# Repeated claim with current snapshot fails
	var repeated_receipt := walk.claim_pincushion_fray(walk.snapshot(), pin_curio.instance)
	_check(not repeated_receipt.ok, "AC2: repeated claim fails")
	_check(not repeated_receipt.error.is_empty(), "AC2: repeated claim returns stable error reason")
	_check(walk.snapshot() == after_snap and rng.state == rng_before, "AC2: repeated claim leaves state and RNG unchanged")

	# Replay with stale (pre-claim) expected snapshot fails
	var stale_receipt := walk.claim_pincushion_fray(before_snap, pin_curio.instance)
	_check(not stale_receipt.ok and not stale_receipt.error.is_empty(), "AC2: stale snapshot claim fails")
	_check(walk.snapshot() == after_snap and rng.state == rng_before, "AC2: stale refusal mutates nothing")

	# Multi-pull walk (seed 6) preserves pending loot while consuming only fray descriptor
	var rng_multi := _rng(6)
	var walk_multi := Walk.start(rng_multi, "walls", _dolls(), _pockets())
	var pin_multi := _find_pin_nest(walk_multi)
	for i in range(4):
		_act(walk_multi, "curio", {"target": pin_multi.instance, "choice": "pull"})
	_finish_walk(walk_multi)

	var multi_before := walk_multi.snapshot()
	var multi_receipt := walk_multi.claim_pincushion_fray(multi_before, pin_multi.instance)
	_check(multi_receipt.ok, "AC2: multi-pull completed walk fray claimed successfully")
	var multi_after := walk_multi.snapshot()
	var loot_descriptors: Array = []
	for effect in multi_after.pending:
		if effect.source == pin_multi.instance and effect.kind == "curio_loot":
			loot_descriptors.append(effect)
			_check(effect.consumed == false, "AC2: pending loot descriptors preserved unconsumed")
	_check(loot_descriptors.size() > 0, "AC2: multi-pull generated authentic loot descriptors")

	# Independent seeded claim replay: identical receipts and post-claim state
	var seed_val := 43
	var r1 := _rng(seed_val)
	var r2 := _rng(seed_val)
	var w1 := Walk.start(r1, "walls", _dolls(), _pockets())
	var w2 := Walk.start(r2, "walls", _dolls(), _pockets())
	_act(w1, "curio", {"target": pin_curio.instance, "choice": "pull"})
	_act(w2, "curio", {"target": pin_curio.instance, "choice": "pull"})
	_finish_walk(w1)
	_finish_walk(w2)

	_check(w1.snapshot() == w2.snapshot(), "AC2: independent seeded walks match before claim")
	var rc1 := w1.claim_pincushion_fray(w1.snapshot(), pin_curio.instance)
	var rc2 := w2.claim_pincushion_fray(w2.snapshot(), pin_curio.instance)
	_check(rc1 == rc2, "AC2: independent seeded claim receipts match identically")
	_check(w1.snapshot() == w2.snapshot(), "AC2: independent post-claim snapshots match identically")
	_check(r1.state == r2.state, "AC2: independent post-claim RNG states match identically")


func _test_ac3_negative_refusals_and_controlled_checks() -> void:
	# Negative 1: Leave outcome yields no fray descriptor
	var rng_leave := _rng(43)
	var walk_leave := Walk.start(rng_leave, "walls", _dolls(), _pockets())
	var curio_leave := _find_pin_nest(walk_leave)
	_act(walk_leave, "curio", {"target": curio_leave.instance, "choice": "leave"})
	_finish_walk(walk_leave)
	var snap_leave := walk_leave.snapshot()
	var rng_leave_state := rng_leave.state
	var rec_leave := walk_leave.claim_pincushion_fray(snap_leave, curio_leave.instance)
	_check(not rec_leave.ok and not rec_leave.error.is_empty(), "AC3: Leave outcome refused")
	_check(walk_leave.snapshot() == snap_leave and rng_leave.state == rng_leave_state, "AC3: Leave refusal mutates nothing")

	# Negative 2: Pins protection avoids the trap
	var rng_pins := _rng(43)
	var walk_pins := Walk.start(rng_pins, "walls", _dolls(), _pockets())
	var curio_pins := _find_pin_nest(walk_pins)
	var pin_use := _act(walk_pins, "use_item", {"slot": 0, "target": curio_pins.instance})
	_check(pin_use.ok, "AC3: pin_nest pinned shut with pins item")
	_act(walk_pins, "curio", {"target": curio_pins.instance, "choice": "pull"})
	_finish_walk(walk_pins)
	var snap_pins := walk_pins.snapshot()
	var rng_pins_state := rng_pins.state
	var rec_pins := walk_pins.claim_pincushion_fray(snap_pins, curio_pins.instance)
	_check(not rec_pins.ok and not rec_pins.error.is_empty(), "AC3: pins-protected pull refused")
	_check(walk_pins.snapshot() == snap_pins and rng_pins.state == rng_pins_state, "AC3: pins refusal mutates nothing")

	# Negative 3: Dye protection avoids the trap
	var rng_dye := _rng(43)
	var walk_dye := Walk.start(rng_dye, "walls", _dolls(), _pockets())
	var curio_dye := _find_pin_nest(walk_dye)
	var dye_use := _act(walk_dye, "use_item", {"slot": 1, "target": "seamstress"})
	_check(dye_use.ok, "AC3: seamstress dyed with dye item")
	_act(walk_dye, "curio", {"target": curio_dye.instance, "choice": "pull"})
	_finish_walk(walk_dye)
	var snap_dye := walk_dye.snapshot()
	var rng_dye_state := rng_dye.state
	var rec_dye := walk_dye.claim_pincushion_fray(snap_dye, curio_dye.instance)
	_check(not rec_dye.ok and not rec_dye.error.is_empty(), "AC3: dye-protected pull refused")
	_check(walk_dye.snapshot() == snap_dye and rng_dye.state == rng_dye_state, "AC3: dye refusal mutates nothing")

	# Negative 4: Fight branch (Seed 9 wakes on pull 2 and yields curio_fight)
	var rng_fight := _rng(9)
	var walk_fight := Walk.start(rng_fight, "walls", _dolls(), _pockets())
	var curio_fight := _find_pin_nest(walk_fight)
	_act(walk_fight, "curio", {"target": curio_fight.instance, "choice": "pull"})
	_act(walk_fight, "curio", {"target": curio_fight.instance, "choice": "pull"})
	_finish_walk(walk_fight)
	var snap_fight := walk_fight.snapshot()
	var has_fight_desc := false
	for effect in snap_fight.pending:
		if effect.source == curio_fight.instance and effect.kind == "curio_fight":
			has_fight_desc = true
	_check(has_fight_desc, "AC3: seed 9 witnesses authentic curio_fight descriptor")
	var rec_fight := walk_fight.claim_pincushion_fray(snap_fight, curio_fight.instance)
	_check(not rec_fight.ok and not rec_fight.error.is_empty(), "AC3: fight branch outcome refused")
	_check(walk_fight.snapshot() == snap_fight, "AC3: fight refusal mutates nothing")

	# Negative 5: Incomplete walk (phase == "walking")
	var rng_incomplete := _rng(43)
	var walk_incomplete := Walk.start(rng_incomplete, "walls", _dolls(), _pockets())
	var curio_incomplete := _find_pin_nest(walk_incomplete)
	_act(walk_incomplete, "curio", {"target": curio_incomplete.instance, "choice": "pull"})
	var snap_incomplete := walk_incomplete.snapshot()
	_check(snap_incomplete.phase == "walking", "AC3: walk is currently walking")
	var rec_incomplete := walk_incomplete.claim_pincushion_fray(snap_incomplete, curio_incomplete.instance)
	_check(not rec_incomplete.ok and rec_incomplete.reason == "walk_incomplete", "AC3: incomplete walk claim refused with walk_incomplete")
	_check(walk_incomplete.snapshot() == snap_incomplete, "AC3: incomplete walk refusal mutates nothing")

	# Negative 6: Wrong instance name and different curio kind
	var rng_wrong := _rng(43)
	var walk_wrong := Walk.start(rng_wrong, "walls", _dolls(), _pockets())
	var curio_real := _find_pin_nest(walk_wrong)
	_act(walk_wrong, "curio", {"target": curio_real.instance, "choice": "pull"})
	_finish_walk(walk_wrong)
	var snap_wrong := walk_wrong.snapshot()

	var rec_nonexistent := walk_wrong.claim_pincushion_fray(snap_wrong, "curio_nonexistent")
	_check(not rec_nonexistent.ok and rec_nonexistent.reason == "curio_not_found", "AC3: nonexistent curio instance refused")

	# Check claiming a non-pin_nest curio (e.g. pattern_scraps)
	for curio in snap_wrong.curios:
		if curio.id != "pin_nest":
			var rec_not_pin := walk_wrong.claim_pincushion_fray(snap_wrong, curio.instance)
			_check(not rec_not_pin.ok and rec_not_pin.reason == "curio_not_pincushion", "AC3: non-pincushion curio refused")

	# Negative 7: Forged snapshots rejected
	var forged_consumed := snap_wrong.duplicate(true)
	for effect in forged_consumed.pending:
		if effect.source == curio_real.instance and effect.kind == "curio_fray":
			effect.consumed = true
	var rec_forged1 := walk_wrong.claim_pincushion_fray(forged_consumed, curio_real.instance)
	_check(not rec_forged1.ok and rec_forged1.reason == "stale_snapshot", "AC3: forged consumed snapshot refused")

	var forged_effects := snap_wrong.duplicate(true)
	for effect in forged_effects.pending:
		if effect.source == curio_real.instance and effect.kind == "curio_fray":
			effect.effects = {"amount": 99, "already_applied": true}
	var rec_forged2 := walk_wrong.claim_pincushion_fray(forged_effects, curio_real.instance)
	_check(not rec_forged2.ok and rec_forged2.reason == "stale_snapshot", "AC3: forged effects snapshot refused")

	# Negative 8: External RNG drift rejected
	walk_wrong._rng.randi()
	var drifted_rng := walk_wrong._rng.state
	var rec_drift := walk_wrong.claim_pincushion_fray(snap_wrong, curio_real.instance)
	_check(not rec_drift.ok and rec_drift.reason == "stale_snapshot", "AC3: external RNG drift refused")
	_check(walk_wrong._rng.state == drifted_rng, "AC3: RNG drift refusal does not rewind external RNG")
	walk_wrong._rng.state = snap_wrong.rng

	# Negative 9: Controlled bad-descriptor checks on internal state
	var walk_ctrl := Walk.start(_rng(43), "walls", _dolls(), _pockets())
	var c_ctrl := _find_pin_nest(walk_ctrl)
	_act(walk_ctrl, "curio", {"target": c_ctrl.instance, "choice": "pull"})
	_finish_walk(walk_ctrl)

	# Controlled check 9a: Duplicate fray descriptor
	var original_pending: Array = walk_ctrl._state.pending.duplicate(true)
	var fray_desc_copy: Dictionary = {}
	for p in walk_ctrl._state.pending:
		if p.source == c_ctrl.instance and p.kind == "curio_fray":
			fray_desc_copy = p.duplicate(true)
	walk_ctrl._state.pending.append(fray_desc_copy)
	var rec_duplicate := walk_ctrl.claim_pincushion_fray(walk_ctrl.snapshot(), c_ctrl.instance)
	_check(not rec_duplicate.ok and rec_duplicate.reason == "duplicate_curio_fray_descriptor", "AC3: duplicate fray descriptor refused")
	walk_ctrl._state.pending = original_pending.duplicate(true)

	# Controlled check 9b: Conflicting fight descriptor
	walk_ctrl._state.pending.append({"kind": "curio_fight", "source": c_ctrl.instance, "target": "seamstress", "consumed": false, "effects": {}})
	var rec_conflict := walk_ctrl.claim_pincushion_fray(walk_ctrl.snapshot(), c_ctrl.instance)
	_check(not rec_conflict.ok and rec_conflict.reason == "conflicting_curio_descriptors", "AC3: conflicting fight descriptor refused")
	walk_ctrl._state.pending = original_pending.duplicate(true)

	# Controlled check 9c: Tampered effects amount
	for p in walk_ctrl._state.pending:
		if p.source == c_ctrl.instance and p.kind == "curio_fray":
			p.effects = {"amount": 99, "already_applied": true}
	var rec_bad_effects := walk_ctrl.claim_pincushion_fray(walk_ctrl.snapshot(), c_ctrl.instance)
	_check(not rec_bad_effects.ok and rec_bad_effects.reason == "invalid_curio_fray_effects", "AC3: tampered effects amount refused")
	walk_ctrl._state.pending = original_pending.duplicate(true)

	# Controlled check 9d: Tampered descriptor shape (extra key)
	for p in walk_ctrl._state.pending:
		if p.source == c_ctrl.instance and p.kind == "curio_fray":
			p["tampered"] = true
	var rec_bad_shape := walk_ctrl.claim_pincushion_fray(walk_ctrl.snapshot(), c_ctrl.instance)
	_check(not rec_bad_shape.ok and rec_bad_shape.reason == "invalid_descriptor_shape", "AC3: tampered descriptor shape refused")
	walk_ctrl._state.pending = original_pending.duplicate(true)

	# Controlled check 9e: Invalid target doll
	for p in walk_ctrl._state.pending:
		if p.source == c_ctrl.instance and p.kind == "curio_fray":
			p.target = "unknown_doll"
	var rec_bad_target := walk_ctrl.claim_pincushion_fray(walk_ctrl.snapshot(), c_ctrl.instance)
	_check(not rec_bad_target.ok and rec_bad_target.reason == "invalid_target_doll", "AC3: invalid target doll refused")
	walk_ctrl._state.pending = original_pending.duplicate(true)

	# Controlled check 9f: Puller fray missing paid consequence (< 15)
	walk_ctrl._state.dolls[0].fray = 0
	var rec_missing_fray := walk_ctrl.claim_pincushion_fray(walk_ctrl.snapshot(), c_ctrl.instance)
	_check(not rec_missing_fray.ok and rec_missing_fray.reason == "doll_fray_missing_consequence", "AC3: doll fray missing paid consequence refused")
	walk_ctrl._state.dolls[0].fray = 15

	# Valid claim succeeds after restoring state
	var rec_valid := walk_ctrl.claim_pincushion_fray(walk_ctrl.snapshot(), c_ctrl.instance)
	_check(rec_valid.ok, "AC3: valid claim succeeds on restored state")

	# Non-viewpoint actor switch test: verify puller doll is accurately targeted
	var rng_switch := _rng(43)
	var walk_switch := Walk.start(rng_switch, "walls", _dolls(), _pockets())
	var c_switch := _find_pin_nest(walk_switch)
	_act(walk_switch, "switch", {"target": "b"})
	_check(walk_switch.snapshot().viewpoint == "b", "AC3: switched viewpoint to doll b")
	_act(walk_switch, "curio", {"target": c_switch.instance, "choice": "pull"})
	_check(walk_switch.snapshot().dolls[1].id == "b" and walk_switch.snapshot().dolls[1].fray == 15, "AC3: doll b received +15 fray")
	_check(walk_switch.snapshot().dolls[0].fray == 0, "AC3: seamstress fray unchanged at 0")
	_finish_walk(walk_switch)
	var rec_switch := walk_switch.claim_pincushion_fray(walk_switch.snapshot(), c_switch.instance)
	_check(rec_switch.ok, "AC3: switched puller claim succeeds")
	_check(rec_switch.target == "b", "AC3: receipt target reflects actual switched puller b")
