extends SceneTree
## Deterministic regression suite for RunV3ServiceWaystationEventGate.select_actionable_campfire_event (V3-4).
## Exercises AC1 (actionable offers only, scraps thresholds),
## AC2 (genuine Campfire recovery preview on deep-detached snapshots, isolation, no spend),
## AC3 (useless offers refusal, invalid roster/wallet/exclusions/RNG, one-draw RNG, detachment),
## and AC4 (preserved catalog outcomes, independent open_visit Campfire stop_type receipts, one-claim latch).

var failures: Array[String] = []
var checks: int = 0


func _init() -> void:
	_test_ac1_actionable_campfire_offers()
	_test_ac2_party_recovery_preview_and_isolation()
	_test_ac3_refusal_state_preservation_and_rng()
	_test_ac4_gate_visit_receipts_and_catalog_invariants()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("run_v3_campfire_waystation_actionability_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _make_rng(seed_val: int = 12345) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng


func _sample_party(hps: Array, max_hps: Array = [40, 30, 26]) -> Array:
	var party: Array = []
	var ids := ["warden", "seamstress", "tinker"]
	for i in range(3):
		party.append({
			"id": ids[i],
			"position": i + 1,
			"hp": hps[i],
			"max_hp": max_hps[i],
			"block": 5 + i,
			"statuses": {"bleed": {"stacks": i}},
			"metadata": {"patches": ["patch_%d" % i]},
		})
	return party


# AC1: Offers only an unvisited Campfire whose exact paid service is affordable AND whose authentic heal changes party HP.
# Test Emberglass at 0/1 scraps and Briar-Button at 1/2 scraps (no gold cost), with independent exclusions.
func _test_ac1_actionable_campfire_offers() -> void:
	var gate := RunV3ServiceWaystationEventGate.new()
	_check(gate.is_catalog_valid(), "AC1: Catalog is valid")

	var ember_id := "v3_emberglass_campfire"
	var briar_id := "v3_briar_button_mending_bench"
	var wounded_party := _sample_party([35, 18, 0])

	# Boundary 1: Emberglass scraps 0 vs 1 (gold 0). Toll is 1 scrap.
	var rng_e0 := _make_rng(101)
	var res_e0 := gate.select_actionable_campfire_event(
		rng_e0, [briar_id], {"gold": 0, "scraps": 0}, wounded_party
	)
	_check(res_e0 == {"ok": false, "event": {}}, "AC1: Emberglass unaffordable at 0 scraps")

	var rng_e1 := _make_rng(102)
	var res_e1 := gate.select_actionable_campfire_event(
		rng_e1, [briar_id], {"gold": 0, "scraps": 1}, wounded_party
	)
	_check(res_e1.get("ok") == true, "AC1: Emberglass affordable at 1 scrap")
	_check(res_e1.get("event", {}).get("id") == ember_id, "AC1: Emberglass ID returned")
	_check(res_e1.get("event", {}).get("service_kind") == "Campfire", "AC1: Emberglass service_kind is Campfire")

	# Boundary 2: Briar-Button scraps 1 vs 2 (gold 0). Toll is 2 scraps.
	var rng_b1 := _make_rng(103)
	var res_b1 := gate.select_actionable_campfire_event(
		rng_b1, [ember_id], {"gold": 0, "scraps": 1}, wounded_party
	)
	_check(res_b1 == {"ok": false, "event": {}}, "AC1: Briar-Button unaffordable at 1 scrap")

	var rng_b2 := _make_rng(104)
	var res_b2 := gate.select_actionable_campfire_event(
		rng_b2, [ember_id], {"gold": 0, "scraps": 2}, wounded_party
	)
	_check(res_b2.get("ok") == true, "AC1: Briar-Button affordable at 2 scraps")
	_check(res_b2.get("event", {}).get("id") == briar_id, "AC1: Briar-Button ID returned")
	_check(res_b2.get("event", {}).get("service_kind") == "Campfire", "AC1: Briar-Button service_kind is Campfire")

	# Query at 1 scrap without exclusions: only Emberglass is eligible.
	var rng_1s := _make_rng(105)
	var res_1s := gate.select_actionable_campfire_event(
		rng_1s, null, {"gold": 0, "scraps": 1}, wounded_party
	)
	_check(res_1s.get("ok") == true and res_1s.get("event", {}).get("id") == ember_id,
		"AC1: 1 scrap selects Emberglass when both in catalog")

	# Query at 2 scraps without exclusions: both are eligible, selection is authentic.
	var rng_2s := _make_rng(106)
	var res_2s := gate.select_actionable_campfire_event(
		rng_2s, null, {"gold": 0, "scraps": 2}, wounded_party
	)
	_check(res_2s.get("ok") == true, "AC1: 2 scraps selects an eligible Campfire")
	var chosen_id: String = res_2s.get("event", {}).get("id", "")
	_check(chosen_id == ember_id or chosen_id == briar_id, "AC1: Returned ID is authentic Campfire")

	# Exclude both Campfires: rejection.
	var rng_ex := _make_rng(107)
	var res_ex := gate.select_actionable_campfire_event(
		rng_ex, [ember_id, briar_id], {"gold": 100, "scraps": 100}, wounded_party
	)
	_check(res_ex == {"ok": false, "event": {}}, "AC1: Excluding both Campfires returns refusal")

	# Compare with RunEventChoice.preview_wallet_choices:
	var ember_record: Dictionary = gate.get_event_record(ember_id)
	var briar_record: Dictionary = gate.get_event_record(briar_id)
	var ember_preview_1 := RunEventChoice.new(ember_record).preview_wallet_choices({"gold": 0, "scraps": 1})
	var briar_preview_1 := RunEventChoice.new(briar_record).preview_wallet_choices({"gold": 0, "scraps": 1})
	var ember_paid_affordable := false
	for ch in ember_preview_1.get("choices", []):
		if ch.get("choice_id") == "light_the_embers":
			ember_paid_affordable = ch.get("affordable", false)
	var briar_paid_affordable := false
	for ch in briar_preview_1.get("choices", []):
		if ch.get("choice_id") == "fuel_button_fire":
			briar_paid_affordable = ch.get("affordable", false)
	_check(ember_paid_affordable == true, "AC1: RunEventChoice forecasts Emberglass affordable at 1 scrap")
	_check(briar_paid_affordable == false, "AC1: RunEventChoice forecasts Briar-Button unaffordable at 1 scrap")

	# Fully healed party produces no selection even with abundant scraps.
	var full_party := _sample_party([40, 30, 26])
	var rng_full := _make_rng(108)
	var res_full := gate.select_actionable_campfire_event(
		rng_full, null, {"gold": 100, "scraps": 100}, full_party
	)
	_check(res_full == {"ok": false, "event": {}}, "AC1: No selection when party is fully healed")

	# Defeated party (everyone down) produces no selection.
	var dead_party := _sample_party([0, 0, 0])
	var rng_dead := _make_rng(109)
	var res_dead := gate.select_actionable_campfire_event(
		rng_dead, null, {"gold": 100, "scraps": 100}, dead_party
	)
	_check(res_dead == {"ok": false, "event": {}}, "AC1: No selection when everyone is down")


# AC2: Helper previews RunCampfireVisit/RunRestRecovery on deep-detached snapshots.
# A max-HP-30 Torn hero becomes 10 HP and max-HP-25 hero at 12 HP becomes 19 HP; full-HP hero stays full.
# Selector never heals source roster or debits wallet; exact fee debited only on claimed RunEventChoice receipt.
func _test_ac2_party_recovery_preview_and_isolation() -> void:
	var gate := RunV3ServiceWaystationEventGate.new()
	var ember_id := "v3_emberglass_campfire"

	# Authored fixture from BRIEF details:
	# [{id:warden,position:1,hp:30,max_hp:30},{id:seamstress,position:2,hp:12,max_hp:25},{id:tinker,position:3,hp:0,max_hp:30}]
	var test_party: Array = [
		{"id": "warden", "position": 1, "hp": 30, "max_hp": 30, "block": 4},
		{"id": "seamstress", "position": 2, "hp": 12, "max_hp": 25, "block": 6},
		{"id": "tinker", "position": 3, "hp": 0, "max_hp": 30, "block": 8},
	]
	var party_before := test_party.duplicate(true)

	# Verify throwaway RunCampfireVisit directly on this roster:
	var throwaway_visit := RunCampfireVisit.new("throwaway_node", test_party)
	_check(throwaway_visit.read_state().get("status") == RunCampfireVisit.OPEN,
		"AC2: Throwaway RunCampfireVisit opens successfully")
	var receipt: Dictionary = throwaway_visit.choose_heal("throwaway_node", test_party)
	_check(receipt.get("ok") == true and receipt.get("decision") == "heal",
		"AC2: Throwaway RunCampfireVisit heal receipt is valid")
	var healed_roster: Array = receipt.get("heroes", [])
	_check(healed_roster.size() == 3, "AC2: Healed roster has 3 heroes")
	_check(healed_roster[0].get("hp") == 30, "AC2: Full-HP Warden (30/30) stays at 30 HP")
	_check(healed_roster[1].get("hp") == 19, "AC2: Wounded Seamstress (12/25) becomes 19 HP (12 + floor(25*0.3)=7)")
	_check(healed_roster[2].get("hp") == 10, "AC2: Torn Tinker (0/30) revives to 1 + floor(30*0.3)=9 -> 10 HP")

	# Verify visit one-use semantics on throwaway visit:
	var second_heal: Dictionary = throwaway_visit.choose_heal("throwaway_node", healed_roster)
	_check(second_heal.get("ok") == false, "AC2: Throwaway visit rejects duplicate heal")
	var second_leave: Dictionary = throwaway_visit.leave("throwaway_node", healed_roster)
	_check(second_leave.get("ok") == false, "AC2: Throwaway visit rejects leave after heal")

	# Selector execution: verify deep snapshot isolation of caller party and wallet:
	var caller_wallet := {"gold": 25, "scraps": 4}
	var wallet_before := caller_wallet.duplicate(true)
	var rng := _make_rng(201)
	var res := gate.select_actionable_campfire_event(rng, null, caller_wallet, test_party)
	_check(res.get("ok") == true, "AC2: Selection succeeds for actionable roster")
	_check(caller_wallet == wallet_before, "AC2: Caller wallet untouched by selector preview")
	_check(test_party == party_before, "AC2: Caller party untouched by selector preview (Tinker still 0 HP)")

	# Exact fee is deducted only on separately claimed RunEventChoice receipt:
	var ember_record: Dictionary = gate.get_event_record(ember_id)
	var choice_runner := RunEventChoice.new(ember_record)
	var claim_receipt := choice_runner.choose_with_wallet("light_the_embers", caller_wallet)
	_check(claim_receipt.get("ok") == true, "AC2: RunEventChoice claims service choice")
	_check(claim_receipt.get("wallet") == {"gold": 25, "scraps": 3},
		"AC2: Exact toll (0 gold, 1 scrap) debited only on claimed receipt")


# AC3: Refuse useless offers, invalid inputs, preserve state, zero RNG on refusal, one randi_range on success.
func _test_ac3_refusal_state_preservation_and_rng() -> void:
	var gate := RunV3ServiceWaystationEventGate.new()
	var ember_id := "v3_emberglass_campfire"
	var briar_id := "v3_briar_button_mending_bench"
	var funded_wallet := {"gold": 50, "scraps": 10}
	var wounded_party := _sample_party([35, 18, 0])
	var full_party := _sample_party([40, 30, 26])
	var all_down_party := _sample_party([0, 0, 0])

	# 1. Full-health party -> refusal, 0 RNG draws.
	var rng_full := _make_rng(301)
	var state_full_before := rng_full.state
	var res_full := gate.select_actionable_campfire_event(rng_full, null, funded_wallet, full_party)
	_check(res_full == {"ok": false, "event": {}}, "AC3: Full party rejected")
	_check(rng_full.state == state_full_before, "AC3: Full party consumes 0 RNG draws")

	# 2. All-downed party -> refusal, 0 RNG draws.
	var rng_down := _make_rng(302)
	var state_down_before := rng_down.state
	var res_down := gate.select_actionable_campfire_event(rng_down, null, funded_wallet, all_down_party)
	_check(res_down == {"ok": false, "event": {}}, "AC3: All-down party rejected")
	_check(rng_down.state == state_down_before, "AC3: All-down party consumes 0 RNG draws")

	# 3. Malformed / invalid rosters -> refusal, 0 RNG draws.
	var bad_rosters: Array = [
		null,
		"not a roster",
		123,
		[],
		wounded_party.slice(0, 2), # only 2 heroes
		wounded_party + [{"id": "extra", "position": 4, "hp": 10, "max_hp": 20}], # 4 heroes
		_sample_party([10, 10, 10], [0, 30, 26]), # max_hp <= 0
		_sample_party([-1, 10, 10]), # negative hp
		_sample_party([50, 10, 10]), # hp > max_hp
		[wounded_party[0], wounded_party[0], wounded_party[2]], # duplicate hero ID
	]
	var malformed_pos := wounded_party.duplicate(true)
	malformed_pos[1]["position"] = 3
	bad_rosters.append(malformed_pos) # non-sequential position

	for bad_roster in bad_rosters:
		var rng_bad := _make_rng(303)
		var s_before := rng_bad.state
		var res_bad := gate.select_actionable_campfire_event(rng_bad, null, funded_wallet, bad_roster)
		_check(res_bad == {"ok": false, "event": {}}, "AC3: Malformed roster rejected")
		_check(rng_bad.state == s_before, "AC3: Malformed roster consumes 0 RNG draws")

	# Also verify dictionary wrapper format {"heroes": wounded_party} is supported.
	var rng_dict := _make_rng(304)
	var res_dict := gate.select_actionable_campfire_event(rng_dict, null, funded_wallet, {"heroes": wounded_party})
	_check(res_dict.get("ok") == true, "AC3: Snapshot dictionary with heroes array accepted")

	# 4. Malformed / invalid wallet -> refusal, 0 RNG draws.
	var bad_wallets: Array = [
		null,
		"bad_wallet",
		123,
		{},
		{"gold": 10}, # missing scraps
		{"scraps": 5}, # missing gold
		{"gold": -1, "scraps": 5}, # negative gold
		{"gold": 5, "scraps": -1}, # negative scraps
		{"gold": 1.5, "scraps": 2}, # float gold
		{"gold": 0, "scraps": 2.0}, # float scraps
		{"gold": 0, "scraps": 2, "extra": 1}, # extra keys
	]
	for bad_w in bad_wallets:
		var rng_w := _make_rng(305)
		var s_w_before := rng_w.state
		var res_w := gate.select_actionable_campfire_event(rng_w, null, bad_w, wounded_party)
		_check(res_w == {"ok": false, "event": {}}, "AC3: Malformed wallet rejected")
		_check(rng_w.state == s_w_before, "AC3: Malformed wallet consumes 0 RNG draws")

	# 5. Malformed exclusions -> refusal, 0 RNG draws.
	var bad_exclusions: Array = [
		"not_an_array",
		123,
		[123],
		[""],
		["   "],
	]
	for bad_ex in bad_exclusions:
		var rng_ex := _make_rng(306)
		var s_ex_before := rng_ex.state
		var res_ex := gate.select_actionable_campfire_event(rng_ex, bad_ex, funded_wallet, wounded_party)
		_check(res_ex == {"ok": false, "event": {}}, "AC3: Malformed exclusions rejected")
		_check(rng_ex.state == s_ex_before, "AC3: Malformed exclusions consume 0 RNG draws")

	# 6. Invalid RNG -> refusal.
	var res_null_rng := gate.select_actionable_campfire_event(null, null, funded_wallet, wounded_party)
	_check(res_null_rng == {"ok": false, "event": {}}, "AC3: Null RNG rejected")
	var res_int_rng := gate.select_actionable_campfire_event(42, null, funded_wallet, wounded_party)
	_check(res_int_rng == {"ok": false, "event": {}}, "AC3: Int RNG rejected")

	# 7. Unaffordable fees -> refusal, 0 RNG draws.
	var rng_broke := _make_rng(307)
	var s_broke_before := rng_broke.state
	var res_broke := gate.select_actionable_campfire_event(
		rng_broke, null, {"gold": 100, "scraps": 0}, wounded_party
	)
	_check(res_broke == {"ok": false, "event": {}}, "AC3: Zero scraps cannot afford any Campfire")
	_check(rng_broke.state == s_broke_before, "AC3: Unaffordable fees consume 0 RNG draws")

	# 8. Deterministic selection and probe RNG agreement (exactly one randi_range call).
	var seed_val := 777
	var rng_run1 := _make_rng(seed_val)
	var res_run1 := gate.select_actionable_campfire_event(rng_run1, null, funded_wallet, wounded_party)
	var rng_run2 := _make_rng(seed_val)
	var res_run2 := gate.select_actionable_campfire_event(rng_run2, null, funded_wallet, wounded_party)
	_check(res_run1.get("ok") == true, "AC3: Deterministic selection succeeds")
	_check(res_run1 == res_run2, "AC3: Identical seed and inputs produce identical result")
	_check(rng_run1.state == rng_run2.state, "AC3: RNG state matches across identical runs")

	# Verify with independent probe RNG:
	# Alphabetical sort of [briar_id, ember_id]: index 0 is briar, index 1 is ember.
	var probe_rng := _make_rng(seed_val)
	var sorted_candidates := [briar_id, ember_id]
	sorted_candidates.sort()
	var expected_idx: int = probe_rng.randi_range(0, sorted_candidates.size() - 1)
	var expected_id: String = sorted_candidates[expected_idx]
	_check(res_run1.get("event", {}).get("id") == expected_id,
		"AC3: Probe RNG agrees with selector choice")
	_check(rng_run1.state == probe_rng.state,
		"AC3: Exactly one randi_range draw consumed on successful selection")

	# 9. Catalog detachment / immutability:
	res_run1["event"]["title"] = "MUTATED_TITLE"
	res_run1["event"]["choices"][0]["outcome"]["scraps"] = -999
	var pristine_record: Dictionary = gate.get_event_record(res_run1["event"]["id"])
	_check(pristine_record.get("title") != "MUTATED_TITLE",
		"AC3: Mutating returned event record does not mutate catalog")
	_check(pristine_record.get("choices", [])[0].get("outcome", {}).get("scraps") != -999,
		"AC3: Mutating returned event choices does not mutate catalog")


# AC4: Preserves catalog outcomes, open_visit {stop_type: Campfire} receipts, one-claim latch, compatibility.
func _test_ac4_gate_visit_receipts_and_catalog_invariants() -> void:
	var gate := RunV3ServiceWaystationEventGate.new()
	var ember_id := "v3_emberglass_campfire"
	var briar_id := "v3_briar_button_mending_bench"

	# Verify catalog entries presence (without asserting total catalog size):
	var ember_rec := gate.get_event_record(ember_id)
	var briar_rec := gate.get_event_record(briar_id)
	_check(not ember_rec.is_empty(), "AC4: Shipped Emberglass record present")
	_check(not briar_rec.is_empty(), "AC4: Shipped Briar-Button record present")

	# Exact paid choice outcomes:
	_check(ember_rec.get("service_choice_id") == "light_the_embers", "AC4: Emberglass service choice id")
	_check(ember_rec.get("choices")[0].get("outcome") == {"gold": 0, "scraps": -1}, "AC4: Emberglass paid outcome 0/-1")
	_check(ember_rec.get("choices")[1].get("outcome") == {"gold": 12, "scraps": 0}, "AC4: Emberglass sell_cinders outcome +12/0")
	_check(ember_rec.get("choices")[2].get("outcome") == {"gold": 0, "scraps": 0}, "AC4: Emberglass leave outcome 0/0")

	_check(briar_rec.get("service_choice_id") == "fuel_button_fire", "AC4: Briar-Button service choice id")
	_check(briar_rec.get("choices")[0].get("outcome") == {"gold": 0, "scraps": -2}, "AC4: Briar-Button paid outcome 0/-2")
	_check(briar_rec.get("choices")[1].get("outcome") == {"gold": 14, "scraps": 0}, "AC4: Briar-Button take_rivets outcome +14/0")
	_check(briar_rec.get("choices")[2].get("outcome") == {"gold": 0, "scraps": 0}, "AC4: Briar-Button leave outcome 0/0")

	# Independent open_visit on Emberglass:
	var visit_ember := gate.open_visit(ember_id)
	_check(visit_ember != null and visit_ember.is_valid(), "AC4: Emberglass visit opens validly")

	# Preview choices: verify service_request is {"stop_type": "Campfire"} only for service choice:
	var preview_ember := visit_ember.preview_choices({"gold": 10, "scraps": 2})
	_check(preview_ember.get("ok") == true, "AC4: Emberglass preview_choices ok")
	for ch in preview_ember.get("choices", []):
		var cid: String = ch.get("choice_id", "")
		if cid == "light_the_embers":
			_check(ch.get("service_request") == {"stop_type": "Campfire"},
				"AC4: Emberglass paid choice previews {stop_type: Campfire}")
		else:
			_check(ch.get("service_request") == {},
				"AC4: Emberglass non-paid choice previews empty service_request")

	# Claim paid choice:
	var claim_paid := visit_ember.choose_with_wallet("light_the_embers", {"gold": 10, "scraps": 2})
	_check(claim_paid.get("ok") == true, "AC4: Paid service choice claim succeeds")
	_check(claim_paid.get("service_request") == {"stop_type": "Campfire"},
		"AC4: Paid service receipt returns {stop_type: Campfire}")
	_check(claim_paid.get("wallet") == {"gold": 10, "scraps": 1},
		"AC4: Paid service receipt settles toll")

	# One-claim latch on visit:
	_check(visit_ember.is_claimed() == true, "AC4: Visit is latched as claimed")
	_check(not visit_ember.is_valid(), "AC4: Claimed visit is no longer valid for decisions")
	var dup_claim := visit_ember.choose_with_wallet("light_the_embers", {"gold": 10, "scraps": 1})
	_check(dup_claim.get("ok") == false, "AC4: Claimed visit rejects duplicate claim")

	# Independent open_visit on Briar-Button: alternative trade choice returns empty service_request:
	var visit_briar := gate.open_visit(briar_id)
	_check(visit_briar != null and visit_briar.is_valid(), "AC4: Briar visit opens validly")
	var claim_trade := visit_briar.choose_with_wallet("take_rivets", {"gold": 5, "scraps": 3})
	_check(claim_trade.get("ok") == true, "AC4: Alternative trade choice claim succeeds")
	_check(claim_trade.get("service_request") == {},
		"AC4: Alternative trade choice returns empty service_request")
	_check(claim_trade.get("wallet") == {"gold": 19, "scraps": 3},
		"AC4: Alternative trade choice settles wallet (+14 gold)")
	_check(visit_briar.is_claimed() == true, "AC4: Briar visit latched after trade")

	# Independent open_visit for Leave: Leave choice returns empty service_request:
	var visit_leave := gate.open_visit(ember_id)
	var claim_leave := visit_leave.choose_with_wallet("leave", {"gold": 5, "scraps": 3})
	_check(claim_leave.get("ok") == true, "AC4: Leave choice succeeds")
	_check(claim_leave.get("service_request") == {},
		"AC4: Leave choice returns empty service_request")
	_check(claim_leave.get("wallet") == {"gold": 5, "scraps": 3},
		"AC4: Leave choice has 0 wallet delta")
	_check(visit_leave.is_claimed() == true, "AC4: Visit latched after Leave")

	# Compatibility with existing methods:
	var rng_compat := _make_rng(401)
	var res_generic := gate.select_event(rng_compat, null)
	_check(res_generic.get("ok") == true, "AC4: select_event remains functional")
	var res_aff_campfire := gate.select_affordable_service_event(
		rng_compat, null, {"gold": 10, "scraps": 2}, "Campfire"
	)
	_check(res_aff_campfire.get("ok") == true, "AC4: select_affordable_service_event remains functional")
