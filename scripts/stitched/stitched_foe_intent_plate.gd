class_name StitchedFoeIntentPlate
extends NinePatchRect
## Passive, textured presentation of a single authoritative StitchedFoeIntent projection.
## This control cannot pick targets, consume RNG, or advance combat.

const PLATE_TEXTURE := preload("res://assets/paper/ui/hud_name_plate.png")
const HEADING_FONT := preload("res://assets/fonts/LondrinaSolid-Regular.ttf")
const BONE := Color("f5e5cd")
const BRASS := Color("e5b86d")
const PLATE_SIZE := Vector2(148, 64)
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
	patch_margin_top = 11
	patch_margin_bottom = 11
	size = PLATE_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	visible = false


func _ready() -> void:
	glyph = TextureRect.new()
	glyph.name = "IntentGlyph"
	glyph.position = Vector2(8, 8)
	glyph.size = Vector2(26, 26)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.visible = false
	add_child(glyph)
	primary = Label.new()
	primary.name = "IntentText"
	primary.position = Vector2(8, 4)
	primary.size = Vector2(132, 29)
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
	secondary.position = Vector2(8, 36)
	secondary.size = Vector2(132, 24)
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
		primary.size.x = 132
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
	secondary.add_theme_font_size_override("font_size", 19)
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
			if affected is int and affected >= 1 and affected <= 4:
				ranks.append(str(affected))
		var multi := bool(intent.get("multi", false))
		var several := multi or ranks.size() > 1
		var side_name := "HERO" if side == "hero" else "FOE"
		var has_target: bool = side in ["hero", "foe"] and not ranks.is_empty() \
			and ranks.size() == intent.get("affected_ranks", []).size()
		if not has_target:
			target = "NO TARGET"
			detail = "No currently legal target"
		elif several:
			target = "%s RANKS %s" % [side_name, ",".join(ranks)]
			detail = "%s %s ranks %s (chosen target rank %d)" % [
				"ALL legal" if multi else "Multiple",
				side_name, ", ".join(ranks), int(intent.get("target_rank", 0))]
		else:
			target = "%s RANK %s" % [side_name, ranks[0]]
			detail = "Target: %s rank %s" % [side_name, ranks[0]]
		# Keep every affected rank readable, even for a four-rank target cue.
		while not _caption_width_fits(target, secondary) and secondary.get_theme_font_size("font_size") > 1:
			secondary.add_theme_font_size_override("font_size", secondary.get_theme_font_size("font_size") - 1)
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
			var mark_damage := int(intent.get("base_mark_damage", 0))
			if mark_damage > 0:
				base_detail += " · BONUS VS MARK +%d" % mark_damage
			# The rank list always wins over an optional damage cue. No clipped
			# numbers, and a zero-direct-damage buff is never labelled a hit.
			if has_target and ability_kind in ["melee", "ranged"] and high > 0:
				var candidate := target + " · %d–%d DAMAGE" % [low, high]
				if _caption_width_fits(candidate, secondary):
					target = candidate
	if glyph != null:
		glyph.texture = _texture_for_kind(ability_kind)
		glyph.visible = glyph.texture != null and not foe_id.is_empty()
	primary.position.x = 38 if glyph != null and glyph.visible else 8
	primary.size.x = 102 if glyph != null and glyph.visible else 132
	primary.text = _fit_caption(heading, primary)
	secondary.text = target
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


# The dedicated image-backed disclosure on hover/focus is the visible help.
# Keep tooltip_text as the complete, testable accessibility description, but
# prevent Godot's default floating tooltip from masking adjacent foe tickets.
func _get_tooltip(_at_position: Vector2) -> String:
	return ""

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
