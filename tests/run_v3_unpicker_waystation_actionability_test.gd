extends SceneTree
## Deterministic regression suite for RunV3ServiceWaystationEventGate.select_actionable_unpicker_event (V3-4).
## Exercises AC1 (authentic usable offer, starter/Frayed Debt/stitched composite decks, throwaway removal),
## AC2 (exact 84/85, 109/110, 134/135 boundaries, scraps independence, trade/leave separation, independent bound-gate and Unpicker receipts),
## AC3 (refusal on unfunded/empty/forged/stale/overflow/bad RNG/wallet/exclusions without state or RNG drift),
## and AC4 (deterministic replay, one RNG draw on success, catalog detachment, preserved Campfire/Sewing selectors and alt/leave choices).

var failures: Array[String] = []
var checks: int = 0


func _init() -> void:
	_test_ac1_authentic_usable_offer()
	_test_ac2_wallet_boundaries_and_separate_debits()
	_test_ac3_refusal_state_preservation_and_rng()
	_test_ac4_determinism_and_preserved_services()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("run_v3_unpicker_waystation_actionability_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _make_rng(seed_val: int = 12345) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng


# AC1: Authentic usable offer. Shipped catalog, eligible unexcluded Inkblack ID,
# sound starter/Frayed Debt/stitched composite decks, and throwaway removal verification.
func _test_ac1_authentic_usable_offer() -> void:
	var gate := RunV3ServiceWaystationEventGate.new()
	_check(gate.is_catalog_valid(), "AC1: Shipped waystation catalog is valid")

	var inkblack_id := "v3_inkblack_unpicker_van"
	var funded_wallet := {"gold": 85, "scraps": 0}

	# 1. Ordinary starter deck
	var starter_cards: Array[String] = StarterCards.new().get_starting_deck()
	var snap_starter := {
		"deck": starter_cards.duplicate(),
		"descriptors": {},
		"next_stitch_id": 1,
	}
	var rng1 := _make_rng(101)
	var res1 := gate.select_actionable_unpicker_event(rng1, null, funded_wallet, snap_starter, 0)
	_check(res1.get("ok") == true, "AC1: Selection succeeds for starter deck")
	_check(res1.get("event", {}).get("id") == inkblack_id, "AC1: Selected ID is Inkblack Unpicker Van")
	_check(res1.get("event", {}).get("service_kind") == "Unpicker", "AC1: Service kind is Unpicker")
	_check(res1.get("event", {}).get("service_choice_id") == "hire_unpicker", "AC1: Service choice ID is hire_unpicker")

	# Prove throwaway removal succeeds on ordinary card
	var throwaway_ordinary := RunShopCardRemoval.try_remove_with_stitch_ledger(
		starter_cards.duplicate(), {}, 1, 75, 0, "warden_strike"
	)
	_check(throwaway_ordinary.get("ok") == true, "AC1: Ordinary card throwaway removal succeeds")
	_check(throwaway_ordinary.get("deck", []).count("warden_strike") == starter_cards.count("warden_strike") - 1,
		"AC1: Exactly one copy of warden_strike removed")
	_check(throwaway_ordinary.get("gold") == 0, "AC1: Exactly 75 gold charged for first removal")
	_check(throwaway_ordinary.get("prior_removals") == 1, "AC1: Prior removals incremented to 1")

	# 2. Deck with canonical Frayed Debt curse
	var curse_id: String = MpwFrayedDebt.CARD_ID
	var curse_deck := starter_cards.duplicate()
	curse_deck.append(curse_id)
	var snap_curse := {
		"deck": curse_deck.duplicate(),
		"descriptors": {},
		"next_stitch_id": 1,
	}
	var rng2 := _make_rng(102)
	var res2 := gate.select_actionable_unpicker_event(rng2, null, funded_wallet, snap_curse, 0)
	_check(res2.get("ok") == true, "AC1: Selection succeeds for deck containing Frayed Debt")
	_check(res2.get("event", {}).get("id") == inkblack_id, "AC1: Selected ID matches Inkblack")

	# Prove throwaway removal succeeds on Frayed Debt
	var throwaway_curse := RunShopCardRemoval.try_remove_with_stitch_ledger(
		curse_deck.duplicate(), {}, 1, 75, 0, curse_id
	)
	_check(throwaway_curse.get("ok") == true, "AC1: Frayed Debt throwaway removal succeeds")
	_check(throwaway_curse.get("deck", []).count(curse_id) == 0, "AC1: Frayed Debt removed from deck")
	_check(throwaway_curse.get("gold") == 0, "AC1: Removal charged exactly 75 gold")

	# 3. Authentic stitched composite deck
	var base_stitch_deck := ["warden_strike", "tinker_tune_up", "seamstress_prick"]
	var stitch_runner := RunRestStitchCards.new(base_stitch_deck, {}, 3, 1)
	_check(stitch_runner.is_valid(), "AC1: Rest stitch helper initialized")
	var stitch_res := stitch_runner.choose_stitch(0, 1, stitch_runner.get_snapshot())
	_check(stitch_res.get("ok") == true, "AC1: Cross-owner stitch succeeded")
	var stitched_id: String = stitch_res.get("stitched_id", "")
	var stitched_deck: Array = stitch_res.get("deck", [])
	var stitched_desc: Dictionary = stitch_res.get("descriptors", {})
	var cursor: int = stitch_res.get("next_stitch_id", 2)
	var snap_stitched := {
		"deck": stitched_deck.duplicate(),
		"descriptors": stitched_desc.duplicate(true),
		"next_stitch_id": cursor,
	}
	var rng3 := _make_rng(103)
	var res3 := gate.select_actionable_unpicker_event(rng3, null, funded_wallet, snap_stitched, 0)
	_check(res3.get("ok") == true, "AC1: Selection succeeds for authentic stitched deck")
	_check(res3.get("event", {}).get("id") == inkblack_id, "AC1: Selected ID matches Inkblack")

	# Prove throwaway removal succeeds on stitched composite and retires its descriptor
	var throwaway_stitched := RunShopCardRemoval.try_remove_with_stitch_ledger(
		stitched_deck.duplicate(), stitched_desc.duplicate(true), cursor, 75, 0, stitched_id
	)
	_check(throwaway_stitched.get("ok") == true, "AC1: Stitched composite throwaway removal succeeds")
	_check(not throwaway_stitched.get("descriptors", {}).has(stitched_id),
		"AC1: Stitched descriptor retired upon composite removal")
	_check(throwaway_stitched.get("deck", []).count(stitched_id) == 0, "AC1: Composite removed from deck")
	_check(throwaway_stitched.get("next_stitch_id") == cursor, "AC1: Allocator cursor preserved")

	# 4. Loose parameters call support
	var rng4 := _make_rng(104)
	var res_loose := gate.select_actionable_unpicker_event(rng4, null, funded_wallet, starter_cards, 0, {}, 1)
	_check(res_loose.get("ok") == true, "AC1: Loose parameters invocation succeeds")
	_check(res_loose.get("event", {}).get("id") == inkblack_id, "AC1: Loose parameters returns Inkblack")


# AC2: Both costs are real. 84/85, 109/110, 134/135 boundaries; scraps independence;
# trade/leave non-usability; independent bound-gate (10) and Unpicker (75+25n) separate debits.
func _test_ac2_wallet_boundaries_and_separate_debits() -> void:
	var gate := RunV3ServiceWaystationEventGate.new()
	var inkblack_id := "v3_inkblack_unpicker_van"
	var starter_cards: Array[String] = StarterCards.new().get_starting_deck()
	var snap := {
		"deck": starter_cards,
		"descriptors": {},
		"next_stitch_id": 1,
	}

	# Boundary 1: prior_removals = 0 (toll 10, removal 75 -> total 85)
	var rng := _make_rng(201)
	var res_84 := gate.select_actionable_unpicker_event(rng, null, {"gold": 84, "scraps": 0}, snap, 0)
	_check(res_84 == {"ok": false, "event": {}}, "AC2: 84 gold rejected at prior 0")
	var res_84_s50 := gate.select_actionable_unpicker_event(rng, null, {"gold": 84, "scraps": 50}, snap, 0)
	_check(res_84_s50 == {"ok": false, "event": {}}, "AC2: 84 gold rejected at prior 0 regardless of scraps")

	var res_85 := gate.select_actionable_unpicker_event(rng, null, {"gold": 85, "scraps": 0}, snap, 0)
	_check(res_85.get("ok") == true and res_85["event"].get("id") == inkblack_id,
		"AC2: 85 gold admitted at prior 0 with 0 scraps")
	var res_85_s7 := gate.select_actionable_unpicker_event(rng, null, {"gold": 85, "scraps": 7}, snap, 0)
	_check(res_85_s7.get("ok") == true and res_85_s7["event"].get("id") == inkblack_id,
		"AC2: 85 gold admitted at prior 0 with 7 scraps")

	# Boundary 2: prior_removals = 1 (toll 10, removal 100 -> total 110)
	var res_109 := gate.select_actionable_unpicker_event(rng, null, {"gold": 109, "scraps": 0}, snap, 1)
	_check(res_109 == {"ok": false, "event": {}}, "AC2: 109 gold rejected at prior 1")
	var res_109_s20 := gate.select_actionable_unpicker_event(rng, null, {"gold": 109, "scraps": 20}, snap, 1)
	_check(res_109_s20 == {"ok": false, "event": {}}, "AC2: 109 gold rejected at prior 1 with 20 scraps")

	var res_110 := gate.select_actionable_unpicker_event(rng, null, {"gold": 110, "scraps": 0}, snap, 1)
	_check(res_110.get("ok") == true and res_110["event"].get("id") == inkblack_id,
		"AC2: 110 gold admitted at prior 1 with 0 scraps")

	# Boundary 3: prior_removals = 2 (toll 10, removal 125 -> total 135)
	var res_134 := gate.select_actionable_unpicker_event(rng, null, {"gold": 134, "scraps": 0}, snap, 2)
	_check(res_134 == {"ok": false, "event": {}}, "AC2: 134 gold rejected at prior 2")
	var res_134_s15 := gate.select_actionable_unpicker_event(rng, null, {"gold": 134, "scraps": 15}, snap, 2)
	_check(res_134_s15 == {"ok": false, "event": {}}, "AC2: 134 gold rejected at prior 2 with 15 scraps")

	var res_135 := gate.select_actionable_unpicker_event(rng, null, {"gold": 135, "scraps": 0}, snap, 2)
	_check(res_135.get("ok") == true and res_135["event"].get("id") == inkblack_id,
		"AC2: 135 gold admitted at prior 2 with 0 scraps")

	# Cost failure even when hire itself is affordable
	var res_10 := gate.select_actionable_unpicker_event(rng, null, {"gold": 10, "scraps": 0}, snap, 0)
	_check(res_10 == {"ok": false, "event": {}}, "AC2: 10 gold rejected even though 10-gold hire is affordable")
	var res_50 := gate.select_actionable_unpicker_event(rng, null, {"gold": 50, "scraps": 10}, snap, 0)
	_check(res_50 == {"ok": false, "event": {}}, "AC2: 50 gold rejected even though 10-gold hire is affordable")

	# Event trade / leave do not count as paid usability
	var res_trade := gate.select_actionable_unpicker_event(rng, null, {"gold": 0, "scraps": 10}, snap, 0)
	_check(res_trade == {"ok": false, "event": {}}, "AC2: Trade and leave do not count as paid service usability")

	# Contrast with generic select_affordable_service_event
	var gen_aff := gate.select_affordable_service_event(rng, null, {"gold": 10, "scraps": 0}, "Unpicker")
	_check(gen_aff.get("ok") == true, "AC2: Generic select_affordable_service_event admits 10 gold")
	var act_unpicker := gate.select_actionable_unpicker_event(rng, null, {"gold": 10, "scraps": 0}, snap, 0)
	_check(act_unpicker.get("ok") == false, "AC2: Actionable selector rejects 10 gold")

	# Independent bound-gate and Unpicker receipt charges 10 and 75+25n exactly once each
	var visit := gate.open_visit(inkblack_id)
	_check(visit != null and visit.is_valid(), "AC2: Gate visit opens validly")

	# Preview choices on visit
	var preview := visit.preview_choices({"gold": 85, "scraps": 0})
	_check(preview.get("ok") == true, "AC2: Gate choice preview succeeds")
	for ch in preview.get("choices", []):
		var cid: String = ch.get("choice_id", "")
		if cid == "hire_unpicker":
			_check(ch.get("service_request") == {"stop_type": "Unpicker"},
				"AC2: hire_unpicker previews {stop_type: Unpicker}")
		else:
			_check(ch.get("service_request") == {},
				"AC2: non-service choice previews empty service_request")

	# Settle hire_unpicker on gate: exact 10 gold debited
	var gate_claim := visit.choose_with_wallet("hire_unpicker", {"gold": 85, "scraps": 0})
	_check(gate_claim.get("ok") == true, "AC2: Gate hire_unpicker claim succeeds")
	_check(gate_claim.get("wallet") == {"gold": 75, "scraps": 0}, "AC2: Gate charges exactly 10 gold (85 -> 75)")
	_check(gate_claim.get("service_request") == {"stop_type": "Unpicker"},
		"AC2: Gate receipt returns {stop_type: Unpicker}")
	_check(visit.is_claimed() == true, "AC2: Gate is latched as claimed")
	_check(visit.is_valid() == false, "AC2: Claimed gate is no longer valid")
	var dup_gate := visit.choose_with_wallet("hire_unpicker", {"gold": 75, "scraps": 0})
	_check(dup_gate.get("ok") == false, "AC2: Gate rejects duplicate claim")

	# Open real Unpicker visit with post-toll wallet (75 gold)
	var unpicker := RunUnpickerVisit.new(inkblack_id, starter_cards.duplicate(), 75, 0, {}, 1)
	_check(unpicker.is_valid(), "AC2: Real RunUnpickerVisit opens validly")
	var unpicker_quote := unpicker.quote()
	_check(unpicker_quote.get("ok") == true and unpicker_quote.get("price") == 75,
		"AC2: Unpicker quotes 75 gold removal")

	# Settle remove_card on Unpicker: exact 75 gold debited
	var unpicker_state := unpicker.read_state()
	var unpicker_claim := unpicker.remove_card(
		"warden_strike", unpicker_state.get("visit_id"), inkblack_id, unpicker_state
	)
	_check(unpicker_claim.get("ok") == true, "AC2: Real Unpicker removal succeeds")
	_check(unpicker_claim.get("charged_gold") == 75, "AC2: Unpicker charges exactly 75 gold")
	_check(unpicker_claim.get("gold") == 0, "AC2: Wallet settled from 75 to 0 gold")
	_check(unpicker_claim.get("prior_removals") == 1, "AC2: Prior removals incremented from 0 to 1")
	_check(unpicker.is_consumed(), "AC2: Unpicker visit is latched as consumed")
	var dup_unpicker := unpicker.remove_card(
		"warden_strike", unpicker_state.get("visit_id"), inkblack_id, unpicker_state
	)
	_check(dup_unpicker.get("ok") == false, "AC2: Consumed Unpicker rejects duplicate removal")


# AC3: Fail closed without drift. Unfunded post-hire, excluded ID, empty/forged deck,
# invalid stitched registry or cursor, invalid prior count, overflow, bad RNG/wallet/exclusions.
func _test_ac3_refusal_state_preservation_and_rng() -> void:
	var gate := RunV3ServiceWaystationEventGate.new()
	var inkblack_id := "v3_inkblack_unpicker_van"
	var starter_cards: Array[String] = StarterCards.new().get_starting_deck()

	var caller_wallet := {"gold": 50, "scraps": 10}
	var caller_deck := starter_cards.duplicate()
	var caller_desc: Dictionary = {}
	var caller_cursor := 1
	var caller_prior := 0
	var caller_snap := {
		"deck": caller_deck,
		"descriptors": caller_desc,
		"next_stitch_id": caller_cursor,
	}

	var w_before := caller_wallet.duplicate(true)
	var d_before := caller_deck.duplicate(true)
	var desc_before := caller_desc.duplicate(true)
	var s_before := caller_snap.duplicate(true)

	var rng := _make_rng(301)
	var rng_state_before := rng.state

	# 1. Unfunded post-hire call
	var res_unfunded := gate.select_actionable_unpicker_event(rng, null, caller_wallet, caller_snap, caller_prior)
	_check(res_unfunded == {"ok": false, "event": {}}, "AC3: Unfunded post-hire returns refusal")
	_check(rng.state == rng_state_before, "AC3: Refusal consumes 0 RNG draws")
	_check(caller_wallet == w_before, "AC3: Caller wallet unmodified")
	_check(caller_deck == d_before, "AC3: Caller deck unmodified")
	_check(caller_desc == desc_before, "AC3: Caller descriptors unmodified")
	_check(caller_snap == s_before, "AC3: Caller snapshot unmodified")
	_check(gate.is_claimed() == false, "AC3: Gate visit claim unmodified")

	# 2. Excluded ID
	var res_ex := gate.select_actionable_unpicker_event(rng, [inkblack_id], {"gold": 100, "scraps": 0}, caller_snap, 0)
	_check(res_ex == {"ok": false, "event": {}}, "AC3: Excluded Inkblack ID returns refusal")
	_check(rng.state == rng_state_before, "AC3: Excluded ID consumes 0 RNG draws")

	# 3. Empty deck
	var res_empty := gate.select_actionable_unpicker_event(
		rng, null, {"gold": 100, "scraps": 0}, {"deck": [], "descriptors": {}, "next_stitch_id": 1}, 0
	)
	_check(res_empty == {"ok": false, "event": {}}, "AC3: Empty deck rejected")
	_check(rng.state == rng_state_before, "AC3: Empty deck consumes 0 RNG draws")

	# 4. Forged deck (counterfeit card / non-string)
	var res_fake := gate.select_actionable_unpicker_event(
		rng, null, {"gold": 100, "scraps": 0}, {"deck": ["counterfeit_card"], "descriptors": {}, "next_stitch_id": 1}, 0
	)
	_check(res_fake == {"ok": false, "event": {}}, "AC3: Counterfeit card ID rejected")
	var res_non_str := gate.select_actionable_unpicker_event(
		rng, null, {"gold": 100, "scraps": 0}, {"deck": [123], "descriptors": {}, "next_stitch_id": 1}, 0
	)
	_check(res_non_str == {"ok": false, "event": {}}, "AC3: Non-string card in deck rejected")
	_check(rng.state == rng_state_before, "AC3: Forged deck consumes 0 RNG draws")

	# 5. Invalid stitched registry
	# Same-owner halves
	var w_def: Dictionary = StarterCards.new().get_definition("warden_strike")
	var w_brace_def: Dictionary = StarterCards.new().get_definition("warden_brace")
	var same_owner_desc := RunRestStitchCards._make_descriptor("stitched_000001", w_def, w_brace_def)
	var res_same_owner := gate.select_actionable_unpicker_event(
		rng, null, {"gold": 100, "scraps": 0},
		{"deck": ["stitched_000001"], "descriptors": {"stitched_000001": same_owner_desc}, "next_stitch_id": 2}, 0
	)
	_check(res_same_owner == {"ok": false, "event": {}}, "AC3: Same-owner descriptor rejected")

	# Serial >= next_stitch_id
	var t_def: Dictionary = StarterCards.new().get_definition("tinker_tune_up")
	var valid_desc := RunRestStitchCards._make_descriptor("stitched_000001", w_def, t_def)
	var res_serial_high := gate.select_actionable_unpicker_event(
		rng, null, {"gold": 100, "scraps": 0},
		{"deck": ["stitched_000001"], "descriptors": {"stitched_000001": valid_desc}, "next_stitch_id": 1}, 0
	)
	_check(res_serial_high == {"ok": false, "event": {}}, "AC3: Serial >= next_stitch_id rejected")

	# Stale descriptor missing from deck
	var res_stale := gate.select_actionable_unpicker_event(
		rng, null, {"gold": 100, "scraps": 0},
		{"deck": ["warden_strike"], "descriptors": {"stitched_000001": valid_desc}, "next_stitch_id": 2}, 0
	)
	_check(res_stale == {"ok": false, "event": {}}, "AC3: Stale descriptor missing from deck rejected")

	# Duplicate composite in deck
	var res_dup := gate.select_actionable_unpicker_event(
		rng, null, {"gold": 100, "scraps": 0},
		{"deck": ["stitched_000001", "stitched_000001"], "descriptors": {"stitched_000001": valid_desc}, "next_stitch_id": 2}, 0
	)
	_check(res_dup == {"ok": false, "event": {}}, "AC3: Duplicate composite in deck rejected")
	_check(rng.state == rng_state_before, "AC3: Invalid stitched registry consumes 0 RNG draws")

	# 6. Invalid cursor values
	_check(gate.select_actionable_unpicker_event(rng, null, {"gold": 100, "scraps": 0}, {"deck": ["warden_strike"], "descriptors": {}, "next_stitch_id": 0}, 0) == {"ok": false, "event": {}}, "AC3: Cursor 0 rejected")
	_check(gate.select_actionable_unpicker_event(rng, null, {"gold": 100, "scraps": 0}, {"deck": ["warden_strike"], "descriptors": {}, "next_stitch_id": -1}, 0) == {"ok": false, "event": {}}, "AC3: Negative cursor rejected")
	_check(gate.select_actionable_unpicker_event(rng, null, {"gold": 100, "scraps": 0}, {"deck": ["warden_strike"], "descriptors": {}, "next_stitch_id": "1"}, 0) == {"ok": false, "event": {}}, "AC3: String cursor rejected")
	_check(gate.select_actionable_unpicker_event(rng, null, {"gold": 100, "scraps": 0}, {"deck": ["warden_strike"], "descriptors": {}, "next_stitch_id": RunRestStitchCards.MAX_INT}, 0) == {"ok": false, "event": {}}, "AC3: Cursor MAX_INT rejected")
	_check(rng.state == rng_state_before, "AC3: Invalid cursor consumes 0 RNG draws")

	# 7. Invalid prior_removals
	_check(gate.select_actionable_unpicker_event(rng, null, {"gold": 100, "scraps": 0}, caller_snap, -1) == {"ok": false, "event": {}}, "AC3: Negative prior rejected")
	_check(gate.select_actionable_unpicker_event(rng, null, {"gold": 100, "scraps": 0}, caller_snap, "0") == {"ok": false, "event": {}}, "AC3: String prior rejected")
	_check(gate.select_actionable_unpicker_event(rng, null, {"gold": 100, "scraps": 0}, caller_snap, 1.5) == {"ok": false, "event": {}}, "AC3: Float prior rejected")
	_check(gate.select_actionable_unpicker_event(rng, null, {"gold": 100, "scraps": 0}, caller_snap, null) == {"ok": false, "event": {}}, "AC3: Null prior rejected")
	_check(gate.select_actionable_unpicker_event(rng, null, {"gold": 100, "scraps": 0}, caller_snap, RunShopCardRemoval.MAX_INT) == {"ok": false, "event": {}}, "AC3: Overflow prior rejected")
	_check(rng.state == rng_state_before, "AC3: Invalid prior consumes 0 RNG draws")

	# 8. Bad RNG
	_check(gate.select_actionable_unpicker_event(null, null, {"gold": 100, "scraps": 0}, caller_snap, 0) == {"ok": false, "event": {}}, "AC3: Null RNG rejected")
	_check(gate.select_actionable_unpicker_event(42, null, {"gold": 100, "scraps": 0}, caller_snap, 0) == {"ok": false, "event": {}}, "AC3: Int RNG rejected")
	_check(gate.select_actionable_unpicker_event("rng", null, {"gold": 100, "scraps": 0}, caller_snap, 0) == {"ok": false, "event": {}}, "AC3: String RNG rejected")

	# 9. Bad wallet
	_check(gate.select_actionable_unpicker_event(rng, null, null, caller_snap, 0) == {"ok": false, "event": {}}, "AC3: Null wallet rejected")
	_check(gate.select_actionable_unpicker_event(rng, null, {}, caller_snap, 0) == {"ok": false, "event": {}}, "AC3: Empty wallet rejected")
	_check(gate.select_actionable_unpicker_event(rng, null, {"gold": 100}, caller_snap, 0) == {"ok": false, "event": {}}, "AC3: Missing scraps rejected")
	_check(gate.select_actionable_unpicker_event(rng, null, {"scraps": 0}, caller_snap, 0) == {"ok": false, "event": {}}, "AC3: Missing gold rejected")
	_check(gate.select_actionable_unpicker_event(rng, null, {"gold": -1, "scraps": 0}, caller_snap, 0) == {"ok": false, "event": {}}, "AC3: Negative gold rejected")
	_check(gate.select_actionable_unpicker_event(rng, null, {"gold": 100, "scraps": -1}, caller_snap, 0) == {"ok": false, "event": {}}, "AC3: Negative scraps rejected")
	_check(gate.select_actionable_unpicker_event(rng, null, {"gold": 100.5, "scraps": 0}, caller_snap, 0) == {"ok": false, "event": {}}, "AC3: Float gold rejected")
	_check(gate.select_actionable_unpicker_event(rng, null, {"gold": 100, "scraps": 0.5}, caller_snap, 0) == {"ok": false, "event": {}}, "AC3: Float scraps rejected")
	_check(gate.select_actionable_unpicker_event(rng, null, {"gold": 100, "scraps": 0, "extra": 1}, caller_snap, 0) == {"ok": false, "event": {}}, "AC3: Extra wallet key rejected")
	_check(rng.state == rng_state_before, "AC3: Bad wallet consumes 0 RNG draws")

	# 10. Malformed exclusions
	_check(gate.select_actionable_unpicker_event(rng, "not_an_array", {"gold": 100, "scraps": 0}, caller_snap, 0) == {"ok": false, "event": {}}, "AC3: String exclusion rejected")
	_check(gate.select_actionable_unpicker_event(rng, 123, {"gold": 100, "scraps": 0}, caller_snap, 0) == {"ok": false, "event": {}}, "AC3: Int exclusion rejected")
	_check(gate.select_actionable_unpicker_event(rng, [123], {"gold": 100, "scraps": 0}, caller_snap, 0) == {"ok": false, "event": {}}, "AC3: Non-string item in exclusions rejected")
	_check(gate.select_actionable_unpicker_event(rng, [""], {"gold": 100, "scraps": 0}, caller_snap, 0) == {"ok": false, "event": {}}, "AC3: Empty string in exclusions rejected")
	_check(gate.select_actionable_unpicker_event(rng, ["   "], {"gold": 100, "scraps": 0}, caller_snap, 0) == {"ok": false, "event": {}}, "AC3: Blank string in exclusions rejected")
	_check(rng.state == rng_state_before, "AC3: Malformed exclusions consume 0 RNG draws")

	# 11. Malformed snapshot dictionary
	_check(gate.select_actionable_unpicker_event(rng, null, {"gold": 100, "scraps": 0}, {"descriptors": {}, "next_stitch_id": 1}, 0) == {"ok": false, "event": {}}, "AC3: Missing deck in snapshot rejected")
	_check(gate.select_actionable_unpicker_event(rng, null, {"gold": 100, "scraps": 0}, {"deck": ["warden_strike"], "next_stitch_id": 1}, 0) == {"ok": false, "event": {}}, "AC3: Missing descriptors in snapshot rejected")
	_check(gate.select_actionable_unpicker_event(rng, null, {"gold": 100, "scraps": 0}, {"deck": ["warden_strike"], "descriptors": {}}, 0) == {"ok": false, "event": {}}, "AC3: Missing cursor in snapshot rejected")
	_check(gate.select_actionable_unpicker_event(rng, null, {"gold": 100, "scraps": 0}, null, 0) == {"ok": false, "event": {}}, "AC3: Null snapshot rejected")
	_check(rng.state == rng_state_before, "AC3: Malformed snapshot consumes 0 RNG draws")


# AC4: Determinism and preserved services. Same valid seed/input replay yields same event/draw state;
# one RNG draw on success; detached catalog output; preserved Campfire/Sewing/Unpicker selectors and alt/leave choices.
func _test_ac4_determinism_and_preserved_services() -> void:
	var gate := RunV3ServiceWaystationEventGate.new()
	var inkblack_id := "v3_inkblack_unpicker_van"
	var starter_cards: Array[String] = StarterCards.new().get_starting_deck()
	var snap := {
		"deck": starter_cards,
		"descriptors": {},
		"next_stitch_id": 1,
	}

	# 1. Deterministic replay on identical seeds
	for test_seed: int in [42, 777, 9999, 123456]:
		var rng_a := _make_rng(test_seed)
		var rng_b := _make_rng(test_seed)
		var res_a := gate.select_actionable_unpicker_event(rng_a, null, {"gold": 100, "scraps": 0}, snap, 0)
		var res_b := gate.select_actionable_unpicker_event(rng_b, null, {"gold": 100, "scraps": 0}, snap, 0)
		_check(res_a.get("ok") == true and res_b.get("ok") == true, "AC4: Deterministic run succeeded")
		_check(res_a == res_b, "AC4: Identical result on seed " + str(test_seed))
		_check(rng_a.state == rng_b.state, "AC4: Identical RNG progression on seed " + str(test_seed))

	# 2. Exactly one randi_range draw on success
	var seed_val := 4321
	var rng_main := _make_rng(seed_val)
	var rng_probe := _make_rng(seed_val)
	var probe_draw := rng_probe.randi_range(0, 0)
	var res_main := gate.select_actionable_unpicker_event(rng_main, null, {"gold": 100, "scraps": 0}, snap, 0)
	_check(res_main.get("ok") == true, "AC4: Selection succeeds")
	_check(rng_main.state == rng_probe.state, "AC4: Exactly one randi_range draw consumed on success")

	# 3. Detached catalog output
	var mod_event: Dictionary = res_main["event"]
	var orig_title: String = mod_event.get("title", "")
	mod_event["title"] = "MUTATED_TITLE"
	mod_event["choices"][0]["outcome"]["gold"] = -9999
	var pristine := gate.get_event_record(inkblack_id)
	_check(pristine.get("title") == orig_title, "AC4: Catalog record title not mutated by modifying result")
	_check(pristine.get("choices", [])[0].get("outcome", {}).get("gold") == -10,
		"AC4: Catalog record outcome not mutated by modifying result")

	# 4. Preserved existing selectors
	var rng_gen := _make_rng(501)
	var res_generic := gate.select_event(rng_gen)
	_check(res_generic.get("ok") == true, "AC4: select_event remains functional")

	var res_aff_unpicker := gate.select_affordable_service_event(
		rng_gen, null, {"gold": 50, "scraps": 0}, "Unpicker"
	)
	_check(res_aff_unpicker.get("ok") == true, "AC4: select_affordable_service_event Unpicker remains functional")
	_check(res_aff_unpicker.get("event", {}).get("service_kind") == "Unpicker", "AC4: Service kind matches")

	var res_aff_campfire := gate.select_affordable_service_event(
		rng_gen, null, {"gold": 50, "scraps": 5}, "Campfire"
	)
	_check(res_aff_campfire.get("ok") == true, "AC4: select_affordable_service_event Campfire remains functional")

	var res_aff_sewing := gate.select_affordable_service_event(
		rng_gen, null, {"gold": 50, "scraps": 5}, "SewingCircle"
	)
	_check(res_aff_sewing.get("ok") == true, "AC4: select_affordable_service_event SewingCircle remains functional")

	# Actionable Campfire selector remains functional
	var wounded_party: Array = [
		{"id": "warden", "position": 1, "hp": 20, "max_hp": 40},
		{"id": "seamstress", "position": 2, "hp": 15, "max_hp": 30},
		{"id": "tinker", "position": 3, "hp": 10, "max_hp": 26},
	]
	var res_act_cf := gate.select_actionable_campfire_event(
		rng_gen, null, {"gold": 0, "scraps": 5}, wounded_party
	)
	_check(res_act_cf.get("ok") == true, "AC4: select_actionable_campfire_event remains functional")

	# Actionable Sewing selector remains functional
	var res_act_sew := gate.select_actionable_sewing_event(
		rng_gen, null, {"gold": 25, "scraps": 5}, snap
	)
	_check(res_act_sew.get("ok") == true, "AC4: select_actionable_sewing_event remains functional")

	# 5. Preserved alternate trade and Leave in Inkblack
	var visit_trade := gate.open_visit(inkblack_id)
	_check(visit_trade != null and visit_trade.is_valid(), "AC4: Inkblack visit opens for trade")
	var trade_res := visit_trade.choose_with_wallet("sell_trim", {"gold": 0, "scraps": 0})
	_check(trade_res.get("ok") == true, "AC4: sell_trim choice succeeds")
	_check(trade_res.get("wallet") == {"gold": 0, "scraps": 1}, "AC4: sell_trim grants 1 scrap")
	_check(trade_res.get("service_request") == {}, "AC4: sell_trim returns empty service_request")
	_check(visit_trade.is_claimed(), "AC4: sell_trade latches visit")

	var visit_leave := gate.open_visit(inkblack_id)
	_check(visit_leave != null and visit_leave.is_valid(), "AC4: Inkblack visit opens for leave")
	var leave_res := visit_leave.choose_with_wallet("leave", {"gold": 0, "scraps": 0})
	_check(leave_res.get("ok") == true, "AC4: leave choice succeeds")
	_check(leave_res.get("wallet") == {"gold": 0, "scraps": 0}, "AC4: leave outcome is zero delta")
	_check(leave_res.get("service_request") == {}, "AC4: leave returns empty service_request")
	_check(visit_leave.is_claimed(), "AC4: leave latches visit")
