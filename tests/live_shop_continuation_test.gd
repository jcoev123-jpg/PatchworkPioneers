extends "res://tests/live_shop_route_entry_test.gd"
## Real seeded Fight -> reward -> Shop -> connected noncombat visit.


func _continuation_fixture(kind: String) -> Dictionary:
	for value in range(1, 1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for fight in map.get_legal_choices():
			if map.get_node(fight).type != "Fight":
				continue
			for shop in map.get_node(fight).outgoing:
				if map.get_node(shop).type != "Shop":
					continue
				for next in map.get_node(shop).outgoing:
					if map.get_node(next).type != kind:
						continue
					map.choose_node(fight)
					var selected := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
					if selected.get("encounter_id") == "starter_attacks":
						return {"seed": value, "fight": fight, "shop": shop, "next": next}
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


func _bounds(view: Control) -> void:
	_check(view.is_visible_in_tree() and Rect2(0, 0, 1280, 720).encloses(view.get_global_rect()), "visit fits viewport")
	for control in view.get_children():
		if control is Control:
			_check(Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()), "every mounted visit control fits viewport")


func _paid_card(index: int, keyboard: bool) -> void:
	var stock: Dictionary = app.shop_purchases.get_stock()
	var offer: Dictionary = stock.cards[index]
	var expected: Array = app.run_deck.duplicate()
	expected.append(offer.id)
	var gold: int = app.session_gold - offer.price
	var rng: int = app.run_rng.state
	_check(not offer.sold and gold >= 0, "post-removal purchase fixture is unsold and affordable")
	app.shop_offers.select(index)
	app.shop_offers.item_selected.emit(index)
	_check(not app.shop_offers.disabled and not app.shop_buy_button.disabled, "valid visit keeps selected affordable stock enabled")
	if keyboard:
		app.shop_offers.grab_focus()
		await _key(KEY_TAB)
		_check(app.shop_buy_button.has_focus(), "Tab reaches Buy from stock after removal")
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
			await _paid_card(1 if kind == "Shop" else 0, session == 1)
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
				_check(app.shop_offers.has_focus(), "Shop focus wraps after Return")
				for step in range(5):
					if button.has_focus():
						break
					await _key(KEY_TAB)
				_check(button.has_focus(), "Tab navigation reaches Continue after removal and continued buying")
				await _key(KEY_SPACE)
			_check(app.route_view != null and not app.shop_view.visible and not app.title_view.visible, "physical Continue opens connected choices without returning or selecting")
			if app.route_view == null:
				break
			_check(visit.get_state().status == "closed" and _persistent() == before[0] and app.run_map == live_map, "Shop exit closes ledger while preserving exact run, actors, map and RNG")
			_bounds(app.route_view)
			before = _continuation_state()
			for callback in [exit, remove, buy, back]:
				callback.call()
			var shown: Array[String] = []
			for action in app.route_buttons:
				var id: String = action.get_meta("route_id")
				var node_kind: String = live_map.get_node(id).type
				shown.append(id)
				_check(action.text.begins_with("%s: %s" % [id, node_kind]) and action.disabled == (node_kind not in ["Rest", "Shop", "Event", "Treasure", "Fight", "Elite", "Boss"]), "exact adjacent ID/type with only supported kinds enabled")
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
