extends SceneTree
## S8f: real New Run route controls, journaled Walk, and authenticated app-root reload.
var failures: Array[String] = []
var checks := 0

const WALK_SAVE := "user://s8f_app_walk_reload_test.save"
const MAP_SAVE := "user://s8f_app_map_reload_test.save"
const BAD_SAVE := "user://s8f_app_bad_reload_test.save"
const MISSING_SAVE := "user://s8f_app_missing_reload_test.save"


func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)


func _check_host_hud(walker: StitchedWalkScreen, session: StitchedRunSession) -> void:
	_check(walker != null and session != null and session.walk != null and session.phase == "walk",
		"host view checks a real mounted live session")
	if walker == null or session == null or session.walk == null:
		return
	_check(walker.expected == session.walk.snapshot() and walker.candle == session.candle
		and walker.fear() == session.kid_fear(), "hosted Walk reads the current session's walk, candle and fear")


## Count actual app children, not only references that might mask a detached ghost.
func _check_single_view(app: Node, phase: String, label: String) -> void:
	var walkers := 0
	var battles := 0
	var pages := 0
	for child in app.get_children():
		if child is StitchedWalkScreen:
			walkers += 1
		elif child is StitchedBattleScreen:
			battles += 1
		elif child.name == "StitchedRunPage":
			pages += 1
	_check(walkers == (1 if phase == "walk" else 0)
		and battles == (1 if phase == "battle" else 0)
		and pages == (1 if phase not in ["walk", "battle"] else 0),
		label + " has exactly one mounted phase view without ghost surfaces")
	_check((app.stitched_run_walk != null and app.stitched_run_walk.get_parent() == app)
		if phase == "walk" else app.stitched_run_walk == null,
		label + " current walker reference matches its only attached view")
	_check((app.stitched_run_battle != null and app.stitched_run_battle.get_parent() == app)
		if phase == "battle" else app.stitched_run_battle == null,
		label + " current battle reference matches its only attached view")


func _finish(app: Node) -> void:
	if app != null:
		app.free()
	for path in [WALK_SAVE, MAP_SAVE, BAD_SAVE, MISSING_SAVE]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	for failure in failures:
		printerr(failure)
	print("stitched_s8f_app_walk_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	for path in [WALK_SAVE, MAP_SAVE, BAD_SAVE, MISSING_SAVE]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	root.size = Vector2i(1280, 720)
	var app: Node = load("res://scenes/app.tscn").instantiate()
	app.run_seed = 42
	app.stitched_walks = true
	root.add_child(app)
	await process_frame
	app.start_button.pressed.emit()
	await process_frame
	_check(app.stitched_run_panel != null and app.stitched_run_buttons.size() > 0,
		"a real title New Run opens the four-doll picker")
	if app.stitched_run_buttons.is_empty():
		_finish(app)
		return
	app.stitched_run_buttons[0].pressed.emit()
	await process_frame
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.walks_enabled, "New Run opts into Walks")
	if session == null:
		_finish(app)
		return
	var picked: Array = session.picks.duplicate()
	_check(picked.size() == 4 and picked.duplicate().all(func(id): return picked.count(id) == 1)
		and session.map.get_floors().size() == 12, "seed 42 authenticates four distinct heroes and twelve floors")
	_check_single_view(app, "map", "new-run map")
	var opening_map := session.snapshot()
	_check(StitchedRunSave.write_file(MAP_SAVE, session), "an authentic opening-map document is saved")
	var pick := -1
	for index in session.choices().size():
		if session.map.get_node(session.choices()[index]).type != "Boss":
			pick = index
			if session.map.get_node(session.choices()[index]).type == "Fight":
				break
	_check(pick >= 0 and pick < app.stitched_run_buttons.size(),
		"a genuine seed-42 non-Boss ticket is reachable through the app")
	if pick < 0 or pick >= app.stitched_run_buttons.size():
		_finish(app)
		return
	var node_id: String = session.choices()[pick]
	app.stitched_run_buttons[pick].pressed.emit()
	await process_frame
	var walker: StitchedWalkScreen = app.stitched_run_walk
	_check(walker != null and walker.host == session and walker.walk == session.walk and session.phase == "walk",
		"route ticket opens the genuine hosted Walk")
	if walker == null:
		_finish(app)
		return
	_check(not walker.exit_button.visible, "hosted Walk has no title shortcut")
	_check_host_hud(walker, session)
	_check_single_view(app, "walk", "first Walk")
	var pristine := session.walk.snapshot()
	var journal_count := session.journal.size()
	walker.refresh()
	_check(session.walk.snapshot() == pristine and session.journal.size() == journal_count,
		"hosted refresh does not consume RNG, state or journal")
	walker.back_button.pressed.emit()
	_check(session.is_consistent() and session.journal.size() == journal_count + 1
		and session.walk.snapshot().whirr == pristine.whirr + 5 and session.walk.snapshot().looking_back,
		"public LOOK BACK adds exactly five WHIRR and one authenticated command")
	_check_host_hud(walker, session)
	var document := StitchedRunSave.capture(session)
	var saved_snapshot := session.snapshot()
	var saved_journal := session.journal.duplicate(true)
	var saved_rng := session.rng.state
	_check(not document.is_empty() and StitchedRunSave.write_file(WALK_SAVE, session),
		"genuine mid-Walk document writes with digest, RNG and journal")
	_check(StitchedRunSave.read_file(WALK_SAVE) != null, "mid-Walk save validates before publishing")
	var former := walker
	_check(app.load_stitched_run(WALK_SAVE), "app restores the first verified mid-Walk document")
	session = app.stitched_run_session
	walker = app.stitched_run_walk
	_check(session != null and session != former.host and walker != null and walker != former
		and former.get_parent() == null and walker.host == session and walker.walk == session.walk,
		"old walker is detached before the newly bound walker accepts input")
	_check(session.snapshot() == saved_snapshot and session.journal == saved_journal
		and session.rng.state == saved_rng, "first reload exactly preserves map, journal and RNG")
	_check_single_view(app, "walk", "first restore")
	await process_frame
	former = walker
	_check(app.load_stitched_run(WALK_SAVE), "same mid-Walk save reloads a second time")
	session = app.stitched_run_session
	walker = app.stitched_run_walk
	_check(session != null and walker != null and walker != former and former.get_parent() == null
		and walker.host == session, "repeated restore replaces the previous walker, not stacks it")
	_check(session.snapshot() == saved_snapshot and session.journal == saved_journal
		and session.rng.state == saved_rng, "repeated restore creates no ghost command or node")
	_check_single_view(app, "walk", "second restore")
	# A previously mounted UI control is still callable until queue_free flushes.
	# Neither that control nor its completion signal may affect the published run.
	var live_before := session.snapshot()
	var live_journal := session.journal.duplicate(true)
	var live_rng := session.rng.state
	former.forward_button.pressed.emit()
	former.walk_finished.emit()
	_check(app.stitched_run_session == session and app.stitched_run_walk == walker
		and session.snapshot() == live_before and session.journal == live_journal
		and session.rng.state == live_rng, "detached old walker controls and completion cannot mutate the restored run")
	_check_single_view(app, "walk", "stale signal immunity")
	await process_frame

	var untouched := session.snapshot()
	var untouched_journal := session.journal.duplicate(true)
	var untouched_rng := session.rng.state
	_check(not app.load_stitched_run(MISSING_SAVE), "missing save fails closed in a live Walk")
	var corrupt := document.duplicate(true)
	corrupt.digest = "tampered"
	var corrupt_file := FileAccess.open(BAD_SAVE, FileAccess.WRITE)
	_check(corrupt_file != null, "corrupt-save fixture can be written outside the repository")
	if corrupt_file != null:
		corrupt_file.store_buffer(var_to_bytes(corrupt))
		corrupt_file.close()
		_check(not app.load_stitched_run(BAD_SAVE), "corrupt save fails closed in a live Walk")
	app.stitched_event_gate = RunV3FightEventGate.new()
	_check(not app.load_stitched_run(WALK_SAVE), "legacy-mode gate denies Stitched reload")
	app.stitched_event_gate = null
	_check(app.stitched_run_session == session and app.stitched_run_walk == walker
		and walker.get_parent() == app and session.snapshot() == untouched
		and session.journal == untouched_journal and session.rng.state == untouched_rng,
		"all denied reloads retain the exact same active view, snapshot, journal and RNG")
	_check_single_view(app, "walk", "rejected restore")

	var reference := StitchedRunSave.restore(document)
	_check(reference != null and reference.snapshot() == saved_snapshot,
		"one-step oracle is an independent verified restore of the same document")
	if reference != null:
		var reference_walker := StitchedWalkScreen.new()
		_check(reference_walker.attach(reference), "the independent oracle uses the public hosted Walk command")
		var expected_step := reference_walker.command("forward")
		var before_whirr: int = int(session.walk.snapshot().whirr)
		var before_count := session.journal.size()
		walker.forward_button.pressed.emit()
		_check(expected_step.get("ok") == true and session.journal.size() == before_count + 1
			and session.journal.back().action == "walk", "one public forward press commits exactly one Walk command")
		_check(session.snapshot() == reference.snapshot() and session.journal == reference.journal
			and session.rng.state == reference.rng.state, "forward step exactly matches independent replay state, journal and RNG")
		_check(session.walk != null and session.walk.snapshot().whirr == before_whirr,
			"forward adds zero WHIRR")
		_check_host_hud(walker, session)
		reference_walker.free()
	_check_single_view(app, "walk", "post-forward walk")

	_check(app.load_stitched_run(MAP_SAVE), "opening-map save replaces an active Walk")
	session = app.stitched_run_session
	_check(session != null and session.phase == "map" and session.snapshot() == opening_map,
		"map reload returns to the exact pending route authority")
	_check_single_view(app, "map", "map after Walk")
	_check(app.stitched_run_intro == null, "reload leaves no stale opening-story overlay")

	# Take the same authentic route again and carry the live Walk to its node.
	var resumed_pick := session.choices().find(node_id)
	_check(resumed_pick >= 0 and resumed_pick < app.stitched_run_buttons.size(),
		"saved-map route admits the same genuine ticket")
	if resumed_pick >= 0 and resumed_pick < app.stitched_run_buttons.size():
		app.stitched_run_buttons[resumed_pick].pressed.emit()
		await process_frame
		var walked_steps := 0
		while app.stitched_run_walk != null and walked_steps < 40:
			var current: StitchedWalkScreen = app.stitched_run_walk
			var n := session.journal.size()
			current.forward_button.pressed.emit()
			walked_steps += 1
			await process_frame
			if app.stitched_run_walk != null:
				_check(session.is_consistent() and session.journal.size() == n + 1
					and session.journal.back().action == "walk",
					"every live forward command is journaled only once")
		_check(walked_steps > 0 and walked_steps < 40 and app.stitched_run_walk == null
			and session.walk == null and session.phase in ["battle", "visit"],
			"completing an authentic Walk opens exactly its pending battle or visit")
		if session.phase in ["battle", "visit"]:
			var pending_phase: String = session.phase
			_check_single_view(app, pending_phase, "node after Walk")
			var pending_snapshot := session.snapshot()
			var pending_journal := session.journal.duplicate(true)
			var pending_rng := session.rng.state
			_check(StitchedRunSave.write_file(WALK_SAVE, session),
				"genuine pending node creates a verified reload document")
			_check(app.load_stitched_run(WALK_SAVE), "authenticated pending node reload succeeds after Walk")
			_check(app.stitched_run_session != session
				and app.stitched_run_session.snapshot() == pending_snapshot
				and app.stitched_run_session.journal == pending_journal
				and app.stitched_run_session.rng.state == pending_rng,
				"pending node reload preserves the exact authenticated session")
			_check_single_view(app, pending_phase, "reloaded pending node")
			if pending_phase == "battle":
				_check(app.stitched_run_battle != null
					and app.stitched_run_battle.battle == app.stitched_run_session.battle,
					"reloaded battle is bound only to the new session's genuine fight")
			else:
				_check(app.stitched_run_panel != null
					and app.stitched_run_buttons.size() == app.stitched_run_session.visit_actions().size() + 2,
				"reloaded visit has exactly its legal choices and Save/Reload controls")

	# A second genuine ticket covers the other phase: a pending service after a Walk.
	_check(app.load_stitched_run(MAP_SAVE), "a saved map can replace the mounted pending battle or visit")
	session = app.stitched_run_session
	_check_single_view(app, "map", "map after pending-node restore")
	var service_index := -1
	for index in session.choices().size():
		var kind: String = str(session.map.get_node(session.choices()[index]).type)
		if not kind in ["Fight", "Elite", "Boss"]:
			service_index = index
			break
	_check(service_index >= 0, "seed-42 opening map has a genuine noncombat service ticket")
	if service_index >= 0:
		app.stitched_run_buttons[service_index].pressed.emit()
		await process_frame
		_check(app.stitched_run_walk != null and session.phase == "walk",
			"genuine service ticket enters the hosted corridor")
		var service_steps := 0
		while app.stitched_run_walk != null and service_steps < 40:
			var current: StitchedWalkScreen = app.stitched_run_walk
			current.forward_button.pressed.emit()
			service_steps += 1
			await process_frame
		_check(service_steps > 0 and service_steps < 40 and session.phase == "visit"
			and app.stitched_run_walk == null, "service Walk ends in an authenticated pending visit")
		if session.phase == "visit":
			_check_single_view(app, "visit", "visit after Walk")
			var visit_snapshot := session.snapshot()
			var visit_journal := session.journal.duplicate(true)
			var visit_rng := session.rng.state
			_check(StitchedRunSave.write_file(WALK_SAVE, session),
				"pending visit saves from the mounted live run")
			var previous_page: Control = app.stitched_run_panel
			_check(app.load_stitched_run(WALK_SAVE), "app reloads the genuine pending visit")
			_check(app.stitched_run_session != session
				and app.stitched_run_session.snapshot() == visit_snapshot
				and app.stitched_run_session.journal == visit_journal
				and app.stitched_run_session.rng.state == visit_rng
				and previous_page.get_parent() == null,
				"visit restore detaches the prior page and publishes unchanged state, journal and RNG")
			_check_single_view(app, "visit", "reloaded pending visit")
			_check(app.stitched_run_buttons.size() == app.stitched_run_session.visit_actions().size() + 2,
				"restored pending visit has one action set, Save and Reload")
	_finish(app)
