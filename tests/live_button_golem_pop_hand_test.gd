extends "res://tests/live_support_hand_test.gd"

const IDS := ["button_golem_starter_loose_pop", "button_golem_starter_loose_pop_plus",
	"button_golem_pop_button", "button_golem_pop_button_plus"]
var _last_result: Array = []

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
	app.deck.combat_state.energy = 6
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 25}]
	heroes.insert(seat - 1, {"id": "button_golem", "name": "Button Golem", "max_hp": 30, "statuses": {"weak": 1}})
	app.party = CombatParty.new(heroes)
	app.enemies = CombatEnemies.new([
		{"id": "tangled", "max_hp": 50, "statuses": {"tangled": 2, "exposed": 1}},
		{"id": "untangled", "max_hp": 50, "statuses": {"bleed": 2}},
		{"id": "slain", "max_hp": 50, "statuses": {"tangled": 3}}])
	_check(app.party.is_valid() and app.enemies.is_valid(), "real valid rosters")
	_check(app.enemies.gain_block(2, 20), "back survivor has Block")
	_check(app.party.get_hero(seat).id == "button_golem" and app.enemies.get_enemy(2).block == 20,
		"non-vacuous owner seat and real Block preconditions")
	_check(app.party.gain_block(seat, 10) and app.party.get_hero(seat).block == 10,
		"Golem has real stored own Block before input")
	app.party._heroes[seat - 1].buttons_popped = 7
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies, app.enemy_intents, app.battle_result)
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_hand()
	await _frames()
	var panel := _pool_panel(id)
	_check(panel != null and panel.is_visible_in_tree() and presenter._bindings.has(panel), "authentic panel bound by mounted adapter")
	return panel


func _dispose() -> void:
	app.free()
	await _frames()


func _arm_pop(panel: Control, keyboard: bool) -> void:
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(panel)
	_check(presenter._pending.get("choosing", false) and presenter._targets.size() > 0,
		"real enemy selection armed")


func _success(id: String, seat: int, input: int) -> void:
	var panel := await _begin(id, seat)
	if panel == null:
		await _dispose()
		return
	var meta = presenter._metadata
	var definition: Dictionary = ButtonGolemStarterCards.new().get_definition(id) if id.begins_with("button_golem_starter") else ButtonGolemPoolCards.new().get_definition(id)
	var facts: Dictionary = meta.get_facts(panel)
	_check(not definition.is_empty() and meta.definition(id) == definition, "distinct authenticated catalog")
	_check(facts.known and facts.owner_text == "Button Golem" and facts.cost == 1
		and facts.from_text == "From " + meta._positions([1, 2])
		and facts.target_text == "To enemy " + meta._positions([1, 2])
		and meta.visual_state(panel).playable, "mounted enabled owner, cost and pips")
	_check(meta.short_line(id) == "Spend 5 own Block; deal %d; pop 1 button." % definition.effects.damage
		and panel.tooltip_text.contains("1 energy") and panel.tooltip_text.contains("spend 5 own Block")
		and panel.tooltip_text.contains("deal %d damage" % definition.effects.damage), "exact printed payment and damage")
	var rng := RandomNumberGenerator.new()
	rng.seed = app.run_rng.seed
	rng.state = app.run_rng.state
	var oracle := CombatDeck.new([], rng)
	oracle.hand.assign(app.deck.hand)
	oracle.draw_pile.assign(app.deck.draw_pile)
	oracle.discard_pile.assign(app.deck.discard_pile)
	oracle.combat_state = CombatState.new()
	oracle.combat_state.player_turn_active = true
	oracle.combat_state.energy = app.deck.energy
	var party := CombatParty.new(app.party.get_heroes())
	party._heroes = app.party.get_heroes()
	var enemies := CombatEnemies.new(app.enemies.get_enemies())
	enemies._enemies = app.enemies.get_enemies()
	var target := 1 if input == 0 else 2
	var result := CombatButtonGolemPopCards.new().play_card(oracle, party, enemies, id, target)
	_check(result.ok and result.block_spent == 5 and result.buttons_popped == 8, "independent resolver oracle actually commits")
	var before := _pool_state()
	await _arm_pop(panel, input != 0)
	_check(_pool_state() == before and presenter._targets.size() == 2, "arming is pure; only two legal targets")
	var labels: Array = app.get_node("LiveEnemyRoster")._labels
	_check(not presenter._targets.has(labels[2]), "living out-of-range enemy excluded")
	await _keyboard(KEY_3)
	_check(_pool_state() == before, "out-of-range number input is inert")
	var callback: Callable = presenter._targets[labels[target - 1]].callback
	if input == 0:
		await _mouse(labels[target - 1])
	elif input == 1:
		labels[target - 1].grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		root.push_input(_key(KEY_2), true)
		root.push_input(_key(KEY_2), true)
		root.push_input(_key(KEY_2, false), true)
		await _frames()
	_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(oracle, party, rng)
		and app.enemies.get_enemies() == enemies.get_enemies(), "mounted result equals independent oracle including RNG")
	_check(app.deck.hand.count(id) == 1 and app.deck.discard_pile.count(id) == 1
		and app.party.get_hero(seat).block == 5 and app.party.get_hero(seat).buttons_popped == 8,
		"one energy, five own Block, one copy and one counter increment")
	_check(result.block_absorbed > 0 if target == 2 else result.hp_loss > 0, "blocked hit or HP damage exercised")
	_check(app.hero_panels[seat - 1].get_child(0).text.contains("Block: 5"), "hero HUD refreshed")
	var after := _pool_state()
	callback.call(_press())
	await _frames()
	_check(_pool_state() == after and presenter._pending.is_empty(), "retired duplicate receipt inert")
	_last_result = after.duplicate(true)
	await _dispose()


func _unavailable(mode: String) -> void:
	var panel := await _begin(IDS[0], 3 if mode == "seat" else 2)
	if panel == null:
		await _dispose()
		return
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"block": app.party._heroes[1].block = 4
		"counter": app.party._heroes[1].buttons_popped = -1
		"owner": app.party.apply_damage(2, 999)
		"missing": app.party._heroes[1].id = "seamstress"
		"hand":
			app.deck.discard_played(IDS[0])
			app.deck.discard_played(IDS[0])
		"targets":
			for enemy in app.enemies._enemies:
				enemy.hp = 0
		"range":
			app.enemies.apply_damage(1, 999)
			app.enemies.apply_damage(2, 999)
			_check(app.enemies.get_enemy(3).hp > 0, "only out-of-range enemy survives")
		"status": app.enemies._enemies[1].statuses = []
	app._refresh_intents()
	presenter._metadata._update_visual(panel)
	_check(not presenter._metadata.visual_state(panel).playable, "disabled face before input: " + mode)
	var callback: Callable = presenter._bindings[panel]
	if mode == "targets":
		app._observe_battle_result()
	var before := _pool_state()
	if mode == "targets":
		callback.call(_press())
		await _frames()
	else:
		await _mouse(panel)
	_check(_pool_state() == before and presenter._pending.is_empty(), "unavailable card cannot arm or spend: " + mode)
	await _dispose()


func _refuse(mode: String, queued: bool) -> void:
	var panel := await _begin(IDS[0])
	if panel == null:
		await _dispose()
		return
	await _arm_pop(panel, true)
	var target: Control = app.get_node("LiveEnemyRoster")._labels[0]
	var callback: Callable = presenter._targets[target].callback
	if queued:
		callback.call(_press())
		_check(presenter._pending.get("queued", false), "actual commit deferred")
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"block": app.party._heroes[1].block = 4
		"counter": app.party._heroes[1].buttons_popped = -1
		"downed": app.party.apply_damage(2, 999)
		"missing": app.party._heroes[1].id = "seamstress"
		"seat":
			var hero: Dictionary = app.party._heroes[1]
			app.party._heroes[1] = app.party._heroes[2]
			app.party._heroes[2] = hero
		"legal_seat_change":
			var hero: Dictionary = app.party._heroes[1]
			app.party._heroes[1] = app.party._heroes[0]
			app.party._heroes[0] = hero
			app.party._heroes[0].position = 1
			app.party._heroes[1].position = 2
			_check(app.party.is_valid() and app.party.get_hero(1).id == "button_golem",
				"owner moved to another otherwise legal seat")
		"hand":
			app.deck.discard_played(IDS[0])
			app.deck.discard_played(IDS[0])
		"dead": app.enemies.apply_damage(1, 999)
		"identity": app.enemies._enemies[0].id = "replacement"
		"same_id": app.enemies._enemies[0] = app.enemies._enemies[0].duplicate(true)
		"counter_type": app.party._heroes[1].buttons_popped = 1.5
		"owner_status": app.party._heroes[1].statuses = {"weak": -1}
		"battle":
			app.battle_view = app.battle_view.duplicate(0)
			app.add_child(app.battle_view)
		"status": app.enemies._enemies[0].statuses = {"exposed": -1}
		"inactive": app.deck.combat_state.player_turn_active = false
		"turn": app.enemy_intents.advance_turn()
		"closed": app._battle_closed = true
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"deck":
			var rng := RandomNumberGenerator.new()
			rng.seed = 8
			app.deck = CombatDeck.new([IDS[0]], rng)
			app.deck.start_turn()
		"panel": app._refresh_hand()
		"label": panel.get_child(0).text = IDS[1]
		"escape":
			root.push_input(_key(KEY_ESCAPE), true)
			root.push_input(_key(KEY_ESCAPE, false), true)
		"cancel": presenter.cancel_button.pressed.emit()
	# Settle presentation-only forecasts for externally changed fixture state.
	app._refresh_intents()
	var before := _pool_state()
	callback.call(_press())
	await _frames()
	_check(_pool_state() == before and presenter._pending.is_empty(), "complete no-spend rejection: " + mode)
	callback.call(_press())
	await _frames()
	_check(_pool_state() == before, "rejected receipt cannot replay: " + mode)
	await _dispose()


func _living_keys() -> void:
	for slot in [1, 2]:
		var panel := await _begin(IDS[0])
		var dead: int = 3 - slot
		app.enemies.apply_damage(dead, 999)
		app._refresh_intents()
		await _arm_pop(panel, true)
		_check(presenter._targets.size() == 1, "only living in-range enemy selectable")
		var before := _pool_state()
		await _keyboard(KEY_1 if dead == 1 else KEY_2)
		_check(_pool_state() == before, "dead target key inert")
		await _keyboard(KEY_1 if slot == 1 else KEY_2)
		_check(app.deck.hand.count(IDS[0]) == 1 and app.party.get_hero(2).buttons_popped == 8, "both legal number keys commit")
		await _dispose()


func _counter_change() -> void:
	var panel := await _begin(IDS[3])
	await _arm_pop(panel, true)
	app.party._heroes[1].buttons_popped = 12
	var energy: int = app.deck.energy
	var rng_state: int = app.run_rng.state
	await _keyboard(KEY_1)
	_check(app.party.get_hero(2).buttons_popped == 13 and app.party.get_hero(2).block == 5
		and app.deck.energy == energy - 1 and app.run_rng.state == rng_state,
		"deferred resolution increments current valid counter once without RNG")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id in IDS:
		for seat in [1, 2]:
			for input in [0, 1, 2]:
				await _success(id, seat, input)
	for mode in ["seat", "energy", "block", "counter", "owner", "missing", "hand", "targets", "range", "status"]:
		await _unavailable(mode)
	await _living_keys()
	await _counter_change()
	await _success(IDS[2], 2, 2)
	var replay := _last_result.duplicate(true)
	await _success(IDS[2], 2, 2)
	_check(_last_result == replay, "complete seeded mounted replay")
	for mode in ["energy", "block", "counter", "counter_type", "downed", "missing", "seat", "legal_seat_change", "hand", "dead", "identity", "same_id", "status", "owner_status", "battle",
		"inactive", "turn", "closed", "session", "deck", "panel", "label", "escape", "cancel"]:
		for queued in [false, true]:
			await _refuse(mode, queued)
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_button_golem_pop_hand_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
