extends "res://tests/stitched_s6_followon_foes_live_test.gd"
## Real New Run controls, connected map choices and legal ranked abilities.


func _new_run(seed_number: int) -> Node:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	app.run_seed = seed_number
	app.stitched_walks = false   # S8f Walks are covered by stitched_s8f_routed_walk_test
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


## First seeded route whose opening choices include a Rest node, i.e. an authentic Campfire.
func _campfire_route() -> Array:
	for seed_number in range(300):
		var map_rng := RandomNumberGenerator.new()
		map_rng.seed = seed_number
		var generated := RunMap.new()
		if not generated.generate(map_rng):
			continue
		for node_id in generated.get_legal_choices():
			if generated.get_node(node_id).type == "Rest":
				return [seed_number, node_id]
	return []


## Test-only setup: Wren's FEAR is seeded through the public StitchedKidFear observed-event API
## (not a claim of battle-earned FEAR), then the run is routed into the real Campfire.
func _tales_setup(route: Array, fear_target: int, frays: Array, resolves: Array, options: Dictionary = {}) -> StitchedRunSession:
	var session := StitchedRunSession.start(route[0])
	if session == null:
		return null
	var remaining := fear_target
	while remaining >= 15:
		session._kid_fear.apply_observed_event({"kind": "lost"})
		remaining -= 15
	while remaining >= 5:
		session._kid_fear.apply_observed_event({"kind": "hanging"})
		remaining -= 5
	while remaining >= 2:
		session._kid_fear.apply_observed_event({"kind": "fray", "amount": 10})
		remaining -= 2
	for index in 4:
		session.heroes[index].fray = int(frays[index])
		session.heroes[index].resolve = str(resolves[index])
	if options.get("hurt", false):
		session.heroes[0].hp = maxi(1, session.heroes[0].max_hp - 10)
	if options.get("spare", false):
		var slot: String = StitchedParts.SLOTS[0]
		session.satchel.append({"id": session.heroes[1].parts[slot].id, "slot": slot, "tier": 1, "torn": false})
	session._seal()
	if session.kid_fear() != fear_target or not session.enter(route[1], session.snapshot()):
		return null
	return session


func _enabled_ids(session: StitchedRunSession) -> Array:
	var ids: Array = []
	for action in session.visit_actions():
		if action.enabled:
			ids.append(action.id)
	return ids


func _fray_of(session: StitchedRunSession) -> Dictionary:
	var result := {}
	for hero in session.heroes:
		result[hero.id] = [hero.fray, hero.resolve]
	return result


func _exercise_campfire_tell_tales() -> void:
	var route := _campfire_route()
	_check(route.size() == 2, "a seeded route reaches an authentic Campfire")
	if route.size() != 2:
		return
	var untouched_rng := StitchedRunSession.start(route[0]).rng.state
	var zeros := [0, 0, 0, 0]
	var blank := ["", "", "", ""]

	# AC1: FEAR alone offers Tell Tales (capped quote); no FEAR and no FRAY does not.
	var fear_only := _tales_setup(route, 20, zeros, blank)
	_check(fear_only != null and fear_only.phase == "visit" and fear_only.candle == 92,
		"FEAR-only Campfire opens through the run with the ordinary -8 CANDLE debit")
	if fear_only == null:
		return
	var offered := _enabled_ids(fear_only)
	_check(offered.has("tell_tales") and offered.has("leave") and not offered.has("mend"),
		"four zero-FRAY dolls with positive FEAR still offer enabled Tell Tales and Leave")
	_check(str(fear_only._service.read_state().quote.text).contains("-15 Wren FEAR now"),
		"live quote reports the 15 FEAR relief")
	var capped := _tales_setup(route, 5, zeros, blank)
	_check(capped != null and str(capped._service.read_state().quote.text).contains("-5 Wren FEAR now"),
		"live quote reports FEAR relief capped by the actual FEAR")
	var calm := _tales_setup(route, 0, zeros, blank)
	_check(calm != null and calm.visit_actions().size() > 0 and _enabled_ids(calm).has("leave")
		and not calm.visit_actions().any(func(action: Dictionary): return action.id == "tell_tales"),
		"zero FEAR and zero FRAY omit Tell Tales")

	# AC2: FEAR-only commit.
	var before := fear_only.snapshot()
	var sequence: int = fear_only._kid_fear.get_sequence()
	var gold_before := fear_only.gold
	var scraps_before := fear_only.scraps
	_check(fear_only.choose_visit("tell_tales", [], before), "FEAR-only Tell Tales is accepted")
	var oracle := StitchedKidFear.new(20)
	var event := oracle.apply_observed_event({"kind": "tell_tales"})
	_check(fear_only.kid_fear() == 5 and fear_only.kid_fear() == event.fear
		and fear_only._kid_fear.get_sequence() == sequence + 1,
		"one ledger event lowers FEAR by 15 and agrees with the standalone ledger")
	_check(fear_only.heroes == before.heroes and fear_only.satchel == before.satchel
		and fear_only.gold == gold_before and fear_only.scraps == scraps_before and fear_only.candle == 92
		and fear_only.rng.state == untouched_rng,
		"FEAR-only relief leaves dolls, gear, wallet, CANDLE and the run RNG alone")
	_check(fear_only.phase == "map" and fear_only.receipts.size() == 1
		and fear_only.receipts[0].decision == "tell_tales" and fear_only.receipts[0].steps.size() == 1
		and fear_only.is_consistent(), "one stop receipt seals the committed choice")

	# AC2: mixed FRAY and FEAR below 15, resolve cleared strictly below 50.
	var mixed := _tales_setup(route, 5, [0, 60, 75, 130], ["", "frantic", "bitter", "hollow"])
	_check(mixed != null and _enabled_ids(mixed).has("tell_tales"), "mixed FRAY and FEAR offers Tell Tales")
	if mixed != null:
		var mixed_before := mixed.snapshot()
		var mixed_sequence: int = mixed._kid_fear.get_sequence()
		_check(mixed.choose_visit("tell_tales", [], mixed_before), "mixed Tell Tales is accepted")
		var expected := {}
		var ids: Array = []
		for hero in mixed_before.heroes:
			ids.append(hero.id)
		var after_fray := [0, 35, 50, 105]
		var after_resolve := ["", "", "bitter", "hollow"]
		for index in 4:
			expected[ids[index]] = [after_fray[index], after_resolve[index]]
		_check(_fray_of(mixed) == expected and mixed.kid_fear() == 0 and mixed._kid_fear.get_sequence() == mixed_sequence + 1,
			"every doll loses min(25, FRAY), Wren loses min(15, FEAR) once, and resolve clears only below 50")

	# AC2: a queued Lose the Strings survives the relief.
	var strings := _tales_setup(route, 100, zeros, blank)
	_check(strings != null and strings._kid_fear.has_pending_lost_strings(), "FEAR 100 queues Lose the Strings")
	if strings != null:
		_check(strings.choose_visit("tell_tales", [], strings.snapshot()) and strings.kid_fear() == 85
			and strings._kid_fear.has_pending_lost_strings(), "Tell Tales at FEAR 100 keeps the queued interruption")

	# AC3: stale, forged and replayed attempts are neutral.
	var guarded := _tales_setup(route, 20, [0, 10, 0, 0], blank)
	if guarded != null:
		var start := guarded.snapshot()
		var guarded_sequence: int = guarded._kid_fear.get_sequence()
		var stale := start.duplicate(true)
		stale.candle = 99
		var stale_fear := start.duplicate(true)
		stale_fear.kid_fear.fear = 0
		var refusals := [
			guarded.choose_visit("tell_tales", [], stale), guarded.choose_visit("tell_tales", [], stale_fear),
			guarded.choose_visit("tell_tales", [], {}), guarded.choose_visit("forged", [], start),
			guarded.choose_visit("tell_tales", ["extra"], start), guarded.choose_visit("mend", [], start)]
		_check(refusals.all(func(accepted: bool): return not accepted) and guarded.snapshot() == start
			and guarded._kid_fear.get_sequence() == guarded_sequence and guarded.rng.state == untouched_rng,
			"stale, forged and unoffered Campfire attempts change no FRAY, FEAR, wallet, CANDLE, RNG or receipt")
		_check(guarded.choose_visit("tell_tales", [], start), "the authentic Tell Tales is still accepted")
		var done := guarded.snapshot()
		_check(not guarded.choose_visit("tell_tales", [], start) and not guarded.choose_visit("tell_tales", [], done)
			and not guarded.choose_visit("leave", [], done) and guarded.snapshot() == done
			and guarded.receipts.size() == 1 and guarded._kid_fear.get_sequence() == guarded_sequence + 1
			and guarded.kid_fear() == 5, "replayed Tell Tales or Leave cannot repeat the relief")

	# AC3: other accepted choices never emit the Tell Tales event.
	for choice in ["trim_the_wick", "leave", "mend", "swap"]:
		var other := _tales_setup(route, 20, [0, 10, 0, 0], blank, {"hurt": choice == "mend", "spare": choice == "swap"})
		_check(other != null, choice + " setup reaches the Campfire")
		if other == null:
			continue
		var other_before := other.snapshot()
		var other_sequence: int = other._kid_fear.get_sequence()
		var index := -1
		for position in other.visit_actions().size():
			if other.visit_actions()[position].id == choice and other.visit_actions()[position].enabled:
				index = position
		_check(index >= 0, choice + " is an eligible Campfire decision")
		if index < 0:
			continue
		var action: Dictionary = other.visit_actions()[index]
		_check(other.choose_visit(choice, action.arguments, other_before), choice + " is accepted")
		if choice == "swap":
			_check(other.phase == "visit" and other.choose_visit("leave", [], other.snapshot()),
				"Leave after a swap closes the Campfire")
		_check(other.kid_fear() == 20 and other._kid_fear.get_sequence() == other_sequence
			and other._kid_fear.state_snapshot().fear == 20 and other.rng.state == untouched_rng,
			choice + " leaves FEAR, the ledger sequence and the RNG unchanged")
		_check(other.heroes[1].fray == 10, choice + " leaves FRAY untouched")

	# Fixed-seed repeatability.
	var first := _tales_setup(route, 20, [0, 60, 75, 130], ["", "frantic", "bitter", "hollow"])
	var second := _tales_setup(route, 20, [0, 60, 75, 130], ["", "frantic", "bitter", "hollow"])
	_check(first != null and second != null and first.choose_visit("tell_tales", [], first.snapshot())
		and second.choose_visit("tell_tales", [], second.snapshot())
		and first.snapshot() == second.snapshot() and first.journal == second.journal
		and first.rng.state == untouched_rng,
		"two identical seeded setups commit identical Tell Tales results without a fresh RNG call")


func _run() -> void:
	# Seed 43 re-derives the public-control winning witness for the first-phase Behemoth
	# Maul tear: the same mounted route from an opening Fight must still reach victory.
	var app: Node = await _new_run(43)
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
	_exercise_campfire_tell_tales()
	for message in failures:
		printerr(message)
	print("stitched_s6_full_run_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


## Fresh public title and village actions cannot expose the retired three-card route.
func _exercise_village_entry() -> void:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	_check(app.get("route_button") == null and app.run_map == null and app.deck == null,
		"fresh title has no retired card route")
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
			_check(result.acted > 0 and stage.battle.is_over() and stage.battle.outcome() == "victory",
				"actual legal turns earn the ranked route fight's victory")
			if not stage.battle.is_over() or stage.battle.outcome() != "victory":
				break
			stage._action_buttons["exit"].pressed.emit()
