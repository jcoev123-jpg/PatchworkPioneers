extends SceneTree
## M04 standalone Marshal crossbeat Elite pair; no changes to the routed global pool.

const PATHS := {
	"marshal_frontpin_bastion": "res://data/encounters/marshal_frontpin_bastion.json",
	"marshal_midline_tumble": "res://data/encounters/marshal_midline_tumble.json",
}
const BINDINGS := {
	"marshal_frontpin_bastion": ["needle_marshal", "button_guard"],
	"marshal_midline_tumble": ["needle_marshal", "seam_ripper"],
}
const CATALOGS := ["res://data/enemies/m04_elites.json", "res://data/enemies/run_enemies.json"]
const STATS := {
	"needle_marshal": [28, "Needle Marshal", "res://assets/paper/enemies/needle_marshal.png"],
	"button_guard": [16, "Button Guard", "res://assets/paper/enemies/button_guard.png"],
	"seam_ripper": [18, "Seam Ripper", "res://assets/paper/enemies/seam_ripper.png"],
}
const EXPECTED := {
	"marshal_frontpin_bastion": [
		{"enemy_position": 1, "pattern": [
			{"type": "debuff", "amount": 1, "target_position": 1, "status": "exposed"},
			{"type": "buff", "amount": 3},
			{"type": "attack", "amount": 4, "target_position": 2},
			{"type": "block", "amount": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 4, "target_position": 1},
			{"type": "attack", "amount": 3, "target_position": 2},
			{"type": "block", "amount": 2},
			{"type": "attack", "amount": 2, "target_position": 3}]}],
	"marshal_midline_tumble": [
		{"enemy_position": 1, "pattern": [
			{"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
			{"type": "attack", "amount": 4, "target_position": 2},
			{"type": "buff", "amount": 3}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 3, "target_position": 2},
			{"type": "block", "amount": 2},
			{"type": "attack", "amount": 2, "target_position": 3},
			{"type": "attack", "amount": 2, "target_position": 1}]}],
}
# Explicit combat snapshots: [id, position, HP, Block, actor-owned statuses].
# These are independent of the phase implementation, including beat-4 wrap.
const HERO_PHASES := {
	"marshal_frontpin_bastion": [
		[["warden", 1, 40, 0, {"exposed": 1}], ["seamstress", 2, 30, 0, {}], ["tinker", 3, 26, 0, {}]],
		[["warden", 1, 40, 0, {}], ["seamstress", 2, 27, 0, {}], ["tinker", 3, 26, 0, {}]],
		[["warden", 1, 40, 0, {}], ["seamstress", 2, 23, 0, {}], ["tinker", 3, 26, 0, {}]],
		[["warden", 1, 40, 0, {}], ["seamstress", 2, 23, 0, {}], ["tinker", 3, 24, 0, {}]],
		[["warden", 1, 34, 0, {"exposed": 1}], ["seamstress", 2, 23, 0, {}], ["tinker", 3, 24, 0, {}]],
	],
	"marshal_midline_tumble": [
		[["warden", 1, 40, 6, {}], ["tinker", 2, 23, 0, {}], ["seamstress", 3, 30, 0, {}]],
		[["warden", 1, 40, 0, {}], ["tinker", 2, 23, 0, {}], ["seamstress", 3, 30, 0, {"weak": 1}]],
		[["warden", 1, 40, 0, {}], ["tinker", 2, 19, 0, {}], ["seamstress", 3, 28, 0, {}]],
		[["warden", 1, 38, 0, {}], ["tinker", 2, 19, 0, {}], ["seamstress", 3, 28, 0, {}]],
		[["warden", 1, 38, 0, {}], ["seamstress", 2, 25, 0, {}], ["tinker", 3, 19, 0, {}]],
	],
}
# Enemy state [id, slot, HP, Block, statuses], keyed independently of global catalogs.
const ENEMY_PHASES := {
	"marshal_frontpin_bastion": [
		[["needle_marshal", 1, 28, 0, {}], ["button_guard", 2, 16, 0, {}]],
		[["needle_marshal", 1, 28, 3, {}], ["button_guard", 2, 16, 0, {}]],
		[["needle_marshal", 1, 28, 3, {}], ["button_guard", 2, 16, 2, {}]],
		[["needle_marshal", 1, 28, 5, {}], ["button_guard", 2, 16, 2, {}]],
		[["needle_marshal", 1, 28, 5, {}], ["button_guard", 2, 16, 2, {}]],
	],
	"marshal_midline_tumble": [
		[["needle_marshal", 1, 28, 0, {}], ["seam_ripper", 2, 18, 0, {}]],
		[["needle_marshal", 1, 28, 0, {}], ["seam_ripper", 2, 18, 2, {}]],
		[["needle_marshal", 1, 28, 0, {}], ["seam_ripper", 2, 18, 2, {}]],
		[["needle_marshal", 1, 28, 3, {}], ["seam_ripper", 2, 18, 2, {}]],
		[["needle_marshal", 1, 28, 3, {}], ["seam_ripper", 2, 18, 2, {}]],
	],
}
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_content()
	var elite_seed := _elite_seed()
	_check(elite_seed > 0, "a seeded map has a truly selectable Elite node")
	if elite_seed > 0:
		_selection(elite_seed)
		_phases(elite_seed)
		_negative(elite_seed)
	for failure in failures:
		printerr(failure)
	print("m04_marshal_crossbeat_elites_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, why: String) -> void:
	checks += 1
	if not value:
		failures.append(why)


func _schedule(id: String) -> Array:
	_check(FileAccess.file_exists(PATHS[id]), "own authored encounter exists " + id)
	if not FileAccess.file_exists(PATHS[id]):
		return []
	return RunFightEncounterSelection._parse_schedule_text(
		FileAccess.get_file_as_string(PATHS[id]))


func _announced(id: String, beat: int) -> Array[Dictionary]:
	var intents: Array[Dictionary] = []
	for source in EXPECTED[id]:
		var action: Dictionary = source.pattern[beat % 4].duplicate(true)
		action["enemy_position"] = source.enemy_position
		intents.append(action)
	return intents


func _events(id: String, beat: int, source1_alive: bool = true) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for index in range(2):
		var action: Dictionary = EXPECTED[id][index].pattern[beat % 4]
		var event := {"type": action.type, "enemy_position": index + 1,
			"applied": source1_alive if index == 0 else true}
		for field in ["target_position", "status", "direction"]:
			if action.has(field):
				event[field] = action[field]
		events.append(event)
	return events


func _rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _route(value: int) -> Dictionary:
	var rng := _rng(value)
	var map := RunMap.new()
	if not map.generate(rng):
		return {}
	for node_id in map.get_legal_choices():
		if map.get_node(node_id).get("type") == "Elite" and map.choose_node(node_id):
			return {"map": map, "rng": rng, "node": node_id}
	return {}


func _elite_seed() -> int:
	for value in range(1, 257):
		if not _route(value).is_empty():
			return value
	return -1


func _party() -> CombatParty:
	var path := "res://data/heroes/starter_party.json"
	var raw := FileAccess.get_file_as_string(path)
	var records := RunTypedBattleRoster._parse_catalog_text(raw)
	_check(not records.is_empty(), "starter hero catalog parses")
	var heroes: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		var matching: Array = records.filter(func(h: Dictionary) -> bool:
			return h.get("id") == id)
		_check(matching.size() == 1, "one real starter hero " + id)
		if matching.size() == 1:
			heroes.append(matching[0])
	var party := CombatParty.new(heroes)
	_check(party.is_valid(), "real CombatParty made from the shipped heroes")
	if party.is_valid():
		_check(_actors(party.get_heroes()) == [
			["warden", 1, 40, 0, {}], ["seamstress", 2, 30, 0, {}],
			["tinker", 3, 26, 0, {}]], "40/30/26 actual living starter formation")
		_check(CombatStartingBlock.new(party).apply() and party.get_hero(1).block == 6,
			"ordinary one-shot Warden opening 6 Block")
	_check(FileAccess.get_file_as_string(path) == raw, "source hero catalog stays unchanged")
	return party


func _actors(actors: Array) -> Array:
	var result: Array = []
	for actor in actors:
		result.append([actor.get("id"), actor.get("position"), actor.get("hp"),
			actor.get("block"), actor.get("statuses", {}).duplicate(true)])
	return result


func _snapshot(game: Dictionary) -> Dictionary:
	var map: RunMap = game.map
	var rng: RandomNumberGenerator = game.rng
	var picker: RunFightEncounterSelection = game.selector
	var party: CombatParty = game.party
	var enemies: CombatEnemies = game.enemies
	var scheduler: CombatEnemyIntents = game.scheduler
	return {"heroes": party.get_heroes(), "enemies": enemies.get_enemies(),
		"intents": scheduler.get_intents(), "turn": scheduler._turn_index,
		"floors": map.get_floors(), "route": map.get_route(),
		"choices": map.get_legal_choices(), "node": map.get_current_node_id(),
		"rng": rng.state, "cache": picker._selected.duplicate(true),
		"bound": picker._bound_map}


func _build(id: String, value: int) -> Dictionary:
	var route := _route(value)
	_check(not route.is_empty(), "actual reachable Elite route " + id)
	if route.is_empty():
		return {}
	var map: RunMap = route.map
	_check(map.get_node(route.node).get("type") == "Elite"
		and map.get_route() == [route.node] and map.get_current_floor() == 1,
		"selected node was legally committed before selection " + id)
	var picker := RunFightEncounterSelection.new()
	var local := {"Elite": {id: PATHS[id]}}
	var rng: RandomNumberGenerator = route.rng
	var before_rng: int = rng.state
	var prediction := RandomNumberGenerator.new()
	prediction.state = before_rng
	prediction.randi_range(0, 0) # the local one-entry candidate selection
	var choice := picker.select_current_battle(map, rng, local)
	_check(choice == {"success": true, "node_type": "Elite",
		"encounter_id": id, "definitions": EXPECTED[id]}, "typed local selection " + id)
	_check(rng.state == prediction.state, "exactly one selector RNG draw " + id)
	if not choice.get("success", false):
		return {}
	var assembled := RunTypedBattleRoster.new().assemble(
		choice, {id: BINDINGS[id].duplicate()}, CATALOGS)
	_check(assembled.get("ok") == true and assembled.get("node_type") == "Elite"
		and assembled.get("encounter_id") == id
		and assembled.get("definitions") == EXPECTED[id],
		"real selected two-actor roster assembled " + id)
	if not assembled.get("ok", false):
		return {}
	var enemies: CombatEnemies = assembled.enemies
	var scheduler := CombatEnemyIntents.new(assembled.definitions)
	_check(enemies.is_valid() and scheduler.is_valid()
		and enemies.get_enemies().size() == 2, "real battle/prevalidated scheduler " + id)
	return {"map": map, "rng": rng, "selector": picker, "choice": choice,
		"enemies": enemies, "scheduler": scheduler, "party": _party()}


func _content() -> void:
	var raw_catalogs: Dictionary = {}
	var originals: Dictionary = {}
	for path in CATALOGS:
		_check(FileAccess.file_exists(path), "required real enemy catalog exists " + path)
		var raw := FileAccess.get_file_as_string(path)
		raw_catalogs[path] = raw
		var records := RunTypedBattleRoster._parse_catalog_text(raw)
		_check(not records.is_empty(), "real enemy catalog parses " + path)
		for record in records:
			if STATS.has(record.id):
				_check(not originals.has(record.id), "unique required actor " + record.id)
				originals[record.id] = record.duplicate(true)
	for id in STATS:
		_check(originals.has(id), "existing actor ID in catalogs " + id)
		if originals.has(id):
			var source: Dictionary = originals[id]
			_check([source.get("max_hp"), source.get("name"), source.get("art_path")] == STATS[id],
				"existing HP/name/art source record exact " + id)
	for id in PATHS:
		var original_text := FileAccess.get_file_as_string(PATHS[id])
		var parsed := _schedule(id)
		_check(parsed == EXPECTED[id] and parsed.size() == 2,
			"both source records, all four actions, every field exact " + id)
		var intents := CombatEnemyIntents.new(parsed)
		_check(intents.is_valid(), "CombatEnemyIntents validates original schedule " + id)
		if not intents.is_valid():
			continue
		var before := parsed.duplicate(true)
		for beat in range(9):
			_check(intents.get_intents() == _announced(id, beat),
				"fixed beat %d and complete double wrap %s" % [beat, id])
			_check(intents.advance_turn(), "explicit authored advance " + id)
		_check(parsed == before and FileAccess.get_file_as_string(PATHS[id]) == original_text,
			"schedule inputs not modified by parser or scheduler " + id)
		var detached := intents.get_intents()
		detached[0]["amount"] = 999
		_check(intents.get_intents() == _announced(id, 9), "announcements detached " + id)
	for path in CATALOGS:
		_check(FileAccess.get_file_as_string(path) == raw_catalogs[path],
			"complete original catalog bytes unchanged " + path)


func _selection(value: int) -> void:
	for id in PATHS:
		var first := _build(id, value)
		var second := _build(id, value)
		if first.is_empty() or second.is_empty():
			continue
		_check(first.map.get_floors() == second.map.get_floors()
			and first.map.get_route() == second.map.get_route()
			and first.rng.state == second.rng.state and first.choice == second.choice
			and first.enemies.get_enemies() == second.enemies.get_enemies(),
			"independent same-seed map, pick and typed roster replay " + id)
		var snapshot := _snapshot(first)
		var original: Dictionary = first.choice.duplicate(true)
		var cached: Dictionary = first.selector.select_current_battle(
			first.map, first.rng, {"Elite": {}})
		_check(cached == original and _snapshot(first) == snapshot,
			"cached reentry uses no pool read, state change or RNG " + id)
		cached.definitions[0].pattern[0]["amount"] = 888
		_check(first.selector.select_current_battle(first.map, first.rng,
			{"Elite": {"forged": "res://data/encounters/missing.json"}}) == original
			and _snapshot(first) == snapshot, "cached choice deeply copied " + id)
		for index in range(2):
			var actor: Dictionary = first.enemies.get_enemy(index + 1)
			var actor_id: String = BINDINGS[id][index]
			_check(actor.get("id") == actor_id and actor.get("position") == index + 1
				and actor.get("hp") == STATS[actor_id][0]
				and actor.get("max_hp") == STATS[actor_id][0]
				and actor.get("name") == STATS[actor_id][1]
				and actor.get("art_path") == STATS[actor_id][2]
				and actor.get("block") == 0,
				"real enemy identity/slot/HP/Block/art record " + id)
		_check(_snapshot(first) == snapshot, "all selection and roster reads inert " + id)


func _phases(value: int) -> void:
	for id in PATHS:
		var first_trace: Array = []
		for replay in range(2):
			var game := _build(id, value)
			if game.is_empty():
				continue
			var party: CombatParty = game.party
			var enemies: CombatEnemies = game.enemies
			var scheduler: CombatEnemyIntents = game.scheduler
			var rng_before: int = game.rng.state
			var selection_before: Dictionary = game.selector._selected.duplicate(true)
			var route_before: Array = game.map.get_route()
			seed(303014)
			var next_global := randi()
			seed(303014)
			var trace: Array = []
			for beat in range(5):
				if beat > 0:
					var before_tick := party.get_heroes()
					var tick := CombatStatusTurnBatch.new().tick_side(
						"heroes", before_tick)
					_check(tick.get("ok") == true and tick.get("events", []).size() == 3,
						"real owner-turn status transition " + id)
					if not tick.get("ok", false):
						break
					var expected_tick := before_tick.duplicate(true)
					for hero in expected_tick:
						hero["statuses"] = {}
					_check(tick.actors == expected_tick
						and tick.events.map(func(e: Dictionary) -> int:
							return e.bleed_hp_loss) == [0, 0, 0]
						and party.get_heroes() == before_tick,
						"owner-tick is detached; Exposed/Weak expire, no invented Bleed " + id)
					for index in range(3):
						party._heroes[index]["hp"] = tick.actors[index].hp
						party._heroes[index]["statuses"] = tick.actors[index].statuses
					_check(party.start_player_turn() and scheduler.advance_turn(),
						"hero turn resets Block then explicit enemy beat advances " + id)
					trace.append(tick)
				var announced := scheduler.get_intents()
				_check(announced == _announced(id, beat),
					"complete announced pair before phase " + id)
				var previous_turn: int = scheduler._turn_index
				var feed := announced.duplicate(true)
				feed.reverse() # prove source-position ordering, not input order
				var phase := CombatEnemyPhase.new().execute_phase(party, enemies, feed)
				_check(phase == {"ok": true, "events": _events(id, beat)},
					"exact ascending-source events for beat %d %s" % [beat, id])
				_check(_actors(party.get_heroes()) == HERO_PHASES[id][beat],
					"all hero IDs/slots/HP/Block/statuses after beat %d %s" % [beat, id])
				_check(_actors(enemies.get_enemies()) == ENEMY_PHASES[id][beat],
					"all enemy IDs/HP/Block after beat %d %s" % [beat, id])
				_check(scheduler._turn_index == previous_turn
					and scheduler.get_intents() == announced,
					"phase does not auto-advance fixed intentions " + id)
				trace.append([announced, phase, party.get_heroes(), enemies.get_enemies()])
			_check(scheduler.get_intents() == _announced(id, 4)
				and game.rng.state == rng_before and randi() == next_global
				and game.selector._selected == selection_before
				and game.map.get_route() == route_before,
				"five full phases wrap and spend no run/global RNG or selector state " + id)
			if replay == 0:
				first_trace = trace
			else:
				_check(trace == first_trace, "all five phase/tick outputs replay exactly " + id)


func _reject_phase(game: Dictionary, actions: Array, why: String) -> void:
	var before := _snapshot(game)
	seed(22507)
	var next_global := randi()
	seed(22507)
	var result := CombatEnemyPhase.new().execute_phase(game.party, game.enemies, actions)
	_check(result == {"ok": false, "events": []}
		and _snapshot(game) == before and randi() == next_global, why)


func _negative(value: int) -> void:
	for id in PATHS:
		var game := _build(id, value)
		if game.is_empty():
			continue
		var before := _snapshot(game)
		var malformed: Array = EXPECTED[id].duplicate(true)
		malformed[0].pattern[0]["target_position"] = 4
		_check(not CombatEnemyIntents.new(malformed).is_valid(),
			"invalid target rejected by intent validator " + id)
		_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(malformed)).is_empty(),
			"invalid in-bounds target rejected by JSON schedule parser " + id)
		malformed = EXPECTED[id].duplicate(true)
		malformed[0].pattern[0]["amount"] = 0.5
		_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(malformed)).is_empty(),
			"fractional action amount cannot truncate into a legal intent " + id)
		malformed = EXPECTED[id].duplicate(true)
		malformed[1].enemy_position = 1
		_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(malformed)).is_empty(),
			"duplicate enemy source is invalid " + id)
		_check(_snapshot(game) == before,
			"malformed schedule parsing leaves full battle/map/cache/RNG alone " + id)

		_reject_phase(game, [
			{"type": "attack", "enemy_position": 1, "amount": 3, "target_position": 1},
			{"type": "attack", "enemy_position": 2, "amount": 4, "target_position": 4}],
			"invalid later target rejects complete phase without damage " + id)
		_reject_phase(game, [
			{"type": "attack", "enemy_position": 1, "amount": 3, "target_position": 1},
			{"type": "attack", "enemy_position": 1, "amount": 3, "target_position": 2}],
			"duplicate phase source rejects atomically " + id)
		_reject_phase(game, [
			{"type": "attack", "enemy_position": 1, "amount": 3, "target_position": 1},
			{"type": "attack", "enemy_position": 3, "amount": 3, "target_position": 2}],
			"nonexistent third source rejects atomically " + id)

		# Earlier attack would consume actual Warden Block; later source's
		# attempted shove is illegal because the adjacent participant is downed.
		_check(game.party.apply_damage(3, 26) and game.party.is_downed(3),
			"real Tinker downed for impossible adjacent swap " + id)
		_reject_phase(game, [
			{"type": "attack", "enemy_position": 1, "amount": 4, "target_position": 1},
			{"type": "shove", "enemy_position": 2, "amount": 0,
				"target_position": 2, "direction": 1}],
			"later impossible shove rolls back earlier real attack " + id)
		if id == "marshal_midline_tumble":
			var original := _build(id, value)
			if not original.is_empty():
				_check(original.party.apply_damage(2, 30)
					and original.party.is_downed(2), "real first-beat shove mover downed")
				_reject_phase(original, original.scheduler.get_intents(),
					"actual Tumble scheduled shove fails closed on downed mover")

		# Even a slain but correctly authored source must not be rejected:
		# its event remains unapplied and the living companion still attacks.
		game = _build(id, value)
		if game.is_empty():
			continue
		var source_hp: int = game.enemies.get_enemy(1).hp
		_check(game.enemies.apply_damage(1, source_hp)
			and game.enemies.is_slain(1) and not game.enemies.is_slain(2),
			"actual source 1 killed, companion 2 lives " + id)
		var killed_enemies: Array = game.enemies.get_enemies()
		var killed_intents: Array = game.scheduler.get_intents()
		var killed_state := _snapshot(game)
		var phase := CombatEnemyPhase.new().execute_phase(
			game.party, game.enemies, killed_intents.duplicate(true))
		var expected_heroes: Array = []
		if id == "marshal_frontpin_bastion":
			expected_heroes = [
				["warden", 1, 40, 2, {}], ["seamstress", 2, 30, 0, {}],
				["tinker", 3, 26, 0, {}]]
		else:
			expected_heroes = [
				["warden", 1, 40, 6, {}], ["seamstress", 2, 27, 0, {}],
				["tinker", 3, 26, 0, {}]]
		_check(phase == {"ok": true, "events": _events(id, 0, false)}
			and _actors(game.party.get_heroes()) == expected_heroes
			and game.enemies.get_enemies() == killed_enemies
			and game.scheduler.get_intents() == killed_intents
			and game.rng.state == killed_state.rng
			and game.selector._selected == killed_state.cache
			and game.map.get_route() == killed_state.route,
			"slain source unapplied; surviving source resolves actual targeted hit " + id)

		# Rejected *selection* is also inert before and after binding.
		var fresh := _route(value)
		_check(not fresh.is_empty(), "fresh seeded chosen Elite for selector failures " + id)
		if fresh.is_empty():
			continue
		var selector := RunFightEncounterSelection.new()
		var original_route: Array = fresh.map.get_route()
		var original_floors: Array = fresh.map.get_floors()
		var original_rng: int = fresh.rng.state
		var rejected := selector.select_current_battle(fresh.map, fresh.rng,
			{"Elite": {id: "res://data/encounters/nonexistent.json"}})
		_check(rejected == {"success": false}
			and selector._selected.is_empty() and selector._bound_map == null
			and fresh.rng.state == original_rng
			and fresh.map.get_route() == original_route
			and fresh.map.get_floors() == original_floors,
			"missing schedule rejects with zero RNG/cache/map side effects " + id)
		rejected = selector.select_current_battle(fresh.map, fresh.rng,
			{"Fight": {id: PATHS[id]}})
		_check(rejected == {"success": false}
			and selector._selected.is_empty() and selector._bound_map == null
			and fresh.rng.state == original_rng and fresh.map.get_route() == original_route,
			"wrong node-type pool rejected inertly " + id)
		var good := selector.select_current_battle(fresh.map, fresh.rng,
			{"Elite": {id: PATHS[id]}})
		_check(good.get("success") == true and good.get("encounter_id") == id,
			"rejected first retrieval does not poison a later real selection " + id)
		var cache_before := selector._selected.duplicate(true)
		var rng_before: int = fresh.rng.state
		var other := _route(value)
		_check(not other.is_empty(), "independent real Elite route for stale selector " + id)
		if not other.is_empty():
			rejected = selector.select_current_battle(other.map, other.rng,
				{"Elite": {id: PATHS[id]}})
			_check(rejected == {"success": false}
				and selector._selected == cache_before and selector._bound_map == fresh.map
				and fresh.rng.state == rng_before
				and other.rng.state == original_rng
				and fresh.map.get_route() == original_route
				and other.map.get_route() == original_route,
				"stale cross-map selector request rejects without cache/route/RNG change " + id)
