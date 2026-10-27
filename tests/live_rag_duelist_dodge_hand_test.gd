extends "res://tests/live_rag_duelist_riposte_hand_test.gd"

const DODGE_FORMS := {
	"rag_duelist_cape_slip": 1,
	"rag_duelist_cape_slip_plus": 0,
	"rag_duelist_cape_flourish": 1,
	"rag_duelist_cape_flourish_plus": 0,
}
const SLIP := "rag_duelist_cape_slip"


func _dodge_begin(id: String, seat: int = 2) -> Control:
	var panel := await _begin(id, seat)
	# Upgrades must work with genuinely zero available energy.
	app.deck.combat_state.energy = DODGE_FORMS[id]
	app.party._heroes[seat - 1].statuses = {"bleed": 2, "riposte": 2}
	app.party._heroes[seat % 3].statuses = {"weak": 1}
	app._refresh_party()
	return panel


func _assert_dodge(panel: Control, id: String, seat: int, keyboard: bool) -> void:
	_check(panel != null and presenter._bindings.has(panel), "nonempty mounted Dodge binding")
	if panel == null or not presenter._bindings.has(panel):
		return
	var metadata = app.get_node("LiveSupportHand")._metadata
	metadata._update_visual(panel)
	_check(metadata.visual_state(panel).playable, "live metadata enables affordable Dodge: " + id)
	_check(panel.tooltip_text.to_lower().contains("dodge the next attack"), "authored Dodge tooltip")
	var callback: Callable = presenter._bindings[panel].callback
	var before := _state()
	await _cast(panel, keyboard)
	var expected := before.duplicate(true)
	expected[0][1].erase(id)
	expected[0][2].append(id)
	expected[0][3] -= DODGE_FORMS[id]
	expected[0][5][seat - 1].statuses["dodge_next_attack"] = 1
	_check(_state() == expected, "exact one-copy spend and only owner integer Dodge; no draw/HP/Block/enemy/RNG effects: " + id)
	_check(typeof(app.party.get_hero(seat).statuses.get("dodge_next_attack")) == TYPE_INT,
		"Dodge is integer token")
	_check(presenter.last_event.get("ok", false) and presenter.last_event.get("self_target", false)
		and presenter.last_event.get("target_position") == seat, "paid service confirms implicit self target")
	_check(presenter._pending.is_empty(), "self card never opens a target picker")
	_check(app.pile_label.text.contains("Discard: %d" % app.deck.discard_pile.size())
		and app.get_node("LiveSupportHand").energy_label.text == str(app.deck.energy)
		and app.hand_view.get_child_count() == app.deck.hand.size(), "mounted resources and hand refresh")
	var after := _state()
	callback.call(_press())
	await _frames()
	_check(_state() == after, "retired callback cannot replay Dodge")
	var remaining := _pool_panel(id)
	_check(remaining != null and presenter._bindings.has(remaining), "remaining genuine copy rebound")
	if remaining == null:
		return
	app.deck.combat_state.energy = DODGE_FORMS[id]
	metadata._update_visual(remaining)
	_check(metadata.visual_state(remaining).playable, "already armed Dodge remains playable")
	before = _state()
	await _cast(remaining, not keyboard)
	expected = before.duplicate(true)
	expected[0][1].erase(id)
	expected[0][2].append(id)
	expected[0][3] -= DODGE_FORMS[id]
	_check(_state() == expected, "second genuine cast refreshes Dodge to 1 without stacking")


func _dodge_negative(mode: String, queued: bool) -> void:
	var panel := await _dodge_begin(SLIP)
	var callback: Callable = presenter._bindings[panel].callback
	if queued:
		callback.call(_press())
		_check(not presenter._pending.is_empty(), "valid queued intent exists before tampering: " + mode)
	var token: int = presenter._token
	var receipt: Dictionary = presenter._pending.get("receipt", {}).duplicate()
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"owner": app.party._heroes[1].id = "missing"
		"down": app.party.apply_damage(2, 999)
		"hand": app.deck.hand[panel.get_index()] = "forged"
		"label": panel.get_child(0).text = "rag_duelist_cape_slip_plus_plus"
		"status": app.party._heroes[1].statuses["dodge_next_attack"] = true
		"ally_status": app.party._heroes[0].statuses["weak"] = -1
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
	if mode == "energy":
		var metadata = app.get_node("LiveSupportHand")._metadata
		metadata._update_visual(panel)
		_check(not metadata.visual_state(panel).playable, "unaffordable base Dodge is dimmed")
	if queued:
		presenter._commit(panel, SLIP, token, receipt)
	else:
		callback.call(_press())
		var release := _press()
		release.pressed = false
		callback.call(release)
	_check(_state() == before, "Dodge refusal preserves all resources/statuses/RNG: %s queued=%s" % [mode, queued])
	if mode != "result":
		await _frames()
		_check(_state() == before, "deferred Dodge refusal remains inert: " + mode)
	await _dispose()


func _retry() -> void:
	var panel := await _dodge_begin(SLIP)
	var callback: Callable = presenter._bindings[panel].callback
	callback.call(_press())
	var token: int = presenter._token
	var receipt: Dictionary = presenter._pending.receipt.duplicate()
	app.deck.combat_state.energy = 0
	var before := _state()
	presenter._commit(panel, SLIP, token, receipt)
	_check(_state() == before and presenter._pending.is_empty(), "failed commit consumes pending intent without spend")
	app.deck.combat_state.energy = 1
	presenter._commit(panel, SLIP, token, receipt)
	_check(app.deck.hand.count(SLIP) == 2, "restoring resources cannot revive old receipt")
	await _assert_dodge(panel, SLIP, 2, true)
	await _dispose()


func _routed_dodge(keyboard: bool) -> void:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 338
	app._start_run()
	preload("res://tests/party_choice.gd").choose(app, ["warden", "rag_duelist", "tinker"])
	await _frames()
	_check(app.run_map != null and app.run_rng != null, "genuine Rag party admitted through picker")
	if app.run_map == null:
		await _dispose()
		return
	for button in app.route_buttons:
		if app.run_map.get_node(button.get_meta("route_id")).type == "Fight":
			button.pressed.emit()
			break
	await _frames()
	_check(app.deck != null and app.party_carryover != null, "real route opened mounted Fight")
	if app.deck == null:
		await _dispose()
		return
	presenter = app.get_node("LiveRagDuelistRiposteHand")
	var cast := false
	for turn in range(5):
		var panel := _pool_panel(SLIP)
		if panel != null and presenter._eligible(panel, SLIP):
			var before := _state()
			await _cast(panel, keyboard)
			var expected := before.duplicate(true)
			expected[0][1].erase(SLIP)
			expected[0][2].append(SLIP)
			expected[0][3] -= 1
			var statuses: Dictionary = expected[0][5][1].get("statuses", {}).duplicate(true)
			statuses["dodge_next_attack"] = 1
			expected[0][5][1]["statuses"] = statuses
			_check(_state() == expected, "real routed shared starter hand casts Cape Slip exactly once")
			cast = true
			break
		app.end_turn_button.pressed.emit()
		await _frames()
		if app._battle_closed:
			break
	_check(cast, "routed Fight genuinely exercised Dodge input")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id in DODGE_FORMS:
		for seat in [1, 2, 3]:
			for keyboard in [false, true]:
				var panel := await _dodge_begin(id, seat)
				await _assert_dodge(panel, id, seat, keyboard)
				await _dispose()
	for mode in ["energy", "owner", "down", "hand", "label", "status", "ally_status", "redraw",
		"closed", "turn", "inactive", "result", "session", "party", "enemies", "rng", "index"]:
		for queued in [false, true]:
			await _dodge_negative(mode, queued)
	await _dodge_negative("rng_state", true)
	await _retry()
	for keyboard in [false, true]:
		await _routed_dodge(keyboard)
	for failure in failures:
		printerr(failure)
	print("live_rag_duelist_dodge_hand_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
