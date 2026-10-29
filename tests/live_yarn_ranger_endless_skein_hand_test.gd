extends "res://tests/live_support_hand_test.gd"
## Real mounted-hand proof for both authored rare printings. The paid resolver is never mocked.

const IDS := ["yarn_ranger_endless_skein", "yarn_ranger_endless_skein_plus"]


func _begin(id: String, seat: int = 2, slain_last: bool = false) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 290
	_check(app._start_battle(), "authentic scene starts an active battle")
	presenter = app.get_node("LiveAreaAttackAction")
	var rng := RandomNumberGenerator.new()
	rng.seed = 290
	var cards: Array[String] = [id, id, "warden_strike", "warden_brace", "tinker_tune_up"]
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.count(id) == 2, "two truly held copies drawn")
	app.deck.combat_state.energy = 6
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 25}]
	heroes.insert(seat - 1, {"id": "yarn_ranger", "name": "Yarn Ranger",
		"max_hp": 30, "statuses": {"weak": 1, "cannot_buff_next_turn": true}})
	app.party = CombatParty.new(heroes)
	app.enemies = CombatEnemies.new([
		{"id": "tangled", "max_hp": 50, "statuses": {"tangled": 2, "exposed": 1}},
		{"id": "blocked", "max_hp": 50, "statuses": {"bleed": 2}},
		{"id": "third", "max_hp": 50, "statuses": {"weak": 1}}])
	_check(app.party.is_valid() and app.enemies.is_valid(), "valid living party and foe roster")
	_check(app.enemies.gain_block(1, 3) and app.enemies.gain_block(2, 2)
		and app.enemies.gain_block(3, 1), "real pre-hit Block fixtures")
	if slain_last:
		_check(app.enemies.apply_damage(3, 1000), "third original slot slain before cast")
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
		"actual held ID has scene-bound area input")
	return panel


func _state() -> Array:
	return [_live(), app.battle_result.get_outcome(), app._battle_closed]


func _dispose() -> void:
	app.free()
	await _frames()


func _success(id: String, key: int, seat: int, slain_last: bool = false) -> void:
	var panel := await _begin(id, seat, slain_last)
	if panel == null:
		await _dispose()
		return
	var upgraded := id.ends_with("_plus")
	var damage := 6 if upgraded else 4
	var added := 3 if upgraded else 2
	var meta = app.get_node("LiveSupportHand")._metadata
	meta._update_visual(panel)
	var facts: Dictionary = meta.get_facts(panel)
	var face: Dictionary = presenter.face_text(panel)
	var printed_name := "Endless Skein+" if upgraded else "Endless Skein"
	_check(facts.known and facts.owner == "yarn_ranger" and facts.owner_text == "Yarn Ranger"
		and facts.display_name == printed_name and facts.cost == 3
		and facts.from_text.contains("2") and facts.from_text.contains("3"), "real catalog metadata owns correct name/seat/cost")
	_check(face.name == printed_name and face.owner == "Yarn Ranger"
		and face.cost == "3 energy" and face.effect == "Deal %d to all; then Tangled %d." % [damage, added]
		and face.from_pips == [false, true, true]
		and face.to_pips == [true, true, true] and face.thread,
		"mounted sewn cue spells damage/Tangled and all authored pips")
	_check(not presenter.face_children(panel).is_empty()
		and panel.tooltip_text.contains(printed_name)
		and panel.tooltip_text.contains("Yarn Ranger")
		and panel.tooltip_text.contains("3 energy")
		and panel.tooltip_text.contains("From 2,3")
		and panel.tooltip_text.contains("All living enemies 1,2,3")
		and panel.tooltip_text.contains("Tangled %d" % added)
		and panel.tooltip_text.contains("Weak/Exposed")
		and meta.base_effect_text(id).contains("newly applied Tangled does not boost")
		and meta.short_line(id) == face.effect, "mounted tooltip and catalog face tell true rules")
	_check(meta.visual_state(panel).playable and panel.self_modulate == Color.WHITE
		and panel.focus_mode == Control.FOCUS_ALL
		and panel.gui_input.get_connections().size() == 1,
		"legal interactive panel has exactly one live callback")
	var expected := _state().duplicate(true)
	var deck_state: Array = expected[0][0]
	deck_state[1].erase(id)
	deck_state[2].append(id)
	deck_state[3] -= 3
	# Weak x Exposed = floor(9/8 * printed damage); PRE-hit Tangled adds +2.
	var first_damage := int(floor(float(damage) * 9.0 / 8.0)) + 2
	var other_damage := int(floor(float(damage) * 3.0 / 4.0))
	expected[0][5][0].hp -= first_damage - 3
	expected[0][5][0].block = 0
	expected[0][5][0].statuses.tangled += added
	expected[0][5][1].hp -= other_damage - 2
	expected[0][5][1].block = 0
	expected[0][5][1].statuses.tangled = added
	if not slain_last:
		expected[0][5][2].hp -= other_damage - 1
		expected[0][5][2].block = 0
		expected[0][5][2].statuses.tangled = added
	var callback: Callable = presenter._bindings[panel].callback
	if key == 0:
		await _mouse(panel)
	else:
		panel.grab_focus()
		root.push_input(_key(key), true)
		root.push_input(_key(key), true)
		root.push_input(_key(key, false), true)
		await _frames()
	_check(_state() == expected,
		"exact live energy/hand/discard/HP/Block/status/party/intents/RNG after one cast")
	var hits: Array = [
		{"position": 1, "damage": first_damage, "block_absorbed": 3,
			"hp_loss": first_damage - 3, "tangled_added": added},
		{"position": 2, "damage": other_damage, "block_absorbed": 2,
			"hp_loss": other_damage - 2, "tangled_added": added}]
	if not slain_last:
		hits.append({"position": 3, "damage": other_damage, "block_absorbed": 1,
			"hp_loss": other_damage - 1, "tangled_added": added})
	_check(presenter.last_event == {
		"ok": true, "reason": "applied", "card_id": id, "cost": 3,
		"owner_position": seat, "base_damage": damage, "tangled_added": added,
		"target_positions": [1, 2] if slain_last else [1, 2, 3], "hits": hits},
		"unaltered original paid resolver receipt, ordered pre-hit strikes")
	var roster = app.get_node("LiveEnemyRoster")
	_check(roster.enemies == app.enemies and roster._status_tags.size() == 3,
		"visible enemy HUD still bound to authoritative roster")
	if roster._status_tags.size() == 3:
		for index in [0, 1]:
			var label = roster._status_tags[index].get_node("Caption")
			_check(roster._status_tags[index].visible
				and label.text.contains("Tangled %d" % expected[0][5][index].statuses.tangled),
				"enemy HUD displays new cumulative Tangled")
	# Fresh energy makes the remaining copy affordable, but this old panel is retired.
	app.deck.combat_state.energy = 6
	var before := _state()
	callback.call(_press())
	await _frames()
	_check(_state() == before and app.deck.hand.count(id) == 1
		and presenter._pending.is_empty(), "stale callback cannot spend remaining card")
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
		_check(not presenter._pending.is_empty(), "physical Enter queued before invalidation")
	match mode:
		"no_targets":
			for slot in [1, 2, 3]:
				app.enemies.apply_damage(slot, 1000)
		"energy": app.deck.combat_state.energy = 2
		"missing": app.party._heroes[1].id = "seamstress"
		"downed": app.party.apply_damage(2, 1000)
		"position":
			var heroes: Array = app.party.get_heroes()
			var first = heroes[0]
			heroes[0] = heroes[1]
			heroes[1] = first
			app.party._heroes = CombatParty.new(heroes).get_heroes()
			_check(app.party.get_hero(1).id == "yarn_ranger", "authentic owner illegally in front")
		"absent":
			app.deck.discard_played(id)
			app.deck.discard_played(id)
		"closed": app._battle_closed = true
		"turn": app.enemy_intents.advance_turn()
		"label": panel.get_child(0).text = IDS[1] if id == IDS[0] else IDS[0]
		"index": app.hand_view.move_child(panel, 4)
		"forged": app.deck.hand[panel.get_index()] = "yarn_ranger_unverified"
		"roster": app.enemies._enemies[0].position = 2
		"party_status": app.party._heroes[1].statuses = {"weak": "bad"}
		"rebuild": app._refresh_hand()
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"inactive": app.deck.combat_state.player_turn_active = false
		"status": app.enemies._enemies[0].statuses.exposed = "bad"
		"tangled_status": app.enemies._enemies[0].statuses.tangled = "bad"
		"overflow": app.enemies._enemies[0].statuses.tangled = CombatStatuses.MAX_INT
	app._refresh_intents()
	if mode != "rebuild":
		var meta = app.get_node("LiveSupportHand")._metadata
		meta._update_visual(panel)
		_check(not meta.visual_state(panel).playable and panel.self_modulate != Color.WHITE,
			"refused card visually dim: " + mode)
	if mode == "no_targets":
		# End-of-fight reward RNG belongs only to the app, not to a rejected card.
		app._observe_battle_result()
	var before := _state()
	callback.call(_press())
	await _frames()
	_check(_state() == before and presenter._pending.is_empty()
		and presenter.last_event.is_empty(), "pure refusal/no RNG/no double spend: " + mode)
	await _dispose()


func _lethal(id: String) -> void:
	var panel := await _begin(id, 3, true)
	if panel == null:
		await _dispose()
		return
	# Each living foe can be killed by the printed cast after the old Block absorbs.
	_check(app.enemies.apply_damage(1, 48) and app.enemies.apply_damage(2, 49),
		"real last-two-enemies lethal threshold fixture")
	var oracle := RandomNumberGenerator.new()
	oracle.seed = app.run_rng.seed
	oracle.state = app.run_rng.state
	var gold := oracle.randi_range(10, 20)
	await _mouse(panel)
	_check(presenter.last_event.get("ok", false)
		and presenter.last_event.hits.size() == 2
		and app.enemies.is_victorious()
		and app.battle_result.get_outcome() == CombatBattleResult.VICTORY
		and not app.deck.turn_active and app.end_turn_button.disabled,
		"confirmed lethal casts reach genuine app battle-result closure")
	_check(app.session_gold == gold and app.run_rng.state == oracle.state,
		"only regular victory reward advances RNG, never the Skein resolver")
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
	_check(not presenter._pending.is_empty(), "queued cast before teardown")
	app.return_button.pressed.emit()
	callback.call(_press())
	await _frames()
	_check([_snapshot(old_deck, old_party, old_rng), old_enemies.get_enemies()] == before,
		"teardown cancels queued card with no mutation to retired authorities")
	_check(app._start_battle(), "genuine replacement battle starts")
	await _frames()
	var fresh := _state()
	callback.call(_press())
	await _frames()
	_check(_state() == fresh, "retired panel cannot mutate replacement battle")
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
		"recognized catalog without live presenter cannot falsely enable")
	callback.call(_press())
	await _frames()
	_check(_state() == before, "removed presenter cannot pay from stale saved callback")
	presenter.free()
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id: String in IDS:
		for key in [0, KEY_ENTER, KEY_SPACE]:
			for seat in [2, 3]:
				await _success(id, key, seat)
		await _success(id, KEY_SPACE, 3, true)
		for mode in ["no_targets", "energy", "missing", "downed", "position", "absent",
				"closed", "turn", "label", "index", "forged", "roster", "party_status",
				"rebuild", "session", "inactive", "status", "tangled_status", "overflow"]:
			for queued in [false, true]:
				await _refusal(id, mode, queued)
		await _lethal(id)
		await _stale_battle(id)
		await _display_only(id)
	for failure in failures:
		printerr("FAIL: " + failure)
	print("live_yarn_ranger_endless_skein_hand_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

