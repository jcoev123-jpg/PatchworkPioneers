extends "res://tests/live_support_hand_test.gd"

const IDS := ["lantern_monk_vigil_ring", "lantern_monk_vigil_ring_plus"]


func _begin(id: String, seat: int = 2) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 307
	_check(app._start_battle(), "legitimate seeded battle starts")
	presenter = app.get_node("LiveSupportHand")
	var rng := RandomNumberGenerator.new()
	rng.seed = 307
	var cards: Array[String] = [id, id, "warden_strike", "warden_brace", "tinker_tune_up"]
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.count(id) == 2, "two authentic held copies")
	app.deck.combat_state.energy = 6
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 25}]
	heroes.insert(seat - 1, {"id": "lantern_monk", "name": "Lantern Monk", "max_hp": 30})
	app.party = CombatParty.new(heroes)
	_check(app.party.is_valid() and app.enemies.is_valid(), "valid real battle rosters")
	for slot in [1, 2, 3]:
		_check(app.party.apply_damage(slot, 2 if slot == seat else 12), "wounded living fixture")
		app.party._heroes[slot - 1].statuses = {"bleed": 2, "weak": 1, "exposed": 3}
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies, app.enemy_intents, app.battle_result)
	app._refresh_party()
	app._refresh_hand()
	await _frames()
	var panel := _pool_panel(id)
	_check(panel != null and panel.is_visible_in_tree() and presenter._bindings.has(panel), "mounted bound Vigil panel")
	return panel


func _dispose() -> void:
	app.free()
	await _frames()


func _success(id: String, seat: int, keyboard: bool, torn: bool) -> Array:
	var panel := await _begin(id, seat)
	if panel == null:
		await _dispose()
		return []
	if torn:
		_check(app.party.apply_damage(1, 999) and app.party.is_downed(1), "Torn recipient established")
		app._refresh_party()
	var meta = presenter._metadata
	var definition := LanternMonkPoolCards.new().get_definition(id)
	_check(not definition.is_empty() and definition.target_kind == "party_all"
		and definition.effects == {"heal_all": 4 if id == IDS[0] else 6, "block_all": 4 if id == IDS[0] else 6},
		"authentic printing amounts")
	var facts: Dictionary = meta.get_facts(panel)
	_check(facts.known and facts.owner == "lantern_monk" and facts.owner_text == "Lantern Monk"
		and facts.cost == 2 and meta.definition(id) == definition
		and facts.from_text == "From " + meta._positions([2, 3])
		and facts.target_text == "All living heroes" and meta.visual_state(panel).playable,
		"honest owner, cost, seats, party target and enabled face")
	_check(meta.short_line(id) == "Each living hero: heal %d HP; gain %d Block." % [definition.effects.heal_all, definition.effects.block_all]
		and panel.tooltip_text.contains("capped at max HP") and panel.tooltip_text.contains("no debuffs are removed"),
		"printed heal/Block and no-cleanse tooltip")
	for held in app.hand_view.get_children():
		if held.get_child(0).text == id:
			_check(held.gui_input.get_connections().size() == 1 and presenter._bindings.has(held), "one callback per copy")
	var callback: Callable = presenter._bindings[panel]
	var before := _pool_state()
	presenter._sync_battle()
	_check(_pool_panel(id) == panel and presenter._bindings[panel] == callback
		and _pool_state() == before, "presentation refresh preserves panel, callback and complete state")
	var expected := before.duplicate(true)
	expected[1].erase(id)
	expected[2].append(id)
	expected[3] -= 2
	for hero in expected[5]:
		if hero.hp > 0:
			hero.hp = mini(hero.max_hp, hero.hp + int(definition.effects.heal_all))
			hero.block += int(definition.effects.block_all)
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_SPACE)
	else:
		await _mouse(panel)
	_check(_pool_state() == expected, "exact party-only effects, one copy, two energy, unchanged enemies/statuses/RNG")
	_check(presenter._pending.is_empty() and presenter._targets.is_empty()
		and app.end_turn_button.has_focus(), "target-free commit consumes receipt and restores focus")
	_check(presenter.energy_label.text == str(app.deck.energy)
		and app.pile_label.text.contains("Discard: %d" % app.deck.discard_pile.size()), "real energy and pile HUD refreshed")
	for slot in [1, 2, 3]:
		var hero: Dictionary = app.party.get_hero(slot)
		var meter = app.get_node("LiveCombatMeters").row.get_child(slot - 1)
		_check(meter.hp_text.text == "%d/%d" % [hero.hp, hero.max_hp]
			and meter.hp_bar.value == hero.hp and meter.block_badge.visible == (hero.block > 0)
			and meter.block_text.text == (str(hero.block) if hero.block > 0 else ""), "real party HP/Block HUD refreshed")
	var after := _pool_state()
	callback.call(_press())
	await _frames()
	_check(_pool_state() == after and app.deck.hand.count(id) == 1, "retired source cannot consume duplicate copy")
	var remaining := _pool_panel(id)
	_check(remaining != null and remaining != panel and presenter._bindings.has(remaining), "remaining authentic copy bound")
	if remaining != null:
		remaining.grab_focus()
		await _keyboard(KEY_ENTER)
		_check(app.deck.hand.count(id) == 0 and app.deck.energy == before[3] - 4
			and app.run_rng.state == before[11], "second copy independently casts through Enter")
	var result := _pool_state()
	await _dispose()
	return result


func _reject(mode: String, queued: bool) -> void:
	var panel := await _begin(IDS[0], 1 if mode == "seat" and not queued else 2)
	if panel == null:
		await _dispose()
		return
	var callback: Callable = presenter._bindings[panel]
	if queued:
		panel.grab_focus()
		callback.call(_key(KEY_ENTER))
		_check(not presenter._pending.is_empty(), "real deferred cast armed")
	match mode:
		"energy": app.deck.combat_state.energy = 1
		"downed": app.party.apply_damage(2, 999)
		"missing": app.party._heroes[1].id = "seamstress"
		"seat":
			if queued:
				var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, -1)
				_check(swap.ok, "owner can move to illegal cast seat")
				app.party._heroes.assign(swap.heroes)
		"hand":
			app.deck.discard_played(IDS[0])
			app.deck.discard_played(IDS[0])
		"status": app.party._heroes[0].statuses = []
		"inactive": app.deck.combat_state.player_turn_active = false
		"closed": app._battle_closed = true
		"turn": app.enemy_intents.advance_turn()
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"enemies": app.enemies = CombatEnemies.new([{"id": "other", "max_hp": 20}])
		"panel": app._refresh_hand()
		"label": panel.get_child(0).text = IDS[1]
		"cancel": presenter._cancel_pending()
	app._refresh_intents()
	if mode not in ["panel", "cancel"]:
		presenter._metadata._update_visual(panel)
		_check(not presenter._metadata.visual_state(panel).playable, "disabled face: " + mode)
	var before := _pool_state()
	if not queued and mode != "cancel":
		callback.call(_press())
	await _frames()
	_check(_pool_state() == before and presenter._pending.is_empty(), "complete no-spend rejection: " + mode)
	if queued:
		presenter._activate(panel, IDS[0], app.deck, app.party, app.battle_view, presenter._token - 1)
		await _frames()
		_check(_pool_state() == before, "stale activation inert: " + mode)
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id in IDS:
		for seat in [2, 3]:
			for keyboard in [false, true]:
				await _success(id, seat, keyboard, false)
		await _success(id, 2, false, true)
	var first := await _success(IDS[1], 3, true, true)
	_check(await _success(IDS[1], 3, true, true) == first, "entire seeded sequence replays exactly")
	for mode in ["seat", "energy", "downed", "missing", "hand", "status", "inactive", "closed", "turn", "session", "enemies", "panel", "label", "cancel"]:
		for queued in [false, true]:
			await _reject(mode, queued)
	var panel := await _begin(IDS[0])
	_check(panel != null and not presenter._is_actionable("lantern_monk_lantern_glow")
		and not presenter._is_actionable("lantern_monk_lantern_glow_plus"), "Lantern Glow remains unwired")
	await _dispose()
	_finish()
