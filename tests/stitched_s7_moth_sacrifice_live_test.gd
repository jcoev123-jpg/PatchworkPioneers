extends "res://tests/stitched_s6_full_run_test.gd"
## Genuine seeded map -> ranked victory -> spare purchase -> Moth.

const SAVE_PATH := "user://stitched_s7_moth_sacrifice_live.save"
# Re-derived through the genuine map -> battle -> Peddler -> Event pipeline after the
# merged roadside Event packs shifted the seeded selector.
const RICH_SEED := 152239
# The merged roadside Event packs shifted the seeded selector; this empty-satchel floor-1
# witness still reaches the authored Moth with zero scraps.
const POOR_SEED := 744
const FIRST_NODE := "f01_n1"
const SHOP_NODE := "f02_n1"
const MOTH_NODE := "f03_n1"
## The poor witness is the first seed from POOR_SEED whose floor-one Event is the Moth, so new
## events shifting the seeded draws do not retire it.
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


func _reload_and_continue(app: Node, label: String) -> void:
	var session: StitchedRunSession = app.stitched_run_session
	var before := session.snapshot()
	var journal := session.journal.duplicate(true)
	var actions := session.visit_actions()
	var count := actions.size() if session.phase == "visit" else session.choices().size()
	var stale: Button = app.stitched_run_buttons[0]
	app.stitched_save_path = SAVE_PATH
	_check(app.stitched_run_buttons[count].text == "Save run"
		and app.stitched_run_buttons[count + 1].text == "Reload saved run", label + " has real Save/Reload controls")
	app.stitched_run_buttons[count].pressed.emit()
	_check(FileAccess.file_exists(SAVE_PATH), label + " writes a save")
	app.stitched_run_buttons[count + 1].pressed.emit()
	_check(app.stitched_run_session != session and app.stitched_run_session.snapshot() == before
		and app.stitched_run_session.journal == journal and app.stitched_run_session.visit_actions() == actions,
		label + " reloads exact receipt, satchel identity/order, wallet, route, journal, quote and RNG")
	stale.pressed.emit()
	_check(app.stitched_run_session.snapshot() == before, label + " rejects pre-reload callback")
	var continued: Node = load("res://scenes/app.tscn").instantiate()
	continued.stitched_save_path = SAVE_PATH
	root.add_child(continued)
	await process_frame
	_check(continued.stitched_run_session == null and continued.title_view.is_visible_in_tree()
		and continued.stitched_continue_button.is_visible_in_tree() and not continued.stitched_continue_button.disabled,
		label + " fresh title offers Continue")
	continued.stitched_continue_button.pressed.emit()
	_check(continued.stitched_run_session != null and continued.stitched_run_session.snapshot() == before
		and continued.stitched_run_session.journal == journal and continued.stitched_run_session.visit_actions() == actions,
		label + " title Continue reproduces exact deterministic session")
	continued.free()
	await process_frame


func _refusals(session: StitchedRunSession) -> void:
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
				if target != null and not target.disabled and target.is_visible_in_tree():
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
	_check(session.phase == "map" and session.pending.is_empty() and session.is_consistent()
		and session.satchel == expected_satchel and session.scraps == before.scraps + delta,
		"branch settles exactly its catalog scrap delta and selected spare, preserving order/identity")
	_check(session.gold == before.gold and session.candle == before.candle and session.heroes == before.heroes
		and session.patches == before.patches and session.pockets == before.pockets
		and session.snapshot().kid_fear == before.kid_fear
		and session.map.export_state() == before.map and session.rng.state == before.rng,
		"branch has no generic Event double-effect, unrelated spend, route mutation or RNG draw")
	_check(service.is_claimed() and not service.is_open() and service.get_version() == 1,
		"mounted action actually claimed the guarded service once")
	if session.phase == "map" and service.is_claimed():
		settled_branches += 1
	_check(session.receipts.size() == before.receipts.size() + 1
		and session.receipts.back() == {"node_id": before.pending.node_id, "kind": "Event", "decision": id,
			"event_id": "moth_infestation", "steps": [{"action": id, "arguments": arguments,
				"gold": before.gold, "scraps": before.scraps + delta, "candle": before.candle}]}
		and session.journal.size() == journal.size() + 1
		and session.journal.back() == {"action": "visit", "id": id, "arguments": arguments},
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
	await _reload_and_continue(app, "settled " + id)
	session = app.stitched_run_session
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
	var acted := _earn_moth_wallet(stage)
	_check(acted > 0 and stage.battle.outcome() == "victory", "legal mounted abilities earn actual spares and scraps")
	stage._action_buttons["exit"].pressed.emit()
	_check(session.phase == "map", "victory returns to the genuine route: " + session.phase)
	_check(session.gold >= StitchedRunSession.PEDDLER_PRICE, "victory funds the spare purchase: gold=" + str(session.gold))
	_check(_press_route(app, SHOP_NODE), "real route control activates connected Peddler")
	var purchase := _button(app, "buy_part")
	_check(purchase != null and not purchase.disabled, "earned spare purchase is mounted and affordable")
	if purchase == null or purchase.disabled:
		app.free()
		return
	purchase.pressed.emit()
	_check(session.satchel.size() >= 2, "earned drop and purchase supply two spares: " + str(session.satchel))
	if session.satchel.size() >= 2:
		_check(session.satchel[0].id != session.satchel[1].id, "ordered sacrifice witnesses are distinct parts")
	_check(session.scraps >= 1, "earned wallet funds fumigate: scraps=" + str(session.scraps))
	var before_entry := session.snapshot()
	_check(_press_route(app, MOTH_NODE), "real route control activates connected Moth witness node")
	_check(session.pending.get("event_id") == "moth_infestation",
		"funded witness selected Event ID: " + str(session.pending.get("event_id")))
	_check(session.phase == "visit" and session.map.get_route() == before_entry.map.route + [MOTH_NODE],
		"funded Event entry advances the authentic route once: " + str(session.map.get_route()))
	_check(session.is_consistent() and session.rng.state != before_entry.rng,
		"funded Event entry seals the actual selector RNG: %d -> %d" % [before_entry.rng, session.rng.state])
	if session.phase == "visit" and session.pending.get("event_id") == "moth_infestation":
		_controls(app)
		_refusals(session)
		await _reload_and_continue(app, "open funded Moth")
		_controls(app)
		var arguments: Array = [index] if id == "sacrifice_part" else []
		await _settle(app, id, arguments, keyboard)
	app.free()
	await process_frame


## [seed, node] of the first run from POOR_SEED that meets the Moth on floor one.
func _poor_witness() -> Array:
	for seed_number in range(POOR_SEED, POOR_SEED + POOR_SEARCH):
		var probe := StitchedRunSession.start(seed_number)
		if probe == null:
			continue
		for id in probe.choices():
			if probe.map.get_node(str(id)).type != "Event":
				continue
			var session := StitchedRunSession.start(seed_number)
			if session.enter(str(id), session.snapshot()) and session.pending.get("event_id") == "moth_infestation":
				return [seed_number, str(id)]
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
			await _reload_and_continue(app, "open empty Moth")
			await _settle(app, "escape", [], true)
	app.free()
	await process_frame


func _run() -> void:
	await _rich_branch("sacrifice_part", 0)
	await _rich_branch("sacrifice_part", 1, true)
	await _rich_branch("fumigate")
	await _rich_branch("escape")
	await _poor_branch()
	_check(settled_branches == 5, "both indexed sacrifices, funded fumigate, funded escape and empty escape actually settled")
	DirAccess.remove_absolute(SAVE_PATH)
	for failure in failures:
		printerr(failure)
	print("stitched_s7_moth_sacrifice_live_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
