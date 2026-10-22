extends SceneTree
## Focused deterministic SceneTree tests for RunSignatureSummary.

var failures: Array[String] = []
var checks: int = 0


class CorruptedWardrobe extends RunPatchWardrobe:
	var _custom_snapshot: Dictionary = {}

	func _init(custom_snap: Dictionary) -> void:
		_custom_snapshot = custom_snap.duplicate(true)

	func is_valid() -> bool:
		return true

	func get_snapshot() -> Dictionary:
		return _custom_snapshot.duplicate(true)


func _initialize() -> void:
	_test_two_legal_stitches_and_wardrobe_summary()
	_test_shop_removal_and_wardrobe_updates()
	_test_negative_matrix_detachment_and_rng()
	if failures.is_empty():
		print("run_signature_summary_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_signature_summary_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_party() -> Array:
	var source: String = FileAccess.get_file_as_string("res://data/heroes/starter_party.json")
	var authored: Variant = JSON.parse_string(source)
	_check(typeof(authored) == TYPE_ARRAY and authored.size() == 3, "shipped starter party has 3 heroes")
	if typeof(authored) != TYPE_ARRAY or authored.size() != 3:
		return []
	var definitions: Array = []
	for hero in authored:
		definitions.append({
			"id": hero["id"],
			"max_hp": int(hero["max_hp"]),
			"art_path": hero["art_path"],
		})
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "CombatParty accepts starter party definitions")
	return party.get_heroes()


func _load_starter_deck() -> Array[String]:
	var source: String = FileAccess.get_file_as_string("res://data/cards/starter_deck.json")
	var authored: Variant = JSON.parse_string(source)
	var deck: Array[String] = []
	if typeof(authored) == TYPE_ARRAY:
		for id in authored:
			if typeof(id) == TYPE_STRING:
				deck.append(id)
	_check(not deck.is_empty(), "shipped starter deck is non-empty")
	_check(deck.has("warden_strike"), "shipped starter deck contains warden_strike")
	_check(deck.has("seamstress_prick"), "shipped starter deck contains seamstress_prick")
	_check(deck.has("seamstress_mend"), "shipped starter deck contains seamstress_mend")
	_check(deck.has("tinker_pop_shot"), "shipped starter deck contains tinker_pop_shot")
	var idx_w: int = deck.find("warden_strike")
	var idx_s: int = deck.find("seamstress_prick")
	var idx_m: int = deck.find("seamstress_mend")
	var idx_t: int = deck.find("tinker_pop_shot")
	_check(idx_w >= 0 and idx_s >= 0 and idx_m >= 0 and idx_t >= 0,
		"shipped starter deck has usable indices for stitch candidates")
	_check(idx_w != idx_s and idx_w != idx_m and idx_w != idx_t and idx_s != idx_m and idx_s != idx_t and idx_m != idx_t,
		"shipped starter deck has distinct usable indices for stitch candidates")
	return deck


func _authored_patch_definitions() -> Array:
	return [
		{"id": "button_eye", "slot": "HEAD"},
		{"id": "stitched_badge", "slot": "HEAD"},
		{"id": "pincushion_arm", "slot": "ARM"},
		{"id": "spare_spool", "slot": "ARM"},
		{"id": "quilted_coat", "slot": "COAT"},
	]


func _test_two_legal_stitches_and_wardrobe_summary() -> void:
	var starter_deck: Array[String] = _load_starter_deck()
	var idx_warden: int = starter_deck.find("warden_strike")
	var idx_seamstress: int = starter_deck.find("seamstress_prick")
	var idx_mend: int = starter_deck.find("seamstress_mend")
	var idx_tinker: int = starter_deck.find("tinker_pop_shot")
	_check(idx_warden >= 0, "starter deck contains warden_strike")
	_check(idx_seamstress >= 0, "starter deck contains seamstress_prick")
	_check(idx_mend >= 0, "starter deck contains seamstress_mend")
	_check(idx_tinker >= 0, "starter deck contains tinker_pop_shot")
	_check(idx_warden != idx_seamstress and idx_warden != idx_mend and idx_warden != idx_tinker \
		and idx_seamstress != idx_mend and idx_seamstress != idx_tinker and idx_mend != idx_tinker,
		"starter deck has distinct usable indices for stitch candidates")
	if idx_warden < 0 or idx_seamstress < 0 or idx_mend < 0 or idx_tinker < 0 or idx_warden == idx_seamstress:
		return

	_assert_ac1_scenario(starter_deck, "shipped starter deck")

	# Test-only fixture with legal extra starter card to verify catalog-growth tolerance.
	var expanded_deck: Array[String] = starter_deck.duplicate()
	expanded_deck.append("warden_strike")
	_assert_ac1_scenario(expanded_deck, "expanded starter deck fixture")


func _assert_ac1_scenario(deck: Array[String], scenario_name: String) -> void:
	var heroes: Array = _load_party()
	var idx_warden: int = deck.find("warden_strike")
	var idx_seamstress: int = deck.find("seamstress_prick")
	var idx_mend: int = deck.find("seamstress_mend")
	var idx_tinker: int = deck.find("tinker_pop_shot")
	_check(idx_warden >= 0, scenario_name + ": deck contains warden_strike")
	_check(idx_seamstress >= 0, scenario_name + ": deck contains seamstress_prick")
	_check(idx_mend >= 0, scenario_name + ": deck contains seamstress_mend")
	_check(idx_tinker >= 0, scenario_name + ": deck contains tinker_pop_shot")
	_check(idx_warden != idx_seamstress and idx_warden != idx_mend and idx_warden != idx_tinker \
		and idx_seamstress != idx_mend and idx_seamstress != idx_tinker and idx_mend != idx_tinker,
		scenario_name + ": deck has distinct usable indices for stitch candidates")
	if heroes.is_empty() or idx_warden < 0 or idx_seamstress < 0 or idx_mend < 0 or idx_tinker < 0 \
			or idx_warden == idx_seamstress:
		return

	# Visit 1: Stitch warden_strike and seamstress_prick.
	var scraps_initial: int = 6
	var stitch_1 := RunRestStitchCards.new(deck, {}, scraps_initial, 1)
	_check(stitch_1.is_valid(), scenario_name + ": first stitch service instance is valid")
	var snapshot_1: Dictionary = stitch_1.get_snapshot()

	var result_1: Dictionary = stitch_1.choose_stitch(idx_warden, idx_seamstress, snapshot_1)
	_check(result_1.get("ok") == true, scenario_name + ": first stitch transaction succeeded")
	var deck_after_1: Array[String] = []
	deck_after_1.assign(result_1.get("deck", []))
	var desc_after_1: Dictionary = result_1.get("descriptors", {}).duplicate(true)
	var scraps_after_1: int = result_1.get("remaining_scraps", 0)
	var next_id_after_1: int = result_1.get("next_stitch_id", 1)
	_check(scraps_after_1 == 3, scenario_name + ": scraps decremented by 3 after first stitch")
	_check(next_id_after_1 == 2, scenario_name + ": next_stitch_id advanced to 2")
	_check(desc_after_1.has("stitched_000001"), scenario_name + ": descriptors contains stitched_000001")

	# Visit 2: Stitch seamstress_mend and tinker_pop_shot.
	var stitch_2 := RunRestStitchCards.new(deck_after_1, desc_after_1, scraps_after_1, next_id_after_1)
	_check(stitch_2.is_valid(), scenario_name + ": second stitch service instance is valid")
	var snapshot_2: Dictionary = stitch_2.get_snapshot()
	var idx_seamstress_2: int = deck_after_1.find("seamstress_mend")
	var idx_tinker_2: int = deck_after_1.find("tinker_pop_shot")
	_check(idx_seamstress_2 >= 0 and idx_tinker_2 >= 0 and idx_seamstress_2 != idx_tinker_2,
		scenario_name + ": found distinct second-pair cards")
	if idx_seamstress_2 < 0 or idx_tinker_2 < 0 or idx_seamstress_2 == idx_tinker_2:
		return

	var result_2: Dictionary = stitch_2.choose_stitch(idx_seamstress_2, idx_tinker_2, snapshot_2)
	_check(result_2.get("ok") == true, scenario_name + ": second stitch transaction succeeded")
	var deck_after_2: Array[String] = []
	deck_after_2.assign(result_2.get("deck", []))
	var desc_after_2: Dictionary = result_2.get("descriptors", {}).duplicate(true)
	var next_id_after_2: int = result_2.get("next_stitch_id", 1)
	_check(next_id_after_2 == 3, scenario_name + ": next_stitch_id advanced to 3")
	_check(desc_after_2.has("stitched_000001") and desc_after_2.has("stitched_000002"),
		scenario_name + ": descriptors contains both stitched cards")

	# Construct valid RunPatchWardrobe against resulting deck.
	var defs: Array = _authored_patch_definitions()
	var owned: Array = ["button_eye", "stitched_badge", "pincushion_arm", "spare_spool", "quilted_coat"]
	var wardrobe := RunPatchWardrobe.new(heroes, owned, defs, 3, 100, deck_after_2, 777)
	_check(wardrobe.is_valid(), scenario_name + ": wardrobe constructed against resulting deck is valid")

	# Sew HEAD to Warden, ARM to Seamstress, COAT to Tinker.
	var sew_1: Dictionary = wardrobe.sew("button_eye", "warden", "HEAD", "op_1", wardrobe.get_snapshot())
	var sew_2: Dictionary = wardrobe.sew("pincushion_arm", "seamstress", "ARM", "op_2", wardrobe.get_snapshot())
	var sew_3: Dictionary = wardrobe.sew("quilted_coat", "tinker", "COAT", "op_3", wardrobe.get_snapshot())
	_check(sew_1.get("ok") == true and sew_2.get("ok") == true and sew_3.get("ok") == true,
		scenario_name + ": all 3 sew operations succeeded")

	# Snapshot source state and RNG before projection.
	var wardrobe_snap_before: Dictionary = wardrobe.get_snapshot()
	var deck_snapshot_before: Array[String] = deck_after_2.duplicate()
	var desc_snapshot_before: Dictionary = desc_after_2.duplicate(true)
	var test_rng := RandomNumberGenerator.new()
	test_rng.seed = 45678
	var rng_state_before: int = test_rng.state
	seed(13579)
	var global_sample_before: int = randi()
	seed(13579)

	# Execute RunSignatureSummary.summarize
	var summary: Dictionary = RunSignatureSummary.summarize(deck_after_2, desc_after_2, next_id_after_2, wardrobe)

	_check(summary.get("ok") == true, scenario_name + " AC1: summary reports ok == true")
	_check(summary.get("stitched_created") == 2, scenario_name + " AC1: stitched_created == 2 historical allocations")
	_check(summary.get("stitched_current") == 2, scenario_name + " AC1: stitched_current == 2 currently owned")
	var summary_descriptors: Variant = summary.get("descriptors")
	_check(typeof(summary_descriptors) == TYPE_DICTIONARY and summary_descriptors.size() == 2,
		scenario_name + " AC1: 2 live descriptors in summary")
	_check(summary.get("worn_total") == 3, scenario_name + " AC1: worn_total == 3 for three sewn slot placements")

	var worn_ids_val: Variant = summary.get("worn_ids")
	_check(typeof(worn_ids_val) == TYPE_ARRAY and worn_ids_val.size() == 3,
		scenario_name + " AC1: three worn IDs returned")
	if typeof(worn_ids_val) == TYPE_ARRAY:
		_check(worn_ids_val == ["button_eye", "pincushion_arm", "quilted_coat"],
			scenario_name + " AC1: exact worn IDs in exact HERO_IDS/SLOTS order")

	var heroes_val: Variant = summary.get("heroes")
	_check(typeof(heroes_val) == TYPE_ARRAY and heroes_val.size() == 3,
		scenario_name + " AC1: 3 hero rows in Warden/Seamstress/Tinker order")
	if typeof(heroes_val) == TYPE_ARRAY and heroes_val.size() == 3:
		var h0: Dictionary = heroes_val[0]
		var h1: Dictionary = heroes_val[1]
		var h2: Dictionary = heroes_val[2]
		_check(h0.get("hero_id") == "warden" and h0.get("HEAD") == "button_eye" and h0.get("ARM") == "" and h0.get("COAT") == "",
			scenario_name + " AC1: Warden wears button_eye on HEAD")
		_check(h1.get("hero_id") == "seamstress" and h1.get("HEAD") == "" and h1.get("ARM") == "pincushion_arm" and h1.get("COAT") == "",
			scenario_name + " AC1: Seamstress wears pincushion_arm on ARM")
		_check(h2.get("hero_id") == "tinker" and h2.get("HEAD") == "" and h2.get("ARM") == "" and h2.get("COAT") == "quilted_coat",
			scenario_name + " AC1: Tinker wears quilted_coat on COAT")
		# Check slot-indexed dictionary access.
		var slots0: Dictionary = h0.get("slots", {})
		var slots1: Dictionary = h1.get("slots", {})
		var slots2: Dictionary = h2.get("slots", {})
		_check(slots0.get("HEAD") == "button_eye" and slots1.get("ARM") == "pincushion_arm" and slots2.get("COAT") == "quilted_coat",
			scenario_name + " AC1: slot-indexed dictionary access on hero rows matches")

	# Assert caller state and RNG unchanged.
	_check(wardrobe.get_snapshot() == wardrobe_snap_before, scenario_name + ": wardrobe state unchanged after summary")
	_check(wardrobe.get_snapshot().get("receipt") == wardrobe_snap_before.get("receipt"), scenario_name + ": wardrobe receipt unchanged")
	_check(deck_after_2 == deck_snapshot_before, scenario_name + ": deck argument unchanged after summary")
	_check(desc_after_2 == desc_snapshot_before, scenario_name + ": descriptors argument unchanged after summary")
	_check(test_rng.state == rng_state_before, scenario_name + ": seeded RNG state unchanged after summary")
	_check(randi() == global_sample_before, scenario_name + ": global RNG state unchanged after summary")


func _test_shop_removal_and_wardrobe_updates() -> void:
	var heroes: Array = _load_party()
	var starter_deck: Array[String] = _load_starter_deck()

	# Create two stitched cards.
	var stitch_1 := RunRestStitchCards.new(starter_deck, {}, 6, 1)
	var res_1: Dictionary = stitch_1.choose_stitch(starter_deck.find("warden_strike"), starter_deck.find("seamstress_prick"), stitch_1.get_snapshot())
	var deck_1: Array[String] = []
	deck_1.assign(res_1.get("deck", []))
	var desc_1: Dictionary = res_1.get("descriptors", {}).duplicate(true)

	var stitch_2 := RunRestStitchCards.new(deck_1, desc_1, 3, 2)
	var res_2: Dictionary = stitch_2.choose_stitch(deck_1.find("seamstress_mend"), deck_1.find("tinker_pop_shot"), stitch_2.get_snapshot())
	var deck_2: Array[String] = []
	deck_2.assign(res_2.get("deck", []))
	var desc_2: Dictionary = res_2.get("descriptors", {}).duplicate(true)
	var cursor: int = res_2.get("next_stitch_id", 3)

	# Build wardrobe and initial wear.
	var defs: Array = _authored_patch_definitions()
	var owned: Array = ["button_eye", "stitched_badge", "pincushion_arm", "spare_spool", "quilted_coat"]
	var wardrobe := RunPatchWardrobe.new(heroes, owned, defs, 3, 100, deck_2, 777)
	wardrobe.sew("button_eye", "warden", "HEAD", "op_sew_w", wardrobe.get_snapshot())
	wardrobe.sew("pincushion_arm", "seamstress", "ARM", "op_sew_s", wardrobe.get_snapshot())
	wardrobe.sew("quilted_coat", "tinker", "COAT", "op_sew_t", wardrobe.get_snapshot())

	# Remove stitched_000001 with RunShopCardRemoval.try_remove_with_stitch_ledger.
	var removal_res: Dictionary = RunShopCardRemoval.try_remove_with_stitch_ledger(deck_2, desc_2, cursor, 100, 0, "stitched_000001")
	_check(removal_res.get("ok") == true, "AC2: removal succeeded")
	_check(removal_res.get("price") == 75, "AC2: first removal price is 75")
	_check(removal_res.get("gold") == 25, "AC2: gold debited to 25")
	_check(removal_res.get("next_stitch_id") == 3, "AC2: next_stitch_id remains 3")
	var deck_removed: Array[String] = []
	deck_removed.assign(removal_res.get("deck", []))
	var desc_removed: Dictionary = removal_res.get("descriptors", {}).duplicate(true)
	_check(not deck_removed.has("stitched_000001") and deck_removed.has("stitched_000002"), "AC2: deck has only surviving stitched card")
	_check(not desc_removed.has("stitched_000001") and desc_removed.has("stitched_000002"), "AC2: descriptors has only surviving descriptor")

	# Refresh wardrobe with resulting deck.
	var refresh_ok: bool = wardrobe.refresh_run_context(
		wardrobe.get_snapshot().get("heroes"),
		wardrobe.get_snapshot().get("owned"),
		wardrobe.get_snapshot().get("scraps"),
		removal_res.get("gold"),
		deck_removed,
		wardrobe.get_snapshot()
	)
	_check(refresh_ok, "AC2: wardrobe refreshed with new deck and gold")

	# Execute a same-slot paid Rest re-sew: move button_eye from Warden to Seamstress HEAD.
	wardrobe.start_rest("rest_node_1", wardrobe.get_snapshot())
	var resew_res: Dictionary = wardrobe.re_sew("button_eye", "warden", "seamstress", "rest_node_1", "op_resew_1", wardrobe.get_snapshot())
	_check(resew_res.get("ok") == true, "AC2: re_sew button_eye to Seamstress HEAD succeeded")
	wardrobe.end_rest("rest_node_1", wardrobe.get_snapshot())

	# Execute sewn replacement: sew stitched_badge over Seamstress HEAD (displacing button_eye).
	var replace_res: Dictionary = wardrobe.sew("stitched_badge", "seamstress", "HEAD", "op_replace_1", wardrobe.get_snapshot())
	_check(replace_res.get("ok") == true, "AC2: replacement sew succeeded")
	_check(replace_res.get("receipt", {}).get("displaced_id") == "button_eye", "AC2: button_eye displaced")
	var wardrobe_snap: Dictionary = wardrobe.get_snapshot()
	var owned_after_replace: Array = wardrobe_snap.get("owned", [])
	_check(not owned_after_replace.has("button_eye"), "AC2: displaced button_eye destroyed from owned inventory")
	_check(owned_after_replace.has("spare_spool"), "AC2: spare_spool remains in inventory as unsewn patch")

	# Run RunSignatureSummary.summarize on updated ledger.
	var summary: Dictionary = RunSignatureSummary.summarize(deck_removed, desc_removed, cursor, wardrobe)
	_check(summary.get("ok") == true, "AC2: summary succeeds on updated ledger")
	_check(summary.get("stitched_created") == 2, "AC2: stitched_created stays 2")
	_check(summary.get("stitched_current") == 1, "AC2: stitched_current falls to 1")
	var summary_descriptors: Variant = summary.get("descriptors")
	_check(typeof(summary_descriptors) == TYPE_DICTIONARY and summary_descriptors.has("stitched_000002") and not summary_descriptors.has("stitched_000001"),
		"AC2: summary preserves surviving stitched_000002 descriptor and omits retired one")

	# Validate surviving descriptor remains valid for RunRestStitchCards.
	var validator := RunRestStitchCards.new(deck_removed, desc_removed, 0, cursor)
	_check(validator.is_valid(), "AC2: surviving composite descriptor is still valid for RunRestStitchCards")

	_check(summary.get("worn_total") == 3, "AC2: worn_total is 3 (spare_spool in inventory is not counted)")
	var worn_ids: Array = summary.get("worn_ids", [])
	_check(not worn_ids.has("button_eye"), "AC2: displaced patch button_eye absent from worn_ids")
	_check(not worn_ids.has("spare_spool"), "AC2: unsewn inventory patch spare_spool absent from worn_ids")
	_check(worn_ids == ["stitched_badge", "pincushion_arm", "quilted_coat"], "AC2: exact worn_ids matches latest wardrobe")

	var heroes_summary: Array = summary.get("heroes", [])
	_check(heroes_summary.size() == 3, "AC2: 3 hero rows")
	if heroes_summary.size() == 3:
		_check(heroes_summary[0].get("HEAD") == "" and heroes_summary[0].get("ARM") == "" and heroes_summary[0].get("COAT") == "",
			"AC2: Warden has no worn patches after re-sew")
		_check(heroes_summary[1].get("HEAD") == "stitched_badge" and heroes_summary[1].get("ARM") == "pincushion_arm" and heroes_summary[1].get("COAT") == "",
			"AC2: Seamstress has stitched_badge on HEAD and pincushion_arm on ARM")
		_check(heroes_summary[2].get("HEAD") == "" and heroes_summary[2].get("ARM") == "" and heroes_summary[2].get("COAT") == "quilted_coat",
			"AC2: Tinker has quilted_coat on COAT")


func _test_negative_matrix_detachment_and_rng() -> void:
	var heroes: Array = _load_party()
	var starter_deck: Array[String] = _load_starter_deck()

	# Create valid baseline.
	var stitch_1 := RunRestStitchCards.new(starter_deck, {}, 3, 1)
	var res_1: Dictionary = stitch_1.choose_stitch(starter_deck.find("warden_strike"), starter_deck.find("seamstress_prick"), stitch_1.get_snapshot())
	var valid_deck: Array[String] = []
	valid_deck.assign(res_1.get("deck", []))
	var valid_desc: Dictionary = res_1.get("descriptors", {}).duplicate(true)
	var valid_cursor: int = res_1.get("next_stitch_id", 2)

	var defs: Array = _authored_patch_definitions()
	var owned: Array = ["button_eye", "pincushion_arm", "quilted_coat"]
	var valid_wardrobe := RunPatchWardrobe.new(heroes, owned, defs, 1, 50, valid_deck, 101)
	valid_wardrobe.sew("button_eye", "warden", "HEAD", "op_w", valid_wardrobe.get_snapshot())

	var expected_empty: Dictionary = {
		"ok": false,
		"stitched_created": 0,
		"stitched_current": 0,
		"worn_total": 0,
		"heroes": [],
		"descriptors": {},
		"worn_ids": [],
		"stitched_ids": [],
	}

	# RNG setups
	var test_rng := RandomNumberGenerator.new()
	test_rng.seed = 24680
	var rng_initial_state: int = test_rng.state
	seed(97531)
	var global_initial_val: int = randi()
	seed(97531)

	# 1. Null / invalid wardrobe
	_check(RunSignatureSummary.summarize(valid_deck, valid_desc, valid_cursor, null) == expected_empty,
		"AC3: null wardrobe returns stable empty result")
	var invalid_wardrobe := RunPatchWardrobe.new(null, null, null, -1)
	_check(RunSignatureSummary.summarize(valid_deck, valid_desc, valid_cursor, invalid_wardrobe) == expected_empty,
		"AC3: invalid wardrobe returns stable empty result")

	# 2. Supplied deck different from wardrobe.cards
	var deck_extra: Array[String] = valid_deck.duplicate()
	deck_extra.append("warden_strike")
	_check(RunSignatureSummary.summarize(deck_extra, valid_desc, valid_cursor, valid_wardrobe) == expected_empty,
		"AC3: deck with extra card returns stable empty result")
	var deck_missing: Array[String] = valid_deck.slice(1)
	_check(RunSignatureSummary.summarize(deck_missing, valid_desc, valid_cursor, valid_wardrobe) == expected_empty,
		"AC3: deck with missing card returns stable empty result")
	var deck_reordered: Array[String] = valid_deck.duplicate()
	var temp: String = deck_reordered[0]
	deck_reordered[0] = deck_reordered[1]
	deck_reordered[1] = temp
	_check(RunSignatureSummary.summarize(deck_reordered, valid_desc, valid_cursor, valid_wardrobe) == expected_empty,
		"AC3: reordered deck returns stable empty result")

	# 3. Foreign / fake stitched ID
	var deck_fake_stitched: Array[String] = valid_deck.duplicate()
	deck_fake_stitched.append("stitched_000099")
	_check(RunSignatureSummary.summarize(deck_fake_stitched, valid_desc, valid_cursor, valid_wardrobe) == expected_empty,
		"AC3: fake stitched ID in deck returns stable empty result")
	var desc_fake_stitched: Dictionary = valid_desc.duplicate(true)
	desc_fake_stitched["stitched_000099"] = valid_desc["stitched_000001"].duplicate(true)
	_check(RunSignatureSummary.summarize(valid_deck, desc_fake_stitched, valid_cursor, valid_wardrobe) == expected_empty,
		"AC3: fake stitched ID in descriptors returns stable empty result")

	# 4. Forged half / descriptor
	var desc_forged_half: Dictionary = valid_desc.duplicate(true)
	desc_forged_half["stitched_000001"]["half_ids"] = ["warden_strike", "warden_strike"]
	_check(RunSignatureSummary.summarize(valid_deck, desc_forged_half, valid_cursor, valid_wardrobe) == expected_empty,
		"AC3: forged same-owner descriptor returns stable empty result")
	var desc_forged_cost: Dictionary = valid_desc.duplicate(true)
	desc_forged_cost["stitched_000001"]["cost"] = 99
	_check(RunSignatureSummary.summarize(valid_deck, desc_forged_cost, valid_cursor, valid_wardrobe) == expected_empty,
		"AC3: forged cost descriptor returns stable empty result")

	# 5. Cursor behind allocated serial
	_check(RunSignatureSummary.summarize(valid_deck, valid_desc, 1, valid_wardrobe) == expected_empty,
		"AC3: cursor behind allocated serial returns stable empty result")
	_check(RunSignatureSummary.summarize(valid_deck, valid_desc, 0, valid_wardrobe) == expected_empty,
		"AC3: cursor 0 returns stable empty result")
	_check(RunSignatureSummary.summarize(valid_deck, valid_desc, -5, valid_wardrobe) == expected_empty,
		"AC3: negative cursor returns stable empty result")

	# 6. Worn patch violations via CorruptedWardrobe
	var base_snap: Dictionary = valid_wardrobe.get_snapshot()

	# Unknown patch ID in worn
	var snap_unknown_patch: Dictionary = base_snap.duplicate(true)
	snap_unknown_patch["worn"]["warden"]["HEAD"] = "unknown_patch_xyz"
	_check(RunSignatureSummary.summarize(valid_deck, valid_desc, valid_cursor, CorruptedWardrobe.new(snap_unknown_patch)) == expected_empty,
		"AC3: unknown worn patch ID returns stable empty result")

	# Unowned patch ID in worn (defined but not in owned)
	var snap_unowned_patch: Dictionary = base_snap.duplicate(true)
	snap_unowned_patch["worn"]["warden"]["HEAD"] = "pincushion_arm"
	snap_unowned_patch["owned"] = ["button_eye", "quilted_coat"] # pincushion_arm removed from owned
	_check(RunSignatureSummary.summarize(valid_deck, valid_desc, valid_cursor, CorruptedWardrobe.new(snap_unowned_patch)) == expected_empty,
		"AC3: unowned worn patch ID returns stable empty result")

	# Wrong slot assignment in worn
	var snap_wrong_slot: Dictionary = base_snap.duplicate(true)
	snap_wrong_slot["worn"]["warden"]["HEAD"] = "pincushion_arm" # pincushion_arm is ARM, not HEAD
	_check(RunSignatureSummary.summarize(valid_deck, valid_desc, valid_cursor, CorruptedWardrobe.new(snap_wrong_slot)) == expected_empty,
		"AC3: wrong slot patch assignment returns stable empty result")

	# Duplicate worn patch assignment across party
	var snap_duplicate_worn: Dictionary = base_snap.duplicate(true)
	snap_duplicate_worn["worn"]["warden"]["HEAD"] = "button_eye"
	snap_duplicate_worn["worn"]["seamstress"]["HEAD"] = "button_eye"
	_check(RunSignatureSummary.summarize(valid_deck, valid_desc, valid_cursor, CorruptedWardrobe.new(snap_duplicate_worn)) == expected_empty,
		"AC3: duplicate worn patch ID returns stable empty result")

	# Missing hero in worn
	var snap_missing_hero: Dictionary = base_snap.duplicate(true)
	snap_missing_hero["worn"].erase("tinker")
	_check(RunSignatureSummary.summarize(valid_deck, valid_desc, valid_cursor, CorruptedWardrobe.new(snap_missing_hero)) == expected_empty,
		"AC3: missing hero in worn returns stable empty result")

	# Invalid slot container shape
	var snap_invalid_slot_shape: Dictionary = base_snap.duplicate(true)
	snap_invalid_slot_shape["worn"]["warden"] = ["button_eye"]
	_check(RunSignatureSummary.summarize(valid_deck, valid_desc, valid_cursor, CorruptedWardrobe.new(snap_invalid_slot_shape)) == expected_empty,
		"AC3: invalid slot container shape returns stable empty result")

	# Missing slot in hero slots
	var snap_missing_slot: Dictionary = base_snap.duplicate(true)
	snap_missing_slot["worn"]["warden"] = {"HEAD": "button_eye", "ARM": ""} # missing COAT
	_check(RunSignatureSummary.summarize(valid_deck, valid_desc, valid_cursor, CorruptedWardrobe.new(snap_missing_slot)) == expected_empty,
		"AC3: missing slot in hero container returns stable empty result")

	# 7. Invalid input types
	_check(RunSignatureSummary.summarize(null, valid_desc, valid_cursor, valid_wardrobe) == expected_empty, "AC3: null deck returns failure")
	_check(RunSignatureSummary.summarize(1234, valid_desc, valid_cursor, valid_wardrobe) == expected_empty, "AC3: int deck returns failure")
	_check(RunSignatureSummary.summarize("deck", valid_desc, valid_cursor, valid_wardrobe) == expected_empty, "AC3: string deck returns failure")
	_check(RunSignatureSummary.summarize([], valid_desc, valid_cursor, valid_wardrobe) == expected_empty, "AC3: empty deck returns failure")
	_check(RunSignatureSummary.summarize([123], valid_desc, valid_cursor, valid_wardrobe) == expected_empty, "AC3: deck with non-strings returns failure")

	_check(RunSignatureSummary.summarize(valid_deck, null, valid_cursor, valid_wardrobe) == expected_empty, "AC3: null descriptors returns failure")
	_check(RunSignatureSummary.summarize(valid_deck, [], valid_cursor, valid_wardrobe) == expected_empty, "AC3: array descriptors returns failure")
	_check(RunSignatureSummary.summarize(valid_deck, "desc", valid_cursor, valid_wardrobe) == expected_empty, "AC3: string descriptors returns failure")

	_check(RunSignatureSummary.summarize(valid_deck, valid_desc, null, valid_wardrobe) == expected_empty, "AC3: null cursor returns failure")
	_check(RunSignatureSummary.summarize(valid_deck, valid_desc, "2", valid_wardrobe) == expected_empty, "AC3: string cursor returns failure")
	_check(RunSignatureSummary.summarize(valid_deck, valid_desc, 2.5, valid_wardrobe) == expected_empty, "AC3: float cursor returns failure")

	_check(RunSignatureSummary.summarize(valid_deck, valid_desc, valid_cursor, 999) == expected_empty, "AC3: int wardrobe returns failure")
	_check(RunSignatureSummary.summarize(valid_deck, valid_desc, valid_cursor, "wardrobe") == expected_empty, "AC3: string wardrobe returns failure")
	_check(RunSignatureSummary.summarize(valid_deck, valid_desc, valid_cursor, {}) == expected_empty, "AC3: dict wardrobe returns failure")

	# 8. Detachment and mutation test
	var valid_summary: Dictionary = RunSignatureSummary.summarize(valid_deck, valid_desc, valid_cursor, valid_wardrobe)
	_check(valid_summary.get("ok") == true, "baseline summary succeeded")

	# Mutate returned hero entry and ID lists
	var heroes_out: Array = valid_summary.get("heroes", [])
	_check(heroes_out.size() == 3, "summary has 3 heroes")
	if heroes_out.size() > 0:
		var hero_0: Dictionary = heroes_out[0]
		hero_0["HEAD"] = "MUTATED_HEAD"
		hero_0["hero_id"] = "MUTATED_ID"
		var slots_dict: Dictionary = hero_0.get("slots", {})
		slots_dict["HEAD"] = "MUTATED_SLOT"
		heroes_out.clear()

	var worn_ids_out: Array = valid_summary.get("worn_ids", [])
	worn_ids_out.append("MUTATED_WORN_ID")

	var desc_out: Dictionary = valid_summary.get("descriptors", {})
	desc_out.clear()

	# Re-run summarize and verify authority is 100% unchanged
	var rerun_summary: Dictionary = RunSignatureSummary.summarize(valid_deck, valid_desc, valid_cursor, valid_wardrobe)
	_check(rerun_summary.get("ok") == true, "re-run summary succeeds")
	_check(rerun_summary.get("stitched_created") == 1, "stitched_created unchanged after mutation")
	_check(rerun_summary.get("stitched_current") == 1, "stitched_current unchanged after mutation")
	_check(rerun_summary.get("worn_total") == 1, "worn_total unchanged after mutation")
	var rerun_heroes: Array = rerun_summary.get("heroes", [])
	_check(rerun_heroes.size() == 3, "re-run heroes size is 3")
	if rerun_heroes.size() > 0:
		_check(rerun_heroes[0].get("hero_id") == "warden" and rerun_heroes[0].get("HEAD") == "button_eye",
			"re-run hero 0 is unchanged by prior mutation")
		_check(rerun_heroes[0].get("slots", {}).get("HEAD") == "button_eye",
			"re-run hero 0 slots is unchanged by prior mutation")
	_check(rerun_summary.get("worn_ids") == ["button_eye"], "re-run worn_ids unchanged by prior mutation")
	_check(rerun_summary.get("descriptors").size() == 1, "re-run descriptors unchanged by prior mutation")
	_check(valid_wardrobe.get_snapshot() == base_snap, "wardrobe snapshot unchanged after summary and mutations")

	# 9. RNG invariance across all calls
	_check(test_rng.state == rng_initial_state, "AC3: seeded test RNG state unchanged across all positive and negative calls")
	_check(randi() == global_initial_val, "AC3: global RNG state unchanged across all positive and negative calls")
