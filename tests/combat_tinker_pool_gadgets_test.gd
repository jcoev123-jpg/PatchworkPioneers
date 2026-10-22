extends SceneTree
## D2-1 deterministic headless tests for Tinker's Spare Parts and Sight Glass
## shared-hand utility resolution (base and plus versions).

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_spare_parts_ac1()
	_test_sight_glass_ac2()
	_test_rejections_ac3()
	_test_regressions_ac4()
	for failure in failures:
		printerr(failure)
	print("combat_tinker_pool_gadgets_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var generator = RandomNumberGenerator.new()
	generator.seed = seed_value
	return generator


func _deck(cards: Array[String], seed_value: int = 42) -> CombatDeck:
	var deck = CombatDeck.new(cards, _rng(seed_value))
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3,
		"fixture starts a real shared turn with three energy")
	return deck


func _party(order: Array = ["warden", "seamstress", "tinker"]) -> CombatParty:
	var raw = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/heroes/starter_party.json"))
	_check(raw is Array and raw.size() == 3, "real starter_party JSON has three heroes")
	var definitions = []
	if raw is Array:
		for id in order:
			for hero in raw:
				if hero.get("id") == id:
					var definition = hero.duplicate(true)
					definition["max_hp"] = int(hero["max_hp"])
					definitions.append(definition)
	var party = CombatParty.new(definitions)
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"authentic party precondition and assigned slots")
	return party


func _enemies(hps: Array = [70, 70, 70]) -> CombatEnemies:
	var definitions = []
	for index in range(hps.size()):
		definitions.append({"id": "foe_%d" % index, "max_hp": hps[index]})
	var enemies = CombatEnemies.new(definitions)
	_check(enemies.is_valid() and enemies.get_enemies().size() == hps.size(),
		"real fixed-slot enemy roster is valid and nonempty")
	return enemies


func _snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies = null) -> Dictionary:
	var snap = {"draw": deck.draw_pile.duplicate(), "hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(), "energy": deck.energy,
		"turn": deck.turn_active, "state_energy": deck.combat_state.energy,
		"state_turn": deck.combat_state.player_turn_active, "rng": deck._rng.state,
		"party": party.get_heroes()}
	if enemies != null:
		snap["enemies"] = enemies.get_enemies()
	return snap


func _full_snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies = null) -> Dictionary:
	var snap = {"draw": deck.draw_pile.duplicate(), "hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(), "energy": deck.energy,
		"turn": deck.turn_active, "state_energy": deck.combat_state.energy,
		"state_turn": deck.combat_state.player_turn_active, "rng": deck._rng.state,
		"party": party.get_heroes()}
	if enemies != null:
		snap["enemies"] = enemies.get_enemies()
	return snap


func _assert_rejection(result: Dictionary, before: Dictionary, after: Dictionary, label: String) -> void:
	_check(not result["ok"], label + " rejected")
	_check(after == before, label + " atomic: full state unchanged")


## AC1: Spare Parts and Spare Parts+ grant exact Block, draw one, discard one copy,
## zero energy, work from position 2 or 3, handle empty draw supply, no self-redraw.
func _test_spare_parts_ac1() -> void:
	var resolver = CombatTinkerPoolGadgets.new()
	var catalog = TinkerPoolCards.new()

	## Spare Parts base: Block 3, draw 1
	for card_id in ["tinker_spare_parts", "tinker_spare_parts_plus"]:
		var is_plus = card_id.ends_with("_plus")
		var expected_block = 4 if is_plus else 3

		## Tinker at position 3 (default order)
		var party = _party()
		## Add extra cards so draw_pile is not empty after initial draw
		var deck = _deck([card_id, "warden_brace", "seamstress_mend", "tinker_tune_up", "tinker_pop_shot", "extra1", "extra2"])
		var before = _snapshot(deck, party)
		var result = resolver.resolve_spare_parts(deck, party, card_id)
		_check(result == {"ok": true, "block": expected_block, "drawn": 1},
			card_id + " from pos3 accepted with exact Block and draw")
		_check(deck.energy == 3 and deck.hand.size() == 5 and deck.discard_pile == [card_id]
			and party.get_hero(3)["block"] == expected_block and party.get_hero(1)["block"] == 0
			and party.get_hero(2)["block"] == 0,
			card_id + " zero energy, one discard, Block only to Tinker")
		_check(deck.hand.has("warden_brace") and deck.hand.has("tinker_tune_up")
			and deck.hand.has("tinker_pop_shot"),
			card_id + " draw pulls from draw_pile, not self")

		## Tinker at position 2 (reordered party)
		party = _party(["warden", "tinker", "seamstress"])
		deck = _deck([card_id, "warden_brace", "seamstress_mend", "tinker_tune_up", "tinker_pop_shot", "extra1", "extra2"])
		before = _snapshot(deck, party)
		result = resolver.resolve_spare_parts(deck, party, card_id)
		_check(result == {"ok": true, "block": expected_block, "drawn": 1},
			card_id + " from pos2 accepted")
		_check(party.get_hero(2)["block"] == expected_block and party.get_hero(3)["block"] == 0,
			card_id + " Block to actual Tinker position")

		## Empty draw supply: play still succeeds, drawn = 0
		party = _party()
		deck = _deck([card_id])
		_check(deck.draw_pile.is_empty() and deck.hand == [card_id] and deck.discard_pile.is_empty(),
			card_id + " empty draw supply fixture")
		before = _snapshot(deck, party)
		result = resolver.resolve_spare_parts(deck, party, card_id)
		_check(result == {"ok": true, "block": expected_block, "drawn": 0},
			card_id + " empty draw supply still grants Block, drawn=0")
		_check(deck.energy == 3 and deck.hand.is_empty() and deck.discard_pile == [card_id]
			and party.get_hero(3)["block"] == expected_block,
			card_id + " empty draw: zero energy, one discard, Block granted")

		## No self-redraw: with one other card in discard, draw pulls that card
		party = _party()
		deck = _deck([card_id, "other_card"])
		deck.discard_played("other_card")
		_check(deck.discard_pile == ["other_card"] and deck.draw_pile.is_empty(),
			card_id + " no-self-redraw fixture: other card in discard")
		before = _snapshot(deck, party)
		result = resolver.resolve_spare_parts(deck, party, card_id)
		_check(result == {"ok": true, "block": expected_block, "drawn": 1},
			card_id + " no-self-redraw draws other_card from reshuffle")
		_check(deck.hand.has("other_card") and not deck.hand.has(card_id)
			and deck.discard_pile == [card_id],
			card_id + " drew other_card, discarded self")

		## Available reshuffle: draw pile has cards, discard has cards
		party = _party()
		deck = _deck(["draw_card1", "draw_card2", "draw_card3", card_id, "draw_card4"])
		deck.discard_played("draw_card4")
		before = _snapshot(deck, party)
		result = resolver.resolve_spare_parts(deck, party, card_id)
		_check(result == {"ok": true, "block": expected_block, "drawn": 1},
			card_id + " with available reshuffle")
		_check(deck.hand.size() == 4 and deck.discard_pile == [card_id],
			card_id + " reshuffle case: hand size and discard correct")

		## Verify both IDs work identically except Block amount
		_check(catalog.get_definition(card_id)["effects"]["block"] == expected_block,
			card_id + " catalog matches expected Block")
		_check(catalog.get_definition(card_id)["effects"]["draw"] == 1,
			card_id + " catalog draw is 1")


## AC2: Sight Glass and Sight Glass+ apply Exposed 2 to one living enemy,
## cost 1 energy, draw 1, discard one, no damage, no first-attack consumption.
func _test_sight_glass_ac2() -> void:
	var resolver = CombatTinkerPoolGadgets.new()
	var catalog = TinkerPoolCards.new()

	for card_id in ["tinker_sight_glass", "tinker_sight_glass_plus"]:
		var is_plus = card_id.ends_with("_plus")
		_check(catalog.get_definition(card_id)["effects"]["exposed"] == 2,
			card_id + " catalog Exposed is exactly 2")
		_check(catalog.get_definition(card_id)["effects"]["draw"] == 1,
			card_id + " catalog draw is 1")
		_check(catalog.get_definition(card_id)["cost"] == 1,
			card_id + " catalog cost is 1")

		## Test each target position 1, 2, 3
		for target in [1, 2, 3]:
			var party = _party(["warden", "tinker", "seamstress"])  # Tinker at pos2
			var enemies = _enemies([50, 60, 70])
			var deck = _deck([card_id, "warden_brace", "seamstress_mend", "tinker_tune_up", "tinker_pop_shot", "extra1", "extra2"])
			var before = _snapshot(deck, party, enemies)

			var result = resolver.resolve_sight_glass(deck, party, enemies, card_id, target)
			_check(result == {"ok": true, "exposed_applied": 2, "drawn": 1, "target": target},
				card_id + " target pos" + str(target) + " accepted")
			_check(deck.energy == 2 and deck.discard_pile == [card_id] and deck.hand.size() == 5,
				card_id + " spends 1 energy, discards one, draws one")
			_check(enemies.get_enemy(target)["statuses"]["exposed"] == 2,
				card_id + " Exposed 2 applied to target " + str(target))
			_check(enemies.get_enemy(target)["hp"] == before["enemies"][target - 1]["hp"],
				card_id + " no HP damage to target")
			_check(enemies.get_enemy(target)["block"] == 0,
				card_id + " no Block change to target")
			_check(party.get_heroes() == before["party"],
				card_id + " party unchanged")

			## Other enemies unchanged
			for pos in [1, 2, 3]:
				if pos != target:
					_check(enemies.get_enemy(pos).get("statuses", {}).get("exposed", 0) == 0,
						card_id + " no Exposed on non-target pos" + str(pos))

		## Exposed stacks on pre-existing Exposed
		var party = _party(["warden", "tinker", "seamstress"])
		var enemies = _enemies([50, 60, 70])
		_check(enemies.apply_statuses({2: {"exposed": 3}}), "pre-existing Exposed 3 on pos2")
		var deck = _deck([card_id, "warden_brace", "seamstress_mend", "tinker_tune_up", "tinker_pop_shot", "extra1", "extra2"])
		var before = _snapshot(deck, party, enemies)
		var result = resolver.resolve_sight_glass(deck, party, enemies, card_id, 2)
		_check(result["ok"] and result["exposed_applied"] == 2,
			card_id + " stacks on pre-existing Exposed")
		_check(enemies.get_enemy(2)["statuses"]["exposed"] == 5,
			card_id + " Exposed stacks to 5")

		## Slain middle slot excluded, slot 3 still targetable
		party = _party(["warden", "tinker", "seamstress"])
		enemies = _enemies([50, 1, 70])
		_check(enemies.apply_damage(2, 1) and enemies.is_slain(2), "middle slot slain")
		deck = _deck([card_id, "warden_brace", "seamstress_mend", "tinker_tune_up", "tinker_pop_shot", "extra1", "extra2"])
		before = _snapshot(deck, party, enemies)

		## Target slain slot 2 should reject
		result = resolver.resolve_sight_glass(deck, party, enemies, card_id, 2)
		_check(not result["ok"], card_id + " rejects slain target pos2")
		_check(_snapshot(deck, party, enemies) == before, card_id + " slain target rejection atomic")

		## Target living slot 3 should succeed
		before = _snapshot(deck, party, enemies)
		result = resolver.resolve_sight_glass(deck, party, enemies, card_id, 3)
		_check(result == {"ok": true, "exposed_applied": 2, "drawn": 1, "target": 3},
			card_id + " accepts living target pos3 with slain pos2")
		_check(enemies.get_enemy(3)["statuses"]["exposed"] == 2,
			card_id + " Exposed applied to pos3")


## AC3: Rejection table - all cases reject atomically with full snapshot equality.
func _test_rejections_ac3() -> void:
	var resolver = CombatTinkerPoolGadgets.new()

	## 1. Absent card (not in hand)
	var party = _party()
	var deck = _deck(["warden_brace"])
	var before = _full_snapshot(deck, party)
	var result = resolver.resolve_spare_parts(deck, party, "tinker_spare_parts")
	_assert_rejection(result, before, _full_snapshot(deck, party), "Spare Parts absent card")

	## 2. Inactive turn
	deck = _deck(["tinker_spare_parts"])
	deck.end_turn()
	_check(not deck.turn_active, "inactive turn fixture")
	before = _full_snapshot(deck, party)
	result = resolver.resolve_spare_parts(deck, party, "tinker_spare_parts")
	_assert_rejection(result, before, _full_snapshot(deck, party), "Spare Parts inactive turn")

	## 3. Insufficient energy for Sight Glass (cost 1)
	party = _party(["warden", "tinker", "seamstress"])
	var enemies = _enemies()
	deck = _deck(["tinker_sight_glass"])
	_check(deck.try_spend_energy(3) and deck.energy == 0, "energy exhausted fixture")
	before = _full_snapshot(deck, party, enemies)
	result = resolver.resolve_sight_glass(deck, party, enemies, "tinker_sight_glass", 1)
	_assert_rejection(result, before, _full_snapshot(deck, party, enemies), "Sight Glass insufficient energy")

	## 4. Wrong Tinker FROM position (position 1)
	party = _party(["tinker", "warden", "seamstress"])  # Tinker at front
	deck = _deck(["tinker_spare_parts"])
	before = _full_snapshot(deck, party)
	result = resolver.resolve_spare_parts(deck, party, "tinker_spare_parts")
	_assert_rejection(result, before, _full_snapshot(deck, party), "Spare Parts Tinker at pos1")

	deck = _deck(["tinker_sight_glass"])
	enemies = _enemies()
	before = _full_snapshot(deck, party, enemies)
	result = resolver.resolve_sight_glass(deck, party, enemies, "tinker_sight_glass", 1)
	_assert_rejection(result, before, _full_snapshot(deck, party, enemies), "Sight Glass Tinker at pos1")

	## 5. Downed owner
	party = _party(["warden", "tinker", "seamstress"])
	_check(party.apply_damage(2, 30) and party.is_downed(2), "Tinker downed at pos2")
	deck = _deck(["tinker_spare_parts"])
	before = _full_snapshot(deck, party)
	result = resolver.resolve_spare_parts(deck, party, "tinker_spare_parts")
	_assert_rejection(result, before, _full_snapshot(deck, party), "Spare Parts downed Tinker")

	deck = _deck(["tinker_sight_glass"])
	enemies = _enemies()
	before = _full_snapshot(deck, party, enemies)
	result = resolver.resolve_sight_glass(deck, party, enemies, "tinker_sight_glass", 1)
	_assert_rejection(result, before, _full_snapshot(deck, party, enemies), "Sight Glass downed Tinker")

	## 6. Invalid/slain selected enemy for Sight Glass
	party = _party(["warden", "tinker", "seamstress"])
	enemies = _enemies([10, 20, 30])
	deck = _deck(["tinker_sight_glass"])
	before = _full_snapshot(deck, party, enemies)
	result = resolver.resolve_sight_glass(deck, party, enemies, "tinker_sight_glass", 0)
	_assert_rejection(result, before, _full_snapshot(deck, party, enemies), "Sight Glass invalid target pos0")

	result = resolver.resolve_sight_glass(deck, party, enemies, "tinker_sight_glass", 4)
	_assert_rejection(result, before, _full_snapshot(deck, party, enemies), "Sight Glass invalid target pos4")

	_check(enemies.apply_damage(1, 10) and enemies.is_slain(1), "enemy pos1 slain")
	before = _full_snapshot(deck, party, enemies)
	result = resolver.resolve_sight_glass(deck, party, enemies, "tinker_sight_glass", 1)
	_assert_rejection(result, before, _full_snapshot(deck, party, enemies), "Sight Glass slain target pos1")

	## 7. Nonzero target passed for Spare Parts (should reject atomically)
	party = _party(["warden", "tinker", "seamstress"])
	deck = _deck(["tinker_spare_parts"])
	before = _full_snapshot(deck, party)
	result = resolver.resolve_spare_parts(deck, party, "tinker_spare_parts", 1)
	_assert_rejection(result, before, _full_snapshot(deck, party), "Spare Parts nonzero target")

	## 8. Block capacity rejection (Spare Parts)
	party = _party()
	deck = _deck(["tinker_spare_parts"])
	_check(party.gain_block(3, CombatParty.MAX_INT), "Tinker Block at MAX_INT")
	before = _full_snapshot(deck, party)
	result = resolver.resolve_spare_parts(deck, party, "tinker_spare_parts")
	_assert_rejection(result, before, _full_snapshot(deck, party), "Spare Parts Block capacity")

	## 9. Status capacity rejection (Sight Glass)
	party = _party(["warden", "tinker", "seamstress"])
	enemies = _enemies([50, 50, 50])
	deck = _deck(["tinker_sight_glass"])
	## Set enemy at position 1 to have Exposed at MAX_INT - 1 so adding 2 overflows
	_check(enemies.apply_statuses({1: {"exposed": CombatEnemies.MAX_INT - 1}}), "pre-existing Exposed near MAX_INT")
	_check(not enemies.can_apply_statuses({1: {"exposed": 2}}), "can_apply_statuses rejects overflow")
	before = _full_snapshot(deck, party, enemies)
	result = resolver.resolve_sight_glass(deck, party, enemies, "tinker_sight_glass", 1)
	_assert_rejection(result, before, _full_snapshot(deck, party, enemies), "Sight Glass status capacity")

	## 10. Equal-seed replay: valid play twice with same seed gives identical outcomes
	party = _party(["warden", "tinker", "seamstress"])
	enemies = _enemies([50, 60, 70])
	deck = _deck(["tinker_sight_glass", "warden_brace", "seamstress_mend", "tinker_tune_up", "tinker_pop_shot", "extra1", "extra2"], 12345)
	var before1 = _full_snapshot(deck, party, enemies)
	var result1 = resolver.resolve_sight_glass(deck, party, enemies, "tinker_sight_glass", 1)
	var after1 = _full_snapshot(deck, party, enemies)

	party = _party(["warden", "tinker", "seamstress"])
	enemies = _enemies([50, 60, 70])
	deck = _deck(["tinker_sight_glass", "warden_brace", "seamstress_mend", "tinker_tune_up", "tinker_pop_shot", "extra1", "extra2"], 12345)
	var before2 = _full_snapshot(deck, party, enemies)
	var result2 = resolver.resolve_sight_glass(deck, party, enemies, "tinker_sight_glass", 1)
	var after2 = _full_snapshot(deck, party, enemies)

	_check(result1 == result2, "Sight Glass equal-seed replay: results match")
	_check(after1 == after2, "Sight Glass equal-seed replay: full state matches")

	## Also test Spare Parts equal-seed replay
	party = _party()
	deck = _deck(["tinker_spare_parts", "warden_brace", "seamstress_mend", "tinker_tune_up", "tinker_pop_shot", "extra1", "extra2"], 54321)
	before1 = _full_snapshot(deck, party)
	result1 = resolver.resolve_spare_parts(deck, party, "tinker_spare_parts")
	after1 = _full_snapshot(deck, party)

	party = _party()
	deck = _deck(["tinker_spare_parts", "warden_brace", "seamstress_mend", "tinker_tune_up", "tinker_pop_shot", "extra1", "extra2"], 54321)
	before2 = _full_snapshot(deck, party)
	result2 = resolver.resolve_spare_parts(deck, party, "tinker_spare_parts")
	after2 = _full_snapshot(deck, party)

	_check(result1 == result2, "Spare Parts equal-seed replay: results match")
	_check(after1 == after2, "Spare Parts equal-seed replay: full state matches")


## AC4: Regression - catalog records unchanged, starter/support cards still work.
func _test_regressions_ac4() -> void:
	var catalog = TinkerPoolCards.new()

	## Compare catalog records before/after (they're immutable, but verify expected IDs exist)
	var required_ids = [
		"tinker_spare_parts", "tinker_spare_parts_plus",
		"tinker_sight_glass", "tinker_sight_glass_plus",
		"tinker_rivet_shot", "tinker_rivet_shot_plus",
		"tinker_scatter_bolts", "tinker_scatter_bolts_plus",
		"tinker_long_barrel", "tinker_long_barrel_plus",
		"tinker_ricochet", "tinker_ricochet_plus",
		"tinker_bobbin_cannon", "tinker_bobbin_cannon_plus",
		"tinker_spring_trap", "tinker_spring_trap_plus",
		"tinker_spool_launcher", "tinker_spool_launcher_plus",
		"tinker_overclock", "tinker_overclock_plus",
		"tinker_shrapnel_seam", "tinker_shrapnel_seam_plus",
		"tinker_bobbin_cannon", "tinker_bobbin_cannon_plus",
		"tinker_snip_the_seam", "tinker_snip_the_seam_plus"
	]
	for id in required_ids:
		_check(catalog.has_card(id), "catalog has " + id)

	## Verify Spare Parts and Sight Glass definitions unchanged
	var spare = catalog.get_definition("tinker_spare_parts")
	_check(spare["cost"] == 0 and spare["from_positions"] == [2, 3]
		and spare["target_kind"] == "self" and spare["effects"] == {"block": 3, "draw": 1},
		"Spare Parts base definition unchanged")

	var spare_plus = catalog.get_definition("tinker_spare_parts_plus")
	_check(spare_plus["cost"] == 0 and spare_plus["from_positions"] == [2, 3]
		and spare_plus["target_kind"] == "self" and spare_plus["effects"] == {"block": 4, "draw": 1},
		"Spare Parts+ definition unchanged")

	var sight = catalog.get_definition("tinker_sight_glass")
	_check(sight["cost"] == 1 and sight["from_positions"] == [2, 3]
		and sight["target_kind"] == "enemy_single" and sight["to_positions"] == [1, 2, 3]
		and sight["effects"] == {"exposed": 2, "draw": 1},
		"Sight Glass base definition unchanged")

	var sight_plus = catalog.get_definition("tinker_sight_glass_plus")
	_check(sight_plus["cost"] == 1 and sight_plus["from_positions"] == [2, 3]
		and sight_plus["target_kind"] == "enemy_single" and sight_plus["to_positions"] == [1, 2, 3]
		and sight_plus["effects"] == {"exposed": 2, "draw": 1},
		"Sight Glass+ definition unchanged (Exposed does NOT grow)")

	## Focused regressions: run StarterCards, CombatSupportCards, CombatDeck, CombatParty, CombatEnemies
	## through quick sanity checks to ensure no cross-contamination

	## StarterCards still has original Tinker cards
	var starter = StarterCards.new()
	_check(starter.has_card("tinker_pop_shot") and starter.has_card("tinker_scrap_bomb") and starter.has_card("tinker_tune_up"),
		"StarterCards retains original Tinker cards")
	_check(not starter.has_card("tinker_spare_parts") and not starter.has_card("tinker_sight_glass"),
		"StarterCards does not have pool cards")

	## CombatSupportCards: verify original support cards still resolve
	var support = CombatSupportCards.new()
	var party = _party()
	var deck = _deck(["tinker_tune_up"])
	var before = _snapshot(deck, party)
	var tune_def = starter.get_definition("tinker_tune_up")
	var support_def = {
		"id": tune_def["id"],
		"owner_id": tune_def["owner"],
		"cost": tune_def["cost"],
		"from_positions": tune_def["from_positions"],
		"effect": "draw",
		"amount": tune_def["effects"]["draw"]
	}
	_check(support.play_support(deck, party, support_def, 0), "CombatSupportCards Tune Up still works")
	_check(deck.energy == 3 and deck.discard_pile == ["tinker_tune_up"],
		"CombatSupportCards Tune Up zero cost, discards, draws")

	## CombatDeck energy/turn/draw still works
	deck = _deck(["a", "b", "c", "d", "e"])
	_check(deck.energy == 3 and deck.turn_active and deck.hand.size() == 5,
		"CombatDeck turn start unchanged")
	_check(deck.try_spend_energy(1) and deck.energy == 2, "CombatDeck energy spend")
	_check(deck.end_turn() and not deck.turn_active, "CombatDeck end turn")
	_check(deck.start_turn() and deck.energy == 3, "CombatDeck new turn")

	## CombatParty Block/HP/downed still works
	party = _party()
	_check(party.gain_block(1, 5) and party.get_hero(1)["block"] == 5, "CombatParty Block")
	_check(party.apply_damage(1, 3) and party.get_hero(1)["block"] == 2 and party.get_hero(1)["hp"] == 40,
		"CombatParty Block absorbs")
	_check(party.apply_damage(1, 5) and party.get_hero(1)["hp"] == 37, "CombatParty HP damage")
	_check(party.start_player_turn() and party.get_hero(1)["block"] == 0, "CombatParty turn reset")

	## CombatEnemies status application still works
	var enemies = _enemies([50, 60, 70])
	_check(enemies.apply_statuses({1: {"exposed": 1}, 2: {"weak": 2}}), "CombatEnemies apply statuses")
	_check(enemies.get_enemy(1)["statuses"]["exposed"] == 1 and enemies.get_enemy(2)["statuses"]["weak"] == 2,
		"CombatEnemies statuses applied")
	_check(enemies.can_apply_statuses({1: {"exposed": 1}}), "CombatEnemies can stack")
	_check(enemies.apply_statuses({1: {"exposed": 1}}) and enemies.get_enemy(1)["statuses"]["exposed"] == 2,
		"CombatEnemies Exposed stacks")