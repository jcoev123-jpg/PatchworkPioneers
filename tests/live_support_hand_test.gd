extends SceneTree

var failures: Array[String] = []
var checks := 0
var app
var presenter
var reference: CombatDeck
var reference_party: CombatParty
var reference_rng: RandomNumberGenerator
var service := CombatStarterSupportPlay.new()


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _frames() -> void:
	await process_frame
	await process_frame


func _key(code: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	return event


func _keyboard(code: Key) -> void:
	root.push_input(_key(code), true)
	root.push_input(_key(code, false), true)
	await _frames()


func _mouse(control: Control, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)
		if pressed:
			# A burst before deferred activation must still resolve just once.
			root.push_input(event, true)
	await _frames()


func _snapshot(deck: CombatDeck, party: CombatParty, rng: RandomNumberGenerator) -> Array:
	return [deck.draw_pile.duplicate(), deck.hand.duplicate(), deck.discard_pile.duplicate(),
		deck.energy, deck.turn_active, party.get_heroes(), rng.seed, rng.state]


func _live() -> Array:
	return [_snapshot(app.deck, app.party, app.run_rng), app.enemy_attacks.duplicate(true),
		app.enemy_intents.get_intents(), app.intent_label.text, app.run_seed]


func _visible() -> void:
	if "--inject-wrong-energy" in OS.get_cmdline_user_args() and is_instance_valid(presenter.energy_label):
		presenter.energy_label.text = "deliberately wrong"
	var ids: Array[String] = []
	for panel in app.hand_view.get_children():
		_check(panel is PanelContainer and panel.is_visible_in_tree(), "mounted hand panel")
		_check(panel.get_child_count() > 0 and panel.get_child(0) is Label, "first child remains Label")
		var id: String = panel.get_child(0).text
		ids.append(id)
		if id in presenter.SUPPORT_IDS:
			_check(panel.focus_mode == Control.FOCUS_ALL and panel.get_child_count() == 2,
				"support has focus and visible action hint")
			_check(panel.gui_input.get_connections().size() == 1, "exactly one input binding")
		else:
			_check(panel.focus_mode == Control.FOCUS_NONE and panel.gui_input.get_connections().is_empty(),
				"other card remains inert")
	_check(ids == app.deck.hand, "mounted labels match entire authoritative hand")
	_check(app.pile_label.text == "Draw: %d | Discard: %d" % [app.deck.draw_pile.size(), app.deck.discard_pile.size()],
		"mounted pile counts exact")
	_check(is_instance_valid(presenter.energy_label) and presenter.energy_label.is_visible_in_tree(), "energy mounted")
	if is_instance_valid(presenter.energy_label):
		_check(presenter.energy_label.text.begins_with("Energy: %d |" % app.deck.energy), "visible energy exact")
	for index in range(3):
		var hero: Dictionary = app.party.get_hero(index + 1)
		_check(app.hero_panels[index].get_child(0).text == "%d - %s\nHP: %d/%d | Block: %d%s" % [
			hero.position, hero.name, hero.hp, hero.max_hp, hero.block,
			"\nDOWNED" if hero.hp == 0 else ""], "visible hero HP/Block exact")


func _panel(id: String) -> Control:
	for panel in app.hand_view.get_children():
		if panel.get_child(0).text == id:
			return panel
	return null


func _start(seed_value: int) -> bool:
	app.run_seed = seed_value
	app.start_button.grab_focus()
	await _keyboard(KEY_ENTER)
	var ready: bool = app.deck is CombatDeck and app.party is CombatParty and app.party.is_valid() \
		and app.run_rng != null and is_instance_valid(app.battle_view)
	_check(ready, "real focused title button starts complete session")
	if not ready:
		return false
	var cards: Array[String] = []
	cards.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
	reference_rng = RandomNumberGenerator.new()
	reference_rng.seed = seed_value
	reference = CombatDeck.new(cards, reference_rng)
	reference.start_turn()
	reference_party = CombatParty.new(app._load_party_definitions())
	CombatStartingBlock.new(reference_party).apply()
	_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(reference, reference_party, reference_rng),
		"no support action before activation; independent opening matches")
	_visible()
	return true


func _turn() -> void:
	_check(reference.end_turn(), "reference ends turn")
	_check(CombatEnemyAttacks.new().execute_attacks(reference_party, app.enemy_attacks).ok, "reference enemy phase")
	_check(reference.start_turn() and reference_party.start_player_turn(), "reference starts turn")
	await _mouse(app.end_turn_button)
	_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(reference, reference_party, reference_rng),
		"actual End Turn matches reference, including enemy damage and RNG")
	_visible()


func _play_card(id: String, keyboard: bool) -> void:
	var panel := _panel(id)
	_check(is_instance_valid(panel), "required held support found: " + id)
	if panel == null:
		return
	var intent_before: Array = [app.enemy_attacks.duplicate(true), app.enemy_intents.get_intents(), app.intent_label.text]
	_check(service.play_card(reference, reference_party, id, 0), "independent service accepts " + id)
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_SPACE)
	else:
		await _mouse(panel)
	_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(reference, reference_party, reference_rng),
		"mounted input matches complete service result: " + id)
	_check([app.enemy_attacks, app.enemy_intents.get_intents(), app.intent_label.text] == intent_before,
		"support leaves intent cadence unchanged")
	_visible()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real scene loads")
	if scene == null:
		_finish()
		return
	app = scene.instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveSupportHand")
	_check(app.deck == null and presenter._bindings.is_empty(), "title has no support bindings")
	# Find a deterministic opening with Brace, so it must stack atop the real passive.
	var cards: Array[String] = []
	cards.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
	var seed_value := -1
	for candidate in range(100):
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		var deck := CombatDeck.new(cards, rng)
		deck.start_turn()
		if "warden_brace" in deck.hand:
			seed_value = candidate
			break
	_check(seed_value >= 0, "deterministic Brace opening exists")
	var trace: Array = []
	for session in range(2):
		if not await _start(seed_value):
			app.free()
			_finish()
			return
		var before := _live()
		app.start_button.pressed.emit()
		presenter._sync_battle()
		presenter._sync_battle()
		_check(_live() == before, "duplicate start and sync never play")
		_visible()
		for inert in app.hand_view.get_children():
			if inert.get_child(0).text not in presenter.SUPPORT_IDS:
				before = _live()
				await _mouse(inert)
				_check(_live() == before, "real click on other card IDs is inert")
				break
		# Navigation from the existing button cycle reaches the support card row.
		app.end_turn_button.grab_focus()
		await _keyboard(KEY_UP)
		_check(app.hand_view.is_ancestor_of(root.gui_get_focus_owner()), "keyboard Up reaches support row")
		var brace := _panel("warden_brace")
		if brace == null:
			_check(false, "opening Brace mounted")
			break
		before = _live()
		await _mouse(brace, MOUSE_BUTTON_RIGHT)
		brace.grab_focus()
		root.push_input(_key(KEY_ENTER, true, true), true)
		await _frames()
		_check(_live() == before, "right click and key echo fail closed")
		_check(app.party.get_hero(1).block == 6, "real opening protection precedes Brace")
		await _play_card("warden_brace", false)
		_check(app.party.get_hero(1).block == 13 and app.deck.energy == 2, "Brace adds seven atop opening six and spends one")
		# Captured callback is stale after successful play, even if explicitly replayed.
		before = _live()
		presenter._activate(brace, "warden_brace", app.deck, app.party, app.battle_view)
		_check(_live() == before, "failed replay cannot charge a second time")
		var found := false
		for turn in range(12):
			if _panel("tinker_tune_up") != null:
				found = true
				break
			await _turn()
		_check(found, "Tune Up held across deterministic real turns")
		if found:
			_check(not app.deck.draw_pile.is_empty(), "normal Tune Up has a draw pile")
			await _play_card("tinker_tune_up", true)
		# Find Tune Up again, then drain the remaining draw pile via the real deck API
		# to exercise its seeded discard reshuffle through mounted input.
		found = false
		for turn in range(12):
			await _turn()
			if _panel("tinker_tune_up") != null:
				found = true
				break
		_check(found, "second held Tune Up found")
		if found:
			if app.deck.discard_pile.is_empty():
				var discard_id: String = ""
				for id in app.deck.hand:
					if id != "tinker_tune_up":
						discard_id = id
						break
				_check(not discard_id.is_empty() and app.deck.discard_played(discard_id)
					and reference.discard_played(discard_id), "real discard supplies reshuffle fixture")
			var count: int = app.deck.draw_pile.size()
			_check(app.deck.draw_extra(count) == reference.draw_extra(count), "draw fixture uses real deck API")
			app._refresh_hand()
			await _frames()
			_check(app.deck.draw_pile.is_empty() and not app.deck.discard_pile.is_empty(), "nonvacuous reshuffle preconditions")
			await _play_card("tinker_tune_up", false)
		var final := _live()
		if session == 0:
			trace = final
		else:
			_check(final == trace, "same-seed return/start replays complete state with no leaked callbacks")
		await _negative_cases()
		app.return_button.pressed.emit()
		_check(presenter._bindings.is_empty() and presenter._deck == null, "Return immediately disconnects session")
		await _frames()
		_check(app.deck == null and presenter.energy_label == null, "title removes support presentation")
	await _stale_restart(seed_value)
	app.free()
	_finish()


func _negative_cases() -> void:
	# Locate Brace using normal turns; no fixed hand fixture bypasses the live flow.
	for turn in range(12):
		if _panel("warden_brace") != null:
			break
		await _turn()
	var panel := _panel("warden_brace")
	_check(panel != null, "negative cases have a real held Brace")
	if panel == null:
		return
	var battle: Control = app.battle_view
	var deck: CombatDeck = app.deck
	var party: CombatParty = app.party
	var event := _key(KEY_ENTER)
	panel.grab_focus()
	var before := _live()
	presenter._on_card_input(null, panel, "warden_brace", deck, party, battle)
	presenter._on_card_input(event, panel, "seamstress_mend", deck, party, battle)
	var foreign := PanelContainer.new()
	root.add_child(foreign)
	presenter._on_card_input(event, foreign, "warden_brace", deck, party, battle)
	presenter._on_card_input(event, panel, "warden_brace", reference, party, battle)
	foreign.free()
	await _frames()
	_check(_live() == before, "null/foreign/wrong ID/wrong session inputs preserve complete state")
	battle.hide()
	presenter._on_card_input(event, panel, "warden_brace", deck, party, battle)
	await _frames()
	_check(_live() == before, "hidden battle cannot act")
	battle.show()
	panel.hide()
	presenter._on_card_input(event, panel, "warden_brace", deck, party, battle)
	await _frames()
	_check(_live() == before, "hidden panel cannot act")
	panel.show()
	deck.combat_state.energy = 0
	before = _live()
	await _mouse(panel)
	_check(_live() == before, "zero energy cannot spend or mutate RNG/party/piles")
	deck.combat_state.energy = 3
	deck.combat_state.player_turn_active = false
	before = _live()
	await _mouse(panel)
	_check(_live() == before, "inactive player turn cannot act")
	deck.combat_state.player_turn_active = true
	_check(party.apply_damage(1, 10000), "downed owner fixture applied")
	_check(party.is_downed(1), "owner really downed")
	before = _live()
	await _mouse(panel)
	_check(_live() == before, "downed owner cannot act")
	_check(deck.discard_played("warden_brace"), "remove held copy for unavailable-card case")
	before = _live()
	await _mouse(panel)
	_check(_live() == before, "unavailable card on stale mounted panel cannot act")
	# Keep the old panel alive while detaching it, then restart the real app.
	app.hand_view.remove_child(panel)
	presenter._sync_battle()
	_check(panel.gui_input.get_connections().is_empty(), "detached panel disconnected")
	presenter._on_card_input(event, panel, "warden_brace", deck, party, battle)
	await _frames()
	_check(_live() == before, "detached input cannot mutate old session")
	panel.free()


func _stale_restart(seed_value: int) -> void:
	if not await _start(seed_value):
		return
	var panel := _panel("warden_brace")
	_check(panel != null, "stale callback has real mounted source")
	if panel == null:
		return
	var callback: Callable = presenter._bindings[panel]
	var old_deck: CombatDeck = app.deck
	var old_party: CombatParty = app.party
	var old_rng: RandomNumberGenerator = app.run_rng
	var old_state := _snapshot(old_deck, old_party, old_rng)
	# Queue input then Return before dispatch completes: the pending play is cancelled.
	panel.grab_focus()
	callback.call(_key(KEY_ENTER))
	app.return_button.pressed.emit()
	_check(panel.gui_input.get_connections().is_empty(), "Return disconnects still-live old panel")
	await _frames()
	_check(_snapshot(old_deck, old_party, old_rng) == old_state, "queued input cancelled on Return")
	if not await _start(seed_value):
		return
	var before := _live()
	callback.call(_key(KEY_ENTER))
	await _frames()
	_check(_live() == before and _snapshot(old_deck, old_party, old_rng) == old_state,
		"captured callback with freed controls cannot act in restarted session")
	# An intervening End Turn also invalidates a queued activation before it can spend.
	panel = _panel("warden_brace")
	_check(panel != null, "queued End Turn case has held Brace")
	if panel != null:
		panel.grab_focus()
		presenter._bindings[panel].call(_key(KEY_ENTER))
		_check(reference.end_turn(), "queued-turn reference ends")
		_check(CombatEnemyAttacks.new().execute_attacks(reference_party, app.enemy_attacks).ok,
			"queued-turn reference enemy phase")
		_check(reference.start_turn() and reference_party.start_player_turn(), "queued-turn reference starts")
		app.end_turn_button.pressed.emit()
		await _frames()
		_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(reference, reference_party, reference_rng),
			"queued old-turn activation cannot play into the new hand")
	app.return_button.pressed.emit()
	await _frames()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_support_hand_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
