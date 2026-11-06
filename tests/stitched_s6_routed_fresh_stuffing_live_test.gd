extends "res://tests/stitched_s6_routed_vis_a_test.gd"
## Earned wallets and genuine generated Shops, driven through New Run controls.

const SAVE_PATH := "user://stitched_s6_routed_stuffing_live.save"
var wounded_purchases := 0


func _visit_button(app: Node, id: String, arguments: Array = []) -> Button:
	var actions: Array = app.stitched_run_session.visit_actions()
	for index in actions.size():
		if actions[index].id == id and actions[index].arguments == arguments:
			return app.stitched_run_buttons[index]
	_check(false, "mounted visit has requested action " + id + str(arguments))
	return null


func _stuffing_controls(app: Node) -> void:
	var session: StitchedRunSession = app.stitched_run_session
	_check(session.phase == "visit" and session.pending.service == "Peddler"
		and session.map.get_node(session.pending.node_id).type == "Shop",
		"fresh stuffing are mounted at a genuine generated routed Shop")
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
			_check(not _visit_button(app, "bandage", [hero.id]).disabled, "existing eligible bandage remains buyable")


func _save_reload(app: Node, label: String, stale_button: Button = null) -> void:
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
	if stale_button != null:
		stale_button.pressed.emit()
		_check(app.stitched_run_session.snapshot() == before,
			"pre-reload callback cannot authorize the restored visit")
	var continued: Node = load("res://scenes/app.tscn").instantiate()
	continued.stitched_save_path = SAVE_PATH
	root.add_child(continued)
	await process_frame
	_check(continued.stitched_run_session == null and continued.title_view.is_visible_in_tree()
		and continued.stitched_continue_button.is_visible_in_tree()
		and not continued.stitched_continue_button.disabled, label + " fresh title exposes Continue run")
	continued.stitched_continue_button.pressed.emit()
	_check(continued.stitched_run_session != null and continued.stitched_run_session != session
		and continued.stitched_run_session.snapshot() == before
		and continued.stitched_run_session.visit_actions() == app.stitched_run_session.visit_actions(),
		label + " authentic title Continue restores all four pockets, wallet and choices")
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
			_check(result.acted > 0 and stage.battle.outcome() == "victory", "legal mounted combat earns the stuffing wallet")
			stage._action_buttons["exit"].pressed.emit()
			fights += 1
		elif session.phase == "visit" and session.pending.service == "Peddler":
			shops += 1
			_stuffing_controls(app)
			_reject_choices(session)
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
				_visit_button(app, "leave").pressed.emit()
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
		_check(_press_route(app, witness.id) and session.gold == 0, "opening Shop has the normal empty wallet")
		_stuffing_controls(app)
		var before := session.snapshot()
		var forged := StitchedRunSave.capture(session)
		forged.journal.append({"action": "visit", "id": "buy_fresh_stuffing", "arguments": [session.heroes[0].id]})
		forged.digest = StitchedRunSave._digest(forged)
		_check(StitchedRunSave.restore(forged) == null and session.snapshot() == before,
			"rehashed unaffordable purchase command fails replay without mutating the live visit")
		var old_stuffing := _visit_button(app, "buy_fresh_stuffing", [session.heroes[0].id])
		_visit_button(app, "leave").pressed.emit()
		_check(session.phase == "map" and session.gold == 0 and session.pockets == before.pockets
			and session.rng.state == before.rng, "unaffordable Shop still has a free usable Leave")
		var left := session.snapshot()
		old_stuffing.pressed.emit()
		_check(not session.choose_visit("buy_fresh_stuffing", [session.heroes[0].id], before)
			and session.snapshot() == left, "Leave closes competing stuffing callbacks without any spend")
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
		_stuffing_controls(app)
		await _save_reload(app, "LOST Peddler")
		session = app.stitched_run_session
		_stuffing_controls(app)
		var living := session.heroes.filter(func(hero: Dictionary): return not hero.lost)
		_check(living.size() > 0 and session.heroes.any(func(hero: Dictionary): return hero.lost), "living and LOST controls both have witnesses")
		if not living.is_empty():
			await _buy(app, living[0].id)
			session = app.stitched_run_session
			_check(session.choices().has("f03_n3") and _press_route(app, "f03_n3")
				and session.pending.service == "SewingCircle", "owned stuffing continue into a genuine Sewing Circle")
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
