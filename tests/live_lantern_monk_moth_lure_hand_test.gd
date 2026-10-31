extends "res://tests/live_support_hand_test.gd"
## Mounted, seeded shared-hand Moth Lure integration. No scene-free-only green path.

const BASE := "lantern_monk_moth_lure"
const PLUS := "lantern_monk_moth_lure_plus"


func _begin_lure(id: String, seat: int) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 4106
	_check(app._start_battle(), "real App opens routed combat")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4106
	var cards: Array[String] = [id, id, id, id, id,
		"warden_strike", "warden_brace", "tinker_tune_up"]
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.size() == 5
		and app.deck.hand.has(id), "seeded genuine shared hand holds the printing")
	var heroes: Array = [
		{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 25}]
	heroes.insert(seat - 1, {"id": "lantern_monk",
		"name": "Lantern Monk", "max_hp": 30})
	app.party = CombatParty.new(heroes)
	app.enemies = CombatEnemies.new([
		{"id": "front", "max_hp": 30, "statuses": {"weak": 1}},
		{"id": "middle", "max_hp": 30, "statuses": {"blind_next_attack": 1}},
		{"id": "rear", "max_hp": 30, "statuses": {"tangled": 1}}])
	_check(app.party.is_valid() and app.enemies.is_valid()
		and app.party.get_hero(seat).id == "lantern_monk"
		and app.enemies.get_enemies().size() == 3,
		"living unique Monk at legal seat and three original enemy positions")
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies,
		app.enemy_intents, app.battle_result)
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_hand()
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	presenter._sync_battle()
	var panel := _panel(id)
	_check(panel != null and presenter._bindings.has(panel)
		and panel.is_visible_in_tree() and panel.focus_mode == Control.FOCUS_ALL,
		"actual mounted attack presenter binds the held card")
	return panel


func _full_state() -> Array:
	return [
		app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.exhausted.duplicate(),
		app.deck.energy, app.deck.turn_active,
		app.party.get_heroes(), app.enemies.get_enemies(),
		app.run_rng.seed, app.run_rng.state,
		app.enemy_intents.get_intents(), app.enemy_intents._turn_index,
		app.battle_result.get_outcome(), app._battle_closed,
		app.session_gold, app.enemy_attacks.duplicate(true)]


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


func _face(panel: Control, id: String) -> void:
	var meta = app.get_node("LiveSupportHand")._metadata
	var card := LanternMonkPoolCards.new().get_definition(id)
	var facts: Dictionary = meta.get_facts(panel)
	_check(CombatLanternMonkMothLureCards.new().is_supported_card(id)
		and presenter._definition(id) == card and meta.definition(id) == card,
		"both presenters use one authenticated catalog printing")
	_check(facts.get("known", false) and facts.get("display_name") == card.display_name
		and facts.get("cost") == card.cost and facts.get("owner_text") == "Lantern Monk"
		and facts.get("target_text", "").contains("enemy")
		and facts.get("rules", "").contains("Blind")
		and facts.get("rules", "").contains("draw 1")
		and not facts.get("rules", "").contains("Deal"),
		"mounted face correctly prints name, Monk, cost, target, Blind and draw without hit")
	_check(panel.tooltip_text.contains(card.display_name)
		and panel.tooltip_text.contains("%d energy" % card.cost)
		and panel.tooltip_text.contains("From 2–3")
		and panel.tooltip_text.contains("Blind")
		and panel.tooltip_text.contains("draw 1")
		and panel.tooltip_text.contains("No attack or damage"),
		"Help states actual authored control and source/target positions")
	_check(meta.visual_state(panel).get("playable", false)
		and panel.self_modulate == Color.WHITE,
		"genuine mounted picker makes payable card bright")


func _dispose() -> void:
	app.free()
	await _frames()


func _success(id: String, seat: int, position: int, mode: String) -> Array:
	var panel := await _begin_lure(id, seat)
	if panel == null:
		await _dispose()
		return []
	_face(panel, id)
	var before: Array = _full_state()
	var reference := _oracle()
	var expected := CombatLanternMonkMothLureCards.new().play_card(
		reference.deck, reference.party, reference.enemies, id, position)
	_check(expected.get("ok", false) and expected.get("target_position") == position
		and expected.get("target_id") == ["front", "middle", "rear"][position - 1],
		"independent resolver succeeds for intended original enemy ID")
	if not expected.get("ok", false):
		await _dispose()
		return []
	var preview: Dictionary = presenter._target_preview(id)
	_check(preview.get("playable", false) and preview.get("target_positions") == [1, 2, 3]
		and preview.get("hits", []).size() == 3,
		"read-only mounted forecast offers only authentic living positions")
	for target in preview.hits:
		_check(not target.has("damage") and target.get("draw") == 1
			and target.get("blind_after") == 1, "forecast never invents hit damage")
	_check(_full_state() == before, "preview cannot mutate RNG, statuses or resources")
	if mode == "pointer":
		await _mouse(panel)
	elif mode in ["enter", "space"]:
		panel.grab_focus()
		await _keyboard(KEY_ENTER if mode == "enter" else KEY_SPACE)
	else:
		await _keyboard(KEY_P)
	_check(presenter.current_forecast.get("playable", false)
		and presenter.cue.text.contains("Blind") and presenter.cue.text.contains("draw 1")
		and not presenter.cue.text.contains("damage"), "mounted selected target cue shows control only")
	_check(_full_state() == before, "arming mouse/keyboard selector is read-only")
	if mode == "pointer":
		var roster = app.get_node("LiveEnemyRoster")
		await _mouse(roster._labels[position - 1])
	else:
		await _keyboard(KEY_1 + position - 1)
	_check(presenter.last_event == expected, "one deferred commit uses paid receipt and selected target ID")
	_check(app.deck.energy == before[4] - int(expected.cost)
		and app.deck.discard_pile.count(id) >= 1
		and expected.draw_requested == 1,
		"printed energy, discard and single real draw")
	_check(app.deck.hand == reference.deck.hand
		and app.deck.draw_pile == reference.deck.draw_pile
		and app.deck.discard_pile == reference.deck.discard_pile
		and app.deck.exhausted == reference.deck.exhausted
		and app.party.get_heroes() == reference.party.get_heroes()
		and app.enemies.get_enemies() == reference.enemies.get_enemies()
		and app.run_rng.state == reference.rng.state,
		"full paid state and seeded RNG exactly equal independent oracle")
	_check(not presenter.last_event.has("hits") and not presenter.last_event.has("damage")
		and not presenter.last_event.has("hp_loss"),
		"control receipt has no phantom hit or damage")
	var roster: Array[Dictionary] = app.enemies.get_enemies()
	for index in range(roster.size()):
		var expected_blind := 1 if index == position - 1 else (1 if index == 1 else 0)
		_check(int(roster[index].get("statuses", {}).get("blind_next_attack", 0)) == expected_blind,
			"only chosen foe gains/keeps one Blind token")
	_check(app.pile_label.text == "Draw: %d | Discard: %d" % [
			app.deck.draw_pile.size(), app.deck.discard_pile.size()]
		and app.get_node("LiveSupportHand").energy_label.text == "%d" % app.deck.energy
		and app.hand_view.get_child_count() == app.deck.hand.size()
		and app.get_node("LiveEnemyRoster").enemies == app.enemies,
		
		"real hand, energy and pile HUD refreshed after paid cast")
	var done: Array = _full_state()
	await _dispose()
	return done


func _phase() -> void:
	var panel := await _begin_lure(BASE, 2)
	if panel == null:
		await _dispose()
		return
	await _mouse(panel)
	await _keyboard(KEY_1)
	_check(presenter.last_event.get("ok", false), "live cast armed Blind for enemy phase")
	var phase := CombatEnemyPhase.new()
	var hp_before: int = app.party.get_hero(1).hp
	var first := phase.execute_phase(app.party, app.enemies, [
		{"enemy_position": 1, "type": "attack", "amount": 6, "target_position": 1},
		{"enemy_position": 2, "type": "block", "amount": 3}])
	_check(first.get("ok", false) and first.events.size() == 2
		and not first.events[0].applied and first.events[1].applied
		and app.party.get_hero(1).hp == hp_before,
		"real enemy attack misses while nonattack resolves")
	_check(not app.enemies.get_enemy(1).statuses.has("blind_next_attack")
		and app.enemies.get_enemy(2).statuses.get("blind_next_attack") == 1,
		"attack spends once; Block intent preserves second Blind")
	var second := phase.execute_phase(app.party, app.enemies, [
		{"enemy_position": 2, "type": "attack", "amount": 4, "target_position": 1}])
	_check(second.get("ok", false) and not second.events[0].applied
		and not app.enemies.get_enemy(2).statuses.has("blind_next_attack"),
		"next actual attack spends preserved Blind exactly once")
	await _dispose()


func _refusal(mode: String, queued: bool) -> void:
	var panel := await _begin_lure(BASE, 2)
	if panel == null:
		await _dispose()
		return
	if queued:
		await _mouse(panel)
		presenter._queue_attack(2)
	match mode:
		"owner_missing": app.party._heroes[1].id = "other"
		"owner_torn": app.party.apply_damage(2, 999)
		"wrong_seat":
			var monk: Dictionary = app.party._heroes[1]
			app.party._heroes[1] = app.party._heroes[0]
			app.party._heroes[0] = monk
			app.party._heroes[0].position = 1
			app.party._heroes[1].position = 2
		"absent": app.deck.hand.erase(BASE)
		"energy": app.deck.combat_state.energy = 0
		"dead_enemy": app.enemies.apply_damage(2, 999)
		"replaced_target": app.enemies._enemies[1].id = "replacement"
		"closed": app._battle_closed = true
		"new_turn": app.enemy_intents.advance_turn()
		"rebind": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"cancel": presenter._cancel_choice()
		"redraw": app._refresh_hand()
	var before: Array = _full_state()
	if not queued:
		presenter._sync_battle()
		if mode in ["owner_missing", "owner_torn", "wrong_seat", "absent", "energy", "closed"]:
			var meta = app.get_node("LiveSupportHand")._metadata
			if meta._bindings.has(panel):
				meta._update_visual(panel)
				_check(not meta.visual_state(panel).get("playable", true),
					"%s: authentic unavailable printing stays dim" % mode)
		if presenter._bindings.has(panel):
			presenter._select(_press(), panel)
			presenter._queue_attack(2)
	await _frames()
	_check(_full_state() == before,
		"%s queued=%s: refused action preserves full model and RNG" % [mode, queued])
	_check(not presenter.last_event.get("ok", false),
		"%s queued=%s: no paid receipt or phantom hit" % [mode, queued])
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id in [BASE, PLUS]:
		for seat in [2, 3]:
			for position in [1, 2, 3]:
				await _success(id, seat, position,
					"pointer" if position == 2 else ("enter" if position == 1 else "space"))
	var first := await _success(PLUS, 3, 2, "pointer")
	var replay := await _success(PLUS, 3, 2, "pointer")
	await _success(BASE, 2, 1, "keyboard")
	_check(not first.is_empty() and first == replay, "seeded real mounted replay deterministic")
	await _phase()
	for mode in ["owner_missing", "owner_torn", "wrong_seat", "absent",
			"energy", "dead_enemy", "replaced_target", "closed", "new_turn",
			"rebind", "cancel", "redraw"]:
		for queued in ([true] if mode in ["replaced_target", "new_turn", "rebind", "cancel"] else [false, true]):
			await _refusal(mode, queued)
	_finish()
