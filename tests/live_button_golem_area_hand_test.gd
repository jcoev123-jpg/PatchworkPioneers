extends "res://tests/live_support_hand_test.gd"
## The shipped App scene, its actual five-card hand, one mounted area listener and
## the same paid CombatButtonGolemAreaCards service on an independent real fixture.

const IDS := ["button_golem_popping_volley", "button_golem_popping_volley_plus",
	"button_golem_buttonstorm", "button_golem_buttonstorm_plus"]


func _begin(id: String, seat: int = 1, pops: int = 2, last_enemy: bool = false,
		with_tinker_area: bool = false) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 290
	_check(app._start_battle(), "actual App opens real combat")
	presenter = app.get_node("LiveAreaAttackAction")
	var rng := RandomNumberGenerator.new()
	rng.seed = 290
	var cards: Array[String] = [id, id, "warden_strike", "warden_brace", "tinker_tune_up"]
	if with_tinker_area:
		cards[4] = "tinker_scatter_bolts"
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.count(id) == 2, "authentic five-card draw holds two copies")
	app.deck.combat_state.energy = 6
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 25}]
	heroes.insert(seat - 1, {"id": "button_golem", "name": "Button Golem", "max_hp": 48,
		"buttons_popped": pops, "statuses": {"dodge_next_attack": 1}})
	app.party = CombatParty.new(heroes)
	app.enemies = CombatEnemies.new([
		{"id": "front", "max_hp": 30, "statuses": {}},
		{"id": "middle", "max_hp": 30, "statuses": {"exposed": 1, "tangled": 1}},
		{"id": "rear", "max_hp": 30, "statuses": {"weak": 1}}])
	_check(app.party.is_valid() and app.enemies.is_valid() and app.party.get_hero(seat).max_hp == 48,
		"authentic Golem and three real enemy positions")
	_check(app.party.gain_block(seat, 7) and app.enemies.gain_block(2, 4),
		"owner Block and recipient Block precede any attack")
	if last_enemy:
		_check(app.enemies.apply_damage(1, 30) and app.enemies.apply_damage(3, 30),
			"two original slots slain")
		app.enemies._enemies[1].statuses.clear()
		app.enemies._enemies[1].hp = 1
		app.enemies._enemies[1].block = 0
	else:
		# First Volley hit on front is lethal; the second must be absent.
		app.enemies._enemies[0].hp = 3
		_check(app.enemies.apply_damage(3, 30), "rear slot slain without compaction")
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies,
		app.enemy_intents, app.battle_result)
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_hand()
	await _frames()
	var panel := _panel(id)
	_check(panel != null and panel.is_visible_in_tree() and presenter._bindings.has(panel),
		"actual hand panel owned by mounted LiveAreaAttackAction")
	return panel


func _authorities() -> Array:
	return [_snapshot(app.deck, app.party, app.run_rng),
		app.enemies.get_enemies(), app.enemy_intents.get_intents(),
		app.battle_result.get_outcome(), app._battle_closed, app.session_gold]


func _oracle() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = app.run_rng.seed
	rng.state = app.run_rng.state
	var deck := CombatDeck.new(["warden_strike"], rng)
	rng.state = app.run_rng.state
	deck.draw_pile = app.deck.draw_pile.duplicate()
	deck.hand = app.deck.hand.duplicate()
	deck.discard_pile = app.deck.discard_pile.duplicate()
	deck.combat_state.energy = app.deck.energy
	deck.combat_state.player_turn_active = app.deck.turn_active
	var party := CombatParty.new(app.party.get_heroes())
	party._heroes = app.party.get_heroes()
	var enemies := CombatEnemies.new(app.enemies.get_enemies())
	enemies._enemies = app.enemies.get_enemies()
	return {"rng": rng, "deck": deck, "party": party, "enemies": enemies}


func _dispose() -> void:
	app.free()
	await _frames()


func _face(panel: Control, id: String) -> void:
	var definition: Dictionary = ButtonGolemPoolCards.new().get_definition(id)
	var face: Dictionary = presenter.face_text(panel)
	var volley: bool = id.begins_with("button_golem_popping_volley")
	_check(presenter._definition(id) == definition and not definition.is_empty(),
		"each variant uses its own authentic pool record: " + id)
	_check(face.get("name") == definition.display_name and face.get("owner") == "Button Golem"
		and face.get("cost") == "2 energy" and face.get("thread") == true,
		"real sewn face prints name, owner, cost and linked targets")
	_check(face.get("from_pips") == ([true, true, false] if volley else [true, false, false])
		and face.get("to_pips") == [true, true, true], "authored source and destination pips")
	var rule: String = face.get("effect", "")
	var detail: String = panel.tooltip_text
	_check((rule.contains("independent hits") and detail.contains("check survival before each hit")
		if volley else rule.contains("prior popped button") and detail.contains("0 pops = 0 damage"))
		and detail.contains("From " + ("1,2" if volley else "1"))
		and detail.contains("enemies 1,2,3") and detail.contains("no target choice")
		and detail.contains("Block absorbs before HP") and detail.contains("2 energy"),
		"compact authored rule and complete live tooltip")
	var children: Array[Node] = presenter.face_children(panel)
	var names: Array[String] = []
	for child in children:
		names.append(str(child.name))
	_check(names.has("CardName") and names.has("Cost") and names.has("Owner")
		and names.has("Effect") and names.has("Positions") and names.has("To3"),
		"the visible face and pip nodes are real mounted children")
	_check(panel.gui_input.get_connections().size() == 1 and panel.focus_mode == Control.FOCUS_ALL
		and panel.is_visible_in_tree(), "exactly one mounted mouse/keyboard listener")


func _success(id: String, mode: String, seat: int, pops: int) -> void:
	var panel := await _begin(id, seat, pops)
	if panel == null:
		await _dispose()
		return
	_face(panel, id)
	var reference: Dictionary = _oracle()
	var oracle_event := CombatButtonGolemAreaCards.new().play_card(
		reference.deck, reference.party, reference.enemies, id, 0)
	_check(oracle_event.get("ok", false) and oracle_event.get("energy_spent") == 2,
		"independent real paid resolver accepted preconditions")
	var before := _authorities()
	var old_callback: Callable = presenter._bindings[panel].callback
	seed(99117)
	var expected_global := randi()
	seed(99117)
	if mode == "mouse":
		await _mouse(panel)
	else:
		panel.grab_focus()
		root.push_input(_key(KEY_ENTER if mode == "enter" else KEY_SPACE), true)
		root.push_input(_key(KEY_ENTER if mode == "enter" else KEY_SPACE), true)
		root.push_input(_key(KEY_ENTER if mode == "enter" else KEY_SPACE, false), true)
		await _frames()
	var expected := [_snapshot(reference.deck, reference.party, reference.rng),
		reference.enemies.get_enemies(), before[2], before[3], before[4], before[5]]
	_check(_authorities() == expected, "full hero/deck/enemy/intents/result/RNG snapshot equals isolated resolver: " + id + mode)
	_check(presenter.last_event == oracle_event and randi() == expected_global,
		"entire hit receipt matches independent resolver, no global RNG")
	_check(app.deck.energy == 4 and app.deck.discard_pile.count(id) == 1
		and app.deck.hand.count(id) == 1 and app.party.get_hero(seat).buttons_popped == pops
		and app.party.get_hero(seat).block == 7, "two energy, one discard, preserved button counter and Block")
	_check(app.enemies.get_enemy(3).position == 3 and app.enemies.is_slain(3),
		"slain third slot is not compacted or attacked")
	if id.begins_with("button_golem_popping_volley"):
		_check(oracle_event.hit_count == 2 and oracle_event.hits.filter(
			func(hit): return hit.position == 1).size() == 1
			and oracle_event.hits.filter(func(hit): return hit.position == 2).size() == 2,
			"first-hit lethal skip; two independent status/Block hits on surviving middle")
	else:
		_check(oracle_event.hit_count == 1 and oracle_event.base_damage ==
			(5 if id.ends_with("_plus") else 4) * pops and oracle_event.hits.size() == 2,
			"zero/one/two prior popped buttons scale each living recipient, never consumed")
	_check(app.pile_label.text == "Draw: %d | Discard: %d" % [
		app.deck.draw_pile.size(), app.deck.discard_pile.size()]
		and app.get_node("LiveSupportHand").energy_label.text == "%d" % app.deck.energy
		and app.hero_panels[seat - 1].get_child(0).text.contains("Block: 7"),
		"after-cast mounted piles, energy and actor HUD refreshed")
	var settled := _authorities()
	old_callback.call(_press())
	await _frames()
	_check(_authorities() == settled, "retired click never spends affordable second copy")
	await _dispose()


func _denial(mode: String, queued: bool, id: String = "button_golem_popping_volley") -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	var callback: Callable = presenter._bindings[panel].callback
	if queued:
		panel.grab_focus()
		root.push_input(_key(KEY_ENTER), true)
		_check(not presenter._pending.is_empty(), "real physical input queued before " + mode)
	match mode:
		"unheld":
			app.deck.discard_played(id)
			app.deck.discard_played(id)
		"identity":
			panel.get_child(0).text = "button_golem_buttonstorm"
		"energy":
			app.deck.combat_state.energy = 1
		"owner":
			app.party._heroes[0].id = "seamstress"
		"seat":
			var heroes: Array = app.party.get_heroes()
			var first = heroes[0]
			heroes[0] = heroes[2]
			heroes[2] = first
			app.party._heroes = CombatParty.new(heroes).get_heroes()
		"torn":
			app.party.apply_damage(1, 1000)
		"targets":
			app.enemies._enemies[0].hp = 0
			app.enemies._enemies[1].hp = 0
		"counter":
			app.party._heroes[0].buttons_popped = -1
		"counter_type":
			app.party._heroes[0].buttons_popped = "2"
		"status":
			app.enemies._enemies[1].statuses.exposed = "bad"
		"dodge":
			app.party._heroes[0].statuses.dodge_next_attack = 2
		"hidden":
			app.battle_view.hide()
		"finished":
			app._battle_closed = true
		"turn":
			app.enemy_intents.advance_turn()
		"relabel":
			panel.get_child(0).text = "wrong"
		"rebuild":
			app._refresh_hand()
		"result":
			app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"roster":
			app.enemies = CombatEnemies.new([{"id": "other", "max_hp": 30}])
		"deck":
			app.deck = CombatDeck.new([id], app.run_rng)
		"rng":
			app.run_rng = RandomNumberGenerator.new()
		"deck_rng":
			app.deck._rng = RandomNumberGenerator.new()
		"intents":
			app.enemy_intents = CombatEnemyIntents.new(app._load_enemy_schedule())
	var current := _authorities()
	var previous_event: Dictionary = presenter.last_event.duplicate(true)
	seed(77111)
	var next_global := randi()
	seed(77111)
	if mode == "targets":
		_check(CombatButtonGolemAreaCards.new()._prepare(app.deck, app.party,
			app.enemies, id, 0).get("reason") == "no_living_targets"
			and not presenter._eligible(panel, id), "all slain slots deny a paid cast")
	callback.call(_press())
	if mode == "targets":
		# Assert before the independent App result observer legitimately settles an
		# already-won fight; consume a queued callback at its real commit entry.
		if queued:
			var receipt: Dictionary = presenter._pending.duplicate()
			presenter._commit(panel, id, receipt.token, receipt.receipt)
		_check(_authorities() == current and presenter.last_event == previous_event,
			"no-target play never pays or changes any actor before result observation")
		# Restore one enemy before the next process frame. This isolates the
		# attempted invalid cast from the App's automatic victory settlement.
		app.enemies._enemies[1].hp = 30
		current = _authorities()
	await _frames()
	_check(_authorities() == current and presenter.last_event == previous_event
		and randi() == next_global, "denial is atomic and does not consume RNG: " + mode
		+ (" queued" if queued else " direct"))
	await _dispose()


func _terminal_and_stale(id: String) -> void:
	var panel := await _begin(id, 1, 2, true)
	if panel == null:
		await _dispose()
		return
	var oracle := RandomNumberGenerator.new()
	oracle.seed = app.run_rng.seed
	oracle.state = app.run_rng.state
	var expected_gold := oracle.randi_range(10, 20)
	await _mouse(panel)
	_check(presenter.last_event.get("ok", false) and app.enemies.is_victorious()
		and app.battle_result.get_outcome() == CombatBattleResult.VICTORY
		and app._battle_closed and not app.deck.turn_active and app.end_turn_button.disabled,
		"final genuine attack closes battle exactly once")
	_check(app.session_gold == expected_gold and app.run_rng.state == oracle.state,
		"only the existing victory gold claim consumes run RNG")
	var gold: int = app.session_gold
	var state := _authorities()
	app._observe_battle_result()
	_check(_authorities() == state and app.session_gold == gold,
		"reobserving victory never grants reward twice")
	await _dispose()
	panel = await _begin(id)
	if panel == null:
		await _dispose()
		return
	var old_deck: CombatDeck = app.deck
	var old_party: CombatParty = app.party
	var old_enemies: CombatEnemies = app.enemies
	var old_rng: RandomNumberGenerator = app.run_rng
	var before := [_snapshot(old_deck, old_party, old_rng), old_enemies.get_enemies()]
	var old_callback: Callable = presenter._bindings[panel].callback
	panel.grab_focus()
	root.push_input(_key(KEY_ENTER), true)
	_check(not presenter._pending.is_empty(), "old genuine panel queued before Return")
	app.return_button.pressed.emit()
	old_callback.call(_press())
	await _frames()
	_check([_snapshot(old_deck, old_party, old_rng), old_enemies.get_enemies()] == before,
		"retired queued cast did not mutate old fight")
	_check(app._start_battle(), "new genuine fight after Return")
	await _frames()
	var fresh := _authorities()
	old_callback.call(_press())
	await _frames()
	_check(_authorities() == fresh, "retired callback cannot mutate next battle")
	await _dispose()


func _existing_area_still_plays() -> void:
	var golem_panel := await _begin(IDS[0], 1, 2, false, true)
	if golem_panel == null:
		await _dispose()
		return
	var other := _panel("tinker_scatter_bolts")
	_check(other != null and presenter._bindings.has(other)
		and other.gui_input.get_connections().size() == 1
		and presenter._bindings.has(golem_panel),
		"genuine mixed hand binds each original area only once beside Golem")
	if other != null and presenter._bindings.has(other):
		var energy_before: int = app.deck.energy
		other.grab_focus()
		root.push_input(_key(KEY_SPACE), true)
		root.push_input(_key(KEY_SPACE, false), true)
		await _frames()
		_check(presenter.last_event.get("ok", false)
			and app.deck.energy == energy_before - 1
			and app.deck.discard_pile.count("tinker_scatter_bolts") == 1
			and app.deck.hand.has(IDS[0]) and app.battle_result.can_continue(),
			"existing Tinker area keyboard route still commits alongside held Golem")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id: String in IDS:
		for mode in ["mouse", "enter", "space"]:
			await _success(id, mode, 2 if id.begins_with("button_golem_popping_volley") else 1, 2)
		if id.begins_with("button_golem_buttonstorm"):
			for pops in [0, 1]:
				await _success(id, "mouse", 1, pops)
		await _terminal_and_stale(id)
	for mode in ["unheld", "identity", "energy", "owner", "seat", "torn",
			"targets", "counter", "counter_type", "status", "dodge", "hidden",
			"finished", "turn", "relabel", "rebuild", "result", "roster",
			"deck", "rng", "deck_rng", "intents"]:
		for queued in [false, true]:
			await _denial(mode, queued)
	await _existing_area_still_plays()
	for failure in failures:
		printerr("FAIL: " + failure)
	print("live_button_golem_area_hand_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
