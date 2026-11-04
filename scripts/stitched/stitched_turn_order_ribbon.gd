class_name StitchedTurnOrderRibbon
extends Control
## Read-only S5 turn tags: this display never asks the battle to roll or advance.
## Nine fixed-sized places accommodate four heroes, four foes and a boss's extra turn.

const TAG_WIDTH := 73.0
const TAG_HEIGHT := 42.0
const TAG_GAP := 4.0
const MAX_TAGS := 9
const PLATE_PATH := "res://assets/paper/ui/hud_name_plate.png"
const AMBER := Color("e4b76a")
const BONE := Color("f0ddc0")
const MUTED := Color("c7b4a1")
const ROSTER := preload("res://scripts/live_enemy_roster.gd")

var displayed_entries: Array[Dictionary] = []
var _tags: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE
	var plate: Texture2D = load(PLATE_PATH) if ResourceLoader.exists(PLATE_PATH, "Texture2D") else null
	for index in range(MAX_TAGS):
		var tag := Control.new()
		tag.name = "TurnTag%d" % (index + 1)
		tag.position = Vector2(index * (TAG_WIDTH + TAG_GAP), 0)
		tag.size = Vector2(TAG_WIDTH, TAG_HEIGHT)
		tag.mouse_filter = Control.MOUSE_FILTER_STOP
		tag.focus_mode = Control.FOCUS_ALL
		add_child(tag)

		var frame := NinePatchRect.new()
		frame.name = "SewnPlate"
		frame.texture = plate
		frame.size = tag.size
		frame.patch_margin_left = 10
		frame.patch_margin_right = 10
		frame.patch_margin_top = 8
		frame.patch_margin_bottom = 8
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(frame)

		var portrait := TextureRect.new()
		portrait.name = "ActorPortrait"
		portrait.position = Vector2(4, 4)
		portrait.size = Vector2(33, 34)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(portrait)

		var fallback := Label.new()
		fallback.name = "NameFallback"
		fallback.position = Vector2(3, 5)
		fallback.size = Vector2(36, 32)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.clip_text = true
		fallback.add_theme_font_size_override("font_size", 11)
		fallback.add_theme_color_override("font_color", BONE)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(fallback)

		var rank := Label.new()
		rank.name = "SideRank"
		rank.position = Vector2(39, 2)
		rank.size = Vector2(30, 19)
		rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rank.add_theme_font_size_override("font_size", 17)
		rank.add_theme_color_override("font_color", BONE)
		rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(rank)

		var marker := Label.new()
		marker.name = "NowMarker"
		marker.position = Vector2(36, 22)
		marker.size = Vector2(34, 16)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		marker.add_theme_font_size_override("font_size", 12)
		marker.add_theme_color_override("font_color", AMBER)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(marker)

		# A real on-focus disclosure, not merely a mouse-only engine tooltip.
		# Both channels use the *same* public-unit text; the sewn plate is existing art.
		var help := NinePatchRect.new()
		help.name = "FocusTooltip"
		help.texture = plate
		help.position = Vector2(-236 if index >= 5 else 0, TAG_HEIGHT + 3)
		help.size = Vector2(304, 218)
		help.patch_margin_left = 10
		help.patch_margin_right = 10
		help.patch_margin_top = 8
		help.patch_margin_bottom = 8
		help.z_index = 20
		help.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(help)
		var help_label := Label.new()
		help_label.name = "TooltipText"
		help_label.position = Vector2(12, 10)
		help_label.size = Vector2(280, 198)
		help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		help_label.add_theme_font_size_override("font_size", 12)
		help_label.add_theme_color_override("font_color", BONE)
		help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		help.add_child(help_label)
		help.hide()

		_tags.append({"root": tag, "frame": frame, "portrait": portrait,
			"fallback": fallback, "rank": rank, "marker": marker,
			"help": help, "help_label": help_label, "hovered": false})
		tag.mouse_entered.connect(_on_hover.bind(index, true))
		tag.mouse_exited.connect(_on_hover.bind(index, false))
		tag.focus_entered.connect(_on_focus.bind(index))
		tag.focus_exited.connect(_on_blur.bind(index))
		tag.hide()


func _on_hover(index: int, hovered: bool) -> void:
	_tags[index]["hovered"] = hovered
	_sync_tip(index)


func _on_focus(index: int) -> void:
	_sync_tip(index)


func _on_blur(index: int) -> void:
	_sync_tip(index)


func _sync_tip(index: int) -> void:
	var tag: Dictionary = _tags[index]
	var control: Control = tag["root"]
	tag["help"].visible = control.visible and not control.tooltip_text.is_empty() and (
		bool(tag["hovered"]) or control.has_focus())


## Entries are supplied from public StitchedRules.turn_order() and get_unit().
## The original order and repeated IDs are preserved; only dead/lost entries vanish.
## The caller supplies an empty actor ID or is_over=true to clear NOW at battle end.
func show_order(entries: Array, acting_id: String, is_over: bool) -> void:
	displayed_entries.clear()
	for raw in entries:
		if not raw is Dictionary:
			continue
		var unit: Dictionary = raw
		if unit.is_empty() or (unit.get("dead") is bool and unit["dead"]) or (
			unit.get("lost") is bool and unit["lost"]):
			continue
		if unit.get("side") == "foe" and (
			(unit.get("hp") is int or unit.get("hp") is float) and float(unit["hp"]) <= 0):
			continue
		displayed_entries.append(unit.duplicate(true))
		if displayed_entries.size() == MAX_TAGS:
			break
	for index in range(_tags.size()):
		var tag: Dictionary = _tags[index]
		var control: Control = tag["root"]
		if index >= displayed_entries.size():
			control.hide()
			control.tooltip_text = ""
			tag["help_label"].text = ""
			tag["help"].hide()
			tag["hovered"] = false
			tag["portrait"].texture = null
			tag["portrait"].hide()
			tag["fallback"].text = ""
			tag["rank"].text = ""
			tag["marker"].text = ""
			continue
		var unit: Dictionary = displayed_entries[index]
		var id := str(unit.get("id", ""))
		var full_name := str(unit.get("name", id))
		if full_name.is_empty():
			full_name = "?"
		var side: Variant = unit.get("side")
		var rank: Variant = unit.get("rank")
		var code := "H" if side == "hero" else ("F" if side == "foe" else "?")
		if rank is int or rank is float:
			code += str(int(rank))
		control.tooltip_text = StitchedTurnStatusCues.tooltip(unit)
		tag["help_label"].text = control.tooltip_text
		tag["rank"].text = code
		var active := not is_over and not acting_id.is_empty() and id == acting_id
		tag["marker"].text = "NOW" if active else StitchedTurnStatusCues.cue(unit)
		tag["marker"].add_theme_color_override("font_color", AMBER if active else MUTED)
		tag["frame"].modulate = Color(1, 0.87, 0.67) if active else Color(0.85, 0.82, 0.78)
		# Never substitute a rank-mate's art or a generic enemy for an unknown ID.
		var path := str(ROSTER.art_paths(id).get("idle", ""))
		var texture: Texture2D = load(path) if not path.is_empty() and ResourceLoader.exists(path, "Texture2D") else null
		tag["portrait"].texture = texture
		tag["portrait"].visible = texture != null
		tag["fallback"].visible = texture == null
		tag["fallback"].text = full_name.substr(0, 6)
		control.show()
		_sync_tip(index)


func tag_at(index: int) -> Control:
	if index < 0 or index >= _tags.size():
		return null
	return _tags[index]["root"]


func portrait_at(index: int) -> TextureRect:
	if index < 0 or index >= _tags.size():
		return null
	return _tags[index]["portrait"]


func marker_at(index: int) -> Label:
	if index < 0 or index >= _tags.size():
		return null
	return _tags[index]["marker"]
