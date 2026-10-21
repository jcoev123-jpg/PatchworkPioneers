extends "res://tests/live_run_map_entry_test.gd"


func _marker(app, id: String) -> Button:
	var button := app.route_atlas.get_node_or_null("Node_" + id + "/Action") as Button
	_check(button != null and button.is_visible_in_tree(), "actual highlighted marker mounted")
	return button


func _button(app, id: String) -> Button:
	for button in app.route_buttons:
		if button.get_meta("route_id") == id:
			return button
	_check(false, "legal chooser button exists: " + id)
	return null


func _inert(app, callback: Callable, id: String, reason: String) -> void:
	var before := _snapshot(app)
	var controls: Array = [app.route_view, app.route_atlas, app.route_atlas_overlay,
		app.route_map_button, root.gui_get_focus_owner()]
	callback.call(id)
	_check(_snapshot(app) == before and controls == [app.route_view, app.route_atlas,
		app.route_atlas_overlay, app.route_map_button, root.gui_get_focus_owner()], reason)


## Value-only ledger so the direct chooser and every atlas input can be compared.
func _values(app) -> Array:
	var carry = app.party_carryover as RunTornCarryover
	var battle: Variant = null
	if app.deck != null:
		battle = [app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
			app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
			app.enemies.get_enemies(), app.enemy_intents.get_intents()]
	return [app.run_map.get_floors(), app.run_map.get_route(),
		app.run_map.get_legal_choices(), app.run_map.get_current_node_id(),
		app.run_rng.state, app.encounter_id, app.run_deck.duplicate(),
		app.run_heroes.duplicate(true), app.session_gold, app.run_scraps,
		app.run_trinkets.duplicate(), app.run_removal_count,
		app.run_stitch_descriptors.duplicate(true), app.run_next_stitch_id,
		carry.read_state() if carry != null else null,
		app.act_outcome.get_state() if app.act_outcome != null else null,
		app._placeholder_route.duplicate(), battle]


## Each legal opening kind must mount its own existing flow, never a no-op.
func _assert_flow(app, kind: String, id: String, rng_state: int) -> void:
	if kind in ["Fight", "Elite"]:
		_check(app.deck != null and app.battle_view != null and app.battle_view.is_visible_in_tree(),
			"typed %s opening mounts the real mounted battle" % kind)
		if app.deck == null:
			return
		var pools: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RunAuthoredBattleEntry.POOLS_PATH))
		_check(pools[kind].has(app.encounter_id), "selected encounter belongs to the actual %s pool" % kind)
		var rng := RandomNumberGenerator.new()
		rng.state = rng_state
		var ids: Array = pools[kind].keys()
		ids.sort()
		_check(app.encounter_id == ids[rng.randi_range(0, ids.size() - 1)],
			"one sorted %s selection draw on the uninterrupted run RNG" % kind)
		# Entry legitimately draws the typed encounter and then shuffles the same
		# RNG for the hand; the mounted deck must match that continuation exactly.
		var reference := CombatDeck.new(app.run_deck, rng)
		_check(reference.start_turn(), "independent deck starts from the seeded selection state")
		_check(app.deck.hand == reference.hand and app.deck.draw_pile == reference.draw_pile
			and app.deck.discard_pile == reference.discard_pile
			and app.run_rng.state == rng.state and app.deck._rng == app.run_rng,
			"typed selection and real hand share one uninterrupted seeded stream")
		_check(app.deck.energy == 3 and app.deck.hand.size() == 5 and app.deck.turn_active,
			"real hand opens at three energy and five cards")
		_check(app._current_act_battle() and app._current_carryover_fight()
			and app.act_outcome.get_state().pending_node_id == id,
			"live outcome latch and torn witness bind the actual %s battle" % kind)
		return
	if kind == "Rest":
		_check(app.rest_view != null and app.rest_view.is_visible_in_tree()
			and app.rest_recovery != null and is_instance_valid(app.rest_continue_button)
			and app.rest_continue_button.disabled and app.route_view == null,
			"Rest marker mounts its existing visit with no choice committed")
		_check(app.run_rng.state == rng_state,
			"Rest visit preserves the seeded run RNG")
		return
	if kind == "Shop":
		_check(app.shop_view != null and app.shop_view.is_visible_in_tree()
			and app.shop_visit != null and app.shop_purchases != null
			and app.shop_offers.item_count > 0 and app.route_view == null,
			"Shop marker mounts its existing seeded visit")
		var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
		var rng := RandomNumberGenerator.new()
		rng.state = rng_state
		var owners: Array[String] = []
		for hero in app.run_heroes:
			owners.append(hero.id)
		var expected := RunShopStockOffers.generate(rng, owners, authored.cards, authored.trinkets, [])
		_check(expected.ok and app.run_rng.state == rng.state,
			"Shop spends exactly one seeded stock draw")
		var stock: Array = app.shop_purchases.get_stock().cards
		_check(stock.size() == expected.cards.size(), "Shop mounts the complete authored card stock")
		for index in range(mini(stock.size(), expected.cards.size())):
			_check(stock[index].id == expected.cards[index].id
				and stock[index].price == expected.cards[index].price
				and app.shop_offers.get_item_metadata(index) == expected.cards[index].id,
				"visible Shop offer matches the independent stock oracle")
		_check(app.session_gold == 0 and app.run_deck.size() == 12,
			"Shop opening spends none of the seeded session")
		return
	_check(app.route_view != null and app.route_view.is_visible_in_tree()
		and app._placeholder_route == [id] and app.deck == null
		and app.run_rng.state == rng_state and app.encounter_id == "",
		"placeholder marker mounts the actual connected choices without effects")
	_check(not app.route_buttons.is_empty()
		and app.route_buttons.all(func(button: Button) -> bool: return not button.disabled),
		"placeholder offers its real connected route")


func _leave_flow(app, kind: String) -> void:
	if kind == "Event" and is_instance_valid(app.quiet_spool_panel):
		_check(app.route_view == null, "Event exit requires completing its pending choice")
		await _click(app.quiet_spool_panel.get_choice_buttons()[1])
	var back: Button
	if kind == "Rest":
		back = app.rest_back_button
	elif kind == "Shop":
		back = app.shop_back_button
	elif kind in ["Event", "Treasure"]:
		back = app.route_back_button
	else:
		back = app.return_button
	_check(is_instance_valid(back) and back.is_visible_in_tree(),
		"actual %s exit control is mounted" % kind)
	if not is_instance_valid(back):
		return
	await _click(back)
	await process_frame
	_check(app.run_map == null and app.run_rng == null and app.deck == null
		and app.title_view.visible and app.start_button.has_focus()
		and app.route_view == null and app.route_atlas == null,
		"%s exit clears the seeded session and restores the title" % kind)


## Mouse, Enter and Space on the actual marker must match the direct chooser.
func _legal_openings(app) -> void:
	var cases: Array = [
		["Rest", 2, "f01_n2"], ["Shop", 3, "f01_n2"],
		["Event", 7, "f01_n1"], ["Treasure", 9, "f01_n2"],
		["Elite", 1, "f01_n1"],
	]
	for fixture in cases:
		var kind: String = fixture[0]
		var replay: Array = []
		for mode in range(5):
			app.run_seed = fixture[1]
			await _click(app.route_button)
			_check(app.run_map != null and app.route_view != null
				and app.run_map.get_legal_choices().has(fixture[2])
				and app.run_map.get_node(fixture[2]).type == kind,
				"seeded %s opening is a real legal choice" % kind)
			if app.run_map == null:
				continue
			var rng_state: int = app.run_rng.state
			var callback := Callable()
			var cleared: Array = []
			var marker: Button
			if mode == 0:
				marker = _button(app, fixture[2])
			else:
				await _click(app.route_map_button)
				_check(app.route_atlas_overlay != null and app.route_atlas != null
					and app.route_atlas._map == app.run_map,
					"real atlas bound for the legal %s opening" % kind)
				if app.route_atlas == null:
					continue
				callback = app.route_atlas.node_requested.get_connections()[0].callable
				var atlas: RunRouteAtlas = app.route_atlas
				atlas.tree_exiting.connect(func(): cleared.append(atlas._map == null))
				marker = _marker(app, fixture[2])
				_check(marker != null and marker.focus_mode == Control.FOCUS_ALL
					and marker.mouse_filter == Control.MOUSE_FILTER_STOP
					and marker.get_parent().get_meta("route_state") == "legal",
					"newly legal %s marker is clickable and focusable" % kind)
			if marker == null:
				continue
			if mode == 1:
				await _click(marker)
			elif mode == 4:
				var shortcut: int = app.route_atlas._rendered_shortcuts.find(fixture[2])
				_check(shortcut >= 0 and shortcut < 4, "legal opening has a physical number shortcut")
				for down in [true, false]:
					var event := InputEventKey.new()
					event.keycode = (KEY_1 + shortcut) as Key
					event.physical_keycode = event.keycode
					event.pressed = down
					root.push_input(event, true)
					await process_frame
			else:
				marker.grab_focus()
				_check(marker.has_focus(), "actual atlas marker keyboard focus: " + kind)
				await _key(KEY_ENTER if mode == 2 else KEY_SPACE)
			if callback.is_valid():
				_check(cleared == [true] and app.route_atlas == null,
					"accepting a legal %s marker clears the atlas before disposal" % kind)
			_check(app.run_map.get_route() == [fixture[2]]
				and app.run_map.get_current_node_id() == fixture[2],
				"%s opening commits exactly one selected node" % kind)
			if kind == "Event":
				_check(app.quiet_spool_panel != null and app.route_view == null
					and not app._can_choose_connected_route(), "atlas Event mounts pending authored choice")
				if app.quiet_spool_panel != null:
					await _click(app.quiet_spool_panel.get_choice_buttons()[1])
				_check(app.run_scraps == 0, "atlas Ignore preserves zero-scrap wallet")
			_assert_flow(app, kind, fixture[2], rng_state)
			if mode == 0:
				replay = _values(app)
			else:
				_check(_values(app) == replay,
					"atlas %s input matches the direct chooser ledger and RNG" % kind)
			if callback.is_valid():
				_inert(app, callback, fixture[2], "accepted atlas %s request cannot replay" % kind)
			await _leave_flow(app, kind)
			if callback.is_valid():
				callback.call(fixture[2])
				_check(app.run_map == null and app.title_view.visible
					and app.route_view == null and app.deck == null,
					"accepted %s atlas request cannot reopen the next session" % kind)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.run_seed = 6
	var id := "f01_n0"
	var replay: Array = []
	var stale: Array[Callable] = []
	# Same scene, title resets, same seed: chooser, mouse atlas, Enter atlas, Space atlas.
	for mode in range(4):
		await _click(app.route_button)
		_check(app.run_map != null and app.run_map.get_node(id).type == "Fight",
			"seed has legal opening Fight")
		for callback in stale:
			_inert(app, callback, id, "disposed listener cannot affect restarted session")
		if mode == 0:
			await _click(app.route_buttons[0])
		else:
			await _click(app.route_map_button)
			var atlas: RunRouteAtlas = app.route_atlas
			var cleared: Array = []
			atlas.tree_exiting.connect(func(): cleared.append(atlas._map == null))
			_check(atlas.node_requested.get_connections().size() == 1, "exactly one app listener")
			var callback: Callable = atlas.node_requested.get_connections()[0].callable
			for old in stale:
				_inert(app, old, id, "old listener cannot affect new mounted overlay")
			stale.append(callback)
			# Forge each captured identity independently while all other sources stay valid.
			for index in range(5):
				var args: Array = callback.get_bound_arguments()
				args[index] = weakref(app.route_back_button)
				var forged := Callable(app, "_choose_atlas_opening").bindv(args)
				_inert(app, forged, id, "forged captured identity rejected: " + str(index))
			_inert(app, callback, "unknown", "unknown signal rejected")
			_inert(app, callback, "f02_n0", "future signal rejected")
			# Every legal floor-one kind is admitted now; only a kind outside the
			# run's supported floor kinds stays inert without changing any state.
			for opening in app.run_map.get_legal_choices():
				if app.run_map.get_node(opening).type != "Fight":
					_check(_marker(app, opening) != null,
						"newly legal non-Fight marker mounted: " + opening)
			var supported_id := "f01_n1"
			var saved_kind: String = app.run_map._nodes[supported_id].type
			app.run_map._nodes[supported_id].type = "Boss"
			_inert(app, callback, supported_id, "unsupported opening kind rejected")
			app.run_map._nodes[supported_id].type = saved_kind
			app.route_buttons[0].disabled = true
			_inert(app, callback, id, "disabled matching chooser rejects signal")
			app.route_buttons[0].disabled = false
			var original_id = app.route_buttons[0].get_meta("route_id")
			app.route_buttons[0].set_meta("route_id", "forged")
			_inert(app, callback, id, "forged chooser identity rejected")
			app.route_buttons[0].set_meta("route_id", original_id)
			var map = app.run_map
			var foreign := RunMap.new()
			var rng := RandomNumberGenerator.new()
			rng.seed = 6
			_check(foreign.generate(rng), "foreign generated map fixture")
			app.run_map = foreign
			_inert(app, callback, id, "foreign live map rejected")
			app.run_map = map
			atlas.bind_map(foreign)
			_inert(app, callback, id, "foreign atlas binding rejected")
			atlas.bind_map(map)
			_check(map.choose_node(id), "external route progress fixture")
			_inert(app, callback, id, "changed route rejects listener")
			var empty_route: Array[String] = []
			_check(map.undo_choice(id, empty_route), "restore external route fixture")
			app.route_atlas_overlay.remove_child(atlas)
			_inert(app, callback, id, "detached atlas rejected")
			app.route_atlas_overlay.add_child(atlas)
			var overlay = app.route_atlas_overlay
			app.remove_child(overlay)
			_inert(app, callback, id, "detached overlay rejected")
			app.add_child(overlay)
			cleared.clear()
			var marker := _marker(app, id)
			if marker == null:
				break
			if mode == 1:
				await _click(marker)
			else:
				marker.grab_focus()
				_check(marker.has_focus(), "actual atlas marker keyboard focus")
				await _key(KEY_ENTER if mode == 2 else KEY_SPACE)
			_check(cleared == [true] and app.route_atlas == null, "acceptance clears atlas before disposal")
		_check(app.deck != null and app.battle_view != null and app.battle_view.is_visible_in_tree(),
			"actual input mounts routed battle")
		if app.deck == null:
			break
		_check(app.run_map.get_route() == [id] and app.route_view == null
			and app.hand_view.get_child_count() == 5 and app.deck._rng == app.run_rng,
			"exactly one route commit with real hand and shared RNG")
		var state := _snapshot(app)
		if mode == 0:
			replay = state
		else:
			_check(state == replay, "atlas matches direct graph/encounter/party/deck/enemies/RNG")
		for callback in stale:
			_inert(app, callback, id, "disposed callback cannot enter twice or alter battle")
			_inert(app, callback, "f01_n1", "disposed non-Fight signal cannot alter battle")
		await _click(app.return_button)
		await process_frame
	# Every other legal opening kind must work from the same mounted atlas.
	await _legal_openings(app)
	app.run_seed = 6
	# Failed admission must expose a usable chooser and roll back the transaction.
	await _click(app.route_button)
	var before := _snapshot(app)
	await _click(app.route_map_button)
	app.fight_selection._selected[id] = {"success": false}
	await _click(_marker(app, id))
	_check(app.route_atlas == null and app.route_view.is_visible_in_tree()
		and app.route_buttons[0].has_focus() and _snapshot(app) == before,
		"failed atlas startup restores exact chooser/models/RNG")
	app.fight_selection._selected.clear()
	await _click(app.route_buttons[0])
	_check(app.deck != null and _snapshot(app) == replay, "failed atlas entry retries with identical seeded battle")
	await _click(app.return_button)
	# Same graph regenerated on the same object must invalidate a saved listener.
	await _click(app.route_button)
	await _click(app.route_map_button)
	var callback: Callable = app.route_atlas.node_requested.get_connections()[0].callable
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	_check(app.run_map.generate(rng), "same-object regeneration fixture")
	_inert(app, callback, id, "generation mismatch rejects even identical graph")
	app._return_to_title()
	await process_frame
	await _click(app.route_button)
	_inert(app, callback, id, "title reset invalidates old listener")
	await _click(app.route_map_button)
	var back_callback: Callable = app.route_atlas.node_requested.get_connections()[0].callable
	app._cancel_route()
	await process_frame
	await _click(app.route_button)
	_inert(app, back_callback, id, "Back invalidates old listener")
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_atlas_opening_choice_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
