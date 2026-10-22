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
