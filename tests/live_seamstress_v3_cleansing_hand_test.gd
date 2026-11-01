extends "res://tests/live_support_hand_test.gd"

const FORMS := ["seamstress_v3_mending_knot", "seamstress_v3_mending_knot_plus",
	"seamstress_v3_darn_the_tear", "seamstress_v3_darn_the_tear_plus"]
## The whole-party Midnight Loom pair really held and played from the shared hand.
const LOOM_FORMS := ["seamstress_v3_midnight_loom", "seamstress_v3_midnight_loom_plus"]
## The kinds the printed cleanse may remove, in the resolver's own fixed order.
const LOOM_ELIGIBLE := ["bleed", "weak", "exposed"]


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
	_check(presenter._targets.has(app.hero_panels[0]), "real target callback exists before commit")
	var target_callback: Callable = presenter._targets[app.hero_panels[0]].callback
	var cleanse_callback := Callable()
	await _ally(keyboard)
	if selected != "":
		_check(is_instance_valid(presenter.cleanse_choices) and presenter.cleanse_choices.get_child_count() == 3,
			"all three positive eligible counters explicitly offered")
		_check(_pool_state() == before and presenter.help_label.text.contains("Tab, Enter / Space"), "choice remains read only and explains keys")
		var button: Button = presenter.cleanse_choices.get_node(selected.capitalize())
		_check(button.is_visible_in_tree() and button.text.contains("Remove all"), "real visible choice button")
		cleanse_callback = button.pressed.get_connections()[0].callable
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
	# Successful play focuses End Turn; Enter there is a new legitimate turn action.
	# Replay the actual retired target/cleanse inputs to check one-shot payment instead.
	_check(app.end_turn_button.has_focus(), "successful play restores End Turn focus")
	target_callback.call(_press())
	if cleanse_callback.is_valid():
		cleanse_callback.call()
	await _frames()
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
	# The Midnight Loom pair is now genuinely playable from the shared hand: both printings,
	# both authored source seats, real mouse and keyboard, all three explicit cleanse kinds,
	# a seat with no eligible counter and a torn ally.
	for keyboard in [false, true]:
		await _loom_success(LOOM_FORMS[0], 2, keyboard, false, false, "weak" if keyboard else "bleed")
		await _loom_success(LOOM_FORMS[1], 3, keyboard, false, false, "bleed" if keyboard else "exposed")
		await _loom_success(LOOM_FORMS[1], 3, keyboard, true, false, "weak")
		await _loom_success(LOOM_FORMS[0], 2, keyboard, false, true, "")
	var first := await _loom_success(LOOM_FORMS[1], 2, true, false, false, "exposed")
	_check(await _loom_success(LOOM_FORMS[1], 2, true, false, false, "exposed") == first,
		"a complete seeded Midnight Loom success replays identically")
	for keyboard in [false, true]:
		for mode in ["absent", "energy", "owner", "seat", "turn", "battle"]:
			await _loom_refuse(mode, keyboard)
	for mode in ["statuses", "positions", "hand", "turn", "energy", "battle", "malformed", "escape", "cancel"]:
		await _loom_stale(mode)
	var refused := await _loom_stale("statuses")
	_check(await _loom_stale("statuses") == refused, "a deterministic no-spend Loom refusal replays")
	app.queue_free()
	await _frames()
	_finish()


## The authentic pool record for one Midnight Loom printing, straight from the catalog.
func _loom_definition(id: String) -> Dictionary:
	return V3SeamstressPoolCards.new().get_definition(id)


## A real mounted battle whose shared hand genuinely holds one Loom printing. Seat 2 is the
## shared party's own Seamstress slot; seat 3 is a real adjacent swap, so both authored source
## seats are exercised through the live hand.
func _loom_begin(id: String, seat: int) -> bool:
	if not await _begin(id):
		return false
	_check(app.deck.energy == CombatState.TURN_ENERGY, "real shared hand starts with three energy: " + id)
	if seat == 3:
		var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, 1)
		_check(swap.ok and app.party.get_hero(2).get("id") == "seamstress",
			"authentic adjacent swap reaches the authored back seat")
		app.party._heroes.assign(swap.heroes)
		app._refresh_intents()
		app._refresh_party()
		app._refresh_hand()
		await _frames()
	_check(app.party.get_hero(seat).get("id") == "seamstress", "owner really sits in seat %d" % seat)
	var panel := _pool_panel(id)
	_check(panel != null and panel.gui_input.get_connections().size() == 1,
		"the held Loom printing has exactly one real input binding: " + id)
	return panel != null


## Real wounds through the party model. The middle seat is hurt normally, the back seat ends
## two HP under its cap so the printed heal must cap there, and the downed variant leaves the
## front seat torn while it still carries positive counters.
func _loom_wounds(torn: bool) -> void:
	if torn:
		_check(app.party.apply_damage(1, 99999) and app.party.is_downed(1), "front seat genuinely torn")
	else:
		_check(app.party.apply_damage(1, int(app.party.get_hero(1).get("block", 0)) + 9),
			"front seat really wounded through its opening Block")
	_check(app.party.apply_damage(2, 7), "middle living seat really wounded")
	_check(app.party.apply_damage(3, 2), "back living seat ends two HP under its cap")
	_check(app.party.gain_block(3, 3), "back living seat already holds Block")


## Different positive counters on different living seats, plus ineligible ones that must
## survive. `empty` leaves no eligible counter anywhere, only ineligible positives.
func _loom_statuses(empty: bool) -> void:
	var spread := {
		0: {"bleed": 8, "weak": 3, "exposed": 2, "tangled": 7, "riposte": 2},
		1: {"weak": 4, "tangled": 2},
		2: {"exposed": 3, "weak": 0, "tangled": 1},
	}
	for index in range(3):
		app.party._heroes[index].statuses = {"weak": 0, "tangled": 1, "riposte": 2} \
			if empty else spread[index]
	app._refresh_party()


## The positive eligible kinds one hero snapshot really carries, for the offered buttons.
func _loom_offered(hero: Dictionary) -> Array[String]:
	var offered: Array[String] = []
	var statuses: Dictionary = hero.get("statuses", {})
	for debuff in LOOM_ELIGIBLE:
		if int(statuses.get(debuff, 0)) > 0:
			offered.append(debuff)
	return offered


## Independent oracle: a freshly constructed CombatDeck and CombatParty loaded from the detached
## mounted snapshot and resolved by a SEPARATE CombatSeamstressV3CleansingCards instance, never
## by the UI service and never by a hand-written effect.
func _loom_oracle(before: Array, id: String, selections: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(before[10])
	var cards: Array[String] = []
	var deck := CombatDeck.new(cards, rng)
	deck.draw_pile.assign(before[0])
	deck.hand.assign(before[1])
	deck.discard_pile.assign(before[2])
	deck.combat_state.energy = int(before[3])
	deck.combat_state.player_turn_active = bool(before[4])
	var party := CombatParty.new(app._load_party_definitions())
	party._heroes.assign((before[5] as Array).duplicate(true))
	var oracle := CombatSeamstressV3CleansingCards.new()
	_check(oracle != presenter._cleansing, "the oracle is a separate resolver instance")
	var receipt: Dictionary = oracle.play_party_card(deck, party, id, selections)
	_check(receipt.get("ok", false), "the independent resolver oracle accepts the same request: " + id)
	var expected: Array = before.duplicate(true)
	expected[0] = deck.draw_pile.duplicate()
	expected[1] = deck.hand.duplicate()
	expected[2] = deck.discard_pile.duplicate()
	expected[3] = deck.energy
	expected[4] = deck.turn_active
	expected[5] = party.get_heroes()
	return expected


func _loom_arm(panel: Control, keyboard: bool) -> void:
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(panel)


func _loom_success(id: String, seat: int, keyboard: bool, torn: bool, empty: bool,
		selected: String) -> Array:
	if not await _loom_begin(id, seat):
		_check(false, "the Loom success fixture must start a real mounted battle: " + id)
		await _pool_return()
		return []
	_loom_wounds(torn)
	_loom_statuses(empty)
	await _frames()
	var panel := _pool_panel(id)
	var definition: Dictionary = _loom_definition(id)
	var effects: Dictionary = definition.get("effects", {})
	var meta = presenter._metadata
	var facts: Dictionary = meta.get_facts(panel)
	_check(not definition.is_empty() and definition.get("id") == id
		and definition.get("owner") == "seamstress" and int(definition.get("cost")) == 3
		and definition.get("target_kind") == "party_all"
		and definition.get("from_positions") == [2, 3]
		and (definition.get("to_positions", []) as Array).is_empty()
		and effects == {"heal": 4 if id == LOOM_FORMS[0] else 6,
			"block": 4 if id == LOOM_FORMS[0] else 6, "cleanse_debuff": 1}
		and definition.get("reward_eligible") == (id == LOOM_FORMS[0])
		and presenter._is_actionable(id) and presenter._is_loom_card(id),
		"authentic authored Midnight Loom record: " + id)
	_check(facts.get("known") == true and facts.get("display_name") == definition.display_name
		and int(facts.get("cost")) == 3 and facts.get("owner") == "seamstress"
		and facts.get("from_text") == "From " + meta._positions([2, 3])
		and facts.get("target_text") == "All living heroes"
		and bool(meta.visual_state(panel).get("playable", false)),
		"honest enabled party-wide printed face: " + id)
	_check(meta.definition(id) == definition, "the drawn face is the authentic catalog record: " + id)
	var short_line: String = meta.short_line(id)
	_check(short_line.contains("Each living hero: heal %d HP" % int(effects.heal))
		and short_line.contains("gain %d Block" % int(effects.block)),
		"the drawn face prints the authentic party-wide heal and Block: " + id)
	_check(panel.tooltip_text.contains("all living heroes")
		and panel.tooltip_text.contains("capped at max HP")
		and panel.tooltip_text.contains("remove completely")
		and panel.tooltip_text.contains("Torn heroes are excluded"),
		"the tooltip prints the party-wide heal, Block and explicit cleanse: " + id)
	var source: Callable = presenter._bindings[panel]
	var before := _pool_state()
	_check(int(before[3]) == 3, "three available energy before the Loom: " + id)
	await _loom_arm(panel, keyboard)
	if not empty:
		_check(_pool_state() == before, "arming a Loom spends nothing including RNG: " + id)
		_check(presenter._pending.get("choosing", false) and presenter._targets.is_empty(),
			"the party-wide flow opens with no extra target picker: " + id)
		_check(presenter.cancel_button.is_visible_in_tree(), "cancel stays reachable during choices")
	var wanted := {1: selected, 2: "weak", 3: "exposed"}
	var plan_positions: Array[int] = []
	if not empty:
		for position in [1, 2, 3]:
			if not (torn and position == 1):
				plan_positions.append(position)
	var selections: Dictionary = {}
	var receipts: Array[Callable] = []
	var first_living := true
	for index in range(plan_positions.size()):
		var position: int = plan_positions[index]
		var snapshot: Dictionary = before[5][position - 1]
		var offered := _loom_offered(snapshot)
		_check(is_instance_valid(presenter.cleanse_choices)
			and presenter._pending.get("choice_position", 0) == position
			and presenter.cleanse_choices.get_child_count() == offered.size(),
			"seat %d asks for exactly one of its own present counters" % position)
		_check(presenter.help_label.text.contains(app.party.get_hero(position).name),
			"the prompt names the real hero in seat %d" % position)
		if not is_instance_valid(presenter.cleanse_choices):
			break
		var names: Array[String] = []
		for button in presenter.cleanse_choices.get_children():
			names.append(String(button.name).to_lower())
			_check(button.is_visible_in_tree() and root.get_visible_rect().encloses(button.get_global_rect())
				and button.get_theme_font_size("font_size") >= 18, "readable mounted choice button")
		_check(names == offered, "only present eligible counters are offered in fixed order")
		var kind: String = wanted[position]
		var button: Button = presenter.cleanse_choices.get_node_or_null(kind.capitalize())
		_check(button != null and button.text.contains("Remove all %s (%d)" % [
			kind.capitalize(), int(snapshot.statuses.get(kind, 0))]),
			"explicit remove-the-whole-counter button for " + kind)
		if button == null:
			break
		receipts.append(button.pressed.get_connections()[0].callable)
		if keyboard:
			if first_living:
				for step in range(offered.find(kind)):
					await _keyboard(KEY_TAB)
				_check(button.has_focus(), "Tab reaches the chosen counter on seat %d" % position)
				await _keyboard(KEY_SPACE)
			else:
				_check(button.has_focus(), "the next seat's first counter receives focus")
				await _keyboard(KEY_ENTER)
		else:
			await _mouse(button)
		first_living = false
		selections[position] = kind
		if index < plan_positions.size() - 1:
			_check(_pool_state() == before, "a partial cleanse choice still spends nothing")
			_check(presenter._pending.get("selections", {}) == selections, "each chosen counter is remembered")
			_check(is_instance_valid(presenter.cleanse_choices), "the next living hero still owes a choice")
	if empty:
		_check(presenter._pending.is_empty(), "a party with no eligible counter needs no choice")
	var expected := _loom_oracle(before, id, selections)
	_check(_pool_state() == expected,
		"the mounted Loom matches the independent resolver oracle exactly: " + id)
	for position in [1, 2, 3]:
		var hero: Dictionary = app.party.get_hero(position)
		var was: Dictionary = before[5][position - 1]
		if int(was.get("hp", 0)) == 0:
			_check(int(hero.hp) == 0 and int(hero.block) == int(was.block) and hero.statuses == was.statuses,
				"a torn seat is never healed, Blocked or cleansed")
			continue
		_check(int(hero.hp) == mini(int(was.max_hp), int(was.hp) + int(effects.heal))
			and int(hero.block) == int(was.block) + int(effects.block),
			"exact printed heal capped at max HP and Block on living seat %d" % position)
		var chosen: String = str(selections.get(position, ""))
		for debuff in LOOM_ELIGIBLE:
			if debuff == chosen:
				_check(not hero.statuses.has(debuff), "the chosen counter is removed entirely")
			else:
				_check(int(hero.statuses.get(debuff, 0)) == int(was.statuses.get(debuff, 0)),
					"every unchosen counter survives on seat %d" % position)
		_check(int(hero.statuses.get("tangled", 0)) == int(was.statuses.get("tangled", 0))
			and int(hero.statuses.get("riposte", 0)) == int(was.statuses.get("riposte", 0)),
			"ineligible statuses are never cleansed")
	_check(app.deck.energy == 0, "the printed three energy is paid exactly once")
	_check(app.deck.discard_pile.back() == id and not app.deck.hand.has(id),
		"exactly the held printing is discarded")
	_check(app.run_rng.seed == before[10] and app.run_rng.state == before[11],
		"the Loom consumes no combat RNG")
	_check(presenter._pending.is_empty() and presenter._targets.is_empty()
		and not is_instance_valid(presenter.cleanse_choices), "the commit clears every choice control")
	_check(app.end_turn_button.has_focus(), "a successful Loom restores End Turn focus")
	_check(presenter.energy_label.text == "0"
		and app.pile_label.text.contains("Discard: %d" % app.deck.discard_pile.size()),
		"the energy and pile HUD refresh after the Loom")
	source.call(_press())
	for receipt in receipts:
		receipt.call()
	await _frames()
	_check(_pool_state() == expected, "retired Loom callbacks cannot pay a second time")
	await _pool_return()
	return expected


## Preflight refusals: with the real panel still mounted, an absent printing, too little
## energy, a downed owner, an unauthored seat, an ended turn or a closed battle cannot stage
## or spend a Loom at all.
func _loom_refuse(mode: String, keyboard: bool) -> void:
	var id: String = LOOM_FORMS[0]
	if not await _loom_begin(id, 2):
		_check(false, "the Loom refusal fixture must start a real mounted battle")
		await _pool_return()
		return
	_loom_wounds(false)
	_loom_statuses(false)
	await _frames()
	match mode:
		"absent": _check(app.deck.discard_played(id), "the real held printing is removed")
		"energy": app.deck.combat_state.energy = CombatState.TURN_ENERGY - 1
		"owner": _check(app.party.apply_damage(2, 99999) and app.party.is_downed(2), "owner really downed")
		"seat":
			var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, -1)
			_check(swap.ok, "authentic adjacent swap into the illegal front seat")
			app.party._heroes.assign(swap.heroes)
			_check(app.party.get_hero(1).get("id") == "seamstress", "owner really outside the authored seats")
		"turn": app.deck.combat_state.player_turn_active = false
		"battle": app._battle_closed = true
	app._refresh_party()
	app._refresh_intents()
	await _frames()
	var panel := _pool_panel(id)
	var before := _pool_state()
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(panel)
	_check(_pool_state() == before and presenter._pending.is_empty()
		and presenter._targets.is_empty() and not is_instance_valid(presenter.cleanse_choices),
		"a preflight refusal never stages or spends a Loom: " + mode + (" keyboard" if keyboard else " mouse"))
	await _pool_return()


## A pending Loom choice that becomes stale (counters, roster, hand, energy, turn or battle
## changed) or is cancelled must never commit, and its captured button cannot replay.
func _loom_stale(mode: String) -> Array:
	var id: String = LOOM_FORMS[1]
	if not await _loom_begin(id, 2):
		_check(false, "the stale Loom fixture must start a real mounted battle")
		await _pool_return()
		return []
	_loom_wounds(false)
	_loom_statuses(false)
	await _frames()
	var panel := _pool_panel(id)
	await _loom_arm(panel, false)
	_check(is_instance_valid(presenter.cleanse_choices), "real first-seat counters before a stale request")
	if not is_instance_valid(presenter.cleanse_choices):
		await _pool_return()
		return []
	await _mouse(presenter.cleanse_choices.get_child(0))
	_check(presenter._pending.get("selections", {}) == {1: "bleed"}, "one real counter is already chosen")
	_check(is_instance_valid(presenter.cleanse_choices)
		and presenter.cleanse_choices.has_node("Weak"), "the second seat still owes its own Weak choice")
	if not is_instance_valid(presenter.cleanse_choices):
		await _pool_return()
		return []
	var callback: Callable = presenter.cleanse_choices.get_node("Weak").pressed.get_connections()[0].callable
	match mode:
		"statuses": app.party._heroes[1].statuses.weak = 9
		"positions":
			var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, 1)
			_check(swap.ok, "authentic pending-roster swap")
			app.party._heroes.assign(swap.heroes)
		"hand":
			var other := ""
			for held in app.deck.hand:
				if held != id:
					other = held
					break
			_check(not other.is_empty() and app.deck.discard_played(other), "the shared hand really changed")
		"turn": app.deck.combat_state.player_turn_active = false
		"energy": app.deck.combat_state.energy = CombatState.TURN_ENERGY - 1
		"battle": app._battle_closed = true
		"malformed": app.party._heroes[2].statuses = []
		"escape": await _keyboard(KEY_ESCAPE)
		"cancel": await _mouse(presenter.cancel_button)
	app._refresh_party()
	app._refresh_intents()
	await _frames()
	var before := _pool_state()
	callback.call()
	await _frames()
	_check(_pool_state() == before and presenter._pending.is_empty()
		and presenter._targets.is_empty() and not is_instance_valid(presenter.cleanse_choices),
		"a stale Loom choice cancels without spending: " + mode)
	callback.call()
	await _frames()
	_check(_pool_state() == before, "a refused Loom choice cannot replay: " + mode)
	await _pool_return()
	return before
