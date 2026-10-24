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
		var oracle := _stock_oracle()
		await _click(route)
		_check(app.shop_purchases != null and app.shop_purchases.is_valid() and app.shop_visit != null,
			"real entry constructs valid purchases and removal ledger")
		if app.shop_purchases == null or app.shop_visit == null:
			break
		var visit: RunShopVisit = app.shop_visit
		var purchases: RunShopPurchases = app.shop_purchases
		var stock: Dictionary = purchases.get_stock()
		var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
		_check(stock == oracle.stock and app.run_rng.state == oracle.state,
			"physical entry matches exact pre-entry seeded generator order and seven-draw state")
		var prices := {}
		for candidate in authored.cards:
			prices[candidate.id] = int(candidate.price)
		var seen := {}
		_check(stock.cards.size() == 5 and stock.trinkets.size() == 2 and app.shop_offers.item_count == 5,
			"authored five plus two stock reaches mounted Shop")
		for index in range(stock.cards.size()):
			var offer: Dictionary = stock.cards[index]
			var definition: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(offer.id)
			var is_base: bool = catalog.has_card(offer.id) or WardenPoolCards.new().get_base_ids().has(offer.id) \
				or SeamstressPoolCards.new().get_base_ids().has(offer.id) \
				or TinkerPoolCards.new().get_pool_card_ids().has(offer.id)
			_check(is_base and not definition.is_empty() and definition.get("owner") == offer.owner \
				and not String(offer.id).ends_with("_plus") and app.run_heroes.any(func(hero): return hero.id == offer.owner),
				"each listing is an authored party-owned playable base card, never a pool upgrade")
			_check(not seen.has(offer.id), "generated card offers are distinct")
			seen[offer.id] = true
			_check(offer.price == prices.get(offer.id) and not offer.sold
				and app.shop_offers.get_item_metadata(index) == offer.id
				and app.shop_offers.get_item_text(index) == "%s | %d gold" % [definition.display_name, offer.price],
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
			before = _purchase_state()
			await _click_tile(_tile_for("offer", 2))
			_check(_purchase_state() == before and app.shop_buy_button.disabled,
				"unaffordable offer tile selects without spending and leaves Buy blocked")
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
			# Select a non-first listing through its real sewn offer tile.
			var listing_tile = _tile_for("offer", 1)
			before = _purchase_state()
			if session == 2:
				await _select_tile_by_key(listing_tile)
			else:
				await _click_tile(listing_tile)
			_check(app.shop_offers.selected == 1, "sewn offer tile selects the second listing")
			_check(_purchase_state() == before, "tile selection alone cannot buy or alter stock")
			var offer: Dictionary = stock.cards[1]
			var expected_deck: Array = app.run_deck.duplicate()
			expected_deck.append(offer.id)
			var ledger: Dictionary = visit.get_state()
			if session == 2:
				listing_tile.grab_focus()
				for step in range(4):
					if app.shop_buy_button.has_focus():
						break
					await _key(KEY_TAB)
				_check(app.shop_buy_button.has_focus(), "Tab reaches Buy from the stock tiles")
				await _key(KEY_ENTER)
			else:
				await _click(app.shop_buy_button)
			_check(app.run_deck == expected_deck and app.session_gold == 200 - offer.price,
				"funded Buy appends exactly selected card and charges exact price")
			_check(app.shop_offers.selected == 1 and app.shop_offers.get_item_metadata(1) == offer.id
				and app.shop_offers.get_item_text(1) == "%s | %d gold | SOLD" % [
					RunPoolCardRewardOffers.resolve_reward_definition(offer.id).display_name, offer.price]
				and app.shop_cards.get_item_metadata(expected_deck.size() - 1) == offer.id
				and app.shop_cards.get_item_text(expected_deck.size() - 1) == "Deck #%d: %s" % [
					expected_deck.size(), RunPoolCardRewardOffers.resolve_reward_definition(offer.id).display_name],
				"paid purchase retains offer selection, publishes SOLD and appends named owned row with exact metadata")
			var expected_stock := stock.duplicate(true)
			expected_stock.cards[1].sold = true
			_check(purchases.get_stock() == expected_stock and purchases.get_state().deck == expected_deck
				and purchases.get_state().gold == app.session_gold, "only selected listing sold and service snapshot published")
			ledger.deck = expected_deck.duplicate()
			ledger.gold = app.session_gold
			_check(visit.get_state() == ledger and app.run_removal_count == 0 and visit.quote() == 75
				and not app.shop_remove_button.disabled, "same visit preserves node/history/count/quote and can remove after Buy")
			await _frames()
			var sold_tile = _tile_for("offer", 1)
			var sold_details: Dictionary = _visit_tiles().tile_details(sold_tile)
			_check(sold_details.meta.begins_with("SOLD") and sold_details.selected,
				"bought listing keeps one sewn tile, marked SOLD and visibly selected")
			before = _purchase_state()
			await _click_tile(sold_tile)
			_check(_purchase_state() == before and app.shop_buy_button.disabled,
				"re-selecting the sold tile cannot buy or charge again")
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
			_check(app.shop_buy_button.disabled and not app.shop_offers.disabled, "sold selection stays disabled while post-removal stock remains reachable")
			app.shop_buy_button.disabled = false
			app.shop_offers.disabled = false
			app.shop_offers.select(2)
			# Deliberately stale service state must still reject after legal removal.
			purchases._state.gold += 1
			after = _purchase_state()
			buy.call()
			_check(_purchase_state() == after, "post-removal unsold listing cannot publish stale purchase snapshot")
			purchases._state.gold -= 1
		stale = [buy, app.shop_back_button.pressed.get_connections()[0].callable]
		await _click(app.shop_back_button)
		for callback in stale:
			callback.call()
		_check(visit.get_state().status == "closed" and app.title_view.visible and app.shop_visit == null
			and app.shop_purchases == null and app.shop_offers == null and app.shop_buy_button == null
			and app.run_map == null and app.run_deck.is_empty() and app.session_gold == 0 and app.run_removal_count == 0,
			"Return clears purchase controls/service and stale callbacks cannot restore run")
		_check(randi() == next_global, "routed buy/removal/restart does not consume global RNG")
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
		if app.shop_purchases == null or app.shop_visit == null:
			_check(false, "pool fixture mounts both real Shop ledgers")
			break
		var listed: Dictionary = app.shop_purchases.get_stock()
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
			_check(position < app.shop_offers.item_count and not paid.sold and paid.price <= app.session_gold,
				"found actual visible, unsold, affordable base pool offer: " + paid.id)
			_check(not catalog.has_card(paid.id) and not paid.id.ends_with("_plus")
				and (eligible.has(paid.id) if target == "warden" else
					SeamstressPoolCards.new().get_base_ids().has(paid.id)),
				"selected Warden/Thread Whip is an authored nonstarter pool base card")
			var before: Array = _purchase_state()
			var prior_scraps: int = app.run_scraps
			var prior_trinkets: Array = app.run_trinkets.duplicate(true)
			var prior_removals: int = app.run_removal_count
			var original_deck: Array = app.run_deck.duplicate(true)
			var selected_stock: Dictionary = listed.duplicate(true)
			var pool_tile = _tile_for("offer", position)
			before = _purchase_state()
			if target == "warden":
				await _click_tile(pool_tile)
			else:
				await _select_tile_by_key(pool_tile)
			_check(_purchase_state() == before, "pool tile selection alone spends nothing")
			_check(not app.shop_buy_button.disabled and app.shop_offers.get_item_text(position) ==
				"%s | %d gold" % [RunPoolCardRewardOffers.resolve_reward_definition(paid.id).display_name, paid.price]
				and app.shop_offers.get_item_metadata(position) == paid.id, "real offer selection enables precisely quoted Buy")
			if target == "warden":
				await _click(app.shop_buy_button)
			else:
				pool_tile.grab_focus()
				for step in range(_visit_tiles().offer_tiles().size() + 2):
					if app.shop_buy_button.has_focus():
						break
					await _key(KEY_TAB)
				_check(app.shop_buy_button.has_focus(), "Thread Whip Buy is keyboard reachable")
				await _key(KEY_ENTER)
			var expected_deck: Array = original_deck + [paid.id]
			selected_stock.cards[position].sold = true
			_check(app.run_deck == expected_deck and app.session_gold == 400 - paid.price
				and app.shop_purchases.get_state().deck == expected_deck
				and app.shop_visit.get_state().deck == expected_deck,
				"physical Warden/Thread Whip Buy debits authored price and appends exact shared base ID")
			_check(app.shop_purchases.get_stock() == selected_stock
				and app.shop_visit.get_state().gold == app.session_gold
				and app.shop_purchases.get_state().gold == app.session_gold
				and app.run_rng.state == before[0][0][3]
				and app.run_heroes == before[0][0][0]
				and app.run_map.get_route() == before[0][0][4]
				and app.run_scraps == prior_scraps and app.run_trinkets == prior_trinkets
				and app.run_removal_count == prior_removals,
				"paid Shop preserves heroes, route, scraps, trinkets, removal count and RNG; only sold listing changes")
			var after: Array = _purchase_state()
			app.shop_buy_button.pressed.emit()
			_check(_purchase_state() == after, "sold pool listing rejects repeated callback atomically")
			app.shop_offers.select(-1)
			app.shop_buy_button.disabled = false
			app.shop_buy_button.pressed.emit()
			_check(_purchase_state() == after, "invalid pool selection cannot charge or alter ledgers")
			_check(app.run_deck.count(paid.id) == original_deck.count(paid.id) + 1,
				"exactly one physical pool card appended, with no upgrade substitution")
		await _click(app.shop_back_button)
		_check(app.title_view.visible and app.run_deck.is_empty() and app.shop_visit == null,
			"candidate route returns cleanly to title with no stale Shop service")
		if matched:
			break
		if attempted >= 60:
			break
	_check(matched, "bounded authentic seeded Shop routes can actually buy %s after %d qualifying routes" % [target, attempted])
