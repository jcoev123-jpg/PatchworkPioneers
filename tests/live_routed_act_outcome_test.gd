extends "res://tests/live_fight_carryover_entry_test.gd"
## Real routed inputs, with the complete inherited combat/persistence snapshots.

var last_latch: RunActBattleOutcome


func _snapshot() -> Array:
	var result := super._snapshot()
	result.append(app.act_outcome.get_state() if app.act_outcome != null else {})
	result.append([app.run_scraps, app.run_trinkets.duplicate(),
		app.run_stitch_descriptors.duplicate(true), app.run_next_stitch_id,
		app.fight_reward_trinket])
	if app.fight_rewards != null:
		result.append([app.fight_rewards._prepared, app.fight_rewards._award,
			app.fight_rewards._choice.get_offers(), app.fight_rewards._choice.is_claimed()])
	if app.multi_fight_rewards != null:
		result.append(app.multi_fight_rewards.read_state())
	var panel: LiveRunTerminalResultPanel = app.terminal_result_panel
	result.append([panel, panel.get_presented_status() if panel != null else "",
		panel.visible if panel != null else false,
		panel.return_button.disabled if panel != null else true])
	return result


func _click(control: Control) -> void:
	var returning: bool = is_instance_valid(control) and (control == app.return_button
		or (app.terminal_result_panel != null and control == app.terminal_result_panel.return_button))
	var terminal_return: bool = returning and app.terminal_result_panel != null \
		and control == app.terminal_result_panel.return_button
	var latch: RunActBattleOutcome = app.act_outcome
	var saved := latch.get_state() if latch != null else {}
	if terminal_return and app.battle_result.get_outcome() == CombatBattleResult.DEFEAT:
		_check(latch != null and saved.run_status == RunActBattleOutcome.DEFEAT
			and saved.settled_node_ids == app.run_map.get_route() and saved.pending_node_id == "",
			"enemy-phase defeat settles exact selected Fight as run DEFEAT")
		_check(app.result_label.is_visible_in_tree() and app.result_label.text.contains("Run defeat")
			and app.end_turn_button.disabled and not app.deck.turn_active
			and app.reward_buttons.is_empty(), "routed defeat cue, frozen hand and no rewards")
		var before := _snapshot()
		app.end_turn_button.pressed.emit()
		app.return_button.pressed.emit()
		app.return_button.release_focus()
		app._mount_terminal_result()
		var callback: Callable = app._terminal_return_connection
		callback.call()
		_check(_snapshot() == before, "closed defeat ignores old Return, forged signal callback and duplicate mount")
		_check(app.terminal_result_panel.return_button.has_focus(),
			"Defeat Return has keyboard focus")
		# A focused terminal button must be the only valid keyboard action.
		await _key(KEY_ENTER)
		_check(app.title_view.is_visible_in_tree() and app.act_outcome == null,
			"physical Enter accepts genuine terminal Return")
		# Keyboard consumed this terminal; the caller's old mouse click no longer applies.
		if latch != null:
			_check(latch.get_state() == saved, "keyboard Return preserves detached settled latch")
		return
	await super._click(control)
	if returning:
		_check(app.act_outcome == null and app.title_view.is_visible_in_tree(), "Return disposes latch and shows title")
		if latch != null:
			_check(latch.get_state() == saved, "Return preserves detached outcome snapshot")
			if not saved.settled_node_ids.is_empty():
				_check(not latch.settle_current_battle(), "disposed settled latch cannot settle twice")
	elif app.battle_result != null and app.act_outcome != null and app.act_outcome != last_latch:
		last_latch = app.act_outcome
		_check(last_latch._map == app.run_map and last_latch._pending_result == app.battle_result
			and app.battle_result._party == app.party and app.battle_result._enemies == app.enemies,
			"published latch binds exact live map, result and actors")
		_check(last_latch.get_state() == {"run_status": "ACTIVE", "pending_node_id": app.run_map.get_current_node_id(),
			"settled_node_ids": []}, "fresh routed battle has fresh ACTIVE latch")
		var before := _snapshot()
		_check(not last_latch.settle_current_battle() and app._observe_battle_result(), "ACTIVE cannot settle")
		_check(_snapshot() == before and app.terminal_result_panel == null,
			"ACTIVE observation conserves complete state and has no terminal panel")
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
		and app.deck == null and app.battle_result == null and app.act_outcome != null
		and app.act_outcome.get_state().pending_node_id == ""
		and app.party_carryover != null and app.party_carryover.read_state().completed_fights.is_empty()
		and app.battle_view == null, "failed admission publishes and spends nothing")
	await _click(app.route_back_button)
	_check(app.act_outcome == null, "cancel has no outcome latch")
	var replay: Array = []
	var previous: RunActBattleOutcome
	var retained: Array[Callable] = []
	for session in range(2):
		exercised_entry = false
		if not await _routed_win(fixture, false):
			break
		var latch: RunActBattleOutcome = app.act_outcome
		_check(latch != previous and latch.get_state() == {"run_status": "ACTIVE",
			"pending_node_id": "", "settled_node_ids": [fixture.fight]}, "held-card Fight victory settles once and run stays ACTIVE")
		_check(app.terminal_result_panel == null,
			"settled ordinary Fight remains ACTIVE with no terminal screen")
		_check(app.run_heroes == _block_free_party() and app.fight_rewards != null
			and app.reward_choice_panel != null and app.reward_choice_panel.has_open_rewards()
			and app.reward_choice_panel.get_choice_buttons() == app.reward_buttons
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
		retained = [app.reward_buttons[3].pressed.get_connections()[0].callable,
			app.continue_button.pressed.get_connections()[0].callable]
		previous = latch
		await _click(app.return_button)
	_check(pointer_plays > 0 and key_plays > 0, "victories exercise held cards by mouse and keyboard")
	await _regeneration_rejections(fixture)
	await _identity_rejections(fixture)
	await _enter(fixture)
	# An active bound run cannot publish merely from a direct mount request,
	# even with lethal-looking actors that combat has not observed.
	var active_before := _snapshot()
	app._mount_terminal_result()
	_check(app.terminal_result_panel == null and _snapshot() == active_before,
		"ACTIVE routed battle refuses direct terminal publication")
	for enemy in app.enemies.get_enemies():
		app.enemies.apply_damage(enemy.position, 999)
	var lethal_before := _snapshot()
	app._mount_terminal_result()
	_check(app.battle_result.get_outcome() == CombatBattleResult.ACTIVE
		and app.terminal_result_panel == null and _snapshot() == lethal_before,
		"unobserved lethal actors cannot open panel, settle or spend RNG")
	# In-place map drift must reject before evaluate can witness lethal actors.
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
	_check(app._start_battle(), "explicit standalone M01 fixture starts")
	await _frames()
	_check(app.deck != null and app.run_map == null and app.act_outcome == null, "standalone M01 fixture has no run latch")
	_check(not retained.is_empty(), "routed victory supplies retained reward and Continue callbacks")
	var standalone := _state()
	for callback in retained:
		callback.call()
	_check(_state() == standalone and app.run_map == null and app.act_outcome == null
		and app.party_carryover == null and app.rest_recovery == null and app.shop_visit == null
		and app.route_view == null and app.terminal_result_panel == null,
		"post-title callbacks preserve standalone combat without reviving routed session")
	await _click(app.return_button)
	await _finish_carryover()


func _regenerate_selected() -> void:
	var live_map: RunMap = app.run_map
	var graph := live_map.get_floors()
	var route := live_map.get_route()
	var revision := live_map.get_generation_revision()
	var rng_before: int = app.run_rng.state
	var independent := RandomNumberGenerator.new()
	independent.seed = app.run_seed
	_check(live_map.generate(independent), "same object regenerates successfully")
	_check(app.run_map == live_map and live_map.get_floors() == graph
		and live_map.get_generation_revision() != revision, "same object and graph have a new generation")
	for id in route:
		_check(live_map.choose_node(id), "original route node can be reselected: " + id)
	_check(live_map.get_route() == route and app.run_rng.state == rng_before,
		"regenerated selected route matches without spending run RNG")
	_check(not app._current_carryover_fight() and not app._can_leave_fight(),
		"generation mismatch invalidates combat and continuation binding")


func _stale_mounted_actions(label: String) -> void:
	_check(app.battle_view.is_visible_in_tree() and is_instance_valid(app.end_turn_button),
		label + " has mounted battle controls")
	var before := _snapshot()
	app.end_turn_button.pressed.emit()
	_check(not app._observe_battle_result(), label + " rejects result observation")
	_check(not app._commit_fight_carryover(), label + " rejects carryover")
	app._build_card_reward()
	for button in app.reward_buttons:
		_check(is_instance_valid(button) and (button.is_visible_in_tree() or app.fight_reward_claimed), label + " reward control is mounted or accepted")
		button.pressed.emit()
	if is_instance_valid(app.continue_button):
		app.continue_button.pressed.emit()
	await _frames()
	_check(app.terminal_result_panel == null, label + " never opens a terminal panel")
	_check(_snapshot() == before and app.route_view == null and app.battle_view.is_visible_in_tree(),
		label + " preserves full combat, terminal, route, ledger, inventory, rewards and RNG state")


func _regeneration_rejections(fixture: Dictionary) -> void:
	await _enter(fixture)
	_check(app.battle_result.get_outcome() == CombatBattleResult.ACTIVE
		and app.deck.turn_active and not app.end_turn_button.disabled, "opening probe starts in actionable combat")
	_regenerate_selected()
	await _stale_mounted_actions("regenerated active opening Fight")
	# A stale observer must not even evaluate actors that now look terminal.
	for enemy in app.enemies.get_enemies():
		_check(app.enemies.apply_damage(enemy.position, 999), "stale result fixture defeats real enemy")
	await _stale_mounted_actions("regenerated opening with lethal actors")
	_check(app.battle_result.get_outcome() == CombatBattleResult.ACTIVE,
		"generation rejection occurs before evaluating lethal actors")
	await _click(app.return_button)
	_check(app._carryover_revision == 0, "title clears generation token")
	for claimed in [false, true]:
		exercised_entry = false
		if not await _routed_win(fixture, false):
			return
		_check(app.reward_buttons.size() == 4 and not app.fight_reward_claimed
			and app.battle_result.get_outcome() == CombatBattleResult.VICTORY,
			"regeneration probe has real held-card victory and unclaimed rewards")
		if claimed:
			await _click(app.reward_buttons[0])
			_check(app.fight_reward_claimed and is_instance_valid(app.continue_button)
				and not app.continue_button.disabled and app._can_leave_fight(),
				"valid pick exposes actionable Continue before regeneration")
		_regenerate_selected()
		await _stale_mounted_actions("regenerated victory claimed=" + str(claimed))
		await _click(app.return_button)
	# Untouched Skip/Continue must still admit an actual connected Fight or Elite.
	exercised_entry = false
	if not await _routed_win(fixture, false):
		return
	await _click(app.reward_buttons[3])
	_check(app._can_leave_fight(), "untouched Skip permits Continue")
	await _click(app.continue_button)
	_check(is_instance_valid(app.route_view) and app.route_view.is_visible_in_tree(),
		"untouched Continue mounts connected route")
	var next: Button
	for button in app.route_buttons:
		if app.run_map.get_node(button.get_meta("route_id")).type in ["Fight", "Elite"]:
			next = button
			break
	_check(next != null and not next.disabled, "fixture has an actionable connected battle")
	if next != null:
		await _click(next)
		_check(app.run_map.get_route().size() == 2 and app._current_carryover_fight()
			and app.battle_result.get_outcome() == CombatBattleResult.ACTIVE
			and app.deck.turn_active and not app.end_turn_button.disabled,
			"connected admission publishes valid current generation and real active combat")
		_regenerate_selected()
		await _stale_mounted_actions("regenerated active connected battle")
	await _click(app.return_button)


func _finish_carryover() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_routed_act_outcome_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
