extends "res://tests/live_campfire_stop_test.gd"
## Real settled-Fight book inputs enter the existing one-action Campfire.


func _late_fixture() -> Dictionary:
	for value in range(1, 12000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		var opening := rng.state
		for fight in map.get_legal_choices():
			if map.get_node(fight).type != "Fight":
				continue
			for id in map.get_node(fight).outgoing:
				if map.get_node(id).type != "Rest":
					continue
				for next in map.get_node(id).outgoing:
					if map.get_node(next).type != "Fight":
						continue
					rng.state = opening
					map.choose_node(fight)
					var battle := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
					map.undo_choice(fight, [])
					if battle.get("encounter_id") == "starter_attacks":
						return {"seed": value, "fight": fight, "id": id, "next": next}
	return {}


func _late_boot() -> bool:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	if not await _routed_win(fixture, true, true):
		return false
	await _click(app.reward_buttons[3])
	_check(app.fight_reward_claimed and app.party_carryover.read_state().completed_fights == [fixture.fight],
		"authentic settled Fight and claimed reward precede later Rest")
	await _click(app.continue_button)
	await _frames()
	return true


func _late_scenario(heal: bool, keyboard: bool) -> Array:
	if not await _late_boot():
		app.free()
		return []
	var button := _button(fixture.id)
	_check(button != null and button.pressed.get_connections().size() == 1,
		"genuine connected Rest control has its production callback")
	if button == null:
		app.free()
		return []
	var map: RunMap = app.run_map
	var prior: Array[String] = map.get_route()
	var original: Dictionary = app._sewing_context()
	_check(button.get_meta("route_kind") == "Rest" and button.get_meta("sewing_source") == original
		and button.tooltip_text == "Campfire: Heal each hero 30% max HP (torn revives at 1 HP first), or Leave unchanged for free.",
		"later Rest retains source identity and advertises the exact free Heal/Leave choices")
	var admit: Callable = button.pressed.get_connections()[0].callable
	var fake := Button.new()
	app.route_view.add_child(fake)
	for key in ["route_id", "route_kind", "v3_kind", "sewing_source"]:
		fake.set_meta(key, button.get_meta(key))
	_check(not app._dispatch_route(fixture.id, weakref(map), prior, fake), "copied authentic metadata cannot authorize forged control")
	fake.free()
	var foreign := RunMap.new()
	_check(not app._dispatch_route(fixture.id, weakref(foreign), prior, button), "foreign map refuses genuine control")
	app.run_scraps += 1
	_check(not admit.call(), "stale source wallet refuses admission")
	app.run_scraps -= 1
	map._generation_revision += 1
	_check(not admit.call(), "regenerated source refuses admission")
	map._generation_revision -= 1
	var edges: Array = map._nodes[fixture.fight].outgoing.duplicate()
	map._nodes[fixture.fight].outgoing.erase(fixture.id)
	_check(not admit.call(), "removed legal edge refuses admission")
	map._nodes[fixture.fight].outgoing = edges
	_check(app._sewing_context() == original and app.campfire_visit == null, "rejected admissions preserve exact authorities and RNG")
	if keyboard:
		button.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(button)
	await _frames()
	_check(app.campfire_view is LiveCampfirePanel and app.campfire_view.is_visible_in_tree()
		and app.run_map.get_route() == prior + [fixture.id] and not is_instance_valid(app.rest_view),
		"physical book input mounts real sewn panel and advances exactly once")
	if not is_instance_valid(app.campfire_view):
		app.free()
		return []
	var actions: Array = []
	for child in app.campfire_view.get_children():
		if child is Button:
			actions.append(child.text)
	_check(actions == ["Heal", "Leave"], "later Rest mounts only Heal and Leave")
	var admitted: Dictionary = app._sewing_context()
	for key in original:
		if key != "route":
			_check(admitted[key] == original[key], "book admission preserves exact " + key)
	_check(not admit.call() and app._sewing_context() == admitted, "accepted book callback replay is inert")
	_check(not app._can_choose_connected_route() and not app._campfire_visits.has(fixture.id), "open Rest cannot continue without completion witness")
	await _camp_negatives()
	var before: Dictionary = app._sewing_context()
	_check(before.heroes.size() == 3 and before.heroes.any(func(hero): return hero.hp == 0)
		and before.heroes.any(func(hero): return hero.hp > 0 and hero.hp < hero.max_hp),
		"settled Fight supplies genuine Torn revival and damaged living heal cases")
	var expected: Array = before.heroes.duplicate(true)
	if heal:
		for hero in expected:
			hero.hp = mini(hero.max_hp, maxi(1, hero.hp) + int(floor(hero.max_hp * 0.3)))
	var action: Button = app.campfire_heal_button if heal else app.campfire_leave_button
	var retired: Callable = app.campfire_view._connections[action]
	if keyboard:
		action.grab_focus()
		await _key(KEY_SPACE)
	else:
		await _click(action)
	await _frames()
	_check(app._campfire_closed and not app.campfire_view.visible and app._can_choose_connected_route(), "physical Heal/Leave closes once and permits onward play")
	_check(app.campfire_visit.read_state() == {"ok": true, "node_id": fixture.id,
		"status": RunCampfireVisit.HEALED if heal else RunCampfireVisit.LEFT, "heroes": expected}, "exact one-use receipt")
	var after: Dictionary = app._sewing_context()
	var ledger: Dictionary = before.ledger.duplicate(true)
	var torn: Dictionary = before.torn.duplicate(true)
	if heal:
		ledger.heroes = expected
		ledger.completed_rests.append(fixture.id)
		torn.heroes = expected
		torn.completed_rests.append(fixture.id)
	_check(after.ledger == ledger and after.torn == torn and app.run_heroes == expected, "both full ledgers match independent exact Heal/Leave oracle")
	for key in before:
		if key not in ["heroes", "ledger", "torn"]:
			_check(after[key] == before[key], "decision preserves exact " + key)
	_refuse(retired, "replayed action")
	var witness: Array = app._campfire_visits[fixture.id]
	app._campfire_visits.erase(fixture.id)
	_check(not app._can_choose_connected_route(), "absent witness cannot fall back to legacy authority")
	app._campfire_visits[fixture.id] = witness.slice(0, 3) + [[]]
	_check(not app._can_choose_connected_route(), "wrong prefix witness rejects continuation")
	app._campfire_visits[fixture.id] = witness
	var onward := _button(fixture.next)
	_check(onward != null and not onward.disabled, "real onward Fight control exists")
	if onward != null:
		var callback: Callable = onward.pressed.get_connections()[0].callable
		await _click(onward)
		await _frames()
		_check(app.deck != null and map.get_route() == prior + [fixture.id, fixture.next], "real onward button enters exactly one Fight")
		var state: Dictionary = app._sewing_context()
		callback.call()
		_check(app._sewing_context() == state, "replayed onward control is inert")
	_refuse(retired, "old decision after onward battle")
	var replay: Array = [map.get_route(), app.run_heroes.duplicate(true), app.party_carryover.read_state(), app.run_rng.state, app.deck.hand.duplicate()]
	app._return_to_title()
	_check(app._campfire_visits.is_empty() and app.campfire_visit == null
		and app.campfire_view == null and app.run_map == null, "title clears Campfire session and witnesses")
	var title: Dictionary = app._sewing_context()
	admit.call()
	retired.call()
	_check(app._sewing_context() == title and app.title_view.visible, "post-title book and action callbacks are inert")
	app.free()
	await _frames()
	return replay


func _unfought_late_rest(legacy: bool = false) -> void:
	var found := {}
	for value in range(1, 1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for opening in map.get_legal_choices():
			if map.get_node(opening).type != "Campfire":
				continue
			for id in map.get_node(opening).outgoing:
				if map.get_node(id).type == "Rest":
					for next in map.get_node(id).outgoing:
						if map.get_node(next).type == "Campfire":
							found = {"seed": value, "opening": opening, "id": id, "next": next}
		if not found.is_empty():
			break
	_check(not found.is_empty(), "bounded genuine unfought Campfire -> later Rest prefix exists")
	if found.is_empty():
		return
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = found.seed
	await _click(app.start_button)
	var opening := _button(found.opening)
	_check(opening != null, "unfought opening control exists")
	if opening == null:
		app.free()
		return
	await _click(opening)
	await _click(app.campfire_leave_button)
	var button := _button(found.id)
	_check(button != null and app._unfought_run(), "completed opening provides legal unfought later Rest control")
	if button == null:
		app.free()
		return
	if legacy:
		_check(app._choose_rest_route(found.id, weakref(app.run_map), app.run_map.get_route(), button),
			"explicit retained legacy entry accepts the authentic control")
		_check(not app._unfought_run(), "uncompleted legacy Rest cannot authorize prefix")
		await _click(app.rest_upgrade_button)
		_check(app._current_completed_rest() and app.party_carryover.read_state().completed_rests.is_empty(),
			"genuine legacy Upgrade completes without a Heal ledger receipt")
		await _click(app.rest_continue_button)
		var next := _button(found.next)
		_check(next != null and app._unfought_run(), "completed legacy Upgrade permits onward control")
		if next != null:
			await _click(next)
			await _click(app.campfire_leave_button)
			_check(app._unfought_run() and app._can_choose_connected_route(), "historical legacy Upgrade remains valid after another completed node")
			var saved: Array = app._legacy_rest_visits[found.id]
			app._legacy_rest_visits.erase(found.id)
			_check(not app._unfought_run(), "historical legacy Rest still requires authenticated completion")
			app._legacy_rest_visits[found.id] = saved
		app._return_to_title()
		_check(app._legacy_rest_visits.is_empty(), "title clears historical legacy witnesses")
		app.free()
		await _frames()
		return
	await _click(button)
	_check(app.campfire_visit != null and app.run_map.get_current_node_id() == found.id, "unfought book enters later Rest Campfire")
	_check(not app._unfought_run() and not app._can_choose_connected_route(), "uncompleted later Rest rejects unfought continuation")
	await _click(app.campfire_leave_button)
	_check(app._unfought_run() and app._can_choose_connected_route(), "authenticated later Rest Leave supports unfought continuation")
	var witness: Array = app._campfire_visits[found.id]
	app._campfire_visits.erase(found.id)
	_check(not app._unfought_run() and not app._can_choose_connected_route(), "missing later Rest completion cannot authorize unfought prefix")
	app._campfire_visits[found.id] = witness
	_check(app._unfought_run(), "restored authentic prefix witness validates")
	app.free()
	await _frames()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	fixture = _late_fixture()
	_check(not fixture.is_empty(), "bounded generated post-Fight Rest with onward Fight exists")
	if not fixture.is_empty():
		for heal in [false, true]:
			var first := await _late_scenario(heal, false)
			var second := await _late_scenario(heal, true)
			_check(not first.is_empty() and first == second, "same seed mouse/keyboard receipt and onward RNG replay exactly")
	await _unfought_late_rest()
	await _unfought_late_rest(true)
	for failure in failures:
		printerr(failure)
	print("live_late_rest_campfire_admission_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
