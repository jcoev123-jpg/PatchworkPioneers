extends "res://tests/live_rest_route_entry_test.gd"

const ROUTE_HELP_TOOLTIPS := {"SewingCircle": "Upgrade one card, stitch two different-owner cards for 3 scraps, or leave unchanged"}
var fixture: Dictionary


func _frames() -> void:
	for i in range(3):
		await process_frame


func _fixture() -> Dictionary:
	for value in range(1, 1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for id in map.get_legal_choices():
			if map.get_node(id).type != "SewingCircle":
				continue
			for next in map.get_node(id).outgoing:
				if map.get_node(next).type == "Fight":
					return {"seed": value, "id": id, "next": next}
	return {}


func _ledger() -> Array:
	return [app._sewing_context(), app.act_outcome.get_state(),
		app._sewing_closed, app._sewing_visits.duplicate(true),
		app.sewing_visit.read_state() if app.sewing_visit != null else {}]


func _button(id: String) -> Button:
	for button in app.route_buttons:
		if button.get_meta("route_id") == id:
			return button
	return null


func _boot(wallet: bool = false, wardrobe: bool = false) -> void:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = fixture.seed
	await _click(app.start_button)
	preload("res://tests/party_choice.gd").choose(app)
	await _frames()
	_check(app.run_map.get_node(fixture.id).type == "SewingCircle"
		and app.run_map.get_legal_choices().has(fixture.id), "genuine seeded legal Sewing Circle")
	if wallet:
		# Same explicit funded opening authority as the shipped web preview.
		app.session_gold = 100
		app.run_scraps = 10
		root.get_node("LiveWebPlaytestBoot")._preview_map = weakref(app.run_map)
	if wardrobe:
		var carry: RunTornCarryover = app.party_carryover
		var w := RunPatchWardrobe.new(app.run_heroes, app.run_trinkets, [],
			app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
		_check(w.is_valid() and carry.bind_wardrobe(w, carry.torn, w.get_snapshot()),
			"real carryover binds coherent wardrobe before route capture")
	if wallet or wardrobe:
		app._clear_route_view()
		app._present_connected_route(weakref(app.run_map))
	await _frames()


func _enter(atlas: bool, keyboard: bool) -> void:
	var prior: Array = app.run_map.get_route()
	if atlas:
		await _click(app.route_map_button)
		await _frames()
		var captured: Callable = app.route_atlas.node_requested.get_connections()[0].callable
		var overlay = app.route_atlas_overlay
		app.run_scraps += 1
		_inert(captured, "stale atlas wallet", [fixture.id])
		_check(app.route_atlas_overlay == overlay, "rejected Sewing atlas admission preserves mounted overlay")
		app.run_scraps -= 1
		var marker: Button = app.route_atlas.get_node("Node_" + fixture.id + "/Action")
		_check(marker.tooltip_text.contains(ROUTE_HELP_TOOLTIPS.SewingCircle), "atlas has truthful Sewing Circle Help")
		if keyboard:
			marker.grab_focus()
			await _key(KEY_ENTER)
		else:
			await _click(marker)
	else:
		var button := _button(fixture.id)
		_check(button.text == "Sewing Circle" and button.get_meta("route_kind") == "SewingCircle",
			"opening label and canonical kind are distinct")
		if keyboard:
			button.grab_focus()
			await _key(KEY_ENTER)
		else:
			await _click(button)
	await _frames()
	_check(is_instance_valid(app.sewing_view) and app.sewing_view.is_visible_in_tree()
		and app.run_map.get_route() == prior + [fixture.id], "physical input enters isolated Sewing Circle")
	_check(not is_instance_valid(app.rest_view) and not is_instance_valid(app.rest_stitch_overlay),
		"Rest gallery and guided picker are not mounted")
	var panel: LiveSewingCirclePanel = app.sewing_view
	_check(panel.get_parent() == app and panel.position == Vector2(170, 50)
		and panel.size == Vector2(940, 620), "tested panel placement fits live viewport")
	_check(panel.intent_requested.get_connections().size() == 1
		and panel._visit == app.sewing_visit and app.sewing_visit.is_valid(), "one controller owns authentic visit")
	_check(panel.stitch_button.text.contains("3 scraps") and panel.confirm_button.disabled,
		"cost visible and explicit confirmation required")
	var before := _ledger()
	var controls := [panel.upgrade_button, panel.stitch_button, panel.leave_button]
	var visited: Array = []
	for i in range(4):
		var focus := root.gui_get_focus_owner()
		if not visited.has(focus):
			visited.append(focus)
		await _key(KEY_TAB)
	for control in controls:
		if not control.disabled:
			_check(visited.has(control), "Tab reaches primary action")
	_check(_ledger() == before, "focus traversal consumes nothing")
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_TAB
		event.shift_pressed = true
		event.pressed = down
		root.push_input(event, true)
	await _frames()
	_check(controls.has(root.gui_get_focus_owner()) and _ledger() == before,
		"reverse Tab stays within the mounted visit without spending")


func _intent(action: String = "upgrade", first: int = 0, second: int = -1) -> Dictionary:
	var source: Dictionary = app._sewing_source
	return {"action": action, "first_index": first, "second_index": second,
		"node_id": source.node_id, "visit_id": source.visit_id, "source_snapshot": source.duplicate(true)}


func _activate(button: Button, keyboard: bool) -> void:
	_check(is_instance_valid(button) and not button.disabled and button.is_visible_in_tree(), "real enabled panel action")
	if keyboard:
		button.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(button)
	await _frames()


func _inert(callback: Callable, label: String, arguments: Array = []) -> void:
	var before := _ledger()
	callback.callv(arguments)
	_check(_ledger() == before, label + " preserves complete authority and RNG")


func _negative_actions() -> void:
	var panel: LiveSewingCirclePanel = app.sewing_view
	var visit: RunSewingCircleVisit = app.sewing_visit
	var listener: Callable = panel.intent_requested.get_connections()[0].callable
	# Nothing is selected or confirmed yet: even a complete, source-valid
	# decision forwarded straight into the connected listener is not a player's
	# choice, so every canonical action must fail closed.
	_check(not panel._submitted and panel._confirmed.is_empty() and panel.confirm_button.disabled
		and panel.preview().is_empty(), "authentication negatives start before any selection or Confirm")
	_inert(listener, "unconfirmed Leave", [_intent("leave")])
	var upgrades: Array = visit.upgrade_options()
	_check(not upgrades.is_empty(), "an eligible unconfirmed Upgrade exists")
	if not upgrades.is_empty():
		_inert(listener, "unconfirmed eligible Upgrade", [_intent("upgrade", upgrades[0].index)])
	var pair: Array = []
	for first in visit.stitch_first_options():
		var seconds: Array = visit.stitch_second_options(first.index)
		if not seconds.is_empty():
			pair = [first.index, seconds[0].index]
			break
	if app.run_scraps >= RunRestStitchCards.SCRAP_COST:
		_check(not pair.is_empty(), "an affordable different-owner Stitch pair exists")
		if not pair.is_empty():
			_inert(listener, "unconfirmed affordable Stitch", [_intent("stitch", pair[0], pair[1])])
	_check(not panel._submitted and panel.confirm_button.disabled and not panel.leave_button.disabled
		and not visit.is_consumed() and app.run_map.get_current_node_id() == app._sewing_source.node_id,
		"unconfirmed intents leave panel operable, visit open and route intact")
	var callback: Callable = app.sewing_view.intent_requested.get_connections()[0].callable.bind(_intent())
	var original: Dictionary = app._sewing_context()
	app.run_heroes[0].hp -= 1
	_inert(callback, "mismatched party")
	app.run_heroes = original.heroes.duplicate(true)
	var carry = app.party_carryover
	app.party_carryover = RunTornCarryover.new(original.heroes)
	_inert(callback, "foreign carryover identity")
	app.party_carryover = carry
	if app.party != null:
		var live: Array = app.party.get_heroes()
		app.party.apply_damage(1, 1)
		_inert(callback, "drifted live combat party")
		app.party._heroes.assign(live)
	var map = app.run_map
	var foreign := RunMap.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = fixture.seed
	foreign.generate(rng)
	foreign.choose_node(fixture.id)
	app.run_map = foreign
	_inert(callback, "same-graph foreign map identity")
	app.run_map = map
	map._generation_revision += 1
	_inert(callback, "regenerated map revision")
	map._generation_revision -= 1
	map._route.append(fixture.next)
	_inert(callback, "advanced route")
	map._route.pop_back()
	var run_rng = app.run_rng
	app.run_rng = RandomNumberGenerator.new()
	app.run_rng.state = run_rng.state
	_inert(callback, "foreign RNG identity")
	app.run_rng = run_rng
	app.run_rng.randi()
	_inert(callback, "advanced RNG state")
	app.run_rng.state = original.rng_state
	app.session_gold += 1
	_inert(callback, "drifted gold")
	app.session_gold -= 1
	app.run_scraps += 1
	_inert(callback, "drifted scraps")
	app.run_scraps -= 1
	app.run_stitch_descriptors["forged"] = {}
	_inert(callback, "corrupt descriptor ledger")
	app.run_stitch_descriptors.clear()
	app.run_next_stitch_id += 1
	_inert(callback, "drifted allocator")
	app.run_next_stitch_id -= 1
	app.run_trinkets.append("forged_patch")
	_inert(callback, "drifted patch inventory")
	app.run_trinkets.pop_back()
	var bound_source: Dictionary = panel._source.duplicate(true)
	panel._source.node_id = "forged"
	_inert(callback, "tampered panel binding")
	panel._source = bound_source
	app.sewing_visit._ledger.remaining_scraps += 1
	_inert(callback, "tampered service ledger")
	app.sewing_visit._ledger.remaining_scraps -= 1
	for field in ["node_id", "visit_id", "source_snapshot", "action"]:
		var forged := _intent()
		forged[field] = {} if field == "source_snapshot" else "forged"
		_inert(panel.intent_requested.get_connections()[0].callable, "forged " + field, [forged])
	_inert(app._sewing_intent.bind(_intent(), panel, RunSewingCircleVisit.new(fixture.id,
		app.run_deck, app.run_stitch_descriptors, app.run_scraps, app.run_next_stitch_id)), "foreign visit identity")
	var fake := LiveSewingCirclePanel.new()
	app.add_child(fake)
	_inert(app._sewing_intent.bind(_intent(), fake, app.sewing_visit), "forged panel")
	fake.free()
	panel.hide()
	_inert(callback, "hidden panel")
	panel.show()
	app.remove_child(panel)
	root.add_child(panel)
	_inert(callback, "reparented panel")
	root.remove_child(panel)
	app.add_child(panel)
	_inert(panel.intent_requested.get_connections()[0].callable, "forged upgrade index", [_intent("upgrade", 10000)])
	_inert(panel.intent_requested.get_connections()[0].callable, "same occurrence stitch", [_intent("stitch", 0, 0)])
	var owner: String = RunRestStitchCards.resolve_card_definition(app.run_deck[0]).owner
	var found := false
	for i in range(1, app.run_deck.size()):
		if RunRestStitchCards.resolve_card_definition(app.run_deck[i]).owner == owner:
			found = true
			_inert(panel.intent_requested.get_connections()[0].callable, "different occurrences same owner", [_intent("stitch", 0, i)])
			break
	_check(found, "same-owner rejection has genuine distinct occurrences")
	_inert(panel.intent_requested.get_connections()[0].callable, "forged stitch index", [_intent("stitch", 0, -1)])
	if original.wardrobe != null:
		original.wardrobe._scraps += 1
		_inert(callback, "stale wardrobe snapshot")
		original.wardrobe._scraps -= 1
		carry._wardrobe = null
		_inert(callback, "removed wardrobe identity")
		carry._wardrobe = original.wardrobe
	_check(app._sewing_context() == original, "negative fixtures restore exact original authority")
	# With a real preview selected and Confirm enabled, an alternate eligible
	# index and an alternate action are still not the confirmed decision.
	await _activate(panel.upgrade_button, false)
	var eligible: Array = visit.upgrade_options()
	_check(panel.option_buttons.size() == eligible.size() and eligible.size() >= 2,
		"alternate-index rejection has genuine eligible copies")
	var selected_index := -1
	var alternate_index := -1
	if not panel.option_buttons.is_empty():
		selected_index = panel.option_buttons[0].get_meta("option").index
	for option in eligible:
		if option.index != selected_index:
			alternate_index = option.index
			break
	_check(selected_index >= 0 and alternate_index >= 0, "a distinct eligible upgrade index exists")
	if alternate_index >= 0:
		await _activate(panel.option_buttons[0], false)
		_check(not panel.confirm_button.disabled and panel.preview().index == selected_index,
			"selected upgrade preview matches the chosen occurrence")
		_inert(listener, "alternate unconfirmed upgrade index", [_intent("upgrade", alternate_index)])
		_check(not panel._submitted and panel.preview().is_empty() and panel.confirm_button.disabled,
			"alternate index never settles and retires the pending selection")
	await _activate(panel.leave_button, false)
	_check(not panel.confirm_button.disabled, "alternate-action rejection has a selected, confirmable preview")
	var other_action: Array = visit.upgrade_options()
	_check(not other_action.is_empty(), "alternate action is itself eligible")
	if not other_action.is_empty():
		_inert(listener, "alternate selected Upgrade", [_intent("upgrade", other_action[0].index)])
	_check(not panel._submitted and panel.preview().is_empty() and panel.confirm_button.disabled
		and not panel.leave_button.disabled, "mismatched forwarded action retires the pending selection")
	# A real Confirm marks the panel submitted before controller preflight.
	# Reject stale authority, then restore it and prove this visit remains usable.
	await _activate(panel.leave_button, false)
	app.session_gold += 1
	var before := _ledger()
	await _activate(panel.confirm_button, false)
	_check(_ledger() == before and not panel._submitted and not panel.leave_button.disabled,
		"rejected physical Confirm preserves service and restores usable panel")
	app.session_gold -= 1
	_check(app._sewing_context() == original, "recovery restores exact original authority")


func _onward() -> void:
	var prior: Array = app.run_map.get_route()
	_check(app._can_choose_connected_route() and not app.sewing_view.visible,
		"closed visit exposes legal onward routing")
	var button := _button(fixture.next)
	_check(button != null and not button.disabled, "genuine connected fight exists")
	if button != null:
		await _click(button)
		await _frames()
		_check(app.deck != null and app.run_map.get_route() == prior + [fixture.next],
			"physical connected selection starts real fight after pre-fight Sewing Circle")


func _scenario(mode: String, atlas: bool, keyboard: bool) -> Array:
	await _boot(mode != "leave", true)
	# Route admission compares the captured source before touching the graph.
	var route: Callable = _button(fixture.id).pressed.get_connections()[0].callable
	app.run_scraps += 1
	_inert(route, "stale route wallet")
	app.run_scraps -= 1
	await _enter(atlas, keyboard)
	await _negative_actions()
	var before: Dictionary = app._sewing_context()
	var panel: LiveSewingCirclePanel = app.sewing_view
	var visit: RunSewingCircleVisit = app.sewing_visit
	var expected: Dictionary = {}
	var submitted := _intent(mode)
	await _activate(panel.upgrade_button if mode == "upgrade" else panel.stitch_button if mode == "stitch" else panel.leave_button, keyboard)
	if mode != "leave":
		var authentic: Array = visit.upgrade_options() if mode == "upgrade" else visit.stitch_first_options()
		_check(not authentic.is_empty() and panel.option_buttons.size() == authentic.size(),
			"routed panel displays all authentic source occurrence mini-cards")
		if not authentic.is_empty() and not panel.option_buttons.is_empty():
			var card: Button = panel.option_buttons[0]
			var record: Dictionary = authentic[0]
			var ink := ""
			for label in card.find_children("*", "Label", true, false):
				ink += (label as Label).text + "\n"
			_check(card.get_meta("option") == record and ink.contains(record.owner.capitalize())
				and ink.contains("copy #%d" % (record.index + 1))
				and ink.contains("%d energy" % record.cost)
				and ink.contains(record.get("display_name", record.get("name", ""))),
				"actual seeded route mounts readable owner/cost/name/index labels")
	if mode == "upgrade":
		var duplicate: Button
		for option in panel.option_buttons:
			var row: Dictionary = option.get_meta("option")
			if before.deck.slice(0, row.index).has(row.base_id):
				duplicate = option
				break
		_check(duplicate != null, "canonical buttons contain indexed duplicate occurrence")
		var chosen: Dictionary = duplicate.get_meta("option")
		duplicate.set_meta("option", {"index": 10000})
		await _activate(duplicate, keyboard)
		_check(panel.preview() == chosen and panel.preview_label.text.contains(chosen.plus_display_name),
			"tampered display metadata cannot redirect canonical upgrade callback or preview")
		expected = {"deck": before.deck.duplicate()}
		expected.deck[chosen.index] = chosen.plus_id
		submitted = _intent(mode, chosen.index)
	elif mode == "stitch":
		var first: int = panel.option_buttons[0].get_meta("option").index
		await _activate(panel.option_buttons[0], keyboard)
		_check(not panel.option_buttons.is_empty(), "real different-owner stitch pair exists")
		var second: int = panel.option_buttons[0].get_meta("option").index
		panel.option_buttons[0].set_meta("option", {"index": -1})
		await _activate(panel.option_buttons[0], keyboard)
		var oracle := RunRestStitchCards.new(before.deck, before.descriptors, before.scraps, before.cursor)
		expected = oracle.choose_stitch(first, second, oracle.get_snapshot())
		_check(expected.ok and panel.preview().first_index == first and panel.preview().second_index == second,
			"independent stitch receipt and preview use chosen occurrences")
		submitted = _intent(mode, first, second)
	else:
		_check(panel.stitch_button.disabled and before.scraps == 0, "insufficient scraps disables Stitch")
		_check(RunRestStitchCards.resolve_card_definition(before.deck[0]).owner !=
			RunRestStitchCards.resolve_card_definition(before.deck[4]).owner,
			"unaffordable rejection uses a genuine different-owner pair")
		_inert(panel.intent_requested.get_connections()[0].callable, "insufficient scraps", [_intent("stitch", 0, 4)])
		await _activate(panel.leave_button, keyboard)
	_check(app._sewing_context() == before and not visit.is_consumed() and not panel.confirm_button.disabled,
		"preview never settles; Confirm is required")
	var callback: Callable = panel.intent_requested.get_connections()[0].callable.bind(submitted)
	await _activate(panel.confirm_button, keyboard)
	_check(visit.is_consumed() and app._sewing_closed and panel._visit == null,
		"controller consumes receipt and retires panel")
	_check(visit.read_state().deck == app.run_deck and visit.read_state().descriptors == app.run_stitch_descriptors
		and visit.read_state().remaining_scraps == app.run_scraps and visit.read_state().next_stitch_id == app.run_next_stitch_id,
		"run authority exactly matches complete consumed controller receipt")
	var after: Dictionary = app._sewing_context()
	if mode == "leave":
		_check(after == before, "Leave preserves the complete authoritative snapshot")
	else:
		var wanted := before.duplicate(true)
		wanted.deck = expected.deck
		if mode == "stitch":
			wanted.scraps -= 3
			wanted.descriptors = expected.descriptors
			wanted.cursor += 1
			_check(app._stitch_snapshot() == RunRestStitchCards.new(expected.deck, expected.descriptors,
				expected.remaining_scraps, expected.next_stitch_id).get_snapshot(), "atomic composite ledger and receipt match")
		wanted.wardrobe_state = after.wardrobe_state
		_check(after == wanted, "winning action changes only exact chosen deck/ledger, never RNG or HP")
		_check(after.wardrobe_state.cards == after.deck and after.wardrobe_state.scraps == after.scraps,
			"legitimate closure refreshes wardrobe cards and scraps")
	_inert(callback, "repeated closed action")
	var replay: Array = [after.deck, after.descriptors, after.scraps, after.cursor, after.rng_state, after.heroes]
	await _onward()
	_inert(callback, "old action after real next fight")
	app.free()
	await _frames()
	return replay


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
				if map.get_node(id).type != "SewingCircle":
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


func _connected_visits() -> void:
	fixture = _post_fight_fixture()
	_check(not fixture.is_empty(), "real Fight -> Sewing Circle -> Fight fixture exists")
	if fixture.is_empty():
		return
	for keyboard in [false, true]:
		app = load("res://scenes/app.tscn").instantiate()
		root.add_child(app)
		await _frames()


		presenter = app.get_node("LiveAttackPreview")
		if not await _routed_win(fixture, false):
			app.free()
			return
		await _click(app.reward_buttons[3])
		await _click(app.continue_button)
		await _frames()
		_check(app.party_carryover.read_state().completed_fights == [fixture.fight], "real won fight is committed before connected visit")
		var route_button := _button(fixture.id)
		var route: Callable = route_button.pressed.get_connections()[0].callable
		var forged := Button.new()
		app.route_view.add_child(forged)
		forged.set_meta("route_id", fixture.id)
		forged.set_meta("route_kind", "SewingCircle")
		forged.set_meta("sewing_source", app._sewing_context())
		_inert(app._choose_sewing_route.bind(fixture.id, weakref(app.run_map), app.run_map.get_route(), forged), "forged route control")
		forged.free()
		var saved: int = app.run_rng.state
		app.run_rng.randi()
		_inert(route, "stale connected route RNG")
		app.run_rng.state = saved
		await _enter(keyboard, keyboard)
		var before := _ledger()
		if keyboard:
			app.sewing_leave_button.grab_focus()
			await _key(KEY_ENTER)
		else:
			await _click(app.sewing_leave_button)
		await _activate(app.sewing_view.confirm_button, keyboard)
		await _frames()
		_check(_ledger()[0] == before[0] and app._can_choose_connected_route(), "post-fight Leave preserves complete snapshot and admits onward route")
		var witness: Array = app._sewing_visits[fixture.id]
		app._sewing_visits.erase(fixture.id)
		_check(not app._can_choose_connected_route(), "missing closure receipt rejects onward route")
		app._sewing_visits[fixture.id] = witness
		_inert(route, "old connected route after closure")
		await _onward()
		app.free()
		await _frames()




func _composite_visit() -> void:
	var chain: Dictionary = {}
	for value in range(1, 1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for id in map.get_legal_choices():
			if map.get_node(id).type != "SewingCircle":
				continue
			for second in map.get_node(id).outgoing:
				if map.get_node(second).type != "SewingCircle":
					continue
				for next in map.get_node(second).outgoing:
					if map.get_node(next).type == "Fight":
						chain = {"seed": value, "id": id, "second": second, "next": next}
		if not chain.is_empty():
			break
	_check(not chain.is_empty(), "seeded Sewing Circle -> Sewing Circle chain exists")
	if chain.is_empty():
		return
	fixture = chain
	await _boot(true, true)
	await _enter(false, false)
	var panel: LiveSewingCirclePanel = app.sewing_view
	await _activate(panel.stitch_button, false)
	var first: int = panel.option_buttons[0].get_meta("option").index
	await _activate(panel.option_buttons[0], false)
	var second: int = panel.option_buttons[0].get_meta("option").index
	await _activate(panel.option_buttons[0], false)
	var old: Callable = panel.intent_requested.get_connections()[0].callable.bind(_intent("stitch", first, second))
	var old_confirm: Callable = panel.confirm_button.pressed.get_connections()[0].callable
	await _activate(panel.confirm_button, false)
	_check(app.run_stitch_descriptors.size() == 1 and app.run_next_stitch_id == 2, "first real visit creates authenticated composite")
	fixture.id = chain.second
	await _enter(true, true)
	_inert(old, "old control during a new mounted Sewing Circle")
	var composite_index: int = app.run_deck.find("stitched_000001")
	_check(composite_index >= 0, "real composite occurrence is present")
	_inert(old_confirm, "old panel confirmation during new visit")
	panel = app.sewing_view
	await _activate(panel.stitch_button, true)
	for option in panel.option_buttons:
		_check(option.get_meta("option").index != composite_index, "composite is never an eligible stitch half")
	_inert(panel.intent_requested.get_connections()[0].callable, "forged composite half", [_intent("stitch", composite_index, 0)])
	await _activate(panel.leave_button, true)
	await _activate(panel.confirm_button, true)
	await _onward()
	app._return_to_title()
	await _frames()
	_check(app.sewing_view == null and app.sewing_visit == null and app._sewing_source.is_empty()
		and app._sewing_original.is_empty() and app._sewing_visits.is_empty()
		and app.sewing_upgrade_button == null and app.sewing_stitch_button == null
		and app.sewing_leave_button == null, "title clears Sewing Circle controls, service and receipts")
	app.free()
	await _frames()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	fixture = _fixture()
	_check(not fixture.is_empty(), "bounded seeded Sewing Circle fixture found")
	if fixture.is_empty():
		_finish()
		return
	var facts := RunRouteAtlas.stop_consequence("SewingCircle")
	_check(facts.lead == "Choose one: upgrade or stitch"
		and facts.detail == "Stitch different owners: 3 scraps; or leave"
		and facts.tooltip == ROUTE_HELP_TOOLTIPS.SewingCircle, "truthful independent Help facts")
	var token := RunRouteAtlas.NodeToken.new()
	token.token_kind = "SewingCircle"
	token.token_texture = null
	root.add_child(token)
	await process_frame
	_check(token.token_kind == "SewingCircle" and token.token_texture == null,
		"deterministic missing-image token fallback retains kind")
	token.free()
	for mode in ["upgrade", "stitch", "leave"]:
		var first := await _scenario(mode, false, false)
		var second := await _scenario(mode, true, true)
		_check(first == second, "same seed and choices replay exactly: " + mode)
	await _connected_visits()
	await _composite_visit()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_sewing_circle_stop_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
