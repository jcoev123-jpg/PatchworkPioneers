extends SceneTree

var failures: Array[String] = []
var checks := 0
var app
var presenter
var catalog := StarterCards.new()
var targeting := CombatAttackTargeting.new()


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _frames() -> void:
	for frame in range(4):
		await process_frame


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _hover(control: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(2, 2)
	root.push_input(motion, true)
	await _frames()
	motion = InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	_check(root.get_visible_rect().has_point(motion.position), "physical hover within viewport")
	root.push_input(motion, true)
	await _frames()


func _click(control: Control) -> void:
	await _hover(control)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _panel(id: String):
	for panel in app.hand_view.get_children():
		if panel.get_child(0).text == id:
			return panel
	return null


func _snapshot() -> Array:
	return [app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(), app.deck.discard_pile.duplicate(),
		app.deck.energy, app.deck.turn_active, app.party.get_heroes(), app.enemies.get_enemies(),
		app.enemy_attacks.duplicate(true), app.enemy_intents.get_intents(), app.enemy_intents._turn_index,
		app.run_rng.seed, app.run_rng.state, app.battle_result.get_outcome()]


func _seed_for(id: String) -> int:
	var cards: Array[String] = []
	cards.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
	for candidate in range(1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		var deck := CombatDeck.new(cards, rng)
		deck.start_turn()
		if id in deck.hand:
			return candidate
	_check(false, "seeded opening found: " + id)
	return -1


func _start(seed_value: int) -> bool:
	app.run_seed = seed_value
	await _click(app.start_button)
	var valid: bool = app.deck != null and app.party != null and app.enemies != null \
		and app.battle_result != null and is_instance_valid(presenter.cue)
	_check(valid, "actual title start mounts cue with complete models")
	if valid:
		_check(app.deck.turn_active and not presenter._bindings.is_empty(), "real active opening with bound attacks")
		var count := 0
		for child in app.hand_view.get_parent().get_children():
			if child.name == "AttackPreviewCue":
				count += 1
		_check(count == 1, "exactly one battle-local cue")
	return valid


func _return() -> void:
	await _click(app.return_button)
	_check(app.deck == null and presenter.cue == null and presenter._bindings.is_empty(), "Return clears cue and bindings")


func _expected(id: String) -> String:
	var definition := catalog.get_definition(id)
	var preview := targeting.get_preview(app.deck, app.party, app.enemies, id)
	var slots: PackedStringArray = []
	for position in preview.target_positions:
		slots.append(str(position))
	var description := "Unavailable: no legal targets"
	if preview.playable:
		description = ("Choose one enemy slot: " if preview.requires_selection else "All enemies in slots: ") + ", ".join(slots)
	return "%s | %d energy | Preview (P to cycle)\n%s" % [definition.display_name, definition.cost, description]


func _assert_preview(id: String) -> void:
	if "--inject-wrong-cue" in OS.get_cmdline_user_args():
		presenter.cue.text = "wrong"
	_check(presenter._selected == _panel(id), "mounted event selected actual held attack: " + id)
	_check(presenter.cue.text == _expected(id), "exact catalog name/cost and service targets: " + id)
	_check(presenter.cue.is_visible_in_tree() and root.get_visible_rect().encloses(presenter.cue.get_global_rect()), "cue readable at 1280x720")
	_check(presenter.cue.get_line_count() <= 2, "cue fits two readable lines")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node_or_null("LiveAttackPreview")
	_check(presenter != null, "app itself mounts preview presenter")
	if presenter == null:
		app.free()
		_finish()
		return
	_check(presenter.cue == null, "no cue on title")
	for id in CombatAttackTargeting.ATTACK_IDS:
		var replay: Array = []
		for session in range(2):
			if not await _start(_seed_for(id)):
				app.free()
				_finish()
				return
			var panel = _panel(id)
			_check(panel != null, "authored attack really held: " + id)
			if panel == null:
				await _return()
				continue
			_check(panel.gui_input.get_connections().is_empty() and panel.focus_mode == Control.FOCUS_NONE, "attack remains hover-only")
			_check(panel.mouse_entered.get_connections().size() == 1, "one hover binding per panel")
			var before := _snapshot()
			seed(8123)
			var expected_global := randi()
			seed(8123)
			await _hover(panel)
			_assert_preview(id)
			var trace: Array = [presenter.cue.text]
			var held: Array[String] = []
			for card in app.deck.hand:
				if card in CombatAttackTargeting.ATTACK_IDS and card not in held:
					held.append(card)
			for step in range(held.size() * 2):
				await _key(KEY_P)
				var next_id: String = held[(held.find(id) + step + 1) % held.size()]
				_assert_preview(next_id)
				trace.append(presenter.cue.text)
			_check(randi() == expected_global, "previews do not consume global RNG")
			_check(_snapshot() == before, "repeated physical previews preserve complete battle state")
			if session == 0:
				replay = trace
			else:
				_check(trace == replay, "same seed restart reproduces preview trace")
			# Rebuild invalidates selected panels, and new panels get exactly one binding.
			var old = panel
			var callback: Callable = presenter._bindings[old].entered
			app.hand_view.remove_child(old)
			app._refresh_hand()
			await _frames()
			_check(old.mouse_entered.get_connections().is_empty(), "obsolete live panel disconnected")
			callback.call()
			_check(presenter._selected == null, "captured obsolete hover cannot select rebuilt hand")
			old.free()
			await _hover(_panel(id))
			_assert_preview(id)
			_check(_snapshot() == before, "rebuild and stale callback preserve rules state")
			await _return()
	await _negative_cases()
	await _controls()
	app.free()
	_finish()


func _negative_cases() -> void:
	for scenario in ["energy", "downed", "position", "slain", "absent_target", "missing", "inactive", "terminal", "hidden", "invalid"]:
		var id := "tinker_scrap_bomb" if scenario in ["slain", "absent_target"] else "warden_shield_bash"
		if not await _start(_seed_for(id)):
			return
		await _hover(_panel(id))
		_assert_preview(id)
		_check(targeting.get_preview(app.deck, app.party, app.enemies, id).playable, "negative starts with legal targets: " + scenario)
		if scenario == "energy":
			app.deck.combat_state.energy = 0
		elif scenario == "downed":
			_check(app.party.apply_damage(1, 10000) and app.party.is_downed(1), "owner truly downed")
		elif scenario == "position":
			var definitions: Array = app._load_party_definitions()
			var warden = definitions.pop_front()
			definitions.append(warden)
			app.party = CombatParty.new(definitions)
			app.battle_result = CombatBattleResult.new(app.party, app.enemies)
			_check(app.party.get_hero(3).id == "warden", "owner truly moved to forbidden position")
		elif scenario == "slain":
			_check(app.enemies.apply_damage(1, 10000) and app.enemies.is_slain(1), "slot one slain, slot two survives")
			_check(targeting.get_preview(app.deck, app.party, app.enemies, id).target_positions == [2], "slain slot is not compacted")
		elif scenario == "absent_target":
			app.enemies = CombatEnemies.new([app._load_enemy_definitions()[0]])
			app.battle_result = CombatBattleResult.new(app.party, app.enemies)
			_check(app.enemies.is_valid() and app.enemies.get_enemy(2).is_empty(), "valid roster with absent slot two")
			_check(targeting.get_preview(app.deck, app.party, app.enemies, id).target_positions == [1], "absent target excluded")
		elif scenario == "missing":
			_check(app.deck.discard_played(id), "selected card removed from authoritative hand")
		elif scenario == "inactive":
			app.deck.combat_state.player_turn_active = false
		elif scenario == "terminal":
			for enemy in app.enemies.get_enemies():
				app.enemies.apply_damage(enemy.position, 10000)
			await _frames()
			_check(app.battle_result.is_finished(), "terminal result observed in actual app")
		elif scenario == "hidden":
			app.battle_view.hide()
		elif scenario == "invalid":
			app.enemies = null
		var before: Array = _snapshot() if app.enemies != null else []
		# Let the normal presenter observe the change without another input.
		await _frames()
		if not before.is_empty():
			_check(_snapshot() == before, "state refresh never mutates surviving models: " + scenario)
		if scenario in ["energy", "downed", "position", "slain", "absent_target"]:
			_assert_preview(id)
			if scenario in ["energy", "downed", "position"]:
				_check(presenter.cue.text.contains("Unavailable") and not presenter.cue.text.contains("enemy slot:"), "no stale legal targets: " + scenario)
		else:
			_check(presenter._selected == null and not presenter.cue.text.contains("enemy slot:") and not presenter.cue.text.contains("All enemies"), "cue cleared: " + scenario)
		if scenario == "energy":
			app.deck.combat_state.energy = 3
			await _frames()
			_assert_preview(id)
		app.battle_view.show()
		await _return()


func _controls() -> void:
	if not await _start(_seed_for("warden_brace")):
		return
	var brace = _panel("warden_brace")
	_check(brace != null and brace.focus_mode == Control.FOCUS_ALL and brace.gui_input.get_connections().size() == 1, "support input/focus preserved")
	var block: int = app.party.get_hero(1).block
	await _key(KEY_P)
	await _click(brace)
	_check(app.party.get_hero(1).block == block + 7 and app.deck.energy == 2 and not app.deck.hand.has("warden_brace"), "physical support play still works after preview")
	await _key(KEY_P)
	await _click(app.end_turn_button)
	_check(app.enemy_intents._turn_index == 1 and app.deck.turn_active and app.deck.energy == 3, "physical End Turn advances real battle")
	_check(presenter._selected == null, "End Turn rebuild clears selected preview")
	await _key(KEY_P)
	_check(presenter._selected != null, "new turn attacks reachable by P")
	await _return()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_attack_preview_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
