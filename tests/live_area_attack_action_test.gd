extends SceneTree

const ID := CombatAreaAttacks.SCRAP_BOMB_ID
var failures: Array[String] = []
var checks := 0
var app
var presenter


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _frames() -> void:
	for index in range(4):
		await process_frame


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _mouse(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).has_point(point), "mouse action lies in 1280x720 viewport")
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _state(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies, rng: RandomNumberGenerator) -> Array:
	return [deck.draw_pile.duplicate(), deck.hand.duplicate(), deck.discard_pile.duplicate(),
		deck.energy, deck.turn_active, party.get_heroes(), enemies.get_enemies(), rng.seed, rng.state]


func _live() -> Array:
	return [_state(app.deck, app.party, app.enemies, app.run_rng), app.enemy_attacks.duplicate(true),
		app.enemy_intents.get_intents(), app.enemy_intents._turn_index]


func _start() -> bool:
	app.start_button.pressed.emit()
	await _frames()
	if "--inject-missing-action" in OS.get_cmdline_user_args() and is_instance_valid(presenter.button):
		presenter.button.free()
	var valid: bool = app.deck != null and app.party != null and app.enemies != null \
		and app.battle_result != null and is_instance_valid(presenter.button)
	_check(valid, "real start mounts Scrap Bomb with complete real models")
	if valid:
		_check(app.deck.turn_active and app.deck.hand.has(ID) and app.deck.energy == 3
			and not presenter.button.disabled and presenter.button.is_visible_in_tree(), "otherwise playable seeded hand")
	return valid


func _visible() -> void:
	var ids: Array[String] = []
	for panel in app.hand_view.get_children():
		ids.append(panel.get_child(0).text)
		if panel.get_child(0).text == ID:
			_check(panel.gui_input.get_connections().is_empty(), "attack hand panel has no input handlers")
	_check(ids == app.deck.hand, "visible hand matches actual hand")
	_check(app.pile_label.text == "Draw: %d | Discard: %d" % [app.deck.draw_pile.size(), app.deck.discard_pile.size()], "visible piles refreshed")
	var support = app.get_node("LiveSupportHand")
	_check(is_instance_valid(support.energy_label) and support.energy_label.is_visible_in_tree()
		and support.energy_label.text.begins_with("Energy: %d |" % app.deck.energy), "visible shared energy refreshed")
	var meters = app.get_node("LiveCombatMeters")
	_check(is_instance_valid(meters.row), "mounted combat meter row exists")
	if is_instance_valid(meters.row):
		if "--inject-wrong-meter" in OS.get_cmdline_user_args():
			meters.row.get_child(0).hp_text.text = "wrong"
		_check(meters.row.get_child_count() == 3 + app.enemies.get_enemies().size(), "all live actors have meters")
		for meter in meters.row.get_children():
			var index: int = meter.get_index()
			var actor: Dictionary = app.party.get_hero(index + 1) if index < 3 else app.enemies.get_enemy(index - 2)
			_check(meter.is_visible_in_tree() and meter.hp_text.text == "HP: %d/%d" % [actor.hp, actor.max_hp]
				and meter.block_text.text == "Block: %d" % actor.block
				and meter.hp_bar.value == actor.hp and meter.block_bar.value == actor.block, "visible HP/Block and bars match models")
	_check(app.result_label.is_visible_in_tree() == app.battle_result.is_finished(), "visible result follows actual outcome")
	if app.battle_result.is_finished():
		var expected_text: String = "Battle result: " + app.battle_result.get_outcome()
		if app.battle_result.get_outcome() == CombatBattleResult.VICTORY:
			expected_text += " | Gold: %d" % app.session_gold
		_check(app.result_label.text == expected_text, "result text matches outcome and actual payout")


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
	presenter = app.get_node("LiveAreaAttackAction")
	_check(presenter.button == null, "title has no bomb control")
	var cards: Array[String] = []
	cards.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
	var chosen := -1
	for candidate in range(100):
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		var deck := CombatDeck.new(cards, rng)
		deck.start_turn()
		if ID in deck.hand:
			chosen = candidate
			break
	_check(chosen >= 0, "deterministic Scrap Bomb opening found")
	if chosen < 0:
		app.free()
		_finish()
		return
	app.run_seed = chosen
	var replay: Array = []
	for mode in ["mouse", "enter", "space"]:
		if not await _start():
			app.free()
			_finish()
			return
		_check(presenter.button.text.contains("Scrap Bomb") and presenter.button.text.contains("Tinker")
			and presenter.button.text.contains("2 energy"), "visible name owner and authored cost")
		_visible()
		await _key(KEY_TAB)
		_check(app.return_button.has_focus(), "End to Return Tab preserved")
		await _key(KEY_TAB)
		_check(app.end_turn_button.has_focus(), "Return to End Tab preserved")
		await _key(KEY_LEFT)
		_check(presenter.button.has_focus(), "Left reaches mounted action from End Turn")
		var rng := RandomNumberGenerator.new()
		rng.seed = chosen
		var deck := CombatDeck.new(cards, rng)
		_check(deck.start_turn(), "independent seeded deck starts")
		var party := CombatParty.new(app._load_party_definitions())
		CombatStartingBlock.new(party).apply()
		var enemies := CombatEnemies.new(app._load_enemy_definitions())
		_check(app.enemies.gain_block(1, 2) and enemies.gain_block(1, 2), "Block fixture")
		_check(app.enemies.apply_damage(2, 9) and enemies.apply_damage(2, 9), "second enemy has three HP")
		var before := _live()
		var oracle := CombatAttackCards.new()
		oracle.start_player_turn()
		_check(oracle.play_attack(deck, party, enemies, ID, 0).ok, "shared scene-free resolver accepts same fixture")
		seed(9123)
		var expected_global := randi()
		seed(9123)
		if mode == "mouse":
			await _mouse(presenter.button)
		else:
			await _key(KEY_ENTER if mode == "enter" else KEY_SPACE)
		_check(randi() == expected_global, "live play never draws global RNG")
		_check(_state(app.deck, app.party, app.enemies, app.run_rng) == _state(deck, party, enemies, rng), "complete state equals scene-free resolver")
		_check(app.deck.energy == 1 and app.deck.discard_pile == [ID]
			and app.deck.hand.size() == 4, "exact two energy and one discard")
		_check(app.enemies.get_enemy(1).hp == 7 and app.enemies.get_enemy(1).block == 0
			and app.enemies.get_enemy(2).hp == 0 and app.enemies.get_enemy(2).position == 2, "seven damage Block first and slain slot retained")
		_check(app.get_node("LiveAttackPreview").last_event.hits[0].damage == 7,
			"mounted Bomb includes first-attack passive")
		_check(_live().slice(1) == before.slice(1), "intents and selector unchanged")
		_check(is_instance_valid(app.intent_label) and app.intent_label.is_visible_in_tree()
			and app.intent_label.text == "Intent: Enemy 1 -> Hero 1 (Warden): 1 damage",
			"real mouse/keyboard bomb immediately removes slain Guard intent and retains Ragling")
		_check(app.session_gold == 0, "nonterminal bomb awards no gold")
		_check(presenter.button == null and app.battle_result.can_continue(), "spent card removes action; surviving enemy keeps fight active")
		_visible()
		if replay.is_empty():
			replay = _live()
		else:
			_check(_live() == replay, "same-seed restart reproduces full mouse and keyboard result")
		app.return_button.pressed.emit()
		await _frames()
	await _rejections()
	# Opposite survivor: the Guard's Block announcement and badge stay intact.
	if await _start():
		_check(app.enemies.apply_damage(1, 5), "Ragling at seven HP before real bomb")
		var before := _live()
		var expected: Array = before[0].duplicate(true)
		expected[3] -= 2
		expected[1].erase(ID)
		expected[2].append(ID)
		expected[6][0].hp = 0
		expected[6][1].hp -= 7
		await _mouse(presenter.button)
		_check(_live()[0] == expected and _live().slice(1) == before.slice(1)
			and app.session_gold == 0, "Guard survivor bomb preserves complete expected state, statuses, intents and RNG")
		_check(app.enemies.is_slain(1) and not app.enemies.is_slain(2)
			and app.intent_label.text == "Intent: Enemy 2: 1 Block", "living Guard alone retains exact Block intent")
		var roster = app.get_node("LiveEnemyRoster")
		_check(roster._badges.size() == 2, "both source badges mounted")
		if roster._badges.size() == 2:
			_check(roster._badges[1].is_visible_in_tree() and roster._badges[1].icon_mode == "block"
				and roster._badges[1].readable_text == "BLOCK +1"
				and roster._badges[0].icon_mode == "slain", "surviving Guard badge retains exact Block; Ragling badge slain")
		_visible()
		app.return_button.pressed.emit()
		await _frames()
	# Final living target: the existing result observer closes the deck and UI.
	if await _start():
		_check(app.enemies.apply_damage(1, 12) and app.enemies.apply_damage(2, 5), "slain first slot and final enemy at seven HP")
		var before := _live()
		var expected: Array = before[0].duplicate(true)
		var reference := RandomNumberGenerator.new()
		reference.seed = app.run_rng.seed
		reference.state = app.run_rng.state
		var expected_gold := reference.randi_range(10, 20)
		expected[8] = reference.state
		expected[3] = 0 # Existing result observer ends the player turn after victory.
		expected[4] = false
		expected[6][1].hp = 0
		expected[1].erase(ID)
		expected[2].append(ID)
		expected[2].append_array(expected[1])
		expected[1].clear()
		await _mouse(presenter.button)
		_check(_live()[0] == expected and _live().slice(1) == before.slice(1)
			and app.session_gold == expected_gold, "terminal play preserves slain slot, party and intents; draws exact gold and closes remaining hand once")
		_check(app.enemies.is_slain(1) and app.enemies.is_slain(2)
			and app.battle_result.get_outcome() == CombatBattleResult.VICTORY
			and not app.deck.turn_active and app.end_turn_button.disabled, "final enemy triggers live victory")
		_check(is_instance_valid(app.intent_label) and app.intent_label.is_visible_in_tree()
			and app.intent_label.text == "Intent: none", "terminal real bomb clears every dead enemy announcement")
		_visible()
		app.return_button.pressed.emit()
		await _frames()
	await _stale()
	app.free()
	_finish()


func _rejections() -> void:
	for mode in ["energy", "downed", "position", "removed", "targets", "inactive", "terminal", "hidden", "identity", "deck_identity", "enemies_identity", "rng_identity", "result_identity", "presenter_missing", "presenter_unbound", "queued_turn"]:
		if not await _start():
			return
		var callback: Callable = presenter._callback
		var token: int = presenter._token
		# Queue while valid, then invalidate before the deferred commit.
		callback.call()
		_check(presenter._queued, "valid callback queues actual activation: " + mode)
		var original_party: CombatParty = app.party
		var original_deck: CombatDeck = app.deck
		var original_enemies: CombatEnemies = app.enemies
		var original_rng: RandomNumberGenerator = app.run_rng
		var attack_presenter = app.get_node("LiveAttackPreview")
		var service = attack_presenter._play
		var bonus: int = service._tinker.bonus_for_attack(ID)
		_check(bonus == 3, "rejected action starts with pending first-attack bonus: " + mode)
		if mode == "energy":
			_check(app.deck.try_spend_energy(3), "zero energy fixture")
		elif mode == "downed":
			_check(app.party.apply_damage(3, 26), "Tinker is downed")
		elif mode == "position":
			# Valid reordered roster with Tinker in disallowed front position.
			var definitions: Array = app._load_party_definitions()
			var first = definitions[0]
			definitions[0] = definitions[2]
			definitions[2] = first
			var misplaced := CombatParty.new(definitions)
			app.party._heroes = misplaced.get_heroes()
			_check(app.party.is_valid() and app.party.get_hero(1).id == "tinker", "valid mispositioned owner")
		elif mode == "removed":
			_check(app.deck.discard_played(ID), "card removed after queue")
		elif mode == "targets":
			_check(app.enemies.apply_damage(1, 12) and app.enemies.apply_damage(2, 12), "no living enemies")
		elif mode == "inactive":
			app.deck.combat_state.player_turn_active = false
			_check(ID in app.deck.hand and app.deck.energy == 3, "inactive phase retains otherwise playable card and energy")
		elif mode == "terminal":
			for position in range(1, 4):
				_check(app.party.apply_damage(position, 100), "down every hero")
			_check(app.battle_result.evaluate() == CombatBattleResult.DEFEAT, "terminal result latched")
			# Restore living heroes on the same model: only the latched result rejects.
			var restored := CombatParty.new(app._load_party_definitions())
			app.party._heroes = restored.get_heroes()
			_check(not app.party.is_defeated() and app.party.get_hero(3).hp > 0
				and app.deck.turn_active and ID in app.deck.hand, "terminal guard isolated from owner and deck eligibility")
		elif mode == "hidden":
			app.battle_view.hide()
		elif mode == "identity":
			app.party = CombatParty.new(app._load_party_definitions())
		elif mode == "deck_identity":
			var replacement := CombatDeck.new(app.deck.hand, app.run_rng)
			_check(replacement.start_turn() and ID in replacement.hand, "replacement deck otherwise holds playable card")
			app.deck = replacement
		elif mode == "enemies_identity":
			app.enemies = CombatEnemies.new(app._load_enemy_definitions())
		elif mode == "rng_identity":
			app.run_rng = RandomNumberGenerator.new()
			app.run_rng.seed = app.run_seed
		elif mode == "result_identity":
			app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		elif mode == "presenter_missing":
			app.remove_child(attack_presenter)
		elif mode == "presenter_unbound":
			attack_presenter._clear()
		elif mode == "queued_turn":
			app.enemy_intents.advance_turn()
			app.enemy_attacks = app.enemy_intents.get_intents()
		var before := _live()
		var old_state := _state(original_deck, original_party, original_enemies, original_rng)
		seed(9876)
		var global_next := randi()
		seed(9876)
		presenter._activate(token)
		callback.call()
		_check(_live() == before and _state(original_deck, original_party, original_enemies, original_rng) == old_state, "rejection preserves complete state: " + mode)
		_check(service._tinker.bonus_for_attack(ID) == bonus and randi() == global_next,
			"rejection preserves pending bonus and global RNG: " + mode)
		if mode == "presenter_missing":
			app.add_child(attack_presenter)
		app.return_button.pressed.emit()
		await _frames()
	# Duplicates must be gated even if another copy and sufficient energy remain.
	if await _start():
		app.deck.hand.append(ID)
		app.deck.combat_state.energy = 6
		var callback: Callable = presenter._callback
		callback.call()
		callback.call()
		await _frames()
		_check(app.deck.energy == 4 and app.deck.discard_pile == [ID]
			and app.deck.hand.count(ID) == 1 and app.enemies.get_enemy(1).hp == 5, "duplicate callbacks resolve exactly once with playable extra copy")
		_check(app.get_node("LiveAttackPreview")._play._tinker.bonus_for_attack(ID) == 0,
			"duplicate activation consumes shared bonus exactly once")
		app.return_button.pressed.emit()
		await _frames()


func _stale() -> void:
	if not await _start():
		return
	var callback: Callable = presenter._callback
	var old_button: Button = presenter.button
	var deck: CombatDeck = app.deck
	var party: CombatParty = app.party
	var enemies: CombatEnemies = app.enemies
	var rng: RandomNumberGenerator = app.run_rng
	var old_service = app.get_node("LiveAttackPreview")._play
	var before := _state(deck, party, enemies, rng)
	callback.call()
	app.return_button.pressed.emit()
	_check(presenter.button == null and presenter._deck == null and presenter._party == null
		and presenter._enemies == null and presenter._result == null, "Return immediately clears controls and model references")
	old_button.pressed.emit()
	callback.call()
	if not await _start():
		return
	var fresh := _live()
	callback.call()
	await _frames()
	_check(_live() == fresh and _state(deck, party, enemies, rng) == before, "stale Return and deferred callbacks preserve both sessions")
	_check(old_service._tinker.bonus_for_attack(ID) == 3
		and app.get_node("LiveAttackPreview")._play._tinker.bonus_for_attack(ID) == 3,
		"stale callbacks preserve both sessions' pending bonuses")
	_check(app.title_view.visible == false and is_instance_valid(presenter.button), "new session retains its own action")
	app.return_button.pressed.emit()
	await _frames()


func _finish() -> void:
	for failure in failures:
		printerr("FAIL: " + failure)
	print("live_area_attack_action_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
