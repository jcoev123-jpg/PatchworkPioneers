extends SceneTree
## Deterministic regression suite for RunStitchedBriarCampfireEvent.
## Covers AC1 (quote actionability, remedies, 0/1/2 scraps, lost-only wounds),
## AC2 (paid claim, exact -2 scraps, Campfire service_request, isolation of heroes/candle/inputs/RNG),
## AC3 (fail-closed rejections, stale/forged state, take_rivets +14 gold, leave, single-claim latch),
## and AC4 (catalog integrity, preservation of existing records).

const BRIAR_ID := "v3_briar_button_mending_bench"
const NODE := "test_briar_node_1"

var failures: Array[String] = []
var checks: int = 0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 7052026
	var rng_state_before := rng.state

	_test_ac1_catalog_authentication_and_pricing()
	_test_ac1_quote_actionability_remedies_and_scraps()
	_test_ac2_paid_claim_isolation_and_wallet_settlement()
	_test_ac3_trade_and_leave_claims()
	_test_ac3_rejections_and_fail_closed()
	_test_ac3_admission_validation_failures()
	_test_ac1_ac2_wren_fear_actionability_and_settlement()
	_test_ac3_wren_fear_validation_and_forgery()

	_check(rng.state == rng_state_before, "Overall: Seeded RNG state must remain completely untouched")
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr("FAIL: ", failure)
	print("run_stitched_briar_campfire_event_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _hero(id: String, rank: int, hp: int, max_hp: int, fray: int = 0, lost: bool = false) -> Dictionary:
	var h := {
		"id": id,
		"rank": rank,
		"hp": hp,
		"max_hp": max_hp,
		"fray": fray,
	}
	if lost:
		h["lost"] = true
	return h


func _standard_party(hp_offset: int = 0, fray_offset: int = 0, lost_first: bool = false) -> Array:
	return [
		_hero("warden", 1, 30 + hp_offset, 30, 0 + fray_offset, lost_first),
		_hero("seamstress", 2, 25, 25, 0),
		_hero("tinker", 3, 24, 24, 0),
		_hero("lantern_monk", 4, 28, 28, 0),
	]


func _find_choice(choices: Array, choice_id: String) -> Dictionary:
	for ch_raw: Variant in choices:
		if ch_raw is Dictionary and String((ch_raw as Dictionary).get("choice_id", "")) == choice_id:
			return (ch_raw as Dictionary).duplicate(true)
	return {}


# AC1: Catalog authentication, pricing and authored alternatives.
func _test_ac1_catalog_authentication_and_pricing() -> void:
	var gate := RunV3ServiceWaystationEventGate.new()
	_check(gate.is_catalog_valid(), "AC1: Shipped waystation catalog loads and validates")

	var record := gate.get_event_record(BRIAR_ID)
	_check(not record.is_empty(), "AC1: Authentic Briar-Button record exists in catalog")
	_check(record.get("id") == BRIAR_ID, "AC1: Record id is " + BRIAR_ID)
	_check(record.get("service_choice_id") == "fuel_button_fire", "AC1: service_choice_id is fuel_button_fire")
	_check(record.get("service_kind") == "Campfire", "AC1: service_kind is Campfire")

	var choices: Array = record.get("choices", [])
	_check(choices.size() == 3, "AC1: Authored Briar-Button has exactly 3 choices")

	var paid_ch: Dictionary = choices[0]
	_check(paid_ch.get("id") == "fuel_button_fire", "AC1: First choice is fuel_button_fire")
	_check(paid_ch.get("outcome") == {"gold": 0, "scraps": -2}, "AC1: fuel_button_fire costs {gold: 0, scraps: -2}")

	var trade_ch: Dictionary = choices[1]
	_check(trade_ch.get("id") == "take_rivets", "AC1: Second choice is take_rivets")
	_check(trade_ch.get("outcome") == {"gold": 14, "scraps": 0}, "AC1: take_rivets gives {gold: 14, scraps: 0}")

	var leave_ch: Dictionary = choices[2]
	_check(leave_ch.get("id") == "leave", "AC1: Third choice is leave")
	_check(leave_ch.get("outcome") == {"gold": 0, "scraps": 0}, "AC1: leave is zero cost {gold: 0, scraps: 0}")


# AC1: Quote actionability across scraps (0/1/2), HP (full/missing/hanging), FRAY (0/positive),
# candle (100/99), and lost-only wounds.
func _test_ac1_quote_actionability_remedies_and_scraps() -> void:
	# 1. Scraps threshold: 0 scraps vs 1 scrap vs 2 scraps on a wounded party
	var wounded_party := _standard_party(-10, 0) # Warden 20/30 HP
	for scraps in [0, 1]:
		var ev := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, wounded_party, 100, {"gold": 0, "scraps": scraps})
		_check(ev.is_valid(), "AC1: Event is valid with %d scraps" % scraps)
		var preview := ev.preview_choices()
		_check(bool(preview.get("ok", false)), "AC1: Preview succeeds with %d scraps" % scraps)
		var paid := _find_choice(preview.get("choices", []), "fuel_button_fire")
		_check(not bool(paid.get("affordable", false)), "AC1: fuel_button_fire is not affordable at %d scraps" % scraps)
		_check(not bool(paid.get("available", false)), "AC1: fuel_button_fire is not available at %d scraps" % scraps)
		_check(not bool(paid.get("actionable", false)), "AC1: fuel_button_fire is not actionable when unaffordable at %d scraps" % scraps)
		_check(paid.get("service_request", {}) == {}, "AC1: No service request offered when unaffordable at %d scraps" % scraps)
		var trade := _find_choice(preview.get("choices", []), "take_rivets")
		_check(bool(trade.get("available", false)), "AC1: take_rivets remains available when scraps=%d" % scraps)
		var leave := _find_choice(preview.get("choices", []), "leave")
		_check(bool(leave.get("available", false)), "AC1: leave remains available when scraps=%d" % scraps)

	# 2. Fully restored party at candle 100 with 2 scraps: all 3 remedies useless -> paid unavailable!
	var full_party := _standard_party(0, 0)
	var ev_full := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, full_party, 100, {"gold": 0, "scraps": 2})
	_check(ev_full.is_valid(), "AC1: Event valid for full party")
	_check(not ev_full.can_mend(), "AC1: Mend cannot help full party")
	_check(not ev_full.can_tell_tales(), "AC1: Tell Tales cannot help full party")
	_check(not ev_full.can_trim_wick(), "AC1: Trim Wick cannot help at candle 100")
	_check(not ev_full.has_useful_remedy(), "AC1: No useful remedy for fully restored party at candle 100")
	var preview_full := ev_full.preview_choices()
	var paid_full := _find_choice(preview_full.get("choices", []), "fuel_button_fire")
	_check(bool(paid_full.get("affordable", false)), "AC1: Paid choice is affordable with 2 scraps")
	_check(not bool(paid_full.get("available", false)), "AC1: Paid choice is unavailable when no remedy helps")
	_check(not bool(paid_full.get("actionable", false)), "AC1: Paid choice is not actionable when no remedy helps")
	_check(paid_full.get("service_request", {}) == {}, "AC1: No service request when no remedy helps")
	_check(bool(_find_choice(preview_full.get("choices", []), "take_rivets").get("available", false)), "AC1: Trade available on fully rested party")
	_check(bool(_find_choice(preview_full.get("choices", []), "leave").get("available", false)), "AC1: Leave available on fully rested party")

	# 3. Missing HP remedy: Warden 20/30 HP, candle 100, fray 0 -> paid available!
	var ev_hp := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, wounded_party, 100, {"gold": 0, "scraps": 2})
	_check(ev_hp.can_mend(), "AC1: Mend helps wounded party")
	_check(ev_hp.has_useful_remedy(), "AC1: Has useful remedy (Mend)")
	var preview_hp := ev_hp.preview_choices()
	var paid_hp := _find_choice(preview_hp.get("choices", []), "fuel_button_fire")
	_check(bool(paid_hp.get("available", false)), "AC1: Paid choice is available when hero has missing HP")
	_check(bool(paid_hp.get("actionable", false)), "AC1: Paid choice is actionable when hero has missing HP")
	_check(paid_hp.get("service_request", {}).get("stop_type") == "Campfire", "AC1: Offers Campfire service request when Mend helps")

	# 4. Hanging hero (0 HP): 0 HP is Hanging and may be healed -> paid available!
	var hanging_party := [
		_hero("warden", 1, 0, 30, 0), # Hanging at 0 HP
		_hero("seamstress", 2, 25, 25, 0),
		_hero("tinker", 3, 24, 24, 0),
		_hero("lantern_monk", 4, 28, 28, 0),
	]
	var ev_hanging := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, hanging_party, 100, {"gold": 0, "scraps": 2})
	_check(ev_hanging.can_mend(), "AC1: Mend helps Hanging (0 HP) hero")
	var paid_hanging := _find_choice(ev_hanging.preview_choices().get("choices", []), "fuel_button_fire")
	_check(bool(paid_hanging.get("available", false)), "AC1: Paid choice is available for Hanging hero")

	# 5. Positive FRAY remedy: All full HP, Seamstress has 20 FRAY, candle 100 -> paid available!
	var frayed_party := [
		_hero("warden", 1, 30, 30, 0),
		_hero("seamstress", 2, 25, 25, 20), # Positive FRAY
		_hero("tinker", 3, 24, 24, 0),
		_hero("lantern_monk", 4, 28, 28, 0),
	]
	var ev_fray := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, frayed_party, 100, {"gold": 0, "scraps": 2})
	_check(not ev_fray.can_mend(), "AC1: Mend does not help frayed party")
	_check(ev_fray.can_tell_tales(), "AC1: Tell Tales helps frayed party")
	_check(ev_fray.has_useful_remedy(), "AC1: Has useful remedy (Tell Tales)")
	var paid_fray := _find_choice(ev_fray.preview_choices().get("choices", []), "fuel_button_fire")
	_check(bool(paid_fray.get("available", false)), "AC1: Paid choice available when hero has positive FRAY")
	_check(paid_fray.get("service_request", {}).get("stop_type") == "Campfire", "AC1: Offers Campfire request when Tell Tales helps")

	# 6. Trim Wick remedy: Full HP, 0 FRAY, candle 99 (< 100) -> paid available!
	var ev_candle99 := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, full_party, 99, {"gold": 0, "scraps": 2})
	_check(not ev_candle99.can_mend(), "AC1: Mend does not help candle 99 full party")
	_check(not ev_candle99.can_tell_tales(), "AC1: Tell Tales does not help candle 99 full party")
	_check(ev_candle99.can_trim_wick(), "AC1: Trim Wick helps at candle 99")
	_check(ev_candle99.has_useful_remedy(), "AC1: Has useful remedy (Trim Wick)")
	var paid_c99 := _find_choice(ev_candle99.preview_choices().get("choices", []), "fuel_button_fire")
	_check(bool(paid_c99.get("available", false)), "AC1: Paid choice available when candle < 100")
	_check(paid_c99.get("service_request", {}).get("stop_type") == "Campfire", "AC1: Offers Campfire request when Trim Wick helps")

	# 7. Lost-only wounds: Warden is lost with 10/30 HP and 50 FRAY. Others are non-lost with full HP and 0 FRAY.
	# At candle 100: all remedies useless for non-lost heroes -> paid unavailable!
	var lost_only_party := [
		_hero("warden", 1, 10, 30, 50, true), # Lost hero with wounds and fray
		_hero("seamstress", 2, 25, 25, 0, false),
		_hero("tinker", 3, 24, 24, 0, false),
		_hero("lantern_monk", 4, 28, 28, 0, false),
	]
	var ev_lost100 := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, lost_only_party, 100, {"gold": 0, "scraps": 2})
	_check(not ev_lost100.can_mend(), "AC1: Mend ignores lost hero wounds")
	_check(not ev_lost100.can_tell_tales(), "AC1: Tell Tales ignores lost hero fray")
	_check(not ev_lost100.can_trim_wick(), "AC1: Trim Wick useless at candle 100")
	_check(not ev_lost100.has_useful_remedy(), "AC1: No useful remedy with lost-only wounds at candle 100")
	var paid_lost100 := _find_choice(ev_lost100.preview_choices().get("choices", []), "fuel_button_fire")
	_check(not bool(paid_lost100.get("available", false)), "AC1: Paid choice unavailable for lost-only wounds at candle 100")

	# Lost-only wounds at candle 99: Trim Wick would help candle -> paid available!
	var ev_lost99 := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, lost_only_party, 99, {"gold": 0, "scraps": 2})
	_check(ev_lost99.can_trim_wick(), "AC1: Trim Wick helps at candle 99 even with lost-only wounds")
	var paid_lost99 := _find_choice(ev_lost99.preview_choices().get("choices", []), "fuel_button_fire")
	_check(bool(paid_lost99.get("available", false)), "AC1: Paid choice available when candle 99 despite lost-only wounds")


# AC2: With actionable open quote + matching node/state, one paid fuel_button_fire claim
# charges exactly 2 scraps once, returns only Campfire service_request, preserving wallet gold,
# hero HP/FRAY, candle, inputs and RNG until downstream service action.
func _test_ac2_paid_claim_isolation_and_wallet_settlement() -> void:
	var initial_party := [
		_hero("warden", 1, 15, 30, 10),
		_hero("seamstress", 2, 25, 25, 0),
		_hero("tinker", 3, 24, 24, 0),
		_hero("lantern_monk", 4, 28, 28, 0),
	]
	var caller_party := initial_party.duplicate(true)
	var caller_wallet := {"gold": 42, "scraps": 5}
	var caller_candle := 75

	var rng_before := rng.state

	var ev := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, caller_party, caller_candle, caller_wallet)
	_check(ev.is_valid(), "AC2: Event is valid")
	_check(ev.is_open(), "AC2: Event is open initially")
	_check(not ev.is_claimed(), "AC2: Event is unclaimed initially")
	_check(ev.get_version() == 0, "AC2: Version starts at 0")

	# Snapshot state before claim
	var open_state := ev.read_state()
	_check(bool(open_state.get("ok", false)), "AC2: Read state is ok")
	_check(open_state.get("version") == 0, "AC2: Read state version is 0")
	_check(open_state.get("candle") == 75, "AC2: Read state candle is 75")
	_check(open_state.get("wallet") == {"gold": 42, "scraps": 5}, "AC2: Read state wallet matches")

	# Claim paid choice
	var receipt := ev.choose("fuel_button_fire", NODE, open_state)
	_check(bool(receipt.get("ok", false)), "AC2: Paid claim succeeds")
	_check(receipt.get("choice_id") == "fuel_button_fire", "AC2: Receipt choice_id is fuel_button_fire")
	_check(receipt.get("event_id") == BRIAR_ID, "AC2: Receipt event_id is Briar-Button")
	_check(receipt.get("wallet") == {"gold": 42, "scraps": 3}, "AC2: Wallet charged exactly 2 scraps (gold 42, scraps 3)")
	_check(receipt.get("service_request") == {"stop_type": "Campfire"}, "AC2: Receipt returns Campfire service_request")

	# Post-claim state invariants
	_check(not ev.is_open(), "AC2: Event is closed after claim")
	_check(ev.is_claimed(), "AC2: Event is claimed after claim")
	_check(not ev.is_valid(), "AC2: Claimed event is no longer valid for new claims")
	_check(ev.get_version() == 1, "AC2: Version incremented to 1")

	var after_state: Dictionary = receipt.get("state", {})
	_check(after_state.get("claimed") == true, "AC2: After-state is claimed")
	_check(after_state.get("open") == false, "AC2: After-state is closed")
	_check(after_state.get("version") == 1, "AC2: After-state version is 1")
	_check(after_state.get("wallet") == {"gold": 42, "scraps": 3}, "AC2: After-state wallet updated")
	_check(after_state.get("candle") == caller_candle, "AC2: Candle untouched by adapter (remains 75)")
	_check(after_state.get("heroes") == initial_party, "AC2: Heroes HP and FRAY untouched by adapter")

	# Verify caller's input variables were not mutated
	_check(caller_party == initial_party, "AC2: Caller party array untouched by admission or claim")
	_check(caller_wallet == {"gold": 42, "scraps": 5}, "AC2: Caller wallet dictionary untouched")

	# Verify RNG was completely untouched
	_check(rng.state == rng_before, "AC2: RNG state completely untouched across claim")

	# Modifying receipt or state cannot leak into held event
	after_state["wallet"]["gold"] = 999
	after_state["heroes"][0]["hp"] = 999
	_check(ev.get_wallet() == {"gold": 42, "scraps": 3}, "AC2: Mutating receipt state does not affect held wallet")
	_check(ev.get_heroes() == initial_party, "AC2: Mutating receipt state does not affect held heroes")


# AC3: Alternate trade (take_rivets) gives 14 gold with no request; Leave gives zero with no request.
# Both close their visit once and latch.
func _test_ac3_trade_and_leave_claims() -> void:
	var party := _standard_party(0, 0) # Full party

	# 1. take_rivets (+14 gold, 0 scraps)
	var ev_trade := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, party, 100, {"gold": 10, "scraps": 1})
	var trade_open := ev_trade.read_state()
	var trade_receipt := ev_trade.choose("take_rivets", NODE, trade_open)
	_check(bool(trade_receipt.get("ok", false)), "AC3: take_rivets succeeds")
	_check(trade_receipt.get("choice_id") == "take_rivets", "AC3: Receipt choice_id is take_rivets")
	_check(trade_receipt.get("wallet") == {"gold": 24, "scraps": 1}, "AC3: take_rivets gives exactly +14 gold (gold: 24, scraps: 1)")
	_check(trade_receipt.get("service_request") == {}, "AC3: take_rivets produces empty service_request")
	_check(ev_trade.is_claimed(), "AC3: Event latches claimed after take_rivets")

	# Replay / second claim fails
	var second_trade := ev_trade.choose("take_rivets", NODE, trade_receipt.get("state", {}))
	_check(not bool(second_trade.get("ok", false)), "AC3: Replay of take_rivets refused")
	_check(ev_trade.get_wallet() == {"gold": 24, "scraps": 1}, "AC3: Second claim attempt does not change wallet")

	# 2. leave (0 gold, 0 scraps)
	var ev_leave := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, party, 100, {"gold": 15, "scraps": 4})
	var leave_open := ev_leave.read_state()
	var leave_receipt := ev_leave.leave(NODE, leave_open)
	_check(bool(leave_receipt.get("ok", false)), "AC3: leave succeeds")
	_check(leave_receipt.get("choice_id") == "leave", "AC3: Receipt choice_id is leave")
	_check(leave_receipt.get("wallet") == {"gold": 15, "scraps": 4}, "AC3: leave preserves wallet exactly")
	_check(leave_receipt.get("service_request") == {}, "AC3: leave produces empty service_request")
	_check(ev_leave.is_claimed(), "AC3: Event latches claimed after leave")

	# Replay of leave fails
	var second_leave := ev_leave.leave(NODE, leave_receipt.get("state", {}))
	_check(not bool(second_leave.get("ok", false)), "AC3: Replay of leave refused")


# AC3: Wrong/stale/forged node/state, no affordability/remedy, failure preservation.
func _test_ac3_rejections_and_fail_closed() -> void:
	var wounded_party := _standard_party(-5, 0)
	var ev := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, wounded_party, 100, {"gold": 10, "scraps": 2})
	var state := ev.read_state()

	# 1. Wrong node ID
	var res_wrong_node := ev.choose("fuel_button_fire", "wrong_node_id", state)
	_check(not bool(res_wrong_node.get("ok", false)), "AC3: Claim with wrong node ID fails")
	_check(res_wrong_node.get("error") == "wrong node", "AC3: Error message is 'wrong node'")
	_check(ev.is_open() and not ev.is_claimed(), "AC3: Failure on wrong node does not consume visit")
	_check(ev.get_wallet() == {"gold": 10, "scraps": 2}, "AC3: Wallet unspent after failure")

	# 2. Null node ID
	var res_null_node := ev.choose("fuel_button_fire", null, state)
	_check(not bool(res_null_node.get("ok", false)), "AC3: Claim with null node ID fails")

	# 3. Forged state (e.g. modified wallet in expected state)
	var forged_state := state.duplicate(true)
	forged_state["wallet"]["scraps"] = 999
	var res_forged := ev.choose("fuel_button_fire", NODE, forged_state)
	_check(not bool(res_forged.get("ok", false)), "AC3: Claim with forged state fails")
	_check(res_forged.get("error") == "stale or forged state", "AC3: Error message is 'stale or forged state'")
	_check(ev.is_open(), "AC3: Visit remains open after forged state rejection")

	# 4. Unknown choice ID
	var res_unknown_choice := ev.choose("steal_fire", NODE, state)
	_check(not bool(res_unknown_choice.get("ok", false)), "AC3: Unknown choice ID fails")

	# 5. Claiming paid choice when remedies are useless (full HP, 0 fray, candle 100)
	var full_party := _standard_party(0, 0)
	var ev_useless := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, full_party, 100, {"gold": 10, "scraps": 2})
	var useless_state := ev_useless.read_state()
	var res_useless := ev_useless.choose("fuel_button_fire", NODE, useless_state)
	_check(not bool(res_useless.get("ok", false)), "AC3: Claiming paid choice with useless remedies fails")
	_check(ev_useless.is_open(), "AC3: Visit remains open after useless remedy refusal")
	_check(ev_useless.get_wallet() == {"gold": 10, "scraps": 2}, "AC3: Scraps unspent after refusal")

	# Alternative options remain actionable after the refusal!
	var trade_after_refusal := ev_useless.choose("take_rivets", NODE, useless_state)
	_check(bool(trade_after_refusal.get("ok", false)), "AC3: Alternative trade choice succeeds after paid choice was blocked")
	_check(trade_after_refusal.get("wallet") == {"gold": 24, "scraps": 2}, "AC3: Wallet properly updated on alternative choice")

	# 6. Claiming paid choice when scraps < 2
	var ev_broke := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, wounded_party, 100, {"gold": 10, "scraps": 1})
	var broke_state := ev_broke.read_state()
	var res_broke := ev_broke.choose("fuel_button_fire", NODE, broke_state)
	_check(not bool(res_broke.get("ok", false)), "AC3: Claiming paid choice with 1 scrap fails")
	_check(ev_broke.is_open(), "AC3: Visit remains open when broke")
	var leave_after_broke := ev_broke.leave(NODE, broke_state)
	_check(bool(leave_after_broke.get("ok", false)), "AC3: Leave succeeds when paid choice is unaffordable")


# AC3: Malformed admission rejects without substituting default or inferred roster values.
func _test_ac3_admission_validation_failures() -> void:
	var valid_heroes := _standard_party(-5, 0)
	var valid_wallet := {"gold": 10, "scraps": 2}
	var valid_candle := 80

	# 1. Invalid Node IDs
	for bad_node in ["", "  ", " node_id", "node_id ", null, 123]:
		var ev := RunStitchedBriarCampfireEvent.new(bad_node, BRIAR_ID, valid_heroes, valid_candle, valid_wallet)
		_check(not ev.is_valid(), "AC3: Rejected invalid node: " + str(bad_node))
		_check(not ev.is_open(), "AC3: Closed for invalid node: " + str(bad_node))

	# 2. Invalid Event Targets (not authentic Briar-Button)
	for bad_target in ["v3_emberglass_campfire", "v3_threadmill_sewing_circle", "unknown", null, 42]:
		var ev := RunStitchedBriarCampfireEvent.new(NODE, bad_target, valid_heroes, valid_candle, valid_wallet)
		_check(not ev.is_valid(), "AC3: Rejected invalid event target: " + str(bad_target))

	# 3. Party size != 4
	var three_heroes: Array = valid_heroes.slice(0, 3)
	var ev_three := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, three_heroes, valid_candle, valid_wallet)
	_check(not ev_three.is_valid(), "AC3: Party of 3 heroes rejected")

	var five_heroes: Array = valid_heroes.duplicate(true)
	five_heroes.append(_hero("rag_duelist", 4, 20, 20, 0))
	var ev_five := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, five_heroes, valid_candle, valid_wallet)
	_check(not ev_five.is_valid(), "AC3: Party of 5 heroes rejected")

	# 4. Non-canonical hero ID
	var non_canonical: Array = valid_heroes.duplicate(true)
	non_canonical[0]["id"] = "dragon_knight"
	var ev_non_canon := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, non_canonical, valid_candle, valid_wallet)
	_check(not ev_non_canon.is_valid(), "AC3: Non-canonical hero ID rejected")

	# 5. Duplicate hero ID
	var duplicate_id: Array = valid_heroes.duplicate(true)
	duplicate_id[1]["id"] = duplicate_id[0]["id"]
	var ev_dupe_id := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, duplicate_id, valid_candle, valid_wallet)
	_check(not ev_dupe_id.is_valid(), "AC3: Duplicate hero ID rejected")

	# 6. Missing rank (must not infer default rank)
	var missing_rank: Array = valid_heroes.duplicate(true)
	missing_rank[1].erase("rank")
	missing_rank[1].erase("position")
	var ev_no_rank := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, missing_rank, valid_candle, valid_wallet)
	_check(not ev_no_rank.is_valid(), "AC3: Hero missing rank rejected (no inferred values)")

	# 7. Duplicate rank
	var dupe_rank: Array = valid_heroes.duplicate(true)
	dupe_rank[1]["rank"] = 1 # Two heroes at rank 1
	var ev_dupe_rank := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, dupe_rank, valid_candle, valid_wallet)
	_check(not ev_dupe_rank.is_valid(), "AC3: Duplicate rank rejected")

	# 8. Rank out of range (0 or 5)
	var rank_zero: Array = valid_heroes.duplicate(true)
	rank_zero[0]["rank"] = 0
	var ev_rank0 := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, rank_zero, valid_candle, valid_wallet)
	_check(not ev_rank0.is_valid(), "AC3: Rank 0 rejected")

	var rank_five: Array = valid_heroes.duplicate(true)
	rank_five[3]["rank"] = 5
	var ev_rank5 := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, rank_five, valid_candle, valid_wallet)
	_check(not ev_rank5.is_valid(), "AC3: Rank 5 rejected")

	# 9. HP boundary violations: max_hp <= 0, hp < 0, hp > max_hp
	var zero_max_hp: Array = valid_heroes.duplicate(true)
	zero_max_hp[0]["max_hp"] = 0
	var ev_zero_mhp := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, zero_max_hp, valid_candle, valid_wallet)
	_check(not ev_zero_mhp.is_valid(), "AC3: max_hp == 0 rejected")

	var neg_hp: Array = valid_heroes.duplicate(true)
	neg_hp[0]["hp"] = -1
	var ev_neg_hp := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, neg_hp, valid_candle, valid_wallet)
	_check(not ev_neg_hp.is_valid(), "AC3: negative hp rejected")

	var over_hp: Array = valid_heroes.duplicate(true)
	over_hp[0]["hp"] = 35
	over_hp[0]["max_hp"] = 30
	var ev_over_hp := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, over_hp, valid_candle, valid_wallet)
	_check(not ev_over_hp.is_valid(), "AC3: hp > max_hp rejected")

	# 10. FRAY boundary violations: fray < 0, fray > 200
	var neg_fray: Array = valid_heroes.duplicate(true)
	neg_fray[0]["fray"] = -1
	var ev_neg_fray := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, neg_fray, valid_candle, valid_wallet)
	_check(not ev_neg_fray.is_valid(), "AC3: negative fray rejected")

	var over_fray: Array = valid_heroes.duplicate(true)
	over_fray[0]["fray"] = 201
	var ev_over_fray := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, over_fray, valid_candle, valid_wallet)
	_check(not ev_over_fray.is_valid(), "AC3: fray > 200 rejected")

	# 11. Malformed lost field (non-boolean)
	var bad_lost: Array = valid_heroes.duplicate(true)
	bad_lost[0]["lost"] = "yes"
	var ev_bad_lost := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, bad_lost, valid_candle, valid_wallet)
	_check(not ev_bad_lost.is_valid(), "AC3: non-boolean lost rejected")

	# 12. Candle boundaries: candle < 0, candle > 100, candle null, candle string
	for bad_candle in [-1, 101, null, "100", 50.5]:
		var ev_bad_c := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, valid_heroes, bad_candle, valid_wallet)
		_check(not ev_bad_c.is_valid(), "AC3: Rejected invalid candle: " + str(bad_candle))

	# 13. Malformed wallet: negative gold, negative scraps, missing keys, extra keys, non-dict
	for bad_w in [{"gold": -1, "scraps": 0}, {"gold": 0, "scraps": -1}, {"gold": 0}, {"gold": 0, "scraps": 0, "gems": 5}, null, 12]:
		var ev_bad_w := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, valid_heroes, valid_candle, bad_w)
		_check(not ev_bad_w.is_valid(), "AC3: Rejected invalid wallet: " + str(bad_w))


# AC1 & AC2: Wren Fear positive actionability, exact single settlement (-2 scraps) and isolation.
func _test_ac1_ac2_wren_fear_actionability_and_settlement() -> void:
	var full_party := _standard_party(0, 0) # 4 living heroes, full HP, fray 0

	# 1. Default fear 0 (and explicit fear 0) with full HP, fray 0, candle 100: paid choice unavailable
	var ev_fear0_default := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, full_party, 100, {"gold": 0, "scraps": 2})
	_check(ev_fear0_default.is_valid(), "AC1: Event valid with default fear 0")
	_check(ev_fear0_default.get_wren_fear() == 0, "AC1: Default wren_fear is 0")
	_check(not ev_fear0_default.can_tell_tales(), "AC1: Tell Tales cannot help with fear 0 and zero fray")
	_check(not ev_fear0_default.has_useful_remedy(), "AC1: No useful remedy at fear 0 full HP zero fray candle 100")
	_check(not ev_fear0_default.has_useful_recovery(), "AC1: has_useful_recovery alias matches has_useful_remedy")
	var preview_fear0 := ev_fear0_default.preview_choices()
	var paid_fear0 := _find_choice(preview_fear0.get("choices", []), "fuel_button_fire")
	_check(bool(paid_fear0.get("affordable", false)), "AC1: Paid choice affordable at 2 scraps")
	_check(not bool(paid_fear0.get("available", false)), "AC1: Paid choice unavailable with fear 0")
	_check(not bool(paid_fear0.get("actionable", false)), "AC1: Paid choice not actionable with fear 0")
	_check(paid_fear0.get("service_request", {}) == {}, "AC1: No service request offered with fear 0")

	var ev_fear0_explicit := RunStitchedBriarCampfireEvent.new(NODE, BRIAR_ID, full_party, 100, {"gold": 0, "scraps": 2}, null, 0)
	_check(ev_fear0_explicit.get_wren_fear() == 0, "AC1: Explicit fear 0 accepted")
	_check(not ev_fear0_explicit.has_useful_remedy(), "AC1: Explicit fear 0 has no useful remedy")

	# 2. Positive Wren fear boundaries (fear 1, 15, 60) activate Tell Tales recovery
	for test_fear: int in [1, 15, 60]:
		var ev_pos_fear := RunStitchedBriarCampfireEvent.new(
			NODE, BRIAR_ID, full_party, 100, {"gold": 0, "scraps": 2}, null, test_fear
		)
		_check(ev_pos_fear.is_valid(), "AC1: Event valid with fear %d" % test_fear)
		_check(ev_pos_fear.get_wren_fear() == test_fear, "AC1: get_wren_fear() returns %d" % test_fear)
		_check(ev_pos_fear.read_state().get("wren_fear") == test_fear, "AC1: read_state() shows wren_fear %d" % test_fear)
		_check(ev_pos_fear.can_tell_tales(), "AC1: can_tell_tales() true for fear %d" % test_fear)
		_check(ev_pos_fear.has_useful_remedy(), "AC1: has_useful_remedy() true for fear %d" % test_fear)
		_check(ev_pos_fear.has_useful_recovery(), "AC1: has_useful_recovery() true for fear %d" % test_fear)
		var preview_pos := ev_pos_fear.preview_choices()
		var paid_pos := _find_choice(preview_pos.get("choices", []), "fuel_button_fire")
		_check(bool(paid_pos.get("affordable", false)), "AC1: Paid choice affordable with fear %d" % test_fear)
		_check(bool(paid_pos.get("available", false)), "AC1: Paid choice available with fear %d" % test_fear)
		_check(bool(paid_pos.get("actionable", false)), "AC1: Paid choice actionable with fear %d" % test_fear)
		_check(paid_pos.get("service_request", {}).get("stop_type") == "Campfire",
			"AC1: Offers Campfire service request with fear %d" % test_fear)

	# 3. Underfunded fear-positive refusal: fear 60 with 0 or 1 scrap -> unavailable / unaffordable
	for bad_scraps: int in [0, 1]:
		var ev_underfunded := RunStitchedBriarCampfireEvent.new(
			NODE, BRIAR_ID, full_party, 100, {"gold": 10, "scraps": bad_scraps}, null, 60
		)
		_check(ev_underfunded.is_valid(), "AC1: Underfunded fear 60 event is valid at %d scraps" % bad_scraps)
		_check(ev_underfunded.has_useful_remedy(), "AC1: Useful remedy exists from fear 60")
		var preview_under := ev_underfunded.preview_choices()
		var paid_under := _find_choice(preview_under.get("choices", []), "fuel_button_fire")
		_check(not bool(paid_under.get("affordable", false)), "AC1: Paid choice unaffordable with %d scraps despite fear 60" % bad_scraps)
		_check(not bool(paid_under.get("available", false)), "AC1: Paid choice unavailable when unaffordable despite fear 60")
		_check(not bool(paid_under.get("actionable", false)), "AC1: Paid choice not actionable when unaffordable")
		_check(paid_under.get("service_request", {}) == {}, "AC1: No service request offered when underfunded")

		# Attempting to claim underfunded paid choice fails closed
		var res_under_claim := ev_underfunded.choose("fuel_button_fire", NODE, ev_underfunded.read_state())
		_check(not bool(res_under_claim.get("ok", false)), "AC1: Claim underfunded paid choice fails at %d scraps" % bad_scraps)
		_check(ev_underfunded.is_open(), "AC1: Event remains open after underfunded paid choice refusal")
		_check(ev_underfunded.get_wallet() == {"gold": 10, "scraps": bad_scraps}, "AC1: Wallet unchanged after underfunded refusal")

	# 4. Exact fear-only paid claim settlement, isolation and downstream StitchedKidFear Tell Tales witness
	var caller_party := full_party.duplicate(true)
	var caller_wallet := {"gold": 25, "scraps": 5}
	var caller_candle := 100
	var initial_fear := 60

	var ev_settle := RunStitchedBriarCampfireEvent.new(
		NODE, BRIAR_ID, caller_party, caller_candle, caller_wallet, null, initial_fear
	)
	var state_before := ev_settle.read_state()
	_check(state_before.get("wren_fear") == 60, "AC2: State before claim has wren_fear 60")
	_check(state_before.get("wallet") == {"gold": 25, "scraps": 5}, "AC2: State before claim matches wallet")

	var receipt := ev_settle.choose("fuel_button_fire", NODE, state_before)
	_check(bool(receipt.get("ok", false)), "AC2: Fear-only paid claim succeeds")
	_check(receipt.get("choice_id") == "fuel_button_fire", "AC2: Receipt choice_id is fuel_button_fire")
	_check(receipt.get("event_id") == BRIAR_ID, "AC2: Receipt event_id is Briar-Button")
	_check(receipt.get("wallet") == {"gold": 25, "scraps": 3}, "AC2: Exactly 2 scraps debited (gold: 25, scraps: 3)")
	_check(receipt.get("service_request") == {"stop_type": "Campfire"},
		"AC2: Receipt returns only Campfire service_request")

	# Event adapter invariants after claim: fear untouched, closed, claimed once
	_check(ev_settle.is_claimed(), "AC2: Event claimed after settlement")
	_check(not ev_settle.is_open(), "AC2: Event closed after settlement")
	_check(ev_settle.get_wren_fear() == initial_fear,
		"AC2: Event adapter wren_fear untouched by claim (remains %d)" % initial_fear)
	var state_after: Dictionary = receipt.get("state", {})
	_check(state_after.get("wren_fear") == initial_fear,
		"AC2: State after claim preserves wren_fear untouched (remains %d)" % initial_fear)
	_check(state_after.get("candle") == caller_candle, "AC2: Candle untouched by adapter (remains 100)")
	_check(state_after.get("heroes") == full_party, "AC2: Heroes untouched by adapter")
	_check(caller_party == full_party, "AC2: Caller party untouched")
	_check(caller_wallet == {"gold": 25, "scraps": 5}, "AC2: Caller wallet untouched")

	# Second claim fails (single-claim latch)
	var second_claim := ev_settle.choose("fuel_button_fire", NODE, state_after)
	_check(not bool(second_claim.get("ok", false)), "AC2: Replay of fear-only paid claim refused")

	# 5. Downstream separate StitchedKidFear object witnesses exact -15 Tell Tales effect
	# Fear 60 -> 45
	var kid_fear_60 := StitchedKidFear.new(60)
	_check(kid_fear_60.is_valid(), "AC2: StitchedKidFear instantiated at fear 60")
	var tell_tales_res_60 := kid_fear_60.apply_event({"kind": "tell_tales"})
	_check(bool(tell_tales_res_60.get("ok", false)), "AC2: StitchedKidFear accepts tell_tales event")
	_check(tell_tales_res_60.get("delta") == -15, "AC2: tell_tales delta is -15")
	_check(tell_tales_res_60.get("before_fear") == 60, "AC2: before_fear was 60")
	_check(tell_tales_res_60.get("after_fear") == 45, "AC2: after_fear is 45 (60 - 15)")
	_check(kid_fear_60.get_fear() == 45, "AC2: Kid fear meter is now 45")

	# Fear 10 -> 0 (lower bound zero)
	var kid_fear_10 := StitchedKidFear.new(10)
	var tell_tales_res_10 := kid_fear_10.apply_event({"kind": "tell_tales"})
	_check(bool(tell_tales_res_10.get("ok", false)), "AC2: StitchedKidFear accepts tell_tales event for fear 10")
	_check(tell_tales_res_10.get("before_fear") == 10, "AC2: before_fear was 10")
	_check(tell_tales_res_10.get("after_fear") == 0, "AC2: after_fear is 0 (10 - 15 clamped to 0)")
	_check(kid_fear_10.get_fear() == 0, "AC2: Kid fear meter clamped at 0")


# AC3: Forgery fail-closed and fear admission boundaries.
func _test_ac3_wren_fear_validation_and_forgery() -> void:
	var full_party := _standard_party(0, 0)
	var valid_wallet := {"gold": 10, "scraps": 2}

	# 1. Forged wren_fear in expected state check fails
	var ev_forgery := RunStitchedBriarCampfireEvent.new(
		NODE, BRIAR_ID, full_party, 100, valid_wallet, null, 15
	)
	var real_state := ev_forgery.read_state()
	_check(real_state.get("wren_fear") == 15, "AC3: Real state has wren_fear 15")

	var forged_fear_state := real_state.duplicate(true)
	forged_fear_state["wren_fear"] = 0 # forged fear
	var res_forged := ev_forgery.choose("fuel_button_fire", NODE, forged_fear_state)
	_check(not bool(res_forged.get("ok", false)), "AC3: Forged wren_fear in state rejected")
	_check(res_forged.get("error") == "stale or forged state",
		"AC3: Forged wren_fear yields 'stale or forged state'")
	_check(ev_forgery.is_open(), "AC3: Event remains open after forged state rejection")
	_check(ev_forgery.get_wallet() == valid_wallet, "AC3: Wallet untouched after forged state rejection")

	# 2. Malformed / invalid Wren fear values rejected at admission
	# Boundaries: -1, 101, fractional floats, strings, null, non-numerics
	for bad_fear: Variant in [-1, 101, 15.5, 0.5, -0.1, "15", "fear", null, true, false, {}]:
		var ev_bad := RunStitchedBriarCampfireEvent.new(
			NODE, BRIAR_ID, full_party, 100, valid_wallet, null, bad_fear
		)
		_check(not ev_bad.is_valid(), "AC3: Rejected invalid wren_fear: " + str(bad_fear))
		_check(not ev_bad.is_open(), "AC3: Closed for invalid wren_fear: " + str(bad_fear))
		_check(not ev_bad.get_error().is_empty(), "AC3: Nonempty error for invalid wren_fear: " + str(bad_fear))

	# Whole float accepted and converted to native int
	var ev_float_whole := RunStitchedBriarCampfireEvent.new(
		NODE, BRIAR_ID, full_party, 100, valid_wallet, null, 20.0
	)
	_check(ev_float_whole.is_valid(), "AC3: Whole float 20.0 accepted")
	_check(ev_float_whole.get_wren_fear() == 20, "AC3: Whole float stored as int 20")
	_check(typeof(ev_float_whole.read_state()["wren_fear"]) == TYPE_INT, "AC3: read_state has native integer")

	# Factory open() method accepts 7 arguments preserving argument 6 as catalog
	var ev_open_factory := RunStitchedBriarCampfireEvent.open(
		NODE, BRIAR_ID, full_party, 100, valid_wallet, null, 30
	)
	_check(ev_open_factory.is_valid(), "AC3: open() factory works with 7 arguments")
	_check(ev_open_factory.get_wren_fear() == 30, "AC3: open() factory passes wren_fear 30")

	# Factory open() with default fear 0
	var ev_open_default := RunStitchedBriarCampfireEvent.open(
		NODE, BRIAR_ID, full_party, 100, valid_wallet
	)
	_check(ev_open_default.is_valid(), "AC3: open() factory works with 5 arguments")
	_check(ev_open_default.get_wren_fear() == 0, "AC3: open() factory defaults fear to 0")
