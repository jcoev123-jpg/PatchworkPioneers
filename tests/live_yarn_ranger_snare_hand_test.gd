extends "res://tests/live_support_hand_test.gd"
## Actual scene-mounted area action, using the shared physical input harness.

const IDS := ["yarn_ranger_snare_net", "yarn_ranger_snare_net_plus"]


func _begin(id: String, seat: int = 2) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 290
	_check(app._start_battle(), "mounted battle starts")
	presenter = app.get_node("LiveAreaAttackAction")
	var rng := RandomNumberGenerator.new()
	rng.seed = 290
	var cards: Array[String] = [id, id, "warden_strike", "warden_brace", "tinker_tune_up"]
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.count(id) == 2, "two genuine drawn copies")
	app.deck.combat_state.energy = 2
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


func _success(id: String, key: int, seat: int, untangled: bool = false) -> void:
	var panel := await _begin(id, seat)
	if panel == null:
		await _dispose()
		return
	if untangled:
		app.enemies._enemies[0].statuses.erase("tangled")
		app._refresh_enemy_roster()
	var meta = app.get_node("LiveSupportHand")._metadata
	meta._update_visual(panel)
	var facts: Dictionary = meta.get_facts(panel)
	var face: Dictionary = presenter.face_text(panel)
	var added := 2 if id.ends_with("_plus") else 1
	var name := "Snare Net+" if added == 2 else "Snare Net"
	_check(facts.known and facts.owner == "yarn_ranger" and facts.owner_text == "Yarn Ranger" and facts.cost == 2, "authentic metadata")
	_check(face.name == name and face.owner == "Yarn Ranger" and face.cost == "2 energy"
		and face.effect == "Tangled %d to all living enemies." % added
		and face.from_pips == [false, true, true] and face.to_pips == [true, true, true] and face.thread, "mounted authored name/rule/owner/pips")
	_check(not presenter.face_children(panel).is_empty() and panel.tooltip_text.contains("Tangled %d" % added)
		and panel.tooltip_text.contains("Yarn Ranger") and panel.tooltip_text.contains("2 energy"), "mounted face and tooltip")
	_check(meta._rules(id) == face.effect and meta.base_effect_text(id).contains("Tangled %d" % added), "sewn rules agree")
	_check(meta.visual_state(panel).playable and panel.self_modulate == Color.WHITE
		and panel.gui_input.get_connections().size() == 1, "one playable callback")
	var expected := _state().duplicate(true)
	expected[0][0][1].erase(id)
	expected[0][0][2].append(id)
	expected[0][0][3] -= 2
	for index in [0, 1]:
		var statuses: Dictionary = expected[0][5][index].statuses
		statuses.tangled = statuses.get("tangled", 0) + added
	var callback: Callable = presenter._bindings[panel].callback
	if key != 0:
		panel.grab_focus()
		root.push_input(_key(key), true)
		root.push_input(_key(key), true)
		root.push_input(_key(key, false), true)
		await _frames()
	else:
		await _mouse(panel)
	_check(_state() == expected, "exact payment/discard/statuses; HP/Block/party/intents/RNG unchanged")
	_check(presenter.last_event == {"ok": true, "reason": "applied", "card_id": id, "cost": 2,
		"owner_position": seat, "tangled_added": added, "target_positions": [1, 2]}, "actual service receipt forwarded")
	var roster = app.get_node("LiveEnemyRoster")
	_check(roster.enemies == app.enemies and roster._status_tags.size() == 3, "real enemy display bound")
	if roster._status_tags.size() == 3:
		for index in [0, 1]:
			var tag = roster._status_tags[index]
			_check(tag.visible and tag.get_node("Caption").text.contains("Tangled %d" % expected[0][5][index].statuses.tangled), "live Tangled plaque refreshed")
	# Remaining copy is affordable: only the retired listener prevents replay.
	app.deck.combat_state.energy = 2
	var before := _state()
	callback.call(_press())
	await _frames()
	_check(_state() == before and app.deck.hand.count(id) == 1, "retired callback cannot replay affordable copy")
	await _dispose()


func _refusal(id: String, mode: String, queued: bool) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	var callback: Callable = presenter._bindings[panel].callback
	if queued:
		panel.grab_focus()
		root.push_input(_key(KEY_ENTER), true)
		_check(not presenter._pending.is_empty(), "actual input queued before invalidation")
	match mode:
		"targets":
			app.enemies.apply_damage(1, 1000)
			app.enemies.apply_damage(2, 1000)
		"energy": app.deck.combat_state.energy = 1
		"missing": app.party._heroes[1].id = "seamstress"
		"downed": app.party.apply_damage(2, 1000)
		"position":
			var heroes: Array = app.party.get_heroes()
			var first = heroes[0]
			heroes[0] = heroes[1]
			heroes[1] = first
			app.party._heroes = CombatParty.new(heroes).get_heroes()
			_check(app.party.get_hero(1).id == "yarn_ranger", "valid front-seat owner")
		"absent":
			app.deck.discard_played(id)
			app.deck.discard_played(id)
		"closed": app._battle_closed = true
		"turn": app.enemy_intents.advance_turn()
		"label": panel.get_child(0).text = IDS[1] if id == IDS[0] else IDS[0]
		"index": app.hand_view.move_child(panel, 4)
		"forged": app.deck.hand[panel.get_index()] = "yarn_ranger_unwired"
		"roster": app.enemies._enemies[0].position = 2
		"party_status": app.party._heroes[0].statuses = {"weak": "bad"}
		"rebuild": app._refresh_hand()
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"inactive": app.deck.combat_state.player_turn_active = false
		"status": app.enemies._enemies[0].statuses.exposed = "bad"
	# Settle the HUD's legitimate response to the changed fixture before input.
	if mode == "targets":
		_check(not presenter._eligible(panel, id), "all-slain roster refuses before terminal observation")
	app._refresh_intents()
	if mode != "rebuild":
		var meta = app.get_node("LiveSupportHand")._metadata
		meta._update_visual(panel)
		_check(not meta.visual_state(panel).playable and panel.self_modulate != Color.WHITE, "unavailable dim face: " + mode)
	if mode == "targets":
		# The app legitimately closes victory, rebuilds the hand and draws reward RNG.
		# Complete that observation before the no-cast snapshot.
		app._observe_battle_result()
	var before := _state()
	callback.call(_press())
	await _frames()
	_check(_state() == before and presenter._pending.is_empty() and presenter.last_event.is_empty(), "full no-spend and no queued settlement: " + mode)
	await _dispose()


func _stale_battle(id: String) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	var callback: Callable = presenter._bindings[panel].callback
	var old_deck: CombatDeck = app.deck
	var old_party: CombatParty = app.party
	var old_enemies: CombatEnemies = app.enemies
	var old_rng: RandomNumberGenerator = app.run_rng
	var before := [_snapshot(old_deck, old_party, old_rng), old_enemies.get_enemies()]
	panel.grab_focus()
	root.push_input(_key(KEY_ENTER), true)
	_check(not presenter._pending.is_empty(), "cast queued before leaving battle")
	app.return_button.pressed.emit()
	callback.call(_press())
	await _frames()
	_check([_snapshot(old_deck, old_party, old_rng), old_enemies.get_enemies()] == before,
		"closed battle and queued retired callback preserve old authorities")
	_check(app._start_battle(), "replacement real battle starts")
	await _frames()
	var fresh := _state()
	callback.call(_press())
	await _frames()
	_check(_state() == fresh, "stale panel cannot mutate replacement battle")
	await _dispose()


func _display_only(id: String) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	var meta = app.get_node("LiveSupportHand")._metadata
	var callback: Callable = presenter._bindings[panel].callback
	var before := _state()
	app.remove_child(presenter)
	meta._update_visual(panel)
	_check(meta.get_facts(panel).known and not meta.visual_state(panel).playable
		and panel.self_modulate != Color.WHITE and panel.gui_input.get_connections().is_empty(),
		"catalog knowledge without mounted authority stays dim and unbound")
	callback.call(_press())
	await _frames()
	_check(_state() == before, "removed presenter cannot cast from saved callback")
	presenter.free()
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id: String in IDS:
		for key in [0, KEY_ENTER, KEY_SPACE]:
			for seat in [2, 3]:
				await _success(id, key, seat)
		await _success(id, KEY_SPACE, 3, true)
		for mode in ["targets", "energy", "missing", "downed", "position", "absent", "closed", "turn", "label", "index", "forged", "roster", "party_status", "rebuild", "session", "inactive", "status"]:
			for queued in [false, true]:
				await _refusal(id, mode, queued)
		await _stale_battle(id)
		await _display_only(id)
	for failure in failures:
		printerr("FAIL: " + failure)
	print("live_yarn_ranger_snare_hand_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
