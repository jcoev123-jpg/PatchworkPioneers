extends "res://tests/stitched_s6_routed_vis_a_test.gd"
## Earned wallets and genuine generated Shops, driven through New Run controls.

## Lane suites can execute this same test in different Godot processes at once;
## unique public save paths prevent cross-process seals from racing via user://.
var SAVE_PATH := "user://stitched_s6_routed_stuffing_live_%d.save" % OS.get_process_id()
const LiveWitness := preload("res://tests/live_witness.gd")
var wounded_purchases := 0


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


func _stuffing_controls(app: Node) -> void:
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.phase == "visit" and session.pending.service == "Peddler"
		and session.map.get_node(session.pending.node_id).type == "Shop",
		"fresh stuffing are mounted at a genuine generated routed Shop")
	if session == null:
		return
	_check(session.heroes.size() == 4 and session.pockets.size() == 4,
		"four canonical dolls have exactly four owned pockets")
	var count := 0
	for hero in session.heroes:
		_check(hero.id in StitchedPartyAdmission.HERO_IDS and session.pockets.has(hero.id),
			"pocket owner is the canonical selected hero")
		var button := _visit_button(app, "buy_fresh_stuffing", [hero.id])
		if button == null:
			continue
		count += 1
		var enabled: bool = not hero.lost and session.pockets[hero.id].size() < 2 and session.gold >= 10
		var projected: Array = session.visit_actions().filter(func(action: Dictionary):
			return action.id == "buy_fresh_stuffing" and action.arguments == [hero.id])
		_check(projected.size() == 1 and projected[0].enabled == enabled
			and projected[0].text == button.text and hero.name in button.text
			and button.get_meta("action_id") == "buy_fresh_stuffing"
			and button.get_meta("action_arguments") == [hero.id],
			"one session projection is mounted for the actual doll " + hero.id)
		_check(button.is_visible_in_tree() and button.focus_mode == Control.FOCUS_ALL
			and button.mouse_filter == Control.MOUSE_FILTER_STOP
			and button.disabled == not enabled and "10 gold" in button.text and "Fresh stuffing" in button.text,
			"visible focusable 10-gold stuffing choice reflects lost/full/wallet for " + hero.id)
		if enabled:
			button.grab_focus()
			_check(button.has_focus() and not button.focus_next.is_empty(), "legal stuffing choice participates in keyboard focus")
		else:
			var before := session.snapshot()
			button.pressed.emit()
			_check(not session.choose_visit("buy_fresh_stuffing", [hero.id], before) and session.snapshot() == before,
				"disabled stuffing button and command preserve every ledger, route and RNG")
	_check(count == 4, "all four stuffing choices were actually inspected")
	var leave := _visit_button(app, "leave")
	_check(leave != null and not leave.disabled and leave.focus_mode == Control.FOCUS_ALL,
		"free Leave remains enabled and keyboard reachable")
	_check(_visit_button(app, "buy_candle_stub") != null and _visit_button(app, "buy_part") != null,
		"the same Peddler retains candle and spare-part stock")
	for hero in session.heroes:
		_check(_visit_button(app, "buy_pins", [hero.id]) != null, "existing per-doll pins stock is intact")
		_check(_visit_button(app, "buy_thimble_tonic", [hero.id]) != null, "existing per-doll tonic stock is intact")
		if not hero.lost and int(hero.statuses.get("bleed", 0)) > 0 and session.gold >= 10:
			var bandage := _visit_button(app, "bandage", [hero.id])
			_check(bandage != null and not bandage.disabled, "existing eligible bandage remains buyable")


func _save_reload(app: Node, label: String, stale_button: Button = null) -> void:
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null, label + " has a real session to save")
	if session == null:
		return
	var phase := str(session.phase)
	var service := str(session.pending.get("service", "")) if phase == "visit" else ""
	# The sealed-file witness is acquired only against the generation that is
	# current when Save is pressed: a capture taken before the awaited controls
	# can go stale across the wait, so each branch reads the snapshot, journal
	# and choices after its own wait, never from a pre-await capture.
	var before: Dictionary = {}
	var journal: Array = []
	var choices: Array = []
	app.stitched_save_path = SAVE_PATH
	if phase == "battle":
		# Battle has its own public Save, not the map/visit button array; no
		# await precedes that press, so its witness is the live session itself.
		before = session.snapshot()
		journal = session.journal.duplicate(true)
		var stage: StitchedBattleScreen = app.stitched_run_battle
		var battle_save := stage.get_node_or_null("SaveStitchedBattle") as Button if is_instance_valid(stage) else null
		_check(is_instance_valid(stage) and stage.battle == session.battle
			and battle_save != null and battle_save.is_visible_in_tree() and not battle_save.disabled,
			label + " saves from the actual mounted onward battle")
		if battle_save == null:
			return
		battle_save.pressed.emit()
	elif phase in ["map", "visit"]:
		if not await _await_controls(app, phase, service):
			return
		# The wait may span a remount: reject generation drift before Save.
		# The awaited session, phase, service and parented page must still be
		# this exact generation, so an invalid or outdated page generation can
		# never supply the save witness, and no stale pre-await capture is ever
		# asserted against; explicit evidence names the exact mismatch.
		var live: StitchedRunSession = app.stitched_run_session
		var panel: Control = app.stitched_run_panel
		var mounted: bool = live == session and live.phase == phase \
			and (phase != "visit" or str(live.pending.get("service", "")) == service) \
			and is_instance_valid(panel) and panel.get_parent() == app
		_check(mounted, label + " saves the same mounted generation it awaited; "
			+ _controls_evidence(app, "wanted the awaited phase=" + phase + " service=" + service + " generation"))
		if not mounted:
			return
		# Complete current-generation witness, acquired after the await against
		# the mounted, parented page and its verified Save/Reload buttons: the
		# sealed file must replay exactly this snapshot, journal and choices.
		before = live.snapshot()
		journal = live.journal.duplicate(true)
		choices = live.visit_actions() if phase == "visit" else live.choices()
		var count := choices.size()
		var usable: bool = app.stitched_run_buttons.size() >= count + 2
		var save: Button = app.stitched_run_buttons[count] if usable else null
		var secondary: Button = app.stitched_run_buttons[count + 1] if usable else null
		if usable:
			usable = is_instance_valid(save) and is_instance_valid(secondary) \
				and save.text == "Save run" and secondary.text == (
					"Return to title" if phase == "map" else "Reload saved run") \
				and not save.disabled and not secondary.disabled \
				and save.is_visible_in_tree() and secondary.is_visible_in_tree() \
				and panel.is_ancestor_of(save) and panel.is_ancestor_of(secondary)
		_check(usable, label + " uses the phase-correct visible Save and navigation controls; "
			+ _controls_evidence(app, "wanted phase=" + phase + " service=" + service + " Save controls"))
		if not usable:
			return
		save.pressed.emit()
		_check(FileAccess.file_exists(SAVE_PATH), label + " creates its public save")
		if not FileAccess.file_exists(SAVE_PATH):
			return
		# Existence alone cannot tell a fresh seal from an older run's stale file:
		# prove the file now holds THIS generation's exact state before the
		# Reload/Return press may load it.
		var sealed: StitchedRunSession = StitchedRunSave.read_file(SAVE_PATH)
		_check(sealed != null and sealed.snapshot() == before and sealed.journal == journal,
			label + " seals the current generation into its public save; "
			+ _controls_evidence(app, "wanted the sealed file to hold phase=" + phase + " service=" + service))
		if sealed == null or sealed.snapshot() != before or sealed.journal != journal:
			return
		if phase == "map":
			secondary.pressed.emit()
			_check(app.stitched_run_session == null and app.title_view.is_visible_in_tree()
				and app.stitched_continue_button.is_visible_in_tree()
				and not app.stitched_continue_button.disabled
				and session.snapshot() == before,
				label + " Return to title detaches the map without changing the saved run")
			if app.stitched_run_session != null:
				return
			app.stitched_continue_button.pressed.emit()
		else:
			secondary.pressed.emit()
		var current: StitchedRunSession = app.stitched_run_session
		_check(current != null and current != session and current.snapshot() == before
			and current.journal == journal and current.gold == before.gold
			and current.pockets == before.pockets and current.rng.state == before.rng
			and current.map.get_route() == session.map.get_route()
			and (current.visit_actions() if phase == "visit" else current.choices()) == choices,
			label + " replaces the live session with identical wallet, pockets, route, RNG, choices and journal; "
			+ _controls_evidence(app, "wanted the reload to restore phase=" + phase + " service=" + service))
		if current == null:
			return
		if stale_button != null and is_instance_valid(stale_button):
			stale_button.pressed.emit()
			_check(current.snapshot() == before and current.journal == journal,
				"pre-remount callback cannot authorize the restored visit")
		_check(await _await_controls(app, phase, service),
			label + " re-mounts valid, visible, matching controls")
	else:
		_check(false, label + " has a supported map, visit or battle save phase")
		return
	var from_file := StitchedRunSave.read_file(SAVE_PATH)
	_check(from_file != null and from_file != session and from_file.snapshot() == before
		and from_file.journal == journal, label + " sealed public file replays the exact saved state")
	if from_file == null:
		return
	var continued: Node = load("res://scenes/app.tscn").instantiate()
	continued.stitched_save_path = SAVE_PATH
	root.add_child(continued)
	await process_frame
	var title_ready: bool = continued.stitched_run_session == null and continued.title_view.is_visible_in_tree() \
		and continued.stitched_continue_button.is_visible_in_tree() \
		and not continued.stitched_continue_button.disabled
	_check(title_ready, label + " fresh app exposes valid title Continue; "
		+ _controls_evidence(continued, "wanted fresh title Continue"))
	if title_ready:
		continued.stitched_continue_button.pressed.emit()
		var from_title: StitchedRunSession = continued.stitched_run_session
		_check(from_title != null and from_title != session and from_title != app.stitched_run_session
			and from_title.snapshot() == before and from_title.journal == journal
			and from_title.gold == before.gold and from_title.pockets == before.pockets
			and from_title.rng.state == before.rng
			and from_title.map.get_route() == session.map.get_route()
			and (phase == "battle" or (
				(from_title.visit_actions() if phase == "visit" else from_title.choices()) == choices)),
			label + " fresh title Continue restores exact ownership, route, RNG, choices and journal")
		if phase in ["map", "visit"] and from_title != null:
			_check(await _await_controls(continued, phase, service),
				label + " fresh title Continue mounts its own valid route/visit controls")
		elif phase == "battle" and from_title != null:
			_check(continued.stitched_run_battle != null
				and continued.stitched_run_battle.battle == from_title.battle,
				label + " fresh title Continue mounts the resumed real onward battle")
	continued.free()
	await process_frame


func _reject_choices(session: StitchedRunSession) -> void:
	var before := session.snapshot()
	var journal := session.journal.duplicate(true)
	for args in [[], ["unknown"], [""], [null], [7], [session.heroes[0].id, "extra"]]:
		_check(not session.choose_visit("buy_fresh_stuffing", args, before) and session.snapshot() == before
			and session.journal == journal, "forged stuffing arguments are atomic and RNG-neutral")
	for key in ["gold", "pockets", "rng", "pending", "map"]:
		var forged := before.duplicate(true)
		forged[key] = "forged"
		_check(not session.choose_visit("buy_fresh_stuffing", [session.heroes[0].id], forged)
			and session.snapshot() == before and session.journal == journal,
			"stale or forged " + key + " cannot authorize a purchase")
	var detached := session.snapshot()
	detached.pockets[session.heroes[0].id].append("fresh_stuffing")
	_check(session.snapshot() == before, "snapshot pockets are deeply detached")
	session.pockets[session.heroes[0].id].append("fresh_stuffing")
	_check(not session.is_consistent() and StitchedRunSave.capture(session).is_empty()
		and not session.choose_visit("buy_fresh_stuffing", [session.heroes[0].id], session.snapshot()),
		"direct pocket tampering fails the sealed state boundary")
	session.pockets[session.heroes[0].id].pop_back()
	_check(session.is_consistent() and session.snapshot() == before, "tamper probe restores its original exact state")


func _buy(app: Node, hero_id: String) -> void:
	if not await _await_controls(app, "visit", "Peddler"):
		return
	# Recapture the current generation after the wait: every later check and
	# press must refer to the live session, not a pre-await capture.
	var session: StitchedRunSession = app.stitched_run_session
	var button := _visit_button(app, "buy_fresh_stuffing", [hero_id])
	_check(button != null and not button.disabled and session.gold >= 10, "earned wallet and living pocket admit a real buy")
	if button == null or button.disabled:
		return
	var before := session.snapshot()
	for hero in session.heroes:
		if hero.id == hero_id and hero.hp < hero.max_hp:
			wounded_purchases += 1
	var replay := StitchedRunSave.restore(StitchedRunSave.capture(session))
	_check(replay != null and replay.snapshot() == before, "public purchase comparison starts from an authentic replay")
	if replay == null:
		return
	_check(replay.choose_visit("buy_fresh_stuffing", [hero_id], replay.snapshot()),
		"restored session accepts the same public stuffing command")
	var journal_size := session.journal.size()
	var old_buttons: Array = app.stitched_run_buttons.duplicate()
	var old_actions := session.visit_actions()
	button.pressed.emit()
	var expected_pockets: Dictionary = before.pockets.duplicate(true)
	expected_pockets[hero_id].append("fresh_stuffing")
	_check(session.phase == "map" and session.gold == before.gold - 10
		and session.pockets == expected_pockets and session.heroes == before.heroes
		and session.candle == before.candle and session.scraps == before.scraps
		and session.satchel == before.satchel and session.patches == before.patches
		and session.rng.state == before.rng and session.map.export_state() == before.map
		and session.snapshot().kid_fear == before.kid_fear,
		"one mounted buy charges exactly 10 and adds one owned stuffing without unrelated mutations")
	_check(session.snapshot() == replay.snapshot() and session.journal == replay.journal,
		"mounted and public session purchases produce identical receipts and ledgers")
	for pocket in session.pockets.values():
		_check(pocket.size() <= 2, "every owned pocket stays within the two-item cap")
	_check(session.receipts.size() == before.receipts.size() + 1 and session.pending.is_empty()
		and session.journal.size() == journal_size + 1
		and session.journal.back() == {"action": "visit", "id": "buy_fresh_stuffing", "arguments": [hero_id]}
		and session.receipts.back().decision == "buy_fresh_stuffing" and session.receipts.back().steps.size() == 1,
		"buy closes and authenticates exactly one journal entry and one node receipt")
	var paid := session.snapshot()
	for index in old_actions.size():
		old_buttons[index].pressed.emit()
		_check(not session.choose_visit(old_actions[index].id, old_actions[index].arguments, before)
			and not session.choose_visit(old_actions[index].id, old_actions[index].arguments, paid)
			and session.snapshot() == paid and session.journal.size() == journal_size + 1,
			"repeated and competing stock/Leave callbacks cannot spend, change pockets, route or RNG")
	var saved := StitchedRunSave.capture(session)
	var restored := StitchedRunSave.restore(saved)
	_check(restored != null and restored.snapshot() == paid, "purchased ownership survives deterministic replay")
	for ledger in [null, [], {}, {hero_id: ["fresh_stuffing"]}]:
		var corrupt := saved.duplicate(true)
		corrupt.state.pockets = ledger
		corrupt.digest = StitchedRunSave._digest(corrupt)
		_check(StitchedRunSave.restore(corrupt) == null, "malformed pocket save fails closed even with recomputed digest")
	for items in [["unknown"], ["fresh_stuffing", "fresh_stuffing", "fresh_stuffing"], [], ["dye"]]:
		var corrupt := saved.duplicate(true)
		corrupt.state.pockets[hero_id] = items
		corrupt.digest = StitchedRunSave._digest(corrupt)
		_check(StitchedRunSave.restore(corrupt) == null, "forged ownership cannot replace the replayed purchase ledger")
	for without_fear in [false, true]:
		var legacy := saved.duplicate(true)
		legacy.state.erase("pockets")
		if without_fear:
			legacy.state.erase("kid_fear")
		legacy.digest = StitchedRunSave._digest(legacy)
		_check(StitchedRunSave.restore(legacy) == null, "omitting pockets cannot disguise a new purchase as an old save")
	var pre_fear := saved.duplicate(true)
	pre_fear.state.erase("kid_fear")
	pre_fear.digest = StitchedRunSave._digest(pre_fear)
	var migrated := StitchedRunSave.restore(pre_fear)
	_check(migrated != null and migrated.snapshot() == paid, "pre-fear migration reconstructs purchased pockets and exact settled fear")
	var doubled := saved.duplicate(true)
	doubled.journal.append(doubled.journal.back().duplicate(true))
	doubled.digest = StitchedRunSave._digest(doubled)
	_check(StitchedRunSave.restore(doubled) == null, "replayed duplicate purchase fails closed")
	for command in [null, {}, {"action": "visit", "id": "buy_fresh_stuffing", "arguments": ["unknown"]},
			{"action": "visit", "id": "buy_fresh_stuffing", "arguments": [hero_id], "price": 0},
			{"action": "enter", "node_id": "forged_shop"}]:
		var corrupt := saved.duplicate(true)
		corrupt.journal[-1] = command
		corrupt.digest = StitchedRunSave._digest(corrupt)
		_check(StitchedRunSave.restore(corrupt) == null and session.snapshot() == paid,
			"bad purchase journal fails closed without changing the live paid state")
	await _save_reload(app, "post-purchase map")


## AC1 regression: remount the SAME visit without any state change, emit the old
## purchase and Leave buttons, and prove no phase, wallet, pocket, RNG, receipt or
## journal mutation; the freshly remounted controls then finish the real scenario.
func _remount_same_visit(app: Node) -> void:
	if not await _await_controls(app, "visit", "Peddler"):
		return
	var session: StitchedRunSession = app.stitched_run_session
	if session == null or session.phase != "visit" or str(session.pending.get("service", "")) != "Peddler":
		return
	var before := session.snapshot()
	var journal := session.journal.duplicate(true)
	var rng_state := session.rng.state
	var wallet := session.gold
	var pockets := session.pockets.duplicate(true)
	var receipts := session.receipts.duplicate(true)
	var old_page: Control = app.stitched_run_panel
	var old_buttons: Array = app.stitched_run_buttons.duplicate()
	var old_buy := _visit_button(app, "buy_fresh_stuffing", ["warden"])
	var old_leave := _visit_button(app, "leave")
	_check(old_buy != null and not old_buy.disabled and wallet >= 10,
		"earned Peddler mounts an enabled old purchase control before the remount")
	_check(old_leave != null and not old_leave.disabled,
		"earned Peddler mounts an enabled old Leave control before the remount")
	if old_buy == null or old_leave == null:
		return
	# Remount the very same visit: the session object and its sealed snapshot stay.
	app._present_stitched_run()
	_check(app.stitched_run_session == session and session.snapshot() == before and session.journal == journal,
		"same-visit remount keeps the original session and sealed snapshot unchanged")
	_check(is_instance_valid(app.stitched_run_panel) and app.stitched_run_panel != old_page
		and app.stitched_run_panel.is_visible_in_tree() and app.stitched_run_panel.get_parent() == app,
		"the remount mounted a genuinely fresh attached page over the old one")
	# The detached pre-remount controls are still retained objects: emit them all,
	# then the old purchase and Leave again, before any deferred freeing.
	for button in old_buttons:
		if is_instance_valid(button):
			button.pressed.emit()
	old_buy.pressed.emit()
	old_leave.pressed.emit()
	_check(session.phase == "visit" and str(session.pending.get("service", "")) == "Peddler"
		and session.snapshot() == before and session.journal == journal
		and session.gold == wallet and session.pockets == pockets
		and session.rng.state == rng_state and session.receipts == receipts
		and session.map.export_state() == before.map,
		"detached purchase and Leave buttons cannot mutate phase, wallet, pockets, RNG, receipts or journal")
	_check(await _await_controls(app, "visit", "Peddler"),
		"the remounted same visit mounts fresh valid controls")
	session = app.stitched_run_session
	var fresh_buy := _visit_button(app, "buy_fresh_stuffing", ["warden"])
	var fresh_leave := _visit_button(app, "leave")
	_check(fresh_buy != null and fresh_leave != null and fresh_buy != old_buy and fresh_leave != old_leave
		and not fresh_buy.disabled and not fresh_leave.disabled
		and not app.stitched_run_buttons.has(old_buy) and not app.stitched_run_buttons.has(old_leave),
		"fresh purchase and Leave controls replace the detached pre-remount ones")
	_check(session.phase == "visit" and session.snapshot() == before and session.journal == journal,
		"reacquiring the fresh controls changes nothing; the real buys press them next")


func _earned_cap_route() -> void:
	var app: Node = await _new_run(201)
	var session: StitchedRunSession = app.stitched_run_session
	if session == null:
		app.free()
		return
	var shops := 0
	var fights := 0
	for id in ["f01_n1", "f02_n1", "f03_n1", "f04_n1", "f05_n1", "f06_n1", "f07_n0", "f08_n0"]:
		if not await _await_controls(app, "map"):
			break
		# Recapture the current session after the wait before any press.
		session = app.stitched_run_session
		_check(session != null and session.choices().has(id) and _press_route(app, id), "seeded connected control enters " + id)
		if session.phase == "battle":
			var stage: StitchedBattleScreen = app.stitched_run_battle
			_check(stage != null and stage.battle == session.battle, "real routed fight is mounted before earning gold")
			if stage == null:
				break
			var result := _win(stage)
			_check(result.acted > 0 and stage.battle.outcome() == "victory", "legal mounted combat earns the stuffing wallet")
			stage._action_buttons["exit"].pressed.emit()
			fights += 1
		elif session.phase == "visit" and session.pending.service == "Peddler":
			if not await _await_controls(app, "visit", "Peddler"):
				break
			session = app.stitched_run_session
			shops += 1
			_stuffing_controls(app)
			_reject_choices(session)
			if shops == 1:
				await _remount_same_visit(app)
				session = app.stitched_run_session
			if shops <= 2:
				_check(fights == 3 and session.gold >= 10, "three genuine victories funded this purchase")
				var stale_button := _visit_button(app, "buy_fresh_stuffing", ["warden"])
				await _save_reload(app, "open Peddler", stale_button)
				session = app.stitched_run_session
				_stuffing_controls(app)
				await _buy(app, "warden")
				session = app.stitched_run_session
			else:
				_check(session.pockets.warden == ["fresh_stuffing", "fresh_stuffing"] and session.gold >= 10,
					"full-pocket refusal is witnessed with an otherwise affordable wallet")
				var before := session.snapshot()
				var leave := _visit_button(app, "leave")
				if leave != null:
					leave.pressed.emit()
				_check(session.phase == "map" and session.gold == before.gold and session.pockets == before.pockets
					and session.rng.state == before.rng and session.map.export_state() == before.map,
					"free Leave closes the full-pocket Shop without any spend or RNG draw")
		else:
			_check(_finish_visit(app) and session.phase == "map", "ordinary mounted stop continues the connected route")
	_check(shops == 3 and fights == 3 and session.pockets.warden == ["fresh_stuffing", "fresh_stuffing"],
		"three Shops and two earned purchases exercised the two-item cap non-vacuously")
	await _save_reload(app, "onward ownership")
	session = app.stitched_run_session
	var next_choices := session.choices()
	_check(not next_choices.is_empty(), "reloaded ownership has a legal onward node")
	if not next_choices.is_empty():
		var onward_pockets := session.pockets.duplicate(true)
		var onward_gold := session.gold
		var stale := session.snapshot()
		_check(_press_route(app, next_choices[0]) and session.pockets == onward_pockets and session.gold == onward_gold,
			"continued real next-node play retains both owned stuffing")
		var entered := session.snapshot()
		_check(not session.choose_visit("buy_fresh_stuffing", ["warden"], stale)
			and not session.choose_visit("buy_fresh_stuffing", ["warden"], entered)
			and session.snapshot() == entered, "wrong-node stuffing callbacks cannot mutate the onward node")
		var restored := StitchedRunSave.restore(StitchedRunSave.capture(session))
		_check(restored != null and restored.snapshot() == session.snapshot(), "onward state replays with exact ownership")
		await _save_reload(app, "entered onward node")
	app.free()
	await process_frame


func _poor_shop() -> void:
	var witness := _seed_with_kind("Shop")
	_check(not witness.is_empty(), "unaffordable witness has a genuine seeded opening Shop")
	if witness.is_empty():
		return
	var app: Node = await _new_run(witness.seed)
	var session: StitchedRunSession = app.stitched_run_session
	if session != null:
		_check(await _await_controls(app, "map"), "unaffordable opening has fresh mounted route controls")
		session = app.stitched_run_session
		_check(_press_route(app, witness.id) and session.gold == 0, "opening Shop has the normal empty wallet")
		_check(await _await_controls(app, "visit", "Peddler"), "unaffordable Shop has fresh mounted choices")
		session = app.stitched_run_session
		_stuffing_controls(app)
		var before := session.snapshot()
		var forged := StitchedRunSave.capture(session)
		forged.journal.append({"action": "visit", "id": "buy_fresh_stuffing", "arguments": [session.heroes[0].id]})
		forged.digest = StitchedRunSave._digest(forged)
		_check(StitchedRunSave.restore(forged) == null and session.snapshot() == before,
			"rehashed unaffordable purchase command fails replay without mutating the live visit")
		var old_stuffing := _visit_button(app, "buy_fresh_stuffing", [session.heroes[0].id])
		var leave := _visit_button(app, "leave")
		if leave != null:
			leave.pressed.emit()
		_check(session.phase == "map" and session.gold == 0 and session.pockets == before.pockets
			and session.rng.state == before.rng, "unaffordable Shop still has a free usable Leave")
		var left := session.snapshot()
		old_stuffing.pressed.emit()
		_check(not session.choose_visit("buy_fresh_stuffing", [session.heroes[0].id], before)
			and session.snapshot() == left, "Leave closes competing stuffing callbacks without any spend")
	app.free()
	await process_frame


func _lost_shop() -> void:
	# The LOST witness is searched at run time (owner 11-08): the first opening Fight -> Shop -> Sewing
	# Circle route whose mounted Fight loses exactly one doll to enemy turns and is won afterwards.
	var witness := await LiveWitness.lost_fight(self)
	_check(not witness.is_empty(), "enemy turns genuinely lose a doll before the survivors win")
	if witness.is_empty():
		return
	var app: Node = witness.app
	var session: StitchedRunSession = app.stitched_run_session
	var circle_id := str(witness.route[2])
	_check(await _await_controls(app, "map"), "post-LOST battle mounts fresh route controls")
	session = app.stitched_run_session
	_check(_press_route(app, str(witness.route[1])), "earned LOST roster reaches its connected Shop")
	if session.phase == "visit" and session.pending.service == "Peddler":
		_check(await _await_controls(app, "visit", "Peddler"), "LOST Shop mounts fresh choice controls")
		session = app.stitched_run_session
		_stuffing_controls(app)
		await _save_reload(app, "LOST Peddler")
		session = app.stitched_run_session
		_stuffing_controls(app)
		var living := session.heroes.filter(func(hero: Dictionary): return not hero.lost)
		_check(living.size() > 0 and session.heroes.any(func(hero: Dictionary): return hero.lost), "living and LOST controls both have witnesses")
		if not living.is_empty():
			await _buy(app, living[0].id)
			session = app.stitched_run_session
			_check(session.choices().has(circle_id) and _press_route(app, circle_id)
				and session.pending.service == "SewingCircle", "owned stuffing continue into a genuine Sewing Circle")
			var replacements := session.visit_actions().filter(func(action: Dictionary): return action.id == "replace" and action.enabled)
			_check(not replacements.is_empty(), "genuine LOST doll has a mounted replacement choice")
			if not replacements.is_empty():
				var action: Dictionary = replacements[0]
				var before := session.pockets.duplicate(true)
				var expected := before.duplicate(true)
				expected.erase(action.arguments[1])
				expected[action.arguments[0]] = []
				var replace_button := _visit_button(app, action.id, action.arguments)
				if replace_button != null:
					replace_button.pressed.emit()
				_check(session.pockets == expected and session.pockets.size() == 4
					and session.pockets[living[0].id] == ["fresh_stuffing"],
					"replacement removes the retired ID, starts an empty new pocket and preserves survivors' stuffing")
				await _save_reload(app, "replacement with owned stuffing")
				session = app.stitched_run_session
				_check(session.pockets == expected, "replacement pocket ownership replays by canonical ID")
	app.free()
	await process_frame


func _run() -> void:
	await _poor_shop()
	await _earned_cap_route()
	await _lost_shop()
	_check(wounded_purchases > 0, "no-heal purchase checks include a genuinely wounded recipient")
	DirAccess.remove_absolute(SAVE_PATH)
	for message in failures:
		printerr(message)
	print("stitched_s6_routed_stuffing_live_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
