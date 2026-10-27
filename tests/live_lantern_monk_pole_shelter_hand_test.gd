extends "res://tests/live_support_hand_test.gd"
## Drives real cards and the independent mounted, keyboard-accessible choice panel.
const BASE := "lantern_monk_pole_shelter"
const PLUS := "lantern_monk_pole_shelter_plus"


func _begin(id: String, seat: int = 2, count: int = 2) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 307
	_check(app._start_battle(), "actual seeded standalone battle admitted")
	presenter = app.get_node("LiveLanternMonkPoleShelterHand")
	_check(presenter != null and app.get_node("LiveSupportHand") != null,
		"separate Pole Shelter presenter scene-mounted alongside support hand")
	var rng := RandomNumberGenerator.new()
	rng.seed = 307
	var cards: Array[String] = [id, "warden_strike", "warden_brace", "tinker_tune_up", id]
	if count == 1:
		cards[4] = "seamstress_prick"
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.count(id) == count, "exact authentic drawn copies")
	app.deck.combat_state.energy = 4
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 25}]
	heroes.insert(seat - 1, {"id": "lantern_monk", "name": "Lantern Monk", "max_hp": 30})
	app.party = CombatParty.new(heroes)
	_check(app.party.is_valid() and app.enemies.is_valid() and app.deck.turn_active,
		"live valid actor rosters and held active turn")
	for position in range(1, 4):
		app.party._heroes[position - 1].statuses = {
			"bleed": position + 1, "weak": position, "exposed": 3,
			"tangled": 2, "riposte": 1}
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies,
		app.enemy_intents, app.battle_result)
	app._refresh_party()
	app._refresh_hand()
	await _frames()
	var panel := _pool_panel(id)
	_check(panel != null and panel is PanelContainer and panel.is_visible_in_tree()
		and presenter._bindings.has(panel), "authentic card PanelContainer bound through scene")
	return panel


func _dispose() -> void:
	app.free()
	await _frames()


func _state() -> Array:
	return [_pool_state(), app.run_rng.state, app.run_rng.seed, app.run_scraps,
		app.run_deck.duplicate(), app.session_gold]


func _open_card(panel: Control, keyboard: bool) -> void:
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(panel)
	_check(not presenter._pending.is_empty() and is_instance_valid(presenter.choice_panel),
		"rendered held card input opens read-only chooser")
	_check(is_instance_valid(presenter.ally_row) and presenter.ally_row.get_child_count() == 3,
		"three visible ally positions, no invented target")


func _target(position: int, keyboard: bool) -> void:
	var button: Button = presenter.ally_row.get_node("Ally%d" % position)
	_check(not button.disabled and button.is_visible_in_tree(), "living target selectable")
	if keyboard:
		button.grab_focus()
		await _keyboard(KEY_SPACE)
	else:
		await _mouse(button)


func _debuff(kind: String, keyboard: bool) -> void:
	var button: Button = presenter.debuff_row.get_node(kind.capitalize())
	_check(button.is_visible_in_tree() and not button.disabled, "explicit present debuff button")
	if keyboard:
		button.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(button)


func _success(id: String, seat: int, target: int, kind: String, keyboard: bool) -> Array:
	var panel := await _begin(id, seat)
	if panel == null:
		await _dispose()
		return []
	var other_panel: Control = null
	for child in app.hand_view.get_children():
		if child != panel and child.get_child(0).text == id:
			other_panel = child
	_check(other_panel != null and presenter._bindings.has(other_panel), "independent second copy bound")
	var callback: Callable = presenter._bindings[panel].callback
	var before := _state()
	await _open_card(panel, keyboard)
	_check(_state() == before, "opening forecast never alters paid state, seed or RNG")
	var block := 7 if id == PLUS else 5
	var title := "Pole Shelter+" if id == PLUS else "Pole Shelter"
	_check(presenter.caption.text.contains(title) and presenter.caption.text.contains("Cost 1")
		and presenter.caption.text.contains("Block %d" % block),
		"authentic printed cost and Block shown on mounted chooser")
	for position in range(1, 4):
		_check(not presenter.ally_row.get_node("Ally%d" % position).disabled,
			"living party seat shown available %d" % position)
	await _target(target, keyboard)
	if kind != "":
		_check(_state() == before, "no payment before explicit cleanse selection")
		_check(presenter.debuff_row.get_child_count() == 3, "only all three present debuffs offered")
		var statuses: Dictionary = app.party.get_hero(target).statuses
		for debuff in ["bleed", "weak", "exposed"]:
			var b: Button = presenter.debuff_row.get_node(debuff.capitalize())
			_check(b.text.contains("%d" % statuses[debuff]) and b.text.contains(debuff.capitalize()),
				"choice names actual debuff stack and kind")
		await _debuff(kind, not keyboard)
	var expected := before.duplicate(true)
	expected[0][1].erase(id)
	expected[0][2].append(id)
	expected[0][3] -= 1
	expected[0][5][target - 1].block += block
	if kind != "":
		expected[0][5][target - 1].statuses.erase(kind)
	_check(_state() == expected, "single paid card exactly Block %d and only chosen status erased" % block)
	_check(presenter._pending.is_empty() and not is_instance_valid(presenter.choice_panel)
		and app.end_turn_button.has_focus(), "one-shot chooser retired, focus restored to battle action")
	_check(app.pile_label.text.contains("Discard: %d" % app.deck.discard_pile.size())
		and app.get_node("LiveSupportHand").energy_label.text == str(app.deck.energy),
		"real draw/discard and energy displays updated")
	var label: Label = app.hero_panels[target - 1].get_child(0)
	_check(label.text.contains("Block: %d" % app.party.get_hero(target).block),
		"real ally Block label refreshed")
	var unchanged := _state()
	callback.call(_press())
	presenter._choose_ally(target, presenter._epoch - 1)
	presenter._choose_debuff(kind, target, presenter._epoch - 1)
	await _frames()
	_check(_state() == unchanged and app.deck.hand.count(id) == 1,
		"retired card and stale chooser callbacks cannot replay charge")
	var remaining := _pool_panel(id)
	_check(remaining != null and remaining != panel and presenter._bindings.has(remaining),
		"second surviving authentic drawn copy rebound")
	if remaining != null:
		await _open_card(remaining, true)
		await _target(target, true)
		if kind != "":
			await _debuff("exposed" if kind != "exposed" else "weak", true)
		_check(app.deck.hand.count(id) == 0 and app.deck.energy == before[0][3] - 2,
			"independent second held copy pays exactly once")
	var after := _state()
	await _dispose()
	return after


func _negative(mode: String, queued: bool) -> void:
	var panel := await _begin(BASE, 2, 1)
	if panel == null:
		await _dispose()
		return
	var callback: Callable = presenter._bindings[panel].callback
	if queued:
		await _open_card(panel, false)
	var token: int = presenter._epoch
	match mode:
		"missing": app.party._heroes[1].id = "missing_monk"
		"down_owner": app.party.apply_damage(2, 999)
		"down_target": app.party.apply_damage(1, 999)
		"energy": app.deck.combat_state.energy = 0
		"hand": app.deck.discard_played(BASE)
		"turn": app.enemy_intents.advance_turn()
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"result": app.battle_result._outcome = CombatBattleResult.DEFEAT
		"enemies": app.enemies = CombatEnemies.new([{"id": "replacement", "max_hp": 12}])
		"redraw": app._refresh_hand()
		"label": panel.get_child(0).text = PLUS
		"forged": app.deck.hand[panel.get_index()] = "forged_pole"
		"inactive": app.deck.combat_state.player_turn_active = false
		"offered": app.party._heroes[0].statuses.erase("weak")
		"party": app.party._heroes[0].statuses["exposed"] = 8
		"closed": app._battle_closed = true
		"cancel": presenter._cancel()
	if mode == "down_target" and queued:
		_check(app.party.is_downed(1), "queued recipient really downed")
	if mode == "down_target" and not queued:
		await _open_card(panel, false)
		app.party.apply_damage(1, 999)
	if mode in ["turn", "enemies"]:
		app._refresh_intents()
	var before := _state()
	if queued:
		presenter._choose_ally(1, token)
		presenter._choose_debuff("weak", 1, token)
		presenter._commit(1, "weak", token)
	else:
		callback.call(_press())
	_check(_state() == before, "invalid %s immediate callback is no-spend" % mode)
	await _frames()
	var after := _state()
	# An externally forced terminal result legitimately ends the turn through the
	# app observer, independently of this presenter. Never count that as a play.
	if mode == "result":
		var terminal_discard: Array = before[0][2].duplicate()
		terminal_discard.append_array(before[0][1])
		_check(app._battle_closed and not app.deck.turn_active and app.deck.energy == 0
			and app.deck.hand.is_empty() and app.deck.discard_pile == terminal_discard
			and app.party.get_heroes() == before[0][5]
			and app.run_rng.state == before[1] and app.session_gold == before[0][13],
			"terminal observer closes turn (energy resets normally), no Pole payment")
	else:
		_check(after == before, "stale %s queued=%s keeps full state" % [mode, str(queued)])
	_check(presenter._pending.is_empty(), "invalid/stale chooser retired: %s" % mode)
	await _dispose()


func _down_and_empty() -> void:
	var panel := await _begin(PLUS, 1, 1)
	_check(app.party.apply_damage(3, 999) and app.party.is_downed(3), "third recipient truly downed")
	app.party._heroes[1].statuses = {"tangled": 3, "riposte": 2}
	await _open_card(panel, false)
	_check(presenter.ally_row.get_node("Ally3").disabled and not presenter.ally_row.get_node("Ally2").disabled,
		"downed recipient visibly disabled; other living target enabled")
	var before := _state()
	await _target(2, true)
	var expected := before.duplicate(true)
	expected[0][1].erase(PLUS)
	expected[0][2].append(PLUS)
	expected[0][3] -= 1
	expected[0][5][1].block += 7
	_check(_state() == expected and app.party.get_hero(2).statuses == {"tangled": 3, "riposte": 2},
		"zero eligible kinds commit without invented removal; Tangled and Riposte persist")
	await _dispose()


func _cancel_case() -> void:
	var panel := await _begin(BASE, 3, 1)
	await _open_card(panel, true)
	await _target(1, false)
	var before := _state()
	var stale: int = presenter._epoch
	await _keyboard(KEY_ESCAPE)
	_check(_state() == before and presenter._pending.is_empty() and app.end_turn_button.has_focus(),
		"Escape cancels without paying and restores action focus")
	presenter._choose_debuff("bleed", 1, stale)
	_check(_state() == before, "cancelled cleanse callback inert")
	await _open_card(panel, false)
	presenter.cancel_button.pressed.emit()
	_check(_state() == before and presenter._pending.is_empty(), "visible Cancel button also inert")
	await _dispose()



func _single_choice() -> void:
	var panel := await _begin(BASE, 2, 1)
	_check(panel != null, "single-kind case has real held source")
	app.party._heroes[0].statuses = {"weak": 4, "tangled": 2, "riposte": 1}
	var before := _state()
	await _open_card(panel, true)
	await _target(1, false)
	_check(presenter.debuff_row.get_child_count() == 1
		and presenter.debuff_row.get_child(0).text == "Remove Weak (4)"
		and _state() == before, "exactly one explicit present-kind button, no prepayment")
	await _debuff("weak", true)
	var expected := before.duplicate(true)
	expected[0][1].erase(BASE)
	expected[0][2].append(BASE)
	expected[0][3] -= 1
	expected[0][5][0].block += 5
	expected[0][5][0].statuses.erase("weak")
	_check(_state() == expected and app.party.get_hero(1).statuses == {"tangled": 2, "riposte": 1},
		"single available Weak removes all four stacks, preserves excluded statuses")
	await _dispose()


func _changed_after_target() -> void:
	var panel := await _begin(PLUS, 3, 1)
	await _open_card(panel, true)
	await _target(1, true)
	_check(presenter.debuff_row.get_child_count() == 3, "multiple explicit choices appeared")
	var token: int = presenter._epoch
	app.party._heroes[0].statuses["weak"] = 9
	var before := _state()
	presenter._choose_debuff("weak", 1, token)
	await _frames()
	_check(_state() == before and presenter._pending.is_empty()
		and app.deck.hand.has(PLUS) and app.deck.energy == 4,
		"changed offered status after targeting rejects late confirmation without payment")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id in [BASE, PLUS]:
		for seat in [1, 2, 3]:
			await _success(id, seat, 1 + (seat % 3), "weak", seat == 2)
	await _down_and_empty()
	await _single_choice()
	await _changed_after_target()
	await _cancel_case()
	for mode in ["missing", "down_owner", "energy", "hand", "session",
			"result", "enemies", "redraw", "label", "forged", "inactive", "closed"]:
		for queued in [false, true]:
			await _negative(mode, queued)
	# These changes invalidate an already selected card; a new card may legally be
	# opened again against the new status or party, so test only stale receipts.
	for mode in ["offered", "party", "down_target", "turn", "cancel"]:
		await _negative(mode, true)
	_finish()
