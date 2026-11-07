class_name StitchedRouteGraphView
extends VBoxContainer
## Projection of the session's generated map. Lit nodes request a route;
## the mounted app alone authenticates and enters it.

const NODE_ART := "res://assets/paper/ui/map_node_%s.png"
signal route_requested(id: String)

const FELT := "res://assets/paper/ui/panel_felt.png"
const ROUTE_BUTTON_ART := "res://assets/paper/ui/reward_button.png"
const BONE := Color("#efdfc0")
const AMBER := Color("#ffe0a0")
const VISITED := Color("#c6b6d9")
const FUTURE := Color("#b6a9a0")

var inspected_route_id := ""
var legal_ids: Array[String] = []
var _nodes: Dictionary = {}
var _edge_labels: Dictionary = {}
var _preview: Label


func present(map: RunMap, choices: Array[String]) -> void:
	name = "StitchedRouteGraphView"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size.y = 166
	add_theme_constant_override("separation", 3)
	legal_ids = choices.duplicate()
	var route := map.get_route()
	var current_id := map.get_current_node_id()
	var floors := map.get_floors()
	set_meta("floor_count", floors.size())
	set_meta("visited_ids", route.duplicate())
	set_meta("legal_ids", legal_ids.duplicate())
	set_meta("current_id", current_id)

	var heading := _label("TWELVE FLOORS  /  BRANCH ATLAS", 16, AMBER)
	heading.name = "GraphTitle"
	add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.name = "RouteGraphScroll"
	scroll.custom_minimum_size.y = 102
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.gui_input.connect(_on_graph_scroll_input.bind(scroll))
	add_child(scroll)
	var bands := VBoxContainer.new()
	bands.name = "RouteGraphBands"
	bands.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bands.add_theme_constant_override("separation", 6)
	scroll.add_child(bands)

	for index in floors.size():
		var floor_nodes: Array = floors[index]
		var band := VBoxContainer.new()
		band.name = "GraphFloor_%02d" % (index + 1)
		band.set_meta("floor", index + 1)
		band.set_meta("node_ids", floor_nodes.map(func(record: Dictionary): return str(record.id)))
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_theme_constant_override("separation", 4)
		bands.add_child(band)
		var floor_heading := _label("FLOOR %02d%s" % [index + 1,
			"  /  FINAL SEAM" if index == floors.size() - 1 else ""], 14, BONE)
		band.add_child(floor_heading)
		var row := HBoxContainer.new()
		row.name = "GraphFloorPaths"
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 2)
		band.add_child(row)
		for record in floor_nodes:
			_add_node(row, record, route, current_id)
	_preview = _label("FOCUS A LIT TICKET TO TRACE ITS NEXT SEAMS", 16, BONE)
	_preview.name = "RouteGraphPreview"
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview.custom_minimum_size.y = 44
	_preview.set_meta("preview_ids", [])
	add_child(_preview)
	_refresh_inspection()


## Scroll the whole authored atlas; never page the underlying run or admit a node.
func _on_graph_scroll_input(event: InputEvent, scroll: ScrollContainer) -> void:
	if event is InputEventKey and event.pressed and scroll.has_focus():
		if event.keycode == KEY_PAGEDOWN:
			scroll.scroll_vertical += maxi(48, int(scroll.size.y) - 16)
			scroll.accept_event()
		elif event.keycode == KEY_PAGEUP:
			scroll.scroll_vertical -= maxi(48, int(scroll.size.y) - 16)
			scroll.accept_event()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll.scroll_vertical += 56
			scroll.accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll.scroll_vertical -= 56
			scroll.accept_event()


func set_inspected_route(id: String) -> void:
	if not legal_ids.has(id) or not _nodes.has(id):
		return
	inspected_route_id = id
	_refresh_inspection()


func clear_inspected_route(id: String = "") -> void:
	if not id.is_empty() and inspected_route_id != id:
		return
	inspected_route_id = ""
	_refresh_inspection()


func _add_node(parent: HBoxContainer, record: Dictionary, route: Array[String], current_id: String) -> void:
	var id: String = record.id
	var kind: String = record.type
	var status := "future"
	if route.has(id):
		status = "visited"
	if id == current_id:
		status = "current"
	elif legal_ids.has(id):
		status = "legal"
	var tile := VBoxContainer.new()
	tile.name = "GraphNode_" + id
	tile.custom_minimum_size.x = 81
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.focus_mode = Control.FOCUS_NONE
	tile.add_theme_constant_override("separation", 1)
	tile.set_meta("route_id", id)
	tile.set_meta("node_kind", kind)
	tile.set_meta("floor", record.floor)
	tile.set_meta("path", int(record.position) + 1)
	tile.set_meta("outgoing", record.outgoing.duplicate(true))
	tile.set_meta("node_data", record.duplicate(true))
	tile.set_meta("status", status)
	tile.set_meta("visited", route.has(id))
	tile.set_meta("current", id == current_id)
	tile.set_meta("legal", legal_ids.has(id))
	tile.set_meta("inspected", false)
	parent.add_child(tile)
	_nodes[id] = tile

	var icon_path := NODE_ART % kind.to_snake_case()
	if kind == "Treasure":
		icon_path = NODE_ART % "event"
	var art := _texture(icon_path)
	if art == null:
		icon_path = NODE_ART % "event"
		art = _texture(icon_path)
	var icon := TextureRect.new()
	icon.name = "GraphNodeIcon"
	icon.set_meta("art_path", icon_path)
	icon.texture = art
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(icon)

	var caption := _label(kind.to_upper(), 14, BONE)
	caption.name = "GraphNodeKind"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile.add_child(caption)
	var path_label := _label("FLOOR %02d" % record.floor, 14, BONE)
	path_label.name = "GraphNodeFloor"
	tile.add_child(path_label)
	var position_label := _label("PATH %d" % (int(record.position) + 1), 14, BONE)
	position_label.name = "GraphNodePath"
	tile.add_child(position_label)
	var state_label := _label("", 14, AMBER)
	state_label.name = "GraphNodeState"
	tile.add_child(state_label)
	if status == "legal":
		_add_activation(tile, id)

	# Each authored directed edge has its own inert label and exact source /
	# target IDs. In particular, crossed links are never inferred from layout.
	var exits := HFlowContainer.new()
	exits.name = "GraphNodeEdges"
	exits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exits.add_theme_constant_override("h_separation", 2)
	exits.add_theme_constant_override("v_separation", 0)
	tile.add_child(exits)
	var labels: Array[Label] = []
	for target in record.outgoing:
		var edge := _label("→ F%02d P%d" % [
			_floor_of_id(str(target)), _path_of_id(str(target))], 14, FUTURE)
		edge.name = "GraphEdge_" + str(target)
		edge.set_meta("source_id", id)
		edge.set_meta("target_id", str(target))
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		exits.add_child(edge)
		labels.append(edge)
	_edge_labels[id] = labels
	_style_node(id)


## Only an actual, mounted, enabled control may request entry. The view
## never modifies the session; the app checks the page/snapshot/choice again.
func _add_activation(tile: VBoxContainer, id: String) -> void:
	var button := Button.new()
	button.name = "GraphNodeActivate"
	button.text = "ENTER"
	button.set_meta("route_id", id)
	button.set_meta("art_path", ROUTE_BUTTON_ART)
	button.custom_minimum_size = Vector2(81, 34)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", BONE)
	button.add_theme_color_override("font_hover_color", AMBER)
	button.add_theme_color_override("font_focus_color", AMBER)
	var texture := _texture(ROUTE_BUTTON_ART)
	if texture != null:
		for face in ["normal", "hover", "pressed", "focus"]:
			var skin := StyleBoxTexture.new()
			skin.texture = texture
			skin.texture_margin_left = 12
			skin.texture_margin_right = 12
			skin.texture_margin_top = 12
			skin.texture_margin_bottom = 12
			if face == "focus" or face == "hover":
				skin.modulate_color = Color("#f4c77b")
			elif face == "pressed":
				skin.modulate_color = Color("#bd997c")
			button.add_theme_stylebox_override(face, skin)
	tile.add_child(button)
	button.mouse_entered.connect(func(): set_inspected_route(id))
	button.mouse_exited.connect(func():
		if not button.has_focus():
			clear_inspected_route(id))
	button.focus_entered.connect(func():
		set_inspected_route(id)
		var scroll := get_node("RouteGraphScroll") as ScrollContainer
		scroll.call_deferred("ensure_control_visible", button))
	button.focus_exited.connect(func():
		if not button.is_hovered():
			clear_inspected_route(id))
	button.gui_input.connect(_on_activation_input.bind(button, id))
	button.pressed.connect(func():
		if legal_ids.has(id) and tile.get_meta("status") == "legal" \
			and button.get_parent() == tile and button.is_visible_in_tree() \
			and not button.disabled and is_visible_in_tree():
			route_requested.emit(id))


## Escape cancels a focused preview without requesting or spending a route.
func _on_activation_input(event: InputEvent, button: Button, id: String) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		clear_inspected_route(id)
		button.release_focus()
		button.accept_event()


func _refresh_inspection() -> void:
	for id in _nodes:
		_style_node(str(id))
	if _preview == null:
		return
	var exits: Array = []
	var purpose := ""
	if not inspected_route_id.is_empty()and _nodes.has(inspected_route_id):
		exits = _nodes[inspected_route_id].get_meta("outgoing", []).duplicate(true)
		var node: Control = _nodes[inspected_route_id]
		_preview.text = "LIT F%02d P%d  →  %s" % [
			node.get_meta("floor"), node.get_meta("path"),
			" / ".join(exits.map(func(target): return "F%02d P%d" % [
				_floor_of_id(str(target)), _path_of_id(str(target))]))
			if not exits.is_empty() else "FINAL SEAM"]
		purpose = stop_purpose_for(str(node.get_meta("node_kind", "")))
		if not purpose.is_empty():
			_preview.text += "\n" + purpose
		_preview.add_theme_color_override("font_color", AMBER)
	else:
		_preview.text = "FOCUS A LIT TICKET TO TRACE ITS NEXT SEAMS"
		_preview.add_theme_color_override("font_color", BONE)
	_preview.set_meta("preview_ids", exits)
	_preview.set_meta("stop_purpose", purpose)


## Truthful, price-free purpose of a split stop kind (legacy Rest/Shop are
## aliased by the shared projection); empty for every other node kind.
static func stop_purpose_for(kind: String) -> String:
	var help := RunV3StopChoiceProjection.stitched_stop_help_for(
		RunV3StopChoiceProjection.v3_kind_for(kind))
	return str(help.get("lead", ""))


func _style_node(id: String) -> void:
	var tile: VBoxContainer = _nodes[id]
	var status: String = tile.get_meta("status")
	var inspected := id == inspected_route_id
	tile.set_meta("inspected", inspected)
	var ink := FUTURE
	var state := "FUTURE"
	match status:
		"visited":
			ink = VISITED
			state = "VISITED"
		"current":
			ink = Color("#fff0d2")
			state = "CURRENT"
		"legal":
			ink = AMBER
			state = "LEGAL"
	if inspected:
		ink = Color("#fff3cd")
		state = "FOCUSED"
	var icon: TextureRect = tile.get_node("GraphNodeIcon")
	icon.modulate = ink
	for caption_name in ["GraphNodeKind", "GraphNodeFloor", "GraphNodePath", "GraphNodeState"]:
		var caption: Label = tile.get_node(caption_name)
		caption.add_theme_color_override("font_color", ink)
	(tile.get_node("GraphNodeState") as Label).text = state
	for edge in _edge_labels[id]:
		edge.add_theme_color_override("font_color", AMBER if inspected else (
			VISITED if status in ["visited", "current"] else FUTURE))


func _floor_of_id(id: String) -> int:
	return int(id.substr(1, 2))


func _path_of_id(id: String) -> int:
	return int(id.get_slice("_n", 1)) + 1


func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _texture(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null
