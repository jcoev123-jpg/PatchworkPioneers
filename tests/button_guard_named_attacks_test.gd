extends SceneTree
## Real catalog -> typed floor-band entry -> mounted hand/End Turn, replayed.

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
	var guards := records.filter(func(actor): return actor.id == "button_guard")
	_check(guards.size() == 1, "Button Guard parses uniquely")
	if guards.size() != 1:
		return
	var guard: Dictionary = guards[0]
	_check(guard.name == "Button Guard" and guard.max_hp == 16
		and guard.art_path == "res://assets/paper/enemies/button_guard.png"
		and guard.intent.target == "front", "original Guard identity and target preserved")
	var expected := [{"type": "attack", "amount": 5, "weight": 1},
		{"type": "attack", "amount": 6, "weight": 1, "move": "attack2"},
		{"type": "attack", "amount": 7, "weight": 1, "move": "attack3"},
		{"type": "block", "amount": 2, "weight": 2},
		{"type": "debuff", "amount": 1, "status": "exposed", "weight": 1},
		{"type": "shove", "amount": 0, "direction": 1, "weight": 1}]
	_check(_ints(guard.intent.actions) == expected, "exact three attacks and preserved nonattacks")
	var total := 0
	for raw in guard.intent.actions:
		var parsed := CombatEnemyIntents.weighted_action(raw)
		_check(not parsed.is_empty(), "each parsed weighted alternative is executable")
		total += int(parsed.get("weight", 0))
	_check(total == 7, "total weight remains seven")

func _fixture(count: int = 2) -> Dictionary:
	# Search only authentic generated opening routes and production floor bands.
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
				if ids.size() == count and ids.has("button_guard") and (count == 3 or ids.has("ragling")):
					return {"seed": seed_value, "node": node, "ids": ids,
						"encounter": entry.encounter_id}
			break
	return {}

func _three_source() -> void:
	var fixture := _fixture(3)
	_check(not fixture.is_empty(), "production floor-band entry reaches three living foes with Button Guard")
	if fixture.is_empty():
		return
	var traces := []
	for replay in range(2):
		var rng := RandomNumberGenerator.new()
		rng.seed = fixture.seed
		var map := RunMap.new()
		_check(map.generate(rng) and map.choose_node(fixture.node), "three-source real route commits")
		var entry := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
		_check(entry.get("success", false), "three-source real entry succeeds")
		if not entry.get("success", false):
			return
		var enemies: CombatEnemies = entry.enemies
		var party := CombatParty.new(RunTypedBattleRoster._parse_catalog_text(
			FileAccess.get_file_as_string("res://data/heroes/starter_party.json")))
		var scheduler: CombatEnemyIntents = entry.intents
		_check(party.is_valid() and enemies.is_valid() and enemies.get_enemies().size() == 3,
			"real three-source roster and living party are valid")
		_check(scheduler.bind_battle(enemies, party, rng), "three-source weighted schedule binds to run RNG")
		var source: int = fixture.ids.find("button_guard") + 1
		var seen := {}
		var trace := []
		for turn in range(64):
			var actions := scheduler.get_intents()
			_check(actions.size() == 3 and not enemies.is_slain(source), "all three living sources announce")
			var action: Dictionary = actions[source - 1]
			if action.has("move"):
				_check(action.type == "attack" and action.target_position == 1
					and action.amount == (6 if action.move == "attack2" else 7), "three-source keyed front attack")
				# Resolve the authentic source separately so companion actions cannot mask an extra hit.
				for block in [3, 8]:
					_check(party.gain_block(1, block), "real front hero gains Block")
					var hp: int = party.get_hero(1).hp
					var others := [party.get_hero(2), party.get_hero(3)]
					var roster := enemies.get_enemies()
					var rng_before := rng.state
					var result := CombatEnemyPhase.new().execute_phase(party, enemies, [action], null, true, null, 19)
					_check(result.get("ok") == true and result.get("events", []).size() == 1
						and result.events[0].get("applied") == true and result.get("gold") == 19,
						"one authentic named event preserves gold")
					_check(party.get_hero(1).hp == hp - maxi(0, int(action.amount) - block)
						and party.get_hero(1).block == maxi(0, block - int(action.amount))
						and [party.get_hero(2), party.get_hero(3)] == others
						and enemies.get_enemies() == roster and rng.state == rng_before,
						"exact once-only named hit consumes Block before HP with no collateral or RNG draw")
					trace.append([action.duplicate(true), party.get_heroes(), rng.state])
					party._heroes[0].hp = hp
					party._heroes[0].block = 0
				seen[action.move] = true
			if seen.has("attack2") and seen.has("attack3"):
				break
			_check(scheduler.advance_turn(), "three-source seeded scheduler advances")
		_check(seen.has("attack2") and seen.has("attack3"), "three-source seeded Fight selects both keyed attacks")
		traces.append(trace)
	_check(not traces[0].is_empty() and traces[0] == traces[1], "three-source damage and announcements replay exactly")

func _click(button: Control) -> void:
	_check(is_instance_valid(button) and button.is_visible_in_tree(), "mouse action is reachable")
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
		app.deck.energy, app.deck.turn_active, app.enemy_intents.get_intents(),
		app.enemy_intents._turn_index]

func _mounted(fixture: Dictionary) -> Array:
	var scene: PackedScene = load("res://scenes/app.tscn")
	_check(scene != null, "real app scene loads")
	if scene == null:
		return []
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	app.run_seed = fixture.seed
	await _click(app.route_button)
	var route: Button
	for candidate in app.route_buttons:
		if candidate.get_meta("route_id") == fixture.node:
			route = candidate
	_check(route != null, "genuine generated Fight has a route button")
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
		and app.deck.hand.size() == 5, "typed two-source group binds into real shared hand")
	var source: int = fixture.ids.find("button_guard") + 1
	var presenter = app.get_node("LiveEnemyRoster")
	var seen := {}
	var trace := []
	for turn in range(64):
		# Keep both genuine sources alive; restore recipients for bounded observation.
		for hero in app.party._heroes:
			hero.hp = hero.max_hp
			hero.block = 0
			hero.statuses = {}
		var detached: Array = app.enemy_intents.get_intents()
		var authentic: Array = detached.duplicate(true)
		detached[source - 1].amount = 999
		_check(app.enemy_intents.get_intents() == authentic, "returned announcements are detached")
		var action: Dictionary = authentic[source - 1]
		if action.type == "attack" and action.has("move"):
			var toss: bool = action.get("move", "") == "attack2"
			var name := "Button Toss" if toss else "Pin Thrust"
			_check(action.amount == (6 if toss else 7) and action.target_position == 1
				and not app.party.is_downed(1), "authenticated amount and announced living front hero")
			_check(app.party.gain_block(1, 8), "recipient gains real Block before phase")
			app._refresh_enemy_roster()
			var before := _snapshot(app)
			var fallback := "res://assets/paper/enemies/button_guard_attack.png"
			var pose := LiveMovePoseCatalog.new().lookup_enemy("button_guard", action, fallback)
			var missing := MissingPoseCatalog.new().lookup_enemy("button_guard", action, fallback)
			_check(pose.get("name") == name and pose.get("pose") == ("attack2" if toss else "attack3")
				and presenter._badges[source - 1].tooltip_text.contains(name), "mounted named move projection")
			_check(pose.get("named_art") == "res://assets/paper/enemies/button_guard_%s.png" % pose.get("pose")
				and pose.get("art") == (pose.get("named_art") if pose.get("art_available") else fallback)
				and missing.get("name") == name and missing.get("fallback_used") == true
				and missing.get("art") == fallback, "existing named pose and forced missing-art fallback")
			_check(_snapshot(app) == before, "presentation changes no combat, wallet or RNG state")
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
							if raw.get("move", "") == action.get("move", "") and raw.type == "attack":
								raw.amount += 1
					var protected := _snapshot(app)
					_check(not app.round_flow.end_turn() and _snapshot(app) == protected,
						"forged/stale action refused atomically: " + refusal)
					app.enemy_intents._cache.assign(cache.duplicate(true))
					app.enemies._enemies[source - 1].intent = spec.duplicate(true)
			var hp: int = app.party.get_hero(1).hp
			var others := [app.party.get_hero(2), app.party.get_hero(3)]
			await _click(app.end_turn_button)
			_check(app.party.get_hero(1).hp == hp - (5 + int(action.amount) - 8)
				and app.party.get_hero(1).block == 0
				and [app.party.get_hero(2), app.party.get_hero(3)] == others,
				"real two-source phase resolves Ragling 5 plus named attack once, Block first")
			seen[name] = true
		else:
			await _click(app.end_turn_button)
		trace.append(_snapshot(app))
		if seen.has("Button Toss") and seen.has("Pin Thrust"):
			break
	_check(seen.has("Button Toss") and seen.has("Pin Thrust"), "seeded mounted selection reaches both attacks")
	# A dead original source's authentic named announcement is inert, including wallet/RNG.
	_check(app.enemies.apply_damage(source, 9999) and app.enemies.is_slain(source), "kill real Guard source")
	var dead_before := _snapshot(app)
	var dead_action := {"enemy_position": source, "type": "attack", "amount": 7,
		"move": "attack3", "target_position": 1}
	var result := CombatEnemyPhase.new().execute_phase(app.party, app.enemies,
		[dead_action], null, true, null, app.round_flow.get_gold())
	_check(result.get("ok") == true and result.get("events", []).size() == 1
		and result.events[0].get("applied") == false
		and result.get("gold") == app.round_flow.get_gold() and _snapshot(app) == dead_before,
		"dead named source changes no HP, Block, wallet or RNG")
	app.free()
	return trace

func _run() -> void:
	root.size = Vector2i(1280, 720)
	_catalog()
	_three_source()
	var fixture := _fixture()
	_check(not fixture.is_empty(), "production seeded entry reaches original two-source pair")
	if not fixture.is_empty():
		var first := await _mounted(fixture)
		var replay := await _mounted(fixture)
		_check(not first.is_empty() and first == replay, "full mounted announcements, damage, deck, gold and RNG replay")
	for failure in failures:
		printerr(failure)
	print("button_guard_named_attacks_test: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
