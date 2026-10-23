extends "res://tests/live_run_map_entry_test.gd"
## Mounted presentation/lifecycle checks; visual layout is reviewed in web screenshots.


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	var shell = app.get_node("PatchworkUIShell")
	var shared: Theme = app.theme
	_check(shared != null and shared.default_font_size >= 18, "scene installs body theme before App readiness")
	_check(shared.get_font_size("font_size", "TitleLabel") >= 40, "shared title default at least 40")
	_check((shared.get_stylebox("panel", "Panel") as StyleBoxFlat).bg_color == shell.PAPER
		and (shared.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).bg_color != shell.PAPER,
		"shared Theme supplies paper panels and contrasting felt containers")
	_check(app.title_label.theme_type_variation == "TitleLabel" and app.title_label.get_theme_color("font_color") == shell.INK,
		"existing live label uses dark ink title variation")
	_check(shell.mouse_filter == Control.MOUSE_FILTER_IGNORE and shell.focus_mode == Control.FOCUS_NONE,
		"shell cannot intercept pointer or keyboard")
	_check(shell.TITLE_BACKDROP == "res://assets/paper/backgrounds/title.png"
		and shell._backdrop is Texture2D and shell._backdrop.resource_path == shell.TITLE_BACKDROP,
		"title boot mounts the supplied backdrop texture behind its decorations")
	if shell._backdrop is Texture2D:
		var cover: Rect2 = shell.backdrop_rect()
		_check(cover.encloses(Rect2(Vector2.ZERO, shell.size)),
			"supplied title backdrop covers the whole 1280x720 title")
		_check(is_equal_approx(cover.size.x / cover.size.y,
			float(shell._backdrop.get_width()) / float(shell._backdrop.get_height())),
			"supplied title backdrop keeps its own proportions")
	_check(shell._load_backdrop("res://assets/paper/backgrounds/fabricated_missing_title.png") == null
		and shell._load_backdrop("") == null,
		"a missing title image loads no texture and cannot fail boot")
	_check(shell.get_index() > 0 and app.get_child(shell.get_index() - 1) is ColorRect
		and shell.get_index() < app.title_view.get_index(), "decorations between original background and title")
	var fills: Array[Color] = []
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := shared.get_stylebox(state, "Button") as StyleBoxFlat
		_check(style != null and not fills.has(style.bg_color), "distinct felt button state: " + state)
		fills.append(style.bg_color)
	var focus := shared.get_stylebox("focus", "Button") as StyleBoxFlat
	_check(focus != null and focus.border_width_top >= 3 and focus.border_color.a == 1.0,
		"opaque keyboard focus border")
	for button in [app.start_button, app.route_button, app.base_button]:
		_check(button.get_child_count() == 1 and button.get_child(0).mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"title stitches cannot block original button")
	_check(app.base_button.get_theme_stylebox("normal") == shared.get_stylebox("normal", "Button")
		and app.base_button.get_theme_stylebox("hover") == shared.get_stylebox("hover", "Button")
		and app.base_button.get_theme_stylebox("focus") == shared.get_stylebox("focus", "Button"),
		"third title action shares the sewn button theme")
	_check(app.start_button.has_focus() and shell.visible, "initial focused title with backdrop")
	await _key(KEY_TAB)
	_check(app.route_button.has_focus(), "physical Tab retains title focus cycle")
	await _key(KEY_SPACE)
	_check(app.run_map != null and app.route_view.is_visible_in_tree() and not shell.visible,
		"physical route choice hides decoration and mounts route")
	var before := _snapshot(app)
	app.title_view.show()
	_check(shell.visible, "backdrop follows title show synchronously")
	app.title_view.hide()
	_check(not shell.visible and _snapshot(app) == before, "decoration visibility leaves real run and RNG unchanged")
	await _click(app.route_back_button)
	_check(app.run_map == null and shell.visible and app.start_button.has_focus(), "physical Back restores title and focus")
	await _click(app.start_button)
	_check(app.route_view != null and not app.route_buttons.is_empty() and not shell.visible, "physical Start reaches real map")
	var fight: Button
	for button in app.route_buttons:
		if app.run_map.get_node(button.get_meta("route_id")).type == "Fight":
			fight = button
			break
	_check(fight != null, "seeded real map has actionable opening Fight")
	if fight != null:
		fight.grab_focus()
		await _key(KEY_SPACE)
		_check(app.deck != null and app.battle_view.is_visible_in_tree() and not shell.visible, "physical route keyboard activation enters battle")
		await _click(app.return_button)
		_check(app.deck == null and app.run_rng == null and shell.visible and app.start_button.has_focus(),
			"physical Return clears run and restores original focused title")
	app.free()
	# All V1 screens mount real downstream Controls with the same inherited theme.
	var boot = root.get_node("LiveWebPlaytestBoot")
	for screen in boot.SCREENS:
		app = scene.instantiate()
		root.add_child(app)
		await process_frame
		_check(await boot.enter_preview(app, screen), "nonempty real preview precondition: " + screen)
		var controls: Array[Control] = []
		_collect(app, controls)
		_check(not controls.is_empty(), "live screen has themed controls: " + screen)
		var visible_buttons := 0
		for control in controls:
			_check(control.theme == null, "downstream controls retain inherited root Theme: " + screen)
			if control is Button and control.is_visible_in_tree():
				visible_buttons += 1
				# Existing authored reward/event/result overrides intentionally sit on this Theme.
				if not control.has_theme_stylebox_override("normal"):
					_check(control.get_theme_stylebox("normal") == app.theme.get_stylebox("normal", "Button"),
						"live button resolves shared style: " + screen)
		_check(visible_buttons > 0, "each real preview has visible actions: " + screen)
		_check(app.get_node("PatchworkUIShell").visible == (screen == "title"), "title decoration visibility: " + screen)
		app.free()
	for failure in failures:
		printerr(failure)
	print("patchwork_ui_shell_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _collect(node: Node, controls: Array[Control]) -> void:
	for child in node.get_children():
		if child is Control:
			controls.append(child)
		_collect(child, controls)
