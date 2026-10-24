extends "res://tests/live_multi_fight_settlement_test.gd"
## Earn the purse through mounted Fight/Elite claims before choosing Rest.


func _stitch_fixture() -> Dictionary:
	for value in range(1, 3000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for fight in map.get_legal_choices():
			if map.get_node(fight).type != "Fight":
				continue
			var elite := _path_to(map, fight, "Elite")
			if elite.is_empty():
				continue
			var rest := _path_to(map, elite.back(), "Rest")
			if rest.is_empty():
				continue
			map.choose_node(fight)
			var selected := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
			map.undo_choice(fight, [])
			if selected.get("encounter_id") == "starter_attacks":
				return {"seed": value, "fight": fight, "elite": elite, "rest_path": rest}
	return {}


func _stitch_state() -> Array:
	return [app._stitch_snapshot(), _persistent(), app.party_carryover.read_state(),
		app.run_map.get_floors(), app.rest_stitch.get_snapshot(), app.rest_stitch.is_consumed(),
		app.rest_recovery.is_consumed(), app.rest_upgrade.is_consumed(),
		app._rest_stitch_committed.duplicate(true), app._rest_committed_deck.duplicate(),
		app._rest_committed_heroes.duplicate(true), app.rest_continue_button.disabled,
		app.rest_stitch_button.disabled, app.rest_heal_button.disabled, app.rest_upgrade_button.disabled]


func _reject_stitch(callback: Callable, reason: String) -> void:
	var before := _stitch_state()
	callback.call()
	_check(_stitch_state() == before, reason + " preserves purse, receipt, models, RNG and admission")


func _select_stitch(selector: OptionButton, item: int, keyboard: bool) -> void:
	await _frames()
	if keyboard:
		selector.grab_focus()
		await _key(KEY_SPACE)
		for index in range(item):
			await _key(KEY_DOWN)
		await _key(KEY_ENTER)
	else:
		await _click(selector)
		var popup := selector.get_popup()
		_check(popup.visible, "mouse opens stitch instance menu")
		var height := popup.get_theme_font("font").get_height(popup.get_theme_font_size("font_size")) + popup.get_theme_constant("v_separation")
		var margin := popup.get_theme_stylebox("panel").get_content_margin(SIDE_TOP)
		var point := Vector2(popup.position) + Vector2(30, margin + height * (item + 0.5))
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			root.push_input(event, true)
		await _frames()
	_check(selector.selected == item, "physical input selects original instance %d" % item)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _stitch_fixture()
	_check(not fixture.is_empty(), "seeded Fight -> Elite -> Rest fixture exists")
	if fixture.is_empty():
		await _finish_stitch()
		return
	var replay: Array = []
	var retained: Callable
	for session in range(5):
		seed(820082)
		var global_next := randi()
		seed(820082)
		if not await _routed_win(fixture, false):
			break
		_check(app.run_scraps == 0 and app.run_stitch_descriptors.is_empty() and app.run_next_stitch_id == 1, "new run has no free scraps or descriptors")
		var earned_pool: String = app.fight_reward_offers[0].id
		_check(not RunPoolCardRewardOffers.resolve_reward_definition(earned_pool).is_empty(), "real seeded pool offer exists")
		var claim: Callable = app.reward_buttons[0].pressed.get_connections()[0].callable
		var rng_before: int = app.run_rng.state
		await _click(app.reward_buttons[0])
		_check(app.run_scraps == 1 and app.run_deck.back() == earned_pool and app.run_rng.state == rng_before, "opening Fight claims seeded pool card and exactly one scrap without RNG")
		claim.call()
		app._observe_battle_result()
		_check(app.run_scraps == 1, "duplicate claim and observation cannot mint scraps")
		await _click(app.continue_button)
		var path: Array = fixture.elite.duplicate()
		var elite: String = path.pop_back()
		await _visit_path(path, false)
		await _click(_route_action(elite))
		_check(app.run_map.get_current_node_id() == elite and app.battle_result.get_outcome() == CombatBattleResult.ACTIVE, "actual routed Elite mounted")
		for enemy in app.enemies.get_enemies():
			_check(app.enemies.apply_damage(enemy.position, 9999), "defeat real Elite actor")
		app._observe_battle_result()
		await _frames()
		_check(app.reward_buttons.size() == 4 and app.multi_fight_rewards != null, "Elite reward controls exist")
		if app.reward_buttons.size() != 4:
			break
		rng_before = app.run_rng.state
		claim = app.reward_buttons[3].pressed.get_connections()[0].callable
		await _click(app.reward_buttons[3])
		_check(app.run_scraps == 3 and app.run_rng.state == rng_before, "Elite Skip adds exactly two scraps without RNG")
		claim.call()
		_check(app.run_scraps == 3, "duplicate Elite claim inert")
		await _click(app.continue_button)
		await _visit_path(fixture.rest_path.slice(0, -1), false)
		if session == 4:
			# Authentic canonical ledger with a pool upgrade and an issued composite;
			# mount it through the same connected Rest admission as the earned deck.
			var plus: String = WardenPoolCards.new().get_upgrade_id(earned_pool)
			_check(RunRestStitchCards.is_authored_pool_plus(plus), "earned pool has an authored plus")
			app.run_deck.append(plus)
			app.run_deck.append("seamstress_prick_plus")
			app.run_deck.append("tinker_pop_shot")
			var ledger := RunRestStitchCards.new(app.run_deck, {}, 6, 1)
			_check(ledger.is_valid(), "canonical plus ledger is valid before crafting")
			var issued := ledger.choose_stitch(app.run_deck.size() - 2, app.run_deck.size() - 1, ledger.get_snapshot())
			_check(issued.ok, "fixture composite issued by authentic transaction")
			app.run_deck.assign(issued.deck)
			# Put the composite before the pool + so later metadata cannot merely
			# mirror menu positions; retain a separate starter + occurrence too.
			app.run_deck.erase(issued.stitched_id)
			app.run_deck.insert(app.run_deck.size() - 1, issued.stitched_id)
			app.run_deck.append("warden_strike_plus")
			app.run_stitch_descriptors = issued.descriptors.duplicate(true)
			app.run_scraps = issued.remaining_scraps
			app.run_next_stitch_id = issued.next_stitch_id
		await _click(_route_action(fixture.rest_path.back()))
		_check(app.rest_stitch != null and app.rest_stitch.is_valid() and not app.rest_stitch_button.disabled, "earned purse admits real Rest stitch")
		if app.rest_stitch == null:
			break
		_bounds(app.rest_view)
		var first: OptionButton = app.rest_stitch_first
		var second: OptionButton = app.rest_stitch_second
		var button: Button = app.rest_stitch_button
		var stitch: Callable = button.pressed.get_connections()[0].callable
		var heal: Callable = app.rest_heal_button.pressed.get_connections()[0].callable
		var upgrade: Callable = app.rest_upgrade_button.pressed.get_connections()[0].callable
		var next: Callable = app.rest_continue_button.pressed.get_connections()[0].callable
		var eligible: Array[int] = []
		for index in range(app.run_deck.size()):
			if not app.run_stitch_descriptors.has(app.run_deck[index]):
				eligible.append(index)
		_check(first.item_count == eligible.size() and second.item_count == eligible.size(), "every canonical original occurrence offered; composites excluded")
		_check(eligible.has(app.run_deck.find(earned_pool)), "earned pool occurrence inspected in both selectors")
		if session == 4:
			_check(app.run_stitch_descriptors.size() == 1 and eligible.size() == app.run_deck.size() - 1
				and eligible.has(app.run_deck.find(WardenPoolCards.new().get_upgrade_id(earned_pool))), "nonempty authentic composite and pool plus fixture inspected")
		for item in range(eligible.size()):
			var index: int = eligible[item]
			_check(first.get_item_metadata(item) == index and second.get_item_metadata(item) == index, "selectors retain original indices across excluded composites")
			var definition: Dictionary = catalog.get_definition(app.run_deck[index])
			if definition.is_empty():
				definition = WardenPoolCards.new().get_definition(app.run_deck[index])
			_check(not definition.is_empty(), "selector has independent authored definition")
			var suffix := "Deck #%d: %s - %s" % [index + 1, str(definition.owner).capitalize(), definition.display_name]
			_check(first.get_item_text(item) == "First card: " + suffix
				and second.get_item_text(item) == "Second card: " + suffix,
				"mounted selectors visibly identify ordered halves with exact occurrence and owner")
		_check(first.text.begins_with("First card: ") and second.text.begins_with("Second card: ")
			and first.size.y == second.size.y, "closed selectors expose distinct roles without an extra row")
		_reject_stitch(next, "premature Continue")
		_reject_stitch(stitch, "same instance")
		second.select(1)
		_check(catalog.get_definition(app.run_deck[0]).owner == catalog.get_definition(app.run_deck[1]).owner, "same-owner negative fixture")
		_reject_stitch(stitch, "different instances same owner")
		var first_index: int = app.run_deck.rfind("warden_strike")
		var second_index: int = app.run_deck.find("seamstress_prick")
		_check(first_index > 0 and second_index > first_index, "second duplicate and different-owner fixture exists")
		first.select(first_index)
		second.select(second_index)
		if retained.is_valid():
			_reject_stitch(retained, "old session callback")
		for field in ["run_scraps", "run_next_stitch_id"]:
			var original: int = app.get(field)
			app.set(field, original + 1)
			_reject_stitch(stitch, "stale " + field)
			app.set(field, original)
		app.run_scraps = 2
		_reject_stitch(stitch, "insufficient purse")
		app.run_scraps = 3
		var registry: Dictionary = app.run_stitch_descriptors.duplicate(true)
		app.run_stitch_descriptors["forged"] = {}
		_reject_stitch(stitch, "stale registry")
		app.run_stitch_descriptors = registry
		var receipt: Dictionary = app.rest_stitch._source_snapshot.duplicate(true)
		app.rest_stitch._source_snapshot.receipt = "forged"
		_reject_stitch(stitch, "stale receipt")
		app.rest_stitch._source_snapshot = receipt
		app.rest_stitch._valid = false
		_reject_stitch(stitch, "failed service")
		app.rest_stitch._valid = true
		var ledger: Array = app.party_carryover._rest_ids.duplicate()
		app.party_carryover._rest_ids.append(app.run_map.get_current_node_id())
		_reject_stitch(stitch, "stale carryover ledger")
		app.party_carryover._rest_ids.assign(ledger)
		var map: RunMap = app.run_map
		app.run_map = RunMap.new()
		_reject_stitch(stitch, "replaced map")
		app.run_map = map
		var foreign := OptionButton.new()
		_reject_stitch(app._stitch_at_rest.bind(app.rest_stitch, button, foreign, second), "foreign selector")
		foreign.free()
		var old_first: OptionButton = app.rest_stitch_first
		app.rest_stitch_first = second
		_reject_stitch(stitch, "replaced selector")
		app.rest_stitch_first = old_first
		first.set_item_metadata(first_index, second_index)
		_reject_stitch(stitch, "forged original-index list")
		first.set_item_metadata(first_index, first_index)
		# Validate the entire menu, including an unselected final occurrence.
		var last: int = first.item_count - 1
		var last_text: String = first.get_item_text(last)
		first.set_item_text(last, "forged unselected card")
		_reject_stitch(stitch, "forged unselected selector text")
		first.set_item_text(last, last_text)
		first.add_item("unknown card")
		first.set_item_metadata(first.item_count - 1, app.run_deck.size())
		_reject_stitch(stitch, "extra unknown selector record")
		first.remove_item(first.item_count - 1)
		for selector in [first, second]:
			var original: String = selector.get_item_text(selector.selected)
			selector.set_item_text(selector.selected, "forged card")
			_reject_stitch(stitch, "forged visible selector text")
			selector.set_item_text(selector.selected, original)
		var source: Dictionary = app._stitch_snapshot()
		var oracle := RunRestStitchCards.new(app.run_deck, app.run_stitch_descriptors, app.run_scraps, app.run_next_stitch_id)
		var expected := oracle.choose_stitch(first_index, second_index, source)
		_check(expected.ok, "independent service oracle succeeds")
		if session < 2:
			first.select(0)
			second.select(0)
			await _select_stitch(first, first_index, session == 1)
			await _select_stitch(second, second_index, session == 1)
			if session == 0:
				await _click(button)
			else:
				second.grab_focus()
				await _key(KEY_TAB)
				_check(button.has_focus(), "Tab reaches Stitch action")
				await _key(KEY_ENTER)
			_check(app.rest_stitch.is_consumed() and app._stitch_snapshot() == oracle.get_snapshot(), "exact oracle deck, ordered survivors, descriptor, cursor and three-scrap spend committed")
			_check(app.run_scraps == 0 and app.run_stitch_descriptors.size() == 1 and app.run_next_stitch_id == 2, "one durable stitched instance allocated")
			_check(not app.rest_continue_button.disabled and app.rest_heal_button.disabled and app.rest_upgrade_button.disabled, "exclusive Stitch enables Continue")
			_check_rest_hp_only()
			app._refresh_rest_hp()
			_check_rest_hp_only()
			_reject_stitch(stitch, "duplicate Stitch")
			_reject_stitch(heal, "Heal after Stitch")
			_reject_stitch(upgrade, "Upgrade after Stitch")
			var state := _stitch_state()
			if session == 0:
				replay = state.duplicate(true)
			else:
				_check(state == replay, "seeded mouse/keyboard replay matches full ledger and RNG")
			await _click(app.rest_continue_button)
			_check(app.route_view != null and not app.rest_view.visible, "Stitch Continue opens connected route")
			_reject_stitch(stitch, "post-Continue callback")
			retained = stitch
			await _click(app.route_back_button)
		elif session < 4:
			await _click(app.rest_heal_button if session == 2 else app.rest_upgrade_button)
			_check(not app.rest_continue_button.disabled, "competing Rest choice commits")
			_reject_stitch(stitch, "Stitch after Heal/Upgrade")
			_check(app.run_scraps == 3 and app.run_stitch_descriptors.is_empty(), "competing choice spends no scraps")
			await _click(app.rest_back_button)
		else:
			await _click(app.rest_back_button)
		var cleared: Array = [app.run_deck.duplicate(), app.run_scraps, app.run_stitch_descriptors.duplicate(true), app.run_next_stitch_id]
		stitch.call()
		_check(cleared == [[], 0, {}, 1] and cleared == [app.run_deck, app.run_scraps, app.run_stitch_descriptors, app.run_next_stitch_id] and app.rest_stitch == null, "Back/title clears purse and makes old callback inert")
		_check(randi() == global_next, "whole routed path preserves global RNG")
	await _finish_stitch()


func _finish_stitch() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_rest_stitch_choice_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
