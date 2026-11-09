extends "res://tests/stitched_s6_routed_vis_a_test.gd"
## S6: the mounted Peddler Save/Reload pair publishes and restores the exact
## live generation around both pocket-item purchases, and a Save press whose
## verified publish fails never lets the adjacent Reload substitute the
## previously sealed generation for the live open visit.

## Lane suites can execute this same test in different Godot processes at once;
## unique public save paths prevent cross-process seals from racing via user://.
var SAVE_PATH := "user://stitched_s6_peddler_save_generation_%d.save" % OS.get_process_id()


## These seeded S6 wallet witnesses predate optional S8f walking. Preserve their exact
## route/fight replay while exercising the CURRENT corridor junction and visit surfaces.
## Begin through the title's real controls, then remount the junction on that run.
func _new_run(seed_number: int) -> Node:
	var app: Node = await super._new_run(seed_number)
	if app.stitched_run_session == null:
		return app
	if is_instance_valid(app.stitched_run_intro):
		var begin := app.stitched_run_intro.find_child("WrenIntroBegin", true, false) as Button
		_check(begin != null and begin.is_visible_in_tree() and not begin.disabled,
			"real Wren introduction has a usable Begin control")
		if begin != null:
			begin.pressed.emit()
	app.stitched_walks = true
	app._present_stitched_run()
	await process_frame
	_check(await _await_controls(app, "map"), "new seeded run mounts current corridor junction")
	return app


func _press_route(app: Node, id: String) -> bool:
	var session: StitchedRunSession = app.stitched_run_session
	if session == null or session.phase != "map" or not app.stitched_run_panel is StitchedCorridorJunction:
		_check(false, "route entry requires the live map junction: " + id)
		return false
	var junction := app.stitched_run_panel as StitchedCorridorJunction
	var choices := session.choices()
	var button := junction.doors.get(id) as Button
	var valid: bool = choices.has(id) and is_instance_valid(button) and button.is_visible_in_tree() \
		and not button.disabled and button.get_parent() == junction \
		and button.get_meta("route_id", "") == id and app.stitched_run_buttons.has(button)
	_check(valid, "legal connected " + id + " is a visible, live junction door")
	if not valid:
		return false
	button.pressed.emit()
	if not (session.map.get_current_node_id() == id and session.phase in ["visit", "battle"]):
		_check(false, "mounted " + id + " door did not enter it; "
			+ _controls_evidence(app, "wanted the current generation to enter " + id))
		return false
	return true


func _visit_button(app: Node, id: String, arguments: Array = []) -> Button:
	# A returned control must be the CURRENT generation's projection: exact
	# metadata, text and enabled state on the live parented page, so a retired
	# or out-of-sync button is never returned as a usable Shop action.
	var session: StitchedRunSession = app.stitched_run_session
	var actions: Array = session.visit_actions() if session != null and session.phase == "visit" else []
	for index in actions.size():
		if actions[index].id == id and actions[index].arguments == arguments:
			var button: Button = app.stitched_run_buttons[index] if index < app.stitched_run_buttons.size() else null
			if is_instance_valid(button) and is_instance_valid(app.stitched_run_panel) \
					and app.stitched_run_panel.is_ancestor_of(button) and button.is_visible_in_tree() \
					and button.get_meta("action_id", "") == id \
					and button.get_meta("action_arguments", []) == arguments \
					and button.text == str(actions[index].text) \
					and button.disabled == not bool(actions[index].enabled):
				return button
	_check(false, "current mounted visit has requested action " + id + str(arguments) + "; "
		+ _controls_evidence(app, "wanted visible visit action " + id + str(arguments)))
	return null


## Explicit actual-versus-expected evidence for a wait, press or projection that
## did not hold: the CURRENT session, page and mounted button projection
## against the wanted one, so any timeout names the exact mismatch.
func _controls_evidence(app: Node, wanted: String) -> String:
	var session: StitchedRunSession = app.stitched_run_session
	var text := wanted + "; actual phase=" + ("null" if session == null else str(session.phase))
	if session != null:
		var projected: Array = session.visit_actions() if session.phase == "visit" else session.choices()
		var names: Array = []
		for entry in projected:
			names.append(str(entry.id) if entry is Dictionary else str(entry))
		text += " projected=" + str(names) + " pending=" + str(session.pending)
	var panel: Control = app.stitched_run_panel
	if not is_instance_valid(panel):
		text += " panel=none"
	else:
		var kind := "junction" if panel is StitchedCorridorJunction else "visit" if panel is StitchedCorridorVisit \
			else str(panel.get_meta("page_kind", str(panel.name)))
		text += " panel=" + kind + " parented=" + str(panel.get_parent() == app) \
			+ " visible=" + str(panel.is_visible_in_tree())
	var buttons: Array[Button] = app.stitched_run_buttons
	text += " buttons=" + str(buttons.size()) + " ["
	for index in mini(buttons.size(), 8):
		var button: Button = buttons[index]
		if is_instance_valid(button):
			text += "\"" + button.text + "\""
			if button.has_meta("action_id"):
				text += "=action:" + str(button.get_meta("action_id")) + str(button.get_meta("action_arguments", []))
			elif button.has_meta("route_id"):
				text += "=route:" + str(button.get_meta("route_id"))
			text += ("/on" if not button.disabled else "/off")
		else:
			text += "freed"
		if index < mini(buttons.size(), 8) - 1:
			text += ", "
	text += "]"
	return text


## A transition detaches old page controls immediately, but new mounted controls
## may not be ready until a subsequent frame under parallel test load. Re-query
## both the session projection and current page for an exact, visible generation;
## no blind sleep, replay shortcut, or test-only purchase is involved.
func _await_controls(app: Node, phase: String, service: String = "") -> bool:
	# The map is a corridor junction: doors + Save + Return. A stop has
	# visit actions + Save + Reload. Reject a previous generation outright:
	# each attempt re-proves the CURRENT session generation, page parentage,
	# pending node, service and full button projection (metadata, text and
	# enabled state), so a retired panel or replaced session never passes.
	for attempt in range(18):
		var session: StitchedRunSession = app.stitched_run_session
		var panel: Control = app.stitched_run_panel
		if session != null and session.phase == phase and is_instance_valid(panel) \
				and panel.is_visible_in_tree() and panel.get_parent() == app \
				and (phase != "visit" or (str(session.pending.get("service", "")) == service \
					and not session.map.get_node(str(session.pending.get("node_id", ""))).is_empty())):
			var buttons: Array[Button] = app.stitched_run_buttons
			if phase == "map" and panel is StitchedCorridorJunction:
				var junction := panel as StitchedCorridorJunction
				var legal := session.choices()
				var ready := not legal.is_empty() and junction.doors.size() == legal.size() \
					and buttons.size() == legal.size() + 2
				if ready:
					for index in legal.size():
						var door := junction.doors.get(legal[index]) as Button
						if not is_instance_valid(door) or buttons[index] != door \
								or door.get_parent() != junction or not door.is_visible_in_tree() \
								or door.disabled or door.get_meta("route_id", "") != legal[index]:
							ready = false
							break
					if ready:
						var save := buttons[legal.size()]
						var title := buttons[legal.size() + 1]
						ready = is_instance_valid(save) and is_instance_valid(title) \
							and save.text == "Save run" and title.text == "Return to title" \
							and not save.disabled and not title.disabled \
							and save.is_visible_in_tree() and title.is_visible_in_tree() \
							and panel.is_ancestor_of(save) and panel.is_ancestor_of(title)
						if ready:
							return true
			elif phase == "visit" and panel is StitchedCorridorVisit:
				var actions := session.visit_actions()
				var ready := not actions.is_empty() and buttons.size() == actions.size() + 2
				if ready:
					for index in actions.size():
						var button := buttons[index]
						if not is_instance_valid(button) or not panel.is_ancestor_of(button) \
								or not button.is_visible_in_tree() \
								or button.get_meta("action_id", "") != actions[index].id \
								or button.get_meta("action_arguments", []) != actions[index].arguments \
								or button.text != str(actions[index].text) \
								or button.disabled != not bool(actions[index].enabled):
							ready = false
							break
					if ready:
						var save := buttons[actions.size()]
						var reload := buttons[actions.size() + 1]
						ready = is_instance_valid(save) and is_instance_valid(reload) \
							and save.text == "Save run" and reload.text == "Reload saved run" \
							and not save.disabled and not reload.disabled \
							and save.is_visible_in_tree() and reload.is_visible_in_tree() \
							and panel.is_ancestor_of(save) and panel.is_ancestor_of(reload)
						if ready:
							return true
		await process_frame
	_check(false, "timed out waiting for live " + phase + " " + service + " controls; "
		+ _controls_evidence(app, "wanted phase=" + phase + " service=" + service))
	return false


## The mounted visit's own Save/Reload navigation pair inside the live panel.
func _nav_controls(app: Node) -> Array:
	var found: Array = []
	var panel: Control = app.stitched_run_panel
	for button in app.stitched_run_buttons:
		if is_instance_valid(button) and is_instance_valid(panel) and panel.is_ancestor_of(button) \
			and button.text in ["Save run", "Reload saved run"]:
			found.append(button)
	return found


## The mounted visit's Save/Reload pair in button order: Save first, Reload second.
func _nav_pair(app: Node) -> Array:
	var pair: Array = []
	for button in _nav_controls(app):
		if button.text == "Save run":
			pair.append(button)
		elif button.text == "Reload saved run":
			pair.append(button)
	return pair


## AC2 witness: emit retained pre-remount navigation controls after a remount and
## prove zero mutation of the live session, its complete ledger and the sealed file.
func _reject_stale_nav(app: Node, old_nav: Array, label: String) -> void:
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null, label + " has a live authenticated session to protect")
	if session == null:
		return
	var path: String = app.stitched_save_path
	_check(not path.is_empty(), label + " uses the public sealed save path")
	var before := session.snapshot()
	var journal := session.journal.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	var sealed := StitchedRunSave.read_file(path)
	for button in old_nav:
		_check(is_instance_valid(button), label + " retained a real pre-remount navigation control")
		if is_instance_valid(button):
			button.pressed.emit()
		_check(session.snapshot() == before and session.journal == journal,
			label + " stale Save/Reload leaves the live snapshot and complete ledger untouched")
		var now_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
		_check(now_bytes == bytes, label + " stale Save leaves the sealed save file byte-identical")
		var resealed := StitchedRunSave.read_file(path)
		_check((sealed == null) == (resealed == null) and (resealed == null
			or (resealed.snapshot() == sealed.snapshot() and resealed.journal == sealed.journal)),
			label + " stale callbacks keep complete authenticated snapshots and ledgers in the file")


## AC1 witness: the restored session must equal the exact live generation field
## by field: complete snapshot and journal, still-open Peddler service, mounted
## choices, sampled stock, pockets, wallet, RNG and route.
func _assert_exact_generation(label: String, restored: StitchedRunSession, before: Dictionary,
		journal: Array, choices: Array, stock: Variant) -> void:
	_check(restored != null, label + " restored a real session")
	if restored == null:
		return
	_check(restored.snapshot() == before and restored.journal == journal,
		label + " restores the exact live generation and complete journal")
	_check(restored.phase == "visit" and str(restored.pending.get("service", "")) == "Peddler",
		label + " restores the still-open Peddler visit service")
	_check(restored.visit_actions() == choices, label + " restores the exact mounted choices")
	_check(stock != null and restored.pending.get("peddler_stock", null) == stock,
		label + " restores the exact sampled Peddler stock")
	_check(restored.gold == before.gold and restored.pockets == before.pockets
		and restored.rng.state == before.rng and restored.map.export_state() == before.map,
		label + " restores the exact wallet, pockets, RNG and route")


## AC1 map-phase restore: seal the current map generation through the junction's
## real Save, return to the title and restore it through a genuine Continue.
func _map_save_continue(app: Node, label: String, expected_pockets: Dictionary) -> bool:
	var session: StitchedRunSession = app.stitched_run_session
	if session == null or session.phase != "map":
		return false
	var owned := session.snapshot()
	var owned_journal := session.journal.duplicate(true)
	var save := app.stitched_run_buttons[session.choices().size()] as Button
	_check(save != null and save.text == "Save run" and not save.disabled,
		label + " junction remounts its real Save control")
	if save != null:
		save.pressed.emit()
		var sealed := StitchedRunSave.read_file(SAVE_PATH)
		var pockets_ok := sealed != null
		if sealed != null:
			for hero_id in expected_pockets:
				pockets_ok = pockets_ok and sealed.pockets[hero_id] == expected_pockets[hero_id]
		_check(sealed != null and sealed.snapshot() == owned
			and sealed.journal == owned_journal and pockets_ok,
			label + " junction Save publishes the exact owned generation")
	var return_button := app.stitched_run_buttons[session.choices().size() + 1] as Button
	_check(return_button != null and return_button.text == "Return to title",
		label + " junction mounts its real Return to title control")
	if return_button != null:
		return_button.pressed.emit()
	_check(app.stitched_run_session == null and app.title_view.is_visible_in_tree()
		and not app.stitched_continue_button.disabled,
		label + " Return to title keeps the sealed generation eligible for a genuine Continue")
	if app.stitched_run_session != null:
		return false
	app.stitched_continue_button.pressed.emit()
	var continued: StitchedRunSession = app.stitched_run_session
	var restored_pockets := continued != null
	if continued != null:
		for hero_id in expected_pockets:
			restored_pockets = restored_pockets and continued.pockets[hero_id] == expected_pockets[hero_id]
	_check(continued != null and continued.snapshot() == owned
		and continued.journal == owned_journal and restored_pockets
		and continued.rng.state == owned.rng and continued.gold == owned.gold,
		label + " title Continue restores the exact generation, wallet and RNG")
	return continued != null


## AC1 tonic case at the first genuine Shop: the failed-publish refusal, the
## exact open-visit Save/Reload generation, the corrupted-seal refusal and the
## real tonic purchase, then its owned generation through Return + Continue.
func _tonic_shop(app: Node) -> bool:
	if not await _await_controls(app, "visit", "Peddler"):
		return false
	var session: StitchedRunSession = app.stitched_run_session
	if session == null or session.phase != "visit" or str(session.pending.get("service", "")) != "Peddler":
		return false
	_check(session.map.get_node(str(session.pending.get("node_id", ""))).type == "Shop",
		"the first mounted stop is a genuine generated routed Shop")
	_check(session.gold >= 20, "three genuine victories fund both pocket-item purchases")
	var visit := session.snapshot()
	var journal := session.journal.duplicate(true)
	var choices := session.visit_actions()
	var stock: Variant = session.pending.get("peddler_stock", null)
	_check(not choices.is_empty() and stock != null,
		"the live Peddler visit has mounted choices and its sampled stock")
	var pair := _nav_pair(app)
	var save: Button = pair[0] if pair.size() == 2 else null
	var reload: Button = pair[1] if pair.size() == 2 else null
	_check(save != null and reload != null and not save.disabled and not reload.disabled,
		"the open Peddler visit mounts its real enabled Save and Reload controls")
	if save == null or reload == null:
		return false
	# The recorded intermittent mismatch, made deterministic: the sealed file
	# still holds the earlier map generation, and the next Save's publish is
	# forced to fail at its staging step. The Reload beside that failed Save
	# must refuse to substitute the stale sealed generation for the live visit.
	var sealed_bytes := FileAccess.get_file_as_bytes(SAVE_PATH)
	_check(not sealed_bytes.is_empty(), "the earlier junction Save sealed real bytes")
	var staged := SAVE_PATH + StitchedRunSave.STAGED_SUFFIX
	if DirAccess.dir_exists_absolute(staged) or DirAccess.make_dir_absolute(staged) == OK:
		save.pressed.emit()
		_check(FileAccess.get_file_as_bytes(SAVE_PATH) == sealed_bytes,
			"failed staged publish preserves the previously sealed save bytes")
		_check(session.snapshot() == visit and session.journal == journal
			and session.rng.state == visit.rng and session.gold == visit.gold,
			"failed Save press leaves the live visit, ledger, wallet and RNG untouched")
		reload.pressed.emit()
		_check(app.stitched_run_session == session and session.snapshot() == visit
			and session.journal == journal and session.rng.state == visit.rng
			and session.pockets == visit.pockets and session.gold == visit.gold,
			"the Reload beside a failed Save refuses to substitute the sealed map generation")
		_check(FileAccess.get_file_as_bytes(SAVE_PATH) == sealed_bytes,
			"the refused Reload never rewrites the sealed save file")
		DirAccess.remove_absolute(staged)
		_check(not DirAccess.dir_exists_absolute(staged),
			"the staging obstacle is removed before the genuine publish")
	else:
		_check(false, "staged-path directory obstacle was created")
	# The recorded refused-replace transient, made deterministic: a handle
	# held on the staged file makes the publish's replace refuse, and Windows'
	# replace unlinks the sealed target before the move, so the refusal must
	# restore the previously sealed generation instead of destroying it.
	# Where the platform still allows the held-handle replace, the genuine
	# publish itself is the required truthful outcome.
	var hold_writer := FileAccess.open(staged, FileAccess.WRITE)
	_check(hold_writer != null, "refused-replace witness stages a real file")
	if hold_writer != null:
		hold_writer.store_buffer(PackedByteArray([1]))
		hold_writer.close()
	var hold := FileAccess.open(staged, FileAccess.READ)
	_check(hold != null, "refused-replace witness holds the staged file open")
	var sealed_generation := StitchedRunSave.read_file(SAVE_PATH)
	_check(sealed_generation != null and sealed_generation.snapshot() != visit,
		"refused-replace witness starts from the sealed earlier generation")
	if hold != null:
		save.pressed.emit()
		if app._stitched_run_save_failed:
			_check(FileAccess.get_file_as_bytes(SAVE_PATH) == sealed_bytes,
				"refused replace preserves the previously sealed save bytes")
			var resealed := StitchedRunSave.read_file(SAVE_PATH)
			_check(resealed != null and resealed.snapshot() == sealed_generation.snapshot()
				and resealed.journal == sealed_generation.journal,
				"refused replace keeps the earlier sealed generation authenticated in the file")
			_check(session.snapshot() == visit and session.journal == journal
				and session.rng.state == visit.rng and session.gold == visit.gold,
				"refused replace leaves the live visit, ledger, wallet and RNG untouched")
			reload.pressed.emit()
			_check(app.stitched_run_session == session and session.snapshot() == visit
				and session.journal == journal and session.rng.state == visit.rng
				and session.pockets == visit.pockets and session.gold == visit.gold,
				"the Reload beside the refused replace cannot substitute the restored older generation")
			_check(FileAccess.get_file_as_bytes(SAVE_PATH) == sealed_bytes,
				"the refused Reload never rewrites the sealed save file")
		else:
			var held_publish := StitchedRunSave.read_file(SAVE_PATH)
			_check(held_publish != null and held_publish.snapshot() == visit
				and held_publish.journal == journal,
				"a held-handle replace the platform allows still publishes the exact live generation")
		hold.close()
		DirAccess.remove_absolute(staged)
		_check(not FileAccess.file_exists(staged),
			"the staged file is released before the genuine publish")
	# The genuine publish and the immediately following mounted Reload restore
	# the exact live open Peddler visit.
	save.pressed.emit()
	var published := StitchedRunSave.read_file(SAVE_PATH)
	_check(published != null and published.snapshot() == visit and published.journal == journal,
		"genuine Save publishes the exact live open Peddler generation")
	if published == null:
		return false
	_check(FileAccess.get_file_as_bytes(SAVE_PATH) != sealed_bytes,
		"the genuine publish replaces the earlier sealed generation's bytes")
	reload.pressed.emit()
	var restored: StitchedRunSession = app.stitched_run_session
	_check(restored != session, "mounted Reload publishes a restored session")
	_assert_exact_generation("open Peddler reload", restored, visit, journal, choices, stock)
	if not await _await_controls(app, "visit", "Peddler"):
		return false
	session = app.stitched_run_session
	# Corrupted sealed bytes fail closed through the mounted Reload.
	var genuine := FileAccess.get_file_as_bytes(SAVE_PATH)
	var forged := StitchedRunSave.capture(session)
	forged.journal.append({"action": "visit", "id": "buy_thimble_tonic",
		"arguments": [session.heroes[0].id]})
	forged.digest = StitchedRunSave._digest(forged)
	var forged_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	_check(forged_file != null, "corrupted seal is written through a real file handle")
	if forged_file != null:
		forged_file.store_buffer(var_to_bytes(forged))
		forged_file.close()
	var live_visit := session.snapshot()
	var live_journal := session.journal.duplicate(true)
	for button in _nav_controls(app):
		if button.text == "Reload saved run":
			button.pressed.emit()
	_check(app.stitched_run_session == session and session.snapshot() == live_visit
		and session.journal == live_journal and session.rng.state == live_visit.rng,
		"corrupted save cannot be substituted for the live visit through the mounted Reload")
	_check(FileAccess.get_file_as_bytes(SAVE_PATH) == var_to_bytes(forged),
		"the refused corrupted Reload leaves the corrupted bytes untouched for repair")
	var repair := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if repair != null:
		repair.store_buffer(genuine)
		repair.close()
	_check(FileAccess.get_file_as_bytes(SAVE_PATH) == genuine,
		"the genuine sealed bytes are restored before the real purchase")
	# The tonic pocket-item purchase itself.
	var buy := _visit_button(app, "buy_thimble_tonic", ["warden"])
	_check(buy != null and not buy.disabled and session.gold >= 10,
		"earned wallet and empty pocket admit the tonic purchase")
	if buy == null or buy.disabled:
		return false
	var pre_buy := session.snapshot()
	var old_nav := _nav_controls(app)
	buy.pressed.emit()
	var tonic_pockets: Dictionary = pre_buy.pockets.duplicate(true)
	tonic_pockets["warden"].append("thimble_tonic")
	_check(session.phase == "map" and session.gold == pre_buy.gold - 10
		and session.pockets == tonic_pockets and session.heroes == pre_buy.heroes
		and session.rng.state == pre_buy.rng and session.map.export_state() == pre_buy.map
		and session.journal.back() == {"action": "visit", "id": "buy_thimble_tonic", "arguments": ["warden"]},
		"one mounted tonic buy charges exactly 10 and adds one owned tonic")
	_reject_stale_nav(app, old_nav, "post-tonic remount")
	if not await _await_controls(app, "map"):
		return false
	return await _map_save_continue(app, "tonic-ownership", {"warden": ["thimble_tonic"]})


## AC1 stuffing case at the second genuine Shop: the exact open-visit
## Save/Reload generation, the real stuffing purchase and its owned generation.
func _stuffing_shop(app: Node) -> bool:
	if not await _await_controls(app, "visit", "Peddler"):
		return false
	var session: StitchedRunSession = app.stitched_run_session
	if session == null or session.phase != "visit" or str(session.pending.get("service", "")) != "Peddler":
		return false
	var visit := session.snapshot()
	var journal := session.journal.duplicate(true)
	var choices := session.visit_actions()
	var stock: Variant = session.pending.get("peddler_stock", null)
	var pair := _nav_pair(app)
	var save: Button = pair[0] if pair.size() == 2 else null
	var reload: Button = pair[1] if pair.size() == 2 else null
	_check(save != null and reload != null and not save.disabled and not reload.disabled,
		"the second Peddler visit mounts its real enabled Save and Reload controls")
	if save == null or reload == null:
		return false
	save.pressed.emit()
	var published := StitchedRunSave.read_file(SAVE_PATH)
	_check(published != null and published.snapshot() == visit and published.journal == journal,
		"second Shop Save publishes the exact live stuffing-side generation")
	if published == null:
		return false
	reload.pressed.emit()
	var restored: StitchedRunSession = app.stitched_run_session
	_check(restored != session, "mounted Reload publishes a restored session")
	_assert_exact_generation("stuffing-side reload", restored, visit, journal, choices, stock)
	if not await _await_controls(app, "visit", "Peddler"):
		return false
	session = app.stitched_run_session
	var buy := _visit_button(app, "buy_fresh_stuffing", ["seamstress"])
	_check(buy != null and not buy.disabled and session.gold >= 10,
		"earned wallet and empty pocket admit the stuffing purchase")
	if buy == null or buy.disabled:
		return false
	var pre_buy := session.snapshot()
	var old_nav := _nav_controls(app)
	buy.pressed.emit()
	var stuffing_pockets: Dictionary = pre_buy.pockets.duplicate(true)
	stuffing_pockets["seamstress"].append("fresh_stuffing")
	_check(session.phase == "map" and session.gold == pre_buy.gold - 10
		and session.pockets == stuffing_pockets
		and session.rng.state == pre_buy.rng
		and session.journal.back() == {"action": "visit", "id": "buy_fresh_stuffing", "arguments": ["seamstress"]},
		"one mounted stuffing buy charges exactly 10 and adds one owned stuffing")
	_reject_stale_nav(app, old_nav, "post-stuffing remount")
	if not await _await_controls(app, "map"):
		return false
	return await _map_save_continue(app, "both-ownership",
		{"warden": ["thimble_tonic"], "seamstress": ["fresh_stuffing"]})


func _generation_route() -> void:
	var app: Node = await _new_run(201)
	var session: StitchedRunSession = app.stitched_run_session
	if session == null:
		app.free()
		return
	app.stitched_save_path = SAVE_PATH
	var fights := 0
	var shops := 0
	var pre_sealed := false
	for id in ["f01_n1", "f02_n1", "f03_n1", "f04_n1", "f05_n1", "f06_n1", "f07_n0", "f08_n0"]:
		if not await _await_controls(app, "map"):
			break
		# Recapture the current session after the wait before any press.
		session = app.stitched_run_session
		if session == null or not session.choices().has(id):
			_check(false, "seeded connected route keeps " + id)
			break
		# The junction's own mounted Save seals the earned pre-visit generation
		# right before the first genuine Shop is entered.
		if shops == 0 and not pre_sealed and session.map.get_node(id).type == "Shop":
			pre_sealed = true
			var pre_map := session.snapshot()
			var pre_map_journal := session.journal.duplicate(true)
			var junction_save := app.stitched_run_buttons[session.choices().size()] as Button
			_check(junction_save != null and junction_save.text == "Save run" and not junction_save.disabled,
				"junction mounts its real enabled Save run control")
			if junction_save != null:
				junction_save.pressed.emit()
				var sealed_map := StitchedRunSave.read_file(SAVE_PATH)
				_check(sealed_map != null and sealed_map.snapshot() == pre_map
					and sealed_map.journal == pre_map_journal,
					"junction Save publishes the exact earned map generation")
		if not _press_route(app, id):
			break
		if session.phase == "battle":
			var stage: StitchedBattleScreen = app.stitched_run_battle
			_check(stage != null and stage.battle == session.battle,
				"real routed fight is mounted before earning the wallet")
			if stage == null:
				break
			var result := _win(stage)
			_check(result.acted > 0 and stage.battle.outcome() == "victory",
				"legal mounted combat earns the Peddler wallet")
			stage._action_buttons["exit"].pressed.emit()
			fights += 1
		elif session.phase == "visit" and str(session.pending.get("service", "")) == "Peddler":
			shops += 1
			if shops == 1:
				if not await _tonic_shop(app):
					break
			elif shops == 2:
				if not await _stuffing_shop(app):
					break
				break
			else:
				_check(false, "this focused witness only needs the first two Shops")
				break
		else:
			_check(_finish_visit(app) and session.phase == "map",
				"ordinary mounted stop continues the connected route")
	_check(fights == 3 and shops == 2,
		"three genuine victories and both pocket-item Shops exercised the save generation boundary")
	# Failed publishes preserve the previously sealed bytes exactly.
	session = app.stitched_run_session
	if session != null:
		var final_bytes := FileAccess.get_file_as_bytes(SAVE_PATH)
		_check(not StitchedRunSave.write_file(SAVE_PATH, null),
			"a null session cannot publish a save")
		_check(FileAccess.get_file_as_bytes(SAVE_PATH) == final_bytes,
			"null-session failed publish preserves the sealed bytes")
		session.pockets["tinker"].append("fresh_stuffing")
		_check(not session.is_consistent()
			and not StitchedRunSave.write_file(SAVE_PATH, session),
			"a save press from a broken sealed state cannot publish")
		_check(FileAccess.get_file_as_bytes(SAVE_PATH) == final_bytes,
			"failed publish from a broken state preserves the sealed bytes")
		session.pockets["tinker"].pop_back()
		_check(session.is_consistent(),
			"tamper probe restores its original exact state")
		_check(not StitchedRunSave.write_file(
			"user://missing_peddler_generation_%d/x.save" % OS.get_process_id(), session),
			"an unwritable save path fails its publish")
		_check(FileAccess.get_file_as_bytes(SAVE_PATH) == final_bytes,
			"the unwritable-path failure leaves the sealed save untouched")
	app.free()
	await process_frame


func _run() -> void:
	await _generation_route()
	DirAccess.remove_absolute(SAVE_PATH)
	var staged := SAVE_PATH + StitchedRunSave.STAGED_SUFFIX
	if DirAccess.dir_exists_absolute(staged):
		DirAccess.remove_absolute(staged)
	for message in failures:
		printerr(message)
	print("stitched_s6_peddler_save_generation_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
