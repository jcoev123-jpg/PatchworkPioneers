extends SceneTree
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
	await _mouse_click(app.start_button)
	if not is_instance_valid(app.route_view) or not app.route_view.is_visible_in_tree():
		app.start_button.pressed.emit()
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
	_check(enemy1_hp_before == 12 and enemy2_hp_before == 12, "AC2: enemy starting HPs are 12 and 12")

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
	_check(app.enemies.get_enemy(1).hp == e1_hp_before_next, "AC3: following turn has NO retaliation (Enemy 1 took no damage)")

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
