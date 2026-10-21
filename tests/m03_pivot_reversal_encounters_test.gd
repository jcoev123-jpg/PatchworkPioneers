extends SceneTree

## Paired M03 positional Fights: fixed authored beats, ordered real combat,
## deterministic map selection and atomic rejection. No live pool registration.

const FRONT := "res://data/encounters/front_hem_pivot.json"
const REAR := "res://data/encounters/rear_spool_reversal.json"
const STARTER := "res://data/encounters/starter_attacks.json"
const BACKSTITCH := "res://data/encounters/backstitch_displacement.json"
const HERO_PATH := "res://data/heroes/starter_party.json"
const ROSTER_PATH := "res://data/enemies/run_enemies.json"

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_schedules()
	_test_three_phases("front_hem_pivot", ["button_guard", "fray_scavenger"])
	_test_three_phases("rear_spool_reversal", ["spool_stalker", "seam_ripper"])
	_test_selection()
	_test_rejections()
	if failures.is_empty():
		print("m03_pivot_reversal_encounters_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("m03_pivot_reversal_encounters_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)


func _expected(name: String) -> Array:
	if name == "front_hem_pivot":
		return [
			{"enemy_position": 1, "pattern": [
				{"type": "shove", "amount": 0, "target_position": 1, "direction": 1},
				{"type": "block", "amount": 2},
				{"type": "attack", "amount": 2, "target_position": 3}]},
			{"enemy_position": 2, "pattern": [
				{"type": "attack", "amount": 2, "target_position": 1},
				{"type": "attack", "amount": 2, "target_position": 2},
				{"type": "buff", "amount": 2}]}]
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 2, "target_position": 2},
			{"type": "attack", "amount": 2, "target_position": 2},
			{"type": "buff", "amount": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "shove", "amount": 0, "target_position": 3, "direction": -1},
			{"type": "block", "amount": 2},
			{"type": "attack", "amount": 2, "target_position": 3}]}]


func _path(name: String) -> String:
	return FRONT if name == "front_hem_pivot" else REAR


func _parsed(path: String) -> Array:
	_check(FileAccess.file_exists(path), path + ": shipped file exists")
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, path + ": file is readable")
	if file == null:
		return []
	var result := RunFightEncounterSelection._parse_schedule_text(file.get_as_text())
	file.close()
	return result


func _json_actors(path: String) -> Array:
	_check(FileAccess.file_exists(path), path + ": actual actor catalog exists")
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, path + ": actual actor catalog opens")
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	_check(parsed is Array, path + ": actual catalog is an array")
	if not parsed is Array:
		return []
	var records: Array = parsed
	for record in records:
		if record is Dictionary and record.get("max_hp") is float:
			var hp: float = record["max_hp"]
			_check(is_finite(hp) and floorf(hp) == hp,
				path + ": authored max_hp is mathematically integral")
			if is_finite(hp) and floorf(hp) == hp:
				record["max_hp"] = int(hp)
	return records


func _record(records: Array, id: String) -> Dictionary:
	var matches: Array = []
	for entry in records:
		if entry is Dictionary and entry.get("id") == id:
			matches.append(entry)
	_check(matches.size() == 1, id + ": exactly one named catalog record")
	return matches[0].duplicate(true) if matches.size() == 1 else {}


func _party() -> CombatParty:
	var catalog := _json_actors(HERO_PATH)
	var definitions: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		definitions.append(_record(catalog, id))
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "real three-hero starter party built")
	return party


func _enemies(ids: Array) -> CombatEnemies:
	var catalog := _json_actors(ROSTER_PATH)
	var definitions: Array = []
	for id in ids:
		definitions.append(_record(catalog, id))
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid(), "real two-source roster built: " + str(ids))
	return enemies


func _announced(definitions: Array, beat: int) -> Array:
	var result: Array = []
	for source in definitions:
		var action: Dictionary = source["pattern"][beat % 3].duplicate(true)
		action["enemy_position"] = source["enemy_position"]
		result.append(action)
	return result


func _events(name: String, turn: int) -> Array:
	if name == "front_hem_pivot":
		match turn:
			0:
				return [
					{"type": "shove", "enemy_position": 1, "target_position": 1,
						"direction": 1, "applied": true},
					{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true}]
			1:
				return [
					{"type": "block", "enemy_position": 1, "applied": true},
					{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true}]
			2:
				return [
					{"type": "attack", "enemy_position": 1, "target_position": 3, "applied": true},
					{"type": "buff", "enemy_position": 2, "applied": true}]
	else:
		match turn:
			0:
				return [
					{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
					{"type": "shove", "enemy_position": 2, "target_position": 3,
						"direction": -1, "applied": true}]
			1:
				return [
					{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
					{"type": "block", "enemy_position": 2, "applied": true}]
			2:
				return [
					{"type": "buff", "enemy_position": 1, "applied": true},
					{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true}]
	return []


func _hero_rows(party: CombatParty) -> Array:
	var rows: Array = []
	for hero in party.get_heroes():
		rows.append([hero.get("id"), hero.get("hp"), hero.get("block"), hero.get("position")])
	return rows


func _enemy_rows(enemies: CombatEnemies) -> Array:
	var rows: Array = []
	for enemy in enemies.get_enemies():
		rows.append([enemy.get("id"), enemy.get("hp"), enemy.get("block"), enemy.get("position")])
	return rows


func _test_schedules() -> void:
	for name in ["front_hem_pivot", "rear_spool_reversal"]:
		var expected := _expected(name)
		var data := _parsed(_path(name))
		_check(data == expected, name + ": complete literal two-source three-beat JSON")
		_check(data.size() == 2, name + ": exactly two authored source entries")
		if data.size() != 2:
			continue
		for source in range(2):
			_check(data[source].size() == 2
				and data[source]["enemy_position"] == source + 1
				and data[source]["enemy_position"] is int
				and data[source]["pattern"].size() == 3,
				name + ": source %d has only its integer position and three beats" % (source + 1))
			for beat in range(3):
				var action: Dictionary = data[source]["pattern"][beat]
				_check(action == expected[source]["pattern"][beat]
					and action.get("amount") is int
					and (not action.has("target_position") or action["target_position"] is int)
					and (not action.has("direction") or action["direction"] is int),
					name + ": source %d beat %d exact fields and integer values" % [source + 1, beat + 1])
		var scheduler := CombatEnemyIntents.new(data)
		_check(scheduler.is_valid(), name + ": canonical CombatEnemyIntents valid")
		for turn in range(7):
			_check(scheduler.get_intents() == _announced(expected, turn),
				name + ": exact ordered announcement for beat " + str(turn + 1))
			_check(scheduler.advance_turn(), name + ": advance exactly once")
		# Caller edits cannot reach schedule storage or later announcements.
		var isolated := CombatEnemyIntents.new(data)
		var copy := isolated.get_intents()
		var original := copy.duplicate(true)
		copy[0]["amount"] = 99
		data[0]["pattern"][0]["amount"] = 55
		_check(isolated.get_intents() == original,
			name + ": scheduler owns independent copy of definitions and announcements")
	# Older shipped encounters must remain accepted, with their actual authored actions.
	for path in [STARTER, BACKSTITCH]:
		var parsed := _parsed(path)
		_check(parsed.size() == 2 and CombatEnemyIntents.new(parsed).is_valid(),
			path + ": prior named schedule still parses and validates")
		if path == STARTER:
			_check(parsed == [
				{"enemy_position": 1, "pattern": [
					{"type": "attack", "amount": 1, "target_position": 1},
					{"type": "attack", "amount": 1, "target_position": 2},
					{"type": "attack", "amount": 1, "target_position": 3}]},
				{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]}],
				"starter_attacks unchanged complete action cycles")
		else:
			_check(parsed == [
				{"enemy_position": 1, "pattern": [
					{"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
					{"type": "attack", "amount": 2, "target_position": 2},
					{"type": "block", "amount": 1}]},
				{"enemy_position": 2, "pattern": [
					{"type": "attack", "amount": 2, "target_position": 3},
					{"type": "debuff", "amount": 1, "target_position": 2, "status": "weak"},
					{"type": "attack", "amount": 2, "target_position": 1}]}],
				"backstitch_displacement unchanged complete action cycles")


func _play(name: String, ids: Array) -> Dictionary:
	var party := _party()
	var enemies := _enemies(ids)
	var scheduler := CombatEnemyIntents.new(_parsed(_path(name)))
	_check(scheduler.is_valid() and party.is_valid() and enemies.is_valid(),
		name + ": full valid real service preconditions")
	var hp := [40, 30, 26]
	for index in range(3):
		_check(party.get_hero(index + 1).get("id") == ["warden", "seamstress", "tinker"][index]
			and party.get_hero(index + 1).get("hp") == hp[index]
			and party.get_hero(index + 1).get("block") == 0,
			name + ": real starter HP, position, identity and zero opening Block")
	var enemy_hp := [16, 14] if name == "front_hem_pivot" else [14, 18]
	for index in range(2):
		_check(enemies.get_enemy(index + 1).get("id") == ids[index]
			and enemies.get_enemy(index + 1).get("hp") == enemy_hp[index],
			name + ": exact real enemy identity and starting HP")
	var originals: Dictionary = {}
	for hero in party._heroes:
		originals[hero["id"]] = hero
	var opening := CombatStartingBlock.new(party)
	_check(opening.apply() and not opening.apply(), name + ": Warden opens with exactly one Block 6 grant")
	_check(party.get_hero(1).get("block") == 6, name + ": opening Block on Warden")
	var expected_heroes := []
	if name == "front_hem_pivot":
		expected_heroes = [
			[["seamstress", 28, 0, 1], ["warden", 40, 6, 2], ["tinker", 26, 0, 3]],
			[["seamstress", 28, 0, 1], ["warden", 38, 0, 2], ["tinker", 26, 0, 3]],
			[["seamstress", 28, 0, 1], ["warden", 38, 0, 2], ["tinker", 24, 0, 3]]]
	else:
		expected_heroes = [
			[["warden", 40, 6, 1], ["tinker", 26, 0, 2], ["seamstress", 28, 0, 3]],
			[["warden", 40, 0, 1], ["tinker", 24, 0, 2], ["seamstress", 28, 0, 3]],
			[["warden", 40, 0, 1], ["tinker", 24, 0, 2], ["seamstress", 26, 0, 3]]]
	var all_events: Array = []
	var snapshots: Array = []
	for turn in range(3):
		if turn > 0:
			_check(party.start_player_turn(), name + ": next player turn resets hero Block")
			for hero in party.get_heroes():
				_check(hero.get("block") == 0, name + ": all hero Block reset before T" + str(turn + 1))
		var announcements := scheduler.get_intents()
		_check(announcements == _announced(_expected(name), turn),
			name + ": source ordered turn intents before phase " + str(turn + 1))
		var before_intents := announcements.duplicate(true)
		var result := phase.execute_phase(party, enemies, announcements)
		_check(result == {"ok": true, "events": _events(name, turn)},
			name + ": exact source-ordered event list T" + str(turn + 1))
		_check(announcements == before_intents and scheduler.get_intents() == before_intents,
			name + ": phase cannot mutate intents or advance scheduler")
		_check(_hero_rows(party) == expected_heroes[turn],
			name + ": exact actor position, HP and Block T" + str(turn + 1)
				+ " got " + str(_hero_rows(party)))
		var enemy_blocks := [0, 0] if turn == 0 else (
			[2, 0] if name == "front_hem_pivot" else [0, 2])
		if turn == 2:
			enemy_blocks = [2, 2]
		_check(_enemy_rows(enemies) == [
			[ids[0], enemy_hp[0], enemy_blocks[0], 1],
			[ids[1], enemy_hp[1], enemy_blocks[1], 2]],
			name + ": enemy identities, HP and precise Block T" + str(turn + 1))
		for position in range(1, 4):
			var hero := party.get_hero(position)
			_check(is_same(party._heroes[position - 1], originals[hero["id"]])
				and hero.get("statuses", {}) == {},
				name + ": real original hero dictionary and status ownership at slot "
					+ str(position))
		all_events.append(result.duplicate(true))
		snapshots.append([party.get_heroes(), enemies.get_enemies()])
		_check(scheduler.advance_turn(), name + ": caller advances exactly once T" + str(turn + 1))
	_check(scheduler._turn_index == 3
		and scheduler.get_intents() == _announced(_expected(name), 0),
		name + ": three advances wrap to exact turn-4 first intents")
	return {"events": all_events, "snapshots": snapshots,
		"heroes": party.get_heroes(), "enemies": enemies.get_enemies()}


func _test_three_phases(name: String, ids: Array) -> void:
	seed(763205)
	var expected_global := randi()
	seed(763205)
	var first := _play(name, ids)
	_check(randi() == expected_global, name + ": no global RNG draw across actual three phases")
	var second := _play(name, ids)
	_check(first == second and first["events"].size() == 3
		and first["snapshots"].size() == 3,
		name + ": two independently reconstructed complete timelines replay identically")
	# Additional status-ownership probe: statuses follow the swapped actor, not a slot.
	var party := _party()
	var enemies := _enemies(ids)
	party._heroes[0]["statuses"] = {"weak": 1}
	party._heroes[1]["statuses"] = {"bleed": 1}
	party._heroes[2]["statuses"] = {"bleed": 2}
	var old_heroes := party._heroes.duplicate()
	var owned_statuses := [{"weak": 1}, {"bleed": 1}, {"bleed": 2}]
	var first_intents := CombatEnemyIntents.new(_parsed(_path(name))).get_intents()
	_check(phase.execute_phase(party, enemies, first_intents).get("ok") == true,
		name + ": first special succeeds with authored actor-bound statuses")
	var expected_order := [1, 0, 2] if name == "front_hem_pivot" else [0, 2, 1]
	for index in range(3):
		var original: Dictionary = old_heroes[expected_order[index]]
		_check(is_same(party._heroes[index], original)
			and party.get_hero(index + 1).get("statuses", {})
				== owned_statuses[expected_order[index]],
			name + ": swapped original object retains its own literal status stack")


func _rng(value: int) -> RandomNumberGenerator:
	var result := RandomNumberGenerator.new()
	result.seed = value
	return result


func _opening(map: RunMap) -> String:
	for id in map.get_legal_choices():
		if map.get_node(id).get("type") == "Fight":
			return id
	return ""


func _test_selection() -> void:
	var pool := {"rear_spool_reversal": REAR, "front_hem_pivot": FRONT}
	var seen: Dictionary = {}
	seed(271828)
	var expected_global := randi()
	seed(271828)
	for seed_value in range(101, 131):
		var rng := _rng(seed_value)
		var replay_rng := _rng(seed_value)
		var oracle_rng := _rng(seed_value)
		var map := RunMap.new()
		var replay_map := RunMap.new()
		var oracle_map := RunMap.new()
		_check(map.generate(rng) and replay_map.generate(replay_rng)
			and oracle_map.generate(oracle_rng), "seeded real RunMap generation")
		_check(map.get_floors() == replay_map.get_floors()
			and map.get_floors() == oracle_map.get_floors(),
			"identical seeds produce the same real connected map")
		var id := _opening(map)
		_check(not id.is_empty() and map.get_legal_choices().has(id)
			and map.get_node(id).get("type") == "Fight",
			"actual opening legal Fight exists")
		if id.is_empty():
			continue
		_check(map.choose_node(id) and replay_map.choose_node(id)
			and oracle_map.choose_node(id), "three real routes enter same legal Fight")
		var ids: Array = pool.keys()
		ids.sort()
		var picked: String = ids[oracle_rng.randi_range(0, ids.size() - 1)]
		var expected_state := oracle_rng.state
		var selector := RunFightEncounterSelection.new()
		var answer := selector.select_current_fight(map, rng, pool)
		_check(answer == {"success": true, "encounter_id": picked,
			"definitions": _expected(picked)}
			and rng.state == expected_state,
			"local two-path selection takes exactly one sorted run RNG draw")
		_check(map.get_route() == [id] and map.get_current_node_id() == id,
			"selector leaves real map route unchanged")
		var reverse_pool := {"front_hem_pivot": FRONT, "rear_spool_reversal": REAR}
		var replay := RunFightEncounterSelection.new().select_current_fight(
			replay_map, replay_rng, reverse_pool)
		_check(replay == answer and replay_rng.state == expected_state,
			"fresh equivalent map/RNG/selector reproduces choice with reversed insertion")
		var immutable := answer.duplicate(true)
		answer["definitions"][0]["pattern"][0]["amount"] = 999
		answer["encounter_id"] = "caller_corruption"
		var cached := selector.select_current_fight(map, rng, {})
		_check(cached == immutable and rng.state == expected_state,
			"cached Fight choice is independent of caller mutations and costs zero draws")
		cached["definitions"][0]["pattern"].clear()
		_check(selector.select_current_fight(map, rng, pool) == immutable
			and rng.state == expected_state,
			"second copied choice cannot mutate cache or spend run RNG")
		seen[picked] = true
		if seen.size() == 2:
			break
	_check(seen.has("front_hem_pivot") and seen.has("rear_spool_reversal"),
		"both new Fights are reachable through the local two-path pool")
	_check(randi() == expected_global, "map, selector, replay and cache never draw global RNG")


func _with_replaced(name: String, position: int, action: Dictionary) -> Array:
	var result := _expected(name)
	result[position - 1]["pattern"][0] = action
	return result


func _reject_phase(name: String, ids: Array, actions: Array, down_position: int = 0) -> void:
	var party := _party()
	var enemies := _enemies(ids)
	_check(CombatStartingBlock.new(party).apply(), name + ": negative fixture has opening Block")
	if down_position > 0:
		_check(party.apply_damage(down_position, party.get_hero(down_position)["hp"]),
			name + ": downed adjacent hero was alive and now is downed")
		_check(party.is_downed(down_position), name + ": downed precondition")
	var before_heroes := party.get_heroes()
	var before_enemies := enemies.get_enemies()
	var before_actions := actions.duplicate(true)
	seed(183739)
	var oracle := randi()
	seed(183739)
	_check(phase.execute_phase(party, enemies, actions) == {"ok": false, "events": []},
		name + ": entire invalid phased batch rejects")
	_check(randi() == oracle, name + ": rejecting phase draws no global RNG")
	_check(party.get_heroes() == before_heroes
		and enemies.get_enemies() == before_enemies
		and actions == before_actions, name + ": rejection preserves every HP/Block/position/status/intent")


func _test_rejections() -> void:
	var front := _expected("front_hem_pivot")
	var rear := _expected("rear_spool_reversal")
	var malformed: Array = [
		_with_replaced("front_hem_pivot", 1,
			{"type": "shove", "amount": 0, "target_position": 1, "direction": 0}),
		_with_replaced("front_hem_pivot", 1,
			{"type": "shove", "amount": 0, "target_position": 1, "direction": -1}),
		_with_replaced("rear_spool_reversal", 2,
			{"type": "shove", "amount": 0, "target_position": 3, "direction": 1}),
		_with_replaced("rear_spool_reversal", 2,
			{"type": "shove", "amount": 0, "target_position": 0, "direction": 1}),
		_with_replaced("rear_spool_reversal", 2,
			{"type": "shove", "amount": 0, "target_position": 4, "direction": -1}),
		_with_replaced("rear_spool_reversal", 2,
			{"type": "shove", "amount": 0, "target_position": 3, "direction": 0}),
		_with_replaced("rear_spool_reversal", 2,
			{"type": "shove", "amount": 0, "target_position": 3, "direction": -1.5})]
	var duplicate := front.duplicate(true)
	duplicate[1]["enemy_position"] = 1
	malformed.append(duplicate)
	for index in range(malformed.size()):
		var bad: Array = malformed[index]
		_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(bad)).is_empty()
			and not CombatEnemyIntents.new(bad).is_valid(),
			"bad shove/target/direction or duplicate source rejects parsed schedule " + str(index))
		var actions: Array = []
		for source in bad:
			var beat: Dictionary = source["pattern"][0].duplicate(true)
			beat["enemy_position"] = source["enemy_position"]
			actions.append(beat)
		var ids := (["button_guard", "fray_scavenger"] if index < 2 or index == 7
			else ["spool_stalker", "seam_ripper"])
		_reject_phase("invalid first-beat fixture " + str(index), ids, actions)
	# Stage a valid early action followed by a malformed late action: no partial commit.
	var bad_second := [
		{"type": "attack", "amount": 2, "target_position": 2, "enemy_position": 1},
		{"type": "shove", "amount": 0, "target_position": 3,
			"direction": 0, "enemy_position": 2}]
	_reject_phase("late zero direction", ["spool_stalker", "seam_ripper"], bad_second)
	var duplicate_actions := [
		{"type": "shove", "amount": 0, "target_position": 1,
			"direction": 1, "enemy_position": 1},
		{"type": "attack", "amount": 2, "target_position": 1, "enemy_position": 1}]
	_reject_phase("duplicate source with valid early shove",
		["button_guard", "fray_scavenger"], duplicate_actions)
	_reject_phase("front shove has downed adjacent Seamstress",
		["button_guard", "fray_scavenger"], _announced(front, 0), 2)
	_reject_phase("rear later shove has downed adjacent Seamstress",
		["spool_stalker", "seam_ripper"], _announced(rear, 0), 2)
	# Positive control proves both shove directions really work on live neighbors.
	for name in ["front_hem_pivot", "rear_spool_reversal"]:
		var ids := (["button_guard", "fray_scavenger"]
			if name == "front_hem_pivot" else ["spool_stalker", "seam_ripper"])
		var party := _party()
		var enemies := _enemies(ids)
		var result := phase.execute_phase(party, enemies, _announced(_expected(name), 0))
		_check(result == {"ok": true, "events": _events(name, 0)}
			and party.get_hero(2).get("id") ==
				("warden" if name == "front_hem_pivot" else "tinker"),
			name + ": live adjacent shove succeeds when both occupants are living")
