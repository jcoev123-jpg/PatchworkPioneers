extends SceneTree

const STARTER_ORACLE := preload("res://tests/starter_fight_oracle.gd")
const WIRED_ATTACK_IDS: Array[String] = [
	"warden_strike_plus",
	"warden_strike", "warden_shield_bash", "seamstress_prick",
	"tinker_pop_shot", "tinker_scrap_bomb"
]

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
	# Zero-starter-copy upgrades use a held original for this preview fixture.
	var opening_id := "warden_strike" if id == "warden_strike_plus" else id
	for candidate in range(1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		var deck := CombatDeck.new(cards, rng)
		deck.start_turn()
		if opening_id in deck.hand:
			return candidate
	_check(false, "seeded opening found: " + id)
	return -1


func _start(seed_value: int, held_id: String = "") -> bool:
	app.run_seed = seed_value
	_fixture_start(app)
	await _frames()
	# Keep every preview/status/replay assertion for upgraded attacks too. The
	# connected Rest -> real next-battle draw is covered by live_rest_upgrade_choice_test.
	if held_id == "warden_strike_plus" and app.deck != null:
		var upgrade := RunRestCardUpgrade.new(app.deck.hand, {"warden_strike": "warden_strike_plus"})
		var result := upgrade.choose_upgrade(app.deck.hand.find("warden_strike"))
		_check(result.ok, "preview fixture upgrades an actual held Strike copy")
		if not result.ok:
			return false
		app.deck.hand.assign(result.deck)
		app._refresh_hand()
		await _frames()
	var valid: bool = app.deck != null and app.party != null and app.enemies != null \
		and app.battle_result != null and is_instance_valid(presenter.cue)
	_check(valid, "actual title start mounts cue with complete models")
	if valid:
		_check(app.deck.turn_active and not presenter._bindings.is_empty(), "real active opening with bound attacks")
		_check(presenter.cue.text == "" and not presenter.cue.is_visible_in_tree(),
			"fresh battle cue is empty and collapsed")
		var count := 0
		for child in app.hand_view.get_parent().get_children():
			if child.name == "AttackPreviewCue":
				count += 1
		_check(count == 1, "exactly one battle-local cue")
		var combo_count := 0
		for child in app.hand_view.get_parent().get_children():
			if child.name == "ComboForecastCue":
				combo_count += 1
		_check(combo_count == 1 and is_instance_valid(app.combo_cue)
			and app.combo_cue.text == "" and not app.combo_cue.is_visible_in_tree()
			and app._combo_selected == null and app._combo_bindings.is_empty(),
			"fresh battle mounts one collapsed, unbound combo forecast cue")
	return valid


func _return() -> void:
	await _click(app.return_button)
	_check(app.deck == null and presenter.cue == null and presenter._bindings.is_empty(), "Return clears cue and bindings")
	_check(app.combo_cue == null and app._combo_selected == null and app._combo_bindings.is_empty(),
		"Return clears the combo forecast cue and bindings")


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
	for id in WIRED_ATTACK_IDS:
		var replay: Array = []
		for session in range(2):
			if not await _start(_seed_for(id), id):
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
	await _blind_mounted_attack()
	await _needle_mount_cases()
	await _monk_mount_cases()
	await _combo_route_case()
	await _combo_precast_bleed()
	await _combo_three_slots()
	await _combo_forecasts()
	await _combo_commits()
	await _combo_sequences()
	await _combo_deferred_rejections()
	await _combo_live_state()
	await _combo_rejections()
	await _combo_other_owner()
	await _forecast_statuses()
	await _exact_on_hit_stacks()
	await _duplicate_instances()
	await _drawn_drag_cards()
	await _paid_move_refresh()
	await _cue_strip()
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
	await _control_attack_patches()
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
				_check(roster._labels[position - 1].text == String(enemy.name),
					"mounted enemy name tag reflects hit")
				var meter = app.get_node("LiveCombatMeters").row.get_child(3 + position - 1)
				_check(meter.hp_text.text == "%d/%d" % [enemy.hp, enemy.max_hp] and meter.block_badge.visible == (enemy.block > 0) and meter.block_text.text == ("%d" % enemy.block if enemy.block > 0 else "") and meter.hp_bar.value == enemy.hp, "mounted meters reflect service hit")
				_check(app.hand_view.get_child_count() == app.deck.hand.size() and app.pile_label.text.contains("Discard: 1"), "mounted hand and piles refresh")
				_check(app.get_node("LiveSupportHand").energy_label.text == "%d" % app.deck.energy, "mounted energy refresh")
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
				# Mirror the real admission: the same authored roster/party/RNG binds
				# before the opening deal, so announcements match turn for turn.
				_check(intents.bind_battle(enemies, party, rng),
					"independent reference battle binds the same authored intents")
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
	var guard_announced: Dictionary = {}
	for action in app.enemy_intents.get_intents():
		if action.get("enemy_position") == 2:
			guard_announced = action
	_check(app.intent_label.text == STARTER_ORACLE.intent_text([guard_announced],
		["Warden", "Seamstress", "Tinker"]) and not app.intent_label.text.contains("Enemy 1"),
		"next-frame intent removes killed enemy only")
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



## Mount the actual app hand and the battle-owned ledger, not a direct resolver
## fixture. All chosen enemy IDs occur in the shipped enemy tier catalogs.
func _needle_mount(id: String, seat: int = 2, mode: String = "") -> bool:
	if not await _start(_seed_for("warden_strike")):
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = 5127
	app.run_rng = rng
	app.deck = CombatDeck.new([id, "warden_strike", "warden_brace",
		"tinker_pop_shot", "tinker_tune_up"], rng)
	_check(app.deck.start_turn() and app.deck.hand.has(id) and app.deck.energy == 3,
		"needle fixture starts a real seeded 5-card / 3-energy hand: " + id)
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 25}]
	heroes.insert(seat - 1, {"id": "yarn_ranger", "name": "Yarn Ranger", "max_hp": 27})
	app.party = CombatParty.new(heroes)
	app.enemies = CombatEnemies.new([
		{"id": "ragling", "name": "Ragling", "max_hp": 30},
		{"id": "ragling_guard", "name": "Guard Ragling", "max_hp": 30},
		{"id": "fray_scavenger", "name": "Fray Scavenger", "max_hp": 30}])
	if mode == "block":
		_check(app.enemies.gain_block(1, 50), "needle nonlethal foe has real Block")
	elif mode == "lethal":
		_check(app.enemies.apply_damage(1, 29), "needle lethal foe starts at 1 HP")
	elif mode == "statuses":
		app.party._heroes[seat - 1]["statuses"] = {"weak": 1}
		app.enemies._enemies[0]["statuses"] = {"exposed": 1, "tangled": 1}
		_check(app.enemies.gain_block(1, 2), "needle status case has Block")
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies,
		app.enemy_intents, app.battle_result)
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_hand()
	await _frames()
	var panel: Control = _panel(id)
	var ready: bool = panel != null and panel.is_visible_in_tree() \
		and presenter._bindings.has(panel) and presenter._unravel != null \
		and presenter._unravel._bound_enemies == app.enemies \
		and app.round_flow._enemies == app.enemies
	_check(ready, "needle held panel and real round-bound battle models: " + id)
	return ready


func _needle_state() -> Array:
	return [_snapshot(), presenter._unravel._gauges.duplicate(true),
		app.round_flow._unravel, presenter.last_event.duplicate(true),
		app.run_rng.state]


func _needle_arm(panel: Control, keyboard: bool) -> void:
	if keyboard:
		for i in range(9):
			await _key(KEY_P)
			if presenter._armed == panel:
				break
	else:
		await _click(panel)
	_check(presenter._armed == panel, "needle physical P / click binds exact panel")


func _needle_mount_cases() -> void:
	var damages := {"yarn_ranger_needle_nock": 4, "yarn_ranger_needle_nock_plus": 6,
		"yarn_ranger_needle_arrow": 5, "yarn_ranger_needle_arrow_plus": 7}
	for id in damages:
		for mode in ["plain", "block", "lethal", "statuses"]:
			if not await _needle_mount(id, 3 if id.ends_with("_plus") else 2, mode):
				await _return()
				continue
			var panel: Control = _panel(id)
			var quoted: Dictionary = presenter._target_preview(id)
			var original_gauge: CombatUnravel = presenter._unravel
			_check(quoted.playable and quoted.requires_selection and quoted.target_positions == [1, 2, 3]
				and quoted.hits.size() == 3 and quoted.hits[0].unravel == (2 if id.ends_with("_plus") else 1),
				"service preflight offers only three living printed needle targets: " + id)
			var before := _needle_state()
			var keyboard: bool = id.ends_with("_plus")
			await _needle_arm(panel, keyboard)
			_check(_needle_state() == before and presenter.current_forecast.get("hits", []).size() == 3
				and presenter.cue.text.contains("Unravel") and presenter.cue.text.contains("P / click"),
				"real P / mouse input gives honest per-slot forecast without charging")
			presenter._queue_attack(4)
			_check(not presenter._queued and _needle_state() == before,
				"never offer or queue enemy seat four")
			var first: Dictionary = app.enemies.get_enemy(1)
			var other: Array = app.enemies.get_enemies()
			var party_before: Array = app.party.get_heroes()
			var rng_before: int = app.run_rng.state
			var amount: int = damages[id]
			if mode == "statuses":
				amount = CombatStatuses.new().adjusted_attack_damage(amount,
					{"weak": 1}, {"exposed": 1, "tangled": 1})
			var absorbed: int = mini(first.block, amount)
			var loss: int = mini(first.hp, amount - absorbed)
			if keyboard:
				await _key(KEY_1)
			else:
				await _click(app.get_node("LiveEnemyRoster")._labels[0])
			var receipt: Dictionary = presenter.last_event
			var new_gauge: Dictionary = original_gauge.get_snapshot(1)
			var added: int = 0 if loss == first.hp else (2 if id.ends_with("_plus") else 1)
			_check(receipt.get("ok", false) and receipt.get("damage") == amount
				and receipt.get("block_absorbed") == absorbed
				and receipt.get("hp_loss") == loss and receipt.get("unravel_added") == added,
				"one authentic paid needle status/Block hit and post-hit Unravel: " + id + " " + mode)
			_check(app.enemies.get_enemy(1).hp == first.hp - loss
				and app.enemies.get_enemy(1).block == first.block - absorbed
				and new_gauge.gauge == added and new_gauge.threshold == 8
				and app.round_flow._unravel == original_gauge,
				"same live round ledger, original HP/Block and unmodified threshold")
			_check(app.enemies.get_enemy(2) == other[1] and app.enemies.get_enemy(3) == other[2]
				and app.party.get_heroes() == party_before and app.run_rng.state == rng_before,
				"no other actors or random draw touched by needle hit")
			_check(app.deck.energy == 2 and not app.deck.hand.has(id)
				and app.deck.discard_pile == [id] and app.deck.draw_pile.is_empty()
				and app.hand_view.get_child_count() == 4
				and app.get_node("LiveSupportHand").energy_label.text == "2",
				"one hand copy paid and discarded; live hand/energy refresh")
			var settled := _needle_state()
			await _key(KEY_1)
			_check(_needle_state() == settled, "consumed needle selection cannot replay")
			await _return()

	for scenario in ["seat1", "downed", "energy", "unheld", "missing_owner", "target_dead",
			"foreign_gauge", "replaced_target", "spoofed_id", "stale_panel",
			"switched_turn", "switched_battle", "cancelled"]:
		if not await _needle_mount("yarn_ranger_needle_arrow_plus"):
			await _return()
			continue
		var panel: Control = _panel("yarn_ranger_needle_arrow_plus")
		if scenario in ["replaced_target", "spoofed_id", "stale_panel", "switched_turn",
				"switched_battle", "foreign_gauge", "unheld", "missing_owner", "cancelled"]:
			await _needle_arm(panel, false)
			presenter._queue_attack(1)
			_check(presenter._queued, "real needle target has exactly one deferred callback: " + scenario)
		match scenario:
			"seat1":
				var a: Dictionary = app.party._heroes[0]
				app.party._heroes[0] = app.party._heroes[1]
				app.party._heroes[1] = a
				app.party._heroes[0].position = 1
				app.party._heroes[1].position = 2
			"downed": app.party.apply_damage(2, 999)
			"energy": app.deck.combat_state.energy = 0
			"unheld": app.deck.hand.erase("yarn_ranger_needle_arrow_plus")
			"missing_owner": app.party._heroes[1].id = "seamstress"
			"target_dead": app.enemies.apply_damage(1, 999)
			"foreign_gauge": presenter._unravel = CombatUnravel.new()
			"replaced_target":
				var old_id: String = app.enemies._enemies[0].id
				app.enemies._enemies[0].id = app.enemies._enemies[2].id
				app.enemies._enemies[2].id = old_id
			"spoofed_id": panel.get_child(0).text = "yarn_ranger_needle_arrow_plus_plus"
			"stale_panel": app._refresh_hand()
			"cancelled": presenter._cancel_choice()
			"switched_turn": app.enemy_intents._turn_index += 1
			"switched_battle": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		var before := _needle_state()
		var quote: Dictionary = presenter._target_preview("yarn_ranger_needle_arrow_plus")
		if scenario in ["seat1", "downed", "energy", "unheld", "missing_owner", "foreign_gauge"]:
			_check(not quote.playable, "invalid needle source, energy, victim or ledger dims preview: " + scenario)
		if scenario == "target_dead":
			_check(not quote.target_positions.has(1), "slain needle target omitted from mounted picker")
		await _frames()
		_check(_needle_state() == before and app.deck.discard_pile.is_empty(),
			"stale/illegal needle callback has no cost, hit, gauge or RNG mutation: " + scenario)
		await _return()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_attack_preview_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _forecast_statuses() -> void:
	for id in WIRED_ATTACK_IDS:
		var replay: Array = []
		for keyboard in [false, true]:
			if not await _start(_seed_for(id), id):
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


## The idle attack strip is a collapsed row, not an empty label holding a fixed
## height. A hovered, armed or P-selected attack still owns a readable forecast;
## Esc, a stale card, Return to title and a fresh battle all restore the collapsed
## lower third without a leftover forecast, extra cue or spent model.
func _cue_strip() -> void:
	var id := "warden_shield_bash"
	var seed_value := _seed_for(id)
	_check(seed_value >= 0, "collapse fixture finds a seeded held attack")
	if seed_value < 0:
		return
	if not await _start(seed_value):
		return
	var column := app.hand_view.get_parent() as Control
	var initial := _snapshot()
	var idle_min: float = column.get_combined_minimum_size().y
	var idle_stage: float = app.hero_view.size.y
	var idle_hand: float = app.hand_view.get_global_rect().position.y
	var strip: float = presenter.cue.custom_minimum_size.y
	_check(strip >= 44.0, "cue still declares its readable authored height")
	_check(presenter.cue.text == "" and not presenter.cue.is_visible_in_tree()
		and presenter.current_forecast.is_empty(),
		"eligible held attacks still leave the idle cue empty and collapsed")
	_check(not presenter.cue.text.contains("Attack preview"), "no persistent debug sentence")
	var panel = _panel(id)
	_check(panel != null and presenter._bindings.has(panel), "collapse fixture holds the real attack panel")
	if panel == null:
		await _return()
		return
	await _hover(panel)
	_assert_preview(id)
	var active_min: float = column.get_combined_minimum_size().y
	_check(presenter.cue.is_visible_in_tree() and active_min >= idle_min + strip,
		"hovered attack re-owns a complete cue strip")
	_check(app.hero_view.size.y <= idle_stage - strip, "stage yields the strip height only while forecasting")
	_check(app.hand_view.get_global_rect().position.y == idle_hand, "card row never jumps for a forecast")
	await _key(KEY_ESCAPE)
	_check(presenter._selected == null and presenter.current_forecast.is_empty()
		and presenter.cue.text == "" and not presenter.cue.is_visible_in_tree(),
		"Esc retires the forecast and collapses the cue")
	_check(column.get_combined_minimum_size().y == idle_min and app.hero_view.size.y == idle_stage,
		"Esc restores the collapsed lower third")
	# Click arms the same attack: the forecast stays readable until cancellation.
	await _click(panel)
	_check(presenter._armed == panel and presenter.cue.is_visible_in_tree(),
		"clicked armed attack keeps its forecast strip")
	await _key(KEY_ESCAPE)
	_check(not presenter.cue.is_visible_in_tree() and presenter.cue.text == ""
		and column.get_combined_minimum_size().y == idle_min and app.hero_view.size.y == idle_stage,
		"cancelled armed attack collapses the cue and layout again")
	# Losing eligibility (the real held card leaves the authoritative hand).
	await _hover(panel)
	_check(presenter.cue.is_visible_in_tree(), "hover before the stale removal shows the cue")
	_check(app.deck.discard_played(id), "stale fixture removes the selected real card")
	await _frames()
	_check(presenter._selected == null and presenter.current_forecast.is_empty()
		and presenter.cue.text == "" and not presenter.cue.is_visible_in_tree()
		and column.get_combined_minimum_size().y == idle_min and app.hero_view.size.y == idle_stage,
		"lost eligibility retires cue, forecast and reserved strip")
	var before_return := _snapshot()
	_check(before_return[0] != initial[0], "stale fixture really changed the prior battle hand")
	await _return()
	if not await _start(seed_value):
		return
	_check(_cue_count() == 1, "fresh battle mounts exactly one cue")
	_check(presenter.cue.text == "" and not presenter.cue.is_visible_in_tree()
		and presenter.current_forecast.is_empty(),
		"fresh battle cue starts empty and collapsed")
	var fresh_column := app.hand_view.get_parent() as Control
	_check(fresh_column.get_combined_minimum_size().y == idle_min and app.hero_view.size.y == idle_stage,
		"fresh battle reserves no cue strip")
	_check(_snapshot() == initial, "Return and fresh battle reproduce the seeded opening untouched")
	var fresh := _snapshot()
	await _choose(id, true)
	_check(presenter._armed == presenter._selected and presenter.cue.is_visible_in_tree(),
		"P-selected attack still shows the readable forecast after re-entry")
	_assert_preview(id)
	await _key(KEY_ESCAPE)
	_check(presenter.current_forecast.is_empty() and presenter.cue.text == ""
		and not presenter.cue.is_visible_in_tree(),
		"Esc after re-entry again leaves no stale forecast")
	_check(_snapshot() == fresh, "P forecast and Esc in the fresh battle spend nothing and keep the seeded RNG")
	await _return()


func _cue_count() -> int:
	var count := 0
	for child in app.hand_view.get_parent().get_children():
		if child.name == "AttackPreviewCue":
			count += 1
	return count


## ---------------------------------------------------------------------------
## Combo-attack forecast: the app now calls the detached eight-variant oracle
## from the real shared hand. Pinned/Unravel/Tinker first-attack remain the
## battle's own instances, and the mounted cue is compared to the same oracle.
## ---------------------------------------------------------------------------

const COMBO_FAMILIES: Array[String] = [
	"warden_pinning_jab", "warden_pinning_jab_plus",
	"warden_seam_breaker", "warden_seam_breaker_plus",
	"tinker_spool_launcher", "tinker_spool_launcher_plus",
	"tinker_snip_the_seam", "tinker_snip_the_seam_plus",
]


func _combo_oracle(id: String) -> Dictionary:
	var live = app.get_node("LiveAttackPreview")
	return CombatPoolComboAttackPreview.new().get_preview(app.deck, app.party, app.enemies,
		live._pinned, live._unravel, live._play._tinker, id, 0)


## Independent expected reading assembled from the oracle's own slots and hit
## dictionaries; it never calls the app's formatting routine.
func _combo_expected(id: String, forecast: Dictionary) -> String:
	var definition := CombatAttackTargeting.new().combo_definition(id)
	var reading := "%s | %d energy | P / click card; %s / click enemy; Esc cancels" % [
		str(definition.get("display_name", id)), int(definition.get("cost", 0)),
		presenter._key_hint(forecast.get("target_positions", []))]
	if not forecast.get("playable", false):
		return reading + "\nForecast unavailable: no legal target, energy, or owner position"
	var details: PackedStringArray = []
	for value in forecast["targets"]:
		var hit: Dictionary = value
		var detail := "slot %d: %d damage" % [int(hit["position"]), int(hit["damage"])]
		if int(hit.get("block_absorbed", 0)) > 0:
			detail += " (%d absorbed)" % int(hit["block_absorbed"])
		detail += " → %d HP, %d Block" % [int(hit["hp_after"]), int(hit["block_after"])]
		if not bool(hit.get("survives", true)):
			detail += ", slain"
		if int(hit.get("pin_bonus", 0)) > 0:
			detail += ", +%d Pinned consumed" % int(hit["pin_bonus"])
		if bool(hit.get("pin_applied", false)):
			detail += ", Pins it (%s)" % str(hit.get("pin_owner_after", "")).capitalize()
		elif not str(hit.get("pin_owner_after", "")).is_empty():
			detail += ", Pinned by %s" % str(hit.get("pin_owner_after", "")).capitalize()
		var after: Dictionary = hit.get("unravel_after", {})
		var before: Dictionary = hit.get("unravel_before", {})
		if int(hit.get("unravel_added", 0)) > 0:
			detail += ", Unravel %d→%d/%d" % [int(before["gauge"]),
				int(after["gauge"]), int(after["threshold"])]
		elif not after.is_empty():
			detail += ", gauge %d/%d" % [int(after["gauge"]), int(after["threshold"])]
		var skip: Dictionary = hit.get("after_action_skip", {})
		if bool(after.get("skip_pending", false)):
			if skip.is_empty():
				detail += ", threshold reached (slain)"
			else:
				detail += ", next action skipped → %d/%d" % [int(skip["gauge"]),
					int(skip["threshold"])]
		if bool(hit.get("conditional_empowered", false)):
			detail += ", empowered"
		if int(hit.get("tinker_first_attack_bonus", 0)) > 0:
			detail += ", +%d Tinker first attack" % int(hit["tinker_first_attack_bonus"])
		details.append(detail)
	var keys: PackedStringArray = []
	for position in forecast["target_positions"]:
		keys.append(str(int(position)))
	var slot_text := "none"
	if keys.size() > 1 and int(forecast["target_positions"].back()) \
			- int(forecast["target_positions"].front()) == keys.size() - 1:
		slot_text = "%s-%s" % [keys[0], keys[keys.size() - 1]]
	elif not keys.is_empty():
		slot_text = ", ".join(keys)
	return reading + "\nOriginal slots %s — %s" % [slot_text, "; ".join(details)]


## Full mounted battle snapshot plus the three battle-scoped combo authorities
## and the last committed event, so a pure forecast cannot hide a write.
func _combo_state() -> Array:
	var live = app.get_node_or_null("LiveAttackPreview")
	if live == null:
		return _snapshot()
	var pinned = null
	var bind_identity := false
	var gauges := {}
	var latch = null
	if live._pinned != null:
		pinned = live._pinned._pinner_by_position.duplicate(true)
	if live._unravel != null:
		bind_identity = live._unravel._bound_enemies == app.enemies
		gauges = live._unravel._gauges.duplicate(true)
	if live._play != null:
		latch = live._play._tinker._consumed
	return _snapshot() + [pinned, bind_identity, gauges, latch, live.last_event.duplicate(true)]


func _hold_combo(id: String, extra: Array[String] = []) -> bool:
	if not await _start(_seed_for("warden_strike")):
		return false
	var hand: Array[String] = [id]
	hand.append_array(extra)
	app.deck.hand.assign(hand)
	app.deck.combat_state.energy = 3
	app._refresh_hand()
	await _frames()
	var panel = _panel(id)
	_check(panel != null and presenter._bindings.has(panel) and app._combo_bindings.has(panel),
		"mounted hand binds real cast and passive forecast listeners: " + id)
	return panel != null


## A seeded opening Fight reached through the real title/route controls.
func _combo_route_fixture() -> Dictionary:
	for value in range(1, 400):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for id in map.get_legal_choices():
			if map.get_node(id).type == "Fight":
				return {"seed": value, "fight": id}
	return {}


## The routed fight must still be this run's current route and encounter.
func _combo_route_case() -> void:
	var fixture := _combo_route_fixture()
	_check(not fixture.is_empty(), "seeded opening offers a real Fight node")
	if fixture.is_empty():
		return
	app.run_seed = fixture.seed
	await _click(preload("res://tests/legacy_card_app_fixture.gd").route_button(app))
	var fight: Button = null
	for button in app.route_buttons:
		if button.get_meta("route_id") == fixture.fight:
			fight = button
	_check(fight != null and not fight.disabled, "seeded opening Fight is an enabled route control")
	if fight == null:
		await _return()
		return
	await _click(fight)
	_check(app.deck != null and app.run_map != null and app.party_carryover != null,
		"real route entry mounts a routed battle with a run ledger")
	if app.deck == null:
		return
	_check(app._current_act_battle(), "mounted routed fight is the current route encounter")
	var id := "tinker_snip_the_seam"
	app.deck.hand.assign([id])
	app.deck.combat_state.energy = 3
	app._refresh_hand()
	await _frames()
	var panel = _panel(id)
	_check(panel != null and presenter._bindings.has(panel),
		"routed battle hand holds the actual combo card")
	if panel == null:
		await _return()
		return
	await _hover(panel)
	var forecast := _combo_oracle(id)
	_check(forecast.playable and presenter.cue.is_visible_in_tree()
		and presenter.cue.text == _combo_expected(id, forecast),
		"routed encounter shows the same oracle forecast")
	# A route/encounter that no longer matches this battle retires the forecast.
	var route: Array[String] = app.run_map.get_route().duplicate()
	app.run_map._route.append("f99_n9")
	_check(not app._current_act_battle(), "mutated route is no longer the current encounter")
	var before := _combo_state()
	await _frames()
	_check(presenter._selected == null and not presenter.cue.is_visible_in_tree()
		and _combo_state() == before, "stale route retires the cue without touching combat")
	app.run_map._route.assign(route)
	await _frames()
	_check(app._current_act_battle() and not presenter.cue.is_visible_in_tree(),
		"restored route keeps the retired cue hidden until a new selection")
	await _hover(panel)
	_check(presenter.cue.is_visible_in_tree()
		and presenter.cue.text == _combo_expected(id, _combo_oracle(id)),
		"restored route re-admits the real forecast")
	# A queued attack cannot settle if the real run route changes before
	# the deferred commit; restoration admits a fresh, separately armed cast.
	await _click(panel)
	presenter._queue_attack(1)
	_check(presenter._queued, "real routed combo enqueues exactly one target")
	var prior_route: Array[String] = app.run_map.get_route().duplicate()
	app.run_map._route.append("f99_n9")
	var stale_before := _combo_state()
	seed(7401)
	var stale_next := randi()
	seed(7401)
	await _frames()
	_check(_combo_state() == stale_before and randi() == stale_next
		and not presenter.last_event.get("ok", false),
		"queued combo rejects wrong route without spending or consuming run/global RNG")
	app.run_map._route.assign(prior_route)
	await _frames()
	var routed_before := _combo_state()
	await _key(KEY_P)
	await _key(KEY_1)
	_check(presenter.last_event.get("ok", false)
		and app.deck.energy == int(routed_before[3]) - 1
		and app.deck.discard_pile.count(id) == routed_before[2].count(id) + 1
		and app.enemies.get_enemy(1)["hp"] < int(routed_before[6][0]["hp"]),
		"real title → route Fight → held Snip keycast spends once and damages")
	await _return()


## Find an actual first-node Fight with three authored enemies. Advance the
## same seeded map and encounter RNG that the app uses, never fabricate a
## third live target in the mounted roster.
## Bleed from a genuine Seamstress hand attack must charge the battle's
## SAME gauge even before the first Pin/Unravel combo is ever committed.
## The single missing charge makes Spool (3) fall short of Snip's 8/2 gate.
func _combo_precast_bleed() -> void:
	var fixture := _combo_route_fixture()
	_check(not fixture.is_empty(), "pre-combo Bleed fixture has a real routed Fight")
	if fixture.is_empty():
		return
	app.run_seed = fixture.seed
	await _click(preload("res://tests/legacy_card_app_fixture.gd").route_button(app))
	var fight: Button = null
	for button in app.route_buttons:
		if button.get_meta("route_id") == fixture.fight:
			fight = button
	_check(fight != null and not fight.disabled, "pre-combo Bleed enters via enabled Fight control")
	if fight == null:
		await _return()
		return
	await _click(fight)
	_check(app.deck != null and app._current_act_battle()
		and app.round_flow != null and app.enemies != null,
		"real routed combat and enemy phase exist before any combo")
	if app.deck == null or not app._current_act_battle():
		return
	# Durable original enemy slot: real Bleed, Spool and Snip can all resolve
	# without accidentally ending this routed combat early.
	app.enemies._enemies[0]["max_hp"] = 100
	app.enemies._enemies[0]["hp"] = 100
	_check(app.enemies.gain_block(1, 30), "real target survives pre-combo Bleed and follow-up")
	var snip := "tinker_snip_the_seam"
	var spool := "tinker_spool_launcher"
	app.deck.hand.assign(["seamstress_prick", snip])
	app.deck.combat_state.energy = 3
	app._refresh_hand()
	await _frames()
	var held = _panel(snip)
	var seamstress_card = _panel("seamstress_prick")
	var gauge = presenter._unravel
	var flow = app.round_flow
	_check(held != null and seamstress_card != null
		and presenter._bindings.has(held) and presenter._bindings.has(seamstress_card)
		and app.deck.hand.has(snip), "routed real hand holds combo alongside playable Bleed")
	_check(gauge != null and gauge._bound_enemies == app.enemies
		and gauge.get_snapshot(1).get("gauge", -1) == 0
		and flow._unravel == gauge, "round flow shares the exact validated gauge before any cast")
	if held == null or seamstress_card == null or gauge == null:
		await _return()
		return
	# A physical Seamstress Prick applies Bleed, with NO combo committed yet.
	await _click(seamstress_card)
	await _click(app.get_node("LiveEnemyRoster")._labels[0])
	_check(presenter.last_event.get("ok", false)
		and app.enemies.get_enemy(1).get("statuses", {}).get("bleed", 0) == 3
		and app.deck.hand.has(snip) and app.deck.discard_pile.count(snip) == 0
		and gauge.get_snapshot(1)["gauge"] == 0,
		"confirmed Seamstress attack applies Bleed while held Snip remains uncast")
	var hp_before_tick: int = app.enemies.get_enemy(1)["hp"]
	var previous_turn: int = app.enemy_intents._turn_index
	await _click(app.end_turn_button)
	_check(app.enemy_intents._turn_index == previous_turn + 1 and app.deck.turn_active,
		"real End Turn advances an enemy owner Bleed boundary")
	_check(app.enemies.get_enemy(1)["hp"] == hp_before_tick - 3
		and app.enemies.get_enemy(1).get("statuses", {}).get("bleed", 0) == 2
		and not app.enemies.is_slain(1), "real enemy suffers one surviving Bleed tick")
	_check(app.round_flow == flow and flow._unravel == gauge
		and presenter._unravel == gauge and gauge.get_snapshot(1)["gauge"] == 1
		and gauge.get_snapshot(1)["threshold"] == 8,
		"exactly one Unravel earned from Bleed BEFORE any combo cast")
	# Same battle, next hand: Spool adds 3 to that original Bleed charge.
	# This is the exact half-threshold where Snip must be empowered.
	app.deck.hand.assign([spool, snip])
	app.deck.combat_state.energy = 3
	app._refresh_hand()
	await _frames()
	_check(_panel(spool) != null and _panel(snip) != null
		and flow._unravel == gauge and presenter._unravel == gauge,
		"hand rebuild preserves the identical round-flow/presenter gauge")
	if _panel(spool) == null or _panel(snip) == null:
		await _return()
		return
	await _click(_panel(spool))
	await _click(app.get_node("LiveEnemyRoster")._labels[0])
	_check(presenter.last_event.get("ok", false)
		and presenter.last_event["hits"][0]["unravel"] == 3
		and gauge.get_snapshot(1)["gauge"] == 4 and not gauge.get_snapshot(1)["skip_pending"]
		and presenter._play._tinker._consumed,
		"committed Spool adds three to the earlier Bleed tick, reaching exactly 4/8")
	var forecast := _combo_oracle(snip)
	var expected: Dictionary = {}
	for hit in forecast.get("targets", []):
		if int(hit["position"]) == 1:
			expected = hit
	_check(forecast.get("playable", false) and not expected.is_empty()
		and expected.get("unravel_before", {}).get("gauge") == 4
		and expected.get("unravel_before", {}).get("threshold") == 8
		and expected.get("conditional_empowered", false)
		and expected.get("tinker_first_attack_bonus", -1) == 0
		and expected.get("damage", 0) == 15,
		"Snip forecast empowers precisely at CURRENT half-threshold after Bleed plus Spool")
	var before_preview := _combo_state()
	seed(72891)
	var global_next := randi()
	seed(72891)
	await _hover(_panel(snip))
	_check(presenter.cue.is_visible_in_tree()
		and presenter.cue.text == _combo_expected(snip, forecast)
		and _combo_state() == before_preview and app.run_rng.state == before_preview[11],
		"live held Snip preview reads the battle gauge without spending or run RNG")
	await _key(KEY_ESCAPE)
	_check(_combo_state() == before_preview and randi() == global_next,
		"Snip preview plus cancel changes neither authorities nor global RNG")
	await _key(KEY_P)
	await _key(KEY_1)
	_check(not expected.is_empty() and presenter.last_event.get("ok", false)
		and presenter.last_event["hits"].size() == 1
		and presenter.last_event["hits"][0]["damage"] == expected.get("damage")
		and app.enemies.get_enemy(1)["hp"] == expected.get("hp_after")
		and app.enemies.get_enemy(1)["block"] == expected.get("block_after"),
		"authoritative empowered Snip hit matches its detached half-threshold HP/Block forecast")
	_check(app.deck.hand.count(snip) == 0 and app.deck.discard_pile.count(snip) == before_preview[2].count(snip) + 1
		and app.deck.energy == 1 and app.run_rng.state == before_preview[11]
		and presenter._unravel == gauge and flow._unravel == gauge,
		"real Snip commits one card/energy with unchanged RNG and gauge identity")
	await _return()


func _combo_three_fixture() -> Dictionary:
	for value in range(1, 180):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		for id in map.get_legal_choices():
			if map.get_node(id).get("type") != "Fight":
				continue
			var probe_rng := RandomNumberGenerator.new()
			probe_rng.seed = value
			var probe_map := RunMap.new()
			if not probe_map.generate(probe_rng) or not probe_map.choose_node(id):
				continue
			var entered := RunAuthoredBattleEntry.new().entry_current_battle(
				probe_map, probe_rng, RunFightEncounterSelection.new())
			if entered.get("success", false) and entered["enemies"].get_enemies().size() == 3:
				return {"seed": value, "fight": id}
	return {}


## All four Tinker IDs can target original slot 3 when it is actually
## occupied. This is a routed title -> Fight -> shared hand real cast.
func _combo_three_slots() -> void:
	var fixture := _combo_three_fixture()
	_check(not fixture.is_empty(), "seeded first-node Fight with three authored enemies exists")
	if fixture.is_empty():
		return
	for id in ["tinker_spool_launcher", "tinker_spool_launcher_plus",
			"tinker_snip_the_seam", "tinker_snip_the_seam_plus"]:
		app.run_seed = fixture.seed
		await _click(preload("res://tests/legacy_card_app_fixture.gd").route_button(app))
		var fight: Button = null
		for button in app.route_buttons:
			if button.get_meta("route_id") == fixture.fight:
				fight = button
		_check(fight != null and not fight.disabled, "routed three-enemy Fight control: " + id)
		if fight == null:
			return
		await _click(fight)
		_check(app.deck != null and app.enemies.get_enemies().size() == 3
			and app._current_act_battle(), "real battle has living original enemy slot 3: " + id)
		if app.deck == null or app.enemies.get_enemies().size() != 3:
			return
		app.deck.hand.assign([id])
		app.deck.combat_state.energy = 3
		app._refresh_hand()
		await _frames()
		var panel = _panel(id)
		var forecast := _combo_oracle(id)
		_check(panel != null and presenter._bindings.has(panel)
			and forecast.get("playable", false) and forecast["target_positions"].has(3),
			"authored TO slot 3 live-binding and detached oracle: " + id)
		if panel == null or not forecast.get("playable", false):
			await _return()
			continue
		var target := {}
		for hit in forecast["targets"]:
			if int(hit["position"]) == 3:
				target = hit
		_check(not target.is_empty(), "oracle forecasts occupied third enemy: " + id)
		var before := _combo_state()
		if id.ends_with("_plus"):
			await _click(panel)
			await _click(app.get_node("LiveEnemyRoster")._labels[2])
		else:
			await _key(KEY_P)
			await _key(KEY_3)
		_check(presenter.last_event.get("ok", false)
			and app.deck.energy == int(before[3]) - 1
			and app.deck.hand.count(id) == 0
			and app.deck.discard_pile.count(id) == before[2].count(id) + 1,
			"real original slot 3 consumes one held copy and one energy: " + id)
		_check(not target.is_empty()
			and app.enemies.get_enemy(3)["hp"] == target.get("hp_after")
			and app.enemies.get_enemy(3)["block"] == target.get("block_after"),
			"live original slot 3 agrees with detached HP/Block forecast: " + id)
		_check(app.run_rng.state == int(before[11])
			and app.round_flow._unravel == presenter._unravel,
			"slot 3 cast shares gauge and consumes no run RNG: " + id)
		await _return()


func _combo_forecasts() -> void:
	_check(COMBO_FAMILIES.size() == 8, "all eight authored combo variants are covered")
	for id in COMBO_FAMILIES:
		var replay: Array = []
		for session in range(2):
			if not await _hold_combo(id):
				return
			var panel = _panel(id)
			_check(panel != null, "authored combo card really held: " + id)
			if panel == null:
				await _return()
				continue
			var definition := CombatAttackTargeting.new().combo_definition(id)
			_check(not definition.is_empty() and definition.get("id") == id,
				"authored combo record available: " + id)
			# A forecast only: no cast handler is added to the shared hand.
			_check(panel.gui_input.get_connections().size() == 1,
				"combo card adds one live cast input handler: " + id)
			_check(panel.mouse_entered.get_connections().size() == 2
				and panel.mouse_exited.get_connections().size() == 2,
				"one app-only and one live hover listener per combo panel: " + id)
			var before := _combo_state()
			var idle_min: float = app.hand_view.get_parent().get_combined_minimum_size().y
			var idle_hand: float = app.hand_view.get_global_rect().position.y
			_check(not presenter.cue.is_visible_in_tree() and presenter.cue.text == "",
				"idle combo cue reserves no permanent strip: " + id)
			seed(7411)
			var global_next := randi()
			seed(7411)
			await _hover(panel)
			var forecast := _combo_oracle(id)
			_check(forecast.get("playable", false) and not forecast["targets"].is_empty(),
				"oracle has a real legal forecast: " + id)
			_check(presenter._selected == panel and app._combo_selected == null,
				"live presenter takes ownership of the combo hover: " + id)
			_check(presenter._selected == panel,
				"physical hover selects the real held combo panel: " + id)
			_check(presenter.cue.text == _combo_expected(id, forecast),
				"cue equals the same oracle snapshot: " + id)
			_check(presenter.cue.is_visible_in_tree()
				and root.get_visible_rect().encloses(presenter.cue.get_global_rect()),
				"forecast cue readable at 1280x720: " + id)
			_check(app.hand_view.get_parent().get_combined_minimum_size().y >= idle_min + 44.0
				and app.hand_view.get_global_rect().position.y == idle_hand,
				"forecast strip yields the stage and never moves the card row: " + id)
			_check(presenter.cue.text.contains("click card") and not presenter.cue.text.contains("Forecast only"),
				"cue advertises the real cast without spending: " + id)
			_check(presenter.cue.mouse_filter == Control.MOUSE_FILTER_IGNORE
				and presenter.cue.focus_mode == Control.FOCUS_NONE,
				"cue stays pointer- and focus-inert: " + id)
			for hit in forecast["targets"]:
				_check(presenter.cue.text.contains("slot %d: %d damage" % [
					int(hit["position"]), int(hit["damage"])])
					and presenter.cue.text.contains("→ %d HP, %d Block" % [
					int(hit["hp_after"]), int(hit["block_after"])]),
					"slot %d damage and post-hit HP/Block: %s" % [int(hit["position"]), id])
			if id.begins_with("warden_pinning_jab"):
				_check(presenter.cue.text.contains("Pins it (Warden)"),
					"Pinning Jab forecast reports the real pin: " + id)
			else:
				_check(presenter.cue.text.contains("Unravel") or presenter.cue.text.contains("gauge"),
					"Unravel family forecast reports the gauge: " + id)
			if id.begins_with("tinker_"):
				_check(presenter.cue.text.contains("+3 Tinker first attack"),
					"live first-attack bonus reported: " + id)
			if id.begins_with("tinker_snip_the_seam"):
				_check(not presenter.cue.text.contains("empowered"),
					"fresh gauge is not empowered: " + id)
			var held_text: String = presenter.cue.text
			_check(_combo_state() == before and randi() == global_next,
				"hover forecast leaves every model, authority and RNG untouched: " + id)
			# Keyboard selection of the very same held panel reads identically.
			presenter._selected = null
			await _key(KEY_P)
			_check(presenter._selected == panel and presenter._keyboard,
				"P selects the held combo card: " + id)
			_check(presenter.cue.text == held_text,
				"keyboard reading equals hover reading: " + id)
			_check(_combo_state() == before, "keyboard forecast is equally pure: " + id)
			await _key(KEY_P)
			_check(presenter._selected == panel,
				"single held combo card keeps cycling to itself: " + id)
			await _key(KEY_ESCAPE)
			_check(presenter._selected == null and presenter.cue.text == ""
				and not presenter.cue.is_visible_in_tree(),
				"Esc retires the combo forecast: " + id)
			_check(app.hand_view.get_parent().get_combined_minimum_size().y == idle_min,
				"Esc restores the collapsed lower third: " + id)
			_check(_combo_state() == before, "cancel alters no combat state: " + id)
			# Target and cast keys never spend a forecast-only combo.
			await _key(KEY_1)
			await _key(KEY_2)
			await _key(KEY_SPACE)
			_check(_combo_state() == before and not presenter.cue.is_visible_in_tree()
				and app.deck.hand.count(id) == 1 and app.deck.discard_pile.has(id) == false,
				"unarmed target or cast key never spends a combo: " + id)
			var trace := [held_text, app.deck.hand.duplicate()]
			if replay.is_empty():
				replay = trace
			else:
				_check(trace == replay, "same-seed combo forecast replay: " + id)
			await _return()


## For every base/+ card and every legal ORIGINAL enemy slot, make a real
## mounted mouse or keyboard cast and compare the committed state to the
## independent detached authority. No resolver is called by the test.
func _combo_commits() -> void:
	for id in COMBO_FAMILIES:
		var legal: Array = targeting.combo_definition(id)["to_positions"]
		for position in legal:
			# The title's standalone Fight has two occupants. Slot 3 has its
			# own seeded three-enemy routed Fight coverage below.
			if position > 2:
				continue
			if not await _hold_combo(id):
				return
			var card = _panel(id)
			var forecast := _combo_oracle(id)
			var expected: Dictionary = {}
			for target in forecast.get("targets", []):
				if int(target["position"]) == position:
					expected = target
			_check(card != null and presenter._bindings.has(card)
				and forecast.get("playable", false) and not expected.is_empty()
				and forecast["target_positions"].has(position),
				"actual held combo is legal in original target slot: %s/%d" % [id, position])
			if card == null or expected.is_empty():
				await _return()
				continue
			var before := _combo_state()
			var definition := targeting.combo_definition(id)
			var mouse: bool = (COMBO_FAMILIES.find(id) + position) % 2 == 0
			if mouse:
				await _click(card)
				_check(presenter._armed == card, "mouse really arms combo: " + id)
				var roster = app.get_node("LiveEnemyRoster")
				await _click(roster._labels[position - 1])
			else:
				await _key(KEY_P)
				_check(presenter._armed == card, "keyboard P really arms combo: " + id)
				await _key(KEY_1 if position == 1 else KEY_2 if position == 2 else KEY_3)
			var enemy: Dictionary = app.enemies.get_enemy(position)
			_check(presenter.last_event.get("ok", false) and
				int(presenter.last_event.get("hits", []).size()) == 1,
				"exactly one confirmed live hit: %s/%d" % [id, position])
			_check(enemy["hp"] == expected["hp_after"]
				and enemy["block"] == expected["block_after"],
				"live enemy HP/Block agrees with detached resolver: %s/%d" % [id, position])
			_check(app.deck.energy == int(before[3]) - int(definition["cost"])
				and app.deck.hand.count(id) == 0
				and app.deck.discard_pile.count(id) == before[2].count(id) + 1,
				"one energy payment and one discarded held copy: %s/%d" % [id, position])
			_check(presenter._unravel.get_snapshot(position) == expected["unravel_after"]
				and presenter._pinned.pinner_for_enemy(position) == expected["pin_owner_after"],
				"same battle-local Pin and gauge result: %s/%d" % [id, position])
			_check(app.round_flow._unravel == presenter._unravel,
				"real enemy phase receives precisely the live combo gauge: " + id)
			_check(app.run_rng.state == before[11],
				"committed deterministic combo never consumes run RNG: " + id)
			_check(presenter._play._tinker._consumed == id.begins_with("tinker_"),
				"Tinker latch belongs to this same battle: " + id)
			_check(app._combo_selected == null and not app.combo_cue.is_visible_in_tree(),
				"passive app forecast cannot double-handle committed combo: " + id)
			await _return()


## Cross-hero Pin, same-owner nonconsumption, one-turn Tinker bonus,
## threshold skip/advance and Snip's half-threshold live execution.
func _combo_sequences() -> void:
	if not await _hold_combo("warden_pinning_jab",
			["tinker_spool_launcher", "tinker_spool_launcher"]):
		return
	_check(app.enemies.gain_block(1, 30), "surviving enemy carries enough Block for three hits")
	await _key(KEY_P)
	await _key(KEY_1)
	_check(presenter.last_event.get("ok", false)
		and presenter._pinned.pinner_for_enemy(1) == "warden",
		"Warden live Jab pins surviving enemy")
	var second := _combo_oracle("tinker_spool_launcher")
	_check(int(second["targets"][0]["pin_bonus"]) == 5
		and int(second["targets"][0]["tinker_first_attack_bonus"]) == 3,
		"different-owner live hit forecasts one +5 pin and first-turn +3")
	await _key(KEY_P)
	await _key(KEY_1)
	_check(presenter.last_event.get("ok", false)
		and presenter._pinned.pinner_for_enemy(1).is_empty()
		and presenter._play._tinker._consumed,
		"live Tinker hit consumes one cross-owner pin and first-attack latch")
	var third := _combo_oracle("tinker_spool_launcher")
	_check(third.get("playable", false)
		and int(third["targets"][0]["pin_bonus"]) == 0
		and int(third["targets"][0]["tinker_first_attack_bonus"]) == 0
		and int(third["targets"][0]["damage"]) == 3,
		"next same-turn Tinker attack cannot obtain either bonus again")
	await _key(KEY_P)
	await _key(KEY_1)
	_check(presenter.last_event.get("ok", false)
		and presenter._unravel.get_snapshot(1)["gauge"] == 6,
		"both live Spool attacks increment the same normal gauge")
	await _return()

	if not await _hold_combo("warden_pinning_jab", ["warden_seam_breaker"]):
		return
	_check(app.enemies.gain_block(1, 25), "same-owner case survives")
	await _key(KEY_P)
	await _key(KEY_1)
	var pin_before: String = presenter._pinned.pinner_for_enemy(1)
	await _key(KEY_P)
	await _key(KEY_1)
	_check(pin_before == "warden" and presenter.last_event.get("ok", false)
		and presenter.last_event["hits"][0]["pin_bonus"] == 0
		and presenter._pinned.pinner_for_enemy(1) == "warden",
		"same Warden owner deals no pin bonus and cannot consume its pin")
	await _return()

	if not await _hold_combo("tinker_spool_launcher"):
		return
	_check(app.enemies.gain_block(1, 20), "threshold-case target remains alive")
	_check(presenter._unravel.apply_unravel(app.enemies, 1, 5),
		"real normal gauge precharged one Spool short of threshold")
	await _key(KEY_P)
	await _key(KEY_1)
	_check(presenter.last_event.get("ok", false)
		and presenter._unravel.get_snapshot(1)["skip_pending"]
		and presenter._unravel.get_snapshot(1)["threshold"] == 8,
		"live Spool crosses threshold and queues action skip")
	_check(app.round_flow._unravel == presenter._unravel,
		"enemy phase and combo use identical gauge authority")
	var old_turn: int = app.enemy_intents._turn_index
	await _click(app.end_turn_button)
	_check(app.enemy_intents._turn_index == old_turn + 1
		and app.deck.turn_active
		and presenter._unravel.get_snapshot(1)["gauge"] == 0
		and presenter._unravel.get_snapshot(1)["threshold"] == 12
		and not presenter._unravel.get_snapshot(1)["skip_pending"],
		"next real enemy phase consumes one skip and raises threshold by four")
	_check(not presenter._play._tinker._consumed,
		"next player turn reopens the shared Tinker once-turn bonus")
	await _return()

	for id in ["tinker_snip_the_seam", "tinker_snip_the_seam_plus"]:
		if not await _hold_combo(id):
			return
		var threshold: int = presenter._unravel.get_snapshot(1)["threshold"]
		_check(threshold == 8 and presenter._unravel.apply_unravel(app.enemies, 1, threshold / 2),
			"real Snip target reaches exactly half its current threshold")
		var empowered := _combo_oracle(id)
		_check(empowered.get("playable", false)
			and bool(empowered["targets"][0]["conditional_empowered"])
			and int(empowered["targets"][0]["damage"]) == (18 if id.ends_with("_plus") == false else 23),
			"detached conditional uses authored empowered damage plus first attack")
		await _key(KEY_P)
		await _key(KEY_1)
		_check(presenter.last_event.get("ok", false)
			and app.enemies.get_enemy(1)["hp"] == empowered["targets"][0]["hp_after"]
			and app.enemies.is_slain(1), "live empowered Snip resolves lethal authored hit")
		await _return()

	for id in ["warden_pinning_jab", "tinker_spool_launcher"]:
		if not await _hold_combo(id):
			return
		var hp: int = app.enemies.get_enemy(1)["hp"]
		_check(app.enemies.apply_damage(1, hp - 1), "genuinely fragile combo target")
		await _key(KEY_P)
		await _key(KEY_1)
		_check(presenter.last_event.get("ok", false) and app.enemies.is_slain(1)
			and presenter._pinned.pinner_for_enemy(1).is_empty()
			and presenter._unravel.get_snapshot(1)["gauge"] == 0,
			"slain enemy never receives a fresh pin or gauge charge")
		await _return()


## A queued real click is validated again after the deferred boundary. These
## checks use the same mounted callback as pointer/keyboard input, not a direct
## resolver call, and retain both run/global RNG on every rejection.
func _combo_deferred_rejections() -> void:
	for scenario in ["energy", "dead_owner", "target_identity", "hand_swap",
			"panel_swap", "turn_swap", "closed", "unbound_gauge"]:
		if not await _hold_combo("warden_pinning_jab"):
			return
		var panel = _panel("warden_pinning_jab")
		await _click(panel)
		_check(presenter._armed == panel and presenter._bindings.has(panel),
			"deferred scenario begins with a live armed held combo: " + scenario)
		presenter._queue_attack(1)
		_check(presenter._queued, "legal input enqueues exactly one deferred cast: " + scenario)
		match scenario:
			"energy":
				app.deck.combat_state.energy = 0
			"dead_owner":
				_check(app.party.apply_damage(1, 999), "source becomes genuinely downed")
			"target_identity":
				app.enemies._enemies[0]["id"] = "ragling_guard"
			"hand_swap":
				app.deck.hand.assign(["warden_seam_breaker"])
			"panel_swap":
				app._refresh_hand()
			"turn_swap":
				app.enemy_intents._turn_index += 1
			"closed":
				app._battle_closed = true
			"unbound_gauge":
				presenter._unravel = CombatUnravel.new()
		var before := _combo_state()
		seed(9124)
		var random_next := randi()
		seed(9124)
		await _frames()
		_check(_combo_state() == before and randi() == random_next,
			"stale/dead/illegal queued combo leaves all battle state and RNG unchanged: " + scenario)
		_check(app.deck.discard_pile.count("warden_pinning_jab") == before[2].count("warden_pinning_jab")
			and not presenter.last_event.get("ok", false),
			"no phantom discard or completed cast: " + scenario)
		await _return()


## Real battle-local Pinned/Unravel/first-attack changes refresh the cue, and a
## fresh default service would not carry them.
func _combo_live_state() -> void:
	var id := "warden_seam_breaker"
	if not await _hold_combo(id):
		return
	var live = app.get_node("LiveAttackPreview")
	_check(app.enemies.gain_block(1, 2), "forecast target carries real Block")
	await _frames()
	await _hover(_panel(id))
	var base_forecast := _combo_oracle(id)
	var base_text: String = presenter.cue.text
	_check(base_forecast.get("playable", false)
		and presenter.cue.text == _combo_expected(id, base_forecast),
		"baseline live forecast matches the oracle")
	_check(presenter.cue.text.contains(" (2 absorbed)")
		and int(base_forecast["targets"][0]["hp_after"])
			== app.enemies.get_enemy(1).hp - int(base_forecast["targets"][0]["hp_loss"])
		and int(base_forecast["targets"][0]["hp_loss"])
			== int(base_forecast["targets"][0]["damage"]) - 2,
		"forecast shows absorbed Block and the post-hit HP")
	var target: int = int(base_forecast["target_positions"][0])
	# The battle's own Pinned authority, from a real cross-hero owner.
	_check(live._pinned.pin_enemy(app.enemies, target, "seamstress"),
		"battle-local Pinned authority accepts the real pin")
	await _frames()
	var pinned_forecast := _combo_oracle(id)
	var pinned_text: String = presenter.cue.text
	_check(pinned_text != base_text
		and pinned_text == _combo_expected(id, pinned_forecast),
		"refreshed cue reflects the real battle Pinned token")
	_check(int(pinned_forecast["targets"][0]["pin_bonus"]) == 5
		and int(pinned_forecast["targets"][0]["damage"])
			== int(base_forecast["targets"][0]["damage"]) + 5,
		"real Pinned +5 reaches the live forecast damage")
	_check(pinned_text.contains(", +5 Pinned consumed"),
		"cue reports the consumed cross-hero pin")
	var fresh_pin := CombatPoolComboAttackPreview.new().get_preview(app.deck, app.party,
		app.enemies, CombatPinned.new(), live._unravel, live._play._tinker, id, 0)
	_check(int(fresh_pin["targets"][0]["damage"])
			== int(base_forecast["targets"][0]["damage"])
		and int(pinned_forecast["targets"][0]["damage"])
			!= int(fresh_pin["targets"][0]["damage"]),
		"forecast uses the battle's Pinned instance, not a fresh default")
	var settled := _combo_state()
	await _frames()
	_check(_combo_state() == settled,
		"live-state refresh never mutates actors, piles, authorities or RNG")
	# The battle's own Unravel gauge: charge one short of the skip, then reach it.
	var added := int(pinned_forecast["targets"][0]["unravel_added"])
	var threshold := int(pinned_forecast["targets"][0]["unravel_after"]["threshold"])
	var partial := threshold - added - 1
	if partial > 0:
		_check(live._unravel.apply_unravel(app.enemies, target, partial),
			"battle-local Unravel gauge accepts a real charge")
		await _frames()
		var charged_forecast := _combo_oracle(id)
		var charged_text: String = presenter.cue.text
		_check(charged_text != pinned_text
			and charged_text == _combo_expected(id, charged_forecast),
			"refreshed cue reflects the real Unravel gauge")
		_check(int(charged_forecast["targets"][0]["unravel_before"]["gauge"]) == partial
			and int(charged_forecast["targets"][0]["unravel_after"]["gauge"]) == partial + added
			and not bool(charged_forecast["targets"][0]["unravel_after"]["skip_pending"]),
			"live gauge charge and post-hit gauge agree below the threshold")
		_check(charged_text.contains("Unravel %d→%d/%d" % [partial, partial + added, threshold]),
			"cue reports the authoritative Unravel charge")
		_check(live._unravel.apply_unravel(app.enemies, target, 1),
			"real gauge charge reaches the authored threshold")
		await _frames()
	var skip_forecast := _combo_oracle(id)
	_check(bool(skip_forecast["targets"][0]["unravel_after"]["skip_pending"])
		and not skip_forecast["targets"][0]["after_action_skip"].is_empty(),
		"threshold charge queues a real action skip")
	_check(presenter.cue.text.contains("next action skipped")
		and presenter.cue.text == _combo_expected(id, skip_forecast),
		"cue reports the queued skip and the reset gauge")
	var unbound := CombatPoolComboAttackPreview.new().get_preview(app.deck, app.party,
		app.enemies, live._pinned, CombatUnravel.new(), live._play._tinker, id, 0)
	_check(not unbound.get("playable", false)
		and presenter.cue.text != _combo_expected(id, unbound),
		"forecast uses the battle's bound Unravel gauge, not a fresh default")
	await _return()
	# The battle's shared Tinker first-attack latch.
	var tinker_id := "tinker_spool_launcher"
	if not await _hold_combo(tinker_id):
		return
	live = app.get_node("LiveAttackPreview")
	await _hover(_panel(tinker_id))
	var pending := _combo_oracle(tinker_id)
	_check(int(pending["targets"][0]["tinker_first_attack_bonus"]) == 3
		and presenter.cue.text.contains("+3 Tinker first attack"),
		"pending shared first-attack bonus is forecast")
	_check(live._play._tinker.record_successful_attack("tinker_pop_shot"),
		"the battle's shared first-attack latch consumes a real attack")
	await _frames()
	var spent := _combo_oracle(tinker_id)
	_check(int(spent["targets"][0]["tinker_first_attack_bonus"]) == 0
		and int(spent["targets"][0]["damage"]) == int(pending["targets"][0]["damage"]) - 3,
		"consumed latch removes exactly the +3 first-attack bonus")
	_check(presenter.cue.text == _combo_expected(tinker_id, spent)
		and not presenter.cue.text.contains("Tinker first attack"),
		"refreshed cue reflects the consumed battle latch")
	var fresh_latch := CombatPoolComboAttackPreview.new().get_preview(app.deck, app.party,
		app.enemies, live._pinned, live._unravel, CombatTinkerFirstAttack.new(), tinker_id, 0)
	_check(int(fresh_latch["targets"][0]["tinker_first_attack_bonus"]) == 3,
		"a fresh latch default would still advertise +3")
	settled = _combo_state()
	await _frames()
	_check(_combo_state() == settled and presenter.cue.text == _combo_expected(tinker_id, spent),
		"consumed-latch forecast is still pure")
	await _return()
	# Snip's authored conditional damage follows the battle's own gauge.
	var snip := "tinker_snip_the_seam_plus"
	if not await _hold_combo(snip):
		return
	live = app.get_node("LiveAttackPreview")
	await _hover(_panel(snip))
	var base_snip := _combo_oracle(snip)
	_check(not bool(base_snip["targets"][0]["conditional_empowered"])
		and not presenter.cue.text.contains("empowered"),
		"fresh gauge forecasts Snip's base damage")
	var snip_threshold := int(base_snip["targets"][0]["unravel_after"]["threshold"])
	_check(live._unravel.apply_unravel(app.enemies, 1, snip_threshold / 2),
		"battle-local Unravel gauge reaches Snip's half-threshold condition")
	await _frames()
	var empowered := _combo_oracle(snip)
	_check(bool(empowered["targets"][0]["conditional_empowered"])
		and int(empowered["targets"][0]["damage"]) > int(base_snip["targets"][0]["damage"])
		and presenter.cue.text.contains(", empowered")
		and presenter.cue.text == _combo_expected(snip, empowered),
		"live gauge change flips Snip to its authored conditional damage")
	settled = _combo_state()
	await _frames()
	_check(_combo_state() == settled,
		"empowered Snip forecast keeps every model and authority untouched")
	await _return()


func _combo_rejections() -> void:
	var id := "warden_pinning_jab"
	var stale_callback: Callable
	var stale_panel: Control
	for scenario in ["energy", "downed", "wrong_position", "dead_target",
			"nonheld", "stale", "hidden", "terminal", "canceled"]:
		if not await _hold_combo(id):
			return
		var panel = _panel(id)
		await _hover(panel)
		_check(presenter.cue.is_visible_in_tree()
			and presenter.cue.text == _combo_expected(id, _combo_oracle(id)),
			"negative scenario starts from a real legal forecast: " + scenario)
		match scenario:
			"energy":
				app.deck.combat_state.energy = 0
			"downed":
				_check(app.party.apply_damage(1, 999) and app.party.is_downed(1),
					"combo owner really downed in the mounted battle")
			"wrong_position":
				# Move the Warden to a slot the authored card cannot attack from,
				# keeping the same party instance and round flow.
				var heroes: Array = app.party.get_heroes()
				heroes[0]["position"] = 3
				heroes[1]["position"] = 1
				heroes[2]["position"] = 2
				app.party._heroes.assign([heroes[1], heroes[2], heroes[0]])
				_check(app.party.get_hero(3).id == "warden"
					and int(app.party.get_hero(3).position) == 3,
					"warden really moved to a forbidden position")
			"dead_target":
				_check(app.enemies.apply_damage(1, 999) and app.enemies.is_slain(1),
					"the only authored target really slain in its original slot")
			"nonheld":
				_check(app.deck.discard_played(id),
					"selected combo card really leaves the hand")
			"stale":
				stale_panel = panel
				stale_callback = presenter._bindings[panel].entered
				app.hand_view.remove_child(panel)
				app._refresh_hand()
			"hidden":
				app.battle_view.hide()
			"terminal":
				for enemy in app.enemies.get_enemies():
					app.enemies.apply_damage(enemy.position, 10000)
			"canceled":
				await _key(KEY_ESCAPE)
		# A terminal boundary settles turn/outcome/gold in the next frames; take
		# the baseline after that real boundary so the check still proves the
		# forecast refresh itself writes nothing.
		if scenario == "terminal":
			await _frames()
			_check(app.battle_result.is_finished(), "terminal result observed in the actual app")
		var before := _combo_state()
		seed(451)
		var global_next := randi()
		seed(451)
		# Let the normal lifecycle observe the change without another input.
		await _frames()
		if scenario in ["energy", "downed", "wrong_position", "dead_target"]:
			_check(presenter.cue.is_visible_in_tree()
				and presenter.cue.text.contains("Forecast unavailable")
				and not presenter.cue.text.contains(" damage")
				and not presenter.cue.text.contains("Original slots"),
				"no actionable forecast for an existing but invalid cast: " + scenario)
		else:
			_check(presenter._selected == null and presenter.cue.text == ""
				and not presenter.cue.is_visible_in_tree(),
				"cue fully retired: " + scenario)
			if scenario == "stale":
				stale_callback.call()
				_check(presenter._selected == null,
					"captured obsolete hover cannot select the rebuilt hand")
				_check(presenter._bindings.size() == 1
					and presenter._bindings.has(_panel(id)),
					"rebuild leaves exactly one fresh listener on the held card")
		_check(_combo_state() == before and randi() == global_next,
			"negative context alters no combat state or global RNG: " + scenario)
		if scenario == "stale":
			stale_panel.free()
		app.battle_view.show()
		await _return()
	# A dead slot is excluded without compacting the surviving original slots.
	if not await _hold_combo("tinker_spool_launcher"):
		return
	_check(app.enemies.apply_damage(1, 999) and app.enemies.is_slain(1),
		"slot one really slain in place")
	await _frames()
	await _hover(_panel("tinker_spool_launcher"))
	var forecast := _combo_oracle("tinker_spool_launcher")
	var expected_slots: Array[int] = [2]
	_check(forecast["target_positions"] == expected_slots
		and presenter.cue.text == _combo_expected("tinker_spool_launcher", forecast),
		"dead slot excluded without compacting original slots")
	_check(presenter.cue.text.contains("Original slots 2")
		and not presenter.cue.text.contains("slot 1:"),
		"forecast never advertises the dead slot")
	await _return()


## Only the live attack presenter owns combo input and cue.
func _combo_other_owner() -> void:
	var id := "warden_seam_breaker"
	if not await _hold_combo(id, ["warden_shield_bash"]):
		return
	app.deck.hand.assign(["warden_shield_bash", id])
	app._refresh_hand()
	await _frames()
	var combo = _panel(id)
	var attack = _panel("warden_shield_bash")
	_check(combo != null and attack != null and presenter._bindings.has(combo),
		"hand holds one combo and one starter, both live-bound")
	if combo == null or attack == null:
		await _return()
		return
	await _key(KEY_P)
	_check(presenter._card_id(presenter._selected) == "warden_shield_bash"
		and presenter.cue.is_visible_in_tree(),
		"P starts with the first actual held attack")
	_check(app._combo_selected == null and not app.combo_cue.is_visible_in_tree(),
		"app forecast never duplicates a live preview")
	await _key(KEY_ESCAPE)
	await _click(attack)
	_check(presenter._armed == attack and presenter.cue.is_visible_in_tree(),
		"clicked starter remains armed")
	var before := _combo_state()
	await _hover(combo)
	_check(presenter._armed == attack and presenter._selected == combo,
		"hover can preview combo without replacing the armed starter")
	_check(app._combo_selected == null and not app.combo_cue.is_visible_in_tree(),
		"app-only hover cue defers to the live attack presenter")
	_check(_combo_state() == before, "competing hover neither spends nor mutates")
	await _key(KEY_ESCAPE)
	await _hover(combo)
	_check(presenter._selected == combo and presenter.cue.is_visible_in_tree()
		and presenter.cue.text == _combo_expected(id, _combo_oracle(id)),
		"combo hover is fully live after cancel")
	await _return()

func _fixture_start(target) -> void:
	if target.deck != null:
		preload("res://tests/legacy_card_app_fixture.gd").enable(target)
		target.start_run_requested.emit()
		return
	var started: bool = target._start_battle()
	_check(started == (target.deck != null), "standalone fixture reports admission consistently")


func _drawn_drag_cards() -> void:
	for id in ["warden_strike", "tinker_scrap_bomb", "seamstress_mend", "warden_brace", "warden_backstep"]:
		for scenario in ["valid", "escape", "rebuild", "energy", "downed", "wrong"]:
			if not await _start(_seed_for("warden_strike")):
				return
			app.deck.hand.assign([id])
			app._refresh_hand()
			await _frames()
			var card: Control = _panel(id)
			_check(card != null and not card.get_child(0).visible, "drawn real drag card retains hidden identity: " + id)
			var from := card.get_global_rect().get_center()
			var destination := from
			if id in ["warden_strike", "tinker_scrap_bomb"]:
				destination = app.get_node("LiveEnemyRoster")._labels[0].get_global_rect().get_center()
			elif id == "seamstress_mend":
				app.party.apply_damage(1, 8)
				destination = app.hero_panels[0].get_global_rect().get_center()
			var before := _snapshot()
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			press.position = from
			root.push_input(press, true)
			await _frames()
			_check(_snapshot() == before, "held mouse press only arms, never spends: " + id)
			if scenario == "wrong":
				destination = Vector2(5, 5)
			var motion := InputEventMouseMotion.new()
			motion.position = destination
			root.push_input(motion, true)
			await _frames()
			_check(card.get_meta("aiming", false), "live armed card draws drag arrow: " + id)
			match scenario:
				"escape": await _key(KEY_ESCAPE)
				"rebuild": app._refresh_hand()
				"energy": app.deck.combat_state.energy = 0
				"downed":
					var owner: String = (M02PositionCards.new().get_definition(id) if id in M02PositionCards.IDS else catalog.get_definition(id)).owner
					for hero in app.party._heroes:
						if hero.id == owner:
							hero.hp = 0
			var staged := _snapshot()
			var release := InputEventMouseButton.new()
			release.button_index = MOUSE_BUTTON_LEFT
			release.position = destination
			release.pressed = false
			root.push_input(release, true)
			await _frames()
			if scenario == "valid":
				_check(app.deck.hand.is_empty() and app.deck.discard_pile.count(id) == before[2].count(id) + 1 and app.deck.energy == before[3] - (2 if id == "tinker_scrap_bomb" else 1), "legal mouse release commits exactly one card and authored cost: " + id)
			else:
				_check(_snapshot() == staged, "cancelled invalid or stale drag has no effect: " + id + " / " + scenario)
			await _return()

## Find a genuinely traversable Treasure → Fight; admission, not this
## test, binds the real run's sewn wardrobe and live first-attack latch.
func _control_patch_route_fixture() -> Dictionary:
	for value in range(1, 1500):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for first in map.get_legal_choices():
			if map.get_node(first).type != "Treasure":
				continue
			var probe := RunMap.new()
			var same_rng := RandomNumberGenerator.new()
			same_rng.seed = value
			probe.generate(same_rng)
			if not probe.choose_node(first):
				continue
			for second in probe.get_legal_choices():
				if probe.get_node(second).type == "Fight":
					return {"seed": value, "treasure": first, "fight": second}
	return {}


## The physical routed hand exercises the SAME patch projection through the
## live forecast and settled control resolver, not a detached card imitation.
func _control_attack_patches() -> void:
	var fixture := _control_patch_route_fixture()
	_check(not fixture.is_empty(), "seeded authored Treasure → Fight route exists")
	if fixture.is_empty():
		return
	app.run_seed = fixture.seed
	await _click(preload("res://tests/legacy_card_app_fixture.gd").route_button(app))
	var treasure: Button = null
	for button in app.route_buttons:
		if button.get_meta("route_id") == fixture.treasure:
			treasure = button
	_check(treasure != null and not treasure.disabled, "Treasure route control really offered")
	if treasure == null:
		await _return()
		return
	await _click(treasure)
	_check(app.run_map.get_route() == [fixture.treasure] and app.route_buttons.size() > 0,
		"real Treasure visit retains live onward route controls")
	# Supply a genuine run-owned sewn wardrobe during the noncombat prefix,
	# while the fight does not yet exist. Its contents match run ledger exactly.
	app.run_trinkets.assign(["button_eye", "pincushion_arm"])
	var definitions := [
		{"id": "button_eye", "slot": "HEAD"},
		{"id": "pincushion_arm", "slot": "ARM"}]
	var wardrobe := RunPatchWardrobe.new(app.run_heroes, app.run_trinkets,
		definitions, app.run_scraps, app.session_gold, app.run_deck,
		app.run_seed, true)
	var carry := app.party_carryover as RunTornCarryover
	_check(carry != null and wardrobe.is_valid(), "real route-bound wardrobe ledger prepared")
	if carry == null or not wardrobe.is_valid():
		await _return()
		return
	_check(wardrobe.sew("button_eye", "seamstress", "HEAD", "head",
		wardrobe.get_snapshot()).ok, "real Button Eye sewn on Seamstress")
	_check(wardrobe.sew("pincushion_arm", "seamstress", "ARM", "arm",
		wardrobe.get_snapshot()).ok, "real Pincushion Arm sewn on Seamstress")
	_check(carry.bind_wardrobe(wardrobe, carry.torn, wardrobe.get_snapshot()),
		"authentic run carryover binds actual wearable patch ledger before Fight")
	var choice: Button = null
	for button in app.route_buttons:
		if button.get_meta("route_id") == fixture.fight:
			choice = button
	_check(choice != null and not choice.disabled and app._can_choose_connected_route(),
		"real next Fight remains actionable after sewn run ledger binding")
	if choice == null:
		await _return()
		return
	await _click(choice)
	_check(app._current_act_battle() and app.deck != null and app.round_flow != null,
		"real routed battle admits sewn wearer and combat round flow")
	if app.deck == null:
		return
	var shared = presenter._play._patches
	_check(shared != null and shared.is_valid() and presenter._controls._patches == shared
		and shared.active_snapshot().seamstress.has("button_eye")
		and shared.active_snapshot().seamstress.has("pincushion_arm"),
		"battle entry itself binds the identical valid starter/control patch state")
	_check(shared != null and presenter._controls._patches == shared
		and shared.latch_snapshot().seamstress == false,
		"mounted control and starter attacks share exact fresh latch instance")
	# Durable original target slot survives both variants; keep pre-existing
	# Block and statuses available for exact rounded forecasts.
	app.enemies._enemies[0]["max_hp"] = 200
	app.enemies._enemies[0]["hp"] = 200
	_check(app.enemies.gain_block(1, 6) and app.enemies.apply_statuses({1: {"exposed": 1}})
		and presenter._pinned.pin_enemy(app.enemies, 1, "warden"),
		"actual mounted enemy has cross-owner Pinned, Block and Exposed")
	for hero in app.party._heroes:
		if hero.id == "seamstress":
			hero["statuses"] = {"weak": 1}
	var base := "seamstress_needle_pin"
	var plus := "seamstress_needle_pin_plus"
	app.deck.hand.assign([base, plus])
	app.deck.combat_state.energy = 3
	app._refresh_hand()
	await _frames()
	var initial := _snapshot()
	var pin_before = presenter._pinned._pinner_by_position.duplicate(true)
	var gauge_before = presenter._unravel._gauges.duplicate(true)
	var latch_before = shared.latch_snapshot()
	_check(_panel(base) != null and _panel(plus) != null
		and presenter._bindings.has(_panel(base)) and presenter._bindings.has(_panel(plus)),
		"physical hand contains both eligible sewn attack variants")
	if _panel(base) == null or _panel(plus) == null:
		await _return()
		return
	await _hover(_panel(base))
	var forecast: Dictionary = presenter.current_forecast.duplicate(true)
	var expected: Dictionary = {}
	for hit in forecast.get("hits", []):
		if hit.position == 1:
			expected = hit
	_check(forecast.get("playable", false) and expected.damage == 10
		and expected.pinned_bonus == 5 and expected.exposed_applied == 1
		and expected.exposed_before == 1 and expected.exposed_after == 2
		and presenter.cue.text.contains("1: 10 damage (+5 Pinned)")
		and presenter.cue.text.contains("Exposed 1 → 2 after hit"),
		"real held Pin forecasts ARM + cross-pin + Weak/Exposed and after-hit Eye")
	_check(_snapshot() == initial and shared.latch_snapshot() == latch_before
		and presenter._pinned._pinner_by_position == pin_before
		and presenter._unravel._gauges == gauge_before,
		"real physical hover remains pure across deck, enemies, RNG, pin, gauge and latch")
	await _click(_panel(base))
	await _click(app.get_node("LiveEnemyRoster")._labels[0])
	var event: Dictionary = presenter.last_event.duplicate(true)
	_check(event.get("ok", false) and event.damage == expected.damage
		and event.block_absorbed == 6 and event.hp_loss == 4
		and event.pinned_bonus == 5 and app.enemies.get_enemy(1).hp == 196
		and app.enemies.get_enemy(1).statuses.exposed == 2,
		"physical mouse hit equals forecast and applies Eye only after damage")
	_check(app.deck.energy == 2 and not app.deck.hand.has(base)
		and app.deck.hand.has(plus) and app.deck.discard_pile.count(base) == initial[2].count(base) + 1
		and shared.latch_snapshot().seamstress
		and presenter._pinned.pinner_for_enemy(1) == "seamstress",
		"one real cost/discard, pin replacement and shared first-attack consumption")
	# Rebuilding the held hand must never replace the shared rules or reset
	# its consumed Eye; further attacks still get the ARM bonus.
	app._refresh_hand()
	await _frames()
	_check(presenter._controls._patches == shared and presenter._play._patches == shared
		and shared.latch_snapshot().seamstress, "real hand rebuild retains exact used latch")
	var refreshed := _snapshot()
	await _key(KEY_P)
	_check(presenter._armed != null and presenter._card_id(presenter._armed) == plus,
		"P physically arms remaining Needle Pin+ panel")
	forecast = presenter.current_forecast.duplicate(true)
	expected = {}
	for hit in forecast.get("hits", []):
		if hit.position == 1:
			expected = hit
	# Exposed stacks affect duration, not magnitude: floor((4 + ARM 1) * 9/8) = 5.
	_check(forecast.get("playable", false) and expected.damage == 5
		and expected.pinned_bonus == 0 and not expected.has("exposed_applied")
		and _snapshot() == refreshed and shared.latch_snapshot().seamstress,
		"post-refresh Needle Pin+ forecast reads used Eye and same-owner pin")
	await _key(KEY_1)
	event = presenter.last_event.duplicate(true)
	_check(event.get("ok", false) and event.damage == expected.damage
		and app.deck.energy == 1 and not app.deck.hand.has(plus)
		and app.deck.discard_pile.count(plus) == initial[2].count(plus) + 1
		and shared.latch_snapshot().seamstress
		and app.enemies.get_enemy(1).statuses.exposed == 2,
		"physical keyboard Needle Pin+ commits once without repeated Eye")
	await _return()

## The shipped app's exact hand panel and mounted picker, never a detached
## resolver-only fixture. Both Monk seats and all six catalog printings play.
func _monk_mount(id: String, seat: int, mode: String = "") -> bool:
	if not await _start(_seed_for("warden_strike")):
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = 8712
	app.run_rng = rng
	app.deck = CombatDeck.new([id, "warden_strike", "warden_brace",
		"tinker_pop_shot", "tinker_tune_up"], rng)
	_check(app.deck.start_turn() and app.deck.hand.size() == 5
		and app.deck.hand.has(id) and app.deck.energy == 3,
		"Monk precondition: authentic held printing, active three-energy turn: " + id)
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 25}]
	heroes.insert(seat - 1, {"id": "lantern_monk", "name": "Lantern Monk", "max_hp": 27})
	app.party = CombatParty.new(heroes)
	app.enemies = CombatEnemies.new([
		{"id": "ragling", "name": "Ragling", "max_hp": 30},
		{"id": "ragling_guard", "name": "Guard Ragling", "max_hp": 30},
		{"id": "fray_scavenger", "name": "Fray Scavenger", "max_hp": 30}])
	if mode == "block":
		_check(app.enemies.gain_block(1, 30), "Monk blocked hit uses real enemy Block")
	elif mode == "statuses":
		app.party._heroes[seat - 1]["statuses"] = {"weak": 1}
		app.enemies._enemies[0]["statuses"] = {"exposed": 1, "tangled": 1}
		_check(app.enemies.gain_block(1, 2), "Monk status hit uses real Block")
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies,
		app.enemy_intents, app.battle_result)
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_hand()
	await _frames()
	var panel: Control = _panel(id)
	var ready: bool = panel != null and panel.is_visible_in_tree() 		and presenter._bindings.has(panel) and app.party.is_valid() 		and app.enemies.is_valid() and app.round_flow._enemies == app.enemies
	_check(ready, "Monk living seat %d and held hand wired to live picker: %s" % [seat, id])
	return ready


func _monk_state() -> Array:
	return [_snapshot(), presenter.last_event.duplicate(true)]


func _monk_arm(panel: Control, keyboard: bool) -> void:
	if keyboard:
		for i in range(9):
			await _key(KEY_P)
			if presenter._armed == panel:
				break
	else:
		await _click(panel)
	_check(presenter._armed == panel, "Monk actual P/click selected exact held panel")


func _monk_mount_cases() -> void:
	var monk := CombatLanternMonkBlindStrikeCards.new()
	var ids := ["lantern_monk_wick_spark", "lantern_monk_wick_spark_plus",
		"lantern_monk_wick_flicker", "lantern_monk_wick_flicker_plus",
		"lantern_monk_snuff_flame", "lantern_monk_snuff_flame_plus"]
	for id in ids:
		for mode in ["plain", "block", "statuses"]:
			var seat := 3 if id.ends_with("_plus") else 2
			if not await _monk_mount(id, seat, mode):
				await _return()
				continue
			var panel: Control = _panel(id)
			var definition: Dictionary = monk.get_definition(id)
			var plan: Dictionary = monk._prepare(app.deck, app.party, app.enemies, id, 1)
			_check(not definition.is_empty() and plan.get("ok", false)
				and definition.get("owner") == "lantern_monk" and definition.get("cost") == 1,
				"nonvacuous Monk preflight and catalog-backed printing: " + id)
			var quote: Dictionary = presenter._target_preview(id)
			var visual: Dictionary = app.get_node("LiveSupportHand")._metadata.visual_state(panel)
			_check(quote.playable and quote.requires_selection
				and quote.target_positions == [1, 2, 3] and quote.hits.size() == 3
				and visual.get("playable", false),
				"mounted Monk picker and enabled authored face: " + id)
			var expected_damage: int = CombatStatuses.new().adjusted_attack_damage(
				int(plan.base_damage), plan.attacker_statuses, plan.defender_statuses)
			_check(quote.hits[0].damage == expected_damage
				and quote.hits[0].exposed_added == int(plan.exposed),
				"Monk forecast uses pre-hit modifiers and printed post-hit Exposed")
			var before := _monk_state()
			var keyboard: bool = id.ends_with("_plus")
			await _monk_arm(panel, keyboard)
			_check(_monk_state() == before and presenter.current_forecast.get("hits", []).size() == 3
				and presenter.cue.text.contains("Blind") and presenter.cue.text.contains("P / click"),
				"mounted Monk forecast doesn't spend, add statuses or consume RNG")
			presenter._queue_attack(4)
			_check(not presenter._queued and _monk_state() == before,
				"Monk refuses enemy slot four without queueing")
			var original: Dictionary = app.enemies.get_enemy(1)
			var other: Array = app.enemies.get_enemies()
			var party_before: Array = app.party.get_heroes()
			var rng_before: int = app.run_rng.state
			var absorbed: int = mini(original.block, expected_damage)
			var loss: int = mini(original.hp, expected_damage - absorbed)
			if keyboard:
				await _key(KEY_1)
			else:
				await _click(app.get_node("LiveEnemyRoster")._labels[0])
			var paid: Dictionary = presenter.last_event
			_check(paid.get("ok", false) and paid.get("card_id") == id
				and paid.get("damage") == expected_damage
				and paid.get("block_absorbed") == absorbed and paid.get("hp_loss") == loss
				and paid.get("hits", []).size() == 1 and paid.hits[0].hp_loss == loss,
				"one real confirmed Monk hit with actual observer metadata: " + id)
			var target: Dictionary = app.enemies.get_enemy(1)
			_check(target.hp == original.hp - loss and target.block == original.block - absorbed
				and target.statuses.get("blind_next_attack", 0) == 1
				and int(target.statuses.get("exposed", 0)) == int(original.get("statuses", {}).get("exposed", 0)) + int(plan.exposed),
				"selected foe gets one paid hit, Blind and AFTER-hit Exposed: " + id)
			_check(app.enemies.get_enemy(2) == other[1] and app.enemies.get_enemy(3) == other[2]
				and app.party.get_heroes() == party_before and app.run_rng.state == rng_before,
				"Monk attack isolates other slots, party and seeded RNG")
			_check(app.deck.energy == 2 and app.deck.hand.size() == 4
				and not app.deck.hand.has(id) and app.deck.discard_pile == [id]
				and app.hand_view.get_child_count() == 4,
				"Monk spends exactly one energy and discards exactly one actual card")
			var phase := CombatEnemyPhase.new()
			var attack := [{"type": "attack", "enemy_position": 1, "amount": 6, "target_position": 1}]
			var phase_party: Array = app.party.get_heroes()
			var missed := phase.execute_phase(app.party, app.enemies, attack)
			_check(missed.get("ok", false) and missed.events.size() == 1
				and not missed.events[0].applied
				and app.party.get_heroes() == phase_party
				and not app.enemies.get_enemy(1).statuses.has("blind_next_attack"),
				"Blind makes next real enemy attack miss; it is consumed without ending the turn")
			var next_attack := phase.execute_phase(app.party, app.enemies, attack)
			_check(next_attack.get("ok", false) and next_attack.events.size() == 1
				and next_attack.events[0].applied
				and app.party.get_hero(1).hp < phase_party[0].hp,
				"enemy still acts: following phase's genuine attack deals HP damage")
			var settled := _monk_state()
			await _key(KEY_1)
			_check(_monk_state() == settled, "consumed Monk hand selection cannot replay")
			await _return()

	for scenario in ["seat1", "downed", "energy", "target_dead", "replaced_target",
			"spoofed_id", "stale_panel", "switched_turn", "switched_battle", "cancelled", "unheld"]:
		if not await _monk_mount("lantern_monk_snuff_flame_plus", 2):
			await _return()
			continue
		var panel: Control = _panel("lantern_monk_snuff_flame_plus")
		if scenario in ["replaced_target", "spoofed_id", "stale_panel", "switched_turn",
				"switched_battle", "cancelled", "unheld"]:
			await _monk_arm(panel, false)
			presenter._queue_attack(1)
			_check(presenter._queued, "Monk queued a real, originally identified target: " + scenario)
		match scenario:
			"seat1":
				var hero: Dictionary = app.party._heroes[0]
				app.party._heroes[0] = app.party._heroes[1]
				app.party._heroes[1] = hero
				app.party._heroes[0].position = 1
				app.party._heroes[1].position = 2
			"downed": app.party.apply_damage(2, 999)
			"energy": app.deck.combat_state.energy = 0
			"target_dead": app.enemies.apply_damage(1, 999)
			"replaced_target":
				var old_id: String = app.enemies._enemies[0].id
				app.enemies._enemies[0].id = app.enemies._enemies[2].id
				app.enemies._enemies[2].id = old_id
			"spoofed_id": panel.get_child(0).text = "lantern_monk_snuff_flame_plus_plus"
			"stale_panel": app._refresh_hand()
			"switched_turn": app.enemy_intents._turn_index += 1
			"switched_battle": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
			"cancelled": presenter._cancel_choice()
			"unheld": app.deck.hand.erase("lantern_monk_snuff_flame_plus")
		var before := _monk_state()
		var quote: Dictionary = presenter._target_preview("lantern_monk_snuff_flame_plus")
		if scenario in ["seat1", "downed", "energy", "unheld"]:
			_check(not quote.playable, "Monk owner/energy/hand preflight refuses: " + scenario)
		if scenario == "target_dead":
			_check(not quote.target_positions.has(1), "dead target excluded by Monk picker")
		await _frames()
		_check(_monk_state() == before and app.deck.discard_pile.is_empty(),
			"stale/illegal Monk callback leaves complete battle and RNG unchanged: " + scenario)
		await _return()


func _blind_mounted_attack() -> void:
	var id := "warden_strike"
	if not await _start(_seed_for(id)):
		return
	_check(app.party.get_hero(1).id == "warden" and app.party.get_hero(1).hp > 0
		and not app.enemies.is_slain(1) and app.deck.hand.has(id),
		"Blind mounted preconditions: living Warden, enemy and genuine held Strike")
	app.deck.hand.assign([id, "warden_brace", id])
	app.deck.combat_state.energy = 3
	app._refresh_hand()
	await _frames()
	app.party._heroes[0]["statuses"] = {"blind_next_attack": 1}
	var enemy_before: Array[Dictionary] = app.enemies.get_enemies()
	var rng_before: int = app.run_rng.state
	var party_before: Array[Dictionary] = app.party.get_heroes()
	var pinned_before: Dictionary = presenter._pinned._pinner_by_position.duplicate(true)
	var tinker_before = presenter._play._tinker._consumed
	# A nonattack card is still physically playable, not a token consumer.
	var brace = _panel("warden_brace")
	_check(brace != null and brace.gui_input.get_connections().size() == 1,
		"mounted nonattack Brace remains bound under Blind")
	if brace != null:
		await _click(brace)
	_check(app.party.get_hero(1).statuses.get("blind_next_attack") == 1
		and app.party.get_hero(1).block > party_before[0].block
		and app.deck.energy == 2 and app.deck.hand.has(id),
		"actual nonattack spends normally, leaves Blind token intact")
	# Choosing an unsupported enemy slot must not pay or consume.
	await _choose(id, true)
	var before := _snapshot()
	await _key(KEY_3)
	_check(_snapshot() == before and app.party.get_hero(1).statuses.get("blind_next_attack") == 1,
		"real rejected keyboard target has zero payment and preserves Blind")
	await _choose(id, true)
	await _key(KEY_1)
	_check(presenter.last_event.get("ok") == true and presenter.last_event.get("miss") == true
		and presenter.last_event.get("hits") == []
		and presenter.last_event.get("damage") == 0,
		"actual mounted held Strike resolves one paid miss, not an attack hit")
	_check(app.deck.energy == 1 and app.deck.hand.count(id) == 1
		and app.deck.discard_pile.count(id) == 1,
		"one energy and precisely one of two real held copies paid")
	_check(app.party.get_hero(1).get("statuses", {}).get("blind_next_attack", 0) == 0
		and app.enemies.get_enemies() == enemy_before
		and app.run_rng.state == rng_before
		and presenter._pinned._pinner_by_position == pinned_before
		and presenter._play._tinker._consumed == tinker_before,
		"paid miss changes no enemy HP/status, seeded RNG or confirmed-hit bonuses")
	# With the one-shot consumed, the next legal held attack truly lands.
	await _choose(id, true)
	await _key(KEY_1)
	_check(presenter.last_event.get("ok") == true
		and not presenter.last_event.get("miss", false)
		and not presenter.last_event.get("hits", []).is_empty()
		and app.enemies.get_enemy(1).hp < enemy_before[0].hp,
		"next ordinary attack hits normally after precisely one Blind miss")
	await _return()
