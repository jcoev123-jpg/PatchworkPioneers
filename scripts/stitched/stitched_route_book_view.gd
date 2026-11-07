class_name StitchedRouteBookView
extends HBoxContainer
## Read-only stitched map spread. The app owns every route Button and its
## guarded session.enter() callback; this view only lays out genuine records.

const FELT := "res://assets/paper/ui/panel_felt.png"
const NODE_ART := "res://assets/paper/ui/map_node_%s.png"
const BONE := Color("#f4e1bf")
const AMBER := Color("#f6d78e")

var visited_ids: Array[String] = []
var legal_ids: Array[String] = []
var graph_view: StitchedRouteGraphView


func present(map: RunMap, choices: Array[String]) -> VBoxContainer:
	name = "StitchedRouteBookView"
	custom_minimum_size = Vector2(1110, 326)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 15)
	visited_ids = map.get_route()
	legal_ids = choices.duplicate()
	set_meta("visited_ids", visited_ids.duplicate())
	set_meta("legal_ids", legal_ids.duplicate())

	var diary := _felt_page("RouteOrVisitStory", 409)
	var tickets := _felt_page("LegalChoices", 675)
	_heading(diary, "THE SEWN JOURNEY", 20, AMBER)
	var current_id := map.get_current_node_id()
	set_meta("current_id", current_id)
	var current := map.get_node(current_id)
	var here: Label
	if current.is_empty():
		here = _heading(diary, "AT THE FIRST SEAM  /  FLOOR 01 OF 12", 15, BONE)
	else:
		here = _heading(diary, "HERE  /  FLOOR %02d  /  %s  /  PATH %d" % [
			current.floor, current.type, current.position + 1], 15, BONE)
	here.name = "CurrentSeam"
	graph_view = StitchedRouteGraphView.new()
	diary.add_child(graph_view)
	graph_view.present(map, choices)
	_heading(diary, "VISITED STITCHES  /  IN JOURNEY ORDER", 14, AMBER)
	var history_scroll := ScrollContainer.new()
	history_scroll.name = "VisitedSeamScroll"
	history_scroll.custom_minimum_size = Vector2(365, 48)
	history_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	diary.add_child(history_scroll)
	var seams := VBoxContainer.new()
	seams.name = "VisitedSeams"
	seams.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seams.add_theme_constant_override("separation", 5)
	history_scroll.add_child(seams)
	if visited_ids.is_empty():
		_heading(seams, "No stops sewn yet. Choose a connected first stitch.", 17, BONE)
	else:
		for index in visited_ids.size():
			var id := visited_ids[index]
			var record := map.get_node(id)
			var row := HBoxContainer.new()
			row.name = "VisitedSeam_%02d" % index
			row.set_meta("route_id", id)
			row.set_meta("node_kind", record.type)
			row.set_meta("floor", record.floor)
			row.set_meta("path", record.position + 1)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.custom_minimum_size.y = 38
			row.add_theme_constant_override("separation", 9)
			seams.add_child(row)
			_add_icon(row, str(record.type), 35)
			_heading(row, "%02d   FLOOR %02d  /  %s  /  PATH %d" % [
				index + 1, record.floor, record.type, record.position + 1], 16, BONE)

	_heading(tickets, "LIT STOPS  /  CONNECTED THREADS", 22, AMBER)
	_heading(tickets, "FLOOR %02d OF 12   /   %d LEGAL PATHS" % [
		map.get_current_floor() + 1, choices.size()], 17, BONE)
	var scroll := ScrollContainer.new()
	scroll.name = "RunActionScroll"
	scroll.custom_minimum_size = Vector2(630, 238)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tickets.add_child(scroll)
	var decisions := VBoxContainer.new()
	decisions.name = "PublicRouteDecisions"
	decisions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decisions.add_theme_constant_override("separation", 8)
	scroll.add_child(decisions)
	return decisions


func decorate_ticket(button: Button, kind: String) -> void:
	# The existing reward-button art doubles as a candle-amber focus ring.
	var art := _texture("res://assets/paper/ui/reward_button.png")
	if art != null:
		var focus := StyleBoxTexture.new()
		focus.texture = art
		focus.texture_margin_left = 13
		focus.texture_margin_right = 13
		focus.texture_margin_top = 13
		focus.texture_margin_bottom = 13
		focus.modulate_color = Color("#a8703f")
		button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_hover_color", AMBER)
	button.add_theme_color_override("font_pressed_color", AMBER)
	button.add_theme_color_override("font_focus_color", AMBER)
	button.add_theme_font_size_override("font_size", 18)
	button.set_meta("ticket_kind", kind)


func _felt_page(page_name: String, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = page_name
	panel.custom_minimum_size = Vector2(width, 326)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var texture := _texture(FELT)
	if texture != null:
		var skin := StyleBoxTexture.new()
		skin.texture = texture
		skin.texture_margin_left = 24
		skin.texture_margin_right = 24
		skin.texture_margin_top = 24
		skin.texture_margin_bottom = 24
		skin.content_margin_left = 16
		skin.content_margin_right = 16
		skin.content_margin_top = 12
		skin.content_margin_bottom = 12
		skin.modulate_color = Color(0.34, 0.30, 0.36, 0.98)
		panel.add_theme_stylebox_override("panel", skin)
	add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	return body


func _heading(parent: Node, value: String, font_size: int, ink: Color) -> Label:
	var caption := Label.new()
	caption.text = value
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", font_size)
	caption.add_theme_color_override("font_color", ink)
	parent.add_child(caption)
	return caption


func _add_icon(parent: Node, kind: String, dimension: float) -> void:
	var path := NODE_ART % kind.to_snake_case()
	if kind == "Treasure":
		path = NODE_ART % "event"
	var art := _texture(path)
	if art == null:
		path = NODE_ART % "event"
		art = _texture(path)
	if art == null:
		return
	var icon := TextureRect.new()
	icon.name = "VisitedNodeIcon"
	icon.texture = art
	icon.set_meta("art_path", path)
	icon.custom_minimum_size = Vector2(dimension, dimension)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)


func _texture(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null
