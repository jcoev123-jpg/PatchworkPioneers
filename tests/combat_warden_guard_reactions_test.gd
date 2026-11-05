extends SceneTree
const LEGACY_ENTRY := preload("res://tests/legacy_card_app_fixture.gd")
## Deterministic headless test for CombatWardenGuardReactions (D2-1).
## Validates Draw Fire, Counter-stitch, Guarding redirection, Thorns retaliation,
## movement following, turn lifecycle, and negative fail-closed behavior.

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run_all_suites")


func _run_all_suites() -> void:
	_test_ac1_draw_fire_guarding()
	_test_ac2_counter_stitch_thorns()
	_test_ac3_reactions_sequential_and_movement()
	_test_ac4_lifecycle_and_rejections()
	_test_hand_spend()
	_test_v3_buckle_rebound_paid_and_retaliation()
	_test_v3_buckle_rebound_refusals_and_patches()
	_test_v3_guard_cards_paid_and_interception()
	_test_v3_guard_cards_refusals()
	_test_v3_final_bastion_paid_and_interaction()
	_test_patch_block_projection_ac1()
	_test_patch_wearer_and_binding_ac2()
	_test_patch_negative_and_stale_ac3()
	await _test_real_mounted_hand()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("combat_warden_guard_reactions_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("combat_warden_guard_reactions_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _party() -> CombatParty:
	var party: CombatParty = CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
	])
	_check(party.is_valid() and party.get_heroes().size() == 3, "fixture party is valid")
	return party


func _enemies() -> CombatEnemies:
	var enemies: CombatEnemies = CombatEnemies.new([
		{"id": "ragling-a", "max_hp": 12},
		{"id": "ragling-b", "max_hp": 15},
	])
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2, "fixture enemies is valid")
	return enemies


## Case 1 (AC1): real catalog and party fixture, Draw Fire vs +, exact 6/8 Block and Guarding,
## legal/from-state rejection, no spend or leakage to other heroes.
func _test_ac1_draw_fire_guarding() -> void:
	var catalog: WardenPoolCards = WardenPoolCards.new()
	var draw_fire: Dictionary = catalog.get_definition("warden_draw_fire")
	var draw_fire_plus: Dictionary = catalog.get_definition("warden_draw_fire_plus")

	_check(not draw_fire.is_empty(), "authored warden_draw_fire exists")
	_check(not draw_fire_plus.is_empty(), "authored warden_draw_fire_plus exists")
	_check(draw_fire.get("cost") == 1 and draw_fire.get("from_positions") == [1], "Draw Fire cost 1, from 1")
	_check(draw_fire_plus.get("cost") == 1 and draw_fire_plus.get("from_positions") == [1], "Draw Fire+ cost 1, from 1")

	# Base Draw Fire: 6 Block + Guarding
	var party: CombatParty = _party()
	var initial_allies: Array = [party.get_hero(2), party.get_hero(3)]
	var reactions: CombatWardenGuardReactions = CombatWardenGuardReactions.new()

	_check(reactions.apply_committed_card(draw_fire, party), "AC1: Draw Fire applied to party")
	_check(party.get_hero(1)["block"] == 6, "AC1: Warden gains exact 6 Block")
	_check(party.get_hero(1)["hp"] == 40, "AC1: Warden HP untouched")
	_check([party.get_hero(2), party.get_hero(3)] == initial_allies, "AC1: Seamstress and Tinker untouched")
	_check(reactions.is_guarding() == true, "AC1: Guarding mode is active")
	_check(reactions.get_thorns() == 0, "AC1: Draw Fire does not grant Thorns")

	# Draw Fire+: 8 Block + Guarding
	var party_plus: CombatParty = _party()
	var initial_allies_plus: Array = [party_plus.get_hero(2), party_plus.get_hero(3)]
	var reactions_plus: CombatWardenGuardReactions = CombatWardenGuardReactions.new()

	_check(reactions_plus.apply_committed_card(draw_fire_plus, party_plus), "AC1: Draw Fire+ applied to party")
	_check(party_plus.get_hero(1)["block"] == 8, "AC1: Warden gains exact 8 Block from +")
	_check(party_plus.get_hero(1)["hp"] == 40, "AC1: Warden HP untouched from +")
	_check([party_plus.get_hero(2), party_plus.get_hero(3)] == initial_allies_plus, "AC1: allies untouched from +")
	_check(reactions_plus.is_guarding() == true, "AC1: Guarding mode is active from +")
	_check(reactions_plus.get_thorns() == 0, "AC1: Draw Fire+ does not grant Thorns")

	# Wrong from-position rejection: Warden at position 2
	var preview: Dictionary = CombatPositionSwaps.preview_adjacent_swap(party, 1, 1)
	_check(preview.get("ok", false), "adjacent swap preview is valid")
	var swapped_party: CombatParty = CombatParty.new(preview.get("heroes", []))
	_check(swapped_party.is_valid() and swapped_party.get_hero(2)["id"] == "warden",
		"swapped party has Warden at position 2")
	var swapped_snapshot: Array = swapped_party.get_heroes()
	var reactions_pos2: CombatWardenGuardReactions = CombatWardenGuardReactions.new()

	_check(not reactions_pos2.apply_committed_card(draw_fire, swapped_party),
		"AC1: Draw Fire rejects when Warden is at position 2")
	_check(swapped_party.get_heroes() == swapped_snapshot,
		"AC1: swapped party state completely unchanged on rejection")
	_check(reactions_pos2.is_guarding() == false, "AC1: Guarding not activated on rejection")

	# Wrong from-position for Draw Fire+ as well
	_check(not reactions_pos2.apply_committed_card(draw_fire_plus, swapped_party),
		"AC1: Draw Fire+ rejects when Warden is at position 2")
	_check(swapped_party.get_heroes() == swapped_snapshot,
		"AC1: swapped party state remains unchanged after Draw Fire+ rejection")


## Case 2 (AC2): Counter-stitch vs +, exact 5/7 Block and 3/4 Thorns, no implicit Guarding,
## legal from pos 1 or 2, and mode coexistence.
func _test_ac2_counter_stitch_thorns() -> void:
	var catalog: WardenPoolCards = WardenPoolCards.new()
	var counter_stitch: Dictionary = catalog.get_definition("warden_counter_stitch")
	var counter_stitch_plus: Dictionary = catalog.get_definition("warden_counter_stitch_plus")

	_check(not counter_stitch.is_empty(), "authored warden_counter_stitch exists")
	_check(not counter_stitch_plus.is_empty(), "authored warden_counter_stitch_plus exists")
	_check(counter_stitch.get("cost") == 1 and counter_stitch.get("from_positions") == [1, 2],
		"Counter-stitch cost 1, from [1, 2]")
	_check(counter_stitch_plus.get("cost") == 1 and counter_stitch_plus.get("from_positions") == [1, 2],
		"Counter-stitch+ cost 1, from [1, 2]")

	# Base Counter-stitch: 5 Block + Thorns 3
	var party: CombatParty = _party()
	var reactions: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(reactions.apply_committed_card(counter_stitch, party), "AC2: Counter-stitch applied from pos 1")
	_check(party.get_hero(1)["block"] == 5, "AC2: Warden gains exact 5 Block")
	_check(reactions.is_guarding() == false, "AC2: Counter-stitch does not grant Guarding")
	_check(reactions.get_thorns() == 3, "AC2: Counter-stitch grants exact Thorns 3")

	# Verify incoming attack triggers 3 retaliation damage
	var enemies: CombatEnemies = _enemies()
	var attack_incoming: Dictionary = {"enemy_position": 1, "target_position": 1, "amount": 2}
	var res: Dictionary = reactions.resolve_enemy_attack(party, enemies, attack_incoming)
	_check(res.get("ok") == true and res.get("applied") == true, "AC2: attack resolved against Warden")
	_check(res.get("redirected") == false, "AC2: not redirected")
	_check(res.get("retaliation_damage") == 3, "AC2: retaliation damage is exact 3")
	_check(party.get_hero(1)["block"] == 3 and party.get_hero(1)["hp"] == 40,
		"AC2: Warden 5 Block absorbed 2 damage, remaining 3 Block")
	_check(enemies.get_enemy(1)["hp"] == 9 and enemies.get_enemy(1)["block"] == 0,
		"AC2: enemy took exact 3 Thorns retaliation damage")

	# Upgraded Counter-stitch+: 7 Block + Thorns 4
	var party_plus: CombatParty = _party()
	var reactions_plus: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(reactions_plus.apply_committed_card(counter_stitch_plus, party_plus), "AC2: Counter-stitch+ applied")
	_check(party_plus.get_hero(1)["block"] == 7, "AC2: Warden gains exact 7 Block from +")
	_check(reactions_plus.is_guarding() == false, "AC2: Counter-stitch+ does not grant Guarding")
	_check(reactions_plus.get_thorns() == 4, "AC2: Counter-stitch+ grants exact Thorns 4")

	# Verify incoming attack triggers 4 retaliation damage
	var enemies_plus: CombatEnemies = _enemies()
	var res_plus: Dictionary = reactions_plus.resolve_enemy_attack(party_plus, enemies_plus, attack_incoming)
	_check(res_plus.get("retaliation_damage") == 4, "AC2: Counter-stitch+ retaliation damage is exact 4")
	_check(enemies_plus.get_enemy(1)["hp"] == 8, "AC2: enemy took exact 4 Thorns retaliation damage")

	# Counter-stitch from position 2 is legal
	var preview: Dictionary = CombatPositionSwaps.preview_adjacent_swap(party, 1, 1)
	var swapped_party: CombatParty = CombatParty.new(preview.get("heroes", []))
	var reactions_pos2: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(reactions_pos2.apply_committed_card(counter_stitch, swapped_party),
		"AC2: Counter-stitch is legal with Warden at position 2")
	_check(swapped_party.get_hero(2)["block"] == 5, "AC2: Warden at position 2 gains 5 Block")
	_check(reactions_pos2.get_thorns() == 3, "AC2: Warden gains Thorns 3 from position 2")

	# Coexistence of Guarding and Thorns
	var coex_reactions: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	var coex_party: CombatParty = _party()
	var draw_fire: Dictionary = catalog.get_definition("warden_draw_fire")
	_check(coex_reactions.apply_committed_card(draw_fire, coex_party), "AC2: apply Draw Fire")
	_check(coex_reactions.apply_committed_card(counter_stitch, coex_party), "AC2: apply Counter-stitch")
	_check(coex_reactions.is_guarding() == true, "AC2: Guarding mode coexists")
	_check(coex_reactions.get_thorns() == 3, "AC2: Thorns mode coexists")
	_check(coex_party.get_hero(1)["block"] == 11, "AC2: combined 6 + 5 = 11 Block on Warden")


## Case 3 (AC3): two living enemies hit original/moved/Guarding Warden with Block absorption,
## enemy HP/Block retaliation, combined modes, direct and redirected targets and source order.
func _test_ac3_reactions_sequential_and_movement() -> void:
	var catalog: WardenPoolCards = WardenPoolCards.new()
	var draw_fire: Dictionary = catalog.get_definition("warden_draw_fire")
	var counter_stitch: Dictionary = catalog.get_definition("warden_counter_stitch")

	var party: CombatParty = _party()
	var enemies: CombatEnemies = _enemies()
	# Enemy 2 starts with 4 Block
	_check(enemies.gain_block(2, 4), "enemy 2 prepares 4 Block")

	var reactions: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(reactions.apply_committed_card(draw_fire, party), "prep: Draw Fire committed")
	_check(reactions.apply_committed_card(counter_stitch, party), "prep: Counter-stitch committed")
	_check(party.get_hero(1)["block"] == 11, "prep: Warden has 11 Block")
	_check(reactions.is_guarding() == true and reactions.get_thorns() == 3, "prep: Guarding and Thorns 3 active")

	var attack1: Dictionary = {"enemy_position": 1, "target_position": 2, "amount": 4}
	var attack1_copy: Dictionary = attack1.duplicate(true)

	# Attack 1: Enemy 1 attacks Seamstress (target 2) -> redirected to Warden (target 1)
	var res1: Dictionary = reactions.resolve_enemy_attack(party, enemies, attack1)
	_check(attack1 == attack1_copy, "AC3: resolution preserves caller attack dictionary")
	_check(res1.get("ok") == true and res1.get("applied") == true, "AC3: attack 1 successfully applied")
	_check(res1.get("target_position") == 1, "AC3: redirected target is position 1")
	_check(res1.get("redirected") == true, "AC3: attack 1 redirected flag is true")
	_check(res1.get("retaliation_damage") == 3, "AC3: attack 1 retaliation damage is 3")
	_check(party.get_hero(1)["block"] == 7 and party.get_hero(1)["hp"] == 40,
		"AC3: Warden Block absorbs 4 damage (11 -> 7), HP stays 40")
	_check(party.get_hero(2)["hp"] == 30 and party.get_hero(2)["block"] == 0,
		"AC3: Seamstress protected by Guarding, takes 0 damage")
	_check(enemies.get_enemy(1)["hp"] == 9 and enemies.get_enemy(1)["block"] == 0,
		"AC3: source 1 took 3 Thorns retaliation (12 -> 9 HP)")

	# Attack 2: Enemy 2 attacks Warden directly (target 1) for 9 damage
	var attack2: Dictionary = {"enemy_position": 2, "target_position": 1, "amount": 9}
	var attack2_copy: Dictionary = attack2.duplicate(true)
	var res2: Dictionary = reactions.resolve_enemy_attack(party, enemies, attack2)
	_check(attack2 == attack2_copy, "AC3: resolution preserves attack 2 dictionary")
	_check(res2.get("ok") == true and res2.get("applied") == true, "AC3: attack 2 successfully applied")
	_check(res2.get("target_position") == 1, "AC3: target position remains 1")
	_check(res2.get("redirected") == false, "AC3: direct attack on Warden is not redirected")
	_check(res2.get("retaliation_damage") == 3, "AC3: attack 2 retaliation damage is 3")
	_check(party.get_hero(1)["block"] == 0 and party.get_hero(1)["hp"] == 38,
		"AC3: Warden absorbs remaining 7 Block, takes 2 damage to HP (40 -> 38)")
	_check(enemies.get_enemy(2)["block"] == 1 and enemies.get_enemy(2)["hp"] == 15,
		"AC3: enemy 2 Block absorbs all 3 Thorns retaliation (4 -> 1 Block, HP 15 intact)")

	# Movement fixture: lawful swap follows Warden by ID
	var moved_party_base: CombatParty = _party()
	var swap_preview: Dictionary = CombatPositionSwaps.preview_adjacent_swap(moved_party_base, 1, 1)
	_check(swap_preview.get("ok", false), "AC3: swap preview succeeded")
	var moved_party: CombatParty = CombatParty.new(swap_preview.get("heroes", []))
	_check(moved_party.get_hero(1)["id"] == "seamstress" and moved_party.get_hero(2)["id"] == "warden",
		"AC3: Warden is now at position 2, Seamstress at position 1")

	# Warden plays Counter-stitch from position 2
	var moved_reactions: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(moved_reactions.apply_committed_card(counter_stitch, moved_party),
		"AC3: Counter-stitch played by Warden at position 2")
	# Manually set guarding for the moved test fixture
	moved_reactions.guarding = true

	var enemies_moved: CombatEnemies = _enemies()
	# Enemy attacks Tinker at position 3
	var attack_tinker: Dictionary = {"enemy_position": 1, "target_position": 3, "amount": 2}
	var res_moved: Dictionary = moved_reactions.resolve_enemy_attack(moved_party, enemies_moved, attack_tinker)
	_check(res_moved.get("ok") == true and res_moved.get("applied") == true, "AC3: moved attack applied")
	_check(res_moved.get("target_position") == 2, "AC3: attack redirected to Warden's CURRENT position 2")
	_check(res_moved.get("redirected") == true, "AC3: attack marked redirected")
	_check(res_moved.get("retaliation_damage") == 3, "AC3: moved Warden retaliates with 3 Thorns")
	_check(moved_party.get_hero(2)["block"] == 3 and moved_party.get_hero(2)["hp"] == 40,
		"AC3: Warden at pos 2 absorbs 2 damage with Block (5 -> 3)")
	_check(moved_party.get_hero(3)["hp"] == 26 and moved_party.get_hero(3)["block"] == 0,
		"AC3: Tinker at pos 3 completely unharmed")
	_check(enemies_moved.get_enemy(1)["hp"] == 9, "AC3: enemy took 3 retaliation damage from moved Warden")


## Case 4 (AC4): next-turn expiry, slain/downed handling, malformed input rejection,
## unaltered snapshots on failed preflight and deterministic repeat.
func _test_ac4_lifecycle_and_rejections() -> void:
	var catalog: WardenPoolCards = WardenPoolCards.new()
	var draw_fire: Dictionary = catalog.get_definition("warden_draw_fire")
	var counter_stitch: Dictionary = catalog.get_definition("warden_counter_stitch")

	# 1. Turn lifecycle expiry
	var party: CombatParty = _party()
	var reactions: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(reactions.apply_committed_card(draw_fire, party), "apply Draw Fire")
	_check(reactions.apply_committed_card(counter_stitch, party), "apply Counter-stitch")
	_check(reactions.is_guarding() == true and reactions.get_thorns() == 3, "modes active")

	# Begin player turn: clears modes without resetting Block
	_check(reactions.begin_player_turn(), "AC4: begin_player_turn succeeds")
	_check(reactions.is_guarding() == false, "AC4: Guarding expired")
	_check(reactions.get_thorns() == 0, "AC4: Thorns expired")
	_check(party.get_hero(1)["block"] == 11, "AC4: Warden Block untouched by reactions.begin_player_turn")

	# Standard CombatParty reset resets Block
	_check(party.start_player_turn(), "CombatParty resets Block")
	_check(party.get_hero(1)["block"] == 0, "Warden Block reset by party")

	# Post-expiry attack does not redirect and does not retaliate
	var enemies: CombatEnemies = _enemies()
	var attack_post: Dictionary = {"enemy_position": 1, "target_position": 2, "amount": 5}
	var res_post: Dictionary = reactions.resolve_enemy_attack(party, enemies, attack_post)
	_check(res_post.get("ok") == true and res_post.get("applied") == true, "AC4: post-expiry attack resolves")
	_check(res_post.get("target_position") == 2, "AC4: no redirection after expiry")
	_check(res_post.get("redirected") == false, "AC4: redirected is false")
	_check(res_post.get("retaliation_damage") == 0, "AC4: no retaliation after expiry")
	_check(party.get_hero(2)["hp"] == 25, "AC4: Seamstress took direct 5 damage")
	_check(enemies.get_enemy(1)["hp"] == 12, "AC4: enemy took 0 retaliation damage")

	# 2. Slain source handling
	party = _party()
	enemies = _enemies()
	_check(enemies.apply_damage(1, 12) and enemies.is_slain(1), "slay enemy 1")
	var party_snap: Array = party.get_heroes()
	var enemies_snap: Array = enemies.get_enemies()
	reactions.guarding = true
	reactions.thorns = 3

	var dead_attack: Dictionary = {"enemy_position": 1, "target_position": 1, "amount": 6}
	var dead_res: Dictionary = reactions.resolve_enemy_attack(party, enemies, dead_attack)
	_check(dead_res.get("ok") == true and dead_res.get("applied") == false,
		"AC4: slain source attack is skipped")
	_check(dead_res.get("retaliation_damage") == 0, "AC4: slain source triggers no phantom retaliation")
	_check(party.get_heroes() == party_snap and enemies.get_enemies() == enemies_snap,
		"AC4: slain source causes zero party/enemy mutation")

	# 3. Downed target handling (with Guarding active)
	_check(party.apply_damage(2, 30) and party.is_downed(2), "down Seamstress")
	party_snap = party.get_heroes()
	enemies_snap = enemies.get_enemies()
	var downed_target_attack: Dictionary = {"enemy_position": 2, "target_position": 2, "amount": 5}
	var downed_res: Dictionary = reactions.resolve_enemy_attack(party, enemies, downed_target_attack)
	_check(downed_res.get("ok") == true and downed_res.get("applied") == false,
		"AC4: downed target attack is skipped, not redirected")
	_check(downed_res.get("retaliation_damage") == 0,
		"AC4: downed target creates no phantom retaliation")
	_check(party.get_heroes() == party_snap and enemies.get_enemies() == enemies_snap,
		"AC4: downed target causes zero party/enemy mutation")

	# 4. Downed Warden handling
	party = _party()
	_check(party.apply_damage(1, 40) and party.is_downed(1), "down Warden")
	party_snap = party.get_heroes()
	var downed_warden_reactions: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(not downed_warden_reactions.apply_committed_card(draw_fire, party),
		"AC4: card play rejected when Warden is downed")
	_check(party.get_heroes() == party_snap, "AC4: party untouched after downed Warden rejection")
	_check(not downed_warden_reactions.apply_committed_card(counter_stitch, party),
		"AC4: Counter-stitch rejected when Warden is downed")

	downed_warden_reactions.guarding = true
	downed_warden_reactions.thorns = 3
	# Attack on living hero with downed Warden does not redirect to downed Warden
	var attack_living: Dictionary = {"enemy_position": 1, "target_position": 2, "amount": 4}
	var res_dw: Dictionary = downed_warden_reactions.resolve_enemy_attack(party, enemies, attack_living)
	_check(res_dw.get("target_position") == 2 and res_dw.get("redirected") == false,
		"AC4: attack on living ally does not redirect to downed Warden")
	_check(res_dw.get("retaliation_damage") == 0, "AC4: no retaliation when Warden is downed")

	# 5. Malformed card rejection
	party = _party()
	party_snap = party.get_heroes()
	var bad_reactions: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(not bad_reactions.apply_committed_card(null, party), "null card rejected")
	_check(not bad_reactions.apply_committed_card("fake_card_id", party), "unknown card rejected")
	_check(not bad_reactions.apply_committed_card("warden_strike", party), "non-reaction pool card rejected")
	_check(not bad_reactions.apply_committed_card({"id": "warden_draw_fire", "owner": "seamstress"}, party),
		"wrong owner rejected")
	_check(not bad_reactions.apply_committed_card({"id": "warden_draw_fire", "effects": {"block": 999}}, party),
		"tampered effects rejected")
	_check(party.get_heroes() == party_snap, "AC4: malformed card preflight leaves party unchanged")

	# Absent Warden in party
	var no_warden_party: CombatParty = CombatParty.new([
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
		{"id": "tinker_two", "max_hp": 26},
	])
	_check(not bad_reactions.apply_committed_card(draw_fire, no_warden_party),
		"AC4: absent Warden rejected")

	# 6. Malformed attack rejection
	party = _party()
	enemies = _enemies()
	party_snap = party.get_heroes()
	enemies_snap = enemies.get_enemies()

	var malformed_attacks: Array = [
		{},
		{"target_position": 1, "amount": 5},
		{"enemy_position": 1, "amount": 5},
		{"enemy_position": 1, "target_position": 1},
		{"enemy_position": 0, "target_position": 1, "amount": 5},
		{"enemy_position": 3, "target_position": 1, "amount": 5}, # only 2 enemies
		{"enemy_position": -1, "target_position": 1, "amount": 5},
		{"enemy_position": 1, "target_position": 0, "amount": 5},
		{"enemy_position": 1, "target_position": 4, "amount": 5},
		{"enemy_position": 1, "target_position": 1, "amount": -1},
		{"enemy_position": "1", "target_position": 1, "amount": 5},
		{"enemy_position": 1, "target_position": "1", "amount": 5},
		{"enemy_position": 1, "target_position": 1, "amount": "5"},
		{"enemy_position": 1, "target_position": 1, "amount": 5, "type": "defend"},
	]

	for bad_atk: Dictionary in malformed_attacks:
		var bad_res: Dictionary = reactions.resolve_enemy_attack(party, enemies, bad_atk)
		_check(bad_res.get("ok") == false, "AC4: malformed attack rejected: " + str(bad_atk))
		_check(party.get_heroes() == party_snap and enemies.get_enemies() == enemies_snap,
			"AC4: malformed attack leaves combat snapshots unchanged")

	_check(reactions.resolve_enemy_attack(null, enemies, {"enemy_position": 1, "target_position": 1, "amount": 1}).get("ok") == false,
		"null party rejected")
	_check(reactions.resolve_enemy_attack(party, null, {"enemy_position": 1, "target_position": 1, "amount": 1}).get("ok") == false,
		"null enemies rejected")

	# 7. Deterministic repeat
	var replay_results: Array = []
	for rep: int in range(3):
		var r_party: CombatParty = _party()
		var r_enemies: CombatEnemies = _enemies()
		var r_reactions: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
		r_reactions.apply_committed_card(draw_fire, r_party)
		r_reactions.apply_committed_card(counter_stitch, r_party)
		var atk_rep: Dictionary = {"enemy_position": 1, "target_position": 2, "amount": 3}
		var r_res: Dictionary = r_reactions.resolve_enemy_attack(r_party, r_enemies, atk_rep)
		var rep_pack: Array = [r_res, r_party.get_heroes(), r_enemies.get_enemies()]
		if rep == 0:
			replay_results = rep_pack.duplicate(true)
		else:
			_check(rep_pack == replay_results, "AC4: deterministic repeat produces exact identical results")


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _deck(cards: Array[String], seed_value: int = 7, start: bool = true) -> CombatDeck:
	var deck := CombatDeck.new(cards, _rng(seed_value))
	if start:
		_check(deck.start_turn() and deck.turn_active and deck.energy == CombatState.TURN_ENERGY,
			"hand-spend deck starts turn")
	return deck


## Hand-spend (paid) plays via play_from_hand (D2-1).
func _test_hand_spend() -> void:
	var catalog: WardenPoolCards = WardenPoolCards.new()

	# AC1: both Draw Fire variants, Warden at slot 1
	for variant in ["warden_draw_fire", "warden_draw_fire_plus"]:
		var expected_block: int = 6 if variant == "warden_draw_fire" else 8
		var cards: Array[String] = [variant, variant]
		var deck: CombatDeck = _deck(cards, 11, true)
		# ensure at least one held copy (hand already has 5 drawn; may or may not include variant)
		# Arrange: move one copy into hand if absent by direct hand injection? Use real deck: place variant in hand.
		# We'll rebuild hand deterministically: clear and set hand to include variant.
		deck.hand.clear()
		deck.hand.append(variant)
		deck.hand.append(variant)
		var party: CombatParty = _party()
		var reactions: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
		var rng_before: int = deck._rng.state
		var hand_before: Array = deck.hand.duplicate()
		var discard_before: Array = deck.discard_pile.duplicate()
		var energy_before: int = deck.energy
		var warden_block_before: int = party.get_hero(1)["block"]
		_check(reactions.play_from_hand(deck, party, variant), "HS AC1: " + variant + " plays")
		_check(party.get_hero(1)["block"] == warden_block_before + expected_block,
			"HS AC1: " + variant + " exact block")
		_check(reactions.is_guarding() == true, "HS AC1: " + variant + " guarding")
		_check(reactions.get_thorns() == 0, "HS AC1: " + variant + " no thorns")
		_check(deck.energy == energy_before - 1, "HS AC1: " + variant + " energy -1")
		_check(deck.hand.size() == hand_before.size() - 1, "HS AC1: " + variant + " one copy removed")
		_check(deck.discard_pile.size() == discard_before.size() + 1, "HS AC1: " + variant + " one discard")
		_check(deck._rng.state == rng_before, "HS AC1: " + variant + " RNG unchanged")
		# second copy remains
		_check(deck.hand.has(variant), "HS AC1: " + variant + " second copy remains")

	# AC2: both Counter-stitch variants at slots 1 and 2
	for variant in ["warden_counter_stitch", "warden_counter_stitch_plus"]:
		var expected_block: int = 5 if variant == "warden_counter_stitch" else 7
		var expected_thorns: int = 3 if variant == "warden_counter_stitch" else 4
		# slot 1
		for slot_setup in [1, 2]:
			var cards2: Array[String] = [variant]
			var deck2: CombatDeck = _deck(cards2, 13, true)
			deck2.hand.clear()
			deck2.hand.append(variant)
			var party2: CombatParty = _party()
			var reactions2: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
			if slot_setup == 2:
				var preview: Dictionary = CombatPositionSwaps.preview_adjacent_swap(party2, 1, 1)
				var swapped: CombatParty = CombatParty.new(preview.get("heroes", []))
				party2 = swapped
			_check(reactions2.play_from_hand(deck2, party2, variant),
				"HS AC2: " + variant + " plays at slot " + str(slot_setup))
			var wpos: int = 1 if slot_setup == 1 else 2
			_check(party2.get_hero(wpos)["block"] == expected_block,
				"HS AC2: " + variant + " block at slot " + str(slot_setup))
			_check(reactions2.get_thorns() == expected_thorns,
				"HS AC2: " + variant + " thorns at slot " + str(slot_setup))
			_check(reactions2.is_guarding() == false,
				"HS AC2: " + variant + " no guarding")
			_check(deck2.energy == CombatState.TURN_ENERGY - 1,
				"HS AC2: " + variant + " energy -1")
			# resolve enemy hit
			var enemies2: CombatEnemies = _enemies()
			var atk: Dictionary = {"enemy_position": 1, "target_position": wpos, "amount": 1}
			var res: Dictionary = reactions2.resolve_enemy_attack(party2, enemies2, atk)
			_check(res.get("retaliation_damage") == expected_thorns,
				"HS AC2: " + variant + " retaliation")
			_check(enemies2.get_enemy(1)["hp"] == 12 - expected_thorns,
				"HS AC2: " + variant + " enemy loses thorns")
			# begin next turn clears
			_check(reactions2.begin_player_turn(), "HS AC2: begin turn")
			_check(reactions2.is_guarding() == false and reactions2.get_thorns() == 0,
				"HS AC2: " + variant + " cleared")

	# AC3: both cards in one hand, 3 energy
	var cards3: Array[String] = ["warden_draw_fire", "warden_counter_stitch"]
	var deck3: CombatDeck = _deck(cards3, 17, true)
	deck3.hand.clear()
	deck3.hand.append("warden_draw_fire")
	deck3.hand.append("warden_counter_stitch")
	var party3: CombatParty = _party()
	var reactions3: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	var rng3_before: int = deck3._rng.state
	_check(reactions3.play_from_hand(deck3, party3, "warden_draw_fire"), "HS AC3: draw fire plays")
	_check(reactions3.play_from_hand(deck3, party3, "warden_counter_stitch"), "HS AC3: counter stitch plays")
	_check(party3.get_hero(1)["block"] == 11, "HS AC3: 11 block")
	_check(reactions3.is_guarding() == true, "HS AC3: guarding")
	_check(reactions3.get_thorns() == 3, "HS AC3: thorns 3")
	_check(deck3.energy == 1, "HS AC3: 1 energy left")
	_check(deck3._rng.state == rng3_before, "HS AC3: RNG unchanged")
	# enemy aimed at seamstress redirected, retaliates 3
	var enemies3: CombatEnemies = _enemies()
	var atk3: Dictionary = {"enemy_position": 1, "target_position": 2, "amount": 2}
	var res3: Dictionary = reactions3.resolve_enemy_attack(party3, enemies3, atk3)
	_check(res3.get("redirected") == true, "HS AC3: redirected")
	_check(res3.get("retaliation_damage") == 3, "HS AC3: retaliation 3")
	_check(enemies3.get_enemy(1)["hp"] == 9, "HS AC3: enemy loses 3")
	# next turn clears
	_check(reactions3.begin_player_turn(), "HS AC3: begin turn")
	_check(reactions3.is_guarding() == false and reactions3.get_thorns() == 0, "HS AC3: cleared")

	# AC4: negatives
	var party4: CombatParty = _party()
	var deck4: CombatDeck = _deck(["warden_draw_fire"], 19, true)
	deck4.hand.clear()
	# absent card
	var reactions4: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	var snap_party: Array = party4.get_heroes()
	var snap_hand: Array = deck4.hand.duplicate()
	var snap_discard: Array = deck4.discard_pile.duplicate()
	var snap_energy: int = deck4.energy
	var rng4_before: int = deck4._rng.state
	_check(not reactions4.play_from_hand(deck4, party4, "warden_draw_fire"), "HS AC4: absent card rejects")
	_check(deck4.hand == snap_hand and deck4.discard_pile == snap_discard, "HS AC4: no hand/discard change")
	_check(deck4.energy == snap_energy, "HS AC4: no energy change")
	_check(party4.get_heroes() == snap_party, "HS AC4: no party change")
	_check(deck4._rng.state == rng4_before, "HS AC4: RNG unchanged")

	# inactive turn
	var deck5: CombatDeck = CombatDeck.new(["warden_draw_fire"], _rng(21))
	# not started
	var party5: CombatParty = _party()
	var reactions5: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	deck5.hand.clear()
	deck5.hand.append("warden_draw_fire")
	_check(not reactions5.play_from_hand(deck5, party5, "warden_draw_fire"), "HS AC4: inactive turn rejects")

	# insufficient energy
	var deck6: CombatDeck = _deck(["warden_draw_fire"], 23, true)
	deck6.hand.clear()
	deck6.hand.append("warden_draw_fire")
	var party6: CombatParty = _party()
	var reactions6: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	# spend all energy
	_check(deck6.try_spend_energy(3), "spend all energy")
	_check(not reactions6.play_from_hand(deck6, party6, "warden_draw_fire"), "HS AC4: insufficient energy rejects")

	# bad ID
	var deck7: CombatDeck = _deck(["warden_draw_fire"], 29, true)
	deck7.hand.clear()
	deck7.hand.append("warden_draw_fire")
	var party7: CombatParty = _party()
	var reactions7: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(not reactions7.play_from_hand(deck7, party7, "fake_card"), "HS AC4: bad ID rejects")

	# Warden position 2 for Draw Fire
	var party8: CombatParty = _party()
	var preview8: Dictionary = CombatPositionSwaps.preview_adjacent_swap(party8, 1, 1)
	var swapped8: CombatParty = CombatParty.new(preview8.get("heroes", []))
	var deck8: CombatDeck = _deck(["warden_draw_fire"], 31, true)
	deck8.hand.clear()
	deck8.hand.append("warden_draw_fire")
	var reactions8: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(not reactions8.play_from_hand(deck8, swapped8, "warden_draw_fire"), "HS AC4: DF pos2 rejects")

	# Warden position 3 for Counter-stitch
	var party9: CombatParty = _party()
	# move warden to pos3 via two swaps
	var p9a: Dictionary = CombatPositionSwaps.preview_adjacent_swap(party9, 1, 1)
	var party9b: CombatParty = CombatParty.new(p9a.get("heroes", []))
	var p9b: Dictionary = CombatPositionSwaps.preview_adjacent_swap(party9b, 2, 1)
	var party9c: CombatParty = CombatParty.new(p9b.get("heroes", []))
	var deck9: CombatDeck = _deck(["warden_counter_stitch"], 37, true)
	deck9.hand.clear()
	deck9.hand.append("warden_counter_stitch")
	var reactions9: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(not reactions9.play_from_hand(deck9, party9c, "warden_counter_stitch"), "HS AC4: CS pos3 rejects")

	# downed Warden
	var party10: CombatParty = _party()
	_check(party10.apply_damage(1, 40), "down warden")
	var deck10: CombatDeck = _deck(["warden_draw_fire"], 41, true)
	deck10.hand.clear()
	deck10.hand.append("warden_draw_fire")
	var reactions10: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(not reactions10.play_from_hand(deck10, party10, "warden_draw_fire"), "HS AC4: downed warden rejects")

	# Block overflow
	var party11: CombatParty = _party()
	party11._heroes[0]["block"] = CombatParty.MAX_INT
	var deck11: CombatDeck = _deck(["warden_draw_fire"], 43, true)
	deck11.hand.clear()
	deck11.hand.append("warden_draw_fire")
	var reactions11: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(not reactions11.play_from_hand(deck11, party11, "warden_draw_fire"), "HS AC4: block overflow rejects")

	# Thorns overflow
	var party12: CombatParty = _party()
	var deck12: CombatDeck = _deck(["warden_counter_stitch"], 47, true)
	deck12.hand.clear()
	deck12.hand.append("warden_counter_stitch")
	var reactions12: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	reactions12.thorns = CombatParty.MAX_INT
	_check(not reactions12.play_from_hand(deck12, party12, "warden_counter_stitch"), "HS AC4: thorns overflow rejects")

	# invalid party
	var reactions13: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	var deck13: CombatDeck = _deck(["warden_draw_fire"], 53, true)
	deck13.hand.clear()
	deck13.hand.append("warden_draw_fire")
	_check(not reactions13.play_from_hand(deck13, CombatParty.new([]), "warden_draw_fire"), "HS AC4: invalid party rejects")


# =============================================================================
# M05 worn Block patch projection (Draw Fire / Counter-stitch reactions)
# =============================================================================

## Independent oracle from the brief: authored Block, Guarding, Thorns and the
## legal from-positions. Never derived from the catalog or the service under test.
func _reactions_table() -> Dictionary:
	return {
		"warden_draw_fire": {"block": 6, "guarding": true, "thorns": 0, "from": [1]},
		"warden_draw_fire_plus": {"block": 8, "guarding": true, "thorns": 0, "from": [1]},
		"warden_counter_stitch": {"block": 5, "guarding": false, "thorns": 3, "from": [1, 2]},
		"warden_counter_stitch_plus": {"block": 7, "guarding": false, "thorns": 4, "from": [1, 2]},
	}


func _patch_definitions() -> Array:
	return [
		{"id": "hemguard_cuff", "slot": "ARM"},
		{"id": "reinforced_browband", "slot": "HEAD"},
	]


## Genuine wardrobe and torn ledger built from a real starter CombatParty roster.
## `wear` maps an authored slot to the hero who really sews the patch there.
func _patch_fixture(wear: Dictionary = {}) -> Dictionary:
	var heroes: Array = _party().get_heroes()
	var torn: RunTornMending = RunTornMending.new(heroes)
	_check(torn.is_valid(), "fixture: genuine torn ledger")
	var wardrobe: RunPatchWardrobe = RunPatchWardrobe.new(heroes,
		["hemguard_cuff", "reinforced_browband"], _patch_definitions(), 5, 100,
		["warden_draw_fire", "warden_counter_stitch"], 4242)
	_check(wardrobe.is_valid(), "fixture: genuine run wardrobe")
	for slot: String in ["HEAD", "ARM"]:
		var wearer: String = str(wear.get(slot, ""))
		if wearer.is_empty():
			continue
		var patch_id: String = "reinforced_browband" if slot == "HEAD" else "hemguard_cuff"
		var sewn: Dictionary = wardrobe.sew(patch_id, wearer, slot,
			"op-" + patch_id + "-" + wearer, wardrobe.get_snapshot())
		_check(sewn.get("ok") == true,
			"fixture: sew " + patch_id + " onto " + wearer + " " + slot)
	return {"wardrobe": wardrobe, "torn": torn}


## A torn run roster (real battle end) with both Block patches sewn on the Warden.
func _torn_warden_fixture() -> Dictionary:
	var heroes: Array = _party().get_heroes()
	var torn: RunTornMending = RunTornMending.new(heroes)
	_check(torn.is_valid(), "fixture: torn ledger for the Warden tear")
	var ended: Array = heroes.duplicate(true)
	ended[0]["hp"] = 0
	_check(torn.observe_battle_end("fixture_warden_tear", heroes.duplicate(true), ended).get("ok") == true,
		"fixture: genuine battle end tears the Warden in the run ledger")
	var state: Dictionary = torn.read_state()
	var wardrobe: RunPatchWardrobe = RunPatchWardrobe.new(state["heroes"],
		["hemguard_cuff", "reinforced_browband"], _patch_definitions(), 5, 100,
		["warden_draw_fire"], 4242, true)
	_check(wardrobe.is_valid(), "fixture: current-run wardrobe matches the torn roster")
	for slot: String in ["HEAD", "ARM"]:
		var patch_id: String = "reinforced_browband" if slot == "HEAD" else "hemguard_cuff"
		_check(wardrobe.sew(patch_id, "warden", slot, "op-torn-" + patch_id,
			wardrobe.get_snapshot()).get("ok") == true,
			"fixture: sew " + patch_id + " onto the torn Warden")
	return {"wardrobe": wardrobe, "torn": torn}


func _party_with_warden_at(position: int) -> CombatParty:
	var party: CombatParty = _party()
	var slot: int = 1
	while slot < position:
		var preview: Dictionary = CombatPositionSwaps.preview_adjacent_swap(party, slot, 1)
		_check(preview.get("ok", false), "fixture: legal swap toward Warden slot " + str(position))
		party = CombatParty.new(preview.get("heroes", []))
		slot += 1
	_check(party.get_hero(position)["id"] == "warden",
		"fixture: Warden really occupies slot " + str(position))
	return party


## A real paid hand that holds exactly one copy of the reaction card.
func _paid_deck(card_id: String, seed_value: int) -> CombatDeck:
	var cards: Array[String] = [card_id, "filler_a", "filler_b", "filler_c", "filler_d"]
	var deck: CombatDeck = CombatDeck.new(cards, _rng(seed_value))
	_check(deck.start_turn() and deck.turn_active and deck.energy == CombatState.TURN_ENERGY,
		"fixture: paid deck opens a real 3-energy turn for " + card_id)
	deck.hand.clear()
	deck.hand.append(card_id)
	return deck


func _combat_snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		reactions: CombatWardenGuardReactions) -> Array:
	return [
		party.get_heroes(),
		deck.hand.duplicate(true),
		deck.draw_pile.duplicate(true),
		deck.discard_pile.duplicate(true),
		deck.exhausted.duplicate(true),
		deck.energy,
		deck.turn_active,
		deck.combat_state.energy,
		deck.combat_state.player_turn_active,
		enemies.get_enemies(),
		reactions.is_guarding(),
		reactions.get_thorns(),
		reactions.is_patch_binding_valid(),
		deck._rng.state,
		deck._rng.seed,
	]


func _committed_snapshot(party: CombatParty, enemies: CombatEnemies,
		reactions: CombatWardenGuardReactions) -> Array:
	return [
		party.get_heroes(),
		enemies.get_enemies(),
		reactions.is_guarding(),
		reactions.get_thorns(),
		reactions.is_patch_binding_valid(),
	]


func _refuse_committed(reactions: CombatWardenGuardReactions, card: Variant,
		party: CombatParty, enemies: CombatEnemies, label: String) -> void:
	var before: Array = _committed_snapshot(party, enemies, reactions)
	_check(not reactions.apply_committed_card(card, party), label + ": refused")
	_check(_committed_snapshot(party, enemies, reactions) == before,
		label + ": party, enemy roster and reaction mode unchanged")


func _refuse_paid(reactions: CombatWardenGuardReactions, deck: CombatDeck,
		party: CombatParty, enemies: CombatEnemies, card_id: String, label: String) -> void:
	var before: Array = _combat_snapshot(deck, party, enemies, reactions)
	_check(not reactions.play_from_hand(deck, party, card_id), label + ": refused")
	_check(_combat_snapshot(deck, party, enemies, reactions) == before,
		label + ": hand, piles, energy, party, enemy roster, mode and RNG unchanged")


## Accepted paid play of one patched reaction; returns a detached snapshot for replay.
func _accept_paid(card_id: String, position: int, wardrobe: RunPatchWardrobe,
		torn: RunTornMending, expected_block: int, seed_value: int,
		label: String) -> Array:
	var party: CombatParty = _party_with_warden_at(position)
	var enemies: CombatEnemies = _enemies()
	var deck: CombatDeck = _paid_deck(card_id, seed_value)
	var reactions: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(reactions.bind_patch_wardrobe(wardrobe, torn),
		label + ": genuine wardrobe and torn ledger bind")
	var hand_before: int = deck.hand.size()
	var discard_before: int = deck.discard_pile.size()
	var energy_before: int = deck.energy
	var rng_before: int = deck._rng.state
	var allies_before: Array = party.get_heroes()
	var spec: Dictionary = _reactions_table()[card_id]
	_check(reactions.play_from_hand(deck, party, card_id), label + ": paid play accepted")
	_check(party.get_hero(position)["block"] == expected_block,
		label + ": exact " + str(expected_block) + " Block at slot " + str(position))
	_check(deck.energy == energy_before - 1, label + ": exactly one energy spent")
	_check(deck.hand.size() == hand_before - 1 and not deck.hand.has(card_id),
		label + ": exactly one held copy committed")
	_check(deck.discard_pile.size() == discard_before + 1 and deck.discard_pile.back() == card_id,
		label + ": exactly one discard")
	_check(deck._rng.state == rng_before, label + ": deck RNG untouched by the play")
	_check(reactions.is_guarding() == bool(spec["guarding"]),
		label + ": Guarding duration/behaviour unchanged")
	_check(reactions.get_thorns() == int(spec["thorns"]),
		label + ": Thorns amount unchanged")
	for index in range(CombatParty.PARTY_SIZE):
		if index + 1 != position:
			_check(party.get_hero(index + 1) == allies_before[index],
				label + ": ally slot " + str(index + 1) + " untouched")
	return _combat_snapshot(deck, party, enemies, reactions)


## AC1: genuine worn patches add exactly +2 Block apiece on every legal reaction path.
func _test_patch_block_projection_ac1() -> void:
	var table: Dictionary = _reactions_table()
	var wear_buckets: Array = [
		{"wear": {}, "delta": 0, "label": "no patch"},
		{"wear": {"ARM": "warden"}, "delta": 2, "label": "Hemguard Cuff only"},
		{"wear": {"HEAD": "warden"}, "delta": 2, "label": "Reinforced Browband only"},
		{"wear": {"HEAD": "warden", "ARM": "warden"}, "delta": 4, "label": "both patches"},
	]
	for bucket: Dictionary in wear_buckets:
		var wear: Dictionary = bucket["wear"]
		var delta: int = int(bucket["delta"])
		var label: String = str(bucket["label"])
		var fixture: Dictionary = _patch_fixture(wear)
		var wardrobe: RunPatchWardrobe = fixture["wardrobe"]
		var torn: RunTornMending = fixture["torn"]
		var probe: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
		_check(probe.bind_patch_wardrobe(wardrobe, torn), "AC1: bind " + label)
		_check(probe.is_patch_binding_valid(), "AC1: live binding " + label)

		for card_id: String in table:
			var exact_block: int = int(table[card_id]["block"]) + delta
			var projected: Dictionary = probe.project_block(card_id)
			_check(projected.get("ok", false), "AC1: projection available for " + card_id + " " + label)
			_check(int(projected.get("block", -1)) == exact_block,
				"AC1: " + card_id + " projects exact " + str(exact_block) + " Block (" + label + ")")
			_check(int(projected.get("bonus", -1)) == delta,
				"AC1: " + card_id + " bonus is exactly +" + str(delta) + " (" + label + ")")

			# Already-paid committed path at every authored from-position.
			for position: int in (table[card_id]["from"] as Array):
				var party: CombatParty = _party_with_warden_at(position)
				var enemies: CombatEnemies = _enemies()
				var reactions: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
				_check(reactions.bind_patch_wardrobe(wardrobe, torn),
					"AC1: committed bind " + label)
				var allies_before: Array = party.get_heroes()
				var before: Array = _committed_snapshot(party, enemies, reactions)
				_check(reactions.apply_committed_card(card_id, party),
					"AC1: committed " + card_id + " at slot " + str(position) + " (" + label + ")")
				_check(party.get_hero(position)["block"] == exact_block,
					"AC1: committed " + card_id + " grants exact " + str(exact_block)
						+ " Block at slot " + str(position) + " (" + label + ")")
				_check(reactions.is_guarding() == bool(table[card_id]["guarding"]),
					"AC1: committed " + card_id + " Guarding unchanged (" + label + ")")
				_check(reactions.get_thorns() == int(table[card_id]["thorns"]),
					"AC1: committed " + card_id + " Thorns unchanged (" + label + ")")
				for index in range(CombatParty.PARTY_SIZE):
					if index + 1 != position:
						_check(party.get_hero(index + 1) == allies_before[index],
							"AC1: committed " + card_id + " leaves ally slot "
								+ str(index + 1) + " untouched (" + label + ")")
				# Only the Warden's Block and reaction mode changed.
				var after: Array = _committed_snapshot(party, enemies, reactions)
				_check(after[1] == before[1], "AC1: committed " + card_id + " leaves enemies unchanged")
				_check(after[2] == bool(table[card_id]["guarding"])
					and after[3] == int(table[card_id]["thorns"]),
					"AC1: committed " + card_id + " mode is purely authored (" + label + ")")

			# Paid shared-hand path: one energy, one discard, same projected Block.
			var paid_block: int = int(table[card_id]["block"]) + delta
			_accept_paid(card_id, 1, wardrobe, torn, paid_block, 71,
				"AC1 paid " + card_id + " (" + label + ")")
			if (table[card_id]["from"] as Array).has(2):
				_accept_paid(card_id, 2, wardrobe, torn, paid_block, 71,
					"AC1 paid " + card_id + " slot 2 (" + label + ")")

	# Two fixed seeds replay the same patched paid matrix identically.
	var both: Dictionary = _patch_fixture({"HEAD": "warden", "ARM": "warden"})
	for seed_value: int in [101, 202]:
		var first: Array = []
		var second: Array = []
		for card_id: String in table:
			for position: int in (table[card_id]["from"] as Array):
				var exact_block: int = int(table[card_id]["block"]) + 4
				first.append(_accept_paid(card_id, position, both["wardrobe"], both["torn"],
					exact_block, seed_value, "AC1 seed " + str(seed_value) + " first"))
				second.append(_accept_paid(card_id, position, both["wardrobe"], both["torn"],
					exact_block, seed_value, "AC1 seed " + str(seed_value) + " second"))
		_check(first == second,
			"AC1: seed " + str(seed_value) + " repeated patched matrix is identical")


## AC2: unbound legacy play, wrong wearer, torn owner and a failed bind all keep the contract.
func _test_patch_wearer_and_binding_ac2() -> void:
	var table: Dictionary = _reactions_table()

	# 1. Legacy unbound controls: authored numbers, one energy, one discard.
	for card_id: String in table:
		var party: CombatParty = _party()
		var deck: CombatDeck = _paid_deck(card_id, 37)
		var reactions: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
		_check(reactions.is_patch_binding_valid(), "AC2: unbound service stays legacy-valid")
		var projected: Dictionary = reactions.project_block(card_id)
		_check(int(projected.get("block", -1)) == int(table[card_id]["block"])
			and int(projected.get("bonus", -1)) == 0,
			"AC2: unbound projection is authored Block for " + card_id)
		var before_energy: int = deck.energy
		_check(reactions.play_from_hand(deck, party, card_id),
			"AC2: unbound paid play accepted for " + card_id)
		_check(party.get_hero(1)["block"] == int(table[card_id]["block"]),
			"AC2: unbound paid play keeps authored Block for " + card_id)
		_check(deck.energy == before_energy - 1, "AC2: unbound play spends once for " + card_id)
		_check(reactions.get_thorns() == int(table[card_id]["thorns"])
			and reactions.is_guarding() == bool(table[card_id]["guarding"]),
			"AC2: unbound mode stays authored for " + card_id)
		var committed_party: CombatParty = _party()
		var committed: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
		_check(committed.apply_committed_card(card_id, committed_party),
			"AC2: unbound committed play accepted for " + card_id)
		_check(committed_party.get_hero(1)["block"] == int(table[card_id]["block"]),
			"AC2: unbound committed play keeps authored Block for " + card_id)

	# 2. The identical patches on Seamstress and on Tinker never boost the Warden.
	for wearer: String in ["seamstress", "tinker"]:
		var fixture: Dictionary = _patch_fixture({"HEAD": wearer, "ARM": wearer})
		var wardrobe: RunPatchWardrobe = fixture["wardrobe"]
		var torn: RunTornMending = fixture["torn"]
		var bound: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
		_check(bound.bind_patch_wardrobe(wardrobe, torn),
			"AC2: genuine bind with patches on " + wearer)
		for card_id: String in table:
			_check(int(bound.project_block(card_id).get("bonus", -1)) == 0,
				"AC2: " + wearer + "-worn patches give no bonus to " + card_id)
			var party: CombatParty = _party()
			_check(bound.apply_committed_card(card_id, party),
				"AC2: committed " + card_id + " still legal with " + wearer + " wearing both")
			_check(party.get_hero(1)["block"] == int(table[card_id]["block"]),
				"AC2: committed " + card_id + " keeps authored Block with " + wearer + " wearing both")
			var wardens: Array = [party.get_hero(1), party.get_hero(2), party.get_hero(3)]
			if wearer == "seamstress":
				_check(wardens[1]["block"] == 0, "AC2: Seamstress never gains the Warden Block")
			else:
				_check(wardens[2]["block"] == 0, "AC2: Tinker never gains the Warden Block")
			_accept_paid(card_id, 1, wardrobe, torn, int(table[card_id]["block"]), 73,
				"AC2: paid " + card_id + " with " + wearer + " wearing both")

	# 3. A torn Warden in the run ledger owns nothing even with both patches sewn on.
	var torn_fixture: Dictionary = _torn_warden_fixture()
	var torn_rules: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(torn_rules.bind_patch_wardrobe(torn_fixture["wardrobe"], torn_fixture["torn"]),
		"AC2: bind the torn Warden's twin patches")
	for card_id: String in table:
		_check(int(torn_rules.project_block(card_id).get("bonus", -1)) == 0,
			"AC2: torn Warden gains no bonus for " + card_id)
		var living: CombatParty = _party()
		_check(torn_rules.apply_committed_card(card_id, living),
			"AC2: committed " + card_id + " legal for a living battle Warden")
		_check(living.get_hero(1)["block"] == int(table[card_id]["block"]),
			"AC2: torn ledger keeps authored Block for " + card_id)
		_accept_paid(card_id, 1, torn_fixture["wardrobe"], torn_fixture["torn"],
			int(table[card_id]["block"]), 79, "AC2: paid " + card_id + " with a torn ledger owner")

	# 4. A failed or stale explicit bind fails closed instead of silently playing unpatched.
	var genuine: Dictionary = _patch_fixture({"HEAD": "warden", "ARM": "warden"})
	var failed: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(not failed.bind_patch_wardrobe(null, null), "AC2: null explicit bind is refused")
	_check(not failed.is_patch_binding_valid(), "AC2: failed bind is explicitly invalid")
	var failed_party: CombatParty = _party()
	var failed_deck: CombatDeck = _paid_deck("warden_draw_fire", 83)
	_refuse_committed(failed, "warden_draw_fire", failed_party, _enemies(),
		"AC2: failed bind cannot fall back to unpatched committed play")
	_refuse_paid(failed, failed_deck, failed_party, _enemies(), "warden_draw_fire",
		"AC2: failed bind cannot fall back to unpatched paid play")
	var half: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(not half.bind_patch_wardrobe(genuine["wardrobe"], null),
		"AC2: missing torn ledger bind is refused")
	_refuse_paid(half, failed_deck, failed_party, _enemies(), "warden_draw_fire",
		"AC2: half binding refuses paid play")
	var wrong_expected: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(not wrong_expected.bind_patch_wardrobe(genuine["wardrobe"], genuine["torn"],
		{"stale": true}, null), "AC2: stale expected wardrobe snapshot bind is refused")
	_refuse_paid(wrong_expected, failed_deck, failed_party, _enemies(), "warden_draw_fire",
		"AC2: stale expected snapshot refuses paid play")
	# Recovering is an explicit rebind, never a silent fallback.
	_check(failed.bind_patch_wardrobe(genuine["wardrobe"], genuine["torn"]),
		"AC2: explicit rebind after a failure succeeds")
	var recovered_party: CombatParty = _party()
	_check(failed.apply_committed_card("warden_draw_fire", recovered_party),
		"AC2: rebind restores the patched play")
	_check(recovered_party.get_hero(1)["block"] == 10,
		"AC2: rebind applies both worn patches (6 + 2 + 2)")
	_accept_paid("warden_draw_fire", 1, genuine["wardrobe"], genuine["torn"], 10, 89,
		"AC2: rebind paid Draw Fire")


## AC3: negatives, overflow and stale bindings refuse before any mutation.
func _test_patch_negative_and_stale_ac3() -> void:
	var table: Dictionary = _reactions_table()
	var fixture: Dictionary = _patch_fixture({"HEAD": "warden", "ARM": "warden"})
	var wardrobe: RunPatchWardrobe = fixture["wardrobe"]
	var torn: RunTornMending = fixture["torn"]
	var patched: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(patched.bind_patch_wardrobe(wardrobe, torn), "AC3: bind both worn patches")
	var enemy_roster: CombatEnemies = _enemies()

	# 1. Illegal positions for the committed and paid paths.
	var slot_two: CombatParty = _party_with_warden_at(2)
	_refuse_committed(patched, "warden_draw_fire", slot_two, enemy_roster,
		"AC3: committed Draw Fire at slot 2 refused")
	_refuse_paid(patched, _paid_deck("warden_draw_fire", 91), slot_two, enemy_roster,
		"warden_draw_fire", "AC3: paid Draw Fire at slot 2 refused")
	var slot_three: CombatParty = _party_with_warden_at(3)
	_refuse_committed(patched, "warden_counter_stitch", slot_three, enemy_roster,
		"AC3: committed Counter-stitch at slot 3 refused")
	_refuse_paid(patched, _paid_deck("warden_counter_stitch", 97), slot_three, enemy_roster,
		"warden_counter_stitch", "AC3: paid Counter-stitch at slot 3 refused")
	# Slot 2 remains legal for Counter-stitch (control against over-refusal).
	var legal_two: CombatParty = _party_with_warden_at(2)
	_check(patched.apply_committed_card("warden_counter_stitch", legal_two),
		"AC3: Counter-stitch at slot 2 stays legal")
	_check(legal_two.get_hero(2)["block"] == 9, "AC3: legal slot 2 Counter-stitch is 5 + 4")

	# 2. Downed Warden refuses both entry points.
	var downed: CombatParty = _party()
	_check(downed.apply_damage(1, 40) and downed.is_downed(1), "AC3: Warden downed in combat")
	_refuse_committed(patched, "warden_draw_fire", downed, enemy_roster,
		"AC3: downed Warden refuses committed Draw Fire")
	_refuse_paid(patched, _paid_deck("warden_draw_fire", 103), downed, enemy_roster,
		"warden_draw_fire", "AC3: downed Warden refuses paid Draw Fire")

	# 3. Absent held card and short energy.
	var empty_hand_deck: CombatDeck = _paid_deck("warden_draw_fire", 107)
	empty_hand_deck.hand.clear()
	_refuse_paid(patched, empty_hand_deck, _party(), enemy_roster, "warden_draw_fire",
		"AC3: absent held card refused")
	var poor_deck: CombatDeck = _paid_deck("warden_draw_fire", 109)
	_check(poor_deck.try_spend_energy(3), "AC3: energy fixture spends all three")
	_refuse_paid(patched, poor_deck, _party(), enemy_roster, "warden_draw_fire",
		"AC3: short energy refused")

	# 4. Stale wardrobe: a genuine sew after the bind invalidates it until rebind.
	var stale_fixture: Dictionary = _patch_fixture({"ARM": "warden"})
	var stale_w: RunPatchWardrobe = stale_fixture["wardrobe"]
	var stale_t: RunTornMending = stale_fixture["torn"]
	var stale: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(stale.bind_patch_wardrobe(stale_w, stale_t), "AC3: bind before the wardrobe changes")
	_check(stale_w.sew("reinforced_browband", "tinker", "HEAD", "op-stale-head",
		stale_w.get_snapshot()).get("ok") == true, "AC3: genuine wardrobe change")
	_check(not stale.is_patch_binding_valid(), "AC3: binding turns stale after the sew")
	_refuse_paid(stale, _paid_deck("warden_draw_fire", 113), _party(), enemy_roster,
		"warden_draw_fire", "AC3: stale wardrobe refuses paid Draw Fire")
	_check(stale.bind_patch_wardrobe(stale_w, stale_t), "AC3: rebind after the wardrobe change")
	_accept_paid("warden_draw_fire", 1, stale_w, stale_t, 8, 127,
		"AC3: rebind still applies only the Warden's Hemguard Cuff")

	# 5. Stale torn ledger (real later battle) refuses until rebind.
	var torn_stale_fixture: Dictionary = _patch_fixture({"HEAD": "warden"})
	var ts_w: RunPatchWardrobe = torn_stale_fixture["wardrobe"]
	var ts_t: RunTornMending = torn_stale_fixture["torn"]
	var ts_service: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(ts_service.bind_patch_wardrobe(ts_w, ts_t), "AC3: bind before the torn ledger changes")
	var held: Array = ts_t.read_state()["heroes"]
	var later: Array = held.duplicate(true)
	later[2]["hp"] = 0
	_check(ts_t.observe_battle_end("ac3_later_battle", held.duplicate(true), later).get("ok") == true,
		"AC3: genuine later battle tears the Tinker")
	_check(not ts_service.is_patch_binding_valid(), "AC3: binding turns stale after the torn change")
	_refuse_committed(ts_service, "warden_counter_stitch", _party(), enemy_roster,
		"AC3: stale torn ledger refuses committed Counter-stitch")
	_refuse_paid(ts_service, _paid_deck("warden_counter_stitch", 131), _party(), enemy_roster,
		"warden_counter_stitch", "AC3: stale torn ledger refuses paid Counter-stitch")

	# 6. At-capacity Block: the projected amount must fit, before any spend.
	var capped: CombatParty = _party()
	capped._heroes[0]["block"] = CombatParty.MAX_INT - 6
	_refuse_committed(patched, "warden_draw_fire", capped, enemy_roster,
		"AC3: projected 10 Block cannot fit 6 remaining capacity")
	_refuse_paid(patched, _paid_deck("warden_draw_fire", 137), capped, enemy_roster,
		"warden_draw_fire", "AC3: paid projected overflow refused")
	# The same capacity really would have accepted the unpatched authored 6.
	var unbound_capped: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	var unbound_party: CombatParty = _party()
	unbound_party._heroes[0]["block"] = CombatParty.MAX_INT - 6
	_check(unbound_capped.apply_committed_card("warden_draw_fire", unbound_party),
		"AC3: unpatched authored 6 exactly fits the same capacity")
	_check(unbound_party.get_hero(1)["block"] == CombatParty.MAX_INT,
		"AC3: unpatched authored Block reaches the exact cap")

	# 7. Thorns overflow refuses before the Block of the same card is applied.
	var thorn_cap: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(thorn_cap.bind_patch_wardrobe(wardrobe, torn), "AC3: bind for the Thorns overflow")
	thorn_cap.thorns = CombatParty.MAX_INT
	var thorn_party: CombatParty = _party()
	_refuse_committed(thorn_cap, "warden_counter_stitch", thorn_party, enemy_roster,
		"AC3: Thorns overflow refuses committed Counter-stitch")
	_check(thorn_party.get_hero(1)["block"] == 0,
		"AC3: Thorns overflow never applies the projected Block first")
	_refuse_paid(thorn_cap, _paid_deck("warden_counter_stitch", 139), thorn_party, enemy_roster,
		"warden_counter_stitch", "AC3: Thorns overflow refuses paid Counter-stitch")
	_check(thorn_party.get_hero(1)["block"] == 0,
		"AC3: paid Thorns overflow never applies Block or energy first")

	# 8. Duplicate paid copy and disallowed/counterfeit committed descriptors.
	var single_deck: CombatDeck = _paid_deck("warden_draw_fire", 149)
	var single_party: CombatParty = _party()
	_check(patched.play_from_hand(single_deck, single_party, "warden_draw_fire"),
		"AC3: first paid Draw Fire accepted")
	_check(single_deck.energy == 2 and single_party.get_hero(1)["block"] == 10,
		"AC3: first paid play spent once and gained 10")
	_refuse_paid(patched, single_deck, single_party, enemy_roster, "warden_draw_fire",
		"AC3: duplicate paid play of the consumed copy refused")
	_check(single_deck.discard_pile.count("warden_draw_fire") == 1,
		"AC3: duplicate refusal never discards twice")

	var descriptor_party: CombatParty = _party()
	var descriptor_enemies: CombatEnemies = _enemies()
	# A counterfeit descriptor claiming the patched total is never a grant source.
	_refuse_committed(patched, {"id": "warden_draw_fire",
		"effects": {"block": 10, "guarding": true, "duration": "until_next_turn"}},
		descriptor_party, descriptor_enemies,
		"AC3: counterfeit patched Block descriptor refused")
	_refuse_committed(patched, {"id": "warden_draw_fire", "effects": {"block": 6}},
		descriptor_party, descriptor_enemies,
		"AC3: descriptor dropping Guarding refused")
	_refuse_committed(patched, {"id": "warden_draw_fire", "target_kind": "enemy_single"},
		descriptor_party, descriptor_enemies,
		"AC3: descriptor with a disallowed target refused")
	_refuse_committed(patched, {"id": "warden_draw_fire", "from_positions": [2]},
		descriptor_party, descriptor_enemies,
		"AC3: descriptor with a disallowed from-position refused")
	_refuse_committed(patched, {"id": "warden_draw_fire", "owner": "tinker"},
		descriptor_party, descriptor_enemies,
		"AC3: descriptor with a foreign owner refused")
	_refuse_committed(patched, "warden_hold_the_line", descriptor_party, descriptor_enemies,
		"AC3: disallowed Warden card refused")
	# The genuine descriptor still works after every refusal.
	_check(patched.apply_committed_card("warden_draw_fire", descriptor_party),
		"AC3: genuine descriptor still accepted after descriptor refusals")
	_check(descriptor_party.get_hero(1)["block"] == 10,
		"AC3: genuine descriptor applies the projected 10 Block")

	# 9. Reaction modes still expire at the player-turn boundary.
	var expiry: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(expiry.bind_patch_wardrobe(wardrobe, torn), "AC3: bind for the turn-boundary case")
	var expiry_party: CombatParty = _party()
	var expiry_deck: CombatDeck = _paid_deck("warden_counter_stitch", 151)
	_check(expiry.play_from_hand(expiry_deck, expiry_party, "warden_counter_stitch"),
		"AC3: patched Counter-stitch accepted")
	_check(expiry.get_thorns() == 3 and expiry_party.get_hero(1)["block"] == 9,
		"AC3: patched Counter-stitch is 9 Block and authored Thorns 3")
	_check(expiry.begin_player_turn(), "AC3: player-turn boundary accepted")
	_check(not expiry.is_guarding() and expiry.get_thorns() == 0,
		"AC3: until-next-turn modes expired, not lengthened by the patches")
	_check(expiry_party.get_hero(1)["block"] == 9,
		"AC3: the reaction boundary never resets Block")
	var expiry_enemies: CombatEnemies = _enemies()
	var expiry_attack: Dictionary = {"enemy_position": 1, "target_position": 2, "amount": 3}
	var expiry_result: Dictionary = expiry.resolve_enemy_attack(expiry_party, expiry_enemies, expiry_attack)
	_check(expiry_result.get("target_position") == 2 and expiry_result.get("redirected") == false,
		"AC3: expired Guarding no longer redirects for patched play")
	_check(expiry_result.get("retaliation_damage") == 0,
		"AC3: expired Thorns grants no retaliation for patched play")
	_check(expiry_enemies.get_enemy(1)["hp"] == 12,
		"AC3: expired Thorns leaves the attacking enemy untouched")


# =============================================================================
# Mounted Real-Hand Integration Suite (D2-1 AC1-AC4)
# =============================================================================

func _frames() -> void:
	await process_frame
	await process_frame


func _key(code: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	return event


func _key_press(code: Key) -> void:
	root.push_input(_key(code, true), true)
	root.push_input(_key(code, false), true)
	await _frames()


func _mouse_click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		if pressed:
			root.push_input(event, true)
	await _frames()


func _mouse_drag_cancel(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.position = point
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down, true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2.ZERO
	root.push_input(motion, true)
	var up := InputEventMouseButton.new()
	up.position = Vector2.ZERO
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	root.push_input(up, true)
	await _frames()


func _panel_for(app: Control, card_id: String) -> Control:
	if not is_instance_valid(app.hand_view):
		return null
	for panel: Node in app.hand_view.get_children():
		if panel is Control and panel.get_child_count() > 0 and panel.get_child(0) is Label:
			if (panel.get_child(0) as Label).text == card_id:
				return panel as Control
	return null


func _find_starter_attacks_fixture() -> Dictionary:
	for value in range(1, 1025):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		var opening_rng: int = rng.state
		for id: String in map.get_legal_choices():
			if map.get_node(id).get("type") != "Fight":
				continue
			rng.state = opening_rng
			if not map.choose_node(id):
				continue
			var selected: Dictionary = RunAuthoredBattleEntry.new().entry_current_battle(
				map, rng, RunFightEncounterSelection.new())
			map.undo_choice(id, [])
			if selected.get("success", false) and selected.get("encounter_id") == "starter_attacks":
				return {"seed": value, "fight": id}
	return {}


func _start_battle_in_app(app: Control, target_fight_id: String = "") -> bool:
	if app.deck != null:
		return true
	_check(is_instance_valid(app.start_button) and app.start_button.is_visible_in_tree() \
		and not app.start_button.disabled, "real title Start run button exists and is actionable")
	if not is_instance_valid(app.start_button) or not app.start_button.is_visible_in_tree() or app.start_button.disabled:
		return false
	app.start_button.grab_focus()
	await _frames()
	await _mouse_click(LEGACY_ENTRY.start_button(app))
	if not is_instance_valid(app.route_view) or not app.route_view.is_visible_in_tree():
		app.start_run_requested.emit()
		preload("res://tests/party_choice.gd").choose(app)
		await _frames()
	_check(is_instance_valid(app.route_view) and app.route_view.is_visible_in_tree(),
		"opening route view is mounted and visible after Start run")
	if not is_instance_valid(app.route_view) or not app.route_view.is_visible_in_tree():
		return false
	var chosen_button: Button = null
	for btn: Button in app.route_buttons:
		if not is_instance_valid(btn) or btn.disabled:
			continue
		if not target_fight_id.is_empty():
			if btn.get_meta("route_id", "") == target_fight_id:
				chosen_button = btn
				break
		elif btn.get_meta("route_kind", "") == "Fight":
			chosen_button = btn
			break
	_check(chosen_button != null and not chosen_button.disabled,
		"legal Fight route action button exists in route view")
	if chosen_button == null:
		return false
	chosen_button.grab_focus()
	await _frames()
	await _mouse_click(chosen_button)
	if app.deck == null and is_instance_valid(chosen_button):
		chosen_button.pressed.emit()
		await _frames()
	if app.deck == null or app.round_flow == null:
		return false
	# These mounted Warden reaction cases explicitly exercise the legacy
	# starter_attacks schedule, not the opt-in weighted battle scheduler.
	var fixture_intents := CombatEnemyIntents.new(app.enemy_intents._definitions)
	_check(fixture_intents.is_valid() and not fixture_intents.is_bound(),
		"mounted fixture independently retains the legacy authored schedule")
	app.enemy_intents = fixture_intents
	app.round_flow._intents = fixture_intents
	app.round_flow._battle_intents = fixture_intents
	app.enemy_attacks = fixture_intents.get_intents()
	app._refresh_intents()
	return true


func _return_to_title(app: Control) -> void:
	if is_instance_valid(app.return_button) and app.return_button.is_visible_in_tree() and not app.return_button.disabled:
		app.return_button.grab_focus()
		await _frames()
		await _mouse_click(app.return_button)
		if app.title_view == null or not app.title_view.is_visible_in_tree():
			app.return_button.pressed.emit()
	await _frames()


func _app_snapshot(app: Control) -> Array:
	return [
		app.deck.draw_pile.duplicate(),
		app.deck.hand.duplicate(),
		app.deck.discard_pile.duplicate(),
		app.deck.energy,
		app.deck.turn_active,
		app.party.get_heroes(),
		app.enemies.get_enemies(),
		app.enemy_attacks.duplicate(true),
		app.enemy_intents.get_intents(),
		app.run_rng.seed,
		app.deck._rng.state,
		app.battle_result.get_outcome(),
	]


func _test_real_mounted_hand() -> void:
	var fixture: Dictionary = _find_starter_attacks_fixture()
	_check(not fixture.is_empty(), "AC1: bounded seed search discovers authored starter_attacks Fight")
	if fixture.is_empty():
		return

	root.size = Vector2i(1280, 720)
	var scene: PackedScene = load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "AC1: real scenes/app.tscn loads")
	if scene == null:
		return
	var app: Control = scene.instantiate() as Control
	root.add_child(app)
	await _frames()

	var presenter: Node = app.get_node_or_null("LiveWardenReactionHand")
	_check(presenter != null, "AC1: LiveWardenReactionHand is mounted in scene")
	_check(app.deck == null, "AC1: scene starts on title without active battle")

	# =========================================================================
	# AC1: Draw Fire (base and +) mounted hand plays, Block delta, Guarding, End Turn redirect
	# =========================================================================
	# AC1.1: Draw Fire base (mouse confirmation)
	app.run_seed = int(fixture.seed)
	_check(await _start_battle_in_app(app, fixture.fight), "AC1: battle starts from title")
	_check(app.deck != null and app.party != null and app.enemies != null \
		and app.battle_result != null and app.round_flow != null and is_instance_valid(app.hand_view),
		"AC1: authoritative fight coordinator and presenter live")
	_check(app.round_flow._deck == app.deck and app.round_flow._party == app.party \
		and app.round_flow._enemies == app.enemies and app.round_flow._result == app.battle_result,
		"AC1: round_flow bound to current app models")
	_check(app.encounter_id == "starter_attacks",
		"AC1: route-selected fight is authentic authored starter_attacks")

	var warden_initial_block: int = int(app.party.get_hero(1).block)
	_check(warden_initial_block == 6, "AC1: Warden starts with 6 passive opening block")

	app.deck.draw_pile.append("warden_draw_fire")
	_check(app.deck.draw_extra(1) == 1, "AC1: drew warden_draw_fire")
	app._refresh_hand()
	await _frames()

	var panel_df: Control = _panel_for(app, "warden_draw_fire")
	_check(panel_df != null, "AC1: mounted panel exists for warden_draw_fire")
	var idx_df: int = panel_df.get_index()
	_check(idx_df >= 0 and idx_df < app.deck.hand.size() and app.deck.hand[idx_df] == "warden_draw_fire",
		"AC1: panel index matches hand index")
	_check(panel_df.get_child(0) is Label and (panel_df.get_child(0) as Label).text == "warden_draw_fire",
		"AC1: panel first child retains card ID label")

	var before_df: Array = _app_snapshot(app)
	await _mouse_click(panel_df)

	_check(app.deck.energy == int(before_df[3]) - 1, "AC1: spent exactly 1 energy")
	_check(app.deck.hand.size() == (before_df[1] as Array).size() - 1, "AC1: hand count decremented by 1")
	_check(not app.deck.hand.has("warden_draw_fire"), "AC1: warden_draw_fire removed from hand")
	_check(app.deck.discard_pile.back() == "warden_draw_fire", "AC1: warden_draw_fire in discard pile")
	_check(app.party.get_hero(1).block == warden_initial_block + 6, "AC1: Warden gained authored 6 block (total 12)")
	_check(app.party.get_hero(1).hp == 40, "AC1: Warden HP untouched")
	_check(app.party.get_hero(2).block == 0 and app.party.get_hero(3).block == 0, "AC1: allies gained no block")
	_check(app.round_flow._reactions != null and app.round_flow._reactions.is_guarding() == true,
		"AC1: Guarding mode is true")
	_check(app.deck._rng.state == before_df[10], "AC1: run RNG untouched by play")

	# Enemy 1 announced attack targets ally 2 (Seamstress)
	app.enemy_intents._turn_index = 1
	app.enemy_attacks = app.enemy_intents.get_intents()
	app._refresh_intents()
	_check(int(app.enemy_attacks[0].get("target_position", 0)) == 2, "AC1: announced enemy attack targets ally 2")
	_check(int(app.enemy_attacks[0].get("amount", 0)) == 1, "AC1: announced attack amount is 1")
	var seamstress_hp_before: int = int(app.party.get_hero(2).hp)
	_check(seamstress_hp_before == 30, "AC1: Seamstress starts at 30 HP")

	app.end_turn_button.pressed.emit()
	await _frames()

	# Redirected hit: Seamstress unharmed at 30 HP, Warden absorbed 1 damage without HP loss (40 HP)
	_check(app.party.get_hero(2).hp == seamstress_hp_before, "AC1: Seamstress HP completely unharmed by redirected attack")
	_check(app.party.get_hero(2).block == 0, "AC1: Seamstress Block remains 0")
	_check(app.party.get_hero(1).hp == 40, "AC1: Warden HP untouched after absorbed redirect")

	await _return_to_title(app)
	_check(presenter._bindings.is_empty() and presenter._battle == null,
		"AC3: Return to title clears presenter bindings")

	# AC1.2: Draw Fire+ (keyboard Enter confirmation)
	app.run_seed = int(fixture.seed)
	_check(await _start_battle_in_app(app, fixture.fight), "AC1: start battle for Draw Fire+")
	app.deck.draw_pile.append("warden_draw_fire_plus")
	_check(app.deck.draw_extra(1) == 1, "AC1: drew warden_draw_fire_plus")
	app._refresh_hand()
	await _frames()

	var panel_dfp: Control = _panel_for(app, "warden_draw_fire_plus")
	_check(panel_dfp != null, "AC1: mounted panel exists for Draw Fire+")
	panel_dfp.grab_focus()
	_check(panel_dfp.has_focus(), "AC1: Draw Fire+ panel grabbed focus")
	await _key_press(KEY_ENTER)

	_check(app.deck.discard_pile.back() == "warden_draw_fire_plus", "AC1: Draw Fire+ discarded")
	_check(app.party.get_hero(1).block == 6 + 8, "AC1: Warden gained authored 8 block from Draw Fire+ (total 14)")
	_check(app.round_flow._reactions != null and app.round_flow._reactions.is_guarding() == true,
		"AC1: Draw Fire+ activated Guarding mode")

	await _return_to_title(app)

	# =========================================================================
	# AC2: Counter-stitch (base and +) mounted hand plays, Block, Thorns, retaliation
	# =========================================================================
	# AC2.1: Counter-stitch base (mouse confirmation)
	app.run_seed = int(fixture.seed)
	_check(await _start_battle_in_app(app, fixture.fight), "AC2: start battle for Counter-stitch")
	app.deck.draw_pile.append("warden_counter_stitch")
	_check(app.deck.draw_extra(1) == 1, "AC2: drew warden_counter_stitch")
	app._refresh_hand()
	await _frames()

	var panel_cs: Control = _panel_for(app, "warden_counter_stitch")
	_check(panel_cs != null, "AC2: mounted panel exists for warden_counter_stitch")
	var before_cs: Array = _app_snapshot(app)
	await _mouse_click(panel_cs)

	_check(app.deck.energy == int(before_cs[3]) - 1, "AC2: spent exactly 1 energy")
	_check(app.deck.discard_pile.back() == "warden_counter_stitch", "AC2: warden_counter_stitch discarded")
	_check(app.party.get_hero(1).block == 6 + 5, "AC2: Warden gained authored 5 block (total 11)")
	_check(app.round_flow._reactions != null and app.round_flow._reactions.get_thorns() == 3,
		"AC2: Thorns mode is 3")
	_check(app.round_flow._reactions.is_guarding() == false, "AC2: Guarding mode is false")

	app.enemy_intents._turn_index = 0
	app.enemy_attacks = app.enemy_intents.get_intents()
	app._refresh_intents()
	_check(int(app.enemy_attacks[0].get("target_position", 0)) == 1, "AC2: enemy 1 attacks Warden")
	var enemy1_hp_before: int = int(app.enemies.get_enemy(1).hp)
	var enemy2_hp_before: int = int(app.enemies.get_enemy(2).hp)
	var oracle_rng := RandomNumberGenerator.new()
	oracle_rng.seed = int(fixture.seed)
	var oracle_map := RunMap.new()
	_check(oracle_map.generate(oracle_rng) and oracle_map.choose_node(fixture.fight),
		"AC2: independent seeded map reaches the actual mounted Fight")
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		RunAuthoredBattleEntry.POOLS_PATH))
	var ids: Array = registry["Fight"].keys()
	ids.sort()
	_check(ids[oracle_rng.randi_range(0, ids.size() - 1)] == "starter_attacks",
		"AC2: independent oracle selects the live authored schedule")
	var band_ids: Array = preload("res://tests/floor_band_oracle.gd").group(
		oracle_map.get_current_floor(), 2, oracle_rng)
	var records: Dictionary = preload("res://tests/floor_band_oracle.gd").records()
	_check(band_ids.size() == 2 and app.enemies.get_enemy(1).id == band_ids[0]
		and app.enemies.get_enemy(2).id == band_ids[1]
		and enemy1_hp_before == int(records[band_ids[0]].max_hp)
		and enemy2_hp_before == int(records[band_ids[1]].max_hp)
		and app.run_map.get_current_node_id() == fixture.fight,
		"AC2: both mounted IDs and HP match independent floor-band sampling and RNG")

	app.end_turn_button.pressed.emit()
	await _frames()

	_check(app.enemies.get_enemy(1).hp == enemy1_hp_before - 3, "AC2: attacking Enemy 1 took 3 Thorns retaliation (12 -> 9)")
	_check(app.enemies.get_enemy(2).hp == enemy2_hp_before, "AC2: non-attacking Enemy 2 took NO Thorns retaliation")

	await _return_to_title(app)

	# AC2.2: Counter-stitch+ (keyboard Space confirmation)
	app.run_seed = int(fixture.seed)
	_check(await _start_battle_in_app(app, fixture.fight), "AC2: start battle for Counter-stitch+")
	app.deck.draw_pile.append("warden_counter_stitch_plus")
	_check(app.deck.draw_extra(1) == 1, "AC2: drew warden_counter_stitch_plus")
	app._refresh_hand()
	await _frames()

	var panel_csp: Control = _panel_for(app, "warden_counter_stitch_plus")
	_check(panel_csp != null, "AC2: mounted panel exists for Counter-stitch+")
	panel_csp.grab_focus()
	_check(panel_csp.has_focus(), "AC2: Counter-stitch+ panel grabbed focus")
	await _key_press(KEY_SPACE)

	_check(app.deck.discard_pile.back() == "warden_counter_stitch_plus", "AC2: Counter-stitch+ discarded")
	_check(app.party.get_hero(1).block == 6 + 7, "AC2: Warden gained authored 7 block from Counter-stitch+ (total 13)")
	_check(app.round_flow._reactions != null and app.round_flow._reactions.get_thorns() == 4,
		"AC2: Counter-stitch+ activated Thorns 4")

	app.enemy_intents._turn_index = 0
	app.enemy_attacks = app.enemy_intents.get_intents()
	app._refresh_intents()
	var enemy1_hp_before_csp: int = int(app.enemies.get_enemy(1).hp)
	app.end_turn_button.pressed.emit()
	await _frames()

	_check(app.enemies.get_enemy(1).hp == enemy1_hp_before_csp - 4,
		"AC2: attacking Enemy 1 took 4 Thorns retaliation from Counter-stitch+")

	await _return_to_title(app)

	# =========================================================================
	# AC3: Both reactions in same turn, coexistence, redirect + thorns, expiry, seed replay
	# =========================================================================
	app.run_seed = int(fixture.seed)
	_check(await _start_battle_in_app(app, fixture.fight), "AC3: start battle for coexistence")
	app.deck.draw_pile.append("warden_draw_fire")
	app.deck.draw_pile.append("warden_counter_stitch")
	_check(app.deck.draw_extra(2) == 2, "AC3: drew both reaction cards")
	app._refresh_hand()
	await _frames()

	var panel_both_df: Control = _panel_for(app, "warden_draw_fire")
	_check(panel_both_df != null, "AC3: Draw Fire panel mounted")

	await _mouse_click(panel_both_df)
	_check(app.deck.energy == 2, "AC3: 1 energy paid for Draw Fire, 2 remaining")
	_check(app.round_flow._reactions.is_guarding() == true, "AC3: Guarding mode enabled")

	# Re-acquire panel_both_cs since hand was refreshed
	var panel_both_cs: Control = _panel_for(app, "warden_counter_stitch")
	_check(panel_both_cs != null, "AC3: Counter-stitch panel found in rebuilt hand")
	panel_both_cs.grab_focus()
	await _key_press(KEY_ENTER)
	_check(app.deck.energy == 1, "AC3: 1 energy paid for Counter-stitch, 1 remaining")
	_check(app.round_flow._reactions.is_guarding() == true, "AC3: Guarding still active")
	_check(app.round_flow._reactions.get_thorns() == 3, "AC3: Thorns 3 active simultaneously")
	_check(app.party.get_hero(1).block == 6 + 6 + 5, "AC3: Warden has 17 block (6 passive + 6 + 5)")

	app.enemy_intents._turn_index = 1
	app.enemy_attacks = app.enemy_intents.get_intents()
	app._refresh_intents()
	var e1_hp_before_ac3: int = int(app.enemies.get_enemy(1).hp)
	var seamstress_hp_before_ac3: int = int(app.party.get_hero(2).hp)

	app.end_turn_button.pressed.emit()
	await _frames()

	_check(app.party.get_hero(2).hp == seamstress_hp_before_ac3, "AC3: Seamstress took NO damage due to redirect")
	_check(app.enemies.get_enemy(1).hp == e1_hp_before_ac3 - 3, "AC3: Enemy 1 suffered 3 Thorns retaliation from redirected hit")

	_check(app.round_flow._reactions.is_guarding() == false, "AC3: Guarding expired at start of new player turn")
	_check(app.round_flow._reactions.get_thorns() == 0, "AC3: Thorns expired at start of new player turn")

	app.enemy_intents._turn_index = 1
	app.enemy_attacks = app.enemy_intents.get_intents()
	app._refresh_intents()
	var e1_hp_before_next: int = int(app.enemies.get_enemy(1).hp)
	var seamstress_hp_before_next: int = int(app.party.get_hero(2).hp)
	app.end_turn_button.pressed.emit()
	await _frames()

	_check(app.party.get_hero(2).hp == seamstress_hp_before_next - 1, "AC3: following turn has NO redirect (Seamstress took damage)")
	# The attacking ordinary floor-band actor may author Drain (the shipped Thread
	# Biter now does): the only HP it may regain is the HP its own bite really
	# removed, capped at its missing HP. A leaked Thorns retaliation would still
	# lower its HP and fail this exact expectation.
	var next_attacker: Dictionary = app.enemies.get_enemy(1)
	var next_drains: bool = next_attacker.get("drain") is bool \
		and next_attacker.get("drain") == true
	var next_missing: int = int(next_attacker.max_hp) - e1_hp_before_next
	var next_hero_loss: int = seamstress_hp_before_next - int(app.party.get_hero(2).hp)
	var expected_next_hp: int = e1_hp_before_next + (
		mini(next_hero_loss, next_missing) if next_drains else 0)
	_check(int(app.enemies.get_enemy(1).hp) == expected_next_hp,
		"AC3: following turn has NO retaliation; only an authored Drain bite restores HP")

	await _return_to_title(app)
	app.run_seed = 123
	_check(await _start_battle_in_app(app), "AC3: start battle for seed replay 1")
	var snap1: Array = _app_snapshot(app)
	_check(app.round_flow._reactions == null or not app.round_flow._reactions.is_active(),
		"AC3: fresh battle has no inherited reaction modes")
	await _return_to_title(app)

	app.run_seed = 123
	_check(await _start_battle_in_app(app), "AC3: start battle for seed replay 2")
	var snap2: Array = _app_snapshot(app)
	_check(snap1 == snap2, "AC3: replaying fixed seed yields identical battle snapshot")

	await _return_to_title(app)

	# =========================================================================
	# AC4: Rejections, negatives, fail-closed, invariants & retry
	# =========================================================================
	app.run_seed = int(fixture.seed)
	_check(await _start_battle_in_app(app, fixture.fight), "AC4: start battle for negatives")

	# 1. Insufficient energy
	app.deck.draw_pile.append("warden_draw_fire")
	app.deck.draw_extra(1)
	app._refresh_hand()
	await _frames()
	var panel_neg_df: Control = _panel_for(app, "warden_draw_fire")
	_check(panel_neg_df != null, "AC4: Draw Fire drawn")

	app.deck.combat_state.energy = 0
	var snap_insufficient: Array = _app_snapshot(app)
	await _mouse_click(panel_neg_df)
	_check(_app_snapshot(app) == snap_insufficient, "AC4: insufficient energy rejects; state completely unchanged")
	_check(app.deck._rng.state == snap_insufficient[10], "AC4: insufficient energy leaves deck RNG untouched")

	# Drag to invalid target (outside panel) cancels without spend
	app.deck.combat_state.energy = 3
	var snap_drag_cancel: Array = _app_snapshot(app)
	await _mouse_drag_cancel(panel_neg_df)
	_check(_app_snapshot(app) == snap_drag_cancel, "AC4: drag outside panel cancels without spend")

	# Right-click is inert
	var snap_rc: Array = _app_snapshot(app)
	var rc_point: Vector2 = panel_neg_df.get_global_rect().get_center()
	var rc_down := InputEventMouseButton.new()
	rc_down.position = rc_point
	rc_down.button_index = MOUSE_BUTTON_RIGHT
	rc_down.pressed = true
	root.push_input(rc_down, true)
	await _frames()
	_check(_app_snapshot(app) == snap_rc, "AC4: right click is inert")

	# Accepted retry after restoring energy
	await _mouse_click(panel_neg_df)
	_check(app.deck.energy == 2, "AC4: accepted retry after restoring energy succeeds (spent 1)")
	_check(app.round_flow._reactions != null and app.round_flow._reactions.is_guarding() == true,
		"AC4: Guarding active after accepted retry")

	await _return_to_title(app)

	# 2. Downed Warden
	app.run_seed = int(fixture.seed)
	_check(await _start_battle_in_app(app, fixture.fight), "AC4: start battle for downed Warden")
	app.deck.draw_pile.append("warden_draw_fire")
	app.deck.draw_extra(1)
	app._refresh_hand()
	await _frames()
	var panel_downed: Control = _panel_for(app, "warden_draw_fire")
	_check(panel_downed != null, "AC4: Draw Fire panel ready")

	app.party.apply_damage(1, 50)
	_check(app.party.is_downed(1), "AC4: Warden is downed")
	var snap_downed: Array = _app_snapshot(app)
	await _mouse_click(panel_downed)
	_check(_app_snapshot(app) == snap_downed, "AC4: downed Warden rejects play; state completely unchanged")

	await _return_to_title(app)

	# 3. Wrong Warden position
	app.run_seed = int(fixture.seed)
	_check(await _start_battle_in_app(app, fixture.fight), "AC4: start battle for wrong position")
	var swap_preview: Dictionary = CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
	_check(swap_preview.get("ok", false), "AC4: swap preview valid")
	app.party._heroes.assign(swap_preview["heroes"])
	app._refresh_party()
	_check(app.party.get_hero(2)["id"] == "warden", "AC4: Warden moved to position 2")

	app.deck.draw_pile.append("warden_draw_fire")
	app.deck.draw_extra(1)
	app._refresh_hand()
	await _frames()
	var panel_wrong_pos: Control = _panel_for(app, "warden_draw_fire")
	_check(panel_wrong_pos != null, "AC4: Draw Fire drawn while Warden at position 2")
	var snap_wrong_pos: Array = _app_snapshot(app)
	await _mouse_click(panel_wrong_pos)
	_check(_app_snapshot(app) == snap_wrong_pos, "AC4: Draw Fire rejects when Warden is at position 2")

	# Counter-stitch is FROM [1, 2] only. Move Warden to position 3.
	var swap_preview2: Dictionary = CombatPositionSwaps.preview_adjacent_swap(app.party, 2, 1)
	_check(swap_preview2.get("ok", false), "AC4: swap preview to position 3 valid")
	app.party._heroes.assign(swap_preview2["heroes"])
	app._refresh_party()
	_check(app.party.get_hero(3)["id"] == "warden", "AC4: Warden moved to position 3")

	app.deck.draw_pile.append("warden_counter_stitch")
	app.deck.draw_extra(1)
	app._refresh_hand()
	await _frames()
	var panel_cs_pos3: Control = _panel_for(app, "warden_counter_stitch")
	_check(panel_cs_pos3 != null, "AC4: Counter-stitch drawn while Warden at position 3")
	var snap_pos3: Array = _app_snapshot(app)
	await _mouse_click(panel_cs_pos3)
	_check(_app_snapshot(app) == snap_pos3, "AC4: Counter-stitch rejects when Warden is at position 3")

	await _return_to_title(app)

	# 4. Hidden panel & synthetic panel & captured callback
	app.run_seed = int(fixture.seed)
	_check(await _start_battle_in_app(app, fixture.fight), "AC4: start battle for panel controls")
	app.deck.draw_pile.append("warden_draw_fire")
	app.deck.draw_extra(1)
	app._refresh_hand()
	await _frames()
	var panel_ctl: Control = _panel_for(app, "warden_draw_fire")
	_check(panel_ctl != null, "AC4: panel ready for panel checks")
	var adapter: LiveWardenReactionHand = app.get_node("LiveWardenReactionHand") as LiveWardenReactionHand
	_check(adapter._bindings.has(panel_ctl), "AC4: panel bound by adapter")
	var captured_callback: Callable = adapter._bindings[panel_ctl]["callback"]

	panel_ctl.hide()
	await _frames()
	var snap_hidden: Array = _app_snapshot(app)
	captured_callback.call(_key(KEY_ENTER))
	await _frames()
	_check(_app_snapshot(app) == snap_hidden, "AC4: hidden panel rejected; state completely unchanged")
	panel_ctl.show()
	await _frames()

	# Synthetic panel outside hand_view
	var synthetic := PanelContainer.new()
	var synth_label := Label.new()
	synth_label.text = "warden_draw_fire"
	synthetic.add_child(synth_label)
	app.add_child(synthetic)
	await _frames()
	_check(not adapter._bindings.has(synthetic), "AC4: synthetic panel outside hand_view is never bound")
	synthetic.queue_free()
	await _frames()

	# Other card families not bound
	for panel: Node in app.hand_view.get_children():
		if panel is Control and panel.get_child_count() > 0 and panel.get_child(0) is Label:
			var label := panel.get_child(0) as Label
			if not CombatWardenGuardReactions.ALLOWED_CARD_IDS.has(label.text):
				_check(not adapter._bindings.has(panel), "AC4: adapter never binds non-reaction card: " + label.text)

	# Advance turn to make captured callback stale
	app.end_turn_button.pressed.emit()
	await _frames()
	var snap_stale: Array = _app_snapshot(app)
	captured_callback.call(_key(KEY_ENTER))
	await _frames()
	_check(_app_snapshot(app) == snap_stale, "AC4: captured callback across turns is inert; state unchanged")

	await _return_to_title(app)
	app.queue_free()
	await _frames()


# V3-1 Buckle Rebound is admitted to this rules service only, not the live hand.
# These are genuine card IDs in a real started CombatDeck, with no hand injection.
func _test_v3_buckle_rebound_paid_and_retaliation() -> void:
	var catalog: V3WardenPoolCards = V3WardenPoolCards.new()
	for card_id: String in ["warden_v3_buckle_rebound", "warden_v3_buckle_rebound_plus"]:
		var upgraded: bool = card_id.ends_with("_plus")
		var block: int = 6 if upgraded else 4
		var thorns_amount: int = 4 if upgraded else 3
		var definition: Dictionary = catalog.get_definition(card_id)
		_check(not definition.is_empty() and definition.get("id") == card_id,
			"V3 AC1: authentic " + card_id + " catalog record exists")
		_check(definition.get("owner") == "warden" and definition.get("cost") == 1
			and definition.get("from_positions") == [1, 2]
			and definition.get("target_kind") == "self" and definition.get("to_positions") == []
			and definition.get("effects") == {"block": block, "thorns": thorns_amount,
				"duration": "until_next_turn"}, "V3 AC1: exact printed metadata " + card_id)
		_check(definition.get("upgrade_of", "") == ("warden_v3_buckle_rebound" if upgraded else "")
			and definition.get("upgrade_id", "") == ("" if upgraded else "warden_v3_buckle_rebound_plus"),
			"V3 AC1: exact upgrade relation " + card_id)

		for seat: int in [1, 2]:
			var label: String = "V3 " + card_id + " seat " + str(seat)
			var party: CombatParty = _party_with_warden_at(seat)
			var enemies: CombatEnemies = _enemies()
			var deck: CombatDeck = _deck([card_id], 140 + seat)
			var reactions: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
			_check(deck.turn_active and deck.hand == [card_id]
				and deck.energy == CombatState.TURN_ENERGY,
				label + ": real turn really holds exactly this card")
			_check(party.get_hero(seat).get("id") == "warden"
				and not party.is_downed(seat), label + ": real living owner occupies this seat")
			var before: Array = party.get_heroes()
			var rng_before: int = deck._rng.state
			_check(reactions.play_from_hand(deck, party, card_id), label + ": paid play succeeds")
			_check(deck.energy == CombatState.TURN_ENERGY - 1
				and deck.hand.is_empty() and deck.discard_pile == [card_id],
				label + ": exactly one cost and one discard")
			_check(deck._rng.state == rng_before, label + ": play consumes no RNG")
			_check(party.get_hero(seat)["block"] == block
				and party.get_hero(seat)["hp"] == 40,
				label + ": only Warden gains exact printed Block")
			for ally_position: int in range(1, CombatParty.PARTY_SIZE + 1):
				if ally_position != seat:
					_check(party.get_hero(ally_position) == before[ally_position - 1],
						label + ": other hero " + str(ally_position) + " untouched")
			_check(reactions.get_thorns() == thorns_amount and not reactions.is_guarding(),
				label + ": correct Thorns, without invented Guarding")

			# A confirmed hit absorbed entirely by Block still retaliates.
			var first: Dictionary = reactions.resolve_enemy_attack(party, enemies,
				{"enemy_position": 1, "target_position": seat, "amount": 1})
			_check(first.get("ok") == true and first.get("applied") == true
				and first.get("retaliation_damage") == thorns_amount,
				label + ": actual Block-only hit retaliates")
			_check(party.get_hero(seat)["block"] == block - 1
				and party.get_hero(seat)["hp"] == 40
				and enemies.get_enemy(1)["hp"] == 12 - thorns_amount,
				label + ": Block absorbed hit, enemy took Thorns")

			# Another confirmed hit retaliates once again; an ally hit does not.
			var second: Dictionary = reactions.resolve_enemy_attack(party, enemies,
				{"enemy_position": 1, "target_position": seat, "amount": 1})
			_check(second.get("applied") == true and second.get("retaliation_damage") == thorns_amount
				and enemies.get_enemy(1)["hp"] == 12 - 2 * thorns_amount,
				label + ": second genuine hit triggers Thorns again")
			var warden_before_ally: Dictionary = party.get_hero(seat)
			var ally_position: int = 3 if seat == 2 else 2
			var enemy2_before: Dictionary = enemies.get_enemy(2)
			var ally: Dictionary = reactions.resolve_enemy_attack(party, enemies,
				{"enemy_position": 2, "target_position": ally_position, "amount": 2})
			_check(ally.get("applied") == true and ally.get("retaliation_damage") == 0
				and party.get_hero(seat) == warden_before_ally
				and enemies.get_enemy(2) == enemy2_before,
				label + ": hit on another hero cannot retaliate")

			# The real recipient's one-use Dodge prevents both damage and Thorns.
			party._heroes[seat - 1]["statuses"] = {"dodge_next_attack": 1}
			var before_dodge: Dictionary = party.get_hero(seat)
			var enemy_before_dodge: Dictionary = enemies.get_enemy(1)
			var dodge: Dictionary = reactions.resolve_enemy_attack(party, enemies,
				{"enemy_position": 1, "target_position": seat, "amount": 3})
			_check(dodge.get("ok") == true and dodge.get("applied") == false
				and dodge.get("retaliation_damage") == 0
				and party.get_hero(seat)["block"] == before_dodge["block"]
				and party.get_hero(seat)["hp"] == before_dodge["hp"]
				and not party.get_hero(seat)["statuses"].has("dodge_next_attack")
				and enemies.get_enemy(1) == enemy_before_dodge,
				label + ": Dodge consumes only token, never retaliates")

			_check(enemies.apply_damage(2, 15) and enemies.is_slain(2),
				label + ": slain-source precondition")
			var before_dead: Array = party.get_heroes()
			var dead_source: Dictionary = reactions.resolve_enemy_attack(party, enemies,
				{"enemy_position": 2, "target_position": seat, "amount": 2})
			_check(dead_source.get("ok") == true and dead_source.get("applied") == false
				and dead_source.get("retaliation_damage") == 0 and party.get_heroes() == before_dead,
				label + ": dead attacker cannot trigger Thorns")

			var block_before_expiry: int = int(party.get_hero(seat)["block"])
			_check(reactions.begin_player_turn() and not reactions.is_active()
				and reactions.get_thorns() == 0
				and party.get_hero(seat)["block"] == block_before_expiry,
				label + ": next turn expires Thorns but retains Block")
			var post_expiry: Dictionary = reactions.resolve_enemy_attack(party, enemies,
				{"enemy_position": 1, "target_position": seat, "amount": 1})
			_check(post_expiry.get("applied") == true and post_expiry.get("retaliation_damage") == 0,
				label + ": no Thorns after expiry")

		# Already-paid dispatch accepts the complete genuine v3 record at the
		# post-swap real Warden seat, without hand or deck side effects.
		var committed_party: CombatParty = _party_with_warden_at(2)
		var committed: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
		_check(committed.apply_committed_card(definition, committed_party)
			and committed_party.get_hero(2)["block"] == block
			and committed.get_thorns() == thorns_amount and not committed.is_guarding(),
			"V3 AC1: authentic already-paid " + card_id + " from seat 2")


func _test_v3_buckle_rebound_refusals_and_patches() -> void:
	var catalog: V3WardenPoolCards = V3WardenPoolCards.new()
	var foes: CombatEnemies = _enemies()
	for card_id: String in ["warden_v3_buckle_rebound", "warden_v3_buckle_rebound_plus"]:
		var upgraded: bool = card_id.ends_with("_plus")
		var authored_block: int = 6 if upgraded else 4
		var authored_thorns: int = 4 if upgraded else 3
		var card: Dictionary = catalog.get_definition(card_id)
		_check(not card.is_empty(), "V3 AC3: genuine metadata exists for rejection controls")
		var reactions: CombatWardenGuardReactions = CombatWardenGuardReactions.new()

		var not_held: CombatDeck = _deck(["warden_draw_fire"], 201)
		_check(not not_held.hand.has(card_id), "V3 AC3: absent-card precondition")
		_refuse_paid(reactions, not_held, _party(), foes, card_id,
			"V3 AC3: unheld " + card_id)
		var foreign: CombatDeck = _deck(["warden_v3_shield_toss"], 203)
		_check(foreign.hand == ["warden_v3_shield_toss"],
			"V3 AC3: held unsupported card precondition")
		_refuse_paid(reactions, foreign, _party(), foes, "warden_v3_shield_toss",
			"V3 AC3: foreign v3 card")
		var inactive: CombatDeck = CombatDeck.new([card_id], _rng(205))
		inactive.hand.append(card_id)
		_check(not inactive.turn_active and inactive.hand.has(card_id),
			"V3 AC3: inactive but held precondition")
		_refuse_paid(reactions, inactive, _party(), foes, card_id,
			"V3 AC3: inactive turn")
		var poor: CombatDeck = _deck([card_id], 207)
		_check(poor.try_spend_energy(CombatState.TURN_ENERGY) and poor.energy == 0,
			"V3 AC3: unaffordable precondition")
		_refuse_paid(reactions, poor, _party(), foes, card_id, "V3 AC3: no energy")

		var no_warden: CombatParty = CombatParty.new([
			{"id": "seamstress", "max_hp": 30},
			{"id": "tinker", "max_hp": 26},
			{"id": "another", "max_hp": 20},
		])
		_check(no_warden.is_valid(), "V3 AC3: valid roster without a Warden")
		_refuse_paid(reactions, _deck([card_id], 209), no_warden, foes, card_id,
			"V3 AC3: absent Warden")
		var downed: CombatParty = _party()
		_check(downed.apply_damage(1, 40) and downed.is_downed(1),
			"V3 AC3: downed Warden precondition")
		_refuse_paid(reactions, _deck([card_id], 211), downed, foes, card_id,
			"V3 AC3: downed Warden")
		_refuse_paid(reactions, _deck([card_id], 213),
			_party_with_warden_at(3), foes, card_id, "V3 AC3: wrong seat 3")
		_refuse_committed(reactions, card, _party_with_warden_at(3), foes,
			"V3 AC3: already-paid wrong seat 3")

		var capped: CombatParty = _party()
		capped._heroes[0]["block"] = CombatParty.MAX_INT
		_refuse_paid(reactions, _deck([card_id], 215), capped, foes, card_id,
			"V3 AC3: Block capacity")
		_refuse_committed(reactions, card, capped, foes,
			"V3 AC3: committed Block capacity")
		var full_thorns: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
		full_thorns.thorns = CombatParty.MAX_INT
		_refuse_paid(full_thorns, _deck([card_id], 217), _party(), foes, card_id,
			"V3 AC3: Thorns capacity")
		_refuse_committed(full_thorns, card, _party(), foes,
			"V3 AC3: committed Thorns capacity")

		# An ID plus incomplete or substituted card metadata is not a paid receipt.
		var forgeries: Array = []
		var fake_cost: Dictionary = card.duplicate(true)
		fake_cost["cost"] = 0
		forgeries.append(fake_cost)
		var fake_owner: Dictionary = card.duplicate(true)
		fake_owner["owner"] = "tinker"
		forgeries.append(fake_owner)
		var fake_seat: Dictionary = card.duplicate(true)
		fake_seat["from_positions"] = [1, 2, 3]
		forgeries.append(fake_seat)
		var fake_target: Dictionary = card.duplicate(true)
		fake_target["target_kind"] = "ally_single"
		forgeries.append(fake_target)
		var fake_to: Dictionary = card.duplicate(true)
		fake_to["to_positions"] = [1]
		forgeries.append(fake_to)
		var fake_effects: Dictionary = card.duplicate(true)
		fake_effects["effects"]["thorns"] = 999
		forgeries.append(fake_effects)
		var fake_relation: Dictionary = card.duplicate(true)
		fake_relation["upgrade_of" if upgraded else "upgrade_id"] = "warden_draw_fire"
		forgeries.append(fake_relation)
		var incomplete: Dictionary = {"id": card_id}
		forgeries.append(incomplete)
		var missing_effects: Dictionary = card.duplicate(true)
		missing_effects.erase("effects")
		forgeries.append(missing_effects)
		for index: int in range(forgeries.size()):
			_refuse_committed(reactions, forgeries[index], _party(), foes,
				"V3 AC3: forged catalog record " + card_id + " case " + str(index))
		_check(reactions.get_thorns() == 0 and not reactions.is_guarding(),
			"V3 AC3: failed records leave modes untouched")

		# Both genuine worn patches add Block to the Warden alone through the
		# same authenticated ARM and HEAD rules as legacy reaction cards.
		var worn: Dictionary = _patch_fixture({"HEAD": "warden", "ARM": "warden"})
		var patched: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
		_check(patched.bind_patch_wardrobe(worn["wardrobe"], worn["torn"]),
			"V3 AC1: bind genuine Warden-worn HEAD/ARM patches")
		_check(patched.project_block(card_id) == {
			"ok": true, "block": authored_block + 4, "bonus": 4},
			"V3 AC1: both patches contribute exactly +4 Block to " + card_id)
		var patched_party: CombatParty = _party()
		var patched_deck: CombatDeck = _deck([card_id], 219)
		_check(patched.play_from_hand(patched_deck, patched_party, card_id)
			and patched_party.get_hero(1)["block"] == authored_block + 4
			and patched.get_thorns() == authored_thorns,
			"V3 AC1: paid patched Block and unchanged Thorns " + card_id)
		var other_wearer: Dictionary = _patch_fixture({"HEAD": "tinker", "ARM": "tinker"})
		var unboosted: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
		_check(unboosted.bind_patch_wardrobe(other_wearer["wardrobe"], other_wearer["torn"])
			and unboosted.project_block(card_id).get("block") == authored_block
			and unboosted.project_block(card_id).get("bonus") == 0,
			"V3 AC1: another hero's patches cannot boost " + card_id)


# =============================================================================
# V3-1 Shield Catch / Guard Stitch: one-use ally interception
# =============================================================================

## Independent oracle from the brief: owner, printed Block and catalog identity. Never derived from
## the catalog or from the service under test.
func _v3_guard_table() -> Dictionary:
	return {
		"warden_v3_shield_catch": {"catalog": "starter", "display_name": "Shield Catch",
			"block": 4, "starting_copies": 1, "reward_eligible": false, "has_rarity": false,
			"upgrade_id": "warden_v3_shield_catch_plus", "upgrade_of": ""},
		"warden_v3_shield_catch_plus": {"catalog": "starter", "display_name": "Shield Catch+",
			"block": 6, "starting_copies": 0, "reward_eligible": false, "has_rarity": false,
			"upgrade_id": "", "upgrade_of": "warden_v3_shield_catch"},
		"warden_v3_guard_stitch": {"catalog": "pool", "display_name": "Guard Stitch",
			"block": 5, "starting_copies": 0, "reward_eligible": true, "has_rarity": true,
			"upgrade_id": "warden_v3_guard_stitch_plus", "upgrade_of": ""},
		"warden_v3_guard_stitch_plus": {"catalog": "pool", "display_name": "Guard Stitch+",
			"block": 7, "starting_copies": 0, "reward_eligible": false, "has_rarity": true,
			"upgrade_id": "", "upgrade_of": "warden_v3_guard_stitch"},
	}


func _v3_guard_definition(card_id: String) -> Dictionary:
	var spec: Dictionary = _v3_guard_table()[card_id]
	if spec["catalog"] == "starter":
		return V3WardenStarterCards.new().get_definition(card_id)
	return V3WardenPoolCards.new().get_definition(card_id)


func _guard_snapshot(deck: CombatDeck, party: CombatParty,
		guard: CombatWardenV3GuardCards, taunt: Variant = null) -> Array:
	return [
		party.get_heroes(),
		deck.hand.duplicate(true),
		deck.draw_pile.duplicate(true),
		deck.discard_pile.duplicate(true),
		deck.exhausted.duplicate(true),
		deck.energy,
		deck.turn_active,
		deck.combat_state.energy,
		deck.combat_state.player_turn_active,
		guard.has_pending_guard(),
		guard.get_guarded_hero_id(),
		guard.get_pending_guard_card_id(),
		guard.has_universal_guard(),
		_taunt_snapshot(taunt),
		deck._rng.state,
		deck._rng.seed,
	]


## The separately held battle Taunt authority's complete pending state, so a refusal can prove
## that a required reaction really stayed unarmed.
func _taunt_snapshot(taunt: Variant) -> Array:
	if not (taunt is CombatWardenV3TauntCards):
		return ["no_authority"]
	var authority: CombatWardenV3TauntCards = taunt
	return [authority.has_pending_taunt(), authority.get_pending_taunt_card_id()]


func _guard_state(party: CombatParty, guard: CombatWardenV3GuardCards) -> Array:
	return [
		party.get_heroes(),
		guard.has_pending_guard(),
		guard.get_guarded_hero_id(),
		guard.get_pending_guard_card_id(),
	]


func _refuse_guard(guard: CombatWardenV3GuardCards, deck: CombatDeck,
		party: CombatParty, card_id: Variant, target_position: int,
		label: String, taunt: Variant = null) -> Dictionary:
	var before: Array = _guard_snapshot(deck, party, guard, taunt)
	var receipt: Dictionary = guard.play_card(deck, party, card_id, target_position)
	_check(not receipt.get("ok", false), label + ": refused")
	_check(_guard_snapshot(deck, party, guard, taunt) == before,
		label + ": hand, piles, energy, party, pending guard, pending taunt and RNG unchanged")
	return receipt


## AC1/AC2: all four catalog printings, both legal Warden seats, exact paid Block, one-shot
## interception keyed by hero identity, confirmed-hit consumption, miss/non-attack preservation,
## a second hit after consumption being ordinary, and a legal seat change following the hero.
func _test_v3_guard_cards_paid_and_interception() -> void:
	var table: Dictionary = _v3_guard_table()
	var seat_runs := 0
	for card_id: String in table:
		var spec: Dictionary = table[card_id]
		var definition: Dictionary = _v3_guard_definition(card_id)
		_check(not definition.is_empty() and definition.get("id") == card_id,
			"V3 Guard AC1: authentic catalog record exists for " + card_id)
		_check(definition.get("display_name") == spec["display_name"]
			and definition.get("owner") == "warden" and definition.get("cost") == 1
			and definition.get("target_kind") == "ally_single"
			and definition.get("from_positions") == [1, 2]
			and definition.get("to_positions") == []
			and definition.get("effects") == {"block": int(spec["block"]),
				"guard_next_hit": true}
			and definition.get("starting_copies") == int(spec["starting_copies"])
			and definition.get("reward_eligible") == bool(spec["reward_eligible"])
			and definition.get("upgrade_id", "") == str(spec["upgrade_id"])
			and definition.get("upgrade_of", "") == str(spec["upgrade_of"]),
			"V3 Guard AC1: exact printed metadata for " + card_id)
		if bool(spec["has_rarity"]):
			_check(definition.get("rarity") == "common",
				"V3 Guard AC1: pool rarity preserved for " + card_id)
		else:
			_check(not definition.has("rarity"),
				"V3 Guard AC1: starter record keeps no pool rarity for " + card_id)

		var service: CombatWardenV3GuardCards = CombatWardenV3GuardCards.new()
		_check(service.is_supported_card(card_id) and service.is_authentic_card(card_id),
			"V3 Guard AC1: service authenticates " + card_id)

		for seat: int in [1, 2]:
			var label: String = "V3 Guard " + card_id + " seat " + str(seat)
			seat_runs += 1
			var party: CombatParty = _party_with_warden_at(seat)
			var deck: CombatDeck = _deck([card_id], 300 + seat * 7 + table.keys().find(card_id))
			var guard: CombatWardenV3GuardCards = CombatWardenV3GuardCards.new()
			_check(deck.turn_active and deck.hand == [card_id]
				and deck.energy == CombatState.TURN_ENERGY,
				label + ": real turn really holds exactly this card")
			_check(party.get_hero(seat)["id"] == "warden" and not party.is_downed(seat),
				label + ": living Warden really occupies this seat")
			var before: Array = party.get_heroes()
			var rng_before: int = deck._rng.state
			var target: int = 3
			var receipt: Dictionary = guard.play_card(deck, party, card_id, target)
			_check(receipt.get("ok", false) and receipt.get("reason") == "applied",
				label + ": paid play accepted")
			_check(int(receipt.get("owner_position", 0)) == seat
				and int(receipt.get("target_position", 0)) == target
				and int(receipt.get("cost", 0)) == 1
				and int(receipt.get("energy_spent", 0)) == 1,
				label + ": receipt names the current Warden seat and the paid cost")
			_check(deck.energy == CombatState.TURN_ENERGY - 1,
				label + ": exactly one shared energy spent")
			_check(deck.hand.is_empty() and deck.discard_pile == [card_id],
				label + ": exactly one held copy discarded")
			_check(deck._rng.state == rng_before, label + ": play consumes no RNG")
			_check(party.get_hero(target)["block"] == int(spec["block"]),
				label + ": chosen ally gains exactly " + str(spec["block"]) + " Block")
			_check(party.get_hero(target)["hp"] == before[target - 1]["hp"],
				label + ": chosen ally HP untouched")
			for position: int in range(1, CombatParty.PARTY_SIZE + 1):
				if position != target:
					_check(party.get_hero(position) == before[position - 1],
						label + ": hero " + str(position) + " untouched by the Block")
			_check(guard.has_pending_guard()
				and guard.get_guarded_hero_id() == "tinker"
				and guard.get_pending_guard_card_id() == card_id,
				label + ": interception is armed on the chosen ally identity")

			# Read-only projection for an announced attack on the protected ally.
			var party_before_projection: Array = party.get_heroes()
			var projection: Dictionary = guard.project_interception(party, target)
			_check(projection.get("ok", false) and projection.get("eligible", false)
				and projection.get("redirected", false)
				and int(projection.get("announced_target_position", 0)) == target
				and int(projection.get("actual_target_position", 0)) == seat
				and projection.get("guarded_hero_id") == "tinker"
				and int(projection.get("warden_position", 0)) == seat,
				label + ": projection nominates the Warden's current seat")
			_check(party.get_heroes() == party_before_projection,
				label + ": projection mutates nothing")

			# A confirmed hit on another hero neither redirects nor consumes.
			var other_position: int = 2 if seat == 1 else 1
			var other: Dictionary = guard.consume_confirmed_hit(party, other_position, true)
			_check(not other.get("consumed", false) and guard.has_pending_guard(),
				label + ": a hit on another hero does not consume the guard")
			_check(int(other.get("actual_target_position", 0)) == other_position,
				label + ": the other hero keeps its ordinary target")

			# A miss or a non-attack is not a confirmed hit: nothing is consumed.
			var miss: Dictionary = guard.consume_confirmed_hit(party, target, false)
			_check(not miss.get("consumed", false) and guard.has_pending_guard(),
				label + ": miss/non-attack does not consume the guard")
			var still_armed: Dictionary = guard.project_interception(party, target)
			_check(still_armed.get("eligible", false)
				and still_armed.get("redirected", false),
				label + ": the guard is still armed after a miss")

			# A confirmed hit absorbed entirely by Warden Block still consumes the one-shot.
			_check(party.gain_block(seat, 2), label + ": Warden prepares 2 Block")
			var warden_hp_before: int = int(party.get_hero(seat)["hp"])
			var warden_block_before: int = int(party.get_hero(seat)["block"])
			var ally_block_before: int = int(party.get_hero(target)["block"])
			_check(party.apply_damage(seat, 1),
				label + ": ordinary Block-before-HP hit lands on the Warden")
			_check(party.get_hero(seat)["hp"] == warden_hp_before
				and party.get_hero(seat)["block"] == warden_block_before - 1,
				label + ": Warden Block really absorbed the hit")
			_check(party.get_hero(target)["block"] == ally_block_before
				and party.get_hero(target)["hp"] == before[target - 1]["hp"],
				label + ": protected ally took no damage and kept its Block")
			var confirmed: Dictionary = guard.consume_confirmed_hit(party, target, true)
			_check(confirmed.get("ok", false) and confirmed.get("consumed", false)
				and int(confirmed.get("actual_target_position", 0)) == seat,
				label + ": Block-absorbed confirmed hit consumes the interception")
			_check(not guard.has_pending_guard() and guard.get_guarded_hero_id() == ""
				and guard.get_pending_guard_card_id() == "",
				label + ": pending guard is cleared after consumption")

			# The next hit after consumption is ordinary and consumes nothing.
			var second_projection: Dictionary = guard.project_interception(party, target)
			_check(second_projection.get("ok", false)
				and not second_projection.get("eligible", false)
				and not second_projection.get("redirected", false)
				and int(second_projection.get("actual_target_position", 0)) == target,
				label + ": following hit is ordinary")
			var second: Dictionary = guard.consume_confirmed_hit(party, target, true)
			_check(not second.get("consumed", false)
				and int(second.get("actual_target_position", 0)) == target,
				label + ": following confirmed hit consumes nothing")
	_check(seat_runs == 8, "V3 Guard AC1: all four printings played from both legal seats")

	# A self-selected Warden gets the printed Block but never redirects another hero's hit.
	var self_party: CombatParty = _party()
	var self_deck: CombatDeck = _deck(["warden_v3_shield_catch"], 401)
	var self_guard: CombatWardenV3GuardCards = CombatWardenV3GuardCards.new()
	_check(self_guard.play_card(self_deck, self_party, "warden_v3_shield_catch", 1).get("ok", false),
		"V3 Guard AC2: self-selected Warden play accepted")
	_check(self_party.get_hero(1)["block"] == 4,
		"V3 Guard AC2: self-selected Warden gains exact printed 4 Block")
	_check(self_guard.get_guarded_hero_id() == "warden",
		"V3 Guard AC2: self-selected Warden is the protected identity")
	var self_projection: Dictionary = self_guard.project_interception(self_party, 1)
	_check(self_projection.get("eligible", false)
		and not self_projection.get("redirected", false)
		and int(self_projection.get("actual_target_position", 0)) == 1,
		"V3 Guard AC2: hit on the Warden stays on the Warden")
	var ally_projection: Dictionary = self_guard.project_interception(self_party, 2)
	_check(ally_projection.get("ok", false)
		and not ally_projection.get("eligible", false)
		and int(ally_projection.get("actual_target_position", 0)) == 2,
		"V3 Guard AC2: self-guard never redirects another hero's hit")
	var self_hit: Dictionary = self_guard.consume_confirmed_hit(self_party, 1, true)
	_check(self_hit.get("consumed", false)
		and int(self_hit.get("actual_target_position", 0)) == 1,
		"V3 Guard AC2: confirmed hit on the self-guarded Warden consumes the one-shot")

	# The protected identity follows a legal seat change; the remembered seat is not used.
	var moved_party: CombatParty = _party()
	var moved_deck: CombatDeck = _deck(["warden_v3_guard_stitch"], 503)
	var moved_guard: CombatWardenV3GuardCards = CombatWardenV3GuardCards.new()
	_check(moved_guard.play_card(moved_deck, moved_party, "warden_v3_guard_stitch", 3).get("ok", false),
		"V3 Guard AC2: guard on Tinker at seat 3 accepted")
	_check(moved_party.get_hero(3)["block"] == 5,
		"V3 Guard AC2: Tinker holds exact 5 Block before moving")
	var swap_one: Dictionary = CombatPositionSwaps.preview_adjacent_swap(moved_party, 3, -1)
	_check(swap_one.get("ok", false), "V3 Guard AC2: first legal swap preview")
	moved_party._heroes.assign(swap_one["heroes"])
	var swap_two: Dictionary = CombatPositionSwaps.preview_adjacent_swap(moved_party, 2, -1)
	_check(swap_two.get("ok", false), "V3 Guard AC2: second legal swap preview")
	moved_party._heroes.assign(swap_two["heroes"])
	_check(moved_party.get_hero(1)["id"] == "tinker"
		and moved_party.get_hero(1)["block"] == 5,
		"V3 Guard AC2: protected Tinker now lives in seat 1 with its Block")
	_check(moved_party.get_hero(2)["id"] == "warden",
		"V3 Guard AC2: Warden now lives in seat 2")
	_check(moved_guard.get_guarded_hero_id() == "tinker",
		"V3 Guard AC2: pending protection stays keyed by hero identity")
	var moved_projection: Dictionary = moved_guard.project_interception(moved_party, 1)
	_check(moved_projection.get("eligible", false)
		and moved_projection.get("redirected", false)
		and int(moved_projection.get("announced_target_position", 0)) == 1
		and int(moved_projection.get("actual_target_position", 0)) == 2
		and int(moved_projection.get("guarded_position", 0)) == 1
		and int(moved_projection.get("warden_position", 0)) == 2,
		"V3 Guard AC2: projection follows both heroes to their current seats")
	var moved_hit: Dictionary = moved_guard.consume_confirmed_hit(moved_party, 1, true)
	_check(moved_hit.get("consumed", false)
		and int(moved_hit.get("actual_target_position", 0)) == 2,
		"V3 Guard AC2: consumption uses the moved Warden's current seat")


## AC3: forged, unheld, unaffordable, inactive, illegal-seat, downed-owner and downed-target
## preflights all fail closed before any charge, with complete before/after snapshots.
func _test_v3_guard_cards_refusals() -> void:
	var card: String = "warden_v3_guard_stitch"

	# 1. Invalid and unsupported IDs keep every byte of state.
	var id_party: CombatParty = _party()
	var id_deck: CombatDeck = _deck([card], 601)
	var id_guard: CombatWardenV3GuardCards = CombatWardenV3GuardCards.new()
	_check(id_deck.hand == [card] and id_deck.energy == CombatState.TURN_ENERGY,
		"V3 Guard AC3: invalid-ID fixture really holds the card and energy")
	for bad_id in [null, "", 7, "fake_guard_card", "warden_v3_shield_toss"]:
		_refuse_guard(id_guard, id_deck, id_party, bad_id, 2,
			"V3 Guard AC3: invalid ID " + str(bad_id))
	_check(not id_guard.is_supported_card("warden_v3_shield_toss")
		and not id_guard.is_supported_card(null),
		"V3 Guard AC3: non-guard IDs are unsupported, not silently aliased")

	# 2. Authentic but not held.
	var not_held: CombatDeck = _deck(["warden_v3_shield_catch"], 603)
	_check(not not_held.hand.has(card), "V3 Guard AC3: not-held precondition")
	_refuse_guard(id_guard, not_held, _party(), card, 2, "V3 Guard AC3: authentic but unheld")

	# 3. Unaffordable after a genuine full spend.
	var poor: CombatDeck = _deck([card], 605)
	_check(poor.try_spend_energy(CombatState.TURN_ENERGY) and poor.energy == 0,
		"V3 Guard AC3: unaffordable precondition")
	_refuse_guard(id_guard, poor, _party(), card, 2, "V3 Guard AC3: no energy")

	# 4. Inactive turn, and null deck/party.
	var inactive: CombatDeck = CombatDeck.new([card], _rng(607))
	inactive.hand.append(card)
	_check(not inactive.turn_active and inactive.hand.has(card),
		"V3 Guard AC3: inactive but held precondition")
	_refuse_guard(id_guard, inactive, _party(), card, 2, "V3 Guard AC3: inactive turn")
	var null_party: CombatParty = _party()
	var null_deck: CombatDeck = _deck([card], 609)
	var null_state: Array = _guard_state(null_party, id_guard)
	var null_receipt: Dictionary = id_guard.play_card(null_deck, null, card, 2)
	_check(not null_receipt.get("ok", false)
		and _guard_state(null_party, id_guard) == null_state,
		"V3 Guard AC3: null party refused without state change")
	var null_deck_receipt: Dictionary = id_guard.play_card(null, null_party, card, 2)
	_check(not null_deck_receipt.get("ok", false)
		and _guard_state(null_party, id_guard) == null_state,
		"V3 Guard AC3: null deck refused without state change")
	# A deck without its shared combat state is invalid, not an ordinary inactive turn.
	var broken_deck: CombatDeck = _deck([card], 629)
	var broken_state: Array = [
		broken_deck.hand.duplicate(true), broken_deck.draw_pile.duplicate(true),
		broken_deck.discard_pile.duplicate(true), broken_deck._rng.state,
		broken_deck._rng.seed, null_party.get_heroes(),
		id_guard.has_pending_guard(), id_guard.get_guarded_hero_id(),
	]
	broken_deck.combat_state = null
	var broken_receipt: Dictionary = id_guard.play_card(broken_deck, null_party, card, 2)
	_check(not broken_receipt.get("ok", false)
		and broken_receipt.get("reason") == "invalid_deck",
		"V3 Guard AC3: deck without combat state reports invalid_deck")
	var broken_after: Array = [
		broken_deck.hand.duplicate(true), broken_deck.draw_pile.duplicate(true),
		broken_deck.discard_pile.duplicate(true), broken_deck._rng.state,
		broken_deck._rng.seed, null_party.get_heroes(),
		id_guard.has_pending_guard(), id_guard.get_guarded_hero_id(),
	]
	_check(broken_after == broken_state,
		"V3 Guard AC3: invalid deck refused without pile, party, guard or RNG change")

	# 5. Illegal Warden seat and downed Warden.
	_refuse_guard(id_guard, _deck([card], 611), _party_with_warden_at(3), card, 2,
		"V3 Guard AC3: Warden in illegal seat 3")
	var downed_warden: CombatParty = _party()
	_check(downed_warden.apply_damage(1, 40) and downed_warden.is_downed(1),
		"V3 Guard AC3: downed Warden precondition")
	_refuse_guard(id_guard, _deck([card], 613), downed_warden, card, 2,
		"V3 Guard AC3: downed Warden")

	# 6. Invalid and downed ally targets.
	var target_party: CombatParty = _party()
	var target_deck: CombatDeck = _deck([card], 615)
	for bad_target: int in [0, 4, -1]:
		_refuse_guard(id_guard, target_deck, target_party, card, bad_target,
			"V3 Guard AC3: invalid ally seat " + str(bad_target))
	var downed_target_party: CombatParty = _party()
	_check(downed_target_party.apply_damage(2, 30) and downed_target_party.is_downed(2),
		"V3 Guard AC3: downed ally precondition")
	_refuse_guard(id_guard, _deck([card], 617), downed_target_party, card, 2,
		"V3 Guard AC3: downed ally target")

	# 7. Block capacity on the chosen ally.
	var capped: CombatParty = _party()
	capped._heroes[2]["block"] = CombatParty.MAX_INT
	_refuse_guard(id_guard, _deck([card], 619), capped, card, 3,
		"V3 Guard AC3: chosen ally Block capacity")

	# 8. A forged record for an otherwise valid, held ID is refused through the catalog seam.
	var forged_starter_record: Dictionary = V3WardenStarterCards.new().get_definition(
		"warden_v3_shield_catch")
	forged_starter_record["effects"]["block"] = 99
	var forged_starter := ForgedStarterGuardCatalog.new()
	forged_starter.forged_id = "warden_v3_shield_catch"
	forged_starter.forged_record = forged_starter_record
	var forged_guard: CombatWardenV3GuardCards = CombatWardenV3GuardCards.new(forged_starter)
	_check(not forged_guard.is_authentic_card("warden_v3_shield_catch"),
		"V3 Guard AC3: forged starter record authenticates as nothing")
	_refuse_guard(forged_guard, _deck(["warden_v3_shield_catch"], 621), _party(),
		"warden_v3_shield_catch", 2, "V3 Guard AC3: forged Shield Catch")
	var forged_pool_record: Dictionary = V3WardenPoolCards.new().get_definition(
		"warden_v3_guard_stitch")
	forged_pool_record["effects"]["guard_next_hit"] = false
	var forged_pool := ForgedPoolGuardCatalog.new()
	forged_pool.forged_id = "warden_v3_guard_stitch"
	forged_pool.forged_record = forged_pool_record
	var forged_pool_guard: CombatWardenV3GuardCards = CombatWardenV3GuardCards.new(null,
		forged_pool)
	_check(not forged_pool_guard.is_authentic_card("warden_v3_guard_stitch"),
		"V3 Guard AC3: forged pool record authenticates as nothing")
	_refuse_guard(forged_pool_guard, _deck(["warden_v3_guard_stitch"], 623), _party(),
		"warden_v3_guard_stitch", 2, "V3 Guard AC3: forged Guard Stitch")

	# 9. A refusal never disturbs an already-pending interception.
	var pending_party: CombatParty = _party()
	var pending_deck: CombatDeck = _deck(["warden_v3_shield_catch", "warden_v3_guard_stitch"], 625)
	var pending_guard: CombatWardenV3GuardCards = CombatWardenV3GuardCards.new()
	_check(pending_guard.play_card(pending_deck, pending_party,
		"warden_v3_shield_catch", 2).get("ok", false),
		"V3 Guard AC3: pending-guard fixture arms a real interception")
	_check(pending_guard.get_guarded_hero_id() == "seamstress"
		and pending_party.get_hero(2)["block"] == 4,
		"V3 Guard AC3: pending-guard fixture is really armed on Seamstress")
	_refuse_guard(pending_guard, pending_deck, pending_party, "warden_v3_guard_stitch", 4,
		"V3 Guard AC3: refused play with pending guard")
	_check(pending_guard.has_pending_guard()
		and pending_guard.get_guarded_hero_id() == "seamstress"
		and pending_guard.get_pending_guard_card_id() == "warden_v3_shield_catch",
		"V3 Guard AC3: pending guard survives the refusal")
	var pending_projection: Dictionary = pending_guard.project_interception(pending_party, 2)
	_check(pending_projection.get("eligible", false)
		and pending_projection.get("redirected", false)
		and int(pending_projection.get("actual_target_position", 0)) == 1,
		"V3 Guard AC3: pending guard still redirects after the refusal")

	# 10. Deterministic replay of the whole accepted transaction.
	var replay: Array = []
	for repetition: int in range(2):
		var r_party: CombatParty = _party()
		var r_deck: CombatDeck = _deck(["warden_v3_shield_catch_plus"], 627)
		var r_guard: CombatWardenV3GuardCards = CombatWardenV3GuardCards.new()
		var r_play: Dictionary = r_guard.play_card(r_deck, r_party,
			"warden_v3_shield_catch_plus", 3)
		var r_projection: Dictionary = r_guard.project_interception(r_party, 3)
		var r_consume: Dictionary = r_guard.consume_confirmed_hit(r_party, 3, true)
		var pack: Array = [r_play, r_projection, r_consume, r_party.get_heroes(),
			r_deck.discard_pile, r_deck._rng.state]
		if repetition == 0:
			replay = pack.duplicate(true)
		else:
			_check(pack == replay, "V3 Guard AC3: fixed-seed replay is identical")


class ForgedStarterGuardCatalog extends V3WardenStarterCards:
	var forged_id: String = ""
	var forged_record: Dictionary = {}

	func get_definition(card_id: Variant) -> Dictionary:
		if typeof(card_id) == TYPE_STRING and (card_id as String) == forged_id:
			return forged_record.duplicate(true)
		return super.get_definition(card_id)


class ForgedPoolGuardCatalog extends V3WardenPoolCards:
	var forged_id: String = ""
	var forged_record: Dictionary = {}

	func get_definition(card_id: Variant) -> Dictionary:
		if typeof(card_id) == TYPE_STRING and (card_id as String) == forged_id:
			return forged_record.duplicate(true)
		return super.get_definition(card_id)


# =============================================================================
# V3-1 Final Bastion: rare self Block + universal ally Guard + next-enemy-turn Taunt
# =============================================================================

func _test_v3_final_bastion_paid_and_interaction() -> void:
	var catalog: V3WardenPoolCards = V3WardenPoolCards.new()
	var base_id: String = "warden_v3_final_bastion"
	var plus_id: String = "warden_v3_final_bastion_plus"

	# AC1: both printings are authentic pool records with the exact authored line and links.
	for card_id: String in [base_id, plus_id]:
		var definition: Dictionary = catalog.get_definition(card_id)
		_check(not definition.is_empty() and definition.get("id") == card_id,
			"V3 Final Bastion AC1: authentic catalog record exists for " + card_id)
		_check(definition.get("owner") == "warden" and definition.get("cost") == 3
			and definition.get("from_positions") == [1]
			and definition.get("target_kind") == "self" and definition.get("to_positions") == []
			and definition.get("effects") == ({"block": 12, "guard_next_hit": true, "taunt_next_enemy_turn": true} if card_id == base_id else {"block": 16, "guard_next_hit": true, "taunt_next_enemy_turn": true}),
			"V3 Final Bastion AC1: exact printed metadata for " + card_id)
		_check(definition.get("rarity") == "rare"
			and definition.get("reward_eligible") == (true if card_id == base_id else false)
			and definition.get("upgrade_id", "") == (plus_id if card_id == base_id else "")
			and definition.get("upgrade_of", "") == ("" if card_id == base_id else base_id),
			"V3 Final Bastion AC1: exact rarity/reward/upgrade links for " + card_id)
		var companion_id: String = plus_id if card_id == base_id else base_id
		_check(not catalog.get_definition(companion_id).is_empty(),
			"V3 Final Bastion AC1: reciprocal companion printing exists for " + card_id)

	# AC1/AC2: two independent real Guard and Taunt objects passed together; both printings pay
	# exactly 3 energy, discard exactly one held copy, give only the Warden 12/16 Block and arm
	# THAT SAME battle Taunt authority plus the universal ally guard.
	for card_id: String in [base_id, plus_id]:
		var expected_block: int = 12 if card_id == base_id else 16
		var label: String = "V3 Final Bastion " + card_id
		var party: CombatParty = _party()
		var deck: CombatDeck = _paid_deck(card_id, 700 + (0 if card_id == base_id else 1))
		var taunt: CombatWardenV3TauntCards = CombatWardenV3TauntCards.new()
		var guard: CombatWardenV3GuardCards = CombatWardenV3GuardCards.new(null, null, taunt)
		_check(deck.turn_active and deck.hand == [card_id]
			and deck.energy == CombatState.TURN_ENERGY,
			label + ": real 3-energy turn really holds exactly this card")
		_check(is_same(guard.get_taunt_authority(), taunt),
			label + ": resolver holds the caller-supplied battle Taunt authority")
		var before: Array = party.get_heroes()
		var rng_before: int = deck._rng.state
		var energy_before: int = deck.energy
		var draw_before: Array = deck.draw_pile.duplicate(true)

		var receipt: Dictionary = guard.play_card(deck, party, card_id, 1)
		_check(receipt.get("ok", false) and receipt.get("reason") == "applied",
			label + ": paid play accepted")
		_check(receipt.get("taunt_armed") == true, label + ": receipt reports the armed Taunt")
		_check(deck.energy == energy_before - 3 and deck.energy == 0,
			label + ": exactly 3 of the turn's 3 energy spent")
		_check(int(receipt.get("energy_spent", 0)) == 3
			and int(receipt.get("energy_after", -1)) == 0,
			label + ": receipt reports exactly one 3-cost payment")
		_check(deck.hand.is_empty() and deck.discard_pile == [card_id],
			label + ": exactly one held copy discarded and no new draw")
		_check(deck.draw_pile == draw_before, label + ": draw pile untouched")
		_check(party.get_hero(1)["block"] == expected_block,
			label + ": Warden gains exactly " + str(expected_block) + " Block")
		_check(party.get_hero(1)["hp"] == 40, label + ": Warden HP untouched")
		for other: int in [2, 3]:
			_check(party.get_hero(other) == before[other - 1],
				label + ": ally seat " + str(other) + " completely untouched")
		_check(deck._rng.state == rng_before, label + ": deck RNG untouched by the play")
		_check(guard.has_pending_guard() and guard.has_universal_guard()
			and guard.get_pending_guard_card_id() == card_id,
			label + ": universal ally guard is armed with the card ID")
		_check(guard.get_guarded_hero_id() == "",
			label + ": universal guard forges no target hero ID")
		_check(taunt.has_pending_taunt() and taunt.get_pending_taunt_card_id() == card_id,
			label + ": the SAME battle Taunt authority is really armed")
		_check(not CombatWardenV3TauntCards.CARDS.has(card_id),
			label + ": Final Bastion was never added to the paid Taunt card set")

		# AC2: every eligible attack of the next whole enemy turn redirects to the living
		# Warden's current seat; an attack already aimed at him stays there.
		for announced: int in [2, 3, 1, 3, 2]:
			var target: Dictionary = taunt.project_attack_target(party, announced)
			_check(target.get("ok", false) and target.get("eligible", false),
				label + ": announced attack " + str(announced) + " is a valid target")
			_check(int(target.get("announced_target_position", 0)) == announced
				and int(target.get("actual_target_position", 0)) == 1,
				label + ": announced attack " + str(announced) + " lands on the Warden seat 1")
			_check(target.get("redirected") == (announced != 1),
				label + ": attack " + str(announced) + " redirect flag matches its origin")
		# Non-attack actions are returned as detached, unchanged copies and never retargeted.
		for nonattack: Dictionary in [
			{"type": "block", "enemy_position": 1, "target_position": 2, "amount": 4},
			{"type": "buff", "enemy_position": 2, "amount": 3},
			{"type": "debuff", "enemy_position": 1, "target_position": 3, "status": "bleed"},
		]:
			var nonattack_copy: Dictionary = nonattack.duplicate(true)
			var projected: Dictionary = taunt.project_enemy_action(party, nonattack)
			_check(projected.get("ok", false) and not projected.get("targetable", true),
				label + ": non-attack " + str(nonattack["type"]) + " is never Taunt-targeted")
			_check(projected.get("action") == nonattack_copy and nonattack == nonattack_copy,
				label + ": non-attack " + str(nonattack["type"]) + " passes through unchanged")
		var attack_action: Dictionary = {"type": "attack", "enemy_position": 2,
			"target_position": 3, "amount": 5, "hits": 2}
		var attack_copy: Dictionary = attack_action.duplicate(true)
		var projected_attack: Dictionary = taunt.project_enemy_action(party, attack_action)
		_check(projected_attack.get("ok", false) and projected_attack.get("targetable", false)
			and projected_attack.get("redirected") == true
			and int(projected_attack.get("actual_target_position", 0)) == 1,
			label + ": attack action is redirected to the Warden")
		_check((projected_attack.get("action") as Dictionary).get("target_position") == 1
			and (projected_attack.get("action") as Dictionary).get("amount") == 5
			and (projected_attack.get("action") as Dictionary).get("hits") == 2
			and (projected_attack.get("action") as Dictionary).get("enemy_position") == 2,
			label + ": Taunt changes only the seat, never hit count, damage or owner")
		_check(attack_action == attack_copy, label + ": caller's attack dictionary is untouched")

		# A legal seat swap moves both reactions with the living Warden identity.
		var swap: Dictionary = CombatPositionSwaps.preview_adjacent_swap(party, 1, 1)
		_check(swap.get("ok", false), label + ": legal adjacent swap preview")
		party._heroes.assign(swap.get("heroes", []))
		_check(party.get_hero(2)["id"] == "warden" and party.get_hero(1)["id"] == "seamstress",
			label + ": Warden really moved to seat 2")
		var moved_attack: Dictionary = taunt.project_attack_target(party, 3)
		_check(moved_attack.get("eligible", false) and moved_attack.get("redirected", false)
			and int(moved_attack.get("actual_target_position", 0)) == 2,
			label + ": following attack follows the Warden's new seat 2")
		var moved_guard: Dictionary = guard.project_interception(party, 3)
		_check(moved_guard.get("eligible", false) and moved_guard.get("redirected", false)
			and int(moved_guard.get("actual_target_position", 0)) == 2,
			label + ": ally guard also follows the Warden's new seat 2")
		_check(taunt.has_pending_taunt() and guard.has_pending_guard(),
			label + ": both reactions stay armed through the swap")

		# The Taunt expires only after the WHOLE enemy turn; the Guard is independent.
		_check(taunt.complete_enemy_turn(), label + ": complete_enemy_turn retires the armed Taunt")
		_check(not taunt.has_pending_taunt() and taunt.get_pending_taunt_card_id() == "",
			label + ": Taunt is cleared after the enemy turn")
		var following: Dictionary = taunt.project_attack_target(party, 3)
		_check(not following.get("redirected", true)
			and int(following.get("actual_target_position", 0)) == 3,
			label + ": the following enemy turn is unaffected")
		_check(not taunt.complete_enemy_turn(),
			label + ": a second complete_enemy_turn consumes nothing")
		_check(guard.has_pending_guard(),
			label + ": the ally guard outlives the Taunt until its own confirmed hit")

	# AC1: exactly one held occurrence is spent even when the hand holds two genuine copies.
	var pair_deck: CombatDeck = _paid_deck(base_id, 749)
	pair_deck.hand.append(base_id)
	var pair_party: CombatParty = _party()
	var pair_guard: CombatWardenV3GuardCards = CombatWardenV3GuardCards.new(
		null, null, CombatWardenV3TauntCards.new())
	_check(pair_deck.hand == [base_id, base_id] and pair_deck.energy == 3
		and pair_deck.discard_pile.is_empty(),
		"V3 Final Bastion AC1: two genuine held copies, one full turn of energy")
	_check(pair_guard.play_card(pair_deck, pair_party, base_id, 1).get("ok", false)
		and pair_deck.hand == [base_id] and pair_deck.discard_pile == [base_id]
		and pair_deck.energy == 0 and int(pair_party.get_hero(1)["block"]) == 12,
		"V3 Final Bastion AC1: exactly one held occurrence is paid for and discarded")

	# AC2: Taunt-driven redirection is never counted as a second ally interception.
	var interaction_party: CombatParty = _party()
	var interaction_deck: CombatDeck = _paid_deck(base_id, 719)
	var interaction_taunt: CombatWardenV3TauntCards = CombatWardenV3TauntCards.new()
	var interaction_guard: CombatWardenV3GuardCards = CombatWardenV3GuardCards.new(
		null, null, interaction_taunt)
	_check(interaction_guard.play_card(interaction_deck, interaction_party, base_id, 1).get("ok", false),
		"V3 Final Bastion AC2: interaction fixture really plays")
	var taunted: Dictionary = interaction_taunt.project_attack_target(interaction_party, 3)
	_check(taunted.get("redirected", false)
		and int(taunted.get("actual_target_position", 0)) == 1,
		"V3 Final Bastion AC2: Taunt retargets the announced Tinker attack onto the Warden")
	var announced_ally: Dictionary = interaction_guard.project_interception(interaction_party, 3)
	_check(announced_ally.get("eligible", false)
		and int(announced_ally.get("actual_target_position", 0)) == 1,
		"V3 Final Bastion AC2: the same contact is one interception, not two")

	# A hit already aimed at the Warden is not another ally's contact: preview and miss keep it.
	var warden_target: Dictionary = interaction_guard.project_interception(interaction_party, 1)
	_check(warden_target.get("ok", false) and not warden_target.get("eligible", false)
		and not warden_target.get("redirected", false)
		and int(warden_target.get("actual_target_position", 0)) == 1,
		"V3 Final Bastion AC2: announced Warden target is not an ally interception")
	var warden_preview: Dictionary = interaction_guard.project_interception(interaction_party, 3)
	_check(warden_preview.get("eligible", false) and interaction_guard.has_pending_guard(),
		"V3 Final Bastion AC2: preview-only projection never consumes the guard")
	var miss: Dictionary = interaction_guard.consume_confirmed_hit(interaction_party, 3, false)
	_check(not miss.get("consumed", false) and interaction_guard.has_pending_guard(),
		"V3 Final Bastion AC2: a miss or non-attack never consumes the guard")
	var warden_consume: Dictionary = interaction_guard.consume_confirmed_hit(interaction_party, 1, true)
	_check(not warden_consume.get("consumed", false) and interaction_guard.has_pending_guard(),
		"V3 Final Bastion AC2: a hit already aimed at the Warden consumes nothing")
	var ally_consume: Dictionary = interaction_guard.consume_confirmed_hit(interaction_party, 3, true)
	_check(ally_consume.get("ok", false) and ally_consume.get("consumed", false)
		and int(ally_consume.get("actual_target_position", 0)) == 1
		and not interaction_guard.has_pending_guard(),
		"V3 Final Bastion AC2: the one genuine ally contact consumes exactly once")
	var repeat_consume: Dictionary = interaction_guard.consume_confirmed_hit(interaction_party, 3, true)
	_check(not repeat_consume.get("consumed", false)
		and int(repeat_consume.get("actual_target_position", 0)) == 3,
		"V3 Final Bastion AC2: the following contact is ordinary")
	_check(interaction_taunt.has_pending_taunt(),
		"V3 Final Bastion AC2: the Taunt authority is unaffected by the guard consumption")

	# AC3: every refusal keeps deck, party, guard, Taunt and RNG byte-identical.
	var missing_party: CombatParty = _party()
	var missing_deck: CombatDeck = _paid_deck(base_id, 721)
	var no_authority_guard: CombatWardenV3GuardCards = CombatWardenV3GuardCards.new()
	var missing_receipt: Dictionary = _refuse_guard(no_authority_guard, missing_deck,
		missing_party, base_id, 1, "V3 Final Bastion AC3: missing Taunt authority")
	_check(str(missing_receipt.get("reason", "")) == "taunt_authority_missing",
		"V3 Final Bastion AC3: missing Taunt authority is a read-only preflight refusal")

	var incompatible_taunt: CombatWardenV3TauntCards = CombatWardenV3TauntCards.new()
	var incompatible_guard: CombatWardenV3GuardCards = CombatWardenV3GuardCards.new(
		null, null, "not a taunt authority")
	var incompatible_receipt: Dictionary = _refuse_guard(incompatible_guard, _paid_deck(base_id, 723),
		_party(), base_id, 1, "V3 Final Bastion AC3: incompatible Taunt authority",
		incompatible_taunt)
	_check(str(incompatible_receipt.get("reason", "")) == "taunt_authority_incompatible",
		"V3 Final Bastion AC3: incompatible Taunt authority is refused read-only")

	# A real authority that passes the read-only preflight but rejects the arm proves the whole
	# payment is restored instead of leaving a partially paid card.
	var refusing_taunt := RefusingFinalBastionTauntAuthority.new()
	var refusing_guard: CombatWardenV3GuardCards = CombatWardenV3GuardCards.new(
		null, null, refusing_taunt)
	var refusing_receipt: Dictionary = _refuse_guard(refusing_guard, _paid_deck(base_id, 725),
		_party(), base_id, 1, "V3 Final Bastion AC3: rejected arm rolls the payment back",
		refusing_taunt)
	_check(str(refusing_receipt.get("reason", "")) == "taunt_arm_rejected",
		"V3 Final Bastion AC3: a rejected arm reports taunt_arm_rejected")

	# A missing or forged companion pool record refuses the genuine held card before payment.
	var missing_pool := MissingFinalBastionCompanionCatalog.new()
	var missing_pair_taunt: CombatWardenV3TauntCards = CombatWardenV3TauntCards.new()
	var missing_pair_guard: CombatWardenV3GuardCards = CombatWardenV3GuardCards.new(
		null, missing_pool, missing_pair_taunt)
	_check(not missing_pair_guard.is_authentic_card(base_id)
		and not missing_pair_guard.is_authentic_card(plus_id),
		"V3 Final Bastion AC3: a missing companion printing authenticates as nothing")
	var missing_pair_receipt: Dictionary = _refuse_guard(missing_pair_guard,
		_paid_deck(base_id, 727), _party(), base_id, 1,
		"V3 Final Bastion AC3: missing companion definition", missing_pair_taunt)
	_check(str(missing_pair_receipt.get("reason", "")) == "catalog_pair_mismatch",
		"V3 Final Bastion AC3: a missing companion is a catalog pair refusal")

	var forged_pool := ForgedPoolGuardCatalog.new()
	forged_pool.forged_id = plus_id
	var forged_companion: Dictionary = V3WardenPoolCards.new().get_definition(plus_id)
	forged_companion["effects"]["block"] = 99
	forged_pool.forged_record = forged_companion
	var forged_pair_taunt: CombatWardenV3TauntCards = CombatWardenV3TauntCards.new()
	var forged_pair_guard: CombatWardenV3GuardCards = CombatWardenV3GuardCards.new(
		null, forged_pool, forged_pair_taunt)
	_check(not forged_pair_guard.is_authentic_card(base_id),
		"V3 Final Bastion AC3: a forged companion invalidates the base printing")
	_check(not forged_pair_guard.is_authentic_card(plus_id),
		"V3 Final Bastion AC3: the forged printing itself is never authentic")
	_refuse_guard(forged_pair_guard, _paid_deck(base_id, 729), _party(), base_id, 1,
		"V3 Final Bastion AC3: forged companion definition", forged_pair_taunt)

	# A forged Final Bastion record of its own is refused through the same catalog seam.
	var forged_own_pool := ForgedPoolGuardCatalog.new()
	forged_own_pool.forged_id = base_id
	var forged_own_record: Dictionary = V3WardenPoolCards.new().get_definition(base_id)
	forged_own_record["effects"]["guard_next_hit"] = false
	forged_own_pool.forged_record = forged_own_record
	var forged_own_taunt: CombatWardenV3TauntCards = CombatWardenV3TauntCards.new()
	var forged_own_guard: CombatWardenV3GuardCards = CombatWardenV3GuardCards.new(
		null, forged_own_pool, forged_own_taunt)
	_check(not forged_own_guard.is_authentic_card(base_id),
		"V3 Final Bastion AC3: a forged own record authenticates as nothing")
	_refuse_guard(forged_own_guard, _paid_deck(base_id, 730), _party(), base_id, 1,
		"V3 Final Bastion AC3: forged own definition", forged_own_taunt)

	# Genuine controls: a genuine pair really authenticates and really pays.
	var genuine_guard: CombatWardenV3GuardCards = CombatWardenV3GuardCards.new(
		null, null, CombatWardenV3TauntCards.new())
	_check(genuine_guard.is_authentic_card(base_id)
		and genuine_guard.is_authentic_card(plus_id),
		"V3 Final Bastion AC3: the genuine reciprocal pair authenticates")

	# Retained negative preflights: unheld, unaffordable, inactive, torn, wrong seat, bad target,
	# Block overflow; each also proves the battle Taunt stays unarmed.
	var negatives_taunt: CombatWardenV3TauntCards = CombatWardenV3TauntCards.new()
	var negatives_guard: CombatWardenV3GuardCards = CombatWardenV3GuardCards.new(
		null, null, negatives_taunt)
	var not_held: CombatDeck = _paid_deck("warden_draw_fire", 731)
	_check(not not_held.hand.has(base_id), "V3 Final Bastion AC3: unheld precondition")
	_refuse_guard(negatives_guard, not_held, _party(), base_id, 1,
		"V3 Final Bastion AC3: unheld refuses", negatives_taunt)

	var poor: CombatDeck = _paid_deck(base_id, 733)
	_check(poor.try_spend_energy(3) and poor.energy == 0,
		"V3 Final Bastion AC3: unaffordable precondition")
	_refuse_guard(negatives_guard, poor, _party(), base_id, 1,
		"V3 Final Bastion AC3: no energy refuses", negatives_taunt)

	var inactive: CombatDeck = CombatDeck.new([base_id], _rng(735))
	inactive.hand.append(base_id)
	_check(not inactive.turn_active and inactive.hand.has(base_id),
		"V3 Final Bastion AC3: inactive but held precondition")
	_refuse_guard(negatives_guard, inactive, _party(), base_id, 1,
		"V3 Final Bastion AC3: inactive turn refuses", negatives_taunt)

	var downed_party: CombatParty = _party()
	_check(downed_party.apply_damage(1, 40) and downed_party.is_downed(1),
		"V3 Final Bastion AC3: downed Warden precondition")
	_refuse_guard(negatives_guard, _paid_deck(base_id, 737), downed_party, base_id, 1,
		"V3 Final Bastion AC3: downed Warden refuses", negatives_taunt)

	var no_warden_party: CombatParty = CombatParty.new([
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
		{"id": "another", "max_hp": 20},
	])
	_check(no_warden_party.is_valid() and not no_warden_party.is_defeated(),
		"V3 Final Bastion AC3: valid roster without a Warden")
	_refuse_guard(negatives_guard, _paid_deck(base_id, 739), no_warden_party, base_id, 1,
		"V3 Final Bastion AC3: absent Warden refuses", negatives_taunt)

	var wrong_seat_party: CombatParty = _party_with_warden_at(2)
	_refuse_guard(negatives_guard, _paid_deck(base_id, 741), wrong_seat_party, base_id, 2,
		"V3 Final Bastion AC3: wrong Warden seat refuses", negatives_taunt)

	_refuse_guard(negatives_guard, _paid_deck(base_id, 743), _party(), base_id, 2,
		"V3 Final Bastion AC3: non-Warden self target refuses", negatives_taunt)

	var capped_party: CombatParty = _party()
	capped_party._heroes[0]["block"] = CombatParty.MAX_INT - 11
	_refuse_guard(negatives_guard, _paid_deck(base_id, 745), capped_party, base_id, 1,
		"V3 Final Bastion AC3: base Block overflow refuses", negatives_taunt)
	var capped_plus_party: CombatParty = _party()
	capped_plus_party._heroes[0]["block"] = CombatParty.MAX_INT - 15
	_refuse_guard(negatives_guard, _paid_deck(plus_id, 747), capped_plus_party, plus_id, 1,
		"V3 Final Bastion AC3: plus Block overflow refuses", negatives_taunt)
	_check(not negatives_taunt.has_pending_taunt()
		and not negatives_guard.has_pending_guard(),
		"V3 Final Bastion AC3: no refusal armed either reaction")


## A battle Taunt authority that passes the read-only preflight but rejects the real arm, so the
## guard resolver's post-payment rollback is exercised honestly.
class RefusingFinalBastionTauntAuthority extends CombatWardenV3TauntCards:
	func can_arm_taunt_for_final_bastion(_card_id: Variant) -> bool:
		return true

	func arm_taunt_for_final_bastion(_card_id: String) -> bool:
		return false


## A pool catalog whose companion "+" record is genuinely missing while everything else is intact.
class MissingFinalBastionCompanionCatalog extends V3WardenPoolCards:
	func get_definition(card_id: Variant) -> Dictionary:
		if typeof(card_id) == TYPE_STRING and (card_id as String) == "warden_v3_final_bastion_plus":
			return {}
		return super.get_definition(card_id)

