extends "res://tests/stitched_s6_full_run_test.gd"
## Genuine seeded map -> ranked victory -> spare purchase -> Moth.

## Lane suites can execute this same test in different Godot processes at once;
## unique public save paths prevent cross-process seals from racing via user://.
var SAVE_PATH := "user://stitched_s7_moth_sacrifice_live_%d.save" % OS.get_process_id()
# This seed's mounted run wins f01_n1 with a real drop and one scrap, buys a distinct
# second spare at the f02_n0 Peddler, and enters the f03_n0 Event (pinned to the Moth).
# Re-derived for the S14 fixed kits: the old 588735 fight no longer rolls a part drop.
const RICH_SEED := 25
# The genuine unpinned floor-one Moth is searched at run time from seed 3242 (owner 11-08): each Event
# pack shifts the selector, and with ~140 Events a 64-seed window often missed it.
const LiveWitness := preload("res://tests/live_witness.gd")
const POOR_SEED := 3242
const FIRST_NODE := "f01_n1"
const SHOP_NODE := "f02_n0"
const MOTH_NODE := "f03_n0"
const POOR_SEARCH := 4000
var settled_branches := 0


func _button(app: Node, id: String, arguments: Array = []) -> Button:
	var actions: Array = app.stitched_run_session.visit_actions()
	for index in actions.size():
		if actions[index].id == id and actions[index].arguments == arguments:
			return app.stitched_run_buttons[index]
	_check(false, "real Moth button exists: " + id + str(arguments))
	return null


func _controls(app: Node) -> void:
	var session: StitchedRunSession = app.stitched_run_session
	if session == null:
		_check(false, "Moth control page needs the actual mounted owner, not a null session")
		return
	_check(session.phase == "visit" and session.pending.get("event_id") == "moth_infestation"
		and session.pending.service == "Event"
		and session.map.get_node(session.pending.node_id).type == "Event",
		"authoritative selected Moth is mounted at a genuine generated Event")
	_check(session._service is RunStitchedMothSacrificeEvent, "live route owns the guarded Moth service")
	var actions := session.visit_actions()
	_check(actions.size() == maxi(1, session.satchel.size()) + 2, "one sacrifice per spare plus both alternatives")
	for index in actions.size():
		var action: Dictionary = actions[index]
		var button: Button = app.stitched_run_buttons[index]
		_check(button.is_visible_in_tree() and button.focus_mode == Control.FOCUS_ALL
			and button.mouse_filter == Control.MOUSE_FILTER_STOP
			and button.get_meta("action_id") == action.id
			and button.get_meta("action_arguments") == action.arguments
			and button.disabled == not action.enabled and button.text == action.text,
			"mounted mouse/keyboard control reflects the exact quote")
		if action.enabled:
			button.grab_focus()
			_check(button.has_focus() and not button.focus_next.is_empty(), "enabled Moth action is in focus chain")
		else:
			var before := session.snapshot()
			button.pressed.emit()
			_check(not session.choose_visit(action.id, action.arguments, before) and session.snapshot() == before,
				"disabled mounted action and public request refuse atomically")
	for index in session.satchel.size():
		var button := _button(app, "sacrifice_part", [index])
		_check(button != null and not button.disabled
			and session.catalog[session.satchel[index].id].name in button.text
			and "spare %d" % (index + 1) in button.text, "each spare has an unambiguous indexed sacrifice")
	var fumigate := _button(app, "fumigate")
	var escape := _button(app, "escape")
	_check(fumigate != null and fumigate.disabled == (session.scraps < 1), "fumigate follows actual scrap affordability")
	_check(escape != null and not escape.disabled, "free escape is always selectable")


## The expected journal, quotes and every nested state value belong to the ORIGINAL
## owner, before Save. Never build expectations from a restored candidate.
func _sealed_oracle(session: StitchedRunSession) -> Dictionary:
	var state := session.snapshot().duplicate(true)
	var document := StitchedRunSave.capture(session).duplicate(true)
	var service_state := {}
	if session._service is RunStitchedMothSacrificeEvent:
		service_state = session._service.read_state().duplicate(true)
	return {
		"state": state,
		"journal": session.journal.duplicate(true),
		"actions": (session.visit_actions() if session.phase == "visit" else
			session.choices() if session.phase == "map" else []).duplicate(true),
		"phase": session.phase,
		"node": session.map.get_current_node_id(),
		"service": str(session.pending.get("service", "")),
		"event": str(session.pending.get("event_id", "")),
		"service_state": service_state,
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
	if str(session.pending.get("event_id", "")) != oracle.event:
		differences.append("event: %s -> %s" % [oracle.event, session.pending.get("event_id", "")])
	if not oracle.service_state.is_empty():
		if not (session._service is RunStitchedMothSacrificeEvent):
			differences.append("restored owner lost the guarded Moth service")
		elif session._service.read_state() != oracle.service_state:
			differences.append("guarded Moth service state differs from the pre-save owner")
	var actions: Array = session.visit_actions() if session.phase == "visit" else (
		session.choices() if session.phase == "map" else [])
	if actions != oracle.actions:
		differences.append("choices: before=%s after=%s" % [
			str(oracle.actions).substr(0, 240), str(actions).substr(0, 240)])
	if StitchedRunSave.capture(session) != oracle.document:
		differences.append("sealed capture/digest differs from pre-save journal and state")
	return differences


## The actual current mounted page and its live Save/Reload generation. The open Moth
## additionally proves its Event identity, guarded service and that the action controls
## belong to this page's current quote; a retired generation cannot pass.
func _owned_mount(app: Node, phase: String) -> Dictionary:
	if not phase in ["visit", "map"]:
		return {}
	var session: StitchedRunSession = app.stitched_run_session
	if session == null or session.phase != phase:
		return {}
	var page: Control = app.stitched_run_panel
	if page == null or not is_instance_valid(page) or not page.is_visible_in_tree():
		return {}
	# A fresh title's Continue mounts the live corridor junction, not the non-walking
	# test runner's paper map: its navigation offers Save/Title while every connected
	# route choice keeps its own active door.
	if phase == "map" and page is StitchedCorridorJunction:
		var junction := page as StitchedCorridorJunction
		var legal: Array = session.choices()
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
	if phase == "visit":
		if session.pending.get("node_id", "") != session.map.get_current_node_id() \
				or session.pending.get("event_id", "") != "moth_infestation" \
				or str(session.pending.get("service", "")) != "Event" \
				or not (session._service is RunStitchedMothSacrificeEvent):
			return {}
		var actions: Array = session.visit_actions()
		if app.stitched_run_buttons.size() < actions.size() + 2:
			return {}
		for index in actions.size():
			var action_button: Button = app.stitched_run_buttons[index]
			if action_button == null or not action_button.is_visible_in_tree() \
					or action_button.get_meta("action_id", "") != actions[index].id \
					or action_button.get_meta("action_arguments", null) != actions[index].arguments \
					or action_button.disabled != not actions[index].enabled:
				return {}
	var navigation := page.find_child("RunNavigation", true, false)
	if navigation == null or not navigation.is_visible_in_tree():
		return {}
	var save: Button = null
	var reload: Button = null
	for child in navigation.get_children():
		if not child is Button or not app.stitched_run_buttons.has(child) \
				or child.disabled or not child.is_visible_in_tree():
			continue
		if child.text == "Save run":
			save = child
		elif child.text == "Reload saved run":
			reload = child
	if save == null or reload == null:
		return {}
	return {"page": page, "save": save, "reload": reload}


## The mounted Save/Reload generation must prove itself: the newly published file is
## compared against a deep pre-Save oracle, a NEW owner replaces the old page, stale
## callbacks stay powerless, and the fresh-title Continue mounts a third owner within
## a bounded wait. A missing generation is a precise failing check, never an assumption.
func _save_reload(app: Node, label: String, stale_button: Button = null) -> void:
	var original: StitchedRunSession = app.stitched_run_session
	_check(original != null and original.is_consistent()
		and original.phase in ["map", "visit"],
		label + " starts with a consistent live map or visit owner")
	if original == null or not original.is_consistent() \
			or not original.phase in ["map", "visit"]:
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
	# A retired generation's file must not masquerade as this generation's Save.
	DirAccess.remove_absolute(SAVE_PATH)
	old_save.pressed.emit()
	var disk: StitchedRunSession = StitchedRunSave.read_file(SAVE_PATH)
	_check(disk != null and _oracle_differences(disk, oracle).is_empty(),
		label + " mounted Save writes exactly its pre-save owner (phase=%s node=%s event=%s): " % [
			oracle.phase, oracle.node, oracle.event] + str(_oracle_differences(disk, oracle)))
	if disk == null:
		return
	old_reload.pressed.emit()
	var reloaded: StitchedRunSession = app.stitched_run_session
	_check(reloaded != null and reloaded != original and reloaded != disk
		and app.stitched_run_panel != old_page,
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
		label + " Reload/stale Save preserve phase, node, wallet, journal, quotes and RNG: "
			+ str(_oracle_differences(reloaded, oracle)))
	var fresh_mount: Dictionary = {}
	for attempt in range(8):
		fresh_mount = _owned_mount(app, oracle.phase)
		if app.stitched_run_session == reloaded and not fresh_mount.is_empty() \
				and fresh_mount.page != old_page:
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
		if continued.stitched_run_session == null and continued.title_view != null \
				and continued.title_view.is_visible_in_tree() \
				and continued.stitched_continue_button != null \
				and continued.stitched_continue_button.is_visible_in_tree() \
				and not continued.stitched_continue_button.disabled:
			break
		await process_frame
	var ready: bool = continued.stitched_run_session == null and continued.title_view != null \
		and continued.title_view.is_visible_in_tree() and continued.stitched_continue_button != null \
		and continued.stitched_continue_button.is_visible_in_tree() \
		and not continued.stitched_continue_button.disabled
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


func _refusals(session: StitchedRunSession) -> void:
	# The negative tables act only on the live guarded Moth service; a missing service is
	# an explicit failing check, never an assumed, manufactured or forged one.
	if not (session != null and session._service is RunStitchedMothSacrificeEvent):
		_check(false, "refusal table needs the live mounted Moth service, not a null service")
		return
	var before := session.snapshot()
	var journal := session.journal.duplicate(true)
	var service_state: Dictionary = session._service.read_state()
	for args in [[], [-1], [session.satchel.size()], ["0"], [0.0], [null], [true], [0, 1], [{"id": "forged"}]]:
		_check(not session.choose_visit("sacrifice_part", args, before)
			and session.snapshot() == before and session.journal == journal
			and session._service.read_state() == service_state, "forged/empty index refuses without spend, latch or RNG")
	for id in ["fumigate", "escape", "leave", "unpick", "moth_infestation", "buy_dye"]:
		_check(not session.choose_visit(id, [0], before) and session.snapshot() == before
			and session.journal == journal, "unquoted action/arguments cannot authorize Moth")
	for key in ["satchel", "scraps", "rng", "pending", "map"]:
		var forged := before.duplicate(true)
		forged[key] = "forged"
		_check(not session.choose_visit("escape", [], forged) and session.snapshot() == before
			and session.journal == journal, "stale snapshot fails closed for " + key)
	var detached := session.visit_actions()
	detached[0].arguments.append("forged")
	_check(session.visit_actions() != detached and session.snapshot() == before, "quoted actions are detached")
	var old_scraps := session.scraps
	session.scraps += 1
	_check(not session.is_consistent() and StitchedRunSave.capture(session).is_empty()
		and not session.choose_visit("escape", [], session.snapshot()), "direct ledger tampering fails sealed session")
	session.scraps = old_scraps
	_check(session.is_consistent() and session.snapshot() == before, "tamper check restores original state")


func _activate(button: Button, keyboard: bool) -> void:
	if keyboard:
		button.grab_focus()
		_check(button.has_focus() and not button.disabled, "keyboard activation starts at a focused legal button")
		for down in [true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_ENTER
			event.pressed = down
			root.push_input(event, true)
	else:
		button.pressed.emit()


func _earn_moth_wallet(stage: StitchedBattleScreen) -> int:
	# Each turn uses the first legal mounted part on the front-most living foe,
	# passing only when no part can reach one; no seed-specific command list.
	var acted := 0
	while not stage.battle.is_over() and acted < 80:
		var done := false
		for slot in stage._part_buttons:
			if stage._part_buttons[slot].disabled:
				continue
			stage._part_buttons[slot].pressed.emit()
			for rank in [1, 2, 3, 4]:
				var target: Button = stage._target_buttons.get("foe_" + str(rank))
				if target != null and not target.disabled and target.visible:
					target.pressed.emit()
					done = true
					break
			if done:
				break
		if not done:
			var pass_button: Button = stage._action_buttons.get("pass")
			_check(pass_button != null and not pass_button.disabled, "witness turn has a legal mounted action")
			if pass_button == null or pass_button.disabled:
				break
			pass_button.pressed.emit()
		acted += 1
	return acted


func _settle(app: Node, id: String, arguments: Array, keyboard: bool) -> void:
	var session: StitchedRunSession = app.stitched_run_session
	# Settlement acts only on the actual current mounted Moth owner and its guarded
	# service; a missing owner or service is an explicit failing check, never a
	# manufactured service or a forced route outcome.
	if not (session != null and session.phase == "visit"
			and session.pending.get("event_id") == "moth_infestation"
			and session._service is RunStitchedMothSacrificeEvent):
		_check(false, "settlement " + id + " needs the actual mounted open-Moth owner and guarded service"
			+ " (session=" + ("live" if session != null else "null")
			+ ", phase=" + (str(session.phase) if session != null else "<none>")
			+ ", event=" + (str(session.pending.get("event_id", "<none>")) if session != null else "<none>") + ")")
		return
	var before := session.snapshot()
	var journal := session.journal.duplicate(true)
	var buttons: Array = app.stitched_run_buttons.duplicate()
	var actions := session.visit_actions()
	var service: RunStitchedMothSacrificeEvent = session._service
	var service_state := service.read_state()
	var replay := StitchedRunSave.restore(StitchedRunSave.capture(session))
	_check(replay != null, "comparison replay starts at an authentic open Moth")
	if replay == null:
		return
	_check(replay.choose_visit(id, arguments, replay.snapshot()), "replay uses the same public action and arguments")
	var button := _button(app, id, arguments)
	if button == null:
		return
	_activate(button, keyboard)
	var expected_satchel: Array = before.satchel.duplicate(true)
	var delta := 0
	if id == "sacrifice_part":
		expected_satchel.remove_at(arguments[0])
		delta = 2
	elif id == "fumigate":
		delta = -1
	# A consequential Moth choice carries S14 Event loot; the free escape carries none.
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.state = before.rng
	var drawn: Dictionary = {}
	if id != "escape":
		drawn = StitchedS14Abilities.draw_patch(expected_rng, "event")
	var awarded: Dictionary = session.journal.back().get("ability_patch", {})
	_check(session.phase == "map" and session.pending.is_empty() and session.is_consistent()
		and session.satchel == expected_satchel and session.scraps == before.scraps + delta,
		"branch settles exactly its catalog scrap delta and selected spare, preserving order/identity")
	_check(session.gold == before.gold and session.candle == before.candle and session.heroes == before.heroes
		and session.patches == before.patches and session.pockets == before.pockets
		and session.snapshot().kid_fear == before.kid_fear
		and session.map.export_state() == before.map and session.rng.state == expected_rng.state
		and (awarded.is_empty() if drawn.is_empty() else (not awarded.is_empty()
			and awarded.id == drawn.id and awarded.rarity == drawn.rarity
			and int(awarded.uid) == int(before.s14.serial) + 1
			and session.ability_inventory.back() == awarded)),
		"branch has no generic Event double-effect, unrelated spend or route mutation, and only its seeded patch draw")
	_check(service.is_claimed() and not service.is_open() and service.get_version() == 1,
		"mounted action actually claimed the guarded service once")
	if session.phase == "map" and service.is_claimed():
		settled_branches += 1
	var expected_journal := {"action": "visit", "id": id, "arguments": arguments}
	if not awarded.is_empty():
		expected_journal["ability_patch"] = awarded
	_check(session.receipts.size() == before.receipts.size() + 1
		and session.receipts.back() == {"node_id": before.pending.node_id, "kind": "Event", "decision": id,
			"event_id": "moth_infestation", "steps": [{"action": id, "arguments": arguments,
				"gold": before.gold, "scraps": before.scraps + delta, "candle": before.candle}]}
		and session.journal.size() == journal.size() + 1
		and session.journal.back() == expected_journal,
		"one exact node receipt and deterministic journal command")
	_check(session.snapshot() == replay.snapshot() and session.journal == replay.journal,
		"mounted path and public replay have identical complete state")
	var settled := session.snapshot()
	var claimed := service.read_state()
	_check(service.choose(id, arguments[0] if not arguments.is_empty() else null,
		before.pending.node_id, service_state).get("ok") == false and service.read_state() == claimed,
		"duplicate guarded claim refuses without any mutation")
	for index in actions.size():
		buttons[index].pressed.emit()
		_check(not session.choose_visit(actions[index].id, actions[index].arguments, before)
			and not session.choose_visit(actions[index].id, actions[index].arguments, settled)
			and session.snapshot() == settled and session.journal.size() == journal.size() + 1,
			"duplicate and competing stale callbacks cannot spend, remove another spare or redraw RNG")
	var saved := StitchedRunSave.capture(session)
	for command in [{"action": "visit", "id": id, "arguments": arguments},
		{"action": "visit", "id": "sacrifice_part", "arguments": [999]},
		{"action": "visit", "id": "escape", "arguments": [0]}]:
		var forged := saved.duplicate(true)
		forged.journal.append(command)
		forged.digest = StitchedRunSave._digest(forged)
		_check(StitchedRunSave.restore(forged) == null and session.snapshot() == settled,
			"rehashed forged/duplicate journal fails detached replay")
	for key in ["satchel", "scraps", "receipts", "rng"]:
		var forged := saved.duplicate(true)
		forged.state[key] = [{"id": "forged"}] if key == "satchel" else [] if key == "receipts" else -1
		forged.digest = StitchedRunSave._digest(forged)
		_check(StitchedRunSave.restore(forged) == null, "forged saved " + key + " fails exact replay")
	await _save_reload(app, "settled " + id)
	session = app.stitched_run_session
	if session == null:
		_check(false, "settled " + id + " keeps a live reloaded owner for its onward route")
		return
	var onward := session.choices()
	_check(not onward.is_empty(), "settled/reloaded Moth has a legal onward route")
	if not onward.is_empty():
		_check(_press_route(app, onward[0]), "real next-node control continues after Moth")
		var entered := session.snapshot()
		_check(not session.choose_visit(id, arguments, settled) and session.snapshot() == entered,
			"old Moth cannot authorize an onward node")
		var restored := StitchedRunSave.restore(StitchedRunSave.capture(session))
		_check(restored != null and restored.snapshot() == entered, "onward action replays exact route and RNG")


func _rich_branch(id: String, index: int = -1, keyboard: bool = false) -> void:
	var app: Node = await _new_run(RICH_SEED)
	var session: StitchedRunSession = app.stitched_run_session
	if session == null:
		app.free()
		return
	_check(_press_route(app, FIRST_NODE), "real route control activates connected opening Fight")
	_check(session.phase == "battle", "opening Fight starts a genuine battle: " + session.phase)
	var stage: StitchedBattleScreen = app.stitched_run_battle
	_check(stage != null and stage.battle == session.battle, "mounted battle is the real run authority")
	if stage == null:
		app.free()
		return
	var before_fight := session.snapshot()
	var acted := _earn_moth_wallet(stage)
	_check(acted > 0 and stage.battle.outcome() == "victory", "legal mounted abilities earn actual spares and scraps")
	stage._action_buttons["exit"].pressed.emit()
	_check(session.phase == "map", "victory returns to the genuine route: " + session.phase)
	_check(session.receipts.size() == before_fight.receipts.size() + 1,
		"opening Fight publishes one actual reward receipt")
	if session.receipts.is_empty():
		app.free()
		return
	var fight_receipt: Dictionary = session.receipts.back()
	var reward: Dictionary = fight_receipt.get("reward", {})
	_check(fight_receipt.get("node_id") == FIRST_NODE and fight_receipt.get("kind") == "Fight"
		and fight_receipt.get("outcome") == "victory" and not reward.get("parts", []).is_empty()
		and session.satchel == reward.get("parts", [])
		and session.gold == before_fight.gold + int(reward.get("gold", 0))
		and session.scraps == before_fight.scraps + int(reward.get("scraps", 0)),
		"funded seed earns its real drop and wallet from victory: seed=%d reward=%s" % [RICH_SEED, reward])
	_check(session.gold >= StitchedRunSession.PEDDLER_PRICE, "victory funds the spare purchase: gold=" + str(session.gold))
	_check(_press_route(app, SHOP_NODE), "real route control activates connected Peddler")
	_check(session.phase == "visit" and session.pending.get("service") == "Peddler"
		and session.map.get_node(SHOP_NODE).type == "Shop", "generated second node mounts the real Peddler")
	var purchase := _button(app, "buy_part")
	_check(purchase != null and not purchase.disabled, "earned spare purchase is mounted and affordable")
	if purchase == null or purchase.disabled:
		app.free()
		return
	var before_purchase := session.snapshot()
	# The asserted Peddler prerequisites are enforced before any pending field is
	# read, so a failed route entry fails this branch explicitly (the mounted
	# Peddler check above) instead of reaching into a visit holding no stock.
	if not (session.phase == "visit" and session.pending.get("service") == "Peddler"):
		app.free()
		return
	var stock: Dictionary = session.pending.peddler_stock.part.duplicate(true)
	purchase.pressed.emit()
	var expected_spares: Array = before_purchase.satchel.duplicate(true)
	expected_spares.append({"id": stock.id, "slot": session.catalog[stock.id].slot, "tier": 1, "torn": false})
	_check(session.phase == "map" and session.satchel == expected_spares
		and session.gold == before_purchase.gold - int(stock.price) and session.scraps == before_purchase.scraps
		and session.receipts.size() == before_purchase.receipts.size() + 1
		and session.receipts.back().node_id == SHOP_NODE and session.receipts.back().decision == "buy_part",
		"mounted Peddler appends its quoted spare once and charges earned gold: stock=" + str(stock))
	_check(session.satchel.size() >= 2, "earned drop and purchase supply two spares: " + str(session.satchel))
	if session.satchel.size() >= 2:
		_check(session.satchel[0].id != session.satchel[1].id, "ordered sacrifice witnesses are distinct parts")
	_check(session.scraps >= 1, "earned wallet funds fumigate: scraps=" + str(session.scraps))
	var before_entry := session.snapshot()
	_check(_press_route(app, MOTH_NODE), "real route control activates connected Moth witness node")
	var witness := "seed=%d action=%s args=%d phase=%s event=%s route=%s spares=%s scraps=%d gold=%d rng=%d->%d quote=%s" % [
		RICH_SEED, id, index, session.phase, session.pending.get("event_id", "<none>"), session.map.get_route(),
		session.satchel, session.scraps, session.gold, before_entry.rng, session.rng.state, session.visit_actions()]
	print("funded Moth witness: " + witness)
	_check(session.pending.get("event_id") == "moth_infestation",
		"funded Moth witness missing; re-derive through mounted Fight -> Peddler -> Event: " + witness)
	_check(session.phase == "visit" and session.map.get_route() == before_entry.map.route + [MOTH_NODE],
		"funded Event entry advances the authentic route once: " + str(session.map.get_route()))
	_check(session.is_consistent() and session.rng.state != before_entry.rng,
		"funded Event entry seals the actual selector RNG: %d -> %d" % [before_entry.rng, session.rng.state])
	if session.phase == "visit" and session.pending.get("event_id") == "moth_infestation":
		_controls(app)
		_refusals(session)
		var stale_open: Button = app.stitched_run_buttons[0]
		await _save_reload(app, "open funded Moth", stale_open)
		_controls(app)
		var arguments: Array = [index] if id == "sacrifice_part" else []
		await _settle(app, id, arguments, keyboard)
	else:
		_check(false, "required funded settlement was not exercised: " + witness)
	app.free()
	await process_frame


## [seed, node] of the first run from POOR_SEED that meets the Moth on floor one.
## One session per candidate seed is enough: the standing Event selector draws its
## record from the run RNG before reading any node id, so every floor-one Event of a
## seed reaches the same authored Event. The map-only search skips seeds with no
## floor-one Event before paying for a session.
func _poor_witness() -> Array:
	for candidate in LiveWitness.candidates(["Event"], POOR_SEED, 1, [], POOR_SEARCH):
		var session := StitchedRunSession.start(int(candidate[0]))
		var first_event := str(candidate[1][0])
		if session != null and session.enter(first_event, session.snapshot()) \
				and session.pending.get("event_id") == "moth_infestation":
			return [candidate[0], first_event]
	return [POOR_SEED, ""]


func _poor_branch() -> void:
	var witness := _poor_witness()
	_check(not str(witness[1]).is_empty(), "a seed from %d meets the Moth on floor one" % POOR_SEED)
	var poor_node := str(witness[1])
	var app: Node = await _new_run(int(witness[0]))
	var session: StitchedRunSession = app.stitched_run_session
	if session != null:
		var before_entry := session.snapshot()
		_check(_press_route(app, poor_node), "real route control activates connected empty Moth witness node")
		_check(session.pending.get("event_id") == "moth_infestation",
			"empty witness selected Event ID: " + str(session.pending.get("event_id")))
		_check(session.satchel.is_empty(), "opening Moth has no spare parts: " + str(session.satchel))
		_check(session.scraps == 0, "opening Moth has no scraps: " + str(session.scraps))
		_check(session.phase == "visit" and session.map.get_route() == before_entry.map.route + [poor_node],
			"empty Event entry advances the authentic route once: " + str(session.map.get_route()))
		_check(session.is_consistent() and session.rng.state != before_entry.rng,
			"empty Event entry seals the actual selector RNG: %d -> %d" % [before_entry.rng, session.rng.state])
		if session.phase == "visit" and session.pending.get("event_id") == "moth_infestation":
			_controls(app)
			_refusals(session)
			var before := session.snapshot()
			_check(not session.choose_visit("fumigate", [], before)
				and not session.choose_visit("sacrifice_part", [0], before) and session.snapshot() == before,
				"unaffordable fumigate and empty sacrifice refuse without RNG or spend")
			var stale_open: Button = app.stitched_run_buttons[0]
			await _save_reload(app, "open empty Moth", stale_open)
			await _settle(app, "escape", [], true)
	app.free()
	await process_frame


func _run() -> void:
	# Each new Event pack shifts the seeded selector off the Moth, so the funded runs pin
	# the drawn record; route, wallet and spares stay earned through the real pipeline.
	StitchedRunSession.pinned_event_id = "moth_infestation"
	await _rich_branch("sacrifice_part", 0)
	await _rich_branch("sacrifice_part", 1, true)
	await _rich_branch("fumigate")
	await _rich_branch("escape")
	StitchedRunSession.pinned_event_id = ""
	await _poor_branch()
	_check(settled_branches == 5, "both indexed sacrifices, funded fumigate, funded escape and empty escape actually settled")
	DirAccess.remove_absolute(SAVE_PATH)
	for failure in failures:
		printerr(failure)
	print("stitched_s7_moth_sacrifice_live_test: %d checks, %d failures, %d witnessed settlements" % [checks, failures.size(), settled_branches])
	quit(0 if failures.is_empty() else 1)
