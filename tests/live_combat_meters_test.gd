extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _frames() -> void:
	for frame in range(4):
		await process_frame


func _state(app) -> Array:
	return [app.party.get_heroes(), app.enemies.get_enemies(), app.deck.hand.duplicate(),
		app.deck.draw_pile.duplicate(), app.deck.discard_pile.duplicate(), app.deck.energy,
		app.deck.turn_active, app.run_rng.state, app.enemy_intents.get_intents(), app.enemy_attacks.duplicate(true)]


func _meters(app) -> Array[CombatActorMeter]:
	var result: Array[CombatActorMeter] = []
	for node in app.find_children("*", "VBoxContainer", true, false):
		if node is CombatActorMeter:
			result.append(node)
	return result


func _visible(app) -> void:
	var meters := _meters(app)
	_check(meters.size() == 5, "exactly five real actor meters")
	if meters.size() != 5:
		return
	var actors: Array = app.party.get_heroes() + app.enemies.get_enemies()
	for index in range(5):
		var meter := meters[index]
		var actor: Dictionary = actors[index]
		var heading := "%d. %s" % [actor.position, actor.name]
		if actor.hp == 0:
			heading += " — DOWNED" if index < 3 else " — SLAIN"
		_check(meter.actor_heading.text == heading, "ordered exact actor heading %d" % index)
		_check(meter.hp_text.text == "HP: %d/%d" % [actor.hp, actor.max_hp]
			and meter.hp_bar.value == actor.hp and meter.hp_bar.max_value == actor.max_hp,
			"exact HP text and bar %d" % index)
		_check(meter.block_text.text == "Block: %d" % actor.block and meter.block_bar.value == actor.block
			and meter.block_bar.max_value == maxi(1, maxi(actor.max_hp, actor.block)), "exact Block %d" % index)
		for control in [meter, meter.actor_heading, meter.hp_text, meter.hp_bar, meter.block_text, meter.block_bar]:
			_check(control.is_visible_in_tree() and control.size.x > 0 and control.size.y > 0,
				"meter controls visibly mounted")
			_check(Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()), "meter controls fit viewport")
			_check(control.mouse_filter == Control.MOUSE_FILTER_IGNORE and control.focus_mode == Control.FOCUS_NONE,
				"meters never intercept mouse or keyboard")
		for control in [app.hero_view, app.hand_view, app.end_turn_button, app.return_button]:
			_check(not meter.get_global_rect().intersects(control.get_global_rect()), "meters do not obstruct controls")
		for other in meters:
			if other != meter:
				_check(not meter.get_global_rect().intersects(other.get_global_rect()), "meter rectangles do not overlap")
	for control in [app.hero_view, app.hand_view, app.end_turn_button, app.return_button]:
		_check(control.is_visible_in_tree() and Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()),
			"existing battle controls fit viewport")
	_check(app.end_turn_button.focus_next == app.end_turn_button.get_path_to(app.return_button), "existing Tab cycle")


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await _frames()


func _mouse(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await _frames()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real scene loads")
	if scene == null:
		_finish()
		return
	var app = scene.instantiate()
	root.add_child(app)
	await _frames()
	var presenter = app.get_node_or_null("LiveCombatMeters")
	_check(presenter != null and is_instance_valid(app.start_button), "mounted presenter and Start Run exist")
	if presenter == null or not is_instance_valid(app.start_button):
		app.free()
		_finish()
		return
	_check(app.title_view.is_visible_in_tree() and _meters(app).is_empty(), "title has no meters")
	app.starter_party_path = "user://missing_meter_party/invalid.json"
	await _mouse(app.start_button)
	_check(app.deck == null and app.party == null and app.enemies == null and presenter.row == null,
		"failed actual Start Run creates no partial meters or rules")
	app._end_turn()
	await _frames()
	_check(_meters(app).is_empty(), "inactive End Turn has no presentation")
	app.starter_party_path = app.STARTER_PARTY_PATH
	var replay: Array = []
	for session in range(2):
		app.start_button.grab_focus()
		await _key(KEY_ENTER)
		_check(app.deck is CombatDeck and app.party is CombatParty and app.enemies is CombatEnemies
			and app.run_rng != null and is_instance_valid(app.battle_view), "real keyboard Start Run constructs battle")
		if app.deck == null or app.party == null or app.enemies == null:
			break
		_check(app.party.get_hero(1).name == "Warden" and app.party.get_hero(1).block == 6
			and app.enemies.get_enemy(2).name == "Guard Ragling", "authored five-actor preconditions")
		# Explicit failure probes ensure missing controls/wrong values cannot pass vacuously.
		if "--inject-missing-control" in OS.get_cmdline_user_args():
			presenter.row.get_child(0).free()
			_visible(app)
			app.free()
			_finish()
			return
		if "--inject-wrong-value" in OS.get_cmdline_user_args():
			presenter.row.get_child(0).hp_bar.value = 1
			_visible(app)
			app.free()
			_finish()
			return
		_visible(app)
		var initial := _state(app)
		if session == 0:
			replay = initial
		else:
			_check(initial == replay, "same-seed replay restores full initial state")
		var ids: Array[int] = []
		for meter in _meters(app):
			ids.append(meter.get_instance_id())
		app.start_button.pressed.emit()
		for frame in range(8):
			presenter._sync_battle()
			await process_frame
		_check(_state(app) == initial and _meters(app).size() == 5, "duplicate frames/start never spend or duplicate")
		for index in range(_meters(app).size()):
			_check(_meters(app)[index].get_instance_id() == ids[index], "refresh reuses existing nodes")
		app.end_turn_button.disabled = true
		app.end_turn_button.pressed.emit()
		await _frames()
		_check(_state(app) == initial, "disabled End Turn has no state changes")
		app.end_turn_button.disabled = false
		await _mouse(app.end_turn_button)
		_check(app.party.get_hero(1).hp == 40 and app.party.get_hero(1).block == 0
			and app.enemies.get_enemy(2).block == 1, "actual turn absorbs attack and executes second enemy Block")
		_visible(app)
		# Direct valid model changes must refresh without app refresh callbacks.
		_check(app.party.gain_block(2, 7) and app.party.apply_damage(2, 3), "valid hero Block absorption")
		_check(app.party.apply_damage(3, 999) and app.enemies.gain_block(1, 8)
			and app.enemies.apply_damage(1, 3) and app.enemies.apply_damage(2, 999), "valid HP/Block and zero HP mutations")
		var before := _state(app)
		await _frames()
		_visible(app)
		_check(_state(app) == before, "display refresh preserves every model, energy, piles, intents and RNG")
		# Each source identity change tears down the old presentation, even with identical values.
		for source in ["party", "enemies", "deck"]:
			var old_ids: Array[int] = []
			for meter in _meters(app):
				old_ids.append(meter.get_instance_id())
			if source == "party":
				app.party = CombatParty.new(app._load_party_definitions())
			elif source == "enemies":
				app.enemies = CombatEnemies.new(app._load_enemy_definitions())
			else:
				app.deck = CombatDeck.new(["warden_brace"], app.run_rng)
				app.deck.start_turn()
			await _frames()
			_visible(app)
			for id in old_ids:
				_check(not is_instance_id_valid(id), "source replacement frees stale meters: " + source)
		# Invalid/inactive sources clear synchronously; restoring a valid source rebuilds once.
		for source in ["party", "enemies", "deck", "hidden"]:
			var before_rejection := _state(app)
			var party: CombatParty = app.party
			var enemies: CombatEnemies = app.enemies
			var deck: CombatDeck = app.deck
			if source == "party":
				app.party = CombatParty.new([])
			elif source == "enemies":
				app.enemies = CombatEnemies.new([])
			elif source == "deck":
				app.deck = null
			else:
				app.battle_view.hide()
			presenter._sync_battle()
			_check(presenter.row == null and _meters(app).is_empty(), "invalid/inactive source clears meters: " + source)
			app.party = party
			app.enemies = enemies
			app.deck = deck
			app.battle_view.show()
			await _frames()
			_visible(app)
			_check(_state(app) == before_rejection, "rejection/rebuild leaves surviving models unchanged")
		var final_ids: Array[int] = []
		for meter in _meters(app):
			final_ids.append(meter.get_instance_id())
		await _mouse(app.return_button)
		_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus()
			and presenter.row == null and _meters(app).is_empty(), "real Return clears presentation and restores focus")
		for id in final_ids:
			_check(not is_instance_id_valid(id), "Return frees old meter")
	app.free()
	await _frames()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_combat_meters_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
