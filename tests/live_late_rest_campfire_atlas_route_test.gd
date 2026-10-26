extends "res://tests/live_late_rest_campfire_admission_test.gd"
## Real Fight/reward prefix, physical atlas input, and authenticated Campfire receipts.


func _atlas_refuse(callback: Callable, reason: String) -> void:
	var state: Dictionary = app._sewing_context()
	var overlay = app.route_atlas_overlay
	var view = app.route_view
	var atlas = app.route_atlas
	var visit = app.campfire_visit
	var visibility := [view.visible if is_instance_valid(view) else false,
		overlay.visible if is_instance_valid(overlay) else false]
	var receipts: Dictionary = app._campfire_visits.duplicate(true)
	_check(not callback.call(fixture.id), reason + " returns failure")
	_check(app._sewing_context() == state and app.route_atlas_overlay == overlay
		and app.route_atlas == atlas and app.route_view == view and app.campfire_visit == visit
		and app._campfire_visits == receipts, reason + " is atomic across models, views and receipts")
	_check(visibility == [app.route_view.visible if is_instance_valid(app.route_view) else false,
		app.route_atlas_overlay.visible if is_instance_valid(app.route_atlas_overlay) else false],
		reason + " preserves chooser and overlay visibility")


func _atlas_scenario(heal: bool, mode: int) -> Array:
	if not await _late_boot():
		app.free()
		return []
	var button := _button(fixture.id)
	_check(button != null and button.pressed.get_connections().size() == 1,
		"genuine connected Rest control has its production callback")
	if button == null:
		app.free()
		return []
	var map: RunMap = app.run_map
	var prior: Array[String] = map.get_route()
	var original: Dictionary = app._sewing_context()
	_check(button.get_meta("route_kind") == "Rest" and button.get_meta("sewing_source") == original
		and button.tooltip_text == "Campfire preview: opens the legacy Rest screen to heal or upgrade a card.",
		"later Rest captures source context but retains accurate legacy tooltip")
	await _click(app.route_map_button)
	var atlas: RunRouteAtlas = app.route_atlas
	_check(atlas != null and atlas._map == map, "live atlas binds original generated map")
	if atlas == null:
		app.free()
		return []
	_check(atlas.node_requested.get_connections().size() == 1, "exactly one mounted atlas listener")
	var callback: Callable = atlas.node_requested.get_connections()[0].callable
	var cleared: Array = []
	atlas.tree_exiting.connect(func(): cleared.append(atlas._map == null))
	var marker := atlas.get_node_or_null("Node_" + fixture.id + "/Action") as Button
	_check(marker != null and not marker.disabled, "genuine later Rest marker is reachable")
	if marker == null:
		app.free()
		return []
	marker.grab_focus()
	var help := "One action: heal each hero 30% max HP (torn revives at 1 HP first), or leave unchanged"
	_check(marker.tooltip_text.contains(help) and atlas._choice_ticket.route_id == fixture.id
		and atlas._choice_ticket.lead_text == "Rest · Choose one: heal or leave"
		and atlas._choice_ticket.detail_text == "Heal 30% max HP; torn revives at 1 HP first",
		"legal Rest focus ticket and hover promise exactly Campfire actions")
	var motion := InputEventMouseMotion.new()
	motion.position = marker.get_global_rect().get_center()
	root.push_input(motion, true)
	await _frames()
	_check(atlas._choice_ticket.route_id == fixture.id
		and atlas._choice_ticket.lead_text == "Rest · Choose one: heal or leave",
		"physical pointer selects truthful later Rest ticket")
	_check(map.get_node(fixture.id).type == "Rest" and app._sewing_context() == original,
		"guidance preserves source kind and every run authority")
	var future_rests := 0
	for floor_nodes in map.get_floors():
		for node in floor_nodes:
			if node.type == "Rest" and not map.get_legal_choices().has(node.id):
				future_rests += 1
				var future := atlas.get_node_or_null("Node_" + node.id) as Control
				_check(future != null and not future.tooltip_text.contains("One action:"), "nonlegal Rest keeps identity-only guidance")
	_check(future_rests > 0, "seeded atlas exercises nonlegal future Rest guidance")
	# A closed overlay's saved listener must fail even after reopening on the same sources.
	await _click(app.route_atlas_close)
	_atlas_refuse(callback, "closed overlay listener")
	await _click(app.route_map_button)
	_atlas_refuse(callback, "old listener against replacement overlay")
	atlas = app.route_atlas
	callback = atlas.node_requested.get_connections()[0].callable
	cleared.clear()
	atlas.tree_exiting.connect(func(): cleared.append(atlas._map == null))
	marker = atlas.get_node("Node_" + fixture.id + "/Action") as Button
	var fake := Button.new()
	app.route_view.add_child(fake)
	for key in ["route_id", "route_kind", "v3_kind", "sewing_source"]:
		fake.set_meta(key, button.get_meta(key))
	var args: Array = callback.get_bound_arguments()
	var choices: Dictionary = args[7].duplicate()
	choices[fixture.id] = weakref(fake)
	args[7] = choices
	_atlas_refuse(Callable(app, "_choose_atlas_opening").bindv(args), "forged copied route button")
	fake.free()
	app.run_scraps += 1
	_atlas_refuse(callback, "stale sewing wallet")
	app.run_scraps -= 1
	map._generation_revision += 1
	_atlas_refuse(callback, "generation drift")
	map._generation_revision -= 1
	var edges: Array = map._nodes[fixture.fight].outgoing.duplicate()
	map._nodes[fixture.fight].outgoing.erase(fixture.id)
	_atlas_refuse(callback, "removed legal edge")
	map._nodes[fixture.fight].outgoing = edges
	map._route.append(fixture.id)
	_atlas_refuse(callback, "route drift")
	map._route.pop_back()
	button.disabled = true
	_atlas_refuse(callback, "disabled original button")
	button.disabled = false
	# Matching forged metadata cannot hide a failed carryover preflight.
	var carry = app.party_carryover
	app.party_carryover = RunTornCarryover.new(app.run_heroes)
	var saved = button.get_meta("sewing_source")
	button.set_meta("sewing_source", app._sewing_context())
	_atlas_refuse(callback, "unbound carryover observer")
	app.party_carryover = carry
	button.set_meta("sewing_source", saved)
	_check(app._sewing_context() == original, "all refused admissions preserve original authorities")
	if mode == 0:
		await _click(marker)
	elif mode == 3:
		var shortcut: int = atlas._rendered_shortcuts.find(fixture.id)
		_check(shortcut >= 0 and shortcut < 4, "later Rest has physical number shortcut")
		await _key((KEY_1 + shortcut) as Key)
	else:
		marker.grab_focus()
		_check(marker.has_focus(), "later Rest marker receives keyboard focus")
		await _key(KEY_ENTER if mode == 1 else KEY_SPACE)
	_check(cleared == [true] and app.route_atlas == null, "accepted atlas clears once before disposal")
	await _frames()
	_check(app.campfire_view is LiveCampfirePanel and app.campfire_view.is_visible_in_tree()
		and app.run_map.get_route() == prior + [fixture.id] and not is_instance_valid(app.rest_view),
		"atlas mounts real sewn panel and advances exactly once")
	if not is_instance_valid(app.campfire_view):
		app.free()
		return []
	_check(not app._can_choose_connected_route() and not app._campfire_visits.has(fixture.id), "open Rest cannot continue without completion witness")
	var count := 0
	for child in app.get_children():
		if child is LiveCampfirePanel:
			count += 1
	_check(count == 1, "exactly one Campfire panel is mounted")
	var admitted: Dictionary = app._sewing_context()
	for key in original:
		if key != "route":
			_check(admitted[key] == original[key], "entry preserves exact " + key)
	_atlas_refuse(callback, "accepted atlas listener replay")
	await _camp_negatives()
	var before: Dictionary = app._sewing_context()
	var expected: Array = before.heroes.duplicate(true)
	if heal:
		for hero in expected:
			hero.hp = mini(hero.max_hp, maxi(1, hero.hp) + int(floor(hero.max_hp * 0.3)))
	var action: Button = app.campfire_heal_button if heal else app.campfire_leave_button
	var retired: Callable = app.campfire_view._connections[action]
	if mode == 3:
		await _key(KEY_1 if heal else KEY_2)
	elif mode > 0:
		action.grab_focus()
		await _key(KEY_SPACE)
	else:
		await _click(action)
	await _frames()
	_check(app._campfire_closed and not app.campfire_view.visible and app._can_choose_connected_route(), "physical Heal/Leave closes once and permits onward play")
	_check(app.campfire_visit.read_state() == {"ok": true, "node_id": fixture.id,
		"status": RunCampfireVisit.HEALED if heal else RunCampfireVisit.LEFT, "heroes": expected}, "exact one-use receipt")
	var after: Dictionary = app._sewing_context()
	var ledger: Dictionary = before.ledger.duplicate(true)
	var torn: Dictionary = before.torn.duplicate(true)
	if heal:
		ledger.heroes = expected
		ledger.completed_rests.append(fixture.id)
		torn.heroes = expected
		torn.completed_rests.append(fixture.id)
	_check(after.ledger == ledger and after.torn == torn and app.run_heroes == expected, "both full ledgers match independent exact Heal/Leave oracle")
	for key in before:
		if key not in ["heroes", "ledger", "torn"]:
			_check(after[key] == before[key], "decision preserves exact " + key)
	_refuse(retired, "replayed action")
	var witness: Array = app._campfire_visits[fixture.id]
	app._campfire_visits.erase(fixture.id)
	_check(not app._can_choose_connected_route(), "absent witness cannot fall back to legacy authority")
	app._campfire_visits[fixture.id] = witness.slice(0, 3) + [[]]
	_check(not app._can_choose_connected_route(), "wrong prefix witness rejects continuation")
	app._campfire_visits[fixture.id] = witness
	var onward := _button(fixture.next)
	_check(onward != null and not onward.disabled, "real onward Fight control exists")
	if onward != null:
		var onward_callback: Callable = onward.pressed.get_connections()[0].callable
		await _click(onward)
		await _frames()
		_check(app.deck != null and map.get_route() == prior + [fixture.id, fixture.next], "real onward button enters exactly one Fight")
		var state: Dictionary = app._sewing_context()
		onward_callback.call()
		_check(app._sewing_context() == state, "replayed onward control is inert")
	_refuse(retired, "old decision after onward battle")
	_atlas_refuse(callback, "old atlas listener after onward battle")
	var replay: Array = [map.get_route(), app.run_heroes.duplicate(true), app.party_carryover.read_state(), app.run_rng.state, app.deck.hand.duplicate()]
	app.free()
	await _frames()
	return replay



func _run() -> void:
	root.size = Vector2i(1280, 720)
	fixture = _late_fixture()
	_check(not fixture.is_empty(), "real generated Fight -> Rest -> Fight fixture exists")
	if not fixture.is_empty():
		for heal in [false, true]:
			var replay: Array = []
			for mode in range(4):
				var result := await _atlas_scenario(heal, mode)
				_check(not result.is_empty(), "physical input completes receipt and onward Fight")
				if mode == 0:
					replay = result
				else:
					_check(result == replay, "mouse, Enter, Space and number inputs replay exact ledgers and RNG")
	for failure in failures:
		printerr(failure)
	print("live_late_rest_campfire_atlas_route_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
