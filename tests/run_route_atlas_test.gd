extends SceneTree

var failures: Array[String] = []
var checks := 0
var requests: Array[String] = []


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


func _inside(rect: Rect2, outer: Rect2) -> bool:
	return rect.position.x >= outer.position.x and rect.position.y >= outer.position.y \
		and rect.end.x <= outer.end.x and rect.end.y <= outer.end.y


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
	var first_marker_index := 999999
	var last_thread_index := -1
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
			else:
				_check(action == null and marker.mouse_filter == Control.MOUSE_FILTER_IGNORE,
					label + ": chosen/inaccessible node has no actionable button or focus " + id)
			var identity: Label = marker.get_node_or_null("Identity") as Label
			_check(identity != null, label + ": visible marker identity exists " + id)
			if identity != null and expected_nodes.has(id):
				var kind: String = expected_nodes[id]["type"]
				var expected_state := "chosen" if chosen.has(id) else ("legal" if legal.has(id) else "other")
				var number := ordered_legal.find(id) + 1
				var expected_caption := (str(number) + "\n" if expected_state == "legal" else "") + kind + "\n" + id
				var panel_style := marker.get_theme_stylebox("panel") as StyleBoxFlat
				_check(marker.get_meta("route_kind") == kind
					and identity.text == expected_caption
					and marker.get_meta("route_state") == expected_state,
					label + ": correct actual kind, ID and three-state highlights " + id)
				_check(panel_style != null and panel_style.bg_color == _expected_style(expected_state),
					label + ": highlight is visibly colored, not metadata-only " + id)
				_check(identity.mouse_filter == Control.MOUSE_FILTER_IGNORE
					and identity.focus_mode == Control.FOCUS_NONE
					and identity.get_theme_font_size("font_size") >= 12,
					label + ": inert legible label " + id)
				_check(identity.get_combined_minimum_size().x <= marker.size.x
					and identity.get_combined_minimum_size().y <= marker.size.y,
					label + ": full type and ID text fits patch " + id)
		elif child is Label:
			var header: Label = child
			_check(header.has_meta("floor_number"), label + ": only expected header labels")
			if header.has_meta("floor_number"):
				var floor_num: int = header.get_meta("floor_number")
				_check(floor_num >= 1 and floor_num <= 12 and not seen_floors.has(floor_num)
					and header.text == "%02d" % floor_num, label + ": floor number shown once")
				seen_floors[floor_num] = true
			_check(_inside(Rect2(header.position, header.size), bounding)
				and header.mouse_filter == Control.MOUSE_FILTER_IGNORE
				and header.focus_mode == Control.FOCUS_NONE,
				label + ": header within bounds and inert")
		else:
			_check(false, label + ": unexpected rendered child: " + child.name)

	_check(seen_nodes.size() == expected_nodes.size() and seen_nodes.size() >= 36,
		label + ": one actual marker per 3-4 node across twelve floors")
	_check(seen_edges.size() == expected_edges.size() and seen_edges.size() >= 36,
		label + ": exact number of directed edges")
	_check(seen_floors.size() == 12, label + ": all twelve columns headed")
	_check(last_thread_index < first_marker_index,
		label + ": every connection is behind every node")
	_check(view.get_child_count() == expected_nodes.size() + expected_edges.size() + 12,
		label + ": no orphan/duplicate children")
	for id in expected_nodes:
		_check(seen_nodes.has(id), label + ": missing actual node " + id)
	for key in expected_edges:
		_check(seen_edges.has(key), label + ": missing actual edge " + key)
	_check(_state(map, rng) == before, label + ": inspecting preview leaves map and RNG unchanged")


func _signature(view: RunRouteAtlas) -> Array:
	var result: Array = []
	for child in view.get_children():
		if child is PanelContainer:
			var marker: PanelContainer = child
			var style: StyleBoxFlat = marker.get_theme_stylebox("panel") as StyleBoxFlat
			result.append(["node", marker.get_meta("route_id"), marker.get_meta("route_kind"),
				marker.get_meta("route_state"), marker.position, marker.size, style.bg_color,
				(marker.get_node("Identity") as Label).text])
		elif child is Line2D:
			var thread: Line2D = child
			result.append(["edge", thread.get_meta("from_id"), thread.get_meta("to_id"),
				thread.get_meta("route_state"), thread.points, thread.default_color])
		elif child is Label:
			result.append(["floor", child.get_meta("floor_number"), (child as Label).text, (child as Label).position])
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
	first.queue_free()
	await process_frame
	if failures.is_empty():
		print("run_route_atlas_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_route_atlas_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)