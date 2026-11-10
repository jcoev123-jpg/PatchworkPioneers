extends "res://tests/stitched_s6_full_run_test.gd"
## S6 VIS-A: authenticated public route, service and terminal pages, not test-only UI.
var _mouse_scroll_verified := false
var _stop_witnesses := 0
var _campfire_witnesses := 0


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
	if expected_kind.begins_with("visit:"):
		# A road stop stands in the corridor: the party at their ranks, one plain felt page, no numbers.
		var stage := page.find_child("CorridorStage", true, false) as StitchedCorridorStage
		_check(stage != null and stage.is_visible_in_tree() and stage.fighting, label + " stands in the corridor")
		if stage != null:
			for hero in app.stitched_run_session.heroes:
				var figure: Sprite3D = stage.figure_nodes.get("hero_%d" % hero.rank)
				_check((figure != null and figure.visible and stage.screen_point("hero_%d" % hero.rank).x < 640.0) != bool(hero.lost),
					label + " shows " + str(hero.id) + " standing on the left unless lost")
		_check(frame != null and frame.get_global_rect().position.x >= 640.0 and frame.get_global_rect().end.x <= 1280.0, label + " keeps its page right of the party")
		_check(page.find_child("RunLedger", true, false) == null and page.find_child("FourHeroRecaps", true, false) == null,
			label + " shows no ledger or doll numbers")
		var story := page.find_child("RouteOrVisitStory", true, false) as Control
		_check(story != null and story.is_visible_in_tree() and not app.stitched_run_session.visit_story().is_empty(),
			label + " tells the stop's story: " + app.stitched_run_session.visit_story())
		return page
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
				and not recap.text.contains("FRAY")
				and ("LOST" in recap.text) == bool(hero.lost),
				label + " reads true HP and loss with the fray readout hidden for " + str(hero.id))
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
	var left_skin: StyleBoxTexture = left.get_theme_stylebox("panel") as StyleBoxTexture if left != null else null
	var right_skin: StyleBoxTexture = right.get_theme_stylebox("panel") as StyleBoxTexture if right != null else null
	_check(left_skin != null and right_skin != null and left_skin.texture != null
		and right_skin.texture != null and left_skin.texture == right_skin.texture
		and left_skin.texture_margin_left >= 16 and right_skin.texture_margin_right >= 16
		and left_skin.modulate_color.r < 0.5 and right_skin.modulate_color.r < 0.5,
		label + " both route pages have dark authored nine-slice felt, not code-drawn panels")
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
		label + " embeds the live route atlas on the left page")
	if graph == null:
		return
	var left := book.find_child("RouteOrVisitStory", true, false)
	var scroll := graph.find_child("RouteGraphScroll", true, false) as ScrollContainer
	var bands := graph.find_child("RouteGraphBands", true, false) as VBoxContainer
	var preview := graph.find_child("RouteGraphPreview", true, false) as Label
	var floors := session.map.get_floors()
	var title := graph.find_child("GraphTitle", true, false) as Label
	_check(title != null and title.get_theme_font_size("font_size") >= 14
		and preview != null and preview.get_theme_font_size("font_size") >= 16,
		label + " graph heading and outgoing-seam preview have effective readable sizes")
	var route := session.map.get_route()
	var choices := session.choices()
	_check(graph.is_ancestor_of(scroll) and left.is_ancestor_of(graph)
		and scroll != null and bands != null and preview != null
		and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
		and scroll.follow_focus and graph.get_meta("floor_count") == floors.size() and floors.size() == 12,
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
	var three_path_floors := 0
	var four_path_floors := 0
	for floor_index in floors.size():
		var floor_nodes: Array = floors[floor_index]
		if floor_nodes.size() == 3:
			three_path_floors += 1
		elif floor_nodes.size() == 4:
			four_path_floors += 1
		var band := graph.find_child("GraphFloor_%02d" % (floor_index + 1), true, false) as VBoxContainer
		_check(band != null and band.get_meta("floor", -1) == floor_index + 1
			and band.get_meta("node_ids", []) == floor_nodes.map(func(node: Dictionary): return str(node.id)),
			label + " authored floor %02d has the exact generated nodes" % (floor_index + 1))
		if band == null:
			continue
		var floor_title := band.get_child(0) as Label
		_check(floor_title != null and floor_title.get_theme_font_size("font_size") >= 14
			and "FLOOR %02d" % (floor_index + 1) in floor_title.text,
			label + " every scrollable floor retains a readable numbered heading")
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
			var activations := tile.find_children("GraphNodeActivate", "Button", false, false)
			var activation := activations[0] as Button if activations.size() == 1 else null
			var focus_skin: StyleBoxTexture = activation.get_theme_stylebox("focus") as StyleBoxTexture if activation != null else null
			var normal_skin: StyleBoxTexture = activation.get_theme_stylebox("normal") as StyleBoxTexture if activation != null else null
			_check(activations.size() == (1 if choices.has(id) else 0)
				and (not choices.has(id) or (activation != null
					and activation.get_meta("route_id", "") == id
					and activation.get_meta("art_path", "") == "res://assets/paper/ui/reward_button.png"
					and activation.focus_mode == Control.FOCUS_ALL and not activation.disabled
					and activation.is_visible_in_tree()
					and activation.get_theme_stylebox("normal") is StyleBoxTexture
					and activation.get_theme_stylebox("focus") is StyleBoxTexture
					and activation.get_theme_font_size("font_size") >= 16
					and focus_skin != null and normal_skin != null
					and focus_skin.modulate_color != normal_skin.modulate_color)),
				label + " " + id + " has one real image-backed activation iff connected/legal")
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
				label + " " + id + " has exact detached session truth in a passive tile shell")
			_check(art != null and art.texture != null and art.get_meta("art_path", "").begins_with("res://assets/paper/ui/map_node_")
				and kind != null and record.type.to_upper() in kind.text
				and floor_label != null and "FLOOR %02d" % record.floor in floor_label.text
				and path_label != null and "PATH %d" % (record.position + 1) in path_label.text
				and state_label != null and state_label.text == (
					"FOCUSED" if tile.get_meta("inspected") else
					"CURRENT" if expected_status == "current" else
					"VISITED" if expected_status == "visited" else
					"LEGAL" if expected_status == "legal" else "FUTURE")
				and kind.get_theme_font_size("font_size") >= 14
				and floor_label.get_theme_font_size("font_size") >= 14
				and path_label.get_theme_font_size("font_size") >= 14
				and state_label.get_theme_font_size("font_size") >= 14,
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
						and "F%02d P%d" % [session.map.get_node(target).floor,
							session.map.get_node(target).position + 1] in edge.text
						and edge.get_theme_font_size("font_size") >= 14
						and edge.mouse_filter == Control.MOUSE_FILTER_IGNORE,
						label + " " + id + " retains directed link to " + target)
					edge_count += 1
	_check(three_path_floors > 0 and four_path_floors > 0,
		label + " exercises real three-path and four-path seeded bands, not an empty fixture")
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
	var floor_rows := graph.find_children("GraphFloorPaths", "HBoxContainer", true, false)
	_check(floor_rows.size() == session.map.get_floors().size() and floor_rows.size() > 0,
		label + " measures all twelve live rendered floor rows")
	for floor_row in floor_rows:
		var row_rect := (floor_row as Control).get_global_rect()
		_check(row_rect.position.x >= g.position.x - 1
			and row_rect.end.x <= g.end.x + 1
			and row_rect.size.x > 0,
			label + " 3-4 path row remains inside the graph scroll without horizontal clipping")
		var previous_end := row_rect.position.x
		for tile in floor_row.get_children():
			var rect := (tile as Control).get_global_rect()
			_check(rect.position.x >= previous_end - 1 and rect.end.x <= g.end.x + 1
				and rect.size.x >= 81,
				label + " every path tile stays in reading order without overlap")
			previous_end = rect.end.x
			for child in tile.get_children():
				if child is Control:
					var child_rect := (child as Control).get_global_rect()
					_check(child_rect.position.x >= rect.position.x - 1
						and child_rect.end.x <= rect.end.x + 1,
						label + " tile icon, facts, ENTER and seam labels remain inside their column")
	var atlas_scroll := graph_scroll as ScrollContainer
	_check(atlas_scroll != null and atlas_scroll.get_v_scroll_bar().max_value
		- atlas_scroll.get_v_scroll_bar().page > 100,
		label + " twelve full-height node bands overflow vertically into a real native scroll")
	var initial := session.snapshot()
	var choices := session.choices()
	_check(choices.size() > 0, label + " has at least one real choice to inspect")
	for index in choices.size():
		var id: String = choices[index]
		var button: Button = app.stitched_run_buttons[index]
		button.mouse_entered.emit()
		var hovered_preview := (graph.find_child("RouteGraphPreview", true, false) as Label).text
		_check(graph.inspected_route_id == id
			and graph.find_child("GraphNode_" + id, true, false).get_meta("inspected")
			and graph.find_child("RouteGraphPreview", true, false).get_meta("preview_ids")
				== session.map.get_node(id).outgoing
			and session.snapshot() == initial,
			label + " mouse inspection matches " + id + " and draws no RNG")
		await _assert_preview_purpose(graph, session, id, label + " ticket hover")
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
			and (graph.find_child("RouteGraphPreview", true, false) as Label).text == hovered_preview
			and graph.find_child("RouteGraphPreview", true, false).get_meta("preview_ids")
				== session.map.get_node(id).outgoing
			and session.snapshot() == initial,
			label + " keyboard focus highlights same node/links without mutating run")
		await _assert_preview_purpose(graph, session, id, label + " ticket focus")
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
		_assert_preview_default(graph, label + " ticket focus exit")
	for id in choices:
		var tile := graph.find_child("GraphNode_" + id, true, false) as VBoxContainer
		var activate := tile.get_node("GraphNodeActivate") as Button
		var ticket: Button = app.stitched_run_buttons[choices.find(id)]
		_check(ticket.get_node(ticket.focus_neighbor_left) == activate
			and activate.get_node(activate.focus_neighbor_right) == ticket,
			label + " keyboard Left/Right joins lit graph node and original ticket")
		activate.mouse_entered.emit()
		var hovered_graph_preview := (graph.find_child("RouteGraphPreview", true, false) as Label).text
		_check(graph.inspected_route_id == id and tile.get_meta("inspected")
			and (tile.get_node("GraphNodeState") as Label).text == "FOCUSED"
			and graph.find_child("RouteGraphPreview", true, false).get_meta("preview_ids")
				== session.map.get_node(id).outgoing
			and session.snapshot() == initial,
			label + " graph pointer hover previews exact authored outgoing seams without spending")
		await _assert_preview_purpose(graph, session, id, label + " graph hover")
		activate.mouse_exited.emit()
		_check(graph.inspected_route_id.is_empty() and session.snapshot() == initial,
			label + " graph pointer exit clears preview without changing the run")
		activate.grab_focus()
		await process_frame
		_check(activate.has_focus() and graph.inspected_route_id == id
			and (graph.find_child("RouteGraphPreview", true, false) as Label).text == hovered_graph_preview
			and graph.find_child("RouteGraphPreview", true, false).get_meta("preview_ids")
				== session.map.get_node(id).outgoing and session.snapshot() == initial,
			label + " graph keyboard focus traces real outgoing edges without drawing RNG")
		await _assert_preview_purpose(graph, session, id, label + " graph focus")
		activate.mouse_entered.emit()
		activate.mouse_exited.emit()
		_check(graph.inspected_route_id == id,
			label + " graph mouse exit preserves keyboard focus inspection")
		var save: Button = app.stitched_run_buttons[choices.size()]
		save.grab_focus()
		await process_frame
		_check(graph.inspected_route_id.is_empty()
			and graph.find_child("RouteGraphPreview", true, false).get_meta("preview_ids") == []
			and session.snapshot() == initial,
			label + " graph blur restores empty preview with no spend")
		_assert_preview_default(graph, label + " graph blur")
	# One genuine wheel witness per run is sufficient; Godot's synthetic wheel
	# button state is global and repeated separate Window mounts are not physical
	# pointer sessions. Keyboard paging is still checked on every mounted atlas.
	atlas_scroll.scroll_vertical = 0
	await process_frame
	var after_wheel := 0
	if not _mouse_scroll_verified:
		var wheel_motion := InputEventMouseMotion.new()
		wheel_motion.position = atlas_scroll.get_global_rect().get_center()
		root.push_input(wheel_motion, true)
		await process_frame
		atlas_scroll.scroll_vertical = 0
		await process_frame
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		wheel.factor = 1.0
		wheel.position = atlas_scroll.get_global_rect().get_center()
		root.push_input(wheel, true)
		await process_frame
		wheel.pressed = false
		root.push_input(wheel, true)
		await process_frame
		_mouse_scroll_verified = atlas_scroll.scroll_vertical > 0 and session.snapshot() == initial
		_check(_mouse_scroll_verified,
			label + " pointer wheel scrolls actual tall atlas without advancing RNG or ledger")
		after_wheel = atlas_scroll.scroll_vertical
	atlas_scroll.grab_focus()
	await process_frame
	var page_key := InputEventKey.new()
	page_key.keycode = KEY_PAGEDOWN
	page_key.pressed = true
	Input.parse_input_event(page_key)
	await process_frame
	page_key.pressed = false
	Input.parse_input_event(page_key)
	await process_frame
	_check(atlas_scroll.scroll_vertical > after_wheel and session.snapshot() == initial,
		label + " keyboard PageDown scrolls the native atlas without route entry")
	atlas_scroll.scroll_vertical = 0
	await process_frame
	if not choices.is_empty():
		var cancel_tile := graph.find_child("GraphNode_" + choices[0], true, false) as VBoxContainer
		var cancel_button := cancel_tile.get_node("GraphNodeActivate") as Button
		cancel_button.grab_focus()
		await process_frame
		_check(cancel_button.has_focus() and graph.inspected_route_id == choices[0],
			label + " Escape precondition has a real focused, legal atlas entry")
		var escape_key := InputEventKey.new()
		escape_key.keycode = KEY_ESCAPE
		escape_key.pressed = true
		root.push_input(escape_key, true)
		await process_frame
		_check(not cancel_button.has_focus() and graph.inspected_route_id.is_empty()
			and session.snapshot() == initial,
			label + " keyboard Escape cancels preview without route, wallet or RNG mutation")
		_assert_preview_default(graph, label + " Escape")
	graph.set_inspected_route("invented")
	_check(graph.inspected_route_id.is_empty() and session.snapshot() == initial,
		label + " nonexistent map focus cannot create a path or draw RNG")


const _SPLIT_KINDS := ["Campfire", "SewingCircle", "Peddler", "Unpicker", "PatchStall"]
const _NON_STOP_KINDS := ["Fight", "Elite", "Event", "Treasure", "Boss", "Mystery", "", "campfire"]


## The visible preview of an inspected legal node: true floor/path, every real
## outgoing seam, and the helper's lead only for the five split stops.
func _assert_preview_purpose(graph: StitchedRouteGraphView, session: StitchedRunSession,
		id: String, label: String) -> void:
	var node := session.map.get_node(id)
	var preview := graph.find_child("RouteGraphPreview", true, false) as Label
	_check(preview != null and not node.is_empty(), label + " has a real preview and node")
	if preview == null or node.is_empty():
		return
	var text := preview.text
	var kind := RunV3StopChoiceProjection.v3_kind_for(str(node.type))
	var lead := str(RunV3StopChoiceProjection.stitched_stop_help_for(kind).get("lead", ""))
	var hint := StitchedRouteGraphView.campfire_recovery_hint_for(str(node.type))
	if kind == "Campfire":
		_check(not hint.is_empty(), label + " Campfire has a recovery hint")
		_campfire_witnesses += 1
		# The compact hint replaces the generic lead for Campfire only.
		lead = hint
	else:
		_check(hint.is_empty(), label + " " + str(node.type) + " gains no Campfire hint")
	_check(("LIT F%02d P%d: %s" % [node.floor, node.position + 1, node.type]) in text,
		label + " preview keeps the inspected real type, floor and path")
	var destinations: Array = []
	var previous_at := -1
	for target in node.outgoing:
		var seam: Dictionary = session.map.get_node(str(target))
		_check(not seam.is_empty(), label + " resolves source-backed destination " + str(target))
		if seam.is_empty():
			continue
		destinations.append({"id": str(target), "type": str(seam.type),
			"floor": int(seam.floor), "path": int(seam.position) + 1})
		var line := "F%02d P%d: %s" % [seam.floor, seam.position + 1, seam.type]
		var at := text.find(line)
		_check(at > previous_at, label + " previews ordered real destination " + str(target))
		previous_at = at
	_check(preview.get_meta("preview_ids", []) == node.outgoing
		and preview.get_meta("preview_destinations", []) == destinations
		and ("FINAL SEAM" in text) == node.outgoing.is_empty(),
		label + " visible next-stop names and IDs match only the real directed links")
	if lead.is_empty():
		_check(str(preview.get_meta("stop_purpose", "x")) == "",
			label + " " + str(node.type) + " gains no stop purpose")
	else:
		_stop_witnesses += 1
		_check(lead in text and str(preview.get_meta("stop_purpose", "")) == lead,
			label + " " + str(node.type) + " shows its stop purpose from the shared helper")
	if kind == "Campfire":
		_check("30%" in text and "25" in text and "50" in text and "100" in text
			and "Mend 30% HP" in text and "Tales -25 FRAY" in text
			and "Wick +50 CANDLE" in text and "max 100" in text
			and "pick one" in text and "Possible" in text,
			label + " Campfire shows all three recovery values as one possible pick")
		_check(not RunV3StopChoiceProjection.stitched_stop_help_for("Campfire").lead in text,
			label + " Campfire hint replaces the generic lead")
		_check(not "guarantee" in text.to_lower() and not "heals " in text.to_lower(),
			label + " Campfire promises no guaranteed gain")
	for other in _SPLIT_KINDS:
		var other_lead := str(RunV3StopChoiceProjection.stitched_stop_help_for(other).get("lead", ""))
		if other_lead != lead and not (kind == "Campfire" and other == "Campfire"):
			_check(not other_lead in text, label + " does not show the " + other + " purpose")
	_check(not "GOLD" in text.to_upper() and not "STOCK" in text.to_upper(),
		label + " invents no price or stock")
	await process_frame
	var scroll := graph.find_child("RouteGraphScroll", true, false) as Control
	_check(scroll != null and scroll.get_global_rect().size.y >= 100
		and preview.get_theme_font_size("font_size") >= 16
		and preview.get_line_count() > 0
		and preview.get_visible_line_count() == preview.get_line_count()
		and preview.get_global_rect().position.x >= graph.get_global_rect().position.x - 1
		and preview.get_global_rect().end.x <= graph.get_global_rect().end.x + 1
		and preview.get_global_rect().end.y <= (graph.get_global_rect().end.y + 1),
		label + " preview keeps the atlas scroll at least 100px and inside the page")


func _assert_preview_default(graph: StitchedRouteGraphView, label: String) -> void:
	var preview := graph.find_child("RouteGraphPreview", true, false) as Label
	_check(preview != null and preview.text == "FOCUS A LIT TICKET TO TRACE ITS NEXT SEAMS"
		and str(preview.get_meta("stop_purpose", "x")) == "",
		label + " restores the default preview with no stop purpose")


func _check_stop_purpose_helper() -> void:
	var seen: Dictionary = {}
	for kind in _SPLIT_KINDS:
		var purpose := StitchedRouteGraphView.stop_purpose_for(kind)
		_check(not purpose.is_empty() and purpose == str(
			RunV3StopChoiceProjection.stitched_stop_help_for(kind).lead)
			and not seen.has(purpose), kind + " has its own distinct stop purpose")
		seen[purpose] = true
	_check(StitchedRouteGraphView.stop_purpose_for("Rest")
		== StitchedRouteGraphView.stop_purpose_for("Campfire"),
		"legacy Rest aliases to the Campfire purpose")
	_check(StitchedRouteGraphView.stop_purpose_for("Shop")
		== StitchedRouteGraphView.stop_purpose_for("Peddler"),
		"legacy Shop aliases to the Peddler purpose")
	for kind in _NON_STOP_KINDS:
		_check(StitchedRouteGraphView.stop_purpose_for(kind).is_empty(),
			"'" + kind + "' gains no split-stop purpose")
	var hint := StitchedRouteGraphView.campfire_recovery_hint_for("Campfire")
	_check(hint == "Possible, pick one: Mend %d%% HP / Tales -%d FRAY / Wick +%d CANDLE, max %d" % [
		RunCampfireVisit.MEND_HEAL_PERCENT, RunCampfireVisit.TALES_FRAY_REDUCTION,
		RunCampfireVisit.WICK_CANDLE_RESTORE, RunCampfireVisit.STITCHED_CANDLE_MAX]
		and "Mend 30% HP" in hint and "Tales -25 FRAY" in hint
		and "Wick +50 CANDLE" in hint and "max 100" in hint
		and not "GOLD" in hint.to_upper(),
		"Campfire hint shows 30/25/50/100 from the real constants and no price")
	_check(StitchedRouteGraphView.campfire_recovery_hint_for("Rest") == hint,
		"legacy Rest maps to the same Campfire hint")
	for kind in ["Peddler", "SewingCircle", "Unpicker", "PatchStall", "Shop"]:
		_check(StitchedRouteGraphView.campfire_recovery_hint_for(kind).is_empty()
			and not StitchedRouteGraphView.stop_purpose_for(kind).is_empty(),
			kind + " keeps its own lead and gains no Campfire hint")
	for kind in _NON_STOP_KINDS:
		_check(StitchedRouteGraphView.campfire_recovery_hint_for(kind).is_empty(),
			"'" + kind + "' gains no Campfire hint")


## S8f-enabled live app: graph admission is the same real entry used by tickets.
func _graph_walk_and_rejections() -> void:
	var witness := _seed_with_kind("Event")
	_check(not witness.is_empty(), "graph Walk has a genuine non-boss opening witness")
	if witness.is_empty():
		return
	root.size = Vector2i(1280, 720)
	var app: Node = load("res://scenes/app.tscn").instantiate()
	app.run_seed = witness.seed
	root.add_child(app)
	await process_frame
	app.start_button.pressed.emit()
	await process_frame
	app.stitched_run_buttons[0].pressed.emit()
	await process_frame
	if is_instance_valid(app.stitched_run_intro):
		var begin: Button = app.stitched_run_intro.find_child("WrenIntroBegin", true, false)
		_check(begin != null, "graph Walk dismisses the real Wren intro")
		if begin != null:
			begin.pressed.emit()
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.phase == "map" and session.walks_enabled,
		"graph Walk is mounted in the live S8f-enabled New Run")
	if session == null or session.phase != "map":
		app.free()
		return
	# Owner 11-08: with walks on the map is a corridor junction. The atlas still serves the
	# no-walk page, so its admission checks run there on this same walk-enabled session.
	_check(app.stitched_run_panel is StitchedCorridorJunction, "graph Walk opening mounts the corridor junction")
	app.stitched_walks = false
	app._present_stitched_run()
	await process_frame
	_assert_book(app, "graph Walk opening")
	await _exercise_graph_inspection(app, "graph Walk opening")
	var book := app.stitched_run_panel.find_child("StitchedRouteBookView", true, false) as StitchedRouteBookView
	var graph: StitchedRouteGraphView = book.graph_view
	var id: String = witness.id
	_check(session.choices().has(id) and session.map.get_node(id).type != "Boss",
		"graph admission uses an actual connected, non-boss map ID")
	var tile := graph.find_child("GraphNode_" + id, true, false) as VBoxContainer
	var button := tile.get_node("GraphNodeActivate") as Button
	var before := session.snapshot()
	var journal_before := session.journal.size()
	_check(before.candle == 100 and journal_before == 0 and session.receipts.is_empty(),
		"graph Walk begins with a fresh unspent candle, journal and receipts")
	for floor in session.map.get_floors():
		for record in floor:
			if not session.choices().has(str(record.id)):
				graph.route_requested.emit(str(record.id))
				_check(session.snapshot() == before and session.journal.size() == journal_before,
					"disconnected/visited/future node " + str(record.id) + " cannot request entry")
	graph.route_requested.emit("forged")
	_check(session.snapshot() == before and session.journal.size() == journal_before,
		"forged ID via the public graph signal cannot spend or change RNG/ledger")
	button.disabled = true
	button.pressed.emit()
	graph.route_requested.emit(id)
	_check(session.snapshot() == before, "disabled graph button and signal reject even a legal ID")
	button.disabled = false
	button.hide()
	button.pressed.emit()
	graph.route_requested.emit(id)
	_check(session.snapshot() == before, "hidden graph button and signal reject even a legal ID")
	button.show()
	button.grab_focus()
	await process_frame
	var graph_scroll := graph.find_child("RouteGraphScroll", true, false) as ScrollContainer
	var pointer := button.get_global_rect().get_center()
	_check(graph_scroll.get_global_rect().has_point(pointer)
		and root.get_visible_rect().has_point(pointer),
		"lit graph activation is fully reachable inside the mounted book's clipped scroll")
	var motion := InputEventMouseMotion.new()
	motion.position = pointer
	root.push_input(motion, true)
	await process_frame
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = pointer
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		root.push_input(click, true)
		await process_frame
	_check(session.phase == "walk" and app.stitched_run_walk != null
		and app.stitched_run_walk.host == session and session.map.get_route() == [id]
		and session.map.get_current_node_id() == id
		and session.candle == before.candle - 8
		and session.journal.size() == journal_before + 1
		and session.journal.back().action == "enter"
		and session.journal.back().node_id == id and session.receipts.is_empty(),
		"graph pointer enters exactly once, charges eight candle, journals once and mounts hosted Walk")
	var entered := session.snapshot()
	if is_instance_valid(button):
		button.pressed.emit()
	if is_instance_valid(graph):
		graph.route_requested.emit(id)
	_check(session.snapshot() == entered and session.journal.size() == journal_before + 1,
		"stale graph control and signal after Walk transition cannot replay or draw RNG")
	app.free()
	await process_frame

	# Keyboard Enter must activate a fresh native graph control, not a data hook.
	var keyboard_app: Node = load("res://scenes/app.tscn").instantiate()
	keyboard_app.run_seed = witness.seed
	root.add_child(keyboard_app)
	await process_frame
	keyboard_app.start_button.pressed.emit()
	await process_frame
	keyboard_app.stitched_run_buttons[0].pressed.emit()
	await process_frame
	if is_instance_valid(keyboard_app.stitched_run_intro):
		keyboard_app.stitched_run_intro.find_child("WrenIntroBegin", true, false).pressed.emit()
	keyboard_app.stitched_walks = false   # the atlas page; walks stay on in the session
	keyboard_app._present_stitched_run()
	await process_frame
	var keyboard_session: StitchedRunSession = keyboard_app.stitched_run_session
	var keyboard_graph := keyboard_app.stitched_run_panel.find_child("StitchedRouteGraphView", true, false) as StitchedRouteGraphView
	var keyboard_button := keyboard_graph.find_child("GraphNode_" + id, true, false).get_node("GraphNodeActivate") as Button
	var keyboard_before := keyboard_session.snapshot()
	var matching_ticket: Button = keyboard_app.stitched_run_buttons[keyboard_session.choices().find(id)]
	matching_ticket.grab_focus()
	await process_frame
	var left_key := InputEventKey.new()
	left_key.keycode = KEY_LEFT
	left_key.pressed = true
	Input.parse_input_event(left_key)
	await process_frame
	left_key.pressed = false
	Input.parse_input_event(left_key)
	await process_frame
	_check(keyboard_button.has_focus(),
		"Left arrow from a right-page legal ticket reaches its matching graph button")
	if not keyboard_button.has_focus():
		keyboard_button.grab_focus()
	await process_frame
	_check(keyboard_button.has_focus(), "native legal graph control receives keyboard focus in real app")
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame
	_check(keyboard_session.phase == "walk" and keyboard_session.map.get_route() == [id]
		and keyboard_session.candle == keyboard_before.candle - 8
		and keyboard_session.journal.size() == 1
		and keyboard_app.stitched_run_walk != null,
		"native graph Enter key opens exactly one authentic hosted Walk")
	keyboard_app.free()
	await process_frame

	# A legitimate session option updates the sealed snapshot while the old
	# map view is still mounted, proving the captured page guard rejects it.
	var stale_app: Node = await _new_run(witness.seed)
	var stale_session: StitchedRunSession = stale_app.stitched_run_session
	var stale_graph := stale_app.stitched_run_panel.find_child("StitchedRouteGraphView", true, false) as StitchedRouteGraphView
	var stale_button := stale_graph.find_child("GraphNode_" + id, true, false).get_node("GraphNodeActivate") as Button
	var captured := stale_session.snapshot()
	_check(stale_session.enable_walks() and stale_session.snapshot() != captured
		and stale_session.phase == "map", "session Walk opt-in creates an authentic stale captured snapshot")
	var changed := stale_session.snapshot()
	stale_button.pressed.emit()
	stale_graph.route_requested.emit(id)
	_check(stale_session.snapshot() == changed and stale_session.map.get_route().is_empty()
		and stale_session.journal.is_empty() and stale_session.receipts.is_empty(),
		"stale expected map snapshot cannot admit or change RNG, candle, wallet or receipts")
	stale_app.free()
	await process_frame

	# Right-page path remains fully equivalent on a separate live Walk run.
	var ticket_app: Node = load("res://scenes/app.tscn").instantiate()
	ticket_app.run_seed = witness.seed
	root.add_child(ticket_app)
	await process_frame
	ticket_app.start_button.pressed.emit()
	await process_frame
	ticket_app.stitched_run_buttons[0].pressed.emit()
	await process_frame
	if is_instance_valid(ticket_app.stitched_run_intro):
		ticket_app.stitched_run_intro.find_child("WrenIntroBegin", true, false).pressed.emit()
	var ticket_session: StitchedRunSession = ticket_app.stitched_run_session
	var ticket_before := ticket_session.snapshot()
	ticket_app.stitched_run_buttons[ticket_session.choices().find(id)].pressed.emit()
	_check(ticket_session.phase == "walk" and ticket_session.map.get_route() == [id]
		and ticket_session.candle == ticket_before.candle - 8
		and ticket_session.journal.size() == 1 and ticket_app.stitched_run_walk != null,
		"untouched right-page ticket admits the identical canonical S8f Walk")
	ticket_app.free()
	await process_frame


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
		var old_graph: StitchedRouteGraphView = app.stitched_run_panel.find_child("StitchedRouteGraphView", true, false)
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
		if is_instance_valid(old_graph) and not next_ids.is_empty():
			old_graph.route_requested.emit(next_ids[0])
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
	# S9d adds a third action back to Wren's room once the bedroom pictures exist.
	var room_action := 1 if StitchedBedroom.has_art() else 0
	_check(app.stitched_run_buttons.size() == 2 + room_action
		and app.stitched_run_buttons[0].text == "Return to title"
		and app.stitched_run_buttons[1].text == "Save run"
		and (room_action == 0 or app.stitched_run_buttons[2].text == "Back to Wren's room"),
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
	_check_stop_purpose_helper()
	await _graph_walk_and_rejections()
	await _keyboard_route()
	await _visit_kind("Event", false)
	var witnesses_before := _stop_witnesses
	await _visit_kind("SewingCircle", true)
	_check(_stop_witnesses > witnesses_before,
		"a genuine mounted legal SewingCircle stop showed its purpose by mouse and keyboard")
	var campfire_before := _campfire_witnesses
	await _visit_kind("Campfire", false)
	_check(_campfire_witnesses > campfire_before,
		"a genuine mounted legal Campfire showed its recovery hint by mouse and keyboard")
	# The winning route witness is searched at run time from seed 43 (owner 11-08): a lane that
	# retunes a boss or adds a foe can turn one fixed seed's route into a real defeat. A seed
	# whose route ends in a genuine defeat is not a witness, so its route checks are dropped and
	# the next seed is tried; the kept run must pass every check and win.
	# S15 (11-09) made deeper floors bite, so the search window is wider.
	var win_app: Node = null
	var last_seed := 74
	for seed_number in range(43, last_seed + 1):
		var kept := failures.size()
		win_app = await _new_run(seed_number)
		if win_app.stitched_run_session == null:
			break
		_complete_route(win_app)
		# A lost route battle stops _complete_route before the session settles, so the
		# witness test is a settled victory, not merely "not defeat".
		if win_app.stitched_run_session.phase == "victory" or seed_number == last_seed:
			break
		failures.resize(kept)
		win_app.free()
		await process_frame
	if win_app.stitched_run_session != null:
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
