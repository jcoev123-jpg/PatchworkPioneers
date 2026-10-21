class_name RunRouteAtlas
extends Control
## Standalone, inert read-only preview: RunMap remains the only graph and route authority.
## bind_map(null) clears everything. refresh() always rebuilds from defensive snapshots.
## All positions are local to the 1240 x 600 preview; a parent may center it in 1280 x 720.

const ATLAS_SIZE := Vector2(1240.0, 600.0)
const NODE_SIZE := Vector2(84.0, 58.0)
const FIRST_X := 30.0
const FLOOR_STEP := 99.0
const FIRST_Y := 130.0
const ROW_STEP := 106.0
const CHOSEN_BG := Color("#426458")
const LEGAL_BG := Color("#887244")
const OTHER_BG := Color("#484651")
const CHOSEN_THREAD := Color("#a6e4c5")
const LEGAL_THREAD := Color("#efd6a0")
const OTHER_THREAD := Color("#837886")

var _map: RunMap = null


func _init() -> void:
	custom_minimum_size = ATLAS_SIZE
	size = ATLAS_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_process_input(false)
	set_process_unhandled_input(false)


func bind_map(map: RunMap) -> void:
	_map = map
	refresh()


func refresh() -> void:
	# Synchronous removal avoids stale, queued-for-deletion duplicates on repeated refresh.
	for child in get_children():
		remove_child(child)
		child.free()
	if _map == null or not _map.is_generated():
		return
	var floors: Array = _map.get_floors()
	var chosen: Array[String] = _map.get_route()
	var legal: Array[String] = _map.get_legal_choices()
	var positions: Dictionary = {}
	for floor_index in range(floors.size()):
		var floor_nodes: Array = floors[floor_index]
		for node in floor_nodes:
			var id: String = node["id"]
			positions[id] = _node_position(floor_index, int(node["position"]))
	# Threads are children before any labels/markers, so they always render behind paper.
	for floor_nodes in floors:
		for node in floor_nodes:
			var source_id: String = node["id"]
			for target_id in node["outgoing"]:
				if positions.has(target_id):
					_add_thread(source_id, target_id, positions, chosen, legal)
	for floor_index in range(floors.size()):
		var floor_header := Label.new()
		floor_header.name = "Floor%02d" % (floor_index + 1)
		floor_header.set_meta("floor_number", floor_index + 1)
		floor_header.text = "%02d" % (floor_index + 1)
		floor_header.position = Vector2(FIRST_X + FLOOR_STEP * floor_index, 64.0)
		floor_header.size = Vector2(NODE_SIZE.x, 30.0)
		floor_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		floor_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		floor_header.add_theme_font_size_override("font_size", 16)
		floor_header.add_theme_color_override("font_color", Color("#d7c9ae"))
		_inert(floor_header)
		add_child(floor_header)
		for node in floors[floor_index]:
			var id: String = node["id"]
			_add_marker(id, String(node["type"]), positions[id], chosen, legal)


func _node_position(floor_index: int, row_index: int) -> Vector2:
	return Vector2(FIRST_X + floor_index * FLOOR_STEP, FIRST_Y + row_index * ROW_STEP)


func _add_thread(source: String, target: String, positions: Dictionary,
		chosen: Array[String], legal: Array[String]) -> void:
	var line := Line2D.new()
	line.name = "Thread_%s_%s" % [source, target]
	line.set_meta("from_id", source)
	line.set_meta("to_id", target)
	var start: Vector2 = positions[source] + Vector2(NODE_SIZE.x, NODE_SIZE.y * 0.5)
	var end: Vector2 = positions[target] + Vector2(0.0, NODE_SIZE.y * 0.5)
	var offset: Vector2 = end - start
	var normal := Vector2(-offset.y, offset.x).normalized()
	var path := PackedVector2Array()
	for i in range(13):
		var t := float(i) / 12.0
		var wobble := 0.0 if i == 0 or i == 12 else (1.6 if i % 2 == 0 else -1.6)
		path.append(start.lerp(end, t) + normal * wobble)
	# A small threaded arrow stitch indicates left-to-right direction.
	path.append(end + Vector2(-6.0, -3.5))
	path.append(end)
	path.append(end + Vector2(-6.0, 3.5))
	line.points = path
	line.width = 1.7
	line.antialiased = true
	var state := "other"
	if chosen.has(source) and chosen.has(target):
		state = "chosen"
	elif chosen.has(source) and legal.has(target):
		state = "legal"
	line.set_meta("route_state", state)
	match state:
		"chosen":
			line.default_color = CHOSEN_THREAD
		"legal":
			line.default_color = LEGAL_THREAD
		_:
			line.default_color = OTHER_THREAD
	add_child(line)


func _add_marker(id: String, kind: String, at: Vector2,
		chosen: Array[String], legal: Array[String]) -> void:
	var marker := PanelContainer.new()
	marker.name = "Node_" + id
	marker.set_meta("route_id", id)
	marker.set_meta("route_kind", kind)
	var state := "other"
	if chosen.has(id):
		state = "chosen"
	elif legal.has(id):
		state = "legal"
	marker.set_meta("route_state", state)
	var paper := StyleBoxFlat.new()
	paper.bg_color = OTHER_BG
	paper.border_color = Color("#938999")
	match state:
		"chosen":
			paper.bg_color = CHOSEN_BG
			paper.border_color = CHOSEN_THREAD
		"legal":
			paper.bg_color = LEGAL_BG
			paper.border_color = LEGAL_THREAD
	paper.set_border_width_all(2)
	paper.set_corner_radius_all(6)
	paper.content_margin_left = 1.0
	paper.content_margin_right = 1.0
	marker.add_theme_stylebox_override("panel", paper)
	marker.position = at
	marker.custom_minimum_size = NODE_SIZE
	marker.size = NODE_SIZE
	_inert(marker)
	var caption := Label.new()
	caption.name = "Identity"
	caption.text = kind + "\n" + id
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color("#fff8e9"))
	_inert(caption)
	marker.add_child(caption)
	add_child(marker)


func _inert(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.focus_mode = Control.FOCUS_NONE