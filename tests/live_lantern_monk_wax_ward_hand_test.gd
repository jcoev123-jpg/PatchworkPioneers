extends "res://tests/live_lantern_monk_pole_shelter_hand_test.gd"
## Mounted scenes/app.tscn regression for paid self-only Wax Ward in the drawn hand.
const WAX := "lantern_monk_wax_ward"
const WAX_PLUS := "lantern_monk_wax_ward_plus"


class TrackedWaxService extends CombatLanternMonkWaxWardCards:
	var targets: Array[int] = []

	func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant,
			target_position: int = 0) -> Dictionary:
		targets.append(target_position)
		return super.play_card(deck, party, card_id, target_position)


func _with_spy() -> TrackedWaxService:
	var spy := TrackedWaxService.new()
	presenter._wax_service = spy
	return spy


func _full_state() -> Array:
	return [_state(), app.deck.combat_state.energy, app.deck.combat_state.player_turn_active,
		app.battle_result.get_outcome(), app._battle_closed, app.run_map,
		app.run_scraps, app.encounter_id, app.party_carryover, app.round_flow,
		app.enemy_intents._turn_index, app.battle_view.visible, app.hand_view.visible]


func _displayed(id: String, seat: int) -> void:
	_check(app.pile_label.text == "Draw: %d | Discard: %d" % [
		app.deck.draw_pile.size(), app.deck.discard_pile.size()], "real piles update")
	_check(app.get_node("LiveSupportHand").energy_label.text == str(app.deck.energy),
		"real sewn energy meter updates")
	var label: Label = app.hero_panels[seat - 1].get_child(0)
	_check(label.text.contains("Block: %d" % app.party.get_hero(seat).block),
		"current Monk seat's visible Block updates")
	_check(_pool_panel(id) == null or _pool_panel(id).get_child(0).text == id,
		"surviving source still retains authentic full card ID")


func _activation(id: String, seat: int, keyboard: bool) -> void:
	var panel: Control = await _begin(id, seat)
	if panel == null:
		await _dispose()
		return
	_check(app.party.gain_block(seat, 3), "Monk begins with nonzero additive Block")
	app._refresh_party()
	app._refresh_hand()
	await _frames()
	panel = _pool_panel(id)
	_check(panel != null and presenter._bindings.has(panel), "updated hand remains authentically mounted")
	var spy := _with_spy()
	_check(app.get_node("LiveLanternMonkPoleShelterHand") == presenter,
		"uses actual scene-mounted child, not a helper")
	_check(app.deck.hand.count(id) == 2 and app.party.get_hero(seat).id == "lantern_monk"
		and app.deck.energy == 4, "drawn two authentic held copies at current living Monk seat")
	_check(panel.get_child(0).text == id and panel.gui_input.get_connections().size() == 1
		and panel.focus_mode == Control.FOCUS_ALL, "one effective source-card listener")
	presenter._sync_battle()
	_check(panel.gui_input.get_connections().size() == 1, "sync cannot double-subscribe")
	var block := 7 if id == WAX_PLUS else 5
	var title := "Wax Ward+" if id == WAX_PLUS else "Wax Ward"
	_check(panel.tooltip_text.contains(title) and panel.tooltip_text.contains("Cost 1")
		and panel.tooltip_text.contains("Block %d" % block)
		and panel.tooltip_text.contains("self"), "readable, self-only mounted tooltip")
	_check(CombatLanternMonkWaxWardCards.new()._prepare(app.deck, app.party, id, 0).ok,
		"genuine paid preflight uses self sentinel")
	var before_target := _full_state()
	for illegal_seat in [1, 2, 3, -1]:
		_check(not CombatLanternMonkWaxWardCards.new().play_card(
			app.deck, app.party, id, illegal_seat).ok,
			"even current seat cannot be explicit self target %d" % illegal_seat)
	_check(_full_state() == before_target, "invalid nonzero target leaves full live state and RNG intact")
	var callback: Callable = presenter._bindings[panel].callback
	var before := _full_state()
	if keyboard:
		panel.grab_focus()
		_check(panel.has_focus(), "held panel genuinely keyboard-focused")
		await _keyboard(KEY_SPACE if id == WAX_PLUS else KEY_ENTER)
	else:
		await _mouse(panel)
	var expected := before.duplicate(true)
	expected[0][0][1].erase(id)
	expected[0][0][2].append(id)
	expected[0][0][3] -= 1
	expected[0][0][5][seat - 1].block += block
	expected[1] -= 1
	_check(_full_state() == expected,
		"single play spends exactly 1 energy, discards 1 and adds only Monk Block %d" % block)
	_check(spy.targets == [0], "paid resolver called once with implicit self target zero")
	_check(presenter._pending.is_empty() and not is_instance_valid(presenter.choice_panel),
		"no ally, enemy or debuff chooser ever mounted")
	_displayed(id, seat)
	var after := _full_state()
	callback.call(_press())
	callback.call(_key(KEY_ENTER))
	callback.call(_key(KEY_SPACE, true, true))
	await _frames()
	_check(_full_state() == after and spy.targets == [0],
		"duplicate activation and stale input callback cannot replay paid copy")
	var second: Control = _pool_panel(id)
	_check(second != null and second != panel and presenter._bindings.has(second)
		and second.gui_input.get_connections().size() == 1,
		"independent second authentic copy rebound exactly once")
	if second != null:
		second.grab_focus()
		await _keyboard(KEY_ENTER if keyboard else KEY_SPACE)
		_check(spy.targets == [0, 0] and app.deck.energy == 2
			and app.deck.hand.count(id) == 0 and app.deck.discard_pile.count(id) == 2
			and app.party.get_hero(seat).block == 3 + block * 2,
			"second genuine held copy independently pays once and stacks its Block")
		_displayed(id, seat)
	await _dispose()


func _refusal(mode: String, keyboard: bool) -> void:
	var panel: Control = await _begin(WAX, 2, 1)
	if panel == null:
		await _dispose()
		return
	var spy := _with_spy()
	var callback: Callable = presenter._bindings[panel].callback
	match mode:
		"missing": app.party._heroes[1].id = "another"
		"downed": app.party.apply_damage(2, 999)
		"not_held": _check(app.deck.discard_played(WAX), "not-held source actually removed")
		"energy": app.deck.combat_state.energy = 0
		"inactive": app.deck.combat_state.player_turn_active = false
		"closed": app._battle_closed = true
		"terminal": app.battle_result._outcome = CombatBattleResult.DEFEAT
		"forged_label": panel.get_child(0).text = "lantern_monk_wax_ward_plus"
		"forged_hand": app.deck.hand[panel.get_index()] = "fake_wax_ward"
		"redraw": app._refresh_hand()
		"turn": app.enemy_intents.advance_turn()
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"enemies": app.enemies = CombatEnemies.new([{"id": "other", "max_hp": 12}])
		"context": app.party.gain_block(1, 2)
		"hidden": app.battle_view.hide()
	var before := _full_state()
	# The original listener is intentionally retained even if a redraw freed its panel.
	callback.call(_press())
	callback.call(_key(KEY_ENTER))
	callback.call(_key(KEY_SPACE, true, true))
	_check(_full_state() == before and spy.targets.is_empty(),
		"invalid %s never calls resolver, pays, affects actors or consumes RNG" % mode)
	if mode != "redraw":
		if keyboard and panel.is_visible_in_tree() and panel.focus_mode == Control.FOCUS_ALL:
			panel.grab_focus()
			root.push_input(_key(KEY_ENTER, true, true), true)
			root.push_input(_key(KEY_ENTER, false), true)
		elif panel.is_visible_in_tree():
			root.push_input(_press(), true)
		_check(_full_state() == before and spy.targets.is_empty(),
			"invalid %s live viewport input cannot pay" % mode)
	_check(presenter._pending.is_empty() and not is_instance_valid(presenter.choice_panel),
		"refused Wax Ward never leaves a target popup")
	await _dispose()


func _echo_and_interference() -> void:
	var panel: Control = await _begin(WAX_PLUS, 3, 1)
	if panel == null:
		await _dispose()
		return
	var spy := _with_spy()
	var before := _full_state()
	panel.grab_focus()
	root.push_input(_key(KEY_SPACE, true, true), true)
	root.push_input(_key(KEY_ENTER, false), true)
	await _frames()
	_check(_full_state() == before and spy.targets.is_empty(),
		"echo and release cannot activate a held card")
	# A Pole Shelter choice already open must not be displaced by a self-card.
	var pole_id := "lantern_monk_pole_shelter"
	app.deck.hand[0] = pole_id
	app._refresh_hand()
	await _frames()
	var pole: Control = _pool_panel(pole_id)
	_check(pole != null and presenter._bindings.has(pole), "Pole Shelter coexists in live shared hand")
	if pole != null:
		await _mouse(pole)
		_check(not presenter._pending.is_empty(), "genuine Pole chooser opens")
		var pending: Dictionary = presenter._pending.duplicate(true)
		var wax: Control = _pool_panel(WAX_PLUS)
		_check(wax != null, "Wax Ward still held while Pole chooser active")
		if wax != null:
			presenter._bindings[wax].callback.call(_press())
		_check(presenter._pending == pending and spy.targets.is_empty(),
			"pending Pole Shelter blocks Wax Ward, preserving pending target")
		presenter._cancel()
		_check(presenter._pending.is_empty(), "Pole Shelter cancel still closes")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id in [WAX, WAX_PLUS]:
		for seat in [1, 2, 3]:
			await _activation(id, seat, seat % 2 == 0)
	await _echo_and_interference()
	for mode in ["missing", "downed", "not_held", "energy", "inactive",
			"closed", "terminal", "forged_label", "forged_hand", "redraw",
			"turn", "session", "enemies", "context", "hidden"]:
		await _refusal(mode, mode == "energy" or mode == "turn")
	_finish()
