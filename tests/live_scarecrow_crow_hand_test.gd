extends "res://tests/live_support_hand_test.gd"
## Actual scene-mounted area action, using the shared physical input harness.

const IDS := ["scarecrow_crow_dive", "scarecrow_crow_dive_plus",
	"scarecrow_crow_peck", "scarecrow_crow_peck_plus"]


func _begin(id: String, seat: int = 2, rear_alive: bool = false) -> Control:
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
	heroes.insert(seat - 1, {"id": "scarecrow", "name": "Scarecrow", "max_hp": 30, "statuses": {"weak": 1}})
	app.party = CombatParty.new(heroes)
	app.enemies = CombatEnemies.new([
		{"id": "tangled", "max_hp": 50, "statuses": {"tangled": 2, "exposed": 1}},
		{"id": "untangled", "max_hp": 50, "statuses": {"bleed": 2}},
		{"id": "slain", "max_hp": 50, "statuses": {"tangled": 3}}])
	_check(app.party.is_valid() and app.enemies.is_valid(), "real valid rosters")
	_check(app.enemies.gain_block(2, 20), "back survivor has Block")
	if rear_alive:
		_check(app.enemies.gain_block(3, 20), "living rear has Block")
		app.party._heroes[seat - 1].statuses.clear()
		app.enemies._enemies[2].statuses.clear()
	else:
		_check(app.enemies.apply_damage(3, 50), "rear is slain")
	_check(app.party.get_hero(seat).id == "scarecrow" and app.enemies.get_enemy(2).block == 20,
		"non-vacuous owner seat and real Block preconditions")
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


func _success(id: String, keyboard: bool, seat: int, rear_alive: bool) -> void:
	var panel := await _begin(id, seat, rear_alive)
	if panel == null:
		await _dispose()
		return
	var meta = app.get_node("LiveSupportHand")._metadata
	var facts: Dictionary = meta.get_facts(panel)
	var face: Dictionary = presenter.face_text(panel)
	var definition: Dictionary = CombatScarecrowCrowCards.new()._catalog_definition(id)
	_check(not definition.is_empty() and facts.known and facts.owner == "scarecrow"
		and facts.owner_text == "Scarecrow" and facts.cost == 1, "authentic metadata face")
	_check(meta.definition(id) == definition and presenter._definition(id) == definition, "exact separate catalog")
	var rule := "Deal %d to backmost living enemy; bypass Block." % definition.effects.damage
	_check(face.owner == "Scarecrow" and face.cost == "1 energy" and face.effect == rule
		and meta.short_line(id) == rule and face.from_pips == [true, true, true]
		and face.to_pips == [true, true, true] and not face.thread, "mounted precise face and pips")
	var tooltip: String = meta.base_effect_text(id)
	_check(not presenter.face_children(panel).is_empty() and panel.tooltip_text.contains("backmost living enemy only")
		and panel.tooltip_text.contains("bypass Block") and panel.tooltip_text.contains("From 1,2,3")
		and panel.tooltip_text.contains(CombatScarecrowCrowCards.CARDS[id].catalog + " catalog")
		and tooltip.contains("BASE deal %d damage" % definition.effects.damage)
		and tooltip.contains("1 energy") and tooltip.contains("Block remains"), "mounted full tooltip")
	_check(meta.visual_state(panel).playable and panel.gui_input.get_connections().size() == 1, "single enabled hand entry")
	var expected := _state().duplicate(true)
	var snapshot: Array = expected[0][0]
	snapshot[1].erase(id)
	snapshot[2].append(id)
	snapshot[3] -= 1
	# Rear slot is slain, so slot 2 is now backmost. Weak floors; Block is bypassed.
	var base: int = definition.effects.damage
	var damage := base if rear_alive else int(floor(base * 0.75))
	var target := 3 if rear_alive else 2
	expected[0][5][target - 1].hp -= damage
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
	_check(presenter.last_event.get("ok", false) and presenter.last_event.target_position == target
		and presenter.last_event.damage == damage and presenter.last_event.block_after == 20, "resolver event forwarded")
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
		"targets":
			for enemy in app.enemies._enemies:
				enemy.hp = 0
		"energy": app.deck.combat_state.energy = 0
		"missing": app.party._heroes[1].id = "seamstress"
		"downed": app.party.apply_damage(2, 1000)
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
		"owner_status": app.party._heroes[1].statuses = []
		"hidden": panel.hide()
	if mode == "targets":
		_check(not presenter._crow_preflight(id).get("ok", false)
			and not presenter._eligible(panel, id), "all-slain roster refuses before result closure")
	# Settle the HUD's legitimate response to the changed fixture before input.
	app._refresh_intents()
	if mode != "rebuild":
		var meta = app.get_node("LiveSupportHand")._metadata
		meta._update_visual(panel)
		_check(not meta.visual_state(panel).playable, "unavailable face: " + mode)
	if mode == "targets":
		app._observe_battle_result()
	var before := _state()
	callback.call(_press())
	await _frames()
	_check(_state() == before, "full no-spend snapshot: " + mode)
	await _dispose()


func _terminal_and_stale(id: String) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	_check(app.enemies.apply_damage(2, 100) and app.enemies.apply_damage(1, 49), "last living Tangled enemy at lethal HP after Block")
	# The final living enemy has one HP.
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


func _retarget_at_commit(id: String) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	panel.grab_focus()
	root.push_input(_key(KEY_ENTER), true)
	_check(not presenter._pending.is_empty(), "real input queued before rear death")
	_check(app.enemies.apply_damage(2, 100), "rear survivor slain while queued")
	var expected := _state().duplicate(true)
	expected[0][0][1].erase(id)
	expected[0][0][2].append(id)
	expected[0][0][3] -= 1
	var base: int = CombatScarecrowCrowCards.CARDS[id].damage
	var damage := int(floor(base * 9.0 / 8.0)) + 2
	expected[0][5][0].hp -= damage
	app._refresh_intents()
	# Refresh publishes the legitimately changed intent text.
	expected[0][2] = app.enemy_intents.get_intents()
	expected[0][3] = app.intent_label.text
	await _frames()
	_check(_state() == expected and presenter.last_event.get("target_position") == 1
		and presenter.last_event.get("damage") == damage, "commit retargets next survivor with Weak/Exposed/Tangled")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id: String in IDS:
		for keyboard in [false, true]:
			for seat in [1, 2, 3]:
				for rear_alive in [false, true]:
					await _success(id, keyboard, seat, rear_alive)
		for mode in ["targets", "energy", "missing", "downed", "absent", "closed", "turn", "label", "rebuild", "session", "inactive", "status", "owner_status", "hidden"]:
			for queued in [false, true]:
				await _refusal(id, mode, queued)
		await _retarget_at_commit(id)
		await _terminal_and_stale(id)
	var meta = preload("res://scripts/live_hand_card_metadata.gd").new()
	for catalog in [ScarecrowStarterCards.new(), ScarecrowPoolCards.new()]:
		for id in catalog.get_all_card_ids():
			if id in CombatSupportCards.SCARECROW_STRAW_IDS:
				_check(meta.definition(id) == catalog.get_definition(id), "straw face retains exact canonical catalog")
			elif CombatScarecrowPitchforkCards.CARDS.has(id):
				_check(meta.definition(id) == catalog.get_definition(id), "pitchfork face retains exact canonical catalog")
			elif id not in IDS and id not in ["scarecrow_re_stuff", "scarecrow_re_stuff_plus"]:
				_check(meta.definition(id).is_empty(), "unrelated Scarecrow IDs remain unwired")
	for failure in failures:
		printerr("FAIL: " + failure)
	print("live_scarecrow_crow_hand_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
