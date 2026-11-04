extends SceneTree
## Deterministic headless test for CombatWardenPoolHeavyAttacks (D2-1).
## Validates Heavy Thimble, Pin and Pound, upgraded variants, Block absorption,
## sequential hits, per-hit status floors, lethal short-circuit, and negative snapshots.

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_ac1_heavy_thimble()
	_test_ac2_pin_and_pound()
	_test_ac3_negative_snapshots_and_replay()
	_test_ac4_catalog_starter_deck_and_invariants()
	_test_pinned_ac1_heavy_thimble_token_cash_in()
	_test_pinned_ac2_pin_and_pound_single_consumption()
	_test_pinned_ac3_same_owner_absent_and_unaffected_pins()
	_test_pinned_ac4_rejections_leave_tokens()
	_test_patch_ac1_pincushion_arm_damage_bonus()
	_test_patch_ac2_button_eye_exposed_and_latch()
	_test_patch_ac3_projection_rejections_and_replay()
	_test_needle_heavy_first_hit_receipts()
	_test_needle_heavy_fail_closed()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("combat_warden_pool_heavy_attacks_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("combat_warden_pool_heavy_attacks_test: FAIL (", failures.size(), " failures)")
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


func _party_with_statuses(warden_statuses: Dictionary = {}) -> CombatParty:
	var warden_def: Dictionary = {"id": "warden", "max_hp": 40}
	if not warden_statuses.is_empty():
		warden_def["statuses"] = warden_statuses.duplicate(true)
	var party: CombatParty = CombatParty.new([
		warden_def,
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
	])
	_check(party.is_valid() and party.get_heroes().size() == 3, "fixture party is valid")
	return party


func _enemies(hps: Array[int] = [30, 30, 30]) -> CombatEnemies:
	var defs: Array[Dictionary] = []
	for i: int in range(hps.size()):
		defs.append({"id": "enemy_" + str(i + 1), "max_hp": hps[i]})
	var enemies: CombatEnemies = CombatEnemies.new(defs)
	_check(enemies.is_valid() and enemies.get_enemies().size() == hps.size(), "fixture enemies is valid")
	return enemies


func _deck(held_cards: Array[String], seed_val: int = 42) -> CombatDeck:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val
	var all_cards: Array[String] = held_cards.duplicate()
	while all_cards.size() < 10:
		all_cards.append("warden_strike")
	var deck: CombatDeck = CombatDeck.new(all_cards, rng)
	_check(deck.start_turn(), "deck started player turn")
	# Ensure the requested held cards are physically in hand
	for card_id: String in held_cards:
		if not deck.hand.has(card_id):
			var idx: int = deck.draw_pile.find(card_id)
			if idx >= 0:
				deck.hand.append(deck.draw_pile[idx])
				deck.draw_pile.remove_at(idx)
			else:
				idx = deck.discard_pile.find(card_id)
				if idx >= 0:
					deck.hand.append(deck.discard_pile[idx])
					deck.discard_pile.remove_at(idx)
				else:
					deck.hand.append(card_id)
	return deck


func _snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies) -> Dictionary:
	return {
		"hand": deck.hand.duplicate(),
		"draw_pile": deck.draw_pile.duplicate(),
		"discard_pile": deck.discard_pile.duplicate(),
		"energy": deck.energy,
		"turn_active": deck.turn_active,
		"heroes": party.get_heroes(),
		"enemies": enemies.get_enemies(),
		"rng_state": deck._rng.state if (deck != null and deck._rng != null) else 0,
	}


func _pin_map(pinned: CombatPinned) -> Dictionary:
	return pinned._pinner_by_position.duplicate(true)


## AC1: Heavy Thimble & Heavy Thimble+ 11/15 damage, targets 1-2 only, Block absorption,
## precisely 2 energy debited and one held copy discarded, other actors unchanged.
func _test_ac1_heavy_thimble() -> void:
	var catalog: WardenPoolCards = WardenPoolCards.new()
	var service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new()

	var thimble_def: Dictionary = catalog.get_definition("warden_heavy_thimble")
	var thimble_plus_def: Dictionary = catalog.get_definition("warden_heavy_thimble_plus")

	_check(not thimble_def.is_empty(), "AC1: warden_heavy_thimble in catalog")
	_check(not thimble_plus_def.is_empty(), "AC1: warden_heavy_thimble_plus in catalog")
	_check(int(thimble_def.get("cost", 0)) == 2, "AC1: Heavy Thimble cost is 2")
	_check(int(thimble_plus_def.get("cost", 0)) == 2, "AC1: Heavy Thimble+ cost is 2")
	_check(thimble_def.get("from_positions") == [1], "AC1: Heavy Thimble FROM position 1")
	_check(thimble_plus_def.get("from_positions") == [1], "AC1: Heavy Thimble+ FROM position 1")
	_check(thimble_def.get("to_positions") == [1, 2], "AC1: Heavy Thimble TO positions 1 and 2")
	_check(thimble_plus_def.get("to_positions") == [1, 2], "AC1: Heavy Thimble+ TO positions 1 and 2")

	# 1. Base Heavy Thimble on Enemy 1 (25 HP, 0 Block): exact 11 damage
	var party: CombatParty = _party()
	var enemies: CombatEnemies = _enemies([25, 20, 20])
	var deck: CombatDeck = _deck(["warden_heavy_thimble"])
	var other_heroes: Array[Dictionary] = [party.get_hero(2), party.get_hero(3)]
	var other_enemies: Array[Dictionary] = [enemies.get_enemy(2), enemies.get_enemy(3)]
	var rng1_before: int = deck._rng.state

	_check(service.can_play(deck, party, enemies, "warden_heavy_thimble", 1), "AC1: can_play returns true for target 1")
	_check(deck._rng.state == rng1_before, "AC1: can_play preflight preserved deck._rng.state")
	var result: Dictionary = service.play_attack(deck, party, enemies, "warden_heavy_thimble", 1)

	_check(result.get("ok", false) == true, "AC1: Heavy Thimble play succeeded")
	_check(deck._rng.state == rng1_before, "AC1: Heavy Thimble execution preserved deck._rng.state")
	var hits: Array = result.get("hits", []) as Array
	_check(hits.size() == 1, "AC1: Heavy Thimble produced exactly 1 hit")
	var hit: Dictionary = hits[0] as Dictionary
	_check(int(hit.get("position", 0)) == 1, "AC1: Hit targeted position 1")
	_check(int(hit.get("damage", 0)) == 11, "AC1: Exact 11 damage dealt")
	_check(int(hit.get("block_absorbed", 0)) == 0, "AC1: Zero block absorbed on unblocked foe")
	_check(int(hit.get("hp_loss", 0)) == 11, "AC1: Exact 11 HP loss")
	_check(enemies.get_enemy(1)["hp"] == 14, "AC1: Enemy 1 HP is 25 - 11 = 14")
	_check(deck.energy == 1, "AC1: Exactly 2 energy spent (3 - 2 = 1)")
	_check(not deck.hand.has("warden_heavy_thimble"), "AC1: One copy discarded from hand")
	_check(deck.discard_pile.has("warden_heavy_thimble"), "AC1: Discard pile contains played card")
	_check([enemies.get_enemy(2), enemies.get_enemy(3)] == other_enemies, "AC1: Enemies 2 and 3 unchanged")
	_check([party.get_hero(2), party.get_hero(3)] == other_heroes, "AC1: Seamstress and Tinker unchanged")
	_check(party.get_hero(1)["hp"] == 40, "AC1: Warden HP unchanged")

	# 2. Base Heavy Thimble on Enemy 2 (target position 2): exact 11 damage
	var party2: CombatParty = _party()
	var enemies2: CombatEnemies = _enemies([25, 25, 25])
	var deck2: CombatDeck = _deck(["warden_heavy_thimble"])
	var rng2_before: int = deck2._rng.state
	var res2: Dictionary = service.play_attack(deck2, party2, enemies2, "warden_heavy_thimble", 2)
	_check(res2.get("ok", false) == true, "AC1: Target 2 play succeeded")
	_check(deck2._rng.state == rng2_before, "AC1: Target 2 execution preserved deck._rng.state")
	_check(enemies2.get_enemy(2)["hp"] == 14, "AC1: Enemy 2 took 11 damage")
	_check(enemies2.get_enemy(1)["hp"] == 25, "AC1: Enemy 1 untouched")

	# 3. Base Heavy Thimble against Block absorption: 6 Block, 25 HP
	var party3: CombatParty = _party()
	var enemies3: CombatEnemies = _enemies([25, 20])
	_check(enemies3.gain_block(1, 6), "AC1: Gave Enemy 1 6 Block")
	var deck3: CombatDeck = _deck(["warden_heavy_thimble"])
	var rng3_before: int = deck3._rng.state
	var res3: Dictionary = service.play_attack(deck3, party3, enemies3, "warden_heavy_thimble", 1)
	_check(res3.get("ok", false) == true, "AC1: Blocked play succeeded")
	_check(deck3._rng.state == rng3_before, "AC1: Blocked play preserved deck._rng.state")
	var hit3: Dictionary = (res3.get("hits", []) as Array)[0] as Dictionary
	_check(int(hit3.get("damage", 0)) == 11, "AC1: 11 damage against block")
	_check(int(hit3.get("block_absorbed", 0)) == 6, "AC1: 6 block absorbed")
	_check(int(hit3.get("hp_loss", 0)) == 5, "AC1: 5 HP lost (11 - 6 = 5)")
	_check(enemies3.get_enemy(1)["block"] == 0, "AC1: Enemy 1 block depleted to 0")
	_check(enemies3.get_enemy(1)["hp"] == 20, "AC1: Enemy 1 HP is 25 - 5 = 20")

	# 4. Heavy Thimble+ (15 damage): 8 Block, 30 HP
	var party_plus: CombatParty = _party()
	var enemies_plus: CombatEnemies = _enemies([30, 20])
	_check(enemies_plus.gain_block(1, 8), "AC1: Gave Enemy 1 8 Block for Thimble+")
	var deck_plus: CombatDeck = _deck(["warden_heavy_thimble_plus"])
	var rng_plus_before: int = deck_plus._rng.state
	var res_plus: Dictionary = service.play_attack(deck_plus, party_plus, enemies_plus, "warden_heavy_thimble_plus", 1)
	_check(res_plus.get("ok", false) == true, "AC1: Heavy Thimble+ play succeeded")
	_check(deck_plus._rng.state == rng_plus_before, "AC1: Heavy Thimble+ execution preserved deck._rng.state")
	var hit_plus: Dictionary = (res_plus.get("hits", []) as Array)[0] as Dictionary
	_check(int(hit_plus.get("damage", 0)) == 15, "AC1: Heavy Thimble+ dealt exact 15 damage")
	_check(int(hit_plus.get("block_absorbed", 0)) == 8, "AC1: 8 block absorbed")
	_check(int(hit_plus.get("hp_loss", 0)) == 7, "AC1: 7 HP loss (15 - 8 = 7)")
	_check(enemies_plus.get_enemy(1)["hp"] == 23, "AC1: Enemy 1 HP is 30 - 7 = 23")
	_check(enemies_plus.get_enemy(1)["block"] == 0, "AC1: Enemy 1 block is 0")
	_check(deck_plus.energy == 1, "AC1: Heavy Thimble+ spent 2 energy")
	_check(not deck_plus.hand.has("warden_heavy_thimble_plus"), "AC1: Heavy Thimble+ discarded")

	# 5. Target slot restriction: target position 3 is illegal for Heavy Thimble
	var party_pos3: CombatParty = _party()
	var enemies_pos3: CombatEnemies = _enemies([30, 30, 30])
	var deck_pos3: CombatDeck = _deck(["warden_heavy_thimble"])
	var snap_before: Dictionary = _snapshot(deck_pos3, party_pos3, enemies_pos3)
	var rng_pos3_before: int = deck_pos3._rng.state
	_check(not service.can_play(deck_pos3, party_pos3, enemies_pos3, "warden_heavy_thimble", 3),
		"AC1: can_play rejects target position 3 for Heavy Thimble")
	_check(deck_pos3._rng.state == rng_pos3_before, "AC1: can_play target 3 preserved deck._rng.state")
	var res_pos3: Dictionary = service.play_attack(deck_pos3, party_pos3, enemies_pos3, "warden_heavy_thimble", 3)
	_check(res_pos3.get("ok", true) == false, "AC1: Heavy Thimble target 3 rejected")
	_check(_snapshot(deck_pos3, party_pos3, enemies_pos3) == snap_before, "AC1: State untouched after target 3 rejection")
	_check(deck_pos3._rng.state == rng_pos3_before, "AC1: Target 3 rejection preserved deck._rng.state")


## AC2: Pin and Pound & Pin and Pound+ two sequential hits, Weak/Exposed per-hit floors,
## first-hit Block then HP on second, lethal hit-one short-circuit, no Pinned token.
func _test_ac2_pin_and_pound() -> void:
	var catalog: WardenPoolCards = WardenPoolCards.new()
	var service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new()

	var pnp_def: Dictionary = catalog.get_definition("warden_pin_and_pound")
	var pnp_plus_def: Dictionary = catalog.get_definition("warden_pin_and_pound_plus")

	_check(not pnp_def.is_empty(), "AC2: warden_pin_and_pound in catalog")
	_check(not pnp_plus_def.is_empty(), "AC2: warden_pin_and_pound_plus in catalog")
	_check(int(pnp_def.get("cost", 0)) == 2, "AC2: Pin and Pound cost 2")
	_check(int(pnp_plus_def.get("cost", 0)) == 2, "AC2: Pin and Pound+ cost 2")
	_check(pnp_def.get("from_positions") == [1], "AC2: Pin and Pound FROM position 1")
	_check(pnp_plus_def.get("from_positions") == [1], "AC2: Pin and Pound+ FROM position 1")
	_check(pnp_def.get("to_positions") == [1, 2, 3], "AC2: Pin and Pound TO positions 1, 2, 3")
	_check(pnp_plus_def.get("to_positions") == [1, 2, 3], "AC2: Pin and Pound+ TO positions 1, 2, 3")
	_check(not (pnp_def.get("effects", {}) as Dictionary).has("pinned"), "AC2: Pin and Pound catalog has no pinned key")
	_check(not (pnp_plus_def.get("effects", {}) as Dictionary).has("pinned"), "AC2: Pin and Pound+ catalog has no pinned key")

	# 1. Base Pin and Pound: two sequential 9-damage hits on target position 2
	var party: CombatParty = _party()
	var enemies: CombatEnemies = _enemies([30, 30, 30])
	var deck: CombatDeck = _deck(["warden_pin_and_pound"])
	var other_heroes: Array[Dictionary] = [party.get_hero(2), party.get_hero(3)]
	var other_enemies: Array[Dictionary] = [enemies.get_enemy(1), enemies.get_enemy(3)]
	var rng1_before: int = deck._rng.state

	var res: Dictionary = service.play_attack(deck, party, enemies, "warden_pin_and_pound", 2)
	_check(res.get("ok", false) == true, "AC2: Pin and Pound play succeeded")
	_check(deck._rng.state == rng1_before, "AC2: Pin and Pound execution preserved deck._rng.state")
	var hits: Array = res.get("hits", []) as Array
	_check(hits.size() == 2, "AC2: Exactly 2 separate hits performed")
	var h1: Dictionary = hits[0] as Dictionary
	var h2: Dictionary = hits[1] as Dictionary
	_check(int(h1.get("position", 0)) == 2 and int(h1.get("damage", 0)) == 9 and int(h1.get("hp_loss", 0)) == 9,
		"AC2: Hit 1 dealt 9 damage to position 2")
	_check(int(h2.get("position", 0)) == 2 and int(h2.get("damage", 0)) == 9 and int(h2.get("hp_loss", 0)) == 9,
		"AC2: Hit 2 dealt 9 damage to position 2")
	_check(not h1.get("statuses", {}).has("pinned"), "AC2: Hit 1 does not apply Pinned")
	_check(not h2.get("statuses", {}).has("pinned"), "AC2: Hit 2 does not apply Pinned")
	_check(enemies.get_enemy(2)["hp"] == 12, "AC2: Enemy 2 HP is 30 - 18 = 12")
	_check([enemies.get_enemy(1), enemies.get_enemy(3)] == other_enemies, "AC2: Other enemies untouched")
	_check([party.get_hero(2), party.get_hero(3)] == other_heroes, "AC2: Other heroes untouched")
	_check(deck.energy == 1, "AC2: Exactly 2 energy charged for whole card")
	_check(deck.discard_pile.has("warden_pin_and_pound") and not deck.hand.has("warden_pin_and_pound"),
		"AC2: Exactly one card discarded")

	# 2. First-hit Block followed by HP on second hit
	# Enemy 1 has 5 Block, 20 HP. Hit 1: 5 block absorbed, 4 HP loss. Hit 2: 0 block absorbed, 9 HP loss.
	var party2: CombatParty = _party()
	var enemies2: CombatEnemies = _enemies([20, 20])
	_check(enemies2.gain_block(1, 5), "AC2: Set Enemy 1 Block to 5")
	var deck2: CombatDeck = _deck(["warden_pin_and_pound"])
	var rng2_before: int = deck2._rng.state
	var res2: Dictionary = service.play_attack(deck2, party2, enemies2, "warden_pin_and_pound", 1)
	_check(res2.get("ok", false) == true, "AC2: Blocked Pin and Pound succeeded")
	_check(deck2._rng.state == rng2_before, "AC2: Blocked Pin and Pound preserved deck._rng.state")
	var hits2: Array = res2.get("hits", []) as Array
	_check(hits2.size() == 2, "AC2: 2 hits on blocked foe")
	var b_h1: Dictionary = hits2[0] as Dictionary
	var b_h2: Dictionary = hits2[1] as Dictionary
	_check(int(b_h1.get("block_absorbed", 0)) == 5 and int(b_h1.get("hp_loss", 0)) == 4,
		"AC2: Hit 1 absorbed 5 block and dealt 4 HP loss")
	_check(int(b_h2.get("block_absorbed", 0)) == 0 and int(b_h2.get("hp_loss", 0)) == 9,
		"AC2: Hit 2 absorbed 0 block and dealt full 9 HP loss")
	_check(enemies2.get_enemy(1)["hp"] == 7, "AC2: Enemy 1 HP is 20 - 4 - 9 = 7")
	_check(enemies2.get_enemy(1)["block"] == 0, "AC2: Enemy 1 Block is 0")

	# 3. Lethal hit-one short-circuit: enemy has 6 HP, 0 Block. Hit 1 slays enemy. Hit 2 is skipped.
	var party3: CombatParty = _party()
	var enemies3: CombatEnemies = _enemies([6, 20])
	var deck3: CombatDeck = _deck(["warden_pin_and_pound"])
	var other_foe: Dictionary = enemies3.get_enemy(2)
	var rng3_before: int = deck3._rng.state
	var res3: Dictionary = service.play_attack(deck3, party3, enemies3, "warden_pin_and_pound", 1)
	_check(res3.get("ok", false) == true, "AC2: Lethal play succeeded")
	_check(deck3._rng.state == rng3_before, "AC2: Lethal play preserved deck._rng.state")
	var hits3: Array = res3.get("hits", []) as Array
	_check(hits3.size() == 1, "AC2: Lethal hit 1 short-circuited hit 2 (no phantom hit)")
	var l_h1: Dictionary = hits3[0] as Dictionary
	_check(int(l_h1.get("position", 0)) == 1 and int(l_h1.get("damage", 0)) == 9 and int(l_h1.get("hp_loss", 0)) == 6,
		"AC2: Hit 1 killed enemy 1 with 6 HP loss")
	_check(enemies3.is_slain(1), "AC2: Enemy 1 is slain")
	_check(enemies3.get_enemy(1)["hp"] == 0, "AC2: Enemy 1 HP is 0")
	_check(enemies3.get_enemy(2) == other_foe, "AC2: Enemy 2 was NOT redirected to")
	_check(deck3.energy == 1, "AC2: 2 energy still debited (no rollback)")
	_check(deck3.discard_pile.has("warden_pin_and_pound"), "AC2: Card discarded (no rollback)")

	# 4. Status modifiers: Weak attacker (25% less per hit), Exposed defender (50% more per hit)
	# For Pin and Pound (9 base damage):
	# Weak: floor(9 * 3 / 4) = 6 per hit. Total 12. (NOT floor(18 * 3 / 4) = 13).
	# Seed Weak on the real Warden actor record:
	var party_weak: CombatParty = _party_with_statuses({"weak": 1})
	var enemies_weak: CombatEnemies = _enemies([30, 20])
	var deck_weak: CombatDeck = _deck(["warden_pin_and_pound"])
	var rng_weak_before: int = deck_weak._rng.state
	var res_weak: Dictionary = service.play_attack(deck_weak, party_weak, enemies_weak, "warden_pin_and_pound", 1)
	_check(res_weak.get("ok", false) == true, "AC2: Real Weak attack succeeded")
	_check(deck_weak._rng.state == rng_weak_before, "AC2: Real Weak attack preserved deck._rng.state")
	var weak_hits: Array = res_weak.get("hits", []) as Array
	_check(weak_hits.size() == 2, "AC2: Weak attack produced 2 hits")
	_check(int((weak_hits[0] as Dictionary).get("damage", 0)) == 6, "AC2: Hit 1 weak damage is floor(9 * 3/4) = 6")
	_check(int((weak_hits[1] as Dictionary).get("damage", 0)) == 6, "AC2: Hit 2 weak damage is floor(9 * 3/4) = 6")
	_check(enemies_weak.get_enemy(1)["hp"] == 18, "AC2: Total 12 damage dealt (per-hit floor proves independent hits)")

	# Contradictory caller snapshot proof: passing {weak: 0} does NOT override real Warden Weak
	var party_weak_c: CombatParty = _party_with_statuses({"weak": 1})
	var enemies_weak_c: CombatEnemies = _enemies([30, 20])
	var deck_weak_c: CombatDeck = _deck(["warden_pin_and_pound"])
	var rng_weak_c_before: int = deck_weak_c._rng.state
	var res_weak_c: Dictionary = service.play_attack(deck_weak_c, party_weak_c, enemies_weak_c, "warden_pin_and_pound", 1,
		{"weak": 0})
	_check(res_weak_c.get("ok", false) == true, "AC2: Contradictory {weak: 0} snapshot play succeeded")
	_check(deck_weak_c._rng.state == rng_weak_c_before, "AC2: Contradictory {weak: 0} snapshot preserved deck._rng.state")
	var weak_c_hits: Array = res_weak_c.get("hits", []) as Array
	_check(weak_c_hits.size() == 2, "AC2: Produced 2 hits despite {weak: 0} caller arg")
	_check(int((weak_c_hits[0] as Dictionary).get("damage", 0)) == 6,
		"AC2: Hit 1 still deals 6 damage; caller {weak: 0} does not override real Warden Weak")
	_check(int((weak_c_hits[1] as Dictionary).get("damage", 0)) == 6,
		"AC2: Hit 2 still deals 6 damage; caller {weak: 0} does not override real Warden Weak")
	_check(enemies_weak_c.get_enemy(1)["hp"] == 18, "AC2: Enemy 1 HP is 18 (not 12), proving authoritative status obeyed")

	# Exposed: floor(9 * 3 / 2) = 13 per hit. Total 26.
	# Seed Exposed on the real enemy actor record:
	var party_exp: CombatParty = _party()
	var enemies_exp: CombatEnemies = _enemies([40, 20])
	_check(enemies_exp.apply_statuses({1: {"exposed": 1}}), "AC2: Seeded Exposed on real enemy 1")
	var deck_exp: CombatDeck = _deck(["warden_pin_and_pound"])
	var rng_exp_before: int = deck_exp._rng.state
	var res_exp: Dictionary = service.play_attack(deck_exp, party_exp, enemies_exp, "warden_pin_and_pound", 1)
	_check(res_exp.get("ok", false) == true, "AC2: Real Exposed attack succeeded")
	_check(deck_exp._rng.state == rng_exp_before, "AC2: Real Exposed attack preserved deck._rng.state")
	var exp_hits: Array = res_exp.get("hits", []) as Array
	_check(exp_hits.size() == 2, "AC2: Exposed attack produced 2 hits")
	_check(int((exp_hits[0] as Dictionary).get("damage", 0)) == 13, "AC2: Hit 1 exposed damage is floor(9 * 3/2) = 13")
	_check(int((exp_hits[1] as Dictionary).get("damage", 0)) == 13, "AC2: Hit 2 exposed damage is floor(9 * 3/2) = 13")
	_check(enemies_exp.get_enemy(1)["hp"] == 14, "AC2: Total 26 damage dealt to exposed foe")

	# Contradictory caller snapshot proof: passing {1: {exposed: 0}} does NOT override real enemy Exposed
	var party_exp_c: CombatParty = _party()
	var enemies_exp_c: CombatEnemies = _enemies([40, 20])
	_check(enemies_exp_c.apply_statuses({1: {"exposed": 1}}), "AC2: Seeded Exposed on real enemy 1 for contra check")
	var deck_exp_c: CombatDeck = _deck(["warden_pin_and_pound"])
	var rng_exp_c_before: int = deck_exp_c._rng.state
	var res_exp_c: Dictionary = service.play_attack(deck_exp_c, party_exp_c, enemies_exp_c, "warden_pin_and_pound", 1,
		{}, {1: {"exposed": 0}})
	_check(res_exp_c.get("ok", false) == true, "AC2: Contradictory {1: {exposed: 0}} snapshot play succeeded")
	_check(deck_exp_c._rng.state == rng_exp_c_before, "AC2: Contradictory {1: {exposed: 0}} snapshot preserved deck._rng.state")
	var exp_c_hits: Array = res_exp_c.get("hits", []) as Array
	_check(exp_c_hits.size() == 2, "AC2: Produced 2 hits despite {1: {exposed: 0}} caller arg")
	_check(int((exp_c_hits[0] as Dictionary).get("damage", 0)) == 13,
		"AC2: Hit 1 still deals 13 damage; caller {exposed: 0} does not override real enemy Exposed")
	_check(int((exp_c_hits[1] as Dictionary).get("damage", 0)) == 13,
		"AC2: Hit 2 still deals 13 damage; caller {exposed: 0} does not override real enemy Exposed")
	_check(enemies_exp_c.get_enemy(1)["hp"] == 14, "AC2: Enemy 1 HP is 14 (not 22), proving authoritative enemy status obeyed")

	# Weak + Exposed: floor(9 * 9 / 8) = 10 per hit. Total 20.
	# Seed Weak on real Warden and Exposed on real enemy:
	var party_we: CombatParty = _party_with_statuses({"weak": 1})
	var enemies_we: CombatEnemies = _enemies([30, 20])
	_check(enemies_we.apply_statuses({1: {"exposed": 1}}), "AC2: Seeded Exposed on real enemy 1 for we check")
	var deck_we: CombatDeck = _deck(["warden_pin_and_pound"])
	var rng_we_before: int = deck_we._rng.state
	var res_we: Dictionary = service.play_attack(deck_we, party_we, enemies_we, "warden_pin_and_pound", 1)
	_check(res_we.get("ok", false) == true, "AC2: Real Weak+Exposed attack succeeded")
	_check(deck_we._rng.state == rng_we_before, "AC2: Real Weak+Exposed attack preserved deck._rng.state")
	var we_hits: Array = res_we.get("hits", []) as Array
	_check(we_hits.size() == 2, "AC2: Weak+Exposed attack produced 2 hits")
	_check(int((we_hits[0] as Dictionary).get("damage", 0)) == 10, "AC2: Hit 1 weak+exposed damage is floor(9 * 9/8) = 10")
	_check(int((we_hits[1] as Dictionary).get("damage", 0)) == 10, "AC2: Hit 2 weak+exposed damage is floor(9 * 9/8) = 10")
	_check(enemies_we.get_enemy(1)["hp"] == 10, "AC2: Enemy 1 HP is 30 - 20 = 10")

	# Contradictory caller snapshots proof: passing {weak: 0} and {1: {exposed: 0}} does NOT override either status
	var party_we_c: CombatParty = _party_with_statuses({"weak": 1})
	var enemies_we_c: CombatEnemies = _enemies([30, 20])
	_check(enemies_we_c.apply_statuses({1: {"exposed": 1}}), "AC2: Seeded Exposed on real enemy 1 for we contra check")
	var deck_we_c: CombatDeck = _deck(["warden_pin_and_pound"])
	var rng_we_c_before: int = deck_we_c._rng.state
	var res_we_c: Dictionary = service.play_attack(deck_we_c, party_we_c, enemies_we_c, "warden_pin_and_pound", 1,
		{"weak": 0}, {1: {"exposed": 0}})
	_check(res_we_c.get("ok", false) == true, "AC2: Contradictory weak+exposed snapshots succeeded")
	_check(deck_we_c._rng.state == rng_we_c_before, "AC2: Contradictory weak+exposed snapshots preserved deck._rng.state")
	var we_c_hits: Array = res_we_c.get("hits", []) as Array
	_check(we_c_hits.size() == 2, "AC2: Produced 2 hits despite both contradictory caller args")
	_check(int((we_c_hits[0] as Dictionary).get("damage", 0)) == 10,
		"AC2: Hit 1 still deals 10 damage; contradictory args do not override real statuses")
	_check(int((we_c_hits[1] as Dictionary).get("damage", 0)) == 10,
		"AC2: Hit 2 still deals 10 damage; contradictory args do not override real statuses")
	_check(enemies_we_c.get_enemy(1)["hp"] == 10, "AC2: Enemy 1 HP is 10 (not 12 or 22)")

	# Matching caller snapshots (valid pass-through):
	var party_we_m: CombatParty = _party_with_statuses({"weak": 1})
	var enemies_we_m: CombatEnemies = _enemies([30, 20])
	_check(enemies_we_m.apply_statuses({1: {"exposed": 1}}), "AC2: Seeded Exposed on real enemy 1 for matching check")
	var deck_we_m: CombatDeck = _deck(["warden_pin_and_pound"])
	var res_we_m: Dictionary = service.play_attack(deck_we_m, party_we_m, enemies_we_m, "warden_pin_and_pound", 1,
		{"weak": 1}, {1: {"exposed": 1}})
	_check(res_we_m.get("ok", false) == true, "AC2: Matching snapshots succeeded")
	_check(enemies_we_m.get_enemy(1)["hp"] == 10, "AC2: Matching snapshots result in 10 damage per hit")

	# Malformed caller snapshot rejection:
	var party_mal: CombatParty = _party()
	var enemies_mal: CombatEnemies = _enemies([30, 20])
	var deck_mal: CombatDeck = _deck(["warden_pin_and_pound"])
	var snap_mal_before: Dictionary = _snapshot(deck_mal, party_mal, enemies_mal)
	var rng_mal_before: int = deck_mal._rng.state
	var res_mal: Dictionary = service.play_attack(deck_mal, party_mal, enemies_mal, "warden_pin_and_pound", 1,
		{"poison": 1})
	_check(res_mal.get("ok", true) == false, "AC2: Malformed attacker status name rejected")
	_check(_snapshot(deck_mal, party_mal, enemies_mal) == snap_mal_before, "AC2: Malformed attacker status leaves state untouched")
	_check(deck_mal._rng.state == rng_mal_before, "AC2: Malformed attacker status preserved deck._rng.state")

	var res_mal_foe: Dictionary = service.play_attack(deck_mal, party_mal, enemies_mal, "warden_pin_and_pound", 1,
		{}, {1: {"exposed": -1}})
	_check(res_mal_foe.get("ok", true) == false, "AC2: Negative enemy status count rejected")
	_check(_snapshot(deck_mal, party_mal, enemies_mal) == snap_mal_before, "AC2: Negative enemy status leaves state untouched")
	_check(deck_mal._rng.state == rng_mal_before, "AC2: Negative enemy status preserved deck._rng.state")

	# 5. Pin and Pound+ (12 damage twice): normal, weak, and target position 3
	var party_pp: CombatParty = _party()
	var enemies_pp: CombatEnemies = _enemies([30, 30, 30])
	var deck_pp: CombatDeck = _deck(["warden_pin_and_pound_plus"])
	var rng_pp_before: int = deck_pp._rng.state
	var res_pp: Dictionary = service.play_attack(deck_pp, party_pp, enemies_pp, "warden_pin_and_pound_plus", 3)
	_check(res_pp.get("ok", false) == true, "AC2: Pin and Pound+ succeeded on target position 3")
	_check(deck_pp._rng.state == rng_pp_before, "AC2: Pin and Pound+ preserved deck._rng.state")
	var pp_hits: Array = res_pp.get("hits", []) as Array
	_check(pp_hits.size() == 2, "AC2: Pin and Pound+ produced 2 hits")
	_check(int((pp_hits[0] as Dictionary).get("damage", 0)) == 12, "AC2: Hit 1 dealt 12 damage")
	_check(int((pp_hits[1] as Dictionary).get("damage", 0)) == 12, "AC2: Hit 2 dealt 12 damage")
	_check(enemies_pp.get_enemy(3)["hp"] == 6, "AC2: Enemy 3 HP is 30 - 24 = 6")
	_check(deck_pp.energy == 1, "AC2: 2 energy spent for Pin and Pound+")
	_check(deck_pp.discard_pile.has("warden_pin_and_pound_plus"), "AC2: Pin and Pound+ discarded")


## AC3: Table of absent hand, depleted energy, inactive turn, downed/moved Warden,
## bad target slot, slain target; snapshot invariants; deterministic seeded repeat.
func _test_ac3_negative_snapshots_and_replay() -> void:
	var service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new()

	for card_id: String in CombatWardenPoolHeavyAttacks.SUPPORTED_CARD_IDS:
		# Scenario A: Card absent from hand
		var party_a: CombatParty = _party()
		var enemies_a: CombatEnemies = _enemies([20, 20])
		var deck_a: CombatDeck = _deck(["warden_strike"]) # does not hold card_id
		var rng_a_before: int = deck_a._rng.state
		var snap_a: Dictionary = _snapshot(deck_a, party_a, enemies_a)
		_check(snap_a["rng_state"] == rng_a_before, "AC3: Snapshot captures deck._rng.state")
		_check(not service.can_play(deck_a, party_a, enemies_a, card_id, 1), "AC3: " + card_id + " can_play absent false")
		_check(deck_a._rng.state == rng_a_before, "AC3: can_play preflight preserved deck._rng.state for absent " + card_id)
		var res_a: Dictionary = service.play_attack(deck_a, party_a, enemies_a, card_id, 1)
		_check(res_a.get("ok", true) == false, "AC3: " + card_id + " rejected when absent")
		_check(_snapshot(deck_a, party_a, enemies_a) == snap_a, "AC3: State untouched for absent card " + card_id)
		_check(deck_a._rng.state == rng_a_before, "AC3: deck._rng.state preserved for absent card " + card_id)

		# Scenario B: Depleted energy (energy 0 or 1, card needs 2)
		var party_b: CombatParty = _party()
		var enemies_b: CombatEnemies = _enemies([20, 20])
		var deck_b: CombatDeck = _deck([card_id])
		_check(deck_b.try_spend_energy(2), "AC3: Spent 2 energy leaving 1")
		var rng_b_before: int = deck_b._rng.state
		var snap_b: Dictionary = _snapshot(deck_b, party_b, enemies_b)
		_check(not service.can_play(deck_b, party_b, enemies_b, card_id, 1), "AC3: " + card_id + " can_play low energy false")
		_check(deck_b._rng.state == rng_b_before, "AC3: can_play preflight preserved deck._rng.state for low energy " + card_id)
		var res_b: Dictionary = service.play_attack(deck_b, party_b, enemies_b, card_id, 1)
		_check(res_b.get("ok", true) == false, "AC3: " + card_id + " rejected with 1 energy")
		_check(_snapshot(deck_b, party_b, enemies_b) == snap_b, "AC3: State untouched for low energy " + card_id)
		_check(deck_b._rng.state == rng_b_before, "AC3: deck._rng.state preserved for low energy " + card_id)

		# Scenario C: Inactive turn
		var party_c: CombatParty = _party()
		var enemies_c: CombatEnemies = _enemies([20, 20])
		var deck_c: CombatDeck = _deck([card_id])
		_check(deck_c.end_turn(), "AC3: End player turn")
		var rng_c_before: int = deck_c._rng.state
		var snap_c: Dictionary = _snapshot(deck_c, party_c, enemies_c)
		_check(not service.can_play(deck_c, party_c, enemies_c, card_id, 1), "AC3: " + card_id + " can_play inactive false")
		_check(deck_c._rng.state == rng_c_before, "AC3: can_play preflight preserved deck._rng.state for inactive " + card_id)
		var res_c: Dictionary = service.play_attack(deck_c, party_c, enemies_c, card_id, 1)
		_check(res_c.get("ok", true) == false, "AC3: " + card_id + " rejected on inactive turn")
		_check(_snapshot(deck_c, party_c, enemies_c) == snap_c, "AC3: State untouched for inactive turn " + card_id)
		_check(deck_c._rng.state == rng_c_before, "AC3: deck._rng.state preserved for inactive " + card_id)

		# Scenario D: Downed Warden
		var party_d: CombatParty = _party()
		_check(party_d.apply_damage(1, 999), "AC3: Down Warden")
		var enemies_d: CombatEnemies = _enemies([20, 20])
		var deck_d: CombatDeck = _deck([card_id])
		var rng_d_before: int = deck_d._rng.state
		var snap_d: Dictionary = _snapshot(deck_d, party_d, enemies_d)
		_check(not service.can_play(deck_d, party_d, enemies_d, card_id, 1), "AC3: " + card_id + " can_play downed Warden false")
		_check(deck_d._rng.state == rng_d_before, "AC3: can_play preflight preserved deck._rng.state for downed Warden " + card_id)
		var res_d: Dictionary = service.play_attack(deck_d, party_d, enemies_d, card_id, 1)
		_check(res_d.get("ok", true) == false, "AC3: " + card_id + " rejected when Warden downed")
		_check(_snapshot(deck_d, party_d, enemies_d) == snap_d, "AC3: State untouched for downed Warden " + card_id)
		_check(deck_d._rng.state == rng_d_before, "AC3: deck._rng.state preserved for downed Warden " + card_id)

		# Scenario E: Warden moved out of position 1 (Warden in position 2)
		var party_e: CombatParty = CombatParty.new([
			{"id": "seamstress", "max_hp": 30},
			{"id": "warden", "max_hp": 40},
			{"id": "tinker", "max_hp": 26},
		])
		var enemies_e: CombatEnemies = _enemies([20, 20])
		var deck_e: CombatDeck = _deck([card_id])
		var rng_e_before: int = deck_e._rng.state
		var snap_e: Dictionary = _snapshot(deck_e, party_e, enemies_e)
		_check(not service.can_play(deck_e, party_e, enemies_e, card_id, 1), "AC3: " + card_id + " can_play Warden at 2 false")
		_check(deck_e._rng.state == rng_e_before, "AC3: can_play preflight preserved deck._rng.state for moved Warden " + card_id)
		var res_e: Dictionary = service.play_attack(deck_e, party_e, enemies_e, card_id, 1)
		_check(res_e.get("ok", true) == false, "AC3: " + card_id + " rejected when Warden at position 2")
		_check(_snapshot(deck_e, party_e, enemies_e) == snap_e, "AC3: State untouched for moved Warden " + card_id)
		_check(deck_e._rng.state == rng_e_before, "AC3: deck._rng.state preserved for moved Warden " + card_id)

		# Scenario F: Slain target
		var party_f: CombatParty = _party()
		var enemies_f: CombatEnemies = _enemies([20, 20])
		_check(enemies_f.apply_damage(1, 999), "AC3: Slain target enemy 1")
		var deck_f: CombatDeck = _deck([card_id])
		var rng_f_before: int = deck_f._rng.state
		var snap_f: Dictionary = _snapshot(deck_f, party_f, enemies_f)
		_check(not service.can_play(deck_f, party_f, enemies_f, card_id, 1), "AC3: " + card_id + " can_play slain target false")
		_check(deck_f._rng.state == rng_f_before, "AC3: can_play preflight preserved deck._rng.state for slain target " + card_id)
		var res_f: Dictionary = service.play_attack(deck_f, party_f, enemies_f, card_id, 1)
		_check(res_f.get("ok", true) == false, "AC3: " + card_id + " rejected on slain target")
		_check(_snapshot(deck_f, party_f, enemies_f) == snap_f, "AC3: State untouched for slain target " + card_id)
		_check(deck_f._rng.state == rng_f_before, "AC3: deck._rng.state preserved for slain target " + card_id)

		# Scenario G: Bad target slot (target position 0, 4, -1)
		for bad_target: int in [0, 4, -1]:
			var party_g: CombatParty = _party()
			var enemies_g: CombatEnemies = _enemies([20, 20])
			var deck_g: CombatDeck = _deck([card_id])
			var rng_g_before: int = deck_g._rng.state
			var snap_g: Dictionary = _snapshot(deck_g, party_g, enemies_g)
			_check(not service.can_play(deck_g, party_g, enemies_g, card_id, bad_target),
				"AC3: " + card_id + " can_play bad target " + str(bad_target) + " false")
			_check(deck_g._rng.state == rng_g_before, "AC3: can_play preflight preserved deck._rng.state for bad target " + str(bad_target))
			var res_g: Dictionary = service.play_attack(deck_g, party_g, enemies_g, card_id, bad_target)
			_check(res_g.get("ok", true) == false, "AC3: " + card_id + " rejected on bad target " + str(bad_target))
			_check(_snapshot(deck_g, party_g, enemies_g) == snap_g, "AC3: State untouched for bad target " + str(bad_target))
			_check(deck_g._rng.state == rng_g_before, "AC3: deck._rng.state preserved for bad target " + str(bad_target))

	# Deterministic replay comparison: run accepted sequence under seed 500 twice
	var run_sequence: Callable = func(seed_val: int) -> Dictionary:
		var r_party: CombatParty = _party()
		var r_enemies: CombatEnemies = _enemies([30, 30, 30])
		var r_deck: CombatDeck = _deck(["warden_heavy_thimble", "warden_pin_and_pound"], seed_val)
		var r_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new()
		var rng_initial: int = r_deck._rng.state
		var e1: Dictionary = r_service.play_attack(r_deck, r_party, r_enemies, "warden_heavy_thimble", 1)
		# Add 2 energy so second attack can be played
		r_deck.combat_state.energy += 2
		var e2: Dictionary = r_service.play_attack(r_deck, r_party, r_enemies, "warden_pin_and_pound", 2)
		var rng_final: int = r_deck._rng.state
		_check(rng_final == rng_initial, "AC3: accepted replay sequence preserves deck._rng.state")
		return {
			"events": [e1, e2],
			"party": r_party.get_heroes(),
			"enemies": r_enemies.get_enemies(),
			"deck_hand": r_deck.hand.duplicate(),
			"deck_discard": r_deck.discard_pile.duplicate(),
			"deck_energy": r_deck.energy,
			"rng_state": rng_final,
		}

	var run1: Dictionary = run_sequence.call(500)
	var run2: Dictionary = run_sequence.call(500)
	_check(run1 == run2, "AC3: Valid play sequence is 100% deterministic under identical seed")
	_check(run1["rng_state"] == run2["rng_state"], "AC3: Replay deck._rng.state matches across runs")


## AC4: Starter deck, StarterCards attacks, Warden pool catalog, Guarding/Thorns,
## and shared 3-energy turn rules remain unmodified.
func _test_ac4_catalog_starter_deck_and_invariants() -> void:
	var catalog: WardenPoolCards = WardenPoolCards.new()
	var starter: StarterCards = StarterCards.new()

	# Original 12-card starter deck
	var starting_deck: Array[String] = starter.get_starting_deck()
	_check(starting_deck.size() == 12, "AC4: Starter deck has exactly 12 cards")
	_check(starting_deck.has("warden_strike"), "AC4: Starter deck has warden_strike")
	_check(starting_deck.has("warden_shield_bash"), "AC4: Starter deck has warden_shield_bash")
	_check(starting_deck.has("warden_brace"), "AC4: Starter deck has warden_brace")

	# Warden pool heavy attack definitions in catalog
	_check(catalog.has_card("warden_heavy_thimble"), "AC4: Catalog has warden_heavy_thimble")
	_check(catalog.has_card("warden_heavy_thimble_plus"), "AC4: Catalog has warden_heavy_thimble_plus")
	_check(catalog.has_card("warden_pin_and_pound"), "AC4: Catalog has warden_pin_and_pound")
	_check(catalog.has_card("warden_pin_and_pound_plus"), "AC4: Catalog has warden_pin_and_pound_plus")

	# Neither Pin and Pound version has pinned token
	var pnp: Dictionary = catalog.get_definition("warden_pin_and_pound")
	var pnp_plus: Dictionary = catalog.get_definition("warden_pin_and_pound_plus")
	_check(not (pnp.get("effects", {}) as Dictionary).has("pinned"), "AC4: No pinned in pin_and_pound")
	_check(not (pnp_plus.get("effects", {}) as Dictionary).has("pinned"), "AC4: No pinned in pin_and_pound_plus")

	# Warden Guard reactions service exists and behaves correctly
	var reactions: CombatWardenGuardReactions = CombatWardenGuardReactions.new()
	_check(reactions.is_guarding() == false and reactions.get_thorns() == 0, "AC4: Guard reactions service intact")

	# Shared turn starts with 3 energy
	var deck: CombatDeck = _deck([])
	_check(deck.energy == 3, "AC4: Turn starts with exactly 3 energy")
	_check(deck.turn_active == true, "AC4: Turn is active")


## Pinned AC1: a bound cross-hero CombatPinned token adds +5 to the confirmed
## Heavy Thimble / Heavy Thimble+ hit before Weak/Exposed. It consumes only that
## original-slot token while still debiting 2 energy and discarding one held copy.
func _test_pinned_ac1_heavy_thimble_token_cash_in() -> void:
	# 1. Base Heavy Thimble: authored 11 + 5 from a Seamstress token on slot 1.
	var party: CombatParty = _party()
	var enemies: CombatEnemies = _enemies([25, 20, 25])
	var pinned: CombatPinned = CombatPinned.new()
	_check(pinned.pin_enemy(enemies, 1, "seamstress"), "P-AC1: real pin by Seamstress on slot 1")
	_check(pinned.pin_enemy(enemies, 3, "tinker"), "P-AC1: real pin by Tinker on slot 3")
	var service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new()
	service.set_pinned(pinned)
	_check(service.get_pinned() == pinned, "P-AC1: service exposes its bound Pinned instance")
	var deck: CombatDeck = _deck(["warden_heavy_thimble"])
	var rng_before: int = deck._rng.state
	var snap_before: Dictionary = _snapshot(deck, party, enemies)
	var pin_before: Dictionary = _pin_map(pinned)
	_check(service.can_play(deck, party, enemies, "warden_heavy_thimble", 1),
		"P-AC1: legal pinned Heavy Thimble is admitted")
	_check(_pin_map(pinned) == pin_before, "P-AC1: can_play preflight left tokens untouched")
	_check(deck._rng.state == rng_before, "P-AC1: can_play preflight preserved deck._rng.state")
	var res: Dictionary = service.play_attack(deck, party, enemies, "warden_heavy_thimble", 1)
	_check(res.get("ok", false), "P-AC1: pinned Heavy Thimble succeeded")
	_check(deck._rng.state == rng_before, "P-AC1: pinned Heavy Thimble preserved deck._rng.state")
	var hits: Array = res.get("hits", []) as Array
	_check(hits.size() == 1, "P-AC1: Heavy Thimble produced exactly 1 hit")
	var hit: Dictionary = hits[0] as Dictionary
	_check(int(hit.get("damage", 0)) == 16, "P-AC1: 11 authored + 5 Pinned = 16 damage")
	_check(int(hit.get("pinned_bonus", 0)) == 5, "P-AC1: hit records the +5 Pinned bonus")
	_check(int(hit.get("block_absorbed", 0)) == 0 and int(hit.get("hp_loss", 0)) == 16,
		"P-AC1: 0 block absorbed and 16 HP lost")
	_check(enemies.get_enemy(1)["hp"] == 9, "P-AC1: enemy 1 HP is 25 - 16 = 9")
	_check(deck.energy == 1, "P-AC1: exactly 2 energy debited")
	var snap_after: Dictionary = _snapshot(deck, party, enemies)
	_check(int(snap_after["hand"].count("warden_heavy_thimble")) + 1
		== int(snap_before["hand"].count("warden_heavy_thimble")),
		"P-AC1: exactly one held copy left the hand")
	_check(int(snap_after["discard_pile"].count("warden_heavy_thimble")) ==
		int(snap_before["discard_pile"].count("warden_heavy_thimble")) + 1,
		"P-AC1: exactly one copy entered the discard pile")
	_check(snap_after["draw_pile"] == snap_before["draw_pile"], "P-AC1: draw pile unchanged")
	_check(pinned.pinner_for_enemy(1) == "", "P-AC1: consumed the slot-1 token")
	_check(pinned.pinner_for_enemy(2) == "", "P-AC1: unpinned slot stays unpinned")
	_check(pinned.pinner_for_enemy(3) == "tinker", "P-AC1: token on slot 3 untouched")
	_check(enemies.get_enemy(2)["hp"] == 20 and enemies.get_enemy(3)["hp"] == 25,
		"P-AC1: other enemies untouched")
	_check(party.get_hero(1)["hp"] == 40, "P-AC1: Warden HP unchanged")

	# 2. Heavy Thimble+ (15) + Tinker token on slot 2, passed per call (unbound service).
	var plus_party: CombatParty = _party()
	var plus_enemies: CombatEnemies = _enemies([25, 30, 25])
	var plus_pinned: CombatPinned = CombatPinned.new()
	_check(plus_pinned.pin_enemy(plus_enemies, 1, "seamstress"), "P-AC1: pin slot 1 for the + variant")
	_check(plus_pinned.pin_enemy(plus_enemies, 2, "tinker"), "P-AC1: pin slot 2 by Tinker for the + variant")
	var plus_deck: CombatDeck = _deck(["warden_heavy_thimble_plus"])
	var plus_rng_before: int = plus_deck._rng.state
	var plus_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new()
	_check(plus_service.get_pinned() == null, "P-AC1: per-call binding works without set_pinned")
	var plus_res: Dictionary = plus_service.play_attack(plus_deck, plus_party, plus_enemies,
		"warden_heavy_thimble_plus", 2, {}, {}, plus_pinned)
	_check(plus_res.get("ok", false), "P-AC1: pinned Heavy Thimble+ succeeded on slot 2")
	_check(plus_deck._rng.state == plus_rng_before, "P-AC1: pinned Heavy Thimble+ preserved deck._rng.state")
	var plus_hits: Array = plus_res.get("hits", []) as Array
	_check(plus_hits.size() == 1, "P-AC1: Heavy Thimble+ produced exactly 1 hit")
	var plus_hit: Dictionary = plus_hits[0] as Dictionary
	_check(int(plus_hit.get("damage", 0)) == 20, "P-AC1: 15 authored + 5 Pinned = 20 damage")
	_check(int(plus_hit.get("hp_loss", 0)) == 20, "P-AC1: 20 HP loss")
	_check(plus_enemies.get_enemy(2)["hp"] == 10, "P-AC1: enemy 2 HP is 30 - 20 = 10")
	_check(plus_deck.energy == 1, "P-AC1: exactly 2 energy debited for the + variant")
	_check(plus_pinned.pinner_for_enemy(2) == "", "P-AC1: consumed the slot-2 token")
	_check(plus_pinned.pinner_for_enemy(1) == "seamstress", "P-AC1: slot-1 token untouched")

	# 3. Weak ordering: floor((11 + 5) * 3 / 4) = 12, not floor(11 * 3/4) + 5 = 13.
	var weak_party: CombatParty = _party_with_statuses({"weak": 1})
	var weak_enemies: CombatEnemies = _enemies([25, 20])
	var weak_pinned: CombatPinned = CombatPinned.new()
	_check(weak_pinned.pin_enemy(weak_enemies, 1, "tinker"), "P-AC1: pin slot 1 for the Weak case")
	var weak_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new(weak_pinned)
	_check(weak_service.get_pinned() == weak_pinned, "P-AC1: constructor binds the Pinned service")
	var weak_deck: CombatDeck = _deck(["warden_heavy_thimble"])
	var weak_rng_before: int = weak_deck._rng.state
	var weak_res: Dictionary = weak_service.play_attack(weak_deck, weak_party, weak_enemies,
		"warden_heavy_thimble", 1)
	_check(weak_res.get("ok", false), "P-AC1: weak pinned Heavy Thimble succeeded")
	_check(weak_deck._rng.state == weak_rng_before, "P-AC1: weak pinned play preserved deck._rng.state")
	var weak_hit: Dictionary = (weak_res.get("hits", []) as Array)[0] as Dictionary
	_check(int(weak_hit.get("damage", 0)) == 12, "P-AC1: +5 is added before Weak (floor(16*3/4)=12)")
	_check(weak_enemies.get_enemy(1)["hp"] == 13, "P-AC1: enemy 1 HP is 25 - 12 = 13")
	_check(weak_pinned.pinner_for_enemy(1) == "", "P-AC1: weak confirmed hit consumed the token")

	# 4. Exposed ordering: floor((11 + 5) * 3 / 2) = 24.
	var exp_party: CombatParty = _party()
	var exp_enemies: CombatEnemies = _enemies([40, 20])
	_check(exp_enemies.apply_statuses({1: {"exposed": 1}}), "P-AC1: seeded Exposed on real enemy 1")
	var exp_pinned: CombatPinned = CombatPinned.new()
	_check(exp_pinned.pin_enemy(exp_enemies, 1, "seamstress"), "P-AC1: pin slot 1 for the Exposed case")
	var exp_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new(exp_pinned)
	var exp_deck: CombatDeck = _deck(["warden_heavy_thimble"])
	var exp_res: Dictionary = exp_service.play_attack(exp_deck, exp_party, exp_enemies,
		"warden_heavy_thimble", 1)
	_check(exp_res.get("ok", false), "P-AC1: exposed pinned Heavy Thimble succeeded")
	var exp_hit: Dictionary = (exp_res.get("hits", []) as Array)[0] as Dictionary
	_check(int(exp_hit.get("damage", 0)) == 24, "P-AC1: +5 is added before Exposed (floor(16*3/2)=24)")
	_check(exp_enemies.get_enemy(1)["hp"] == 16, "P-AC1: enemy 1 HP is 40 - 24 = 16")

	# 5. Block absorption still happens on the boosted damage: 16 vs 6 Block.
	var block_party: CombatParty = _party()
	var block_enemies: CombatEnemies = _enemies([25, 20])
	_check(block_enemies.gain_block(1, 6), "P-AC1: gave enemy 1 6 Block")
	var block_pinned: CombatPinned = CombatPinned.new()
	_check(block_pinned.pin_enemy(block_enemies, 1, "seamstress"), "P-AC1: pin slot 1 for the Block case")
	var block_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new(block_pinned)
	var block_deck: CombatDeck = _deck(["warden_heavy_thimble"])
	var block_res: Dictionary = block_service.play_attack(block_deck, block_party, block_enemies,
		"warden_heavy_thimble", 1)
	_check(block_res.get("ok", false), "P-AC1: blocked pinned Heavy Thimble succeeded")
	var block_hit: Dictionary = (block_res.get("hits", []) as Array)[0] as Dictionary
	_check(int(block_hit.get("damage", 0)) == 16 and int(block_hit.get("block_absorbed", 0)) == 6,
		"P-AC1: 16 boosted damage absorbed 6 Block")
	_check(int(block_hit.get("hp_loss", 0)) == 10, "P-AC1: 10 HP loss after Block")
	_check(block_enemies.get_enemy(1)["hp"] == 15 and block_enemies.get_enemy(1)["block"] == 0,
		"P-AC1: enemy 1 is 15 HP with 0 Block")
	_check(block_pinned.pinner_for_enemy(1) == "", "P-AC1: blocked confirmed hit still consumed the token")

	# 6. Lethal pinned hit still consumes the token (no token left on a corpse).
	var kill_party: CombatParty = _party()
	var kill_enemies: CombatEnemies = _enemies([5, 20])
	var kill_pinned: CombatPinned = CombatPinned.new()
	_check(kill_pinned.pin_enemy(kill_enemies, 1, "tinker"), "P-AC1: pin the 5 HP enemy")
	var kill_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new(kill_pinned)
	var kill_deck: CombatDeck = _deck(["warden_heavy_thimble"])
	var kill_res: Dictionary = kill_service.play_attack(kill_deck, kill_party, kill_enemies,
		"warden_heavy_thimble", 1)
	_check(kill_res.get("ok", false), "P-AC1: lethal pinned Heavy Thimble succeeded")
	var kill_hit: Dictionary = (kill_res.get("hits", []) as Array)[0] as Dictionary
	_check(int(kill_hit.get("damage", 0)) == 16 and int(kill_hit.get("hp_loss", 0)) == 5,
		"P-AC1: lethal hit deals the boosted 16 and caps HP loss at 5")
	_check(kill_enemies.is_slain(1), "P-AC1: enemy 1 is slain")
	_check(kill_pinned.pinner_for_enemy(1) == "", "P-AC1: lethal confirmed hit consumed the token")


## Pinned AC2: Pin and Pound / + consume the token on the first confirmed hit only;
## the second hit is unboosted, and a lethal first hit still consumes it.
func _test_pinned_ac2_pin_and_pound_single_consumption() -> void:
	# 1. Base Pin and Pound: hit 1 = 9 + 5 = 14, hit 2 = 9.
	var party: CombatParty = _party()
	var enemies: CombatEnemies = _enemies([20, 40, 30])
	var pinned: CombatPinned = CombatPinned.new()
	_check(pinned.pin_enemy(enemies, 2, "seamstress"), "P-AC2: pin slot 2 by Seamstress")
	_check(pinned.pin_enemy(enemies, 3, "tinker"), "P-AC2: pin slot 3 by Tinker")
	var service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new(pinned)
	var deck: CombatDeck = _deck(["warden_pin_and_pound"])
	var rng_before: int = deck._rng.state
	var snap_before: Dictionary = _snapshot(deck, party, enemies)
	var res: Dictionary = service.play_attack(deck, party, enemies, "warden_pin_and_pound", 2)
	_check(res.get("ok", false), "P-AC2: pinned Pin and Pound succeeded")
	_check(deck._rng.state == rng_before, "P-AC2: pinned Pin and Pound preserved deck._rng.state")
	var hits: Array = res.get("hits", []) as Array
	_check(hits.size() == 2, "P-AC2: exactly 2 sequential hits")
	var h1: Dictionary = hits[0] as Dictionary
	var h2: Dictionary = hits[1] as Dictionary
	_check(int(h1.get("position", 0)) == 2 and int(h1.get("damage", 0)) == 14
		and int(h1.get("hp_loss", 0)) == 14 and int(h1.get("pinned_bonus", 0)) == 5,
		"P-AC2: hit 1 is 9 + 5 = 14 on slot 2")
	_check(int(h2.get("position", 0)) == 2 and int(h2.get("damage", 0)) == 9
		and int(h2.get("hp_loss", 0)) == 9 and int(h2.get("pinned_bonus", 0)) == 0,
		"P-AC2: hit 2 is an unboosted 9 on slot 2")
	_check(enemies.get_enemy(2)["hp"] == 17, "P-AC2: enemy 2 HP is 40 - 23 = 17")
	_check(deck.energy == 1, "P-AC2: exactly 2 energy debited once for the card")
	var snap_after: Dictionary = _snapshot(deck, party, enemies)
	_check(int(snap_after["hand"].count("warden_pin_and_pound")) + 1
		== int(snap_before["hand"].count("warden_pin_and_pound")),
		"P-AC2: exactly one held copy left the hand")
	_check(int(snap_after["discard_pile"].count("warden_pin_and_pound")) ==
		int(snap_before["discard_pile"].count("warden_pin_and_pound")) + 1,
		"P-AC2: exactly one copy discarded")
	_check(pinned.pinner_for_enemy(2) == "", "P-AC2: consumed the slot-2 token")
	_check(pinned.pinner_for_enemy(3) == "tinker", "P-AC2: token on slot 3 untouched")
	_check(enemies.get_enemy(1)["hp"] == 20 and enemies.get_enemy(3)["hp"] == 30,
		"P-AC2: other enemies untouched")

	# 2. Pin and Pound+ on slot 3: hit 1 = 12 + 5 = 17, hit 2 = 12.
	var plus_party: CombatParty = _party()
	var plus_enemies: CombatEnemies = _enemies([20, 20, 40])
	var plus_pinned: CombatPinned = CombatPinned.new()
	_check(plus_pinned.pin_enemy(plus_enemies, 3, "tinker"), "P-AC2: pin slot 3 by Tinker for the + variant")
	var plus_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new(plus_pinned)
	var plus_deck: CombatDeck = _deck(["warden_pin_and_pound_plus"])
	var plus_rng_before: int = plus_deck._rng.state
	var plus_res: Dictionary = plus_service.play_attack(plus_deck, plus_party, plus_enemies,
		"warden_pin_and_pound_plus", 3)
	_check(plus_res.get("ok", false), "P-AC2: pinned Pin and Pound+ succeeded on slot 3")
	_check(plus_deck._rng.state == plus_rng_before, "P-AC2: pinned Pin and Pound+ preserved deck._rng.state")
	var plus_hits: Array = plus_res.get("hits", []) as Array
	_check(plus_hits.size() == 2, "P-AC2: Pin and Pound+ produced 2 hits")
	_check(int((plus_hits[0] as Dictionary).get("damage", 0)) == 17,
		"P-AC2: Pin and Pound+ hit 1 is 12 + 5 = 17")
	_check(int((plus_hits[1] as Dictionary).get("damage", 0)) == 12,
		"P-AC2: Pin and Pound+ hit 2 is an unboosted 12")
	_check(plus_enemies.get_enemy(3)["hp"] == 11, "P-AC2: enemy 3 HP is 40 - 29 = 11")
	_check(plus_deck.energy == 1, "P-AC2: exactly 2 energy debited for Pin and Pound+")
	_check(plus_pinned.pinner_for_enemy(3) == "", "P-AC2: consumed the slot-3 token")

	# 3. Lethal hit one skips hit two and still consumes the token.
	var kill_party: CombatParty = _party()
	var kill_enemies: CombatEnemies = _enemies([10, 20])
	var kill_pinned: CombatPinned = CombatPinned.new()
	_check(kill_pinned.pin_enemy(kill_enemies, 1, "seamstress"), "P-AC2: pin the 10 HP enemy")
	_check(kill_pinned.pin_enemy(kill_enemies, 2, "tinker"), "P-AC2: pin the surviving slot 2")
	var kill_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new(kill_pinned)
	var kill_deck: CombatDeck = _deck(["warden_pin_and_pound"])
	var kill_rng_before: int = kill_deck._rng.state
	var other_foe: Dictionary = kill_enemies.get_enemy(2)
	var kill_res: Dictionary = kill_service.play_attack(kill_deck, kill_party, kill_enemies,
		"warden_pin_and_pound", 1)
	_check(kill_res.get("ok", false), "P-AC2: lethal pinned Pin and Pound succeeded")
	_check(kill_deck._rng.state == kill_rng_before, "P-AC2: lethal pinned play preserved deck._rng.state")
	var kill_hits: Array = kill_res.get("hits", []) as Array
	_check(kill_hits.size() == 1, "P-AC2: hit 2 is skipped after a lethal hit 1")
	var kill_hit: Dictionary = kill_hits[0] as Dictionary
	_check(int(kill_hit.get("damage", 0)) == 14 and int(kill_hit.get("hp_loss", 0)) == 10,
		"P-AC2: lethal hit 1 deals 14 with 10 HP loss")
	_check(kill_enemies.is_slain(1) and kill_enemies.get_enemy(1)["hp"] == 0,
		"P-AC2: enemy 1 is slain")
	_check(kill_enemies.get_enemy(2) == other_foe, "P-AC2: hit 2 was not redirected to enemy 2")
	_check(kill_pinned.pinner_for_enemy(1) == "", "P-AC2: lethal hit 1 still consumed the token")
	_check(kill_pinned.pinner_for_enemy(2) == "tinker", "P-AC2: surviving slot 2 token untouched")
	_check(kill_deck.energy == 1, "P-AC2: 2 energy still debited on the lethal play")
	_check(kill_deck.discard_pile.has("warden_pin_and_pound"), "P-AC2: card discarded on the lethal play")

	# 4. Weak + Exposed with Pinned: floor((9 + 5) * 9/8) = 15 then floor(9 * 9/8) = 10.
	var we_party: CombatParty = _party_with_statuses({"weak": 1})
	var we_enemies: CombatEnemies = _enemies([40, 20])
	_check(we_enemies.apply_statuses({1: {"exposed": 1}}), "P-AC2: seeded Exposed on real enemy 1")
	var we_pinned: CombatPinned = CombatPinned.new()
	_check(we_pinned.pin_enemy(we_enemies, 1, "tinker"), "P-AC2: pin slot 1 for the Weak/Exposed case")
	var we_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new(we_pinned)
	var we_deck: CombatDeck = _deck(["warden_pin_and_pound"])
	var we_res: Dictionary = we_service.play_attack(we_deck, we_party, we_enemies,
		"warden_pin_and_pound", 1)
	_check(we_res.get("ok", false), "P-AC2: weak/exposed pinned Pin and Pound succeeded")
	var we_hits: Array = we_res.get("hits", []) as Array
	_check(we_hits.size() == 2, "P-AC2: weak/exposed attack produced 2 hits")
	_check(int((we_hits[0] as Dictionary).get("damage", 0)) == 15,
		"P-AC2: hit 1 is floor((9+5)*9/8) = 15, so +5 precedes Weak/Exposed")
	_check(int((we_hits[1] as Dictionary).get("damage", 0)) == 10,
		"P-AC2: hit 2 is floor(9*9/8) = 10 with no second +5")
	_check(we_enemies.get_enemy(1)["hp"] == 15, "P-AC2: enemy 1 HP is 40 - 25 = 15")

	# 5. Block receipts stay ordered: hit 1 spends Block, hit 2 hits HP.
	var block_party: CombatParty = _party()
	var block_enemies: CombatEnemies = _enemies([25, 20])
	_check(block_enemies.gain_block(1, 6), "P-AC2: gave enemy 1 6 Block")
	var block_pinned: CombatPinned = CombatPinned.new()
	_check(block_pinned.pin_enemy(block_enemies, 1, "seamstress"), "P-AC2: pin slot 1 for the Block case")
	var block_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new(block_pinned)
	var block_deck: CombatDeck = _deck(["warden_pin_and_pound"])
	var block_res: Dictionary = block_service.play_attack(block_deck, block_party, block_enemies,
		"warden_pin_and_pound", 1)
	_check(block_res.get("ok", false), "P-AC2: blocked pinned Pin and Pound succeeded")
	var block_hits: Array = block_res.get("hits", []) as Array
	_check(block_hits.size() == 2, "P-AC2: blocked pinned attack produced 2 hits")
	var b_h1: Dictionary = block_hits[0] as Dictionary
	var b_h2: Dictionary = block_hits[1] as Dictionary
	_check(int(b_h1.get("damage", 0)) == 14 and int(b_h1.get("block_absorbed", 0)) == 6
		and int(b_h1.get("hp_loss", 0)) == 8,
		"P-AC2: hit 1 deals 14, absorbing 6 Block for 8 HP loss")
	_check(int(b_h2.get("damage", 0)) == 9 and int(b_h2.get("block_absorbed", 0)) == 0
		and int(b_h2.get("hp_loss", 0)) == 9,
		"P-AC2: hit 2 deals 9 with no Block left")
	_check(block_enemies.get_enemy(1)["hp"] == 8 and block_enemies.get_enemy(1)["block"] == 0,
		"P-AC2: enemy 1 ends at 8 HP with 0 Block")


## Pinned AC3: unbound services, absent tokens and same-owner tokens keep the
## original unboosted outcomes and leave every token in place; tokens on other
## slots survive even when a different target dies.
func _test_pinned_ac3_same_owner_absent_and_unaffected_pins() -> void:
	# 1. No binding at all: tokens exist but are never consulted.
	var unbound: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new()
	_check(unbound.get_pinned() == null, "P-AC3: unbound service holds no Pinned instance")
	var u_party: CombatParty = _party()
	var u_enemies: CombatEnemies = _enemies([30, 30])
	var u_pinned: CombatPinned = CombatPinned.new()
	_check(u_pinned.pin_enemy(u_enemies, 1, "seamstress"), "P-AC3: real token exists while unbound")
	var u_deck: CombatDeck = _deck(["warden_heavy_thimble"])
	var u_res: Dictionary = unbound.play_attack(u_deck, u_party, u_enemies, "warden_heavy_thimble", 1)
	_check(u_res.get("ok", false), "P-AC3: unbound Heavy Thimble succeeded")
	var u_hit: Dictionary = (u_res.get("hits", []) as Array)[0] as Dictionary
	_check(int(u_hit.get("damage", 0)) == 11 and int(u_hit.get("pinned_bonus", 0)) == 0,
		"P-AC3: unbound Heavy Thimble deals the authored 11")
	_check(u_enemies.get_enemy(1)["hp"] == 19, "P-AC3: enemy 1 HP is 30 - 11 = 19")
	_check(u_pinned.pinner_for_enemy(1) == "seamstress", "P-AC3: unbound play left the token untouched")

	var u2_party: CombatParty = _party()
	var u2_enemies: CombatEnemies = _enemies([30, 30])
	var u2_pinned: CombatPinned = CombatPinned.new()
	_check(u2_pinned.pin_enemy(u2_enemies, 1, "tinker"), "P-AC3: real token exists for unbound Pin and Pound")
	var u2_deck: CombatDeck = _deck(["warden_pin_and_pound"])
	var u2_res: Dictionary = unbound.play_attack(u2_deck, u2_party, u2_enemies, "warden_pin_and_pound", 1)
	_check(u2_res.get("ok", false), "P-AC3: unbound Pin and Pound succeeded")
	var u2_hits: Array = u2_res.get("hits", []) as Array
	_check(u2_hits.size() == 2 and int((u2_hits[0] as Dictionary).get("damage", 0)) == 9
		and int((u2_hits[1] as Dictionary).get("damage", 0)) == 9,
		"P-AC3: unbound Pin and Pound keeps 9/9")
	_check(u2_pinned.pinner_for_enemy(1) == "tinker", "P-AC3: unbound Pin and Pound left the token untouched")

	# 2. Bound service with a Warden-authored token on the chosen foe: no bonus, token stays.
	var own_party: CombatParty = _party()
	var own_enemies: CombatEnemies = _enemies([30, 30])
	var own_pinned: CombatPinned = CombatPinned.new()
	_check(own_pinned.pin_enemy(own_enemies, 1, "warden"), "P-AC3: Warden pinned slot 1 itself")
	var own_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new(own_pinned)
	var own_deck: CombatDeck = _deck(["warden_heavy_thimble"])
	var own_res: Dictionary = own_service.play_attack(own_deck, own_party, own_enemies,
		"warden_heavy_thimble", 1)
	_check(own_res.get("ok", false), "P-AC3: same-owner Heavy Thimble succeeded")
	var own_hit: Dictionary = (own_res.get("hits", []) as Array)[0] as Dictionary
	_check(int(own_hit.get("damage", 0)) == 11 and int(own_hit.get("pinned_bonus", 0)) == 0,
		"P-AC3: same-owner Heavy Thimble stays at 11")
	_check(own_pinned.pinner_for_enemy(1) == "warden", "P-AC3: same-owner token remains after the hit")

	var own2_party: CombatParty = _party()
	var own2_enemies: CombatEnemies = _enemies([30, 30])
	var own2_pinned: CombatPinned = CombatPinned.new()
	_check(own2_pinned.pin_enemy(own2_enemies, 1, "warden"), "P-AC3: Warden pinned slot 1 for Pin and Pound")
	var own2_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new(own2_pinned)
	var own2_deck: CombatDeck = _deck(["warden_pin_and_pound_plus"])
	var own2_res: Dictionary = own2_service.play_attack(own2_deck, own2_party, own2_enemies,
		"warden_pin_and_pound_plus", 1)
	_check(own2_res.get("ok", false), "P-AC3: same-owner Pin and Pound+ succeeded")
	var own2_hits: Array = own2_res.get("hits", []) as Array
	_check(own2_hits.size() == 2 and int((own2_hits[0] as Dictionary).get("damage", 0)) == 12
		and int((own2_hits[1] as Dictionary).get("damage", 0)) == 12,
		"P-AC3: same-owner Pin and Pound+ keeps 12/12")
	_check(own2_pinned.pinner_for_enemy(1) == "warden", "P-AC3: same-owner token survives both hits")

	# 3. Bound service with no token at all: original outcomes, nothing consumed.
	var none_party: CombatParty = _party()
	var none_enemies: CombatEnemies = _enemies([30, 30])
	var none_pinned: CombatPinned = CombatPinned.new()
	var none_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new(none_pinned)
	var none_deck: CombatDeck = _deck(["warden_heavy_thimble_plus"])
	var none_res: Dictionary = none_service.play_attack(none_deck, none_party, none_enemies,
		"warden_heavy_thimble_plus", 1)
	_check(none_res.get("ok", false), "P-AC3: unpinned Heavy Thimble+ succeeded")
	var none_hit: Dictionary = (none_res.get("hits", []) as Array)[0] as Dictionary
	_check(int(none_hit.get("damage", 0)) == 15 and int(none_hit.get("pinned_bonus", 0)) == 0,
		"P-AC3: unpinned Heavy Thimble+ stays at 15")
	_check(_pin_map(none_pinned).is_empty(), "P-AC3: no token was invented by the play")

	var none2_party: CombatParty = _party()
	var none2_enemies: CombatEnemies = _enemies([30, 30])
	var none2_pinned: CombatPinned = CombatPinned.new()
	var none2_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new(none2_pinned)
	var none2_deck: CombatDeck = _deck(["warden_pin_and_pound"])
	var none2_res: Dictionary = none2_service.play_attack(none2_deck, none2_party, none2_enemies,
		"warden_pin_and_pound", 2)
	_check(none2_res.get("ok", false), "P-AC3: unpinned Pin and Pound succeeded")
	var none2_hits: Array = none2_res.get("hits", []) as Array
	_check(none2_hits.size() == 2 and int((none2_hits[0] as Dictionary).get("damage", 0)) == 9
		and int((none2_hits[1] as Dictionary).get("damage", 0)) == 9,
		"P-AC3: unpinned Pin and Pound keeps 9/9")
	_check(_pin_map(none2_pinned).is_empty(), "P-AC3: unpinned Pin and Pound invented no token")

	# 4. A token on a different original slot survives a lethal hit on another slot.
	var other_party: CombatParty = _party()
	var other_enemies: CombatEnemies = _enemies([5, 25])
	var other_pinned: CombatPinned = CombatPinned.new()
	_check(other_pinned.pin_enemy(other_enemies, 2, "seamstress"), "P-AC3: pin the untouched slot 2")
	var other_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new(other_pinned)
	var other_deck: CombatDeck = _deck(["warden_pin_and_pound"])
	var other_res: Dictionary = other_service.play_attack(other_deck, other_party, other_enemies,
		"warden_pin_and_pound", 1)
	_check(other_res.get("ok", false), "P-AC3: lethal unpinned Pin and Pound succeeded")
	_check(other_enemies.is_slain(1), "P-AC3: the unpinned target died")
	_check(other_pinned.pinner_for_enemy(2) == "seamstress",
		"P-AC3: the token on slot 2 survives a death on slot 1")
	_check(other_pinned.pinner_for_enemy(1) == "", "P-AC3: no token appeared on the dead slot")


## Pinned AC4: every pre-existing rejection still fails closed and now also leaves
## the bound token untouched (no card, energy, actor, status or RNG movement).
func _test_pinned_ac4_rejections_leave_tokens() -> void:
	# 1. Card absent from hand.
	var a_party: CombatParty = _party()
	var a_enemies: CombatEnemies = _enemies([20, 20])
	var a_pinned: CombatPinned = CombatPinned.new()
	_check(a_pinned.pin_enemy(a_enemies, 1, "seamstress"), "P-AC4: pin slot 1 for the absent-card case")
	var a_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new(a_pinned)
	var a_deck: CombatDeck = _deck(["warden_strike"])
	var a_rng: int = a_deck._rng.state
	var a_snap: Dictionary = _snapshot(a_deck, a_party, a_enemies)
	var a_pins: Dictionary = _pin_map(a_pinned)
	_check(not a_service.can_play(a_deck, a_party, a_enemies, "warden_heavy_thimble", 1),
		"P-AC4: can_play rejects an absent card")
	var a_res: Dictionary = a_service.play_attack(a_deck, a_party, a_enemies, "warden_heavy_thimble", 1)
	_check(not a_res.get("ok", true), "P-AC4: play_attack rejects an absent card")
	_check(_snapshot(a_deck, a_party, a_enemies) == a_snap, "P-AC4: absent-card rejection left state untouched")
	_check(_pin_map(a_pinned) == a_pins, "P-AC4: absent-card rejection left the token untouched")
	_check(a_deck._rng.state == a_rng, "P-AC4: absent-card rejection preserved deck._rng.state")

	# 2. Unaffordable 2-energy cost.
	var b_party: CombatParty = _party()
	var b_enemies: CombatEnemies = _enemies([20, 20])
	var b_pinned: CombatPinned = CombatPinned.new()
	_check(b_pinned.pin_enemy(b_enemies, 1, "tinker"), "P-AC4: pin slot 1 for the low-energy case")
	var b_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new(b_pinned)
	var b_deck: CombatDeck = _deck(["warden_heavy_thimble_plus"])
	_check(b_deck.try_spend_energy(2), "P-AC4: spent 2 energy leaving 1")
	var b_rng: int = b_deck._rng.state
	var b_snap: Dictionary = _snapshot(b_deck, b_party, b_enemies)
	var b_pins: Dictionary = _pin_map(b_pinned)
	_check(not b_service.can_play(b_deck, b_party, b_enemies, "warden_heavy_thimble_plus", 1),
		"P-AC4: can_play rejects unaffordable 2 energy")
	var b_res: Dictionary = b_service.play_attack(b_deck, b_party, b_enemies, "warden_heavy_thimble_plus", 1)
	_check(not b_res.get("ok", true), "P-AC4: play_attack rejects unaffordable 2 energy")
	_check(_snapshot(b_deck, b_party, b_enemies) == b_snap, "P-AC4: low-energy rejection left state untouched")
	_check(_pin_map(b_pinned) == b_pins, "P-AC4: low-energy rejection left the token untouched")
	_check(b_deck._rng.state == b_rng, "P-AC4: low-energy rejection preserved deck._rng.state")

	# 3. Inactive turn.
	var c_party: CombatParty = _party()
	var c_enemies: CombatEnemies = _enemies([20, 20])
	var c_pinned: CombatPinned = CombatPinned.new()
	_check(c_pinned.pin_enemy(c_enemies, 1, "seamstress"), "P-AC4: pin slot 1 for the inactive-turn case")
	var c_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new(c_pinned)
	var c_deck: CombatDeck = _deck(["warden_pin_and_pound"])
	_check(c_deck.end_turn(), "P-AC4: ended the player turn")
	var c_rng: int = c_deck._rng.state
	var c_snap: Dictionary = _snapshot(c_deck, c_party, c_enemies)
	var c_pins: Dictionary = _pin_map(c_pinned)
	_check(not c_service.can_play(c_deck, c_party, c_enemies, "warden_pin_and_pound", 1),
		"P-AC4: can_play rejects an inactive turn")
	var c_res: Dictionary = c_service.play_attack(c_deck, c_party, c_enemies, "warden_pin_and_pound", 1)
	_check(not c_res.get("ok", true), "P-AC4: play_attack rejects an inactive turn")
	_check(_snapshot(c_deck, c_party, c_enemies) == c_snap, "P-AC4: inactive-turn rejection left state untouched")
	_check(_pin_map(c_pinned) == c_pins, "P-AC4: inactive-turn rejection left the token untouched")
	_check(c_deck._rng.state == c_rng, "P-AC4: inactive-turn rejection preserved deck._rng.state")

	# 4. Downed Warden.
	var d_party: CombatParty = _party()
	_check(d_party.apply_damage(1, 999), "P-AC4: downed the Warden")
	var d_enemies: CombatEnemies = _enemies([20, 20])
	var d_pinned: CombatPinned = CombatPinned.new()
	_check(d_pinned.pin_enemy(d_enemies, 2, "tinker"), "P-AC4: pin slot 2 for the downed-Warden case")
	var d_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new(d_pinned)
	var d_deck: CombatDeck = _deck(["warden_pin_and_pound"])
	var d_rng: int = d_deck._rng.state
	var d_snap: Dictionary = _snapshot(d_deck, d_party, d_enemies)
	var d_pins: Dictionary = _pin_map(d_pinned)
	_check(not d_service.can_play(d_deck, d_party, d_enemies, "warden_pin_and_pound", 2),
		"P-AC4: can_play rejects a downed Warden")
	var d_res: Dictionary = d_service.play_attack(d_deck, d_party, d_enemies, "warden_pin_and_pound", 2)
	_check(not d_res.get("ok", true), "P-AC4: play_attack rejects a downed Warden")
	_check(_snapshot(d_deck, d_party, d_enemies) == d_snap, "P-AC4: downed-Warden rejection left state untouched")
	_check(_pin_map(d_pinned) == d_pins, "P-AC4: downed-Warden rejection left the token untouched")
	_check(d_deck._rng.state == d_rng, "P-AC4: downed-Warden rejection preserved deck._rng.state")

	# 5. Warden moved out of position 1.
	var e_party: CombatParty = CombatParty.new([
		{"id": "seamstress", "max_hp": 30},
		{"id": "warden", "max_hp": 40},
		{"id": "tinker", "max_hp": 26},
	])
	var e_enemies: CombatEnemies = _enemies([20, 20])
	var e_pinned: CombatPinned = CombatPinned.new()
	_check(e_pinned.pin_enemy(e_enemies, 1, "tinker"), "P-AC4: pin slot 1 for the moved-Warden case")
	var e_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new(e_pinned)
	var e_deck: CombatDeck = _deck(["warden_heavy_thimble"])
	var e_rng: int = e_deck._rng.state
	var e_snap: Dictionary = _snapshot(e_deck, e_party, e_enemies)
	var e_pins: Dictionary = _pin_map(e_pinned)
	_check(not e_service.can_play(e_deck, e_party, e_enemies, "warden_heavy_thimble", 1),
		"P-AC4: can_play rejects a Warden moved out of position 1")
	var e_res: Dictionary = e_service.play_attack(e_deck, e_party, e_enemies, "warden_heavy_thimble", 1)
	_check(not e_res.get("ok", true), "P-AC4: play_attack rejects a moved Warden")
	_check(_snapshot(e_deck, e_party, e_enemies) == e_snap, "P-AC4: moved-Warden rejection left state untouched")
	_check(_pin_map(e_pinned) == e_pins, "P-AC4: moved-Warden rejection left the token untouched")
	_check(e_deck._rng.state == e_rng, "P-AC4: moved-Warden rejection preserved deck._rng.state")

	# 6. Illegal / out-of-range target slots with a pinned legal foe present.
	var f_party: CombatParty = _party()
	var f_enemies: CombatEnemies = _enemies([20, 20])
	var f_pinned: CombatPinned = CombatPinned.new()
	_check(f_pinned.pin_enemy(f_enemies, 1, "seamstress"), "P-AC4: pin slot 1 for the bad-target cases")
	var f_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new(f_pinned)
	var f_deck: CombatDeck = _deck(["warden_heavy_thimble"])
	var f_rng: int = f_deck._rng.state
	var f_snap: Dictionary = _snapshot(f_deck, f_party, f_enemies)
	var f_pins: Dictionary = _pin_map(f_pinned)
	_check(not f_service.can_play(f_deck, f_party, f_enemies, "warden_heavy_thimble", 3),
		"P-AC4: can_play rejects target 3 for Heavy Thimble")
	var f_res: Dictionary = f_service.play_attack(f_deck, f_party, f_enemies, "warden_heavy_thimble", 3)
	_check(not f_res.get("ok", true), "P-AC4: Heavy Thimble rejects target 3 with a bound token")
	_check(_snapshot(f_deck, f_party, f_enemies) == f_snap, "P-AC4: bad-target rejection left state untouched")
	_check(_pin_map(f_pinned) == f_pins, "P-AC4: bad-target rejection left the token untouched")
	_check(f_deck._rng.state == f_rng, "P-AC4: bad-target rejection preserved deck._rng.state")

	var g_party: CombatParty = _party()
	var g_enemies: CombatEnemies = _enemies([20, 20])
	var g_pinned: CombatPinned = CombatPinned.new()
	_check(g_pinned.pin_enemy(g_enemies, 1, "tinker"), "P-AC4: pin slot 1 for the out-of-range cases")
	var g_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new(g_pinned)
	var g_deck: CombatDeck = _deck(["warden_pin_and_pound"])
	var g_rng: int = g_deck._rng.state
	var g_snap: Dictionary = _snapshot(g_deck, g_party, g_enemies)
	var g_pins: Dictionary = _pin_map(g_pinned)
	for bad_target: int in [0, 4, -1]:
		_check(not g_service.can_play(g_deck, g_party, g_enemies, "warden_pin_and_pound", bad_target),
			"P-AC4: can_play rejects out-of-range target " + str(bad_target))
		var g_res: Dictionary = g_service.play_attack(g_deck, g_party, g_enemies,
			"warden_pin_and_pound", bad_target)
		_check(not g_res.get("ok", true), "P-AC4: Pin and Pound rejects target " + str(bad_target))
	_check(_snapshot(g_deck, g_party, g_enemies) == g_snap, "P-AC4: out-of-range rejections left state untouched")
	_check(_pin_map(g_pinned) == g_pins, "P-AC4: out-of-range rejections left the token untouched")
	_check(g_deck._rng.state == g_rng, "P-AC4: out-of-range rejections preserved deck._rng.state")

	# 7. Slain target whose token survives on the corpse slot.
	var h_party: CombatParty = _party()
	var h_enemies: CombatEnemies = _enemies([20, 20])
	var h_pinned: CombatPinned = CombatPinned.new()
	_check(h_pinned.pin_enemy(h_enemies, 1, "seamstress"), "P-AC4: pin slot 1 before it is slain")
	_check(h_enemies.apply_damage(1, 999), "P-AC4: slew the pinned enemy 1")
	var h_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new(h_pinned)
	var h_deck: CombatDeck = _deck(["warden_pin_and_pound"])
	var h_rng: int = h_deck._rng.state
	var h_snap: Dictionary = _snapshot(h_deck, h_party, h_enemies)
	var h_pins: Dictionary = _pin_map(h_pinned)
	_check(not h_service.can_play(h_deck, h_party, h_enemies, "warden_pin_and_pound", 1),
		"P-AC4: can_play rejects a slain target")
	var h_res: Dictionary = h_service.play_attack(h_deck, h_party, h_enemies, "warden_pin_and_pound", 1)
	_check(not h_res.get("ok", true), "P-AC4: play_attack rejects a slain target")
	_check(_snapshot(h_deck, h_party, h_enemies) == h_snap, "P-AC4: slain-target rejection left state untouched")
	_check(_pin_map(h_pinned) == h_pins, "P-AC4: slain-target rejection left the token untouched")
	_check(h_deck._rng.state == h_rng, "P-AC4: slain-target rejection preserved deck._rng.state")

	# 8. A rejection on a service bound later still honors the new binding.
	var i_party: CombatParty = _party()
	var i_enemies: CombatEnemies = _enemies([20, 20])
	var i_pinned: CombatPinned = CombatPinned.new()
	_check(i_pinned.pin_enemy(i_enemies, 1, "tinker"), "P-AC4: pin slot 1 before rebinding")
	var i_service: CombatWardenPoolHeavyAttacks = CombatWardenPoolHeavyAttacks.new()
	_check(not i_service.can_play(_deck(["warden_strike"]), i_party, i_enemies, "warden_heavy_thimble", 1),
		"P-AC4: unbound service still rejects an absent card")
	i_service.set_pinned(i_pinned)
	var i_deck: CombatDeck = _deck(["warden_heavy_thimble"])
	var i_res: Dictionary = i_service.play_attack(i_deck, i_party, i_enemies, "warden_heavy_thimble", 1)
	_check(i_res.get("ok", false), "P-AC4: rebinding a live service still plays legally")
	var i_hit: Dictionary = (i_res.get("hits", []) as Array)[0] as Dictionary
	_check(int(i_hit.get("damage", 0)) == 16, "P-AC4: rebound token grants the +5 on the next legal play")
	_check(i_pinned.pinner_for_enemy(1) == "", "P-AC4: rebound token is consumed by the confirmed hit")


func _patch_context(party: CombatParty, wearer: String = "warden", sew_arm: bool = false, sew_head: bool = false) -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/patches/m04_attack_patches.json"))
	_check(raw is Array and raw.size() >= 2, "authored M04 attack patch metadata parsed")
	var definitions: Array = []
	for entry in raw:
		definitions.append({"id": entry["id"], "slot": entry["slot"]})
	var owned: Array = []
	if sew_head:
		owned.append("button_eye")
	if sew_arm:
		owned.append("pincushion_arm")
	var torn := RunTornMending.new(party.get_heroes())
	var wardrobe := RunPatchWardrobe.new(party.get_heroes(), owned, definitions, 3)
	_check(torn.is_valid() and wardrobe.is_valid(), "genuine three-hero run patch ledgers valid")
	if sew_head:
		var result: Dictionary = wardrobe.sew("button_eye", wearer, "HEAD", "sew_button_eye", wardrobe.get_snapshot())
		_check(result.get("ok", false) and wardrobe.get_snapshot()["worn"][wearer]["HEAD"] == "button_eye",
			"Button Eye sewn on " + wearer + " HEAD slot")
	if sew_arm:
		var result: Dictionary = wardrobe.sew("pincushion_arm", wearer, "ARM", "sew_pincushion_arm", wardrobe.get_snapshot())
		_check(result.get("ok", false) and wardrobe.get_snapshot()["worn"][wearer]["ARM"] == "pincushion_arm",
			"Pincushion Arm sewn on " + wearer + " ARM slot")
	return {"wardrobe": wardrobe, "torn": torn}


## Patch AC1: On a valid wardrobe with Pincushion Arm sewn on Warden ARM slot,
## exactly +1 is added to EACH damaging hit before Weak/Exposed calculations.
## Unbound plays retain all existing exact results.
func _test_patch_ac1_pincushion_arm_damage_bonus() -> void:
	# 1. Base Heavy Thimble (11 + 1 = 12 damage)
	var party1 := _party()
	var ctx1 := _patch_context(party1, "warden", true, false)
	var enemies1 := _enemies([25, 20])
	var deck1 := _deck(["warden_heavy_thimble"])
	var service1 := CombatWardenPoolHeavyAttacks.new()
	_check(service1.bind_patch_wardrobe(ctx1.wardrobe, ctx1.torn), "AC1: Heavy Thimble bound Pincushion Arm")
	_check(service1._patches.damage_bonus("warden") == 1, "AC1: Warden has +1 damage bonus")
	var rng1 := deck1._rng.state
	_check(service1.can_play(deck1, party1, enemies1, "warden_heavy_thimble", 1), "AC1: can_play legal for target 1")
	_check(deck1._rng.state == rng1, "AC1: preflight preserved RNG")
	var res1 := service1.play_attack(deck1, party1, enemies1, "warden_heavy_thimble", 1)
	_check(res1.get("ok", false), "AC1: Heavy Thimble succeeded")
	_check(deck1._rng.state == rng1, "AC1: execution preserved RNG")
	var hits1: Array = res1.get("hits", []) as Array
	_check(hits1.size() == 1, "AC1: 1 hit produced")
	var h1: Dictionary = hits1[0] as Dictionary
	_check(int(h1.get("damage", 0)) == 12, "AC1: 11 base + 1 patch = 12 damage")
	_check(int(h1.get("block_absorbed", 0)) == 0 and int(h1.get("hp_loss", 0)) == 12, "AC1: 12 HP loss")
	_check(enemies1.get_enemy(1)["hp"] == 13, "AC1: enemy 1 HP is 25 - 12 = 13")
	_check(deck1.energy == 1, "AC1: exactly 2 energy spent")
	_check(not deck1.hand.has("warden_heavy_thimble") and deck1.discard_pile.has("warden_heavy_thimble"), "AC1: card discarded once")

	# 2. Heavy Thimble+ (15 + 1 = 16 damage) with Block absorption
	var party2 := _party()
	var ctx2 := _patch_context(party2, "warden", true, false)
	var enemies2 := _enemies([30, 20])
	_check(enemies2.gain_block(1, 5), "AC1: set enemy 1 block to 5")
	var deck2 := _deck(["warden_heavy_thimble_plus"])
	var service2 := CombatWardenPoolHeavyAttacks.new()
	_check(service2.bind_patch_wardrobe(ctx2.wardrobe, ctx2.torn), "AC1: Heavy Thimble+ bound Pincushion Arm")
	var res2 := service2.play_attack(deck2, party2, enemies2, "warden_heavy_thimble_plus", 1)
	_check(res2.get("ok", false), "AC1: Heavy Thimble+ succeeded")
	var hits2: Array = res2.get("hits", []) as Array
	_check(hits2.size() == 1, "AC1: 1 hit produced")
	var h2: Dictionary = hits2[0] as Dictionary
	_check(int(h2.get("damage", 0)) == 16, "AC1: 15 base + 1 patch = 16 damage")
	_check(int(h2.get("block_absorbed", 0)) == 5 and int(h2.get("hp_loss", 0)) == 11, "AC1: 5 block absorbed, 11 HP loss")
	_check(enemies2.get_enemy(1)["hp"] == 19 and enemies2.get_enemy(1)["block"] == 0, "AC1: enemy 1 HP is 30 - 11 = 19, block 0")
	_check(deck2.energy == 1, "AC1: 2 energy spent")

	# 3. Pin and Pound (9 + 1 = 10 damage twice) on target 2
	var party3 := _party()
	var ctx3 := _patch_context(party3, "warden", true, false)
	var enemies3 := _enemies([30, 40, 30])
	var deck3 := _deck(["warden_pin_and_pound"])
	var service3 := CombatWardenPoolHeavyAttacks.new()
	_check(service3.bind_patch_wardrobe(ctx3.wardrobe, ctx3.torn), "AC1: Pin and Pound bound Pincushion Arm")
	var res3 := service3.play_attack(deck3, party3, enemies3, "warden_pin_and_pound", 2)
	_check(res3.get("ok", false), "AC1: Pin and Pound succeeded")
	var hits3: Array = res3.get("hits", []) as Array
	_check(hits3.size() == 2, "AC1: Pin and Pound produced 2 hits")
	var p3_h1: Dictionary = hits3[0] as Dictionary
	var p3_h2: Dictionary = hits3[1] as Dictionary
	_check(int(p3_h1.get("damage", 0)) == 10 and int(p3_h1.get("hp_loss", 0)) == 10, "AC1: Hit 1 dealt 10 damage")
	_check(int(p3_h2.get("damage", 0)) == 10 and int(p3_h2.get("hp_loss", 0)) == 10, "AC1: Hit 2 dealt 10 damage (+1 on EACH hit)")
	_check(enemies3.get_enemy(2)["hp"] == 20, "AC1: enemy 2 HP is 40 - 20 = 20")
	_check(deck3.energy == 1, "AC1: 2 energy spent once")
	_check(not deck3.hand.has("warden_pin_and_pound") and deck3.discard_pile.has("warden_pin_and_pound"), "AC1: card discarded once")

	# 4. Pin and Pound+ (12 + 1 = 13 damage twice) with Block absorption
	var party4 := _party()
	var ctx4 := _patch_context(party4, "warden", true, false)
	var enemies4 := _enemies([35, 20])
	_check(enemies4.gain_block(1, 6), "AC1: gave enemy 1 6 block")
	var deck4 := _deck(["warden_pin_and_pound_plus"])
	var service4 := CombatWardenPoolHeavyAttacks.new()
	_check(service4.bind_patch_wardrobe(ctx4.wardrobe, ctx4.torn), "AC1: Pin and Pound+ bound Pincushion Arm")
	var res4 := service4.play_attack(deck4, party4, enemies4, "warden_pin_and_pound_plus", 1)
	_check(res4.get("ok", false), "AC1: Pin and Pound+ succeeded")
	var hits4: Array = res4.get("hits", []) as Array
	_check(hits4.size() == 2, "AC1: Pin and Pound+ produced 2 hits")
	var p4_h1: Dictionary = hits4[0] as Dictionary
	var p4_h2: Dictionary = hits4[1] as Dictionary
	_check(int(p4_h1.get("damage", 0)) == 13 and int(p4_h1.get("block_absorbed", 0)) == 6 and int(p4_h1.get("hp_loss", 0)) == 7,
		"AC1: Hit 1 dealt 13, absorbed 6 block, 7 HP loss")
	_check(int(p4_h2.get("damage", 0)) == 13 and int(p4_h2.get("block_absorbed", 0)) == 0 and int(p4_h2.get("hp_loss", 0)) == 13,
		"AC1: Hit 2 dealt 13, absorbed 0 block, 13 HP loss")
	_check(enemies4.get_enemy(1)["hp"] == 15 and enemies4.get_enemy(1)["block"] == 0, "AC1: enemy 1 HP is 35 - 7 - 13 = 15")

	# 5. Weak and Exposed with Pincushion Arm:
	# Weak Warden: floor(10 * 3 / 4) = 7 per hit. Total 14.
	var party_w := _party_with_statuses({"weak": 1})
	var ctx_w := _patch_context(party_w, "warden", true, false)
	var enemies_w := _enemies([30, 20])
	var deck_w := _deck(["warden_pin_and_pound"])
	var service_w := CombatWardenPoolHeavyAttacks.new()
	_check(service_w.bind_patch_wardrobe(ctx_w.wardrobe, ctx_w.torn), "AC1: Weak Pin and Pound bound")
	var res_w := service_w.play_attack(deck_w, party_w, enemies_w, "warden_pin_and_pound", 1)
	_check(res_w.get("ok", false), "AC1: Weak Pin and Pound succeeded")
	var hits_w: Array = res_w.get("hits", []) as Array
	_check(int((hits_w[0] as Dictionary).get("damage", 0)) == 7, "AC1: Weak hit 1 is floor(10*3/4) = 7")
	_check(int((hits_w[1] as Dictionary).get("damage", 0)) == 7, "AC1: Weak hit 2 is floor(10*3/4) = 7")
	_check(enemies_w.get_enemy(1)["hp"] == 16, "AC1: enemy 1 HP is 30 - 14 = 16")

	# Exposed Enemy: floor(10 * 3 / 2) = 15 per hit. Total 30.
	var party_e := _party()
	var ctx_e := _patch_context(party_e, "warden", true, false)
	var enemies_e := _enemies([40, 20])
	_check(enemies_e.apply_statuses({1: {"exposed": 1}}), "AC1: applied exposed to enemy 1")
	var deck_e := _deck(["warden_pin_and_pound"])
	var service_e := CombatWardenPoolHeavyAttacks.new()
	_check(service_e.bind_patch_wardrobe(ctx_e.wardrobe, ctx_e.torn), "AC1: Exposed Pin and Pound bound")
	var res_e := service_e.play_attack(deck_e, party_e, enemies_e, "warden_pin_and_pound", 1)
	_check(res_e.get("ok", false), "AC1: Exposed Pin and Pound succeeded")
	var hits_e: Array = res_e.get("hits", []) as Array
	_check(int((hits_e[0] as Dictionary).get("damage", 0)) == 15, "AC1: Exposed hit 1 is floor(10*3/2) = 15")
	_check(int((hits_e[1] as Dictionary).get("damage", 0)) == 15, "AC1: Exposed hit 2 is floor(10*3/2) = 15")
	_check(enemies_e.get_enemy(1)["hp"] == 10, "AC1: enemy 1 HP is 40 - 30 = 10")

	# Weak + Exposed: floor(10 * 9 / 8) = 11 per hit. Total 22.
	var party_we := _party_with_statuses({"weak": 1})
	var ctx_we := _patch_context(party_we, "warden", true, false)
	var enemies_we := _enemies([30, 20])
	_check(enemies_we.apply_statuses({1: {"exposed": 1}}), "AC1: applied exposed to enemy 1 for we")
	var deck_we := _deck(["warden_pin_and_pound"])
	var service_we := CombatWardenPoolHeavyAttacks.new()
	_check(service_we.bind_patch_wardrobe(ctx_we.wardrobe, ctx_we.torn), "AC1: Weak+Exposed Pin and Pound bound")
	var res_we := service_we.play_attack(deck_we, party_we, enemies_we, "warden_pin_and_pound", 1)
	_check(res_we.get("ok", false), "AC1: Weak+Exposed Pin and Pound succeeded")
	var hits_we: Array = res_we.get("hits", []) as Array
	_check(int((hits_we[0] as Dictionary).get("damage", 0)) == 11, "AC1: Weak+Exposed hit 1 is floor(10*9/8) = 11")
	_check(int((hits_we[1] as Dictionary).get("damage", 0)) == 11, "AC1: Weak+Exposed hit 2 is floor(10*9/8) = 11")
	_check(enemies_we.get_enemy(1)["hp"] == 8, "AC1: enemy 1 HP is 30 - 22 = 8")

	# 6. Pinned token (+5 from different hero) + Pincushion Arm (+1):
	# Heavy Thimble: 11 base + 5 pin + 1 patch = 17 raw damage.
	var party_p := _party()
	var ctx_p := _patch_context(party_p, "warden", true, false)
	var enemies_p := _enemies([30, 20])
	var pinned_p := CombatPinned.new()
	_check(pinned_p.pin_enemy(enemies_p, 1, "seamstress"), "AC1: pinned slot 1 by Seamstress")
	var service_p := CombatWardenPoolHeavyAttacks.new(pinned_p)
	_check(service_p.bind_patch_wardrobe(ctx_p.wardrobe, ctx_p.torn), "AC1: Pinned Heavy Thimble bound")
	var deck_p := _deck(["warden_heavy_thimble"])
	var res_p := service_p.play_attack(deck_p, party_p, enemies_p, "warden_heavy_thimble", 1)
	_check(res_p.get("ok", false), "AC1: Pinned Heavy Thimble succeeded")
	var hits_p: Array = res_p.get("hits", []) as Array
	_check(int((hits_p[0] as Dictionary).get("damage", 0)) == 17, "AC1: 11 + 5 pin + 1 patch = 17 damage")
	_check(int((hits_p[0] as Dictionary).get("pinned_bonus", 0)) == 5, "AC1: pinned bonus recorded")
	_check(enemies_p.get_enemy(1)["hp"] == 13, "AC1: enemy 1 HP is 30 - 17 = 13")
	_check(pinned_p.pinner_for_enemy(1) == "", "AC1: pin consumed")

	# Pin and Pound with Pinned: hit 1 = 9 + 5 + 1 = 15; hit 2 = 9 + 0 + 1 = 10.
	var party_p2 := _party()
	var ctx_p2 := _patch_context(party_p2, "warden", true, false)
	var enemies_p2 := _enemies([35, 20])
	var pinned_p2 := CombatPinned.new()
	_check(pinned_p2.pin_enemy(enemies_p2, 1, "tinker"), "AC1: pinned slot 1 by Tinker")
	var service_p2 := CombatWardenPoolHeavyAttacks.new(pinned_p2)
	_check(service_p2.bind_patch_wardrobe(ctx_p2.wardrobe, ctx_p2.torn), "AC1: Pinned Pin and Pound bound")
	var deck_p2 := _deck(["warden_pin_and_pound"])
	var res_p2 := service_p2.play_attack(deck_p2, party_p2, enemies_p2, "warden_pin_and_pound", 1)
	_check(res_p2.get("ok", false), "AC1: Pinned Pin and Pound succeeded")
	var hits_p2: Array = res_p2.get("hits", []) as Array
	_check(hits_p2.size() == 2, "AC1: 2 hits produced")
	_check(int((hits_p2[0] as Dictionary).get("damage", 0)) == 15 and int((hits_p2[0] as Dictionary).get("pinned_bonus", 0)) == 5,
		"AC1: Hit 1 is 9 + 5 + 1 = 15")
	_check(int((hits_p2[1] as Dictionary).get("damage", 0)) == 10 and int((hits_p2[1] as Dictionary).get("pinned_bonus", 0)) == 0,
		"AC1: Hit 2 is 9 + 0 + 1 = 10 (pin consumed on hit 1)")
	_check(enemies_p2.get_enemy(1)["hp"] == 10, "AC1: enemy 1 HP is 35 - 25 = 10")
	_check(pinned_p2.pinner_for_enemy(1) == "", "AC1: pin consumed")

	# Pin and Pound+ with Pinned: hit 1 = 12 + 5 + 1 = 18; hit 2 = 12 + 0 + 1 = 13.
	var party_pp_p := _party()
	var ctx_pp_p := _patch_context(party_pp_p, "warden", true, false)
	var enemies_pp_p := _enemies([40, 20])
	var pinned_pp_p := CombatPinned.new()
	_check(pinned_pp_p.pin_enemy(enemies_pp_p, 1, "seamstress"), "AC1: pinned slot 1 for Pin and Pound+")
	var service_pp_p := CombatWardenPoolHeavyAttacks.new(pinned_pp_p)
	_check(service_pp_p.bind_patch_wardrobe(ctx_pp_p.wardrobe, ctx_pp_p.torn), "AC1: bound for Pinned Pin and Pound+")
	var deck_pp_p := _deck(["warden_pin_and_pound_plus"])
	var res_pp_p := service_pp_p.play_attack(deck_pp_p, party_pp_p, enemies_pp_p, "warden_pin_and_pound_plus", 1)
	_check(res_pp_p.get("ok", false), "AC1: Pinned Pin and Pound+ succeeded")
	var hits_pp_p: Array = res_pp_p.get("hits", []) as Array
	_check(int((hits_pp_p[0] as Dictionary).get("damage", 0)) == 18 and int((hits_pp_p[0] as Dictionary).get("pinned_bonus", 0)) == 5,
		"AC1: Pin and Pound+ hit 1 is 12 + 5 + 1 = 18")
	_check(int((hits_pp_p[1] as Dictionary).get("damage", 0)) == 13 and int((hits_pp_p[1] as Dictionary).get("pinned_bonus", 0)) == 0,
		"AC1: Pin and Pound+ hit 2 is 12 + 0 + 1 = 13")
	_check(enemies_pp_p.get_enemy(1)["hp"] == 9, "AC1: enemy 1 HP is 40 - 31 = 9")
	_check(pinned_pp_p.pinner_for_enemy(1) == "", "AC1: pin consumed")

	# Heavy Thimble+ with Pinned: 15 + 5 + 1 = 21.
	var party_tp_p := _party()
	var ctx_tp_p := _patch_context(party_tp_p, "warden", true, false)
	var enemies_tp_p := _enemies([30, 20])
	var pinned_tp_p := CombatPinned.new()
	_check(pinned_tp_p.pin_enemy(enemies_tp_p, 1, "tinker"), "AC1: pinned slot 1 for Heavy Thimble+")
	var service_tp_p := CombatWardenPoolHeavyAttacks.new(pinned_tp_p)
	_check(service_tp_p.bind_patch_wardrobe(ctx_tp_p.wardrobe, ctx_tp_p.torn), "AC1: bound for Pinned Heavy Thimble+")
	var deck_tp_p := _deck(["warden_heavy_thimble_plus"])
	var res_tp_p := service_tp_p.play_attack(deck_tp_p, party_tp_p, enemies_tp_p, "warden_heavy_thimble_plus", 1)
	_check(res_tp_p.get("ok", false), "AC1: Pinned Heavy Thimble+ succeeded")
	var hits_tp_p: Array = res_tp_p.get("hits", []) as Array
	_check(int((hits_tp_p[0] as Dictionary).get("damage", 0)) == 21 and int((hits_tp_p[0] as Dictionary).get("pinned_bonus", 0)) == 5,
		"AC1: Heavy Thimble+ is 15 + 5 + 1 = 21")
	_check(enemies_tp_p.get_enemy(1)["hp"] == 9, "AC1: enemy 1 HP is 30 - 21 = 9")
	_check(pinned_tp_p.pinner_for_enemy(1) == "", "AC1: pin consumed")

	# Weak on Heavy Thimble: floor(12 * 3 / 4) = 9
	var party_tw := _party_with_statuses({"weak": 1})
	var ctx_tw := _patch_context(party_tw, "warden", true, false)
	var enemies_tw := _enemies([30, 20])
	var deck_tw := _deck(["warden_heavy_thimble"])
	var service_tw := CombatWardenPoolHeavyAttacks.new()
	_check(service_tw.bind_patch_wardrobe(ctx_tw.wardrobe, ctx_tw.torn), "AC1: Weak Heavy Thimble bound")
	var res_tw := service_tw.play_attack(deck_tw, party_tw, enemies_tw, "warden_heavy_thimble", 1)
	_check(res_tw.get("ok", false), "AC1: Weak Heavy Thimble succeeded")
	_check(int(((res_tw.get("hits", []) as Array)[0] as Dictionary).get("damage", 0)) == 9,
		"AC1: Weak Heavy Thimble deals floor(12 * 3/4) = 9")
	_check(enemies_tw.get_enemy(1)["hp"] == 21, "AC1: enemy 1 HP is 30 - 9 = 21")

	# Exposed on Heavy Thimble: floor(12 * 3 / 2) = 18
	var party_te := _party()
	var ctx_te := _patch_context(party_te, "warden", true, false)
	var enemies_te := _enemies([30, 20])
	_check(enemies_te.apply_statuses({1: {"exposed": 1}}), "AC1: applied exposed to enemy 1")
	var deck_te := _deck(["warden_heavy_thimble"])
	var service_te := CombatWardenPoolHeavyAttacks.new()
	_check(service_te.bind_patch_wardrobe(ctx_te.wardrobe, ctx_te.torn), "AC1: Exposed Heavy Thimble bound")
	var res_te := service_te.play_attack(deck_te, party_te, enemies_te, "warden_heavy_thimble", 1)
	_check(res_te.get("ok", false), "AC1: Exposed Heavy Thimble succeeded")
	_check(int(((res_te.get("hits", []) as Array)[0] as Dictionary).get("damage", 0)) == 18,
		"AC1: Exposed Heavy Thimble deals floor(12 * 3/2) = 18")
	_check(enemies_te.get_enemy(1)["hp"] == 12, "AC1: enemy 1 HP is 30 - 18 = 12")

	# Weak on Heavy Thimble+: floor(16 * 3 / 4) = 12
	var party_tpw := _party_with_statuses({"weak": 1})
	var ctx_tpw := _patch_context(party_tpw, "warden", true, false)
	var enemies_tpw := _enemies([30, 20])
	var deck_tpw := _deck(["warden_heavy_thimble_plus"])
	var service_tpw := CombatWardenPoolHeavyAttacks.new()
	_check(service_tpw.bind_patch_wardrobe(ctx_tpw.wardrobe, ctx_tpw.torn), "AC1: Weak Heavy Thimble+ bound")
	var res_tpw := service_tpw.play_attack(deck_tpw, party_tpw, enemies_tpw, "warden_heavy_thimble_plus", 1)
	_check(res_tpw.get("ok", false), "AC1: Weak Heavy Thimble+ succeeded")
	_check(int(((res_tpw.get("hits", []) as Array)[0] as Dictionary).get("damage", 0)) == 12,
		"AC1: Weak Heavy Thimble+ deals floor(16 * 3/4) = 12")
	_check(enemies_tpw.get_enemy(1)["hp"] == 18, "AC1: enemy 1 HP is 30 - 12 = 18")

	# Exposed on Heavy Thimble+: floor(16 * 3 / 2) = 24
	var party_tpe := _party()
	var ctx_tpe := _patch_context(party_tpe, "warden", true, false)
	var enemies_tpe := _enemies([40, 20])
	_check(enemies_tpe.apply_statuses({1: {"exposed": 1}}), "AC1: applied exposed to enemy 1")
	var deck_tpe := _deck(["warden_heavy_thimble_plus"])
	var service_tpe := CombatWardenPoolHeavyAttacks.new()
	_check(service_tpe.bind_patch_wardrobe(ctx_tpe.wardrobe, ctx_tpe.torn), "AC1: Exposed Heavy Thimble+ bound")
	var res_tpe := service_tpe.play_attack(deck_tpe, party_tpe, enemies_tpe, "warden_heavy_thimble_plus", 1)
	_check(res_tpe.get("ok", false), "AC1: Exposed Heavy Thimble+ succeeded")
	_check(int(((res_tpe.get("hits", []) as Array)[0] as Dictionary).get("damage", 0)) == 24,
		"AC1: Exposed Heavy Thimble+ deals floor(16 * 3/2) = 24")
	_check(enemies_tpe.get_enemy(1)["hp"] == 16, "AC1: enemy 1 HP is 40 - 24 = 16")

	# Weak on Pin and Pound+: floor(13 * 3 / 4) = 9 per hit. Total 18.
	var party_ppw := _party_with_statuses({"weak": 1})
	var ctx_ppw := _patch_context(party_ppw, "warden", true, false)
	var enemies_ppw := _enemies([30, 20])
	var deck_ppw := _deck(["warden_pin_and_pound_plus"])
	var service_ppw := CombatWardenPoolHeavyAttacks.new()
	_check(service_ppw.bind_patch_wardrobe(ctx_ppw.wardrobe, ctx_ppw.torn), "AC1: Weak Pin and Pound+ bound")
	var res_ppw := service_ppw.play_attack(deck_ppw, party_ppw, enemies_ppw, "warden_pin_and_pound_plus", 1)
	_check(res_ppw.get("ok", false), "AC1: Weak Pin and Pound+ succeeded")
	var hits_ppw: Array = res_ppw.get("hits", []) as Array
	_check(int((hits_ppw[0] as Dictionary).get("damage", 0)) == 9 and int((hits_ppw[1] as Dictionary).get("damage", 0)) == 9,
		"AC1: Weak Pin and Pound+ deals floor(13 * 3/4) = 9 per hit")
	_check(enemies_ppw.get_enemy(1)["hp"] == 12, "AC1: enemy 1 HP is 30 - 18 = 12")

	# Exposed on Pin and Pound+: floor(13 * 3 / 2) = 19 per hit. Total 38.
	var party_ppe := _party()
	var ctx_ppe := _patch_context(party_ppe, "warden", true, false)
	var enemies_ppe := _enemies([50, 20])
	_check(enemies_ppe.apply_statuses({1: {"exposed": 1}}), "AC1: applied exposed to enemy 1")
	var deck_ppe := _deck(["warden_pin_and_pound_plus"])
	var service_ppe := CombatWardenPoolHeavyAttacks.new()
	_check(service_ppe.bind_patch_wardrobe(ctx_ppe.wardrobe, ctx_ppe.torn), "AC1: Exposed Pin and Pound+ bound")
	var res_ppe := service_ppe.play_attack(deck_ppe, party_ppe, enemies_ppe, "warden_pin_and_pound_plus", 1)
	_check(res_ppe.get("ok", false), "AC1: Exposed Pin and Pound+ succeeded")
	var hits_ppe: Array = res_ppe.get("hits", []) as Array
	_check(int((hits_ppe[0] as Dictionary).get("damage", 0)) == 19 and int((hits_ppe[1] as Dictionary).get("damage", 0)) == 19,
		"AC1: Exposed Pin and Pound+ deals floor(13 * 3/2) = 19 per hit")
	_check(enemies_ppe.get_enemy(1)["hp"] == 12, "AC1: enemy 1 HP is 50 - 38 = 12")


## Patch AC2: Button Eye in HEAD applies Exposed 1 to the struck enemy from the first
## successful heavy card of combat after all hits; consumed once for Warden; Pin and Pound
## hit two does not benefit from its own newly applied Exposed; lethal short-circuit applies
## Exposed and consumes latch; rejections do not consume latch.
func _test_patch_ac2_button_eye_exposed_and_latch() -> void:
	# 1. Button Eye on Heavy Thimble: applies Exposed 1 and latches; second attack does not apply Exposed
	var party1 := _party()
	var ctx1 := _patch_context(party1, "warden", false, true)
	var enemies1 := _enemies([30, 30])
	var deck1 := _deck(["warden_heavy_thimble", "warden_pin_and_pound"])
	var service1 := CombatWardenPoolHeavyAttacks.new()
	_check(service1.bind_patch_wardrobe(ctx1.wardrobe, ctx1.torn), "AC2: bound Button Eye")
	_check(service1._patches.exposed_for_first_hit("warden") == {"exposed": 1}, "AC2: Warden has first attack exposed")
	_check(service1._patches.latch_snapshot().get("warden") == false, "AC2: latch not yet consumed")

	var res1 := service1.play_attack(deck1, party1, enemies1, "warden_heavy_thimble", 1)
	_check(res1.get("ok", false), "AC2: Heavy Thimble succeeded")
	var hits1: Array = res1.get("hits", []) as Array
	_check(int((hits1[0] as Dictionary).get("damage", 0)) == 11, "AC2: 11 damage dealt")
	_check((hits1[0] as Dictionary).get("statuses", {}) == {"exposed": 1}, "AC2: hit 1 status has exposed 1")
	_check(enemies1.get_enemy(1)["statuses"].get("exposed", 0) == 1, "AC2: enemy 1 has exposed 1")
	_check(service1._patches.latch_snapshot().get("warden") == true, "AC2: latch consumed")
	_check(service1._patches.exposed_for_first_hit("warden") == {}, "AC2: exposed_for_first_hit empty after latch")

	# Second attack in same combat: does NOT apply Exposed
	deck1.combat_state.energy += 2
	var res1_2 := service1.play_attack(deck1, party1, enemies1, "warden_pin_and_pound", 2)
	_check(res1_2.get("ok", false), "AC2: second attack succeeded")
	var hits1_2: Array = res1_2.get("hits", []) as Array
	_check((hits1_2[0] as Dictionary).get("statuses", {}) == {}, "AC2: second attack hit 1 has no patch exposed")
	_check((hits1_2[1] as Dictionary).get("statuses", {}) == {}, "AC2: second attack hit 2 has no patch exposed")
	_check(not enemies1.get_enemy(2).has("statuses") or enemies1.get_enemy(2)["statuses"].is_empty(),
		"AC2: enemy 2 has no exposed status")

	# 2. Pin and Pound: hit 2 is NOT amplified by Button Eye's newly applied Exposed
	var party2 := _party()
	var ctx2 := _patch_context(party2, "warden", false, true)
	var enemies2 := _enemies([30, 30])
	var deck2 := _deck(["warden_pin_and_pound"])
	var service2 := CombatWardenPoolHeavyAttacks.new()
	_check(service2.bind_patch_wardrobe(ctx2.wardrobe, ctx2.torn), "AC2: bound Button Eye for Pin and Pound")
	var res2 := service2.play_attack(deck2, party2, enemies2, "warden_pin_and_pound", 1)
	_check(res2.get("ok", false), "AC2: Pin and Pound succeeded")
	var hits2: Array = res2.get("hits", []) as Array
	_check(hits2.size() == 2, "AC2: 2 hits produced")
	var p2_h1: Dictionary = hits2[0] as Dictionary
	var p2_h2: Dictionary = hits2[1] as Dictionary
	_check(int(p2_h1.get("damage", 0)) == 9, "AC2: hit 1 deals 9 damage")
	_check(int(p2_h2.get("damage", 0)) == 9, "AC2: hit 2 deals 9 damage (NOT amplified by Exposed!)")
	_check(enemies2.get_enemy(1)["hp"] == 12, "AC2: enemy 1 HP is 30 - 18 = 12 (not 30 - 22 = 8)")
	_check(enemies2.get_enemy(1)["statuses"].get("exposed", 0) == 1, "AC2: enemy 1 has exposed 1 after card resolves")
	_check(p2_h1.get("statuses", {}) == {"exposed": 1}, "AC2: hit 1 records applied exposed 1")
	_check(p2_h2.get("statuses", {}) == {}, "AC2: hit 2 statuses is empty")
	_check(service2._patches.latch_snapshot().get("warden") == true, "AC2: latch consumed")

	# 3. Existing enemy Exposed interaction: Enemy 1 already has exposed 1
	var party3 := _party()
	var ctx3 := _patch_context(party3, "warden", false, true)
	var enemies3 := _enemies([40, 30])
	_check(enemies3.apply_statuses({1: {"exposed": 1}}), "AC2: seeded exposed 1 on enemy 1")
	var deck3 := _deck(["warden_pin_and_pound"])
	var service3 := CombatWardenPoolHeavyAttacks.new()
	_check(service3.bind_patch_wardrobe(ctx3.wardrobe, ctx3.torn), "AC2: bound Button Eye with existing exposed")
	var res3 := service3.play_attack(deck3, party3, enemies3, "warden_pin_and_pound", 1)
	_check(res3.get("ok", false), "AC2: Pin and Pound on exposed enemy succeeded")
	var hits3: Array = res3.get("hits", []) as Array
	_check(int((hits3[0] as Dictionary).get("damage", 0)) == 13, "AC2: hit 1 deals floor(9 * 3/2) = 13")
	_check(int((hits3[1] as Dictionary).get("damage", 0)) == 13, "AC2: hit 2 deals floor(9 * 3/2) = 13")
	_check(enemies3.get_enemy(1)["hp"] == 14, "AC2: enemy 1 HP is 40 - 26 = 14")
	_check(enemies3.get_enemy(1)["statuses"].get("exposed", 0) == 2, "AC2: enemy 1 exposed increased from 1 to 2")
	_check((hits3[0] as Dictionary).get("statuses", {}) == {"exposed": 1}, "AC2: hit 1 records applied exposed 1")

	# 4. Existing Pinned interaction
	var party4 := _party()
	var ctx4 := _patch_context(party4, "warden", false, true)
	var enemies4 := _enemies([35, 20])
	var pinned4 := CombatPinned.new()
	_check(pinned4.pin_enemy(enemies4, 1, "seamstress"), "AC2: pinned slot 1 by Seamstress")
	var service4 := CombatWardenPoolHeavyAttacks.new(pinned4)
	_check(service4.bind_patch_wardrobe(ctx4.wardrobe, ctx4.torn), "AC2: bound Button Eye and Pinned")
	var deck4 := _deck(["warden_pin_and_pound"])
	var res4 := service4.play_attack(deck4, party4, enemies4, "warden_pin_and_pound", 1)
	_check(res4.get("ok", false), "AC2: Pinned + Button Eye succeeded")
	var hits4: Array = res4.get("hits", []) as Array
	_check(int((hits4[0] as Dictionary).get("damage", 0)) == 14, "AC2: hit 1 deals 9 + 5 = 14")
	_check(int((hits4[1] as Dictionary).get("damage", 0)) == 9, "AC2: hit 2 deals 9")
	_check(enemies4.get_enemy(1)["hp"] == 12, "AC2: enemy 1 HP is 35 - 23 = 12")
	_check(enemies4.get_enemy(1)["statuses"].get("exposed", 0) == 1, "AC2: exposed 1 applied after all hits")
	_check(pinned4.pinner_for_enemy(1) == "", "AC2: pin consumed")

	# 5. First-hit lethal short-circuit: Enemy 1 has 6 HP, dies on hit 1
	var party5 := _party()
	var ctx5 := _patch_context(party5, "warden", false, true)
	var enemies5 := _enemies([6, 30])
	var deck5 := _deck(["warden_pin_and_pound"])
	var service5 := CombatWardenPoolHeavyAttacks.new()
	_check(service5.bind_patch_wardrobe(ctx5.wardrobe, ctx5.torn), "AC2: bound Button Eye for lethal short-circuit")
	var res5 := service5.play_attack(deck5, party5, enemies5, "warden_pin_and_pound", 1)
	_check(res5.get("ok", false), "AC2: lethal play succeeded")
	var hits5: Array = res5.get("hits", []) as Array
	_check(hits5.size() == 1, "AC2: hit 2 skipped on lethal hit 1")
	_check(enemies5.is_slain(1) and enemies5.get_enemy(1)["hp"] == 0, "AC2: enemy 1 is slain")
	_check(enemies5.get_enemy(1)["statuses"].get("exposed", 0) == 1, "AC2: exposed 1 applied to slain enemy slot")
	_check((hits5[0] as Dictionary).get("statuses", {}) == {"exposed": 1}, "AC2: lethal hit 1 records applied exposed")
	_check(service5._patches.latch_snapshot().get("warden") == true, "AC2: latch consumed on lethal short-circuit")

	# 6. Simultaneous ARM and HEAD patches on Warden
	var party6 := _party()
	var ctx6 := _patch_context(party6, "warden", true, true)
	var enemies6 := _enemies([35, 20])
	var deck6 := _deck(["warden_pin_and_pound"])
	var service6 := CombatWardenPoolHeavyAttacks.new()
	_check(service6.bind_patch_wardrobe(ctx6.wardrobe, ctx6.torn), "AC2: bound both ARM and HEAD")
	_check(service6._patches.damage_bonus("warden") == 1, "AC2: +1 damage active")
	_check(service6._patches.exposed_for_first_hit("warden") == {"exposed": 1}, "AC2: exposed 1 active")
	var res6 := service6.play_attack(deck6, party6, enemies6, "warden_pin_and_pound", 1)
	_check(res6.get("ok", false), "AC2: simultaneous ARM and HEAD play succeeded")
	var hits6: Array = res6.get("hits", []) as Array
	_check(hits6.size() == 2, "AC2: 2 hits")
	_check(int((hits6[0] as Dictionary).get("damage", 0)) == 10, "AC2: hit 1 deals 9 + 1 = 10")
	_check(int((hits6[1] as Dictionary).get("damage", 0)) == 10, "AC2: hit 2 deals 9 + 1 = 10")
	_check(enemies6.get_enemy(1)["hp"] == 15, "AC2: enemy 1 HP is 35 - 20 = 15")
	_check(enemies6.get_enemy(1)["statuses"].get("exposed", 0) == 1, "AC2: exposed 1 applied after card resolves")
	_check(service6._patches.latch_snapshot().get("warden") == true, "AC2: latch consumed")

	# 7. Rejections do not consume Button Eye latch
	var party7 := _party()
	var ctx7 := _patch_context(party7, "warden", false, true)
	var enemies7 := _enemies([30, 20])
	var deck7 := _deck(["warden_heavy_thimble"])
	var service7 := CombatWardenPoolHeavyAttacks.new()
	_check(service7.bind_patch_wardrobe(ctx7.wardrobe, ctx7.torn), "AC2: bound Button Eye for rejection check")
	_check(deck7.try_spend_energy(2), "AC2: spent 2 energy leaving 1")
	_check(not service7.can_play(deck7, party7, enemies7, "warden_heavy_thimble", 1), "AC2: can_play rejects low energy")
	var res7 := service7.play_attack(deck7, party7, enemies7, "warden_heavy_thimble", 1)
	_check(not res7.get("ok", true), "AC2: play_attack rejects low energy")
	_check(service7._patches.latch_snapshot().get("warden") == false, "AC2: latch stays false on rejected play")

	# 8. Status overflow preflight: enemy at MAX_INT exposed rejects before debit
	var party8 := _party()
	var ctx8 := _patch_context(party8, "warden", false, true)
	var enemies8 := _enemies([30, 20])
	enemies8._enemies[0]["statuses"] = {"exposed": CombatEnemies.MAX_INT}
	var deck8 := _deck(["warden_heavy_thimble"])
	var service8 := CombatWardenPoolHeavyAttacks.new()
	_check(service8.bind_patch_wardrobe(ctx8.wardrobe, ctx8.torn), "AC2: bound Button Eye for overflow check")
	_check(not service8.can_play(deck8, party8, enemies8, "warden_heavy_thimble", 1), "AC2: can_play rejects exposed overflow")
	var snap8 := _snapshot(deck8, party8, enemies8)
	var rng8 := deck8._rng.state
	var res8 := service8.play_attack(deck8, party8, enemies8, "warden_heavy_thimble", 1)
	_check(not res8.get("ok", true), "AC2: play_attack rejects exposed overflow")
	_check(_snapshot(deck8, party8, enemies8) == snap8, "AC2: overflow leaves state untouched")
	_check(deck8._rng.state == rng8, "AC2: overflow preserves RNG")
	_check(service8._patches.latch_snapshot().get("warden") == false, "AC2: overflow leaves latch unconsumed")


## Patch AC3: RunPatchWardrobe/RunTornMending projection determines effects; torn Warden
## or patch worn by other hero gives no bonus; invalid explicit binding fails closed;
## invalid plays change no state, RNG, tokens, or patch latch; deterministic seeded replay.
func _test_patch_ac3_projection_rejections_and_replay() -> void:
	# 1. Patch worn by another hero (Tinker wears both Pincushion Arm and Button Eye)
	var party1 := _party()
	var ctx1 := _patch_context(party1, "tinker", true, true)
	var enemies1 := _enemies([30, 30])
	var deck1 := _deck(["warden_heavy_thimble", "warden_pin_and_pound"])
	var service1 := CombatWardenPoolHeavyAttacks.new()
	_check(service1.bind_patch_wardrobe(ctx1.wardrobe, ctx1.torn), "AC3: bound wardrobe worn by Tinker")
	_check(service1._patches.damage_bonus("warden") == 0, "AC3: Warden gets 0 damage bonus")
	_check(service1._patches.exposed_for_first_hit("warden") == {}, "AC3: Warden gets no exposed")
	var res1 := service1.play_attack(deck1, party1, enemies1, "warden_heavy_thimble", 1)
	_check(res1.get("ok", false), "AC3: Heavy Thimble succeeded")
	var hits1: Array = res1.get("hits", []) as Array
	_check(int((hits1[0] as Dictionary).get("damage", 0)) == 11, "AC3: exact 11 damage (no bonus from Tinker's patch)")
	_check((hits1[0] as Dictionary).get("statuses", {}) == {}, "AC3: no exposed applied from Tinker's patch")
	_check(enemies1.get_enemy(1)["hp"] == 19, "AC3: enemy 1 HP is 30 - 11 = 19")

	# 2. Torn Warden: in RunTornMending Warden has 0 HP
	var party_torn := _party()
	var ctx_torn := _patch_context(party_torn, "warden", true, true)
	var start_heroes: Array = ctx_torn.torn.read_state()["heroes"]
	_check(party_torn.apply_damage(1, 999) and party_torn.is_downed(1), "AC3: downed Warden")
	_check(ctx_torn.torn.observe_battle_end("tear_warden", start_heroes, party_torn.get_heroes()).get("ok", false),
		"AC3: torn ledger observed downed Warden")
	var service_torn := CombatWardenPoolHeavyAttacks.new()
	_check(service_torn.bind_patch_wardrobe(ctx_torn.wardrobe, ctx_torn.torn), "AC3: torn wardrobe bound successfully")
	_check(service_torn._patches.damage_bonus("warden") == 0, "AC3: torn Warden projected damage bonus is 0")
	_check(service_torn._patches.exposed_for_first_hit("warden") == {}, "AC3: torn Warden projected exposed is empty")

	# 3. Invalid explicit binding fails closed
	var invalid_service := CombatWardenPoolHeavyAttacks.new()
	var party3 := _party()
	var enemies3 := _enemies([30, 30])
	var deck3 := _deck(["warden_heavy_thimble"])
	var snap3 := _snapshot(deck3, party3, enemies3)
	_check(not invalid_service.bind_patch_wardrobe(null, RunTornMending.new(party3.get_heroes())),
		"AC3: null wardrobe rejects binding")
	_check(invalid_service._patches != null and not invalid_service._patches.is_valid(),
		"AC3: explicit binding failed and is marked invalid")
	_check(not invalid_service.can_play(deck3, party3, enemies3, "warden_heavy_thimble", 1),
		"AC3: can_play fails closed on invalid explicit binding")
	var res3 := invalid_service.play_attack(deck3, party3, enemies3, "warden_heavy_thimble", 1)
	_check(not res3.get("ok", true), "AC3: play_attack fails closed on invalid explicit binding")
	_check(_snapshot(deck3, party3, enemies3) == snap3, "AC3: state untouched after invalid binding rejection")
	_check(invalid_service.get_valid_targets(party3, enemies3, "warden_heavy_thimble").is_empty(),
		"AC3: get_valid_targets returns empty array on invalid binding")

	# 4. Table of rejections with bound patches leaves state, tokens, RNG and latch unchanged
	var party4 := _party()
	var ctx4 := _patch_context(party4, "warden", true, true)
	var pinned4 := CombatPinned.new()
	var enemies4 := _enemies([30, 30])
	_check(pinned4.pin_enemy(enemies4, 1, "seamstress"), "AC3: pin slot 1")
	var service4 := CombatWardenPoolHeavyAttacks.new(pinned4)
	_check(service4.bind_patch_wardrobe(ctx4.wardrobe, ctx4.torn), "AC3: bound wardrobe for negative checks")

	# Scenario A: Absent card
	var deck_a := _deck(["warden_strike"])
	var rng_a := deck_a._rng.state
	var snap_a := _snapshot(deck_a, party4, enemies4)
	var pin_a := _pin_map(pinned4)
	_check(not service4.can_play(deck_a, party4, enemies4, "warden_heavy_thimble", 1), "AC3: absent card can_play false")
	var res_a := service4.play_attack(deck_a, party4, enemies4, "warden_heavy_thimble", 1)
	_check(not res_a.get("ok", true), "AC3: absent card play_attack false")
	_check(_snapshot(deck_a, party4, enemies4) == snap_a, "AC3: absent card left state untouched")
	_check(_pin_map(pinned4) == pin_a, "AC3: absent card left pins untouched")
	_check(deck_a._rng.state == rng_a, "AC3: absent card preserved RNG")
	_check(service4._patches.latch_snapshot().get("warden") == false, "AC3: absent card left latch untouched")

	# Scenario B: Low energy
	var deck_b := _deck(["warden_heavy_thimble"])
	_check(deck_b.try_spend_energy(2), "AC3: spent 2 energy leaving 1")
	var rng_b := deck_b._rng.state
	var snap_b := _snapshot(deck_b, party4, enemies4)
	_check(not service4.can_play(deck_b, party4, enemies4, "warden_heavy_thimble", 1), "AC3: low energy can_play false")
	var res_b := service4.play_attack(deck_b, party4, enemies4, "warden_heavy_thimble", 1)
	_check(not res_b.get("ok", true), "AC3: low energy play_attack false")
	_check(_snapshot(deck_b, party4, enemies4) == snap_b, "AC3: low energy left state untouched")
	_check(deck_b._rng.state == rng_b, "AC3: low energy preserved RNG")
	_check(service4._patches.latch_snapshot().get("warden") == false, "AC3: low energy left latch untouched")

	# Scenario C: Inactive turn
	var deck_c := _deck(["warden_heavy_thimble"])
	_check(deck_c.end_turn(), "AC3: end turn")
	var rng_c := deck_c._rng.state
	var snap_c := _snapshot(deck_c, party4, enemies4)
	_check(not service4.can_play(deck_c, party4, enemies4, "warden_heavy_thimble", 1), "AC3: inactive turn can_play false")
	var res_c := service4.play_attack(deck_c, party4, enemies4, "warden_heavy_thimble", 1)
	_check(not res_c.get("ok", true), "AC3: inactive turn play_attack false")
	_check(_snapshot(deck_c, party4, enemies4) == snap_c, "AC3: inactive turn left state untouched")
	_check(deck_c._rng.state == rng_c, "AC3: inactive turn preserved RNG")
	_check(service4._patches.latch_snapshot().get("warden") == false, "AC3: inactive turn left latch untouched")

	# Scenario D: Downed Warden
	var party_d := _party()
	_check(party_d.apply_damage(1, 999), "AC3: downed Warden")
	var deck_d := _deck(["warden_heavy_thimble"])
	var rng_d := deck_d._rng.state
	var snap_d := _snapshot(deck_d, party_d, enemies4)
	_check(not service4.can_play(deck_d, party_d, enemies4, "warden_heavy_thimble", 1), "AC3: downed Warden can_play false")
	var res_d := service4.play_attack(deck_d, party_d, enemies4, "warden_heavy_thimble", 1)
	_check(not res_d.get("ok", true), "AC3: downed Warden play_attack false")
	_check(_snapshot(deck_d, party_d, enemies4) == snap_d, "AC3: downed Warden left state untouched")
	_check(deck_d._rng.state == rng_d, "AC3: downed Warden preserved RNG")
	_check(service4._patches.latch_snapshot().get("warden") == false, "AC3: downed Warden left latch untouched")

	# Scenario E: Warden moved out of position 1
	var party_e := CombatParty.new([
		{"id": "seamstress", "max_hp": 30},
		{"id": "warden", "max_hp": 40},
		{"id": "tinker", "max_hp": 26},
	])
	var deck_e := _deck(["warden_heavy_thimble"])
	var rng_e := deck_e._rng.state
	var snap_e := _snapshot(deck_e, party_e, enemies4)
	_check(not service4.can_play(deck_e, party_e, enemies4, "warden_heavy_thimble", 1), "AC3: moved Warden can_play false")
	var res_e := service4.play_attack(deck_e, party_e, enemies4, "warden_heavy_thimble", 1)
	_check(not res_e.get("ok", true), "AC3: moved Warden play_attack false")
	_check(_snapshot(deck_e, party_e, enemies4) == snap_e, "AC3: moved Warden left state untouched")
	_check(deck_e._rng.state == rng_e, "AC3: moved Warden preserved RNG")
	_check(service4._patches.latch_snapshot().get("warden") == false, "AC3: moved Warden left latch untouched")

	# Scenario F: Slain target
	var enemies_f := _enemies([20, 20])
	_check(enemies_f.apply_damage(1, 999), "AC3: slew enemy 1")
	var deck_f := _deck(["warden_heavy_thimble"])
	var rng_f := deck_f._rng.state
	var snap_f := _snapshot(deck_f, party4, enemies_f)
	_check(not service4.can_play(deck_f, party4, enemies_f, "warden_heavy_thimble", 1), "AC3: slain target can_play false")
	var res_f := service4.play_attack(deck_f, party4, enemies_f, "warden_heavy_thimble", 1)
	_check(not res_f.get("ok", true), "AC3: slain target play_attack false")
	_check(_snapshot(deck_f, party4, enemies_f) == snap_f, "AC3: slain target left state untouched")
	_check(deck_f._rng.state == rng_f, "AC3: slain target preserved RNG")
	_check(service4._patches.latch_snapshot().get("warden") == false, "AC3: slain target left latch untouched")

	# Scenario G: Bad target slot (target 0, 4, -1)
	for bad_slot: int in [0, 4, -1]:
		var deck_g := _deck(["warden_pin_and_pound"])
		var rng_g := deck_g._rng.state
		var snap_g := _snapshot(deck_g, party4, enemies4)
		_check(not service4.can_play(deck_g, party4, enemies4, "warden_pin_and_pound", bad_slot),
			"AC3: bad slot " + str(bad_slot) + " can_play false")
		var res_g := service4.play_attack(deck_g, party4, enemies4, "warden_pin_and_pound", bad_slot)
		_check(not res_g.get("ok", true), "AC3: bad slot " + str(bad_slot) + " play_attack false")
		_check(_snapshot(deck_g, party4, enemies4) == snap_g, "AC3: bad slot left state untouched")
		_check(deck_g._rng.state == rng_g, "AC3: bad slot preserved RNG")
		_check(service4._patches.latch_snapshot().get("warden") == false, "AC3: bad slot left latch untouched")

	# Scenario H: Duplicate / stale play (card already discarded, play attempted again)
	var deck_h := _deck(["warden_heavy_thimble"])
	var res_h1 := service4.play_attack(deck_h, party4, enemies4, "warden_heavy_thimble", 1)
	_check(res_h1.get("ok", false), "AC3: first play succeeded")
	var snap_h := _snapshot(deck_h, party4, enemies4)
	var rng_h := deck_h._rng.state
	_check(not service4.can_play(deck_h, party4, enemies4, "warden_heavy_thimble", 1), "AC3: duplicate play can_play false")
	var res_h2 := service4.play_attack(deck_h, party4, enemies4, "warden_heavy_thimble", 1)
	_check(not res_h2.get("ok", true), "AC3: duplicate play rejected")
	_check(_snapshot(deck_h, party4, enemies4) == snap_h, "AC3: duplicate play left state untouched")
	_check(deck_h._rng.state == rng_h, "AC3: duplicate play preserved RNG")

	# 5. Seeded replay comparison with patches bound
	var replay_sequence: Callable = func(seed_val: int) -> Dictionary:
		var r_party := _party()
		var r_ctx := _patch_context(r_party, "warden", true, true)
		var r_enemies := _enemies([40, 40, 40])
		var r_deck := _deck(["warden_heavy_thimble_plus", "warden_pin_and_pound_plus"], seed_val)
		var r_service := CombatWardenPoolHeavyAttacks.new()
		r_service.bind_patch_wardrobe(r_ctx.wardrobe, r_ctx.torn)
		var rng_start := r_deck._rng.state
		var e1 := r_service.play_attack(r_deck, r_party, r_enemies, "warden_heavy_thimble_plus", 1)
		r_deck.combat_state.energy += 2
		var e2 := r_service.play_attack(r_deck, r_party, r_enemies, "warden_pin_and_pound_plus", 2)
		var rng_end := r_deck._rng.state
		_check(rng_end == rng_start, "AC3: replay preserves RNG state across patched plays")
		return {
			"events": [e1, e2],
			"party": r_party.get_heroes(),
			"enemies": r_enemies.get_enemies(),
			"deck_hand": r_deck.hand.duplicate(),
			"deck_discard": r_deck.discard_pile.duplicate(),
			"deck_energy": r_deck.energy,
			"rng_state": rng_end,
			"latches": r_service._patches.latch_snapshot(),
		}

	var rep1: Dictionary = replay_sequence.call(1234)
	var rep2: Dictionary = replay_sequence.call(1234)
	_check(rep1 == rep2, "AC3: patched play sequence is 100% deterministic under identical seed")

## P12: use the exact authored heavy definitions with genuine battle/run
## ledgers; never substitute a detached bonus number for a worn HEAD quote.
func _heavy_needle_context(card_id: String, wearer: String = "warden",
		pin_owner: String = "warden", weak_exposed: bool = false) -> Dictionary:
	var party := _party_with_statuses({"weak": 1} if weak_exposed else {})
	var foes := _enemies([120, 120, 120])
	var deck := _deck([card_id, card_id, "warden_pin_and_pound"])
	var torn := RunTornMending.new(party.get_heroes())
	var wardrobe := RunPatchWardrobe.new(party.get_heroes(), ["needle_echo"],
		RunAuthoredPatchDefinitions.load_definitions(), 5)
	_check(torn.is_valid() and wardrobe.is_valid(), "heavy Needle real ledger preconditions")
	if not wearer.is_empty():
		_check(wardrobe.sew("needle_echo", wearer, "HEAD",
			"heavy_needle_sew", wardrobe.get_snapshot()).get("ok", false),
			"heavy Needle genuinely worn HEAD by " + wearer)
	var pins := CombatPinned.new()
	if not pin_owner.is_empty():
		_check(pins.pin_enemy(foes, 1, pin_owner), "heavy Needle genuine living pin")
	if weak_exposed:
		_check(foes.apply_statuses({1: {"exposed": 1}}),
			"heavy Needle real Exposed target")
	var rules := CombatHeirloomPatchTriggers.new()
	_check(rules.bind_battle(wardrobe, torn, party, foes, pins)
		and rules.start_player_turn() and rules.is_current(),
		"heavy Needle genuine wearer, party, target and turn bound")
	return {"party": party, "foes": foes, "deck": deck, "pins": pins,
		"rules": rules, "wardrobe": wardrobe, "torn": torn}


func _test_needle_heavy_first_hit_receipts() -> void:
	for id in CombatWardenPoolHeavyAttacks.SUPPORTED_CARD_IDS:
		var printed := WardenPoolCards.new().get_definition(id)
		var multi: bool = int(printed.effects.get("hits", 1)) == 2
		var battle := _heavy_needle_context(id, "warden", "warden",
			id == "warden_pin_and_pound_plus")
		var deck: CombatDeck = battle.deck
		var foes: CombatEnemies = battle.foes
		var rules: CombatHeirloomPatchTriggers = battle.rules
		var pins: CombatPinned = battle.pins
		var service := CombatWardenPoolHeavyAttacks.new(pins)
		var blocked: int = 110 if id == "warden_heavy_thimble_plus" else 3
		_check(deck.hand.has(id) and printed.id == id
			and printed.owner == "warden" and printed.target_kind == "enemy_single"
			and printed.from_positions == [1] and printed.to_positions.has(1)
			and foes.gain_block(1, blocked), "held canonical heavy and genuine Block " + id)
		var before := foes.get_enemy(1)
		var payment := _snapshot(deck, battle.party, foes)
		var quote: Dictionary = rules.quote_needle_hit("warden", 1, id)
		_check(quote.get("ok", false) and quote.get("card_id") == id
			and rules.authorizes_needle_hit(quote, battle.party, foes, id, 1),
			"exact authored heavy printing has a sealed Echo ticket " + id)
		var result := service.play_attack(deck, battle.party, foes, id, 1,
			{}, {}, pins, null, null, {}, rules, quote)
		var base: int = printed.effects.damage
		var hero_status: Dictionary = battle.party.get_hero(1).get("statuses", {})
		var enemy_status: Dictionary = before.get("statuses", {})
		var first: int = CombatStatuses.new().adjusted_attack_damage(
			base + 1, hero_status, enemy_status)
		var second: int = CombatStatuses.new().adjusted_attack_damage(
			base, hero_status, enemy_status)
		var remaining_block: int = maxi(0, blocked - first)
		var first_block: int = mini(blocked, first)
		var second_block: int = mini(remaining_block, second) if multi else 0
		var hp_loss: int = first - first_block + (second - second_block if multi else 0)
		var after := foes.get_enemy(1)
		_check(result.get("ok", false) and result.get("hits", []).size() == (2 if multi else 1)
			and result.hits[0].damage == first
			and result.hits[0].block_absorbed == first_block
			and result.hits[0].hp_loss == first - first_block
			and (not multi or (result.hits[1].damage == second
				and result.hits[1].block_absorbed == second_block
				and result.hits[1].hp_loss == second - second_block))
			and after.hp == before.hp - hp_loss
			and after.block == before.block - first_block - second_block
			and after.get("statuses", {}) == before.get("statuses", {}),
			"Echo on first raw hit only, exact post-status HP/Block/status receipts " + id)
		_check(deck.energy == payment.energy - printed.cost
			and deck.hand.count(id) == payment.hand.count(id) - 1
			and deck.discard_pile.count(id) == payment.discard_pile.count(id) + 1
			and deck._rng.state == payment.rng_state
			and rules._needle_used and rules._pending_needle.is_empty()
			and pins.pinner_for_enemy(1) == "warden",
			"single paid/discarded heavy and Echo latch; same-owner Pin retained " + id)
		if id == "warden_heavy_thimble_plus":
			_check(result.hits[0].hp_loss == 0
				and result.hits[0].block_absorbed == first and rules._needle_used,
				"Block-only heavy contact still consumes Echo")
		if id == "warden_pin_and_pound_plus":
			_check(first == CombatStatuses.new().adjusted_attack_damage(
				base + 1, {"weak": 1}, {"exposed": 1})
				and first >= second,
				"Echo enters raw first hit before Weak and Exposed adjustments")
		_check(not rules.quote_needle_hit("warden", 1, id).get("ok", false),
			"spent Echo cannot quote a second held heavy in same turn " + id)
		_check(not rules.finish_needle_hit(quote, result)
			and rules._needle_used, "paid heavy receipt replay is refused " + id)
		_check(rules.start_player_turn() and not rules._needle_used
			and rules.quote_needle_hit("warden", 1, id).get("ok", false),
			"fresh service turn rearms exact heavy Needle ticket " + id)
		rules.cancel_needle_hit()


func _test_needle_heavy_fail_closed() -> void:
	for scenario in ["forged", "stale", "wrong_card", "wrong_target", "no_energy",
			"wrong_owner", "unworn", "unpinned", "invalid_binding"]:
		var wearer := "seamstress" if scenario == "wrong_owner" else (
			"" if scenario == "unworn" else "warden")
		var pin_owner := "" if scenario == "unpinned" else "warden"
		var battle := _heavy_needle_context("warden_heavy_thimble", wearer, pin_owner)
		var deck: CombatDeck = battle.deck
		var foes: CombatEnemies = battle.foes
		var rules: CombatHeirloomPatchTriggers = battle.rules
		var pins: CombatPinned = battle.pins
		var id := "warden_heavy_thimble"
		var quote: Dictionary = rules.quote_needle_hit("warden", 1, id)
		if scenario in ["wrong_owner", "unworn", "unpinned"]:
			_check(not quote.get("ok", false) and rules._pending_needle.is_empty(),
				"refused Needle eligibility " + scenario)
			continue
		_check(quote.get("ok", false), "real precondition before heavy refusal " + scenario)
		if scenario == "forged":
			quote["ticket"] = -500
		if scenario == "stale":
			_check(pins.clear_pin(1), "stale quote loses original pin")
		if scenario == "no_energy":
			_check(deck.try_spend_energy(2), "real deck has insufficient heavy energy")
		if scenario == "invalid_binding":
			pins = CombatPinned.new()
		var before := _snapshot(deck, battle.party, foes)
		var before_pin: Dictionary = battle.pins._pinner_by_position.duplicate(true)
		var card := "warden_pin_and_pound" if scenario == "wrong_card" else id
		_check(deck.hand.has(card) and (deck.energy >= 2 or scenario == "no_energy"),
			"authentic selected/held candidate affordable before ticket refusal " + scenario)
		var target := 3 if scenario == "wrong_target" else 1
		var result := CombatWardenPoolHeavyAttacks.new().play_attack(
			deck, battle.party, foes, card, target, {}, {}, pins, null, null, {}, rules, quote)
		_check(not result.get("ok", false)
			and _snapshot(deck, battle.party, foes) == before
			and battle.pins._pinner_by_position == before_pin
			and not rules._needle_used and rules._pending_needle.is_empty(),
			"heavy refusal cancels ticket without energy/hand/RNG/pin/patch effects " + scenario)
