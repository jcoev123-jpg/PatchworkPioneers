extends "res://tests/live_support_hand_test.gd"

const FORMS := {
	"rag_duelist_cape_parry": [4, 2],
	"rag_duelist_cape_parry_plus": [6, 3],
	"rag_duelist_cape_guard": [5, 3],
	"rag_duelist_cape_guard_plus": [7, 4],
	"rag_duelist_duelist_reprise": [0, 5],
	"rag_duelist_duelist_reprise_plus": [0, 7],
}
const BASE := "rag_duelist_cape_parry"


func _begin(id: String, seat: int = 2) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 337
	_check(app._start_battle(), "real standalone battle starts")
	presenter = app.get_node("LiveRagDuelistRiposteHand")
	var rng := RandomNumberGenerator.new()
	rng.seed = 337
	var cards: Array[String] = [id, id, "warden_strike", "warden_brace", "tinker_tune_up"]
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.count(id) == 2, "two genuine held copies")
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40, "statuses": {}},
		{"id": "tinker", "name": "Tinker", "max_hp": 30, "statuses": {}}]
	heroes.insert(seat - 1, {"id": "rag_duelist", "name": "Rag Duelist", "max_hp": 30, "statuses": {}})
	app.party = CombatParty.new(heroes)
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies, app.enemy_intents, app.battle_result)
	app._refresh_party()
	app._refresh_hand()
	await _frames()
	var panel := _pool_panel(id)
	_check(panel != null and panel.is_visible_in_tree() and presenter._bindings.has(panel),
		"real held panel bound by scene-mounted adapter")
	var metadata = app.get_node("LiveSupportHand")._metadata
	metadata._update_visual(panel)
	_check(metadata.visual_state(panel).playable == (seat != 3 or not id.contains("reprise")),
		"metadata queries actual mounted legal cast")
	return panel


func _state() -> Array:
	return [_snapshot(app.deck, app.party, app.run_rng), app.enemies.get_enemies()]


func _dispose() -> void:
	app.free()
	await _frames()


func _cast(panel: Control, keyboard: bool) -> void:
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(panel)


func _assert_cast(panel: Control, id: String, seat: int, keyboard: bool) -> void:
	var callback: Callable = presenter._bindings[panel].callback
	var before := _state()
	await _cast(panel, keyboard)
	var expected := before.duplicate(true)
	expected[0][1].erase(id)
	expected[0][2].append(id)
	expected[0][3] -= 1
	expected[0][5][seat - 1].block += FORMS[id][0]
	expected[0][5][seat - 1].statuses["riposte"] = FORMS[id][1]
	_check(_state() == expected, "exact one-copy payment, owner-only authored Block/Riposte: " + id)
	_check(presenter.last_event.get("ok", false), "resolver confirms paid cast")
	_check(app.pile_label.text.contains("Discard: %d" % app.deck.discard_pile.size())
		and app.get_node("LiveSupportHand").energy_label.text == str(app.deck.energy),
		"real energy and pile UI refreshed")
	var label: Label = app.hero_panels[seat - 1].get_child(0)
	_check(label.text.contains("Block: %d" % app.party.get_hero(seat).block)
		and label.text.contains(str(app.party.get_hero(seat).hp)), "real owner HP/Block refreshed")
	_check(presenter._pending.is_empty(), "self cast has no target selection")
	var after := _state()
	callback.call(_press())
	await _frames()
	_check(_state() == after, "retired listener cannot replay")
	var remaining := _pool_panel(id)
	if remaining != null:
		_check(presenter._bindings.has(remaining), "surviving copy rebound on redraw")
		var metadata = app.get_node("LiveSupportHand")._metadata
		metadata._update_visual(remaining)
		_check(not metadata.visual_state(remaining).playable, "active Riposte metadata stays dim")
		await _cast(remaining, not keyboard)
		_check(_state() == after, "active Riposte rejects surviving copy without spend")


func _negative(mode: String, queued: bool) -> void:
	var id: String = "rag_duelist_duelist_reprise" if mode == "seat" else BASE
	var panel := await _begin(id, 3 if mode == "seat" else 2)
	var callback: Callable = presenter._bindings[panel].callback
	if queued:
		callback.call(_press())
	var token: int = presenter._token
	var receipt: Dictionary = presenter._pending.get("receipt", {}).duplicate()
	match mode:
		"active": app.party._heroes[1].statuses["riposte"] = 2
		"energy": app.deck.combat_state.energy = 0
		"owner": app.party._heroes[1].id = "missing"
		"down": app.party.apply_damage(2, 999)
		"hand": app.deck.hand[panel.get_index()] = "forged"
		"label": panel.get_child(0).text = "forged"
		"redraw": app._refresh_hand()
		"closed": app._battle_closed = true
		"turn": app.enemy_intents.advance_turn()
		"inactive": app.deck.combat_state.player_turn_active = false
		"result": app.battle_result._outcome = CombatBattleResult.DEFEAT
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"party": app.party = CombatParty.new(app.party.get_heroes())
		"enemies": app.enemies = CombatEnemies.new([{"id": "replacement", "name": "Replacement", "max_hp": 30}])
		"rng": app.run_rng = RandomNumberGenerator.new()
		"rng_state": app.run_rng.randi()
		"index": app.hand_view.move_child(panel, (panel.get_index() + 1) % 5)
	var before := _state()
	if queued:
		presenter._commit(panel, id, token, receipt)
	else:
		callback.call(_press())
	_check(_state() == before, "immediate refusal no mutation: %s queued=%s" % [mode, queued])
	# Terminal observation belongs to app, so assert before that independent close.
	if mode != "result":
		await _frames()
		_check(_state() == before, "deferred refusal no mutation: " + mode)
	await _dispose()


func _routed(keyboard: bool) -> void:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 337
	app._start_run()
	preload("res://tests/party_choice.gd").choose(app, ["warden", "rag_duelist", "tinker"])
	await _frames()
	_check(app.run_map != null and app.run_rng != null, "real picker admits chosen Rag Duelist run")
	if app.run_map == null:
		await _dispose()
		return
	for button in app.route_buttons:
		if app.run_map.get_node(button.get_meta("route_id")).type == "Fight":
			button.pressed.emit()
			break
	await _frames()
	_check(app.deck != null and app.party_carryover != null, "real connected route enters fight")
	if app.deck == null:
		await _dispose()
		return
	presenter = app.get_node("LiveRagDuelistRiposteHand")
	# Stage the authored opening token on the genuine routed actor, then let
	# the existing owner-turn boundary expire it. Passive admission is separate.
	var owner: Dictionary = app.party._heroes[1]
	var passive: Dictionary = owner.get("passive", {})
	_check(passive.get("id") == "en_garde" and passive.get("effects", {}).get("riposte") == 2,
		"chosen live actor retains canonical starting passive")
	owner["statuses"] = {"riposte": int(passive.get("effects", {}).get("riposte", 0))}
	_check(app.party.get_hero(2).id == "rag_duelist"
		and app.party.get_hero(2).statuses.get("riposte", 0) > 0, "V3 starting passive actually active")
	var opening := _pool_panel(BASE)
	if opening != null:
		var before := _state()
		await _cast(opening, keyboard)
		_check(_state() == before, "genuine starting passive blocks paid Cape")
	var cast := false
	for turn in range(5):
		app.end_turn_button.pressed.emit()
		await _frames()
		if app._battle_closed:
			break
		var panel := _pool_panel(BASE)
		if panel != null and app.party.get_hero(2).statuses.get("riposte", 0) == 0:
			_check(presenter._eligible(panel, BASE), "post-passive real Cape legal")
			await _assert_cast(panel, BASE, 2, keyboard)
			cast = true
			break
	_check(cast, "chosen Rag Duelist routed fight pays Cape after passive expires")
	await _dispose()


func _detach_and_unmount() -> void:
	var panel := await _begin(BASE)
	var callback: Callable = presenter._bindings[panel].callback
	app.hand_view.remove_child(panel)
	presenter._sync_battle()
	_check(not presenter._bindings.has(panel) and not panel.gui_input.is_connected(callback),
		"detached panel listener actually disconnected")
	var before := _state()
	callback.call(_press())
	await _frames()
	_check(_state() == before, "detached panel cannot spend")
	panel.free()
	app._refresh_hand()
	await _frames()
	panel = _pool_panel(BASE)
	_check(panel != null and presenter._bindings.has(panel), "fresh panels reconciled")
	presenter._clear()
	var metadata = app.get_node("LiveSupportHand")._metadata
	metadata._update_visual(panel)
	_check(not metadata.visual_state(panel).playable, "canonical held card dim without mounted admission")
	await _dispose()


func _session_replay() -> void:
	var panel := await _begin(BASE)
	var old_presenter = presenter
	var callback: Callable = presenter._bindings[panel].callback
	callback.call(_press())
	var token: int = presenter._token
	var receipt: Dictionary = presenter._pending.receipt.duplicate()
	app._return_to_title()
	await _frames()
	_check(old_presenter._bindings.is_empty(), "closed session detaches every listener")
	_check(app._start_battle(), "replacement live battle really opens")
	await _frames()
	var before := _state()
	callback.call(_press())
	old_presenter._commit(panel, BASE, token, receipt)
	await _frames()
	_check(_state() == before, "previous battle callback and receipt cannot play in new session")
	await _dispose()


func _mixed_dodge_riposte() -> void:
	await _begin(BASE)
	var dodge_id := "rag_duelist_cape_slip_plus"
	app.deck.hand[app.deck.hand.find("warden_strike")] = dodge_id
	app._refresh_hand()
	await _frames()
	var dodge_panel := _pool_panel(dodge_id)
	var riposte_panel := _pool_panel(BASE)
	_check(dodge_panel != null and riposte_panel != null
		and presenter._bindings.has(dodge_panel) and presenter._bindings.has(riposte_panel),
		"shared adapter binds Dodge and Riposte together in the actual hand")
	if dodge_panel != null and riposte_panel != null:
		await _cast(dodge_panel, false)
		_check(app.party.get_hero(2).statuses.get("dodge_next_attack") == 1,
			"mixed hand first routes Dodge to its paid service")
		riposte_panel = _pool_panel(BASE)
		_check(riposte_panel != null and presenter._eligible(riposte_panel, BASE),
			"Dodge redraw leaves genuine Riposte eligible")
		if riposte_panel != null:
			await _assert_cast(riposte_panel, BASE, 2, true)
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	await _mixed_dodge_riposte()
	for id in FORMS:
		for keyboard in [false, true]:
			var panel := await _begin(id)
			await _assert_cast(panel, id, 2, keyboard)
			await _dispose()
	for pair in [[BASE, 1], ["rag_duelist_cape_guard_plus", 3], ["rag_duelist_duelist_reprise_plus", 1]]:
		var panel := await _begin(pair[0], pair[1])
		await _assert_cast(panel, pair[0], pair[1], true)
		await _dispose()
	for mode in ["active", "energy", "owner", "down", "hand", "label", "redraw", "closed",
		"turn", "inactive", "result", "session", "party", "enemies", "rng", "index", "seat"]:
		for queued in [false, true]:
			await _negative(mode, queued)
	await _negative("rng_state", true)
	await _detach_and_unmount()
	await _session_replay()
	for keyboard in [false, true]:
		await _routed(keyboard)
	for failure in failures:
		printerr(failure)
	print("live_rag_duelist_riposte_hand_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
