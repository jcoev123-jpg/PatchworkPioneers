extends "res://tests/live_rest_upgrade_choice_test.gd"
## Each family travels through real reward, Rest input and next-battle admission.


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _upgrade_fixture()
	_check(not fixture.is_empty(), "authentic seeded Fight -> Rest -> Fight fixture exists")
	if fixture.is_empty():
		await _finish_upgrade()
		return
	var families := ["warden_shield_bash", "seamstress_prick", "tinker_pop_shot", "tinker_scrap_bomb"]
	var completed: Array[String] = []
	for base_id: String in families:
		seed(2110211)
		var global_next := randi()
		seed(2110211)
		if not await _routed_win(fixture, false):
			break
		_check(app.fight_rewards != null and app.reward_buttons.size() >= 3,
			base_id + ": real victory offers claimable rewards")
		if app.fight_rewards == null or app.reward_buttons.size() < 3:
			break
		var earned_id: String = app.fight_reward_offers[0].id
		var starting: Array = app.run_deck.duplicate()
		await _click(app.reward_buttons[0])
		_check(app.run_deck == starting + [earned_id] and app.fight_reward_claimed,
			base_id + ": genuine Fight reward is earned into the run ledger")
		await _click(app.continue_button)
		await _click(_route_action(fixture.rest))
		_check(app.rest_upgrade != null and is_instance_valid(app.rest_upgrade_cards)
			and app.rest_view.is_visible_in_tree(), base_id + ": connected Rest is mounted")
		if app.rest_upgrade == null or not is_instance_valid(app.rest_upgrade_cards):
			break
		var source: Array = app.run_deck.duplicate()
		var index: int = source.rfind(base_id)
		var plus_id := base_id + "_plus"
		var choices: OptionButton = app.rest_upgrade_cards
		var row := -1
		for item in range(choices.item_count):
			if choices.get_item_metadata(item) == index:
				row = item
		_check(index >= 0 and row >= 0, base_id + ": real owned occurrence has a rendered selector row")
		if index < 0 or row < 0:
			break
		var definition := catalog.get_definition(plus_id)
		_check(choices.get_item_text(row).contains(definition.display_name)
			and choices.get_item_text(row).contains("#%d" % (index + 1)),
			base_id + ": selector names the authored plus and exact occurrence")
		var tile = _tile_for("upgrade", row)
		_check(tile != null, base_id + ": rendered choice owns an interactive tile")
		if tile == null:
			break
		var before := _persistent()
		var ledger: Dictionary = app.party_carryover.read_state()
		var stitch: Dictionary = app._stitch_snapshot()
		await _select_tile_by_key(tile)
		_check(_persistent() == before and choices.selected == row,
			base_id + ": keyboard selects only the intended occurrence without spending")
		var visit: RunRestCardUpgrade = app.rest_upgrade
		var callback: Callable = app.rest_upgrade_button.pressed.get_connections()[0].callable
		await _click(app.rest_upgrade_button)
		var expected := source.duplicate()
		expected[index] = plus_id
		_check(visit.is_consumed() and app.run_deck == expected and not app.rest_recovery.is_consumed(),
			base_id + ": mounted Upgrade replaces exactly one occurrence once")
		_check(_persistent().slice(2) == before.slice(2) and app.run_heroes == before[0]
			and app.party_carryover.read_state() == ledger
			and app.run_scraps == stitch.remaining_scraps
			and app.run_stitch_descriptors == stitch.descriptors
			and app.run_next_stitch_id == stitch.next_stitch_id,
			base_id + ": upgrade preserves currency, RNG, route, heroes and stitch ledger")
		_reject_upgrade(callback, base_id + ": replay rejected")
		await _click(app.rest_continue_button)
		_check(app.route_view != null and not app.rest_view.visible,
			base_id + ": Continue returns to connected choices")
		var oracle := _oracle(fixture.next)
		await _click(_route_action(fixture.next))
		_check(app.battle_result.get_outcome() == CombatBattleResult.ACTIVE and _mounted_state() == oracle,
			base_id + ": next genuine Fight admits exact upgraded run deck")
		while not app.deck.hand.has(plus_id) and not app.deck.draw_pile.is_empty():
			_check(app.deck.draw_extra(1) == 1, base_id + ": draw real next-Fight card")
		app._refresh_hand()
		await _frames()
		_check(app.deck.hand.has(plus_id) and app.run_deck == expected,
			base_id + ": corresponding plus reaches actual next-Fight hand")
		var held := false
		for panel in app.hand_view.get_children():
			if panel.get_child_count() > 0 and panel.get_child(0) is Label:
				held = held or panel.get_child(0).text == plus_id
		_check(held, base_id + ": upgraded card is rendered in mounted shared hand")
		_reject_upgrade(callback, base_id + ": previous Rest callback stays inert in combat")
		await _click(app.return_button)
		_check(randi() == global_next, base_id + ": whole seeded route preserves global RNG")
		completed.append(base_id)
	_check(completed == families, "all four independent seeded visits exercised every route assertion")
	await _finish_upgrade()


func _finish_upgrade() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_authored_starter_upgrade_route_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
