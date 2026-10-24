extends SceneTree
## Scene-free test for CombatPoolComboAttackPreview patch-power forecasting (M05).
## Verifies exact effect/receipt parity, ownership, thresholds, snapshots, detachment,
## negative/fail-closed coverage, and byte-for-byte legacy backward-compatibility.

var failures: Array[String] = []
var checks: int = 0
var oracle := CombatPoolComboAttackPreview.new()


func _initialize() -> void:
	_test_ac1_loose_thread_glove_unravel_bonus()
	_test_ac1_unravel_threshold_and_action_skip()
	_test_ac2_button_eye_exposed_timing_and_consumed_latch()
	_test_ac2_pincushion_arm_damage_bonus_and_weak_exposed()
	_test_ac2_pinning_jab_and_snip_the_seam_conditions()
	_test_ac2_cross_owner_pinned_bonus()
	_test_ac3_preview_immutability_and_repeated_calls()
	_test_ac3_fail_closed_and_mismatched_roster()
	_test_ac3_downed_torn_and_wrong_wearer()
	_test_ac4_legacy_compatibility_and_null_patches()
	_test_result_keys_integrity()

	if failures.is_empty():
		print("combat_pool_combo_attack_preview_patch_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("combat_pool_combo_attack_preview_patch_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)


func _build_fixture(card_ids: Array[String], seed_val: int = 4210,
		hero_order: Array[String] = ["warden", "seamstress", "tinker"],
		enemy_max_hps: Array[int] = [80, 80, 80],
		tiers: Dictionary = {1: "normal", 2: "elite", 3: "boss"},
		sew_specs: Array[Dictionary] = []) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var hand_ids: Array[String] = card_ids.duplicate()
	while hand_ids.size() < 5:
		hand_ids.append("warden_strike")
	var deck := CombatDeck.new(hand_ids, rng)
	_check(deck.start_turn() and deck.energy == 3 and deck.turn_active,
		"fixture: turn active with 3 energy")

	var hero_templates: Dictionary = {
		"warden": {"id": "warden", "max_hp": 40},
		"seamstress": {"id": "seamstress", "max_hp": 30},
		"tinker": {"id": "tinker", "max_hp": 26},
	}
	var heroes: Array[Dictionary] = []
	for hid in hero_order:
		if hero_templates.has(hid):
			heroes.append(hero_templates[hid].duplicate(true))
		else:
			heroes.append({"id": hid, "max_hp": 30})
	var party := CombatParty.new(heroes)
	_check(party.is_valid(), "fixture: valid party")

	var enemies_list: Array[Dictionary] = []
	for i in range(enemy_max_hps.size()):
		enemies_list.append({"id": "enemy_%d" % (i + 1), "max_hp": enemy_max_hps[i]})
	var enemies := CombatEnemies.new(enemies_list)
	_check(enemies.is_valid(), "fixture: valid enemies")

	var pinned := CombatPinned.new()
	var unravel := CombatUnravel.new()
	_check(unravel.bind_roster(enemies, tiers), "fixture: unravel bound to enemies")

	var first_attack := CombatTinkerFirstAttack.new()

	var wardrobe: RunPatchWardrobe = null
	var torn: RunTornMending = null
	var patches: CombatPatchAttackRules = null
	if not sew_specs.is_empty():
		var m04: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/patches/m04_attack_patches.json"))
		var m05: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/patches/m05_arm_support_patches.json"))
		var definitions: Array = []
		for entry: Variant in (m04 as Array):
			definitions.append({"id": entry["id"], "slot": entry["slot"]})
		for entry: Variant in (m05 as Array):
			definitions.append({"id": entry["id"], "slot": entry["slot"]})
		var owned: Array = []
		for spec: Dictionary in sew_specs:
			owned.append(spec["id"])
		var run_heroes: Array = [
			{"id": "warden", "max_hp": 40},
			{"id": "seamstress", "max_hp": 30},
			{"id": "tinker", "max_hp": 26},
		]
		var run_party := CombatParty.new(run_heroes)
		torn = RunTornMending.new(run_party.get_heroes())
		wardrobe = RunPatchWardrobe.new(run_party.get_heroes(), owned, definitions, 3)
		for spec: Dictionary in sew_specs:
			var sew_res: Dictionary = wardrobe.sew(
				spec["id"], spec["wearer"], spec["slot"], "sew_" + spec["id"], wardrobe.get_snapshot())
			_check(sew_res.get("ok", false), "fixture: sewn " + spec["id"] + " on " + spec["wearer"])
		patches = CombatPatchAttackRules.new()
		_check(patches.bind_wardrobe(wardrobe, torn), "fixture: bound patch rules")

	return {
		"deck": deck,
		"party": party,
		"enemies": enemies,
		"pinned": pinned,
		"unravel": unravel,
		"first_attack": first_attack,
		"wardrobe": wardrobe,
		"torn": torn,
		"patches": patches,
		"rng": rng,
	}


func _snapshot(f: Dictionary) -> Dictionary:
	var deck: CombatDeck = f["deck"]
	var party: CombatParty = f["party"]
	var enemies: CombatEnemies = f["enemies"]
	var pinned: CombatPinned = f["pinned"]
	var unravel: CombatUnravel = f["unravel"]
	var first_attack: CombatTinkerFirstAttack = f["first_attack"]
	var patches: CombatPatchAttackRules = f.get("patches", null)
	var wardrobe: RunPatchWardrobe = f.get("wardrobe", null)
	var torn: RunTornMending = f.get("torn", null)

	var token_map: Dictionary = pinned._pinner_by_position.duplicate(true)
	var gauge_map: Dictionary = unravel._gauges.duplicate(true)
	var patch_latch: Dictionary = patches.latch_snapshot() if patches != null else {}
	var patch_active: Dictionary = patches.active_snapshot() if patches != null else {}
	var wardrobe_snap: Dictionary = wardrobe.get_snapshot() if wardrobe != null else {}
	var torn_snap: Dictionary = torn.read_state() if torn != null else {}

	return {
		"hand": deck.hand.duplicate(),
		"draw": deck.draw_pile.duplicate(),
		"discard": deck.discard_pile.duplicate(),
		"energy": deck.energy,
		"turn_active": deck.turn_active,
		"rng_state": deck._rng.state,
		"heroes": party.get_heroes(),
		"enemies": enemies.get_enemies(),
		"pinned": token_map,
		"gauges": gauge_map,
		"first_attack_consumed": first_attack._consumed,
		"first_attack_bonus": first_attack._path_bonus,
		"patch_latch": patch_latch,
		"patch_active": patch_active,
		"wardrobe": wardrobe_snap,
		"torn": torn_snap,
	}


func _detached_commit(f: Dictionary, card_id: String, target_position: int,
		patches: CombatPatchAttackRules) -> Dictionary:
	var deck: CombatDeck = f["deck"]
	var party: CombatParty = f["party"]
	var enemies: CombatEnemies = f["enemies"]
	var pinned: CombatPinned = f["pinned"]
	var unravel: CombatUnravel = f["unravel"]
	var first_attack: CombatTinkerFirstAttack = f["first_attack"]

	var rng_copy := RandomNumberGenerator.new()
	rng_copy.seed = deck._rng.seed
	rng_copy.state = deck._rng.state
	var deck_copy := CombatDeck.new([], rng_copy)
	deck_copy.draw_pile.assign(deck.draw_pile)
	deck_copy.hand.assign(deck.hand)
	deck_copy.discard_pile.assign(deck.discard_pile)
	deck_copy.combat_state.player_turn_active = deck.turn_active
	deck_copy.combat_state.energy = deck.energy

	var party_copy := CombatParty.new(party.get_heroes())
	party_copy._heroes.assign(party.get_heroes())
	var enemies_copy := CombatEnemies.new(enemies.get_enemies())
	enemies_copy._enemies.assign(enemies.get_enemies())

	var pinned_copy := CombatPinned.new()
	pinned_copy._pinner_by_position = pinned._pinner_by_position.duplicate(true)
	var unravel_copy := CombatUnravel.new()
	unravel_copy.bind_roster(enemies_copy, unravel._tiers_by_position.duplicate(true))
	unravel_copy._gauges = unravel._gauges.duplicate(true)
	var latch_copy := CombatTinkerFirstAttack.new()
	latch_copy._consumed = first_attack._consumed
	latch_copy._path_bonus = first_attack._path_bonus

	var clone_patches: CombatPatchAttackRules = null
	if patches != null:
		clone_patches = CombatPatchAttackRules.new()
		clone_patches._valid = patches._valid
		clone_patches._active = patches._active.duplicate(true)
		clone_patches._consumed = patches._consumed.duplicate(true)
		clone_patches._worn = patches._worn.duplicate(true)
		clone_patches._living = patches._living.duplicate(true)

	var is_warden: bool = card_id.begins_with("warden_")
	var receipt: Dictionary
	if is_warden:
		var resolver := CombatWardenPoolComboAttacks.new(clone_patches)
		receipt = resolver.play_attack(
			deck_copy, party_copy, enemies_copy, pinned_copy, unravel_copy,
			card_id, target_position, clone_patches)
	else:
		var resolver := CombatTinkerPoolUnravelAttacks.new(latch_copy, unravel_copy, pinned_copy)
		resolver._patches = clone_patches
		receipt = resolver.play_attack(
			deck_copy, party_copy, enemies_copy, card_id, target_position)

	return {
		"receipt": receipt,
		"deck": deck_copy,
		"party": party_copy,
		"enemies": enemies_copy,
		"pinned": pinned_copy,
		"unravel": unravel_copy,
		"first_attack": latch_copy,
		"patches": clone_patches,
	}


func _verify_target_against_commit(target_dict: Dictionary, commit: Dictionary,
		is_warden: bool, context: String) -> void:
	_check(commit["receipt"].get("ok", false), context + ": detached commit succeeded")
	var hit: Dictionary = commit["receipt"]["hits"][0]
	var pos: int = target_dict["position"]
	var commit_enemies: CombatEnemies = commit["enemies"]
	var commit_unravel: CombatUnravel = commit["unravel"]
	var commit_pinned: CombatPinned = commit["pinned"]

	_check(target_dict["damage"] == hit["damage"], context + ": damage matches commit hit receipt")
	_check(target_dict["block_absorbed"] == hit["block_absorbed"], context + ": block_absorbed matches")
	_check(target_dict["hp_loss"] == hit["hp_loss"], context + ": hp_loss matches")
	_check(target_dict["hp_after"] == commit_enemies.get_enemy(pos)["hp"], context + ": hp_after matches")
	_check(target_dict["block_after"] == commit_enemies.get_enemy(pos)["block"], context + ": block_after matches")
	_check(target_dict["survives"] == (not commit_enemies.is_slain(pos)), context + ": survives matches")
	_check(target_dict["pin_owner_after"] == commit_pinned.pinner_for_enemy(pos), context + ": pin_owner_after matches")
	_check(target_dict["pin_consumed"] == (bool(hit.get("pin_consumed", false)) if is_warden else target_dict["pin_bonus"] > 0), context + ": pin_consumed matches")

	var commit_unravel_amount: int = int(hit.get("unravel_added", 0) if is_warden else hit.get("unravel", 0))
	_check(target_dict["unravel_added"] == commit_unravel_amount, context + ": unravel_added matches")
	_check(target_dict["unravel_after"] == commit_unravel.get_snapshot(pos), context + ": unravel_after matches snapshot")

	if commit_unravel.get_snapshot(pos).get("skip_pending", false) and not commit_enemies.is_slain(pos):
		_check(commit_unravel.consume_action_skip(commit_enemies, pos), context + ": commit skip consumed")
		_check(target_dict["after_action_skip"] == commit_unravel.get_snapshot(pos),
			context + ": after_action_skip matches commit post-skip snapshot")
	else:
		_check(target_dict["after_action_skip"].is_empty(), context + ": after_action_skip empty when no skip")


# =========================================================================
# AC1: Loose Thread Glove on Warden & Tinker +1 Unravel & Threshold 8 Skip
# =========================================================================
func _test_ac1_loose_thread_glove_unravel_bonus() -> void:
	# 1. Warden Seam Breaker (base: 7 dmg, 4 unravel; +1 glove -> 5 unravel)
	var f_sb := _build_fixture(["warden_seam_breaker"], 5001, ["warden", "seamstress", "tinker"],
		[80, 80, 80], {1: "normal", 2: "elite", 3: "boss"},
		[{"id": "loose_thread_glove", "wearer": "warden", "slot": "ARM"}])
	var prev_sb: Dictionary = oracle.get_preview(
		f_sb.deck, f_sb.party, f_sb.enemies, f_sb.pinned, f_sb.unravel,
		f_sb.first_attack, "warden_seam_breaker", 0, f_sb.patches)
	_check(prev_sb["playable"], "AC1: Seam Breaker with glove is playable")
	_check(prev_sb["target_positions"] == [1, 2], "AC1: Seam Breaker targets slots 1 and 2")
	_check(prev_sb["targets"].size() == 2, "AC1: forecasts both legal slots")
	for t in prev_sb["targets"]:
		_check(t["unravel_added"] == 5, "AC1: Seam Breaker predicts 5 unravel (4 base + 1 glove)")
		_check(t["damage"] == 7, "AC1: Seam Breaker predicts 7 damage")
		var commit := _detached_commit(f_sb, "warden_seam_breaker", t["position"], f_sb.patches)
		_verify_target_against_commit(t, commit, true, "AC1: Seam Breaker slot %d" % t["position"])

	# 2. Warden Seam Breaker+ (base: 10 dmg, 6 unravel; +1 glove -> 7 unravel)
	var f_sbp := _build_fixture(["warden_seam_breaker_plus"], 5002, ["warden", "seamstress", "tinker"],
		[80, 80, 80], {1: "normal", 2: "elite", 3: "boss"},
		[{"id": "loose_thread_glove", "wearer": "warden", "slot": "ARM"}])
	var prev_sbp: Dictionary = oracle.get_preview(
		f_sbp.deck, f_sbp.party, f_sbp.enemies, f_sbp.pinned, f_sbp.unravel,
		f_sbp.first_attack, "warden_seam_breaker_plus", 1, f_sbp.patches)
	_check(prev_sbp["playable"] and prev_sbp["targets"].size() == 1, "AC1: Seam Breaker+ requested position 1")
	var t_sbp: Dictionary = prev_sbp["targets"][0]
	_check(t_sbp["unravel_added"] == 7, "AC1: Seam Breaker+ predicts 7 unravel (6 base + 1 glove)")
	_check(t_sbp["damage"] == 10, "AC1: Seam Breaker+ predicts 10 damage")
	var commit_sbp := _detached_commit(f_sbp, "warden_seam_breaker_plus", 1, f_sbp.patches)
	_verify_target_against_commit(t_sbp, commit_sbp, true, "AC1: Seam Breaker+ slot 1")

	# 3. Tinker Spool Launcher (base: 3 dmg, 3 unravel; +1 glove -> 4 unravel; +3 first attack -> 6 dmg)
	var f_sl := _build_fixture(["tinker_spool_launcher"], 5003, ["warden", "seamstress", "tinker"],
		[80, 80, 80], {1: "normal", 2: "elite", 3: "boss"},
		[{"id": "loose_thread_glove", "wearer": "tinker", "slot": "ARM"}])
	var prev_sl: Dictionary = oracle.get_preview(
		f_sl.deck, f_sl.party, f_sl.enemies, f_sl.pinned, f_sl.unravel,
		f_sl.first_attack, "tinker_spool_launcher", 0, f_sl.patches)
	_check(prev_sl["playable"], "AC1: Spool Launcher with glove is playable")
	_check(prev_sl["target_positions"] == [1, 2, 3], "AC1: Spool Launcher targets slots 1, 2, 3")
	for t in prev_sl["targets"]:
		_check(t["unravel_added"] == 4, "AC1: Spool Launcher predicts 4 unravel (3 base + 1 glove)")
		_check(t["damage"] == 6, "AC1: Spool Launcher predicts 6 damage (3 base + 3 first attack)")
		var commit := _detached_commit(f_sl, "tinker_spool_launcher", t["position"], f_sl.patches)
		_verify_target_against_commit(t, commit, false, "AC1: Spool Launcher slot %d" % t["position"])

	# 4. Tinker Spool Launcher+ (base: 4 dmg, 4 unravel; +1 glove -> 5 unravel; +3 first attack -> 7 dmg)
	var f_slp := _build_fixture(["tinker_spool_launcher_plus"], 5004, ["warden", "seamstress", "tinker"],
		[80, 80, 80], {1: "normal", 2: "elite", 3: "boss"},
		[{"id": "loose_thread_glove", "wearer": "tinker", "slot": "ARM"}])
	var prev_slp: Dictionary = oracle.get_preview(
		f_slp.deck, f_slp.party, f_slp.enemies, f_slp.pinned, f_slp.unravel,
		f_slp.first_attack, "tinker_spool_launcher_plus", 2, f_slp.patches)
	_check(prev_slp["playable"] and prev_slp["targets"].size() == 1, "AC1: Spool Launcher+ requested position 2")
	var t_slp: Dictionary = prev_slp["targets"][0]
	_check(t_slp["unravel_added"] == 5, "AC1: Spool Launcher+ predicts 5 unravel (4 base + 1 glove)")
	_check(t_slp["damage"] == 7, "AC1: Spool Launcher+ predicts 7 damage (4 base + 3 first attack)")
	var commit_slp := _detached_commit(f_slp, "tinker_spool_launcher_plus", 2, f_slp.patches)
	_verify_target_against_commit(t_slp, commit_slp, false, "AC1: Spool Launcher+ slot 2")


func _test_ac1_unravel_threshold_and_action_skip() -> void:
	# Test reaching threshold 8 with Loose Thread Glove:
	# Normal threshold is 8. Set enemy 1 gauge to 3.
	# Warden Seam Breaker adds 5 (4 + 1 glove). 3 + 5 = 8 (threshold reached!).
	var f := _build_fixture(["warden_seam_breaker"], 5005, ["warden", "seamstress", "tinker"],
		[80, 80, 80], {1: "normal", 2: "elite", 3: "boss"},
		[{"id": "loose_thread_glove", "wearer": "warden", "slot": "ARM"}])
	_check(f.unravel.apply_unravel(f.enemies, 1, 3), "precondition: enemy 1 unravel set to 3")
	_check(f.unravel.get_snapshot(1)["gauge"] == 3, "enemy 1 gauge is 3/8")

	var prev: Dictionary = oracle.get_preview(
		f.deck, f.party, f.enemies, f.pinned, f.unravel,
		f.first_attack, "warden_seam_breaker", 1, f.patches)
	_check(prev["playable"], "AC1: Seam Breaker threshold forecast playable")
	var t: Dictionary = prev["targets"][0]
	_check(t["unravel_before"]["gauge"] == 3 and t["unravel_before"]["threshold"] == 8,
		"AC1: unravel_before is 3/8")
	_check(t["unravel_after"]["gauge"] == 8 and t["unravel_after"]["threshold"] == 8,
		"AC1: unravel_after is 8/8")
	_check(t["unravel_after"]["skip_pending"] == true, "AC1: unravel_after marks skip_pending")
	_check(t["after_action_skip"]["gauge"] == 0 and t["after_action_skip"]["threshold"] == 12,
		"AC1: after_action_skip models reset to 0/12 threshold")
	_check(t["after_action_skip"]["skip_pending"] == false, "AC1: after_action_skip pending cleared")

	var commit := _detached_commit(f, "warden_seam_breaker", 1, f.patches)
	_verify_target_against_commit(t, commit, true, "AC1: threshold 8 skip verification")


# =========================================================================
# AC2: Button Eye timing/latch, Pincushion Arm + Weak/Exposed, Pinning Jab, Snip
# =========================================================================
func _test_ac2_button_eye_exposed_timing_and_consumed_latch() -> void:
	# HEAD button_eye adds Exposed 1 AFTER first confirmed attack, not to its own damage.
	var f := _build_fixture(["warden_seam_breaker"], 6001, ["warden", "seamstress", "tinker"],
		[80, 80, 80], {1: "normal", 2: "elite", 3: "boss"},
		[{"id": "button_eye", "wearer": "warden", "slot": "HEAD"}])
	var prev: Dictionary = oracle.get_preview(
		f.deck, f.party, f.enemies, f.pinned, f.unravel,
		f.first_attack, "warden_seam_breaker", 1, f.patches)
	_check(prev["playable"], "AC2: Warden with Button Eye playable")
	var t: Dictionary = prev["targets"][0]
	# Damage must be 7, NOT 7 * 1.5 = 10 (Exposed is not added retroactively to this hit)
	_check(t["damage"] == 7, "AC2: Button Eye Exposed 1 not added to first hit damage")
	_check(t["hp_loss"] == 7, "AC2: hp_loss is 7")
	_check(t["hp_after"] == 73, "AC2: hp_after is 73")
	var commit := _detached_commit(f, "warden_seam_breaker", 1, f.patches)
	_verify_target_against_commit(t, commit, true, "AC2: Button Eye first hit commit")
	_check(commit["enemies"].get_enemy(1).get("statuses", {}).get("exposed", 0) == 1,
		"AC2: commit enemy 1 gained Exposed 1 after hit")
	_check(commit["patches"].latch_snapshot()["warden"] == true,
		"AC2: commit patches recorded warden attack and consumed latch")

	# Now test when Button Eye is ALREADY consumed:
	f.patches.record_successful_attack("warden")
	_check(f.patches.latch_snapshot()["warden"] == true, "precondition: latch consumed on live patch rules")
	var prev_consumed: Dictionary = oracle.get_preview(
		f.deck, f.party, f.enemies, f.pinned, f.unravel,
		f.first_attack, "warden_seam_breaker", 1, f.patches)
	_check(prev_consumed["playable"], "AC2: playable with consumed latch")
	var t_c: Dictionary = prev_consumed["targets"][0]
	_check(t_c["damage"] == 7, "AC2: damage remains 7 with consumed latch")
	var commit_consumed := _detached_commit(f, "warden_seam_breaker", 1, f.patches)
	_verify_target_against_commit(t_c, commit_consumed, true, "AC2: consumed latch commit")
	_check(commit_consumed["enemies"].get_enemy(1).get("statuses", {}).get("exposed", 0) == 0,
		"AC2: no new Exposed status when Button Eye was already consumed")


func _test_ac2_pincushion_arm_damage_bonus_and_weak_exposed() -> void:
	# ARM pincushion_arm adds +1 attack damage before Weak (-25%) and Exposed (+50%) floor rounding.
	# Case 1: Plain (no status) -> 7 + 1 = 8 damage; no +1 unravel (4 unravel).
	var f := _build_fixture(["warden_seam_breaker"], 6002, ["warden", "seamstress", "tinker"],
		[80, 80, 80], {1: "normal", 2: "elite", 3: "boss"},
		[{"id": "pincushion_arm", "wearer": "warden", "slot": "ARM"}])
	var prev: Dictionary = oracle.get_preview(
		f.deck, f.party, f.enemies, f.pinned, f.unravel,
		f.first_attack, "warden_seam_breaker", 1, f.patches)
	_check(prev["playable"], "AC2: Pincushion Arm playable")
	var t: Dictionary = prev["targets"][0]
	_check(t["damage"] == 8, "AC2: Pincushion Arm adds +1 damage (7 + 1 = 8)")
	_check(t["unravel_added"] == 4, "AC2: Pincushion Arm does NOT add unravel (stays 4)")
	var commit := _detached_commit(f, "warden_seam_breaker", 1, f.patches)
	_verify_target_against_commit(t, commit, true, "AC2: Pincushion Arm plain commit")

	# Case 2: Attacker is Weak (floor(8 * 0.75) = 6).
	# Note: without Pincushion, 7 * 0.75 = floor(5.25) = 5.
	f.party._heroes[0]["statuses"] = {"weak": 1}
	var prev_weak: Dictionary = oracle.get_preview(
		f.deck, f.party, f.enemies, f.pinned, f.unravel,
		f.first_attack, "warden_seam_breaker", 1, f.patches)
	var t_weak: Dictionary = prev_weak["targets"][0]
	_check(t_weak["damage"] == 6, "AC2: Pincushion +1 before Weak floor rounding: floor(8 * 0.75) = 6")
	var commit_weak := _detached_commit(f, "warden_seam_breaker", 1, f.patches)
	_verify_target_against_commit(t_weak, commit_weak, true, "AC2: Pincushion Weak commit")

	# Case 3: Defender is Exposed (floor(8 * 1.5) = 12).
	f.party._heroes[0]["statuses"] = {}
	_check(f.enemies.apply_statuses({1: {"exposed": 1}}), "precondition: Enemy 1 gained Exposed 1")
	var prev_exp: Dictionary = oracle.get_preview(
		f.deck, f.party, f.enemies, f.pinned, f.unravel,
		f.first_attack, "warden_seam_breaker", 1, f.patches)
	var t_exp: Dictionary = prev_exp["targets"][0]
	_check(t_exp["damage"] == 12, "AC2: Pincushion +1 before Exposed floor rounding: floor(8 * 1.5) = 12")
	var commit_exp := _detached_commit(f, "warden_seam_breaker", 1, f.patches)
	_verify_target_against_commit(t_exp, commit_exp, true, "AC2: Pincushion Exposed commit")


func _test_ac2_pinning_jab_and_snip_the_seam_conditions() -> void:
	# Pinning Jab does NOT gain Unravel from Loose Thread Glove.
	var f_pj := _build_fixture(["warden_pinning_jab", "warden_pinning_jab_plus"], 6003,
		["warden", "seamstress", "tinker"], [80, 80, 80], {1: "normal", 2: "elite", 3: "boss"},
		[{"id": "loose_thread_glove", "wearer": "warden", "slot": "ARM"}])
	var prev_pj: Dictionary = oracle.get_preview(
		f_pj.deck, f_pj.party, f_pj.enemies, f_pj.pinned, f_pj.unravel,
		f_pj.first_attack, "warden_pinning_jab", 1, f_pj.patches)
	_check(prev_pj["playable"], "AC2: Pinning Jab with glove playable")
	var t_pj: Dictionary = prev_pj["targets"][0]
	_check(t_pj["damage"] == 4, "AC2: Pinning Jab base damage 4")
	_check(t_pj["unravel_added"] == 0, "AC2: Pinning Jab gains NO unravel from glove")
	_check(t_pj["pin_applied"] == true, "AC2: Pinning Jab applies pin")
	_check(t_pj["pin_owner_after"] == "warden", "AC2: Pinning Jab pins by warden")
	var commit_pj := _detached_commit(f_pj, "warden_pinning_jab", 1, f_pj.patches)
	_verify_target_against_commit(t_pj, commit_pj, true, "AC2: Pinning Jab commit")

	# Snip the Seam does NOT gain Unravel from Loose Thread Glove.
	# Condition: base deals 5, conditional deals 15 (if target unravelled or gauge >= half threshold).
	var f_snip := _build_fixture(["tinker_snip_the_seam", "tinker_snip_the_seam_plus"], 6004,
		["warden", "seamstress", "tinker"], [80, 80, 80], {1: "normal", 2: "elite", 3: "boss"},
		[{"id": "loose_thread_glove", "wearer": "tinker", "slot": "ARM"}])
	# Consume Tinker first attack latch to test raw card damage
	f_snip.first_attack._consumed = true

	# 1. Unempowered: gauge is 0, threshold 8 (0 * 2 < 8).
	var prev_unemp: Dictionary = oracle.get_preview(
		f_snip.deck, f_snip.party, f_snip.enemies, f_snip.pinned, f_snip.unravel,
		f_snip.first_attack, "tinker_snip_the_seam", 1, f_snip.patches)
	_check(prev_unemp["playable"], "AC2: Snip the Seam unempowered playable")
	var t_unemp: Dictionary = prev_unemp["targets"][0]
	_check(t_unemp["damage"] == 5, "AC2: Snip the Seam unempowered deals 5 damage")
	_check(t_unemp["unravel_added"] == 0, "AC2: Snip the Seam gains NO unravel from glove")
	_check(t_unemp["conditional_empowered"] == false, "AC2: not conditional_empowered")
	var commit_unemp := _detached_commit(f_snip, "tinker_snip_the_seam", 1, f_snip.patches)
	_verify_target_against_commit(t_unemp, commit_unemp, false, "AC2: Snip unempowered commit")

	# 2. Empowered: set gauge to 4 (4 * 2 >= 8). Deals 15 damage!
	_check(f_snip.unravel.apply_unravel(f_snip.enemies, 1, 4), "precondition: set enemy 1 unravel to 4")
	var prev_emp: Dictionary = oracle.get_preview(
		f_snip.deck, f_snip.party, f_snip.enemies, f_snip.pinned, f_snip.unravel,
		f_snip.first_attack, "tinker_snip_the_seam", 1, f_snip.patches)
	var t_emp: Dictionary = prev_emp["targets"][0]
	_check(t_emp["damage"] == 15, "AC2: Snip the Seam empowered deals 15 damage")
	_check(t_emp["unravel_added"] == 0, "AC2: Snip the Seam empowered gains NO unravel")
	_check(t_emp["conditional_empowered"] == true, "AC2: conditional_empowered is true")
	var commit_emp := _detached_commit(f_snip, "tinker_snip_the_seam", 1, f_snip.patches)
	_verify_target_against_commit(t_emp, commit_emp, false, "AC2: Snip empowered commit")

	# 3. Snip the Seam+: unempowered 7, empowered 20.
	var prev_plus: Dictionary = oracle.get_preview(
		f_snip.deck, f_snip.party, f_snip.enemies, f_snip.pinned, f_snip.unravel,
		f_snip.first_attack, "tinker_snip_the_seam_plus", 1, f_snip.patches)
	var t_plus: Dictionary = prev_plus["targets"][0]
	_check(t_plus["damage"] == 20, "AC2: Snip the Seam+ empowered deals 20 damage")
	_check(t_plus["unravel_added"] == 0, "AC2: Snip the Seam+ gains NO unravel")
	_check(t_plus["conditional_empowered"] == true, "AC2: Snip+ conditional_empowered")
	var commit_plus := _detached_commit(f_snip, "tinker_snip_the_seam_plus", 1, f_snip.patches)
	_verify_target_against_commit(t_plus, commit_plus, false, "AC2: Snip+ empowered commit")


func _test_ac2_cross_owner_pinned_bonus() -> void:
	# Pinned cross-owner bonus is +5 before Weak/Exposed and is consumed once.
	var f := _build_fixture(["warden_seam_breaker"], 6005, ["warden", "seamstress", "tinker"],
		[80, 80, 80], {1: "normal", 2: "elite", 3: "boss"},
		[{"id": "loose_thread_glove", "wearer": "warden", "slot": "ARM"}])
	# Pin enemy 1 by Seamstress (different owner)
	_check(f.pinned.pin_enemy(f.enemies, 1, "seamstress"), "precondition: Seamstress pinned enemy 1")

	var prev: Dictionary = oracle.get_preview(
		f.deck, f.party, f.enemies, f.pinned, f.unravel,
		f.first_attack, "warden_seam_breaker", 1, f.patches)
	_check(prev["playable"], "AC2: Pinned cross-owner forecast playable")
	var t: Dictionary = prev["targets"][0]
	# 7 base + 5 pin = 12 damage. Unravel is 4 + 1 glove = 5.
	_check(t["damage"] == 12, "AC2: cross-owner pin adds +5 damage (7 + 5 = 12)")
	_check(t["pin_bonus"] == 5, "AC2: pin_bonus is 5")
	_check(t["pin_consumed"] == true, "AC2: pin_consumed is true")
	_check(t["pin_owner_after"] == "", "AC2: pin_owner_after cleared")
	_check(t["unravel_added"] == 5, "AC2: unravel_added is 5")
	var commit := _detached_commit(f, "warden_seam_breaker", 1, f.patches)
	_verify_target_against_commit(t, commit, true, "AC2: cross-owner pin commit")


# =========================================================================
# AC3: Invariants, immutability, repeated previews, detachment, fail-closed
# =========================================================================
func _test_ac3_preview_immutability_and_repeated_calls() -> void:
	var f := _build_fixture(["warden_seam_breaker"], 7001, ["warden", "seamstress", "tinker"],
		[80, 80, 80], {1: "normal", 2: "elite", 3: "boss"},
		[
			{"id": "button_eye", "wearer": "warden", "slot": "HEAD"},
			{"id": "loose_thread_glove", "wearer": "warden", "slot": "ARM"},
		])
	var snap_before := _snapshot(f)

	# Preview 0 (all legal targets)
	var prev1 := oracle.get_preview(f.deck, f.party, f.enemies, f.pinned, f.unravel, f.first_attack, "warden_seam_breaker", 0, f.patches)
	# Preview specific target
	var prev2 := oracle.get_preview(f.deck, f.party, f.enemies, f.pinned, f.unravel, f.first_attack, "warden_seam_breaker", 1, f.patches)
	# Preview again
	var prev3 := oracle.get_preview(f.deck, f.party, f.enemies, f.pinned, f.unravel, f.first_attack, "warden_seam_breaker", 0, f.patches)

	var snap_after := _snapshot(f)
	_check(snap_before == snap_after, "AC3: live state completely unchanged after 3 previews")
	_check(prev1 == prev3, "AC3: preview twice produces identical projections")
	_check(f.patches.latch_snapshot()["warden"] == false, "AC3: patch latch not consumed in live authority")

	# Detachment / mutation test: mutate prev1 deeply in place
	prev1["playable"] = false
	prev1["targets"][0]["damage"] = 9999
	prev1["target_positions"].append(999)
	var fresh := oracle.get_preview(f.deck, f.party, f.enemies, f.pinned, f.unravel, f.first_attack, "warden_seam_breaker", 0, f.patches)
	_check(fresh["playable"] == true, "AC3: fresh preview unaffected by in-place mutation of prior dict")
	_check(fresh["targets"][0]["damage"] == 7, "AC3: fresh damage unaffected")
	_check(fresh["target_positions"] == [1, 2], "AC3: fresh target_positions unaffected")


func _test_ac3_fail_closed_and_mismatched_roster() -> void:
	var f := _build_fixture(["warden_seam_breaker"], 7002, ["warden", "seamstress", "tinker"],
		[80, 80, 80], {1: "normal", 2: "elite", 3: "boss"},
		[{"id": "loose_thread_glove", "wearer": "warden", "slot": "ARM"}])

	# 1. Empty / unbound patch authority fails closed
	var unbound := CombatPatchAttackRules.new()
	var prev_unbound := oracle.get_preview(
		f.deck, f.party, f.enemies, f.pinned, f.unravel, f.first_attack, "warden_seam_breaker", 0, unbound)
	_check(not prev_unbound["playable"], "AC3: unbound patch authority fails closed")
	_check(prev_unbound["targets"].is_empty(), "AC3: unbound returns empty targets")

	# 2. Corrupted / invalid explicit patch authority fails closed
	var corrupted := CombatPatchAttackRules.new()
	corrupted._valid = false
	var prev_corrupted := oracle.get_preview(
		f.deck, f.party, f.enemies, f.pinned, f.unravel, f.first_attack, "warden_seam_breaker", 0, corrupted)
	_check(not prev_corrupted["playable"], "AC3: invalid patch authority fails closed")

	# 3. Mismatched party roster (foreign hero in party)
	var foreign_party := CombatParty.new([
		{"id": "goblin", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
	])
	var prev_mismatched := oracle.get_preview(
		f.deck, foreign_party, f.enemies, f.pinned, f.unravel, f.first_attack, "warden_seam_breaker", 0, f.patches)
	_check(not prev_mismatched["playable"], "AC3: mismatched party roster fails closed")

	# 4. Wrong hero position (Warden swapped to position 3; Seam Breaker requires 1-2)
	var f_pos := _build_fixture(["warden_seam_breaker"], 7003, ["warden", "seamstress", "tinker"],
		[80, 80, 80], {1: "normal", 2: "elite", 3: "boss"},
		[{"id": "loose_thread_glove", "wearer": "warden", "slot": "ARM"}])
	f_pos.party = CombatParty.new([
		{"id": "tinker", "max_hp": 26},
		{"id": "seamstress", "max_hp": 30},
		{"id": "warden", "max_hp": 40},
	])
	var prev_wrong_pos := oracle.get_preview(
		f_pos.deck, f_pos.party, f_pos.enemies, f_pos.pinned, f_pos.unravel,
		f_pos.first_attack, "warden_seam_breaker", 1, f_pos.patches)
	_check(not prev_wrong_pos["playable"], "AC3: Warden at position 3 fails closed for Seam Breaker")

	# 5. Unavailable energy (cost 2, energy 1)
	f.deck.try_spend_energy(2) # energy now 1
	_check(f.deck.energy == 1, "precondition: deck energy is 1")
	var prev_energy := oracle.get_preview(
		f.deck, f.party, f.enemies, f.pinned, f.unravel, f.first_attack, "warden_seam_breaker", 1, f.patches)
	_check(not prev_energy["playable"], "AC3: insufficient energy fails closed")

	# 6. Slain target: requested position 1 when enemy 1 is slain
	var f_slain := _build_fixture(["warden_seam_breaker"], 7004, ["warden", "seamstress", "tinker"],
		[80, 80, 80], {1: "normal", 2: "elite", 3: "boss"},
		[{"id": "loose_thread_glove", "wearer": "warden", "slot": "ARM"}])
	_check(f_slain.enemies.apply_damage(1, 80) and f_slain.enemies.is_slain(1), "enemy 1 slain")
	var prev_slain_req := oracle.get_preview(
		f_slain.deck, f_slain.party, f_slain.enemies, f_slain.pinned, f_slain.unravel,
		f_slain.first_attack, "warden_seam_breaker", 1, f_slain.patches)
	_check(not prev_slain_req["playable"], "AC3: requesting slain enemy slot 1 fails closed")
	# Requested 0 skips slain slot 1 and returns only legal slot 2
	var prev_slain_all := oracle.get_preview(
		f_slain.deck, f_slain.party, f_slain.enemies, f_slain.pinned, f_slain.unravel,
		f_slain.first_attack, "warden_seam_breaker", 0, f_slain.patches)
	_check(prev_slain_all["playable"], "AC3: requested 0 with one slain target is playable")
	_check(prev_slain_all["target_positions"] == [2], "AC3: only living slot 2 returned")
	_check(prev_slain_all["targets"].size() == 1, "AC3: exactly 1 target simulated")

	# 7. Unsupported card ID
	var prev_unsupported := oracle.get_preview(
		f.deck, f.party, f.enemies, f.pinned, f.unravel, f.first_attack, "fake_card_id", 0, f.patches)
	_check(not prev_unsupported["playable"], "AC3: unsupported card ID fails closed")


func _test_ac3_downed_torn_and_wrong_wearer() -> void:
	# Downed card owner: Warden is downed in party -> cannot play, fails closed.
	var f_down := _build_fixture(["warden_seam_breaker"], 7005, ["warden", "seamstress", "tinker"],
		[80, 80, 80], {1: "normal", 2: "elite", 3: "boss"},
		[{"id": "loose_thread_glove", "wearer": "warden", "slot": "ARM"}])
	_check(f_down.party.apply_damage(1, 40) and f_down.party.is_downed(1), "precondition: Warden downed")
	var prev_down := oracle.get_preview(
		f_down.deck, f_down.party, f_down.enemies, f_down.pinned, f_down.unravel,
		f_down.first_attack, "warden_seam_breaker", 1, f_down.patches)
	_check(not prev_down["playable"], "AC3: downed attacker fails closed")

	# Another hero wearing the patch: Seamstress wears Loose Thread Glove, Warden plays Seam Breaker.
	# Warden gets no glove bonus, deals original unpatched 4 unravel and 7 damage.
	var f_other := _build_fixture(["warden_seam_breaker"], 7006, ["warden", "seamstress", "tinker"],
		[80, 80, 80], {1: "normal", 2: "elite", 3: "boss"},
		[{"id": "loose_thread_glove", "wearer": "seamstress", "slot": "ARM"}])
	var prev_other := oracle.get_preview(
		f_other.deck, f_other.party, f_other.enemies, f_other.pinned, f_other.unravel,
		f_other.first_attack, "warden_seam_breaker", 1, f_other.patches)
	_check(prev_other["playable"], "AC3: Warden playable when Seamstress wears glove")
	_check(prev_other["targets"][0]["unravel_added"] == 4,
		"AC3: Warden gets unpatched 4 unravel when other hero wears glove")
	_check(prev_other["targets"][0]["damage"] == 7, "AC3: Warden gets unpatched 7 damage")

	# Torn wearer: Warden was marked torn in RunTornMending.
	# In wardrobe projection, worn glove is inactive for torn wearer -> returns unpatched values.
	var f_torn := _build_fixture(["warden_seam_breaker"], 7007, ["warden", "seamstress", "tinker"],
		[80, 80, 80], {1: "normal", 2: "elite", 3: "boss"},
		[{"id": "loose_thread_glove", "wearer": "warden", "slot": "ARM"}])
	# Record battle end tear for warden:
	var start_heroes: Array = f_torn.torn.read_state()["heroes"]
	var end_heroes: Array = start_heroes.duplicate(true)
	end_heroes[0]["hp"] = 0
	_check(f_torn.torn.observe_battle_end("battle_tear", start_heroes, end_heroes).get("ok", false),
		"precondition: combat tear recorded in torn mending")
	_check(f_torn.patches.bind_wardrobe(f_torn.wardrobe, f_torn.torn),
		"rebound patches reflects torn wearer")
	_check(f_torn.patches.card_unravel_bonus("warden", "warden_seam_breaker") == 0,
		"torn wearer has 0 unravel bonus")
	var prev_torn := oracle.get_preview(
		f_torn.deck, f_torn.party, f_torn.enemies, f_torn.pinned, f_torn.unravel,
		f_torn.first_attack, "warden_seam_breaker", 1, f_torn.patches)
	_check(prev_torn["playable"], "AC3: living battle party playable with torn run ledger")
	_check(prev_torn["targets"][0]["unravel_added"] == 4,
		"AC3: torn wearer receives unpatched 4 unravel")


# =========================================================================
# AC4: Legacy compatibility (8 args & null patches), parity with unpatched
# =========================================================================
func _test_ac4_legacy_compatibility_and_null_patches() -> void:
	var f := _build_fixture(["warden_seam_breaker"], 8001, ["warden", "seamstress", "tinker"],
		[80, 80, 80], {1: "normal", 2: "elite", 3: "boss"}, [])

	# 1. Legacy 8-parameter call (no patches argument passed)
	var legacy_call: Dictionary = oracle.get_preview(
		f.deck, f.party, f.enemies, f.pinned, f.unravel,
		f.first_attack, "warden_seam_breaker", 0)
	_check(legacy_call["playable"], "AC4: legacy 8-arg call is playable")
	_check(legacy_call["targets"].size() == 2, "AC4: legacy returns 2 targets")
	_check(legacy_call["targets"][0]["unravel_added"] == 4, "AC4: legacy unravel is 4 (unpatched)")
	_check(legacy_call["targets"][0]["damage"] == 7, "AC4: legacy damage is 7 (unpatched)")

	# 2. 9-parameter call with explicit null patches
	var null_patches_call: Dictionary = oracle.get_preview(
		f.deck, f.party, f.enemies, f.pinned, f.unravel,
		f.first_attack, "warden_seam_breaker", 0, null)
	_check(null_patches_call == legacy_call, "AC4: null patches call exactly matches 8-arg legacy call")

	# 3. Tinker legacy call
	var f_t := _build_fixture(["tinker_spool_launcher"], 8002, ["warden", "seamstress", "tinker"],
		[80, 80, 80], {1: "normal", 2: "elite", 3: "boss"}, [])
	var t_legacy: Dictionary = oracle.get_preview(
		f_t.deck, f_t.party, f_t.enemies, f_t.pinned, f_t.unravel,
		f_t.first_attack, "tinker_spool_launcher", 1)
	var t_null: Dictionary = oracle.get_preview(
		f_t.deck, f_t.party, f_t.enemies, f_t.pinned, f_t.unravel,
		f_t.first_attack, "tinker_spool_launcher", 1, null)
	_check(t_legacy["playable"] and t_null == t_legacy, "AC4: Tinker null patches matches 8-arg legacy call")
	_check(t_legacy["targets"][0]["unravel_added"] == 3, "AC4: Tinker legacy unravel is 3 (unpatched)")


# =========================================================================
# Result keys integrity check
# =========================================================================
func _test_result_keys_integrity() -> void:
	var f := _build_fixture(["warden_seam_breaker"], 9001, ["warden", "seamstress", "tinker"],
		[80, 80, 80], {1: "normal", 2: "elite", 3: "boss"},
		[{"id": "loose_thread_glove", "wearer": "warden", "slot": "ARM"}])
	var prev: Dictionary = oracle.get_preview(
		f.deck, f.party, f.enemies, f.pinned, f.unravel,
		f.first_attack, "warden_seam_breaker", 1, f.patches)
	_check(prev["playable"], "result keys test: playable")

	var expected_top_keys: Array[String] = [
		"playable", "requires_selection", "target_positions", "card_id", "cost", "targets"
	]
	for k in expected_top_keys:
		_check(prev.has(k), "result keys: top-level has '%s'" % k)
	_check(prev.size() == expected_top_keys.size(), "result keys: exact top-level size")

	var expected_target_keys: Array[String] = [
		"position", "damage", "block_absorbed", "hp_loss", "hp_after", "block_after",
		"survives", "pin_bonus", "pin_owner_before", "pin_owner_after", "pin_consumed",
		"pin_applied", "unravel_added", "unravel_before", "unravel_after", "after_action_skip",
		"tinker_first_attack_bonus", "conditional_empowered", "target_hp_before", "target_block_before"
	]
	var t: Dictionary = prev["targets"][0]
	for k in expected_target_keys:
		_check(t.has(k), "result keys: target has '%s'" % k)
	_check(t.size() == expected_target_keys.size(), "result keys: exact target dictionary size")
