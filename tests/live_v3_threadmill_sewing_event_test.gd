extends "res://tests/live_m04_event_wallet_batch_test.gd"
## Genuine six-Event mounted Threadmill Loft service: paid Event and its one-use
## Sewing Circle share the fifth chosen node, with no additional route or RNG draw.

const THREADMILL := "v3_threadmill_sewing_circle"
var _pre_transit_scraps: int = -1


func _reach(fixture: Dictionary, funded: bool = true, picked: Array = ["warden", "seamstress", "tinker"]) -> void:
	app.run_seed = fixture.seed
	await _click(LEGACY_ENTRY.start_button(app))
	preload("res://tests/party_choice.gd").choose(app)
	await _frames()
	_check(app.run_map != null and app.run_rng != null, "real title Start creates seeded run")
	var service := RunV3HeroEventOffers.new(_party_ids())
	_check(service.is_valid(), "live three-hero party has a valid authored Event service")
	var live: Dictionary = app._load_wallet_event_catalog()
	_check(live == _combined_catalog(), "live catalog matches eligible actual party oracle")
	var live_ids := RunM04EventRotation.new(live).get_generic_event_ids()
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RunV3HeroEventOffers.CATALOG_PATH))
	var absent := 0
	for record in authored.events:
		if _party_ids().has(record.required_hero):
			_check(live_ids.count(record.id) == 1, "present hero story admitted once: " + record.id)
		else:
			absent += 1
			_check(not live_ids.has(record.id), "absent hero story excluded: " + record.id)
	_check(absent > 0, "live exclusion checks cover genuinely absent heroes")
	var detached := live.duplicate(true)
	live.events.clear()
	_check(app._load_wallet_event_catalog() == detached, "live hero offers remain detached")
	for index in range(3):
		await _traverse_treasures(fixture, fixture.path[index])
		await _click(_route_action(fixture.path[index]))
		var panel: LiveEventChoicePanel = app.quiet_spool_panel if index == 0 \
			else (app.moth_panel if index == 1 else app.dye_vat_panel)
		_check(is_instance_valid(panel) and app.route_view == null, "special Event genuinely mounted and gates route")
		if not is_instance_valid(panel):
			return
		await _click(panel.get_choice_buttons()[(0 if funded else 1) if index == 0 \
			else (2 if index == 1 or not funded else 1)])
	_check(app._quiet_spool_completed and app._moth_completed and app._dye_vat_completed
		and _wallet() == {"gold": 0, "scraps": 2 if funded else 0},
		"three authentic special receipts establish exact opening wallet")
	await _traverse_treasures(fixture, fixture.path[3])
	await _click(_route_action(fixture.path[3]))
	_check(is_instance_valid(app.needle_toll_panel), "fourth Event mounts the inserted toll")
	if not is_instance_valid(app.needle_toll_panel):
		return
	await _click(app.needle_toll_panel.get_choice_buttons()[0])
	_check(is_instance_valid(app.needle_toll_panel) and app._needle_toll_outcome.is_paid(),
		"paid toll preserves the wallet before generic affordability tests")
	if is_instance_valid(app.needle_toll_panel):
		var offers: Array = app._needle_toll_outcome.get_offered_ids()
		var buttons: Array = app.needle_toll_panel.get_choice_buttons()
		_check(offers.size() == 2 and buttons.size() == 3,
			"real paid visit mounts both rare tickets and Skip")
		if offers.size() != 2 or buttons.size() != 3:
			return
		for index in range(2):
			var card := RunPoolCardRewardOffers.resolve_reward_definition(offers[index])
			_check(not card.is_empty(), "routed paid offer resolves to an authored card")
			if card.is_empty():
				return
			_check(buttons[index].text == "Claim %s (%s, rare)\nCost %d energy · %s" % [
				card.display_name, card.owner, card.cost, CardShortRules.line(card)]
				and app.needle_toll_panel._bound_choices[buttons[index]] == offers[index]
				and buttons[index].tooltip_text.begins_with(buttons[index].text + "\nSource positions: ")
				and buttons[index].is_visible_in_tree()
				and Rect2(0, 0, 1280, 720).encloses(buttons[index].get_global_rect()),
				"real app payment exposes the exact offered card powers before selection")
		await _click(app.needle_toll_panel.get_choice_buttons()[2])
	_check(app.needle_toll_panel == null and app._needle_toll_completed
		and _wallet() == {"gold": 0, "scraps": 2 if funded else 0},
		"Skip resumes routing with the exact original wallet including zero-wallet negatives")
	if _pre_transit_gold >= 0:
		app.session_gold = _pre_transit_gold
	if _pre_transit_scraps >= 0:
		app.run_scraps = _pre_transit_scraps
	if _pre_transit_gold >= 0 or _pre_transit_scraps >= 0:
		app._sync_bound_wardrobe(app.party_carryover as RunTornCarryover)
		app._clear_route_view()
		app._present_connected_route(weakref(app.run_map))
	await _traverse_treasures(fixture, fixture.path[4])


func _open_threadmill(fixture: Dictionary, gold: int = 12, scraps: int = -1) -> LiveEventChoicePanel:
	_pre_transit_gold = gold
	_pre_transit_scraps = scraps
	await _reach(fixture)
	_pre_transit_gold = -1
	_pre_transit_scraps = -1
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
	_check(record.id == THREADMILL and app._wallet_event_history == [THREADMILL]
		and app._emberglass_gate != null and app._emberglass_gate.is_valid()
		and app._emberglass_gate.get_event() == record
		and panel.get_choice_buttons().size() == 3
		and record.choices[0].id == "borrow_spools"
		and record.choices[1].id == "untie_scraps"
		and record.choices[2].id == "leave",
		"mounted parchment binds three canonical choices to one unclaimed service gate")
	for index in range(3):
		_check(panel._bound_choices.get(panel.get_choice_buttons()[index]) == record.choices[index].id
			and panel.get_choice_buttons()[index].text.contains(record.choices[index].text),
			"each physical ticket is bound to its exact authored ID and caption")
	return panel


func _threadmill_state() -> Array:
	return [app._sewing_context(), app._wallet_event_history.duplicate(),
		app._threadmill_sewing_auth.duplicate(), app._sewing_closed,
		app._sewing_source.duplicate(true), app._sewing_visits.duplicate(true),
		app.sewing_visit.read_state() if app.sewing_visit != null else {},
		app.sewing_view, app.wallet_event_panel, app.route_view]


func _reject_threadmill(callback: Callable, reason: String) -> void:
	var before := _threadmill_state()
	callback.call()
	_check(_threadmill_state() == before, reason + " preserves service, wallet, map, route and RNG")


func _test_paid_upgrade(fixture: Dictionary, keyboard: bool) -> Array:
	var panel := await _open_threadmill(fixture, 12)
	if panel == null:
		return []
	var node_id: String = fixture.path[4]
	var wallet := _wallet()
	var before_route: Array = app.run_map.get_route()
	var before_rng: int = app.run_rng.state
	var original_deck: Array[String] = app.run_deck.duplicate()
	_check(wallet.gold == 12 and not panel.get_choice_buttons()[0].disabled,
		"12-gold wallet enables borrow_spools")
	var old_commit: Callable = panel.wallet_choice_committed.get_connections()[0].callable
	_reject_wallet(old_commit.bind({"ok": true, "event_id": THREADMILL, "choice_id": "borrow_spools",
		"wallet": {"gold": 0, "scraps": 0}}), "unclaimed forged paid signal")
	if keyboard:
		panel.get_choice_buttons()[0].grab_focus()
		await _key(KEY_1)
	else:
		await _click(panel.get_choice_buttons()[0])
	_check(app.wallet_event_panel == null and is_instance_valid(app.sewing_view)
		and app.sewing_view.is_visible_in_tree() and app.sewing_visit.is_valid()
		and app.sewing_visit.read_state() == app._sewing_source
		and app.run_map.get_current_node_id() == node_id
		and app._threadmill_sewing_active(node_id) and app._threadmill_sewing_auth[5].is_claimed()
		and app.run_map.get_route() == before_route and app.run_rng.state == before_rng
		and _wallet() == {"gold": 0, "scraps": wallet.scraps}
		and not app._can_choose_connected_route(),
		"paid choice settles 12 gold once and mounts LiveSewingCirclePanel on same Event")
	if not is_instance_valid(app.sewing_view):
		return []
	var view: LiveSewingCirclePanel = app.sewing_view
	var before := _threadmill_state()
	old_commit.call({"ok": true, "event_id": THREADMILL, "choice_id": "borrow_spools",
		"wallet": {"gold": 0, "scraps": wallet.scraps}})
	_check(_threadmill_state() == before, "paid Event callback replay cannot mount or charge again")
	_check(not view.upgrade_button.disabled and view.confirm_button.disabled,
		"sewing circle offers enabled upgrade and requires explicit confirm")

	# Test negative intent actions before selection
	var listener: Callable = view.intent_requested.get_connections()[0].callable
	var source: Dictionary = app._sewing_source
	var valid_intent := {"action": "upgrade", "first_index": 0, "second_index": -1,
		"node_id": source.node_id, "visit_id": source.visit_id, "source_snapshot": source.duplicate(true)}
	_reject_threadmill(listener.bind(valid_intent), "unconfirmed intent requested rejected")
	var forged_intent := valid_intent.duplicate(true)
	forged_intent.visit_id = "forged"
	_reject_threadmill(listener.bind(forged_intent), "forged visit_id rejected")
	var forged_node := valid_intent.duplicate(true)
	forged_node.node_id = "forged"
	_reject_threadmill(listener.bind(forged_node), "forged node_id rejected")

	# Physical upgrade selection
	await _click(view.upgrade_button)
	_check(not view.option_buttons.is_empty(), "upgrade populates card option buttons")
	if view.option_buttons.is_empty():
		return []
	var chosen_option: Dictionary = view.option_buttons[0].get_meta("option")
	await _click(view.option_buttons[0])
	_check(not view.confirm_button.disabled and view.preview() == chosen_option,
		"card selection enables confirm button and matches preview")

	# Commit upgrade
	if keyboard:
		view.confirm_button.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(view.confirm_button)

	_check(app._sewing_closed and not app.sewing_view.visible
		and is_instance_valid(app.route_view) and app._can_choose_connected_route()
		and app.run_map.get_route() == before_route and app.run_rng.state == before_rng
		and app.session_gold == 0 and app.run_scraps == wallet.scraps
		and app._threadmill_sewing_auth.is_empty()
		and app.run_deck[chosen_option.index] == chosen_option.plus_id,
		"upgrade choice commits upgraded card, clears witness and resumes connected route")

	var result := [_wallet(), app.run_deck.duplicate(), app.run_map.get_route(), str(app.run_rng.state)]
	await _return_title()
	_check(app._threadmill_sewing_auth.is_empty(), "title return cleans up Threadmill authority")
	return result


func _test_paid_stitch(fixture: Dictionary) -> void:
	var panel := await _open_threadmill(fixture, 12, 10)
	if panel == null:
		return
	var node_id: String = fixture.path[4]
	var wallet := _wallet()
	_check(wallet.gold == 12 and wallet.scraps == 10, "funded 12 gold and 10 scraps for stitch")
	await _click(panel.get_choice_buttons()[0])
	_check(is_instance_valid(app.sewing_view) and app.sewing_view.is_visible_in_tree(),
		"paid entry opens sewing panel for stitch test")
	if not is_instance_valid(app.sewing_view):
		return
	var view: LiveSewingCirclePanel = app.sewing_view
	_check(not view.stitch_button.disabled, "stitch button is enabled with 10 scraps")
	await _click(view.stitch_button)
	_check(not view.option_buttons.is_empty(), "stitch mode populates first card options")
	if view.option_buttons.is_empty():
		return
	var first_card: Dictionary = view.option_buttons[0].get_meta("option")
	await _click(view.option_buttons[0])
	_check(not view.option_buttons.is_empty(), "first selection populates second different-owner options")
	if view.option_buttons.is_empty():
		return
	var second_card: Dictionary = view.option_buttons[0].get_meta("option")
	_check(first_card.owner != second_card.owner, "stitch options enforce different-owner cards")
	await _click(view.option_buttons[0])
	_check(not view.confirm_button.disabled, "two cards selected enables confirm button")
	await _click(view.confirm_button)
	_check(app._sewing_closed and not app.sewing_view.visible
		and is_instance_valid(app.route_view) and app._can_choose_connected_route()
		and app.session_gold == 0 and app.run_scraps == 7
		and app._threadmill_sewing_auth.is_empty()
		and not app.run_stitch_descriptors.is_empty(),
		"stitch choice charges 3 scraps, creates stitched card and resumes route")
	await _return_title()


func _test_paid_leave(fixture: Dictionary) -> void:
	var panel := await _open_threadmill(fixture, 12, 5)
	if panel == null:
		return
	await _click(panel.get_choice_buttons()[0])
	_check(is_instance_valid(app.sewing_view) and app.sewing_view.is_visible_in_tree(),
		"paid entry opens sewing panel for leave test")
	if not is_instance_valid(app.sewing_view):
		return
	var view: LiveSewingCirclePanel = app.sewing_view
	_check(not view.leave_button.disabled, "leave button enabled in sewing circle")
	await _click(view.leave_button)
	_check(not view.confirm_button.disabled, "clicking leave enables confirm")
	var deck_before: Array[String] = app.run_deck.duplicate()
	await _click(view.confirm_button)
	_check(app._sewing_closed and not app.sewing_view.visible
		and is_instance_valid(app.route_view) and app._can_choose_connected_route()
		and app.session_gold == 0 and app.run_scraps == 5
		and app._threadmill_sewing_auth.is_empty()
		and app.run_deck == deck_before,
		"paid sewing circle leave settles zero scraps and resumes route")
	await _return_title()


func _test_untie_scraps(fixture: Dictionary) -> void:
	var panel := await _open_threadmill(fixture, 0)
	if panel == null:
		return
	var scraps_before: int = app.run_scraps
	var gold_before: int = app.session_gold
	var rng_before: int = app.run_rng.state
	var button := panel.get_choice_buttons()[1]
	_check(not button.disabled and button.text.contains("Untie scraps"), "untie_scraps button enabled")
	await _click(button)
	_check(app.wallet_event_panel == null and (app.sewing_view == null or not app.sewing_view.visible)
		and app._threadmill_sewing_auth.is_empty()
		and is_instance_valid(app.route_view) and app._can_choose_connected_route()
		and app.session_gold == gold_before and app.run_scraps == scraps_before + 2
		and app.run_rng.state == rng_before,
		"untie_scraps grants exactly 2 scraps without sewing panel or witness")
	await _return_title()


func _test_free_leave(fixture: Dictionary) -> void:
	var panel := await _open_threadmill(fixture, 0)
	if panel == null:
		return
	var scraps_before: int = app.run_scraps
	var gold_before: int = app.session_gold
	var rng_before: int = app.run_rng.state
	var button := panel.get_choice_buttons()[2]
	_check(not button.disabled and button.text.contains("Leave"), "leave button enabled")
	await _click(button)
	_check(app.wallet_event_panel == null and (app.sewing_view == null or not app.sewing_view.visible)
		and app._threadmill_sewing_auth.is_empty()
		and is_instance_valid(app.route_view) and app._can_choose_connected_route()
		and app.session_gold == gold_before and app.run_scraps == scraps_before
		and app.run_rng.state == rng_before,
		"free leave alters neither currency and resumes route without sewing panel")
	await _return_title()


func _test_unfunded_and_preflight(fixture: Dictionary) -> void:
	# 11 gold: borrow_spools is disabled
	var panel := await _open_threadmill(fixture, 11)
	if panel == null:
		return
	_check(panel.get_choice_buttons()[0].disabled, "11 gold disables 12-gold borrow_spools")
	_check(not panel.get_choice_buttons()[1].disabled, "untie_scraps remains enabled at 11 gold")
	_check(not panel.get_choice_buttons()[2].disabled, "leave remains enabled at 11 gold")
	var before := _wallet_state()
	await _click(panel.get_choice_buttons()[0])
	await _key(KEY_1)
	panel.get_choice_buttons()[0].pressed.emit()
	_check(_wallet_state() == before and not panel._selector.is_claimed(),
		"disabled borrow_spools cannot spend or claim gate")
	await _click(panel.get_choice_buttons()[2])
	await _return_title()

	# Preflight failure and recovery check
	panel = await _open_threadmill(fixture, 12)
	if panel == null:
		return
	var commit: Callable = panel.wallet_choice_committed.get_connections()[0].callable
	var receipt := RunEventChoice.new(panel._selector.get_event()).choose_with_wallet("borrow_spools", _wallet())
	_check(receipt.ok, "independent authentic paid receipt exists")
	panel.wallet_choice_committed.disconnect(commit)
	await _click(panel.get_choice_buttons()[0])
	_check(panel._selector.is_claimed() and panel._committed_choice == receipt,
		"physical click claims panel and stages pending receipt")

	# Forged wallet in receipt fails
	var forged := receipt.duplicate(true)
	forged.wallet.gold += 1
	_reject_wallet(commit.bind(forged), "forged wallet receipt rejected")
	panel._committed_choice = forged
	_reject_wallet(commit.bind(forged), "forged panel receipt rejected")
	panel._committed_choice = receipt

	# Stale live state fails
	app.session_gold += 1
	_reject_wallet(commit.bind(receipt), "stale gold rejected")
	app.session_gold -= 1

	# Preflight failure: corrupt deck
	var orig_deck: Array[String] = app.run_deck.duplicate()
	app.run_deck.clear()
	_reject_wallet(commit.bind(receipt), "corrupt deck causes preflight failure")
	app.run_deck.assign(orig_deck)

	# Recovery: authentic commit succeeds after preflight failure recovery
	commit.call(receipt)
	_check(is_instance_valid(app.sewing_view) and app._threadmill_sewing_active(fixture.path[4])
		and app.session_gold == 0,
		"restored authentic claim settles 12 gold and opens sewing view")
	await _click(app.sewing_view.leave_button)
	await _click(app.sewing_view.confirm_button)
	await _return_title()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	var fixtures := _fixtures()
	var fixture: Dictionary = fixtures.get(THREADMILL, {})
	_check(not fixture.is_empty(), "oracle finds genuine seeded Threadmill route")
	if not fixture.is_empty():
		print("THREADMILL_WITNESS_SEED=", fixture.seed)
		var mouse := await _test_paid_upgrade(fixture, false)
		var keyboard := await _test_paid_upgrade(fixture, true)
		_check(not mouse.is_empty() and mouse == keyboard,
			"paid upgrade replays identically for physical mouse and keyboard")
		await _test_paid_stitch(fixture)
		await _test_paid_leave(fixture)
		await _test_untie_scraps(fixture)
		await _test_free_leave(fixture)
		await _test_unfunded_and_preflight(fixture)
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_v3_threadmill_sewing_event_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
