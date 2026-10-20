extends SceneTree

## Deterministic headless coverage for the authored Three-Point Thread Trap encounter:
## fixed three-beat positional pressure from Ragling (slot 1) and Guard Ragling (slot 2).

const ENCOUNTER_PATH := "res://data/encounters/three_point_thread_trap.json"
const ENCOUNTER_ID := "three_point_thread_trap"
const STARTER_PATH := "res://data/encounters/starter_attacks.json"
const GUARD_PATH := "res://data/encounters/guard_counterattack.json"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_authored_schedule_and_parser()
	_test_intent_cycle_and_copies()
	_test_real_phase_sequence()
	_test_negative_resolution()
	_test_real_selection_path()
	if failures.is_empty():
		print("three_point_thread_trap_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("three_point_thread_trap_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## The exact prescribed schedule: 3-beat attacks covering positions 1, 2, 3, each punctuated by a Block.
func _expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 3}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "block", "amount": 1}]},
	]


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


## Godot's JSON parser yields whole numbers as floats; the real model services
## require ints for max_hp, so authored fixtures are normalized exactly.
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


func _announced_for(turn: int) -> Array:
	var announced: Array = []
	for entry in _expected():
		var action: Dictionary = entry["pattern"][turn % 3].duplicate(true)
		action["enemy_position"] = entry["enemy_position"]
		announced.append(action)
	return announced


## One named entry, located by its own enemy_position (never by list order or a catalogue total).
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
			"entry %d turn %d is exactly %s" % [position, index, JSON.stringify(expected_actions[index])])
		if expected_actions[index].has("target_position"):
			_check(pattern[index].get("target_position") >= 1
				and pattern[index].get("target_position") <= 3,
				"entry %d turn %d targets a real hero position 1-3" % [position, index])


func _check_hero(party: CombatParty, position: int, hp: int, block: int, label: String) -> void:
	var hero := party.get_hero(position)
	_check(hero.get("hp") == hp and hero.get("block") == block,
		"%s: hero %d has %d HP and %d Block (got %d/%d)"
			% [label, position, hp, block, hero.get("hp"), hero.get("block")])


func _check_enemy(enemies: CombatEnemies, position: int, id: String, hp: int, block: int, label: String) -> void:
	var enemy := enemies.get_enemy(position)
	_check(enemy.get("id") == id and enemy.get("hp") == hp and enemy.get("block") == block,
		"%s: enemy %d is %s with %d HP and %d Block (got %s %d/%d)"
			% [label, position, id, hp, block, enemy.get("id"), enemy.get("hp"), enemy.get("block")])


func _build_authored_party() -> CombatParty:
	var heroes := _load_json("res://data/heroes/starter_party.json")
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
	var enemies := _load_json("res://data/enemies/starter_enemies.json")
	var definitions: Array = []
	for id in ["ragling", "ragling_guard"]:
		var matches: Array = []
		for enemy in enemies:
			if enemy is Dictionary and enemy.get("id") == id:
				matches.append(enemy)
		_check(matches.size() == 1, "authored enemy %s found once" % id)
		definitions.append({} if matches.is_empty() else matches[0].duplicate(true))
	return CombatEnemies.new(definitions)


func _test_authored_schedule_and_parser() -> void:
	# AC1: the real file parses through the real selection service and matches the prescription.
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "new authored encounter file exists")
	var parsed := RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	_check(parsed == _expected(), "real parser accepts the file as the exact prescribed schedule")
	_check(CombatEnemyIntents.new(parsed).is_valid(), "CombatEnemyIntents.is_valid() for the new JSON")
	_check_entry(parsed, 1, _expected()[0]["pattern"])
	_check_entry(parsed, 2, _expected()[1]["pattern"])

	# The three-beat pressure really visits all three hero positions once each cycle.
	var targets: Array = []
	for entry in _expected():
		for action in entry["pattern"]:
			if action["type"] == "attack" and not targets.has(action["target_position"]):
				targets.append(action["target_position"])
	targets.sort()
	_check(targets == [1, 2, 3], "one cycle visits hero positions 1, 2 and 3")
	_check(_expected()[0]["pattern"][1]["type"] == "block"
		and _expected()[1]["pattern"][2]["type"] == "block",
		"each enemy contributes exactly one Block beat per cycle")

	# Pre-existing authored encounters stay readable and unchanged, by their own actions only.
	var starter := RunFightEncounterSelection._parse_schedule_text(_read_text(STARTER_PATH))
	_check_entry(starter, 1, [
		{"type": "attack", "amount": 1, "target_position": 1},
		{"type": "attack", "amount": 1, "target_position": 2}])
	_check_entry(starter, 2, [{"type": "block", "amount": 1}])
	_check(CombatEnemyIntents.new(starter).is_valid(), "starter_attacks still valid")

	var guard := RunFightEncounterSelection._parse_schedule_text(_read_text(GUARD_PATH))
	_check_entry(guard, 1, [
		{"type": "block", "amount": 1},
		{"type": "attack", "amount": 1, "target_position": 1}])
	_check_entry(guard, 2, [
		{"type": "attack", "amount": 1, "target_position": 3},
		{"type": "block", "amount": 1}])
	_check(CombatEnemyIntents.new(guard).is_valid(), "guard_counterattack still valid")


func _test_intent_cycle_and_copies() -> void:
	# AC2: six consecutive announced phases reproduce turns 0,1,2 twice, in slot order 1 then 2.
	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	var intents := CombatEnemyIntents.new(definitions)
	var seen: Array[Array] = []
	for turn in range(6):
		var announced := intents.get_intents()
		_check(announced == _announced_for(turn), "turn %d announces the exact scheduled actions" % turn)
		_check(announced.size() == 2 and announced[0].get("enemy_position") == 1
			and announced[1].get("enemy_position") == 2,
			"turn %d announces slot 1 then slot 2" % turn)
		seen.append(announced)
		_check(intents.advance_turn(), "turn %d advance succeeds" % turn)
	_check(seen[0] == seen[3] and seen[1] == seen[4] and seen[2] == seen[5],
		"turn 3-5 wrap exactly to the turn 0-2 pattern")

	# Announcements and advancement never consume global RNG (on a dedicated instance,
	# so the cycle above stays at its wrap turn).
	var probe := CombatEnemyIntents.new(definitions)
	var baseline := 0
	seed(20261021)
	baseline = randi()
	seed(20261021)
	probe.get_intents()
	probe.advance_turn()
	_check(randi() == baseline, "get_intents and advance_turn consume no global RNG")
	# Prove the probe would notice a draw, so the check above cannot pass vacuously.
	seed(20261021)
	var without_extra := randi()
	seed(20261021)
	randi()
	_check(randi() != without_extra, "global RNG probe detects an injected extra draw")

	# Defensive copies: mutating a returned snapshot or the parsed source cannot alter later announcements.
	var snapshot := intents.get_intents()
	_check(snapshot == _announced_for(6), "snapshot is the exact scheduled wrap turn")
	snapshot[0]["type"] = "block"
	snapshot[0]["amount"] = 99
	snapshot.append({"enemy_position": 3, "type": "block", "amount": 5})
	var later := intents.get_intents()
	_check(later.size() == 2, "mutated snapshot does not grow later announcements")
	_check(later[0].get("type") != "block" and later[0].get("amount") == 1,
		"mutated snapshot does not alter later announced actions")
	_check(later == _announced_for(6), "later announcement is the exact scheduled wrap turn")
	_check(definitions == _expected(), "parsed schedule starts from its prescribed source")
	var parsed_snapshot := definitions.duplicate(true)
	definitions.clear()
	_check(intents.get_intents() == _announced_for(6),
		"clearing the parsed source cannot alter the intent selector")
	_check(parsed_snapshot == _expected(), "the parsed snapshot is independent of the selector")


func _test_real_phase_sequence() -> void:
	# AC3: real authored party/enemies through the real starting-Block and enemy-phase services.
	var party := _build_authored_party()
	_check(party.is_valid(), "authored party is valid")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(2).get("hp") == 30
		and party.get_hero(3).get("hp") == 26,
		"authored heroes start 40/30/26 HP in positions 1-3")
	var enemies := _build_authored_enemies()
	_check(enemies.is_valid(), "authored enemy roster is valid")
	_check_enemy(enemies, 1, "ragling", 12, 0, "start")
	_check_enemy(enemies, 2, "ragling_guard", 12, 0, "start")

	var starting_block := CombatStartingBlock.new(party)
	_check(starting_block.apply(), "Warden opening Block applies once")
	_check_hero(party, 1, 40, 6, "opening")
	_check(not starting_block.apply(), "opening Block cannot be applied twice")

	var scheduler := CombatEnemyIntents.new(
		RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH)))
	var phase := CombatEnemyPhase.new()

	# Turn 0: Ragling attacks position 1 into the opening Block; Guard Ragling attacks position 2.
	var result0 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(result0.get("ok") == true, "turn 0 phase succeeds")
	_check(result0.get("events") == [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true}],
		"turn 0 events: slot 1 then slot 2, both attacks applied")
	_check_hero(party, 1, 40, 5, "turn 0")
	_check_hero(party, 2, 29, 0, "turn 0")
	_check_hero(party, 3, 26, 0, "turn 0")
	_check_enemy(enemies, 1, "ragling", 12, 0, "turn 0")
	_check_enemy(enemies, 2, "ragling_guard", 12, 0, "turn 0")
	_check(scheduler.advance_turn(), "advance to turn 1")
	_check(party.start_player_turn(), "player turn resets hero Block")
	_check_hero(party, 1, 40, 0, "player reset")

	# Turn 1: Ragling gains 1 Block; Guard Ragling attacks position 1.
	var result1 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(result1.get("ok") == true, "turn 1 phase succeeds")
	_check(result1.get("events") == [
		{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true}],
		"turn 1 events: Ragling Block then Guard attack on slot 1")
	_check_enemy(enemies, 1, "ragling", 12, 1, "turn 1")
	_check_enemy(enemies, 2, "ragling_guard", 12, 0, "turn 1")
	_check_hero(party, 1, 39, 0, "turn 1")
	_check_hero(party, 2, 29, 0, "turn 1")
	_check_hero(party, 3, 26, 0, "turn 1")
	_check(scheduler.advance_turn(), "advance to turn 2")
	_check(party.start_player_turn(), "second player turn resets hero Block")

	# Turn 2: Ragling attacks position 3; Guard Ragling gains 1 Block. Enemy Block persists.
	var result2 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(result2.get("ok") == true, "turn 2 phase succeeds")
	_check(result2.get("events") == [
		{"type": "attack", "enemy_position": 1, "target_position": 3, "applied": true},
		{"type": "block", "enemy_position": 2, "applied": true}],
		"turn 2 events: Ragling attack on slot 3 then Guard Block")
	_check_hero(party, 1, 39, 0, "turn 2")
	_check_hero(party, 2, 29, 0, "turn 2")
	_check_hero(party, 3, 25, 0, "turn 2")
	_check_enemy(enemies, 1, "ragling", 12, 1, "turn 2")
	_check_enemy(enemies, 2, "ragling_guard", 12, 1, "turn 2")
	_check(enemies.get_enemy(1).get("block") == 1,
		"enemy Block persists across turns (Ragling keeps turn 1's Block)")
	_check(enemies.get_enemy(1).get("hp") == 12 and enemies.get_enemy(2).get("hp") == 12,
		"enemy HP is untouched by their own Block beats")


func _test_negative_resolution() -> void:
	# AC4a: a slain slot-1 attacker is skipped; the living slot-2 attacker still acts.
	var party := _build_authored_party()
	var enemies := _build_authored_enemies()
	_check(CombatStartingBlock.new(party).apply(), "negative: opening Block applied")
	var scheduler := CombatEnemyIntents.new(
		RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH)))
	var phase := CombatEnemyPhase.new()
	_check(enemies.apply_damage(1, 12) and enemies.is_slain(1), "negative: Ragling at slot 1 slain")
	var slain_result := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(slain_result.get("events") == [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": false},
		{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true}],
		"negative: slain slot-1 attack not applied, living slot-2 attack applied")
	_check_hero(party, 1, 40, 6, "slain attacker")
	_check_hero(party, 2, 29, 0, "slain attacker")
	_check_hero(party, 3, 26, 0, "slain attacker")
	_check_enemy(enemies, 1, "ragling", 0, 0, "slain attacker")
	_check_enemy(enemies, 2, "ragling_guard", 12, 0, "slain attacker")

	# AC4b: a downed intended target is skipped, never retargeted; the slot-2 attacker still acts on turn 1.
	party = _build_authored_party()
	enemies = _build_authored_enemies()
	_check(party.apply_damage(2, 30) and party.is_downed(2), "negative: Seamstress at slot 2 downed")
	scheduler = CombatEnemyIntents.new(
		RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH)))
	var turn0 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(turn0.get("events") == [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": false}],
		"negative: attack on the downed slot-2 hero stays targeted and unapplied")
	_check_hero(party, 1, 39, 0, "downed target")
	_check_hero(party, 2, 0, 0, "downed target")
	_check_hero(party, 3, 26, 0, "downed target")
	_check_enemy(enemies, 1, "ragling", 12, 0, "downed target")
	_check_enemy(enemies, 2, "ragling_guard", 12, 0, "downed target")
	_check(scheduler.advance_turn(), "negative: advance to turn 1")
	var turn1 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(turn1.get("events") == [
		{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true}],
		"negative: with slot 2 downed, the living slot-2 attacker still acts")
	_check_hero(party, 1, 38, 0, "downed target turn 1")
	_check_hero(party, 2, 0, 0, "downed target turn 1")
	_check_enemy(enemies, 1, "ragling", 12, 1, "downed target turn 1")

	# AC4c: a schedule variant lacking an attack target is rejected by the real parser/validator.
	var untargeted: Array = _expected().duplicate(true)
	var untargeted_entry: Dictionary = untargeted[0]
	var untargeted_pattern: Array = untargeted_entry["pattern"]
	untargeted_pattern[0].erase("target_position")
	var untargeted_text := JSON.stringify(untargeted)
	_check(RunFightEncounterSelection._parse_schedule_text(untargeted_text).is_empty(),
		"negative: malformed slot-1 attack without target_position is rejected")
	_check(not CombatEnemyIntents.new(untargeted).is_valid(),
		"negative: intent validator also rejects the untargeted attack")
	var fractional := JSON.stringify(_expected()).replace("\"target_position\":2", "\"target_position\":2.5")
	_check(fractional != JSON.stringify(_expected()), "negative: fractional probe actually changed the fixture")
	_check(RunFightEncounterSelection._parse_schedule_text(fractional).is_empty(),
		"negative: non-integral target_position is rejected")
	_check(not RunFightEncounterSelection._parse_schedule_text(JSON.stringify(_expected())).is_empty(),
		"negative: the unmodified prescription still parses")


func _test_real_selection_path() -> void:
	# AC5: the real seeded map + selector path can choose and cache this encounter.
	var seed_value := 20261021
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := RunMap.new()
	_check(map.generate(rng), "real RunMap generates from the run RNG")
	var fight_id := ""
	for candidate in map.get_legal_choices():
		if map.get_node(candidate).get("type") == "Fight":
			fight_id = candidate
			break
	_check(not fight_id.is_empty(), "opening floor offers a real legal Fight")
	var pool := {ENCOUNTER_ID: ENCOUNTER_PATH}

	# Rejection before a legal Fight is chosen, with the run RNG preserved.
	var before_state := rng.state
	var unselected := RunFightEncounterSelection.new()
	_check(unselected.select_current_fight(map, rng, pool) == {"success": false},
		"selection before choosing a Fight is rejected")
	_check(rng.state == before_state and unselected._selected.is_empty()
		and unselected._bound_map == null,
		"rejected selection preserves RNG, cache and map binding")

	_check(map.choose_node(fight_id) and map.get_current_node_id() == fight_id,
		"the chosen CURRENT node is the real Fight")
	var selector := RunFightEncounterSelection.new()
	var answer := selector.select_current_fight(map, rng, pool)
	_check(answer.get("success") == true and answer.get("encounter_id") == ENCOUNTER_ID,
		"selector returns the new encounter by its own ID")
	_check(answer.get("definitions") == _expected(),
		"selector returns the exact prescribed definitions")
	_check(CombatEnemyIntents.new(answer.get("definitions", [])).is_valid(),
		"returned definitions instantiate a valid real intent selector")
	var picked_state := rng.state
	# An independent mirror of the same seeded run shows the exact RNG the one sorted-index draw spends.
	var mirror := RandomNumberGenerator.new()
	mirror.seed = seed_value
	var mirror_map := RunMap.new()
	_check(mirror_map.generate(mirror) and mirror_map.choose_node(fight_id),
		"mirror run reaches the same Fight")
	var sorted_ids: Array = pool.keys()
	sorted_ids.sort()
	_check(sorted_ids == [ENCOUNTER_ID], "selection pool is the new encounter by its own ID")
	var mirrored_id: String = sorted_ids[mirror.randi_range(0, sorted_ids.size() - 1)]
	_check(mirrored_id == ENCOUNTER_ID and mirrored_id == answer.get("encounter_id"),
		"mirror predicts the new encounter as the selected ID")
	_check(mirror.state == picked_state,
		"selection leaves exactly the one-draw RNG state of the mirror run")

	# Same seed, fresh map and selector: identical choice and identical RNG state.
	var replay_rng := RandomNumberGenerator.new()
	replay_rng.seed = seed_value
	var replay_map := RunMap.new()
	_check(replay_map.generate(replay_rng) and replay_map.choose_node(fight_id),
		"same-seed replay map reaches the same Fight")
	var replay := RunFightEncounterSelection.new().select_current_fight(replay_map, replay_rng, pool)
	_check(replay == answer and replay_rng.state == picked_state,
		"same-seed replay returns the same choice and RNG state")

	# The cached choice is isolated from caller mutation.
	var pristine := answer.duplicate(true)
	answer["encounter_id"] = "mutated"
	answer["definitions"][0]["pattern"][0]["amount"] = 99
	answer["definitions"].clear()
	var cached := selector.select_current_fight(map, rng, pool)
	_check(cached == pristine and cached.get("encounter_id") == ENCOUNTER_ID,
		"mutating a returned choice cannot alter the cached selection")
	_check(rng.state == picked_state, "cached re-query consumes no RNG")
