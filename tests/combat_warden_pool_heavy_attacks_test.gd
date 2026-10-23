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
