extends "res://tests/live_support_hand_test.gd"
## Actual scene-mounted area action, using the shared physical input harness.

const IDS := ["yarn_ranger_unspool", "yarn_ranger_unspool_plus"]


func _begin(id: String, seat: int = 2) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 290
	_check(app._start_battle(), "mounted battle starts")
	presenter = app.get_node("LiveAreaAttackAction")
	var rng := RandomNumberGenerator.new()
	rng.seed = 290
	var cards: Array[String] = [id, id, "warden_strike", "warden_brace", "tinker_tune_up"]
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.count(id) == 2, "two genuine drawn copies")
	app.deck.combat_state.energy = 6
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 25}]
	heroes.insert(seat - 1, {"id": "yarn_ranger", "name": "Yarn Ranger", "max_hp": 30, "statuses": {"weak": 1}})
	app.party = CombatParty.new(heroes)
	app.enemies = CombatEnemies.new([
		{"id": "tangled", "max_hp": 50, "statuses": {"tangled": 2, "exposed": 1}},
		{"id": "untangled", "max_hp": 50, "statuses": {"bleed": 2}},
		{"id": "slain", "max_hp": 50, "statuses": {"tangled": 3}}])
	_check(app.party.is_valid() and app.enemies.is_valid(), "real valid rosters")
	_check(app.enemies.gain_block(1, 3) and app.enemies.apply_damage(3, 50), "Block and slain Tangled fixture")
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies, app.enemy_intents, app.battle_result)
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_hand()
	await _frames()
	var panel := _panel(id)
	_check(panel != null and panel.is_visible_in_tree() and presenter._bindings.has(panel), "authentic panel bound by mounted adapter")
	return panel


func _state() -> Array:
	return [_live(), app.battle_result.get_outcome(), app._battle_closed]


func _dispose() -> void:
	app.free()
	await _frames()


func _success(id: String, keyboard: bool, seat: int) -> void:
	var panel := await _begin(id, seat)
	if panel == null:
		await _dispose()
		return
	var meta = app.get_node("LiveSupportHand")._metadata
	var facts: Dictionary = meta.get_facts(panel)
	var face: Dictionary = presenter.face_text(panel)
	_check(facts.known and facts.owner == "yarn_ranger" and facts.owner_text == "Yarn Ranger" and facts.cost == 2, "authentic metadata face")
	_check(face.owner == "Yarn Ranger" and face.cost == "2 energy" and face.effect.contains("living Tangled enemies only")
		and face.from_pips == [false, true, true] and face.to_pips == [true, true, true] and face.thread, "mounted conditional cue and pips")
	_check(not presenter.face_children(panel).is_empty() and panel.tooltip_text.contains("Tangled")
		and panel.tooltip_text.contains("Yarn Ranger") and panel.tooltip_text.contains("2 energy"), "visible children and full tooltip")
	_check(meta.visual_state(panel).playable and panel.gui_input.get_connections().size() == 1, "single enabled hand entry")
	var expected := _state().duplicate(true)
	var snapshot: Array = expected[0][0]
	snapshot[1].erase(id)
	snapshot[2].append(id)
	snapshot[3] -= 2
	# Combined Weak/Exposed floors once, then Tangled adds 2 before Block.
	var base := 10 if id.ends_with("_plus") else 7
	var damage := int(floor(base * 9.0 / 8.0)) + 2
	expected[0][5][0].hp -= damage - 3
	expected[0][5][0].block = 0
	var callback: Callable = presenter._bindings[panel].callback
	if keyboard:
		panel.grab_focus()
		root.push_input(_key(KEY_ENTER), true)
		root.push_input(_key(KEY_ENTER), true)
		root.push_input(_key(KEY_ENTER, false), true)
		await _frames()
	else:
		await _mouse(panel)
	_check(_state() == expected, "exact full state: one payment/discard, adjusted hit, untouched statuses/other slots/intents/RNG")
	_check(presenter.last_event.get("ok", false) and presenter.last_event.hits.size() == 1
		and presenter.last_event.hits[0].position == 1 and presenter.last_event.hits[0].damage == damage, "resolver event forwarded")
	callback.call(_press())
	await _frames()
	_check(_state() == expected and app.deck.hand.count(id) == 1, "retired listener cannot spend affordable remaining copy")
	await _dispose()


func _refusal(id: String, mode: String, queued: bool) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	var callback: Callable = presenter._bindings[panel].callback
	if queued:
		panel.grab_focus()
		root.push_input(_key(KEY_ENTER), true)
		_check(not presenter._pending.is_empty(), "actual input queued before invalidation")
	match mode:
		"targets": app.enemies._enemies[0].statuses.erase("tangled")
		"energy": app.deck.combat_state.energy = 1
		"missing": app.party._heroes[1].id = "seamstress"
		"downed": app.party.apply_damage(2, 1000)
		"position":
			var heroes: Array = app.party.get_heroes()
			var first = heroes[0]
			heroes[0] = heroes[1]
			heroes[1] = first
			app.party._heroes = CombatParty.new(heroes).get_heroes()
			_check(app.party.get_hero(1).id == "yarn_ranger", "valid front-seat owner")
		"absent":
			app.deck.discard_played(id)
			app.deck.discard_played(id)
		"closed": app._battle_closed = true
		"turn": app.enemy_intents.advance_turn()
		"label": panel.get_child(0).text = IDS[1] if id == IDS[0] else IDS[0]
		"rebuild": app._refresh_hand()
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"inactive": app.deck.combat_state.player_turn_active = false
		"status": app.enemies._enemies[0].statuses.exposed = "bad"
	# Settle the HUD's legitimate response to the changed fixture before input.
	app._refresh_intents()
	var before := _state()
	if mode != "rebuild":
		var meta = app.get_node("LiveSupportHand")._metadata
		meta._update_visual(panel)
		_check(not meta.visual_state(panel).playable, "unavailable face: " + mode)
	callback.call(_press())
	await _frames()
	_check(_state() == before, "full no-spend snapshot: " + mode)
	await _dispose()


func _terminal_and_stale(id: String) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	_check(app.enemies.apply_damage(2, 50) and app.enemies.apply_damage(1, 49), "last living Tangled enemy at lethal HP after Block")
	# Damage first absorbed 3 Block, leaving four HP: still a lethal authored hit.
	var oracle := RandomNumberGenerator.new()
	oracle.seed = app.run_rng.seed
	oracle.state = app.run_rng.state
	var gold := oracle.randi_range(10, 20)
	await _mouse(panel)
	_check(presenter.last_event.get("ok", false) and app.enemies.is_victorious()
		and app.battle_result.get_outcome() == CombatBattleResult.VICTORY
		and not app.deck.turn_active and app.end_turn_button.disabled, "real result observer closes final cast")
	_check(app.session_gold == gold and app.run_rng.state == oracle.state, "only existing victory reward consumes RNG")
	await _dispose()
	panel = await _begin(id)
	if panel == null:
		await _dispose()
		return
	var callback: Callable = presenter._bindings[panel].callback
	var old_deck: CombatDeck = app.deck
	var old_party: CombatParty = app.party
	var old_enemies: CombatEnemies = app.enemies
	var old_rng: RandomNumberGenerator = app.run_rng
	var before := [_snapshot(old_deck, old_party, old_rng), old_enemies.get_enemies()]
	panel.grab_focus()
	root.push_input(_key(KEY_ENTER), true)
	_check(not presenter._pending.is_empty(), "cast queued before leaving battle")
	app.return_button.pressed.emit()
	callback.call(_press())
	await _frames()
	_check([_snapshot(old_deck, old_party, old_rng), old_enemies.get_enemies()] == before,
		"closed battle and queued retired callback preserve old authorities")
	_check(app._start_battle(), "replacement real battle starts")
	await _frames()
	var fresh := _state()
	callback.call(_press())
	await _frames()
	_check(_state() == fresh, "stale panel cannot mutate replacement battle")
	await _dispose()


func _multiple(id: String) -> void:
	var panel := await _begin(id, 3)
	if panel == null:
		await _dispose()
		return
	app.enemies._enemies[1].statuses["tangled"] = 1
	_check(app.enemies.gain_block(2, 2), "second living Tangled target has Block")
	app._refresh_intents()
	var expected := _state().duplicate(true)
	expected[0][0][1].erase(id)
	expected[0][0][2].append(id)
	expected[0][0][3] -= 2
	var base := 10 if id.ends_with("_plus") else 7
	expected[0][5][0].hp -= int(floor(base * 9.0 / 8.0)) + 2 - 3
	expected[0][5][0].block = 0
	expected[0][5][1].hp -= int(floor(base * 0.75)) + 2 - 2
	expected[0][5][1].block = 0
	await _mouse(panel)
	_check(_state() == expected and presenter.last_event.hits.size() == 2
		and presenter.last_event.hits[0].position == 1 and presenter.last_event.hits[1].position == 2,
		"each living Tangled slot hit once in order with independent modifiers; slain slot unchanged")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id: String in IDS:
		for keyboard in [false, true]:
			for seat in [2, 3]:
				await _success(id, keyboard, seat)
		for mode in ["targets", "energy", "missing", "downed", "position", "absent", "closed", "turn", "label", "rebuild", "session", "inactive", "status"]:
			for queued in [false, true]:
				await _refusal(id, mode, queued)
		await _multiple(id)
		await _terminal_and_stale(id)
	var meta = preload("res://scripts/live_hand_card_metadata.gd").new()
	for id in YarnRangerPoolCards.new().get_all_card_ids():
		if CombatYarnRangerKnitCards.CARDS.has(id):
			_check(meta.definition(id) == CombatYarnRangerKnitCards.knit_definition(id), "knit IDs use authentic definitions")
		elif id not in IDS and id not in ["yarn_ranger_snare_net", "yarn_ranger_snare_net_plus"]:
			_check(meta.definition(id).is_empty(), "unrelated Yarn IDs remain unwired")
	for failure in failures:
		printerr("FAIL: " + failure)
	print("live_yarn_ranger_unspool_hand_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
