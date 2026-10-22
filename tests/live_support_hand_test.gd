extends SceneTree

var failures: Array[String] = []
var checks := 0
var app
var presenter
var reference: CombatDeck
var reference_party: CombatParty
var reference_enemies: CombatEnemies
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
		app.enemy_intents.get_intents(), app.intent_label.text, app.run_seed, app.enemies.get_enemies()]


func _visible() -> void:
	_check(app.enemies.get_enemies() == reference_enemies.get_enemies(), "all enemy HP and Block match independent reference")
	if "--inject-wrong-energy" in OS.get_cmdline_user_args() and is_instance_valid(presenter.energy_label):
		presenter.energy_label.text = "deliberately wrong"
	var ids: Array[String] = []
	for panel in app.hand_view.get_children():
		_check(panel is PanelContainer and panel.is_visible_in_tree(), "mounted hand panel")
		_check(panel.get_child_count() > 0 and panel.get_child(0) is Label, "first child remains Label")
		var id: String = panel.get_child(0).text
		ids.append(id)
		if id in presenter.SUPPORT_IDS:
			_check(panel.focus_mode == Control.FOCUS_ALL and panel.get_child_count() == 1 and not panel.get_child(0).visible,
				"support keeps focus and its original ID without overprinted hints")
			_check(panel.gui_input.get_connections().size() == 1, "exactly one input binding")
		else:
			var attack: bool = StarterCards.new().get_definition(id).get("target_kind") in ["enemy_single", "enemy_all"]
			_check(panel.focus_mode == Control.FOCUS_NONE and panel.gui_input.get_connections().size() == (1 if attack else 0),
				"other cards preserve focus; held attacks bind exactly one input handler")
	_check(ids == app.deck.hand, "mounted labels match entire authoritative hand")
	_check(app.pile_label.text == "Draw: %d | Discard: %d" % [app.deck.draw_pile.size(), app.deck.discard_pile.size()],
		"mounted pile counts exact")
	_check(is_instance_valid(presenter.energy_label) and presenter.energy_label.is_visible_in_tree(), "energy mounted")
	if is_instance_valid(presenter.energy_label):
		_check(presenter.energy_label.text == "Energy\n%d" % app.deck.energy, "visible energy exact")
	_check(is_instance_valid(presenter.energy_orb) and presenter.energy_label.get_parent() == presenter.energy_orb
		and presenter.energy_orb.is_visible_in_tree(), "energy belongs to the mounted drawn orb")
	_check(presenter.energy_orb.focus_mode == Control.FOCUS_NONE
		and presenter.energy_orb.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and presenter.energy_orb.gui_input.get_connections().is_empty(), "energy orb is inert")
	_check(presenter.help_label.text == "Up: cards | Click / Enter / Space: play", "general help exact outside card names")
	_check(app.battle_view.find_children("SupportHandEnergyOrb", "Control", true, false).size() == 1
		and app.battle_view.find_children("SupportHandHelp", "Label", true, false).size() == 1,
		"repeated sync leaves exactly one orb and help control")
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
	_fixture_start(app)
	await _frames()
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
	reference_enemies = CombatEnemies.new(app._load_enemy_definitions())
	CombatStartingBlock.new(reference_party).apply()
	_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(reference, reference_party, reference_rng),
		"no support action before activation; independent opening matches")
	_visible()
	return true


func _turn() -> void:
	_check(reference.end_turn(), "reference ends turn")
	_reference_enemy_phase()
	_check(reference.start_turn() and reference_party.start_player_turn(), "reference starts turn")
	await _mouse(app.end_turn_button)
	_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(reference, reference_party, reference_rng),
		"actual End Turn matches reference, including enemy damage and RNG")
	_visible()


func _reference_enemy_phase() -> void:
	for action in app.enemy_attacks:
		if reference_enemies.is_slain(action.enemy_position):
			continue
		if action.type == "attack":
			_check(CombatEnemyAttacks.new().execute_attacks(reference_party, [action]).ok, "reference enemy attack")
		else:
			_check(CombatEnemyBlocks.execute_blocks(reference_enemies, [action]).ok, "reference enemy Block")


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
		_fixture_start(app)
		presenter._sync_battle()
		presenter._sync_battle()
		_check(_live() == before, "duplicate start and sync never play")
		_visible()
		for inert in app.hand_view.get_children():
			if inert.get_child(0).text not in presenter.SUPPORT_IDS:
				before = _live()
				var id: String = inert.get_child(0).text
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = true
				presenter._on_card_input(click, inert, id, app.deck, app.party, app.battle_view)
				await _frames()
				_check(_live() == before, "support callback rejects every non-support ID: " + id)
				# Bomb now casts on left click; right click must still reject.
				await _mouse(inert, MOUSE_BUTTON_RIGHT if id == "tinker_scrap_bomb" else MOUSE_BUTTON_LEFT)
				_check(_live() == before, "unconfirmed single attack or right-click Bomb never spends")
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
		_check(app.deck == null and presenter.energy_label == null and presenter.energy_orb == null
			and presenter.help_label == null and presenter.cancel_button == null, "title removes all support presentation")
		_check(app.find_children("SupportHandEnergyOrb", "Control", true, false).is_empty(), "Return leaves no orphan orb")
	await _ally_cases()
	await _ally_move_cases()
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
	presenter._on_card_input(event, panel, "seamstress_prick", deck, party, battle)
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
		_reference_enemy_phase()
		_check(reference.start_turn() and reference_party.start_player_turn(), "queued-turn reference starts")
		app.end_turn_button.pressed.emit()
		await _frames()
		_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(reference, reference_party, reference_rng),
			"queued old-turn activation cannot play into the new hand")
	app.return_button.pressed.emit()
	await _frames()


func _ally_start() -> bool:
	var cards: Array[String] = []
	cards.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
	for candidate in range(1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		var deck := CombatDeck.new(cards, rng)
		deck.start_turn()
		if "seamstress_mend" in deck.hand and "seamstress_stitch_up" in deck.hand:
			return await _start(candidate)
	_check(false, "seeded opening contains both ally cards")
	return false


func _select_ally(id: String, keyboard: bool) -> bool:
	var panel := _panel(id)
	_check(is_instance_valid(panel), "real held ally card mounted: " + id)
	if panel == null:
		return false
	var before := _live()
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(panel)
	_check(_live() == before, "pending ally choice never charges or changes rules")
	var choosing: bool = presenter._pending.get("choosing", false)
	_check(choosing and presenter.cancel_button.is_visible_in_tree(), "target mode and cancel visible")
	_check(presenter.help_label.text == "%s: choose a living ally | Esc: cancel" % StarterCards.new().get_definition(id).display_name,
		"exact targeting help separate from energy")
	_check(presenter.energy_label.text == "Energy\n%d" % app.deck.energy, "target mode retains authoritative orb energy")
	_check(root.get_visible_rect().encloses(presenter.cancel_button.get_global_rect()), "cancel fits 1280x720 viewport")
	for index in range(3):
		var hero: Control = app.hero_panels[index]
		var living: bool = not app.party.is_downed(index + 1)
		_check((hero.focus_mode == Control.FOCUS_ALL) == living, "only living ally focusable")
		_check(presenter._targets.has(hero) == living, "only living ally has input callback")
		if living:
			_check(hero.get_child_count() == 3 and hero.get_child(2) is Label
				and hero.get_child(2).is_visible_in_tree() and hero.get_child(2).text.contains("Choose ally")
				and hero.get_child(1).name.begins_with("HeroPuppet")
				and hero.get_child(1).mouse_filter == Control.MOUSE_FILTER_IGNORE, "visible hero target cue above inert puppet")
			_check(hero.has_theme_stylebox_override("focus"), "visible hero focus outline")
	return choosing


func _ally_return() -> void:
	# Negative hidden-battle input checks have finished; make cleanup reachable.
	app.battle_view.show()
	app.return_button.pressed.emit()
	_check(presenter._pending.is_empty() and presenter._targets.is_empty(), "Return clears all target state immediately")
	await _frames()


func _ally_cases() -> void:
	# Every success begins at the real title with a seeded, unmodified starter hand.
	for id in ["seamstress_mend", "seamstress_stitch_up"]:
		for target in [1, 2, 3]:
			if not await _ally_start():
				return
			if id == "seamstress_mend" and target != 3:
				var damage := 9 if target == 1 else 2
				_check(app.party.apply_damage(target, damage) and reference_party.apply_damage(target, damage), "wounded ally fixture")
			if id == "seamstress_stitch_up":
				_check(app.party.gain_block(target, 3) and reference_party.gain_block(target, 3), "existing Block fixture")
			app._refresh_party()
			var old_energy: int = app.deck.energy
			var old_discard: int = app.deck.discard_pile.size()
			var old_hand: int = app.deck.hand.size()
			var old_hero: Dictionary = app.party.get_hero(target)
			var intent_before: Array = [app.enemy_attacks.duplicate(true), app.enemy_intents.get_intents(), app.intent_label.text]
			if await _select_ally(id, target != 1):
				var pending_before := _live()
				await _mouse(app.hero_panels[target - 1], MOUSE_BUTTON_RIGHT)
				app.hero_panels[target - 1].grab_focus()
				root.push_input(_key(KEY_ENTER, true, true), true)
				await _frames()
				_check(_live() == pending_before, "target right-click and key echo never resolve")
				app.hero_panels[0].grab_focus()
				_check(service.play_card(reference, reference_party, id, target), "reference accepts chosen living ally")
				var hero: Control = app.hero_panels[target - 1]
				if target == 1:
					await _mouse(hero)
				else:
					# Reach the hero using real focus navigation, then use both accept keys.
					for step in range(target - 1):
						await _keyboard(KEY_TAB)
					_check(hero.has_focus(), "Tab reaches chosen hero")
					var code := KEY_SPACE if target == 2 else KEY_ENTER
					root.push_input(_key(code), true)
					root.push_input(_key(code), true)
					root.push_input(_key(code, false), true)
					await _frames()
				_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(reference, reference_party, reference_rng), "chosen ally matches authoritative effect; other heroes and RNG unchanged")
				_check(app.deck.energy == old_energy - 1 and app.deck.discard_pile.size() == old_discard + 1
					and app.deck.hand.size() == old_hand - 1 and app.deck.discard_pile.back() == id, "exact one-energy one-card charge")
				var updated: Dictionary = app.party.get_hero(target)
				if id == "seamstress_mend":
					_check(updated.hp == mini(old_hero.max_hp, old_hero.hp + 5), "Mend heals up to five including full HP")
				else:
					_check(updated.block == old_hero.block + 5, "Stitch stacks exactly five Block")
				_check([app.enemy_attacks, app.enemy_intents.get_intents(), app.intent_label.text] == intent_before, "ally play leaves intents unchanged")
				_check(presenter._pending.is_empty() and presenter._targets.is_empty(), "success removes target handlers")
				_visible()
			await _ally_return()
	# Both cards share the same fail-closed interaction, including queued target callbacks.
	for id in ["seamstress_mend", "seamstress_stitch_up"]:
		for scenario in ["escape", "queued_cancel", "cancel", "downed_target", "downed_after", "downed_owner", "zero", "inactive", "hidden", "absent", "replace", "turn", "return", "stale", "switch", "detached", "foreign", "invalid_target"]:
			if not await _ally_start():
				return
			if scenario == "downed_target":
				_check(app.party.apply_damage(1, 10000) and app.party.is_downed(1), "target truly downed")
			if not await _select_ally(id, false):
				await _ally_return()
				continue
			var hero: Control = app.hero_panels[1]
			var callback: Callable = presenter._targets[hero].callback
			var before := _live()
			if scenario == "escape":
				await _keyboard(KEY_ESCAPE)
			elif scenario == "queued_cancel":
				hero.grab_focus()
				callback.call(_key(KEY_ENTER))
				root.push_input(_key(KEY_ESCAPE), true)
				root.push_input(_key(KEY_ESCAPE, false), true)
			elif scenario == "cancel":
				await _mouse(presenter.cancel_button)
			elif scenario == "downed_target":
				await _mouse(app.hero_panels[0])
			elif scenario == "foreign":
				var foreign := PanelContainer.new()
				root.add_child(foreign)
				presenter._on_target_input(_key(KEY_ENTER), foreign, 2, presenter._token)
				foreign.free()
			elif scenario == "invalid_target":
				hero.grab_focus()
				for position in [0, 1, 4]:
					presenter._on_target_input(_key(KEY_ENTER), hero, position, presenter._token)
			elif scenario == "turn":
				hero.grab_focus()
				callback.call(_key(KEY_ENTER))
				await _turn()
				before = _live()
			elif scenario == "return":
				var old_deck: CombatDeck = app.deck
				var old_party: CombatParty = app.party
				var old_rng: RandomNumberGenerator = app.run_rng
				var old_state := _snapshot(old_deck, old_party, old_rng)
				hero.grab_focus()
				callback.call(_key(KEY_ENTER))
				await _ally_return()
				_check(_snapshot(old_deck, old_party, old_rng) == old_state, "queued target Return never spends")
				if not await _ally_start():
					return
				before = _live()
				callback.call(_key(KEY_ENTER))
			elif scenario == "stale":
				await _keyboard(KEY_ESCAPE)
				await _select_ally(id, true)
				hero.grab_focus()
				callback.call(_key(KEY_ENTER))
			elif scenario == "switch":
				var other_id := "seamstress_stitch_up" if id == "seamstress_mend" else "seamstress_mend"
				await _select_ally(other_id, true)
				_check(presenter._pending.id == other_id, "only the newly selected card remains pending")
				hero.grab_focus()
				callback.call(_key(KEY_ENTER))
			else:
				if scenario == "downed_owner":
					_check(app.party.apply_damage(2, 10000) and app.party.is_downed(2), "Seamstress truly downed")
				elif scenario == "downed_after":
					_check(app.party.apply_damage(1, 10000) and app.party.is_downed(1), "target downed during pending choice")
					hero = app.hero_panels[0]
					callback = presenter._targets[hero].callback
				elif scenario == "zero":
					app.deck.combat_state.energy = 0
				elif scenario == "inactive":
					app.deck.combat_state.player_turn_active = false
				elif scenario == "hidden":
					app.battle_view.hide()
				elif scenario == "absent":
					_check(app.deck.discard_played(id), "selected card actually removed")
				elif scenario == "replace":
					app._refresh_hand()
				elif scenario == "detached":
					var card: Control = _panel(id)
					app.hand_view.remove_child(card)
					presenter._sync_battle()
					card.free()
				before = _live()
				if hero.focus_mode == Control.FOCUS_ALL and hero.is_visible_in_tree():
					hero.grab_focus()
				callback.call(_key(KEY_ENTER))
			await _frames()
			_check(_live() == before, "ally rejection preserves full state: " + id + "/" + scenario)
			if scenario in ["escape", "queued_cancel", "cancel", "replace", "turn", "hidden", "downed_owner", "downed_after", "zero", "inactive", "absent", "detached"]:
				_check(presenter._pending.is_empty() and presenter._targets.is_empty(), "cancellation removes queued work and target callbacks: " + scenario)
				for panel in app.hero_panels:
					_check(panel.focus_mode == Control.FOCUS_NONE and panel.get_child_count() == 2
						and panel.get_child(1).name.begins_with("HeroPuppet")
						and panel.gui_input.get_connections().is_empty(), "cancel restores inert hero panels")
			await _ally_return()
	# Authored from-positions: Mend rejects front, accepts back; Stitch accepts front.
	for id in ["seamstress_mend", "seamstress_stitch_up"]:
		for position in [1, 3]:
			if not await _ally_start():
				return
			var definitions: Array = app._load_party_definitions()
			var seamstress = definitions.pop_at(1)
			definitions.insert(position - 1, seamstress)
			app.party = CombatParty.new(definitions)
			reference_party = CombatParty.new(definitions)
			presenter._sync_battle()
			app._refresh_party()
			_check(app.party.get_hero(position).id == "seamstress", "actual owner at authored position fixture")
			# Settle the view after replacing the party, before checking input is inert.
			app._refresh_intents()
			_check(app.intent_label.text == "Intent: Enemy 1 -> Hero 1 (%s): 1 damage; Enemy 2: 1 Block" % app.party.get_hero(1).name,
				"reordered fixture announces the actual hero at the authored target")
			var before := _live()
			if id == "seamstress_mend" and position == 1:
				await _mouse(_panel(id))
				_check(_live() == before and presenter._pending.is_empty(), "front Mend rejects without target mode or spend")
			else:
				if await _select_ally(id, true):
					_check(service.play_card(reference, reference_party, id, position), "authored owner position accepted")
					await _mouse(app.hero_panels[position - 1])
					_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(reference, reference_party, reference_rng), "authored position live play matches service")
			await _ally_return()


func _ally_move_cases() -> void:
	for id in ["seamstress_mend", "seamstress_stitch_up"]:
		for mode in ["queued", "unconfirmed_input", "unconfirmed_sync"]:
			for keyboard in [false, true]:
				if not await _ally_start():
					return
				# Distinct actor-owned state must travel with each proposed actor.
				for index in range(3):
					_check(app.party.apply_damage(index + 1, index + 3)
						and reference_party.apply_damage(index + 1, index + 3), "movement fixture wounds living heroes")
					_check(app.party.gain_block(index + 1, index + 2)
						and reference_party.gain_block(index + 1, index + 2), "movement fixture gives distinct Block")
					app.party._heroes[index]["statuses"] = {"weak": index + 1, "bleed": index + 2}
					reference_party._heroes[index]["statuses"] = {"weak": index + 1, "bleed": index + 2}
				app._refresh_party()
				if not await _select_ally(id, keyboard):
					await _ally_return()
					continue
				var hero: Control = app.hero_panels[1]
				var callback: Callable = presenter._targets[hero].callback
				var chosen: Dictionary = app.party.get_hero(2)
				_check(chosen.id == "seamstress" and chosen.hp > 0, "living slot-2 recipient really selected")
				hero.grab_focus()
				var event: InputEvent = _key(KEY_SPACE)
				if not keyboard:
					var click := InputEventMouseButton.new()
					click.button_index = MOUSE_BUTTON_LEFT
					click.pressed = true
					click.position = hero.get_global_rect().get_center()
					event = click
				if mode == "queued":
					# Real viewport dispatch queues resolution; install movement before yielding.
					root.push_input(event, true)
					_check(presenter._pending.get("queued", false), "target input actually queued before swap")
					_check(presenter._pending.target == {"position": 2, "hero_id": chosen.id}, "queued action retains actor and slot")
				var before_move := _live()
				var proposal := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, 1)
				_check(proposal.ok and proposal.heroes.size() == 3, "real adjacent preview accepts living slots 2/3")
				_check(_live() == before_move, "preview itself leaves complete live state unchanged")
				if not proposal.ok:
					await _ally_return()
					continue
				app.party._heroes.assign(proposal.heroes)
				var reference_proposal := CombatPositionSwaps.preview_adjacent_swap(reference_party, 2, 1)
				_check(reference_proposal.ok, "reference movement valid")
				reference_party._heroes.assign(reference_proposal.heroes)
				var expected_move := before_move.duplicate(true)
				expected_move[0][5] = proposal.heroes.duplicate(true)
				var after_move := _live()
				_check(after_move == expected_move, "only intentional roster swap changes state; actor HP/Block/statuses retained")
				_check(app.party.get_hero(2).id == "tinker" and app.party.get_hero(3).id == chosen.id,
					"slot 2 really has a different living occupant")
				if mode == "unconfirmed_sync":
					presenter._sync_battle()
				elif mode == "unconfirmed_input":
					# Exercise admission before the next presentation sync can cancel it.
					callback.call(event)
				await _frames()
				_check(_live() == after_move, "movement rejects old recipient without any transaction: " + id + "/" + mode)
				_check(presenter._pending.is_empty() and presenter._targets.is_empty(), "movement clears pending choice and bindings")
				_check(not presenter.cancel_button.visible and _panel(id).has_focus(), "movement hides cancel and restores card focus")
				for panel in app.hero_panels:
					_check(panel.focus_mode == Control.FOCUS_NONE and not panel.has_focus()
						and panel.get_child_count() == 2 and panel.get_child(1).name.begins_with("HeroPuppet")
						and panel.gui_input.get_connections().is_empty()
						and not panel.has_theme_stylebox_override("focus")
						and panel.focus_next.is_empty() and panel.focus_previous.is_empty()
						and panel.focus_neighbor_bottom.is_empty(), "movement removes target cues, navigation and focus")
				callback.call(event)
				await _frames()
				_check(_live() == after_move, "captured pre-movement target callback stays inert")
				app._refresh_party()
				if await _select_ally(id, keyboard):
					# A fresh choice may target the new occupant at its current slot.
					var old_hero: Dictionary = app.party.get_hero(2)
					_check(service.play_card(reference, reference_party, id, 2), "service accepts newly chosen occupant")
					var expected := after_move.duplicate(true)
					expected[0] = _snapshot(reference, reference_party, reference_rng)
					if keyboard:
						app.hero_panels[0].grab_focus()
						await _keyboard(KEY_TAB)
						_check(hero.has_focus(), "Tab reaches moved slot-2 occupant")
						root.push_input(_key(KEY_SPACE), true)
						root.push_input(_key(KEY_SPACE), true)
						root.push_input(_key(KEY_SPACE, false), true)
						await _frames()
					else:
						await _mouse(hero)
					_check(_live() == expected, "fresh moved target matches one authoritative transaction and preserves all other state")
					_check(app.deck.energy == after_move[0][3] - 1
						and app.deck.hand.size() == after_move[0][1].size() - 1
						and app.deck.discard_pile.size() == after_move[0][2].size() + 1
						and app.deck.discard_pile.back() == id, "moved target charged and discarded exactly once")
					var updated: Dictionary = app.party.get_hero(2)
					_check(updated.id == old_hero.id and (updated.hp == mini(old_hero.max_hp, old_hero.hp + 5)
						if id == "seamstress_mend" else updated.block == old_hero.block + 5), "authored effect applies to new occupant")
					_check(presenter._pending.is_empty() and presenter._targets.is_empty(), "moved target success clears controls")
				await _ally_return()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_support_hand_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## Standalone M01 admission; seeded title input is covered by live_seeded_opening_route_test.
func _fixture_start(target) -> void:
	if target.deck != null:
		target.start_button.pressed.emit()
		return
	var started: bool = target._start_battle()
	_check(started == (target.deck != null), "standalone fixture reports admission consistently")
