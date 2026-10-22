extends SceneTree
## Deterministic headless test for CombatWardenGuardReactions (D2-1).
## Validates Draw Fire, Counter-stitch, Guarding redirection, Thorns retaliation,
## movement following, turn lifecycle, and negative fail-closed behavior.

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_ac1_draw_fire_guarding()
	_test_ac2_counter_stitch_thorns()
	_test_ac3_reactions_sequential_and_movement()
	_test_ac4_lifecycle_and_rejections()
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
