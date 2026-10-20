extends SceneTree

var failures: Array[String] = []
var checks := 0
var app


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _frames() -> void:
	for frame in range(4):
		await process_frame


func _key(code: Key, shift := false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.shift_pressed = shift
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _click(control: Control) -> void:
	var rect := control.get_global_rect()
	_check(root.get_visible_rect().encloses(rect), "whole clickable control inside 1280x720: " + control.name)
	var motion := InputEventMouseMotion.new()
	motion.position = rect.get_center()
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = rect.get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _snapshot() -> Array:
	return [app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(), app.deck.discard_pile.duplicate(),
		app.deck.energy, app.deck.turn_active, app.party.get_heroes() if app.party != null else null,
		app.enemies.get_enemies(), app.enemy_attacks.duplicate(true), app.enemy_intents.get_intents(),
		app.enemy_intents._turn_index, app.run_rng.seed, app.run_rng.state,
		app.battle_result.get_outcome(), app.session_gold, app._battle_closed]


func _expected(pair: int) -> String:
	var proposal := CombatPositionSwaps.preview_adjacent_swap(app.party, pair, 1)
	_check(proposal.ok and proposal.heroes.size() == 3, "service returns complete legal proposal")
	var positions: PackedStringArray = []
	for hero in proposal.heroes:
		positions.append("%d: %s" % [hero.position, hero.name])
	return "Preview only: " + " | ".join(positions) + " (no movement or cost)"


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene: PackedScene = load("res://scenes/app.tscn")
	_check(scene != null, "real app scene loads")
	if scene == null:
		_finish()
		return
	app = scene.instantiate()
	root.add_child(app)
	await _frames()
	_check(app.start_button.has_focus() and app.deck == null, "real title is initial entry")
	var replay: Array = []
	var stale: Callable
	# Initial battle plus two same-seed title restarts.
	for session in range(3):
		if session == 1:
			await _key(KEY_ENTER)
		else:
			await _click(app.start_button)
		_check(app.deck != null and app.party != null and app.enemies != null
			and app.deck.turn_active and app.battle_result.can_continue(), "title creates real active seeded battle")
		_check(app.swap_preview_buttons.size() == 2 and is_instance_valid(app.swap_preview_cue), "both buttons and cue mounted")
		if app.deck == null or app.swap_preview_buttons.size() != 2 or not is_instance_valid(app.swap_preview_cue):
			app.free()
			_finish()
			return
		var before := _snapshot()
		if stale.is_valid():
			var untouched: String = app.swap_preview_cue.text
			stale.call()
			_check(app.swap_preview_cue.text == untouched and _snapshot() == before, "old button callback rejected after restart")
		var trace: Array = [before]
		var actions: Array = [app.end_turn_button, app.return_button]
		actions.append_array(app.swap_preview_buttons)
		for control in actions:
			_check(control.focus_mode == Control.FOCUS_ALL and not control.disabled, "mouse and keyboard action enabled")
		# Traverse the full loop with real Tab and reverse Tab input.
		app.end_turn_button.grab_focus()
		for index in range(1, 5):
			await _key(KEY_TAB)
			_check(actions[index % 4].has_focus(), "forward physical Tab loop")
		for index in range(1, 5):
			await _key(KEY_TAB, true)
			_check(actions[(4 - index) % 4].has_focus(), "reverse physical Tab loop")
		seed(7123)
		var global_next := randi()
		seed(7123)
		for pair in [1, 2]:
			var button: Button = app.swap_preview_buttons[pair - 1]
			_check(button.text == "Preview swap %d / %d" % [pair, pair + 1]
				and button.pressed.get_connections().size() == 1, "labeled button has exactly one handler")
			var expected := _expected(pair)
			await _click(button)
			if "--inject-wrong-preview" in OS.get_cmdline_user_args():
				app.swap_preview_cue.text = "wrong"
			_check(app.swap_preview_cue.text == expected, "mouse shows exact ordered service proposal")
			button.grab_focus()
			await _key(KEY_ENTER if session != 1 else KEY_SPACE)
			_check(app.swap_preview_cue.text == expected, "keyboard shows exact ordered service proposal")
			_check(_snapshot() == before, "preview preserves complete battle snapshot")
			_check(root.get_visible_rect().encloses(app.swap_preview_cue.get_global_rect())
				and app.swap_preview_cue.size.y >= app.swap_preview_cue.get_minimum_size().y, "cue readable within viewport")
			trace.append(app.swap_preview_cue.text)
		_check(randi() == global_next, "physical previews preserve global RNG stream")
		if session == 0:
			replay = trace
		else:
			_check(trace == replay, "same-seed restart replays exact state and both proposals")
		# Real End Turn still works, and previews query advanced authoritative state.
		await _click(app.end_turn_button)
		_check(app.enemy_intents._turn_index == 1 and app.deck.turn_active, "physical End Turn preserved")
		before = _snapshot()
		await _click(app.swap_preview_buttons[0])
		_check(app.swap_preview_cue.text == _expected(1) and _snapshot() == before, "advanced-turn preview is read-only")
		var down_position := 2 if session == 0 else 1 if session == 1 else 3
		_check(app.party.apply_damage(down_position, 10000) and app.party.is_downed(down_position), "real neighbor/mover downed")
		await _frames()
		_check(app.swap_preview_cue.text.contains("unavailable") if down_position in [1, 2]
			else app.swap_preview_cue.text == _expected(1), "selected cue automatically refreshes after downing")
		before = _snapshot()
		seed(8124)
		global_next = randi()
		seed(8124)
		for pair in [1, 2]:
			var rejected: bool = down_position in [pair, pair + 1]
			_check(app.swap_preview_buttons[pair - 1].disabled == rejected, "availability follows authoritative downed state")
			if rejected:
				await _click(app.swap_preview_buttons[pair - 1])
				app.swap_preview_buttons[pair - 1].pressed.emit()
				_check(app.swap_preview_cue.text.contains("unavailable"), "rejected press explains living-hero requirement")
		_check(_snapshot() == before and app.party.is_downed(down_position), "rejection never spends, moves or revives")
		_check(randi() == global_next, "downed rejections preserve global RNG")
		if session == 1:
			# Replacement with an invalid party must fail closed even before refresh.
			var original: CombatParty = app.party
			app.party = CombatParty.new([])
			before = _snapshot()
			app.swap_preview_buttons[0].pressed.emit()
			_check(_snapshot() == before and app.swap_preview_cue.text.contains("unavailable")
				and app.swap_preview_buttons[0].disabled and app.swap_preview_buttons[1].disabled, "invalid party press is read-only and disables both choices")
			app.party = null
			before = _snapshot()
			app.swap_preview_buttons[1].pressed.emit()
			_check(_snapshot() == before and app.swap_preview_cue.text.contains("unavailable"), "missing party rejects without changing surviving models")
			app.party = original
			await _frames()
		# Resolve victory/defeat through the existing observation boundary.
		if session == 2:
			for position in [1, 2, 3]:
				if not app.party.is_downed(position):
					_check(app.party.apply_damage(position, 10000), "complete real defeat")
		else:
			for enemy in app.enemies.get_enemies():
				_check(app.enemies.apply_damage(enemy.position, 10000), "complete real victory")
		# Press before observation must reject without itself closing/spending the turn.
		before = _snapshot()
		app.swap_preview_buttons[0].pressed.emit()
		_check(_snapshot() == before and app.swap_preview_cue.text.contains("unavailable"), "unobserved terminal roster rejects read-only")
		await _frames()
		_check(app._battle_closed and app.battle_result.is_finished() and not app.deck.turn_active
			and app.return_button.has_focus(), "actual combat closure preserves focused Return")
		before = _snapshot()
		for button in app.swap_preview_buttons:
			_check(button.disabled, "closed preview disabled")
			button.pressed.emit()
		_check(_snapshot() == before, "closed actions preserve all models")
		stale = app.swap_preview_buttons[0].pressed.get_connections()[0].callable
		var view_id: int = app.battle_view.get_instance_id()
		await _key(KEY_ENTER)
		_check(app.deck == null and app.battle_view == null and app.swap_preview_buttons.is_empty()
			and app.swap_preview_cue == null and not is_instance_id_valid(view_id), "keyboard Return frees view and clears preview references")
		_check(app.start_button.has_focus() and app.title_view.is_visible_in_tree(), "Return restores title focus")
		stale.call()
		_check(app.deck == null and app.swap_preview_cue == null, "closed stale callback inert")
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_position_swap_preview_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
