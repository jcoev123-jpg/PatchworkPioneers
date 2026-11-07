extends "res://tests/stitched_s7_title_continue_test.gd"
## Mounted production controls; reuse physical input and legal battle drivers.
const MENU_SAVE := "user://stitched_gothic_title_menu_test.save"
const BUTTON_ART := "res://assets/paper/ui/reward_button.png"


func _menu_surface(button: Button) -> void:
	var colors: Array[Color] = []
	for face in ["normal", "hover", "pressed", "disabled", "focus"]:
		var skin := button.get_theme_stylebox(face) as StyleBoxTexture
		_check(button.has_theme_stylebox_override(face) and skin != null,
			button.text + " has an image-backed " + face)
		if skin == null:
			continue
		_check(skin.texture != null and skin.texture.resource_path == BUTTON_ART,
			button.text + " reuses the authored reward button: " + face)
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			_check(skin.get_texture_margin(side) == 14,
				button.text + " preserves nine-slice edges: " + face)
		_check(not colors.has(skin.modulate_color), button.text + " has distinct " + face + " tint")
		colors.append(skin.modulate_color)
		if face == "focus":
			_check(not skin.draw_center and skin.modulate_color.v >= 0.95
				and skin.expand_margin_left >= 3 and skin.expand_margin_right >= 3
				and skin.expand_margin_top >= 3 and skin.expand_margin_bottom >= 3,
				button.text + " has a bright expanded image rim for keyboard focus")
	for face in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		var ink := button.get_theme_color(face)
		_check(ink.r > 0.9 and ink.g > 0.85 and ink.b > 0.7 and ink.a == 1,
			button.text + " uses readable pale " + face)
	_check(button.get_theme_color("font_disabled_color").v < button.get_theme_color("font_color").v,
		button.text + " dims its disabled label")


func _menu_layout(app: Node, expected: Array) -> void:
	await process_frame
	await process_frame
	var visible: Array = []
	for child in app.title_view.get_children():
		if child is Button and child.is_visible_in_tree():
			visible.append(child)
	_check(not expected.is_empty() and visible == expected, "actual visible title actions match this state")
	var viewport := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var previous: Rect2 = app.title_label.get_global_rect()
	_check(viewport.encloses(previous), "title heading stays inside viewport")
	for button: Button in visible:
		var rect := button.get_global_rect()
		_check(rect.has_area() and viewport.encloses(rect.grow(3)),
			button.text + " and its focus rim fit the viewport")
		_check(previous.end.y <= rect.position.y - 6, button.text + " never overlaps the previous title item")
		_check(rect.size.y == 56, button.text + " keeps the original compact hit height")
		previous = rect
		_menu_surface(button)
	for button in [app.stitched_fight_button]:
		_check(not button.is_visible_in_tree() and button.disabled and button.focus_mode == Control.FOCUS_NONE
			and button.pressed.get_connections().is_empty(), "retired action is hidden and inert")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute(MENU_SAVE)
	var app: Node = load("res://scenes/app.tscn").instantiate()
	app.run_seed = 42
	app.stitched_walks = false
	app.stitched_save_path = MENU_SAVE
	root.add_child(app)
	await process_frame
	var ordinary: Array = [app.start_button, app.stitched_continue_button, app.base_button]
	var available: Array = [app.start_button, app.base_button]
	await _menu_layout(app, ordinary)
	_check(app.stitched_continue_button.disabled and app.stitched_continue_button.focus_mode == Control.FOCUS_NONE
		and not app.start_button.disabled and not app.base_button.disabled,
		"missing-save Continue has the original dark disabled face and cannot take focus")
	_check([app.start_button.text, app.stitched_continue_button.text, app.base_button.text] ==
		["New Run", "Continue Run", "Wren's Room"],
		"all three live title labels have consistent title case")
	for face in ["normal", "hover", "pressed"]:
		var primary := app.start_button.get_theme_stylebox(face) as StyleBoxTexture
		var secondary := app.stitched_continue_button.get_theme_stylebox(face) as StyleBoxTexture
		var bedroom := app.base_button.get_theme_stylebox(face) as StyleBoxTexture
		_check(primary != null and secondary != null and bedroom != null
			and primary.texture == secondary.texture and secondary.texture == bedroom.texture
			and primary.modulate_color != secondary.modulate_color
			and secondary.modulate_color == bedroom.modulate_color,
			"primary oxblood and secondary umber nine-slice diverge only at title: " + face)
	var shell := app.get_node("PatchworkUIShell")
	var source_logo_sha := FileAccess.get_sha256(ProjectSettings.globalize_path(shell.TITLE_LOGO))
	_check(shell.LOGO_TINT.r < 1.0 and shell.LOGO_TINT.g < 1.0
		and shell.LOGO_TINT.b < 1.0 and shell.LOGO_TINT.a == 1.0
		and shell._logo != null and shell.logo_rect().has_area(),
		"readable wordmark gets its darkening tint only while the live shell paints it")
	await process_frame
	_check(source_logo_sha != "" and source_logo_sha ==
		FileAccess.get_sha256(ProjectSettings.globalize_path(shell.TITLE_LOGO)),
		"title logo source image bytes are unchanged by paint-time tint")
	_check(app.start_button.has_focus(), "ordinary boot focuses New Run")
	var carry := _carry(app)
	await _ring(app, available)
	await _disabled_click(app.stitched_continue_button)
	_check(not app.stitched_continue_button.has_focus(), "missing-save Continue refuses focus")
	app.stitched_continue_button.pressed.emit()
	_check(app.stitched_run_session == null and app.title_view.is_visible_in_tree()
		and _carry(app) == carry and _no_legacy_wallet(app),
		"missing-save Continue rejects physical mouse and a stale signal without changing state")
	await _click(app.start_button)
	_check(app.stitched_run_panel != null and not app.title_view.visible
		and app.stitched_run_session == null and app.stitched_run_draft.size() == 4,
		"mouse New Run mounts the real four-doll draft without a run")
	if app.stitched_run_panel != null:
		var choices: Array = app.stitched_run_panel.find_children("*", "CheckButton", true, false)
		_check(not choices.is_empty() and choices.filter(func(choice): return choice.button_pressed).size() == 4,
			"mounted picker has four selected dolls")
		app.stitched_run_buttons[1].grab_focus()
		await _physical(KEY_ENTER)
	_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus()
		and app.stitched_run_panel == null and _carry(app) == carry, "keyboard Cancel restores untouched focused title")
	await _physical(KEY_SPACE)
	_check(app.stitched_run_panel != null, "keyboard New Run reopens real picker")
	if app.stitched_run_panel != null:
		await _click(app.stitched_run_buttons[1])
	_check(app.start_button.has_focus() and app.stitched_run_session == null,
		"mouse Cancel returns focus without allocating a run")
	await _click(app.base_button)
	_check(app.base_screen != null and app.base_screen.is_visible_in_tree()
		and app.base_screen.has_open_village() and app.base_screen.bedroom != null,
		"mouse room action opens the mounted bedroom")
	if app.base_screen != null:
		app.base_screen.back_button.grab_focus()
		await _physical(KEY_ENTER)
	_check(app.title_view.is_visible_in_tree() and app.base_button.has_focus()
		and _carry(app) == carry and _no_legacy_wallet(app), "bedroom Back restores title focus and resources")

	# Obtain a valid save from the public picker, then exercise disabled and live Continue.
	await _click(app.start_button)
	if app.stitched_run_panel != null:
		await _click(app.stitched_run_buttons[0])
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.is_consistent(), "public Set out produces an authentic save source")
	if session != null:
		var before := session.snapshot()
		_check(StitchedRunSave.write_file(MENU_SAVE, session), "isolated valid save written")
		app._return_stitched_run_title()
		await process_frame
		_check(not app.stitched_continue_button.disabled
			and app.stitched_continue_button.focus_mode == Control.FOCUS_ALL,
			"real saved four-doll run automatically enables Continue on return")
		await _ring(app, ordinary)
		app.stitched_continue_button.grab_focus()
		app.stitched_continue_button.disabled = true
		app.stitched_continue_button.focus_mode = Control.FOCUS_NONE
		# A forced-disabled skin still keeps the original live action in the tree.
		app._wire_stitched_title_focus()
		await _menu_layout(app, ordinary)
		await _disabled_click(app.stitched_continue_button)
		await _physical(KEY_SPACE)
		app.start_button.grab_focus()
		await _physical(KEY_TAB)
		_check(app.base_button.has_focus(), "Tab skips disabled Continue")
		await _physical(KEY_TAB)
		_check(app.start_button.has_focus(), "disabled title ring wraps without retired shortcuts")
		_check(app.stitched_run_session == null and app.title_view.visible, "disabled mouse/keyboard Continue cannot load a valid save")
		app._refresh_stitched_continue_eligibility()
		_check(not app.stitched_continue_button.disabled
			and app.stitched_continue_button.focus_mode == Control.FOCUS_ALL,
			"reader, not a manual override, re-enables the genuine saved night")
		await _ring(app, ordinary)
		app.stitched_continue_button.grab_focus()
		await _physical(KEY_SPACE)
		_check(app.stitched_run_session != null and app.stitched_run_session.snapshot() == before
			and not app.title_view.visible and app.stitched_run_panel != null,
			"keyboard Continue restores exact saved state and RNG")
		var restored: StitchedRunSession = app.stitched_run_session
		app.stitched_continue_button.pressed.emit()
		_check(app.stitched_run_session == restored and restored.snapshot() == before,
			"hidden active-run Continue callback cannot replace or mutate the session")
		app._return_stitched_run_title()
		await process_frame
		await _click(app.stitched_continue_button)
		_check(app.stitched_run_session != null and app.stitched_run_session.snapshot() == before
			and not app.title_view.visible and app.stitched_run_panel != null,
			"mouse Continue also restores the exact authentic saved run")
	app.free()
	await process_frame
	if session != null:
		# A second production App must authenticate a save before its first frame.
		var fresh: Node = load("res://scenes/app.tscn").instantiate()
		fresh.stitched_save_path = MENU_SAVE
		root.add_child(fresh)
		await process_frame
		_check(not fresh.stitched_continue_button.disabled
			and fresh.stitched_continue_button.focus_mode == Control.FOCUS_ALL
			and fresh.stitched_run_session == null,
			"newly mounted title authenticates an existing four-doll save on first appearance")
		await _ring(fresh, [fresh.start_button, fresh.stitched_continue_button, fresh.base_button])
		var pristine := _carry(fresh)
		var tamper := FileAccess.open(MENU_SAVE, FileAccess.WRITE)
		_check(tamper != null, "tamper fixture is writable after eligible title appears")
		if tamper != null:
			tamper.store_buffer(var_to_bytes({"version": "corrupt", "journal": []}))
			tamper.close()
		_check(StitchedRunSave.read_file(MENU_SAVE) == null,
			"corrupt replacement is rejected by replaying saved-run reader")
		await _click(fresh.stitched_continue_button)
		_check(fresh.stitched_run_session == null and fresh.title_view.is_visible_in_tree()
			and fresh.stitched_continue_button.disabled
			and fresh.stitched_continue_button.focus_mode == Control.FOCUS_NONE
			and fresh.start_button.has_focus() and _carry(fresh) == pristine
			and _no_legacy_wallet(fresh),
			"replaced-between-display-and-click fails closed, transfers focus and preserves state")
		await _ring(fresh, [fresh.start_button, fresh.base_button])
		fresh.free()
		await process_frame
	DirAccess.remove_absolute(MENU_SAVE)

	# Real Roadblock victory and Circle Leave earn all four optional title stops.
	app = load("res://scenes/app.tscn").instantiate()
	app.stitched_save_path = MENU_SAVE
	root.add_child(app)
	await process_frame
	var stage: StitchedBattleScreen = await _mount(app)
	_check(stage != null, "earned-state witness mounts a genuine Roadblock")
	if stage != null:
		var won := _win(stage)
		_check(won.acted > 0 and won.outcome == "victory", "legal actions earn the stop state")
		stage._action_buttons["exit"].pressed.emit()
		await process_frame
		_check(app.stitched_sewing_panel != null, "genuine victory mounts Circle")
		if app.stitched_sewing_panel != null:
			app.stitched_sewing_panel.get_node("SewingLeave").pressed.emit()
			await process_frame
			var earned: Array = [app.start_button, app.base_button,
				app.stitched_peddler_button, app.stitched_campfire_button,
				app.stitched_postevent_button, app.stitched_unpicker_button]
			_check(app._stitched_postvictory_stop_available and app.stitched_continue_button.disabled,
				"authenticated earned stops are available without a valid Continue save")
			await _menu_layout(app, [app.start_button, app.stitched_continue_button, app.base_button,
				app.stitched_peddler_button, app.stitched_campfire_button,
				app.stitched_postevent_button, app.stitched_unpicker_button])
			var earned_carry := _carry(app)
			await _ring(app, earned)
			_check(_carry(app) == earned_carry, "earned focus traversal preserves all carried state")
	app.free()
	await process_frame
	for message in failures:
		printerr(message)
	print("stitched_gothic_title_menu_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _disabled_click(button: Button) -> void:
	# The inherited click helper intentionally requires an enabled target.
	_check(button.disabled and button.is_visible_in_tree() and button.get_global_rect().has_area(),
		"disabled Continue is a real visible mouse target")
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame
