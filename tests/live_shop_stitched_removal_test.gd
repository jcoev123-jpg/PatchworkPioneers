extends "res://tests/live_stitched_next_fight_test.gd"
## Earn a cross-owner stitch at the real Rest, retire it through routed Shop
## controls, then admit the surviving ledger to a connected Rest and battle.

var fixture_gold := 500
var fixture_count := 0


func _prepare_shop_receipt(fixture: Dictionary, keyboard: bool, upgrade: bool = false) -> String:
	if not await _routed_win(fixture, false):
		return ""
	await _click(app.reward_buttons[3])
	await _click(app.continue_button)
	await _click(_route_action(fixture.elite.back()))
	if not await _win_earned_elite():
		return ""
	await _click(app.reward_buttons[3])
	_check(app.run_scraps == 3, "genuine Fight and Elite claims fund Rest stitch")
	# Inject only funding/history before Rest captures its completed-visit guards.
	app.session_gold = fixture_gold
	app.run_removal_count = fixture_count
	await _click(app.continue_button)
	await _click(_legacy_rest_control(_route_action(fixture.rest.back())))
	_check(app.rest_stitch != null and app.rest_stitch.is_valid() and not app.rest_stitch_button.disabled,
		"connected Rest offers genuine funded stitch")
	if app.rest_stitch == null or app.rest_stitch_button.disabled:
		return ""
	if upgrade:
		var index: int = app.run_deck.find("warden_strike")
		var row := -1
		for item in range(app.rest_upgrade_cards.item_count):
			if app.rest_upgrade_cards.get_item_metadata(item) == index:
				row = item
		_check(index >= 0 and row >= 0 and not app.rest_upgrade_button.disabled,
			"real Rest offers the owned starter upgrade")
		if row < 0:
			return ""
		app.rest_upgrade_cards.select(row)
		await _click(app.rest_upgrade_button)
		_check(app.run_deck[index] == "warden_strike_plus" and app.rest_upgrade.is_consumed(),
			"real Rest commits authored plus card")
		await _click(app.rest_continue_button)
		return "warden_strike_plus"
	var source: Dictionary = app._stitch_snapshot()
	var first: int = app.run_deck.find("seamstress_prick")
	var second: int = app.run_deck.find("tinker_pop_shot")
	_check(first >= 0 and second >= 0, "cross-owner original cards are owned")
	if first < 0 or second < 0:
		return ""
	var oracle := RunRestStitchCards.new(source.deck, source.descriptors, source.remaining_scraps, source.next_stitch_id)
	var made := oracle.choose_stitch(first, second, source)
	_check(made.ok, "canonical Rest service issues authentic cross-owner receipt")
	await _select_stitch(app.rest_stitch_first, first, keyboard)
	await _select_stitch(app.rest_stitch_second, second, keyboard)
	if keyboard:
		app.rest_stitch_button.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(app.rest_stitch_button)
	_check(app.rest_stitch.is_consumed() and app._stitch_snapshot() == oracle.get_snapshot(),
		"real Rest controls commit the exact canonical receipt")
	await _click(app.rest_continue_button)
	return made.stitched_id if app.rest_stitch.is_consumed() else ""


func _shop_fixture() -> Dictionary:
	for value in [218053] + range(1, 500001):
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
					for shop in map.get_node(rest).outgoing:
						if map.get_node(shop).type != "Unpicker":
							continue
						for later in map.get_node(shop).outgoing:
							if map.get_node(later).type != "Rest":
								continue
							for battle in map.get_node(later).outgoing:
								if map.get_node(battle).type != "Fight":
									continue
								map.choose_node(fight)
								var entry := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
								if entry.get("encounter_id") == "starter_attacks":
									return {"seed": value, "fight": fight, "elite": [elite], "rest": [rest],
										"shop": shop, "later": later, "battle": battle}
								map.undo_choice(fight, [])
	return {}


func _ledger_state() -> Array:
	return [_admission_state(), app.session_gold, app.run_removal_count,
		app.run_trinkets.duplicate(),
		app.shop_visit.get_state() if app.shop_visit != null else {},
		app.shop_purchases.get_state() if app.shop_purchases != null else {},
		app.shop_purchases.get_stock() if app.shop_purchases != null else {}]


func _reject_shop(callbacks: Array[Callable], reason: String) -> void:
	var before := _ledger_state()
	for callback in callbacks:
		callback.call()
	_check(_ledger_state() == before, reason + " preserves deck, descriptors, cursor, wallet, count, route and RNG")


func _select_shop_row(group: String, row: int, keyboard: bool) -> void:
	await _frames()
	var gallery = app.get_node("LiveVisitCardTiles")
	var tiles: Array = gallery.removal_tiles() if group == "removal" else gallery.offer_tiles()
	var selected: Button
	for tile in tiles:
		if gallery.tile_row(tile) == row:
			selected = tile
	_check(selected != null, "actual mounted " + group + " row exists")
	if selected == null:
		return
	gallery.gallery_scroll().ensure_control_visible(selected)
	await _frames()
	if keyboard:
		selected.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(selected)
	_check((app.shop_cards.selected if group == "removal" else app.shop_offers.selected) == row,
		"physical input selects exact backing row")


func _buy_stitch_shop(row: int, keyboard: bool) -> void:
	var stock: Dictionary = app.shop_purchases.get_stock()
	var offer: Dictionary = stock.cards[row]
	var deck_before: Array = app.run_deck.duplicate()
	var gold_before: int = app.session_gold
	var registry: Dictionary = app.run_stitch_descriptors.duplicate(true)
	var cursor: int = app.run_next_stitch_id
	_check(not offer.sold and gold_before >= offer.price, "purchase is unsold and funded")
	await _select_shop_row("offer", row, keyboard)
	if keyboard:
		app.shop_buy_button.grab_focus()
		await _key(KEY_SPACE)
	else:
		await _click(app.shop_buy_button)
	stock.cards[row].sold = true
	_check(app.run_deck == deck_before + [offer.id] and app.session_gold == gold_before - offer.price
		and app.shop_purchases.get_stock() == stock and app.run_stitch_descriptors == registry
		and app.run_next_stitch_id == cursor and app._current_shop_ledger(),
		"purchase preserves stitch ownership and cursor while publishing exact paid card and sold marker")
	_reject_shop([app.shop_buy_button.pressed.get_connections()[0].callable], "sold purchase replay")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _shop_fixture()
	_check(not fixture.is_empty(), "seeded Fight-Elite-Rest-Unpicker-Rest-Fight exists")
	var stale: Array[Callable] = []
	var replay: Array = []
	for session in range(5):
		var keyboard := session == 1
		var poor := session == 2
		var upgrade := session == 4
		fixture_gold = 74 if poor else 500
		fixture_count = 2 if keyboard else 0
		if fixture.is_empty():
			break
		var earned := await _prepare_shop_receipt(fixture, keyboard, upgrade)
		_check(not earned.is_empty() and app.run_deck.has(earned), "genuine Rest earns stitched or upgraded removal target")
		if earned.is_empty():
			break
		var entry: Button = _route_action(fixture.shop)
		var enter: Callable = entry.pressed.get_connections()[0].callable
		var descriptors: Dictionary = app.run_stitch_descriptors.duplicate(true)
		if not upgrade:
			app.run_stitch_descriptors[earned].cost += 1
			var before: Dictionary = app._sewing_context()
			enter.call()
			_check(app._sewing_context() == before and app.unpicker_visit == null, "forged stitch descriptor refuses real Unpicker entry")
			app.run_stitch_descriptors = descriptors.duplicate(true)
		await _click(entry)
		_check(app.unpicker_visit != null and app.unpicker_view.is_visible_in_tree(), "whole-card removal now mounts real Unpicker")
		if app.unpicker_visit == null:
			break
		var view: LiveUnpickerPanel = app.unpicker_view
		var callbacks: Array[Callable] = []
		callbacks.append(view.remove_button.pressed.get_connections()[0].callable)
		callbacks.append(view.leave_button.pressed.get_connections()[0].callable)
		var state: Dictionary = app._sewing_context()
		for old in stale:
			old.call()
		_check(app._sewing_context() == state, "previous-run callbacks cannot alter fresh Unpicker")
		var target := "warden_strike" if keyboard else earned
		var selected: Button
		for row in view.card_buttons:
			if view._rows[row].get("id") == target:
				selected = row
		_check(selected != null and app.run_deck.has(target), "actual owned target has a canonical whole-card row")
		if selected == null:
			break
		view.choice_scroll.ensure_control_visible(selected)
		await _frames()
		if keyboard:
			selected.grab_focus()
			await _key(KEY_ENTER)
		else:
			await _click(selected)
		_check(view._selected_id == target and app._sewing_context() == state, "selection alone cannot remove or debit")
		var held := _held_unpicker_remove(view)
		app.session_gold += 1
		_reject_unpicker(held, "drifted gold")
		app.session_gold -= 1
		app.run_removal_count += 1
		_reject_unpicker(held, "drifted removal history")
		app.run_removal_count -= 1
		app.run_next_stitch_id += 1
		_reject_unpicker(held, "drifted stitch cursor")
		app.run_next_stitch_id -= 1
		if not upgrade:
			app.run_stitch_descriptors[earned].cost += 1
			_reject_unpicker(held, "forged live composite descriptor")
			app.run_stitch_descriptors = descriptors.duplicate(true)
			app.run_stitch_descriptors.erase(earned)
			_reject_unpicker(held, "missing live composite descriptor")
			app.run_stitch_descriptors = descriptors.duplicate(true)
		app.run_deck.append("warden_strike")
		_reject_unpicker(held, "drifted ordered deck")
		app.run_deck.pop_back()
		_check(app._sewing_context() == state, "negative Unpicker fixtures restore authentic stitched ledger")
		var text := selected.text
		selected.text = "forged card"
		callbacks[0].call()
		_check(app._sewing_context() == state, "forged row refuses removal")
		selected.text = text
		var expected: Array = app.run_deck.duplicate()
		expected.erase(target)
		var registry: Dictionary = descriptors.duplicate(true)
		registry.erase(target)
		var price: int = 75 + 25 * app.run_removal_count
		if keyboard:
			view.remove_button.grab_focus()
			await _key(KEY_ENTER)
		else:
			await _click(view.remove_button)
		if poor:
			_check(app._sewing_context() == state and not app._unpicker_closed, "short wallet preserves entire composite, cursor, wallet, RNG and removal history")
			callbacks[0].call()
			_check(app._sewing_context() == state, "shortfall retained callback cannot spend")
			await _click(view.leave_button)
		else:
			_check(app.run_deck == expected and app.run_stitch_descriptors == registry and app.run_next_stitch_id == state.cursor
				and app.session_gold == state.gold - price and app.run_removal_count == state.removals + 1
				and app.run_rng.state == state.rng_state and app.run_trinkets == state.patches,
				"whole-card Unpicker atomically retires first exact owned ID and descriptor with escalating canonical debit")
			var after: Dictionary = app._sewing_context()
			for callback in callbacks:
				callback.call()
			_check(app._sewing_context() == after and app._can_choose_connected_route(), "spent removal cannot replay and surviving stitched ledger admits route")
			var observation := [app._stitch_snapshot(), app.session_gold, app.run_removal_count, app.run_rng.state, app.run_map.get_route()]
			if session == 0:
				replay = observation
			elif session == 3:
				_check(observation == replay, "same seeded Rest-Unpicker timeline replays complete surviving ledger")
		var source: Dictionary = app._unpicker_source
		stale.assign([view.decision_requested.get_connections()[0].callable.bind({
			"action": "remove_card", "visit_id": source.visit_id, "node_id": source.node_id,
			"expected_snapshot": source.duplicate(true), "selected_card_id": target})])
		await _click(_legacy_rest_control(_route_action(fixture.later)))
		_check(app.rest_stitch != null and app.rest_stitch.is_valid() and app.rest_stitch.get_snapshot() == app._stitch_snapshot(), "later Rest accepts surviving authenticated ledger")
		await _click(app.rest_heal_button)
		await _click(app.rest_continue_button)
		await _click(_route_action(fixture.battle))
		_check(app.run_map.get_current_node_id() == fixture.battle and app.deck != null and app.deck.hand.size() == 5,
			"real onward Fight admits surviving deck and stitch descriptors")
		state = app._sewing_context()
		for old in stale:
			old.call()
		_check(app._sewing_context() == state, "old removal controls cannot change later battle")
		await _click(app.return_button)
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_shop_stitched_removal_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _held_unpicker_remove(view: LiveUnpickerPanel) -> Callable:
	var source: Dictionary = app._unpicker_source
	var intent := {"action": "remove_card", "visit_id": source.visit_id, "node_id": source.node_id,
		"expected_snapshot": source.duplicate(true), "selected_card_id": view._selected_id}
	var listener: Callable = view.decision_requested.get_connections()[0].callable
	return func():
		var submitted := view._submitted
		view._submitted = true
		listener.call(intent)
		view._submitted = submitted


func _reject_unpicker(callback: Callable, reason: String) -> void:
	var before: Dictionary = app._sewing_context()
	var visit: Dictionary = app.unpicker_visit.read_state()
	callback.call()
	_check(app._sewing_context() == before and app.unpicker_visit.read_state() == visit and not app._unpicker_closed,
		reason + " refuses without changing run, visit, descriptors or RNG")
