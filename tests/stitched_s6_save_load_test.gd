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
	# This S6 fixture deliberately exercises the pre-S14 legacy Hanging and
	# save-migration path. Opt out before its first journaled action.
	session.s14_enabled = false
	session._seal()
	app._present_stitched_run()
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


func _published_document(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var readback: Variant = bytes_to_var(file.get_buffer(file.get_length()))
	file.close()
	return readback


## AC1 witness: the file published at path must reopen as exactly the
## just-captured latest generation, never a stale or partial predecessor.
func _check_published_generation(path: String, session: StitchedRunSession,
		prior: Dictionary, label: String) -> Dictionary:
	var document := StitchedRunSave.capture(session)
	_check(not document.is_empty(), label + " captures the authenticated generation")
	var on_disk: Variant = _published_document(path)
	var matched: bool = on_disk is Dictionary and on_disk.version == document.version \
		and on_disk.seed == document.seed and on_disk.picks == document.picks \
		and on_disk.initial == document.initial and on_disk.journal == document.journal \
		and on_disk.state == document.state and on_disk.digest == document.digest
	_check(matched, label + " reopens as the just-captured seed, picks, initial, state, journal and digest")
	var fresh: bool = prior.is_empty() or (on_disk is Dictionary and on_disk.journal != prior.journal \
		and on_disk.state != prior.state and on_disk.digest != prior.digest)
	_check(fresh, label + " publishes the latest run, never the stale prior generation")
	_check(not FileAccess.file_exists(path + ".tmp"), label + " successful replace consumes its staged file")
	var reopened := StitchedRunSave.read_file(path)
	_check(reopened != null and reopened != session and reopened.snapshot() == session.snapshot() \
		and reopened.journal == session.journal and reopened.seed_value == session.seed_value,
		label + " immediate reopen replays exactly the latest generation")
	return document


## AC2 witness: invalid and unwritable writes must fail without corrupting
## the prior accepted save or leaving a misleading staged file behind.
func _check_negative_writes(path: String, session: StitchedRunSession, label: String) -> void:
	var before := session.snapshot()
	var prior := StitchedRunSave.read_file(path)
	_check(prior != null and prior.snapshot() == before, label + " starts from an intact prior accepted save")
	_check(not StitchedRunSave.write_file(path, null), label + " invalid run fails closed")
	_check(not StitchedRunSave.write_file("user://s6_save_load_missing_dir/run.save", session),
		label + " unwritable directory fails closed")
	_check(not FileAccess.file_exists(path + ".tmp"), label + " failed writes leave no misleading staged file")
	var preserved := StitchedRunSave.read_file(path)
	_check(preserved != null and preserved.snapshot() == before and preserved.journal == session.journal,
		label + " failed writes preserve the prior accepted save and journal")
	var corrupt_path := "user://s6_save_load_corrupt.save"
	var writer := FileAccess.open(corrupt_path, FileAccess.WRITE)
	_check(writer != null, label + " corrupt fixture opens")
	if writer != null:
		writer.store_buffer(var_to_bytes({"version": "not a run"}))
		writer.close()
	_check(StitchedRunSave.read_file(corrupt_path) == null, label + " a failed read remains fail-closed")
	DirAccess.remove_absolute(corrupt_path)
	_check(session.snapshot() == before, label + " negative writes leave the live session untouched")


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
		DirAccess.remove_absolute(path)
		DirAccess.remove_absolute(path + ".tmp")
		_check(StitchedRunSave.write_file(path, session), "versioned run file writes successfully")
		var first := _check_published_generation(path, session, {}, "midbattle generation")
		_check_negative_writes(path, session, "midbattle negative writes")
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
		var second := _check_published_generation(path, session, first, "postbattle generation")
		_check(not first.is_empty() and not second.is_empty() \
			and second.journal.size() > first.journal.size(),
			"postbattle generation carries strictly more authenticated journal actions")
		DirAccess.remove_absolute(path)
		DirAccess.remove_absolute(path + ".tmp")
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
