extends "res://tests/live_legal_starter_fight_test.gd"
## Drive the shipped scene with physical inputs; only the downed-hero case is injected.


func _fixture() -> Dictionary:
	for value in range(1, 1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for id in map.get_legal_choices():
			if map.get_node(id).type != "Fight":
				continue
			var rest := false
			var unsupported := false
			for next in map.get_node(id).outgoing:
				rest = rest or map.get_node(next).type == "Rest"
				unsupported = unsupported or map.get_node(next).type != "Rest"
			if rest and unsupported:
				map.choose_node(id)
				var selected := RunFightEncounterSelection.new().select_current_fight(map, rng, app.FIGHT_ENCOUNTER_PATHS)
				if selected.get("encounter_id") == "starter_attacks":
					return {"seed": value, "fight": id}
	return {}


func _persistent() -> Array:
	return [app.run_heroes.duplicate(true), app.run_deck.duplicate(), app.session_gold,
		app.run_rng.state, app.run_map.get_route(), _state()]


func _routed_win(fixture: Dictionary, downed: bool) -> bool:
	app.run_seed = fixture.seed
	await _click(app.route_button)
	var fight: Button
	for button in app.route_buttons:
		if button.get_meta("route_id") == fixture.fight:
			fight = button
	_check(fight != null and not fight.disabled, "seeded opening Fight is a real enabled node")
	if fight == null:
		return false
	await _click(fight)
	_check(app.deck != null and app.party.is_valid(), "routed input mounts real combat")
	if app.deck == null:
		return false
	if downed:
		_check(app.party.apply_damage(3, 999) and app.party.is_downed(3), "fixture downs Tinker in actual combat")
	var before := _persistent()
	app._continue_to_rest_route(null, weakref(app.run_map), null)
	_check(_persistent() == before and app.route_view == null, "active combat cannot continue or heal")
	for turn in range(20):
		for play in range(3):
			var id := ""
			var target := 0
			for held in app.deck.hand:
				var preview := CombatAttackTargeting.new().get_preview(app.deck, app.party, app.enemies, held)
				if preview.playable and preview.requires_selection:
					id = held
					target = preview.target_positions.back()
					break
			if id.is_empty():
				break
			if not await _choose(id, play % 2 == 1):
				return false
			await _key(KEY_1 if target == 1 else KEY_2)
			if app._battle_closed:
				break
		if app._battle_closed:
			break
		await _click(app.end_turn_button)
	var won: bool = app.battle_result.get_outcome() == CombatBattleResult.VICTORY
	_check(won and app.card_reward != null, "seeded routed fight wins using legal held-card inputs")
	return won and app.card_reward != null


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _fixture()
	_check(not fixture.is_empty(), "actual seeded graph offers connected Rest and unsupported choices")
	if fixture.is_empty():
		_finish_rest()
		return
	var old_continue: Callable
	var old_route: Callable
	var old_heal: Callable
	var old_back: Callable
	var replay: Array = []
	for session in range(3):
		seed(380038)
		var global_next := randi()
		seed(380038)
		if not await _routed_win(fixture, session == 1):
			break
		_check(app.run_heroes == app.party.get_heroes() and app.run_heroes.size() == 3,
			"routed victory saves complete independent three-hero run snapshot")
		var copy: Array = app.run_heroes.duplicate(true)
		_check(app.party.apply_damage(1, 1), "probe combat snapshot independence")
		_check(app.run_heroes == copy and app.party.get_heroes() != copy, "combat mutation cannot alias run heroes")
		var before := _persistent()
		app._continue_to_rest_route(app.card_reward, weakref(app.run_map), null)
		_check(_persistent() == before and app.continue_button == null, "unclaimed reward offers no Continue")
		if session == 1:
			app.reward_buttons[3].grab_focus()
			await _key(KEY_ENTER)
		else:
			await _click(app.reward_buttons[0])
		_check(app.card_reward.is_claimed() and is_instance_valid(app.continue_button), "claim or Skip exposes Continue")
		if not is_instance_valid(app.continue_button):
			break
		before = _persistent()
		for stale in [old_continue, old_route, old_heal, old_back]:
			if stale.is_valid():
				stale.call()
		_check(_persistent() == before and app.battle_view.visible, "old session callbacks preserve fresh victory")
		old_continue = app.continue_button.pressed.get_connections()[0].callable
		if session == 0:
			replay = before.duplicate(true)
		elif session == 2:
			_check(before == replay, "fresh routed restart deterministically replays complete victory state")
		var claimed: RunCardRewardChoice = app.card_reward
		app.card_reward = RunCardRewardChoice.new(claimed._offered_cards, ["warden", "seamstress", "tinker"])
		_check(app.card_reward.is_valid() and not app.card_reward.is_claimed(), "otherwise valid unclaimed transaction fixture")
		app._continue_to_rest_route(app.card_reward, weakref(app.run_map), app.continue_button)
		_check(_persistent() == before and app.route_view == null, "unclaimed reward rejects with current real Continue control")
		app.card_reward = claimed
		app._continue_to_rest_route(app.card_reward, weakref(RunMap.new()), app.continue_button)
		_check(_persistent() == before and app.route_view == null, "wrong map identity cannot continue")
		# Invalid and defeated snapshots reject before mounting or advancing the map.
		for invalid in [[], [{"id": "bad"}], _defeated(copy)]:
			app.run_heroes = invalid.duplicate(true)
			var invalid_before := _persistent()
			old_continue.call()
			_check(_persistent() == invalid_before and app.route_view == null, "invalid/defeated run cannot enter Rest")
		app.run_heroes = copy.duplicate(true)
		var live_party: CombatParty = app.party
		for invalid_party in [CombatParty.new([]), _defeated_party()]:
			app.party = invalid_party
			var rejected_before := _persistent()
			old_continue.call()
			_check(_persistent() == rejected_before and app.route_view == null,
				"invalid/defeated combat party cannot leave Fight with enabled Continue")
		app.party = live_party
		if session == 0:
			await _click(app.continue_button)
		else:
			app.return_button.grab_focus()
			await _key(KEY_TAB)
			_check(app.continue_button.has_focus(), "Tab reaches Continue after claimed reward")
			await _key(KEY_ENTER)
		_check(app.route_view != null and not app.battle_view.visible, "Continue presents connected route")
		if app.route_view == null:
			break
		before = _persistent()
		old_continue.call()
		var rest: Button
		var shown: Array[String] = []
		for button in app.route_buttons:
			var id: String = button.get_meta("route_id")
			shown.append(id)
			_check(button.disabled == (app.run_map.get_node(id).type != "Rest"), "only actual Rest controls enabled")
			if button.disabled:
				await _click(button)
				button.grab_focus()
				await _key(KEY_ENTER)
				button.pressed.emit()
			else:
				rest = button
		_check(shown == app.run_map.get_legal_choices(), "all and only real connected choices are shown")
		_check(rest != null and _persistent() == before, "disabled controls and duplicate Continue mutate nothing")
		if rest == null:
			break
		old_route = rest.pressed.get_connections()[0].callable
		old_back = app.route_back_button.pressed.get_connections()[0].callable
		var parent_id: String = app.run_map.get_current_node_id()
		var outgoing: Array = app.run_map._nodes[parent_id].outgoing.duplicate()
		app.run_map._nodes[parent_id].outgoing.erase(rest.get_meta("route_id"))
		old_route.call()
		_check(_persistent() == before and app.rest_view == null, "enabled mounted Rest revalidates legal connection at activation")
		app.run_map._nodes[parent_id].outgoing = outgoing
		app._choose_rest_route("f12_n0", weakref(app.run_map), app.run_map.get_route(), rest)
		app._choose_rest_route(rest.get_meta("route_id"), weakref(RunMap.new()), app.run_map.get_route(), rest)
		_check(_persistent() == before, "unconnected node and wrong-map callback are inert")
		if session == 2:
			await _click(app.route_back_button)
			old_route.call()
			old_continue.call()
			_check(app.title_view.visible and app.run_map == null and app.run_heroes.is_empty(), "route Back and stale callbacks clear run")
			continue
		var rest_id: String = rest.get_meta("route_id")
		if session == 0:
			await _click(rest)
		else:
			app.route_back_button.grab_focus()
			await _key(KEY_TAB)
			_check(root.gui_get_focus_owner() in app.route_buttons and not root.gui_get_focus_owner().disabled,
				"keyboard navigation skips disabled nodes")
			rest.grab_focus()
			await _key(KEY_ENTER)
		_check(app.rest_view != null and app.run_map.get_route() == [fixture.fight, rest_id], "Rest advances map exactly once")
		if app.rest_view == null:
			break
		before = _persistent()
		old_route.call()
		old_back.call()
		old_continue.call()
		_check(_persistent() == before and app.rest_view.visible, "duplicate route and stale route Back are inert")
		var visit: RunRestRecovery = app.rest_recovery
		old_heal = app.rest_heal_button.pressed.get_connections()[0].callable
		var live_map: RunMap = app.run_map
		var replacement := RunMap.new()
		var replacement_rng := RandomNumberGenerator.new()
		replacement_rng.seed = fixture.seed
		replacement.generate(replacement_rng)
		_check(replacement.choose_node(fixture.fight) and replacement.choose_node(rest_id), "wrong map has otherwise identical valid Rest route")
		app.run_map = replacement
		var wrong_map_before := _persistent()
		old_heal.call()
		_check(_persistent() == wrong_map_before and not visit.is_consumed(), "Heal rejects different map identity with identical route")
		app.run_map = live_map
		app._heal_at_rest(RunRestRecovery.new(copy), app.rest_heal_button)
		_check(_persistent() == before and not visit.is_consumed(), "wrong visit rejects without consumption")
		app.run_heroes = _defeated(copy)
		var invalid_before := _persistent()
		old_heal.call()
		_check(_persistent() == invalid_before and not visit.is_consumed(), "changed defeated snapshot cannot heal")
		app.run_heroes = copy.duplicate(true)
		var expected_heal := RunRestRecovery.new(copy).choose_heal()
		_check(expected_heal.ok, "independent service oracle is valid")
		if "--inject-wrong-hp" in OS.get_cmdline_user_args():
			expected_heal.heroes[0].hp = -1
		if session == 0:
			await _click(app.rest_heal_button)
		else:
			app.rest_heal_button.grab_focus()
			await _key(KEY_ENTER)
		_check(visit.is_consumed() and app.rest_heal_button.disabled and app.run_heroes == expected_heal.heroes,
			"visible Heal commits service exact result once")
		for index in range(3):
			var hero: Dictionary = app.run_heroes[index]
			_check(hero.hp == mini(hero.max_hp, (1 if copy[index].hp == 0 else copy[index].hp) + int(hero.max_hp * 0.3)), "exact capped 30% and revive arithmetic")
			_check(app.rest_hp_label.text.contains("%s: HP %d/%d" % [hero.id.capitalize(), hero.hp, hero.max_hp]), "on-screen persistent HP updated")
		_check(copy[2].hp == 0 if session == 1 else copy[2].hp == copy[2].max_hp, "fixture exercises downed revive or full-HP cap")
		var after := _persistent()
		_check(after.slice(1) == before.slice(1), "heal preserves inventory/gold/RNG/route and all combat state")
		old_heal.call()
		app.rest_heal_button.pressed.emit()
		_check(_persistent() == after, "duplicate Heal does not apply twice")
		old_back = app.rest_back_button.pressed.get_connections()[0].callable
		await _click(app.rest_back_button)
		for stale in [old_continue, old_route, old_heal, old_back]:
			stale.call()
		_check(app.title_view.visible and app.run_heroes.is_empty() and app.run_map == null
			and app.rest_recovery == null and app.rest_view == null and app.deck == null, "Return clears run and post-Return inputs are inert")
		_check(randi() == global_next, "entire route/rest path leaves global RNG unchanged")
	await _click(app.start_button)
	_check(app.deck != null and app.run_map == null and app.run_heroes.is_empty() and app.rest_recovery == null,
		"fresh direct Start remains independent after Rest Return")
	await _click(app.return_button)
	_finish_rest()


func _defeated(heroes: Array) -> Array:
	var result := heroes.duplicate(true)
	for hero in result:
		hero.hp = 0
	return result


func _defeated_party() -> CombatParty:
	var result := CombatParty.new(app._load_party_definitions())
	for position in [1, 2, 3]:
		result.apply_damage(position, 999)
	return result


func _finish_rest() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_rest_route_entry_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
