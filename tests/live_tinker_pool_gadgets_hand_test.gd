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


## The v3 pool service is the only payment/effect authority. The physical card arrives
## through CombatDeck.draw_extra and the same mounted hand as all legacy cards.
func _v3_meter(expected: int) -> void:
	var meters = app.get_node_or_null("LiveCombatMeters")
	_check(meters != null and is_instance_valid(meters.row), "combat ribbons remain mounted")
	if meters == null or not is_instance_valid(meters.row):
		return
	var slot := _owner()
	_check(slot > 0, "Tinker has an actual party slot for Combat Scrap HUD")
	if slot == 0:
		return
	var label := meters.row.get_node_or_null("hero%d/Padding/Content/CombatScrap" % slot) as Label
	_check(label != null and label.is_visible_in_tree()
		and label.text == "Combat Scrap: %d" % expected
		and label.tooltip_text.contains("Not run-wallet scraps"),
		"real Tinker actor ribbon displays authoritative Combat Scrap %d" % expected)
	_check(app.party.get_hero(slot).get("combat_scrap", 0) == expected,
		"CombatParty snapshot is the displayed counter authority")
	for other in range(1, 4):
		if other == slot:
			continue
		var other_label := meters.row.get_node_or_null("hero%d/Padding/Content/CombatScrap" % other) as Label
		_check(other_label != null and not other_label.visible,
			"Combat Scrap appears on Tinker only, not another actor")


func _v3_move_tinker(seat: int) -> void:
	for current in range(3, seat, -1):
		var swap: Dictionary = CombatPositionSwaps.preview_adjacent_swap(app.party, current - 1, 1)
		_check(swap.get("ok", false), "legal party swap moves Tinker toward requested seat")
		if not swap.get("ok", false):
			return
		app.party._heroes.assign(swap.heroes)
	app._refresh_party()
	await _frames()
	_check(_owner() == seat, "Tinker occupies actual desired seat %d" % seat)


func _v3_display(id: String) -> void:
	var panel := _panel(id)
	_check(panel != null, "v3 authentic held panel is physical: " + id)
	if panel == null:
		return
	var definition: Dictionary = V3TinkerPoolCards.new().get_definition(id)
	var facts: Dictionary = support._metadata.get_facts(panel)
	var from_text: String = "From 1–3" if id.begins_with("tinker_v3_gear") else "From 2–3"
	_check(not definition.is_empty() and definition.starting_copies == 0
		and facts.get("known") == true and facts.get("owner") == "tinker"
		and facts.get("display_name") == definition.display_name
		and facts.get("cost") == definition.cost and facts.get("cost_text") == "Cost %d" % definition.cost
		and facts.get("from_text") == from_text and facts.get("target_text") == "Self",
		"catalog exact name, cost, FROM, self/empty TO is mounted: " + id)
	_check(support._metadata.get_geometry(panel).has("frame")
		and support._metadata.TINKER == Color("#c49a3a")
		and panel.get_child(0).text == id and not panel.get_child(0).visible
		and panel.mouse_filter == Control.MOUSE_FILTER_STOP,
		"v3 preserves mustard-and-cream drawn fallback and physical sewn face: " + id)
	var block_amount: int = int(definition.effects.get("block", 0))
	_check(panel.tooltip_text.contains(definition.display_name)
		and panel.tooltip_text.contains("Combat Scrap")
		and panel.tooltip_text.contains("From " + ("1–3" if block_amount > 0 else "2–3"))
		and panel.tooltip_text.contains("Self")
		and panel.tooltip_text.contains("%d Block" % block_amount if block_amount > 0 else "draw 1 card"),
		"v3 tooltip accurately explains printed Block/Scrap/draw, seats, self: " + id)
	_check(support._bindings.has(panel) and not attack._bindings.has(panel)
		and panel.gui_input.get_connections().size() == 1,
		"only the live support presenter owns this card: " + id)
	_check(CombatTinkerV3ScrapSupportCards.is_authentic_definition(definition, id)
		and support._metadata.definition(id) == definition,
		"v3 screen metadata originates from exact authenticated source: " + id)


func _v3_play(id: String, keyboard: bool, key: Key, seat: int, empty_draw: bool = false,
		zero_energy: bool = false) -> void:
	if not await _start(id):
		return
	if seat != 3:
		await _v3_move_tinker(seat)
	if empty_draw:
		app.deck.draw_pile.clear()
		app.deck.discard_pile.clear()
	if zero_energy:
		app.deck.combat_state.energy = 0
	await _frames()
	_v3_display(id)
	_v3_meter(0)
	var held := _panel(id)
	if held == null:
		await _return()
		return
	var definition := V3TinkerPoolCards.new().get_definition(id)
	var before := _state()
	var wallet_before: int = app.run_scraps
	_check(support._eligible(held, id, app.deck, app.party, app.battle_view)
		and support._v3_tinker_scrap._prepare(app.deck, app.party, id, 0).get("ok", false),
		"exact authentic paid preflight on actual mounted card: " + id)
	if keyboard:
		held.grab_focus()
		await _key(key)
	else:
		await _mouse(held)
	var after := _state()
	var expected_heroes: Array = before[5].duplicate(true)
	expected_heroes[seat - 1]["combat_scrap"] = int(definition.effects.combat_scrap_gain)
	expected_heroes[seat - 1]["block"] += int(definition.effects.get("block", 0))
	var expected_hand: Array = before[1].duplicate()
	var expected_draw: Array = before[0].duplicate()
	if not empty_draw and int(definition.effects.get("draw", 0)) > 0:
		_check(not expected_draw.is_empty(), "authentic seeded shared draw supply is nonempty: " + id)
		if not expected_draw.is_empty():
			expected_hand.append(expected_draw.pop_back())
	expected_hand.erase(id)
	var expected_discard: Array = before[2].duplicate()
	expected_discard.append(id)

	_check(after[0] == expected_draw and after[1] == expected_hand
		and after[2] == expected_discard and after[3] == int(before[3]) - int(definition.cost)
		and after[5] == expected_heroes and after[6] == before[6],
		"exactly one paid v3 receipt: energy, draw-before-discard, own Block, own Scrap: " + id)
	_check(after.slice(7) == before.slice(7) and app.run_scraps == wallet_before
		and support._pending.is_empty() and app.hand_view.get_child_count() == app.deck.hand.size(),
		"v3 never changes run wallet, RNG, opponents, phase or hand lifecycle: " + id)
	await _frames()
	_v3_meter(int(definition.effects.combat_scrap_gain))
	# A former panel/input handler cannot replay the resolved transaction.
	var settled := _state()
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	support._on_card_input(event, held, id, app.deck, app.party, app.battle_view)
	await _frames()
	_check(_state() == settled, "a committed v3 card cannot replay on a stale panel")
	await _return()


func _v3_rejections() -> void:
	for mode in ["gear_empty_energy", "gear_downed", "gear_missing", "gear_inactive",
			"screws_front", "screws_empty_energy", "screws_downed",
			"screws_absent", "screws_closed", "screws_mismatch", "screws_bad_counter"]:
		var gear: bool = mode.begins_with("gear")
		var id := "tinker_v3_gear_brace" if gear else "tinker_v3_spare_screws"
		if not await _start(id):
			return
		if mode == "screws_front":
			await _v3_move_tinker(1)
		elif mode.ends_with("energy"):
			app.deck.combat_state.energy = 0
		elif mode.ends_with("downed"):
			_check(app.party.apply_damage(3, 10000) and app.party.is_downed(3),
				"v3 downed Tinker is real")
		elif mode.ends_with("missing"):
			app.party._heroes[2]["id"] = "not_tinker"
		elif mode.ends_with("inactive"):
			app.deck.combat_state.player_turn_active = false
		elif mode.ends_with("absent"):
			_check(app.deck.discard_played(id), "v3 card actually leaves the real hand")
			app._refresh_hand()
		elif mode.ends_with("closed"):
			app._battle_closed = true
		elif mode.ends_with("mismatch"):
			support._v3_tinker_scrap._catalog._definitions[id]["effects"]["draw"] = 7
		elif mode.ends_with("counter"):
			app.party._heroes[2]["combat_scrap"] = -1
		await _frames()
		var before := _state()
		var wallet_before: int = app.run_scraps
		var held := _panel(id)
		if held != null:
			var accepted: bool = support._eligible(held, id, app.deck, app.party, app.battle_view)
			_check(not accepted, "v3 illegal mounted panel preflight declines: " + mode)
			await _mouse(held)
		_check(_state() == before and app.run_scraps == wallet_before,
			"v3 rejected input is pure no-spend, no-draw, no-hero, no-RNG: " + mode)
		if mode == "gear_empty_energy":
			app.deck.combat_state.energy = 1
			await _frames()
			var retry := _panel(id)
			_check(retry != null and support._eligible(retry, id, app.deck, app.party, app.battle_view),
				"rejected unaffordable v3 card becomes playable after real energy recovery")
			var prior_scrap: int = int(app.party.get_hero(_owner()).get("combat_scrap", 0))
			await _mouse(retry)
			_check(app.party.get_hero(_owner()).get("combat_scrap", 0) == prior_scrap + 1,
				"real retry commits once after rejection")
		await _return()

	# A fake V3 spelling remains readable as unknown, but is never admitted or charged.
	var unknown := "tinker_v3_gear_brace_counterfeit"
	if await _start(unknown):
		var panel := _panel(unknown)
		var before := _state()
		_check(panel != null and support._metadata.definition(unknown).is_empty()
			and support._metadata.describe(unknown).get("known") == false
			and not support._bindings.has(panel) and not attack._bindings.has(panel),
			"unknown V3 card record remains fail-closed in mounted hand")
		await _mouse(panel)
		_check(_state() == before, "unrecognized physical card cannot spend or draw")
		await _return()
	var authentic := V3TinkerPoolCards.new().get_definition("tinker_v3_gear_brace")
	var counterfeit := authentic.duplicate(true)
	counterfeit["effects"]["block"] = 999
	_check(not CombatTinkerV3ScrapSupportCards.is_authentic_definition(
		counterfeit, "tinker_v3_gear_brace"),
		"spoofed V3 effects cannot authenticate, even with a genuine card ID")


func _v3_retired_and_fresh() -> void:
	if not await _start("tinker_v3_gear_brace"):
		return
	var old_panel := _panel("tinker_v3_gear_brace")
	var old_callback: Callable = support._bindings[old_panel]
	var old_deck: CombatDeck = app.deck
	var old_party: CombatParty = app.party
	var old_hand := old_deck.hand.duplicate()
	var old_energy := old_deck.energy
	var old_heroes := old_party.get_heroes()
	await _return()
	_check(await _start("tinker_v3_spare_screws_plus"),
		"fresh battle starts with independently drawn V3 card")
	_v3_meter(0)
	var stale := InputEventMouseButton.new()
	stale.button_index = MOUSE_BUTTON_LEFT
	stale.pressed = true
	old_callback.call(stale)
	await _frames()
	_check(old_deck.hand == old_hand and old_deck.energy == old_energy
		and old_party.get_heroes() == old_heroes
		and not support._bindings.has(old_panel),
		"old retired GUI callback cannot spend even after a fresh battle mounts")
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
		for id in ["tinker_v3_gear_brace", "tinker_v3_gear_brace_plus",
				"tinker_v3_spare_screws", "tinker_v3_spare_screws_plus"]:
			_check(CombatTinkerV3ScrapSupportCards.scrap_support_definition(id).get("id") == id,
				"required V3 printed form authentic in paid service: " + id)
		await _v3_play("tinker_v3_gear_brace", false, KEY_SPACE, 3)
		await _v3_play("tinker_v3_gear_brace_plus", true, KEY_ENTER, 1)
		await _v3_play("tinker_v3_spare_screws", false, KEY_SPACE, 2)
		await _v3_play("tinker_v3_spare_screws_plus", true, KEY_SPACE, 3, true, true)
		await _v3_rejections()
		await _v3_retired_and_fresh()
		await _cancellation()
	app.free()
	for failure in failures:
		printerr(failure)
	print("live_tinker_pool_gadgets_hand_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
