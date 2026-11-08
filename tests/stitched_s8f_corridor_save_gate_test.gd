extends SceneTree
## S8f rescue: real title -> Event Walk -> Leave -> Fight Walk -> corridor Save -> title Continue.
const TEST_SAVE := "user://stitched_s8f_corridor_save_gate_test.save"
const EVENT_KIND := "Event"
const FIGHT_KIND := "Fight"
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, explanation: String) -> void:
	checks += 1
	if not condition:
		failures.append(explanation)


func _press(button: BaseButton, label: String) -> bool:
	var usable := is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled
	_check(usable, "mounted, enabled player control: " + label)
	if usable:
		button.pressed.emit()
	return usable


func _app(seed_number: int) -> Node:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	app.run_seed = seed_number
	app.stitched_walks = true
	app.stitched_save_path = TEST_SAVE
	root.add_child(app)
	return app


func _find_ticket(app: Node, kind: String) -> Button:
	var session: StitchedRunSession = app.stitched_run_session
	if session == null or session.phase != "map":
		return null
	for button: Button in app.stitched_run_buttons:
		var node_id := str(button.get_meta("route_id", ""))
		if session.choices().has(node_id) and str(session.map.get_node(node_id).type) == kind:
			return button
	return null


func _walk_to_stop(app: Node, node_id: String, ordinal: int) -> void:
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.phase == "walk" and session.walk != null,
		"Walk %d is an authenticated mounted route" % ordinal)
	if session == null or session.walk == null or app.stitched_run_walk == null:
		return
	var walker: StitchedWalkScreen = app.stitched_run_walk
	_check(walker.host == session and walker.walk == session.walk and walker.is_visible_in_tree(),
		"Walk %d uses the real hosted Walk screen" % ordinal)
	var previous_journal := session.journal.size()
	var steps := 0
	while app.stitched_run_walk != null and steps < 40:
		steps += 1
		var old_count := session.journal.size()
		var old_walker: StitchedWalkScreen = app.stitched_run_walk
		if not _press(old_walker.forward_button, "Walk %d forward / tug %d" % [ordinal, steps]):
			break
		await process_frame
		var new_entries: Array = session.journal.slice(old_count)
		var step_journaled: bool = (not new_entries.is_empty() and new_entries[0] is Dictionary
			and new_entries[0].get("action") == "walk"
			and str(new_entries[0].get("command", {}).get("kind", "")) in ["forward", "tug"])
		var legitimate_fight_open := true
		for entry in new_entries.slice(1):
			legitimate_fight_open = (legitimate_fight_open and session.phase == "battle"
				and entry is Dictionary and entry.get("action") == "battle")
		_check(step_journaled and legitimate_fight_open,
			"Walk %d step %d journals forward/tug first; any follow-on actions begin real combat" % [ordinal, steps])
	_check(steps > 0 and steps < 40 and app.stitched_run_walk == null
		and session.walk == null and session.phase in ["visit", "battle"],
		"Walk %d reaches a real Event/Fight stop" % ordinal)
	_check(session.journal.size() > previous_journal
		and session.walk_receipts.size() == ordinal
		and str(session.walk_receipts.back().get("node_id", "")) == node_id,
		"Walk %d journals its route and publishes its own stop receipt" % ordinal)

## Save a real partially traversed corridor, then independently Continue it from
## a fresh title. Both mounted buttons must make the same next seeded command.
func _walk_save_replay(app: Node) -> void:
	var session: StitchedRunSession = app.stitched_run_session
	var walker: StitchedWalkScreen = app.stitched_run_walk
	_check(is_instance_valid(walker) and walker.walk == session.walk
		and session.walk.snapshot().step == 0, "mid-Walk witness starts on a real opening step")
	if not is_instance_valid(walker) or not _press(walker.forward_button, "mid-Walk first forward"):
		return
	await process_frame
	_check(session.phase == "walk" and session.walk != null and session.is_consistent(),
		"mid-Walk save is taken after a committed player step, not at entry")
	if session.phase != "walk":
		return
	var before := session.snapshot()
	var journal := session.journal.duplicate(true)
	var receipts := session.receipts.duplicate(true)
	var walks := session.walk_receipts.duplicate(true)
	_check(StitchedRunSave.write_file(TEST_SAVE, session),
		"authoritative Save writes an independently loadable mid-Walk document")
	var stored := StitchedRunSave.read_file(TEST_SAVE)
	_check(stored != null and stored.snapshot() == before and stored.journal == journal
		and stored.receipts == receipts and stored.walk_receipts == walks
		and stored.rng.state == before.rng,
		"mid-Walk Save preserves party, pending node, pockets, ledger, receipts, RNG")
	var fresh := _app(999)
	await process_frame
	await process_frame
	if not _press(fresh.stitched_continue_button, "separate title Continue mid-Walk"):
		fresh.free()
		return
	await process_frame
	var restored: StitchedRunSession = fresh.stitched_run_session
	_check(restored != null and restored != session and restored.phase == "walk"
		and restored.snapshot() == before and restored.journal == journal
		and restored.receipts == receipts and restored.walk_receipts == walks
		and is_instance_valid(fresh.stitched_run_walk)
		and fresh.stitched_run_walk.walk == restored.walk, "title Continue mounts exact mid-Walk state")
	if restored != null and restored.phase == "walk" and session.phase == "walk":
		var baseline_walk := session.journal.size()
		var first: StitchedWalkScreen = app.stitched_run_walk
		var second: StitchedWalkScreen = fresh.stitched_run_walk
		_check(first.walk.tug_unresolved() == second.walk.tug_unresolved(),
			"next seeded Walk command has identical preconditions")
		_press(first.forward_button, "uninterrupted next Walk command")
		_press(second.forward_button, "reloaded next Walk command")
		await process_frame
		_check(session.journal.size() == baseline_walk + 1
			and restored.snapshot() == session.snapshot()
			and restored.journal == session.journal
			and restored.receipts == session.receipts
			and restored.walk_receipts == session.walk_receipts
			and restored.rng.state == session.rng.state and session.is_consistent(),
			"independent next public Walk step reproduces state, pocket budgets, receipt and RNG")
	fresh.free()
	await process_frame


func _corridors(app: Node) -> Array:
	return app.find_children("CorridorFight", "Control", true, false)


func _check_fight(app: Node, session: StitchedRunSession, label: String) -> void:
	var matches := _corridors(app)
	var stage: StitchedBattleScreen = app.stitched_run_battle
	_check(session != null and session.phase == "battle" and session.battle != null
		and session.battle_config is Dictionary and not session.battle_config.is_empty(),
		label + ": session holds a configured live battle")
	_check(matches.size() == 1 and is_instance_valid(stage) and stage.is_inside_tree()
		and stage.battle == session.battle and stage.is_visible_in_tree(),
		label + ": exactly one visible mounted corridor fight has the live session battle")
	if matches.size() == 1 and is_instance_valid(stage):
		var corridor: StitchedCorridorFight = matches[0] as StitchedCorridorFight
		_check(corridor != null and corridor.engine == stage
			and corridor.battle == session.battle and corridor.is_visible_in_tree()
			and stage.get_parent() == app,
			label + ": corridor view wraps the actual gameplay engine")


func _write_document(document: Variant) -> void:
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	_check(file != null, "isolated negative save opens for write")
	if file != null:
		file.store_buffer(var_to_bytes(document))
		file.close()


func _rejection(app: Node, reference: StitchedRunSession, expected: Dictionary,
		label: String) -> void:
	var stage: StitchedBattleScreen = app.stitched_run_battle
	var corridor: Node = _corridors(app)[0] if _corridors(app).size() == 1 else null
	var before := reference.journal.duplicate(true)
	_check(not app.load_stitched_run(TEST_SAVE), label + ": public load rejects document")
	_check(app.stitched_run_session == reference and reference.snapshot() == expected
		and reference.journal == before and reference.rng.state == expected.rng
		and reference.is_consistent(), label + ": rejected load preserves authentic run, wallet and RNG")
	_check(app.stitched_run_battle == stage and _corridors(app).size() == 1
		and _corridors(app)[0] == corridor and not app.title_view.visible,
		label + ": rejection never replaces or duplicates the mounted corridor fight")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute(TEST_SAVE)
	DirAccess.remove_absolute(TEST_SAVE + ".tmp")
	var app := _app(53)
	await process_frame
	await process_frame
	_check(app.title_view.is_visible_in_tree() and app.stitched_run_session == null,
		"fresh 1280x720 title has no run or corridor fight")
	_check(app.stitched_continue_button.is_visible_in_tree()
		and app.stitched_continue_button.disabled
		and app.stitched_continue_button.focus_mode == Control.FOCUS_NONE,
		"missing title Continue is visible but disabled and unfocusable")
	app.stitched_continue_button.pressed.emit()
	_check(app.stitched_run_session == null and app.title_view.visible
		and _corridors(app).is_empty(),
		"missing title Continue signal fails closed without creating a session or fight")
	_write_document({"version": "malformed", "state": {}})
	_check(StitchedRunSave.read_file(TEST_SAVE) == null,
		"malformed save is rejected by the authoritative reader")
	app._refresh_stitched_continue_eligibility()
	_check(app.stitched_continue_button.disabled
		and app.stitched_continue_button.focus_mode == Control.FOCUS_NONE,
		"malformed title Continue stays disabled and unfocusable")
	app.stitched_continue_button.pressed.emit()
	_check(app.stitched_run_session == null and app.title_view.visible
		and _corridors(app).is_empty(),
		"malformed title Continue signal fails closed without publishing a run or fight")
	DirAccess.remove_absolute(TEST_SAVE)
	if not _press(app.start_button, "New Run"):
		_finish(app)
		return
	await process_frame
	_check(app.stitched_run_session == null and app.stitched_run_buttons.size() == 2,
		"New Run exposes the real four-doll picker")
	if app.stitched_run_buttons.is_empty() or not _press(app.stitched_run_buttons[0], "four-doll Set out"):
		_finish(app)
		return
	await process_frame
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.heroes.size() == 4 and session.walks_enabled
		and session.picks.size() == 4 and session.seed_value == 53,
		"real four selected dolls start seed 53 with Walks")
	if session == null:
		_finish(app)
		return
	var intro: Control = app.stitched_run_intro
	var begin: Button = intro.find_child("WrenIntroBegin", true, false) as Button if is_instance_valid(intro) else null
	_check(intro != null and intro.is_visible_in_tree(), "intro is mounted before the first ticket")
	_press(begin, "intro Begin the night")
	await process_frame
	_check(app.stitched_run_intro == null and session.phase == "map",
		"intro dismissal reveals authentic legal tickets")
	var event_ticket := _find_ticket(app, EVENT_KIND)
	_check(event_ticket != null and str(event_ticket.get_meta("route_id", "")) in session.choices(),
		"seed 53 offers a legal Event ticket")
	if event_ticket == null:
		_finish(app)
		return
	var event_id := str(event_ticket.get_meta("route_id"))
	_press(event_ticket, "legal Event ticket")
	await process_frame
	_check(session.phase == "walk" and session.pending.node_id == event_id
		and str(session.pending.kind) == EVENT_KIND and session.journal.back().action == "enter",
		"Event ticket enters via live Walk and journals its exact node")
	await _walk_save_replay(app)
	await _walk_to_stop(app, event_id, 1)
	if session.phase != "visit":
		_finish(app)
		return
	_check(session.pending.node_id == event_id and session.pending.service == "Event",
		"Event Walk arrives at actual live event service")
	var leave: Button
	for button: Button in app.stitched_run_buttons:
		if str(button.get_meta("action_id", "")) in ["leave", "decline_trade", "leave_rookery", "leave_chapel"] and not button.disabled:
			leave = button
			break
	_check(leave != null, "Event offers enabled Leave / decline without spending")
	if leave == null:
		_finish(app)
		return
	var event_exit_id := str(leave.get_meta("action_id"))
	var wallet_before := [session.gold, session.scraps, session.candle, session.rng.state]
	var walk_receipts_before := session.walk_receipts.duplicate(true)
	_press(leave, "Event Leave")
	await process_frame
	_check(session.phase == "map" and session.journal.back().action == "visit"
		and session.journal.back().id == event_exit_id and session.walk_receipts == walk_receipts_before
		and [session.gold, session.scraps, session.candle, session.rng.state] == wallet_before,
		"public Leave journals event resolution, with prior Walk receipt intact")
	var fight_ticket := _find_ticket(app, FIGHT_KIND)
	_check(fight_ticket != null, "Event Leave unlocks a legal Fight ticket")
	if fight_ticket == null:
		_finish(app)
		return
	var fight_id := str(fight_ticket.get_meta("route_id"))
	_check(session.choices().has(fight_id), "fight ticket is among generated legal choices")
	_press(fight_ticket, "legal Fight ticket")
	await process_frame
	_check(session.phase == "walk" and session.pending.node_id == fight_id
		and str(session.pending.kind) == "Fight" and session.journal.back().action == "enter",
		"Fight ticket journals entry into a second distinct hosted Walk")
	await _walk_to_stop(app, fight_id, 2)
	_check_fight(app, session, "after second Walk")
	if app.stitched_run_battle == null or _corridors(app).size() != 1:
		_finish(app)
		return
	var corridor: StitchedCorridorFight = _corridors(app)[0] as StitchedCorridorFight
	_check(corridor.more_buttons.has("save"), "mounted corridor exposes More > Save run")
	_press(corridor.more_button, "corridor More")
	_check(corridor.more_panel.visible and corridor.more_buttons["save"].is_visible_in_tree(),
		"player opens the active More panel containing Save run")
	_press(corridor.more_buttons["save"], "corridor More > Save run")
	_check(FileAccess.file_exists(TEST_SAVE), "corridor Save creates isolated run file")
	var before := session.snapshot()
	var journal := session.journal.duplicate(true)
	var preserved_receipts := session.receipts.duplicate(true)
	var preserved_walks := session.walk_receipts.duplicate(true)
	var captured := StitchedRunSave.read_file(TEST_SAVE)
	_check(captured != null and captured.snapshot() == before and captured.journal == journal
		and captured.receipts == preserved_receipts and captured.walk_receipts == preserved_walks
		and captured.rng.state == session.rng.state,
		"corridor Save replays complete party, Fight, hand budget, fear, wallet, receipts and RNG")
	var hand_before := session.journal.size()
	_check(corridor.hand_buttons.has("shield_candle"), "actual corridor displays Wren's Shield hand")
	if corridor.hand_buttons.has("shield_candle"):
		_press(corridor.hand_buttons["shield_candle"], "Wren Shield the Candle on uninterrupted Fight")
	var hand_after := session.snapshot()
	var hand_journal := session.journal.duplicate(true)
	_check(session.journal.size() == hand_before + 1
		and session.journal.back().get("method") == "use_hand_action"
		and session.journal.back().get("arguments", [])[0] == "shield_candle"
		and session.is_consistent(), "Wren's genuine hand commits one budgeted battle receipt")
	app.free()
	await process_frame
	var fresh := _app(999)
	await process_frame
	await process_frame
	_check(fresh.title_view.is_visible_in_tree() and fresh.stitched_run_session == null
		and _corridors(fresh).is_empty(), "fresh independent title starts with no mounted battle")
	_press(fresh.stitched_continue_button, "fresh title Continue")
	await process_frame
	var resumed: StitchedRunSession = fresh.stitched_run_session
	_check(resumed != null and resumed != session and not fresh.title_view.visible
		and resumed.snapshot() == before and resumed.journal == journal and resumed.rng.state == before.rng,
		"fresh Continue restores exact snapshot, journal, RNG and genuine seeded run")
	if resumed == null:
		_finish(fresh)
		return
	_check(resumed.heroes == before.heroes and resumed.pending == before.pending
		and resumed.candle == before.candle and resumed.kid_fear() == before.kid_fear.fear
		and resumed.gold == before.gold and resumed.scraps == before.scraps
		and resumed.battle.state_snapshot() == before.battle and resumed.journal == journal,
		"explicit party, pending Fight, resources, fear, battle and journal equal saved values")
	_check_fight(fresh, resumed, "after fresh title Continue")
	if _corridors(fresh).size() == 1:
		var reloaded_fight: StitchedCorridorFight = _corridors(fresh)[0]
		_check(reloaded_fight.hand_buttons.has("shield_candle"),
			"restored Fight exposes the same Wren hand")
		if reloaded_fight.hand_buttons.has("shield_candle"):
			_press(reloaded_fight.hand_buttons["shield_candle"], "Wren Shield the Candle after Fight reload")
		_check(resumed.snapshot() == hand_after and resumed.journal == hand_journal
			and resumed.receipts == preserved_receipts and resumed.walk_receipts == preserved_walks
			and resumed.rng.state == hand_after.rng and resumed.is_consistent(),
			"independent next Wren hand command reproduces exact Fight state, budget, journal and RNG")
	if _corridors(fresh).size() == 1:
		var preserved := resumed.snapshot()
		DirAccess.remove_absolute(TEST_SAVE)
		_rejection(fresh, resumed, preserved, "missing file during legitimate battle")
		_write_document({"version": "malformed", "state": {}})
		_rejection(fresh, resumed, preserved, "malformed file during legitimate battle")
		var forged := StitchedRunSave.capture(resumed)
		_check(not forged.is_empty(), "authenticated save document exists before forgery")
		if not forged.is_empty():
			forged.state.candle = maxi(0, int(forged.state.candle) - 1)
			forged.digest = StitchedRunSave._digest(forged)
			_write_document(forged)
			_rejection(fresh, resumed, preserved, "rehashed forged document")
	_finish(fresh)


func _finish(app: Node) -> void:
	if is_instance_valid(app):
		app.free()
	DirAccess.remove_absolute(TEST_SAVE)
	DirAccess.remove_absolute(TEST_SAVE + ".tmp")
	for failure in failures:
		printerr(failure)
	print("stitched_s8f_corridor_save_gate_test: %s (%d checks, %d failures)" %
		["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
