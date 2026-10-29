extends SceneTree
## Fight-local Moth Swarm birth: authoritative bound roster, scheduler and rounds.
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures.append(reason)


func _source() -> Dictionary:
	var parsed := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
	for record in parsed:
		if record.get("id") == "moth_swarm":
			return record.duplicate(true)
	return {}


func _fixture(seed_value: int, count: int = 2) -> Dictionary:
	var mother := _source()
	if mother.is_empty():
		return {}
	var summon: Dictionary = {}
	for action in mother.intent.actions:
		if action.get("type") == "summon":
			summon = action.duplicate(true)
	_check(CombatEnemyIntents.weighted_action(summon) == {"weight": 1, "action": {"type": "summon", "amount": 0}},
		"precondition: shipped Moth authors a real weighted zero-amount summon")
	if summon.is_empty():
		return {}
	mother.intent = {"target": "front", "actions": [summon]}
	var actors: Array = [mother]
	for i in range(1, count):
		actors.append({"id": "passive_%d" % i, "name": "Passive",
			"max_hp": 12, "intent": {"target": "front", "actions": [
				{"type": "block", "amount": 0, "weight": 1}]}})
	var enemies := CombatEnemies.new(actors)
	var party := CombatParty.new([
		{"id": "warden", "max_hp": 40}, {"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var definitions: Array = []
	for i in range(count):
		definitions.append({"enemy_position": i + 1, "pattern": [
			{"type": "block", "amount": 0}]})
	var scheduler := CombatEnemyIntents.new(definitions)
	_check(enemies.is_valid() and party.is_valid() and scheduler.is_valid(),
		"precondition: real two/three-enemy combat models and three living heroes")
	_check(scheduler.bind_battle(enemies, party, rng),
		"precondition: the authentic bound weighted scheduler accepts the fight")
	return {"enemies": enemies, "party": party, "rng": rng, "intents": scheduler}


func _phase_cases() -> void:
	for count in [2, 3]:
		var f := _fixture(12945 + count, count)
		if f.is_empty():
			continue
		var enemies: CombatEnemies = f.enemies
		var party: CombatParty = f.party
		var rng: RandomNumberGenerator = f.rng
		var intents: CombatEnemyIntents = f.intents
		var previous: Array = enemies.get_enemies()
		var before_heroes: Array = party.get_heroes()
		var rng_before: int = rng.state
		var selected: Array = intents.get_intents()
		_check(selected[0].type == "summon" and selected.size() == count,
			"precondition: the living Moth actually announces Summon")
		var result := CombatEnemyPhase.new().execute_phase(party, enemies, selected, null, true)
		_check(result.get("ok", false), "staged broodling beat completes without a failed batch")
		_check(rng.state == rng_before, "resolving Summon never uses the run RNG")
		if count == 3:
			_check(enemies.get_enemies() == previous and enemies.get_enemies().size() == 3
				and not enemies.get_enemy(1).has(CombatEnemies.BROODLING_LATCH),
				"a full three-slot roster skips the birth without spending its latch")
			_check(not result.events[0].applied, "full-cap birth publishes an inert event")
			continue
		_check(enemies.get_enemies().size() == 3 and enemies.get_enemy(3).id == CombatEnemies.BROODLING_ID
			and enemies.get_enemy(3).hp == 8 and enemies.get_enemy(3).max_hp == 8
			and enemies.get_enemy(3).block == 0 and enemies.get_enemy(3).position == 3,
			"two-foe phase appends one unique stable 8-HP child to the vacant third slot")
		_check(enemies.get_enemy(1).get(CombatEnemies.BROODLING_LATCH) == true
			and result.events[0].applied and result.events[0].spawn_position == 3
			and party.get_heroes() == before_heroes,
			"successful birth latches the mother without an immediate child attack")
		_check(intents.get_intents() == selected,
			"birth itself leaves the current announced two-source phase intact")
		_check(intents.advance_turn() and intents.get_intents().size() == 3
			and intents.get_intents()[2] == {"enemy_position": 3, "type": "attack",
				"amount": 5, "target_position": 1},
			"only the following turn announces the child attack-5 on the living front hero")
		_check(rng.state == rng_before, "one-action child needs no extra seeded draw")
		var hp_before: int = party.get_hero(1).hp
		var next := CombatEnemyPhase.new().execute_phase(party, enemies, intents.get_intents(), null, true)
		_check(next.ok and party.get_hero(1).hp == hp_before - 5
			and next.events[2].applied and next.events[2].enemy_position == 3,
			"child acts only in the following genuine enemy phase and hits for five")
		var after := enemies.get_enemies()
		_check(CombatEnemyPhase.new().execute_phase(party, enemies, selected, null, true).ok
			and enemies.get_enemies() == after,
			"repeating the source's Summon after the latch is inert")
		_check(enemies.apply_damage(1, 21) and enemies.apply_damage(2, 12)
			and not enemies.is_victorious(), "a live child prevents victory after both original foes die")
		_check(enemies.apply_damage(3, 8) and enemies.is_victorious(),
			"the child is targetable and its death permits legitimate victory")
	
	# Slain sources are inert; a forged non-Moth source is rejected.
	var dead := _fixture(31)
	dead.enemies.apply_damage(1, 21)
	var dead_before: Array = dead.enemies.get_enemies()
	var dead_rng: int = dead.rng.state
	var inert := CombatEnemyPhase.new().execute_phase(dead.party, dead.enemies,
		dead.intents.get_intents(), null, true)
	_check(inert.ok and not inert.events[0].applied and dead.enemies.get_enemies() == dead_before
		and dead.rng.state == dead_rng, "dead source cannot summon, latch or draw RNG")
	var wrong := _fixture(32)
	wrong.enemies._enemies[0].id = "not_moth"
	var wrong_before: Array = wrong.enemies.get_enemies()
	_check(not CombatEnemyPhase.new().execute_phase(wrong.party, wrong.enemies,
		wrong.intents.get_intents(), null, true).ok
		and wrong.enemies.get_enemies() == wrong_before,
		"source identity forgery rejects the entire phase")
	for bad in ["true", 1, 1.0, null, [], {}]:
		var broken := _fixture(33)
		broken.enemies._enemies[0][CombatEnemies.BROODLING_LATCH] = bad
		var before := [broken.party.get_heroes(), broken.enemies.get_enemies(),
			broken.intents.get_intents(), broken.rng.state]
		_check(CombatEnemyPhase.new().execute_phase(broken.party, broken.enemies,
			broken.intents.get_intents(), null, true) == {"ok": false, "events": []}
			and before == [broken.party.get_heroes(), broken.enemies.get_enemies(),
				broken.intents.get_intents(), broken.rng.state],
			"malformed latch refuses the entire batch without actor, intent or RNG mutation")


func _round_session(seed_value: int) -> Array:
	var f := _fixture(seed_value)
	if f.is_empty():
		return []
	var cards := StarterCards.new().get_starting_deck()
	var deck := CombatDeck.new(cards, f.rng)
	var result := CombatBattleResult.new(f.party, f.enemies)
	var gauges := CombatUnravel.new()
	var tiers := {}
	for i in range(f.enemies.get_enemies().size()):
		tiers[i + 1] = "normal"
	_check(gauges.bind_roster(f.enemies, tiers) and gauges.apply_unravel(f.enemies, 1, 3),
		"precondition: same real battle has a charged and correctly bound Unravel gauge")
	var flow := CombatRoundFlow.new(deck, f.party, f.enemies, f.intents, result, gauges)
	_check(flow.begin_fight(), "precondition: real shared deck opens bound fight")
	var before_hero: Array = f.party.get_heroes()
	_check(flow.end_turn(), "end turn commits first phase")
	_check(f.enemies.get_enemies().size() == 3 and f.intents.get_intents().size() == 3
		and f.intents.get_intents()[2].amount == 5
		and gauges.get_snapshot(1).get("gauge") == 3
		and gauges.get_snapshot(3).get("threshold") == CombatUnravel.THRESHOLD_NORMAL
		and gauges.get_snapshot(3).get("gauge") == 0,
		"round flow admits the spawned child to the next announced batch")
	_check(f.party.get_hero(1).hp == before_hero[0].hp
		and f.party.get_hero(2).hp == before_hero[1].hp
		and f.party.get_hero(3).hp == before_hero[2].hp,
		"newborn cannot damage a hero during the end turn that created it")
	_check(flow.get_outcome() == CombatBattleResult.ACTIVE,
		"live result remains active with a living child")
	var child_before: int = f.party.get_hero(1).hp
	_check(flow.end_turn() and f.party.get_hero(1).hp == child_before - 5,
		"next accepted end turn actually resolves the announced child hit")
	_check(f.enemies.apply_damage(1, 21) and f.enemies.apply_damage(2, 12),
		"precondition: both originals can die independently")
	_check(flow.observe_result() == CombatBattleResult.ACTIVE,
		"battle may not report premature victory while summoned child lives")
	_check(f.enemies.apply_damage(3, 8) and flow.observe_result() == CombatBattleResult.VICTORY,
		"child is a genuine last target in the result's victory query")
	return [f.party.get_heroes(), f.enemies.get_enemies(),
		f.intents.get_intents(), f.rng.state, result.get_outcome()]


## Use the shipped map, authored Fight selector, roster and actual app battle
## controls. A deterministic seed search is only a witness search, not a patched
## catalog, forged scheduler or fake action handed to the scene.
func _mounted_routed_fight() -> void:
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "precondition: actual app scene loads")
	if scene == null:
		return
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	var material := RunAuthoredBattleEntry._floor_band_material(null)
	_check(material.get("ok", false), "precondition: genuine normal-Fight floor bands load")
	if not material.get("ok", false):
		app.free()
		return
	var floor_number := 0
	for band in RunV3FloorBandRoster.BAND_KEYS:
		if material.pools[band].has(CombatEnemies.MOTH_ID):
			floor_number = {"1-4": 2, "5-8": 5, "9-11": 9}[band]
	_check(floor_number > 0, "precondition: the shipped Moth is in a reachable normal-Fight band")
	if floor_number == 0:
		app.free()
		return
	var found := {}
	for value in range(1, 501):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		var routes := {}
		for choice in map.get_legal_choices():
			routes[choice] = [choice]
		for step in range(1, floor_number):
			var next_routes := {}
			for current in routes:
				for next_id in map.get_node(current).get("outgoing", []):
					if not next_routes.has(next_id):
						next_routes[next_id] = routes[current] + [next_id]
			routes = next_routes
		var route: Array = []
		for target in routes:
			if map.get_node(target).get("type") == "Fight":
				route = routes[target]
				break
		if route.is_empty():
			continue
		var legal := true
		for node_id in route:
			if not map.choose_node(node_id):
				legal = false
				break
		if not legal or map.get_current_floor() != floor_number:
			continue
		var entry := RunAuthoredBattleEntry.new().entry_current_battle(
			map, rng, RunFightEncounterSelection.new())
		if not entry.get("success", false):
			continue
		var records: Array = entry.enemies.get_enemies()
		if records.size() != 2:
			continue
		var moth_position := 0
		for record in records:
			if record.get("id") == CombatEnemies.MOTH_ID:
				moth_position = record.position
		if moth_position == 0:
			continue
		# Rehearse the same genuine admission shuffle on a copied run RNG.
		# The actual routed app still binds the unmodified authored weights.
		var preview_rng := RandomNumberGenerator.new()
		preview_rng.seed = rng.seed
		preview_rng.state = rng.state
		var preview_deck := CombatDeck.new([], preview_rng)
		preview_deck.draw_pile.assign(app._load_starter_deck())
		preview_deck._shuffle_draw_pile()
		var announcement := CombatEnemyIntents.new(entry.definitions)
		var party := CombatParty.new(app._load_party_definitions())
		if not announcement.bind_battle(entry.enemies, party, preview_rng):
			continue
		if announcement.get_intents()[moth_position - 1].get("type") != "summon":
			continue
		found = {"map": map, "rng": rng, "entry": entry,
			"moth_position": moth_position, "seed": value}
		break
	_check(not found.is_empty(),
		"precondition: a seeded real floor-four two-enemy Fight authors and announces the Moth birth")
	if found.is_empty():
		app.free()
		return
	app.run_map = found.map
	app.run_seed = found.seed
	_check(app._start_battle(found.rng, found.entry.definitions, found.entry.enemies),
		"mounted app enters the selected real Fight with its run RNG and authored schedules")
	if app.round_flow == null or app.enemies == null:
		app.free()
		return
	await process_frame
	_check(app.run_map.get_node(app.run_map.get_current_node_id()).get("type") == "Fight"
		and app.enemy_intents.is_bound() and app.enemies.get_enemies().size() == 2
		and app.enemy_intents.get_intents()[found.moth_position - 1].get("type") == "summon",
		"precondition: mounted routed fight retains the authentic source and current announcement")
	_check(is_instance_valid(app.end_turn_button) and app.end_turn_button.is_visible_in_tree()
		and not app.end_turn_button.disabled,
		"precondition: actual End Turn button is actionable")
	var rng_before: int = app.run_rng.state
	app.end_turn_button.pressed.emit()
	await process_frame
	var stage = app.get_node("LiveEnemyRoster")
	var meters = app.get_node("LiveCombatMeters")
	_check(app.enemies.get_enemies().size() == 3
		and app.enemies.get_enemy(3).get("id") == CombatEnemies.BROODLING_ID
		and app.enemy_intents.get_intents().size() == 3
		and app.enemy_intents.get_intents()[2].get("amount") == 5,
		"real mounted End Turn summons the child and announces its attack next turn")
	_check(stage._labels.size() == 3 and stage._labels[2].text == "Moth Broodling"
		and meters.row.get_child_count() == CombatParty.PARTY_SIZE + 3,
		"birth is visible as a third selectable enemy puppet and distinct HP ribbon")
	_check(app.enemies.get_enemy(3).get("hp") == 8
		and app.enemies.get_enemy(3).get("position") == 3
		and app.round_flow._unravel.get_snapshot(3).get("threshold") == CombatUnravel.THRESHOLD_NORMAL,
		"the routed child is a real 8 HP combat actor with an independent normal Unravel gauge")
	_check(app.run_rng.state != rng_before or app.deck.turn_active,
		"live turn legitimately cycles the same run RNG through a single next-hand deal")
	app.free()


func _run() -> void:
	_phase_cases()
	await _mounted_routed_fight()
	var first := _round_session(9452)
	var replay := _round_session(9452)
	_check(not first.is_empty() and first == replay, "seeded bound rounds replay identically")
	if failures.is_empty():
		print("combat_v3_moth_summon_test: PASS (", checks, " checks)")
	else:
		for reason in failures:
			printerr(reason)
		print("combat_v3_moth_summon_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
