extends "res://tests/live_support_hand_test.gd"
## Reuse the mounted support harness's real viewport mouse/key dispatch.

const RESTUFF := ["scarecrow_re_stuff", "scarecrow_re_stuff_plus"]


func _begin(id: String, seat: int = 2, damage: int = 20, cap: int = 30) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 289
	_check(app._start_battle(), "real battle admits fixture")
	presenter = app.get_node("LiveSupportHand")
	var rng := RandomNumberGenerator.new()
	rng.seed = 289
	var cards: Array[String] = [id, "warden_strike", "warden_brace", "tinker_pop_shot", "tinker_tune_up"]
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.count(id) == 1, "requested copy genuinely drawn")
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 25}]
	heroes.insert(seat - 1, {"id": "scarecrow", "name": "Scarecrow", "max_hp": cap,
		"statuses": {"weak": 2}, "metadata": {"straw": [1, 2]}})
	app.party = CombatParty.new(heroes)
	_check(app.party.is_valid() and app.party.get_hero(seat).id == "scarecrow", "authentic living owner fixture")
	_check(app.party.apply_damage(seat, damage), "real HP damage applied before Block")
	if damage < cap:
		_check(app.party.gain_block(seat, 7), "owner has preserved Block")
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies, app.enemy_intents, app.battle_result)
	app._refresh_party()
	app._refresh_hand()
	await _frames()
	var panel := _panel(id)
	_check(panel != null and panel.is_visible_in_tree(), "real held panel mounted")
	return panel


func _state() -> Array:
	return [_live(), app.deck.combat_state.player_turn_active,
		app.battle_result.get_outcome() if app.battle_result != null else "missing"]


func _dispose() -> void:
	app.free()
	await _frames()


func _success(id: String, keyboard: bool, seat: int, damage: int, cap: int = 30) -> Array:
	var panel := await _begin(id, seat, damage, cap)
	if panel == null:
		await _dispose()
		return []
	var meta = presenter._metadata
	var facts: Dictionary = meta.get_facts(panel)
	var heal := 13 if id.ends_with("_plus") else 10
	_check(facts.known and facts.owner == "scarecrow" and facts.owner_text == "Scarecrow"
		and facts.cost == 2 and facts.target_text == "Self", "authored owner/cost/self face")
	_check(meta.definition(id) == ScarecrowPoolCards.new().get_definition(id), "exact detached authored definition")
	_check(facts.rules == "Lose 2 max HP first; heal self %d HP, capped at new max HP." % heal,
		"short face states loss before exact capped heal")
	_check(panel.tooltip_text.contains("loses 2 max HP first")
		and panel.tooltip_text.contains("then heals %d HP, capped at the new max HP" % heal)
		and not panel.tooltip_text.contains("not described"), "readable precise tooltip")
	_check(meta.visual_state(panel).playable and panel.focus_mode == Control.FOCUS_ALL
		and panel.gui_input.get_connections().size() == 1, "enabled authentic input panel")
	var before := _state()
	var expected: Array = before.duplicate(true)
	var snapshot: Array = expected[0][0]
	snapshot[1].erase(id)
	snapshot[2].append(id)
	snapshot[3] -= 2
	var hero: Dictionary = snapshot[5][seat - 1]
	hero.max_hp -= 2
	hero.hp = mini(hero.max_hp, mini(hero.hp, hero.max_hp) + heal)
	var callback: Callable = presenter._bindings[panel]
	var token: int = presenter._token
	if keyboard:
		panel.grab_focus()
		# Multiple physical accepts before deferred input commits still cast once.
		root.push_input(_key(KEY_ENTER), true)
		root.push_input(_key(KEY_ENTER), true)
		root.push_input(_key(KEY_ENTER, false), true)
		await _frames()
	else:
		await _mouse(panel)
	_check(_state() == expected, "full independent post-commit snapshot, one payment/copy, RNG untouched")
	_check(app.deck.energy == 1 and app.deck.discard_pile.count(id) == 1
		and not app.deck.hand.has(id), "exact 2 energy and single discard")
	_check(app.hero_panels[seat - 1].get_child(0).text == "%d - Scarecrow\nHP: %d/%d | Block: 7" % [seat, hero.hp, hero.max_hp],
		"real HP/max HP HUD refreshed")
	_check(presenter.energy_label.text == "1" and app.pile_label.text == "Draw: 0 | Discard: 1",
		"energy and pile views refreshed")
	var shown: Array[String] = []
	for held in app.hand_view.get_children():
		shown.append(held.get_child(0).text)
	_check(shown == app.deck.hand and presenter._pending.is_empty(), "real hand refreshed without a target picker")
	callback.call(_press())
	presenter._activate(panel, id, app.deck, app.party, app.battle_view, token)
	await _frames()
	_check(_state() == expected, "retired listener and activation replay spend nothing")
	await _dispose()
	return expected


func _refusal(mode: String, keyboard: bool, id: String = RESTUFF[0]) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	var callback: Callable = presenter._bindings[panel]
	var old_deck: CombatDeck = app.deck
	var old_party: CombatParty = app.party
	var old_rng: RandomNumberGenerator = app.run_rng
	var queued := mode.begins_with("queued_")
	if queued:
		panel.grab_focus()
		root.push_input(_key(KEY_ENTER), true)
		_check(not presenter._pending.is_empty(), "negative has genuinely queued physical input")
	match mode.trim_prefix("queued_"):
		"energy": app.deck.try_spend_energy(2)
		"downed": app.party.apply_damage(2, 1000)
		"missing_owner": app.party._heroes[1].id = "seamstress"
		"duplicate_owner": app.party._heroes[0].id = "scarecrow"
		"cap":
			app.party._heroes[1].max_hp = 2
			app.party._heroes[1].hp = 2
		"malformed": app.party._heroes[1].hp = 31
		"inactive": app.deck.combat_state.player_turn_active = false
		"absent": _check(app.deck.discard_played(id), "negative removes actual held copy")
		"label": panel.get_child(0).text = RESTUFF[1] if id == RESTUFF[0] else RESTUFF[0]
		"hidden": app.battle_view.hide()
		"closed": app._battle_closed = true
		"victory":
			for enemy in app.enemies.get_enemies():
				app.enemies.apply_damage(enemy.position, 10000)
			_check(app.enemies.is_victorious(), "all enemies genuinely slain")
			# Establish the real terminal lifecycle before measuring rejected input.
			app._observe_battle_result()
			app._refresh_intents()
		"result": app.battle_result = CombatBattleResult.new(CombatParty.new(app._load_party_definitions()), app.enemies)
		"deck":
			app.deck = CombatDeck.new([], app.run_rng)
			app.deck.start_turn()
		"party": app.party = CombatParty.new(app._load_party_definitions())
		"rebuild": app._refresh_hand()
		"turn_context": app.enemy_intents._turn_index += 1
		"escape":
			root.push_input(_key(KEY_ESCAPE), true)
		"echo", "release", "right", "unfocused", "unsupported": pass
		_: _check(false, "known refusal case: " + mode)
	var before := _state()
	var old_before := _snapshot(old_deck, old_party, old_rng)
	if is_instance_valid(panel) and mode not in ["queued_rebuild"]:
		presenter._metadata._update_visual(panel)
		if mode.trim_prefix("queued_") not in ["escape", "echo", "release", "right", "unfocused", "unsupported"]:
			_check(not presenter._metadata.visual_state(panel).playable, "truthful unavailable face: " + mode)
	if not queued:
		match mode:
			"echo":
				panel.grab_focus()
				callback.call(_key(KEY_ENTER, true, true))
			"release": callback.call(_key(KEY_ENTER, false))
			"right": await _mouse(panel, MOUSE_BUTTON_RIGHT)
			"unfocused":
				app.end_turn_button.grab_focus()
				callback.call(_key(KEY_ENTER))
			"unsupported": presenter._on_card_input(_press(), panel, "scarecrow_crow_peck", app.deck, app.party, app.battle_view)
			_:
				if not is_instance_valid(panel):
					_check(mode == "victory", "only real victory retires the panel before input")
					callback.call(_press())
				elif keyboard:
					panel.grab_focus()
					await _keyboard(KEY_ENTER)
				else:
					await _mouse(panel)
	await _frames()
	# Direct stale listener replay must be inert even when the physical control was rebuilt.
	if mode not in ["echo", "release", "right", "unfocused", "queued_escape", "unsupported"]:
		callback.call(_press())
		await _frames()
	_check(_state() == before and _snapshot(old_deck, old_party, old_rng) == old_before,
		"rejected input preserves all current/retired authorities and RNG: " + mode)
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id: String in RESTUFF:
		for keyboard in [false, true]:
			for seat in [1, 2, 3]:
				var first := await _success(id, keyboard, seat, 20)
				var replay := await _success(id, keyboard, seat, 20)
				_check(not first.is_empty() and replay == first, "entire seeded mounted replay identical")
			for damage in [0, 1, 5]:
				await _success(id, keyboard, 2, damage)
			await _success(id, keyboard, 2, 1, 3)
	for id: String in RESTUFF:
		for keyboard in [false, true]:
			for mode in ["energy", "downed", "missing_owner", "duplicate_owner", "cap", "malformed", "inactive",
				"absent", "label", "hidden", "closed", "victory", "result", "deck", "party", "turn_context"]:
				await _refusal(mode, keyboard, id)
				await _refusal("queued_" + mode, keyboard, id)
		for mode in ["queued_rebuild", "queued_escape", "echo", "release", "right", "unfocused", "unsupported"]:
			await _refusal(mode, false, id)
	var metadata = preload("res://scripts/live_hand_card_metadata.gd").new()
	for id in ScarecrowPoolCards.new().get_all_card_ids():
		if CombatScarecrowCrowCards.CARDS.has(id):
			_check(metadata.definition(id) == ScarecrowPoolCards.new().get_definition(id),
				"live crow definitions retain their exact pool catalog: " + id)
		elif id in CombatSupportCards.SCARECROW_STRAW_IDS:
			_check(metadata.definition(id) == ScarecrowPoolCards.new().get_definition(id),
				"live straw definitions use their exact pool catalog: " + id)
		elif not id in RESTUFF:
			_check(metadata.definition(id).is_empty(), "unrelated Scarecrow definitions stay unregistered: " + id)
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_scarecrow_re_stuff_hand_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
