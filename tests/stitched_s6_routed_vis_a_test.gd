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
	var old_route_button: Button = app.stitched_run_buttons[route_choices.find(node_id)]
	var initial := session.snapshot()
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
