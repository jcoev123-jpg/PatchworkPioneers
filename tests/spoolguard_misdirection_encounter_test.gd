extends SceneTree

## Deterministic headless coverage for the authored Spoolguard Misdirection encounter:
## slot 1 Button Guard opens with Exposed on the middle hero before slot 2
## Spool Stalker's same-phase boosted attack; later beats grant Block and Weak.
## Data/service only: this file never wires the encounter into live play.

const ENCOUNTER_PATH := "res://data/encounters/spoolguard_misdirection.json"
const ENCOUNTER_ID := "spoolguard_misdirection"
const STARTER_PATH := "res://data/encounters/starter_attacks.json"
const EXPOSED_PATH := "res://data/encounters/exposed_hem_pincer.json"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMY_PATH := "res://data/enemies/run_enemies.json"

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_authored_schedule_and_parser()
	_test_intent_cycle_and_copies()
	_test_real_phase_sequence()
	_test_slain_source()
	_test_double_replay()
	_test_selection()
	_test_atomic_negative()
	if failures.is_empty():
		print("spoolguard_misdirection_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("spoolguard_misdirection_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "opens " + path)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _load_json(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(_read_text(path))
	if not parsed is Array:
		return []
	return _normalize_json(parsed)


func _normalize_json(data) -> Variant:
	if data is Array:
		var result: Array = []
		for item in data:
			result.append(_normalize_json(item))
		return result
	if data is Dictionary:
		var result: Dictionary = {}
		for key in data:
			var value = data[key]
			if value is float and value == int(value):
				value = int(value)
			else:
				value = _normalize_json(value)
			result[key] = value
		return result
	if data is float and data == int(data):
		return int(data)
	return data


func _parsed() -> Array:
	return RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))


func _expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "debuff", "amount": 1, "target_position": 2, "status": "exposed"},
			{"type": "buff", "amount": 3},
			{"type": "attack", "amount": 3, "target_position": 1}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 3, "target_position": 2},
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
			{"type": "block", "amount": 2}]},
	]


func _first_intents() -> Array:
	return [
		{"type": "debuff", "amount": 1, "target_position": 2, "status": "exposed",
			"enemy_position": 1},
		{"type": "attack", "amount": 3, "target_position": 2, "enemy_position": 2}]


func _second_intents() -> Array:
	return [
		{"type": "buff", "amount": 3, "enemy_position": 1},
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak",
			"enemy_position": 2}]


func _third_intents() -> Array:
	return [
		{"type": "attack", "amount": 3, "target_position": 1, "enemy_position": 1},
		{"type": "block", "amount": 2, "enemy_position": 2}]


func _unique_entry(entries: Array, position: int) -> Dictionary:
	var matches: Array = []
	for entry in entries:
		if entry is Dictionary and entry.get("enemy_position") == position:
			matches.append(entry)
	_check(matches.size() == 1, "exactly one entry at enemy_position %d" % position)
	return {} if matches.is_empty() else matches[0]


func _check_entry(entries: Array, position: int, expected_actions: Array) -> void:
	var entry := _unique_entry(entries, position)
	_check(entry.size() == 2 and entry.has("enemy_position") and entry.has("pattern"),
		"entry %d has exactly enemy_position and pattern" % position)
	var pattern = entry.get("pattern")
	_check(pattern is Array and pattern.size() == expected_actions.size(),
		"entry %d has a %d-action cycle" % [position, expected_actions.size()])
	if not pattern is Array or pattern.size() != expected_actions.size():
		return
	for index in range(expected_actions.size()):
		_check(pattern[index] == expected_actions[index],
			"entry %d turn %d is exactly %s" % [position, index + 1,
				JSON.stringify(expected_actions[index])])


func _check_hero(party: CombatParty, position: int, hp: int, block: int, label: String) -> void:
	var hero := party.get_hero(position)
	_check(hero.get("hp") == hp and hero.get("block") == block,
		"%s: hero %d has %d HP and %d Block (got %d/%d)"
			% [label, position, hp, block, hero.get("hp"), hero.get("block")])


func _check_enemy(enemies: CombatEnemies, position: int, id: String, hp: int, block: int,
		label: String) -> void:
	var enemy := enemies.get_enemy(position)
	_check(enemy.get("id") == id and enemy.get("hp") == hp and enemy.get("block") == block,
		"%s: enemy %d is %s with %d HP and %d Block (got %s %d/%d)"
			% [label, position, id, hp, block, enemy.get("id"), enemy.get("hp"), enemy.get("block")])


func _build_authored_party() -> CombatParty:
	var heroes := _load_json(PARTY_PATH)
	var definitions: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		var matches: Array = []
		for hero in heroes:
			if hero is Dictionary and hero.get("id") == id:
				matches.append(hero)
		_check(matches.size() == 1, "authored hero %s found once" % id)
		definitions.append({} if matches.is_empty() else matches[0].duplicate(true))
	return CombatParty.new(definitions)


func _build_authored_enemies() -> CombatEnemies:
	var enemies := _load_json(ENEMY_PATH)
	var definitions: Array = []
	for id in ["button_guard", "spool_stalker"]:
		var matches: Array = []
		for enemy in enemies:
			if enemy is Dictionary and enemy.get("id") == id:
				matches.append(enemy)
		_check(matches.size() == 1, "authored enemy %s found once" % id)
		definitions.append({} if matches.is_empty() else matches[0].duplicate(true))
	return CombatEnemies.new(definitions)


## AC1
func _test_authored_schedule_and_parser() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "new authored encounter file exists")
	_check(ENCOUNTER_PATH.get_file().get_basename() == ENCOUNTER_ID,
		"the schedule file name carries the canonical encounter ID %s" % ENCOUNTER_ID)
	var raw: Variant = JSON.parse_string(_read_text(ENCOUNTER_PATH))
	_check(raw is Array and raw.size() == 2,
		"the authored file holds exactly this encounter's two source records")
	var parsed := _parsed()
	_check(parsed == _expected(), "real parser accepts the file as the exact prescribed schedule")
	_check(parsed.size() == 2, "the parsed schedule has exactly two sources")
	_check(CombatEnemyIntents.new(parsed).is_valid(),
		"CombatEnemyIntents.is_valid() for the new authored JSON")
	_check_entry(parsed, 1, _expected()[0]["pattern"])
	_check_entry(parsed, 2, _expected()[1]["pattern"])
	for entry in parsed:
		_check(entry.get("enemy_position") is int,
			"parsed enemy_position is an int, not a JSON float")
		var pattern: Array = entry["pattern"]
		for action in pattern:
			_check(action.get("amount") is int,
				"parsed beat amount is an int, not a JSON float")
			if action.has("target_position"):
				_check(action.get("target_position") is int,
					"parsed beat target_position is an int, not a JSON float")

	var roster := _load_json(ENEMY_PATH)
	for expected_actor in [{"id": "button_guard", "name": "Button Guard", "max_hp": 16},
			{"id": "spool_stalker", "name": "Spool Stalker", "max_hp": 14}]:
		var matches: Array = []
		for enemy in roster:
			if enemy is Dictionary and enemy.get("id") == expected_actor["id"]:
				matches.append(enemy)
		_check(matches.size() == 1, "shipped enemy %s exists exactly once" % expected_actor["id"])
		if matches.size() == 1:
			_check(matches[0].get("name") == expected_actor["name"]
				and matches[0].get("max_hp") == expected_actor["max_hp"],
				"shipped enemy %s is %s with %d max HP"
					% [expected_actor["id"], expected_actor["name"], expected_actor["max_hp"]])

	var party := _build_authored_party()
	_check(party.is_valid(), "shipped starter party builds a real three-hero party")
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("max_hp") == 40
		and party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("max_hp") == 30
		and party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("max_hp") == 26,
		"starter party is Warden/Seamstress/Tinker at 40/30/26 HP in positions 1/2/3")

	# Earlier named schedules stay parsable and are unchanged, identified by their own data only.
	var starter := RunFightEncounterSelection._parse_schedule_text(_read_text(STARTER_PATH))
	_check(CombatEnemyIntents.new(starter).is_valid(), "starter_attacks still valid")
	_check_entry(starter, 1, [
		{"type": "attack", "amount": 1, "target_position": 1},
		{"type": "attack", "amount": 1, "target_position": 2},
		{"type": "attack", "amount": 1, "target_position": 3}])
	_check_entry(starter, 2, [{"type": "block", "amount": 1}])

	var exposed := RunFightEncounterSelection._parse_schedule_text(_read_text(EXPOSED_PATH))
	_check(CombatEnemyIntents.new(exposed).is_valid(), "exposed_hem_pincer still valid")
	_check_entry(exposed, 1, [
		{"type": "debuff", "amount": 1, "target_position": 1, "status": "exposed"},
		{"type": "attack", "amount": 1, "target_position": 2},
		{"type": "block", "amount": 1}])
	_check_entry(exposed, 2, [
		{"type": "attack", "amount": 2, "target_position": 1},
		{"type": "buff", "amount": 2},
		{"type": "attack", "amount": 1, "target_position": 3}])
	_check(starter != parsed and exposed != parsed,
		"the new schedule differs from both named earlier schedules")


## AC1/AC3
func _test_intent_cycle_and_copies() -> void:
	var definitions := _parsed()
	var intents := CombatEnemyIntents.new(definitions)
	_check(intents.get_intents() == _first_intents(), "turn 1 announces the exact first beats")
	_check(intents.advance_turn(), "advance to turn 2")
	_check(intents.get_intents() == _second_intents(), "turn 2 announces the exact second beats")
	_check(intents.advance_turn(), "advance to turn 3")
	_check(intents.get_intents() == _third_intents(), "turn 3 announces the exact third beats")
	_check(intents.advance_turn(), "advance past the third beat")
	_check(intents.get_intents() == _first_intents(),
		"turn 4 repeats the first announced intents exactly")

	for turn in range(4):
		var announced := intents.get_intents()
		_check(announced.size() == 2 and announced[0].get("enemy_position") == 1
			and announced[1].get("enemy_position") == 2,
			"announcement %d lists slot 1 then slot 2" % (turn + 1))
		intents.advance_turn()

	# Repeated gets do not advance.
	var probe := CombatEnemyIntents.new(definitions)
	var first := probe.get_intents()
	var second := probe.get_intents()
	_check(first == second, "repeated get_intents does not advance the cycle")
	_check(probe.get_intents() == _first_intents(), "cycle still on first beat after repeated gets")

	# Returned announcements cannot alias selector state.
	var snapshot_selector := CombatEnemyIntents.new(_expected().duplicate(true))
	var snapshot := snapshot_selector.get_intents()
	_check(snapshot == _first_intents(), "snapshot is the exact first announced beats")
	snapshot[0]["type"] = "block"
	snapshot[0]["amount"] = 99
	snapshot.append({"enemy_position": 3, "type": "block", "amount": 5})
	_check(snapshot_selector.get_intents() == _first_intents(),
		"mutating a returned announcement cannot alter later intents")
	_check(definitions == _expected(), "parsed schedule starts from its prescribed source")
	var isolated := CombatEnemyIntents.new(definitions)
	var parsed_pattern: Array = definitions[0]["pattern"]
	parsed_pattern[0]["amount"] = 7
	_check(isolated.get_intents() == _first_intents(),
		"mutating the parsed source cannot alter an independently constructed intent selector")
	parsed_pattern[0]["amount"] = 1

	# No global RNG.
	seed(20261022)
	var baseline := randi()
	seed(20261022)
	var rng_probe := CombatEnemyIntents.new(definitions)
	for turn in range(7):
		rng_probe.get_intents()
		rng_probe.advance_turn()
	_check(randi() == baseline, "constructing, viewing and advancing this schedule draws no global RNG")
	seed(20261022)
	var without_extra := randi()
	seed(20261022)
	randi()
	_check(randi() != without_extra, "the global RNG probe detects an injected extra draw")


## AC2
func _test_real_phase_sequence() -> void:
	var party := _build_authored_party()
	_check(party.is_valid(), "authored party is valid")
	var enemies := _build_authored_enemies()
	_check(enemies.is_valid(), "authored two-enemy roster is valid")
	_check_enemy(enemies, 1, "button_guard", 16, 0, "start")
	_check_enemy(enemies, 2, "spool_stalker", 14, 0, "start")

	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "Warden opening Block 6 applies once")
	_check_hero(party, 1, 40, 6, "opening")
	_check(not opening.apply(), "opening Block cannot be applied twice")

	var scheduler := CombatEnemyIntents.new(_parsed())
	_check(scheduler.get_intents() == _first_intents(), "T1 announces Exposed then attack")

	# Turn 1: slot 1 Exposed 1 lands before slot 2's attack 3 -> floor(3 * 1.5) = 4.
	var turn1 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(turn1.get("ok") == true, "T1 phase succeeds")
	_check(turn1.get("events") == [
		{"type": "debuff", "enemy_position": 1, "target_position": 2, "status": "exposed",
			"applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true}],
		"T1 events: slot-1 Exposed then slot-2 attack, both applied")
	_check_hero(party, 1, 40, 6, "T1")
	_check_hero(party, 2, 26, 0, "T1")
	_check_hero(party, 3, 26, 0, "T1")
	_check(party.get_hero(1).get("statuses", {}) == {},
		"T1 Warden carries no status")
	_check(party.get_hero(2).get("statuses", {}) == {"exposed": 1},
		"T1 Seamstress keeps exactly Exposed 1")
	_check(party.get_hero(3).get("statuses", {}) == {},
		"T1 only the debuffed hero carries a status")
	_check_enemy(enemies, 1, "button_guard", 16, 0, "T1")
	_check_enemy(enemies, 2, "spool_stalker", 14, 0, "T1")

	_check(scheduler.advance_turn(), "explicit advance to turn 2")

	# Turn 2: slot 1 buff +3 Block on Button Guard; slot 2 Weak 1 on Tinker.
	var turn2 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(turn2.get("ok") == true, "T2 phase succeeds")
	_check(turn2.get("events") == [
		{"type": "buff", "enemy_position": 1, "applied": true},
		{"type": "debuff", "enemy_position": 2, "target_position": 3, "status": "weak",
			"applied": true}],
		"T2 events: slot-1 buff then slot-2 Weak debuff, both applied")
	_check_hero(party, 1, 40, 6, "T2")
	_check_hero(party, 2, 26, 0, "T2")
	_check_hero(party, 3, 26, 0, "T2")
	_check(party.get_hero(2).get("statuses", {}) == {"exposed": 1},
		"T2 Exposed on Seamstress is retained by the immediate phase")
	_check(party.get_hero(3).get("statuses", {}) == {"weak": 1},
		"T2 Tinker carries Weak 1")
	_check_enemy(enemies, 1, "button_guard", 16, 3, "T2")
	_check_enemy(enemies, 2, "spool_stalker", 14, 0, "T2")

	_check(scheduler.advance_turn(), "explicit advance to turn 3")

	# Turn 3: slot 1 attacks Warden for 3 (consumes 3 of 6 Block); slot 2 gains 2 Block.
	var turn3 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(turn3.get("ok") == true, "T3 phase succeeds")
	_check(turn3.get("events") == [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
		{"type": "block", "enemy_position": 2, "applied": true}],
		"T3 events: slot-1 attack on Warden then slot-2 self Block, both applied")
	_check_hero(party, 1, 40, 3, "T3")
	_check_hero(party, 2, 26, 0, "T3")
	_check_hero(party, 3, 26, 0, "T3")
	_check(party.get_hero(3).get("statuses", {}) == {"weak": 1},
		"T3 Weak on Tinker is retained by the immediate phase")
	_check_enemy(enemies, 1, "button_guard", 16, 3, "T3")
	_check_enemy(enemies, 2, "spool_stalker", 14, 2, "T3")

	_check(scheduler.advance_turn(), "explicit advance past the third beat")
	_check(scheduler.get_intents() == _first_intents(),
		"after exactly three advances the schedule announces its first intents again")


func _test_slain_source() -> void:
	var party := _build_authored_party()
	var enemies := _build_authored_enemies()
	_check(CombatStartingBlock.new(party).apply(), "slain-source precondition: opening Block applies")
	_check(enemies.apply_damage(1, 16) and enemies.is_slain(1),
		"slain-source precondition: Button Guard is slain")
	var scheduler := CombatEnemyIntents.new(_parsed())
	var before_party := party.get_heroes()
	var before_enemies := enemies.get_enemies()
	seed(20261023)
	var expected_rng := randi()
	seed(20261023)
	var result := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(randi() == expected_rng, "slain source draws no global RNG")
	_check(result.get("ok") == true, "slain-source phase still succeeds for living sources")
	_check(result.get("events") == [
		{"type": "debuff", "enemy_position": 1, "target_position": 2, "status": "exposed",
			"applied": false},
		{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true}],
		"slain source action is not applied; living source still applies")
	_check(party.get_hero(2).get("hp") == 27 and party.get_hero(2).get("statuses", {}) == {},
		"slain source deals no Exposed and its target takes only the living attack")
	_check(party.get_heroes() != before_party, "living source still mutates party")
	_check(enemies.get_enemy(1).get("hp") == 0, "slain Button Guard stays slain")


## AC3 replay
func _play_three_turns() -> Dictionary:
	var party := _build_authored_party()
	var enemies := _build_authored_enemies()
	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "replay precondition: Warden opening Block applies")
	var scheduler := CombatEnemyIntents.new(_parsed())
	var events: Array = []
	for turn in range(3):
		events.append(phase.execute_phase(party, enemies, scheduler.get_intents()))
		_check(scheduler.advance_turn(), "replay advance after turn %d" % (turn + 1))
	return {"events": events, "heroes": party.get_heroes(), "enemies": enemies.get_enemies(),
		"repeating": scheduler.get_intents()}


func _test_double_replay() -> void:
	seed(20261022)
	var expected_rng := randi()
	seed(20261022)
	var first := _play_three_turns()
	_check(randi() == expected_rng,
		"three real authored phases draw no global RNG")
	var second := _play_three_turns()
	_check(first["events"].size() == 3 and second["events"].size() == 3,
		"each replay resolved exactly three enemy phases")
	_check(first["heroes"].size() == 3 and first["enemies"].size() == 2,
		"each replay ends with the complete authored formation")
	_check(first["heroes"][0]["hp"] == 40 and first["heroes"][0]["block"] == 3
		and first["heroes"][0].get("statuses", {}) == {}
		and first["heroes"][1]["hp"] == 26 and first["heroes"][1]["block"] == 0
		and first["heroes"][1].get("statuses", {}) == {"exposed": 1}
		and first["heroes"][2]["hp"] == 26 and first["heroes"][2]["block"] == 0
		and first["heroes"][2].get("statuses", {}) == {"weak": 1},
		"replay end state is Warden 40/3, Seamstress 26/0 Exposed 1, Tinker 26/0 Weak 1")
	_check(first["enemies"][0]["id"] == "button_guard" and first["enemies"][0]["hp"] == 16
		and first["enemies"][0]["block"] == 3
		and first["enemies"][1]["id"] == "spool_stalker" and first["enemies"][1]["hp"] == 14
		and first["enemies"][1]["block"] == 2,
		"replay end state is Button Guard 16/3 and Spool Stalker 14/2")
	_check(first["repeating"] == _first_intents() and second["repeating"] == _first_intents(),
		"both copies return to the first announced intents on turn 4")
	_check(first["events"] == second["events"],
		"two independently constructed copies produce identical phase results")
	_check(first["heroes"] == second["heroes"] and first["enemies"] == second["enemies"],
		"two independently constructed copies end in identical party and enemy state")


## AC3 selection
func _test_selection() -> void:
	var seed_value := 4103
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var replay_rng := RandomNumberGenerator.new()
	replay_rng.seed = seed_value
	var oracle_rng := RandomNumberGenerator.new()
	oracle_rng.seed = seed_value
	var map := RunMap.new()
	var replay_map := RunMap.new()
	var oracle_map := RunMap.new()
	_check(map.generate(rng) and replay_map.generate(replay_rng) and oracle_map.generate(oracle_rng),
		"three same-seed maps generate")
	var id := ""
	for candidate in map.get_legal_choices():
		if map.get_node(candidate).get("type") == "Fight":
			id = candidate
			break
	_check(not id.is_empty(), "a real legal opening Fight exists")
	_check(map.choose_node(id) and replay_map.choose_node(id) and oracle_map.choose_node(id),
		"all routes choose opening Fight")
	_check(map.get_current_node_id() == id and map.get_node(id).get("type") == "Fight",
		"chosen CURRENT node is Fight")

	var pool := {"spoolguard_misdirection": ENCOUNTER_PATH}
	var ids: Array = pool.keys()
	ids.sort()
	# A single-candidate pool selects index 0 without consuming RNG.
	var expected_id: String = ids[0]
	var after_one_draw := oracle_rng.state

	var selector := RunFightEncounterSelection.new()
	var replay_selector := RunFightEncounterSelection.new()

	seed(765430)
	var global_expected := randi()
	seed(765430)
	var answer := selector.select_current_fight(map, rng, pool)
	_check(randi() == global_expected, "selector leaves Godot global RNG undrawn")
	_check(answer.get("success", false) and answer.get("encounter_id") == expected_id,
		"first choice selects the authored encounter")
	_check(answer.get("encounter_id") == ENCOUNTER_ID, "first choice encounter_id is canonical")
	_check(answer.get("definitions", []) == _parsed(), "first selection returns complete authored schedule")
	_check(rng.state == after_one_draw, "first choice leaves exact one-draw RNG state")

	var replay := replay_selector.select_current_fight(replay_map, replay_rng, pool)
	_check(replay == answer and replay_rng.state == rng.state,
		"fresh same-seed run replays exactly")

	# Cached same-node pick returns same deep-copied result without extra RNG draw.
	var cached_rng_state := rng.state
	var cached := selector.select_current_fight(map, rng, {})
	_check(cached == answer, "cached pick returns the same result")
	_check(rng.state == cached_rng_state, "cached pick draws no extra RNG")

	# Deep-copy isolation.
	var first_copy := answer.duplicate(true)
	answer["definitions"][0]["pattern"][0]["amount"] = 900
	answer["definitions"][0]["pattern"][0]["type"] = "invented"
	answer["definitions"].clear()
	answer["encounter_id"] = "mutated"
	var reread := selector.select_current_fight(map, rng, pool)
	_check(reread == first_copy, "caller mutations cannot affect later cached reads")
	_check(rng.state == cached_rng_state, "mutating and reading cached result consumes zero RNG")

	# New map/selector with same seed reproduces selection and run RNG.
	var new_rng := RandomNumberGenerator.new()
	new_rng.seed = seed_value
	var new_map := RunMap.new()
	_check(new_map.generate(new_rng), "new same-seed map generates")
	var new_id := ""
	for candidate in new_map.get_legal_choices():
		if new_map.get_node(candidate).get("type") == "Fight":
			new_id = candidate
			break
	_check(new_map.choose_node(new_id), "new map chooses opening Fight")
	var new_selector := RunFightEncounterSelection.new()
	var new_answer := new_selector.select_current_fight(new_map, new_rng, pool)
	_check(new_answer == first_copy and new_rng.state == rng.state,
		"new same-seed map/selector reproduces selection and run RNG")

	# Returned schedule instantiates real intents.
	var intents := CombatEnemyIntents.new(first_copy["definitions"])
	_check(intents.is_valid(), "selected returned array instantiates real CombatEnemyIntents")
	for turn in range(4):
		var expected_actions: Array = []
		for def in _expected():
			var action: Dictionary = def["pattern"][turn % def["pattern"].size()].duplicate(true)
			action["enemy_position"] = def["enemy_position"]
			expected_actions.append(action)
		_check(intents.get_intents() == expected_actions,
			"selected choice gets exact authored turn %d for both enemy owners" % turn)
		_check(intents.advance_turn(), "selected intents advance owner turn %d" % turn)


## AC3 atomic negative
func _test_atomic_negative() -> void:
	# Valid-then-invalid two-action batch.
	var party := _build_authored_party()
	var enemies := _build_authored_enemies()
	_check(CombatStartingBlock.new(party).apply(), "negative: opening Block applied")
	_check(party.apply_damage(3, 26) and party.is_downed(3),
		"negative: Tinker is legitimately downed")
	var batch := [
		{"type": "buff", "amount": 3, "enemy_position": 1},
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak",
			"enemy_position": 2}]
	var before_party := party.get_heroes()
	var before_enemies := enemies.get_enemies()
	seed(20261024)
	var expected_rng := randi()
	seed(20261024)
	var result := phase.execute_phase(party, enemies, batch)
	_check(randi() == expected_rng, "negative: rejected batch draws no global RNG")
	_check(result == {"ok": false, "events": []},
		"negative: valid buff then invalid Weak-to-downed rejects whole phase")
	_check(party.get_heroes() == before_party, "negative: no hero change survives")
	_check(enemies.get_enemies() == before_enemies, "negative: no enemy change survives")
	_check(enemies.get_enemy(1).get("block") == 0,
		"negative: zero staged Block retained on Button Guard")

	# Unsupported status fails closed.
	party = _build_authored_party()
	enemies = _build_authored_enemies()
	_check(CombatStartingBlock.new(party).apply(), "negative: second opening Block applied")
	before_party = party.get_heroes()
	before_enemies = enemies.get_enemies()
	var bad_status := [
		{"type": "debuff", "amount": 1, "target_position": 1, "status": "poison",
			"enemy_position": 1}]
	seed(20261025)
	expected_rng = randi()
	seed(20261025)
	_check(phase.execute_phase(party, enemies, bad_status) == {"ok": false, "events": []},
		"negative: unsupported status rejects the phase")
	_check(randi() == expected_rng, "negative: unsupported status draws no global RNG")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"negative: unsupported status changes nothing")

	# Malformed action fails closed.
	party = _build_authored_party()
	enemies = _build_authored_enemies()
	_check(CombatStartingBlock.new(party).apply(), "negative: third opening Block applied")
	before_party = party.get_heroes()
	before_enemies = enemies.get_enemies()
	var malformed := [
		{"type": "debuff", "amount": "1", "target_position": 1, "status": "exposed",
			"enemy_position": 1}]
	seed(20261026)
	expected_rng = randi()
	seed(20261026)
	_check(phase.execute_phase(party, enemies, malformed) == {"ok": false, "events": []},
		"negative: malformed action rejects the phase")
	_check(randi() == expected_rng, "negative: malformed action draws no global RNG")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"negative: malformed action changes nothing")