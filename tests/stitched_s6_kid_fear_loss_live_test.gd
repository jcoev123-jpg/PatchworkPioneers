extends "res://tests/stitched_s6_full_run_test.gd"
## Mounted S6 loss, carry, replacement and Save/Continue use the sealed fear ledger.

const FEAR_SAVE_PATH := "user://stitched_s6_kid_fear_loss_live.save"


func _fear(session: StitchedRunSession, amount: int, sequence: int, label: String) -> void:
	_check(session.snapshot().kid_fear == {"fear": amount, "shake": amount >= 50,
		"pending_lost_strings": amount >= 100, "sequence": sequence}, label)


func _ledger(app: Node, label: String) -> void:
	await process_frame
	# Owner 11-08: with walks on, the map is a corridor junction with no numeric ledger;
	# Wren's fear lives in the session (checked by _fear) and shows as light, never a number.
	if app.stitched_run_panel is StitchedCorridorJunction:
		_check(app.stitched_run_panel.is_visible_in_tree()
			and app.stitched_run_panel.find_child("RunLedger", true, false) == null,
			label + " mounts the corridor junction with no fear number")
		return
	var ledger: Label = app.stitched_run_panel.find_child("RunLedger", true, false)
	_check(ledger != null and ledger.is_visible_in_tree()
		and ledger.text.ends_with("WREN FEAR %d / 100" % app.stitched_run_session.snapshot().kid_fear.fear),
		label + " mounts the exact canonical Wren fear")
	if ledger != null:
		_check(ledger.get_minimum_size().x <= ledger.get_parent().size.x
			and ledger.get_global_rect().end.x <= 1280, label + " ledger fits the 1280-wide page")


func _route_kind(app: Node, kind: String) -> bool:
	for id in app.stitched_run_session.choices():
		if app.stitched_run_session.map.get_node(id).type == kind:
			return _press_route(app, id)
	_check(false, "connected route contains " + kind)
	return false


func _visit_button(app: Node, id: String, arguments: Array = []) -> Button:
	var actions: Array = app.stitched_run_session.visit_actions()
	for index in actions.size():
		if actions[index].id == id and actions[index].arguments == arguments and actions[index].enabled:
			return app.stitched_run_buttons[index]
	_check(false, "mounted enabled visit action exists: " + id + str(arguments))
	return null


func _replay_future(twin: StitchedRunSession, session: StitchedRunSession, label: String) -> void:
	_check(twin != null, label + " has an authenticated replay session")
	if twin == null:
		return
	# Mounted battle entry/actions can also journal automatic foe turns.
	for command in session.journal.slice(twin.journal.size()):
		_check(StitchedRunSave._replay(twin, command), label + " replays the real command " + str(command))
	_check(twin.snapshot() == session.snapshot() and twin.journal == session.journal,
		label + " agrees on the complete canonical state, journal and RNG")


func _continue_saved(app: Node, label: String) -> Node:
	var session: StitchedRunSession = app.stitched_run_session
	var before := session.snapshot()
	app.stitched_save_path = FEAR_SAVE_PATH
	var saved := false
	for button in app.stitched_run_buttons:
		if button.text == "Save run":
			button.pressed.emit()
			saved = true
			break
	_check(saved and FileAccess.file_exists(FEAR_SAVE_PATH), label + " uses mounted Save")
	app.free()
	await process_frame
	var loaded: Node = load("res://scenes/app.tscn").instantiate()
	loaded.stitched_save_path = FEAR_SAVE_PATH
	root.add_child(loaded)
	await process_frame
	_check(loaded.stitched_continue_button.is_visible_in_tree()
		and loaded.stitched_continue_button.focus_mode == Control.FOCUS_ALL,
		label + " title exposes mouse/keyboard Continue")
	loaded.stitched_continue_button.pressed.emit()
	_check(loaded.stitched_run_session != null and loaded.stitched_run_session != session
		and loaded.stitched_run_session.snapshot() == before
		and loaded.stitched_run_session.journal == session.journal,
		label + " Continue reconstructs the full canonical state, journal and RNG")
	await _ledger(loaded, label + " continued page")
	return loaded


func _direct_head_loss(value: Variant) -> bool:
	if value is Dictionary:
		var door: Variant = value.get("death_door", value.get("attacker_death_door"))
		if door is Dictionary and bool(door.get("lost", false)) \
				and str(door.get("tear", {}).get("slot", "")) == "head":
			return true
		for key in value:
			if _direct_head_loss(value[key]):
				return true
	elif value is Array:
		for item in value:
			if _direct_head_loss(item):
				return true
	return false


func _first_loss(seed_number: int) -> Node:
	var app: Node = await _new_run(seed_number)
	var session: StitchedRunSession = app.stitched_run_session
	if session == null:
		return app
	_fear(session, 0, 0, "fresh run has the complete zero fear state")
	await _ledger(app, "fresh map")
	var detached := session.snapshot()
	detached.kid_fear.fear = 99
	_check(session.is_consistent() and session.snapshot().kid_fear.fear == 0,
		"published fear state is detached from the private service and seal")
	_check(_route_kind(app, "Fight"), "real opening fight mounts for loss")
	var stage: StitchedBattleScreen = app.stitched_run_battle
	if stage == null:
		return app
	var entered := session.snapshot()
	var journal := session.journal.duplicate(true)
	stage._action_buttons["exit"].pressed.emit()
	_check(not session.settle_battle(stage.battle) and session.snapshot() == entered
		and session.journal == journal, "unfinished mounted exit and settlement are fully atomic")
	var hanging_seen := false
	var head_loss_seen := false
	var passes := 0
	for step in range(500):
		if stage.battle.is_over() or stage.battle.get_heroes().any(func(hero: Dictionary): return hero.lost):
			break
		var count := stage.receipts.size()
		stage._action_buttons["pass"].pressed.emit()
		if stage.receipts.size() == count:
			break
		passes += 1
		for receipt in stage.receipts.slice(count):
			head_loss_seen = head_loss_seen or _direct_head_loss(receipt)
		hanging_seen = hanging_seen or stage.battle.get_heroes().any(func(hero: Dictionary): return hero.hanging)
		_fear(session, 0, 0, "hits, fray and Hanging never publish an unrelated fear event")
	var won := _win(stage)
	var lost := stage.battle.get_heroes().filter(func(hero: Dictionary): return hero.lost)
	_check(passes > 0 and (hanging_seen or head_loss_seen) and won.acted > 0 and lost.size() == 1
		and stage.battle.outcome() == "victory", "public Pass and ability controls genuinely lose one doll then win")
	if lost.size() != 1 or stage.battle.outcome() != "victory":
		return app
	_fear(session, 0, 0, "LOST waits for authenticated settlement")
	var completed: StitchedRules = stage.battle
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.state = session.rng.state
	expected_rng.randi_range(RunVictoryGold.NORMAL_MIN, RunVictoryGold.NORMAL_MAX)
	expected_rng.randi_range(0, 1)
	var drawn: Dictionary = StitchedS14Abilities.draw_patch(expected_rng, "fight")
	journal = session.journal.duplicate(true)
	stage._action_buttons["exit"].pressed.emit()
	_fear(session, 15, 1, "one newly LOST identity applies exactly one +15 service event")
	var awarded: Dictionary = session.journal.back().get("ability_patch", {})
	var expected_command := {"action": "settle", "ability_patch": awarded}
	_check(session.is_consistent() and session.rng.state == expected_rng.state
		and not drawn.is_empty() and awarded == session.ability_inventory.back()
		and session.receipts.back().get("reward", {}).get("ability_patch", {}) == awarded
		and awarded.get("id") == drawn.id and awarded.get("rarity") == drawn.rarity
		and session.journal == journal + [expected_command],
		"fear seals with settlement, consumes no extra RNG and awards only its real seeded patch")
	var settled := session.snapshot()
	stage._action_buttons["exit"].pressed.emit()
	_check(not session.settle_battle(completed) and session.snapshot() == settled
		and session.journal == journal + [expected_command], "duplicate exit and stale settlement cannot count twice")
	await _ledger(app, "settled map")
	var twin := StitchedRunSave.restore(StitchedRunSave.capture(session))
	_check(twin != null and twin.snapshot() == settled, "authenticated replay reproduces every ledger and RNG")
	if twin != null:
		twin._kid_fear.apply_observed_event({"kind": "lost"})
		var tampered := twin.snapshot()
		_check(not twin.is_consistent() and twin.choices().is_empty()
			and StitchedRunSave.capture(twin).is_empty()
			and not twin.enter(session.choices()[0], tampered) and twin.snapshot() == tampered,
			"private fear mutation breaks the same seal and blocks capture and route admission")
	return app


func _carried_loss() -> void:
	# Seed 101 re-derives the carried-LOST witness under S14: the opening Fight loses
	# exactly one doll and is won, and its chain reaches a Shop, a Campfire and a real Elite.
	var app: Node = await _first_loss(101)
	var session: StitchedRunSession = app.stitched_run_session
	if session == null or session.phase != "map":
		app.free()
		return
	app = await _continue_saved(app, "one-loss map")
	session = app.stitched_run_session
	var twin := StitchedRunSave.restore(StitchedRunSave.capture(session))
	_check(twin != null, "loaded future has an independent authenticated replay")
	# Apply the very same mounted commands to the replay, checking the entire state after each.
	_check(_route_kind(app, "Shop"), "carried LOST reaches the connected Shop")
	_replay_future(twin, session, "loaded future Shop")
	var leave := _visit_button(app, "leave")
	if leave != null:
		leave.pressed.emit()
	_replay_future(twin, session, "loaded future unrelated visit")
	_check(_route_kind(app, "Campfire"), "carried LOST reaches the connected Campfire")
	_replay_future(twin, session, "loaded future Campfire")
	var mend := _visit_button(app, "mend")
	if mend != null:
		mend.pressed.emit()
	_replay_future(twin, session, "loaded future recovery")
	_check(_route_kind(app, "Elite"), "carried LOST enters a valid next encounter")
	_replay_future(twin, session, "loaded future next encounter including opening foe turns")
	var stage: StitchedBattleScreen = app.stitched_run_battle
	_check(stage != null and stage.battle.get_heroes().filter(func(hero: Dictionary): return hero.lost).size() == 1,
		"the next actual battle contains the previously LOST ID")
	if stage != null:
		for step in range(10):
			if stage.battle.is_over():
				break
			stage._action_buttons["retreat"].pressed.emit()
			_replay_future(twin, session, "loaded future Retreat including foe turns")
		_check(stage.battle.outcome() == "retreated"
			and stage.battle.get_heroes().filter(func(hero: Dictionary): return hero.lost).size() == 1,
			"next completed battle has only the carried LOST doll")
		var old_battle: StitchedRules = stage.battle
		var rng_before := session.rng.state
		stage._action_buttons["exit"].pressed.emit()
		_replay_future(twin, session, "loaded future settlement")
		_fear(session, 15, 1, "carried LOST is never counted again")
		_check(session.rng.state == rng_before and not session.settle_battle(old_battle),
			"carried loss settlement uses no RNG and rejects replay")
		await _ledger(app, "carried-loss map")
	app.free()
	await process_frame


func _replacement_loss() -> void:
	# Seed 911 re-derives the replacement witness under S14: the opening Fight still
	# loses exactly one doll and is won, its connected Shop leads to the connected Sewing
	# Circle and on into a genuine onward Elite.
	var app: Node = await _first_loss(911)
	var session: StitchedRunSession = app.stitched_run_session
	if session == null or session.phase != "map":
		app.free()
		return
	var lost := session.heroes.filter(func(hero: Dictionary): return hero.lost)
	if lost.size() != 1:
		app.free()
		return
	var retired_id: String = lost[0].id
	_check(_route_kind(app, "Shop"), "replacement route reaches Shop")
	var leave := _visit_button(app, "leave")
	if leave != null:
		leave.pressed.emit()
	var circle_id := ""
	for id in session.choices():
		if session.map.get_node(id).type == "SewingCircle":
			circle_id = id
	_check(not circle_id.is_empty() and _press_route(app, circle_id)
		and session.pending.service == "SewingCircle", "loss reaches the real connected Sewing Circle")
	var offers := session.visit_actions().filter(func(action: Dictionary): return action.id == "replace")
	_check(not offers.is_empty(), "genuine LOST identity has lawful replacement offers")
	if offers.is_empty():
		app.free()
		return
	var args: Array = offers[0].arguments
	var before := session.snapshot()
	var replacement := _visit_button(app, "replace", args)
	if replacement != null:
		replacement.pressed.emit()
	_check(not session._party_ids().has(retired_id) and session._party_ids().has(args[0])
		and session.heroes.all(func(hero: Dictionary): return not hero.lost)
		and session.rng.state == before.rng, "lawful replacement installs a separate living identity without a draw")
	_fear(session, 15, 1, "replacement preserves Wren's settled loss history")
	leave = _visit_button(app, "leave")
	if leave != null:
		leave.pressed.emit()
	app = await _continue_saved(app, "replacement map")
	session = app.stitched_run_session
	_check(_route_kind(app, "Elite"), "replacement enters a real onward Elite")
	var stage: StitchedBattleScreen = app.stitched_run_battle
	_check(stage != null and not stage.battle.get_unit(args[0]).is_empty()
		and stage.battle.get_unit(retired_id).is_empty(), "onward fight owns the new identity and excludes the retired doll")
	if stage != null:
		var passes := 0
		for step in range(800):
			if stage.battle.is_over():
				break
			var count := stage.receipts.size()
			stage._action_buttons["pass"].pressed.emit()
			if count == stage.receipts.size():
				break
			passes += 1
		_check(passes > 0 and stage.battle.outcome() == "defeat"
			and stage.battle.get_unit(args[0]).lost
			and stage.battle.get_heroes().all(func(hero: Dictionary): return hero.lost),
			"public turns genuinely lose the replacement as a new ID and all remaining survivors")
		var rng_before := session.rng.state
		stage._action_buttons["exit"].pressed.emit()
		_fear(session, 75, 5, "replacement loss counts independently and each of four newly LOST IDs adds +15 once")
		_check(session.phase == "defeat" and session.rng.state == rng_before,
			"defeat commits deterministic fear without reward draws")
		await _ledger(app, "defeat terminal")
		app = await _continue_saved(app, "defeat terminal")
	app.free()
	await process_frame


func _no_loss(hanging: bool) -> void:
	# The no-loss full route's winning seed is searched at run time (_winning_seed), so
	# appended Events that redraw the seeded rotation no longer break this witness.
	var app: Node = await _new_run(0 if hanging else await _winning_seed())
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and _route_kind(app, "Fight"), "no-loss witness mounts a genuine fight")
	var stage: StitchedBattleScreen = app.stitched_run_battle
	if stage == null:
		app.free()
		return
	if hanging:
		for step in range(500):
			if stage.battle.is_over() or stage.battle.get_heroes().any(func(hero: Dictionary): return hero.hanging):
				break
			stage._action_buttons["pass"].pressed.emit()
		for step in range(10):
			if stage.battle.is_over():
				break
			stage._action_buttons["retreat"].pressed.emit()
		_check(stage.battle.outcome() == "retreated"
			and stage.battle.get_heroes().any(func(hero: Dictionary): return hero.hanging and not hero.lost),
			"public Retreat ends with a non-vacuous Hanging doll")
	else:
		var won := _win(stage)
		_check(won.acted > 0 and stage.battle.outcome() == "victory", "public abilities win the no-loss fight")
	_check(stage.battle.is_over() and stage.battle.get_heroes().all(func(hero: Dictionary): return not hero.lost),
		"no-loss settlement has no LOST ending IDs")
	stage._action_buttons["exit"].pressed.emit()
	_fear(session, 0, 0, "completed no-loss fight produces no fear event, including Hanging and victory")
	await _ledger(app, "no-loss settled map")
	if not hanging:
		_complete_route(app)
		_check(session.phase == "victory", "public full route reaches the victory terminal")
		await _ledger(app, "victory terminal")
		app = await _continue_saved(app, "victory terminal")
	app.free()
	await process_frame


func _run() -> void:
	await _carried_loss()
	await _replacement_loss()
	await _no_loss(true)
	await _no_loss(false)
	DirAccess.remove_absolute(FEAR_SAVE_PATH)
	for message in failures:
		printerr(message)
	print("stitched_s6_kid_fear_loss_live_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
