extends SceneTree

## Test-local Fight registration only: these encounters are NOT in the live pool.
const CROSS := "crosscover_exposed"
const BACK := "backseam_weakline"
const ENCOUNTER_DIR := "res://data/encounters/"
const HERO_PATH := "res://data/heroes/starter_party.json"
const ENEMY_PATH := "res://data/enemies/run_enemies.json"
const HERO_IDS := ["warden", "seamstress", "tinker"]
const ROSTERS := {
	CROSS: ["button_guard", "fray_scavenger", "spool_stalker"],
	BACK: ["seam_ripper", "spool_stalker"],
}
const STATS := {
	"button_guard": ["Button Guard", 16],
	"fray_scavenger": ["Fray Scavenger", 14],
	"spool_stalker": ["Spool Stalker", 14],
	"seam_ripper": ["Seam Ripper", 18],
}

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_exact_data_and_intents(CROSS)
	_test_exact_data_and_intents(BACK)
	_test_seeded_selection(CROSS)
	_test_seeded_selection(BACK)
	_test_combat_replay(CROSS)
	_test_combat_replay(BACK)
	_test_atomic_rejections()
	_test_slain_sources()
	if failures.is_empty():
		print("m03_crosscover_weakline_encounters_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("m03_crosscover_weakline_encounters_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _expected(id: String) -> Array:
	if id == CROSS:
		return [
			{"enemy_position": 1, "pattern": [
				{"type": "buff", "amount": 3},
				{"type": "attack", "amount": 3, "target_position": 1},
				{"type": "block", "amount": 2}]},
			{"enemy_position": 2, "pattern": [
				{"type": "debuff", "amount": 1, "target_position": 2, "status": "exposed"},
				{"type": "attack", "amount": 2, "target_position": 2},
				{"type": "attack", "amount": 3, "target_position": 3}]},
			{"enemy_position": 3, "pattern": [
				{"type": "attack", "amount": 3, "target_position": 2},
				{"type": "block", "amount": 2},
				{"type": "attack", "amount": 2, "target_position": 1}]},
		]
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
			{"type": "attack", "amount": 3, "target_position": 1},
			{"type": "block", "amount": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
			{"type": "attack", "amount": 4, "target_position": 2},
			{"type": "attack", "amount": 3, "target_position": 3}]},
	]


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "real resource opens: " + path)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content


func _parsed(id: String) -> Array:
	return RunFightEncounterSelection._parse_schedule_text(_read(ENCOUNTER_DIR + id + ".json"))


func _beats(id: String, turn: int) -> Array:
	var result: Array = []
	for definition in _expected(id):
		var pattern: Array = definition["pattern"]
		var action: Dictionary = pattern[turn % pattern.size()].duplicate(true)
		action["enemy_position"] = definition["enemy_position"]
		result.append(action)
	return result


func _test_exact_data_and_intents(id: String) -> void:
	var raw = JSON.parse_string(_read(ENCOUNTER_DIR + id + ".json"))
	var prescribed := _expected(id)
	_check(raw is Array and raw.size() == prescribed.size(),
		id + ": JSON is an array with this encounter's exact number of sources")
	var parsed := _parsed(id)
	_check(parsed == prescribed, id + ": production parser yields exact prescribed ordered source entries")
	_check(parsed.size() == ROSTERS[id].size(), id + ": source count matches test-local roster")
	for position in range(1, ROSTERS[id].size() + 1):
		var matches: Array = []
		for entry in parsed:
			if entry is Dictionary and entry.get("enemy_position") == position:
				matches.append(entry)
		_check(matches.size() == 1, id + ": exactly one source at slot " + str(position))
		if matches.size() != 1:
			continue
		var actual: Dictionary = matches[0]
		_check(actual.size() == 2 and actual.has("pattern"),
			id + ": exact source record schema " + str(position))
		_check(actual["pattern"] == prescribed[position - 1]["pattern"],
			id + ": full ordered action cycle for source " + str(position))
		_check(actual["enemy_position"] is int, id + ": parsed slot is integer")
		for action in actual["pattern"]:
			_check(action["amount"] is int
				and (not action.has("target_position") or action["target_position"] is int)
				and (not action.has("direction") or action["direction"] is int),
				id + ": parser normalizes numeric fields without fractional coercion")
	var intents := CombatEnemyIntents.new(parsed)
	_check(intents.is_valid(), id + ": actual parsed schedule validates in CombatEnemyIntents")
	if not intents.is_valid():
		return
	seed(912345)
	var expected_global := randi()
	seed(912345)
	var rng := RandomNumberGenerator.new()
	rng.seed = 731
	var state_before := rng.state
	for turn in range(7):
		_check(intents.get_intents() == _beats(id, turn),
			id + ": exact ascending source announcements on beat " + str(turn))
		_check(intents.advance_turn(), id + ": explicit scheduler advance " + str(turn))
	_check(randi() == expected_global and rng.state == state_before,
		id + ": intent announcement/advance consumes neither global nor run RNG")
	var detached := CombatEnemyIntents.new(parsed)
	var first := detached.get_intents()
	var second := detached.get_intents()
	_check(first == _beats(id, 0) and second == first,
		id + ": two independent same-beat snapshots have correct values")
	first[0]["amount"] = 999
	first[0]["type"] = "invented"
	first.append({"enemy_position": 10})
	_check(second == _beats(id, 0) and detached.get_intents() == _beats(id, 0),
		id + ": mutating first returned intent does not affect second or scheduler")
	parsed[0]["pattern"][0]["amount"] = 77
	_check(detached.get_intents() == _beats(id, 0)
		and _parsed(id) == prescribed,
		id + ": source mutation cannot alter scheduler or actual JSON")
	_check(RunFightEncounterSelection._parse_schedule_text(
		'[{"enemy_position":1,"pattern":[{"type":"attack","amount":1.5,"target_position":2}]}]').is_empty(),
		id + ": fractional authored action fails closed")


func _starter_party() -> CombatParty:
	var parsed = JSON.parse_string(_read(HERO_PATH))
	_check(parsed is Array, "real starter_party.json has array shape")
	var definitions: Array = []
	if not parsed is Array:
		return CombatParty.new([])
	for position in HERO_IDS.size():
		var id: String = HERO_IDS[position]
		var matches: Array = []
		for record in parsed:
			if record is Dictionary and record.get("id") == id:
				matches.append(record)
		_check(matches.size() == 1, "starter party unique " + id)
		if matches.size() != 1:
			return CombatParty.new([])
		var hero: Dictionary = matches[0].duplicate(true)
		var hp: int = [40, 30, 26][position]
		_check(hero.get("max_hp") == hp and hero.get("name") is String
			and hero.get("art_path") is String,
			id + ": real hero max HP / name / art path")
		hero["max_hp"] = int(hero["max_hp"])
		definitions.append(hero)
	return CombatParty.new(definitions)


func _admit(id: String, run_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var run_map := RunMap.new()
	_check(run_map.generate(rng), id + ": generated real seeded RunMap")
	var legal := run_map.get_legal_choices()
	var fight_id := ""
	for node_id in legal:
		if run_map.get_node(node_id).get("type") == "Fight":
			fight_id = node_id
			break
	_check(not fight_id.is_empty() and legal.has(fight_id),
		id + ": chose truly legal opening Fight from generated map")
	if fight_id.is_empty():
		return {}
	_check(run_map.choose_node(fight_id), id + ": choose_node accepts actual Fight")
	_check(run_map.get_current_node_id() == fight_id
		and run_map.get_node(fight_id).get("type") == "Fight"
		and run_map.get_route() == [fight_id], id + ": current node is chosen Fight")
	var selector := RunFightEncounterSelection.new()
	var pool := {"Fight": {id: ENCOUNTER_DIR + id + ".json"}}
	var rng_before := rng.state
	var choice := selector.select_current_battle(run_map, rng, pool)
	_check(choice.get("success") == true and choice.get("node_type") == "Fight"
		and choice.get("encounter_id") == id
		and choice.get("definitions") == _expected(id),
		id + ": actual typed selector loads JSON from sole-entry local Fight pool")
	_check(rng.state == rng_before,
		id + ": Godot singleton-choice selection leaves RNG state unchanged")
	var rng_after := rng.state
	var cached := selector.select_current_battle(run_map, rng, {"Fight": {}})
	_check(cached == choice and rng.state == rng_after,
		id + ": cached selection is identical with no additional RNG spend")
	var detached_choice := choice.duplicate(true)
	cached["definitions"][0]["pattern"][0]["amount"] = 999
	_check(selector.select_current_battle(run_map, rng, pool) == detached_choice
		and rng.state == rng_after,
		id + ": selector cache detached from mutated response")
	var assembled := RunTypedBattleRoster.new().assemble(
		choice, {id: ROSTERS[id]}, [ENEMY_PATH])
	_check(assembled.get("ok") == true and assembled.get("node_type") == "Fight"
		and assembled.get("encounter_id") == id
		and assembled.get("definitions") == _expected(id),
		id + ": real typed assembler accepts selector definitions and test-local IDs")
	if not assembled.get("ok", false):
		return {}
	var enemies: CombatEnemies = assembled["enemies"]
	_check(enemies.is_valid() and enemies.get_enemies().size() == ROSTERS[id].size(),
		id + ": assembled CombatEnemies has exact required source count")
	var catalog := RunTypedBattleRoster._parse_catalog_text(_read(ENEMY_PATH))
	_check(not catalog.is_empty(), id + ": production catalog parser accepts real run enemies")
	for position in ROSTERS[id].size():
		var enemy_id: String = ROSTERS[id][position]
		var entry := enemies.get_enemy(position + 1)
		var matches := 0
		for record in catalog:
			if record.get("id") == enemy_id:
				matches += 1
				_check(record.get("name") == STATS[enemy_id][0]
					and record.get("max_hp") == STATS[enemy_id][1]
					and record.get("art_path") == "res://assets/paper/enemies/" + enemy_id + ".png",
					id + ": original published catalog record unchanged for " + enemy_id)
		_check(matches == 1, id + ": unique authored enemy " + enemy_id)
		_check(entry.get("position") == position + 1 and entry.get("id") == enemy_id
			and entry.get("name") == STATS[enemy_id][0]
			and entry.get("max_hp") == STATS[enemy_id][1]
			and entry.get("hp") == STATS[enemy_id][1]
			and entry.get("block") == 0,
			id + ": real assembled slot and full-HP/zero-Block identity " + enemy_id)
	var party := _starter_party()
	_check(party.is_valid(), id + ": starter party constructs valid CombatParty")
	var block := CombatStartingBlock.new(party)
	_check(block.apply() and not block.apply(), id + ": Warden gets exactly one +6 opening Block")
	_check(party.get_hero(1).get("block") == 6
		and party.get_hero(1).get("hp") == 40
		and party.get_hero(2).get("hp") == 30
		and party.get_hero(3).get("hp") == 26,
		id + ": full-health party and precisely six starting Block")
	var scheduler := CombatEnemyIntents.new(choice["definitions"])
	_check(scheduler.is_valid() and scheduler.get_intents() == _beats(id, 0),
		id + ": typed selected schedule instantiates production intent service")
	return {"rng": rng, "map": run_map, "selector": selector,
		"choice": choice, "enemies": enemies, "party": party, "scheduler": scheduler}


func _test_seeded_selection(id: String) -> void:
	var a := _admit(id, 4103)
	var b := _admit(id, 4103)
	_check(not a.is_empty() and not b.is_empty(), id + ": two independently admitted legal fights")
	if a.is_empty() or b.is_empty():
		return
	_check(a["map"].get_floors() == b["map"].get_floors()
		and a["map"].get_route() == b["map"].get_route()
		and a["rng"].state == b["rng"].state
		and a["choice"] == b["choice"]
		and a["enemies"].get_enemies() == b["enemies"].get_enemies(),
		id + ": same-seed generated maps, selection, roster and RNG replay exactly")
	var oracle_rng := RandomNumberGenerator.new()
	oracle_rng.seed = 4103
	var oracle_map := RunMap.new()
	_check(oracle_map.generate(oracle_rng)
		and oracle_map.choose_node(a["map"].get_current_node_id()),
		id + ": independent RNG oracle generates same legal Fight route")
	oracle_rng.randi_range(0, 0)
	_check(oracle_rng.state == a["rng"].state,
		id + ": one and only one selection RNG draw after generating map")


func _hero(party: CombatParty, position: int, id: String, hp: int,
		block: int, statuses: Dictionary, label: String) -> void:
	var actual := party.get_hero(position)
	_check(actual.get("position") == position and actual.get("id") == id
		and actual.get("hp") == hp and actual.get("block") == block
		and actual.get("statuses", {}) == statuses,
		label + ": slot " + str(position) + " expected " + id + " "
		+ str([hp, block, statuses]) + " got " + str(actual))


func _phase(fixture: Dictionary, id: String, turn: int) -> Dictionary:
	var party: CombatParty = fixture["party"]
	var enemies: CombatEnemies = fixture["enemies"]
	var scheduler: CombatEnemyIntents = fixture["scheduler"]
	_check(scheduler.get_intents() == _beats(id, turn),
		id + ": full expected announced beat " + str(turn + 1))
	var before := scheduler.get_intents()
	var rng_before: int = fixture["rng"].state
	var result := CombatEnemyPhase.new().execute_phase(party, enemies, before)
	_check(result.get("ok") == true and result.get("events", []).size() == ROSTERS[id].size(),
		id + ": actual CombatEnemyPhase executes all sources on beat " + str(turn + 1))
	for event in result.get("events", []):
		_check(event.get("applied") == true,
			id + ": each source applied its real beat " + str(turn + 1))
	_check(scheduler.get_intents() == before and fixture["rng"].state == rng_before,
		id + ": real phase does not advance scheduler or spend run RNG")
	_check(scheduler.advance_turn(), id + ": caller explicitly advances after successful phase")
	return result


func _play(id: String) -> Dictionary:
	var f := _admit(id, 4103)
	if f.is_empty():
		return {}
	var party: CombatParty = f["party"]
	var enemies: CombatEnemies = f["enemies"]
	if id == CROSS:
		_check(CombatStatuses.new().adjusted_attack_damage(3, {}, {"exposed": 1}) == 4
			and CombatStatuses.new().adjusted_attack_damage(3, {}, {}) == 3,
			"crosscover: Exposed floors 3*1.5 to 4, versus unexposed 3")
		var result := _phase(f, id, 0)
		_check(result.get("events") == [
			{"type": "buff", "enemy_position": 1, "applied": true},
			{"type": "debuff", "enemy_position": 2, "applied": true,
				"target_position": 2, "status": "exposed"},
			{"type": "attack", "enemy_position": 3, "applied": true,
				"target_position": 2}], "crosscover: buff, debuff, attack actually applied in source order")
		_hero(party, 1, "warden", 40, 6, {}, "crosscover phase 1")
		_hero(party, 2, "seamstress", 26, 0, {"exposed": 1}, "crosscover phase 1")
		_hero(party, 3, "tinker", 26, 0, {}, "crosscover phase 1")
		_check(enemies.get_enemy(1).get("block") == 3, "crosscover: Guard gains +3 self-Block")
		_phase(f, id, 1)
		_hero(party, 1, "warden", 40, 3, {}, "crosscover phase 2")
		_hero(party, 2, "seamstress", 23, 0, {"exposed": 1}, "crosscover phase 2")
		_check(enemies.get_enemy(3).get("block") == 2, "crosscover phase 2: Spool self-Block 2")
		_phase(f, id, 2)
		_hero(party, 1, "warden", 40, 1, {}, "crosscover phase 3")
		_hero(party, 3, "tinker", 23, 0, {}, "crosscover phase 3")
		_check(enemies.get_enemy(1).get("block") == 5, "crosscover phase 3: Guard Block 5")
		_phase(f, id, 3)
		_hero(party, 2, "seamstress", 19, 0, {"exposed": 2}, "crosscover wrap phase 4")
		_check(enemies.get_enemy(1).get("block") == 8, "crosscover wrap: Guard buff adds 3")
	else:
		var result := _phase(f, id, 0)
		_check(result.get("events") == [
			{"type": "shove", "enemy_position": 1, "applied": true,
				"target_position": 2, "direction": 1},
			{"type": "debuff", "enemy_position": 2, "applied": true,
				"target_position": 3, "status": "weak"}],
			"backseam: real slot-2-to-3 shove, then Weak on actor now at 3")
		_hero(party, 1, "warden", 40, 6, {}, "backseam phase 1")
		_hero(party, 2, "tinker", 26, 0, {}, "backseam phase 1")
		_hero(party, 3, "seamstress", 30, 0, {"weak": 1}, "backseam phase 1")
		_phase(f, id, 1)
		_hero(party, 1, "warden", 40, 3, {}, "backseam phase 2")
		_hero(party, 2, "tinker", 22, 0, {}, "backseam phase 2")
		_hero(party, 3, "seamstress", 30, 0, {"weak": 1}, "backseam phase 2")
		_phase(f, id, 2)
		_hero(party, 3, "seamstress", 27, 0, {"weak": 1}, "backseam phase 3")
		_check(enemies.get_enemy(1).get("block") == 2, "backseam phase 3: Ripper gains 2 Block")
		_phase(f, id, 3)
		_hero(party, 2, "seamstress", 27, 0, {"weak": 1}, "backseam wrap phase 4")
		_hero(party, 3, "tinker", 22, 0, {"weak": 1}, "backseam wrap phase 4")
	_check(f["scheduler"].get_intents() == _beats(id, 1),
		id + ": four successful phases advance to second action")
	return {"heroes": party.get_heroes(), "enemies": enemies.get_enemies(),
		"intent": f["scheduler"].get_intents(), "rng": f["rng"].state}


func _test_combat_replay(id: String) -> void:
	var first := _play(id)
	var second := _play(id)
	_check(not first.is_empty() and first == second,
		id + ": independent seed-identical real four-phase combat replay")


func _reject_phase(f: Dictionary, id: String, label: String) -> void:
	var party: CombatParty = f["party"]
	var enemies: CombatEnemies = f["enemies"]
	var scheduler: CombatEnemyIntents = f["scheduler"]
	var prior_heroes := party.get_heroes()
	var prior_enemies := enemies.get_enemies()
	var prior_intents := scheduler.get_intents()
	var prior_rng: int = f["rng"].state
	var actions := prior_intents.duplicate(true)
	seed(118917)
	var global_expected := randi()
	seed(118917)
	_check(CombatEnemyPhase.new().execute_phase(party, enemies, actions) ==
		{"ok": false, "events": []}, label + ": rejects entire announced real phase")
	_check(party.get_heroes() == prior_heroes and enemies.get_enemies() == prior_enemies,
		label + ": atomic rejection restores every hero, enemy, status, Block and position")
	_check(scheduler.get_intents() == prior_intents and actions == prior_intents,
		label + ": rejection preserves complete scheduler beat and caller action snapshots")
	_check(f["rng"].state == prior_rng and randi() == global_expected,
		label + ": rejection consumes neither run RNG nor global RNG")


func _test_atomic_rejections() -> void:
	for downed in [2, 3]:
		var f := _admit(BACK, 4103)
		if f.is_empty():
			continue
		var party: CombatParty = f["party"]
		var victim := party.get_hero(downed)
		_check(party.apply_damage(downed, victim["hp"]) and party.is_downed(downed),
			"backseam: downed shove participant precondition at slot " + str(downed))
		_reject_phase(f, BACK, "backseam downed shove neighbor " + str(downed))
	# Guard's first action would add 3 Block; later middle debuff is illegal.
	var f := _admit(CROSS, 4103)
	if f.is_empty():
		return
	var party: CombatParty = f["party"]
	_check(party.apply_damage(2, 30) and party.is_downed(2),
		"crosscover: downed planned debuff target precondition")
	_check(f["enemies"].get_enemy(1).get("block") == 0
		and f["scheduler"].get_intents() == _beats(CROSS, 0),
		"crosscover: valid Guard buff precedes invalid later debuff")
	_reject_phase(f, CROSS, "crosscover staged Guard buff then invalid downed debuff")
	_check(f["enemies"].get_enemy(1).get("block") == 0,
		"crosscover: earlier staged Guard self-Block did not leak")


func _test_slain_sources() -> void:
	for id in [CROSS, BACK]:
		var f := _admit(id, 4103)
		if f.is_empty():
			continue
		var enemies: CombatEnemies = f["enemies"]
		var party: CombatParty = f["party"]
		var hp: int = enemies.get_enemy(1).get("hp")
		_check(enemies.apply_damage(1, hp) and enemies.is_slain(1)
			and not enemies.is_slain(2), id + ": kill published-HP source 1 using real damage API")
		var dead := enemies.get_enemy(1)
		var before := party.get_heroes()
		var result := CombatEnemyPhase.new().execute_phase(
			party, enemies, f["scheduler"].get_intents())
		_check(result.get("ok") == true and result.get("events", []).size() == ROSTERS[id].size(),
			id + ": dead source does not invalidate living sources' phase")
		_check(result["events"][0].get("applied") == false
			and result["events"][1].get("applied") == true,
			id + ": slain source silent, subsequent real living source applies")
		_check(enemies.get_enemy(1) == dead,
			id + ": slain source remains at original position and zero HP")
		if id == CROSS:
			_check(result["events"][2].get("applied") == true
				and party.get_hero(2).get("hp") == 26
				and party.get_hero(2).get("statuses", {}) == {"exposed": 1}
				and party.get_hero(1).get("block") == 6,
				"crosscover: live Exposed debuff and floor-4 attack continue after dead Guard")
		else:
			_check(party.get_hero(1) == before[0] and party.get_hero(2) == before[1]
				and party.get_hero(3).get("id") == "tinker"
				and party.get_hero(3).get("hp") == 26
				and party.get_hero(3).get("statuses", {}) == {"weak": 1},
				"backseam: dead shover leaves positions intact; live Spool weakens actual back hero")
