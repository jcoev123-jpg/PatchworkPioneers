extends SceneTree

var failures: Array[String] = []
var checks := 0
var service := CombatBasicAttacks.new()


func _initialize() -> void:
	_test_success()
	_test_positions_and_victory()
	_test_rejections()
	_test_replay()
	for failure in failures:
		printerr(failure)
	print("combat_basic_attacks_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var generator := RandomNumberGenerator.new()
	generator.seed = seed_value
	return generator


func _deck(cards: Array[String], seed_value: int = 42) -> CombatDeck:
	var deck := CombatDeck.new(cards, _rng(seed_value))
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3,
		"fixture starts a real shared turn with three energy")
	return deck


func _party(order: Array[String]) -> CombatParty:
	var definitions: Array = []
	for id in order:
		var max_hp := 40
		if id == "seamstress":
			max_hp = 30
		elif id == "tinker":
			max_hp = 26
		definitions.append({"id": id, "max_hp": max_hp})
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"fixture constructs three living heroes")
	return party


func _default_party() -> CombatParty:
	return _party(["warden", "seamstress", "tinker"])


func _enemies(defs: Array) -> CombatEnemies:
	var enemies := CombatEnemies.new(defs)
	_check(enemies.is_valid(), "enemy fixture is valid")
	return enemies


func _snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies) -> Array:
	return [deck.draw_pile.duplicate(), deck.hand.duplicate(), deck.discard_pile.duplicate(),
		deck.turn_active, deck.energy, deck.combat_state.player_turn_active,
		deck.combat_state.energy, party.get_heroes(), enemies.get_enemies(), deck._rng.state]


func _deck_state(deck: CombatDeck) -> Array:
	return [deck.draw_pile.duplicate(), deck.hand.duplicate(), deck.discard_pile.duplicate(),
		deck.turn_active, deck.energy, deck.combat_state.player_turn_active,
		deck.combat_state.energy, deck._rng.state]


func _rejected(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target: int, label: String) -> void:
	var before := _snapshot(deck, party, enemies)
	_check(not service.play(deck, party, enemies, card_id, target), label + ": rejected")
	_check(_snapshot(deck, party, enemies) == before,
		label + ": atomic rejection preserves piles, party, enemies, energy and RNG")


func _assert_play_snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int, damage: int, cost: int, label: String) -> void:
	var before := _snapshot(deck, party, enemies)
	_check(service.play(deck, party, enemies, card_id, target_position), label + ": accepted")
	var expected := before.duplicate(true)
	var hand: Array = expected[1]
	var hand_index := hand.find(card_id)
	_check(hand_index >= 0, label + ": played copy existed in hand")
	if hand_index >= 0:
		hand.remove_at(hand_index)
	expected[1] = hand
	var discard: Array = expected[2]
	discard.append(card_id)
	expected[2] = discard
	expected[4] = int(before[4]) - cost
	expected[6] = int(before[6]) - cost
	var enemies_before: Array = before[8]
	var enemies_expected: Array = (expected[8] as Array).duplicate(true)
	var eb: Dictionary = enemies_before[target_position - 1]
	var block_before := int(eb["block"])
	var hp_before := int(eb["hp"])
	var absorbed := mini(block_before, damage)
	var new_block := block_before - absorbed
	var new_hp := maxi(0, hp_before - (damage - absorbed))
	var ee: Dictionary = (enemies_expected[target_position - 1] as Dictionary).duplicate(true)
	ee["block"] = new_block
	ee["hp"] = new_hp
	enemies_expected[target_position - 1] = ee
	expected[8] = enemies_expected
	var after := _snapshot(deck, party, enemies)
	_check(after == expected, label + ": full expected snapshot")


func _test_success() -> void:
	# Strike: 6 damage, no block, surviving duplicate hand copy.
	var party := _default_party()
	var enemies := _enemies([{"id": "e1", "max_hp": 10}])
	var deck := _deck(["warden_strike", "warden_strike"])
	_assert_play_snapshot(deck, party, enemies, "warden_strike", 1, 6, 1, "Strike deals 6")
	_check(enemies.get_enemy(1)["hp"] == 4 and enemies.get_enemy(1)["block"] == 0,
		"Strike deals exactly 6 damage")
	_check(deck.energy == 2 and deck.hand.count("warden_strike") == 1
		and deck.discard_pile.count("warden_strike") == 1,
		"Strike spends 1 energy and moves exactly one copy to discard")

	# Overkill clamps at 0 and marks slain.
	party = _default_party()
	enemies = _enemies([{"id": "e1", "max_hp": 4}])
	deck = _deck(["warden_strike"])
	_assert_play_snapshot(deck, party, enemies, "warden_strike", 1, 6, 1, "Strike overkill")
	_check(enemies.get_enemy(1)["hp"] == 0 and enemies.is_slain(1),
		"Strike overkill clamps HP at 0")
	_check(enemies.get_enemy(1)["position"] == 1, "slain enemy retains its slot position")

	# Block absorption before HP.
	party = _default_party()
	enemies = _enemies([{"id": "e1", "max_hp": 10}])
	_check(enemies.gain_block(1, 4), "Strike block fixture gains Block")
	deck = _deck(["warden_strike"])
	_assert_play_snapshot(deck, party, enemies, "warden_strike", 1, 6, 1, "Strike into Block")
	_check(enemies.get_enemy(1)["block"] == 0 and enemies.get_enemy(1)["hp"] == 8,
		"Strike Block absorbs 4 then 2 HP damage")

	# Pop Shot: 5 damage.
	party = _default_party()
	enemies = _enemies([{"id": "e1", "max_hp": 10}, {"id": "e2", "max_hp": 10}])
	deck = _deck(["tinker_pop_shot", "tinker_pop_shot"])
	_assert_play_snapshot(deck, party, enemies, "tinker_pop_shot", 2, 5, 1, "Pop Shot deals 5")
	_check(enemies.get_enemy(2)["hp"] == 5 and enemies.get_enemy(1)["hp"] == 10,
		"Pop Shot deals exactly 5 to selected enemy only")
	_check(deck.energy == 2 and deck.hand.count("tinker_pop_shot") == 1
		and deck.discard_pile.count("tinker_pop_shot") == 1,
		"Pop Shot spends 1 energy and moves exactly one copy to discard")

	# Pop Shot block absorption.
	party = _default_party()
	enemies = _enemies([{"id": "e1", "max_hp": 10}])
	_check(enemies.gain_block(1, 3), "Pop Shot block fixture gains Block")
	deck = _deck(["tinker_pop_shot"])
	_assert_play_snapshot(deck, party, enemies, "tinker_pop_shot", 1, 5, 1, "Pop Shot into Block")
	_check(enemies.get_enemy(1)["block"] == 0 and enemies.get_enemy(1)["hp"] == 8,
		"Pop Shot Block absorbs 3 then 2 HP damage")

	# duplicate hand card survives after one play
	party = _default_party()
	enemies = _enemies([{"id": "e1", "max_hp": 10}])
	deck = _deck(["warden_strike", "warden_strike", "warden_strike"])
	service.play(deck, party, enemies, "warden_strike", 1)
	_check(deck.hand.count("warden_strike") == 2, "two matching copies remain after one play")


func _test_positions_and_victory() -> void:
	# Warden valid at position 1.
	var party := _party(["warden", "seamstress", "tinker"])
	var enemies := _enemies([{"id": "e1", "max_hp": 10}, {"id": "e2", "max_hp": 10}])
	var deck := _deck(["warden_strike"])
	_assert_play_snapshot(deck, party, enemies, "warden_strike", 1, 6, 1, "Warden at pos1 can Strike enemy 1")
	_check(enemies.get_enemy(1)["hp"] == 4, "Strike from pos1 applies damage")

	# Warden valid at position 2.
	party = _party(["seamstress", "warden", "tinker"])
	enemies = _enemies([{"id": "e1", "max_hp": 10}, {"id": "e2", "max_hp": 10}])
	deck = _deck(["warden_strike"])
	_assert_play_snapshot(deck, party, enemies, "warden_strike", 2, 6, 1, "Warden at pos2 can Strike enemy 2")
	_check(enemies.get_enemy(2)["hp"] == 4, "Strike from pos2 applies damage")

	# Warden invalid at position 3.
	party = _party(["seamstress", "tinker", "warden"])
	enemies = _enemies([{"id": "e1", "max_hp": 10}])
	deck = _deck(["warden_strike"])
	_rejected(deck, party, enemies, "warden_strike", 1, "Warden at pos3 cannot Strike")

	# Tinker valid at position 2.
	party = _party(["warden", "tinker", "seamstress"])
	enemies = _enemies([{"id": "e1", "max_hp": 10}, {"id": "e2", "max_hp": 10}, {"id": "e3", "max_hp": 10}])
	deck = _deck(["tinker_pop_shot"])
	_assert_play_snapshot(deck, party, enemies, "tinker_pop_shot", 2, 5, 1, "Tinker at pos2 can Pop Shot enemy 2")

	# Tinker valid at position 3.
	party = _default_party()
	enemies = _enemies([{"id": "e1", "max_hp": 10}, {"id": "e2", "max_hp": 10}, {"id": "e3", "max_hp": 10}])
	deck = _deck(["tinker_pop_shot"])
	_assert_play_snapshot(deck, party, enemies, "tinker_pop_shot", 3, 5, 1, "Tinker at pos3 can Pop Shot enemy 3")

	# Tinker invalid at position 1.
	party = _party(["tinker", "warden", "seamstress"])
	enemies = _enemies([{"id": "e1", "max_hp": 10}])
	deck = _deck(["tinker_pop_shot"])
	_rejected(deck, party, enemies, "tinker_pop_shot", 1, "Tinker at pos1 cannot Pop Shot")

	# Strike may hit only enemy positions 1-2.
	party = _default_party()
	enemies = _enemies([{"id": "e1", "max_hp": 10}, {"id": "e2", "max_hp": 10}, {"id": "e3", "max_hp": 10}])
	deck = _deck(["warden_strike"])
	_rejected(deck, party, enemies, "warden_strike", 3, "Strike cannot target enemy 3")
	party = _default_party()
	enemies = _enemies([{"id": "e1", "max_hp": 10}, {"id": "e2", "max_hp": 10}, {"id": "e3", "max_hp": 10}])
	deck = _deck(["warden_strike"])
	_assert_play_snapshot(deck, party, enemies, "warden_strike", 2, 6, 1, "Strike can target enemy 2")

	# Pop Shot may hit positions 1-3.
	party = _default_party()
	enemies = _enemies([{"id": "e1", "max_hp": 10}, {"id": "e2", "max_hp": 10}, {"id": "e3", "max_hp": 10}])
	deck = _deck(["tinker_pop_shot"])
	_assert_play_snapshot(deck, party, enemies, "tinker_pop_shot", 1, 5, 1, "Pop Shot can target enemy 1")

	# Last-enemy kill and no premature victory (two enemies).
	party = _default_party()
	enemies = _enemies([{"id": "e1", "max_hp": 6}, {"id": "e2", "max_hp": 6}])
	deck = _deck(["warden_strike"])
	_check(service.play(deck, party, enemies, "warden_strike", 1), "first kill accepted")
	_check(enemies.is_slain(1) and not enemies.is_victorious(),
		"first kill does not report victory while enemy 2 lives")
	_check(enemies.get_enemy(1)["position"] == 1, "slain enemy 1 retains position")
	# Re-run cleanly:
	party = _default_party()
	enemies = _enemies([{"id": "e1", "max_hp": 6}, {"id": "e2", "max_hp": 6}])
	deck = _deck(["warden_strike", "warden_strike"])
	_check(service.play(deck, party, enemies, "warden_strike", 1), "kill enemy 1")
	_check(!enemies.is_victorious(), "not victorious after first death")
	_check(enemies.get_enemy(1)["position"] == 1, "slain enemy 1 retains position")
	_check(service.play(deck, party, enemies, "warden_strike", 2), "kill enemy 2")
	_check(enemies.is_slain(2) and enemies.is_victorious(), "victory only after final enemy dies")
	_check(enemies.get_enemy(2)["position"] == 2, "slain enemy 2 retains position")

	# Single-enemy final kill reports victory.
	party = _default_party()
	enemies = _enemies([{"id": "e1", "max_hp": 6}])
	deck = _deck(["warden_strike"])
	_assert_play_snapshot(deck, party, enemies, "warden_strike", 1, 6, 1, "single enemy kill")
	_check(enemies.is_slain(1) and enemies.is_victorious(), "single enemy kill reports victory")
	_check(enemies.get_enemy(1)["position"] == 1, "single slain enemy retains position")

	# Three-enemy final kill reports victory only after last death.
	party = _default_party()
	enemies = _enemies([{"id": "e1", "max_hp": 5}, {"id": "e2", "max_hp": 5}, {"id": "e3", "max_hp": 5}])
	deck = _deck(["tinker_pop_shot", "tinker_pop_shot", "tinker_pop_shot"])
	_assert_play_snapshot(deck, party, enemies, "tinker_pop_shot", 1, 5, 1, "three-enemy kill 1")
	_check(enemies.is_slain(1) and not enemies.is_victorious(), "no victory after first of three deaths")
	_check(enemies.get_enemy(1)["position"] == 1, "slain enemy 1 retains position")
	_assert_play_snapshot(deck, party, enemies, "tinker_pop_shot", 2, 5, 1, "three-enemy kill 2")
	_check(enemies.is_slain(2) and not enemies.is_victorious(), "no victory after second of three deaths")
	_check(enemies.get_enemy(2)["position"] == 2, "slain enemy 2 retains position")
	_assert_play_snapshot(deck, party, enemies, "tinker_pop_shot", 3, 5, 1, "three-enemy kill 3")
	_check(enemies.is_slain(3) and enemies.is_victorious(), "victory only after final of three deaths")
	_check(enemies.get_enemy(3)["position"] == 3, "slain enemy 3 retains position")


func _test_rejections() -> void:
	var party := _default_party()
	var enemies := _enemies([{"id": "e1", "max_hp": 10}, {"id": "e2", "max_hp": 10}])

	# Inactive turn.
	var deck := CombatDeck.new(["warden_strike"], _rng(1))
	_rejected(deck, party, enemies, "warden_strike", 1, "inactive turn")

	# Real turn then absent hand copy.
	deck = _deck(["filler"])
	_rejected(deck, party, enemies, "warden_strike", 1, "absent hand copy")

	# Insufficient energy.
	deck = _deck(["warden_strike"])
	_check(deck.try_spend_energy(3) and deck.energy == 0, "energy exhausted fixture")
	_rejected(deck, party, enemies, "warden_strike", 1, "insufficient energy")

	# Downed owner.
	party = _default_party()
	_check(party.apply_damage(1, 40) and party.is_downed(1), "Warden downed fixture")
	enemies = _enemies([{"id": "e1", "max_hp": 10}])
	deck = _deck(["warden_strike"])
	_rejected(deck, party, enemies, "warden_strike", 1, "downed owner cannot play")

	# Wrong owner: party lacks the card owner.
	party = _party(["seamstress", "tinker", "extra"])
	enemies = _enemies([{"id": "e1", "max_hp": 10}])
	deck = _deck(["warden_strike"])
	_rejected(deck, party, enemies, "warden_strike", 1, "Strike wrong owner (no Warden)")

	party = _party(["warden", "seamstress", "extra"])
	enemies = _enemies([{"id": "e1", "max_hp": 10}])
	deck = _deck(["tinker_pop_shot"])
	_rejected(deck, party, enemies, "tinker_pop_shot", 1, "Pop Shot wrong owner (no Tinker)")

	# Nonexistent enemy slot.
	party = _default_party()
	enemies = _enemies([{"id": "e1", "max_hp": 10}])
	deck = _deck(["warden_strike"])
	_rejected(deck, party, enemies, "warden_strike", 2, "nonexistent enemy slot")

	# Slain enemy target.
	party = _default_party()
	enemies = _enemies([{"id": "e1", "max_hp": 6}])
	deck = _deck(["warden_strike", "warden_strike"])
	_check(service.play(deck, party, enemies, "warden_strike", 1), "setup kill")
	deck = _deck(["warden_strike"])
	_rejected(deck, party, enemies, "warden_strike", 1, "slain enemy untargetable")

	# Invalid target positions.
	party = _default_party()
	enemies = _enemies([{"id": "e1", "max_hp": 10}, {"id": "e2", "max_hp": 10}])
	deck = _deck(["warden_strike"])
	for bad_target in [0, -1, 4, 100]:
		_rejected(deck, party, enemies, "warden_strike", bad_target, "invalid target position " + str(bad_target))

	# Unknown card id.
	party = _default_party()
	enemies = _enemies([{"id": "e1", "max_hp": 10}])
	deck = _deck(["warden_strike"])
	_rejected(deck, party, enemies, "unknown_card", 1, "unknown card ID")

	# Seven non-basic starter cards never resolve.
	var other_ids := ["warden_brace", "warden_shield_bash", "seamstress_prick",
		"seamstress_mend", "seamstress_stitch_up", "tinker_scrap_bomb", "tinker_tune_up"]
	for other_id in other_ids:
		party = _default_party()
		enemies = _enemies([{"id": "e1", "max_hp": 10}, {"id": "e2", "max_hp": 10}, {"id": "e3", "max_hp": 10}])
		deck = _deck([other_id])
		_rejected(deck, party, enemies, other_id, 1, "non-basic card rejected: " + other_id)

	# Invalid models.
	party = _default_party()
	enemies = _enemies([{"id": "e1", "max_hp": 10}])
	deck = _deck(["warden_strike"])
	# null deck: surviving party and enemies unchanged.
	var party_before_null_deck := party.get_heroes()
	var enemies_before_null_deck := enemies.get_enemies()
	_check(not service.play(null, party, enemies, "warden_strike", 1), "null deck rejects")
	_check(party.get_heroes() == party_before_null_deck, "null deck: party unchanged")
	_check(enemies.get_enemies() == enemies_before_null_deck, "null deck: enemies unchanged")
	# null party: surviving deck and enemies unchanged.
	var deck_before_null_party := _deck_state(deck)
	var enemies_before_null_party := enemies.get_enemies()
	_check(not service.play(deck, null, enemies, "warden_strike", 1), "null party rejects")
	_check(_deck_state(deck) == deck_before_null_party, "null party: deck unchanged")
	_check(enemies.get_enemies() == enemies_before_null_party, "null party: enemies unchanged")
	# null enemies: surviving deck and party unchanged.
	var deck_before_null_enemies := _deck_state(deck)
	var party_before_null_enemies := party.get_heroes()
	_check(not service.play(deck, party, null, "warden_strike", 1), "null enemies rejects")
	_check(_deck_state(deck) == deck_before_null_enemies, "null enemies: deck unchanged")
	_check(party.get_heroes() == party_before_null_enemies, "null enemies: party unchanged")
	# invalid party/enemies objects: all surviving models unchanged via _rejected.
	var invalid_party := CombatParty.new([])
	var invalid_enemies := CombatEnemies.new([])
	_rejected(deck, invalid_party, enemies, "warden_strike", 1, "invalid party rejects")
	_rejected(deck, party, invalid_enemies, "warden_strike", 1, "invalid enemies rejects")

	# Atomic rejection for slain target preserves block/hp.
	party = _default_party()
	enemies = _enemies([{"id": "e1", "max_hp": 10}])
	_check(enemies.gain_block(1, 2), "block fixture")
	deck = _deck(["warden_strike"])
	_check(enemies.apply_damage(1, 100) and enemies.is_slain(1), "slain fixture")
	_rejected(deck, party, enemies, "warden_strike", 1, "slain target atomic")


func _test_replay() -> void:
	for seed_value in [0, 42, 987654]:
		var first := _sequence(seed_value)
		var second := _sequence(seed_value)
		_check(first.size() == 4 and second.size() == 4, "replay includes four snapshots")
		_check(first == second, "identical seeded replay matches exactly")


func _sequence(seed_value: int) -> Array:
	var party := _default_party()
	var enemies := _enemies([{"id": "e1", "max_hp": 12}, {"id": "e2", "max_hp": 8}])
	_check(enemies.gain_block(1, 3), "replay block fixture")
	var deck := _deck(["warden_strike", "tinker_pop_shot", "warden_strike", "filler"], seed_value)
	var trace: Array = [_snapshot(deck, party, enemies)]
	_check(service.play(deck, party, enemies, "warden_strike", 1), "replay Strike succeeds")
	trace.append(_snapshot(deck, party, enemies))
	_check(service.play(deck, party, enemies, "tinker_pop_shot", 2), "replay Pop Shot succeeds")
	trace.append(_snapshot(deck, party, enemies))
	_check(deck.end_turn() and deck.start_turn(), "replay refills next turn")
	trace.append(_snapshot(deck, party, enemies))
	return trace