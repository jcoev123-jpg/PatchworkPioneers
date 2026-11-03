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


func _source(queen: bool = false) -> Dictionary:
	var parsed := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/enemies/boss.json" if queen else "res://data/enemies/run_enemies.json"))
	for record in parsed:
		if record.get("id") == ("moth_queen" if queen else "moth_swarm"):
			return record.duplicate(true)
	return {}


func _fixture(seed_value: int, count: int = 2, queen: bool = false) -> Dictionary:
	var mother := _source(queen)
	if mother.is_empty():
		return {}
	var summon: Dictionary = {}
	for action in mother.intent.actions:
		if action.get("type") == "summon":
			summon = action.duplicate(true)
	_check(CombatEnemyIntents.weighted_action(summon) == {"weight": 2 if queen else 1, "action": {"type": "summon", "amount": 0}},
		"precondition: shipped Moth authors a real weighted zero-amount summon")
	if summon.is_empty():
		return {}
	_check(CombatEnemies.authentic_broodling_mother(mother, 1),
		"precondition: complete shipped weighted mother is authentic")
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
	if not scheduler.is_bound():
		return {}
	var found := false
	for step in range(80):
		var chosen := scheduler.get_intents()
		if not chosen.is_empty() and chosen[0].get("type") == "summon":
			found = true
			break
		if not scheduler.advance_turn():
			break
	_check(found, "precondition: genuinely weighted parent selects Summon")
	if not found:
		return {}
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
		var oracle := RandomNumberGenerator.new()
		oracle.seed = rng.seed
		oracle.state = rng_before
		var parent_weight := 0
		for entry in enemies.get_enemy(1).intent.actions:
			parent_weight += int(entry.weight)
		oracle.randi_range(1, parent_weight)
		_check(rng.state == oracle.state,
			"child admission draws no RNG beyond the authored parent choice")
		# The mother's new attack2 can also hit this phase. Resolve the same
		# parents independently, then prove the child's additional five HP loss.
		var parent_party := CombatParty.new(party.get_heroes())
		var parent_enemies := CombatEnemies.new(enemies.get_enemies())
		var parent_phase := CombatEnemyPhase.new().execute_phase(parent_party, parent_enemies,
			intents.get_intents().slice(0, 2), null, true)
		_check(parent_phase.ok and parent_party.get_hero(1).hp > 5,
			"precondition: authentic parent beats leave a living front target for the child")
		var next := CombatEnemyPhase.new().execute_phase(party, enemies, intents.get_intents(), null, true)
		_check(next.ok and party.get_hero(1).hp == parent_party.get_hero(1).hp - 5
			and next.events.size() == parent_phase.events.size() + 1
			and next.events.back() == {"type": "attack", "enemy_position": 3,
				"target_position": 1, "applied": true},
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
	var announced_next: Array = f.intents.get_intents()
	var parent_damage := int(announced_next[0].get("amount", 0)) if announced_next[0].get("type") == "attack" else 0
	var before_block: int = f.party.get_hero(1).block
	if announced_next[0].get("type") == "snip_block":
		before_block = 0
	var expected_hp := maxi(0, child_before - maxi(0, parent_damage + 5 - before_block))
	_check(flow.end_turn() and f.party.get_hero(1).hp == expected_hp,
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


## A separate opt-in three-of-four mounted Fight witness. Its three records come
## from the shipped enemy catalog, but are NOT injected into run encounter pools.
## Only the actual weighted Moth draw and the app's visible End Turn can birth.
func _mounted_fourth_slot_input() -> void:
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "AC1 precondition: real app scene can mount four-capacity witness")
	if scene == null:
		return
	var catalog := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
	var definitions: Array = []
	for id in [CombatEnemies.MOTH_ID, "fray_scavenger", "felt_bulwark"]:
		for record in catalog:
			if record.get("id") == id:
				definitions.append(record.duplicate(true))
				break
	_check(definitions.size() == 3 and (definitions.is_empty() or
		CombatEnemies.authentic_broodling_mother(definitions[0], 1)),
		"AC1 precondition: three different catalog actors include the full genuine Moth spec")
	if definitions.size() != 3:
		return
	var roster := CombatEnemies.new(definitions, CombatEnemies.OPT_IN_MAX_ENEMIES)
	var slots: Array = []
	for position in range(1, 4):
		slots.append({"enemy_position": position, "pattern": [
			{"type": "block", "amount": 0}]})
	_check(roster.is_valid() and roster.get_capacity() == 4 and roster.get_enemies().size() == 3,
		"AC1 precondition: explicitly opted-in roster has exactly one free slot")
	if not roster.is_valid():
		return
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	# Rehearse the same real deck shuffle and weighted scheduler on a copied RNG.
	# Choose a seed where both peers Block, isolating the Moth's birth phase.
	var found := {}
	for seed_value in range(1, 1501):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		var fight_id := ""
		for node_id in map.get_legal_choices():
			if map.get_node(node_id).get("type") == "Fight":
				fight_id = node_id
				break
		if fight_id.is_empty() or not map.choose_node(fight_id):
			continue
		var witness_rng := RandomNumberGenerator.new()
		witness_rng.seed = rng.seed
		witness_rng.state = rng.state
		var pre_bind_state: int = witness_rng.state
		var admission_deck := CombatDeck.new([], witness_rng)
		admission_deck.draw_pile.assign(app._load_starter_deck())
		admission_deck._shuffle_draw_pile()
		var scheduler := CombatEnemyIntents.new(slots)
		if not scheduler.bind_battle(CombatEnemies.new(definitions, 4),
				CombatParty.new(app._load_party_definitions()), witness_rng):
			continue
		var announced: Array = scheduler.get_intents()
		if announced.size() == 3 and announced[0].get("type") == "summon" \
				and announced[1].get("type") == "block" and announced[2].get("type") == "block":
			found = {"rng": rng, "map": map, "seed": seed_value,
				"before_shuffle": pre_bind_state}
			break
	_check(not found.is_empty(),
		"AC1 precondition: a reproducible seeded live-input battle announces weighted Summon with two harmless peer beats")
	if found.is_empty():
		app.free()
		return
	app.run_map = found.map
	app.run_seed = found.seed
	_check(app._start_battle(found.rng, slots, roster),
		"AC1 precondition: actual app battle boots its real deck, party, weighted scheduler and opt-in roster")
	if app.round_flow == null or app.enemies != roster:
		app.free()
		return
	await process_frame
	await process_frame
	var first: Array = app.enemy_intents.get_intents()
	var stage = app.get_node("LiveEnemyRoster")
	var meters = app.get_node("LiveCombatMeters")
	var gauge: CombatUnravel = app.round_flow._unravel
	_check(app.run_map.get_node(app.run_map.get_current_node_id()).get("type") == "Fight"
		and app.enemy_intents.is_bound() and app.enemy_intents._enemies == roster
		and app.deck.turn_active and first.size() == 3
		and first[0].get("type") == "summon"
		and first[1].get("type") == "block" and first[2].get("type") == "block"
		and stage._labels.size() == 3 and meters.row.get_child_count() == 6
		and app.end_turn_button.is_visible_in_tree() and not app.end_turn_button.disabled,
		"AC1 precondition: three actual puppets and a playable End Turn show the genuine first announcement")
	_check(gauge != null and gauge._bound_enemies == roster
		and app.round_flow._valid_unravel_binding(),
		"AC2 precondition: routed UI shares its real bound Unravel service with the app round flow")
	if gauge == null or not app.round_flow._valid_unravel_binding():
		app.free()
		return
	_check(gauge.apply_unravel(roster, 1, 2) and gauge.apply_unravel(roster, 2, 3)
		and gauge.apply_unravel(roster, 3, 1),
		"AC3 precondition: all three original actors have distinct nonzero live gauges")
	var old_gauges := [gauge.get_snapshot(1), gauge.get_snapshot(2), gauge.get_snapshot(3)]
	var old_roster: Array = roster.get_enemies()
	var old_heroes: Array = app.party.get_heroes()
	var old_rng: int = app.run_rng.state
	# Same fully authored roster at DEFAULT capacity must refuse with no latch/RNG spend.
	var full := CombatEnemies.new(definitions)
	var default_rng := RandomNumberGenerator.new()
	default_rng.seed = app.run_rng.seed
	default_rng.state = found.before_shuffle
	var default_deck := CombatDeck.new([], default_rng)
	default_deck.draw_pile.assign(app._load_starter_deck())
	default_deck._shuffle_draw_pile()
	var default_intents := CombatEnemyIntents.new(slots)
	var default_party := CombatParty.new(app._load_party_definitions())
	var default_bound := default_intents.bind_battle(full, default_party, default_rng)
	_check(default_bound and default_intents.get_intents() == first and full.get_capacity() == 3,
		"AC3 precondition: default-capacity comparison has identical genuine first weighted action")
	if default_bound:
		var no_room_rng: int = default_rng.state
		var no_room_actors: Array = full.get_enemies()
		var no_room_heroes: Array = default_party.get_heroes()
		var no_room := CombatEnemyPhase.new().execute_phase(
			default_party, full, default_intents.get_intents(), null, true)
		_check(no_room.get("ok", false) and full.get_enemies().size() == 3
			and full.get_enemy(1) == no_room_actors[0]
			and full.get_enemy(2).get("id") == no_room_actors[1].id
			and full.get_enemy(3).get("id") == no_room_actors[2].id
			and default_party.get_heroes() == no_room_heroes
			and not no_room.events[0].applied
			and not full.get_enemy(1).has(CombatEnemies.BROODLING_LATCH)
			and default_rng.state == no_room_rng,
			"AC3: full default-three roster refuses birth without latch or extra RNG")
	var button = app.end_turn_button
	button.pressed.emit()
	button.pressed.emit() # A duplicated input before the deferred re-enable is inert.
	await process_frame
	await process_frame
	var born := roster.get_enemy(4)
	_check(roster.get_enemies().size() == 4 and born.get("id") == CombatEnemies.BROODLING_ID
		and born.get("name") == "Moth Broodling" and born.get("hp") == 8
		and born.get("max_hp") == 8 and born.get("block") == 0
		and born.get("position") == 4
		and roster.get_enemy(1).get(CombatEnemies.BROODLING_LATCH) == true
		and roster.get_enemy(2).id == old_roster[1].id
		and roster.get_enemy(3).id == old_roster[2].id
		and roster.get_enemy(2).position == 2 and roster.get_enemy(3).position == 3
		and roster.get_enemy(2).hp == old_roster[1].hp
		and roster.get_enemy(3).hp == old_roster[2].hp,
		"AC1: one and only one 8 HP, zero Block fourth-position child follows real End Turn; peers stay put")
	_check(app.party.get_heroes().map(func(hero): return hero.get("hp")) ==
		old_heroes.map(func(hero): return hero.get("hp")),
		"AC1: the newborn cannot strike on its birth turn with only harmless peer beats")
	var next_actions: Array = app.enemy_intents.get_intents()
	_check(next_actions.size() == 4 and next_actions[3] == {
			"enemy_position": 4, "type": "attack", "amount": 5, "target_position": 1}
		and app.enemy_attacks == next_actions and app.enemy_intents.is_bound()
		and app.run_rng.state != old_rng
		and app.round_flow._valid_bindings() and app.battle_result.get_outcome() == CombatBattleResult.ACTIVE
		and not app.result_label.visible,
		"AC2: fourth attack is cached for NEXT round and the real battle result remains ACTIVE")
	_check(gauge.get_snapshot(1) == old_gauges[0] and gauge.get_snapshot(2) == old_gauges[1]
		and gauge.get_snapshot(3) == old_gauges[2] and gauge.get_snapshot(4) == {
			"gauge": 0, "threshold": CombatUnravel.THRESHOLD_NORMAL,
			"unravelled": false, "skip_pending": false},
		"AC2/AC3: the child's clean normal Unravel gauge is admitted without changing any peer charge")
	var meter = meters.row.get_child(6) as CombatActorMeter if meters.row != null and meters.row.get_child_count() == 7 else null
	var thread := meter.get_node("Padding/Content/UnravelThread") as ProgressBar if meter != null else null
	var fraction := thread.get_node("ThreadFraction") as Label if thread != null else null
	_check(stage._labels.size() == 4 and stage._labels[3].text == "Moth Broodling"
		and stage._puppets.size() == 7 and stage._puppets[6].actor_id == CombatEnemies.BROODLING_ID,
		"AC2: fourth named enemy puppet has correct authoritative ID and label")
	_check(stage._badges.size() == 4 and stage._badges[3].source_position == 4
		and stage._badges[3].intent_type == "attack",
		"AC2: fourth puppet shows its genuine next attack badge")
	_check(meter != null and meter.hp_bar.value == 8 and meter.hp_bar.max_value == 8
		and meter.hp_text.text == "8/8" and meter.is_visible_in_tree(),
		"AC2: fourth enemy has a mounted 8/8 HP ribbon: " +
		(str([meter.hp_bar.value, meter.hp_bar.max_value, meter.hp_text.text])
			if meter != null else "no meter"))
	_check(thread != null and thread.visible and fraction != null and fraction.text == "0/8",
		"AC2: fourth enemy has its own visible clean 0/8 Unravel gauge: " +
		(str([thread.visible, fraction.text if fraction != null else "no fraction"])
			if thread != null else "no thread"))
	_check(meter != null and meter._valid_snapshot(born, "enemy")
		and not meter._valid_snapshot(born, "hero")
		and not meter._valid_snapshot(born.merged({"position": 5}, true), "enemy"),
		"AC3: position four is an enemy-only meter slot; hero four and enemy five still fail closed")
	var after_birth := [roster.get_enemies(), app.party.get_heroes(),
		gauge.get_snapshot(1), gauge.get_snapshot(2),
		gauge.get_snapshot(3), gauge.get_snapshot(4), app.run_rng.state,
		app.enemy_intents.get_intents()]
	_check(roster.stage_broodling(1) == {"ok": true, "spawned": false}
		and after_birth == [roster.get_enemies(), app.party.get_heroes(),
			gauge.get_snapshot(1), gauge.get_snapshot(2),
			gauge.get_snapshot(3), gauge.get_snapshot(4), app.run_rng.state,
			app.enemy_intents.get_intents()],
		"AC3: latched mother refuses repeat birth without touching any actors, gauges, intents or RNG")
	# A stale announcement must be refused by the genuine button callback.
	app.enemy_attacks = first.duplicate(true)
	button.pressed.emit()
	_check(after_birth == [roster.get_enemies(), app.party.get_heroes(),
			gauge.get_snapshot(1), gauge.get_snapshot(2),
			gauge.get_snapshot(3), gauge.get_snapshot(4), app.run_rng.state,
			app.enemy_intents.get_intents()],
		"AC3: stale mounted End Turn is fail-closed, with no RNG or gauge change")
	app.enemy_attacks = next_actions
	# Validate the next legitimate phase with a detached oracle, then commit only
	# through the same on-screen control (never feed staged actions into the app).
	var oracle_party := CombatParty.new(app._load_party_definitions())
	oracle_party._heroes.assign(app.party.get_heroes())
	var oracle_enemies := CombatEnemies.new(definitions, CombatEnemies.OPT_IN_MAX_ENEMIES)
	oracle_enemies._enemies.assign(roster.get_enemies())
	var next_phase := CombatEnemyPhase.new().execute_phase(
		oracle_party, oracle_enemies, next_actions, null, true, null, app.session_gold)
	_check(next_phase.get("ok", false) and next_phase.events.size() == 4
		and next_phase.events[3].applied and next_phase.events[3].enemy_position == 4,
		"AC2 precondition: authentic cached child attack actually resolves in the next enemy phase")
	button.pressed.emit()
	await process_frame
	await process_frame
	_check(app.party.get_heroes() == oracle_party.get_heroes()
		and app.session_gold == next_phase.get("gold")
		and app.round_flow.get_gold() == next_phase.get("gold")
		and app.battle_result.get_outcome() == CombatBattleResult.ACTIVE
		and roster.get_enemies().size() == 4,
		"AC2: following real End Turn commits the newborn attack exactly once, not on birth")
	app.free()


## A committed final-Boss entry and genuine bound round (not a forged
## single-action summon) exercise the Queen's own weighted RNG.
## Both authentic parents must pass the real bound scheduler/phase refusal and
## capacity contract, not a forged summon-only intent in a model fixture.
func _queen_phase_refusals() -> void:
	for count in [2, 3]:
		var f := _fixture(8120 + count, count, true)
		_check(not f.is_empty() and f.intents.is_bound()
			and f.intents.get_intents().size() == count
			and f.intents.get_intents()[0].get("type") == "summon",
			"precondition: full Queen weighted spec announces a real summon")
		if f.is_empty():
			continue
		var before := [f.party.get_heroes(), f.enemies.get_enemies(),
			f.intents.get_intents(), f.rng.state]
		var phase := CombatEnemyPhase.new().execute_phase(
			f.party, f.enemies, f.intents.get_intents(), null, true)
		_check(phase.get("ok", false) and f.rng.state == before[3],
			"Queen phase is executable and does not draw run RNG")
		if count == 3:
			_check(f.enemies.get_enemies() == before[1]
				and not phase.events[0].applied and f.intents.get_intents() == before[2],
				"full-slot Queen is inert; cached phase and latch untouched")
		else:
			_check(f.enemies.get_enemies().size() == 3
				and f.enemies.get_enemy(3).id == CombatEnemies.BROODLING_ID
				and f.enemies.get_enemy(1).get(CombatEnemies.BROODLING_LATCH) == true
				and phase.events[0].applied
				and f.party.get_heroes() == before[0]
				and f.intents.get_intents() == before[2],
				"Queen birth commits one child without changing the current announcement")
			_check(f.intents.advance_turn() and f.intents.get_intents().size() == 3
				and f.intents.get_intents()[2] == {"type": "attack", "amount": 5,
					"enemy_position": 3, "target_position": 1},
				"Queen's child first attacks on the following announced turn")
	for mode in ["slain", "forged", "bad_latch", "bad_weight"]:
		var f := _fixture(8202, 2, true)
		if f.is_empty():
			_check(false, "precondition: Queen forged-source fixture exists")
			continue
		match mode:
			"slain":
				_check(f.enemies.apply_damage(1, f.enemies.get_enemy(1).hp),
					"precondition: Queen is actually slain")
			"forged":
				f.enemies._enemies[0]["id"] = "not_queen"
			"bad_latch":
				f.enemies._enemies[0][CombatEnemies.BROODLING_LATCH] = "true"
			"bad_weight":
				f.enemies._enemies[0]["intent"]["actions"][1]["weight"] = 3
		var before := [f.party.get_heroes(), f.enemies.get_enemies(),
			f.intents.get_intents(), f.rng.state]
		var result := CombatEnemyPhase.new().execute_phase(
			f.party, f.enemies, f.intents.get_intents(), null, true)
		if mode == "slain":
			_check(result.get("ok", false) and not result.events[0].applied,
				"slain Queen's genuine summon is inert")
		else:
			_check(result == {"ok": false, "events": []},
				"forged/malformed Queen source refuses entire phase: " + mode)
		_check(before == [f.party.get_heroes(), f.enemies.get_enemies(),
			f.intents.get_intents(), f.rng.state],
			"slain/forged Queen refusal preserves heroes/roster/cache/RNG: " + mode)


func _queen_round_case() -> Array:
	var found := {}
	for value in range(1, 401):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		var route_ok := true
		for floor in range(RunMap.FLOOR_COUNT):
			var legal := map.get_legal_choices()
			if legal.is_empty() or not map.choose_node(legal[0]):
				route_ok = false
				break
		if not route_ok:
			continue
		var selector := RunFightEncounterSelection.new()
		var entry := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, selector)
		if entry.get("success", false) and entry.get("encounter_id") == "moth_queen":
			# Replay the actual admission shuffle and weighted draw on a
			# detached generator, selecting a witness that summons on turn one.
			var witness_rng := RandomNumberGenerator.new()
			witness_rng.seed = rng.seed
			witness_rng.state = rng.state
			var witness_deck := CombatDeck.new(StarterCards.new().get_starting_deck(), witness_rng)
			var witness_party := CombatParty.new([
				{"id": "warden", "max_hp": 40},
				{"id": "seamstress", "max_hp": 30},
				{"id": "tinker", "max_hp": 26}])
			var witness_enemies := CombatEnemies.new(entry.enemies.get_enemies())
			var witness_intents := CombatEnemyIntents.new(entry.definitions)
			if not witness_deck.draw_pile.is_empty() and witness_intents.bind_battle(
				witness_enemies, witness_party, witness_rng) \
				and witness_intents.get_intents().size() == 1 \
				and witness_intents.get_intents()[0].get("type") == "summon":
				found = {"entry": entry, "rng": rng, "map": map}
				break
	_check(not found.is_empty(), "precondition: real seeded final Boss chooses Queen")
	if found.is_empty():
		return []
	var enemies: CombatEnemies = found.entry.enemies
	var actor := enemies.get_enemy(1)
	_check(enemies.get_enemies().size() == 1 and actor.id == "moth_queen"
		and actor.hp == 90 and CombatEnemies.authentic_broodling_mother(actor, 1),
		"authentic Queen enters as sole boss with full HP and weighted summon")
	var party := CombatParty.new([{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30}, {"id": "tinker", "max_hp": 26}])
	var rng: RandomNumberGenerator = found.rng
	var deck := CombatDeck.new(StarterCards.new().get_starting_deck(), rng)
	var scheduler: CombatEnemyIntents = found.entry.intents
	var outcome := CombatBattleResult.new(party, enemies)
	var gauge := CombatUnravel.new()
	_check(gauge.bind_roster(enemies, {1: "boss"}), "boss gauge binds Queen")
	var flow := CombatRoundFlow.new(deck, party, enemies, scheduler, outcome, gauge)
	_check(scheduler.bind_battle(enemies, party, rng) and flow.begin_fight() and scheduler.is_bound(), "real Queen round flow mounts")
	if not scheduler.is_bound():
		return []
	var summoned := false
	for turn in range(80):
		var selected := scheduler.get_intents()
		if selected.size() != 1:
			break
		var birth: bool = selected[0].get("type") == "summon"
		var before := party.get_heroes()
		if not flow.end_turn():
			break
		if birth:
			summoned = true
			_check(party.get_hero(1).hp == before[0].hp
				and party.get_hero(2).hp == before[1].hp
				and party.get_hero(3).hp == before[2].hp
				and gauge.get_snapshot(2).get("threshold") == CombatUnravel.THRESHOLD_NORMAL
				and enemies.get_enemies().size() == 2
				and enemies.get_enemy(1).get(CombatEnemies.BROODLING_LATCH) == true
				and enemies.get_enemy(2).id == CombatEnemies.BROODLING_ID
				and enemies.get_enemy(2).hp == 8 and enemies.get_enemy(2).position == 2,
				"Queen summon adds real child only after the parent phase")
			_check(scheduler.get_intents().size() == 2
				and scheduler.get_intents()[1] == {"enemy_position": 2,
					"type": "attack", "amount": 5, "target_position": 1},
				"next announced turn holds the newborn's authentic attack-5")
			break
	_check(summoned, "authentic weighted Queen selects summon before battle ends")
	if not summoned:
		return []
	var hp: int = party.get_hero(1).hp
	_check(flow.end_turn() and party.get_hero(1).hp <= hp - 5,
		"Queen child attacks on later real round, not the birth round")
	var before_roster := enemies.get_enemies()
	_check(enemies.stage_broodling(1) == {"ok": true, "spawned": false}
		and enemies.get_enemies() == before_roster,
		"Queen once-only latch blocks a duplicate spawn")
	return [party.get_heroes(), enemies.get_enemies(), scheduler.get_intents(),
		deck.hand.duplicate(), deck.draw_pile.duplicate(), deck.discard_pile.duplicate(),
		rng.state, outcome.get_outcome()]


func _run() -> void:
	_phase_cases()
	_queen_phase_refusals()
	var queen_first := _queen_round_case()
	var queen_replay := _queen_round_case()
	_check(not queen_first.is_empty() and queen_first == queen_replay,
		"independent genuine Queen boss rounds and child replays are identical")
	await _mounted_routed_fight()
	await _mounted_fourth_slot_input()
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
