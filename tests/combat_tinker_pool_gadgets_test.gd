extends SceneTree
## D2-1 deterministic headless tests for Tinker's Spare Parts and Sight Glass
## shared-hand utility resolution (base and plus versions), plus the M05
## wearer-only ARM/HEAD Block projection onto Spare Parts and the HEAD Exposed
## projection onto Sight Glass.

const ARM_PATCHES := "res://data/patches/m05_arm_support_patches.json"
const HEAD_PATCHES := "res://data/patches/m05_head_patches.json"
const BOTH_PATCHES := [
	{"id": "hemguard_cuff", "slot": "ARM"},
	{"id": "reinforced_browband", "slot": "HEAD"},
]
const CUFF_ONLY := [{"id": "hemguard_cuff", "slot": "ARM"}]
const BROWBAND_ONLY := [{"id": "reinforced_browband", "slot": "HEAD"}]
const SPARE_PARTS_IDS := ["tinker_spare_parts", "tinker_spare_parts_plus"]
const SIGHT_GLASS_IDS := ["tinker_sight_glass", "tinker_sight_glass_plus"]

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_spare_parts_ac1()
	_test_sight_glass_ac2()
	_test_rejections_ac3()
	_test_regressions_ac4()
	_test_wearer_block_ac1()
	_test_wearer_scope_ac2()
	_test_wearer_rejections_ac3()
	_test_visor_exposed_ac1()
	_test_visor_scope_ac2()
	_test_visor_rejections_ac3()
	_test_windup_turret_ac1()
	_test_windup_turret_ac2()
	_test_windup_turret_ac3()
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


## ---------------------------------------------------------------------------
## M05 wearer-only Block projection fixtures.
## ---------------------------------------------------------------------------

func _patch_records(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Array and not parsed.is_empty(),
		"authored patch catalog is a nonempty array: " + path)
	var records := []
	if parsed is Array:
		for entry in parsed:
			if entry is Dictionary and entry.get("id") is String and entry.get("slot") is String:
				records.append({"id": entry["id"], "slot": entry["slot"]})
	return records


## Genuine RunPatchWardrobe + RunTornMending over the real starter roster, with
## every authored M05 ARM/HEAD patch owned and the required Block patches present.
func _wearer_ledgers() -> Dictionary:
	var definitions := _patch_records(ARM_PATCHES)
	definitions.append_array(_patch_records(HEAD_PATCHES))
	var owned := []
	for record in definitions:
		owned.append(record["id"])
	_check(owned.has("hemguard_cuff") and owned.has("reinforced_browband"),
		"required wearer Block patch IDs are authored in the M05 catalogs")
	var heroes := _party().get_heroes()
	var torn := RunTornMending.new(heroes)
	var wardrobe := RunPatchWardrobe.new(heroes, owned, definitions, 5, 100,
		["warden_brace", "seamstress_prick", "tinker_spool_launcher"], 24680)
	_check(wardrobe.is_valid() and torn.is_valid(),
		"genuine wardrobe and torn ledgers are valid for the canonical roster")
	_check(wardrobe.get_snapshot().get("heroes") == torn.read_state().get("heroes"),
		"wardrobe and torn agree on the canonical hero authorities")
	return {"wardrobe": wardrobe, "torn": torn, "heroes": heroes}


## Sews the requested patches onto their wearers and binds an explicit,
## authenticated resolver to those exact ledgers.
func _bound_service(patches: Array, wearer: String = "tinker") -> Dictionary:
	var ctx := _wearer_ledgers()
	var wardrobe: RunPatchWardrobe = ctx["wardrobe"]
	var torn: RunTornMending = ctx["torn"]
	for index in range(patches.size()):
		var patch: Dictionary = patches[index]
		var target: String = patch.get("wearer", wearer)
		var sewn: Dictionary = wardrobe.sew(patch["id"], target, patch["slot"],
			"op-186-sew-%d" % index, wardrobe.get_snapshot())
		_check(sewn.get("ok") == true,
			"genuine sew of %s onto %s %s" % [patch["id"], target, patch["slot"]])
	var wardrobe_before: Dictionary = wardrobe.get_snapshot()
	var torn_before: Dictionary = torn.read_state()
	var svc := CombatTinkerPoolGadgets.new()
	var bound: bool = svc.bind_patch_wardrobe(wardrobe, torn, wardrobe_before, torn_before)
	_check(bound, "explicit authenticated bind with matching ledger snapshots")
	_check(svc.is_patch_binding_valid(), "bound ledger authorities are still current")
	_check(wardrobe.get_snapshot() == wardrobe_before,
		"binding the resolver does not mutate the wardrobe ledger")
	_check(torn.read_state() == torn_before,
		"binding the resolver does not mutate the torn ledger")
	return {"svc": svc, "wardrobe": wardrobe, "torn": torn}


func _spare_parts_deck(card_id: String, seed_value: int) -> CombatDeck:
	# Three matching copies among seven cards guarantee at least one held copy
	# and leave a seeded draw supply for the single draw.
	return _deck([card_id, card_id, card_id, "filler_a", "filler_b",
		"filler_c", "filler_d"], seed_value)


## Plays one held Spare Parts card through a genuine shared deck and party while
## keeping a real first-attack latch alongside it for the nonattack assertion.
func _play_spare_parts(svc: CombatTinkerPoolGadgets, card_id: String, order: Array,
		seed_value: int = 4242) -> Dictionary:
	var party := _party(order)
	var tinker_position: int = order.find("tinker") + 1
	var deck := _spare_parts_deck(card_id, seed_value)
	var latch := CombatTinkerFirstAttack.new()
	latch.start_player_turn()
	_check(latch.arm_path_bonus(2), "first-attack fixture arms one Path bonus")
	var before := _full_snapshot(deck, party)
	var draw_before: Array = deck.draw_pile.duplicate()
	var result = svc.resolve_spare_parts(deck, party, card_id)
	return {"result": result, "before": before, "draw_before": draw_before,
		"after": _full_snapshot(deck, party), "deck": deck, "party": party,
		"latch": latch, "tinker_position": tinker_position,
		"held_before": before["hand"].count(card_id)}


func _check_spare_parts_play(svc: CombatTinkerPoolGadgets, card_id: String, order: Array,
		expected_block: int, label: String, seed_value: int = 4242) -> Dictionary:
	var run := _play_spare_parts(svc, card_id, order, seed_value)
	var deck: CombatDeck = run["deck"]
	var party: CombatParty = run["party"]
	var tinker_position: int = run["tinker_position"]
	var held_before: int = run["held_before"]
	_check(held_before >= 1 and run["before"]["energy"] == 3,
		label + ": genuine held card with the shared three energy")
	_check(run["result"] == {"ok": true, "block": expected_block, "drawn": 1},
		label + ": exact projected Block and exactly one drawn card")
	var others_unblocked := true
	for position in range(1, 4):
		if position != tinker_position and party.get_hero(position)["block"] != 0:
			others_unblocked = false
	_check(party.get_hero(tinker_position)["block"] == expected_block and others_unblocked,
		label + ": Block goes only to the real Tinker slot")
	_check(party.get_hero(tinker_position)["hp"] == run["before"]["party"][tinker_position - 1]["hp"],
		label + ": no HP mutation")
	_check(deck.energy == 3 and deck.combat_state.energy == run["before"]["state_energy"],
		label + ": printed zero energy charged")
	_check(deck.hand.size() == 5 and deck.discard_pile == [card_id]
		and deck.hand.count(card_id) + deck.draw_pile.count(card_id) \
			+ deck.discard_pile.count(card_id) == 3,
		label + ": one drawn card and exactly one discarded copy")
	_check(deck.draw_pile == run["draw_before"].slice(0, run["draw_before"].size() - 1),
		label + ": the draw comes from the seeded pile in order")
	_check(deck._rng.state == run["before"]["rng"],
		label + ": no speculative RNG draws")
	var latch: CombatTinkerFirstAttack = run["latch"]
	_check(latch.first_hit_bonus() == 3 and latch.path_bonus() == 2
		and latch.bonus_for_attack("tinker_rivet_shot") == 5,
		label + ": first-attack and Path state untouched by a nonattack")
	_check(latch.record_successful_attack("tinker_rivet_shot")
		and latch.first_hit_bonus() == 0 and latch.path_bonus() == 0,
		label + ": a later real attack still consumes the untouched latch")
	return run


## ---------------------------------------------------------------------------
## AC1: an active Tinker-worn Hemguard Cuff ARM and/or Reinforced Browband HEAD
## raises Spare Parts Block by +2 each for base and plus, keeping one draw and
## the printed zero energy.
## ---------------------------------------------------------------------------

func _test_wearer_block_ac1() -> void:
	var canonical := ["warden", "seamstress", "tinker"]
	var middle := ["warden", "tinker", "seamstress"]
	var configs := [
		{"label": "unbound", "patches": [], "bonus": 0},
		{"label": "Hemguard Cuff only", "patches": CUFF_ONLY, "bonus": 2},
		{"label": "Threadguard Wrap only",
			"patches": [{"id": "threadguard_wrap", "slot": "ARM"}], "bonus": 1},
		{"label": "Reinforced Browband only", "patches": BROWBAND_ONLY, "bonus": 2},
		{"label": "both patches", "patches": BOTH_PATCHES, "bonus": 4},
	]
	for config in configs:
		var svc: CombatTinkerPoolGadgets
		if config["patches"].is_empty():
			svc = CombatTinkerPoolGadgets.new()
		else:
			svc = _bound_service(config["patches"])["svc"]
		for order in [canonical, middle]:
			for card_id in SPARE_PARTS_IDS:
				var authored: int = 4 if card_id.ends_with("_plus") else 3
				var label := "%s / %s / pos%d" % [config["label"], card_id,
					order.find("tinker") + 1]
				_check_spare_parts_play(svc, card_id, order,
					authored + int(config["bonus"]), label)

	## Inspectable binding: both rules are genuine, current and detached.
	var bound := _bound_service(BOTH_PATCHES)
	var bound_svc: CombatTinkerPoolGadgets = bound["svc"]
	var wardrobe: RunPatchWardrobe = bound["wardrobe"]
	var torn: RunTornMending = bound["torn"]
	_check(bound_svc.get_wardrobe() == wardrobe and bound_svc.get_torn() == torn,
		"AC1: bound resolver returns the authenticated ledgers")
	_check(bound_svc.get_patches() != null and bound_svc.get_patches().is_valid(),
		"AC1: bound resolver holds valid CombatPatchAttackRules")
	_check(bound_svc.get_head_patches() != null
		and bound_svc.get_head_patches().read_projection().get("ok") == true,
		"AC1: bound resolver holds valid CombatM05HeadPatchRules")
	_check(bound_svc.get_patches().card_block_bonus("tinker", "tinker_spare_parts") == 2
		and bound_svc.get_head_patches().get_bonus("tinker", "tinker_spare_parts", "block") == 2,
		"AC1: each authored patch contributes exactly +2 to the Spare Parts Block")

	## Two equal-seed replays leave identical deck, RNG and party traces.
	for card_id in SPARE_PARTS_IDS:
		var authored: int = 4 if card_id.ends_with("_plus") else 3
		var replay_a: CombatTinkerPoolGadgets = _bound_service(BOTH_PATCHES)["svc"]
		var replay_b: CombatTinkerPoolGadgets = _bound_service(BOTH_PATCHES)["svc"]
		var first := _check_spare_parts_play(replay_a, card_id, canonical, authored + 4,
			"AC1 replay A " + card_id, 54321)
		var second := _check_spare_parts_play(replay_b, card_id, canonical, authored + 4,
			"AC1 replay B " + card_id, 54321)
		_check(first["result"] == second["result"],
			"AC1 equal-seed replay: identical Spare Parts result for " + card_id)
		_check(first["after"] == second["after"],
			"AC1 equal-seed replay: identical party, piles, energy and RNG trace for " + card_id)
		var first_deck: CombatDeck = first["deck"]
		var second_deck: CombatDeck = second["deck"]
		_check(first_deck.draw_pile == second_deck.draw_pile
			and first_deck.discard_pile == second_deck.discard_pile
			and first_deck._rng.state == second_deck._rng.state,
			"AC1 equal-seed replay: identical draw, discard and RNG state for " + card_id)


## ---------------------------------------------------------------------------
## AC2: only the living Tinker in position 2 or 3 receives the bonus; unbound,
## another wearer or a torn Tinker keeps 3/4. Sight Glass is untouched.
## ---------------------------------------------------------------------------

func _test_wearer_scope_ac2() -> void:
	var canonical := ["warden", "seamstress", "tinker"]
	var middle := ["warden", "tinker", "seamstress"]

	## No wardrobe bound at all: the legal authored baseline.
	for card_id in SPARE_PARTS_IDS:
		var authored: int = 4 if card_id.ends_with("_plus") else 3
		_check_spare_parts_play(CombatTinkerPoolGadgets.new(), card_id, canonical,
			authored, "AC2 unbound baseline " + card_id)

	## Both patches worn by Warden: Tinker keeps the authored numbers.
	var warden_worn := _bound_service(BOTH_PATCHES, "warden")
	_check_spare_parts_play(warden_worn["svc"], "tinker_spare_parts", canonical, 3,
		"AC2 Warden-worn patches give Tinker no bonus")
	_check_spare_parts_play(warden_worn["svc"], "tinker_spare_parts_plus", middle, 4,
		"AC2 Warden-worn patches give Spare Parts+ no bonus")

	## Mixed wearers: only the patch on Tinker counts.
	var mixed := _bound_service([
		{"id": "hemguard_cuff", "slot": "ARM", "wearer": "seamstress"},
		{"id": "reinforced_browband", "slot": "HEAD", "wearer": "tinker"},
	])
	_check_spare_parts_play(mixed["svc"], "tinker_spare_parts", canonical, 5,
		"AC2 Seamstress-worn cuff contributes nothing while Tinker's Browband adds 2")
	_check_spare_parts_play(mixed["svc"], "tinker_spare_parts_plus", middle, 6,
		"AC2 mixed wearers on Spare Parts+ from position 2")

	## Tinker torn in the run ledger but still living in this combat party.
	var torn_ctx := _wearer_ledgers()
	var torn_wardrobe: RunPatchWardrobe = torn_ctx["wardrobe"]
	var torn: RunTornMending = torn_ctx["torn"]
	var heroes: Array = torn_ctx["heroes"]
	_check(torn_wardrobe.sew("hemguard_cuff", "tinker", "ARM", "op-186-torn-arm",
		torn_wardrobe.get_snapshot()).get("ok") == true, "AC2 sew cuff before the tear")
	_check(torn_wardrobe.sew("reinforced_browband", "tinker", "HEAD", "op-186-torn-head",
		torn_wardrobe.get_snapshot()).get("ok") == true, "AC2 sew browband before the tear")
	var battle_end: Array = heroes.duplicate(true)
	battle_end[2]["hp"] = 0
	_check(torn.observe_battle_end("node-186-tinker-tear", heroes.duplicate(true),
		battle_end).get("ok") == true, "AC2 battle end observed: Tinker torn")
	var torn_state: Dictionary = torn.read_state()
	_check(torn_state["heroes"][2]["hp"] == 0, "AC2 torn ledger records Tinker at zero HP")
	var stale_ctx: Dictionary = torn_wardrobe.get_snapshot()
	_check(torn_wardrobe.refresh_run_context(torn_state["heroes"], stale_ctx["owned"],
		stale_ctx["scraps"], stale_ctx["gold"], stale_ctx["cards"], stale_ctx),
		"AC2 wardrobe refresh adopts the torn roster")
	var torn_svc := CombatTinkerPoolGadgets.new()
	_check(torn_svc.bind_patch_wardrobe(torn_wardrobe, torn),
		"AC2 bind the torn ledger explicitly")
	_check(torn_svc.is_patch_binding_valid(), "AC2 torn binding is authentic and current")
	for card_id in SPARE_PARTS_IDS:
		var authored: int = 4 if card_id.ends_with("_plus") else 3
		var torn_run := _check_spare_parts_play(torn_svc, card_id, canonical, authored,
			"AC2 torn Tinker keeps authored Block for " + card_id)
		var party: CombatParty = torn_run["party"]
		_check(party.get_hero(3)["hp"] == 26 and not party.is_downed(3),
			"AC2 combat party still shows a living Tinker while the run ledger is torn")
		_check_spare_parts_play(torn_svc, card_id, middle, authored,
			"AC2 torn Tinker from position 2 keeps authored Block for " + card_id)

	## Sight Glass keeps its authored Exposed 2 / draw 1 and never gains Block.
	var bound := _bound_service(BOTH_PATCHES)
	var sight_svc: CombatTinkerPoolGadgets = bound["svc"]
	for card_id in SIGHT_GLASS_IDS:
		for target in [1, 2, 3]:
			var sight_party := _party(middle)
			var enemies := _enemies([50, 60, 70])
			var deck := _spare_parts_deck(card_id, 777)
			var before := _full_snapshot(deck, sight_party, enemies)
			var result = sight_svc.resolve_sight_glass(deck, sight_party, enemies, card_id, target)
			_check(result == {"ok": true, "exposed_applied": 2, "drawn": 1, "target": target},
				"AC2 " + card_id + " keeps Exposed 2 and one draw under the wearer bind")
			_check(enemies.get_enemy(target)["statuses"]["exposed"] == 2
				and enemies.get_enemy(target)["hp"] == before["enemies"][target - 1]["hp"],
				"AC2 " + card_id + " applies exactly Exposed 2 to target " + str(target))
			_check(deck.energy == 2 and deck.discard_pile == [card_id],
				"AC2 " + card_id + " still spends its printed one energy and discards once")
			_check(sight_party.get_heroes() == before["party"],
				"AC2 " + card_id + " grants no Block to the patched Tinker")


## ---------------------------------------------------------------------------
## AC3: stale or failed bindings, illegal positions/hand and insufficient Block
## capacity make no HP, Block, energy, draw/discard, status or RNG mutation.
## ---------------------------------------------------------------------------

func _test_wearer_rejections_ac3() -> void:
	var middle := ["warden", "tinker", "seamstress"]

	## 1. The wardrobe moves after a successful bind.
	var wardrobe_ctx := _bound_service(BOTH_PATCHES)
	var wardrobe_svc: CombatTinkerPoolGadgets = wardrobe_ctx["svc"]
	var wardrobe: RunPatchWardrobe = wardrobe_ctx["wardrobe"]
	_check(wardrobe.sew("bloodstitch_bonnet", "warden", "HEAD", "op-186-stale-head",
		wardrobe.get_snapshot()).get("ok") == true, "AC3 auxiliary sew fixture on the bound wardrobe")
	_check(not wardrobe_svc.is_patch_binding_valid(),
		"AC3 a moved wardrobe makes the binding stale")
	var party := _party()
	var deck := _spare_parts_deck("tinker_spare_parts", 4242)
	var before := _full_snapshot(deck, party)
	var result = wardrobe_svc.resolve_spare_parts(deck, party, "tinker_spare_parts")
	_assert_rejection(result, before, _full_snapshot(deck, party),
		"AC3 stale wardrobe binding")
	_check(deck._rng.state == before["rng"], "AC3 stale wardrobe binding consumes no RNG")

	## 2. The torn ledger moves after a successful bind.
	var torn_ctx := _bound_service(BOTH_PATCHES)
	var torn_svc: CombatTinkerPoolGadgets = torn_ctx["svc"]
	var torn: RunTornMending = torn_ctx["torn"]
	var heroes := _party().get_heroes()
	var battle_end: Array = heroes.duplicate(true)
	battle_end[0]["hp"] = 0
	_check(torn.observe_battle_end("node-186-stale-torn", heroes, battle_end).get("ok") == true,
		"AC3 seamstress torn after the bind")
	_check(not torn_svc.is_patch_binding_valid(),
		"AC3 a moved torn ledger makes the binding stale")
	party = _party()
	deck = _spare_parts_deck("tinker_spare_parts_plus", 4242)
	before = _full_snapshot(deck, party)
	result = torn_svc.resolve_spare_parts(deck, party, "tinker_spare_parts_plus")
	_assert_rejection(result, before, _full_snapshot(deck, party),
		"AC3 stale torn binding")
	_check(deck._rng.state == before["rng"], "AC3 stale torn binding consumes no RNG")

	## 3. Explicit bindings that fail authentication reject every later cast.
	var failed_ctx := _wearer_ledgers()
	var failed_wardrobe: RunPatchWardrobe = failed_ctx["wardrobe"]
	var failed_torn: RunTornMending = failed_ctx["torn"]
	_check(failed_wardrobe.sew("hemguard_cuff", "tinker", "ARM", "op-186-failed-arm",
		failed_wardrobe.get_snapshot()).get("ok") == true, "AC3 sew before the failed bind")
	var genuine: Dictionary = failed_wardrobe.get_snapshot()
	var wrong_snapshot: Dictionary = genuine.duplicate(true)
	wrong_snapshot["scraps"] = int(wrong_snapshot["scraps"]) + 1
	var failed_svc := CombatTinkerPoolGadgets.new()
	_check(not failed_svc.bind_patch_wardrobe(failed_wardrobe, failed_torn,
		wrong_snapshot, failed_torn.read_state()),
		"AC3 mismatched expected wardrobe rejects the explicit bind")
	_check(not failed_svc.is_patch_binding_valid(), "AC3 a failed bind stays explicit and invalid")
	party = _party()
	deck = _spare_parts_deck("tinker_spare_parts", 4242)
	before = _full_snapshot(deck, party)
	result = failed_svc.resolve_spare_parts(deck, party, "tinker_spare_parts")
	_assert_rejection(result, before, _full_snapshot(deck, party),
		"AC3 failed binding never grants a vanilla cast")

	var null_svc := CombatTinkerPoolGadgets.new()
	_check(not null_svc.bind_patch_wardrobe(null, null),
		"AC3 absent authorities reject the explicit bind")
	party = _party()
	deck = _spare_parts_deck("tinker_spare_parts_plus", 4242)
	before = _full_snapshot(deck, party)
	result = null_svc.resolve_spare_parts(deck, party, "tinker_spare_parts_plus")
	_assert_rejection(result, before, _full_snapshot(deck, party),
		"AC3 absent authorities never grant a vanilla cast")

	## 4. A torn ledger the wardrobe has not adopted fails the bind closed.
	var diverged_ctx := _wearer_ledgers()
	var diverged_wardrobe: RunPatchWardrobe = diverged_ctx["wardrobe"]
	var diverged_torn: RunTornMending = diverged_ctx["torn"]
	_check(diverged_wardrobe.sew("reinforced_browband", "tinker", "HEAD",
		"op-186-diverged-head", diverged_wardrobe.get_snapshot()).get("ok") == true,
		"AC3 sew before the roster divergence")
	var diverged_end: Array = _party().get_heroes().duplicate(true)
	diverged_end[2]["hp"] = 0
	_check(diverged_torn.observe_battle_end("node-186-diverged", _party().get_heroes(),
		diverged_end).get("ok") == true, "AC3 torn roster diverges from the wardrobe")
	var diverged_svc := CombatTinkerPoolGadgets.new()
	_check(not diverged_svc.bind_patch_wardrobe(diverged_wardrobe, diverged_torn),
		"AC3 divergent roster authorities reject the explicit bind")
	party = _party()
	deck = _spare_parts_deck("tinker_spare_parts", 4242)
	before = _full_snapshot(deck, party)
	result = diverged_svc.resolve_spare_parts(deck, party, "tinker_spare_parts")
	_assert_rejection(result, before, _full_snapshot(deck, party),
		"AC3 divergent roster binding rejects without a vanilla cast")

	## 5. Illegal position and hand with a genuine, current binding.
	var bound := _bound_service(BOTH_PATCHES)
	var svc: CombatTinkerPoolGadgets = bound["svc"]
	party = _party(["tinker", "warden", "seamstress"])
	deck = _spare_parts_deck("tinker_spare_parts", 4242)
	before = _full_snapshot(deck, party)
	result = svc.resolve_spare_parts(deck, party, "tinker_spare_parts")
	_assert_rejection(result, before, _full_snapshot(deck, party),
		"AC3 patched Spare Parts rejects Tinker at position 1")
	party = _party(middle)
	deck = _spare_parts_deck("tinker_spare_parts", 4242)
	before = _full_snapshot(deck, party)
	result = svc.resolve_spare_parts(deck, party, "tinker_spare_parts", 1)
	_assert_rejection(result, before, _full_snapshot(deck, party),
		"AC3 patched Spare Parts rejects a false target")
	deck = _deck(["warden_brace", "seamstress_mend", "tinker_tune_up",
		"tinker_pop_shot", "extra1"], 4242)
	before = _full_snapshot(deck, party)
	result = svc.resolve_spare_parts(deck, party, "tinker_spare_parts")
	_assert_rejection(result, before, _full_snapshot(deck, party),
		"AC3 patched Spare Parts rejects a missing hand card")

	## 6. Held IDs whose authored definition is not a zero-cost self Block draw.
	for invalid_id in ["tinker_rivet_shot", "tinker_spare_parts_stale"]:
		party = _party(middle)
		deck = _spare_parts_deck(invalid_id, 4242)
		_check(deck.hand.has(invalid_id), "AC3 held invalid definition fixture: " + invalid_id)
		before = _full_snapshot(deck, party)
		result = svc.resolve_spare_parts(deck, party, invalid_id)
		_assert_rejection(result, before, _full_snapshot(deck, party),
			"AC3 invalid definition rejected: " + invalid_id)

	## 7. Block capacity is capped before any party/deck mutation.
	var capacity_party := _party()
	_check(capacity_party.gain_block(3, CombatParty.MAX_INT - 6),
		"AC3 Tinker Block near capacity fixture")
	var capacity_deck := _spare_parts_deck("tinker_spare_parts", 4242)
	var capacity_before := _full_snapshot(capacity_deck, capacity_party)
	var capacity_result = svc.resolve_spare_parts(capacity_deck, capacity_party,
		"tinker_spare_parts")
	_assert_rejection(capacity_result, capacity_before,
		_full_snapshot(capacity_deck, capacity_party), "AC3 patched Block above capacity")
	_check(capacity_deck._rng.state == capacity_before["rng"],
		"AC3 capacity rejection consumes no RNG")

	## The authored 3 fits where the patched 7 does not, and an exact fit succeeds.
	var authored_party := _party()
	_check(authored_party.gain_block(3, CombatParty.MAX_INT - 6),
		"AC3 near-capacity unbound fixture")
	var authored_deck := _spare_parts_deck("tinker_spare_parts", 4242)
	var authored_result = CombatTinkerPoolGadgets.new().resolve_spare_parts(
		authored_deck, authored_party, "tinker_spare_parts")
	_check(authored_result == {"ok": true, "block": 3, "drawn": 1},
		"AC3 the authored 3 still fits where the patched 7 does not")
	var exact_party := _party()
	_check(exact_party.gain_block(3, CombatParty.MAX_INT - 7),
		"AC3 exact patched capacity fixture")
	var exact_deck := _spare_parts_deck("tinker_spare_parts", 4242)
	var exact_result = svc.resolve_spare_parts(exact_deck, exact_party, "tinker_spare_parts")
	_check(exact_result == {"ok": true, "block": 7, "drawn": 1}
		and exact_party.get_hero(3)["block"] == CombatParty.MAX_INT,
		"AC3 an exactly fitting patched Block still lands and caps at MAX_INT")

	## 8. Insufficient energy and no RNG mutation, with a current binding.
	party = _party(middle)
	var enemies := _enemies()
	deck = _spare_parts_deck("tinker_sight_glass", 4242)
	_check(deck.try_spend_energy(3) and deck.energy == 0, "AC3 energy exhausted fixture")
	before = _full_snapshot(deck, party, enemies)
	result = svc.resolve_sight_glass(deck, party, enemies, "tinker_sight_glass", 1)
	_assert_rejection(result, before, _full_snapshot(deck, party, enemies),
		"AC3 bound Sight Glass still rejects insufficient energy")
	_check(deck._rng.state == before["rng"],
		"AC3 insufficient energy consumes no RNG")

	## 9. A stale or failed binding rejects Sight Glass before any deck mutation,
	## and a fresh current bind without a Visor keeps the authored Exposed 2.
	party = _party(middle)
	enemies = _enemies([50, 60, 70])
	deck = _sight_deck("tinker_sight_glass", 4242)
	before = _full_snapshot(deck, party, enemies)
	result = wardrobe_svc.resolve_sight_glass(deck, party, enemies, "tinker_sight_glass", 2)
	_assert_rejection(result, before, _full_snapshot(deck, party, enemies),
		"AC3 Sight Glass rejects a stale wearer binding")
	_check(deck._rng.state == before["rng"],
		"AC3 stale wearer binding Sight Glass consumes no RNG")

	var fresh_svc: CombatTinkerPoolGadgets = _bound_service(BOTH_PATCHES)["svc"]
	party = _party(middle)
	enemies = _enemies([50, 60, 70])
	deck = _sight_deck("tinker_sight_glass", 4242)
	result = fresh_svc.resolve_sight_glass(deck, party, enemies, "tinker_sight_glass", 2)
	_check(result == {"ok": true, "exposed_applied": 2, "drawn": 1, "target": 2},
		"AC3 a current ARM/HEAD bind without a Visor keeps the authored Exposed 2")
	_check(enemies.get_enemy(2)["statuses"]["exposed"] == 2 and deck.energy == 2,
		"AC3 Sight Glass applies only Exposed 2 and its printed energy")


## ---------------------------------------------------------------------------
## Wind-up Turret: detached three-beat seeded end-of-turn effect.
## ---------------------------------------------------------------------------

func _test_windup_turret_ac1() -> void:
	var svc := CombatTinkerPoolGadgets.new()
	var first_state := svc.create_wind_up_turret()
	var second_state := svc.create_wind_up_turret()
	_check(first_state.get("remaining") == 3, "AC1 turret state reports 3 pending beats")
	_check(second_state.get("remaining") == 3, "AC1 second turret state reports 3 pending beats")
	for key in ["remaining", "remaining_beats", "ticks_remaining", "pending"]:
		_check(first_state.get(key) == 3 and second_state.get(key) == 3,
			"AC1 state alias " + key + " is 3")

	## Independent counters: ticking one does not touch the other.
	var enemies := _enemies([10, 10, 10])
	var rng := _rng(123)
	var first_state_before := first_state.duplicate(true)
	var result := svc.resolve_wind_up_turret(first_state, enemies, rng)
	_check(result.get("ok") == true, "AC1 first tick resolves")
	_check(first_state == first_state_before, "AC1 first state untouched")
	_check(result.get("state").get("remaining") == 2, "AC1 first counter decremented in result state")
	_check(second_state.get("remaining") == 3, "AC1 second counter untouched")


func _test_windup_turret_ac2() -> void:
	var svc := CombatTinkerPoolGadgets.new()
	var enemies := _enemies([10, 20, 30])
	_check(enemies.gain_block(1, 1) and enemies.gain_block(2, 2) and enemies.gain_block(3, 3),
		"AC2 distinct Block fixtures")
	var seed := 98765
	var state := svc.create_wind_up_turret()
	var rng := _rng(seed)
	var oracle := _rng(seed)

	var beat: int = 0
	var rng_state_before_beat1: int = rng.state
	while beat < 3:
		## Independent oracle predicts the target from living positions.
		var living: Array[int] = []
		for enemy in enemies.get_enemies():
			if int(enemy.get("hp", 0)) > 0:
				living.append(int(enemy.get("position", 0)))
		living.sort()
		var expected_target: int = 0
		if living.size() >= 2:
			expected_target = living[oracle.randi_range(0, living.size() - 1)]
		elif living.size() == 1:
			expected_target = living[0]

		var block_before: int = 0
		var hp_before: int = 0
		if expected_target > 0:
			var eb: Dictionary = enemies.get_enemy(expected_target)
			block_before = int(eb.get("block", 0))
			hp_before = int(eb.get("hp", 0))

		var rng_before: int = rng.state
		var state_before: Dictionary = state.duplicate(true)
		var enemies_before: Dictionary = {}
		for enemy in enemies.get_enemies():
			enemies_before[int(enemy.get("position"))] = enemy.duplicate(true)

		var res: Dictionary = svc.resolve_wind_up_turret(state, enemies, rng)
		_check(res.get("ok") == true, "AC2 beat %d resolves" % (beat + 1))
		_check(int(res.get("target", 0)) == expected_target,
			"AC2 beat %d chosen position matches oracle" % (beat + 1))
		_check(int(res.get("remaining", -1)) == 2 - beat,
			"AC2 beat %d remaining count" % (beat + 1))
		
		_check(state == state_before, "AC2 beat %d state untouched" % (beat + 1))
		state = res.get("state")
		_check(state.get("remaining") == 2 - beat,
			"AC2 beat %d next-state decremented" % (beat + 1))

		for enemy in enemies.get_enemies():
			var pos = int(enemy.get("position"))
			if pos != expected_target:
				_check(enemy == enemies_before[pos], "AC2 beat %d non-target enemy unchanged" % (beat + 1))

		if expected_target > 0:
			var absorbed: int = mini(block_before, 3)
			var hp_loss: int = mini(hp_before, 3 - absorbed)
			_check(int(res.get("block_absorbed", -1)) == absorbed,
				"AC2 beat %d actual Block absorbed" % (beat + 1))
			_check(int(res.get("hp_lost", -1)) == hp_loss,
				"AC2 beat %d actual HP lost" % (beat + 1))
			_check(enemies.get_enemy(expected_target).get("hp", -1) == hp_before - hp_loss,
				"AC2 beat %d enemy HP updated" % (beat + 1))
			_check(enemies.get_enemy(expected_target).get("block", -1) == block_before - absorbed,
				"AC2 beat %d enemy Block updated" % (beat + 1))

		## RNG consumption matches living count.
		if living.size() >= 2:
			_check(rng.state != rng_before, "AC2 beat %d consumed one draw" % (beat + 1))
		else:
			_check(rng.state == rng_before, "AC2 beat %d consumed no draw" % (beat + 1))

		beat += 1

	## Fourth tick is inert.
	var rng_before4: int = rng.state
	var state_before4: Dictionary = state.duplicate(true)
	var res4: Dictionary = svc.resolve_wind_up_turret(state, enemies, rng)
	_check(res4.get("ok") == false, "AC2 fourth tick has no effect")
	_check(state == state_before4, "AC2 fourth tick leaves state unchanged")
	_check(rng.state == rng_before4, "AC2 fourth tick consumes no RNG")
	_check(enemies.is_valid(), "AC2 roster still valid after fourth")

	## Equal seed repeats the same result.
	var enemies2 := _enemies([10, 20, 30])
	_check(enemies2.gain_block(1, 1) and enemies2.gain_block(2, 2) and enemies2.gain_block(3, 3),
		"AC2 replay Block fixtures")
	var state2 := svc.create_wind_up_turret()
	var rng2 := _rng(seed)
	var oracle2 := _rng(seed)
	var targets_a: Array[int] = []
	var targets_b: Array[int] = []
	## Replay only first beat target for determinism check.
	var living_r: Array[int] = [1, 2, 3]
	var expected_r: int = living_r[oracle2.randi_range(0, 2)]
	targets_a.append(expected_r)
	var res_r: Dictionary = svc.resolve_wind_up_turret(state2, enemies2, rng2)
	targets_b.append(int(res_r.get("target", 0)))
	_check(targets_a == targets_b, "AC2 equal seed yields same first target")


func _test_windup_turret_ac3() -> void:
	var svc := CombatTinkerPoolGadgets.new()

	## Single living foe: no RNG draw.
	var single_enemies := _enemies([10, 10, 10])
	_check(single_enemies.apply_damage(1, 10) and single_enemies.is_slain(1), "AC3 slay pos1")
	_check(single_enemies.apply_damage(3, 10) and single_enemies.is_slain(3), "AC3 slay pos3")
	var single_state := svc.create_wind_up_turret()
	var single_rng := _rng(555)
	var single_rng_before: int = single_rng.state
	var single_state_before := single_state.duplicate(true)
	var single_res := svc.resolve_wind_up_turret(single_state, single_enemies, single_rng)
	_check(single_res.get("ok") == true, "AC3 single living resolves")
	_check(int(single_res.get("target", 0)) == 2, "AC3 single living targets pos2")
	_check(single_rng.state == single_rng_before, "AC3 single living consumes no RNG")
	_check(single_state == single_state_before, "AC3 single living leaves input state unchanged")
	_check(single_res.get("state").get("remaining") == 2, "AC3 single living next-state decrements")

	## Dead middle: never target dead slot; one draw for two living.
	var middle_enemies := _enemies([10, 10, 10])
	_check(middle_enemies.apply_damage(2, 10) and middle_enemies.is_slain(2), "AC3 slay middle")
	var middle_state := svc.create_wind_up_turret()
	var middle_rng := _rng(777)
	var middle_rng_before: int = middle_rng.state
	var middle_state_before := middle_state.duplicate(true)
	var middle_res := svc.resolve_wind_up_turret(middle_state, middle_enemies, middle_rng)
	_check(middle_res.get("ok") == true, "AC3 dead-middle resolves")
	_check(int(middle_res.get("target", 0)) in [1, 3], "AC3 dead-middle avoids pos2")
	_check(middle_rng.state != middle_rng_before, "AC3 dead-middle consumes one draw")
	_check(middle_state == middle_state_before, "AC3 dead-middle leaves input state unchanged")
	_check(middle_res.get("state").get("remaining") == 2, "AC3 dead-middle next-state decrements")

	## No living foes: no target, no damage, no RNG, decrements.
	var none_enemies := _enemies([10, 10, 10])
	for pos in [1, 2, 3]:
		_check(none_enemies.apply_damage(pos, 10) and none_enemies.is_slain(pos), "AC3 slay pos%d" % pos)
	var none_state := svc.create_wind_up_turret()
	var none_rng := _rng(999)
	var none_rng_before: int = none_rng.state
	var none_before_snap := none_enemies.get_enemies()
	var none_state_before := none_state.duplicate(true)
	var none_res := svc.resolve_wind_up_turret(none_state, none_enemies, none_rng)
	_check(none_res.get("ok") == true, "AC3 no-living resolves")
	_check(int(none_res.get("target", 0)) == 0, "AC3 no-living no target")
	_check(int(none_res.get("damage", 0)) == 0, "AC3 no-living no damage")
	_check(none_rng.state == none_rng_before, "AC3 no-living no RNG")
	_check(none_enemies.get_enemies() == none_before_snap, "AC3 no-living enemies unchanged")
	_check(none_state == none_state_before, "AC3 no-living leaves input state unchanged")
	_check(none_res.get("state").get("remaining") == 2, "AC3 no-living next-state decrements")

	## Invalid state rejects atomically.
	var valid_enemies := _enemies([10, 10, 10])
	var valid_rng := _rng(1)
	var bad_state := {"remaining": 99}
	var snap_enemies := valid_enemies.get_enemies()
	var rng_before := valid_rng.state
	var bad_res := svc.resolve_wind_up_turret(bad_state, valid_enemies, valid_rng)
	_check(bad_res.get("ok") == false, "AC3 malformed state rejects")
	_check(valid_enemies.get_enemies() == snap_enemies, "AC3 malformed state enemies unchanged")
	_check(valid_rng.state == rng_before, "AC3 malformed state no RNG")

	## Null roster rejects.
	var st := svc.create_wind_up_turret()
	var rng2 := _rng(2)
	var before_rng2 := rng2.state
	var null_res := svc.resolve_wind_up_turret(st, null, rng2)
	_check(null_res.get("ok") == false, "AC3 null roster rejects")
	_check(rng2.state == before_rng2, "AC3 null roster no RNG")

	## Null RNG rejects.
	var st2 := svc.create_wind_up_turret()
	var en2 := _enemies([10, 10, 10])
	var snap_en2 := en2.get_enemies()
	var null_rng_res := svc.resolve_wind_up_turret(st2, en2, null)
	_check(null_rng_res.get("ok") == false, "AC3 null RNG rejects")
	_check(en2.get_enemies() == snap_en2, "AC3 null RNG enemies unchanged")
	_check(st2.get("remaining") == 3, "AC3 null RNG state unchanged")

	## Invalid roster (empty definitions) rejects.
	var invalid_enemies := CombatEnemies.new([])
	_check(not invalid_enemies.is_valid(), "AC3 invalid roster fixture")
	var st3 := svc.create_wind_up_turret()
	var rng3 := _rng(3)
	var before3 := rng3.state
	var invalid_res := svc.resolve_wind_up_turret(st3, invalid_enemies, rng3)
	_check(invalid_res.get("ok") == false, "AC3 invalid roster rejects")
	_check(rng3.state == before3, "AC3 invalid roster no RNG")
	_check(st3.get("remaining") == 3, "AC3 invalid roster state unchanged")

## ---------------------------------------------------------------------------
## M05 HEAD Exposed projection fixtures (Button Glass Visor: HEAD,
## card_exposed_bonus +1).
## ---------------------------------------------------------------------------

const VISOR := [{"id": "button_glass_visor", "slot": "HEAD"}]


func _sight_deck(card_id: String, seed_value: int) -> CombatDeck:
	# Three matching copies among seven guarantee a held copy and leave a
	# seeded draw supply for the single draw.
	return _spare_parts_deck(card_id, seed_value)


## Plays one held Sight Glass through a genuine shared deck, party and enemy
## roster, asserting the exact receipt, the chosen target and every unchanged
## authority.
func _check_sight_glass_play(svc: CombatTinkerPoolGadgets, card_id: String,
		order: Array, target: int, expected_exposed: int, label: String,
		seed_value: int = 4242) -> Dictionary:
	var party := _party(order)
	var enemies := _enemies([50, 60, 70])
	var deck := _sight_deck(card_id, seed_value)
	var before := _full_snapshot(deck, party, enemies)
	var draw_before: Array = deck.draw_pile.duplicate()
	var tinker_position: int = order.find("tinker") + 1
	_check(before["hand"].count(card_id) >= 1 and before["energy"] == 3,
		label + ": genuine held copy with the shared three energy")
	_check(party.get_hero(tinker_position)["id"] == "tinker"
		and not party.is_downed(tinker_position),
		label + ": the resolving Tinker slot is genuine and living")
	var result = svc.resolve_sight_glass(deck, party, enemies, card_id, target)
	_check(result == {"ok": true, "exposed_applied": expected_exposed,
		"drawn": 1, "target": target},
		label + ": exact applied Exposed, one draw and the chosen target")
	_check(enemies.get_enemy(target)["statuses"]["exposed"] == expected_exposed,
		label + ": projected Exposed lands on the chosen enemy")
	_check(enemies.get_enemy(target)["hp"] == before["enemies"][target - 1]["hp"]
		and enemies.get_enemy(target)["block"] == before["enemies"][target - 1]["block"],
		label + ": no HP or Block change to the target")
	var others_clean := true
	for position in range(1, 4):
		if position != target \
				and enemies.get_enemy(position).get("statuses", {}).get("exposed", 0) != 0:
			others_clean = false
	_check(others_clean, label + ": no Exposed leaks to the other enemy slots")
	_check(party.get_heroes() == before["party"],
		label + ": no hero HP or Block mutation")
	_check(deck.energy == 2 and deck.combat_state.energy == int(before["state_energy"]) - 1,
		label + ": exactly the printed one energy charged")
	_check(deck.hand.size() == 5 and deck.discard_pile == [card_id]
		and deck.hand.count(card_id) + deck.draw_pile.count(card_id) \
			+ deck.discard_pile.count(card_id) == 3,
		label + ": one drawn card and exactly one discarded copy")
	_check(deck.draw_pile == draw_before.slice(0, draw_before.size() - 1),
		label + ": the draw comes from the seeded pile in order")
	_check(deck._rng.state == before["rng"],
		label + ": no speculative RNG draws")
	return {"result": result, "deck": deck, "party": party, "enemies": enemies,
		"before": before, "after": _full_snapshot(deck, party, enemies)}


## ---------------------------------------------------------------------------
## AC1: with the Button Glass Visor genuinely sewn to a living Tinker, a legal
## base or plus Sight Glass applies Exposed 3 (2 printed +1 wearer HEAD), draws
## one, charges one energy and discards one held copy.
## ---------------------------------------------------------------------------

func _test_visor_exposed_ac1() -> void:
	var canonical := ["warden", "seamstress", "tinker"]
	var middle := ["warden", "tinker", "seamstress"]

	var bound := _bound_service(VISOR)
	var svc: CombatTinkerPoolGadgets = bound["svc"]
	var heads: CombatM05HeadPatchRules = svc.get_head_patches()
	_check(heads != null and heads.read_projection().get("ok") == true,
		"AC1 visor fixture holds a valid, current HEAD projection")
	for card_id in SIGHT_GLASS_IDS:
		_check(heads.get_bonus("tinker", card_id, "exposed") == 1,
			"AC1 the genuine Tinker-worn Visor projects +1 Exposed for " + card_id)
	_check(heads.get_bonus("tinker", "tinker_spare_parts", "exposed") == 0
		and heads.get_bonus("tinker", "tinker_spare_parts", "block") == 0
		and heads.get_bonus("tinker", "tinker_sight_glass", "block") == 0,
		"AC1 the Visor projects no Exposed onto Spare Parts and no Block at all")

	## Two legal Tinker positions (2 and 3) with two targets each, both IDs.
	for order in [canonical, middle]:
		for card_id in SIGHT_GLASS_IDS:
			for target in [1, 3]:
				_check_sight_glass_play(svc, card_id, order, target, 3,
					"AC1 Visor / %s / pos%d -> target %d" % [card_id,
						order.find("tinker") + 1, target])

	## The projection stays additive on a target that is already Exposed.
	var stack_party := _party(middle)
	var stack_enemies := _enemies([50, 60, 70])
	_check(stack_enemies.apply_statuses({1: {"exposed": 3}}),
		"AC1 pre-existing Exposed 3 fixture")
	var stack_deck := _sight_deck("tinker_sight_glass", 4242)
	var stack_result = svc.resolve_sight_glass(stack_deck, stack_party, stack_enemies,
		"tinker_sight_glass", 1)
	_check(stack_result == {"ok": true, "exposed_applied": 3, "drawn": 1, "target": 1},
		"AC1 a stacking Visor cast reports its full applied amount")
	_check(stack_enemies.get_enemy(1)["statuses"]["exposed"] == 6,
		"AC1 projected Exposed 3 stacks on pre-existing Exposed 3")
	_check(stack_deck.energy == 2
		and stack_deck.discard_pile == ["tinker_sight_glass"],
		"AC1 the stacking cast still spends one energy and discards once")

	## Equal-seed replays of the projected cast leave identical traces.
	for card_id in SIGHT_GLASS_IDS:
		var replay_a_svc: CombatTinkerPoolGadgets = _bound_service(VISOR)["svc"]
		var replay_b_svc: CombatTinkerPoolGadgets = _bound_service(VISOR)["svc"]
		var first := _check_sight_glass_play(replay_a_svc, card_id, canonical, 2, 3,
			"AC1 replay A " + card_id, 98765)
		var second := _check_sight_glass_play(replay_b_svc, card_id, canonical, 2, 3,
			"AC1 replay B " + card_id, 98765)
		_check(first["result"] == second["result"],
			"AC1 equal-seed replay: identical Visor result for " + card_id)
		_check(first["after"] == second["after"],
			"AC1 equal-seed replay: identical party, enemies, piles, energy and RNG for "
				+ card_id)


## ---------------------------------------------------------------------------
## AC2: no valid Tinker-worn Visor means the authored Exposed 2, and other ARM
## or HEAD patches keep Spare Parts at its authored Block plus only its own
## eligible wearer bonuses.
## ---------------------------------------------------------------------------

func _test_visor_scope_ac2() -> void:
	var canonical := ["warden", "seamstress", "tinker"]
	var middle := ["warden", "tinker", "seamstress"]

	## No bind at all: the legal authored baseline.
	for card_id in SIGHT_GLASS_IDS:
		_check_sight_glass_play(CombatTinkerPoolGadgets.new(), card_id, middle, 2, 2,
			"AC2 unbound baseline " + card_id)

	## The same Visor sewn onto another hero never helps the Tinker cast.
	var warden_worn := _bound_service(VISOR, "warden")
	var warden_heads: CombatM05HeadPatchRules = warden_worn["svc"].get_head_patches()
	_check(warden_heads != null
		and warden_heads.get_bonus("tinker", "tinker_sight_glass", "exposed") == 0,
		"AC2 a Warden-worn Visor projects nothing onto the Tinker cast")
	_check_sight_glass_play(warden_worn["svc"], "tinker_sight_glass", canonical, 1, 2,
		"AC2 Warden-worn Visor keeps Sight Glass at Exposed 2")
	_check_sight_glass_play(warden_worn["svc"], "tinker_sight_glass_plus", middle, 3, 2,
		"AC2 Warden-worn Visor keeps Sight Glass+ at Exposed 2")

	## The ARM/HEAD Block patches never turn into Exposed on Sight Glass.
	var both := _bound_service(BOTH_PATCHES)
	for card_id in SIGHT_GLASS_IDS:
		_check_sight_glass_play(both["svc"], card_id, middle, 3, 2,
			"AC2 Cuff/Browband keep Sight Glass at the authored Exposed 2 for " + card_id)
	for card_id in SPARE_PARTS_IDS:
		var authored: int = 4 if card_id.ends_with("_plus") else 3
		_check_spare_parts_play(both["svc"], card_id, canonical, authored + 4,
			"AC2 Cuff/Browband still add only their own Block for " + card_id)

	## The Visor is a HEAD Exposed patch: it grants Spare Parts no Block.
	var visor_only := _bound_service(VISOR)
	_check(visor_only["svc"].get_patches().card_block_bonus("tinker", "tinker_spare_parts") == 0,
		"AC2 the HEAD Visor is not read as an ARM Block patch")
	for card_id in SPARE_PARTS_IDS:
		var authored: int = 4 if card_id.ends_with("_plus") else 3
		_check_spare_parts_play(visor_only["svc"], card_id, canonical, authored,
			"AC2 the Visor grants Spare Parts no Block for " + card_id)

	## Legal mixed slots: Visor HEAD plus Hemguard Cuff ARM at the same time.
	var visor_and_cuff := _bound_service([
		{"id": "button_glass_visor", "slot": "HEAD"},
		{"id": "hemguard_cuff", "slot": "ARM"},
	])
	_check_sight_glass_play(visor_and_cuff["svc"], "tinker_sight_glass", canonical, 3, 3,
		"AC2 Visor plus Cuff still applies exactly Exposed 3")
	_check_spare_parts_play(visor_and_cuff["svc"], "tinker_spare_parts", middle, 5,
		"AC2 Visor plus Cuff keeps Spare Parts at authored 3 plus the ARM 2")

	## Only its living, untorn wearer receives the bonus: a Tinker the run ledger
	## has torn keeps Exposed 2 even while this combat party still shows her up.
	var torn_ctx := _wearer_ledgers()
	var torn_wardrobe: RunPatchWardrobe = torn_ctx["wardrobe"]
	var torn: RunTornMending = torn_ctx["torn"]
	var torn_heroes: Array = torn_ctx["heroes"]
	_check(torn_wardrobe.sew("button_glass_visor", "tinker", "HEAD",
		"op-186-visor-tear", torn_wardrobe.get_snapshot()).get("ok") == true,
		"AC2 sew the Visor before the tear")
	var torn_end: Array = torn_heroes.duplicate(true)
	torn_end[2]["hp"] = 0
	_check(torn.observe_battle_end("node-186-visor-tear", torn_heroes.duplicate(true),
		torn_end).get("ok") == true, "AC2 battle end observed: Tinker torn under the Visor")
	var torn_state: Dictionary = torn.read_state()
	var torn_ledger: Dictionary = torn_wardrobe.get_snapshot()
	_check(torn_wardrobe.refresh_run_context(torn_state["heroes"], torn_ledger["owned"],
		torn_ledger["scraps"], torn_ledger["gold"], torn_ledger["cards"], torn_ledger),
		"AC2 wardrobe refresh adopts the torn roster")
	var torn_svc := CombatTinkerPoolGadgets.new()
	_check(torn_svc.bind_patch_wardrobe(torn_wardrobe, torn),
		"AC2 bind the torn ledger explicitly under the Visor")
	_check(torn_svc.is_patch_binding_valid(),
		"AC2 the torn Visor binding is authentic and current")
	var torn_heads: CombatM05HeadPatchRules = torn_svc.get_head_patches()
	_check(torn_heads != null
		and torn_heads.get_bonus("tinker", "tinker_sight_glass", "exposed") == 0,
		"AC2 a torn Tinker's Visor projects no Exposed bonus")
	var torn_run := _check_sight_glass_play(torn_svc, "tinker_sight_glass", canonical, 2, 2,
		"AC2 torn Tinker under the Visor keeps the authored Exposed 2")
	var torn_party: CombatParty = torn_run["party"]
	_check(torn_party.get_hero(3)["hp"] == 26 and not torn_party.is_downed(3),
		"AC2 the combat party still shows a living Tinker while the run ledger is torn")


## ---------------------------------------------------------------------------
## AC3: a stale or failed Visor bind, a downed owner, an illegal target or
## from-position, a missing held copy, insufficient energy or exhausted status
## capacity changes no party, enemy, hand, energy, discard or RNG state.
## ---------------------------------------------------------------------------

func _test_visor_rejections_ac3() -> void:
	var canonical := ["warden", "seamstress", "tinker"]
	var middle := ["warden", "tinker", "seamstress"]

	## 1. The wardrobe moves after a successful Visor bind.
	var stale_ctx := _bound_service(VISOR)
	var stale_svc: CombatTinkerPoolGadgets = stale_ctx["svc"]
	var stale_wardrobe: RunPatchWardrobe = stale_ctx["wardrobe"]
	_check(stale_wardrobe.sew("bloodstitch_bonnet", "warden", "HEAD",
		"op-186-visor-stale", stale_wardrobe.get_snapshot()).get("ok") == true,
		"AC3 auxiliary sew fixture on the Visor-bound wardrobe")
	_check(not stale_svc.is_patch_binding_valid(),
		"AC3 a moved wardrobe makes the Visor binding stale")
	for card_id in SIGHT_GLASS_IDS:
		var party := _party(middle)
		var enemies := _enemies([50, 60, 70])
		var deck := _sight_deck(card_id, 4242)
		var before := _full_snapshot(deck, party, enemies)
		var result = stale_svc.resolve_sight_glass(deck, party, enemies, card_id, 1)
		_assert_rejection(result, before, _full_snapshot(deck, party, enemies),
			"AC3 stale Visor binding rejects " + card_id)
		_check(deck._rng.state == before["rng"],
			"AC3 stale Visor binding consumes no RNG for " + card_id)
		_check(deck.hand.count(card_id) >= 1 and deck.discard_pile.is_empty(),
			"AC3 stale Visor binding keeps the card in hand for " + card_id)

	## 2. The torn ledger moves after a successful Visor bind.
	var torn_ctx := _bound_service(VISOR)
	var torn_svc: CombatTinkerPoolGadgets = torn_ctx["svc"]
	var torn: RunTornMending = torn_ctx["torn"]
	var heroes := _party().get_heroes()
	var battle_end: Array = heroes.duplicate(true)
	battle_end[0]["hp"] = 0
	_check(torn.observe_battle_end("node-186-visor-stale-torn", heroes, battle_end).get("ok") == true,
		"AC3 the seamstress is torn after the Visor bind")
	_check(not torn_svc.is_patch_binding_valid(),
		"AC3 a moved torn ledger makes the Visor binding stale")
	var torn_party := _party(canonical)
	var torn_enemies := _enemies([50, 60, 70])
	var torn_deck := _sight_deck("tinker_sight_glass_plus", 4242)
	var torn_before := _full_snapshot(torn_deck, torn_party, torn_enemies)
	var torn_result = torn_svc.resolve_sight_glass(torn_deck, torn_party, torn_enemies,
		"tinker_sight_glass_plus", 3)
	_assert_rejection(torn_result, torn_before,
		_full_snapshot(torn_deck, torn_party, torn_enemies),
		"AC3 stale torn ledger rejects the Visor cast")
	_check(torn_deck._rng.state == torn_before["rng"],
		"AC3 stale torn ledger consumes no RNG")

	## 3. An explicit Visor bind that fails authentication rejects every cast.
	var failed_ctx := _wearer_ledgers()
	var failed_wardrobe: RunPatchWardrobe = failed_ctx["wardrobe"]
	var failed_torn: RunTornMending = failed_ctx["torn"]
	_check(failed_wardrobe.sew("button_glass_visor", "tinker", "HEAD",
		"op-186-visor-failed", failed_wardrobe.get_snapshot()).get("ok") == true,
		"AC3 sew the Visor before the failed bind")
	var genuine: Dictionary = failed_wardrobe.get_snapshot()
	var wrong_snapshot: Dictionary = genuine.duplicate(true)
	wrong_snapshot["gold"] = int(wrong_snapshot["gold"]) + 1
	var failed_svc := CombatTinkerPoolGadgets.new()
	_check(not failed_svc.bind_patch_wardrobe(failed_wardrobe, failed_torn,
		wrong_snapshot, failed_torn.read_state()),
		"AC3 mismatched expected wardrobe rejects the explicit Visor bind")
	_check(not failed_svc.is_patch_binding_valid(),
		"AC3 a failed Visor bind stays explicit and invalid")
	var failed_party := _party(middle)
	var failed_enemies := _enemies([50, 60, 70])
	var failed_deck := _sight_deck("tinker_sight_glass", 4242)
	var failed_before := _full_snapshot(failed_deck, failed_party, failed_enemies)
	var failed_result = failed_svc.resolve_sight_glass(failed_deck, failed_party,
		failed_enemies, "tinker_sight_glass", 2)
	_assert_rejection(failed_result, failed_before,
		_full_snapshot(failed_deck, failed_party, failed_enemies),
		"AC3 a failed Visor bind never grants a vanilla cast")

	## 4. A Tinker downed inside this combat party cannot cast it.
	var downed_ctx := _bound_service(VISOR)
	var downed_svc: CombatTinkerPoolGadgets = downed_ctx["svc"]
	var downed_party := _party(middle)
	_check(downed_party.apply_damage(2, 30) and downed_party.is_downed(2),
		"AC3 Tinker downed at pos2 under the Visor")
	var downed_enemies := _enemies([50, 60, 70])
	var downed_deck := _sight_deck("tinker_sight_glass", 4242)
	var downed_before := _full_snapshot(downed_deck, downed_party, downed_enemies)
	var downed_result = downed_svc.resolve_sight_glass(downed_deck, downed_party,
		downed_enemies, "tinker_sight_glass", 1)
	_assert_rejection(downed_result, downed_before,
		_full_snapshot(downed_deck, downed_party, downed_enemies),
		"AC3 downed Visor wearer rejects the cast")
	_check(downed_deck._rng.state == downed_before["rng"],
		"AC3 downed Visor wearer consumes no RNG")

	## 5. Illegal FROM position with a genuine, current Visor binding.
	var illegal_party := _party(["tinker", "warden", "seamstress"])
	var illegal_enemies := _enemies([50, 60, 70])
	var illegal_deck := _sight_deck("tinker_sight_glass", 4242)
	var illegal_before := _full_snapshot(illegal_deck, illegal_party, illegal_enemies)
	var illegal_result = downed_svc.resolve_sight_glass(illegal_deck, illegal_party,
		illegal_enemies, "tinker_sight_glass", 1)
	_assert_rejection(illegal_result, illegal_before,
		_full_snapshot(illegal_deck, illegal_party, illegal_enemies),
		"AC3 Visor cast rejects Tinker at position 1")

	## 6. An empty hand copy.
	var empty_party := _party(middle)
	var empty_enemies := _enemies([50, 60, 70])
	var empty_deck := _deck(["warden_brace", "seamstress_mend", "tinker_tune_up",
		"tinker_pop_shot", "extra1"], 4242)
	_check(not empty_deck.hand.has("tinker_sight_glass"),
		"AC3 missing held copy fixture")
	var empty_before := _full_snapshot(empty_deck, empty_party, empty_enemies)
	var empty_result = downed_svc.resolve_sight_glass(empty_deck, empty_party,
		empty_enemies, "tinker_sight_glass", 1)
	_assert_rejection(empty_result, empty_before,
		_full_snapshot(empty_deck, empty_party, empty_enemies),
		"AC3 Visor cast rejects a missing held copy")

	## 7. Insufficient energy.
	var low_party := _party(middle)
	var low_enemies := _enemies([50, 60, 70])
	var low_deck := _sight_deck("tinker_sight_glass", 4242)
	_check(low_deck.try_spend_energy(3) and low_deck.energy == 0,
		"AC3 energy exhausted fixture under the Visor")
	var low_before := _full_snapshot(low_deck, low_party, low_enemies)
	var low_result = downed_svc.resolve_sight_glass(low_deck, low_party, low_enemies,
		"tinker_sight_glass", 1)
	_assert_rejection(low_result, low_before,
		_full_snapshot(low_deck, low_party, low_enemies),
		"AC3 Visor cast rejects insufficient energy")
	_check(low_deck._rng.state == low_before["rng"],
		"AC3 insufficient energy consumes no RNG under the Visor")

	## 8. Status capacity is preflighted with the projected 3, not the printed 2.
	var cap_party := _party(middle)
	var cap_enemies := _enemies([50, 60, 70])
	_check(cap_enemies.apply_statuses({1: {"exposed": CombatEnemies.MAX_INT - 2}}),
		"AC3 pre-existing Exposed leaves room for 2 but not 3")
	_check(cap_enemies.can_apply_statuses({1: {"exposed": 2}}),
		"AC3 the printed 2 still fits the capacity fixture")
	_check(not cap_enemies.can_apply_statuses({1: {"exposed": 3}}),
		"AC3 the projected 3 does not fit the capacity fixture")
	var cap_deck := _sight_deck("tinker_sight_glass", 4242)
	var cap_before := _full_snapshot(cap_deck, cap_party, cap_enemies)
	var cap_result = downed_svc.resolve_sight_glass(cap_deck, cap_party, cap_enemies,
		"tinker_sight_glass", 1)
	_assert_rejection(cap_result, cap_before,
		_full_snapshot(cap_deck, cap_party, cap_enemies),
		"AC3 the projected Visor amount is what the capacity preflight rejects")
	_check(cap_deck._rng.state == cap_before["rng"],
		"AC3 capacity rejection consumes no RNG under the Visor")

	## The same state without a Visor accepts and caps the enemy at MAX_INT.
	var cap_plain_party := _party(middle)
	var cap_plain_enemies := _enemies([50, 60, 70])
	_check(cap_plain_enemies.apply_statuses({1: {"exposed": CombatEnemies.MAX_INT - 2}}),
		"AC3 plain capacity fixture mirrors the projected one")
	var cap_plain_deck := _sight_deck("tinker_sight_glass", 4242)
	var cap_plain_result = CombatTinkerPoolGadgets.new().resolve_sight_glass(
		cap_plain_deck, cap_plain_party, cap_plain_enemies, "tinker_sight_glass", 1)
	_check(cap_plain_result == {"ok": true, "exposed_applied": 2, "drawn": 1, "target": 1}
		and cap_plain_enemies.get_enemy(1)["statuses"]["exposed"] == CombatEnemies.MAX_INT,
		"AC3 without the Visor the authored 2 still lands and caps at MAX_INT")

	## 9. Illegal targets and a slain target with the Visor bound.
	var target_party := _party(middle)
	var target_enemies := _enemies([50, 60, 70])
	var target_deck := _sight_deck("tinker_sight_glass", 4242)
	for bad_target in [0, 4]:
		var target_before := _full_snapshot(target_deck, target_party, target_enemies)
		var target_result = downed_svc.resolve_sight_glass(target_deck, target_party,
			target_enemies, "tinker_sight_glass", bad_target)
		_assert_rejection(target_result, target_before,
			_full_snapshot(target_deck, target_party, target_enemies),
			"AC3 Visor cast rejects target position " + str(bad_target))
	_check(target_enemies.apply_damage(1, 50) and target_enemies.is_slain(1),
		"AC3 target pos1 slain under the Visor")
	var slain_before := _full_snapshot(target_deck, target_party, target_enemies)
	var slain_result = downed_svc.resolve_sight_glass(target_deck, target_party,
		target_enemies, "tinker_sight_glass", 1)
	_assert_rejection(slain_result, slain_before,
		_full_snapshot(target_deck, target_party, target_enemies),
		"AC3 Visor cast rejects a slain target")

	## 10. A held single copy cannot be played twice.
	var once_party := _party(canonical)
	var once_enemies := _enemies([50, 60, 70])
	var once_deck := _deck(["tinker_sight_glass", "warden_brace", "seamstress_mend",
		"tinker_tune_up", "tinker_pop_shot"], 4242)
	_check(once_deck.hand.count("tinker_sight_glass") == 1
		and once_deck.draw_pile.is_empty(), "AC3 single-copy fixture for duplicate play")
	var once_result = downed_svc.resolve_sight_glass(once_deck, once_party, once_enemies,
		"tinker_sight_glass", 1)
	_check(once_result == {"ok": true, "exposed_applied": 3, "drawn": 0, "target": 1}
		and once_enemies.get_enemy(1)["statuses"]["exposed"] == 3,
		"AC3 the first Visor cast lands with the projected 3")
	var again_before := _full_snapshot(once_deck, once_party, once_enemies)
	var again_result = downed_svc.resolve_sight_glass(once_deck, once_party, once_enemies,
		"tinker_sight_glass", 1)
	_assert_rejection(again_result, again_before,
		_full_snapshot(once_deck, once_party, once_enemies),
		"AC3 the same held copy cannot be played twice")