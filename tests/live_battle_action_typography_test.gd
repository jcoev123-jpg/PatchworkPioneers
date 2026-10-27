extends SceneTree
## Mounted 1280x720 battle action typography, lifecycle and input regression.

const HEADING_FONT := "res://assets/fonts/LondrinaSolid-Regular.ttf"
const END_ART := "res://assets/paper/ui/hud_end_turn.png"
const STARTER_ORACLE := preload("res://tests/starter_fight_oracle.gd")
var failures: Array[String] = []
var checks := 0
var app
var hand
var seed_value := -1


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _frames() -> void:
	await process_frame
	await process_frame


func _keyboard(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _mouse(button: Control, mouse_button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = mouse_button
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _snapshot() -> Array:
	return [app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(), app.deck.discard_pile.duplicate(),
		app.deck.energy, app.deck.turn_active, app.party.get_heroes(), app.enemies.get_enemies(),
		app.run_rng.seed, app.run_rng.state, app.enemy_intents.get_intents(),
		app.enemy_attacks.duplicate(true), app.run_seed]


func _opening_seed() -> int:
	var cards: Array[String] = []
	cards.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
	for candidate in range(1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		var deck := CombatDeck.new(cards, rng)
		if deck.start_turn() and "seamstress_mend" in deck.hand:
			return candidate
	return -1


func _held_panel(card_id: String) -> Control:
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0) is Label and panel.get_child(0).text == card_id:
			return panel
	return null


func _actions(stage: String, originals: Array, labels: Array, counts: Array,
		focus: Array, prior: Array) -> void:
	var buttons := [app.end_turn_button, app.return_button, hand.cancel_button]
	var theme_font: Font = app.theme.get_font("font", "PatchHeadingButton")
	_check(theme_font != null and theme_font.resource_path == HEADING_FONT,
		"shipped action variation uses Londrina Solid Regular: " + stage)
	for index in range(3):
		var button: Button = buttons[index]
		_check(is_instance_valid(button) and button == originals[index],
			"original mounted Button identity remains: " + stage + " " + str(index))
		if not is_instance_valid(button):
			continue
		_check(button.text == labels[index] and button.pressed.get_connections().size() == counts[index]
			and counts[index] == 1, "label and exactly one callback retained: " + stage + " " + str(index))
		_check(button.theme_type_variation == &"PatchHeadingButton"
			and hand._action_variations.has(button)
			and hand._action_variations[button] == prior[index]
			and button.get_theme_font("font") == theme_font
			and button.get_theme_font_size("font_size") >= 18,
			"effective readable heading and stored prior variation: " + stage + " " + str(index))
		_check(button.focus_next == focus[index][0] and button.focus_previous == focus[index][1]
			and button.focus_mode == focus[index][2]
			and button.get_theme_stylebox("focus") != null,
			"focus neighbours/mode and sewn focus outline intact: " + stage + " " + str(index))
		_check(root.get_visible_rect().encloses(button.get_global_rect()) if button.is_visible_in_tree() else true,
			"visible action fits 1280x720: " + stage + " " + str(index))
	_check(app.end_turn_button.focus_next == app.end_turn_button.get_path_to(app.return_button),
		"End Turn remains next to Return in the real Tab cycle: " + stage)


func _start() -> bool:
	app.run_seed = seed_value
	var started: bool = app._start_battle()
	await _frames()
	_check(started and app.deck is CombatDeck and app.deck.turn_active
		and app.party is CombatParty and app.party.get_heroes().size() == 3
		and app.deck.energy == 3 and app.deck.hand.size() == 5
		and is_instance_valid(app.battle_view) and app.battle_view.is_visible_in_tree(),
		"genuine seeded battle starts with three heroes, shared five-card hand, three energy")
	return started and app.deck is CombatDeck and is_instance_valid(app.battle_view)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "shipped App scene exists")
	if scene == null:
		_finish()
		return
	app = scene.instantiate()
	root.add_child(app)
	await _frames()
	_check(STARTER_ORACLE.pin_guard_block(app, "user://live_action_typography_guard.json"),
		"shipped Guard Ragling pinned to its own authored Block alternative")
	hand = app.get_node("LiveSupportHand")
	_check(app.theme is Theme and app.deck == null and hand._action_variations.is_empty(),
		"real title owns the shared Theme but no battle action overrides")
	seed_value = _opening_seed()
	_check(seed_value >= 0, "a deterministic real opening holds Seamstress Mend")
	if seed_value < 0 or not await _start():
		app.free()
		_finish()
		return

	# Remove only the presenter's display mount, then record the genuine controls
	# and their original state before applying typography again.
	hand._clear()
	var end: Button = app.end_turn_button
	var back: Button = app.return_button
	var original_buttons := [end, back]
	var original_labels := [end.text, back.text]
	var original_counts := [end.pressed.get_connections().size(), back.pressed.get_connections().size()]
	var original_focus := [
		[end.focus_next, end.focus_previous, end.focus_mode],
		[back.focus_next, back.focus_previous, back.focus_mode]]
	var original_variations := [end.theme_type_variation, back.theme_type_variation]
	var before_presentation := _snapshot()
	_check(original_labels == ["End Turn", back.text]
		and original_counts == [1, 1] and end.focus_mode == Control.FOCUS_ALL
		and back.focus_mode == Control.FOCUS_ALL,
		"recorded two genuine operational action controls before presentation")
	hand._sync_battle()
	await _frames()
	var cancel: Button = hand.cancel_button
	_check(is_instance_valid(cancel) and not cancel.visible
		and cancel.text == "Cancel target (Esc)" and cancel.pressed.get_connections().size() == 1,
		"the real temporary Cancel action was mounted once, initially hidden")
	if not is_instance_valid(cancel):
		app.free()
		_finish()
		return
	var buttons := [end, back, cancel]
	var labels := original_labels + [cancel.text]
	var counts := original_counts + [cancel.pressed.get_connections().size()]
	var focus := original_focus + [[cancel.focus_next, cancel.focus_previous, cancel.focus_mode]]
	var prior := original_variations + [hand._action_variations.get(cancel, &"")]
	_actions("mounted", buttons, labels, counts, focus, prior)
	_check(_snapshot() == before_presentation, "mounting font variation spends no cards, energy, HP or RNG")
	var face := end.get_theme_stylebox("normal") as StyleBoxTexture
	_check(face != null and face.texture != null and face.texture.resource_path == END_ART,
		"the real End Turn keeps its sewn PNG face")
	for state in ["normal", "hover", "pressed", "disabled"]:
		_check(end.get_theme_stylebox(state) is StyleBoxTexture,
			"the authored " + state + " End Turn state remains textured")
	_check(end.get_theme_stylebox("focus") != null and not end.disabled,
		"original End Turn focus ring and enabled state remain usable")
	var normal_face: StyleBox = end.get_theme_stylebox("normal")
	for repeat in range(3):
		hand._sync_battle()
	_actions("idempotent repaint", buttons, labels, counts, focus, prior)
	_check(end.get_theme_stylebox("normal") == normal_face and _snapshot() == before_presentation,
		"repeated refresh retains the same face and never runs a turn")

	var saved_root: String = hand.ui_art_root
	hand.ui_art_root = "res://assets/paper/ui/absent/"
	hand._sync_battle()
	await _frames()
	_actions("missing art fallback", buttons, labels, counts, focus, prior)
	_check(not end.has_theme_stylebox_override("normal")
		and end.get_theme_stylebox("normal") != null
		and end.get_theme_stylebox("hover") != null
		and end.get_theme_stylebox("pressed") != null
		and end.get_theme_stylebox("disabled") != null,
		"missing End Turn art falls back to usable sewn Theme skins on the real Button")
	_check(_snapshot() == before_presentation, "missing-art refresh never spends or advances RNG")
	hand.ui_art_root = saved_root
	hand._sync_battle()
	await _frames()
	_check(end.get_theme_stylebox("normal") is StyleBoxTexture,
		"authored End Turn image returns on the same control")

	# A real keyboard card action enters target mode without committing the card.
	var panel := _held_panel("seamstress_mend")
	_check(panel != null and hand._bindings.has(panel) if panel != null else false,
		"seeded held Mend is wired to its real player-operable panel")
	if panel != null:
		var clean := _snapshot()
		panel.grab_focus()
		await _keyboard(KEY_ENTER)
		_check(hand._pending.get("choosing", false) and cancel.is_visible_in_tree()
			and hand._targets.size() == 3, "real Enter reaches ally targeting and shows Cancel")
		_actions("target mode", buttons, labels, counts, focus, prior)
		_check(_snapshot() == clean, "target selection leaves deck, heroes, enemies and RNG unchanged")
		await _mouse(app.hero_panels[0], MOUSE_BUTTON_RIGHT)
		_check(_snapshot() == clean and hand._pending.get("choosing", false),
			"right-click rejected target cannot spend or resolve")
		await _keyboard(KEY_ESCAPE)
		_check(hand._pending.is_empty() and hand._targets.is_empty() and not cancel.visible
			and _snapshot() == clean, "Escape cancels the genuine choice without payment")
		panel.grab_focus()
		await _keyboard(KEY_SPACE)
		_check(hand._pending.get("choosing", false) and cancel.is_visible_in_tree(),
			"Space reopens target selection on the original hand panel")
		await _mouse(cancel)
		_check(hand._pending.is_empty() and hand._targets.is_empty() and not cancel.visible
			and _snapshot() == clean, "mouse Cancel performs one no-spend cancellation")
		_actions("canceled target", buttons, labels, counts, focus, prior)

	# The same real Button must reject pointer activation while disabled.
	var gated := _snapshot()
	end.disabled = true
	await _mouse(end)
	_check(_snapshot() == gated and end.disabled
		and end.get_theme_stylebox("disabled") is StyleBoxTexture,
		"disabled sewn End Turn ignores live pointer input without spending or RNG")
	end.disabled = false
	_check(not end.disabled and end.pressed.get_connections().size() == 1,
		"restoring End Turn availability keeps one original press callback")

	# An independent baseline uses the same seeded deck and authoritative enemy phase.
	var cards: Array[String] = []
	cards.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var reference := CombatDeck.new(cards, rng)
	var reference_party := CombatParty.new(app._load_party_definitions())
	var reference_enemies := CombatEnemies.new(app._load_enemy_definitions())
	_check(reference.start_turn(), "reference starts the same seeded shared-hand turn")
	CombatStartingBlock.new(reference_party).apply()
	_check(app.deck.hand == reference.hand and app.deck.energy == reference.energy,
		"nonvacuous reference opening matches live five-card hand and energy")
	_check(reference.end_turn(), "reference accepts exactly one End Turn")
	for action in app.enemy_attacks:
		if reference_enemies.is_slain(action.enemy_position):
			continue
		if action.type == "attack":
			_check(CombatEnemyAttacks.new().execute_attacks(reference_party, [action]).ok,
				"reference resolves real announced enemy attack")
		else:
			_check(CombatEnemyBlocks.execute_blocks(reference_enemies, [action]).ok,
				"reference resolves real announced enemy Block")
	_check(reference.start_turn() and reference_party.start_player_turn(),
		"reference returns to one new player turn")
	await _mouse(end)
	_check(app.deck.hand == reference.hand and app.deck.draw_pile == reference.draw_pile
		and app.deck.discard_pile == reference.discard_pile
		and app.deck.energy == reference.energy and app.party.get_heroes() == reference_party.get_heroes()
		and app.run_rng.state == rng.state,
		"real mouse End Turn settles one enemy phase, draws five and grants three energy")
	_actions("after live End Turn", buttons, labels, counts, focus, prior)

	var before_return := _snapshot()
	var old_cancel_id := cancel.get_instance_id()
	back.grab_focus()
	await _keyboard(KEY_ENTER)
	_check(app.deck == null and hand._deck == null and hand._action_variations.is_empty(),
		"real keyboard Return tears down the battle and restores all prior variations")
	_check(not is_instance_id_valid(old_cancel_id)
		and hand.cancel_button == null and hand._targets.is_empty(),
		"Return destroys the temporary Cancel without a stale target or callback")
	for index in range(2):
		if is_instance_valid(buttons[index]):
			_check((buttons[index] as Button).theme_type_variation == prior[index],
				"surviving app action restores its exact pre-battle variation")
	_check(before_return.size() > 0, "before-return full gameplay snapshot was captured")

	if await _start():
		var next_end: Button = app.end_turn_button
		var next_back: Button = app.return_button
		var next_cancel: Button = hand.cancel_button
		_check(is_instance_valid(next_end) and is_instance_valid(next_back)
			and is_instance_valid(next_cancel) and next_cancel.get_instance_id() != old_cancel_id,
			"fresh genuine battle has new temporary Cancel, no prior target control")
		for button in [next_end, next_back, next_cancel]:
			_check(button.theme_type_variation == &"PatchHeadingButton"
				and (button.get_theme_font("font") as Font).resource_path == HEADING_FONT
				and button.get_theme_font_size("font_size") >= 18
				and button.pressed.get_connections().size() == 1,
				"fresh battle action has one callback and readable heading font")
		_check(hand._targets.is_empty() and hand._pending.is_empty()
			and hand._action_variations.size() == 3, "fresh battle starts without stale target state")
		next_back.pressed.emit()
		await _frames()
		_check(hand._action_variations.is_empty(), "second Return also restores every action variation")
	app.free()
	_finish()


func _finish() -> void:
	for problem in failures:
		printerr(problem)
	print("live_battle_action_typography_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
