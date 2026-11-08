extends "res://tests/stitched_s6_routed_vis_a_test.gd"
## Earned wallets and genuine generated Shops, driven through New Run controls.

## A parallel lane can run this same suite in another Godot process sharing
## the same user:// directory: a process-unique public save path keeps another
## lane's seals from racing this one's mounted Save/Reload/Continue generation.
var SAVE_PATH := "user://stitched_s7_routed_dye_live_%d.save" % OS.get_process_id()
const LiveWitness := preload("res://tests/live_witness.gd")
var wounded_purchases := 0


## A returned control must belong to the CURRENT generation: exact projection
## metadata, parentage, text and enabled state on the owned live page, so a
## retired or out-of-sync button is never handed back as a usable action.
func _visit_button(app: Node, id: String, arguments: Array = []) -> Button:
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
		+ _mount_evidence(app, "visit", str(session.pending.get("service", "")) if session != null else ""))
	return null


## Explicit wanted-versus-mounted evidence for a mount that did not hold:
## the CURRENT phase, node, service and page, every projected action and every
## mounted control, so a failed wait names the exact mismatched generation
## instead of leaving a later press to throw a SCRIPT ERROR on a stale button.
func _mount_evidence(app: Node, phase: String, service: String) -> String:
	var session: StitchedRunSession = app.stitched_run_session
	var text := "wanted phase=" + phase + " service=" + service + "; actual phase="
	if session == null:
		text += "null"
	else:
		text += str(session.phase)
		var names: Array = []
		var entries: Array = session.visit_actions() if session.phase == "visit" else session.choices()
		for entry in entries:
			if entry is Dictionary:
				names.append(str(entry.id) + str(entry.arguments) + ("on" if bool(entry.enabled) else "off"))
			else:
				names.append(str(entry))
		text += " node=" + str(session.map.get_current_node_id()) \
			+ " pending=" + str(session.pending).substr(0, 160) \
			+ " projected=" + str(names).substr(0, 360)
	var panel: Control = app.stitched_run_panel
	if not is_instance_valid(panel):
		text += " panel=none"
	else:
		text += " panel=" + str(panel.get_meta("page_kind", str(panel.name))) \
			+ " parented=" + str(panel.get_parent() == app) \
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


func _nav_pair_valid(panel: Control, buttons: Array[Button], first: int) -> bool:
	if buttons.size() < first + 2:
		return false
	var save: Button = buttons[first]
	var reload: Button = buttons[first + 1]
	return is_instance_valid(save) and is_instance_valid(reload) \
		and save.text == "Save run" and reload.text == "Reload saved run" \
		and not save.disabled and not reload.disabled \
		and save.is_visible_in_tree() and reload.is_visible_in_tree() \
		and panel.is_ancestor_of(save) and panel.is_ancestor_of(reload)


## The CURRENT generation's own page: an owned, visible page of the wanted phase
## and service whose projected actions or route tickets each have a live
## parented button with matching metadata, text and enabled state, plus its
## genuine Save/Reload pair. A replaced panel or foreign projection never passes.
func _mount_valid(app: Node, phase: String, service: String = "") -> bool:
	var session: StitchedRunSession = app.stitched_run_session
	if session == null or session.phase != phase:
		return false
	var panel: Control = app.stitched_run_panel
	if not is_instance_valid(panel) or not panel.is_visible_in_tree() or panel.get_parent() != app:
		return false
	var buttons: Array[Button] = app.stitched_run_buttons
	if phase == "visit":
		if str(session.pending.get("service", "")) != service \
				or str(session.pending.get("node_id", "")) != session.map.get_current_node_id() \
				or str(panel.get_meta("page_kind", "")) != "visit:" + service:
			return false
		var actions: Array = session.visit_actions()
		if actions.is_empty() or buttons.size() != actions.size() + 2:
			return false
		for index in actions.size():
			var button := buttons[index]
			if not is_instance_valid(button) or not panel.is_ancestor_of(button) \
					or not button.is_visible_in_tree() \
					or button.get_meta("action_id", "") != str(actions[index].id) \
					or button.get_meta("action_arguments", []) != actions[index].arguments \
					or button.text != str(actions[index].text) \
					or button.disabled == bool(actions[index].enabled):
				return false
		return _nav_pair_valid(panel, buttons, actions.size())
	if phase == "map" and str(panel.get_meta("page_kind", "")) == "map":
		var legal: Array = session.choices()
		if legal.is_empty() or buttons.size() != legal.size() + 2:
			return false
		for index in legal.size():
			var button := buttons[index]
			if not is_instance_valid(button) or not panel.is_ancestor_of(button) \
					or not button.is_visible_in_tree() or button.disabled \
					or button.get_meta("route_id", "") != str(legal[index]):
				return false
		return _nav_pair_valid(panel, buttons, legal.size())
	return false


## A synchronous transition swaps its generation at once, but under parallel
## lane load the replacement can take a later frame to become the owned
## visible projection of the CURRENT session. Bounded frame polling re-proves
## the whole generation every attempt; a timeout fails clearly with phase,
## node, service and projected-versus-mounted evidence and stops the branch.
func _await_mount(app: Node, phase: String, service: String = "", label: String = "") -> bool:
	for attempt in range(18):
		if _mount_valid(app, phase, service):
			return true
		await process_frame
	_check(false, (label if not label.is_empty() else "live " + phase + " " + service) \
		+ " never mounted its current generation within 18 frames; " \
		+ _mount_evidence(app, phase, service))
	return false


func _dye_controls(app: Node) -> void:
	if not await _await_mount(app, "visit", "Peddler", "Peddler dye controls"):
		return
	var session: StitchedRunSession = app.stitched_run_session
	_check(session.phase == "visit" and session.pending.service == "Peddler"
		and session.map.get_node(session.pending.node_id).type == "Shop",
		"fresh dye are mounted at a genuine generated routed Shop")
	_check(session.heroes.size() == 4 and session.pockets.size() == 4,
		"four canonical dolls have exactly four owned pockets")
	var count := 0
	for hero in session.heroes:
		_check(hero.id in StitchedPartyAdmission.HERO_IDS and session.pockets.has(hero.id),
			"pocket owner is the canonical selected hero")
		var button := _visit_button(app, "buy_dye", [hero.id])
		if button == null:
			continue
		count += 1
		var enabled: bool = not hero.lost and session.pockets[hero.id].size() < 2 and session.gold >= 10
		var projected: Array = session.visit_actions().filter(func(action: Dictionary):
			return action.id == "buy_dye" and action.arguments == [hero.id])
		_check(projected.size() == 1 and projected[0].enabled == enabled
			and projected[0].text == button.text and hero.name in button.text
			and button.get_meta("action_id") == "buy_dye"
			and button.get_meta("action_arguments") == [hero.id],
			"one session projection is mounted for the actual doll " + hero.id)
		_check(button.is_visible_in_tree() and button.focus_mode == Control.FOCUS_ALL
			and button.mouse_filter == Control.MOUSE_FILTER_STOP
			and button.disabled == not enabled and "10 gold" in button.text and "Dye" in button.text,
			"visible focusable 10-gold dye choice reflects lost/full/wallet for " + hero.id)
		if enabled:
			button.grab_focus()
			_check(button.has_focus() and not button.focus_next.is_empty(), "legal dye choice participates in keyboard focus")
		else:
			var before := session.snapshot()
			button.pressed.emit()
			_check(not session.choose_visit("buy_dye", [hero.id], before) and session.snapshot() == before,
				"disabled dye button and command preserve every ledger, route and RNG")
	_check(count == 4, "all four dye choices were actually inspected")
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


func _sealed_oracle(session: StitchedRunSession) -> Dictionary:
	# The expected journal and every nested state value belong to the ORIGINAL
	# owner, before Save. Never build expectations from a restored candidate.
	var state := session.snapshot().duplicate(true)
	var document := StitchedRunSave.capture(session).duplicate(true)
	return {
		"state": state,
		"journal": session.journal.duplicate(true),
		"actions": (session.visit_actions() if session.phase == "visit" else
			session.choices() if session.phase == "map" else []).duplicate(true),
		"phase": session.phase,
		"node": session.map.get_current_node_id(),
		"service": str(session.pending.get("service", "")),
		"document": document,
	}


func _oracle_differences(session: StitchedRunSession, oracle: Dictionary) -> Array[String]:
	var differences: Array[String] = []
	if session == null:
		differences.append("session is null")
		return differences
	var actual := session.snapshot()
	for key in oracle.state:
		if not actual.has(key) or actual[key] != oracle.state[key]:
			differences.append("%s: before=%s after=%s" % [key,
				str(oracle.state[key]).substr(0, 180), str(actual.get(key, "<missing>")).substr(0, 180)])
	for key in actual:
		if not oracle.state.has(key):
			differences.append("unexpected state key " + str(key))
	if session.journal != oracle.journal:
		differences.append("journal: before=%s after=%s" % [
			str(oracle.journal).substr(-280), str(session.journal).substr(-280)])
	if session.phase != oracle.phase:
		differences.append("phase: %s -> %s" % [oracle.phase, session.phase])
	if session.map.get_current_node_id() != oracle.node:
		differences.append("node: %s -> %s" % [oracle.node, session.map.get_current_node_id()])
	if str(session.pending.get("service", "")) != oracle.service:
		differences.append("service: %s -> %s" % [oracle.service, session.pending.get("service", "")])
	var actions: Array = session.visit_actions() if session.phase == "visit" else (
		session.choices() if session.phase == "map" else [])
	if actions != oracle.actions:
		differences.append("choices: before=%s after=%s" % [
			str(oracle.actions).substr(0, 240), str(actions).substr(0, 240)])
	if StitchedRunSave.capture(session) != oracle.document:
		differences.append("sealed capture/digest differs from pre-save journal and state")
	return differences


func _owned_mount(app: Node, phase: String) -> Dictionary:
	if app.stitched_run_session == null or app.stitched_run_session.phase != phase:
		return {}
	var page: Control = app.stitched_run_battle if phase == "battle" else app.stitched_run_panel
	if page == null or not is_instance_valid(page) or not page.is_visible_in_tree():
		return {}
	if phase == "battle":
		var save := page.get_node_or_null("SaveStitchedBattle") as Button
		if save == null or save.disabled or not save.is_visible_in_tree() 				or app.stitched_run_battle.battle != app.stitched_run_session.battle:
			return {}
		return {"page": page, "save": save, "reload": null}
	# The default title's Continue mounts the live corridor junction, not the
	# non-walking test runner's paper map. Its navigation offers Save/Title,
	# while every connected route choice must have its own active door.
	if phase == "map" and page is StitchedCorridorJunction:
		var junction := page as StitchedCorridorJunction
		var legal: Array = app.stitched_run_session.choices()
		if legal.is_empty() or junction.doors.size() != legal.size():
			return {}
		for id in legal:
			var door: Button = junction.doors.get(id)
			if door == null or door.disabled or not door.is_visible_in_tree() \
					or not app.stitched_run_buttons.has(door):
				return {}
		for button in app.stitched_run_buttons:
			if button is Button and button.text == "Save run" \
					and button.is_visible_in_tree() and not button.disabled \
					and button.get_parent() == junction:
				return {"page": page, "save": button, "reload": null}
		return {}
	var navigation := page.find_child("RunNavigation", true, false)
	if navigation == null or not navigation.is_visible_in_tree():
		return {}
	var save: Button = null
	var reload: Button = null
	for child in navigation.get_children():
		if not child is Button or not app.stitched_run_buttons.has(child) 				or child.disabled or not child.is_visible_in_tree():
			continue
		if child.text == "Save run":
			save = child
		elif child.text == "Reload saved run":
			reload = child
	if save == null or reload == null:
		return {}
	return {"page": page, "save": save, "reload": reload}


func _save_reload(app: Node, label: String, stale_button: Button = null) -> void:
	var original: StitchedRunSession = app.stitched_run_session
	_check(original != null and original.is_consistent()
		and original.phase in ["map", "visit", "battle"],
		label + " starts with a consistent live map, visit or battle owner")
	if original == null or not original.is_consistent() 			or not original.phase in ["map", "visit", "battle"]:
		return
	var oracle := _sealed_oracle(original)
	_check(not oracle.document.is_empty() and oracle.document.journal == oracle.journal
		and oracle.document.state == oracle.state,
		label + " seals an independent deep pre-Save state and journal oracle")
	if oracle.document.is_empty():
		return
	var mounted := _owned_mount(app, oracle.phase)
	_check(not mounted.is_empty(), label + " has the active " + oracle.phase
		+ " Save/Reload generation at " + str(oracle.node))
	if mounted.is_empty():
		return
	var old_page: Control = mounted.page
	var old_save: Button = mounted.save
	var old_reload: Button = mounted.reload
	app.stitched_save_path = SAVE_PATH
	# A prior phase's save must not masquerade as this generation's Save.
	DirAccess.remove_absolute(SAVE_PATH)
	old_save.pressed.emit()
	var disk := StitchedRunSave.read_file(SAVE_PATH)
	_check(disk != null and _oracle_differences(disk, oracle).is_empty(),
		label + " mounted Save writes exactly its pre-save owner (phase=%s node=%s)" % [
			oracle.phase, oracle.node])
	if disk == null:
		return
	# Battles mount Save but not Reload: exercise the same live public load
	# entry point directly after pressing the actual battle Save control.
	if oracle.phase == "battle":
		_check(app.load_stitched_run(SAVE_PATH), label + " live battle load accepts its saved fight")
	else:
		old_reload.pressed.emit()
	var reloaded: StitchedRunSession = app.stitched_run_session
	_check(reloaded != null and reloaded != original and reloaded != disk
		and app.stitched_run_panel != old_page if oracle.phase != "battle"
			else reloaded != null and reloaded != original and reloaded != disk
				and app.stitched_run_battle != old_page,
		label + " Reload publishes a NEW owner and replaces its old page")
	if reloaded == null or reloaded == original:
		return
	if stale_button != null:
		_check(is_instance_valid(stale_button),
			label + " retains its actual pre-Reload stale action for rejection")
		if is_instance_valid(stale_button):
			stale_button.pressed.emit()
			_check(_oracle_differences(reloaded, oracle).is_empty(),
				label + " old visit callback cannot change the new owner")
	# Retired Save callbacks must also be powerless after the ownership swap.
	if is_instance_valid(old_save):
		old_save.pressed.emit()
	_check(_oracle_differences(reloaded, oracle).is_empty()
		and _oracle_differences(StitchedRunSave.read_file(SAVE_PATH), oracle).is_empty(),
		label + " Reload/stale Save preserve phase, node, gold, pockets, journal, choices and RNG: "
			+ str(_oracle_differences(reloaded, oracle)))
	var fresh_mount: Dictionary = {}
	for attempt in range(8):
		fresh_mount = _owned_mount(app, oracle.phase)
		if app.stitched_run_session == reloaded and not fresh_mount.is_empty() 				and fresh_mount.page != old_page:
			break
		await process_frame
	_check(not fresh_mount.is_empty() and fresh_mount.page != old_page
		and app.stitched_run_session == reloaded,
		label + " replaces the visible " + oracle.phase + " controls within eight frames")
	_check(_oracle_differences(reloaded, oracle).is_empty(),
		label + " new mounted Reload owner matches sealed oracle: "
			+ str(_oracle_differences(reloaded, oracle)))
	var continued: Node = load("res://scenes/app.tscn").instantiate()
	continued.stitched_save_path = SAVE_PATH
	root.add_child(continued)
	for attempt in range(8):
		if continued.stitched_run_session == null and continued.title_view != null 				and continued.title_view.is_visible_in_tree() 				and continued.stitched_continue_button != null 				and continued.stitched_continue_button.is_visible_in_tree() 				and not continued.stitched_continue_button.disabled:
			break
		await process_frame
	var ready: bool = continued.stitched_run_session == null and continued.title_view != null 		and continued.title_view.is_visible_in_tree() and continued.stitched_continue_button != null 		and continued.stitched_continue_button.is_visible_in_tree() 		and not continued.stitched_continue_button.disabled
	_check(ready, label + " fresh title exposes an enabled saved-run Continue within eight frames")
	if ready:
		continued.stitched_continue_button.pressed.emit()
		var title_mount: Dictionary = {}
		for attempt in range(8):
			title_mount = _owned_mount(continued, oracle.phase)
			if continued.stitched_run_session != null and not title_mount.is_empty():
				break
			await process_frame
		var title_owner: StitchedRunSession = continued.stitched_run_session
		_check(title_owner != null and title_owner != original and title_owner != reloaded
			and not title_mount.is_empty() and _oracle_differences(title_owner, oracle).is_empty(),
			label + " title Continue restores a third owner and genuine " + oracle.phase
				+ " controls: " + str(_oracle_differences(title_owner, oracle)))
	continued.free()
	await process_frame


func _reject_choices(session: StitchedRunSession) -> void:
	var before := session.snapshot()
	var journal := session.journal.duplicate(true)
	for args in [[], ["unknown"], [""], [null], [7], [session.heroes[0].id, "extra"]]:
		_check(not session.choose_visit("buy_dye", args, before) and session.snapshot() == before
			and session.journal == journal, "forged dye arguments are atomic and RNG-neutral")
	for key in ["gold", "pockets", "rng", "pending", "map"]:
		var forged := before.duplicate(true)
		forged[key] = "forged"
		_check(not session.choose_visit("buy_dye", [session.heroes[0].id], forged)
			and session.snapshot() == before and session.journal == journal,
			"stale or forged " + key + " cannot authorize a purchase")
	var detached := session.snapshot()
	detached.pockets[session.heroes[0].id].append("dye")
	_check(session.snapshot() == before, "snapshot pockets are deeply detached")
	session.pockets[session.heroes[0].id].append("dye")
	_check(not session.is_consistent() and StitchedRunSave.capture(session).is_empty()
		and not session.choose_visit("buy_dye", [session.heroes[0].id], session.snapshot()),
		"direct pocket tampering fails the sealed state boundary")
	session.pockets[session.heroes[0].id].pop_back()
	_check(session.is_consistent() and session.snapshot() == before, "tamper probe restores its original exact state")


func _buy(app: Node, hero_id: String) -> void:
	if not await _await_mount(app, "visit", "Peddler", "dye buy for " + hero_id):
		return
	var session: StitchedRunSession = app.stitched_run_session
	var button := _visit_button(app, "buy_dye", [hero_id])
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
	_check(replay.choose_visit("buy_dye", [hero_id], replay.snapshot()),
		"restored session accepts the same public dye command")
	var journal_size := session.journal.size()
	var old_buttons: Array = app.stitched_run_buttons.duplicate()
	var old_actions := session.visit_actions()
	button.pressed.emit()
	var expected_pockets: Dictionary = before.pockets.duplicate(true)
	expected_pockets[hero_id].append("dye")
	_check(session.phase == "map" and session.gold == before.gold - 10
		and session.pockets == expected_pockets and session.heroes == before.heroes
		and session.candle == before.candle and session.scraps == before.scraps
		and session.satchel == before.satchel and session.patches == before.patches
		and session.rng.state == before.rng and session.map.export_state() == before.map
		and session.snapshot().kid_fear == before.kid_fear,
		"one mounted buy charges exactly 10 and adds one owned dye without unrelated mutations")
	_check(session.snapshot() == replay.snapshot() and session.journal == replay.journal,
		"mounted and public session purchases produce identical receipts and ledgers")
	for pocket in session.pockets.values():
		_check(pocket.size() <= 2, "every owned pocket stays within the two-item cap")
	_check(session.receipts.size() == before.receipts.size() + 1 and session.pending.is_empty()
		and session.journal.size() == journal_size + 1
		and session.journal.back() == {"action": "visit", "id": "buy_dye", "arguments": [hero_id]}
		and session.receipts.back().decision == "buy_dye" and session.receipts.back().steps.size() == 1,
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
	for ledger in [null, [], {}, {hero_id: ["dye"]}]:
		var corrupt := saved.duplicate(true)
		corrupt.state.pockets = ledger
		corrupt.digest = StitchedRunSave._digest(corrupt)
		_check(StitchedRunSave.restore(corrupt) == null, "malformed pocket save fails closed even with recomputed digest")
	for items in [["unknown"], ["dye", "dye", "dye"], [], ["fresh_stuffing"]]:
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
	for command in [null, {}, {"action": "visit", "id": "buy_dye", "arguments": ["unknown"]},
			{"action": "visit", "id": "buy_dye", "arguments": [hero_id], "price": 0},
			{"action": "enter", "node_id": "forged_shop"}]:
		var corrupt := saved.duplicate(true)
		corrupt.journal[-1] = command
		corrupt.digest = StitchedRunSave._digest(corrupt)
		_check(StitchedRunSave.restore(corrupt) == null and session.snapshot() == paid,
			"bad purchase journal fails closed without changing the live paid state")
	await _save_reload(app, "post-purchase map")


func _earned_cap_route() -> void:
	var app: Node = await _new_run(201)
	var session: StitchedRunSession = app.stitched_run_session
	if session == null:
		app.free()
		return
	var shops := 0
	var fights := 0
	var paid_buys := 0
	var paid_shop_ids: Array[String] = []
	for id in ["f01_n1", "f02_n1", "f03_n1", "f04_n1", "f05_n1", "f06_n1", "f07_n0", "f08_n0"]:
		if not await _await_mount(app, "map", "", "cap route to " + id):
			app.free()
			await process_frame
			return
		session = app.stitched_run_session
		_check(session.choices().has(id) and _press_route(app, id), "seeded connected control enters " + id)
		if session.phase == "battle":
			var stage: StitchedBattleScreen = app.stitched_run_battle
			_check(stage != null and stage.battle == session.battle, "real routed fight is mounted before earning gold")
			if stage == null:
				break
			var result := _win(stage)
			_check(result.acted > 0 and stage.battle.outcome() == "victory", "legal mounted combat earns the dye wallet")
			stage._action_buttons["exit"].pressed.emit()
			fights += 1
		elif session.phase == "visit" and session.pending.service == "Peddler":
			shops += 1
			await _dye_controls(app)
			_reject_choices(session)
			if shops <= 2:
				_check(fights == 3 and session.gold >= 10, "three genuine victories funded this purchase")
				var stale_button := _visit_button(app, "buy_dye", ["warden"])
				await _save_reload(app, "open Peddler", stale_button)
				session = app.stitched_run_session
				await _dye_controls(app)
				var before_paid := session.snapshot().duplicate(true)
				var journal_before := session.journal.size()
				var receipts_before := session.receipts.size()
				var shop_id: String = session.map.get_current_node_id()
				await _buy(app, "warden")
				session = app.stitched_run_session
				var expected_pockets: Dictionary = before_paid.pockets.duplicate(true)
				expected_pockets["warden"].append("dye")
				var paid_ok := false
				if session != null:
					paid_ok = (
						session.phase == "map" and session.gold == before_paid.gold - 10
						and session.pockets == expected_pockets
						and session.journal.size() == journal_before + 1
						and session.receipts.size() == receipts_before + 1
						and session.journal.back() == {"action": "visit", "id": "buy_dye", "arguments": ["warden"]}
						and session.receipts.back().decision == "buy_dye"
					)
				_check(paid_ok, "genuine Shop %s produces one paid 10-gold Warden Dye receipt" % shop_id)
				if paid_ok:
					paid_buys += 1
					paid_shop_ids.append(shop_id)
			else:
				_check(session.pockets.warden == ["dye", "dye"] and session.gold >= 10,
					"full-pocket refusal is witnessed with an otherwise affordable wallet")
				var before := session.snapshot()
				var leave_button := _visit_button(app, "leave")
				if leave_button == null:
					app.free()
					await process_frame
					return
				leave_button.pressed.emit()
				_check(session.phase == "map" and session.gold == before.gold and session.pockets == before.pockets
					and session.rng.state == before.rng and session.map.export_state() == before.map,
					"free Leave closes the full-pocket Shop without any spend or RNG draw")
		else:
			var stop_service := str(session.pending.get("service", ""))
			if not await _await_mount(app, "visit", stop_service, "ordinary stop " + id):
				app.free()
				await process_frame
				return
			_check(_finish_visit(app) and session.phase == "map", "ordinary mounted stop continues the connected route")
	var dye_entries: Array = session.journal.filter(func(command: Dictionary): return command.get("action") == "visit" and command.get("id") == "buy_dye" and command.get("arguments") == ["warden"])
	_check(paid_buys == 2 and paid_shop_ids.size() == 2 and paid_shop_ids[0] != paid_shop_ids[1]
		and dye_entries.size() == 2, "exactly two distinct authenticated Shops record paid Warden Dye")
	_check(shops == 3 and fights == 3 and session.pockets.warden == ["dye", "dye"],
		"three Shops and two earned purchases exercised the two-item cap non-vacuously")
	await _save_reload(app, "onward ownership")
	session = app.stitched_run_session
	var next_choices := session.choices()
	_check(not next_choices.is_empty(), "reloaded ownership has a legal onward node")
	if not next_choices.is_empty():
		var onward_pockets := session.pockets.duplicate(true)
		var onward_gold := session.gold
		var stale := session.snapshot()
		if not await _await_mount(app, "map", "", "onward ownership route"):
			app.free()
			await process_frame
			return
		_check(_press_route(app, next_choices[0]) and session.pockets == onward_pockets and session.gold == onward_gold,
			"continued real next-node play retains both owned dye")
		var entered := session.snapshot()
		_check(not session.choose_visit("buy_dye", ["warden"], stale)
			and not session.choose_visit("buy_dye", ["warden"], entered)
			and session.snapshot() == entered, "wrong-node dye callbacks cannot mutate the onward node")
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
		if not await _await_mount(app, "map", "", "poor Shop route"):
			app.free()
			await process_frame
			return
		_check(_press_route(app, witness.id) and session.gold == 0, "opening Shop has the normal empty wallet")
		await _dye_controls(app)
		var before := session.snapshot()
		var forged := StitchedRunSave.capture(session)
		forged.journal.append({"action": "visit", "id": "buy_dye", "arguments": [session.heroes[0].id]})
		forged.digest = StitchedRunSave._digest(forged)
		_check(StitchedRunSave.restore(forged) == null and session.snapshot() == before,
			"rehashed unaffordable purchase command fails replay without mutating the live visit")
		var old_dye := _visit_button(app, "buy_dye", [session.heroes[0].id])
		var leave_button := _visit_button(app, "leave")
		if leave_button == null:
			app.free()
			await process_frame
			return
		leave_button.pressed.emit()
		_check(session.phase == "map" and session.gold == 0 and session.pockets == before.pockets
			and session.rng.state == before.rng, "unaffordable Shop still has a free usable Leave")
		var left := session.snapshot()
		if old_dye != null:
			old_dye.pressed.emit()
			_check(not session.choose_visit("buy_dye", [session.heroes[0].id], before)
				and session.snapshot() == left, "Leave closes competing dye callbacks without any spend")
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
	if not await _await_mount(app, "map", "", "LOST roster route to its Shop"):
		app.free()
		await process_frame
		return
	_check(_press_route(app, str(witness.route[1])), "earned LOST roster reaches its connected Shop")
	if session.phase == "visit" and session.pending.service == "Peddler":
		await _dye_controls(app)
		await _save_reload(app, "LOST Peddler")
		session = app.stitched_run_session
		await _dye_controls(app)
		var living := session.heroes.filter(func(hero: Dictionary): return not hero.lost)
		_check(living.size() > 0 and session.heroes.any(func(hero: Dictionary): return hero.lost), "living and LOST controls both have witnesses")
		if not living.is_empty():
			await _buy(app, living[0].id)
			session = app.stitched_run_session
			if not await _await_mount(app, "map", "", "owned dye route to the Sewing Circle"):
				app.free()
				await process_frame
				return
			_check(session.choices().has(circle_id) and _press_route(app, circle_id)
				and session.pending.service == "SewingCircle", "owned dye continue into a genuine Sewing Circle")
			if not await _await_mount(app, "visit", "SewingCircle", "LOST Sewing Circle replacement"):
				app.free()
				await process_frame
				return
			var replacements := session.visit_actions().filter(func(action: Dictionary): return action.id == "replace" and action.enabled)
			_check(not replacements.is_empty(), "genuine LOST doll has a mounted replacement choice")
			if not replacements.is_empty():
				var action: Dictionary = replacements[0]
				var before := session.pockets.duplicate(true)
				var expected := before.duplicate(true)
				expected.erase(action.arguments[1])
				expected[action.arguments[0]] = []
				var replace_button := _visit_button(app, action.id, action.arguments)
				if replace_button == null:
					app.free()
					await process_frame
					return
				replace_button.pressed.emit()
				_check(session.pockets == expected and session.pockets.size() == 4
					and session.pockets[living[0].id] == ["dye"],
					"replacement removes the retired ID, starts an empty new pocket and preserves survivors' dye")
				await _save_reload(app, "replacement with owned dye")
				session = app.stitched_run_session
				_check(session.pockets == expected, "replacement pocket ownership replays by canonical ID")
	app.free()
	await process_frame


func _run() -> void:
	await _poor_shop()
	await _earned_cap_route()
	await _lost_shop()
	_check(wounded_purchases > 0, "dye purchase includes a genuinely wounded recipient without healing")
	DirAccess.remove_absolute(SAVE_PATH)
	for message in failures:
		printerr(message)
	print("stitched_s7_routed_dye_live_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
