extends "res://tests/live_rest_route_entry_test.gd"
## Mounted route/combat/reward/Shop inputs; only funded gold/count are injected.


class RejectingMap extends RunMap:
	var attempts := 0
	func choose_node(_id: String) -> bool:
		attempts += 1
		return false


func _stock_oracle() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.state = app.run_rng.state
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
	var ids: Array[String] = []
	for hero in app.run_heroes:
		ids.append(hero.id)
	var expected := RunShopStockOffers.generate(rng, ids, authored.cards, authored.trinkets, [])
	_check(expected.ok, "real authored pools produce oracle stock")
	for category in ["cards", "trinkets"]:
		for offer in expected[category]:
			offer.sold = false
	return {"stock": {"cards": expected.cards, "trinkets": expected.trinkets}, "state": rng.state}


func _fixture() -> Dictionary:
	for value in range(1, 1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for id in map.get_legal_choices():
			if map.get_node(id).type != "Fight":
				continue
			var shop := false
			var unsupported := false
			for next in map.get_node(id).outgoing:
				shop = shop or map.get_node(next).type == "Shop"
				unsupported = unsupported or map.get_node(next).type not in ["Rest", "Shop"]
			if shop and unsupported:
				map.choose_node(id)
				var selected := RunFightEncounterSelection.new().select_current_fight(map, rng, app.FIGHT_ENCOUNTER_PATHS)
				if selected.get("encounter_id") == "starter_attacks":
					return {"seed": value, "fight": id}
	return {}


func _shop_state() -> Array:
	return [_persistent(), app.run_removal_count, app.shop_visit.get_state()]


func _popup_key(code: Key) -> void:
	var popup: PopupMenu = app.shop_cards.get_popup()
	_check(popup.visible, "owned-card popup is open for physical input")
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _fixture()
	_check(not fixture.is_empty(), "seeded real graph offers Shop and unsupported choices after starter Fight")
	if fixture.is_empty():
		_finish_shop()
		return
	var stale: Array[Callable] = []
	var replay: Array = []
	# Normal insufficient funds, funded mouse, funded keyboard with escalated quote,
	# and same-seed normal restart/skip.
	for session in range(4):
		seed(400040)
		var global_next := randi()
		seed(400040)
		if not await _routed_win(fixture, false):
			break
		if session != 1:
			await _click(app.reward_buttons[3])
		else:
			app.reward_buttons[0].grab_focus()
			await _key(KEY_ENTER)
		_check(app.fight_reward_claimed and is_instance_valid(app.continue_button), "reward claim/skip exposes live Continue")
		if not is_instance_valid(app.continue_button):
			break
		var before := _persistent()
		for callback in stale:
			callback.call()
		_check(_persistent() == before and app.shop_visit == null, "old visit callbacks cannot spend or reopen in fresh combat")
		await _click(app.continue_button)
		var shop: Button
		var shown: Array[String] = []
		before = _persistent()
		for button in app.route_buttons:
			var id: String = button.get_meta("route_id")
			var kind: String = app.run_map.get_node(id).type
			shown.append(id)
			_check(button.disabled == (kind not in ["Rest", "Shop"]), "only connected Rest/Shop controls enabled")
			if kind == "Shop":
				shop = button
			if button.disabled:
				await _click(button)
				button.grab_focus()
				await _key(KEY_ENTER)
				button.pressed.emit()
		_check(shown == app.run_map.get_legal_choices() and shop != null, "real connected Shop button is mounted")
		_check(_persistent() == before, "unsupported physical and retained signal input is inert")
		if shop == null:
			break
		var route_callback: Callable = shop.pressed.get_connections()[0].callable
		var back_callback: Callable = app.route_back_button.pressed.get_connections()[0].callable
		var prior: Array[String] = app.run_map.get_route()
		var id: String = shop.get_meta("route_id")
		var parent: String = app.run_map.get_current_node_id()
		var outgoing: Array = app.run_map._nodes[parent].outgoing.duplicate()
		app.run_map._nodes[parent].outgoing.erase(id)
		route_callback.call()
		_check(_persistent() == before and app.shop_view == null, "disconnected mounted Shop rejects before map commit")
		app.run_map._nodes[parent].outgoing = outgoing
		app._choose_shop_route(id, weakref(RunMap.new()), prior, shop)
		app._choose_shop_route("f12_n0", weakref(app.run_map), prior, shop)
		var empty_route: Array[String] = []
		app._choose_shop_route(id, weakref(app.run_map), empty_route, shop)
		shop.disabled = true
		route_callback.call()
		shop.disabled = false
		app.run_map._nodes[id].type = "Rest"
		route_callback.call()
		app.run_map._nodes[id].type = "Shop"
		_check(_persistent() == before and app.shop_visit == null, "wrong identity, ID, route, disabled button and node type reject")
		var saved_gold: int = app.session_gold
		app.session_gold = -1
		var invalid_before := _persistent()
		route_callback.call()
		_check(_persistent() == invalid_before and app.shop_visit == null, "invalid ledger cannot commit a route choice")
		app.session_gold = saved_gold
		var saved_rng: RandomNumberGenerator = app.run_rng
		app.run_rng = null
		var missing_before := [app.run_heroes.duplicate(true), app.run_deck.duplicate(), app.session_gold,
			app.run_removal_count, app.run_map.get_floors(), app.run_map.get_route()]
		route_callback.call()
		_check(app.run_rng == null and app.shop_visit == null and app.shop_purchases == null
			and missing_before == [app.run_heroes, app.run_deck, app.session_gold,
			app.run_removal_count, app.run_map.get_floors(), app.run_map.get_route()], "absent RNG rejects without partial entry")
		app.run_rng = saved_rng
		# A valid roster with an unknown catalog owner must fail stock generation without draws.
		var heroes: Array = app.run_heroes.duplicate(true)
		app.run_heroes[0].id = "unknown_shop_owner"
		_check(app._can_choose_connected_route(), "unknown catalog owner passes roster admission before stock rejection")
		invalid_before = _persistent()
		route_callback.call()
		_check(_persistent() == invalid_before and app.shop_visit == null and app.shop_purchases == null,
			"rejected stock leaves roster, deck, gold, route and RNG untouched")
		app.run_heroes = heroes
		# Force choose_node to reject only after admission and valid generation.
		var original_map: RunMap = app.run_map
		var rejecting := RejectingMap.new()
		rejecting._nodes = original_map._nodes.duplicate(true)
		rejecting._floor_ids = original_map._floor_ids.duplicate(true)
		rejecting._route.assign(prior)
		app.run_map = rejecting
		app._connected_map = weakref(rejecting)
		app._reward_map = weakref(rejecting)
		invalid_before = _persistent()
		_check(not app._choose_shop_route(id, weakref(rejecting), prior, shop) and rejecting.attempts == 1,
			"valid generated stock reaches rejecting map choice")
		_check(_persistent() == invalid_before and app.shop_visit == null and app.shop_purchases == null,
			"rejected map choice restores RNG and publishes no ledger or stock")
		app.run_map = original_map
		app._connected_map = weakref(original_map)
		app._reward_map = weakref(original_map)
		# A connected whitespace node reaches open_visit, which rejects its ID.
		original_map._nodes[" "] = original_map._nodes[id].duplicate(true)
		original_map._nodes[parent].outgoing.append(" ")
		shop.set_meta("route_id", " ")
		_check(app._can_choose_connected_route() and original_map.get_legal_choices().has(" ")
			and original_map.get_node(" ").type == "Shop" and _stock_oracle().stock.cards.size() == 5,
			"whitespace fixture admits connected Shop with valid generated stock before visit opening")
		invalid_before = _persistent()
		_check(not app._choose_shop_route(" ", weakref(original_map), prior, shop), "visit opening rejects whitespace ID")
		_check(_persistent() == invalid_before and app.shop_visit == null and app.shop_purchases == null,
			"failed visit opening rolls back committed map and generated RNG")
		original_map._nodes.erase(" ")
		original_map._nodes[parent].outgoing = outgoing
		shop.set_meta("route_id", id)
		if session in [1, 2]:
			app.session_gold = 200
			app.run_removal_count = 1 if session == 2 else 0
		if session == 2:
			shop.grab_focus()
			await _key(KEY_ENTER)
		else:
			await _click(shop)
		_check(app.shop_view != null and app.shop_visit != null, "physical Shop entry mounts real ledger and view")
		if app.shop_view == null or app.shop_visit == null:
			break
		var visit: RunShopVisit = app.shop_visit
		var state := visit.get_state()
		_check(app.run_map.get_route() == [fixture.fight, id] and state.visited_ids == [id]
			and state.shop_node_id == id and state.removal_available, "Shop records exact ID and route once")
		var price: int = 75 + 25 * app.run_removal_count
		_check(app.shop_label.text == "Gold: %d | Removal: %d gold" % [app.session_gold, price], "visible gold and authoritative escalating quote")
		_check(app.shop_cards.item_count == app.run_deck.size(), "compact OptionButton includes every owned copy")
		for index in range(app.run_deck.size()):
			_check(app.shop_cards.get_item_text(index) == app.run_deck[index], "owned ID order is visible")
		_check(app.shop_purchases.is_valid() and app.shop_offers.item_count == 5, "routed Shop includes valid card buying stock")
		for control in [app.shop_view, app.shop_label, app.shop_offers, app.shop_buy_button, app.shop_cards, app.shop_remove_button, app.shop_continue_button, app.shop_back_button]:
			_check(control.is_visible_in_tree() and Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()), "Shop control fits 1280x720")
		before = _shop_state()
		route_callback.call()
		back_callback.call()
		_check(_shop_state() == before and app.shop_view.visible, "duplicate entry and stale route Back cannot mutate or close Shop")
		var remove_callback: Callable = app.shop_remove_button.pressed.get_connections()[0].callable
		var live_map: RunMap = app.run_map
		var other := RunMap.new()
		var other_rng := RandomNumberGenerator.new()
		other_rng.seed = fixture.seed
		other.generate(other_rng)
		_check(other.choose_node(fixture.fight) and other.choose_node(id), "replacement map has identical legal Shop route")
		app.run_map = other
		var wrong_before := _shop_state()
		remove_callback.call()
		_check(_shop_state() == wrong_before, "same-route replacement map cannot spend")
		app.run_map = live_map
		app._remove_at_shop(RunShopVisit.new(app.run_deck, app.session_gold, 0), app.shop_remove_button)
		app._remove_at_shop(visit, app.shop_back_button)
		app.session_gold += 1
		var changed_before := _shop_state()
		remove_callback.call()
		_check(_shop_state() == changed_before, "gold mismatched with ledger cannot spend")
		app.session_gold -= 1
		app.run_removal_count += 1
		changed_before = _shop_state()
		remove_callback.call()
		_check(_shop_state() == changed_before, "count mismatched with ledger cannot spend")
		app.run_removal_count -= 1
		app.run_deck.append("warden_strike")
		changed_before = _shop_state()
		remove_callback.call()
		_check(_shop_state() == changed_before, "deck mismatched with ledger cannot spend")
		app.run_deck.pop_back()
		var selected: int = app.shop_cards.selected
		var original_id: String = app.shop_cards.get_item_text(selected)
		var different_id := ""
		for owned in app.run_deck:
			if owned != original_id:
				different_id = owned
				break
		_check(not different_id.is_empty(), "mismatched fixture is a different owned ID")
		for invalid in ["unknown_card", different_id]:
			app.shop_cards.set_item_text(selected, invalid)
			remove_callback.call()
			_check(_shop_state() == before, "unknown or mismatched owned ID cannot spend")
		app.shop_cards.set_item_text(selected, original_id)
		if session in [0, 3]:
			_check(app.session_gold < price, "natural victory gold cannot afford removal")
			await _click(app.shop_remove_button)
			app.shop_remove_button.grab_focus()
			await _key(KEY_ENTER)
			_check(_shop_state() == before and not app.shop_remove_button.disabled
				and app.shop_cards.selected == selected, "insufficient funds retain selection, state and available option")
			if session == 0:
				replay = before.duplicate(true)
			else:
				_check(before == replay, "same-seed restart reproduces complete combat, inventory, ledger, route and RNG")
		else:
			# Select the last copy by physical keyboard navigation in the actual popup.
			var duplicate_index := -1
			for index in range(1, app.run_deck.size()):
				if app.run_deck[index] == app.run_deck[0]:
					duplicate_index = index
			_check(duplicate_index > 0, "owned fixture contains duplicate copies")
			if duplicate_index < 0:
				break
			app.shop_cards.grab_focus()
			await _key(KEY_SPACE)
			await _popup_key(KEY_HOME)
			for index in range(duplicate_index):
				await _popup_key(KEY_DOWN)
			await _popup_key(KEY_ENTER)
			_check(app.shop_cards != null, "popup selection keeps Shop mounted")
			if app.shop_cards == null:
				break
			_check(app.shop_cards.selected == duplicate_index, "physical keyboard chooses later duplicate in owned popup")
			var expected_deck: Array = app.run_deck.duplicate()
			expected_deck.remove_at(0)
			var gold: int = app.session_gold
			var count: int = app.run_removal_count
			if session == 1:
				await _click(app.shop_remove_button)
			else:
				app.shop_cards.grab_focus()
				await _key(KEY_TAB)
				_check(app.shop_remove_button.has_focus(), "Tab reaches Remove from owned selector")
				await _key(KEY_ENTER)
			_check(app.run_deck == expected_deck and app.session_gold == gold - price
				and app.run_removal_count == count + 1, "funded input removes FIRST duplicate and charges exact quote once")
			_check(visit.get_state().deck == expected_deck and visit.get_state().gold == app.session_gold
				and visit.get_state().prior_removals == count + 1 and app.shop_remove_button.disabled,
				"run mirrors used ledger exactly and disables removal")
			var after := _shop_state()
			remove_callback.call()
			app.shop_remove_button.pressed.emit()
			await _click(app.shop_remove_button)
			_check(_shop_state() == after, "repeat mouse and retained callback cannot remove or charge twice")
			_check(after[0][0] == before[0][0] and after[0][3] == before[0][3]
				and after[0][4] == before[0][4], "removal preserves heroes, seeded RNG and route")
		stale = [route_callback, back_callback, remove_callback,
			app.shop_continue_button.pressed.get_connections()[0].callable,
			app.shop_back_button.pressed.get_connections()[0].callable]
		if session % 2 == 0:
			app.shop_back_button.grab_focus()
			await _key(KEY_ENTER)
		else:
			await _click(app.shop_back_button)
		for callback in stale:
			callback.call()
		_check(visit.get_state().status == "closed" and app.title_view.visible and app.shop_visit == null
			and app.shop_view == null and app.shop_cards == null and app.shop_remove_button == null
			and app.shop_back_button == null and app.run_map == null and app.run_deck.is_empty()
			and app.shop_continue_button == null
			and app.shop_purchases == null and app.shop_offers == null and app.shop_buy_button == null
			and app.session_gold == 0 and app.run_removal_count == 0, "skip/Return closes ledger, clears run and rejects stale inputs")
		_check(randi() == global_next, "complete physical route/Shop leaves global RNG untouched")
	_finish_shop()


func _finish_shop() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_shop_route_entry_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
