extends "res://tests/live_support_hand_test.gd"

const IDS := ["rag_duelist_needle_barrage", "rag_duelist_needle_barrage_plus"]
const CATALOG := preload("res://data/cards/rag_duelist_pool_cards.gd")

func _begin(id: String, seat: int = 1, lethal: bool = false) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 350
	_check(app._start_battle(), "genuine mounted battle starts")
	presenter = app.get_node("LiveAttackPreview")
	var rng := RandomNumberGenerator.new()
	rng.seed = 350
	var cards: Array[String] = [id, id, "warden_strike", "warden_brace", "tinker_tune_up"]
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.count(id) == 2, "two actual held printings")
	app.deck.combat_state.energy = 2
	var heroes: Array = [
		{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "seamstress", "name": "Seamstress", "max_hp": 26}]
	heroes.insert(seat - 1, {"id": "rag_duelist", "name": "Rag Duelist",
		"max_hp": 32})
	app.party = CombatParty.new(heroes)
	app.enemies = CombatEnemies.new([
		{"id": "front_foe", "max_hp": 5 if lethal else 18, "statuses": {"tangled": 1} if not lethal else {}},
		{"id": "middle_foe", "max_hp": 23},
		{"id": "forbidden_foe", "max_hp": 35}])
	_check(app.enemies.gain_block(1, 0 if lethal else 4) and app.enemies.gain_block(2, 2)
		and app.enemies.gain_block(3, 5), "original enemy slots carry distinct Block")
	_check(app.party.is_valid() and app.enemies.is_valid()
		and app.party.get_hero(seat).id == "rag_duelist"
		and app.enemies.get_enemy(1).hp == (5 if lethal else 18)
		and app.enemies.get_enemy(2).block == 2
		and app.enemies.get_enemy(3).block == 5, "non-vacuous authenticated roster")
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies,
		app.enemy_intents, app.battle_result)
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_hand()
	await _frames()
	var panel := _pool_panel(id)
	_check(panel != null and panel.is_visible_in_tree()
		and presenter._bindings.has(panel), "actual reward/upgrade copy gets a live input binding")
	return panel


func _dispose() -> void:
	app.free()
	await _frames()


func _state() -> Array:
	return [_snapshot(app.deck, app.party, app.run_rng),
		app.enemies.get_enemies(), app.battle_result.get_outcome(),
		presenter.last_event.duplicate(true)]


func _arm(panel: Control, keyboard: bool) -> void:
	if keyboard:
		await _keyboard(KEY_ESCAPE)
		await _keyboard(KEY_P)
	else:
		await _mouse(panel)
	_check(presenter._armed == panel, "genuine panel armed by P or mouse")


func _success(id: String, target: int, keyboard: bool, lethal: bool = false) -> void:
	var panel := await _begin(id, 1, lethal)
	if panel == null:
		await _dispose()
		return
	var metadata = app.get_node("LiveSupportHand")._metadata
	var facts: Dictionary = metadata.get_facts(panel)
	var authored := CATALOG.new().get_definition(id)
	_check(facts.get("known", false) and facts.cost == 2 and facts.owner == "rag_duelist"
		and metadata.definition(id) == authored and metadata.visual_state(panel).playable
		and metadata.short_line(id).contains("3 separate hits")
		and authored.reward_eligible == (id == IDS[0])
		and authored.illustration_path.ends_with("rag_duelist_needle_barrage.png"),
		"real hand has authentic base/plus metadata, price, face and art fallback")
	var before := _state()
	await _hover(panel)
	var quote: Dictionary = presenter.current_forecast.duplicate(true)
	_check(quote.get("playable", false) and quote.target_positions == [1, 2]
		and quote.hits.size() == 2 and quote.hits[0].hit_count == 3
		and quote.hits[0].base_damage == (3 if id == IDS[0] else 4)
		and presenter.cue.text.contains(authored.display_name)
		and presenter.cue.text.contains("2 energy")
		and presenter.cue.text.contains("3 separate strikes")
		and presenter.cue.text.contains("one foe"),
		"pure two-original-slot strike preview uses printed hits and one foe")
	_check(_state() == before, "hover leaves complete battle and run RNG untouched")
	await _arm(panel, keyboard)
	_check(_state() == before, "mouse/physical keyboard selection is pure")
	await _keyboard(KEY_3)
	_check(_state() == before, "third slot cannot fire even while alive")
	var enemies_before: Array = app.enemies.get_enemies()
	var heroes_before: Array = app.party.get_heroes()
	var hand_before: Array = app.deck.hand.duplicate()
	var discard_before: Array = app.deck.discard_pile.duplicate()
	var draw_before: Array = app.deck.draw_pile.duplicate()
	var rng_before: int = app.run_rng.state
	var callback: Callable = presenter._bindings[panel].input
	var queued: Array = [panel, id, target, presenter._token, app.party, app.enemies,
		app.battle_result, app.run_rng, presenter._turn, app.enemies.get_enemy(target).id,
		panel.get_index(), app.deck, app.deck.hand.duplicate(), app.run_map, presenter._pinned]
	if keyboard:
		root.push_input(_key(KEY_1 if target == 1 else KEY_2), true)
		root.push_input(_key(KEY_1 if target == 1 else KEY_2), true)
		root.push_input(_key(KEY_1 if target == 1 else KEY_2, false), true)
		await _frames()
	else:
		await _mouse(app.get_node("LiveEnemyRoster")._labels[target - 1])
	var event: Dictionary = presenter.last_event
	var printed := 3 if id == IDS[0] else 4
	var expected_hits: Array[Dictionary] = []
	var victim: Dictionary = enemies_before[target - 1]
	for i in range(1, 4):
		if victim.hp <= 0:
			break
		var damage := printed + (2 if target == 1 and not lethal else 0)
		var absorbed: int = mini(victim.block, damage)
		victim.block -= absorbed
		victim.hp = maxi(0, victim.hp - damage + absorbed)
		expected_hits.append({"position": target, "hit": i, "base_damage": printed,
			"damage": damage, "block_absorbed": absorbed, "hp_loss": damage - absorbed if victim.hp > 0 else 0,
			"target_hp_after": victim.hp, "target_block_after": victim.block})
	# Exact HP loss must be clamped on lethal strikes, independently of the service.
	var hp_at_start: int = (5 if lethal else 18) if target == 1 else 23
	var hp_running: int = hp_at_start
	for hit in expected_hits:
		var actual_loss: int = mini(hp_running, int(hit.damage) - int(hit.block_absorbed))
		hit.hp_loss = actual_loss
		hp_running -= actual_loss
		hit.target_hp_after = hp_running
	_check(event.get("ok", false) and event.card_id == id and event.energy_spent == 2
		and event.hit_count == expected_hits.size() and event.hits == expected_hits,
		"paid receipt is sequential with independent hit, Block and HP oracles")
	_check(app.enemies.get_enemies() == enemies_before and app.party.get_heroes() == heroes_before,
		"original target receives exact damage; all other actors and slots unchanged")
	hand_before.erase(id)
	discard_before.append(id)
	_check(app.deck.energy == 0 and app.deck.hand == hand_before
		and app.deck.discard_pile == discard_before and app.deck.draw_pile == draw_before
		and app.run_rng.state == rng_before and app.hand_view.get_child_count() == hand_before.size()
		and not presenter._bindings.has(panel),
		"one charged/discarded copy, refreshed mounted hand, unchanged seeded RNG")
	var settled := _state()
	callback.call(_press())
	presenter._commit.callv(queued)
	presenter._queue_attack(target)
	await _frames()
	_check(_state() == settled, "old panel/duplicate press/queued replay is inert")
	await _dispose()


func _negative(mode: String, queued: bool) -> void:
	var panel := await _begin(IDS[0])
	if panel == null:
		await _dispose()
		return
	await _arm(panel, true)
	if queued:
		presenter._queue_attack(1)
		_check(presenter._queued, "valid cast queued before invalidation: " + mode)
	match mode:
		"seat":
			var swap: Dictionary = app.party._heroes[0]
			app.party._heroes[0] = app.party._heroes[1]
			app.party._heroes[1] = swap
			app.party._heroes[0].position = 1
			app.party._heroes[1].position = 2
		"downed": app.party.apply_damage(1, 999)
		"zero": app.deck.combat_state.energy = 0
		"one": app.deck.combat_state.energy = 1
		"missing": 
			app.deck.discard_played(IDS[0])
			app.deck.discard_played(IDS[0])
		"forged": panel.get_child(0).text = "rag_duelist_needle_barrage_forged"
		"slain": app.enemies.apply_damage(1, 999)
		"blind": app.party._heroes[0].statuses = {"blind_next_attack": 1}
		"dodge": app.enemies._enemies[0].statuses = {"dodge_next_attack": 1}
		"identity": app.enemies._enemies[0].id = "replacement_foe"
		"turn": app.enemy_intents.advance_turn()
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"closed": app._battle_closed = true
		"panel": app._refresh_hand()
		"hand_order": app.deck.hand.reverse()
		"rng":
			app.run_rng = RandomNumberGenerator.new()
			app.run_rng.seed = 351
	var before := _state()
	if not queued:
		await _keyboard(KEY_1)
	else:
		await _frames()
	_check(_state() == before, "full fail-closed no-spend/no-status/no-RNG: " + mode
		+ " queued=" + str(queued))
	var stable := _state()
	presenter._queue_attack(1)
	await _frames()
	_check(_state() == stable, "refused cast cannot replay: " + mode)
	await _dispose()


func _slain_slot() -> void:
	var panel := await _begin(IDS[1])
	app.enemies.apply_damage(1, 999)
	await _hover(panel)
	_check(presenter.current_forecast.get("target_positions", []) == [2],
		"pure picker omits dead original slot 1 without compacting roster")
	await _arm(panel, true)
	var before := _state()
	await _keyboard(KEY_1)
	_check(_state() == before, "dead slot keyboard shortcut rejected")
	await _keyboard(KEY_2)
	_check(presenter.last_event.get("ok", false)
		and presenter.last_event.target_position == 2 and presenter.last_event.hit_count == 3,
		"living original slot 2 remains keyboard-accessible")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id in IDS:
		for target in [1, 2]:
			for keyboard in [false, true]:
				await _success(id, target, keyboard)
	await _success(IDS[0], 1, true, true)
	for mode in ["seat", "downed", "zero", "one", "missing", "forged", "slain",
		"blind", "dodge", "identity", "turn", "session", "closed", "panel",
		"hand_order", "rng"]:
		# A replacement target ID or another still-held identical copy is legal
		# until a queue captures its original target/hand instance.
		for queued in ([true] if mode in ["identity", "hand_order"] else [false, true]):
			await _negative(mode, queued)
	await _slain_slot()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_rag_duelist_needle_barrage_hand_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
