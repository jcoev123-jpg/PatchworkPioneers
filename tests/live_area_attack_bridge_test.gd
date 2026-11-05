extends SceneTree
## Mounted input reaches the real area operation; expectations use manual arithmetic.

class ObservedArea extends CombatAreaAttacks:
	var calls := 0
	var observed: Array = []

	func resolve(enemies: CombatEnemies, base_damage: int, attacker: Dictionary = {},
			defenders: Dictionary = {}) -> Dictionary:
		calls += 1
		observed = [enemies, base_damage, attacker.duplicate(true), defenders.duplicate(true)]
		return super.resolve(enemies, base_damage, attacker, defenders)

const ID := "tinker_scrap_bomb"
var failures: Array[String] = []
var checks := 0
var app


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
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


func _click(panel: Control) -> void:
	_check(panel.is_visible_in_tree() and Rect2(0, 0, 1280, 720).encloses(panel.get_global_rect()),
		"real mouse control is visible inside viewport")
	var motion := InputEventMouseMotion.new()
	motion.position = panel.get_global_rect().get_center()
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = motion.position
		root.push_input(event, true)
	await _frames()


func _state() -> Dictionary:
	return {"draw": app.deck.draw_pile.duplicate(), "hand": app.deck.hand.duplicate(),
		"discard": app.deck.discard_pile.duplicate(), "energy": app.deck.energy,
		"state_energy": app.deck.combat_state.energy, "active": app.deck.turn_active,
		"heroes": app.party.get_heroes(), "enemies": app.enemies.get_enemies(),
		"rng": app.run_rng.state, "seed": app.run_rng.seed,
		"intents": app.enemy_intents.get_intents(), "attacks": app.enemy_attacks.duplicate(true),
		"turn": app.enemy_intents._turn_index, "gold": app.session_gold,
		"outcome": app.battle_result.get_outcome()}


func _panel():
	for panel in app.hand_view.get_children():
		if panel.get_child(0) is Label and panel.get_child(0).text == ID:
			return panel
	return null


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real app scene loads")
	if scene == null:
		_finish()
		return
	app = scene.instantiate()
	root.add_child(app)
	await _frames()
	var cards: Array[String] = []
	cards.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
	var chosen := -1
	for candidate in range(100):
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		var deck := CombatDeck.new(cards, rng)
		if deck.start_turn() and ID in deck.hand:
			chosen = candidate
			break
	_check(chosen >= 0, "authored seeded opening holds Bomb")
	if chosen < 0:
		app.free()
		_finish()
		return
	app.run_seed = chosen
	var replay: Dictionary = {}
	for mode in ["mouse", "enter", "space"]:
		_fixture_start(app)
		await _frames()
		var panel = _panel()
		_check(panel != null and app.deck.energy == 3 and app.deck.turn_active
			and app.enemies.get_enemies().size() == 2, "real battle has held Bomb and live recipients")
		if panel == null:
			break
		var presenter = app.get_node("LiveAttackPreview")
		var area := ObservedArea.new()
		# Observe by forwarding to the production operation on actual bound models.
		presenter._play._area = area
		app.party._heroes[2]["statuses"] = {"weak": 1}
		_check(app.enemies.apply_statuses({1: {"exposed": 1}})
			and app.enemies.gain_block(1, 2), "real status and Block fixture")
		var callback: Callable = presenter._bindings[panel].input
		var expected := _state().duplicate(true)
		expected.energy -= 2
		expected.state_energy -= 2
		expected.hand.erase(ID)
		expected.discard.append(ID)
		expected.enemies[0].block = 0
		expected.enemies[0].hp -= 5 # floor(7 * 3/4 * 3/2) = 7, minus 2 Block.
		expected.enemies[1].hp -= 5 # floor(7 * 3/4) = 5.
		if mode == "mouse":
			await _click(panel)
		else:
			for attempt in range(CombatAttackTargeting.ATTACK_IDS.size() + 1):
				await _key(KEY_P)
				if presenter._armed == panel:
					break
			_check(presenter._armed == panel, "existing P hand control selects Bomb")
			await _key(KEY_ENTER if mode == "enter" else KEY_SPACE)
		_check(_state() == expected, "mounted " + mode + " exact authoritative transition")
		_check(area.calls == 1 and area.observed == [app.enemies, 7, {"weak": 1},
			{1: {"exposed": 1}, 2: {}}], "live route uses area service once with real roster and statuses")
		var event := {"ok": true, "hits": [
			{"position": 1, "damage": 7, "block_absorbed": 2, "hp_loss": 5, "statuses": {}},
			{"position": 2, "damage": 5, "block_absorbed": 0, "hp_loss": 5, "statuses": {}}]}
		_check(presenter.last_event == event and presenter._play._tinker._consumed,
			"exact ordered events and once-per-turn latch")
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		callback.call(press)
		# Repeated attack keys with no focused competing button. Focused button
		# activation is covered separately by live_area_attack_action_test.
		var focused := root.gui_get_focus_owner()
		if focused != null:
			focused.release_focus()
		await _key(KEY_ENTER)
		await _key(KEY_SPACE)
		_check(_state() == expected and presenter.last_event == event and area.calls == 1,
			"stale callback and repeated keys preserve all state and avoid another area call")
		if replay.is_empty():
			replay = _state()
		else:
			_check(_state() == replay, "same seed mouse and keyboard replay agree")
		app.return_button.pressed.emit()
		await _frames()
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_area_attack_bridge_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


## Standalone M01 admission; seeded title input is covered by live_seeded_opening_route_test.
func _fixture_start(target) -> void:
	if target.deck != null:
		target.start_run_requested.emit()
		return
	var started: bool = target._start_battle()
	_check(started == (target.deck != null), "standalone fixture reports admission consistently")
