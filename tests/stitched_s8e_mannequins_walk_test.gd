extends SceneTree

const Walk = preload("res://scripts/stitched/walk/stitched_walk_rules.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)

func random(seed_number: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_number
	return rng

func party() -> Array:
	var dolls: Array = []
	for index in 4:
		dolls.append({"id": str(index), "rank": index + 1, "hp": 30,
			"max_hp": 40, "lost": false, "fray": 0})
	return dolls

func pockets() -> Dictionary:
	return {"0": [], "1": [], "2": [], "3": []}

func act(walk: StitchedWalkRules, kind: String, extra: Dictionary = {}) -> Dictionary:
	var command := {"kind": kind, "actor": walk.snapshot().viewpoint}
	command.merge(extra, true)
	return walk.act(command, walk.snapshot())

func reject(walk: StitchedWalkRules, rng: RandomNumberGenerator, command: Dictionary,
		expected: Dictionary = {}) -> void:
	var before := walk.snapshot()
	var rng_before := rng.state
	var receipt := walk.act(command, before if expected.is_empty() else expected)
	check(not receipt.ok and not receipt.error.is_empty() and receipt.events.is_empty(),
		"invalid action rejects: " + str(command))
	check(walk.snapshot() == before and receipt.snapshot == before and rng.state == rng_before,
		"invalid action preserves state, WHIRR, RNG and pending")
	receipt.snapshot.clear()
	check(walk.snapshot() == before, "rejected receipt is detached")

func finish(walk: StitchedWalkRules) -> void:
	while walk.snapshot().phase == "walking":
		var result: Dictionary
		if walk.tug_unresolved():
			result = act(walk, "tug", {"target": "thread_tug", "choice": "yield"})
		else:
			result = act(walk, "forward")
		check(result.ok, "public Walk reaches completion")
		if not result.ok:
			break

func mannequin_effects(walk: StitchedWalkRules) -> Array:
	return walk.snapshot().pending.filter(func(p): return p.kind == "mannequins")

func has_event(events: Array, kind: String, stage: int = -1) -> bool:
	for event in events:
		if event.kind == kind and (stage < 0 or event.get("stage") == stage):
			return true
	return false

func any_mannequins_event(events: Array) -> bool:
	for event in events:
		if event.kind.begins_with("mannequins"):
			return true
	return false

func exercise(seed_number: int, mimic: bool, tug: bool) -> void:
	var baseline_rng := random(seed_number)
	var baseline = Walk.start(baseline_rng, "walls", party(), pockets(), null, mimic, tug)
	var off_rng := random(seed_number)
	var off = Walk.start(off_rng, "walls", party(), pockets(), null, mimic, tug, false)
	check(baseline != null and off != null and baseline.snapshot() == off.snapshot()
		and baseline_rng.state == off_rng.state, "default-off byte-for-byte schedule/RNG unchanged")
	check(not off.snapshot().has("mannequins"), "disabled Walk has no extra state")
	var expected_present := baseline_rng.randi_range(0, 1) == 1
	var expected_step := baseline_rng.randi_range(0, int(baseline.snapshot().corridor.steps) - 1)
	var a_rng := random(seed_number)
	var b_rng := random(seed_number)
	var a = Walk.start(a_rng, "walls", party(), pockets(), null, mimic, tug, true)
	var b = Walk.start(b_rng, "walls", party(), pockets(), null, mimic, tug, true)
	check(a != null and b != null, "both independent opt-in Walks start")
	if a == null or b == null:
		return
	var initial := a.snapshot()
	check(initial == b.snapshot() and a_rng.state == b_rng.state
		and a_rng.state == baseline_rng.state and initial.rng == baseline_rng.state,
		"seeded schedules reproducible with exactly two appended RNG draws")
	check(initial.mannequins.id == "following_forms" and initial.mannequins.name == "Mannequins"
		and initial.mannequins.present == expected_present
		and initial.mannequins.step == expected_step and initial.mannequins.stage == 0
		and initial.pending.is_empty(), "authored present/absent witness at traversable step")
	var caller_copy := initial.duplicate(true)
	caller_copy.mannequins.stage = 3
	caller_copy.pending.append({"kind": "forged"})
	check(a.snapshot() == initial, "public start snapshot detached")
	var untouched = Walk.start(random(seed_number), "walls", party(), pockets(), null, mimic, tug, true)
	finish(untouched)
	check(untouched.snapshot().phase == "complete" and untouched.snapshot().mannequins.stage == 0
		and mannequin_effects(untouched).is_empty(), "no-look completion never spawns an effect")
	if not expected_present:
		for idx in 5:
			var x := act(a, "look_back")
			var y := act(b, "look_back")
			check(x.ok and x == y and a_rng.state == b_rng.state, "absent LOOK BACK replay")
		check(a.snapshot().mannequins.stage == 0 and mannequin_effects(a).is_empty(),
			"absent witness ignores repeated looks")
		finish(a)
		finish(b)
		check(a.snapshot() == b.snapshot() and mannequin_effects(a).is_empty(),
			"absent completion replay remains effect-free")
		return
	if expected_step > 0:
		var premature := act(a, "look_back")
		check(premature.ok and a.snapshot().mannequins.stage == 0
			and mannequin_effects(a).is_empty(), "look before encounter step cannot escalate")
		check(premature == act(b, "look_back"), "early LOOK BACK replays")
	while a.snapshot().step < expected_step:
		if a.tug_unresolved():
			check(act(a, "tug", {"target": "thread_tug", "choice": "yield"}) ==
				act(b, "tug", {"target": "thread_tug", "choice": "yield"}),
				"tug resolution replays on route to mannequins")
		else:
			check(act(a, "forward") == act(b, "forward"), "public forward scheduling replay")
	check(a.mannequins_visible() and b.mannequins_visible(),
		"present witness actually reached through public Walk")
	var at_step := a.snapshot()
	reject(a, a_rng, {"kind": "look_back", "actor": "forged"})
	reject(a, a_rng, {"kind": "look_back", "actor": "1"})
	reject(a, a_rng, {"kind": "look_back", "actor": "0", "extra": true})
	var forged := at_step.duplicate(true)
	forged.mannequins.stage = 2
	reject(a, a_rng, {"kind": "look_back", "actor": "0"}, forged)
	var receipts: Array = []
	for stage in range(1, 6):
		var before := a.snapshot()
		var ra := act(a, "look_back")
		var rb := act(b, "look_back")
		receipts.append(ra.duplicate(true))
		check(ra.ok and ra == rb and a_rng.state == b_rng.state
			and a_rng.state == initial.rng, "identical seed action/receipt replay")
		check(ra.snapshot.mannequins.stage == mini(stage, 3)
			and ra.snapshot.whirr == before.whirr + 5, "each legal look adds WHIRR, caps escalation at three")
		var effects := mannequin_effects(a)
		check(effects.size() == (1 if stage >= 3 else 0),
			"exactly one future encounter only from third LOOK BACK")
		if stage <= 3:
			check(has_event(ra.events, "mannequins_stage", stage),
				"receipt names actual escalation stage")
		else:
			check(not any_mannequins_event(ra.events),
				"fourth and fifth looks cannot re-emit effect")
		if stage == 3 and effects.size() == 1:
			check(effects[0] == {"kind": "mannequins", "source": "following_forms",
				"consumed": false, "effects": {"next_fight": true,
				"position": "party_back_rank"}}, "typed unconsumed next-fight party-rear encounter")
			check(has_event(ra.events, "mannequins_pending"),
				"third look exposes one pending receipt")
	var stable := a.snapshot()
	receipts[2].snapshot.mannequins.stage = 99
	receipts[2].events.clear()
	receipts[2].snapshot.pending.clear()
	check(a.snapshot() == stable, "successful returned receipts are fully detached")
	reject(a, a_rng, {"kind": "look_back", "actor": "0"}, at_step)
	finish(a)
	finish(b)
	check(a.snapshot() == b.snapshot() and mannequin_effects(a).size() == 1,
		"completion preserves one staged effect and full replay")
	reject(a, a_rng, {"kind": "look_back", "actor": "0"})
	reject(a, a_rng, {"kind": "forward", "actor": "0"})

func thresholds() -> void:
	var witness := -1
	for seed_number in 128:
		var w = Walk.start(random(seed_number), "walls", party(), pockets(),
			null, false, false, true)
		if w.snapshot().mannequins.present and w.snapshot().mannequins.step == 0:
			witness = seed_number
			break
	check(witness >= 0, "actual seeded immediate mannequin witness for WHIRR threshold")
	if witness < 0:
		return
	var rng := random(witness)
	var walk = Walk.start(rng, "walls", party(), pockets(), null, false, false, true)
	var initial_rng := rng.state
	var warning_count := 0
	var machine_count := 0
	var mannequin_count := 0
	for index in 22:
		var result := act(walk, "look_back")
		for event in result.events:
			if event.kind == "whirr_warning": warning_count += 1
			if event.kind == "machine_pending": machine_count += 1
			if event.kind == "mannequins_pending": mannequin_count += 1
		check(result.ok and result.snapshot.whirr == mini(100, (index + 1) * 5),
			"WHIRR saturates exactly as legacy S8a")
	check(warning_count == 1 and machine_count == 1 and mannequin_count == 1
		and walk.snapshot().pending.filter(func(p): return p.kind == "machine").size() == 1
		and mannequin_effects(walk).size() == 1 and rng.state == initial_rng,
		"Machine, warning and third-look effect coexist one-shot with no RNG draws")

func missing_horror() -> void:
	var rng := random(553)
	var baseline := rng.state
	var catalogs := Walk.load_catalogs()
	for record in catalogs.horrors:
		if record.id == "following_forms":
			record.id = "forged_forms"
	check(Walk.start(rng, "walls", party(), pockets(), catalogs, true, true, true) == null
		and rng.state == baseline, "missing authored ID fails atomically even after other opt-in draws")
	var dolls := party()
	dolls[0].id = "following_forms"
	check(Walk.start(rng, "walls", dolls,
		{"following_forms": [], "1": [], "2": [], "3": []},
		null, false, false, true) == null and rng.state == baseline,
		"authored horror cannot alias a real doll, preserving RNG")

func _initialize() -> void:
	var present := 0
	var absent := 0
	for seed_number in 32:
		for combo in [[false, false], [true, false], [false, true], [true, true]]:
			var w = Walk.start(random(seed_number), "walls", party(), pockets(),
				null, combo[0], combo[1], true)
			if w.snapshot().mannequins.present:
				present += 1
			else:
				absent += 1
			exercise(seed_number, combo[0], combo[1])
	check(present > 0 and absent > 0, "nonvacuous present and absent seeded witnesses")
	thresholds()
	missing_horror()
	_test_ac1_mannequins_claim_success()
	_test_ac2_mannequins_claim_refusals()
	_test_ac3_stale_forged_drift_replay_isolation_coexistence()
	_test_ac4_no_mutation_side_effects_or_spawns()
	for failure in failures:
		printerr(failure)
	print("stitched_s8e_mannequins_walk_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _find_seed(present: bool, require_nonzero_step: bool = false) -> int:
	for seed_number in range(1, 1000):
		var w = Walk.start(random(seed_number), "walls", party(), pockets(),
			null, false, false, true)
		if w != null and w.snapshot().mannequins.present == present:
			if not require_nonzero_step or w.snapshot().mannequins.step > 0:
				return seed_number
	return -1


func _test_ac1_mannequins_claim_success() -> void:
	var seed_num := _find_seed(true, true)
	check(seed_num >= 0, "AC1: found present witness with step > 0")
	if seed_num < 0:
		return
	var rng := random(seed_num)
	var walk := Walk.start(rng, "walls", party(), pockets(), null, false, false, true)
	check(walk != null, "AC1: walk starts")
	var target_step: int = walk.snapshot().mannequins.step

	while walk.snapshot().step < target_step:
		var fwd := act(walk, "forward")
		check(fwd.ok, "AC1: forward to scheduled step")

	check(walk.mannequins_visible(), "AC1: mannequins visible at scheduled step")

	for idx in 3:
		var lb := act(walk, "look_back")
		check(lb.ok, "AC1: look_back " + str(idx + 1) + " accepted")

	check(walk.snapshot().mannequins.stage == 3, "AC1: stage reaches 3")
	var effects := mannequin_effects(walk)
	check(effects.size() == 1, "AC1: exactly one descriptor queued")
	check(effects[0] == {"kind": "mannequins", "source": "following_forms",
		"consumed": false, "effects": {"next_fight": true, "position": "party_back_rank"}},
		"AC1: canonical descriptor matches")

	finish(walk)
	check(walk.snapshot().phase == "complete", "AC1: walk completed")

	var before_snap: Dictionary = walk.snapshot()
	var dolls_before: Array = before_snap.dolls.duplicate(true)
	var pockets_before: Dictionary = before_snap.pockets.duplicate(true)
	var whirr_before: int = before_snap.whirr
	var rng_before: int = rng.state
	var rev_before: int = before_snap.revision

	var receipt := walk.claim_mannequins_encounter(before_snap)
	check(receipt.ok, "AC1: claim_mannequins_encounter succeeds")
	check(receipt.error.is_empty(), "AC1: receipt error is empty")
	check(receipt.kind == "mannequins", "AC1: receipt kind is mannequins")
	check(receipt.source == "following_forms", "AC1: receipt source is following_forms")
	check(receipt.horror == "following_forms", "AC1: receipt horror is following_forms")
	check(receipt.horror_id == "following_forms", "AC1: receipt horror_id is following_forms")
	check(receipt.next_fight == true, "AC1: receipt next_fight is true")
	check(receipt.position == "party_back_rank", "AC1: receipt position is party_back_rank")
	check(receipt.effects == {"next_fight": true, "position": "party_back_rank"}, "AC1: receipt effects match")
	check(receipt.snapshot == walk.snapshot(), "AC1: receipt snapshot matches walk snapshot")

	var after_snap := walk.snapshot()
	check(after_snap.revision == rev_before + 1, "AC1: revision advances exactly once")
	var post_effects := mannequin_effects(walk)
	check(post_effects.size() == 1 and post_effects[0].consumed == true, "AC1: descriptor is consumed")
	check(after_snap.dolls == dolls_before, "AC1: dolls unchanged")
	check(after_snap.pockets == pockets_before, "AC1: pockets unchanged")
	check(after_snap.whirr == whirr_before, "AC1: whirr unchanged")
	check(rng.state == rng_before, "AC1: RNG state unchanged")


func _test_ac2_mannequins_claim_refusals() -> void:
	# 1. Horror disabled
	var rng_dis := random(101)
	var walk_dis := Walk.start(rng_dis, "walls", party(), pockets(), null, false, false, false)
	finish(walk_dis)
	var r_dis := walk_dis.claim_mannequins_encounter(walk_dis.snapshot())
	check(not r_dis.ok and not r_dis.error.is_empty(), "AC2: claim refused when horror disabled")
	check(not r_dis.next_fight and r_dis.effects.is_empty(), "AC2: no encounter intent when disabled")

	# 2. Absent witness
	var seed_abs := _find_seed(false)
	check(seed_abs >= 0, "AC2: found absent witness seed")
	var rng_abs := random(seed_abs)
	var walk_abs := Walk.start(rng_abs, "walls", party(), pockets(), null, false, false, true)
	for idx in 3:
		act(walk_abs, "look_back")
	finish(walk_abs)
	var r_abs := walk_abs.claim_mannequins_encounter(walk_abs.snapshot())
	check(not r_abs.ok and not r_abs.error.is_empty(), "AC2: claim refused for absent witness")
	check(not r_abs.next_fight and r_abs.effects.is_empty(), "AC2: no encounter intent for absent witness")

	# 3. Present witness, zero looks (no-look completion)
	var seed_pres := _find_seed(true, true)
	check(seed_pres >= 0, "AC2: found present witness seed")
	var rng_zero := random(seed_pres)
	var walk_zero := Walk.start(rng_zero, "walls", party(), pockets(), null, false, false, true)
	finish(walk_zero)
	var r_zero := walk_zero.claim_mannequins_encounter(walk_zero.snapshot())
	check(not r_zero.ok and not r_zero.error.is_empty(), "AC2: claim refused on zero looks")
	check(not r_zero.next_fight and r_zero.effects.is_empty(), "AC2: no encounter intent on zero looks")

	# 4. Present witness, 1 look (stage 1)
	var rng_one := random(seed_pres)
	var walk_one := Walk.start(rng_one, "walls", party(), pockets(), null, false, false, true)
	var step_one: int = walk_one.snapshot().mannequins.step
	while walk_one.snapshot().step < step_one:
		act(walk_one, "forward")
	act(walk_one, "look_back")
	check(walk_one.snapshot().mannequins.stage == 1, "AC2: stage is 1")
	finish(walk_one)
	var r_one := walk_one.claim_mannequins_encounter(walk_one.snapshot())
	check(not r_one.ok and not r_one.error.is_empty(), "AC2: claim refused on stage 1")
	check(not r_one.next_fight and r_one.effects.is_empty(), "AC2: no encounter intent on stage 1")

	# 5. Present witness, 2 looks (stage 2)
	var rng_two := random(seed_pres)
	var walk_two := Walk.start(rng_two, "walls", party(), pockets(), null, false, false, true)
	var step_two: int = walk_two.snapshot().mannequins.step
	while walk_two.snapshot().step < step_two:
		act(walk_two, "forward")
	act(walk_two, "look_back")
	act(walk_two, "look_back")
	check(walk_two.snapshot().mannequins.stage == 2, "AC2: stage is 2")
	finish(walk_two)
	var r_two := walk_two.claim_mannequins_encounter(walk_two.snapshot())
	check(not r_two.ok and not r_two.error.is_empty(), "AC2: claim refused on stage 2")
	check(not r_two.next_fight and r_two.effects.is_empty(), "AC2: no encounter intent on stage 2")

	# 6. Pre-completion (walk incomplete while walking)
	var rng_incomp := random(seed_pres)
	var walk_incomp := Walk.start(rng_incomp, "walls", party(), pockets(), null, false, false, true)
	var step_incomp: int = walk_incomp.snapshot().mannequins.step
	while walk_incomp.snapshot().step < step_incomp:
		act(walk_incomp, "forward")
	for idx in 3:
		act(walk_incomp, "look_back")
	check(walk_incomp.snapshot().mannequins.stage == 3, "AC2: stage is 3")
	check(walk_incomp.snapshot().phase == "walking", "AC2: walk is incomplete")
	var snap_incomp := walk_incomp.snapshot()
	var rng_before_incomp: int = rng_incomp.state
	var r_incomp := walk_incomp.claim_mannequins_encounter(snap_incomp)
	check(not r_incomp.ok and not r_incomp.error.is_empty(), "AC2: claim refused while walk is incomplete")
	check(not r_incomp.next_fight and r_incomp.effects.is_empty(), "AC2: no encounter intent while incomplete")
	check(walk_incomp.snapshot() == snap_incomp and rng_incomp.state == rng_before_incomp, "AC2: incomplete refusal mutates nothing")
	finish(walk_incomp)
	var r_comp := walk_incomp.claim_mannequins_encounter(walk_incomp.snapshot())
	check(r_comp.ok, "AC2: claim succeeds once completed")

	# 7. Fourth and fifth looks do not produce extra descriptors or claims
	var rng_five := random(seed_pres)
	var walk_five := Walk.start(rng_five, "walls", party(), pockets(), null, false, false, true)
	var step_five: int = walk_five.snapshot().mannequins.step
	while walk_five.snapshot().step < step_five:
		act(walk_five, "forward")
	for idx in 5:
		act(walk_five, "look_back")
	check(walk_five.snapshot().mannequins.stage == 3, "AC2: stage remains 3 after 5 looks")
	check(mannequin_effects(walk_five).size() == 1, "AC2: exactly one descriptor after 5 looks")
	finish(walk_five)
	var r_first_claim := walk_five.claim_mannequins_encounter(walk_five.snapshot())
	check(r_first_claim.ok, "AC2: first claim succeeds after 5 looks")
	var r_extra_claim := walk_five.claim_mannequins_encounter(walk_five.snapshot())
	check(not r_extra_claim.ok and not r_extra_claim.error.is_empty(), "AC2: extra claim refused")


func _test_ac3_stale_forged_drift_replay_isolation_coexistence() -> void:
	var seed_num := _find_seed(true, true)
	var rng := random(seed_num)
	var walk := Walk.start(rng, "walls", party(), pockets(), null, false, false, true)
	var target_step: int = walk.snapshot().mannequins.step
	while walk.snapshot().step < target_step:
		act(walk, "forward")
	for idx in 3:
		act(walk, "look_back")
	finish(walk)

	var snap_before := walk.snapshot()
	var rng_before := rng.state

	# Claim succeeds once
	var r_ok := walk.claim_mannequins_encounter(snap_before)
	check(r_ok.ok, "AC3: first claim succeeds")
	var snap_after := walk.snapshot()

	# Stale snapshot replay
	var r_stale := walk.claim_mannequins_encounter(snap_before)
	check(not r_stale.ok and not r_stale.error.is_empty(), "AC3: stale snapshot rejected")
	check(walk.snapshot() == snap_after and rng.state == rng_before, "AC3: stale refusal mutates nothing")

	# Second claim with current snapshot
	var r_second := walk.claim_mannequins_encounter(snap_after)
	check(not r_second.ok and not r_second.error.is_empty(), "AC3: second claim rejected")
	check(walk.snapshot() == snap_after and rng.state == rng_before, "AC3: second claim mutates nothing")

	# Receipt tampering isolation
	r_ok.snapshot.clear()
	r_ok.effects.clear()
	r_ok.source = "tampered"
	r_ok.position = "front"
	check(walk.snapshot() == snap_after, "AC3: mutating returned receipt does not affect walk state")

	# Forged expected snapshot tests on fresh walk
	var walk_fresh := Walk.start(random(seed_num), "walls", party(), pockets(), null, false, false, true)
	while walk_fresh.snapshot().step < target_step:
		act(walk_fresh, "forward")
	for idx in 3:
		act(walk_fresh, "look_back")
	finish(walk_fresh)

	var fresh_snap := walk_fresh.snapshot()
	var fresh_rng := walk_fresh._rng.state

	# Forged consumed
	var forged_c := fresh_snap.duplicate(true)
	forged_c.pending[0].consumed = true
	var r_fc := walk_fresh.claim_mannequins_encounter(forged_c)
	check(not r_fc.ok and not r_fc.error.is_empty(), "AC3: forged consumed rejected")
	check(walk_fresh.snapshot() == fresh_snap and walk_fresh._rng.state == fresh_rng, "AC3: forged consumed preserves state")

	# Forged effects
	var forged_e := fresh_snap.duplicate(true)
	forged_e.pending[0].effects = {"next_fight": false, "position": "party_front_rank"}
	var r_fe := walk_fresh.claim_mannequins_encounter(forged_e)
	check(not r_fe.ok and not r_fe.error.is_empty(), "AC3: forged effects rejected")
	check(walk_fresh.snapshot() == fresh_snap and walk_fresh._rng.state == fresh_rng, "AC3: forged effects preserves state")

	# Forged source
	var forged_s := fresh_snap.duplicate(true)
	forged_s.pending[0].source = "fake_source"
	var r_fs := walk_fresh.claim_mannequins_encounter(forged_s)
	check(not r_fs.ok and not r_fs.error.is_empty(), "AC3: forged source rejected")
	check(walk_fresh.snapshot() == fresh_snap and walk_fresh._rng.state == fresh_rng, "AC3: forged source preserves state")

	# Forged revision
	var forged_r := fresh_snap.duplicate(true)
	forged_r.revision = 999
	var r_fr := walk_fresh.claim_mannequins_encounter(forged_r)
	check(not r_fr.ok and not r_fr.error.is_empty(), "AC3: forged revision rejected")
	check(walk_fresh.snapshot() == fresh_snap and walk_fresh._rng.state == fresh_rng, "AC3: forged revision preserves state")

	# Direct internal descriptor corruption defense
	var walk_corrupt := Walk.start(random(seed_num), "walls", party(), pockets(), null, false, false, true)
	while walk_corrupt.snapshot().step < target_step:
		act(walk_corrupt, "forward")
	for idx in 3:
		act(walk_corrupt, "look_back")
	finish(walk_corrupt)
	walk_corrupt._state.pending[0].effects = {"wrong": true}
	var r_corrupt := walk_corrupt.claim_mannequins_encounter(walk_corrupt.snapshot())
	check(not r_corrupt.ok and not r_corrupt.error.is_empty(), "AC3: corrupt internal effects rejected")

	# RNG drift test
	walk_fresh._rng.randi()
	var drifted_rng := walk_fresh._rng.state
	var r_drift := walk_fresh.claim_mannequins_encounter(fresh_snap)
	check(not r_drift.ok and not r_drift.error.is_empty(), "AC3: RNG drift rejected")
	check(walk_fresh._rng.state == drifted_rng, "AC3: RNG drift not rewound")
	check(walk_fresh.snapshot() == fresh_snap, "AC3: RNG drift preserves state")
	walk_fresh._rng.state = fresh_rng
	var r_retry := walk_fresh.claim_mannequins_encounter(fresh_snap)
	check(r_retry.ok, "AC3: retry after RNG restored succeeds")

	# Independent seeded replay
	var replay_seed := 7721
	var rng1 := random(replay_seed)
	var rng2 := random(replay_seed)
	var w1 := Walk.start(rng1, "walls", party(), pockets(), null, false, false, true)
	var w2 := Walk.start(rng2, "walls", party(), pockets(), null, false, false, true)
	var step1: int = w1.snapshot().mannequins.step
	while w1.snapshot().step < step1:
		act(w1, "forward")
		act(w2, "forward")
	for idx in 3:
		act(w1, "look_back")
		act(w2, "look_back")
	finish(w1)
	finish(w2)
	check(w1.snapshot() == w2.snapshot(), "AC3: walks match before claim")
	check(rng1.state == rng2.state, "AC3: RNGs match before claim")
	var r1 := w1.claim_mannequins_encounter(w1.snapshot())
	var r2 := w2.claim_mannequins_encounter(w2.snapshot())
	check(r1 == r2, "AC3: independent seeded claim receipts match identically")
	check(w1.snapshot() == w2.snapshot(), "AC3: independent seeded snapshots match after claim")
	check(rng1.state == rng2.state, "AC3: independent seeded RNGs match after claim")

	# Coexistence with Machine and item pending effects
	var p_multi := pockets()
	p_multi["0"] = ["starch"]
	var rng_coex := random(seed_num)
	var walk_coex := Walk.start(rng_coex, "walls", party(), p_multi, null, true, false, true)
	var step_coex: int = walk_coex.snapshot().mannequins.step
	while walk_coex.snapshot().step < step_coex:
		act(walk_coex, "forward")
	# Starch use
	act(walk_coex, "use_item", {"slot": 0, "target": "1"})
	# 3 looks for mannequins
	for idx in 3:
		act(walk_coex, "look_back")
	# Further looks to reach WHIRR 100
	while walk_coex.snapshot().whirr < 100:
		act(walk_coex, "look_back")
	finish(walk_coex)

	var snap_coex: Dictionary = walk_coex.snapshot()
	var starch_before: Array = snap_coex.pending.filter(func(p): return p.kind == "starch")
	var machine_before: Array = snap_coex.pending.filter(func(p): return p.kind == "machine")
	var mannequins_before: Array = snap_coex.pending.filter(func(p): return p.kind == "mannequins")
	check(starch_before.size() == 1 and not starch_before[0].consumed, "AC3: starch unconsumed before claim")
	check(machine_before.size() == 1 and not machine_before[0].consumed, "AC3: machine unconsumed before claim")
	check(mannequins_before.size() == 1 and not mannequins_before[0].consumed, "AC3: mannequins unconsumed before claim")

	# Claim mannequins
	var r_m_claim := walk_coex.claim_mannequins_encounter(snap_coex)
	check(r_m_claim.ok, "AC3: mannequins claimed in coexistence walk")

	var snap_coex_mid: Dictionary = walk_coex.snapshot()
	var starch_mid: Array = snap_coex_mid.pending.filter(func(p): return p.kind == "starch")
	var machine_mid: Array = snap_coex_mid.pending.filter(func(p): return p.kind == "machine")
	var mannequins_mid: Array = snap_coex_mid.pending.filter(func(p): return p.kind == "mannequins")
	check(mannequins_mid.size() == 1 and mannequins_mid[0].consumed, "AC3: mannequins consumed after claim")
	check(starch_mid.size() == 1 and not starch_mid[0].consumed, "AC3: starch remains unconsumed")
	check(machine_mid.size() == 1 and not machine_mid[0].consumed, "AC3: machine remains unconsumed")

	# Now claim machine toll
	var r_mach_claim := walk_coex.claim_machine_toll(snap_coex_mid)
	check(r_mach_claim.ok, "AC3: machine toll claimed in coexistence walk")
	var snap_coex_final: Dictionary = walk_coex.snapshot()
	var machine_final: Array = snap_coex_final.pending.filter(func(p): return p.kind == "machine")
	var mannequins_final: Array = snap_coex_final.pending.filter(func(p): return p.kind == "mannequins")
	check(machine_final.size() == 1 and machine_final[0].consumed, "AC3: machine consumed after toll claim")
	check(mannequins_final.size() == 1 and mannequins_final[0].consumed, "AC3: mannequins still consumed")


func _test_ac4_no_mutation_side_effects_or_spawns() -> void:
	var seed_num := _find_seed(true, true)
	var rng := random(seed_num)
	var dolls := party()
	dolls[0].hp = 15
	dolls[0].fray = 25
	dolls[1].hp = 20
	dolls[1].fray = 10
	var walk := Walk.start(rng, "walls", dolls, pockets(), null, false, false, true)
	var target_step: int = walk.snapshot().mannequins.step
	while walk.snapshot().step < target_step:
		act(walk, "forward")
	for idx in 3:
		act(walk, "look_back")
	finish(walk)

	var before := walk.snapshot()
	var rng_before := rng.state

	var receipt := walk.claim_mannequins_encounter(before)
	check(receipt.ok, "AC4: claim succeeds")

	var after := walk.snapshot()

	# Exact preservation of doll attributes
	check(after.dolls.size() == 4, "AC4: party size unchanged")
	for i in 4:
		var d_b: Dictionary = before.dolls[i]
		var d_a: Dictionary = after.dolls[i]
		check(d_a.id == d_b.id, "AC4: doll " + str(i) + " id unchanged")
		check(d_a.rank == d_b.rank, "AC4: doll " + str(i) + " rank unchanged")
		check(d_a.hp == d_b.hp, "AC4: doll " + str(i) + " hp unchanged")
		check(d_a.max_hp == d_b.max_hp, "AC4: doll " + str(i) + " max_hp unchanged")
		check(d_a.fray == d_b.fray, "AC4: doll " + str(i) + " fray unchanged")
		check(d_a.lost == d_b.lost, "AC4: doll " + str(i) + " lost unchanged")
		check(d_a.get("parts", {}) == d_b.get("parts", {}), "AC4: doll " + str(i) + " parts unchanged")

	check(after.pockets == before.pockets, "AC4: pockets unchanged")
	check(after.whirr == before.whirr, "AC4: whirr unchanged")
	check(after.area == before.area, "AC4: area unchanged")
	check(after.corridor == before.corridor, "AC4: corridor unchanged")
	check(after.curios == before.curios, "AC4: curios unchanged")
	check(rng.state == rng_before, "AC4: RNG state unchanged")
	check(after.revision == before.revision + 1, "AC4: exactly one revision increment")

	# Receipt does not invent enemy IDs or foe count
	check(not receipt.has("foe_count") and not receipt.has("foes") and not receipt.has("enemy_id"),
		"AC4: receipt does not invent enemy IDs or foe counts")
	check(receipt.effects == {"next_fight": true, "position": "party_back_rank"},
		"AC4: receipt effects only contains canonical next_fight and position")

	# Default-off scheduling check
	var default_rng := random(seed_num)
	var default_walk := Walk.start(default_rng, "walls", party(), pockets())
	check(not default_walk.snapshot().has("mannequins"), "AC4: default-off scheduling preserved")
	finish(default_walk)
	var r_def := default_walk.claim_mannequins_encounter(default_walk.snapshot())
	check(not r_def.ok, "AC4: claim fails on default-off walk")
