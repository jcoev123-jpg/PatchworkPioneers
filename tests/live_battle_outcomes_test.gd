extends SceneTree

var failures: Array[String] = []
var checks := 0
var app


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _frames() -> void:
	for frame in range(4):
		await process_frame


func _state() -> Array:
	return [app.party.get_heroes(), app.enemies.get_enemies(), app.deck.hand.duplicate(),
		app.deck.draw_pile.duplicate(), app.deck.discard_pile.duplicate(), app.deck.energy,
		app.deck.turn_active, app.run_rng.state, app.enemy_intents.get_intents(),
		app.enemy_attacks.duplicate(true), app.session_gold, app.victory_gold.is_claimed(),
		app.enemy_intents._turn_index, app.battle_result.get_outcome(),
		app.deck.combat_state.energy, app.deck.combat_state.player_turn_active]


func _click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _mouse(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := _click()
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await _frames()


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await _frames()


func _start() -> bool:
	_fixture_start(app)
	await _frames()
	var valid: bool = app.deck != null and app.party != null and app.enemies != null \
		and app.battle_result != null and is_instance_valid(app.result_label)
	_check(valid, "keyboard Start constructs all live models and result")
	if not valid:
		return false
	_check(app.battle_result._party == app.party and app.battle_result._enemies == app.enemies,
		"result observes actual authoritative model identities")
	_check(app.round_flow != null and app.round_flow._started
		and app.round_flow._result == app.battle_result and app.round_flow._deck == app.deck
		and app.round_flow._party == app.party and app.round_flow._enemies == app.enemies
		and app.round_flow._intents == app.enemy_intents, "live coordinator shares complete session")
	_check(app.victory_gold != null and app.victory_gold._result == app.battle_result
		and not app.victory_gold.is_claimed() and app.session_gold == 0,
		"fresh session binds one unclaimed payout to authoritative result")
	_check(app.battle_result.get_outcome() == CombatBattleResult.ACTIVE
		and not app.result_label.is_visible_in_tree() and app.deck.turn_active,
		"new battle ACTIVE without terminal banner")
	_check(app.find_children("BattleResult", "Label", true, false).size() == 1,
		"exactly one battle-local result label")
	return true


func _closed(outcome: String) -> void:
	_check(app.round_flow != null and app.round_flow.get_outcome() == outcome,
		"coordinator retains terminal session outcome")
	_check(app.battle_result.get_outcome() == outcome, "authoritative outcome: " + outcome)
	var expected_text := "Battle result: " + outcome
	if outcome == CombatBattleResult.VICTORY:
		expected_text += " | Gold: %d" % app.session_gold
		_check(app.session_gold >= 10 and app.session_gold <= 20 and app.victory_gold.is_claimed(),
			"victory claims normal gold once")
	else:
		_check(app.session_gold == 0 and not app.victory_gold.is_claimed(), "non-victory never claims gold")
	_check(app.result_label.text == expected_text
		and app.result_label.is_visible_in_tree(), "readable mounted outcome: " + outcome)
	_check(app.result_label.size.x > 0 and app.result_label.size.y > 0
		and Rect2(0, 0, 1280, 720).encloses(app.result_label.get_global_rect()), "banner fits viewport")
	_check(app.end_turn_button.disabled and not app.deck.turn_active and app.deck.hand.is_empty(),
		"closure disables End Turn and ends active hand")
	_check(app.battle_view.is_visible_in_tree() and app.return_button.is_visible_in_tree()
		and not app.return_button.disabled
		and Rect2(0, 0, 1280, 720).encloses(app.return_button.get_global_rect()), "Return remains visible and usable")
	_check(app.find_children("BattleResult", "Label", true, false).size() == 1, "no extra result nodes")


func _inert() -> void:
	var before := _state()
	for repeat in range(3):
		_fixture_start(app)
		app._process(0.0)
		app._reenable_end_turn(app.end_turn_button)
		app.end_turn_button.pressed.emit()
		app._end_turn(app.end_turn_button)
		_check(not app.deck.try_spend_energy(1) and app.deck.draw_extra(1) == -1,
			"closed support spend/draw gates reject")
		await _frames()
	_check(_state() == before, "repeated terminal inputs preserve every model, pile, intent and RNG")


func _return() -> void:
	var flow_ref: WeakRef = weakref(app.round_flow)
	var result_ref: WeakRef = weakref(app.battle_result)
	var gold_ref: WeakRef = weakref(app.victory_gold)
	var old_label: Label = app.result_label
	await _mouse(app.return_button)
	_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus(), "mouse Return restores actionable title")
	_check(app.battle_result == null and app.result_label == null and app.deck == null
		and app.party == null and app.enemies == null and app.run_rng == null
		and app.victory_gold == null and app.session_gold == 0, "Return cleans session references and payout")
	_check(gold_ref.get_ref() == null, "Return frees bound payout service")
	_check(app.round_flow == null and flow_ref.get_ref() == null, "Return releases terminal coordinator")
	_check(result_ref.get_ref() == null and not is_instance_valid(old_label)
		and app.find_children("BattleResult", "Label", true, false).is_empty(), "Return frees result and label")


func _support_panel(card_id: String):
	for panel in app.hand_view.get_children():
		if panel.get_child(0).text == card_id:
			return panel
	return null


func _victory() -> void:
	var replay: Array = []
	for session in range(2):
		if not await _start():
			return
		var trace: Array = [_state()]
		var result: WeakRef = weakref(app.battle_result)
		var gold: WeakRef = weakref(app.victory_gold)
		_fixture_start(app)
		await _frames()
		_check(app.battle_result == result.get_ref() and app.victory_gold == gold.get_ref()
			and _state() == trace[0], "duplicate Start preserves single result, claim latch and state")
		_check(app.enemies.get_enemies().size() == 2 and app.enemies.apply_damage(1, 999), "two-enemy fixture slays first slot")
		var one_slain := _state()
		await _frames()
		_check(app.battle_result.can_continue() and not app.result_label.visible
			and not app.end_turn_button.disabled and _state() == one_slain, "one slain stays active without observation mutation")
		trace.append(_state())
		# Start an actual ally selection; queue its resolution just before closure.
		var support = app.get_node("LiveSupportHand")
		var panel = _support_panel("seamstress_mend")
		_check(panel != null, "seeded hand contains Mend for pending-target test")
		if panel != null:
			panel.gui_input.emit(_click())
			await _frames()
			_check(support._pending.get("choosing", false) and support._targets.size() == 3,
				"real support activation entered ally selection")
			app.hero_panels[0].gui_input.emit(_click())
			_check(support._pending.get("queued", false), "target resolution really queued")
		var before := _state()
		_check(app.enemies.apply_damage(2, 999), "final enemy damage succeeds")
		var resolved_enemies: Array = app.enemies.get_enemies()
		var reference := RandomNumberGenerator.new()
		reference.seed = app.run_rng.seed
		reference.state = app.run_rng.state
		var expected_gold := reference.randi_range(10, 20)
		# Real End Turn dispatch observes damage before allowing the enemy phase.
		app.end_turn_button.pressed.emit()
		await _frames()
		_closed(CombatBattleResult.VICTORY)
		_check(app.party.get_heroes() == before[0] and app.enemies.get_enemies() == resolved_enemies
			and app.deck.draw_pile == before[3]
			and app.deck.discard_pile == before[4] + before[2] and app.deck.energy == 0
			and app.run_rng.state == reference.state and app.session_gold == expected_gold
			and app.enemy_intents.get_intents() == before[8]
			and app.enemy_attacks == before[9], "victory only ends hand and draws exact gold; no queued heal, spend, draw, attack or intent advance")
		_check(support._pending.is_empty() and support._targets.is_empty(), "closure cancels pending target callbacks")
		await _inert()
		trace.append(_state())
		if session == 0:
			replay = trace
		else:
			_check(trace == replay, "fixed seed replays complete fresh victory trace")
		await _return()


func _defeat() -> void:
	var path := "user://live_battle_outcomes_attacks.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "authored-intent fixture file writable")
	if file == null:
		return
	file.store_string(JSON.stringify([
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "target_position": 1, "amount": 999},
			{"type": "attack", "target_position": 3, "amount": 999}]},
		{"enemy_position": 2, "pattern": [{"type": "attack", "target_position": 2, "amount": 999}]}]))
	file.close()
	app.starter_attacks_path = path
	var replay: Array = []
	for session in range(2):
		if not await _start():
			break
		var trace: Array = [_state()]
		_check(app.enemies.get_enemies().size() == 2 and app.enemy_attacks[0].amount == 999
			and app.intent_label.text.contains("999 damage"), "two live enemies announce authored lethal hits")
		await _mouse(app.end_turn_button)
		_check(app.party.is_downed(1) and app.party.is_downed(2) and not app.party.is_downed(3)
			and app.battle_result.can_continue(), "actual first End Turn downs two heroes and continues")
		trace.append(_state())
		var before := _state()
		await _mouse(app.end_turn_button)
		_closed(CombatBattleResult.DEFEAT)
		_check(app.party.is_defeated(), "actual announced second-phase attacks defeat all three heroes")
		_check(app.enemies.get_enemies() == before[1] and app.deck.draw_pile == before[3]
			and app.deck.discard_pile == before[4] + before[2] and app.deck.energy == 0
			and app.run_rng.state == before[7] and app.enemy_attacks == before[9]
			and app.enemy_intents.get_intents() == before[8], "defeat stops before next draw, Block reset or intent advance")
		await _inert()
		trace.append(_state())
		if session == 0:
			replay = trace
		else:
			_check(trace == replay, "fixed seed replays authored defeat trace")
		await _return()
	app.starter_attacks_path = app.STARTER_ATTACKS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _unresolved_and_queued_support() -> void:
	for scenario in ["tie", "invalid", "queued_brace", "live_update"]:
		if not await _start():
			return
		var support = app.get_node("LiveSupportHand")
		var panel = _support_panel("warden_brace")
		_check(panel != null, "seeded held Brace provides real support activation")
		if panel != null and scenario != "live_update":
			panel.gui_input.emit(_click())
			_check(not support._pending.is_empty(), "support activation actually queued")
		if scenario == "tie":
			for position in range(1, 4):
				_check(app.party.apply_damage(position, 999), "tie downs hero")
		elif scenario == "invalid":
			app.party._heroes.clear()
			_check(not app.party.is_valid(), "unreadable roster genuinely invalid")
		for position in range(1, 3):
			_check(app.enemies.apply_damage(position, 999), "final enemy damage before live update")
		var reference := RandomNumberGenerator.new()
		reference.seed = app.run_rng.seed
		reference.state = app.run_rng.state
		var expected_gold := 0
		if scenario in ["queued_brace", "live_update"]:
			expected_gold = reference.randi_range(10, 20)
		if scenario == "live_update":
			# No explicit result callback or End Turn: normal mounted scene processing
			# must observe final damage (the future attack-card update boundary).
			await _frames()
		else:
			# Observe before the queued support callback is dispatched.
			app._process(0.0)
		var before := _state()
		await _frames()
		_closed(CombatBattleResult.VICTORY if scenario in ["queued_brace", "live_update"] else CombatBattleResult.UNRESOLVED)
		_check(app.session_gold == expected_gold and app.run_rng.state == reference.state,
			"exact payout and RNG for live/deferred victory or invalid/tie: " + scenario)
		_check(_state() == before and support._pending.is_empty(), "deferred support activation cannot spend after closure")
		# Try all existing support service entry points against the closed live deck.
		for card_id in support.SUPPORT_IDS:
			_check(not support._play.play_card(app.deck, app.party, card_id, 1), "closed support card rejects: " + card_id)
		_check(_state() == before, "all support rejection paths preserve complete state")
		await _inert()
		await _return()


func _status_turns() -> void:
	var replay: Array = []
	for session in range(2):
		if not await _start():
			return
		var hero: Dictionary = app.party._heroes[0]
		hero["statuses"] = {"bleed": 2, "weak": 2, "exposed": 1}
		var expected: Array = app.party.get_heroes()
		expected[0]["hp"] = 38
		expected[0]["block"] = 0
		expected[0]["statuses"] = {"bleed": 1, "weak": 1}
		_check(hero["hp"] == 40 and hero["block"] == 6
			and app.enemy_intents._turn_index == 0, "live status fixture has opening Block and current phase")
		# Duplicate dispatches in one input burst must tick only once.
		app.end_turn_button.pressed.emit()
		app.end_turn_button.pressed.emit()
		await _frames()
		_check(app.party.get_heroes() == expected and hero == expected[0]
			and app.enemy_intents._turn_index == 1 and app.enemies.get_enemy(2)["block"] == 1
			and app.deck.energy == 3 and app.deck.hand.size() == 5,
			"mounted End Turn commits one hero tick and retains enemy/hand cadence")
		var label := app.hero_panels[0].get_child(0) as Label
		_check(label != null and label.is_visible_in_tree() and label.text.contains("HP: 38/40"),
			"mounted hero label refreshes authoritative Bleed HP")
		var trace: Array = [_state()]
		_check(app.party.apply_damage(1, 999) and app.party.apply_damage(2, 999),
			"live terminal fixture has exactly one living hero")
		app.party._heroes[2]["hp"] = 2
		app.party._heroes[2]["block"] = 9
		app.party._heroes[2]["statuses"] = {"bleed": 2}
		var before := _state()
		await _mouse(app.end_turn_button)
		_closed(CombatBattleResult.DEFEAT)
		_check(app.party.is_defeated() and app.party.get_hero(3)["block"] == 9
			and app.party.get_hero(3)["statuses"] == {"bleed": 1}
			and app.enemies.get_enemies() == before[1] and app.deck.draw_pile == before[3]
			and app.deck.discard_pile == before[4] + before[2] and app.deck.energy == 0
			and app.run_rng.state == before[7] and app.enemy_intents.get_intents() == before[8]
			and app.enemy_attacks == before[9] and app.enemy_intents._turn_index == before[12],
			"mounted status defeat closes hand once before any enemy action, intent or new draw")
		await _inert()
		trace.append(_state())
		if session == 0:
			replay = trace
		else:
			_check(trace == replay, "title return/restart replays complete seeded status traces")
		await _return()
	for scenario in ["statuses", "position", "overflow", "stale"]:
		if not await _start():
			return
		app.party._heroes[0]["statuses"] = {"bleed": 2}
		match scenario:
			"statuses": app.party._heroes[2]["statuses"] = {"bleed": -1}
			"position": app.party._heroes[2]["position"] = 2
			"overflow": app.enemies._enemies[1]["block"] = CombatEnemies.MAX_INT
			"stale": app.enemy_attacks[0]["amount"] += 1
		var before := _state()
		app.end_turn_button.pressed.emit()
		app.end_turn_button.pressed.emit()
		_check(_state() == before and not app.end_turn_button.disabled,
			"mounted rejected End Turn preserves complete state and remains actionable: " + scenario)
		# Restore fixture before the normal scene update/render and Return.
		app.party._heroes[2]["statuses"] = {}
		app.party._heroes[2]["position"] = 3
		app.enemies._enemies[1]["block"] = 0
		app.enemy_attacks = app.enemy_intents.get_intents()
		await _return()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "mounted real app scene loads")
	if scene != null:
		app = scene.instantiate()
		root.add_child(app)
		await _frames()
		_check(app.title_view.is_visible_in_tree() and app.battle_result == null
			and app.result_label == null and app.victory_gold == null and app.session_gold == 0, "title has no result or payout")
		app.starter_party_path = "user://missing_outcomes_party.json"
		_fixture_start(app)
		await _frames()
		_check(app.deck == null and app.party == null and app.enemies == null
			and app.battle_result == null and app.title_view.is_visible_in_tree()
			and app.victory_gold == null and app.session_gold == 0
			and not app.start_button.disabled, "rejected Start remains actionable without partial result")
		app.starter_party_path = app.STARTER_PARTY_PATH
		# Pick a deterministic authored hand with both ally and immediate support inputs.
		var cards: Array[String] = []
		cards.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
		var found := false
		for seed_value in range(1000):
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			var deck := CombatDeck.new(cards, rng)
			deck.start_turn()
			if "seamstress_mend" in deck.hand and "warden_brace" in deck.hand:
				app.run_seed = seed_value
				found = true
				break
		_check(found, "deterministic support-hand seed found")
		await _victory()
		await _defeat()
		await _status_turns()
		await _unresolved_and_queued_support()
		app.free()
		await _frames()
	for failure in failures:
		printerr(failure)
	print("live_battle_outcomes_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## Standalone M01 admission; seeded title input is covered by live_seeded_opening_route_test.
func _fixture_start(target) -> void:
	if target.deck != null:
		target.start_button.pressed.emit()
		return
	var started: bool = target._start_battle()
	_check(started == (target.deck != null), "standalone fixture reports admission consistently")
