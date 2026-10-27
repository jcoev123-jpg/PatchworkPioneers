extends "res://tests/live_lantern_monk_glow_hand_test.gd"

## Cycle 346: the Lantern Monk starter Lamplight Wash (cost 2, seats 2-3, heal every living hero
## and remove one chosen whole debuff each) plays from the mounted battle hand through the shared
## Glow choice flow, and is reachable after the real title pick-three admission.

const PartyChoice := preload("res://tests/party_choice.gd")
const WASH_FORMS := ["lantern_monk_lamplight_wash", "lantern_monk_lamplight_wash_plus"]


func _wash_success(id: String, seat: int, keyboard: bool, empty: bool, torn: bool) -> Array:
	var panel := await _glow_fixture(id, seat, empty, torn)
	if panel == null:
		await _dispose()
		return []
	app.deck.combat_state.energy = 4
	var definition := LanternMonkStarterCards.new().get_definition(id)
	var heal := 2 if id == WASH_FORMS[0] else 3
	var meta = presenter._metadata
	var facts: Dictionary = meta.get_facts(panel)
	_check(not definition.is_empty() and definition.owner == "lantern_monk"
		and definition.cost == 2 and definition.from_positions == [2, 3]
		and definition.target_kind == "party_all" and definition.to_positions.is_empty()
		and definition.effects == {"heal": heal, "cleanse_debuff": 1}, "authentic starter base/+ record")
	_check(facts.known and facts.owner == "lantern_monk" and facts.cost == 2
		and facts.from_text == "From " + meta._positions([2, 3])
		and facts.target_text == "All living heroes" and meta.visual_state(panel).playable
		and meta.definition(id) == definition, "honest enabled party-wide face from seats 2-3")
	_check(meta.short_line(id) == "Each living hero: heal %d HP; choose Bleed/Weak/Exposed to remove all (if present)." % heal
		and panel.tooltip_text.contains("No Block; Torn heroes are excluded")
		and panel.tooltip_text.contains("capped at max HP"), "explicit heal/choice and exclusion text")
	var source: Callable = presenter._bindings[panel]
	var before := _pool_state()
	var receipts: Array[Callable] = []
	await _glow_arm(panel, keyboard)
	if not empty:
		_check(_pool_state() == before and presenter._targets.is_empty()
			and presenter._pending.get("choosing", false), "no target selection or spend before choices")
		_check(presenter.help_label.text.contains(String(definition.display_name))
			and presenter.help_label.text.contains(app.party.get_hero(1).name), "prompt names the card and hero")
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
	expected[3] -= 2
	for hero in expected[5]:
		if hero.hp > 0:
			hero.hp = mini(hero.max_hp, hero.hp + heal)
	if not empty:
		expected[5][0].statuses.erase("weak")
		if not torn:
			expected[5][1].statuses.erase("exposed")
	_check(_pool_state() == expected, "exact capped heals/chosen entire counters, unchanged Torn/Block/other statuses/enemies/RNG, one copy and 2 energy")
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
		_check(app.deck.energy == 2 and meta.visual_state(remaining).playable, "last two energy enables second copy")
		remaining.grab_focus()
		await _keyboard(KEY_SPACE)
		if not empty:
			_check(is_instance_valid(presenter.cleanse_choices) and presenter.cleanse_choices.has_node("Bleed"), "second copy offers remaining Bleed")
			await _keyboard(KEY_ENTER)
		_check(app.deck.hand.count(id) == 0 and app.deck.energy == before[3] - 4
			and app.run_rng.state == before[11], "second copy pays once via Space/Enter")
	var result := _pool_state()
	await _dispose()
	return result


## Seat 1 is outside Wash's [2, 3] and 1 energy is below its cost of 2: the face is disabled
## and neither a click nor a direct binding call spends, opens choices or advances RNG.
func _wash_unplayable(id: String, mode: String) -> void:
	var panel := await _glow_fixture(id, 1 if mode == "seat1" else 3)
	if panel == null:
		await _dispose()
		return
	if mode == "energy1":
		app.deck.combat_state.energy = 1
		app._refresh_hand()
		await _frames()
		panel = _pool_panel(id)
	var before := _pool_state()
	_check(panel != null and not presenter._metadata.visual_state(panel).playable, "disabled Wash face: " + mode)
	if panel != null:
		await _mouse(panel)
		if presenter._bindings.has(panel):
			presenter._bindings[panel].call(_press())
		await _frames()
	_check(_pool_state() == before and presenter._pending.is_empty()
		and not is_instance_valid(presenter.cleanse_choices), "illegal Wash spends nothing: " + mode)
	await _dispose()


func _wash_refuse(mode: String, partial: bool) -> Array:
	var panel := await _glow_fixture(WASH_FORMS[0], 3)
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
		"energy": app.deck.combat_state.energy = 1
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
		"hand": app.deck.discard_played(WASH_FORMS[0])
		"panel": app._refresh_hand()
		"label": panel.get_child(0).text = WASH_FORMS[1]
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
	_check(_pool_state() == before and presenter._pending.is_empty(), "entire stale Wash request cancelled without spend: " + mode)
	callback.call()
	await _frames()
	_check(_pool_state() == before, "refused Wash selection replay inert: " + mode)
	await _dispose()
	return before


## The real title flow: Start, the pick-three picker, the seeded opening Fight. The admitted
## Lantern Monk deck carries exactly one Lamplight Wash, and the held copy is bound and playable.
func _admitted_wash() -> void:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	var ids: Array[String] = ["warden", "lantern_monk", "tinker"]
	var receipt := RunV3PartyAdmission.admit(ids)
	_check(receipt.ok and receipt.deck.count(WASH_FORMS[0]) == 1, "canonical admission deck holds one Wash")
	await _mouse(app.start_button)
	_check(is_instance_valid(app.party_picker) and app.run_map == null, "Start asks for the party first")
	PartyChoice.choose(app, ids)
	await _frames()
	var fight: Button = null
	for button in app.route_buttons:
		if not button.disabled and String(button.get_meta("route_kind", "")) == "Fight":
			fight = button
			break
	_check(fight != null, "the admitted opening offers a Fight")
	if fight == null:
		await _dispose()
		return
	await _mouse(fight)
	presenter = app.get_node("LiveSupportHand")
	var seat := -1
	for slot in [1, 2, 3]:
		if String(app.party.get_hero(slot).get("id", "")) == "lantern_monk":
			seat = slot
	_check(seat in [2, 3], "admitted Lantern Monk stands in a Wash seat")
	var cards: Array = []
	for pile in [app.deck.draw_pile, app.deck.hand, app.deck.discard_pile]:
		cards.append_array(pile)
	_check(cards.count(WASH_FORMS[0]) == 1 and cards.size() == receipt.deck.size(), "the Fight deck is the admitted deck")
	var turns := 0
	while not app.deck.hand.has(WASH_FORMS[0]) and turns < 4:
		await _mouse(app.end_turn_button)
		await _frames()
		turns += 1
	var panel := _pool_panel(WASH_FORMS[0])
	_check(panel != null and presenter._bindings.has(panel) and presenter._metadata.visual_state(panel).playable,
		"the drawn admitted Wash is a bound, enabled hand card")
	if panel == null:
		await _dispose()
		return
	var hurt := false
	for slot in [1, 2, 3]:
		var hero: Dictionary = app.party.get_hero(slot)
		hurt = hurt or hero.hp < hero.max_hp
	var before := _pool_state()
	await _glow_arm(panel, false)
	while is_instance_valid(presenter.cleanse_choices) and presenter.cleanse_choices.get_child_count() > 0:
		await _mouse(presenter.cleanse_choices.get_child(0))
	var after := _pool_state()
	_check(after[1].count(WASH_FORMS[0]) == 0 and after[2].count(WASH_FORMS[0]) == before[2].count(WASH_FORMS[0]) + 1
		and after[3] == before[3] - 2 and after[11] == before[11], "admitted Wash plays once for 2 energy without RNG")
	for slot in [1, 2, 3]:
		var old: Dictionary = before[5][slot - 1]
		var now: Dictionary = after[5][slot - 1]
		_check(now.hp == (old.hp if old.hp <= 0 else mini(old.max_hp, old.hp + 2)), "admitted Wash heals each living hero 2, capped")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id in WASH_FORMS:
		for seat in [2, 3]:
			for keyboard in [false, true]:
				await _wash_success(id, seat, keyboard, false, false)
		await _wash_success(id, 3, true, true, false)
		await _wash_success(id, 3, false, false, true)
		for mode in ["seat1", "energy1"]:
			await _wash_unplayable(id, mode)
	var first := await _wash_success(WASH_FORMS[1], 3, true, false, true)
	_check(await _wash_success(WASH_FORMS[1], 3, true, false, true) == first, "complete seeded Wash success replay")
	for mode in ["energy", "owner", "missing", "recipient", "roster", "seat", "statuses", "other_statuses", "malformed", "hand", "panel", "label", "turn", "inactive", "closed", "session", "enemies", "escape", "cancel"]:
		for partial in [false, true]:
			await _wash_refuse(mode, partial)
	var refused := await _wash_refuse("statuses", true)
	_check(await _wash_refuse("statuses", true) == refused, "deterministic Wash no-spend replay")
	await _admitted_wash()
	_finish()
