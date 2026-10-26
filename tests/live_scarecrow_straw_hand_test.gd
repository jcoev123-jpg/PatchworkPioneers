extends "res://tests/live_scarecrow_re_stuff_hand_test.gd"
## Mounted shared-hand input, authoritative state and independent draw oracle.

const STRAW := CombatSupportCards.SCARECROW_STRAW_IDS


func _straw_begin(id: String, seat: int, supply: int = 0) -> Control:
	var panel := await _begin(id, seat, 0)
	if supply == 1:
		app.deck.draw_pile.append("warden_strike_plus")
	elif supply == 2:
		app.deck.discard_pile.assign(["warden_strike_plus", "warden_brace_plus", "tinker_tune_up_plus"])
	app._refresh_hand()
	await _frames()
	panel = _panel(id)
	_check(panel != null and presenter._bindings.has(panel), "genuine held straw bound to support presenter")
	return panel


func _arm(panel: Control, key: int) -> void:
	if key == 0:
		await _mouse(panel)
	else:
		panel.grab_focus()
		await _keyboard(key)
	_check(presenter._pending.get("choosing", false) and presenter._targets.size() == 3,
		"real card activation opens all three living ally targets")


func _straw_success(id: String, seat: int, target: int, key: int, supply: int) -> Array:
	var panel := await _straw_begin(id, seat, supply)
	if panel == null:
		await _dispose()
		return []
	var meta = presenter._metadata
	var definition := CombatSupportCards.scarecrow_straw_definition(id)
	var catalog: Dictionary = ScarecrowStarterCards.new().get_definition(id)
	if catalog.is_empty():
		catalog = ScarecrowPoolCards.new().get_definition(id)
	var block: int = [4, 6, 6, 8][STRAW.find(id)]
	var facts: Dictionary = meta.get_facts(panel)
	_check(not catalog.is_empty() and meta.definition(id) == catalog and definition == catalog,
		"face uses exact canonical starter/pool printing")
	_check(facts.known and facts.owner == "scarecrow" and facts.cost == 1
		and facts.target_text == "Ally" and facts.rules.contains(str(block))
		and panel.tooltip_text.contains("BASE draw 1 card") and meta.visual_state(panel).playable,
		"canonical cost, Block, draw, ally face and actual eligibility")
	_check(panel.focus_mode == Control.FOCUS_ALL and panel.gui_input.get_connections().size() == 1,
		"one mouse/keyboard card binding")
	var before := _state()
	var expected := before.duplicate(true)
	var snapshot: Array = expected[0][0]
	# Independent deck oracle: one draw happens before the played copy is discarded.
	if supply == 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = snapshot[6]
		rng.state = snapshot[7]
		snapshot[0].append_array(snapshot[2])
		snapshot[2].clear()
		for index in range(snapshot[0].size() - 1, 0, -1):
			var other := rng.randi_range(0, index)
			var saved: String = snapshot[0][index]
			snapshot[0][index] = snapshot[0][other]
			snapshot[0][other] = saved
		snapshot[7] = rng.state
	if not snapshot[0].is_empty():
		snapshot[1].append(snapshot[0].pop_back())
	snapshot[1].erase(id)
	snapshot[2].append(id)
	snapshot[3] -= 1
	snapshot[5][target - 1].block += block
	var callback: Callable = presenter._bindings[panel]
	await _arm(panel, key)
	_check(_state() == before, "picker preview never spends, draws or advances RNG")
	var recipient: Control = app.hero_panels[target - 1]
	_check(presenter._targets.has(recipient), "selected real living recipient bound")
	var target_callback: Callable = presenter._targets[recipient].callback
	var token: int = presenter._token
	if key == 0:
		await _mouse(recipient)
	else:
		recipient.grab_focus()
		root.push_input(_key(key), true)
		root.push_input(_key(key), true)
		root.push_input(_key(key, false), true)
		await _frames()
	_check(_state() == expected, "exact Block, one charge/copy, authentic draw and full RNG oracle")
	_check(app.deck.energy == 2 and app.deck.discard_pile.count(id) == 1
		and not app.deck.hand.has(id), "one paid discard")
	_check(presenter._pending.is_empty() and presenter._targets.is_empty(), "single settled picker")
	_check(presenter.energy_label.text == "2" and app.pile_label.text == "Draw: %d | Discard: %d" % [snapshot[0].size(), snapshot[2].size()],
		"energy and pile HUD refreshed")
	var shown: Array[String] = []
	for held in app.hand_view.get_children():
		shown.append(held.get_child(0).text)
	_check(shown == app.deck.hand, "entire mounted hand refreshes including drawn card")
	var hero: Dictionary = snapshot[5][target - 1]
	_check(app.hero_panels[target - 1].get_child(0).text == "%d - %s\nHP: %d/%d | Block: %d" % [target, hero.name, hero.hp, hero.max_hp, hero.block],
		"exact recipient Block HUD refreshed")
	callback.call(_press())
	target_callback.call(_press())
	presenter._resolve_target(target, token)
	await _frames()
	_check(_state() == expected, "source, target and settlement replay inert")
	await _dispose()
	return expected


func _straw_refusal(id: String, mode: String, stage: int) -> void:
	var panel := await _straw_begin(id, 2, 2)
	if panel == null:
		await _dispose()
		return
	var source: Callable = presenter._bindings[panel]
	var old_deck: CombatDeck = app.deck
	var old_party: CombatParty = app.party
	var old_rng: RandomNumberGenerator = app.run_rng
	var token: int = presenter._token
	var target_callback: Callable
	if stage > 0:
		await _arm(panel, KEY_SPACE)
		token = presenter._token
		target_callback = presenter._targets[app.hero_panels[0]].callback
	if stage == 2:
		app.hero_panels[0].grab_focus()
		root.push_input(_key(KEY_ENTER), true)
		_check(presenter._pending.get("queued", false), "genuine target commit queued before invalidation")
	match mode:
		"energy": app.deck.try_spend_energy(3)
		"owner_dead": app.party.apply_damage(2, 1000)
		"target_dead": app.party.apply_damage(1, 1000)
		"missing_owner": app.party._heroes[1].id = "seamstress"
		"duplicate_owner": app.party._heroes[0].id = "scarecrow"
		"malformed": app.party._heroes[1].hp = 31
		"absent": _check(app.deck.discard_played(id), "actual held copy removed")
		"inactive": app.deck.combat_state.player_turn_active = false
		"closed": app._battle_closed = true
		"hidden": app.battle_view.hide()
		"label": panel.get_child(0).text = STRAW[(STRAW.find(id) + 1) % STRAW.size()]
		"turn": app.enemy_intents._turn_index += 1
		"result": app.battle_result = CombatBattleResult.new(CombatParty.new(app._load_party_definitions()), app.enemies)
		"deck":
			app.deck = CombatDeck.new([], app.run_rng)
			app.deck.start_turn()
		"party": app.party = CombatParty.new(app._load_party_definitions())
		"rebuild": app._refresh_hand()
		"wardrobe": _check(not presenter._straw.bind_patch_wardrobe(null, null), "explicit invalid wardrobe binding")
		"escape": root.push_input(_key(KEY_ESCAPE), true)
		"overflow": app.party._heroes[0].block = CombatParty.MAX_INT
		"forged", "echo", "release", "right", "unfocused": pass
		_: _check(false, "known straw refusal")
	if mode in ["energy", "owner_dead", "missing_owner", "duplicate_owner", "malformed", "absent", "inactive", "closed", "hidden", "label", "turn", "result", "wardrobe"]:
		_check(presenter._metadata._bindings.has(panel), "negative starts with bound metadata")
		presenter._metadata._update_visual(panel)
		_check(not presenter._metadata.visual_state(panel).playable, "invalid live card truthfully dim: " + mode)
	var before := _state()
	var old_before := _snapshot(old_deck, old_party, old_rng)
	if stage == 0:
		match mode:
			"forged": presenter._on_card_input(_press(), panel, STRAW[(STRAW.find(id) + 1) % STRAW.size()], app.deck, app.party, app.battle_view)
			"echo":
				panel.grab_focus()
				source.call(_key(KEY_ENTER, true, true))
			"release": source.call(_key(KEY_ENTER, false))
			"right": await _mouse(panel, MOUSE_BUTTON_RIGHT)
			"unfocused":
				app.end_turn_button.grab_focus()
				source.call(_key(KEY_SPACE))
			_: source.call(_press())
	elif stage == 1:
		target_callback.call(_press())
	await _frames()
	if stage > 0:
		target_callback.call(_press())
		presenter._resolve_target(1, token)
		await _frames()
	_check(_state() == before and _snapshot(old_deck, old_party, old_rng) == old_before,
		"atomic current/retired authority and RNG rejection: %s stage %d" % [mode, stage])
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id: String in STRAW:
		for key in [0, KEY_ENTER, KEY_SPACE]:
			for seat in [1, 2, 3]:
				for target in [1, 2, 3]:
					# Rotate supplies across the complete input/seat/recipient matrix.
					await _straw_success(id, seat, target, key, (seat + target + key) % 3)
		var first := await _straw_success(id, 2, 1, KEY_SPACE, 2)
		_check(not first.is_empty() and first == await _straw_success(id, 2, 1, KEY_SPACE, 2), "entire seeded mounted replay")
		for mode in ["energy", "owner_dead", "missing_owner", "duplicate_owner", "malformed", "absent", "inactive", "closed", "hidden", "label", "turn", "result", "deck", "party", "rebuild", "wardrobe"]:
			for stage in [0, 1, 2]:
				await _straw_refusal(id, mode, stage)
		for mode in ["target_dead", "escape", "overflow"]:
			for stage in [1, 2]:
				await _straw_refusal(id, mode, stage)
		for mode in ["forged", "echo", "release", "right", "unfocused"]:
			await _straw_refusal(id, mode, 0)
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_scarecrow_straw_hand_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
