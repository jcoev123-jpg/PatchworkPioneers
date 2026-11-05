class_name StitchedTurnOrderRibbon
extends Control
## Read-only S5 turn tags: this display never asks the battle to roll or advance.
## Up to nine adaptive places accommodate four heroes, four foes and a boss's extra turn.

const RIBBON_WIDTH := 690.0
const MAX_TAG_WIDTH := 110.0
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
		tag.size = Vector2(MAX_TAG_WIDTH, TAG_HEIGHT)
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
		portrait.position = Vector2(3, 5)
		portrait.size = Vector2(28, 32)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(portrait)

		var fallback := Label.new()
		fallback.name = "NameFallback"
		fallback.position = Vector2(3, 5)
		fallback.size = Vector2(28, 32)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.clip_text = true
		fallback.add_theme_font_size_override("font_size", 11)
		fallback.add_theme_color_override("font_color", BONE)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(fallback)

		var rank := Label.new()
		rank.name = "SideRank"
		rank.position = Vector2(35, 2)
		rank.size = Vector2(34, 19)
		rank.clip_text = true
		rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rank.add_theme_font_size_override("font_size", 16)
		rank.add_theme_color_override("font_color", BONE)
		rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(rank)

		var marker := Label.new()
		marker.name = "NowMarker"
		marker.position = Vector2(35, 23)
		marker.size = Vector2(34, 17)
		marker.clip_text = true
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


## Fit to the resolved Gothic font rather than guessing from character count.
## Rank and cue must fit their own cells; a shortened fallback is disclosed
## with the complete public actor name in both mouse and keyboard tooltips.
func _fit_chip_text(label: Label, value: String, preferred: int, minimum: int, cell: Vector2) -> void:
	var font := label.get_theme_font("font")
	var size := preferred
	while size > minimum and (
		font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > cell.x - 2.0 or
		font.get_height(size) > cell.y - 1.0):
		size -= 1
	while not value.is_empty() and font.get_string_size(
		value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > cell.x - 2.0:
		value = value.substr(0, value.length() - 1)
	label.add_theme_font_size_override("font_size", size)
	label.text = value
	label.size = cell


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
	var help: Control = tag["help"]
	var viewport := get_viewport_rect()
	var origin := control.global_position + Vector2(0, TAG_HEIGHT + 3)
	help.global_position = Vector2(
		clampf(origin.x, viewport.position.x, viewport.end.x - help.size.x),
		clampf(origin.y, viewport.position.y, viewport.end.y - help.size.y))
	tag["help"].visible = control.visible and not control.tooltip_text.is_empty() and (
		bool(tag["hovered"]) or control.has_focus())


func _layout_tag(tag: Dictionary, index: int, width: float) -> void:
	var control: Control = tag["root"]
	control.position = Vector2(index * (width + TAG_GAP), 0)
	control.size = Vector2(width, TAG_HEIGHT)
	tag["frame"].size = control.size
	var portrait_width := 28.0 + floorf((width - 73.0) * 0.5)
	var face_size := Vector2(portrait_width, 32)
	tag["portrait"].position = Vector2(3, 5)
	tag["portrait"].size = face_size
	tag["fallback"].position = Vector2(3, 5)
	tag["fallback"].size = face_size
	var text_left := portrait_width + 7.0
	var text_width := width - text_left - 4.0
	tag["rank"].position = Vector2(text_left, 2)
	tag["rank"].size = Vector2(text_width, 19)
	tag["marker"].position = Vector2(text_left, 23)
	tag["marker"].size = Vector2(text_width, 17)


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
	var count := displayed_entries.size()
	var width := minf(MAX_TAG_WIDTH, floorf((RIBBON_WIDTH - TAG_GAP * (count - 1)) / maxi(1, count)))
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
		_layout_tag(tag, index, width)
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
		_fit_chip_text(tag["rank"], code, 16, 10, Vector2(tag["rank"].size.x, 19))
		var active := not is_over and not acting_id.is_empty() and id == acting_id
		_fit_chip_text(tag["marker"], "NOW" if active else StitchedTurnStatusCues.cue(unit), 12, 9, Vector2(tag["marker"].size.x, 17))
		tag["marker"].add_theme_color_override("font_color", AMBER if active else MUTED)
		tag["frame"].modulate = Color(1, 0.87, 0.67) if active else Color(0.85, 0.82, 0.78)
		# Never substitute a rank-mate's art or a generic enemy for an unknown ID.
		var path := str(ROSTER.art_paths(id).get("idle", ""))
		var texture: Texture2D = load(path) if not path.is_empty() and ResourceLoader.exists(path, "Texture2D") else null
		tag["portrait"].texture = texture
		tag["portrait"].visible = texture != null
		tag["fallback"].visible = texture == null
		_fit_chip_text(tag["fallback"], full_name.substr(0, 4), 11, 9, tag["fallback"].size)
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
