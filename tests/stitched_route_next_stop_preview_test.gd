extends SceneTree
## Seeded source-vs-visible branch disclosure, using the real RunMap and live
## StitchedRouteGraphView (not a canned path list or fake map records).

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _assert_choice(view: StitchedRouteGraphView, map: RunMap, id: String,
		context: String) -> void:
	var node := map.get_node(id)
	_check(not node.is_empty() and view.legal_ids.has(id),
		context + " tests an actual offered map record")
	if node.is_empty():
		return
	var preview := view.find_child("RouteGraphPreview", true, false) as Label
	_check(preview != null, context + " has a mounted visible preview")
	if preview == null:
		return
	view.set_inspected_route(id)
	var expected: Array = []
	var previous_at := -1
	for target in node.outgoing:
		var record := map.get_node(str(target))
		_check(not record.is_empty(), context + " has a real destination " + str(target))
		if record.is_empty():
			continue
		expected.append({"id": str(target), "type": str(record.type),
			"floor": int(record.floor), "path": int(record.position) + 1})
		var label := "F%02d P%d: %s" % [record.floor, record.position + 1, record.type]
		var where := preview.text.find(label)
		_check(where > previous_at, context + " shows the true ordered " + label)
		previous_at = where
	_check(view.inspected_route_id == id
		and preview.get_meta("preview_ids", []) == node.outgoing
		and preview.get_meta("preview_destinations", []) == expected
		and ("LIT F%02d P%d: %s" % [node.floor, node.position + 1, node.type]) in preview.text,
		context + " displays its exact source and target records")
	_check(("FINAL SEAM" in preview.text) == node.outgoing.is_empty(),
		context + " marks final seam only on a genuine no-exit node")
	# A preview must not disclose any other future map node as an exit, even
	# when an authored edge crosses path columns or skips a visual neighbor.
	for floor_nodes in map.get_floors():
		for record in floor_nodes:
			if str(record.id) == id or node.outgoing.has(str(record.id)):
				continue
			var extra := "F%02d P%d: %s" % [record.floor, record.position + 1, record.type]
			_check(not extra in preview.text, context + " hides unrelated " + str(record.id))


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var saw_crossing := false
	var saw_multi := false
	var saw_terminal := false
	for seed_number in [0, 17, 42]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_number
		var map := RunMap.new()
		_check(map.generate_stitched(rng), "seed %d generates the authoritative stitched map" % seed_number)
		var choices := map.get_legal_choices()
		_check(choices.size() >= 3 and choices.size() <= 4,
			"seed %d starts with 3-4 legal first-floor paths" % seed_number)
		var snapshot := map.export_state()
		var rng_state := rng.state
		var view := StitchedRouteGraphView.new()
		root.add_child(view)
		view.present(map, choices)
		await process_frame
		var preview := view.find_child("RouteGraphPreview", true, false) as Label
		_check(preview != null and preview.text == "FOCUS A LIT TICKET TO TRACE ITS NEXT SEAMS",
			"seed %d starts without an inspected or fabricated exit" % seed_number)
		var first := map.get_node("f01_n0")
		var second := map.get_node("f01_n1")
		saw_crossing = saw_crossing or (first.outgoing.has("f02_n1")
			and second.outgoing.has("f02_n0"))
		for id in choices:
			var record := map.get_node(id)
			saw_multi = saw_multi or record.outgoing.size() >= 2
			_assert_choice(view, map, id, "seed %d opening %s" % [seed_number, id])
			_check(map.export_state() == snapshot and rng.state == rng_state,
				"seed %d inspecting %s spends no route or RNG" % [seed_number, id])
			view.clear_inspected_route()
			_check(view.inspected_route_id.is_empty() and preview.get_meta("preview_ids", []) == []
				and preview.get_meta("preview_destinations", []) == []
				and preview.text == "FOCUS A LIT TICKET TO TRACE ITS NEXT SEAMS",
				"seed %d clears the offered preview" % seed_number)
		view.set_inspected_route("forged")
		view.set_inspected_route("f12_n0")
		_check(view.inspected_route_id.is_empty() and map.export_state() == snapshot
			and rng.state == rng_state,
			"seed %d forged and future nodes cannot be inspected or spend RNG" % seed_number)
		view.free()
		await process_frame

		# Reach the final legal boss candidates only through genuine connected
		# admissions; no fixture overrides RunMap topology.
		for floor_index in range(11):
			var offered := map.get_legal_choices()
			_check(not offered.is_empty() and map.choose_node(offered[0]),
				"seed %d advances through authentic floor %d" % [seed_number, floor_index + 1])
		var final_choices := map.get_legal_choices()
		_check(not final_choices.is_empty(), "seed %d reaches real boss offers" % seed_number)
		var final_view := StitchedRouteGraphView.new()
		root.add_child(final_view)
		final_view.present(map, final_choices)
		await process_frame
		var final_snapshot := map.export_state()
		for id in final_choices:
			var boss := map.get_node(id)
			saw_terminal = saw_terminal or (boss.type == "Boss" and boss.outgoing.is_empty())
			_assert_choice(final_view, map, id, "seed %d terminal %s" % [seed_number, id])
		_check(map.export_state() == final_snapshot and rng.state == rng_state,
			"seed %d final inspection cannot visit the boss or advance RNG" % seed_number)
		final_view.free()
		await process_frame
	_check(saw_crossing and saw_multi and saw_terminal,
		"non-vacuous generated crossed links, branching and actual no-exit boss cases")
	for failure in failures:
		printerr(failure)
	print("stitched_route_next_stop_preview_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
