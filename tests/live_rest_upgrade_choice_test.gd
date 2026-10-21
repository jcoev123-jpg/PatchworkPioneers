extends "res://tests/live_routed_battle_reentry_test.gd"
## Real connected Rest selection and actual held Strike+ combat input.


func _upgrade_fixture() -> Dictionary:
	for value in range(1, 1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		var opening_rng := rng.state
		for fight in map.get_legal_choices():
			if map.get_node(fight).type != "Fight":
				continue
			for rest in map.get_node(fight).outgoing:
				if map.get_node(rest).type != "Rest":
					continue
				for next in map.get_node(rest).outgoing:
					if map.get_node(next).type != "Fight":
						continue
					var selector := RunFightEncounterSelection.new()
					rng.state = opening_rng
					map.choose_node(fight)
					var selected := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, selector)
					map.undo_choice(fight, [])
					if selected.get("encounter_id") == "starter_attacks":
						return {"seed": value, "fight": fight, "rest": rest, "next": next}
	return {}


func _upgrade_state() -> Array:
	return [app.run_scraps, app.run_stitch_descriptors.duplicate(true), app.run_next_stitch_id, _persistent(), app.run_map.get_floors(), app.party_carryover.read_state(),
		app.rest_upgrade.is_consumed(), app.rest_recovery.is_consumed(),
		app.rest_upgrade._source.duplicate(true), app.rest_upgrade._deck.duplicate(),
		app.rest_upgrade._upgrades.duplicate(true), app.rest_upgrade._valid,
		app._rest_committed_deck.duplicate(), app._rest_committed_heroes.duplicate(true),
		app.rest_heal_button.disabled, app.rest_upgrade_button.disabled,
		app.rest_upgrade_cards.disabled, app.rest_continue_button.disabled, app.route_view]


func _reject_upgrade(callback: Callable, reason: String) -> void:
	var before := _upgrade_state()
	callback.call()
	_check(_upgrade_state() == before, reason + " preserves full state and choice eligibility")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _upgrade_fixture()
	_check(not fixture.is_empty(), "seeded Fight -> Rest -> Fight path exists")
	if fixture.is_empty():
		await _finish_upgrade()
		return
	var replay: Array = []
	var stale: Callable
	for session in range(3):
		seed(780078)
		var global_next := randi()
		seed(780078)
		if not await _routed_win(fixture, false):
			break
		await _click(app.reward_buttons[3])
		_check(app.run_deck == catalog.get_starting_deck() and app.run_deck.size() == 12,
			"skip retains exact initial twelve-card starter deck")
		await _click(app.continue_button)
		await _click(_route_action(fixture.rest))
		_check(app.rest_upgrade != null and is_instance_valid(app.rest_upgrade_cards)
			and is_instance_valid(app.rest_upgrade_button), "real connected Rest mounts upgrade service and controls")
		if app.rest_upgrade == null or not is_instance_valid(app.rest_upgrade_cards):
			break
		_bounds(app.rest_view)
		_check(app.run_scraps == 1 and app.rest_stitch_button.disabled, "one earned scrap cannot enable Stitch")
		var choices: OptionButton = app.rest_upgrade_cards
		var visit: RunRestCardUpgrade = app.rest_upgrade
		var button: Button = app.rest_upgrade_button
		var upgrade: Callable = button.pressed.get_connections()[0].callable
		var heal: Callable = app.rest_heal_button.pressed.get_connections()[0].callable
		var next: Callable = app.rest_continue_button.pressed.get_connections()[0].callable
		var source: Array = app.run_deck.duplicate()
		var heroes: Array = app.run_heroes.duplicate(true)
		_check(app.rest_hp_label.text.contains(" -> "), "eligible Upgrade visit initially shows pending Heal forecast")
		var ledger: Dictionary = app.party_carryover.read_state()
		var indices: Array[int] = []
		for index in range(source.size()):
			if source[index] == "warden_strike":
				indices.append(index)
		_check(indices.size() == 2 and choices.item_count == 2 and not button.disabled,
			"two actual duplicate Strike indices offered with one visible Upgrade")
		if indices.size() != 2 or choices.item_count != 2:
			break
		for item in range(2):
			_check(choices.get_item_metadata(item) == indices[item]
				and choices.get_item_text(item).contains("#%d" % (indices[item] + 1)), "each visible choice identifies its deck position")
		_reject_upgrade(next, "premature Continue")
		app._rest_committed_deck.assign(source)
		_reject_upgrade(upgrade, "forged partially committed deck")
		app._rest_committed_deck.clear()
		if stale.is_valid():
			_reject_upgrade(stale, "previous session upgrade")
		_reject_upgrade(app._upgrade_at_rest.bind(RunRestCardUpgrade.new(source, {"warden_strike": "warden_strike_plus"}), button, choices), "foreign visitor")
		_reject_upgrade(app._upgrade_at_rest.bind(visit, app.rest_heal_button, choices), "foreign action")
		var foreign := OptionButton.new()
		_reject_upgrade(app._upgrade_at_rest.bind(visit, button, foreign), "foreign selector")
		foreign.free()
		# Every rejection starts with otherwise-valid mounted controls and preserves all surviving models.
		for invalid in [-1, source.size(), "1", 1.5, source.find("warden_brace")]:
			choices.set_item_metadata(1, invalid)
			_reject_upgrade(upgrade, "forged index " + str(invalid))
		choices.set_item_metadata(1, indices[1])
		choices.set_item_text(1, "forged label")
		_reject_upgrade(upgrade, "forged label")
		choices.set_item_text(1, app._rest_upgrade_text(indices[1]))
		for mapping in [{}, {"warden_strike": "unknown"}, {"warden_brace": "warden_strike_plus"}]:
			visit._upgrades = mapping
			_reject_upgrade(upgrade, "unmapped or invalid replacement")
		visit._upgrades = {"warden_strike": "warden_strike_plus"}
		visit._valid = false
		_reject_upgrade(upgrade, "invalid visitor")
		visit._valid = true
		visit._consumed = true
		_reject_upgrade(upgrade, "forged consumed visitor")
		_reject_upgrade(next, "forged consumption cannot complete Rest")
		visit._consumed = false
		visit._deck[indices[1]] = "warden_brace"
		_reject_upgrade(upgrade, "forged visitor deck")
		visit._deck.assign(source)
		app.run_deck[indices[0]] = "warden_brace"
		_reject_upgrade(upgrade, "changed run deck")
		app.run_deck.assign(source)
		app.run_heroes[0].hp -= 1
		_reject_upgrade(upgrade, "changed party")
		app.run_heroes = heroes.duplicate(true)
		app.session_gold += 1
		_reject_upgrade(upgrade, "changed gold")
		app.session_gold -= 1
		var rng_state: int = app.run_rng.state
		app.run_rng.randi()
		_reject_upgrade(upgrade, "changed run RNG")
		app.run_rng.state = rng_state
		var map: RunMap = app.run_map
		app.run_map = RunMap.new()
		_reject_upgrade(upgrade, "replaced map identity")
		app.run_map = map
		map._route.append(fixture.next)
		_reject_upgrade(upgrade, "changed route")
		map._route.pop_back()
		var edges: Array = map._nodes[fixture.rest].outgoing.duplicate()
		map._nodes[fixture.rest].outgoing.clear()
		_reject_upgrade(upgrade, "changed map edges")
		map._nodes[fixture.rest].outgoing = edges
		for control in [button, choices, app.rest_view]:
			control.hide()
			_reject_upgrade(upgrade, "hidden input or visit")
			control.show()
		button.disabled = true
		_reject_upgrade(upgrade, "disabled action")
		button.disabled = false
		choices.disabled = true
		_reject_upgrade(upgrade, "disabled selector")
		choices.disabled = false
		if session == 2:
			await _click(app.rest_heal_button)
			_check(app.rest_recovery.is_consumed() and app.rest_upgrade_button.disabled, "Heal remains available and excludes Upgrade")
			_reject_upgrade(upgrade, "Upgrade after Heal")
		else:
			# Select the SECOND duplicate with real popup input in both modalities.
			if session == 0:
				await _click(choices)
				var popup := choices.get_popup()
				_check(popup.visible, "mouse opens eligible index menu")
				var font := popup.get_theme_font("font")
				var height := font.get_height(popup.get_theme_font_size("font_size")) + popup.get_theme_constant("v_separation")
				var margin := popup.get_theme_stylebox("panel").get_content_margin(SIDE_TOP)
				var point := Vector2(popup.position) + Vector2(30, margin + height * 1.5)
				for pressed in [true, false]:
					var event := InputEventMouseButton.new()
					event.position = point
					event.button_index = MOUSE_BUTTON_LEFT
					event.pressed = pressed
					root.push_input(event, true)
				await _frames()
			else:
				app.rest_heal_button.grab_focus()
				await _key(KEY_TAB)
				_check(choices.has_focus(), "Tab reaches card index selector")
				await _key(KEY_SPACE)
				await _key(KEY_DOWN)
				await _key(KEY_ENTER)
			_check(choices.selected == 1, "physical input selects second duplicate index")
			var before := _persistent()
			if session == 0:
				await _click(button)
			else:
				choices.grab_focus()
				await _key(KEY_TAB)
				_check(button.has_focus(), "Tab reaches Upgrade action")
				await _key(KEY_ENTER)
			var upgraded := source.duplicate()
			upgraded[indices[1]] = "warden_strike_plus"
			_check(visit.is_consumed() and not app.rest_recovery.is_consumed() and app.run_deck == upgraded,
				"one selected duplicate replaced exactly once without consuming Heal service")
			_check(_persistent().slice(2) == before.slice(2) and app.run_heroes == heroes
				and app.party_carryover.read_state() == ledger, "Upgrade preserves heroes, gold, RNG, route, combat and carryover ledger")
			var hp_lines: PackedStringArray = []
			for hero in heroes:
				hp_lines.append("%s: HP %d/%d" % [hero.id.capitalize(), hero.hp, hero.max_hp])
			_check(app.rest_hp_label.text == "\n".join(hp_lines), "Upgrade removes forecast and keeps exact current HP rows")
			app._refresh_rest_hp()
			_check(app.rest_hp_label.text == "\n".join(hp_lines), "refresh cannot restore forecast after Upgrade")
			_check(app.rest_heal_button.disabled and button.disabled and choices.disabled
				and not app.rest_continue_button.disabled, "exclusive consumed upgrade enables Continue")
			_reject_upgrade(upgrade, "duplicate Upgrade")
			_reject_upgrade(heal, "Heal after Upgrade")
			app.run_deck[indices[0]] = "warden_brace"
			_reject_upgrade(next, "changed committed deck")
			app.rest_recovery._consumed = true
			_reject_upgrade(next, "forged Heal consumption cannot bypass committed upgrade validation")
			app.rest_recovery._consumed = false
			app.run_deck.assign(upgraded)
			await _click(app.rest_continue_button)
			_check(app.route_view != null and not app.rest_view.visible, "Upgrade Continue opens legal connected chooser")
			_check(app.route_buttons.size() == map.get_legal_choices().size(), "exact legal connected choices remain playable")
			_reject_upgrade(upgrade, "hidden prior Rest")
			var oracle := _oracle(fixture.next)
			await _click(_route_action(fixture.next))
			_check(app.battle_result.get_outcome() == CombatBattleResult.ACTIVE and _mounted_state() == oracle,
				"next real battle uses upgraded deck and unchanged carried party")
			# Draw from the real ongoing deck, never inject a held card.
			while not app.deck.hand.has("warden_strike_plus") and not app.deck.draw_pile.is_empty():
				_check(app.deck.draw_extra(1) == 1, "real next-battle draw")
			app._refresh_hand()
			await _frames()
			_check(app.deck.hand.has("warden_strike_plus"), "upgraded copy actually held in next battle")
			var combat := _state()
			var target: int = CombatAttackTargeting.new().get_preview(app.deck, app.party, app.enemies, "warden_strike_plus").get("target_positions", [0])[0]
			_check(target > 0, "living legal recipient exists")
			var enemy: Dictionary = app.enemies.get_enemy(target)
			_check(app.party.get_hero(1).get("statuses", {}).is_empty() and enemy.get("statuses", {}).is_empty(), "seven-damage base case has no modifiers")
			if await _choose("warden_strike_plus", session == 1):
				await _key([KEY_1, KEY_2, KEY_3][target - 1])
			var expected_hand: Array = combat.hand.duplicate()
			expected_hand.erase("warden_strike_plus")
			_check(presenter.last_event.ok and presenter.last_event.hits[0].damage == 7,
				"real held-card input resolves exactly seven base damage")
			_check(app.deck.energy == combat.energy - 1 and app.deck.hand == expected_hand
				and app.deck.discard_pile == combat.discard + ["warden_strike_plus"]
				and app.deck.draw_pile == combat.draw and app.run_rng.state == combat.rng,
				"standard single charge/discard preserves remaining piles and RNG")
			_check(app.enemies.get_enemy(target).hp == enemy.hp - maxi(0, 7 - enemy.block), "actual recipient loses exact unblocked damage")
			var state: Array = [_persistent(), app.party_carryover.read_state(), presenter.last_event]
			if session == 0:
				replay = state.duplicate(true)
			else:
				_check(state == replay, "same-seed mouse/keyboard replay matches full next battle and attack")
		stale = upgrade
		await _click(app.return_button if app.battle_view.visible else app.rest_back_button)
		_check(app.rest_upgrade == null and app.rest_upgrade_cards == null and app.rest_upgrade_button == null
			and app._rest_committed_deck.is_empty() and app.run_deck.is_empty() and app.run_map == null,
			"title clears all upgrade state and controls")
		stale.call()
		_check(app.run_map == null and app.run_deck.is_empty(), "post-title upgrade callback inert")
		_check(randi() == global_next, "complete path consumes no global RNG")
	_check(app._start_battle(), "explicit standalone M01 fixture starts")
	await _frames()
	_check(app.deck != null and app.rest_upgrade == null and app.run_map == null, "restart creates independent battle")
	stale.call()
	_check(not app.run_deck.has("warden_strike_plus"), "stale callback cannot upgrade restarted run")
	await _click(app.return_button)
	await _finish_upgrade()


func _finish_upgrade() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_rest_upgrade_choice_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
