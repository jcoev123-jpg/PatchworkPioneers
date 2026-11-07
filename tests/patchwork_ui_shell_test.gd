extends "res://tests/live_run_map_entry_test.gd"
## Mounted presentation/lifecycle checks; visual layout is reviewed in web screenshots.

## The master body face every sewn tile label inherits: Patrick Hand.
const BODY_FONT := "res://assets/fonts/PatrickHand-Regular.ttf"
## The master heading face a sewn card name now wears: Londrina Regular.
const HEADING_FONT := "res://assets/fonts/LondrinaSolid-Regular.ttf"
## U+2192, printed between the two halves of a real Rest upgrade tile.
const ARROW := 0x2192
const GOTHIC_BG := Color("171419")
const GOTHIC_OXBLOOD := Color("352126")
const GOTHIC_UMBER := Color("382a26")
const GOTHIC_BRASS := Color("998053")
const GOTHIC_BONE := Color("e9ddc7")
const GOTHIC_AMBER := Color("e6ad58")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	var shell = app.get_node("PatchworkUIShell")
	var shared: Theme = app.theme
	_check(shared != null and shared.default_font_size >= 18, "scene installs body theme before App readiness")
	for token in ["background", "oxblood", "umber", "brass", "bone", "amber"]:
		_check(shared.has_color(token, "GothicPalette"),
			"resource publishes reusable gothic palette token: " + token)
	_check(shared.get_color("background", "GothicPalette").is_equal_approx(GOTHIC_BG)
		and shared.get_color("oxblood", "GothicPalette").is_equal_approx(GOTHIC_OXBLOOD)
		and shared.get_color("umber", "GothicPalette").is_equal_approx(GOTHIC_UMBER)
		and shared.get_color("brass", "GothicPalette").is_equal_approx(GOTHIC_BRASS)
		and shared.get_color("bone", "GothicPalette").is_equal_approx(GOTHIC_BONE)
		and shared.get_color("amber", "GothicPalette").is_equal_approx(GOTHIC_AMBER),
		"all six shared palette tokens match the owner's exact values")
	var gothic_source: Theme = load("res://themes/gothic_theme.tres") as Theme
	_check(gothic_source != null and shared == gothic_source
		and shell._build_theme() == shared and app.theme == gothic_source,
		"real App boots with the gothic scene Theme; shell inherits instead of replacing it")
	_check(shared.default_font != null and shared.default_font.resource_path == BODY_FONT
		and shared.default_font_size >= 18
		and shared.get_font_size("font_size", "Label") >= 18,
		"gothic Theme keeps Patrick Hand body at readable size")
	_check((shared.get_stylebox("panel", "Panel") as StyleBoxFlat).bg_color.is_equal_approx(GOTHIC_OXBLOOD)
		and (shared.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).bg_color.is_equal_approx(GOTHIC_UMBER)
		and (shared.get_stylebox("panel", "Panel") as StyleBoxFlat).border_color.is_equal_approx(GOTHIC_BRASS)
		and shared.get_color("font_color", "Label").is_equal_approx(GOTHIC_BONE)
		and shared.get_stylebox("scroll", "VScrollBar").bg_color.is_equal_approx(GOTHIC_BG),
		"gothic palette is oxblood, umber, brass and bone over a near-black scrollbar")
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
		"selector surfaces belong to the gothic root Theme, not the font master")
	_check(shell._fabric_style("res://missing_selector_surface.png", shell.PAPER) is StyleBoxFlat,
		"unavailable UI art retains the readable shell fallback")
	_check(master != null and master != shared and master.get_font_size("font_size", "PatchTitle") < 40,
		"the App uses a separate gothic Theme without mutating the master fonts")
	_check(app.title_label.get_theme_font("font").resource_path == shell.TITLE_FONT,
		"title uses the Londrina Solid title font")
	for button in [app.start_button, app.stitched_continue_button, app.base_button]:
		_check(button.theme_type_variation == "PatchHeadingButton"
			and (button.get_theme_font("font") as Font).resource_path == shell.HEADING_FONT,
			"title action uses the master Londrina heading button font: " + button.text)
		_check(button.get_theme_color("font_color") == shared.get_color("font_color", "Button")
			and button.get_theme_color("font_hover_color") == shared.get_color("font_hover_color", "Button")
			and button.get_theme_color("font_pressed_color") == shared.get_color("font_pressed_color", "Button"),
			"title action keeps inherited gothic text color in every state: " + button.text)
	_check((shared.get_stylebox("panel", "Panel") as StyleBoxFlat).bg_color.is_equal_approx(GOTHIC_OXBLOOD)
		and (shared.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).bg_color.is_equal_approx(GOTHIC_UMBER),
		"shared Theme supplies contrasting gothic oxblood and umber surfaces")
	_check(app.title_label.theme_type_variation == "PatchTitle"
		and app.title_label.get_theme_color("font_color").is_equal_approx(GOTHIC_BONE),
		"original live title keeps bone Londrina lettering on its dark missing-logo backing")
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
	for button in [app.start_button, app.stitched_continue_button, app.base_button]:
		frames_actions = frames_actions and action_back.encloses(button.get_global_rect())
	_check(frames_actions, "one compact felt backing frames all three title actions")
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
	var previous_action := Rect2()
	for button in [app.start_button, app.stitched_continue_button, app.base_button]:
		var hit: Rect2 = button.get_global_rect()
		_check(button.is_visible_in_tree() and not button.disabled and viewport.encloses(hit)
			and hit.size.y == 56 and (not previous_action.has_area() or previous_action.end.y <= hit.position.y),
			"three visible nonoverlapping 56px mouse bounds: " + button.text)
		previous_action = hit
		fixed_actions.append(hit)
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
			_check([app.start_button, app.stitched_continue_button, app.base_button][index].get_global_rect() == fixed_actions[index],
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
		and [app.start_button.get_global_rect(), app.stitched_continue_button.get_global_rect(),
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
		and app.title_label.get_theme_color("font_color").is_equal_approx(GOTHIC_BONE)
		and shell.FALLBACK_STAGE.is_equal_approx(GOTHIC_BG)
		and shell.ACTION_BACKING.is_equal_approx(GOTHIC_OXBLOOD)
		and _gothic_contrast(GOTHIC_BONE, shell.ACTION_BACKING) >= 4.5
		and shell.THREAD.is_equal_approx(GOTHIC_BRASS),
		"missing-art fallback keeps bone title text readable on dark oxblood and brass")
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
		_check(style != null and not fills.has(style.bg_color), "distinct gothic button state: " + state)
		if style != null:
			fills.append(style.bg_color)
			var text_state: String = "font_color" if state == "normal" else "font_" + state + "_color"
			_check(_gothic_contrast(shared.get_color(text_state, "Button"), style.bg_color) >= 4.5,
				"gothic " + state + " button text remains legible")
	var focus := shared.get_stylebox("focus", "Button") as StyleBoxFlat
	_check(focus != null and focus.border_width_top >= 3 and focus.border_color.is_equal_approx(GOTHIC_AMBER)
		and not focus.draw_center and focus.expand_margin_left >= 3.0,
		"opaque 3px candle-amber keyboard focus border")
	for button in [app.start_button, app.stitched_continue_button, app.base_button]:
		_check(button.get_child_count() == 1 and button.get_child(0).mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"title stitches cannot block original button")
	_check(app.base_button.get_theme_stylebox("normal") == shared.get_stylebox("normal", "Button")
		and app.base_button.get_theme_stylebox("hover") == shared.get_stylebox("hover", "Button")
		and app.base_button.get_theme_stylebox("focus") == shared.get_stylebox("focus", "Button"),
		"third title action shares the sewn button theme")
	_check(shell._actions == [app.start_button, app.stitched_continue_button, app.base_button],
		"shell styles exactly the three live title actions")
	for button in [app.stitched_fight_button]:
		_check(not button.is_visible_in_tree() and button.disabled
			and button.focus_mode == Control.FOCUS_NONE and button.pressed.get_connections().is_empty()
			and button.get_child_count() == 0 and button.theme_type_variation == "",
			"dormant shortcut has no presentation, focus or callback: " + button.text)
		button.pressed.emit()
	_check(app.stitched_event_panel == null and app.stitched_run_panel == null
		and app.run_map == null and app.run_rng == null and app.title_view.is_visible_in_tree(),
		"dormant shortcut signals cannot enter a game")
	_check(app.start_button.has_focus() and shell.visible, "initial focused title with backdrop")
	await _key(KEY_TAB)
	_check(app.stitched_continue_button.has_focus(), "physical Tab retains title focus cycle")
	app.start_button.grab_focus()
	await _key(KEY_SPACE)
	_check(app.stitched_run_panel != null and not shell.visible,
		"physical New Run hides decoration and mounts the Stitched picker")
	app.title_view.show()
	_check(shell.visible and shell.is_processing(), "backdrop follows title visibility synchronously")
	app.title_view.hide()
	await _click(app.stitched_run_buttons[1])
	_check(app.stitched_run_session == null and shell.visible and app.start_button.has_focus(),
		"physical Cancel restores title and focus without a run")
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
	# Focus cycles over all three live title actions with the picture mounted.
	app.base_button.grab_focus()
	await _key(KEY_TAB)
	_check(app.start_button.has_focus(), "Tab wraps from village to New Run, skipping dormant controls")
	await _key(KEY_TAB)
	_check(app.stitched_continue_button.has_focus(), "Tab reaches Continue on the sewn title")
	await _key(KEY_TAB)
	_check(app.base_button.has_focus(), "Tab reaches Quilt village on the sewn title")
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


## WCAG contrast is checked on the resolved flat fill, not merely on a font flag.
func _gothic_contrast(foreground: Color, background: Color) -> float:
	var a := foreground.srgb_to_linear().get_luminance()
	var b := background.srgb_to_linear().get_luminance()
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


func _check_visit_theme(shared: Theme) -> void:
	for type in ["OptionButton", "PopupMenu", "VScrollBar", "HScrollBar"]:
		var entries: Array = ["normal", "hover", "pressed", "disabled", "focus"]
		if type == "PopupMenu":
			entries = ["panel", "hover", "focus"]
		elif type in ["VScrollBar", "HScrollBar"]:
			entries = ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]
		for entry in entries:
			_check(shared.has_stylebox(entry, type), type + " explicitly owns " + entry)
			var style := shared.get_stylebox(entry, type) as StyleBoxFlat
			_check(style != null and style.border_width_top >= 1,
				type + " uses readable dark-gothic flat fallback: " + entry)
			if entry == "focus" and style != null:
				_check(style.border_width_top >= 3 and style.border_color.is_equal_approx(GOTHIC_AMBER)
					and not style.draw_center and style.expand_margin_top >= 3,
					"type " + type + " exposes 3px candle-amber focus")
	for type in ["OptionButton", "PopupMenu"]:
		var normal_style := shared.get_stylebox("normal" if type == "OptionButton" else "panel", type) as StyleBoxFlat
		var hover_style := shared.get_stylebox("hover", type) as StyleBoxFlat
		_check(normal_style != null and hover_style != null,
			type + " has real normal and hover surfaces")
		if normal_style == null or hover_style == null:
			continue
		for entry in ["font_color", "font_hover_color", "font_disabled_color"]:
			var bg: Color = hover_style.bg_color if entry == "font_hover_color" else normal_style.bg_color
			_check(shared.has_color(entry, type)
				and _gothic_contrast(shared.get_color(entry, type), bg) >= 4.5,
				type + " uses readable pale lettering on dark fabric: " + entry)
	_check(shared.get_color("font_hover_color", "OptionButton").is_equal_approx(GOTHIC_AMBER)
		and shared.get_color("font_hover_color", "PopupMenu").is_equal_approx(GOTHIC_AMBER),
		"both selectors share the candle-amber hover highlight")
	_check(shared.get_stylebox("grabber", "VScrollBar").bg_color.is_equal_approx(GOTHIC_BRASS)
		and shared.get_stylebox("grabber_pressed", "VScrollBar").bg_color.is_equal_approx(GOTHIC_BONE),
		"both dark scrollbars retain a contrasting brass/bone grip")

