class_name RunRouteAtlas
extends Control
## Standalone node request view: RunMap remains the only graph and route authority.
## The view emits requests, never commits a choice or draws from any RNG.
## bind_map(null) clears everything. refresh() always rebuilds from defensive snapshots.
## All positions are local to the 1240 x 600 preview; a parent may center it in 1280 x 720.
##
## The preview is the owner's OPEN BOOK (ART_STYLE "Map"): two cream pages, a stitched
## spine, a running-stitch frame, a page curl and a ribbon bookmark are drawn behind every
## thread and patch, and a drawn pin marks the party's current patch. The optional owner
## map-board image (MAP_BOARD_PATH) replaces the drawn pages when ResourceLoader confirms
## it exists; a missing image keeps the complete drawn book, so no PNG is required.
##
## Presentation only: a stitch that becomes legal because the party just visited its source
## sews into view with a transparent-to-coloured gradient mask on the existing full path.
## A Line2D gradient REPLACES default_color while installed, so the mask repeats the stitch's
## own legal-thread RGB: opaque behind the sewing front, fully transparent ahead of it.
## The mask never touches points, default_color, metadata or the model, is removed when the
## reveal ends (or the view rebuilds), and every request/refresh path stays synchronous.

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
## Owner art path, kept in code so the relay's ART phase can drop in the board image.
const MAP_BOARD_PATH := "res://assets/paper/backgrounds/map_board.png"
const BOOK_RECT := Rect2(10.0, 20.0, 1220.0, 564.0)
## The gutter falls in the gap between floors 6 and 7, so no patch covers the spine.
const PAGE_LEFT := Rect2(18.0, 28.0, 591.0, 548.0)
const PAGE_RIGHT := Rect2(624.0, 28.0, 598.0, 548.0)
const SPINE_RECT := Rect2(609.0, 24.0, 15.0, 556.0)
const BOOKMARK_RECT := Rect2(609.0, 4.0, 15.0, 132.0)
const CURL_SIZE := 70.0
const STITCH_INSET := 9.0
const PAPER := Color("#ecdfbd")
const PAPER_SHADE := Color("#d8c9a2")
const SPINE_FILL := Color("#b7a276")
const THREAD := Color("#c9b996")
const INK := Color("#4a3f35")
const BOOKMARK_FILL := Color("#a2544a")
const PIN_SIZE := Vector2(24.0, 30.0)
## Normal and presentation-only fast reveal of a newly legal stitch, in seconds.
const REVEAL_DURATION := 0.6
const REVEAL_FAST_DURATION := 0.15

signal node_requested(id: String)

var _map: RunMap = null
var _revision := 0
var _rendered_generation := 0
var _rendered_graph: Array = []
var _rendered_route: Array[String] = []
var _rendered_legal: Array[String] = []
var _rendered_shortcuts: Array[String] = []
## Last map snapshot this view actually rendered, so a repeat refresh never replays.
var _rendered_map: RunMap = null
var _has_snapshot := false
## Running stitch reveals only; every entry is released by the next refresh or teardown.
var _reveal_masks: Dictionary = {}
var _reveal_tweens: Array[Tween] = []
var _pending_reveals: Array[Line2D] = []
## Presentation-only switch: the same reveal at 0.15 s instead of 0.6 s.
var reveal_fast := false
var _board_texture: Texture2D = null
## Owner or data may hand the board image in directly; null falls back to the path.
var board_texture_override: Texture2D = null
var board_texture_path := MAP_BOARD_PATH


## Inert drawn pushpin over the party's current patch; never takes pointer or focus.
class CurrentPin extends Control:
	const HEAD := Color("#c9605a")
	const HEAD_SHADE := Color("#8f3f3d")
	const NEEDLE := Color("#f0e6cf")

	var pin_id := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		var head := Vector2(size.x * 0.5, size.y * 0.38)
		var radius := minf(size.x, size.y) * 0.34
		draw_line(head, Vector2(size.x * 0.5, size.y), NEEDLE, 2.0, true)
		draw_circle(head, radius, HEAD)
		draw_circle(head + Vector2(-radius * 0.35, -radius * 0.35), radius * 0.36, HEAD_SHADE)


func _init() -> void:
	custom_minimum_size = ATLAS_SIZE
	size = ATLAS_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	# _input covers the initial atlas opening even when another Control owns focus.
	set_process_input(true)
	set_process_unhandled_input(false)


func _ready() -> void:
	resized.connect(queue_redraw)


## A map may be bound before the view enters the tree (the overlay does exactly that),
## so queued reveals start on the first processed frame instead of being dropped.
func _process(_delta: float) -> void:
	if _pending_reveals.is_empty():
		set_process(false)
		return
	if not is_inside_tree():
		return
	var queued := _pending_reveals.duplicate()
	_pending_reveals.clear()
	for line in queued:
		var mask: Gradient = _reveal_masks.get(line)
		if is_instance_valid(line) and mask != null:
			_start_reveal_tween(line, mask)
	set_process(false)


## Leaving the tree releases every reveal: no tween may outlive its threads.
func _exit_tree() -> void:
	_teardown_reveal()


## Presentation-only switch: the same reveal settles in 0.15 s instead of 0.6 s.
func set_reveal_fast(fast: bool) -> void:
	reveal_fast = fast


func reveal_duration() -> float:
	return REVEAL_FAST_DURATION if reveal_fast else REVEAL_DURATION


func is_revealing() -> bool:
	return not _reveal_masks.is_empty() or not _pending_reveals.is_empty()


## Canonical "source->target" keys whose stitch is currently sewing into view.
func revealing_edges() -> Array[String]:
	var keys: Array[String] = []
	for line in _reveal_masks:
		if is_instance_valid(line) and line.has_meta("from_id") and line.has_meta("to_id"):
			keys.append(str(line.get_meta("from_id")) + "->" + str(line.get_meta("to_id")))
	keys.sort()
	return keys


## Directed edges the model currently paints as visited-to-legal stitches.
static func _legal_edge_keys(graph: Array, route: Array, legal: Array) -> Dictionary:
	var keys: Dictionary = {}
	for floor_nodes in graph:
		for node in floor_nodes:
			var source: String = node["id"]
			if not route.has(source):
				continue
			for target in node["outgoing"]:
				if legal.has(target):
					keys[source + "->" + str(target)] = true
	return keys


## The mask is a hard alpha step that moves from the source end to the target end.
## Line2D.gradient REPLACES default_color while it is installed, so both stops carry the
## stitch's own legal-thread RGB: opaque behind the sewing front and fully transparent ahead,
## which keeps the newly sewn pixels the model-selected colour instead of white.
static func _new_reveal_mask(thread_color: Color) -> Gradient:
	var mask := Gradient.new()
	mask.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var sewn := Color(thread_color.r, thread_color.g, thread_color.b, thread_color.a)
	var unsewn := Color(thread_color.r, thread_color.g, thread_color.b, 0.0)
	mask.set_color(0, sewn)
	mask.set_color(1, unsewn)
	mask.set_offset(0, 0.0)
	mask.set_offset(1, 0.0)
	return mask


static func _set_reveal_front(mask: Gradient, progress: float) -> void:
	if mask != null:
		mask.set_offset(1, clampf(progress, 0.0, 1.0))


## Attach a hidden-ahead-of-the-front mask to an existing full-path thread.
func _begin_reveal(line: Line2D) -> void:
	if not is_instance_valid(line):
		return
	var mask := _new_reveal_mask(line.default_color)
	line.gradient = mask
	_reveal_masks[line] = mask
	if is_inside_tree():
		_start_reveal_tween(line, mask)
		return
	if not _pending_reveals.has(line):
		_pending_reveals.append(line)
	set_process(true)


func _start_reveal_tween(line: Line2D, mask: Gradient) -> void:
	if not is_inside_tree() or not is_instance_valid(line):
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_method(func(value: float) -> void: _set_reveal_front(mask, value),
		0.0, 1.0, reveal_duration())
	tween.tween_callback(_finish_reveal.bind(line, mask))
	_reveal_tweens.append(tween)


## Completion drops the temporary mask so default_color stays authoritative.
func _finish_reveal(line: Line2D, mask: Gradient) -> void:
	if not is_instance_valid(line):
		_reveal_masks.erase(line)
		return
	if _reveal_masks.get(line) == mask:
		line.gradient = null
		_reveal_masks.erase(line)


func _teardown_reveal() -> void:
	for tween in _reveal_tweens:
		if is_instance_valid(tween):
			tween.kill()
	_reveal_tweens.clear()
	for line in _reveal_masks:
		if is_instance_valid(line):
			line.gradient = null
	_reveal_masks.clear()
	_pending_reveals.clear()
	set_process(false)


func bind_map(map: RunMap) -> void:
	_map = map
	refresh()


func refresh() -> void:
	# Each rebuild invalidates every previous marker callback, including callbacks
	# retained by a caller after a Control has been detached or freed.
	_revision += 1
	# Snapshot what the party already saw before this rebuild releases it.
	var previous_map := _rendered_map
	var previous_graph := _rendered_graph
	var previous_route := _rendered_route.duplicate()
	var previous_legal := _rendered_legal.duplicate()
	var had_snapshot := _has_snapshot
	# Kill and release every prior reveal before its threads are removed.
	_teardown_reveal()
	_rendered_graph = []
	_rendered_generation = 0
	_rendered_route.clear()
	_rendered_legal.clear()
	_rendered_shortcuts.clear()
	_rendered_map = null
	_has_snapshot = false
	# Synchronous removal avoids stale, queued-for-deletion duplicates on repeated refresh.
	for child in get_children():
		remove_child(child)
		child.free()
	_board_texture = board_texture_override if board_texture_override != null \
		else load_board_texture(board_texture_path)
	queue_redraw()
	if _map == null or not _map.is_generated():
		return
	var floors: Array = _map.get_floors()
	var chosen: Array[String] = _map.get_route()
	var legal: Array[String] = _map.get_legal_choices()
	_rendered_generation = _map.get_generation_revision()
	_rendered_graph = floors.duplicate(true)
	_rendered_route = chosen.duplicate()
	_rendered_legal = legal.duplicate()
	_rendered_map = _map
	_has_snapshot = true
	# A visited-to-legal stitch is new only when this exact map never showed it before.
	# An unchanged snapshot therefore keeps its already-shown stitches still.
	var previous_edges: Dictionary = {}
	if had_snapshot and previous_map == _map:
		previous_edges = _legal_edge_keys(previous_graph, previous_route, previous_legal)
	var reveal_keys: Dictionary = {}
	if not _map.is_complete():
		var current_edges := _legal_edge_keys(_rendered_graph, _rendered_route, _rendered_legal)
		for key in current_edges:
			if not previous_edges.has(key):
				reveal_keys[key] = true
	# Number only live choices, not all nodes or Dictionary insertion order.
	# Source floor rows are explicitly sorted by their model position.
	for floor_nodes in floors:
		var ordered: Array = floor_nodes.duplicate()
		ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["position"]) < int(b["position"]))
		for node in ordered:
			var id: String = node["id"]
			if legal.has(id) and not chosen.has(id):
				_rendered_shortcuts.append(id)
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
					_add_thread(source_id, target_id, positions, chosen, legal, reveal_keys)
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
		# Dark ink keeps the floor strip readable on the cream page.
		floor_header.add_theme_color_override("font_color", INK)
		_inert(floor_header)
		add_child(floor_header)
		for node in floors[floor_index]:
			var id: String = node["id"]
			var shortcut := _rendered_shortcuts.find(id) + 1
			_add_marker(id, String(node["type"]), positions[id], chosen, legal, shortcut)
	# The pin is the last child so it sits on top of its patch, never behind it.
	var current_id: String = _map.get_current_node_id()
	if not current_id.is_empty() and positions.has(current_id):
		_add_pin(current_id, positions[current_id])


## A missing owner image leaves the complete drawn book instead of failing the preview.
static func load_board_texture(path: String = MAP_BOARD_PATH) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	return load(path) as Texture2D


func uses_board_texture() -> bool:
	return _board_texture != null


func board_texture() -> Texture2D:
	return _board_texture


## The owner board fills the whole preview, exactly like the drawn open book, so the
## same sewn map keeps its pages, spine, curl and bookmark with or without the image.
func board_texture_rect() -> Rect2:
	if _board_texture == null or _board_texture.get_width() <= 0 or _board_texture.get_height() <= 0:
		return Rect2()
	return Rect2(Vector2.ZERO, ATLAS_SIZE)


## Deterministic geometry of the drawn open book; empty when the owner image is mounted.
func drawn_book_geometry() -> Dictionary:
	if uses_board_texture():
		return {}
	return {
		"book": BOOK_RECT,
		"left_page": PAGE_LEFT,
		"right_page": PAGE_RIGHT,
		"spine": SPINE_RECT,
		"curl": curl_rect(),
		"bookmark": BOOKMARK_RECT,
		"stitch_inset": STITCH_INSET,
		"paper": PAPER,
	}


func curl_rect() -> Rect2:
	return Rect2(PAGE_RIGHT.end - Vector2(CURL_SIZE, CURL_SIZE), Vector2(CURL_SIZE, CURL_SIZE))


func _draw() -> void:
	if _map == null or not _map.is_generated():
		return
	if uses_board_texture():
		# The owner board supplies pages, spine, curl and bookmark in one image.
		draw_texture_rect(_board_texture, board_texture_rect(), false)
		return
	# A soft table shadow under the sewn book keeps the cream pages readable.
	draw_rect(Rect2(BOOK_RECT.position + Vector2(7.0, 9.0), BOOK_RECT.size),
		Color(0.0, 0.0, 0.0, 0.22))
	draw_rect(BOOK_RECT, PAPER_SHADE)
	draw_rect(PAGE_LEFT, PAPER)
	draw_rect(PAGE_RIGHT, PAPER)
	# Gutter shading so the two pages read as one folded book, not a loose sheet.
	draw_rect(Rect2(PAGE_LEFT.end.x - 16.0, PAGE_LEFT.position.y, 16.0, PAGE_LEFT.size.y),
		Color(0.35, 0.30, 0.22, 0.12))
	draw_rect(Rect2(PAGE_RIGHT.position.x, PAGE_RIGHT.position.y, 16.0, PAGE_RIGHT.size.y),
		Color(0.35, 0.30, 0.22, 0.12))
	draw_rect(SPINE_RECT, SPINE_FILL)
	# Running stitches down the spine.
	var stitch_y := int(SPINE_RECT.position.y) + 16
	while stitch_y < int(SPINE_RECT.end.y) - 8:
		draw_line(Vector2(SPINE_RECT.position.x + 4.0, float(stitch_y)),
			Vector2(SPINE_RECT.end.x - 4.0, float(stitch_y)), THREAD, 1.0, true)
		stitch_y += 26
	# Stitched frame on both pages, inset from the torn paper edge.
	_stitch_frame(PAGE_LEFT.grow(-STITCH_INSET))
	_stitch_frame(PAGE_RIGHT.grow(-STITCH_INSET))
	# Page curl folded up from the bottom-right corner of the right page.
	var curl := curl_rect()
	draw_colored_polygon(PackedVector2Array([
		Vector2(curl.end.x - CURL_SIZE, curl.end.y),
		curl.end,
		curl.end - Vector2(CURL_SIZE * 0.55, CURL_SIZE * 0.55),
	]), PAPER_SHADE)
	draw_dashed_line(Vector2(curl.end.x - CURL_SIZE, curl.end.y), curl.end,
		THREAD, 1.2, 6.0)
	# Ribbon bookmark hanging over the spine's top edge.
	draw_colored_polygon(PackedVector2Array([
		BOOKMARK_RECT.position,
		Vector2(BOOKMARK_RECT.end.x, BOOKMARK_RECT.position.y),
		BOOKMARK_RECT.end,
		Vector2(BOOKMARK_RECT.position.x + BOOKMARK_RECT.size.x * 0.5,
			BOOKMARK_RECT.end.y - 12.0),
		Vector2(BOOKMARK_RECT.position.x, BOOKMARK_RECT.end.y),
	]), BOOKMARK_FILL)
	draw_dashed_line(BOOKMARK_RECT.position + Vector2(4.0, 6.0),
		Vector2(BOOKMARK_RECT.position.x + 4.0, BOOKMARK_RECT.end.y - 18.0), THREAD, 1.0, 5.0)


func _stitch_frame(rect: Rect2) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]
	for index in range(corners.size()):
		var from: Vector2 = corners[index]
		var to: Vector2 = corners[(index + 1) % corners.size()]
		draw_dashed_line(from, to, THREAD, 1.4, 7.0)
	for corner: Vector2 in corners:
		draw_line(corner + Vector2(-4, -4), corner + Vector2(4, 4), THREAD, 1.2, true)
		draw_line(corner + Vector2(4, -4), corner + Vector2(-4, 4), THREAD, 1.2, true)


func _node_position(floor_index: int, row_index: int) -> Vector2:
	return Vector2(FIRST_X + floor_index * FLOOR_STEP, FIRST_Y + row_index * ROW_STEP)


func _add_thread(source: String, target: String, positions: Dictionary,
		chosen: Array[String], legal: Array[String], reveal_keys: Dictionary) -> void:
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
	if state == "legal" and reveal_keys.has(source + "->" + target):
		_begin_reveal(line)


func _add_marker(id: String, kind: String, at: Vector2,
		chosen: Array[String], legal: Array[String], shortcut: int) -> void:
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
	caption.text = (str(shortcut) + "\n" if state == "legal" and shortcut > 0 else "") + kind
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color("#fff8e9"))
	_inert(caption)
	marker.add_child(caption)
	if state == "legal":
		# Only a legal marker owns an actionable Control; its transparent face
		# preserves the original paper style. Canonical ID is in Action tooltip and metadata.
		var action := Button.new()
		action.name = "Action"
		action.flat = true
		action.focus_mode = Control.FOCUS_ALL
		action.mouse_filter = Control.MOUSE_FILTER_STOP
		action.position = Vector2(2, 2)
		action.size = NODE_SIZE - Vector2(4, 4)
		action.tooltip_text = "Request " + kind + " " + id
		action.pressed.connect(_request_node.bind(id, _map, _revision))
		marker.add_child(action)
	add_child(marker)


## The drawn pin names the party's current patch; it is decoration only.
func _add_pin(id: String, at: Vector2) -> void:
	var pin := CurrentPin.new()
	pin.name = "Pin_current"
	pin.pin_id = id
	pin.set_meta("pin_node_id", id)
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.focus_mode = Control.FOCUS_NONE
	pin.position = at + Vector2(NODE_SIZE.x * 0.5 - PIN_SIZE.x * 0.5, -PIN_SIZE.y + 16.0)
	pin.custom_minimum_size = PIN_SIZE
	pin.size = PIN_SIZE
	add_child(pin)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event
	if not key.pressed or key.echo or not is_inside_tree() or not is_visible_in_tree():
		return
	var index := -1
	match key.keycode:
		KEY_1:
			index = 0
		KEY_2:
			index = 1
		KEY_3:
			index = 2
		KEY_4:
			index = 3
	if index < 0 or index >= _rendered_shortcuts.size():
		return
	if _request_node(_rendered_shortcuts[index], _map, _revision):
		get_viewport().set_input_as_handled()


func _request_node(id: String, source_map: RunMap, revision: int) -> bool:
	# A stale callback is invalid even if the old Control has been removed.
	# Check model snapshots too: external progress and regeneration can happen
	# before a caller refreshes the view.
	if source_map == null or _map != source_map or revision != _revision:
		return false
	if not _map.is_generated() or _map.is_complete():
		return false
	if _map.get_generation_revision() != _rendered_generation:
		return false
	if _map.get_floors() != _rendered_graph or _map.get_route() != _rendered_route:
		return false
	var legal := _map.get_legal_choices()
	if legal != _rendered_legal or not legal.has(id):
		return false
	node_requested.emit(id)
	return true


func _inert(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.focus_mode = Control.FOCUS_NONE
