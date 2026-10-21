extends "res://tests/live_shop_continuation_test.gd"
## Real connected input, typed-entry oracle, atomic rejection, and terminal latch.


func _path_to(map: RunMap, source: String, kind: String) -> Array:
	for id in map.get_node(source).outgoing:
		var node := map.get_node(id)
		if node.type == kind:
			return [id]
		if node.type in ["Rest", "Shop", "Event", "Treasure"]:
			var tail := _path_to(map, id, kind)
			if not tail.is_empty():
				return [id] + tail
	return []


func _battle_fixture(kind: String) -> Dictionary:
	for value in range(1, 3000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for id in map.get_legal_choices():
			if map.get_node(id).type != "Fight":
				continue
			var path := _path_to(map, id, kind)
			if kind == "Fight" and path.size() != 1:
				continue
			if path.is_empty():
				continue
			map.choose_node(id)
			var selected := RunFightEncounterSelection.new().select_current_fight(map, rng, app.FIGHT_ENCOUNTER_PATHS)
			if selected.get("encounter_id") == "starter_attacks":
				return {"seed": value, "fight": id, "path": path}
			map.undo_choice(id, [])
	return {}


func _entry_state() -> Array:
	return [_persistent(), app.party, app.enemies, app.deck, app.round_flow,
		app.battle_result, app.enemy_intents, app.encounter_id, app.battle_view,
		app.hero_view, app.hero_panels.duplicate(), app.route_view, app.route_buttons.duplicate(),
		app.party_carryover, app.party_carryover.read_state(), app.fight_selection,
		app.fight_selection._bound_map, app.fight_selection._selected.duplicate(true),
		app.act_outcome.get_state(), app.fight_rewards, app.fight_reward_claimed,
		app.run_removal_count, app.shop_visit.get_state() if app.shop_visit != null else {},
		app.rest_recovery.is_consumed() if app.rest_recovery != null else false,
		app.get_node("LiveEnemyRoster").panel, app.terminal_result_panel,
		app.terminal_result_panel.get_presented_status() if app.terminal_result_panel != null else "",
		app.terminal_result_panel.return_button.disabled if app.terminal_result_panel != null else true]


func _reject_entry(callback: Callable, reason: String) -> void:
	var before := _entry_state()
	callback.call()
	_check(_entry_state() == before, reason + " preserves all mounted and persistent state")


func _oracle(id: String) -> Dictionary:
	var map := RunMap.new()
	map._floor_ids = app.run_map._floor_ids.duplicate(true)
	map._nodes = app.run_map._nodes.duplicate(true)
	map._route = app.run_map.get_route()
	_check(map.choose_node(id), "oracle uses a genuinely adjacent generated node")
	var rng := RandomNumberGenerator.new()
	rng.state = app.run_rng.state
	var selector := RunFightEncounterSelection.new()
	selector._bound_map = map
	selector._selected = app.fight_selection._selected.duplicate(true)
	var entry := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, selector)
	_check(entry.get("success", false), "authored typed entry oracle succeeds")
	if not entry.get("success", false):
		return {}
	var party: CombatParty = app.party_carryover.create_next_fight_party()
	var deck := CombatDeck.new(app.run_deck, rng)
	var result := CombatBattleResult.new(party, entry.enemies)
	var flow := CombatRoundFlow.new(deck, party, entry.enemies, entry.intents, result)
	_check(flow.begin_fight(), "independent carried-party battle begins")
	return {"heroes": party.get_heroes(), "enemies": entry.enemies.get_enemies(),
		"intents": entry.intents.get_intents(), "encounter": entry.encounter_id,
		"hand": deck.hand.duplicate(), "draw": deck.draw_pile.duplicate(), "rng": rng.state}


func _mounted_state() -> Dictionary:
	return {"heroes": app.party.get_heroes(), "enemies": app.enemies.get_enemies(),
		"intents": app.enemy_intents.get_intents(), "encounter": app.encounter_id,
		"hand": app.deck.hand.duplicate(), "draw": app.deck.draw_pile.duplicate(), "rng": app.run_rng.state}


func _visit_path(path: Array, keyboard: bool) -> void:
	for id in path:
		var button := _route_action(id)
		if button == null:
			return
		if keyboard:
			button.grab_focus()
			await _key(KEY_ENTER)
		else:
			await _click(button)
		match app.run_map.get_node(id).type:
			"Rest":
				await _click(app.rest_heal_button)
				await _click(app.rest_continue_button)
			"Shop":
				await _click(app.shop_continue_button)
		_check(app.route_view != null and app.route_view.is_visible_in_tree(), "completed visit keeps connected chooser live")


func _formation_win(fixture: Dictionary) -> bool:
	# A deterministic combat fixture covers carried downed/status/permuted actors;
	# the two normal sessions below win their predecessor with actual held inputs.
	app.run_seed = fixture.seed
	await _click(app.route_button)
	await _click(_route_action(fixture.fight))
	_check(app.party != null and app.enemies != null, "formation fixture starts real routed battle")
	if app.party == null:
		return false
	var formation := CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
	_check(formation.ok, "fixture moves Warden to middle")
	app.party._heroes.assign(formation.heroes)
	_check(app.party.apply_damage(1, 7) and app.party.apply_damage(3, 999), "fixture carries injured and downed heroes")
	app.party._heroes[0].statuses = {"weak": 2, "bleed": 1}
	_check(app.party.gain_block(2, 13), "fixture grants transit Block that must be discarded")
	for enemy in app.enemies.get_enemies():
		_check(app.enemies.apply_damage(enemy.position, 999), "fixture defeats each actual enemy")
	app._observe_battle_result()
	_check(app._battle_closed and app.fight_rewards != null, "legal predecessor victory recorded by app")
	return app._battle_closed and app.fight_rewards != null


func _click(control: Control) -> void:
	if is_instance_valid(control):
		_check(Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()),
			"routed mouse action fits viewport: %s %s" % [control.name, control.get_global_rect()])
	await super._click(control)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var retained: Array[Callable] = []
	for kind in ["Fight", "Elite", "Boss"]:
		var fixture := _battle_fixture(kind)
		_check(not fixture.is_empty(), "generated connected path reaches " + kind)
		if fixture.is_empty():
			continue
		var replay: Dictionary = {}
		for session in range(3 if kind == "Fight" else 2):
			seed(690069)
			var global_next := randi()
			seed(690069)
			var won: bool = await _formation_win(fixture) if session == 2 else await _routed_win(fixture, false)
			if not won:
				break
			await _click(app.reward_buttons[0])
			var old_end: Callable = app.end_turn_button.pressed.get_connections()[0].callable
			var old_return: Callable = app.return_button.pressed.get_connections()[0].callable
			var old_reward: Callable = app.reward_buttons[0].pressed.get_connections()[0].callable
			var old_continue: Callable = app.continue_button.pressed.get_connections()[0].callable
			await _click(app.continue_button)
			var path: Array = fixture.path.duplicate()
			var id: String = path.pop_back()
			await _visit_path(path, session == 1)
			var button := _route_action(id)
			if button == null:
				break
			_check(not button.disabled and button.is_visible_in_tree(), kind + " connected choice is actionable")
			var callback: Callable = button.pressed.get_connections()[0].callable
			var map: RunMap = app.run_map
			var prior: Array[String] = map.get_route()
			_reject_entry(old_return, "hidden predecessor Return")
			_reject_entry(app._choose_battle_route.bind(id, weakref(RunMap.new()), prior, button), "foreign map")
			var empty: Array[String] = []
			_reject_entry(app._choose_battle_route.bind(id, weakref(map), empty, button), "stale route")
			_reject_entry(app._choose_battle_route.bind(id, weakref(map), prior, app.route_back_button), "forged control")
			_reject_entry(app._choose_battle_route.bind(prior[0], weakref(map), prior, button), "nonadjacent ID")
			button.disabled = true
			_reject_entry(callback, "disabled choice")
			button.disabled = false
			button.hide()
			_reject_entry(callback, "hidden choice")
			button.show()
			var edges: Array = map._nodes[prior.back()].outgoing.duplicate()
			map._nodes[prior.back()].outgoing.erase(id)
			_reject_entry(callback, "disconnected choice")
			map._nodes[prior.back()].outgoing = edges
			map._nodes[id].type = "Unknown"
			_reject_entry(callback, "malformed kind")
			map._nodes[id].type = kind
			var saved_floor: Variant = map._nodes[id].floor
			map._nodes[id].floor = -1
			_reject_entry(callback, "malformed battle floor")
			map._nodes[id].floor = saved_floor
			var saved_choices: Dictionary = app.fight_selection._selected.duplicate(true)
			app.fight_selection._selected[id] = {"success": true, "node_type": kind,
				"encounter_id": "unknown_encounter", "definitions": []}
			_reject_entry(callback, "malformed cached authored entry")
			app.fight_selection._selected = saved_choices
			var cards: Array[String] = app.run_deck.duplicate()
			app.run_deck.append("not_a_card")
			_reject_entry(callback, "malformed carried deck")
			app.run_deck.assign(cards)
			app.run_heroes[0].hp -= 1
			_reject_entry(callback, "ledger mismatch")
			app.run_heroes = app.party_carryover.read_state().heroes
			# This fails AFTER typed selection and deck shuffle, proving full rollback.
			app.act_outcome._settled_node_ids.append(id)
			_reject_entry(callback, "post-selection outcome admission failure")
			app.act_outcome._settled_node_ids.erase(id)
			for stale in retained:
				_reject_entry(stale, "previous session callback")
			var expected_entry := _oracle(id)
			if expected_entry.is_empty():
				break
			var persistent: Array = [app.run_heroes.duplicate(true), app.run_deck.duplicate(), app.session_gold,
				app.party_carryover.read_state(), app.run_removal_count]
			var old_models: Array = [app.party, app.enemies, app.deck, app.battle_result, app.round_flow, app.enemy_intents]
			var old_view_id: int = app.battle_view.get_instance_id()
			var rng: RandomNumberGenerator = app.run_rng
			var selector: RunFightEncounterSelection = app.fight_selection
			if session == 1:
				app.route_back_button.grab_focus()
				for step in range(app.route_buttons.size() + 1):
					await _key(KEY_TAB)
					if button.has_focus():
						break
				_check(button.has_focus(), "physical Tab reaches typed battle button")
				await _key(KEY_SPACE if kind == "Elite" else KEY_ENTER)
			else:
				await _click(button)
			_check(app.run_map == map and map.get_route() == prior + [id] and app.route_view == null, "one input mounts chosen connected battle")
			_check(app.run_rng == rng and app.fight_selection == selector and app.deck._rng == rng, "same run RNG and selector retained")
			_check(_mounted_state() == expected_entry, "complete mounted state matches typed-entry/round-flow oracle")
			_check([app.run_heroes, app.run_deck, app.session_gold, app.party_carryover.read_state(), app.run_removal_count] == persistent, "entry preserves persistent deck, heroes, ledger and gold")
			_check(not is_instance_id_valid(old_view_id) and app.hero_panels.size() == 3 and app.reward_buttons.is_empty() and app.continue_button == null, "obsolete battle controls disposed")
			var new_models: Array = [app.party, app.enemies, app.deck, app.battle_result, app.round_flow, app.enemy_intents]
			for index in range(new_models.size()):
				_check(new_models[index] != old_models[index], "fresh authoritative model " + str(index))
			var roster = app.get_node("LiveEnemyRoster")
			_check(roster.enemies == app.enemies and roster.panel.is_visible_in_tree() and roster._labels.size() == app.enemies.get_enemies().size(), "accepted presenter mounts replacement roster")
			_check(app.deck.hand.size() == 5 and app.deck.energy == 3 and app.deck.turn_active and app.hand_view.get_child_count() == 5, "real playable first hand")
			if session == 2:
				_check(app.party.get_hero(2).id == "warden" and app.party.get_hero(2).block == 6 and app.party.get_hero(1).statuses == {"weak": 2, "bleed": 1} and app.party.is_downed(3), "carried formation HP/status/downed and current-slot opening Block")
			var before := _entry_state()
			_check(not app.round_flow.begin_fight() and _entry_state() == before, "opening bonus is once only")
			for stale in [callback, old_end, old_return, old_reward, old_continue]:
				_reject_entry(stale, "stale previous-battle/duplicate input")
			if session < 2:
				if session == 0:
					replay = _mounted_state()
				else:
					_check(_mounted_state() == replay, "fixed seed mouse/keyboard replay matches full mounted battle")
			# Prove a real held attack uses the replacement actors and hand.
			var played := false
			for held in app.deck.hand.duplicate():
				var preview := CombatAttackTargeting.new().get_preview(app.deck, app.party, app.enemies, held)
				if preview.playable and preview.requires_selection:
					var energy: int = app.deck.energy
					var enemy_before: Array = app.enemies.get_enemies()
					if await _choose(held, session == 1):
						await _key(KEY_1 if preview.target_positions[0] == 1 else KEY_2)
						_check(app.deck.energy < energy and app.deck.discard_pile.has(held) and app.enemies.get_enemies() != enemy_before, "held attack spends and damages actual reentered roster")
						played = true
					break
			if session < 2:
				_check(played, "fresh hand supplies valid held attack: %s session %d" % [kind, session])
			await _click(app.end_turn_button)
			_check(app.enemy_intents._turn_index == 1 or app._battle_closed, "real enemy phase executes replacement intents")
			if session == 1:
				for position in range(1, 4):
					app.party.apply_damage(position, 9999)
			else:
				for enemy in app.enemies.get_enemies():
					app.enemies.apply_damage(enemy.position, 9999)
			app._observe_battle_result()
			await _frames()
			_check(app._battle_closed and app.end_turn_button.disabled and app.result_label.visible, "true terminal battle result closes controls")
			var outcome: String = CombatBattleResult.DEFEAT if session == 1 else CombatBattleResult.VICTORY
			_check(app.battle_result.get_outcome() == outcome and app.result_label.text.contains(outcome), "visible true result")
			var run_status: String = RunActBattleOutcome.DEFEAT if session == 1 else (RunActBattleOutcome.VICTORY if kind == "Boss" else RunActBattleOutcome.ACTIVE)
			_check(app.act_outcome.get_state().run_status == run_status and app.act_outcome.get_state().settled_node_ids.count(id) == 1, "run defeat/Boss victory latched once")
			if run_status != RunActBattleOutcome.ACTIVE:
				_check(app.result_label.text.contains("Run defeat" if session == 1 else "Run victory"), "visible run defeat or Boss victory")
				var panel: LiveRunTerminalResultPanel = app.terminal_result_panel
				var title: String = "Victory" if run_status == RunActBattleOutcome.VICTORY else "Defeat"
				var description: String = ("The final boss has fallen. The run is complete."
					if title == "Victory" else "The party has fallen. The run has ended.")
				var panels: Array = app.find_children("*", "LiveRunTerminalResultPanel", true, false)
				_check(panel != null and panel.get_parent() == app and panel.is_visible_in_tree()
					and panel.has_open_result() and panels.size() == 1 and panels[0] == panel,
					"terminal outcome mounts exactly one top-level panel")
				_check(panel != null and panel.title_label.text == title
					and panel.description_label.text == description
					and panel.get_presented_status() == run_status
					and panel.return_button.has_focus() and not panel.return_button.disabled
					and app.return_button.disabled and app.end_turn_button.disabled,
					"witnessed " + title + " has real distinct screen and sole focused Return")
				_check(app.act_outcome.get_state().pending_node_id == ""
					and not app.act_outcome.get_state().settled_node_ids.is_empty()
					and app.act_outcome.get_state().settled_node_ids.back() == id
					and (title != "Victory" or (map.get_current_floor() == 12
						and map.get_node(id).type == "Boss")),
					"terminal screen follows settled authoritative chosen node")
				var terminal_before := _entry_state()
				app._terminal_return_connection.call()
				app.return_button.pressed.emit()
				app._mount_terminal_result()
				_check(_entry_state() == terminal_before and app.terminal_result_panel == panel
					and app.find_children("*", "LiveRunTerminalResultPanel", true, false).size() == 1,
					"forged callback, legacy Return and repeat mount are inert")
			else:
				_check(app.terminal_result_panel == null
					and app.find_children("*", "LiveRunTerminalResultPanel", true, false).is_empty(),
					"settled nonterminal Fight/Elite never publishes panel")
			if kind in ["Fight", "Elite"] and outcome == CombatBattleResult.VICTORY:
				_check(app.multi_fight_rewards != null and app.reward_buttons.size() == 4 and app.continue_button == null and app.session_gold == persistent[2] and app.run_deck == persistent[1], "later Fight/Elite prepares rewards without payment")
			else:
				_check(app.reward_buttons.is_empty() and app.fight_rewards == null and app.multi_fight_rewards == null and app.continue_button == null and app.session_gold == persistent[2] and app.run_deck == persistent[1], "Boss/defeat gain no rewards or continuation")
				_check(app.run_trinkets.is_empty(), "Boss/defeat never grants an Elite trinket")
			before = _entry_state()
			app._observe_battle_result()
			app._observe_battle_result()
			_check(_entry_state() == before, "duplicate terminal observation is inert")
			retained = [callback, old_end, old_return, old_reward, old_continue]
			if run_status == RunActBattleOutcome.ACTIVE:
				await _click(app.return_button)
			else:
				var terminal_request: Callable = app._terminal_return_connection
				var old_panel: LiveRunTerminalResultPanel = app.terminal_result_panel
				if session == 1:
					await _key(KEY_SPACE)
				else:
					await _click(old_panel.return_button)
				_check(not is_instance_valid(old_panel) and app.terminal_result_panel == null
					and not app._terminal_return_connection.is_valid(),
					"terminal screen and host callback removed after real Return")
				retained.append(terminal_request)
			_check(app.title_view.visible and app.run_map == null and app.deck == null and app.run_rng == null and app.fight_selection == null and app.run_heroes.is_empty() and app._carryover_route.is_empty(), "clean title and restart state")
			_check(app.session_gold == 0 and app.run_deck.is_empty() and app.run_trinkets.is_empty()
				and app.card_reward == null and app.multi_fight_rewards == null
				and app.act_outcome == null and app.party_carryover == null
				and app.route_view == null and app.terminal_result_panel == null,
				"terminal/title cleanup leaves no inventory, reward, ledger or overlay")
			_check(randi() == global_next, "connected battle never consumes global RNG")
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_routed_battle_reentry_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
