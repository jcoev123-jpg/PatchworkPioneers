extends SceneTree
## Standalone Elite schedule integration: real map, selector, roster, phase and owner tick.

const PATHS := {
	"marshal_reel_reversal": "res://data/encounters/marshal_reel_reversal.json",
	"spoolhex_bleedline": "res://data/encounters/spoolhex_bleedline.json",
}
const BINDINGS := {
	"marshal_reel_reversal": ["needle_marshal", "spool_stalker"],
	"spoolhex_bleedline": ["spool_hexer", "seam_ripper"],
}
const CATALOGS := ["res://data/enemies/m04_elites.json", "res://data/enemies/run_enemies.json"]
const STATS := {
	"needle_marshal": [28, "Needle Marshal", "res://assets/paper/enemies/needle_marshal.png"],
	"spool_stalker": [14, "Spool Stalker", "res://assets/paper/enemies/spool_stalker.png"],
	"spool_hexer": [24, "Spool Hexer", "res://assets/paper/enemies/spool_hexer.png"],
	"seam_ripper": [18, "Seam Ripper", "res://assets/paper/enemies/seam_ripper.png"],
}
const EXPECTED := {
	"marshal_reel_reversal": [
		{"enemy_position": 1, "pattern": [
			{"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
			{"type": "attack", "amount": 4, "target_position": 1},
			{"type": "buff", "amount": 3},
			{"type": "attack", "amount": 4, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 2, "target_position": 3},
			{"type": "block", "amount": 2},
			{"type": "attack", "amount": 2, "target_position": 1},
			{"type": "attack", "amount": 2, "target_position": 3}]}],
	"spoolhex_bleedline": [
		{"enemy_position": 1, "pattern": [
			{"type": "debuff", "amount": 2, "target_position": 3, "status": "bleed"},
			{"type": "debuff", "amount": 1, "target_position": 2, "status": "weak"},
			{"type": "attack", "amount": 3, "target_position": 3},
			{"type": "buff", "amount": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 3, "target_position": 3},
			{"type": "attack", "amount": 4, "target_position": 1},
			{"type": "block", "amount": 2},
			{"type": "attack", "amount": 3, "target_position": 2}]}],
}
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_content()
	_selection()
	_phases()
	_negative()
	for failure in failures:
		printerr(failure)
	print("m03_elite_battle_variants_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, why: String) -> void:
	checks += 1
	if not value:
		failures.append(why)


func _schedule(id: String) -> Array:
	_check(FileAccess.file_exists(PATHS[id]), "authored file exists: " + id)
	if not FileAccess.file_exists(PATHS[id]):
		return []
	return RunFightEncounterSelection._parse_schedule_text(
		FileAccess.get_file_as_string(PATHS[id]))


func _party() -> CombatParty:
	var path := "res://data/heroes/starter_party.json"
	var records := RunTypedBattleRoster._parse_catalog_text(FileAccess.get_file_as_string(path))
	_check(records.size() >= 3, "real starter hero catalog parses")
	var heroes: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		var matching: Array = records.filter(func(actor: Dictionary) -> bool:
			return actor.get("id") == id)
		_check(matching.size() == 1, "unique authored hero " + id)
		if matching.size() == 1:
			heroes.append(matching[0])
	var party := CombatParty.new(heroes)
	_check(party.is_valid() and party.get_heroes().map(
		func(hero: Dictionary) -> int: return hero.hp) == [40, 30, 26],
		"real living Warden/Seamstress/Tinker formation")
	_check(CombatStartingBlock.new(party).apply()
		and party.get_hero(1).get("block") == 6, "one-shot Warden six Block")
	return party


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _route(seed_value: int) -> Dictionary:
	var rng := _rng(seed_value)
	var map := RunMap.new()
	if not map.generate(rng):
		return {}
	for node_id in map.get_legal_choices():
		if map.get_node(node_id).get("type") == "Elite" and map.choose_node(node_id):
			return {"map": map, "rng": rng, "node": node_id}
	return {}


func _elite_seed() -> int:
	for value in range(1, 129):
		if not _route(value).is_empty():
			return value
	return -1


func _snapshot(context: Dictionary) -> Dictionary:
	var map: RunMap = context.map
	var rng: RandomNumberGenerator = context.rng
	var selector: RunFightEncounterSelection = context.selector
	return {"floors": map.get_floors(), "route": map.get_route(),
		"choices": map.get_legal_choices(), "node": map.get_current_node_id(),
		"rng": rng.state, "cache": selector._selected.duplicate(true),
		"bound": selector._bound_map}


func _build(id: String, seed_value: int) -> Dictionary:
	var route := _route(seed_value)
	_check(not route.is_empty(), "generated legal Elite path " + id)
	if route.is_empty():
		return {}
	var map: RunMap = route.map
	_check(map.get_node(route.node).get("type") == "Elite"
		and map.get_route() == [route.node] and map.get_current_floor() == 1,
		"selector input is actual chosen Elite node " + id)
	var picker := RunFightEncounterSelection.new()
	var local_pool := {"Elite": {id: PATHS[id]}}
	var choice := picker.select_current_battle(map, route.rng, local_pool)
	_check(choice.get("success") == true and choice.get("node_type") == "Elite"
		and choice.get("encounter_id") == id and choice.get("definitions") == EXPECTED[id],
		"typed selector selected own full schedule " + id)
	if not choice.get("success", false):
		return {}
	var roster_bindings := {id: BINDINGS[id].duplicate()}
	var built := RunTypedBattleRoster.new().assemble(choice, roster_bindings, CATALOGS)
	_check(built.get("ok") == true and built.get("node_type") == "Elite"
		and built.get("encounter_id") == id and built.get("definitions") == EXPECTED[id],
		"production typed roster accepted local binding " + id)
	if not built.get("ok", false):
		return {}
	var enemies: CombatEnemies = built.enemies
	var scheduler := CombatEnemyIntents.new(built.definitions)
	_check(enemies.is_valid() and scheduler.is_valid()
		and enemies.get_enemies().size() == 2, "real assembled battle is live " + id)
	return {"map": map, "rng": route.rng, "selector": picker, "choice": choice,
		"enemies": enemies, "scheduler": scheduler, "party": _party()}


func _content() -> void:
	var originals: Dictionary = {}
	for path in CATALOGS:
		_check(FileAccess.file_exists(path), "source catalog exists " + path)
		var records := RunTypedBattleRoster._parse_catalog_text(FileAccess.get_file_as_string(path))
		_check(not records.is_empty(), "real enemy catalog valid " + path)
		for record in records:
			if STATS.has(record.get("id")):
				_check(not originals.has(record.id), "unique enemy across catalogs " + record.id)
				originals[record.id] = record
	for enemy_id in STATS:
		_check(originals.has(enemy_id), "unchanged enemy record present " + enemy_id)
		if originals.has(enemy_id):
			var actor: Dictionary = originals[enemy_id]
			_check([actor.get("max_hp"), actor.get("name"), actor.get("art_path")] == STATS[enemy_id],
				"original enemy HP/name/art exact " + enemy_id)
	for id in PATHS:
		var schedule := _schedule(id)
		_check(schedule == EXPECTED[id] and schedule.size() == 2,
			"all own beats, exact two ordered sources and fields " + id)
		var intents := CombatEnemyIntents.new(schedule)
		_check(intents.is_valid(), "production intent validation " + id)
		if not intents.is_valid():
			continue
		var before := schedule.duplicate(true)
		for beat in range(5):
			var announced: Array = []
			for definition in EXPECTED[id]:
				var action: Dictionary = definition.pattern[beat % 4].duplicate(true)
				action["enemy_position"] = definition.enemy_position
				announced.append(action)
			_check(intents.get_intents() == announced,
				"both announced intents at beat %d, including wrap, %s" % [beat, id])
			_check(intents.advance_turn(), "explicit beat advance " + id)
		_check(schedule == before, "production intent scheduler never edits schedule " + id)


func _selection() -> void:
	var seed_value := _elite_seed()
	_check(seed_value > 0, "bounded seed search found actual legal Elite")
	if seed_value < 0:
		return
	for id in PATHS:
		var a := _build(id, seed_value)
		var b := _build(id, seed_value)
		if a.is_empty() or b.is_empty():
			continue
		_check(a.map.get_floors() == b.map.get_floors()
			and a.map.get_route() == b.map.get_route()
			and a.rng.state == b.rng.state and a.choice == b.choice,
			"two independent same-seed Elite selections replay " + id)
		var before := _snapshot(a)
		var original: Dictionary = a.choice.duplicate(true)
		var cached: Dictionary = a.selector.select_current_battle(a.map, a.rng, {"Elite": {}})
		_check(cached == original and _snapshot(a) == before,
			"cached retry retains route, pool claim and RNG " + id)
		cached.definitions[0].pattern[0].amount = 444
		_check(a.selector.select_current_battle(a.map, a.rng, {"Elite": {}}) == original
			and _snapshot(a) == before, "cache is independently copied " + id)
		_check(a.enemies.get_enemies() == b.enemies.get_enemies()
			and a.enemies != b.enemies, "typed rosters independent and identical " + id)
		for index in range(2):
			var actor: Dictionary = a.enemies.get_enemy(index + 1)
			var actor_id: String = BINDINGS[id][index]
			_check(actor.get("id") == actor_id and actor.get("position") == index + 1
				and actor.get("hp") == STATS[actor_id][0]
				and actor.get("max_hp") == STATS[actor_id][0]
				and actor.get("art_path") == STATS[actor_id][2]
				and actor.get("block") == 0, "bound actor record/slot " + id)
		_check(_snapshot(a) == before, "assembly and queries do not mutate route/RNG " + id)


func _events(id: String, beat: int, first_applied: bool = true) -> Array:
	var events: Array = []
	for index in range(2):
		var action: Dictionary = EXPECTED[id][index].pattern[beat].duplicate(true)
		var event := {"type": action.type, "enemy_position": index + 1,
			"applied": first_applied if index == 0 else true}
		for field in ["target_position", "direction", "status"]:
			if action.has(field):
				event[field] = action[field]
		events.append(event)
	return events


func _phases() -> void:
	var seed_value := _elite_seed()
	if seed_value < 0:
		return
	for id in PATHS:
		var first_trace: Array = []
		for replay in range(2):
			var game := _build(id, seed_value)
			if game.is_empty():
				continue
			var party: CombatParty = game.party
			var enemies: CombatEnemies = game.enemies
			var intents: CombatEnemyIntents = game.scheduler
			var start_heroes := party.get_heroes()
			var start_enemies := enemies.get_enemies()
			var initial_intents := intents.get_intents()
			var rng_before: int = game.rng.state
			seed(60291)
			var expected_global := randi()
			seed(60291)
			var descending := initial_intents.duplicate(true)
			descending.reverse()
			var result := CombatEnemyPhase.new().execute_phase(party, enemies, descending)
			_check(result == {"ok": true, "events": _events(id, 0)},
				"real first phase source 1 then 2, input reversed " + id)
			var expected_heroes := start_heroes.duplicate(true)
			if id == "marshal_reel_reversal":
				var moved: Dictionary = expected_heroes[1]
				expected_heroes[1] = expected_heroes[2]
				expected_heroes[2] = moved
				expected_heroes[1]["position"] = 2
				expected_heroes[2]["position"] = 3
				expected_heroes[2]["hp"] = 28
			else:
				expected_heroes[2]["hp"] = 23
				expected_heroes[2]["statuses"] = {"bleed": 2}
			_check(party.get_heroes() == expected_heroes and enemies.get_enemies() == start_enemies,
				"complete expected opening HP/Block/formation/status and enemies " + id)
			_check(intents.get_intents() == initial_intents and descending.size() == 2,
				"enemy phase does not spend scheduled beat " + id)
			var tick := CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())
			_check(tick.get("ok") == true and tick.get("events", []).size() == 3,
				"real hero-owner turn tick valid " + id)
			if not tick.get("ok", false):
				continue
			var expected_ticked := expected_heroes.duplicate(true)
			if id == "spoolhex_bleedline":
				expected_ticked[2]["hp"] = 21
				expected_ticked[2]["statuses"] = {"bleed": 1}
			for index in range(3):
				if not expected_ticked[index].has("statuses"):
					expected_ticked[index]["statuses"] = {}
			_check(tick.actors == expected_ticked
				and tick.events.map(func(e: Dictionary) -> int: return e.bleed_hp_loss) ==
					([0, 0, 2] if id == "spoolhex_bleedline" else [0, 0, 0]),
				"owner tick independently proves direct Bleed bypass and decrement " + id)
			_check(party.get_heroes() == expected_heroes,
				"owner tick is detached until caller commits, not auto-applied " + id)
			for index in range(3):
				party._heroes[index]["hp"] = tick.actors[index].hp
				party._heroes[index]["statuses"] = tick.actors[index].statuses
			_check(party.start_player_turn() and intents.advance_turn(),
				"real turn boundary resets Block and explicitly advances intents " + id)
			for hero in expected_ticked:
				hero["block"] = 0
			var next_intents := intents.get_intents()
			var actual: Array = []
			for definition in EXPECTED[id]:
				var announced: Dictionary = definition.pattern[1].duplicate(true)
				announced["enemy_position"] = definition.enemy_position
				actual.append(announced)
			_check(next_intents == actual, "second actual announced beat exact " + id)
			var second := CombatEnemyPhase.new().execute_phase(party, enemies, next_intents)
			_check(second == {"ok": true, "events": _events(id, 1)},
				"second actual phase actions in source order " + id)
			var expected_enemies := start_enemies.duplicate(true)
			if id == "marshal_reel_reversal":
				# The authored Marshal Attack 4 lands on the living front Warden
				# with no Block, so its confirmed-hit sting adds exactly Bleed 1
				# alongside the unchanged 4 HP loss.
				expected_ticked[0]["hp"] = 36
				expected_ticked[0]["statuses"] = {"bleed": 1}
				expected_enemies[1]["block"] = 2
			else:
				expected_ticked[1]["statuses"] = {"weak": 1}
				expected_ticked[0]["hp"] = 36
			_check(party.get_heroes() == expected_ticked
				and enemies.get_enemies() == expected_enemies,
				"full second-beat HP/Block/formation/weak and enemy state " + id)
			_check(game.rng.state == rng_before and randi() == expected_global,
				"phase and owner tick never spend run or global RNG " + id)
			var trace := [initial_intents, result, expected_heroes,
				tick, next_intents, second, party.get_heroes(), enemies.get_enemies()]
			if replay == 0:
				first_trace = trace
			else:
				_check(trace == first_trace, "fresh independent phase and tick replay " + id)


func _negative() -> void:
	var seed_value := _elite_seed()
	if seed_value < 0:
		return
	for id in PATHS:
		var game := _build(id, seed_value)
		if game.is_empty():
			continue
		var party: CombatParty = game.party
		var enemies: CombatEnemies = game.enemies
		var intents: CombatEnemyIntents = game.scheduler
		var target := 2 if id == "marshal_reel_reversal" else 3
		var hp: int = party.get_hero(target).hp
		_check(party.apply_damage(target, hp) and party.is_downed(target),
			"real combat damage downs swap participant or Bleed target " + id)
		var before_party := party.get_heroes()
		var before_enemies := enemies.get_enemies()
		var before_intents := intents.get_intents()
		var before_state := _snapshot(game)
		seed(19117)
		var global_next := randi()
		seed(19117)
		var phase := CombatEnemyPhase.new().execute_phase(party, enemies, before_intents)
		_check(phase == {"ok": false, "events": []}
			and party.get_heroes() == before_party
			and enemies.get_enemies() == before_enemies
			and intents.get_intents() == before_intents
			and _snapshot(game) == before_state and randi() == global_next,
			"illegal shove/debuff reject atomically across party/enemy/intent/run/global RNG " + id)

		# Later invalid source also rolls back an earlier source's real attack.
		var staged_first := {"type": "attack", "enemy_position": 1,
			"amount": 3, "target_position": 1}
		var staged_second := {"type": "debuff", "enemy_position": 2,
			"amount": 1, "target_position": target, "status": "weak"}
		phase = CombatEnemyPhase.new().execute_phase(party, enemies,
			[staged_second, staged_first])
		_check(phase == {"ok": false, "events": []}
			and party.get_heroes() == before_party and enemies.get_enemies() == before_enemies
			and intents.get_intents() == before_intents and _snapshot(game) == before_state,
			"later rejected debuff rolls back earlier staged hit " + id)

		game = _build(id, seed_value)
		if game.is_empty():
			continue
		party = game.party
		enemies = game.enemies
		intents = game.scheduler
		var enemy_hp: int = enemies.get_enemy(1).hp
		_check(enemies.apply_damage(1, enemy_hp) and enemies.is_slain(1)
			and not enemies.is_slain(2), "real slain source and living source 2 " + id)
		var killed_before := enemies.get_enemies()
		var killed_intents := intents.get_intents()
		var rng_state: int = game.rng.state
		var killed := CombatEnemyPhase.new().execute_phase(party, enemies, killed_intents)
		_check(killed == {"ok": true, "events": _events(id, 0, false)}
			and enemies.get_enemies() == killed_before
			and party.get_hero(3).hp == (24 if id == "marshal_reel_reversal" else 23)
			and party.get_hero(2).id == "seamstress"
			and party.get_hero(3).get("statuses", {}).is_empty()
			and party.get_hero(1).block == 6
			and intents.get_intents() == killed_intents and game.rng.state == rng_state,
			"killed source is silent; living source 2 attacks correct original rear " + id)
