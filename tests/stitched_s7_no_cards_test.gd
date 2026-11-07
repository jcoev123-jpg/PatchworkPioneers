extends "res://tests/stitched_s7_title_continue_test.gd"
## Public S7 post-purge audit. No fabricated card, route, combat or enemy fixtures.
const NO_CARDS_SAVE := "user://stitched_s7_no_cards_test.save"


func _old_card_surfaces_dormant(app: Node) -> bool:
	# Dormant fields may exist for old regressions, but no old screen or wallet is live.
	if not _no_legacy_wallet(app) or app.party_picker != null or app.reward_choice_panel != null:
		return false
	for node in [app.route_view, app.battle_view, app.shop_view, app.rest_view,
			app.quiet_spool_panel, app.terminal_result_panel]:
		if is_instance_valid(node) and node.is_visible_in_tree():
			return false
	return true


func _opening_fight(session: StitchedRunSession) -> String:
	if session == null or session.phase != "map" or session.choices().is_empty():
		return ""
	for id in session.choices():
		if session.map.get_node(id).type == "Fight":
			return id
	return ""


func _enter_public_fight(app: Node, session: StitchedRunSession, id: String) -> StitchedBattleScreen:
	var options := session.choices()
	_check(not id.is_empty() and options.has(id) and app.stitched_run_buttons.size() >= options.size(),
		"an authenticated public map ticket offers an opening Fight")
	if id.is_empty() or not options.has(id):
		return null
	var index := options.find(id)
	var ticket: Button = app.stitched_run_buttons[index]
	_check(ticket != null and ticket.is_visible_in_tree() and not ticket.disabled
		and ticket.get_meta("route_id", "") == id,
		"the real routed Fight button is enabled and matches its map node")
	await _click(ticket)
	await process_frame
	var stage: StitchedBattleScreen = app.stitched_run_battle
	_check(stage != null and stage.battle == session.battle and session.phase == "battle"
		and app.stitched_fight_view == null and app.stitched_event_panel == null,
		"public routed Fight mounts only the authenticated Stitched battle")
	return stage


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute(NO_CARDS_SAVE)
	var app: Node = load("res://scenes/app.tscn").instantiate()
	app.run_seed = 42
	app.stitched_walks = false
	app.stitched_save_path = NO_CARDS_SAVE
	root.add_child(app)
	await process_frame
	await process_frame
	var baseline := _carry(app)
	_check(app.title_view.is_visible_in_tree() and app.stitched_run_session == null
		and _old_card_surfaces_dormant(app), "fresh public boot has no active legacy cards or spending")
	_check([app.start_button.text, app.stitched_continue_button.text, app.base_button.text] ==
		["New Run", "Continue Run", "Wren's Room"],
		"the three visible title actions use consistent title case")

	# Genuine keyboard and pointer Continue attempts must not load corrupt/stale state.
	await _click(app.stitched_continue_button)
	_check(app.stitched_run_session == null and app.title_view.is_visible_in_tree()
		and _carry(app) == baseline and _old_card_surfaces_dormant(app),
		"missing-save Continue is atomic on the live mouse callback")
	var file := FileAccess.open(NO_CARDS_SAVE, FileAccess.WRITE)
	_check(file != null, "invalid-save input file can be created")
	if file != null:
		file.store_buffer(var_to_bytes({"version": "invalid", "state": {}}))
		file.close()
	app.stitched_continue_button.grab_focus()
	await _physical(KEY_SPACE)
	_check(app.stitched_run_session == null and app.title_view.is_visible_in_tree()
		and _carry(app) == baseline and _old_card_surfaces_dormant(app),
		"malformed-save Continue is atomic on the live keyboard callback")

	# Wren's room replaces rather than exposes the hidden retired card Path panels.
	await _click(app.base_button)
	var room: BaseScreen = app.base_screen
	_check(room != null and room.has_open_village() and room.bedroom != null
		and room.bedroom.is_visible_in_tree() and _old_card_surfaces_dormant(app),
		"room action reaches the authentic mounted bedroom, not a retired card scene")
	if room != null:
		var retired_visible := false
		for control in [room.path_panel, room.tinker_panel, room.warden_panel]:
			retired_visible = retired_visible or (is_instance_valid(control) and control.is_visible_in_tree())
		for control in room.path_buttons + room.tinker_buttons + room.warden_buttons:
			retired_visible = retired_visible or (is_instance_valid(control) and control.is_visible_in_tree())
		_check(not retired_visible, "bedroom does not publish any retired card-Path button")
		await _click(room.back_button)
	_check(app.base_screen == null and app.title_view.is_visible_in_tree()
		and app.base_button.has_focus() and _carry(app) == baseline
		and _old_card_surfaces_dormant(app), "room Back restores an untouched card-free title")

	# Set out through original public buttons; do not inject a session or a battle.
	await _click(app.start_button)
	_check(app.stitched_run_panel != null and app.stitched_run_session == null
		and app.stitched_run_draft.size() == 4 and _old_card_surfaces_dormant(app),
		"New Run publicly mounts a four-doll picker without a retired deck")
	if app.stitched_run_panel == null:
		app.free()
		DirAccess.remove_absolute(NO_CARDS_SAVE)
		_finish()
		return
	await _click(app.stitched_run_buttons[0])
	await process_frame
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.heroes.size() == 4 and session.is_consistent(),
		"public Set out constructs four authenticated Stitched heroes")
	if session == null:
		app.free()
		DirAccess.remove_absolute(NO_CARDS_SAVE)
		_finish()
		return
	var intro: Control = app.stitched_run_intro
	_check(intro != null and intro.is_visible_in_tree(), "the real Wren intro overlays the first map page")
	if intro != null:
		var begin := intro.find_child("WrenIntroBegin", true, false) as Button
		_check(begin != null and begin.is_visible_in_tree(), "the public intro has an actionable Begin button")
		if begin != null:
			await _click(begin)
	_check(app.stitched_run_intro == null and session.phase == "map"
		and _old_card_surfaces_dormant(app), "public Begin reveals the card-free routed map")
	var first_snapshot := session.snapshot()
	var first_id := _opening_fight(session)
	_check(not first_id.is_empty() and session.choices().has(first_id),
		"real seeded map has a reachable, non-vacuous opening Fight")
	var save_action: Button
	for button in app.stitched_run_buttons:
		if button.text == "Save run":
			save_action = button
			break
	_check(save_action != null and save_action.is_visible_in_tree(),
		"the real map exposes its own public Save run button")
	if save_action != null:
		await _click(save_action)
	_check(FileAccess.file_exists(NO_CARDS_SAVE)
		and session.snapshot() == first_snapshot and _old_card_surfaces_dormant(app),
		"public Save run is exact and does not charge or mount a card route")

	# Return to title is existing S7 test seam; Continue itself is physical/public.
	app._return_stitched_run_title()
	await process_frame
	_check(app.stitched_run_session == null and app.title_view.is_visible_in_tree()
		and _old_card_surfaces_dormant(app), "return clears only the current run instance")
	app.stitched_continue_button.grab_focus()
	await _physical(KEY_ENTER)
	var restored: StitchedRunSession = app.stitched_run_session
	_check(restored != null and restored != session and restored.snapshot() == first_snapshot
		and restored.is_consistent() and _old_card_surfaces_dormant(app),
		"public Continue restores exact save, seed, RNG and new session identity")
	if restored == null:
		app.free()
		DirAccess.remove_absolute(NO_CARDS_SAVE)
		_finish()
		return
	var before_stale := restored.snapshot()
	app.stitched_continue_button.pressed.emit()
	app.stitched_fight_button.pressed.emit()
	_check(app.stitched_run_session == restored and restored.snapshot() == before_stale
		and _old_card_surfaces_dormant(app),
		"hidden stale Continue and retired Fight shortcut cannot replace or spend the session")
	var stage: StitchedBattleScreen = await _enter_public_fight(app, restored, first_id)
	var first_end: Dictionary = {}
	var first_receipts: Array = []
	if stage != null:
		_check(_old_card_surfaces_dormant(app) and stage.battle.get_heroes().size() == 4
			and stage.battle.get_foes().size() > 0,
			"the routed mounted Fight has real combatants but no old hand/panels/ledger")
		var combat := _win(stage)
		_check(combat.acted > 0 and combat.outcome == "victory"
			and not combat.receipts.is_empty() and _old_card_surfaces_dormant(app),
			"legal sewn-on body-part abilities defeat real seeded foes without card spending")
		first_end = combat.end
		stage._action_buttons["exit"].pressed.emit()
		await process_frame
		first_receipts = restored.receipts.duplicate(true)
		_check(first_receipts.size() == 1 and first_receipts[0].node_id == first_id
			and _old_card_surfaces_dormant(app), "routed settlement records only the admitted Fight receipt")
	app.free()
	await process_frame

	# Recreate a different App and replay the SAME public Continue route and battle.
	var replay: Node = load("res://scenes/app.tscn").instantiate()
	replay.run_seed = 42
	replay.stitched_walks = false
	replay.stitched_save_path = NO_CARDS_SAVE
	root.add_child(replay)
	await process_frame
	await process_frame
	await _click(replay.stitched_continue_button)
	var replay_session: StitchedRunSession = replay.stitched_run_session
	_check(replay_session != null and replay_session.snapshot() == first_snapshot
		and _old_card_surfaces_dormant(replay), "same-seed second public Continue restores exact prior save")
	if replay_session != null:
		var replay_stage: StitchedBattleScreen = await _enter_public_fight(replay, replay_session, first_id)
		if replay_stage != null:
			var repeated := _win(replay_stage)
			_check(repeated.acted > 0 and repeated.outcome == "victory"
				and repeated.end == first_end and _old_card_surfaces_dormant(replay),
				"replayed live abilities and RNG reproduce the exact ranked battle")
			replay_stage._action_buttons["exit"].pressed.emit()
			await process_frame
			_check(replay_session.receipts == first_receipts and first_receipts.size() > 0
				and _old_card_surfaces_dormant(replay),
				"independent public replay settles the same nonempty receipt without legacy route")
	replay.free()
	DirAccess.remove_absolute(NO_CARDS_SAVE)
	await process_frame
	_finish()


func _finish() -> void:
	for problem in failures:
		printerr(problem)
	print("stitched_s7_no_cards_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
