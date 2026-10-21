extends SceneTree

var failures: Array[String] = []
var checks := 0
var requests: Array[String] = []
const NUMBER_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _on_requested(id: String) -> void:
	requests.append(id)


func _rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _state(map: RunMap, rng: RandomNumberGenerator) -> Dictionary:
	return {
		"floors": map.get_floors(),
		"route": map.get_route(),
		"legal": map.get_legal_choices(),
		"generation": map.get_generation_revision(),
		"current": map.get_current_node_id(),
		"floor": map.get_current_floor(),
		"complete": map.is_complete(),
		"rng": rng.state,
	}


func _ordered_legal(map: RunMap) -> Array[String]:
	var result: Array[String] = []
	var legal := map.get_legal_choices()
	for floor_nodes in map.get_floors():
		var by_position: Array = floor_nodes.duplicate()
		by_position.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["position"]) < int(b["position"]))
		for node in by_position:
			var id: String = node["id"]
			if legal.has(id):
				result.append(id)
	return result


func _marker(view: RunRouteAtlas, id: String) -> PanelContainer:
	for child in view.get_children():
		if child is PanelContainer and child.get_meta("route_id") == id:
			return child as PanelContainer
	return null


func _verify_labels(view: RunRouteAtlas, map: RunMap, rng: RandomNumberGenerator,
		where: String) -> Array[String]:
	var before := _state(map, rng)
	var ordered := _ordered_legal(map)
	_check(view.is_inside_tree() and view.is_visible_in_tree()
		and view.size == Vector2(1240, 600)
		and view.position + view.size <= Vector2(1280, 720),
		where + ": mounted visible atlas fully fits target viewport")
	_check(ordered.size() <= 4 and ordered == map.get_legal_choices() if map.get_current_floor() == 0 else ordered.size() <= 4,
		where + ": actual legal destinations fit numeric keys")
	var button_count := 0
	var captions: Array[String] = []
	for floor_nodes in map.get_floors():
		for node in floor_nodes:
			var id: String = node["id"]
			var marker := _marker(view, id)
			_check(marker != null, where + ": model marker exists " + id)
			if marker == null:
				continue
			var identity := marker.get_node_or_null("Identity") as Label
			var action := marker.get_node_or_null("Action") as Button
			var index := ordered.find(id)
			var expected_caption := (str(index + 1) + "\n" if index >= 0 else "") + String(node["type"]) + "\n" + id
			_check(identity != null and identity.text == expected_caption,
				where + ": exact numbered kind and canonical ID for " + id)
			if identity != null:
				captions.append(identity.text)
				_check(identity.get_combined_minimum_size().x <= marker.size.x
					and identity.get_combined_minimum_size().y <= marker.size.y,
					where + ": complete caption fits stitched marker " + id)
			_check(marker.get_meta("route_state") == ("legal" if index >= 0 else
				("chosen" if map.get_route().has(id) else "other")),
				where + ": state reflects selected/available/inaccessible " + id)
			if index >= 0:
				button_count += 1
				_check(action != null and action.focus_mode == Control.FOCUS_ALL
					and action.is_visible_in_tree(),
					where + ": numbered destination owns mounted keyboard/mouse button " + id)
			else:
				_check(action == null, where + ": no inactive numbered/actionable marker " + id)
	_check(button_count == ordered.size() and captions.size() >= 36,
		where + ": exactly N legal Action buttons across complete graph")
	_check(_state(map, rng) == before, where + ": display verification leaves graph, route and RNG intact")
	return ordered


# Deliver physical SceneTree events instead of invoking RunRouteAtlas._input directly.
# Return the press event's handled flag, before a release clears it.
func _key(code: Key, echo: bool = false) -> bool:
	var down := InputEventKey.new()
	down.keycode = code
	down.pressed = true
	down.echo = echo
	root.push_input(down, true)
	var handled := root.is_input_handled()
	await process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.pressed = false
	root.push_input(up, true)
	await process_frame
	return handled


func _assert_key(view: RunRouteAtlas, map: RunMap, rng: RandomNumberGenerator,
		code: Key, expected: String, where: String, echo: bool = false) -> void:
	_check(view.is_inside_tree(), where + ": tested view is mounted")
	var before := _state(map, rng)
	requests.clear()
	seed(77113)
	var global_next := randi()
	seed(77113)
	var handled := await _key(code, echo)
	_check(requests == ([expected] if not expected.is_empty() else []),
		where + ": exactly the expected node_requested signal, never duplicate")
	_check(handled == not expected.is_empty(),
		where + ": only admitted shortcuts claim keyboard input")
	_check(_state(map, rng) == before, where + ": key never chooses route or draws from model RNG")
	_check(randi() == global_next, where + ": key never draws from global RNG")


func _assert_held_key(map: RunMap, rng: RandomNumberGenerator, id: String) -> void:
	var before := _state(map, rng)
	requests.clear()
	var down := InputEventKey.new()
	down.keycode = KEY_1
	down.pressed = true
	root.push_input(down, true)
	await process_frame
	for repeat in range(3):
		var echo := InputEventKey.new()
		echo.keycode = KEY_1
		echo.pressed = true
		echo.echo = true
		root.push_input(echo, true)
		await process_frame
	var up := InputEventKey.new()
	up.keycode = KEY_1
	up.pressed = false
	root.push_input(up, true)
	await process_frame
	_check(requests == [id], "one held numeric key emits once despite three repeat events")
	_check(_state(map, rng) == before, "held key and repeats leave full run state intact")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var view := RunRouteAtlas.new()
	view.position = Vector2(20, 40)
	root.add_child(view)
	view.node_requested.connect(_on_requested)
	var other_focus := Button.new()
	other_focus.text = "Unrelated focus"
	other_focus.position = Vector2(0, 0)
	root.add_child(other_focus)
	await process_frame
	other_focus.grab_focus()
	_check(other_focus.has_focus() and not view.has_focus(),
		"initial numeric request works with focus on non-atlas Control")

	var ungenerated := RunMap.new()
	view.bind_map(ungenerated)
	_check(view.get_child_count() == 0, "ungenerated map has no markers")
	await _assert_key(view, ungenerated, _rng(1), KEY_1, "", "ungenerated key")
	view.bind_map(null)
	await _assert_key(view, ungenerated, _rng(1), KEY_1, "", "null map key")

	var saw_narrow := false
	for seed_value in [6, 42]:
		var rng := _rng(seed_value)
		var map := RunMap.new()
		_check(map.generate(rng), "real seeded map generated %d" % seed_value)
		view.bind_map(map)
		var first_legal := _verify_labels(view, map, rng, "seed %d opening" % seed_value)
		_check(first_legal.size() >= 3, "opening has three or four real choices")
		for i in range(first_legal.size()):
			await _assert_key(view, map, rng, NUMBER_KEYS[i], first_legal[i],
				"seed %d initial shortcut %d" % [seed_value, i + 1])
		if not first_legal.is_empty():
			await _assert_held_key(map, rng, first_legal[0])
		await _assert_key(view, map, rng, KEY_5, "", "unassigned key 5")
		await _assert_key(view, map, rng, KEY_1, "", "auto-repeat suppressed", true)
		if first_legal.size() < 4:
			saw_narrow = true
			await _assert_key(view, map, rng, KEY_4, "", "opening number 4 absent")

		var first_action := (_marker(view, first_legal[0]).get_node_or_null("Action") as Button) if not first_legal.is_empty() else null
		_check(first_action != null, "callback fixture is a real opening button")
		var stale: Callable = first_action.pressed.get_connections()[0].callable if first_action != null else Callable()
		view.hide()
		await process_frame
		await _assert_key(view, map, rng, KEY_1, "", "hidden mounted atlas")
		view.show()
		await process_frame
		await _assert_key(view, map, rng, KEY_1, first_legal[0], "reshown valid atlas")

		# An external legal move makes the displayed shortcut list stale.
		var previous := _state(map, rng)
		_check(map.choose_node(first_legal[0]), "external legal route move succeeds")
		var advanced := _state(map, rng)
		_check(advanced["route"].size() == previous["route"].size() + 1
			and advanced["rng"] == previous["rng"],
			"external move only advances authoritative route")
		await _assert_key(view, map, rng, KEY_1, "", "stale external route")
		requests.clear()
		if stale.is_valid():
			stale.call()
		_check(requests.is_empty() and _state(map, rng) == advanced,
			"retained marker callback rejects external move")

		view.refresh()
		var fresh := _verify_labels(view, map, rng, "seed %d advanced" % seed_value)
		_check(not fresh.is_empty(), "new floor exposes real outgoing destinations")
		if fresh.size() < 4:
			saw_narrow = true
			await _assert_key(view, map, rng, KEY_4, "", "connected narrow floor has no fourth shortcut")
		for i in range(fresh.size()):
			await _assert_key(view, map, rng, NUMBER_KEYS[i], fresh[i],
				"seed %d connected shortcut %d" % [seed_value, i + 1])

		# Same map and seed can recreate identical labels but MUST invalidate requests.
		var old_marker := _marker(view, fresh[0])
		var old_action := old_marker.get_node_or_null("Action") as Button if old_marker != null else null
		var old_cb: Callable = old_action.pressed.get_connections()[0].callable if old_action != null else Callable()
		var old_revision := map.get_generation_revision()
		var identical_rng := _rng(seed_value)
		_check(map.generate(identical_rng) and map.get_generation_revision() == old_revision + 1,
			"identical seed regenerates with distinct generation revision")
		var regenerated := _state(map, identical_rng)
		_check(regenerated["floors"] == previous["floors"], "same-seed graph replay is identical")
		await _assert_key(view, map, identical_rng, KEY_1, "", "unrefreshed regenerated atlas")
		requests.clear()
		if old_cb.is_valid():
			old_cb.call()
		_check(requests.is_empty() and _state(map, identical_rng) == regenerated,
			"stale button callback rejected across same-seed regeneration")
		view.refresh()
		var replay_legal := _verify_labels(view, map, identical_rng, "seed %d regenerated" % seed_value)
		await _assert_key(view, map, identical_rng, KEY_1, replay_legal[0],
			"refreshed same-seed map accepts new callback")
		requests.clear()
		if old_cb.is_valid():
			old_cb.call()
		_check(requests.is_empty(), "refresh invalidates retained old generation callback")

		# Follow a real route through the boss; no number keys remain at completion.
		for floor_number in range(1, 13):
			var legal := _ordered_legal(map)
			_check(not legal.is_empty(), "floor %d has reachable next node" % floor_number)
			if legal.is_empty():
				break
			var before_step := _state(map, identical_rng)
			_check(map.choose_node(legal[0]), "floor %d chooses only a legal model node" % floor_number)
			_check(identical_rng.state == before_step["rng"], "route advancement does not draw RNG")
			view.refresh()
			var now := _verify_labels(view, map, identical_rng,
				"seed %d after floor %d" % [seed_value, floor_number])
			if floor_number < 12:
				_check(not now.is_empty(), "upcoming floor has live shortcuts")
				if now.size() < 4:
					saw_narrow = true
					await _assert_key(view, map, identical_rng, KEY_4, "",
						"floor %d absent shortcut 4" % floor_number)
				await _assert_key(view, map, identical_rng, KEY_1, now[0],
					"floor %d newly refreshed shortcut" % floor_number)
			else:
				_check(map.is_complete() and now.is_empty(), "boss completion has zero legal shortcuts")
				await _assert_key(view, map, identical_rng, KEY_1, "", "completed atlas ignores 1")
				await _assert_key(view, map, identical_rng, KEY_4, "", "completed atlas ignores 4")

		var finished := _state(map, identical_rng)
		view.bind_map(null)
		await _assert_key(view, map, identical_rng, KEY_1, "", "null after completion")
		_check(_state(map, identical_rng) == finished, "null binding leaves former map unchanged")

	_check(saw_narrow, "at least one real connected state offers fewer than four destinations")
	view.queue_free()
	other_focus.queue_free()
	await process_frame
	if failures.is_empty():
		print("run_route_atlas_shortcuts_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_route_atlas_shortcuts_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
