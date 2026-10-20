extends SceneTree

## Deterministic headless coverage for the authored Twin-Hem Crossguard encounter:
## fixed three-beat crossfire from Ragling (slot 1) and Guard Ragling (slot 2).
## Each source opens on a flank, raises 1 Block on the second beat, then both
## converge on the middle hero. This file never wires the encounter into live play;
## it proves the authored data, the real parser/intent/phase services and the
## seeded RunFightEncounterSelection eligibility for a caller-supplied pool.

const ENCOUNTER_PATH := "res://data/encounters/twin_hem_crossguard.json"
const ENCOUNTER_ID := "twin_hem_crossguard"
const STARTER_PATH := "res://data/encounters/starter_attacks.json"
const GUARD_PATH := "res://data/encounters/guard_counterattack.json"
const ENCOUNTER_DIR := "res://data/encounters"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_authored_schedule_and_parser()
	_test_intent_cycle_and_copies()
	_test_real_phase_sequence()
	_test_negative_resolution()
	_test_real_selection_path()
	if failures.is_empty():
		print("twin_hem_crossguard_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("twin_hem_crossguard_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## The exact prescribed schedule for this encounter's own two sources.
func _expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 3},
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 2}]},
	]


func _starter_expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "attack", "amount": 1, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]},
	]


func _guard_expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 1}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 3},
			{"type": "block", "amount": 1}]},
	]


func _expected_for(id: String) -> Array:
	match id:
		ENCOUNTER_ID:
			return _expected()
		"starter_attacks":
			return _starter_expected()
		"guard_counterattack":
			return _guard_expected()
	return []


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "opens " + path)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _parsed() -> Array:
	return RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))


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


## Complete position-ordered announcement for any turn, built from the prescription.
func _announced_for(turn: int) -> Array:
	var announced: Array = []
	for entry in _expected():
		var pattern: Array = entry["pattern"]
		var action: Dictionary = pattern[turn % pattern.size()].duplicate(true)
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
	var entry_keys: Array = entry.keys()
	entry_keys.sort()
	_check(entry_keys == ["enemy_position", "pattern"],
		"entry %d has exactly enemy_position and pattern" % position)
	var pattern = entry.get("pattern")
	_check(pattern is Array and pattern.size() == expected_actions.size(),
		"entry %d has a %d-action cycle" % [position, expected_actions.size()])
	if not pattern is Array or pattern.size() != expected_actions.size():
		return
	for index in range(expected_actions.size()):
		var action = pattern[index]
		var expected_action: Dictionary = expected_actions[index]
		_check(action is Dictionary, "entry %d turn %d is a dictionary" % [position, index])
		if not action is Dictionary:
			continue
		var expected_keys: Array = expected_action.keys()
		expected_keys.sort()
		var actual_keys: Array = action.keys()
		actual_keys.sort()
		_check(actual_keys == expected_keys,
			"entry %d turn %d has exactly the schema keys %s" % [position, index, expected_keys])
		_check(action.get("type") == expected_action.get("type"),
			"entry %d turn %d has type %s" % [position, index, expected_action.get("type")])
		_check(action.get("amount") == expected_action.get("amount"),
			"entry %d turn %d has amount %d" % [position, index, expected_action.get("amount")])
		_check(action.has("target_position") == expected_action.has("target_position"),
			"entry %d turn %d target_position presence matches the prescription" % [position, index])
		if expected_action.has("target_position"):
			_check(action.get("target_position") == expected_action.get("target_position"),
				"entry %d turn %d targets hero %d" % [position, index,
					expected_action.get("target_position")])
		_check(action == expected_action,
			"entry %d turn %d is exactly %s" % [position, index, JSON.stringify(expected_action)])


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


## A fresh authored party whose Block is explicitly zero on a fresh player turn.
func _fresh_fixtures() -> Dictionary:
	var party := _build_authored_party()
	var enemies := _build_authored_enemies()
	party.start_player_turn()
	return {"party": party, "enemies": enemies}


func _test_authored_schedule_and_parser() -> void:
	# AC1: the real on-disk file parses through the real selection service parser.
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "new authored encounter file exists")
	var parsed := _parsed()
	_check(parsed == _expected(), "real parser accepts the file as the exact prescribed schedule")
	_check(parsed.size() == 2, "the encounter authors exactly its own two sources")
	_check(CombatEnemyIntents.new(parsed).is_valid(),
		"CombatEnemyIntents.is_valid() for the new authored JSON")
	_check_entry(parsed, 1, _expected()[0]["pattern"])
	_check_entry(parsed, 2, _expected()[1]["pattern"])

	# Every prescribed amount is exactly 1 and Block never carries a hero target.
	for position in [1, 2]:
		var entry := _unique_entry(parsed, position)
		var pattern: Array = entry.get("pattern", [])
		for index in range(pattern.size()):
			if not pattern[index] is Dictionary:
				continue
			_check(pattern[index].get("amount") == 1,
				"entry %d turn %d amount is exactly 1" % [position, index])
			if pattern[index].get("type") == "block":
				_check(not pattern[index].has("target_position"),
					"entry %d turn %d Block has no target_position" % [position, index])

	# AC1 opening-vs-middle and crossfire identity, from the parsed schedule alone.
	var opening := _announced_for(0)
	var opening_targets: Array = []
	for intent in opening:
		if intent["type"] == "attack":
			opening_targets.append(int(intent["target_position"]))
	_check(opening_targets == [1, 3],
		"opening beat attacks the two flank heroes, never the middle")
	var convergence := _announced_for(2)
	_check(convergence[0].get("target_position") == 2 and convergence[1].get("target_position") == 2,
		"third beat has both sources converge on hero position 2")

	# Distinct from every earlier authored encounter file on disk (no catalogue-total assumption).
	var files := DirAccess.get_files_at(ENCOUNTER_DIR)
	_check(files.has("twin_hem_crossguard.json"), "authored encounter directory lists the new file")
	var compared := 0
	for file_name in files:
		if not file_name.ends_with(".json") or file_name == "twin_hem_crossguard.json":
			continue
		var other := RunFightEncounterSelection._parse_schedule_text(
			_read_text(ENCOUNTER_DIR + "/" + file_name))
		if other.is_empty():
			continue
		compared += 1
		_check(other != parsed,
			"earlier authored encounter %s differs from the new schedule" % file_name)
	_check(compared >= 2, "at least the named earlier encounters were compared by their own data")

	# AC1: the named existing encounters remain parsable with their complete ordered actions.
	var starter := RunFightEncounterSelection._parse_schedule_text(_read_text(STARTER_PATH))
	_check(starter == _starter_expected(), "starter_attacks still parses to its complete own schedule")
	_check_entry(starter, 1, _starter_expected()[0]["pattern"])
	_check_entry(starter, 2, _starter_expected()[1]["pattern"])
	_check(CombatEnemyIntents.new(starter).is_valid(), "starter_attacks still valid")

	var guard := RunFightEncounterSelection._parse_schedule_text(_read_text(GUARD_PATH))
	_check(guard == _guard_expected(), "guard_counterattack still parses to its complete own schedule")
	_check_entry(guard, 1, _guard_expected()[0]["pattern"])
	_check_entry(guard, 2, _guard_expected()[1]["pattern"])
	_check(CombatEnemyIntents.new(guard).is_valid(), "guard_counterattack still valid")

	# The authored files themselves are untouched by parsing.
	_check(_parsed() == _expected(), "new encounter JSON unchanged after all parser reads")
	_check(RunFightEncounterSelection._parse_schedule_text(_read_text(STARTER_PATH))
		== _starter_expected(), "starter_attacks JSON unchanged after parser reads")
	_check(RunFightEncounterSelection._parse_schedule_text(_read_text(GUARD_PATH))
		== _guard_expected(), "guard_counterattack JSON unchanged after parser reads")


func _test_intent_cycle_and_copies() -> void:
	# AC2: six consecutive announced phases reproduce turns 0,1,2 twice, in slot order 1 then 2.
	var definitions := _parsed()
	var intents := CombatEnemyIntents.new(definitions)
	_check(intents.is_valid(), "real parsed schedule instantiates the intent selector")
	var seen: Array[Array] = []
	for turn in range(6):
		var announced := intents.get_intents()
		_check(announced == _announced_for(turn),
			"turn %d announces the exact scheduled actions" % turn)
		_check(announced.size() == 2 and announced[0].get("enemy_position") == 1
			and announced[1].get("enemy_position") == 2,
			"turn %d announces slot 1 then slot 2" % turn)
		seen.append(announced)
		_check(intents.advance_turn(), "turn %d advance succeeds" % turn)
	_check(seen[0] == seen[3] and seen[1] == seen[4] and seen[2] == seen[5],
		"turns 3-5 wrap exactly to the turn 0-2 pattern")

	# Author order never changes the position-ordered announcement.
	var reversed_definitions := definitions.duplicate(true)
	reversed_definitions.reverse()
	var reversed_intents := CombatEnemyIntents.new(reversed_definitions)
	_check(reversed_intents.is_valid() and reversed_intents.get_intents() == _announced_for(0),
		"announcements stay position-ordered with reversed author order")

	# AC2: announcements and advancement consume no RNG (dedicated instance, so the
	# cycle above stays at its wrap turn).
	var probe := CombatEnemyIntents.new(definitions.duplicate(true))
	seed(20261021)
	var baseline := randi()
	seed(20261021)
	probe.get_intents()
	probe.advance_turn()
	_check(randi() == baseline, "get_intents and advance_turn consume no global RNG")
	seed(20261021)
	var without_extra := randi()
	seed(20261021)
	randi()
	_check(randi() != without_extra, "global RNG probe detects an injected extra draw")

	_check(definitions == _expected(), "selector construction never mutates the parsed source")

	# AC2: returned snapshots are isolated copies.
	var snapshot := intents.get_intents()
	_check(snapshot == _announced_for(6), "snapshot is the exact scheduled wrap turn")
	snapshot[0]["type"] = "block"
	snapshot[0]["amount"] = 99
	snapshot[0]["target_position"] = 3
	snapshot.append({"enemy_position": 3, "type": "block", "amount": 5})
	var later := intents.get_intents()
	_check(later.size() == 2, "mutated snapshot does not grow later announcements")
	_check(later[0].get("type") != "block" and later[0].get("amount") == 1,
		"mutated snapshot does not alter later announced actions")
	_check(later == _announced_for(6), "later announcement is the exact scheduled wrap turn")
	_check(later != snapshot, "returned snapshots are independent of one another")

	# Clearing the caller's parsed array cannot alter the selector.
	var source_copy := definitions.duplicate(true)
	definitions.clear()
	_check(intents.get_intents() == _announced_for(6),
		"clearing the parsed source cannot alter the intent selector")
	_check(source_copy == _expected(), "the parsed snapshot is independent of the selector")

	# An independent replay from the same prescription announces the identical timeline.
	var replay := CombatEnemyIntents.new(_expected().duplicate(true))
	_check(replay.is_valid(), "replay selector is valid")
	for turn in range(6):
		_check(replay.get_intents() == seen[turn],
			"independent replay turn %d matches the first timeline" % turn)
		_check(replay.advance_turn(), "independent replay advances turn %d" % turn)


func _test_real_phase_sequence() -> void:
	# AC3: real authored party/enemies through the real starting-Block and enemy-phase services.
	var party := _build_authored_party()
	_check(party.is_valid(), "authored party is valid")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 0
		and party.get_hero(2).get("hp") == 30 and party.get_hero(3).get("hp") == 26,
		"authored heroes start 40/30/26 HP and no Block in positions 1-3")
	var enemies := _build_authored_enemies()
	_check(enemies.is_valid(), "authored enemy roster is valid")
	_check_enemy(enemies, 1, "ragling", 12, 0, "start")
	_check_enemy(enemies, 2, "ragling_guard", 12, 0, "start")

	var starting_block := CombatStartingBlock.new(party)
	_check(starting_block.apply(), "Warden's real opening Block applies once")
	_check_hero(party, 1, 40, 6, "opening")
	_check(not starting_block.apply(), "opening Block cannot be applied twice")

	var scheduler := CombatEnemyIntents.new(_parsed())
	_check(scheduler.is_valid(), "real schedule drives the real phase")
	var phase := CombatEnemyPhase.new()

	# Turn 0: flank attack on Warden is absorbed by the opening Block; flank attack on Tinker lands.
	var turn_zero := scheduler.get_intents()
	_check(turn_zero == _announced_for(0), "turn 0 announces flank attacks on positions 1 and 3")
	var result_zero := phase.execute_phase(party, enemies, turn_zero)
	_check(result_zero == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true}]},
		"turn 0 events: slot 1 then slot 2, both attacks applied")
	_check_hero(party, 1, 40, 5, "turn 0")
	_check_hero(party, 2, 30, 0, "turn 0")
	_check_hero(party, 3, 25, 0, "turn 0")
	_check_enemy(enemies, 1, "ragling", 12, 0, "turn 0")
	_check_enemy(enemies, 2, "ragling_guard", 12, 0, "turn 0")
	_check(scheduler.advance_turn(), "advance to turn 1")
	_check(party.start_player_turn(), "player turn explicitly resets hero Block")
	_check_hero(party, 1, 40, 0, "player reset")
	_check_enemy(enemies, 1, "ragling", 12, 0, "player reset keeps enemy Block untouched")
	_check_enemy(enemies, 2, "ragling_guard", 12, 0, "player reset keeps enemy Block untouched")

	# Turn 1: both sources raise exactly 1 Block; hero Block stays reset at 0.
	var turn_one := scheduler.get_intents()
	_check(turn_one == _announced_for(1), "turn 1 announces one Block from each source")
	var result_one := phase.execute_phase(party, enemies, turn_one)
	_check(result_one == {"ok": true, "events": [
		{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "block", "enemy_position": 2, "applied": true}]},
		"turn 1 events: slot 1 then slot 2, both Blocks applied")
	_check_hero(party, 1, 40, 0, "turn 1")
	_check_hero(party, 2, 30, 0, "turn 1")
	_check_hero(party, 3, 25, 0, "turn 1")
	_check_enemy(enemies, 1, "ragling", 12, 1, "turn 1")
	_check_enemy(enemies, 2, "ragling_guard", 12, 1, "turn 1")
	_check(scheduler.advance_turn(), "advance to turn 2")
	_check(party.start_player_turn(), "second player turn resets hero Block")
	# Enemy Block is not part of the player reset boundary and persists into turn 2.
	_check_enemy(enemies, 1, "ragling", 12, 1, "enemy Block persists across player reset")
	_check_enemy(enemies, 2, "ragling_guard", 12, 1, "enemy Block persists across player reset")

	# Turn 2: both sources converge on the middle hero, for 2 total damage; enemy Block persists.
	var turn_two := scheduler.get_intents()
	_check(turn_two == _announced_for(2), "turn 2 announces the middle-hero crossfire")
	var result_two := phase.execute_phase(party, enemies, turn_two)
	_check(result_two == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true}]},
		"turn 2 events: slot 1 then slot 2, both attacks on hero 2 applied")
	_check_hero(party, 1, 40, 0, "turn 2")
	_check_hero(party, 2, 28, 0, "turn 2")
	_check_hero(party, 3, 25, 0, "turn 2")
	_check_enemy(enemies, 1, "ragling", 12, 1, "turn 2")
	_check_enemy(enemies, 2, "ragling_guard", 12, 1, "turn 2")
	_check(enemies.get_enemy(1).get("hp") == 12 and enemies.get_enemy(2).get("hp") == 12,
		"enemy HP is untouched by their own Block beats")


func _test_negative_resolution() -> void:
	var phase := CombatEnemyPhase.new()

	# Slain slot-1 attacker is skipped; the living slot-2 attacker still acts.
	var pair := _fresh_fixtures()
	var party: CombatParty = pair["party"]
	var enemies: CombatEnemies = pair["enemies"]
	_check(enemies.apply_damage(1, 12) and enemies.is_slain(1),
		"negative: Ragling at slot 1 is slain")
	var scheduler := CombatEnemyIntents.new(_parsed())
	var slain := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(slain == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": false},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true}]},
		"negative: slain slot-1 attack is not applied while the living slot-2 attack lands")
	_check_hero(party, 1, 40, 0, "slain attacker")
	_check_hero(party, 2, 30, 0, "slain attacker")
	_check_hero(party, 3, 25, 0, "slain attacker")
	_check_enemy(enemies, 1, "ragling", 0, 0, "slain attacker")
	_check_enemy(enemies, 2, "ragling_guard", 12, 0, "slain attacker")
	_check(scheduler.advance_turn(), "negative: advance the slain-source fixture to turn 1")
	var slain_block := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(slain_block == {"ok": true, "events": [
		{"type": "block", "enemy_position": 1, "applied": false},
		{"type": "block", "enemy_position": 2, "applied": true}]},
		"negative: a slain source cannot gain Block on the next beat")
	_check_enemy(enemies, 1, "ragling", 0, 0, "slain blocker")
	_check_enemy(enemies, 2, "ragling_guard", 12, 1, "slain blocker")

	# A downed hero on the opening flank is never retargeted.
	pair = _fresh_fixtures()
	party = pair["party"]
	enemies = pair["enemies"]
	_check(party.apply_damage(1, 40) and party.is_downed(1),
		"negative: Warden at slot 1 is downed")
	scheduler = CombatEnemyIntents.new(_parsed())
	var downed_open := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(downed_open == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": false},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true}]},
		"negative: attack aimed at the downed flank stays unapplied and is not redirected")
	_check_hero(party, 1, 0, 0, "downed flank")
	_check_hero(party, 2, 30, 0, "downed flank")
	_check_hero(party, 3, 25, 0, "downed flank")
	_check_enemy(enemies, 1, "ragling", 12, 0, "downed flank")
	_check_enemy(enemies, 2, "ragling_guard", 12, 0, "downed flank")

	# Both converging attacks on a downed middle hero are inapplicable, never redirected.
	pair = _fresh_fixtures()
	party = pair["party"]
	enemies = pair["enemies"]
	_check(party.apply_damage(2, 30) and party.is_downed(2),
		"negative: Seamstress at slot 2 is downed")
	scheduler = CombatEnemyIntents.new(_parsed())
	_check(scheduler.advance_turn() and scheduler.advance_turn(),
		"negative: advance to the converging turn 2")
	var downed_middle := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(downed_middle == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": false},
		{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": false}]},
		"negative: both crossfire attacks stay unapplied when the middle hero is downed")
	_check_hero(party, 1, 40, 0, "downed middle")
	_check_hero(party, 2, 0, 0, "downed middle")
	_check_hero(party, 3, 26, 0, "downed middle")
	_check_enemy(enemies, 1, "ragling", 12, 0, "downed middle")
	_check_enemy(enemies, 2, "ragling_guard", 12, 0, "downed middle")

	# An entirely slain roster produces ordered skipped events and mutates nothing.
	pair = _fresh_fixtures()
	party = pair["party"]
	enemies = pair["enemies"]
	_check(enemies.apply_damage(1, 12) and enemies.apply_damage(2, 12),
		"negative: both sources are slain")
	var heroes_before := party.get_heroes()
	var enemies_before := enemies.get_enemies()
	scheduler = CombatEnemyIntents.new(_parsed())
	var all_slain := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(all_slain == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": false},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": false}]},
		"negative: an all-slain phase reports ordered skipped events")
	_check(party.get_heroes() == heroes_before and enemies.get_enemies() == enemies_before,
		"negative: an all-slain phase never damages heroes or revives sources")

	# No buff, debuff or shove action is accepted by this schedule's schema.
	for kind in ["buff", "debuff", "shove"]:
		var unsupported := _expected().duplicate(true)
		unsupported[0]["pattern"][1] = {"type": kind, "amount": 1}
		_check(unsupported != _expected(), "negative: %s probe actually changed the fixture" % kind)
		_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(unsupported)).is_empty(),
			"negative: real parser rejects a %s action" % kind)
		_check(not CombatEnemyIntents.new(unsupported).is_valid(),
			"negative: intent validator rejects a %s action" % kind)

	# Block with a hero target and status-laden attacks stay invalid.
	var targeted_block := _expected().duplicate(true)
	targeted_block[1]["pattern"][1] = {"type": "block", "amount": 1, "target_position": 2}
	_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(targeted_block)).is_empty()
		and not CombatEnemyIntents.new(targeted_block).is_valid(),
		"negative: a Block carrying target_position is rejected")
	var status_attack := _expected().duplicate(true)
	status_attack[0]["pattern"][0]["status"] = "bleed"
	_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(status_attack)).is_empty()
		and not CombatEnemyIntents.new(status_attack).is_valid(),
		"negative: an attack with an extra status key is rejected")
	var untargeted := _expected().duplicate(true)
	untargeted[0]["pattern"][0].erase("target_position")
	_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(untargeted)).is_empty()
		and not CombatEnemyIntents.new(untargeted).is_valid(),
		"negative: an attack without target_position is rejected")
	var fractional := JSON.stringify(_expected()).replace("\"amount\":1", "\"amount\":1.5")
	_check(fractional != JSON.stringify(_expected()), "negative: fractional probe actually changed the fixture")
	_check(RunFightEncounterSelection._parse_schedule_text(fractional).is_empty(),
		"negative: a non-integral amount is rejected instead of truncated")
	_check(not _parsed().is_empty(), "negative: the unmodified authored file still parses")


func _two_pool(reversed: bool = false) -> Dictionary:
	var pool := {}
	if reversed:
		pool[ENCOUNTER_ID] = ENCOUNTER_PATH
		pool["starter_attacks"] = STARTER_PATH
	else:
		pool["starter_attacks"] = STARTER_PATH
		pool[ENCOUNTER_ID] = ENCOUNTER_PATH
	return pool


func _map_with_fight(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := RunMap.new()
	_check(map.generate(rng), "real RunMap generates from the seeded run RNG")
	var fight_id := ""
	for candidate in map.get_legal_choices():
		if map.get_node(candidate).get("type") == "Fight":
			fight_id = candidate
			break
	_check(not fight_id.is_empty(), "opening floor offers a real legal Fight")
	return {"rng": rng, "map": map, "fight_id": fight_id}


func _snapshot(map: RunMap, rng: RandomNumberGenerator,
		picker: RunFightEncounterSelection) -> Dictionary:
	return {
		"floors": map.get_floors(),
		"route": map.get_route(),
		"current": map.get_current_node_id(),
		"choices": map.get_legal_choices(),
		"floor": map.get_current_floor(),
		"rng": rng.state,
		"cache": picker._selected.duplicate(true),
		"bound": picker._bound_map,
	}


func _reject(map: RunMap, rng: RandomNumberGenerator, picker: RunFightEncounterSelection,
		pool: Dictionary, label: String, supplied_rng: RandomNumberGenerator = null) -> void:
	var before := _snapshot(map, rng, picker)
	var answer := picker.select_current_fight(map, supplied_rng, pool)
	_check(answer == {"success": false}, label + ": rejected with no encounter")
	_check(_snapshot(map, rng, picker) == before,
		label + ": graph, route, run RNG, binding and cache all unchanged")


func _test_real_selection_path() -> void:
	# AC4: the real seeded map + selector path accepts the new path in a caller-supplied pool.
	var seed_value := 20261021
	var start := _map_with_fight(seed_value)
	var rng: RandomNumberGenerator = start["rng"]
	var map: RunMap = start["map"]
	var fight_id: String = start["fight_id"]
	var picker := RunFightEncounterSelection.new()
	var two := _two_pool()

	# Failed selections preserve route, RNG and cache, then a valid retry succeeds.
	_reject(RunMap.new(), rng, picker, two, "ungenerated map", rng)
	_reject(map, rng, picker, two, "legal but UNCHOSEN opening Fight", rng)
	if fight_id.is_empty():
		return
	_check(map.choose_node(fight_id) and map.get_current_node_id() == fight_id
		and map.get_node(fight_id).get("type") == "Fight",
		"the chosen CURRENT node is the real offered Fight")
	_reject(map, rng, picker, two, "null RNG")
	_reject(map, rng, picker, {}, "empty candidate pool", rng)
	_reject(map, rng, picker, {"absent": "res://data/encounters/no_such_twin_hem_fight.json"},
		"missing candidate file", rng)
	_reject(map, rng, picker, {"bad": "res://data/enemies/starter_enemies.json"},
		"candidate outside the encounter directory", rng)
	_reject(map, rng, picker, {"bad": "res://data/encounters/../enemies/starter_enemies.json"},
		"noncanonical candidate path", rng)
	_reject(map, rng, picker, {ENCOUNTER_ID: ENCOUNTER_PATH,
		"broken": "res://data/encounters/unknown_twin_hem_fight.json"},
		"malformed later candidate path rejects the whole pool", rng)
	_reject(map, rng, picker, {"bad": null}, "non-string candidate path", rng)
	_reject(map, rng, picker, {1: ENCOUNTER_PATH}, "non-string encounter ID", rng)
	_reject(map, rng, picker, {"": ENCOUNTER_PATH}, "empty encounter ID", rng)
	_check(picker._selected.is_empty() and picker._bound_map == null,
		"no failed attempt bound the selector or cached a choice")

	# Independent seeded oracle: same map, same Fight, one sorted-index draw.
	var oracle := _map_with_fight(seed_value)
	var oracle_rng: RandomNumberGenerator = oracle["rng"]
	var oracle_map: RunMap = oracle["map"]
	_check(oracle_map.get_floors() == map.get_floors() and oracle["fight_id"] == fight_id,
		"same-seed oracle reaches the identical graph and Fight")
	_check(oracle_map.choose_node(fight_id), "oracle chooses the same real Fight")
	var sorted_ids: Array = two.keys()
	sorted_ids.sort()
	_check(sorted_ids == ["starter_attacks", ENCOUNTER_ID],
		"two-entry pool is exactly the named starter and the new encounter by their own IDs")
	var oracle_id: String = sorted_ids[oracle_rng.randi_range(0, sorted_ids.size() - 1)]
	var oracle_state: int = oracle_rng.state

	var answer := picker.select_current_fight(map, rng, two)
	_check(answer.get("success", false) and answer.get("encounter_id") == oracle_id,
		"selection is the exact single sorted-index RNG draw of the oracle")
	_check(answer.get("definitions", []) == _expected_for(oracle_id),
		"selection returns the complete canonical schedule of the chosen ID")
	_check(rng.state == oracle_state, "selection leaves exactly the oracle's one-draw RNG state")
	var selected_intents := CombatEnemyIntents.new(answer.get("definitions", []))
	_check(selected_intents.is_valid() and selected_intents.get_intents()
		== _announced_for_id(oracle_id, 0),
		"selected definitions instantiate a valid position-ordered real intent selector")

	# Reversed Dictionary insertion order must replay the same draw and RNG state.
	var replay := _map_with_fight(seed_value)
	var replay_rng: RandomNumberGenerator = replay["rng"]
	var replay_map: RunMap = replay["map"]
	_check(replay_map.choose_node(fight_id), "same-seed replay reaches the same real Fight")
	var replay_answer := RunFightEncounterSelection.new().select_current_fight(
		replay_map, replay_rng, _two_pool(true))
	_check(replay_answer == answer and replay_rng.state == rng.state,
		"reversed insertion order replays the same ID, definitions and RNG state")

	# The cached choice is detached from every caller mutation and spends no extra RNG.
	var pristine := answer.duplicate(true)
	var cached := picker.select_current_fight(map, rng, {})
	_check(cached == pristine and rng.state == oracle_state,
		"cached re-query returns the same choice and consumes no RNG even with no pool")
	answer["encounter_id"] = "mutated"
	answer["definitions"][0]["pattern"][0]["amount"] = 900
	answer["definitions"].clear()
	_check(picker.select_current_fight(map, rng, two) == pristine,
		"mutating a returned choice cannot alter the cached selection")
	_check(rng.state == oracle_state, "mutating and re-reading the cache consumes zero RNG")

	# AC4: a one-entry pool containing only the new encounter can select it specifically.
	var solo_seed := 771043
	var solo := _map_with_fight(solo_seed)
	var solo_rng: RandomNumberGenerator = solo["rng"]
	var solo_map: RunMap = solo["map"]
	_check(not solo["fight_id"].is_empty() and solo_map.choose_node(solo["fight_id"]),
		"one-entry pool fixture reaches its real Fight")
	var solo_oracle := _map_with_fight(solo_seed)
	var solo_oracle_rng: RandomNumberGenerator = solo_oracle["rng"]
	_check(solo_oracle["map"].choose_node(solo_oracle["fight_id"]),
		"one-entry oracle reaches the same real Fight")
	var solo_ids: Array = [ENCOUNTER_ID]
	_check(solo_ids[solo_oracle_rng.randi_range(0, solo_ids.size() - 1)] == ENCOUNTER_ID,
		"one-entry oracle draw can only name the new encounter")
	var solo_state: int = solo_oracle_rng.state
	var solo_answer := RunFightEncounterSelection.new().select_current_fight(
		solo_map, solo_rng, {ENCOUNTER_ID: ENCOUNTER_PATH})
	_check(solo_answer.get("success", false)
		and solo_answer.get("encounter_id") == ENCOUNTER_ID,
		"one-entry pool selects the new encounter by its own ID")
	_check(solo_answer.get("definitions", []) == _expected(),
		"one-entry pool returns the new encounter's exact definitions")
	_check(solo_rng.state == solo_state,
		"one-entry selection spends exactly its own single sorted draw")


## Position-ordered announcements for an arbitrary selected ID.
func _announced_for_id(id: String, turn: int) -> Array:
	var announced: Array = []
	for entry in _expected_for(id):
		var pattern: Array = entry["pattern"]
		var action: Dictionary = pattern[turn % pattern.size()].duplicate(true)
		action["enemy_position"] = entry["enemy_position"]
		announced.append(action)
	return announced
