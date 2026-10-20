extends SceneTree

const FLANK := "res://data/encounters/ragged_needle_flank.json"
const STARTER := "res://data/encounters/starter_attacks.json"
const GUARD := "res://data/encounters/guard_counterattack.json"
const PARTY := "res://data/heroes/starter_party.json"
const ENEMIES := "res://data/enemies/starter_enemies.json"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_authored_beats()
	_test_phases_and_fresh_replay()
	_test_seeded_selection_and_predecessors()
	_test_slain_and_rejected_inputs()
	if failures.is_empty():
		print("ragged_needle_flank_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("ragged_needle_flank_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)


func _load_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "opens shipped file " + path)
	if file == null:
		return ""
	var result := file.get_as_text()
	file.close()
	return result


func _actor_data(path: String) -> Array:
	var value = JSON.parse_string(_load_text(path))
	_check(value is Array, path + " is a JSON array")
	if not value is Array:
		return []
	var definitions: Array = value
	for entry in definitions:
		if not entry is Dictionary or not entry.get("max_hp") is float:
			# Godot JSON numbers are floats; only authored integral positive HP is valid.
			if not entry is Dictionary or not entry.get("max_hp") is int:
				_check(false, path + " contains numeric actor HP")
				return []
		var hp: float = float(entry["max_hp"])
		if not is_finite(hp) or hp <= 0 or floorf(hp) != hp:
			_check(false, path + " contains positive integral HP")
			return []
		entry["max_hp"] = int(hp)
	return definitions


func _expected_flank() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 3},
			{"type": "attack", "amount": 1, "target_position": 1}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 3},
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 2}]}
	]


func _expected_previous(name: String) -> Array:
	if name == "starter_attacks":
		return [
			{"enemy_position": 1, "pattern": [
				{"type": "attack", "amount": 1, "target_position": 1},
				{"type": "attack", "amount": 1, "target_position": 2},
				{"type": "attack", "amount": 1, "target_position": 3}]},
			{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]}]
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 1}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 3},
			{"type": "block", "amount": 1}]}]


func _announced(definitions: Array, beat: int) -> Array:
	var result: Array = []
	for source in definitions:
		var action: Dictionary = source["pattern"][beat % source["pattern"].size()].duplicate(true)
		action["enemy_position"] = source["enemy_position"]
		result.append(action)
	return result


func _event(kind: String, slot: int, applied: bool, target: int = 0) -> Dictionary:
	var result := {"type": kind, "enemy_position": slot, "applied": applied}
	if kind == "attack":
		result["target_position"] = target
	return result


func _test_authored_beats() -> void:
	var raw := _load_text(FLANK)
	var parsed = JSON.parse_string(raw)
	_check(parsed is Array and parsed.size() == 2, "flank JSON has exactly two source records")
	var expected := _expected_flank()
	var definitions := RunFightEncounterSelection._parse_schedule_text(raw)
	_check(definitions == expected, "parser preserves both complete four-action patterns, slots, fields")
	if definitions != expected:
		return
	var scheduler := CombatEnemyIntents.new(definitions)
	_check(scheduler.is_valid() and scheduler.get_intents().size() == 2,
		"two authoritative intent sources are valid")
	for beat in range(5):
		var actions := scheduler.get_intents()
		_check(actions == _announced(expected, beat),
			"beat %d announces exact source-sorted actions; beat 5 wraps" % (beat + 1))
		_check(actions[0]["enemy_position"] == 1 and actions[1]["enemy_position"] == 2,
			"beat %d retains occupied enemy slots" % (beat + 1))
		var copy := actions.duplicate(true)
		actions[0]["amount"] = 99
		_check(scheduler.get_intents() == copy, "returned beat %d intents are deep snapshots" % beat)
		if beat < 4:
			_check(scheduler.advance_turn(), "explicitly advances after beat %d" % beat)
	_check(definitions == expected, "scheduler does not mutate parsed schedule")
	# The service also copies nested caller definitions on construction.
	definitions[0]["pattern"][0]["amount"] = 777
	_check(scheduler.get_intents() == _announced(expected, 4),
		"original definition mutation cannot change the wrapped announcement")


func _fixture() -> Dictionary:
	var heroes := _actor_data(PARTY)
	var enemies := _actor_data(ENEMIES)
	_check(heroes.size() == 3 and enemies.size() == 2, "authoritative roster sizes")
	if heroes.size() != 3 or enemies.size() != 2:
		return {}
	var hero_ids := ["warden", "seamstress", "tinker"]
	var hero_hp := [40, 30, 26]
	for i in range(3):
		_check(heroes[i]["id"] == hero_ids[i] and heroes[i]["max_hp"] == hero_hp[i],
			"authoritative hero %d identity and max HP" % (i + 1))
	_check(enemies[0]["id"] == "ragling" and enemies[0]["max_hp"] == 12
		and enemies[1]["id"] == "ragling_guard" and enemies[1]["max_hp"] == 12,
		"real Ragling/Guard Ragling both have 12 HP in slots 1/2")
	var party := CombatParty.new(heroes)
	var foes := CombatEnemies.new(enemies)
	var intents := CombatEnemyIntents.new(
		RunFightEncounterSelection._parse_schedule_text(_load_text(FLANK)))
	_check(party.is_valid() and foes.is_valid() and intents.is_valid(),
		"real party, enemy and flank schedule services initialized")
	if not party.is_valid() or not foes.is_valid() or not intents.is_valid():
		return {}
	var opening := CombatStartingBlock.new(party)
	_check(opening.apply() and not opening.apply()
		and party.get_hero(1)["block"] == 6, "real Warden opening +6 Block is one-shot")
	return {"party": party, "enemies": foes, "intents": intents}


func _test_phases_and_fresh_replay() -> void:
	var expected_heroes := [
		[[40, 6], [29, 0], [25, 0]],
		[[40, 5], [29, 0], [25, 0]],
		[[40, 5], [29, 0], [24, 0]],
		[[40, 4], [28, 0], [24, 0]]
	]
	var expected_blocks := [[0, 0], [1, 0], [1, 1], [1, 1]]
	var expected_events := [
		[_event("attack", 1, true, 2), _event("attack", 2, true, 3)],
		[_event("block", 1, true), _event("attack", 2, true, 1)],
		[_event("attack", 1, true, 3), _event("block", 2, true)],
		[_event("attack", 1, true, 1), _event("attack", 2, true, 2)]
	]
	var first_trace: Array = []
	for replay in range(2):
		var fixture := _fixture()
		if fixture.is_empty():
			return
		var party: CombatParty = fixture["party"]
		var enemies: CombatEnemies = fixture["enemies"]
		var intents: CombatEnemyIntents = fixture["intents"]
		var phase := CombatEnemyPhase.new()
		_check(party.get_hero(1)["hp"] == 40 and party.get_hero(2)["hp"] == 30
			and party.get_hero(3)["hp"] == 26
			and enemies.get_enemy(1)["hp"] == 12 and enemies.get_enemy(2)["hp"] == 12,
			"fresh replay %d begins with complete shipped starting HP" % replay)
		var trace: Array = []
		for beat in range(4):
			var actions := intents.get_intents()
			var result := phase.execute_phase(party, enemies, actions)
			_check(result == {"ok": true, "events": expected_events[beat]},
				"replay %d beat %d resolves exact sorted events" % [replay, beat + 1])
			_check(intents.get_intents() == actions,
				"phase does not secretly advance scheduler at beat %d" % (beat + 1))
			var heroes_before := party.get_heroes()
			var foes_before := enemies.get_enemies()
			for i in range(3):
				_check(heroes_before[i]["hp"] == expected_heroes[beat][i][0]
					and heroes_before[i]["block"] == expected_heroes[beat][i][1],
					"replay %d beat %d exact hero slot %d HP/Block" % [replay, beat + 1, i + 1])
			for i in range(2):
				_check(foes_before[i]["hp"] == 12
					and foes_before[i]["block"] == expected_blocks[beat][i],
					"replay %d beat %d exact enemy slot %d HP/Block" % [replay, beat + 1, i + 1])
			trace.append({"result": result, "heroes": heroes_before, "enemies": foes_before})
			if beat < 3:
				_check(intents.advance_turn(), "caller explicitly advances after beat %d" % (beat + 1))
		_check(party.get_hero(1)["hp"] == 40 and party.get_hero(1)["block"] == 4
			and party.get_hero(2)["hp"] == 28 and party.get_hero(3)["hp"] == 24
			and enemies.get_enemy(1)["block"] == 1 and enemies.get_enemy(2)["block"] == 1,
			"AC2 four-phase final Warden 40/4, Seamstress 28, Tinker 24, each enemy +1 Block")
		if replay == 0:
			first_trace = trace.duplicate(true)
		else:
			_check(trace == first_trace, "fresh real combat fixtures replay all phases identically")


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _fight(map: RunMap) -> String:
	for node_id in map.get_legal_choices():
		if map.get_node(node_id).get("type") == "Fight":
			_check(map.choose_node(node_id) and map.get_current_node_id() == node_id
				and map.get_current_floor() == 1,
				"chosen Fight is legally entered in the actual generated run map")
			return node_id
	_check(false, "generated map contains a legal opening Fight")
	return ""


func _pool(reversed: bool = false) -> Dictionary:
	if reversed:
		return {"ragged_needle_flank": FLANK, "starter_attacks": STARTER}
	return {"starter_attacks": STARTER, "ragged_needle_flank": FLANK}


func _test_seeded_selection_and_predecessors() -> void:
	for prior in [{"id": "starter_attacks", "path": STARTER},
			{"id": "guard_counterattack", "path": GUARD}]:
		var definitions := RunFightEncounterSelection._parse_schedule_text(
			_load_text(prior["path"]))
		_check(definitions == _expected_previous(prior["id"])
			and CombatEnemyIntents.new(definitions).is_valid(),
			"predecessor " + prior["id"] + " still parses with full authored actions")
	var rng := _rng(47161)
	var replay_rng := _rng(47161)
	var oracle := _rng(47161)
	var map := RunMap.new()
	var replay_map := RunMap.new()
	var oracle_map := RunMap.new()
	_check(map.generate(rng) and replay_map.generate(replay_rng)
		and oracle_map.generate(oracle), "independent same-seed generated maps")
	_check(map.get_floors() == replay_map.get_floors()
		and map.get_floors() == oracle_map.get_floors(), "identical seeded map geometry")
	var id := _fight(map)
	if id.is_empty():
		return
	_check(replay_map.choose_node(id) and oracle_map.choose_node(id)
		and replay_map.get_node(id).get("type") == "Fight",
		"both reference maps choose same legal Fight")
	var ids: Array = _pool().keys()
	ids.sort()
	var expected_id: String = ids[oracle.randi_range(0, ids.size() - 1)]
	var oracle_state := oracle.state
	var selector := RunFightEncounterSelection.new()
	seed(47161)
	var global_next := randi()
	seed(47161)
	var selected := selector.select_current_fight(map, rng, _pool())
	_check(randi() == global_next, "selector does not spend the global RNG")
	var expected_definitions: Array = _expected_flank() if expected_id == "ragged_needle_flank" else _expected_previous("starter_attacks")
	_check(selected == {"success": true, "encounter_id": expected_id,
		"definitions": expected_definitions}, "one sorted-ID RNG draw selects a full schedule")
	_check(rng.state == oracle_state and map.get_route() == [id],
		"selection spends exactly one run draw and leaves map route unchanged")
	var replay_choice := RunFightEncounterSelection.new().select_current_fight(
		replay_map, replay_rng, _pool(true))
	_check(replay_choice == selected and replay_rng.state == oracle_state,
		"reverse insertion with fresh seeded map/RNG replays selection exactly")
	var original := selected.duplicate(true)
	var cached := selector.select_current_fight(map, rng, {})
	_check(cached == original and rng.state == oracle_state,
		"cached reread requires no pool and spends zero RNG")
	selected["definitions"][0]["pattern"][0]["amount"] = 99
	cached["definitions"][0]["pattern"][0]["amount"] = 88
	cached["definitions"].clear()
	_check(selector.select_current_fight(map, rng, _pool()) == original
		and rng.state == oracle_state, "multiple deep-copy mutations cannot damage cache")
	_check(CombatEnemyIntents.new(original["definitions"]).is_valid(),
		"selected complete definitions instantiate actual scheduler")


func _test_slain_and_rejected_inputs() -> void:
	var fixture := _fixture()
	if fixture.is_empty():
		return
	var party: CombatParty = fixture["party"]
	var enemies: CombatEnemies = fixture["enemies"]
	var scheduler: CombatEnemyIntents = fixture["intents"]
	var phase := CombatEnemyPhase.new()
	_check(enemies.apply_damage(1, 12) and enemies.is_slain(1)
		and not enemies.is_slain(2), "slain Ragling remains occupied in enemy slot 1")
	var dead := enemies.get_enemy(1)
	var intents := scheduler.get_intents()
	var result := phase.execute_phase(party, enemies, intents)
	_check(result == {"ok": true, "events": [
		_event("attack", 1, false, 2), _event("attack", 2, true, 3)]},
		"slain first source skipped; live Guard retains slot 2 and attacks Tinker")
	_check(enemies.get_enemy(1) == dead and enemies.get_enemy(2)["hp"] == 12
		and party.get_hero(1)["block"] == 6 and party.get_hero(2)["hp"] == 30
		and party.get_hero(3)["hp"] == 25,
		"slain source cannot attack or alter its own state; live source damages only slot 3")
	_check(scheduler.advance_turn(), "explicitly advance for dead-source Block beat")
	result = phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(result == {"ok": true, "events": [
		_event("block", 1, false), _event("attack", 2, true, 1)]},
		"slain Ragling Block skipped; Guard hits Warden's opening Block")
	_check(enemies.get_enemy(1) == dead and enemies.get_enemy(2)["block"] == 0
		and party.get_hero(1)["hp"] == 40 and party.get_hero(1)["block"] == 5,
		"slain Block has no effect; living attack is not retargeted")

	var valid := _expected_flank()
	var malformed := [
		{"type": "block", "amount": 1, "target_position": 2},
		{"type": "attack", "amount": 1},
		{"type": "attack", "amount": 1, "target_position": 2.5},
		{"type": "attack", "amount": -1, "target_position": 2},
		{"type": "heal", "amount": 1},
	]
	for bad in malformed:
		var corrupted := valid.duplicate(true)
		corrupted[1]["pattern"][3] = bad
		var text_json := JSON.stringify(corrupted)
		_check(RunFightEncounterSelection._parse_schedule_text(text_json).is_empty(),
			"malformed later authored action is rejected: " + str(bad))
		var raw_scheduler := CombatEnemyIntents.new(corrupted)
		_check(not raw_scheduler.is_valid() and raw_scheduler.get_intents().is_empty(),
			"raw scheduler also rejects malformed action " + str(bad))
	# Both sources are alive, so the first valid hit WOULD change HP if the
	# later invalid action did not reject the complete batch atomically.
	var fresh := _fixture()
	if fresh.is_empty():
		return
	var live_party: CombatParty = fresh["party"]
	var live_enemies: CombatEnemies = fresh["enemies"]
	var live_scheduler: CombatEnemyIntents = fresh["intents"]
	var before_party := live_party.get_heroes()
	var before_enemies := live_enemies.get_enemies()
	var before_announced := live_scheduler.get_intents()
	var wrong := [{"type": "attack", "enemy_position": 1, "amount": 1,
		"target_position": 2}, {"type": "block", "enemy_position": 2, "amount": 1,
		"target_position": 1}]
	_check(phase.execute_phase(live_party, live_enemies, wrong) == {"ok": false, "events": []},
		"late bad phase shape rejects whole batch, including live first attack")
	_check(live_party.get_heroes() == before_party and live_enemies.get_enemies() == before_enemies
		and live_scheduler.get_intents() == before_announced,
		"rejected phase makes no partial combat or schedule changes")

	var rng := _rng(91731)
	var map := RunMap.new()
	_check(map.generate(rng), "invalid-pool test uses an actual seeded generated map")
	if _fight(map).is_empty():
		return
	var picker := RunFightEncounterSelection.new()
	var old_state := rng.state
	var old_route := map.get_route()
	var bad_pools: Array = [{}, {"starter_attacks": STARTER, "broken": "res://data/encounters/absent.json"},
		{"ragged_needle_flank": "res://data/enemies/starter_enemies.json"},
		{1: FLANK}]
	for bad_pool in bad_pools:
		_check(picker.select_current_fight(map, rng, bad_pool) == {"success": false},
			"invalid candidate pool fails closed " + str(bad_pool))
		_check(rng.state == old_state and picker._selected.is_empty()
			and picker._bound_map == null and map.get_route() == old_route,
			"bad pool spends no RNG and never binds or caches a selected encounter")
	var oracle := _rng(91731)
	var reference_map := RunMap.new()
	_check(reference_map.generate(oracle)
		and reference_map.choose_node(map.get_current_node_id()),
		"reference retry uses independently generated same-seed Fight")
	var names: Array = _pool().keys()
	names.sort()
	var oracle_name: String = names[oracle.randi_range(0, names.size() - 1)]
	var success := picker.select_current_fight(map, rng, _pool())
	_check(success.get("success", false) and success.get("encounter_id") == oracle_name
		and success.get("definitions") == (
			_expected_flank() if oracle_name == "ragged_needle_flank" else _expected_previous("starter_attacks"))
		and rng.state == oracle.state,
		"valid retry after invalid pools selects a complete encounter with exactly one draw")
