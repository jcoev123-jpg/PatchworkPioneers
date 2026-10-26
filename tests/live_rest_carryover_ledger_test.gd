extends "res://tests/live_rest_route_entry_test.gd"
## Mounted route/card inputs exercise the persistent Rest transaction boundary.


func _ledger_state() -> Array:
	return [_persistent(), app.party_carryover.read_state() if app.party_carryover != null else {},
		app.run_removal_count, app.rest_recovery.is_consumed(),
		app._rest_committed_heroes.duplicate(true), app.rest_heal_button.disabled,
		app.rest_continue_button.disabled]


func _reject(callback: Callable, message: String) -> void:
	var before := _ledger_state()
	callback.call()
	_check(_ledger_state() == before, message + ": both transactions, controls and run unchanged")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _fixture()
	_check(not fixture.is_empty(), "real seeded Fight connects to Rest")
	if fixture.is_empty():
		await _finish_ledger()
		return
	var stale: Array[Callable] = []
	var replay: Array = []
	for session in range(3):
		seed(640064)
		var global_next := randi()
		seed(640064)
		if not await _routed_win(fixture, true, true):
			break
		await _click(app.reward_buttons[3])
		await _click(app.continue_button)
		var rest: Button
		for action in app.route_buttons:
			if not action.disabled and app.run_map.get_node(action.get_meta("route_id")).type == "Rest":
				rest = action
		_check(rest != null, "mounted connected Rest control exists")
		if rest == null:
			break
		await _click(_legacy_rest_control(rest))
		_check(app.rest_recovery != null and is_instance_valid(app.rest_continue_button), "real Rest visitor and Continue mounted")
		if app.rest_recovery == null or not is_instance_valid(app.rest_continue_button):
			break
		var visit: RunRestRecovery = app.rest_recovery
		var ledger: RunPartyCarryover = app.party_carryover
		var source: Array = app.run_heroes.duplicate(true)
		var rest_id: String = app.run_map.get_current_node_id()
		var initial: Dictionary = ledger.read_state()
		_check(initial.ok and initial.heroes == source and initial.completed_rests.is_empty()
			and initial.completed_fights == [fixture.fight], "witnessed fight ledger is exact before Heal")
		_check(source[2].hp == 0 and source[1].hp == source[1].max_hp
			and source[1].statuses == {"exposed": 2},
			"nonvacuous downed Tinker, capped survivor and persistent status fixtures")
		var expected_heroes := source.duplicate(true)
		for hero in expected_heroes:
			hero.hp = mini(hero.max_hp, maxi(1, hero.hp) + int(floor(hero.max_hp * 0.3)))
			_check(hero.block == 0, "transit source has zero Block")
		if "--inject-wrong-hp" in OS.get_cmdline_user_args():
			expected_heroes[0].hp = -1
		var heal: Callable = app.rest_heal_button.pressed.get_connections()[0].callable
		var next: Callable = app.rest_continue_button.pressed.get_connections()[0].callable
		_reject(next, "Continue before Heal")
		_reject(app._heal_at_rest.bind(null, app.rest_heal_button), "missing visit")
		_reject(app._heal_at_rest.bind(visit, app.rest_continue_button), "wrong mounted control")
		visit._consumed = true
		_reject(heal, "already consumed visitor with unused ledger")
		visit._consumed = false
		for callback in stale:
			_reject(callback, "previous session callback")
		var map: RunMap = app.run_map
		var replacement := RunMap.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = fixture.seed
		replacement.generate(rng)
		_check(replacement.choose_node(fixture.fight) and replacement.choose_node(rest_id), "replacement map has identical valid route")
		app.run_map = replacement
		_reject(heal, "wrong map identity")
		app.run_map = map
		map._route.append("stale")
		_reject(heal, "changed route")
		map._route.pop_back()
		map._nodes[rest_id].type = "Shop"
		_reject(heal, "wrong node type")
		map._nodes[rest_id].type = "Rest"
		var prior: Array[String] = app._rest_route.duplicate()
		app._rest_route.clear()
		app._rest_route.append(fixture.fight)
		_reject(heal, "wrong bound Rest ID")
		app._rest_route = prior
		app.run_heroes[0].hp -= 1
		_reject(heal, "changed valid source heroes")
		app.run_heroes = source.duplicate(true)
		app.party_carryover = null
		_reject(heal, "missing ledger cannot use old snapshot")
		app.party_carryover = RunPartyCarryover.new([])
		_reject(heal, "invalid ledger")
		app.party_carryover = ledger
		ledger._heroes[0].hp -= 1
		_reject(heal, "ledger heroes mismatch")
		ledger._heroes = source.duplicate(true)
		ledger._rest_ids.append(rest_id)
		_reject(heal, "already used ledger Rest ID")
		ledger._rest_ids.clear()
		visit._valid = false
		_reject(heal, "invalid bound visit")
		visit._valid = true
		visit._roster[0].hp -= 1
		_reject(heal, "changed visitor source")
		visit._roster = source.duplicate(true)
		app._heal_at_rest(RunRestRecovery.new(source), app.rest_heal_button)
		_check(not visit.is_consumed() and ledger.read_state() == initial, "different valid visitor rejects")
		var conserved := _persistent().slice(1)
		var removals: int = app.run_removal_count
		if session == 0:
			await _click(app.rest_heal_button)
		else:
			app.rest_heal_button.grab_focus()
			await _key(KEY_SPACE if session == 1 else KEY_ENTER)
		var healed := ledger.read_state()
		_check(visit.is_consumed() and app.rest_heal_button.disabled and not app.rest_continue_button.disabled,
			"physical Heal consumes visitor and enables Continue once")
		_check(healed.ok and healed.heroes == expected_heroes and app.run_heroes == expected_heroes
			and app._rest_committed_heroes == expected_heroes and healed.completed_rests == [rest_id]
			and healed.completed_fights == initial.completed_fights, "exact manual recovery and current Rest committed to ledger")
		_check(_persistent().slice(1) == conserved and app.run_removal_count == removals,
			"Heal conserves complete combat, inventory, gold, RNG, route and removals")
		var after := _ledger_state()
		await _click(app.rest_heal_button)
		app.rest_heal_button.grab_focus()
		await _key(KEY_ENTER)
		app.rest_heal_button.pressed.emit()
		heal.call()
		_check(_ledger_state() == after, "disabled physical mouse/keyboard and duplicate callbacks cannot heal twice")
		if session == 0:
			await _click(app.rest_continue_button)
		else:
			app.rest_back_button.grab_focus()
			await _key(KEY_TAB)
			_check(app.rest_continue_button.has_focus(), "Tab reaches enabled Rest Continue")
			await _key(KEY_ENTER)
		_check(is_instance_valid(app.route_view) and app.route_view.visible and not app.rest_view.visible,
			"Rest Continue opens real connected route")
		var hydrated := ledger.create_next_fight_party()
		_check(hydrated != null and hydrated.is_valid(), "witnessed healed ledger creates next fight party")
		if hydrated != null:
			_check(hydrated.get_heroes() == expected_heroes, "next fight inherits recovered HP, revival, positions and statuses")
			hydrated.apply_damage(1, 1)
			_check(ledger.read_state() == healed and app.run_heroes == expected_heroes, "next fight is detached from persistent heroes")
		_reject(heal, "hidden Rest Heal")
		_reject(next, "duplicate Continue")
		var replay_state := [_persistent(), healed, app.run_removal_count]
		if session == 0:
			replay = replay_state.duplicate(true)
		else:
			_check(replay_state == replay, "same seed replays complete healed ledger and run")
		stale = [heal, next]
		await _click(app.route_back_button)
		_check(app.party_carryover == null and app.run_heroes.is_empty() and app.rest_recovery == null,
			"Return clears ledger and visit")
		for callback in stale:
			callback.call()
		_check(app.party_carryover == null and app.run_map == null, "post-Return callbacks cannot revive session")
		_check(randi() == global_next, "all Rest paths preserve global RNG")
	_check(app._start_battle(), "explicit standalone M01 fixture starts")
	await _frames()
	_check(app.deck != null and app.party_carryover == null and app.run_map == null and app.run_heroes.is_empty(),
		"standalone M01 fixture resets independently of Rest ledger")
	for callback in stale:
		callback.call()
	_check(app.party_carryover == null and app.run_map == null, "old Rest inputs preserve standalone M01 fixture")
	await _click(app.return_button)
	await _finish_ledger()


func _finish_ledger() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_rest_carryover_ledger_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
