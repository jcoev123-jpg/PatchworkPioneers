extends "res://tests/stitched_s6_followon_foes_live_test.gd"
## Mounted production callbacks; the save path belongs exclusively to this test.
const TEST_SAVE := "user://s7_title_continue_test.save"


func _physical(code: Key, reverse: bool = false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.shift_pressed = reverse
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame


func _ring(app: Node, buttons: Array) -> void:
	_check(buttons.size() >= 3, "nonempty mounted title ring")
	buttons[0].grab_focus()
	for direction in [1, -1]:
		for step in range(1, buttons.size() + 1):
			await _physical(KEY_TAB, direction == -1)
			var index := posmod(step * direction, buttons.size())
			_check(root.gui_get_focus_owner() == buttons[index],
				"physical Tab ring direction %d step %d" % [direction, step])
	for button in [app.route_button, app.stitched_fight_button]:
		_check(not button.visible and button.disabled and button.focus_mode == Control.FOCUS_NONE
			and button.pressed.get_connections().is_empty() and not button.has_focus(),
			"retired shortcut never enters live keyboard ring: " + button.text)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute(TEST_SAVE)
	var app: Node = load("res://scenes/app.tscn").instantiate()
	app.run_seed = 42
	app.stitched_walks = false
	app.stitched_save_path = TEST_SAVE
	root.add_child(app)
	await process_frame
	await process_frame
	var shell = app.get_node("PatchworkUIShell")
	var actions: Array = [app.start_button, app.stitched_continue_button,
		app.base_button]
	_check(shell._actions == actions, "shell binds exactly three default production actions")
	var visible_actions: Array = []
	for child in app.title_view.get_children():
		if child is Button and child.is_visible_in_tree():
			visible_actions.append(child)
	_check(visible_actions == actions, "fresh mounted title exposes only the three real actions")
	_check(not app.start_run_requested.is_connected(Callable(app, "_start_run"))
		and not app.route_button.pressed.is_connected(Callable(app, "_open_route")),
		"the old card start and route hooks have no production listeners")
	var viewport := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var previous := Rect2()
	for button: Button in actions:
		var rect := button.get_global_rect()
		_check(button.is_visible_in_tree() and not button.disabled and rect.has_area()
			and viewport.encloses(rect) and rect.size.y == 56
			and button.custom_minimum_size.y == 56,
			"visible readable 56px action: " + button.text)
		_check(not previous.has_area() or previous.end.y <= rect.position.y,
			"title actions never overlap: " + button.text)
		previous = rect
		_check(shell.action_backing_rect().encloses(rect)
			and button.get_child_count() == 1
			and button.get_child(0).mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"felt and nonblocking stitches cover " + button.text)
		_check(button.theme_type_variation == "PatchHeadingButton"
			and button.get_theme_font("font").resource_path == shell.HEADING_FONT
			and button.get_theme_font_size("font_size") == actions[0].get_theme_font_size("font_size"),
			"shared sewn heading typography: " + button.text)
		for state in ["normal", "hover", "disabled", "focus"]:
			_check(button.get_theme_stylebox(state) == app.theme.get_stylebox(state, "Button"),
				"inherited " + state + " style: " + button.text)
	var carry := _carry(app)
	for button in [app.route_button, app.stitched_fight_button]:
		button.pressed.emit()
	_check(app.stitched_event_panel == null and app.stitched_fight_view == null
		and app.stitched_run_panel == null and app.title_view.is_visible_in_tree()
		and _carry(app) == carry and _no_legacy_wallet(app),
		"disabled shortcut signals have no authority, spend or RNG draw")
	await _ring(app, actions)
	_check(_carry(app) == carry and _no_legacy_wallet(app), "focus and display do not spend or draw")
	app.stitched_continue_button.grab_focus()
	await _physical(KEY_SPACE)
	_check(app.stitched_run_session == null and app.title_view.visible and _carry(app) == carry,
		"missing save cannot start or mutate a run")
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_buffer(var_to_bytes({"version": "malformed", "state": {}}))
	file.close()
	await _physical(KEY_SPACE)
	_check(app.stitched_run_session == null and app.title_view.visible and _carry(app) == carry,
		"malformed save fails closed through original Continue callback")
	app.base_button.grab_focus()
	await _physical(KEY_SPACE)
	_check(is_instance_valid(app.base_screen) and app.base_screen.has_open_village(),
		"original village callback remains actionable")
	if is_instance_valid(app.base_screen):
		app.base_screen.back_button.pressed.emit()
	await process_frame
	_check(app.base_button.has_focus() and app.title_view.is_visible_in_tree(),
		"base Back restores a visible eligible title action")
	app.start_button.grab_focus()
	await _physical(KEY_SPACE)
	_check(app.stitched_run_panel != null and app.stitched_run_session == null,
		"original New Run opens Stitched picker")
	app.stitched_run_buttons[0].pressed.emit()
	await process_frame
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null, "seeded live picker created real run")
	_check(app.deck == null and app.run_map == null and app.run_rng == null
		and app.party_picker == null and app.run_deck.is_empty(),
		"real four-doll New Run never mounts a card deck or legacy map")
	if session != null:
		var before := session.snapshot()
		_check(session.heroes.size() == 4 and not session.choices().is_empty()
			and app.stitched_event_panel == null and app._stitched_roadblock_win_count == 0,
			"four-doll routed New Run needs no Roadblock receipt")
		app.title_view.show()
		await _ring(app, actions)
		shell._process(1.25)
		app.stitched_continue_button.pressed.emit()
		app.title_view.hide()
		_check(app.stitched_run_session == session and session.snapshot() == before,
			"live display, focus and rejected Continue preserve RNG and receipts")
		_check(StitchedRunSave.write_file(TEST_SAVE, session), "isolated valid save written")
		app._return_stitched_run_title()
		await process_frame
		app.stitched_continue_button.grab_focus()
		await _physical(KEY_SPACE)
		_check(app.stitched_run_session != null and app.stitched_run_session.snapshot() == before
			and not app.title_view.visible and app.stitched_run_panel != null,
			"original Continue callback resumes exact saved state and RNG")
		var restored: StitchedRunSession = app.stitched_run_session
		var opening := ""
		for id in restored.choices():
			if restored.map.get_node(id).type == "Fight":
				opening = id
				break
		_check(not opening.is_empty(), "restored real route has an authenticated opening Fight")
		if not opening.is_empty():
			var index := restored.choices().find(opening)
			app.stitched_run_buttons[index].pressed.emit()
			await process_frame
			var routed: StitchedBattleScreen = app.stitched_run_battle
			_check(routed != null and routed.battle == restored.battle
				and app.stitched_event_panel == null and app.stitched_fight_view == null,
				"actual player entry mounts the session's authenticated ranked combat")
			if routed != null:
				var result := _win(routed)
				_check(result.acted > 0 and result.outcome == "victory",
					"legal routed combat actions win the real opening")
				routed._action_buttons["exit"].pressed.emit()
				await process_frame
				_check(restored.receipts.size() == 1 and restored.receipts[0].node_id == opening,
					"real routed settlement records the exact admitted node")
		app._return_stitched_run_title()
		await process_frame
		_check(app.start_button.has_focus(), "run return focuses live New Run")
		for button in [app.route_button, app.stitched_fight_button]:
			button.pressed.emit()
		_check(app.stitched_run_session == null and app.stitched_event_panel == null
			and app.title_view.is_visible_in_tree(), "stale shortcut signals remain inert on return")
	var stage: StitchedBattleScreen = await _mount(app)
	_check(stage != null, "explicit Roadblock regression entry mounts genuine fight")
	if stage != null:
		var won := _win(stage)
		_check(won.outcome == "victory" and won.acted > 0, "real legal actions earn victory")
		stage._action_buttons["exit"].pressed.emit()
		await process_frame
		_check(app.stitched_sewing_panel != null, "victory opens earned Sewing Circle")
		if app.stitched_sewing_panel != null:
			app.stitched_sewing_panel.get_node("SewingLeave").pressed.emit()
			await process_frame
			await process_frame
			var earned := actions.duplicate()
			for button in [app.stitched_peddler_button, app.stitched_campfire_button,
				app.stitched_postevent_button, app.stitched_unpicker_button]:
				if button.is_visible_in_tree() and not button.disabled:
					earned.append(button)
			_check(earned.size() > 3 and app._stitched_postvictory_stop_available,
				"authentic victory and Circle Leave earn reachable stops")
			_check(app.base_button.has_focus(), "Circle return skips the dormant Roadblock")
			var earned_carry := _carry(app)
			await _ring(app, earned)
			_check(_carry(app) == earned_carry, "earned-stop traversal does not mutate receipts or resources")
			app.stitched_peddler_button.pressed.emit()
			await process_frame
			_check(app.stitched_peddler_panel != null and app.stitched_peddler_visit != null,
				"earned Peddler mounts an authentic service")
			if app.stitched_peddler_panel != null:
				app.stitched_peddler_panel.get_node("PeddlerLeave").pressed.emit()
				await process_frame
				await process_frame
				var remaining := actions.duplicate()
				for button in earned.slice(3):
					if button.is_visible_in_tree() and not button.disabled:
						remaining.append(button)
				_check(not app._stitched_postvictory_stop_available and remaining == actions
					and app.start_button.has_focus(),
					"Peddler Leave consumes the stop and focuses eligible New Run")
				await _ring(app, remaining)
	app.free()
	DirAccess.remove_absolute(TEST_SAVE)
	await process_frame
	for message in failures:
		printerr(message)
	print("stitched_s7_title_continue_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
