extends "res://tests/live_stitched_hand_play_test.gd"
## Title -> earned scraps -> genuine Rest receipt -> canonical routed admission.
## Extends the same seeded run through the next Fight's actual victory, its
## normal reward pick/Skip and the onward connected route.


## The same earned-stitch route, now with a battle waiting after the stitched
## Fight so the mounted reward can be settled and the run can continue.
func _hand_fixture() -> Dictionary:
	# Seed 38812 is a verified ten-kind route in this bounded search band that
	# wins its stronger weighted Elite with all three stitch owners alive.
	for value in [38812] + range(1, 200001):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for fight in map.get_legal_choices():
			if map.get_node(fight).type != "Fight":
				continue
			for elite in map.get_node(fight).outgoing:
				if map.get_node(elite).type != "Elite":
					continue
				for rest in map.get_node(elite).outgoing:
					if map.get_node(rest).type != "Rest":
						continue
					for next in map.get_node(rest).outgoing:
						if map.get_node(next).type != "Fight":
							continue
						var onward := ""
						for after in map.get_node(next).outgoing:
							if map.get_node(after).type in ["Fight", "Elite", "Boss"]:
								onward = after
								break
						if onward.is_empty():
							continue
						map.choose_node(fight)
						var entry := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
						if entry.get("encounter_id") == "starter_attacks":
							return {"seed": value, "fight": fight, "elite": [elite],
								"rest": [rest], "next": next, "onward": onward}
						map.undo_choice(fight, [])
	return {}


func _admission_state() -> Array:
	return [_entry_state(), app.run_deck.duplicate(), app.run_scraps,
		app.run_stitch_descriptors.duplicate(true), app.run_next_stitch_id,
		app._stitch_snapshot(), app.run_map.get_floors(), app._carryover_route.duplicate()]


func _reject_admission(callback: Callable, reason: String) -> void:
	var before := _admission_state()
	callback.call()
	_check(_admission_state() == before, reason + " preserves ledger, selection, RNG, battle and route")


func _canonical_oracle(id: String) -> Dictionary:
	var map := RunMap.new()
	map._floor_ids = app.run_map._floor_ids.duplicate(true)
	map._nodes = app.run_map._nodes.duplicate(true)
	map._route = app.run_map.get_route()
	_check(map.choose_node(id), "oracle commits a legal connected Fight")
	var rng := RandomNumberGenerator.new()
	rng.state = app.run_rng.state
	var selector := RunFightEncounterSelection.new()
	selector._bound_map = map
	selector._selected = app.fight_selection._selected.duplicate(true)
	var entry := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, selector)
	_check(entry.get("success", false), "independent typed encounter selection succeeds")
	if not entry.get("success", false):
		return {}
	if entry.node_type == "Fight":
		var definitions: Array = entry.enemies.get_enemies()
		for definition in definitions:
			var scaled := RunNormalAttackFloorScaling.scale_normal_max_hp(
				definition.max_hp, map.get_node(id).floor)
			_check(scaled.ok, "oracle normal roster has valid authored floor scaling")
			if not scaled.ok:
				return {}
			definition.max_hp = scaled.max_hp
		entry.enemies = CombatEnemies.new(definitions)
	var receipt: Dictionary = app._stitch_snapshot()
	var admitted := RunStitchedBattleHandEntry.new().admit_next_fight(
		receipt.deck, receipt.descriptors, receipt.remaining_scraps,
		receipt.next_stitch_id, receipt.receipt, rng)
	_check(admitted.get("ok", false) and admitted.snapshot == receipt,
		"independent canonical service accepts complete authentic receipt")
	if not admitted.get("ok", false):
		return {}
	var party: CombatParty = app.party_carryover.create_next_fight_party()
	var deck: CombatDeck = admitted.combat_deck
	var bound_intents := CombatEnemyIntents.new(entry.intents._definitions)
	_check(bound_intents.bind_battle(entry.enemies, party, rng),
		"independent canonical roster caches weighted intentions after the deck shuffle")
	var result := CombatBattleResult.new(party, entry.enemies)
	var flow := CombatRoundFlow.new(deck, party, entry.enemies, bound_intents, result)
	_check(flow.begin_fight(), "oracle begins exactly one five-card turn")
	return {"mounted": {"heroes": party.get_heroes(), "enemies": entry.enemies.get_enemies(),
		"intents": bound_intents.get_intents(), "encounter": entry.encounter_id,
		"hand": deck.hand.duplicate(), "draw": deck.draw_pile.duplicate(), "rng": rng.state},
		"snapshot": admitted.snapshot, "deck": deck, "party": party, "enemies": entry.enemies,
		"flow": flow, "run_cards": admitted.run_cards}


func _win_earned_elite() -> bool:
	# Use only held cards, production targeting and physical player inputs.
	for turn in range(30):
		for action in range(3):
			if app._battle_closed:
				break
			var chosen := ""
			var target := 0
			for held in app.deck.hand:
				var preview := CombatAttackTargeting.new().get_preview(app.deck, app.party, app.enemies, held)
				if preview.playable and preview.requires_selection:
					chosen = held
					# Remove the dangerous front Elite first when a real held card can target it.
					target = (1 if preview.target_positions.has(1)
						else preview.target_positions.back())
					break
			if chosen.is_empty():
				break
			if not await _choose(chosen, false):
				return false
			await _key(KEY_1 + target - 1)
		if app._battle_closed:
			break
		await _click(app.end_turn_button)
	var won: bool = app.battle_result.get_outcome() == CombatBattleResult.VICTORY
	_check(won and app.reward_buttons.size() == 4, "Elite won through actual held-card inputs")
	if won:
		var heroes: Array[Dictionary] = app.party.get_heroes()
		var hp_values: Array[int] = []
		for hero in heroes:
			hp_values.append(int(hero.get("hp", 0)))
		_check(hp_values.size() == 3 and hp_values.any(func(hp: int) -> bool: return hp > 0),
			"genuine Elite victory retains a three-hero roster with a living owner: HP %s" % [str(hp_values)])
	return won and app.reward_buttons.size() == 4


func _prepare_receipt(fixture: Dictionary, keyboard: bool, use_pool: bool = false) -> String:
	if not await _routed_win(fixture, false):
		return ""
	var first_id := "seamstress_prick"
	if use_pool:
		first_id = app.fight_reward_offers[1].id
		_check(not RunPoolCardRewardOffers.resolve_reward_definition(first_id).is_empty(), "seeded Seamstress pool reward is authentic")
	await _click(app.reward_buttons[1] if use_pool else app.reward_buttons[3])
	_check(app.run_scraps == 1, "opening Fight earns one scrap")
	if use_pool:
		_check(app.run_deck.back() == first_id, "mounted reward claim owns the earned pool half")
	await _click(app.continue_button)
	await _click(_route_action(fixture.elite.back()))
	if not await _win_earned_elite():
		return ""
	var heroes: Array[Dictionary] = app.party.get_heroes()
	var hp_values: Array[int] = []
	for hero in heroes:
		hp_values.append(int(hero.get("hp", 0)))
	_check(hp_values.size() == 3 and hp_values.all(func(hp: int) -> bool: return hp > 0),
		"genuine Elite victory leaves all three stitch owners alive: HP %s" % [str(hp_values)])
	await _click(app.reward_buttons[3])
	_check(app.run_scraps == 3, "genuine Elite claim funds three-scrap Stitch")
	await _click(app.continue_button)
	await _click(_legacy_rest_control(_route_action(fixture.rest.back())))
	_check(app.rest_stitch != null and app.rest_stitch.is_valid()
		and not app.rest_stitch_button.disabled, "connected Rest offers funded stitch")
	if app.rest_stitch == null or app.rest_stitch_button.disabled:
		return ""
	var source: Dictionary = app._stitch_snapshot()
	var first: int = app.run_deck.find(first_id)
	var second: int = app.run_deck.find("tinker_pop_shot")
	_check(first >= 0 and second >= 0, "authored cross-owner originals are owned")
	if first < 0 or second < 0:
		return ""
	var rest_oracle := RunRestStitchCards.new(source.deck, source.descriptors,
		source.remaining_scraps, source.next_stitch_id)
	var made := rest_oracle.choose_stitch(first, second, source)
	_check(made.ok, "independent Rest transaction issues authentic receipt")
	_check(made.descriptor.half_ids == [first_id, "tinker_pop_shot"], "descriptor preserves selected pool/starter half order")
	await _select_stitch(app.rest_stitch_first, first, keyboard)
	await _select_stitch(app.rest_stitch_second, second, keyboard)
	if keyboard:
		app.rest_stitch_button.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(app.rest_stitch_button)
	_check(app.rest_stitch.is_consumed() and app._stitch_snapshot() == rest_oracle.get_snapshot(),
		"mounted Stitch commits complete oracle receipt")
	if not app.rest_stitch.is_consumed():
		return ""
	_check(app.run_deck.count(made.stitched_id) == 1
		and app.run_deck.count(first_id) == source.deck.count(first_id) - 1
		and app.run_deck.count("tinker_pop_shot") == source.deck.count("tinker_pop_shot") - 1
		and app.run_scraps == 0 and app.run_next_stitch_id == 2,
		"one composite consumes exactly the two originals and three scraps")
	await _click(app.rest_continue_button)
	return made.stitched_id


## The already-admitted next Fight is won with real held-card input only, the
## same production targeting and physical keys a player uses.
func _win_held_cards() -> bool:
	for turn in range(30):
		if app._battle_closed:
			break
		for action in range(3):
			if app._battle_closed:
				break
			var chosen := ""
			var target := 0
			for held in app.deck.hand:
				var preview := CombatAttackTargeting.new().get_preview(app.deck, app.party, app.enemies, held)
				if preview.playable and preview.requires_selection:
					chosen = held
					target = preview.target_positions.back()
					break
			if chosen.is_empty():
				break
			if not await _choose(chosen, false):
				return false
			await _key(KEY_1 + target - 1)
		if app._battle_closed:
			break
		await _click(app.end_turn_button)
	var won: bool = app.battle_result.get_outcome() == CombatBattleResult.VICTORY
	_check(won, "stitched run wins the next Fight through actual held-card inputs")
	return won


## A won Fight whose run deck owns a Rest composite still prepares the normal
## seeded reward; pick or Skip settles it once and the run walks onward.
func _settle_and_continue(fixture: Dictionary, composite: String, keyboard: bool) -> Dictionary:
	if not await _win_held_cards():
		return {}
	await _frames()
	var service = app._routed_reward_service()
	_check(app._battle_closed and service != null and app.reward_buttons.size() == 4,
		"won Fight with a composite deck prepares the normal four reward choices")
	if app.reward_buttons.size() != 4:
		return {}
	var offers: Array = app.fight_reward_offers.duplicate(true)
	var award: int = app.fight_reward_gold
	var drop: String = app.fight_reward_trinket
	_check(offers.size() == 3, "composite reward offers exactly three cards")
	if offers.size() != 3:
		return {}
	var living_owners: Array[String] = []
	for hero in app.party.get_heroes():
		if int(hero.get("hp", 0)) > 0:
			living_owners.append(str(hero.get("id", "")))
	_check(not living_owners.is_empty(), "victory reward has actual living hero owners")
	var eligible_bases: Dictionary = {}
	for candidate in RunPoolCardRewardOffers.get_authored_base_candidates():
		eligible_bases[str(candidate.get("id", ""))] = str(candidate.get("owner", ""))
	_check(not eligible_bases.is_empty(), "authored base reward catalog exists")
	var offered_ids: Array[String] = []
	for index in range(3):
		var offer: Dictionary = offers[index]
		var offered_id := str(offer.get("id", ""))
		var definition: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(offered_id)
		var owner := str(offer.get("owner", ""))
		_check(not definition.is_empty() and definition.get("owner") == owner
			and eligible_bases.get(offered_id, "") == owner and living_owners.has(owner)
			and not offered_ids.has(offered_id),
			"composite reward offers a unique authored base card from a living owner " + str(index + 1))
		if index < living_owners.size():
			_check(owner == living_owners[index],
				"first-pass rewards follow living party order " + str(index + 1))
		offered_ids.append(offered_id)
	_check(award >= 10 and award <= 20 and drop.is_empty(),
		"composite Fight pays the authored normal gold range without a trinket")
	_check(is_instance_valid(app.continue_button) == false, "unsettled composite reward exposes no Continue")
	var deck_before: Array = app.run_deck.duplicate()
	var gold_before: int = app.session_gold
	var scraps_before: int = app.run_scraps
	var descriptors_before: Dictionary = app.run_stitch_descriptors.duplicate(true)
	var cursor_before: int = app.run_next_stitch_id
	if keyboard:
		app.reward_buttons[3].grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(app.reward_buttons[0])
	var expected_deck: Array = deck_before.duplicate()
	if not keyboard:
		expected_deck.append(offers[0]["id"])
	_check(app.fight_reward_claimed and app.run_deck == expected_deck
		and app.session_gold == gold_before + award and app.run_scraps == scraps_before + 1,
		"composite reward pick/Skip publishes exactly one card, award and scrap")
	_check(app.run_deck.count(composite) == 1
		and app.run_stitch_descriptors == descriptors_before
		and app.run_next_stitch_id == cursor_before,
		"authentic composite stays exactly one deck member with intact descriptors")
	var replay_claim: Dictionary = (service.choose(app._carryover_node, "")
		if service is RunMultiFightRewards else service.choose(""))
	_check(not replay_claim.get("ok", false), "settled composite reward service cannot pay again")
	var settled: Array = [app.run_deck.duplicate(), app.session_gold, app.run_scraps,
		app.run_rng.state, app.run_stitch_descriptors.duplicate(true)]
	app.reward_buttons[0].pressed.emit()
	app.reward_buttons[3].pressed.emit()
	_check([app.run_deck, app.session_gold, app.run_scraps, app.run_rng.state,
		app.run_stitch_descriptors] == settled,
		"forced duplicate reward callbacks cannot settle or spend twice")
	_check(is_instance_valid(app.continue_button) and not app.continue_button.disabled,
		"settled composite victory enables the connected Continue")
	if not is_instance_valid(app.continue_button):
		return {}
	var trace := {"offers": offers, "award": award, "drop": drop,
		"rng": app.run_rng.state, "gold": app.session_gold, "scraps": app.run_scraps,
		"descriptors": app.run_stitch_descriptors.duplicate(true),
		"cursor": app.run_next_stitch_id}
	await _click(app.continue_button)
	_check(app.route_view != null and app.route_view.is_visible_in_tree()
		and app._can_choose_connected_route(),
		"composite victory Continue opens the onward connected route")
	var choices: Array = app.run_map.get_legal_choices()
	var onward: String = str(fixture.get("onward", ""))
	_check(not choices.is_empty() and choices.has(onward),
		"onward route offers the seeded connected battle")
	if not choices.has(onward):
		return trace
	var prior: Array[String] = app.run_map.get_route()
	await _click(_route_action(onward))
	_check(app.run_map.get_route() == prior + [onward]
		and app.run_map.get_current_node_id() == onward,
		"onward routed battle commits exactly once after a composite reward")
	_check(app.deck != null and app.deck.hand.size() == 5 and app.deck.energy == 3
		and app.deck.turn_active and app._stitch_snapshot().deck.count(composite) == 1,
		"onward battle mounts a playable hand with the composite still owned")
	await _click(app.return_button)
	_check(app.title_view.visible and app.run_map == null and app.run_deck.is_empty()
		and app.run_stitch_descriptors.is_empty(),
		"composite reward run returns to a clean title")
	return trace


func _play_natural(id: String, oracle: Dictionary, keyboard: bool) -> void:
	var expected_deck: CombatDeck = oracle.deck
	# Normal End Turn deals the next hand; no extra draws or hand injection.
	for turn in range(3):
		if app.deck.hand.has(id) or app._battle_closed:
			break
		_check(oracle.flow.end_turn(), "independent oracle advances natural turn")
		await _click(app.end_turn_button)
		_check(app.deck.hand == expected_deck.hand and app.deck.draw_pile == expected_deck.draw_pile
			and app.deck.discard_pile == expected_deck.discard_pile
			and app.run_rng.state == expected_deck._rng.state
			and app.party.get_heroes() == oracle.party.get_heroes()
			and app.enemies.get_enemies() == oracle.enemies.get_enemies(), "natural draw matches independent battle")
	_check(not app._battle_closed and app.deck.hand.has(id) and _panel(id) != null,
		"owned composite is naturally held in active mounted Fight")
	if app._battle_closed or not app.deck.hand.has(id):
		return
	var preview := CombatStitchedTargetPreview.new().get_preview(oracle.run_cards,
		oracle.snapshot, expected_deck, oracle.party, oracle.enemies, id)
	_check(preview.playable and preview.halves.size() == 2
		and preview.halves[0].requires_selection and preview.halves[1].requires_selection,
		"two legal ordered enemy target choices required")
	if not preview.playable:
		return
	var first: int = preview.halves[0].target_positions.front()
	var second: int = preview.halves[1].target_positions.back()
	var attacks := CombatAttackCards.new()
	var expected := CombatStitchedCards.new(attacks).play_stitched(expected_deck,
		oracle.party, oracle.enemies, oracle.run_cards, id, first, second)
	_check(expected.ok and expected.halves.size() == 2, "independent ordered combat resolution succeeds")
	var before := _complete_state()
	await _arm(id, keyboard)
	_check(presenter._armed == _panel(id), "real held stitched panel armed")
	await _pick(first, "enemy", keyboard)
	_check(presenter._choices == [first] and _complete_state() == before,
		"first legal target waits without spending or applying either half")
	await _pick(second, "enemy", keyboard)
	_check(presenter.last_event == expected and app.party.get_heroes() == oracle.party.get_heroes()
		and app.enemies.get_enemies() == oracle.enemies.get_enemies(),
		"real second target resolves ordered effects and authoritative actors exactly")
	_check(app.deck.hand == expected_deck.hand and app.deck.draw_pile == expected_deck.draw_pile
		and app.deck.discard_pile == expected_deck.discard_pile and app.deck.discard_pile.count(id) == 1
		and app.deck.energy == expected_deck.energy and app.deck.energy == before[0][3] - 2
		and app.run_rng.state == expected_deck._rng.state and app._stitch_snapshot() == oracle.snapshot,
		"single charge and whole-card discard preserve piles, RNG and full run ledger")
	_check(expected.halves[0].hits[0].statuses == {"bleed": 3}
		and expected.halves[1].hits[0].damage == 8 and presenter._play._tinker._consumed,
		"Seamstress on-hit Bleed and Tinker first-attack passive survive routed admission")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _hand_fixture()
	_check(not fixture.is_empty(), "seeded legal Fight -> Elite -> Rest -> Fight path exists")
	var replay: Array = []
	var reward_replay: Dictionary = {}
	for session in range(4):
		if fixture.is_empty():
			break
		var id := await _prepare_receipt(fixture, session % 2 == 1, session >= 2)
		if id.is_empty():
			break
		var button := _route_action(fixture.next)
		var callback: Callable = button.pressed.get_connections()[0].callable
		var prior: Array[String] = app.run_map.get_route()
		var empty: Array[String] = []
		_reject_admission(app._choose_battle_route.bind(fixture.next, weakref(app.run_map), empty, button), "stale route control")
		var registry: Dictionary = app.run_stitch_descriptors.duplicate(true)
		app.run_stitch_descriptors[id].first_half.effects.damage = 999
		_reject_admission(callback, "corrupted canonical descriptor")
		app.run_stitch_descriptors = registry
		var oracle := _canonical_oracle(fixture.next)
		if oracle.is_empty():
			break
		if session % 2 == 1:
			button.grab_focus()
			await _key(KEY_ENTER)
		else:
			await _click(button)
		_check(app.run_map.get_route() == prior + [fixture.next] and app.route_view == null
			and _mounted_state() == oracle.mounted and app._stitch_snapshot() == oracle.snapshot,
			"connected Fight admission matches full canonical snapshot, encounter, shuffle, hand and RNG")
		var all_cards: Array = app.deck.hand + app.deck.draw_pile + app.deck.discard_pile
		all_cards.sort()
		var owned: Array = oracle.snapshot.deck.duplicate()
		owned.sort()
		_check(all_cards == owned and all_cards.count(id) == 1 and app.deck.hand.size() == 5
			and app.deck.energy == 3 and app.deck._rng == app.run_rng,
			"canonical multiset, exactly one seeded shuffle, five-card opening and three energy")
		_reject_admission(callback, "retained already-used route callback")
		if session >= 2:
			_check(app.run_stitch_descriptors[id].half_ids[0].begins_with("seamstress_")
				and not catalog.has_card(app.run_stitch_descriptors[id].half_ids[0]),
				"earned pool composite admitted into genuine next Fight")
			var pool_trace := _complete_state()
			if session == 2:
				replay = pool_trace
			else:
				_check(pool_trace == replay, "earned pool mouse/keyboard replay matches full admission and RNG")
			await _click(app.return_button)
			continue
		await _play_natural(id, oracle, session == 1)
		var trace := _complete_state()
		if session == 0:
			replay = trace
		else:
			_check(trace == replay, "same-seed mouse/keyboard replay matches complete final combat and ledger")
		var settled := await _settle_and_continue(fixture, id, session == 1)
		if settled.is_empty():
			break
		if session == 0:
			reward_replay = settled
		else:
			_check(settled == reward_replay,
				"same-seed composite reward and onward route replay exactly")
	# A separate nonstitched connected Fight still uses the same admission path.
	var plain := _battle_fixture("Fight")
	_check(not plain.is_empty(), "plain connected Fight fixture exists")
	if not plain.is_empty() and await _routed_win(plain, false):
		await _click(app.reward_buttons[3])
		await _click(app.continue_button)
		var transit: Array = plain.path.duplicate()
		var next_fight: String = transit.pop_back()
		await _visit_path(transit, false)
		_check(app.run_map.get_node(next_fight).get("type") == "Fight"
			and app.run_map.get_legal_choices().has(next_fight),
			"plain routed fixture reaches an actual connected Fight after transit")
		var oracle := _canonical_oracle(next_fight)
		await _click(_route_action(next_fight))
		_check(not oracle.is_empty() and _mounted_state() == oracle.mounted
			and app.run_stitch_descriptors.is_empty() and app.deck.hand.size() == 5
			and app.deck.energy == 3, "plain routed Fight matches canonical admission oracle")
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_stitched_next_fight_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
