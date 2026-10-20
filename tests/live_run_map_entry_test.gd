extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		root.push_input(event, true)
		await process_frame


func _click(button: Button) -> void:
	_check(is_instance_valid(button) and button.is_visible_in_tree(), "mouse target is mounted")
	if not is_instance_valid(button):
		return
	var point := button.get_global_rect().get_center()
	_check(root.get_visible_rect().has_point(point), "mouse target inside viewport")
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame


func _snapshot(app) -> Array:
	var result: Array = [app.run_map.get_floors(), app.run_map.get_route(),
		app.run_map.get_legal_choices(), app.run_rng.state]
	if app.deck != null:
		result.append([app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
			app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
			app.party.get_heroes(), app.enemies.get_enemies(), app.enemy_intents.get_intents()])
	else:
		result.append([app.deck, app.party, app.enemies, app.battle_view, app.round_flow, app.battle_result])
	return result


func _reject(app, id: String, reason: String) -> void:
	var before := _snapshot(app)
	_check(not app._choose_route(id), reason + " rejected")
	_check(_snapshot(app) == before, reason + " spends no map/combat/RNG state")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	# Seed 6 originally generated Rest, Rest, Treasure (pinned before the fix).
	var fixture_seed := 6
	var fight_id := "f01_n0"
	var reference_rng := RandomNumberGenerator.new()
	reference_rng.seed = fixture_seed
	var reference := RunMap.new()
	_check(reference.generate(reference_rng), "reference map exists")
	var scene: PackedScene = load("res://scenes/app.tscn")
	_check(scene != null, "real scene loads")
	if scene == null:
		_finish()
		return
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	_check(app.start_button.has_focus(), "original Start run initially focused")
	_check(app.route_button.is_visible_in_tree(), "second title action mounted")
	app.run_seed = fixture_seed
	await _key(KEY_TAB)
	_check(app.route_button.has_focus(), "second title button reached by keyboard")
	await _key(KEY_ENTER)
	_check(app.run_map != null and app.route_view != null, "keyboard opens route chooser")
	if app.run_map == null or app.route_view == null:
		app.free()
		_finish()
		return
	_check(app.run_map.get_floors() == reference.get_floors() and
		app.run_rng.state == reference_rng.state, "map generation matches reference stream")
	_check(app.deck == null and app.run_map.get_route().is_empty(), "chooser has not started combat or committed")
	_check(app.route_buttons.size() == reference.get_legal_choices().size(), "one control per actual legal opening")
	if "--inject-wrong-type" in OS.get_cmdline_user_args():
		app.route_buttons[0].text = "incorrect"
	var seen: Array = []
	for button in app.route_buttons:
		var id: String = button.get_meta("route_id")
		seen.append(id)
		_check(reference.get_legal_choices().has(id), "mounted ID is legal: " + id)
		var node := reference.get_node(id)
		_check(not node.is_empty(), "reference node exists: " + id)
		if node.is_empty():
			continue
		_check(button.is_visible_in_tree() and button.text.contains(id) and button.text.contains(node.type),
			"exact ID/type visible: " + id)
		_check(button.disabled == (node.type != "Fight"), "per-node operability: " + id)
		if button.disabled:
			_check(button.text.contains("unavailable"), "unsupported reason visible")
			var before := _snapshot(app)
			await _click(button)
			_check(_snapshot(app) == before, "disabled mouse choice is unspent")
			button.grab_focus()
			await _key(KEY_ENTER)
			_check(_snapshot(app) == before, "disabled keyboard choice is unspent")
			_reject(app, id, "unsupported callback")
	_check(seen == reference.get_legal_choices(), "all and only opening IDs displayed in map order")
	_reject(app, "unknown", "unknown choice")
	_reject(app, reference.get_floors()[1][0].id, "future unavailable node")
	var before_direct := _snapshot(app)
	app._start_run()
	app._open_route()
	_check(_snapshot(app) == before_direct, "duplicate opening/direct-start cannot overwrite route")
	var old_rng: WeakRef = weakref(app.run_rng)
	var old_map: WeakRef = weakref(app.run_map)
	var old_view: int = app.route_view.get_instance_id()
	app.route_back_button.grab_focus()
	await _key(KEY_ENTER)
	await process_frame
	_check(app.run_map == null and app.run_rng == null and app.route_view == null and
		app.route_buttons.is_empty() and app.route_back_button == null, "Back clears route models and controls")
	_check(old_rng.get_ref() == null and old_map.get_ref() == null and
		not is_instance_id_valid(old_view), "Back releases map/RNG/view")
	_check(app.route_button.has_focus() and app.title_view.is_visible_in_tree(), "Back restores title focus")
	_check(not app._choose_route(fight_id) and app.deck == null and app.run_rng == null, "cancelled callback cannot start battle")

	var trace: Array = []
	for session in range(2):
		await _click(app.route_button)
		_check(app.route_view != null, "mouse opens route chooser")
		if app.route_view == null:
			break
		var same_rng = app.run_rng
		var same_map = app.run_map
		var fight: Button = null
		for button in app.route_buttons:
			if button.get_meta("route_id") == fight_id:
				fight = button
		_check(fight != null and not fight.disabled, "available Fight fixture mounted")
		if fight == null:
			break
		if session == 0:
			await _click(fight)
		else:
			app.route_back_button.grab_focus()
			await _key(KEY_TAB)
			_check(root.gui_get_focus_owner() in app.route_buttons and not root.gui_get_focus_owner().disabled,
				"Tab from Back reaches an enabled Fight")
			fight.grab_focus()
			await _key(KEY_ENTER)
		_check(app.deck != null and app.battle_view != null, "actual input starts real battle")
		if app.deck == null:
			break
		_check(app.run_rng == same_rng and app.deck._rng == same_rng and app.run_map == same_map,
			"combat retains exact map and shared RNG objects")
		_check(app.run_map.get_route() == [fight_id] and app.run_map.get_current_floor() == 1,
			"successful combat commits exactly one node")
		_check(app.route_view == null and app.route_buttons.is_empty(), "chooser removed during battle")
		_check(app.deck.energy == 3 and app.deck.hand.size() == 5 and app.deck.turn_active,
			"M01 opens at three energy and five cards")
		var cards: Array[String] = app._load_starter_deck()
		var rng := RandomNumberGenerator.new()
		rng.seed = fixture_seed
		var map := RunMap.new()
		_check(map.generate(rng), "combat reference generates")
		var reference_deck := CombatDeck.new(cards, rng)
		_check(reference_deck.start_turn() and map.choose_node(fight_id), "reference starts and commits")
		_check(app.deck.hand == reference_deck.hand and app.deck.draw_pile == reference_deck.draw_pile
			and app.run_rng.state == rng.state and app.run_map.get_floors() == map.get_floors(),
			"map then hand use one uninterrupted seeded stream")
		_check(app.hand_view.get_child_count() == 5 and app.end_turn_button.has_focus(), "real hand mounted and battle focused")
		for index in range(app.deck.hand.size()):
			_check(app.hand_view.get_child(index).get_child(0).text == app.deck.hand[index], "mounted card matches real hand")
		if session == 0:
			trace = _snapshot(app)
		else:
			_check(_snapshot(app) == trace, "two runs replay complete graph/route/hand/actors/RNG")
		_reject(app, fight_id, "duplicate battle choice")
		_reject(app, "unknown", "unknown during combat")
		_reject(app, app.run_map.get_legal_choices()[0], "next floor during combat")
		var before := _snapshot(app)
		app._start_run()
		app._open_route()
		app._cancel_route()
		_check(_snapshot(app) == before, "other starts and stale Back preserve battle")
		same_rng = null
		same_map = null
		old_map = weakref(app.run_map)
		old_rng = weakref(app.run_rng)
		if session == 0:
			await _click(app.return_button)
		else:
			app.return_button.grab_focus()
			await _key(KEY_ENTER)
		await process_frame
		_check(app.deck == null and app.run_rng == null and app.run_map == null and app.battle_view == null,
			"Return clears route and battle")
		_check(old_map.get_ref() == null and old_rng.get_ref() == null, "Return releases map/RNG")
		_check(app.start_button.has_focus(), "Return restores original title focus")

	await _click(app.route_button)
	_check(app.run_map != null and app.route_view != null, "failed-data retry chooser mounted")
	if app.run_map != null:
		for field in ["starter_deck_path", "starter_party_path", "starter_attacks_path", "starter_enemies_path"]:
			var original: String = app.get(field)
			app.set(field, OS.get_environment("TEMP").path_join("patchwork_missing_029.json"))
			_reject(app, fight_id, "bad starter data: " + field)
			app.set(field, original)
		# Valid CombatParty input that violates the current round-flow owner contract.
		var definitions: Array = JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_PARTY_PATH))
		definitions[1].id = "wrong_owner"
		var path := OS.get_environment("TEMP").path_join("patchwork_route_029_party.json")
		var file := FileAccess.open(path, FileAccess.WRITE)
		_check(file != null, "external invalid-contract fixture writable")
		if file != null:
			file.store_string(JSON.stringify(definitions))
			file.close()
			app.starter_party_path = path
			_reject(app, fight_id, "valid party with invalid round-flow binding")
			app.starter_party_path = app.STARTER_PARTY_PATH
			DirAccess.remove_absolute(path)
		var before_retry := _snapshot(app)
		var retry_button: Button = null
		for button in app.route_buttons:
			if button.get_meta("route_id") == fight_id:
				retry_button = button
		_check(retry_button != null, "failed starter attempts retain the mounted Fight")
		if retry_button != null:
			await _click(retry_button)
			_check(app.deck != null and app.run_map.get_route() == [fight_id], "corrected data retries successfully via mouse")
			if app.deck != null:
				_check(app.run_map.get_floors() == before_retry[0], "retry retains generated graph")
				await _click(app.return_button)
	# The formerly blocked opening now offers Fight; Back still cancels it.
	app.run_seed = fixture_seed
	await _click(app.route_button)
	_check(app.run_map != null and app.route_buttons.size() == 3,
		"formerly blocked seed has its actual opening mounted")
	if app.run_map != null and app.route_buttons.size() == 3:
		_check(app.route_buttons[0].get_meta("route_id") == fight_id
			and not app.route_buttons[0].disabled and app.route_buttons[0].has_focus(),
			"fallback Fight enabled and initially focused")
		for index in [1, 2]:
			_check(app.route_buttons[index].disabled, "other opening types remain unavailable")
		_check(app.run_map.get_floors()[0][1].type == "Rest"
			and app.run_map.get_floors()[0][2].type == "Treasure",
			"fallback preserves unsupported kinds")
		await _key(KEY_TAB)
		_check(app.route_back_button.has_focus(), "Tab skips disabled choices to Back")
		await _click(app.route_back_button)
		_check(app.run_map == null and app.run_rng == null and app.deck == null,
			"formerly blocked seed Back clears session")
	app.run_seed = fixture_seed
	await _click(app.start_button)
	_check(app.deck != null and app.run_map == null and app.route_view == null, "original direct start preserved")
	if app.deck != null:
		var rng := RandomNumberGenerator.new()
		rng.seed = fixture_seed
		var direct := CombatDeck.new(app._load_starter_deck(), rng)
		_check(direct.start_turn(), "direct reference starts")
		_check(app.deck.hand == direct.hand and app.run_rng.state == rng.state, "direct start retains original seeded hand")
		await _click(app.return_button)
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_run_map_entry_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
