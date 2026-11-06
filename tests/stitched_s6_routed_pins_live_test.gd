extends "res://tests/stitched_s6_routed_vis_a_test.gd"
## Earned wallets and genuine generated Shops, driven through New Run controls.

const SAVE_PATH := "user://stitched_s6_routed_pins_live.save"


func _visit_button(app: Node, id: String, arguments: Array = []) -> Button:
	var actions: Array = app.stitched_run_session.visit_actions()
	for index in actions.size():
		if actions[index].id == id and actions[index].arguments == arguments:
			return app.stitched_run_buttons[index]
	_check(false, "mounted visit has requested action " + id + str(arguments))
	return null


func _pins_controls(app: Node) -> void:
	var session: StitchedRunSession = app.stitched_run_session
	_check(session.phase == "visit" and session.pending.service == "Peddler"
		and session.map.get_node(session.pending.node_id).type == "Shop",
		"pins are mounted at a genuine generated routed Shop")
	_check(session.heroes.size() == 4 and session.pockets.size() == 4,
		"four canonical dolls have exactly four owned pockets")
	var count := 0
	for hero in session.heroes:
		_check(hero.id in StitchedPartyAdmission.HERO_IDS and session.pockets.has(hero.id),
			"pocket owner is the canonical selected hero")
		var button := _visit_button(app, "buy_pins", [hero.id])
		if button == null:
			continue
		count += 1
		var enabled: bool = not hero.lost and session.pockets[hero.id].size() < 2 and session.gold >= 10
		_check(button.is_visible_in_tree() and button.focus_mode == Control.FOCUS_ALL
			and button.disabled == not enabled and "10 gold" in button.text and "Pins" in button.text,
			"visible focusable 10-gold pins choice reflects lost/full/wallet for " + hero.id)
		if enabled:
			button.grab_focus()
			_check(button.has_focus() and not button.focus_next.is_empty(), "legal pins choice participates in keyboard focus")
		else:
			var before := session.snapshot()
			button.pressed.emit()
			_check(not session.choose_visit("buy_pins", [hero.id], before) and session.snapshot() == before,
				"disabled pins button and command preserve every ledger, route and RNG")
	_check(count == 4, "all four pins choices were actually inspected")
	var leave := _visit_button(app, "leave")
	_check(leave != null and not leave.disabled and leave.focus_mode == Control.FOCUS_ALL,
		"free Leave remains enabled and keyboard reachable")
	_check(_visit_button(app, "buy_candle_stub") != null and _visit_button(app, "buy_part") != null,
		"the same Peddler retains candle and spare-part stock")


func _save_reload(app: Node, label: String) -> void:
	var session: StitchedRunSession = app.stitched_run_session
	var before := session.snapshot()
	var count := session.visit_actions().size() if session.phase == "visit" else session.choices().size()
	app.stitched_save_path = SAVE_PATH
	_check(app.stitched_run_buttons[count].text == "Save run"
		and app.stitched_run_buttons[count + 1].text == "Reload saved run", label + " uses mounted Save/Reload controls")
	app.stitched_run_buttons[count].pressed.emit()
	_check(FileAccess.file_exists(SAVE_PATH), label + " creates its save")
	app.stitched_run_buttons[count + 1].pressed.emit()
	_check(app.stitched_run_session != session and app.stitched_run_session.snapshot() == before,
		label + " reloads a detached exact state including pockets and seeded RNG")


func _reject_choices(session: StitchedRunSession) -> void:
	var before := session.snapshot()
	var journal := session.journal.duplicate(true)
	for args in [[], ["unknown"], [""], [null], [7], [session.heroes[0].id, "extra"]]:
		_check(not session.choose_visit("buy_pins", args, before) and session.snapshot() == before
			and session.journal == journal, "forged pins arguments are atomic and RNG-neutral")
	for key in ["gold", "pockets", "rng", "pending", "map"]:
		var forged := before.duplicate(true)
		forged[key] = "forged"
		_check(not session.choose_visit("buy_pins", [session.heroes[0].id], forged)
			and session.snapshot() == before and session.journal == journal,
			"stale or forged " + key + " cannot authorize a purchase")
	var detached := session.snapshot()
	detached.pockets[session.heroes[0].id].append("pins")
	_check(session.snapshot() == before, "snapshot pockets are deeply detached")
	session.pockets[session.heroes[0].id].append("pins")
	_check(not session.is_consistent() and StitchedRunSave.capture(session).is_empty()
		and not session.choose_visit("buy_pins", [session.heroes[0].id], session.snapshot()),
		"direct pocket tampering fails the sealed state boundary")
	session.pockets[session.heroes[0].id].pop_back()
	_check(session.is_consistent() and session.snapshot() == before, "tamper probe restores its original exact state")


func _buy(app: Node, hero_id: String) -> void:
	var session: StitchedRunSession = app.stitched_run_session
	var button := _visit_button(app, "buy_pins", [hero_id])
	_check(button != null and not button.disabled and session.gold >= 10, "earned wallet and living pocket admit a real buy")
	if button == null or button.disabled:
		return
	var before := session.snapshot()
	var journal_size := session.journal.size()
	var old_buttons: Array = app.stitched_run_buttons.duplicate()
	var old_actions := session.visit_actions()
	button.pressed.emit()
	var expected_pockets: Dictionary = before.pockets.duplicate(true)
	expected_pockets[hero_id].append("pins")
	_check(session.phase == "map" and session.gold == before.gold - 10
		and session.pockets == expected_pockets and session.heroes == before.heroes
		and session.rng.state == before.rng and session.map.export_state() == before.map,
		"one mounted buy charges exactly 10 and adds one owned pins without unrelated mutations")
	_check(session.receipts.size() == before.receipts.size() + 1 and session.pending.is_empty()
		and session.journal.size() == journal_size + 1
		and session.journal.back() == {"action": "visit", "id": "buy_pins", "arguments": [hero_id]}
		and session.receipts.back().decision == "buy_pins" and session.receipts.back().steps.size() == 1,
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
	for ledger in [null, [], {}, {hero_id: ["pins"]}]:
		var corrupt := saved.duplicate(true)
		corrupt.state.pockets = ledger
		corrupt.digest = StitchedRunSave._digest(corrupt)
		_check(StitchedRunSave.restore(corrupt) == null, "malformed pocket save fails closed even with recomputed digest")
	for items in [["unknown"], ["pins", "pins", "pins"], [], ["dye"]]:
		var corrupt := saved.duplicate(true)
		corrupt.state.pockets[hero_id] = items
		corrupt.digest = StitchedRunSave._digest(corrupt)
		_check(StitchedRunSave.restore(corrupt) == null, "forged ownership cannot replace the replayed purchase ledger")
	var legacy := saved.duplicate(true)
	legacy.state.erase("pockets")
	legacy.digest = StitchedRunSave._digest(legacy)
	_check(StitchedRunSave.restore(legacy) == null, "omitting pockets cannot disguise a new purchase as an old save")
	var doubled := saved.duplicate(true)
	doubled.journal.append(doubled.journal.back().duplicate(true))
	doubled.digest = StitchedRunSave._digest(doubled)
	_check(StitchedRunSave.restore(doubled) == null, "replayed duplicate purchase fails closed")
	_save_reload(app, "post-purchase map")


func _earned_cap_route() -> void:
	var app: Node = await _new_run(201)
	var session: StitchedRunSession = app.stitched_run_session
	if session == null:
		app.free()
		return
	var shops := 0
	var fights := 0
	for id in ["f01_n1", "f02_n1", "f03_n1", "f04_n1", "f05_n1", "f06_n1", "f07_n0", "f08_n0"]:
		_check(session.choices().has(id) and _press_route(app, id), "seeded connected control enters " + id)
		if session.phase == "battle":
			var stage: StitchedBattleScreen = app.stitched_run_battle
			_check(stage != null and stage.battle == session.battle, "real routed fight is mounted before earning gold")
			if stage == null:
				break
			var result := _win(stage)
			_check(result.acted > 0 and stage.battle.outcome() == "victory", "legal mounted combat earns the pins wallet")
			stage._action_buttons["exit"].pressed.emit()
			fights += 1
		elif session.phase == "visit" and session.pending.service == "Peddler":
			shops += 1
			_pins_controls(app)
			_reject_choices(session)
			if shops <= 2:
				_check(fights == 3 and session.gold >= 10, "three genuine victories funded this purchase")
				var stale_button := _visit_button(app, "buy_pins", ["warden"])
				_save_reload(app, "open Peddler")
				session = app.stitched_run_session
				var reloaded := session.snapshot()
				stale_button.pressed.emit()
				_check(session.snapshot() == reloaded, "pre-reload callback cannot authorize the restored visit")
				_pins_controls(app)
				_buy(app, "warden")
				session = app.stitched_run_session
			else:
				_check(session.pockets.warden == ["pins", "pins"] and session.gold >= 10,
					"full-pocket refusal is witnessed with an otherwise affordable wallet")
				var before := session.snapshot()
				_visit_button(app, "leave").pressed.emit()
				_check(session.phase == "map" and session.gold == before.gold and session.pockets == before.pockets
					and session.rng.state == before.rng and session.map.export_state() == before.map,
					"free Leave closes the full-pocket Shop without any spend or RNG draw")
		else:
			_check(_finish_visit(app) and session.phase == "map", "ordinary mounted stop continues the connected route")
	_check(shops == 3 and fights == 3 and session.pockets.warden == ["pins", "pins"],
		"three Shops and two earned purchases exercised the two-item cap non-vacuously")
	_save_reload(app, "onward ownership")
	session = app.stitched_run_session
	var next_choices := session.choices()
	_check(not next_choices.is_empty(), "reloaded ownership has a legal onward node")
	if not next_choices.is_empty():
		_check(_press_route(app, next_choices[0]) and session.pockets.warden == ["pins", "pins"],
			"continued real next-node play retains both owned pins")
		var restored := StitchedRunSave.restore(StitchedRunSave.capture(session))
		_check(restored != null and restored.snapshot() == session.snapshot(), "onward state replays with exact ownership")
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
		_check(_press_route(app, witness.id) and session.gold == 0, "opening Shop has the normal empty wallet")
		_pins_controls(app)
		var before := session.snapshot()
		var forged := StitchedRunSave.capture(session)
		forged.journal.append({"action": "visit", "id": "buy_pins", "arguments": [session.heroes[0].id]})
		forged.digest = StitchedRunSave._digest(forged)
		_check(StitchedRunSave.restore(forged) == null and session.snapshot() == before,
			"rehashed unaffordable purchase command fails replay without mutating the live visit")
		var old_pins := _visit_button(app, "buy_pins", [session.heroes[0].id])
		_visit_button(app, "leave").pressed.emit()
		_check(session.phase == "map" and session.gold == 0 and session.pockets == before.pockets
			and session.rng.state == before.rng, "unaffordable Shop still has a free usable Leave")
		var left := session.snapshot()
		old_pins.pressed.emit()
		_check(not session.choose_visit("buy_pins", [session.heroes[0].id], before)
			and session.snapshot() == left, "Leave closes competing pins callbacks without any spend")
	app.free()
	await process_frame


func _lost_shop() -> void:
	var app: Node = await _new_run(0)
	var session: StitchedRunSession = app.stitched_run_session
	if session == null:
		app.free()
		return
	var fight_id := ""
	for id in session.choices():
		if session.map.get_node(id).type == "Fight":
			fight_id = id
	_check(not fight_id.is_empty() and _press_route(app, fight_id), "LOST witness enters a genuine fight")
	var stage: StitchedBattleScreen = app.stitched_run_battle
	if stage == null:
		app.free()
		return
	for step in range(500):
		if stage.battle.is_over() or stage.battle.get_heroes().any(func(hero: Dictionary): return hero.lost):
			break
		stage._action_buttons["pass"].pressed.emit()
	var result := _win(stage)
	_check(result.acted > 0 and stage.battle.outcome() == "victory"
		and stage.battle.get_heroes().any(func(hero: Dictionary): return hero.lost), "enemy turns genuinely lose a doll before the survivors win")
	stage._action_buttons["exit"].pressed.emit()
	var shop_id := ""
	for id in session.choices():
		if session.map.get_node(id).type == "Shop":
			shop_id = id
	_check(not shop_id.is_empty() and _press_route(app, shop_id), "earned LOST roster reaches its connected Shop")
	if session.phase == "visit" and session.pending.service == "Peddler":
		_pins_controls(app)
		_save_reload(app, "LOST Peddler")
		session = app.stitched_run_session
		_pins_controls(app)
		var living := session.heroes.filter(func(hero: Dictionary): return not hero.lost)
		_check(living.size() > 0 and session.heroes.any(func(hero: Dictionary): return hero.lost), "living and LOST controls both have witnesses")
		if not living.is_empty():
			_buy(app, living[0].id)
			session = app.stitched_run_session
			_check(session.choices().has("f03_n3") and _press_route(app, "f03_n3")
				and session.pending.service == "SewingCircle", "owned pins continue into a genuine Sewing Circle")
			var replacements := session.visit_actions().filter(func(action: Dictionary): return action.id == "replace" and action.enabled)
			_check(not replacements.is_empty(), "genuine LOST doll has a mounted replacement choice")
			if not replacements.is_empty():
				var action: Dictionary = replacements[0]
				var before := session.pockets.duplicate(true)
				var expected := before.duplicate(true)
				expected.erase(action.arguments[1])
				expected[action.arguments[0]] = []
				_visit_button(app, action.id, action.arguments).pressed.emit()
				_check(session.pockets == expected and session.pockets.size() == 4
					and session.pockets[living[0].id] == ["pins"],
					"replacement removes the retired ID, starts an empty new pocket and preserves survivors' pins")
				_save_reload(app, "replacement with owned pins")
				session = app.stitched_run_session
				_check(session.pockets == expected, "replacement pocket ownership replays by canonical ID")
	app.free()
	await process_frame


func _run() -> void:
	await _poor_shop()
	await _earned_cap_route()
	await _lost_shop()
	DirAccess.remove_absolute(SAVE_PATH)
	for message in failures:
		printerr(message)
	print("stitched_s6_routed_pins_live_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
