extends "res://tests/live_routed_battle_reentry_test.gd"


func _torn_state() -> Array:
	return [_persistent(), app.party_carryover.read_state(),
		app.party_carryover.torn.read_state(), app.fight_reward_claimed,
		app.run_trinkets.duplicate(), app.run_map.get_floors()]


func _reject_torn(callback: Callable, reason: String) -> void:
	var before := _torn_state()
	callback.call()
	_check(_torn_state() == before, reason + " preserves heroes, tears, rewards, route and RNG")


func _tear_fixture(kind: String) -> Dictionary:
	for value in range(1, 3000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for first in map.get_legal_choices():
			if map.get_node(first).type != "Fight":
				continue
			for second in map.get_node(first).outgoing:
				if map.get_node(second).type != kind:
					continue
				for rest in map.get_node(second).outgoing:
					if map.get_node(rest).type != "Rest":
						continue
					for last in map.get_node(rest).outgoing:
						if map.get_node(last).type == "Fight":
							if _two_enemy_second(value, first, second):
								return {"seed": value, "fight": first, "second": second, "rest": rest, "last": last}
	return {}


func _two_enemy_second(seed_value: int, first: String, second: String) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := RunMap.new()
	map.generate(rng)
	map.choose_node(first)
	var selector := RunFightEncounterSelection.new()
	selector.select_current_battle(map, rng, {"Fight": app.FIGHT_ENCOUNTER_PATHS})
	CombatDeck.new(app._load_starter_deck(), rng)
	rng.randi_range(10, 20)
	var pool_size := catalog.get_all_card_ids().size()
	for pick in range(3):
		rng.randi_range(0, pool_size - 1 - pick)
	map.choose_node(second)
	var entry := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, selector)
	return entry.get("success", false) and entry.enemies.get_enemies().size() == 2


func _activate(button: Button, keyboard: bool) -> void:
	_check(button != null and not button.disabled and button.is_visible_in_tree(), "required mounted control is reachable")
	if button == null:
		return
	if keyboard:
		button.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(button)


func _win_fixture() -> void:
	for enemy in app.enemies.get_enemies():
		_check(app.enemies.apply_damage(enemy.position, 9999), "defeat real mounted enemy")
	app._observe_battle_result()
	_check(app.battle_result.get_outcome() == CombatBattleResult.VICTORY and app.reward_buttons.size() == 4, "witnessed victory mounts actual rewards")


func _service_checks() -> void:
	var party := CombatParty.new(app._load_party_definitions())
	var carry := RunTornCarryover.new(party.get_heroes())
	_check(carry.is_valid(), "canonical service fixture valid")
	for cycle in range(8):
		var enemies := CombatEnemies.new(app._load_enemy_definitions())
		var result := CombatBattleResult.new(party, enemies)
		var node := "fight_%d" % cycle
		_check(carry.begin_battle(node, result, party), "actual start receipt")
		var before := [carry.read_state(), carry.torn.read_state()]
		_check(carry.preview_reward(node, result, party) == null and not carry.commit_victory(node, result, party).ok, "unwitnessed battle rejected")
		_check([carry.read_state(), carry.torn.read_state()] == before, "unwitnessed admission inert")
		party.apply_damage(3, 9999)
		for enemy in enemies.get_enemies():
			enemies.apply_damage(enemy.position, 9999)
		result.evaluate()
		var saved := party.get_heroes()
		party._heroes[2].max_hp += 1
		_check(carry.preview_reward(node, result, party) == null, "invalid end maximum rejected")
		party._heroes.assign(saved)
		_check(carry.commit_victory(node, result, party).ok and carry.apply_reward(node, result, party).ok, "witnessed victory and reward publish")
		var expected := maxi(10, 26 - 3 * (cycle + 1))
		_check(carry.read_state().heroes[2].max_hp == expected and carry.read_state().heroes[2].hp == 0, "exact repeated tear reaches floor 10")
		var downed := carry.create_next_fight_party()
		var next_enemies := CombatEnemies.new(app._load_enemy_definitions())
		var next_result := CombatBattleResult.new(downed, next_enemies)
		_check(carry.begin_battle("revival_probe", next_result, downed), "valid downed start for no-revival probe")
		downed._heroes[2].hp = 1
		for enemy in next_enemies.get_enemies():
			next_enemies.apply_damage(enemy.position, 9999)
		next_result.evaluate()
		_check(not carry.can_commit_victory("revival_probe", next_result, downed) and carry.preview_reward("revival_probe", next_result, downed) == null, "inherited no-revival check retained")
		before = [carry.read_state(), carry.torn.read_state()]
		_check(not carry.apply_reward(node, result, party).ok and not carry.commit_victory(node, result, party).ok, "duplicate receipts rejected")
		_check([carry.read_state(), carry.torn.read_state()] == before, "duplicate receipt inert")
		var healed := carry.choose_rest_heal("rest_%d" % cycle)
		_check(healed.ok and healed.heroes[2].max_hp == expected and healed.heroes[2].hp == 1 + int(expected * 0.3), "Rest revives using reduced maximum")
		_check(carry.torn.read_state().heroes == healed.heroes, "Rest observers agree")
		party = carry.create_next_fight_party()
		_check(party != null and party.get_heroes() == healed.heroes, "exact deterministic rehydration")
	# A defeated party may never publish tears, even with an evaluated outcome.
	var enemies := CombatEnemies.new(app._load_enemy_definitions())
	var result := CombatBattleResult.new(party, enemies)
	_check(carry.begin_battle("defeat", result, party), "defeat starts from valid held roster")
	for position in range(1, 4):
		party.apply_damage(position, 9999)
	result.evaluate()
	var before := [carry.read_state(), carry.torn.read_state()]
	_check(carry.preview_reward("defeat", result, party) == null and not carry.commit_victory("defeat", result, party).ok, "defeated party rejected")
	_check([carry.read_state(), carry.torn.read_state()] == before, "defeat cannot change tears or heroes")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	seed(800080)
	var global_next := randi()
	seed(800080)
	_service_checks()
	for kind in ["Fight", "Elite"]:
		var fixture := _tear_fixture(kind)
		_check(not fixture.is_empty(), "real graph supports Fight -> %s -> Rest -> Fight" % kind)
		if fixture.is_empty():
			continue
		var replay: Array = []
		for session in range(2):
			var keyboard := session == 1
			app.run_seed = fixture.seed
			await _activate(app.route_button, keyboard)
			await _activate(_route_action(fixture.fight), keyboard)
			_check(app.party_carryover is RunTornCarryover, "routed battle owns tear service")
			var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
			_check(swap.ok, "real combat permits actor permutation")
			app.party._heroes.assign(swap.heroes)
			app.party._heroes[2].statuses = {"weak": 2, "bleed": 1}
			app.party.apply_damage(3, 9999)
			await _win_fixture()
			var expected := _block_free_party()
			expected[2].max_hp = 23
			var button: Button = app.reward_buttons[3 if kind == "Elite" else 0]
			var callback: Callable = button.pressed.get_connections()[0].callable
			_reject_torn(app._claim_card_reward.bind("foreign_card", button, app.fight_rewards), "invalid reward")
			app.party._heroes[2].max_hp += 1
			_reject_torn(callback, "invalid tear snapshot")
			app.party._heroes[2].max_hp -= 1
			await _activate(button, keyboard)
			_check(app.fight_reward_claimed and app.run_heroes == expected and app.party_carryover.torn.read_state().tear_counts.tinker == 1, "reward applies exactly one tear preserving all statuses/order/HP")
			_reject_torn(callback, "duplicate reward")
			await _activate(app.continue_button, keyboard)
			await _activate(_route_action(fixture.second), keyboard)
			var mounted := expected.duplicate(true)
			mounted[1].block = 6
			_check(app.party.get_heroes() == mounted, "next connected battle exactly rehydrates reduced maximum and same formation/statuses")
			_reject_torn(callback, "stale first-battle callback")
			if kind == "Elite":
				app.party.apply_damage(1, 9999)
				expected[0].hp = 0
				expected[0].max_hp = 27
			await _win_fixture()
			await _activate(app.reward_buttons[3], keyboard)
			_check(app.run_heroes == expected and app.party_carryover.torn.read_state().tear_counts.tinker == 1, "already downed hero gains no second tear in Fight/Elite")
			if kind == "Elite":
				_check(app.party_carryover.torn.read_state().tear_counts.seamstress == 1, "newly downed Elite actor gains exactly one tear")
			await _activate(app.continue_button, keyboard)
			await _activate(_route_action(fixture.rest), keyboard)
			var healed := RunRestRecovery.new(expected).choose_heal()
			await _activate(app.rest_heal_button, keyboard)
			_check(app.run_heroes == healed.heroes and app.run_heroes[2].hp == 7 and app.run_heroes[2].max_hp == 23 and app.party_carryover.torn.read_state().heroes == healed.heroes, "actual Rest preserves reduced maximum and synchronizes observers")
			await _activate(app.rest_continue_button, keyboard)
			await _activate(_route_action(fixture.last), keyboard)
			mounted = healed.heroes.duplicate(true)
			mounted[1].block = 6
			_check(app.party.get_heroes() == mounted, "post-Rest battle exactly rehydrates capped recovered actors")
			var observed: Array = [app.party.get_heroes(), app.party_carryover.torn.read_state(), app.run_rng.state]
			if session == 0:
				replay = observed
			else:
				_check(observed == replay, "mouse and keyboard replay identical heroes/receipts/RNG")
			await _activate(app.return_button, keyboard)
			_check(app.party_carryover == null and app.run_heroes.is_empty(), "title resets tear history")
	await _activate(app.start_button, false)
	_check(app.run_map == null and app.party_carryover == null and app.party.get_hero(3).max_hp == 26, "standalone restart has pristine maximum and no tear service")
	await _activate(app.return_button, false)
	_check(randi() == global_next, "service and mounted flows never consume global RNG")
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_torn_carryover_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
