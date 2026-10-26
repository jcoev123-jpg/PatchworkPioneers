extends "res://tests/live_button_golem_pop_hand_test.gd"

const ROLL_IDS := ["button_golem_starter_threadwheel_roll", "button_golem_starter_threadwheel_roll_plus",
	"button_golem_button_roll", "button_golem_button_roll_plus"]
const BLOCK := [5, 7, 5, 8]


func _arm_roll(panel: Control, input: int) -> void:
	if input == 0:
		await _mouse(panel)
	else:
		panel.grab_focus()
		await _keyboard(KEY_ENTER if input == 1 else KEY_SPACE)
	_check(presenter._pending.get("choosing", false) and not presenter._targets.is_empty(), "real ally picker armed")


func _roll_success(id: String, seat: int, target: int, input: int) -> void:
	var panel := await _begin(id, seat)
	if panel == null:
		await _dispose()
		return
	for index in range(3):
		app.party._heroes[index].hp -= index + 1
		app.party._heroes[index].block += index + 2
		app.party._heroes[index].buttons_popped = index + 7
		app.party._heroes[index].statuses = {"weak": index + 1, "bleed": index + 2}
	app._refresh_party()
	app._refresh_intents()
	var meta = presenter._metadata
	var definition: Dictionary = ButtonGolemStarterCards.new().get_definition(id) if id.begins_with("button_golem_starter") else ButtonGolemPoolCards.new().get_definition(id)
	var facts: Dictionary = meta.get_facts(panel)
	var gain: int = BLOCK[ROLL_IDS.find(id)]
	_check(not definition.is_empty() and meta.definition(id) == definition, "authentic own catalog record")
	_check(facts.known and facts.owner_text == "Button Golem" and facts.cost == 1
		and facts.from_text == "From " + meta._positions([1, 2, 3])
		and facts.target_text == "Living other ally" and definition.to_positions.is_empty()
		and meta.visual_state(panel).playable and panel.focus_mode == Control.FOCUS_ALL, "authored mounted face and availability")
	_check(meta.short_line(id) == "Swap with a living other ally; gain %d Block on self." % gain
		and panel.tooltip_text.contains("1 energy") and panel.tooltip_text.contains("living other ally in any hero slot")
		and panel.tooltip_text.contains("gain %d Block on self" % gain), "printed Block and unrestricted other-ally target")
	var rng := RandomNumberGenerator.new()
	rng.seed = app.run_rng.seed
	rng.state = app.run_rng.state
	var oracle := CombatDeck.new([], rng)
	oracle.hand.assign(app.deck.hand)
	oracle.draw_pile.assign(app.deck.draw_pile)
	oracle.discard_pile.assign(app.deck.discard_pile)
	oracle.combat_state = CombatState.new()
	oracle.combat_state.player_turn_active = true
	oracle.combat_state.energy = app.deck.energy
	var party := CombatParty.new(app.party.get_heroes())
	party._heroes = app.party.get_heroes()
	var enemies: Array = app.enemies.get_enemies()
	var initial: Array = app.party.get_heroes()
	var state: int = app.run_rng.state
	for step in range(2):
		var destination: int = target if step == 0 else seat
		var origin: int = seat if step == 0 else target
		var before := _pool_state()
		var receipt := CombatButtonGolemRollCards.new().play_card(oracle, party, id, destination)
		_check(receipt.ok and receipt.from_position == origin and receipt.block_gained == gain, "independent paid Roll oracle")
		panel = _pool_panel(id)
		_check(panel != null and presenter._bindings.has(panel), "remaining held copy bound at new seat")
		if panel == null:
			break
		await _arm_roll(panel, input)
		_check(_pool_state() == before and presenter._targets.size() == 2
			and not presenter._targets.has(app.hero_panels[origin - 1]), "pure picker excludes self")
		await _keyboard([KEY_1, KEY_2, KEY_3][origin - 1])
		_check(_pool_state() == before, "self number key is inert")
		var actor_panel: Control = app.hero_panels[destination - 1]
		_check(presenter._targets.has(actor_panel), "intended living ally has real listener")
		var callback: Callable = presenter._targets[actor_panel].callback
		if input == 0:
			await _mouse(actor_panel)
		elif input in [1, 2]:
			actor_panel.grab_focus()
			await _keyboard(KEY_ENTER if input == 1 else KEY_SPACE)
		else:
			root.push_input(_key([KEY_1, KEY_2, KEY_3][destination - 1]), true)
			root.push_input(_key([KEY_1, KEY_2, KEY_3][destination - 1]), true)
			root.push_input(_key([KEY_1, KEY_2, KEY_3][destination - 1], false), true)
			await _frames()
		_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(oracle, party, rng)
			and app.enemies.get_enemies() == enemies and app.run_rng.state == state, "exact mounted oracle state and unchanged RNG after each swap")
		_check(app.deck.energy == 5 - step and app.deck.hand.count(id) == 1 - step
			and app.deck.discard_pile.count(id) == step + 1, "exactly one paid copy per input burst")
		var expected: Array = initial.duplicate(true)
		expected[seat - 1].block += gain * (step + 1)
		if step == 0:
			var mover: Dictionary = expected[seat - 1]
			expected[seat - 1] = expected[target - 1]
			expected[target - 1] = mover
		for index in range(3):
			expected[index].position = index + 1
			var hero: Dictionary = expected[index]
			var label: String = app.hero_panels[index].get_child(0).text
			_check(label.contains(hero.name) and label.contains("HP: %d/%d | Block: %d" % [hero.hp, hero.max_hp, hero.block]), "real actor order HP and Block HUD")
		_check(app.party.get_heroes() == expected, "all actor HP Block statuses counters follow identity; only Golem gains")
		_check(presenter.energy_label.text == str(app.deck.energy) and app.hand_view.get_child_count() == app.deck.hand.size()
			and presenter._pending.is_empty() and presenter._targets.is_empty()
			and not presenter.cancel_button.visible and app.end_turn_button.has_focus(), "hand energy picker and focus reset")
		var after := _pool_state()
		callback.call(_press())
		await _frames()
		_check(_pool_state() == after, "retired receipt cannot spend remaining copy")
	_last_result = _pool_state()
	await _dispose()


func _roll_refuse(mode: String, phase: int) -> void:
	var panel := await _begin(ROLL_IDS[1])
	if panel == null:
		await _dispose()
		return
	var callback: Callable = presenter._bindings[panel]
	if phase > 0:
		await _arm_roll(panel, 1)
		callback = presenter._targets[app.hero_panels[0]].callback
		if phase == 2:
			callback.call(_press())
			_check(presenter._pending.get("queued", false), "real deferred target commit queued")
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"torn": app.party.apply_damage(2, 999)
		"target_torn": app.party.apply_damage(1, 999)
		"tangled": app.party._heroes[1].statuses = {"tangled": 1}
		"target_tangled": app.party._heroes[0].statuses = {"tangled": 1}
		"no_targets":
			app.party.apply_damage(1, 999)
			app.party.apply_damage(3, 999)
		"owner": app.party._heroes[1].id = "seamstress"
		"duplicate_owner": app.party._heroes[0].id = "button_golem"
		"status": app.party._heroes[0].statuses = {"weak": -1}
		"status_type": app.party._heroes[1].statuses = []
		"overflow": app.party._heroes[1].block = CombatParty.MAX_INT
		"hand":
			app.deck.discard_played(ROLL_IDS[1])
			app.deck.discard_played(ROLL_IDS[1])
		"inactive": app.deck.combat_state.player_turn_active = false
		"closed": app._battle_closed = true
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"turn": app.enemy_intents.advance_turn()
		"label": panel.get_child(0).text = ROLL_IDS[0]
		"panel": app._refresh_hand()
		"battle":
			app.battle_view = app.battle_view.duplicate(0)
			app.add_child(app.battle_view)
		"deck":
			var rng := RandomNumberGenerator.new()
			rng.seed = 8
			app.deck = CombatDeck.new([ROLL_IDS[1]], rng)
			app.deck.start_turn()
		"identity": app.party._heroes[0].id = "replacement"
		"same_id": app.party._heroes[0] = app.party._heroes[0].duplicate(true)
		"owner_ref": app.party._heroes[1] = app.party._heroes[1].duplicate(true)
		"seat":
			var hero: Dictionary = app.party._heroes[1]
			app.party._heroes[1] = app.party._heroes[2]
			app.party._heroes[2] = hero
			app.party._heroes[1].position = 2
			app.party._heroes[2].position = 3
			_check(app.party.is_valid(), "otherwise valid changed caster seat")
		"escape": await _keyboard(KEY_ESCAPE)
		"cancel": presenter.cancel_button.pressed.emit()
	app._refresh_intents()
	if phase == 0 and mode not in ["target_torn", "target_tangled", "panel", "battle"]:
		presenter._metadata._update_visual(panel)
		_check(not presenter._metadata.visual_state(panel).playable, "resolver preflight dims invalid card: " + mode)
	var before := _pool_state()
	callback.call(_press())
	await _frames()
	if phase == 0 and mode in ["target_torn", "target_tangled"]:
		_check(presenter._pending.get("choosing", false) and presenter._targets.size() == 1
			and presenter._targets.has(app.hero_panels[2]), "unavailable ally filtered; other ally remains legal")
		await _keyboard(KEY_1)
		_check(_pool_state() == before, "unavailable ally key cannot spend")
		await _keyboard(KEY_ESCAPE)
	_check(_pool_state() == before and presenter._pending.is_empty(), "atomic no-spend " + mode)
	if phase > 0 or mode not in ["target_torn", "target_tangled"]:
		callback.call(_key(KEY_ENTER))
	await _frames()
	_check(_pool_state() == before, "rejected repeat inert " + mode)
	await _dispose()


func _unknown_roll() -> void:
	await _begin(ROLL_IDS[0])
	var id := "button_golem_button_roll_plus_plus"
	app.deck.hand[0] = id
	app._refresh_hand()
	await _frames()
	var panel := _pool_panel(id)
	_check(panel != null and not presenter._bindings.has(panel), "unknown Roll alias has no action listener")
	if panel != null:
		_check(not presenter._metadata.get_facts(panel).known
			and not presenter._metadata.visual_state(panel).playable, "unknown Roll alias remains unknown and dim")
		var before := _pool_state()
		await _mouse(panel)
		await _keyboard(KEY_ENTER)
		await _keyboard(KEY_SPACE)
		_check(_pool_state() == before and panel.focus_mode == Control.FOCUS_NONE, "unknown Roll alias cannot spend or focus")
	await _dispose()


func _one_target() -> void:
	var panel := await _begin(ROLL_IDS[0])
	app.party._heroes[0].statuses = {"tangled": 1}
	app._refresh_intents()
	await _arm_roll(panel, 2)
	_check(presenter._targets.size() == 1 and presenter._targets.has(app.hero_panels[2]), "only resolver-legal living other ally offered")
	var before := _pool_state()
	await _keyboard(KEY_1)
	_check(_pool_state() == before, "Tangled target number is inert")
	await _keyboard(KEY_3)
	_check(app.party.get_hero(3).id == "button_golem" and app.deck.energy == 5, "legal remaining ally number commits")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id in ROLL_IDS:
		for seat in [1, 2, 3]:
			for target in [1, 2, 3]:
				if target == seat:
					continue
				for input in [0, 1, 2, 3]:
					await _roll_success(id, seat, target, input)
	for mode in ["energy", "torn", "target_torn", "tangled", "target_tangled", "no_targets", "owner", "duplicate_owner", "status", "status_type", "overflow", "hand", "inactive", "closed", "session", "turn", "label", "panel", "battle", "deck"]:
		for phase in [0, 1, 2]:
			await _roll_refuse(mode, phase)
	for mode in ["identity", "same_id", "owner_ref", "seat", "escape", "cancel"]:
		for phase in [1, 2]:
			await _roll_refuse(mode, phase)
	await _one_target()
	await _unknown_roll()
	await _roll_success(ROLL_IDS[3], 1, 3, 3)
	var replay := _last_result.duplicate(true)
	await _roll_success(ROLL_IDS[3], 1, 3, 3)
	_check(_last_result == replay, "complete seeded sequence replay")
	for failure in failures:
		printerr(failure)
	print("live_button_golem_roll_hand_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
