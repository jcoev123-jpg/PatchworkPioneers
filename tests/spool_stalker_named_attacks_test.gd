extends SceneTree
## Shipped data -> seeded floor-band route -> real hand and End Turn.

class MissingPoseCatalog extends LiveMovePoseCatalog:
	func _art_available(_path: String) -> bool:
		return false

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _ints(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = _ints(value[key])
		return result
	if value is Array:
		return value.map(_ints)
	if value is float and is_finite(value) and floorf(value) == value:
		return int(value)
	return value

func _catalog() -> void:
	var records := RunTypedBattleRoster._parse_catalog_text(FileAccess.get_file_as_string(
		"res://data/enemies/run_enemies.json"))
	var stalkers := records.filter(func(actor): return actor.id == "spool_stalker")
	_check(stalkers.size() == 1, "shipped Stalker parses uniquely")
	if stalkers.size() != 1:
		return
	var actor: Dictionary = stalkers[0]
	_check(actor.name == "Spool Stalker" and actor.max_hp == 14
		and actor.art_path == "res://assets/paper/enemies/spool_stalker.png"
		and actor.intent.target == "exposed", "identity, HP and exposed target preserved")
	var expected := [{"type": "attack", "amount": 5, "weight": 1},
		{"type": "attack", "amount": 6, "weight": 1, "move": "attack2"},
		{"type": "attack", "amount": 7, "weight": 1, "move": "attack3"},
		{"type": "block", "amount": 2, "weight": 2},
		{"type": "debuff", "amount": 1, "status": "exposed", "weight": 2},
		{"type": "buff", "amount": 2, "weight": 1}]
	_check(_ints(actor.intent.actions) == expected, "exact attacks and unchanged nonattacks")
	var total := 0
	for raw in actor.intent.actions:
		var parsed := CombatEnemyIntents.weighted_action(raw)
		_check(not parsed.is_empty(), "each authored alternative validates")
		total += int(parsed.get("weight", 0))
	_check(total == 8, "total weight stays eight")

func _fixture(count: int) -> Dictionary:
	for seed_value in range(1, 1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		for node in map.get_legal_choices():
			if map.get_node(node).get("type") != "Fight":
				continue
			if not map.choose_node(node):
				break
			var entry := RunAuthoredBattleEntry.new().entry_current_battle(
				map, rng, RunFightEncounterSelection.new())
			if entry.get("success", false):
				var ids: Array = entry.enemies.get_enemies().map(func(actor): return actor.id)
				if ids.size() == count and ids.has("spool_stalker"):
					return {"seed": seed_value, "node": node, "ids": ids,
						"encounter": entry.encounter_id}
			break
	return {}

func _click(button: Control) -> void:
	_check(is_instance_valid(button) and button.is_visible_in_tree(), "mouse action reachable")
	if not is_instance_valid(button) or not button.is_visible_in_tree():
		return
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func _snapshot(app) -> Array:
	return [app.party.get_heroes(), app.enemies.get_enemies(), app.run_rng.state,
		app.round_flow.get_gold(), app.session_gold, app.deck.hand.duplicate(),
		app.deck.draw_pile.duplicate(), app.deck.discard_pile.duplicate(),
		app.deck.exhausted.duplicate(), app.deck.energy, app.deck.turn_active,
		app.enemy_intents.get_intents(), app.enemy_intents._turn_index]

func _three_source(fixture: Dictionary) -> void:
	var traces := []
	for replay in range(2):
		var rng := RandomNumberGenerator.new()
		rng.seed = fixture.seed
		var map := RunMap.new()
		_check(map.generate(rng) and map.choose_node(fixture.node), "three-source route commits")
		var entry := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
		_check(entry.get("success", false), "three-source entry succeeds")
		if not entry.get("success", false):
			return
		var enemies: CombatEnemies = entry.enemies
		var party := CombatParty.new(RunTypedBattleRoster._parse_catalog_text(
			FileAccess.get_file_as_string("res://data/heroes/starter_party.json")))
		party._heroes[1].statuses = {"exposed": 2}
		var scheduler: CombatEnemyIntents = entry.intents
		_check(party.is_valid() and enemies.is_valid() and enemies.get_enemies().size() == 3,
			"genuine three living sources and valid party")
		_check(scheduler.bind_battle(enemies, party, rng), "bind shipped weighted actions to run RNG")
		var source: int = fixture.ids.find("spool_stalker") + 1
		var seen := {}
		var trace := []
		for turn in range(80):
			var actions := scheduler.get_intents()
			_check(actions.size() == 3 and enemies.get_enemies().all(func(actor): return actor.hp > 0),
				"all three actual foes remain living and announcing")
			var action: Dictionary = actions[source - 1]
			if action.type == "attack" and action.has("move"):
				_check(action.move in ["attack2", "attack3"] and action.target_position == 2
					and action.amount == (6 if action.move == "attack2" else 7), "seed selects keyed attack against exposed middle")
				var damage := 9 if action.move == "attack2" else 10
				for block in [3, 12]:
					_check(party.gain_block(2, block), "give recipient partial or full absorption Block")
					var hp: int = party.get_hero(2).hp
					var others := [party.get_hero(1), party.get_hero(3)]
					var roster := enemies.get_enemies()
					var rng_before := rng.state
					var receipt := CombatEnemyPhase.new().execute_phase(party, enemies, [action], null, true, null, 19)
					_check(receipt.get("ok") == true and receipt.get("events", []).size() == 1
						and receipt.events[0].get("applied") == true and receipt.get("gold") == 19,
						"exactly one authentic named event, no wallet change")
					_check(party.get_hero(2).hp == hp - maxi(0, damage - block)
						and party.get_hero(2).block == maxi(0, block - damage)
						and [party.get_hero(1), party.get_hero(3)] == others
						and enemies.get_enemies() == roster and rng.state == rng_before,
						"each named move hits once, Block before HP, no collateral or RNG draw")
					trace.append([action.duplicate(true), receipt, party.get_heroes(), rng.state])
					party._heroes[1].hp = hp
					party._heroes[1].block = 0
				seen[action.move] = true
			if seen.has("attack2") and seen.has("attack3"):
				break
			_check(scheduler.advance_turn(), "advance real seeded weighted schedule")
		_check(seen.has("attack2") and seen.has("attack3"), "three-living-foe Fight selects and resolves both moves")
		traces.append(trace)
	_check(not traces[0].is_empty() and traces[0] == traces[1], "three-source announcement/receipt/damage/RNG replay")

func _mounted(fixture: Dictionary) -> Array:
	var scene: PackedScene = load("res://scenes/app.tscn")
	_check(scene != null, "real app scene loads")
	if scene == null:
		return []
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	app.run_seed = fixture.seed
	await _click(preload("res://tests/legacy_card_app_fixture.gd").route_button(app))
	var route: Button
	for candidate in app.route_buttons:
		if candidate.get_meta("route_id") == fixture.node:
			route = candidate
	_check(route != null, "generated Fight has a real route button")
	if route == null:
		app.free()
		return []
	await _click(route)
	for frame in range(3):
		await process_frame
	_check(app.enemies != null and app.enemy_intents != null and app.deck != null,
		"route mounts actual combat models")
	if app.enemies == null or app.enemy_intents == null or app.deck == null:
		app.free()
		return []
	_check(app.encounter_id == fixture.encounter and app.enemy_intents.is_bound()
		and app.enemies.get_enemies().map(func(actor): return actor.id) == fixture.ids
		and fixture.ids.size() in [2, 3] and app.deck.hand.size() == 5,
		"real floor-band group and weighted scheduler bind into shared hand")
	var source: int = fixture.ids.find("spool_stalker") + 1
	var presenter = app.get_node("LiveEnemyRoster")
	# Keep the real entry, RNG, scheduler and hand; isolate the source so a
	# companion's hits/statuses cannot hide duplicated damage in this witness.
	for actor in app.enemies.get_enemies():
		if actor.position != source:
			_check(app.enemies.apply_damage(actor.position, 99999), "isolate admitted Stalker")
	var seen := {}
	var trace := []
	var last_named := {}
	for turn in range(80):
		for hero in app.party._heroes:
			hero.hp = hero.max_hp
			hero.block = 0
			hero.statuses = {}
		app.party._heroes[1].statuses = {"exposed": 2}
		app.enemies._enemies[source - 1].statuses = {}
		var detached: Array = app.enemy_intents.get_intents()
		var authentic: Array = detached.duplicate(true)
		detached[source - 1].amount = 999
		_check(app.enemy_intents.get_intents() == authentic, "announcements are detached")
		var action: Dictionary = authentic[source - 1]
		if action.type == "attack" and action.has("move"):
			last_named = action.duplicate(true)
			var web: bool = action.move == "attack2"
			var name := "Web Spit" if web else "Leg Stab"
			var target: int = action.target_position
			_check(action.move in ["attack2", "attack3"] and action.amount == (6 if web else 7)
				and target in [1, 2] and not app.party.is_downed(target), "authentic keyed amount and living announced recipient")
			var block := 3 if web else 12
			_check(app.party.gain_block(target, block), "recipient has real Block before hit")
			app._refresh_enemy_roster()
			var before := _snapshot(app)
			var fallback := "res://assets/paper/enemies/spool_stalker_attack.png"
			var pose := LiveMovePoseCatalog.new().lookup_enemy("spool_stalker", action, fallback)
			var missing := MissingPoseCatalog.new().lookup_enemy("spool_stalker", action, fallback)
			_check(pose.get("name") == name and pose.get("pose") == action.move
				and presenter._badges[source - 1].tooltip_text.contains(name), "mounted named move projection")
			_check(pose.get("named_art") == "res://assets/paper/enemies/spool_stalker_%s.png" % action.move
				and pose.get("art") == (pose.get("named_art") if pose.get("art_available") else fallback)
				and missing.get("name") == name and missing.get("fallback_used") == true
				and missing.get("art") == fallback, "named art path and forced missing-art fallback")
			_check(_snapshot(app) == before, "presentation leaves combat, wallet and RNG unchanged")
			if not seen.has(name):
				var cache: Array = app.enemy_intents._cache.duplicate(true)
				var spec: Dictionary = app.enemies._enemies[source - 1].intent.duplicate(true)
				for refusal in ["amount", "move", "malformed", "stale"]:
					if refusal == "amount":
						app.enemy_intents._cache[source - 1].amount += 1
					elif refusal == "move":
						app.enemy_intents._cache[source - 1].move = "attack4"
					elif refusal == "malformed":
						app.enemy_intents._cache[source - 1].amount = "6"
					else:
						for raw in app.enemies._enemies[source - 1].intent.actions:
							if raw.get("move", "") == action.move:
								raw.amount += 1
					var protected := _snapshot(app)
					_check(not app.round_flow.end_turn() and _snapshot(app) == protected,
						"forged/stale action refused atomically: " + refusal)
					app.enemy_intents._cache.assign(cache.duplicate(true))
					app.enemies._enemies[source - 1].intent = spec.duplicate(true)
			var hp: int = app.party.get_hero(target).hp
			var others: Array = app.party.get_heroes().filter(func(hero): return hero.position != target)
			var prior_turn: int = app.enemy_intents._turn_index
			await _click(app.end_turn_button)
			# Exposed multiplies the base by 1.5, floored: 6 -> 9, 7 -> 10.
			var damage: int = (9 if web else 10) if target == 2 else int(action.amount)
			_check(app.enemy_intents._turn_index == prior_turn + 1
				and app.party.get_hero(target).hp == hp - maxi(0, damage - block)
				and app.party.get_hero(target).block == 0
				and app.party.get_heroes().filter(func(hero): return hero.position != target).map(func(hero): return [hero.hp, hero.block])
					== others.map(func(hero): return [hero.hp, hero.block]),
				"physical End Turn hits announced recipient once and clears Block on next player turn")
			seen[name] = true
		else:
			await _click(app.end_turn_button)
		trace.append(_snapshot(app))
		if seen.has("Web Spit") and seen.has("Leg Stab"):
			break
	_check(seen.has("Web Spit") and seen.has("Leg Stab"), "seeded mounted selection reaches both attacks")
	if not last_named.is_empty():
		_check(app.enemies.apply_damage(source, 99999) and app.enemies.is_slain(source), "real named source slain")
		var dead_before := _snapshot(app)
		var result := CombatEnemyPhase.new().execute_phase(app.party, app.enemies,
			[last_named], null, true, null, app.round_flow.get_gold())
		_check(result.get("ok") == true and result.get("events", []).size() == 1
			and result.events[0].get("applied") == false
			and result.get("gold") == app.round_flow.get_gold() and _snapshot(app) == dead_before,
			"authentic dead-source action inert: HP, Block, gold, deck and RNG unchanged")
	app.free()
	return trace

func _run() -> void:
	root.size = Vector2i(1280, 720)
	_catalog()
	for count in [2, 3]:
		var fixture := _fixture(count)
		_check(not fixture.is_empty(), "production entry reaches %d-source Stalker Fight" % count)
		if not fixture.is_empty():
			if count == 3:
				_three_source(fixture)
			var first := await _mounted(fixture)
			var replay := await _mounted(fixture)
			_check(not first.is_empty() and first == replay, "mounted announcements/damage/deck/gold/RNG replay")
	for failure in failures:
		printerr(failure)
	print("spool_stalker_named_attacks_test: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
