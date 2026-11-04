extends SceneTree
## Detached S2 accessibility chrome contract: no App, rules, parts or run fixture.
const THEME_PATH := "res://themes/gothic_theme.tres"
const BODY_FONT := "res://assets/fonts/PatrickHand-Regular.ttf"
const OXBLOOD := Color("352126")
const BRASS := Color("998053")
const BONE := Color("e9ddc7")
const AMBER := Color("e6ad58")
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _linear(component: float) -> float:
	return component / 12.92 if component <= 0.04045 else pow((component + 0.055) / 1.055, 2.4)


func _luminance(color: Color) -> float:
	return 0.2126 * _linear(color.r) + 0.7152 * _linear(color.g) + 0.0722 * _linear(color.b)


func _contrast(a: Color, b: Color) -> float:
	var light := maxf(_luminance(a), _luminance(b))
	var dark := minf(_luminance(a), _luminance(b))
	return (light + 0.05) / (dark + 0.05)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var gothic: Theme = load(THEME_PATH) as Theme
	_check(gothic != null, "the shipped Gothic Theme loads")
	if gothic == null:
		_finish()
		return
	var host := Control.new()
	host.size = Vector2(1280, 720)
	host.theme = gothic
	root.add_child(host)
	var toggle := CheckButton.new()
	toggle.text = "Reduce motion"
	toggle.position = Vector2(220, 160)
	toggle.size = Vector2(202, 36)
	toggle.focus_mode = Control.FOCUS_ALL
	host.add_child(toggle)
	var action := Button.new()
	action.text = "Pass turn"
	action.position = Vector2(220, 230)
	action.size = Vector2(155, 38)
	host.add_child(action)
	await process_frame
	_check(toggle.is_inside_tree() and action.is_inside_tree()
		and toggle.theme == null and action.theme == null and host.theme == gothic,
		"both genuine Control subclasses inherit one mounted gothic parent Theme")
	_check(gothic.default_font != null and gothic.default_font.resource_path == BODY_FONT
		and gothic.default_font_size == 18 and gothic.get_font_size("font_size", "CheckButton") == 18
		and toggle.get_theme_font("font") == gothic.default_font
		and action.get_theme_font("font") == gothic.default_font
		and toggle.get_theme_font_size("font_size") == 18,
		"CheckButton and ordinary Button inherit Patrick Hand at 18px")
	_check(gothic.has_stylebox("normal", "CheckButton")
		and gothic.has_stylebox("hover", "CheckButton")
		and gothic.has_stylebox("pressed", "CheckButton")
		and gothic.has_stylebox("hover_pressed", "CheckButton")
		and gothic.has_stylebox("disabled", "CheckButton")
		and gothic.has_stylebox("focus", "CheckButton"),
		"all six CheckButton surfaces are explicit Theme resources")
	_check(gothic.has_color("font_color", "CheckButton")
		and gothic.has_color("font_hover_color", "CheckButton")
		and gothic.has_color("font_pressed_color", "CheckButton")
		and gothic.has_color("font_hover_pressed_color", "CheckButton")
		and gothic.has_color("font_disabled_color", "CheckButton")
		and gothic.has_color("font_focus_color", "CheckButton"),
		"every CheckButton text state is explicit")
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var surface := toggle.get_theme_stylebox(state) as StyleBoxFlat
		var ordinary := action.get_theme_stylebox(state) as StyleBoxFlat
		_check(surface != null and ordinary != null
			and surface == gothic.get_stylebox(state, "CheckButton")
			and surface == ordinary,
			"resolved %s toggle surface shares the existing sewn Button chrome" % state)
		if surface == null:
			continue
		var color_key: String = "font_color" if state == "normal" else "font_" + state + "_color"
		var ink := toggle.get_theme_color(color_key)
		_check(_contrast(ink, surface.bg_color) >= 4.5,
			"resolved %s state keeps text contrast at least 4.5:1" % state)
		_check(surface.border_width_left >= 2 and surface.border_color.a >= 1.0,
			"%s retains a visible sewn border" % state)
	var normal := toggle.get_theme_stylebox("normal") as StyleBoxFlat
	var hover := toggle.get_theme_stylebox("hover") as StyleBoxFlat
	var disabled := toggle.get_theme_stylebox("disabled") as StyleBoxFlat
	_check(normal != null and normal.bg_color.is_equal_approx(OXBLOOD)
		and normal.border_color.is_equal_approx(BRASS)
		and toggle.get_theme_color("font_color").is_equal_approx(BONE),
		"oxblood face, brass seam and pale bone label replace the default toggle face")
	_check(hover != null and disabled != null and normal != null
		and hover.bg_color != normal.bg_color and disabled.bg_color != normal.bg_color
		and hover.border_color.is_equal_approx(AMBER)
		and toggle.get_theme_color("font_hover_color").is_equal_approx(AMBER),
		"hover has distinct candle-amber border/text without losing its dark surface")
	_check(disabled != null
		and toggle.get_theme_color("font_disabled_color") != toggle.get_theme_color("font_color")
		and _contrast(toggle.get_theme_color("font_disabled_color"), disabled.bg_color) >= 4.5,
		"disabled wording is intentionally muted while still readable")
	var focus := toggle.get_theme_stylebox("focus") as StyleBoxFlat
	toggle.grab_focus()
	await process_frame
	_check(toggle.has_focus() and focus != null
		and focus == action.get_theme_stylebox("focus")
		and focus.border_color.is_equal_approx(AMBER)
		and focus.border_width_top >= 3 and not focus.draw_center
		and focus.expand_margin_left >= 3.0,
		"keyboard focus is a non-occluding expanded candle-amber ring")
	_check(toggle.get_theme_color("font_focus_color").is_equal_approx(BONE),
		"focused label remains bone against dark gothic background")
	toggle.button_pressed = false
	await process_frame
	var off_icon := toggle.get_theme_icon("unchecked")
	var on_icon := toggle.get_theme_icon("checked")
	var off_disabled_icon := toggle.get_theme_icon("unchecked_disabled")
	var on_disabled_icon := toggle.get_theme_icon("checked_disabled")
	_check(not toggle.button_pressed
		and off_icon != null and on_icon != null
		and off_icon != on_icon
		and off_icon.get_width() > 0 and on_icon.get_width() > 0,
		"the built-in switch has separate visible unchecked and checked indicator assets")
	toggle.button_pressed = true
	await process_frame
	_check(toggle.button_pressed and off_icon != on_icon
		and toggle.get_theme_icon("checked") == on_icon
		and toggle.get_theme_icon("unchecked") == off_icon,
		"on/off changes the real toggle state without losing either indicator")
	toggle.disabled = true
	await process_frame
	_check(toggle.disabled and toggle.button_pressed
		and off_disabled_icon != null and on_disabled_icon != null
		and off_disabled_icon != on_disabled_icon,
		"disabled checked and unchecked indicators remain individually recognizable")
	toggle.disabled = false
	toggle.button_pressed = false
	toggle.add_theme_font_size_override("font_size", 17)
	_check(toggle.get_theme_font_size("font_size") == 17
		and action.get_theme_font_size("font_size") == 18
		and gothic.default_font_size == 18,
		"S2's local 17px override stays available without shrinking other buttons")
	_check(gothic.get_stylebox("panel", "Panel") != null
		and gothic.get_stylebox("panel", "PanelContainer") != null
		and gothic.get_color("bone", "GothicPalette").is_equal_approx(BONE)
		and gothic.get_color("brass", "GothicPalette").is_equal_approx(BRASS),
		"panel resources and shared gothic tokens remain present")
	host.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s2_gothic_toggle_theme_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
