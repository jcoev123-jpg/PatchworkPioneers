extends SceneTree
## S8/S9: the public seeded Walk -> Fight -> victory Continue -> map -> title Continue handoff.
const SAVE_PATH := "user://stitched_s8s9_corridor_victory_handoff_test.save"
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)


func _press(button: BaseButton, description: String) -> bool:
	var live := is_instance_valid(button) and button.is_inside_tree() and button.is_visible_in_tree() and not button.disabled
	_check(live, "mounted enabled control: " + description)
	if live:
		button.pressed.emit()
	return live


func _app(seed_number: int) -> Node:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	app.run_seed = seed_number
	app.stitched_walks = true
	app.stitched_save_path = SAVE_PATH
	root.add_child(app)
	return app


func _ticket(app: Node, kind: String = "") -> Button:
	var session: StitchedRunSession = app.stitched_run_session
	if session == null or session.phase != "map":
		return null
	for button: Button in app.stitched_run_buttons:
		var id := str(button.get_meta("route_id", ""))
		if id in session.choices() and (kind.is_empty() or str(session.map.get_node(id).type) == kind):
			if str(session.map.get_node(id).type) != "Boss":
				return button
	return null


func _walk_to_stop(app: Node, ordinal: int, expected_id: String) -> bool:
	var session: StitchedRunSession = app.stitched_run_session
	var ready := session != null and session.phase == "walk" and session.walk != null \
		and is_instance_valid(app.stitched_run_walk)
	_check(ready, "Walk %d is actually hosted" % ordinal)
	if not ready:
		return false
	var walker: StitchedWalkScreen = app.stitched_run_walk
	_check(walker.host == session and walker.walk == session.walk and walker.is_visible_in_tree(),
		"Walk %d has genuine live movement controls" % ordinal)
	var steps := 0
	while is_instance_valid(app.stitched_run_walk) and steps < 40:
		steps += 1
		walker = app.stitched_run_walk
		if not _press(walker.forward_button, "Walk %d forward / tug %d" % [ordinal, steps]):
			return false
		await process_frame
	var arrived := steps > 0 and steps < 40 and session.walk == null \
		and not is_instance_valid(app.stitched_run_walk) and session.phase in ["visit", "battle"] \
		and session.walk_receipts.size() == ordinal \
		and str(session.walk_receipts.back().get("node_id", "")) == expected_id
	_check(arrived, "Walk %d arrives with exactly its true stop receipt" % ordinal)
	return arrived


func _corridor(app: Node, session: StitchedRunSession) -> StitchedCorridorFight:
	var views := app.find_children("CorridorFight", "Control", true, false)
	var engine: StitchedBattleScreen = app.stitched_run_battle
	var good: bool = session != null and session.phase == "battle" and session.battle != null \
		and views.size() == 1 and is_instance_valid(engine) and engine.battle == session.battle \
		and engine.is_visible_in_tree() and not app.title_view.visible
	var fight: StitchedCorridorFight = views[0] as StitchedCorridorFight if views.size() == 1 else null
	_check(good and fight != null and fight.engine == engine and fight.battle == session.battle \
		and fight.is_visible_in_tree() and fight.get_parent() == engine,
		"exactly one live corridor overlays the session's authoritative Fight")
	return fight if good else null


func _fight_to_victory(fight: StitchedCorridorFight, session: StitchedRunSession) -> bool:
	var screen: StitchedBattleScreen = fight.engine
	var attacks := 0
	var waits := 0
	var turns := 0
	while not session.battle.is_over() and turns < 250:
		turns += 1
		if session.battle.current_side() != "hero":
			_check(false, "the real engine returns to a playable doll turn")
			break
		var committed := false
		# Prefer damaging parts. A one-target part may commit immediately in choose_part.
		for slot in ["arms", "legs", "torso", "head"]:
			if fight.part_buttons[slot].disabled:
				continue
			var before := session.journal.size()
			var result := fight.choose_part(slot)
			if str(result.get("pending", "")) == slot:
				var targets := screen.legal_targets()
				if not targets.is_empty():
					var target: String = str(targets.keys()[0])
					for key in targets:
						if str(key).begins_with("foe_"):
							target = str(key)
							break
					result = fight.click_figure(target.get_slice("_", 0), int(target.get_slice("_", 1)))
			if session.journal.size() > before:
				_check(result.get("ok") == true and session.journal.back().get("action") == "battle" \
					and session.is_consistent(), "mounted body-part attack commits one real battle command")
				attacks += 1
				committed = true
				break
			# A rejected/pending part is not a turn; clear the selection through the same control.
			if screen._selected_part == slot:
				fight.choose_part(slot)
		if not committed:
			var previous := session.journal.size()
			if not _press(fight.more_button, "More for legal Pass"):
				break
			if not _press(fight.more_buttons["pass"], "Pass the doll's turn"):
				break
			_check(session.journal.size() > previous and session.journal[previous].get("method") == "pass_turn" \
				and session.is_consistent(), "Pass is journaled through the visible More menu")
			waits += 1
		await process_frame
	var won := session.battle != null and session.battle.is_over() and session.battle.outcome() == "victory"
	_check(won and turns < 250 and attacks >= 3, 
		"four dolls genuinely win seeded corridor Fight with %d part actions and %d passes in %d turns" % [attacks, waits, turns])
	return won


func _hero_contract(expected: Array, actual: Array, description: String) -> void:
	_check(expected.size() == 4 and actual.size() == 4, description + ": all four dolls are present")
	if expected.size() != actual.size():
		return
	for index in expected.size():
		var a: Dictionary = expected[index]
		var b: Dictionary = actual[index]
		_check(a.get("id") == b.get("id") and a.get("hp") == b.get("hp") \
			and a.get("fray") == b.get("fray") and a.get("parts") == b.get("parts") \
			and a.get("lost") == b.get("lost"),
			description + ": " + str(a.get("id")) + " preserves HP/fray/equipped gear/loss")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.remove_absolute(SAVE_PATH + ".tmp")
	# Seed 53: the appended doll-scale route-effect stories shift the sorted Event pool's
	# single draw, so this witness seed must reach a lawful Event Leave and a next Fight.
	var app := _app(53)
	await process_frame
	await process_frame
	_check(app.title_view.is_visible_in_tree() and app.stitched_run_session == null,
		"fresh title has no fixture battle")
	if not _press(app.start_button, "New Run"):
		_finish(app)
		return
	await process_frame
	if app.stitched_run_buttons.is_empty() or not _press(app.stitched_run_buttons[0], "four-doll Set out"):
		_finish(app)
		return
	await process_frame
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.seed_value == 53 and session.heroes.size() == 4 \
		and session.walks_enabled and session.is_consistent(), "real seed 53 four-doll Walk session")
	if session == null:
		_finish(app)
		return
	var begin: Button = app.stitched_run_intro.find_child("WrenIntroBegin", true, false) as Button \
		if is_instance_valid(app.stitched_run_intro) else null
	if not _press(begin, "Begin the night"):
		_finish(app)
		return
	await process_frame
	var event := _ticket(app, "Event")
	if not _press(event, "legal Event ticket"):
		_finish(app)
		return
	var event_id := str(event.get_meta("route_id"))
	await process_frame
	if not await _walk_to_stop(app, 1, event_id) or session.phase != "visit" \
		or session.pending.get("service") != "Event":
		_check(false, "seeded Event reaches an authentic public service")
		_finish(app)
		return
	var leave: Button
	for button: Button in app.stitched_run_buttons:
		if str(button.get_meta("action_id", "")) in ["leave", "decline_trade"] and not button.disabled:
			leave = button
			break
	if not _press(leave, "Event Leave"):
		_finish(app)
		return
	await process_frame
	var fight_ticket := _ticket(app, "Fight")
	if not _press(fight_ticket, "next legal Fight ticket"):
		_finish(app)
		return
	var fight_id := str(fight_ticket.get_meta("route_id"))
	await process_frame
	if not await _walk_to_stop(app, 2, fight_id):
		_finish(app)
		return
	var corridor := _corridor(app, session)
	if corridor == null:
		_finish(app)
		return
	_check(session.receipts.filter(func(receipt: Dictionary): return receipt.get("kind") == "Fight").is_empty() \
		and session.walk_receipts.size() == 2 and not corridor.continue_button.visible \
		and not session.battle.is_over(),
		"Fight enters without its own settlement; Continue is not offered before victory")
	var before_early := session.snapshot()
	var early_journal := session.journal.duplicate(true)
	var early_receipts := session.receipts.duplicate(true)
	# Exercise the actual Continue callback while hidden: it must not exit or settle.
	corridor.continue_button.pressed.emit()
	_check(session.phase == "battle" and app.stitched_run_battle == corridor.engine \
		and session.snapshot() == before_early and session.journal == early_journal \
		and session.receipts == early_receipts, "premature Continue cannot exit, pay or spend RNG")
	if not await _fight_to_victory(corridor, session):
		_finish(app)
		return
	await process_frame
	var battle := session.battle
	var final_heroes: Array = battle.get_heroes().duplicate(true)
	var battle_satchel: Array = battle.satchel().duplicate(true)
	var previous_walks := session.walk_receipts.duplicate(true)
	var previous_receipts := session.receipts.duplicate(true)
	var previous_journal := session.journal.duplicate(true)
	var gold_before := session.gold
	var scraps_before := session.scraps
	var candle_before := session.candle
	var pockets_before := session.pockets.duplicate(true)
	var patches_before := session.patches.duplicate(true)
	var fear_before := session.kid_fear()
	_check(corridor.continue_button.is_visible_in_tree() and not corridor.continue_button.disabled \
		and corridor.outcome_label.visible and corridor.outcome_label.text == "VICTORY",
		"visible enabled post-victory Continue is the public exit")
	if not _press(corridor.continue_button, "victory Continue"):
		_finish(app)
		return
	# The original signal may still be invoked in this same frame; settlement must be one-shot.
	corridor.continue_button.pressed.emit()
	await process_frame
	_check(session.phase == "map" and session.battle == null and session.pending.is_empty() \
		and app.stitched_run_battle == null and app.stitched_run_panel != null \
		and app.stitched_run_panel.is_visible_in_tree() and app.find_children("CorridorFight", "Control", true, false).is_empty(),
		"only Continue returns to a live routed map, never a second Fight")
	_check(session.receipts.size() == previous_receipts.size() + 1 \
		and session.receipts.slice(0, previous_receipts.size()) == previous_receipts \
		and session.journal.size() == previous_journal.size() + 1 \
		and session.journal.slice(0, previous_journal.size()) == previous_journal \
		and session.journal.back() == {"action": "settle"} \
		and session.walk_receipts == previous_walks and session.is_consistent(),
		"one and only one Fight settlement receipt, journal settle and intact old Walk receipts")
	if session.receipts.size() != previous_receipts.size() + 1:
		_finish(app)
		return
	var receipt: Dictionary = session.receipts.back()
	var reward: Dictionary = receipt.get("reward", {})
	var awarded: Array = reward.get("parts", [])
	var expected_satchel: Array = battle_satchel.duplicate(true)
	expected_satchel.append_array(awarded)
	_check(receipt.get("node_id") == fight_id and receipt.get("kind") == "Fight" \
		and receipt.get("outcome") == "victory" and reward.has("gold") \
		and reward.has("scraps") and reward.has("parts") and awarded.size() <= 1,
		"receipt belongs to exactly the won routed Fight and describes its real random award")
	_check(session.gold == gold_before + int(reward.get("gold", -999)) \
		and session.scraps == scraps_before + int(reward.get("scraps", -999)) \
		and session.satchel == expected_satchel, "gold, scraps and optional trophy exactly equal receipt payouts")
	_check(session.candle == candle_before and session.pockets == pockets_before \
		and session.patches == patches_before and session.kid_fear() == fear_before,
		"settlement retains candle, pockets, patches and Wren's state")
	_hero_contract(final_heroes, session.heroes, "post-victory")
	var settled_snapshot := session.snapshot()
	var settled_journal := session.journal.duplicate(true)
	var settled_receipts := session.receipts.duplicate(true)
	var settled_walks := session.walk_receipts.duplicate(true)
	var settled_rng := session.rng.state
	# A duplicate stale signal, including one after the old stage is removed, has no entry point.
	_check(session.snapshot() == settled_snapshot and session.receipts == settled_receipts \
		and session.journal == settled_journal, "double Continue grants no second settlement")
	var save: BaseButton
	for button: Button in app.stitched_run_buttons:
		if button.text == "Save run" and button.is_visible_in_tree():
			save = button
			break
	if not _press(save, "mounted map Save run"):
		_finish(app)
		return
	var saved := StitchedRunSave.read_file(SAVE_PATH)
	_check(FileAccess.file_exists(SAVE_PATH) and saved != null and saved.snapshot() == settled_snapshot \
		and saved.journal == settled_journal and saved.receipts == settled_receipts \
		and saved.walk_receipts == settled_walks and saved.rng.state == settled_rng,
		"map Save persists the exact won snapshot, settlement, walks, journal and RNG")
	if saved == null:
		_finish(app)
		return
	app.free()
	await process_frame
	var fresh := _app(999)
	await process_frame
	await process_frame
	_check(fresh.title_view.is_visible_in_tree() and fresh.stitched_run_session == null,
		"fresh instance begins at title, not retained prior map")
	if not _press(fresh.stitched_continue_button, "fresh title Continue"):
		_finish(fresh)
		return
	await process_frame
	var restored: StitchedRunSession = fresh.stitched_run_session
	_check(restored != null and restored != session and restored.snapshot() == settled_snapshot \
		and restored.journal == settled_journal and restored.receipts == settled_receipts \
		and restored.walk_receipts == settled_walks and restored.rng.state == settled_rng \
		and restored.is_consistent() and restored.phase == "map" \
		and fresh.stitched_run_panel.is_visible_in_tree(),
		"title Continue recreates complete settled map, receipts, journal and RNG")
	if restored == null:
		_finish(fresh)
		return
	var next_ticket := _ticket(fresh)
	_check(next_ticket != null and restored.choices().size() > 0 \
		and restored.candle >= StitchedRunSession.NODE_CANDLE_COST,
		"restored map has a new legal non-Boss node and enough candle for its toll")
	if next_ticket == null:
		_finish(fresh)
		return
	var new_id := str(next_ticket.get_meta("route_id"))
	var old_candle := restored.candle
	var old_journal := restored.journal.size()
	var old_walk_count := restored.walk_receipts.size()
	var old_heroes := restored.heroes.duplicate(true)
	var old_satchel := restored.satchel.duplicate(true)
	var old_gold := restored.gold
	var old_scraps := restored.scraps
	var old_pockets := restored.pockets.duplicate(true)
	var old_patches := restored.patches.duplicate(true)
	var old_fear := restored.kid_fear()
	if not _press(next_ticket, "restored legal non-Boss route ticket"):
		_finish(fresh)
		return
	await process_frame
	_check(restored.phase == "walk" and restored.pending.get("node_id") == new_id \
		and restored.walk != null and is_instance_valid(fresh.stitched_run_walk) \
		and fresh.stitched_run_walk.is_visible_in_tree() \
		and fresh.stitched_run_walk.host == restored and fresh.stitched_run_walk.walk == restored.walk,
		"one fresh hosted Walk is mounted from a legal restored route ticket")
	_check(restored.candle == old_candle - StitchedRunSession.NODE_CANDLE_COST \
		and restored.journal.size() == old_journal + 1 \
		and restored.journal.back() == {"action": "enter", "node_id": new_id} \
		and restored.walk_receipts.size() == old_walk_count and restored.receipts == settled_receipts,
		"exactly one new node candle toll, entry and no premature Walk or Fight settlement")
	_check(restored.heroes == old_heroes and restored.satchel == old_satchel \
		and restored.gold == old_gold and restored.scraps == old_scraps \
		and restored.pockets == old_pockets and restored.patches == old_patches \
		and restored.kid_fear() == old_fear and restored.is_consistent(),
		"new Walk retains the saved dolls, gear and resources except exactly one candle toll")
	var continued := StitchedRunSave.restore(StitchedRunSave.capture(restored))
	_check(continued != null and continued.snapshot() == restored.snapshot() \
		and continued.journal == restored.journal and continued.rng.state == restored.rng.state,
		"resumed legal Walk also replays with precisely matching snapshot, journal and RNG")
	_finish(fresh)


func _finish(app: Node) -> void:
	if is_instance_valid(app):
		app.free()
	DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.remove_absolute(SAVE_PATH + ".tmp")
	for failure in failures:
		printerr(failure)
	print("stitched_s8s9_corridor_victory_handoff_test: %s (%d checks, %d failures)" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
