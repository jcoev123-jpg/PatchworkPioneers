class_name StitchedFoeIntentPlate
extends NinePatchRect
## Passive, textured presentation of a single authoritative StitchedFoeIntent projection.
## This control cannot pick targets, consume RNG, or advance combat.

const PLATE_TEXTURE := preload("res://assets/paper/ui/hud_name_plate.png")
const HEADING_FONT := preload("res://assets/fonts/LondrinaSolid-Regular.ttf")
const BONE := Color("f5e5cd")
const BRASS := Color("e5b86d")
const PLATE_SIZE := Vector2(150, 76)
const ATTACK_TEXTURE := preload("res://assets/paper/ui/intent_attack.png")
const DEFEND_TEXTURE := preload("res://assets/paper/ui/intent_defend.png")
const BUFF_TEXTURE := preload("res://assets/paper/ui/intent_buff.png")
const DEBUFF_TEXTURE := preload("res://assets/paper/ui/intent_debuff.png")

var foe_id := ""
var foe_rank := 0
var ability_kind := ""
var glyph: TextureRect
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
	glyph = TextureRect.new()
	glyph.name = "IntentGlyph"
	glyph.position = Vector2(9, 10)
	glyph.size = Vector2(26, 26)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.visible = false
	add_child(glyph)
	primary = Label.new()
	primary.name = "IntentText"
	primary.position = Vector2(8, 6)
	primary.size = Vector2(134, 33)
	primary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	primary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	primary.clip_text = true
	primary.add_theme_font_override("font", HEADING_FONT)
	primary.add_theme_font_size_override("font_size", 24)
	primary.add_theme_color_override("font_color", BONE)
	primary.add_theme_color_override("font_shadow_color", Color("160c13"))
	primary.add_theme_constant_override("shadow_offset_x", 1)
	primary.add_theme_constant_override("shadow_offset_y", 1)
	primary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(primary)
	secondary = Label.new()
	secondary.name = "IntentTarget"
	secondary.position = Vector2(8, 43)
	secondary.size = Vector2(134, 26)
	secondary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	secondary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	secondary.clip_text = true
	secondary.add_theme_font_override("font", HEADING_FONT)
	secondary.add_theme_font_size_override("font_size", 19)
	secondary.add_theme_color_override("font_color", BRASS)
	secondary.add_theme_color_override("font_shadow_color", Color("160c13"))
	secondary.add_theme_constant_override("shadow_offset_x", 1)
	secondary.add_theme_constant_override("shadow_offset_y", 1)
	secondary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(secondary)


func clear_intent() -> void:
	foe_id = ""
	foe_rank = 0
	ability_kind = ""
	visible = false
	tooltip_text = ""
	if glyph != null:
		glyph.texture = null
		glyph.visible = false
	if primary != null:
		primary.position.x = 8
		primary.size.x = 134
		primary.text = ""
	if secondary != null:
		secondary.text = ""


func present_intent(intent: Dictionary, rank: int) -> void:
	if intent.is_empty() or rank < 1 or rank > 4:
		clear_intent()
		return
	foe_id = str(intent.get("foe_id", ""))
	foe_rank = rank
	var actual_name := str(intent.get("ability_name", ""))
	var heading := actual_name
	ability_kind = ""
	var target := ""
	var detail := ""
	var base_detail := ""
	if bool(intent.get("stun", false)):
		heading = "STUN"
		target = "NO ACTION"
		detail = "STUN: next turn will be skipped"
	elif bool(intent.get("pass", false)):
		heading = "PASS"
		target = "NO ACTION"
		detail = "PASS: no currently legal ability or target"
	else:
		ability_kind = str(intent.get("ability_kind", ""))
		if ability_kind == "move":
			heading = "MOVE " + actual_name
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
		var damage: Array = intent.get("base_damage", [])
		if damage.size() == 2:
			var low := int(damage[0])
			var high := int(damage[1])
			base_detail = "BASE DMG %d–%d · BASE ACC %d%% · BASE CRIT %+d" % [
				low, high, int(intent.get("base_acc", 0)), int(intent.get("base_crit", 0))]
			var effects: Dictionary = intent.get("base_effects", {})
			var keys := effects.keys()
			keys.sort()
			var effect_labels: Array[String] = []
			for key in keys:
				effect_labels.append("%s %+d" % [str(key), int(effects[key])])
			base_detail += " · BASE EFFECTS " + (", ".join(effect_labels) if not effect_labels.is_empty() else "none")
			# The rank list always wins over an optional damage cue. No clipped
			# numbers, and a zero-direct-damage buff is never labelled a hit.
			if high > 0:
				var candidate := target + " BASE %d–%d" % [low, high]
				if _caption_width_fits(candidate, secondary):
					target = candidate
	if glyph != null:
		glyph.texture = _texture_for_kind(ability_kind)
		glyph.visible = glyph.texture != null and not foe_id.is_empty()
	primary.position.x = 38 if glyph != null and glyph.visible else 8
	primary.size.x = 104 if glyph != null and glyph.visible else 134
	primary.text = _fit_caption(heading, primary)
	secondary.text = _fit_caption(target, secondary)
	var kind_detail := "Kind: " + ability_kind.to_upper() + " · " if not ability_kind.is_empty() else ""
	var disclosed_name := heading if bool(intent.get("pass", false)) or bool(intent.get("stun", false)) else actual_name
	tooltip_text = "%s · %s · %s%s%s\nCurrent intent; may change if ranks or statuses change" % [
		str(intent.get("foe_name", "")), disclosed_name,
		kind_detail, detail, "\n" + base_detail if not base_detail.is_empty() else ""]
	visible = not foe_id.is_empty()


func _texture_for_kind(kind: String) -> Texture2D:
	match kind:
		"melee", "ranged":
			return ATTACK_TEXTURE
		"guard":
			return DEFEND_TEXTURE
		"buff", "heal":
			return BUFF_TEXTURE
		"debuff":
			return DEBUFF_TEXTURE
	return null


func set_inspected(value: bool) -> void:
	if primary != null:
		primary.add_theme_color_override("font_color", BRASS if value else BONE)


func _caption_width_fits(value: String, label: Label) -> bool:
	var font := label.get_theme_font("font")
	return font == null or font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1,
		label.get_theme_font_size("font_size")).x <= label.size.x


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
