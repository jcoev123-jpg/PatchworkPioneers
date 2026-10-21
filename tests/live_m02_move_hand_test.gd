extends SceneTree

var failures: Array[String] = []
var checks := 0
var app
var hand
var catalog := M02PositionCards.new()


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _frames() -> void:
	for i in range(4):
		await process_frame


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _click(control: Control, settle := true) -> void:
	_check(is_instance_valid(control) and control.is_visible_in_tree(), "real visible input control")
	var rect := control.get_global_rect()
	_check(root.get_visible_rect().encloses(rect), "whole input rectangle fits viewport")
	var motion := InputEventMouseMotion.new()
	motion.position = rect.get_center()
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = rect.get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	if settle:
		await _frames()


func _snapshot() -> Array:
	return [app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.party.get_heroes(), app.enemies.get_enemies(), app.enemy_attacks.duplicate(true),
		app.enemy_intents.get_intents(), app.enemy_intents._turn_index,
		app.run_rng.seed, app.run_rng.state, app.battle_result.get_outcome(),
		app.session_gold, app._battle_closed, app.round_flow._started,
		app.round_flow._opening_block._consumed]


func _supply(cards: Array[String]) -> void:
	# Supply held cards to the actual session, without changing shipped starter membership.
	app.deck.hand.assign(cards)
	app.deck.combat_state.energy = 3
	app._refresh_hand()
	await _frames()
	_check(app.hand_view.get_child_count() == cards.size(), "real ordered supplied hand mounted")


func _catalog_checks() -> void:
	var starter := StarterCards.new()
	var disk = JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH))
	_check(starter.get_starting_deck().size() == 12 and disk == starter.get_starting_deck(), "unchanged twelve-card starter deck")
	for id in M02PositionCards.IDS:
		var back: bool = id == "warden_backstep"
		var definition := catalog.get_definition(id)
		_check(definition.id == id and definition.owner == "warden" and definition.cost == 1
			and definition.from_positions == ([1, 2] if back else [2, 3])
			and definition.direction == (1 if back else -1) and definition.action_kind == "adjacent_swap", "exact authored move: " + id)
		_check(starter.get_definition(id).is_empty() and id not in disk, "move excluded from starter: " + id)
		var pristine := definition.duplicate(true)
		definition.from_positions.clear()
		definition.effects["bad"] = [1]
		_check(catalog.get_definition(id) == pristine, "nested lookup copies independent")
	for malformed in [null, 1, [], {}, "", "unknown", "WARDEN_BACKSTEP"]:
		_check(catalog.get_definition(malformed).is_empty(), "unknown/malformed catalog choice rejected")


func _move(id: String, origin: int, code: Key = KEY_NONE) -> Array:
	await _supply([id, id, "warden_shield_bash", "warden_strike"])
	var panel: Control = app.hand_view.get_child(0)
	_check(hand._bindings.has(panel) and panel.gui_input.get_connections().size() == 1, "one live move handler")
	var facts: Dictionary = hand._metadata.get_facts(panel)
	_check(facts.known and facts.owner == "warden" and facts.cost_text == "Cost 1"
		and facts.from_text == ("From 1–2" if id == "warden_backstep" else "From 2–3")
		and facts.target_text == ("Swap with ally behind" if id == "warden_backstep" else "Swap with ally ahead"), "exact rendered move facts")
	_check(panel.tooltip_text.contains("living adjacent ally") and panel.tooltip_text.contains("1 energy"), "paid movement rules readable")
	var before := _snapshot()
	var expected := before.duplicate(true)
	var destination: int = origin + catalog.get_definition(id).direction
	var actor = expected[5][origin - 1]
	expected[5][origin - 1] = expected[5][destination - 1]
	expected[5][destination - 1] = actor
	for i in range(3):
		expected[5][i].position = i + 1
	expected[0].remove_at(0)
	expected[2].append(id)
	expected[3] -= 1
	if "--inject-wrong-move" in OS.get_cmdline_user_args():
		expected[3] -= 1
	seed(61234)
	var next := randi()
	seed(61234)
	if code == KEY_NONE:
		# Two real presses in one dispatch must spend/discard only once, even with two copies held.
		await _click(panel, false)
		await _click(panel, false)
		await _frames()
	else:
		app.end_turn_button.grab_focus()
		await _key(KEY_UP)
		_check(panel.has_focus(), "physical Up reaches move row")
		await _key(KEY_TAB)
		_check(app.hand_view.get_child(1).has_focus(), "physical Tab reaches second move copy")
		await _key(KEY_TAB)
		_check(panel.has_focus(), "card focus row wraps")
		await _key(code)
	_check(_snapshot() == expected, "exact paid transaction preserves all other fields/piles/RNG")
	_check(randi() == next, "input transaction preserves global RNG")
	_check(app.end_turn_button.has_focus(), "focus survives destroyed source panel")
	for i in range(3):
		var hero: Dictionary = app.party.get_hero(i + 1)
		_check(app.hero_panels[i].get_child(0).text.begins_with("%d - %s" % [i + 1, hero.name]), "hero row follows authoritative slot")
		var meter = app.get_node("LiveCombatMeters").row.get_child(i)
		_check(meter.actor_heading.text.contains(hero.name), "meter follows moved hero")
	for intent in app.enemy_intents.get_intents():
		if intent.get("type") == "attack":
			_check(app.intent_label.text.contains("Hero %d (%s)" % [intent.target_position,
				app.party.get_hero(intent.target_position).name]), "intent announces current occupant")
	var target := CombatAttackTargeting.new()
	_check(target.get_preview(app.deck, app.party, app.enemies, "warden_shield_bash").playable == (destination == 1), "Shield Bash legality follows new origin")
	_check(target.get_preview(app.deck, app.party, app.enemies, "warden_strike").playable == (destination in [1, 2]), "Strike legality follows new origin")
	var unchanged := _snapshot()
	await _click(app.swap_preview_buttons[0])
	_check(_snapshot() == unchanged and app.swap_preview_cue.text.begins_with("Preview only:"), "free preview remains read-only after paid move")
	return expected


func _reject(label: String, id := "warden_backstep") -> void:
	var panel: Control = app.hand_view.get_child(0)
	var before := _snapshot()
	seed(9191)
	var next := randi()
	seed(9191)
	await _click(panel, false)
	# Resolve the deferred callback before app's outcome observer, where relevant.
	if not hand._pending.is_empty():
		hand._activate(panel, id, app.deck, app.party, app.battle_view, hand._token)
	_check(_snapshot() == before and randi() == next, label + ": exact no-spend/no-move/no-RNG rejection")
	await _frames()


func _status_backstep_turn() -> void:
	var replay: Array = []
	for session in range(2):
		app.run_seed = 42
		_fixture_start(app)
		await _frames()
		var ready: bool = app.deck != null and app.party != null and app.round_flow != null
		_check(ready, "status backstep has real session services")
		if not ready:
			return
		hand = app.get_node("LiveSupportHand")
		_check(app.deck.turn_active and app.party.get_hero(1).id == "warden"
			and app.party.get_hero(1).block == 6 and app.party.get_hero(2).id == "seamstress"
			and app.enemy_intents._turn_index == 0 and app.enemy_intents.get_intents() == [
				{"enemy_position": 1, "type": "attack", "amount": 1, "target_position": 1},
				{"enemy_position": 2, "type": "block", "amount": 1}],
			"authored living formation, opening passive and front attack really present")
		app.party._heroes[0].hp = 32
		app.party._heroes[0].block = 4
		app.party._heroes[0]["statuses"] = {"bleed": 3, "weak": 2, "exposed": 1}
		app.party._heroes[1].hp = 20
		app.party._heroes[1].block = 0
		app.party._heroes[1]["statuses"] = {"bleed": 2, "exposed": 2}
		var moved: Array = await _move("warden_backstep", 1, KEY_ENTER if session else KEY_NONE)
		_check(app.party.get_hero(1).id == "seamstress" and app.party.get_hero(2).id == "warden",
			"status-bearing paid backstep really reorders living actors")
		var expected := moved.duplicate(true)
		# Owner Bleed bypasses Block, then the announced 1 * 3/2 floors to 1.
		expected[5][0].hp = 20 - 2 - 1
		expected[5][0].statuses = {"bleed": 1, "exposed": 1}
		expected[5][1].hp = 32 - 3
		expected[5][1].statuses = {"bleed": 2, "weak": 1}
		for hero in expected[5]:
			hero.block = 0
		expected[6][1].block = 1
		expected[2].append_array(expected[0])
		expected[0] = []
		_check(expected[1].size() >= 5, "next hand needs no refill or RNG")
		for i in range(5):
			expected[0].append(expected[1].pop_back())
		expected[3] = 3
		expected[7] = [
			{"enemy_position": 1, "type": "attack", "amount": 1, "target_position": 2},
			{"enemy_position": 2, "type": "block", "amount": 1}]
		expected[8] = expected[7].duplicate(true)
		expected[9] = 1
		seed(51050)
		var next := randi()
		seed(51050)
		await _click(app.end_turn_button)
		_check(_snapshot() == expected and randi() == next,
			"physical End Turn: exact ID-local ticks, moved target HP, zero Block/no second passive, piles, energy, intents and RNG")
		var trace: Array = [moved, _snapshot()]
		if session == 0:
			replay = trace
		else:
			_check(trace == replay, "same-seed status backstep and physical End Turn replay exactly")
		await _click(app.return_button)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	_catalog_checks()
	await _status_backstep_turn()
	var replay: Array = []
	for session in range(2):
		_fixture_start(app)
		await _frames()
		_check(app.deck != null and app.deck.turn_active and app.party.is_valid()
			and app.battle_result.can_continue(), "real active battle preconditions")
		if app.deck == null:
			break
		hand = app.get_node("LiveSupportHand")
		for i in range(3):
			app.party.apply_damage(i + 1, i + 1)
			app.party.gain_block(i + 1, i + 2)
			app.party._heroes[i]["statuses"] = {"weak": i + 1}
			app.party._heroes[i]["metadata"] = {"nested": [i, {"kept": true}]}
		var trace: Array = []
		trace.append(await _move("warden_backstep", 1))
		trace.append(await _move("warden_backstep", 2, KEY_ENTER))
		await _supply(["warden_backstep"])
		await _reject("illegal origin")
		trace.append(await _move("warden_advance", 3, KEY_SPACE))
		trace.append(await _move("warden_advance", 2))
		await _supply(["warden_advance"])
		await _reject("advance illegal at front", "warden_advance")
		if session == 0:
			replay = trace
		else:
			_check(trace == replay, "same-seed mouse/key replay exact")
		# A moved front occupant receives the announced hit on the real End Turn path.
		await _move("warden_backstep", 1)
		for hero in app.party._heroes:
			hero.block = 0
			hero.statuses = {}
		var front: Dictionary = app.party.get_hero(1)
		var damage := 0
		for intent in app.enemy_intents.get_intents():
			if intent.get("type") == "attack" and intent.target_position == 1:
				damage += intent.amount
		_check(front.id == "seamstress" and damage > 0, "nonvacuous moved target and announced front hit")
		await _click(app.end_turn_button)
		_check(app.enemy_intents._turn_index == 1 and app.party.get_hero(1).hp == front.hp - damage, "End Turn hits current occupant")
		# Return Warden to front for otherwise-legal rejection fixtures.
		await _move("warden_advance", 2)
		await _supply(["warden_backstep"])
		app.deck.combat_state.energy = 0
		await _reject("insufficient energy")
		await _supply(["warden_backstep"])
		app.deck.combat_state.player_turn_active = false
		await _reject("inactive turn")
		app.deck.combat_state.player_turn_active = true
		await _supply(["warden_backstep"])
		app._battle_closed = true
		await _reject("closed battle with otherwise legal move")
		app._battle_closed = false
		await _supply(["warden_backstep"])
		var queued_panel: Control = app.hand_view.get_child(0)
		await _click(queued_panel, false)
		_check(not hand._pending.is_empty(), "real click queued before turn advances")
		app.enemy_intents.advance_turn()
		var queued_before := _snapshot()
		hand._activate(queued_panel, "warden_backstep", app.deck, app.party, app.battle_view, hand._token)
		_check(_snapshot() == queued_before, "queued old-turn panel cannot play in next turn")
		await _supply(["warden_backstep"])
		queued_panel = app.hand_view.get_child(0)
		await _click(queued_panel, false)
		_check(not hand._pending.is_empty(), "real click queued before session binding changes")
		var result: CombatBattleResult = app.battle_result
		app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		queued_before = _snapshot()
		hand._activate(queued_panel, "warden_backstep", app.deck, app.party, app.battle_view, hand._token)
		_check(_snapshot() == queued_before, "queued replaced result/session rejected")
		app.battle_result = result
		await _supply(["warden_backstep"])
		var panel: Control = app.hand_view.get_child(0)
		var callback: Callable = hand._bindings[panel]
		app.deck.hand[0] = "warden_advance"
		await _reject("unheld/replaced ID")
		await _supply(["warden_backstep", "warden_backstep"])
		app.hand_view.move_child(app.hand_view.get_child(0), 1)
		await _reject("original index changed")
		await _supply(["warden_backstep"])
		panel = app.hand_view.get_child(0)
		callback = hand._bindings[panel]
		await _click(panel, false)
		app._refresh_hand()
		var before := _snapshot()
		await _frames()
		_check(_snapshot() == before, "queued stale panel rejected after hand rebuild")
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = true
		callback.call(event)
		_check(_snapshot() == before, "freed panel callback inert")
		await _supply(["warden_backstep"])
		var living_roster: Array = app.party.get_heroes()
		app.party.apply_damage(2, 10000)
		await _reject("downed neighbor")
		await _supply(["warden_backstep"])
		app.party.apply_damage(1, 10000)
		await _reject("downed mover")
		await _supply(["warden_backstep"])
		if session == 0:
			# Keep the move otherwise legal: victory itself must reject before observation.
			app.party._heroes.assign(living_roster)
			_check(not app.party.is_downed(1) and not app.party.is_downed(2)
				and app.deck.energy == 3, "terminal victory has living legal mover/neighbor and energy")
			for enemy in app.enemies.get_enemies():
				app.enemies.apply_damage(enemy.position, 10000)
		else:
			app.party.apply_damage(3, 10000)
		await _reject("unobserved terminal battle")
		_check(app._battle_closed and not app.deck.turn_active, "real terminal observer closes fight")
		before = _snapshot()
		callback.call(event)
		_check(_snapshot() == before, "terminal stale callback inert")
		await _click(app.return_button)
		_check(app.deck == null and app.start_button.has_focus(), "real Return releases session")
		_fixture_start(app)
		await _frames()
		before = _snapshot()
		callback.call(event)
		_check(_snapshot() == before, "restarted session rejects old callback")
		await _click(app.return_button)
	app.free()
	for failure in failures:
		printerr(failure)
	print("live_m02_move_hand_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## Standalone M01 admission; seeded title input is covered by live_seeded_opening_route_test.
func _fixture_start(target) -> void:
	if target.deck != null:
		target.start_button.pressed.emit()
		return
	var started: bool = target._start_battle()
	_check(started == (target.deck != null), "standalone fixture reports admission consistently")
