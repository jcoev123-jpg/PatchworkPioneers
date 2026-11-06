extends "res://tests/stitched_s6_followon_foes_live_test.gd"
## Real New Run controls, connected map choices and legal ranked abilities.


func _new_run(seed_number: int) -> Node:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	app.run_seed = seed_number
	root.add_child(app)
	await process_frame
	app.start_button.pressed.emit()
	await process_frame
	_check(app.stitched_run_panel != null and app.stitched_run_session == null,
		"New Run mounts the four-of-eight picker before creating ledgers")
	if app.stitched_run_buttons.is_empty():
		return app
	app.stitched_run_buttons[0].pressed.emit()
	await process_frame
	_check(app.stitched_run_session != null, "Set out authenticates the selected four")
	return app


func _press_route(app: Node, id: String) -> bool:
	var session: StitchedRunSession = app.stitched_run_session
	var choices := session.choices()
	var index := choices.find(id)
	if index < 0 or index >= app.stitched_run_buttons.size():
		return false
	app.stitched_run_buttons[index].pressed.emit()
	return session.map.get_current_node_id() == id


func _finish_visit(app: Node) -> bool:
	var session: StitchedRunSession = app.stitched_run_session
	var actions := session.visit_actions()
	var selected := -1
	for preferred in ["mend", "trim_the_wick", "tell_tales", "leave"]:
		for index in actions.size():
			if actions[index].id == preferred and actions[index].enabled:
				selected = index
				break
		if selected >= 0:
			break
	if selected < 0:
		for index in actions.size():
			if actions[index].enabled:
				selected = index
				break
	if selected < 0:
		return false
	app.stitched_run_buttons[selected].pressed.emit()
	return true


func _run() -> void:
	var app: Node = await _new_run(42)
	var session: StitchedRunSession = app.stitched_run_session
	if session == null:
		app.free()
		quit(1)
		return
	_check(session.heroes.size() == 4 and session.map.get_floors().size() == 12,
		"four real equipped heroes and twelve generated floors")
	var before := session.snapshot()
	_check(not session.enter("forged", before) and session.snapshot() == before,
		"forged node cannot spend candle, mutate route or draw RNG")
	var choice: String = session.choices()[0]
	for id in session.choices():
		if session.map.get_node(id).type == "Fight":
			choice = id
			break
	_check(_press_route(app, choice), "mounted route button enters authentic opening")
	_check(session.candle == 92, "one candle charge at entry")
	if app.stitched_run_battle != null:
		var stage: StitchedBattleScreen = app.stitched_run_battle
		_check(stage.battle == session.battle and stage.battle.get_foes().size() in [2, 3],
			"mounted ranked battle borrows the session's actual rules authority")
		var entered := session.snapshot()
		stage._action_buttons["exit"].pressed.emit()
		_check(session.snapshot() == entered and session.receipts.is_empty(),
			"unwon exit cannot publish a receipt or rewards")
		var result := _win(stage)
		_check(result.acted > 0 and stage.battle.is_over(), "public part and target buttons resolve genuine turns")
		stage._action_buttons["exit"].pressed.emit()
	_check(session.receipts.size() == 1, "one authentic opening receipt")
	_complete_route(app)
	_check(session.phase == "victory" and session.map.get_route().size() == 12,
		"seeded public-control route completes twelve floors and wins")
	_check(session.receipts.size() == 12, "one settled receipt per entered floor")
	var bosses := 0
	for receipt in session.receipts:
		if receipt.kind == "Boss":
			bosses += 1
	_check(bosses == 1, "one final Boss receipt")
	_check(app.stitched_run_panel != null,
		"terminal result is mounted")
	var recap_rows: Node = app.stitched_run_panel.find_child("FourHeroRecaps", true, false)
	_check(recap_rows != null and recap_rows.get_child_count() == 4, "four accurate terminal hero rows are mounted")
	var saved := StitchedRunSave.restore(StitchedRunSave.capture(session))
	_check(saved != null and saved.snapshot() == session.snapshot(), "victory reload preserves the settled run")
	print("S6 final phase ", session.phase, " floors ", session.map.get_current_floor(), " receipts ", session.receipts.size())
	app.free()
	await process_frame
	await _exercise_defeat()
	await _exercise_stop_kinds()
	await _exercise_partial_carry()
	await _exercise_picker()
	await _exercise_village_entry()
	for message in failures:
		printerr(message)
	print("stitched_s6_full_run_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


## Fresh public title and village actions cannot expose the retired three-card route.
func _exercise_village_entry() -> void:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	_check(not app.route_button.is_visible_in_tree() and app.route_button.disabled
		and app.route_button.focus_mode == Control.FOCUS_NONE
		and app.run_map == null and app.deck == null,
		"fresh title hides the retired card route from pointer and keyboard")
	app.base_button.pressed.emit()
	var village: BaseScreen = app.base_screen
	_check(village != null and village.is_visible_in_tree(),
		"Quilt village remains browseable from the title")
	if village == null:
		app.free()
		return
	village.set_out_button.pressed.emit()
	_check(app.stitched_run_panel != null and not village.visible
		and app.party_picker == null and app.run_map == null and app.deck == null,
		"village Set out mounts four-of-eight Stitched picker, never the card picker")
	if app.stitched_run_panel == null:
		app.free()
		return
	var boxes: Array = app.stitched_run_panel.find_children("*", "CheckButton", true, false)
	_check(boxes.size() == 8 and app.stitched_run_session == null,
		"village admission presents eight real identities before any run allocation")
	app.stitched_run_buttons[1].pressed.emit()
	_check(village.is_visible_in_tree() and village.has_open_village()
		and not village.set_out_button.disabled and app.stitched_run_session == null
		and app.run_map == null and app.deck == null,
		"cancel returns to the same live village without allocating a card run")
	village.set_out_button.pressed.emit()
	_check(app.stitched_run_panel != null and app.stitched_run_buttons.size() >= 2,
		"repeated village Set out offers a fresh four-hero picker")
	if app.stitched_run_panel != null:
		app.stitched_run_buttons[0].pressed.emit()
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.heroes.size() == 4
		and session.map.get_floors().size() == 12 and app.base_screen == null
		and app.run_map == null and app.deck == null and app.run_rng == null,
		"village confirms four distinct Stitched heroes on twelve floors and no card deck")
	if session != null:
		var identities: Array = []
		for hero in session.heroes:
			identities.append(hero.id)
		_check(identities.size() == 4 and identities.duplicate().all(func(id): return identities.count(id) == 1),
			"village-selected hero identities are distinct and real")
	app.free()
	await process_frame


func _exercise_picker() -> void:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.start_button.pressed.emit()
	var boxes: Array = app.stitched_run_panel.find_children("*", "CheckButton", true, false)
	_check(boxes.size() == 8, "New Run exposes the eight authored hero controls")
	var confirm: Button = app.stitched_run_buttons[0]
	for box in boxes:
		if box.get_meta("hero_id") == "warden":
			box.button_pressed = false
	confirm.pressed.emit()
	_check(app.stitched_run_session == null and app.run_rng == null and app.deck == null,
		"an incomplete real picker cannot publish ledgers or consume RNG")
	app.stitched_run_buttons[1].pressed.emit()
	confirm.pressed.emit()
	_check(app.stitched_run_session == null and app.title_view.is_visible_in_tree(),
		"cancelled picker callbacks cannot start an old draft")
	app.start_button.pressed.emit()
	boxes = app.stitched_run_panel.find_children("*", "CheckButton", true, false)
	var alternate := ["button_golem", "scarecrow", "yarn_ranger", "rag_duelist"]
	for box in boxes:
		box.button_pressed = box.get_meta("hero_id") in alternate
	app.stitched_run_buttons[0].pressed.emit()
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null, "a different four-of-eight selection is admitted through the real picker")
	if session != null:
		for hero in session.heroes:
			_check(hero.id in alternate, "alternate New Run retains each selected canonical identity")
			for part in hero.parts.values():
				_check(session.catalog[part.id].owner == hero.id, "each selected hero wears its authored starter kit")
	app.free()
	await process_frame


func _exercise_partial_carry() -> void:
	var app: Node = await _new_run(42)
	var session: StitchedRunSession = app.stitched_run_session
	if session == null:
		app.free()
		return
	var fight_id := ""
	for id in session.choices():
		if session.map.get_node(id).type == "Fight":
			fight_id = id
	_check(not fight_id.is_empty() and _press_route(app, fight_id), "partial carry starts in a genuine ranked fight")
	var stage: StitchedBattleScreen = app.stitched_run_battle
	if stage == null:
		app.free()
		return
	for step in range(500):
		if stage.battle.is_over() or stage.battle.get_heroes().any(func(hero: Dictionary): return hero.lost):
			break
		stage._action_buttons["pass"].pressed.emit()
	var result := _win(stage)
	_check(result.acted > 0 and stage.battle.outcome() == "victory" \
		and stage.battle.get_heroes().any(func(hero: Dictionary): return hero.lost),
		"actual enemy turns lose a doll before surviving heroes win through abilities")
	if stage.battle.outcome() != "victory":
		app.free()
		return
	stage._action_buttons["exit"].pressed.emit()
	var lost := session.heroes.filter(func(hero: Dictionary): return hero.lost)
	_check(lost.size() == 1 and lost[0].parts.is_empty() and session.satchel.size() >= 4,
		"LOST hero's parts enter the bounded satchel once")
	var shop_id := ""
	for id in session.choices():
		if session.map.get_node(id).type == "Shop":
			shop_id = id
	_check(not shop_id.is_empty() and _press_route(app, shop_id), "earned carry enters the real connected Peddler")
	var actions := session.visit_actions()
	var bought := false
	var bought_part: Dictionary = {}
	for index in actions.size():
		if actions[index].id == "buy_part" and actions[index].enabled:
			var before := session.snapshot()
			var button: Button = app.stitched_run_buttons[index]
			button.pressed.emit()
			_check(session.gold == before.gold - StitchedRunSession.PEDDLER_PRICE \
				and session.satchel.size() == before.satchel.size() + 1, "real Peddler receipt charges gold and adds exactly one part")
			bought_part = session.satchel.back().duplicate(true)
			var paid := session.snapshot()
			button.pressed.emit()
			_check(session.snapshot() == paid, "stale paid button cannot duplicate its part or spend")
			bought = true
			break
	_check(bought, "paid part purchase has a non-vacuous earned-wallet witness")
	if not bought:
		app.free()
		return
	var camp_id: String = session.choices()[0]
	_check(session.map.get_node(camp_id).type == "Campfire" and _press_route(app, camp_id), "connected Campfire receives the carried four-record roster")
	actions = session.visit_actions()
	var swapped := false
	for index in actions.size():
		var action: Dictionary = actions[index]
		if action.id == "swap" and action.enabled and action.arguments[1] == bought_part.get("slot", "") \
			and session.satchel[action.arguments[2]].id == bought_part.get("id", ""):
			app.stitched_run_buttons[index].pressed.emit()
			swapped = true
			break
	_check(swapped, "mounted Campfire swaps the purchased part onto a surviving hero")
	_check(not session.visit_actions().any(func(action: Dictionary): return action.id == "swap"),
		"Campfire's single swap receipt cannot be claimed twice")
	_check(_finish_visit(app) and session.phase == "map", "Campfire recovery finishes without reviving the LOST hero")
	var carried := session.snapshot()
	var next_id: String = session.choices()[0]
	_check(session.map.get_node(next_id).type == "Elite" and _press_route(app, next_id), "carried roster mounts the next actual ranked Elite")
	stage = app.stitched_run_battle
	_check(stage != null and stage.battle.get_heroes().any(func(hero: Dictionary): return hero.lost),
		"next fight preserves LOST and empty equipped slots")
	if stage != null:
		for hero in stage.config.heroes:
			for previous in carried.heroes:
				if hero.id == previous.id:
					_check(hero.parts == previous.parts and hero.hp == previous.hp and hero.fray == previous.fray,
						"next fight receives authenticated gear, HP and fray by hero ID")
	var restored := StitchedRunSave.restore(StitchedRunSave.capture(session))
	_check(restored != null and restored.snapshot() == session.snapshot(), "LOST/part-purchase/swap carry replays through a real follow-on battle")
	app.free()
	await process_frame


func _exercise_defeat() -> void:
	var app: Node = await _new_run(42)
	var session: StitchedRunSession = app.stitched_run_session
	if session == null:
		app.free()
		return
	var id := ""
	for candidate in session.choices():
		if session.map.get_node(candidate).type == "Fight":
			id = candidate
	_check(not id.is_empty() and _press_route(app, id), "defeat test enters an actual opening fight")
	var stage: StitchedBattleScreen = app.stitched_run_battle
	if stage == null:
		app.free()
		return
	var turns := 0
	for step in range(800):
		if stage.battle.is_over():
			break
		var previous := stage.receipts.size()
		stage._action_buttons["pass"].pressed.emit()
		if stage.receipts.size() == previous:
			break
		turns += 1
	_check(turns > 0 and stage.battle.outcome() == "defeat", "seeded public Pass controls genuinely lose all four heroes")
	stage._action_buttons["exit"].pressed.emit()
	_check(session.phase == "defeat" and session.receipts.size() == 1 and session.gold == 0 and session.scraps == 0,
		"genuine defeat settles once without victory spoils")
	var restored := StitchedRunSave.restore(StitchedRunSave.capture(session))
	_check(restored != null and restored.snapshot() == session.snapshot(), "defeat reload preserves four LOST recaps and exact RNG")
	app.stitched_run_buttons[0].pressed.emit()
	_check(app.stitched_run_session == null and app.title_view.is_visible_in_tree(), "Return retires the defeated session")
	app.start_button.pressed.emit()
	app.stitched_run_buttons[0].pressed.emit()
	_check(app.stitched_run_session != null and app.stitched_run_session.candle == 100 \
		and app.stitched_run_session.map.get_route().is_empty() and app.stitched_run_session.gold == 0,
		"New Run restarts fresh after defeat")
	app.free()
	await process_frame


func _exercise_stop_kinds() -> void:
	var missing := ["Rest", "Shop", "Event", "Treasure", "SewingCircle", "Campfire", "PatchStall", "Unpicker"]
	for seed_number in range(100):
		if missing.is_empty():
			break
		var map_rng := RandomNumberGenerator.new()
		map_rng.seed = seed_number
		var generated := RunMap.new()
		generated.generate(map_rng)
		for node_id in generated.get_legal_choices():
			var kind: String = generated.get_node(node_id).type
			if not kind in missing:
				continue
			var app: Node = await _new_run(seed_number)
			var session: StitchedRunSession = app.stitched_run_session
			if session == null:
				app.free()
				continue
			var route_button: Button = app.stitched_run_buttons[session.choices().find(node_id)]
			_check(_press_route(app, node_id) and session.phase == "visit", kind + " mounts its real route service")
			if session.phase != "visit":
				app.free()
				continue
			var before := session.snapshot()
			route_button.pressed.emit()
			_check(session.snapshot() == before and session.candle == 92, kind + " stale route callback has no second charge")
			_check(not session.choose_visit("forged", [], before) and session.snapshot() == before,
				kind + " forged service action preserves ledgers and RNG")
			_check(_finish_visit(app) and session.phase == "map" and session.receipts.size() == 1,
				kind + " mounted stop choice commits exactly one receipt")
			var ended := session.snapshot()
			_check(not session.choose_visit("leave", [], before) and session.snapshot() == ended,
				kind + " replay cannot duplicate a service outcome")
			missing.erase(kind)
			app.free()
			await process_frame
	_check(missing.is_empty(), "every real route stop kind has a non-vacuous mounted witness")


func _complete_route(app: Node) -> void:
	var session: StitchedRunSession = app.stitched_run_session
	for step in range(80):
		if session.phase in ["victory", "defeat"]:
			break
		if session.phase == "map":
			var route_id: String = session.choices()[0]
			for preferred in ["Campfire", "Rest", "Event", "SewingCircle", "Shop", "Treasure", "PatchStall", "Unpicker", "Fight", "Elite", "Boss"]:
				var found := false
				for id in session.choices():
					if session.map.get_node(id).type == preferred:
						route_id = id
						found = true
						break
				if found:
					break
			var prior_candle := session.candle
			var prior := session.snapshot()
			_check(_press_route(app, route_id), "legal connected route enters %s" % route_id)
			_check(session.candle == maxi(0, prior_candle - 8), "each route entry charges exactly once")
			_check(not session.enter(route_id, prior), "old node callback cannot enter twice")
		elif session.phase == "visit":
			_check(_finish_visit(app), "mounted service decision is usable")
		elif session.phase == "battle":
			var stage: StitchedBattleScreen = app.stitched_run_battle
			if stage == null:
				_check(false, "session battle is actually mounted")
				break
			var result := _win(stage)
			_check(result.acted > 0 and stage.battle.is_over(), "actual legal turns settle the ranked route fight")
			if not stage.battle.is_over():
				break
			stage._action_buttons["exit"].pressed.emit()
