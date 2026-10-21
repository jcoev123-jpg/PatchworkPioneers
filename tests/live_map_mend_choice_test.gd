extends "res://tests/live_routed_battle_reentry_test.gd"


func _activate(control: Control, keyboard: bool) -> void:
	_check(is_instance_valid(control), "required input control exists")
	if not is_instance_valid(control):
		return
	if keyboard:
		control.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(control)


func _mend_fixture() -> Dictionary:
	for value in range(1, 3000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for first in map.get_legal_choices():
			if map.get_node(first).type != "Fight":
				continue
			for elite in map.get_node(first).outgoing:
				if map.get_node(elite).type != "Elite":
					continue
				for fight in map.get_node(elite).outgoing:
					if map.get_node(fight).type != "Fight":
						continue
					for last in map.get_node(fight).outgoing:
						if map.get_node(last).type == "Fight":
							return {"seed": value, "path": [first, elite, fight, last]}
	return {}


func _mend_state() -> Array:
	var carry: RunTornCarryover = app.party_carryover
	return [app._map_mend_context(), carry._receipts.duplicate(true),
		carry._max_hp_by_id.duplicate(true), app.route_view, app.route_buttons.duplicate(),
		app.map_mend_buttons.duplicate(), app._mended_route_context.duplicate(true)]


func _reject_mend(callback: Callable, label: String) -> void:
	var before := _mend_state()
	callback.call()
	_check(_mend_state() == before, label + " preserves all state and receipts")


func _mend_button(id: String) -> Button:
	for button in app.map_mend_buttons:
		if button.get_meta("hero_id", "") == id:
			return button
	_check(false, "required torn hero button exists: " + id)
	return null


func _win_mend() -> void:
	for enemy in app.enemies.get_enemies():
		_check(app.enemies.apply_damage(enemy.position, 9999), "real mounted enemy defeated")
	app._observe_battle_result()
	await _frames()
	_check(app._battle_closed and not app.reward_buttons.is_empty(), "mounted reward exists")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _mend_fixture()
	_check(not fixture.is_empty(), "generated Fight Elite Fight Fight route exists")
	var replay: Array = []
	var retained: Array[Callable] = []
	seed(100100)
	var next_global := randi()
	seed(100100)
	if not fixture.is_empty():
		for session in range(2):
			var keyboard := session == 1
			app.run_seed = fixture.seed
			await _activate(app.route_button, keyboard)
			await _activate(_route_action(fixture.path[0]), keyboard)
			_check(app.party_carryover is RunTornCarryover and app.party != null, "real routed combat admitted")
			app.party._heroes[2].statuses = {"weak": 2, "bleed": 1}
			_check(app.party.apply_damage(3, 9999), "opening Fight tears Tinker")
			await _win_mend()
			await _activate(app.reward_buttons[0], keyboard)
			await _activate(app.continue_button, keyboard)
			_check(app.run_scraps == 1 and _mend_button("tinker").disabled, "one earned scrap disables mend without blocking routes")
			var poor: Callable = _mend_button("tinker").pressed.get_connections()[0].callable
			_reject_mend(poor, "insufficient scraps")
			await _activate(_route_action(fixture.path[1]), keyboard)
			_reject_mend(poor, "non-map stale callback")
			await _win_mend()
			var carry: RunTornCarryover = app.party_carryover
			var before_claim := _mend_state()
			app._choose_map_mend("tinker", 3, weakref(app.reward_buttons[0]), weakref(app.battle_view), app._map_mend_context())
			_check(_mend_state() == before_claim, "unclaimed reward cannot mend")
			await _activate(app.reward_buttons[3], keyboard)
			var sewing = app.get_node("LiveElitePatchSewing")
			_check(sewing.wardrobe != null and sewing.hero_buttons.size() == 3, "earned Elite patch exposes actual sewing controls")
			if sewing.wardrobe == null or sewing.hero_buttons.size() != 3:
				break
			await _activate(sewing.hero_buttons[0], keyboard)
			var patch: String = app.fight_reward_trinket
			_check(carry._wardrobe == sewing.wardrobe, "real sewing binds wardrobe")
			await _activate(app.continue_button, keyboard)
			for callback in retained:
				_reject_mend(callback, "previous session callback")
			var button := _mend_button("tinker")
			_check(not button.disabled and app.run_scraps == 3, "claimed Fight and Elite scraps enable mend")
			var callback: Callable = button.pressed.get_connections()[0].callable
			button.disabled = true
			_reject_mend(callback, "disabled")
			button.disabled = false
			button.hide()
			_reject_mend(callback, "hidden")
			button.show()
			var context: Array = app._map_mend_context()
			for pair in [["foreign", 3], ["warden", 1], ["tinker", 1], ["tinker", 3.0]]:
				_reject_mend(app._choose_map_mend.bind(pair[0], pair[1], weakref(button), weakref(app.route_view), context), "bad hero or slot")
			_reject_mend(app._choose_map_mend.bind("tinker", 3, weakref(app.route_back_button), weakref(app.route_view), context), "foreign control")
			_reject_mend(app._choose_map_mend.bind("tinker", 3, weakref(button), weakref(app.battle_view), context), "foreign chooser")
			_reject_mend(app._choose_map_mend.bind("tinker", 3, weakref(button), weakref(app.route_view), []), "missing snapshot")
			button.set_meta("hero_id", "warden")
			button.set_meta("hero_position", 1)
			_reject_mend(app._choose_map_mend.bind("warden", 1, weakref(button), weakref(app.route_view), context), "otherwise admitted living target")
			button.set_meta("hero_id", "tinker")
			button.set_meta("hero_position", 3)
			for field in ["run_scraps", "session_gold"]:
				app.set(field, app.get(field) + 1)
				_reject_mend(callback, "stale " + field)
				app.set(field, app.get(field) - 1)
			app.run_heroes[2].statuses.weak += 1
			_reject_mend(callback, "roster drift")
			app.run_heroes[2].statuses.weak -= 1
			app.run_map._generation_revision += 1
			_reject_mend(callback, "revision drift")
			app.run_map._generation_revision -= 1
			var route_end: String = app.run_map._route.pop_back()
			_reject_mend(callback, "route drift")
			app.run_map._route.append(route_end)
			app.run_map._nodes[fixture.path[1]].outgoing.append("foreign")
			_reject_mend(callback, "graph drift")
			app.run_map._nodes[fixture.path[1]].outgoing.erase("foreign")
			var wardrobe: RunPatchWardrobe = carry._wardrobe
			wardrobe._gold += 1
			_reject_mend(callback, "wardrobe drift is not repaired")
			wardrobe._gold -= 1
			var expected: Array = app.run_heroes.duplicate(true)
			expected[2].hp = 5
			var conserved: Array = [app.session_gold, app.run_deck.duplicate(), app.run_map.get_route(), app.run_rng.state]
			_bounds(app.route_view)
			if keyboard:
				app.route_buttons.back().grab_focus()
				await _key(KEY_TAB)
				_check(button.has_focus(), "physical Tab reaches mend after routes")
				await _key(KEY_SPACE)
			else:
				await _click(button)
			_check(app.run_heroes == expected and app.run_scraps == 1 and wardrobe.get_snapshot().scraps == 1,
				"exact quarter HP and two scraps committed together")
			_check([app.session_gold, app.run_deck, app.run_map.get_route(), app.run_rng.state] == conserved,
				"mend conserves gold deck route RNG")
			_reject_mend(callback, "replay after remount")
			retained.append(callback)
			_check(app._can_choose_connected_route() and app.route_buttons.size() == app.run_map.get_legal_choices().size(), "routes remain usable without duplicate controls")
			_check(app.map_mend_buttons.size() == 1 and app.map_mend_buttons[0].disabled
				and app.map_mend_buttons[0].text.contains("no torn heroes"), "no target action stays visibly disabled")
			await _activate(_route_action(fixture.path[2]), keyboard)
			_check(app.party.get_hero(3).hp == 5 and app.party.get_hero(3).statuses == expected[2].statuses, "next routed Fight hydrates mended HP and statuses")
			# Tear the genuine wearer, then recover its patch through the same map UI.
			var moved := CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
			_check(moved.ok, "real battle movement changes wearer position")
			app.party._heroes.assign(moved.heroes)
			_check(app.party.apply_damage(2, 9999) and app.party.apply_damage(1, 9999), "next real Fight tears moved wearer and another hero")
			await _win_mend()
			await _activate(app.reward_buttons[3], keyboard)
			await _activate(app.continue_button, keyboard)
			_check(wardrobe.project_active(carry.torn.read_state()).active.warden == [], "torn wearer patch suspended")
			var worn_before: Dictionary = wardrobe.get_snapshot().worn
			_check(_mend_button("warden").get_meta("hero_position") == 2 and app.map_mend_buttons.size() == 2,
				"chooser uses actual moved ID and slot with multiple torn targets")
			_bounds(app.route_view)
			await _activate(_mend_button("warden"), keyboard)
			_check(app.run_heroes[1].hp == 9 and app.run_heroes[0].hp == 0 and app.run_scraps == 0 and wardrobe.get_snapshot().worn == worn_before
				and wardrobe.project_active(carry.torn.read_state()).active.warden == [patch], "wearer-only patch recovers with floor 37/4 HP")
			_check(_mend_button("seamstress").disabled, "remaining torn target is unaffordable after one spend")
			await _activate(_route_action(fixture.path[3]), keyboard)
			_check(app.party.get_hero(2).id == "warden" and app.party.get_hero(2).hp == 9
				and app.party.get_hero(3).hp == 5 and app.party.get_hero(1).hp == 0, "second next Fight carries both paid mends and leaves unselected hero torn")
			var observed: Array = [app.party.get_heroes(), carry.read_state(), carry.torn.read_state(), carry._receipts.duplicate(true), wardrobe.get_snapshot(), app.run_rng.state]
			if session == 0:
				replay = observed
			else:
				_check(observed == replay, "mouse and physical keyboard replay exactly")
			await _activate(app.return_button, keyboard)
	_check(randi() == next_global, "same global RNG stream unchanged")
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_map_mend_choice_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
