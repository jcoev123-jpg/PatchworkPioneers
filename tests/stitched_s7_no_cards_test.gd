extends "res://tests/stitched_s7_title_continue_test.gd"
## Public S7 post-purge audit. No fabricated card, route, combat or enemy fixtures.
const NO_CARDS_SAVE := "user://stitched_s7_no_cards_test.save"
## Retired card classes that may survive only as dormant declarations or comments.
const LEGACY_CARD_CLASSES := ["CombatDeck", "CombatParty", "CombatEnemies", "CombatBattleResult",
	"RunRestRecovery", "LiveRunCardRewardChoicePanel", "LiveRunTerminalResultPanel"]
const LEGACY_CARD_SCRIPTS := ["combat_deck.gd", "combat_party.gd", "combat_enemies.gd",
	"combat_battle_result.gd", "run_rest_recovery.gd", "live_run_card_reward_choice_panel.gd",
	"live_run_terminal_result_panel.gd"]


func _disabled_click(button: Button) -> void:
	_check(button.is_visible_in_tree() and button.disabled
		and button.focus_mode == Control.FOCUS_NONE,
		"missing-save Continue is mounted but ineligible for a physical mouse press")
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame


func _old_card_surfaces_dormant(app: Node) -> bool:
	# Dormant fields may exist for old regressions, but no old screen or wallet is live.
	if not _no_legacy_wallet(app) or app.party_picker != null or app.reward_choice_panel != null:
		return false
	for node in [app.route_view, app.battle_view, app.shop_view, app.rest_view,
			app.quiet_spool_panel, app.terminal_result_panel]:
		if is_instance_valid(node) and node.is_visible_in_tree():
			return false
	return true


func _tree_nodes(node: Node, into: Array) -> void:
	into.append(node)
	for child in node.get_children():
		_tree_nodes(child, into)


## AC1: source, scene and mounted tree carry no callable or compiled card route.
func _audit_no_card_sources(app: Node) -> void:
	var source := FileAccess.open("res://scripts/app.gd", FileAccess.READ)
	var scene := FileAccess.open("res://scenes/app.tscn", FileAccess.READ)
	var source_text := source.get_as_text() if source != null else ""
	var scene_text := scene.get_as_text() if scene != null else ""
	if source != null:
		source.close()
	if scene != null:
		scene.close()
	_check(not source_text.is_empty() and not scene_text.is_empty(),
		"the real app script and scene are readable, nonempty no-card audit inputs")
	if source_text.is_empty() or scene_text.is_empty():
		return
	var resources := 0
	for line in scene_text.split("\n"):
		if line.begins_with("[ext_resource "):
			resources += 1
	_check(resources == 3 and not scene_text.to_lower().contains("card"),
		"the app scene wires only app, shell and Theme and references no card resource")
	for line in source_text.split("\n"):
		for banned in LEGACY_CARD_CLASSES:
			if not banned in line:
				continue
			var trimmed := line.strip_edges()
			_check(trimmed.begins_with("#") or trimmed.begins_with("var "),
				"purged app source keeps " + banned + " only as a dormant declaration or comment")
			_check(not trimmed.contains(".new(") and not trimmed.contains("preload(")
				and not trimmed.contains("load(") and not trimmed.contains("connect(")
				and not trimmed.contains("func "),
				"no live app source line constructs or wires " + banned)
	_check(not source_text.contains("combat_mode"),
		"the app source exposes no retired combat mode")
	var exposed: Array[String] = []
	for method in app.get_method_list():
		var label := str(method.name)
		if label.to_lower().contains("card") or label == "_start_run" or label == "_open_route":
			exposed.append(label)
	_check(exposed.is_empty(),
		"the compiled app exposes no card or retired route method: " + ", ".join(exposed))
	var nodes: Array = []
	_tree_nodes(app, nodes)
	var hidden: Array[String] = []
	for node in nodes:
		for connection in node.get_incoming_connections():
			var callable: Callable = connection.callable
			if str(callable.get_method()).to_lower().contains("card"):
				hidden.append(str(node.name) + " wires " + str(callable.get_method()))
			var bound: Object = callable.get_object()
			var script: Script = bound.get_script() if bound != null and is_instance_valid(bound) else null
			var path := str(script.resource_path) if script != null else ""
			for banned in LEGACY_CARD_SCRIPTS:
				if path.ends_with("/" + banned):
					hidden.append(str(node.name) + " binds " + banned)
	_check(hidden.is_empty(),
		"the mounted tree wires no hidden card callback or instance: " + ", ".join(hidden))


## A long service list scrolls; a physical mouse press needs its target on screen.
func _scrolled_click(page: Control, button: Button) -> void:
	var scroll: ScrollContainer = page.find_child("RunActionScroll", true, false)
	if scroll != null and button != null:
		scroll.ensure_control_visible(button)
		await process_frame
	await _click(button)


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

	# AC1: no callable or compiled card route survives in source, scene or mounted tree.
	_audit_no_card_sources(app)

	# Genuine keyboard and pointer Continue attempts must not load corrupt/stale state.
	await _disabled_click(app.stitched_continue_button)
	app.stitched_continue_button.pressed.emit()
	_check(app.stitched_run_session == null and app.title_view.is_visible_in_tree()
		and _carry(app) == baseline and _old_card_surfaces_dormant(app),
		"missing-save Continue is atomic on the live mouse callback")
	var file := FileAccess.open(NO_CARDS_SAVE, FileAccess.WRITE)
	_check(file != null, "invalid-save input file can be created")
	if file != null:
		file.store_buffer(var_to_bytes({"version": "invalid", "state": {}}))
		file.close()
	_check(StitchedRunSave.read_file(NO_CARDS_SAVE) == null,
		"malformed journal fixture cannot authenticate a Continue run")
	app._refresh_stitched_continue_eligibility()
	await _ring(app, [app.start_button, app.base_button])
	app.stitched_continue_button.pressed.emit()
	_check(app.stitched_continue_button.disabled
		and app.stitched_continue_button.focus_mode == Control.FOCUS_NONE
		and app.stitched_run_session == null and app.title_view.is_visible_in_tree()
		and _carry(app) == baseline and _old_card_surfaces_dormant(app),
		"malformed-save Continue signal and keyboard ring fail closed without a card route")

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
	# The battle screen is freed on exit, so witness the landed fight before leaving it.
	var fight_landed: bool = stage != null
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

	# The settled map re-runs the purge audit across the whole mounted run tree.
	_audit_no_card_sources(app)

	# The earned victory publicly offers Wren a keepsake; decline it by mouse first.
	if fight_landed:
		var gift_veil: Control = app._wren_gift_pick
		_check(gift_veil != null and gift_veil.is_visible_in_tree(),
			"the earned victory publicly offers the keepsake veil")
		if gift_veil != null:
			var decline: Button = gift_veil.find_child("WrenGiftLeave", true, false)
			_check(decline != null and decline.is_visible_in_tree() and not decline.disabled,
				"the keepsake veil offers a public decline button")
			if decline != null:
				await _click(decline)
				await process_frame
				_check(not is_instance_valid(app._wren_gift_pick)
					and restored.gift_offer.is_empty() and restored.phase == "map"
					and _old_card_surfaces_dormant(app),
					"declining the keepsake closes only its own veil without spending the run")

	# A connected road stop is entered through its physical route button, then left.
	var receipts_before_stop: int = restored.receipts.size()
	var stop_id := ""
	for id in restored.choices():
		if not (restored.map.get_node(id).type in ["Fight", "Elite", "Boss"]):
			stop_id = id
			break
	_check(fight_landed and not stop_id.is_empty(),
		"the settled map offers a genuine non-battle road stop")
	if fight_landed and not stop_id.is_empty():
		var stop_button: Button = app.stitched_run_buttons[restored.choices().find(stop_id)]
		var stop_candle := restored.candle
		await _click(stop_button)
		await process_frame
		var service := str(restored.pending.get("service", ""))
		var stop_page: Control = app.stitched_run_panel
		_check(restored.phase == "visit" and restored.candle == maxi(0, stop_candle - 8)
			and stop_page != null and stop_page.is_visible_in_tree()
			and stop_page.get_meta("page_kind", "") == "visit:" + service
			and _old_card_surfaces_dormant(app),
			"the physical road-stop ticket enters its authenticated corridor visit")
		if stop_page != null:
			var stop_art: TextureRect = stop_page.find_child("StitchedSceneArt", true, false)
			var stop_frame: NinePatchRect = stop_page.find_child("StitchedFeltFrame", true, false)
			_check(stop_art != null and stop_art.texture != null and stop_frame != null
				and stop_frame.texture != null,
				"the stop page keeps authored art inside a stitched felt frame")
		var stop_actions := restored.visit_actions()
		var leave_index := -1
		for index in stop_actions.size():
			if stop_actions[index].id == "leave" and stop_actions[index].enabled:
				leave_index = index
				break
		if leave_index < 0:
			for index in stop_actions.size():
				if stop_actions[index].enabled:
					leave_index = index
					break
		_check(leave_index >= 0 and leave_index < app.stitched_run_buttons.size(),
			"the mounted stop exposes a public enabled leave decision")
		if leave_index >= 0 and leave_index < app.stitched_run_buttons.size():
			await _scrolled_click(stop_page, app.stitched_run_buttons[leave_index])
			await process_frame
			_check(restored.phase == "map" and restored.receipts.size() == receipts_before_stop + 1
				and restored.receipts.back().node_id == stop_id
				and _old_card_surfaces_dormant(app),
				"leaving the stop records exactly one committed visit receipt")

	# Hop onward until a genuine ranked battle is physically offered.
	var battle_id := ""
	for preferred in ["Fight", "Elite", "Boss"]:
		for id in restored.choices():
			if restored.map.get_node(id).type == preferred:
				battle_id = id
				break
		if not battle_id.is_empty():
			break
	var hops := 0
	while battle_id.is_empty() and restored.phase == "map" and hops < 11:
		var next_stop := ""
		for id in restored.choices():
			if not restored.map.get_node(id).type in ["Fight", "Elite", "Boss"]:
				next_stop = id
				break
		if next_stop.is_empty():
			break
		await _click(app.stitched_run_buttons[restored.choices().find(next_stop)])
		await process_frame
		var finish_actions := restored.visit_actions()
		var finish := -1
		for index in finish_actions.size():
			if finish_actions[index].id == "leave" and finish_actions[index].enabled:
				finish = index
				break
		if finish < 0:
			for index in finish_actions.size():
				if finish_actions[index].enabled:
					finish = index
					break
		if finish < 0 or finish >= app.stitched_run_buttons.size():
			break
		await _scrolled_click(app.stitched_run_panel, app.stitched_run_buttons[finish])
		await process_frame
		for preferred in ["Fight", "Elite", "Boss"]:
			for id in restored.choices():
				if restored.map.get_node(id).type == preferred:
					battle_id = id
					break
			if not battle_id.is_empty():
				break
		hops += 1
	_check(not battle_id.is_empty(), "the public road reaches a genuine ranked battle")

	# Losing that battle through public Pass controls reaches the true terminal page.
	if fight_landed and not battle_id.is_empty():
		await _click(app.stitched_run_buttons[restored.choices().find(battle_id)])
		await process_frame
		var loss_stage: StitchedBattleScreen = app.stitched_run_battle
		_check(loss_stage != null and restored.phase == "battle"
			and loss_stage.battle == restored.battle
			and _old_card_surfaces_dormant(app),
			"the physical battle ticket mounts only the authenticated Stitched fight")
		if loss_stage != null:
			var receipts_before_loss: int = restored.receipts.size()
			var turns := 0
			for step in range(800):
				if loss_stage.battle.is_over():
					break
				var previous := loss_stage.receipts.size()
				loss_stage._action_buttons["pass"].pressed.emit()
				if loss_stage.receipts.size() == previous:
					break
				turns += 1
			_check(turns > 0 and loss_stage.battle.outcome() == "defeat",
				"public Pass controls genuinely lose the ranked battle")
			if loss_stage.battle.outcome() == "defeat":
				# The public exit is the corridor's own Continue, not the tucked-away utilities row.
				# The corridor only turns that button visible inside its own _process refresh,
				# so grant the public frames before demanding it.
				var corridor_continue: Button = null
				for _settle_frame in range(6):
					await process_frame
					corridor_continue = loss_stage.find_child("Continue", true, false) as Button
					if corridor_continue != null and corridor_continue.is_visible_in_tree():
						break
				_check(corridor_continue != null and corridor_continue.is_visible_in_tree()
					and not corridor_continue.disabled,
					"the finished battle shows its public Continue action")
				if corridor_continue != null:
					await _click(corridor_continue)
				await process_frame
				var terminal: Control = app.stitched_run_panel
				_check(restored.phase == "defeat"
					and restored.receipts.size() == receipts_before_loss + 1
					and restored.receipts.back().node_id == battle_id
					and terminal != null and terminal.is_visible_in_tree()
					and terminal.get_meta("page_kind", "") == "defeat"
					and _old_card_surfaces_dormant(app),
					"settle records the lost battle and mounts the defeat terminal")
				if terminal != null:
					var terminal_heading := terminal.find_child("StitchedPageHeading", true, false) as Label
					_check(terminal_heading != null
						and "THE THREAD HAS FALLEN / DEFEAT" in terminal_heading.text,
						"the terminal page shows the authentic defeat heading")
					_check(terminal.find_child("TerminalRecap", true, false) != null,
						"the terminal page keeps its felt recap panel")
					var return_button: Button
					for button in app.stitched_run_buttons:
						if button.text == "Return to title":
							return_button = button
							break
					_check(return_button != null and return_button.is_visible_in_tree(),
						"the defeat terminal offers a public Return to title action")
					if return_button != null:
						await _click(return_button)
						await process_frame
						_check(app.stitched_run_session == null
							and app.title_view.is_visible_in_tree()
							and not app.stitched_continue_button.disabled
							and _old_card_surfaces_dormant(app),
							"Return to title retires the lost run and leaves Continue eligible")
						var saved_night := StitchedRunSave.read_file(NO_CARDS_SAVE)
						_check(saved_night != null and saved_night.snapshot() == first_snapshot,
							"the lost side route never overwrote the saved night")
						await _click(app.start_button)
						var fresh_picker: Control = app.stitched_run_panel
						_check(fresh_picker != null and app.stitched_run_session == null
							and fresh_picker.get_meta("page_kind", "") == "picker",
							"post-defeat New Run mounts the public picker")
						if fresh_picker != null and app.stitched_run_buttons.size() > 0:
							await _click(app.stitched_run_buttons[0])
							await process_frame
							var fresh: StitchedRunSession = app.stitched_run_session
							_check(fresh != null and fresh != restored and fresh.candle == 100
								and fresh.map.get_route().is_empty()
								and fresh.receipts.is_empty() and fresh.is_consistent()
								and _old_card_surfaces_dormant(app),
								"a fresh New Run restarts Stitched-only from candle 100")
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
