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
	_test_pinned_ac1_spool_and_snip()
	_test_pinned_ac2_shrapnel_seam()
	_test_pinned_ac3_rejections()
	_test_patch_damage_all_six()
	_test_patch_button_eye()
	_test_patch_suppression_and_rejections()
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
		unravel: CombatUnravel, first: CombatTinkerFirstAttack, pinned: CombatPinned = null) -> Dictionary:
	var gauges: Dictionary = {}
	for i: int in range(enemies.get_enemies().size()):
		var pos: int = i + 1
		gauges[pos] = unravel.get_snapshot(pos)
	var pins: Dictionary = {}
	if pinned != null:
		pins = pinned._pinner_by_position.duplicate()
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
		"pins": pins,
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


func _test_pinned_ac1_spool_and_snip() -> void:
	# 1. Spool Launcher base with Warden pin: cost 1, damage 3, unravel 3.
	# First attack latch active (+3). Pin bonus (+5). Raw damage 3 + 3 + 5 = 11.
	var first: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	var pinned: CombatPinned = CombatPinned.new()
	var resolver: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first, pinned)
	_check(resolver.get_pinned() == pinned, "AC1: get_pinned returns bound CombatPinned")
	var deck: CombatDeck = _deck(["tinker_spool_launcher", "warden_strike"])
	var party: CombatParty = _party(["warden", "seamstress", "tinker"])
	var enemies: CombatEnemies = _enemies([50, 50])
	var unravel: CombatUnravel = _unravel(enemies, {1: "normal", 2: "normal"})
	_check(pinned.pin_enemy(enemies, 1, "warden"), "Warden pins enemy 1")
	_check(enemies.gain_block(1, 4), "enemy 1 gains 4 Block")

	var before_rng: int = deck._rng.state

	var res: Dictionary = resolver.play_attack(deck, party, enemies, "tinker_spool_launcher", 1, unravel)
	_check(res.get("ok", false) == true, "AC1: Spool Launcher on Warden-pinned target succeeds")
	_check(res.get("hits", []).size() == 1, "AC1: produces 1 hit")
	var hit: Dictionary = res["hits"][0]
	_check(hit.get("position") == 1 and hit.get("damage") == 11
		and hit.get("block_absorbed") == 4 and hit.get("hp_loss") == 7
		and hit.get("unravel") == 3,
		"AC1: Spool Launcher hit deals 11 damage (3 base + 3 first + 5 pin), 4 absorbed, 7 HP loss, 3 unravel")
	_check(enemies.get_enemy(1)["hp"] == 43 and enemies.get_enemy(1)["block"] == 0,
		"AC1: enemy 1 HP (43) and Block (0) updated authoritatively")
	_check(unravel.get_snapshot(1)["gauge"] == 3 and unravel.get_snapshot(1)["threshold"] == 8,
		"AC1: enemy 1 gauge 3/8")
	_check(pinned.pinner_for_enemy(1) == "", "AC1: Warden pin on enemy 1 consumed once")
	_check(deck.energy == 2 and deck.hand == ["warden_strike"]
		and deck.discard_pile == ["tinker_spool_launcher"],
		"AC1: spends 1 energy and discards held Spool Launcher")
	_check(first._consumed == true, "AC1: first attack latch consumed")
	_check(deck._rng.state == before_rng, "AC1: zero RNG draws")

	# 2. Spool Launcher+ with Seamstress pin and consumed first-attack latch (base 4 + pin 5 = 9)
	var first_plus: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	_check(first_plus.record_successful_attack("tinker_pop_shot"), "consume first attack latch")
	var pinned_plus: CombatPinned = CombatPinned.new()
	var resolver_plus: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first_plus, pinned_plus)
	var deck_plus: CombatDeck = _deck(["tinker_spool_launcher_plus"])
	var party_plus: CombatParty = _party(["warden", "tinker", "seamstress"])
	var enemies_plus: CombatEnemies = _enemies([30])
	var unravel_plus: CombatUnravel = _unravel(enemies_plus, {1: "normal"})
	_check(pinned_plus.pin_enemy(enemies_plus, 1, "seamstress"), "Seamstress pins enemy 1")
	var rng_plus_before: int = deck_plus._rng.state

	var res_plus: Dictionary = resolver_plus.play_attack(deck_plus, party_plus, enemies_plus,
		"tinker_spool_launcher_plus", 1, unravel_plus)
	_check(res_plus.get("ok", false) == true, "AC1: Spool Launcher+ play succeeds from slot 2")
	var hit_plus: Dictionary = res_plus["hits"][0]
	_check(hit_plus.get("damage") == 9 and hit_plus.get("hp_loss") == 9 and hit_plus.get("unravel") == 4,
		"AC1: Spool Launcher+ deals 9 damage (4 base + 5 pin) and adds 4 unravel")
	_check(enemies_plus.get_enemy(1)["hp"] == 21, "AC1: enemy 1 HP reduced to 21")
	_check(unravel_plus.get_snapshot(1)["gauge"] == 4, "AC1: gauge incremented by 4")
	_check(pinned_plus.pinner_for_enemy(1) == "", "AC1: Seamstress pin consumed once")
	_check(deck_plus._rng.state == rng_plus_before, "AC1: zero RNG draws on Spool+")

	# 3. Lethal hit on pinned enemy: consumes pin, 0 unravel applied
	var first_lethal: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	_check(first_lethal.record_successful_attack("tinker_pop_shot"), "consume latch")
	var pinned_lethal: CombatPinned = CombatPinned.new()
	var resolver_lethal: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first_lethal, pinned_lethal)
	var deck_lethal: CombatDeck = _deck(["tinker_spool_launcher"])
	var party_lethal: CombatParty = _party()
	var enemies_lethal: CombatEnemies = _enemies([6])
	var unravel_lethal: CombatUnravel = _unravel(enemies_lethal, {1: "normal"})
	_check(pinned_lethal.pin_enemy(enemies_lethal, 1, "warden"), "Warden pins enemy 1")

	var res_lethal: Dictionary = resolver_lethal.play_attack(deck_lethal, party_lethal, enemies_lethal,
		"tinker_spool_launcher", 1, unravel_lethal)
	_check(res_lethal.get("ok", false) == true, "AC1: lethal Spool hit succeeds")
	_check(enemies_lethal.is_slain(1), "AC1: target is slain")
	_check(pinned_lethal.pinner_for_enemy(1) == "", "AC1: pin consumed on lethal hit")
	_check(res_lethal["hits"][0]["unravel"] == 0, "AC1: lethal hit reports 0 unravel")
	_check(unravel_lethal.get_snapshot(1)["gauge"] == 0, "AC1: slain target gauge remains 0")

	# 4. Same-hero pin: Tinker attacks own pin -> 0 bonus and leaves pin in place
	var first_same: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	_check(first_same.record_successful_attack("tinker_pop_shot"), "consume latch")
	var pinned_same: CombatPinned = CombatPinned.new()
	var resolver_same: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first_same, pinned_same)
	var deck_same: CombatDeck = _deck(["tinker_spool_launcher"])
	var party_same: CombatParty = _party()
	var enemies_same: CombatEnemies = _enemies([30])
	var unravel_same: CombatUnravel = _unravel(enemies_same, {1: "normal"})
	_check(pinned_same.pin_enemy(enemies_same, 1, "tinker"), "Tinker pins enemy 1")

	var res_same: Dictionary = resolver_same.play_attack(deck_same, party_same, enemies_same,
		"tinker_spool_launcher", 1, unravel_same)
	_check(res_same.get("ok", false) == true, "AC1: same-hero pin attack succeeds")
	_check(res_same["hits"][0]["damage"] == 3, "AC1: same-hero pin grants 0 bonus (deals base 3)")
	_check(pinned_same.pinner_for_enemy(1) == "tinker", "AC1: same-hero pin is NOT consumed")

	# 5. Snip the Seam base unempowered with Warden pin: base 5 + 5 pin = 10 damage
	var first_snip1: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	_check(first_snip1.record_successful_attack("tinker_pop_shot"), "consume latch")
	var pinned_snip1: CombatPinned = CombatPinned.new()
	var resolver_snip1: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first_snip1, pinned_snip1)
	var deck_snip1: CombatDeck = _deck(["tinker_snip_the_seam"])
	var party_snip1: CombatParty = _party()
	var enemies_snip1: CombatEnemies = _enemies([40])
	var unravel_snip1: CombatUnravel = _unravel(enemies_snip1, {1: "normal"})
	_check(unravel_snip1.apply_unravel(enemies_snip1, 1, 3), "gauge 3/8 is below half")
	_check(pinned_snip1.pin_enemy(enemies_snip1, 1, "warden"), "Warden pins enemy 1")

	var res_snip1: Dictionary = resolver_snip1.play_attack(deck_snip1, party_snip1, enemies_snip1,
		"tinker_snip_the_seam", 1, unravel_snip1)
	_check(res_snip1.get("ok", false) == true, "AC1: unempowered Snip with pin succeeds")
	_check(res_snip1["hits"][0]["damage"] == 10, "AC1: unempowered Snip deals 10 damage (5 base + 5 pin)")
	_check(pinned_snip1.pinner_for_enemy(1) == "", "AC1: pin consumed")
	_check(unravel_snip1.get_snapshot(1)["gauge"] == 3, "AC1: Snip leaves gauge untouched at 3/8")

	# 6. Snip the Seam base empowered with Seamstress pin: base 15 + first 3 + pin 5 = 23
	var first_snip2: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	var pinned_snip2: CombatPinned = CombatPinned.new()
	var resolver_snip2: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first_snip2, pinned_snip2)
	var deck_snip2: CombatDeck = _deck(["tinker_snip_the_seam"])
	var party_snip2: CombatParty = _party()
	var enemies_snip2: CombatEnemies = _enemies([50])
	var unravel_snip2: CombatUnravel = _unravel(enemies_snip2, {1: "normal"})
	_check(unravel_snip2.apply_unravel(enemies_snip2, 1, 4), "gauge 4/8 triggers empowered")
	_check(pinned_snip2.pin_enemy(enemies_snip2, 1, "seamstress"), "Seamstress pins enemy 1")

	var res_snip2: Dictionary = resolver_snip2.play_attack(deck_snip2, party_snip2, enemies_snip2,
		"tinker_snip_the_seam", 1, unravel_snip2)
	_check(res_snip2.get("ok", false) == true, "AC1: empowered Snip with pin succeeds")
	_check(res_snip2["hits"][0]["damage"] == 23,
		"AC1: empowered Snip deals 23 damage (15 empowered + 3 first + 5 pin)")
	_check(pinned_snip2.pinner_for_enemy(1) == "", "AC1: Seamstress pin consumed")
	_check(unravel_snip2.get_snapshot(1)["gauge"] == 4, "AC1: gauge remains 4/8")

	# 7. Snip the Seam empowered with Weak, Exposed and Block:
	# Raw damage before status: 15 (empowered) + 5 (pin) = 20.
	# Weak reduces by 25%: 20 * 0.75 = 15.
	# Exposed increases by 50%: 15 * 1.5 = 22.5 -> floor = 22.
	# Block 6 absorbs 6, HP loss = 16 (60 -> 44).
	var first_calc: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	_check(first_calc.record_successful_attack("tinker_pop_shot"), "consume latch")
	var pinned_calc: CombatPinned = CombatPinned.new()
	var resolver_calc: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first_calc, pinned_calc)
	var deck_calc: CombatDeck = _deck(["tinker_snip_the_seam"])
	var party_calc: CombatParty = _party()
	party_calc._heroes[2]["statuses"] = {"weak": 1}
	var enemies_calc: CombatEnemies = _enemies([60])
	_check(enemies_calc.apply_statuses({1: {"exposed": 1}}), "enemy 1 exposed")
	_check(enemies_calc.gain_block(1, 6), "enemy 1 gains 6 Block")
	var unravel_calc: CombatUnravel = _unravel(enemies_calc, {1: "normal"})
	_check(unravel_calc.apply_unravel(enemies_calc, 1, 4), "gauge 4/8 empowered")
	_check(pinned_calc.pin_enemy(enemies_calc, 1, "warden"), "Warden pins enemy 1")

	var res_calc: Dictionary = resolver_calc.play_attack(deck_calc, party_calc, enemies_calc,
		"tinker_snip_the_seam", 1, unravel_calc)
	_check(res_calc.get("ok", false) == true, "AC1: calculation test succeeds")
	var h_calc: Dictionary = res_calc["hits"][0]
	_check(h_calc.get("damage") == 22 and h_calc.get("block_absorbed") == 6 and h_calc.get("hp_loss") == 16,
		"AC1: +5 pin applied before Weak/Exposed gives floor(floor(20*0.75)*1.5)=22 damage, 6 absorbed, 16 HP loss")
	_check(enemies_calc.get_enemy(1)["hp"] == 44 and enemies_calc.get_enemy(1)["block"] == 0,
		"AC1: enemy HP (44) and Block (0) updated")
	_check(pinned_calc.pinner_for_enemy(1) == "", "AC1: pin consumed")

	# 8. Snip the Seam+ empowered with Warden pin: base 20 + pin 5 = 25
	var first_snip_p: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	_check(first_snip_p.record_successful_attack("tinker_pop_shot"), "consume latch")
	var pinned_snip_p: CombatPinned = CombatPinned.new()
	var resolver_snip_p: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first_snip_p, pinned_snip_p)
	var deck_snip_p: CombatDeck = _deck(["tinker_snip_the_seam_plus"])
	var party_snip_p: CombatParty = _party()
	var enemies_snip_p: CombatEnemies = _enemies([60])
	var unravel_snip_p: CombatUnravel = _unravel(enemies_snip_p, {1: "normal"})
	_check(unravel_snip_p.apply_unravel(enemies_snip_p, 1, 4), "gauge 4/8 empowered")
	_check(pinned_snip_p.pin_enemy(enemies_snip_p, 1, "warden"), "Warden pins enemy 1")

	var res_snip_p: Dictionary = resolver_snip_p.play_attack(deck_snip_p, party_snip_p, enemies_snip_p,
		"tinker_snip_the_seam_plus", 1, unravel_snip_p)
	_check(res_snip_p.get("ok", false) == true, "AC1: empowered Snip+ succeeds")
	_check(res_snip_p["hits"][0]["damage"] == 25, "AC1: empowered Snip+ deals 25 damage (20 base + 5 pin)")
	_check(pinned_snip_p.pinner_for_enemy(1) == "", "AC1: pin consumed once")


func _test_pinned_ac2_shrapnel_seam() -> void:
	# 1. Shrapnel Seam base: cost 2, damage 5, unravel 2.
	# Tinker at position 3. Living enemies in 3-enemy roster:
	# - Slot 1: pinned by Warden (different hero) -> +5 bonus, pin consumed
	# - Slot 2: pinned by Tinker (same hero) -> 0 bonus, pin preserved
	# - Slot 3: unpinned -> 0 bonus, remains unpinned
	# First attack latch active (+3) applies to all hits.
	var first: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	var pinned: CombatPinned = CombatPinned.new()
	var resolver: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first, pinned)
	var deck: CombatDeck = _deck(["tinker_shrapnel_seam", "warden_strike"])
	var party: CombatParty = _party(["warden", "seamstress", "tinker"])
	var enemies: CombatEnemies = _enemies([40, 40, 40])
	var unravel: CombatUnravel = _unravel(enemies, {1: "normal", 2: "normal", 3: "normal"})
	_check(pinned.pin_enemy(enemies, 1, "warden"), "pin enemy 1 by warden")
	_check(pinned.pin_enemy(enemies, 2, "tinker"), "pin enemy 2 by tinker")

	var before_rng: int = deck._rng.state
	var res: Dictionary = resolver.play_attack(deck, party, enemies, "tinker_shrapnel_seam", 0, unravel)
	_check(res.get("ok", false) == true, "AC2: Shrapnel Seam succeeds")
	_check(res.get("hits", []).size() == 3, "AC2: exactly hits living slots 1, 2, 3")

	var h1: Dictionary = res["hits"][0]
	var h2: Dictionary = res["hits"][1]
	var h3: Dictionary = res["hits"][2]
	# Slot 1: 5 base + 3 first + 5 warden pin = 13
	_check(h1.get("position") == 1 and h1.get("damage") == 13 and h1.get("unravel") == 2,
		"AC2: slot 1 (warden pin) receives 13 damage and 2 unravel")
	# Slot 2: 5 base + 3 first + 0 tinker pin = 8
	_check(h2.get("position") == 2 and h2.get("damage") == 8 and h2.get("unravel") == 2,
		"AC2: slot 2 (tinker pin) receives 8 damage and 2 unravel")
	# Slot 3: 5 base + 3 first + 0 unpinned = 8
	_check(h3.get("position") == 3 and h3.get("damage") == 8 and h3.get("unravel") == 2,
		"AC2: slot 3 (unpinned) receives 8 damage and 2 unravel")

	_check(enemies.get_enemy(1)["hp"] == 27 and enemies.get_enemy(2)["hp"] == 32
		and enemies.get_enemy(3)["hp"] == 32, "AC2: living enemy HPs updated correctly")

	_check(unravel.get_snapshot(1)["gauge"] == 2 and unravel.get_snapshot(2)["gauge"] == 2
		and unravel.get_snapshot(3)["gauge"] == 2, "AC2: surviving enemies receive 2 unravel")

	_check(pinned.pinner_for_enemy(1) == "", "AC2: slot 1 Warden pin consumed")
	_check(pinned.pinner_for_enemy(2) == "tinker", "AC2: slot 2 Tinker pin preserved")
	_check(pinned.pinner_for_enemy(3) == "", "AC2: slot 3 unpinned remains unpinned")

	_check(deck.energy == 1 and deck.hand == ["warden_strike"]
		and deck.discard_pile == ["tinker_shrapnel_seam"],
		"AC2: single 2-energy charge and single discard")
	_check(first._consumed == true, "AC2: latch consumed once for area attack")
	_check(deck._rng.state == before_rng, "AC2: zero RNG draws")

	# 2. Shrapnel Seam with slain slot 2: slot 1 (Seamstress pin) and slot 3 (Tinker pin)
	var first_slain: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	var pinned_slain: CombatPinned = CombatPinned.new()
	var resolver_slain: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first_slain, pinned_slain)
	var deck_slain: CombatDeck = _deck(["tinker_shrapnel_seam"])
	var party_slain: CombatParty = _party(["warden", "seamstress", "tinker"])
	var enemies_slain: CombatEnemies = _enemies([40, 20, 40])
	var unravel_slain: CombatUnravel = _unravel(enemies_slain, {1: "normal", 2: "normal", 3: "normal"})
	_check(pinned_slain.pin_enemy(enemies_slain, 1, "seamstress"), "pin 1 by seamstress")
	_check(pinned_slain.pin_enemy(enemies_slain, 3, "tinker"), "pin 3 by tinker")
	_check(enemies_slain.apply_damage(2, 20) and enemies_slain.is_slain(2), "slay slot 2")

	var res_slain: Dictionary = resolver_slain.play_attack(deck_slain, party_slain, enemies_slain,
		"tinker_shrapnel_seam", 0, unravel_slain)
	_check(res_slain.get("ok", false) == true, "AC2: Shrapnel Seam with slain slot succeeds")
	_check(res_slain.get("hits", []).size() == 2, "AC2: hits exactly surviving slots 1 and 3")
	_check(res_slain["hits"][0]["position"] == 1 and res_slain["hits"][0]["damage"] == 13,
		"AC2: slot 1 (seamstress pin) receives 13 damage")
	_check(res_slain["hits"][1]["position"] == 3 and res_slain["hits"][1]["damage"] == 8,
		"AC2: slot 3 (tinker pin) receives 8 damage")
	_check(enemies_slain.get_enemy(2)["hp"] == 0 and enemies_slain.is_slain(2),
		"AC2: slain slot 2 remains untouched")
	_check(unravel_slain.get_snapshot(2)["gauge"] == 0, "AC2: slain slot 2 gauge untouched")
	_check(pinned_slain.pinner_for_enemy(1) == "", "AC2: slot 1 Seamstress pin consumed")
	_check(pinned_slain.pinner_for_enemy(3) == "tinker", "AC2: slot 3 Tinker pin preserved")

	# 2. Shrapnel Seam+ with multiple cross-hero pins (Seamstress and Warden)
	var first_plus: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	_check(first_plus.record_successful_attack("tinker_pop_shot"), "consume latch")
	var pinned_plus: CombatPinned = CombatPinned.new()
	var resolver_plus: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first_plus, pinned_plus)
	var deck_plus: CombatDeck = _deck(["tinker_shrapnel_seam_plus"])
	var party_plus: CombatParty = _party(["warden", "seamstress", "tinker"])
	var enemies_plus: CombatEnemies = _enemies([50, 50, 50])
	var unravel_plus: CombatUnravel = _unravel(enemies_plus, {1: "normal", 2: "elite", 3: "normal"})
	_check(pinned_plus.pin_enemy(enemies_plus, 1, "seamstress"), "pin 1 by seamstress")
	_check(pinned_plus.pin_enemy(enemies_plus, 2, "warden"), "pin 2 by warden")

	var res_plus: Dictionary = resolver_plus.play_attack(deck_plus, party_plus, enemies_plus,
		"tinker_shrapnel_seam_plus", 0, unravel_plus)
	_check(res_plus.get("ok", false) == true, "AC2: Shrapnel+ succeeds")
	_check(res_plus.get("hits", []).size() == 3, "AC2: hits 3 enemies")
	_check(res_plus["hits"][0]["damage"] == 12 and res_plus["hits"][0]["unravel"] == 3,
		"AC2: slot 1 (seamstress pin) deals 12 (7 base + 5 pin)")
	_check(res_plus["hits"][1]["damage"] == 12 and res_plus["hits"][1]["unravel"] == 3,
		"AC2: slot 2 (warden pin) deals 12 (7 base + 5 pin)")
	_check(res_plus["hits"][2]["damage"] == 7 and res_plus["hits"][2]["unravel"] == 3,
		"AC2: slot 3 (unpinned) deals 7 base")
	_check(pinned_plus.pinner_for_enemy(1) == "" and pinned_plus.pinner_for_enemy(2) == "",
		"AC2: both cross-hero pins consumed")
	_check(deck_plus.energy == 1 and deck_plus.discard_pile == ["tinker_shrapnel_seam_plus"],
		"AC2: 2 energy spent, 1 discard")


func _test_pinned_ac3_rejections() -> void:
	# 1. Resolver without CombatPinned bound: legacy behavior unchanged
	var first_leg: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	var resolver_leg: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first_leg)
	_check(resolver_leg.get_pinned() == null, "AC3: get_pinned returns null when unbound")
	var deck_leg: CombatDeck = _deck(["tinker_spool_launcher"])
	var party_leg: CombatParty = _party()
	var enemies_leg: CombatEnemies = _enemies([30])
	var unravel_leg: CombatUnravel = _unravel(enemies_leg, {1: "normal"})
	var res_leg: Dictionary = resolver_leg.play_attack(deck_leg, party_leg, enemies_leg,
		"tinker_spool_launcher", 1, unravel_leg)
	_check(res_leg.get("ok", false) == true and res_leg["hits"][0]["damage"] == 6,
		"AC3: unbound resolver deals legacy 6 damage (3 base + 3 first)")

	# 2. Comprehensive fail-closed snapshot tests with active CombatPinned tokens
	var first_rej: CombatTinkerFirstAttack = CombatTinkerFirstAttack.new()
	var pinned_rej: CombatPinned = CombatPinned.new()
	var resolver_rej: CombatTinkerPoolUnravelAttacks = CombatTinkerPoolUnravelAttacks.new(first_rej, pinned_rej)

	var run_rej_case: Callable = func(card_id: String, target: int, mutator: Callable, reason: String) -> void:
		var d: CombatDeck = _deck(["tinker_spool_launcher", "tinker_shrapnel_seam", "tinker_snip_the_seam"])
		var p: CombatParty = _party(["warden", "seamstress", "tinker"])
		var e: CombatEnemies = _enemies([30, 30])
		var u: CombatUnravel = _unravel(e, {1: "normal", 2: "normal"})
		_check(pinned_rej.pin_enemy(e, 1, "warden"), "pre-pin enemy 1 by warden")
		_check(pinned_rej.pin_enemy(e, 2, "tinker"), "pre-pin enemy 2 by tinker")
		var active_u: CombatUnravel = u
		var override_u: Variant = mutator.call(d, p, e, u)
		if override_u != null and override_u is CombatUnravel:
			active_u = override_u

		var before: Dictionary = _snapshot(d, p, e, u, first_rej, pinned_rej)
		_check(resolver_rej.can_play(d, p, e, card_id, target, active_u, pinned_rej) == false,
			"AC3: can_play rejects " + reason)
		var result: Dictionary = resolver_rej.play_attack(d, p, e, card_id, target, active_u, pinned_rej)
		_check(result == {"ok": false, "hits": []}, "AC3: play_attack rejects " + reason)
		_check(_snapshot(d, p, e, u, first_rej, pinned_rej) == before,
			"AC3: " + reason + " preserves full deck, party, enemy, gauge, latch, pin and RNG snapshots")
		_check(pinned_rej.pinner_for_enemy(1) == "warden" and pinned_rej.pinner_for_enemy(2) == "tinker",
			"AC3: pins remain intact after rejection " + reason)

	# Negative cases with pinned state:
	run_rej_case.call("tinker_spool_launcher_plus", 1, func(d, p, e, u): pass, "missing held copy")
	run_rej_case.call("tinker_shrapnel_seam", 0, func(d, p, e, u): d.combat_state.energy = 1, "insufficient energy")
	run_rej_case.call("tinker_spool_launcher", 1, func(d, p, e, u): d.combat_state.player_turn_active = false, "inactive turn")
	run_rej_case.call("tinker_spool_launcher", 1, func(d, p, e, u): p.apply_damage(3, 26), "downed Tinker")
	run_rej_case.call("tinker_spool_launcher", 1, func(d, p, e, u):
		p._heroes[0]["id"] = "tinker"
		p._heroes[2]["id"] = "warden"
	, "wrong-slot Tinker at slot 1")
	run_rej_case.call("tinker_spool_launcher", 0, func(d, p, e, u): pass, "target 0 for single attack")
	run_rej_case.call("tinker_shrapnel_seam", 1, func(d, p, e, u): pass, "target 1 for area attack")
	run_rej_case.call("tinker_spool_launcher", 2, func(d, p, e, u): e.apply_damage(2, 30), "slain target")
	run_rej_case.call("tinker_shrapnel_seam", 0, func(d, p, e, u):
		e.apply_damage(1, 30)
		e.apply_damage(2, 30)
	, "all-dead roster")
	run_rej_case.call("tinker_spool_launcher", 1, func(d, p, e, u): return CombatUnravel.new(), "unbound unravel")


## Real run ledger fixture: creates, owns and sews both authored patches.
## A separate run Torn/Mending record supplies the combat-only projection.
func _patch_fixture(arm_owner: String = "tinker", head_owner: String = "",
		torn_tinker: bool = false) -> Dictionary:
	var heroes: Array[Dictionary] = _party().get_heroes()
	var torn := RunTornMending.new(heroes)
	_check(torn.is_valid(), "patch fixture authentic valid Torn/Mending ledger")
	if torn_tinker:
		var ending: Array = heroes.duplicate(true)
		ending[2]["hp"] = 0
		var result: Dictionary = torn.observe_battle_end("patch_fixture_battle", heroes, ending)
		_check(result.get("ok") == true and torn.read_state()["heroes"][2]["hp"] == 0,
			"torn fixture really records Tinker as downed")
	var owned: Array = ["pincushion_arm", "button_eye"]
	var wardrobe := RunPatchWardrobe.new(heroes, owned, [
		{"id": "pincushion_arm", "slot": "ARM"},
		{"id": "button_eye", "slot": "HEAD"}], 0)
	_check(wardrobe.is_valid(), "patch fixture authentic valid wardrobe")
	if arm_owner != "":
		_check(wardrobe.sew("pincushion_arm", arm_owner, "ARM", "sew_arm",
			wardrobe.get_snapshot()).get("ok") == true,
			"pincushion actually sewn to " + arm_owner)
	if head_owner != "":
		_check(wardrobe.sew("button_eye", head_owner, "HEAD", "sew_head",
			wardrobe.get_snapshot()).get("ok") == true,
			"button eye actually sewn to " + head_owner)
	var projection: Dictionary = wardrobe.project_active(torn.read_state())
	_check(projection.get("ok") == true and projection["active"].has("tinker"),
		"wardrobe authentic wearer projection")
	return {"wardrobe": wardrobe, "torn": torn}


func _patch_snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		unravel: CombatUnravel, first: CombatTinkerFirstAttack,
		pinned: CombatPinned, resolver: CombatTinkerPoolUnravelAttacks) -> Dictionary:
	var state: Dictionary = _snapshot(deck, party, enemies, unravel, first, pinned)
	state["patch_latch"] = {} if resolver._patches == null else resolver._patches.latch_snapshot()
	state["patch_active"] = {} if resolver._patches == null else resolver._patches.active_snapshot()
	return state


func _test_patch_damage_all_six() -> void:
	var expected := {
		"tinker_spool_launcher": [3, 3, 1],
		"tinker_spool_launcher_plus": [4, 4, 1],
		"tinker_shrapnel_seam": [5, 2, 2],
		"tinker_shrapnel_seam_plus": [7, 3, 2],
		"tinker_snip_the_seam": [5, 0, 1],
		"tinker_snip_the_seam_plus": [7, 0, 1],
	}
	var catalog := TinkerPoolCards.new()
	for card_id in expected:
		var spec: Array = expected[card_id]
		var def: Dictionary = catalog.get_definition(card_id)
		_check(not def.is_empty() and def.get("cost") == spec[2]
			and def.get("effects", {}).get("damage") == spec[0],
			"AC1: six real catalog definitions and costs: " + card_id)
		var first := CombatTinkerFirstAttack.new()
		var pinned := CombatPinned.new()
		var resolver := CombatTinkerPoolUnravelAttacks.new(first, pinned)
		var fixture: Dictionary = _patch_fixture("tinker")
		_check(resolver.bind_patch_wardrobe(fixture["wardrobe"], fixture["torn"]),
			"AC1: bound genuine Pincushion " + card_id)
		_check(resolver._patches.damage_bonus("tinker") == 1,
			"AC1: Tinker is projected actual Pincushion wearer")
		var deck: CombatDeck = _deck([card_id, "warden_strike"])
		var party: CombatParty = _party()
		var enemies: CombatEnemies = _enemies([100, 100, 100])
		var unravel: CombatUnravel = _unravel(enemies)
		_check(enemies.gain_block(1, 2), "AC1: enemy 1 real Block 2")
		_check(pinned.pin_enemy(enemies, 1, "warden"), "AC1: foreign Warden pin")
		var before_rng: int = deck._rng.state
		_check(resolver.can_play(deck, party, enemies, card_id, 0 if spec[2] == 2 else 1, unravel),
			"AC1: patched card preflight succeeds " + card_id)
		var result: Dictionary = resolver.play_attack(deck, party, enemies, card_id,
			0 if spec[2] == 2 else 1, unravel)
		_check(result.get("ok") == true, "AC1: patched " + card_id + " plays")
		if result.get("ok") != true:
			continue
		var expected_hits: int = 3 if spec[2] == 2 else 1
		_check(result["hits"].size() == expected_hits,
			"AC1: original living slots hit once " + card_id)
		for i in range(expected_hits):
			var h: Dictionary = result["hits"][i]
			var damage: int = spec[0] + 3 + 1 + (5 if i == 0 else 0)
			var absorbed: int = 2 if i == 0 else 0
			_check(h == {"position": i + 1, "damage": damage, "block_absorbed": absorbed,
				"hp_loss": damage - absorbed, "statuses": {}, "unravel": spec[1]},
				"AC1: per-hit patch+first+pin/Block receipt " + card_id + " slot " + str(i+1))
			_check(enemies.get_enemy(i+1)["hp"] == 100 - damage + absorbed
				and enemies.get_enemy(i+1)["block"] == 0,
				"AC1: exact resulting HP/Block " + card_id + " slot " + str(i+1))
			_check(unravel.get_snapshot(i+1)["gauge"] == spec[1],
				"AC1: exact surviving Unravel gauge " + card_id + " slot " + str(i+1))
		_check(pinned.pinner_for_enemy(1) == "" and first._consumed,
			"AC1: foreign pin consumed and first-attack latch set " + card_id)
		_check(deck.energy == 3 - spec[2] and deck.hand == ["warden_strike"]
			and deck.discard_pile == [card_id] and deck._rng.state == before_rng,
			"AC1: exactly one cost/discard with no RNG draws " + card_id)
		_check(resolver._patches.latch_snapshot().get("tinker") == false,
			"AC1: no Button Eye means patch latch unused")

	# Empowered Snip is a separate conditional branch, preserved for both variants.
	for card_id in ["tinker_snip_the_seam", "tinker_snip_the_seam_plus"]:
		var first := CombatTinkerFirstAttack.new()
		var pinned := CombatPinned.new()
		var resolver := CombatTinkerPoolUnravelAttacks.new(first, pinned)
		var fixture: Dictionary = _patch_fixture()
		_check(resolver.bind_patch_wardrobe(fixture["wardrobe"], fixture["torn"]),
			"AC1: conditional Snip patch binding")
		var deck: CombatDeck = _deck([card_id])
		var party: CombatParty = _party()
		party._heroes[2]["statuses"] = {"weak": 1}
		var enemies: CombatEnemies = _enemies([80])
		_check(enemies.apply_statuses({1: {"exposed": 1}}), "AC1: real enemy Exposed")
		_check(enemies.gain_block(1, 6), "AC1: real enemy Block")
		var unravel: CombatUnravel = _unravel(enemies)
		_check(unravel.apply_unravel(enemies, 1, 4), "AC1: half threshold reached")
		_check(pinned.pin_enemy(enemies, 1, "seamstress"), "AC1: foreign pin")
		var raw: int = 15 if card_id == "tinker_snip_the_seam" else 20
		var total: int = raw + 3 + 1 + 5
		var final_damage: int = 27 if raw == 15 else 32
		_check(total == (24 if raw == 15 else 29),
			"AC1: independent pre-modifier conditional Snip damage+pin+patch")
		var result: Dictionary = resolver.play_attack(deck, party, enemies, card_id, 1, unravel)
		_check(result.get("ok") == true and result["hits"][0] == {
			"position": 1, "damage": final_damage, "block_absorbed": 6,
			"hp_loss": final_damage - 6, "statuses": {}, "unravel": 0},
			"AC1: empowered Snip pin+patch applied before Weak/Exposed " + card_id)
		_check(enemies.get_enemy(1)["hp"] == 86 - final_damage
			and unravel.get_snapshot(1)["gauge"] == 4,
			"AC1: exact empowered HP and unchanged Unravel " + card_id)


func _test_patch_button_eye() -> void:
	var catalog := TinkerPoolCards.new()
	for card_id in CombatTinkerPoolUnravelAttacks.SUPPORTED_CARD_IDS:
		var definition: Dictionary = catalog.get_definition(card_id)
		_check(not definition.is_empty(), "AC2: authentic Button Eye card definition " + card_id)
		var first := CombatTinkerFirstAttack.new()
		var resolver := CombatTinkerPoolUnravelAttacks.new(first)
		var fixture: Dictionary = _patch_fixture("", "tinker")
		_check(resolver.bind_patch_wardrobe(fixture["wardrobe"], fixture["torn"]),
			"AC2: real Button Eye projection bound")
		var deck: CombatDeck = _deck([card_id])
		var party: CombatParty = _party()
		var enemies: CombatEnemies = _enemies([75, 75])
		var unravel: CombatUnravel = _unravel(enemies)
		var is_area: bool = definition["target_kind"] == "enemy_all"
		var original_damage: int = definition["effects"]["damage"] + 3
		var before_rng: int = deck._rng.state
		var result: Dictionary = resolver.play_attack(deck, party, enemies, card_id,
			0 if is_area else 1, unravel)
		_check(result.get("ok") == true, "AC2: successful first patched " + card_id)
		if result.get("ok") != true:
			continue
		_check(result["hits"][0]["damage"] == original_damage
			and result["hits"][0]["statuses"] == {"exposed": 1},
			"AC2: no same-hit exposed damage boost; receipt exposes slot 1 " + card_id)
		_check(enemies.get_enemy(1).get("statuses", {}) == {"exposed": 1}
			and enemies.get_enemy(1)["hp"] == 75 - original_damage,
			"AC2: Exposed landed after hit " + card_id)
		if is_area:
			_check(result["hits"][1]["damage"] == original_damage
				and result["hits"][1]["statuses"] == {}
				and enemies.get_enemy(2).get("statuses", {}) == {},
				"AC2: same Shrapnel card cannot boost later recipient " + card_id)
		_check(resolver._patches.latch_snapshot()["tinker"] == true
			and first._consumed and deck._rng.state == before_rng
			and deck.energy == 3 - definition["cost"] and deck.discard_pile == [card_id],
			"AC2: patch and passive latches, single spend, no RNG " + card_id)

	# First original living slot (2) is selected although slot 1 was slain.
	# Two worn patches: Button Eye is independent from per-turn +3.
	var first := CombatTinkerFirstAttack.new()
	var resolver := CombatTinkerPoolUnravelAttacks.new(first)
	var both: Dictionary = _patch_fixture("tinker", "tinker")
	_check(resolver.bind_patch_wardrobe(both["wardrobe"], both["torn"]),
		"AC2: simultaneous two-slot binding")
	var deck: CombatDeck = _deck(["tinker_shrapnel_seam", "tinker_spool_launcher"])
	var party: CombatParty = _party()
	var enemies: CombatEnemies = _enemies([40, 40, 40])
	var unravel: CombatUnravel = _unravel(enemies)
	_check(enemies.apply_damage(1, 40) and enemies.is_slain(1),
		"AC2: initially slain original slot 1")
	_check(enemies.gain_block(2, 2), "AC2: living first slot 2 Block")
	var before_rng: int = deck._rng.state
	var first_result: Dictionary = resolver.play_attack(deck, party, enemies,
		"tinker_shrapnel_seam", 0, unravel)
	_check(first_result.get("ok") == true and first_result["hits"].size() == 2,
		"AC2: first Shrapnel with dead original slot")
	_check(first_result["hits"][0] == {"position": 2, "damage": 9,
		"block_absorbed": 2, "hp_loss": 7, "statuses": {"exposed": 1}, "unravel": 2}
		and first_result["hits"][1] == {"position": 3, "damage": 9,
		"block_absorbed": 0, "hp_loss": 9, "statuses": {}, "unravel": 2},
		"AC2: both patches +3 first; Exposed applies only after whole area card")
	_check(enemies.get_enemy(1).get("statuses", {}) == {}
		and enemies.get_enemy(2).get("statuses", {}) == {"exposed": 1}
		and enemies.get_enemy(3).get("statuses", {}) == {},
		"AC2: Button Eye applied to original living slot 2, never dead slot 1")
	_check(enemies.get_enemy(2)["hp"] == 33 and enemies.get_enemy(3)["hp"] == 31,
		"AC2: exact first Shrapnel HP after Block")
	_check(resolver._patches.latch_snapshot()["tinker"] and first._consumed,
		"AC2: independent latches both set")
	# A later card in the same turn benefits from prior Exposed, but never reapplies it.
	var second: Dictionary = resolver.play_attack(deck, party, enemies,
		"tinker_spool_launcher", 2, unravel)
	_check(second.get("ok") == true and second["hits"] == [{"position": 2,
		"damage": 6, "block_absorbed": 0, "hp_loss": 6,
		"statuses": {}, "unravel": 3}],
		"AC2: next Spool gets +1 without +3, prior Exposed multiplies 4 into 6")
	_check(enemies.get_enemy(2)["hp"] == 27
		and enemies.get_enemy(2)["statuses"]["exposed"] == 1
		and unravel.get_snapshot(2)["gauge"] == 5
		and deck.energy == 0 and deck.hand.is_empty()
		and deck.discard_pile.size() == 2 and deck._rng.state == before_rng,
		"AC2: patch once per combat, energy/discard/gauge exact across two plays")

	# The patch has a combat latch independent of an already-spent turn passive.
	var prior_first := CombatTinkerFirstAttack.new()
	_check(prior_first.record_successful_attack("tinker_pop_shot"),
		"AC2: Tinker shared first-attack passive already spent")
	var prior_resolver := CombatTinkerPoolUnravelAttacks.new(prior_first)
	var prior_fixture: Dictionary = _patch_fixture("", "tinker")
	_check(prior_resolver.bind_patch_wardrobe(prior_fixture["wardrobe"], prior_fixture["torn"]),
		"AC2: bound Button Eye despite already consumed passive")
	var prior_deck: CombatDeck = _deck(["tinker_spool_launcher"])
	var prior_party: CombatParty = _party()
	var prior_enemies: CombatEnemies = _enemies([25])
	var prior_unravel: CombatUnravel = _unravel(prior_enemies)
	var prior_result: Dictionary = prior_resolver.play_attack(prior_deck, prior_party,
		prior_enemies, "tinker_spool_launcher", 1, prior_unravel)
	_check(prior_result.get("ok") == true and prior_result["hits"][0]["damage"] == 3
		and prior_result["hits"][0]["statuses"] == {"exposed": 1}
		and prior_resolver._patches.latch_snapshot()["tinker"],
		"AC2: Button Eye triggers independently when +3 passive unavailable")

	# First actual hit may be lethal; the defeated slot still records Exposed.
	var lethal_first := CombatTinkerFirstAttack.new()
	var lethal_resolver := CombatTinkerPoolUnravelAttacks.new(lethal_first)
	var lethal_fixture: Dictionary = _patch_fixture("", "tinker")
	_check(lethal_resolver.bind_patch_wardrobe(lethal_fixture["wardrobe"], lethal_fixture["torn"]),
		"AC2: lethal-case patch binding")
	var lethal_deck: CombatDeck = _deck(["tinker_shrapnel_seam"])
	var lethal_party: CombatParty = _party()
	var lethal_enemies: CombatEnemies = _enemies([10, 1, 30])
	var lethal_unravel: CombatUnravel = _unravel(lethal_enemies)
	_check(lethal_enemies.apply_damage(1, 10), "AC2: already dead slot 1")
	var lethal_result: Dictionary = lethal_resolver.play_attack(lethal_deck, lethal_party,
		lethal_enemies, "tinker_shrapnel_seam", 0, lethal_unravel)
	_check(lethal_result.get("ok") == true and lethal_result["hits"][0]["position"] == 2
		and lethal_result["hits"][0]["damage"] == 8
		and lethal_result["hits"][0]["statuses"] == {"exposed": 1}
		and lethal_result["hits"][0]["unravel"] == 0
		and lethal_result["hits"][1]["position"] == 3
		and lethal_result["hits"][1]["damage"] == 8
		and lethal_result["hits"][1]["statuses"] == {},
		"AC2: lethal first recipient, no same-card Exposed or dead-target Unravel")
	_check(lethal_enemies.is_slain(2)
		and lethal_enemies.get_enemy(2).get("statuses", {}) == {"exposed": 1}
		and lethal_enemies.get_enemy(3).get("statuses", {}) == {}
		and lethal_unravel.get_snapshot(3)["gauge"] == 2
		and lethal_resolver._patches.latch_snapshot()["tinker"],
		"AC2: late Exposed persists on lethal slot 2 and latches")


func _test_patch_suppression_and_rejections() -> void:
	# A patch sewn to another living hero is never a Tinker card bonus.
	for arm_owner in ["warden", "seamstress"]:
		var fixture: Dictionary = _patch_fixture(arm_owner, arm_owner if arm_owner == "warden" else "")
		var first := CombatTinkerFirstAttack.new()
		var resolver := CombatTinkerPoolUnravelAttacks.new(first)
		_check(resolver.bind_patch_wardrobe(fixture["wardrobe"], fixture["torn"]),
			"AC3: foreign patch wearer bound")
		_check(resolver._patches.damage_bonus("tinker") == 0
			and resolver._patches.exposed_for_first_hit("tinker") == {},
			"AC3: foreign owner's sewn patches do not project to Tinker")
		var deck: CombatDeck = _deck(["tinker_spool_launcher"])
		var party: CombatParty = _party()
		var enemies: CombatEnemies = _enemies([30])
		var unravel: CombatUnravel = _unravel(enemies)
		var result: Dictionary = resolver.play_attack(deck, party, enemies,
			"tinker_spool_launcher", 1, unravel)
		_check(result.get("ok") == true and result["hits"][0]["damage"] == 6
			and result["hits"][0]["statuses"] == {}
			and enemies.get_enemy(1).get("statuses", {}) == {}
			and resolver._patches.latch_snapshot()["tinker"] == false,
			"AC3: no borrowed Pincushion or Button Eye " + arm_owner)

	# Tinker is torn in the *run* ledger: even a sewn patch becomes inactive.
	# Combat party is a separate, valid newly mounted session with living Tinker.
	var torn_fixture: Dictionary = _patch_fixture("tinker", "tinker", true)
	var torn_resolver := CombatTinkerPoolUnravelAttacks.new()
	_check(torn_resolver.bind_patch_wardrobe(torn_fixture["wardrobe"], torn_fixture["torn"]),
		"AC3: torn-ledger projection still safely binds")
	_check(torn_resolver._patches.active_snapshot()["tinker"] == [],
		"AC3: sewn patches suppressed for downed run wearer")
	var torn_deck: CombatDeck = _deck(["tinker_spool_launcher"])
	var torn_party: CombatParty = _party()
	var torn_enemies: CombatEnemies = _enemies([30])
	var torn_unravel: CombatUnravel = _unravel(torn_enemies)
	var torn_result: Dictionary = torn_resolver.play_attack(torn_deck, torn_party,
		torn_enemies, "tinker_spool_launcher", 1, torn_unravel)
	_check(torn_result.get("ok") == true and torn_result["hits"][0]["damage"] == 6
		and torn_result["hits"][0]["statuses"] == {}
		and torn_resolver._patches.latch_snapshot()["tinker"] == false,
		"AC3: torn wearer cannot contribute either patch rider")

	# Failed explicit bind permanently fails closed until a new valid bind succeeds.
	var invalid := CombatTinkerPoolUnravelAttacks.new()
	var good: Dictionary = _patch_fixture("tinker", "tinker")
	_check(not invalid.bind_patch_wardrobe(good["wardrobe"], null),
		"AC3: explicit null Torn/Mending binding fails")
	var invalid_deck: CombatDeck = _deck(["tinker_spool_launcher"])
	var invalid_party: CombatParty = _party()
	var invalid_enemies: CombatEnemies = _enemies([30])
	var invalid_unravel: CombatUnravel = _unravel(invalid_enemies)
	var invalid_first: CombatTinkerFirstAttack = invalid.get_first_attack()
	var before_invalid: Dictionary = _patch_snapshot(invalid_deck, invalid_party, invalid_enemies,
		invalid_unravel, invalid_first, null, invalid)
	_check(not invalid.can_play(invalid_deck, invalid_party, invalid_enemies,
		"tinker_spool_launcher", 1, invalid_unravel),
		"AC3: failed explicit bind refuses preview")
	_check(invalid.play_attack(invalid_deck, invalid_party, invalid_enemies,
		"tinker_spool_launcher", 1, invalid_unravel) == {"ok": false, "hits": []}
		and _patch_snapshot(invalid_deck, invalid_party, invalid_enemies,
		invalid_unravel, invalid_first, null, invalid) == before_invalid,
		"AC3: failed bind leaves all state and patch latch untouched")
	_check(invalid.bind_patch_wardrobe(good["wardrobe"], good["torn"])
		and invalid.can_play(invalid_deck, invalid_party, invalid_enemies,
			"tinker_spool_launcher", 1, invalid_unravel),
		"AC3: correct explicit rebind restores legal patched play")

	# Every rejection is tested with both patches genuinely active and a live
	# foreign pin. Snapshot includes injected RNG, all combat state and patch latch.
	var negatives := [
		{"name": "missing held upgrade", "card": "tinker_spool_launcher_plus", "target": 1},
		{"name": "wrong single target", "card": "tinker_spool_launcher", "target": 0},
		{"name": "wrong area target", "card": "tinker_shrapnel_seam", "target": 1},
		{"name": "unaffordable area", "card": "tinker_shrapnel_seam", "target": 0,
			"kind": "energy"},
		{"name": "downed Tinker", "card": "tinker_spool_launcher", "target": 1,
			"kind": "down"},
		{"name": "Tinker in forbidden slot", "card": "tinker_shrapnel_seam", "target": 0,
			"kind": "from"},
		{"name": "dead single target", "card": "tinker_spool_launcher", "target": 2,
			"kind": "dead_second"},
		{"name": "all area targets dead", "card": "tinker_shrapnel_seam", "target": 0,
			"kind": "all_dead"},
		{"name": "Button Eye status overflow", "card": "tinker_spool_launcher", "target": 1,
			"kind": "overflow"},
		{"name": "area first-living status overflow", "card": "tinker_shrapnel_seam", "target": 0,
			"kind": "area_overflow"},
		{"name": "malformed gauge", "card": "tinker_snip_the_seam", "target": 1,
			"kind": "gauge"},
		{"name": "invalid defender statuses", "card": "tinker_spool_launcher", "target": 1,
			"kind": "statuses"},
		{"name": "unbound gauge service", "card": "tinker_spool_launcher", "target": 1,
			"kind": "unbound"}
	]
	for case in negatives:
		var first := CombatTinkerFirstAttack.new()
		var pinned := CombatPinned.new()
		var resolver := CombatTinkerPoolUnravelAttacks.new(first, pinned)
		var fixture: Dictionary = _patch_fixture("tinker", "tinker")
		_check(resolver.bind_patch_wardrobe(fixture["wardrobe"], fixture["torn"]),
			"AC3: active genuine two-patch binding for " + case["name"])
		var deck: CombatDeck = _deck(["tinker_spool_launcher", "tinker_shrapnel_seam",
			"tinker_snip_the_seam"])
		var party: CombatParty = _party()
		var enemies: CombatEnemies = _enemies([30, 30])
		var unravel: CombatUnravel = _unravel(enemies)
		_check(pinned.pin_enemy(enemies, 1, "warden"), "AC3: pinned rejection precondition")
		var kind: String = case.get("kind", "")
		match kind:
			"energy":
				deck.combat_state.energy = 1
			"down":
				party.apply_damage(3, 26)
			"from":
				party._heroes[1]["id"] = "tinker"
				party._heroes[2]["id"] = "seamstress"
			"dead_second":
				enemies.apply_damage(2, 30)
			"all_dead":
				enemies.apply_damage(1, 30)
				enemies.apply_damage(2, 30)
			"overflow":
				enemies._enemies[0]["statuses"] = {"exposed": CombatStatuses.MAX_INT}
				_check(not enemies.can_apply_statuses({1: {"exposed": 1}}),
					"AC3: real Button Eye status-capacity overflow")
			"area_overflow":
				enemies.apply_damage(1, 30)
				enemies._enemies[1]["statuses"] = {"exposed": CombatStatuses.MAX_INT}
				_check(enemies.is_slain(1) and not enemies.can_apply_statuses(
					{2: {"exposed": 1}}),
					"AC3: area first actual slot 2 lacks Exposed capacity")
			"gauge":
				unravel._gauges[1]["gauge"] = -1
				_check(unravel.get_snapshot(1)["gauge"] == -1,
					"AC3: malformed gauge is actually present")
			"statuses":
				enemies._enemies[0]["statuses"] = {"exposed": -1}
			"unbound":
				unravel = CombatUnravel.new()
		var before: Dictionary = _patch_snapshot(deck, party, enemies, unravel,
			first, pinned, resolver)
		var before_wardrobe: Dictionary = fixture["wardrobe"].get_snapshot()
		var before_torn: Dictionary = fixture["torn"].read_state()
		_check(not resolver.can_play(deck, party, enemies,
			case["card"], case["target"], unravel),
			"AC3: can_play rejects patched " + case["name"])
		_check(resolver.play_attack(deck, party, enemies, case["card"],
			case["target"], unravel) == {"ok": false, "hits": []},
			"AC3: patched play rejects " + case["name"])
		_check(_patch_snapshot(deck, party, enemies, unravel, first, pinned, resolver) == before
			and fixture["wardrobe"].get_snapshot() == before_wardrobe
			and fixture["torn"].read_state() == before_torn,
			"AC3: full atomic no-spend/no-RNG/no-latch/pin state " + case["name"])
