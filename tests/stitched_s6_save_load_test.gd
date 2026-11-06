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
	for key in ["gold", "candle", "rng", "phase", "heroes", "map", "pockets", "kid_fear"]:
		var corrupt := document.duplicate(true)
		corrupt.state[key] = "forged"
		corrupt.digest = StitchedRunSave._digest(corrupt)
		_check(StitchedRunSave.restore(corrupt) == null and session.snapshot() == before,
			label + " rejects corrupted " + key + " atomically")
	var legacy := document.duplicate(true)
	legacy.state.erase("pockets")
	legacy.digest = StitchedRunSave._digest(legacy)
	var migrated := StitchedRunSave.restore(legacy)
	_check(migrated != null and migrated.snapshot() == before,
		label + " replays a pre-pocket save into four empty canonical pockets")
	_fear_save_guards(session, label)
	var forged_purchase := legacy.duplicate(true)
	forged_purchase.journal.append({"action": "visit", "id": "buy_pins", "arguments": [session.heroes[0].id]})
	forged_purchase.digest = StitchedRunSave._digest(forged_purchase)
	_check(StitchedRunSave.restore(forged_purchase) == null,
		label + " a pre-pocket save cannot smuggle a purchase command past replay")
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


func _fear_save_guards(session: StitchedRunSession, label: String) -> void:
	var before := session.snapshot()
	var journal := session.journal.duplicate(true)
	var document := StitchedRunSave.capture(session)
	_check(document.version == 1, label + " retains VERSION=1")
	for field in ["fear", "shake", "pending_lost_strings", "sequence"]:
		var forged := document.duplicate(true)
		var value: Variant = forged.state.kid_fear[field]
		forged.state.kid_fear[field] = not value if value is bool else int(value) + 1
		forged.digest = StitchedRunSave._digest(forged)
		_check(StitchedRunSave.restore(forged) == null, label + " rejects rehashed fear service field " + field)
	var incomplete := document.duplicate(true)
	incomplete.state.kid_fear.erase("sequence")
	incomplete.digest = StitchedRunSave._digest(incomplete)
	_check(StitchedRunSave.restore(incomplete) == null, label + " present fear must match the entire service state")
	var extra := document.duplicate(true)
	extra.state.kid_fear["forged"] = 0
	extra.digest = StitchedRunSave._digest(extra)
	_check(StitchedRunSave.restore(extra) == null, label + " rejects additional fear fields")
	for without_pockets in [false, true]:
		var legacy_fear := document.duplicate(true)
		legacy_fear.state.erase("kid_fear")
		if without_pockets:
			legacy_fear.state.erase("pockets")
		legacy_fear.digest = StitchedRunSave._digest(legacy_fear)
		var migrated := StitchedRunSave.restore(bytes_to_var(var_to_bytes(legacy_fear)))
		_check(migrated != null and migrated.is_consistent() and migrated.snapshot() == before
			and migrated.journal == journal and migrated.rng.state == session.rng.state,
			label + " pre-fear save reconstructs complete canonical state and RNG, pockets absent=" + str(without_pockets))
		var corrupt := legacy_fear.duplicate(true)
		corrupt.state.gold += 1
		corrupt.digest = StitchedRunSave._digest(corrupt)
		_check(StitchedRunSave.restore(corrupt) == null, label + " legacy fear migration preserves other ledger validation")
		var undigested := legacy_fear.duplicate(true)
		undigested.journal.append({"action": "settle"})
		_check(StitchedRunSave.restore(undigested) == null, label + " legacy migration retains original digest validation")
		if without_pockets:
			for purchase in ["buy_pins", "buy_thimble_tonic", "buy_fresh_stuffing", "buy_dye"]:
				var smuggled := legacy_fear.duplicate(true)
				smuggled.journal.append({"action": "visit", "id": purchase, "arguments": [session.heroes[0].id]})
				smuggled.digest = StitchedRunSave._digest(smuggled)
				_check(StitchedRunSave.restore(smuggled) == null, label + " pre-fear/pre-pocket save rejects " + purchase)
	for command in [{"action": "settle"}, {"action": "kid_fear", "fear": 15}]:
		var forged := document.duplicate(true)
		forged.journal.append(command)
		forged.digest = StitchedRunSave._digest(forged)
		_check(StitchedRunSave.restore(forged) == null, label + " rejects unfinished, duplicate or forged fear command " + str(command))
	_check(session.snapshot() == before and session.journal == journal,
		label + " every rejected restore leaves the source state and journal unchanged")


func _lost_save() -> void:
	var app: Node = await _new_run(42)
	var session: StitchedRunSession = app.stitched_run_session
	if session == null:
		app.free()
		return
	var fight_id := ""
	for id in session.choices():
		if session.map.get_node(id).type == "Fight":
			fight_id = id
	_check(not fight_id.is_empty() and _press_route(app, fight_id), "legacy loss regression mounts real combat")
	var stage: StitchedBattleScreen = app.stitched_run_battle
	if stage == null:
		app.free()
		return
	for step in range(500):
		if stage.battle.is_over() or stage.battle.get_heroes().any(func(hero: Dictionary): return hero.lost):
			break
		stage._action_buttons["pass"].pressed.emit()
	var won := _win(stage)
	_check(won.acted > 0 and stage.battle.outcome() == "victory"
		and stage.battle.get_heroes().filter(func(hero: Dictionary): return hero.lost).size() == 1,
		"legacy migration uses public turns with one actual LOST doll and a surviving victory")
	stage._action_buttons["exit"].pressed.emit()
	_check(session.phase == "map" and session.snapshot().kid_fear.fear == 15
		and session.snapshot().kid_fear.sequence == 1, "loss save has nonzero authenticated service state")
	_roundtrip(session, "real LOST settlement")
	var shop_id := ""
	for id in session.choices():
		if session.map.get_node(id).type == "Shop":
			shop_id = id
	_check(not shop_id.is_empty() and _press_route(app, shop_id), "loss save reaches an actual pocket purchase offer")
	var actions := session.visit_actions()
	var purchased := false
	for index in actions.size():
		if actions[index].id == "buy_pins" and actions[index].enabled:
			app.stitched_run_buttons[index].pressed.emit()
			purchased = true
			break
	_check(purchased, "purchase-smuggling regression contains an accepted real purchase command")
	var before := session.snapshot()
	var document := StitchedRunSave.capture(session)
	_check(not document.is_empty() and document.journal.back().id == "buy_pins",
		"owned pocket item is authenticated by its genuine journal action")
	var legacy := document.duplicate(true)
	legacy.state.erase("kid_fear")
	legacy.digest = StitchedRunSave._digest(legacy)
	var migrated := StitchedRunSave.restore(legacy)
	_check(migrated != null and migrated.snapshot() == before, "pre-fear save with a legitimate pocket purchase migrates exactly")
	for without_fear in [false, true]:
		var smuggled := document.duplicate(true)
		smuggled.state.erase("pockets")
		if without_fear:
			smuggled.state.erase("kid_fear")
		smuggled.digest = StitchedRunSave._digest(smuggled)
		_check(StitchedRunSave.restore(smuggled) == null and session.snapshot() == before,
			"pre-pocket document with a real purchased-item command fails closed, fear absent=" + str(without_fear))
	app.free()
	await process_frame


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
	await _lost_save()
	for message in failures:
		printerr(message)
	print("stitched_s6_save_load_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
