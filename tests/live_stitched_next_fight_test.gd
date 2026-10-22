extends "res://tests/live_stitched_hand_play_test.gd"
## Title -> earned scraps -> genuine Rest receipt -> canonical routed admission.


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
	var result := CombatBattleResult.new(party, entry.enemies)
	var flow := CombatRoundFlow.new(deck, party, entry.enemies, entry.intents, result)
	_check(flow.begin_fight(), "oracle begins exactly one five-card turn")
	return {"mounted": {"heroes": party.get_heroes(), "enemies": entry.enemies.get_enemies(),
		"intents": entry.intents.get_intents(), "encounter": entry.encounter_id,
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
	_check(won and app.reward_buttons.size() == 4, "Elite won through actual held-card inputs")
	return won and app.reward_buttons.size() == 4


func _prepare_receipt(fixture: Dictionary, keyboard: bool) -> String:
	if not await _routed_win(fixture, false):
		return ""
	await _click(app.reward_buttons[3])
	_check(app.run_scraps == 1, "opening Fight earns one scrap")
	await _click(app.continue_button)
	await _click(_route_action(fixture.elite.back()))
	if not await _win_earned_elite():
		return ""
	await _click(app.reward_buttons[3])
	_check(app.run_scraps == 3, "genuine Elite claim funds three-scrap Stitch")
	await _click(app.continue_button)
	await _click(_route_action(fixture.rest.back()))
	_check(app.rest_stitch != null and app.rest_stitch.is_valid()
		and not app.rest_stitch_button.disabled, "connected Rest offers funded stitch")
	if app.rest_stitch == null or app.rest_stitch_button.disabled:
		return ""
	var source: Dictionary = app._stitch_snapshot()
	var first: int = app.run_deck.find("seamstress_prick")
	var second: int = app.run_deck.find("tinker_pop_shot")
	_check(first >= 0 and second >= 0, "authored cross-owner originals are owned")
	if first < 0 or second < 0:
		return ""
	var rest_oracle := RunRestStitchCards.new(source.deck, source.descriptors,
		source.remaining_scraps, source.next_stitch_id)
	var made := rest_oracle.choose_stitch(first, second, source)
	_check(made.ok, "independent Rest transaction issues authentic receipt")
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
		and app.run_deck.count("seamstress_prick") == source.deck.count("seamstress_prick") - 1
		and app.run_deck.count("tinker_pop_shot") == source.deck.count("tinker_pop_shot") - 1
		and app.run_scraps == 0 and app.run_next_stitch_id == 2,
		"one composite consumes exactly the two originals and three scraps")
	await _click(app.rest_continue_button)
	return made.stitched_id


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
	for session in range(2):
		if fixture.is_empty():
			break
		var id := await _prepare_receipt(fixture, session == 1)
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
		if session == 1:
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
		await _play_natural(id, oracle, session == 1)
		var trace := _complete_state()
		if session == 0:
			replay = trace
		else:
			_check(trace == replay, "same-seed mouse/keyboard replay matches complete final combat and ledger")
		await _click(app.return_button)
	# A separate nonstitched connected Fight still uses the same admission path.
	var plain := _battle_fixture("Fight")
	_check(not plain.is_empty(), "plain connected Fight fixture exists")
	if not plain.is_empty() and await _routed_win(plain, false):
		await _click(app.reward_buttons[3])
		await _click(app.continue_button)
		var oracle := _canonical_oracle(plain.path[0])
		await _click(_route_action(plain.path[0]))
		_check(not oracle.is_empty() and _mounted_state() == oracle.mounted
			and app.run_stitch_descriptors.is_empty() and app.deck.hand.size() == 5
			and app.deck.energy == 3, "plain routed Fight matches canonical admission oracle")
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_stitched_next_fight_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
