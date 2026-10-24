extends "res://tests/live_rest_upgrade_choice_test.gd"
## Reuse the routed Rest harness without changing its existing coverage.

const TUNE_PLUS := "tinker_tune_up_plus"


func _tune_panel() -> Control:
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0) is Label \
				and panel.get_child(0).text == TUNE_PLUS:
			return panel
	return null


func _tune_persistent() -> Array:
	return [_persistent(), app.run_scraps, app.party_carryover.read_state(),
		app.run_stitch_descriptors.duplicate(true), app.run_next_stitch_id]


func _reject_tune_support(support, id: String, target: int, reason: String) -> void:
	var before := _tune_persistent()
	_check(not support._play_held(app.deck, app.party, id, target), reason + " rejects")
	_check(_tune_persistent() == before, reason + " preserves combat, run, wallet, route and RNG")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _upgrade_fixture()
	_check(not fixture.is_empty(), "authentic seeded Fight -> Rest -> Fight exists")
	if fixture.is_empty():
		await _finish_tune()
		return
	var replay: Array = []
	var stale: Callable
	for keyboard in [false, true]:
		if not await _routed_win(fixture, false):
			break
		await _click(app.reward_buttons[3])
		await _click(app.continue_button)
		await _click(_route_action(fixture.rest))
		_check(app.rest_upgrade != null and app.rest_view.is_visible_in_tree(), "real connected Rest has upgrade authority")
		if app.rest_upgrade == null:
			break
		var visit: RunRestCardUpgrade = app.rest_upgrade
		var source: Array = app.run_deck.duplicate()
		var choices: OptionButton = app.rest_upgrade_cards
		var upgrade: Callable = app.rest_upgrade_button.pressed.get_connections()[0].callable
		var row := -1
		var index := source.find("tinker_tune_up")
		for i in range(app._rest_upgrade_choices.size()):
			if app._rest_upgrade_choices[i].index == index:
				row = i
		_check(index >= 0 and row >= 0 and source.count("tinker_tune_up") == 1,
			"owned Tune Up occurrence has a canonical row")
		if row < 0:
			break
		var tile = _tile_for("upgrade", row)
		_check(tile != null and app._rest_upgrade_choices[row].plus_effects == {"draw": 2},
			"real Tune Up tile previews authored draw two")
		if tile == null:
			break
		var before := _tune_persistent()
		if keyboard:
			await _select_tile_by_key(tile)
		else:
			await _click_tile(tile)
		_check(choices.selected == row and choices.get_item_metadata(row) == index
			and _tune_persistent() == before, "physical selection selects exact copy without spending")
		choices.set_item_metadata(row, -1)
		_reject_upgrade(upgrade, "invalid Tune Up row")
		choices.set_item_metadata(row, index)
		if stale.is_valid():
			_reject_upgrade(stale, "stale previous Rest callback")
		if keyboard:
			tile.grab_focus()
			for step in range(_visit_tiles().upgrade_tiles().size() + 2):
				if app.rest_upgrade_button.has_focus():
					break
				await _key(KEY_TAB)
			_check(app.rest_upgrade_button.has_focus(), "Tab reaches genuine Upgrade action")
			await _key(KEY_ENTER)
		else:
			await _click(app.rest_upgrade_button)
		var expected := source.duplicate()
		expected[index] = TUNE_PLUS
		_check(visit.is_consumed() and app.run_deck == expected,
			"real Rest upgrades selected Tune Up exactly once")
		_check(_tune_persistent()[0].slice(2) == before[0].slice(2)
			and _tune_persistent().slice(1) == before.slice(1), "upgrade preserves HP, wallet, route, ledger and RNG")
		_reject_upgrade(upgrade, "second Tune Up upgrade")
		stale = upgrade
		await _click(app.rest_continue_button)
		_reject_upgrade(upgrade, "hidden completed Rest")
		var oracle := _oracle(fixture.next)
		await _click(_route_action(fixture.next))
		_check(app.battle_result.get_outcome() == CombatBattleResult.ACTIVE
			and _mounted_state() == oracle, "next routed Fight admits exact upgraded deck and seeded state")
		# Draw only through the real deck; never insert a held card.
		while not app.deck.hand.has(TUNE_PLUS) and not app.deck.draw_pile.is_empty():
			_check(app.deck.draw_extra(1) == 1, "natural next-Fight draw reaches upgraded copy")
		app._refresh_hand()
		await _frames()
		var held := _tune_panel()
		var support = app.get_node("LiveSupportHand")
		_check(held != null and support._bindings.has(held)
			and support._eligible(held, TUNE_PLUS, app.deck, app.party, app.battle_view),
			"genuine held Tune Up+ has mounted support input")
		_check(app.deck.draw_pile.size() >= 2, "two natural cards remain to prove draw two")
		if held == null or app.deck.draw_pile.size() < 2:
			break
		_check(app.deck.try_spend_energy(app.deck.energy) and app.deck.energy == 0,
			"real held zero-cost play starts at zero energy")
		_reject_tune_support(support, TUNE_PLUS, 1, "target supplied to held Tune Up+")
		_reject_tune_support(support, "tinker_tune_up_plus_forged", 0, "forged support ID")
		_check(app.deck.combat_state.end_player_turn() and app.deck.hand.has(TUNE_PLUS),
			"inactive fixture still genuinely holds upgraded copy")
		_reject_tune_support(support, TUNE_PLUS, 0, "inactive held Tune Up+")
		_check(app.deck.combat_state.start_player_turn() and app.deck.try_spend_energy(app.deck.energy),
			"restore active zero-energy turn before next rejection")
		var healthy: Array = app.party.get_heroes()
		_check(app.party.apply_damage(3, 999) and app.party.is_downed(3)
			and app.party.get_hero(3).id == "tinker", "held support owner genuinely downed")
		_reject_tune_support(support, TUNE_PLUS, 0, "downed held Tune Up+ owner")
		app.party._heroes = healthy.duplicate(true)
		var combat_before := _tune_persistent()
		var expected_hand: Array = app.deck.hand.duplicate()
		expected_hand.erase(TUNE_PLUS)
		var expected_draw: Array = app.deck.draw_pile.duplicate()
		expected_hand.append(expected_draw.pop_back())
		expected_hand.append(expected_draw.pop_back())
		var expected_discard: Array = app.deck.discard_pile.duplicate()
		expected_discard.append(TUNE_PLUS)
		var actors: Array = [app.party.get_heroes(), app.enemies.get_enemies()]
		var rng_before: int = app.run_rng.state
		if keyboard:
			held.grab_focus()
			await _key(KEY_ENTER)
		else:
			await _click(held)
		await _frames()
		_check(app.deck.hand == expected_hand and app.deck.draw_pile == expected_draw
			and app.deck.discard_pile == expected_discard and app.deck.energy == 0,
			"physical held play draws exactly two and discards once without energy")
		_check(support._pending.is_empty() and support._targets.is_empty(), "Tune Up+ needs no target")
		_check([app.party.get_heroes(), app.enemies.get_enemies()] == actors
			and app.run_rng.state == rng_before, "draw-two preserves actors and RNG without reshuffle")
		_check(_tune_persistent()[0].slice(0, 5) == combat_before[0].slice(0, 5)
			and _tune_persistent()[0].slice(6) == combat_before[0].slice(6)
			and _tune_persistent().slice(1) == combat_before.slice(1), "combat support preserves run deck, HP, wallet and route")
		var state := _tune_persistent()
		if keyboard:
			_check(state == replay, "same-seed mouse and keyboard route and support replay agree")
		else:
			replay = state.duplicate(true)
		_check(not app.deck.hand.has(TUNE_PLUS), "played upgraded copy genuinely absent from hand")
		_reject_tune_support(support, TUNE_PLUS, 0, "absent-hand Tune Up+")
		await _click(app.return_button)
		var title_state: Array = [app.run_deck.duplicate(), app.run_heroes.duplicate(true), app.run_map, app.run_rng]
		stale.call()
		_check([app.run_deck, app.run_heroes, app.run_map, app.run_rng] == title_state,
			"stale Rest callback inert after title")
	await _finish_tune()


func _finish_tune() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_tune_up_plus_route_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
