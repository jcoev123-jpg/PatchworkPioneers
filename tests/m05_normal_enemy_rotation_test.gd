extends SceneTree
## The four M05 normals travel through production catalogs, typed Fight selection,
## seeded weighted phases and a real mounted routed battle.

const POOLS := "res://data/encounters/m03_typed_battle_pools.json"
const CATALOGS := RunAuthoredBattleEntry.CATALOG_PATHS
const NEW := {
	"felt_bulwark": {"name": "Felt Bulwark", "max_hp": 18, "target": "front",
		"actions": [{"type": "attack", "amount": 2, "weight": 3},
			{"type": "block", "amount": 3, "weight": 3},
			{"type": "buff", "amount": 2, "weight": 1}]},
	"moth_scribe": {"name": "Moth Scribe", "max_hp": 14, "target": "exposed",
		"actions": [{"type": "attack", "amount": 2, "weight": 3},
			{"type": "debuff", "amount": 1, "status": "weak", "weight": 2},
			{"type": "block", "amount": 2, "weight": 1}]},
	"pin_skitter": {"name": "Pin Skitter", "max_hp": 13, "target": "random",
		"actions": [{"type": "attack", "amount": 2, "weight": 4},
			{"type": "shove", "amount": 0, "direction": 1, "weight": 1},
			{"type": "block", "amount": 1, "weight": 1}]},
	"thread_biter": {"name": "Thread Biter", "max_hp": 15, "target": "lowest_living_hp",
		"actions": [{"type": "attack", "amount": 3, "weight": 3},
			{"type": "debuff", "amount": 1, "status": "bleed", "weight": 1},
			{"type": "block", "amount": 2, "weight": 1}]},
}
const OLD := {
	"ragling": ["Ragling", 12, "front", [{"type": "attack", "amount": 1, "weight": 3}]],
	"ragling_guard": ["Guard Ragling", 12, "front", [{"type": "block", "amount": 1, "weight": 3}]],
	"fray_scavenger": ["Fray Scavenger", 14, "lowest_living_hp",
		[{"type": "attack", "amount": 3, "weight": 3}, {"type": "block", "amount": 2, "weight": 2},
			{"type": "debuff", "amount": 1, "status": "exposed", "weight": 1}]],
	"button_guard": ["Button Guard", 16, "front",
		[{"type": "attack", "amount": 2, "weight": 3}, {"type": "block", "amount": 2, "weight": 2},
			{"type": "debuff", "amount": 1, "status": "exposed", "weight": 1},
			{"type": "shove", "amount": 0, "direction": 1, "weight": 1}]],
	"spool_stalker": ["Spool Stalker", 14, "exposed",
		[{"type": "attack", "amount": 2, "weight": 3}, {"type": "block", "amount": 2, "weight": 2},
			{"type": "debuff", "amount": 1, "status": "exposed", "weight": 2},
			{"type": "buff", "amount": 2, "weight": 1}]],
	"seam_ripper": ["Seam Ripper", 18, "lowest_living_hp",
		[{"type": "attack", "amount": 4, "weight": 3}, {"type": "block", "amount": 2, "weight": 2},
			{"type": "debuff", "amount": 1, "status": "bleed", "weight": 1},
			{"type": "buff", "amount": 2, "weight": 1}]],
}
const PAIRS := {
	"felt_moth_pressure": {"schedule": "res://data/encounters/bobbin_skirmish.json",
		"enemy_ids": ["felt_bulwark", "moth_scribe"]},
	"pin_thread_crossfire": {"schedule": "res://data/encounters/buttonhole_holdout.json",
		"enemy_ids": ["pin_skitter", "thread_biter"]},
}
const PRIOR := {
	"Fight": {
		"buttonfront_pinfall": ["button_guard", "fray_scavenger"],
		"starter_attacks": ["ragling", "ragling_guard"],
		"bobbin_skirmish": ["fray_scavenger", "spool_stalker"],
		"buttonhole_holdout": ["button_guard", "seam_ripper"],
		"guard_counterattack": ["ragling_guard", "button_guard"],
		"double_hem_siege": ["fray_scavenger", "seam_ripper"],
		"triple_spool_pinch": ["fray_scavenger", "button_guard", "spool_stalker"],
		"seamshift_tripwire": ["seam_ripper", "spool_stalker", "fray_scavenger"],
		"front_hem_pivot": ["button_guard", "fray_scavenger"],
		"rear_spool_reversal": ["spool_stalker", "seam_ripper"],
		"rearline_needlemark": ["fray_scavenger", "seam_ripper"],
		"middlemark_clamp": ["spool_stalker", "seam_ripper"],
		"backhem_pinwheel": ["fray_scavenger", "button_guard", "spool_stalker"],
		"hemdrag_relay": ["seam_ripper", "button_guard"],
		"spoolbridge_staggered_exposure": ["spool_stalker", "seam_ripper"],
		"hemhook_exposed_swap": ["spool_stalker", "seam_ripper", "fray_scavenger"],
	},
	"Elite": {"thimble_crossfire": ["button_guard", "seam_ripper"],
		"needle_marshal_elite": ["needle_marshal", "ragling_guard"],
		"spool_hexer_elite": ["spool_hexer", "spool_stalker"]},
	"Boss": {"patchwork_behemoth": ["patchwork_behemoth"]},
}

var failures: Array[String] = []
var checks := 0
var catalog := {}
var pools := {}

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures.append(reason)

func _rng(value: int) -> RandomNumberGenerator:
	var result := RandomNumberGenerator.new()
	result.seed = value
	return result

func _normalized(value: Variant) -> Variant:
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_normalized(item))
		return result
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = _normalized(value[key])
		return result
	if value is float and is_finite(value) and floorf(value) == value:
		return int(value)
	return value

func _party() -> CombatParty:
	var party := CombatParty.new([
		{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "seamstress", "name": "Seamstress", "max_hp": 30},
		{"id": "tinker", "name": "Tinker", "max_hp": 26},
	])
	_check(party.is_valid() and CombatEnemyIntents.living_positions(party) == [1, 2, 3],
		"genuine three-hero combat authority starts living")
	return party

func _catalog_and_bindings() -> void:
	for path in CATALOGS:
		var raw := FileAccess.get_file_as_string(path)
		var parsed := RunTypedBattleRoster._parse_catalog_text(raw)
		_check(not raw.is_empty() and not parsed.is_empty(), "genuine catalog parses " + path)
		for record in parsed:
			_check(not catalog.has(record.id), "unique enemy ID across all catalogs " + record.id)
			catalog[record.id] = _normalized(record)
	for id in NEW:
		var expected: Dictionary = NEW[id]
		_check(catalog.has(id), "M05 ID present " + id)
		if not catalog.has(id):
			continue
		var record: Dictionary = catalog[id]
		_check(record == {"id": id, "name": expected.name, "max_hp": expected.max_hp,
			"art_path": "res://assets/paper/enemies/" + id + ".png",
			"intent": {"target": expected.target, "actions": expected.actions}},
			"exact new identity, HP, art, policy and ordered weighted actions " + id)
		for raw in expected.actions:
			_check(CombatEnemyIntents.positive_weight(raw.weight) > 0
				and not CombatEnemyIntents.weighted_action(raw).is_empty(),
				"new weighted action is executable " + id + " " + str(raw))
	for id in OLD:
		_check(catalog.has(id), "original normal still present " + id)
		if not catalog.has(id):
			continue
		var old: Array = OLD[id]
		_check(catalog[id] == {"id": id, "name": old[0], "max_hp": old[1],
			"art_path": "res://assets/paper/enemies/" + id + ".png",
			"intent": {"target": old[2], "actions": old[3]}},
			"original normal retains exact full definition " + id)
	pools = JSON.parse_string(FileAccess.get_file_as_string(POOLS))
	_check(pools is Dictionary and pools.get("Fight") is Dictionary
		and pools.get("Elite") is Dictionary and pools.get("Boss") is Dictionary,
		"production typed Fight/Elite/Boss pools parse")
	if not pools is Dictionary or not pools.get("Fight") is Dictionary:
		return
	for id in PAIRS:
		_check(pools["Fight"].get(id) == PAIRS[id], "new named Fight alias exact " + id)
		var definitions := RunFightEncounterSelection._parse_schedule_text(
			FileAccess.get_file_as_string(PAIRS[id].schedule))
		_check(definitions.size() == 2 and definitions[0].enemy_position == 1
			and definitions[1].enemy_position == 2,
			"reused original schedule contains two ordered sources " + id)
	for kind in PRIOR:
		for id in PRIOR[kind]:
			_check(pools[kind].get(id) == {"schedule": "res://data/encounters/" + id + ".json",
				"enemy_ids": PRIOR[kind][id]},
				"unmodified prior typed binding " + kind + "/" + id)

func _choose_fight(map: RunMap) -> String:
	for id in map.get_legal_choices():
		if map.get_node(id).get("type") == "Fight" and map.choose_node(id):
			return id
	return ""

func _assemble(id: String, run_seed: int) -> Dictionary:
	var rng := _rng(run_seed)
	var map := RunMap.new()
	_check(map.generate(rng), "seeded real twelve-floor map created " + id)
	var node := _choose_fight(map)
	_check(not node.is_empty() and map.get_node(node).get("type") == "Fight"
		and map.get_route() == [node], "actual legal current Fight chosen " + id)
	if node.is_empty():
		return {}
	var selector := RunFightEncounterSelection.new()
	var choice := selector.select_current_battle(map, rng, {"Fight": {id: PAIRS[id].schedule}})
	_check(choice.get("success") and choice.get("node_type") == "Fight"
		and choice.get("encounter_id") == id, "real typed selector reaches alias " + id)
	if not choice.get("success", false):
		return {}
	var before := [map.get_floors(), map.get_route(), map.get_legal_choices(),
		rng.state, selector._selected.duplicate(true)]
	var roster := RunTypedBattleRoster.new().assemble(choice, {id: PAIRS[id].enemy_ids}, CATALOGS)
	_check(roster.get("ok") and roster.get("node_type") == "Fight",
		"real typed assembler resolves alias catalogs " + id)
	_check(before == [map.get_floors(), map.get_route(), map.get_legal_choices(),
		rng.state, selector._selected.duplicate(true)],
		"assembly neither spends RNG nor mutates route/selection cache " + id)
	if not roster.get("ok", false):
		return {}
	var expected: Array = PAIRS[id].enemy_ids
	var snapshots: Array = roster.enemies.get_enemies()
	_check(snapshots.size() == 2 and CombatEnemyIntents.new(roster.definitions).is_valid(),
		"two living source slots and valid schedule " + id)
	for index in range(2):
		var actor: Dictionary = roster.enemies.get_enemy(index + 1)
		var authored: Dictionary = NEW[expected[index]]
		_check(actor.get("id") == expected[index] and actor.get("name") == authored.name
			and actor.get("position") == index + 1 and actor.get("hp") == authored.max_hp
			and actor.get("max_hp") == authored.max_hp and actor.get("block") == 0,
			"source identity, HP and slot " + id + "/" + str(index + 1))
	_check(roster.definitions == RunFightEncounterSelection._parse_schedule_text(
		FileAccess.get_file_as_string(PAIRS[id].schedule)),
		"exact pre-existing schedule carried intact " + id)
	var live := RunAuthoredBattleEntry.new()._entry_from_data(map, _rng(981), 
		RunFightEncounterSelection.new(), {"Fight": {id: PAIRS[id]}})
	_check(live.get("success") and live.get("encounter_id") == id
		and live.get("enemies") is CombatEnemies and live.get("intents") is CombatEnemyIntents,
		"live production entry accepts canonical schedule alias " + id)
	return {"choice": choice, "roster": roster, "rng_state": rng.state,
		"floors": map.get_floors(), "route": map.get_route()}

func _weighted(id: String, assembled: Dictionary) -> void:
	if assembled.is_empty():
		return
	var present := {}
	for seed_value in range(1, 161):
		var first: Array = []
		var states: Array = []
		var phase_states: Array = []
		for replay in range(2):
			var party := _party()
			_check(party.apply_damage(3, 21), "Tinker wounded for policy differentiation")
			party._heroes[1]["statuses"] = {"exposed": 2}
			var enemies := CombatEnemies.new(assembled.roster.enemies.get_enemies())
			var rng := _rng(seed_value)
			var scheduler := CombatEnemyIntents.new(assembled.roster.definitions)
			_check(enemies.is_valid() and scheduler.bind_battle(enemies, party, rng),
				"actual authored roster binds weighted intents " + id)
			if not scheduler.is_bound():
				return
			var announced := scheduler.get_intents()
			var committed := rng.state
			_check(announced.size() == 2 and announced == scheduler.get_intents(),
				"cached prediction unchanged on UI-style refresh " + id)
			_check(rng.state == committed, "forecast reads spend zero RNG " + id)
			# Independent RNG oracle: one weighted roll per source, plus only
			# random-policy targeting when that source needs a hero.
			var oracle := _rng(seed_value)
			for index in range(2):
				var spec: Dictionary = NEW[PAIRS[id].enemy_ids[index]]
				var total := 0
				for raw in spec.actions:
					total += raw.weight
				var roll := oracle.randi_range(1, total)
				var picked: Dictionary = {}
				for raw in spec.actions:
					roll -= raw.weight
					if roll <= 0:
						picked = raw
						break
				var action: Dictionary = announced[index]
				var body: Dictionary = picked.duplicate(true)
				body.erase("weight")
				for key in body:
					if key == "direction" and body.type == "shove":
						_check(action.get(key) in [-1, 1],
							"authored shove is bounded to a legal direction " + id)
					else:
						_check(action.get(key) == body[key],
							"weighted announced action matches seeded authored roll " + id)
				_check(action.get("enemy_position") == index + 1,
					"announced source stays in original slot " + id)
				if action.type in ["attack", "debuff", "shove"]:
					var target := CombatEnemyIntents.priority_target(party, spec.target)
					if spec.target == "random":
						target = [1, 2, 3][oracle.randi_range(0, 2)]
					_check(action.get("target_position") == target,
						"announced live target matches policy and run RNG " + id)
				else:
					_check(not action.has("target_position"),
						"Block/buff never invent a hero target " + id)
				present[PAIRS[id].enemy_ids[index] + "/" + action.type] = true
			_check(rng.state == oracle.state,
				"only expected weighted and random-target RNG draws consumed " + id)
			first.append(announced)
			states.append(rng.state)
			var phase := CombatEnemyPhase.new().execute_phase(party, enemies, announced, null, true)
			_check(phase.get("ok") and phase.get("events", []).size() == 2,
				"actual enemy phase executes announced alternatives " + id)
			_check(scheduler.get_intents() == announced and rng.state == committed,
				"execution does not reroll the cached predictions " + id)
			phase_states.append([phase.get("events"), party.get_heroes(), enemies.get_enemies()])
		_check(first[0] == first[1] and states[0] == states[1]
			and phase_states[0] == phase_states[1],
			"two same-seed announcements and committed phases replay identically " + id)
	for actor_id in PAIRS[id].enemy_ids:
		for raw in NEW[actor_id].actions:
			_check(present.has(actor_id + "/" + raw.type),
				"actual seeded phase covered authored alternative " + actor_id + "/" + raw.type)
	# Preannounced targets downed after admission fall back at execution time
	# without a second roll, for both deterministic and random policies.
	for source in range(2):
		var found := false
		for seed_value in range(1, 90):
			var party := _party()
			var enemies := CombatEnemies.new(assembled.roster.enemies.get_enemies())
			var rng := _rng(seed_value)
			var scheduler := CombatEnemyIntents.new(assembled.roster.definitions)
			if not scheduler.bind_battle(enemies, party, rng):
				continue
			var announced := scheduler.get_intents()
			var action: Dictionary = announced[source]
			if not action.has("target_position"):
				continue
			var target: int = action.target_position
			var old_hp: int = party.get_hero(target).hp
			if not party.apply_damage(target, old_hp) or not party.is_downed(target):
				continue
			var before_rng := rng.state
			var expected_target := CombatEnemyIntents.priority_target(party,
				NEW[PAIRS[id].enemy_ids[source]].target)
			var resolved := CombatEnemyIntents.resolve_announced_action(party, action, enemies)
			_check(resolved.get("target_position") == expected_target
				and not party.is_downed(expected_target),
				"downed announced target finds legal deterministic fallback " + id)
			var phase := CombatEnemyPhase.new().execute_phase(party, enemies, [action], null, true)
			_check(phase.get("ok") and phase.get("events", []).size() == 1
				and phase.events[0].get("target_position") == expected_target,
				"executor uses live legal fallback of announced action " + id)
			_check(rng.state == before_rng and scheduler.get_intents() == announced,
				"downed fallback spends no RNG or reroll " + id)
			found = true
			break
		_check(found, "found genuine target-bearing action for downed fallback " + id)

func _click(button: Control) -> void:
	_check(is_instance_valid(button) and button.is_visible_in_tree(),
		"physical mouse target visible")
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

func _mounted() -> void:
	# Find a real run seed that picks an M05 candidate from the entire pool,
	# without forcing a test-only entry in the app.
	var fixture := {}
	var ids: Array = pools["Fight"].keys()
	ids.sort()
	for seed_value in range(1, 700):
		var rng := _rng(seed_value)
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		var node := _choose_fight(map)
		if node.is_empty():
			continue
		var selected_id: String = ids[rng.randi_range(0, ids.size() - 1)]
		if PAIRS.has(selected_id):
			fixture = {"seed": seed_value, "node": node, "encounter": selected_id}
			break
	_check(not fixture.is_empty(), "genuine seeded full Fight rotation reaches new alternative")
	if fixture.is_empty():
		return
	var scene: PackedScene = load("res://scenes/app.tscn")
	_check(scene != null, "real 1280x720 app scene loads")
	if scene == null:
		return
	root.size = Vector2i(1280, 720)
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	app.run_seed = fixture.seed
	await _click(app.route_button)
	_check(app.run_map != null and app.run_map.get_route().is_empty(),
		"physical title route opens genuine uncommitted map")
	if app.run_map == null:
		app.free()
		return
	var button: Button
	for candidate in app.route_buttons:
		if candidate.get_meta("route_id") == fixture.node:
			button = candidate
	_check(button != null and app.run_map.get_legal_choices().has(fixture.node),
		"new-pair Fight is reachable by mounted route button")
	if button == null:
		app.free()
		return
	await _click(button)
	for frame in range(3):
		await process_frame
	_check(app.encounter_id == fixture.encounter and app.deck != null
		and app.enemy_intents != null and app.enemy_intents.is_bound()
		and app.enemies != null and app.battle_view != null,
		"actual routed entry mounts selected new pair with weighted intents")
	if app.enemies == null or app.deck == null:
		app.free()
		return
	var presenter = app.get_node("LiveEnemyRoster")
	var expected: Array = PAIRS[fixture.encounter].enemy_ids
	_check(presenter.enemies == app.enemies and presenter._labels.size() == 2
		and presenter._puppets.size() >= 5, "mounted battle owns both felt puppets")
	for index in range(2):
		var actor: Dictionary = app.enemies.get_enemy(index + 1)
		var puppet = presenter._puppets[index + 3]
		_check(actor.id == expected[index] and puppet.actor_id == expected[index]
			and puppet.is_visible_in_tree() and puppet.size.x > 0
			and presenter._labels[index].text == NEW[expected[index]].name,
			"named actor renders in genuine existing fallback stage " + expected[index])
		_check(presenter.art_for(expected[index]).get("idle") == null
			and puppet.current_texture() == null,
			"unmapped M05 actor uses procedural felt puppet fallback " + expected[index])
	_check(app.deck.hand.size() == 5 and app.end_turn_button.is_visible_in_tree(),
		"real five-card hand and End Turn reachable at 1280x720")
	# A genuine mounted card remains playable before enemy End Turn.
	var played := false
	for i in range(app.deck.hand.size()):
		var card_id: String = app.deck.hand[i]
		if card_id not in ["warden_strike", "seamstress_prick", "tinker_pop_shot"]:
			continue
		var before := [app.deck.hand.size(), app.deck.energy, app.enemies.get_enemies()]
		await _click(app.hand_view.get_child(i))
		await _click(presenter._labels[0])
		played = app.deck.hand.size() < before[0] and app.deck.energy < before[1]
		if played:
			break
	_check(played, "physical card selection and enemy targeting commits a starter attack")
	var prior_turn: int = app.enemy_intents._turn_index
	var prior_hand: Array = app.deck.hand.duplicate()
	await _click(app.end_turn_button)
	_check(app.enemy_intents._turn_index == prior_turn + 1
		and app.deck.hand.size() == 5 and app.deck.hand != prior_hand,
		"mounted End Turn resolves weighted enemy phase and draws next hand")
	app.free()

func _run() -> void:
	_catalog_and_bindings()
	if pools is Dictionary and pools.get("Fight") is Dictionary:
		for id in PAIRS:
			var first := _assemble(id, 18141)
			var again := _assemble(id, 18141)
			_check(not first.is_empty() and not again.is_empty(),
				"independent actual selections both succeed " + id)
			if not first.is_empty() and not again.is_empty():
				_check(first.choice == again.choice and first.rng_state == again.rng_state
					and first.floors == again.floors and first.route == again.route
					and first.roster.enemies.get_enemies() == again.roster.enemies.get_enemies(),
					"seeded new Fight route, actor roster and RNG replay " + id)
				_weighted(id, first)
		await _mounted()
	if failures.is_empty():
		print("m05_normal_enemy_rotation_test: PASS (", checks, " checks)")
	else:
		for reason in failures:
			printerr(reason)
		printerr("m05_normal_enemy_rotation_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
