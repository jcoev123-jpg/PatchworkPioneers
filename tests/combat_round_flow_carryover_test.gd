extends SceneTree

## A real witnessed Fight -> carried heroes + seeded reward deck -> new round.
var failures: Array[String] = []
var checks := 0

const HERO_PATH := "res://data/heroes/starter_party.json"
const ENEMY_PATH := "res://data/enemies/starter_enemies.json"
const INTENT_PATH := "res://data/encounters/starter_attacks.json"


func _initialize() -> void:
	_test_carried_opening("slot2_pick", 1, true, false, 740)
	_test_carried_opening("slot3_skip", 2, false, false, 741)
	_test_carried_opening("downed_skip", 1, false, true, 742)
	for failure in failures:
		printerr(failure)
	print("combat_round_flow_carryover_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _authored(path: String) -> Array:
	var raw := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	_check(not raw.is_empty() and parsed is Array and not parsed.is_empty(),
		"real nonempty authored data: " + path)
	if not parsed is Array:
		return []
	for item in parsed:
		if not item is Dictionary:
			_check(false, "authored record must be a dictionary: " + path)
			return []
		for field in ["max_hp", "enemy_position"]:
			if item.has(field) and item[field] is float:
				_check(item[field] == floorf(item[field]), "integer authored field " + field)
				item[field] = int(item[field])
		for action in item.get("pattern", []):
			if action is Dictionary:
				for field in ["amount", "target_position"]:
					if action.get(field) is float:
						_check(action[field] == floorf(action[field]), "integral authored action " + field)
						action[field] = int(action[field])
	return parsed


func _rng(value: int) -> RandomNumberGenerator:
	var result := RandomNumberGenerator.new()
	result.seed = value
	return result


func _sorted_cards(ids: Array) -> Array:
	var sorted := ids.duplicate()
	sorted.sort()
	return sorted


func _piles(deck: CombatDeck) -> Array:
	var all: Array = []
	all.append_array(deck.hand)
	all.append_array(deck.draw_pile)
	all.append_array(deck.discard_pile)
	return _sorted_cards(all)


func _snapshot(fight: Dictionary) -> Dictionary:
	var deck: CombatDeck = fight.deck
	var flow: CombatRoundFlow = fight.flow
	return {
		"heroes": fight.party.get_heroes(),
		"enemies": fight.enemies.get_enemies(),
		"draw": deck.draw_pile.duplicate(true),
		"hand": deck.hand.duplicate(true),
		"discard": deck.discard_pile.duplicate(true),
		"energy": deck.energy,
		"turn_active": deck.turn_active,
		"state_energy": deck.combat_state.energy,
		"state_active": deck.combat_state.player_turn_active,
		"rng_seed": deck._rng.seed,
		"rng_state": deck._rng.state,
		"intents": fight.intents.get_intents(),
		"definitions": fight.intents._definitions.duplicate(true),
		"intent_index": fight.intents._turn_index,
		"result": fight.result.get_outcome(),
		"result_binding": flow._result == fight.result,
		"started": flow._started,
		"opening_consumed": flow._opening_block._consumed
	}


func _swap(party: CombatParty, mover: int) -> bool:
	var proposal: Dictionary = CombatPositionSwaps.preview_adjacent_swap(party, mover, 1)
	_check(proposal.get("ok") == true, "authentic adjacent swap is legal at " + str(mover))
	if proposal.get("ok") != true:
		return false
	party._heroes.assign(proposal["heroes"].duplicate(true))
	return true


func _test_carried_opening(scenario: String, moves: int, pick: bool,
		down_warden: bool, seed_value: int) -> void:
	var starter_heroes := _authored(HERO_PATH)
	var starter_enemies := _authored(ENEMY_PATH)
	var starter_intents := _authored(INTENT_PATH)
	var base_deck: Array[String] = StarterCards.new().get_starting_deck()
	_check(starter_heroes.size() == 3 and starter_enemies.size() == 2
		and starter_intents.size() == 2 and base_deck.size() == 12
		and base_deck.count("warden_strike") == 2
		and base_deck.count("seamstress_prick") == 2
		and base_deck.count("tinker_pop_shot") == 2,
		"all starter definitions, intents, and twelve authored copies exist: " + scenario)
	if starter_heroes.size() != 3 or starter_enemies.size() != 2 or starter_intents.size() != 2:
		return

	var prior := CombatParty.new(starter_heroes)
	var enemies := CombatEnemies.new(starter_enemies)
	var result := CombatBattleResult.new(prior, enemies)
	var carry := RunPartyCarryover.new(prior.get_heroes())
	_check(prior.is_valid() and enemies.is_valid() and carry.is_valid()
		and result.get_outcome() == CombatBattleResult.ACTIVE
		and not enemies.is_victorious(), "real initial battle and carry ledger live: " + scenario)
	if not carry.is_valid():
		return

	for mover in range(1, moves + 1):
		if not _swap(prior, mover):
			return
	var warden_slot := moves + 1
	_check(prior.get_hero(warden_slot)["id"] == "warden"
		and prior.get_hero(warden_slot)["position"] == warden_slot,
		"legal prior battle moves Warden to authored slot " + str(warden_slot))

	_check(prior.apply_damage(warden_slot, 9)
		and prior.apply_damage(1 if warden_slot != 1 else 2, 3),
		"real pre-victory damage wounds current-slot heroes")
	if down_warden:
		_check(prior.apply_damage(warden_slot, 40)
			and prior.is_downed(warden_slot) and not prior.is_defeated(),
			"zero-HP Warden occupies his current slot with living allies")
	for index in range(3):
		var hero: Dictionary = prior._heroes[index]
		if hero["id"] == "warden":
			hero["statuses"] = {"bleed": 2, "weak": 1}
		elif hero["id"] == "seamstress":
			hero["statuses"] = {"exposed": 2}
		else:
			hero["statuses"] = {"weak": 3}
		hero["metadata"] = {"owner": hero["id"], "stitches": [index, "persist"]}
		if hero["hp"] > 0:
			_check(prior.gain_block(index + 1, index + 4),
				"prior fight genuinely contains stale per-hero Block")
	var before_victory := prior.get_heroes()
	_check(CombatStatusTurnBatch.new().tick_side("heroes", before_victory)["ok"],
		"nonzero actor statuses are valid before carried victory")
	_check(enemies.apply_damage(1, 12) and enemies.is_slain(1)
		and not enemies.is_victorious() and result.evaluate() == CombatBattleResult.ACTIVE,
		"first real enemy dies but battle is not yet won")
	_check(enemies.apply_damage(2, 12) and enemies.is_victorious()
		and result.get_outcome() == CombatBattleResult.ACTIVE,
		"last real enemy dies without fabricating a result")
	_check(result.evaluate() == CombatBattleResult.VICTORY,
		"explicit evaluate witnesses final enemy's death")
	var ledger := carry.commit_victory("fight_" + scenario, result, prior)
	_check(ledger.get("ok") == true and carry.read_state()["completed_fights"] == ["fight_" + scenario],
		"real evaluated victory commits into RunPartyCarryover")
	if ledger.get("ok") != true:
		return
	var persisted: Array = before_victory.duplicate(true)
	for hero in persisted:
		hero["block"] = 0
	_check(carry.get_next_fight_heroes() == persisted and ledger["heroes"] == persisted
		and prior.get_heroes() == before_victory,
		"commit preserves HP/status/formation and strips transit Block only")

	# Rewards consume the same seeded run RNG that is later injected into the
	# next deck. A pick appends one authored owned copy; Skip adds nothing.
	var run_rng := _rng(seed_value)
	var party_ids: Array[String] = ["warden", "seamstress", "tinker"]
	var offers := RunFightVictoryRewards.new(result, run_rng, party_ids,
		StarterCards.new().get_all_card_ids(), base_deck, 0, false)
	var prepared: Dictionary = offers.prepare()
	_check(prepared.get("ok") == true and prepared.get("gold_award", 0) >= 10
		and prepared.get("gold_award", 0) <= 20
		and prepared.get("offers", []).size() == 3,
		"real seeded Fight reward produces gold and three authored offers")
	if prepared.get("ok") != true:
		return
	var chosen_id: String = prepared["offers"][0]["id"] if pick else ""
	var selected := offers.choose(chosen_id)
	_check(selected.get("ok") == true and selected["skipped"] == (not pick)
		and selected["gold"] == prepared["gold_award"],
		"picked or explicitly skipped actual reward exactly once: " + scenario)
	if selected.get("ok") != true:
		return
	var run_deck: Array[String] = selected["deck"]
	var expected_cards: Array[String] = base_deck.duplicate()
	if pick:
		var definition := StarterCards.new().get_definition(chosen_id)
		_check(not definition.is_empty() and party_ids.has(definition.get("owner")),
			"offered picked ID is an eligible hero-owned authored card")
		expected_cards.append(chosen_id)
	_check(_sorted_cards(run_deck) == _sorted_cards(expected_cards)
		and run_deck.size() == (13 if pick else 12)
		and run_deck.count(chosen_id) == base_deck.count(chosen_id) + (1 if pick else 0),
		"exact multiset preserves all starter copies and only the optional reward")
	var rewards_rng_state: int = run_rng.state
	var oracle_rng := _rng(seed_value)
	oracle_rng.state = rewards_rng_state
	var next_deck := CombatDeck.new(run_deck, run_rng)
	var oracle := CombatDeck.new(run_deck, oracle_rng)
	var next_party := carry.create_next_fight_party()
	_check(next_party != null and next_party.is_valid()
		and next_party.get_heroes() == persisted
		and next_party != prior, "fresh CombatParty rehydrates committed hero formation")
	if next_party == null:
		return
	var next_enemies := CombatEnemies.new(starter_enemies)
	var next_intents := CombatEnemyIntents.new(starter_intents)
	var next_result := CombatBattleResult.new(next_party, next_enemies)
	var flow := CombatRoundFlow.new(next_deck, next_party,
		next_enemies, next_intents, next_result)
	var fight := {"deck": next_deck, "party": next_party, "enemies": next_enemies,
		"intents": next_intents, "result": next_result, "flow": flow}
	_check(next_enemies.is_valid() and next_intents.is_valid() and next_result.can_continue()
		and flow._result._party == next_party and flow._result._enemies == next_enemies,
		"new enemies, intents and battle result bind the exact hydrated actors")
	var before := _snapshot(fight)
	_check(before["heroes"] == persisted and not before["started"]
		and not before["opening_consumed"] and before["hand"].is_empty()
		and before["energy"] == 0 and before["discard"].is_empty(),
		"new fight is not prematurely started or holding a stale hand")
	_check(flow.begin_fight() and oracle.start_turn(),
		"round service admits witnessed carried formation: " + scenario)
	var after := _snapshot(fight)
	var expected_heroes := persisted.duplicate(true)
	if not down_warden:
		expected_heroes[warden_slot - 1]["block"] = 6
	_check(next_party.get_heroes() == expected_heroes
		and flow._opening_block._consumed == (not down_warden),
		"only live current-slot Warden receives +6; wounds, 0 HP and statuses persist")
	_check(next_deck.hand.size() == 5 and next_deck.energy == 3
		and next_deck.turn_active and next_deck.hand == oracle.hand
		and next_deck.draw_pile == oracle.draw_pile
		and next_deck.discard_pile == oracle.discard_pile
		and run_rng.state == oracle_rng.state and run_rng.seed == oracle_rng.seed,
		"exact draw-five, three energy and RNG match independent same-state oracle")
	_check(_piles(next_deck) == _sorted_cards(expected_cards),
		"post-opening hand/draw/discard multiset equals rewarded persistent deck")
	_check(not flow.begin_fight() and _snapshot(fight) == after,
		"second begin is byte-for-byte inert including RNG and passive")
	_check(carry.get_next_fight_heroes() == persisted,
		"new battle does not mutate carry ledger")

	if down_warden:
		var held_warden_attack := ""
		for card in next_deck.hand:
			if card in ["warden_strike", "warden_shield_bash"]:
				held_warden_attack = card
				break
		_check(not held_warden_attack.is_empty(), "downed scenario draws a real held Warden attack")
		if not held_warden_attack.is_empty():
			_check(not CombatAttackTargeting.new().get_preview(
				next_deck, next_party, next_enemies, held_warden_attack)["playable"],
				"downed Warden cannot play a genuinely held owned attack")
		_check(flow.end_turn() and oracle.end_turn() and oracle.start_turn(),
			"surviving allies can progress into another player turn")
		_check(next_party.get_hero(warden_slot)["hp"] == 0
			and next_party.get_hero(warden_slot)["block"] == 0
			and not flow._opening_block._consumed,
			"later turn neither revives downed Warden nor grants belated Block")
		_check(next_deck.hand == oracle.hand and next_deck.draw_pile == oracle.draw_pile
			and next_deck.discard_pile == oracle.discard_pile and next_deck.energy == 3
			and run_rng.state == oracle_rng.state,
			"later turn keeps seeded shared-deck progression with living allies")
