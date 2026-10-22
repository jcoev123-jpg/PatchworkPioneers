extends "res://tests/live_seeded_opening_route_test.gd"
## Discover by stable encounter ID, then exercise fresh mounted scenes and inputs.


func _fixture() -> Dictionary:
	for value in range(1, 257):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		for id in map.get_legal_choices():
			if map.get_node(id).type != "Fight":
				continue
			if not map.choose_node(id):
				continue
			var choice := RunAuthoredBattleEntry.new().entry_current_battle(
				map, rng, RunFightEncounterSelection.new())
			if choice.get("success", false) and choice.get("encounter_id") == "buttonfront_pinfall":
				return {"seed": value, "id": id}
			# Each first-Fight candidate must use a fresh map and RNG stream.
			break
	return {}


func _values(app) -> Array:
	return [app.run_map.get_route(), app.run_rng.state, app.encounter_id,
		app.party.get_heroes(), app.enemies.get_enemies(), app.deck.hand.duplicate(),
		app.deck.draw_pile.duplicate(), app.deck.discard_pile.duplicate(),
		app.deck.energy, app.deck.turn_active, app.enemy_intents.get_intents(),
		app.enemy_intents._turn_index, app.battle_result.get_outcome(),
		app.run_heroes.duplicate(true), app.run_deck.duplicate(), app.session_gold,
		app.run_scraps, app.party_carryover.read_state(), app.act_outcome.get_state()]


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var fixture := _fixture()
	_check(not fixture.is_empty(), "bounded seeds 1..256 find a legal opening Buttonfront Pinfall")
	if fixture.is_empty():
		_finish()
		return
	print("Buttonfront Pinfall discovered seed=", fixture.seed, " node=", fixture.id)
	var replay: Array = []
	var stale := Callable()
	for mode in range(2):
		var app = load("res://scenes/app.tscn").instantiate()
		root.add_child(app)
		await process_frame
		app.run_seed = fixture.seed
		await _activate(app.start_button, mode == 1)
		_check(app.run_map != null and app.route_view != null and app.deck == null,
			"real title input initializes chooser before any encounter")
		if app.run_map == null or app.route_view == null:
			app.free()
			continue
		_check(app.run_map.get_legal_choices().has(fixture.id)
			and app.run_map.get_node(fixture.id).type == "Fight", "discovered Fight is legal in live map")
		var before := _record(app)
		if stale.is_valid():
			stale.call()
		_check(_record(app) == before, "old scene route callback cannot create encounter in fresh run")
		_reject(app, "unknown", "unknown route")
		_reject(app, "f02_n0", "future route")
		var foreign := RunMap.new()
		var foreign_rng := RandomNumberGenerator.new()
		foreign_rng.seed = fixture.seed
		_check(foreign.generate(foreign_rng), "foreign map exists")
		_check(not app._choose_route(fixture.id, weakref(foreign)) and _record(app) == before,
			"foreign map request cannot create encounter or consume state")
		var action := _button(app, fixture.id)
		if action == null:
			app.free()
			continue
		action.disabled = true
		_reject(app, fixture.id, "disabled legal route")
		action.disabled = false
		stale = action.pressed.get_connections()[0].callable
		await _activate(action, mode == 1)
		var mounted: bool = app.party != null and app.enemies != null and app.deck != null \
			and app.enemy_intents != null and app.round_flow != null and app.battle_result != null
		_check(mounted and app.encounter_id == "buttonfront_pinfall", "live entry actually selects Buttonfront Pinfall")
		if not mounted:
			app.free()
			continue
		_check(app.run_map.get_route() == [fixture.id] and app.battle_view.is_visible_in_tree(),
			"actual Fight committed and battle visible")
		_check(app.round_flow._party == app.party and app.round_flow._enemies == app.enemies
			and app.round_flow._deck == app.deck and app.round_flow._intents == app.enemy_intents
			and app.deck._rng == app.run_rng, "real models and single run RNG drive End Turn")
		var enemies: Array = app.enemies.get_enemies()
		_check(enemies.size() == 2, "two real enemies mounted")
		if enemies.size() != 2:
			app.free()
			continue
		_check(enemies[0].id == "button_guard" and enemies[0].position == 1
			and enemies[0].name == "Button Guard" and enemies[0].hp == 16
			and enemies[1].id == "fray_scavenger" and enemies[1].position == 2
			and enemies[1].name == "Fray Scavenger" and enemies[1].hp == 14,
			"authored identities, slots and HP appear in real roster")
		var presenter = app.get_node("LiveEnemyRoster")
		_check(presenter.enemies == app.enemies and presenter._labels.size() == 2,
			"live roster presenter binds the actual two enemies")
		for index in range(presenter._labels.size()):
			_check(presenter._labels[index].is_visible_in_tree() and presenter._labels[index].text
				== String(enemies[index].name),
				"real target name tag displays exact identity")
			var meter = app.get_node("LiveCombatMeters").row.get_child(3 + index)
			_check(meter.hp_text.is_visible_in_tree() and meter.hp_text.text == "HP: %d/%d" % [enemies[index].hp, enemies[index].max_hp]
				and meter.block_text.is_visible_in_tree() and meter.block_text.text == "Block: 0",
				"real enemy meter displays exact HP and Block")
		_check(app.party.get_hero(1).hp == 40 and app.party.get_hero(1).block == 6,
			"ordinary Warden opening Block absorbs exactly the Exposed-enhanced six damage")
		var labels := [
			"Intent: Enemy 1 -> Hero 1: Exposed 1; Enemy 2 -> Hero 1 (Warden): 4 damage",
			"Intent: Enemy 1: 2 Block; Enemy 2 -> Hero 3 (Tinker): 3 damage",
			"Intent: Enemy 1 -> Hero 2 (Seamstress): 3 damage; Enemy 2: Buff +2 Block"]
		var trace: Array = [_values(app)]
		for turn in range(4):
			_check(not app.intent_label.visible and app.intent_label.text == labels[turn % 3],
				"visible exact authored intent beat %d" % (turn + 1))
			var unchanged := _values(app)
			stale.call()
			_check(not app._choose_route(fixture.id) and not app._choose_route("f02_n0")
				and _values(app) == unchanged, "stale and illegal route inputs cannot alter active encounter")
			_check(app.deck.turn_active and app.deck.energy == 3 and app.deck.hand.size() == 5
				and not app.end_turn_button.disabled, "legal ordinary End Turn available")
			await _activate(app.end_turn_button, mode == 1)
			_check(app.enemy_intents._turn_index == turn + 1 and app.deck.turn_active,
				"real End Turn advances exactly one beat and draws next hand")
			var expected_hp := [[40, 30, 26], [40, 30, 23], [40, 27, 23], [34, 27, 23]]
			for position in range(1, 4):
				var hero: Dictionary = app.party.get_hero(position)
				_check(hero.hp == expected_hp[turn][position - 1] and hero.block == 0
					and hero.get("statuses", {}) == ({"exposed": 1} if turn % 3 == 0 and position == 1 else {}),
					"exact live HP, Block and timed Exposed after beat %d hero %d" % [turn + 1, position])
			_check(app.enemies.get_enemy(1).hp == 16 and app.enemies.get_enemy(2).hp == 14
				and app.enemies.get_enemy(1).block == (0 if turn == 0 else 2)
				and app.enemies.get_enemy(2).block == (2 if turn >= 2 else 0),
				"exact live enemy HP and authored Block/buff results")
			trace.append(_values(app))
		_check(app.party.get_hero(1).hp == 34 and app.intent_label.text == labels[1],
			"wraparound opening proves Exposed raises base four to six with no opening Block left")
		if mode == 0:
			replay = trace
		else:
			_check(trace == replay and trace.size() == 5,
				"independent same-seed scene replays all actors, hands, RNG, intents and run ledgers")
		app.free()
		await process_frame
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_buttonfront_pinfall_route_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
