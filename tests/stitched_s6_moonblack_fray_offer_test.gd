extends SceneTree
## Deterministic headless SceneTree test for S6 Moonblack Paperweight fray-relief gate.
##
## Validates that paying 16 gold for buy_quiet_house_plan at v3_moonblack_paperweight
## is admitted only when at least one surviving (non-LOST) doll has fray >= 1.
## Validates lift_shadowed_map full-candle gating, neutral leave, immutability of
## caller snapshots, deterministic same-seed replay, and zero caller RNG draws.

const EFFECTS_PATH := "res://data/events/stitched_route_effects.json"
const CANONICAL_HEROES := ["warden", "seamstress", "tinker", "lantern_monk"]

var checks: int = 0
var failures: Array[String] = []


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_moonblack_record() -> Dictionary:
	var file := FileAccess.open(EFFECTS_PATH, FileAccess.READ)
	_check(file != null, "stitched_route_effects.json opens through FileAccess")
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	_check(parsed is Dictionary, "stitched_route_effects.json root is a Dictionary")
	if not parsed is Dictionary:
		return {}
	var events: Variant = (parsed as Dictionary).get("events")
	_check(events is Array, "stitched_route_effects.json carries events Array")
	if not events is Array:
		return {}
	for ev in events:
		if ev is Dictionary and (ev as Dictionary).get("id") == "v3_moonblack_paperweight":
			return (ev as Dictionary).duplicate(true)
	_check(false, "v3_moonblack_paperweight found in stitched_route_effects.json")
	return {}


func _find_choice(record: Dictionary, choice_id: String) -> Dictionary:
	for c in record.get("choices", []):
		if c is Dictionary and (c as Dictionary).get("id") == choice_id:
			return (c as Dictionary).duplicate(true)
	return {}


func _entry(preview: Dictionary, choice_id: String) -> Dictionary:
	for c in preview.get("choices", []):
		if c is Dictionary and (c as Dictionary).get("choice_id") == choice_id:
			return (c as Dictionary).duplicate(true)
	return {}


func _make_snapshot(candle: int, gold: int, scraps: int, satchel_count: int, frays: Array, lost_flags: Array = []) -> Dictionary:
	var party: Array = []
	for i in range(CANONICAL_HEROES.size()):
		var hero_id: String = CANONICAL_HEROES[i]
		var fray_val: int = frays[i] if i < frays.size() else 0
		var lost_val: bool = lost_flags[i] if i < lost_flags.size() else false
		party.append({
			"id": hero_id,
			"fray": fray_val,
			"lost": lost_val,
		})
	return {
		"candle": candle,
		"party": party,
		"gold": gold,
		"scraps": scraps,
		"satchel_count": satchel_count,
	}


func _initialize() -> void:
	var record := _load_moonblack_record()
	_check(not record.is_empty(), "authored Moonblack Paperweight record loaded")

	_test_ac1_authored_schema(record)
	_test_ac2_calm_survivors_and_lost_warden(record)
	_test_ac3_frayed_survivors_admission_and_settlement(record)
	_test_ac4_underfunded_lift_and_leave(record)
	_test_replay_and_rng_invariants(record)

	if failures.is_empty():
		print("stitched_s6_moonblack_fray_offer_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("stitched_s6_moonblack_fray_offer_test: FAILED (%d/%d checks failed)" % [failures.size(), checks])
		quit(1)


## AC1: Verify authored record fields, choice IDs, texts, and stitched_effect shapes.
## Only buy_quiet_house_plan has min_fray: 1.
func _test_ac1_authored_schema(record: Dictionary) -> void:
	_check(record.get("id") == "v3_moonblack_paperweight", "AC1: event id is v3_moonblack_paperweight")
	_check(record.get("title") == "The Moonblack Paperweight", "AC1: event title is The Moonblack Paperweight")
	_check(record.get("description") == "A moonblack glass paperweight pins a torn house plan to the floorboards; a small cream-felt mapkeeper waits beneath its cold reflection, holding an ink-stained spool.", "AC1: event description matches")

	var choices: Array = record.get("choices", [])
	_check(choices.size() == 3, "AC1: exactly three choices present")

	var buy_choice := _find_choice(record, "buy_quiet_house_plan")
	_check(not buy_choice.is_empty(), "AC1: buy_quiet_house_plan choice present")
	_check(buy_choice.get("text") == "Pay 16 gold for a reassuring house plan (every doll settles)", "AC1: buy_quiet_house_plan text matches")
	var buy_effect: Dictionary = buy_choice.get("stitched_effect", {})
	_check(buy_effect.get("target") == "party", "AC1: buy target is party")
	_check(int(buy_effect.get("candle")) == 0, "AC1: buy candle delta is 0")
	_check(int(buy_effect.get("fray")) == -10, "AC1: buy fray delta is -10")
	_check(int(buy_effect.get("gold")) == -16, "AC1: buy gold delta is -16")
	_check(int(buy_effect.get("min_fray")) == 1, "AC1: buy min_fray is native-integer 1")
	_check(buy_effect.size() == 5, "AC1: buy stitched_effect contains exactly 5 keys")

	var lift_choice := _find_choice(record, "lift_shadowed_map")
	_check(not lift_choice.is_empty(), "AC1: lift_shadowed_map choice present")
	_check(lift_choice.get("text") == "Lift the shadowed weight (+23 gold, -10 candle; every doll strains)", "AC1: lift text matches")
	var lift_effect: Dictionary = lift_choice.get("stitched_effect", {})
	_check(lift_effect.get("target") == "party", "AC1: lift target is party")
	_check(int(lift_effect.get("candle")) == -10, "AC1: lift candle delta is -10")
	_check(int(lift_effect.get("fray")) == 7, "AC1: lift fray delta is 7")
	_check(int(lift_effect.get("gold")) == 23, "AC1: lift gold delta is 23")
	_check(lift_effect.get("require_full_candle") == true, "AC1: lift requires full candle")
	_check(not lift_effect.has("min_fray"), "AC1: lift has no min_fray")
	_check(lift_effect.size() == 5, "AC1: lift stitched_effect contains exactly 5 keys")

	var leave_choice := _find_choice(record, "leave")
	_check(not leave_choice.is_empty(), "AC1: leave choice present")
	_check(leave_choice.get("text") == "Leave the black glass holding down the plan", "AC1: leave text matches")
	var leave_effect: Dictionary = leave_choice.get("stitched_effect", {})
	_check(leave_effect.get("target") == "party", "AC1: leave target is party")
	_check(int(leave_effect.get("candle")) == 0, "AC1: leave candle delta is 0")
	_check(int(leave_effect.get("fray")) == 0, "AC1: leave fray delta is 0")
	_check(not leave_effect.has("min_fray"), "AC1: leave has no min_fray")
	_check(leave_effect.size() == 3, "AC1: leave stitched_effect contains exactly 3 keys")


## AC2: When all surviving heroes have fray 0, buy_quiet_house_plan is present but unavailable;
## choose rejects it without claim or mutation. A lost hero with fray 150 does not qualify.
func _test_ac2_calm_survivors_and_lost_warden(record: Dictionary) -> void:
	# Witness 1: four survivors all FRAY 0
	var snap_calm := _make_snapshot(80, 16, 0, 0, [0, 0, 0, 0])
	var snap_calm_before := snap_calm.duplicate(true)
	var svc_calm := RunStitchedEventConsequence.new(record)
	_check(svc_calm.is_valid() and not svc_calm.is_claimed(), "AC2: calm survivors service opens fresh")

	var prev_calm := svc_calm.preview(snap_calm)
	_check(prev_calm.get("ok") == true, "AC2: calm preview ok")
	var buy_calm := _entry(prev_calm, "buy_quiet_house_plan")
	_check(not buy_calm.is_empty(), "AC2: buy choice present in calm preview")
	_check(buy_calm.get("available") == false, "AC2: buy choice unavailable when all fray 0")
	_check(int(buy_calm.get("candle_delta")) == 0, "AC2: buy candle_delta readable")
	_check(int(buy_calm.get("fray_delta")) == -10, "AC2: buy fray_delta readable")
	_check(int(buy_calm.get("gold_delta")) == -16, "AC2: buy gold_delta readable")
	_check(int(buy_calm.get("gold")) == 16, "AC2: buy gold shows unchanged balance")
	_check(buy_calm.get("fray") == {}, "AC2: buy fray projection empty when unavailable")

	var ref_calm := svc_calm.choose("buy_quiet_house_plan", snap_calm)
	_check(ref_calm.get("ok") == false and int(ref_calm.get("candle")) == 80, "AC2: calm choose refused")
	_check(svc_calm.is_valid() and not svc_calm.is_claimed(), "AC2: calm refusal leaves service unclaimed and valid")
	_check(snap_calm == snap_calm_before, "AC2: calm refusal does not mutate caller snapshot")

	# Witness 2: LOST Warden at FRAY 150 with three calm survivors
	var snap_lost := _make_snapshot(80, 16, 0, 0, [150, 0, 0, 0], [true, false, false, false])
	var snap_lost_before := snap_lost.duplicate(true)
	var svc_lost := RunStitchedEventConsequence.new(record)

	var prev_lost := svc_lost.preview(snap_lost)
	var buy_lost := _entry(prev_lost, "buy_quiet_house_plan")
	_check(buy_lost.get("available") == false, "AC2: LOST Warden with fray 150 does not qualify calm survivors")
	_check(buy_lost.get("fray") == {}, "AC2: fray projection empty when only lost hero has fray")

	var ref_lost := svc_lost.choose("buy_quiet_house_plan", snap_lost)
	_check(ref_lost.get("ok") == false, "AC2: choose refused with LOST frayed hero and calm survivors")
	_check(svc_lost.is_valid() and not svc_lost.is_claimed(), "AC2: service unclaimed after lost hero refusal")
	_check(snap_lost == snap_lost_before, "AC2: lost hero refusal does not mutate caller snapshot")


## AC3: With identical funds and at least one survivor at fray >= 1, buy_quiet_house_plan is available
## and commits exactly once. Projects gold 0, candle 80, -10 raw fray intent for each active hero.
func _test_ac3_frayed_survivors_admission_and_settlement(record: Dictionary) -> void:
	# Witness 1: one survivor at FRAY 1 (Warden)
	var snap_fray1 := _make_snapshot(80, 16, 0, 0, [1, 0, 0, 0])
	var snap_fray1_before := snap_fray1.duplicate(true)
	var svc_fray1 := RunStitchedEventConsequence.new(record)

	var prev_fray1 := svc_fray1.preview(snap_fray1)
	var buy_fray1 := _entry(prev_fray1, "buy_quiet_house_plan")
	_check(buy_fray1.get("available") == true, "AC3: fray 1 qualifies buy_quiet_house_plan")
	_check(int(buy_fray1.get("candle")) == 80, "AC3: projected candle is 80")
	_check(int(buy_fray1.get("gold")) == 0, "AC3: projected gold is 0")
	var expected_fray_intent := {
		"warden": -10,
		"seamstress": -10,
		"tinker": -10,
		"lantern_monk": -10,
	}
	_check(buy_fray1.get("fray") == expected_fray_intent, "AC3: preview raw fray intent is -10 each")

	var claim_fray1 := svc_fray1.choose("buy_quiet_house_plan", snap_fray1)
	_check(claim_fray1.get("ok") == true, "AC3: fray 1 purchase succeeds")
	_check(claim_fray1.get("event_id") == "v3_moonblack_paperweight", "AC3: receipt event_id matches")
	_check(claim_fray1.get("choice_id") == "buy_quiet_house_plan", "AC3: receipt choice_id matches")
	_check(int(claim_fray1.get("candle")) == 80, "AC3: receipt candle is 80")
	_check(int(claim_fray1.get("gold")) == 0, "AC3: receipt gold is 0")
	_check(int(claim_fray1.get("gold_delta")) == -16, "AC3: receipt gold_delta is -16")
	_check(claim_fray1.get("fray") == expected_fray_intent, "AC3: receipt fray intent is -10 each")
	_check(svc_fray1.is_claimed() and not svc_fray1.is_valid(), "AC3: service latches after successful claim")
	_check(snap_fray1 == snap_fray1_before, "AC3: claim leaves caller snapshot untouched")

	# Second claim refused
	var repeat := svc_fray1.choose("buy_quiet_house_plan", snap_fray1)
	_check(repeat.get("ok") == false, "AC3: second claim of buy choice is refused")
	var alt_repeat := svc_fray1.choose("leave", snap_fray1)
	_check(alt_repeat.get("ok") == false, "AC3: alternate choice after claim is refused")
	var denied_prev := svc_fray1.preview(snap_fray1)
	_check(denied_prev.get("ok") == false, "AC3: preview after claim is denied")

	# Witness 2: living frayed hero at position 2 (Tinker fray 25) with gold 16
	var snap_tinker := _make_snapshot(80, 16, 0, 0, [0, 0, 25, 0])
	var svc_tinker := RunStitchedEventConsequence.new(record)
	var prev_tinker := svc_tinker.preview(snap_tinker)
	_check(_entry(prev_tinker, "buy_quiet_house_plan").get("available") == true, "AC3: living Tinker fray 25 qualifies")
	var claim_tinker := svc_tinker.choose("buy_quiet_house_plan", snap_tinker)
	_check(claim_tinker.get("ok") == true and int(claim_tinker.get("gold")) == 0, "AC3: Tinker fray 25 claim succeeds")

	# Witness 3: LOST Warden fray 150 + living Seamstress fray 20 qualifies because living survivor has fray
	var snap_mixed := _make_snapshot(80, 16, 0, 0, [150, 20, 0, 0], [true, false, false, false])
	var svc_mixed := RunStitchedEventConsequence.new(record)
	var prev_mixed := svc_mixed.preview(snap_mixed)
	var buy_mixed := _entry(prev_mixed, "buy_quiet_house_plan")
	_check(buy_mixed.get("available") == true, "AC3: living Seamstress qualifies even when Warden is lost")
	var expected_survivor_fray := {
		"seamstress": -10,
		"tinker": -10,
		"lantern_monk": -10,
	}
	_check(buy_mixed.get("fray") == expected_survivor_fray, "AC3: fray intent directed only to active survivors")


## AC4: Insufficient gold refuses purchase even if frayed; lift_shadowed_map candle rules; leave neutrality.
func _test_ac4_underfunded_lift_and_leave(record: Dictionary) -> void:
	# Witness 1: Living FRAY 25 with insufficient gold 15
	var snap_gold15 := _make_snapshot(80, 15, 0, 0, [25, 0, 0, 0])
	var snap_gold15_before := snap_gold15.duplicate(true)
	var svc_gold15 := RunStitchedEventConsequence.new(record)
	var prev_gold15 := svc_gold15.preview(snap_gold15)
	var buy_gold15 := _entry(prev_gold15, "buy_quiet_house_plan")
	_check(buy_gold15.get("available") == false, "AC4: gold 15 refuses buy even with fray 25")
	_check(int(buy_gold15.get("gold")) == 15, "AC4: underfunded buy reports unchanged balance 15")
	var ref_gold15 := svc_gold15.choose("buy_quiet_house_plan", snap_gold15)
	_check(ref_gold15.get("ok") == false, "AC4: choose refused with insufficient gold")
	_check(svc_gold15.is_valid() and not svc_gold15.is_claimed(), "AC4: service unclaimed after underfunded refusal")
	_check(snap_gold15 == snap_gold15_before, "AC4: caller snapshot unchanged by underfunded refusal")

	# Leave succeeds on the same visit after refusal
	var leave_after_refusal := svc_gold15.choose("leave", snap_gold15)
	_check(leave_after_refusal.get("ok") == true, "AC4: Leave claims after underfunded refusal")
	_check(svc_gold15.is_claimed() and not svc_gold15.is_valid(), "AC4: service latches after Leave")

	# Witness 2: lift_shadowed_map at insufficient candle 9
	var snap_candle9 := _make_snapshot(9, 16, 0, 0, [0, 0, 0, 0])
	var svc_candle9 := RunStitchedEventConsequence.new(record)
	var prev_candle9 := svc_candle9.preview(snap_candle9)
	var lift_candle9 := _entry(prev_candle9, "lift_shadowed_map")
	_check(lift_candle9.get("available") == false, "AC4: lift unavailable at candle 9 due to require_full_candle")
	var ref_candle9 := svc_candle9.choose("lift_shadowed_map", snap_candle9)
	_check(ref_candle9.get("ok") == false, "AC4: lift choose refused at candle 9")
	_check(svc_candle9.is_valid(), "AC4: service stays valid after lift refusal")

	# Witness 3: lift_shadowed_map at candle 80
	var snap_candle80 := _make_snapshot(80, 16, 0, 0, [0, 0, 0, 0])
	var svc_candle80 := RunStitchedEventConsequence.new(record)
	var prev_candle80 := svc_candle80.preview(snap_candle80)
	var lift_candle80 := _entry(prev_candle80, "lift_shadowed_map")
	_check(lift_candle80.get("available") == true, "AC4: lift available at candle 80")
	_check(int(lift_candle80.get("candle_delta")) == -10, "AC4: lift preview candle_delta is -10")
	_check(int(lift_candle80.get("candle")) == 70, "AC4: lift projects candle 70 (80 - 10)")
	_check(int(lift_candle80.get("gold_delta")) == 23, "AC4: lift preview gold_delta is 23")
	_check(int(lift_candle80.get("gold")) == 39, "AC4: lift projects gold 39 (16 + 23)")
	var expected_lift_fray := {"warden": 7, "seamstress": 7, "tinker": 7, "lantern_monk": 7}
	_check(lift_candle80.get("fray") == expected_lift_fray, "AC4: lift projects +7 fray each")
	var claim_lift := svc_candle80.choose("lift_shadowed_map", snap_candle80)
	_check(claim_lift.get("ok") == true, "AC4: lift claim succeeds")
	_check(int(claim_lift.get("candle")) == 70, "AC4: lift receipt candle is 70")
	_check(int(claim_lift.get("gold")) == 39, "AC4: lift receipt gold is 39")
	_check(int(claim_lift.get("gold_delta")) == 23, "AC4: lift receipt gold_delta is 23")
	_check(claim_lift.get("fray") == expected_lift_fray, "AC4: lift receipt fray is +7 each")

	# Witness 4: Neutral leave
	var snap_leave := _make_snapshot(80, 16, 0, 0, [10, 0, 0, 0])
	var svc_leave := RunStitchedEventConsequence.new(record)
	var prev_leave := svc_leave.preview(snap_leave)
	var leave_entry := _entry(prev_leave, "leave")
	_check(leave_entry.get("available") == true, "AC4: leave available")
	_check(int(leave_entry.get("candle")) == 80, "AC4: leave preserves candle 80")
	_check(leave_entry.get("fray") == {}, "AC4: leave has empty fray intent map")
	var claim_leave := svc_leave.choose("leave", snap_leave)
	_check(claim_leave.get("ok") == true, "AC4: leave succeeds")
	_check(int(claim_leave.get("candle")) == 80, "AC4: leave receipt candle is 80")
	_check(claim_leave.get("fray") == {}, "AC4: leave receipt fray is empty")
	_check(not claim_leave.has("gold"), "AC4: leave receipt does not touch gold")
	_check(not claim_leave.has("scraps"), "AC4: leave receipt does not touch scraps")


## Verifies same-seed replay produces identical receipts and no RNG is consumed.
func _test_replay_and_rng_invariants(record: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261108
	var initial_state := rng.state

	var snap_a := _make_snapshot(80, 16, 0, 0, [50, 0, 0, 0])
	var snap_b := _make_snapshot(80, 16, 0, 0, [50, 0, 0, 0])

	var svc_a := RunStitchedEventConsequence.new(record)
	var prev_a := svc_a.preview(snap_a)
	var rec_a := svc_a.choose("buy_quiet_house_plan", snap_a)

	var svc_b := RunStitchedEventConsequence.new(record)
	var prev_b := svc_b.preview(snap_b)
	var rec_b := svc_b.choose("buy_quiet_house_plan", snap_b)

	_check(prev_a == prev_b, "Invariants: same-seed replay previews are identical")
	_check(rec_a == rec_b, "Invariants: same-seed replay receipts are identical")
	_check(rng.state == initial_state, "Invariants: caller RNG state is untouched")
