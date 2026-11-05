extends SceneTree
## Deterministic regression suite for RunV3HeroVitalEventGate.select_party_actionable_event (V3-4).
## Exercises AC1 (party/living eligibility), AC2 (affordability/floors), AC3 (sorting/seeded draw/purity),
## and AC4 (authentic handoff to gate.enter/settlement).

const CATALOG_PATH := "res://data/events/v3_hero_vital_events.json"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_ac1_party_and_living_eligibility()
	_test_ac2_affordability_and_vital_floors()
	_test_ac3_seeded_uniformity_purity_and_detachment()
	_test_ac4_gate_enter_preview_and_claim_handoff()
	_test_ac5_rivet_choir_full_health_paid_heal_suppression()
	_test_four_hero_stitched_party()
	_test_direct_bound_visit_full_health_paid_heal_suppression()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("run_v3_hero_vital_actionable_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _hero(id: String, hp: int = 20, max_hp: int = 30) -> Dictionary:
	return {"id": id, "hp": hp, "max_hp": max_hp}


func _wallet(gold: int = 50, scraps: int = 10) -> Dictionary:
	return {"gold": gold, "scraps": scraps}


## Shared-catalog-safe exclusion helper: every offered record except the named
## keep IDs, so forced-single-eligible witnesses stay deterministic as the
## shipped catalog grows (no hardcoded pool or full ID list).
func _exclude_all_but(gate: RunV3HeroVitalEventGate, keep_ids: Array) -> Array:
	var excluded: Array = []
	for offer: Dictionary in gate.get_offers():
		var oid: String = offer.get("id", "")
		if not keep_ids.has(oid):
			excluded.append(oid)
	return excluded


# AC1: Only authenticated party-owned hero events with matching living required hero are eligible.
func _test_ac1_party_and_living_eligibility() -> void:
	var party_ids := ["warden", "scarecrow", "tinker"]
	var gate := RunV3HeroVitalEventGate.new(party_ids)
	_check(gate.is_valid(), "AC1: 3-hero gate is valid")

	var heroes := [
		_hero("warden", 20, 30),
		_hero("scarecrow", 20, 30),
		_hero("tinker", 20, 30),
	]
	var wallet := _wallet(50, 10)

	var warden_id := "v3_warden_buckle_heart_ward"
	var scarecrow_id := "v3_scarecrow_strawheart_alarm"
	var crowbell_harvest_id := "v3_scarecrow_crowbell_harvest"
	var tinker_greenhouse_id := "v3_tinker_copper_needle_greenhouse"
	var tinker_blunderbuss_id := "v3_tinker_blunderbuss_fuse_well"

	var rng := RandomNumberGenerator.new()
	rng.seed = 101

	# Force Warden by dynamically excluding every other offered record
	var res_warden := gate.select_party_actionable_event(
		rng, _exclude_all_but(gate, [warden_id]), wallet, heroes
	)
	_check(res_warden.get("ok") == true and res_warden["event"].get("id") == warden_id,
		"AC1: forced Warden record returned")

	# Force Scarecrow by dynamically excluding every other offered record
	var res_scarecrow := gate.select_party_actionable_event(
		rng, _exclude_all_but(gate, [scarecrow_id]), wallet, heroes
	)
	_check(res_scarecrow.get("ok") == true and res_scarecrow["event"].get("id") == scarecrow_id,
		"AC1: forced Scarecrow record returned")

	# Force Tinker greenhouse by dynamically excluding every other offered record
	var res_tinker1 := gate.select_party_actionable_event(
		rng, _exclude_all_but(gate, [tinker_greenhouse_id]), wallet, heroes
	)
	_check(res_tinker1.get("ok") == true and res_tinker1["event"].get("id") == tinker_greenhouse_id,
		"AC1: forced Tinker greenhouse record returned")

	# Force Tinker blunderbuss by dynamically excluding every other offered record
	var res_tinker2 := gate.select_party_actionable_event(
		rng, _exclude_all_but(gate, [tinker_blunderbuss_id]), wallet, heroes
	)
	_check(res_tinker2.get("ok") == true and res_tinker2["event"].get("id") == tinker_blunderbuss_id,
		"AC1: forced Tinker blunderbuss record returned")

	# Absent heroes refusal: dynamically exclude every offered party record; un-offered absent heroes (e.g. Seamstress) cannot be returned
	var res_absent := gate.select_party_actionable_event(
		rng, _exclude_all_but(gate, []), wallet, heroes
	)
	_check(res_absent.get("ok") == false and res_absent.get("event") == {},
		"AC1: absent heroes can never be returned; exhausted party records reject")

	# Present-but-Torn hero refusal (Scarecrow hp == 0)
	var torn_scarecrow_heroes := [
		_hero("warden", 20, 30),
		_hero("scarecrow", 0, 30), # Torn!
		_hero("tinker", 20, 30),
	]
	var res_torn_scarecrow := gate.select_party_actionable_event(
		rng, _exclude_all_but(gate, [scarecrow_id]), wallet, torn_scarecrow_heroes
	)
	_check(res_torn_scarecrow.get("ok") == false and res_torn_scarecrow.get("event") == {},
		"AC1: present-but-Torn Scarecrow cannot be returned")

	# Present-but-Torn hero refusal (Tinker hp == 0: neither Tinker story can be returned)
	var torn_tinker_heroes := [
		_hero("warden", 20, 30),
		_hero("scarecrow", 20, 30),
		_hero("tinker", 0, 30), # Torn!
	]
	var res_torn_tinker := gate.select_party_actionable_event(
		rng, _exclude_all_but(gate, [tinker_greenhouse_id, tinker_blunderbuss_id]), wallet, torn_tinker_heroes
	)
	_check(res_torn_tinker.get("ok") == false and res_torn_tinker.get("event") == {},
		"AC1: present-but-Torn Tinker refuses both Tinker stories")


# AC2: At least one non-Leave choice is affordable under existing preview; Leave-only cannot admit.
func _test_ac2_affordability_and_vital_floors() -> void:
	var party_ids := ["warden", "seamstress", "tinker"]
	var gate := RunV3HeroVitalEventGate.new(party_ids)
	_check(gate.is_valid(), "AC2: Warden/Seamstress/Tinker gate is valid")

	var zero_wallet := _wallet(0, 0)
	var min_heroes := [
		_hero("warden", 1, 10),
		_hero("seamstress", 1, 10),
		_hero("tinker", 1, 10),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 202

	# Rich party test: funded wallet and healthy heroes admit selection
	var rich_wallet := _wallet(100, 20)
	var rich_heroes := [
		_hero("warden", 20, 30),
		_hero("seamstress", 20, 30),
		_hero("tinker", 20, 30),
	]
	var rich_res := gate.select_party_actionable_event(rng, null, rich_wallet, rich_heroes)
	_check(rich_res.get("ok") == true and not rich_res["event"].is_empty(),
		"AC2: rich party selects an actionable event")

	# Zero-wallet, HP 1, max HP 10: all visits are Leave-only, selection refuses
	var zero_res := gate.select_party_actionable_event(rng, null, zero_wallet, min_heroes)
	_check(zero_res.get("ok") == false and zero_res.get("event") == {},
		"AC2: 0 gold, 0 scraps, HP 1/max 10 makes all events Leave-only; selection refuses")

	# Raise scraps to 2: Warden's reinforce_shield_seam (-2 scraps) becomes affordable
	var warden_id := "v3_warden_buckle_heart_ward"
	var tinker_greenhouse_id := "v3_tinker_copper_needle_greenhouse"
	var tinker_blunderbuss_id := "v3_tinker_blunderbuss_fuse_well"
	var seamstress_id := "v3_seamstress_crimson_quilt_surgeon"

	var scraps_2_wallet := _wallet(0, 2)
	var scraps_res := gate.select_party_actionable_event(
		rng, _exclude_all_but(gate, [warden_id]), scraps_2_wallet, min_heroes
	)
	_check(scraps_res.get("ok") == true and scraps_res["event"].get("id") == warden_id,
		"AC2: Warden becomes actionable when scraps raised to 2")

	# Raise gold to 12: Seamstress's stitch_wound (-12 gold) becomes affordable
	var gold_12_wallet := _wallet(12, 0)
	var seamstress_res := gate.select_party_actionable_event(
		rng, [warden_id, tinker_greenhouse_id, tinker_blunderbuss_id], gold_12_wallet, min_heroes
	)
	_check(seamstress_res.get("ok") == true and seamstress_res["event"].get("id") == seamstress_id,
		"AC2: Seamstress becomes actionable when gold raised to 12")

	# Raise Seamstress HP to 5 (donate_red_thread loses 4 HP, leaving 1 >= 1): affordable without gold
	var seamstress_hp5_heroes := [
		_hero("warden", 1, 10),
		_hero("seamstress", 5, 10),
		_hero("tinker", 1, 10),
	]
	var hp5_res := gate.select_party_actionable_event(
		rng, [warden_id, tinker_greenhouse_id, tinker_blunderbuss_id], zero_wallet, seamstress_hp5_heroes
	)
	_check(hp5_res.get("ok") == true and hp5_res["event"].get("id") == seamstress_id,
		"AC2: Seamstress donate_red_thread becomes actionable at HP 5 (HP floor 1 satisfied)")

	# Seamstress at HP 4: donate_red_thread loses 4 HP, leaving 0 < 1 floor: unaffordable, selection refuses
	var seamstress_hp4_heroes := [
		_hero("warden", 1, 10),
		_hero("seamstress", 4, 10),
		_hero("tinker", 1, 10),
	]
	var hp4_res := gate.select_party_actionable_event(
		rng, [warden_id, tinker_greenhouse_id, tinker_blunderbuss_id], zero_wallet, seamstress_hp4_heroes
	)
	_check(hp4_res.get("ok") == false,
		"AC2: Seamstress donate_red_thread at HP 4 violates HP 1 floor and is refused")

	# Raise Warden max HP to 12 (sell_rivets loses 2 max HP, leaving 10 >= 10 floor): affordable without gold/scraps
	var warden_max12_heroes := [
		_hero("warden", 1, 12),
		_hero("seamstress", 1, 10),
		_hero("tinker", 1, 10),
	]
	var max12_res := gate.select_party_actionable_event(
		rng, _exclude_all_but(gate, [warden_id]), zero_wallet, warden_max12_heroes
	)
	_check(max12_res.get("ok") == true and max12_res["event"].get("id") == warden_id,
		"AC2: Warden sell_rivets becomes actionable at max HP 12 (max HP 10 floor satisfied)")

	# Warden at max HP 11: sell_rivets loses 2 max HP, leaving 9 < 10 floor: unaffordable, selection refuses
	var warden_max11_heroes := [
		_hero("warden", 1, 11),
		_hero("seamstress", 1, 10),
		_hero("tinker", 1, 10),
	]
	var max11_res := gate.select_party_actionable_event(
		rng, _exclude_all_but(gate, [warden_id]), zero_wallet, warden_max11_heroes
	)
	_check(max11_res.get("ok") == false,
		"AC2: Warden sell_rivets at max HP 11 violates max HP 10 floor and is refused")

	# Healing cap and negative wallet checks via production RunEventChoice preview
	var warden_record: Dictionary = {}
	for offer: Dictionary in gate.get_offers():
		if offer.get("id") == warden_id:
			warden_record = offer
			break
	_check(not warden_record.is_empty(), "AC2: Warden record retrieved from gate offers")

	var preview_service := RunEventChoice.new(warden_record)
	# Negative wallet rejection
	var neg_wallet_preview := preview_service.preview_vital_choices({
		"gold": -1, "scraps": 0, "hero": {"id": "warden", "hp": 10, "max_hp": 20}
	})
	_check(neg_wallet_preview.get("ok") == false, "AC2: negative gold rejected by preview")

	var neg_scraps_preview := preview_service.preview_vital_choices({
		"gold": 0, "scraps": -1, "hero": {"id": "warden", "hp": 10, "max_hp": 20}
	})
	_check(neg_scraps_preview.get("ok") == false, "AC2: negative scraps rejected by preview")

	# Healing cap check on seamstress record (+8 HP)
	var seamstress_record: Dictionary = {}
	for offer: Dictionary in gate.get_offers():
		if offer.get("id") == seamstress_id:
			seamstress_record = offer
			break
	var seamstress_service := RunEventChoice.new(seamstress_record)
	var heal_cap_preview := seamstress_service.preview_vital_choices({
		"gold": 50, "scraps": 0, "hero": {"id": "seamstress", "hp": 18, "max_hp": 20}
	})
	_check(heal_cap_preview.get("ok") == true, "AC2: healing preview ok")
	var stitch_choice: Dictionary = {}
	for c: Dictionary in heal_cap_preview.get("choices", []):
		if c.get("choice_id") == "stitch_wound":
			stitch_choice = c
			break
	_check(stitch_choice.get("affordable") == true and stitch_choice["state"]["hero"]["hp"] == 20,
		"AC2: healing caps at max HP (18 + 8 clamped to 20)")


# AC3: Eligible IDs are sorted, exactly one caller-RNG range draw occurs only on success, refused selection is pure.
func _test_ac3_seeded_uniformity_purity_and_detachment() -> void:
	var party_ids := ["warden", "scarecrow", "tinker"]
	var gate := RunV3HeroVitalEventGate.new(party_ids)
	var wallet := _wallet(100, 20)
	var heroes := [
		_hero("warden", 20, 30),
		_hero("scarecrow", 20, 30),
		_hero("tinker", 20, 30),
	]

	# Every offered record is eligible and actionable at this funded wallet;
	# derive and sort the pool dynamically (no hardcoded total or ID list):
	var expected_sorted_ids: Array = []
	for offer: Dictionary in gate.get_offers():
		expected_sorted_ids.append(String(offer.get("id", "")))
	expected_sorted_ids.sort()

	# 1. Compare with separately seeded one-draw oracle
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 777
	var oracle_rng := RandomNumberGenerator.new()
	oracle_rng.seed = 777
	var oracle_index := oracle_rng.randi_range(0, expected_sorted_ids.size() - 1)
	var oracle_id: String = expected_sorted_ids[oracle_index]

	var res1 := gate.select_party_actionable_event(rng1, null, wallet, heroes)
	_check(res1.get("ok") == true, "AC3: selection succeeds")
	_check(res1["event"].get("id") == oracle_id, "AC3: seeded draw matches oracle draw: " + oracle_id)
	_check(rng1.state == oracle_rng.state, "AC3: exactly one randi_range call consumed on success")

	# 2. Seeded replay agreement
	var rng_replay := RandomNumberGenerator.new()
	rng_replay.seed = 777
	var res_replay := gate.select_party_actionable_event(rng_replay, null, wallet, heroes)
	_check(res_replay["event"].get("id") == res1["event"].get("id"), "AC3: seeded replay returns identical event")

	# 3. Order independence of supplied heroes
	var reordered_heroes := [
		_hero("tinker", 20, 30),
		_hero("warden", 20, 30),
		_hero("scarecrow", 20, 30),
	]
	var rng_heroes := RandomNumberGenerator.new()
	rng_heroes.seed = 777
	var res_heroes := gate.select_party_actionable_event(rng_heroes, null, wallet, reordered_heroes)
	_check(res_heroes["event"].get("id") == res1["event"].get("id"),
		"AC3: reordered heroes return identical event with same seed")

	# 4. Catalog order independence: reversed catalog data
	var shipped := RunV3HeroVitalEventGate.load_shipped_catalog()
	var reversed_events: Array = shipped["events"].duplicate(true)
	reversed_events.reverse()
	var reversed_gate := RunV3HeroVitalEventGate.new(party_ids, {"events": reversed_events})
	_check(reversed_gate.is_valid(), "AC3: reversed catalog gate is valid")
	var rng_rev := RandomNumberGenerator.new()
	rng_rev.seed = 777
	var res_rev := reversed_gate.select_party_actionable_event(rng_rev, null, wallet, heroes)
	_check(res_rev["event"].get("id") == res1["event"].get("id"),
		"AC3: reversed catalog order returns identical event with same seed")

	# 5. Exclusion history: suppresses only named IDs, ignores well-formed unknown IDs
	var rng_ex := RandomNumberGenerator.new()
	rng_ex.seed = 888
	var ex_res := gate.select_party_actionable_event(rng_ex, ["v3_warden_buckle_heart_ward", "unknown_bogus_id"], wallet, heroes)
	_check(ex_res.get("ok") == true and ex_res["event"].get("id") != "v3_warden_buckle_heart_ward",
		"AC3: exclusion history suppresses named ID and ignores unknown ID")

	# 6. Refusal purity: no RNG advance and no input mutation on any refusal
	var test_rng := RandomNumberGenerator.new()
	test_rng.seed = 999
	var saved_state := test_rng.state

	var wallet_copy := wallet.duplicate(true)
	var heroes_copy := heroes.duplicate(true)
	var exclusions_input := ["some_id"]
	var exclusions_copy := exclusions_input.duplicate(true)

	# Invalid gate (constructed with invalid party)
	var bad_gate := RunV3HeroVitalEventGate.new(["invalid_hero"])
	_check(not bad_gate.is_valid(), "AC3: invalid party gate is invalid")
	var bad_gate_res := bad_gate.select_party_actionable_event(test_rng, null, wallet, heroes)
	_check(bad_gate_res.get("ok") == false and bad_gate_res.get("event") == {} and test_rng.state == saved_state,
		"AC3: invalid gate does not advance RNG")

	# Bound visit gate cannot select
	var bound_visit := gate.enter("v3_warden_buckle_heart_ward", {"gold": 10, "scraps": 5, "hero": {"id": "warden", "hp": 20, "max_hp": 30}})
	_check(bound_visit != null and bound_visit.is_valid(), "AC3: bound visit opened")
	var bound_res := bound_visit.select_party_actionable_event(test_rng, null, wallet, heroes)
	_check(bound_res.get("ok") == false and test_rng.state == saved_state,
		"AC3: bound visit refuses selector without touching RNG")

	# Invalid RNG
	_check(gate.select_party_actionable_event(null, null, wallet, heroes).get("ok") == false, "AC3: null RNG rejected")
	_check(gate.select_party_actionable_event(12345, null, wallet, heroes).get("ok") == false, "AC3: int RNG rejected")
	_check(gate.select_party_actionable_event("rng", null, wallet, heroes).get("ok") == false, "AC3: string RNG rejected")

	# Mismatched/duplicate hero IDs
	var mismatched_heroes := [_hero("warden"), _hero("seamstress"), _hero("tinker")]
	var mis_res := gate.select_party_actionable_event(test_rng, null, wallet, mismatched_heroes)
	_check(mis_res.get("ok") == false and test_rng.state == saved_state,
		"AC3: mismatched off-party hero rejected without RNG draw")

	var duplicate_heroes := [_hero("warden"), _hero("warden"), _hero("tinker")]
	var dup_res := gate.select_party_actionable_event(test_rng, null, wallet, duplicate_heroes)
	_check(dup_res.get("ok") == false and test_rng.state == saved_state,
		"AC3: duplicate hero ID rejected without RNG draw")

	var wrong_count_heroes := [_hero("warden"), _hero("tinker")]
	_check(gate.select_party_actionable_event(test_rng, null, wallet, wrong_count_heroes).get("ok") == false
		and test_rng.state == saved_state, "AC3: wrong hero count rejected without RNG draw")

	# Malformed snapshots
	_check(gate.select_party_actionable_event(test_rng, null, null, heroes).get("ok") == false and test_rng.state == saved_state,
		"AC3: null wallet rejected without RNG draw")
	_check(gate.select_party_actionable_event(test_rng, null, {"gold": -1, "scraps": 0}, heroes).get("ok") == false
		and test_rng.state == saved_state, "AC3: negative gold rejected without RNG draw")
	_check(gate.select_party_actionable_event(test_rng, null, {"gold": 10}, heroes).get("ok") == false
		and test_rng.state == saved_state, "AC3: missing scraps rejected without RNG draw")
	_check(gate.select_party_actionable_event(test_rng, null, {"gold": 10, "scraps": 0, "extra": 1}, heroes).get("ok") == false
		and test_rng.state == saved_state, "AC3: extra wallet keys rejected without RNG draw")

	_check(gate.select_party_actionable_event(test_rng, null, wallet, null).get("ok") == false and test_rng.state == saved_state,
		"AC3: null heroes rejected without RNG draw")
	var hp_neg := [_hero("warden", -1, 30), _hero("scarecrow"), _hero("tinker")]
	_check(gate.select_party_actionable_event(test_rng, null, wallet, hp_neg).get("ok") == false and test_rng.state == saved_state,
		"AC3: negative HP rejected without RNG draw")
	var hp_over_max := [_hero("warden", 31, 30), _hero("scarecrow"), _hero("tinker")]
	_check(gate.select_party_actionable_event(test_rng, null, wallet, hp_over_max).get("ok") == false and test_rng.state == saved_state,
		"AC3: HP > max_hp rejected without RNG draw")
	var max_below_floor := [_hero("warden", 5, 9), _hero("scarecrow"), _hero("tinker")]
	_check(gate.select_party_actionable_event(test_rng, null, wallet, max_below_floor).get("ok") == false and test_rng.state == saved_state,
		"AC3: max_hp < 10 rejected without RNG draw")

	# Non-string / blank exclusions
	_check(gate.select_party_actionable_event(test_rng, [123], wallet, heroes).get("ok") == false and test_rng.state == saved_state,
		"AC3: int exclusion rejected without RNG draw")
	_check(gate.select_party_actionable_event(test_rng, [""], wallet, heroes).get("ok") == false and test_rng.state == saved_state,
		"AC3: empty string exclusion rejected without RNG draw")
	_check(gate.select_party_actionable_event(test_rng, ["   "], wallet, heroes).get("ok") == false and test_rng.state == saved_state,
		"AC3: whitespace exclusion rejected without RNG draw")
	_check(gate.select_party_actionable_event(test_rng, "not_an_array", wallet, heroes).get("ok") == false and test_rng.state == saved_state,
		"AC3: string non-array exclusion rejected without RNG draw")

	# Exhaustion
	var exhaust_res := gate.select_party_actionable_event(test_rng, expected_sorted_ids, wallet, heroes)
	_check(exhaust_res.get("ok") == false and exhaust_res.get("event") == {} and test_rng.state == saved_state,
		"AC3: pool exhaustion rejected without RNG draw")

	# Verify caller inputs were not mutated
	_check(wallet == wallet_copy, "AC3: wallet input was not mutated")
	_check(heroes == heroes_copy, "AC3: heroes input was not mutated")
	_check(exclusions_input == exclusions_copy, "AC3: exclusions input was not mutated")

	# 7. Deep detachment: mutating returned record does not mutate gate records
	var detach_rng := RandomNumberGenerator.new()
	detach_rng.seed = 1234
	var detach_res := gate.select_party_actionable_event(detach_rng, null, wallet, heroes)
	_check(detach_res.get("ok") == true, "AC3: detachment selection ok")
	var original_event_id: String = detach_res["event"]["id"]
	detach_res["event"]["id"] = "tampered_id"
	detach_res["event"]["choices"] = []
	detach_res["event"]["new_key"] = true

	# Check gate's offers to ensure internal record is untouched
	var offers := gate.get_offers()
	var found_tampered := false
	var found_original := false
	for o: Dictionary in offers:
		if o.get("id") == "tampered_id":
			found_tampered = true
		if o.get("id") == original_event_id:
			found_original = true
			_check(o.get("choices", []).size() == 3, "AC3: gate record choices intact")
	_check(not found_tampered and found_original, "AC3: returned record is deeply detached from gate")


# AC4: Selected records remain authentic, unclaimed and enterable; preview, one claim, no second claim.
func _test_ac4_gate_enter_preview_and_claim_handoff() -> void:
	var party_ids := ["warden", "scarecrow", "tinker"]
	var gate := RunV3HeroVitalEventGate.new(party_ids)
	var wallet := _wallet(50, 10)
	var heroes := [
		_hero("warden", 20, 30),
		_hero("scarecrow", 20, 30),
		_hero("tinker", 20, 30),
	]

	var rng := RandomNumberGenerator.new()
	rng.seed = 303
	var selection := gate.select_party_actionable_event(rng, null, wallet, heroes)
	_check(selection.get("ok") == true, "AC4: selection ok")
	var selected_event: Dictionary = selection["event"]
	var req_hero: String = selected_event.get("required_hero", "")
	_check(not req_hero.is_empty(), "AC4: selected event has required_hero: " + req_hero)

	# Enter the selected record with a matching living snapshot
	var hero_snap := {
		"gold": wallet["gold"],
		"scraps": wallet["scraps"],
		"hero": {"id": req_hero, "hp": 20, "max_hp": 30},
	}
	var visit := gate.enter(selected_event, hero_snap)
	_check(visit != null and visit.is_valid() and not visit.is_claimed(),
		"AC4: gate.enter admits selected authentic record")
	if visit == null:
		return

	# Preview exact authored alternatives
	var preview := visit.preview_vital_choices(hero_snap)
	_check(preview.get("ok") == true, "AC4: visit preview ok")
	var choices: Array = preview.get("choices", [])
	_check(choices.size() == 3, "AC4: visit preview has exactly 3 choices")

	# Find first affordable non-leave choice
	var target_choice_id := ""
	for c: Dictionary in choices:
		if c.get("choice_id") != "leave" and c.get("affordable") == true:
			target_choice_id = c["choice_id"]
			break
	_check(not target_choice_id.is_empty(), "AC4: found affordable non-leave choice: " + target_choice_id)

	# Claim affordable non-leave choice once
	var claim_receipt := visit.choose_with_vitals(target_choice_id, hero_snap)
	_check(claim_receipt.get("ok") == true and claim_receipt.get("choice_id") == target_choice_id,
		"AC4: claimed choice successfully once")
	_check(visit.is_claimed() and not visit.is_valid(), "AC4: visit is now claimed and invalid")

	# Reject second claim
	var second_claim := visit.choose_with_vitals("leave", claim_receipt.get("state", hero_snap))
	_check(second_claim.get("ok") == false, "AC4: second claim rejected on claimed visit")

	# Original gate remains valid and unclaimed
	_check(gate.is_valid() and not gate.is_claimed(), "AC4: original gate remains valid and unclaimed")


# AC1/AC2/AC3/AC4: Rivet Choir full-health paid heal suppression, wounded admission, absence/Torn, non-heal path, and gate handoff.
func _test_ac5_rivet_choir_full_health_paid_heal_suppression() -> void:
	var party_ids := ["warden", "button_golem", "tinker"]
	var gate := RunV3HeroVitalEventGate.new(party_ids)
	_check(gate.is_valid(), "AC5: gate with Button Golem is valid")

	var bg_event_id := "v3_button_golem_rivet_choir"
	var found_bg := false
	var other_offers: Array[String] = []
	for offer: Dictionary in gate.get_offers():
		var oid: String = offer.get("id", "")
		if oid == bg_event_id:
			found_bg = true
		else:
			other_offers.append(oid)
	_check(found_bg, "AC5: Rivet Choir is offered to Button Golem party")

	var wallet_17 := _wallet(17, 0)
	var wallet_before := wallet_17.duplicate(true)

	var rng := RandomNumberGenerator.new()
	rng.seed = 91001
	var rng_before := rng.state

	# 1. 10/10 HP Button Golem with 17 gold:
	# polish_chest_buttons: -17 gold, +9 HP (0 actual HP at 10/10 max 10) -> suppressed!
	# lend_bass_button: 10 max HP - 3 = 7 < 10 floor -> unaffordable!
	# Both non-Leave choices nonactionable -> must reject without RNG draw!
	var heroes_full := [
		_hero("warden", 20, 30),
		_hero("button_golem", 10, 10),
		_hero("tinker", 20, 30),
	]
	var heroes_full_before := heroes_full.duplicate(true)
	var other_copy := other_offers.duplicate(true)

	var res_full := gate.select_party_actionable_event(rng, other_offers, wallet_17, heroes_full)
	_check(res_full == {"ok": false, "event": {}},
		"AC5: 10/10 Button Golem with 17 gold rejects Rivet Choir (paid heal suppressed, Leave does not rescue)")
	_check(rng.state == rng_before,
		"AC5: suppressed paid heal rejection consumes zero RNG")
	_check(wallet_17 == wallet_before and heroes_full == heroes_full_before and other_offers == other_copy,
		"AC5: caller inputs preserved on rejection")

	# 2. 9/10 HP Button Golem with 17 gold (missing just 1 HP):
	# polish_chest_buttons restores 1 HP (9 to 10) for 17 gold -> actionable!
	var heroes_wounded := [
		_hero("warden", 20, 30),
		_hero("button_golem", 9, 10),
		_hero("tinker", 20, 30),
	]
	var heroes_wounded_before := heroes_wounded.duplicate(true)
	var oracle_rng := RandomNumberGenerator.new()
	oracle_rng.seed = 91001
	oracle_rng.randi_range(0, 0)

	var res_wounded := gate.select_party_actionable_event(rng, other_offers, wallet_17, heroes_wounded)
	_check(res_wounded.get("ok") == true,
		"AC5: 9/10 Button Golem with 17 gold admits Rivet Choir (restores 1 HP)")
	_check(res_wounded.get("event", {}).get("id") == bg_event_id,
		"AC5: admitted event is Rivet Choir")
	_check(rng.state == oracle_rng.state,
		"AC5: single admission consumes exactly one randi_range draw")
	_check(heroes_wounded == heroes_wounded_before and wallet_17 == wallet_before,
		"AC5: caller inputs preserved on admission")

	# Replay agreement:
	var replay_rng := RandomNumberGenerator.new()
	replay_rng.seed = 91001
	var res_replay := gate.select_party_actionable_event(replay_rng, other_offers, wallet_17, heroes_wounded)
	_check(res_replay["event"].get("id") == res_wounded["event"].get("id"),
		"AC5: seeded replay returns identical event")

	# Detachment: mutating returned event leaves gate offers untouched:
	var returned_event: Dictionary = res_wounded["event"]
	returned_event["title"] = "MUTATED"
	(returned_event["choices"] as Array).clear()
	for offer: Dictionary in gate.get_offers():
		if offer.get("id") == bg_event_id:
			_check(offer.get("title") != "MUTATED" and offer.get("choices", []).size() == 3,
				"AC5: returned event is deeply detached from gate")

	# 3. Torn Button Golem (hp == 0):
	var heroes_torn_bg := [
		_hero("warden", 20, 30),
		_hero("button_golem", 0, 10),
		_hero("tinker", 20, 30),
	]
	var res_torn := gate.select_party_actionable_event(rng, other_offers, wallet_17, heroes_torn_bg)
	_check(res_torn == {"ok": false, "event": {}},
		"AC5: Torn Button Golem cannot admit hero-gated Rivet Choir")
	_check(rng.state == oracle_rng.state,
		"AC5: Torn hero rejection consumes zero RNG")

	# 4. Absent Button Golem case:
	var party_no_bg := ["warden", "scarecrow", "tinker"]
	var gate_no_bg := RunV3HeroVitalEventGate.new(party_no_bg)
	var no_bg_offers: Array = []
	for offer: Dictionary in gate_no_bg.get_offers():
		if offer.get("id") == bg_event_id:
			no_bg_offers.append(offer)
	_check(no_bg_offers.is_empty(), "AC5: Rivet Choir absent from party without Button Golem")
	var heroes_no_bg := [
		_hero("warden", 20, 30),
		_hero("scarecrow", 20, 30),
		_hero("tinker", 20, 30),
	]
	var res_no_bg := gate_no_bg.select_party_actionable_event(rng, null, wallet_17, heroes_no_bg)
	_check(res_no_bg.get("event", {}).get("id") != bg_event_id,
		"AC5: absent hero's event cannot be returned")

	# 5. Eligible non-heal path:
	# Button Golem at 10/13 HP, 0 gold, 0 scraps:
	# polish_chest_buttons is unaffordable (0 gold).
	# lend_bass_button (+27 gold, -3 max HP) has max HP 13 - 3 = 10 >= 10 floor -> affordable!
	var heroes_non_heal := [
		_hero("warden", 20, 30),
		_hero("button_golem", 10, 13),
		_hero("tinker", 20, 30),
	]
	var res_non_heal := gate.select_party_actionable_event(rng, other_offers, _wallet(0, 0), heroes_non_heal)
	_check(res_non_heal.get("ok") == true and res_non_heal.get("event", {}).get("id") == bg_event_id,
		"AC5: eligible non-heal choice admits Rivet Choir even with 0 gold")

	# 6. Selected event handoff through RunEventChoice gate and settlement:
	var clean_bg_event: Dictionary = res_replay["event"]
	var bg_snap := {
		"gold": 17,
		"scraps": 0,
		"hero": {"id": "button_golem", "hp": 9, "max_hp": 10},
	}
	var bg_snap_before := bg_snap.duplicate(true)
	var visit := gate.enter(clean_bg_event, bg_snap)
	_check(visit != null and visit.is_valid() and not visit.is_claimed(),
		"AC5: gate.enter admits selected authentic Rivet Choir")
	if visit != null:
		var preview := visit.preview_vital_choices(bg_snap)
		_check(preview.get("ok") == true and preview.get("choices", []).size() == 3,
			"AC5: visit preview returns 3 choices")
		var polish_choice: Dictionary = {}
		for c: Dictionary in preview.get("choices", []):
			if c.get("choice_id") == "polish_chest_buttons":
				polish_choice = c
		_check(polish_choice.get("affordable") == true
			and polish_choice.get("state", {}).get("hero", {}).get("hp") == 10,
			"AC5: polish_chest_buttons projects capped healing from 9 to 10 HP")
		var receipt := visit.choose_with_vitals("polish_chest_buttons", bg_snap)
		_check(receipt.get("ok") == true and receipt.get("choice_id") == "polish_chest_buttons"
			and receipt.get("state", {}).get("gold") == 0
			and receipt.get("state", {}).get("hero", {}).get("hp") == 10,
			"AC5: polish_chest_buttons settles to 0 gold, 10/10 HP")
		_check(visit.is_claimed() and not visit.is_valid(),
			"AC5: visit is claimed and invalidated after choice")
		_check(visit.choose_with_vitals("leave", bg_snap).get("ok") == false,
			"AC5: second choice on claimed visit refuses")
		_check(bg_snap == bg_snap_before,
			"AC5: caller snapshot is untouched by choice settlement")


# A Design v4 Stitched party is four of eight distinct heroes. Excluding the
# other three members' genuine offers must leave the living fourth hero's
# authenticated Event selectable with one sorted-ID draw, while a Torn fourth
# hero, foreign/missing/duplicate/malformed snapshots and rejected exclusions
# consume no RNG and mutate no input. The named Lantern Monk trade then settles
# exactly once.
func _test_four_hero_stitched_party() -> void:
	var party_ids := ["warden", "seamstress", "tinker", "lantern_monk"]
	var vigil_id := "v3_lantern_monk_thimble_moon_vigil"
	var gate := RunV3HeroVitalEventGate.new(party_ids)
	_check(gate.is_valid(), "four-hero: Stitched gate is valid")
	if not gate.is_valid():
		return
	var offers := gate.get_offers()
	# The exclusions are actual offered IDs of the other three party members, so
	# only the fourth hero's authenticated records can remain. Never a catalog total.
	var other_members: Array[String] = []
	var monk_offers: Array = []
	for offer: Dictionary in offers:
		if offer.get("required_hero") == "lantern_monk":
			monk_offers.append(offer)
		else:
			other_members.append(offer["id"])
	_check(not other_members.is_empty() and not monk_offers.is_empty(),
		"four-hero: genuine three-member exclusions and fourth-hero offers exist")

	var wallet := _wallet(20, 2)
	var live_heroes := [
		_hero("warden", 20, 30),
		_hero("seamstress", 20, 30),
		_hero("tinker", 20, 30),
		_hero("lantern_monk", 15, 30),
	]
	var wallet_copy := wallet.duplicate(true)
	var heroes_copy := live_heroes.duplicate(true)
	var exclusions_copy := other_members.duplicate(true)

	# Independently derive the eligible sorted IDs from the genuine offers.
	var candidates := _offers_actionable_for_hero(offers, "lantern_monk", wallet, 15, 30, other_members)
	_check(candidates.has(vigil_id), "four-hero: moon vigil is actionable for the living fourth hero")
	_check(not candidates.is_empty(), "four-hero: the living fourth hero has candidates")
	var rng := RandomNumberGenerator.new()
	rng.seed = 61001
	var oracle := RandomNumberGenerator.new()
	oracle.seed = 61001
	var expected_id: String = candidates[oracle.randi_range(0, candidates.size() - 1)]
	var expected_record := {}
	for offer: Dictionary in offers:
		if offer.get("id") == expected_id:
			expected_record = offer
	_check(not expected_record.is_empty(), "four-hero: oracle candidate is a genuine offer")
	var res := gate.select_party_actionable_event(rng, other_members, wallet, live_heroes)
	_check(res == {"ok": true, "event": expected_record},
		"four-hero: living fourth hero's Event is selected from the sorted eligible set")
	_check(rng.state == oracle.state,
		"four-hero: selection consumes exactly one randi_range draw versus the seeded oracle")
	_check(res.get("event", {}).get("required_hero") == "lantern_monk",
		"four-hero: selected Event belongs to the fourth hero")

	# A Torn (0 HP) fourth hero can never be selected, and consumes no RNG.
	var torn_heroes := [
		_hero("warden", 20, 30),
		_hero("seamstress", 20, 30),
		_hero("tinker", 20, 30),
		_hero("lantern_monk", 0, 30),
	]
	var torn_state := rng.state
	_check(gate.select_party_actionable_event(rng, other_members, wallet, torn_heroes)
		== {"ok": false, "event": {}} and rng.state == torn_state,
		"four-hero: 0-HP fourth hero cannot select and consumes zero RNG")

	# With every fourth-hero trade unaffordable (0 gold, 0 scraps, HP 4/max 10 the
	# paid heal would leave 0 HP and the max-HP cut would break the floor) the
	# pool is Leave-only and rejects with zero RNG draws.
	var broke_wallet := _wallet(0, 0)
	var broke_heroes := [
		_hero("warden", 20, 30),
		_hero("seamstress", 20, 30),
		_hero("tinker", 20, 30),
		_hero("lantern_monk", 4, 10),
	]
	var broke_candidates := _offers_actionable_for_hero(
		offers, "lantern_monk", broke_wallet, 4, 10, other_members)
	var broke_state := rng.state
	_check(broke_candidates.is_empty()
		and gate.select_party_actionable_event(rng, other_members, broke_wallet, broke_heroes)
			== {"ok": false, "event": {}} and rng.state == broke_state,
		"four-hero: Leave-only fourth-hero pool rejects with zero RNG draws")

	# Foreign, missing, five-member, duplicate and malformed hero snapshots.
	var bad_snapshots := [
		["missing", [_hero("warden", 20, 30), _hero("seamstress", 20, 30), _hero("tinker", 20, 30)]],
		["foreign", [_hero("warden", 20, 30), _hero("seamstress", 20, 30),
			_hero("tinker", 20, 30), _hero("scarecrow", 15, 30)]],
		["five", [_hero("warden", 20, 30), _hero("seamstress", 20, 30),
			_hero("tinker", 20, 30), _hero("lantern_monk", 15, 30), _hero("scarecrow", 15, 30)]],
		["duplicate", [_hero("warden", 20, 30), _hero("warden", 20, 30),
			_hero("tinker", 20, 30), _hero("lantern_monk", 15, 30)]],
		["malformed", [_hero("warden", 20, 30), _hero("seamstress", 20, 30),
			_hero("tinker", 20, 30), {"id": "lantern_monk", "hp": 15}]],
	]
	for snapshot_case: Array in bad_snapshots:
		var bad_state := rng.state
		_check(gate.select_party_actionable_event(rng, other_members, wallet, snapshot_case[1])
			== {"ok": false, "event": {}} and rng.state == bad_state,
			"four-hero: " + str(snapshot_case[0]) + " hero snapshot rejects with zero RNG draws")

	# Rejected exclusions also consume zero RNG.
	for bad_exclusions in [123, "ids", other_members + [123], [""], ["   "]]:
		var ex_state := rng.state
		_check(gate.select_party_actionable_event(rng, bad_exclusions, wallet, live_heroes)
			== {"ok": false, "event": {}} and rng.state == ex_state,
			"four-hero: malformed exclusions reject with zero RNG draws: " + str(bad_exclusions))
	_check(wallet == wallet_copy and live_heroes == heroes_copy
		and other_members == exclusions_copy,
		"four-hero: refused selection never mutates caller wallet, heroes or exclusions")

	# Force the named record: exclude every other genuine offer, one draw remains.
	var only_vigil: Array[String] = []
	for offer: Dictionary in offers:
		if offer.get("id") != vigil_id:
			only_vigil.append(offer["id"])
	var forced_rng := RandomNumberGenerator.new()
	forced_rng.seed = 61002
	var forced_oracle := RandomNumberGenerator.new()
	forced_oracle.seed = 61002
	forced_oracle.randi_range(0, 0)
	var forced := gate.select_party_actionable_event(forced_rng, only_vigil, wallet, live_heroes)
	_check(forced.get("ok") == true and forced.get("event", {}).get("id") == vigil_id
		and forced_rng.state == forced_oracle.state,
		"four-hero: only the fourth hero's moon vigil remains, selected with one draw")

	# Enter the authenticated record with the Stitched opening vitality.
	var snap := {"gold": 20, "scraps": 2, "hero": {"id": "lantern_monk", "hp": 15, "max_hp": 30}}
	var snap_copy := snap.duplicate(true)
	var expected_state := {"gold": 4, "scraps": 2,
		"hero": {"id": "lantern_monk", "hp": 15, "max_hp": 32}}
	_check(gate.enter(vigil_id, {"gold": 20, "scraps": 2,
		"hero": {"id": "lantern_monk", "hp": 0, "max_hp": 30}}) == null,
		"four-hero: Torn Lantern Monk is refused admission")
	_check(gate.enter(vigil_id, {"gold": 20, "scraps": 2,
		"hero": {"id": "warden", "hp": 15, "max_hp": 30}}) == null,
		"four-hero: wrong-hero snapshot is refused admission")
	var visit := gate.enter(forced["event"], snap)
	_check(visit != null and visit.is_valid() and not visit.is_claimed(),
		"four-hero: authenticated moon vigil opens an unclaimed visit")
	if visit == null:
		return
	# None of the preview/claim refusals below may consume a run RNG draw.
	var claim_rng_state := rng.state

	var preview := visit.preview_vital_choices(snap)
	_check(preview.get("ok") == true and preview.get("event_id") == vigil_id,
		"four-hero: moon vigil previews authentically")
	var moonlight_quote := {}
	var tend_quote := {}
	for entry: Dictionary in preview.get("choices", []):
		if entry.get("choice_id") == "moonlight_seam":
			moonlight_quote = entry
		elif entry.get("choice_id") == "tend_moth_candles":
			tend_quote = entry
	_check(moonlight_quote == {"choice_id": "moonlight_seam", "gold_delta": -16,
		"scraps_delta": 0, "hp_delta": 0, "max_hp_delta": 2, "affordable": true,
		"state": expected_state},
		"four-hero: moonlight_seam previews gold 20 -> 4, scraps 2, HP 15/max 32")
	_check(tend_quote == {"choice_id": "tend_moth_candles", "gold_delta": 20,
		"scraps_delta": 0, "hp_delta": -4, "max_hp_delta": 0, "affordable": true,
		"state": {"gold": 40, "scraps": 2, "hero": {"id": "lantern_monk",
			"hp": 11, "max_hp": 30}}},
		"four-hero: tend_moth_candles previews its exact signed alternative")
	_check(snap == snap_copy and not visit.is_claimed(),
		"four-hero: preview does not claim or mutate the caller snapshot")

	# Wrong-hero preview and claim refuse on the still-unclaimed visit.
	var wrong_snap := {"gold": 20, "scraps": 2,
		"hero": {"id": "warden", "hp": 15, "max_hp": 30}}
	_check(visit.preview_vital_choices(wrong_snap).get("ok") == false,
		"four-hero: wrong-hero preview is denied")
	_check(visit.choose_with_vitals("moonlight_seam", wrong_snap) == {
		"ok": false, "event_id": "", "choice_id": "", "state": wrong_snap},
		"four-hero: wrong-hero claim refuses without changing the snapshot")
	_check(visit.is_valid() and not visit.is_claimed(),
		"four-hero: wrong-hero refusal does not consume the claim")

	var receipt := visit.choose_with_vitals("moonlight_seam", snap)
	_check(receipt == {"ok": true, "event_id": vigil_id, "choice_id": "moonlight_seam",
		"state": expected_state} and snap == snap_copy,
		"four-hero: moonlight_seam settles once to gold 4, scraps 2, HP 15/max 32")
	_check(visit.is_claimed() and not visit.is_valid(),
		"four-hero: accepted claim latches the visit")
	_check(visit.choose_with_vitals("moonlight_seam", expected_state) == {
		"ok": false, "event_id": "", "choice_id": "", "state": expected_state},
		"four-hero: replay refuses without a second settlement")
	_check(visit.choose_with_vitals("leave", expected_state).get("ok") == false,
		"four-hero: alternate choice is blocked after the claim")

	# An unfunded choice refuses without changing wallet, HP or the claim.
	var poor_snap := {"gold": 15, "scraps": 0,
		"hero": {"id": "lantern_monk", "hp": 15, "max_hp": 30}}
	var poor_copy := poor_snap.duplicate(true)
	var poor_visit := gate.enter(vigil_id, poor_snap)
	_check(poor_visit != null and poor_visit.is_valid(),
		"four-hero: unfunded Lantern Monk still enters the authored visit")
	if poor_visit == null:
		return
	var poor_quote := {}
	for entry: Dictionary in poor_visit.preview_vital_choices(poor_snap).get("choices", []):
		if entry.get("choice_id") == "moonlight_seam":
			poor_quote = entry
	_check(poor_quote.get("affordable") == false and poor_quote.get("state") == poor_snap,
		"four-hero: unfunded moonlight_seam projects the unchanged snapshot")
	_check(poor_visit.choose_with_vitals("moonlight_seam", poor_snap) == {
		"ok": false, "event_id": "", "choice_id": "", "state": poor_snap}
		and poor_snap == poor_copy and poor_visit.is_valid() and not poor_visit.is_claimed(),
		"four-hero: unfunded claim refuses without spending gold, HP or the claim")
	_check(poor_visit.choose_with_vitals("leave", poor_snap).get("ok") == true
		and poor_visit.is_claimed(),
		"four-hero: unfunded visit recovers with the authored Leave")
	_check(rng.state == claim_rng_state,
		"four-hero: preview, wrong-hero, unfunded and replay refusals consume no RNG")

	# Legacy three-hero parties remain admitted and selectable.
	var legacy := RunV3HeroVitalEventGate.new(["warden", "seamstress", "tinker"])
	_check(legacy.is_valid(), "four-hero: legacy three-hero gate stays valid")


## Expected sorted IDs of a hero's actionable offered Events, computed from the
## genuine offers and the production row rule (never a hardcoded catalog list).
func _offers_actionable_for_hero(
	offers: Array,
	hero_id: String,
	wallet: Dictionary,
	hp: int,
	max_hp: int,
	excluded: Array = []
) -> Array[String]:
	var excluded_map := {}
	for item: Variant in excluded:
		excluded_map[item] = true
	var snapshot := {"gold": wallet["gold"], "scraps": wallet["scraps"],
		"hero": {"id": hero_id, "hp": hp, "max_hp": max_hp}}
	var ids: Array[String] = []
	for offer: Dictionary in offers:
		if offer.get("required_hero") != hero_id or excluded_map.has(offer.get("id")):
			continue
		var service := RunEventChoice.new(offer)
		if not service.is_valid():
			continue
		var preview := service.preview_vital_choices(snapshot)
		if not preview.get("ok", false):
			continue
		for entry: Dictionary in preview.get("choices", []):
			if RunV3HeroVitalEventGate.is_choice_actionable(entry, hp):
				ids.append(offer["id"])
				break
	ids.sort()
	return ids


func _find_choice(preview: Dictionary, choice_id: String) -> Dictionary:
	for c in preview.get("choices", []):
		if c is Dictionary and (c as Dictionary).get("choice_id") == choice_id:
			return c
	return {}


## Direct-bound visit full-health paid heal suppression, capping, alternatives and claim-time revalidation.
func _test_direct_bound_visit_full_health_paid_heal_suppression() -> void:
	var surgeon_id := "v3_seamstress_crimson_quilt_surgeon"
	var party_3 := ["warden", "seamstress", "tinker"]
	var gate_3 := RunV3HeroVitalEventGate.new(party_3)
	_check(gate_3.is_valid(), "direct-visit: 3-hero gate is valid")

	# AC1: Seamstress at 30/30 HP, gold >= 12, scraps >= 0
	# stitch_wound is visible as unaffordable with unchanged projected state.
	# Direct choose_with_vitals("stitch_wound") refuses without spending gold or claiming.
	var snap_30 := {"gold": 12, "scraps": 0, "hero": {"id": "seamstress", "hp": 30, "max_hp": 30}}
	var snap_30_copy := snap_30.duplicate(true)
	var visit_30 := gate_3.enter(surgeon_id, snap_30)
	_check(visit_30 != null and visit_30.is_valid() and not visit_30.is_claimed(),
		"AC1: valid unclaimed visit opened for 30/30 Seamstress")
	if visit_30 == null:
		return

	var prev_30 := visit_30.preview_vital_choices()
	_check(prev_30.get("ok") == true and prev_30.get("event_id") == surgeon_id,
		"AC1: preview_vital_choices succeeds on direct visit")
	var stitch_30 := _find_choice(prev_30, "stitch_wound")
	_check(stitch_30.get("choice_id") == "stitch_wound", "AC1: stitch_wound row present")
	_check(stitch_30.get("gold_delta") == -12 and stitch_30.get("scraps_delta") == 0
		and stitch_30.get("hp_delta") == 8 and stitch_30.get("max_hp_delta") == 0,
		"AC1: stitch_wound authored deltas preserved")
	_check(stitch_30.get("affordable") == false,
		"AC1: stitch_wound is visible as unaffordable/unavailable at 30/30 HP")
	_check(stitch_30.get("state") == snap_30,
		"AC1: stitch_wound reports unchanged projected snapshot")

	# Alias preview_choices returns identical result
	var prev_alias := visit_30.preview_choices()
	_check(prev_alias == prev_30, "AC1: preview_choices alias matches preview_vital_choices")

	# Direct choose_with_vitals refuses without spending gold or claiming the visit
	var refuse_receipt := visit_30.choose_with_vitals("stitch_wound")
	_check(refuse_receipt == {"ok": false, "event_id": "", "choice_id": "", "state": snap_30},
		"AC1: direct choose_with_vitals refuses stitch_wound at full HP without taking money")
	_check(visit_30.is_valid() and not visit_30.is_claimed(),
		"AC1: rejected full-health paid heal leaves visit available for a later valid choice")
	_check(snap_30 == snap_30_copy,
		"AC1: caller snapshot preserved on refusal")

	# AC2: With same authentic visit and Seamstress at 25/30 HP, gold 12:
	# stitch_wound previews and commits exactly once for Seamstress 30/30 HP and gold 0.
	var snap_25 := {"gold": 12, "scraps": 0, "hero": {"id": "seamstress", "hp": 25, "max_hp": 30}}
	var snap_25_copy := snap_25.duplicate(true)
	var visit_25 := gate_3.enter(surgeon_id, snap_25)
	_check(visit_25 != null and visit_25.is_valid(), "AC2: 25/30 Seamstress enters visit")
	if visit_25 != null:
		var prev_25 := visit_25.preview_vital_choices()
		var stitch_25 := _find_choice(prev_25, "stitch_wound")
		_check(stitch_25.get("affordable") == true, "AC2: stitch_wound is affordable at 25/30 HP")
		var expected_25_state := {"gold": 0, "scraps": 0, "hero": {"id": "seamstress", "hp": 30, "max_hp": 30}}
		_check(stitch_25.get("state") == expected_25_state, "AC2: stitch_wound previews gold 0 and 30/30 HP")
		var commit_25 := visit_25.choose_with_vitals("stitch_wound")
		_check(commit_25 == {"ok": true, "event_id": surgeon_id, "choice_id": "stitch_wound", "state": expected_25_state},
			"AC2: stitch_wound commits exactly once for Seamstress 30/30 HP and gold 0")
		_check(visit_25.is_claimed() and not visit_25.is_valid(), "AC2: visit is claimed and invalidated")
		_check(visit_25.choose_with_vitals("leave").get("ok") == false, "AC2: second claim rejected on claimed visit")
		_check(snap_25 == snap_25_copy, "AC2: caller snapshot untouched")

	# AC2: At 27/30 HP, healing still caps at 30 without changing max HP.
	var snap_27 := {"gold": 12, "scraps": 0, "hero": {"id": "seamstress", "hp": 27, "max_hp": 30}}
	var visit_27 := gate_3.enter(surgeon_id, snap_27)
	_check(visit_27 != null and visit_27.is_valid(), "AC2: 27/30 Seamstress enters visit")
	if visit_27 != null:
		var prev_27 := visit_27.preview_vital_choices()
		var stitch_27 := _find_choice(prev_27, "stitch_wound")
		_check(stitch_27.get("affordable") == true, "AC2: stitch_wound affordable at 27/30 HP")
		var expected_27_state := {"gold": 0, "scraps": 0, "hero": {"id": "seamstress", "hp": 30, "max_hp": 30}}
		_check(stitch_27.get("state") == expected_27_state,
			"AC2: 27/30 HP (+8) caps at 30 without changing max HP")
		var commit_27 := visit_27.choose_with_vitals("stitch_wound")
		_check(commit_27 == {"ok": true, "event_id": surgeon_id, "choice_id": "stitch_wound", "state": expected_27_state},
			"AC2: 27/30 HP commits with capped 30 HP and max HP 30")

	# AC2: Authenticated non-healing trade (donate_red_thread: +18 gold, -4 HP) and leave remain available at full HP.
	var donate_30 := _find_choice(prev_30, "donate_red_thread")
	_check(donate_30.get("affordable") == true, "AC2: donate_red_thread remains available when HP is full")
	var expected_donate_state := {"gold": 30, "scraps": 0, "hero": {"id": "seamstress", "hp": 26, "max_hp": 30}}
	_check(donate_30.get("state") == expected_donate_state,
		"AC2: donate_red_thread projects gold 30 and HP 26/30")

	var leave_30 := _find_choice(prev_30, "leave")
	_check(leave_30.get("affordable") == true and leave_30.get("state") == snap_30,
		"AC2: leave remains available when HP is full")

	# Prove that after stitch_wound refusal on visit_30, player can choose leave instead
	var leave_receipt := visit_30.choose_with_vitals("leave")
	_check(leave_receipt == {"ok": true, "event_id": surgeon_id, "choice_id": "leave", "state": snap_30},
		"AC2: leave commits successfully after refused paid heal")
	_check(visit_30.is_claimed() and not visit_30.is_valid(),
		"AC2: visit_30 latched by leave choice")

	# Fresh full-health visit commits donate_red_thread
	var visit_donate := gate_3.enter(surgeon_id, snap_30)
	var donate_receipt := visit_donate.choose_with_vitals("donate_red_thread")
	_check(donate_receipt == {"ok": true, "event_id": surgeon_id, "choice_id": "donate_red_thread", "state": expected_donate_state},
		"AC2: donate_red_thread commits successfully at full HP")

	# AC2: Warden reinforce_shield_seam (-2 scraps, +3 max HP) is not mistakenly suppressed
	var warden_id := "v3_warden_buckle_heart_ward"
	var warden_snap := {"gold": 10, "scraps": 2, "hero": {"id": "warden", "hp": 30, "max_hp": 30}}
	var warden_visit := gate_3.enter(warden_id, warden_snap)
	_check(warden_visit != null and warden_visit.is_valid(), "AC2: Warden visit opened")
	if warden_visit != null:
		var warden_prev := warden_visit.preview_vital_choices()
		var reinforce := _find_choice(warden_prev, "reinforce_shield_seam")
		_check(reinforce.get("affordable") == true,
			"AC2: Warden reinforce_shield_seam (-2 scraps, +3 max HP) is not mistakenly suppressed")
		var expected_warden_state := {"gold": 10, "scraps": 0, "hero": {"id": "warden", "hp": 30, "max_hp": 33}}
		_check(reinforce.get("state") == expected_warden_state,
			"AC2: reinforce_shield_seam projects scraps 0 and max HP 33")
		var warden_commit := warden_visit.choose_with_vitals("reinforce_shield_seam")
		_check(warden_commit == {"ok": true, "event_id": warden_id, "choice_id": "reinforce_shield_seam", "state": expected_warden_state},
			"AC2: reinforce_shield_seam commits successfully at full HP")

	# AC3: Snapshot revalidation at claim time:
	# A visit opened at 25/30 HP refuses a full-health (30/30 HP) override passed to choose_with_vitals.
	var visit_override := gate_3.enter(surgeon_id, snap_25)
	_check(visit_override != null and visit_override.is_valid(), "AC3: visit_override opened at 25 HP")
	if visit_override != null:
		var override_snap := {"gold": 12, "scraps": 0, "hero": {"id": "seamstress", "hp": 30, "max_hp": 30}}
		var override_refuse := visit_override.choose_with_vitals("stitch_wound", override_snap)
		_check(override_refuse == {"ok": false, "event_id": "", "choice_id": "", "state": override_snap},
			"AC3: claim-time full-health override is refused without spending or claiming")
		_check(visit_override.is_valid() and not visit_override.is_claimed(),
			"AC3: failed paid-heal override leaves visit latch intact")
		# Valid wounded snapshot or leave can still claim the visit
		var recovery_receipt := visit_override.choose_with_vitals("leave")
		_check(recovery_receipt.get("ok") == true and visit_override.is_claimed(),
			"AC3: visit recovers and claims with leave after failed override")

	# AC3: 4-hero Stitched party direct entry regression
	var party_4 := ["warden", "seamstress", "tinker", "lantern_monk"]
	var gate_4 := RunV3HeroVitalEventGate.new(party_4)
	_check(gate_4.is_valid(), "AC3: 4-hero Stitched gate is valid")
	var visit_4 := gate_4.enter(surgeon_id, snap_30)
	_check(visit_4 != null and visit_4.is_valid() and not visit_4.is_claimed(),
		"AC3: 4-hero direct visit opened for 30/30 Seamstress")
	if visit_4 != null:
		var prev_4 := visit_4.preview_vital_choices()
		var stitch_4 := _find_choice(prev_4, "stitch_wound")
		_check(stitch_4.get("affordable") == false and stitch_4.get("state") == snap_30,
			"AC3: 4-hero visit suppresses stitch_wound at 30/30 HP in preview")
		var refuse_4 := visit_4.choose_with_vitals("stitch_wound")
		_check(refuse_4 == {"ok": false, "event_id": "", "choice_id": "", "state": snap_30},
			"AC3: 4-hero visit refuses stitch_wound at 30/30 HP")
		_check(visit_4.is_valid() and not visit_4.is_claimed(),
			"AC3: 4-hero visit remains unclaimed after refusal")
		var leave_4 := visit_4.choose_with_vitals("leave")
		_check(leave_4.get("ok") == true and visit_4.is_claimed(),
			"AC3: 4-hero visit claims leave after refusal")

