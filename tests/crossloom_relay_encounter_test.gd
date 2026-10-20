extends SceneTree

## Deterministic headless coverage for the authored Crossloom Relay encounter:
## Ragling (enemy slot 1) runs a three-beat loop and Guard Ragling (slot 2) a
## four-beat loop, so their combined cycle is twelve enemy phases. This file
## proves the authored data, the real parser/intent/phase services, the exact
## isolated multi-phase ledger and seeded RunFightEncounterSelection eligibility
## for a caller-supplied pool. It never wires the encounter into live play and
## never resets the party between the repeated enemy phases.

const ENCOUNTER_PATH := "res://data/encounters/crossloom_relay.json"
const ENCOUNTER_ID := "crossloom_relay"
const GUARD_PATH := "res://data/encounters/guard_counterattack.json"
const CROSS_STITCH_PATH := "res://data/encounters/cross_stitch_guard.json"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMIES_PATH := "res://data/enemies/starter_enemies.json"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_authored_schedule_and_parser()
	_test_intent_cycle_and_copies()
	_test_real_phase_sequence()
	_test_negative_resolution()
	_test_real_selection_path()
	if failures.is_empty():
		print("crossloom_relay_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("crossloom_relay_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## The exact prescribed schedule for this encounter's own two sources.
func _expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 1}]},
		{"enemy_position": 2, "pattern": [
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 3},
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "attack", "amount": 1, "target_position": 1}]},
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


func _cross_stitch_expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 3},
			{"type": "block", "amount": 1}]},
		{"enemy_position": 2, "pattern": [
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 1}]},
	]


func _expected_for(id: String) -> Array:
	match id:
		ENCOUNTER_ID:
			return _expected()
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
		var items: Array = []
		for item in data:
			items.append(_normalize_json(item))
		return items
	if data is Dictionary:
		var record: Dictionary = {}
		for key in data:
			record[key] = _normalize_json(data[key])
		return record
	if data is float and data == int(data):
		return int(data)
	return data


## Complete announcement for any turn, built from a prescription's patterns.
func _announced_from(definitions: Array, turn: int) -> Array:
	var announced: Array = []
	for entry in definitions:
		var pattern: Array = entry["pattern"]
		var action: Dictionary = pattern[turn % pattern.size()].duplicate(true)
		action["enemy_position"] = entry["enemy_position"]
		announced.append(action)
	return announced


func _announced_for(turn: int) -> Array:
	return _announced_from(_expected(), turn)


func _announced_for_id(id: String, turn: int) -> Array:
	return _announced_from(_expected_for(id), turn)


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
		_check(action.get("amount") is int and action.get("amount") == 1,
			"entry %d turn %d amount is the integer 1" % [position, index])
		_check(action.has("target_position") == expected_action.has("target_position"),
			"entry %d turn %d target_position presence matches the prescription" % [position, index])
		if expected_action.has("target_position"):
			_check(action.get("target_position") is int
				and action.get("target_position") == expected_action.get("target_position"),
				"entry %d turn %d targets hero %d" % [position, index,
					expected_action.get("target_position")])
		_check(action == expected_action,
			"entry %d turn %d is exactly %s" % [position, index, JSON.stringify(expected_action)])


func _check_hero(party: CombatParty, position: int, hp: int, block: int, label: String) -> void:
	var hero := party.get_hero(position)
	_check(hero.get("hp") == hp and hero.get("block") == block,
		"%s: hero %d has %d HP and %d Block (got %d/%d)"
			% [label, position, hp, block, hero.get("hp"), hero.get("block")])


func _check_enemy(enemies: CombatEnemies, position: int, id: String,
		hp: int, block: int, label: String) -> void:
	var enemy := enemies.get_enemy(position)
	_check(enemy.get("id") == id and enemy.get("hp") == hp and enemy.get("block") == block,
		"%s: enemy %d is %s with %d HP and %d Block (got %s %d/%d)"
			% [label, position, id, hp, block, enemy.get("id"),
				enemy.get("hp"), enemy.get("block")])


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
	var enemies := _load_json(ENEMIES_PATH)
	var definitions: Array = []
	for id in ["ragling", "ragling_guard"]:
		var matches: Array = []
		for enemy in enemies:
			if enemy is Dictionary and enemy.get("id") == id:
				matches.append(enemy)
		_check(matches.size() == 1, "authored enemy %s found once" % id)
		definitions.append({} if matches.is_empty() else matches[0].duplicate(true))
	return CombatEnemies.new(definitions)


## Authored party/enemy fixtures (a fresh party always starts with zero Block).
func _fresh_fixtures() -> Dictionary:
	return {"party": _build_authored_party(), "enemies": _build_authored_enemies()}


## The exact announced pair for each of the twelve combined phases.
func _phase_events() -> Array:
	return [
		[{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
			{"type": "block", "enemy_position": 2, "applied": true}],
		[{"type": "block", "enemy_position": 1, "applied": true},
			{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true}],
		[{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
			{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true}],
		[{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
			{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true}],
		[{"type": "block", "enemy_position": 1, "applied": true},
			{"type": "block", "enemy_position": 2, "applied": true}],
		[{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
			{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true}],
		[{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
			{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true}],
		[{"type": "block", "enemy_position": 1, "applied": true},
			{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true}],
		[{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
			{"type": "block", "enemy_position": 2, "applied": true}],
		[{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
			{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true}],
		[{"type": "block", "enemy_position": 1, "applied": true},
			{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true}],
		[{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
			{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true}],
	]


## Hero [hp, block] ledger after each phase, in positions 1-3.
func _hero_ledger() -> Array:
	return [
		[[40, 6], [29, 0], [26, 0]],
		[[40, 6], [29, 0], [25, 0]],
		[[40, 5], [28, 0], [25, 0]],
		[[40, 4], [27, 0], [25, 0]],
		[[40, 4], [27, 0], [25, 0]],
		[[40, 3], [27, 0], [24, 0]],
		[[40, 3], [25, 0], [24, 0]],
		[[40, 2], [25, 0], [24, 0]],
		[[40, 1], [25, 0], [24, 0]],
		[[40, 1], [24, 0], [23, 0]],
		[[40, 1], [23, 0], [23, 0]],
		[[39, 0], [23, 0], [23, 0]],
	]


## Enemy [hp, block] ledger after each phase, in positions 1-2.
func _enemy_ledger() -> Array:
	return [
		[[12, 0], [12, 1]],
		[[12, 1], [12, 1]],
		[[12, 1], [12, 1]],
		[[12, 1], [12, 1]],
		[[12, 2], [12, 2]],
		[[12, 2], [12, 2]],
		[[12, 2], [12, 2]],
		[[12, 3], [12, 2]],
		[[12, 3], [12, 3]],
		[[12, 3], [12, 3]],
		[[12, 4], [12, 3]],
		[[12, 4], [12, 3]],
	]


func _check_ledger(party: CombatParty, enemies: CombatEnemies, phase: int, label: String) -> void:
	var heroes: Array = _hero_ledger()[phase]
	var foes: Array = _enemy_ledger()[phase]
	for position in range(1, 4):
		_check_hero(party, position, heroes[position - 1][0], heroes[position - 1][1], label)
	_check_enemy(enemies, 1, "ragling", foes[0][0], foes[0][1], label)
	_check_enemy(enemies, 2, "ragling_guard", foes[1][0], foes[1][1], label)


func _test_authored_schedule_and_parser() -> void:
	# AC1: the real on-disk file parses through the real selection service parser.
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "new authored encounter file exists")
	var parsed := _parsed()
	_check(parsed == _expected(), "real parser accepts the file as the exact prescribed schedule")
	_check(parsed.size() == 2, "the encounter authors exactly its own two sources")
	_check(CombatEnemyIntents.new(parsed).is_valid(),
		"CombatEnemyIntents.is_valid() for the new authored JSON")
	var entry_one := _unique_entry(parsed, 1)
	var entry_two := _unique_entry(parsed, 2)
	_check(entry_one.get("pattern", []).size() == 3, "slot 1 runs a three-beat cycle")
	_check(entry_two.get("pattern", []).size() == 4, "slot 2 runs a four-beat cycle")
	_check_entry(parsed, 1, _expected()[0]["pattern"])
	_check_entry(parsed, 2, _expected()[1]["pattern"])

	# Seven authored actions, each exactly 1 damage or 1 Block, Block never targeted.
	var actions: Array = []
	for entry in parsed:
		for action in entry.get("pattern", []):
			actions.append(action)
	_check(actions.size() == 7, "the two patterns hold exactly seven authored actions")
	for action in actions:
		_check(action.get("amount") is int, "every amount is an integer")
		_check(action.get("amount") == 1, "every authored action is exactly 1")
		if action.get("type") == "block":
			_check(not action.has("target_position"), "Block actions never carry target_position")
		else:
			_check(action.get("type") == "attack" and action.has("target_position"),
				"damage actions are targeted attacks")

	# AC1: the named earlier encounters remain parsable with their complete ordered actions.
	var guard := RunFightEncounterSelection._parse_schedule_text(_read_text(GUARD_PATH))
	_check(guard == _guard_expected(), "guard_counterattack still parses to its complete own schedule")
	_check_entry(guard, 1, _guard_expected()[0]["pattern"])
	_check_entry(guard, 2, _guard_expected()[1]["pattern"])
	_check(CombatEnemyIntents.new(guard).is_valid(), "guard_counterattack still valid")

	var cross_stitch := RunFightEncounterSelection._parse_schedule_text(_read_text(CROSS_STITCH_PATH))
	_check(cross_stitch == _cross_stitch_expected(),
		"cross_stitch_guard still parses to its complete own schedule")
	_check_entry(cross_stitch, 1, _cross_stitch_expected()[0]["pattern"])
	_check_entry(cross_stitch, 2, _cross_stitch_expected()[1]["pattern"])
	_check(CombatEnemyIntents.new(cross_stitch).is_valid(), "cross_stitch_guard still valid")

	# Reading and parsing never rewrite the authored files.
	_check(_parsed() == _expected(), "new encounter JSON unchanged after all parser reads")
	_check(RunFightEncounterSelection._parse_schedule_text(_read_text(GUARD_PATH))
		== _guard_expected(), "guard_counterattack JSON unchanged after parser reads")
	_check(RunFightEncounterSelection._parse_schedule_text(_read_text(CROSS_STITCH_PATH))
		== _cross_stitch_expected(), "cross_stitch_guard JSON unchanged after parser reads")


func _test_intent_cycle_and_copies() -> void:
	# AC2: two independent schedulers announce the same exact pairs for phases 0-12.
	var definitions := _parsed()
	var first := CombatEnemyIntents.new(definitions)
	var second := CombatEnemyIntents.new(definitions.duplicate(true))
	_check(first.is_valid() and second.is_valid(),
		"two independent schedulers accept the real parsed schedule")
	var seen: Array[Array] = []
	for phase in range(13):
		var announced: Array = first.get_intents()
		var echoed: Array = second.get_intents()
		seen.append(announced)
		_check(announced == _announced_for(phase),
			"phase %d announces the exact scheduled actions" % phase)
		_check(announced == echoed, "phase %d matches the independent scheduler" % phase)
		_check(announced.size() == 2, "phase %d announces exactly two sources" % phase)
		if announced.size() == 2:
			_check(announced[0].get("enemy_position") == 1
				and announced[1].get("enemy_position") == 2,
				"phase %d announces slot 1 then slot 2" % phase)
		# Exactly one advance per enemy phase on both schedulers.
		_check(first.advance_turn(), "phase %d advances exactly once" % phase)
		_check(second.advance_turn(), "phase %d advances the replay exactly once" % phase)
	_check(seen.size() == 13, "the complete phase 0-12 timeline was observed")
	_check(seen[12] == seen[0], "phase 12 repeats phase 0")
	_check(first.get_intents() == _announced_for(13),
		"the next phase after 12 wraps to the phase-13 announcement")

	# Advancing one scheduler never advances the other.
	var isolated := CombatEnemyIntents.new(_expected().duplicate(true))
	var untouched := CombatEnemyIntents.new(_expected().duplicate(true))
	_check(isolated.advance_turn(), "independent scheduler advances")
	_check(isolated.get_intents() == _announced_for(1)
		and untouched.get_intents() == _announced_for(0),
		"advancing one scheduler leaves the other on its own phase")

	# Author order never changes the position-ordered announcement.
	var reversed_definitions := _expected().duplicate(true)
	reversed_definitions.reverse()
	var reversed_intents := CombatEnemyIntents.new(reversed_definitions)
	var reversed_announced := reversed_intents.get_intents()
	_check(reversed_intents.is_valid(), "reversed author order is still valid")
	_check(reversed_announced == _announced_for(0),
		"announcements stay position-ordered with reversed author order")
	_check(reversed_announced.size() == 2 and reversed_announced[0].get("enemy_position") == 1,
		"reversed author order still announces slot 1 first")

	# AC2: stepping intents consumes no randomness. Check the same global stream
	# production code could use, then prove the probe detects an extra draw.
	var probe := CombatEnemyIntents.new(_expected().duplicate(true))
	seed(20261021)
	var baseline := randi()
	seed(20261021)
	probe.get_intents()
	probe.advance_turn()
	probe.get_intents()
	_check(randi() == baseline, "get_intents and advance_turn consume no global RNG")
	seed(20261021)
	var without_extra := randi()
	seed(20261021)
	randi()
	_check(randi() != without_extra, "global RNG probe detects an injected extra draw")

	# A supplied seeded RNG passed alongside the scheduler also stays untouched.
	var supplied := RandomNumberGenerator.new()
	supplied.seed = 424242
	var supplied_state := supplied.state
	var supplied_probe := CombatEnemyIntents.new(_expected().duplicate(true))
	supplied_probe.get_intents()
	supplied_probe.advance_turn()
	_check(supplied.state == supplied_state,
		"intent stepping does not consume a supplied seeded RNG")

	# AC2: returned snapshots and the caller's input are isolated from later mutation.
	var snapshot: Array = first.get_intents()
	_check(snapshot == _announced_for(13), "snapshot is the exact scheduled phase")
	snapshot[0]["type"] = "block"
	snapshot[0]["amount"] = 99
	snapshot[0]["target_position"] = 3
	snapshot.append({"enemy_position": 3, "type": "block", "amount": 5})
	var later := first.get_intents()
	_check(later.size() == 2, "mutated snapshot does not grow later announcements")
	_check(later == _announced_for(13), "mutated snapshot does not alter later announcements")
	_check(later != snapshot, "returned snapshots are independent of one another")

	var source_copy := definitions.duplicate(true)
	definitions.clear()
	_check(first.get_intents() == _announced_for(13),
		"clearing the parsed source cannot alter the intent selector")
	_check(source_copy == _expected(), "the parsed snapshot is independent of the selector")

	# The parsed source itself was never mutated by construction.
	_check(_parsed() == _expected(), "intent construction never mutates the parsed source")


func _test_real_phase_sequence() -> void:
	# AC3: real authored party/enemies through the real starting-Block and enemy-phase services.
	var party := _build_authored_party()
	_check(party.is_valid(), "authored party is valid")
	_check_hero(party, 1, 40, 0, "start")
	_check_hero(party, 2, 30, 0, "start")
	_check_hero(party, 3, 26, 0, "start")
	_check(party.get_hero(1).get("id") == "warden"
		and party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(3).get("id") == "tinker",
		"authored slots 1-3 are Warden, Seamstress and Tinker")

	var enemies := _build_authored_enemies()
	_check(enemies.is_valid(), "authored enemy roster is valid")
	_check_enemy(enemies, 1, "ragling", 12, 0, "start")
	_check_enemy(enemies, 2, "ragling_guard", 12, 0, "start")

	var starting_block := CombatStartingBlock.new(party)
	_check(starting_block.apply(), "Warden's real opening +6 Block applies once")
	_check_hero(party, 1, 40, 6, "opening Block")
	_check(not starting_block.apply(), "opening Block cannot be applied twice")
	_check_hero(party, 1, 40, 6, "opening Block stays a single grant")

	var scheduler := CombatEnemyIntents.new(_parsed())
	_check(scheduler.is_valid(), "real schedule drives the real phase")
	var phase := CombatEnemyPhase.new()
	var events := _phase_events()
	var heroes := _hero_ledger()
	var foes := _enemy_ledger()

	# Isolated enemy phases 0-11: no player-turn start/reset is invoked anywhere.
	for index in range(12):
		var announced := scheduler.get_intents()
		_check(announced == _announced_for(index),
			"phase %d uses the authored announcement" % index)
		var result := phase.execute_phase(party, enemies, announced)
		_check(result == {"ok": true, "events": events[index]},
			"phase %d events are ordered, typed and flagged as authored" % index)
		var result_events: Array = result.get("events", [])
		_check(result_events.size() == 2, "phase %d emits exactly two events" % index)
		for event_index in range(result_events.size()):
			var event: Dictionary = result_events[event_index]
			var expected_event: Dictionary = events[index][event_index]
			_check(event.get("enemy_position") == event_index + 1,
				"phase %d event %d comes from the expected source slot" % [index, event_index])
			_check(event.get("type") == expected_event["type"],
				"phase %d event %d has the expected type" % [index, event_index])
			_check(event.get("applied") == true,
				"phase %d event %d is applied on the real fixture" % [index, event_index])
			if expected_event.has("target_position"):
				_check(event.get("target_position") == expected_event["target_position"],
					"phase %d event %d targets hero %d"
						% [index, event_index, expected_event["target_position"]])
			else:
				_check(not event.has("target_position"),
					"phase %d event %d has no hero target for Block" % [index, event_index])
		_check_ledger(party, enemies, index, "phase %d" % index)
		_check(scheduler.advance_turn(), "advance from phase %d" % index)

	# The named AC3 checkpoints, restated from the final ledger.
	var after_three := 3
	_check(heroes[after_three][0] == [40, 4] and heroes[after_three][1] == [27, 0]
		and heroes[after_three][2] == [25, 0],
		"phase 3 ledger is Warden 40/4, Seamstress 27, Tinker 25")
	_check(foes[after_three][0] == [12, 1] and foes[after_three][1] == [12, 1],
		"phase 3 ledger has both enemies at 12 HP and 1 Block")
	_check(heroes[11][0] == [39, 0] and heroes[11][1] == [23, 0]
		and heroes[11][2] == [23, 0],
		"phase 11 ledger is Warden 39/0, Seamstress 23, Tinker 23")
	_check(foes[11][0] == [12, 4] and foes[11][1] == [12, 3],
		"phase 11 ledger is Ragling 12/4 and Guard Ragling 12/3")
	_check_enemy(enemies, 1, "ragling", 12, 4, "final")
	_check_enemy(enemies, 2, "ragling_guard", 12, 3, "final")
	_check_hero(party, 1, 39, 0, "final")
	_check_hero(party, 2, 23, 0, "final")
	_check_hero(party, 3, 23, 0, "final")


func _test_negative_resolution() -> void:
	var phase := CombatEnemyPhase.new()

	# A slain slot-1 source contributes nothing; the living slot-2 source still acts.
	var pair := _fresh_fixtures()
	var party: CombatParty = pair["party"]
	var enemies: CombatEnemies = pair["enemies"]
	_check(enemies.apply_damage(1, 12) and enemies.is_slain(1),
		"negative: Ragling at slot 1 is slain")
	var scheduler := CombatEnemyIntents.new(_parsed())
	var slain_phase := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(slain_phase == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": false},
		{"type": "block", "enemy_position": 2, "applied": true}]},
		"negative: the slain slot-1 attack is skipped while slot 2 raises Block")
	_check_hero(party, 1, 40, 0, "slain attacker")
	_check_hero(party, 2, 30, 0, "slain attacker")
	_check_hero(party, 3, 26, 0, "slain attacker")
	_check_enemy(enemies, 1, "ragling", 0, 0, "slain attacker")
	_check_enemy(enemies, 2, "ragling_guard", 12, 1, "slain attacker")
	_check(scheduler.advance_turn(), "negative: advance the slain-source fixture")
	var slain_block := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(slain_block == {"ok": true, "events": [
		{"type": "block", "enemy_position": 1, "applied": false},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true}]},
		"negative: a slain source cannot gain Block while the other source attacks")
	_check_enemy(enemies, 1, "ragling", 0, 0, "slain blocker")
	_check_enemy(enemies, 2, "ragling_guard", 12, 1, "slain blocker")
	_check_hero(party, 3, 25, 0, "slain blocker")

	# A downed middle hero is never retargeted by the authored attack aimed there.
	pair = _fresh_fixtures()
	party = pair["party"]
	enemies = pair["enemies"]
	_check(party.apply_damage(2, 30) and party.is_downed(2),
		"negative: Seamstress at slot 2 is downed")
	scheduler = CombatEnemyIntents.new(_parsed())
	var downed_open := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(downed_open == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": false},
		{"type": "block", "enemy_position": 2, "applied": true}]},
		"negative: the attack aimed at the downed hero is not applied or redirected")
	_check_hero(party, 1, 40, 0, "downed middle")
	_check_hero(party, 2, 0, 0, "downed middle")
	_check_hero(party, 3, 26, 0, "downed middle")
	_check_enemy(enemies, 1, "ragling", 12, 0, "downed middle")
	_check_enemy(enemies, 2, "ragling_guard", 12, 1, "downed middle")

	# Later attacks aimed elsewhere still land while the downed-target beat is skipped.
	_check(scheduler.advance_turn(), "negative: advance to the rear-line attack")
	_check(phase.execute_phase(party, enemies, scheduler.get_intents())
		== {"ok": true, "events": [
			{"type": "block", "enemy_position": 1, "applied": true},
			{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true}]},
		"negative: the survivor's rear-line attack still lands")
	_check(scheduler.advance_turn(), "negative: advance to the converging beat")
	var downed_again := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(downed_again == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": false}]},
		"negative: only the beat aimed at the downed hero is inapplicable")
	_check_hero(party, 1, 39, 0, "downed middle later")
	_check_hero(party, 2, 0, 0, "downed middle later")
	_check_hero(party, 3, 25, 0, "downed middle later")

	# No unsupported action, extra key or non-integral amount is accepted by this schema.
	var unsupported := _expected().duplicate(true)
	unsupported[0]["pattern"][1] = {"type": "heal", "amount": 1}
	_check(unsupported != _expected(), "negative: unsupported-action probe changed the fixture")
	_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(unsupported)).is_empty(),
		"negative: the real parser rejects an unsupported action type")
	_check(not CombatEnemyIntents.new(unsupported).is_valid(),
		"negative: the intent validator rejects an unsupported action type")
	var extra_key := _expected().duplicate(true)
	extra_key[1]["pattern"][0]["status"] = "bleed"
	_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(extra_key)).is_empty()
		and not CombatEnemyIntents.new(extra_key).is_valid(),
		"negative: a Block with an extra key is rejected")
	var fractional := JSON.stringify(_expected()).replace("\"amount\":1", "\"amount\":1.5")
	_check(fractional != JSON.stringify(_expected()),
		"negative: fractional probe actually changed the fixture")
	_check(RunFightEncounterSelection._parse_schedule_text(fractional).is_empty(),
		"negative: a non-integral amount is rejected instead of truncated")
	_check(_parsed() == _expected(), "negative: the unmodified authored file still parses")


func _pool(reversed: bool = false) -> Dictionary:
	var pool := {}
	if reversed:
		pool["guard_counterattack"] = GUARD_PATH
		pool[ENCOUNTER_ID] = ENCOUNTER_PATH
	else:
		pool[ENCOUNTER_ID] = ENCOUNTER_PATH
		pool["guard_counterattack"] = GUARD_PATH
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
	var seed_value := 20261021
	var start := _map_with_fight(seed_value)
	var rng: RandomNumberGenerator = start["rng"]
	var map: RunMap = start["map"]
	var fight_id: String = start["fight_id"]
	var picker := RunFightEncounterSelection.new()
	var solo_pool := {ENCOUNTER_ID: ENCOUNTER_PATH}

	# AC4: every rejection is fail-closed and mutates nothing.
	_reject(RunMap.new(), rng, picker, solo_pool, "ungenerated map", rng)
	_reject(map, rng, picker, solo_pool, "legal but UNCHOSEN opening Fight", rng)
	if fight_id.is_empty():
		return
	_check(map.choose_node(fight_id) and map.get_current_node_id() == fight_id
		and map.get_node(fight_id).get("type") == "Fight",
		"the chosen CURRENT node is the real offered Fight")
	_reject(map, rng, picker, solo_pool, "null RNG")
	_reject(map, rng, picker, {}, "empty candidate pool", rng)
	_reject(map, rng, picker, {"absent": "res://data/encounters/no_such_crossloom_fight.json"},
		"missing candidate file", rng)
	_reject(map, rng, picker, {"bad": "res://data/enemies/starter_enemies.json"},
		"candidate outside the encounter directory", rng)
	_reject(map, rng, picker, {"bad": "res://data/encounters/../enemies/starter_enemies.json"},
		"noncanonical candidate path", rng)
	_reject(map, rng, picker, {ENCOUNTER_ID: ENCOUNTER_PATH,
		"broken": "res://data/encounters/unknown_crossloom_fight.json"},
		"malformed later candidate path rejects the whole pool", rng)
	_reject(map, rng, picker, {"bad": null}, "non-string candidate path", rng)
	_reject(map, rng, picker, {1: ENCOUNTER_PATH}, "non-string encounter ID", rng)
	_reject(map, rng, picker, {"": ENCOUNTER_PATH}, "empty encounter ID", rng)
	_check(picker._selected.is_empty() and picker._bound_map == null,
		"no failed attempt bound the selector or cached a choice")

	# A singleton candidate pool containing only the new encounter selects it directly.
	var oracle := _map_with_fight(seed_value)
	var oracle_rng: RandomNumberGenerator = oracle["rng"]
	var oracle_map: RunMap = oracle["map"]
	_check(oracle_map.get_floors() == map.get_floors() and oracle["fight_id"] == fight_id,
		"same-seed oracle reaches the identical graph and Fight")
	_check(oracle_map.choose_node(fight_id), "oracle chooses the same real Fight")
	var solo_ids: Array = solo_pool.keys()
	solo_ids.sort()
	var solo_id: String = solo_ids[oracle_rng.randi_range(0, solo_ids.size() - 1)]
	_check(solo_id == ENCOUNTER_ID, "one-ID oracle draw can only name the new encounter")
	var solo_state: int = oracle_rng.state

	var answer := picker.select_current_fight(map, rng, solo_pool)
	_check(answer.get("success", false) and answer.get("encounter_id") == ENCOUNTER_ID,
		"singleton pool selects the new encounter by its own ID")
	_check(answer.get("definitions", []) == _expected(),
		"singleton selection returns the new encounter's exact definitions")
	_check(rng.state == solo_state,
		"singleton selection leaves the run RNG unchanged: a one-entry range has no alternative")
	var selected_intents := CombatEnemyIntents.new(answer.get("definitions", []))
	_check(selected_intents.is_valid()
		and selected_intents.get_intents() == _announced_for_id(ENCOUNTER_ID, 0),
		"selected definitions instantiate the real position-ordered intent selector")

	# AC4: a two-ID pool including guard_counterattack replays identically in either
	# Dictionary insertion order, and each spends exactly one sorted-index draw.
	var two_pool := _pool()
	var replay := _map_with_fight(seed_value)
	var replay_rng: RandomNumberGenerator = replay["rng"]
	var replay_map: RunMap = replay["map"]
	_check(replay_map.choose_node(fight_id), "two-ID replay reaches the same real Fight")
	var two_ids: Array = two_pool.keys()
	two_ids.sort()
	_check(two_ids == [ENCOUNTER_ID, "guard_counterattack"],
		"two-entry pool is exactly the new encounter and guard_counterattack by their own IDs")

	# Independent seeded oracle: same map, same Fight, one sorted-index draw.
	var two_oracle := _map_with_fight(seed_value)
	var two_oracle_rng: RandomNumberGenerator = two_oracle["rng"]
	_check(two_oracle["map"].get_floors() == map.get_floors()
		and two_oracle["fight_id"] == fight_id,
		"two-entry oracle reaches the identical graph and Fight")
	_check(two_oracle["map"].choose_node(fight_id), "two-entry oracle chooses the same real Fight")
	var two_oracle_id: String = two_ids[two_oracle_rng.randi_range(0, two_ids.size() - 1)]
	var two_oracle_state: int = two_oracle_rng.state
	var two_answer := RunFightEncounterSelection.new().select_current_fight(
		replay_map, replay_rng, two_pool)
	_check(two_answer.get("success", false)
		and two_answer.get("encounter_id") == two_oracle_id,
		"two-entry selection is the exact single sorted-index RNG draw")
	_check(two_answer.get("definitions", []) == _expected_for(two_oracle_id),
		"two-entry selection returns the complete canonical schedule of the drawn ID")
	_check(replay_rng.state == two_oracle_state,
		"two-entry selection leaves exactly the oracle's one-draw RNG state")

	var reversed := _map_with_fight(seed_value)
	var reversed_rng: RandomNumberGenerator = reversed["rng"]
	var reversed_map: RunMap = reversed["map"]
	_check(reversed_map.choose_node(fight_id), "reversed-order replay reaches the same real Fight")
	var reversed_answer := RunFightEncounterSelection.new().select_current_fight(
		reversed_map, reversed_rng, _pool(true))
	_check(reversed_answer == two_answer and reversed_rng.state == replay_rng.state,
		"reversed insertion order replays the same ID, definitions and RNG state")

	# The cached choice is detached from every caller mutation and spends no extra RNG.
	var pristine := answer.duplicate(true)
	var cached := picker.select_current_fight(map, rng, {})
	_check(cached == pristine and rng.state == solo_state,
		"cached re-query returns the same choice and consumes no RNG even with no pool")
	answer["encounter_id"] = "mutated"
	answer["definitions"][0]["pattern"][0]["amount"] = 900
	answer["definitions"].clear()
	_check(answer != pristine, "the returned choice really was mutated by the caller")
	_check(picker.select_current_fight(map, rng, solo_pool) == pristine,
		"mutating a returned choice cannot alter the cached selection")
	_check(rng.state == solo_state, "mutating and re-reading the cache consumes zero RNG")
