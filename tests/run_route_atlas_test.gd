extends SceneTree

var failures: Array[String] = []
var checks := 0
var requests: Array[String] = []
## The six committed sewn tokens, written out independently of the view's own table so
## this regression cannot silently inherit an omission from the implementation.
const TOKEN_PATHS := {
	"Fight": "res://assets/paper/ui/map_node_fight.png",
	"Elite": "res://assets/paper/ui/map_node_elite.png",
	"Event": "res://assets/paper/ui/map_node_event.png",
	"Shop": "res://assets/paper/ui/map_node_shop.png",
	"Rest": "res://assets/paper/ui/map_node_rest.png",
	"Boss": "res://assets/paper/ui/map_node_boss.png",
}
## The five authored book areas, written out independently of the view's own table:
## name -> [first floor, last floor].
const AREA_LABELS := {
	"Meadow": [1, 3],
	"Woods": [4, 6],
	"Marsh": [7, 9],
	"Peaks": [10, 11],
	"Boss": [12, 12],
}


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _state(map: RunMap, rng: RandomNumberGenerator) -> Dictionary:
	return {
		"floors": map.get_floors(),
		"route": map.get_route(),
		"legal": map.get_legal_choices(),
		"current": map.get_current_node_id(),
		"floor": map.get_current_floor(),
		"complete": map.is_complete(),
		"generated": map.is_generated(),
		"rng": rng.state,
	}


func _expected_style(state: String) -> Color:
	match state:
		"chosen":
			return RunRouteAtlas.CHOSEN_BG
		"legal":
			return RunRouteAtlas.LEGAL_BG
		_:
			return RunRouteAtlas.OTHER_BG


func _expected_thread(state: String) -> Color:
	match state:
		"chosen":
			return RunRouteAtlas.CHOSEN_THREAD
		"legal":
			return RunRouteAtlas.LEGAL_THREAD
		_:
			return RunRouteAtlas.OTHER_THREAD


func _expected_border(state: String) -> Color:
	match state:
		"chosen":
			return RunRouteAtlas.CHOSEN_THREAD
		"legal":
			return RunRouteAtlas.LEGAL_THREAD
		_:
			return RunRouteAtlas.OTHER_BORDER


func _inside(rect: Rect2, outer: Rect2) -> bool:
	return rect.position.x >= outer.position.x and rect.position.y >= outer.position.y \
		and rect.end.x <= outer.end.x and rect.end.y <= outer.end.y


# The mounted preview must always show a complete open book: owner art or drawing.
func _verify_book(view: RunRouteAtlas, label: String) -> void:
	if view.uses_board_texture():
		var art := view.board_texture()
		var placed := view.board_texture_rect()
		_check(art is Texture2D and art.get_width() > 0 and art.get_height() > 0
			and placed == Rect2(Vector2.ZERO, view.size)
			and view.drawn_book_geometry().is_empty(),
			label + ": optional owner board image covers the map in place of the drawing")
		return
	var book := view.drawn_book_geometry()
	_check(book.has("left_page") and book.has("right_page") and book.has("spine")
		and book.has("curl") and book.has("bookmark") and book.has("paper"),
		label + ": complete drawn open book behind the map")
	if not (book.has("left_page") and book.has("right_page") and book.has("spine")
			and book.has("curl") and book.has("bookmark")):
		return
	var left: Rect2 = book["left_page"]
	var right: Rect2 = book["right_page"]
	var spine: Rect2 = book["spine"]
	var curl: Rect2 = book["curl"]
	var bookmark: Rect2 = book["bookmark"]
	_check(book["paper"] == RunRouteAtlas.PAPER and left.size.x >= 500.0 and right.size.x >= 500.0
		and left.end.x <= spine.position.x and spine.end.x <= right.position.x,
		label + ": two cream pages sit either side of the spine")
	_check(_inside(left, RunRouteAtlas.BOOK_RECT) and _inside(right, RunRouteAtlas.BOOK_RECT)
		and _inside(spine, RunRouteAtlas.BOOK_RECT) and left.end.x <= right.position.x,
		label + ": pages and spine stay inside the book")
	_check(_inside(curl, right) and is_equal_approx(curl.end.x, right.end.x)
		and is_equal_approx(curl.end.y, right.end.y) and curl.size.x >= 40.0,
		label + ": page curl folds the right page's bottom-right corner")
	_check(bookmark.position.y < RunRouteAtlas.BOOK_RECT.position.y
		and bookmark.position.x >= spine.position.x and bookmark.end.x <= spine.end.x
		and bookmark.end.y > spine.position.y,
		label + ": ribbon bookmark hangs over the spine's top edge")
	_check(float(book["stitch_inset"]) > 0.0
		and float(book["stitch_inset"]) * 2.0 < minf(left.size.x, left.size.y),
		label + ": stitched frame is inset from the torn page edge")
	# Every header and patch must sit on a page, never on the table or the spine.
	for index in range(view.get_child_count()):
		var child: Node = view.get_child(index)
		if not (child is PanelContainer or child is Label):
			continue
		var rect := Rect2(child.position, child.size)
		_check(_inside(rect, left) or _inside(rect, right),
			label + ": " + str(child.name) + " is sewn onto a page")


# The committed sewn token is a real, inert marker child on every supported kind. The
# caption never sits under it. Kinds outside this task's six authored mappings are left
# untouched here, so future art for them cannot be asserted away.
func _verify_token_marker(marker: PanelContainer, id: String, view: RunRouteAtlas,
		label: String) -> void:
	var kind: String = marker.get_meta("route_kind")
	var expected_path: String = TOKEN_PATHS.get(kind, "")
	if expected_path.is_empty():
		return
	var art := marker.get_node_or_null("Art") as RunRouteAtlas.NodeToken
	var identity := marker.get_node_or_null("Identity") as Label
	var action := marker.get_node_or_null("Action") as Button
	_check(art != null, label + ": committed sewn token mounted for " + kind + " " + id)
	if art == null:
		return
	var committed := load(expected_path) as Texture2D
	_check(committed != null and committed.get_width() > 0 and committed.get_height() > 0,
		label + ": authored token image loads with real pixels " + kind)
	_check(art.name == "Art" and art.token_kind == kind
		and art.get_meta("art_path") == expected_path
		and art.token_texture == committed
		and view.node_token_texture(expected_path) == art.token_texture,
		label + ": actual marker child carries the matching committed image " + kind + " " + id)
	_check(art.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and art.focus_mode == Control.FOCUS_NONE,
		label + ": token art is inert decoration, not an input target " + id)
	_check(marker.get_child(0) == art and identity != null
		and identity.get_index() > art.get_index()
		and (action == null or action.get_index() > identity.get_index())
		and marker.get_child_count() == (3 if action != null else 2),
		label + ": token sits before the identity caption and legal action " + id)
	var texture := art.token_texture
	var drawn := art.token_rect()
	_check(texture != null and drawn.size.x > 0.0 and drawn.size.y > 0.0,
		label + ": token has a real drawn rectangle " + id)
	if texture != null:
		_check(is_equal_approx(drawn.size.x / drawn.size.y,
			float(texture.get_width()) / float(texture.get_height())),
			label + ": token keeps the committed aspect ratio " + id)
		_check(drawn.position.x >= 0.0 and drawn.position.y >= 0.0
			and drawn.end.x <= art.size.x and drawn.end.y <= art.size.y
			and drawn.end.x <= RunRouteAtlas.NODE_TOKEN_COLUMN,
			label + ": token stays inside the marker's left art column " + id)
	var caption_width := identity.get_combined_minimum_size().x if identity != null else 0.0
	_check(identity != null and identity.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT
		and art.position.x + drawn.end.x + caption_width <= marker.size.x,
		label + ": readable caption keeps its own space beside the token " + id)
	# The three route-state borders survive behind the art: art stays off the border.
	var paper := marker.get_theme_stylebox("panel") as StyleBoxFlat
	_check(paper != null and art.position.x >= paper.get_margin(SIDE_LEFT)
		and art.position.y >= paper.get_margin(SIDE_TOP)
		and art.position.x + art.size.x <= marker.size.x - paper.get_margin(SIDE_RIGHT)
		and art.position.y + art.size.y <= marker.size.y - paper.get_margin(SIDE_BOTTOM),
		label + ": sewn token stays inside the visible patch border " + id)


## Kind mapping, optional loading, caching and both marker branches, from real source.
func _verify_token_sources(view: RunRouteAtlas, label: String) -> void:
	for kind in TOKEN_PATHS:
		var path: String = TOKEN_PATHS[kind]
		_check(RunRouteAtlas.node_token_path(kind) == path,
			label + ": exact authored " + kind + " kind maps to its committed token")
		var loaded := view.node_token_texture(path)
		_check(loaded != null and loaded == load(path) and view.has_cached_node_token(path),
			label + ": committed " + kind + " token loads once and is cached by path")
		_check(view.node_token_texture(path) == loaded,
			label + ": repeated " + kind + " load returns the cached texture")
		var art := RunRouteAtlas.NodeToken.new()
		art.token_kind = kind
		art.token_texture = loaded
		art.size = RunRouteAtlas.NODE_SIZE - Vector2(2.0, 4.0)
		var drawn := art.token_rect()
		_check(loaded != null and drawn.size.x > 0.0
			and is_equal_approx(drawn.size.x / drawn.size.y,
				float(loaded.get_width()) / float(loaded.get_height())),
			label + ": " + kind + " token drawn without stretching")
		art.free()
	# Unknown kinds and failed loads fall back to the drawn marker, never an error.
	_check(RunRouteAtlas.node_token_path("Forged").is_empty()
		and RunRouteAtlas.node_token_path("").is_empty(),
		label + ": unknown authored kinds have no token path")
	var failed_path := "res://assets/paper/ui/map_node_forged_token.png"
	_check(view.node_token_texture(failed_path) == null
		and view.has_cached_node_token(failed_path),
		label + ": a token that fails to load is null and cached, never an error")
	_check(view.node_token_texture("") == null, label + ": a blank token path loads nothing")
	# The real _add_marker branches: token art + right-aligned caption, or drawn fallback.
	var probe := RunRouteAtlas.new()
	var none: Array[String] = []
	var legal: Array[String] = ["f01_n0"]
	var fallback_legal: Array[String] = ["f01_n1"]
	probe._add_marker("f01_n0", "Elite", Vector2.ZERO, none, legal, 1)
	probe._add_marker("f01_n1", "Forged", Vector2(100.0, 0.0), none, fallback_legal, 2)
	var token_marker := probe.get_node_or_null("Node_f01_n0") as PanelContainer
	var drawn_marker := probe.get_node_or_null("Node_f01_n1") as PanelContainer
	_check(token_marker != null and token_marker.get_node_or_null("Art") is RunRouteAtlas.NodeToken
		and (token_marker.get_node("Identity") as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT
		and token_marker.get_node_or_null("Action") != null,
		label + ": supported kind mounts its token, caption and legal action together")
	_check(drawn_marker != null and drawn_marker.get_node_or_null("Art") == null
		and (drawn_marker.get_node("Identity") as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
		and drawn_marker.get_node_or_null("Action") != null,
		label + ": unknown kind keeps the drawn paper marker and still admits its legal action")
	probe.free()


# ---------------------------------------------------------------------------
# Authored area captions over their exact floor groups (drawn pages and owner board).
# ---------------------------------------------------------------------------

func _verify_area_labels(view: RunRouteAtlas, label: String) -> void:
	var found: Dictionary = {}
	for child in view.get_children():
		if not (child is Label) or not child.has_meta("area_name"):
			continue
		var area: Label = child
		var area_name: String = str(area.get_meta("area_name"))
		var span: Array = AREA_LABELS.get(area_name, [])
		_check(span.size() == 2 and not found.has(area_name),
			label + ": one authored area caption names " + area_name)
		if span.size() != 2 or found.has(area_name):
			continue
		found[area_name] = area
		_check(int(area.get_meta("first_floor")) == int(span[0])
			and int(area.get_meta("last_floor")) == int(span[1]),
			label + ": " + area_name + " names its exact floor span")
		_check(area.text == area_name and area.is_visible_in_tree(),
			label + ": open book visibly reads " + area_name)
		_check(area.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and area.focus_mode == Control.FOCUS_NONE,
			label + ": area caption never takes pointer or keyboard input: " + area_name)
		_check(area.get_theme_font_size("font_size") >= 14
			and area.get_theme_color("font_color") == RunRouteAtlas.INK,
			label + ": area caption is legible ink at map scale: " + area_name)
		var left := RunRouteAtlas.FIRST_X + float(int(span[0]) - 1) * RunRouteAtlas.FLOOR_STEP
		var right := RunRouteAtlas.FIRST_X + float(int(span[1]) - 1) * RunRouteAtlas.FLOOR_STEP \
			+ RunRouteAtlas.NODE_SIZE.x
		var rect := Rect2(area.position, area.size)
		_check(is_equal_approx(rect.position.x, left)
			and is_equal_approx(rect.size.x, right - left)
			and rect.end.y <= RunRouteAtlas.FIRST_Y,
			label + ": " + area_name + " spans its own floor columns above every patch")
		_check(_inside(rect, RunRouteAtlas.PAGE_LEFT) or _inside(rect, RunRouteAtlas.PAGE_RIGHT),
			label + ": " + area_name + " stays sewn on a page")
	_check(found.size() == AREA_LABELS.size(),
		label + ": only the authored area captions are mounted")
	for area_name in AREA_LABELS:
		_check(found.has(area_name), label + ": open book names the " + area_name + " area")


# Inspect actual mounted children, not internal arrays or a view-generated graph oracle.
func _verify(view: RunRouteAtlas, map: RunMap, rng: RandomNumberGenerator, label: String) -> void:
	var before := _state(map, rng)
	var floors: Array = map.get_floors()
	_check(floors.size() == 12 and floors[0].size() >= 3 and floors[0].size() <= 4,
		label + ": twelve actual floors with playable opening")
	if floors.size() != 12:
		return
	var expected_nodes: Dictionary = {}
	var expected_edges: Dictionary = {}
	for fi in range(floors.size()):
		_check(floors[fi].size() >= 3 and floors[fi].size() <= 4,
			label + ": actual floor node count %d" % (fi + 1))
		for node in floors[fi]:
			var id: String = node["id"]
			_check(not expected_nodes.has(id), label + ": distinct model ID " + id)
			expected_nodes[id] = node.duplicate(true)
			_check(node["floor"] == fi + 1 and node["position"] >= 0,
				label + ": authoritative floor and row positions")
			for to_id in node["outgoing"]:
				var pair := id + "->" + str(to_id)
				_check(not expected_edges.has(pair), label + ": model directed edges unique: " + pair)
				expected_edges[pair] = true

	var seen_nodes: Dictionary = {}
	var seen_edges: Dictionary = {}
	var seen_floors: Dictionary = {}
	## Authored kinds this seeded book actually shows a sewn token for.
	var seen_kinds: Dictionary = {}
	var first_marker_index := 999999
	var last_thread_index := -1
	var last_marker_index := -1
	var pin_ids: Array = []
	var pin_indices: Array = []
	var chosen: Array[String] = map.get_route()
	var legal: Array[String] = map.get_legal_choices()
	var ordered_legal: Array[String] = []
	for floor_nodes in floors:
		var sorted_nodes: Array = floor_nodes.duplicate()
		sorted_nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["position"]) < int(b["position"]))
		for node in sorted_nodes:
			if legal.has(node["id"]) and not chosen.has(node["id"]):
				ordered_legal.append(node["id"])
	var bounding := Rect2(Vector2.ZERO, view.size)
	_check(view.is_inside_tree() and view.size == RunRouteAtlas.ATLAS_SIZE,
		label + ": actual 1240x600 mounted preview")
	_check(_inside(Rect2(view.position, view.size), Rect2(Vector2.ZERO, Vector2(1280, 720))),
		label + ": full preview fits 1280x720")
	_check(view.mouse_filter == Control.MOUSE_FILTER_IGNORE and view.focus_mode == Control.FOCUS_NONE,
		label + ": atlas cannot capture pointer or keyboard focus")

	for index in range(view.get_child_count()):
		var child: Node = view.get_child(index)
		if child is Line2D:
			var line: Line2D = child
			last_thread_index = index
			_check(line.has_meta("from_id") and line.has_meta("to_id"),
				label + ": every visible thread identifies its directed endpoints")
			if not line.has_meta("from_id") or not line.has_meta("to_id"):
				continue
			var source: String = line.get_meta("from_id")
			var target: String = line.get_meta("to_id")
			var edge_key := source + "->" + target
			_check(expected_edges.has(edge_key) and not seen_edges.has(edge_key),
				label + ": no invented or repeated edge " + edge_key)
			seen_edges[edge_key] = line
			var state := "other"
			if chosen.has(source) and chosen.has(target):
				state = "chosen"
			elif chosen.has(source) and legal.has(target):
				state = "legal"
			_check(line.get_meta("route_state") == state and line.default_color == _expected_thread(state),
				label + ": colored stitch correctly reflects route")
			_check(line.points.size() == 16 and line.width > 0,
				label + ": visible zigzag plus arrowhead for " + edge_key)
			if expected_nodes.has(source) and expected_nodes.has(target) and line.points.size() >= 13:
				var from_node: Dictionary = expected_nodes[source]
				var to_node: Dictionary = expected_nodes[target]
				var expected_start := Vector2(
					RunRouteAtlas.FIRST_X + (int(from_node["floor"]) - 1) * RunRouteAtlas.FLOOR_STEP + RunRouteAtlas.NODE_SIZE.x,
					RunRouteAtlas.FIRST_Y + int(from_node["position"]) * RunRouteAtlas.ROW_STEP + RunRouteAtlas.NODE_SIZE.y * 0.5)
				var expected_end := Vector2(
					RunRouteAtlas.FIRST_X + (int(to_node["floor"]) - 1) * RunRouteAtlas.FLOOR_STEP,
					RunRouteAtlas.FIRST_Y + int(to_node["position"]) * RunRouteAtlas.ROW_STEP + RunRouteAtlas.NODE_SIZE.y * 0.5)
				_check(line.points[0].is_equal_approx(expected_start)
					and line.points[12].is_equal_approx(expected_end),
					label + ": ends reach exactly actual directed source and target: " + edge_key)
		elif child is PanelContainer:
			var marker: PanelContainer = child
			first_marker_index = mini(first_marker_index, index)
			last_marker_index = maxi(last_marker_index, index)
			_check(marker.has_meta("route_id") and marker.has_meta("route_kind")
				and marker.has_meta("route_state"), label + ": marker has real identity/type/state")
			if not marker.has_meta("route_id"):
				continue
			var id: String = marker.get_meta("route_id")
			_check(expected_nodes.has(id) and not seen_nodes.has(id),
				label + ": no invented or repeated marker: " + id)
			seen_nodes[id] = marker
			_check(_inside(Rect2(marker.position, marker.size), bounding),
				label + ": complete marker rectangle inside view " + id)
			_check(marker.size.x >= 80 and marker.size.y >= 55,
				label + ": legible compact marker dimensions " + id)
			_check(marker.focus_mode == Control.FOCUS_NONE, label + ": decorative panel cannot take focus " + id)
			var action: Button = marker.get_node_or_null("Action") as Button
			if legal.has(id) and not chosen.has(id):
				_check(action != null, label + ": legal ID owns a real button " + id)
				if action != null:
					_check(action.focus_mode == Control.FOCUS_ALL and not action.disabled
						and action.mouse_filter == Control.MOUSE_FILTER_STOP
						and _inside(Rect2(action.position, action.size), Rect2(Vector2.ZERO, marker.size))
						and action.size.x >= 70 and action.size.y >= 48,
						label + ": legal button is mouse/keyboard actionable within marker " + id)
					_check(action.tooltip_text.contains(id) and action.tooltip_text.contains(expected_nodes[id]["type"]),
						label + ": legal action tooltip identifies exact kind and id: " + id)
			else:
				_check(action == null and marker.mouse_filter == Control.MOUSE_FILTER_IGNORE,
					label + ": chosen/inaccessible node has no actionable button or focus " + id)
			var identity: Label = marker.get_node_or_null("Identity") as Label
			_check(identity != null, label + ": visible marker identity exists " + id)
			if identity != null and expected_nodes.has(id):
				var kind: String = expected_nodes[id]["type"]
				var expected_state := "chosen" if chosen.has(id) else ("legal" if legal.has(id) else "other")
				var number := ordered_legal.find(id) + 1
				var expected_caption := (str(number) + "\n" if expected_state == "legal" else "") + kind
				var panel_style := marker.get_theme_stylebox("panel") as StyleBoxFlat
				_check(marker.get_meta("route_kind") == kind
					and marker.get_meta("route_id") == id
					and identity.text == expected_caption
					and not identity.text.contains(id)
					and marker.get_meta("route_state") == expected_state,
					label + ": correct actual kind, caption without internal ID, and three-state highlights " + id)
				if expected_state == "legal":
					_check(identity.text.begins_with(str(number) + "\n"),
						label + ": legal destination displays sorted 1-4 number: " + id)
				else:
					_check(identity.text == kind,
						label + ": nonlegal marker displays kind without phantom number: " + id)
				_check(panel_style != null and panel_style.bg_color == _expected_style(expected_state),
					label + ": highlight is visibly colored, not metadata-only " + id)
				_check(panel_style != null and panel_style.border_color == _expected_border(expected_state),
					label + ": route-state border stays visible around the patch " + id)
				seen_kinds[kind] = true
				_verify_token_marker(marker, id, view, label)
				_check(identity.mouse_filter == Control.MOUSE_FILTER_IGNORE
					and identity.focus_mode == Control.FOCUS_NONE
					and identity.get_theme_font_size("font_size") >= 12,
					label + ": inert legible label " + id)
				_check(identity.get_combined_minimum_size().x <= marker.size.x
					and identity.get_combined_minimum_size().y <= marker.size.y,
					label + ": readable caption fits patch without spill " + id)
		elif child is Label:
			var header: Label = child
			if header.has_meta("floor_number"):
				var floor_num: int = header.get_meta("floor_number")
				_check(floor_num >= 1 and floor_num <= 12 and not seen_floors.has(floor_num)
					and header.text == "%02d" % floor_num, label + ": floor number shown once")
				seen_floors[floor_num] = true
			else:
				_check(header.has_meta("area_name"),
					label + ": only area captions or floor headers are plain labels")
			_check(_inside(Rect2(header.position, header.size), bounding)
				and header.mouse_filter == Control.MOUSE_FILTER_IGNORE
				and header.focus_mode == Control.FOCUS_NONE,
				label + ": header within bounds and inert")
		elif child is RunRouteAtlas.CurrentPin:
			var pin: RunRouteAtlas.CurrentPin = child
			_check(pin.has_meta("pin_node_id"), label + ": pin names its patch")
			pin_ids.append(pin.get_meta("pin_node_id"))
			pin_indices.append(index)
			_check(pin.mouse_filter == Control.MOUSE_FILTER_IGNORE
				and pin.focus_mode == Control.FOCUS_NONE,
				label + ": current pin is decoration, not an input target")
			_check(_inside(Rect2(pin.position, pin.size), bounding),
				label + ": current pin fits the preview")
		else:
			_check(false, label + ": unexpected rendered child: " + child.name)

	_check(seen_nodes.size() == expected_nodes.size() and seen_nodes.size() >= 36,
		label + ": one actual marker per 3-4 node across twelve floors")
	_check(seen_edges.size() == expected_edges.size() and seen_edges.size() >= 36,
		label + ": exact number of directed edges")
	_check(seen_floors.size() == 12, label + ": all twelve columns headed")
	for kind in TOKEN_PATHS:
		_check(seen_kinds.has(kind),
			label + ": seeded book renders the committed " + kind + " token")
	_check(last_thread_index < first_marker_index,
		label + ": every connection is behind every node")
	var current_id: String = map.get_current_node_id()
	var expected_pins: Array = [] if current_id.is_empty() else [current_id]
	_check(pin_ids == expected_pins, label + ": exactly the party's current patch is pinned")
	for pin_index in pin_indices:
		_check(int(pin_index) > last_marker_index, label + ": current pin sits above every patch")
	if seen_nodes.has(current_id) and not pin_indices.is_empty():
		var current_marker: PanelContainer = seen_nodes[current_id]
		var pin: Control = view.get_child(int(pin_indices[0]))
		_check(Rect2(pin.position, pin.size).intersects(Rect2(current_marker.position,
			current_marker.size)), label + ": current pin touches the pinned patch")
	_check(view.get_child_count() == expected_nodes.size() + expected_edges.size() + 12
		+ AREA_LABELS.size() + expected_pins.size(), label + ": no orphan/duplicate children")
	for id in expected_nodes:
		_check(seen_nodes.has(id), label + ": missing actual node " + id)
	for key in expected_edges:
		_check(seen_edges.has(key), label + ": missing actual edge " + key)
	_verify_area_labels(view, label)
	_verify_book(view, label)
	_check(_state(map, rng) == before, label + ": inspecting preview leaves map and RNG unchanged")


func _signature(view: RunRouteAtlas) -> Array:
	var result: Array = []
	for child in view.get_children():
		if child is PanelContainer:
			var marker: PanelContainer = child
			var style: StyleBoxFlat = marker.get_theme_stylebox("panel") as StyleBoxFlat
			var token := marker.get_node_or_null("Art") as RunRouteAtlas.NodeToken
			result.append(["node", marker.get_meta("route_id"), marker.get_meta("route_kind"),
				marker.get_meta("route_state"), marker.position, marker.size, style.bg_color,
				style.border_color, (marker.get_node("Identity") as Label).text,
				"" if token == null else token.token_kind,
				"" if token == null else str(token.get_meta("art_path"))])
		elif child is Line2D:
			var thread: Line2D = child
			result.append(["edge", thread.get_meta("from_id"), thread.get_meta("to_id"),
				thread.get_meta("route_state"), thread.points, thread.default_color])
		elif child is Label:
			if child.has_meta("area_name"):
				result.append(["area", str(child.get_meta("area_name")), (child as Label).text,
					(child as Label).position, (child as Label).size])
			else:
				result.append(["floor", child.get_meta("floor_number"), (child as Label).text,
					(child as Label).position])
		elif child is RunRouteAtlas.CurrentPin:
			result.append(["pin", child.get_meta("pin_node_id"), child.position, child.size])
	return result


func _crossing_present(view: RunRouteAtlas, map: RunMap, label: String) -> void:
	var floors: Array = map.get_floors()
	if floors.size() < 2 or floors[0].size() < 2 or floors[1].size() < 2:
		_check(false, label + ": map has crossing preconditions")
		return
	var first_id: String = floors[0][0]["id"]
	var second_id: String = floors[0][1]["id"]
	var upper_target: String = floors[1][0]["id"]
	var lower_target: String = floors[1][1]["id"]
	_check(floors[0][0]["outgoing"].has(lower_target) and floors[0][1]["outgoing"].has(upper_target),
		label + ": crossing is present in authoritative map")
	var down: Line2D = null
	var up: Line2D = null
	for child in view.get_children():
		if child is Line2D:
			if child.get_meta("from_id") == first_id and child.get_meta("to_id") == lower_target:
				down = child
			if child.get_meta("from_id") == second_id and child.get_meta("to_id") == upper_target:
				up = child
	_check(down != null and up != null, label + ": both crossing directed links are actually rendered")
	if down != null and up != null:
		_check(down.points[0].y < up.points[0].y and down.points[12].y > up.points[12].y,
			label + ": actual link coordinates geometrically cross")


func _record_request(id: String) -> void:
	requests.append(id)


## Both backdrop paths must work for the mounted open book: owner art or drawing.
func _exercise_board_art(view: RunRouteAtlas, map: RunMap, rng: RandomNumberGenerator,
		label: String) -> void:
	var before := _state(map, rng)
	var drawn_signature := _signature(view)
	var stored_path := view.board_texture_path
	_check(RunRouteAtlas.MAP_BOARD_PATH == "res://assets/paper/backgrounds/map_board.png",
		label + ": owner board art path is the paper backdrop folder")
	_check(RunRouteAtlas.load_board_texture("res://assets/paper/backgrounds/missing_map_board.png") == null
		and RunRouteAtlas.load_board_texture("") == null,
		label + ": a missing or blank owner board image is not an error")
	# Drawn fallback: force the missing-art path even when the owner image exists.
	view.board_texture_path = "res://assets/paper/backgrounds/missing_map_board.png"
	view.board_texture_override = null
	view.refresh()
	_check(not view.uses_board_texture() and view.board_texture() == null
		and not view.drawn_book_geometry().is_empty(),
		label + ": missing art keeps the complete drawn fallback")
	_verify_book(view, label + " drawn fallback")
	_verify_area_labels(view, label + " drawn fallback")
	_check(_signature(view) == drawn_signature and _state(map, rng) == before,
		label + ": the drawn book leaves nodes, route and RNG alone")
	# Owner art path: the real image when it exists, else the same in-memory image.
	var art := RunRouteAtlas.load_board_texture(RunRouteAtlas.MAP_BOARD_PATH)
	if art == null:
		var image := Image.create(64, 36, false, Image.FORMAT_RGBA8)
		image.fill(Color("#e8dcb6"))
		art = ImageTexture.create_from_image(image)
	view.board_texture_override = art
	view.board_texture_path = RunRouteAtlas.MAP_BOARD_PATH
	view.refresh()
	_check(view.uses_board_texture() and view.board_texture() == art
		and view.drawn_book_geometry().is_empty(),
		label + ": an owner board image replaces the drawing in the same preview")
	_verify_book(view, label + " owner art")
	_verify_area_labels(view, label + " owner art")
	_check(view.board_texture_rect() == Rect2(Vector2.ZERO, view.size),
		label + ": mounted owner board covers the whole map preview")
	_check(_signature(view) == drawn_signature and _state(map, rng) == before,
		label + ": the board image only changes the backdrop, not nodes or route")
	view.board_texture_override = null
	view.board_texture_path = stored_path
	view.refresh()
	_check(_signature(view) == drawn_signature and _state(map, rng) == before,
		label + ": restoring the configured board leaves nodes, route and RNG alone")


func _action(view: RunRouteAtlas, id: String) -> Button:
	for child in view.get_children():
		if child is PanelContainer and child.get_meta("route_id") == id:
			return child.get_node_or_null("Action") as Button
	return null


func _click_action(action: Button) -> void:
	_check(action != null and action.is_visible_in_tree(), "mouse target is a mounted actionable button")
	if action == null or not action.is_visible_in_tree():
		return
	var point := action.get_global_rect().get_center()
	_check(root.get_visible_rect().has_point(point), "click point lies within viewport")
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _key_action(action: Button, code: Key) -> void:
	_check(action != null and action.is_visible_in_tree(), "keyboard target is a mounted actionable button")
	if action == null or not action.is_visible_in_tree():
		return
	action.grab_focus()
	_check(action.has_focus(), "real legal marker receives focus")
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _exercise_requests(view: RunRouteAtlas, map: RunMap, rng: RandomNumberGenerator,
		label: String) -> void:
	var legal := map.get_legal_choices()
	_check(not legal.is_empty(), label + ": real legal choices before input")
	if legal.is_empty():
		return
	var before := _state(map, rng)
	seed(87001)
	var expected_global := randi()
	seed(87001)
	for id in legal:
		var action := _action(view, id)
		_check(action != null, label + ": expected mounted action " + id)
		if action == null:
			continue
		for mode in ["mouse", "enter", "space"]:
			requests.clear()
			if mode == "mouse":
				await _click_action(action)
			else:
				await _key_action(action, KEY_ENTER if mode == "enter" else KEY_SPACE)
			_check(requests == [id], label + ": " + mode + " emits exactly canonical " + id)
			_check(_state(map, rng) == before, label + ": " + mode + " never changes route/RNG")
	_check(randi() == expected_global, label + ": all inputs avoid global RNG")
	requests.clear()


# ---------------------------------------------------------------------------
# Progressive reveal of newly legal stitches (presentation only).
# ---------------------------------------------------------------------------

func _ordered_legal(map: RunMap) -> Array[String]:
	var result: Array[String] = []
	var legal := map.get_legal_choices()
	for floor_nodes in map.get_floors():
		var by_position: Array = floor_nodes.duplicate()
		by_position.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["position"]) < int(b["position"]))
		for node in by_position:
			var id: String = node["id"]
			if legal.has(id) and not map.get_route().has(id):
				result.append(id)
	return result


## Directed edges the authoritative map paints as visited-to-legal, sorted canonically.
func _legal_edge_keys(map: RunMap) -> Array[String]:
	var keys: Array[String] = []
	var route := map.get_route()
	var legal := map.get_legal_choices()
	for floor_nodes in map.get_floors():
		for node in floor_nodes:
			var source: String = node["id"]
			if not route.has(source):
				continue
			for target in node["outgoing"]:
				if legal.has(target):
					keys.append(source + "->" + str(target))
	keys.sort()
	return keys


func _line_for(view: RunRouteAtlas, key: String) -> Line2D:
	for child in view.get_children():
		if child is Line2D \
				and str(child.get_meta("from_id")) + "->" + str(child.get_meta("to_id")) == key:
			return child as Line2D
	return null


func _no_masks(view: RunRouteAtlas) -> bool:
	return _mask_count(view) == 0


func _mask_count(view: RunRouteAtlas) -> int:
	var count := 0
	for child in view.get_children():
		if child is Line2D and child.gradient != null:
			count += 1
	return count


## Offset of the sewing front: the first sampled position the mask leaves transparent.
func _reveal_front(mask: Gradient) -> float:
	if mask == null:
		return 1.0
	for step in range(1, 101):
		var offset := float(step) / 100.0
		if mask.sample(offset).a < 0.5:
			return offset
	return 1.0


## Behind the front the installed gradient is the only colour Godot draws, because setting
## Line2D.gradient replaces default_color. Those pixels must be the legal thread, not white,
## and everything ahead of the moving front must still be transparent.
func _verify_reveal_colour(line: Line2D, label: String) -> void:
	var key := "unknown"
	if line != null and line.has_meta("from_id") and line.has_meta("to_id"):
		key = str(line.get_meta("from_id")) + "->" + str(line.get_meta("to_id"))
	var mask: Gradient = line.gradient if line != null else null
	_check(mask != null, label + ": sewing stitch still carries its reveal mask: " + key)
	if mask == null:
		return
	var front := _reveal_front(mask)
	var sewn := mask.sample(clampf(front - 0.01, 0.0, 1.0))
	var unsewn := mask.sample(clampf(front + 0.01, 0.0, 1.0))
	var transparent_legal := Color(RunRouteAtlas.LEGAL_THREAD.r, RunRouteAtlas.LEGAL_THREAD.g,
		RunRouteAtlas.LEGAL_THREAD.b, 0.0)
	_check(sewn.is_equal_approx(RunRouteAtlas.LEGAL_THREAD)
		and is_equal_approx(sewn.a, RunRouteAtlas.LEGAL_THREAD.a)
		and not (is_equal_approx(sewn.r, 1.0) and is_equal_approx(sewn.g, 1.0)
			and is_equal_approx(sewn.b, 1.0)),
		label + ": sewn pixels behind the front sample the legal thread colour: " + key)
	_check(unsewn.is_equal_approx(transparent_legal) and is_zero_approx(unsewn.a),
		label + ": pixels ahead of the front stay transparent: " + key)


## Select one real legal node, then confirm only its newly legal stitches are masking.
func _reveal_step(view: RunRouteAtlas, map: RunMap, rng: RandomNumberGenerator,
		label: String) -> Array[String]:
	var legal := map.get_legal_choices()
	_check(not legal.is_empty(), label + ": real legal node before the step")
	if legal.is_empty():
		return []
	var before := _state(map, rng)
	_check(map.choose_node(legal[0]), label + ": real node selected")
	_check(_state(map, rng)["rng"] == before["rng"], label + ": progression spends no run RNG")
	view.refresh()
	var expected := _legal_edge_keys(map)
	_check(not expected.is_empty(), label + ": selected node exposes visited-to-legal stitches")
	_check(view.revealing_edges() == expected, label + ": exactly the new legal stitches reveal")
	var masked := 0
	for child in view.get_children():
		if not (child is Line2D):
			continue
		var line: Line2D = child
		if line.gradient == null:
			continue
		masked += 1
		var key := str(line.get_meta("from_id")) + "->" + str(line.get_meta("to_id"))
		_check(expected.has(key) and line.default_color == RunRouteAtlas.LEGAL_THREAD
			and line.points.size() == 16,
			label + ": masked thread is a new legal stitch on its canonical path: " + key)
		_verify_reveal_colour(line, label)
	_check(masked == expected.size(), label + ": every and only new legal stitch carries a mask")
	_check(_state(map, rng)["rng"] == before["rng"], label + ": refresh during a reveal spends no run RNG")
	return expected


## Real seeded selected nodes must sew their new legal stitches in, then settle.
func _exercise_reveal(seed_value: int) -> void:
	var rng := _rng(seed_value)
	var map := RunMap.new()
	_check(map.generate(rng), "reveal fixture generated from a real seed")
	var view := RunRouteAtlas.new()
	view.position = Vector2(20, 40)
	root.add_child(view)
	view.node_requested.connect(_record_request)
	await process_frame
	requests.clear()
	seed(99013)
	var expected_global := randi()
	seed(99013)
	var opening := _state(map, rng)
	view.bind_map(map)
	_check(not view.is_revealing() and view.revealing_edges().is_empty() and _no_masks(view),
		"opening snapshot has no visited-to-legal stitch to reveal")
	_check(view.reveal_duration() == RunRouteAtlas.REVEAL_DURATION
		and is_equal_approx(RunRouteAtlas.REVEAL_DURATION, 0.6)
		and is_equal_approx(RunRouteAtlas.REVEAL_FAST_DURATION, 0.15),
		"normal reveal is bounded to 0.6 s and fast mode to 0.15 s")
	_check(_state(map, rng) == opening, "binding an unvisited map starts no reveal or model change")
	_verify(view, map, rng, "reveal opening seed %d" % seed_value)

	# Normal presentation: the first real selected node exposes new legal stitches.
	view.set_reveal_fast(false)
	var first_keys := await _reveal_step(view, map, rng, "seed %d slow reveal" % seed_value)
	_check(first_keys.size() >= 2, "selected node exposes several legal stitches")
	var probe: Line2D = _line_for(view, first_keys[0]) if not first_keys.is_empty() else null
	_check(probe != null and probe.gradient != null
		and probe.get_meta("route_state") == "legal"
		and probe.default_color == RunRouteAtlas.LEGAL_THREAD and probe.points.size() == 16,
		"newly legal stitch keeps canonical state, colour and path under its mask")
	var mask: Gradient = null
	if probe != null:
		mask = probe.gradient
	_check(_reveal_front(mask) <= 0.02, "stitch starts hidden at its source end")
	# Exact graph, geometry and colour checks while the reveal is still animating.
	_verify(view, map, rng, "seed %d mid reveal" % seed_value)
	await create_timer(0.15).timeout
	_check(view.is_revealing(), "stitch is still sewing shortly after progression")
	var first_front := _reveal_front(mask)
	_check(first_front > 0.05 and first_front < 0.95,
		"stitch partially reveals from its source end")
	_check(probe != null and probe.default_color == RunRouteAtlas.LEGAL_THREAD
		and probe.points.size() == 16,
		"partial reveal leaves the canonical colour and geometry alone")
	_verify_reveal_colour(probe, "seed %d mid reveal" % seed_value)
	await create_timer(0.1).timeout
	_check(probe != null and probe.gradient != null
		and _reveal_front(probe.gradient) > first_front,
		"sewing front advances further along the same thread")
	_verify_reveal_colour(probe, "seed %d advanced reveal" % seed_value)
	await create_timer(0.45).timeout
	_check(not view.is_revealing() and _no_masks(view),
		"reveal settles within 0.6 s and drops every temporary mask")
	for key in first_keys:
		var line: Line2D = _line_for(view, key)
		_check(line != null and line.gradient == null
			and line.default_color == RunRouteAtlas.LEGAL_THREAD and line.points.size() == 16,
			"settled stitch keeps its full authoritative colour: " + key)
	_verify(view, map, rng, "seed %d revealed floor" % seed_value)
	# Repeated viewing of an unchanged snapshot never replays the reveal.
	var settled_floors := map.get_floors()
	view.refresh()
	_check(not view.is_revealing() and _no_masks(view),
		"repeated refresh does not replay a settled reveal")
	view.refresh()
	_check(not view.is_revealing() and _no_masks(view)
		and map.get_floors() == settled_floors,
		"second repeat refresh stays inert and leaves the canonical graph alone")

	# Inputs must never wait for the reveal.
	var second_keys := await _reveal_step(view, map, rng, "seed %d input reveal" % seed_value)
	_check(view.is_revealing() and not second_keys.is_empty(),
		"input probe runs on an actively revealing atlas")
	var ordered := _ordered_legal(map)
	var key_down := InputEventKey.new()
	key_down.keycode = KEY_1
	key_down.pressed = true
	root.push_input(key_down, true)
	_check(not ordered.is_empty() and requests == [ordered[0]],
		"numeric shortcut emits its request synchronously during a reveal")
	_check(view.is_revealing(), "a running reveal never delays a keyboard request")
	var key_up := InputEventKey.new()
	key_up.keycode = KEY_1
	key_up.pressed = false
	root.push_input(key_up, true)
	requests.clear()
	var before_click := _state(map, rng)
	var action: Button = _action(view, ordered[0]) if not ordered.is_empty() else null
	_check(action != null, "input probe action is really mounted")
	if action != null:
		await _click_action(action)
		_check(requests == [ordered[0]], "mouse request is admitted during a reveal")
		_check(view.is_revealing(), "a running reveal never delays a mouse request")
	_check(_state(map, rng) == before_click, "inputs during a reveal spend no map or RNG state")
	requests.clear()

	# Teardown and rebind must release the tween and masks before children go.
	view.bind_map(null)
	_check(not view.is_revealing() and view.get_child_count() == 0,
		"null bind mid-reveal releases tween and masks with its threads")
	await process_frame
	await process_frame
	_check(view.get_child_count() == 0 and not view.is_revealing(),
		"no orphan tween or mask resurrects after a null bind")
	view.bind_map(map)
	var rebind_keys := _legal_edge_keys(map)
	_check(view.revealing_edges() == rebind_keys,
		"rebind re-arms exactly the visited-to-legal stitches, without duplicates")
	_verify(view, map, rng, "seed %d rebind reveal" % seed_value)
	var other_rng := _rng(seed_value + 1)
	var other := RunMap.new()
	_check(other.generate(other_rng), "replacement map fixture generated")
	view.bind_map(other)
	_check(not view.is_revealing() and _no_masks(view),
		"replacement bind mid-reveal tears the old mask down")
	_verify(view, other, other_rng, "seed %d replacement bind" % seed_value)

	# Fast presentation: the same reveal in 0.15 s.
	view.bind_map(map)
	_check(view.is_revealing(), "progressed map re-arms a reveal on rebind")
	view.set_reveal_fast(true)
	var fast_keys := await _reveal_step(view, map, rng, "seed %d fast reveal" % seed_value)
	_check(view.reveal_duration() == RunRouteAtlas.REVEAL_FAST_DURATION
		and is_equal_approx(RunRouteAtlas.REVEAL_FAST_DURATION, 0.15),
		"fast presentation switch shortens the reveal to 0.15 s")
	_check(not fast_keys.is_empty() and view.revealing_edges() == fast_keys,
		"fast mode reveals each new legal stitch")
	for key in fast_keys:
		_verify_reveal_colour(_line_for(view, key), "seed %d fast reveal" % seed_value)
	await create_timer(0.2).timeout
	_check(not view.is_revealing() and _no_masks(view),
		"fast reveal settles within 0.15 s")
	for key in fast_keys:
		var line: Line2D = _line_for(view, key)
		_check(line != null and line.gradient == null
			and line.default_color == RunRouteAtlas.LEGAL_THREAD and line.points.size() == 16,
			"fast settled stitch keeps its authoritative colour: " + key)
	_verify(view, map, rng, "seed %d fast revealed floor" % seed_value)
	view.set_reveal_fast(false)
	_check(view.reveal_duration() == RunRouteAtlas.REVEAL_DURATION,
		"normal reveal duration is restored")

	# The live overlay binds its map before mounting the view, so a queued reveal
	# must start on the first mounted frame instead of being dropped.
	var queued_rng := _rng(seed_value + 2)
	var queued_map := RunMap.new()
	_check(queued_map.generate(queued_rng), "queued-reveal fixture generated")
	var queued_id: String = queued_map.get_legal_choices()[0]
	_check(queued_map.choose_node(queued_id), "queued-reveal fixture has one visited node")
	var queued_view := RunRouteAtlas.new()
	queued_view.position = Vector2(20, 40)
	queued_view.bind_map(queued_map)
	_check(not queued_view.is_inside_tree() and queued_view.is_revealing()
		and _mask_count(queued_view) == _legal_edge_keys(queued_map).size()
		and _mask_count(queued_view) > 0,
		"binding before mounting queues the reveal like the live overlay does")
	root.add_child(queued_view)
	_check(queued_view.is_revealing(), "queued reveal is retained once the view is mounted")
	await create_timer(0.15).timeout
	_check(queued_view.is_revealing() and not _no_masks(queued_view),
		"queued reveal sews in on the mounted view")
	await create_timer(0.5).timeout
	_check(not queued_view.is_revealing() and _no_masks(queued_view),
		"queued reveal settles within 0.6 s")
	_verify(queued_view, queued_map, queued_rng, "seed %d queued reveal" % seed_value)
	queued_view.queue_free()
	await process_frame

	# A completed run map is inert: no legal stitch exists to reveal.
	var done_rng := _rng(seed_value)
	var done := RunMap.new()
	_check(done.generate(done_rng), "completed-map fixture generated")
	for step in range(12):
		var choices := done.get_legal_choices()
		if choices.is_empty() or not done.choose_node(choices[0]):
			break
	_check(done.is_complete() and done.get_legal_choices().is_empty(), "fixture reaches the boss")
	view.bind_map(done)
	_check(not view.is_revealing() and _no_masks(view),
		"completed maps stay inert with no reveal or mask")
	_verify(view, done, done_rng, "seed %d completed reveal" % seed_value)
	_check(rng.state == opening["rng"], "the whole reveal sequence spends no run RNG")
	_check(randi() == expected_global, "progressive reveals never consume the global RNG")
	view.bind_map(null)
	_check(not view.is_revealing() and view.get_child_count() == 0,
		"final null bind leaves the reveal machinery empty")
	view.queue_free()
	await process_frame


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var first := RunRouteAtlas.new()
	first.position = Vector2(20, 40)
	root.add_child(first)
	first.node_requested.connect(_record_request)
	await process_frame
	_check(first.is_inside_tree(), "read-only Control actually mounted in window")

	var empty := RunMap.new()
	first.bind_map(empty)
	_check(first.get_child_count() == 0, "ungenerated map displays no invented markers")
	first.bind_map(null)
	_check(first.get_child_count() == 0, "null map is empty and inert")
	# Token mapping, optional loading/caching and both marker branches, on the mounted view.
	_verify_token_sources(first, "token sources")

	for seed_value in [6, 42]:
		var rng := _rng(seed_value)
		var replay_rng := _rng(seed_value)
		var map := RunMap.new()
		var replay := RunMap.new()
		_check(map.generate(rng) and replay.generate(replay_rng), "both real maps generated for seed %d" % seed_value)
		var other := RunRouteAtlas.new()
		other.position = Vector2(20, 40)
		root.add_child(other)
		await process_frame
		# Guard the same global RNG stream that a bad view could accidentally consume.
		seed(10121 + seed_value)
		var expected_global := randi()
		seed(10121 + seed_value)
		var before := _state(map, rng)
		first.bind_map(map)
		other.bind_map(replay)
		_verify(first, map, rng, "opening seed %d" % seed_value)
		_verify(other, replay, replay_rng, "opening replay seed %d" % seed_value)
		_crossing_present(first, map, "seed %d crossing" % seed_value)
		if seed_value == 6:
			_exercise_board_art(first, map, rng, "seed %d board" % seed_value)
		_check(_state(map, rng) == before and rng.state == replay_rng.state
			and _signature(first) == _signature(other),
			"identical seed renders byte-for-byte comparable children and never alters graph/route/RNG")
		_check(randi() == expected_global, "atlas does not consume global RNG for seed %d" % seed_value)
		other.hide()
		await _exercise_requests(first, map, rng, "seed %d opening" % seed_value)
		var original_signature := _signature(first)
		var read_graph := map.get_floors()
		var original_floors := map.get_floors()
		read_graph[0][0]["type"] = "Forged"
		read_graph[0][0]["outgoing"].clear()
		read_graph.clear()
		var read_node := map.get_node(original_floors[0][0]["id"])
		read_node["type"] = "Forged"
		read_node["outgoing"].clear()
		var read_choices := map.get_legal_choices()
		read_choices.clear()
		read_choices.append("forged")
		_check(map.get_floors() == original_floors and _signature(first) == original_signature,
			"external graph/node/legal snapshots cannot mutate map or already-rendered atlas")
		for repeat in range(3):
			var old := _state(map, rng)
			first.refresh()
			_check(_signature(first) == original_signature and _state(map, rng) == old,
				"repeated refresh keeps same view, map and supplied RNG")
			_verify(first, map, rng, "repeat opening seed %d" % seed_value)

		var first_floor: Array = map.get_floors()[0]
		_check(not first_floor.is_empty() and map.get_legal_choices().size() == first_floor.size(),
			"real initial choices match complete opening floor")
		var before_bad := _state(map, rng)
		_check(not map.choose_node(map.get_floors()[2][0]["id"]) and not map.choose_node("unknown"),
			"real RunMap rejects floor skip and unknown node")
		_check(_state(map, rng) == before_bad, "bad opening never changes map or RNG")
		first.refresh()
		_verify(first, map, rng, "rejected opening seed %d" % seed_value)

		var old_action := _action(first, map.get_legal_choices()[0])
		_check(old_action != null, "old legal callback exists before advancing")
		var stale: Callable = old_action.pressed.get_connections()[0].callable if old_action != null else Callable()
		for floor_number in range(1, 13):
			var legal := map.get_legal_choices()
			var replay_legal := replay.get_legal_choices()
			_check(not legal.is_empty() and legal == replay_legal,
				"both maps offer identical legal path on floor %d" % floor_number)
			if legal.is_empty():
				break
			var chosen: String = legal[0]
			var previous := _state(map, rng)
			_check(map.choose_node(chosen) and replay.choose_node(chosen),
				"real legal step committed on floor %d" % floor_number)
			if stale.is_valid():
				requests.clear()
				stale.call()
				_check(requests.is_empty(), "external progression blocks prior marker callback")
			_check(map.get_route().size() == floor_number
				and map.get_current_node_id() == chosen and rng.state == previous["rng"],
				"only RunMap legal choice advances floor and spends no RNG")
			first.refresh()
			other.refresh()
			_verify(first, map, rng, "seed %d floor %d" % [seed_value, floor_number])
			_check(_action(first, chosen) == null, "selected node loses action after progression")
			if floor_number < 12 and floor_number in [1, 6]:
				await _exercise_requests(first, map, rng, "seed %d floor %d" % [seed_value, floor_number])
			_check(_signature(first) == _signature(other) and _state(map, rng) == _state(replay, replay_rng),
				"same seeded replay produces identical nodes, threads, highlights, graph and RNG")
			var route_copy := map.get_route()
			route_copy.clear()
			route_copy.append("forged")
			var legal_copy := map.get_legal_choices()
			legal_copy.clear()
			legal_copy.append("forged")
			if stale.is_valid():
				requests.clear()
				stale.call()
				_check(requests.is_empty(), "external progression blocks prior marker callback")
			_check(map.get_route().size() == floor_number
				and not map.get_route().has("forged") and not map.get_legal_choices().has("forged"),
				"route/legal defensive snapshots isolated after every move")
			var before_invalid := _state(map, rng)
			_check(not map.choose_node(chosen) and not map.choose_node("unrecognized"),
				"repeat and unknown route choices rejected on floor %d" % floor_number)
			_check(_state(map, rng) == before_invalid, "rejected move is exactly inert")
			first.refresh()
			_check(_state(map, rng) == before_invalid and _signature(first) == _signature(other),
				"rejection/refresh cannot alter chosen and legal presentation")
		_check(map.is_complete() and map.get_route().size() == 12
			and map.get_legal_choices().is_empty(), "Boss floor 12 complete, no next highlight")
		var end_state := _state(map, rng)
		_check(not map.choose_node(map.get_route().back()) and _state(map, rng) == end_state,
			"completed map rejects replay and leaves RNG intact")
		first.refresh()
		_verify(first, map, rng, "seed %d completed" % seed_value)

		# Pointer/keyboard events are dispatched to the mounted view. It must stay inert.
		var pointer := InputEventMouseButton.new()
		pointer.position = first.position + Vector2(60, 170)
		pointer.button_index = MOUSE_BUTTON_LEFT
		pointer.pressed = true
		Input.parse_input_event(pointer)
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = true
		Input.parse_input_event(key)
		await process_frame
		_check(_state(map, rng) == end_state and requests.is_empty() and not first.has_focus(),
			"finished map mouse/keyboard is inert and has no node buttons")
		first.bind_map(replay)
		requests.clear()
		if stale.is_valid():
			stale.call()
		_check(requests.is_empty(), "old callback rejects rebind")
		_verify(first, replay, replay_rng, "second map rebound")
		var replay_trace := _signature(other)
		_check(_signature(first) == replay_trace, "new map rebind has only its own node/edge state")
		first.bind_map(null)
		requests.clear()
		if stale.is_valid():
			stale.call()
		_check(requests.is_empty(), "old callback rejects null binding")
		_check(first.get_child_count() == 0 and _state(map, rng) == end_state,
			"null rebind immediately clears children, does not change former map")
		first.refresh()
		_check(first.get_child_count() == 0, "null repeat refresh never resurrects stale graph")
		first.bind_map(map)
		_check(_signature(first) == replay_trace, "rebind after clear restores exact owned graph")
		other.queue_free()
		await process_frame
		first.bind_map(null)

	# Distinct second-map graph replacement before any route is selected.
	var a := RunMap.new()
	var b := RunMap.new()
	var a_rng := _rng(6)
	var b_rng := _rng(42)
	_check(a.generate(a_rng) and b.generate(b_rng), "two distinct seeds exist for rebind")
	first.bind_map(a)
	var a_signature := _signature(first)
	first.bind_map(b)
	_verify(first, b, b_rng, "second seed replaces all original markers/threads")
	var b_signature := _signature(first)
	_check(a.get_floors() != b.get_floors() and a_signature != b_signature,
		"second graph has distinct real kind/edge content, stale first graph absent")
	first.bind_map(a)
	_check(_signature(first) == a_signature, "same first map is restorable without duplicates")
	var old_button := _action(first, a.get_legal_choices()[0])
	_check(old_button != null, "regeneration fixture has mounted legal button")
	var old_callback: Callable = old_button.pressed.get_connections()[0].callable if old_button != null else Callable()
	var prior_generation := a.get_generation_revision()
	var prior_state := _state(a, a_rng)
	requests.clear()
	first._request_node("unknown", a, first._revision)
	first._request_node(a.get_floors()[3][0]["id"], a, first._revision)
	_check(requests.is_empty() and _state(a, a_rng) == prior_state,
		"unknown and nonlegal direct request callbacks reject without RNG use")
	var identical_rng := _rng(6)
	_check(a.generate(identical_rng) and a.get_floors() == prior_state.floors
		and a.get_generation_revision() == prior_generation + 1,
		"same seed regeneration recreates identical atlas data with fresh generation identity")
	var regenerated := _state(a, identical_rng)
	if old_callback.is_valid():
		old_callback.call()
	_check(requests.is_empty() and _state(a, identical_rng) == regenerated,
		"old callback rejects same-seed regeneration even when IDs and route are unchanged")
	first.refresh()
	_verify(first, a, identical_rng, "same-seed regenerated view")
	if old_callback.is_valid():
		old_callback.call()
	_check(requests.is_empty(), "refresh invalidates all prior generation callbacks")
	first.bind_map(b)
	if old_callback.is_valid():
		old_callback.call()
	_check(requests.is_empty(), "rebind rejects retained callback from old map")
	first.bind_map(null)
	if old_callback.is_valid():
		old_callback.call()
	first._request_node("f01_n0", null, first._revision)
	_check(requests.is_empty() and first.get_child_count() == 0,
		"last null rejects stale and null callbacks, clears edges, headers and markers")
	# Progressive reveal of newly legal stitches on a real seeded route.
	await _exercise_reveal(6)
	first.queue_free()
	await process_frame
	if failures.is_empty():
		print("run_route_atlas_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_route_atlas_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
