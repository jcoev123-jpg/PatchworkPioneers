extends "res://tests/live_support_hand_test.gd"

const IDS := ["rag_duelist_feather_feint", "rag_duelist_feather_feint_plus",
	"rag_duelist_velvet_feint", "rag_duelist_velvet_feint_plus"]
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
	heroes.insert(seat - 1, {"id": "rag_duelist", "name": "Rag Duelist", "max_hp": 30, "statuses": {"weak": 1}})
	app.party = CombatParty.new(heroes)
	app.enemies = CombatEnemies.new([
		{"id": "tangled", "max_hp": 50, "statuses": {"tangled": 2, "exposed": 1}},
		{"id": "untangled", "max_hp": 50, "statuses": {"bleed": 2}},
		{"id": "slain", "max_hp": 50, "statuses": {"tangled": 3}}])
	_check(app.party.is_valid() and app.enemies.is_valid(), "real valid rosters")
	_check(app.enemies.gain_block(2, 20), "back survivor has Block")
	_check(app.party.get_hero(seat).id == "rag_duelist" and app.enemies.get_enemy(2).block == 20,
		"non-vacuous owner seat and real Block preconditions")
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


func _arm_feint(panel: Control, keyboard: bool) -> void:
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(panel)
	_check(presenter._pending.get("choosing", false) and presenter._targets.size() > 0,
		"real enemy selection armed")


func _success(id: String, seat: int, input: int, refill: bool, empty: bool = false) -> void:
	var panel := await _begin(id, seat)
	if panel == null:
		await _dispose()
		return
	if id.ends_with("_plus"):
		app.deck.combat_state.energy = 0
	var attack = app.get_node("LiveAttackPreview")
	_check(attack._play._tinker.arm_path_bonus(4), "real pending Tinker bonus established")
	var attack_event: Dictionary = attack.last_event.duplicate(true)
	if refill:
		app.deck.draw_pile.clear()
		app.deck.discard_pile.assign([] if empty else ["warden_brace", "tinker_tune_up", "warden_strike"])
	else:
		app.deck.draw_pile.assign(["warden_brace", "tinker_tune_up"])
	var meta = presenter._metadata
	var facts: Dictionary = meta.get_facts(panel)
	var definition := CombatRagDuelistFeintCards.new()._catalog_definition(id)
	_check(facts.known and facts.owner == "rag_duelist" and facts.owner_text == "Rag Duelist"
		and facts.cost == definition.cost and meta.definition(id) == definition,
		"exact catalog metadata")
	_check(definition.from_positions == [1, 2] and definition.to_positions == [1, 2, 3]
		and meta.short_line(id) == "Exposed 1; draw 1." and panel.tooltip_text.contains("Exposed")
		and panel.tooltip_text.contains("draw") and panel.tooltip_text.contains("Rag Duelist")
		and meta.visual_state(panel).playable, "enabled honest effect, owner and pips")
	_check(facts.from_text == "From " + meta._positions([1, 2])
		and facts.target_text == "To enemy " + meta._positions([1, 2, 3])
		and panel.tooltip_text.contains("%d energy" % definition.cost)
		and panel.tooltip_text.contains("Exposed 1") and panel.tooltip_text.contains("draw 1"),
		"mounted positional facts and tooltip print exact costs and effects")
	var rng := RandomNumberGenerator.new()
	rng.seed = app.run_rng.seed
	rng.state = app.run_rng.state
	var oracle := CombatDeck.new([], rng)
	oracle.draw_pile.assign(app.deck.draw_pile)
	oracle.hand.assign(app.deck.hand)
	oracle.discard_pile.assign(app.deck.discard_pile)
	oracle.combat_state = CombatState.new()
	oracle.combat_state.player_turn_active = true
	oracle.combat_state.energy = app.deck.energy
	var party := CombatParty.new(app.party.get_heroes())
	var enemies := CombatEnemies.new(app.enemies.get_enemies())
	_check(enemies.gain_block(2, 20), "oracle Block established")
	var target := input + 1
	var result := CombatRagDuelistFeintCards.new().play_card(oracle, party, enemies, id, target)
	_check(result.ok and result.drawn == (0 if empty else 1), "non-vacuous resolver oracle")
	var before := _pool_state()
	await _arm_feint(panel, input != 0)
	_check(_pool_state() == before, "arming leaves all state and RNG untouched")
	var target_panel: Control = app.get_node("LiveEnemyRoster")._labels[target - 1]
	var callback: Callable = presenter._targets[target_panel].callback
	if input == 0:
		await _mouse(target_panel)
	elif input == 1:
		target_panel.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _keyboard(KEY_3)
	_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(oracle, party, rng)
		and app.enemies.get_enemies() == enemies.get_enemies(), "mounted result equals independent resolver including RNG")
	_check(app.enemies.get_enemy(target).statuses.get("exposed", 0) == (2 if target == 1 else 1)
		and presenter._pending.is_empty(), "Exposed stacks only on chosen enemy, receipt consumed")
	_check(app.get_node("LiveEnemyRoster")._status_tags[target - 1].visible, "enemy status HUD refreshed")
	_check(attack.last_event == attack_event and attack._play._tinker.first_hit_bonus() == 3
		and attack._play._tinker.path_bonus() == 4, "Feint emits no attack event or first-hit/Scope consumption")
	var after := _pool_state()
	callback.call(_press())
	await _frames()
	_check(_pool_state() == after and app.deck.hand.count(id) == 1, "retired input cannot play remaining copy")
	_last_result = after.duplicate(true)
	await _dispose()


func _unavailable(mode: String) -> void:
	var panel := await _begin(IDS[0], 3 if mode == "seat" else 2)
	if panel == null:
		await _dispose()
		return
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"owner": app.party.apply_damage(2, 999)
		"missing": app.party._heroes[1].id = "seamstress"
		"hand":
			app.deck.discard_played(IDS[0])
			app.deck.discard_played(IDS[0])
		"targets":
			for enemy in app.enemies._enemies:
				enemy.hp = 0
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


func _living_keys() -> void:
	for key in [KEY_1, KEY_2, KEY_3]:
		var panel := await _begin(IDS[1])
		var slot: int = [KEY_1, KEY_2, KEY_3].find(key) + 1
		var dead_slot: int = slot % 3 + 1
		_check(app.enemies.apply_damage(dead_slot, 999), "one genuinely slain target")
		app._refresh_intents()
		await _arm_feint(panel, true)
		var labels: Array = app.get_node("LiveEnemyRoster")._labels
		_check(not presenter._targets.has(labels[dead_slot - 1]), "slain slot excluded from choices")
		var before := _pool_state()
		await _keyboard([KEY_1, KEY_2, KEY_3][dead_slot - 1])
		_check(_pool_state() == before and presenter._pending.get("choosing", false), "dead slot shortcut cannot spend")
		root.push_input(_key(key), true)
		root.push_input(_key(key), true)
		root.push_input(_key(key, false), true)
		await _frames()
		_check(app.deck.hand.count(IDS[1]) == 1 and app.enemies.get_enemy(slot).statuses.get("exposed", 0) == (2 if slot == 1 else 1),
			"all enemy shortcuts commit once despite duplicate press")
		await _dispose()


func _refuse(mode: String, queued: bool) -> void:
	var panel := await _begin(IDS[0])
	if panel == null:
		await _dispose()
		return
	await _arm_feint(panel, true)
	var target: Control = app.get_node("LiveEnemyRoster")._labels[0]
	var callback: Callable = presenter._targets[target].callback
	if queued:
		callback.call(_press())
		_check(presenter._pending.get("queued", false), "actual commit deferred")
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"downed": app.party.apply_damage(2, 999)
		"missing": app.party._heroes[1].id = "seamstress"
		"seat":
			var hero: Dictionary = app.party._heroes[1]
			app.party._heroes[1] = app.party._heroes[2]
			app.party._heroes[2] = hero
		"hand":
			app.deck.discard_played(IDS[0])
			app.deck.discard_played(IDS[0])
		"dead": app.enemies.apply_damage(1, 999)
		"identity": app.enemies._enemies[0].id = "replacement"
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


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id in IDS:
		for seat in [1, 2]:
			for input in [0, 1, 2]:
				await _success(id, seat, input, input != 0)
		await _success(id, 2, 0, true, true)
	for mode in ["seat", "energy", "owner", "missing", "hand", "targets", "status"]:
		await _unavailable(mode)
	await _living_keys()
	await _success(IDS[2], 2, 2, true)
	var replay := _last_result.duplicate(true)
	await _success(IDS[2], 2, 2, true)
	_check(_last_result == replay, "entire mounted seeded refill replays exactly")
	for mode in ["energy", "downed", "missing", "seat", "hand", "dead", "identity", "status",
		"inactive", "turn", "closed", "session", "deck", "panel", "label", "escape", "cancel"]:
		for queued in [false, true]:
			await _refuse(mode, queued)
	_finish()


