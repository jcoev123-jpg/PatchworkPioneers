extends SceneTree
## No live-model fixtures: the complete fight is won through viewport input.
## Expectations use manual pile/HP arithmetic, not the production play/round services.

const FIXED_SEED := 42
var failures: Array[String] = []
var checks := 0
var app
var presenter
var catalog := StarterCards.new()
var expected: Dictionary
var oracle_rng := RandomNumberGenerator.new()
var original: Array = []
var schedule: Array = []
var reshuffles := 0
var hero_absorbed := false
var hero_hp_hit := false
var enemy_absorbed := false
var mouse_plays := 0
var keyboard_plays := 0
var slain_rejections := 0


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


func _click(control: Control) -> void:
	_check(is_instance_valid(control), "physical click requires an existing control")
	if not is_instance_valid(control):
		return
	_check(control.is_visible_in_tree() and control.size.x > 0 and control.size.y > 0
		and Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()), "clicked control is visible inside 1280x720")
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	root.push_input(motion, true)
	await _frames()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _state() -> Dictionary:
	return {"hand": app.deck.hand.duplicate(), "draw": app.deck.draw_pile.duplicate(),
		"discard": app.deck.discard_pile.duplicate(), "energy": app.deck.energy,
		"active": app.deck.turn_active, "heroes": app.party.get_heroes(),
		"enemies": app.enemies.get_enemies(), "intents": app.enemy_intents.get_intents(),
		"attacks": app.enemy_attacks.duplicate(true), "turn": app.enemy_intents._turn_index,
		"seed": app.run_rng.seed, "rng": app.run_rng.state,
		"outcome": app.battle_result.get_outcome(), "gold": app.session_gold,
		"claimed": app.victory_gold.is_claimed()}


func _boundary(label: String) -> void:
	expected.rng = oracle_rng.state
	_check(_state() == expected, "exact authoritative state: " + label + "\nactual: " + str(_state()) + "\nexpected: " + str(expected))
	var cards: Array = app.deck.hand + app.deck.draw_pile + app.deck.discard_pile
	cards.sort()
	_check(cards == original, "all original card copies conserved: " + label)
	_check(app.hand_view.get_child_count() == app.deck.hand.size(), "mounted hand count: " + label)
	for index in range(app.deck.hand.size()):
		_check(app.hand_view.get_child(index).get_child(0).text == app.deck.hand[index], "mounted card order: " + label)
	_check(app.pile_label.text.contains("Draw: %d" % app.deck.draw_pile.size())
		and app.pile_label.text.contains("Discard: %d" % app.deck.discard_pile.size()), "visible pile counts: " + label)
	_check(app.get_node("LiveSupportHand").energy_label.text.begins_with("Energy: %d |" % app.deck.energy), "visible energy: " + label)


func _shuffle() -> void:
	for index in range(expected.draw.size() - 1, 0, -1):
		var other := oracle_rng.randi_range(0, index)
		var card = expected.draw[index]
		expected.draw[index] = expected.draw[other]
		expected.draw[other] = card


func _draw() -> void:
	for count in range(5):
		if expected.draw.is_empty():
			expected.draw = expected.discard.duplicate()
			expected.discard.clear()
			_shuffle()
			reshuffles += 1
		expected.hand.append(expected.draw.pop_back())


func _intents(turn: int) -> Array:
	var result: Array = []
	for entry in schedule:
		var intent: Dictionary = entry.pattern[turn % entry.pattern.size()].duplicate(true)
		intent.enemy_position = int(entry.enemy_position)
		intent.amount = int(intent.amount)
		if intent.has("target_position"):
			intent.target_position = int(intent.target_position)
		result.append(intent)
	return result


func _opening() -> void:
	oracle_rng.seed = FIXED_SEED
	expected = {"hand": [], "draw": JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)),
		"discard": [], "energy": 3, "active": true,
		"heroes": CombatParty.new(app._load_party_definitions()).get_heroes(),
		"enemies": CombatEnemies.new(app._load_enemy_definitions()).get_enemies(),
		"intents": _intents(0), "attacks": _intents(0), "turn": 0,
		"seed": FIXED_SEED, "rng": 0, "outcome": CombatBattleResult.ACTIVE,
		"gold": 0, "claimed": false}
	expected.heroes[0].block = 6
	_shuffle()
	_draw()


func _expected_end() -> void:
	expected.discard.append_array(expected.hand)
	expected.hand.clear()
	for intent in expected.intents:
		if expected.enemies[intent.enemy_position - 1].hp == 0:
			continue
		if intent.type == "block":
			expected.enemies[intent.enemy_position - 1].block += intent.amount
		else:
			var hero: Dictionary = expected.heroes[intent.target_position - 1]
			var absorbed := mini(hero.block, intent.amount)
			hero.block -= absorbed
			hero.hp -= intent.amount - absorbed
			hero_absorbed = hero_absorbed or absorbed > 0
			hero_hp_hit = hero_hp_hit or intent.amount > absorbed
	for hero in expected.heroes:
		hero.block = 0
	expected.turn += 1
	expected.intents = _intents(expected.turn)
	expected.attacks = expected.intents.duplicate(true)
	expected.energy = 3
	_draw()


func _expected_attack(id: String, position: int) -> void:
	var definition := catalog.get_definition(id)
	var damage: int = definition.effects.damage + (3 if definition.owner == "tinker" else 0)
	var enemy: Dictionary = expected.enemies[position - 1]
	var absorbed := mini(enemy.block, damage)
	enemy.block -= absorbed
	enemy.hp = maxi(0, enemy.hp - (damage - absorbed))
	enemy_absorbed = enemy_absorbed or absorbed > 0
	expected.energy -= definition.cost
	expected.hand.erase(id)
	expected.discard.append(id)
	if expected.enemies[0].hp == 0 and expected.enemies[1].hp == 0:
		expected.outcome = CombatBattleResult.VICTORY
		expected.gold = oracle_rng.randi_range(10, 20)
		expected.claimed = true
		expected.discard.append_array(expected.hand)
		expected.hand.clear()
		expected.energy = 0
		expected.active = false


func _choose(id: String, keyboard: bool) -> bool:
	if keyboard:
		for attempt in range(6):
			await _key(KEY_P)
			if presenter._card_id(presenter._armed) == id:
				break
	else:
		for panel in app.hand_view.get_children():
			if panel.get_child(0).text == id:
				await _click(panel)
				break
	var armed: bool = presenter._card_id(presenter._armed) == id
	_check(armed, "physical held-card selection arms " + id)
	return armed


func _fight() -> Array:
	seed(915033)
	var global_next := randi()
	seed(915033)
	app.run_seed = FIXED_SEED
	app.start_button.grab_focus()
	await _key(KEY_ENTER)
	var ready: bool = app.deck != null and app.party != null and app.enemies != null and app.round_flow != null and app.victory_gold != null
	_check(ready, "keyboard Start creates complete live fight")
	if not ready:
		return []
	_check(app.enemies.get_enemies().size() == 2 and app.enemies.get_enemy(1).hp == 12
		and app.enemies.get_enemy(2).hp == 12, "both authored enemies alive at full HP")
	_check(app.round_flow._deck == app.deck and app.round_flow._party == app.party
		and app.round_flow._enemies == app.enemies and app.battle_result._enemies == app.enemies,
		"mounted coordinator and result own actual combat models")
	_opening()
	_boundary("opening")
	var trace: Array = [_state()]
	# One held single-target attack per turn, with an opening pass: this naturally
	# exercises enemy attacks, accumulated guard Block and real seeded reshuffles.
	for turn in range(20):
		if turn > 0:
			var id := ""
			var position := 0
			for held in expected.hand:
				var definition := catalog.get_definition(held)
				if definition.get("target_kind") != "enemy_single":
					continue
				for target in [2, 1]:
					if target in definition.to_positions and expected.enemies[target - 1].hp > 0:
						id = held
						position = target
						break
				if not id.is_empty():
					break
			if not id.is_empty():
				var keyboard := turn % 2 == 0
				if not await _choose(id, keyboard):
					return trace
				var before := _state()
				await _key(KEY_3)
				_check(_state() == before, "armed held attack rejects absent slot without spend")
				for slain in [1, 2]:
					if expected.enemies[slain - 1].hp == 0 and slain in catalog.get_definition(id).to_positions:
						await _key(KEY_1 if slain == 1 else KEY_2)
						_check(_state() == before, "slain original slot rejects an otherwise legal held selection without spend")
						slain_rejections += 1
				var old_panel: Control = presenter._armed
				var stale: Callable = presenter._bindings[old_panel].input
				_expected_attack(id, position)
				var definition := catalog.get_definition(id)
				var damage: int = definition.effects.damage + (3 if definition.owner == "tinker" else 0)
				var absorbed := mini(before.enemies[position - 1].block, damage)
				var statuses := {}
				for status in ["weak", "bleed"]:
					if definition.effects.has(status):
						statuses[status] = definition.effects[status]
				if id == "seamstress_prick":
					statuses.bleed += 1
				if keyboard:
					await _key(KEY_1 if position == 1 else KEY_2)
					keyboard_plays += 1
				else:
					await _click(app.get_node("LiveEnemyRoster")._labels[position - 1])
					mouse_plays += 1
				_boundary("play %s at turn %d" % [id, turn])
				_check(presenter.last_event == {"ok": true, "hits": [{"position": position,
					"damage": damage, "block_absorbed": absorbed,
					"hp_loss": before.enemies[position - 1].hp - expected.enemies[position - 1].hp,
					"statuses": statuses}]}, "live attack committed exact authored hit and passive event")
				trace.append(_state())
				# The old panel callback is genuinely captured before the hand rebuild.
				# Even if another copy is held, it cannot arm or charge that copy.
				var after := _state()
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = true
				stale.call(click)
				await _key(KEY_1 if position == 1 else KEY_2)
				_check(_state() == after, "stale consumed-card callback and target spend nothing")
				if expected.outcome == CombatBattleResult.VICTORY:
					break
		_check(not app.end_turn_button.disabled and app.end_turn_button.is_visible_in_tree(), "active End Turn reachable")
		_expected_end()
		await _click(app.end_turn_button)
		_boundary("End Turn %d" % turn)
		trace.append(_state())
	_check(app.enemies.is_victorious() and app.battle_result.get_outcome() == CombatBattleResult.VICTORY
		and app.round_flow.get_outcome() == CombatBattleResult.VICTORY, "bounded legal plays win both enemies")
	_check(app.result_label.is_visible_in_tree()
		and app.result_label.text == "Battle result: VICTORY | Gold: %d" % expected.gold,
		"visible victory agrees with authoritative result and exact gold")
	_check(app.end_turn_button.disabled and app.deck.hand.is_empty() and not app.deck.turn_active
		and app.intent_label.text == "Intent: none", "terminal controls, hand and intents closed")
	_check(app.return_button.is_visible_in_tree() and not app.return_button.disabled
		and Rect2(0, 0, 1280, 720).encloses(app.result_label.get_global_rect()), "terminal result and Return reachable")
	var terminal := _state()
	for repeat in range(3):
		await _click(app.end_turn_button)
		await _key(KEY_P)
		await _key(KEY_1)
		await _key(KEY_2)
		await _click(app.get_node("LiveEnemyRoster")._labels[1])
		# Also deliver a retained disabled-button signal to exercise its guard.
		app.end_turn_button.pressed.emit()
		await _frames()
		_check(_state() == terminal, "terminal card/End Turn inputs preserve all models, gold, intents and RNG")
	await _click(app.return_button)
	_check(app.deck == null and app.party == null and app.enemies == null and app.run_rng == null
		and app.victory_gold == null and app.round_flow == null and app.battle_result == null
		and presenter._bindings.is_empty() and presenter.cue == null
		and app.title_view.is_visible_in_tree() and app.start_button.has_focus(), "Return releases fight and input bindings")
	_check(randi() == global_next, "complete fight, rejected inputs, terminal controls and Return preserve global RNG")
	return trace


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	original = JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH))
	original.sort()
	schedule = JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_ATTACKS_PATH))
	var first := await _fight()
	var replay := await _fight()
	_check(first.size() > 5 and replay == first, "Return/restart reproduces every same-seed action boundary exactly")
	_check(reshuffles >= 2 and hero_absorbed and hero_hp_hit and enemy_absorbed
		and mouse_plays > 0 and keyboard_plays > 0 and slain_rejections > 0,
		"non-vacuous reshuffle, hero Block/HP, guard Block, mouse, keyboard and slain-slot rejection coverage")
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_legal_starter_fight_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
