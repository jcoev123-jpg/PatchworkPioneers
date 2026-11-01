extends "res://tests/live_support_hand_test.gd"
## Mounted hand admission for the existing paid Needle Prick resolver.

const IDS := ["rag_duelist_needle_prick", "rag_duelist_needle_prick_plus"]
const DAMAGE := [4, 6]
const BLEED := [2, 3]


func _begin(id: String, seat: int = 2, blocked: bool = false) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 384
	_check(app._start_battle(), "actual battle opens")
	presenter = app.get_node("LiveAttackPreview")
	var rng := RandomNumberGenerator.new()
	rng.seed = 384
	var cards: Array[String] = [id, id, "warden_strike", "warden_brace", "tinker_tune_up"]
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.count(id) == 2,
		"two real drawn copies of the tested printing")
	app.deck.combat_state.energy = 1
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40}, {"id": "tinker", "name": "Tinker", "max_hp": 25}]
	heroes.insert(seat - 1, {"id": "rag_duelist", "name": "Rag Duelist", "max_hp": 30})
	app.party = CombatParty.new(heroes)
	app.enemies = CombatEnemies.new([
		{"id": "front", "max_hp": 40, "statuses": {"bleed": 1}},
		{"id": "middle", "max_hp": 40, "statuses": {"bleed": 2}},
		{"id": "back", "max_hp": 40, "statuses": {"exposed": 1}}])
	_check(app.party.is_valid() and app.enemies.is_valid() and app.party.get_hero(seat).id == "rag_duelist",
		"non-vacuous living rosters and actual owner's seat")
	if blocked:
		_check(app.enemies.gain_block(2, 15) and app.enemies.get_enemy(2).block == 15,
			"real target has enough Block to soak the full strike")
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
		and presenter._bindings.has(panel), "real held panel wired to mounted presenter")
	return panel


func _dispose() -> void:
	app.free()
	await _frames()


func _state() -> Array:
	return [_snapshot(app.deck, app.party, app.run_rng), app.enemies.get_enemies(),
		app.battle_result.get_outcome(), presenter.last_event.duplicate(true)]


func _arm(panel: Control, keyboard: bool) -> void:
	if keyboard:
		await _keyboard(KEY_ESCAPE)
		for attempt in range(app.deck.hand.size()):
			await _keyboard(KEY_P)
			if presenter._armed == panel:
				break
	else:
		await _mouse(panel)
	_check(presenter._armed == panel, "actual original panel armed")


func _success(id: String, seat: int, target: int, keyboard: bool, blocked: bool) -> void:
	var panel := await _begin(id, seat, blocked)
	if panel == null:
		await _dispose()
		return
	var index := IDS.find(id)
	var damage: int = DAMAGE[index]
	var added: int = BLEED[index]
	var definition: Dictionary = presenter._definition(id)
	_check(definition == presenter._prick._catalog_definition(id)
		and definition.get("cost") == 1 and definition.get("owner") == "rag_duelist"
		and app.deck.hand.has(id), "authentic held definition and printed cost")
	var before := _state()
	await _hover(panel)
	var quote: Dictionary = presenter.current_forecast.duplicate(true)
	_check(quote.get("playable", false) and quote.get("requires_selection", false)
		and quote.get("target_positions", []) == [1, 2]
		and quote.get("hits", []).size() == 2
		and presenter.cue.text.contains("1 energy")
		and presenter.cue.text.contains("Bleed")
		and presenter.cue.text.contains("damage"),
		"mounted hover displays original legal targets, energy, hit and post-hit Bleed")
	if quote.get("hits", []).size() == 2:
		_check(quote.hits[target - 1].damage == damage
			and quote.hits[target - 1].base_damage == damage
			and quote.hits[target - 1].bleed_applied == added
			and quote.hits[target - 1].bleed_before == target
			and quote.hits[target - 1].bleed_after == target + added,
			"independent printed damage and additive Bleed oracle for chosen slot")
	_check(_state() == before, "hover mutates nothing, including RNG")
	await _arm(panel, keyboard)
	_check(_state() == before, "selection is read-only")
	await _keyboard(KEY_3)
	_check(_state() == before and presenter._armed == panel, "illegal original enemy slot 3 refused")
	var heroes_before: Array = app.party.get_heroes()
	var enemies_before: Array = app.enemies.get_enemies()
	var hand: Array = app.deck.hand.duplicate()
	var discard: Array = app.deck.discard_pile.duplicate()
	var draw: Array = app.deck.draw_pile.duplicate()
	var rng_state: int = app.run_rng.state
	var callback: Callable = presenter._bindings[panel].input
	var replay_args: Array = [panel, id, target, presenter._token, app.party, app.enemies,
		app.battle_result, app.run_rng, presenter._turn, app.enemies.get_enemy(target).id,
		panel.get_index(), app.deck, app.deck.hand.duplicate(), app.run_map,
		presenter._pinned, presenter._unravel]
	if keyboard:
		await _keyboard(KEY_1 if target == 1 else KEY_2)
	else:
		await _mouse(app.get_node("LiveEnemyRoster")._labels[target - 1])
	var receipt: Dictionary = presenter.last_event
	var absorbed := mini(int(enemies_before[target - 1].block), damage)
	var loss: int = damage - absorbed
	_check(receipt.get("ok", false) and receipt.get("card_id") == id
		and receipt.get("cost") == 1 and receipt.get("target_position") == target
		and receipt.get("owner_position") == seat and receipt.get("damage") == damage
		and receipt.get("base_damage") == damage and receipt.get("bleed_applied") == added
		and receipt.get("block_absorbed") == absorbed and receipt.get("hp_loss") == loss
		and receipt.get("hits", []).size() == 1
		and receipt.hits[0].get("hp_loss") == loss,
		"one genuine paid receipt with one confirmed observer hit")
	var victim: Dictionary = enemies_before[target - 1]
	victim.block -= absorbed
	victim.hp -= loss
	victim.statuses["bleed"] = int(victim.statuses["bleed"]) + added
	hand.erase(id)
	discard.append(id)
	_check(app.enemies.get_enemies() == enemies_before
		and app.party.get_heroes() == heroes_before,
		"exact Block, HP, and Bleed delta on one target, all other actors untouched")
	_check(app.deck.energy == 0 and app.deck.hand == hand
		and app.deck.discard_pile == discard and app.deck.draw_pile == draw
		and app.run_rng.state == rng_state,
		"one energy and exactly one discard, no preview or cast RNG")
	_check(app.get_node("LiveSupportHand").energy_label.text == "0"
		and app.pile_label.text == "Draw: %d | Discard: %d" % [draw.size(), discard.size()]
		and _pool_panel(id) != null, "genuine hand/piles/energy HUD refresh")
	var settled := _state()
	callback.call(_press())
	presenter._commit.callv(replay_args)
	presenter._queue_attack(target)
	await _frames()
	_check(_state() == settled and presenter._armed == null,
		"retired panel, stale callback and repeated target cannot replay")
	await _dispose()


func _refuse(mode: String, queued: bool) -> void:
	var panel := await _begin(IDS[0], 3 if mode == "seat" else 2)
	if panel == null:
		await _dispose()
		return
	if mode != "seat":
		await _arm(panel, true)
	if queued and mode not in ["seat", "bad_slot"]:
		presenter._queue_attack(1)
		_check(presenter._queued, "genuine pending deferred target exists: " + mode)
	match mode:
		"seat": pass
		"downed": app.party.apply_damage(2, 999)
		"energy": app.deck.combat_state.energy = 0
		"dead": app.enemies.apply_damage(1, 999)
		"overflow": app.enemies._enemies[0].statuses["bleed"] = CombatStatuses.MAX_INT
		"bad_slot": pass
		"owner": app.party._heroes[1].id = "other"
		"hand":
			app.deck.discard_played(IDS[0])
			app.deck.discard_played(IDS[0])
		"hand_order": app.deck.hand.reverse()
		"target_id": app.enemies._enemies[0].id = "replacement"
		"target_missing":
			app.enemies = CombatEnemies.new([{"id": "remaining", "max_hp": 40}])
			app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"party": app.party = CombatParty.new([{"id": "warden", "max_hp": 30},
			{"id": "rag_duelist", "name": "Rag Duelist", "max_hp": 30}])
		"turn": app.enemy_intents.advance_turn()
		"closed": app._battle_closed = true
		"hidden": app.battle_view.hide()
		"inactive": app.deck.combat_state.player_turn_active = false
		"rng":
			app.run_rng = RandomNumberGenerator.new()
			app.run_rng.seed = 385
		"deck":
			app.deck = CombatDeck.new([IDS[0]], app.run_rng)
			app.deck.start_turn()
		"panel": app._refresh_hand()
		"label": panel.get_child(0).text = IDS[1]
		"cancel": await _keyboard(KEY_ESCAPE)
	var before := _state()
	if mode == "bad_slot":
		presenter._queue_attack(0)
		presenter._queue_attack(3)
	elif mode == "seat":
		await _mouse(panel)
		await _keyboard(KEY_1)
	elif not queued and mode != "target_id":
		await _keyboard(KEY_1)
	await _frames()
	_check(_state() == before, "no spend, strike, Bleed, event or RNG on " + mode
		+ " queued=" + str(queued))
	if mode == "bad_slot":
		await _keyboard(KEY_ESCAPE)
	var settled := _state()
	presenter._queue_attack(1)
	await _frames()
	_check(_state() == settled, "invalid or stale selection cannot activate later " + mode)
	await _dispose()


func _slain_slot() -> void:
	var panel := await _begin(IDS[1], 1)
	if panel == null:
		await _dispose()
		return
	app.enemies.apply_damage(1, 999)
	await _hover(panel)
	_check(presenter.current_forecast.get("target_positions", []) == [2],
		"slain original front slot is omitted, live slot two is retained")
	await _arm(panel, true)
	var before := _state()
	await _keyboard(KEY_1)
	_check(_state() == before, "dead original target is inert")
	await _keyboard(KEY_2)
	_check(presenter.last_event.get("ok", false)
		and presenter.last_event.get("target_position") == 2
		and app.enemies.get_enemy(2).statuses.get("bleed") == 5,
		"remaining original slot accepts exactly upgraded Bleed")
	await _dispose()


func _status_modifiers() -> void:
	var panel := await _begin(IDS[0], 1)
	if panel == null:
		await _dispose()
		return
	app.party._heroes[0].statuses = {"weak": 1, "dodge_next_attack": 1}
	app.enemies._enemies[1].statuses = {"bleed": 2, "exposed": 1,
		"tangled": 1, "cannot_buff_next_turn": true}
	var before := _state()
	await _hover(panel)
	var forecast: Dictionary = presenter.current_forecast
	# Raw 4 * Weak .75 * Exposed 1.5, floor once, then Tangled +2.
	_check(forecast.get("playable", false) and forecast.hits[1].damage == 6
		and forecast.hits[1].bleed_after == 4,
		"status-adjusted live forecast uses one shared rounding and exact Bleed")
	_check(_state() == before, "status forecast retains all statuses and RNG")
	await _arm(panel, true)
	await _keyboard(KEY_2)
	_check(presenter.last_event.get("ok", false) and presenter.last_event.damage == 6
		and presenter.last_event.bleed_after == 4
		and app.enemies.get_enemy(2).hp == 34
		and app.enemies.get_enemy(2).statuses == {
			"bleed": 4, "exposed": 1, "tangled": 1, "cannot_buff_next_turn": true}
		and app.party.get_hero(1).statuses == {"weak": 1, "dodge_next_attack": 1}
		and app.run_rng.state == before[0][7],
		"paid mounted hit preserves valid non-damage statuses and RNG")
	await _dispose()


func _terminal_hit() -> void:
	var panel := await _begin(IDS[0], 1)
	if panel == null:
		await _dispose()
		return
	_check(app.enemies.apply_damage(2, 999)
		and app.enemies.apply_damage(3, 999)
		and app.enemies.apply_damage(1, 36)
		and app.enemies.get_enemy(1).hp == 4
		and app.battle_result.get_outcome() == CombatBattleResult.ACTIVE,
		"real single surviving foe has exactly lethal HP before cast")
	app._refresh_enemy_roster()
	await _hover(panel)
	_check(presenter.current_forecast.get("target_positions", []) == [1],
		"lethal forecast retains only original surviving target")
	await _arm(panel, false)
	await _keyboard(KEY_1)
	_check(app.enemies.is_victorious()
		and app.battle_result.get_outcome() == CombatBattleResult.VICTORY
		and presenter.last_event.get("ok", false)
		and presenter.last_event.get("hp_loss") == 4
		and app.deck.energy == 0,
		"mounted lethal commit observes terminal victory after one paid hit")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id in IDS:
		for seat in [1, 2]:
			for target in [1, 2]:
				for keyboard in [false, true]:
					await _success(id, seat, target, keyboard, target == 2)
	for mode in ["seat", "downed", "energy", "dead", "overflow", "bad_slot",
		"owner", "hand", "hand_order", "target_id", "target_missing", "session",
		"party", "turn", "closed", "hidden", "inactive", "rng", "deck", "panel", "label", "cancel"]:
		for queued in [false, true]:
			if mode == "target_id" and not queued:
				continue # Changing identity before choosing a target is a new legal target.
			await _refuse(mode, queued)
	await _slain_slot()
	await _status_modifiers()
	await _terminal_hit()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_rag_duelist_needle_prick_hand_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
