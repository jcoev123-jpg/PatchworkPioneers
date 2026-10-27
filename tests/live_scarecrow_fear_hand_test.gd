extends "res://tests/live_support_hand_test.gd"

const FEAR := CombatScarecrowFearCards.CARDS
const FEAR_KEY := CombatScarecrowFearCards.FEAR_STATUS_KEY


## A real mounted battle whose Scarecrow holds two copies of `id`. Enemies one and two announce a
## self-Block buff and enemy three a plain Block, so a genuine End Turn harms no hero.
func _begin(id: String, seat: int = 2, mode: String = "plain") -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 321
	_check(app._start_battle(), "real mounted battle starts")
	presenter = app.get_node("LiveSupportHand")
	var rng := RandomNumberGenerator.new()
	rng.seed = 321
	app.deck = CombatDeck.new([id, id, "warden_strike", "warden_brace", "tinker_tune_up"], rng)
	app.run_rng = rng
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 25}]
	heroes.insert(seat - 1, {"id": "scarecrow", "name": "Scarecrow", "max_hp": 30})
	app.party = CombatParty.new(heroes)
	var status := {"weak": 1, FEAR_KEY: true} if mode == "marked" else {}
	app.enemies = CombatEnemies.new([
		{"id": "first", "name": "First", "max_hp": 40, "statuses": status},
		{"id": "second", "name": "Second", "max_hp": 40},
		{"id": "third", "name": "Third", "max_hp": 40}])
	_check(app.party.is_valid() and app.enemies.is_valid(), "three authentic seats and valid enemy roster")
	_check(app.enemies.gain_block(1, 2), "first target begins with Block")
	app.enemy_intents = CombatEnemyIntents.new([
		{"enemy_position": 1, "pattern": [{"type": "buff", "amount": 3}]},
		{"enemy_position": 2, "pattern": [{"type": "buff", "amount": 3}]},
		{"enemy_position": 3, "pattern": [{"type": "block", "amount": 1}]}])
	_check(app.enemy_intents.is_valid(), "announced self-Block buff schedule is valid")
	app.enemy_attacks = app.enemy_intents.get_intents()
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies, app.enemy_intents, app.battle_result)
	_check(app.round_flow.begin_fight() and app.deck.hand.count(id) == 2 and app.deck.energy == 3,
		"the real round flow opens the fight: five cards drawn at three energy")
	app.deck.combat_state.energy = 1
	app._refresh_intents()
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_hand()
	await _frames()
	var panel := _panel(id)
	_check(panel != null and panel.is_visible_in_tree() and presenter._bindings.has(panel),
		"real illustrated hand binds the exact held card")
	return panel


func _authored(id: String) -> Dictionary:
	return CombatScarecrowFearCards.new()._catalog_definition(id, FEAR[id].catalog)


func _model_state() -> Array:
	return [_snapshot(app.deck, app.party, app.run_rng), app.enemies.get_enemies(),
		app.enemy_intents.get_intents(), app.battle_result.get_outcome(), app._battle_closed]


func _dispose() -> void:
	app.free()
	await _frames()


func _arm(panel: Control, keyboard: bool) -> void:
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(panel)


func _target_panel(position: int) -> Control:
	return app.get_node("LiveEnemyRoster")._labels[position - 1]


func _select(panel: Control, keyboard: bool) -> void:
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_SPACE)
	else:
		await _mouse(panel)


func _status_caption(position: int) -> String:
	var tag = app.get_node("LiveEnemyRoster")._status_tags[position - 1]
	return (tag.get_node("Caption") as Label).text.to_lower() if tag.visible else ""


## One genuine cast through the real hand and enemy picker; returns false when it did not commit.
func _cast(id: String, keyboard: bool, target: int) -> bool:
	var panel := _panel(id)
	if panel == null:
		return false
	await _arm(panel, keyboard)
	if not presenter._targets.has(_target_panel(target)):
		return false
	await _select(_target_panel(target), keyboard)
	return presenter._pending.is_empty()


func _success(id: String, keyboard: bool, seat: int, target: int, mode: String = "plain") -> void:
	var panel := await _begin(id, seat, mode)
	if panel == null:
		await _dispose()
		return
	var definition := _authored(id)
	var weak: int = int(FEAR[id].weak)
	_check(not definition.is_empty() and definition.id == id and definition.owner == "scarecrow"
		and definition.cost == 1 and definition.effects == {"weak": weak, FEAR_KEY: true},
		"authentic canonical Scarecrow record prints Weak %d and Fear" % weak)
	_check(presenter._eligible(panel, id, app.deck, app.party, app.battle_view)
		and panel.gui_input.get_connections().size() == 1 and panel.focus_mode == Control.FOCUS_ALL,
		"exactly one enabled real mouse/keyboard card binding")
	var before := _model_state()
	var old_source: Callable = presenter._bindings[panel]
	await _arm(panel, keyboard)
	var targets = presenter._targets
	_check(_model_state() == before and presenter._pending.get("choosing", false) and targets.size() == 3
		and targets.has(_target_panel(target)),
		"arm offers every living legal enemy slot with no payment")
	_check(presenter.help_label.text.begins_with("%s: choose a living enemy (1-3)" % definition.display_name),
		"target prompt names the authored card even without generic metadata")
	if not targets.has(_target_panel(target)):
		await _dispose()
		return
	var target_panel := _target_panel(target)
	var old_target: Callable = targets[target_panel].callback
	_check(targets[target_panel].has("actor_ref")
		and is_same(targets[target_panel].actor_ref, app.enemies._enemies[target - 1]),
		"real enemy choice widget binds current actor identity")
	var previous: Dictionary = app.enemies.get_enemy(target)
	var others: Array = app.enemies.get_enemies()
	var prior_party: Array = app.party.get_heroes()
	var prior_rng: int = app.run_rng.state
	var prior_draw: Array[String] = app.deck.draw_pile.duplicate()
	var prior_hand: Array[String] = app.deck.hand.duplicate()
	var prior_discard: Array[String] = app.deck.discard_pile.duplicate()
	var prior_intents = app.enemy_intents.get_intents()
	await _select(target_panel, keyboard)
	var after: Dictionary = app.enemies.get_enemy(target)
	var statuses: Dictionary = after.get("statuses", {})
	_check(after.hp == previous.hp and after.block == previous.block
		and statuses.get("weak", 0) == previous.get("statuses", {}).get("weak", 0) + weak
		and statuses.get(FEAR_KEY, false) == true,
		"printed Weak and canonical Fear land with no HP or Block damage")
	for index in range(3):
		if index != target - 1:
			_check(app.enemies.get_enemy(index + 1) == others[index], "other enemy state unchanged")
	_check(app.party.get_heroes() == prior_party and app.run_rng.state == prior_rng
		and app.enemy_intents.get_intents() == prior_intents and app.battle_result.get_outcome() == CombatBattleResult.ACTIVE,
		"party, intents, battle result and RNG remain unchanged")
	_check(app.deck.energy == 0 and app.deck.hand.count(id) == 1
		and app.deck.hand.size() == prior_hand.size() - 1
		and app.deck.discard_pile == prior_discard + [id]
		and app.deck.draw_pile == prior_draw,
		"single one-energy payment, exactly one discarded copy and no extra draws")
	_check(presenter._pending.is_empty() and presenter._targets.is_empty()
		and presenter.energy_label.text == "0"
		and app.hand_view.get_child_count() == app.deck.hand.size()
		and app.pile_label.text == "Draw: %d | Discard: %d" % [app.deck.draw_pile.size(), app.deck.discard_pile.size()],
		"one-shot target closes and real hand/piles/energy HUD refresh")
	_check(_status_caption(target).contains("weak"), "mounted enemy status plaque refreshes to Weak")
	app.deck.combat_state.energy = 1
	before = _model_state()
	old_source.call(_press())
	old_target.call(_press())
	await _frames()
	_check(_model_state() == before and presenter._pending.is_empty(), "retired callbacks never replay another affordable copy")
	var remaining := _panel(id)
	_check(remaining != null and presenter._eligible(remaining, id, app.deck, app.party, app.battle_view),
		"remaining held copy can be played with replenished energy")
	await _dispose()


## AC2: a real accepted End Turn suppresses the Fear-marked enemy's announced self-Block buff once,
## while the unmarked buff source still gains its Block; Fear expires and Weak ages on its own.
func _end_turn(id: String, keyboard: bool) -> void:
	var panel := await _begin(id, 2)
	if panel == null:
		await _dispose()
		return
	var weak: int = int(FEAR[id].weak)
	_check(app.enemy_attacks[0].type == "buff" and app.enemy_attacks[1].type == "buff",
		"enemies one and two announce a self-Block buff")
	_check(await _cast(id, keyboard, 1), "Fear cast commits on the announced buff source")
	var marked: Dictionary = app.enemies.get_enemy(1)
	_check(marked.statuses.get(FEAR_KEY, false) == true and marked.statuses.get("weak", 0) == weak,
		"buff source carries Fear and Weak before End Turn")
	var party_before: Array = app.party.get_heroes()
	var marked_block: int = int(marked.block)
	var control_block: int = int(app.enemies.get_enemy(2).block)
	var aged: Dictionary = CombatStatuses.new().end_owner_turn(int(marked.hp), marked_block, marked.statuses)
	_check(aged.ok and not aged.statuses.has(FEAR_KEY) and aged.statuses.get("weak", 0) == weak - 1,
		"canonical owner-turn oracle expires Fear and ages Weak separately")
	_check(app.end_turn_button.is_visible_in_tree() and not app.end_turn_button.disabled
		and app.enemy_attacks == app.enemy_intents.get_intents(),
		"real End Turn is available after the cast with the announced batch current")
	if keyboard:
		app.end_turn_button.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(app.end_turn_button)
	await _frames()
	var feared: Dictionary = app.enemies.get_enemy(1)
	var control: Dictionary = app.enemies.get_enemy(2)
	_check(app.deck.turn_active and app.deck.energy == 3 and app.deck.hand.size() == 5,
		"accepted End Turn opens the next player turn")
	_check(feared.block == marked_block and control.block == control_block + 3,
		"Fear suppresses the marked enemy's announced self-Block buff; the unmarked buff still lands")
	_check(feared.get("statuses", {}) == aged.statuses and not feared.get("statuses", {}).has(FEAR_KEY),
		"Fear expires on its owner-turn boundary and Weak ages separately")
	_check(app.party.get_heroes().map(func(hero): return hero.hp) == party_before.map(func(hero): return hero.hp),
		"buff/Block-only enemy turn deals no hero damage")
	_check(_status_caption(1).contains("weak") == (weak > 1),
		"mounted roster plaque shows only the remaining aged Weak")
	_check(app.enemy_attacks == app.enemy_intents.get_intents() and app.enemy_attacks[0].type == "buff",
		"next turn announces the same self-Block buff")
	if app.end_turn_button.disabled:
		await _frames()
	_check(not app.end_turn_button.disabled, "End Turn re-enables for the next turn")
	app.end_turn_button.grab_focus()
	await _keyboard(KEY_ENTER)
	await _frames()
	_check(app.enemies.get_enemy(1).block == marked_block + 3 and app.enemies.get_enemy(2).block == control_block + 6,
		"suppression applied once: the next accepted End Turn lets the expired source buff again")
	await _dispose()


func _reject(id: String, mode: String, stage: int) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	var source: Callable = presenter._bindings[panel]
	var target_callback: Callable
	if stage > 0:
		await _arm(panel, true)
		_check(presenter._targets.size() == 3, "negative fixture arms three enemy choices")
		if presenter._targets.size() != 3:
			await _dispose()
			return
		target_callback = presenter._targets[_target_panel(1)].callback
		if stage == 2:
			target_callback.call(_press())
			_check(presenter._pending.get("queued", false), "deferred target confirmation queued once")
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"downed": app.party.apply_damage(2, 1000)
		"missing": app.party._heroes[1].id = "seamstress"
		"wrong_seat":
			var first: Dictionary = app.party._heroes[0]
			var second: Dictionary = app.party._heroes[1]
			app.party._heroes[0] = second
			app.party._heroes[1] = first
			app.party._heroes[0].position = 1
			app.party._heroes[1].position = 2
		"unheld":
			app.deck.discard_played(id)
			app.deck.discard_played(id)
		"forged": panel.get_child(0).text = "scarecrow_fake_glare"
		"target_dead": app.enemies.apply_damage(1, 1000)
		"illegal_slot": app.enemies._enemies[0].position = 4
		"actor_replaced": app.enemies._enemies[0] = app.enemies._enemies[0].duplicate(true)
		"hero_replaced": app.party._heroes[0] = app.party._heroes[0].duplicate(true)
		"target_status": app.enemies._enemies[0]["statuses"] = {"weak": 1}
		"owner_moved": app.party._heroes[1].position = 3
		"end_turn": app.deck.combat_state.player_turn_active = false
		"closed": app._battle_closed = true
		"result": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"round": app.enemy_intents.advance_turn()
		"rebuild": app._refresh_hand()
		"cancel": presenter.cancel_button.pressed.emit()
		"escape": await _keyboard(KEY_ESCAPE)
	var before := _model_state()
	if stage == 0:
		source.call(_press())
	elif stage == 1:
		target_callback.call(_press())
	await _frames()
	_check(_model_state() == before and presenter._pending.is_empty(),
		"invalid/cancelled %s stage %d does not pay, mark, or change RNG/result" % [mode, stage])
	await _dispose()


## Mouse and keyboard cancellation leave no trace, and a fresh selection afterwards still commits.
func _cancel_retry(id: String, keyboard: bool) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	var before := _model_state()
	await _arm(panel, keyboard)
	var stale: Callable = presenter._targets[_target_panel(1)].callback if presenter._targets.has(_target_panel(1)) else Callable()
	if keyboard:
		await _keyboard(KEY_ESCAPE)
	else:
		await _mouse(presenter.cancel_button)
	_check(_model_state() == before and presenter._pending.is_empty() and presenter._targets.is_empty(),
		"%s cancel spends nothing and closes the picker" % ("keyboard" if keyboard else "mouse"))
	if stale.is_valid():
		stale.call(_press())
		await _frames()
	_check(_model_state() == before, "cancelled target callback stays inert")
	_check(await _cast(id, keyboard, 2), "a fresh selection after cancel commits")
	var enemy: Dictionary = app.enemies.get_enemy(2)
	_check(app.deck.energy == 0 and app.deck.discard_pile.count(id) == 1
		and enemy.get("statuses", {}).get(FEAR_KEY, false) == true
		and enemy.get("statuses", {}).get("weak", 0) == int(FEAR[id].weak)
		and app.enemies.get_enemy(1) == before[1][0],
		"retry pays once and marks only the newly chosen enemy")
	await _dispose()


func _slain_picker(id: String) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	_check(app.enemies.apply_damage(2, 1000), "one slain target fixture")
	app._refresh_enemy_roster()
	var before := _model_state()
	await _arm(panel, true)
	_check(_model_state() == before and presenter._targets.size() == 2
		and not presenter._targets.has(_target_panel(2)), "dead enemy excluded from legal picker")
	await _keyboard(KEY_ESCAPE)
	_check(_model_state() == before and presenter._pending.is_empty(), "Escape cancels without payment")
	_check(app.enemies.apply_damage(1, 1000) and app.enemies.apply_damage(3, 1000),
		"all enemy targets invalid")
	app._refresh_enemy_roster()
	_check(not presenter._eligible(panel, id, app.deck, app.party, app.battle_view),
		"all-dead roster has no actionable panel")
	await _dispose()


func _replacement(id: String) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	var source: Callable = presenter._bindings[panel]
	await _arm(panel, true)
	var target: Callable = presenter._targets[_target_panel(1)].callback
	var old_deck: CombatDeck = app.deck
	var old_party: CombatParty = app.party
	var old_enemies: CombatEnemies = app.enemies
	var old_rng: RandomNumberGenerator = app.run_rng
	var old_fear = presenter._fear
	var before := _model_state()
	target.call(_press())
	app.return_button.pressed.emit()
	await _frames()
	source.call(_press())
	target.call(_press())
	_check(_snapshot(old_deck, old_party, old_rng) == before[0]
		and old_enemies.get_enemies() == before[1], "retired callbacks cannot pay after exit")
	_check(app._start_battle(), "replacement battle starts")
	await _frames()
	_check(old_fear != null and presenter._fear != null and not is_same(presenter._fear, old_fear),
		"battle rebind replaces the Fear resolver")
	before = _model_state()
	source.call(_press())
	target.call(_press())
	await _frames()
	_check(_model_state() == before, "prior battle callback cannot mutate next battle")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var keyboard := false
	for id: String in FEAR:
		await _success(id, keyboard, 1, 1)
		await _success(id, not keyboard, 2, 2)
		await _success(id, keyboard, 3, 1, "marked")
		await _end_turn(id, keyboard)
		await _cancel_retry(id, false)
		await _cancel_retry(id, true)
		for mode in ["energy", "downed", "missing", "wrong_seat", "unheld", "forged",
				"target_dead", "illegal_slot", "actor_replaced", "hero_replaced", "target_status",
				"owner_moved", "end_turn", "closed", "result", "round", "rebuild"]:
			# Fear is legal from every seat, so a reseated or re-dictioned owner is only stale
			# for an already armed selection; a fresh click there is a valid new choice.
			for stage in ([1, 2] if mode in ["target_dead", "actor_replaced", "target_status", "wrong_seat", "hero_replaced"] else [0, 1, 2]):
				await _reject(id, mode, stage)
		for mode in ["cancel", "escape"]:
			for stage in [1, 2]:
				await _reject(id, mode, stage)
		await _slain_picker(id)
		await _replacement(id)
		keyboard = not keyboard
	for failure in failures:
		printerr("FAIL: " + failure)
	print("live_scarecrow_fear_hand_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
