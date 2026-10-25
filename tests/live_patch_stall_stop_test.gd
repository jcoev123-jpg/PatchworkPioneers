extends "res://tests/live_campfire_stop_test.gd"

func _fixture() -> Dictionary:
	for value in range(1, 2000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for id in map.get_legal_choices():
			if map.get_node(id).type == "PatchStall":
				for next in map.get_node(id).outgoing:
					if map.get_node(next).type == "Fight":
						return {"seed": value, "id": id, "next": next}
	return {}


func _stall_state() -> Array:
	return [app._patch_stall_snapshot(), app._patch_stall_closed, app._patch_stall_visits.duplicate(true)]


func _stall_refuse(callback: Callable, reason: String) -> void:
	var before := _stall_state()
	callback.call()
	_check(before == _stall_state(), reason + " preserves all authorities and RNG")


func _stall_scenario(keyboard: bool, buy: bool, funded: bool, wearer: int, connected: bool = false) -> Array:
	fixture = _post_fight_fixture() if connected else _fixture()
	_check(not fixture.is_empty(), "genuine bounded seeded Patch Stall -> Fight fixture")
	if fixture.is_empty():
		return []
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	if connected:
		if not await _routed_win(fixture, false):
			app.free()
			return []
		await _click(app.reward_buttons[3])
		await _click(app.continue_button)
		await _frames()
	else:
		app.run_seed = fixture.seed
		await _click(app.start_button)
		await _frames()
	if funded:
		# Use the shipped preview's explicit opening wallet authority.
		app.session_gold = 100
		app.run_scraps = 10
		root.get_node("LiveWebPlaytestBoot")._preview_map = weakref(app.run_map)
		app._clear_route_view()
		app._present_connected_route(weakref(app.run_map))
		await _frames()
	var route := _button(fixture.id)
	_check(route != null and not route.disabled and route.text == "Patch Stall"
		and route.get_meta("route_kind") == "PatchStall", "unique legal canonical kind and player label")
	var entry: Callable = route.pressed.get_connections()[0].callable
	var prior: Array = app.run_map.get_route()
	app.run_scraps += 1
	entry.call()
	_check(app.run_map.get_route() == prior and app.patch_stall_visit == null, "stale route wallet refuses entry")
	app.run_scraps -= 1
	var oracle := RandomNumberGenerator.new()
	oracle.state = app.run_rng.state
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
	var powers := RunAuthoredPatchDefinitions.load_power_definitions()
	var ids: Array = []
	for record in powers:
		ids.append(record.id)
	var remaining: Array = []
	var prices := {}
	for offer in authored.trinkets:
		if ids.has(offer.id) and not app.run_trinkets.has(offer.id):
			remaining.append(offer.id)
			prices[offer.id] = int(offer.price)
	remaining.sort()
	_check(remaining.size() >= 3, "real priced power candidate pool")
	var expected: Array = []
	for i in range(3):
		var index := oracle.randi_range(0, remaining.size() - 1)
		expected.append({"id": remaining[index], "price": prices[remaining[index]], "sold": false})
		remaining.remove_at(index)
	if keyboard:
		await _click(app.route_map_button)
		var marker: Button = app.route_atlas.get_node("Node_" + fixture.id + "/Action")
		_check(marker.tooltip_text.contains("Buy one of 3 priced power patches for one chosen hero, sewing included, or leave unchanged"), "truthful atlas Help")
		var atlas_callback: Callable = app.route_atlas.node_requested.get_connections()[0].callable
		app.run_scraps += 1
		atlas_callback.call(fixture.id)
		_check(app.run_map.get_route() == prior and is_instance_valid(app.route_atlas), "stale atlas callback keeps overlay and route")
		app.run_scraps -= 1
		marker.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(route)
	await _frames()
	_check(is_instance_valid(app.patch_stall_view) and app.patch_stall_view.is_visible_in_tree()
		and app.run_map.get_route() == prior + [fixture.id], "physical input advances exactly once into Patch Stall")
	_check(app.patch_stall_visit.get_state().shop_node_id == fixture.id
		and app.patch_stall_visit.get_state().status == "available", "confirmed real visit")
	_check(app.patch_stall_purchases.get_stock() == {"cards": [], "trinkets": expected}
		and app.run_rng.state == oracle.state, "exact independently seeded three-offer stock and RNG")
	_check(app.patch_stall_buttons.size() == 3 and app.patch_stall_heroes.item_count == 3
		and app.patch_stall_leave.text == "Leave" and not is_instance_valid(app.shop_view), "only patch choices, three recipients and Leave")
	var controls: Array = [app.patch_stall_heroes] + app.patch_stall_buttons + [app.patch_stall_leave]
	for control in controls:
		_check(Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()), "visible controls fit viewport")
	var visited: Array = []
	for i in range(controls.size()):
		visited.append(root.gui_get_focus_owner())
		await _key(KEY_TAB)
	for control in controls:
		if not control.disabled:
			_check(visited.has(control), "Tab reaches every enabled action and recipient selector")
	var action: Button = app.patch_stall_buttons[1]
	var callback: Callable = action.pressed.get_connections()[0].callable
	var original: Dictionary = app._sewing_context()
	app.session_gold += 1
	_stall_refuse(callback, "gold drift")
	app.session_gold -= 1
	app.run_deck.append("forged")
	_stall_refuse(callback, "deck drift")
	app.run_deck.pop_back()
	app.run_heroes[0].hp -= 1
	_stall_refuse(callback, "HP drift")
	app.run_heroes = original.heroes.duplicate(true)
	app.run_rng.randi()
	_stall_refuse(callback, "RNG drift")
	app.run_rng.state = original.rng_state
	app.run_map._generation_revision += 1
	_stall_refuse(callback, "map regeneration")
	app.run_map._generation_revision -= 1
	app.patch_stall_view.hide()
	_stall_refuse(callback, "hidden view")
	app.patch_stall_view.show()
	app.patch_stall_heroes.set_item_metadata(0, "forged")
	_stall_refuse(callback, "forged recipient")
	app.patch_stall_heroes.set_item_metadata(0, app.run_heroes[0].id)
	var metadata: Variant = action.get_meta("patch_id")
	action.set_meta("patch_id", "forged")
	_stall_refuse(callback, "forged patch")
	action.set_meta("patch_id", metadata)
	var stock: Dictionary = app.patch_stall_purchases.get_stock()
	app.patch_stall_purchases._stock.trinkets[0].price += 1
	_stall_refuse(callback, "stock drift")
	app.patch_stall_purchases._stock = stock.duplicate(true)
	if not funded:
		_check(app.patch_stall_buttons.all(func(b): return b.disabled), "broke visit disables all purchases")
		_stall_refuse(callback, "broke purchase")
	else:
		action.disabled = true
		_stall_refuse(callback, "disabled purchase")
		action.disabled = false
	var fake := Button.new()
	app.patch_stall_view.add_child(fake)
	_stall_refuse(app._patch_stall_action.bind(fake, app.patch_stall_view, app.patch_stall_visit), "forged control")
	fake.free()
	_check(app._sewing_context() == original, "negative fixtures restore exact source")
	# Keyboard recipient selection drives the real popup; mouse scenarios set its chosen row.
	app.patch_stall_heroes.grab_focus()
	await _key(KEY_SPACE)
	await _frames()
	if keyboard:
		for i in range(wearer):
			await _key(KEY_DOWN)
		await _key(KEY_ENTER)
	else:
		var popup: PopupMenu = app.patch_stall_heroes.get_popup()
		popup.hide()
		app.patch_stall_heroes.select(wearer)
	await _frames()
	_check(app.patch_stall_heroes.selected == wearer, "chosen wearer selector")
	var chosen: Button = action if buy else app.patch_stall_leave
	var dead: Callable = chosen.pressed.get_connections()[0].callable
	if keyboard:
		chosen.grab_focus()
		await _key(KEY_SPACE)
	else:
		await _click(chosen)
	await _frames()
	_check(app._patch_stall_closed and not app.patch_stall_view.visible and app._can_choose_connected_route(), "one decision closes visit and admits onward play")
	_check(app.run_rng.state == original.rng_state and app.run_deck == original.deck
		and app.run_heroes == original.heroes and app.run_removal_count == original.removals, "choice preserves HP, deck, removal and RNG")
	if buy:
		var offer: Dictionary = expected[1]
		var w: Dictionary = app._patch_stall_wardrobe.get_snapshot()
		_check(app.session_gold == original.gold - offer.price and app.run_trinkets == original.patches + [offer.id]
			and app.run_scraps == original.scraps, "one exact paid purchase, no scrap sewing fee")
		for i in range(3):
			_check(w.worn[app.run_heroes[i].id][w.definitions[offer.id]] == (offer.id if i == wearer else ""), "exactly the chosen wearer receives patch")
		_check(app.party_carryover._wardrobe == app._patch_stall_wardrobe
			and app.patch_stall_purchases.get_state().trinkets == w.owned
			and app.patch_stall_visit.get_state().trinkets == w.owned, "all ownership and carry ledgers agree")
		# Regression for the shared atomic coordinator's one-buy preflight, using fresh snapshots.
		var before := _stall_state()
		var visit: RunShopVisit = app.patch_stall_visit
		visit._status = "available"
		var refused := RunShopPatchSewing.purchase_and_sew(app.patch_stall_purchases, visit, app._patch_stall_wardrobe,
			fixture.id, expected[0].id, app.run_heroes[0].id, w.definitions[expected[0].id], "duplicate",
			app.patch_stall_purchases.get_state(), app.patch_stall_purchases.get_stock(), visit.get_state(), w)
		visit._status = "closed"
		_check(not refused.ok and _stall_state() == before, "fresh second-patch proposal rejected before any atomic mutation")
	else:
		_check(app._sewing_context() == original and not app.patch_stall_purchases.patch_stall_choice_used(), "Leave is entirely inert")
	_stall_refuse(dead, "duplicate action")
	_stall_refuse(callback, "other choice after closure")
	var result: Array = [app.run_map.get_floors(), app.run_map.get_route(), app.run_rng.state,
		app.run_trinkets.duplicate(), app.session_gold, app.run_scraps, app.run_heroes.duplicate(true), expected]
	var next := _button(fixture.next)
	_check(next != null and not next.disabled, "connected real next Fight")
	await _click(next)
	await _frames()
	_check(app.deck != null and app.run_map.get_current_node_id() == fixture.next
		and app.run_trinkets == result[3] and app.session_gold == result[4], "next encounter persists purchase ledgers")
	if buy:
		_check(app.party_carryover._wardrobe.get_snapshot().worn[app.run_heroes[wearer].id].values().has(expected[1].id), "next battle retains sewn wearer")
	_stall_refuse(dead, "dead visit callback during next fight")
	result.append(app.deck.hand.duplicate())
	result.append(app.run_rng.state)
	app._return_to_title()
	await _frames()
	_check(app.patch_stall_view == null and app._patch_stall_visits.is_empty(), "title clears witnesses")
	dead.call()
	_check(app.run_map == null and app.run_rng == null, "freed control callback cannot revive run")
	app.free()
	await _frames()
	return result


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for wearer in range(3):
		var first := await _stall_scenario(false, true, true, wearer)
		var replay := await _stall_scenario(true, true, true, wearer)
		_check(not first.is_empty() and first == replay, "same-seed mouse/map and keyboard/atlas paid replay")
	for funded in [false, true]:
		var first := await _stall_scenario(false, false, funded, 0)
		var replay := await _stall_scenario(true, false, funded, 0)
		_check(not first.is_empty() and first == replay, "same-seed Leave replay")
	var connected := await _stall_scenario(false, false, false, 0, true)
	var replay := await _stall_scenario(true, false, false, 0, true)
	_check(not connected.is_empty() and connected == replay, "post-victory connected map and atlas entry replay")
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_patch_stall_stop_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _post_fight_fixture() -> Dictionary:
	for value in range(1, 12000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		var opening := rng.state
		for fight in map.get_legal_choices():
			if map.get_node(fight).type != "Fight":
				continue
			for id in map.get_node(fight).outgoing:
				if map.get_node(id).type != "PatchStall":
					continue
				for next in map.get_node(id).outgoing:
					if map.get_node(next).type != "Fight":
						continue
					rng.state = opening
					map.choose_node(fight)
					var battle := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
					map.undo_choice(fight, [])
					if battle.get("encounter_id") == "starter_attacks":
						return {"seed": value, "fight": fight, "id": id, "next": next}
	return {}
