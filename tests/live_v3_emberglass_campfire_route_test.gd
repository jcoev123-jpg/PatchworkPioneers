extends "res://tests/live_m04_event_wallet_batch_test.gd"
## Mounted seeded six-Event witness: the actual fifth ticket pays for the
## existing Campfire on the committed Event node, never a preview/second route.

const EMBER := "v3_emberglass_campfire"


func _open_ember(fixture: Dictionary, funded: bool = true) -> LiveEventChoicePanel:
	await _reach(fixture, funded)
	var route: Array[String] = app.run_map.get_route()
	var rng_before: int = app.run_rng.state
	var action := _route_action(fixture.path[4])
	_check(is_instance_valid(action) and not action.disabled and action.is_visible_in_tree(),
		"the genuine connected Emberglass Event route button is enabled")
	if not is_instance_valid(action):
		return null
	await _click(action)
	var panel: LiveEventChoicePanel = app.wallet_event_panel
	_check(is_instance_valid(panel) and app.run_map.get_route() == route + [fixture.path[4]]
		and app.run_map.get_node(fixture.path[4]).type == "Event"
		and app.run_rng.state == fixture.after_draw
		and rng_before == fixture.before_draw,
		"exactly one seeded Event selection commits the Event node")
	if not is_instance_valid(panel):
		return null
	var record := panel._selector.get_event()
	_check(record.id == EMBER and app._wallet_event_history == [EMBER]
		and app._emberglass_gate != null and app._emberglass_gate.is_valid()
		and app._emberglass_gate.get_event() == record
		and panel.get_choice_buttons().size() == 3
		and panel.title_label.text == record.title,
		"actual mounted parchment and one-visit gate authenticate the authored Event")
	for index in range(3):
		var choice: Dictionary = record.choices[index]
		var button := panel.get_choice_buttons()[index]
		_check(button.is_visible_in_tree() and button.text.contains(choice.text)
			and panel._bound_choices.get(button) == choice.id,
			"all three physical choice tickets preserve the authored IDs and texts")
	return panel


func _paid(fixture: Dictionary, keyboard: bool, heal: bool = true) -> Array:
	var panel := await _open_ember(fixture)
	if panel == null:
		return []
	var node_id: String = fixture.path[4]
	var prior_route: Array[String] = app.run_map.get_route()
	var rng_state: int = app.run_rng.state
	var original: Dictionary = _wallet()
	_check(original.scraps >= 1 and not panel.get_choice_buttons()[0].disabled,
		"one-scrap paid ticket is genuinely affordable")
	var stale_commit: Callable = panel.wallet_choice_committed.get_connections()[0].callable
	var forged := {"ok": true, "event_id": EMBER, "choice_id": "light_the_embers",
		"wallet": {"gold": original.gold, "scraps": 999}}
	_reject_wallet(stale_commit.bind(forged), "unclaimed forged wallet signal")
	if keyboard:
		panel.get_choice_buttons()[0].grab_focus()
		await _key(KEY_SPACE)
	else:
		await _click(panel.get_choice_buttons()[0])
	_check(app.wallet_event_panel == null and app._emberglass_gate == null
		and is_instance_valid(app.campfire_view)
		and app.campfire_view.is_visible_in_tree()
		and app.campfire_visit.read_state().status == RunCampfireVisit.OPEN
		and app.run_map.get_current_node_id() == node_id
		and app.run_map.get_route() == prior_route
		and app.run_rng.state == rng_state
		and _wallet() == {"gold": original.gold, "scraps": original.scraps - 1}
		and app._emberglass_campfire_active(node_id),
		"paid real callback opens the same-node one-use Campfire and spends once")
	if not is_instance_valid(app.campfire_view):
		return []
	var pay_wallet := _wallet()
	var before := _wallet_state()
	stale_commit.call({"ok": true, "event_id": EMBER, "choice_id": "light_the_embers",
		"wallet": pay_wallet})
	_check(_wallet_state() == before, "replayed paid Event receipt cannot spend twice")
	var before_heroes: Array = app.run_heroes.duplicate(true)
	var preview := RunCampfireVisit.new(node_id, before_heroes).choose_heal(node_id, before_heroes)
	_check(not app.campfire_leave_button.disabled and (not app.campfire_heal_button.disabled) == (
		preview.get("ok", false) and preview.get("heroes", []) != before_heroes),
		"paid Campfire preserves the existing Heal eligibility and always offers Leave")
	if heal:
		_check(not app.campfire_heal_button.disabled and preview.get("ok", false)
			and preview.heroes != before_heroes,
			"real earlier events carry recoverable hero damage into Emberglass")
	var action: Button = app.campfire_heal_button if heal else app.campfire_leave_button
	if keyboard:
		action.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(action)
	_check(app.campfire_visit.read_state().status == (
		RunCampfireVisit.HEALED if heal else RunCampfireVisit.LEFT)
		and app._campfire_closed and not app.campfire_view.visible
		and is_instance_valid(app.route_view) and app._can_choose_connected_route()
		and app.run_map.get_route() == prior_route and app.run_rng.state == rng_state
		and _wallet() == pay_wallet
		and app.run_heroes == (preview.heroes if heal else before_heroes),
		"paid Campfire Heal/Leave publishes the ordinary carried-hero receipt and reconnects the route")
	var replay := [pay_wallet, app.run_map.get_route(), str(app.run_rng.state), app.run_heroes.duplicate(true)]
	await _return_title()
	return replay


func _trade_leave(fixture: Dictionary, choice_index: int) -> void:
	var panel := await _open_ember(fixture)
	if panel == null:
		return
	var prior := _wallet()
	var route: Array[String] = app.run_map.get_route()
	var rng_state: int = app.run_rng.state
	var button := panel.get_choice_buttons()[choice_index]
	_check(not button.disabled, "authored trade or Leave has a physical enabled choice")
	await _click(button)
	var expected := {"gold": prior.gold + (12 if choice_index == 1 else 0),
		"scraps": prior.scraps}
	_check(app.wallet_event_panel == null and not is_instance_valid(app.campfire_view)
		and app._emberglass_campfire_auth.is_empty()
		and _wallet() == expected and app.run_map.get_route() == route
		and app.run_rng.state == rng_state and app._can_choose_connected_route(),
		"trade and Leave grant only their authored wallet outcomes with no service")
	await _return_title()


func _reject_and_claim(fixture: Dictionary) -> void:
	var panel := await _open_ember(fixture, false)
	if panel == null:
		return
	_check(_wallet().scraps == 0 and panel.get_choice_buttons()[0].disabled,
		"genuinely empty wallet disables paid service")
	var before := _wallet_state()
	await _click(panel.get_choice_buttons()[0])
	await _key(KEY_1)
	panel.get_choice_buttons()[0].pressed.emit()
	_check(_wallet_state() == before and not panel._selector.is_claimed()
		and app._emberglass_gate.is_valid() and not is_instance_valid(app.campfire_view),
		"unaffordable mouse, keyboard and direct signal refuse without RNG/spend/recovery")
	await _click(panel.get_choice_buttons()[2])
	_check(app.wallet_event_panel == null and app._can_choose_connected_route(),
		"unfunded Leave still completes the ordinary Event safely")
	await _return_title()
	panel = await _open_ember(fixture)
	if panel == null:
		return
	var callback: Callable = panel.wallet_choice_committed.get_connections()[0].callable
	var wallet := _wallet()
	var receipt := RunEventChoice.new(panel._selector.get_event()).choose_with_wallet(
		"light_the_embers", wallet)
	_check(receipt.ok, "forgery fixture constructs a real independently settled receipt")
	panel.wallet_choice_committed.disconnect(callback)
	await _click(panel.get_choice_buttons()[0])
	_check(panel._selector.is_claimed() and panel._committed_choice == receipt
		and app._emberglass_gate.is_valid(), "physical claim stages an authentic pending receipt")
	var forged: Dictionary = receipt.duplicate(true)
	forged.wallet.scraps += 1
	_reject_wallet(callback.bind(forged), "forged pending wallet receipt")
	panel._committed_choice = forged.duplicate(true)
	_reject_wallet(callback.bind(forged), "forged panel receipt fails independent settlement")
	panel._committed_choice = receipt.duplicate(true)
	app.run_scraps += 1
	_reject_wallet(callback.bind(receipt), "stale live wallet refuses service settlement")
	app.run_scraps -= 1
	var route: Array[String] = app.run_map.get_route().duplicate()
	app.run_map._route.pop_back()
	_reject_wallet(callback.bind(receipt), "stale map route refuses service settlement")
	app.run_map._route.assign(route)
	callback.call(receipt)
	_check(is_instance_valid(app.campfire_view) and app._emberglass_campfire_active(fixture.path[4])
		and _wallet() == {"gold": wallet.gold, "scraps": wallet.scraps - 1},
		"restored authentic claim completes exactly one paid mount")
	var spent := _wallet_state()
	callback.call(receipt)
	_check(_wallet_state() == spent, "a second authenticated claim cannot spend or mount twice")
	await _click(app.campfire_leave_button)
	_check(app._can_choose_connected_route(), "claimed Campfire can be left normally")
	await _return_title()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	var fixture: Dictionary = _fixtures().get(EMBER, {})
	_check(not fixture.is_empty(), "real bounded six-Event route and selected Emberglass seed exist")
	if not fixture.is_empty():
		print("EMBERGLASS_WITNESS_SEED=", fixture.seed)
		var mouse := await _paid(fixture, false)
		var keyboard := await _paid(fixture, true)
		_check(not mouse.is_empty() and mouse == keyboard,
			"same-seed mouse/keyboard paid Campfire Heal replay identically")
		await _paid(fixture, false, false)
		await _trade_leave(fixture, 1)
		await _trade_leave(fixture, 2)
		await _reject_and_claim(fixture)
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_v3_emberglass_campfire_route_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
