extends SceneTree
## S8/S9 post-entry: only the live title -> Walk -> corridor UI can spend actions.
const SAVE_PATH := "user://stitched_s8s9_live_combat_continue_test.save"
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
	_run.call_deferred()
func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
func _press(button: BaseButton, label: String) -> bool:
	var ready := is_instance_valid(button) and button.is_inside_tree() and button.is_visible_in_tree() and not button.disabled
	_check(ready, "real enabled mounted control: " + label)
	if ready:
		button.pressed.emit()
	return ready
func _app(seed_number: int) -> Node:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	app.run_seed = seed_number
	app.stitched_walks = true
	app.stitched_save_path = SAVE_PATH
	root.add_child(app)
	return app
func _ticket(app: Node, kind: String) -> Button:
	var session: StitchedRunSession = app.stitched_run_session
	if session == null or session.phase != "map":
		return null
	for button: Button in app.stitched_run_buttons:
		var id := str(button.get_meta("route_id", ""))
		if id in session.choices() and str(session.map.get_node(id).type) == kind:
			return button
	return null
func _walk(app: Node, ordinal: int) -> bool:
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.phase == "walk" and session.walk != null
		and is_instance_valid(app.stitched_run_walk), "Walk %d is hosted by the real run" % ordinal)
	if session == null or session.walk == null or not is_instance_valid(app.stitched_run_walk):
		return false
	var walker: StitchedWalkScreen = app.stitched_run_walk
	_check(walker.host == session and walker.walk == session.walk and walker.is_visible_in_tree(),
		"Walk %d has the real live controls" % ordinal)
	var steps := 0
	while is_instance_valid(app.stitched_run_walk) and steps < 40:
		steps += 1
		walker = app.stitched_run_walk
		if not _press(walker.forward_button, "Walk %d forward/tug %d" % [ordinal, steps]):
			return false
		await process_frame
	_check(steps > 0 and steps < 40 and session.walk == null
		and not is_instance_valid(app.stitched_run_walk) and session.phase in ["visit", "battle"]
		and session.walk_receipts.size() == ordinal, "Walk %d reaches its actual stop" % ordinal)
	return steps > 0 and steps < 40 and session.walk == null and session.phase in ["visit", "battle"]
func _fight(app: Node, session: StitchedRunSession, label: String) -> StitchedCorridorFight:
	var stages := app.find_children("CorridorFight", "Control", true, false)
	var screen: StitchedBattleScreen = app.stitched_run_battle
	var good: bool = session != null and session.phase == "battle" and session.battle != null 		and stages.size() == 1 and is_instance_valid(screen) and screen.battle == session.battle 		and screen.is_visible_in_tree() and not app.title_view.visible
	var corridor: StitchedCorridorFight = stages[0] as StitchedCorridorFight if stages.size() == 1 else null
	_check(good and corridor != null and corridor.engine == screen and corridor.battle == session.battle
		and corridor.is_visible_in_tree() and corridor.get_parent() == screen,
		label + ": exactly one player-visible corridor wraps the authoritative live battle")
	return corridor if good else null
func _state(session: StitchedRunSession, screen: StitchedBattleScreen) -> Dictionary:
	return {"snapshot": session.snapshot(), "journal": session.journal.duplicate(true),
		"run_rng": session.rng.state, "battle": session.battle.state_snapshot(),
		"ui_receipts": screen.receipts.duplicate(true)}
func _off_rank_refusal(corridor: StitchedCorridorFight, session: StitchedRunSession) -> bool:
	var screen: StitchedBattleScreen = corridor.engine
	# Find a mounted part with a real target choice; no fixture or synthesized combat.
	for slot in StitchedBattleScreen.SLOTS:
		if corridor.part_buttons[slot].disabled:
			continue
		var before := session.journal.size()
		_press(corridor.part_buttons[slot], "choose " + slot + " for negative rank check")
		if session.journal.size() != before: # one-target part auto-committed; try the next live actor
			return false
		if screen._selected_part != slot or screen.legal_targets().is_empty():
			continue
		var legal := screen.legal_targets()
		for rank in range(1, 5):
			var key := "foe_" + str(rank)
			if legal.has(key):
				continue
			var pristine := _state(session, screen)
			var selected := screen._selected_part
			var refused := corridor.click_figure("foe", rank)
			_check(refused.get("ok") == false and _state(session, screen) == pristine
				and screen._selected_part == selected and session.is_consistent(),
				"off-rank target is refused with unchanged HP/fray/actions/resources/journal/RNG")
			return true
	return false
func _legal_part(corridor: StitchedCorridorFight, session: StitchedRunSession, require_foe: bool = false) -> bool:
	var screen: StitchedBattleScreen = corridor.engine
	for slot in StitchedBattleScreen.SLOTS:
		if corridor.part_buttons[slot].disabled:
			continue
		if slot == "head": continue # Seamstress head heals allies; exercise a real foe-target attack.
		if screen._selected_part == slot: corridor.part_buttons[slot].pressed.emit()
		var old := session.journal.size()
		var receipt_count := screen.receipts.size()
		if not _press(corridor.part_buttons[slot], "mounted " + slot + " ability"):
			return false
		if session.journal.size() == old:
			var targets := screen.legal_targets()
			_check(screen._selected_part == slot and not targets.is_empty(),
				"mounted part selection exposes legal ranks")
			if targets.is_empty():
				continue
			var key: String = str(targets.keys()[0])
			if not _press(corridor.hits.get(key) as BaseButton, "mounted " + key + " part target"):
				return false
		var committed := session.journal.slice(old)
		var own := committed.filter(func(entry: Dictionary): return entry.get("action") == "battle" and entry.get("method") == "use_part")
		_check(own.size() == 1 and screen.receipts.size() > receipt_count
			and screen.receipts[receipt_count].get("action") == "ability" and not screen.receipts[receipt_count].get("results", []).is_empty()
			and (not require_foe or str(session.battle.get_unit(str(screen.receipts[receipt_count]["results"][0].get("target", ""))).get("side", "")) == "foe") and session.is_consistent(),
			"one mounted part attack commits exactly once and produces an authoritative ability receipt")
		return own.size() == 1
	return false
func _foe_receipts_since(session: StitchedRunSession, start: int) -> int:
	var count := 0
	for entry in session.journal.slice(start):
		if entry is Dictionary and entry.get("action") == "battle" 			and entry.get("method") in ["use_foe_ability", "pass_turn"]:
			# Only a foe's recorded ability is a meaningful foe response.
			if entry.get("method") == "use_foe_ability":
				count += 1
	return count
func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.remove_absolute(SAVE_PATH + ".tmp")
	# Seed 68: the appended doll-scale route-effect stories shift the sorted Event pool's
	# single draw, so this witness seed must reach a lawful Event Leave and a next Fight.
	var app := _app(68)
	await process_frame
	await process_frame
	_check(app.title_view.is_visible_in_tree() and app.stitched_run_session == null,
		"fresh title has no prebuilt battle")
	if not _press(app.start_button, "New Run"):
		_finish(app)
		return
	await process_frame
	if app.stitched_run_buttons.is_empty() or not _press(app.stitched_run_buttons[0], "four-doll Set out"):
		_finish(app)
		return
	await process_frame
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.seed_value == 68 and session.heroes.size() == 4 and session.walks_enabled,
		"seed 68 uses four selected dolls and Walk travel")
	if session == null:
		_finish(app)
		return
	var begin: Button = app.stitched_run_intro.find_child("WrenIntroBegin", true, false) as Button 		if is_instance_valid(app.stitched_run_intro) else null
	if not _press(begin, "Wren intro Begin the night"):
		_finish(app)
		return
	await process_frame
	var event := _ticket(app, "Event")
	if not _press(event, "lawful Event ticket"):
		_finish(app)
		return
	await process_frame
	if not await _walk(app, 1) or session.phase != "visit" or session.pending.service != "Event":
		_check(false, "seeded Event Walk reaches its real event visit")
		_finish(app)
		return
	var leave: Button
	for button: Button in app.stitched_run_buttons:
		if str(button.get_meta("action_id", "")) in ["leave", "decline_trade"] and not button.disabled:
			leave = button
			break
	if not _press(leave, "lawful Event Leave"):
		_finish(app)
		return
	await process_frame
	var fight := _ticket(app, "Fight")
	if not _press(fight, "lawful next Fight ticket"):
		_finish(app)
		return
	await process_frame
	if not await _walk(app, 2):
		_finish(app)
		return
	var corridor := _fight(app, session, "post-Walk Fight")
	if corridor == null:
		_finish(app)
		return
	var screen: StitchedBattleScreen = corridor.engine
	var battle: StitchedRunSession.RankedBattle = session.battle
	_check(battle.current_side() == "hero" and battle.hand_action_open()
		and not corridor.hand_buttons["steady"].disabled, "Wren's hand is enabled on a real doll turn")
	if not battle.hand_action_open() or battle.current_side() != "hero":
		_finish(app)
		return
	var initial := _state(session, screen)
	var start_journal := session.journal.size()
	_press(corridor.hand_buttons["steady"], "Wren's mounted Steady")
	_check(screen._hand_pending == "steady" and not screen.legal_targets().is_empty(),
		"Steady arms the actual mounted hero target choice without spending")
	var hand_keys := screen.legal_targets().keys().filter(func(key: String): return str(key).begins_with("hero_"))
	if hand_keys.is_empty():
		_check(false, "Steady provides a real living doll target")
		_finish(app)
		return
	var hero_key: String = str(hand_keys[0])
	if not _press(corridor.hits.get(hero_key) as BaseButton, "Wren steadies " + hero_key):
		_finish(app)
		return
	await process_frame
	var hand_commands := session.journal.slice(start_journal)
	_check(hand_commands.size() == 1 and hand_commands[0] == {"action": "battle",
			"method": "use_hand_action", "arguments": ["steady", str(screen._unit_at("hero", int(hero_key.get_slice("_", 1))).get("id", "")), 0]}
		and session.snapshot() != initial.snapshot and screen.receipts.size() == initial.ui_receipts.size() + 1
		and screen.receipts.back().get("action") == "hand" and not battle.hand_action_open(),
		"one Wren command changes the authoritative hand receipt, state and journal")
	var spent := _state(session, screen)
	var target_id := str(screen._unit_at("hero", int(hero_key.get_slice("_", 1))).get("id", ""))
	var duplicate := screen.submit_hand_action("steady", int(hero_key.get_slice("_", 1)))
	_check(duplicate.get("ok") == false and _state(session, screen) == spent
		and corridor.hand_buttons["steady"].disabled and session.is_consistent(),
		"spent Wren hand rejects replay without HP/fray/actions/resources/journal/RNG drift")
	# Attempt an off-rank hit while a real part is armed, before its legitimate attack.
	var probed := _off_rank_refusal(corridor, session)
	_check(probed, "a mounted part offered a forbidden target rank for refusal testing")
	var before_part := _state(session, screen)
	var attacked := _legal_part(corridor, session, true) if probed else false
	_check(attacked and session.snapshot() != before_part.snapshot, "legal part resolves live combat, not a preview")
	if not attacked:
		_finish(app)
		return
	await process_frame
	# Complete only as many real mounted actions as needed for a foe to respond.
	var turns := 0
	while _foe_receipts_since(session, start_journal) == 0 and not battle.is_over() and turns < 8:
		turns += 1
		if not _legal_part(corridor, session):
			if not _press(corridor.more_button, "More for Wait"):
				break
			if not _press(corridor.more_buttons["pass"], "mounted Wait for foe turn"):
				break
		await process_frame
	_check(_foe_receipts_since(session, start_journal) > 0 and battle.current_side() == "hero"
		and not battle.is_over() and session.is_consistent(), "real foe response resolved after player actions")
	if battle.is_over() or battle.current_side() != "hero" or _foe_receipts_since(session, start_journal) == 0:
		_finish(app)
		return
	# Save only through the live corridor control, then compare the next mounted command across instances.
	_press(corridor.more_button, "corridor More for Save")
	_check(corridor.more_panel.visible, "Save is on the mounted More panel")
	_press(corridor.more_buttons["save"], "corridor Save run")
	var saved := _state(session, screen)
	var document := StitchedRunSave.read_file(SAVE_PATH)
	_check(FileAccess.file_exists(SAVE_PATH) and document != null
		and document.snapshot() == saved.snapshot and document.journal == saved.journal
		and document.rng.state == saved.run_rng, "post-action save captures full battle, journal and RNG")
	var prior_count := session.journal.size()
	if not corridor.more_panel.visible:
		_press(corridor.more_button, "uninterrupted More for next Wait")
	_press(corridor.more_buttons["pass"], "uninterrupted next legal Wait")
	await process_frame
	var expected := session.snapshot()
	var expected_journal := session.journal.slice(prior_count).duplicate(true)
	var expected_receipts := screen.receipts.slice(saved.ui_receipts.size()).duplicate(true)
	_check(not expected_journal.is_empty() and expected_journal[0].get("method") == "pass_turn"
		and session.is_consistent(), "uninterrupted next legal action and its aftermath are journaled")
	app.free()
	await process_frame
	var fresh := _app(999)
	await process_frame
	await process_frame
	_check(fresh.title_view.visible and fresh.stitched_run_session == null,
		"fresh independent application starts at title")
	_press(fresh.stitched_continue_button, "fresh title Continue")
	await process_frame
	var restored: StitchedRunSession = fresh.stitched_run_session
	var restored_corridor := _fight(fresh, restored, "fresh Continue")
	if restored == null or restored_corridor == null:
		_finish(fresh)
		return
	_check(restored != session and restored.snapshot() == saved.snapshot and restored.journal == saved.journal
		and restored.rng.state == saved.run_rng and restored.battle.state_snapshot() == saved.battle
		and not restored.battle.hand_action_open(),
		"Continue restores the exact run, battle, journal, RNG and prior hand budget")
	var restored_screen: StitchedBattleScreen = restored_corridor.engine
	var before_restored_count := restored.journal.size()
	_press(restored_corridor.more_button, "resumed More for next Wait")
	_press(restored_corridor.more_buttons["pass"], "resumed next legal Wait")
	await process_frame
	_check(restored.snapshot() == expected and restored.rng.state == expected.rng
		and restored.journal.slice(before_restored_count) == expected_journal
		and restored_screen.receipts == expected_receipts and restored.is_consistent(),
		"resumed next mounted action exactly matches uninterrupted combat, foe turns and RNG")
	_finish(fresh)
func _finish(app: Node) -> void:
	if is_instance_valid(app):
		app.free()
	DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.remove_absolute(SAVE_PATH + ".tmp")
	for failure in failures:
		printerr(failure)
	print("stitched_s8s9_live_combat_continue_test: %s (%d checks, %d failures)" %
		["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
