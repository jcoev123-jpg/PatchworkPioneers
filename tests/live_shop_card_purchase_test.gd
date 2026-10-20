extends "res://tests/live_shop_route_entry_test.gd"
## Real routed victory/reward/Shop, with only funded gold injected before entry.


func _purchase_state() -> Array:
	return [_shop_state(), app.shop_purchases.get_state(), app.shop_purchases.get_stock(), app.run_map.get_floors()]


func _offer_key(code: Key) -> void:
	_check(app.shop_offers.get_popup().visible, "stock popup is mounted and open")
	await _key(code)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _fixture()
	_check(not fixture.is_empty(), "real seeded Fight connects to Shop")
	if fixture.is_empty():
		await _finish_purchase()
		return
	var stale: Array[Callable] = []
	var replay: Array = []
	for session in range(4):
		seed(420042)
		var next_global := randi()
		seed(420042)
		if not await _routed_win(fixture, false):
			break
		await _click(app.reward_buttons[0])
		_check(app.fight_reward_claimed and is_instance_valid(app.continue_button), "real reward claimed before Continue")
		if not is_instance_valid(app.continue_button):
			break
		var before := _persistent()
		for callback in stale:
			callback.call()
		_check(_persistent() == before and app.shop_purchases == null, "old purchase callbacks cannot touch restarted Fight")
		await _click(app.continue_button)
		var route: Button
		for button in app.route_buttons:
			if app.run_map.get_node(button.get_meta("route_id")).type == "Shop":
				route = button
		_check(route != null, "connected Shop action exists")
		if route == null:
			break
		if session != 0:
			app.session_gold = 200
		await _click(route)
		_check(app.shop_purchases != null and app.shop_purchases.is_valid() and app.shop_visit != null,
			"real entry constructs valid purchases and removal ledger")
		if app.shop_purchases == null or app.shop_visit == null:
			break
		var visit: RunShopVisit = app.shop_visit
		var purchases: RunShopPurchases = app.shop_purchases
		var stock: Dictionary = purchases.get_stock()
		var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
		_check(stock.cards.size() == 5 and stock.trinkets.size() == 2 and app.shop_offers.item_count == 5,
			"authored five plus two stock reaches mounted Shop")
		for index in range(stock.cards.size()):
			var offer: Dictionary = stock.cards[index]
			_check(catalog.has_card(offer.id) and catalog.get_definition(offer.id).owner == offer.owner,
				"each listing is an existing playable card with correct owner")
			_check(offer.price == authored.cards[index].price and not offer.sold
				and app.shop_offers.get_item_text(index) == "%s | %d gold" % [offer.id, offer.price],
				"every quoted price matches authored unsold stock")
		for control in [app.shop_view, app.shop_offers, app.shop_buy_button, app.shop_cards, app.shop_remove_button, app.shop_back_button]:
			_check(control.is_visible_in_tree() and Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()),
				"complete buying and removal UI fits viewport")
		var buy: Callable = app.shop_buy_button.pressed.get_connections()[0].callable
		before = _purchase_state()
		for callback in stale:
			callback.call()
		_check(_purchase_state() == before and app.shop_view.visible, "old callbacks cannot buy or close newly mounted Shop")
		if session == 0:
			_check(app.session_gold < stock.cards[0].price and app.shop_buy_button.disabled, "natural victory cannot afford listing")
			buy.call()
			await _click(app.shop_buy_button)
			app.shop_buy_button.grab_focus()
			await _key(KEY_ENTER)
			_check(_purchase_state() == before, "unaffordable callback, mouse and keyboard spend nothing")
		else:
			# Every rejection uses a funded, otherwise valid live visit.
			var live_map: RunMap = app.run_map
			var other := RunMap.new()
			var rng := RandomNumberGenerator.new()
			rng.seed = fixture.seed
			other.generate(rng)
			_check(other.choose_node(fixture.fight) and other.choose_node(visit.get_state().shop_node_id), "replacement map has same route")
			app.run_map = other
			var wrong := _purchase_state()
			buy.call()
			_check(_purchase_state() == wrong, "same-route wrong map rejects")
			app.run_map = live_map
			var node_id: String = live_map.get_current_node_id()
			live_map._nodes[node_id].type = "Rest"
			wrong = _purchase_state()
			buy.call()
			_check(_purchase_state() == wrong, "wrong node type rejects")
			live_map._nodes[node_id].type = "Shop"
			var live_route: Array[String] = live_map.get_route()
			live_map._route.pop_back()
			wrong = _purchase_state()
			buy.call()
			_check(_purchase_state() == wrong, "changed route rejects before buying")
			live_map._route.assign(live_route)
			app._buy_at_shop(RunShopVisit.new(app.run_deck, 200, 0), purchases, app.shop_buy_button)
			app._buy_at_shop(visit, purchases, app.shop_back_button)
			app._buy_at_shop(visit, RunShopPurchases.new([], [], [], 200, [], []), app.shop_buy_button)
			_check(_purchase_state() == before, "wrong visit, service and button identities reject")
			for invalid in ["unknown", stock.cards[1].id]:
				app.shop_offers.set_item_metadata(0, invalid)
				buy.call()
				_check(_purchase_state() == before, "unknown or mismatched offer metadata rejects")
			app.shop_offers.set_item_metadata(0, stock.cards[0].id)
			app.shop_offers.select(-1)
			buy.call()
			_check(_purchase_state() == before, "missing selected offer rejects")
			app.shop_offers.select(0)
			app.shop_offers.set_item_text(0, "tampered quote")
			buy.call()
			_check(_purchase_state() == before, "mismatched displayed quote rejects")
			app._refresh_shop()
			app.shop_view.hide()
			buy.call()
			app.shop_view.show()
			app.shop_buy_button.disabled = true
			buy.call()
			app.shop_buy_button.disabled = false
			_check(_purchase_state() == before, "hidden and disabled controls reject")
			app.session_gold += 1
			wrong = _purchase_state()
			buy.call()
			_check(_purchase_state() == wrong, "desynchronized gold rejects without publishing")
			app.session_gold -= 1
			app.run_removal_count += 1
			wrong = _purchase_state()
			buy.call()
			_check(_purchase_state() == wrong, "desynchronized removal count rejects")
			app.run_removal_count -= 1
			app.run_deck.append("warden_strike")
			wrong = _purchase_state()
			buy.call()
			_check(_purchase_state() == wrong, "desynchronized deck rejects")
			app.run_deck.pop_back()
			# Select a non-first listing through the actual popup.
			if session == 2:
				app.shop_offers.grab_focus()
				await _key(KEY_SPACE)
				await _offer_key(KEY_HOME)
				await _offer_key(KEY_DOWN)
				await _offer_key(KEY_ENTER)
			else:
				await _click(app.shop_offers)
				var popup: PopupMenu = app.shop_offers.get_popup()
				_check(popup.visible, "mouse opens real stock popup")
				var point := Vector2(popup.position) + Vector2(popup.size.x * 0.5, popup.size.y * 0.3)
				var motion := InputEventMouseMotion.new()
				motion.position = point
				root.push_input(motion, true)
				await _frames()
				for pressed in [true, false]:
					var event := InputEventMouseButton.new()
					event.position = point
					event.button_index = MOUSE_BUTTON_LEFT
					event.pressed = pressed
					root.push_input(event, true)
				await _frames()
			_check(app.shop_offers.selected == 1, "focused popup selects second listing")
			var offer: Dictionary = stock.cards[1]
			var expected_deck: Array = app.run_deck.duplicate()
			expected_deck.append(offer.id)
			var ledger: Dictionary = visit.get_state()
			if session == 2:
				app.shop_offers.grab_focus()
				await _key(KEY_TAB)
				_check(app.shop_buy_button.has_focus(), "Tab reaches Buy from stock selector")
				await _key(KEY_ENTER)
			else:
				await _click(app.shop_buy_button)
			_check(app.run_deck == expected_deck and app.session_gold == 200 - offer.price,
				"funded Buy appends exactly selected card and charges exact price")
			var expected_stock := stock.duplicate(true)
			expected_stock.cards[1].sold = true
			_check(purchases.get_stock() == expected_stock and purchases.get_state().deck == expected_deck
				and purchases.get_state().gold == app.session_gold, "only selected listing sold and service snapshot published")
			ledger.deck = expected_deck.duplicate()
			ledger.gold = app.session_gold
			_check(visit.get_state() == ledger and app.run_removal_count == 0 and visit.quote() == 75
				and not app.shop_remove_button.disabled, "same visit preserves node/history/count/quote and can remove after Buy")
			var after := _purchase_state()
			buy.call()
			app.shop_buy_button.disabled = false
			buy.call()
			app._refresh_shop()
			await _click(app.shop_buy_button)
			_check(_purchase_state() == after, "sold/repeated forced callback and mouse cannot charge twice")
			_check(after[0][0][0] == before[0][0][0] and after[0][0][3] == before[0][0][3]
				and after[0][0][4] == before[0][0][4], "buy preserves heroes, RNG and route")
			if session == 1:
				replay = after.duplicate(true)
			elif session == 3:
				_check(after == replay, "same seed restart replays full purchase state and RNG")
			var removed: String = app.run_deck[0]
			expected_deck.erase(removed)
			await _click(app.shop_remove_button)
			_check(app.run_deck == expected_deck and app.session_gold == 200 - offer.price - 75
				and app.run_removal_count == 1 and visit.get_state().status == "used", "Buy then Remove charges unchanged quote and retains bought card")
			_check(app.shop_buy_button.disabled and app.shop_offers.disabled, "removal disables buying")
			after = _purchase_state()
			app.shop_buy_button.disabled = false
			app.shop_offers.disabled = false
			app.shop_offers.select(2)
			buy.call()
			_check(_purchase_state() == after, "post-removal unsold listing cannot publish stale purchase snapshot")
		stale = [buy, app.shop_back_button.pressed.get_connections()[0].callable]
		await _click(app.shop_back_button)
		for callback in stale:
			callback.call()
		_check(visit.get_state().status == "closed" and app.title_view.visible and app.shop_visit == null
			and app.shop_purchases == null and app.shop_offers == null and app.shop_buy_button == null
			and app.run_map == null and app.run_deck.is_empty() and app.session_gold == 0 and app.run_removal_count == 0,
			"Return clears purchase controls/service and stale callbacks cannot restore run")
		_check(randi() == next_global, "routed buy/removal/restart does not consume global RNG")
	await _finish_purchase()


func _finish_purchase() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_shop_card_purchase_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
