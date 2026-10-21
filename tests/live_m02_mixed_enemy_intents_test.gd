extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

func _snapshot(app) -> Array:
	return [app.party.get_heroes(), app.enemies.get_enemies(), app.deck.hand.duplicate(),
		app.deck.draw_pile.duplicate(), app.deck.discard_pile.duplicate(), app.deck.energy,
		app.deck.turn_active, app.run_rng.state, app.enemy_intents._turn_index,
		app.enemy_attacks.duplicate(true), app.battle_result.get_outcome()]

func _set_actions(app, first: Dictionary, second: Dictionary) -> void:
	app.enemy_intents = CombatEnemyIntents.new([
		{"enemy_position": 2, "pattern": [second]}, {"enemy_position": 1, "pattern": [first]}])
	_check(app.enemy_intents.is_valid(), "otherwise valid late-action fixture")
	app.round_flow._intents = app.enemy_intents
	app.enemy_attacks = app.enemy_intents.get_intents()
	app._refresh_intents()


## The live hero meters the player sees: one Incoming line per presented slot.
func _incoming(app) -> Array:
	var texts: Array = []
	var presenter = app.get_node_or_null("LiveCombatMeters")
	if presenter == null or presenter.row == null or presenter.row.get_child_count() < CombatParty.PARTY_SIZE:
		return texts
	for index in range(CombatParty.PARTY_SIZE):
		var line = presenter.row.get_child(index).get_node_or_null("Padding/Content/IncomingForecast")
		texts.append("" if line == null else line.text)
	return texts

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app = load("res://scenes/app.tscn").instantiate()
	app.starter_attacks_path = "res://data/encounters/m02_mixed_intents.json"
	root.add_child(app)
	await process_frame
	var replay: Array = []
	for session in range(2):
		app.run_seed = 54054
		app.start_button.pressed.emit()
		await process_frame
		_check(app.party != null and app.enemies != null and app.round_flow != null
			and app.deck.turn_active and app.end_turn_button.is_visible_in_tree(), "real mixed fight mounted")
		if app.party == null or app.deck == null:
			app.free()
			quit(1)
			return
		var definitions: Array = app._load_enemy_schedule()
		var scheduler := CombatEnemyIntents.new(definitions)
		_check(scheduler.is_valid(), "authored complete mixed pattern loads")
		var original := definitions.duplicate(true)
		definitions[0].pattern[0].direction = -1
		var reference := CombatEnemyIntents.new(original)
		for turn in range(11):
			_check(scheduler.get_intents() == reference.get_intents(), "entire timeline and wrap replay")
			var isolated := scheduler.get_intents()
			isolated[0].amount = 999
			_check(scheduler.get_intents() == reference.get_intents(), "announcements detached")
			scheduler.advance_turn()
			reference.advance_turn()
		var trace: Array = [_snapshot(app)]
		var warden: Dictionary = app.party._heroes[0]
		warden["metadata"] = {"retained": [1, 2]}
		warden["statuses"] = {"weak": 3}
		var expected_text := [
			"Intent: Enemy 1: Shove Hero 1 back; Enemy 2 -> Hero 1: Exposed 2",
			"Intent: Enemy 1: Buff +3 Block; Enemy 2 -> Hero 1 (Seamstress): 5 damage",
			"Intent: Enemy 1: 2 Block; Enemy 2 -> Hero 2: Bleed 2",
			"Intent: Enemy 1 -> Hero 3: Weak 2; Enemy 2 -> Hero 3 (Tinker): 4 damage",
			"Intent: Enemy 1: Shove Hero 2 front; Enemy 2: 1 Block"]
		var badges := [
			["SHOVE HERO 1 BACK", "EXPOSED 2 -> HERO 1"],
			["BUFF BLOCK +3", "ATTACK 5 -> HERO 1"],
			["BLOCK +2", "BLEED 2 -> HERO 2"],
			["WEAK 2 -> HERO 3", "ATTACK 4 -> HERO 3"],
			["SHOVE HERO 2 FRONT", "BLOCK +1"]]
		for turn in range(5):
			app._refresh_intents()
			await process_frame
			_check(app.intent_label.text == expected_text[turn], "exact mounted mixed text")
			var presenter = app.get_node("LiveEnemyRoster")
			_check(presenter._badges.size() == 2, "two mounted source badges")
			var cues := CombatIntentCues.new().get_cues(app.enemy_intents, app.enemies)
			for index in range(2):
				var badge = presenter._badges[index]
				_check(badge.is_visible_in_tree() and badge.readable_text == badges[turn][index]
					and badge.icon_mode == cues[index].icon_key, "typed readable badge")
				_check(Rect2(0, 0, 1280, 720).encloses(badge.get_global_rect()), "badge fits viewport")
			_check(Rect2(0, 0, 1280, 720).encloses(app.end_turn_button.get_global_rect()), "End Turn fits viewport")
			await process_frame
			var incoming := _incoming(app)
			_check(incoming.size() == CombatParty.PARTY_SIZE
				and not incoming.has("Incoming: unavailable"),
				"mounted mixed kinds never fall back to unavailable: turn " + str(turn))
			if turn == 0:
				_check(incoming == ["Incoming: none", "Incoming: none", "Incoming: none"],
					"mounted shove and Exposed turn forecasts no hero attack damage")
			elif turn == 1:
				_check(incoming == ["Incoming: 0 Block, 7 HP", "Incoming: none", "Incoming: none"],
					"mounted buff and attack forecast the shove moved Exposed front hero only")
			elif turn == 3:
				_check(incoming == ["Incoming: none", "Incoming: none", "Incoming: 0 Block, 4 HP"],
					"mounted Weak and attack forecast the fixed back hero only")
			var before := _snapshot(app)
			app.end_turn_button.pressed.emit()
			_check(app.enemy_intents._turn_index == turn + 1, "phase commits and advances once")
			var after := _snapshot(app)
			app.end_turn_button.pressed.emit()
			_check(_snapshot(app) == after, "duplicate dispatch inert")
			if turn == 0:
				_check(app.party.get_hero(1).id == "seamstress" and app.party.get_hero(1).statuses == {"exposed": 2}, "debuff binds new occupant after earlier shove")
				_check(is_same(app.party._heroes[1], warden) and warden.statuses == {"weak": 2}
					and warden.metadata == {"retained": [1, 2]}, "status and metadata follow original actor identity")
			if turn == 1:
				_check(app.enemies.get_enemy(1).block == 3 and app.party.get_hero(1).hp == before[0][0].hp - 7, "buff and Exposed attack resolve original base amount")
			if turn == 2:
				_check(app.party.get_hero(2).statuses == {"bleed": 2} and app.enemies.get_enemy(1).block == 5, "Bleed applies after owner tick; Block adds")
			trace.append(after)
			await process_frame
		if session == 0:
			replay = trace
		else:
			_check(trace == replay, "same seed full actors deck turn announcements RNG replay")
		app.return_button.pressed.emit()
		await process_frame
	await _rejections(app)
	app.free()
	for failure in failures:
		printerr(failure)
	print("live_m02_mixed_enemy_intents_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)

func _rejections(app) -> void:
	for mode in ["late_shove", "late_debuff", "overflow", "status_overflow", "stale", "roster", "dead"]:
		app.start_button.pressed.emit()
		await process_frame
		_check(app.party != null and app.deck.turn_active, "negative fixture mounted active")
		var attack := {"type": "attack", "amount": 5, "target_position": 1}
		var debuff := {"type": "debuff", "amount": 1, "status": "weak", "target_position": 1}
		if mode == "late_shove":
			_set_actions(app, attack, {"type": "shove", "amount": 0, "target_position": 1, "direction": 1})
			app.party._heroes[1].hp = 0
		elif mode == "late_debuff":
			_set_actions(app, {"type": "attack", "amount": 999, "target_position": 1}, debuff)
		elif mode == "overflow":
			_set_actions(app, attack, {"type": "buff", "amount": 1})
			app.enemies._enemies[1].block = CombatEnemies.MAX_INT
		elif mode == "status_overflow":
			_set_actions(app, attack, debuff)
			app.party._heroes[0]["statuses"] = {"weak": CombatParty.MAX_INT}
			app.enemy_intents._definitions[0].pattern[0].amount = 2
			app.enemy_attacks = app.enemy_intents.get_intents()
		elif mode == "stale":
			app.enemy_attacks[0].direction = -1
		elif mode == "roster":
			app.enemies._enemies[1].position = 1
		elif mode == "dead":
			app.enemies._enemies[0].hp = 0
		var before := _snapshot(app)
		app.end_turn_button.pressed.emit()
		if mode == "dead":
			_check(app.party.get_hero(1).id == "warden" and app.party.get_hero(1).statuses == {"exposed": 2}
				and app.enemy_intents._turn_index == 1, "slain shove source inert; living debuff still acts")
		else:
			_check(_snapshot(app) == before and not app.end_turn_button.disabled, "full atomic rejection: " + mode)
		app.return_button.pressed.emit()
		await process_frame
