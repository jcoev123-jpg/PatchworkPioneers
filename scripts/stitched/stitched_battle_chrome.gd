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


static func style_action_button(button: Button, icon_path: String) -> void:
	# A non-interactive authored image beside the real Button text. This keeps
	# the original mouse rect, pressed connection, focus and sewn style states.
	style_button(button)
	button.add_theme_font_size_override("font_size", 14)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not ResourceLoader.exists(icon_path, "Texture2D"):
		return # Text-only fallback if the imported emblem is unavailable.
	var emblem := TextureRect.new()
	emblem.name = "ActionEmblem"
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.focus_mode = Control.FOCUS_NONE
	emblem.texture = load(icon_path) as Texture2D
	button.add_child(emblem)
	emblem.position = Vector2(9, 5)
	emblem.size = Vector2(19, 19)


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
	# The value is rendered separately; suppress the invisible percentage font
	# from imposing a 26px minimum on this 8px sewn progress strip.
	meter.add_theme_font_size_override("font_size", 1)
	meter.min_value = 0.0
	meter.max_value = 1.0
	meter.value = 0.0
	meter.add_theme_stylebox_override("background", _box(NAME_PLATE, Color("422c32"), 4.0))
	meter.add_theme_stylebox_override("fill", _box(BUTTON, tint, 4.0))
	parent.add_child(meter)
	# Godot's ProgressBar theme enforces a 26px internal minimum even with
	# percentage text hidden. Scale only its displayed strip to the authored
	# 8px slot; the sewn NinePatch frame stays at its intended unscaled size.
	meter.scale.y = rectangle.size.y / maxf(rectangle.size.y, meter.size.y)
	var frame := NinePatchRect.new()
	frame.name = title + "SewnFrame"
	frame.texture = BAR_FRAME
	# Keep the stitched frame in the bar band, not over the caption above.
	frame.position = rectangle.position - Vector2(1, 1)
	frame.size = rectangle.size + Vector2(2, 2)
	frame.patch_margin_left = 7
	frame.patch_margin_right = 7
	frame.patch_margin_top = 5
	frame.patch_margin_bottom = 5
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	return meter


static func _fit_readout(readout: Label, caption: String) -> void:
	# Measure the inherited Gothic font instead of relying on Label clipping.
	readout.text = caption
	var face: Font = readout.get_theme_font("font")
	var point_size := 11
	if face != null:
		for size_step in range(11, 7, -1):
			point_size = size_step
			if face.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size_step).x <= readout.size.x - 2.0:
				break
	readout.add_theme_font_size_override("font_size", point_size)
	# The inherited Gothic font can enforce a 16px minimum after text
	# changes. Scale its visible caption to 14px so it never covers the
	# adjacent image-backed progress frame in this 24px rank row.
	readout.size = Vector2(readout.size.x, 14)
	readout.scale.y = 14.0 / maxf(14.0, readout.size.y)


static func make_rank_meters(parent: Control, side: String, foot_x: float) -> Dictionary:
	# y530..554 is the existing HP row, below the full-size rank/name button.
	var root := Control.new()
	root.name = "RankMeters" + side.capitalize() + str(int(foot_x))
	root.position = Vector2(foot_x, 530)
	root.size = Vector2(170, 24)
	# PASS makes the complete, accurate HP/FRAY tooltip reachable by mouse
	# without consuming the parent's rank-button input.
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(root)
	var is_hero := side == "hero"
	var hp := _meter(root, "HPFill", Rect2(11, 15, 74 if is_hero else 148, 7),
		Color("af655b"))
	var hp_caption := Label.new()
	hp_caption.name = "HPReadout"
	hp_caption.position = Vector2(10, 0)
	hp_caption.size = Vector2(74 if is_hero else 149, 14)
	hp_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_caption.clip_text = true
	hp_caption.add_theme_font_size_override("font_size", 11)
	hp_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_caption.add_theme_color_override("font_color", BONE)
	hp_caption.add_theme_color_override("font_outline_color", Color("25181d"))
	hp_caption.add_theme_constant_override("outline_size", 2)
	hp_caption.z_index = 2
	root.add_child(hp_caption)
	var output := {"root": root, "hp": hp, "hp_text": hp_caption}
	if is_hero:
		var fray := _meter(root, "FrayFill", Rect2(90, 15, 69, 7), Color("d7a560"))
		var caption := Label.new()
		caption.name = "FrayReadout"
		caption.position = Vector2(87, 0)
		caption.size = Vector2(74, 14)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.clip_text = true
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
	# Presentation only: the caller supplies the authoritative outcome and RNG.
	var occupied := not unit.is_empty() and not bool(unit.get("lost", false)) and not bool(unit.get("dead", false))
	var surface: Control = meters["root"]
	surface.visible = occupied
	var hp: ProgressBar = meters["hp"]
	var hp_caption: Label = meters["hp_text"]
	var hp_frame: NinePatchRect = surface.get_node("HPFillSewnFrame")
	var hp_value := int(unit.get("hp", 0)) if occupied else 0
	var hp_max := int(unit.get("max_hp", 0)) if occupied else 0
	var hanging := occupied and hp_value == 0 and bool(unit.get("hanging", false))
	hp.max_value = maxf(1.0, float(hp_max))
	hp.value = clampf(float(hp_value), 0.0, hp.max_value)
	hp.tooltip_text = ("HP %d/%d" % [hp_value, hp_max]) if occupied else ""
	if hanging:
		hp.tooltip_text += " — HANGING BY A THREAD (still acts and holds rank)"
	_fit_readout(hp_caption, ("HANGING" if hanging else "HP %d/%d" % [hp_value, hp_max]) if occupied else "")
	hp_caption.add_theme_color_override("font_color", AMBER if hanging else BONE)
	hp_frame.self_modulate = Color("ffd18c") if hanging else Color.WHITE
	surface.tooltip_text = hp.tooltip_text
	if side == "hero":
		var fray: ProgressBar = meters["fray"]
		var readout: Label = meters["fray_text"]
		var fray_frame: NinePatchRect = surface.get_node("FrayFillSewnFrame")
		var fray_value := int(unit.get("fray", 0)) if occupied else 0
		var danger := occupied and fray_value >= 100
		fray.max_value = 200.0
		fray.value = clampf(float(fray_value), 0.0, 200.0)
		fray.add_theme_stylebox_override("fill", _box(BUTTON,
			Color("b95450") if danger else Color("d7a560"), 4.0))
		fray_frame.self_modulate = Color("ffd18c") if danger else Color.WHITE
		readout.add_theme_color_override("font_color", AMBER if danger else BONE)
		_fit_readout(readout, "FRAY %d/200" % fray_value if occupied else "")
		fray.tooltip_text = ""
		if occupied:
			# Thresholds are risks, not a guessed roll result. At 200,
			# the battle model alone decides the supplied HANGING/LOST state.
			fray.tooltip_text = ("FRAY %d/200" % fray_value
				+ " | 100 FRAY: resolve threshold (STEADFAST or UNRAVELLED)."
				+ " | 200 FRAY: COMES APART (HANGING, or LOST if already HANGING).")
			surface.tooltip_text += " | " + fray.tooltip_text
