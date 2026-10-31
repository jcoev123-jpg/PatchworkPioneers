extends "res://tests/live_seamstress_pool_bleed_hand_test.gd"
## True mounted-hand regression for both V3 Blanket of Barbs printings.
const BARBS := ["seamstress_v3_blanket_of_barbs", "seamstress_v3_blanket_of_barbs_plus"]

func _gauge() -> CombatUnravel:
	var preview = app.get_node_or_null("LiveAttackPreview")
	return preview._unravel if preview != null else null

func _complete_state() -> Array:
	var state := _state()
	var gauge := _gauge()
	state.append(gauge._gauges.duplicate(true) if gauge != null else {})
	state.append(app.round_flow._unravel if app.round_flow != null else null)
	return state

func _assert_no_change(before: Array, reason: String) -> void:
	_check(_complete_state() == before and adapter._pending.is_empty(),
		reason + " leaves piles, energy, parties, enemies, gauge, gold and both RNGs untouched")

func _cast(card_id: String, keyboard: bool, rear: bool) -> void:
	if not await _start(card_id):
		await _return()
		return
	var gauge := _gauge()
	var panel := _panel(card_id)
	_check(gauge != null and gauge._bound_enemies == app.enemies
		and app.round_flow != null and app.round_flow._enemies == app.enemies,
		"real fight admits a gauge bound to its original enemy roster")
	if gauge == null or panel == null:
		await _return()
		return
	if rear:
		var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, 1)
		_check(swap.get("ok", false), "real adjacent swap permits Seamstress to occupy rear seat")
		if swap.get("ok", false):
			app.party._heroes.assign(swap.heroes)
			app._refresh_party()
			await _frames()
	var owner := 3 if rear else 2
	_check(app.party.get_hero(owner).id == "seamstress"
		and app.party.get_hero(owner).hp > 0,
		"living Seamstress truly occupies the printed source seat")
	var definition := V3SeamstressPoolCards.new().get_definition(card_id)
	var bleed := int(definition.effects.bleed) + 1
	var unravel := int(definition.effects.unravel)
	var face: Dictionary = adapter.face_text(panel)
	_check(adapter._bindings.has(panel) and face.get("name") == definition.display_name
		and face.get("effect", "").contains("Bleed %d" % bleed)
		and face.get("effect", "").contains("Unravel %d" % unravel)
		and panel.tooltip_text.contains("no target choice"),
		"genuine held printing is visibly mounted as a target-free paid card")
	_check(definition.cost == 2 and definition.from_positions == [2, 3]
		and definition.to_positions == [1, 2, 3],
		"canonical printing authorizes only the two rear seats and original enemy 1-3")
	_check(gauge.apply_unravel(app.enemies, 1, 7), "real original slot one is precharged to seven")
	var before := _complete_state()
	var callback: Callable = adapter._bindings[panel].callback
	if keyboard:
		panel.grab_focus()
		_check(panel.has_focus(), "physical keyboard can focus held Blanket")
		await _keyboard(KEY_ENTER if rear else KEY_SPACE)
	else:
		await _mouse(panel)
	_check(adapter.last_event.get("ok", false) and adapter.last_event.get("card_id") == card_id
		and adapter.last_event.get("targets") == [1, 2], "one accepted paid receipt names only the living original slots")
	_check(app.deck.energy == int(before[3]) - 2 and app.deck.discard_pile.count(card_id) == 1
		and app.deck.hand.count(card_id) == int((before[1] as Array).count(card_id)) - 1,
		"exactly two energy and one held copy are charged and discarded once")
	_check(app.deck.draw_pile == before[0] and app.party.get_heroes() == before[5]
		and app.session_gold == before[13] and app.run_rng.state == before[11]
		and app.deck._rng.state == before[14], "successful sweep leaves other resources and RNG fixed")
	for position in [1, 2]:
		var prior: Dictionary = before[6][position - 1]
		var actual: Dictionary = app.enemies.get_enemy(position)
		var expected := prior.duplicate(true)
		if not expected.has("statuses"):
			expected["statuses"] = {}
		expected["statuses"]["bleed"] = int(expected["statuses"].get("bleed", 0)) + bleed
		_check(actual == expected and _chip_shows(position, "bleed", bleed),
			"real enemy %d receives exactly the printed plus passive Bleed and its ribbon updates" % position)
		var gauge_before: Dictionary = before[16][position]
		var expected_gauge := mini(int(gauge_before.gauge) + unravel, int(gauge_before.threshold))
		_check(gauge.get_snapshot(position).gauge == expected_gauge,
			"same roster gauge receives exactly printed Unravel for enemy %d" % position)
	_check(gauge.get_snapshot(1).skip_pending and gauge.get_snapshot(1).unravelled,
		"crossing the normal threshold queues exactly one real turn skip")
	_check(app.round_flow._unravel == gauge, "mounted end-turn flow shares the identical gauge instance")
	var after := _complete_state()
	callback.call(_press())
	await _frames()
	_check(_complete_state() == after, "duplicate old callback cannot charge or bleed twice")
	var prior_hp := int(app.enemies.get_enemy(1).hp)
	app.end_turn_button.pressed.emit()
	await _frames()
	var after_skip := gauge.get_snapshot(1)
	_check(after_skip.threshold == 12 and not after_skip.skip_pending
		and not after_skip.unravelled and after_skip.gauge >= 0,
		"real End Turn consumes exactly one skip and raises the original threshold to twelve")
	_check(app.enemies.get_enemy(1).hp <= prior_hp
		and app.enemy_intents._turn_index > 0 and app.deck.turn_active,
		"real battle progresses to the next player turn after the skipped enemy action")
	await _return()

func _routed_original_slots() -> void:
	var fixture := _three_enemy_fixture()
	_check(not fixture.is_empty(), "genuine seeded map has an authored three-foe Fight")
	if fixture.is_empty():
		return
	app.run_seed = int(fixture.seed)
	app.start_button.pressed.emit()
	preload("res://tests/party_choice.gd").choose(app)
	await _frames()
	var route: Button
	for candidate in app.route_buttons:
		if candidate.get_meta("route_id") == fixture.fight:
			route = candidate
			break
	_check(route != null and not route.disabled, "genuine route action is available")
	if route == null:
		await _return()
		return
	route.pressed.emit()
	await _frames()
	if app.party != null and app.party.get_hero(2).id == "seamstress":
		var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, 1)
		_check(swap.ok, "authentic adjacent swap supplies a rear Seamstress")
		if swap.ok:
			app.party._heroes.assign(swap.heroes)
			app._refresh_party()
			await _frames()
	_check(app.deck != null and app.enemies != null and app.enemies.get_enemies().size() == 3
		and app.party.get_hero(3).id == "seamstress",
		"real routed encounter has three original foes and a rear Seamstress")
	if app.deck == null or app.enemies == null or app.enemies.get_enemies().size() != 3:
		await _return()
		return
	var card_id: String = BARBS[1]
	_check(app.enemies.apply_damage(2, 10000) and app.enemies.is_slain(2),
		"the genuine middle original enemy is slain before casting")
	app.deck.draw_pile.append(card_id)
	_check(app.deck.draw_extra(1) == 1, "routed deck draws authentic upgraded printing")
	app._refresh_hand()
	app._refresh_enemy_roster()
	await _frames()
	var panel := _panel(card_id)
	var gauge := _gauge()
	_check(panel != null and gauge != null and gauge._bound_enemies == app.enemies,
		"upgraded printing is genuinely held with the routed shared gauge")
	if panel == null or gauge == null:
		await _return()
		return
	var prior: Array = app.enemies.get_enemies()
	var gauges := gauge._gauges.duplicate(true)
	await _mouse(panel)
	_check(adapter.last_event.get("ok", false) and adapter.last_event.get("targets") == [1, 3],
		"paid cast targets living original 1 and 3 and never compacts slain slot 2")
	for position in [1, 2, 3]:
		var target: Dictionary = app.enemies.get_enemy(position)
		if position == 2:
			_check(target == prior[1] and gauge.get_snapshot(2) == gauges[2],
				"slain original middle slot has neither added Bleed nor Unravel")
		else:
			_check(int(target.get("statuses", {}).get("bleed", 0)) ==
				int(prior[position - 1].get("statuses", {}).get("bleed", 0)) + 4
				and gauge.get_snapshot(position).gauge == int(gauges[position].gauge) + 3,
				"living original target %d receives exactly Bleed 4 and Unravel 3" % position)
	# A fabricated fourth enemy is not a supported live CombatEnemies roster:
	# the printed TO line stops at three; no fourth-slot effect is ever fabricated.
	_check(CombatEnemies.MAX_ENEMIES == 3
		and CombatSeamstressV3BlanketCards.TO_POSITIONS == [1, 2, 3]
		and adapter.last_event.targets == [1, 3],
		"fourth slot is outside both the authentic combat roster and printed effect")
	await _return()

func _refusals() -> void:
	var card_id: String = BARBS[0]
	for kind in ["missing_gauge", "foreign_gauge", "downed", "front", "unaffordable",
			"unheld", "foreign_session", "stale_turn"]:
		if not await _start(card_id):
			await _return()
			continue
		var panel := _panel(card_id)
		var callback: Callable = adapter._bindings[panel].callback
		var preview = app.get_node("LiveAttackPreview")
		var true_gauge: CombatUnravel = preview._unravel
		match kind:
			"missing_gauge":
				preview._unravel = null
			"foreign_gauge":
				var other := CombatEnemies.new([{"id":"other", "max_hp":10}])
				var foreign := CombatUnravel.new()
				_check(foreign.bind_roster(other, {1:"normal"}), "foreign gauge genuinely binds another roster")
				preview._unravel = foreign
			"downed":
				_check(app.party.apply_damage(2, 10000) and app.party.is_downed(2),
					"real owner is downed, not an absent fixture")
			"front":
				var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, -1)
				_check(swap.ok, "real party can present an illegal front Seamstress")
				app.party._heroes.assign(swap.heroes)
				app._refresh_party()
				app._refresh_intents()
				await _frames()
			"unaffordable":
				app.deck.combat_state.energy = 1
			"unheld":
				app.deck.hand.erase(card_id)
			"foreign_session":
				app.party = CombatParty.new(app._load_party_definitions())
			"stale_turn":
				callback.call(_press())
				_check(not adapter._pending.is_empty(), "genuine pending receipt exists before turn expires")
				_check(app.deck.end_turn(), "the real turn ends before deferred dispatch")
		var before := _complete_state()
		if kind != "stale_turn":
			callback.call(_press())
		await _frames()
		_assert_no_change(before, kind)
		if kind in ["missing_gauge", "foreign_gauge"]:
			preview._unravel = true_gauge
		await _return()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	_check(app != null, "real mounted app scene is available")
	if app == null:
		_finish()
		return
	root.add_child(app)
	await _frames()
	adapter = app.get_node_or_null("LiveAreaAttackAction")
	_check(adapter != null and app.deck == null, "adapter starts inert on real title")
	for card_id in BARBS:
		_check(CombatSeamstressV3BlanketCards.new().is_supported_card(card_id)
			and not V3SeamstressPoolCards.new().get_definition(card_id).is_empty(),
			"both exact canonical printings are authenticated before testing")
	await _cast(BARBS[0], false, false)
	await _cast(BARBS[1], true, true)
	await _routed_original_slots()
	await _refusals()
	app.free()
	_finish()

func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_v3_seamstress_blanket_hand_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
