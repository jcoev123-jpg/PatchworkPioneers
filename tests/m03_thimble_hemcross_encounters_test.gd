extends SceneTree

## Standalone M03 authored Fight tests: local pools only, no app/route admission.
const THIMBLE := "thimble_rally"
const HEMCROSS := "hemcross_exposed_volley"
const ENCOUNTERS := "res://data/encounters/"
const CATALOGS := ["res://data/enemies/starter_enemies.json",
	"res://data/enemies/run_enemies.json"]
const HERO_FILE := "res://data/heroes/starter_party.json"
const ROSTERS := {
	THIMBLE: ["ragling_guard", "seam_ripper"],
	HEMCROSS: ["spool_stalker", "fray_scavenger", "button_guard"]
}
const ENEMY_STATS := {
	"ragling_guard": ["Guard Ragling", 12, "res://assets/paper/enemies/ragling_guard.png"],
	"seam_ripper": ["Seam Ripper", 18, "res://assets/paper/enemies/seam_ripper.png"],
	"spool_stalker": ["Spool Stalker", 14, "res://assets/paper/enemies/spool_stalker.png"],
	"fray_scavenger": ["Fray Scavenger", 14, "res://assets/paper/enemies/fray_scavenger.png"],
	"button_guard": ["Button Guard", 16, "res://assets/paper/enemies/button_guard.png"]
}
const SCHEDULES := {
	THIMBLE: [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 2, "target_position": 1},
			{"type": "block", "amount": 4},
			{"type": "buff", "amount": 3}]},
		{"enemy_position": 2, "pattern": [
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
			{"type": "attack", "amount": 4, "target_position": 2},
			{"type": "attack", "amount": 3, "target_position": 3}]}
	],
	HEMCROSS: [
		{"enemy_position": 1, "pattern": [
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed"},
			{"type": "attack", "amount": 4, "target_position": 2},
			{"type": "block", "amount": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 3, "target_position": 3},
			{"type": "debuff", "amount": 1, "target_position": 1, "status": "weak"},
			{"type": "attack", "amount": 2, "target_position": 3}]},
		{"enemy_position": 3, "pattern": [
			{"type": "block", "amount": 4},
			{"type": "attack", "amount": 2, "target_position": 1},
			{"type": "buff", "amount": 3}]}
	]
}
const OLD_STARTER := [
	{"enemy_position": 1, "pattern": [
		{"type": "attack", "amount": 1, "target_position": 1},
		{"type": "attack", "amount": 1, "target_position": 2},
		{"type": "attack", "amount": 1, "target_position": 3}]},
	{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]}
]
const OLD_HOLDOUT := [
	{"enemy_position": 1, "pattern": [
		{"type": "attack", "amount": 1, "target_position": 1},
		{"type": "block", "amount": 1},
		{"type": "block", "amount": 1},
		{"type": "attack", "amount": 1, "target_position": 3}]},
	{"enemy_position": 2, "pattern": [
		{"type": "attack", "amount": 1, "target_position": 2},
		{"type": "attack", "amount": 1, "target_position": 2},
		{"type": "attack", "amount": 1, "target_position": 1},
		{"type": "attack", "amount": 1, "target_position": 3}]}
]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_data_and_intents()
	for id in [THIMBLE, HEMCROSS]:
		_test_selection(id)
	_test_thimble_phases()
	_test_hemcross_phases()
	_test_phase_fail_closed()
	if failures.is_empty():
		print("m03_thimble_hemcross_encounters_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
		print("m03_thimble_hemcross_encounters_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "read shipped file " + path)
	if file == null:
		return ""
	var result := file.get_as_text()
	file.close()
	return result


func _schedule(id: String) -> Array:
	return RunFightEncounterSelection._parse_schedule_text(
		_read(ENCOUNTERS + id + ".json"))


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _beat(id: String, index: int) -> Array:
	var actions: Array = []
	for source in SCHEDULES[id]:
		var action: Dictionary = source["pattern"][index % 3].duplicate(true)
		action["enemy_position"] = source["enemy_position"]
		actions.append(action)
	return actions


func _events(actions: Array) -> Array:
	var result: Array = []
	for action in actions:
		var event := {"type": action["type"], "enemy_position": action["enemy_position"],
			"applied": true}
		for key in ["target_position", "status", "direction"]:
			if action.has(key):
				event[key] = action[key]
		result.append(event)
	return result


func _test_data_and_intents() -> void:
	for id in [THIMBLE, HEMCROSS]:
		var raw = JSON.parse_string(_read(ENCOUNTERS + id + ".json"))
		_check(raw is Array and raw.size() == SCHEDULES[id].size(),
			id + " is a top-level array with exactly the authored sources and fields")
		var parsed := _schedule(id)
		_check(parsed == SCHEDULES[id] and parsed.size() == ROSTERS[id].size(),
			id + " parser preserves every authored action and local source count")
		for slot in range(1, ROSTERS[id].size() + 1):
			var occurrences := 0
			for source in parsed:
				if source.get("enemy_position") == slot:
					occurrences += 1
					_check(source.size() == 2 and source["enemy_position"] is int
						and source["pattern"].size() == 3,
						id + " source shape and typed slot " + str(slot))
					for action in source["pattern"]:
						_check(action["amount"] is int
							and (not action.has("target_position")
								or action["target_position"] is int),
							id + " integer action parameters")
			_check(occurrences == 1, id + " unique authored source slot " + str(slot))
		var intents := CombatEnemyIntents.new(parsed)
		var replay := CombatEnemyIntents.new(_schedule(id))
		_check(intents.is_valid() and replay.is_valid(), id + " valid real schedulers")
		if not intents.is_valid() or not replay.is_valid():
			continue
		for index in range(7):
			_check(intents.get_intents() == _beat(id, index)
				and replay.get_intents() == _beat(id, index),
				id + " source-order beat " + str(index + 1) + " and cycle wrap")
			_check(intents.advance_turn() and replay.advance_turn(),
				id + " explicit deterministic turn advance")
		var external := intents.get_intents()
		external[0]["amount"] = 999
		_check(intents.get_intents() == _beat(id, 1),
			id + " announced intents are detached from external mutation")
	_check(_schedule("starter_attacks") == OLD_STARTER
		and CombatEnemyIntents.new(_schedule("starter_attacks")).is_valid(),
		"preexisting starter_attacks remains loadable with full original actions")
	_check(_schedule("buttonhole_holdout") == OLD_HOLDOUT
		and CombatEnemyIntents.new(_schedule("buttonhole_holdout")).is_valid(),
		"preexisting buttonhole_holdout remains loadable with full original actions")
	for malformed in [
		'[{"enemy_position":1,"pattern":[{"type":"attack","amount":2.5,"target_position":1}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"attack","amount":1,"target_position":1.5}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"buff","amount":3}],"id":"invented"}]',
		'[{"enemy_position":1,"pattern":[{"type":"debuff","amount":1,"target_position":3,"status":"poison"}]}]',
		'{bad'
	]:
		_check(RunFightEncounterSelection._parse_schedule_text(malformed).is_empty(),
			"real parser rejects malformed integer, extra field or invented status")


func _party() -> CombatParty:
	var raw = JSON.parse_string(_read(HERO_FILE))
	_check(raw is Array, "real starter hero catalog is an array")
	if not raw is Array:
		return CombatParty.new([])
	var definitions: Array = []
	var ids := ["warden", "seamstress", "tinker"]
	var hp := [40, 30, 26]
	for slot in range(3):
		var matches: Array = []
		for record in raw:
			if record is Dictionary and record.get("id") == ids[slot]:
				matches.append(record.duplicate(true))
		_check(matches.size() == 1, "one shipped hero " + ids[slot])
		if matches.size() != 1:
			return CombatParty.new([])
		var hero: Dictionary = matches[0]
		_check(RunFightEncounterSelection._coerce_integral_field(hero, "max_hp"),
			"real hero max_hp is a typed integer")
		_check(hero["max_hp"] == hp[slot] and hero.get("name") is String
			and hero.get("art_path") == "res://assets/paper/heroes/" + ids[slot] + ".png",
			"real hero expected HP, name and art: " + ids[slot])
		definitions.append(hero)
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "three real heroes form a CombatParty")
	if party.is_valid():
		var opening := CombatStartingBlock.new(party)
		_check(opening.apply() and not opening.apply(),
			"one-time actual Warden opening 6 Block")
		_check(party.get_hero(1).get("block") == 6 and party.get_hero(1).get("hp") == 40
			and party.get_hero(2).get("block") == 0 and party.get_hero(2).get("hp") == 30
			and party.get_hero(3).get("block") == 0 and party.get_hero(3).get("hp") == 26,
			"full fresh starter party HP and Block")
	return party


func _opening_fight(map: RunMap) -> String:
	for node_id in map.get_legal_choices():
		if map.get_node(node_id).get("type") == "Fight":
			return node_id
	return ""


func _selection_snapshot(map: RunMap, rng: RandomNumberGenerator,
		picker: RunFightEncounterSelection) -> Dictionary:
	return {"map": map.get_floors(), "route": map.get_route(), "rng": rng.state,
		"cached": picker._selected.duplicate(true), "bound": picker._bound_map}


func _fixture(id: String, seed_value: int = 39514) -> Dictionary:
	var rng := _rng(seed_value)
	var map := RunMap.new()
	_check(map.generate(rng), id + " seeded RunMap generated")
	var node := _opening_fight(map)
	_check(not node.is_empty() and map.get_legal_choices().has(node),
		id + " actual legal Fight offered")
	if node.is_empty():
		return {}
	_check(map.choose_node(node) and map.get_current_node_id() == node,
		id + " selects genuine Fight with RunMap.choose_node")
	var picker := RunFightEncounterSelection.new()
	var choice := picker.select_current_battle(map, rng,
		{"Fight": {id: ENCOUNTERS + id + ".json"}})
	_check(choice.get("success") == true and choice.get("node_type") == "Fight"
		and choice.get("encounter_id") == id and choice.get("definitions") == SCHEDULES[id],
		id + " local one-entry typed Fight pool selects complete authored schedule")
	if choice.get("success") != true:
		return {}
	var binding := RunTypedBattleRoster.new().assemble(choice,
		{id: ROSTERS[id]}, CATALOGS)
	_check(binding.get("ok") == true and binding.get("encounter_id") == id
		and binding.get("definitions") == SCHEDULES[id],
		id + " real typed-roster service binds selected encounter")
	if binding.get("ok") != true:
		return {}
	var enemies: CombatEnemies = binding["enemies"]
	_check(enemies.is_valid() and enemies.get_enemies().size() == ROSTERS[id].size(),
		id + " valid bound enemy roster with no extra slots")
	for slot in range(ROSTERS[id].size()):
		var enemy := enemies.get_enemy(slot + 1)
		var expected: Array = ENEMY_STATS[ROSTERS[id][slot]]
		_check(enemy.get("position") == slot + 1 and enemy.get("id") == ROSTERS[id][slot]
			and enemy.get("name") == expected[0] and enemy.get("max_hp") == expected[1]
			and enemy.get("hp") == expected[1] and enemy.get("block") == 0
			and enemy.get("art_path") == expected[2],
			id + " shipped catalog identity, slot, HP and art at " + str(slot + 1))
	var party := _party()
	var intents := CombatEnemyIntents.new(choice["definitions"])
	_check(party.is_valid() and intents.is_valid()
		and intents.get_intents() == _beat(id, 0),
		id + " authentic fresh three-hero and source action fixtures")
	if not party.is_valid() or not intents.is_valid():
		return {}
	return {"rng": rng, "map": map, "picker": picker, "choice": choice,
		"party": party, "enemies": enemies, "intents": intents}


func _test_selection(id: String) -> void:
	var seed_value := 12535
	var a := _fixture(id, seed_value)
	var b := _fixture(id, seed_value)
	_check(not a.is_empty() and not b.is_empty(), id + " independent live-state fixtures exist")
	if a.is_empty() or b.is_empty():
		return
	var rng: RandomNumberGenerator = a["rng"]
	var map: RunMap = a["map"]
	var picker: RunFightEncounterSelection = a["picker"]
	_check(map.get_floors() == b["map"].get_floors()
		and map.get_route() == b["map"].get_route() and a["choice"] == b["choice"]
		and rng.state == b["rng"].state
		and a["enemies"].get_enemies() == b["enemies"].get_enemies(),
		id + " equal seed repeats graph, node, roster, choice and RNG")
	var oracle := _rng(seed_value)
	var oracle_map := RunMap.new()
	_check(oracle_map.generate(oracle)
		and oracle_map.choose_node(map.get_current_node_id()),
		id + " independent legal-map one-draw oracle created")
	oracle.randi_range(0, 0)
	_check(rng.state == oracle.state, id + " selection spends precisely one run RNG draw")
	var previous := _selection_snapshot(map, rng, picker)
	var copy := picker.select_current_battle(map, rng, {"Fight": {}})
	_check(copy == a["choice"] and _selection_snapshot(map, rng, picker) == previous,
		id + " same-node cache needs no pool and spends zero RNG")
	copy["definitions"][0]["pattern"][0]["amount"] = 999
	_check(picker.select_current_battle(map, rng, {"Fight": {}}) == a["choice"]
		and _selection_snapshot(map, rng, picker) == previous,
		id + " deep cached copies cannot corrupt schedule, map or RNG")
	for fixture in [a, b]:
		var state_before: int = fixture["rng"].state
		var outcome := CombatEnemyPhase.new().execute_phase(
			fixture["party"], fixture["enemies"], fixture["intents"].get_intents())
		_check(outcome == {"ok": true, "events": _events(_beat(id, 0))}
			and fixture["rng"].state == state_before,
			id + " real first phase resolves without consuming run RNG")
	_check(a["party"].get_heroes() == b["party"].get_heroes()
		and a["enemies"].get_enemies() == b["enemies"].get_enemies(),
		id + " identical first phase full roster snapshots replay")
	# Reject future (unchosen) Fight, missing/invalid paths and a legal non-Fight.
	var probe_rng := _rng(seed_value + 1)
	var probe_map := RunMap.new()
	var probe_picker := RunFightEncounterSelection.new()
	_check(probe_map.generate(probe_rng), id + " rejection graph generated")
	var snap := _selection_snapshot(probe_map, probe_rng, probe_picker)
	var pool := {"Fight": {id: ENCOUNTERS + id + ".json"}}
	_check(probe_picker.select_current_battle(probe_map, probe_rng, pool)
		== {"success": false}
		and _selection_snapshot(probe_map, probe_rng, probe_picker) == snap,
		id + " future unchosen Fight does not bind or spend RNG")
	var fight := _opening_fight(probe_map)
	_check(not fight.is_empty() and probe_map.choose_node(fight),
		id + " rejection graph chooses real legal Fight")
	if fight.is_empty():
		return
	for bad in [{"Fight": {}}, {"Fight": {id: ENCOUNTERS + "absent.json"}},
		{"Fight": {id: ENCOUNTERS + id + ".json", "invalid": "no-path"}}]:
		snap = _selection_snapshot(probe_map, probe_rng, probe_picker)
		_check(probe_picker.select_current_battle(probe_map, probe_rng, bad)
			== {"success": false}
			and _selection_snapshot(probe_map, probe_rng, probe_picker) == snap,
			id + " invalid pool rejects atomically without spend or cache")
	_check(probe_picker.select_current_battle(probe_map, probe_rng, pool)
		.get("encounter_id") == id,
		id + " valid request still succeeds after rejected candidates")
	var found_nonfight := false
	for floor_index in range(2, 13):
		var choices := probe_map.get_legal_choices()
		if choices.is_empty():
			break
		var next: String = choices[0]
		for candidate in choices:
			if probe_map.get_node(candidate).get("type") != "Fight":
				next = candidate
				break
		if not probe_map.choose_node(next):
			break
		if probe_map.get_node(next).get("type") != "Fight":
			found_nonfight = true
			snap = _selection_snapshot(probe_map, probe_rng, probe_picker)
			_check(probe_picker.select_current_fight(probe_map, probe_rng, pool["Fight"])
				== {"success": false}
				and probe_picker.select_current_battle(probe_map, probe_rng, pool)
				== {"success": false}
				and _selection_snapshot(probe_map, probe_rng, probe_picker) == snap,
				id + " legally chosen non-Fight rejects with unchanged cache/RNG")
			break
	_check(found_nonfight, id + " exercised genuine reachable non-Fight negative")


func _hero(party: CombatParty, position: int, id: String, hp: int,
		block: int, statuses: Dictionary, label: String) -> void:
	var actor := party.get_hero(position)
	_check(actor.get("position") == position and actor.get("id") == id
		and actor.get("hp") == hp and actor.get("block") == block
		and actor.get("statuses", {}) == statuses, label + " " + str(actor))


func _foe(enemies: CombatEnemies, position: int, hp: int, block: int,
		label: String) -> void:
	var actor := enemies.get_enemy(position)
	_check(actor.get("position") == position and actor.get("hp") == hp
		and actor.get("block") == block and actor.get("statuses", {}) == {},
		label + " " + str(actor))


func _phase(id: String, beat_index: int) -> Dictionary:
	var f := _fixture(id)
	if f.is_empty():
		return {}
	var scheduler: CombatEnemyIntents = f["intents"]
	for index in range(beat_index):
		_check(scheduler.advance_turn(), id + " advances to independent beat " + str(index + 2))
	var announced := scheduler.get_intents()
	_check(announced == _beat(id, beat_index),
		id + " actual announcement equals complete beat " + str(beat_index + 1))
	var before_rng: int = f["rng"].state
	var result := CombatEnemyPhase.new().execute_phase(f["party"], f["enemies"], announced)
	_check(result == {"ok": true, "events": _events(_beat(id, beat_index))},
		id + " ordered fully applied genuine phase beat " + str(beat_index + 1))
	_check(f["rng"].state == before_rng and scheduler.get_intents() == announced,
		id + " phase neither consumes RNG nor advances scheduler")
	return f


func _test_thimble_phases() -> void:
	var first := _phase(THIMBLE, 0)
	if first.is_empty():
		return
	_hero(first["party"], 1, "warden", 40, 4, {}, "Thimble B1 first source only spends 2 of 6 Block")
	_hero(first["party"], 2, "seamstress", 30, 0, {}, "Thimble B1 untouched middle")
	_hero(first["party"], 3, "tinker", 26, 0, {"weak": 1},
		"Thimble B1 later Weak 1 has no instant damage or duration tick")
	_foe(first["enemies"], 1, 12, 0, "Thimble B1 Guard still unblocked")
	_foe(first["enemies"], 2, 18, 0, "Thimble B1 Ripper unharmed")
	var second := _phase(THIMBLE, 1)
	if not second.is_empty():
		_hero(second["party"], 1, "warden", 40, 6, {}, "Thimble B2 independent Warden")
		_hero(second["party"], 2, "seamstress", 26, 0, {}, "Thimble B2 Ripper hits middle 4")
		_hero(second["party"], 3, "tinker", 26, 0, {}, "Thimble B2 rear untouched")
		_foe(second["enemies"], 1, 12, 4, "Thimble B2 Guard self-Block 4")
		_foe(second["enemies"], 2, 18, 0, "Thimble B2 Ripper stays unblocked")
	var third := _phase(THIMBLE, 2)
	if not third.is_empty():
		_hero(third["party"], 1, "warden", 40, 6, {}, "Thimble B3 Warden untouched")
		_hero(third["party"], 2, "seamstress", 30, 0, {}, "Thimble B3 middle untouched")
		_hero(third["party"], 3, "tinker", 23, 0, {}, "Thimble B3 Ripper hits rear 3")
		_foe(third["enemies"], 1, 12, 3, "Thimble B3 buff grants self-Block 3")
		_foe(third["enemies"], 2, 18, 0, "Thimble B3 Ripper unblocked")


func _test_hemcross_phases() -> void:
	var first := _phase(HEMCROSS, 0)
	if first.is_empty():
		return
	_hero(first["party"], 1, "warden", 40, 6, {}, "Hemcross B1 Warden 6 Block retained")
	_hero(first["party"], 2, "seamstress", 30, 0, {}, "Hemcross B1 middle untouched")
	_hero(first["party"], 3, "tinker", 22, 0, {"exposed": 1},
		"Hemcross B1 Exposed before hit floors 3*1.5 to 4, HP 26 to 22")
	_foe(first["enemies"], 1, 14, 0, "Hemcross B1 Stalker unblocked")
	_foe(first["enemies"], 2, 14, 0, "Hemcross B1 Scavenger unblocked")
	_foe(first["enemies"], 3, 16, 4, "Hemcross B1 Button Guard Block 4")
	var second := _phase(HEMCROSS, 1)
	if not second.is_empty():
		_hero(second["party"], 1, "warden", 40, 4, {"weak": 1},
			"Hemcross B2 Weak front then 2 Block damage")
		_hero(second["party"], 2, "seamstress", 26, 0, {}, "Hemcross B2 Stalker middle 4")
		_hero(second["party"], 3, "tinker", 26, 0, {}, "Hemcross B2 Tinker untouched")
		for pos in range(1, 4):
			_foe(second["enemies"], pos, ENEMY_STATS[ROSTERS[HEMCROSS][pos - 1]][1],
				0, "Hemcross B2 no enemy Block " + str(pos))
	var third := _phase(HEMCROSS, 2)
	if not third.is_empty():
		_hero(third["party"], 1, "warden", 40, 6, {}, "Hemcross B3 Warden untouched")
		_hero(third["party"], 2, "seamstress", 30, 0, {}, "Hemcross B3 middle untouched")
		_hero(third["party"], 3, "tinker", 24, 0, {}, "Hemcross B3 rear attack 2")
		_foe(third["enemies"], 1, 14, 2, "Hemcross B3 Stalker self-Block 2")
		_foe(third["enemies"], 2, 14, 0, "Hemcross B3 Scavenger unblocked")
		_foe(third["enemies"], 3, 16, 3, "Hemcross B3 Button Guard buff self-Block 3")


func _assert_failure(f: Dictionary, actions: Array, label: String) -> void:
	var party: CombatParty = f["party"]
	var enemies: CombatEnemies = f["enemies"]
	var before_heroes := party.get_heroes()
	var before_enemies := enemies.get_enemies()
	var before_rng: int = f["rng"].state
	var before_intents: Array = f["intents"].get_intents()
	var outcome := CombatEnemyPhase.new().execute_phase(party, enemies, actions)
	_check(outcome == {"ok": false, "events": []}, label + " rejects without events")
	_check(party.get_heroes() == before_heroes and enemies.get_enemies() == before_enemies
		and f["rng"].state == before_rng
		and f["intents"].get_intents() == before_intents,
		label + " preserves full staged rosters, scheduler and RNG")


func _test_phase_fail_closed() -> void:
	var downed := _fixture(THIMBLE)
	if not downed.is_empty():
		_check(downed["party"].apply_damage(3, 26)
			and downed["party"].is_downed(3),
			"genuine Tinker downed to zero HP and keeps slot 3")
		_check(downed["intents"].get_intents()[0]["type"] == "attack"
			and downed["intents"].get_intents()[1]["type"] == "debuff",
			"first Thimble attack can stage Block loss before late invalid Weak target")
		_assert_failure(downed, downed["intents"].get_intents(),
			"later debuff targets downed Tinker after staged Warden damage")
		_hero(downed["party"], 1, "warden", 40, 6, {},
			"failed staged Thimble attack must not spend Warden Block")
	var bad := _fixture(HEMCROSS)
	if not bad.is_empty():
		var invalid: Array = bad["intents"].get_intents()
		invalid[2]["type"] = "invented"
		_assert_failure(bad, invalid, "malformed later Hemcross source action")
	var overflow := _fixture(HEMCROSS)
	if not overflow.is_empty():
		var enemies: CombatEnemies = overflow["enemies"]
		enemies._enemies[2]["block"] = CombatEnemies.MAX_INT
		_check(enemies.get_enemy(3)["block"] == CombatEnemies.MAX_INT,
			"late Button Guard Block overflow precondition is real")
		_assert_failure(overflow, overflow["intents"].get_intents(),
			"late overflow after earlier Exposed and attack were staged")
		_hero(overflow["party"], 3, "tinker", 26, 0, {},
			"late overflow rolls back earlier Exposed and 4 damage")
		enemies._enemies[2]["block"] = 0
		_check(CombatEnemyPhase.new().execute_phase(overflow["party"], enemies,
			overflow["intents"].get_intents())["ok"],
			"valid original phase succeeds after overflow rejection")
	var slain := _fixture(THIMBLE)
	if not slain.is_empty():
		var enemies: CombatEnemies = slain["enemies"]
		_check(enemies.apply_damage(1, 12) and enemies.is_slain(1),
			"Guard Ragling truly slain without moving source slot")
		var outcome := CombatEnemyPhase.new().execute_phase(
			slain["party"], enemies, slain["intents"].get_intents())
		_check(outcome == {"ok": true, "events": [
			{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": false},
			{"type": "debuff", "enemy_position": 2, "target_position": 3,
				"status": "weak", "applied": true}]},
			"slain source skips attack; living Ripper still applies announced Weak")
		_hero(slain["party"], 1, "warden", 40, 6, {},
			"slain Ragling cannot consume Warden Block")
		_hero(slain["party"], 3, "tinker", 26, 0, {"weak": 1},
			"living enemy still legitimately weakens Tinker")
		_foe(enemies, 1, 0, 0, "slain enemy retains first slot")
