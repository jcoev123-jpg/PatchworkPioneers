class_name StitchedBattleChrome
extends RefCounted
## Authored fabric presentation only. Never owns a battle or calls combat actions.

const FELT := preload("res://assets/paper/ui/panel_felt.png")
const BUTTON := preload("res://assets/paper/ui/reward_button.png")
const NAME_PLATE := preload("res://assets/paper/ui/hud_name_plate.png")
const BAR_FRAME := preload("res://assets/paper/ui/hud_bar_frame.png")
const BONE := Color("f5e4cd")
const AMBER := Color("efc16e")


static func _box(texture: Texture2D, tint: Color, margin: float, focus: bool = false) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.texture_margin_left = margin
	box.texture_margin_right = margin
	box.texture_margin_top = margin
	box.texture_margin_bottom = margin
	box.modulate_color = tint
	box.content_margin_left = 0.0
	box.content_margin_right = 0.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	if focus:
		box.draw_center = false
		box.expand_margin_left = 2.0
		box.expand_margin_right = 2.0
		box.expand_margin_top = 2.0
		box.expand_margin_bottom = 2.0
	return box


static func style_button(button: BaseButton) -> void:
	var tones := {
		"normal": Color("9b7779"),
		"hover": Color("e9b873"),
		"pressed": Color("714a48"),
		"disabled": Color("64565b9c"),
		"focus": Color("ffd18c"),
	}
	for state in tones:
		button.add_theme_stylebox_override(state, _box(BUTTON, tones[state], 12.0, state == "focus"))
	button.add_theme_color_override("font_color", BONE)
	button.add_theme_color_override("font_hover_color", Color("ffedc8"))
	button.add_theme_color_override("font_pressed_color", BONE)
	button.add_theme_color_override("font_focus_color", AMBER)
	button.add_theme_color_override("font_disabled_color", Color("b2a49b"))
	button.add_theme_color_override("font_outline_color", Color("2b191b"))
	button.add_theme_constant_override("outline_size", 2)
	button.focus_mode = Control.FOCUS_ALL


static func action_tray(parent: Control, rectangle: Rect2) -> NinePatchRect:
	var tray := NinePatchRect.new()
	tray.name = "StitchedActionTray"
	tray.texture = FELT
	tray.position = rectangle.position
	tray.size = rectangle.size
	tray.self_modulate = Color("715356ed")
	tray.patch_margin_left = 18
	tray.patch_margin_right = 18
	tray.patch_margin_top = 14
	tray.patch_margin_bottom = 14
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tray)
	return tray


static func _meter(parent: Control, title: String, rectangle: Rect2, tint: Color) -> ProgressBar:
	var meter := ProgressBar.new()
	meter.name = title
	meter.position = rectangle.position
	meter.size = rectangle.size
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.show_percentage = false
	meter.min_value = 0.0
	meter.max_value = 1.0
	meter.value = 0.0
	meter.add_theme_stylebox_override("background", _box(NAME_PLATE, Color("422c32"), 4.0))
	meter.add_theme_stylebox_override("fill", _box(BUTTON, tint, 4.0))
	parent.add_child(meter)
	var frame := NinePatchRect.new()
	frame.name = title + "SewnFrame"
	frame.texture = BAR_FRAME
	frame.position = rectangle.position - Vector2(1, 2)
	frame.size = rectangle.size + Vector2(2, 4)
	frame.patch_margin_left = 7
	frame.patch_margin_right = 7
	frame.patch_margin_top = 5
	frame.patch_margin_bottom = 5
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	return meter


static func make_rank_meters(parent: Control, side: String, foot_x: float) -> Dictionary:
	# y530..554 is the existing HP row, below the full-size rank/name button.
	var root := Control.new()
	root.name = "RankMeters" + side.capitalize() + str(int(foot_x))
	root.position = Vector2(foot_x, 530)
	root.size = Vector2(170, 24)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)
	var is_hero := side == "hero"
	var hp := _meter(root, "HPFill", Rect2(11, 14, 74 if is_hero else 148, 8),
		Color("af655b"))
	var output := {"root": root, "hp": hp}
	if is_hero:
		var fray := _meter(root, "FrayFill", Rect2(90, 14, 69, 8), Color("d7a560"))
		var caption := Label.new()
		caption.name = "FrayReadout"
		caption.position = Vector2(87, 0)
		caption.size = Vector2(74, 22)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 11)
		caption.add_theme_color_override("font_color", BONE)
		caption.add_theme_color_override("font_outline_color", Color("25181d"))
		caption.add_theme_constant_override("outline_size", 2)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.z_index = 2
		root.add_child(caption)
		output["fray"] = fray
		output["fray_text"] = caption
	return output


static func present_rank(meters: Dictionary, unit: Dictionary, side: String) -> void:
	# The caller gives the exact current authoritative rank snapshot each refresh.
	var occupied := not unit.is_empty()
	var surface: Control = meters["root"]
	surface.visible = occupied
	var hp: ProgressBar = meters["hp"]
	hp.max_value = maxf(1.0, float(unit.get("max_hp", 1))) if occupied else 1.0
	hp.value = clampf(float(unit.get("hp", 0)), 0.0, hp.max_value)
	hp.tooltip_text = "HP %d/%d" % [int(unit.get("hp", 0)), int(unit.get("max_hp", 0))] if occupied else ""
	if side == "hero":
		var fray: ProgressBar = meters["fray"]
		var readout: Label = meters["fray_text"]
		fray.max_value = 200.0
		fray.value = clampf(float(unit.get("fray", 0)), 0.0, 200.0)
		fray.tooltip_text = "FRAY %d/200" % int(unit.get("fray", 0)) if occupied else ""
		readout.text = "FRAY %d/200" % int(unit.get("fray", 0)) if occupied else ""
