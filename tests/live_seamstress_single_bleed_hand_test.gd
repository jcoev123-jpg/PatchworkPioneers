extends SceneTree
## Real app/held-hand target strip tests against the independent D2-1 resolver.

const IDS := [
	"seamstress_running_stitch", "seamstress_running_stitch_plus",
	"seamstress_hemorrhage_hem", "seamstress_hemorrhage_hem_plus",
	"seamstress_red_thread", "seamstress_red_thread_plus",
]
var catalog := SeamstressPoolCards.new()
var checks := 0
var failures: Array[String] = []
var app
var adapter


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures.append(reason)


func _frames() -> void:
	for i in range(4):
		await process_frame


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.pressed = pressed
		root.push_input(e, true)
	await _frames()


func _hover(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await _frames()


func _outcome_text(forecast: Dictionary) -> String:
	if not forecast.get("ok", false):
		return ""
	var now := "Now: 0 damage"
	if forecast.damage > 0:
		now = "Now: %d damage (%d Block, %d HP)" % [
			forecast.damage, forecast.block_absorbed, forecast.hp_loss]
	var message := "%s  |  Bleed: %d -> %d (future)" % [
		now, forecast.bleed_before, forecast.bleed_after]
	if forecast.exposed_before != forecast.exposed_after:
		message += "\nExposed: %d -> %d" % [
			forecast.exposed_before, forecast.exposed_after]
	return message


func _preview_at(id: String, position: int, state_before: Array) -> void:
	var forecast := CombatSeamstressPoolBleed.new().forecast_single(
		app.deck, app.party, app.enemies, id, position)
	var label := adapter.target_strip.find_child("OutcomePreview", true, false) as Label
	_check(forecast.get("ok", false) and label != null,
		"real held card has pure forecast and mounted embroidered outcome")
	if not forecast.get("ok", false) or label == null:
		return
	_check(label.text == _outcome_text(forecast)
		and label.text.contains("future") and label.is_visible_in_tree(),
		"mounted target %d shows exact future Bleed separate from immediate hit: %s" % [position, id])
	_check(label.get_global_rect().position.x >= 0
		and label.get_global_rect().end.x <= root.size.x
		and label.get_global_rect().end.y <= root.size.y
		and label.get_global_rect().position.y >= 0,
		"preview and target controls stay in the 1280x720 viewport")
	_check(_state() == state_before and not adapter._choice.get("queued", false),
		"focus/hover forecast is transaction-free, RNG-free and latch-free")


func _mouse(control: Control) -> void:
	if not is_instance_valid(control):
		_check(false, "mouse recipient still exists")
		return
	var point := control.get_global_rect().get_center()
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).has_point(point),
		"physical pointer is within 1280x720")
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = point
		e.pressed = pressed
		root.push_input(e, true)
		if pressed:
			root.push_input(e, true)
	await _frames()


func _press() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	return event


func _panel(id: String) -> Control:
	if not is_instance_valid(app.hand_view):
		return null
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0) is Label 				and panel.get_child(0).text == id:
			return panel
	return null


func _state() -> Array:
	return [app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.party.get_heroes(), app.enemies.get_enemies(), app.run_rng.seed,
		app.run_rng.state, app.deck._rng.state, app.enemy_intents.get_intents(),
		app.enemy_intents._turn_index, app.enemy_attacks.duplicate(true),
		app.intent_label.text, app.battle_result.get_outcome(),
		app.session_gold, app._battle_closed]


func _oracle(id: String, before: Array, position: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(before[7])
	rng.state = int(before[8])
	var deck := CombatDeck.new([], rng)
	deck.draw_pile.assign(before[0])
	deck.hand.assign(before[1])
	deck.discard_pile.assign(before[2])
	deck.combat_state.energy = int(before[3])
	deck.combat_state.player_turn_active = bool(before[4])
	var party := CombatParty.new(app._load_party_definitions())
	party._heroes.assign((before[5] as Array).duplicate(true))
	var definitions: Array[Dictionary] = []
	for enemy in before[6]:
		definitions.append({"id": String(enemy.id), "max_hp": int(enemy.max_hp)})
	var enemies := CombatEnemies.new(definitions)
	enemies._enemies.assign((before[6] as Array).duplicate(true))
	var result: Dictionary = CombatSeamstressPoolBleed.new().play_card(
		deck, party, enemies, id, position)
	return {"result": result, "draw": deck.draw_pile, "hand": deck.hand,
		"discard": deck.discard_pile, "energy": deck.energy,
		"heroes": party.get_heroes(), "enemies": enemies.get_enemies(),
		"rng": rng.state, "turn": deck.turn_active}


func _start(id: String) -> bool:
	_check(app.deck == null, "start from a fresh real title state")
	app.run_seed = 42
	_check(app._start_battle(), "real mounted battle starts")
	await _frames()
	var ready: bool = app.deck != null and app.party != null 		and app.enemies != null and app.battle_result != null 		and app.run_rng != null and is_instance_valid(app.hand_view) 		and app.deck.turn_active and app.deck.energy == 3
	_check(ready, "seeded active deck and real battle exist")
	if not ready:
		return false
	app.deck.draw_pile.append(id)
	_check(app.deck.draw_extra(1) == 1, "authored card is drawn from the real combat deck")
	app._refresh_hand()
	await _frames()
	var panel := _panel(id)
	_check(panel != null and adapter._bindings.has(panel),
		"held authored card has one mounted input binding: " + id)
	return panel != null and adapter._bindings.has(panel)


func _return() -> void:
	if is_instance_valid(app.return_button):
		app.return_button.pressed.emit()
	await _frames()
	_check(adapter._bindings.is_empty() and adapter._battle == null 		and adapter._choice.is_empty() and adapter.target_strip == null
		and adapter._preview == null,
		"Return releases every binding, target strip and forecast")


func _face(id: String) -> void:
	var panel := _panel(id)
	var metadata = app.get_node("LiveSupportHand")._metadata
	var face: Dictionary = metadata.describe(id)
	var definition: Dictionary = catalog.get_definition(id)
	_check(panel != null and panel.is_visible_in_tree(), "real held panel is visible")
	_check(face.get("display_name") == definition.get("display_name")
		and face.get("cost") == definition.get("cost")
		and face.get("from_text") == "From " + metadata._positions(definition.from_positions)
		and String(face.get("target_text", "")).contains("enemy"),
		"shared decorated hand face has catalog name, +, cost, From and enemy target")
	_check(panel.gui_input.get_connections().size() == 1 		and panel.focus_mode == Control.FOCUS_ALL 		and panel.mouse_filter == Control.MOUSE_FILTER_STOP 		and panel.tooltip_text.contains(str(definition.display_name)),
		"single mounted callback and complete legible face tooltip")


func _arm(id: String, keyboard: bool) -> void:
	var panel := _panel(id)
	if keyboard:
		panel.grab_focus()
		_check(panel.has_focus(), "keyboard focuses held card")
		await _key(KEY_ENTER)
	else:
		await _mouse(panel)
	_check(adapter._choice.get("id") == id 		and is_instance_valid(adapter.target_strip) 		and adapter.target_strip.is_visible_in_tree(),
		"held input arms visible real target strip")
	if adapter.target_strip == null:
		return
	var definition: Dictionary = catalog.get_definition(id)
	var heading := adapter.target_strip.find_child("Rule", true, false) as Label
	_check(heading != null and heading.text.contains(str(definition.display_name))
		and heading.text.contains("Cost %d" % definition.cost)
		and heading.text.contains("From 1,2,3")
		and heading.text.contains("One living enemy 1,2,3"),
		"stitched strip spells the authored cost, from and target positions")
	_check(adapter.target_strip.size.x >= 550 		and adapter.target_strip.get_global_rect().end.x <= root.size.x,
		"stitched strip is readable within the viewport")


func _success(id: String, position: int, before: Array, mode: String) -> void:
	var definition: Dictionary = catalog.get_definition(id)
	var oracle := _oracle(id, before, position)
	_check(oracle.result.ok and oracle.result.hits.size() == 1 		and oracle.result.hits[0].position == position,
		"independent resolver returns exactly one original selected enemy: " + id)
	_check(adapter.last_event == oracle.result, "mounted event matches independent resolver: " + id)
	_check(app.deck.draw_pile == oracle.draw and app.deck.hand == oracle.hand 		and app.deck.discard_pile == oracle.discard and app.deck.energy == oracle.energy 		and app.party.get_heroes() == oracle.heroes 		and app.enemies.get_enemies() == oracle.enemies,
		"complete mounted state equals independent D2-1 resolver: " + id)
	_check(app.deck._rng.state == oracle.rng and app.run_rng.state == before[8],
		"mounted cast never advances the actual seeded run/deck RNG: " + id)
	_check(app.deck.energy == int(before[3]) - int(definition.cost) 		and app.deck.discard_pile.count(id) == int(before[2].count(id)) + 1 		and app.deck.hand.count(id) == int(before[1].count(id)) - 1,
		"exact authored cost and one discarded held copy: " + id)
	_check(app.enemy_intents.get_intents() == before[10] 		and app.enemy_intents._turn_index == before[11] 		and app.enemy_attacks == before[12] and app.intent_label.text == before[13] 		and app.session_gold == before[15],
		"intent, turn, attacks and wallet unchanged: " + id)
	_check(app.battle_result.get_outcome() == before[14] 		and app.result_label.visible == app.battle_result.is_finished() 		and adapter._choice.is_empty() and adapter.target_strip == null,
		"battle result observed and target strip retired: " + id)
	var ids: Array[String] = []
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0) is Label:
			ids.append(panel.get_child(0).text)
	_check(ids == app.deck.hand and app.pile_label.text == "Draw: %d | Discard: %d" % [
		app.deck.draw_pile.size(), app.deck.discard_pile.size()],
		"mounted hand and piles refresh after " + mode + " cast: " + id)
	_check(app.get_node("LiveSupportHand").energy_label.text == str(app.deck.energy),
		"shared energy display refreshes: " + id)
	_check(app._quilt_hand_snapshot == app.deck.hand
		and app._quilt_draw_snapshot == app.deck.draw_pile
		and app._quilt_discard_snapshot == app.deck.discard_pile,
		"quilt observer reconciles the same real played-card receipt: " + id)
	var meters = app.get_node("LiveCombatMeters")
	_check(meters != null and is_instance_valid(meters.row)
		and meters.row.get_child_count() == 3 + app.enemies.get_enemies().size(),
		"mounted combat ribbons still cover all original actors: " + id)
	if meters != null and is_instance_valid(meters.row):
		var meter = meters.row.get_child(2 + position)
		var model: Dictionary = app.enemies.get_enemy(position)
		_check(meter.hp_text.text == "%d/%d" % [model.hp, model.max_hp]
			and meter.hp_bar.value == model.hp,
			"selected enemy HP meter reflects authoritative post-hit state: " + id)
	var effect: Dictionary = definition.effects
	var from_enemy: Dictionary = before[6][position - 1]
	var after_enemy: Dictionary = app.enemies.get_enemy(position)
	var old_bleed: int = int(from_enemy.get("statuses", {}).get("bleed", 0))
	var new_bleed: int = int(after_enemy.get("statuses", {}).get("bleed", 0))
	if effect.has("bleed_multiplier"):
		_check(new_bleed == old_bleed * 2, "Hem doubles CURRENT Bleed without passive: " + id)
	else:
		_check(new_bleed == old_bleed + int(effect.bleed) + 1,
			"printed Bleed plus exactly one Seamstress passive: " + id)
	if effect.has("exposed"):
		_check(int(after_enemy.get("statuses", {}).get("exposed", 0)) 			== int(from_enemy.get("statuses", {}).get("exposed", 0)) + 1,
			"Red Thread grants one Exposed: " + id)
	for enemy in before[6]:
		if int(enemy.position) != position:
			_check(app.enemies.get_enemy(int(enemy.position)) == enemy,
				"nonselected enemy slot remains identical: " + id)


func _play(id: String, mode: String, zero_bleed: bool = false) -> void:
	if not await _start(id):
		await _return()
		return
	_face(id)
	# Authoritative combat state: Weak on the attacking Seamstress, enemy Block
	# and Exposed. Hem's '+' additionally verifies 0 -> 0.
	app.party._heroes[1]["statuses"] = {"weak": 1}
	if not zero_bleed:
		_check(app.enemies.apply_statuses({1: {"bleed": 3, "exposed": 1}}),
			"live enemy carries existing Bleed and Exposed")
	_check(app.enemies.gain_block(1, 2), "live enemy has Block")
	_check(app.enemies.apply_statuses({2: {"bleed": 1}})
		and app.enemies.gain_block(2, 1),
		"second genuine enemy has a distinct Block/Bleed profile")
	app._refresh_enemy_roster()
	var before := _state()
	var panel := _panel(id)
	var callback: Callable = adapter._bindings[panel].callback
	await _arm(id, mode != "mouse")
	if adapter.target_strip == null:
		await _return()
		return
	var first_forecast: Dictionary = CombatSeamstressPoolBleed.new().forecast_single(
		app.deck, app.party, app.enemies, id, 1)
	_check(adapter._targets.has(1) and adapter._targets.has(2),
		"two original targets are live and actionable")
	_preview_at(id, 1, before)
	var button: Button = adapter._targets[1]
	await _hover(adapter._targets[2])
	_preview_at(id, 2, before)
	await _hover(button)
	button.grab_focus()
	await _frames()
	_preview_at(id, 1, before)
	_check(first_forecast.get("ok", false) and first_forecast.position == 1,
		"before-commit selected enemy forecast has the original slot")
	if mode == "mouse":
		await _mouse(button)
	else:
		# Focus is granted to the first living target; Tab can visit the next
		# and Shift/explicit focus can return to the selected first position.
		_check(button.has_focus(), "keyboard starts at first living enemy target")
		await _key(KEY_TAB)
		_check(adapter._targets[2].has_focus(), "Tab traverses stitched enemy slots")
		_preview_at(id, 2, before)
		button.grab_focus()
		await _frames()
		_preview_at(id, 1, before)
		await _key(KEY_ENTER if mode == "enter" else KEY_SPACE)
	_success(id, 1, before, mode)
	_check(adapter._preview == null and adapter.target_strip == null,
		"committed choice clears prior mounted projection")
	var after := _state()
	callback.call(_press())
	await _frames()
	_check(_state() == after, "captured spent-panel callback is stale and mutation-free: " + id)
	await _return()


func _cancel_and_reject() -> void:
	var id := IDS[0]
	if await _start(id):
		var before := _state()
		await _arm(id, false)
		await _key(KEY_ESCAPE)
		_check(_state() == before and adapter._choice.is_empty() 			and adapter.target_strip == null and adapter._targets.is_empty()
			and adapter._preview == null,
			"Escape cancels without any mutation or stale preview")
		await _return()
	# All six share legal source positions 1..3; a fourth position is illegal.
	for reason in ["wrong_source", "downed", "energy", "inactive", "hidden"]:
		if not await _start(id):
			break
		match reason:
			"wrong_source":
				app.party._heroes[1]["position"] = 4
			"downed":
				_check(app.party.apply_damage(2, 10000), "owner really downed")
			"energy":
				app.deck.combat_state.energy = 0
			"inactive":
				app.deck.combat_state.player_turn_active = false
			"hidden":
				app.battle_view.hide()
		var before := _state()
		var panel := _panel(id)
		var callback: Callable = adapter._bindings[panel].callback
		callback.call(_press())
		await _frames()
		_check(_state() == before and adapter._choice.is_empty(),
			"invalid %s has no choice, spend or RNG change" % reason)
		if reason == "hidden":
			app.battle_view.show()
		await _return()
	# An active target selection becomes stale on an altered hand, energy or
	# roster, and a duplicate/cancelled or wrong target never replays.
	for reason in ["hand", "energy", "roster", "wrong_target", "duplicate"]:
		if not await _start(id):
			break
		await _arm(id, false)
		if adapter.target_strip == null:
			await _return()
			continue
		var before := _state()
		var callback: Callable = adapter._targets[1].pressed.get_connections()[0].callable
		match reason:
			"hand":
				app.deck.hand.append("seamstress_red_thread")
			"energy":
				app.deck.combat_state.energy = 0
			"roster":
				app.enemies.apply_damage(1, 1)
			"wrong_target":
				adapter._on_target_pressed(99, "forged", adapter._token)
				_check(_state() == before and not adapter._choice.get("queued", false),
					"a non-roster target cannot queue a cast")
				adapter._cancel()
			"duplicate":
				await _key(KEY_ESCAPE)
		var changed := _state()
		if reason != "duplicate":
			callback.call()
		await _frames()
		_check(_state() == changed and adapter.last_event.is_empty()
			and adapter.target_strip == null and adapter._preview == null,
			"stale %s choice cannot mutate or retain outcome" % reason)
		await _return()
	# A valid queued choice invalidated by turn-end must not commit.
	if await _start(id):
		await _arm(id, true)
		var callback: Callable = adapter._targets[1].pressed.get_connections()[0].callable
		callback.call()
		_check(adapter._choice.get("queued", false), "a genuine target queues one commit")
		_check(app.deck.end_turn(), "the real player turn ends before deferred commit")
		var before := _state()
		await _frames()
		_check(_state() == before and adapter._choice.is_empty()
			and adapter.target_strip == null and adapter._preview == null,
			"queued stale turn rejects and clears outcome before any cast")
		await _return()
	# Returning with an armed choice disconnects the strip and callbacks.
	if await _start(id):
		await _arm(id, false)
		var old_deck: CombatDeck = app.deck
		var old_party: CombatParty = app.party
		var old_enemies: CombatEnemies = app.enemies
		var before := _state()
		var callback: Callable = adapter._bindings[_panel(id)].callback
		await _return()
		callback.call(_press())
		await _frames()
		_check(old_deck.hand == before[1] and old_party.get_heroes() == before[5] 			and old_enemies.get_enemies() == before[6],
			"stale Return callback preserves every old session model")


## Last-hit resolution must also take the existing terminal/reward path, not
## merely refresh active battle labels.
func _terminal_case() -> void:
	var id := "seamstress_running_stitch"
	if not await _start(id):
		await _return()
		return
	var first: Dictionary = app.enemies.get_enemy(1)
	var second: Dictionary = app.enemies.get_enemy(2)
	_check(first.hp > 1 and second.hp > 0, "real terminal fixture starts with two living enemies")
	_check(app.enemies.apply_damage(1, first.hp - 1)
		and app.enemies.apply_damage(2, second.hp),
		"real roster APIs leave a one-HP final target")
	app._refresh_enemy_roster()
	await _arm(id, true)
	_check(adapter._targets.has(1) and not adapter._targets.has(2),
		"final living enemy is the only legal original slot")
	if adapter._targets.has(1):
		await _key(KEY_ENTER)
		_check(app.battle_result.get_outcome() == CombatBattleResult.VICTORY
			and app._battle_closed and app.end_turn_button.disabled,
			"final Running Stitch damage drives the real terminal victory gate")
		_check(app.result_label.is_visible_in_tree()
			and app.result_label.text.begins_with("Battle result: " + CombatBattleResult.VICTORY),
			"actual battle result label is refreshed at terminal resolution")
		_check(app.reward_buttons.size() == 4
			and app.hand_view.get_child_count() == 1
			and app.hand_view.get_child(0).name == "CardReward",
			"real terminal reward replaces the discarded hand")
		_check(adapter._choice.is_empty() and adapter.target_strip == null,
			"terminal event retires target controls and their queued receipts")
	await _return()


func _three_enemy_case() -> void:
	var candidate := {}
	for value in range(1, 1025):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		var start_state: int = rng.state
		for node_id in map.get_legal_choices():
			if map.get_node(node_id).get("type") != "Fight":
				continue
			rng.state = start_state
			if not map.choose_node(node_id):
				continue
			var picked := RunAuthoredBattleEntry.new().entry_current_battle(
				map, rng, RunFightEncounterSelection.new())
			map.undo_choice(node_id, [])
			if picked.get("success", false) 					and picked["enemies"].get_enemies().size() == 3:
				candidate = {"seed": value, "id": node_id}
				break
		if not candidate.is_empty():
			break
	_check(not candidate.is_empty(), "authored routed Fight with three original enemy slots exists")
	if candidate.is_empty():
		return
	app.run_seed = int(candidate.seed)
	app.start_button.pressed.emit()
	preload("res://tests/party_choice.gd").choose(app)
	await _frames()
	var route: Button
	for button in app.route_buttons:
		if button.get_meta("route_id") == candidate.id:
			route = button
	_check(route != null and not route.disabled, "routed Fight available through real route control")
	if route == null:
		return
	route.pressed.emit()
	await _frames()
	_check(app.enemies != null and app.enemies.get_enemies().size() == 3,
		"real routed roster has three original positions")
	if app.enemies == null or app.enemies.get_enemies().size() != 3:
		return
	_check(app.enemies.apply_damage(2, 100000) and app.enemies.is_slain(2),
		"middle original enemy position slain")
	app._refresh_enemy_roster()
	var id := IDS[5]
	app.deck.draw_pile.append(id)
	_check(app.deck.draw_extra(1) == 1, "routed deck draws Red Thread+")
	app._refresh_hand()
	await _frames()
	var before := _state()
	await _arm(id, false)
	_check(adapter._targets.has(1) and not adapter._targets.has(2) 		and adapter._targets.has(3),
		"only living original positions 1 and 3 are targetable")
	var strip = adapter.target_strip
	var slain = strip.find_child("Enemy2", true, false) as Button if strip != null else null
	_check(slain != null and slain.disabled and String(slain.text).contains("Slain"),
		"slain middle slot is visibly disabled, not compacted")
	if adapter._targets.has(3):
		await _hover(adapter._targets[3])
		_preview_at(id, 3, before)
		await _mouse(adapter._targets[3])
		_success(id, 3, before, "routed outer slot mouse")
	await _return()


func _route_action(id: String) -> Button:
	for button in app.route_buttons:
		if button.get_meta("route_id") == id:
			return button
	return null


func _quick_fight_fixture() -> Dictionary:
	for value in range(1, 300):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for first in map.get_legal_choices():
			if map.get_node(first).type != "Fight":
				continue
			for next in map.get_node(first).outgoing:
				if map.get_node(next).type != "Fight":
					continue
				map.choose_node(first)
				var entry := RunAuthoredBattleEntry.new().entry_current_battle(
					map, rng, RunFightEncounterSelection.new())
				if entry.get("encounter_id") == "starter_attacks":
					return {"seed": value, "fight": first, "next_fight": next}
				map.undo_choice(first, [])
	return {}


func _test_mounted_worn_patches() -> void:
	var fixture := _quick_fight_fixture()
	_check(not fixture.is_empty(), "mounted patch test: found connected Fight fixture")
	if fixture.is_empty():
		return

	app.run_seed = fixture.seed
	app.route_button.pressed.emit()
	await _frames()

	var first_btn := _route_action(fixture.fight)
	_check(first_btn != null and not first_btn.disabled, "opening fight button found")
	if first_btn == null:
		return
	first_btn.pressed.emit()
	await _frames()

	_check(app.deck != null and app.party.is_valid(), "predecessor fight started")
	for enemy in app.enemies.get_enemies():
		app.enemies.apply_damage(enemy.position, 9999)
	app._observe_battle_result()
	await _frames()
	_check(app.battle_result.get_outcome() == CombatBattleResult.VICTORY
		and app.reward_buttons.size() == 4, "predecessor victory settled")
	if app.reward_buttons.size() != 4:
		return

	app.reward_buttons[3].pressed.emit()
	await _frames()
	app.continue_button.pressed.emit()
	await _frames()

	_check(app.route_view != null and app.route_view.is_visible_in_tree()
		and app.party_carryover is RunTornCarryover, "connected route chooser open")
	if app.route_view == null:
		return

	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_attack_patches.json"))
	var definitions: Array[Dictionary] = []
	var owned: Array = []
	for entry in records:
		if entry is Dictionary and entry.get("id") in ["button_eye", "pincushion_arm"]:
			var slot: String = "HEAD" if entry.id == "button_eye" else "ARM"
			definitions.append({"id": entry.id, "slot": slot})
			owned.append(entry.id)
	var coats: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_coat_patches.json"))
	if coats is Array and RunPatchCoatRules._valid_authored(coats):
		definitions.append({"id": RunPatchCoatRules.BONUS_ID, "slot": "COAT"})
		owned.append(RunPatchCoatRules.BONUS_ID)
	for id in owned:
		app.run_trinkets.append(id)
	var carry := app.party_carryover as RunTornCarryover
	_check(carry != null and carry.is_valid() and carry.torn.is_valid(),
		"carryover valid before next fight")
	var wardrobe := RunPatchWardrobe.new(app.run_heroes, app.run_trinkets,
		definitions, app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
	_check(wardrobe.is_valid(), "wardrobe valid")
	var expected := wardrobe.get_snapshot()
	var sew1 := wardrobe.sew("button_eye", "seamstress", "HEAD", "sew_head", expected)
	expected = wardrobe.get_snapshot()
	var sew2 := wardrobe.sew("pincushion_arm", "seamstress", "ARM", "sew_arm", expected)
	expected = wardrobe.get_snapshot()
	_check(sew1.ok and sew2.ok, "sew button_eye and pincushion_arm to seamstress")
	_check(carry.can_bind_wardrobe(wardrobe, carry.torn, expected)
		and carry.bind_wardrobe(wardrobe, carry.torn, expected),
		"bind wardrobe to live carryover")

	var next_btn := _route_action(fixture.next_fight)
	_check(next_btn != null and not next_btn.disabled, "next fight button found")
	if next_btn == null:
		return
	next_btn.pressed.emit()
	await _frames()

	_check(app.route_view == null and app.battle_view.is_visible_in_tree()
		and app.party.is_valid() and app.deck != null,
		"second fight mounted successfully")

	# AC3: Verifies adapter bound ONE combat-long patch authority
	_check(adapter._service._patches != null and adapter._service._patches.is_valid(),
		"mounted adapter resolver bound ONE patch authority on session entry")
	var patches: CombatPatchAttackRules = adapter._service._patches
	_check(patches.damage_bonus("seamstress") == 1, "Pincushion Arm active on Seamstress")
	_check(patches.exposed_for_first_hit("seamstress") == {"exposed": 1}, "Button Eye active on Seamstress")
	_check(patches.latch_snapshot().get("seamstress") == false, "Button Eye latch unconsumed at start")

	# Held Running Stitch
	var id := "seamstress_running_stitch"
	app.deck.draw_pile.append(id)
	_check(app.deck.draw_extra(1) == 1, "draw running stitch")
	app._refresh_hand()
	await _frames()
	var panel := _panel(id)
	_check(panel != null and adapter._bindings.has(panel), "running stitch panel bound")

	# Target selection and forecast parity
	await _arm(id, false)
	_check(adapter.target_strip != null and is_instance_valid(adapter.target_strip),
		"target strip visible")
	var target_pos := 1
	for enemy in app.enemies.get_enemies():
		if enemy.hp > 10:
			target_pos = enemy.position
			break
	_check(adapter._targets.has(target_pos), "target button available")
	var target_btn: Button = adapter._targets[target_pos]
	await _hover(target_btn)
	var label := adapter.target_strip.find_child("OutcomePreview", true, false) as Label
	_check(label != null and label.text.contains("3 damage"),
		"forecast shows patched damage 3 (2 base + 1 Pincushion)")
	_check(label != null and label.text.contains("Exposed: 0 -> 1"),
		"forecast shows Button Eye Exposed 0 -> 1")
	_check(patches.latch_snapshot().get("seamstress") == false,
		"preview pure reads leave latch unconsumed")

	# Mouse commit for first attack
	var enemy1_before: Dictionary = app.enemies.get_enemy(target_pos)
	await _mouse(target_btn)
	await _frames()

	var event: Dictionary = adapter.last_event
	_check(event.get("ok", false) and event.hits.size() == 1, "commit succeeded")
	var hit: Dictionary = event.hits[0]
	_check(hit.damage == 3, "actual hit dealt patched 3 damage")
	_check(hit.statuses == {"bleed": 4, "exposed": 1}, "actual hit applied Bleed 4 and Exposed 1")
	var enemy1_after: Dictionary = app.enemies.get_enemy(target_pos)
	_check(enemy1_after.get("statuses", {}).get("exposed", 0) ==
		enemy1_before.get("statuses", {}).get("exposed", 0) + 1,
		"enemy received Exposed 1")
	_check(enemy1_after.get("statuses", {}).get("bleed", 0) ==
		enemy1_before.get("statuses", {}).get("bleed", 0) + 4,
		"enemy received Bleed 4 (3 + 1 passive)")
	_check(patches.latch_snapshot().get("seamstress") == true,
		"Button Eye latch is consumed after first hit")

	# Check combat ribbons
	var meters = app.get_node("LiveCombatMeters")
	_check(meters != null and is_instance_valid(meters.row), "combat meters visible")

	# Second cast in same combat: Running Stitch+
	app.deck.combat_state.energy = 3
	var id_plus := "seamstress_running_stitch_plus"
	app.deck.draw_pile.append(id_plus)
	_check(app.deck.draw_extra(1) == 1, "draw running stitch+")
	app._refresh_hand()
	await _frames()
	var panel2 := _panel(id_plus)
	_check(panel2 != null, "panel2 found")
	await _arm(id_plus, true)
	var target_btn2: Button = adapter._targets[target_pos]
	target_btn2.grab_focus()
	await _frames()
	var label2 := adapter.target_strip.find_child("OutcomePreview", true, false) as Label
	# Running stitch+ has base 3 + 1 (Pincushion) = 4 damage.
	# Enemy already has Exposed 1 from hit 1 (+50%): floor(4 * 3 / 2) = 6 damage.
	# Bleed is 4 + 1 = 5. Exposed delta is 0 (Button Eye consumed).
	_check(label2 != null and label2.text.contains("6 damage"),
		"second cast forecast shows 6 damage (4 with enemy Exposed)")
	_check(label2 != null and not label2.text.contains("Exposed:"),
		"second cast forecast has no Button Eye Exposed delta")
	await _key(KEY_ENTER)
	await _frames()

	var event2: Dictionary = adapter.last_event
	_check(event2.get("ok", false) and event2.hits.size() == 1, "second cast commit succeeded")
	_check(event2.hits[0].damage == 6, "second cast dealt 6 damage")
	_check(event2.hits[0].statuses == {"bleed": 5},
		"second cast applied Bleed 5 and NO Exposed")
	_check(patches.latch_snapshot().get("seamstress") == true,
		"latch remains consumed")

	# Repaint/panel sync, forecast, turn change do not reset service/latch
	app.enemy_intents._turn_index += 1
	adapter._sync_battle()
	_check(adapter._service._patches == patches, "turn change preserves single patch service")
	_check(patches.latch_snapshot().get("seamstress") == true, "turn change does not reset latch")

	# Return resets/retires resolver
	await _return()
	_check(adapter._service != null and adapter._service._patches == null,
		"Return resets/retires resolver to unpatched state")

	# Normal battle with no bound wardrobe remains unpatched
	_check(app._start_battle(), "unpatched battle starts from title")
	await _frames()
	_check(adapter._service._patches == null,
		"normal battle with no bound wardrobe remains unpatched")
	await _return()


func _test_mounted_red_bobbin_cuff() -> void:
	var fixture := _quick_fight_fixture()
	_check(not fixture.is_empty(), "mounted red bobbin cuff test: found connected Fight fixture")
	if fixture.is_empty():
		return

	app.run_seed = fixture.seed
	app.route_button.pressed.emit()
	await _frames()

	var first_btn := _route_action(fixture.fight)
	_check(first_btn != null and not first_btn.disabled, "cuff test: opening fight button found")
	if first_btn == null:
		return
	first_btn.pressed.emit()
	await _frames()

	_check(app.deck != null and app.party.is_valid(), "cuff test: predecessor fight started")
	for enemy in app.enemies.get_enemies():
		app.enemies.apply_damage(enemy.position, 9999)
	app._observe_battle_result()
	await _frames()
	_check(app.battle_result.get_outcome() == CombatBattleResult.VICTORY
		and app.reward_buttons.size() == 4, "cuff test: victory settled")
	if app.reward_buttons.size() != 4:
		return

	app.reward_buttons[3].pressed.emit()
	await _frames()
	app.continue_button.pressed.emit()
	await _frames()

	_check(app.route_view != null and app.route_view.is_visible_in_tree()
		and app.party_carryover is RunTornCarryover, "cuff test: connected route chooser open")
	if app.route_view == null:
		return

	var records_m04: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_attack_patches.json"))
	var records_m05: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m05_arm_support_patches.json"))
	var definitions: Array[Dictionary] = []
	for entry in records_m04:
		if entry is Dictionary and entry.get("id") in ["button_eye", "pincushion_arm"]:
			var slot: String = "HEAD" if entry.id == "button_eye" else "ARM"
			definitions.append({"id": entry.id, "slot": slot})
	for entry in records_m05:
		if entry is Dictionary and entry.get("id") in ["red_bobbin_cuff", "hemguard_cuff", "loose_thread_glove"]:
			definitions.append({"id": entry.id, "slot": "ARM"})
	var coats: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_coat_patches.json"))
	if coats is Array and RunPatchCoatRules._valid_authored(coats):
		definitions.append({"id": RunPatchCoatRules.BONUS_ID, "slot": "COAT"})

	app.run_trinkets.clear()
	app.run_trinkets.append("red_bobbin_cuff")
	var carry := app.party_carryover as RunTornCarryover
	_check(carry != null and carry.is_valid() and carry.torn.is_valid(),
		"cuff test: carryover valid before next fight")
	var wardrobe := RunPatchWardrobe.new(app.run_heroes, app.run_trinkets,
		definitions, app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
	_check(wardrobe.is_valid(), "cuff test: wardrobe valid")
	var expected := wardrobe.get_snapshot()
	var sew := wardrobe.sew("red_bobbin_cuff", "seamstress", "ARM", "sew_cuff", expected)
	expected = wardrobe.get_snapshot()
	_check(sew.ok, "sew red_bobbin_cuff to seamstress ARM")
	_check(carry.can_bind_wardrobe(wardrobe, carry.torn, expected)
		and carry.bind_wardrobe(wardrobe, carry.torn, expected),
		"bind cuff wardrobe to live carryover")

	var next_btn := _route_action(fixture.next_fight)
	_check(next_btn != null and not next_btn.disabled, "cuff test: next fight button found")
	if next_btn == null:
		return
	next_btn.pressed.emit()
	await _frames()

	_check(app.route_view == null and app.battle_view.is_visible_in_tree()
		and app.party.is_valid() and app.deck != null,
		"cuff test: second fight mounted successfully")

	# AC3: Both presenters bind valid patch authority on session entry
	var area_adapter = app.get_node_or_null("LiveAreaAttackAction")
	_check(area_adapter != null, "LiveAreaAttackAction mounted")
	_check(adapter._service._patches != null and adapter._service._patches.is_valid(),
		"single-bleed adapter bound patch authority")
	_check(area_adapter._service._patches != null and area_adapter._service._patches.is_valid(),
		"area adapter bound patch authority")
	_check(adapter._service._patches.card_bleed_bonus("seamstress", "seamstress_running_stitch") == 1,
		"running stitch has +1 cuff bleed")
	_check(area_adapter._service._patches.card_bleed_bonus("seamstress", "seamstress_blanket_stitch") == 1,
		"blanket stitch has +1 cuff bleed")
	_check(adapter._service._patches.card_bleed_bonus("seamstress", "seamstress_red_thread") == 1,
		"red thread has +1 cuff bleed")
	_check(adapter._service._patches.card_bleed_bonus("seamstress", "seamstress_hemorrhage_hem") == 0,
		"hemorrhage has 0 cuff bleed")

	# 1. Held Running Stitch (keyboard play)
	var target_pos := 1
	for enemy in app.enemies.get_enemies():
		if enemy.hp > 10:
			target_pos = enemy.position
			break
	var id_run := "seamstress_running_stitch"
	app.deck.draw_pile.append(id_run)
	_check(app.deck.draw_extra(1) == 1, "draw running stitch")
	app._refresh_hand()
	await _frames()

	var panel_run := _panel(id_run)
	_check(panel_run != null and adapter._bindings.has(panel_run), "running stitch panel bound")
	await _arm(id_run, true)
	_check(adapter.target_strip != null and is_instance_valid(adapter.target_strip), "target strip visible")
	var btn_target: Button = adapter._targets[target_pos]
	btn_target.grab_focus()
	await _frames()
	var lbl_prev := adapter.target_strip.find_child("OutcomePreview", true, false) as Label
	_check(lbl_prev != null and lbl_prev.text.contains("5 (future)"),
		"forecast shows Bleed: 0 -> 5 (3 printed + 1 passive + 1 cuff)")
	_check(lbl_prev != null and lbl_prev.text.contains("2 damage"),
		"forecast shows 2 damage")

	var e_before: int = app.deck.energy
	var discard_before: int = app.deck.discard_pile.count(id_run)
	var enemy_hp_before: int = app.enemies.get_enemy(target_pos).hp
	await _key(KEY_ENTER)
	await _frames()

	_check(adapter.last_event.get("ok", false), "running stitch commit succeeded")
	_check(app.deck.energy == e_before - 1, "1 energy spent")
	_check(app.deck.discard_pile.count(id_run) == discard_before + 1, "1 card discarded")
	var enemy_after: Dictionary = app.enemies.get_enemy(target_pos)
	_check(enemy_after.hp == enemy_hp_before - 2, "enemy took 2 damage")
	_check(enemy_after.get("statuses", {}).get("bleed", 0) == 5,
		"enemy has Bleed 5 from running stitch with cuff")

	# 2. Held Red Thread (mouse play)
	app.deck.combat_state.energy = 3
	var id_red := "seamstress_red_thread"
	app.deck.draw_pile.append(id_red)
	_check(app.deck.draw_extra(1) == 1, "draw red thread")
	app._refresh_hand()
	await _frames()

	var panel_red := _panel(id_red)
	_check(panel_red != null and adapter._bindings.has(panel_red), "red thread panel bound")
	await _arm(id_red, false)
	var btn_target_red: Button = adapter._targets[target_pos]
	await _hover(btn_target_red)
	var lbl_prev_red := adapter.target_strip.find_child("OutcomePreview", true, false) as Label
	_check(lbl_prev_red != null and lbl_prev_red.text.contains("5 -> 13"),
		"forecast shows Bleed: 5 -> 13 (5 + 6 printed + 1 passive + 1 cuff)")
	_check(lbl_prev_red != null and lbl_prev_red.text.contains("Exposed: 0 -> 1"),
		"forecast shows Exposed 0 -> 1")

	var e_before_red: int = app.deck.energy
	var discard_before_red: int = app.deck.discard_pile.count(id_red)
	await _mouse(btn_target_red)
	await _frames()

	_check(adapter.last_event.get("ok", false), "red thread commit succeeded")
	_check(app.deck.energy == e_before_red - 2, "2 energy spent")
	_check(app.deck.discard_pile.count(id_red) == discard_before_red + 1, "1 card discarded")
	var enemy_after_red: Dictionary = app.enemies.get_enemy(target_pos)
	_check(enemy_after_red.get("statuses", {}).get("bleed", 0) == 13,
		"enemy has Bleed 13 from red thread")
	_check(enemy_after_red.get("statuses", {}).get("exposed", 0) == 1,
		"enemy has Exposed 1")

	# 3. Held Blanket Stitch (mouse play via LiveAreaAttackAction)
	app.deck.combat_state.energy = 3
	var id_blanket := "seamstress_blanket_stitch"
	app.deck.draw_pile.append(id_blanket)
	_check(app.deck.draw_extra(1) == 1, "draw blanket stitch")
	app._refresh_hand()
	await _frames()

	var panel_blanket := _panel(id_blanket)
	_check(panel_blanket != null and area_adapter._bindings.has(panel_blanket),
		"blanket stitch panel bound to area_adapter")

	var e_before_b: int = app.deck.energy
	var discard_before_b: int = app.deck.discard_pile.count(id_blanket)
	var living_before: Dictionary = {}
	for enemy in app.enemies.get_enemies():
		if enemy.hp > 0:
			living_before[enemy.position] = int(enemy.get("statuses", {}).get("bleed", 0))

	await _mouse(panel_blanket)
	await _frames()

	_check(area_adapter.last_event.get("ok", false), "area blanket stitch commit succeeded")
	_check(app.deck.energy == e_before_b - 2, "exact 2 energy spent on blanket stitch")
	_check(app.deck.discard_pile.count(id_blanket) == discard_before_b + 1, "1 blanket stitch discarded")
	for pos in living_before:
		var after_bleed: int = int(app.enemies.get_enemy(pos).get("statuses", {}).get("bleed", 0))
		var exp_bleed: int = living_before[pos] + 4 # 2 printed + 1 passive + 1 cuff
		_check(after_bleed == exp_bleed,
			"living enemy at pos %d received 4 bleed (was %d, now %d)" % [pos, living_before[pos], after_bleed])

	# 4. Held Blanket Stitch+ (keyboard play via LiveAreaAttackAction)
	app.deck.combat_state.energy = 3
	var id_blanket_plus := "seamstress_blanket_stitch_plus"
	app.deck.draw_pile.append(id_blanket_plus)
	_check(app.deck.draw_extra(1) == 1, "draw blanket stitch+")
	app._refresh_hand()
	await _frames()

	var panel_bp := _panel(id_blanket_plus)
	_check(panel_bp != null and area_adapter._bindings.has(panel_bp),
		"blanket stitch+ panel bound to area_adapter")

	var e_before_bp: int = app.deck.energy
	var discard_before_bp: int = app.deck.discard_pile.count(id_blanket_plus)
	var living_before_bp: Dictionary = {}
	for enemy in app.enemies.get_enemies():
		if enemy.hp > 0:
			living_before_bp[enemy.position] = int(enemy.get("statuses", {}).get("bleed", 0))

	panel_bp.grab_focus()
	await _frames()
	_check(panel_bp.has_focus(), "keyboard focused blanket stitch+ panel")
	await _key(KEY_ENTER)
	await _frames()

	_check(area_adapter.last_event.get("ok", false), "keyboard blanket stitch+ commit succeeded")
	_check(app.deck.energy == e_before_bp - 2, "exact 2 energy spent on blanket stitch+")
	_check(app.deck.discard_pile.count(id_blanket_plus) == discard_before_bp + 1, "1 blanket stitch+ discarded")
	for pos in living_before_bp:
		var after_bleed: int = int(app.enemies.get_enemy(pos).get("statuses", {}).get("bleed", 0))
		var exp_bleed: int = living_before_bp[pos] + 5 # 3 printed + 1 passive + 1 cuff
		_check(after_bleed == exp_bleed,
			"living enemy at pos %d received 5 bleed from plus (was %d, now %d)" % [pos, living_before_bp[pos], after_bleed])

	# 5. Held Hemorrhage Hem (doubles existing bleed, ZERO cuff bonus)
	app.deck.combat_state.energy = 3
	var id_hem := "seamstress_hemorrhage_hem"
	app.deck.draw_pile.append(id_hem)
	_check(app.deck.draw_extra(1) == 1, "draw hemorrhage hem")
	app._refresh_hand()
	await _frames()

	var panel_hem := _panel(id_hem)
	_check(panel_hem != null and adapter._bindings.has(panel_hem), "hemorrhage panel bound to single adapter")
	await _arm(id_hem, true)
	var other_target := -1
	for enemy in app.enemies.get_enemies():
		if enemy.position != target_pos and enemy.hp > 0:
			other_target = enemy.position
			break
	if other_target > 0:
		var btn_other: Button = adapter._targets[other_target]
		btn_other.grab_focus()
		await _frames()
		var bleed_prior: int = int(app.enemies.get_enemy(other_target).get("statuses", {}).get("bleed", 0))
		var lbl_prev_h := adapter.target_strip.find_child("OutcomePreview", true, false) as Label
		_check(lbl_prev_h != null and lbl_prev_h.text.contains("Bleed: %d -> %d" % [bleed_prior, bleed_prior * 2]),
			"hemorrhage forecast doubles existing bleed without cuff bonus: %d -> %d" % [bleed_prior, bleed_prior * 2])
		await _key(KEY_ENTER)
		await _frames()
		_check(adapter.last_event.get("ok", false), "hemorrhage commit succeeded")
		_check(int(app.enemies.get_enemy(other_target).get("statuses", {}).get("bleed", 0)) == bleed_prior * 2,
			"hemorrhage doubled bleed exactly without cuff bonus")

	# 6. Lifecycle: turn change, sync, return, and title unpatched battle
	app.enemy_intents._turn_index += 1
	adapter._sync_battle()
	area_adapter._sync_battle()
	_check(adapter._service._patches != null and adapter._service._patches.is_valid(),
		"turn change preserves single adapter patch service")
	_check(area_adapter._service._patches != null and area_adapter._service._patches.is_valid(),
		"turn change preserves area adapter patch service")

	await _return()
	_check(adapter._service != null and adapter._service._patches == null,
		"Return resets single resolver to unpatched state")
	_check(area_adapter._service != null and area_adapter._service._patches == null,
		"Return resets area resolver to unpatched state")

	_check(app._start_battle(), "unpatched battle starts from title")
	await _frames()
	_check(adapter._service._patches == null, "single adapter remains unpatched in normal battle")
	_check(area_adapter._service._patches == null, "area adapter remains unpatched in normal battle")
	await _return()


## ---------------------------------------------------------------------------
## Genuine sewn HEAD/ARM Bleed: the mounted target strip must state the exact
## amount the authoritative resolver will commit for the ACTUAL Seamstress.
## The expectations below come from the authored card catalog, the authored
## Bloodline passive record and the authored patch catalogs -- never from the
## presenter that is being verified.
## ---------------------------------------------------------------------------

const BLEED_CARD_IDS := [
	"seamstress_running_stitch", "seamstress_running_stitch_plus",
	"seamstress_red_thread", "seamstress_red_thread_plus",
]
const HEM_CARD_IDS := ["seamstress_hemorrhage_hem", "seamstress_hemorrhage_hem_plus"]


func _joined_positions(values: Array) -> String:
	var parts: Array[String] = []
	for value in values:
		parts.append(str(value))
	return ",".join(parts)


func _expected_bloodline() -> int:
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/heroes/seamstress_paths.json"))
	_check(records is Array, "authored Seamstress Path catalog parses")
	if not records is Array:
		return 0
	for entry in records:
		if entry is Dictionary and entry.get("id") == "bloodline":
			var passive: Variant = entry.get("passive")
			_check(passive is Dictionary and passive.get("applies_to") == "seamstress"
				and passive.get("kind") == "bleed_bonus" and passive.get("status") == "bleed"
				and int(passive.get("value", 0)) == 1 and passive.get("stacks") == false,
				"authored Bloodline passive is +1 Bleed on the Seamstress only")
			return int(passive.get("value", 0)) if passive is Dictionary else 0
	_check(false, "authored Bloodline Path record exists")
	return 0


func _authored_patch_bleed(patch_id: String) -> int:
	if patch_id == "":
		return 0
	for path in ["res://data/patches/m05_head_patches.json",
			"res://data/patches/m05_arm_support_patches.json"]:
		var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(records is Array, "authored M05 patch catalog parses: " + path)
		if not records is Array:
			continue
		for entry in records:
			if entry is Dictionary and entry.get("id") == patch_id:
				_check(entry.get("effect") == "card_bleed_bonus"
					and int(entry.get("amount", 0)) == 1,
					"authored patch " + patch_id + " is +1 Bleed")
				return int(entry.get("amount", 0))
	_check(false, "authored patch record exists: " + patch_id)
	return 0


func _expected_strip(definition: Dictionary, applied: int) -> String:
	var effects: Dictionary = definition.effects
	var authored: int = int(effects.get("bleed", 0))
	var summary := "Bleed %d (authored %d)" % [applied, authored]
	if applied > authored:
		summary = "Bleed %d (authored %d + %d passive/sewn)" % [
			applied, authored, applied - authored]
	var detail := ""
	if effects.has("damage"):
		detail = "%d damage; %s" % [int(effects.damage), summary]
	else:
		detail = "%s; Exposed %d" % [summary, int(effects.get("exposed", 0))]
	return "%s | Cost %d | From %s | One living enemy %s\n%s" % [
		str(definition.display_name), int(definition.cost),
		_joined_positions(definition.from_positions),
		_joined_positions(definition.to_positions), detail]


func _expected_hem_strip(definition: Dictionary) -> String:
	return "%s | Cost %d | From %s | One living enemy %s\n%s" % [
		str(definition.display_name), int(definition.cost),
		_joined_positions(definition.from_positions),
		_joined_positions(definition.to_positions),
		"Doubles the chosen enemy's CURRENT Bleed (no flat passive or sewn bonus; the preview shows N -> 2N)"]


func _first_target(min_hp: int = 1) -> int:
	for enemy in app.enemies.get_enemies():
		if int(enemy.hp) >= min_hp:
			return int(enemy.position)
	return -1


func _enter_connected_fight(label: String) -> Dictionary:
	var fixture := _quick_fight_fixture()
	_check(not fixture.is_empty(), label + ": found connected Fight fixture")
	if fixture.is_empty():
		return {"ok": false}
	app.run_seed = fixture.seed
	app.route_button.pressed.emit()
	await _frames()
	var first_btn := _route_action(fixture.fight)
	_check(first_btn != null and not first_btn.disabled, label + ": opening fight button found")
	if first_btn == null:
		return {"ok": false}
	first_btn.pressed.emit()
	await _frames()
	_check(app.deck != null and app.party.is_valid(), label + ": predecessor fight started")
	if app.deck == null or app.party == null:
		return {"ok": false}
	for enemy in app.enemies.get_enemies():
		app.enemies.apply_damage(enemy.position, 9999)
	app._observe_battle_result()
	await _frames()
	var won: bool = app.battle_result.get_outcome() == CombatBattleResult.VICTORY
	_check(won and app.reward_buttons.size() == 4, label + ": predecessor victory settled")
	if not won or app.reward_buttons.size() != 4:
		return {"ok": false}
	app.reward_buttons[3].pressed.emit()
	await _frames()
	app.continue_button.pressed.emit()
	await _frames()
	_check(app.route_view != null and app.route_view.is_visible_in_tree()
		and app.party_carryover is RunTornCarryover, label + ": connected route chooser open")
	if app.route_view == null:
		return {"ok": false}
	return {"ok": true, "fixture": fixture}


func _sew_wardrobe(head_id: String, arm_id: String, label: String) -> bool:
	var definitions: Array[Dictionary] = []
	for path in ["res://data/patches/m05_head_patches.json",
			"res://data/patches/m05_arm_support_patches.json"]:
		var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(records is Array, label + ": M05 catalog parses: " + path)
		if not records is Array:
			return false
		for entry in records:
			if not entry is Dictionary:
				continue
			var slot: Variant = entry.get("slot")
			if (slot == "HEAD" or slot == "ARM") and entry.get("id") is String:
				definitions.append({"id": str(entry.id), "slot": str(slot)})
	app.run_trinkets.clear()
	for patch_id in [head_id, arm_id]:
		if patch_id != "":
			app.run_trinkets.append(patch_id)
	var wardrobe := RunPatchWardrobe.new(app.run_heroes, app.run_trinkets,
		definitions, app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
	_check(wardrobe.is_valid(), label + ": real wardrobe accepts the authored patches")
	if not wardrobe.is_valid():
		return false
	var expected := wardrobe.get_snapshot()
	if head_id != "":
		var sewn_head := wardrobe.sew(head_id, "seamstress", "HEAD",
			"sew_head_" + head_id, expected)
		expected = wardrobe.get_snapshot()
		_check(sewn_head.ok, label + ": " + head_id + " really sewn on Seamstress HEAD")
		if not sewn_head.ok:
			return false
	if arm_id != "":
		var sewn_arm := wardrobe.sew(arm_id, "seamstress", "ARM",
			"sew_arm_" + arm_id, expected)
		expected = wardrobe.get_snapshot()
		_check(sewn_arm.ok, label + ": " + arm_id + " really sewn on Seamstress ARM")
		if not sewn_arm.ok:
			return false
	_check(expected.get("worn", {}).get("seamstress", {}).get("HEAD", "") == head_id
		and expected.get("worn", {}).get("seamstress", {}).get("ARM", "") == arm_id,
		label + ": the actual Seamstress carries the authored sewn slots")
	var carry := app.party_carryover as RunTornCarryover
	var bound: bool = carry != null and carry.can_bind_wardrobe(wardrobe, carry.torn, expected) and carry.bind_wardrobe(wardrobe, carry.torn, expected)
	_check(bound, label + ": the sewn wardrobe binds to the live run carryover")
	return bound


func _enter_next_fight(fixture: Dictionary, label: String) -> bool:
	var next_btn := _route_action(fixture.next_fight)
	_check(next_btn != null and not next_btn.disabled, label + ": next fight button found")
	if next_btn == null:
		return false
	next_btn.pressed.emit()
	await _frames()
	var ready: bool = app.route_view == null and app.battle_view.is_visible_in_tree() and app.party.is_valid() and app.deck != null
	_check(ready, label + ": connected fight mounted with the sewn wardrobe")
	return ready


func _draw_card(id: String, label: String) -> bool:
	app.deck.combat_state.energy = 3
	app.deck.draw_pile.append(id)
	_check(app.deck.draw_extra(1) == 1, label + ": real deck draws " + id)
	app._refresh_hand()
	await _frames()
	var panel := _panel(id)
	_check(panel != null and adapter._bindings.has(panel),
		label + ": held " + id + " has one mounted input binding")
	return panel != null


func _release_card(id: String) -> void:
	# Test fixture only: drop the extra copy this inspection drew so the mounted
	# hand stays a realistic five-card hand instead of growing every check.
	app.deck.hand.erase(id)
	app._refresh_hand()
	await _frames()


func _check_bleed_strip(id: String, applied: int, label: String, commit_mode := "") -> void:
	if not await _draw_card(id, label):
		return
	var definition: Dictionary = catalog.get_definition(id)
	await _arm(id, commit_mode == "keyboard")
	if adapter.target_strip == null:
		return
	var heading := adapter.target_strip.find_child("Rule", true, false) as Label
	_check(heading != null and heading.text == _expected_strip(definition, applied),
		label + ": mounted strip states the real effective Bleed for " + id)
	if heading != null and applied > int(definition.effects.bleed) + 1:
		_check(not heading.text.contains("Bleed %d including passive" % (
			int(definition.effects.bleed) + 1)),
			label + ": strip never repeats the raw authored-plus-one number for " + id)
	var target := _first_target(1)
	if target < 0 or not adapter._targets.has(target):
		_check(false, label + ": living enemy target available for " + id)
		await _key(KEY_ESCAPE)
		return
	var forecast: Dictionary = adapter._service.forecast_single(
		app.deck, app.party, app.enemies, id, target)
	_check(forecast.get("ok", false)
		and int(forecast.bleed_after) - int(forecast.bleed_before) == applied,
		label + ": bound forecast applies exactly the stated Bleed for " + id)
	var before := _state()
	var latch_before: Dictionary = adapter._service._patches.latch_snapshot()
	await _hover(adapter._targets[target])
	adapter._targets[target].grab_focus()
	await _frames()
	var preview := adapter.target_strip.find_child("OutcomePreview", true, false) as Label
	_check(preview != null and preview.text == _outcome_text(forecast)
		and preview.text.contains("Bleed: %d -> %d" % [
			int(forecast.bleed_before), int(forecast.bleed_after)]),
		label + ": target preview keeps the exact future Bleed for " + id)
	_check(_state() == before and not adapter._choice.get("queued", false)
		and adapter._service._patches.latch_snapshot() == latch_before,
		label + ": hovering the target spends nothing and keeps the receipt pending")
	if commit_mode == "":
		await _key(KEY_ESCAPE)
		_check(adapter._choice.is_empty() and adapter.target_strip == null,
			label + ": Escape cancels without spending " + id)
		await _release_card(id)
		return
	await _commit_shown(id, target, applied, commit_mode, label)


func _commit_shown(id: String, target: int, applied: int, mode: String, label: String) -> void:
	var definition: Dictionary = catalog.get_definition(id)
	var forecast: Dictionary = adapter._service.forecast_single(
		app.deck, app.party, app.enemies, id, target)
	_check(forecast.get("ok", false)
		and int(forecast.bleed_after) - int(forecast.bleed_before) == applied,
		label + ": armed commit forecast still matches the strip for " + id)
	var before := _state()
	var enemy_before: Dictionary = app.enemies.get_enemy(target)
	var prior_bleed: int = int(enemy_before.get("statuses", {}).get("bleed", 0))
	var prior_exposed: int = int(enemy_before.get("statuses", {}).get("exposed", 0))
	if mode == "keyboard":
		adapter._targets[target].grab_focus()
		await _frames()
		await _key(KEY_ENTER)
	else:
		await _mouse(adapter._targets[target])
	await _frames()
	var event: Dictionary = adapter.last_event
	_check(event.get("ok", false) and event.hits.size() == 1
		and int(event.hits[0].position) == target,
		label + ": real %s commit resolves exactly one chosen enemy: %s" % [mode, id])
	var after: Dictionary = app.enemies.get_enemy(target)
	_check(int(after.get("statuses", {}).get("bleed", 0)) == prior_bleed + applied,
		label + ": committed enemy carries exactly the shown Bleed increase: " + id)
	_check(int(event.hits[0].statuses.get("bleed", 0)) == applied,
		label + ": the receipt records the same effective Bleed: " + id)
	if definition.effects.has("exposed"):
		_check(int(after.get("statuses", {}).get("exposed", 0)) == prior_exposed + 1
			and int(event.hits[0].statuses.get("exposed", 0)) == 1,
			label + ": Red Thread keeps its authored Exposed 1: " + id)
	_check(app.deck.energy == int(before[3]) - int(definition.cost),
		label + ": exactly the authored cost is spent: " + id)
	_check(app.deck.discard_pile.count(id) == int(before[2].count(id)) + 1
		and app.deck.hand.count(id) == int(before[1].count(id)) - 1,
		label + ": one held copy leaves the hand for the discard pile: " + id)
	_check(app.run_rng.seed == int(before[7]) and app.run_rng.state == int(before[8])
		and app.deck._rng.state == int(before[9]),
		label + ": committed cast never advances the seeded run or deck RNG: " + id)
	for enemy in before[6]:
		if int(enemy.position) != target:
			_check(app.enemies.get_enemy(int(enemy.position)) == enemy,
				label + ": every other enemy slot stays identical: " + id)


func _check_hem_strip(hem_id: String, label: String, commit_mode := "") -> void:
	var target := _first_target(1)
	if target < 0:
		_check(false, label + ": living target exists for " + hem_id)
		return
	_check(app.enemies.apply_statuses({target: {"bleed": 4}}),
		label + ": chosen enemy really carries pre-existing Bleed")
	app._refresh_enemy_roster()
	if not await _draw_card(hem_id, label):
		return
	var definition: Dictionary = catalog.get_definition(hem_id)
	await _arm(hem_id, false)
	if adapter.target_strip == null:
		return
	var heading := adapter.target_strip.find_child("Rule", true, false) as Label
	_check(heading != null and heading.text == _expected_hem_strip(definition),
		label + ": strip describes doubling CURRENT Bleed with no flat +N: " + hem_id)
	var patches: CombatPatchAttackRules = adapter._service._patches
	var heads: CombatM05HeadPatchRules = adapter._service._head_patches
	_check(patches.card_bleed_bonus("seamstress", hem_id) == 0
		and heads.get_bonus("seamstress", hem_id, "bleed") == 0,
		label + ": sewn Bleed bonuses never become a multiplier application: " + hem_id)
	var forecast: Dictionary = adapter._service.forecast_single(
		app.deck, app.party, app.enemies, hem_id, target)
	var prior: int = int(forecast.get("bleed_before", 0))
	_check(forecast.get("ok", false) and prior >= 4
		and int(forecast.bleed_after) == prior * 2,
		label + ": conditional forecast doubles the chosen stack: %s" % hem_id)
	var before := _state()
	await _hover(adapter._targets[target])
	adapter._targets[target].grab_focus()
	await _frames()
	var preview := adapter.target_strip.find_child("OutcomePreview", true, false) as Label
	_check(preview != null and preview.text.contains("Bleed: %d -> %d" % [prior, prior * 2]),
		label + ": preview doubles N to 2N without an invented flat bonus: " + hem_id)
	_check(_state() == before, label + ": doubled preview is transaction free: " + hem_id)
	if commit_mode == "":
		await _key(KEY_ESCAPE)
		_check(adapter._choice.is_empty() and adapter.target_strip == null,
			label + ": Escape cancels the doubling strip: " + hem_id)
		await _release_card(hem_id)
		return
	var enemy_before: Dictionary = app.enemies.get_enemy(target)
	var prior_bleed: int = int(enemy_before.get("statuses", {}).get("bleed", 0))
	if commit_mode == "keyboard":
		await _key(KEY_ENTER)
	else:
		await _mouse(adapter._targets[target])
	await _frames()
	var event: Dictionary = adapter.last_event
	_check(event.get("ok", false) and event.hits.size() == 1,
		label + ": doubling commit succeeded: " + hem_id)
	var after: Dictionary = app.enemies.get_enemy(target)
	_check(int(after.get("statuses", {}).get("bleed", 0)) == prior_bleed * 2,
		label + ": committed doubling yields exactly N + N: " + hem_id)
	_check(int(event.hits[0].statuses.get("bleed", 0)) == prior_bleed,
		label + ": the receipt records the current stack, not a patch bonus: " + hem_id)


func _bleed_case(label: String, head_id: String, arm_id: String,
		table: Dictionary, first_commit: String, first_mode: String,
		second_commit: String, second_mode: String) -> void:
	var entry := await _enter_connected_fight(label)
	if not entry.get("ok", false):
		await _return()
		return
	if not await _sew_wardrobe(head_id, arm_id, label):
		await _return()
		return
	if not await _enter_next_fight(entry.fixture, label):
		await _return()
		return
	var patches: CombatPatchAttackRules = adapter._service._patches
	var heads: CombatM05HeadPatchRules = adapter._service._head_patches
	var bound: bool = patches != null and patches.is_valid() and heads != null and heads.read_projection().get("ok", false)
	_check(bound, label + ": one battle-long genuine patch authority is bound")
	if not bound:
		await _return()
		return
	var passive := _expected_bloodline()
	var head_bonus := _authored_patch_bleed(head_id)
	var arm_bonus := _authored_patch_bleed(arm_id)
	var active: Array = patches.active_snapshot().get("seamstress", [])
	var seamstress_lives := false
	for hero in app.party.get_heroes():
		if hero["id"] == "seamstress":
			seamstress_lives = hero["hp"] > 0
	_check(seamstress_lives and active.has(head_id) == (head_id != "")
		and active.has(arm_id) == (arm_id != ""),
		label + ": the living Seamstress is the patch wearer in the real battle")
	for id in BLEED_CARD_IDS:
		var definition: Dictionary = catalog.get_definition(id)
		var derived: int = int(definition.effects.get("bleed", 0)) + passive + head_bonus + arm_bonus
		_check(derived == int(table[id]),
			"%s: %s is authored %d + Bloodline %d + sewn %d/%d = %d" % [
				label, id, int(definition.effects.get("bleed", 0)), passive,
				head_bonus, arm_bonus, derived])
		_check(patches.card_bleed_bonus("seamstress", id) == arm_bonus,
			label + ": bound ARM projection credits the real Seamstress: " + id)
		_check(heads.get_bonus("seamstress", id, "bleed") == head_bonus,
			label + ": bound HEAD projection credits the real Seamstress: " + id)
		_check(patches.card_bleed_bonus("warden", id) == 0
			and patches.card_bleed_bonus("tinker", id) == 0
			and heads.get_bonus("warden", id, "bleed") == 0
			and heads.get_bonus("tinker", id, "bleed") == 0,
			label + ": no other hero receives the Seamstress sewn Bleed: " + id)
		await _check_bleed_strip(id, derived, label)
	# A real cast proves the shown amount is applied once by the committed path.
	await _check_bleed_strip(first_commit, int(table[first_commit]), label, first_mode)
	await _check_bleed_strip(second_commit, int(table[second_commit]), label, second_mode)
	# Hemorrhage: doubling stays conditional even with both sewn bonuses.
	for hem_id in HEM_CARD_IDS:
		await _check_hem_strip(hem_id, label)
	await _check_hem_strip("seamstress_hemorrhage_hem", label, "mouse")
	await _check_hem_strip("seamstress_hemorrhage_hem_plus", label, "keyboard")
	await _return()
	_check(adapter._service != null and adapter._service._patches == null,
		label + ": leaving the fight retires the sewn projection")


func _test_effective_sewn_bleed() -> void:
	await _bleed_case("unpatched", "", "", {
		"seamstress_running_stitch": 4, "seamstress_running_stitch_plus": 5,
		"seamstress_red_thread": 7, "seamstress_red_thread_plus": 9,
	}, "seamstress_running_stitch", "mouse",
		"seamstress_red_thread_plus", "keyboard")
	await _bleed_case("bloodstitch bonnet", "bloodstitch_bonnet", "", {
		"seamstress_running_stitch": 5, "seamstress_running_stitch_plus": 6,
		"seamstress_red_thread": 8, "seamstress_red_thread_plus": 10,
	}, "seamstress_running_stitch_plus", "keyboard",
		"seamstress_red_thread", "mouse")
	await _bleed_case("bonnet and cuff", "bloodstitch_bonnet", "red_bobbin_cuff", {
		"seamstress_running_stitch": 6, "seamstress_running_stitch_plus": 7,
		"seamstress_red_thread": 9, "seamstress_red_thread_plus": 11,
	}, "seamstress_running_stitch", "keyboard",
		"seamstress_red_thread_plus", "mouse")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real main scene loads")
	if scene == null:
		_finish()
		return
	app = scene.instantiate()
	root.add_child(app)
	await _frames()
	adapter = app.get_node_or_null("LiveAreaAttackAction/LiveSeamstressSingleBleedHand")
	_check(adapter != null and app.deck == null, "child adapter mounted in real title scene")
	if adapter == null:
		app.free()
		_finish()
		return
	for id in IDS:
		_check(catalog.has_card(id) and catalog.get_definition(id).target_kind == "enemy_single",
			"authored single-target Bleed variant present: " + id)
	for i in range(IDS.size()):
		await _play(IDS[i], ["mouse", "enter", "space"][i % 3],
			IDS[i] == "seamstress_hemorrhage_hem_plus")
	await _cancel_and_reject()
	await _terminal_case()
	await _three_enemy_case()
	await _test_mounted_worn_patches()
	await _test_mounted_red_bobbin_cuff()
	await _test_effective_sewn_bleed()
	app.free()
	_finish()


func _finish() -> void:
	for message in failures:
		printerr("FAIL: " + message)
	print("live_seamstress_single_bleed_hand_test: %d checks, %d failures" % [
		checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
