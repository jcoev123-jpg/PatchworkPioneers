extends SceneTree

const STARTER_ORACLE := preload("res://tests/starter_fight_oracle.gd")

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


func _panel():
	if not is_instance_valid(app.hand_view):
		return null
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0) is Label and panel.get_child(0).text == ID:
			return panel
	return null


func _press() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


## Commit through the live release path: a press arms the panel, a physical
## left release over that panel queues the real transaction. Pushing the event
## through the real viewport keeps mouse (and the parallel keyboard) work.
func _release(panel) -> void:
	if not is_instance_valid(panel):
		return
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = panel.get_global_rect().get_center()
	root.push_input(event, true)


func _select_bomb() -> void:
	for index in range(CombatAttackTargeting.ATTACK_IDS.size() + 1):
		await _key(KEY_P)
		if presenter._card_id(presenter._armed) == ID:
			break
	_check(presenter._armed == _panel(), "P selects real Bomb panel")


func _state(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies, rng: RandomNumberGenerator) -> Array:
	return [deck.draw_pile.duplicate(), deck.hand.duplicate(), deck.discard_pile.duplicate(),
		deck.energy, deck.turn_active, party.get_heroes(), enemies.get_enemies(), rng.seed, rng.state]


func _live() -> Array:
	return [_state(app.deck, app.party, app.enemies, app.run_rng), app.enemy_attacks.duplicate(true),
		app.enemy_intents.get_intents(), app.enemy_intents._turn_index]


func _start() -> bool:
	_fixture_start(app)
	await _frames()
	if "--inject-missing-action" in OS.get_cmdline_user_args() and is_instance_valid(_panel()):
		_panel().free()
	var valid: bool = app.deck != null and app.party != null and app.enemies != null \
		and app.battle_result != null and is_instance_valid(_panel())
	_check(valid, "real start mounts held Scrap Bomb with complete real models")
	if valid:
		_check(app.deck.turn_active and app.deck.hand.has(ID) and app.deck.energy == 3
			and _panel().is_visible_in_tree() and _panel().gui_input.get_connections().size() == 1,
			"otherwise playable seeded hand with bound Bomb")
		_check(app.get_node("LiveAreaAttackAction").button == null, "obsolete mounted script creates no button")
	return valid


func _visible() -> void:
	var ids: Array[String] = []
	for panel in app.hand_view.get_children():
		if app.battle_result.get_outcome() == CombatBattleResult.VICTORY:
			_check(app.deck.hand.is_empty() and app.hand_view.get_child_count() == 1
				and panel.name == "CardReward" and app.reward_buttons.size() == 4,
				"victory replaces closed hand with one reward offering")
			continue
		ids.append(panel.get_child(0).text)
		if panel.get_child(0).text == ID:
			_check(panel.gui_input.get_connections().size() == 1, "held Bomb panel has one input handler")
	_check(ids == app.deck.hand, "visible hand matches actual hand")
	_check(app.pile_label.text == "Draw: %d | Discard: %d" % [app.deck.draw_pile.size(), app.deck.discard_pile.size()], "visible piles refreshed")
	var support = app.get_node("LiveSupportHand")
	_check(is_instance_valid(support.energy_label) and support.energy_label.is_visible_in_tree()
		and support.energy_label.text == "%d" % app.deck.energy, "visible shared energy refreshed")
	var meters = app.get_node("LiveCombatMeters")
	_check(is_instance_valid(meters.row), "mounted combat meter row exists")
	if is_instance_valid(meters.row):
		if "--inject-wrong-meter" in OS.get_cmdline_user_args():
			meters.row.get_child(0).hp_text.text = "wrong"
		_check(meters.row.get_child_count() == 3 + app.enemies.get_enemies().size(), "all live actors have meters")
		for meter in meters.row.get_children():
			var index: int = meter.get_index()
			var actor: Dictionary = app.party.get_hero(index + 1) if index < 3 else app.enemies.get_enemy(index - 2)
			_check(meter.is_visible_in_tree() and meter.hp_text.text == "%d/%d" % [actor.hp, actor.max_hp]
				and meter.hp_text.get_parent() == meter.hp_bar
				and meter.block_text.text == ("%d" % actor.block if actor.block > 0 else "")
				and meter.block_badge.visible == (actor.block > 0)
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
	presenter = app.get_node("LiveAttackPreview")
	_check(presenter.cue == null, "title has no attack cue")
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
		_check(_panel().get_child(0).text == ID, "real held Bomb identity")
		_visible()
		await _key(KEY_TAB)
		_check(app.return_button.has_focus(), "End to Return Tab preserved")
		var juice = app.get_node_or_null("LiveCombatJuice")
		_check(juice != null and is_instance_valid(juice.fast_button),
			"battle row mounts one Fast animations toggle")
		_check(is_instance_valid(app.action_corner) and app.action_corner.is_ancestor_of(app.return_button)
			and app.action_corner_row.is_ancestor_of(juice.fast_button)
			and not app.action_corner.is_ancestor_of(app.end_turn_button),
			"Return and Fast share one compact sewn corner beside the prominent End Turn")
		var preview_buttons: Array = []
		for button in app.find_children("*", "Button", true, false):
			if String(button.text).to_lower().contains("preview"):
				preview_buttons.append(button)
		_check(preview_buttons.is_empty(), "no Preview swap control is mounted in the real battle")
		await _key(KEY_TAB)
		_check(juice != null and is_instance_valid(juice.fast_button) and juice.fast_button.has_focus(),
			"Return Tab reaches the Fast animations toggle")
		await _key(KEY_TAB)
		_check(app.end_turn_button.has_focus(), "compact corner loop returns to End Turn")

		var rng := RandomNumberGenerator.new()
		rng.seed = chosen
		var deck := CombatDeck.new(cards, rng)
		var party := CombatParty.new(app._load_party_definitions())
		var enemies := CombatEnemies.new(app._load_enemy_definitions())
		# The mounted start caches the authored weighted batch before dealing,
		# so the independent deck/bind/deal sequence must spend the same draws.
		var oracle_intents := CombatEnemyIntents.new(
			RunFightEncounterSelection._parse_schedule_text(
				FileAccess.get_file_as_string(app.starter_attacks_path)))
		_check(oracle_intents.bind_battle(enemies, party, rng),
			"independent oracle binds the authored weighted starter intents")
		_check(deck.start_turn(), "independent seeded deck starts")
		CombatStartingBlock.new(party).apply()
		app.party._heroes[2]["statuses"] = {"weak": 1}
		party._heroes[2]["statuses"] = {"weak": 1}
		_check(app.enemies.apply_statuses({1: {"exposed": 1}}) and enemies.apply_statuses({1: {"exposed": 1}}), "Bomb recipients have different authoritative Exposed")
		_check(app.enemies.gain_block(1, 2) and enemies.gain_block(1, 2), "Block fixture")
		_check(app.enemies.apply_damage(2, 9) and enemies.apply_damage(2, 9), "second enemy has three HP")
		var before := _live()
		var oracle := CombatAttackCards.new()
		oracle.start_player_turn()
		_check(oracle.play_attack(deck, party, enemies, ID, 0, {"weak": 1}, {1: {"exposed": 1}, 2: {}}).ok, "shared scene-free resolver accepts same fixture")
		seed(9123)
		var expected_global := randi()
		seed(9123)
		if mode == "mouse":
			await _mouse(_panel())
		else:
			await _select_bomb()
			await _key(KEY_ENTER if mode == "enter" else KEY_SPACE)
		_check(randi() == expected_global, "live play never draws global RNG")
		_check(_state(app.deck, app.party, app.enemies, app.run_rng) == _state(deck, party, enemies, rng), "complete state equals scene-free resolver")
		_check(app.deck.energy == 1 and app.deck.discard_pile == [ID]
			and app.deck.hand.size() == 4, "exact two energy and one discard")
		_check(app.enemies.get_enemy(1).hp == 7 and app.enemies.get_enemy(1).block == 0
			and app.enemies.get_enemy(2).hp == 0 and app.enemies.get_enemy(2).position == 2, "seven damage Block first and slain slot retained")
		_check(app.get_node("LiveAttackPreview").last_event.hits[0].damage == 7,
			"mounted Bomb includes first-attack passive")
		_check(app.get_node("LiveAttackPreview").last_event.hits[1].damage == 5,
			"same Bomb applies hero Weak and recipient-specific Exposed with floor once")
		_check(_live().slice(1) == before.slice(1), "intents and selector unchanged")
		_check(is_instance_valid(app.intent_label) and not app.intent_label.visible
			and app.intent_label.text == "Intent: Enemy 1 -> Hero 1 (Warden): 5 damage",
			"real mouse/keyboard bomb immediately removes slain Guard intent and retains Ragling")
		_check(app.session_gold == 0, "nonterminal bomb awards no gold")
		_check(_panel() == null and app.battle_result.can_continue(), "spent card leaves hand; surviving enemy keeps fight active")
		_visible()
		if replay.is_empty():
			replay = _live()
		else:
			_check(_live() == replay, "same-seed restart reproduces full mouse and keyboard result")
		app.return_button.pressed.emit()
		await _frames()
	await _rejections()
	await _rosters()
	await _focus_guards()
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
		await _mouse(_panel())
		_check(_live()[0] == expected and _live().slice(1) == before.slice(1)
			and app.session_gold == 0, "Guard survivor bomb preserves complete expected state, statuses, intents and RNG")
		var guard_announced: Dictionary = {}
		for action in app.enemy_intents.get_intents():
			if action.get("enemy_position") == 2:
				guard_announced = action
		_check(app.enemies.is_slain(1) and not app.enemies.is_slain(2)
			and app.intent_label.text == STARTER_ORACLE.intent_text([guard_announced],
				["Warden", "Seamstress", "Tinker"]),
			"living Guard alone keeps its exact authored intent")
		var roster = app.get_node("LiveEnemyRoster")
		_check(roster._badges.size() == 2, "both source badges mounted")
		if roster._badges.size() == 2:
			_check(roster._badges[1].is_visible_in_tree()
				and roster._badges[1].intent_type == String(guard_announced.get("type", ""))
				and roster._badges[1].amount == int(guard_announced.get("amount", 0))
				and not roster._badges[1].readable_text.is_empty()
				and roster._badges[1].readable_text != "NO ACTION"
				and roster._badges[0].icon_mode == "slain",
				"surviving Guard badge keeps its authored intent; Ragling badge slain")
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
		await _mouse(_panel())
		_check(_live()[0] == expected and _live().slice(1) == before.slice(1)
			and app.session_gold == expected_gold, "terminal play preserves slain slot, party and intents; draws exact gold and closes remaining hand once")
		_check(app.enemies.is_slain(1) and app.enemies.is_slain(2)
			and app.battle_result.get_outcome() == CombatBattleResult.VICTORY
			and not app.deck.turn_active and app.end_turn_button.disabled, "final enemy triggers live victory")
		_check(is_instance_valid(app.intent_label) and not app.intent_label.visible
			and app.intent_label.text == "Intent: none", "terminal real bomb clears every dead enemy announcement")
		_visible()
		app.return_button.pressed.emit()
		await _frames()
	await _stale()
	app.free()
	_finish()


func _rejections() -> void:
	for mode in ["energy", "downed", "position", "removed", "targets", "inactive", "terminal", "hidden", "identity", "deck_identity", "enemies_identity", "rng_identity", "result_identity", "presenter_missing", "presenter_unbound", "queued_turn", "bad_owner_status", "bad_late_status", "rebuild", "end_turn", "intents_identity"]:
		if not await _start():
			return
		var panel = _panel()
		var callback: Callable = presenter._bindings[panel].input
		var token: int = presenter._token
		var original_result = app.battle_result
		var original_turn: int = presenter._turn
		# Queue while valid, then invalidate before the deferred commit.
		callback.call(_press())
		_release(panel)
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
		elif mode == "bad_owner_status":
			app.party._heroes[2]["statuses"] = {"weak": -1}
		elif mode == "bad_late_status":
			app.enemies._enemies[1]["statuses"] = {"exposed": "1"}
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
		elif mode == "rebuild":
			app._refresh_hand()
		elif mode == "end_turn":
			app.end_turn_button.pressed.emit()
		elif mode == "intents_identity":
			app.enemy_intents = CombatEnemyIntents.new(app._load_enemy_schedule())
		elif mode == "queued_turn":
			app.enemy_intents.advance_turn()
			app.enemy_attacks = app.enemy_intents.get_intents()
		var before := _live()
		var old_state := _state(original_deck, original_party, original_enemies, original_rng)
		seed(9876)
		var global_next := randi()
		seed(9876)
		presenter._commit(panel, ID, 0, token, original_party, original_enemies, original_result, original_rng, original_turn)
		callback.call(_press())
		_check(_live() == before and _state(original_deck, original_party, original_enemies, original_rng) == old_state, "rejection preserves complete state: " + mode)
		_check(service._tinker.bonus_for_attack(ID) == bonus and randi() == global_next,
			"rejection preserves pending bonus and global RNG: " + mode)
		if mode == "presenter_missing":
			app.add_child(attack_presenter)
		# Restore the hidden fixture before activating the guarded title control.
		app.battle_view.show()
		app.return_button.pressed.emit()
		await _frames()
	# Duplicates must be gated even if another copy and sufficient energy remain.
	if await _start():
		app.deck.hand.append(ID)
		app.deck.combat_state.energy = 6
		var panel = _panel()
		var callback: Callable = presenter._bindings[panel].input
		callback.call(_press())
		_release(panel)
		callback.call(_press())
		await _frames()
		_check(app.deck.energy == 4 and app.deck.discard_pile == [ID]
			and app.deck.hand.count(ID) == 1 and app.enemies.get_enemy(1).hp == 5, "duplicate callbacks resolve exactly once with playable extra copy")
		_check(app.get_node("LiveAttackPreview")._play._tinker.bonus_for_attack(ID) == 0,
			"duplicate activation consumes shared bonus exactly once")
		app.return_button.pressed.emit()
		await _frames()


func _rosters() -> void:
	for count in [1, 3]:
		if not await _start():
			return
		var definitions: Array = app._load_enemy_definitions()
		if count == 1:
			definitions.resize(1)
		else:
			var third: Dictionary = definitions[0].duplicate(true)
			third.id = "third_fixture"
			definitions.append(third)
		var enemies := CombatEnemies.new(definitions)
		# Keep the real bound session, altering only the controlled roster fixture.
		var roster = app.get_node("LiveEnemyRoster")
		app.battle_view.tree_exiting.disconnect(roster._clear)
		roster._clear()
		app.get_node("LiveCombatMeters")._clear()
		app.enemies._enemies = enemies.get_enemies()
		_check(app.enemies.is_valid() and app.enemies.get_enemies().size() == count,
			"real bound roster contains required live slots")
		for position in range(1, count + 1):
			_check(app.enemies.gain_block(position, position) and enemies.gain_block(position, position),
				"each occupied slot has distinct Block")
		app._refresh_enemy_roster()
		await _frames()
		var before := _live()
		var expected: Array = before[0].duplicate(true)
		expected[3] -= 2
		expected[1].erase(ID)
		expected[2].append(ID)
		for position in range(1, count + 1):
			expected[6][position - 1].hp -= 7 - position
			expected[6][position - 1].block = 0
		await _select_bomb()
		_check(_live() == before, "P selects without spending on alternate roster")
		for duplicate in range(2):
			var event := InputEventKey.new()
			event.keycode = KEY_ENTER
			event.pressed = true
			root.push_input(event, true)
		await _frames()
		_check(_live()[0] == expected and _live().slice(1) == before.slice(1),
			"target-zero Bomb damages every occupied slot once and preserves full remaining state")
		_check(presenter.last_event.ok and presenter.last_event.hits.size() == count,
			"confirmed event includes every live slot")
		_visible()
		app.return_button.pressed.emit()
		await _frames()


func _focus_until(control: Control, limit := 12) -> void:
	for index in range(limit):
		if is_instance_valid(control) and control.has_focus():
			return
		await _key(KEY_TAB)
	_check(is_instance_valid(control) and control.has_focus(), "real Tab sequence focuses expected control")


func _support_seed(support: String) -> int:
	var cards: Array[String] = []
	cards.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
	for candidate in range(1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		var deck := CombatDeck.new(cards, rng)
		deck.start_turn()
		if ID in deck.hand and support in deck.hand:
			return candidate
	_check(false, "seeded opening holds Bomb and " + support)
	return -1


## An armed Bomb must not steal Enter/Space from a control the player focused.
func _focus_guards() -> void:
	for code in [KEY_ENTER, KEY_SPACE]:
		if not await _start():
			return
		var service = presenter._play
		var deck: CombatDeck = app.deck
		var party: CombatParty = app.party
		var enemies: CombatEnemies = app.enemies
		var rng: RandomNumberGenerator = app.run_rng
		var state := _state(deck, party, enemies, rng)
		var event_before: Dictionary = presenter.last_event.duplicate(true)
		_check(app.end_turn_button.has_focus(), "battle starts with the inherited button focus")
		await _select_bomb()
		_check(root.gui_get_focus_owner() == null, "P attack selection clears the inherited battle focus")
		# Re-enter the battle's own action loop, then traverse it with real Tab input.
		app.end_turn_button.grab_focus()
		await _focus_until(app.return_button)
		_check(app.return_button.has_focus(), "real Tab sequence reaches Return")
		await _key(code)
		_check(app.deck == null and presenter._bindings.is_empty() and presenter.cue == null,
			"focused Return activates by keyboard instead of the armed Bomb")
		_check(_state(deck, party, enemies, rng) == state,
			"focused Return leaves the armed Bomb session completely untouched")
		_check(presenter.last_event == event_before and service._tinker.bonus_for_attack(ID) == 3,
			"focused Return spends no Bomb pending first-attack bonus")
	# End Turn keeps its own activation while the Bomb stays armed.
	if not await _start():
		return
	var service = presenter._play
	var before := _live()
	var event_before: Dictionary = presenter.last_event.duplicate(true)
	await _select_bomb()
	# The compact corner loop is End Turn -> Return -> Fast -> End Turn.
	app.end_turn_button.grab_focus()
	await _key(KEY_TAB)
	_check(app.return_button.has_focus(), "real Tab reaches Return in the compact corner")
	var fast_toggle = app.get_node("LiveCombatJuice").fast_button
	await _key(KEY_TAB)
	_check(is_instance_valid(fast_toggle) and fast_toggle.has_focus(),
		"real Tab reaches the Fast toggle in the same corner")
	await _key(KEY_TAB)
	_check(app.end_turn_button.has_focus(), "real Tab sequence returns focus to End Turn")
	await _key(KEY_ENTER)
	_check(app.enemy_intents._turn_index == int(before[3]) + 1, "focused End Turn advances the real round")
	_check(app.deck.turn_active and app.deck.energy == 3, "focused End Turn starts the next real player turn")
	var damaged := false
	for index in range(app.enemies.get_enemies().size()):
		if app.enemies.get_enemies()[index].hp != before[0][6][index].hp:
			damaged = true
	_check(not damaged, "focused End Turn deals no Bomb damage")
	_check(app.deck.discard_pile.count(ID) == int(before[0][2].count(ID)) + 1 and not app.deck.hand.has(ID),
		"armed Bomb left by the turn discard, not a cast")
	_check(presenter.last_event == event_before and service._tinker.bonus_for_attack(ID) == 3
		and presenter._armed == null, "focused End Turn preserves the Bomb event and pending bonus")
	app.return_button.pressed.emit()
	await _frames()
	# A focused support card keeps Enter rather than casting the armed Bomb.
	var support := "warden_brace"
	var chosen := _support_seed(support)
	if chosen < 0:
		return
	app.run_seed = chosen
	if not await _start():
		return
	var bomb_panel = _panel()
	var brace = null
	for candidate in app.hand_view.get_children():
		if candidate.get_child(0).text == support:
			brace = candidate
	_check(bomb_panel != null and brace != null, "seeded opening mounts both Bomb and playable support")
	if bomb_panel == null or brace == null:
		app.return_button.pressed.emit()
		await _frames()
		return
	var support_service = presenter._play
	var support_before := _live()
	var support_event: Dictionary = presenter.last_event.duplicate(true)
	var block_before: int = app.party.get_hero(1).block
	await _select_bomb()
	app.end_turn_button.grab_focus()
	await _key(KEY_UP)
	_check(app.hand_view.is_ancestor_of(root.gui_get_focus_owner()), "real Up leaves the buttons for the support row")
	await _focus_until(brace)
	await _key(KEY_ENTER)
	_check(app.party.get_hero(1).block == block_before + 7 and app.deck.energy == 2,
		"focused support activates with its own cost and effect")
	_check(app.deck.hand.has(ID) and app.deck.discard_pile.count(support) == int(support_before[0][2].count(support)) + 1,
		"focused support spends only its own card")
	_check(app.enemies.get_enemies() == support_before[0][6] and presenter.last_event == support_event
		and support_service._tinker.bonus_for_attack(ID) == 3,
		"focused support deals no Bomb damage and keeps the pending bonus")
	app.return_button.pressed.emit()
	await _frames()


func _stale() -> void:
	if not await _start():
		return
	var panel = _panel()
	var callback: Callable = presenter._bindings[panel].input
	var deck: CombatDeck = app.deck
	var party: CombatParty = app.party
	var enemies: CombatEnemies = app.enemies
	var rng: RandomNumberGenerator = app.run_rng
	var old_service = app.get_node("LiveAttackPreview")._play
	var before := _state(deck, party, enemies, rng)
	callback.call(_press())
	_release(panel)
	app.return_button.pressed.emit()
	_check(presenter.cue == null and presenter._deck == null and presenter._bindings.is_empty(),
		"Return immediately clears cue, bindings and model references")
	callback.call(_press())
	if not await _start():
		return
	var fresh := _live()
	callback.call(_press())
	await _frames()
	_check(_live() == fresh and _state(deck, party, enemies, rng) == before, "stale Return and deferred callbacks preserve both sessions")
	_check(old_service._tinker.bonus_for_attack(ID) == 3
		and app.get_node("LiveAttackPreview")._play._tinker.bonus_for_attack(ID) == 3,
		"stale callbacks preserve both sessions' pending bonuses")
	_check(app.title_view.visible == false and is_instance_valid(_panel()), "new session retains its own held Bomb")
	app.return_button.pressed.emit()
	await _frames()


func _finish() -> void:
	for failure in failures:
		printerr("FAIL: " + failure)
	print("live_area_attack_action_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


## Standalone M01 admission; seeded title input is covered by live_seeded_opening_route_test.
func _fixture_start(target) -> void:
	if target.deck != null:
		preload("res://tests/legacy_card_app_fixture.gd").enable(target)
		target.start_run_requested.emit()
		return
	var started: bool = target._start_battle()
	_check(started == (target.deck != null), "standalone fixture reports admission consistently")
