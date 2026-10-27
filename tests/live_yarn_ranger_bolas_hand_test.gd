extends "res://tests/live_support_hand_test.gd"

const BOLAS := CombatYarnRangerBolasCards.CARDS


func _begin(id: String, seat: int = 2, mode: String = "plain") -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 321
	_check(app._start_battle(), "real mounted battle starts")
	presenter = app.get_node("LiveSupportHand")
	var rng := RandomNumberGenerator.new()
	rng.seed = 321
	app.deck = CombatDeck.new([id, id, "warden_strike", "warden_brace", "tinker_tune_up"], rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.count(id) == 2 and app.deck.energy == 3,
		"one shared deck draws five cards and starts at three energy")
	app.deck.combat_state.energy = 1
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 25}]
	var ranger := {"id": "yarn_ranger", "name": "Yarn Ranger", "max_hp": 27}
	if mode == "weak_exposed":
		ranger["statuses"] = {"weak": 1}
	heroes.insert(seat - 1, ranger)
	app.party = CombatParty.new(heroes)
	var status := {"exposed": 1, "tangled": 2} if mode == "tangled_exposed" else ({"exposed": 1} if mode == "weak_exposed" else {})
	app.enemies = CombatEnemies.new([
		{"id": "first", "name": "First", "max_hp": 40, "statuses": status},
		{"id": "second", "name": "Second", "max_hp": 40},
		{"id": "third", "name": "Third", "max_hp": 40}])
	_check(app.party.is_valid() and app.enemies.is_valid(), "three authentic seats and valid enemy roster")
	if mode == "plain":
		_check(app.enemies.gain_block(1, 1), "plain target begins with Block")
	elif mode == "tangled_exposed":
		_check(app.enemies.gain_block(1, 4), "Tangled/Exposed target begins with Block")
	elif mode == "weak_exposed":
		_check(app.enemies.gain_block(1, 2), "Weak/Exposed target begins with Block")
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies, app.enemy_intents, app.battle_result)
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_hand()
	await _frames()
	var panel := _panel(id)
	_check(panel != null and panel.is_visible_in_tree() and presenter._bindings.has(panel),
		"real illustrated hand binds the exact held card")
	return panel


func _state() -> Array:
	return [_live(), app.battle_result.get_outcome(), app._battle_closed]


func _model_state() -> Array:
	return [_snapshot(app.deck, app.party, app.run_rng), app.enemies.get_enemies(),
		app.enemy_intents.get_intents(), app.battle_result.get_outcome(), app._battle_closed]


func _dispose() -> void:
	app.free()
	await _frames()


func _arm(panel: Control, keyboard: bool) -> void:
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(panel)


func _target_panel(position: int) -> Control:
	return app.get_node("LiveEnemyRoster")._labels[position - 1]


func _select(panel: Control, keyboard: bool) -> void:
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_SPACE)
	else:
		await _mouse(panel)


func _success(id: String, mode: String, keyboard: bool, seat: int, target: int = 1) -> void:
	var panel := await _begin(id, seat, mode)
	if panel == null:
		await _dispose()
		return
	var meta = presenter._metadata
	var definition: Dictionary = CombatYarnRangerBolasCards.bolas_definition(id)
	meta._update_visual(panel)
	var facts: Dictionary = meta.get_facts(panel)
	_check(not definition.is_empty() and meta.definition(id) == definition
		and facts.known and facts.owner == "yarn_ranger" and facts.cost == 1
		and facts.display_name == definition.display_name
		and facts.from_text == "From 2–3" and facts.target_text == "To enemy 1–3",
		"authentic starter/pool base/upgrade owner, name, cost, FROM and TO")
	_check(meta.short_line(id) == "Deal %d; then apply Tangled %d." % [definition.effects.damage, definition.effects.tangled]
		and panel.tooltip_text.contains(definition.display_name)
		and panel.tooltip_text.contains("NEW Tangled %d" % definition.effects.tangled)
		and panel.tooltip_text.contains("Pre-existing Tangled adds +2")
		and panel.tooltip_text.contains("PIPS")
		and meta.get_geometry(panel).size() > 0,
		"sewn illustrated face and Help give printed damage/Tangled and legal pips")
	_check(meta.visual_state(panel).playable and panel.self_modulate == Color.WHITE
		and panel.gui_input.get_connections().size() == 1 and panel.focus_mode == Control.FOCUS_ALL,
		"exactly one enabled real mouse/keyboard card binding")
	var before := _state()
	var old_source: Callable = presenter._bindings[panel]
	await _arm(panel, keyboard)
	var targets = presenter._targets
	_check(_state() == before and presenter._pending.get("choosing", false) and targets.size() == 3
		and targets.has(_target_panel(target)) and _target_panel(target).has_focus() == (target == 1),
		"arm offers living legal enemy slots with focus and no payment")
	if not targets.has(_target_panel(target)):
		await _dispose()
		return
	var target_panel := _target_panel(target)
	var old_target: Callable = targets[target_panel].callback
	_check(target_panel.gui_input.is_connected(old_target) and target_panel.focus_mode == Control.FOCUS_ALL
		and targets[target_panel].has("actor_ref")
		and is_same(targets[target_panel].actor_ref, app.enemies._enemies[target - 1]),
		"real enemy choice widget binds current actor identity")
	var previous: Dictionary = app.enemies.get_enemy(target)
	var other_enemies: Array = app.enemies.get_enemies()
	var prior_party: Array = app.party.get_heroes()
	var prior_rng: int = app.run_rng.state
	var prior_draw: Array[String] = app.deck.draw_pile.duplicate()
	var prior_hand: Array[String] = app.deck.hand.duplicate()
	var prior_discard: Array[String] = app.deck.discard_pile.duplicate()
	var prior_intents = app.enemy_intents.get_intents()
	var printed: int = int(definition.effects.damage)
	var adjusted: int = printed
	if mode == "tangled_exposed":
		adjusted = int(floor(float(printed) * 1.5)) + 2
	elif mode == "weak_exposed":
		adjusted = int(floor(float(printed) * 9.0 / 8.0))
	var absorbed: int = mini(int(previous.block), adjusted)
	var expected_hp: int = maxi(0, int(previous.hp) - (adjusted - absorbed))
	await _select(target_panel, keyboard)
	var after: Dictionary = app.enemies.get_enemy(target)
	_check(after.hp == expected_hp and after.block == previous.block - absorbed
		and after.get("statuses", {}).get("tangled", 0) == previous.get("statuses", {}).get("tangled", 0) + definition.effects.tangled,
		"pre-hit Weak/Exposed/Tangled adjustment, Block-before-HP and only NEW post-hit Tangled")
	for index in range(3):
		if index != target - 1:
			_check(app.enemies.get_enemy(index + 1) == other_enemies[index], "other enemy state unchanged")
	_check(app.party.get_heroes() == prior_party and app.run_rng.state == prior_rng
		and app.enemy_intents.get_intents() == prior_intents and app.battle_result.get_outcome() == CombatBattleResult.ACTIVE,
		"party, intents, battle result and RNG remain unchanged")
	_check(app.deck.energy == 0 and app.deck.hand.count(id) == 1
		and app.deck.hand.size() == prior_hand.size() - 1
		and app.deck.discard_pile == prior_discard + [id]
		and app.deck.draw_pile == prior_draw,
		"single one-energy payment, exactly one discarded copy and no extra draws")
	_check(presenter._pending.is_empty() and presenter._targets.is_empty()
		and presenter.energy_label.text == "0"
		and app.hand_view.get_child_count() == app.deck.hand.size()
		and app.pile_label.text == "Draw: %d | Discard: %d" % [app.deck.draw_pile.size(), app.deck.discard_pile.size()],
		"one-shot target closes and real hand/piles/energy HUD refresh")
	var status_tag = app.get_node("LiveEnemyRoster")._status_tags[target - 1]
	_check(status_tag.visible and (status_tag.get_node("Caption") as Label).text.to_lower().contains("tangled"),
		"mounted enemy status plaque refreshes to printed Tangled")
	var remaining := _panel(id)
	if remaining != null:
		meta._update_visual(remaining)
		_check(not meta.visual_state(remaining).playable, "second held copy stays but dims at zero energy")
	app.deck.combat_state.energy = 1
	before = _state()
	old_source.call(_press())
	old_target.call(_press())
	await _frames()
	_check(_state() == before and presenter._pending.is_empty(), "retired callbacks never replay another affordable copy")
	if remaining != null:
		meta._update_visual(remaining)
		_check(meta.visual_state(remaining).playable and presenter._eligible(remaining, id, app.deck, app.party, app.battle_view),
			"remaining held copy can be played with replenished energy")
	await _dispose()


func _reject(id: String, mode: String, stage: int) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	var source: Callable = presenter._bindings[panel]
	var target_callback: Callable
	if stage > 0:
		await _arm(panel, true)
		_check(presenter._targets.size() == 3, "negative fixture arms three enemy choices")
		if presenter._targets.size() != 3:
			await _dispose()
			return
		target_callback = presenter._targets[_target_panel(1)].callback
		if stage == 2:
			target_callback.call(_press())
			_check(presenter._pending.get("queued", false), "deferred target confirmation queued once")
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"downed": app.party.apply_damage(2, 1000)
		"missing": app.party._heroes[1].id = "seamstress"
		"wrong_seat":
			var first: Dictionary = app.party._heroes[0]
			var second: Dictionary = app.party._heroes[1]
			app.party._heroes[0] = second
			app.party._heroes[1] = first
			app.party._heroes[0].position = 1
			app.party._heroes[1].position = 2
		"unheld":
			app.deck.discard_played(id)
			app.deck.discard_played(id)
		"forged": panel.get_child(0).text = "yarn_ranger_fake_bolas"
		"target_dead": app.enemies.apply_damage(1, 1000)
		"illegal_slot": app.enemies._enemies[0].position = 4
		"actor_replaced": app.enemies._enemies[0] = app.enemies._enemies[0].duplicate(true)
		"owner_moved": app.party._heroes[1].position = 3
		"end_turn": app.deck.combat_state.player_turn_active = false
		"closed": app._battle_closed = true
		"result": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"round": app.enemy_intents.advance_turn()
		"rebuild": app._refresh_hand()
		"cancel": presenter.cancel_button.pressed.emit()
		"escape": await _keyboard(KEY_ESCAPE)
	var before := _model_state()
	if stage == 0:
		source.call(_press())
	elif stage == 1:
		target_callback.call(_press())
	await _frames()
	_check(_model_state() == before and presenter._pending.is_empty(),
		"invalid/cancelled %s stage %d does not pay, hit, or change RNG/result" % [mode, stage])
	await _dispose()


func _slain_picker(id: String) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	_check(app.enemies.apply_damage(2, 1000), "one slain target fixture")
	app._refresh_enemy_roster()
	var before := _model_state()
	await _arm(panel, true)
	_check(_model_state() == before and presenter._targets.size() == 2
		and not presenter._targets.has(_target_panel(2)), "dead enemy excluded from legal picker")
	await _keyboard(KEY_ESCAPE)
	_check(_model_state() == before and presenter._pending.is_empty(), "Escape cancels without payment")
	_check(app.enemies.apply_damage(1, 1000) and app.enemies.apply_damage(3, 1000),
		"all enemy targets invalid")
	app._refresh_enemy_roster()
	meta_update(panel)
	_check(not presenter._eligible(panel, id, app.deck, app.party, app.battle_view)
		and not presenter._metadata.visual_state(panel).playable,
		"all-dead roster has no actionable panel")
	await _dispose()


func meta_update(panel: Control) -> void:
	presenter._metadata._update_visual(panel)


func _lethal(id: String) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	_check(app.enemies.apply_damage(1, 40) and app.enemies.get_enemy(1).hp == 1,
		"lethal target retains a living original seat before play")
	var first_ref: Dictionary = app.enemies._enemies[0]
	var other: Array = app.enemies.get_enemies()
	await _arm(panel, false)
	_check(presenter._targets.has(_target_panel(1)), "lethal hit begins on living target")
	await _select(_target_panel(1), true)
	var card: Dictionary = CombatYarnRangerBolasCards.bolas_definition(id)
	_check(is_same(first_ref, app.enemies._enemies[0])
		and app.enemies.get_enemy(1).hp == 0
		and app.enemies.get_enemy(1).get("statuses", {}).get("tangled", 0) == card.effects.tangled
		and app.enemies.get_enemy(2) == other[1] and app.enemies.get_enemy(3) == other[2]
		and app.deck.energy == 0 and app.deck.hand.count(id) == 1,
		"lethal paid hit retains post-hit Tangled on original slain enemy seat")
	await _dispose()


func _replacement(id: String) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	var source: Callable = presenter._bindings[panel]
	await _arm(panel, true)
	var target: Callable = presenter._targets[_target_panel(1)].callback
	var old_deck: CombatDeck = app.deck
	var old_party: CombatParty = app.party
	var old_enemies: CombatEnemies = app.enemies
	var old_rng: RandomNumberGenerator = app.run_rng
	var before := _state()
	target.call(_press())
	app.return_button.pressed.emit()
	await _frames()
	source.call(_press())
	target.call(_press())
	_check(_snapshot(old_deck, old_party, old_rng) == before[0][0]
		and old_enemies.get_enemies() == before[0][5], "retired callbacks cannot pay after exit")
	_check(app._start_battle(), "replacement battle starts")
	await _frames()
	before = _state()
	source.call(_press())
	target.call(_press())
	await _frames()
	_check(_state() == before, "prior battle callback cannot mutate next battle")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id: String in BOLAS:
		await _success(id, "plain", false, 2)
		await _success(id, "tangled_exposed", true, 3)
		await _success(id, "weak_exposed", false, 2)
		await _success(id, "plain", true, 3, 2)
		await _success(id, "plain", false, 2, 3)
		await _lethal(id)
		for mode in ["energy", "downed", "missing", "wrong_seat", "unheld", "forged",
				"target_dead", "illegal_slot", "actor_replaced", "owner_moved", "end_turn",
				"closed", "result", "round", "rebuild"]:
			for stage in ([1, 2] if mode in ["target_dead", "actor_replaced"] else [0, 1, 2]):
				await _reject(id, mode, stage)
		for mode in ["cancel", "escape"]:
			for stage in [1, 2]:
				await _reject(id, mode, stage)
		await _slain_picker(id)
		await _replacement(id)
	for failure in failures:
		printerr("FAIL: " + failure)
	print("live_yarn_ranger_bolas_hand_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
