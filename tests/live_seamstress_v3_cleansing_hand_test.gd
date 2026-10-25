extends "res://tests/live_support_hand_test.gd"

const FORMS := ["seamstress_v3_mending_knot", "seamstress_v3_mending_knot_plus",
	"seamstress_v3_darn_the_tear", "seamstress_v3_darn_the_tear_plus"]


func _begin(id: String) -> bool:
	app.run_seed = 4247
	_fixture_start(app)
	await _frames()
	_check(app.deck != null and app.party != null and app.enemies != null, "real battle authorities")
	if app.deck == null:
		return false
	app.deck.draw_pile.append(id)
	_check(app.deck.draw_extra(1) == 1 and app.deck.hand.back() == id, "genuine held draw")
	app._refresh_hand()
	await _frames()
	var panel := _pool_panel(id)
	_check(panel != null and panel.gui_input.get_connections().size() == 1, "real mounted input")
	return panel != null


func _arm(id: String, keyboard: bool) -> void:
	var panel := _pool_panel(id)
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(panel)
	_check(presenter._pending.get("choosing", false), "ally selection actually armed")


func _ally(keyboard: bool) -> void:
	if keyboard:
		app.hero_panels[0].grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(app.hero_panels[0])


func _play_case(id: String, keyboard: bool, selected: String, capped: bool) -> void:
	if not await _begin(id):
		return
	_check(app.party.apply_damage(1, 2 if capped else 12), "target genuinely wounded")
	app.party._heroes[0].statuses = {"tangled": 7, "riposte": 2, "weak": 0} if selected == "" else {
		"bleed": 8, "weak": 3, "exposed": 2, "tangled": 7, "riposte": 2}
	app._refresh_party()
	await _frames()
	var panel := _pool_panel(id)
	var definition: Dictionary = presenter._metadata.definition(id)
	var facts: Dictionary = presenter._metadata.get_facts(panel)
	_check(facts.known and facts.display_name == definition.display_name and facts.cost == 1
		and facts.owner == "seamstress" and panel.tooltip_text.contains("Choose one present")
		and presenter._metadata.short_line(id).contains("Heal %d" % definition.effects.heal), "catalog face and explicit rules")
	var before := _pool_state()
	await _arm(id, keyboard)
	_check(_pool_state() == before, "arming spends nothing including RNG")
	await _ally(keyboard)
	if selected != "":
		_check(is_instance_valid(presenter.cleanse_choices) and presenter.cleanse_choices.get_child_count() == 3,
			"all three positive eligible counters explicitly offered")
		_check(_pool_state() == before and presenter.help_label.text.contains("Tab, Enter / Space"), "choice remains read only and explains keys")
		var button: Button = presenter.cleanse_choices.get_node(selected.capitalize())
		_check(button.is_visible_in_tree() and button.text.contains("Remove all"), "real visible choice button")
		for choice in presenter.cleanse_choices.get_children():
			_check(root.get_visible_rect().encloses(choice.get_global_rect())
				and choice.get_minimum_size().x <= choice.size.x
				and choice.get_theme_font_size("font_size") >= 18, "readable choice stays in viewport")
		if keyboard:
			# Traverse actual focus rather than invoking a service or callback.
			for index in range(["bleed", "weak", "exposed"].find(selected)):
				await _keyboard(KEY_TAB)
			_check(button.has_focus(), "Tab reaches selected debuff")
			await _keyboard(KEY_SPACE)
		else:
			await _mouse(button)
	var expected: Array = before.duplicate(true)
	expected[1].erase(id)
	expected[2].append(id)
	expected[3] -= 1
	expected[5][0].hp = mini(expected[5][0].max_hp, expected[5][0].hp + definition.effects.heal)
	if selected != "":
		expected[5][0].statuses.erase(selected)
	_check(_pool_state() == expected, "exact capped heal, entire chosen counter, one payment/copy, other state and RNG untouched: " + id)
	_check(presenter._pending.is_empty() and not is_instance_valid(presenter.cleanse_choices), "successful commit cleans targeting")
	_check(app.hero_panels[0].get_child(0).text.contains("HP: %d/" % expected[5][0].hp), "success refreshes real HP HUD")
	await _keyboard(KEY_ENTER)
	_check(_pool_state() == expected, "no repeated payment")
	await _pool_return()


func _refuse(mode: String) -> void:
	var id: String = FORMS[0]
	if not await _begin(id):
		return
	_check(app.party.apply_damage(1, 12), "refusal has healable target")
	app.party._heroes[0].statuses = {"bleed": 8, "weak": 3, "exposed": 2}
	await _arm(id, false)
	await _ally(false)
	_check(is_instance_valid(presenter.cleanse_choices), "refusal begins with real debuff choices: " + mode)
	var callback: Callable = presenter.cleanse_choices.get_child(0).pressed.get_connections()[0].callable
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"target":
			_check(app.party.apply_damage(1, 10000) and app.party.is_downed(1), "actually downed target")
		"owner":
			_check(app.party.apply_damage(2, 10000) and app.party.is_downed(2), "actually downed owner")
		"seat":
			var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, -1)
			_check(swap.ok, "authentic illegal-seat swap")
			app.party._heroes.assign(swap.heroes)
			_check(app.party.get_hero(1).id == "seamstress", "owner really in illegal seat")
			app._refresh_intents()
		"hand": _check(app.deck.discard_played(id), "actual copy removed")
		"panel": app._refresh_hand()
		"turn": app.deck.combat_state.player_turn_active = false
		"battle": app._battle_closed = true
		"identity": app.party._heroes[0].id = "replacement"
		"statuses": app.party._heroes[0].statuses.weak = 4
		"malformed": app.party._heroes[2].statuses = {"weak": -1}
		"escape": await _keyboard(KEY_ESCAPE)
		"cancel": await _mouse(presenter.cancel_button)
	var before := _pool_state()
	callback.call()
	await _frames()
	_check(_pool_state() == before, "stale/refused callback is wholly inert: " + mode)
	_check(presenter._pending.is_empty(), "refusal clears staged state: " + mode)
	callback.call()
	await _frames()
	_check(_pool_state() == before, "refused receipt cannot replay: " + mode)
	await _pool_return()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = (load("res://scenes/app.tscn") as PackedScene).instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveSupportHand")
	for id in FORMS:
		for keyboard in [false, true]:
			for selected in ["bleed", "weak", "exposed", ""]:
				await _play_case(id, keyboard, selected, selected == "")
	for mode in ["energy", "target", "owner", "seat", "hand", "panel", "turn", "battle", "identity", "statuses", "malformed", "escape", "cancel"]:
		await _refuse(mode)
	app.queue_free()
	await _frames()
	_finish()
