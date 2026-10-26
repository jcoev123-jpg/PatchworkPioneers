extends "res://tests/live_button_golem_pop_hand_test.gd"

const SEW_IDS := ["button_golem_starter_seam_resew", "button_golem_starter_seam_resew_plus",
	"button_golem_sew_on", "button_golem_sew_on_plus"]


func _sew_success(id: String, seat: int, input: int, count: int) -> void:
	var panel := await _begin(id, seat)
	if panel == null:
		await _dispose()
		return
	app.party._heroes[seat - 1].buttons_popped = count
	var meta = presenter._metadata
	var definition: Dictionary = ButtonGolemStarterCards.new().get_definition(id) if id.begins_with("button_golem_starter") else ButtonGolemPoolCards.new().get_definition(id)
	var facts: Dictionary = meta.get_facts(panel)
	_check(not definition.is_empty() and meta.definition(id) == definition, "authentic distinct Sew catalog")
	_check(facts.known and facts.owner_text == "Button Golem" and facts.cost == 1
		and facts.from_text == "From " + meta._positions([1, 2, 3]) and facts.target_text == "Self"
		and meta.visual_state(panel).playable and panel.focus_mode == Control.FOCUS_ALL,
		"mounted owner, energy, legal positions, self and enabled keyboard")
	var multiplier: int = 2 if id == SEW_IDS[3] else 1
	var flat: int = 2 if id == SEW_IDS[1] else 0
	var line := "Gain %d Block per button popped%s; self only." % [multiplier, " + 2 Block" if flat else ""]
	_check(meta.short_line(id) == line and panel.tooltip_text.contains(line)
		and panel.tooltip_text.contains("1 energy") and panel.tooltip_text.contains("To self"), "exact authored multiplier and flat Block printed")
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
	var result := CombatButtonGolemSewCards.new().play_card(oracle, party, id, 0)
	_check(result.ok and result.block_gained == count * multiplier + flat, "independent paid resolver oracle")
	var enemies: Array = app.enemies.get_enemies()
	var rng_state: int = app.run_rng.state
	var callback: Callable = presenter._bindings[panel]
	if input == 0:
		await _mouse(panel)
	else:
		panel.grab_focus()
		await _keyboard(KEY_ENTER if input == 1 else KEY_SPACE)
	_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(oracle, party, rng)
		and app.enemies.get_enemies() == enemies and app.run_rng.state == rng_state,
		"exact mounted state equals resolver; enemies and RNG unchanged")
	_check(app.deck.hand.count(id) == 1 and app.deck.discard_pile.count(id) == 1
		and app.party.get_hero(seat).block == 10 + count * multiplier + flat
		and app.party.get_hero(seat).buttons_popped == count, "exactly one paid held copy, Golem Block, counter retained")
	_check(app.hero_panels[seat - 1].get_child(0).text.contains("Block: %d" % (10 + count * multiplier + flat))
		and presenter.energy_label.text == str(app.deck.energy)
		and app.hand_view.get_child_count() == app.deck.hand.size(), "Block energy and hand HUD refresh")
	_check(presenter._pending.is_empty() and presenter._targets.is_empty() and not presenter.cancel_button.visible,
		"no target picker")
	var after := _pool_state()
	callback.call(_press())
	await _frames()
	_check(_pool_state() == after, "retired callback cannot spend duplicate held copy")
	_last_result = after.duplicate(true)
	await _dispose()


func _sew_refuse(mode: String, queued: bool) -> void:
	var panel := await _begin(SEW_IDS[1])
	if panel == null:
		await _dispose()
		return
	_check(presenter._metadata.visual_state(panel).playable, "valid before rejection fixture")
	var callback: Callable = presenter._bindings[panel]
	if queued:
		panel.grab_focus()
		callback.call(_key(KEY_ENTER))
		_check(not presenter._pending.is_empty(), "real deferred input armed")
	var token: int = presenter._token
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"counter": app.party._heroes[1].buttons_popped = -1
		"counter_type": app.party._heroes[1].buttons_popped = 1.5
		"overflow": app.party._heroes[1].block = CombatParty.MAX_INT
		"torn": app.party.apply_damage(2, 999)
		"owner": app.party._heroes[1].id = "seamstress"
		"duplicate_owner": app.party._heroes[0].id = "button_golem"
		"inactive": app.deck.combat_state.player_turn_active = false
		"closed": app._battle_closed = true
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"turn": app.enemy_intents.advance_turn()
		"hand":
			app.deck.discard_played(SEW_IDS[1])
			app.deck.discard_played(SEW_IDS[1])
		"panel": app._refresh_hand()
		"label": panel.get_child(0).text = SEW_IDS[0]
		"battle":
			app.battle_view = app.battle_view.duplicate(0)
			app.add_child(app.battle_view)
		"seat":
			var hero: Dictionary = app.party._heroes[1]
			app.party._heroes[1] = app.party._heroes[0]
			app.party._heroes[0] = hero
			app.party._heroes[0].position = 1
			app.party._heroes[1].position = 2
			_check(app.party.is_valid(), "otherwise legal moved owner")
		"cancel": presenter._cancel_pending()
	app._refresh_intents()
	if not queued and mode not in ["panel", "battle"]:
		presenter._metadata._update_visual(panel)
		_check(not presenter._metadata.visual_state(panel).playable, "invalid card dims: " + mode)
	var before := _pool_state()
	if mode == "cancel":
		presenter._activate(panel, SEW_IDS[1], app.deck, app.party, app.battle_view, token)
	else:
		callback.call(_key(KEY_ENTER))
	await _frames()
	_check(_pool_state() == before and presenter._pending.is_empty(), "no-spend rejected " + mode)
	if mode == "cancel":
		presenter._activate(panel, SEW_IDS[1], app.deck, app.party, app.battle_view, token)
	else:
		callback.call(_press())
	await _frames()
	_check(_pool_state() == before, "rejected replay inert " + mode)
	await _dispose()


func _pop_then_sew() -> void:
	var panel := await _begin(IDS[0])
	_check(panel != null, "real Pop panel")
	app.deck.hand[app.deck.hand.find(IDS[0])] = SEW_IDS[3]
	app._refresh_hand()
	await _frames()
	panel = _pool_panel(IDS[0])
	await _arm_pop(panel, false)
	await _keyboard(KEY_1)
	_check(app.party.get_hero(2).buttons_popped == 8 and app.party.get_hero(2).block == 5, "live Pop writes counter")
	var state: int = app.run_rng.state
	var energy: int = app.deck.energy
	await _mouse(_pool_panel(SEW_IDS[3]))
	_check(app.party.get_hero(2).block == 21 and app.party.get_hero(2).buttons_popped == 8
		and app.deck.energy == energy - 1 and app.run_rng.state == state, "live Sew reads Pop counter for 16 own Block")
	await _dispose()


func _unknown() -> void:
	await _begin(SEW_IDS[0])
	var id := "button_golem_sew_on_plus_plus"
	app.deck.hand[0] = id
	app._refresh_hand()
	await _frames()
	var panel := _pool_panel(id)
	_check(panel != null and not presenter._bindings.has(panel), "unknown alias has no action binding")
	if panel != null:
		_check(not presenter._metadata.get_facts(panel).known
			and not presenter._metadata.visual_state(panel).playable, "unknown alias stays unknown and dim")
		var before := _pool_state()
		await _mouse(panel)
		_check(panel.focus_mode == Control.FOCUS_NONE, "unknown alias cannot enter keyboard focus")
		await _keyboard(KEY_ENTER)
		await _keyboard(KEY_SPACE)
		_check(_pool_state() == before, "unknown alias mouse and keys cannot spend")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id in SEW_IDS:
		for seat in [1, 2, 3]:
			for input in [0, 1, 2]:
				for count in [0, 7]:
					await _sew_success(id, seat, input, count)
	await _pop_then_sew()
	await _unknown()
	for mode in ["energy", "counter", "counter_type", "overflow", "torn", "owner", "duplicate_owner", "inactive", "closed", "session", "turn", "hand", "panel", "label", "battle"]:
		for queued in [false, true]:
			await _sew_refuse(mode, queued)
	for mode in ["seat", "cancel"]:
		await _sew_refuse(mode, true)
	await _sew_success(SEW_IDS[3], 3, 2, 7)
	var replay := _last_result.duplicate(true)
	await _sew_success(SEW_IDS[3], 3, 2, 7)
	_check(_last_result == replay, "complete seeded replay")
	for failure in failures:
		printerr(failure)
	print("live_button_golem_sew_hand_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
