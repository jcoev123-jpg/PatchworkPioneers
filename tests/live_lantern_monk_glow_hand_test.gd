extends "res://tests/live_lantern_monk_vigil_hand_test.gd"

const GLOW_FORMS := ["lantern_monk_lantern_glow", "lantern_monk_lantern_glow_plus"]


func _glow_fixture(id: String, seat: int, empty: bool = false, torn: bool = false) -> Control:
	var panel := await _begin(id, seat)
	if panel == null:
		return null
	app.party._heroes[0].statuses = {"bleed": 8, "weak": 3, "tangled": 7, "riposte": 2}
	app.party._heroes[1].statuses = {"exposed": 4, "tangled": 2}
	app.party._heroes[2].statuses = {"weak": 0, "tangled": 1}
	if empty:
		for hero in app.party._heroes:
			hero.statuses = {"weak": 0, "tangled": 1, "riposte": 2}
	if torn:
		_check(app.party.apply_damage(2, 999) and app.party.is_downed(2), "actual Torn recipient")
	app._refresh_party()
	await _frames()
	return panel


func _glow_arm(panel: Control, keyboard: bool) -> void:
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(panel)


func _glow_success(id: String, seat: int, keyboard: bool, empty: bool, torn: bool) -> Array:
	var panel := await _glow_fixture(id, seat, empty, torn)
	if panel == null:
		await _dispose()
		return []
	app.deck.combat_state.energy = 2
	var definition := LanternMonkPoolCards.new().get_definition(id)
	var meta = presenter._metadata
	var facts: Dictionary = meta.get_facts(panel)
	_check(not definition.is_empty() and definition.owner == "lantern_monk"
		and definition.cost == 1 and definition.from_positions == [1, 2, 3]
		and definition.target_kind == "party_all" and definition.to_positions.is_empty()
		and definition.effects == {"heal_all": 2 if id == GLOW_FORMS[0] else 3, "cleanse_one_debuff_each_ally": 1}, "authentic base/+ record")
	_check(facts.known and facts.owner == "lantern_monk" and facts.cost == 1
		and facts.from_text == "From " + meta._positions([1, 2, 3])
		and facts.target_text == "All living heroes" and meta.visual_state(panel).playable
		and meta.definition(id) == definition, "honest enabled party-wide face in every owner seat")
	_check(meta.short_line(id) == "Each living hero: heal %d HP; choose Bleed/Weak/Exposed to remove all (if present)." % definition.effects.heal_all
		and panel.tooltip_text.contains("No Block; Torn heroes are excluded")
		and panel.tooltip_text.contains("capped at max HP"), "explicit heal/choice and exclusion text")
	var source: Callable = presenter._bindings[panel]
	var before := _pool_state()
	var receipts: Array[Callable] = []
	await _glow_arm(panel, keyboard)
	if not empty:
		_check(_pool_state() == before and presenter._targets.is_empty()
			and presenter._pending.get("choosing", false), "no target selection or spend before choices")
		_check(is_instance_valid(presenter.cleanse_choices) and presenter.cleanse_choices.get_child_count() == 2,
			"first hero offered only its two present eligible statuses")
		if not is_instance_valid(presenter.cleanse_choices):
			await _dispose()
			return []
		var weak: Button = presenter.cleanse_choices.get_node("Weak")
		receipts.append(weak.pressed.get_connections()[0].callable)
		for button in presenter.cleanse_choices.get_children():
			_check(button.is_visible_in_tree() and root.get_visible_rect().encloses(button.get_global_rect())
				and button.get_minimum_size().x <= button.size.x and button.get_theme_font_size("font_size") >= 18,
				"readable mounted choices in viewport")
		if keyboard:
			await _keyboard(KEY_TAB)
			_check(weak.has_focus(), "Tab reaches Weak")
			await _keyboard(KEY_SPACE)
		else:
			await _mouse(weak)
		if not torn:
			_check(_pool_state() == before and presenter._pending.selections == {1: "weak"}, "partial choice spends nothing")
			_check(is_instance_valid(presenter.cleanse_choices) and presenter.cleanse_choices.get_child_count() == 1
				and presenter._pending.choice_position == 2 and presenter.help_label.text.contains(app.party.get_hero(2).name),
				"second living hero has its own distinct Exposed choice and name")
			var exposed: Button = presenter.cleanse_choices.get_node("Exposed")
			receipts.append(exposed.pressed.get_connections()[0].callable)
			receipts[0].call()
			await _frames()
			_check(_pool_state() == before and presenter._pending.selections == {1: "weak"}, "old first-choice callback cannot fill next hero")
			if keyboard:
				_check(exposed.has_focus(), "next choice receives focus")
				await _keyboard(KEY_ENTER)
			else:
				await _mouse(exposed)
	var expected := before.duplicate(true)
	expected[1].erase(id)
	expected[2].append(id)
	expected[3] -= 1
	for hero in expected[5]:
		if hero.hp > 0:
			hero.hp = mini(hero.max_hp, hero.hp + definition.effects.heal_all)
	if not empty:
		expected[5][0].statuses.erase("weak")
		if not torn:
			expected[5][1].statuses.erase("exposed")
	_check(_pool_state() == expected, "exact capped heals/chosen entire counters, unchanged Torn/Block/other statuses/enemies/RNG, one copy and energy")
	_check(presenter._pending.is_empty() and not is_instance_valid(presenter.cleanse_choices)
		and app.end_turn_button.has_focus(), "commit clears choices and restores focus")
	_check(presenter.energy_label.text == str(app.deck.energy)
		and app.pile_label.text.contains("Discard: %d" % app.deck.discard_pile.size()), "energy and pile HUD refreshed")
	for slot in [1, 2, 3]:
		var hero: Dictionary = app.party.get_hero(slot)
		var meter = app.get_node("LiveCombatMeters").row.get_child(slot - 1)
		_check(meter.hp_text.text == "%d/%d" % [hero.hp, hero.max_hp] and meter.hp_bar.value == hero.hp, "real HP meters refreshed")
	source.call(_press())
	for receipt in receipts:
		receipt.call()
	await _frames()
	_check(_pool_state() == expected and app.deck.hand.count(id) == 1, "retired callbacks cannot spend duplicate")
	var remaining := _pool_panel(id)
	_check(remaining != null and remaining != panel and presenter._bindings.has(remaining), "second copy independently bound")
	if remaining != null:
		_check(app.deck.energy == 1 and meta.visual_state(remaining).playable, "last energy enables second copy")
		remaining.grab_focus()
		await _keyboard(KEY_SPACE)
		if not empty:
			_check(is_instance_valid(presenter.cleanse_choices) and presenter.cleanse_choices.has_node("Bleed"), "second copy offers remaining Bleed")
			await _keyboard(KEY_ENTER)
		_check(app.deck.hand.count(id) == 0 and app.deck.energy == before[3] - 2
			and app.run_rng.state == before[11], "second copy pays once via Space/Enter")
	var result := _pool_state()
	await _dispose()
	return result


func _glow_refuse(mode: String, partial: bool) -> Array:
	var panel := await _glow_fixture(GLOW_FORMS[0], 3)
	if panel == null:
		await _dispose()
		return []
	await _glow_arm(panel, false)
	_check(is_instance_valid(presenter.cleanse_choices), "real pending choices before refusal")
	if not is_instance_valid(presenter.cleanse_choices):
		await _dispose()
		return []
	var callback: Callable = presenter.cleanse_choices.get_node("Weak").pressed.get_connections()[0].callable
	if partial:
		await _mouse(presenter.cleanse_choices.get_node("Weak"))
		_check(presenter._pending.selections == {1: "weak"} and app.deck.energy == 6, "real incomplete request")
		callback = presenter.cleanse_choices.get_node("Exposed").pressed.get_connections()[0].callable
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"owner": app.party.apply_damage(3, 999)
		"missing": app.party._heroes[2].id = "seamstress"
		"recipient": app.party.apply_damage(1, 999)
		"roster": app.party._heroes[0].id = "replacement"
		"seat":
			var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 3, -1)
			_check(swap.ok, "legal owner seat change still invalidates pending roster")
			app.party._heroes.assign(swap.heroes)
		"statuses": app.party._heroes[0].statuses.weak = 4
		"other_statuses": app.party._heroes[1].statuses.exposed = 5
		"malformed": app.party._heroes[2].statuses = []
		"hand": app.deck.discard_played(GLOW_FORMS[0])
		"panel": app._refresh_hand()
		"label": panel.get_child(0).text = GLOW_FORMS[1]
		"turn": app.enemy_intents.advance_turn()
		"inactive": app.deck.combat_state.player_turn_active = false
		"closed": app._battle_closed = true
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"enemies": app.enemies = CombatEnemies.new([{"id": "other", "max_hp": 20}])
		"escape": await _keyboard(KEY_ESCAPE)
		"cancel": await _mouse(presenter.cancel_button)
	app._refresh_intents()
	var before := _pool_state()
	callback.call()
	await _frames()
	_check(_pool_state() == before and presenter._pending.is_empty(), "entire stale request cancelled without spend: " + mode)
	callback.call()
	await _frames()
	_check(_pool_state() == before, "refused selection replay inert: " + mode)
	await _dispose()
	return before


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id in GLOW_FORMS:
		for seat in [1, 2, 3]:
			for keyboard in [false, true]:
				await _glow_success(id, seat, keyboard, false, false)
		await _glow_success(id, 3, true, true, false)
		await _glow_success(id, 3, false, false, true)
	var first := await _glow_success(GLOW_FORMS[1], 3, true, false, true)
	_check(await _glow_success(GLOW_FORMS[1], 3, true, false, true) == first, "complete seeded success replay")
	for mode in ["energy", "owner", "missing", "recipient", "roster", "seat", "statuses", "other_statuses", "malformed", "hand", "panel", "label", "turn", "inactive", "closed", "session", "enemies", "escape", "cancel"]:
		for partial in [false, true]:
			await _glow_refuse(mode, partial)
	var refused := await _glow_refuse("statuses", true)
	_check(await _glow_refuse("statuses", true) == refused, "deterministic no-spend replay")
	_finish()
