extends "res://tests/live_m04_event_wallet_batch_test.gd"
## Genuine six-Event mounted Inkblack service: paid Event and its one-use
## Unpicker share the fifth chosen node, with no additional route or RNG draw.

const INKBLACK := "v3_inkblack_unpicker_van"


func _open_inkblack(fixture: Dictionary, gold: int = 100) -> LiveEventChoicePanel:
	_pre_transit_gold = gold
	await _reach(fixture)
	_pre_transit_gold = -1
	# Funding is installed before the last guarded transit binds its real ledger.
	var route: Array = app.run_map.get_route()
	var before_rng: int = app.run_rng.state
	var route_button := _route_action(fixture.path[4])
	_check(is_instance_valid(route_button) and not route_button.disabled,
		"genuine seeded fifth Event has a physical connected route control")
	if not is_instance_valid(route_button):
		return null
	await _click(route_button)
	var panel: LiveEventChoicePanel = app.wallet_event_panel
	_check(is_instance_valid(panel) and app.run_map.get_route() == route + [fixture.path[4]]
		and app.run_rng.state == fixture.after_draw and before_rng == fixture.before_draw
		and app.run_map.get_node(fixture.path[4]).type == "Event",
		"seeded map and real fifth Event consume exactly the independent draw")
	if not is_instance_valid(panel):
		return null
	var record := panel._selector.get_event()
	_check(record.id == INKBLACK and app._wallet_event_history == [INKBLACK]
		and app._emberglass_gate != null and app._emberglass_gate.is_valid()
		and app._emberglass_gate.get_event() == record
		and panel.get_choice_buttons().size() == 3
		and record.choices[0].id == "hire_unpicker"
		and record.choices[1].id == "sell_trim"
		and record.choices[2].id == "leave",
		"mounted parchment binds three canonical choices to one unclaimed service gate")
	for index in range(3):
		_check(panel._bound_choices.get(panel.get_choice_buttons()[index]) == record.choices[index].id
			and panel.get_choice_buttons()[index].text.contains(record.choices[index].text),
			"each physical ticket is bound to its exact authored ID and caption")
	return panel


func _unpicker_state() -> Array:
	return [app._sewing_context(), app._wallet_event_history.duplicate(),
		app._inkblack_unpicker_auth.duplicate(), app._unpicker_closed,
		app._unpicker_source.duplicate(true), app._unpicker_visits.duplicate(true),
		app.unpicker_visit.read_state() if app.unpicker_visit != null else {},
		app.unpicker_view, app.wallet_event_panel, app.route_view]


func _reject_unpicker(callback: Callable, reason: String) -> void:
	var before := _unpicker_state()
	callback.call()
	_check(_unpicker_state() == before, reason + " preserves service, wallet, map, route and RNG")


func _pay(fixture: Dictionary, keyboard: bool, remove: bool) -> Array:
	var panel := await _open_inkblack(fixture)
	if panel == null:
		return []
	var wallet := _wallet()
	var before_route: Array = app.run_map.get_route()
	var before_rng: int = app.run_rng.state
	var original_deck: Array[String] = app.run_deck.duplicate()
	_check(wallet.gold == 100 and not panel.get_choice_buttons()[0].disabled,
		"funded hire is physically enabled with a real owned deck")
	var old_commit: Callable = panel.wallet_choice_committed.get_connections()[0].callable
	_reject_wallet(old_commit.bind({"ok": true, "event_id": INKBLACK, "choice_id": "hire_unpicker",
		"wallet": {"gold": 90, "scraps": 0}}), "unclaimed forged paid signal")
	if keyboard:
		panel.get_choice_buttons()[0].grab_focus()
		await _key(KEY_1)
	else:
		await _click(panel.get_choice_buttons()[0])
	var node_id: String = fixture.path[4]
	_check(app.wallet_event_panel == null and is_instance_valid(app.unpicker_view)
		and app.unpicker_view.is_visible_in_tree() and app.unpicker_visit.is_valid()
		and app.unpicker_visit.read_state() == app._unpicker_source
		and app._unpicker_source.gold == 90
		and app.run_map.get_current_node_id() == node_id
		and app._inkblack_unpicker_active(node_id) and app._inkblack_unpicker_auth[5].is_claimed()
		and app.run_map.get_route() == before_route and app.run_rng.state == before_rng
		and _wallet() == {"gold": 90, "scraps": wallet.scraps}
		and not app._can_choose_connected_route(),
		"one real paid callback mounts existing Unpicker on same Event with one 10-gold debit")
	if not is_instance_valid(app.unpicker_view):
		return []
	var before := _unpicker_state()
	old_commit.call({"ok": true, "event_id": INKBLACK, "choice_id": "hire_unpicker",
		"wallet": {"gold": 90, "scraps": wallet.scraps}})
	_check(_unpicker_state() == before, "paid Event callback replay cannot mount or charge again")
	var view: LiveUnpickerPanel = app.unpicker_view
	_check(view.card_buttons.size() > 0 and not view.leave_button.disabled
		and view.wallet_label.text == "Wallet: 90 gold    •    Remove: 75 gold"
		and view._source.deck == original_deck, "service preserves quoted typed Unpicker pricing")
	var decision: Callable = view.decision_requested.get_connections()[0].callable
	var source_snapshot: Dictionary = app._unpicker_source.duplicate(true)
	var forged := {"action": "leave", "visit_id": source_snapshot.visit_id,
		"node_id": source_snapshot.node_id, "expected_snapshot": source_snapshot}
	var invalid := forged.duplicate(true)
	invalid.visit_id = "forged"
	_reject_unpicker(decision.bind(invalid), "forged Unpicker visit identity")
	var retained := view._submitted
	view._submitted = true
	_check(view._submitted and view._visit == app.unpicker_visit and view.is_visible_in_tree(),
		"stale-input checks reach a genuinely bound and submitted live Unpicker")
	_reject_unpicker(decision.bind(invalid), "submitted forged Unpicker visit identity")
	app.run_rng.state += 1
	_reject_unpicker(decision.bind(forged), "drifted Unpicker RNG")
	app.run_rng.state -= 1
	var captured: Dictionary = app._sewing_context()
	var route: Array = app.run_map._route.duplicate()
	app.run_map._route.pop_back()
	_reject_unpicker(decision.bind(forged), "drifted Unpicker route")
	app.run_map._route.assign(route)
	var revision: int = app.run_map._generation_revision
	app.run_map._generation_revision += 1
	_reject_unpicker(decision.bind(forged), "drifted Unpicker generation authority")
	app.run_map._generation_revision = revision
	var auth_node: String = app._inkblack_unpicker_auth[4]
	app._inkblack_unpicker_auth[4] = "forged_node"
	_reject_unpicker(decision.bind(forged), "forged claimed Event gate node")
	app._inkblack_unpicker_auth[4] = auth_node
	_check(app._sewing_context() == captured, "route and authority restored before actual decision")
	view._submitted = retained
	if remove:
		_check(not view.card_buttons.is_empty(), "paid Remove has a genuine held card row")
		if view.card_buttons.is_empty():
			return []
		await _click(view.card_buttons[0])
		_check(not view.remove_button.disabled and not view._selected_id.is_empty(),
			"real Remove is selectable with 90 gold after hiring")
		if keyboard:
			view.remove_button.grab_focus()
			await _key(KEY_1)
		else:
			await _click(view.remove_button)
	else:
		if keyboard:
			view.leave_button.grab_focus()
			await _key(KEY_0)
		else:
			await _click(view.leave_button)
	var expected_gold := 15 if remove else 90
	_check(app._unpicker_closed and not app.unpicker_view.visible
		and is_instance_valid(app.route_view) and app._can_choose_connected_route()
		and app.run_map.get_route() == before_route and app.run_rng.state == before_rng
		and app.session_gold == expected_gold and app.run_scraps == wallet.scraps
		and app.run_removal_count == (1 if remove else 0)
		and app.run_deck.size() == original_deck.size() - (1 if remove else 0)
		and app._unpicker_visits.has(node_id),
		"real Remove/Leave settles typed receipt once and reconnects legal Event route")
	var result := [_wallet(), app.run_deck.duplicate(), app.run_removal_count,
		app.run_map.get_route(), str(app.run_rng.state)]
	_reject_unpicker(decision.bind(forged), "replayed old Unpicker decision")
	await _traverse_treasures(fixture, fixture.next)
	var next_button := _route_action(fixture.next)
	_check(is_instance_valid(next_button) and not next_button.disabled,
		"service completion exposes the true connected successor")
	if is_instance_valid(next_button):
		await _click(next_button)
		var rng := RandomNumberGenerator.new()
		rng.state = before_rng
		var event_id := _vital_selection_id(rng)
		_check(is_instance_valid(app.wallet_event_panel)
			and app.wallet_event_panel._selector.get_event().id == event_id
			and app.run_rng.state == rng.state,
			"next Event uses only its own ordinary seeded draw after service")
		result.append([event_id, str(app.run_rng.state)])
		var next_panel: LiveEventChoicePanel = app.wallet_event_panel
		var next_action: Button = null
		if is_instance_valid(next_panel):
			for button in next_panel.get_choice_buttons():
				if not button.disabled:
					next_action = button
					break
		_check(is_instance_valid(next_action), "connected vitality Event offers a funded physical choice")
		if is_instance_valid(next_action):
			await _click(next_action)
			_check(app.wallet_event_panel == null and app._can_choose_connected_route()
				and app.run_rng.state == rng.state,
				"settled successor reconnects after Inkblack and consumes no extra draw")
	await _return_title()
	_check(app._inkblack_unpicker_auth.is_empty(), "title return retires Event service authority")
	return result


func _trade_leave(fixture: Dictionary, choice: int) -> void:
	var panel := await _open_inkblack(fixture, 0)
	if panel == null:
		return
	var wallet := _wallet()
	var rng: int = app.run_rng.state
	var route: Array = app.run_map.get_route()
	var action := panel.get_choice_buttons()[choice]
	var earlier_unpicker = app.unpicker_view
	var earlier_source: Dictionary = app._unpicker_source.duplicate(true)
	_check(not action.disabled, "non-service choice physically offered")
	await _click(action)
	_check(app.wallet_event_panel == null and app._inkblack_unpicker_auth.is_empty()
		and app.unpicker_view == earlier_unpicker and app._unpicker_source == earlier_source,
		"non-service Event retires parchment without touching earlier typed Unpicker")
	_check(app.run_rng.state == rng and app.run_map.get_route() == route
		and _wallet() == {"gold": wallet.gold, "scraps": wallet.scraps + (1 if choice == 1 else 0)},
		"non-service choice publishes exact wallet without route or RNG draw")
	_check(app._can_choose_connected_route(),
		"non-service choice resumes connected route without any service authority")
	await _return_title()


func _unfunded_and_pending(fixture: Dictionary) -> void:
	var panel := await _open_inkblack(fixture, 0)
	if panel == null:
		return
	_check(_wallet().gold == 0 and panel.get_choice_buttons()[0].disabled,
		"zero-gold wallet cannot afford the 10-gold hire")
	var before := _wallet_state()
	var earlier_unpicker = app.unpicker_view
	var earlier_source: Dictionary = app._unpicker_source.duplicate(true)
	await _click(panel.get_choice_buttons()[0])
	await _key(KEY_1)
	panel.get_choice_buttons()[0].pressed.emit()
	_check(_wallet_state() == before and not panel._selector.is_claimed(),
		"unfunded mouse/key/signal cannot mutate wallet, route or RNG")
	_check(app._emberglass_gate.is_valid() and app._inkblack_unpicker_auth.is_empty()
		and app.unpicker_view == earlier_unpicker and app._unpicker_source == earlier_source,
		"unfunded events keep unclaimed gate and cannot replace prior typed Unpicker")
	await _click(panel.get_choice_buttons()[2])
	await _return_title()
	panel = await _open_inkblack(fixture)
	if panel == null:
		return
	var commit: Callable = panel.wallet_choice_committed.get_connections()[0].callable
	var receipt := RunEventChoice.new(panel._selector.get_event()).choose_with_wallet("hire_unpicker", _wallet())
	_check(receipt.ok, "independent authentic paid receipt exists for pending-claim checks")
	panel.wallet_choice_committed.disconnect(commit)
	await _click(panel.get_choice_buttons()[0])
	_check(panel._selector.is_claimed() and panel._committed_choice == receipt,
		"real physical claim stages the pending service receipt")
	var fake := receipt.duplicate(true)
	fake.wallet.gold += 1
	_reject_wallet(commit.bind(fake), "forged pending wallet receipt")
	panel._committed_choice = fake
	_reject_wallet(commit.bind(fake), "forged mounted receipt")
	panel._committed_choice = receipt
	for field in ["session_gold", "run_removal_count", "run_next_stitch_id", "run_seed"]:
		var original: int = app.get(field)
		app.set(field, original + 1)
		_reject_wallet(commit.bind(receipt), "stale " + field)
		app.set(field, original)
	var route: Array = app.run_map._route.duplicate()
	app.run_map._route.pop_back()
	_reject_wallet(commit.bind(receipt), "stale physical route")
	app.run_map._route.assign(route)
	var rng: int = app.run_rng.state
	app.run_rng.state += 1
	_reject_wallet(commit.bind(receipt), "stale pre-commit RNG")
	app.run_rng.state = rng
	var map: RunMap = app.run_map
	var foreign := RunMap.new()
	var foreign_rng := RandomNumberGenerator.new()
	foreign_rng.seed = fixture.seed
	foreign.generate(foreign_rng)
	app.run_map = foreign
	_reject_wallet(commit.bind(receipt), "foreign map")
	app.run_map = map
	commit.call(receipt)
	_check(app._inkblack_unpicker_active(fixture.path[4]) and app.session_gold == 90,
		"restored authentic claim still pays and opens the existing Unpicker")
	_reject_unpicker(commit.bind(receipt), "second paid receipt")
	await _click(app.unpicker_leave_button)
	await _return_title()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	var fixtures := _fixtures()
	var fixture: Dictionary = fixtures.get(INKBLACK, {})
	_check(not fixture.is_empty(), "independent sorted-pool oracle finds genuine seeded six-Event Inkblack route")
	if not fixture.is_empty():
		print("INKBLACK_WITNESS_SEED=", fixture.seed)
		var mouse := await _pay(fixture, false, true)
		var keyboard := await _pay(fixture, true, true)
		_check(not mouse.is_empty() and mouse == keyboard,
			"paid Remove replays identically for physical mouse and keyboard")
		await _pay(fixture, false, false)
		await _trade_leave(fixture, 1)
		await _trade_leave(fixture, 2)
		await _unfunded_and_pending(fixture)
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_v3_inkblack_unpicker_route_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
