extends SceneTree

const SEED := 45045
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


func _deck_state(deck: CombatDeck) -> Array:
	return [deck.draw_pile.duplicate(), deck.hand.duplicate(), deck.discard_pile.duplicate(),
		deck.energy, deck.turn_active, deck.combat_state.energy,
		deck.combat_state.player_turn_active, deck._rng.state]


func _state() -> Array:
	return [app.party.get_heroes(), app.enemies.get_enemies(), _deck_state(app.deck),
		app.enemy_intents.get_intents(), app.enemy_attacks.duplicate(true),
		app.enemy_intents._turn_index, app.battle_result.get_outcome(),
		app.session_gold, app.victory_gold.is_claimed()]


func _announced(target: int) -> void:
	var expected := [
		{"enemy_position": 1, "type": "attack", "amount": 1, "target_position": target},
		{"enemy_position": 2, "type": "block", "amount": 1}]
	_check(app.enemy_attacks == expected and app.enemy_intents.get_intents() == expected,
		"current authored announcement targets slot %d" % target)
	_check(app.intent_label.is_visible_in_tree() and app.intent_label.text ==
		"Intent: Enemy 1 -> Hero %d (%s): 1 damage; Enemy 2: 1 Block" %
		[target, ["Warden", "Seamstress", "Tinker"][target - 1]],
		"visible announcement includes exact target and unchanged amounts")


func _party_visible() -> void:
	_check(app.hero_panels.size() == 3, "three mounted hero panels")
	for index in range(app.hero_panels.size()):
		var label := app.hero_panels[index].get_child(0) as Label
		var hero: Dictionary = app.party.get_hero(index + 1)
		_check(label != null and label.is_visible_in_tree() and label.text.contains(
			"HP: %d/%d | Block: %d" % [hero.hp, hero.max_hp, hero.block]),
			"live hero HP/Block match authoritative state")


func _session() -> Array:
	_check(app.title_view.is_visible_in_tree() and not app.start_button.disabled,
		"real title Start is reachable")
	app.start_button.grab_focus()
	await _key(KEY_ENTER)
	var bound: bool = app.deck != null and app.party != null and app.enemies != null \
		and app.round_flow != null and app.battle_result != null and app.run_rng != null
	_check(bound, "title activation constructs real battle services")
	if not bound:
		return []
	_check(app.round_flow._party == app.party and app.round_flow._enemies == app.enemies
		and app.round_flow._deck == app.deck and app.round_flow._intents == app.enemy_intents
		and app.round_flow._result == app.battle_result and app.deck._rng == app.run_rng,
		"mounted battle binds actual authoritative models and shared RNG")
	_check(app.party.get_hero(1).id == "warden" and app.party.get_hero(1).hp == 40
		and app.party.get_hero(1).block == 6 and app.party.get_hero(2).id == "seamstress"
		and app.party.get_hero(2).hp == 30 and app.party.get_hero(2).block == 0
		and app.party.get_hero(3).id == "tinker" and app.party.get_hero(3).hp == 26
		and app.party.get_hero(3).block == 0, "authored heroes and opening Block unchanged")
	_check(app.enemies.get_enemy(1).id == "ragling" and app.enemies.get_enemy(1).hp == 12
		and app.enemies.get_enemy(2).id == "ragling_guard" and app.enemies.get_enemy(2).hp == 12,
		"real starter enemies remain alive at authored HP")
	var cards: Array[String] = []
	cards.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var oracle := CombatDeck.new(cards, rng)
	_check(oracle.start_turn() and _deck_state(app.deck) == _deck_state(oracle),
		"opening exact hand, piles, energy and RNG match independently seeded deck")
	var trace: Array = [_state()]
	var turns := 0
	while app.battle_result.can_continue() and turns < 160:
		var target := turns % 3 + 1
		_announced(target)
		_party_visible()
		_check(app.enemy_intents._turn_index == turns and app.deck.energy == 3
			and app.deck.hand.size() == 5 and app.deck.turn_active
			and not app.end_turn_button.disabled and app.end_turn_button.is_visible_in_tree(),
			"legal End Turn has full energy/hand and correct turn index")
		var before := _state()
		var heroes: Array = before[0].duplicate(true)
		var victim: Dictionary = heroes[target - 1]
		if victim.hp > 0:
			var absorbed := mini(victim.block, 1)
			victim.block -= absorbed
			victim.hp = maxi(0, victim.hp - (1 - absorbed))
		var defeated := true
		for hero in heroes:
			defeated = defeated and hero.hp == 0
		if not defeated:
			for hero in heroes:
				hero.block = 0
		var enemies: Array = before[1].duplicate(true)
		enemies[1].block += 1
		_check(oracle.end_turn(), "oracle discards exactly the current unplayed hand")
		if not defeated:
			_check(oracle.start_turn(), "oracle draws only for a surviving party")
		app.end_turn_button.grab_focus()
		await _key(KEY_SPACE)
		turns += 1
		_check(app.party.get_heroes() == heroes and app.enemies.get_enemies() == enemies,
			"turn %d exact HP/Block; only announced target and Guard change" % turns)
		_check(_deck_state(app.deck) == _deck_state(oracle),
			"turn %d exact hand/discard/draw, energy and RNG, including terminal no-draw" % turns)
		_check(app.enemy_intents._turn_index == (turns - 1 if defeated else turns),
			"advance announcements only for an active battle")
		if defeated:
			_check(app.enemy_attacks == before[4] and app.enemy_intents.get_intents() == before[3]
				and app.run_rng.state == before[2][7], "terminal phase freezes announcement and RNG")
		trace.append(_state())
	_check(turns == 121 and app.party.is_defeated()
		and app.battle_result.get_outcome() == CombatBattleResult.DEFEAT,
		"unmodified authored battle defeats all three heroes on End Turn 121")
	_party_visible()
	_check(app.result_label.is_visible_in_tree() and app.result_label.text == "Battle result: DEFEAT"
		and app.end_turn_button.disabled and not app.deck.turn_active
		and app.deck.hand.is_empty() and app.hand_view.get_child_count() == 0
		and app.session_gold == 0 and not app.victory_gold.is_claimed(),
		"mounted DEFEAT closes all plays, clears hand and grants no victory gold")
	var closed := _state()
	root.gui_release_focus()
	await _key(KEY_SPACE)
	app.end_turn_button.pressed.emit()
	_check(not app.round_flow.end_turn() and not app.deck.try_spend_energy(0)
		and not app.deck.discard_played(cards[0]) and app.deck.draw_extra(1) == -1,
		"terminal End Turn, zero-spend, card discard and draw reject")
	await _frames()
	_check(_state() == closed, "terminal inputs preserve actors, deck, intents, energy and RNG")
	var old_battle: WeakRef = weakref(app.battle_view)
	var old_flow: WeakRef = weakref(app.round_flow)
	var old_result: WeakRef = weakref(app.battle_result)
	_check(app.return_button.is_visible_in_tree() and not app.return_button.disabled,
		"Return is reachable after natural defeat")
	app.return_button.grab_focus()
	await _key(KEY_ENTER)
	_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus()
		and app.deck == null and app.party == null and app.enemies == null
		and app.round_flow == null and app.battle_result == null and app.run_rng == null
		and app.enemy_intents == null and app.enemy_attacks.is_empty()
		and app.battle_view == null and app.result_label == null and app.victory_gold == null
		and app.session_gold == 0 and old_battle.get_ref() == null
		and old_flow.get_ref() == null and old_result.get_ref() == null,
		"Return frees battle and services and restores fresh title")
	return trace


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real app scene loads")
	if scene != null:
		app = scene.instantiate()
		root.add_child(app)
		await _frames()
		app.run_seed = SEED
		_check(app.starter_attacks_path == "res://data/encounters/starter_attacks.json"
			and app.starter_party_path == app.STARTER_PARTY_PATH
			and app.starter_enemies_path == app.STARTER_ENEMIES_PATH
			and app.starter_deck_path == app.STARTER_DECK_PATH, "all shipped data paths used")
		var first := await _session()
		var second := await _session()
		_check(first.size() == 122 and second.size() == 122 and first == second,
			"same seed after Return reproduces complete 121-turn party/enemy/deck/energy/RNG trace")
		app.free()
	if failures.is_empty():
		print("live_authored_starter_defeat_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("live_authored_starter_defeat_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
