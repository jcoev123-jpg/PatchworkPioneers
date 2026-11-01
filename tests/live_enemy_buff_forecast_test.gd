extends SceneTree

const STARTER_ORACLE := preload("res://tests/starter_fight_oracle.gd")

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _snapshot(app) -> Array:
	return [app.party.get_heroes(), app.enemies.get_enemies(),
		app.deck.draw_pile.duplicate(true), app.deck.hand.duplicate(true),
		app.deck.discard_pile.duplicate(true), app.deck.energy, app.deck.turn_active,
		app.run_rng.seed, app.run_rng.state, app.enemy_intents._turn_index,
		app.enemy_intents._definitions.duplicate(true), app.enemy_intents.get_intents(),
		app.enemy_attacks.duplicate(true), app.battle_result.get_outcome(), app.intent_label.text]


func _mouse(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)


func _key(button: Button) -> void:
	button.grab_focus()
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event, true)


func _visible(app, before: int, after: int) -> void:
	var label = app.enemy_buff_forecast_label
	_check(is_instance_valid(label), "forecast label exists")
	if not is_instance_valid(label):
		return
	_check(label is Label and app.battle_view.is_ancestor_of(label) and label.is_visible_in_tree(),
		"forecast is mounted and visible")
	_check(after - before == 5 and label.text == "Guard Ragling braces: +5 Block",
		"forecast names Guard and its exact +5 gain without exposing before/after telemetry")
	var rect: Rect2 = label.get_global_rect()
	_check(rect.size.x > 0 and rect.size.y > 0 and Rect2(0, 0, 1280, 720).encloses(rect),
		"forecast fits viewport")
	var meters = app.get_node("LiveCombatMeters").row
	_check(is_instance_valid(meters) and meters.is_visible_in_tree()
		and meters.get_child_count() == CombatParty.PARTY_SIZE + app.enemies.get_enemies().size(),
		"all real actor HP and Block meters stay mounted")
	var roster = app.get_node("LiveEnemyRoster")
	_check(roster._badges.size() == app.enemies.get_enemies().size()
		and roster._badges[1].is_visible_in_tree()
		and Rect2(0, 0, 1280, 720).encloses(roster._badges[1].get_global_rect()),
		"Guard source intent badge remains independently mounted and in viewport")
	_check(is_instance_valid(meters) and rect.position.y >= meters.get_global_rect().end.y
		and not rect.intersects(meters.get_global_rect()), "forecast remains directly below the consolidated actor readouts")
	_check(app.end_turn_button.is_visible_in_tree() and app.return_button.is_visible_in_tree()
		and Rect2(0, 0, 1280, 720).encloses(app.end_turn_button.get_global_rect()) \
		and Rect2(0, 0, 1280, 720).encloses(app.return_button.get_global_rect()),
		"battle actions remain inside viewport")


func _immutable_refresh(app) -> void:
	var before := _snapshot(app)
	var cue_before: String = app.enemy_buff_forecast_label.text
	var visible_before: bool = app.enemy_buff_forecast_label.visible
	seed(51601)
	var expected := randi()
	seed(51601)
	for repeat in range(5):
		app._refresh_intents()
		app._refresh_party()
		app._refresh_enemy_roster()
	_check(randi() == expected, "refresh does not consume global RNG")
	_check(_snapshot(app) == before, "repeated refresh preserves full actors, piles, energy, RNG and announcements")
	_check(app.enemy_buff_forecast_label.text == cue_before and app.enemy_buff_forecast_label.visible == visible_before,
		"repeated refresh preserves the projected player cue and its visibility")


func _detached_cases(app) -> void:
	var rules := LiveEnemyBuffForecast.new()
	var before := _snapshot(app)
	var batch: Array = app.enemy_attacks.duplicate(true)
	_check(rules.forecast(app.party, app.enemies, batch) == [
		{"enemy_position": 2, "name": "Guard Ragling", "before": 10, "after": 15}], "helper projects exact current Block")
	_check(rules.forecast(app.party, app.enemies, [{"type": "buff", "enemy_position": 2, "amount": 1}]) == [
		{"enemy_position": 2, "name": "Guard Ragling", "before": 10, "after": 11}], "typed buff projects exact current Block")
	var special_batch: Array = [{"type": "buff", "enemy_position": 1, "amount": 2},
		{"type": "debuff", "enemy_position": 2, "amount": 1, "target_position": 3, "status": "weak"}]
	var original_hero: Dictionary = app.party._heroes[2].duplicate(true)
	app.party._heroes[2].hp = 1
	app.party._heroes[2]["statuses"] = {"bleed": 1}
	var dying := _snapshot(app)
	_check(rules.forecast(app.party, app.enemies, special_batch).is_empty()
		and _snapshot(app) == dying, "forecast accounts for owner Bleed before illegal late debuff without writes")
	app.party._heroes[2] = original_hero
	var bad_batches: Array = [[null], [{"type": "buff", "enemy_position": 2, "amount": 0}]]
	for bad in [-1, 0.5, true, "1", null]:
		var invalid := batch.duplicate(true)
		invalid[1].amount = bad
		bad_batches.append(invalid)
	var duplicate := batch.duplicate(true)
	duplicate.append(batch[1].duplicate(true))
	bad_batches.append(duplicate)
	var late_invalid := batch.duplicate(true)
	late_invalid.reverse()
	late_invalid[1].target_position = 4
	bad_batches.append(late_invalid)
	for invalid in bad_batches:
		_check(rules.forecast(app.party, app.enemies, invalid).is_empty(), "invalid batch advertises nothing")
		_check(_snapshot(app) == before, "invalid batch preserves surviving live models")
	_check(rules.forecast(null, app.enemies, batch).is_empty() \
		and rules.forecast(app.party, null, batch).is_empty() \
		and rules.forecast(CombatParty.new([]), app.enemies, batch).is_empty(), "missing/invalid roster fails closed")
	_check(_snapshot(app) == before, "null/invalid roster leaves survivors unchanged")
	var zero := batch.duplicate(true)
	zero[1].amount = 0
	_check(rules.forecast(app.party, app.enemies, zero).is_empty(), "zero Block has no forecast")
	app.enemy_attacks = zero
	app._refresh_intents()
	_check(app.enemy_buff_forecast_label.text.is_empty() and not app.enemy_buff_forecast_label.visible,
		"stale announcement clears mounted forecast")
	app.enemy_intents._cache[1]["amount"] = 0
	app.enemy_attacks = app.enemy_intents.get_intents()
	app._refresh_intents()
	_check(app.enemy_buff_forecast_label.text.is_empty() and not app.enemy_buff_forecast_label.visible,
		"valid announced zero Block clears mounted forecast")
	app.enemy_intents._cache[1]["amount"] = 5
	app.enemy_attacks = app.enemy_intents.get_intents()
	app._refresh_intents()
	_check(_snapshot(app) == before, "zero and stale fixtures restore full original state")
	app.enemies._enemies[1].block = CombatEnemies.MAX_INT
	var overflow := _snapshot(app)
	_check(rules.forecast(app.party, app.enemies, batch).is_empty(), "overflowing detached action fails closed")
	app._refresh_intents()
	_check(app.enemy_buff_forecast_label.text.is_empty() and not app.enemy_buff_forecast_label.visible,
		"overflow clears mounted forecast")
	_check(_snapshot(app) == overflow, "overflow never mutates live Block or other state")
	var late_overflow: Array = [{"type": "block", "enemy_position": 1, "amount": 1}, batch[1]]
	_check(rules.forecast(app.party, app.enemies, late_overflow).is_empty() \
		and _snapshot(app) == overflow, "late overflowing buff publishes neither earlier forecast nor live write")
	app.enemies._enemies[1].block = 10
	# Two buffs in deliberately reversed source order; outputs retain caller order.
	var ordered: Array = [{"type": "block", "enemy_position": 2, "amount": 1},
		{"type": "block", "enemy_position": 1, "amount": 2}]
	var ordered_before := ordered.duplicate(true)
	var result := rules.forecast(app.party, app.enemies, ordered)
	_check(result.size() == 2 and result[0].enemy_position == 2 and result[1].enemy_position == 1 \
		and result[0].after == 11 and result[1].after == 2, "multiple sources preserve input order and actual totals")
	if not result.is_empty():
		result[0].after = -1
	_check(rules.forecast(app.party, app.enemies, ordered)[0].after == 11 \
		and ordered == ordered_before and _snapshot(app) == before, "results and nested inputs are detached")
	# Only the presentation sees these two valid projections; restore the real announcements.
	var saved_cache: Array[Dictionary] = app.enemy_intents._cache.duplicate(true)
	var scripted: Array[Dictionary] = []
	scripted.assign(ordered)
	app.enemy_intents._cache = scripted
	app.enemy_attacks = app.enemy_intents.get_intents()
	app._refresh_intents()
	_check(app.enemy_buff_forecast_label.text ==
		"Guard Ragling braces: +1 Block; Ragling braces: +2 Block"
		and app.enemy_buff_forecast_label.is_visible_in_tree(),
		"multiple admitted source-owned buffs join compactly in announcement order")
	app.enemy_intents._cache = saved_cache
	app.enemy_attacks = app.enemy_intents.get_intents()
	app._refresh_intents()
	_check(_snapshot(app) == before, "mounted multi-buff presentation restores real announcements without model writes")


func _run() -> void:
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "actual app scene loads")
	if scene == null:
		_finish()
		return
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	_check(STARTER_ORACLE.pin_guard_block(app, "user://live_enemy_buff_forecast_guard.json"),
		"shipped Guard Ragling pinned to its own authored Block alternative")
	_check(app.title_view.is_visible_in_tree() and app.enemy_buff_forecast_label == null, "title has no forecast")
	var replay: Array = []
	for session in range(2):
		_fixture_start(app)
		await process_frame
		await process_frame
		await process_frame
		var ready: bool = app.party != null and app.enemies != null and app.deck != null \
			and app.enemy_intents != null and is_instance_valid(app.end_turn_button)
		_check(ready, "physical title Start creates real battle services")
		if not ready:
			app.free()
			_finish()
			return
		_check(app.enemies.get_enemy(2).name == "Guard Ragling" and app.enemies.get_enemy(2).hp > 0 \
			and app.enemies.get_enemy(2).block == 0 and app.enemy_attacks[1] == \
			{"type": "block", "enemy_position": 2, "amount": 5}, "living authored Guard announces Block 5")
		if "--inject-wrong-forecast" in OS.get_cmdline_user_args():
			app.enemy_buff_forecast_label.text = "wrong"
		if "--inject-missing-forecast" in OS.get_cmdline_user_args():
			app.enemy_buff_forecast_label.free()
		_visible(app, 0, 5)
		if not failures.is_empty():
			app.free()
			_finish()
			return
		var trace: Array = [_snapshot(app)]
		for turn in range(2):
			_immutable_refresh(app)
			if turn == 0:
				_mouse(app.end_turn_button)
			else:
				_key(app.end_turn_button)
			await process_frame
			await process_frame
			_check(app.enemies.get_enemy(2).block == (turn + 1) * 5 \
				and app.enemy_intents._turn_index == turn + 1, "physical End Turn applies exactly one stacking buff")
			_visible(app, (turn + 1) * 5, (turn + 2) * 5)
			_immutable_refresh(app)
			trace.append(_snapshot(app))
		if session == 0:
			replay = trace.duplicate(true)
		else:
			_check(trace == replay, "same seed restart replays full states and announcements")
		_detached_cases(app)
		# Statuses and arbitrary nested actor metadata survive read-only projection too.
		app.party._heroes[0]["statuses"] = {"bleed": 2, "weak": 1}
		app.enemies._enemies[1]["statuses"] = {"exposed": 2}
		app.enemies._enemies[1]["metadata"] = {"nested": [1, {"value": 2}]}
		_immutable_refresh(app)
		_visible(app, 10, 15)
		_check(app.enemies.apply_damage(2, 999) and app.enemies.is_slain(2) \
			and not app.enemies.is_defeated(), "Guard slain while another enemy keeps battle active")
		app._refresh_intents()
		_check(app.enemy_buff_forecast_label.text.is_empty() and not app.enemy_buff_forecast_label.visible,
			"slain Guard omitted from mounted forecast")
		_immutable_refresh(app)
		_check(app.enemies.apply_damage(1, 999), "final enemy can be slain")
		app._observe_battle_result()
		_check(app._battle_closed and app.enemy_buff_forecast_label.text.is_empty(), "terminal forecast clears immediately")
		_key(app.return_button)
		await process_frame
		_check(app.battle_view == null and app.enemy_buff_forecast_label == null \
			and app.title_view.is_visible_in_tree(), "physical Return clears battle forecast before restart")
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_enemy_buff_forecast_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## Standalone M01 admission; seeded title input is covered by live_seeded_opening_route_test.
func _fixture_start(target) -> void:
	if target.deck != null:
		target.start_button.pressed.emit()
		return
	var started: bool = target._start_battle()
	_check(started == (target.deck != null), "standalone fixture reports admission consistently")
