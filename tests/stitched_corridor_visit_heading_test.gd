extends SceneTree
## Visit and event headings share the Walk's left-aligned title rail.
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures.append(reason)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var page := StitchedCorridorVisit.new()
	root.add_child(page)
	await process_frame
	_check(page.heading != null, "visit screen creates a heading")
	if page.heading != null:
		_check(is_equal_approx(page.heading.position.x, 28.0), "event title starts at the Walk's x=28 rail")
		_check(page.heading.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "event and stop titles read from left to right")
		_check(page.heading.position.x + page.heading.size.x <= 1280.0, "long stop titles stay within the screen")
	page.queue_free()
	await process_frame
	for failure in failures:
		printerr(failure)
	print("stitched_corridor_visit_heading_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
