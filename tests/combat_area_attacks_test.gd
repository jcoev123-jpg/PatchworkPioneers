extends SceneTree

const CARD_ID := "tinker_scrap_bomb"

var failures: Array[String] = []
var checks := 0
var resolver := CombatAreaAttacks.new()


func _initialize() -> void:
	_test_four_enemies()
	_test_catalog_and_real_fixture()
	_test_one_enemy()
	_test_three_enemies()
	_test_slain_middle_and_victory()
	_test_fail_closed()
	_test_duplicate_hand()
	_test_seeded_replay()
	_test_reusable_operation()
	if failures.is_empty():
		print("combat_area_attacks_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_area_attacks_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _test_reusable_operation() -> void:
	for count in [1, 3]:
		var hp: Array[int] = []
		hp.assign([20] if count == 1 else [20, 20, 20])
		var enemies := _enemies(hp)
		var deck := _starter_deck()
		var party := _party()
		_check(enemies.gain_block(1, 3), "operation fixture Block")
		var before := _snapshot(deck, party, enemies)
		var expected := before.duplicate(true)
		var hits: Array = []
		for position in range(1, count + 1):
			var damage := 7 if position == 1 else 5
			var absorbed := 3 if position == 1 else 0
			hits.append({"position": position, "damage": damage, "block_absorbed": absorbed,
				"hp_loss": damage - absorbed, "statuses": {}})
			expected.enemies[position - 1].hp -= damage - absorbed
			expected.enemies[position - 1].block -= absorbed
		var attacker := {"weak": 1}
		var defenders := {1: {"exposed": 1}}
		_check(resolver.can_resolve(enemies, 7, attacker, defenders), "area preflight accepts valid batch")
		_check(_snapshot(deck, party, enemies) == before, "preflight is read-only")
		_check(resolver.resolve(enemies, 7, attacker, defenders) == {"ok": true, "hits": hits},
			"operation returns exact floor-once ordered hits")
		_check(_snapshot(deck, party, enemies) == expected, "operation changes damage only; no spending or discard")
		_check(attacker == {"weak": 1} and defenders == {1: {"exposed": 1}}, "operation preserves supplied maps")
	var enemies := _enemies([20, 20, 20])
	_check(enemies.apply_damage(2, 20), "operation slays original middle")
	var before := enemies.get_enemies()
	var result := resolver.resolve(enemies, 4)
	_check(result == {"ok": true, "hits": [
		{"position": 1, "damage": 4, "block_absorbed": 0, "hp_loss": 4, "statuses": {}},
		{"position": 3, "damage": 4, "block_absorbed": 0, "hp_loss": 4, "statuses": {}}]},
		"operation retains stable slots around slain middle")
	_check(enemies.get_enemy(2) == before[1], "slain middle untouched")
	for malformed in [{3: {"exposed": -1}}, {3: []}, {4: {}}, {"3": {}}]:
		before = enemies.get_enemies()
		_check(not resolver.can_resolve(enemies, 7, {}, malformed), "bad last map fails preflight")
		_check(resolver.resolve(enemies, 7, {}, malformed) == {"ok": false, "hits": []}
			and enemies.get_enemies() == before, "bad last map cannot partially damage")
	for field in ["position", "hp", "block", "statuses"]:
		var bad := _enemies([20, 20, 20])
		bad._enemies[2][field] = {"exposed": -1} if field == "statuses" else -1
		before = bad.get_enemies()
		_check(resolver.resolve(bad, 7) == {"ok": false, "hits": []}
			and bad.get_enemies() == before, "malformed late roster rejects atomically: " + field)


func _rng(seed_value: int = 42) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _party(ids: Array[String] = ["warden", "seamstress", "tinker"]) -> CombatParty:
	var hit_points := {"warden": 40, "seamstress": 30, "tinker": 26, "other": 20}
	var definitions: Array = []
	for id in ids:
		definitions.append({"id": id, "max_hp": hit_points[id]})
	return CombatParty.new(definitions)


func _enemies(hit_points: Array[int], capacity: int = CombatEnemies.MAX_ENEMIES) -> CombatEnemies:
	var definitions: Array = []
	for index in range(hit_points.size()):
		definitions.append({"id": "enemy_%d" % index, "max_hp": hit_points[index]})
	return CombatEnemies.new(definitions, capacity)


func _deck(cards: Array[String], seed_value: int = 42) -> CombatDeck:
	var deck := CombatDeck.new(cards, _rng(seed_value))
	_check(deck.start_turn(), "real CombatDeck starts a player turn")
	return deck


func _starter_deck() -> CombatDeck:
	var catalog := StarterCards.new()
	var deck := _deck(catalog.get_starting_deck())
	_check(deck.hand.size() == 5 and deck.energy == 3, "authentic 12-card starter begins with five held cards and three energy")
	# Obtain Scrap Bomb through the real seeded draw API, not by inserting it into hand.
	while not deck.hand.has(CARD_ID) and not deck.draw_pile.is_empty():
		_check(deck.draw_extra(1) == 1, "real deck draws toward the held Scrap Bomb")
	_check(deck.hand.has(CARD_ID), "starter Scrap Bomb is actually held")
	return deck


func _snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies) -> Dictionary:
	return {
		"draw": deck.draw_pile.duplicate(),
		"hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(),
		"turn": deck.turn_active,
		"energy": deck.energy,
		"state_turn": deck.combat_state.player_turn_active,
		"state_energy": deck.combat_state.energy,
		"rng": deck._rng.state,
		"heroes": party.get_heroes(),
		"enemies": enemies.get_enemies(),
		"victory": enemies.is_victorious()
	}


func _played_snapshot(before: Dictionary, resulting_enemies: Array, victorious: bool) -> Dictionary:
	var expected := before.duplicate(true)
	expected["energy"] = before["energy"] - 2
	expected["state_energy"] = before["state_energy"] - 2
	var hand: Array = expected["hand"]
	hand.remove_at(hand.find(CARD_ID))
	var discard: Array = expected["discard"]
	discard.append(CARD_ID)
	expected["enemies"] = resulting_enemies
	expected["victory"] = victorious
	return expected


func _reject(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies, reason: String) -> void:
	var before := _snapshot(deck, party, enemies)
	_check(not resolver.play_scrap_bomb(deck, party, enemies), reason + " rejects")
	_check(_snapshot(deck, party, enemies) == before, reason + " keeps complete deck, RNG, heroes and enemies unchanged")


func _test_catalog_and_real_fixture() -> void:
	var catalog := StarterCards.new()
	var definition: Dictionary = catalog.get_definition(CARD_ID)
	_check(definition.get("id") == CARD_ID and definition.get("display_name") == "Scrap Bomb",
		"resolver's card is the real authored Scrap Bomb")
	_check(definition.get("owner") == "tinker" and definition.get("cost") == 2
		and definition.get("from_positions") == [3], "authored cost, owner and back-row restriction")
	_check(definition.get("target_kind") == "enemy_all" and definition.get("to_positions") == [1, 2, 3],
		"authored all-enemy target schema")
	_check(definition.get("effects") == {"damage": 4} and definition.get("starting_copies") == 1
		and definition.get("illustration_path") == "res://assets/paper/cards/tinker_scrap_bomb.png",
		"authored damage, starting copy and placeholder art metadata")
	_check(catalog.get_starting_deck().count(CARD_ID) == 1, "actual starter deck has one Scrap Bomb")
	_check(resolver.has_method("play_scrap_bomb"), "required public resolver method is present")
	var pristine := definition.duplicate(true)
	var deck := _starter_deck()
	var party := _party()
	var enemies := _enemies([10])
	_check(party.is_valid() and enemies.is_valid() and not party.is_downed(3)
		and not enemies.is_victorious(), "positive fixture owns living Tinker and living real enemy")
	_check(resolver.play_scrap_bomb(deck, party, enemies), "real starter fixture resolves correctly")
	_check(catalog.get_definition(CARD_ID) == pristine, "playing never modifies the card catalog")


func _test_four_enemies() -> void:
	var replay: Array = []
	for repetition in range(2):
		var deck := _starter_deck()
		var party := _party()
		var enemies := _enemies([20, 20, 20, 20], CombatEnemies.OPT_IN_MAX_ENEMIES)
		_check(enemies.is_valid() and enemies.get_enemies().size() == 4, "genuine opt-in roster")
		_check(enemies.gain_block(4, 3), "fourth has Block")
		var before := _snapshot(deck, party, enemies)
		_check(resolver.play_scrap_bomb(deck, party, enemies), "standalone paid Bomb hits four")
		var expected: Array = before.enemies.duplicate(true)
		for actor in expected:
			actor.hp -= 1 if actor.position == 4 else 4
			actor.block = 0
		_check(_snapshot(deck, party, enemies) == _played_snapshot(before, expected, false),
			"fourth Block and all four damage with single payment/discard and unchanged RNG")
		replay.append(_snapshot(deck, party, enemies))
	_check(replay[0] == replay[1], "standalone seeded four-actor replay")
	var dead := _enemies([20, 20, 20, 20], CombatEnemies.OPT_IN_MAX_ENEMIES)
	_check(dead.apply_damage(4, 999), "standalone slay fourth")
	var slain := dead.get_enemy(4)
	_check(resolver.play_scrap_bomb(_starter_deck(), _party(), dead)
		and dead.get_enemy(4) == slain and dead.get_enemy(3).hp == 16,
		"standalone omits slain fourth in original slot")
	for field in ["position", "hp", "block", "statuses"]:
		var bad := _enemies([20, 20, 20, 20], CombatEnemies.OPT_IN_MAX_ENEMIES)
		bad._enemies[3][field] = {"exposed": -1} if field == "statuses" else -1
		_reject(_starter_deck(), _party(), bad, "invalid fourth " + field)


func _test_one_enemy() -> void:
	var deck := _starter_deck()
	var party := _party()
	var enemies := _enemies([10])
	_check(party.gain_block(1, 6) and party.gain_block(3, 2)
		and enemies.gain_block(1, 3), "one-enemy fixture has independent hero and enemy Block")
	var before := _snapshot(deck, party, enemies)
	_check(resolver.play_scrap_bomb(deck, party, enemies), "one present living enemy can be hit")
	_check(enemies.get_enemy(1)["block"] == 0 and enemies.get_enemy(1)["hp"] == 9,
		"three Block absorbs three damage, one reaches 10 HP")
	_check(deck.energy == 1 and deck.discard_pile.count(CARD_ID) == 1,
		"one enemy charges exactly two energy and discards one bomb")
	_check(not enemies.is_victorious(), "injured survivor is not a victory")
	var expected_enemies: Array = before["enemies"].duplicate(true)
	expected_enemies[0]["block"] = 0
	expected_enemies[0]["hp"] = 9
	_check(_snapshot(deck, party, enemies) ==
		_played_snapshot(before, expected_enemies, false),
		"entire snapshot shows only one discard, two energy and real enemy damage")


func _test_three_enemies() -> void:
	var deck := _starter_deck()
	var party := _party()
	var enemies := _enemies([10, 11, 12])
	_check(enemies.gain_block(2, 4) and enemies.gain_block(3, 6)
		and party.gain_block(2, 5), "three enemies have Block 0, 4 and 6; hero protected")
	var before := _snapshot(deck, party, enemies)
	_check(resolver.play_scrap_bomb(deck, party, enemies), "all three occupied living slots are hit")
	_check(enemies.get_enemy(1)["hp"] == 6 and enemies.get_enemy(1)["block"] == 0,
		"unblocked first enemy takes four HP damage")
	_check(enemies.get_enemy(2)["hp"] == 11 and enemies.get_enemy(2)["block"] == 0,
		"second enemy's four Block absorbs entire hit")
	_check(enemies.get_enemy(3)["hp"] == 12 and enemies.get_enemy(3)["block"] == 2,
		"third enemy retains two of six Block")
	var expected_enemies: Array = before["enemies"].duplicate(true)
	expected_enemies[0]["hp"] = 6
	expected_enemies[1]["block"] = 0
	expected_enemies[2]["block"] = 2
	_check(_snapshot(deck, party, enemies) ==
		_played_snapshot(before, expected_enemies, false),
		"all other cards/piles/RNG, hero HP/Block, turn and unrelated fields unchanged")


func _test_slain_middle_and_victory() -> void:
	var deck := _starter_deck()
	var party := _party()
	var enemies := _enemies([6, 3, 10])
	_check(enemies.apply_damage(2, 3) and enemies.is_dead(2), "middle enemy is pre-killed by real damage API")
	_check(enemies.gain_block(1, 1), "first living enemy holds one Block")
	var before := _snapshot(deck, party, enemies)
	var slain_before := enemies.get_enemy(2)
	_check(resolver.play_scrap_bomb(deck, party, enemies), "slain middle slot does not block AoE")
	_check(enemies.get_enemy(1)["hp"] == 3 and enemies.get_enemy(1)["block"] == 0,
		"first living slot takes three unblocked")
	_check(enemies.get_enemy(2) == slain_before and enemies.is_dead(2),
		"slain middle entry retains every field")
	_check(enemies.get_enemy(3)["hp"] == 6, "third slot takes four HP damage")
	_check(not enemies.is_victorious(), "mixed killed and living slots cannot declare victory")
	var expected_enemies: Array = before["enemies"].duplicate(true)
	expected_enemies[0]["hp"] = 3
	expected_enemies[0]["block"] = 0
	expected_enemies[2]["hp"] = 6
	_check(_snapshot(deck, party, enemies) ==
		_played_snapshot(before, expected_enemies, false),
		"mixed-roster play moves exactly one card and preserves all unrelated state")

	var final_deck := _deck([CARD_ID, CARD_ID, "warden_strike", "seamstress_mend", "tinker_tune_up"])
	var final_party := _party()
	var final_enemy := _enemies([4])
	_check(final_deck.hand.count(CARD_ID) == 2 and not final_enemy.is_victorious(),
		"final-kill fixture starts with a living enemy and a held duplicate")
	_check(resolver.play_scrap_bomb(final_deck, final_party, final_enemy), "four HP last enemy is killed")
	_check(final_enemy.get_enemy(1)["hp"] == 0 and final_enemy.is_dead(1)
		and final_enemy.is_victorious(), "final death alone triggers required victory query")
	_check(final_deck.end_turn() and final_deck.start_turn() and final_deck.hand.has(CARD_ID)
		and final_deck.energy == 3, "new valid turn restores energy and still holds a bomb")
	_reject(final_deck, final_party, final_enemy, "already-victorious roster despite a fresh affordable bomb")


func _test_fail_closed() -> void:
	var deck := _starter_deck()
	var party := _party()
	var enemies := _enemies([9, 8])
	_check(deck.end_turn(), "inactive fixture ends turn legitimately")
	_reject(deck, party, enemies, "inactive turn")
	var absent := _deck(["warden_strike", "seamstress_mend", "tinker_tune_up"])
	_check(not absent.hand.has(CARD_ID), "missing ID fixture holds only real other cards")
	_reject(absent, party, enemies, "missing held card")
	var low := _starter_deck()
	_check(low.try_spend_energy(2) and low.energy == 1, "low-energy fixture spends legitimately")
	_reject(low, party, enemies, "one remaining energy")
	var live := _starter_deck()
	_reject(live, _party(["warden", "seamstress", "other"]), enemies, "Tinker absent")
	var downed := _party()
	_check(downed.apply_damage(3, 26) and downed.is_downed(3), "Tinker has been downed through real rules")
	_reject(live, downed, enemies, "Tinker downed")
	for ordering in [["tinker", "warden", "seamstress"], ["warden", "tinker", "seamstress"]]:
		var ids: Array[String] = []
		ids.assign(ordering)
		var wrong_position := _party(ids)
		_check(wrong_position.is_valid(), "mispositioned Tinker fixture remains a valid party")
		_reject(live, wrong_position, enemies, "Tinker in position %d" % (ids.find("tinker") + 1))
	_reject(live, CombatParty.new([]), enemies, "invalid party")
	_reject(live, party, CombatEnemies.new([]), "empty enemy roster")
	_reject(live, party, CombatEnemies.new([{"id": "bad", "max_hp": 0}]), "invalid enemy roster")
	var already_dead := _enemies([3, 4])
	_check(already_dead.apply_damage(1, 3) and already_dead.apply_damage(2, 4)
		and already_dead.is_victorious(), "all-dead fixture reaches real victory")
	_reject(live, party, already_dead, "all-enemy victory")
	var before := _snapshot(live, party, enemies)
	_check(not resolver.play_scrap_bomb(null, party, enemies)
		and not resolver.play_scrap_bomb(live, null, enemies)
		and not resolver.play_scrap_bomb(live, party, null), "null arguments fail closed")
	_check(_snapshot(live, party, enemies) == before, "null arguments leave the live arguments untouched")


func _test_duplicate_hand() -> void:
	var deck := _deck([CARD_ID, CARD_ID, "warden_brace", "tinker_pop_shot", "seamstress_prick"])
	var party := _party()
	var enemies := _enemies([15, 13])
	_check(deck.hand.count(CARD_ID) == 2, "two duplicate IDs really reside in the drawn hand")
	var before := _snapshot(deck, party, enemies)
	_check(resolver.play_scrap_bomb(deck, party, enemies), "one duplicate can be played")
	_check(enemies.get_enemy(1)["hp"] == 11 and enemies.get_enemy(2)["hp"] == 9,
		"one AoE, not duplicate damage, on both living enemies")
	_check(deck.hand.count(CARD_ID) == 1 and deck.discard_pile.count(CARD_ID) == 1
		and deck.energy == 1, "one copy discarded and exactly two energy spent")
	var expected_enemies: Array = before["enemies"].duplicate(true)
	expected_enemies[0]["hp"] = 11
	expected_enemies[1]["hp"] = 9
	_check(_snapshot(deck, party, enemies) ==
		_played_snapshot(before, expected_enemies, false),
		"duplicate hand preserves all other copies and entire unrelated state")
	_reject(deck, party, enemies, "remaining duplicate cannot be played with only one energy")


func _replay_sequence() -> Array:
	var deck := _deck([CARD_ID, CARD_ID, "warden_strike", "tinker_tune_up", "seamstress_mend"], 42)
	var party := _party()
	var enemies := _enemies([4, 5])
	var record: Array = []
	record.append([_snapshot(deck, party, enemies), false])
	var played := resolver.play_scrap_bomb(deck, party, enemies)
	record.append([_snapshot(deck, party, enemies), played])
	_check(played and not enemies.is_victorious() and enemies.is_dead(1)
		and enemies.get_enemy(2)["hp"] == 1, "replay first AoE kills only one enemy")
	played = resolver.play_scrap_bomb(deck, party, enemies)
	record.append([_snapshot(deck, party, enemies), played])
	_check(not played and not enemies.is_victorious(), "replay low-energy rejection is nonlethal")
	_check(deck.end_turn() and deck.start_turn(), "replay uses real discard reshuffle and seeded new turn")
	record.append([_snapshot(deck, party, enemies), false])
	_check(deck.hand.has(CARD_ID), "replay re-draws the unused duplicate")
	played = resolver.play_scrap_bomb(deck, party, enemies)
	record.append([_snapshot(deck, party, enemies), played])
	_check(played and enemies.is_victorious() and enemies.is_dead(2),
		"replay second real AoE kills final enemy")
	played = resolver.play_scrap_bomb(deck, party, enemies)
	record.append([_snapshot(deck, party, enemies), played])
	_check(not played and enemies.is_victorious(), "replay rejects a post-victory play")
	return record


func _test_seeded_replay() -> void:
	var first := _replay_sequence()
	var second := _replay_sequence()
	_check(first == second, "identical seed and sequence yields identical success, HP, Block, victory, RNG and all piles at every step")
	_check(first.size() == 6, "replay checks initial, partial kill, rejection, reshuffle, final kill and post-victory")
