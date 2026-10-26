extends "res://tests/live_support_hand_test.gd"

const IDS := CombatYarnRangerKnitCards.CARDS


func _begin(id: String, seat: int = 2) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 290
	_check(app._start_battle(), "mounted battle starts")
	presenter = app.get_node("LiveSupportHand")
	var rng := RandomNumberGenerator.new()
	rng.seed = 290
	var cards: Array[String] = [id, id, "warden_strike", "warden_brace", "tinker_tune_up"]
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.count(id) == 2, "two genuine drawn copies")
	app.deck.combat_state.energy = 1
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


func _arm(panel: Control, key: int) -> void:
	if key == 0:
		await _mouse(panel)
	else:
		panel.grab_focus()
		root.push_input(_key(key), true)
		root.push_input(_key(key), true)
		root.push_input(_key(key, true, true), true)
		root.push_input(_key(key, false), true)
		await _frames()


func _success(id: String, key: int, seat: int, target: int, supply: String) -> void:
	var panel := await _begin(id, seat)
	if panel == null:
		await _dispose()
		return
	var cards: Array[String] = ["warden_strike", "warden_brace", "tinker_tune_up"]
	if supply == "full":
		app.deck.draw_pile.assign(cards)
	elif supply == "reshuffle":
		app.deck.discard_pile.assign(cards)
	_check(app.deck.draw_pile.is_empty() == (supply != "full") and app.deck.hand.count(id) == 2,
		"real held copies and requested supply")
	var definition := CombatYarnRangerKnitCards.knit_definition(id)
	var meta = presenter._metadata
	meta._update_visual(panel)
	var facts: Dictionary = meta.get_facts(panel)
	_check(not definition.is_empty() and facts.known and facts.owner == "yarn_ranger" and facts.cost == 1,
		"authored owner and cost")
	_check(meta.definition(id) == definition and meta.short_line(id) == CardShortRules.line(definition)
		and meta.short_line(id).contains(str(definition.effects.block))
		and panel.tooltip_text.contains(definition.display_name) and panel.tooltip_text.contains("draw"),
		"mounted authored face, Block and draw text")
	_check(facts.from_text == "From " + meta._positions([1, 2, 3])
		and facts.display_name == definition.display_name and facts.target_text == "Ally"
		and definition.to_positions.is_empty() and panel.tooltip_text.contains("no target square is filled (any hero slot)")
		and meta.get_geometry(panel).size() > 0 and meta.visual_state(panel).playable
		and panel.self_modulate == Color.WHITE and panel.gui_input.get_connections().size() == 1,
		"any-seat pips, geometry and exactly one enabled hand entry")
	var before := _state()
	var old_callback: Callable = presenter._bindings[panel]
	await _arm(panel, key)
	_check(_state() == before and presenter._pending.get("choosing", false)
		and presenter._targets.size() == 3, "opening living-ally selection never spends")
	if presenter._targets.size() != 3:
		await _dispose()
		return
	# Independent scene-free transaction with the identical authoritative input and RNG.
	reference_rng = RandomNumberGenerator.new()
	reference_rng.seed = app.run_rng.seed
	reference = CombatDeck.new([], reference_rng)
	reference.draw_pile.assign(app.deck.draw_pile)
	reference.hand.assign(app.deck.hand)
	reference.discard_pile.assign(app.deck.discard_pile)
	reference.combat_state.energy = app.deck.energy
	reference.combat_state.player_turn_active = true
	reference_rng.state = app.run_rng.state
	reference_party = CombatParty.new(app.party.get_heroes())
	var receipt := CombatYarnRangerKnitCards.new().play_card(reference, reference_party, id, target)
	_check(receipt.get("ok", false) and receipt.drawn == (0 if supply == "empty" else 1), "oracle commits requested draw")
	var target_panel: Control = app.hero_panels[target - 1]
	var target_callback: Callable = presenter._targets[target_panel].callback
	if key == 0:
		await _mouse(target_panel)
	else:
		target_panel.grab_focus()
		await _arm(target_panel, KEY_SPACE if key == KEY_ENTER else KEY_ENTER)
	_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(reference, reference_party, reference_rng),
		"one payment, exact Block and draw-before-discard with seeded RNG")
	_check(app.deck.energy == 0 and app.deck.hand.count(id) == 1 and app.deck.discard_pile.back() == id,
		"played copy cannot be drawn back")
	for position in [1, 2, 3]:
		_check(app.party.get_hero(position).block == (definition.effects.block if position == target else 0), "only selected recipient gains Block")
	_check(presenter.energy_label.text == "0" and app.hand_view.get_child_count() == app.deck.hand.size()
		and app.pile_label.text.contains(str(app.deck.draw_pile.size()))
		and app.hero_panels[target - 1].get_child(0).text.contains("Block: %d" % definition.effects.block), "real hand and HUD refresh")
	var remaining := _panel(id)
	_check(remaining != null, "second held copy remains mounted")
	if remaining != null:
		_check(not meta.visual_state(remaining).playable and remaining.self_modulate != Color.WHITE, "remaining copy dims after energy spent")
	# Another held copy is affordable; retired source and target callbacks still cannot replay.
	app.deck.combat_state.energy = 1
	before = _state()
	old_callback.call(_press())
	target_callback.call(_press())
	await _frames()
	_check(_state() == before, "retired source and target cannot replay affordable copy")
	await _dispose()


func _reject(id: String, mode: String, stage: int) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	var callback: Callable = presenter._bindings[panel]
	var target_callback: Callable
	if stage > 0:
		await _arm(panel, KEY_ENTER)
		_check(presenter._pending.get("choosing", false) and presenter._targets.size() == 3, "negative fixture armed actual targets")
		if presenter._targets.size() != 3:
			await _dispose()
			return
		target_callback = presenter._targets[app.hero_panels[0]].callback
		if stage == 2:
			target_callback.call(_press())
			_check(presenter._pending.get("queued", false), "actual target queued before invalidation")
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"owner": app.party.apply_damage(2, 1000)
		"target": app.party.apply_damage(1, 1000)
		"missing": app.party._heroes[1].id = "seamstress"
		"absent":
			app.deck.discard_played(id)
			app.deck.discard_played(id)
		"closed": app._battle_closed = true
		"inactive": app.deck.combat_state.player_turn_active = false
		"turn": app.enemy_intents.advance_turn()
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"label": panel.get_child(0).text = "yarn_ranger_forged"
		"index": app.hand_view.move_child(panel, 4)
		"roster": app.party._heroes[0].block = -1
		"overflow":
			for hero in app.party._heroes:
				hero.block = CombatParty.MAX_INT
		"rebuild": app._refresh_hand()
		"cancel": presenter.cancel_button.pressed.emit()
		"escape": root.push_input(_key(KEY_ESCAPE), true)
	var before := _state()
	if stage == 0:
		callback.call(_press())
	elif stage == 1:
		target_callback.call(_press())
	await _frames()
	_check(_state() == before and presenter._pending.is_empty(), "no-spend snapshot: %s stage %d" % [mode, stage])
	if mode not in ["target", "cancel", "escape", "rebuild"]:
		if presenter._metadata._bindings.has(panel):
			presenter._metadata._update_visual(panel)
			_check(not presenter._metadata.visual_state(panel).playable and panel.self_modulate != Color.WHITE, "unavailable face disabled: " + mode)
		else:
			_check(not presenter._eligible(panel, id, app.deck, app.party, app.battle_view), "retired identity cannot play: " + mode)
	await _dispose()


func _stale(id: String) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	var callback: Callable = presenter._bindings[panel]
	await _arm(panel, KEY_SPACE)
	_check(presenter._targets.size() == 3, "stale fixture has living targets")
	var target_callback: Callable = presenter._targets[app.hero_panels[0]].callback
	var deck: CombatDeck = app.deck
	var party: CombatParty = app.party
	var rng: RandomNumberGenerator = app.run_rng
	var before := _snapshot(deck, party, rng)
	target_callback.call(_press())
	app.return_button.pressed.emit()
	await _frames()
	callback.call(_press())
	target_callback.call(_press())
	_check(_snapshot(deck, party, rng) == before, "closed battle cancels queued commit and old callbacks")
	_check(app._start_battle(), "replacement battle starts")
	await _frames()
	before = _state()
	callback.call(_press())
	target_callback.call(_press())
	await _frames()
	_check(_state() == before, "old callbacks cannot affect replacement battle")
	await _dispose()


func _living_targets(id: String) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	_check(app.party.apply_damage(1, 1000) and app.party.is_downed(1), "real downed other ally")
	app._refresh_party()
	var before := _state()
	await _arm(panel, KEY_SPACE)
	_check(_state() == before and presenter._targets.size() == 2
		and not presenter._targets.has(app.hero_panels[0])
		and presenter._targets.has(app.hero_panels[1]) and presenter._targets.has(app.hero_panels[2]),
		"picker excludes downed ally and retains self and living other ally without spending")
	await _keyboard(KEY_ESCAPE)
	_check(_state() == before and presenter._pending.is_empty(), "cancel preserves downed fixture")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id: String in IDS:
		for seat in [1, 2, 3]:
			for key in [0, KEY_ENTER, KEY_SPACE]:
				for target in [seat, seat % 3 + 1]:
					for supply in ["full", "empty", "reshuffle"]:
						await _success(id, key, seat, target, supply)
		for mode in ["energy", "owner", "missing", "absent", "closed", "inactive", "turn", "session", "label", "index", "roster", "overflow", "rebuild"]:
			for stage in [0, 1, 2]:
				await _reject(id, mode, stage)
		for mode in ["target", "cancel", "escape"]:
			for stage in [1, 2]:
				await _reject(id, mode, stage)
		await _stale(id)
		await _living_targets(id)
	for failure in failures:
		printerr("FAIL: " + failure)
	print("live_yarn_ranger_knit_hand_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


