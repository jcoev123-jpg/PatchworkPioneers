extends "res://tests/live_shop_route_entry_test.gd"
## Real seeded Fight -> reward -> Shop -> connected noncombat visit.


func _continuation_fixture(kind: String, first_seed: int = 1, last_seed: int = 1000) -> Dictionary:
	for value in range(first_seed, last_seed):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		var opening_rng := rng.state
		for fight in map.get_legal_choices():
			if map.get_node(fight).type != "Fight":
				continue
			for shop in map.get_node(fight).outgoing:
				if map.get_node(shop).type != "Shop":
					continue
				for next in map.get_node(shop).outgoing:
					if map.get_node(next).type != kind:
						continue
					rng.state = opening_rng
					map.choose_node(fight)
					var selected := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
					if selected.get("encounter_id") == "starter_attacks":
						return {"seed": value, "fight": fight, "shop": shop, "next": next}
					map.undo_choice(fight, [])
	return {}


func _continuation_state() -> Array:
	return [_persistent(), app.run_removal_count,
		app.shop_visit.get_state() if app.shop_visit != null else {},
		app.shop_purchases.get_state() if app.shop_purchases != null else {},
		app.shop_purchases.get_stock() if app.shop_purchases != null else {}]


func _route_action(id: String) -> Button:
	for button in app.route_buttons:
		if button.get_meta("route_id") == id:
			return button
	_check(false, "required connected control exists: " + id)
	return null


func _check_connected_book() -> void:
	_check(app._can_choose_connected_route() and not app.run_map.get_route().is_empty(), "book has a genuine completed route context")
	var book: Control = app.route_book_backdrop
	_check(is_instance_valid(book) and book.is_visible_in_tree() and app.route_view.name == "ConnectedBookChoices"
		and not app.route_view is Container, "connected choices mount the existing book with independent sewn patches")
	if not is_instance_valid(book):
		return
	var floor_number: int = app.run_map.get_node(app.run_map.get_current_node_id()).floor
	_check(book.get_node("FloorCue").text == "Floor %02d" % floor_number
		and book.get_node("FloorCue").get_meta("floor_number") == floor_number
		and book.get_node("AreaCue").text == RunRouteAtlas.area_for_floor(floor_number), "book identifies the actual current floor and area")
	var slate := book.get_node("PartySlate")
	for index in range(app.run_heroes.size()):
		var hero: Dictionary = app.run_heroes[index]
		var row := slate.get_node("HeroRow" + str(index))
		_check(row.get_node("HeroName").text == hero.name
			and row.get_node("Health").text == "HP %d / %d" % [hero.hp, hero.max_hp], "left page reflects canonical carried hero")
	_check(slate.get_node("Resources").text == "Deck: %d cards\nGold: %d    Scraps: %d" % [app.run_deck.size(), app.session_gold, app.run_scraps], "left page reflects actual deck and wallets")
	var ids: Array = []
	var actions: Array[Control] = []
	for button in app.route_buttons:
		var id: String = button.get_meta("route_id")
		var kind: String = app.run_map.get_node(id).type
		ids.append(id)
		_check(button.get_parent() == app.route_view and button.get_meta("route_kind") == kind
			and button.text == app.route_kind_label(kind) and button.get_child_count() == 2, "friendly sewn node keeps exact legal identity and token/stitches")
		if not button.disabled:
			actions.append(button)
	_check(not ids.is_empty() and ids == app.run_map.get_legal_choices(), "book shows precisely the real legal choices")
	for button in app.map_mend_buttons:
		_check(button.get_parent() == app.route_view, "Mend remains a direct guarded chooser child")
		if not button.disabled:
			actions.append(button)
	actions.append(app.route_view.get_node("PatchSummaryScroll"))
	actions.append(app.route_map_button)
	actions.append(app.route_back_button)
	var before := _continuation_state()
	actions[0].grab_focus()
	for index in range(actions.size()):
		_check(actions[index].has_focus(), "physical Tab visits every connected action and patch summary")
		await _key(KEY_TAB)
	_check(actions[0].has_focus(), "connected keyboard order wraps to the first route")
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_TAB
		event.shift_pressed = true
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()
	_check(actions.back().has_focus(), "reverse Tab reaches title exit")
	_check(_continuation_state() == before, "focus traversal preserves route, ledgers and RNG")


func _bounds(view: Control) -> void:
	_check(view.is_visible_in_tree() and Rect2(0, 0, 1280, 720).encloses(view.get_global_rect()), "visit fits viewport")
	for control in view.get_children():
		if control is Control:
			_check(Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()), "every mounted visit control fits viewport")


func _paid_card(index: int, keyboard: bool) -> void:
	# Let the presenter rebuild its tiles for the post-removal stock/ledger.
	await _frames()
	var stock: Dictionary = app.shop_purchases.get_stock()
	var offer: Dictionary = stock.cards[index]
	var expected: Array = app.run_deck.duplicate()
	expected.append(offer.id)
	var gold: int = app.session_gold - offer.price
	var rng: int = app.run_rng.state
	_check(not offer.sold and gold >= 0, "post-removal purchase fixture is unsold and affordable")
	var listing_tile = _tile_for("offer", index)
	_check(listing_tile != null, "the paid listing owns one sewn offer tile")
	if listing_tile == null:
		return
	if keyboard:
		await _select_tile_by_key(listing_tile)
	else:
		await _click_tile(listing_tile)
	_check(app.shop_offers.selected == index, "real sewn tile selects the paid listing")
	_check(not app.shop_offers.disabled and not app.shop_buy_button.disabled, "valid visit keeps selected affordable stock enabled")
	if keyboard:
		listing_tile.grab_focus()
		for step in range(_visit_tiles().offer_tiles().size() + 2):
			if app.shop_buy_button.has_focus():
				break
			await _key(KEY_TAB)
		_check(app.shop_buy_button.has_focus(), "Tab reaches Buy from the offer tiles after removal")
		await _key(KEY_ENTER)
	else:
		await _click(app.shop_buy_button)
	stock.cards[index].sold = true
	_check(app.run_deck == expected and app.session_gold == gold and app.run_rng.state == rng and app.shop_purchases.get_stock() == stock, "live purchase charges exact price, appends one card and changes only selected sold marker without RNG")
	var ledger: Dictionary = app.shop_visit.get_state()
	var purchases: Dictionary = app.shop_purchases.get_state()
	_check(ledger.deck == expected and purchases.deck == expected and ledger.gold == gold and purchases.gold == gold and ledger.trinkets == purchases.trinkets, "live purchase and visit ledgers agree exactly")
	var before := _continuation_state()
	app.shop_buy_button.pressed.emit()
	_check(_continuation_state() == before, "sold live purchase cannot replay or spend again")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var stale: Array[Callable] = []
	for kind in ["Rest", "Shop"]:
		var fixture := _continuation_fixture(kind)
		_check(not fixture.is_empty(), "seeded graph supports Fight -> Shop -> " + kind)
		if fixture.is_empty():
			continue
		var replay: Array = []
		for session in range(2):
			seed(570057)
			var global_next := randi()
			seed(570057)
			if not await _routed_win(fixture, false):
				break
			var before := _continuation_state()
			for callback in stale:
				callback.call()
			app._continue_from_shop(null, weakref(app.run_map), app.run_map.get_route(), null)
			_check(_continuation_state() == before and app.route_view == null, "premature and previous-session callbacks leave active run untouched")
			await _click(app.reward_buttons[0 if kind == "Shop" else 3])
			await _click(app.continue_button)
			var entry := _route_action(fixture.shop)
			if entry == null:
				break
			# Funding is injected solely to exercise real purchase/removal transactions.
			app.session_gold = 400
			var first_oracle := _stock_oracle()
			await _click(entry)
			_check(app.shop_visit != null and is_instance_valid(app.shop_continue_button), "first Shop mounts ledger and Continue")
			if app.shop_visit == null or not is_instance_valid(app.shop_continue_button):
				break
			_check(app.shop_purchases.get_stock() == first_oracle.stock and app.run_rng.state == first_oracle.state,
				"first connected Shop matches pre-entry stock and RNG oracle")
			app.shop_purchases._state.gold += 1
			var desynchronized := _continuation_state()
			app.shop_remove_button.pressed.emit()
			_check(_continuation_state() == desynchronized, "removal rejects stale purchase ledger before committing visit or spending")
			app.shop_purchases._state.gold -= 1
			if kind == "Shop":
				var deck_before: Array = app.run_deck.duplicate()
				var gold_before: int = app.session_gold
				var offer: Dictionary = app.shop_purchases.get_stock().cards[0]
				await _click(app.shop_buy_button)
				_check(app.run_deck == deck_before + [offer.id] and app.session_gold == gold_before - offer.price, "real first Shop purchase commits exact card and cost")
				deck_before = app.run_deck.duplicate()
				deck_before.erase(app.run_deck[app.shop_cards.selected])
				gold_before = app.session_gold
				await _click(app.shop_remove_button)
				_check(app.run_deck == deck_before and app.session_gold == gold_before - 75 and app.run_removal_count == 1, "real first Shop removal commits exact cost, deck and rising count")
			else:
				var deck_before: Array = app.run_deck.duplicate()
				deck_before.erase(app.run_deck[app.shop_cards.selected])
				var gold_before: int = app.session_gold
				await _click(app.shop_remove_button)
				_check(app.run_deck == deck_before and app.session_gold == gold_before - 75 and app.run_removal_count == 1 and app.shop_visit.get_state().status == "used", "removal-first ordering charges exact gold and removes one card")
			var expected_stock: Dictionary = first_oracle.stock.duplicate(true)
			if kind == "Shop":
				expected_stock.cards[0].sold = true
			_check(app.shop_purchases.get_stock() == expected_stock and app.run_rng.state == first_oracle.state, "removal preserves every stock identity, price and sold flag without rolling RNG")
			_check(app.shop_back_button.has_focus(), "removal moves focus to visible Return")
			_check(app.shop_remove_button.disabled and app.shop_cards.disabled and not app.shop_offers.disabled, "removal stays disabled while stock remains reachable")
			var after_removal := _continuation_state()
			app.shop_remove_button.pressed.emit()
			_check(_continuation_state() == after_removal, "first Shop duplicate removal cannot spend again")
			var second_offer_index: int = _unsold_pool_offer_index(app.shop_purchases.get_stock())
			var first_paid_id: String = String(first_oracle.stock.cards[0].id) if kind == "Shop" else ""
			_check(second_offer_index >= 0 or _is_shop_base_pool(first_paid_id),
				"authentic continued Shop offers a purchasable authored pool base card")
			if second_offer_index < 0:
				second_offer_index = 1 if kind == "Shop" else 0
			var second_paid_id: String = String(app.shop_purchases.get_stock().cards[second_offer_index].id)
			await _paid_card(second_offer_index, session == 1)
			var persisted_pool_id: String = second_paid_id if _is_shop_base_pool(second_paid_id) else first_paid_id
			_check(_is_shop_base_pool(persisted_pool_id), "paid offer belongs to an eligible authored Shop pool base")
			var pool_count: int = app.run_deck.count(persisted_pool_id)
			_check(pool_count > 0 and app.shop_visit.get_state().deck == app.run_deck
				and app.shop_purchases.get_state().deck == app.run_deck,
				"paid pool card is in single shared deck and both authoritative Shop ledgers")
			_check(app.shop_remove_button.disabled and app.run_removal_count == 1, "post-removal buying never enables a second removal")
			var visit: RunShopVisit = app.shop_visit
			var live_map: RunMap = app.run_map
			var prior: Array[String] = live_map.get_route()
			var empty_route: Array[String] = []
			var button: Button = app.shop_continue_button
			var exit: Callable = button.pressed.get_connections()[0].callable
			var remove: Callable = app.shop_remove_button.pressed.get_connections()[0].callable
			var buy: Callable = app.shop_buy_button.pressed.get_connections()[0].callable
			var back: Callable = app.shop_back_button.pressed.get_connections()[0].callable
			before = _continuation_state()
			_bounds(app.shop_view)
			app._continue_from_shop(RunShopVisit.new(app.run_deck, app.session_gold, 0), weakref(live_map), prior, button)
			app._continue_from_shop(visit, weakref(RunMap.new()), prior, button)
			app._continue_from_shop(visit, weakref(live_map), empty_route, button)
			app._continue_from_shop(visit, weakref(live_map), prior, app.shop_back_button)
			button.disabled = true
			exit.call()
			button.disabled = false
			_check(_continuation_state() == before and app.route_view == null, "foreign visit/map/route/button and disabled Continue reject without closing ledger")
			var replacement := RunMap.new()
			var replacement_rng := RandomNumberGenerator.new()
			replacement_rng.seed = fixture.seed
			replacement.generate(replacement_rng)
			_check(replacement.choose_node(fixture.fight) and replacement.choose_node(fixture.shop), "replacement map has otherwise valid identical Shop route")
			app.run_map = replacement
			var invalid_before := _continuation_state()
			exit.call()
			_check(_continuation_state() == invalid_before and app.route_view == null, "replacement map identity rejects Continue")
			app.run_map = live_map
			live_map._nodes[fixture.shop].type = "Rest"
			invalid_before = _continuation_state()
			exit.call()
			_check(_continuation_state() == invalid_before and app.route_view == null, "changed current node type rejects Continue")
			live_map._nodes[fixture.shop].type = "Shop"
			live_map._route.append(fixture.next)
			invalid_before = _continuation_state()
			exit.call()
			_check(_continuation_state() == invalid_before and app.route_view == null, "advanced route snapshot rejects retained Continue")
			live_map._route.pop_back()
			for field in ["session_gold", "run_removal_count", "run_deck", "run_heroes"]:
				var saved: Variant = app.get(field)
				var invalid: Variant
				if field in ["session_gold", "run_removal_count"]:
					invalid = saved + 1
				else:
					invalid = saved.duplicate()
					invalid.clear()
				app.set(field, invalid)
				invalid_before = _continuation_state()
				exit.call()
				_check(_continuation_state() == invalid_before and app.route_view == null, "mismatched ledger/invalid roster rejects Continue: " + field)
				app.set(field, saved)
			var heroes: Array = app.run_heroes.duplicate(true)
			app.run_heroes = _defeated(heroes)
			invalid_before = _continuation_state()
			exit.call()
			_check(_continuation_state() == invalid_before and app.route_view == null, "defeated valid roster rejects Continue")
			app.run_heroes = heroes
			if session == 0:
				await _click(button)
			else:
				app.shop_back_button.grab_focus()
				await _key(KEY_TAB)
				_check(_visit_tiles().offer_tiles()[0].has_focus(),
					"Shop focus wraps from Return to the first offer tile")
				for step in range(64):
					if button.has_focus():
						break
					await _key(KEY_TAB)
				_check(button.has_focus(), "Tab navigation reaches Continue after removal and continued buying")
				await _key(KEY_SPACE)
			_check(app.route_view != null and not app.shop_view.visible and not app.title_view.visible, "physical Continue opens connected choices without returning or selecting")
			if app.route_view == null:
				break
			_check(visit.get_state().status == "closed" and _persistent() == before[0] and app.run_map == live_map, "Shop exit closes ledger while preserving exact run, actors, map and RNG")
			_check(app.run_deck.count(persisted_pool_id) == pool_count
				and visit.get_state().deck == app.run_deck and not persisted_pool_id.ends_with("_plus"),
				"real Continue retains purchased base ID in shared run deck and closed visit ledger")
			await _check_connected_book()
			_bounds(app.route_view)
			before = _continuation_state()
			for callback in [exit, remove, buy, back]:
				callback.call()
			var shown: Array[String] = []
			for action in app.route_buttons:
				var id: String = action.get_meta("route_id")
				var node_kind: String = live_map.get_node(id).type
				shown.append(id)
				_check(action.get_meta("route_kind") == node_kind and action.text == app.route_kind_label(node_kind) and action.disabled == (node_kind not in ["Rest", "Shop", "Event", "Treasure", "Fight", "Elite", "Boss"]), "exact adjacent ID/type with only supported kinds enabled")
				if action.disabled:
					await _click(action)
					action.pressed.emit()
			_check(shown == live_map.get_legal_choices() and _continuation_state() == before, "only actual adjacent nodes shown; duplicate exit and hidden shop controls inert")
			_check(root.gui_get_focus_owner() != null and root.gui_get_focus_owner().is_visible_in_tree(), "route has visible keyboard focus")
			var next := _route_action(fixture.next)
			if next == null:
				break
			var choose: Callable = next.pressed.get_connections()[0].callable
			var edges: Array = live_map._nodes[fixture.shop].outgoing.duplicate()
			live_map._nodes[fixture.shop].outgoing.erase(fixture.next)
			choose.call()
			_check(_continuation_state() == before, "disconnected following visit rejected before commit")
			live_map._nodes[fixture.shop].outgoing = edges
			var method := "_choose_shop_route" if kind == "Shop" else "_choose_rest_route"
			app.call(method, "f12_n0", weakref(live_map), prior, next)
			app.call(method, fixture.next, weakref(replacement), prior, next)
			app.call(method, fixture.next, weakref(live_map), empty_route, next)
			next.disabled = true
			choose.call()
			next.disabled = false
			_check(_continuation_state() == before, "forged ID/map/route and disabled following visit reject")
			var next_oracle := _stock_oracle() if kind == "Shop" else {}
			if session == 0:
				await _click(next)
			else:
				next.grab_focus()
				await _key(KEY_ENTER)
			_check(live_map.get_route() == prior + [fixture.next] and app.run_map == live_map, "following visit advances exactly one connected node on same map")
			_check(_persistent().slice(0, 3) == before[0].slice(0, 3) and app.run_removal_count == before[1], "entry carries exact heroes, deck, gold and removal count")
			_check(app.run_deck.count(persisted_pool_id) == pool_count
				and app.run_deck == before[0][1],
				"connected next visit retains exact bought base card with no substitution")
			if kind == "Shop":
				_check(app.shop_visit.get_state().deck == app.run_deck
					and app.shop_purchases.get_state().deck == app.run_deck,
					"fresh routed Shop ledgers carry purchased base card without a second deck")
			if kind == "Shop":
				_check(app.shop_purchases.get_stock() == next_oracle.stock and app.run_rng.state == next_oracle.state,
					"later Shop generates once from ongoing run RNG rather than reseeding")
			else:
				_check(app.run_rng.state == before[0][3], "Rest entry preserves RNG")
			before = _continuation_state()
			for callback in [exit, remove, buy, back, choose]:
				callback.call()
			_check(_continuation_state() == before, "old Shop and duplicate route controls cannot change later visit")
			if kind == "Shop":
				_check(app.shop_visit != visit and app.shop_visit.get_state().shop_node_id == fixture.next and app.shop_visit.quote() == 100, "later Shop owns fresh ledger and carried rising quote")
				_bounds(app.shop_view)
				var deck_before_buy: Array = app.run_deck.duplicate()
				var gold_before_buy: int = app.session_gold
				var later_offer: Dictionary = app.shop_purchases.get_stock().cards[0]
				await _click(app.shop_buy_button)
				_check(app.run_deck == deck_before_buy + [later_offer.id] and app.session_gold == gold_before_buy - later_offer.price and app.run_removal_count == 1, "later Shop purchase commits exact card/cost while retaining removal quote")
				var expected_deck: Array = app.run_deck.duplicate()
				expected_deck.erase(app.run_deck[app.shop_cards.selected])
				var gold: int = app.session_gold
				await _click(app.shop_remove_button)
				_check(app.run_deck == expected_deck and app.session_gold == gold - 100 and app.run_removal_count == 2, "later Shop removal works with carried quote beyond route length two")
				before = _continuation_state()
				app.shop_remove_button.pressed.emit()
				_check(_continuation_state() == before, "later Shop duplicate removal remains inert")
			else:
				_check(app.rest_recovery != null and not app.rest_recovery.is_consumed(), "later Rest mounts fresh unconsumed recovery")
				_bounds(app.rest_view)
				var expected_heal := RunRestRecovery.new(heroes).choose_heal()
				await _click(app.rest_heal_button)
				_check(app.run_heroes == expected_heal.heroes and app.rest_recovery.is_consumed(), "later Rest applies exact recovery once beyond route length two")
				_check(_persistent().slice(1) == before[0].slice(1), "later Rest preserves all nonhero state")
				before = _continuation_state()
				app.rest_heal_button.pressed.emit()
				_check(_continuation_state() == before, "later Rest duplicate heal inert")
			if session == 0:
				replay = _continuation_state()
			else:
				_check(_continuation_state() == replay, "seeded mouse/keyboard replay reproduces entire continued run and both shop services")
			stale = [exit, remove, buy, back, choose]
			await _click(app.shop_back_button if kind == "Shop" else app.rest_back_button)
			for callback in stale:
				callback.call()
			_check(app.title_view.visible and app.run_map == null and app.run_rng == null and app.run_deck.is_empty() and app.run_heroes.is_empty() and app.session_gold == 0 and app.run_removal_count == 0 and app.shop_visit == null, "Return after continued visit fully resets; stale controls inert")
			_check(randi() == global_next, "continued run spends no global RNG")
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_shop_continuation_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)

## A purchased base from the previously live Shop pool or the seven newly
## stocked Seamstress D2-1 bases witnesses real Shop-to-visit deck carryover.
## Keep this an explicit subset: an arbitrary starter card cannot satisfy it.
func _is_shop_base_pool(card_id: String) -> bool:
	return card_id in [
		"warden_hold_the_line", "warden_patch_guard", "warden_quick_darn",
		"warden_brass_buckle", "warden_iron_hem", "warden_bastion_quilt",
		"seamstress_thread_whip", "seamstress_running_stitch",
		"seamstress_darning", "seamstress_thimble_tea",
		"seamstress_hemorrhage_hem", "seamstress_blanket_stitch",
		"seamstress_field_mend", "seamstress_red_thread"
	]


func _unsold_pool_offer_index(stock: Dictionary) -> int:
	for index in range(stock.get("cards", []).size()):
		var offer: Dictionary = stock.cards[index]
		if not offer.sold and _is_shop_base_pool(String(offer.id)):
			return index
	return -1
