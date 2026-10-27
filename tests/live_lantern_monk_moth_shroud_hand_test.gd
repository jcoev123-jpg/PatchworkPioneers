extends "res://tests/live_lantern_monk_wax_ward_hand_test.gd"
## Real shared-hand and mounted chooser coverage, reusing the seeded battle fixture.
const SHROUD := "lantern_monk_moth_shroud"
const SHROUD_PLUS := "lantern_monk_moth_shroud_plus"


class TrackedShroudService extends CombatLanternMonkShroudCards:
	var targets: Array[int] = []

	func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant,
			target_position: int = 0) -> Dictionary:
		targets.append(target_position)
		return super.play_card(deck, party, card_id, target_position)


func _shroud_success(id: String, seat: int, target: int, keyboard: bool, armed: bool) -> Array:
	var panel: Control = await _begin(id, seat)
	if panel == null:
		await _dispose()
		return []
	_check(app.party.gain_block(target, 3), "nonzero additive Block prerequisite")
	if armed:
		app.party._heroes[target - 1].statuses["dodge_next_attack"] = 1
	app._refresh_party()
	app._refresh_hand()
	await _frames()
	panel = _pool_panel(id)
	var spy := TrackedShroudService.new()
	presenter._shroud_service = spy
	_check(panel != null and presenter._bindings.has(panel)
		and app.deck.hand.count(id) == 2 and app.party.get_hero(seat).id == "lantern_monk",
		"two genuinely held copies and living Monk in authored seat")
	_check(app.enemies.is_valid() and not app.enemies.is_slain(1), "real attack source alive")
	var block := 8 if id == SHROUD_PLUS else 6
	var title := "Moth Shroud+" if id == SHROUD_PLUS else "Moth Shroud"
	_check(panel.tooltip_text.contains(title) and panel.tooltip_text.contains("Cost 1")
		and panel.tooltip_text.contains("Block %d" % block) and panel.tooltip_text.contains("Dodge"),
		"authentic tooltip identifies cost, Block and Dodge")
	presenter._sync_battle()
	presenter._sync_battle()
	_check(panel.gui_input.get_connections().size() == 1, "one effective input callback after repeated sync")
	var callback: Callable = presenter._bindings[panel].callback
	for copy in range(2):
		var before := _full_state()
		await _open_card(panel, keyboard if copy == 0 else not keyboard)
		if presenter._pending.is_empty():
			_check(false, "held Shroud must open before target assertions")
			await _dispose()
			return []
		_check(_full_state() == before, "opening chooser is entirely read-only")
		var chooser_count := 0
		for child in app.get_children():
			if child.name == "PoleShelterChoices":
				chooser_count += 1
		_check(chooser_count == 1 and presenter.caption.text.contains(title)
			and presenter.caption.text.contains("Cost 1")
			and presenter.caption.text.contains("Block %d" % block)
			and presenter.caption.text.contains("Dodge"), "exactly one mounted authored chooser")
		for position in range(1, 4):
			_check(not presenter.ally_row.get_node("Ally%d" % position).disabled,
				"every living ally including Monk self is selectable")
		_check(presenter.debuff_row.get_child_count() == 0, "Shroud never offers a cleanse")
		var epoch: int = presenter._epoch
		await _target(target, not keyboard if copy == 0 else keyboard)
		var expected := before.duplicate(true)
		expected[0][0][1].erase(id)
		expected[0][0][2].append(id)
		expected[0][0][3] -= 1
		expected[0][0][5][target - 1].block += block
		expected[0][0][5][target - 1].statuses.dodge_next_attack = 1
		expected[1] -= 1
		_check(_full_state() == expected,
			"exact payment, printed Block and one armed Dodge; all debuffs, other actors and RNG unchanged")
		_check(spy.targets.size() == copy + 1 and spy.targets[copy] == target,
			"one authoritative paid resolver call per selected held copy")
		_check(presenter._pending.is_empty() and not is_instance_valid(presenter.choice_panel),
			"chooser retired immediately on ally confirmation, no debuff step")
		_displayed(id, target)
		var after := _full_state()
		callback.call(_press())
		presenter._choose_ally(target, epoch)
		presenter._commit_shroud(target, epoch)
		_check(_full_state() == after and spy.targets.size() == copy + 1,
			"duplicate source and confirmation callbacks cannot spend surviving copy")
		if copy == 0:
			panel = _pool_panel(id)
			_check(panel != null and presenter._bindings.has(panel), "surviving held copy rebound")
			callback = presenter._bindings[panel].callback
			if not armed:
				_dodge_attack(target)
				# Real attack changed the source snapshot: only a fresh rendered hand may activate.
				app._refresh_hand()
				await _frames()
				panel = _pool_panel(id)
				callback = presenter._bindings[panel].callback
	_dodge_attack(target)
	var result := _state()
	await _dispose()
	return result


func _dodge_attack(target: int) -> void:
	var before := _full_state()
	_check(app.party.get_hero(target).statuses.get("dodge_next_attack") == 1,
		"Dodge genuinely armed before enemy attack")
	var reactions := CombatWardenGuardReactions.new()
	var attack := {"type": "attack", "enemy_position": 1, "target_position": target, "amount": 99}
	var receipt := reactions.resolve_enemy_attack(app.party, app.enemies, attack)
	var expected := before.duplicate(true)
	expected[0][0][5][target - 1].statuses.erase("dodge_next_attack")
	_check(receipt.ok and not receipt.applied and _full_state() == expected,
		"established enemy attack consumes only Dodge, preserving HP, Block, other statuses and RNG")
	var hp: int = app.party.get_hero(target).hp
	var second := reactions.resolve_enemy_attack(app.party, app.enemies,
		{"enemy_position": 1, "target_position": target, "amount": 1})
	_check(second.ok and second.applied and app.party.get_hero(target).block ==
		int(expected[0][0][5][target - 1].block) - 1 and app.party.get_hero(target).hp == hp,
		"following attack really lands against Block: Dodge is one-shot")


func _shroud_refusal(mode: String, queued: bool) -> void:
	var panel: Control = await _begin(SHROUD, 2, 1)
	if panel == null:
		await _dispose()
		return
	var spy := TrackedShroudService.new()
	presenter._shroud_service = spy
	var callback: Callable = presenter._bindings[panel].callback
	if queued:
		await _open_card(panel, true)
	var epoch: int = presenter._epoch
	match mode:
		"wrong_seat":
			var monk: Dictionary = app.party._heroes[1]
			app.party._heroes[1] = app.party._heroes[0]
			app.party._heroes[0] = monk
			app.party._heroes[0].position = 1
			app.party._heroes[1].position = 2
		"missing": app.party._heroes[1].id = "missing_monk"
		"owner_dead": app.party.apply_damage(2, 999)
		"target_dead": app.party.apply_damage(1, 999)
		"illegal_target": pass
		"energy": app.deck.combat_state.energy = 0
		"not_held": _check(app.deck.discard_played(SHROUD), "source really discarded")
		"redraw": app._refresh_hand()
		"hand": app.deck.hand.reverse()
		"turn": app.enemy_intents.advance_turn()
		"inactive": app.deck.combat_state.player_turn_active = false
		"closed": app._battle_closed = true
		"battle": app.enemies = CombatEnemies.new([{"id": "other", "max_hp": 12}])
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"label": panel.get_child(0).text = SHROUD_PLUS
		"forged": app.deck.hand[panel.get_index()] = "forged_moth_shroud"
		"context": app.party.gain_block(3, 1)
		"cancel": presenter._cancel()
		"hidden": app.battle_view.hide()
	var before := _full_state()
	if queued:
		presenter._choose_ally(4 if mode == "illegal_target" else 1, epoch)
		presenter._commit_shroud(1, epoch)
	else:
		callback.call(_press())
		callback.call(_key(KEY_ENTER))
	_check(_full_state() == before and spy.targets.is_empty(),
		"%s queued=%s: full state and RNG unchanged, no paid call" % [mode, queued])
	_check(presenter._pending.is_empty(), "refused stale chooser retired")
	await _dispose()


func _cancel_and_dead() -> void:
	var panel: Control = await _begin(SHROUD_PLUS, 3)
	_check(app.party.apply_damage(1, 999) and app.party.is_downed(1), "recipient genuinely dead")
	app._refresh_hand()
	await _frames()
	panel = _pool_panel(SHROUD_PLUS)
	await _open_card(panel, false)
	_check(presenter.ally_row.get_node("Ally1").disabled
		and not presenter.ally_row.get_node("Ally3").disabled, "dead ally disabled; living self enabled")
	var before := _full_state()
	var epoch: int = presenter._epoch
	await _keyboard(KEY_ESCAPE)
	presenter._choose_ally(3, epoch)
	_check(_full_state() == before and presenter._pending.is_empty(), "Escape and stale confirmation cannot pay")
	await _open_card(panel, true)
	_check(root.get_visible_rect().encloses(presenter.cancel_button.get_global_rect()),
		"Cancel within viewport: %s" % presenter.cancel_button.get_global_rect())
	await _mouse(presenter.cancel_button)
	_check(_full_state() == before and presenter._pending.is_empty(), "mouse Cancel is state-pure")
	panel.grab_focus()
	root.push_input(_key(KEY_ENTER, true, true), true)
	root.push_input(_key(KEY_ENTER, false), true)
	await _frames()
	_check(_full_state() == before and presenter._pending.is_empty(), "key echo and release are inert")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id in [SHROUD, SHROUD_PLUS]:
		for seat in [2, 3]:
			for target in [1, seat]:
				await _shroud_success(id, seat, target, seat == 2, target == seat)
	var first := await _shroud_success(SHROUD_PLUS, 3, 1, true, false)
	var replay := await _shroud_success(SHROUD_PLUS, 3, 1, true, false)
	_check(not first.is_empty() and first == replay, "seeded mounted replay is identical")
	await _cancel_and_dead()
	for mode in ["wrong_seat", "missing", "owner_dead", "energy", "not_held", "redraw",
			"hand", "turn", "inactive", "closed", "battle", "session", "label", "forged", "context", "hidden"]:
		for queued in [false, true]:
			await _shroud_refusal(mode, queued)
	for mode in ["target_dead", "illegal_target", "cancel"]:
		await _shroud_refusal(mode, true)
	_finish()
