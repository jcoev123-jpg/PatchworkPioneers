extends SceneTree
## S8f: a real New Run walks the doll's-eye corridor before its first node, then opens that node.
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app: Node = load("res://scenes/app.tscn").instantiate()
	app.run_seed = 42
	root.add_child(app)
	await process_frame
	app.start_button.pressed.emit()
	await process_frame
	app.stitched_run_buttons[0].pressed.emit()
	await process_frame
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.walks_enabled, "New Run opts into Walks")
	if session != null:
		var pick := -1
		var choices := session.choices()
		for index in choices.size():
			if session.map.get_node(choices[index]).type != "Boss":
				pick = index
				break
		app.stitched_run_buttons[pick].pressed.emit()
		await process_frame
		var walker: StitchedWalkScreen = app.stitched_run_walk
		_check(walker != null and walker.host == session and walker.walk == session.walk and session.phase == "walk",
			"the route button opens the hosted Walk screen")
		_check(walker != null and not walker.exit_button.visible, "a hosted Walk has no back-to-title shortcut")
		var steps := 0
		while app.stitched_run_walk != null and steps < 40:
			steps += 1
			walker.forward_button.pressed.emit()
			await process_frame
			if app.stitched_run_walk != null:
				_check(session.is_consistent() and session.journal.back().action == "walk",
					"each Walk button is journaled by the session")
		_check(app.stitched_run_walk == null and session.walk == null and session.phase in ["battle", "visit"],
			"finishing the Walk opens its node")
		_check(session.phase != "battle" or app.stitched_run_battle != null, "a Fight after the Walk mounts the battle")
		var restored := StitchedRunSave.restore(StitchedRunSave.capture(session))
		_check(restored != null and restored.snapshot() == session.snapshot(), "the walked run saves and replays exactly")
	app.free()
	for failure in failures:
		printerr(failure)
	print("stitched_s8f_app_walk_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
