extends "res://tests/stitched_s6_full_run_test.gd"
## S6 VIS-A: authenticated public route, service and terminal pages, not test-only UI.


func _page(app: Node, expected_kind: String, label: String) -> Control:
	var page: Control = app.stitched_run_panel
	_check(page != null and page.is_visible_in_tree(), label + " is mounted visibly")
	if page == null:
		return null
	_check(page.get_meta("page_kind", "") == expected_kind, label + " has its distinct scene mode")
	var image: TextureRect = page.find_child("StitchedSceneArt", true, false)
	_check(image != null and image.texture != null and image.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		label + " displays an authored image without stealing pointer input")
	var frame: NinePatchRect = page.find_child("StitchedFeltFrame", true, false)
	_check(frame != null and frame.texture != null, label + " uses an authored nine-slice felt frame")
	var ledger: Label = page.find_child("RunLedger", true, false)
	_check(ledger != null and "CANDLE" in ledger.text and "GOLD" in ledger.text
		and "SCRAPS" in ledger.text and "SATCHEL" in ledger.text,
		label + " displays every shared resource")
	var cards: Node = page.find_child("FourHeroRecaps", true, false)
	_check(cards != null and cards.get_child_count() == 4, label + " displays four actual doll cards")
	if cards != null:
		for hero in app.stitched_run_session.heroes:
			var recap: Label = cards.find_child("Recap_" + str(hero.id), true, false)
			_check(recap != null and "HP %d / %d" % [hero.hp, hero.max_hp] in recap.text
				and "FRAY %d / 200" % hero.fray in recap.text
				and ("LOST" in recap.text) == bool(hero.lost),
				label + " reads true HP, fray and loss for " + str(hero.id))
	return page


func _assert_actions(app: Node, count: int, label: String) -> void:
	_check(app.stitched_run_buttons.size() >= count and count > 0,
		label + " has non-vacuous public choices")
	for index in range(mini(count, app.stitched_run_buttons.size())):
		var button: Button = app.stitched_run_buttons[index]
		_check(button.is_visible_in_tree() and button.focus_mode == Control.FOCUS_ALL,
			label + " action is visible and focusable: " + str(index))
		_check(button.get_theme_stylebox("normal") is StyleBoxTexture,
			label + " uses image-backed button style: " + str(index))
		if not button.disabled:
			_check(not button.focus_next.is_empty(),
				label + " enabled choice participates in Tab navigation")


func _assert_book(app: Node, label: String) -> void:
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.phase == "map", label + " is a real map-phase session")
	if session == null or session.phase != "map":
		return
	var page := _page(app, "map", label)
	if page == null:
		return
	var book := page.find_child("StitchedRouteBookView", true, false) as StitchedRouteBookView
	_check(book != null and book.is_visible_in_tree(), label + " mounts the sewn two-page map")
	if book == null:
		return
	var route := session.map.get_route()
	var choices := session.choices()
	_check(book.visited_ids == route and book.legal_ids == choices
		and book.get_meta("visited_ids", []) == route
		and book.get_meta("legal_ids", []) == choices
		and book.get_meta("current_id", "invalid") == session.map.get_current_node_id(),
		label + " reads authoritative history, current position and connected IDs")
	_assert_graph(app, book, label)
	var here := book.find_child("CurrentSeam", true, false) as Label
	var current := session.map.get_node(session.map.get_current_node_id())
	_check(here != null and here.is_visible_in_tree()
		and (("AT THE FIRST SEAM" in here.text) if current.is_empty()
		else ("FLOOR %02d" % current.floor in here.text
			and current.type in here.text and "PATH %d" % (current.position + 1) in here.text)),
		label + " displays the actual reached position")
	var seams := book.find_child("VisitedSeams", true, false) as VBoxContainer
	var seam_scroll := book.find_child("VisitedSeamScroll", true, false) as ScrollContainer
	_check(seams != null and seam_scroll != null and seam_scroll.is_visible_in_tree(),
		label + " keeps the entire ordered diary in a native scroll")
	if seams != null:
		var rows: Array[Node] = []
		for child in seams.get_children():
			if child.name.begins_with("VisitedSeam_"):
				rows.append(child)
		_check(rows.size() == route.size(), label + " contains no fabricated or omitted completed stops")
		for index in mini(rows.size(), route.size()):
			var node := session.map.get_node(route[index])
			var row := rows[index]
			var labels := row.find_children("*", "Label", true, false)
			var icon := row.find_child("VisitedNodeIcon", true, false) as TextureRect
			_check(not row is BaseButton and row.get_meta("route_id", "") == route[index]
				and row.get_meta("node_kind", "") == node.type
				and row.get_meta("floor", 0) == node.floor
				and row.get_meta("path", 0) == node.position + 1
				and labels.size() == 1
				and "FLOOR %02d" % node.floor in labels[0].text
				and node.type in labels[0].text
				and "PATH %d" % (node.position + 1) in labels[0].text
				and icon != null and icon.texture != null,
				label + " seam %d is an image-backed, inert authentic record" % index)
		if route.is_empty():
			_check(rows.is_empty() and seams.get_child_count() == 1
				and "No stops sewn yet" in (seams.get_child(0) as Label).text,
				label + " presents an untraversed opening without invented history")
	var left := book.find_child("RouteOrVisitStory", true, false)
	var right := book.find_child("LegalChoices", true, false)
	var scroll := book.find_child("RunActionScroll", true, false) as ScrollContainer
	var decisions := book.find_child("PublicRouteDecisions", true, false) as VBoxContainer
	_check(left is PanelContainer and right is PanelContainer
		and scroll != null and decisions != null
		and scroll.is_visible_in_tree() and decisions.is_visible_in_tree(),
		label + " displays two authored felt pages and a scrolling right page")
	_check(choices.size() > 0 and app.stitched_run_buttons.size() == choices.size() + 2,
		label + " has exactly the legal tickets plus Save and Reload")
	if decisions == null:
		return
	for index in mini(choices.size(), app.stitched_run_buttons.size()):
		var node := session.map.get_node(choices[index])
		var button: Button = app.stitched_run_buttons[index]
		var icon := button.find_child("AuthoredNodeIcon", false, false) as TextureRect
		_check(button.get_parent() == decisions and not button.disabled
			and button.is_visible_in_tree() and button.focus_mode == Control.FOCUS_ALL
			and button.get_theme_stylebox("normal") is StyleBoxTexture
			and button.get_theme_stylebox("focus") is StyleBoxTexture
			and button.get_meta("route_id", "") == choices[index]
			and button.get_meta("node_kind", "") == node.type
			and button.get_meta("ticket_kind", "") == node.type
			and "FLOOR %02d" % node.floor in button.text
			and node.type in button.text
			and "PATH %d" % (node.position + 1) in button.text
			and icon != null and icon.texture != null,
			label + " legal ticket %d is truthful, image-backed and keyboard-focusable" % index)



func _assert_graph(app: Node, book: StitchedRouteBookView, label: String) -> void:
	var session: StitchedRunSession = app.stitched_run_session
	var graph: StitchedRouteGraphView = book.graph_view
	_check(graph != null and graph.get_parent() != null and graph.is_visible_in_tree(),
		label + " embeds the live, passive atlas on the left page")
	if graph == null:
		return
	var left := book.find_child("RouteOrVisitStory", true, false)
	var scroll := graph.find_child("RouteGraphScroll", true, false) as ScrollContainer
	var bands := graph.find_child("RouteGraphBands", true, false) as VBoxContainer
	var preview := graph.find_child("RouteGraphPreview", true, false) as Label
	var floors := session.map.get_floors()
	var route := session.map.get_route()
	var choices := session.choices()
	_check(graph.is_ancestor_of(scroll) and left.is_ancestor_of(graph)
		and scroll != null and bands != null and preview != null
		and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
		and graph.get_meta("floor_count") == floors.size() and floors.size() == 12,
		label + " nests all twelve authored bands in the left-page scroll")
	if bands == null or preview == null:
		return
	_check(bands.get_child_count() == floors.size()
		and graph.get_meta("visited_ids") == route and graph.get_meta("legal_ids") == choices
		and graph.get_meta("current_id") == session.map.get_current_node_id(),
		label + " projects actual visit/current/legal state without adding a node")
	var expected_legal: Array = floors[0].map(func(node: Dictionary): return str(node.id)) if route.is_empty() else session.map.get_node(route.back()).outgoing
	_check(choices == expected_legal and not choices.is_empty(),
		label + " shows only the session's genuine connected next-floor paths")
	var seen: Dictionary = {}
	var edge_count := 0
	for floor_index in floors.size():
		var floor_nodes: Array = floors[floor_index]
		var band := graph.find_child("GraphFloor_%02d" % (floor_index + 1), true, false) as VBoxContainer
		_check(band != null and band.get_meta("floor", -1) == floor_index + 1
			and band.get_meta("node_ids", []) == floor_nodes.map(func(node: Dictionary): return str(node.id)),
			label + " authored floor %02d has the exact generated nodes" % (floor_index + 1))
		if band == null:
			continue
		var row := band.find_child("GraphFloorPaths", false, false) as HBoxContainer
		_check(row != null and row.get_child_count() == floor_nodes.size()
			and floor_nodes.size() in [3, 4],
			label + " floor %02d retains every path in order" % (floor_index + 1))
		for record in floor_nodes:
			var id: String = record.id
			var tile := band.find_child("GraphNode_" + id, true, false) as VBoxContainer
			_check(tile != null and not seen.has(id),
				label + " displays unique genuine path " + id)
			if tile == null:
				continue
			seen[id] = true
			var expected_status := "current" if id == session.map.get_current_node_id() else (
				"visited" if route.has(id) else "legal" if choices.has(id) else "future")
			var art := tile.find_child("GraphNodeIcon", false, false) as TextureRect
			var kind := tile.find_child("GraphNodeKind", false, false) as Label
			var floor_label := tile.find_child("GraphNodeFloor", false, false) as Label
			var path_label := tile.find_child("GraphNodePath", false, false) as Label
			var state_label := tile.find_child("GraphNodeState", false, false) as Label
			_check(tile.get_meta("route_id") == id and tile.get_meta("node_kind") == record.type
				and tile.get_meta("floor") == record.floor
				and tile.get_meta("path") == record.position + 1
				and tile.get_meta("node_data") == record
				and tile.get_meta("outgoing") == record.outgoing
				and tile.get_meta("visited") == route.has(id)
				and tile.get_meta("current") == (id == session.map.get_current_node_id())
				and tile.get_meta("legal") == choices.has(id)
				and tile.get_meta("status") == expected_status
				and tile.focus_mode == Control.FOCUS_NONE
				and tile.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				label + " " + id + " has exact detached session truth and cannot admit")
			_check(art != null and art.texture != null and art.get_meta("art_path", "").begins_with("res://assets/paper/ui/map_node_")
				and kind != null and record.type.to_upper() in kind.text
				and floor_label != null and "FLOOR %02d" % record.floor in floor_label.text
				and path_label != null and "PATH %d" % (record.position + 1) in path_label.text
				and state_label != null and not state_label.text.is_empty(),
				label + " " + id + " has authored art and legible floor/kind/path/state")
			var edges := tile.find_child("GraphNodeEdges", false, false) as HFlowContainer
			_check(edges != null and edges.get_child_count() == record.outgoing.size(),
				label + " " + id + " has every real directed edge, including crossings")
			if edges != null:
				for edge_index in record.outgoing.size():
					var target: String = record.outgoing[edge_index]
					var edge := edges.get_child(edge_index) as Label
					_check(edge != null and edge.get_meta("source_id") == id
						and edge.get_meta("target_id") == target
						and edge.name == "GraphEdge_" + target
						and edge.mouse_filter == Control.MOUSE_FILTER_IGNORE,
						label + " " + id + " retains directed link to " + target)
					edge_count += 1
	_check(seen.size() == floors.reduce(func(count, floor: Array): return count + floor.size(), 0)
		and edge_count > seen.size(),
		label + " retains the entire branching/crossing graph, not a route ticket list")
	var inspected_id: String = graph.inspected_route_id
	var expected_preview: Array = [] if inspected_id.is_empty() else session.map.get_node(inspected_id).outgoing
	_check(preview.get_meta("preview_ids", []) == expected_preview
		and (inspected_id.is_empty() or choices.has(inspected_id)),
		label + " inspection previews only the selected legal node's outgoing links")


func _exercise_graph_inspection(app: Node, label: String) -> void:
	var session: StitchedRunSession = app.stitched_run_session
	var book := app.stitched_run_panel.find_child("StitchedRouteBookView", true, false) as StitchedRouteBookView
	_check(book != null and book.graph_view != null, label + " has a real atlas for focus testing")
	if book == null or book.graph_view == null:
		return
	var graph: StitchedRouteGraphView = book.graph_view
	await process_frame
	var left := book.find_child("RouteOrVisitStory", true, false) as Control
	var right := book.find_child("LegalChoices", true, false) as Control
	var graph_scroll := graph.find_child("RouteGraphScroll", true, false) as Control
	var hero_recaps := app.stitched_run_panel.find_child("FourHeroRecaps", true, false) as Control
	var navigation := app.stitched_run_panel.find_child("RunNavigation", true, false) as Control
	var l := left.get_global_rect()
	var r := right.get_global_rect()
	var g := graph_scroll.get_global_rect()
	_check(l.size.x > 0 and r.size.x > 0 and g.size.y >= 100
		and l.end.x <= r.position.x and g.position.x >= l.position.x
		and g.end.x <= l.end.x and g.end.y <= l.end.y
		and hero_recaps.get_global_rect().end.y <= l.position.y
		and navigation.get_global_rect().position.y >= l.end.y
		and navigation.get_global_rect().end.y <= 720
		and r.end.x <= 1280,
		label + " fits the branch scroll, tickets, four heroes, ledger and nav at 1280x720")
	var initial := session.snapshot()
	var choices := session.choices()
	_check(choices.size() > 0, label + " has at least one real choice to inspect")
	for index in choices.size():
		var id: String = choices[index]
		var button: Button = app.stitched_run_buttons[index]
		button.mouse_entered.emit()
		_check(graph.inspected_route_id == id
			and graph.find_child("GraphNode_" + id, true, false).get_meta("inspected")
			and graph.find_child("RouteGraphPreview", true, false).get_meta("preview_ids")
				== session.map.get_node(id).outgoing
			and session.snapshot() == initial,
			label + " mouse inspection matches " + id + " and draws no RNG")
		for other_id in choices:
			if other_id != id:
				_check(not graph.find_child("GraphNode_" + other_id, true, false).get_meta("inspected"),
					label + " hover does not illuminate unrelated legal " + other_id)
		button.mouse_exited.emit()
		_check(graph.inspected_route_id == (id if button.has_focus() else ""),
			label + " leaving the ticket keeps an existing keyboard focus only")
		button.grab_focus()
		await process_frame
		_check(button.has_focus() and graph.inspected_route_id == id
			and graph.find_child("RouteGraphPreview", true, false).get_meta("preview_ids")
				== session.map.get_node(id).outgoing
			and session.snapshot() == initial,
			label + " keyboard focus highlights same node/links without mutating run")
		button.mouse_entered.emit()
		button.mouse_exited.emit()
		_check(graph.inspected_route_id == id,
			label + " mouse exit preserves the still-focused ticket")
		var save: Button = app.stitched_run_buttons[choices.size()]
		save.grab_focus()
		await process_frame
		_check(graph.inspected_route_id.is_empty()
			and graph.find_child("RouteGraphPreview", true, false).get_meta("preview_ids", []) == []
			and session.snapshot() == initial,
			label + " keyboard focus exit clears preview without a game action")
	graph.set_inspected_route("invented")
	_check(graph.inspected_route_id.is_empty() and session.snapshot() == initial,
		label + " nonexistent map focus cannot create a path or draw RNG")


func _keyboard_route() -> void:
	var witness := _seed_with_kind("Event")
	_check(not witness.is_empty(), "keyboard finds a real opening Event witness")
	if witness.is_empty():
		return
	var app: Node = await _new_run(witness.seed)
	var session: StitchedRunSession = app.stitched_run_session
	if session == null:
		app.free()
		return
	_assert_book(app, "keyboard opening")
	await _exercise_graph_inspection(app, "keyboard opening")
	var index: int = session.choices().find(str(witness.id))
	_check(index >= 0, "keyboard Event is a connected legal choice")
	if index < 0:
		app.free()
		return
	var button: Button = app.stitched_run_buttons[index]
	button.grab_focus()
	await process_frame
	_check(button.has_focus(), "focused legal ticket receives keyboard focus")
	var before := session.snapshot()
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame
	_check(session.map.get_route() == [witness.id]
		and session.phase == "visit" and session.candle == maxi(0, before.candle - 8),
		"keyboard Enter authenticates one legal node and spends exactly one candle toll")
	var entered := session.snapshot()
	_check(not is_instance_valid(button) or not button.is_visible_in_tree(),
		"consumed keyboard ticket is no longer on the live map")
	if is_instance_valid(button):
		button.pressed.emit()
	_check(session.snapshot() == entered,
		"old focused ticket cannot replay admission or advance the seeded RNG")
	app.free()
	await process_frame


func _seed_with_kind(kind: String) -> Dictionary:
	for seed_number in range(100):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_number
		var generated := RunMap.new()
		if not generated.generate(rng):
			continue
		for id in generated.get_legal_choices():
			if generated.get_node(id).type == kind:
				return {"seed": seed_number, "id": id}
	return {}


func _visit_kind(kind: String, expect_disabled: bool) -> void:
	var witness := _seed_with_kind(kind)
	_check(not witness.is_empty(), kind + " has a real seeded opening node")
	if witness.is_empty():
		return
	var app: Node = await _new_run(witness.seed)
	var session: StitchedRunSession = app.stitched_run_session
	if session == null:
		app.free()
		return
	var route_choices := session.choices()
	var node_id: String = witness.id
	var map_page := _page(app, "map", kind + " map")
	_assert_actions(app, route_choices.size(), kind + " map")
	if map_page != null:
		var scroll := map_page.find_child("RunActionScroll", true, false)
		_check(scroll != null, kind + " map has a real scrolling node selector")
		for index in route_choices.size():
			var node := session.map.get_node(route_choices[index])
			var button: Button = app.stitched_run_buttons[index]
			_check(button.get_meta("route_id", "") == route_choices[index]
				and button.get_meta("node_kind", "") == node.type
				and "PATH %d" % (node.position + 1) in button.text
				and "FLOOR %02d" % node.floor in button.text
				and not button.disabled, "legal node labels exactly match authenticated connected graph")
			var icon: TextureRect = button.find_child("AuthoredNodeIcon", false, false)
			_check(icon != null and icon.texture != null, "legal node carries real authored icon")
	_assert_book(app, kind + " opening")
	await _exercise_graph_inspection(app, kind + " opening")
	var old_route_button: Button = app.stitched_run_buttons[route_choices.find(node_id)]
	var initial := session.snapshot()
	old_route_button.disabled = true
	old_route_button.pressed.emit()
	_check(session.snapshot() == initial, kind + " disabled map ticket cannot enter or draw RNG")
	old_route_button.disabled = false
	old_route_button.hide()
	old_route_button.pressed.emit()
	_check(session.snapshot() == initial, kind + " invisible map ticket cannot enter or draw RNG")
	old_route_button.show()
	_check(_press_route(app, node_id) and session.phase == "visit"
		and session.candle == maxi(0, int(initial.candle) - 8),
		kind + " entered by the public route button and charged once")
	if session.phase != "visit":
		app.free()
		return
	var service: String = session.pending.service
	_page(app, "visit:" + service, kind + " visit")
	var actions := session.visit_actions()
	_assert_actions(app, actions.size(), kind + " visit")
	var before := session.snapshot()
	old_route_button.pressed.emit()
	_check(session.snapshot() == before, kind + " stale route press cannot reenter or draw RNG")
	_check(not session.choose_visit("forged", [], before) and session.snapshot() == before,
		kind + " rejected invented command preserves RNG and wallet")
	var disabled_count := 0
	var choice_index := -1
	for index in actions.size():
		var action: Dictionary = actions[index]
		var button: Button = app.stitched_run_buttons[index]
		_check(button.disabled == not bool(action.enabled)
			and button.get_meta("action_id", "") == action.id
			and button.get_meta("action_arguments", []) == action.arguments,
			kind + " decision accurately shows its service eligibility")
		if not action.enabled:
			disabled_count += 1
			button.pressed.emit()
			_check(session.snapshot() == before
				and not session.choose_visit(action.id, action.arguments, before)
				and session.snapshot() == before,
				kind + " disabled command cannot spend or change RNG")
		elif choice_index < 0 or action.id == "leave":
			choice_index = index
	if expect_disabled:
		_check(disabled_count > 0, kind + " has an exercised disabled service choice")
	_check(choice_index >= 0, kind + " has an enabled action")
	if choice_index >= 0:
		var choice: Dictionary = actions[choice_index]
		var old_button: Button = app.stitched_run_buttons[choice_index]
		old_button.pressed.emit()
		_check(session.phase == "map" and session.receipts.size() == 1,
			kind + " real public decision settles exactly one receipt")
		var settled := session.snapshot()
		old_button.pressed.emit()
		_check(not session.choose_visit(choice.id, choice.arguments, before)
			and session.snapshot() == settled,
			kind + " accepted decision cannot replay, double-spend or redraw RNG")
	if session.phase == "map":
		_assert_book(app, kind + " committed stop")
		await _exercise_graph_inspection(app, kind + " committed stop")
		var returned := session.snapshot()
		var next_ids := session.choices()
		var old_page_buttons: Array[Button] = app.stitched_run_buttons.duplicate()
		var save_path := "user://stitched_s6_route_book_" + kind + ".save"
		app.stitched_save_path = save_path
		old_page_buttons[next_ids.size()].pressed.emit()
		var loaded := StitchedRunSave.read_file(save_path)
		_check(loaded != null and loaded.snapshot() == returned,
			kind + " mounted Save preserves sealed route, RNG, ledger, and four heroes")
		old_page_buttons[next_ids.size() + 1].pressed.emit()
		var restored: StitchedRunSession = app.stitched_run_session
		_check(restored != null and restored != session and restored.snapshot() == returned
			and restored.map.get_route() == session.map.get_route()
			and restored.choices() == next_ids,
			kind + " mounted Reload restores the exact connected map and choices")
		_assert_book(app, kind + " reloaded journey")
		# Exercise old callbacks before yielding: the previous page is already
		# queued for deletion, while the new atlas uses independent controls.
		for stale in old_page_buttons:
			stale.pressed.emit()
		_check(session.snapshot() == returned and app.stitched_run_session == restored
			and restored.snapshot() == returned,
			kind + " stale Save/Reload/route buttons cannot replay or consume RNG")
		await _exercise_graph_inspection(app, kind + " reloaded journey")
		DirAccess.remove_absolute(save_path)
	app.free()
	await process_frame


func _terminal(app: Node, mode: String) -> void:
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.phase == mode, mode + " is a settled live session")
	if session == null or session.phase != mode:
		return
	var page := _page(app, mode, mode + " result")
	if page == null:
		return
	var banner: TextureRect = page.find_child("TerminalBanner", true, false)
	_check(banner != null and banner.texture != null, mode + " has authored result banner")
	_check(app.stitched_run_buttons.size() == 2
		and app.stitched_run_buttons[0].text == "Return to title"
		and app.stitched_run_buttons[1].text == "Save run",
		mode + " keeps public Return and Save actions")
	_assert_actions(app, 2, mode + " result")
	var settled := session.snapshot()
	_check(not session.enter("forged", settled) and session.snapshot() == settled,
		mode + " rejects further route rewards without RNG/ledger change")
	_check(not session.choose_visit("leave", [], settled) and session.snapshot() == settled,
		mode + " rejects further visit rewards without RNG/ledger change")
	var save_path := "user://stitched_s6_routed_vis_a_" + mode + ".save"
	app.stitched_save_path = save_path
	app.stitched_run_buttons[1].pressed.emit()
	var loaded := StitchedRunSave.read_file(save_path)
	_check(loaded != null and loaded.snapshot() == settled,
		mode + " mounted Save retains the complete sealed receipt and four heroes")
	DirAccess.remove_absolute(save_path)


func _run() -> void:
	await _keyboard_route()
	await _visit_kind("Event", false)
	await _visit_kind("SewingCircle", true)
	var win_app: Node = await _new_run(42)
	if win_app.stitched_run_session != null:
		_complete_route(win_app)
		_terminal(win_app, "victory")
	win_app.free()
	await process_frame
	var lose_app: Node = await _new_run(42)
	var session: StitchedRunSession = lose_app.stitched_run_session
	if session != null:
		var fight_id := ""
		for id in session.choices():
			if session.map.get_node(id).type == "Fight":
				fight_id = id
				break
		_check(not fight_id.is_empty() and _press_route(lose_app, fight_id),
			"defeat enters real opening Fight using a mounted path")
		var stage: StitchedBattleScreen = lose_app.stitched_run_battle
		if stage != null:
			var turns := 0
			for step in range(800):
				if stage.battle.is_over():
					break
				var previous := stage.receipts.size()
				stage._action_buttons["pass"].pressed.emit()
				if stage.receipts.size() == previous:
					break
				turns += 1
			_check(turns > 0 and stage.battle.outcome() == "defeat",
				"real enemy turns defeat all four dolls")
			if stage.battle.is_over():
				stage._action_buttons["exit"].pressed.emit()
				_terminal(lose_app, "defeat")
				_check(session.receipts.size() == 1 and session.gold == 0 and session.scraps == 0,
					"defeat did not mint any victory reward")
	lose_app.free()
	await process_frame
	for message in failures:
		printerr(message)
	print("stitched_s6_routed_vis_a_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
