extends "res://tests/live_shop_route_entry_test.gd"
## Real routed victory/reward/Shop, with only funded gold injected before entry.


func _purchase_state() -> Array:
	return [_shop_state(), app.shop_purchases.get_state(), app.shop_purchases.get_stock(), app.run_map.get_floors()]


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _fixture()
	_check(not fixture.is_empty(), "real Fight -> Peddler fixture exists")
	var replay: Array = []
	var stale: Array[Callable] = []
	for session in range(4):
		if fixture.is_empty() or not await _routed_win(fixture, false):
			break
		await _click(app.reward_buttons[3])
		await _click(app.continue_button)
		var entry: Button
		for button in app.route_buttons:
			if button.get_meta("route_kind") == "Shop":
				entry = button
		_check(entry != null, "authentic connected Peddler entry exists")
		if entry == null:
			break
		app.session_gold = 200
		var oracle := _stock_oracle()
		await _click(entry)
		_check(app.peddler_visit != null and app.peddler_buttons.size() == 4, "real service and four choices mounted")
		if app.peddler_visit == null:
			break
		var visit: RunPeddlerVisit = app.peddler_visit
		var bound := visit.read_state()
		_check(bound.stock == oracle.stock and app.run_rng.state == oracle.state, "independent stock and RNG oracle matches")
		var unchanged := _shop_state()
		for callback in stale:
			callback.call()
		_check(_shop_state() == unchanged, "old-generation callbacks cannot buy from fresh visit")
		var callbacks: Array[Callable] = []
		for action in app.peddler_buttons + [app.peddler_leave_button]:
			callbacks.append(action.pressed.get_connections()[0].callable)
		await _peddler_rejections(callbacks)
		var index := 1
		var offer: Dictionary = bound.stock.cards[index]
		var before: Dictionary = app._sewing_context()
		var expected: Array = app.run_deck.duplicate() + [offer.id]
		if session == 2:
			app.peddler_buttons[index].grab_focus()
			await _key(KEY_ENTER)
		else:
			await _click(app.peddler_buttons[index])
		var receipt: Dictionary = app.peddler_receipt
		var stock: Dictionary = bound.stock.duplicate(true)
		stock.cards[index].sold = true
		_check(receipt == {"ok": true, "node_id": bound.node_id, "decision": "buy", "kind": "card",
			"id": offer.id, "price": offer.price, "stock": stock,
			"state": {"party_ids": bound.state.party_ids, "deck": expected,
				"trinkets": before.patches, "gold": 200 - offer.price}}, "one exact authoritative paid card receipt published")
		_check(app.run_deck == expected and app.session_gold == 200 - offer.price
			and app.run_trinkets == before.patches and app.run_scraps == before.scraps
			and app.run_removal_count == before.removals and app.run_stitch_descriptors == before.descriptors
			and app.run_heroes == before.heroes and app.run_rng.state == before.rng_state,
			"card buy changes only exact deck append and quoted wallet debit")
		_check(app.shop_view == null and visit.is_consumed() and app._can_choose_connected_route(), "purchase immediately closes Peddler and admits onward route")
		var after := _shop_state()
		for callback in callbacks:
			callback.call()
		_check(_shop_state() == after, "all retained choices and Leave refuse after one paid choice")
		_check(not visit.choose_purchase(bound.node_id, bound.state, bound.stock, "card", offer.id).ok
			and not visit.leave(bound.node_id, bound.state, bound.stock).ok, "direct stale service requests also refuse")
		var observation := [visit.read_state(), receipt.duplicate(true), app.run_rng.state, app.run_heroes.duplicate(true)]
		if session == 0:
			replay = observation
		else:
			_check(observation == replay, "mouse, keyboard and restart replay exact paid receipt and state")
		stale = callbacks
		await _click(app.route_back_button)
		for callback in stale:
			callback.call()
		_check(app.title_view.visible and app.peddler_visit == null and app.peddler_receipt.is_empty()
			and app.run_map == null and app.run_deck.is_empty(), "title reset rejects retained paid actions")
	await _test_stocked_pool_buy("warden")
	await _test_stocked_pool_buy("seamstress_thread_whip")
	await _finish_purchase()


func _finish_purchase() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_shop_card_purchase_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)

## Find qualifying routes by deterministic seed search, but always win the
## real mounted Fight and inspect the five genuinely displayed Shop offers.
## No candidate, stock, or post-fight RNG is injected by the fixture.
func _test_stocked_pool_buy(target: String) -> void:
	var eligible := WardenPoolCards.new().get_base_ids()
	var matched := false
	var attempted := 0
	for value in range(1, 6000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		var candidate: Dictionary = {}
		for fight_id in map.get_legal_choices():
			if map.get_node(fight_id).type != "Fight":
				continue
			var shop_id := ""
			for linked in map.get_node(fight_id).outgoing:
				if map.get_node(linked).type == "Shop":
					shop_id = linked
					break
			if shop_id.is_empty():
				continue
			var check_rng := RandomNumberGenerator.new()
			check_rng.seed = value
			var check_map := RunMap.new()
			check_map.generate(check_rng)
			if not check_map.choose_node(fight_id):
				continue
			var selection := RunAuthoredBattleEntry.new().entry_current_battle(check_map, check_rng, RunFightEncounterSelection.new())
			if selection.get("encounter_id") == "starter_attacks":
				candidate = {"seed": value, "fight": fight_id, "shop": shop_id}
				break
		if candidate.is_empty():
			continue
		attempted += 1
		if not await _routed_win(candidate, false):
			_check(false, "pool fixture must win legal routed starter battle")
			break
		await _click(app.reward_buttons[3])
		await _click(app.continue_button)
		var route: Button
		for button in app.route_buttons:
			if button.get_meta("route_id") == candidate.shop:
				route = button
		_check(route != null, "seeded pool route mounts its connected Shop action")
		if route == null:
			break
		app.session_gold = 400
		var oracle: Dictionary = _stock_oracle()
		await _click(route)
		if app.peddler_visit == null:
			_check(false, "pool fixture mounts both real Shop ledgers")
			break
		var listed: Dictionary = app.peddler_visit.read_state().stock
		_check(listed == oracle.stock and app.run_rng.state == oracle.state,
			"pool fixture's physical Shop exactly replays authentic RNG stock")
		var position := -1
		for index in range(listed.cards.size()):
			var card_id: String = listed.cards[index].id
			if (target == "warden" and eligible.has(card_id)) or card_id == target:
				position = index
				break
		if position >= 0:
			matched = true
			var paid: Dictionary = listed.cards[position]
			_check(position < 3 and not paid.sold and paid.price <= app.session_gold,
				"found actual visible, unsold, affordable base pool offer: " + paid.id)
			_check(not catalog.has_card(paid.id) and not paid.id.ends_with("_plus")
				and (eligible.has(paid.id) if target == "warden" else
					SeamstressPoolCards.new().get_base_ids().has(paid.id)),
				"selected Warden/Thread Whip is an authored nonstarter pool base card")
			var expected_deck: Array = app.run_deck.duplicate() + [paid.id]
			var before: Dictionary = app._sewing_context()
			var callback: Callable = app.peddler_buttons[position].pressed.get_connections()[0].callable
			if target == "warden":
				await _click(app.peddler_buttons[position])
			else:
				app.peddler_buttons[position].grab_focus()
				await _key(KEY_ENTER)
			_check(app.run_deck == expected_deck and app.session_gold == 400 - paid.price
				and app.peddler_receipt.id == paid.id and app.peddler_receipt.price == paid.price
				and app.run_rng.state == before.rng_state and app.run_heroes == before.heroes
				and app.run_scraps == before.scraps and app.run_trinkets == before.patches
				and app.run_removal_count == before.removals, "real pool Buy appends exact base ID once and preserves other ledgers")
			var after := _shop_state()
			callback.call()
			_check(_shop_state() == after, "retired pool choice cannot charge twice")
		if is_instance_valid(app.shop_view):
			await _click(app.peddler_leave_button)
		await _click(app.route_back_button)
		_check(app.title_view.visible and app.run_deck.is_empty() and app.peddler_visit == null, "pool fixture exits cleanly")

		if matched:
			break
		if attempted >= 60:
			break
	_check(matched, "bounded authentic seeded Shop routes can actually buy %s after %d qualifying routes" % [target, attempted])
