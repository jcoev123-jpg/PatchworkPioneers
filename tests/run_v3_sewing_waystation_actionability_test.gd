extends SceneTree
## Deterministic regression suite for RunV3ServiceWaystationEventGate.select_actionable_sewing_event (V3-4).
## Exercises AC1 (actionable offers only), AC2 (toll vs stitch economics boundaries),
## AC3 (useless offers refusal, state preservation, ledger validation),
## and AC4 (repeatability, one-draw RNG, isolation, compatibility).

var failures: Array[String] = []
var checks: int = 0


func _init() -> void:
	_test_ac1_actionable_sewing_offers()
	_test_ac2_toll_versus_stitch_economics_boundaries()
	_test_ac3_refusal_state_preservation_and_ledger_validation()
	_test_ac4_stable_authentic_selection_and_compatibility()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("run_v3_sewing_waystation_actionability_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _make_rng(seed_val: int = 12345) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng


# AC1: Only actionable paid Sewing Circle offers (upgradeable deck or cross-hero stitchable deck).
func _test_ac1_actionable_sewing_offers() -> void:
	var gate := RunV3ServiceWaystationEventGate.new()
	_check(gate.is_catalog_valid(), "AC1: Catalog is valid")

	var threadmill_id := "v3_threadmill_sewing_circle"
	var moonlace_id := "v3_moonlace_darning_parlor"

	# Fixture 1: Upgradeable deck (e.g. starter cards that have authored plus cards).
	# Free upgrades need 0 scraps post-toll.
	var upgradeable_deck := ["warden_strike", "tinker_tune_up"]
	var empty_descriptors: Dictionary = {}
	var cursor := 1
	var upgrade_wallet := {"gold": 25, "scraps": 5}

	# Both Threadmill and Moonlace are actionable. Exclude Moonlace to verify Threadmill.
	var rng1 := _make_rng(101)
	var res_threadmill := gate.select_actionable_sewing_event(
		rng1, [moonlace_id], upgrade_wallet, upgradeable_deck, empty_descriptors, cursor
	)
	_check(res_threadmill.get("ok") == true, "AC1: Threadmill selected for upgradeable deck")
	_check(res_threadmill.get("event", {}).get("id") == threadmill_id, "AC1: Correct Threadmill ID returned")
	_check(res_threadmill.get("event", {}).get("service_kind") == "SewingCircle", "AC1: Service kind is SewingCircle")

	# Exclude Threadmill to verify Moonlace.
	var rng2 := _make_rng(102)
	var res_moonlace := gate.select_actionable_sewing_event(
		rng2, [threadmill_id], upgrade_wallet, upgradeable_deck, empty_descriptors, cursor
	)
	_check(res_moonlace.get("ok") == true, "AC1: Moonlace selected for upgradeable deck")
	_check(res_moonlace.get("event", {}).get("id") == moonlace_id, "AC1: Correct Moonlace ID returned")
	_check(res_moonlace.get("event", {}).get("service_kind") == "SewingCircle", "AC1: Moonlace service kind is SewingCircle")

	# Non-SewingCircle events are never returned by select_actionable_sewing_event.
	var rng3 := _make_rng(103)
	var res_both := gate.select_actionable_sewing_event(
		rng3, null, upgrade_wallet, upgradeable_deck, empty_descriptors, cursor
	)
	_check(res_both.get("ok") == true, "AC1: One sewing circle event selected")
	var selected_id: String = res_both.get("event", {}).get("id", "")
	_check(selected_id == threadmill_id or selected_id == moonlace_id, "AC1: Only authentic SewingCircle event returned")

	# Fixture 2: Upgrade-exhausted cross-hero deck with enough scraps to stitch.
	# warden_strike_plus (Warden) and tinker_tune_up_plus (Tinker) cannot be upgraded,
	# but can be stitched together if post-toll scraps >= 3.
	var stitch_only_deck := ["warden_strike_plus", "tinker_tune_up_plus"]
	# Funded wallet: 12 gold (covers Threadmill fee), 5 scraps (covers Moonlace 2-scrap fee + 3-scrap stitch)
	var funded_stitch_wallet := {"gold": 12, "scraps": 5}

	var rng4 := _make_rng(104)
	var res_stitch_threadmill := gate.select_actionable_sewing_event(
		rng4, [moonlace_id], funded_stitch_wallet, stitch_only_deck, empty_descriptors, cursor
	)
	_check(res_stitch_threadmill.get("ok") == true, "AC1: Threadmill selected for stitch-only deck with funded wallet")
	_check(res_stitch_threadmill.get("event", {}).get("id") == threadmill_id, "AC1: Threadmill ID for stitch-only deck")

	var rng5 := _make_rng(105)
	var res_stitch_moonlace := gate.select_actionable_sewing_event(
		rng5, [threadmill_id], funded_stitch_wallet, stitch_only_deck, empty_descriptors, cursor
	)
	_check(res_stitch_moonlace.get("ok") == true, "AC1: Moonlace selected for stitch-only deck with funded wallet")
	_check(res_stitch_moonlace.get("event", {}).get("id") == moonlace_id, "AC1: Moonlace ID for stitch-only deck")


# AC2: Correct toll-versus-stitch economics:
# Threadmill costs 12 gold, 0 scraps; Moonlace costs 0 gold, 2 scraps.
# Stitching costs 3 scraps after toll; free upgrade needs no additional scraps.
# Boundaries: Threadmill gold 11/12, Moonlace scraps 1/2 for upgrade;
# Moonlace scraps 4/5 for stitch-only, Threadmill scraps 2/3 for stitch-only.
func _test_ac2_toll_versus_stitch_economics_boundaries() -> void:
	var gate := RunV3ServiceWaystationEventGate.new()
	var threadmill_id := "v3_threadmill_sewing_circle"
	var moonlace_id := "v3_moonlace_darning_parlor"

	var upgradeable_deck := ["warden_strike"]
	var stitch_only_deck := ["warden_strike_plus", "tinker_tune_up_plus"]
	var empty_desc: Dictionary = {}
	var cursor := 1

	# Boundary 1: Threadmill gold 11 vs 12 for upgrade (needs 0 scraps).
	# At gold 11: cannot pay 12 gold toll -> fails.
	var rng := _make_rng(201)
	var res_tm_11 := gate.select_actionable_sewing_event(
		rng, [moonlace_id], {"gold": 11, "scraps": 0}, upgradeable_deck, empty_desc, cursor
	)
	_check(res_tm_11 == {"ok": false, "event": {}}, "AC2: Threadmill gold 11 fails toll")

	# At gold 12: pays 12 gold toll, post-toll scraps = 0 -> upgrade available.
	var res_tm_12 := gate.select_actionable_sewing_event(
		rng, [moonlace_id], {"gold": 12, "scraps": 0}, upgradeable_deck, empty_desc, cursor
	)
	_check(res_tm_12.get("ok") == true and res_tm_12["event"].get("id") == threadmill_id,
		"AC2: Threadmill gold 12 pays toll and offers upgrade")
	# Inspect throwaway visit quote directly: post-toll scraps = 0
	var visit_tm_0 := RunSewingCircleVisit.new(threadmill_id, upgradeable_deck, empty_desc, 0, cursor)
	_check(visit_tm_0.quote().get("choices", []).has("upgrade"), "AC2: Visit quote has upgrade at 0 post-toll scraps")
	_check(not visit_tm_0.quote().get("choices", []).has("stitch"), "AC2: Visit quote has no stitch at 0 post-toll scraps")

	# Boundary 2: Moonlace scraps 1 vs 2 for upgrade.
	# At scraps 1: cannot pay 2 scraps toll -> fails.
	var res_ml_1 := gate.select_actionable_sewing_event(
		rng, [threadmill_id], {"gold": 0, "scraps": 1}, upgradeable_deck, empty_desc, cursor
	)
	_check(res_ml_1 == {"ok": false, "event": {}}, "AC2: Moonlace scraps 1 fails toll")

	# At scraps 2: pays 2 scraps toll, post-toll scraps = 0 -> upgrade available.
	var res_ml_2 := gate.select_actionable_sewing_event(
		rng, [threadmill_id], {"gold": 0, "scraps": 2}, upgradeable_deck, empty_desc, cursor
	)
	_check(res_ml_2.get("ok") == true and res_ml_2["event"].get("id") == moonlace_id,
		"AC2: Moonlace scraps 2 pays toll and offers upgrade")
	var visit_ml_0 := RunSewingCircleVisit.new(moonlace_id, upgradeable_deck, empty_desc, 0, cursor)
	_check(visit_ml_0.quote().get("choices", []).has("upgrade"), "AC2: Moonlace visit quote has upgrade at 0 post-toll scraps")

	# Boundary 3: Moonlace scraps 4 vs 5 for stitch-only (toll 2 scraps, stitch 3 scraps -> total 5 scraps).
	# At scraps 4: post-toll scraps = 4 - 2 = 2 (< 3) -> stitch cannot be afforded.
	var res_ml_4 := gate.select_actionable_sewing_event(
		rng, [threadmill_id], {"gold": 0, "scraps": 4}, stitch_only_deck, empty_desc, cursor
	)
	_check(res_ml_4 == {"ok": false, "event": {}}, "AC2: Moonlace scraps 4 fails post-toll stitch cost")
	var visit_ml_post2 := RunSewingCircleVisit.new(moonlace_id, stitch_only_deck, empty_desc, 2, cursor)
	_check(visit_ml_post2.quote().get("choices") == ["leave"], "AC2: Visit quote with 2 post-toll scraps is leave-only")

	# At scraps 5: post-toll scraps = 5 - 2 = 3 (>= 3) -> stitch available.
	var res_ml_5 := gate.select_actionable_sewing_event(
		rng, [threadmill_id], {"gold": 0, "scraps": 5}, stitch_only_deck, empty_desc, cursor
	)
	_check(res_ml_5.get("ok") == true and res_ml_5["event"].get("id") == moonlace_id,
		"AC2: Moonlace scraps 5 succeeds for stitch-only")
	var visit_ml_post3 := RunSewingCircleVisit.new(moonlace_id, stitch_only_deck, empty_desc, 3, cursor)
	_check(visit_ml_post3.quote().get("choices", []).has("stitch"), "AC2: Visit quote with 3 post-toll scraps offers stitch")

	# Boundary 4: Threadmill scraps 2 vs 3 for stitch-only (toll 0 scraps, stitch 3 scraps; gold 12).
	# At scraps 2: post-toll scraps = 2 (< 3) -> stitch cannot be afforded.
	var res_tm_s2 := gate.select_actionable_sewing_event(
		rng, [moonlace_id], {"gold": 12, "scraps": 2}, stitch_only_deck, empty_desc, cursor
	)
	_check(res_tm_s2 == {"ok": false, "event": {}}, "AC2: Threadmill scraps 2 fails post-toll stitch cost")
	var visit_tm_post2 := RunSewingCircleVisit.new(threadmill_id, stitch_only_deck, empty_desc, 2, cursor)
	_check(visit_tm_post2.quote().get("choices") == ["leave"], "AC2: Threadmill visit quote with 2 scraps is leave-only")

	# At scraps 3: post-toll scraps = 3 (>= 3) -> stitch available.
	var res_tm_s3 := gate.select_actionable_sewing_event(
		rng, [moonlace_id], {"gold": 12, "scraps": 3}, stitch_only_deck, empty_desc, cursor
	)
	_check(res_tm_s3.get("ok") == true and res_tm_s3["event"].get("id") == threadmill_id,
		"AC2: Threadmill scraps 3 succeeds for stitch-only")
	var visit_tm_post3 := RunSewingCircleVisit.new(threadmill_id, stitch_only_deck, empty_desc, 3, cursor)
	_check(visit_tm_post3.quote().get("choices", []).has("stitch"), "AC2: Threadmill visit quote with 3 scraps offers stitch")


# AC3: Refuse useless offers without RNG/state drift:
# no upgradeable cards, no cross-owner pair, insufficient scraps, invalid deck/ledger,
# forged/stale descriptors, exclusions of each real waystation ID, invalid wallet/RNG.
func _test_ac3_refusal_state_preservation_and_ledger_validation() -> void:
	var gate := RunV3ServiceWaystationEventGate.new()
	var threadmill_id := "v3_threadmill_sewing_circle"
	var moonlace_id := "v3_moonlace_darning_parlor"

	# Case 1: Already-upgraded single-owner deck (no upgrades, no cross-owner stitch pair).
	var single_owner_exhausted_deck := ["warden_strike_plus", "warden_brace_plus"]
	var funded_wallet := {"gold": 50, "scraps": 20}
	var rng_probe := _make_rng(301)
	var rng_control := _make_rng(301)

	var res_exhausted := gate.select_actionable_sewing_event(
		rng_probe, null, funded_wallet, single_owner_exhausted_deck, {}, 1
	)
	_check(res_exhausted == {"ok": false, "event": {}}, "AC3: Refuses offer for exhausted single-owner deck")
	_check(rng_probe.randi() == rng_control.randi(), "AC3: RNG state preserved on exhausted deck refusal")

	# Case 2: State preservation: caller wallet, deck, descriptors, cursor untouched.
	var caller_wallet := {"gold": 50, "scraps": 20}
	var caller_deck := ["warden_strike_plus", "warden_brace_plus"]
	var caller_desc: Dictionary = {}
	var caller_cursor := 1
	var wallet_before := caller_wallet.duplicate(true)
	var deck_before := caller_deck.duplicate(true)
	var desc_before := caller_desc.duplicate(true)

	var res_drift := gate.select_actionable_sewing_event(
		rng_probe, null, caller_wallet, caller_deck, caller_desc, caller_cursor
	)
	_check(res_drift == {"ok": false, "event": {}}, "AC3: Refusal returns ok: false")
	_check(caller_wallet == wallet_before, "AC3: Caller wallet unmodified")
	_check(caller_deck == deck_before, "AC3: Caller deck unmodified")
	_check(caller_desc == desc_before, "AC3: Caller descriptors unmodified")
	_check(caller_cursor == 1, "AC3: Caller cursor unmodified")

	# Case 3: Dictionary snapshot format accepted and preserved.
	var caller_snapshot := {
		"deck": caller_deck.duplicate(true),
		"descriptors": caller_desc.duplicate(true),
		"next_stitch_id": caller_cursor,
	}
	var snap_before := caller_snapshot.duplicate(true)
	var res_snap := gate.select_actionable_sewing_event(rng_probe, null, caller_wallet, caller_snapshot)
	_check(res_snap == {"ok": false, "event": {}}, "AC3: Snapshot dict refusal returns ok: false")
	_check(caller_snapshot == snap_before, "AC3: Caller snapshot dictionary unmodified")

	# Case 4: Invalid deck inputs:
	# Empty deck
	_check(gate.select_actionable_sewing_event(rng_probe, null, funded_wallet, [], {}, 1) == {"ok": false, "event": {}},
		"AC3: Empty deck rejected")
	# Deck with non-string
	_check(gate.select_actionable_sewing_event(rng_probe, null, funded_wallet, [123], {}, 1) == {"ok": false, "event": {}},
		"AC3: Deck with non-string rejected")
	# Deck with counterfeit/unknown card ID
	_check(gate.select_actionable_sewing_event(rng_probe, null, funded_wallet, ["counterfeit_card"], {}, 1) == {"ok": false, "event": {}},
		"AC3: Counterfeit card ID rejected")

	# Case 5: Forged descriptors:
	# Stitched card with same-owner halves
	var warden_def: Dictionary = StarterCards.new().get_definition("warden_strike")
	var warden_brace_def: Dictionary = StarterCards.new().get_definition("warden_brace")
	var same_owner_desc := RunRestStitchCards._make_descriptor("stitched_000001", warden_def, warden_brace_def)
	var forged_same_owner_registry := {"stitched_000001": same_owner_desc}
	var deck_with_stitched := ["stitched_000001", "tinker_tune_up"]
	_check(gate.select_actionable_sewing_event(rng_probe, null, funded_wallet, deck_with_stitched, forged_same_owner_registry, 2) == {"ok": false, "event": {}},
		"AC3: Forged same-owner descriptor rejected")

	# Descriptor serial >= next_stitch_id
	var tinker_def: Dictionary = StarterCards.new().get_definition("tinker_tune_up")
	var valid_desc := RunRestStitchCards._make_descriptor("stitched_000001", warden_def, tinker_def)
	var registry_serial_too_high := {"stitched_000001": valid_desc}
	_check(gate.select_actionable_sewing_event(rng_probe, null, funded_wallet, deck_with_stitched, registry_serial_too_high, 1) == {"ok": false, "event": {}},
		"AC3: Descriptor serial >= cursor rejected")

	# Case 6: Stale descriptor: present in registry but missing from deck.
	var stale_registry := {"stitched_000001": valid_desc}
	var plain_deck := ["warden_strike", "tinker_tune_up"]
	_check(gate.select_actionable_sewing_event(rng_probe, null, funded_wallet, plain_deck, stale_registry, 2) == {"ok": false, "event": {}},
		"AC3: Stale descriptor missing from deck rejected")

	# Stitched card in deck twice
	var dup_stitched_deck := ["stitched_000001", "stitched_000001"]
	_check(gate.select_actionable_sewing_event(rng_probe, null, funded_wallet, dup_stitched_deck, stale_registry, 2) == {"ok": false, "event": {}},
		"AC3: Stitched card duplicated in deck rejected")

	# Case 7: Invalid cursor values
	_check(gate.select_actionable_sewing_event(rng_probe, null, funded_wallet, plain_deck, {}, 0) == {"ok": false, "event": {}},
		"AC3: Cursor 0 rejected")
	_check(gate.select_actionable_sewing_event(rng_probe, null, funded_wallet, plain_deck, {}, -1) == {"ok": false, "event": {}},
		"AC3: Negative cursor rejected")
	_check(gate.select_actionable_sewing_event(rng_probe, null, funded_wallet, plain_deck, {}, "invalid") == {"ok": false, "event": {}},
		"AC3: String cursor rejected")

	# Case 8: Exclusions of each real waystation ID
	for ex_id: String in RunV3ServiceWaystationEventGate.REQUIRED_EVENT_IDS:
		var res_ex := gate.select_actionable_sewing_event(rng_probe, [ex_id], funded_wallet, plain_deck, {}, 1)
		if ex_id == threadmill_id or ex_id == moonlace_id:
			_check(res_ex.get("ok") == true, "AC3: Excluding one sewing event still permits the other")
			_check(res_ex.get("event", {}).get("id") != ex_id, "AC3: Excluded sewing event not returned")
		else:
			_check(res_ex.get("ok") == true, "AC3: Excluding non-sewing waystation permits sewing circle selection")

	# Exclude both Sewing Circle events
	var res_both_ex := gate.select_actionable_sewing_event(
		rng_probe, [threadmill_id, moonlace_id], funded_wallet, plain_deck, {}, 1
	)
	_check(res_both_ex == {"ok": false, "event": {}}, "AC3: Excluding both sewing waystations rejects")

	# Invalid exclusions
	_check(gate.select_actionable_sewing_event(rng_probe, "not_an_array", funded_wallet, plain_deck, {}, 1) == {"ok": false, "event": {}},
		"AC3: Non-array exclusions rejected")
	_check(gate.select_actionable_sewing_event(rng_probe, [123], funded_wallet, plain_deck, {}, 1) == {"ok": false, "event": {}},
		"AC3: Non-string exclusions item rejected")
	_check(gate.select_actionable_sewing_event(rng_probe, [""], funded_wallet, plain_deck, {}, 1) == {"ok": false, "event": {}},
		"AC3: Empty-string exclusions item rejected")

	# Case 9: Invalid wallets
	_check(gate.select_actionable_sewing_event(rng_probe, null, null, plain_deck, {}, 1) == {"ok": false, "event": {}},
		"AC3: Null wallet rejected")
	_check(gate.select_actionable_sewing_event(rng_probe, null, {"gold": 10}, plain_deck, {}, 1) == {"ok": false, "event": {}},
		"AC3: Wallet missing scraps rejected")
	_check(gate.select_actionable_sewing_event(rng_probe, null, {"gold": -1, "scraps": 5}, plain_deck, {}, 1) == {"ok": false, "event": {}},
		"AC3: Negative gold wallet rejected")
	_check(gate.select_actionable_sewing_event(rng_probe, null, {"gold": 10, "scraps": -1}, plain_deck, {}, 1) == {"ok": false, "event": {}},
		"AC3: Negative scraps wallet rejected")
	_check(gate.select_actionable_sewing_event(rng_probe, null, {"gold": 10.5, "scraps": 5}, plain_deck, {}, 1) == {"ok": false, "event": {}},
		"AC3: Float wallet rejected")
	_check(gate.select_actionable_sewing_event(rng_probe, null, {"gold": 10, "scraps": 5, "extra": 1}, plain_deck, {}, 1) == {"ok": false, "event": {}},
		"AC3: 3-key wallet rejected")

	# Case 10: Invalid RNG
	_check(gate.select_actionable_sewing_event(null, null, funded_wallet, plain_deck, {}, 1) == {"ok": false, "event": {}},
		"AC3: Null RNG rejected")
	_check(gate.select_actionable_sewing_event("not_rng", null, funded_wallet, plain_deck, {}, 1) == {"ok": false, "event": {}},
		"AC3: String RNG rejected")
	_check(gate.select_actionable_sewing_event(999, null, funded_wallet, plain_deck, {}, 1) == {"ok": false, "event": {}},
		"AC3: Int RNG rejected")


# AC4: Stable authentic selection and compatibility:
# equal seeds and input snapshots sort eligible authentic IDs and draw once;
# deep-detached original catalog record without synthetic modifications;
# preserves existing select_event(), select_affordable_service_event(), and non-sewing choices.
func _test_ac4_stable_authentic_selection_and_compatibility() -> void:
	var gate := RunV3ServiceWaystationEventGate.new()
	var threadmill_id := "v3_threadmill_sewing_circle"
	var moonlace_id := "v3_moonlace_darning_parlor"

	var deck := ["warden_strike", "tinker_tune_up"]
	var wallet := {"gold": 25, "scraps": 10}

	# 1. Repeatability on equal seeds
	for test_seed: int in [42, 999, 12345, 777777]:
		var rng_a := _make_rng(test_seed)
		var rng_b := _make_rng(test_seed)
		var res_a := gate.select_actionable_sewing_event(rng_a, null, wallet, deck, {}, 1)
		var res_b := gate.select_actionable_sewing_event(rng_b, null, wallet, deck, {}, 1)
		_check(res_a.get("ok") == true and res_b.get("ok") == true, "AC4: Repeatable run succeeded")
		_check(res_a.get("event", {}).get("id") == res_b.get("event", {}).get("id"),
			"AC4: Identical event picked on identical seed " + str(test_seed))
		_check(rng_a.randi() == rng_b.randi(), "AC4: Identical RNG progression on seed " + str(test_seed))

	# 2. Exactly one randi_range draw on success
	var seed_val := 8888
	var rng_actual := _make_rng(seed_val)
	var rng_shadow := _make_rng(seed_val)
	# Pre-determine which event shadow expects:
	# eligible has 2 events, sorted: ["v3_moonlace_darning_parlor", "v3_threadmill_sewing_circle"]
	var shadow_draw := rng_shadow.randi_range(0, 1)
	var expected_id: String = moonlace_id if shadow_draw == 0 else threadmill_id

	var actual_res := gate.select_actionable_sewing_event(rng_actual, null, wallet, deck, {}, 1)
	_check(actual_res.get("ok") == true, "AC4: Draw check selection succeeded")
	_check(actual_res.get("event", {}).get("id") == expected_id, "AC4: Selected ID matches single shadow draw")
	_check(rng_actual.randi() == rng_shadow.randi(), "AC4: Exactly one RNG draw consumed by successful selection")

	# 3. Deep-copy isolation: mutating returned event record does not affect catalog or subsequent queries
	var res_isolate := gate.select_actionable_sewing_event(rng_actual, null, wallet, deck, {}, 1)
	_check(res_isolate.get("ok") == true, "AC4: Isolation test selection succeeded")
	var event_record: Dictionary = res_isolate["event"]
	var orig_title: String = event_record.get("title", "")
	event_record["title"] = "Corrupted Title"
	event_record["choices"] = []
	event_record["service_kind"] = "CounterfeitKind"

	var clean_record: Dictionary = gate.get_event_record(event_record.get("id"))
	_check(clean_record.get("title") == orig_title, "AC4: get_event_record title untouched by mutation")
	_check(clean_record.get("service_kind") == "SewingCircle", "AC4: get_event_record service_kind untouched")
	_check((clean_record.get("choices") as Array).size() == 3, "AC4: get_event_record choices untouched")

	# 4. Catalog rejection on invalid catalog data
	var invalid_catalog := {
		"events": [
			# Missing required waystation v3_threadmill_sewing_circle
			{
				"id": "v3_emberglass_campfire",
				"title": "The Emberglass Hearth",
				"description": "Test",
				"service_choice_id": "light_the_embers",
				"service_kind": "Campfire",
				"choices": [
					{"id": "light_the_embers", "text": "Light", "outcome": {"gold": 0, "scraps": -1}},
					{"id": "sell_cinders", "text": "Sell", "outcome": {"gold": 12, "scraps": 0}},
					{"id": "leave", "text": "Leave", "outcome": {"gold": 0, "scraps": 0}},
				]
			}
		]
	}
	var invalid_gate := RunV3ServiceWaystationEventGate.new("__omitted_event_target__", invalid_catalog)
	_check(not invalid_gate.is_catalog_valid(), "AC4: Missing required waystation makes catalog invalid")
	var res_inv := invalid_gate.select_actionable_sewing_event(rng_actual, null, wallet, deck, {}, 1)
	_check(res_inv == {"ok": false, "event": {}}, "AC4: Invalid catalog rejects select_actionable_sewing_event")

	# 5. Preservation of old generic and affordable-only selectors
	var gen_rng := _make_rng(501)
	var res_generic := gate.select_event(gen_rng)
	_check(res_generic.get("ok") == true, "AC4: select_event() remains functional")
	_check(RunV3ServiceWaystationEventGate.REQUIRED_EVENT_IDS.has(res_generic.get("event", {}).get("id")),
		"AC4: select_event() returns canonical waystation")

	var aff_rng := _make_rng(502)
	var res_aff_sewing := gate.select_affordable_service_event(aff_rng, null, wallet, "SewingCircle")
	_check(res_aff_sewing.get("ok") == true, "AC4: select_affordable_service_event() remains functional for SewingCircle")
	_check(res_aff_sewing.get("event", {}).get("service_kind") == "SewingCircle", "AC4: Kind matches")

	var res_aff_campfire := gate.select_affordable_service_event(aff_rng, null, wallet, "Campfire")
	_check(res_aff_campfire.get("ok") == true, "AC4: select_affordable_service_event() remains functional for Campfire")
	_check(res_aff_campfire.get("event", {}).get("service_kind") == "Campfire", "AC4: Campfire service kind matches")

	var res_aff_unpicker := gate.select_affordable_service_event(aff_rng, null, wallet, "Unpicker")
	_check(res_aff_unpicker.get("ok") == true, "AC4: select_affordable_service_event() remains functional for Unpicker")
	_check(res_aff_unpicker.get("event", {}).get("service_kind") == "Unpicker", "AC4: Unpicker service kind matches")
