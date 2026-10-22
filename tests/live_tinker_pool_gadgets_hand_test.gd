extends SceneTree
## Real mounted shared-hand actions for both versions of Tinker's nonattack gadgets.
## Seeded title->battle, physical panels and viewport input; no test-only presenter.

const SPARE := ["tinker_spare_parts", "tinker_spare_parts_plus"]
const SIGHT := ["tinker_sight_glass", "tinker_sight_glass_plus"]
var app
var support
var attack
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _frames() -> void:
	await process_frame
	await process_frame


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _mouse(control: Control) -> void:
	_check(is_instance_valid(control) and control.is_visible_in_tree(), "mouse recipient exists and is visible")
	if not is_instance_valid(control):
		return
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		if pressed:
			root.push_input(event, true)
	await _frames()


func _panel(id: String) -> Control:
	if not is_instance_valid(app.hand_view):
		return null
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0) is Label and panel.get_child(0).text == id:
			return panel
	return null


func _state() -> Array:
	return [app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.party.get_heroes(), app.enemies.get_enemies(), app.run_rng.seed,
		app.run_rng.state, app.enemy_intents.get_intents(), app.enemy_attacks.duplicate(true),
		app.battle_result.get_outcome(), app._battle_closed]


func _owner() -> int:
	for hero in app.party.get_heroes():
		if hero.id == "tinker":
			return hero.position
	return 0


func _start(id: String) -> bool:
	_check(app.deck == null, "new action starts on the actual title screen")
	app.run_seed = 42
	var started: bool = app._start_battle()
	await _frames()
	var ready: bool = started and app.deck != null and app.deck.turn_active \
		and app.party != null and app.enemies != null and app.enemy_intents != null \
		and is_instance_valid(app.battle_view) and is_instance_valid(app.hand_view) \
		and app.deck._rng == app.run_rng and app.deck.energy == 3
	_check(ready, "seeded real app battle has live models, hand and three energy")
	if not ready:
		return false
	_check(_owner() == 3 and app.enemies.get_enemies().size() >= 2, "living Tinker in slot 3 and multiple real enemies")
	# A reward acquired earlier in a run is drawn by the real CombatDeck; never
	# replace the hand with a fake control or mutate the panel identity.
	app.deck.draw_pile.append(id)
	_check(app.deck.draw_extra(1) == 1 and app.deck.hand.back() == id,
		"authored card arrives via seeded shared deck draw: " + id)
	app._refresh_hand()
	await _frames()
	return _panel(id) != null


func _return() -> void:
	app.return_button.pressed.emit()
	await _frames()
	_check(app.deck == null and support._bindings.is_empty()
		and attack._bindings.is_empty() and attack._armed == null,
		"Return retires all held input and enemy selection")


func _display(id: String, sight: bool) -> void:
	var panel := _panel(id)
	_check(panel != null, "physical card panel held: " + id)
	if panel == null:
		return
	var facts: Dictionary = support._metadata.get_facts(panel)
	var definition: Dictionary = TinkerPoolCards.new().get_definition(id)
	_check(facts.get("known") == true and facts.get("owner") == "tinker"
		and facts.get("cost") == definition.cost and facts.get("from_text") == "From 2–3"
		and facts.get("target_text") == ("To enemy 1–3" if sight else "Self"),
		"real drawn panel has authored owner, cost and FROM/TO: " + id)
	_check(support._metadata.TINKER == Color("#c49a3a")
		and support._metadata.CREAM == Color("#ece0c8")
		and support._metadata.get_geometry(panel).has("frame"),
		"mustard and cream sewn renderer is retained: " + id)
	_check(panel.tooltip_text.contains(definition.display_name)
		and panel.tooltip_text.contains("draw 1 card")
		and panel.tooltip_text.contains("Exposed 2" if sight else "%d Block" % definition.effects.block),
		"real panel tooltip names the full nonattack effect: " + id)
	_check(panel.get_child(0).text == id and not panel.get_child(0).visible
		and panel.mouse_filter == Control.MOUSE_FILTER_STOP,
		"same underlying ID panel stays pointer-reachable: " + id)
	_check((attack._bindings.has(panel) if sight else support._bindings.has(panel))
		and not (support._bindings.has(panel) if sight else attack._bindings.has(panel))
		and panel.gui_input.get_connections().size() == 1,
		"only the correct hand presenter handles the real panel once: " + id)


func _spare(id: String, keyboard: bool, empty_draw: bool = false, slot_two: bool = false) -> void:
	if not await _start(id):
		return
	if slot_two:
		var swap: Dictionary = CombatPositionSwaps.preview_adjacent_swap(app.party, 2, 1)
		_check(swap.get("ok", false), "real adjacent swap can put Tinker in slot two")
		if swap.get("ok", false):
			app.party._heroes.assign(swap.heroes)
			app._refresh_party()
			await _frames()
	_check(_owner() == (2 if slot_two else 3), "Tinker identity tracks reordered party")
	if empty_draw:
		app.deck.draw_pile.clear()
		app.deck.discard_pile.clear()
	_display(id, false)
	var before := _state()
	var held := _panel(id)
	_check(held != null and support._eligible(held, id, app.deck, app.party, app.battle_view),
		"support preflight admits held Spare Parts")
	var used: bool = attack._play._tinker._consumed
	if keyboard:
		held.grab_focus()
		await _key(KEY_SPACE)
	else:
		await _mouse(held)
	var after := _state()
	var definition: Dictionary = TinkerPoolCards.new().get_definition(id)
	var heroes: Array = before[5].duplicate(true)
	heroes[_owner() - 1]["block"] += int(definition.effects.block)
	var expected_hand: Array = before[1].duplicate()
	if not empty_draw:
		_check(not before[0].is_empty(), "real seeded draw pile has one available card")
		expected_hand.append(before[0].back())
	expected_hand.erase(id)
	var expected_discard: Array = before[2].duplicate()
	expected_discard.append(id)
	var expected_draw: Array = before[0].duplicate()
	if not empty_draw:
		expected_draw.pop_back()
	_check(after[0] == expected_draw and after[1] == expected_hand
		and after[2] == expected_discard and after[3] == before[3]
		and after[5] == heroes and after[6] == before[6],
		"one Spare play: exact Block, drawn card, discard, zero energy and no enemy mutation: " + id)
	_check(after.slice(7) == before.slice(7) and attack._play._tinker._consumed == used
		and support._pending.is_empty() and app.hand_view.get_child_count() == app.deck.hand.size(),
		"Spare keeps RNG, intents, outcome, attack passive and binding lifecycle: " + id)
	_check(support._pending.is_empty(), "consumed Spare selection cannot queue a second play")
	await _return()


func _select_sight(id: String, keyboard: bool) -> bool:
	var held := _panel(id)
	if keyboard:
		for iteration in range(app.deck.hand.size() + 2):
			await _key(KEY_P)
			if attack._armed == held:
				break
	else:
		await _mouse(held)
	_check(attack._armed == held and attack._bindings.has(held),
		"real mouse/P selects held Sight Glass: " + id)
	return attack._armed == held


func _sight(id: String, keyboard: bool, stacked: bool = false) -> void:
	if not await _start(id):
		return
	_display(id, true)
	var position := 2 if stacked else 1
	if stacked:
		_check(app.enemies.apply_statuses({position: {"exposed": 1}}),
			"authentic enemy status service applies existing Exposed")
	if not await _select_sight(id, keyboard):
		await _return()
		return
	var before := _state()
	var forecast: String = attack.cue.text
	var old_exposed: int = before[6][position - 1].get("statuses", {}).get("exposed", 0)
	_check(forecast.contains("Exposed %d → %d" % [old_exposed, old_exposed + 2])
		and forecast.contains("draw 1 card") and not forecast.to_lower().contains("damage"),
		"live choice previews stacked Exposed and draw without fictitious hit: " + id)
	_check(_state() == before and not attack._play._tinker._consumed,
		"nonmutating forecast leaves seeded run and attack passive intact")
	if keyboard:
		await _key(KEY_2 if position == 2 else KEY_1)
	else:
		await _mouse(app.get_node("LiveEnemyRoster")._labels[position - 1])
	var expected_hand: Array = before[1].duplicate()
	_check(not before[0].is_empty(), "seeded deck has next drawable card")
	expected_hand.append(before[0].back())
	expected_hand.erase(id)
	var expected_draw: Array = before[0].duplicate()
	expected_draw.pop_back()
	var expected_discard: Array = before[2].duplicate()
	expected_discard.append(id)
	var enemies: Array = before[6].duplicate(true)
	if not enemies[position - 1].has("statuses"):
		enemies[position - 1]["statuses"] = {}
	enemies[position - 1]["statuses"]["exposed"] = old_exposed + 2
	var after := _state()
	_check(after[0] == expected_draw and after[1] == expected_hand
		and after[2] == expected_discard and after[3] == int(before[3]) - 1
		and after[5] == before[5] and after[6] == enemies,
		"one Sight Glass: exact drawn card, spent energy and only chosen enemy Exposed: " + id)
	_check(after.slice(7) == before.slice(7) and not attack._play._tinker._consumed
		and attack.last_event.get("exposed_applied") == 2
		and attack.last_event.get("target") == position and attack._armed == null,
		"Sight leaves RNG, intent, enemy HP, Tinker first attack and pending choice intact: " + id)
	var settled := _state()
	await _key(KEY_1)
	_check(_state() == settled, "consumed Sight Glass cannot replay a selection")
	# A genuine subsequent starter attack still receives Tinker's FIRST-attack bonus.
	if id == "tinker_sight_glass_plus":
		app.deck.draw_pile.append("tinker_pop_shot")
		_check(app.deck.draw_extra(1) == 1, "draw real starter attack after Glass")
		app._refresh_hand()
		await _frames()
		_check(await _select_sight_attack(), "real Tinker attack panel is selected")
		var hp_before: int = app.enemies.get_enemy(1).hp
		await _key(KEY_1)
		var damage: int = int(StarterCards.new().get_definition("tinker_pop_shot").effects.damage) + 3
		_check(app.enemies.get_enemy(1).hp == hp_before - damage
			and attack._play._tinker._consumed,
			"first genuine Tinker attack after Glass still gains its +3 passive")
	await _return()


func _select_sight_attack() -> bool:
	var panel := _panel("tinker_pop_shot")
	if panel == null:
		return false
	await _mouse(panel)
	return attack._armed == panel


func _rejections() -> void:
	for mode in ["spare_downed", "spare_front", "sight_energy", "sight_downed", "sight_front", "sight_slain", "sight_inactive", "sight_absent"]:
		var sight: bool = mode.begins_with("sight")
		var id := "tinker_sight_glass" if sight else "tinker_spare_parts"
		if not await _start(id):
			return
		if mode.ends_with("front"):
			for start in [2, 1]:
				var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, start, 1)
				_check(swap.ok, "authentic movement preview is valid: " + mode)
				if swap.ok:
					app.party._heroes.assign(swap.heroes)
			_check(_owner() == 1, "Tinker really occupies illegal front: " + mode)
			app._refresh_party()
		elif mode.ends_with("downed"):
			_check(app.party.apply_damage(3, 10000) and app.party.is_downed(3),
				"Tinker really downed: " + mode)
		elif mode == "sight_energy":
			app.deck.combat_state.energy = 0
		elif mode == "sight_slain":
			_check(app.enemies.apply_damage(2, 10000) and app.enemies.is_slain(2),
				"selected enemy truly slain")
		elif mode == "sight_inactive":
			app.deck.combat_state.player_turn_active = false
		elif mode == "sight_absent":
			_check(app.deck.discard_played(id), "held Sight removed via real deck")
			app._refresh_hand()
		await _frames()
		var before := _state()
		if sight:
			if mode in ["sight_inactive", "sight_absent"]:
				if mode == "sight_inactive":
					await _mouse(_panel(id))
			else:
				await _select_sight(id, false)
			await _key(KEY_2 if mode == "sight_slain" else KEY_1)
		else:
			await _mouse(_panel(id))
		_check(_state() == before, "illegal or absent gadget never charges, draws or mutates: " + mode)
		await _return()


func _cancellation() -> void:
	if not await _start("tinker_sight_glass_plus"):
		return
	var held := _panel("tinker_sight_glass_plus")
	await _mouse(held)
	var before := _state()
	await _key(KEY_ESCAPE)
	_check(attack._armed == null and attack._selected == null, "Esc removes pending enemy choice")
	await _key(KEY_1)
	_check(_state() == before, "cancelled enemy selection remains entirely inert")
	# A queued same-frame choice is invalidated by Return and cannot touch the old battle.
	await _mouse(held)
	var old_deck: CombatDeck = app.deck
	var old_hand := old_deck.hand.duplicate()
	var old_energy := old_deck.energy
	var old_enemies: Array = app.enemies.get_enemies()
	var old_enemy_model: CombatEnemies = app.enemies
	attack._queue_attack(1)
	_check(attack._queued, "legal live selection is queued")
	app.return_button.pressed.emit()
	await _frames()
	_check(old_deck.hand == old_hand and old_deck.energy == old_energy
		and old_enemy_model.get_enemies() == old_enemies and app.deck == null,
		"Return cancels queued commit before any old-battle spend")
	_check(await _start("tinker_spare_parts_plus"), "new battle draws its own utility")
	var fresh := _panel("tinker_spare_parts_plus")
	_check(fresh != null and support._bindings.has(fresh)
		and not attack._bindings.has(fresh) and not support._bindings.has(held),
		"restart only binds fresh held instances")
	await _return()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	support = app.get_node_or_null("LiveSupportHand")
	attack = app.get_node_or_null("LiveAttackPreview")
	_check(support != null and attack != null and app.deck == null,
		"real title scene mounts both hand presenters")
	if support != null and attack != null:
		for id in SPARE + SIGHT:
			_check(TinkerPoolCards.new().get_definition(id).get("id") == id
				and not CombatAttackTargeting.ATTACK_IDS.has(id),
				"authored nonattack does not enter starter attack IDs: " + id)
		for index in range(SPARE.size()):
			await _spare(SPARE[index], index == 1, index == 1, index == 1)
		for index in range(SIGHT.size()):
			await _sight(SIGHT[index], index == 1, index == 1)
		await _rejections()
		await _cancellation()
	app.free()
	for failure in failures:
		printerr(failure)
	print("live_tinker_pool_gadgets_hand_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
