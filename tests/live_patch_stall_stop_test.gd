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
		preload("res://tests/party_choice.gd").choose(app)
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
	var power_ids: Dictionary = {}
	for record in powers:
		power_ids[record.id] = record.slot
	var rare_source: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/mpw_synergy_patches.json"))
	_check(typeof(rare_source) == TYPE_ARRAY and not rare_source.is_empty(),
		"shipped P8 rare catalog is readable for the stock oracle")
	var weights := {}
	var prices := {}
	for offer in authored.trinkets:
		if power_ids.has(offer.id) and not app.run_trinkets.has(offer.id):
			weights[offer.id] = 100
			prices[offer.id] = int(offer.price)
	# Each P8 rare competes with ONE ordinary patch at its authored percentage.
	var rare_records: Array = rare_source if rare_source is Array else []
	for record in rare_records:
		if app.run_trinkets.has(record.id):
			continue
		power_ids[record.id] = record.slot
		weights[record.id] = 100 * int(record.stock_weight_percent) / 100
		prices[record.id] = int(record.shop_price_gold)
	var remaining: Array = weights.keys()
	remaining.sort()
	_check(remaining.size() >= 3, "real priced power candidate pool")
	# The live entry's real pool weighs both P8 rares as one tenth of one
	# ordinary patch and keeps the earlier named ordinary patches at full weight.
	_check(weights.get("relay_bobbin") == 10 and weights.get("hearth_lining") == 10,
		"live Patch Stall pool weighs both P8 rares at 10% of one ordinary")
	_check(weights.get("button_eye") == 100 and weights.get("frayfinder_mitt") == 100
		and weights.get("borrowed_button") == 100,
		"live Patch Stall pool keeps earlier ordinary patches at full weight")
	_check(prices.get("relay_bobbin") == 100 and prices.get("hearth_lining") == 100,
		"live Patch Stall quotes both P8 rares at 100 gold")
	var expected: Array = []
	for i in range(3):
		var total := 0
		for id in remaining:
			total += weights[id]
		var ticket := oracle.randi_range(0, total - 1)
		var walked := 0
		var chosen := ""
		for id in remaining:
			walked += weights[id]
			if ticket < walked:
				chosen = id
				break
		expected.append({"id": chosen, "price": prices[chosen], "sold": false})
		remaining.erase(chosen)
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
	var service: RunPatchStallVisit = app.patch_stall_service
	_check(service != null and service.is_valid() and not service.is_consumed(), "real route constructs open one-use service")
	var service_state := service.read_state()
	var ids: Array = []
	for hero in app.run_heroes:
		ids.append(hero.id)
	_check(service_state.node_id == fixture.id and not service_state.visit_id.is_empty()
		and service.read_state().visit_id == service_state.visit_id
		and service_state.snapshot == {"party_ids": ids, "deck_ids": app.run_deck,
			"owned_trinkets": app.run_trinkets, "gold": app.session_gold}, "service binds confirmed node and exact live ledger")
	_check(service.quote() == {"offers": expected, "decisions": ["buy_patch", "leave"]}, "service authentic quote matches independent seeded oracle")
	_check(not app._can_choose_connected_route(), "open visit cannot advance before a physical decision")
	var panel: LivePatchStallPanel = app.patch_stall_view
	_check(panel.position == Vector2(190, 45) and panel.size == Vector2(900, 630)
		and panel._visit == service and panel._source == service_state and panel._quoted == service.quote(),
		"one authentic centered sewn panel binds exact service after node commit")
	# Verify the real map-mounted stop, not a detached preview, owns one
	# authored-image renderer behind its unchanged interactive controls.
	var live_ambient: Control = panel.ambient_layer
	var backing := panel.get_child(0) as Panel
	_check(live_ambient != null and backing.clip_contents
			and live_ambient.get_parent() == backing
			and live_ambient.get_index() < backing.get_child(1).get_index()
			and backing.get_index() < panel.title_label.get_index()
			and panel.find_children("LiveBattleAmbient", "Control", true, false).size() == 1,
			"real routed Patch Stall has one clipped renderer under sewn GUI")
	_check(live_ambient.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and live_ambient.focus_mode == Control.FOCUS_NONE
			and live_ambient.size == Vector2(900, 630)
			and live_ambient.profile == "scraps" and live_ambient.fast
			and live_ambient._visit_dressing and live_ambient.visible_budget() == 7
			and is_equal_approx(live_ambient.self_modulate.a, 0.42),
			"real routed visit uses seven quiet input-inert authored motes")
	var ambient_controls_before: Array = []
	for b in panel.wearer_buttons + panel.offer_buttons + [panel.leave_button]:
		ambient_controls_before.append([b.get_global_rect(), b.text, b.disabled,
			b.focus_mode, b.focus_next, b.has_focus()])
	var ambient_focus := root.gui_get_focus_owner()
	var ambient_source := service.read_state()
	var ambient_quote := service.quote()
	var ambient_run_rng: int = app.run_rng.state
	var ambient_context: Dictionary = app._sewing_context()
	var ambient_motifs: Array = live_ambient.motif_metadata()
	var ambient_light: float = live_ambient.light_alpha(live_ambient._time, true)
	seed(99187)
	var expected_global := randi()
	seed(99187)
	live_ambient._process(3.75)
	var ambient_controls_after: Array = []
	for b in panel.wearer_buttons + panel.offer_buttons + [panel.leave_button]:
		ambient_controls_after.append([b.get_global_rect(), b.text, b.disabled,
			b.focus_mode, b.focus_next, b.has_focus()])
	_check(ambient_motifs.size() == 7 and live_ambient.motif_metadata() != ambient_motifs
			and live_ambient.light_alpha(live_ambient._time, true) != ambient_light,
			"real mounted VFX motion updates deterministic motes and candlelight")
	_check(ambient_controls_after == ambient_controls_before
			and root.gui_get_focus_owner() == ambient_focus and panel._wearer_index == 0
			and service.read_state() == ambient_source and service.quote() == ambient_quote
			and app._sewing_context() == ambient_context and app.run_rng.state == ambient_run_rng
			and randi() == expected_global, "mounted animation changes no quote, input, wearer or RNG")
	var mounted: Array = []
	for child in app.get_children():
		if child.name == "PatchStall":
			_check(child is LivePatchStallPanel, "mounted Patch Stall node is an authentic sewn panel")
			mounted.append(child)
	_check(mounted.size() == 1, "exactly one mounted Patch Stall panel")
	for index in range(3):
		var offer: Dictionary = expected[index]
		var shortfall: int = maxi(0, offer.price - app.session_gold)
		var cost := "%d gold" % offer.price if shortfall == 0 else "%d gold  \u00b7  short %d" % [offer.price, shortfall]
		var caption := "%d  %s  [%s]  \u2715 %s  \u00b7  %s" % [index + 1, String(offer.id).replace("_", " ").capitalize(),
			offer.id, power_ids[offer.id], cost]
		var preview: Dictionary = panel._descriptions.get(offer.id, {})
		var short_rule: String = preview.get("short", "")
		var full_rule: String = preview.get("full", "")
		_check(not short_rule.is_empty() and not full_rule.is_empty()
			and short_rule != LivePatchStallPanel.DETAILS_UNAVAILABLE
			and panel.offer_buttons[index].text == caption + "\n" + short_rule
			and panel.offer_buttons[index].tooltip_text.contains(full_rule)
			and panel.offer_buttons[index].tooltip_text.contains("Torn"),
			"visible choice displays exact authentic price, patch and wearer power")
		var font: Font = panel.offer_buttons[index].get_theme_font("font")
		var measured := font.get_multiline_string_size(panel.offer_buttons[index].text,
			HORIZONTAL_ALIGNMENT_CENTER, panel.offer_buttons[index].size.x - 24,
			panel.offer_buttons[index].get_theme_font_size("font_size"))
		_check(measured.x <= panel.offer_buttons[index].size.x - 24
			and measured.y <= panel.offer_buttons[index].size.y - 14,
			"numbered two-line caption and power fit the sewn 90px action at 1280x720")
	_check(panel.offer_buttons.size() == 3 and panel.wearer_buttons.size() == 3
		and panel.leave_button.text == "0 Leave  \u00b7  FREE" and not is_instance_valid(app.shop_view),
		"only patch choices, three recipients and Leave")
	_check(panel.wearer_label.is_visible_in_tree()
		and panel.wearer_label.text == LivePatchStallPanel.WEARER_WARNING
		and panel.wearer_label.text.contains("+1 scrap"),
		"live Patch Stall always shows the same-slot destruction warning")
	for index in range(3):
		var live_slot: String = power_ids[expected[index].id]
		_check(panel.offer_buttons[index].tooltip_text.contains(
				"%s slot: a patch already worn in this slot is destroyed for exactly +1 scrap." % live_slot)
			and panel.offer_buttons[index].tooltip_text.contains(
				"A free %s slot destroys nothing and gains no scrap." % live_slot),
			"live tooltip names the offer's own %s slot and both replacement outcomes" % live_slot)
	var controls: Array = panel.wearer_buttons + panel.offer_buttons + [panel.leave_button]
	for control in controls:
		_check(Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()), "visible controls fit viewport")
	var visited: Array = []
	for i in range(controls.size()):
		visited.append(root.gui_get_focus_owner())
		await _key(KEY_TAB)
	for control in controls:
		if not control.disabled:
			_check(visited.has(control), "Tab reaches every enabled action and recipient selector")
	var action: Button = app.patch_stall_view.offer_buttons[1]
	var callback: Callable = func():
		panel._connections[action].call()
	var handler: Callable = panel.intent_requested.get_connections()[0].callable
	var proposal := {"action": "buy_patch", "patch_id": expected[1].id, "wearer_id": ids[0],
		"node_id": fixture.id, "visit_id": service_state.visit_id, "expected_snapshot": service_state.snapshot}
	_stall_refuse(handler.bind(proposal), "direct intent without panel submission")
	# Exact-key and full source authentication at the real app listener, even
	# when a hostile caller imitates the panel's submitted control state.
	for key in ["action", "patch_id", "wearer_id", "node_id", "visit_id", "expected_snapshot", "extra"]:
		var forged := proposal.duplicate(true)
		match key:
			"action": forged.action = "buy"
			"patch_id": forged.patch_id = "forged"
			"wearer_id": forged.wearer_id = "forged"
			"node_id": forged.node_id = "foreign"
			"visit_id": forged.visit_id = "foreign"
			"expected_snapshot": forged.expected_snapshot.gold += 1
			"extra": forged.extra = true

		panel._submitted = true
		for control in controls:
			control.disabled = true
		panel._retire_callbacks()
		_stall_refuse(handler.bind(forged), "corrupted intent " + key)
	panel.bind(service)

	var original: Dictionary = app._sewing_context()
	var prepared: Array = []
	for offer in expected:
		prepared.append({"id": offer.id, "price": offer.price})
	var foreign := RunPatchStallVisit.new(fixture.id, ids, app.run_deck, app.run_trinkets, app.session_gold, prepared)
	_check(foreign.is_valid() and foreign.read_state().node_id == service_state.node_id
		and foreign.read_state().snapshot == service_state.snapshot
		and foreign.read_state().status == service_state.status
		and foreign.read_state().visit_id != service_state.visit_id and foreign.quote() == service.quote(),
		"foreign identity fixture has genuinely identical valid source and quote")
	app.patch_stall_service = foreign
	_stall_refuse(callback, "foreign service with identical quote")
	app.patch_stall_service = service
	service._snapshot.gold += 1
	_stall_refuse(callback, "service source drift")
	service._snapshot.gold -= 1
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
	panel.wearer_buttons[0].set_meta("wearer_id", "forged")
	_stall_refuse(callback, "forged recipient")
	panel.wearer_buttons[0].set_meta("wearer_id", app.run_heroes[0].id)
	var metadata: Variant = action.get_meta("patch_id")
	action.set_meta("patch_id", "forged")
	_stall_refuse(callback, "forged patch")
	action.set_meta("patch_id", metadata)
	var stock: Dictionary = app.patch_stall_purchases.get_stock()
	app.patch_stall_purchases._stock.trinkets[0].price += 1
	_stall_refuse(callback, "stock drift")
	app.patch_stall_purchases._stock = stock.duplicate(true)
	if not funded:
		_check(app.patch_stall_view.offer_buttons.all(func(b): return b.disabled), "broke visit disables all purchases")
		_stall_refuse(callback, "broke purchase")
	else:
		action.disabled = true
		_stall_refuse(callback, "disabled purchase")
		action.disabled = false
	var fake := Button.new()
	app.patch_stall_view.add_child(fake)
	_stall_refuse(app._patch_stall_action.bind(proposal, weakref(fake), service, service_state, service.quote()), "forged control")
	fake.free()
	_check(app._sewing_context() == original, "negative fixtures restore exact source")
	# Both input modes choose a real sewn wearer pin.
	if keyboard:
		panel.wearer_buttons[wearer].grab_focus()
		await _key(KEY_SPACE)
	else:
		await _click(panel.wearer_buttons[wearer])
	await _frames()
	_check(panel._wearer_index == wearer and panel.wearer_buttons[wearer].get_meta("wearer_id") == ids[wearer],
		"chosen physical wearer pin")
	var chosen: Button = action if buy else app.patch_stall_view.leave_button
	var final_intent: Dictionary = proposal.duplicate(true) if buy else {
		"action": "leave", "node_id": fixture.id, "visit_id": service_state.visit_id,
		"expected_snapshot": service_state.snapshot}
	if buy:
		final_intent.wearer_id = ids[wearer]
	var dead: Callable = handler.bind(final_intent)
	var retired: WeakRef = weakref(panel)
	if keyboard:
		chosen.grab_focus()
		await _key(KEY_SPACE)
	else:
		await _click(chosen)
	await _frames()
	_check(app._patch_stall_closed and app.patch_stall_view == null and retired.get_ref() == null and app._can_choose_connected_route(), "one decision closes visit and admits onward play")
	_check(not is_instance_valid(live_ambient),
			"real paid or free settlement frees the renderer with the retired stop")
	_check(service.is_consumed() and service.read_state().snapshot == service_state.snapshot,
		"physical decision consumes exactly the bound service without replacing its source")
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
	_stall_refuse(handler.bind(proposal), "other choice after closure")
	app.patch_stall_service = foreign
	_check(not app._can_choose_connected_route(), "foreign open service cannot authenticate freed-panel route")
	var foreign_source := foreign.read_state()
	_check(foreign.leave(foreign_source.visit_id, foreign_source.node_id, foreign_source.snapshot).ok,
		"foreign service is genuinely consumed for closed identity rejection")
	_check(not app._can_choose_connected_route(), "foreign consumed service cannot authenticate freed-panel route")
	app.patch_stall_service = service
	var witness: Array = app._patch_stall_visits[fixture.id]
	app._patch_stall_visits.erase(fixture.id)
	_check(not app._can_choose_connected_route(), "freed panel requires authentic route witness")
	app._patch_stall_visits[fixture.id] = witness
	_check(app._can_choose_connected_route(), "restored authentic closed service and witness admit onward route")
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
	_check(app.patch_stall_view == null and app.patch_stall_service == null and app._patch_stall_visits.is_empty(), "title clears service and witnesses")
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
	await _open_title_teardown()
	_finish()


func _open_title_teardown() -> void:
	fixture = _fixture()
	_check(not fixture.is_empty(), "open-title teardown has a genuine seeded route")
	if fixture.is_empty():
		return
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = fixture.seed
	await _click(app.start_button)
	preload("res://tests/party_choice.gd").choose(app)
	await _click(_button(fixture.id))
	var panel: LivePatchStallPanel = app.patch_stall_view
	_check(is_instance_valid(panel) and panel.is_visible_in_tree(), "title teardown starts with open mounted panel")
	if not is_instance_valid(panel):
		app.free()
		return
	var service: RunPatchStallVisit = app.patch_stall_service
	var source := service.read_state()
	var handler: Callable = panel.intent_requested.get_connections()[0].callable.bind({
		"action": "leave", "node_id": source.node_id, "visit_id": source.visit_id,
		"expected_snapshot": source.snapshot})
	var retired: WeakRef = weakref(panel)
	app._return_to_title()
	await _frames()
	_check(retired.get_ref() == null and app.patch_stall_view == null and app.patch_stall_service == null
		and app._patch_stall_context.is_empty() and app._patch_stall_visits.is_empty(),
		"title frees open panel and clears all bindings and witnesses")
	handler.call()
	_check(app.run_map == null and service.read_state() == source, "retired open intent cannot consume visit at title")
	await _click(app.start_button)
	preload("res://tests/party_choice.gd").choose(app)
	await _frames()
	var before: Dictionary = app._sewing_context()
	_check(app.run_map != null and not before.is_empty(), "real new run exists before stale replay")
	handler.call()
	_check(app._sewing_context() == before and service.read_state() == source
		and app.patch_stall_view == null and app.patch_stall_service == null,
		"old open binding cannot affect new run or revive old visit")
	app._return_to_title()
	app.free()
	await _frames()


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
