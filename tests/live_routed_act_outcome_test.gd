extends "res://tests/live_fight_carryover_entry_test.gd"
## Real routed inputs, with the complete inherited combat/persistence snapshots.

var last_latch: RunActBattleOutcome


func _snapshot() -> Array:
	var result := super._snapshot()
	result.append(app.act_outcome.get_state() if app.act_outcome != null else {})
	return result


func _click(control: Control) -> void:
	var returning: bool = control == app.return_button and is_instance_valid(control)
	var latch: RunActBattleOutcome = app.act_outcome
	var saved := latch.get_state() if latch != null else {}
	if returning and app.battle_result.get_outcome() == CombatBattleResult.DEFEAT:
		_check(latch != null and saved.run_status == RunActBattleOutcome.DEFEAT
			and saved.settled_node_ids == app.run_map.get_route() and saved.pending_node_id == "",
			"enemy-phase defeat settles exact selected Fight as run DEFEAT")
		_check(app.result_label.is_visible_in_tree() and app.result_label.text.contains("Run defeat")
			and app.end_turn_button.disabled and not app.deck.turn_active
			and app.reward_buttons.is_empty(), "routed defeat cue, frozen hand and no rewards")
		var before := _snapshot()
		app.end_turn_button.pressed.emit()
		app.return_button.release_focus()
		await _key(KEY_SPACE)
		_check(_snapshot() == before, "closed defeat ignores mouse callback and keyboard action")
	await super._click(control)
	if returning:
		_check(app.act_outcome == null and app.title_view.is_visible_in_tree(), "Return disposes latch and shows title")
		if latch != null:
			_check(latch.get_state() == saved, "Return preserves detached outcome snapshot")
			if not saved.settled_node_ids.is_empty():
				_check(not latch.settle_current_battle(), "disposed settled latch cannot settle twice")
	elif app.act_outcome != null and app.act_outcome != last_latch:
		last_latch = app.act_outcome
		_check(last_latch._map == app.run_map and last_latch._pending_result == app.battle_result
			and app.battle_result._party == app.party and app.battle_result._enemies == app.enemies,
			"published latch binds exact live map, result and actors")
		_check(last_latch.get_state() == {"run_status": "ACTIVE", "pending_node_id": app.run_map.get_current_node_id(),
			"settled_node_ids": []}, "fresh routed battle has fresh ACTIVE latch")
		var before := _snapshot()
		_check(not last_latch.settle_current_battle() and app._observe_battle_result(), "ACTIVE cannot settle")
		_check(_snapshot() == before, "ACTIVE observation conserves complete state and RNG")
		var detached := last_latch.get_state()
		detached.settled_node_ids.append("forged")
		detached.run_status = "DEFEAT"
		_check(_snapshot() == before, "returned latch snapshot is immutable by caller")


func _reject_unchanged(label: String) -> void:
	var state: Dictionary = app.act_outcome.get_state()
	await super._reject_unchanged(label)
	_check(app.act_outcome.get_state() == state, label + " also preserves pending outcome")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _fixture()
	_check(not fixture.is_empty(), "seeded legal routed fixture exists")
	if fixture.is_empty():
		await _finish_carryover()
		return
	# A routed startup without a selected node must reject before shuffle/publication.
	app.run_seed = fixture.seed
	await _click(app.route_button)
	var route_before: Array = app.run_map.get_route()
	var rng_before: int = app.run_rng.state
	_check(not app._start_battle(app.run_rng, app._load_enemy_schedule(),
		CombatEnemies.new(app._load_enemy_definitions())), "unselected routed admission rejects")
	_check(app.run_rng.state == rng_before and app.run_map.get_route() == route_before
		and app.deck == null and app.battle_result == null and app.act_outcome == null
		and app.party_carryover == null and app.battle_view == null, "failed admission publishes and spends nothing")
	await _click(app.route_back_button)
	_check(app.act_outcome == null, "cancel has no outcome latch")
	var replay: Array = []
	var previous: RunActBattleOutcome
	for session in range(2):
		exercised_entry = false
		if not await _routed_win(fixture, false):
			break
		var latch: RunActBattleOutcome = app.act_outcome
		_check(latch != previous and latch.get_state() == {"run_status": "ACTIVE",
			"pending_node_id": "", "settled_node_ids": [fixture.fight]}, "held-card Fight victory settles once and run stays ACTIVE")
		_check(app.run_heroes == _block_free_party() and app.fight_rewards != null
			and app.reward_buttons.size() == 4 and not app.fight_reward_claimed,
			"carryover precedes existing unclaimed authored rewards")
		var before := _snapshot()
		for repeat in range(3):
			_check(not latch.settle_current_battle(), "duplicate settlement rejects")
			app._observe_battle_result()
			app._build_card_reward()
		_check(_snapshot() == before, "duplicate observation conserves heroes, deck, gold, route, RNG and offers")
		if session == 0:
			replay = before.duplicate(true)
		else:
			_check(before == replay, "same-seed held-card replay exactly reproduces all state")
		var detached := latch.get_state()
		detached.settled_node_ids.clear()
		_check(_snapshot() == before, "settled snapshot remains independent")
		await _click(app.reward_buttons[3])
		_check(app.fight_reward_claimed and app.continue_button != null, "existing Skip reward flow survives")
		previous = latch
		await _click(app.return_button)
	_check(pointer_plays > 0 and key_plays > 0, "victories exercise held cards by mouse and keyboard")
	await _identity_rejections(fixture)
	await _enter(fixture)
	# In-place map drift must reject before evaluate can witness lethal actors.
	for enemy in app.enemies.get_enemies():
		app.enemies.apply_damage(enemy.position, 999)
	var node: Dictionary = app.run_map._nodes[fixture.fight]
	var old_outgoing: Array = node.outgoing.duplicate()
	node.outgoing.append("stale-edge")
	var stale := _snapshot()
	_check(not app._observe_battle_result() and _snapshot() == stale
		and app.battle_result.get_outcome() == CombatBattleResult.ACTIVE, "stale map rejects without evaluation, settlement or mutation")
	node.outgoing = old_outgoing
	app._return_to_title()
	await _frames()
	await _defeat(fixture)
	await _enter(fixture)
	_check(app.act_outcome != previous and app.act_outcome.get_state().run_status == "ACTIVE",
		"restart after defeat creates fresh ACTIVE latch")
	await _click(app.return_button)
	await _click(app.start_button)
	_check(app.deck != null and app.run_map == null and app.act_outcome == null, "standalone Start has no run latch")
	await _click(app.return_button)
	await _finish_carryover()


func _finish_carryover() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_routed_act_outcome_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
