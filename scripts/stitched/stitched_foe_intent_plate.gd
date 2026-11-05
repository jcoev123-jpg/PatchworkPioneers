class_name StitchedFoeIntentPlate
extends NinePatchRect
## Passive, textured presentation of a single authoritative StitchedFoeIntent projection.
## This control cannot pick targets, consume RNG, or advance combat.

const PLATE_TEXTURE := preload("res://assets/paper/ui/hud_name_plate.png")
const HEADING_FONT := preload("res://assets/fonts/LondrinaSolid-Regular.ttf")
const BONE := Color("f5e5cd")
const BRASS := Color("e5b86d")
const PLATE_SIZE := Vector2(144, 62)

var foe_id := ""
var foe_rank := 0
var primary: Label
var secondary: Label


func _init() -> void:
	texture = PLATE_TEXTURE
	self_modulate = Color("62464a")
	patch_margin_left = 22
	patch_margin_right = 22
	patch_margin_top = 13
	patch_margin_bottom = 13
	size = PLATE_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	visible = false


func _ready() -> void:
	primary = Label.new()
	primary.name = "IntentText"
	primary.position = Vector2(9, 6)
	primary.size = Vector2(126, 29)
	primary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	primary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	primary.clip_text = true
	primary.add_theme_font_override("font", HEADING_FONT)
	primary.add_theme_font_size_override("font_size", 21)
	primary.add_theme_color_override("font_color", BONE)
	primary.add_theme_color_override("font_shadow_color", Color("160c13"))
	primary.add_theme_constant_override("shadow_offset_x", 1)
	primary.add_theme_constant_override("shadow_offset_y", 1)
	primary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(primary)
	secondary = Label.new()
	secondary.name = "IntentTarget"
	secondary.position = Vector2(9, 36)
	secondary.size = Vector2(126, 20)
	secondary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	secondary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	secondary.clip_text = true
	secondary.add_theme_font_size_override("font_size", 15)
	secondary.add_theme_color_override("font_color", BRASS)
	secondary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(secondary)


func clear_intent() -> void:
	foe_id = ""
	foe_rank = 0
	visible = false
	tooltip_text = ""
	if primary != null:
		primary.text = ""
	if secondary != null:
		secondary.text = ""


func present_intent(intent: Dictionary, rank: int) -> void:
	if intent.is_empty() or rank < 1 or rank > 4:
		clear_intent()
		return
	foe_id = str(intent.get("foe_id", ""))
	foe_rank = rank
	var heading := str(intent.get("ability_name", ""))
	var target := ""
	var detail := ""
	if bool(intent.get("stun", false)):
		heading = "STUN"
		target = "NO ACTION"
		detail = "STUN: next turn will be skipped"
	elif bool(intent.get("pass", false)):
		heading = "PASS"
		target = "NO ACTION"
		detail = "PASS: no currently legal ability or target"
	else:
		var side := str(intent.get("target_side", ""))
		var ranks: Array[String] = []
		for affected in intent.get("affected_ranks", []):
			ranks.append(str(affected))
		var prefix := "H" if side == "hero" else "F"
		var multi := bool(intent.get("multi", false))
		var several := multi or ranks.size() > 1
		target = ("ALL " if several else "") + prefix + ",".join(ranks)
		var side_name := "HERO" if side == "hero" else "FOE"
		if several:
			detail = "%s %s ranks %s (chosen target rank %d)" % [
				"ALL legal" if multi else "Multiple",
				side_name, ", ".join(ranks), int(intent.get("target_rank", 0))]
		else:
			detail = "Target: %s rank %d" % [side_name, int(intent.get("target_rank", 0))]
	primary.text = _fit_caption(heading, primary)
	secondary.text = _fit_caption(target, secondary)
	tooltip_text = "%s · %s · %s\nCurrent intent; may change if ranks or statuses change" % [
		str(intent.get("foe_name", "")), heading, detail]
	visible = not foe_id.is_empty()


func set_inspected(value: bool) -> void:
	if primary != null:
		primary.add_theme_color_override("font_color", BRASS if value else BONE)


func _fit_caption(value: String, label: Label) -> String:
	var full := value.replace("\n", " ").replace("\r", " ").strip_edges().to_upper()
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	if font == null or font.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= label.size.x:
		return full
	var shortened := full
	while not shortened.is_empty() and font.get_string_size(shortened + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > label.size.x:
		shortened = shortened.substr(0, shortened.length() - 1)
	return shortened.strip_edges() + "…"
