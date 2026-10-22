extends SceneTree
## Deterministic SceneTree regression for Tinker's three Unravel pool attacks (D2-1).
## Covers Spool Launcher, Shrapnel Seam, and Snip the Seam (base and plus).

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_ac1_spool_launcher()
	_test_ac2_shrapnel_seam()
	_test_ac3_snip_the_seam()
	_test_ac4_shared_latch_and_rejections()
	_test_ac4_replay()
	for failure: String in failures:
		printerr(failure)
	print("combat_tinker_pool_unravel_attacks_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _deck(ids: Array, seed_value: int = 774) -> CombatDeck:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var card_ids: Array[String] = []
	card_ids.assign(ids)
	var deck: CombatDeck = CombatDeck.new(card_ids, rng)
	_check(deck.start_turn() and deck.energy == 3 and deck.hand.size() == ids.size(),
		"real seeded CombatDeck starts active with hand")
	return deck


func _party(order: Array = ["warden", "seamstress", "tinker"]) -> CombatParty:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/heroes/starter_party.json"))
	_check(raw is Array and raw.size() == 3, "real starter_party JSON loaded")
	var definitions: Array = []
	if raw is Array:
		for id in order:
			for hero in raw:
				if hero.get("id") == id:
					var def_copy: Dictionary = hero.duplicate(true)
					def_copy["max_hp"] = int(hero["max_hp"])
					definitions.append(def_copy)
	var party: CombatParty = CombatParty.new(definitions)
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"authentic party precondition satisfied")
	return party


func _enemies(hps: Array = [70, 70, 70]) -> CombatEnemies:
	var definitions: Array = []
	for index: int in range(hps.size()):
		definitions.append({"id": "foe_%d" % index, "max_hp": hps[index]})
	var enemies: CombatEnemies = CombatEnemies.new(definitions)
	_check(enemies.is_valid() and enemies.get_enemies().size() == hps.size(),
		"real enemy roster precondition satisfied")
	return enemies


func _unravel(enemies: CombatEnemies, tiers: Dictionary = {1: "normal", 2: "normal", 3: "normal"}) -> CombatUnravel:
	var unravel: CombatUnravel = CombatUnravel.new()
	var sub_tiers: Dictionary = {}
	for i: int in range(enemies.get_enemies().size()):
		var pos: int = i + 1
		sub_tiers[pos] = tiers.get(pos, "normal")
	_check(unravel.bind_roster(enemies, sub_tiers), "CombatUnravel binds to real roster")
	return unravel


func _snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		unravel: CombatUnravel, first: CombatTinkerFirstAttack) -> Dictionary:
	var gauges: Dictionary = {}
	for i: int in range(enemies.get_enemies().size()):
		var pos: int = i + 1
		gauges[pos] = unravel.get_snapshot(pos)
	return {
		"draw": deck.draw_pile.duplicate(),
		"hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(),
		"energy": deck.energy,
		"turn": deck.turn_active,
		"state_energy": deck.combat_state.energy,
		"state_turn": deck.combat_state.player_turn_active,
		"rng": deck._rng.state,
		"party": party.get_heroes(),
		"enemies": enemies.get_enemies(),
		"gauges": gauges,
		"consumed": first._consumed,
	}


func _test_ac1_spool_launcher() -> void:
	# Spool Launcher base: cost 1, damage 3, unravel 3. Tinker FROM [2, 3], TO [1, 2, 3].
	var first: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	var resolver: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first)
	var deck: CombatDeck = _deck(["tinker_spool_launcher", "warden_strike"])
	var party: CombatParty = _party(["warden", "seamstress", "tinker"])
	var enemies: CombatEnemies = _enemies([25, 25])
	var unravel: CombatUnravel = _unravel(enemies, {1: "normal", 2: "normal"})
	_check(enemies.gain_block(1, 4), "enemy 1 gains 4 Block")

	var before_rng: int = deck._rng.state

	var res: Dictionary = resolver.play_attack(deck, party, enemies, "tinker_spool_launcher", 1, unravel)
	_check(res.get("ok", false) == true, "Spool Launcher play succeeds")
	_check(res.get("hits", []).size() == 1, "Spool Launcher produces one hit")
	var hit: Dictionary = res["hits"][0]
	# Base 3 + 3 first attack bonus = 6 damage. 4 absorbed by Block, 2 direct HP loss (25 -> 23).
	_check(hit.get("position") == 1 and hit.get("damage") == 6
		and hit.get("block_absorbed") == 4 and hit.get("hp_loss") == 2
		and hit.get("unravel") == 3,
		"AC1: Spool Launcher hit event has correct damage, Block absorption, HP loss and unravel 3")
	_check(enemies.get_enemy(1)["hp"] == 23 and enemies.get_enemy(1)["block"] == 0,
		"AC1: enemy 1 HP and Block updated authoritatively")
	_check(unravel.get_snapshot(1)["gauge"] == 3 and unravel.get_snapshot(1)["threshold"] == 8,
		"AC1: enemy 1 gauge incremented by 3 to 3/8")
	# Check another slot unchanged
	_check(enemies.get_enemy(2)["hp"] == 25 and enemies.get_enemy(2)["block"] == 0,
		"AC1: enemy 2 unchanged")
	_check(unravel.get_snapshot(2)["gauge"] == 0 and unravel.get_snapshot(2)["threshold"] == 8,
		"AC1: enemy 2 gauge unchanged at 0/8")
	# Deck and first attack checks
	_check(deck.energy == 2 and deck.hand == ["warden_strike"]
		and deck.discard_pile == ["tinker_spool_launcher"],
		"AC1: spends 1 energy and discards one held copy")
	_check(first._consumed == true, "AC1: first attack latch consumed")
	_check(deck._rng.state == before_rng, "AC1: zero RNG draws")

	# Spool Launcher plus: cost 1, damage 4, unravel 4. Tinker in slot 2.
	var first_plus: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	var resolver_plus: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first_plus)
	var deck_plus: CombatDeck = _deck(["tinker_spool_launcher_plus"])
	var party_plus: CombatParty = _party(["warden", "tinker", "seamstress"])
	var enemies_plus: CombatEnemies = _enemies([30])
	var unravel_plus: CombatUnravel = _unravel(enemies_plus, {1: "normal"})
	var rng_plus_before: int = deck_plus._rng.state

	var res_plus: Dictionary = resolver_plus.play_attack(deck_plus, party_plus, enemies_plus,
		"tinker_spool_launcher_plus", 1, unravel_plus)
	_check(res_plus.get("ok", false) == true, "Spool Launcher+ play succeeds from slot 2")
	var hit_plus: Dictionary = res_plus["hits"][0]
	# Base 4 + 3 first attack bonus = 7 damage.
	_check(hit_plus.get("position") == 1 and hit_plus.get("damage") == 7
		and hit_plus.get("hp_loss") == 7 and hit_plus.get("unravel") == 4,
		"AC1: Spool Launcher+ deals 7 damage and adds Unravel 4")
	_check(unravel_plus.get_snapshot(1)["gauge"] == 4, "AC1: gauge incremented by 4")
	_check(deck_plus._rng.state == rng_plus_before, "AC1: zero RNG draws on Spool+")

	# Lethal hit test: hit resolves successfully, slain enemy gains NO new unravel
	var first_lethal: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	first_lethal.record_successful_attack("tinker_pop_shot") # no first-attack bonus, raw damage 3
	var resolver_lethal: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first_lethal)
	var deck_lethal: CombatDeck = _deck(["tinker_spool_launcher"])
	var party_lethal: CombatParty = _party()
	var enemies_lethal: CombatEnemies = _enemies([2]) # 2 HP, hit for 3 is lethal
	var unravel_lethal: CombatUnravel = _unravel(enemies_lethal, {1: "normal"})

	var res_lethal: Dictionary = resolver_lethal.play_attack(deck_lethal, party_lethal, enemies_lethal,
		"tinker_spool_launcher", 1, unravel_lethal)
	_check(res_lethal.get("ok", false) == true, "AC1: lethal Spool hit resolves successfully")
	_check(enemies_lethal.is_slain(1), "AC1: target is slain")
	_check(unravel_lethal.get_snapshot(1)["gauge"] == 0,
		"AC1: slain enemy gains no new Unravel (gauge remains 0)")
	_check(res_lethal["hits"][0]["unravel"] == 0,
		"AC1: hit event reports 0 unravel on lethal hit")


func _test_ac2_shrapnel_seam() -> void:
	# Shrapnel Seam: cost 2, FROM [3], enemy_all TO [1, 2, 3]. damage 5, unravel 2.
	# 3-enemy roster with slain middle slot (slot 2 dead) and elite slot 3 (threshold 12).
	var first: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	var resolver: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first)
	var deck: CombatDeck = _deck(["tinker_shrapnel_seam", "warden_strike"])
	var party: CombatParty = _party(["warden", "seamstress", "tinker"])
	var enemies: CombatEnemies = _enemies([30, 20, 30])
	var unravel: CombatUnravel = _unravel(enemies, {1: "normal", 2: "normal", 3: "elite"})
	_check(enemies.apply_damage(2, 20) and enemies.is_slain(2), "middle enemy slot 2 is slain")

	var before_rng: int = deck._rng.state
	var res: Dictionary = resolver.play_attack(deck, party, enemies, "tinker_shrapnel_seam", 0, unravel)
	_check(res.get("ok", false) == true, "AC2: Shrapnel Seam succeeds with target_position 0")
	_check(res.get("hits", []).size() == 2, "AC2: hits exactly surviving slots 1 and 3")
	# First attack bonus (+3) applies to both recipients: 5 + 3 = 8
	var h1: Dictionary = res["hits"][0]
	var h2: Dictionary = res["hits"][1]
	_check(h1.get("position") == 1 and h1.get("damage") == 8 and h1.get("unravel") == 2,
		"AC2: slot 1 receives 8 damage and 2 unravel")
	_check(h2.get("position") == 3 and h2.get("damage") == 8 and h2.get("unravel") == 2,
		"AC2: slot 3 receives 8 damage and 2 unravel")
	_check(enemies.get_enemy(1)["hp"] == 22 and enemies.get_enemy(3)["hp"] == 22,
		"AC2: authoritative HP updated for both living slots")
	_check(enemies.get_enemy(2)["hp"] == 0 and enemies.is_slain(2),
		"AC2: middle slain slot 2 unchanged")
	_check(unravel.get_snapshot(1)["gauge"] == 2 and unravel.get_snapshot(1)["threshold"] == 8,
		"AC2: normal slot 1 gauge 2/8")
	_check(unravel.get_snapshot(2)["gauge"] == 0, "AC2: slain slot 2 gauge untouched")
	_check(unravel.get_snapshot(3)["gauge"] == 2 and unravel.get_snapshot(3)["threshold"] == 12,
		"AC2: elite slot 3 gauge 2/12")
	_check(deck.energy == 1 and deck.hand == ["warden_strike"]
		and deck.discard_pile == ["tinker_shrapnel_seam"],
		"AC2: charged 2 energy and discarded once")
	_check(deck._rng.state == before_rng, "AC2: zero RNG draws on Shrapnel")

	# Shrapnel Seam plus: cost 2, damage 7, unravel 3. 2-enemy roster (normal 8 and elite 12).
	var first_plus: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	var resolver_plus: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first_plus)
	var deck_plus: CombatDeck = _deck(["tinker_shrapnel_seam_plus"])
	var party_plus: CombatParty = _party()
	var enemies_plus: CombatEnemies = _enemies([40, 40])
	var unravel_plus: CombatUnravel = _unravel(enemies_plus, {1: "normal", 2: "elite"})
	var rng_plus_before: int = deck_plus._rng.state

	var res_plus: Dictionary = resolver_plus.play_attack(deck_plus, party_plus, enemies_plus,
		"tinker_shrapnel_seam_plus", 0, unravel_plus)
	_check(res_plus.get("ok", false) == true, "AC2: Shrapnel+ succeeds")
	_check(res_plus.get("hits", []).size() == 2, "AC2: Shrapnel+ hits 2 enemies")
	_check(res_plus["hits"][0]["damage"] == 10 and res_plus["hits"][0]["unravel"] == 3,
		"AC2: Shrapnel+ hit 1 base 7 + 3 bonus = 10, unravel 3")
	_check(res_plus["hits"][1]["damage"] == 10 and res_plus["hits"][1]["unravel"] == 3,
		"AC2: Shrapnel+ hit 2 base 7 + 3 bonus = 10, unravel 3")
	_check(unravel_plus.get_snapshot(1) == {"gauge": 3, "threshold": 8, "unravelled": false, "skip_pending": false},
		"AC2: normal slot 1 snapshot 3/8")
	_check(unravel_plus.get_snapshot(2) == {"gauge": 3, "threshold": 12, "unravelled": false, "skip_pending": false},
		"AC2: elite slot 2 snapshot 3/12")
	_check(deck_plus._rng.state == rng_plus_before, "AC2: zero RNG draws on Shrapnel+")


func _test_ac3_snip_the_seam() -> void:
	# Snip the Seam: cost 1, FROM [2, 3], TO [1, 2, 3].
	# Base: damage 5, conditional 15 (unravelled or gauge >= half threshold).
	# Plus: damage 7, conditional 20.
	# Does not add unravel.

	# 1. Unempowered base Snip at normal threshold 8, gauge 0 (latch consumed -> no bonus, deals base 5)
	var first1: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	_check(first1.record_successful_attack("tinker_pop_shot"), "consume first attack latch")
	var resolver1: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first1)
	var deck1: CombatDeck = _deck(["tinker_snip_the_seam"])
	var party1: CombatParty = _party()
	var enemies1: CombatEnemies = _enemies([40])
	var unravel1: CombatUnravel = _unravel(enemies1, {1: "normal"})

	var res1: Dictionary = resolver1.play_attack(deck1, party1, enemies1, "tinker_snip_the_seam", 1, unravel1)
	_check(res1.get("ok", false) == true, "Snip play succeeds")
	_check(res1["hits"][0]["damage"] == 5, "AC3: unempowered Snip deals base 5 damage (no first bonus)")
	_check(unravel1.get_snapshot(1)["gauge"] == 0, "AC3: Snip does not add unravel")

	# 2. Gauge 3 on threshold 8: 3 < 4, still unempowered (deals base 5)
	var first2: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	_check(first2.record_successful_attack("tinker_pop_shot"), "consume first attack latch")
	var resolver2: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first2)
	var deck2: CombatDeck = _deck(["tinker_snip_the_seam"])
	var party2: CombatParty = _party()
	var enemies2: CombatEnemies = _enemies([40])
	var unravel2: CombatUnravel = _unravel(enemies2, {1: "normal"})
	_check(unravel2.apply_unravel(enemies2, 1, 3), "charge gauge to 3")
	var res2: Dictionary = resolver2.play_attack(deck2, party2, enemies2, "tinker_snip_the_seam", 1, unravel2)
	_check(res2["hits"][0]["damage"] == 5, "AC3: gauge 3/8 is strictly less than half, deals base 5")
	_check(unravel2.get_snapshot(1)["gauge"] == 3, "AC3: gauge unchanged after Snip")

	# 3. Exact half-threshold boundary: gauge 4 on threshold 8: 4 >= 4, empowered! (deals 15)
	var first3: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	_check(first3.record_successful_attack("tinker_pop_shot"), "consume first attack latch")
	var resolver3: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first3)
	var deck3: CombatDeck = _deck(["tinker_snip_the_seam"])
	var party3: CombatParty = _party()
	var enemies3: CombatEnemies = _enemies([40])
	var unravel3: CombatUnravel = _unravel(enemies3, {1: "normal"})
	_check(unravel3.apply_unravel(enemies3, 1, 4), "charge gauge to 4")
	var res3: Dictionary = resolver3.play_attack(deck3, party3, enemies3, "tinker_snip_the_seam", 1, unravel3)
	_check(res3["hits"][0]["damage"] == 15, "AC3: gauge 4/8 triggers empowered 15 damage")
	_check(unravel3.get_snapshot(1)["gauge"] == 4, "AC3: gauge stays at 4")

	# 4. Unravelled status branch: gauge 8 on threshold 8
	var first4: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	_check(first4.record_successful_attack("tinker_pop_shot"), "consume first attack latch")
	var resolver4: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first4)
	var deck4: CombatDeck = _deck(["tinker_snip_the_seam"])
	var party4: CombatParty = _party()
	var enemies4: CombatEnemies = _enemies([40])
	var unravel4: CombatUnravel = _unravel(enemies4, {1: "normal"})
	_check(unravel4.apply_unravel(enemies4, 1, 8), "charge gauge to threshold 8")
	_check(unravel4.get_snapshot(1)["unravelled"] == true and unravel4.get_snapshot(1)["skip_pending"] == true,
		"target is unravelled with pending skip")
	var res4: Dictionary = resolver4.play_attack(deck4, party4, enemies4, "tinker_snip_the_seam", 1, unravel4)
	_check(res4["hits"][0]["damage"] == 15, "AC3: unravelled target deals empowered 15 damage")
	_check(unravel4.get_snapshot(1)["gauge"] == 8 and unravel4.get_snapshot(1)["unravelled"] == true,
		"AC3: unravel state preserved, no gauge addition")

	# 5. Raised threshold 12 after consumed skip: half-boundary is 6
	var first5a: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	_check(first5a.record_successful_attack("tinker_pop_shot"), "consume first attack latch")
	var resolver5a: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first5a)
	var deck5a: CombatDeck = _deck(["tinker_snip_the_seam"])
	var party5a: CombatParty = _party()
	var enemies5a: CombatEnemies = _enemies([60])
	var unravel5a: CombatUnravel = _unravel(enemies5a, {1: "normal"})
	_check(unravel5a.apply_unravel(enemies5a, 1, 8), "charge to threshold 8")
	_check(unravel5a.consume_action_skip(enemies5a, 1), "consume skip, threshold rises to 12")
	_check(unravel5a.get_snapshot(1) == {"gauge": 0, "threshold": 12, "unravelled": false, "skip_pending": false},
		"threshold is now 12 and gauge is 0")
	# Charge gauge to 5: 5 < 12 / 2 = 6, unempowered
	_check(unravel5a.apply_unravel(enemies5a, 1, 5), "charge gauge to 5 on threshold 12")
	var res5a: Dictionary = resolver5a.play_attack(deck5a, party5a, enemies5a, "tinker_snip_the_seam", 1, unravel5a)
	_check(res5a["hits"][0]["damage"] == 5, "AC3: gauge 5/12 is below half, deals base 5")

	# Add 1 more unravel: gauge becomes 6: 6 >= 12 / 2 = 6, empowered!
	var first5b: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	_check(first5b.record_successful_attack("tinker_pop_shot"), "consume first attack latch")
	var resolver5b: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first5b)
	var deck5b: CombatDeck = _deck(["tinker_snip_the_seam"])
	_check(unravel5a.apply_unravel(enemies5a, 1, 1), "charge gauge to 6 on threshold 12")
	_check(unravel5a.get_snapshot(1)["gauge"] == 6 and unravel5a.get_snapshot(1)["threshold"] == 12,
		"gauge is now 6/12")
	var res5b: Dictionary = resolver5b.play_attack(deck5b, party5a, enemies5a, "tinker_snip_the_seam", 1, unravel5a)
	_check(res5b["hits"][0]["damage"] == 15, "AC3: gauge 6/12 triggers empowered 15 damage at threshold 12")

	# 6. Snip the Seam plus: damage 7 or conditionally 20
	var first_p1: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	_check(first_p1.record_successful_attack("tinker_pop_shot"), "consume latch")
	var resolver_p1: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first_p1)
	var deck_p1: CombatDeck = _deck(["tinker_snip_the_seam_plus"])
	var party_p1: CombatParty = _party()
	var enemies_p1: CombatEnemies = _enemies([60])
	var unravel_p1: CombatUnravel = _unravel(enemies_p1, {1: "normal"})
	# Unempowered plus: deals 7
	var res_p_unemp: Dictionary = resolver_p1.play_attack(deck_p1, party_p1, enemies_p1,
		"tinker_snip_the_seam_plus", 1, unravel_p1)
	_check(res_p_unemp["hits"][0]["damage"] == 7, "AC3: unempowered Snip+ deals 7 damage")

	# Empowered plus: charge to 4/8, deals 20
	var first_p2: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	_check(first_p2.record_successful_attack("tinker_pop_shot"), "consume latch")
	var resolver_p2: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first_p2)
	var deck_p2: CombatDeck = _deck(["tinker_snip_the_seam_plus"])
	_check(unravel_p1.apply_unravel(enemies_p1, 1, 4), "charge to 4/8")
	var res_p_emp: Dictionary = resolver_p2.play_attack(deck_p2, party_p1, enemies_p1,
		"tinker_snip_the_seam_plus", 1, unravel_p1)
	_check(res_p_emp["hits"][0]["damage"] == 20, "AC3: empowered Snip+ deals 20 damage")

	# 7. Real Block / Weak / Exposed calculation on empowered Snip
	var first_calc: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	_check(first_calc.record_successful_attack("tinker_pop_shot"), "consume first attack latch")
	var resolver_calc: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first_calc)
	var deck_calc: CombatDeck = _deck(["tinker_snip_the_seam"])
	var party_calc: CombatParty = _party()
	# Apply Weak 1 to Tinker (slot 3)
	party_calc._heroes[2]["statuses"] = {"weak": 1}
	var enemies_calc: CombatEnemies = _enemies([50])
	# Apply Exposed 1 to enemy 1 and 6 Block
	_check(enemies_calc.apply_statuses({1: {"exposed": 1}}), "enemy 1 exposed")
	_check(enemies_calc.gain_block(1, 6), "enemy 1 gains 6 Block")
	var unravel_calc: CombatUnravel = _unravel(enemies_calc, {1: "normal"})
	_check(unravel_calc.apply_unravel(enemies_calc, 1, 4), "gauge 4/8 makes Snip empowered (base 15)")
	# Weak + Exposed: 15 * 9 / 8 = 16 damage.
	# Block 6 absorbs 6, HP loss = 10 (50 -> 40).
	var res_calc: Dictionary = resolver_calc.play_attack(deck_calc, party_calc, enemies_calc,
		"tinker_snip_the_seam", 1, unravel_calc)
	_check(res_calc.get("ok", false) == true, "calculation test play succeeds")
	var h_calc: Dictionary = res_calc["hits"][0]
	_check(h_calc.get("damage") == 16 and h_calc.get("block_absorbed") == 6 and h_calc.get("hp_loss") == 10,
		"AC3: Weak and Exposed status math with Block absorption matches authoritative floor arithmetic")
	_check(enemies_calc.get_enemy(1)["hp"] == 40 and enemies_calc.get_enemy(1)["block"] == 0,
		"AC3: enemy HP and Block updated after calculation")


func _test_ac4_shared_latch_and_rejections() -> void:
	# Shared CombatTinkerFirstAttack latch between CombatTinkerPoolAttacks and CombatTinkerPoolUnravelAttacks
	var shared_first: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	var direct_resolver: CombatTinkerPoolAttacks = CombatTinkerPoolAttacks.new(shared_first)
	var unravel_resolver: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(shared_first)

	var deck: CombatDeck = _deck(["tinker_spool_launcher", "tinker_long_barrel"])
	var party: CombatParty = _party()
	var enemies: CombatEnemies = _enemies([50])
	var unravel: CombatUnravel = _unravel(enemies, {1: "normal"})

	# First attack: Spool Launcher gains +3 (base 3 + 3 = 6)
	var res1: Dictionary = unravel_resolver.play_attack(deck, party, enemies, "tinker_spool_launcher", 1, unravel)
	_check(res1.get("ok", false) == true and res1["hits"][0]["damage"] == 6,
		"AC4: first Tinker attack gains +3 damage bonus")
	_check(shared_first._consumed == true, "AC4: shared latch is consumed")

	# Second attack: Long Barrel via CombatTinkerPoolAttacks does NOT get bonus (base 12, not 15)
	var res2: Dictionary = direct_resolver.play_attack(deck, party, enemies, "tinker_long_barrel", 1)
	_check(res2.get("ok", false) == true and res2["hits"][0]["damage"] == 12,
		"AC4: second attack from other resolver does not receive bonus")

	# Turn reset restores bonus
	shared_first.start_player_turn()
	_check(shared_first._consumed == false, "AC4: start_player_turn resets latch")
	var deck_area: CombatDeck = _deck(["tinker_shrapnel_seam"])
	var enemies_area: CombatEnemies = _enemies([30, 30])
	var unravel_area: CombatUnravel = _unravel(enemies_area, {1: "normal", 2: "normal"})
	var res3: Dictionary = unravel_resolver.play_attack(deck_area, party, enemies_area,
		"tinker_shrapnel_seam", 0, unravel_area)
	_check(res3.get("ok", false) == true, "AC4: area attack succeeds")
	_check(res3["hits"][0]["damage"] == 8 and res3["hits"][1]["damage"] == 8,
		"AC4: every Shrapnel recipient receives the first-attack bonus (5 + 3 = 8)")
	_check(shared_first._consumed == true, "AC4: area attack consumed latch once")

	# Compact invalid case set with full pre/post snapshots
	_test_rejection_snapshots()


func _test_rejection_snapshots() -> void:
	var first: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	var resolver: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first)

	var run_case: Callable = func(card_id: String, target: int, mutator: Callable, reason: String) -> void:
		var d: CombatDeck = _deck(["tinker_spool_launcher", "tinker_shrapnel_seam", "tinker_snip_the_seam"])
		var p: CombatParty = _party(["warden", "seamstress", "tinker"])
		var e: CombatEnemies = _enemies([30, 30])
		var u: CombatUnravel = _unravel(e, {1: "normal", 2: "normal"})
		var active_u: CombatUnravel = u
		var override_u: Variant = mutator.call(d, p, e, u)
		if override_u != null and override_u is CombatUnravel:
			active_u = override_u

		var before: Dictionary = _snapshot(d, p, e, u, first)
		var result: Dictionary = resolver.play_attack(d, p, e, card_id, target, active_u)
		_check(result == {"ok": false, "hits": []}, "AC4: " + reason + " must reject")
		_check(_snapshot(d, p, e, u, first) == before,
			"AC4: " + reason + " preserves full deck, party, enemy, gauge, latch and RNG snapshots")

	# 1. Missing held copy
	run_case.call("tinker_spool_launcher_plus", 1, func(d, p, e, u): pass, "missing held copy")

	# 2. Insufficient energy
	run_case.call("tinker_shrapnel_seam", 0, func(d, p, e, u): d.combat_state.energy = 1, "insufficient energy (cost 2, has 1)")

	# 3. Inactive turn
	run_case.call("tinker_spool_launcher", 1, func(d, p, e, u): d.combat_state.player_turn_active = false, "inactive turn")

	# 4. Downed / 0 HP Tinker
	run_case.call("tinker_spool_launcher", 1, func(d, p, e, u):
		p.apply_damage(3, 26)
	, "downed Tinker")

	# 5. Wrong-slot Tinker (Tinker at slot 1 for Spool Launcher which is FROM [2, 3])
	run_case.call("tinker_spool_launcher", 1, func(d, p, e, u):
		p._heroes[0]["id"] = "tinker"
		p._heroes[2]["id"] = "warden"
	, "wrong-slot Tinker at slot 1")

	# 6. Wrong-slot Tinker for Shrapnel Seam (Tinker at slot 2 for Shrapnel Seam which is FROM [3] only)
	run_case.call("tinker_shrapnel_seam", 0, func(d, p, e, u):
		p._heroes[1]["id"] = "tinker"
		p._heroes[2]["id"] = "seamstress"
	, "wrong-slot Tinker at slot 2 for Shrapnel Seam")

	# 7. Wrong target for single attack (target 0 for Spool Launcher)
	run_case.call("tinker_spool_launcher", 0, func(d, p, e, u): pass, "target 0 for single attack")

	# 8. Wrong target for area attack (target 1 for Shrapnel Seam)
	run_case.call("tinker_shrapnel_seam", 1, func(d, p, e, u): pass, "target 1 for area attack")

	# 9. Out of range target (target 4)
	run_case.call("tinker_spool_launcher", 4, func(d, p, e, u): pass, "out-of-range target 4")

	# 10. Slain target (target 2 when slain)
	run_case.call("tinker_spool_launcher", 2, func(d, p, e, u):
		e.apply_damage(2, 30)
	, "slain target")

	# 11. All-dead roster
	run_case.call("tinker_shrapnel_seam", 0, func(d, p, e, u):
		e.apply_damage(1, 30)
		e.apply_damage(2, 30)
	, "all-dead roster")

	# 12. Unbound CombatUnravel
	run_case.call("tinker_spool_launcher", 1, func(d, p, e, u):
		return CombatUnravel.new()
	, "unbound CombatUnravel")

	# 13. Wrong-roster CombatUnravel
	run_case.call("tinker_spool_launcher", 1, func(d, p, e, u):
		var other_e: CombatEnemies = _enemies([50])
		var other_u: CombatUnravel = _unravel(other_e, {1: "normal"})
		return other_u
	, "wrong-roster CombatUnravel")


func _test_ac4_replay() -> void:
	# One equal-seed replay case verifying determinism
	var run_trial: Callable = func(seed_val: int) -> Dictionary:
		var first: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
		var resolver: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first)
		var deck: CombatDeck = _deck(["tinker_spool_launcher", "tinker_shrapnel_seam", "tinker_snip_the_seam"], seed_val)
		var party: CombatParty = _party(["warden", "seamstress", "tinker"])
		var enemies: CombatEnemies = _enemies([30, 30])
		var unravel: CombatUnravel = _unravel(enemies, {1: "normal", 2: "normal"})

		var r1: Dictionary = resolver.play_attack(deck, party, enemies, "tinker_spool_launcher", 1, unravel)
		deck.combat_state.energy = 3
		var r2: Dictionary = resolver.play_attack(deck, party, enemies, "tinker_snip_the_seam", 1, unravel)

		return {
			"res1": r1,
			"res2": r2,
			"snap": _snapshot(deck, party, enemies, unravel, first),
		}

	var trial_a: Dictionary = run_trial.call(12345)
	var trial_b: Dictionary = run_trial.call(12345)
	_check(trial_a == trial_b, "AC4: identical seed yields identical results, snapshots and RNG state")
