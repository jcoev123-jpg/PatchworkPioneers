extends "res://tests/live_sewing_circle_stop_test.gd"

func _camp_state() -> Array:
	return [app._sewing_context(), app.act_outcome.get_state(),
		app.campfire_visit.read_state(), app._campfire_closed, app._campfire_visits.duplicate(true)]


func _refuse(callback: Callable, reason: String) -> void:
	var before := _camp_state()
	callback.call()
	_check(_camp_state() == before, reason + " preserves all run authorities and RNG")


func _camp_enter(atlas: bool) -> void:
	var prior: Array = app.run_map.get_route()
	var route: Button = _button(fixture.id)
	var kind: String = app.run_map.get_node(fixture.id).type
	_check(route != null and not route.disabled and route.text == "Campfire"
		and route.get_meta("route_kind") == kind, "genuine legal themed Campfire or source Rest button")
	var before: Dictionary = app._sewing_context()
	var callback: Callable = route.pressed.get_connections()[0].callable
	var fake := Button.new()
	app.route_view.add_child(fake)
	fake.set_meta("route_id", fixture.id)
	fake.set_meta("route_kind", "Campfire")
	fake.set_meta("sewing_source", before)
	_check(not app._choose_campfire_route(fixture.id, weakref(app.run_map), app.run_map.get_route(), fake)
		and app._sewing_context() == before, "forged route control cannot consume a node or RNG")
	fake.free()
	app.run_scraps += 1
	callback.call()
	_check(app.run_map.get_route() == prior and app.campfire_visit == null, "stale route wallet refuses admission")
	app.run_scraps -= 1
	if atlas:
		await _click(app.route_map_button)
		var atlas_callback: Callable = app.route_atlas.node_requested.get_connections()[0].callable
		var saved_overlay = app.route_atlas_overlay
		app.run_scraps += 1
		atlas_callback.call(fixture.id)
		_check(app.route_atlas_overlay == saved_overlay and app.campfire_visit == null
			and app.run_map.get_route() == prior, "stale atlas source refuses before clearing overlay")
		app.run_scraps -= 1
		route.set_meta("route_kind", "foreign")
		atlas_callback.call(fixture.id)
		_check(app.route_atlas_overlay == saved_overlay and app.campfire_visit == null
			and app.run_map.get_route() == prior, "forged atlas source kind refuses before clearing overlay")
		route.set_meta("route_kind", kind)
		var marker: Button = app.route_atlas.get_node("Node_" + fixture.id + "/Action")
		_check(marker.tooltip_text.contains("One action: heal each hero 30% max HP (torn revives at 1 HP first), or leave unchanged"), "truthful atlas Help")
		marker.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(route)
	await _frames()
	_check(app.campfire_view != null and app.campfire_view.is_visible_in_tree()
		and app.run_map.get_route() == prior + [fixture.id], "physical input advances exactly once into Campfire")
	_check(app.campfire_visit.read_state().heroes == before.heroes, "visit binds exact canonical heroes")
	var actions: Array = []
	for child in app.campfire_view.get_children():
		if child is Button:
			actions.append(child.text)
	_check(actions == ["1 Heal · 30%", "0 Leave · free"] and not is_instance_valid(app.rest_view)
		and not is_instance_valid(app.shop_view), "only Heal and Leave mounted, Leave shows primary 0")
	var viewport := Rect2(Vector2.ZERO, Vector2(1280, 720))
	_check(viewport.encloses(app.campfire_view.get_global_rect())
		and not app.campfire_view.heal_button.get_global_rect().intersects(app.campfire_view.leave_button.get_global_rect()),
		"compact visit and separate reachable actions fit the viewport")
	_check(app.campfire_view is LiveCampfirePanel and app.campfire_view.position == Vector2(200, 60)
		and app.campfire_view.size == Vector2(880, 600), "real route mounts authored sewn panel")
	_check(app.campfire_heal_button == app.campfire_view.heal_button
		and app.campfire_leave_button == app.campfire_view.leave_button, "existing aliases reference sewn controls")
	_check(app.campfire_view.heal_button.tooltip_text.contains("30% max HP")
		and app.campfire_view.heal_button.tooltip_text.contains("Torn revives at 1 HP first")
		and app.campfire_view.heal_button.tooltip_text.contains("1 →"), "Heal tooltip spells out 1/30%-max/Torn revival")
	_check(app.campfire_view.leave_button.tooltip_text.contains("Leave")
		and app.campfire_view.leave_button.tooltip_text.contains("2 also works"), "Leave tooltip remains truthful")
	for i in range(3):
		var hero: Dictionary = before.heroes[i]
		var forecast := mini(hero.max_hp, maxi(1, hero.hp) + int(floor(hero.max_hp * 0.3)))
		var actor_name := str(hero.get("name", "")).strip_edges()
		if actor_name.is_empty():
			actor_name = str(hero.id).replace("_", " ").capitalize()
		var gain: int = int(forecast) - int(hero.hp)
		var gain_text := "FULL" if gain == 0 else ("(+%d HP)" % gain)
		var note := "  ·  TORN → REVIVED" if hero.hp == 0 else ""
		var caption := "%s    %d → %d / %d HP  ·  %s%s" % [actor_name, hero.hp, forecast, hero.max_hp, gain_text, note]
		_check(app.campfire_view.hero_labels[i].text == caption, "real hero forecast mounted")
	var preview_gain := false
	for hero_entry in before.heroes:
		var forecast_hp: int = mini(hero_entry.max_hp,
			maxi(1, hero_entry.hp) + int(floor(hero_entry.max_hp * 0.3)))
		if forecast_hp > int(hero_entry.hp):
			preview_gain = true
	_check((app.campfire_view.heal_button if preview_gain
			else app.campfire_view.leave_button).has_focus(),
		"live Campfire default focus follows the authentic preview gain")
	app.campfire_view.heal_button.grab_focus()
	await _key(KEY_TAB)
	_check(app.campfire_view.leave_button.has_focus(), "Tab reaches Leave")
	await _key(KEY_TAB)
	_check(app.campfire_view.heal_button.has_focus(), "Tab cycles to Heal")


func _camp_negatives() -> void:
	var callback: Callable = func():
		var current: Callable = app.campfire_view._connections[app.campfire_view.heal_button]
		current.call()
	var original: Dictionary = app._sewing_context()
	app.campfire_view.heal_button.disabled = true
	_refuse(callback, "disabled control")
	app.campfire_view.heal_button.disabled = false
	app.campfire_view.hide()
	_refuse(callback, "hidden visit")
	app.campfire_view.show()
	var rng_identity = app.run_rng
	app.run_rng = RandomNumberGenerator.new()
	app.run_rng.state = rng_identity.state
	_refuse(callback, "foreign RNG identity")
	app.run_rng = rng_identity
	app.run_heroes[0].hp -= 1
	_refuse(callback, "drifted roster")
	app.run_heroes = original.heroes.duplicate(true)
	var carry = app.party_carryover
	app.party_carryover = RunTornCarryover.new(app.run_heroes)
	_refuse(callback, "foreign carry identity")
	app.party_carryover = carry
	var map = app.run_map
	var foreign := RunMap.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = fixture.seed
	foreign.generate(rng)
	app.run_map = foreign
	_refuse(callback, "foreign map identity")
	app.run_map = map
	map._generation_revision += 1
	_refuse(callback, "regenerated map")
	map._generation_revision -= 1
	map._route.append(fixture.next)
	_refuse(callback, "advanced route")
	map._route.pop_back()
	app.run_rng.randi()
	_refuse(callback, "advanced RNG")
	app.run_rng.state = original.rng_state
	app.run_deck.append("forged")
	_refuse(callback, "drifted deck")
	app.run_deck.pop_back()
	var intent := {"action": "heal", "source_visit": app.campfire_visit,
		"node_id": fixture.id, "expected_heroes": original.heroes.duplicate(true)}
	var bound: Dictionary = app.campfire_visit.read_state()
	_refuse(app._campfire_action.bind(intent, app.campfire_view, app.campfire_visit, bound),
		"forged direct control request without panel submission")
	for key in ["action", "source_visit", "node_id", "expected_heroes", "extra"]:
		var forged := intent.duplicate(true)
		match key:
			"action": forged.action = "buy"
			"source_visit": forged.source_visit = RunCampfireVisit.new(fixture.id, original.heroes)
			"node_id": forged.node_id = fixture.next
			"expected_heroes": forged.expected_heroes[0].hp -= 1
			"extra": forged.extra = true
		app.campfire_view._submitted = true
		_refuse(app._campfire_action.bind(forged, app.campfire_view, app.campfire_visit, bound),
			"forged intent " + key)
	var retired: Callable = app.campfire_view._connections[app.campfire_view.heal_button]
	app.campfire_view.bind(app.campfire_visit)
	_refuse(retired, "retired panel callback generation")
	app.campfire_visit._heroes[0].hp -= 1
	_refuse(callback, "forged service roster")
	app.campfire_visit._heroes = original.heroes.duplicate(true)
	app.campfire_view.bind(app.campfire_visit)
	_check(app._sewing_context() == original, "negative fixtures restore exact authority")


func _camp_scenario(connected: bool, heal: bool, keyboard: bool, opening_rest: bool = false) -> Array:
	fixture = _post_fight_fixture() if connected else (_camp_fixture("Rest") if opening_rest else _fixture())
	_check(not fixture.is_empty(), "bounded genuine seeded Campfire chain exists")
	if fixture.is_empty():
		return []
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	if connected:
		if not await _routed_win(fixture, true, true):
			app.free()
			return []
		await _click(app.reward_buttons[3])
		await _click(app.continue_button)
		await _frames()
		_check(app.run_heroes[2].hp == 0 and app.run_heroes[1].hp == app.run_heroes[1].max_hp
			and app.run_heroes[0].hp < app.run_heroes[0].max_hp, "real victory produces torn, capped and wounded witnesses")
	else:
		app.run_seed = fixture.seed
		await _click(LEGACY_ENTRY.start_button(app))
		preload("res://tests/party_choice.gd").choose(app)
		await _frames()
	await _camp_enter(keyboard)
	await _camp_negatives()
	var before: Dictionary = app._sewing_context()
	var zero_gain := true
	for hero_entry in before.heroes:
		var forecast_hp: int = mini(hero_entry.max_hp,
			maxi(1, hero_entry.hp) + int(floor(hero_entry.max_hp * 0.3)))
		if forecast_hp > int(hero_entry.hp):
			zero_gain = false
	if heal and zero_gain:
		# Design v3 V3-3: a fully healed party cannot spend its one-use visit on
		# a zero-gain Heal. The mounted view shows Heal disabled and Leave is the
		# only genuine action, so the scenario completes the stop via Leave.
		_check(app.campfire_view.heal_button.disabled
			and app.campfire_view.heal_button.is_visible_in_tree()
			and not app.campfire_view.leave_button.disabled
			and app.campfire_view.leave_button.has_focus(),
			"fully healed party mounts a disabled Heal and an enabled focused Leave")
		_refuse(app.campfire_view._connections[app.campfire_view.heal_button],
			"zero-gain disabled Heal decision")
		heal = false
	var expected: Array = before.heroes.duplicate(true)
	if heal:
		for hero in expected:
			hero.hp = mini(hero.max_hp, maxi(1, hero.hp) + int(floor(hero.max_hp * 0.3)))
	var button: Button = app.campfire_view.heal_button if heal else app.campfire_view.leave_button
	var callback: Callable = app.campfire_view._connections[button]
	if keyboard:
		button.grab_focus()
		await _key(KEY_1 if heal else KEY_0)
	else:
		await _click(button)
	await _frames()
	_check(app._campfire_closed and not app.campfire_view.visible and app._can_choose_connected_route(), "one action closes visit and allows onward play")
	_check(app.run_heroes == expected and app.party_carryover.read_state().heroes == expected
		and app.party_carryover.torn.read_state().heroes == expected, "exact independent revive/30%-cap receipt committed to both ledgers")
	var after: Dictionary = app._sewing_context()
	_check(app.campfire_visit.read_state() == {"ok": true, "node_id": fixture.id,
		"status": RunCampfireVisit.HEALED if heal else RunCampfireVisit.LEFT, "heroes": expected},
		"exact authenticated service receipt retains the original source node ID")
	for key in ["map", "revision", "floors", "route", "party", "live_heroes", "rng", "rng_state", "rng_seed", "seed", "gold", "scraps", "patches", "removals", "deck", "descriptors", "cursor"]:
		_check(after[key] == before[key], "Campfire retains unrelated " + key)
	if not heal:
		_check(after == before, "Leave retains complete authority without spend or heal")
	else:
		_check(after.ledger.completed_rests == before.ledger.completed_rests + [fixture.id], "exactly one authenticated heal receipt")
		_check(after.torn.completed_rests == before.torn.completed_rests + [fixture.id], "exactly one Torn-ledger heal receipt")
	_refuse(callback, "duplicate action")
	var replay: Array = [app.run_map.get_floors(), app.run_map.get_route(), expected, app.run_rng.state]
	var witness: Array = app._campfire_visits[fixture.id]
	app._campfire_visits.erase(fixture.id)
	_check(not app._can_choose_connected_route(), "missing closure witness rejects onward play")
	if not connected:
		_check(not app._unfought_run(), "unfought prefix independently requires the Campfire witness")
	app._campfire_visits[fixture.id] = witness.slice(0, 3) + [[]]
	_check(not app._can_choose_connected_route(), "wrong prefix closure witness rejects onward play")
	app._campfire_visits[fixture.id] = witness
	var next := _button(fixture.next)
	_check(next != null and not next.disabled, "real connected next Fight exists")
	await _click(next)
	await _frames()
	_check(app.deck != null and app.run_map.get_route().back() == fixture.next, "next real encounter starts")
	_check(app.party.get_heroes().size() == 3, "next combat has complete carried party")
	for i in range(3):
		_check(app.party.get_heroes()[i].hp == expected[i].hp, "next battle retains exact HP for hero " + str(i))
	_refuse(callback, "post-exit old action")
	replay.append(app.deck.hand.duplicate())
	replay.append(app.run_rng.state)
	app._return_to_title()
	await _frames()
	_check(app.campfire_view == null and app.campfire_visit == null
		and app.campfire_heal_button == null and app.campfire_leave_button == null
		and app._campfire_original.is_empty() and app._campfire_visits.is_empty(), "title clears visit witnesses")
	app.free()
	await _frames()
	return replay


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for connected in [false, true]:
		for heal in [false, true]:
			var first := await _camp_scenario(connected, heal, false)
			var second := await _camp_scenario(connected, heal, true)
			_check(not first.is_empty() and first == second, "same seed mouse/keyboard atlas replay exactly")
	for heal in [false, true]:
		var first := await _camp_scenario(false, heal, false, true)
		var second := await _camp_scenario(false, heal, true, true)
		_check(not first.is_empty() and first == second, "opening source Rest exact book/atlas Heal/Leave replay")
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_campfire_stop_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)

func _fixture() -> Dictionary:
	return _camp_fixture("Campfire")


func _camp_fixture(kind: String) -> Dictionary:
	for value in range(1, 1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for id in map.get_legal_choices():
			if map.get_node(id).type != kind:
				continue
			for next in map.get_node(id).outgoing:
				if map.get_node(next).type == "Fight":
					return {"seed": value, "id": id, "next": next}
	return {}


func _post_fight_fixture() -> Dictionary:
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
				if map.get_node(id).type != "Campfire":
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


