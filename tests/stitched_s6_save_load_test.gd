extends "res://tests/stitched_s6_full_run_test.gd"


func _roundtrip(session: StitchedRunSession, label: String) -> StitchedRunSession:
	var before := session.snapshot()
	var document := StitchedRunSave.capture(session)
	_check(not document.is_empty(), label + " captures a consistent session")
	var restored := StitchedRunSave.restore(bytes_to_var(var_to_bytes(document)))
	if restored == null:
		printerr("Restore failed at " + label + " / " + str(session.pending))
	_check(restored != null and restored != session and restored.snapshot() == before,
		label + " restores exact map, RNG, heroes, ledgers and pending state")
	_check(session.snapshot() == before, label + " is read-only for the source")
	for key in ["gold", "candle", "rng", "phase", "heroes", "map"]:
		var corrupt := document.duplicate(true)
		corrupt.state[key] = "forged"
		corrupt.digest = StitchedRunSave._digest(corrupt)
		_check(StitchedRunSave.restore(corrupt) == null and session.snapshot() == before,
			label + " rejects corrupted " + key + " atomically")
	for invalid_version in [true, false, 1.0, "1", null, 999]:
		var corrupt := document.duplicate(true)
		corrupt.version = invalid_version
		_check(StitchedRunSave.restore(corrupt) == null, "malformed version rejects without runtime errors")
	var altered := document.duplicate(true)
	altered.initial.rng += 1
	_check(StitchedRunSave.restore(altered) == null, "changed initial RNG fails the saved integrity check")
	var broken_graph := document.duplicate(true)
	broken_graph.initial.map.nodes.f01_n0.id = true
	broken_graph.digest = StitchedRunSave._digest(broken_graph)
	_check(StitchedRunSave.restore(broken_graph) == null, "malformed graph rejects atomically even with a valid digest")
	return restored


func _run() -> void:
	var app: Node = await _new_run(42)
	var session: StitchedRunSession = app.stitched_run_session
	if session == null:
		app.free()
		quit(1)
		return
	var restored := _roundtrip(session, "opening map")
	var id: String = session.choices()[0]
	for candidate in session.choices():
		if session.map.get_node(candidate).type == "Fight":
			id = candidate
			break
	_check(_press_route(app, id), "authentic battle mounted before midbattle save")
	var stage: StitchedBattleScreen = app.stitched_run_battle
	_check(stage != null and stage.battle == session.battle, "save test owns a mounted real battle")
	if stage != null:
		_check(_act(stage), "mounted ability and target buttons spend a genuine turn before save")
		restored = _roundtrip(session, "midbattle")
		var path := "user://s6_save_load_test.save"
		_check(StitchedRunSave.write_file(path, session), "versioned run file writes successfully")
		var before := session.snapshot()
		_check(app.load_stitched_run(path), "app publishes fully validated restored battle")
		session = app.stitched_run_session
		stage = app.stitched_run_battle
		_check(session.snapshot() == before and stage.battle == session.battle,
			"mounted reload retains exact turn and resources")
		var result := _win(stage)
		_check(result.acted > 0 and stage.battle.is_over(), "restored mounted controls finish the real fight")
		stage._action_buttons["exit"].pressed.emit()
		restored = _roundtrip(session, "postbattle")
		_check(StitchedRunSave.write_file(path, session), "second Save atomically replaces the existing run file")
		var latest := StitchedRunSave.read_file(path)
		_check(latest != null and latest.snapshot() == session.snapshot(), "repeated Save reloads the latest state")
		DirAccess.remove_absolute(path)
	var visit_id := ""
	for candidate in session.choices():
		if not session.map.get_node(candidate).type in ["Fight", "Elite", "Boss"]:
			visit_id = candidate
			break
	_check(not visit_id.is_empty(), "seed has a genuine pending-visit witness")
	if not visit_id.is_empty():
		_check(_press_route(app, visit_id), "mounted control enters the pending visit")
		restored = _roundtrip(session, "pending visit")
		var actions := session.visit_actions()
		_check(restored != null and not actions.is_empty() and restored.visit_actions() == actions,
			"restored pending visit publishes identical choices")
		for action in actions:
			if restored == null:
				break
			if action.enabled:
				var original_before := session.snapshot()
				_check(session.choose_visit(action.id, action.arguments, original_before), "original visit commits a valid receipt")
				_check(restored.choose_visit(action.id, action.arguments, restored.snapshot()), "reloaded visit commits the same receipt")
				_check(restored.snapshot() == session.snapshot(), "future visit receipts and RNG are deterministic")
				_check(not session.choose_visit(action.id, action.arguments, original_before), "stale visit receipt cannot spend twice")
				break
	for invalid in [null, [], {}, {"version": 999}, {"version": 1, "journal": ["forged"]}]:
		_check(StitchedRunSave.restore(invalid) == null, "malformed save fails closed")
	app.free()
	await process_frame
	for message in failures:
		printerr(message)
	print("stitched_s6_save_load_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
