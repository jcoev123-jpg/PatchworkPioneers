extends SceneTree
## Deterministic headless SceneTree test for StitchedKidFear (Design v4 S9a Kid core).
## Validates Wren's fear ledger, shaky hands 25% percentile checks, event-based deltas,
## one-turn Lose the Strings interruption, and stale snapshot guards.

var checks := 0
var failures: Array[String] = []


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _initialize() -> void:
	_test_ac1_initial_state_and_detachment()
	_test_ac2_event_deltas_and_clamping()
	_test_ac3_shaky_hands_and_rng_neutrality()
	_test_ac4_lost_strings_interruption_lifecycle()
	_test_ac5_negative_atomicity_and_stale_guards()

	if failures.is_empty():
		print("stitched_s9a_kid_fear_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("stitched_s9a_kid_fear_test: FAIL (%d failures)" % failures.size())
		quit(1)


func _test_ac1_initial_state_and_detachment() -> void:
	# AC1: New Stitched night with fear=0 starts at 0, shake=false, no pending interruption.
	var built := StitchedKidFear.create()
	_check(bool(built.get("ok", false)), "AC1: StitchedKidFear.create() succeeds")
	var fear: StitchedKidFear = built.get("service")
	_check(fear != null, "AC1: service instance is non-null")
	if fear == null:
		return

	_check(fear.get_fear() == 0, "AC1: initial fear is 0")
	_check(fear.fear() == 0, "AC1: fear() accessor is 0")
	_check(not fear.is_shaking(), "AC1: is_shaking() is false at fear 0")
	_check(not fear.shake(), "AC1: shake() accessor is false at fear 0")
	_check(not fear.has_pending_lost_strings(), "AC1: has_pending_lost_strings() is false initially")
	_check(not fear.pending_lost_strings(), "AC1: pending_lost_strings() is false initially")
	_check(fear.get_sequence() == 0, "AC1: initial sequence is 0")

	# Test direct instantiation via _init().
	var direct := StitchedKidFear.new()
	_check(direct.get_fear() == 0, "AC1: StitchedKidFear.new() starts with fear 0")
	_check(not direct.is_shaking(), "AC1: direct instance shake is false")
	_check(not direct.has_pending_lost_strings(), "AC1: direct instance no pending interruption")

	# Snapshot detached verification: mutating returned snapshot must not affect internal state.
	var snap := fear.state_snapshot()
	_check(int(snap.get("fear", -1)) == 0, "AC1: snapshot fear is 0")
	_check(not bool(snap.get("shake", true)), "AC1: snapshot shake is false")
	_check(not bool(snap.get("pending_lost_strings", true)), "AC1: snapshot pending_lost_strings is false")
	_check(int(snap.get("sequence", -1)) == 0, "AC1: snapshot sequence is 0")

	snap["fear"] = 99
	snap["shake"] = true
	snap["pending_lost_strings"] = true
	snap["sequence"] = 42
	snap["extraneous"] = "injected"

	_check(fear.get_fear() == 0, "AC1: mutating snapshot does not alter get_fear()")
	_check(not fear.is_shaking(), "AC1: mutating snapshot does not alter is_shaking()")
	_check(not fear.has_pending_lost_strings(), "AC1: mutating snapshot does not alter pending lost strings")
	_check(fear.get_sequence() == 0, "AC1: mutating snapshot does not alter sequence")

	var fresh_snap := fear.state_snapshot()
	_check(int(fresh_snap["fear"]) == 0, "AC1: fresh snapshot reflects untouched fear 0")
	_check(not bool(fresh_snap["shake"]), "AC1: fresh snapshot reflects untouched shake false")
	_check(not fresh_snap.has("extraneous"), "AC1: fresh snapshot has no injected keys")

	# Detached receipt verification.
	var accepted := fear.apply_observed_event({"kind": "fray_gain", "amount": 10})
	_check(bool(accepted.get("ok", false)), "AC1: fray event accepted")
	_check(fear.get_fear() == 2, "AC1: fear updated to 2")

	accepted["fear"] = 88
	accepted["shake"] = true
	accepted["delta"] = 999
	_check(fear.get_fear() == 2, "AC1: mutating accepted receipt does not alter internal fear")


func _test_ac2_event_deltas_and_clamping() -> void:
	var fear := StitchedKidFear.new(0)
	_check(fear.get_fear() == 0, "AC2: starting test fixture at fear 0")

	# 1. Doll fray gain: 9 adds 0 (boundary), 10 adds +2 (boundary), 15 adds +2.
	var fray_9 := fear.apply_observed_event({"kind": "fray_gain", "amount": 9})
	_check(bool(fray_9["ok"]), "AC2: 9 fray gain event accepted")
	_check(int(fray_9["delta"]) == 0, "AC2: 9 fray gain delta is 0")
	_check(fear.get_fear() == 0, "AC2: 9 fray gain leaves fear at 0")

	var fray_10 := fear.apply_observed_event({"kind": "fray_gain", "amount": 10})
	_check(bool(fray_10["ok"]), "AC2: 10 fray gain event accepted")
	_check(int(fray_10["delta"]) == 2, "AC2: 10 fray gain delta is +2")
	_check(fear.get_fear() == 2, "AC2: 10 fray gain raises fear to 2")

	# Support alternative key alias "change".
	var fray_15 := fear.apply_observed_event({"kind": "fray", "change": 15})
	_check(bool(fray_15["ok"]), "AC2: 15 fray change event accepted")
	_check(int(fray_15["delta"]) == 2, "AC2: 15 fray change delta is +2")
	_check(fear.get_fear() == 4, "AC2: 15 fray change raises fear to 4")

	# 2. Entering Hanging adds +5.
	var hanging := fear.apply_observed_event({"kind": "hanging"})
	_check(bool(hanging["ok"]), "AC2: hanging event accepted")
	_check(int(hanging["delta"]) == 5, "AC2: hanging delta is +5")
	_check(fear.get_fear() == 9, "AC2: hanging raises fear from 4 to 9")

	# 3. Loss adds +15.
	var lost := fear.apply_observed_event({"kind": "lost"})
	_check(bool(lost["ok"]), "AC2: lost event accepted")
	_check(int(lost["delta"]) == 15, "AC2: lost delta is +15")
	_check(fear.get_fear() == 24, "AC2: loss raises fear from 9 to 24")

	# 4. Completed round: GLOOM +1, DARK +2, SNUFFED +3, BRIGHT 0, DIM 0.
	# Test via explicit band names.
	var gloom_round := fear.apply_observed_event({"kind": "round_completed", "band": "gloom"})
	_check(bool(gloom_round["ok"]) and int(gloom_round["delta"]) == 1, "AC2: gloom round delta is +1")
	_check(fear.get_fear() == 25, "AC2: fear is 25 after gloom round")

	var dark_round := fear.apply_observed_event({"kind": "round_completed", "band": "dark"})
	_check(bool(dark_round["ok"]) and int(dark_round["delta"]) == 2, "AC2: dark round delta is +2")
	_check(fear.get_fear() == 27, "AC2: fear is 27 after dark round")

	var snuffed_round := fear.apply_observed_event({"kind": "round_completed", "band": "snuffed"})
	_check(bool(snuffed_round["ok"]) and int(snuffed_round["delta"]) == 3, "AC2: snuffed round delta is +3")
	_check(fear.get_fear() == 30, "AC2: fear is 30 after snuffed round")

	var bright_round := fear.apply_observed_event({"kind": "round_completed", "band": "bright"})
	_check(bool(bright_round["ok"]) and int(bright_round["delta"]) == 0, "AC2: bright round delta is 0")
	_check(fear.get_fear() == 30, "AC2: fear remains 30 after bright round")

	var dim_round := fear.apply_observed_event({"kind": "round_completed", "band": "dim"})
	_check(bool(dim_round["ok"]) and int(dim_round["delta"]) == 0, "AC2: dim round delta is 0")
	_check(fear.get_fear() == 30, "AC2: fear remains 30 after dim round")

	# Test via caller-supplied candle integer values (read-only projection).
	# BRIGHT: 76..100 -> 0
	var candle_100 := fear.apply_observed_event({"kind": "round", "candle": 100})
	_check(bool(candle_100["ok"]) and int(candle_100["delta"]) == 0, "AC2: candle 100 (Bright) delta is 0")
	var candle_76 := fear.apply_observed_event({"kind": "round", "candle": 76})
	_check(bool(candle_76["ok"]) and int(candle_76["delta"]) == 0, "AC2: candle 76 (Bright edge) delta is 0")

	# DIM: 51..75 -> 0
	var candle_75 := fear.apply_observed_event({"kind": "round", "candle": 75})
	_check(bool(candle_75["ok"]) and int(candle_75["delta"]) == 0, "AC2: candle 75 (Dim edge) delta is 0")
	var candle_51 := fear.apply_observed_event({"kind": "round", "candle": 51})
	_check(bool(candle_51["ok"]) and int(candle_51["delta"]) == 0, "AC2: candle 51 (Dim edge) delta is 0")

	# GLOOM: 26..50 -> +1
	var candle_50 := fear.apply_observed_event({"kind": "round", "candle": 50})
	_check(bool(candle_50["ok"]) and int(candle_50["delta"]) == 1, "AC2: candle 50 (Gloom edge) delta is +1")
	var candle_26 := fear.apply_observed_event({"kind": "round", "candle": 26})
	_check(bool(candle_26["ok"]) and int(candle_26["delta"]) == 1, "AC2: candle 26 (Gloom edge) delta is +1")

	# DARK: 1..25 -> +2
	var candle_25 := fear.apply_observed_event({"kind": "round", "candle": 25})
	_check(bool(candle_25["ok"]) and int(candle_25["delta"]) == 2, "AC2: candle 25 (Dark edge) delta is +2")
	var candle_1 := fear.apply_observed_event({"kind": "round", "candle": 1})
	_check(bool(candle_1["ok"]) and int(candle_1["delta"]) == 2, "AC2: candle 1 (Dark edge) delta is +2")

	# SNUFFED: 0 -> +3
	var candle_0 := fear.apply_observed_event({"kind": "round", "candle": 0})
	_check(bool(candle_0["ok"]) and int(candle_0["delta"]) == 3, "AC2: candle 0 (Snuffed) delta is +3")

	# 5. Reductions: Steadfast -10, Won fight -10, Campfire Tell Tales -15.
	var cur_fear := fear.get_fear()
	var steadfast := fear.apply_observed_event({"kind": "steadfast"})
	_check(bool(steadfast["ok"]) and int(steadfast["delta"]) == -10, "AC2: steadfast delta is -10")
	_check(fear.get_fear() == cur_fear - 10, "AC2: steadfast reduces fear by 10")

	cur_fear = fear.get_fear()
	var fight_won := fear.apply_observed_event({"kind": "fight_won"})
	_check(bool(fight_won["ok"]) and int(fight_won["delta"]) == -10, "AC2: fight_won delta is -10")
	_check(fear.get_fear() == cur_fear - 10, "AC2: fight_won reduces fear by 10")

	cur_fear = fear.get_fear()
	var tell_tales := fear.apply_observed_event({"kind": "tell_tales"})
	_check(bool(tell_tales["ok"]) and int(tell_tales["delta"]) == -15, "AC2: tell_tales delta is -15")
	_check(fear.get_fear() == cur_fear - 15, "AC2: tell_tales reduces fear by 15")

	# 6. Clamping boundaries: floor at 0 and cap at 100.
	fear.reset(5)
	_check(fear.get_fear() == 5, "AC2: reset to 5 for floor check")
	var floor_test := fear.apply_observed_event({"kind": "tell_tales"})
	_check(bool(floor_test["ok"]), "AC2: tell_tales from 5 accepted")
	_check(int(floor_test["delta"]) == -15, "AC2: tell_tales delta reports -15")
	_check(fear.get_fear() == 0, "AC2: fear clamped at 0 floor")

	# Repeat at 0 with further negative deltas.
	var floor_again := fear.apply_observed_event({"kind": "fight_won"})
	_check(fear.get_fear() == 0, "AC2: fear remains at 0 floor after fight_won")

	# Cap boundary:
	fear.reset(95)
	_check(fear.get_fear() == 95, "AC2: reset to 95 for cap check")
	var cap_test := fear.apply_observed_event({"kind": "lost"})
	_check(bool(cap_test["ok"]), "AC2: lost event from 95 accepted")
	_check(int(cap_test["delta"]) == 15, "AC2: lost delta reports +15")
	_check(fear.get_fear() == 100, "AC2: fear clamped at 100 cap")

	# Overshoot at 100:
	var cap_again := fear.apply_observed_event({"kind": "fray_gain", "amount": 10})
	_check(fear.get_fear() == 100, "AC2: fear remains at 100 cap")


func _test_ac3_shaky_hands_and_rng_neutrality() -> void:
	var fear := StitchedKidFear.new()

	# Fear 49: SHAKE is false, hand action cannot fail from fear regardless of roll.
	fear.reset(49)
	_check(fear.get_fear() == 49, "AC3: fear set to 49")
	_check(not fear.is_shaking(), "AC3: is_shaking() false at 49")
	_check(not fear.shake(), "AC3: shake() false at 49")
	_check(not bool(fear.state_snapshot()["shake"]), "AC3: snapshot shake false at 49")

	for roll in [1, 25, 26, 100]:
		var check := fear.check_hand_failure(roll)
		_check(bool(check.get("ok", false)), "AC3: check_hand_failure at 49 succeeds for roll %d" % roll)
		_check(not bool(check.get("shake", true)), "AC3: check shake false at fear 49 for roll %d" % roll)
		_check(not bool(check.get("failed", true)), "AC3: hand action cannot fail at fear 49 for roll %d" % roll)
		_check(not fear.hand_action_fails(roll), "AC3: hand_action_fails() false at fear 49 for roll %d" % roll)

	# Fear 50: SHAKE is true, hand action fails only on rolls 1..25.
	fear.reset(50)
	_check(fear.get_fear() == 50, "AC3: fear set to 50")
	_check(fear.is_shaking(), "AC3: is_shaking() true at 50")
	_check(fear.shake(), "AC3: shake() true at 50")
	_check(bool(fear.state_snapshot()["shake"]), "AC3: snapshot shake true at 50")

	# Roll 1: fails
	var r1 := fear.check_hand_failure(1)
	_check(bool(r1["ok"]) and bool(r1["shake"]) and bool(r1["failed"]), "AC3: roll 1 fails at fear 50")
	_check(fear.hand_action_fails(1), "AC3: hand_action_fails(1) is true")

	# Roll 25: fails (boundary)
	var r25 := fear.check_hand_failure(25)
	_check(bool(r25["ok"]) and bool(r25["shake"]) and bool(r25["failed"]), "AC3: roll 25 fails at fear 50")
	_check(fear.hand_action_fails(25), "AC3: hand_action_fails(25) is true")

	# Roll 26: succeeds (boundary)
	var r26 := fear.check_hand_failure(26)
	_check(bool(r26["ok"]) and bool(r26["shake"]) and not bool(r26["failed"]), "AC3: roll 26 succeeds at fear 50")
	_check(not fear.hand_action_fails(26), "AC3: hand_action_fails(26) is false")

	# Roll 100: succeeds
	var r100 := fear.check_hand_failure(100)
	_check(bool(r100["ok"]) and bool(r100["shake"]) and not bool(r100["failed"]), "AC3: roll 100 succeeds at fear 50")
	_check(not fear.hand_action_fails(100), "AC3: hand_action_fails(100) is false")

	# Test seeded caller RNG state before and after: helper never draws RNG.
	var caller_rng := RandomNumberGenerator.new()
	caller_rng.seed = 987654321
	var rng_state_before := caller_rng.state

	# Run multiple failure checks across various fear levels.
	for test_fear in [0, 49, 50, 75, 100]:
		fear.reset(test_fear)
		for test_roll in [1, 10, 25, 26, 50, 100]:
			fear.check_hand_failure(test_roll)
			fear.hand_action_fails(test_roll)

	var rng_state_after := caller_rng.state
	_check(rng_state_before == rng_state_after, "AC3: caller RNG state untouched after all hand failure checks")


func _test_ac4_lost_strings_interruption_lifecycle() -> void:
	var fear := StitchedKidFear.new(99)
	_check(fear.get_fear() == 99, "AC4: setup at fear 99")
	_check(not fear.has_pending_lost_strings(), "AC4: no pending interruption at fear 99")

	# 1. 99 -> 100 threshold crossing queues exactly one Lose the Strings interruption.
	var reach_100 := fear.apply_observed_event({"kind": "fray_gain", "amount": 10})
	_check(bool(reach_100["ok"]), "AC4: 99->100 event accepted")
	_check(fear.get_fear() == 100, "AC4: fear reaches 100")
	_check(bool(reach_100["interruption_queued"]), "AC4: interruption_queued is true on reaching 100")
	_check(fear.has_pending_lost_strings(), "AC4: pending lost strings is true")

	# 2. Repeated events at 100 do not stack interruptions.
	var repeat_1 := fear.apply_observed_event({"kind": "fray_gain", "amount": 10})
	_check(bool(repeat_1["ok"]), "AC4: repeated event at 100 accepted")
	_check(fear.get_fear() == 100, "AC4: fear remains 100")
	_check(not bool(repeat_1["interruption_queued"]), "AC4: interruption_queued false for subsequent event at 100")
	_check(fear.has_pending_lost_strings(), "AC4: still pending lost strings")

	var repeat_2 := fear.apply_observed_event({"kind": "hanging"})
	_check(bool(repeat_2["ok"]), "AC4: second repeated event at 100 accepted")
	_check(not bool(repeat_2["interruption_queued"]), "AC4: second repeated event does not queue extra interruption")

	# 3. First doll-turn admission: consumes interruption, skips turn, resets fear to 60, clears queue.
	var turn_1 := fear.consume_next_doll_turn()
	_check(bool(turn_1["ok"]), "AC4: first doll turn admission consumes interruption")
	_check(bool(turn_1["skip_turn"]), "AC4: first doll turn is skipped")
	_check(str(turn_1["interruption"]) == "lose_the_strings", "AC4: receipt identifies lose_the_strings interruption")
	_check(int(turn_1["before_fear"]) == 100, "AC4: before_fear was 100")
	_check(int(turn_1["after_fear"]) == 60, "AC4: after_fear is 60")
	_check(fear.get_fear() == 60, "AC4: service fear is reset to 60")
	_check(not fear.has_pending_lost_strings(), "AC4: pending interruption is cleared")

	# 4. Second doll-turn admission: no pending interruption, proceeds without skip.
	var turn_2 := fear.consume_next_doll_turn()
	_check(not bool(turn_2["ok"]), "AC4: second doll turn admission reports no interruption to consume")
	_check(not bool(turn_2["skip_turn"]), "AC4: second doll turn is NOT skipped")
	_check(fear.get_fear() == 60, "AC4: fear remains 60")
	_check(not fear.has_pending_lost_strings(), "AC4: queue remains clear")

	# 5. Overshoot test: 90 + 15 -> 100 queues interruption.
	fear.reset(90)
	var overshoot := fear.apply_observed_event({"kind": "lost"})
	_check(bool(overshoot["ok"]), "AC4: overshoot event accepted")
	_check(fear.get_fear() == 100, "AC4: fear clamped to 100 on overshoot")
	_check(bool(overshoot["interruption_queued"]), "AC4: interruption queued on overshoot to 100")
	_check(fear.has_pending_lost_strings(), "AC4: pending lost strings is true after overshoot")

	# Consume the overshoot interruption.
	var turn_overshoot := fear.consume_next_doll_turn()
	_check(bool(turn_overshoot["ok"]) and bool(turn_overshoot["skip_turn"]), "AC4: consumed overshoot interruption")
	_check(fear.get_fear() == 60, "AC4: fear back to 60")

	# 6. Second independent threshold crossing from 60 back to 100.
	# 60 + 15 (lost) = 75
	fear.apply_observed_event({"kind": "lost"})
	# 75 + 15 (lost) = 90
	fear.apply_observed_event({"kind": "lost"})
	# 90 + 2 (fray 10) = 92
	fear.apply_observed_event({"kind": "fray_gain", "amount": 10})
	# 92 - 10 (steadfast) = 82
	fear.apply_observed_event({"kind": "steadfast"})
	# 82 + 15 (lost) = 97
	fear.apply_observed_event({"kind": "lost"})
	_check(fear.get_fear() == 97, "AC4: fear reached 97 on re-ascent")
	_check(not fear.has_pending_lost_strings(), "AC4: no pending interruption before 100")

	# 97 + 5 (hanging) -> 100!
	var re_cross := fear.apply_observed_event({"kind": "hanging"})
	_check(fear.get_fear() == 100, "AC4: fear reached 100 again")
	_check(bool(re_cross["interruption_queued"]), "AC4: interruption queued on second threshold crossing")
	_check(fear.has_pending_lost_strings(), "AC4: pending lost strings true on second crossing")

	# Consume the second interruption.
	var turn_re_cross := fear.consume_next_doll_turn()
	_check(bool(turn_re_cross["ok"]) and bool(turn_re_cross["skip_turn"]), "AC4: second interruption consumed")
	_check(fear.get_fear() == 60, "AC4: fear reset to 60 on second crossing")
	_check(not fear.has_pending_lost_strings(), "AC4: queue cleared after second crossing")


func _test_ac5_negative_atomicity_and_stale_guards() -> void:
	var fear := StitchedKidFear.new(20)
	var snap_before := fear.state_snapshot()
	var seq_before := fear.get_sequence()

	# 1. Unknown event kind fails atomically with equal sequence.
	var unknown := fear.apply_observed_event({"kind": "summon_tea_party"})
	_check(not bool(unknown["ok"]), "AC5: unknown event kind rejected")
	_check(int(unknown["sequence"]) == seq_before, "AC5: rejected unknown event returns equal sequence")
	_check(fear.get_sequence() == seq_before, "AC5: service sequence unchanged after unknown event")
	_check(fear.get_fear() == 20, "AC5: service fear unchanged after unknown event")

	# 2. Invalid event payloads fail atomically.
	var neg_fray := fear.apply_observed_event({"kind": "fray", "amount": -10})
	_check(not bool(neg_fray["ok"]), "AC5: negative fray gain rejected")
	_check(int(neg_fray["sequence"]) == seq_before, "AC5: sequence unchanged after negative fray")

	var bad_fray_type := fear.apply_observed_event({"kind": "fray", "amount": "huge"})
	_check(not bool(bad_fray_type["ok"]), "AC5: non-numeric fray amount rejected")

	var bad_candle := fear.apply_observed_event({"kind": "round", "candle": 999})
	_check(not bool(bad_candle["ok"]), "AC5: out-of-bounds candle rejected")

	var bad_band := fear.apply_observed_event({"kind": "round", "band": "starlight"})
	_check(not bool(bad_band["ok"]), "AC5: unrecognized candle band rejected")

	var empty_round := fear.apply_observed_event({"kind": "round"})
	_check(not bool(empty_round["ok"]), "AC5: round event without band or candle rejected")

	var non_dict := fear.apply_observed_event("not_a_dictionary")
	_check(not bool(non_dict["ok"]), "AC5: non-dictionary event rejected")

	var null_event := fear.apply_observed_event(null)
	_check(not bool(null_event["ok"]), "AC5: null event rejected")

	# Check hand action invalid rolls.
	var bad_roll_low := fear.check_hand_failure(0)
	_check(not bool(bad_roll_low["ok"]), "AC5: roll 0 rejected")
	var bad_roll_high := fear.check_hand_failure(101)
	_check(not bool(bad_roll_high["ok"]), "AC5: roll 101 rejected")
	var bad_roll_type := fear.check_hand_failure("not_a_number")
	_check(not bool(bad_roll_type["ok"]), "AC5: non-numeric roll rejected")

	_check(fear.state_snapshot() == snap_before, "AC5: state completely unchanged after all invalid payloads")

	# 3. Invalid initial fear fails.
	var bad_init_neg := StitchedKidFear.create(-1)
	_check(not bool(bad_init_neg["ok"]), "AC5: create(-1) rejected")
	var bad_init_high := StitchedKidFear.create(101)
	_check(not bool(bad_init_high["ok"]), "AC5: create(101) rejected")
	var bad_init_type := StitchedKidFear.create("bogus")
	_check(not bool(bad_init_type["ok"]), "AC5: create('bogus') rejected")

	var reset_neg := fear.reset(-5)
	_check(not bool(reset_neg["ok"]), "AC5: reset(-5) rejected")
	_check(fear.get_fear() == 20, "AC5: fear unchanged after failed reset")
	_check(int(reset_neg["sequence"]) == fear.get_sequence(), "AC5: failed reset returns equal sequence")


	# Strict integer inputs: fractional, whole-valued floats and nonfinite
	# payloads must be refused BEFORE any conversion (including at boundaries).
	var refused_numbers: Array = [-0.5, 0.5, 1.0, 9.5, 10.0, 25.9, 50.0, 99.9, 100.0, 101.0, NAN, INF, -INF]
	var caller_rng := RandomNumberGenerator.new()
	caller_rng.seed = 616099
	var rng_before := caller_rng.state
	for invalid in refused_numbers:
		var label := str(invalid)
		var created := StitchedKidFear.create(invalid)
		_check(not bool(created.get("ok", true)), "AC5: create rejects float %s" % label)
		_check(int(created.get("sequence", -1)) == 0, "AC5: rejected create leaves initial sequence zero for %s" % label)
		var direct := StitchedKidFear.new(invalid)
		_check(not direct.is_valid(), "AC5: _init rejects float %s" % label)
		_check(direct.state_snapshot() == {"fear": 0, "shake": false, "pending_lost_strings": false, "sequence": 0}, "AC5: invalid _init has no fear, queued turn or sequence for %s" % label)
		_check(caller_rng.state == rng_before, "AC5: creation refusal leaves caller RNG unchanged for %s" % label)

	# Repeat across neutral, shaking and already-queued states. An invalid
	# input must neither consume Lose the Strings nor alter its snapshot.
	for starting_fear in [20, 50, 100]:
		var probe := StitchedKidFear.new(starting_fear)
		_check(probe.is_valid() and probe.get_fear() == starting_fear, "AC5: refusal fixture constructed at %d" % starting_fear)
		_check(probe.is_shaking() == (starting_fear >= 50), "AC5: fixture shake precondition at %d" % starting_fear)
		_check(probe.has_pending_lost_strings() == (starting_fear == 100), "AC5: fixture pending precondition at %d" % starting_fear)
		var before := probe.state_snapshot()
		for invalid in refused_numbers:
			var label := "%d / %s" % [starting_fear, str(invalid)]
			_check_refusal_atomic(probe, probe.reset(invalid), before, caller_rng, rng_before, "reset " + label)
			_check_refusal_atomic(probe, probe.check_hand_failure(invalid), before, caller_rng, rng_before, "hand roll " + label)
			for fray_key in ["amount", "change", "gain", "fray", "fray_gain"]:
				var fray_event := {"kind": "fray_gain"}
				fray_event[fray_key] = invalid
				_check_refusal_atomic(probe, probe.apply_observed_event(fray_event), before, caller_rng, rng_before, "fray %s %s" % [fray_key, label])
			_check_refusal_atomic(probe, probe.apply_observed_event({"kind": "round", "candle": invalid}), before, caller_rng, rng_before, "round candle " + label)

		# Integer bounds still fail closed; the valid endpoints remain legal.
		for bad_event in [{"kind": "fray_gain", "amount": -1}, {"kind": "round", "candle": -1}, {"kind": "round", "candle": 101}]:
			_check_refusal_atomic(probe, probe.apply_observed_event(bad_event), before, caller_rng, rng_before, "integer bounds at %d: %s" % [starting_fear, str(bad_event)])

	# Defaults/null remain the allowed ways to start or clear FEAR.
	for allowed in [0, 50, 100, null]:
		var built_valid := StitchedKidFear.create(allowed)
		_check(bool(built_valid.get("ok", false)), "AC5: create allows native integer/null %s" % str(allowed))
		var constructed := StitchedKidFear.new(allowed)
		_check(constructed.is_valid(), "AC5: _init allows native integer/null %s" % str(allowed))
		var expected := 0 if allowed == null else int(allowed)
		_check(constructed.get_fear() == expected and constructed.has_pending_lost_strings() == (expected == 100), "AC5: valid _init preserves fear and queue at %s" % str(allowed))
		var reset_probe := StitchedKidFear.new(100)
		var reset_ok := reset_probe.reset(allowed)
		_check(bool(reset_ok.get("ok", false)) and reset_probe.get_fear() == expected, "AC5: reset accepts native integer/null %s" % str(allowed))
		_check(reset_probe.get_sequence() == 1 and reset_probe.has_pending_lost_strings() == (expected == 100), "AC5: accepted reset updates sequence and queue at %s" % str(allowed))
	_check(bool(StitchedKidFear.create().get("ok", false)), "AC5: default create is accepted")
	var default_reset := StitchedKidFear.new(100)
	_check(bool(default_reset.reset().get("ok", false)) and default_reset.get_fear() == 0 and not default_reset.has_pending_lost_strings(), "AC5: default reset clears queued fear")
	_check(caller_rng.state == rng_before, "AC5: all strict input checks preserve caller RNG")

	# 4. Stale expected snapshot guard.
	var valid_snap := fear.state_snapshot()
	# Apply a legal event to advance state and sequence.
	var advance := fear.apply_observed_event({"kind": "hanging"})
	_check(bool(advance["ok"]), "AC5: advance event accepted")
	_check(fear.get_sequence() == seq_before + 1, "AC5: sequence advanced to %d" % (seq_before + 1))

	# Attempt to apply event with old stale snapshot.
	var stale_apply := fear.apply_observed_event({"kind": "lost"}, valid_snap)
	_check(not bool(stale_apply["ok"]), "AC5: stale snapshot apply rejected")
	_check(str(stale_apply["error"]).contains("stale"), "AC5: error message indicates stale snapshot")
	_check(fear.get_sequence() == seq_before + 1, "AC5: sequence unchanged after stale rejection")
	_check(fear.get_fear() == 25, "AC5: fear unchanged after stale rejection")

	# Attempt to consume doll turn with stale snapshot.
	fear.reset(100)
	var snap_100 := fear.state_snapshot()
	# Advance sequence by an event while at 100.
	fear.apply_observed_event({"kind": "fray_gain", "amount": 10})
	var stale_consume := fear.consume_next_doll_turn(snap_100)
	_check(not bool(stale_consume["ok"]), "AC5: stale snapshot consume rejected")
	_check(str(stale_consume["error"]).contains("stale"), "AC5: error message indicates stale snapshot")
	_check(fear.has_pending_lost_strings(), "AC5: pending interruption not consumed on stale check")

	# 5. Attempts to consume an absent interruption.
	fear.reset(30)
	var absent_snap := fear.state_snapshot()
	var absent_consume := fear.consume_next_doll_turn()
	_check(not bool(absent_consume["ok"]), "AC5: consume absent interruption rejected")
	_check(not bool(absent_consume["skip_turn"]), "AC5: skip_turn is false for absent interruption")
	_check(fear.get_fear() == 30, "AC5: fear unchanged after absent consume")
	_check(int(absent_consume["sequence"]) == fear.get_sequence(), "AC5: equal sequence returned for absent consume")
	_check(fear.state_snapshot() == absent_snap, "AC5: state snapshot unchanged after absent consume")

	# 6. Verify caller-owned dictionary immutability.
	var caller_event := {
		"kind": "fray_gain",
		"amount": 10,
		"caller_private": [1, 2, 3],
		"nested": {"x": 10},
	}
	var caller_copy := caller_event.duplicate(true)
	fear.apply_observed_event(caller_event)
	_check(caller_event == caller_copy, "AC5: caller-owned dictionary not mutated by apply_observed_event")


## Shared refusal contract: compare the actual reachable service, not a detached
## test stand-in, including queue/shake/snapshot and the caller's RNG state.
func _check_refusal_atomic(service: StitchedKidFear, receipt: Dictionary, before: Dictionary, caller_rng: RandomNumberGenerator, rng_before: int, label: String) -> void:
	_check(not bool(receipt.get("ok", true)), "AC5: refuses " + label)
	_check(int(receipt.get("sequence", -1)) == int(before["sequence"]), "AC5: refusal reports unchanged sequence " + label)
	_check(service.get_sequence() == int(before["sequence"]), "AC5: sequence remains unchanged " + label)
	_check(service.get_fear() == int(before["fear"]), "AC5: FEAR remains unchanged " + label)
	_check(service.is_shaking() == bool(before["shake"]), "AC5: shake remains unchanged " + label)
	_check(service.has_pending_lost_strings() == bool(before["pending_lost_strings"]), "AC5: pending interruption remains unchanged " + label)
	_check(service.state_snapshot() == before, "AC5: entire state snapshot remains unchanged " + label)
	_check(caller_rng.state == rng_before, "AC5: caller RNG state remains unchanged " + label)
