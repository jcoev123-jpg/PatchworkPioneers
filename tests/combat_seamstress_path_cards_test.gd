extends SceneTree
## Deterministic headless regression for CombatSeamstressPathCards (D2-5).
## Verifies scene-free resolution for Bloodline Leech Stitch and Unpicker Fray.

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_ac1_bloodline_positions()
	_test_ac1_bloodline_almost_full()
	_test_ac1_bloodline_full_hp()
	_test_ac1_bloodline_tie_break()
	_test_ac1_bloodline_downed_hero()

	_test_ac2_unpicker_normal()
	_test_ac2_unpicker_threshold_and_skip()
	_test_ac2_unpicker_elite()

	_test_ac3_catalog_isolation()
	_test_ac3_exclusivity()

	_test_ac4_rejections_and_snapshots()
	_test_ac4_repeat_submission_rejection()

	_test_preview_and_convenience_methods()

	if failures.is_empty():
		print("combat_seamstress_path_cards_test: PASS (", checks, " checks)")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("combat_seamstress_path_cards_test: FAIL (", failures.size(), " failures, ", checks, " checks)")
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _party(seamstress_position: int = 2) -> CombatParty:
	var ids: Array[String] = ["warden", "seamstress", "tinker"]
	ids.erase("seamstress")
	ids.insert(seamstress_position - 1, "seamstress")
	var definitions: Array[Dictionary] = []
	var hp := {"warden": 40, "seamstress": 30, "tinker": 26}
	for id in ids:
		definitions.append({"id": id, "max_hp": hp[id]})
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "party is valid")
	return party


func _enemies(tiers: Dictionary = {1: "normal", 2: "normal", 3: "normal"}, max_hp: int = 25) -> Dictionary:
	var defs: Array[Dictionary] = [
		{"id": "foe1", "max_hp": max_hp},
		{"id": "foe2", "max_hp": max_hp},
		{"id": "foe3", "max_hp": max_hp},
	]
	var enemies := CombatEnemies.new(defs)
	var unravel := CombatUnravel.new()
	var bound := unravel.bind_roster(enemies, tiers)
	_check(enemies.is_valid() and bound, "enemies and unravel bound successfully")
	return {"enemies": enemies, "unravel": unravel}


func _deck_with_held_card(receipt: Dictionary, card_id: String, seed_val: int = 1234) -> CombatDeck:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var card_ids: Array[String] = []
	for cid in receipt["deck"]:
		card_ids.append(str(cid))
	var deck := CombatDeck.new(card_ids, rng)
	_check(deck.start_turn(), "deck turn started")
	while not deck.hand.has(card_id) and not deck.draw_pile.is_empty():
		deck.draw_extra(1)
	_check(deck.hand.has(card_id), "card " + card_id + " is held in hand")
	return deck


func _snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies, unravel: CombatUnravel = null) -> Dictionary:
	var unravel_snap := {}
	if unravel != null:
		for pos in range(1, 4):
			unravel_snap[pos] = unravel.get_snapshot(pos)
	return {
		"hand": deck.hand.duplicate(),
		"draw": deck.draw_pile.duplicate(),
		"discard": deck.discard_pile.duplicate(),
		"energy": deck.energy,
		"turn_active": deck.turn_active,
		"combat_state_energy": deck.combat_state.energy,
		"combat_state_turn": deck.combat_state.player_turn_active,
		"rng_state": deck._rng.state,
		"party": party.get_heroes(),
		"enemies": enemies.get_enemies(),
		"unravel": unravel_snap,
	}


func _deep_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Array:
		var arr_a: Array = a
		var arr_b: Array = b
		if arr_a.size() != arr_b.size():
			return false
		for i in range(arr_a.size()):
			if not _deep_equal(arr_a[i], arr_b[i]):
				return false
		return true
	if a is Dictionary:
		var dict_a: Dictionary = a
		var dict_b: Dictionary = b
		if dict_a.size() != dict_b.size():
			return false
		for k in dict_a:
			if not dict_b.has(k):
				return false
			if not _deep_equal(dict_a[k], dict_b[k]):
				return false
		return true
	return a == b


func _test_ac1_bloodline_positions() -> void:
	var choice := RunSeamstressPathChoice.new()
	var receipt := choice.choose("bloodline")
	_check(receipt.get("ok") == true, "bloodline receipt created")

	# Test standard play with Seamstress in pos 1, 2, 3
	for seam_pos in [1, 2, 3]:
		var party := _party(seam_pos)
		# Damage Seamstress so she is missing 6 HP (24/30)
		party.apply_damage(seam_pos, 6)
		var enemies_data := _enemies()
		var enemies: CombatEnemies = enemies_data["enemies"]
		var deck := _deck_with_held_card(receipt, "seamstress_leech_stitch", 100 + seam_pos)
		var target_pos := 2

		var resolver := CombatSeamstressPathCards.new(receipt)
		var pre_energy := deck.energy
		var pre_hand_size := deck.hand.size()
		var pre_discard_size := deck.discard_pile.size()
		var pre_rng := deck._rng.state

		var result := resolver.play_card(deck, party, enemies, "seamstress_leech_stitch", target_pos)

		_check(result.get("ok") == true, "AC1: Leech Stitch play returned ok=true for Seamstress at pos %d" % seam_pos)
		_check(result.get("bleed_applied") == 4, "AC1: applies exactly Bleed 4")
		_check(result.get("healed_slot") == seam_pos, "AC1: heals weakest living ally (Seamstress)")
		_check(result.get("healed_amount") == 2, "AC1: heals exactly 2 HP")

		# Check energy and card movement
		_check(deck.energy == pre_energy - 1, "AC1: costs exactly 1 energy")
		_check(deck.hand.size() == pre_hand_size - 1, "AC1: 1 card removed from hand")
		_check(not deck.hand.has("seamstress_leech_stitch"), "AC1: held copy leaves hand")
		_check(deck.discard_pile.size() == pre_discard_size + 1, "AC1: 1 card entered discard")
		_check(deck.discard_pile[-1] == "seamstress_leech_stitch", "AC1: discarded copy is Leech Stitch")
		_check(deck._rng.state == pre_rng, "AC1: no RNG advance on play")

		# Check target enemy has Bleed 4 and unchanged HP/block
		var target_enemy := enemies.get_enemy(target_pos)
		_check(target_enemy["statuses"].get("bleed", 0) == 4, "AC1: target enemy has Bleed 4")
		_check(target_enemy["hp"] == 25 and target_enemy["block"] == 0, "AC1: enemy HP and Block unchanged")

		# Check other enemies unchanged
		for other_pos in [1, 3]:
			var other_foe := enemies.get_enemy(other_pos)
			_check(other_foe.get("statuses", {}).is_empty(), "AC1: other enemy statuses untouched")
			_check(other_foe["hp"] == 25 and other_foe["block"] == 0, "AC1: other enemy HP/Block untouched")

		# Check party healing: Seamstress was at 24/30, now 26/30
		var seam_hero := party.get_hero(seam_pos)
		_check(seam_hero["hp"] == 26, "AC1: Seamstress healed from 24 to 26")
		_check(seam_hero["block"] == 0, "AC1: Seamstress block unchanged")

		# Other heroes unchanged
		for h_pos in range(1, 4):
			if h_pos != seam_pos:
				var h := party.get_hero(h_pos)
				_check(h["hp"] == h["max_hp"] and h["block"] == 0, "AC1: other hero untouched")


func _test_ac1_bloodline_almost_full() -> void:
	var choice := RunSeamstressPathChoice.new()
	var receipt := choice.choose("bloodline")
	var party := _party(2)
	# Tinker (pos 3, max 26): damage 1 -> HP 25 (missing 1 HP).
	# Warden (pos 1) has 40 HP, Seamstress (pos 2) has 30 HP.
	# Tinker is the weakest living ally (25 < 30 < 40).
	party.apply_damage(3, 1)
	var enemies_data := _enemies()
	var enemies: CombatEnemies = enemies_data["enemies"]
	var deck := _deck_with_held_card(receipt, "seamstress_leech_stitch", 201)

	var resolver := CombatSeamstressPathCards.new(receipt)
	var result := resolver.play_card(deck, party, enemies, "seamstress_leech_stitch", 1)

	_check(result.get("ok") == true, "AC1: play succeeded with almost-full ally")
	_check(result.get("healed_slot") == 3, "AC1: weakest ally is Tinker at pos 3")
	_check(result.get("healed_amount") == 1, "AC1: capped to missing HP (1 HP healed)")
	_check(party.get_hero(3)["hp"] == 26, "AC1: Tinker restored to 26 max HP")


func _test_ac1_bloodline_full_hp() -> void:
	var choice := RunSeamstressPathChoice.new()
	var receipt := choice.choose("bloodline")
	var party := _party(2)
	# All heroes at full HP: Warden=40, Seamstress=30, Tinker=26.
	# Weakest living ally is Tinker (lowest current HP: 26 < 30 < 40).
	var enemies_data := _enemies()
	var enemies: CombatEnemies = enemies_data["enemies"]
	var deck := _deck_with_held_card(receipt, "seamstress_leech_stitch", 202)

	var resolver := CombatSeamstressPathCards.new(receipt)
	var result := resolver.play_card(deck, party, enemies, "seamstress_leech_stitch", 1)

	_check(result.get("ok") == true, "AC1: play succeeded with all full HP")
	_check(result.get("healed_slot") == 3, "AC1: weakest living ally (lowest current HP) is Tinker at pos 3")
	_check(result.get("healed_amount") == 0, "AC1: 0 HP healed when missing HP is 0")
	_check(party.get_hero(3)["hp"] == 26, "AC1: Tinker remains at 26 max HP")


func _test_ac1_bloodline_tie_break() -> void:
	var choice := RunSeamstressPathChoice.new()
	var receipt := choice.choose("bloodline")
	var party := _party(2)
	# Seamstress is pos 2 (max 30). Warden pos 1 (max 40). Tinker pos 3 (max 26).
	# Damage Warden by 20 -> HP 20.
	party.apply_damage(1, 20)
	# Damage Tinker by 6 -> HP 20.
	party.apply_damage(3, 6)
	# Seamstress at 30 HP. Both Warden (pos 1) and Tinker (pos 3) have 20 HP.
	var enemies_data := _enemies()
	var enemies: CombatEnemies = enemies_data["enemies"]
	var deck := _deck_with_held_card(receipt, "seamstress_leech_stitch", 203)

	var resolver := CombatSeamstressPathCards.new(receipt)
	var result := resolver.play_card(deck, party, enemies, "seamstress_leech_stitch", 3)

	_check(result.get("ok") == true, "AC1: tie-break play succeeded")
	_check(result.get("healed_slot") == 1, "AC1: tie-break chose frontmost slot 1 over slot 3")
	_check(result.get("healed_amount") == 2, "AC1: healed 2 HP on slot 1")
	_check(party.get_hero(1)["hp"] == 22, "AC1: Warden healed from 20 to 22")
	_check(party.get_hero(3)["hp"] == 20, "AC1: Tinker remained at 20")


func _test_ac1_bloodline_downed_hero() -> void:
	var choice := RunSeamstressPathChoice.new()
	var receipt := choice.choose("bloodline")
	var party := _party(2)
	# Down Warden (pos 1) -> 0 HP
	party.apply_damage(1, 40)
	_check(party.is_downed(1), "Warden is downed")
	# Seamstress (pos 2) has 20 HP (damage 10).
	party.apply_damage(2, 10)
	# Tinker (pos 3) has 22 HP (damage 4).
	party.apply_damage(3, 4)

	var enemies_data := _enemies()
	var enemies: CombatEnemies = enemies_data["enemies"]
	var deck := _deck_with_held_card(receipt, "seamstress_leech_stitch", 204)

	var resolver := CombatSeamstressPathCards.new(receipt)
	var result := resolver.play_card(deck, party, enemies, "seamstress_leech_stitch", 1)

	_check(result.get("ok") == true, "AC1: play succeeded with downed hero in party")
	_check(result.get("healed_slot") == 2, "AC1: downed hero (slot 1) skipped; slot 2 healed")
	_check(party.get_hero(1)["hp"] == 0, "AC1: downed hero remains at 0 HP")
	_check(party.get_hero(2)["hp"] == 22, "AC1: living weakest ally healed")


func _test_ac2_unpicker_normal() -> void:
	var choice := RunSeamstressPathChoice.new()
	var receipt := choice.choose("unpicker")
	_check(receipt.get("ok") == true, "unpicker receipt created")

	var party := _party(2)
	var enemies_data := _enemies({1: "normal", 2: "normal", 3: "normal"})
	var enemies: CombatEnemies = enemies_data["enemies"]
	var unravel: CombatUnravel = enemies_data["unravel"]
	var deck := _deck_with_held_card(receipt, "seamstress_fray", 301)
	var target_pos := 1

	var pre_energy := deck.energy
	var pre_hand_size := deck.hand.size()
	var pre_discard_size := deck.discard_pile.size()
	var pre_rng := deck._rng.state

	var resolver := CombatSeamstressPathCards.new(receipt, unravel)
	var result := resolver.play_card(deck, party, enemies, "seamstress_fray", target_pos)

	_check(result.get("ok") == true, "AC2: Fray play ok=true")
	_check(result.get("bleed_applied") == 1, "AC2: applies exactly Bleed 1")
	_check(result.get("unravel_applied") == 6, "AC2: applies exactly 6 Unravel (4 authored + 2 Unpicker)")

	# Conservation
	_check(deck.energy == pre_energy - 1, "AC2: exactly 1 energy cost")
	_check(deck.hand.size() == pre_hand_size - 1, "AC2: 1 card removed from hand")
	_check(not deck.hand.has("seamstress_fray"), "AC2: fray discarded")
	_check(deck.discard_pile.size() == pre_discard_size + 1, "AC2: 1 card entered discard")
	_check(deck._rng.state == pre_rng, "AC2: no RNG advance")

	# Target enemy state: Bleed 1, direct damage 0, Block 0
	var foe := enemies.get_enemy(target_pos)
	_check(foe["statuses"].get("bleed", 0) == 1, "AC2: enemy has exactly Bleed 1")
	_check(foe["hp"] == 25 and foe["block"] == 0, "AC2: enemy HP and Block unchanged (no direct damage)")

	# Gauge state: gauge=6, threshold=8, unravelled=false, skip_pending=false
	var snap := unravel.get_snapshot(target_pos)
	_check(snap["gauge"] == 6, "AC2: gauge is 6 / 8")
	_check(snap["threshold"] == 8, "AC2: threshold is 8")
	_check(snap["unravelled"] == false, "AC2: not unravelled yet")
	_check(snap["skip_pending"] == false, "AC2: no skip pending yet")

	# Bleed tick check: Fray play does NOT perform the later Bleed tick (gauge remains 6)
	_check(unravel.get_snapshot(target_pos)["gauge"] == 6, "AC2: Fray play itself did not perform Bleed tick")
	# Performing future Bleed tick separately adds 1 Unravel
	_check(unravel.record_bleed_tick(enemies, target_pos), "simulating future Bleed tick")
	_check(unravel.get_snapshot(target_pos)["gauge"] == 7, "gauge becomes 7 after separate Bleed tick")


func _test_ac2_unpicker_threshold_and_skip() -> void:
	var choice := RunSeamstressPathChoice.new()
	var receipt := choice.choose("unpicker")

	var party := _party(1)
	var enemies_data := _enemies({1: "normal", 2: "normal", 3: "normal"})
	var enemies: CombatEnemies = enemies_data["enemies"]
	var unravel: CombatUnravel = enemies_data["unravel"]
	# Pre-charge gauge to 4
	_check(unravel.apply_unravel(enemies, 1, 4), "pre-charge gauge to 4")
	_check(unravel.get_snapshot(1)["gauge"] == 4, "gauge is 4")

	var deck := _deck_with_held_card(receipt, "seamstress_fray", 302)
	var resolver := CombatSeamstressPathCards.new(receipt, unravel)
	var result := resolver.play_card(deck, party, enemies, "seamstress_fray", 1)

	_check(result.get("ok") == true, "AC2: Fray reached threshold")
	var snap := unravel.get_snapshot(1)
	_check(snap["gauge"] == 8, "AC2: gauge clamped to threshold 8")
	_check(snap["unravelled"] == true, "AC2: enemy is unravelled")
	_check(snap["skip_pending"] == true, "AC2: skip_pending is true")

	# Consume the skip
	var consumed := unravel.consume_action_skip(enemies, 1)
	_check(consumed == true, "AC2: skip consumed successfully")
	var post_skip := unravel.get_snapshot(1)
	_check(post_skip["gauge"] == 0, "AC2: gauge reset to 0")
	_check(post_skip["threshold"] == 12, "AC2: threshold raised by 4 (8 -> 12)")
	_check(post_skip["unravelled"] == false, "AC2: unravelled cleared")
	_check(post_skip["skip_pending"] == false, "AC2: skip_pending cleared")


func _test_ac2_unpicker_elite() -> void:
	var choice := RunSeamstressPathChoice.new()
	var receipt := choice.choose("unpicker")

	var party := _party(3)
	var enemies_data := _enemies({1: "normal", 2: "elite", 3: "boss"})
	var enemies: CombatEnemies = enemies_data["enemies"]
	var unravel: CombatUnravel = enemies_data["unravel"]
	# Pre-charge elite gauge to 7
	_check(unravel.apply_unravel(enemies, 2, 7), "pre-charge elite gauge to 7")
	_check(unravel.get_snapshot(2)["gauge"] == 7, "elite gauge is 7")
	_check(unravel.get_snapshot(2)["threshold"] == 12, "elite threshold is 12")

	var deck := _deck_with_held_card(receipt, "seamstress_fray", 303)
	var resolver := CombatSeamstressPathCards.new(receipt, unravel)
	var result := resolver.play_card(deck, party, enemies, "seamstress_fray", 2)

	_check(result.get("ok") == true, "AC2: elite Fray play ok")
	var snap := unravel.get_snapshot(2)
	_check(snap["gauge"] == 12, "AC2: elite gauge clamped to 12")
	_check(snap["unravelled"] == true and snap["skip_pending"] == true, "AC2: elite unravelled and skip pending")

	var consumed := unravel.consume_action_skip(enemies, 2)
	_check(consumed == true, "AC2: elite skip consumed")
	var post_skip := unravel.get_snapshot(2)
	_check(post_skip["gauge"] == 0, "AC2: elite gauge reset to 0")
	_check(post_skip["threshold"] == 16, "AC2: elite threshold raised by 4 (12 -> 16)")


func _test_ac3_catalog_isolation() -> void:
	var starter := StarterCards.new()
	_check(not starter.has_card("seamstress_leech_stitch"), "AC3: Leech Stitch not in StarterCards")
	_check(not starter.has_card("seamstress_fray"), "AC3: Fray not in StarterCards")
	var pool := SeamstressPoolCards.new()
	_check(not pool.has_card("seamstress_leech_stitch"), "AC3: Leech Stitch not in SeamstressPoolCards")
	_check(not pool.has_card("seamstress_fray"), "AC3: Fray not in SeamstressPoolCards")


func _test_ac3_exclusivity() -> void:
	var choice_b := RunSeamstressPathChoice.new()
	var receipt_bloodline := choice_b.choose("bloodline")

	var choice_u := RunSeamstressPathChoice.new()
	var receipt_unpicker := choice_u.choose("unpicker")

	# Bloodline cannot play Fray
	var party := _party(2)
	var enemies_data := _enemies()
	var enemies: CombatEnemies = enemies_data["enemies"]
	var unravel: CombatUnravel = enemies_data["unravel"]
	var deck_cards: Array[String] = []
	for c in receipt_bloodline["deck"]:
		deck_cards.append(str(c))
	deck_cards.append("seamstress_fray")

	var rng := RandomNumberGenerator.new()
	rng.seed = 401
	var deck := CombatDeck.new(deck_cards, rng)
	deck.start_turn()
	while not deck.hand.has("seamstress_fray") and not deck.draw_pile.is_empty():
		deck.draw_extra(1)

	var resolver := CombatSeamstressPathCards.new(receipt_bloodline, unravel)
	var before := _snapshot(deck, party, enemies, unravel)

	var res := resolver.play_card(deck, party, enemies, "seamstress_fray", 1)
	_check(res.get("ok") == false, "AC3: Bloodline receipt cannot play Fray")
	var after := _snapshot(deck, party, enemies, unravel)
	_check(_deep_equal(before, after), "AC3: rejection leaves full state unchanged")

	# Unpicker cannot play Leech Stitch
	var deck_cards_u: Array[String] = []
	for c in receipt_unpicker["deck"]:
		deck_cards_u.append(str(c))
	deck_cards_u.append("seamstress_leech_stitch")

	var rng_u := RandomNumberGenerator.new()
	rng_u.seed = 402
	var deck_u := CombatDeck.new(deck_cards_u, rng_u)
	deck_u.start_turn()
	while not deck_u.hand.has("seamstress_leech_stitch") and not deck_u.draw_pile.is_empty():
		deck_u.draw_extra(1)

	var resolver_u := CombatSeamstressPathCards.new(receipt_unpicker, unravel)
	var before_u := _snapshot(deck_u, party, enemies, unravel)

	var res_u := resolver_u.play_card(deck_u, party, enemies, "seamstress_leech_stitch", 1)
	_check(res_u.get("ok") == false, "AC3: Unpicker receipt cannot play Leech Stitch")
	var after_u := _snapshot(deck_u, party, enemies, unravel)
	_check(_deep_equal(before_u, after_u), "AC3: rejection leaves full state unchanged")


func _test_ac4_rejections_and_snapshots() -> void:
	var choice_b := RunSeamstressPathChoice.new()
	var receipt_b := choice_b.choose("bloodline")

	var choice_u := RunSeamstressPathChoice.new()
	var receipt_u := choice_u.choose("unpicker")

	# 1. Absent receipt
	var d1 := _deck_with_held_card(receipt_b, "seamstress_leech_stitch", 501)
	var p1 := _party(2)
	var e1 := _enemies()["enemies"] as CombatEnemies
	var snap1 := _snapshot(d1, p1, e1)
	var r1 := CombatSeamstressPathCards.new()
	_check(r1.play_card(d1, p1, e1, "seamstress_leech_stitch", 1).get("ok") == false, "AC4 reject: absent receipt")
	_check(_deep_equal(snap1, _snapshot(d1, p1, e1)), "AC4 snapshot unchanged: absent receipt")

	# 2. Empty receipt
	var d2 := _deck_with_held_card(receipt_b, "seamstress_leech_stitch", 502)
	var p2 := _party(2)
	var e2 := _enemies()["enemies"] as CombatEnemies
	var snap2 := _snapshot(d2, p2, e2)
	var r2 := CombatSeamstressPathCards.new({})
	_check(r2.play_card(d2, p2, e2, "seamstress_leech_stitch", 1).get("ok") == false, "AC4 reject: empty receipt")
	_check(_deep_equal(snap2, _snapshot(d2, p2, e2)), "AC4 snapshot unchanged: empty receipt")

	# 3. Altered receipt: modified passive value
	var bad_receipt3: Dictionary = receipt_b.duplicate(true)
	bad_receipt3["passive"]["value"] = 2
	var d3 := _deck_with_held_card(receipt_b, "seamstress_leech_stitch", 503)
	var p3 := _party(2)
	var e3 := _enemies()["enemies"] as CombatEnemies
	var snap3 := _snapshot(d3, p3, e3)
	var r3 := CombatSeamstressPathCards.new(bad_receipt3)
	_check(r3.play_card(d3, p3, e3, "seamstress_leech_stitch", 1).get("ok") == false, "AC4 reject: bad passive value")
	_check(_deep_equal(snap3, _snapshot(d3, p3, e3)), "AC4 snapshot unchanged: bad passive value")

	# 4. Altered receipt: modified card effects
	var bad_receipt4: Dictionary = receipt_b.duplicate(true)
	bad_receipt4["card"]["effects"]["bleed"] = 99
	var d4 := _deck_with_held_card(receipt_b, "seamstress_leech_stitch", 504)
	var p4 := _party(2)
	var e4 := _enemies()["enemies"] as CombatEnemies
	var snap4 := _snapshot(d4, p4, e4)
	var r4 := CombatSeamstressPathCards.new(bad_receipt4)
	_check(r4.play_card(d4, p4, e4, "seamstress_leech_stitch", 1).get("ok") == false, "AC4 reject: bad card effect")
	_check(_deep_equal(snap4, _snapshot(d4, p4, e4)), "AC4 snapshot unchanged: bad card effect")

	# 5. Altered receipt: deck contains both path cards
	var bad_receipt5: Dictionary = receipt_b.duplicate(true)
	bad_receipt5["deck"].append("seamstress_fray")
	var d5 := _deck_with_held_card(receipt_b, "seamstress_leech_stitch", 505)
	var p5 := _party(2)
	var e5 := _enemies()["enemies"] as CombatEnemies
	var snap5 := _snapshot(d5, p5, e5)
	var r5 := CombatSeamstressPathCards.new(bad_receipt5)
	_check(r5.play_card(d5, p5, e5, "seamstress_leech_stitch", 1).get("ok") == false, "AC4 reject: deck contains both path cards")
	_check(_deep_equal(snap5, _snapshot(d5, p5, e5)), "AC4 snapshot unchanged: deck contains both path cards")

	# 6. Altered receipt: ok = false
	var bad_receipt6: Dictionary = receipt_b.duplicate(true)
	bad_receipt6["ok"] = false
	var d6 := _deck_with_held_card(receipt_b, "seamstress_leech_stitch", 506)
	var p6 := _party(2)
	var e6 := _enemies()["enemies"] as CombatEnemies
	var snap6 := _snapshot(d6, p6, e6)
	var r6 := CombatSeamstressPathCards.new(bad_receipt6)
	_check(r6.play_card(d6, p6, e6, "seamstress_leech_stitch", 1).get("ok") == false, "AC4 reject: receipt ok=false")
	_check(_deep_equal(snap6, _snapshot(d6, p6, e6)), "AC4 snapshot unchanged: receipt ok=false")

	# 7. Unheld card: Leech Stitch is in draw pile, not hand
	var rng7 := RandomNumberGenerator.new()
	rng7.seed = 507
	var d7 := CombatDeck.new(receipt_b["deck"], rng7)
	d7.start_turn()
	if d7.hand.has("seamstress_leech_stitch"):
		d7.hand.erase("seamstress_leech_stitch")
		d7.draw_pile.append("seamstress_leech_stitch")
	var p7 := _party(2)
	var e7 := _enemies()["enemies"] as CombatEnemies
	var snap7 := _snapshot(d7, p7, e7)
	var r7 := CombatSeamstressPathCards.new(receipt_b)
	_check(r7.play_card(d7, p7, e7, "seamstress_leech_stitch", 1).get("ok") == false, "AC4 reject: unheld card")
	_check(_deep_equal(snap7, _snapshot(d7, p7, e7)), "AC4 snapshot unchanged: unheld card")

	# 8. Insufficient energy: energy is 0
	var d8 := _deck_with_held_card(receipt_b, "seamstress_leech_stitch", 508)
	d8.try_spend_energy(3)
	var p8 := _party(2)
	var e8 := _enemies()["enemies"] as CombatEnemies
	var snap8 := _snapshot(d8, p8, e8)
	var r8 := CombatSeamstressPathCards.new(receipt_b)
	_check(r8.play_card(d8, p8, e8, "seamstress_leech_stitch", 1).get("ok") == false, "AC4 reject: insufficient energy")
	_check(_deep_equal(snap8, _snapshot(d8, p8, e8)), "AC4 snapshot unchanged: insufficient energy")

	# 9. Downed Seamstress: Seamstress HP is 0
	var d9 := _deck_with_held_card(receipt_b, "seamstress_leech_stitch", 509)
	var p9 := _party(2)
	p9.apply_damage(2, 30)
	var e9 := _enemies()["enemies"] as CombatEnemies
	var snap9 := _snapshot(d9, p9, e9)
	var r9 := CombatSeamstressPathCards.new(receipt_b)
	_check(r9.play_card(d9, p9, e9, "seamstress_leech_stitch", 1).get("ok") == false, "AC4 reject: downed Seamstress")
	_check(_deep_equal(snap9, _snapshot(d9, p9, e9)), "AC4 snapshot unchanged: downed Seamstress")

	# 10. Missing Seamstress
	var d10 := _deck_with_held_card(receipt_b, "seamstress_leech_stitch", 510)
	var defs10: Array[Dictionary] = [
		{"id": "warden", "max_hp": 40},
		{"id": "tinker", "max_hp": 26},
		{"id": "tinker2", "max_hp": 26},
	]
	var p10 := CombatParty.new(defs10)
	var e10 := _enemies()["enemies"] as CombatEnemies
	var snap10 := _snapshot(d10, p10, e10)
	var r10 := CombatSeamstressPathCards.new(receipt_b)
	_check(r10.play_card(d10, p10, e10, "seamstress_leech_stitch", 1).get("ok") == false, "AC4 reject: missing Seamstress")
	_check(_deep_equal(snap10, _snapshot(d10, p10, e10)), "AC4 snapshot unchanged: missing Seamstress")

	# 11. Slain target enemy
	var d11 := _deck_with_held_card(receipt_b, "seamstress_leech_stitch", 511)
	var p11 := _party(2)
	var e11 := _enemies()["enemies"] as CombatEnemies
	e11.apply_damage(2, 25)
	var snap11 := _snapshot(d11, p11, e11)
	var r11 := CombatSeamstressPathCards.new(receipt_b)
	_check(r11.play_card(d11, p11, e11, "seamstress_leech_stitch", 2).get("ok") == false, "AC4 reject: slain enemy")
	_check(_deep_equal(snap11, _snapshot(d11, p11, e11)), "AC4 snapshot unchanged: slain enemy")

	# 12. Invalid target position
	var d12 := _deck_with_held_card(receipt_b, "seamstress_leech_stitch", 512)
	var p12 := _party(2)
	var e12 := _enemies()["enemies"] as CombatEnemies
	var snap12 := _snapshot(d12, p12, e12)
	var r12 := CombatSeamstressPathCards.new(receipt_b)
	_check(r12.play_card(d12, p12, e12, "seamstress_leech_stitch", 0).get("ok") == false, "AC4 reject: target pos 0")
	_check(r12.play_card(d12, p12, e12, "seamstress_leech_stitch", 4).get("ok") == false, "AC4 reject: target pos 4")
	_check(_deep_equal(snap12, _snapshot(d12, p12, e12)), "AC4 snapshot unchanged: invalid target position")

	# 13. Status capacity overflow
	var d13 := _deck_with_held_card(receipt_b, "seamstress_leech_stitch", 513)
	var p13 := _party(2)
	var e13 := _enemies()["enemies"] as CombatEnemies
	e13.apply_statuses({1: {"bleed": CombatEnemies.MAX_INT - 1}})
	var snap13 := _snapshot(d13, p13, e13)
	var r13 := CombatSeamstressPathCards.new(receipt_b)
	_check(r13.play_card(d13, p13, e13, "seamstress_leech_stitch", 1).get("ok") == false, "AC4 reject: bleed capacity overflow")
	_check(_deep_equal(snap13, _snapshot(d13, p13, e13)), "AC4 snapshot unchanged: status overflow")

	# 14. Fray with null unravel
	var d14 := _deck_with_held_card(receipt_u, "seamstress_fray", 514)
	var p14 := _party(2)
	var e14 := _enemies()["enemies"] as CombatEnemies
	var snap14 := _snapshot(d14, p14, e14)
	var r14 := CombatSeamstressPathCards.new(receipt_u, null)
	_check(r14.play_card(d14, p14, e14, "seamstress_fray", 1, null).get("ok") == false, "AC4 reject: null unravel")
	_check(_deep_equal(snap14, _snapshot(d14, p14, e14)), "AC4 snapshot unchanged: null unravel")

	# 15. Fray with wrong bound enemies
	var d15 := _deck_with_held_card(receipt_u, "seamstress_fray", 515)
	var p15 := _party(2)
	var e15_data := _enemies()
	var other_data := _enemies()
	var snap15 := _snapshot(d15, p15, e15_data["enemies"], other_data["unravel"])
	var r15 := CombatSeamstressPathCards.new(receipt_u, other_data["unravel"])
	_check(r15.play_card(d15, p15, e15_data["enemies"], "seamstress_fray", 1, other_data["unravel"]).get("ok") == false, "AC4 reject: wrong enemies bound")
	_check(_deep_equal(snap15, _snapshot(d15, p15, e15_data["enemies"], other_data["unravel"])), "AC4 snapshot unchanged: wrong unravel roster")


func _test_ac4_repeat_submission_rejection() -> void:
	var choice_b := RunSeamstressPathChoice.new()
	var receipt_b := choice_b.choose("bloodline")

	var party := _party(2)
	var enemies_data := _enemies()
	var enemies: CombatEnemies = enemies_data["enemies"]
	var deck := _deck_with_held_card(receipt_b, "seamstress_leech_stitch", 516)
	var resolver := CombatSeamstressPathCards.new(receipt_b)

	# First play succeeds
	var first_play := resolver.play_card(deck, party, enemies, "seamstress_leech_stitch", 1)
	_check(first_play.get("ok") == true, "first play succeeded")

	# Snapshot right after first play
	var snapshot_after_first := _snapshot(deck, party, enemies)

	# Repeat submission immediately
	var repeat_play := resolver.play_card(deck, party, enemies, "seamstress_leech_stitch", 1)
	_check(repeat_play.get("ok") == false, "AC4: repeat play of single held copy rejected")

	# Snapshot after failed repeat must match snapshot right after first play
	var snapshot_after_repeat := _snapshot(deck, party, enemies)
	_check(_deep_equal(snapshot_after_first, snapshot_after_repeat),
		"AC4: repeat submission leaves post-first-play snapshot perfectly intact")


func _test_preview_and_convenience_methods() -> void:
	var choice_b := RunSeamstressPathChoice.new()
	var receipt_b := choice_b.choose("bloodline")

	var party := _party(2)
	party.apply_damage(2, 6) # Seamstress missing 6 HP
	var enemies_data := _enemies()
	var enemies: CombatEnemies = enemies_data["enemies"]
	var deck := _deck_with_held_card(receipt_b, "seamstress_leech_stitch", 601)

	var resolver := CombatSeamstressPathCards.new()
	_check(not resolver.is_valid_choice(), "empty resolver is not valid choice")
	_check(resolver.bind_choice(receipt_b), "bind_choice returns true on valid receipt")
	_check(resolver.is_valid_choice(), "resolver is valid choice after bind")
	_check(resolver.get_path_id() == "bloodline", "get_path_id returns bloodline")
	_check(resolver.get_card_id() == "seamstress_leech_stitch", "get_card_id returns seamstress_leech_stitch")

	_check(resolver.can_play(deck, party, enemies, "seamstress_leech_stitch", 1), "can_play returns true")

	# Test preview / forecast without state mutation
	var snap_before := _snapshot(deck, party, enemies)
	var prev := resolver.preview(deck, party, enemies, "seamstress_leech_stitch", 1)
	_check(prev.get("ok") == true, "preview returns ok=true")
	_check(prev.get("bleed_applied") == 4, "preview shows bleed 4")
	_check(prev.get("healed_amount") == 2, "preview shows heal 2")
	_check(prev.get("healed_slot") == 2, "preview shows healed slot 2")

	var snap_after := _snapshot(deck, party, enemies)
	_check(_deep_equal(snap_before, snap_after), "preview causes zero side-effects")

	# Test alias play(...)
	var play_res := resolver.play(deck, party, enemies, "seamstress_leech_stitch", 1)
	_check(play_res.get("ok") == true, "play alias works identically")
