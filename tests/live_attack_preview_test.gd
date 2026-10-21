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
	var attacker_statuses: Dictionary = {}
	for hero in app.party.get_heroes():
		if hero.id == definition.owner:
			attacker_statuses = hero.get("statuses", {})
	var target_statuses := {}
	for enemy in app.enemies.get_enemies():
		target_statuses[enemy.position] = enemy.get("statuses", {})
	# The independent expected text uses the production forecast and the pure
	# confirmed-hit adapter, never the presenter's string-formatting routine.
	var forecast: Dictionary = presenter._play.forecast_attack(app.deck, app.party, app.enemies,
		id, attacker_statuses, target_statuses)
	var applied: Dictionary = CombatOnHitStatuses.new().status_for_confirmed_hit(id, true) if forecast.playable else {}
	var slots: PackedStringArray = []
	for hit in forecast.hits:
		var description := "%d: %d damage" % [hit.position, hit.damage]
		for status in applied:
			var previous: int = target_statuses[hit.position].get(status, 0)
			description += " (%s %d → %d on confirmed hit)" % [
				status.capitalize(), previous, previous + applied[status]]
		slots.append(description)
	var description := "Unavailable: no legal targets or energy"
	if forecast.playable:
		description = ("Choose one enemy slot: " if forecast.requires_selection else "All enemies in slots: ") + "; ".join(slots)
	var controls := "P / click card; 1-3 / click enemy" if definition.target_kind == "enemy_single" else "P: select; Enter / Space / click card: cast"
	return "%s | %d energy | %s\n%s" % [definition.display_name, definition.cost, controls, description]


func _assert_preview(id: String) -> void:
	if "--inject-wrong-cue" in OS.get_cmdline_user_args():
		presenter.cue.text = "wrong"
	_check(is_instance_valid(presenter._selected) and presenter._bindings.has(presenter._selected)
		and presenter._card_id(presenter._selected) == id, "mounted event selected actual held attack: " + id)
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
			_check(panel.gui_input.get_connections().size() == 1, "all held attacks bind real panel input")
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
				if card in CombatAttackTargeting.ATTACK_IDS:
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
	await _forecast_statuses()
	await _exact_on_hit_stacks()
	await _duplicate_instances()
	await _paid_move_refresh()
	await _negative_cases()
	await _attacks()
	await _status_lifecycle()
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
				var owner_position: int = {"warden": 1, "seamstress": 2, "tinker": 3}[catalog.get_definition(id).owner]
				app.party._heroes[owner_position - 1]["statuses"] = {"weak": 1}
				app.enemies._enemies[position - 1]["statuses"] = {"exposed": 1}
				await _frames()
				await _choose(id, keyboard)
				var before := _snapshot()
				_check(app.deck.hand.has(id) and app.deck.energy >= 1
					and app.enemies.get_enemy(position).block == 2,
					"held attack has affordable cost and living blocked target: " + id)
				var definition := catalog.get_definition(id)
				var damage: int = definition.effects.damage + (3 if definition.owner == "tinker" else 0)
				# Combined Weak/Exposed floors only once (Pop 9, Prick 3, Bash 9).
				damage = int(damage * 9 / 8)
				var expected := before.duplicate(true)
				expected[0].erase(id)
				expected[2].append(id)
				expected[3] -= definition.cost
				expected[6][position - 1].block = 0
				expected[6][position - 1].hp -= damage - 2
				if id == "seamstress_prick":
					expected[6][position - 1].statuses.bleed = 3
				elif id == "warden_shield_bash":
					expected[6][position - 1].statuses.weak = 1
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


func _status_lifecycle() -> void:
	for id in ["seamstress_prick", "warden_shield_bash"]:
		var replay: Array = []
		for keyboard in [false, true]:
			if not await _start(_seed_for(id)):
				return
			var status: String = "bleed" if id == "seamstress_prick" else "weak"
			var amount: int = 3 if status == "bleed" else 1
			# A durable fixture lets the real owner boundary run until expiry.
			app.enemies._enemies[0]["max_hp"] = 100
			app.enemies._enemies[0]["hp"] = 100
			_check(app.enemies.gain_block(1, 100), "living blocked status recipient")
			for attempt in range(2):
				app.deck.hand.assign([id])
				app.deck.combat_state.energy = 3
				app._refresh_hand()
				await _frames()
				await _choose(id, keyboard)
				if keyboard:
					await _key(KEY_1)
				else:
					await _click(app.get_node("LiveEnemyRoster")._labels[0])
				_check(presenter.last_event.ok and presenter.last_event.hits[0].hp_loss == 0
					and app.enemies.get_enemy(1).statuses == {status: amount * (attempt + 1)}, "blocked mounted status application is additive exactly once")
				var after := _snapshot()
				await _key(KEY_1)
				_check(_snapshot() == after, "duplicate physical input cannot reapply status")
			app.party._heroes[0]["statuses"] = {"weak": 1}
			_check(app.enemies.apply_statuses({1: {"exposed": 1}}), "recipient Exposed before actual boundary")
			var hp := 100
			for remaining in range(amount * 2, 0, -1):
				var turn: int = app.enemy_intents._turn_index
				await _click(app.end_turn_button)
				if status == "bleed":
					hp -= remaining
				var expected := {status: remaining - 1} if remaining > 1 else {}
				_check(app.enemy_intents._turn_index == turn + 1 and app.enemies.get_enemy(1).hp == hp
					and app.enemies.get_enemy(1).statuses == expected, "real enemy owner tick reduces status then expires")
				_check(app.party.get_hero(1).statuses == {}, "real hero owner boundary expires Weak")
			var after_expiry := _snapshot()
			if replay.is_empty():
				replay = after_expiry
			else:
				_check(after_expiry == replay, "same-seed mouse/keyboard status and expiry replay")
			app.enemies._enemies[0]["hp"] = 1
			app.enemies._enemies[0]["block"] = 0
			app.deck.hand.assign([id])
			app.deck.combat_state.energy = 3
			app._refresh_hand()
			await _frames()
			await _choose(id, keyboard)
			if keyboard:
				await _key(KEY_1)
			else:
				await _click(app.get_node("LiveEnemyRoster")._labels[0])
			_check(app.enemies.is_slain(1) and app.enemies.get_enemy(1).position == 1
				and app.enemies.get_enemy(1).statuses == {status: amount}, "lethal mounted hit retains status in original slot")
			_check(presenter.last_event.hits[0].damage == catalog.get_definition(id).effects.damage,
				"expired Weak and Exposed no longer modify live damage")
			await _return()


func _rejections() -> void:
	for scenario in ["unselected", "hover", "wrong", "range", "slain", "energy", "downed", "position", "missing", "stale", "inactive", "terminal", "mismatch", "invalid_enemies", "queued_stale", "queued_turn", "status_overflow", "bad_owner_status", "bad_late_status"]:
		var id := "warden_shield_bash"
		if not await _start(_seed_for(id)):
			return
		var panel = _panel(id)
		if scenario == "hover":
			await _hover(panel)
		elif scenario != "unselected":
			await _choose(id, false)
		# Null-model cleanup removes enemy controls; keep the former physical target for that rejection.
		var target_point: Vector2 = app.get_node("LiveEnemyRoster")._labels[0].get_global_rect().get_center()
		if scenario == "energy":
			app.deck.combat_state.energy = 0
		elif scenario == "status_overflow":
			app.enemies._enemies[0]["statuses"] = {"weak": CombatEnemies.MAX_INT}
		elif scenario == "bad_owner_status":
			app.party._heroes[0]["statuses"] = {"weak": -1}
		elif scenario == "bad_late_status":
			app.enemies._enemies[1]["statuses"] = {"exposed": "1"}
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
		if scenario in ["status_overflow", "bad_owner_status", "bad_late_status"]:
			await _frames()
		if scenario in ["status_overflow", "bad_owner_status", "bad_late_status"]:
			_check(presenter.cue.text.contains("Unavailable") and not presenter.cue.text.contains(" damage"),
				"malformed authoritative statuses cannot display a damage forecast " + scenario)
		var before := _snapshot()
		var latch: bool = presenter._play._tinker._consumed
		seed(2345)
		var global_next := randi()
		seed(2345)
		await _key(KEY_2 if scenario == "wrong" else KEY_3 if scenario == "range" else KEY_1)
		if scenario == "invalid_enemies":
			var roster = app.get_node("LiveEnemyRoster")
			_check(roster._labels.is_empty() and roster._badges.is_empty() and roster.panel == null,
				"null authoritative enemies remove stale pointer targets")
			var motion := InputEventMouseMotion.new()
			motion.position = target_point
			root.push_input(motion, true)
			for pressed in [true, false]:
				var event := InputEventMouseButton.new()
				event.position = target_point
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = pressed
				root.push_input(event, true)
			await _frames()
		elif scenario != "range":
			await _click(app.get_node("LiveEnemyRoster")._labels[1 if scenario == "wrong" else 0])
		_check(_snapshot() == before, "complete no-spend snapshot " + scenario)
		_check(presenter._play._tinker._consumed == latch, "rejection preserves first-attack latch " + scenario)
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
			_assert_preview(id)
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
		var panel = _panel(id)
		presenter._armed = panel
		presenter._queued = true
		presenter._commit(panel, id, 1 if mode == "selected_target" else 0, presenter._token,
			app.party, app.enemies, app.battle_result, app.run_rng,
			presenter._turn + (1 if mode == "wrong_turn" else 0))
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
							_check(app.get_node("LiveAreaAttackAction").button == null, "no separate Bomb action")
							if keyboard:
								await _choose(id, true)
								var before := _snapshot()
								await _key(KEY_1)
								await _key(KEY_2)
								await _key(KEY_3)
								_check(_snapshot() == before, "Bomb ignores enemy slot selections")
								await _key(KEY_ENTER if session == 0 else KEY_SPACE)
							else:
								await _click(_panel(id))
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
	_check(app.enemies.get_enemy(1).statuses == {"bleed": 3}, "lethal mouse Prick persists Bleed on slain slot")
	_check(app.intent_label.text.contains("Enemy 2:") and not app.intent_label.text.contains("Enemy 1"), "next-frame intent removes killed enemy only")
	_check(app.battle_result.can_continue() and not app.result_label.is_visible_in_tree(), "first kill keeps battle active")
	await _choose(id, true)
	await _key(KEY_1)
	_check(app.enemies.get_enemy(2).hp == 1 and app.deck.energy == 2, "slain slot remains illegal without compaction")
	await _key(KEY_2)
	_check(app.enemies.is_victorious() and app.battle_result.is_finished() and not app.deck.turn_active, "last physical kill reaches actual victory closure")
	_check(app.enemies.get_enemy(2).statuses == {"bleed": 3}, "lethal keyboard Prick persists Bleed before victory")
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


func _forecast_statuses() -> void:
	for id in CombatAttackTargeting.ATTACK_IDS:
		var replay: Array = []
		for keyboard in [false, true]:
			if not await _start(_seed_for(id)):
				return
			for hero in app.party._heroes:
				if hero.id == catalog.get_definition(id).owner:
					hero["statuses"] = {"weak": 1}
			_check(app.enemies.apply_statuses({1: {"exposed": 1}}), "live distinct per-target status fixture")
			var before := _snapshot()
			var latch: bool = presenter._play._tinker._consumed
			seed(917)
			var next_global := randi()
			seed(917)
			if keyboard:
				await _choose(id, true)
			else:
				await _hover(_panel(id))
			_assert_preview(id)
			var text: String = presenter.cue.text
			_check(_snapshot() == before and presenter._play._tinker._consumed == latch
				and randi() == next_global, "physical status forecast is pure")
			# Refresh the same selected cue from fresh snapshots without another selection.
			for hero in app.party._heroes:
				if hero.id == catalog.get_definition(id).owner:
					hero["statuses"] = {}
			await _frames()
			_assert_preview(id)
			_check(presenter.cue.text != text, "cue refresh observes owner status expiry")
			for hero in app.party._heroes:
				if hero.id == catalog.get_definition(id).owner:
					hero["statuses"] = {"weak": 1}
			await _frames()
			_assert_preview(id)
			var forecast_text: String = presenter.cue.text
			if id == "tinker_scrap_bomb":
				if keyboard:
					await _key(KEY_SPACE)
				else:
					await _click(_panel(id))
			else:
				await _choose(id, keyboard)
				if keyboard:
					await _key(KEY_1)
				else:
					await _click(app.get_node("LiveEnemyRoster")._labels[0])
			_check(presenter.last_event.ok and not presenter.last_event.hits.is_empty(), "forecast followed by actual physical attack")
			for hit in presenter.last_event.hits:
				var base: int = catalog.get_definition(id).effects.damage + (3 if id.begins_with("tinker_") else 0)
				_check(hit.damage == int(floor(base * (1.125 if hit.position == 1 else 0.75)))
					and forecast_text.contains("%d: %d" % [hit.position, hit.damage]),
					"live forecast damage equals actual Weak/Exposed status hit")
			var trace := [text, presenter.last_event.duplicate(true), _snapshot()]
			if replay.is_empty():
				replay = trace
			else:
				_check(trace == replay, "physical forecast/status/attack replay")
			await _return()


func _exact_on_hit_stacks() -> void:
	# Controlled held IDs, but mounted scene, resolver, and physical enemy
	# selection remain the production ones. Never alter the starting deck.
	for id in ["seamstress_prick", "warden_shield_bash"]:
		var status := "bleed" if id == "seamstress_prick" else "weak"
		var addition := 3 if status == "bleed" else 1
		var cost: int = catalog.get_definition(id).cost
		for existing in [0, 2] if status == "bleed" else [0, 1]:
			if not await _start(_seed_for(id)):
				return
			app.deck.hand.assign([id])
			app.deck.combat_state.energy = 3
			app._refresh_hand()
			_check(app.enemies.gain_block(1, 10), "status fixture has blocked live recipient")
			var applications := {1: {"exposed": 1}}
			if existing > 0:
				applications[1][status] = existing
			_check(app.enemies.apply_statuses(applications), "actual enemy counter fixture admitted")
			for hero in app.party._heroes:
				if hero.id == catalog.get_definition(id).owner:
					hero["statuses"] = {"weak": 1}
			await _frames()
			var panel = _panel(id)
			_check(panel != null and panel.gui_input.get_connections().size() == 1,
				"one held status attack input path: " + id)
			await _hover(panel)
			_assert_preview(id)
			var before := _snapshot()
			var forecast: Dictionary = presenter._resolve_attack(app.party, app.enemies, id, 0, true)
			var actual_addition: Dictionary = CombatOnHitStatuses.new().status_for_confirmed_hit(id, true)
			_check(forecast.playable and not forecast.hits.is_empty()
				and actual_addition == {status: addition}, "live forecast and pure confirmed-hit adapter agree")
			var hit_damage: int = forecast.hits[0].damage
			_check(presenter.cue.text.contains("1: %d damage (%s %d → %d on confirmed hit)" % [
				hit_damage, status.capitalize(), existing, existing + addition]),
				"precise selected legal slot damage and additive counter")
			if id == "seamstress_prick":
				_check(forecast.hits.size() >= 2 and presenter.cue.text.contains(
					"2: %d damage (Bleed 0 → 3 on confirmed hit)" % forecast.hits[1].damage),
					"Prick shows other living legal slot independently")
			# No preview, keyboard cycling, hover or unsupported target mutates
			# deck, statuses, intent, outcome or seeded RNG.
			seed(478)
			var global_next := randi()
			seed(478)
			await _key(KEY_P)
			await _hover(panel)
			await _key(KEY_3)
			_check(_snapshot() == before and randi() == global_next,
				"noncommitting inputs preserve full state and global RNG")
			# Re-arm after any invalid attempt, then select the real target.
			await _choose(id, true)
			var expected := before.duplicate(true)
			expected[0].erase(id)
			expected[2].append(id)
			expected[3] -= cost
			expected[6][0].block -= mini(10, hit_damage)
			expected[6][0].hp -= maxi(0, hit_damage - 10)
			expected[6][0]["statuses"][status] = existing + addition
			await _key(KEY_1)
			_check(_snapshot() == expected, "complete actual confirmed attack transaction with additive stack: " + id)
			_check(presenter.last_event.ok and presenter.last_event.hits.size() == 1
				and presenter.last_event.hits[0].statuses == actual_addition
				and presenter.last_event.hits[0].damage == hit_damage,
				"committed resolver matches forecast and pure status payload")
			await _return()


func _duplicate_instances() -> void:
	var id := "seamstress_prick"
	if not await _start(_seed_for(id)):
		return
	app.deck.hand.assign([id, id])
	app.deck.combat_state.energy = 3
	app._refresh_hand()
	await _frames()
	var first := app.hand_view.get_child(0) as Control
	var second := app.hand_view.get_child(1) as Control
	_check(first != second and first.get_child(0).text == id and second.get_child(0).text == id,
		"controlled duplicate held IDs occupy two real distinct card panels")
	for panel in [first, second]:
		_check(presenter._bindings.has(panel) and panel.gui_input.get_connections().size() == 1
			and panel.mouse_entered.get_connections().size() == 1
			and panel.mouse_exited.get_connections().size() == 1,
			"each duplicate owns one independent input, enter and leave callback")
	var before := _snapshot()
	await _hover(first)
	_check(presenter._selected == first, "hover selects first actual copy")
	await _key(KEY_P)
	_check(presenter._selected == second and presenter._armed == second,
		"P selects second real copy instead of deduplicating IDs")
	_assert_preview(id)
	await _key(KEY_P)
	_check(presenter._selected == first and presenter._armed == first,
		"P wraps to first real copy")
	await _hover(second)
	_check(presenter._selected == second, "hover independently updates second copy")
	_check(_snapshot() == before, "duplicate hover/cycle leaves every model unchanged")
	await _click(second)
	await _key(KEY_1)
	_check(app.deck.hand.count(id) == 1 and app.deck.discard_pile.count(id) == before[2].count(id) + 1
		and app.deck.energy == 2 and app.enemies.get_enemy(1).get("statuses", {}).get("bleed", 0) == 3,
		"playing second copy commits exactly one charge, discard and Bleed stack")
	_check(not presenter._bindings.has(first) and not presenter._bindings.has(second),
		"hand redraw drops obsolete duplicate listeners")
	await _return()


func _paid_move_refresh() -> void:
	var replay: Array = []
	for session in range(2):
		if not await _start(_seed_for("warden_shield_bash")):
			return
		# This is the actual paid adjacent-move card and held Shield Bash,
		# supplied in the current hand without changing the starter catalog.
		app.deck.hand.assign(["warden_backstep", "warden_shield_bash"])
		app.deck.combat_state.energy = 3
		app._refresh_hand()
		await _frames()
		_check(app.party.get_hero(1).id == "warden" and app.party.get_hero(2).id == "seamstress",
			"starting live owner positions allow Warden's paid adjacent backstep")
		var bash: Control = _panel("warden_shield_bash")
		var move: Control = _panel("warden_backstep")
		_check(move != null and bash != null and targeting.get_preview(
			app.deck, app.party, app.enemies, "warden_shield_bash").playable,
			"both move and attack are real held cards, Bash initially playable")
		await _hover(bash)
		_assert_preview("warden_shield_bash")
		var legal_description: String = presenter.cue.text
		var before := _snapshot()
		await _click(move)
		_check(app.deck.energy == before[3] - 1 and app.deck.hand == ["warden_shield_bash"]
			and app.deck.discard_pile.count("warden_backstep") == before[2].count("warden_backstep") + 1,
			"real paid adjacent move charges and discards once")
		_check(app.party.get_hero(2).id == "warden" and app.party.get_hero(1).id == "seamstress",
			"real move changes current hero positions")
		bash = _panel("warden_shield_bash")
		_check(bash != null, "Bash remains held on refreshed panels after move")
		await _hover(bash)
		_assert_preview("warden_shield_bash")
		_check(presenter.cue.text.contains("Unavailable") and not presenter.cue.text.contains("on confirmed hit")
			and presenter.cue.text != legal_description, "moved owner's rejected Bash never promises Weak")
		var moved := _snapshot()
		await _click(bash)
		await _key(KEY_1)
		_check(_snapshot() == moved, "invalid post-move attack never spends or applies a stack")
		var trace := [legal_description, presenter.cue.text, moved]
		if replay.is_empty():
			replay = trace
		else:
			_check(trace == replay, "same-seed paid move and refreshed attack rejection replay")
		await _return()
