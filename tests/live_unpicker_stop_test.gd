extends "res://tests/live_sewing_circle_stop_test.gd"


func _unpicker_intent(action: String = "remove_card") -> Dictionary:
	var source: Dictionary = app._unpicker_source
	var intent := {"action": action, "visit_id": source.visit_id,
		"node_id": source.node_id, "expected_snapshot": source.duplicate(true)}
	if action == "remove_card":
		intent.selected_card_id = app.unpicker_view._selected_id
	return intent


func _held_request() -> Callable:
	var panel: LiveUnpickerPanel = app.unpicker_view
	var listener: Callable = panel.decision_requested.get_connections()[0].callable
	var intent := _unpicker_intent()
	# Exercise controller preflight with a submitted, source-authenticated payload.
	return func():
		var submitted := panel._submitted
		panel._submitted = true
		listener.call(intent)
		panel._submitted = submitted


func _unpicker_state() -> Array:
	return [app._sewing_context(), app.act_outcome.get_state(), app.unpicker_visit.read_state(),
		app._unpicker_source.duplicate(true), app._unpicker_closed, app._unpicker_visits.duplicate(true)]


func _reject_action(callback: Callable, reason: String) -> void:
	var before := _unpicker_state()
	callback.call()
	_check(_unpicker_state() == before, reason + " preserves run, visit, route and RNG")


func _reject_number(code: Key, reason: String, changes: Dictionary = {}) -> void:
	var panel: LiveUnpickerPanel = app.unpicker_view
	var emissions := {"count": 0}
	var observe := func(_intent): emissions.count += 1
	panel.decision_requested.connect(observe)
	var before := _unpicker_state()
	var submitted := panel._submitted
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	for property in changes:
		event.set(property, changes[property])
	root.push_input(event, true)
	await _frames()
	_check(_unpicker_state() == before and panel._submitted == submitted
		and emissions.count == 0, reason + " emits nothing and preserves complete state")
	panel.decision_requested.disconnect(observe)


func _number_guards() -> void:
	var panel: LiveUnpickerPanel = app.unpicker_view
	panel.card_buttons[0].grab_focus()
	_check(panel._selected_id != "" and panel.card_buttons[0].has_focus(),
		"number guard fixture owns a real selection and panel focus")
	for code in [KEY_1, KEY_KP_1, KEY_0, KEY_KP_0]:
		for changes in [{"echo": true}, {"pressed": false}, {"ctrl_pressed": true},
			{"alt_pressed": true}, {"shift_pressed": true}, {"meta_pressed": true}]:
			await _reject_number(code, "echo/release/modified number", changes)
		var action := panel.remove_button if code in [KEY_1, KEY_KP_1] else panel.leave_button
		var disabled := action.disabled
		action.disabled = true
		await _reject_number(code, "disabled number action")
		action.disabled = disabled
		action.hide()
		panel.card_buttons[0].grab_focus()
		await _reject_number(code, "hidden number action")
		action.show()
		panel.hide()
		await _reject_number(code, "hidden panel number")
		panel.show()
		var outside := Button.new()
		app.add_child(outside)
		outside.grab_focus()
		_check(outside.has_focus(), "focus belongs outside Unpicker")
		await _reject_number(code, "unfocused panel number")
		outside.free()
		panel.card_buttons[0].grab_focus()
	var old_remove: Callable = panel.remove_button.pressed.get_connections()[0].callable
	var old_leave: Callable = panel.leave_button.pressed.get_connections()[0].callable
	panel.bind(null)
	for code in [KEY_1, KEY_KP_1, KEY_0, KEY_KP_0]:
		await _reject_number(code, "invalid rebound source")
	panel.bind(app.unpicker_visit)
	_reject_action(old_remove, "old Remove callback after rebind")
	_reject_action(old_leave, "old Leave callback after rebind")
	_check(panel._selected_id.is_empty() and panel.remove_button.disabled,
		"valid rebind clears selection and disables Remove")
	for code in [KEY_1, KEY_KP_1]:
		await _reject_number(code, "rebound no-selection Remove")
	await _click(panel.card_buttons[0])


func _number_key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _negative_actions() -> void:
	var callback := _held_request()
	var original: Dictionary = app._sewing_context()
	var was_disabled: bool = app.unpicker_remove_button.disabled
	app.unpicker_remove_button.disabled = true
	_reject_action(app.unpicker_remove_button.pressed.get_connections()[0].callable, "disabled control")
	app.unpicker_remove_button.disabled = false
	app.unpicker_view.hide()
	_reject_action(callback, "hidden visit")
	app.unpicker_view.show()
	var wallet_text: String = app.unpicker_view.wallet_label.text
	app.unpicker_view.wallet_label.text = "forged quote"
	_reject_action(callback, "drifted displayed wallet")
	app.unpicker_view.wallet_label.text = wallet_text
	var rng_identity = app.run_rng
	app.run_rng = RandomNumberGenerator.new()
	app.run_rng.state = rng_identity.state
	_reject_action(callback, "foreign RNG identity")
	app.run_rng = rng_identity
	app.run_heroes[0].hp -= 1
	_reject_action(callback, "drifted roster")
	app.run_heroes = original.heroes.duplicate(true)
	var carry = app.party_carryover
	app.party_carryover = RunTornCarryover.new(app.run_heroes)
	_reject_action(callback, "foreign carry identity")
	app.party_carryover = carry
	var map = app.run_map
	var foreign := RunMap.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = fixture.seed
	foreign.generate(rng)
	app.run_map = foreign
	_reject_action(callback, "foreign map identity")
	app.run_map = map
	map._generation_revision += 1
	_reject_action(callback, "regenerated map")
	map._generation_revision -= 1
	map._route.append(fixture.next)
	_reject_action(callback, "advanced route")
	map._route.pop_back()
	app.run_rng.randi()
	_reject_action(callback, "advanced RNG")
	app.run_rng.state = original.rng_state
	app.run_deck.append("forged")
	_reject_action(callback, "drifted deck")
	app.run_deck.pop_back()
	var fake := LiveUnpickerPanel.new()
	app.unpicker_view.add_child(fake)
	_reject_action(app._unpicker_decision.bind(_unpicker_intent(), fake, app.unpicker_visit), "forged control")
	fake.free()
	app.unpicker_visit._gold += 1
	_reject_action(callback, "forged service wallet")
	app.unpicker_visit._gold -= 1
	app.unpicker_remove_button.disabled = was_disabled
	_check(app._sewing_context() == original, "negative fixtures restore exact authority")



func _unpicker_fixture(stitched: bool) -> Dictionary:
	for value in range(1, 12000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for first in map.get_legal_choices():
			if stitched and map.get_node(first).type != "SewingCircle":
				continue
			var seconds: Array = map.get_node(first).outgoing if stitched else [first]
			for second in seconds:
				if stitched and map.get_node(second).type != "SewingCircle":
					continue
				var candidates: Array = map.get_node(second).outgoing if stitched else [first]
				for id in candidates:
					if map.get_node(id).type != "Unpicker":
						continue
					for next in map.get_node(id).outgoing:
						if map.get_node(next).type == "Fight":
							return {"seed": value, "first": first, "second": second, "id": id, "next": next}
	return {}


func _unpicker_boot(stitched: bool, funded: bool) -> void:
	fixture = _unpicker_fixture(stitched)
	_check(not fixture.is_empty(), "genuine seeded Unpicker and onward Fight witness")
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = fixture.seed
	await _click(app.start_button)
	preload("res://tests/party_choice.gd").choose(app)
	await _frames()
	if funded:
		app.session_gold = 100
		app.run_scraps = 10
		root.get_node("LiveWebPlaytestBoot")._preview_map = weakref(app.run_map)
	var carry: RunTornCarryover = app.party_carryover
	var wardrobe := RunPatchWardrobe.new(app.run_heroes, app.run_trinkets, [],
		app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
	_check(wardrobe.is_valid() and carry.bind_wardrobe(wardrobe, carry.torn, wardrobe.get_snapshot()), "coherent real wardrobe bound")
	app._clear_route_view()
	app._present_connected_route(weakref(app.run_map))
	await _frames()
	if stitched:
		var stitch_number := 0
		for sewing_id in [fixture.first, fixture.second]:
			stitch_number += 1
			await _click(_button(sewing_id))
			await _frames()
			_check(app.sewing_view != null and app.sewing_stitch_button.disabled == false, "real sewing visit permits authentic stitch")
			var panel: LiveSewingCirclePanel = app.sewing_view
			await _activate(panel.stitch_button, false)
			var first: int = panel.option_buttons[0].get_meta("option").index
			var first_owner: String = RunRestStitchCards.resolve_card_definition(app.run_deck[first]).owner
			await _activate(panel.option_buttons[0], false)
			_check(not panel.option_buttons.is_empty(), "authentic different-owner stitch pair exists")
			var second: int = panel.option_buttons[0].get_meta("option").index
			_check(RunRestStitchCards.resolve_card_definition(app.run_deck[second]).owner != first_owner,
				"real panel offers a different owner's occurrence")
			await _activate(panel.option_buttons[0], false)
			_check(not app._sewing_closed and not panel.confirm_button.disabled, "stitch preview requires confirmation")
			await _activate(panel.confirm_button, false)
			await _frames()
			_check(app.run_stitch_descriptors.size() == stitch_number and app.run_next_stitch_id == stitch_number + 1 and app._can_choose_connected_route(), "mounted Sewing commits authentic owned stitch")


func _enter_unpicker(atlas: bool) -> void:
	var route := _button(fixture.id)
	_check(route != null and not route.disabled and route.text == "Unpicker", "distinct genuine Unpicker action")
	var callback: Callable = route.pressed.get_connections()[0].callable
	var before: Dictionary = app._sewing_context()
	app.session_gold += 1
	callback.call()
	_check(app.unpicker_visit == null and app.run_map.get_route() == before.route, "stale route wallet rejected before advance")
	app.session_gold -= 1
	var fake := Button.new()
	app.route_view.add_child(fake)
	fake.set_meta("route_id", fixture.id)
	fake.set_meta("route_kind", "Unpicker")
	fake.set_meta("sewing_source", before)
	_check(not app._choose_unpicker_route(fixture.id, weakref(app.run_map), app.run_map.get_route(), fake)
		and app._sewing_context() == before, "forged held route button rejected")
	fake.free()
	if atlas:
		await _click(app.route_map_button)
		var captured: Callable = app.route_atlas.node_requested.get_connections()[0].callable
		var overlay = app.route_atlas_overlay
		app.session_gold += 1
		captured.call(fixture.id)
		_check(app.unpicker_visit == null and app.route_atlas_overlay == overlay, "stale atlas callback retains chooser")
		app.session_gold -= 1
		var marker: Button = app.route_atlas.get_node("Node_" + fixture.id + "/Action")
		_check(marker.tooltip_text.contains("Remove one owned card for 75 gold plus 25 per previous removal, or leave unchanged"), "truthful gold-only help")
		marker.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(route)
	await _frames()
	_check(app.unpicker_view != null and app.unpicker_view.is_visible_in_tree()
		and app.run_map.get_route() == before.route + [fixture.id], "physical choice enters exactly one Unpicker")
	_check(app.unpicker_visit.read_state() == app._unpicker_source and app._unpicker_source.deck == before.deck, "visit binds exact deck source")
	_check(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(app.unpicker_view.get_global_rect()), "compact visit fits viewport")
	var panel: LiveUnpickerPanel = app.unpicker_view
	_check(panel.remove_button.text == "1 Remove" and panel.leave_button.text == "0 Leave · free"
		and panel.remove_button.is_visible_in_tree() and panel.leave_button.is_visible_in_tree(),
		"mounted action captions advertise number shortcuts and free Leave")
	_check(panel.position == Vector2(200, 60) and panel.size == Vector2(880, 600)
		and panel.remove_button.size == Vector2(390, 62) and panel.leave_button.size == Vector2(400, 62),
		"shortcut captions retain authored panel and action geometry")
	_check(panel.wallet_label.text.contains("Wallet: %d gold" % before.gold)
		and panel.wallet_label.text.contains("Remove: %d gold" % (75 + 25 * before.removals)),
		"sewn panel displays authentic wallet and escalating quote")
	var ids: Array[String] = []
	for id in before.deck:
		if not ids.has(id):
			ids.append(id)
	_check(not ids.is_empty() and panel.card_buttons.size() == ids.size(), "canonical first-occurrence tiles include duplicates only once")
	for i in range(ids.size()):
		_check(panel._rows[panel.card_buttons[i]].id == ids[i]
			and panel._rows[panel.card_buttons[i]].first == before.deck.find(ids[i]),
			"tile maps to exact first owned occurrence")
	_check(panel.choice_scroll.is_visible_in_tree() and panel.choice_scroll.get_v_scroll_bar().visible,
		"owned cards have a visible scroll")
	panel.card_buttons[0].grab_focus()
	_check(panel.card_buttons[0].has_focus() and panel._selected_id.is_empty()
		and panel.remove_button.disabled, "real unselected row owns GUI focus")
	for code in [KEY_1, KEY_KP_1]:
		await _reject_number(code, "no-selection number Remove")
	await _activate(panel.card_buttons[0], atlas)


func _unpicker_scenario(stitched: bool, funded: bool, remove: bool, keyboard: bool, shortcut: int = 0) -> Array:
	await _unpicker_boot(stitched, funded)
	await _enter_unpicker(keyboard)
	if shortcut == 1:
		await _number_guards()
	await _negative_actions()
	var callback := _held_request()
	var original: Dictionary = app._sewing_context()
	# Numeric, descriptor and selector drift must fail without consuming the visit.
	for field in ["session_gold", "run_removal_count", "run_next_stitch_id", "run_seed"]:
		var value: int = app.get(field)
		app.set(field, value + 1)
		_reject_action(callback, "changed " + field)
		app.set(field, value)
	var first_tile: Button = app.unpicker_view.card_buttons[0]
	var caption := first_tile.text
	first_tile.text = "forged occurrence"
	_reject_action(callback, "forged tile occurrence")
	first_tile.text = caption
	if stitched:
		var descriptor_id: String = app.run_stitch_descriptors.keys()[0]
		var descriptor: Dictionary = app.run_stitch_descriptors[descriptor_id].duplicate(true)
		app.run_stitch_descriptors[descriptor_id]["display_name"] = "drifted stitch"
		_reject_action(callback, "changed stitch descriptor")
		app.run_stitch_descriptors[descriptor_id] = descriptor
	var service = app.unpicker_visit
	app.unpicker_visit = RunUnpickerVisit.new(fixture.id, app.run_deck, app.session_gold, app.run_removal_count, app.run_stitch_descriptors, app.run_next_stitch_id)
	_reject_action(callback, "foreign service identity")
	app.unpicker_visit = service
	if not funded:
		_check(app.unpicker_remove_button.disabled and not app.unpicker_leave_button.disabled, "inadequate wallet leaves Leave available")
		_reject_action(callback, "unaffordable removal")
		app.unpicker_remove_button.disabled = false
		_reject_action(callback, "forced unaffordable action still refuses")
		for code in [KEY_1, KEY_KP_1]:
			await _reject_number(code, "forced enabled short-wallet number Remove")
		app.unpicker_remove_button.disabled = true
		for code in [KEY_1, KEY_KP_1]:
			await _reject_number(code, "short-wallet number Remove")
	var panel: LiveUnpickerPanel = app.unpicker_view
	var selected := 0
	if stitched:
		var stitch_id: String = app.run_stitch_descriptors.keys()[0]
		for i in range(panel.card_buttons.size()):
			if panel._rows[panel.card_buttons[i]].id == stitch_id:
				selected = i
	var tile: Button = panel.card_buttons[selected]
	panel.choice_scroll.ensure_control_visible(tile)
	await _frames()
	await _activate(tile, keyboard)
	var expected_card_id := str(panel._rows[tile]["id"])
	var price: int = RunShopCardRemoval.BASE_PRICE + RunShopCardRemoval.PRICE_STEP * int(app.run_removal_count)
	var forecast_gold := -1
	if funded:
		var run_deck := app.run_deck as Array
		forecast_gold = app.session_gold - price
		var chosen_copies: int = run_deck.count(expected_card_id)
		_check(panel.status_label.text.contains(panel._card_name(expected_card_id))
				and panel.status_label.text.contains("first of %d %s" % [
						chosen_copies, "copy" if chosen_copies == 1 else "copies"])
				and panel.status_label.text.contains("deck %d→%d" % [run_deck.size(), run_deck.size() - 1])
				and panel.status_label.text.contains("gold %d→%d (%d cost)" % [
						app.session_gold, forecast_gold, price]),
				"visible panel preview agrees with run_deck, wallet and prior removals in live route")
	else:
		_check(panel.status_label.text.contains("Need %d more gold" % (price - app.session_gold)),
				"selected unaffordable live visit keeps the honest shortfall hint")
	if funded:
		panel.card_buttons.back().grab_focus()
		await _key(KEY_TAB)
		_check(app.unpicker_remove_button.has_focus(), "Tab reaches Remove from owned-card tiles")
		await _key(KEY_TAB)
		_check(app.unpicker_leave_button.has_focus(), "Tab reaches Leave")
		await _key(KEY_TAB)
		_check(panel.card_buttons[0].has_focus(), "Tab cycles to first tile")
	var source: Dictionary = app.unpicker_visit.read_state()
	var oracle := RunUnpickerVisit.new(fixture.id, app.run_deck, app.session_gold, app.run_removal_count, app.run_stitch_descriptors, app.run_next_stitch_id)
	_check(oracle.is_valid() and oracle.read_state()["visit_id"] != source.visit_id
		and not oracle.read_state()["visit_id"].is_empty(),
		"independent same-ledger instance owns a distinct fresh visit identity")
	var oracle_source: Dictionary = oracle.read_state()
	var card: String = panel._rows[tile].id
	var expected := oracle.remove_card(card, oracle_source.visit_id, fixture.id, oracle_source) if remove else oracle.leave(oracle_source.visit_id, fixture.id, oracle_source)
	_check(expected.ok, "independent real service accepts intended decision")
	var action: Button = app.unpicker_remove_button if remove else app.unpicker_leave_button
	var saved: Callable = action.pressed.get_connections()[0].callable
	var listener: Callable = panel.decision_requested.get_connections()[0].callable
	var saved_intent := _unpicker_intent("remove_card" if remove else "leave")
	_reject_action(listener.bind(saved_intent), "direct intent before physical submission")
	panel._submitted = true
	for bad in [{"action": "unknown"}, {"node_id": "foreign"}, {"visit_id": "forged"},
		{"expected_snapshot": {}}, {"extra": true}, {"selected_card_id": "unowned"}]:
		var forged := saved_intent.duplicate(true)
		for key in bad:
			forged[key] = bad[key]
		_reject_action(listener.bind(forged), "forged payload " + str(bad.keys()))
	var oracle_intent := {"action": "remove_card" if remove else "leave",
		"visit_id": oracle_source.visit_id, "node_id": fixture.id,
		"expected_snapshot": oracle_source.duplicate(true)}
	if remove:
		oracle_intent["selected_card_id"] = card
	_reject_action(listener.bind(oracle_intent), "same-ledger independent visit intent")
	if remove:
		var alternate: String = panel._rows[panel.card_buttons[1]].id
		if alternate == card:
			alternate = panel._rows[panel.card_buttons[0]].id
		_check(alternate != card and app.run_deck.has(alternate), "alternate forged selection is genuinely owned")
		var swapped := saved_intent.duplicate(true)
		swapped.selected_card_id = alternate
		_reject_action(listener.bind(swapped), "owned but unselected card")
	panel._submitted = false
	var emissions := {"count": 0}
	panel.decision_requested.connect(func(_intent): emissions.count += 1)
	if shortcut != 0:
		tile.grab_focus()
		_check(tile.has_focus() and not action.disabled and action.is_visible_in_tree(),
			"real selected row owns focus and intended shortcut action is enabled")
		await _number_key((KEY_1 if remove else KEY_0) if shortcut == 1 else (KEY_KP_1 if remove else KEY_KP_0))
	elif keyboard:
		action.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(action)
	await _frames()
	_check(emissions.count == 1, "physical action emits exactly one connected decision")
	_check(app._unpicker_closed and not app.unpicker_view.visible and app._can_choose_connected_route(), "decision closes once and permits onward routing")
	var live_after: Dictionary = app.unpicker_visit.read_state()
	var oracle_after: Dictionary = oracle.read_state()
	_check(live_after.visit_id != oracle_after.visit_id, "live and independent instances keep distinct visit identities")
	for field in ["valid", "consumed", "node_id", "deck", "descriptors", "gold",
		"prior_removals", "next_stitch_id", "price", "receipt"]:
		_check(live_after[field] == oracle_after[field],
			"mounted service matches independent receipt field " + field)
	_check(app.run_deck == expected.deck and app.session_gold == expected.gold and app.run_removal_count == expected.prior_removals
		and app.run_stitch_descriptors == expected.descriptors and app.run_next_stitch_id == expected.next_stitch_id, "all five receipt fields commit together")
	if remove:
		var remaining: Array = original.deck.duplicate()
		remaining.remove_at(remaining.find(card))
		_check(app.run_deck == remaining, "only the first selected occurrence is removed in exact deck order")
		_check(app.run_deck.size() == original.deck.size() - 1 and app.session_gold == original.gold - 75 - 25 * original.removals
			and app.run_removal_count == original.removals + 1, "one actual occurrence removed and exact escalating debit")
		if forecast_gold >= 0:
			_check(app.session_gold == forecast_gold,
				"authoritative purchase lands on exactly the previewed wallet")
		if stitched:
			_check(not app.run_stitch_descriptors.has(card) and app.run_next_stitch_id == original.cursor, "authentic descriptor retired without cursor reuse")
			_check(original.descriptors.size() == 2 and app.run_stitch_descriptors.size() == 1, "real second stitched descriptor survives")
			for survivor in app.run_stitch_descriptors:
				_check(app.run_stitch_descriptors[survivor] == original.descriptors[survivor], "surviving authentic stitch is identical")
	else:
		_check(app._sewing_context() == original, "Leave retains complete ledger and RNG")
	_check(app.run_rng.state == original.rng_state and app.run_scraps == original.scraps, "service spends no scraps or RNG")
	var wardrobe: Dictionary = app.party_carryover._wardrobe.get_snapshot()
	_check(wardrobe.cards == app.run_deck and wardrobe.gold == app.session_gold, "connected-map wardrobe stays synchronized")
	_reject_action(saved, "replayed consumed callback")
	_reject_action(listener.bind(saved_intent), "stale intent after panel closure")
	for code in [KEY_1, KEY_KP_1, KEY_0, KEY_KP_0]:
		await _reject_number(code, "closed panel number")
	var witness: Array = app._unpicker_visits[fixture.id]
	app._unpicker_visits.erase(fixture.id)
	_check(not app._can_choose_connected_route(), "closure witness required")
	app._unpicker_visits[fixture.id] = witness
	var replay: Array = [app.run_map.get_floors(), app.run_map.get_route(), app.run_deck.duplicate(), app.session_gold, app.run_stitch_descriptors.duplicate(true), app.run_rng.state]
	var next := _button(fixture.next)
	_check(next != null and not next.disabled, "actual onward Fight control exists")
	await _click(next)
	await _frames()
	_check(app.deck != null and app.run_map.get_route().back() == fixture.next, "legal onward Fight starts")
	_reject_action(saved, "old callback after onward Fight")
	_reject_action(listener.bind(saved_intent), "stale intent after onward Fight")
	replay.append(app.deck.hand.duplicate())
	replay.append(app.run_rng.state)
	app._return_to_title()
	await _frames()
	_check(app.unpicker_view == null and app.unpicker_visit == null and app._unpicker_source.is_empty()
		and app._unpicker_original.is_empty() and app._unpicker_visits.is_empty(), "Return clears visit and witnesses")
	_check(not saved.is_valid(), "title frees panel-owned action callback")
	listener.call(saved_intent)
	_check(app.run_map == null and app.unpicker_visit == null, "title rejects retained callback")
	app.free()
	await _frames()
	return replay


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for scenario in [[false, true, true], [true, true, true], [false, false, false], [false, true, false], [true, true, false]]:
		var mouse := await _unpicker_scenario(scenario[0], scenario[1], scenario[2], false)
		var keyboard := await _unpicker_scenario(scenario[0], scenario[1], scenario[2], true)
		_check(not mouse.is_empty() and mouse == keyboard, "same seed mouse and atlas/keyboard replay")
		var main := await _unpicker_scenario(scenario[0], scenario[1], scenario[2], false, 1)
		var keypad := await _unpicker_scenario(scenario[0], scenario[1], scenario[2], true, 2)
		_check(not main.is_empty() and main == keypad and main == mouse,
			"same quoted transaction mouse, Enter, main number and keypad replay")
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_unpicker_stop_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
