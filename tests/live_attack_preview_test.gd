extends SceneTree

var failures: Array[String] = []
var checks := 0
var app
var presenter
var catalog := StarterCards.new()
var targeting := CombatAttackTargeting.new()


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _frames() -> void:
	for frame in range(4):
		await process_frame


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _hover(control: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(2, 2)
	root.push_input(motion, true)
	await _frames()
	motion = InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	_check(root.get_visible_rect().has_point(motion.position), "physical hover within viewport")
	root.push_input(motion, true)
	await _frames()


func _click(control: Control) -> void:
	await _hover(control)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _panel(id: String):
	for panel in app.hand_view.get_children():
		if panel.get_child(0).text == id:
			return panel
	return null


func _snapshot() -> Array:
	return [app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(), app.deck.discard_pile.duplicate(),
		app.deck.energy, app.deck.turn_active, app.party.get_heroes(), app.enemies.get_enemies() if app.enemies != null else null,
		app.enemy_attacks.duplicate(true), app.enemy_intents.get_intents(), app.enemy_intents._turn_index,
		app.run_rng.seed, app.run_rng.state, app.battle_result.get_outcome()]


func _seed_for(id: String) -> int:
	var cards: Array[String] = []
	cards.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
	for candidate in range(1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		var deck := CombatDeck.new(cards, rng)
		deck.start_turn()
		if id in deck.hand:
			return candidate
	_check(false, "seeded opening found: " + id)
	return -1


func _start(seed_value: int) -> bool:
	app.run_seed = seed_value
	await _click(app.start_button)
	var valid: bool = app.deck != null and app.party != null and app.enemies != null \
		and app.battle_result != null and is_instance_valid(presenter.cue)
	_check(valid, "actual title start mounts cue with complete models")
	if valid:
		_check(app.deck.turn_active and not presenter._bindings.is_empty(), "real active opening with bound attacks")
		var count := 0
		for child in app.hand_view.get_parent().get_children():
			if child.name == "AttackPreviewCue":
				count += 1
		_check(count == 1, "exactly one battle-local cue")
	return valid


func _return() -> void:
	await _click(app.return_button)
	_check(app.deck == null and presenter.cue == null and presenter._bindings.is_empty(), "Return clears cue and bindings")


func _expected(id: String) -> String:
	var definition := catalog.get_definition(id)
	var preview := targeting.get_preview(app.deck, app.party, app.enemies, id)
	var slots: PackedStringArray = []
	for position in preview.target_positions:
		slots.append(str(position))
	var description := "Unavailable: no legal targets"
	if preview.playable:
		description = ("Choose one enemy slot: " if preview.requires_selection else "All enemies in slots: ") + ", ".join(slots)
	return "%s | %d energy | P / click card; 1-3 / click enemy\n%s" % [definition.display_name, definition.cost, description]


func _assert_preview(id: String) -> void:
	if "--inject-wrong-cue" in OS.get_cmdline_user_args():
		presenter.cue.text = "wrong"
	_check(presenter._selected == _panel(id), "mounted event selected actual held attack: " + id)
	_check(presenter.cue.text == _expected(id), "exact catalog name/cost and service targets: " + id)
	_check(presenter.cue.is_visible_in_tree() and root.get_visible_rect().encloses(presenter.cue.get_global_rect()), "cue readable at 1280x720")
	_check(presenter.cue.get_line_count() <= 2, "cue fits two readable lines")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node_or_null("LiveAttackPreview")
	_check(presenter != null, "app itself mounts preview presenter")
	if presenter == null:
		app.free()
		_finish()
		return
	_check(presenter.cue == null, "no cue on title")
	for id in CombatAttackTargeting.ATTACK_IDS:
		var replay: Array = []
		for session in range(2):
			if not await _start(_seed_for(id)):
				app.free()
				_finish()
				return
			var panel = _panel(id)
			_check(panel != null, "authored attack really held: " + id)
			if panel == null:
				await _return()
				continue
			_check(panel.gui_input.get_connections().size() == (1 if id != "tinker_scrap_bomb" else 0), "single attacks bind selection; bomb stays separate")
			_check(panel.mouse_entered.get_connections().size() == 1, "one hover binding per panel")
			var before := _snapshot()
			seed(8123)
			var expected_global := randi()
			seed(8123)
			await _hover(panel)
			_assert_preview(id)
			var trace: Array = [presenter.cue.text]
			var held: Array[String] = []
			for card in app.deck.hand:
				if card in CombatAttackTargeting.ATTACK_IDS and card not in held:
					held.append(card)
			for step in range(held.size() * 2):
				await _key(KEY_P)
				var next_id: String = held[(held.find(id) + step + 1) % held.size()]
				_assert_preview(next_id)
				trace.append(presenter.cue.text)
			_check(randi() == expected_global, "previews do not consume global RNG")
			_check(_snapshot() == before, "repeated physical previews preserve complete battle state")
			if session == 0:
				replay = trace
			else:
				_check(trace == replay, "same seed restart reproduces preview trace")
			# Rebuild invalidates selected panels, and new panels get exactly one binding.
			var old = panel
			var callback: Callable = presenter._bindings[old].entered
			app.hand_view.remove_child(old)
			app._refresh_hand()
			await _frames()
			_check(old.mouse_entered.get_connections().is_empty(), "obsolete live panel disconnected")
			callback.call()
			_check(presenter._selected == null, "captured obsolete hover cannot select rebuilt hand")
			old.free()
			await _hover(_panel(id))
			_assert_preview(id)
			_check(_snapshot() == before, "rebuild and stale callback preserve rules state")
			await _return()
	await _negative_cases()
	await _attacks()
	await _rejections()
	await _tinker_turns()
	await _bomb_entry_guards()
	await _mixed_tinker_turns()
	await _kills()
	await _stale_restart()
	await _controls()
	app.free()
	_finish()


func _negative_cases() -> void:
	for scenario in ["energy", "downed", "position", "slain", "absent_target", "missing", "inactive", "terminal", "hidden", "invalid"]:
		var id := "tinker_scrap_bomb" if scenario in ["slain", "absent_target"] else "warden_shield_bash"
		if not await _start(_seed_for(id)):
			return
		await _hover(_panel(id))
		_assert_preview(id)
		_check(targeting.get_preview(app.deck, app.party, app.enemies, id).playable, "negative starts with legal targets: " + scenario)
		if scenario == "energy":
			app.deck.combat_state.energy = 0
		elif scenario == "downed":
			_check(app.party.apply_damage(1, 10000) and app.party.is_downed(1), "owner truly downed")
		elif scenario == "position":
			var definitions: Array = app._load_party_definitions()
			var warden = definitions.pop_front()
			definitions.append(warden)
			app.party = CombatParty.new(definitions)
			app.battle_result = CombatBattleResult.new(app.party, app.enemies)
			_check(app.party.get_hero(3).id == "warden", "owner truly moved to forbidden position")
		elif scenario == "slain":
			_check(app.enemies.apply_damage(1, 10000) and app.enemies.is_slain(1), "slot one slain, slot two survives")
			_check(targeting.get_preview(app.deck, app.party, app.enemies, id).target_positions == [2], "slain slot is not compacted")
		elif scenario == "absent_target":
			app.enemies = CombatEnemies.new([app._load_enemy_definitions()[0]])
			app.battle_result = CombatBattleResult.new(app.party, app.enemies)
			_check(app.enemies.is_valid() and app.enemies.get_enemy(2).is_empty(), "valid roster with absent slot two")
			_check(targeting.get_preview(app.deck, app.party, app.enemies, id).target_positions == [1], "absent target excluded")
		elif scenario == "missing":
			_check(app.deck.discard_played(id), "selected card removed from authoritative hand")
		elif scenario == "inactive":
			app.deck.combat_state.player_turn_active = false
		elif scenario == "terminal":
			for enemy in app.enemies.get_enemies():
				app.enemies.apply_damage(enemy.position, 10000)
			await _frames()
			_check(app.battle_result.is_finished(), "terminal result observed in actual app")
		elif scenario == "hidden":
			app.battle_view.hide()
		elif scenario == "invalid":
			app.enemies = null
		var before: Array = _snapshot() if app.enemies != null else []
		# Let the normal presenter observe the change without another input.
		await _frames()
		if not before.is_empty():
			_check(_snapshot() == before, "state refresh never mutates surviving models: " + scenario)
		if scenario in ["energy", "downed", "position", "slain", "absent_target"]:
			_assert_preview(id)
			if scenario in ["energy", "downed", "position"]:
				_check(presenter.cue.text.contains("Unavailable") and not presenter.cue.text.contains("enemy slot:"), "no stale legal targets: " + scenario)
		else:
			_check(presenter._selected == null and not presenter.cue.text.contains("enemy slot:") and not presenter.cue.text.contains("All enemies"), "cue cleared: " + scenario)
		if scenario == "energy":
			app.deck.combat_state.energy = 3
			await _frames()
			_assert_preview(id)
		app.battle_view.show()
		await _return()


func _choose(id: String, keyboard: bool) -> void:
	if keyboard:
		for index in range(CombatAttackTargeting.ATTACK_IDS.size() + 1):
			await _key(KEY_P)
			if presenter._card_id(presenter._armed) == id:
				break
	else:
		await _click(_panel(id))
	_check(presenter._card_id(presenter._armed) == id, "physical selection armed " + id)


func _attacks() -> void:
	for id in ["warden_strike", "warden_shield_bash", "seamstress_prick", "tinker_pop_shot"]:
		var replay: Array = []
		for keyboard in [false, true]:
			for session in range(2):
				if not await _start(_seed_for(id)):
					return
				var position := 1 if id == "warden_shield_bash" else 2
				_check(app.enemies.gain_block(position, 2), "target has real Block")
				await _frames()
				await _choose(id, keyboard)
				var before := _snapshot()
				_check(app.deck.hand.has(id) and app.deck.energy >= 1
					and app.enemies.get_enemy(position).block == 2,
					"held attack has affordable cost and living blocked target: " + id)
				var definition := catalog.get_definition(id)
				var damage: int = definition.effects.damage + (3 if definition.owner == "tinker" else 0)
				var expected := before.duplicate(true)
				expected[0].erase(id)
				expected[2].append(id)
				expected[3] -= definition.cost
				expected[6][position - 1].block = 0
				expected[6][position - 1].hp -= damage - 2
				seed(8123)
				var global_next := randi()
				seed(8123)
				if keyboard:
					# Duplicate presses within one dispatch still commit only once.
					for duplicate in range(2):
						var event := InputEventKey.new()
						event.keycode = KEY_1 if position == 1 else KEY_2
						event.pressed = true
						root.push_input(event, true)
					await _frames()
				else:
					await _click(app.get_node("LiveEnemyRoster")._labels[position - 1])
				_check(_snapshot() == expected, "exact full data-driven transition " + id)
				_check(app.deck.hand.count(id) == before[0].count(id) - 1
					and app.deck.discard_pile.count(id) == before[2].count(id) + 1,
					"one physical activation spends exactly one held copy: " + id)
				_check(randi() == global_next, "attack preserves global RNG " + id)
				var statuses := {}
				for status in ["weak", "bleed"]:
					if definition.effects.has(status):
						statuses[status] = definition.effects[status]
				if id == "seamstress_prick":
					statuses.bleed += 1 # Authored Seamstress passive on confirmed hit.
				_check(presenter.last_event == {"ok": true, "hits": [{"position": position,
					"damage": damage, "block_absorbed": 2, "hp_loss": damage - 2, "statuses": statuses}]}, "authored hit event " + id)
				var roster = app.get_node("LiveEnemyRoster")
				var enemy: Dictionary = app.enemies.get_enemy(position)
				_check(roster._labels[position - 1].text.contains("HP: %d/%d | Block: 0" % [enemy.hp, enemy.max_hp]), "mounted enemy reflects hit")
				var meter = app.get_node("LiveCombatMeters").row.get_child(3 + position - 1)
				_check(meter.hp_text.text == "HP: %d/%d" % [enemy.hp, enemy.max_hp] and meter.block_text.text == "Block: 0" and meter.hp_bar.value == enemy.hp, "mounted meters reflect service hit")
				_check(app.hand_view.get_child_count() == app.deck.hand.size() and app.pile_label.text.contains("Discard: 1"), "mounted hand and piles refresh")
				_check(app.get_node("LiveSupportHand").energy_label.text.begins_with("Energy: %d |" % app.deck.energy), "mounted energy refresh")
				var after := _snapshot()
				await _key(KEY_1)
				await _click(roster._labels[position - 1])
				_check(_snapshot() == after, "consumed selection cannot double-cast")
				if replay.is_empty():
					replay = after
				else:
					_check(after == replay, "mouse/keyboard two-session deterministic replay " + id)
				await _return()


func _rejections() -> void:
	for scenario in ["unselected", "hover", "wrong", "range", "slain", "energy", "downed", "position", "missing", "stale", "inactive", "terminal", "mismatch", "invalid_enemies", "queued_stale", "queued_turn"]:
		var id := "warden_shield_bash"
		if not await _start(_seed_for(id)):
			return
		var panel = _panel(id)
		if scenario == "hover":
			await _hover(panel)
		elif scenario != "unselected":
			await _choose(id, false)
		if scenario == "energy":
			app.deck.combat_state.energy = 0
		elif scenario == "downed":
			_check(app.party.apply_damage(1, 10000), "down owner")
		elif scenario == "position":
			var definitions: Array = app._load_party_definitions()
			definitions.append(definitions.pop_front())
			app.party = CombatParty.new(definitions)
			app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		elif scenario == "slain":
			_check(app.enemies.apply_damage(1, 10000), "slain target")
			_check(app.enemies.get_enemy(2).position == 2 and not app.enemies.is_slain(2), "survivor retains slot two")
		elif scenario == "missing":
			_check(app.deck.discard_played(id), "remove actual held card")
		elif scenario == "inactive":
			app.deck.combat_state.player_turn_active = false
		elif scenario == "terminal":
			for enemy in app.enemies.get_enemies():
				app.enemies.apply_damage(enemy.position, 10000)
			await _frames()
		elif scenario == "mismatch":
			app.battle_result = CombatBattleResult.new(CombatParty.new(app._load_party_definitions()), app.enemies)
		elif scenario == "invalid_enemies":
			app.enemies = null
		elif scenario in ["stale", "queued_stale"]:
			if scenario == "queued_stale":
				presenter._queue_attack(1)
			app.hand_view.remove_child(panel)
			app._refresh_hand()
		elif scenario == "queued_turn":
			presenter._queue_attack(1)
			app.enemy_intents.advance_turn()
			app.enemy_attacks = app.enemy_intents.get_intents()
		var before := _snapshot()
		seed(2345)
		var global_next := randi()
		seed(2345)
		await _key(KEY_2 if scenario == "wrong" else KEY_3 if scenario == "range" else KEY_1)
		if scenario != "range":
			await _click(app.get_node("LiveEnemyRoster")._labels[1 if scenario == "wrong" else 0])
		_check(_snapshot() == before, "complete no-spend snapshot " + scenario)
		_check(randi() == global_next, "no global RNG consumption " + scenario)
		if scenario in ["stale", "queued_stale"]:
			panel.free()
		await _return()


func _tinker_turns() -> void:
	var id := "tinker_pop_shot"
	if not await _start(_seed_for(id)):
		return
	var service = presenter._play
	for turn in range(2):
		_check(app.enemies.gain_block(2, 30), "living target withstands repeated bonus probes")
		# Keep real live models and use the mounted hand after controlled turn fixtures.
		app.deck.hand.assign([id, id])
		app.deck.combat_state.energy = 3
		app._refresh_hand()
		await _frames()
		for attack in range(2):
			await _choose(id, false)
			await _key(KEY_2)
			_check(presenter.last_event.ok and presenter.last_event.hits[0].damage == (8 if attack == 0 else 5), "Tinker bonus once each real player turn")
		_check(presenter._play == service, "service lifetime spans hand rebuilds and turn")
		if turn == 0:
			await _click(app.end_turn_button)
			_check(app.enemy_intents._turn_index == 1, "real End Turn boundary")
	await _return()


func _bomb_entry_guards() -> void:
	var id := "tinker_scrap_bomb"
	if not await _start(_seed_for(id)):
		return
	var service = presenter._play
	_check(service._tinker.bonus_for_attack(id) == 3, "guard probes start with pending bonus")
	for mode in ["selected_target", "wrong_turn", "bound_session", "hidden_hand"]:
		var original_session: Array = presenter._session.duplicate()
		if mode == "bound_session":
			presenter._session = []
		elif mode == "hidden_hand":
			app.hand_view.hide()
		var before := _snapshot()
		var event: Dictionary = presenter.last_event.duplicate(true)
		_check(not presenter.play_scrap_bomb(app.deck, app.party, app.enemies, app.battle_result,
			app.run_rng, presenter._turn + (1 if mode == "wrong_turn" else 0),
			1 if mode == "selected_target" else 0), "guarded Bomb entry rejects " + mode)
		_check(_snapshot() == before and presenter.last_event == event
			and service._tinker.bonus_for_attack(id) == 3, "entry rejection preserves state, event and pending bonus " + mode)
		presenter._session = original_session
		app.hand_view.show()
	await _return()


func _mixed_tinker_turns() -> void:
	var bomb := "tinker_scrap_bomb"
	var pop := "tinker_pop_shot"
	var cards: Array[String] = []
	cards.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
	var chosen := -1
	for candidate in range(1000):
		var probe_rng := RandomNumberGenerator.new()
		probe_rng.seed = candidate
		var probe := CombatDeck.new(cards, probe_rng)
		probe.start_turn()
		if bomb in probe.hand and pop in probe.hand:
			chosen = candidate
			break
	_check(chosen >= 0, "seeded opening naturally holds both Tinker attacks")
	if chosen < 0:
		return
	var previous_service
	for bomb_first in [true, false]:
		var replay: Array = []
		for keyboard in [false, true]:
			for session in range(2):
				if not await _start(chosen):
					return
				_check(bomb in app.deck.hand and pop in app.deck.hand, "both authored cards held before physical permutation")
				var service = presenter._play
				_check(service != previous_service and service._tinker.bonus_for_attack(bomb) == 3,
					"Return/restart creates a fresh pending bonus after prior consumed session")
				previous_service = service
				var rng := RandomNumberGenerator.new()
				rng.seed = chosen
				var deck := CombatDeck.new(cards, rng)
				var party := CombatParty.new(app._load_party_definitions())
				var enemies := CombatEnemies.new(app._load_enemy_definitions())
				var intents := CombatEnemyIntents.new(app._load_enemy_schedule())
				var result := CombatBattleResult.new(party, enemies)
				var flow := CombatRoundFlow.new(deck, party, enemies, intents, result)
				_check(flow.begin_fight(), "independent complete seeded fight starts")
				var oracle := CombatAttackCards.new()
				for position in [1, 2]:
					_check(app.enemies.gain_block(position, 40) and enemies.gain_block(position, 40),
						"living Block fixtures allow two complete mixed turns")
				var trace: Array = []
				for turn in range(2):
					oracle.start_player_turn()
					if turn == 1:
						# Supply the same controlled second hand on the real, advanced session.
						app.deck.hand.assign([bomb, pop])
						deck.hand.assign([bomb, pop])
						app._refresh_hand()
						await _frames()
					_check(presenter._play == service and service._tinker.bonus_for_attack(bomb) == 3,
						"same attack service, fresh first-attack bonus at actual turn boundary")
					var order := [bomb, pop] if bomb_first else [pop, bomb]
					for index in range(2):
						var id: String = order[index]
						var damage: int = [7, 5][index] if bomb_first else [8, 4][index]
						var event := oracle.play_attack(deck, party, enemies, id, 0 if id == bomb else 2)
						_check(event.ok, "independent shared service accepts permutation step")
						if id == bomb:
							var action = app.get_node("LiveAreaAttackAction")
							_check(is_instance_valid(action.button) and not action.button.disabled,
								"actual target-free Bomb action available")
							if not is_instance_valid(action.button):
								await _return()
								return
							if keyboard:
								action.button.grab_focus()
								await _key(KEY_ENTER if session == 0 else KEY_SPACE)
							else:
								await _click(action.button)
						else:
							await _choose(id, keyboard)
							if keyboard:
								await _key(KEY_2)
							else:
								await _click(app.get_node("LiveEnemyRoster")._labels[1])
						_check(presenter.last_event == event and event.hits[0].damage == damage,
							"physical Bomb/Pop order deals exact authored damage with one shared bonus")
						_check([app.deck.hand, app.deck.draw_pile, app.deck.discard_pile, app.deck.energy,
							app.deck.turn_active, app.party.get_heroes(), app.enemies.get_enemies(),
							app.run_rng.state, app.enemy_intents.get_intents()] == [deck.hand, deck.draw_pile,
							deck.discard_pile, deck.energy, deck.turn_active, party.get_heroes(),
							enemies.get_enemies(), rng.state, intents.get_intents()],
							"complete live permutation transition matches independent shared transaction")
						_check(service == presenter._play and service._tinker.bonus_for_attack(bomb) == 0,
							"hand refresh never replaces consumed attack state")
						trace.append(_snapshot())
					_check(app.deck.energy == 0, "mixed turn spends exactly three energy")
					if turn == 0:
						_check(flow.end_turn(), "oracle advances same real round flow")
						await _click(app.end_turn_button)
						_check(app.enemy_intents._turn_index == 1 and app.deck.energy == 3,
							"physical End Turn advances and refills real player turn")
				if replay.is_empty():
					replay = trace
				else:
					_check(trace == replay, "both mixed turns replay identically after Return across mouse/Enter/Space")
				await _return()


func _kills() -> void:
	var id := "seamstress_prick"
	if not await _start(_seed_for(id)):
		return
	app.deck.hand.assign([id, id])
	app._refresh_hand()
	for position in [1, 2]:
		_check(app.enemies.apply_damage(position, 11), "living enemy prepared at one HP")
	await _frames()
	await _choose(id, false)
	await _click(app.get_node("LiveEnemyRoster")._labels[0])
	_check(app.enemies.is_slain(1) and app.enemies.get_enemy(2).hp == 1 and app.enemies.get_enemy(2).position == 2, "first physical kill preserves live slot two")
	_check(app.intent_label.text.contains("Enemy 2:") and not app.intent_label.text.contains("Enemy 1"), "next-frame intent removes killed enemy only")
	_check(app.battle_result.can_continue() and not app.result_label.is_visible_in_tree(), "first kill keeps battle active")
	await _choose(id, true)
	await _key(KEY_1)
	_check(app.enemies.get_enemy(2).hp == 1 and app.deck.energy == 2, "slain slot remains illegal without compaction")
	await _key(KEY_2)
	_check(app.enemies.is_victorious() and app.battle_result.is_finished() and not app.deck.turn_active, "last physical kill reaches actual victory closure")
	_check(app.result_label.is_visible_in_tree() and app.result_label.text.contains(CombatBattleResult.VICTORY) and app.intent_label.text == "Intent: none", "next-frame result and intents reflect final kill")
	var before := _snapshot()
	await _key(KEY_2)
	_check(_snapshot() == before, "terminal key cannot attack")
	await _return()


func _stale_restart() -> void:
	var id := "warden_shield_bash"
	if not await _start(_seed_for(id)):
		return
	await _choose(id, false)
	var panel = _panel(id)
	var callback: Callable = presenter._bindings[panel].input
	var old_deck: CombatDeck = app.deck
	var old_party: CombatParty = app.party
	var old_enemies: CombatEnemies = app.enemies
	var old_rng: RandomNumberGenerator = app.run_rng
	var before := [old_deck.hand.duplicate(), old_deck.discard_pile.duplicate(), old_deck.energy,
		old_party.get_heroes(), old_enemies.get_enemies(), old_rng.state]
	var event := InputEventKey.new()
	event.keycode = KEY_1
	event.pressed = true
	root.push_input(event, true)
	_check(presenter._queued, "physical attack is actually queued before Return")
	# Physical Return in the same dispatch cancels the deferred attack.
	for pressed in [true, false]:
		var mouse := InputEventMouseButton.new()
		mouse.position = app.return_button.get_global_rect().get_center()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed
		root.push_input(mouse, true)
	await _frames()
	_check(app.deck == null, "physical Return completed before deferred attack")
	_check([old_deck.hand, old_deck.discard_pile, old_deck.energy,
		old_party.get_heroes(), old_enemies.get_enemies(), old_rng.state] == before, "queued Return preserves old models")
	if not await _start(_seed_for(id)):
		return
	var restarted := _snapshot()
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	callback.call(mouse)
	await _key(KEY_1)
	_check(_snapshot() == restarted, "captured freed card callback cannot act after restart")
	await _return()


func _controls() -> void:
	if not await _start(_seed_for("warden_brace")):
		return
	var brace = _panel("warden_brace")
	_check(brace != null and brace.focus_mode == Control.FOCUS_ALL and brace.gui_input.get_connections().size() == 1, "support input/focus preserved")
	var block: int = app.party.get_hero(1).block
	await _key(KEY_P)
	await _click(brace)
	_check(app.party.get_hero(1).block == block + 7 and app.deck.energy == 2 and not app.deck.hand.has("warden_brace"), "physical support play still works after preview")
	await _key(KEY_P)
	await _click(app.end_turn_button)
	_check(app.enemy_intents._turn_index == 1 and app.deck.turn_active and app.deck.energy == 3, "physical End Turn advances real battle")
	_check(presenter._selected == null, "End Turn rebuild clears selected preview")
	await _key(KEY_P)
	_check(presenter._selected != null, "new turn attacks reachable by P")
	await _return()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_attack_preview_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
