extends "res://tests/live_run_map_entry_test.gd"
## Shipped scene, physical title/route inputs and independent typed data oracle.


func _record(app) -> Array:
	var carry := app.party_carryover as RunTornCarryover
	return [_snapshot(app), app.run_heroes.duplicate(true), carry.read_state(),
		carry.torn.read_state(), carry._node, carry._start.duplicate(true),
		app.act_outcome.get_state(), app.fight_selection._selected.duplicate(true),
		app.fight_selection._bound_map, app.session_gold, app.run_scraps,
		app.run_trinkets.duplicate(), app.run_removal_count,
		app.run_stitch_descriptors.duplicate(true), app.run_next_stitch_id]


func _activate(button: Button, keyboard: bool) -> void:
	_check(is_instance_valid(button) and not button.disabled and button.is_visible_in_tree(), "real enabled action exists")
	if not is_instance_valid(button):
		return
	if keyboard:
		button.grab_focus()
		await _key(KEY_SPACE)
	else:
		await _click(button)


func _button(app, id: String) -> Button:
	for button in app.route_buttons:
		if button.get_meta("route_id") == id:
			return button
	_check(false, "legal route button exists: " + id)
	return null


func _clean(app) -> void:
	_check(app.run_map == null and app.run_rng == null and app.fight_selection == null
		and app.party_carryover == null and app.act_outcome == null and app.run_heroes.is_empty()
		and app.run_deck.is_empty() and app.run_trinkets.is_empty() and app.run_scraps == 0
		and app.run_stitch_descriptors.is_empty() and app.run_next_stitch_id == 1
		and app.session_gold == 0 and app.run_removal_count == 0 and app.encounter_id == "",
		"Return clears all seeded resources and services")
	_check(app.route_view == null and app.route_buttons.is_empty() and app.route_atlas == null
		and app.route_atlas_overlay == null and app.battle_view == null and app.rest_view == null
		and app.shop_view == null and app._connected_map == null and app._placeholder_map == null
		and app._carryover_map == null and app._rest_map == null and app._shop_map == null
		and app.title_view.visible and app.start_button.has_focus(), "Return clears every mounted visit and callback source")


func _invalid_starts(app) -> void:
	var path := OS.get_environment("TEMP").path_join("patchwork_seeded_opening_095.json")
	var original: Array = app._load_party_definitions()
	var wrong_owner: Array = original.duplicate(true)
	wrong_owner[1].id = "wrong_owner"
	var fractional: Array = original.duplicate(true)
	fractional[0].max_hp = 40.5
	for fixture in [["starter_deck_path", "[]"], ["starter_deck_path", "not JSON"],
		["starter_party_path", JSON.stringify(wrong_owner)],
		["starter_party_path", JSON.stringify(fractional)], ["starter_party_path", "{}"]]:
		var field: String = fixture[0]
		var previous: String = app.get(field)
		var file := FileAccess.open(path, FileAccess.WRITE)
		_check(file != null, "malformed admission fixture is outside repository")
		if file == null:
			continue
		file.store_string(fixture[1])
		file.close()
		app.set(field, path)
		seed(950095)
		var expected := randi()
		seed(950095)
		await _activate(app.start_button, true)
		_check(randi() == expected, "rejected Start does not consume the actual global RNG")
		_clean(app)
		app.set(field, previous)
	DirAccess.remove_absolute(path)
	for field in ["starter_deck_path", "starter_party_path"]:
		var previous: String = app.get(field)
		app.set(field, path)
		await _activate(app.start_button, false)
		_clean(app)
		app.set(field, previous)


func _typed(app, heroes: Array, cards: Array, rng_state: int, kind: String) -> void:
	_check(app.deck != null and app.party != null and app.enemies != null
		and app.enemy_intents != null and app.round_flow != null and app.battle_result != null,
		"typed opening mounts all actual combat models")
	if app.deck == null:
		return
	var pools: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RunAuthoredBattleEntry.POOLS_PATH))
	_check(pools[kind].has(app.encounter_id), "selected encounter belongs to actual node type")
	if not pools[kind].has(app.encounter_id):
		return
	var entry: Dictionary = pools[kind][app.encounter_id]
	var schedule := RunFightEncounterSelection._parse_schedule_text(FileAccess.get_file_as_string(entry.schedule))
	_check(app.enemy_intents._definitions == schedule, "exact typed authored schedule mounted")
	var actors: Array = app.enemies.get_enemies()
	_check(actors.size() == entry.enemy_ids.size() and not actors.is_empty(), "complete typed roster mounted")
	for index in range(actors.size()):
		_check(actors[index].id == entry.enemy_ids[index] and actors[index].position == index + 1,
			"typed enemy identity and source slot")
	var catalog: Array = []
	for path in RunAuthoredBattleEntry.CATALOG_PATHS:
		catalog.append_array(RunTypedBattleRoster._parse_catalog_text(FileAccess.get_file_as_string(path)))
	var definitions: Array = []
	for id in entry.enemy_ids:
		var matches := catalog.filter(func(record): return record.id == id)
		_check(matches.size() == 1, "one authored enemy definition: " + id)
		if matches.size() == 1:
			definitions.append(matches[0])
	_check(actors == CombatEnemies.new(definitions).get_enemies(), "full typed enemy HP, metadata and roster order")
	var expected: Array = heroes.duplicate(true)
	for hero in expected:
		hero.block = 6 if hero.id == "warden" else 0
	_check(app.party.get_heroes() == expected and app.run_heroes == heroes
		and app.run_deck == cards, "all persistent hero fields and deck survive; starting Block is combat only")
	var rng := RandomNumberGenerator.new()
	rng.state = rng_state
	var ids: Array = pools[kind].keys()
	ids.sort()
	_check(app.encounter_id == ids[rng.randi_range(0, ids.size() - 1)], "one sorted typed selection draw")
	var reference := CombatDeck.new(cards, rng)
	_check(reference.start_turn(), "independent persistent deck starts")
	_check(app.deck.hand == reference.hand and app.deck.draw_pile == reference.draw_pile
		and app.deck.discard_pile == reference.discard_pile and app.run_rng.state == rng.state
		and app.deck._rng == app.run_rng and app.deck.energy == 3,
		"selection and real hand share the uninterrupted run RNG")
	_check(app._current_act_battle() and app._current_carryover_fight()
		and app.act_outcome.get_state().pending_node_id == app.run_map.get_current_node_id(),
		"live outcome and torn witness bind the actual selected battle")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await _invalid_starts(app)
	var cases: Array = [
		["Fight", 1, "f01_n0", ""], ["Elite", 1, "f01_n1", ""],
		["Rest", 2, "f01_n2", "f02_n3"], ["Shop", 3, "f01_n2", "f02_n2"],
		["Event", 7, "f01_n1", "f02_n0"], ["Treasure", 9, "f01_n2", "f02_n2"],
	]
	_check(cases.size() == 6, "all six opening fixtures exist")
	var stale: Array[Callable] = []
	for fixture in cases:
		var replay: Array = []
		for mode in range(2):
			app.run_seed = fixture[1]
			await _activate(app.start_button, mode == 1)
			_check(app.run_map != null and app.route_view != null, "physical Start opens initialized chooser")
			if app.run_map == null:
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = fixture[1]
			var map := RunMap.new()
			_check(map.generate(rng), "independent map generated")
			_check(app.run_map.get_floors() == map.get_floors() and app.run_map.get_floors().size() == 12
				and app.run_rng.state == rng.state and app.run_deck == app._load_starter_deck()
				and app.run_heroes == CombatParty.new(app._load_party_definitions()).get_heroes()
				and app.run_deck.size() == 12 and app.party_carryover is RunTornCarryover,
				"Start publishes canonical seeded map, twelve cards and three heroes before combat")
			var before := _record(app)
			for callback in stale:
				callback.call()
			app.start_run_requested.emit()
			app._open_route()
			_check(_record(app) == before, "duplicate Start and stale Back/Return callbacks are inert")
			_check(not app._choose_route("unknown") and not app._choose_route("f02_n0")
				and not app._choose_route(fixture[2], weakref(map)) and _record(app) == before,
				"unknown, future and foreign requests reject atomically")
			if mode == 0:
				replay = before
			else:
				# Object identities differ between sessions; compare authoritative values.
				_check(before.slice(1, 8) == replay.slice(1, 8), "fresh seed replays every initial ledger")
			for button in app.route_buttons:
				_check(not button.disabled, "every actual legal opening enabled")
			stale.append(app.route_back_button.pressed.get_connections()[0].callable)
			var heroes: Array = app.run_heroes.duplicate(true)
			var cards: Array = app.run_deck.duplicate()
			var shared = app.run_rng
			var carry = app.party_carryover
			var latch = app.act_outcome
			var start_rng: int = shared.state
			var kind: String = fixture[0]
			var action := _button(app, fixture[2])
			action.disabled = true
			var disabled_before := _record(app)
			_check(not app._choose_route(fixture[2]) and _record(app) == disabled_before, "disabled otherwise-legal opening rejects without mutation")
			action.disabled = false
			if kind in ["Fight", "Elite"]:
				var selector = app.fight_selection
				for choice in [{"success": false}, {"success": true, "node_type": kind, "encounter_id": "missing", "definitions": []}]:
					selector._selected[fixture[2]] = choice
					var rejected := _record(app)
					_check(not app._choose_route(fixture[2]) and _record(app) == rejected
						and app.fight_selection == selector, "malformed typed entry rolls back map, selection, RNG, ledgers and chooser")
				selector._selected.clear()
				var original = app.party_carryover
				app.party_carryover = RunTornCarryover.new([])
				var invalid: Array = _snapshot(app)
				_check(not app._choose_route(fixture[2]) and _snapshot(app) == invalid, "invalid non-null torn ledger rejects without spending")
				app.party_carryover = original
			await _activate(_button(app, fixture[2]), mode == 1)
			_check(app.run_map.get_route() == [fixture[2]], "opening commits exactly the selected node")
			if kind == "Rest":
				_check(app.rest_recovery != null and app.rest_view.is_visible_in_tree()
					and app.rest_continue_button.disabled, "real Rest visit mounted before any battle")
				stale.append(app.rest_back_button.pressed.get_connections()[0].callable)
				if mode == 0:
					await _activate(app.rest_upgrade_button, false)
					cards[0] = "warden_strike_plus"
				else:
					await _activate(app.rest_heal_button, true)
				_check(app.run_deck == cards and not app.rest_continue_button.disabled,
					"existing Rest transaction commits exact deck/heal choice")
				await _activate(app.rest_continue_button, mode == 1)
			elif kind == "Shop":
				_check(app.shop_visit != null and app.shop_purchases != null and app.shop_view.is_visible_in_tree(),
					"real seeded Shop visit mounted before any battle")
				stale.append(app.shop_back_button.pressed.get_connections()[0].callable)
				var shop_before := _record(app)
				app._buy_at_shop(app.shop_visit, app.shop_purchases, app.shop_buy_button)
				app._remove_at_shop(app.shop_visit, app.shop_remove_button)
				_check(_record(app) == shop_before, "zero-gold Shop cannot spend or remove")
				await _activate(app.shop_continue_button, mode == 1)
			elif kind in ["Event", "Treasure"]:
				if kind == "Event":
					_check(app.route_view == null and app.quiet_spool_panel != null, "first Event requires authored choice")
					await _activate(app.quiet_spool_panel.get_choice_buttons()[1], mode == 1)
				_check(app.route_view != null and app._placeholder_route == [fixture[2]]
					and app.run_heroes == heroes and app.run_deck == cards and shared.state == start_rng,
					"placeholder has no effects and mounts actual connected choices")
			if kind not in ["Fight", "Elite"]:
				_check(app.run_map.get_legal_choices().has(fixture[3])
					and app.run_map.get_node(fixture[3]).type == "Fight", "next Fight is an actual connected node")
				start_rng = shared.state
				await _activate(_button(app, fixture[3]), mode == 1)
				_check(app.run_map.get_route() == [fixture[2], fixture[3]], "noncombat opening progresses one connected floor")
				kind = "Fight"
			_typed(app, heroes, cards, start_rng, kind)
			_check(app.run_rng == shared and app.party_carryover == carry and app.act_outcome == latch,
				"same RNG, torn ledger and outcome latch retained through first combat")
			# Witness a real model victory, then claim through the mounted reward action.
			for enemy in app.enemies.get_enemies():
				_check(app.enemies.apply_damage(enemy.position, 999), "victory fixture damages each real typed enemy")
			app._observe_battle_result()
			# Let the mounted reward panel finish container layout and deferred focus.
			await process_frame
			await process_frame
			_check(app._battle_closed and app.reward_buttons.size() == 4,
				"first typed battle exposes real rewards after every opening kind")
			if app.reward_buttons.size() == 4:
				await _activate(app.reward_buttons[3], mode == 1)
				_check(app.fight_reward_claimed and app.party_carryover.read_state().completed_fights.has(app.run_map.get_current_node_id())
					and app.run_deck == cards and app.run_scraps == (2 if kind == "Elite" else 1)
					and app.session_gold >= (25 if kind == "Elite" else 10)
					and app.session_gold <= (35 if kind == "Elite" else 20)
					and app.run_trinkets.size() == (1 if kind == "Elite" else 0),
					"first typed reward settles the same carryover once with correct type, resources and skipped deck")
			await _activate(app.return_button, mode == 1)
			_clean(app)
			# Return directly from a no-battle visit, then replay the same seeded title.
			await _activate(app.start_button, mode == 0)
			if fixture[0] not in ["Fight", "Elite"]:
				await _activate(_button(app, fixture[2]), mode == 0)
				if fixture[0] == "Event":
					await _activate(app.quiet_spool_panel.get_choice_buttons()[1], mode == 1)
				var back: Button = app.rest_back_button if fixture[0] == "Rest" else app.shop_back_button if fixture[0] == "Shop" else app.route_back_button
				await _activate(back, mode == 1)
			else:
				await _activate(app.route_back_button, mode == 1)
			_clean(app)
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_seeded_opening_route_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
