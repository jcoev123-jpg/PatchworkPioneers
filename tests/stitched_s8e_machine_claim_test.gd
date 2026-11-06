extends SceneTree

const Walk = preload("res://scripts/stitched/walk/stitched_walk_rules.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_test_ac1_twenty_looks_machine_pending_and_complete_claim()
	_test_ac2_claim_consumption_revision_and_rejections()
	_test_ac3_early_and_absent_claims_and_unrelated_effects()
	for failure in failures:
		printerr(failure)
	print("stitched_s8e_machine_claim_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _rng(seed_number: int = 547) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = seed_number
	return random


func _dolls() -> Array:
	return [
		{"id": "a", "rank": 1, "hp": 90, "max_hp": 100, "lost": false, "fray": 0},
		{"id": "b", "rank": 2, "hp": 10, "max_hp": 101, "lost": false, "fray": 0},
		{"id": "c", "rank": 3, "hp": 0, "max_hp": 20, "lost": false, "fray": 0},
		{"id": "d", "rank": 4, "hp": 20, "max_hp": 20, "lost": false, "fray": 0}
	]


func _pockets() -> Dictionary:
	return {
		"a": ["thimble_tonic", "fresh_stuffing"],
		"b": ["starch", "dye"],
		"c": ["pins", "spare_spool"],
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


func _test_ac1_twenty_looks_machine_pending_and_complete_claim() -> void:
	var rng := _rng(1234)
	var walk := Walk.start(rng, "walls", _dolls(), _pockets())
	_check(walk != null, "AC1: seeded real Walk starts")
	if walk == null:
		return

	var initial_state := walk.snapshot()
	var machine_pending_events := 0

	# 20 accepted LOOK BACK actions (each costs 5 WHIRR)
	for index in range(1, 21):
		var receipt := _act(walk, "look_back")
		_check(receipt.ok, "AC1: look_back action accepted at index " + str(index))
		_check(receipt.snapshot.whirr == index * 5, "AC1: WHIRR advances by 5 each look_back")
		for event in receipt.events:
			if event.kind == "machine_pending":
				machine_pending_events += 1

	_check(walk.snapshot().whirr == 100, "AC1: 20 looks reach exactly WHIRR 100")
	_check(machine_pending_events == 1, "AC1: machine_pending event fires exactly once at WHIRR 100")

	var pending_list: Array = walk.snapshot().pending
	var machine_descriptors: Array = pending_list.filter(func(p): return p.get("kind") == "machine")
	_check(machine_descriptors.size() == 1, "AC1: exactly one Machine descriptor queued")
	var desc: Dictionary = machine_descriptors[0]
	_check(desc == {"kind": "machine", "consumed": false,
		"effects": {"next_fight_extra_foes": 1, "party_fray": 10}},
		"AC1: exact authentic unconsumed Machine pending descriptor shape")

	# Finish the seeded corridor with public Forward
	_finish_walk(walk)
	_check(walk.snapshot().phase == "complete", "AC1: Walk reaches phase complete")

	# Capture completed snapshot and dolls before claim
	var completed_snap: Dictionary = walk.snapshot()
	var dolls_before: Array = completed_snap.dolls.duplicate(true)
	var pockets_before: Dictionary = completed_snap.pockets.duplicate(true)
	var rng_before: int = rng.state

	# Claim machine toll
	var receipt := walk.claim_machine_toll(completed_snap)
	_check(receipt.ok, "AC1: claim_machine_toll returns ok=true")
	_check(receipt.error.is_empty(), "AC1: error is empty on success")
	_check(receipt.source == "hungry_machine", "AC1: canonical hungry_machine source derived")
	_check(receipt.next_fight_extra_foes == 1, "AC1: exactly 1 next fight extra foe")
	_check(receipt.party_fray == 10, "AC1: exactly +10 fray per doll")
	_check(receipt.targets == ["a", "b", "c", "d"], "AC1: explicit four doll targets once each")
	_check(receipt.snapshot == walk.snapshot(), "AC1: receipt contains matching detached snapshot")

	# Check no immediate application of foes, HP damage or fray
	var current_snap := walk.snapshot()
	_check(current_snap.dolls == dolls_before, "AC1: dolls HP and fray not applied immediately")
	_check(current_snap.pockets == pockets_before, "AC1: pockets unchanged")
	_check(rng.state == rng_before, "AC1: RNG not drawn during claim")


func _test_ac2_claim_consumption_revision_and_rejections() -> void:
	var rng := _rng(4321)
	var walk := Walk.start(rng, "walls", _dolls(), _pockets())
	for index in 20:
		_act(walk, "look_back")
	_finish_walk(walk)

	var before := walk.snapshot()
	var rng_before := rng.state

	var receipt := walk.claim_machine_toll(before)
	_check(receipt.ok, "AC2: claim accepted")

	var after: Dictionary = walk.snapshot()

	# Compare whole state before and after: ONLY revision and consumed marker differ
	var expected_after: Dictionary = before.duplicate(true)
	expected_after.revision += 1
	for effect in expected_after.pending:
		if effect.kind == "machine":
			effect.consumed = true

	_check(after == expected_after, "AC2: claiming commits consumption exactly once and advances only Walk revision/consumed marker")
	_check(rng.state == rng_before, "AC2: claim performs zero RNG draws")

	# Replay with old expected snapshot
	var stale_receipt: Dictionary = walk.claim_machine_toll(before)
	_check(not stale_receipt.ok and not stale_receipt.error.is_empty(), "AC2: replay with stale snapshot refuses")
	_check(walk.snapshot() == after and rng.state == rng_before, "AC2: stale refusal mutates nothing")

	# Claim twice with current snapshot
	var double_receipt: Dictionary = walk.claim_machine_toll(walk.snapshot())
	_check(not double_receipt.ok and not double_receipt.error.is_empty(), "AC2: claim twice refuses atomically")
	_check(walk.snapshot() == after and rng.state == rng_before, "AC2: double-claim refusal mutates nothing")

	# Tampering with returned receipts does not affect internal state
	receipt.snapshot.clear()
	receipt.targets.clear()
	receipt.source = "forged"
	_check(walk.snapshot() == after, "AC2: tampering with returned receipt leaves service state intact")

	# Forged marker / forged effects in snapshot refusal
	var walk_fresh: StitchedWalkRules = Walk.start(_rng(999), "walls", _dolls(), _pockets())
	for index in 20:
		_act(walk_fresh, "look_back")
	_finish_walk(walk_fresh)

	var fresh_snap: Dictionary = walk_fresh.snapshot()
	var fresh_rng: int = walk_fresh._rng.state

	var forged_consumed: Dictionary = fresh_snap.duplicate(true)
	forged_consumed.pending[0].consumed = true
	var forged_receipt1: Dictionary = walk_fresh.claim_machine_toll(forged_consumed)
	_check(not forged_receipt1.ok, "AC2: forged consumed marker in expected snapshot rejected")
	_check(walk_fresh.snapshot() == fresh_snap and walk_fresh._rng.state == fresh_rng, "AC2: forged consumed refusal mutates nothing")

	var forged_effects: Dictionary = fresh_snap.duplicate(true)
	forged_effects.pending[0].effects = {"next_fight_extra_foes": 99, "party_fray": 99}
	var forged_receipt2: Dictionary = walk_fresh.claim_machine_toll(forged_effects)
	_check(not forged_receipt2.ok, "AC2: forged effects in expected snapshot rejected")
	_check(walk_fresh.snapshot() == fresh_snap and walk_fresh._rng.state == fresh_rng, "AC2: forged effects refusal mutates nothing")

	# External RNG drift refusal
	walk_fresh._rng.randi()
	var drifted_rng := walk_fresh._rng.state
	var drift_receipt := walk_fresh.claim_machine_toll(fresh_snap)
	_check(not drift_receipt.ok, "AC2: external RNG drift rejected")
	_check(walk_fresh._rng.state == drifted_rng, "AC2: drift rejection does not rewind external RNG")
	_check(walk_fresh.snapshot() == fresh_snap, "AC2: drift rejection preserves walk state")

	# Restore RNG state: valid retry succeeds
	walk_fresh._rng.state = fresh_rng
	var retry_receipt := walk_fresh.claim_machine_toll(fresh_snap)
	_check(retry_receipt.ok, "AC2: valid retry succeeds after rejected drift")

	# Independent seeded replay
	var seed_val := 8881
	var rng1 := _rng(seed_val)
	var rng2 := _rng(seed_val)
	var w1 := Walk.start(rng1, "walls", _dolls(), _pockets())
	var w2 := Walk.start(rng2, "walls", _dolls(), _pockets())
	for index in 20:
		_act(w1, "look_back")
		_act(w2, "look_back")
	_finish_walk(w1)
	_finish_walk(w2)

	_check(w1.snapshot() == w2.snapshot(), "AC2: seeded walks match before claim")
	_check(rng1.state == rng2.state, "AC2: seeded walk RNGs match before claim")

	var r1 := w1.claim_machine_toll(w1.snapshot())
	var r2 := w2.claim_machine_toll(w2.snapshot())
	_check(r1 == r2, "AC2: independent seeded claim receipts match identically")
	_check(w1.snapshot() == w2.snapshot(), "AC2: independent seeded snapshots match identically after claim")
	_check(rng1.state == rng2.state, "AC2: independent seeded RNG states match identically after claim")


func _test_ac3_early_and_absent_claims_and_unrelated_effects() -> void:
	# Early claim before completion: phase walking with WHIRR 100
	var rng_early := _rng(555)
	var walk_early := Walk.start(rng_early, "walls", _dolls(), _pockets())
	for index in 20:
		_act(walk_early, "look_back")
	var early_snap := walk_early.snapshot()
	var early_rng := rng_early.state
	_check(early_snap.phase == "walking" and early_snap.whirr == 100, "AC3: walk is walking at WHIRR 100")

	var early_receipt := walk_early.claim_machine_toll(early_snap)
	_check(not early_receipt.ok and not early_receipt.error.is_empty(), "AC3: early claim before completion rejected")
	_check(walk_early.snapshot() == early_snap and rng_early.state == early_rng, "AC3: early claim preserves state and RNG")

	# After completion, the same walk can be claimed
	_finish_walk(walk_early)
	_check(walk_early.snapshot().phase == "complete", "AC3: walk finished")
	var early_complete_receipt := walk_early.claim_machine_toll(walk_early.snapshot())
	_check(early_complete_receipt.ok, "AC3: claim succeeds once phase is complete")

	# Low WHIRR (0 WHIRR) completed Walk: no machine pending
	var rng_no_machine := _rng(666)
	var walk_no_machine := Walk.start(rng_no_machine, "walls", _dolls(), _pockets())
	_finish_walk(walk_no_machine)
	var no_machine_snap := walk_no_machine.snapshot()
	_check(no_machine_snap.phase == "complete" and no_machine_snap.whirr == 0, "AC3: zero-WHIRR completed walk")

	var no_machine_receipt := walk_no_machine.claim_machine_toll(no_machine_snap)
	_check(not no_machine_receipt.ok and not no_machine_receipt.error.is_empty(), "AC3: claim with no machine pending rejected")
	_check(walk_no_machine.snapshot() == no_machine_snap, "AC3: no-machine claim leaves state intact")

	# Intermediate WHIRR (50 WHIRR, warning active, WHIRR < 100) completed Walk
	var rng_mid := _rng(777)
	var walk_mid := Walk.start(rng_mid, "walls", _dolls(), _pockets())
	for index in 10:
		_act(walk_mid, "look_back")
	_check(walk_mid.snapshot().whirr == 50 and walk_mid.snapshot().warning, "AC3: WHIRR 50 warning active")
	_finish_walk(walk_mid)
	var mid_snap := walk_mid.snapshot()

	var mid_receipt := walk_mid.claim_machine_toll(mid_snap)
	_check(not mid_receipt.ok and not mid_receipt.error.is_empty(), "AC3: claim at WHIRR 50 rejected")
	_check(walk_mid.snapshot() == mid_snap, "AC3: intermediate WHIRR claim leaves state intact")

	# Unstarted Walk refusal
	var unstarted := Walk.new()
	var unstarted_receipt := unstarted.claim_machine_toll({})
	_check(not unstarted_receipt.ok, "AC3: unstarted Walk claim rejected")

	# Unrelated pending effects remain intact and unconsumed
	# Use items, enable mimic, enable mannequins
	var rng_multi := _rng(888)
	var walk_multi := Walk.start(rng_multi, "walls", _dolls(), _pockets(), null, true, false, true)
	_check(walk_multi != null, "AC3: multi-opt-in walk starts")
	if walk_multi == null:
		return

	# Switch to doll "b" to access its starch pocket item
	var switch_receipt := _act(walk_multi, "switch", {"target": "b"})
	_check(switch_receipt.ok, "AC3: switched to doll b")
	# Use pocket item (creates starch pending descriptor)
	var use_receipt := _act(walk_multi, "use_item", {"slot": 0, "target": "c"})
	_check(use_receipt.ok, "AC3: starch item used")

	# Look back 20 times (triggers mannequins pending if reached, and reaches WHIRR 100 machine pending)
	for index in 20:
		_act(walk_multi, "look_back")

	_check(walk_multi.snapshot().whirr == 100, "AC3: WHIRR reaches 100")
	_finish_walk(walk_multi)
	_check(walk_multi.snapshot().phase == "complete", "AC3: multi walk complete")

	var multi_snap: Dictionary = walk_multi.snapshot()
	var starch_before: Array = multi_snap.pending.filter(func(p): return p.kind == "starch")
	_check(starch_before.size() == 1 and not starch_before[0].consumed, "AC3: starch pending before claim unconsumed")

	var machine_before: Array = multi_snap.pending.filter(func(p): return p.kind == "machine")
	_check(machine_before.size() == 1 and not machine_before[0].consumed, "AC3: machine pending before claim unconsumed")

	var mimic_before: Array = multi_snap.pending.filter(func(p): return p.kind == "mimic")
	# If mimic shadow was present, mimic pending was added on completion
	if multi_snap.has("shadow") and multi_snap.shadow.present and not multi_snap.shadow.removed:
		_check(mimic_before.size() == 1 and not mimic_before[0].consumed, "AC3: mimic pending before claim unconsumed")

	var mannequins_before: Array = multi_snap.pending.filter(func(p): return p.kind == "mannequins")
	if mannequins_before.size() > 0:
		_check(not mannequins_before[0].consumed, "AC3: mannequins pending before claim unconsumed")

	# Claim machine toll
	var multi_claim: Dictionary = walk_multi.claim_machine_toll(multi_snap)
	_check(multi_claim.ok, "AC3: multi walk machine toll claimed successfully")

	var multi_after: Dictionary = walk_multi.snapshot()
	var starch_after: Array = multi_after.pending.filter(func(p): return p.kind == "starch")
	_check(starch_after.size() == 1 and not starch_after[0].consumed, "AC3: starch pending REMAINS UNCONSUMED after machine claim")

	var machine_after: Array = multi_after.pending.filter(func(p): return p.kind == "machine")
	_check(machine_after.size() == 1 and machine_after[0].consumed, "AC3: machine pending IS CONSUMED after machine claim")

	var mimic_after: Array = multi_after.pending.filter(func(p): return p.kind == "mimic")
	if not mimic_before.is_empty():
		_check(mimic_after.size() == 1 and not mimic_after[0].consumed, "AC3: mimic pending REMAINS UNCONSUMED after machine claim")

	var mannequins_after: Array = multi_after.pending.filter(func(p): return p.kind == "mannequins")
	if not mannequins_before.is_empty():
		_check(mannequins_after.size() == 1 and not mannequins_after[0].consumed, "AC3: mannequins pending REMAINS UNCONSUMED after machine claim")
