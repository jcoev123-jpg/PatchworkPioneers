extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		root.push_input(event, true)
		await process_frame


func _click(button: Button) -> void:
	_check(is_instance_valid(button) and button.is_visible_in_tree(), "mouse target is mounted")
	if not is_instance_valid(button):
		return
	var point := button.get_global_rect().get_center()
	await _click_point(point)


func _click_point(point: Vector2) -> void:
	_check(root.get_visible_rect().has_point(point), "mouse target inside viewport")
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame


func _snapshot(app) -> Array:
	var result: Array = [app.run_map.get_floors(), app.run_map.get_route(),
		app.run_map.get_legal_choices(), app.run_rng.state, app.encounter_id]
	if app.deck != null:
		result.append([app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
			app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
			app.party.get_heroes(), app.enemies.get_enemies(), app.enemy_intents.get_intents()])
	else:
		result.append([app.deck, app.party, app.enemies, app.battle_view, app.round_flow, app.battle_result])
	result.append([app.title_view.visible, app.route_view, app.route_buttons.duplicate(),
		app.run_deck.duplicate(), app.enemy_attacks.duplicate(true), app.route_book_backdrop])
	var controls: Array = []
	for button in app.route_buttons:
		controls.append([button.text, button.disabled, button.is_visible_in_tree()])
	result.append(controls)
	return result


func _reject(app, id: String, reason: String) -> void:
	var before := _snapshot(app)
	var selector = app.fight_selection
	var cache: Dictionary = selector._selected.duplicate(true)
	var bound = selector._bound_map
	var attempted_fight: bool = app.deck == null and app.run_map.get_legal_choices().has(id) \
		and app.run_map.get_node(id).get("type") == "Fight"
	_check(not app._choose_route(id), reason + " rejected")
	_check(_snapshot(app) == before, reason + " spends no map/combat/RNG state")
	if attempted_fight:
		_check(app.fight_selection != null and app.fight_selection == selector,
			reason + " preserves selector identity after failed startup")
		_check(app.fight_selection._selected == cache and app.fight_selection._bound_map == bound
			and app.encounter_id == "", reason + " leaves no cached choice or map binding")
		var presenter = app.get_node("LiveEnemyRoster")
		_check(presenter.enemies == null and presenter.panel == null and app.enemy_intents == null
			and app.victory_gold == null, reason + " leaves no battle services or actor controls")


func _assert_opening_journey(app) -> void:
	var before := _snapshot(app)
	var hint: Label = app.route_book_backdrop.get_node("FloorHint")
	_check(app.run_map.get_route().is_empty(), "opening cue has a genuinely unvisited map")
	_check(hint.is_visible_in_tree() and hint.text == "Trailhead\nNext: Meadow · 01",
		"mounted seeded opening names trailhead and next floor without claiming a visit")
	app._mount_route_book()
	_check(_snapshot(app) == before, "refreshing mounted journey leaves all run state and actions unchanged")
	var source: RunMap = app.run_map
	for unavailable in [null, RunMap.new()]:
		app.run_map = unavailable
		app._mount_route_book()
		_check(hint.text == "Journey unavailable", "missing or ungenerated source is neutral")
	app.run_map = source
	app._mount_route_book()
	_check(hint.text == "Trailhead\nNext: Meadow · 01" and _snapshot(app) == before,
		"restoring the real source refreshes without spending")
	var probe := RunMap.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 232
	_check(probe.generate(rng), "journey boundary fixture generates a genuine seeded graph")
	app.run_map = probe
	for floor_number in range(1, RunMap.FLOOR_COUNT + 1):
		_check(probe.choose_node(probe.get_legal_choices()[0]), "journey boundary fixture commits a legal edge")
		app._mount_route_book()
		var projection: Dictionary = app._route_journey_projection()
		_check(projection.stops.size() == mini(2, floor_number), "projection retains at most two committed stops")
		if floor_number == 3:
			_check(hint.text.ends_with("Next: Woods · 04"), "next cue crosses the authored area boundary")
		var id: String = probe.get_current_node_id()
		var saved: Dictionary = probe._nodes[id].duplicate(true)
		for field in ["floor", "type"]:
			probe._nodes[id][field] = "invalid"
			app._mount_route_book()
			_check(hint.text == "Journey unavailable", "malformed committed " + field + " yields neutral text")
			probe._nodes[id] = saved.duplicate(true)
		probe._nodes[id].type = "Fight" if floor_number == RunMap.FLOOR_COUNT else "Boss"
		app._mount_route_book()
		_check(hint.text == "Journey unavailable", "known kind on the wrong committed floor is neutral")
		probe._nodes[id] = saved.duplicate(true)
		projection.stops[0].kind = "invented"
		_check(probe.get_node(probe.get_route()[maxi(0, floor_number - 2)]).type != "invented",
			"projection cannot mutate the authoritative route record")
		if floor_number < RunMap.FLOOR_COUNT:
			var future_id: String = probe.get_legal_choices()[0]
			var future_kind: String = probe._nodes[future_id].type
			probe._nodes[future_id].type = "HIDDEN FUTURE"
			app._mount_route_book()
			_check(not hint.text.contains("HIDDEN") and hint.text != "Journey unavailable",
				"unopened kinds are not read even when malformed")
			probe._nodes[future_id].type = future_kind
	app._mount_route_book()
	_check(hint.text.ends_with("Journey complete") and not hint.text.contains("Next:"),
		"terminal map has a bounded complete fallback without inventing floor thirteen")
	app.run_map = source
	app._mount_route_book()
	_check(hint.text == "Trailhead\nNext: Meadow · 01" and _snapshot(app) == before,
		"fresh opening clears all earlier journey text without changing real state")


func _preview(app, keyboard: bool, stale: Array = []) -> Array:
	_assert_opening_journey(app)
	var before := _snapshot(app)
	var chooser = app.route_view
	var action: Button = app.route_map_button
	_check(is_instance_valid(action) and action.is_visible_in_tree(), "real map action mounted")
	if not is_instance_valid(action):
		return []
	var open: Callable = action.pressed.get_connections()[0].callable
	var foreign := RunMap.new()
	var foreign_rng := RandomNumberGenerator.new()
	foreign_rng.seed = 6
	_check(foreign.generate(foreign_rng), "foreign map fixture generated")
	app._open_route_atlas(weakref(foreign), weakref(chooser), weakref(action))
	app._open_route_atlas(weakref(app.run_map), weakref(action), weakref(action))
	app._open_route_atlas(weakref(app.run_map), weakref(chooser), weakref(app.route_back_button))
	_check(app.route_atlas_overlay == null and _snapshot(app) == before, "foreign open sources rejected")
	if keyboard:
		app.route_buttons.back().grab_focus()
		await _key(KEY_TAB)
		_check(action.has_focus(), "Tab skips disabled openings to map action")
		await _key(KEY_ENTER)
	else:
		await _click(action)
	var atlas: RunRouteAtlas = app.route_atlas
	_check(is_instance_valid(atlas) and is_instance_valid(app.route_atlas_close), "real atlas and close mounted")
	if not is_instance_valid(atlas) or not is_instance_valid(app.route_atlas_close):
		return []
	var overlay = app.route_atlas_overlay
	var close: Callable = app.route_atlas_close.pressed.get_connections()[0].callable
	_check(app.route_view == chooser and not chooser.visible and app.route_atlas_close.has_focus(),
		"same chooser hidden; close focused")
	_check(app.route_book_backdrop != null and not app.route_book_backdrop.visible,
		"the full map replaces the opening book")
	_check(atlas._map == app.run_map and atlas.global_position == Vector2(20, 20)
		and atlas.size == Vector2(1240, 600), "real map bound at readable preview bounds")
	# The opening has no committed node, so the live preview never invents a reveal.
	_check(not atlas.is_revealing() and atlas.reveal_duration() == RunRouteAtlas.REVEAL_DURATION,
		"live opening atlas reveals nothing before its first committed node")
	var masked_threads := 0
	for child in atlas.get_children():
		if child is Line2D and child.gradient != null:
			masked_threads += 1
	_check(masked_threads == 0, "live opening threads render with their authoritative colours")
	var viewport := Rect2(Vector2.ZERO, Vector2(1280, 720))
	_check(viewport.encloses(atlas.get_global_rect()) and viewport.encloses(app.route_atlas_close.get_global_rect())
		and app.route_atlas_close.global_position.y >= atlas.get_global_rect().end.y, "atlas and reachable close fully fit")
	var expected_nodes := {}
	var expected_edges := {}
	var floors: Array = app.run_map.get_floors()
	_check(floors.size() == 12, "live map has twelve floors")
	var numbered_legal: Array[String] = []
	var choices: Array[String] = app.run_map.get_legal_choices()
	for floor_nodes in floors:
		var ordered: Array = floor_nodes.duplicate()
		ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["position"]) < int(b["position"]))
		for node in ordered:
			if choices.has(node["id"]):
				numbered_legal.append(node["id"])
	_check(atlas._rendered_graph == floors, "complete twelve-floor graph retained in guarded atlas")
	# Only the upcoming three floors are drawn; the other nine remain model-owned.
	for floor_index in range(3):
		for node in floors[floor_index]:
			expected_nodes[node.id] = node
			if floor_index < 2:
				for target in node.outgoing:
					expected_edges[node.id + "->" + target] = true
	var nodes := {}
	var edges := {}
	var highlighted: Array = []
	for child in atlas.get_children():
		if child is PanelContainer:
			var id: String = child.get_meta("route_id")
			_check(expected_nodes.has(id) and not nodes.has(id), "unique actual marker: " + id)
			nodes[id] = child
			if not expected_nodes.has(id):
				continue
			var node: Dictionary = expected_nodes[id]
			var number := numbered_legal.find(id)
			var expected_caption := (str(number + 1) + " " if number >= 0 else "") + String(node.type)
			var identity_label: Label = child.get_node("Identity") as Label
			_check(identity_label.text == expected_caption
				and not identity_label.text.contains(id)
				and child.get_meta("route_id") == id
				and child.get_meta("route_kind") == String(node.type)
				and atlas.get_global_rect().encloses(child.get_global_rect()), "readable mounted identity: " + id)
			var hover := "Floor %02d · %s · Branch %d" % [
				int(node.floor), String(node.type), int(node.position) + 1]
			_check(child.tooltip_text == hover and not child.tooltip_text.contains(id),
				"readable sewn route hover: " + id)
			var legal: bool = app.run_map.get_legal_choices().has(id)
			_check(child.get_meta("route_state") == ("legal" if legal else "other")
				and child.get_theme_stylebox("panel").bg_color == (RunRouteAtlas.LEGAL_BG if legal else RunRouteAtlas.OTHER_BG),
				"visible legal highlight: " + id)
			var action_button: Button = child.get_node_or_null("Action") as Button
			if legal:
				highlighted.append(id)
				_check(action_button != null, "live legal marker has button: " + id)
				if action_button != null:
					_check(action_button.focus_mode == Control.FOCUS_ALL
						and action_button.mouse_filter == Control.MOUSE_FILTER_STOP
						and action_button.tooltip_text == "Choose " + hover
							+ " (key %d)" % (number + 1)
						and not action_button.tooltip_text.contains(id)
						and child.get_global_rect().encloses(action_button.get_global_rect()),
						"live legal button is focused/clickable inside paper: " + id)
			else:
				_check(action_button == null and child.focus_mode == Control.FOCUS_NONE
						and child.mouse_filter == Control.MOUSE_FILTER_IGNORE,
						"live future/inaccessible marker is not interactive: " + id)
		elif child is Line2D:
			var source: String = child.get_meta("from_id")
			var target: String = child.get_meta("to_id")
			var pair := source + "->" + target
			_check(expected_edges.has(pair) and not edges.has(pair), "actual directed link: " + pair)
			edges[pair] = true
			if expected_nodes.has(source) and expected_nodes.has(target):
				var from: Dictionary = expected_nodes[source]
				var to: Dictionary = expected_nodes[target]
				_check(child.points.size() >= 13, "drawn link endpoints exist")
				if child.points.size() >= 13:
					_check(child.points[0] == Vector2(755 + (from.floor - 1) * 150 + 80, 145 + from.position * 101 + 40)
						and child.points[12] == Vector2(755 + (to.floor - 1) * 150, 145 + to.position * 101 + 40),
						"drawn endpoints match model: " + pair)
	_check(nodes.size() == expected_nodes.size() and edges == expected_edges and not edges.is_empty(),
		"all and only actual in-window nodes and links rendered")
	_check(highlighted == app.run_map.get_legal_choices(), "exact legal opening IDs highlighted")
	var hidden := _snapshot(app)
	_check(hidden.slice(0, 6) == before.slice(0, 6), "opening spends no graph/route/legal/encounter/RNG/combat state")
	for callback in stale:
		callback.call()
	_check(app.route_atlas_overlay == overlay and _snapshot(app) == hidden,
		"old preview callbacks cannot close or replace new overlay")
	open.call()
	app._close_route_atlas(weakref(foreign), weakref(chooser), weakref(action), weakref(overlay))
	app._close_route_atlas(weakref(app.run_map), weakref(action), weakref(action), weakref(overlay))
	app._close_route_atlas(weakref(app.run_map), weakref(chooser), weakref(app.route_back_button), weakref(overlay))
	app._close_route_atlas(weakref(app.run_map), weakref(chooser), weakref(action), weakref(chooser))
	_check(app.route_atlas_overlay == overlay, "duplicate open and foreign close sources rejected")
	_check(not app._choose_route("f01_n0"), "hidden chooser rejects legal Fight")
	_check(atlas.node_requested.get_connections().size() == 1, "one opening route request listener")
	# Every legal floor-one kind is admitted now (live_atlas_opening_choice_test);
	# the app must still reject a kind outside the run's supported floor kinds.
	var unsupported_id := ""
	for id in highlighted:
		if app.run_map.get_node(id).type != "Fight":
			unsupported_id = id
			break
	_check(not unsupported_id.is_empty(), "seed fixture has a non-Fight opening to probe")
	if not unsupported_id.is_empty():
		var opening_callback: Callable = atlas.node_requested.get_connections()[0].callable
		var saved_kind: String = app.run_map._nodes[unsupported_id].type
		app.run_map._nodes[unsupported_id].type = "Boss"
		var kind_before := _snapshot(app)
		var kind_controls: Array = [app.route_view, app.route_atlas, app.route_map_button,
			root.gui_get_focus_owner()]
		opening_callback.call(unsupported_id)
		_check(_snapshot(app) == kind_before and kind_controls == [app.route_view,
			app.route_atlas, app.route_map_button, root.gui_get_focus_owner()],
			"unsupported opening kind rejects atomically without entering a flow")
		app.run_map._nodes[unsupported_id].type = saved_kind
	app.route_atlas_close.grab_focus()
	_check(app.route_atlas_close.has_focus() and _snapshot(app) == hidden,
		"close remains accessible after unsupported node input")
	var atlas_id := atlas.get_instance_id()
	var overlay_id: int = overlay.get_instance_id()
	var cleared: Array = []
	atlas.tree_exiting.connect(func(): cleared.append(atlas._map == null))
	if keyboard:
		await _key(KEY_SPACE)
	else:
		await _click(app.route_atlas_close)
	_check(cleared == [true], "closing clears binding before detach")
	await process_frame
	_check(not is_instance_id_valid(atlas_id) and not is_instance_id_valid(overlay_id)
		and app.route_atlas == null and app.route_atlas_overlay == null and app.route_atlas_close == null,
		"close disposes preview")
	_check(_snapshot(app) == before and app.route_view == chooser and action.has_focus(), "close restores exact state and action focus")
	_check(app.route_book_backdrop != null and app.route_book_backdrop.is_visible_in_tree(),
		"closing the full map restores the opening book")
	close.call()
	_check(_snapshot(app) == before, "repeated stale close inert")
	return [open, close]


func _run() -> void:
	root.size = Vector2i(1280, 720)
	# Seed 6 originally generated Rest, Rest, Treasure (pinned before the fix).
	var fixture_seed := 6
	var fight_id := "f01_n0"
	var reference_rng := RandomNumberGenerator.new()
	reference_rng.seed = fixture_seed
	var reference := RunMap.new()
	_check(reference.generate(reference_rng), "reference map exists")
	var scene: PackedScene = load("res://scenes/app.tscn")
	_check(scene != null, "real scene loads")
	if scene == null:
		_finish()
		return
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	_check(app.start_button.has_focus(), "original Start run initially focused")
	_check(app.route_button.is_visible_in_tree(), "second title action mounted")
	app.run_seed = fixture_seed
	await _key(KEY_TAB)
	_check(app.route_button.has_focus(), "second title button reached by keyboard")
	await _key(KEY_ENTER)
	_check(app.run_map != null and app.route_view != null, "keyboard opens route chooser")
	if app.run_map == null or app.route_view == null:
		app.free()
		_finish()
		return
	_check(app.run_map.get_floors() == reference.get_floors() and
		app.run_rng.state == reference_rng.state, "map generation matches reference stream")
	_check(app.deck == null and app.run_map.get_route().is_empty(), "chooser has not started combat or committed")
	var book = app.route_book_backdrop
	_check(is_instance_valid(book) and book.is_visible_in_tree()
		and book.mouse_filter == Control.MOUSE_FILTER_IGNORE and book.focus_mode == Control.FOCUS_NONE,
		"opening chooser mounts its pointer-inert page backdrop")
	_check(is_instance_valid(book) and app.get_children().find(book) < app.get_children().find(app.route_view),
		"page backdrop renders behind the mounted choices")
	var stale_atlas: Array = await _preview(app, true)
	_check(app.route_buttons.size() == reference.get_legal_choices().size(), "one control per actual legal opening")
	if "--inject-wrong-type" in OS.get_cmdline_user_args():
		app.route_buttons[0].text = "incorrect"
	var seen: Array = []
	var page: Dictionary = book.page_geometry()
	var right_page := Rect2(book.global_position + page.right_page.position, page.right_page.size)
	var spine := Rect2(book.global_position + page.spine.position, page.spine.size)
	for button in app.route_buttons:
		var id: String = button.get_meta("route_id")
		seen.append(id)
		_check(reference.get_legal_choices().has(id), "mounted ID is legal: " + id)
		var node := reference.get_node(id)
		_check(not node.is_empty(), "reference node exists: " + id)
		if node.is_empty():
			continue
		_check(button.get_meta("route_id") == id and button.get_meta("route_kind") == node.type
			and button.text.begins_with(String(node.type)) and not button.text.contains(id)
			and button.is_visible_in_tree(), "exact ID metadata and readable type label: " + id)
		# The patch is sewn onto its authored floor position, never a stacked list row.
		var slot := int(node.get("position", -1))
		_check(button.position == Vector2(132.0, 74.0 + float(slot) * 86.0)
			and button.size == Vector2(288.0, 70.0) and button.get_parent() == app.route_view,
			"patch sits on its authored page slot: " + id)
		_check(right_page.encloses(button.get_global_rect())
			and button.get_global_rect().position.x > spine.end.x,
			"sewn patch clears the spine on the right page: " + id)
		_check(not button.disabled, "per-node operability: " + id)
		if button.disabled:
			_check(button.text.contains("unavailable"), "unsupported reason visible")
			var before := _snapshot(app)
			await _click(button)
			_check(_snapshot(app) == before, "disabled mouse choice is unspent")
			button.grab_focus()
			await _key(KEY_ENTER)
			_check(_snapshot(app) == before, "disabled keyboard choice is unspent")
			_reject(app, id, "unsupported callback")
	_check(seen == reference.get_legal_choices(), "all and only opening IDs displayed in map order")
	var seam = app.route_view.get_node_or_null("Branches")
	_check(seam != null and seam.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and seam.focus_mode == Control.FOCUS_NONE
		and seam.branch_targets.size() == app.route_buttons.size(),
		"drawn start seam joins every patch without taking pointer or keyboard input")
	_reject(app, "unknown", "unknown choice")
	_reject(app, reference.get_floors()[1][0].id, "future unavailable node")
	var before_direct := _snapshot(app)
	app._start_run()
	app._open_route()
	_check(_snapshot(app) == before_direct, "duplicate opening/direct-start cannot overwrite route")
	var old_rng: WeakRef = weakref(app.run_rng)
	var old_map: WeakRef = weakref(app.run_map)
	var old_view: int = app.route_view.get_instance_id()
	var old_selector: WeakRef = weakref(app.fight_selection)
	var stale_callback: Callable = app.route_buttons[0].pressed.get_connections()[0].callable
	# Cancellation must also dispose an actively mounted preview.
	await _click(app.route_map_button)
	var cancelled_atlas: RunRouteAtlas = app.route_atlas
	_check(is_instance_valid(cancelled_atlas), "preview reopened before cancellation")
	var cancelled_id: int = cancelled_atlas.get_instance_id()
	var cancelled_close: Callable = app.route_atlas_close.pressed.get_connections()[0].callable
	app._cancel_route()
	_check(cancelled_atlas._map == null and app.route_atlas_overlay == null, "cancel clears mounted preview binding")
	await process_frame
	_check(not is_instance_id_valid(cancelled_id), "cancel frees mounted atlas")
	# Repeat Back through actual input on the restarted chooser.
	await _click(app.route_button)
	app.route_back_button.grab_focus()
	await _key(KEY_ENTER)
	await process_frame
	_check(app.run_map == null and app.run_rng == null and app.route_view == null and
		app.route_buttons.is_empty() and app.route_back_button == null
		and app.route_book_backdrop == null, "Back clears route models and controls")
	_check(old_rng.get_ref() == null and old_map.get_ref() == null and
		not is_instance_id_valid(old_view), "Back releases map/RNG/view")
	_check(app.fight_selection == null and app.encounter_id == "" and old_selector.get_ref() == null,
		"Back releases selector and encounter identity")
	_check(app.start_button.has_focus() and app.title_view.is_visible_in_tree(), "Back restores title focus")
	_check(not app._choose_route(fight_id) and app.deck == null and app.run_rng == null, "cancelled callback cannot start battle")

	var trace: Array = []
	var phase_trace: Array = []
	# Keep the non-starter, two-source phase oracle against the live typed pool.
	var typed_fixture_found := false
	for value in range(1, 1000):
		var probe_rng := RandomNumberGenerator.new()
		probe_rng.seed = value
		var probe_map := RunMap.new()
		probe_map.generate(probe_rng)
		if probe_map.get_node(fight_id).type != "Fight":
			continue
		probe_map.choose_node(fight_id)
		var probe := RunAuthoredBattleEntry.new().entry_current_battle(probe_map, probe_rng, RunFightEncounterSelection.new())
		if probe.get("success", false) and probe.encounter_id != "starter_attacks" and probe.definitions.size() == 2:
			fixture_seed = value
			typed_fixture_found = true
			break
	_check(typed_fixture_found, "typed non-starter two-source battle fixture exists")
	app.run_seed = fixture_seed
	for session in range(2):
		await _click(app.route_button)
		_check(app.route_view != null, "mouse opens route chooser")
		if app.route_view == null:
			break
		var before_stale := _snapshot(app)
		stale_callback.call()
		for callback in stale_atlas:
			callback.call()
		cancelled_close.call()
		_check(_snapshot(app) == before_stale, "old chooser callback cannot affect restarted route")
		var preview_callbacks: Array = await _preview(app, session == 1, stale_atlas + [cancelled_close])
		stale_atlas.append_array(preview_callbacks)
		var same_rng = app.run_rng
		var same_map = app.run_map
		var fight: Button = null
		for button in app.route_buttons:
			if button.get_meta("route_id") == fight_id:
				fight = button
		_check(fight != null and not fight.disabled, "available Fight fixture mounted")
		if fight == null:
			break
		if session == 0:
			await _click(fight)
		else:
			app.route_back_button.grab_focus()
			await _key(KEY_TAB)
			_check(root.gui_get_focus_owner() in app.route_buttons and not root.gui_get_focus_owner().disabled,
				"Tab from Back reaches an enabled Fight")
			fight.grab_focus()
			await _key(KEY_ENTER)
		_check(app.deck != null and app.battle_view != null, "actual input starts real battle")
		if app.deck == null:
			break
		_check(app.run_rng == same_rng and app.deck._rng == same_rng and app.run_map == same_map,
			"combat retains exact map and shared RNG objects")
		_check(app.run_map.get_route() == [fight_id] and app.run_map.get_current_floor() == 1,
			"successful combat commits exactly one node")
		_check(app.route_view == null and app.route_buttons.is_empty(), "chooser removed during battle")
		_check(app.route_atlas == null and app.route_atlas_overlay == null and app.route_map_button == null,
			"Fight entry has no preview state")
		var battle_before_stale := _snapshot(app)
		for callback in stale_atlas:
			callback.call()
		_check(_snapshot(app) == battle_before_stale, "stale atlas callbacks cannot alter Fight")
		_check(app.deck.energy == 3 and app.deck.hand.size() == 5 and app.deck.turn_active,
			"M01 opens at three energy and five cards")
		var cards: Array[String] = app._load_starter_deck()
		var rng := RandomNumberGenerator.new()
		rng.seed = fixture_seed
		var map := RunMap.new()
		_check(map.generate(rng), "combat reference generates")
		_check(map.choose_node(fight_id), "reference commits before selection")
		var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RunAuthoredBattleEntry.POOLS_PATH))
		var ids: Array = registry.Fight.keys()
		ids.sort()
		var draw_rng := RandomNumberGenerator.new()
		draw_rng.state = rng.state
		var expected_id: String = ids[draw_rng.randi_range(0, ids.size() - 1)]
		var selection := RunFightEncounterSelection.new()
		var selected := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, selection)
		_check(selected.get("success", false) and selected.get("encounter_id") == expected_id
			and rng.state == draw_rng.state, "selector spends exactly one sorted-pool draw")
		if not selected.get("success", false):
			break
		var authored := RunFightEncounterSelection._parse_schedule_text(
			FileAccess.get_file_as_string(registry.Fight[expected_id].schedule))
		var expected_intents := CombatEnemyIntents.new(authored)
		_check(expected_intents.is_valid() and not authored.is_empty(), "selected authored two-enemy schedule valid")
		_check(app.enemy_intents._definitions == authored and selected.definitions == authored,
			"battle receives exact selected authored definitions")
		var reference_party := CombatParty.new(app._load_party_definitions())
		# Independent bindings and catalog lookup, without the production assembler.
		var expected_rosters := {}
		for key in registry.Fight:
			expected_rosters[key] = registry.Fight[key].enemy_ids
		var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_ENEMIES_PATH))
		catalog.append_array(JSON.parse_string(FileAccess.get_file_as_string(app.RUN_ENEMIES_PATH)))
		var ordered: Array = []
		for enemy_id in expected_rosters[expected_id]:
			var matches: Array = catalog.filter(func(record): return record.id == enemy_id)
			_check(matches.size() == 1, "unique authored enemy ID: " + enemy_id)
			if matches.size() == 1:
				var record: Dictionary = matches[0].duplicate(true)
				record.max_hp = int(record.max_hp)
				ordered.append(record)
		var reference_enemies := CombatEnemies.new(ordered)
		# Mirror admission order exactly: selector draw, deck shuffle, weighted
		# binding, then the opening deal.
		var reference_deck := CombatDeck.new(cards, rng)
		_check(expected_intents.bind_battle(reference_enemies, reference_party, rng),
			"reference binds the same authored weighted intents")
		_check(app.encounter_id == expected_id and app.enemy_attacks == expected_intents.get_intents()
			and app.enemy_intents.get_intents() == expected_intents.get_intents(),
			"real initial intents for both enemies match selector and authored weighted announcement")
		_check(expected_id != "starter_attacks", "seed exercises a non-starter schedule")
		_check(app.intent_label.text.contains("Enemy 1") and app.intent_label.text.contains("Enemy 2"),
			"both initial announcements mounted")
		_check(reference_enemies.is_valid() and app.enemies.get_enemies() == reference_enemies.get_enemies(),
			"selected catalog IDs, HP, names and source slots match independent roster")
		var presenter = app.get_node("LiveEnemyRoster")
		_check(presenter.enemies == app.enemies and is_instance_valid(presenter.panel)
			and presenter.panel.is_visible_in_tree() and presenter._labels.size() == ordered.size(),
			"real selected enemy panels mounted")
		for index in range(ordered.size()):
			var label: Label = presenter._labels[index]
			_check(label.is_visible_in_tree() and label.text == String(ordered[index].name),
				"visible selected actor name tag by slot")
			var meter = app.get_node("LiveCombatMeters").row.get_child(3 + index)
			var live_block: int = app.enemies.get_enemy(index + 1).block
			_check(meter.hp_text.is_visible_in_tree() and meter.hp_text.text == "%d/%d" % [ordered[index].max_hp, ordered[index].max_hp]
				and meter.block_badge.visible == (live_block > 0)
				and meter.block_text.text == ("%d" % live_block if live_block > 0 else ""),
				"visible selected actor HP and Block by slot")
			var initial_bodies: Array = []
			for raw in ordered[index].get("intent", {}).get("actions", []):
				var candidate: Dictionary = raw.duplicate(true)
				candidate.erase("weight")
				candidate["amount"] = int(candidate["amount"])
				initial_bodies.append(candidate)
			var initial: Dictionary = app.enemy_attacks[index].duplicate(true)
			initial.erase("enemy_position")
			initial.erase("target_position")
			_check(initial_bodies.has(initial)
				and not CombatEnemyIntents.policy_for(app.enemies, index + 1).is_empty(),
				"source-ordered initial announcement is an authored weighted action for its policy")
		var reference_result := CombatBattleResult.new(reference_party, reference_enemies)
		var reference_flow := CombatRoundFlow.new(reference_deck, reference_party, reference_enemies,
			expected_intents, reference_result)
		_check(reference_flow.begin_fight(), "reference starts selected battle")
		_check(app.deck.hand == reference_deck.hand and app.deck.draw_pile == reference_deck.draw_pile
			and app.run_rng.state == rng.state and app.run_map.get_floors() == map.get_floors(),
			"map then one selection draw then hand use one uninterrupted seeded stream")
		_check(app.hand_view.get_child_count() == 5 and app.end_turn_button.has_focus(), "real hand mounted and battle focused")
		for index in range(app.deck.hand.size()):
			_check(app.hand_view.get_child(index).get_child(0).text == app.deck.hand[index], "mounted card matches real hand")
		if session == 0:
			trace = _snapshot(app)
		else:
			_check(_snapshot(app) == trace, "two runs replay complete graph/route/hand/actors/RNG")
		_reject(app, fight_id, "duplicate battle choice")
		_reject(app, "unknown", "unknown during combat")
		_reject(app, app.run_map.get_legal_choices()[0], "next floor during combat")
		var before := _snapshot(app)
		app._start_run()
		app._open_route()
		app._cancel_route()
		_check(_snapshot(app) == before, "other starts and stale Back preserve battle")
		_check(reference_flow.end_turn(), "reference executes selected enemy phase")
		var heroes_before_phase: Array = app.party.get_heroes()
		if session == 0:
			await _click(app.end_turn_button)
		else:
			app.end_turn_button.grab_focus()
			await _key(KEY_ENTER)
		_check(app.party.get_heroes() != heroes_before_phase, "selected phase causes real hero damage")
		_check(app.party.get_heroes() == reference_party.get_heroes()
			and app.enemies.get_enemies() == reference_enemies.get_enemies()
			and app.enemy_attacks == expected_intents.get_intents()
			and app.deck.hand == reference_deck.hand and app.deck.draw_pile == reference_deck.draw_pile
			and app.deck.discard_pile == reference_deck.discard_pile and app.run_rng.state == rng.state
			and app.deck.energy == reference_deck.energy and app.deck.turn_active == reference_deck.turn_active
			and app.enemy_intents._turn_index == expected_intents._turn_index
			and app.battle_result.evaluate() == reference_result.evaluate(),
			"mounted End Turn executes selected attacks/block, advances schedule and deals exact next hand")
		_check(app.enemy_intents.get_intents() == expected_intents.get_intents(), "next phase follows selected schedule")
		for index in range(ordered.size()):
			var next_bodies: Array = []
			for raw in ordered[index].get("intent", {}).get("actions", []):
				var candidate: Dictionary = raw.duplicate(true)
				candidate.erase("weight")
				candidate["amount"] = int(candidate["amount"])
				next_bodies.append(candidate)
			var next_action: Dictionary = app.enemy_attacks[index].duplicate(true)
			next_action.erase("enemy_position")
			next_action.erase("target_position")
			_check(next_bodies.has(next_action) and app.enemy_attacks[index].enemy_position == index + 1,
				"next announcement stays inside the authored weighted actions for each enemy")
		if session == 0:
			phase_trace = _snapshot(app)
		else:
			_check(_snapshot(app) == phase_trace, "restarted run replays next phase and complete state")
		same_rng = null
		same_map = null
		old_map = weakref(app.run_map)
		old_rng = weakref(app.run_rng)
		old_selector = weakref(app.fight_selection)
		if session == 0:
			await _click(app.return_button)
		else:
			app.return_button.grab_focus()
			await _key(KEY_ENTER)
		await process_frame
		_check(app.deck == null and app.run_rng == null and app.run_map == null and app.battle_view == null,
			"Return clears route and battle")
		_check(old_map.get_ref() == null and old_rng.get_ref() == null, "Return releases map/RNG")
		_check(app.fight_selection == null and app.encounter_id == "" and old_selector.get_ref() == null,
			"Return releases selector and encounter identity")
		_check(app.start_button.has_focus(), "Return restores original title focus")

	await _click(app.route_button)
	_check(app.run_map != null and app.route_view != null, "failed-data retry chooser mounted")
	if app.run_map != null:
		_legacy_rejections(app, fight_id)
		var cache: Dictionary = app.fight_selection._selected.duplicate(true)
		app.fight_selection._selected[fight_id] = {"success": true, "node_type": "Fight", "encounter_id": "unknown", "definitions": []}
		_reject(app, fight_id, "malformed typed selection")
		app.fight_selection._selected = cache
		var saved_heroes: Array = app.run_heroes.duplicate(true)
		app.run_heroes = []
		_reject(app, fight_id, "invalid persistent roster")
		app.run_heroes = saved_heroes
		var before_retry := _snapshot(app)
		var retry_button: Button = null
		for button in app.route_buttons:
			if button.get_meta("route_id") == fight_id:
				retry_button = button
		_check(retry_button != null, "failed starter attempts retain the mounted Fight")
		if retry_button != null:
			await _click(retry_button)
			_check(app.deck != null and app.run_map.get_route() == [fight_id], "corrected data retries successfully via mouse")
			if app.deck != null:
				_check(app.run_map.get_floors() == before_retry[0], "retry retains generated graph")
				_check(app.encounter_id == trace[4] and app.run_rng.state == trace[3]
					and app.deck.hand == trace[5][1], "corrected retry repeats exact selection and shuffle")
				await _click(app.return_button)
	# The formerly blocked opening now offers Fight; Back still cancels it.
	app.run_seed = 6
	await _click(app.route_button)
	_check(app.run_map != null and app.route_buttons.size() == 3,
		"formerly blocked seed has its actual opening mounted")
	if app.run_map != null and app.route_buttons.size() == 3:
		_check(app.route_buttons[0].get_meta("route_id") == fight_id
			and not app.route_buttons[0].disabled and app.route_buttons[0].has_focus(),
			"fallback Fight enabled and initially focused")
		for index in [1, 2]:
			_check(not app.route_buttons[index].disabled, "all legal opening types are enabled")
		_check(app.run_map.get_floors()[0][1].type == "Rest"
			and app.run_map.get_floors()[0][2].type == "Treasure",
			"fallback preserves unsupported kinds")
		app.route_buttons.back().grab_focus()
		await _key(KEY_TAB)
		_check(app.route_map_button.has_focus(), "Tab reaches full map after legal choices")
		await _key(KEY_TAB)
		_check(app.route_back_button.has_focus(), "Tab reaches Back after map action")
		await _click(app.route_back_button)
		_check(app.run_map == null and app.run_rng == null and app.deck == null,
			"formerly blocked seed Back clears session")
	await _click(app.route_button)
	await _click(app.route_map_button)
	var reset_atlas: RunRouteAtlas = app.route_atlas
	_check(is_instance_valid(reset_atlas), "title reset fixture has mounted atlas")
	var reset_atlas_id: int = reset_atlas.get_instance_id()
	app._return_to_title()
	_check(reset_atlas._map == null and app.route_atlas_overlay == null and app.run_map == null,
		"title reset clears preview and map binding")
	await process_frame
	_check(not is_instance_id_valid(reset_atlas_id), "title reset frees preview")
	app.run_seed = fixture_seed
	_check(app._start_battle(), "explicit standalone M01 fixture starts")
	_check(app.deck != null and app.run_map == null and app.route_view == null, "original direct start preserved")
	if app.deck != null:
		var starter := CombatEnemyIntents.new(app._load_enemy_schedule())
		_check(app.enemy_attacks == starter.get_intents() and app.fight_selection == null
			and app.encounter_id == "", "direct start keeps starter schedule without routed selector")
		_check(app.enemies.get_enemies() == CombatEnemies.new(app._load_enemy_definitions()).get_enemies(),
			"direct Start run retains original starter pair")
		var rng := RandomNumberGenerator.new()
		rng.seed = fixture_seed
		var direct := CombatDeck.new(app._load_starter_deck(), rng)
		_check(direct.start_turn(), "direct reference starts")
		_check(app.deck.hand == direct.hand and app.run_rng.state == rng.state, "direct start retains original seeded hand")
		await _click(app.return_button)
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_run_map_entry_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## The retired configurable three-Fight path remains protected at its service boundaries.
func _legacy_rejections(app, fight_id: String) -> void:
	var before := _snapshot(app)
	var rng := RandomNumberGenerator.new()
	rng.state = app.run_rng.state
	var map := RunMap.new()
	var generation := RandomNumberGenerator.new()
	generation.seed = app.run_seed
	_check(map.generate(generation) and map.choose_node(fight_id), "legacy negative fixture is an actual selected Fight")
	for pool in [{}, {"missing": "res://data/encounters/missing_036.json"},
		{"bad": "res://data/encounters/../encounters/starter_attacks.json"},
		{"bad": "res://data/encounters/starter_attacks.json", "corrupt": 42}]:
		var state := rng.state
		var selector := RunFightEncounterSelection.new()
		_check(not selector.select_current_fight(map, rng, pool).get("success", false), "malformed legacy pool rejects")
		_check(rng.state == state and selector._selected.is_empty() and selector._bound_map == null, "pool failure spends no RNG or selector state")
	var selected := {"success": true, "node_type": "Fight", "encounter_id": "starter_attacks", "definitions": app._load_enemy_schedule()}
	for invalid in [null, 42, [], ["unknown", "ragling_guard"], ["ragling", "ragling"],
		["ragling"], ["ragling", "ragling_guard", "button_guard"], ["ragling", 42]]:
		_check(not RunTypedBattleRoster.new().assemble(selected, {"starter_attacks": invalid},
			[app.STARTER_ENEMIES_PATH, app.RUN_ENEMIES_PATH]).ok, "malformed/unknown/duplicate/count roster rejects: " + str(invalid))
	for binding in [{}, {"starter_attacks": ["ragling", "ragling_guard"]}]:
		for paths in [[app.STARTER_ENEMIES_PATH, "res://data/enemies/missing_060.json"],
			[app.STARTER_ENEMIES_PATH, app.STARTER_ENEMIES_PATH]]:
			_check(not RunTypedBattleRoster.new().assemble(selected, binding, paths).ok, "missing binding/catalog and duplicate catalog reject")
	_check(_snapshot(app) == before, "legacy negative probes leave live seeded state untouched")
