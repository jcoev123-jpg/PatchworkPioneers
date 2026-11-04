extends "res://tests/live_support_hand_test.gd"

const IDS := ["rag_duelist_rapier_lunge", "rag_duelist_rapier_lunge_plus",
	"rag_duelist_needle_lunge", "rag_duelist_needle_lunge_plus"]

func _begin(id: String, seat: int = 2) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 290
	_check(app._start_battle(), "mounted battle starts")
	presenter = app.get_node("LiveAttackPreview")
	var rng := RandomNumberGenerator.new()
	rng.seed = 290
	var cards: Array[String] = [id, id, "warden_strike", "warden_brace", "tinker_tune_up"]
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.count(id) == 2, "two genuine drawn copies")
	app.deck.combat_state.energy = 1
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 25}]
	heroes.insert(seat - 1, {"id": "rag_duelist", "name": "Rag Duelist", "max_hp": 30, "statuses": {"weak": 1}})
	app.party = CombatParty.new(heroes)
	app.enemies = CombatEnemies.new([
		{"id": "tangled", "max_hp": 50, "statuses": {"tangled": 2, "exposed": 1}},
		{"id": "untangled", "max_hp": 50, "statuses": {"bleed": 2}},
		{"id": "slain", "max_hp": 50, "statuses": {"tangled": 3}}])
	_check(app.party.is_valid() and app.enemies.is_valid(), "real valid rosters")
	_check(app.enemies.gain_block(2, 3), "back survivor has Block")
	_check(app.party.get_hero(seat).id == "rag_duelist" and app.enemies.get_enemy(2).block == 3,
		"non-vacuous owner seat and real Block preconditions")
	for position in [1, 2, 3]:
		_check(app.party.apply_damage(position, position) and app.party.gain_block(position, position + 1),
			"living heroes have distinct HP and Block before selection")
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies, app.enemy_intents, app.battle_result)
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_hand()
	await _frames()
	var panel := _pool_panel(id)
	_check(panel != null and panel.is_visible_in_tree() and presenter._bindings.has(panel), "authentic panel bound by mounted adapter")
	return panel


func _dispose() -> void:
	app.free()
	await _frames()



func _state() -> Array:
	return [_snapshot(app.deck, app.party, app.run_rng), app.enemies.get_enemies(),
		app.battle_result.get_outcome(), presenter.last_event.duplicate(true)]


func _arm(panel: Control, keyboard: bool) -> void:
	if keyboard:
		await _keyboard(KEY_ESCAPE)
		await _keyboard(KEY_P)
	else:
		await _mouse(panel)
	_check(presenter._armed == panel, "actual held panel armed")


func _success(id: String, seat: int, target: int, keyboard: bool, statuses: bool) -> void:
	var panel := await _begin(id, seat)
	if panel == null:
		await _dispose()
		return
	if not statuses:
		for hero in app.party._heroes:
			hero.statuses = {}
		for enemy in app.enemies._enemies:
			enemy.statuses = {}
	var metadata = app.get_node("LiveSupportHand")._metadata
	var facts: Dictionary = metadata.get_facts(panel)
	_check(facts.known and facts.cost == 1 and facts.owner == "rag_duelist"
		and metadata.definition(id) == presenter._lunge._catalog_definition(id)
		and metadata.visual_state(panel).playable
		and metadata.short_line(id).contains("forward 1"), "authentic enabled face with authored movement")
	var before := _state()
	await _hover(panel)
	var quote: Dictionary = presenter.current_forecast.duplicate(true)
	_check(quote.get("playable", false) and quote.target_positions == [1, 2]
		and quote.owner_position == seat and quote.destination_position == seat - 1
		and presenter.cue.text.contains("1 energy") and presenter.cue.text.contains("move forward"),
		"pure forecast offers original slots and adjacent forward move")
	_check(_state() == before, "hover is pure including RNG")
	await _arm(panel, keyboard)
	_check(_state() == before, "selection is pure")
	await _keyboard(KEY_3)
	_check(_state() == before and presenter._armed == panel, "slot three cannot commit")
	var heroes: Array = app.party.get_heroes()
	var enemies: Array = app.enemies.get_enemies()
	var hand: Array = app.deck.hand.duplicate()
	var discard: Array = app.deck.discard_pile.duplicate()
	var draw: Array = app.deck.draw_pile.duplicate()
	var rng_state: int = app.run_rng.state
	var base: int = [5, 7, 6, 8][IDS.find(id)]
	var damage := base if not statuses else int(floor(base * (1.125 if target == 1 else 0.75))) + (2 if statuses and target == 1 else 0)
	_check(quote.hits[target - 1].damage == damage, "independent authored/status damage oracle")
	var callback: Callable = presenter._bindings[panel].input
	var replay_args: Array = [panel, id, target, presenter._token, app.party, app.enemies,
		app.battle_result, app.run_rng, presenter._turn, app.enemies.get_enemy(target).id,
		panel.get_index(), app.deck, app.deck.hand.duplicate(), app.run_map, presenter._pinned]
	if keyboard:
		root.push_input(_key(KEY_1 if target == 1 else KEY_2), true)
		root.push_input(_key(KEY_1 if target == 1 else KEY_2), true)
		root.push_input(_key(KEY_1 if target == 1 else KEY_2, false), true)
		await _frames()
	else:
		await _mouse(app.get_node("LiveEnemyRoster")._labels[target - 1])
	var event: Dictionary = presenter.last_event
	_check(event.get("ok", false) and event.damage == damage and event.cost == 1
		and event.owner_position == seat and event.destination_position == seat - 1,
		"confirmed real resolver receipt")
	var victim: Dictionary = enemies[target - 1]
	var absorbed := mini(int(victim.block), damage)
	victim.block -= absorbed
	victim.hp -= damage - absorbed
	_check(app.enemies.get_enemies() == enemies and event.block_absorbed == absorbed
		and event.hp_loss == damage - absorbed, "exact target HP/Block and all non-target fields preserved")
	var mover: Dictionary = heroes[seat - 1]
	var neighbor: Dictionary = heroes[seat - 2]
	heroes[seat - 2] = mover
	heroes[seat - 1] = neighbor
	mover.position = seat - 1
	neighbor.position = seat
	hand.erase(id)
	discard.append(id)
	_check(app.party.get_heroes() == heroes and app.deck.energy == 0
		and app.deck.hand == hand and app.deck.discard_pile == discard
		and app.deck.draw_pile == draw and app.run_rng.state == rng_state,
		"one exact spend/discard/swap, every actor field and RNG preserved")
	var settled := _state()
	callback.call(_press())
	presenter._commit.callv(replay_args)
	presenter._queue_attack(target)
	await _frames()
	_check(_state() == settled and presenter._armed == null, "retired panel and duplicate input cannot replay")
	await _dispose()


func _refuse(mode: String, queued: bool) -> void:
	var panel := await _begin(IDS[0])
	if panel == null:
		await _dispose()
		return
	await _arm(panel, true)
	if queued:
		presenter._queue_attack(2 if mode == "absent" else 1)
		_check(presenter._queued, "valid receipt genuinely queued")
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"downed": app.party.apply_damage(2, 999)
		"neighbor": app.party.apply_damage(1, 999)
		"tangled": app.party._heroes[1].statuses = {"tangled": 1}
		"neighbor_tangled": app.party._heroes[0].statuses = {"tangled": 1}
		"front":
			var hero: Dictionary = app.party._heroes[1]
			app.party._heroes[1] = app.party._heroes[0]
			app.party._heroes[0] = hero
			app.party._heroes[0].position = 1
			app.party._heroes[1].position = 2
		"missing_owner": app.party._heroes[1].id = "seamstress"
		"hand":
			app.deck.discard_played(IDS[0])
			app.deck.discard_played(IDS[0])
		"hand_order": app.deck.hand.reverse()
		"dead": app.enemies.apply_damage(1, 999)
		"absent":
			app.enemies = CombatEnemies.new([{ "id": "remaining", "max_hp": 50 }])
			app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"identity": app.enemies._enemies[0].id = "replacement"
		"status": app.enemies._enemies[0].statuses = {"weak": -1}
		"inactive": app.deck.combat_state.player_turn_active = false
		"turn": app.enemy_intents.advance_turn()
		"closed": app._battle_closed = true
		"hidden": app.battle_view.hide()
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"rng":
			app.run_rng = RandomNumberGenerator.new()
			app.run_rng.seed = 291
		"deck":
			app.deck = CombatDeck.new([IDS[0]], app.run_rng)
			app.deck.start_turn()
		"panel": app._refresh_hand()
		"label": panel.get_child(0).text = IDS[1]
		"escape":
			root.push_input(_key(KEY_ESCAPE), true)
			root.push_input(_key(KEY_ESCAPE, false), true)
	var before := _state()
	# Before a queue, session/turn changes are observed by the real input lifecycle.
	# Identity replacement is only stale after target selection has bound its ID.
	if not queued and mode == "identity":
		await _keyboard(KEY_ESCAPE)
	elif not queued:
		root.push_input(_key(KEY_1), true)
		root.push_input(_key(KEY_1, false), true)
	await _frames()
	_check(_state() == before, "full no-spend rejection: " + mode + " queued=" + str(queued))
	var settled := _state()
	presenter._queue_attack(1)
	await _frames()
	_check(_state() == settled, "rejected selection cannot replay: " + mode)
	await _dispose()


## One real mounted, held-card Lunge against a foe carrying Thorns 3 and Enrage:
## the same Duelist takes the retaliation at the slot he moves into (never the ally
## who takes his old slot), the selected foe gains exactly one stack, and the
## existing projection then pays +2 for it.
func _keywords(keyboard: bool) -> void:
	var panel := await _begin(IDS[0], 2)
	if panel == null:
		await _dispose()
		return
	for hero in app.party._heroes:
		hero.statuses = {}
	for enemy in app.enemies._enemies:
		enemy.statuses = {}
	app.enemies._enemies[0]["thorns"] = 3
	app.enemies._enemies[0]["enrage"] = true
	_check(app.party.start_player_turn() and app.party.gain_block(2, 2),
		"mounted keyword fixture: living Duelist holding exactly two Block")
	var heroes: Array = app.party.get_heroes()
	var enemies: Array = app.enemies.get_enemies()
	var hand: Array = app.deck.hand.duplicate()
	var discard: Array = app.deck.discard_pile.duplicate()
	var draw: Array = app.deck.draw_pile.duplicate()
	var rng_state: int = app.run_rng.state
	_check(heroes[1].id == "rag_duelist" and heroes[1].hp == 28 and heroes[1].block == 2
		and enemies[0].thorns == 3 and enemies[0].enrage == true,
		"mounted keyword preconditions are real, living and non-vacuous")
	var before := _state()
	await _hover(panel)
	var quote: Dictionary = presenter.current_forecast.duplicate(true)
	_check(quote.get("playable", false) and quote.hits[0].damage == 5
		and presenter.cue.text.contains("1 energy"), "mounted keyword forecast still quotes the printed strike")
	_check(_state() == before, "mounted keyword hover is pure including RNG")
	await _arm(panel, keyboard)
	_check(_state() == before, "mounted keyword selection is pure including RNG")
	if keyboard:
		root.push_input(_key(KEY_1), true)
		root.push_input(_key(KEY_1), true)
		root.push_input(_key(KEY_1, false), true)
		await _frames()
	else:
		await _mouse(app.get_node("LiveEnemyRoster")._labels[0])
	var event: Dictionary = presenter.last_event
	_check(event.get("ok", false) and event.damage == 5 and event.cost == 1
		and event.owner_position == 2 and event.destination_position == 1
		and event.target_position == 1, "mounted keyword confirmed receipt")
	_check(event.get("thorns_retaliation") == {"ok": true, "applied": true, "thorns": 3,
		"block_absorbed": 2, "hp_loss": 1}, "mounted confirmed hit provokes one Thorns retaliation")
	_check(event.get("enrage_commit") == {"ok": true, "applied": true,
		"enrage_stacks": 1, "attack_bonus": 2}, "mounted confirmed hit commits one Enrage stack")
	var expected_enemies: Array = enemies.duplicate(true)
	expected_enemies[0]["hp"] = int(expected_enemies[0]["hp"]) - 5
	expected_enemies[0]["enrage_stacks"] = 1
	_check(app.enemies.get_enemies() == expected_enemies,
		"selected foe loses exactly the printed five, gains one stack, others untouched")
	var mover: Dictionary = heroes[1]
	var neighbor: Dictionary = heroes[0]
	heroes[0] = mover
	heroes[1] = neighbor
	mover.position = 1
	neighbor.position = 2
	var absorbed := mini(int(mover.block), 3)
	mover.block -= absorbed
	mover.hp -= 3 - absorbed
	_check(app.party.get_heroes() == heroes,
		"the same Duelist takes the Thorns hit after moving, every other hero preserved")
	_check(app.party.get_hero(1).id == "rag_duelist" and app.party.get_hero(1).hp == 27
		and app.party.get_hero(1).block == 0, "moved Duelist paid 2 Block then 1 HP")
	_check(app.party.get_hero(2).id == "warden" and app.party.get_hero(2).hp == 39
		and app.party.get_hero(2).block == 0, "the swapped ally never takes the retaliation")
	var projected := CombatEnemyKeywordRules.new().project_enrage_action(
		app.enemies.get_enemy(1), {"type": "attack", "amount": 3})
	_check(projected.ok and projected.attack_bonus == 2 and projected.action.amount == 5,
		"the existing action projection pays +2 for the committed stack")
	hand.erase(IDS[0])
	discard.append(IDS[0])
	_check(app.deck.energy == 0 and app.deck.hand == hand and app.deck.discard_pile == discard
		and app.deck.draw_pile == draw and app.run_rng.state == rng_state,
		"one exact spend/discard/swap, every actor field and RNG preserved")
	var settled := _state()
	presenter._queue_attack(1)
	await _frames()
	_check(_state() == settled, "settled mounted keyword play cannot replay a hit or a stack")
	await _dispose()


func _dead_slot() -> void:
	var panel := await _begin(IDS[3], 3)
	app.enemies.apply_damage(1, 999)
	await _hover(panel)
	_check(presenter.current_forecast.target_positions == [2], "slain original slot omitted without compaction")
	await _arm(panel, true)
	var before := _state()
	await _keyboard(KEY_1)
	_check(_state() == before, "dead slot shortcut inert")
	await _keyboard(KEY_2)
	_check(presenter.last_event.get("ok", false) and presenter.last_event.target_position == 2,
		"surviving original slot two remains executable")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id in IDS:
		for seat in [2, 3]:
			for target in [1, 2]:
				for keyboard in [false, true]:
					for statuses in [false, true]:
						await _success(id, seat, target, keyboard, statuses)
	for mode in ["energy", "downed", "neighbor", "tangled", "neighbor_tangled", "front",
		"missing_owner", "hand", "hand_order", "dead", "absent", "identity", "status",
		"inactive", "turn", "closed", "hidden", "session", "rng", "deck", "panel", "label", "escape"]:
		for queued in [false, true]:
			await _refuse(mode, queued)
	for keyboard in [false, true]:
		await _keywords(keyboard)
	await _dead_slot()
	_finish()



func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_rag_duelist_lunge_hand_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
