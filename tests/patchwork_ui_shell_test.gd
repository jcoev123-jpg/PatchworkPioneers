extends "res://tests/live_run_map_entry_test.gd"
## Mounted presentation/lifecycle checks; visual layout is reviewed in web screenshots.

## The master body face every sewn tile label inherits: Patrick Hand.
const BODY_FONT := "res://assets/fonts/PatrickHand-Regular.ttf"
## The master heading face a sewn card name now wears: Londrina Regular.
const HEADING_FONT := "res://assets/fonts/LondrinaSolid-Regular.ttf"
## U+2192, printed between the two halves of a real Rest upgrade tile.
const ARROW := 0x2192


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	var shell = app.get_node("PatchworkUIShell")
	var shared: Theme = app.theme
	_check(shared != null and shared.default_font_size >= 18, "scene installs body theme before App readiness")
	# The mounted shell Theme must carry the master Theme's whole typography family.
	_check(shared.get_type_variation_base("PatchTitle") == "Label"
		and shared.get_type_variation_base("PatchHeading") == "Label"
		and shared.get_type_variation_base("PatchHeadingButton") == "Button",
		"shared Theme keeps the master PatchTitle/PatchHeading/PatchHeadingButton variations")
	_check(shared.get_font_size("font_size", "PatchTitle") >= 40,
		"shared PatchTitle default at least 40")
	_check((shared.get_font("font", "PatchHeading") as Font).resource_path == shell.HEADING_FONT
		and (shared.get_font("font", "PatchHeadingButton") as Font).resource_path == shell.HEADING_FONT,
		"master heading variation resolves the Londrina Regular face")
	var master: Theme = load(shell.THEME_PATH)
	var master_before := var_to_str(master)
	_check_visit_theme(shared)
	_check(not master.has_stylebox("normal", "OptionButton")
		and not master.has_stylebox("panel", "PopupMenu")
		and not master.has_stylebox("scroll", "VScrollBar"),
		"selector surfaces belong to the shared copy, not the master")
	_check(shell._fabric_style("res://missing_selector_surface.png", shell.PAPER) is StyleBoxFlat,
		"unavailable UI art retains the readable shell fallback")
	_check(master != null and master != shared and master.get_font_size("font_size", "PatchTitle") < 40,
		"the shell duplicates the master Theme instead of mutating it")
	_check(app.title_label.get_theme_font("font").resource_path == shell.TITLE_FONT,
		"title uses the Londrina Solid title font")
	for button in [app.start_button, app.route_button, app.base_button]:
		_check(button.theme_type_variation == "PatchHeadingButton"
			and (button.get_theme_font("font") as Font).resource_path == shell.HEADING_FONT,
			"title action uses the master Londrina heading button font: " + button.text)
		_check(button.get_theme_color("font_color") == shared.get_color("font_color", "Button")
			and button.get_theme_color("font_hover_color") == shared.get_color("font_hover_color", "Button")
			and button.get_theme_color("font_pressed_color") == shared.get_color("font_pressed_color", "Button"),
			"title action keeps the shared cream ink in every state: " + button.text)
	_check((shared.get_stylebox("panel", "Panel") as StyleBoxFlat).bg_color == shell.PAPER
		and (shared.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).bg_color != shell.PAPER,
		"shared Theme supplies paper panels and contrasting felt containers")
	_check(app.title_label.theme_type_variation == "PatchTitle" and app.title_label.get_theme_color("font_color") == shell.INK,
		"existing live label uses the master dark ink PatchTitle variation")
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
	# The picture stays scenery: only two compact sewn backings follow the live controls.
	var viewport := Rect2(Vector2.ZERO, shell.size)
	var title_back: Rect2 = shell.title_backing_rect()
	var action_back: Rect2 = shell.action_backing_rect()
	_check(title_back.has_area() and viewport.encloses(title_back)
		and title_back.encloses(Rect2(app.title_label.global_position, app.title_label.size)),
		"compact paper backing follows the live title label inside the viewport")
	var frames_actions := action_back.has_area() and viewport.encloses(action_back)
	for button in [app.start_button, app.route_button, app.base_button]:
		frames_actions = frames_actions and action_back.encloses(button.get_global_rect())
	_check(frames_actions, "one compact felt backing frames all three original actions")
	_check(is_equal_approx(action_back.position.x, title_back.position.x)
		and is_equal_approx(action_back.size.x, title_back.size.x)
		and action_back.position.y <= title_back.end.y,
		"the sewn menu is one aligned stack, not a full-screen patch")
	var coverage := (title_back.get_area() + action_back.get_area()) / viewport.get_area()
	_check(coverage > 0.0 and coverage <= shell.MENU_COVERAGE_LIMIT,
		"sewn menu covers only a compact share of the title picture")
	# Real mounted title: presentation time may animate only the textured wordmark.
	var logo_art: Texture2D = shell._logo
	var logo_box: Rect2 = shell.logo_rect()
	var fixed_label: Rect2 = app.title_label.get_global_rect()
	var fixed_actions: Array[Rect2] = []
	for button in [app.start_button, app.route_button, app.base_button]:
		fixed_actions.append(button.get_global_rect())
	_check(logo_art != null and logo_art.resource_path == shell.TITLE_LOGO
		and logo_box.has_area() and shell.is_processing() and app.start_button.has_focus(),
		"authored live title wordmark is mounted and drives presentation processing")
	var elapsed_at_boot: float = shell._logo_elapsed
	await process_frame
	_check(shell._logo_elapsed > elapsed_at_boot, "visible title advances presentation clock in real frames")
	var distinct_motion := false
	for beat in [0.0, 1.0, 2.0, 3.0, 4.0, 6.0]:
		shell._logo_elapsed = beat
		var pose: Dictionary = shell.logo_motion()
		var shift: Vector2 = pose["offset"]
		var tilt: float = pose["rotation"]
		_check(absf(shift.x) <= shell.LOGO_MOTION_OFFSET.x + 0.001
			and absf(shift.y) <= shell.LOGO_MOTION_OFFSET.y + 0.001
			and absf(tilt) <= shell.LOGO_MOTION_ROTATION + 0.001,
			"logo sway remains within its small authored rectangle allowance")
		if shift.length() > 0.1 and absf(tilt) > 0.001:
			distinct_motion = true
		_check(shell.logo_rect() == logo_box and app.title_label.get_global_rect() == fixed_label,
			"logo motion leaves the title label and static logo rectangle unchanged")
		for index in range(fixed_actions.size()):
			_check([app.start_button, app.route_button, app.base_button][index].get_global_rect() == fixed_actions[index],
				"sway cannot move the original interactive hit target " + str(index))
	_check(distinct_motion, "mounted wordmark actually moves and rotates during the cycle")
	shell._logo_elapsed = 2.0
	var repeat_pose: Dictionary = shell.logo_motion()
	shell._logo_elapsed = 2.0 + shell.LOGO_MOTION_PERIOD
	var repeated_pose: Dictionary = shell.logo_motion()
	_check(repeat_pose["offset"].distance_to(repeated_pose["offset"]) < 0.001
		and absf(float(repeat_pose["rotation"]) - float(repeated_pose["rotation"])) < 0.001,
		"wordmark sway repeats without RNG or accumulating drift")
	# The reward panel contract: a boolean override wins, null follows ProjectSettings.
	shell.set_reduced_motion_override(true)
	_check(not shell.is_processing() and shell._logo_elapsed == 0.0
		and shell.logo_motion()["offset"] == Vector2.ZERO
		and shell.logo_motion()["rotation"] == 0.0 and shell.logo_rect() == logo_box,
		"reduced-motion override stops processing and preserves the static wordmark")
	shell.set_reduced_motion_override(false)
	_check(shell.is_processing() and shell._logo_elapsed == 0.0,
		"enabling motion again starts from its neutral frame")
	var setting_path := "accessibility/reduced_motion"
	var previous_setting: Variant = ProjectSettings.get_setting(setting_path, false)
	ProjectSettings.set_setting(setting_path, true)
	shell.set_reduced_motion_override(null)
	_check(not shell.is_processing() and shell.logo_motion()["offset"] == Vector2.ZERO,
		"project accessibility reduced-motion setting suppresses wordmark sway")
	ProjectSettings.set_setting(setting_path, false)
	shell._sync_logo_motion()
	_check(shell.is_processing() and shell._logo_elapsed == 0.0,
		"project accessibility setting can restore wordmark motion")
	ProjectSettings.set_setting(setting_path, previous_setting)
	shell.set_reduced_motion_override(false)
	# Missing logo must restore visible live text instead of leaving a blank title.
	shell._logo = null
	shell._process(0.0)
	_check(not shell.is_processing() and shell._logo_elapsed == 0.0
		and not shell.logo_rect().has_area() and app.title_label.self_modulate.a == 1.0,
		"missing logo halts sway and restores the readable live title label")
	shell._logo = logo_art
	shell._sync_logo_motion()
	_check(shell.is_processing() and shell.logo_rect() == logo_box
		and app.title_label.self_modulate.a == 0.0,
		"restored authored logo resumes from neutral and hides only the painted label")
	shell._process(1.0)
	_check(shell._logo_elapsed > 0.0, "logo has motion phase before hiding the title")
	app.title_view.hide()
	_check(not shell.visible and not shell.is_processing() and shell._logo_elapsed == 0.0
		and shell.logo_motion()["offset"] == Vector2.ZERO,
		"hidden title releases its presentation processing and stale pose")
	app.title_view.show()
	_check(shell.visible and shell.is_processing() and shell._logo_elapsed == 0.0
		and shell.logo_motion()["offset"] == Vector2.ZERO and shell.logo_rect() == logo_box,
		"title re-entry starts fresh at the untransformed logo rectangle")
	_check(app.title_label.get_global_rect() == fixed_label
		and [app.start_button.get_global_rect(), app.route_button.get_global_rect(),
			app.base_button.get_global_rect()] == fixed_actions,
		"hide/re-entry preserve label and all three mouse/keyboard action rects")
	# This direct visibility probe bypasses App's navigation callbacks, so restore the
	# original focused title action before exercising the physical Tab cycle.
	app.start_button.grab_focus()
	_check(app.start_button.has_focus(), "focus is restored after the synthetic visibility probe")
	if shell._backdrop is Texture2D:
		var picture: Rect2 = shell.backdrop_rect()
		var scenery := true
		for point in [Vector2(60, 60), Vector2(1220, 60), Vector2(60, 660), Vector2(1220, 660)]:
			scenery = scenery and picture.has_point(point) \
				and not title_back.has_point(point) and not action_back.has_point(point)
		_check(scenery, "supplied scenery is drawn outside the compact sewn menu")
		_check(shell.get_child_count() == 0 and shell.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"the picture and its backings are drawn, never a capturing node")
	# A missing picture must repaint the same readable menu from code alone.
	var draws := [0]
	var count_draw := func(): draws[0] += 1
	shell.draw.connect(count_draw)
	var mounted_backdrop: Texture2D = shell._backdrop
	shell._backdrop = null
	_check(shell.backdrop_rect() == Rect2(), "a missing picture has no cover rect instead of a broken one")
	_check(shell.title_backing_rect() == title_back and shell.action_backing_rect() == action_back,
		"the same compact sewn menu survives a missing picture")
	shell.queue_redraw()
	await process_frame
	await process_frame
	_check(draws[0] > 0, "the null-backdrop fallback actually repaints")
	_check(is_instance_valid(app.title_label) and app.title_label.is_visible_in_tree() and shell.visible
		and shell.PAPER.get_luminance() - shell.INK.get_luminance() > 0.5
		and shell.PAPER.get_luminance() - shell.FALLBACK_STAGE.get_luminance() > 0.3
		and shell.THREAD.get_luminance() > shell.ACTION_BACKING.get_luminance(),
		"fallback keeps the dark ink title readable on paper above its felt menu")
	shell._backdrop = mounted_backdrop
	shell.queue_redraw()
	await process_frame
	shell.draw.disconnect(count_draw)
	_check(shell._backdrop == mounted_backdrop and shell.backdrop_rect().has_area(),
		"the supplied picture is restored for the live title")
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
	_check(shell.visible and shell.is_processing(), "backdrop and title sway follow title show synchronously")
	shell._process(1.25)
	_check(shell._logo_elapsed > 0.0, "real seeded route state coexists with the mounted title animation")
	app.title_view.hide()
	_check(not shell.visible and _snapshot(app) == before, "decoration visibility leaves real run and RNG unchanged")
	await _click(app.route_back_button)
	_check(app.run_map == null and shell.visible and app.start_button.has_focus(), "physical Back restores title and focus")
	# The third original action still opens the village and returns to this title.
	await _click(app.base_button)
	var village = app.base_screen
	_check(is_instance_valid(village) and village.has_open_village() and not shell.visible
		and not app.title_view.is_visible_in_tree(), "physical Quilt village hides the sewn title")
	if is_instance_valid(village):
		await _click(village.back_button)
	_check(app.base_screen == null and shell.visible and app.title_view.is_visible_in_tree()
		and app.base_button.has_focus() and app.run_map == null and app.run_rng == null,
		"village Back restores the focused title without starting a run")
	# Focus cycles over all three original actions with the picture mounted.
	app.base_button.grab_focus()
	await _key(KEY_TAB)
	_check(app.start_button.has_focus(), "Tab wraps from Quilt village to Start run")
	await _key(KEY_TAB)
	_check(app.route_button.has_focus(), "Tab reaches Choose a route on the sewn title")
	await _key(KEY_TAB)
	_check(app.base_button.has_focus(), "Tab reaches Quilt village on the sewn title")
	app.start_button.grab_focus()
	await _click(app.start_button)
	preload("res://tests/party_choice.gd").choose(app)
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
		# Live mounted Event and terminal views resolve the master typography through
		# the App theme the shell installed, not only in a standalone panel mount.
		if screen == "event":
			_check_heading_and_body(app.quiet_spool_panel.title_label,
				app.quiet_spool_panel.description_label, "live Event")
		elif screen == "results":
			_check_heading_and_body(app.terminal_result_panel.title_label,
				app.terminal_result_panel.description_label, "live terminal result")
		elif screen == "rest":
			_check_rest_arrow_tiles(app)
		if screen in ["shop", "rest"]:
			await _check_visit_controls(app, screen)
		var controls: Array[Control] = []
		_collect(app, controls)
		_check(not controls.is_empty(), "live screen has themed controls: " + screen)
		var visible_buttons := 0
		for control in controls:
			if control is LivePeddlerPanel:
				_check(control.theme != null and control.theme != app.theme
					and control.get_theme_font("font", "Button") == app.get_theme_font("font", "Button"),
					"Peddler uses a detached copy of the shipped master font theme")
			else:
				_check(control.theme == null, "downstream controls retain inherited root Theme: " + screen)
			if control is Button and control.is_visible_in_tree():
				visible_buttons += 1
				# Existing authored reward/event/result overrides intentionally sit on this Theme.
				if not control.has_theme_stylebox_override("normal"):
					var button_type := "OptionButton" if control is OptionButton else "Button"
					_check(control.get_theme_stylebox("normal") == app.theme.get_stylebox("normal", button_type),
						"live button resolves shared style: " + screen)
		_check(visible_buttons > 0, "each real preview has visible actions: " + screen)
		_check(app.get_node("PatchworkUIShell").visible == (screen == "title"), "title decoration visibility: " + screen)
		app.free()
	_check(var_to_str(master) == master_before, "mounted visits leave the master Theme unchanged")
	for failure in failures:
		printerr(failure)
	print("patchwork_ui_shell_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _collect(node: Node, controls: Array[Control]) -> void:
	for child in node.get_children():
		if child is Control:
			controls.append(child)
		_collect(child, controls)


func _check_visit_theme(shared: Theme) -> void:
	for type in ["OptionButton", "PopupMenu", "VScrollBar"]:
		var entries: Array = ["normal", "hover", "pressed", "disabled", "focus"]
		if type == "PopupMenu":
			entries = ["panel", "hover"]
		elif type == "VScrollBar":
			entries = ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]
		for entry in entries:
			_check(shared.has_stylebox(entry, type), type + " explicitly owns " + entry)
			var style := shared.get_stylebox(entry, type) as StyleBoxTexture
			_check(style != null and style.texture != null
				and style.texture.resource_path.begins_with("res://assets/paper/ui/reward_"),
				type + " reuses shipped sewn texture: " + entry)
	_check(not shared.get_stylebox("focus", "OptionButton").get("draw_center"),
		"sewn keyboard focus leaves the selector caption uncovered")
	_check(shared.get_color("font_disabled_color", "OptionButton")
		!= shared.get_color("font_color", "OptionButton"), "disabled selector ink is distinct")
	for type in ["OptionButton", "PopupMenu"]:
		for entry in ["font_color", "font_hover_color", "font_disabled_color"]:
			_check(shared.has_color(entry, type)
				and shared.get_color(entry, type).srgb_to_linear().get_luminance() < 0.2,
				type + " keeps dark legible ink on paper: " + entry)


func _check_visit_controls(app, screen: String) -> void:
	var selectors: Array = [app.peddler_heroes] if screen == "shop" \
		else [app.rest_stitch_first, app.rest_stitch_second]
	var deck: Array = app.run_deck.duplicate(true)
	var wallet := [app.session_gold, app.run_scraps]
	for selector: OptionButton in selectors:
		_check(is_instance_valid(selector) and selector.is_visible_in_tree() and selector.item_count > 0,
			screen + " mounts a populated actual selector")
		if not is_instance_valid(selector) or selector.item_count == 0:
			continue
		var selected := selector.selected
		var metadata: Array = []
		for index in range(selector.item_count):
			metadata.append(selector.get_item_metadata(index))
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			_check(selector.get_theme_stylebox(state) == app.theme.get_stylebox(state, "OptionButton"),
				screen + " actual selector inherits " + state)
		_check(selector.get_theme_color("font_disabled_color") == app.theme.get_color("font_disabled_color", "OptionButton")
			and selector.get_theme_color("font_focus_color") == app.theme.get_color("font_focus_color", "OptionButton"),
			screen + " actual selector inherits disabled and focused ink")
		selector.grab_focus()
		_check(selector.has_focus(), screen + " actual selector accepts keyboard focus")
		await _key(KEY_SPACE)
		var popup := selector.get_popup()
		_check(popup.visible and popup.item_count == selector.item_count,
			screen + " keyboard opens the selector's populated PopupMenu")
		popup.set_focused_item(selected)
		_check(popup.get_focused_item() == selected, screen + " popup focuses the selected row")
		for state in ["panel", "hover"]:
			_check(popup.get_theme_stylebox(state) == app.theme.get_stylebox(state, "PopupMenu"),
				screen + " actual PopupMenu inherits " + state)
		for entry in ["font_color", "font_hover_color", "font_disabled_color"]:
			_check(popup.get_theme_color(entry) == app.theme.get_color(entry, "PopupMenu"),
				screen + " actual PopupMenu inherits " + entry)
		popup.hide()
		_check(selector.selected == selected, screen + " inspecting popup preserves selection")
		for index in range(selector.item_count):
			_check(selector.get_item_metadata(index) == metadata[index], screen + " popup preserves metadata")
	if screen == "shop":
		_check(app.peddler_visit != null and app.peddler_visit.is_open() and app.peddler_buttons.size() == 4,
			"Peddler mounts four authentic direct choices")
		for button in app.peddler_buttons + [app.peddler_leave_button]:
			_check(button.is_visible_in_tree() and button.get_theme_stylebox("normal") is StyleBoxFlat
				and button.get_theme_stylebox("focus") is StyleBoxTexture
				and button.get_theme_font_size("font_size") >= 20
				and button.pressed.get_connections().size() == 1, "Peddler direct choice inherits sewn action skin and authentic callback")
		_check(app.run_deck == deck and [app.session_gold, app.run_scraps] == wallet, "Peddler popup inspection leaves run inventory untouched")
		return
	var gallery = app.get_node_or_null("LiveVisitCardTiles")
	_check(gallery != null and gallery.is_gallery_mounted(), screen + " mounts the real populated gallery")
	if gallery != null and gallery.is_gallery_mounted():
		var tiles: Array[Button] = gallery.offer_tiles() if screen == "shop" else gallery.upgrade_tiles()
		_check(not tiles.is_empty(), screen + " gallery has real card tiles")
		var bar: VScrollBar = gallery.gallery_scroll().get_v_scroll_bar()
		for state in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]:
			_check(bar.get_theme_stylebox(state) == app.theme.get_stylebox(state, "VScrollBar"),
				screen + " actual gallery scrollbar inherits " + state)
		var track := bar.get_theme_stylebox("scroll") as StyleBoxTexture
		var handle := bar.get_theme_stylebox("grabber") as StyleBoxTexture
		_check(track != null and handle != null
			and handle.modulate_color.get_luminance() > track.modulate_color.get_luminance() + 0.4,
			screen + " scrollbar has a discernible paper grabber on dark fabric")
	_check(app.run_deck == deck and [app.session_gold, app.run_scraps] == wallet,
		screen + " focus and popup inspection do not spend or alter the deck")


## A real mounted heading resolves the master Londrina variation; its body line
## keeps the master Patrick Hand face underneath it.
func _check_heading_and_body(heading: Label, body: Label, label: String) -> void:
	_check(heading.theme_type_variation == "PatchHeading"
		and (heading.get_theme_font("font") as Font).resource_path
			== "res://assets/fonts/LondrinaSolid-Regular.ttf",
		label + " heading uses the master PatchHeading Londrina face")
	_check(body.theme_type_variation == ""
		and (body.get_theme_font("font") as Font).resource_path
			== "res://assets/fonts/PatrickHand-Regular.ttf",
		label + " body text keeps the master Patrick Hand face")


## The real Rest visit prints U+2192 between the two halves of every upgrade
## tile's name and cost line. Both mounted labels must keep the literal arrow,
## the Patrick Hand base face and a fallback that really covers the glyph, and
## reading them must leave the run deck and wallet untouched.
func _check_rest_arrow_tiles(app) -> void:
	var gallery = app.get_node_or_null("LiveVisitCardTiles")
	_check(gallery != null and is_instance_valid(gallery) and gallery.is_gallery_mounted()
		and gallery.gallery_kind() == "Rest",
		"rest preview mounts the real visit card gallery")
	if gallery == null or not is_instance_valid(gallery):
		return
	var tiles: Array[Button] = gallery.upgrade_tiles()
	_check(not tiles.is_empty(), "rest preview mounts real Rest upgrade tiles")
	if tiles.is_empty():
		return
	var deck: Array = app.run_deck.duplicate()
	var wallet := [app.session_gold, app.run_scraps]
	var arrows := 0
	for tile in tiles:
		var panel: Control = tile.get_parent()
		var name_label := panel.find_child("TileName", true, false) as Label
		var meta_label := panel.find_child("TileMeta", true, false) as Label
		_check(name_label != null and meta_label != null,
			"real Rest upgrade tile mounts its name and cost labels")
		_check(name_label != null and name_label.theme_type_variation == "PatchHeading",
			"real Rest upgrade card name wears the master PatchHeading variation")
		for label in [name_label, meta_label]:
			if label == null:
				continue
			_check(label.text.contains(String.chr(ARROW)),
				"real Rest upgrade label keeps the literal U+2192: " + label.name)
			var face: Font = label.get_theme_font("font")
			_check(face != null and face.has_char(ARROW),
				"resolved Rest upgrade face covers U+2192 through its fallback: " + label.name)
			# The card name is a PatchHeading title now; the cost line stays body.
			var base_path: String = HEADING_FONT if label.name == "TileName" else BODY_FONT
			_check(face is FontVariation
				and (face as FontVariation).base_font != null
				and (face as FontVariation).base_font.resource_path == base_path
				and not (face as FontVariation).base_font.has_char(ARROW),
				"Rest upgrade text keeps its master base face: " + label.name)
			arrows += _count_drawn_arrows(label, face)
		# Every other line on the same sewn face keeps the inherited master face.
		for other_name in ["OwnerLabel", "TileEffects"]:
			var other := panel.find_child(other_name, true, false) as Label
			_check(other != null and not other.has_theme_font_override("font")
				and (other.get_theme_font("font") as Font).resource_path == BODY_FONT,
				"non-arrow Rest tile text keeps the inherited Patrick Hand face: " + other_name)
	_check(arrows == 2 * tiles.size(),
		"every displayed Rest arrow resolves to a drawn glyph, not a missing-glyph box")
	_check(app.run_deck == deck and [app.session_gold, app.run_scraps] == wallet,
		"reading the Rest arrows leaves the run deck and wallet untouched")


## Shape one mounted label's own text and prove its U+2192 is drawn by a fallback
## with a painted glyph atlas, never the base face's .notdef box. Returns the
## number of arrows proven drawn.
func _count_drawn_arrows(label: Label, face: Font) -> int:
	if face == null:
		return 0
	var size: int = label.get_theme_font_size("font_size")
	var rids: Array[RID] = face.get_rids()
	_check(rids.size() >= 2, "Rest arrow face carries its fallback: " + label.name)
	if rids.size() < 2:
		return 0
	var base_rid: RID = rids[0]
	var server := TextServerManager.get_primary_interface()
	var shaped := server.create_shaped_text()
	server.shaped_text_add_string(shaped, label.text, rids, size)
	var drawn := 0
	for glyph in server.shaped_text_get_glyphs(shaped):
		if int(glyph.get("index")) != ARROW:
			continue
		var font_rid: RID = glyph.get("font_rid")
		var key := Vector2i(size, 0)
		var texture_idx := server.font_get_glyph_texture_idx(font_rid, key, ARROW)
		var image: Image = server.font_get_texture_image(font_rid, key, texture_idx) \
			if texture_idx >= 0 else null
		var uv: Rect2 = server.font_get_glyph_uv_rect(font_rid, key, ARROW)
		var painted := 0
		if image != null:
			for y in range(int(uv.position.y), int(uv.end.y)):
				for x in range(int(uv.position.x), int(uv.end.x)):
					if image.get_pixel(x, y).a > 0.0:
						painted += 1
		var ok: bool = font_rid != base_rid and float(glyph.get("advance")) > 0.0 and painted > 0
		_check(ok, "the shown arrow is drawn by the fallback glyph: " + label.name)
		if ok:
			drawn += 1
	server.free_rid(shaped)
	return drawn

