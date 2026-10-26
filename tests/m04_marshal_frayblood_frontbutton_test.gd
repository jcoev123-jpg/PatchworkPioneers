extends SceneTree
## Standalone M04 Elite fixtures, driven by actual map, typed roster and combat services.

const PATHS := {
	"marshal_frayblood_watch": "res://data/encounters/marshal_frayblood_watch.json",
	"marshal_frontbutton_relay": "res://data/encounters/marshal_frontbutton_relay.json",
}
const BINDINGS := {
	"marshal_frayblood_watch": ["needle_marshal", "fray_scavenger"],
	"marshal_frontbutton_relay": ["needle_marshal", "spool_stalker"],
}
const CATALOGS := ["res://data/enemies/m04_elites.json", "res://data/enemies/run_enemies.json"]
const STATS := {
	"needle_marshal": [28, "Needle Marshal", "res://assets/paper/enemies/needle_marshal.png"],
	"fray_scavenger": [14, "Fray Scavenger", "res://assets/paper/enemies/fray_scavenger.png"],
	"spool_stalker": [14, "Spool Stalker", "res://assets/paper/enemies/spool_stalker.png"],
}
const EXPECTED := {
	"marshal_frayblood_watch": [
		{"enemy_position": 1, "pattern": [
			{"type": "debuff", "amount": 1, "target_position": 1, "status": "bleed"},
			{"type": "block", "amount": 3},
			{"type": "attack", "amount": 4, "target_position": 2},
			{"type": "buff", "amount": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 3, "target_position": 2},
			{"type": "attack", "amount": 2, "target_position": 3},
			{"type": "debuff", "amount": 1, "target_position": 1, "status": "exposed"},
			{"type": "attack", "amount": 3, "target_position": 1}]}],
	"marshal_frontbutton_relay": [
		{"enemy_position": 1, "pattern": [
			{"type": "shove", "amount": 0, "target_position": 1, "direction": 1},
			{"type": "debuff", "amount": 1, "target_position": 1, "status": "weak"},
			{"type": "attack", "amount": 4, "target_position": 1},
			{"type": "buff", "amount": 3}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 2, "target_position": 3},
			{"type": "block", "amount": 2},
			{"type": "attack", "amount": 3, "target_position": 2},
			{"type": "attack", "amount": 2, "target_position": 1}]}],
}
# [id, current position, HP, Block, named statuses] after each enemy phase.
const HERO_PHASES := {
	"marshal_frayblood_watch": [
		[["warden", 1, 40, 6, {"bleed": 1}], ["seamstress", 2, 27, 0, {}], ["tinker", 3, 26, 0, {}]],
		[["warden", 1, 39, 0, {}], ["seamstress", 2, 27, 0, {}], ["tinker", 3, 24, 0, {}]],
		[["warden", 1, 39, 0, {"exposed": 1}], ["seamstress", 2, 23, 0, {"bleed": 1}], ["tinker", 3, 24, 0, {}]],
		[["warden", 1, 36, 0, {}], ["seamstress", 2, 22, 0, {}], ["tinker", 3, 24, 0, {}]],
		[["warden", 1, 36, 0, {"bleed": 1}], ["seamstress", 2, 19, 0, {}], ["tinker", 3, 24, 0, {}]]],
	"marshal_frontbutton_relay": [
		[["seamstress", 1, 30, 0, {}], ["warden", 2, 40, 6, {}], ["tinker", 3, 24, 0, {}]],
		[["seamstress", 1, 30, 0, {"weak": 1}], ["warden", 2, 40, 0, {}], ["tinker", 3, 24, 0, {}]],
		[["seamstress", 1, 26, 0, {"bleed": 1}], ["warden", 2, 37, 0, {}], ["tinker", 3, 24, 0, {}]],
		[["seamstress", 1, 23, 0, {}], ["warden", 2, 37, 0, {}], ["tinker", 3, 24, 0, {}]],
		[["warden", 1, 37, 0, {}], ["seamstress", 2, 23, 0, {}], ["tinker", 3, 22, 0, {}]]],
}
const ENEMY_PHASES := {
	"marshal_frayblood_watch": [
		[["needle_marshal", 1, 28, 0, {}], ["fray_scavenger", 2, 14, 0, {}]],
		[["needle_marshal", 1, 28, 3, {}], ["fray_scavenger", 2, 14, 0, {}]],
		[["needle_marshal", 1, 28, 3, {}], ["fray_scavenger", 2, 14, 0, {}]],
		[["needle_marshal", 1, 28, 5, {}], ["fray_scavenger", 2, 14, 0, {}]],
		[["needle_marshal", 1, 28, 5, {}], ["fray_scavenger", 2, 14, 0, {}]]],
	"marshal_frontbutton_relay": [
		[["needle_marshal", 1, 28, 0, {}], ["spool_stalker", 2, 14, 0, {}]],
		[["needle_marshal", 1, 28, 0, {}], ["spool_stalker", 2, 14, 2, {}]],
		[["needle_marshal", 1, 28, 0, {}], ["spool_stalker", 2, 14, 2, {}]],
		[["needle_marshal", 1, 28, 3, {}], ["spool_stalker", 2, 14, 2, {}]],
		[["needle_marshal", 1, 28, 3, {}], ["spool_stalker", 2, 14, 2, {}]]],
}
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_content()
	var elite_seed := _elite_seed()
	_check(elite_seed > 0, "generated seeded map offers an actually legal Elite choice")
	if elite_seed > 0:
		for id in PATHS:
			_replay(id, elite_seed)
			_negative(id, elite_seed)
	for message in failures:
		printerr(message)
	print("m04_marshal_frayblood_frontbutton_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)


func _actors(actors: Array) -> Array:
	var summary: Array = []
	for a in actors:
		summary.append([a.get("id"), a.get("position"), a.get("hp"), a.get("block"),
			a.get("statuses", {}).duplicate(true)])
	return summary


func _parse(id: String) -> Array:
	_check(FileAccess.file_exists(PATHS[id]), "authored JSON exists " + id)
	if not FileAccess.file_exists(PATHS[id]):
		return []
	return RunFightEncounterSelection._parse_schedule_text(
		FileAccess.get_file_as_string(PATHS[id]))


func _announced(id: String, beat: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source in EXPECTED[id]:
		var action: Dictionary = source.pattern[beat % 4].duplicate(true)
		action["enemy_position"] = source.enemy_position
		result.append(action)
	return result


func _events(id: String, beat: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source in EXPECTED[id]:
		var action: Dictionary = source.pattern[beat % 4]
		var event := {"type": action.type, "enemy_position": source.enemy_position,
			"applied": true}
		for field in ["target_position", "direction", "status"]:
			if action.has(field):
				event[field] = action[field]
		result.append(event)
	return result


func _content() -> void:
	var actual_stats := {}
	for path in CATALOGS:
		_check(FileAccess.file_exists(path), "catalog exists " + path)
		var records := RunTypedBattleRoster._parse_catalog_text(
			FileAccess.get_file_as_string(path))
		_check(not records.is_empty(), "catalog has genuine parsed enemies " + path)
		for record in records:
			if STATS.has(record.get("id")):
				_check(not actual_stats.has(record.id), "unique required catalog ID " + record.id)
				actual_stats[record.id] = [record.max_hp, record.name, record.art_path]
	for id in STATS:
		_check(actual_stats.get(id) == STATS[id], "original HP/name/art catalog " + id)
	for id in PATHS:
		var parsed := _parse(id)
		_check(parsed == EXPECTED[id] and parsed.size() == 2,
			"two exact authored sources/four full beats " + id)
		if parsed.size() != 2:
			continue
		_check(parsed[0].enemy_position == 1 and parsed[1].enemy_position == 2
			and parsed[0].pattern.size() == 4 and parsed[1].pattern.size() == 4,
			"ordered distinct slots and four beats " + id)
		var intents := CombatEnemyIntents.new(parsed)
		_check(intents.is_valid(), "genuine typed action validation " + id)
		if intents.is_valid():
			for beat in range(9):
				_check(intents.get_intents() == _announced(id, beat),
					"source-by-source announced beat %d %s" % [beat, id])
				_check(intents.advance_turn(), "schedule can advance " + id)
	for old in ["needle_marshal_elite", "marshal_frontpin_bastion", "marshal_midline_tumble"]:
		var path := "res://data/encounters/%s.json" % old
		_check(FileAccess.file_exists(path), "pre-existing Marshal resource exists " + old)
		var definitions := RunFightEncounterSelection._parse_schedule_text(
			FileAccess.get_file_as_string(path))
		_check(not definitions.is_empty() and CombatEnemyIntents.new(definitions).is_valid(),
			"pre-existing Marshal resource still parses " + old)


func _rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _route(value: int, kind: String) -> Dictionary:
	var rng := _rng(value)
	var map := RunMap.new()
	if not map.generate(rng):
		return {}
	for node in map.get_legal_choices():
		if map.get_node(node).get("type") == kind and map.choose_node(node):
			return {"map": map, "rng": rng, "node": node}
	return {}


func _elite_seed() -> int:
	for candidate in range(1, 257):
		if not _route(candidate, "Elite").is_empty():
			return candidate
	return -1


func _party() -> CombatParty:
	var records := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))
	var ordered: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		var matches := records.filter(func(row: Dictionary) -> bool: return row.get("id") == id)
		_check(matches.size() == 1, "one shipped starter record " + id)
		if matches.size() == 1:
			ordered.append(matches[0])
	var party := CombatParty.new(ordered)
	_check(party.is_valid(), "built actual three-person starter CombatParty")
	if party.is_valid():
		_check(_actors(party.get_heroes()) == [
			["warden", 1, 40, 0, {}], ["seamstress", 2, 30, 0, {}],
			["tinker", 3, 26, 0, {}]], "40/30/26 living original starter lineup")
		_check(CombatStartingBlock.new(party).apply()
			and party.get_hero(1).block == 6, "real opening Warden Block is six")
	return party


func _build(id: String, value: int) -> Dictionary:
	var route := _route(value, "Elite")
	_check(not route.is_empty(), "actual legal seeded Elite on map " + id)
	if route.is_empty():
		return {}
	var map: RunMap = route.map
	_check(map.get_current_node_id() == route.node and map.get_route() == [route.node]
		and map.get_node(route.node).type == "Elite", "committed Elite route " + id)
	var selector := RunFightEncounterSelection.new()
	var choice := selector.select_current_battle(map, route.rng,
		{"Elite": {id: PATHS[id]}})
	_check(choice == {"success": true, "node_type": "Elite", "encounter_id": id,
		"definitions": EXPECTED[id]}, "one-entry real Elite selection " + id)
	if not choice.get("success", false):
		return {}
	var roster := RunTypedBattleRoster.new().assemble(
		choice, {id: BINDINGS[id].duplicate()}, CATALOGS)
	_check(roster.get("ok") == true and roster.get("node_type") == "Elite"
		and roster.get("definitions") == EXPECTED[id],
		"real typed roster binding " + id)
	if not roster.get("ok", false):
		return {}
	var enemies: CombatEnemies = roster.enemies
	var scheduler := CombatEnemyIntents.new(roster.definitions)
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2
		and scheduler.is_valid(), "two living combat enemies and intent scheduler " + id)
	for i in range(2):
		var actor := enemies.get_enemy(i + 1)
		var name: String = BINDINGS[id][i]
		_check([actor.get("id"), actor.get("position"), actor.get("hp"),
			actor.get("max_hp"), actor.get("name"), actor.get("art_path"), actor.get("block")]
			== [name, i + 1, STATS[name][0], STATS[name][0], STATS[name][1],
			STATS[name][2], 0], "real roster HP/name/art and position " + name)
	var party := _party()
	if not party.is_valid():
		return {}
	return {"map": map, "rng": route.rng, "selector": selector, "party": party,
		"enemies": enemies, "scheduler": scheduler}


func _snapshot(game: Dictionary) -> Dictionary:
	return {"heroes": game.party.get_heroes(), "enemies": game.enemies.get_enemies(),
		"intents": game.scheduler.get_intents(), "turn": game.scheduler._turn_index,
		"rng": game.rng.state, "route": game.map.get_route(),
		"cache": game.selector._selected.duplicate(true)}


func _replay(id: String, value: int) -> void:
	var previous_trace: Array = []
	for repeat in range(2):
		var game := _build(id, value)
		if game.is_empty():
			continue
		var party: CombatParty = game.party
		var scheduler: CombatEnemyIntents = game.scheduler
		var initial_rng: int = game.rng.state
		var initial_route: Array = game.map.get_route()
		var initial_cache: Dictionary = game.selector._selected.duplicate(true)
		var trace: Array = []
		for beat in range(5):
			if beat > 0:
				# Enemy phase never applies Bleed. Tick actual hero-owner turn separately.
				var before := party.get_heroes()
				var tick := CombatStatusTurnBatch.new().tick_side("heroes", before)
				_check(tick.get("ok") == true and tick.events.size() == 3,
					"real detached hero owner tick %d %s" % [beat, id])
				if not tick.get("ok", false):
					break
				var losses: Array = tick.events.map(func(e: Dictionary) -> int:
					return e.bleed_hp_loss)
				# Beat 1 pays the authored Bleed 1; beat 3 pays the sting's own
				# Bleed 1 on the hero that really lost HP to the Marshal.
				var expected_losses := [0, 0, 0]
				if id == "marshal_frayblood_watch" and beat == 1:
					expected_losses = [1, 0, 0]
				elif id == "marshal_frayblood_watch" and beat == 3:
					expected_losses = [0, 1, 0]
				elif id == "marshal_frontbutton_relay" and beat == 3:
					expected_losses = [1, 0, 0]
				_check(losses == expected_losses,
					"Bleed goes through preserved Block exactly at owner end " + id)
				_check(party.get_heroes() == before, "detached owner tick does not auto-publish")
				if id == "marshal_frayblood_watch" and beat == 1:
					_check(tick.actors[0].hp == 39 and tick.actors[0].block == 6
						and tick.actors[0].statuses == {},
						"Bleed 1 bypasses six Warden Block, then expires")
				if beat == 3:
					var stung: Dictionary = tick.actors[1] \
						if id == "marshal_frayblood_watch" else tick.actors[0]
					_check(stung.hp == (22 if id == "marshal_frayblood_watch" else 25)
						and stung.statuses == {},
						"the sting's Bleed 1 takes exactly one HP then expires " + id)
				for i in range(3):
					party._heroes[i].hp = tick.actors[i].hp
					party._heroes[i].statuses = tick.actors[i].statuses
				_check(party.start_player_turn() and scheduler.advance_turn(),
					"advance real player-turn Block reset and announced beat " + id)
				trace.append(tick)
			var announced := scheduler.get_intents()
			_check(announced == _announced(id, beat), "exact announced sources/beat %d %s" % [beat, id])
			var reversed := announced.duplicate(true)
			reversed.reverse() # phase must execute lower enemy_position first
			var phase := CombatEnemyPhase.new().execute_phase(party, game.enemies, reversed)
			_check(phase == {"ok": true, "events": _events(id, beat)},
				"actual ordered applied phase events beat %d %s" % [beat, id])
			_check(_actors(party.get_heroes()) == HERO_PHASES[id][beat],
				"full hero identities/HP/Block/statuses beat %d %s" % [beat, id])
			_check(_actors(game.enemies.get_enemies()) == ENEMY_PHASES[id][beat],
				"both enemy HP/Block/statuses beat %d %s" % [beat, id])
			_check(scheduler.get_intents() == announced and scheduler._turn_index == beat,
				"combat phase cannot advance intents implicitly " + id)
			trace.append([announced, phase, party.get_heroes(), game.enemies.get_enemies()])
		_check(game.rng.state == initial_rng and game.map.get_route() == initial_route
			and game.selector._selected == initial_cache,
			"no phase or tick spends run RNG or changes selection " + id)
		if repeat == 0:
			previous_trace = trace
		else:
			_check(trace == previous_trace and not trace.is_empty(),
				"two independent same-seed full five-phase traces identical " + id)


func _reject_phase(game: Dictionary, actions: Array, label: String) -> void:
	var before := _snapshot(game)
	var result := CombatEnemyPhase.new().execute_phase(game.party, game.enemies, actions)
	_check(result == {"ok": false, "events": []} and _snapshot(game) == before, label)


func _negative(id: String, value: int) -> void:
	var game := _build(id, value)
	if game.is_empty():
		return
	var before := _snapshot(game)
	var invalid: Array = EXPECTED[id].duplicate(true)
	invalid[0].pattern[0]["type"] = "not_an_intent"
	_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(invalid)).is_empty()
		and not CombatEnemyIntents.new(invalid).is_valid(), "wrong action type rejected " + id)
	invalid = EXPECTED[id].duplicate(true)
	invalid[0].pattern[0]["amount"] = 0.25
	_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(invalid)).is_empty(),
		"fractional amount rejected without integer truncation " + id)
	invalid = EXPECTED[id].duplicate(true)
	invalid[1].enemy_position = 1
	_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(invalid)).is_empty(),
		"duplicate enemy source rejected " + id)
	_check(_snapshot(game) == before, "malformed schedule probes have no state/RNG effect " + id)

	var choice: Dictionary = game.selector.select_current_battle(
		game.map, game.rng, {"Elite": {}})
	for wrong in [["needle_marshal"], ["needle_marshal", "unknown_enemy"],
		["needle_marshal", "needle_marshal"]]:
		var binding := {id: wrong}
		var roster := RunTypedBattleRoster.new().assemble(choice, binding, CATALOGS)
		_check(roster == {"ok": false} and _snapshot(game) == before,
			"wrong-count/unknown/swapped source binding rejects inertly " + id)
	var fight_route := _route(value, "Fight")
	_check(not fight_route.is_empty() and fight_route.map.get_node(fight_route.node).type == "Fight",
		"genuine legal non-Elite Fight route")
	if not fight_route.is_empty():
		var selector := RunFightEncounterSelection.new()
		var initial_rng: int = fight_route.rng.state
		var initial_route: Array = fight_route.map.get_route()
		_check(selector.select_current_battle(fight_route.map, fight_route.rng,
			{"Elite": {id: PATHS[id]}}) == {"success": false}
			and fight_route.rng.state == initial_rng
			and fight_route.map.get_route() == initial_route
			and selector._selected.is_empty(), "Elite pool cannot select a Fight node")

	_reject_phase(game, [
		{"type": "attack", "amount": 3, "target_position": 1, "enemy_position": 1},
		{"type": "shove", "amount": 0, "target_position": 1,
			"direction": -1, "enemy_position": 2}],
		"illegal direction after real attack fails entire batch atomically " + id)
	# Mover Warden remains alive. DOWN the adjacent destination Seamstress.
	_check(game.party.apply_damage(2, 30) and not game.party.is_downed(1)
		and game.party.is_downed(2), "living mover and downed adjacent destination")
	_reject_phase(game, [
		{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 1},
		{"type": "shove", "amount": 0, "target_position": 1,
			"direction": 1, "enemy_position": 2}],
		"later downed-neighbor shove rolls back earlier Block-consuming attack " + id)
	if id == "marshal_frontbutton_relay":
		_reject_phase(game, game.scheduler.get_intents(),
			"authored Frontbutton first-beat shove rejects a downed neighbor")
