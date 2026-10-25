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
		app._sewing_closed, app._sewing_visits.duplicate(true)]


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
	var actions: Array = []
	for child in app.sewing_view.get_children():
		if child is Button and not child is OptionButton:
			actions.append(child.text)
	_check(actions == ["Upgrade", "Stitch", "Leave"], "exactly three primary actions")
	_check(app.sewing_stitch_button.tooltip_text.contains("3 scraps"), "three-scrap cost visible")
	var before := _ledger()
	# Traverse every enabled control from the real initial focus, including selectors.
	var visited: Array = []
	for i in range(7):
		var focus := root.gui_get_focus_owner()
		if not visited.has(focus):
			visited.append(focus)
		await _key(KEY_TAB)
	for control in app._sewing_controls:
		if not control.disabled:
			_check(visited.has(control), "Tab reaches " + control.get_class())
	_check(_ledger() == before, "focus traversal consumes nothing")
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_TAB
		event.shift_pressed = true
		event.pressed = down
		root.push_input(event, true)
	await _frames()
	_check(app._sewing_controls.has(root.gui_get_focus_owner()) and _ledger() == before,
		"reverse Tab stays within the mounted visit without spending")


func _inert(callback: Callable, label: String, arguments: Array = []) -> void:
	var before := _ledger()
	callback.callv(arguments)
	_check(_ledger() == before, label + " preserves complete authority and RNG")


func _negative_actions() -> void:
	var callback: Callable = app.sewing_upgrade_button.pressed.get_connections()[0].callable
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
	var selector: OptionButton = app.sewing_upgrade_cards
	var row: Dictionary = selector.get_item_metadata(0)
	selector.set_item_metadata(0, {"index": 10000})
	_inert(callback, "forged upgrade metadata")
	selector.set_item_metadata(0, row)
	var fake := Button.new()
	app.sewing_view.add_child(fake)
	_inert(app._sewing_action.bind(fake, app.sewing_view, app._sewing_controls.duplicate()), "forged action control")
	fake.free()
	var stitch: Callable = app.sewing_stitch_button.pressed.get_connections()[0].callable
	app.sewing_first.select(0)
	app.sewing_second.select(0)
	_inert(stitch, "same occurrence stitch")
	var first_id: String = app.run_deck[app.sewing_first.get_item_metadata(0)]
	var owner: String = RunRestStitchCards.resolve_card_definition(first_id).owner
	for i in range(1, app.sewing_second.item_count):
		var id: String = app.run_deck[app.sewing_second.get_item_metadata(i)]
		if RunRestStitchCards.resolve_card_definition(id).owner == owner:
			app.sewing_second.select(i)
			_inert(stitch, "different occurrences, same owner")
			break
	var second_meta: Variant = app.sewing_second.get_item_metadata(0)
	app.sewing_second.set_item_metadata(0, -1)
	_inert(stitch, "forged stitch index")
	app.sewing_second.set_item_metadata(0, second_meta)
	if original.wardrobe != null:
		original.wardrobe._scraps += 1
		_inert(callback, "stale wardrobe snapshot")
		original.wardrobe._scraps -= 1
		carry._wardrobe = null
		_inert(callback, "removed wardrobe identity")
		carry._wardrobe = original.wardrobe
	_check(app._sewing_context() == original, "negative fixtures restore exact original authority")


func _pick(selector: OptionButton, index: int) -> void:
	selector.select(0)
	selector.grab_focus()
	await _key(KEY_ENTER)
	for i in range(index):
		await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	_check(selector.selected == index, "physical popup input selects exact occurrence")


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
	var button: Button = app.sewing_leave_button
	var expected: Dictionary = {}
	if mode == "upgrade":
		button = app.sewing_upgrade_button
		var selector: OptionButton = app.sewing_upgrade_cards
		var duplicate := -1
		for i in range(1, selector.item_count):
			var row: Dictionary = selector.get_item_metadata(i)
			if before.deck.slice(0, row.index).has(row.base_id):
				duplicate = i
				break
		_check(duplicate > 0, "canonical selector contains indexed duplicate occurrence")
		selector.select(duplicate)
		if keyboard:
			await _pick(selector, duplicate)
		var chosen: Dictionary = selector.get_item_metadata(duplicate)
		expected = {"deck": before.deck.duplicate()}
		expected.deck[chosen.index] = chosen.plus_id
	elif mode == "stitch":
		button = app.sewing_stitch_button
		var first: int = app.sewing_first.get_item_metadata(0)
		var second := -1
		for i in range(app.sewing_second.item_count):
			var index: int = app.sewing_second.get_item_metadata(i)
			if RunRestStitchCards.resolve_card_definition(before.deck[index]).owner != RunRestStitchCards.resolve_card_definition(before.deck[first]).owner:
				second = index
				app.sewing_second.select(i)
				break
		_check(second >= 0, "real different-owner stitch pair exists")
		app.sewing_first.select(0)
		if keyboard:
			await _pick(app.sewing_first, 0)
			await _pick(app.sewing_second, app.sewing_second.selected)
		var oracle := RunRestStitchCards.new(before.deck, before.descriptors, before.scraps, before.cursor)
		expected = oracle.choose_stitch(first, second, oracle.get_snapshot())
		_check(expected.ok, "independent scene-free stitch receipt succeeds")
	else:
		_check(app.sewing_stitch_button.disabled and before.scraps == 0, "insufficient scraps disables Stitch")
		_inert(app.sewing_stitch_button.pressed.get_connections()[0].callable, "insufficient scraps")
	var callback: Callable = button.pressed.get_connections()[0].callable
	if keyboard:
		button.grab_focus()
		await _key(KEY_SPACE)
	else:
		await _click(button)
	await _frames()
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
	app.sewing_first.select(0)
	var owner: String = RunRestStitchCards.resolve_card_definition(app.run_deck[0]).owner
	for i in range(app.sewing_second.item_count):
		if RunRestStitchCards.resolve_card_definition(app.run_deck[app.sewing_second.get_item_metadata(i)]).owner != owner:
			app.sewing_second.select(i)
			break
	var old: Callable = app.sewing_stitch_button.pressed.get_connections()[0].callable
	await _click(app.sewing_stitch_button)
	await _frames()
	_check(app.run_stitch_descriptors.size() == 1 and app.run_next_stitch_id == 2, "first real visit creates authenticated composite")
	fixture.id = chain.second
	await _enter(true, true)
	_inert(old, "old control during a new mounted Sewing Circle")
	var composite_index: int = app.run_deck.find("stitched_000001")
	_check(composite_index >= 0, "real composite occurrence is present")
	for selector in [app.sewing_first, app.sewing_second]:
		for i in range(selector.item_count):
			_check(selector.get_item_metadata(i) != composite_index, "composite is never an eligible stitch half")
	var selector: OptionButton = app.sewing_first
	var saved: Variant = selector.get_item_metadata(0)
	selector.set_item_metadata(0, composite_index)
	_inert(app.sewing_stitch_button.pressed.get_connections()[0].callable, "forged composite half")
	selector.set_item_metadata(0, saved)
	await _click(app.sewing_leave_button)
	await _frames()
	await _onward()
	app._return_to_title()
	await _frames()
	_check(app.sewing_view == null and app._sewing_visits.is_empty(), "title clears Sewing Circle controls and receipts")
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
