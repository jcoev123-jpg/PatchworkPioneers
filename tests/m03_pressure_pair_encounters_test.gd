extends SceneTree

## Standalone paired M03 Fight schedules; no typed-pool registration or app wiring.

const PIN := "pincushion_bulwark"
const THREAD := "frayed_threadcross"
const PIN_PATH := "res://data/encounters/pincushion_bulwark.json"
const THREAD_PATH := "res://data/encounters/frayed_threadcross.json"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMIES_PATH := "res://data/enemies/run_enemies.json"
const HERO_IDS := ["warden", "seamstress", "tinker"]

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_catalog_and_schedules()
	_test_intent_cycles()
	_test_real_timelines()
	_test_slain_sources()
	_test_direct_fight_selection()
	_test_success_then_atomic_rejection()
	_test_parser_fail_closed()
	if failures.is_empty():
		print("m03_pressure_pair_encounters_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("m03_pressure_pair_encounters_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)


func _path(id: String) -> String:
	return PIN_PATH if id == PIN else THREAD_PATH


func _expected(id: String) -> Array:
	if id == PIN:
		return [
			{"enemy_position": 1, "pattern": [
				{"type": "debuff", "amount": 1, "target_position": 1, "status": "exposed"},
				{"type": "block", "amount": 4},
				{"type": "buff", "amount": 3}]},
			{"enemy_position": 2, "pattern": [
				{"type": "attack", "amount": 3, "target_position": 1},
				{"type": "attack", "amount": 2, "target_position": 2},
				{"type": "attack", "amount": 3, "target_position": 1}]},
		]
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
			{"type": "attack", "amount": 2, "target_position": 2},
			{"type": "block", "amount": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 2, "target_position": 3},
			{"type": "debuff", "amount": 1, "target_position": 2, "status": "bleed"},
			{"type": "attack", "amount": 3, "target_position": 2}]},
		{"enemy_position": 3, "pattern": [
			{"type": "buff", "amount": 2},
			{"type": "attack", "amount": 2, "target_position": 1},
			{"type": "attack", "amount": 3, "target_position": 1}]},
	]


## Independent literal announcements: do not construct an oracle from file input.
func _announcements(id: String) -> Array:
	if id == PIN:
		return [
			[
				{"enemy_position": 1, "type": "debuff", "amount": 1, "target_position": 1, "status": "exposed"},
				{"enemy_position": 2, "type": "attack", "amount": 3, "target_position": 1}],
			[
				{"enemy_position": 1, "type": "block", "amount": 4},
				{"enemy_position": 2, "type": "attack", "amount": 2, "target_position": 2}],
			[
				{"enemy_position": 1, "type": "buff", "amount": 3},
				{"enemy_position": 2, "type": "attack", "amount": 3, "target_position": 1}],
		]
	return [
		[
			{"enemy_position": 1, "type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
			{"enemy_position": 2, "type": "attack", "amount": 2, "target_position": 3},
			{"enemy_position": 3, "type": "buff", "amount": 2}],
		[
			{"enemy_position": 1, "type": "attack", "amount": 2, "target_position": 2},
			{"enemy_position": 2, "type": "debuff", "amount": 1, "target_position": 2, "status": "bleed"},
			{"enemy_position": 3, "type": "attack", "amount": 2, "target_position": 1}],
		[
			{"enemy_position": 1, "type": "block", "amount": 2},
			{"enemy_position": 2, "type": "attack", "amount": 3, "target_position": 2},
			{"enemy_position": 3, "type": "attack", "amount": 3, "target_position": 1}],
	]


func _events(id: String) -> Array:
	if id == PIN:
		return [
			[
				{"type": "debuff", "enemy_position": 1, "applied": true, "target_position": 1, "status": "exposed"},
				{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 1}],
			[
				{"type": "block", "enemy_position": 1, "applied": true},
				{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 2}],
			[
				{"type": "buff", "enemy_position": 1, "applied": true},
				{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 1}],
		]
	return [
		[
			{"type": "debuff", "enemy_position": 1, "applied": true, "target_position": 3, "status": "weak"},
			{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 3},
			{"type": "buff", "enemy_position": 3, "applied": true}],
		[
			{"type": "attack", "enemy_position": 1, "applied": true, "target_position": 2},
			{"type": "debuff", "enemy_position": 2, "applied": true, "target_position": 2, "status": "bleed"},
			{"type": "attack", "enemy_position": 3, "applied": true, "target_position": 1}],
		[
			{"type": "block", "enemy_position": 1, "applied": true},
			{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 2},
			{"type": "attack", "enemy_position": 3, "applied": true, "target_position": 1}],
	]


func _text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	_check(f != null, "real resource opens: " + path)
	if f == null:
		return ""
	var data := f.get_as_text()
	f.close()
	return data


func _records(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(_text(path))
	_check(parsed is Array and not parsed.is_empty(), "authored catalog is a nonempty array: " + path)
	if not parsed is Array:
		return []
	var result: Array = []
	for entry in parsed:
		if not entry is Dictionary:
			return []
		var item: Dictionary = entry.duplicate(true)
		var max_hp = item.get("max_hp")
		if max_hp is float and not is_nan(max_hp) and not is_inf(max_hp) \
				and max_hp > 0 and floorf(max_hp) == max_hp and max_hp <= 9007199254740991.0:
			item["max_hp"] = int(max_hp)
		_check(item.get("max_hp") is int and item["max_hp"] > 0,
			"catalog max_hp is a positive integer for " + str(item.get("id")))
		result.append(item)
	return result


func _record(catalog: Array, id: String) -> Dictionary:
	var found: Array = []
	for item in catalog:
		if item is Dictionary and item.get("id") == id:
			found.append(item)
	_check(found.size() == 1, "catalog contains exactly one " + id)
	return {} if found.is_empty() else found[0].duplicate(true)


func _party() -> CombatParty:
	var catalog := _records(PARTY_PATH)
	var records: Array = []
	for id in HERO_IDS:
		records.append(_record(catalog, id))
	var party := CombatParty.new(records)
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"real authored 3-hero party constructed")
	return party


func _foes(id: String) -> CombatEnemies:
	var catalog := _records(ENEMIES_PATH)
	var ids := ["button_guard", "seam_ripper"] if id == PIN \
		else ["fray_scavenger", "spool_stalker", "button_guard"]
	var records: Array = []
	for enemy_id in ids:
		records.append(_record(catalog, enemy_id))
	var foes := CombatEnemies.new(records)
	_check(foes.is_valid() and foes.get_enemies().size() == ids.size(),
		id + " builds all authored enemy slots")
	return foes


func _parsed(id: String) -> Array:
	return RunFightEncounterSelection._parse_schedule_text(_text(_path(id)))


func _test_catalog_and_schedules() -> void:
	var heroes := _records(PARTY_PATH)
	for i in HERO_IDS.size():
		var entry := _record(heroes, HERO_IDS[i])
		_check(entry.get("max_hp") == [40, 30, 26][i]
			and entry.get("name") == ["Warden", "Seamstress", "Tinker"][i]
			and entry.get("art_path") is String, "starter party identity and HP " + HERO_IDS[i])
	var catalog := _records(ENEMIES_PATH)
	for expected in [
		{"id": "button_guard", "name": "Button Guard", "max_hp": 16},
		{"id": "seam_ripper", "name": "Seam Ripper", "max_hp": 18},
		{"id": "fray_scavenger", "name": "Fray Scavenger", "max_hp": 14},
		{"id": "spool_stalker", "name": "Spool Stalker", "max_hp": 14},
	]:
		var item := _record(catalog, expected["id"])
		_check(item.get("name") == expected["name"] and item.get("max_hp") == expected["max_hp"]
			and item.get("art_path") is String,
			"shipped enemy stats and art path " + expected["id"])
	for id in [PIN, THREAD]:
		var path := _path(id)
		_check(path.get_file().get_basename() == id and FileAccess.file_exists(path),
			id + " is a distinct standalone encounter file")
		var raw: Variant = JSON.parse_string(_text(path))
		var expected: Array = _expected(id)
		_check(raw is Array and raw.size() == expected.size(),
			id + " JSON contains exactly its authored source records")
		var parsed := _parsed(id)
		_check(parsed == expected, id + " exact actions, positions and beat order")
		_check(CombatEnemyIntents.new(parsed).is_valid(), id + " real selector accepts schedule")
		for position in range(1, expected.size() + 1):
			var matches: Array = []
			for entry in parsed:
				if entry is Dictionary and entry.get("enemy_position") == position:
					matches.append(entry)
			_check(matches.size() == 1, id + " has one source in slot " + str(position))
			if matches.is_empty():
				continue
			var source: Dictionary = matches[0]
			_check(source.size() == 2 and source.has("pattern") and source.has("enemy_position")
				and source["enemy_position"] is int and source["pattern"].size() == 3,
				id + " source fields and int slot are exact")
			for beat in range(3):
				var action: Dictionary = source["pattern"][beat]
				_check(action == expected[position - 1]["pattern"][beat]
					and action.get("amount") is int
					and (not action.has("target_position") or action["target_position"] is int),
					id + " source %d beat %d is exact and numerically normalized" % [position, beat + 1])
		var foes := _foes(id)
		for index in expected.size():
			var expected_id: String = (["button_guard", "seam_ripper"] if id == PIN
				else ["fray_scavenger", "spool_stalker", "button_guard"])[index]
			var foe := foes.get_enemy(index + 1)
			_check(foe.get("position") == expected[index]["enemy_position"]
				and foe.get("id") == expected_id and foe.get("hp") ==
				(16 if expected_id == "button_guard" else 18 if expected_id == "seam_ripper" else 14)
				and foe.get("block") == 0, id + " source %d uses real roster identity/HP" % (index + 1))


func _test_intent_cycles() -> void:
	for id in [PIN, THREAD]:
		var scheduler := CombatEnemyIntents.new(_parsed(id))
		var replay := CombatEnemyIntents.new(_parsed(id))
		_check(scheduler.is_valid() and replay.is_valid(), id + " two fresh schedulers valid")
		var beats := _announcements(id)
		var original_file := _text(_path(id))
		for turn in range(8):
			var want: Array = beats[turn % 3]
			var current := scheduler.get_intents()
			_check(current == want and replay.get_intents() == want,
				id + " independent beat %d announces literal source-sorted actions" % (turn + 1))
			_check(scheduler._turn_index == turn and replay._turn_index == turn,
				id + " correct scheduler index at beat " + str(turn + 1))
			if turn == 0:
				current[0]["amount"] = 999
				_check(scheduler.get_intents() == want, id + " intents are defensive copies")
			_check(scheduler.advance_turn() and replay.advance_turn(),
				id + " advance through full repeated cycle")
		_check(_text(_path(id)) == original_file, id + " schedule bytes not mutated")


func _hero(party: CombatParty, position: int, hp: int, block: int,
		statuses: Dictionary, label: String) -> void:
	var hero := party.get_hero(position)
	_check(hero.get("id") == HERO_IDS[position - 1] and hero.get("hp") == hp
		and hero.get("block") == block and hero.get("statuses", {}) == statuses,
		label + " hero %d expected %d HP / %d Block / %s, got %s" %
		[position, hp, block, str(statuses), str(hero)])


func _enemy(foes: CombatEnemies, position: int, hp: int, block: int, label: String) -> void:
	var enemy := foes.get_enemy(position)
	_check(enemy.get("hp") == hp and enemy.get("block") == block
		and enemy.get("position") == position,
		label + " enemy %d expected %d HP / %d Block, got %s" %
		[position, hp, block, str(enemy)])


func _rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _timeline(id: String) -> Dictionary:
	var party := _party()
	var foes := _foes(id)
	var scheduler := CombatEnemyIntents.new(_parsed(id))
	var stream := _rng(270910)
	var initial_rng := stream.state
	_check(party.is_valid() and foes.is_valid() and scheduler.is_valid(),
		id + " complete real timeline preconditions")
	_hero(party, 1, 40, 0, {}, id + " initial")
	_hero(party, 2, 30, 0, {}, id + " initial")
	_hero(party, 3, 26, 0, {}, id + " initial")
	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), id + " real one-time Warden opening Block")
	_hero(party, 1, 40, 6, {}, id + " opening")
	var after_opening := party.get_heroes()
	_check(not opening.apply() and party.get_heroes() == after_opening,
		id + " second opening grant fails without mutations")
	var events: Array = []
	var snapshots: Array = []
	var tick: Dictionary = {}
	for beat in range(3):
		var actions := scheduler.get_intents()
		_check(actions == _announcements(id)[beat], id + " timeline announces beat " + str(beat + 1))
		var copied: Array = actions.duplicate(true)
		var result := phase.execute_phase(party, foes, actions)
		_check(result == {"ok": true, "events": _events(id)[beat]},
			id + " phase %d applies each source action in exact order: %s" %
			[beat + 1, str(result)])
		_check(actions == copied and scheduler._turn_index == beat,
			id + " phase preserves inputs and scheduler")
		events.append(result)
		snapshots.append({"heroes": party.get_heroes(), "enemies": foes.get_enemies()})
		if id == PIN:
			if beat == 0:
				_hero(party, 1, 40, 2, {"exposed": 1}, "Pincushion exposed before 3*1.5=4 attack")
				_hero(party, 2, 30, 0, {}, "Pincushion beat 1")
				_hero(party, 3, 26, 0, {}, "Pincushion beat 1")
				_enemy(foes, 1, 16, 0, "Pincushion beat 1")
				_enemy(foes, 2, 18, 0, "Pincushion beat 1")
			elif beat == 1:
				_hero(party, 1, 40, 2, {"exposed": 1}, "Pincushion beat 2")
				_hero(party, 2, 28, 0, {}, "Pincushion beat 2")
				_enemy(foes, 1, 16, 4, "Pincushion beat 2")
			else:
				_hero(party, 1, 38, 0, {"exposed": 1}, "Pincushion beat 3")
				_hero(party, 2, 28, 0, {}, "Pincushion beat 3")
				_hero(party, 3, 26, 0, {}, "Pincushion beat 3")
				_enemy(foes, 1, 16, 7, "Pincushion beat 3")
				_enemy(foes, 2, 18, 0, "Pincushion beat 3")
		else:
			if beat == 0:
				_hero(party, 1, 40, 6, {}, "Threadcross beat 1")
				_hero(party, 2, 30, 0, {}, "Threadcross beat 1")
				_hero(party, 3, 24, 0, {"weak": 1}, "Threadcross weak then rear HP loss")
				_enemy(foes, 3, 16, 2, "Threadcross Guard self-Block 2")
			elif beat == 1:
				_hero(party, 1, 40, 4, {}, "Threadcross beat 2")
				_hero(party, 2, 28, 0, {"bleed": 1}, "Threadcross bleed applied")
				_hero(party, 3, 24, 0, {"weak": 1}, "Threadcross beat 2")
				var live_before := party.get_heroes()
				tick = CombatStatusTurnBatch.new().tick_side("heroes", live_before)
				_check(tick.get("ok") == true and tick.get("actors", []).size() == 3
					and tick["actors"][1]["hp"] == 27
					and tick["actors"][1]["block"] == 0
					and tick["actors"][1]["statuses"] == {}
					and tick["events"][1]["bleed_hp_loss"] == 1
					and tick["actors"][2]["statuses"] == {},
					"owner-turn batch proposes Bleed 1 HP bypassing Block, then expires Bleed/Weak")
				var direct := CombatStatuses.new().end_owner_turn(28, 0, {"bleed": 1})
				_check(direct == {"ok": true, "hp": 27, "block": 0,
					"statuses": {}, "bleed_hp_loss": 1},
					"authoritative single-actor Bleed owner-end tick matches batch")
				_check(party.get_heroes() == live_before,
					"detached owner-turn proposal does not silently mutate live party")
			else:
				_hero(party, 1, 40, 1, {}, "Threadcross beat 3")
				_hero(party, 2, 25, 0, {"bleed": 1}, "Threadcross beat 3")
				_hero(party, 3, 24, 0, {"weak": 1}, "Threadcross beat 3")
				_enemy(foes, 1, 14, 2, "Threadcross beat 3")
				_enemy(foes, 2, 14, 0, "Threadcross beat 3")
				_enemy(foes, 3, 16, 2, "Threadcross beat 3")
		_check(scheduler.advance_turn(), id + " caller explicitly advances beat " + str(beat + 1))
	_check(scheduler.get_intents() == _announcements(id)[0] and scheduler._turn_index == 3,
		id + " fourth announced beat wraps to the first actions")
	_check(stream.state == initial_rng, id + " full combat leaves seeded run RNG unchanged")
	return {"events": events, "snapshots": snapshots, "tick": tick,
		"next": scheduler.get_intents(), "index": scheduler._turn_index,
		"run_rng_start": initial_rng, "run_rng_end": stream.state}


func _test_real_timelines() -> void:
	_check(CombatStatuses.new().adjusted_attack_damage(3, {}, {"exposed": 1}) == 4,
		"authoritative Exposed floor(3 x 1.5) = 4, not 3 or 5")
	_check(CombatStatuses.new().adjusted_attack_damage(4, {"weak": 1}, {}) == 3,
		"authoritative Weak floor(4 x .75) = 3")
	for id in [PIN, THREAD]:
		seed(170310)
		var expected_global := randi()
		seed(170310)
		var first := _timeline(id)
		_check(randi() == expected_global, id + " full real timeline leaves global RNG undrawn")
		var second := _timeline(id)
		_check(first == second, id + " independent parties/foes/intent services replay full states")
		_check(first["snapshots"].size() == 3 and first["events"].size() == 3,
			id + " exactly three executed phases and three actor snapshots")


func _test_slain_sources() -> void:
	for id in [PIN, THREAD]:
		var party := _party()
		var foes := _foes(id)
		var scheduler := CombatEnemyIntents.new(_parsed(id))
		_check(CombatStartingBlock.new(party).apply(), id + " slain-source opening Block")
		var victim := 1 if id == PIN else 2
		var max_hp := 16 if id == PIN else 14
		_check(foes.apply_damage(victim, max_hp) and foes.is_slain(victim),
			id + " specified source actually slain at authored HP")
		var before_foes := foes.get_enemies()
		var result := phase.execute_phase(party, foes, scheduler.get_intents())
		_check(result.get("ok") == true and result.get("events", []).size() ==
			(2 if id == PIN else 3) and result["events"][victim - 1]["applied"] == false,
			id + " slain source announces but does not act")
		_check(foes.get_enemy(victim) == before_foes[victim - 1],
			id + " slain slot stays dead and unchanged")
		if id == PIN:
			_hero(party, 1, 40, 3, {}, "slain Button Guard cannot expose Warden")
			_hero(party, 3, 26, 0, {}, "Pincushion slain-source other heroes")
			_check(result["events"][1]["applied"] == true,
				"living Seam Ripper still damages Warden's Block by 3")
		else:
			_hero(party, 3, 26, 0, {"weak": 1}, "slain Spool Stalker cannot damage Tinker")
			_enemy(foes, 3, 16, 2, "living Guard still buffs itself")
			_check(result["events"][0]["applied"] == true
				and result["events"][2]["applied"] == true,
				"Threadcross other living sources still act")


func _opening_fight(map: RunMap) -> String:
	for choice in map.get_legal_choices():
		if map.get_node(choice).get("type") == "Fight":
			return choice
	return ""


func _test_direct_fight_selection() -> void:
	for id in [PIN, THREAD]:
		var seed_value := 87021 if id == PIN else 87022
		var rng := _rng(seed_value)
		var replay_rng := _rng(seed_value)
		var oracle_rng := _rng(seed_value)
		var map := RunMap.new()
		var replay_map := RunMap.new()
		var oracle_map := RunMap.new()
		_check(map.generate(rng) and replay_map.generate(replay_rng)
			and oracle_map.generate(oracle_rng), id + " three full seeded maps generated")
		_check(map.get_floors() == replay_map.get_floors()
			and map.get_floors() == oracle_map.get_floors(),
			id + " independent same-seed 12-floor graphs agree")
		var choice := _opening_fight(map)
		_check(not choice.is_empty() and map.get_legal_choices().has(choice),
			id + " opening Fight exists as a legal option")
		if choice.is_empty():
			continue
		_check(map.choose_node(choice) and replay_map.choose_node(choice)
			and oracle_map.choose_node(choice)
			and map.get_current_node_id() == choice
			and map.get_current_floor() == 1,
			id + " each run legally chooses its actual current Fight")
		var selector := RunFightEncounterSelection.new()
		var pool := {id: _path(id)}
		var snapshot := [rng.state, map.get_route(), map.get_floors(), selector._selected.duplicate(true)]
		seed(91811)
		var expected_global := randi()
		seed(91811)
		var invalid := selector.select_current_fight(map, rng, {
			id: _path(id), "broken": "res://data/encounters/not_an_encounter.json"})
		_check(invalid == {"success": false},
			id + " invalid candidate rejects entire mixed pool before any choice")
		_check([rng.state, map.get_route(), map.get_floors(),
			selector._selected.duplicate(true)] == snapshot and randi() == expected_global,
			id + " invalid path consumes neither run/global RNG nor modifies map/cache")
		oracle_rng.randi_range(0, 0)
		var expected_run_state := oracle_rng.state
		seed(91811)
		expected_global = randi()
		seed(91811)
		var selected := selector.select_current_fight(map, rng, pool)
		_check(randi() == expected_global, id + " direct valid selection uses no global RNG")
		_check(selected == {"success": true, "encounter_id": id,
			"definitions": _expected(id)},
			id + " corrected singleton pool returns full canonical definition")
		_check(rng.state == expected_run_state,
			id + " corrected selection advances only the one candidate draw")
		var replay := RunFightEncounterSelection.new().select_current_fight(
			replay_map, replay_rng, pool)
		_check(replay == selected and replay_rng.state == rng.state
			and replay_map.get_route() == map.get_route(),
			id + " separate generated same-seed map/selection replays exact result")
		var original := selected.duplicate(true)
		var cached := selector.select_current_fight(map, rng, {})
		_check(cached == original and rng.state == expected_run_state,
			id + " current Fight reselects cached value without any run RNG draw")
		selected["definitions"][0]["pattern"][0]["amount"] = 909
		cached["definitions"][0]["pattern"][0]["amount"] = 777
		cached["definitions"].clear()
		_check(selector.select_current_fight(map, rng, {}) == original
			and rng.state == expected_run_state,
			id + " two independently mutated results never corrupt cached choice")
		var selected_scheduler := CombatEnemyIntents.new(original["definitions"])
		_check(selected_scheduler.is_valid()
			and selected_scheduler.get_intents() == _announcements(id)[0],
			id + " selected real Fight yields executable announced intents")


func _test_success_then_atomic_rejection() -> void:
	var party := _party()
	var foes := _foes(THREAD)
	var scheduler := CombatEnemyIntents.new(_parsed(THREAD))
	_check(CombatStartingBlock.new(party).apply(), "rollback fixture receives Warden Block 6")
	var before_success := party.get_heroes()
	var valid := phase.execute_phase(party, foes, scheduler.get_intents())
	_check(valid == {"ok": true, "events": _events(THREAD)[0]},
		"first real valid Threadcross phase succeeds before rejection probe")
	_check(party.get_heroes() != before_success
		and party.get_hero(3).get("hp") == 24
		and party.get_hero(3).get("statuses", {}) == {"weak": 1}
		and foes.get_enemy(3).get("block") == 2,
		"earlier successful phase had real HP/status/Block effects to preserve")
	_check(foes.gain_block(2, CombatEnemies.MAX_INT - 1)
		and foes.get_enemy(2).get("block") == CombatEnemies.MAX_INT - 1,
		"second source is living with near-overflow Block")
	var rng := _rng(44022)
	var before_rng := rng.state
	var before_heroes := party.get_heroes()
	var before_foes := foes.get_enemies()
	var before_intents := scheduler.get_intents()
	var turn_before := scheduler._turn_index
	# Source 1 stages a valid self-Block; source 2's otherwise valid-shaped
	# Block overflows at execution and must roll the whole *new* batch back.
	var rejected_actions: Array = [
		{"type": "block", "amount": 2, "enemy_position": 1},
		{"type": "block", "amount": 2, "enemy_position": 2}]
	var input_copy := rejected_actions.duplicate(true)
	seed(44022)
	var expected_global := randi()
	seed(44022)
	var rejected := phase.execute_phase(party, foes, rejected_actions)
	_check(rejected == {"ok": false, "events": []},
		"late valid-shaped but overflowing second action rejects complete batch")
	_check(party.get_heroes() == before_heroes and foes.get_enemies() == before_foes,
		"zero newly staged effects: prior successful HP/status/Block survive unchanged")
	_check(scheduler.get_intents() == before_intents and scheduler._turn_index == turn_before
		and rejected_actions == input_copy,
		"failed phase leaves scheduler and supplied action dictionaries intact")
	_check(rng.state == before_rng and randi() == expected_global,
		"failed phase draws neither run RNG nor Godot global RNG")
	_check(foes.get_enemy(1).get("block") == 0 and foes.get_enemy(3).get("block") == 2,
		"staged source-1 Block rolled back without erasing earlier Guard self-Block")


func _test_parser_fail_closed() -> void:
	for id in [PIN, THREAD]:
		var initial := _text(_path(id))
		var duplicate: Array = _expected(id)
		duplicate[1]["enemy_position"] = 1
		var fractional: Array = _expected(id)
		fractional[0]["pattern"][0]["amount"] = 1.5
		var extra: Array = _expected(id)
		extra[0]["extra_field"] = true
		var invalids: Array = [duplicate, fractional, extra]
		for malformed in invalids:
			_check(RunFightEncounterSelection._parse_schedule_text(
				JSON.stringify(malformed)).is_empty(),
				id + " canonical parser rejects malformed duplicate/fractional/extra record")
		_check(RunFightEncounterSelection._parse_schedule_text("{").is_empty(),
			id + " malformed JSON fails closed")
		_check(RunFightEncounterSelection._parse_schedule_text(initial) == _expected(id),
			id + " unchanged authored file remains parseable after negatives")
		_check(_text(_path(id)) == initial,
			id + " invalid test data never modified the original file")
