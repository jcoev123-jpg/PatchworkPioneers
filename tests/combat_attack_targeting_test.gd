extends SceneTree

var failures: Array[String] = []
var checks := 0
var service := CombatAttackTargeting.new()

const ATTACK_IDS := [
	"warden_strike", "warden_shield_bash", "seamstress_prick",
	"tinker_pop_shot", "tinker_scrap_bomb"
]
const POOL_STRIKE_IDS := [
	"warden_brass_buckle", "warden_brass_buckle_plus",
	"seamstress_thread_whip", "seamstress_thread_whip_plus",
]
const SUPPORT_IDS := [
	"warden_brace", "seamstress_mend", "seamstress_stitch_up", "tinker_tune_up"
]


func _initialize() -> void:
	_test_authored_cards_and_freshness()
	_test_slain_positions()
	_test_hand_energy_and_turn()
	_test_owner_positions_and_downed()
	_test_unsupported_and_invalid()
	_test_pool_strikes()
	_test_seeded_replay()
	for failure in failures:
		printerr(failure)
	print("combat_attack_targeting_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _deck(cards: Array[String], seed_value: int = 3271, start: bool = true) -> CombatDeck:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var deck := CombatDeck.new(cards, rng)
	_check(deck.draw_pile.size() == cards.size(), "real deck initialized with all supplied cards")
	if start:
		_check(deck.start_turn() and deck.turn_active and deck.energy == 3,
			"real seeded CombatDeck starts turn with three energy")
		_check(deck.hand.size() == mini(5, cards.size()), "real draw-five filled held hand")
	return deck


func _five_attacks() -> CombatDeck:
	var cards: Array[String] = []
	cards.assign(ATTACK_IDS)
	var deck := _deck(cards)
	for id in ATTACK_IDS:
		_check(deck.hand.has(id), "five-card draw holds offensive card " + id)
	return deck


func _party(order: Array[String] = ["warden", "seamstress", "tinker"]) -> CombatParty:
	var definitions: Array = []
	for id in order:
		var max_hp := 40
		if id == "seamstress":
			max_hp = 30
		elif id == "tinker":
			max_hp = 26
		definitions.append({"id": id, "max_hp": max_hp, "tags": ["fixture"]})
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"party fixture is valid and actually has three heroes")
	return party


func _enemies(count: int = 3) -> CombatEnemies:
	var definitions: Array = []
	for i in range(count):
		definitions.append({"id": "synthetic_%d" % (i + 1), "max_hp": 12 + i,
			"tags": ["fixture"]})
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid() and enemies.get_enemies().size() == count,
		"real CombatEnemies fixture has " + str(count) + " occupied slots")
	return enemies


func _snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies) -> Dictionary:
	var state := {}
	if deck != null:
		state["deck"] = [
			deck.draw_pile.duplicate(true), deck.hand.duplicate(true),
			deck.discard_pile.duplicate(true), deck.turn_active, deck.energy,
			deck.combat_state.player_turn_active, deck.combat_state.energy,
			deck._rng.seed, deck._rng.state
		]
	if party != null:
		state["party"] = party.get_heroes().duplicate(true)
	if enemies != null:
		state["enemies"] = enemies.get_enemies().duplicate(true)
	return state


func _assert_preview(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, expected_playable: bool, expected_selection: bool,
		expected_positions: Array, label: String) -> void:
	var before := _snapshot(deck, party, enemies)
	var preview := service.get_preview(deck, party, enemies, card_id)
	var keys := preview.keys()
	keys.sort()
	_check(keys == ["playable", "requires_selection", "target_positions"],
		label + ": exactly the three public response keys")
	_check(typeof(preview.get("playable")) == TYPE_BOOL
		and typeof(preview.get("requires_selection")) == TYPE_BOOL,
		label + ": boolean response values")
	_check(preview.get("target_positions") is Array
		and (preview["target_positions"] as Array).get_typed_builtin() == TYPE_INT,
		label + ": typed Array[int] target list")
	_check(preview == {
		"playable": expected_playable, "requires_selection": expected_selection,
		"target_positions": expected_positions
	}, label + ": exact playable, choice and position values")
	_check(_snapshot(deck, party, enemies) == before,
		label + ": all hand/piles/energy/turn/HP/Block/RNG unchanged")
	var second := service.get_preview(deck, party, enemies, card_id)
	_check(second == preview, label + ": repeated preview is deterministic")
	_check(_snapshot(deck, party, enemies) == before,
		label + ": repeated preview still has no side effects")


func _reject(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		id: String, label: String) -> void:
	_assert_preview(deck, party, enemies, id, false, false, [], label)


func _test_authored_cards_and_freshness() -> void:
	var deck := _five_attacks()
	var party := _party()
	var enemies := _enemies()
	_check(party.gain_block(2, 4) and enemies.gain_block(3, 2)
		and enemies.apply_damage(3, 3), "fixture includes nonzero Block and injured living enemy")
	_check(enemies.get_enemy(3)["hp"] == 13 and enemies.get_enemy(3)["block"] == 0,
		"damage from Block leaves enemy 3 living in its original slot")
	var catalog := StarterCards.new()
	# Verify concrete definitions rather than assuming a five-ID catalog or reauthoring rules.
	for id in ATTACK_IDS:
		var definition := catalog.get_definition(id)
		_check(not definition.is_empty() and definition["owner"] in ["warden", "seamstress", "tinker"],
			id + ": authoritative catalog owner exists")
		_check(definition["cost"] is int and definition["cost"] <= deck.energy
			and definition["from_positions"].has(
				1 if id.begins_with("warden") else 2 if id == "seamstress_prick" else 3),
			id + ": authoritative catalog permits the actual living owner")
		_check(definition["target_kind"] == ("enemy_all" if id == "tinker_scrap_bomb" else "enemy_single"),
			id + ": authoritative catalog kind")
	_assert_preview(deck, party, enemies, "warden_strike", true, true, [1, 2],
		"Strike reaches only front two enemies")
	_assert_preview(deck, party, enemies, "warden_shield_bash", true, true, [1],
		"Shield Bash reaches only enemy 1")
	_assert_preview(deck, party, enemies, "seamstress_prick", true, true, [1, 2, 3],
		"Prick reaches every living position as individual choices")
	_assert_preview(deck, party, enemies, "tinker_pop_shot", true, true, [1, 2, 3],
		"Pop Shot reaches every living position as individual choices")
	_assert_preview(deck, party, enemies, "tinker_scrap_bomb", true, false, [1, 2, 3],
		"Scrap Bomb affects every living enemy without target selection")

	var before := _snapshot(deck, party, enemies)
	var single := service.get_preview(deck, party, enemies, "warden_strike")
	(single["target_positions"] as Array).clear()
	(single["target_positions"] as Array).append(99)
	_assert_preview(deck, party, enemies, "warden_strike", true, true, [1, 2],
		"caller mutation of single-target result cannot poison next preview")
	var area := service.get_preview(deck, party, enemies, "tinker_scrap_bomb")
	(area["target_positions"] as Array).remove_at(0)
	(area["target_positions"] as Array).append(99)
	_assert_preview(deck, party, enemies, "tinker_scrap_bomb", true, false, [1, 2, 3],
		"caller mutation of affected-position result cannot poison next preview")
	_check(_snapshot(deck, party, enemies) == before,
		"mutation of returned lists cannot alter any model or RNG state")


func _test_slain_positions() -> void:
	var deck := _five_attacks()
	var party := _party()
	var enemies := _enemies()
	_check(enemies.apply_damage(2, 999) and enemies.is_slain(2)
		and enemies.get_enemy(2)["position"] == 2
		and enemies.get_enemy(3)["position"] == 3
		and not enemies.is_victorious(),
		"killing slot 2 preserves position of surviving slot 3, not victory")
	_assert_preview(deck, party, enemies, "warden_strike", true, true, [1],
		"Strike never compacts enemy 3 into slain slot 2")
	_assert_preview(deck, party, enemies, "warden_shield_bash", true, true, [1],
		"Shield Bash unaffected by slain enemy 2")
	for id in ["seamstress_prick", "tinker_pop_shot"]:
		_assert_preview(deck, party, enemies, id, true, true, [1, 3],
			id + ": only occupied living position IDs")
	_assert_preview(deck, party, enemies, "tinker_scrap_bomb", true, false, [1, 3],
		"area affected positions skip slain slot 2")

	_check(enemies.apply_damage(1, 999) and enemies.is_slain(1)
		and not enemies.is_victorious(), "two slain enemies leave last enemy alive")
	_reject(deck, party, enemies, "warden_strike", "Strike lacks any living enemy in reach")
	_reject(deck, party, enemies, "warden_shield_bash", "Shield Bash lacks a living enemy 1")
	for id in ["seamstress_prick", "tinker_pop_shot"]:
		_assert_preview(deck, party, enemies, id, true, true, [3],
			id + ": back-only living enemy remains targetable")
	_assert_preview(deck, party, enemies, "tinker_scrap_bomb", true, false, [3],
		"area no-choice still applies to lone surviving back enemy")
	_check(enemies.apply_damage(3, 999) and enemies.is_victorious()
		and enemies.get_enemies().size() == 3, "final enemy dies but all slots remain")
	for id in ATTACK_IDS:
		_reject(deck, party, enemies, id, id + ": all slain cannot be played")

	var one := _enemies(1)
	_assert_preview(deck, party, one, "tinker_scrap_bomb", true, false, [1],
		"one-enemy encounter gives area preview with one affected slot")
	_check(one.apply_damage(1, 999) and one.is_victorious(), "single enemy final death")
	_reject(deck, party, one, "tinker_scrap_bomb", "single slain enemy rejects area")
	var two := _enemies(2)
	_check(two.apply_damage(1, 999) and not two.is_victorious(),
		"two-enemy roster is not victorious after first kill")
	_assert_preview(deck, party, two, "warden_strike", true, true, [2],
		"remaining second slot can be targeted without compaction")


func _test_hand_energy_and_turn() -> void:
	var party := _party()
	var enemies := _enemies()
	var deck := _deck(["warden_strike", "tinker_pop_shot"])
	_reject(deck, party, enemies, "warden_shield_bash", "authored card absent from hand")
	_check(deck.discard_played("warden_strike") and not deck.hand.has("warden_strike"),
		"fixture removes actual held Strike copy through real deck API")
	_reject(deck, party, enemies, "warden_strike", "played/discarded copy no longer held")

	deck = _five_attacks()
	_check(deck.try_spend_energy(2) and deck.energy == 1, "one-energy fixture")
	_reject(deck, party, enemies, "warden_shield_bash", "Shield Bash cost two is unaffordable at one")
	_reject(deck, party, enemies, "tinker_scrap_bomb", "Scrap Bomb cost two is unaffordable at one")
	_assert_preview(deck, party, enemies, "seamstress_prick", true, true, [1, 2, 3],
		"cost-one Prick still affordable at one energy")
	_check(deck.try_spend_energy(1) and deck.energy == 0, "zero-energy fixture")
	for id in ATTACK_IDS:
		_reject(deck, party, enemies, id, id + ": zero energy rejects all attacks")

	var cards: Array[String] = []
	cards.assign(ATTACK_IDS)
	deck = _deck(cards, 17, false)
	_check(not deck.turn_active, "pre-start turn is genuinely inactive")
	_reject(deck, party, enemies, "warden_strike", "inactive turn before initial draw")
	_check(deck.start_turn() and deck.hand.size() == 5, "turn activation actually draws five")
	_assert_preview(deck, party, enemies, "warden_strike", true, true, [1, 2],
		"same deck allows preview while player turn active")
	_check(deck.end_turn() and not deck.turn_active and deck.hand.is_empty()
		and deck.discard_pile.size() == 5, "real end turn discards unplayed hand")
	_reject(deck, party, enemies, "warden_strike", "inactive turn after discard")
	_check(deck.start_turn(), "later turn starts with real discard reshuffle")
	_assert_preview(deck, party, enemies, "warden_shield_bash", true, true, [1],
		"new turn restores held copies and energy")


func _test_owner_positions_and_downed() -> void:
	var deck := _five_attacks()
	var enemies := _enemies()
	var party := _party(["seamstress", "warden", "tinker"])
	_assert_preview(deck, party, enemies, "warden_strike", true, true, [1, 2],
		"Warden moved to slot 2 still can Strike")
	_reject(deck, party, enemies, "warden_shield_bash", "Warden slot 2 cannot Shield Bash")
	_assert_preview(deck, party, enemies, "seamstress_prick", true, true, [1, 2, 3],
		"Seamstress slot 1 can Prick")

	party = _party(["seamstress", "tinker", "warden"])
	_reject(deck, party, enemies, "warden_strike", "Warden slot 3 cannot Strike")
	_reject(deck, party, enemies, "warden_shield_bash", "Warden slot 3 cannot Shield Bash")
	_assert_preview(deck, party, enemies, "tinker_pop_shot", true, true, [1, 2, 3],
		"Tinker slot 2 can Pop Shot")
	_reject(deck, party, enemies, "tinker_scrap_bomb", "Tinker slot 2 cannot Scrap Bomb")

	party = _party(["tinker", "warden", "seamstress"])
	_reject(deck, party, enemies, "tinker_pop_shot", "Tinker slot 1 cannot Pop Shot")
	_reject(deck, party, enemies, "tinker_scrap_bomb", "Tinker slot 1 cannot Scrap Bomb")
	_assert_preview(deck, party, enemies, "seamstress_prick", true, true, [1, 2, 3],
		"Seamstress slot 3 can Prick")

	# Every actual owner is checked independently, not by a hard-coded index.
	for owner in ["warden", "seamstress", "tinker"]:
		party = _party()
		var index := (["warden", "seamstress", "tinker"] as Array).find(owner) + 1
		_check(party.apply_damage(index, 999) and party.is_downed(index),
			owner + ": fixture actually downs card owner")
		for id in ATTACK_IDS:
			if StarterCards.new().get_definition(id)["owner"] == owner:
				_reject(deck, party, enemies, id, id + ": downed actual owner cannot attack")
	party = _party(["seamstress", "tinker", "outsider"])
	_reject(deck, party, enemies, "warden_strike", "no Warden owner in otherwise valid party")
	_reject(deck, party, enemies, "warden_shield_bash", "no Warden for Shield Bash")
	party = _party(["warden", "tinker", "outsider"])
	_reject(deck, party, enemies, "seamstress_prick", "no Seamstress owner in otherwise valid party")
	party = _party(["warden", "seamstress", "outsider"])
	_reject(deck, party, enemies, "tinker_pop_shot", "no Tinker owner for Pop Shot")
	_reject(deck, party, enemies, "tinker_scrap_bomb", "no Tinker owner for Scrap Bomb")


func _test_unsupported_and_invalid() -> void:
	var party := _party()
	var enemies := _enemies()
	var cards: Array[String] = []
	cards.assign(SUPPORT_IDS)
	cards.append("invented_enemy_attack")
	var deck := _deck(cards)
	for id in SUPPORT_IDS:
		_check(StarterCards.new().has_card(id) and deck.hand.has(id),
			id + ": supported catalog card is actually held")
		_reject(deck, party, enemies, id, id + ": support never gains enemy targets")
	_check(deck.hand.has("invented_enemy_attack"), "unknown card is deliberately held")
	_reject(deck, party, enemies, "invented_enemy_attack", "unknown even when held")
	_reject(deck, party, enemies, "", "empty ID fails closed")
	deck = _five_attacks()
	_reject(deck, null, enemies, "warden_strike", "null party preserves surviving deck and enemies")
	_reject(null, party, enemies, "warden_strike", "null deck preserves party and enemies")
	_reject(deck, party, null, "warden_strike", "null enemies preserves deck and party")
	_reject(deck, CombatParty.new([]), enemies, "warden_strike", "invalid empty party")
	_reject(deck, party, CombatEnemies.new([]), "warden_strike", "invalid empty enemy roster")
	_reject(deck, party, CombatEnemies.new([
		{"id": "duplicate", "max_hp": 12}, {"id": "duplicate", "max_hp": 12}
	]), "warden_strike", "invalid duplicate enemy roster")
	_reject(deck, CombatParty.new([
		{"id": "warden", "max_hp": 40}, {"id": "warden", "max_hp": 40},
		{"id": "tinker", "max_hp": 26}
	]), enemies, "warden_strike", "invalid duplicate-owner party")


func _test_pool_strikes() -> void:
	# The starter enumeration mounted regressions iterate must stay starter-only.
	for id in POOL_STRIKE_IDS:
		_check(service.is_pool_strike(id) and service.supports(id),
			id + ": recognised as an authored pool strike")
		_check(not CombatAttackTargeting.ATTACK_IDS.has(id),
			id + ": never expands the starter ATTACK_IDS enumeration")
		var record := service.pool_definition(id)
		var owner_id := "warden" if id.begins_with("warden_") else "seamstress"
		_check(record.get("id") == id and record.get("owner") == owner_id,
			id + ": exact catalog record through the targeting lookup")
		_check(record.get("cost") == 1 and record.get("target_kind") == "enemy_single"
			and record.get("to_positions") == [1, 2], id + ": authored cost, kind and TO slots")
	for id in ATTACK_IDS:
		_check(service.supports(id) and not service.is_pool_strike(id),
			id + ": starter attack stays a starter attack")
	for id in ["warden_hold_the_line", "warden_patch_guard", "seamstress_snag", "tinker_tune_up"]:
		_check(not service.is_pool_strike(id) and not service.supports(id)
			and service.pool_definition(id).is_empty(), id + ": non-strike pool/support card stays rejected")

	var deck := _pool_strike_deck()
	var party := _party()
	var enemies := _enemies()
	for id in POOL_STRIKE_IDS:
		_assert_preview(deck, party, enemies, id, true, true, [1, 2],
			id + ": both authored enemy slots selectable")

	# Authored FROM slots: Brass Buckle reaches the front two heroes only.
	var middle := _party(["seamstress", "warden", "tinker"])
	for id in ["warden_brass_buckle", "warden_brass_buckle_plus"]:
		_assert_preview(deck, middle, enemies, id, true, true, [1, 2],
			id + ": Warden in slot two may play")
	var back := _party(["seamstress", "tinker", "warden"])
	for id in ["warden_brass_buckle", "warden_brass_buckle_plus"]:
		_reject(deck, back, enemies, id, id + ": Warden in forbidden slot three")
	# Thread Whip is authored from every hero slot.
	_assert_preview(deck, back, enemies, "seamstress_thread_whip", true, true, [1, 2],
		"Thread Whip from slot one")
	var seamstress_back := _party(["warden", "tinker", "seamstress"])
	_assert_preview(deck, seamstress_back, enemies, "seamstress_thread_whip_plus", true, true, [1, 2],
		"Thread Whip+ from slot three")

	# Missing and downed owners fail closed.
	_reject(deck, _party(["seamstress", "tinker", "outsider"]), enemies, "warden_brass_buckle",
		"no Warden owner for Brass Buckle")
	_reject(deck, _party(["warden", "tinker", "outsider"]), enemies, "seamstress_thread_whip",
		"no Seamstress owner for Thread Whip")
	var downed := _party()
	_check(downed.apply_damage(1, 999) and downed.is_downed(1), "Warden truly downed")
	_reject(deck, downed, enemies, "warden_brass_buckle", "downed Warden cannot Brass Buckle")
	_check(downed.apply_damage(2, 999) and downed.is_downed(2), "Seamstress truly downed")
	_reject(deck, downed, enemies, "seamstress_thread_whip", "downed Seamstress cannot Thread Whip")

	# Cost is paid from the real shared deck.
	var poor := _pool_strike_deck()
	_check(poor.try_spend_energy(3) and poor.energy == 0, "zero-energy pool deck")
	for id in POOL_STRIKE_IDS:
		_reject(poor, party, enemies, id, id + ": cost one unaffordable at zero energy")
	var absent := _pool_strike_deck()
	for id in POOL_STRIKE_IDS:
		_check(absent.discard_played(id), "remove actual held " + id)
		_reject(absent, party, enemies, id, id + ": absent held copy")
	_reject(deck, party, enemies, "warden_brass_buckle_missing", "unknown pool-like ID fails closed")

	# Slain and absent slots keep their original numbering.
	_check(enemies.apply_damage(2, 999) and enemies.is_slain(2), "slot two slain in place")
	for id in POOL_STRIKE_IDS:
		_assert_preview(deck, party, enemies, id, true, true, [1], id + ": slain slot two excluded")
	_check(enemies.apply_damage(1, 999) and enemies.is_slain(1), "slot one also slain")
	for id in POOL_STRIKE_IDS:
		_reject(deck, party, enemies, id, id + ": only enemy three lies outside the authored TO slots")
	var lone := _enemies(1)
	for id in POOL_STRIKE_IDS:
		_assert_preview(deck, party, lone, id, true, true, [1], id + ": lone front enemy stays legal")
	var two := _enemies(2)
	_check(two.apply_damage(1, 999) and not two.is_victorious(), "front enemy slain in a two-enemy roster")
	for id in POOL_STRIKE_IDS:
		_assert_preview(deck, party, two, id, true, true, [2], id + ": surviving slot two stays targetable")

	# Returned lists stay detached, exactly like starter previews.
	var before := _snapshot(deck, party, two)
	var preview := service.get_preview(deck, party, two, "warden_brass_buckle")
	(preview["target_positions"] as Array).clear()
	(preview["target_positions"] as Array).append(99)
	_assert_preview(deck, party, two, "warden_brass_buckle", true, true, [2],
		"caller mutation of a pool result cannot poison the next preview")
	_check(_snapshot(deck, party, two) == before, "pool preview mutation leaves every model and RNG intact")


func _pool_strike_deck(seed_value: int = 4211) -> CombatDeck:
	var cards: Array[String] = []
	cards.assign(POOL_STRIKE_IDS)
	var deck := _deck(cards, seed_value)
	for id in POOL_STRIKE_IDS:
		_check(deck.hand.has(id), "real seeded draw holds pool strike " + id)
	return deck


func _test_seeded_replay() -> void:
	for seed_value in [0, 42, 987654]:
		var cards: Array[String] = []
		cards.assign(ATTACK_IDS)
		var deck := _deck(cards, seed_value)
		var party := _party()
		var enemies := _enemies()
		var before := _snapshot(deck, party, enemies)
		var first: Array = []
		for id in ATTACK_IDS:
			first.append(service.get_preview(deck, party, enemies, id))
		for id in ATTACK_IDS:
			var preview := service.get_preview(deck, party, enemies, id)
			_check(preview == first[ATTACK_IDS.find(id)],
				"seed " + str(seed_value) + ": repeated " + id + " yields same preview")
		_check(_snapshot(deck, party, enemies) == before,
			"seed " + str(seed_value) + ": preview sequence consumes no RNG or model state")
