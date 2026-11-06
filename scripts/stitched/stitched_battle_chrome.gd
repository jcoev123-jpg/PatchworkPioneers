class_name StitchedBattleChrome
extends RefCounted
## Authored fabric presentation only. Never owns a battle or calls combat actions.

const FELT := preload("res://assets/paper/ui/panel_felt.png")
const BUTTON := preload("res://assets/paper/ui/reward_button.png")
const NAME_PLATE := preload("res://assets/paper/ui/hud_name_plate.png")
const BAR_FRAME := preload("res://assets/paper/ui/hud_bar_frame.png")
const RANK_FONT := preload("res://assets/fonts/PatrickHand-Regular.ttf")
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
	# The real caption row keeps its fixed physical slot even when a rare
	# oversized source number would otherwise grow Label's minimum width.
	var hero_row := readout.name == "FrayReadout" or readout.get_parent().has_node("FrayReadout")
	var slot_width := 74.0 if hero_row else 149.0
	readout.text = caption
	readout.scale = Vector2.ONE
	var face: Font = readout.get_theme_font("font")
	var point_size := 13
	var available := slot_width - 2.0
	if face != null:
		# Standard numerators stay at >=13px; only exceptional wide source
		# values use smaller measured type, never omitted digits.
		while point_size > 10 and face.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x > available:
			point_size -= 1
	readout.add_theme_font_size_override("font_size", point_size)
	readout.size = Vector2(slot_width, 14.0)
	if face != null:
		var width := face.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x
		# If native Label insists on an extra-wide minimum for unusual data,
		# compress only horizontally so it cannot collide with FRAY's slot.
		if width > available or readout.size.x > slot_width:
			readout.scale.x = available / maxf(width, readout.size.x)

# Mirror the mounted screen's canonical order, without asking the screen to
# interpret statuses or touching its combat/inspection authority.
const STATUS_ORDER := [
	"bleed", "weak", "exposed", "thorns", "tangled", "blind",
	"riposte", "stun", "stun_resist", "mark", "guard",
]
const STATUS_ICONS := {
	"bleed": "status_bleed", "stun": "status_stun", "mark": "status_mark",
	"guard": "status_guard", "blind": "status_blind",
	"tangled": "status_tangled", "hanging": "status_hanging",
	"steadfast": "badge_steadfast", "unravelled": "badge_unravelled",
}
const BADGE_SHORT := {
	"weak": "WK", "exposed": "EX", "thorns": "TH",
	"riposte": "RP", "stun_resist": "SR", "dodge": "DG",
	"steadfast": "ST", "frantic": "FR", "hollow": "HO",
	"bitter": "BI", "reckless": "RE", "cowering": "CO",
	"hanging": "H",
}
const UNRAVELLED_TRAITS := ["frantic", "hollow", "bitter", "reckless", "cowering"]


static func _badge_entries(unit: Dictionary, side: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if unit.is_empty() or bool(unit.get("lost", false)) or bool(unit.get("dead", false)):
		return entries
	if int(unit.get("hp", 0)) == 0 and bool(unit.get("hanging", false)):
		entries.append({"id": "hanging", "short": "H", "count": "",
			"full": "HANGING BY A THREAD", "icon": "status_hanging"})
	if side == "hero":
		var resolve := str(unit.get("resolve", ""))
		if resolve == "steadfast":
			entries.append({"id": "steadfast", "short": "ST", "count": "",
				"full": "STEADFAST", "icon": "badge_steadfast"})
		elif resolve in UNRAVELLED_TRAITS:
			entries.append({"id": resolve, "short": str(BADGE_SHORT[resolve]), "count": "",
				"full": "UNRAVELLED — " + resolve.to_upper(), "icon": "badge_unravelled"})
	var statuses: Variant = unit.get("statuses", {})
	if statuses is Dictionary:
		var sorted_keys: Array[String] = []
		for key in STATUS_ORDER:
			if int(statuses.get(key, 0)) > 0:
				sorted_keys.append(key)
		var extras: Array[String] = []
		for key in statuses:
			var status := str(key)
			if not status in STATUS_ORDER and int(statuses[key]) > 0:
				extras.append(status)
		extras.sort()
		sorted_keys.append_array(extras)
		for key in sorted_keys:
			var amount := int(statuses[key])
			entries.append({"id": key,
				"short": str(BADGE_SHORT.get(key, key.left(2).to_upper())),
				"count": str(amount),
				"full": "%s %d" % [key.replace("_", " ").to_upper(), amount],
				"icon": str(STATUS_ICONS.get(key, ""))})
	var buff: Variant = unit.get("dodge_buff", {})
	if buff is Dictionary:
		var amount := int(buff.get("amount", 0))
		var turns := int(buff.get("turns", 0))
		if amount > 0 and turns > 0:
			entries.append({"id": "dodge", "short": "DG", "count": str(turns),
				"full": "DODGE +%d / %d turns" % [amount, turns], "icon": ""})
	return entries


static func _make_badge_row(root: Control) -> Control:
	# Child extends above the meter's y530 origin; global y486..504 exactly.
	# Six preallocated ticket nodes are reused for every presentation/refresh.
	var row := Control.new()
	row.name = "BadgeRow"
	row.position = Vector2(3, -44)
	row.size = Vector2(164, 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.focus_mode = Control.FOCUS_NONE
	root.add_child(row)
	for index in range(6):
		var chip := Control.new()
		chip.name = "Badge%d" % index
		chip.position = Vector2(index * 27, 0)
		chip.size = Vector2(26, 18)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.focus_mode = Control.FOCUS_NONE
		chip.visible = false
		row.add_child(chip)
		var felt := NinePatchRect.new()
		felt.name = "Felt"
		felt.texture = NAME_PLATE
		felt.size = chip.size
		felt.patch_margin_left = 5
		felt.patch_margin_right = 5
		felt.patch_margin_top = 5
		felt.patch_margin_bottom = 5
		felt.self_modulate = Color("9d817ee8")
		felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(felt)
		var emblem := TextureRect.new()
		emblem.name = "Emblem"
		emblem.position = Vector2(2, 2)
		emblem.size = Vector2(14, 14)
		emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(emblem)
		var caption := Label.new()
		caption.name = "Short"
		caption.position = Vector2(2, 1)
		caption.size = Vector2(16, 16)
		caption.add_theme_font_override("font", RANK_FONT)
		caption.add_theme_font_size_override("font_size", 10)
		caption.add_theme_color_override("font_color", BONE)
		caption.add_theme_color_override("font_outline_color", Color("25181d"))
		caption.add_theme_constant_override("outline_size", 1)
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(caption)
		var count := Label.new()
		count.name = "Count"
		count.position = Vector2(16, 1)
		count.size = Vector2(10, 16)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count.add_theme_font_override("font", RANK_FONT)
		count.add_theme_font_size_override("font_size", 9)
		count.add_theme_color_override("font_color", AMBER)
		count.add_theme_color_override("font_outline_color", Color("25181d"))
		count.add_theme_constant_override("outline_size", 1)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(count)
	return row


static func _present_badges(root: Control, unit: Dictionary, side: String) -> void:
	var row: Control = root.get_node("BadgeRow")
	var entries := _badge_entries(unit, side)
	var names: Array[String] = []
	for entry in entries:
		names.append(str(entry["full"]))
	row.tooltip_text = "STATUS: " + (", ".join(names) if not names.is_empty() else "none")
	root.tooltip_text += " | " + row.tooltip_text if root.visible else ""
	var shown := entries.size()
	var overflow := shown > 6
	if overflow:
		shown = 6
	for index in range(6):
		var chip: Control = row.get_node("Badge%d" % index)
		chip.visible = index < shown
		if index >= shown:
			chip.tooltip_text = ""
			continue
		var item: Dictionary = entries[index] if not overflow or index < 5 else {
			"id": "overflow", "short": "+", "count": str(entries.size() - 5),
			"full": "+%d more: %s" % [entries.size() - 5, ", ".join(names.slice(5))],
			"icon": "",
		}
		var emblem: TextureRect = chip.get_node("Emblem")
		var caption: Label = chip.get_node("Short")
		var count: Label = chip.get_node("Count")
		var icon_id := str(item["icon"])
		var icon_path := "res://assets/paper/stitched/icons/%s.png" % icon_id
		emblem.texture = load(icon_path) as Texture2D if not icon_id.is_empty() and ResourceLoader.exists(icon_path, "Texture2D") else null
		emblem.visible = emblem.texture != null
		caption.text = str(item["short"]) if not emblem.visible or str(item["count"]).is_empty() else ""
		caption.position.x = 16 if emblem.visible else 2
		caption.size.x = 10 if emblem.visible else 16
		# Resolve and Hanging icon identities also expose their real short name.
		count.text = str(item["short"]) if emblem.visible and str(item["count"]).is_empty() else str(item["count"])
		count.visible = not count.text.is_empty()
		chip.tooltip_text = str(item["full"])
	row.visible = not entries.is_empty()


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
	_make_badge_row(root)
	# Keep PatrickHand's glyphs at their native size while removing only
	# the font's unused line leading. No vertical glyph scaling or clipping.
	var caption_font := FontVariation.new()
	caption_font.base_font = RANK_FONT
	caption_font.spacing_top = -3
	caption_font.spacing_bottom = -2
	var is_hero := side == "hero"
	var hp := _meter(root, "HPFill", Rect2(11, 15, 74 if is_hero else 148, 7),
		Color("af655b"))
	var hp_caption := Label.new()
	hp_caption.name = "HPReadout"
	hp_caption.position = Vector2(10, 0)
	hp_caption.size = Vector2(74 if is_hero else 149, 14)
	hp_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_caption.clip_text = false
	hp_caption.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	hp_caption.add_theme_font_override("font", caption_font)
	hp_caption.add_theme_font_size_override("font_size", 13)
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
		caption.clip_text = false
		caption.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		caption.add_theme_font_override("font", caption_font)
		caption.add_theme_font_size_override("font_size", 13)
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
	_fit_readout(hp_caption, ("HANGING" if hanging else ("HP %d" % hp_value if side == "hero" else "HP %d/%d" % [hp_value, hp_max])) if occupied else "")
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
		_fit_readout(readout, "FRAY %d" % fray_value if occupied else "")
		fray.tooltip_text = ""
		if occupied:
			# Thresholds are risks, not a guessed roll result. At 200,
			# the battle model alone decides the supplied HANGING/LOST state.
			fray.tooltip_text = ("FRAY %d/200" % fray_value
				+ " | 100 FRAY: resolve threshold (STEADFAST or UNRAVELLED)."
				+ " | 200 FRAY: COMES APART (HANGING, or LOST if already HANGING).")
			surface.tooltip_text += " | " + fray.tooltip_text
	_present_badges(surface, unit if occupied else {}, side)
