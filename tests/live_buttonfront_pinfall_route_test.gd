extends "res://tests/live_seeded_opening_route_test.gd"
## Discover by stable encounter ID, then exercise fresh mounted scenes and inputs.


func _fixture() -> Dictionary:
	for value in range(1, 257):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		for id in map.get_legal_choices():
			if map.get_node(id).type != "Fight":
				continue
			if not map.choose_node(id):
				continue
			var choice := RunAuthoredBattleEntry.new().entry_current_battle(
				map, rng, RunFightEncounterSelection.new())
			if choice.get("success", false) and choice.get("encounter_id") == "buttonfront_pinfall":
				return {"seed": value, "id": id}
			# Each first-Fight candidate must use a fresh map and RNG stream.
			break
	return {}


func _values(app) -> Array:
	return [app.run_map.get_route(), app.run_rng.state, app.encounter_id,
		app.party.get_heroes(), app.enemies.get_enemies(), app.deck.hand.duplicate(),
		app.deck.draw_pile.duplicate(), app.deck.discard_pile.duplicate(),
		app.deck.energy, app.deck.turn_active, app.enemy_intents.get_intents(),
		app.enemy_intents._turn_index, app.battle_result.get_outcome(),
		app.run_heroes.duplicate(true), app.run_deck.duplicate(), app.session_gold,
		app.run_scraps, app.party_carryover.read_state(), app.act_outcome.get_state()]


## Build the fight again from its seeded, authored route and run RNG. This
## oracle never reads mounted actions to choose its weighted batch.
func _independent(fixture: Dictionary, app) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(fixture.seed)
	var map := RunMap.new()
	_check(map.generate(rng) and map.choose_node(fixture.id),
		"independent seeded map reaches the actual legal Fight node")
	var entry := RunAuthoredBattleEntry.new().entry_current_battle(
		map, rng, RunFightEncounterSelection.new())
	_check(entry.get("success", false) and entry.encounter_id == "buttonfront_pinfall",
		"independent authored typed choice selects the same encounter")
	if not entry.get("success", false):
		return {}
	var deck := CombatDeck.new([], rng)
	deck.draw_pile.assign(app.run_deck)
	deck._shuffle_draw_pile()
	var party := CombatParty.new(app.run_heroes)
	var definitions: Array = []
	for record in entry.enemies.get_enemies():
		definitions.append(_normal_floor_record(record, map.get_node(fixture.id).floor))
	var enemies := CombatEnemies.new(definitions)
	var intents := CombatEnemyIntents.new(entry.intents._definitions)
	_check(party.is_valid() and enemies.is_valid()
		and intents.bind_battle(enemies, party, rng),
		"genuine separate roster and party cache the initial weighted batch after shuffle")
	var flow := CombatRoundFlow.new(deck, party, enemies, intents,
		CombatBattleResult.new(party, enemies))
	_check(flow.begin_fight(), "independent weighted battle deals its opening hand")
	return {"rng": rng, "deck": deck, "party": party,
		"enemies": enemies, "intents": intents, "flow": flow}


func _oracle_label(oracle: Dictionary) -> String:
	var cues := CombatIntentCues.new().get_cues(oracle.intents, oracle.enemies)
	var lines: PackedStringArray = []
	for cue in cues:
		if cue.icon_key == "block":
			lines.append("Enemy %d: %d Block" % [cue.enemy_position, cue.amount])
		elif cue.icon_key == "buff":
			lines.append("Enemy %d: Buff +%d Block" % [cue.enemy_position, cue.amount])
		elif cue.icon_key == "debuff":
			lines.append("Enemy %d -> Hero %d: %s %d" % [
				cue.enemy_position, cue.target_position, cue.status.capitalize(), cue.amount])
		elif cue.icon_key == "shove":
			lines.append("Enemy %d: Shove Hero %d %s" % [
				cue.enemy_position, cue.target_position,
				"back" if cue.direction == 1 else "front"])
		else:
			lines.append("Enemy %d -> Hero %d (%s): %d damage" % [
				cue.enemy_position, cue.target_position,
				oracle.party.get_hero(cue.target_position).name, cue.amount])
	return "Intent: " + ("none" if lines.is_empty() else "; ".join(lines))


func _matches_oracle(app, oracle: Dictionary) -> bool:
	return (app.run_rng.state == oracle.rng.state
		and app.enemy_intents.get_intents() == oracle.intents.get_intents()
		and app.enemy_intents._turn_index == oracle.intents._turn_index
		and app.party.get_heroes() == oracle.party.get_heroes()
		and app.enemies.get_enemies() == oracle.enemies.get_enemies()
		and app.deck.hand == oracle.deck.hand
		and app.deck.draw_pile == oracle.deck.draw_pile
		and app.deck.discard_pile == oracle.deck.discard_pile
		and app.deck.energy == oracle.deck.energy
		and app.deck.turn_active == oracle.deck.turn_active)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var fixture := _fixture()
	_check(not fixture.is_empty(), "bounded seeds 1..256 find a legal opening Buttonfront Pinfall")
	if fixture.is_empty():
		_finish()
		return
	print("Buttonfront Pinfall discovered seed=", fixture.seed, " node=", fixture.id)
	var replay: Array = []
	var stale := Callable()
	for mode in range(2):
		var app = load("res://scenes/app.tscn").instantiate()
		root.add_child(app)
		await process_frame
		app.run_seed = fixture.seed
		await _activate(app.start_button, mode == 1)
		preload("res://tests/party_choice.gd").choose(app)
		_check(app.run_map != null and app.route_view != null and app.deck == null,
			"real title input initializes chooser before any encounter")
		if app.run_map == null or app.route_view == null:
			app.free()
			continue
		_check(app.run_map.get_legal_choices().has(fixture.id)
			and app.run_map.get_node(fixture.id).type == "Fight", "discovered Fight is legal in live map")
		var before := _record(app)
		if stale.is_valid():
			stale.call()
		_check(_record(app) == before, "old scene route callback cannot create encounter in fresh run")
		_reject(app, "unknown", "unknown route")
		_reject(app, "f02_n0", "future route")
		var foreign := RunMap.new()
		var foreign_rng := RandomNumberGenerator.new()
		foreign_rng.seed = fixture.seed
		_check(foreign.generate(foreign_rng), "foreign map exists")
		_check(not app._choose_route(fixture.id, weakref(foreign)) and _record(app) == before,
			"foreign map request cannot create encounter or consume state")
		var action := _button(app, fixture.id)
		if action == null:
			app.free()
			continue
		action.disabled = true
		_reject(app, fixture.id, "disabled legal route")
		action.disabled = false
		stale = action.pressed.get_connections()[0].callable
		await _activate(action, mode == 1)
		var mounted: bool = app.party != null and app.enemies != null and app.deck != null \
			and app.enemy_intents != null and app.round_flow != null and app.battle_result != null
		_check(mounted and app.encounter_id == "buttonfront_pinfall", "live entry actually selects Buttonfront Pinfall")
		if not mounted:
			app.free()
			continue
		_check(app.run_map.get_route() == [fixture.id] and app.battle_view.is_visible_in_tree(),
			"actual Fight committed and battle visible")
		_check(app.round_flow._party == app.party and app.round_flow._enemies == app.enemies
			and app.round_flow._deck == app.deck and app.round_flow._intents == app.enemy_intents
			and app.deck._rng == app.run_rng, "real models and single run RNG drive End Turn")
		var oracle := _independent(fixture, app)
		_check(not oracle.is_empty(), "independent seeded oracle rebuilds the same Fight")
		if oracle.is_empty():
			app.free()
			continue
		var enemies: Array = app.enemies.get_enemies()
		_check(enemies.size() == 2, "two real enemies mounted")
		if enemies.size() != 2:
			app.free()
			continue
		var floor_number: int = int(app.run_map.get_node(fixture.id).get("floor", 0))
		var mounted_ids: Array = []
		var group_ok := true
		for enemy in enemies:
			mounted_ids.append(enemy.id)
			group_ok = group_ok and BAND_ORACLE.records().has(enemy.id)
		_check(group_ok and BAND_ORACLE.legal_group(mounted_ids, floor_number),
			"mounted roster is a legal floor-%d band group of authored normals" % floor_number)
		_check(enemies == oracle.enemies.get_enemies(),
			"band identities, slots and authored HP match the seeded oracle")
		var presenter = app.get_node("LiveEnemyRoster")
		_check(presenter.enemies == app.enemies and presenter._labels.size() == 2,
			"live roster presenter binds the actual two enemies")
		for index in range(presenter._labels.size()):
			_check(presenter._labels[index].is_visible_in_tree() and presenter._labels[index].text
				== String(enemies[index].name),
				"real target name tag displays exact identity")
			var meter = app.get_node("LiveCombatMeters").row.get_child(3 + index)
			_check(meter.hp_text.is_visible_in_tree() and meter.hp_text.text == "%d/%d" % [enemies[index].hp, enemies[index].max_hp]
				and meter.block_badge.visible == (enemies[index].block > 0)
				and (enemies[index].block == 0 or meter.block_text.text == "%d" % enemies[index].block),
				"real enemy meter displays exact HP and Block")
		_check(app.party.get_hero(1).hp == 40 and app.party.get_hero(1).block == 6,
			"ordinary Warden opening Block absorbs exactly the Exposed-enhanced six damage")
		_check(_matches_oracle(app, oracle),
			"opening roster, weighted intent, HP, Block, full deck and RNG match seeded oracle")
		var trace: Array = [_values(app)]
		for turn in range(4):
			_check(not app.intent_label.visible and app.intent_label.text == _oracle_label(oracle),
				"announced exact action, target and authored amount before beat %d" % (turn + 1))
			var unchanged := _values(app)
			app._refresh_intents()
			_check(_values(app) == unchanged and app.intent_label.text == _oracle_label(oracle),
				"refresh and preview never reroll or spend the run RNG")
			stale.call()
			_check(not app._choose_route(fixture.id) and not app._choose_route("f02_n0")
				and _values(app) == unchanged, "stale and illegal route inputs cannot alter active encounter")
			_check(app.deck.turn_active and app.deck.energy == 3 and app.deck.hand.size() == 5
				and not app.end_turn_button.disabled, "legal ordinary End Turn available")
			_check(oracle.flow.end_turn(),
				"independent bound scheduler executes one actual weighted phase and next announcement")
			await _activate(app.end_turn_button, mode == 1)
			_check(app.enemy_intents._turn_index == turn + 1 and app.deck.turn_active,
				"real End Turn advances exactly one beat and draws next hand")
			_check(_matches_oracle(app, oracle),
				"exact post-phase HP, statuses, Block, deck, cache and RNG after beat %d" % (turn + 1))
			trace.append(_values(app))
		_check(app.intent_label.text == _oracle_label(oracle)
			and _matches_oracle(app, oracle),
			"fifth announcement and terminal four-beat snapshots match independently drawn cache")
		if mode == 0:
			replay = trace
		else:
			_check(trace == replay and trace.size() == 5,
				"independent same-seed scene replays all actors, hands, RNG, intents and run ledgers")
		app.free()
		await process_frame
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_buttonfront_pinfall_route_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
