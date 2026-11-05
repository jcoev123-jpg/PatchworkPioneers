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
		"res://data/enemies/starter_enemies.json"))
	var guards := records.filter(func(actor): return actor.id == "ragling_guard")
	var raglings := records.filter(func(actor): return actor.id == "ragling")
	_check(guards.size() == 1 and raglings.size() == 1, "original actors parse uniquely")
	if guards.size() != 1 or raglings.size() != 1:
		return
	var guard: Dictionary = guards[0]
	_check(guard.name == "Guard Ragling" and guard.max_hp == 12
		and guard.art_path == "res://assets/paper/enemies/ragling_guard.png"
		and guard.intent.target == "front", "original Guard identity and target preserved")
	var expected := [{"type": "block", "amount": 5, "weight": 3},
		{"type": "shove", "amount": 0, "direction": 1, "weight": 2},
		{"type": "attack", "amount": 6, "weight": 1},
		{"type": "attack", "amount": 7, "weight": 1, "move": "attack2"}]
	_check(_ints(guard.intent.actions) == expected, "exact two attacks and preserved nonattacks")
	var total := 0
	for raw in guard.intent.actions:
		var parsed := CombatEnemyIntents.weighted_action(raw)
		_check(not parsed.is_empty(), "each parsed weighted alternative is executable")
		total += int(parsed.get("weight", 0))
	_check(total == 7, "total weight remains seven")
	# S5 appends an authored Stitched profile to every canonical enemy; this legacy
	# record check keeps every card-era field exact, and the S5 catalog test owns the
	# new profile.
	var legacy_ragling: Dictionary = raglings[0].duplicate(true)
	legacy_ragling.erase("stitched")
	_check(_ints(legacy_ragling) == {"id": "ragling", "name": "Ragling", "max_hp": 12,
		"art_path": "res://assets/paper/enemies/ragling.png",
		"intent": {"target": "front", "actions": [{"type": "attack", "amount": 5, "weight": 3}]}},
		"unrelated Ragling record is unchanged")

func _fixture() -> Dictionary:
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
				if ids.size() == 2 and ids.has("ragling_guard") and ids.has("ragling"):
					return {"seed": seed_value, "node": node, "ids": ids,
						"encounter": entry.encounter_id}
			break
	return {}

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
	await _click(preload("res://tests/legacy_card_app_fixture.gd").route_button(app))
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
	var source: int = fixture.ids.find("ragling_guard") + 1
	var presenter = app.get_node("LiveEnemyRoster")
	var seen := {}
	var trace := []
	for turn in range(64):
		# Keep both genuine sources alive; restore recipients for bounded observation.
		for hero in app.party._heroes:
			hero.hp = hero.max_hp
			hero.block = 0
			hero.statuses = {}
		var action: Dictionary = app.enemy_intents.get_intents()[source - 1]
		if action.type == "attack":
			var bash: bool = action.get("move", "") == "attack2"
			var name := "Shield Bash" if bash else "Needle Jab"
			_check(action.amount == (7 if bash else 6) and action.target_position == 1
				and not app.party.is_downed(1), "authenticated amount and announced living front hero")
			_check(app.party.gain_block(1, 8), "recipient gains real Block before phase")
			app._refresh_enemy_roster()
			var before := _snapshot(app)
			var fallback := "res://assets/paper/enemies/ragling_guard_attack.png"
			var pose := LiveMovePoseCatalog.new().lookup_enemy("ragling_guard", action, fallback)
			var missing := MissingPoseCatalog.new().lookup_enemy("ragling_guard", action, fallback)
			_check(pose.get("name") == name and pose.get("pose") == ("attack2" if bash else "attack")
				and presenter._badges[source - 1].tooltip_text.contains(name), "mounted named move projection")
			_check(pose.get("named_art") == "res://assets/paper/enemies/ragling_guard_%s.png" % pose.get("pose")
				and pose.get("art") == (pose.get("named_art") if pose.get("art_available") else fallback)
				and missing.get("name") == name and missing.get("fallback_used") == true
				and missing.get("art") == fallback, "existing named pose and forced missing-art fallback")
			_check(_snapshot(app) == before, "presentation changes no combat, wallet or RNG state")
			if not seen.has(name):
				var cache: Array = app.enemy_intents._cache.duplicate(true)
				var spec: Dictionary = app.enemies._enemies[source - 1].intent.duplicate(true)
				for refusal in ["amount", "move", "stale"]:
					if refusal == "amount":
						app.enemy_intents._cache[source - 1].amount += 1
					elif refusal == "move":
						app.enemy_intents._cache[source - 1].move = "attack4"
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
		if seen.has("Needle Jab") and seen.has("Shield Bash"):
			break
	_check(seen.has("Needle Jab") and seen.has("Shield Bash"), "seeded mounted selection reaches both attacks")
	# A dead original source's authentic named announcement is inert, including wallet/RNG.
	_check(app.enemies.apply_damage(source, 9999) and app.enemies.is_slain(source), "kill real Guard source")
	var dead_before := _snapshot(app)
	var dead_action := {"enemy_position": source, "type": "attack", "amount": 7,
		"move": "attack2", "target_position": 1}
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
	var fixture := _fixture()
	_check(not fixture.is_empty(), "production seeded entry reaches original two-source pair")
	if not fixture.is_empty():
		var first := await _mounted(fixture)
		var replay := await _mounted(fixture)
		_check(not first.is_empty() and first == replay, "full mounted announcements, damage, deck, gold and RNG replay")
	for failure in failures:
		printerr(failure)
	print("guard_ragling_named_attack_test: %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
