extends "res://tests/live_routed_battle_reentry_test.gd"
## Mounted opening Fight -> later Fight pick -> further Fight Skip, and replay.


func _multi_fixture() -> Dictionary:
	for value in range(1, 3000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for id in map.get_legal_choices():
			if map.get_node(id).type != "Fight":
				continue
			var second := _path_to(map, id, "Fight")
			if second.is_empty():
				continue
			var third := _path_to(map, second.back(), "Fight")
			if third.is_empty():
				continue
			map.choose_node(id)
			var selected := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
			if selected.get("encounter_id") == "starter_attacks" and _two_enemy_multi(value, id, second, third):
				return {"seed": value, "fight": id, "paths": [second, third]}
			map.undo_choice(id, [])
	return {}


func _two_enemy_multi(seed_value: int, first: String, second: Array, third: Array) -> bool:
	if second.size() != 1 or third.size() != 1:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := RunMap.new()
	map.generate(rng)
	map.choose_node(first)
	var selector := RunFightEncounterSelection.new()
	RunAuthoredBattleEntry.new().entry_current_battle(map, rng, selector)
	var party := CombatParty.new(app._load_party_definitions())
	var enemies := CombatEnemies.new(app._load_enemy_definitions())
	var intents := CombatEnemyIntents.new(app._load_enemy_schedule())
	var run_deck: Array[String] = app._load_starter_deck()
	var deck := CombatDeck.new(run_deck, rng)
	var result := CombatBattleResult.new(party, enemies)
	var flow := CombatRoundFlow.new(deck, party, enemies, intents, result)
	flow.begin_fight()
	var attack_play := CombatAttackCards.new()
	var targeting := CombatAttackTargeting.new()
	for turn in range(20):
		attack_play.start_player_turn()
		for play in range(3):
			var chosen := ""
			var target := 0
			for held in deck.hand:
				var preview := targeting.get_preview(deck, party, enemies, held)
				if preview.playable and preview.requires_selection:
					chosen = held
					target = preview.target_positions.back()
					break
			if chosen.is_empty():
				break
			var owner: String = catalog.get_definition(chosen).get("owner", "")
			var owner_statuses := {}
			for hero in party.get_heroes():
				if hero.id == owner:
					owner_statuses = hero.get("statuses", {})
			var enemy_statuses := {}
			for enemy in enemies.get_enemies():
				enemy_statuses[enemy.position] = enemy.get("statuses", {})
			attack_play.play_attack(deck, party, enemies, chosen, target, owner_statuses, enemy_statuses)
			if result.evaluate() != CombatBattleResult.ACTIVE:
				break
		if result.evaluate() != CombatBattleResult.ACTIVE:
			break
		flow.end_turn()
	if result.evaluate() != CombatBattleResult.VICTORY:
		return false
	var rewards := RunFightVictoryRewards.new(result, rng, ["warden", "seamstress", "tinker"],
		RunPoolCardRewardOffers.get_authored_base_candidates(), run_deck, 0, false)
	var prepared := rewards.prepare()
	if not prepared.ok:
		return false
	run_deck.append(prepared.offers[0].id)
	for fight_index in range(2):
		var next_id: String = second[0] if fight_index == 0 else third[0]
		if not map.choose_node(next_id):
			return false
		var entry := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, selector)
		if not entry.get("success", false) or entry.enemies.get_enemies().size() != 2:
			return false
		if fight_index == 0:
			CombatDeck.new(run_deck, rng)
			rng.randi_range(10, 20)
			var drawn: Dictionary = RunPoolCardRewardOffers.generate(rng,
				["warden", "seamstress", "tinker"],
				RunPoolCardRewardOffers.get_authored_base_candidates())
			if not drawn.get("ok", false):
				return false
			run_deck.append(drawn["offers"][0]["id"])
	return true


func _settlement_state() -> Array:
	return [app.run_scraps, app.run_stitch_descriptors.duplicate(true), app.run_next_stitch_id, _persistent(), app.party_carryover.read_state(),
		app.multi_fight_rewards.read_state() if app.multi_fight_rewards != null else {},
		app.fight_reward_claimed, app.fight_reward_offers.duplicate(true),
		app.fight_reward_gold, app.continue_button, app.route_view]


func _reject_reward(callback: Callable, reason: String) -> void:
	var before := _settlement_state()
	callback.call()
	_check(_settlement_state() == before, reason + " preserves resources, ledger, RNG and controls")


func _reward_oracle() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.state = app.run_rng.state
	var award := rng.randi_range(10, 20)
	var party_ids: Array[String] = ["warden", "seamstress", "tinker"]
	var living_order: Array[String] = []
	var living_map: Dictionary = {}
	for hero: Dictionary in app.party.get_heroes():
		if int(hero.get("hp", 0)) > 0:
			living_map[String(hero.get("id", ""))] = true
	for pid: String in party_ids:
		if living_map.has(pid):
			living_order.append(pid)
	var tiers: Array[String] = ["common", "uncommon", "rare"]
	var weights := {"common": 60, "uncommon": 30, "rare": 10}
	var hero_buckets: Dictionary = {}
	for hid: String in living_order:
		hero_buckets[hid] = {"common": [], "uncommon": [], "rare": []}
	for record: Dictionary in RunPoolCardRewardOffers.get_authored_base_candidates():
		var owner := String(record.get("owner", ""))
		var rarity := String(record.get("rarity", ""))
		if hero_buckets.has(owner) and hero_buckets[owner].has(rarity):
			(hero_buckets[owner][rarity] as Array).append(record)
	for hid: String in living_order:
		for tier: String in tiers:
			(hero_buckets[hid][tier] as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return String(a.get("id", "")) < String(b.get("id", "")))
	var offers: Array = []
	for hid: String in living_order:
		if offers.size() >= 3:
			break
		var buckets: Dictionary = hero_buckets[hid]
		var weight_sum := 0
		for tier: String in tiers:
			if not (buckets[tier] as Array).is_empty():
				weight_sum += int(weights[tier])
		var roll: int = rng.randi_range(1, weight_sum)
		var chosen := ""
		var running := 0
		for tier: String in tiers:
			if (buckets[tier] as Array).is_empty():
				continue
			running += int(weights[tier])
			if roll <= running:
				chosen = tier
				break
		var bucket: Array = buckets[chosen]
		var index := rng.randi_range(0, bucket.size() - 1)
		var record: Dictionary = bucket[index]
		bucket.remove_at(index)
		offers.append({"id": String(record["id"]), "owner": String(record["owner"])})
	if offers.size() < 3:
		var union_buckets: Dictionary = {"common": [], "uncommon": [], "rare": []}
		for tier: String in tiers:
			for hid: String in living_order:
				for record: Dictionary in hero_buckets[hid][tier]:
					union_buckets[tier].append(record)
			(union_buckets[tier] as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return String(a.get("id", "")) < String(b.get("id", ""))
			)
		while offers.size() < 3:
			var weight_sum := 0
			for tier: String in tiers:
				if not (union_buckets[tier] as Array).is_empty():
					weight_sum += int(weights[tier])
			var roll: int = rng.randi_range(1, weight_sum)
			var chosen := ""
			var running := 0
			for tier: String in tiers:
				if (union_buckets[tier] as Array).is_empty():
					continue
				running += int(weights[tier])
				if roll <= running:
					chosen = tier
					break
			var bucket: Array = union_buckets[chosen]
			var index := rng.randi_range(0, bucket.size() - 1)
			var record: Dictionary = bucket[index]
			bucket.remove_at(index)
			offers.append({"id": String(record["id"]), "owner": String(record["owner"])})
	return {"offers": offers, "award": award, "rng": rng.state}


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _multi_fixture()
	_check(not fixture.is_empty(), "generated legal path has opening and two later normal Fights")
	if fixture.is_empty():
		await _finish_multi()
		return
	var stale: Array[Callable] = []
	var replay: Array = []
	for session in range(2):
		seed(750075)
		var global_next := randi()
		seed(750075)
		if not await _routed_win(fixture, false):
			break
		_check(app.fight_rewards != null and app.multi_fight_rewards == null, "opening retains original reward transaction")
		await _click(app.reward_buttons[0])
		stale.append(app.reward_buttons[0].pressed.get_connections()[0].callable)
		await _click(app.continue_button)
		var observations: Array = []
		for fight_index in range(2):
			var path: Array = fixture.paths[fight_index].duplicate()
			var id: String = path.pop_back()
			await _visit_path(path, session == 1)
			await _click(_route_action(id))
			_check(app.run_map.get_current_node_id() == id and not app._battle_closed and app.multi_fight_rewards == null,
				"connected input replaces battle and clears old coordinator")
			# Real mounted actors provide the terminal fixture; opening combat above
			# uses held-card input. Damage/status/Block must settle only on choice.
			_check(app.party.apply_damage(2, 1) and app.party.gain_block(1, 9), "later survivor damage and transit Block fixture")
			app.party._heroes[1].statuses = {"weak": 2}
			if fight_index == 1:
				_check(app.party.apply_damage(3, 999), "further Fight carries a downed hero")
			var expected := _reward_oracle()
			var ledger: Dictionary = app.party_carryover.read_state()
			var owned: Array = app.run_deck.duplicate()
			var gold: int = app.session_gold
			for enemy in app.enemies.get_enemies():
				_check(app.enemies.apply_damage(enemy.position, 9999), "defeat actual mounted enemy")
			app._observe_battle_result()
			await _frames()
			var service: RunMultiFightRewards = app.multi_fight_rewards
			_check(service != null and app.fight_rewards == null and app.reward_buttons.size() == 4,
				"later victory mounts coordinator and three offers plus Skip")
			if service == null or app.reward_buttons.size() != 4:
				break
			_check(app.fight_reward_offers == expected.offers and app.fight_reward_gold == expected.award
				and app.run_rng.state == expected.rng and expected.award >= 10 and expected.award <= 20,
				"exact independent gold and sorted-pool offer RNG oracle")
			_check(app.party_carryover.read_state() == ledger and app.run_deck == owned and app.session_gold == gold
				and app.continue_button == null and app.result_label.text.contains("Pending gold: %d" % expected.award),
				"preparation never commits survivors, pays, or enables Continue")
			for index in range(4):
				var button: Button = app.reward_buttons[index]
				_check(not button.disabled and button.is_visible_in_tree()
					and Rect2(0, 0, 1280, 720).encloses(button.get_global_rect()), "live reward fits viewport")
				if index < 3:
					var def: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(expected.offers[index].id)
					var owner_node: Control = button.get_parent().get_node_or_null("CardHeader/OwnerPatch") if button.get_parent().get_node_or_null("CardHeader") != null else button.get_parent().get_node("OwnerPatch")
					_check(owner_node.get("owner_color") == LiveRunCardRewardChoicePanel.OWNER_COLORS[expected.offers[index].owner] and button.get_parent().get_node("NameLabel").text == def.get("display_name", "") and button.get_parent().get_node("MetadataRow/RarityLabel").text == def.get("rarity", "").capitalize(), "actual offer visible")
				else:
					_check(button.text == "0 Skip — take no card", "actual Skip shortcut and full label visible")
			var before := _settlement_state()
			for repeat in range(3):
				app._observe_battle_result()
				app._build_card_reward()
				_check(service.prepare(id, app.battle_result, app.party).get("offers", []) == expected.offers, "cached prepare")
			_check(_settlement_state() == before and app.reward_buttons.size() == 4, "repeated observation never redraws or pays")
			var button: Button = app.reward_buttons[0]
			var callback: Callable = button.pressed.get_connections()[0].callable
			for old in stale:
				_reject_reward(old, "retained callback")
			_reject_reward(app._claim_card_reward.bind("foreign_card", button, service), "foreign card")
			_reject_reward(app._claim_card_reward.bind(expected.offers[1].id, button, service), "mismatched button")
			_reject_reward(app._claim_card_reward.bind(expected.offers[0].id, app.return_button, service), "foreign button")
			var foreign := RunMultiFightRewards.new(app.run_map, app.run_rng, app.party_carryover, app.run_deck, gold, [], catalog.get_all_card_ids())
			_reject_reward(app._claim_card_reward.bind(expected.offers[0].id, button, foreign), "foreign service")
			button.disabled = true
			_reject_reward(callback, "disabled reward")
			button.disabled = false
			button.hide()
			_reject_reward(callback, "hidden reward")
			button.show()
			var map: RunMap = app.run_map
			var replacement := RunMap.new()
			replacement._floor_ids = map._floor_ids.duplicate(true)
			replacement._nodes = map._nodes.duplicate(true)
			replacement._route = map.get_route()
			app.run_map = replacement
			_reject_reward(callback, "same graph foreign source map")
			app.run_map = map
			var route: Array[String] = map.get_route()
			map._route.pop_back()
			_reject_reward(callback, "stale node and route")
			map._route = route.duplicate()
			map._nodes[id].outgoing.append("foreign_node")
			_reject_reward(callback, "source graph drift")
			map._nodes[id].outgoing.erase("foreign_node")
			var live_party: CombatParty = app.party
			app.party = CombatParty.new(live_party.get_heroes())
			_reject_reward(callback, "replaced actor binding")
			app.party = live_party
			var live_enemies: CombatEnemies = app.enemies
			app.enemies = CombatEnemies.new(live_enemies.get_enemies())
			_reject_reward(callback, "replaced enemy binding")
			app.enemies = live_enemies
			app.party._heroes[1].hp -= 1
			_reject_reward(callback, "survivors changed after preparation")
			app.party._heroes[1].hp += 1
			app.session_gold += 1
			_reject_reward(callback, "gold snapshot drift")
			app.session_gold -= 1
			app.run_heroes[0].hp -= 1
			_reject_reward(callback, "published roster drift")
			app.run_heroes[0].hp += 1
			app.run_deck.append("warden_strike")
			_reject_reward(callback, "resource snapshot drift")
			app.run_deck.pop_back()
			_check(not service.choose("foreign_node", "").ok, "coordinator rejects wrong node")
			_check(_settlement_state() == before, "all rejected inputs preserve original complete state")
			_check(app.run_scraps == fight_index + 1, "later reward preparation/rejection never awards scraps")
			var survivors := _block_free_party()
			for hero in survivors:
				for previous in ledger.heroes:
					if previous.id == hero.id and previous.hp > 0 and hero.hp == 0:
						hero.max_hp = maxi(10, previous.max_hp - 3)
			var selected: String = expected.offers[0].id if fight_index == 0 else ""
			if not selected.is_empty():
				owned.append(selected)
			var callbacks: Array[Callable] = []
			for action in app.reward_buttons:
				callbacks.append(action.pressed.get_connections()[0].callable)
			if session == 1 or fight_index == 1:
				app.reward_buttons[2 if fight_index == 1 else 0].grab_focus()
				if fight_index == 1:
					await _key(KEY_TAB)
					_check(app.reward_buttons[3].has_focus(), "physical Tab reaches Skip")
				await _key(KEY_ENTER)
			else:
				await _click(button)
			var expected_ledger: Dictionary = ledger.duplicate(true)
			expected_ledger.heroes = survivors
			expected_ledger.completed_fights.append(id)
			_check(app.fight_reward_claimed and app.run_deck == owned and app.session_gold == gold + expected.award
				and app.run_heroes == survivors and app.party_carryover.read_state() == expected_ledger
				and app.run_rng.state == expected.rng, "pick/Skip settles exact survivors, Block-free ledger, deck and gold once")
			_check(is_instance_valid(app.continue_button) and not app.continue_button.disabled, "successful choice enables connected Continue")
			if not is_instance_valid(app.continue_button):
				break
			var detached := service.read_state()
			detached.deck.clear()
			detached.party.heroes[0].hp = 0
			_check(service.read_state().deck == owned and app.run_heroes == survivors, "published resources are detached")
			_check(app.run_scraps == fight_index + 2, "later pick/Skip adds exactly one scrap")
			var after := _settlement_state()
			var continue_callback: Callable = app.continue_button.pressed.get_connections()[0].callable
			app.continue_button.disabled = true
			_reject_reward(continue_callback, "disabled Continue")
			app.continue_button.disabled = false
			_reject_reward(app._continue_to_rest_route.bind(foreign, weakref(map), app.continue_button), "foreign Continue service")
			_reject_reward(app._continue_to_rest_route.bind(service, weakref(replacement), app.continue_button), "foreign Continue map")
			map._route.pop_back()
			_reject_reward(continue_callback, "stale Continue route")
			map._route = route.duplicate()
			for action in app.reward_buttons:
				_check(action.disabled, "settlement disables all choices")
				action.disabled = false
			for old in callbacks:
				_reject_reward(old, "forced duplicate reward")
			_check(not service.choose(id, "").ok and _settlement_state() == after, "direct duplicate cannot pay")
			observations.append([expected, owned.duplicate(), app.session_gold, expected_ledger])
			stale.append_array(callbacks)
			stale.append(app.continue_button.pressed.get_connections()[0].callable)
			await _click(app.continue_button)
			_check(app.route_view != null and app.route_view.is_visible_in_tree()
				and not app.battle_view.visible and app._can_choose_connected_route(), "Continue exposes legal connected next nodes")
		_check(observations.size() == 2, "both later Fight settlements actually executed")
		if session == 0:
			replay = observations.duplicate(true)
		else:
			_check(observations == replay, "same-seed restart exactly reproduces offers/gold/RNG/deck/party ledger")
		await _click(app.route_back_button)
		for old in stale:
			old.call()
		_check(app.multi_fight_rewards == null and app.run_map == null and app.party_carryover == null
			and app.run_deck.is_empty() and app.session_gold == 0 and app.title_view.visible, "title clears coordinator and stale callbacks cannot restore state")
		_check(randi() == global_next, "all mounted settlement and rejection paths preserve global RNG")
	await _finish_multi()


func _finish_multi() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_multi_fight_settlement_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
