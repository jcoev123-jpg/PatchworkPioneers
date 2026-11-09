extends "res://tests/stitched_s6_routed_vis_a_test.gd"
## S8f: starch and spare spool are sold at the live Peddler, one supply per stop.

const SAVE_PATH := "user://stitched_s8f_peddler_walk_supplies_live.save"
const SUPPLIES := {"buy_starch": "starch", "buy_spare_spool": "spare_spool"}


func _visit_button(app: Node, id: String, arguments: Array = []) -> Button:
	var actions: Array = app.stitched_run_session.visit_actions()
	for index in actions.size():
		if actions[index].id == id and actions[index].arguments == arguments:
			return app.stitched_run_buttons[index]
	_check(false, "mounted visit has requested action " + id + str(arguments))
	return null


func _supply_controls(app: Node) -> void:
	var session: StitchedRunSession = app.stitched_run_session
	_check(session.phase == "visit" and session.pending.service == "Peddler",
		"walk supplies are mounted at a genuine Peddler stop")
	var count := 0
	for action_id in SUPPLIES:
		for hero in session.heroes:
			var button := _visit_button(app, action_id, [hero.id])
			if button == null:
				continue
			count += 1
			var enabled: bool = not hero.lost and session.pockets[hero.id].size() < 2 and session.gold >= 10
			var label := "Starch" if action_id == "buy_starch" else "Spare spool"
			var text := button.text
			var effect_ok: bool
			if action_id == "buy_starch":
				effect_ok = "Guard next fight" in text and "THREAD" not in text and "TUG" not in text
			else:
				effect_ok = "thread that tugs" in text and "Guard" not in text
			_check(effect_ok and hero.name in text and label in text,
				"%s label for %s names its own later-use effect and doll" % [label, hero.id])
			var other := "Spare spool" if action_id == "buy_starch" else "Starch"
			_check(other not in text, "%s label for %s does not name the other supply" % [label, hero.id])
			var listed := ""
			for action in session.visit_actions():
				if action.id == action_id and action.arguments == [hero.id]:
					listed = str(action.text)
			_check(not listed.is_empty() and listed == text and "10 gold" in listed,
				"mounted %s button shows the session's quoted 10-gold action text for %s" % [label, hero.id])
			_check(button.is_visible_in_tree() and button.focus_mode == Control.FOCUS_ALL
				and button.disabled == not enabled and "10 gold" in button.text and label in button.text,
				"visible 10-gold %s choice reflects lost/full/wallet for %s" % [label, hero.id])
			if not enabled:
				var before := session.snapshot()
				button.pressed.emit()
				_check(not session.choose_visit(action_id, [hero.id], before) and session.snapshot() == before,
					"disabled supply button and command preserve every ledger and RNG")
	_check(count == 8, "both supplies are offered for all four dolls")
	_check(_visit_button(app, "buy_pins", [session.heroes[0].id]) != null
		and _visit_button(app, "leave") != null, "the same Peddler keeps its other pocket stock and Leave")


func _save_reload(app: Node, label: String) -> void:
	var session: StitchedRunSession = app.stitched_run_session
	var before := session.snapshot()
	var count := session.visit_actions().size() if session.phase == "visit" else session.choices().size()
	app.stitched_save_path = SAVE_PATH
	app.stitched_run_buttons[count].pressed.emit()
	app.stitched_run_buttons[count + 1].pressed.emit()
	_check(app.stitched_run_session != session and app.stitched_run_session.snapshot() == before,
		label + " reloads exact pockets through the mounted Save/Reload controls")


func _buy(app: Node, action_id: String, hero_id: String) -> void:
	var session: StitchedRunSession = app.stitched_run_session
	var button := _visit_button(app, action_id, [hero_id])
	_check(button != null and not button.disabled, "earned wallet admits a real " + action_id)
	if button == null or button.disabled:
		return
	var before := session.snapshot()
	var old_actions := session.visit_actions()
	button.pressed.emit()
	var expected: Dictionary = before.pockets.duplicate(true)
	expected[hero_id].append(SUPPLIES[action_id])
	_check(session.phase == "map" and session.gold == before.gold - 10 and session.pockets == expected
		and session.heroes == before.heroes and session.rng.state == before.rng
		and session.map.export_state() == before.map,
		action_id + " charges exactly 10 and adds one owned item, then closes the stop")
	_check(session.journal.back() == {"action": "visit", "id": action_id, "arguments": [hero_id]}
		and session.receipts.back().decision == action_id, action_id + " leaves one journal entry and receipt")
	var paid := session.snapshot()
	for action in old_actions:
		_check(not session.choose_visit(action.id, action.arguments, before) and session.snapshot() == paid,
			"a used stop cannot sell a second supply or any other stock")
	var saved := StitchedRunSave.capture(session)
	var restored := StitchedRunSave.restore(saved)
	_check(restored != null and restored.snapshot() == paid, action_id + " replays from a save")
	var legacy := saved.duplicate(true)
	legacy.state.erase("pockets")
	legacy.digest = StitchedRunSave._digest(legacy)
	_check(StitchedRunSave.restore(legacy) == null, "a pocket-less old save cannot hide a supply purchase")
	var forged := saved.duplicate(true)
	forged.state.pockets[hero_id] = ["pins"] if SUPPLIES[action_id] != "pins" else ["dye"]
	forged.digest = StitchedRunSave._digest(forged)
	_check(StitchedRunSave.restore(forged) == null, "forged ownership cannot replace the replayed supply")
	_save_reload(app, "post-supply map")


func _earned_route() -> void:
	var app: Node = await _new_run(201)
	var session: StitchedRunSession = app.stitched_run_session
	if session == null:
		app.free()
		return
	var shops := 0
	for id in ["f01_n1", "f02_n1", "f03_n1", "f04_n1", "f05_n1", "f06_n1", "f07_n0", "f08_n0"]:
		_check(session.choices().has(id) and _press_route(app, id), "seeded connected control enters " + id)
		if session.phase == "battle":
			var stage: StitchedBattleScreen = app.stitched_run_battle
			if stage == null:
				break
			var result := _win(stage)
			_check(result.acted > 0 and stage.battle.outcome() == "victory", "legal combat earns the wallet")
			stage._action_buttons["exit"].pressed.emit()
		elif session.phase == "visit" and session.pending.service == "Peddler":
			shops += 1
			_supply_controls(app)
			if shops == 1:
				_save_reload(app, "open Peddler")
				session = app.stitched_run_session
				_supply_controls(app)
				_buy(app, "buy_starch", "warden")
			elif shops == 2:
				_buy(app, "buy_spare_spool", "warden")
			else:
				_check(session.pockets.warden == ["starch", "spare_spool"],
					"a full pocket is witnessed at the third Peddler")
				var before := session.snapshot()
				_visit_button(app, "leave").pressed.emit()
				_check(session.phase == "map" and session.gold == before.gold and session.pockets == before.pockets,
					"free Leave closes the full-pocket Peddler without spending")
			session = app.stitched_run_session
		else:
			_check(_finish_visit(app) and session.phase == "map", "ordinary stop continues the route")
	_check(shops == 3 and session.pockets.warden == ["starch", "spare_spool"],
		"two earned supply purchases and a full-pocket refusal were exercised")
	app.free()
	await process_frame


func _poor_shop() -> void:
	var witness := _seed_with_kind("Shop")
	_check(not witness.is_empty(), "unaffordable witness has a seeded opening Shop")
	if witness.is_empty():
		return
	var app: Node = await _new_run(witness.seed)
	var session: StitchedRunSession = app.stitched_run_session
	if session != null:
		_check(_press_route(app, witness.id) and session.gold == 0, "opening Shop has an empty wallet")
		_supply_controls(app)
		var forged := StitchedRunSave.capture(session)
		forged.journal.append({"action": "visit", "id": "buy_starch", "arguments": [session.heroes[0].id]})
		forged.digest = StitchedRunSave._digest(forged)
		_check(StitchedRunSave.restore(forged) == null, "a rehashed unaffordable supply purchase fails replay")
	app.free()
	await process_frame


func _run() -> void:
	await _poor_shop()
	await _earned_route()
	DirAccess.remove_absolute(SAVE_PATH)
	for message in failures:
		printerr(message)
	print("stitched_s8f_peddler_walk_supplies_live_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
