extends "res://tests/live_support_hand_test.gd"
## Real App hand input versus a fully independent paid Moth Cloud resolver.
## Never teach the shared metadata presenter these rare printings.

const IDS := ["lantern_monk_moth_cloud", "lantern_monk_moth_cloud_plus"]


func _begin(id: String, seat: int = 2, neighbor: bool = false) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 3776
	_check(app._start_battle(), "real App opens an actual active combat")
	presenter = app.get_node("LiveAreaAttackAction")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3776
	var cards: Array[String] = [id, id, "warden_strike", "warden_brace",
		"tinker_scatter_bolts" if neighbor else "tinker_tune_up"]
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.size() == 5
		and app.deck.hand.count(id) == 2, "five-card genuine hand has two held copies")
	app.deck.combat_state.energy = 6
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 25}]
	heroes.insert(seat - 1, {"id": "lantern_monk", "name": "Lantern Monk",
		"max_hp": 30, "statuses": {"cannot_buff_next_turn": true}})
	app.party = CombatParty.new(heroes)
	app.enemies = CombatEnemies.new([
		{"id": "front", "max_hp": 30, "statuses": {"weak": 2}},
		{"id": "middle", "max_hp": 30, "statuses": {"blind_next_attack": 1,
			"tangled": 1}},
		{"id": "rear", "max_hp": 30, "statuses": {"bleed": 1}}])
	_check(app.party.is_valid() and app.enemies.is_valid()
		and app.party.get_hero(seat).id == "lantern_monk"
		and app.party.get_hero(seat).max_hp == 30, "actual Monk at current legal seat")
	_check(app.enemies.apply_damage(3, 30), "third slot slain without compaction")
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies,
		app.enemy_intents, app.battle_result)
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_hand()
	await _frames()
	var panel := _panel(id)
	_check(panel != null and panel.is_visible_in_tree()
		and presenter._bindings.has(panel), "live held panel claimed by mounted area adapter")
	return panel


func _state() -> Array:
	return [_deck_state(app.deck), app.party.get_heroes(), app.enemies.get_enemies(),
		app.run_rng.seed, app.run_rng.state, app.enemy_intents.get_intents(),
		app.enemy_intents._turn_index, app.battle_result.get_outcome(),
		app._battle_closed, app.session_gold, app.enemy_attacks.duplicate(true)]


func _deck_state(deck: CombatDeck) -> Array:
	return [deck.draw_pile.duplicate(), deck.hand.duplicate(), deck.discard_pile.duplicate(),
		deck.exhausted.duplicate(), deck.energy, deck.turn_active]


func _oracle() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = app.run_rng.seed
	rng.state = app.run_rng.state
	var deck := CombatDeck.new([], rng)
	rng.state = app.run_rng.state
	deck.draw_pile = app.deck.draw_pile.duplicate()
	deck.hand = app.deck.hand.duplicate()
	deck.discard_pile = app.deck.discard_pile.duplicate()
	deck.exhausted = app.deck.exhausted.duplicate()
	deck.combat_state.energy = app.deck.energy
	deck.combat_state.player_turn_active = app.deck.turn_active
	var party := CombatParty.new(app.party.get_heroes())
	party._heroes = app.party.get_heroes()
	var enemies := CombatEnemies.new(app.enemies.get_enemies())
	enemies._enemies = app.enemies.get_enemies()
	return {"deck": deck, "party": party, "enemies": enemies, "rng": rng}


func _dispose() -> void:
	app.free()
	await _frames()


func _face(panel: Control, id: String) -> void:
	var definition := LanternMonkPoolCards.new().get_definition(id)
	var service := CombatLanternMonkMothCloudCards.new()
	var face: Dictionary = presenter.face_text(panel)
	var expected_cost := 1 if id.ends_with("_plus") else 2
	_check(service.is_supported_card(id) and presenter._definition(id) == definition
		and definition.cost == expected_cost and definition.owner == "lantern_monk"
		and definition.target_kind == "enemy_all" and definition.effects ==
			{"blind_next_attack": true, "exhaust": true}, "exact authenticated catalog printing")
	_check(face.get("name") == definition.display_name
		and face.get("cost") == "%d energy" % expected_cost
		and face.get("owner") == "Lantern Monk"
		and face.get("effect", "").contains("Blind NEXT attack")
		and face.get("effect", "").contains("Exhaust"),
		"readable sewn title, cost, owner, Blind and Exhaust")
	_check(face.get("from_pips") == [false, true, true]
		and face.get("to_pips") == [true, true, true] and face.get("thread") == true,
		"drawn FROM 2,3 / enemy-all 1,2,3 and thread")
	var tooltip: String = panel.tooltip_text
	_check(tooltip.contains(definition.display_name) and tooltip.contains("Lantern Monk")
		and tooltip.contains("%d energy" % expected_cost) and tooltip.contains("From 2,3")
		and tooltip.contains("enemies 1,2,3") and tooltip.contains("Blind NEXT attack")
		and tooltip.contains("Exhaust") and tooltip.contains("no target choice"),
		"tooltip states complete authenticated rules and no picker")
	var nodes: Array[Node] = presenter.face_children(panel)
	var names: Array[String] = []
	for node in nodes:
		names.append(str(node.name))
	_check(names.has("CardName") and names.has("Cost") and names.has("Owner")
		and names.has("Effect") and names.has("Positions")
		and names.has("From2") and names.has("To3"), "all sewn labels and pips mounted")
	_check(panel.get_child(0) is Label and panel.get_child(0).text == id
		and panel.gui_input.get_connections().size() == 1
		and presenter._bindings[panel].id == id
		and panel.focus_mode == Control.FOCUS_ALL, "retained first-child identity, single input and focus")
	_check(presenter.button == null, "no separate action button")


func _activate(panel: Control, mode: String) -> void:
	if mode == "mouse":
		await _mouse(panel)
	else:
		panel.grab_focus()
		root.push_input(_key(KEY_ENTER if mode == "enter" else KEY_SPACE), true)
		root.push_input(_key(KEY_ENTER if mode == "enter" else KEY_SPACE), true)
		root.push_input(_key(KEY_ENTER if mode == "enter" else KEY_SPACE, false), true)
		await _frames()


func _success(id: String, seat: int, mode: String, neighbor: bool = false) -> void:
	var panel := await _begin(id, seat, neighbor)
	if panel == null:
		await _dispose()
		return
	_face(panel, id)
	var first := _oracle()
	var before := _state()
	var expected_dead = app.enemies.get_enemy(3)
	var expected_heroes = app.party.get_heroes()
	var expected_rng = app.run_rng.state
	var old: Callable = presenter._bindings[panel].callback
	var receipt := CombatLanternMonkMothCloudCards.new().play_card(
		first.deck, first.party, first.enemies, id, 0)
	_check(receipt.get("ok", false) and receipt.get("owner_position") == seat
		and receipt.get("blinded_positions") == [1, 2]
		and receipt.get("target_position") == 0 and receipt.get("cost") ==
			(1 if id.ends_with("_plus") else 2), "independent paid area/exhaust oracle")
	if not receipt.get("ok", false):
		await _dispose()
		return
	await _activate(panel, mode)
	_check(presenter.last_event == receipt, "mounted receipt exactly equals independent paid resolver")
	_check(_deck_state(app.deck) == _deck_state(first.deck)
		and app.enemies.get_enemies() == first.enemies.get_enemies()
		and app.party.get_heroes() == first.party.get_heroes()
		and app.run_rng.state == first.rng.state, "full deck, statuses, heroes and RNG equal detached oracle")
	_check(app.deck.hand.count(id) == 1 and app.deck.exhausted.count(id) == 1
		and app.deck.discard_pile.count(id) == 0 and app.run_rng.state == expected_rng
		and app.enemies.get_enemy(3) == expected_dead
		and app.party.get_heroes() == expected_heroes,
		"one exhausted, one held, dead position and other originals identical")
	_check(app.enemies.get_enemy(1).statuses == {"weak": 2, "blind_next_attack": 1}
		and app.enemies.get_enemy(2).statuses == {"blind_next_attack": 1, "tangled": 1},
		"canonical one-shot status set/kept, unrelated maps preserved")
	_check(app.pile_label.text == "Draw: %d | Discard: %d" % [
		app.deck.draw_pile.size(), app.deck.discard_pile.size()]
		and app.get_node("LiveSupportHand").energy_label.text == "%d" % app.deck.energy
		and app.hand_view.get_child_count() == app.deck.hand.size()
		and app.end_turn_button.visible and not app.end_turn_button.disabled,
		"real hand, pile, energy and End Turn refresh after cast")
	var settled := _state()
	old.call(_press())
	await _frames()
	_check(_state() == settled, "retired original click callback cannot exhaust the second copy")
	# Play a second copy through its actual rebuilt panel, not the cached callback.
	var second_panel := _panel(id)
	_check(second_panel != null and second_panel != panel and presenter._bindings.has(second_panel),
		"remaining real held copy gets a fresh single listener")
	if second_panel != null:
		var second := _oracle()
		var expected := CombatLanternMonkMothCloudCards.new().play_card(
			second.deck, second.party, second.enemies, id, 0)
		_check(expected.get("ok", false), "second copy still affordable")
		await _activate(second_panel, "enter")
		_check(presenter.last_event == expected and app.deck.exhausted.count(id) == 2
			and app.deck.discard_pile.count(id) == 0 and app.deck.hand.count(id) == 0
			and _deck_state(app.deck) == _deck_state(second.deck)
			and app.enemies.get_enemies() == second.enemies.get_enemies()
			and app.run_rng.state == second.rng.state,
			"second genuine play exhausts once and preserves one Blind per living foe")
	if neighbor:
		var tinker_panel := _panel("tinker_scatter_bolts")
		_check(tinker_panel != null and presenter._bindings.has(tinker_panel),
			"existing Tinker area remains actionable in shared hand")
		if tinker_panel != null:
			var energy_before: int = app.deck.energy
			await _activate(tinker_panel, "space")
			_check(presenter.last_event.get("ok", false)
				and app.deck.discard_pile.count("tinker_scatter_bolts") == 1
				and app.deck.energy < energy_before, "neighboring ordinary area still resolves")
	await _dispose()


func _phase() -> void:
	var panel := await _begin(IDS[0])
	if panel == null:
		await _dispose()
		return
	await _activate(panel, "mouse")
	_check(presenter.last_event.get("ok", false), "physical cast arms enemy phase Blind")
	var phase := CombatEnemyPhase.new()
	var hp_before: int = app.party.get_hero(1).hp
	var first := phase.execute_phase(app.party, app.enemies, [
		{"enemy_position": 1, "type": "attack", "amount": 5, "target_position": 1},
		{"enemy_position": 2, "type": "block", "amount": 4}])
	_check(first.get("ok", false) and first.events.size() == 2
		and not first.events[0].applied and first.events[1].applied,
		"first enemy's attack misses; second's nonattack executes")
	_check(app.party.get_hero(1).hp == hp_before
		and not app.enemies.get_enemy(1).statuses.has("blind_next_attack")
		and app.enemies.get_enemy(2).statuses.blind_next_attack == 1,
		"attack consumes only its own token; Block preserves the other")
	var second := phase.execute_phase(app.party, app.enemies, [
		{"enemy_position": 2, "type": "attack", "amount": 7, "target_position": 1}])
	_check(second.get("ok", false) and second.events.size() == 1
		and not second.events[0].applied and app.party.get_hero(1).hp == hp_before
		and not app.enemies.get_enemy(2).statuses.has("blind_next_attack"),
		"second enemy's subsequent attack misses and spends only its Blind")
	app._refresh_enemy_roster()
	_check(app.get_node("LiveEnemyRoster").enemies == app.enemies
		and is_instance_valid(app.get_node("LiveEnemyRoster").panel),
		"mounted enemy HUD remains active after phase")
	await _dispose()


func _denial(reason: String, queued: bool) -> void:
	var panel := await _begin(IDS[0])
	if panel == null:
		await _dispose()
		return
	var old: Callable = presenter._bindings[panel].callback
	if queued:
		panel.grab_focus()
		root.push_input(_key(KEY_ENTER), true)
		_check(not presenter._pending.is_empty(), "physical press queued before invalidation " + reason)
	match reason:
		"energy":
			app.deck.combat_state.energy = 1
		"owner":
			app.party._heroes[1].id = "scarecrow"
		"torn":
			app.party.apply_damage(2, 1000)
		"seat":
			var heroes: Array = app.party.get_heroes()
			var moved: Dictionary = heroes[0]
			heroes[0] = heroes[1]
			heroes[1] = moved
			app.party._heroes = CombatParty.new(heroes).get_heroes()
		"unheld":
			app.deck.discard_played(IDS[0])
			app.deck.discard_played(IDS[0])
		"identity":
			panel.get_child(0).text = "lantern_monk_moth_cloud_plus"
		"forged":
			panel.get_child(0).text = "lantern_monk_moth_cloud_forged"
		"status":
			app.enemies._enemies[0].statuses.blind_next_attack = 2
		"status_shape":
			app.party._heroes[1].statuses.cannot_buff_next_turn = 1
		"dead":
			app.enemies._enemies[0].hp = 0
			app.enemies._enemies[1].hp = 0
		"hidden":
			app.battle_view.hide()
		"closed":
			app._battle_closed = true
		"inactive":
			app.deck.combat_state.player_turn_active = false
		"turn":
			app.enemy_intents.advance_turn()
		"rebuild":
			app._refresh_hand()
		"result":
			app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"roster":
			app.enemies = CombatEnemies.new([{"id": "other", "max_hp": 30}])
		"deck":
			app.deck = CombatDeck.new([IDS[0]], app.run_rng)
		"rng":
			app.run_rng = RandomNumberGenerator.new()
		"deck_rng":
			app.deck._rng = RandomNumberGenerator.new()
		"intents":
			app.enemy_intents = CombatEnemyIntents.new(app._load_enemy_schedule())
	var before := _state()
	var event_before: Dictionary = presenter.last_event.duplicate(true)
	seed(37799)
	var global_next := randi()
	seed(37799)
	old.call(_press())
	if reason == "dead":
		# An already-finished external battle is observed on the next frame;
		# test the attempted deferred commit before that legitimate observer.
		if queued:
			var pending: Dictionary = presenter._pending.duplicate()
			if not pending.is_empty():
				presenter._commit(panel, IDS[0], pending.token, pending.receipt)
		_check(_state() == before and presenter.last_event == event_before,
			"dead roster refuses before result observation")
		app.enemies._enemies[1].hp = 30
		before = _state()
	await _frames()
	_check(_state() == before and presenter.last_event == event_before
		and randi() == global_next, "atomic refusal, no RNG or HUD/intent mutation: " + reason
		+ (" queued" if queued else " direct"))
	await _dispose()


func _stale_battle() -> void:
	var panel := await _begin(IDS[0])
	if panel == null:
		await _dispose()
		return
	var old_deck: CombatDeck = app.deck
	var old_party: CombatParty = app.party
	var old_enemies: CombatEnemies = app.enemies
	var old_rng: RandomNumberGenerator = app.run_rng
	var retired: Callable = presenter._bindings[panel].callback
	var old_state := [_deck_state(old_deck), old_party.get_heroes(),
		old_enemies.get_enemies(), old_rng.state]
	panel.grab_focus()
	root.push_input(_key(KEY_ENTER), true)
	_check(not presenter._pending.is_empty(), "real queued input precedes leaving old fight")
	app.return_button.pressed.emit()
	retired.call(_press())
	await _frames()
	_check([_deck_state(old_deck), old_party.get_heroes(),
		old_enemies.get_enemies(), old_rng.state] == old_state,
		"retired pending callback cannot pay after Return to title")
	_check(app._start_battle(), "genuine new battle starts after Return")
	await _frames()
	var fresh := _state()
	retired.call(_press())
	retired.call(_key(KEY_ENTER))
	await _frames()
	_check(_state() == fresh, "old panel callback cannot mutate next battle by mouse or key")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id in IDS:
		for mode in ["mouse", "enter", "space"]:
			await _success(id, 2, mode)
		await _success(id, 3, "mouse")
	await _success(IDS[0], 2, "mouse", true)
	await _phase()
	await _stale_battle()
	for reason in ["energy", "owner", "torn", "seat", "unheld", "identity", "forged",
			"status", "status_shape", "dead", "hidden", "closed", "inactive", "turn",
			"rebuild", "result", "roster", "deck", "rng", "deck_rng", "intents"]:
		for queued in [false, true]:
			await _denial(reason, queued)
	for failure in failures:
		printerr("FAIL: " + failure)
	print("live_lantern_monk_moth_cloud_hand_test: %d checks, %d failures" % [
		checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
