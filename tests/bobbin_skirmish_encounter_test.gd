extends SceneTree
## Bobbin Skirmish: a fixed six-phase enemy cycle over the two starter enemies.
## The schedule is data only: res://data/encounters/bobbin_skirmish.json.
## This test never reaches into a catalog count or an ordered ID list; it finds
## the two sources by their enemy_position and by the authored hero/enemy IDs.

const ENCOUNTER_PATH := "res://data/encounters/bobbin_skirmish.json"
const STARTER_PATH := "res://data/encounters/starter_attacks.json"
const GUARD_PATH := "res://data/encounters/guard_counterattack.json"
const CROSS_STITCH_PATH := "res://data/encounters/cross_stitch_guard.json"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMIES_PATH := "res://data/enemies/starter_enemies.json"

var failures: Array[String] = []
var checks := 0

## The prescribed six-phase announcement cycle, slot-1 action first then slot-2.
var EXPECTED_PHASES: Array = [
	[{"type": "attack", "amount": 1, "target_position": 2, "enemy_position": 1},
	 {"type": "attack", "amount": 1, "target_position": 1, "enemy_position": 2}],
	[{"type": "block", "amount": 1, "enemy_position": 1},
	 {"type": "block", "amount": 1, "enemy_position": 2}],
	[{"type": "attack", "amount": 1, "target_position": 3, "enemy_position": 1},
	 {"type": "attack", "amount": 1, "target_position": 1, "enemy_position": 2}],
	[{"type": "attack", "amount": 1, "target_position": 2, "enemy_position": 1},
	 {"type": "block", "amount": 1, "enemy_position": 2}],
	[{"type": "block", "amount": 1, "enemy_position": 1},
	 {"type": "attack", "amount": 1, "target_position": 1, "enemy_position": 2}],
	[{"type": "attack", "amount": 1, "target_position": 3, "enemy_position": 1},
	 {"type": "block", "amount": 1, "enemy_position": 2}],
]

## The events every real phase must publish, in enemy-position order.
var EXPECTED_EVENTS: Array = [
	[{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
	 {"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true}],
	[{"type": "block", "enemy_position": 1, "applied": true},
	 {"type": "block", "enemy_position": 2, "applied": true}],
	[{"type": "attack", "enemy_position": 1, "target_position": 3, "applied": true},
	 {"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true}],
	[{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
	 {"type": "block", "enemy_position": 2, "applied": true}],
	[{"type": "block", "enemy_position": 1, "applied": true},
	 {"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true}],
	[{"type": "attack", "enemy_position": 1, "target_position": 3, "applied": true},
	 {"type": "block", "enemy_position": 2, "applied": true}],
]

## Ledger after each enemy phase:
## [warden_hp, warden_block, seamstress_hp, seamstress_block, tinker_hp, tinker_block,
##  ragling_block, guard_ragling_block]
var EXPECTED_LEDGER: Array = [
	[40, 5, 29, 0, 26, 0, 0, 0],
	[40, 0, 29, 0, 26, 0, 1, 1],
	[39, 0, 29, 0, 25, 0, 1, 1],
	[39, 0, 28, 0, 25, 0, 1, 2],
	[38, 0, 28, 0, 25, 0, 2, 2],
	[38, 0, 28, 0, 24, 0, 2, 3],
]


func _initialize() -> void:
	_test_bobbin_skirmish_json()
	_test_announcement_cycle()
	_test_real_phase_ledger()
	_test_negative_and_preservation()
	if failures.is_empty():
		print("bobbin_skirmish_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("bobbin_skirmish_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## JSON.parse_string may hand back whole numbers as floats; normalize them to int
## only when the value really is integral, so drifted data cannot be truncated
## into a valid-looking schedule.
func _normalize(value: Variant) -> Variant:
	if value is Dictionary:
		var normalized_dict: Dictionary = {}
		for key in value:
			normalized_dict[key] = _normalize(value[key])
		return normalized_dict
	if value is Array:
		var normalized_array: Array = []
		for item in value:
			normalized_array.append(_normalize(item))
		return normalized_array
	if value is float:
		if value == floor(value) and abs(value) < 1.0e15:
			return int(value)
		return value
	return value


func _load_json(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "opens " + path)
	if file == null:
		return []
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	_check(parsed is Array, path + " parses as a JSON array")
	if not parsed is Array:
		return []
	return _normalize(parsed)


## Exactly one record for the given enemy_position; duplicates fail the lookup.
func _find_source_by_position(records: Array, position: int) -> Dictionary:
	var matches: Array = []
	for record in records:
		if record is Dictionary and record.get("enemy_position") == position:
			matches.append(record)
	if matches.size() != 1:
		return {}
	return matches[0].duplicate(true)


func _find_record_by_id(records: Array, id: String) -> Dictionary:
	var matches: Array = []
	for record in records:
		if record is Dictionary and record.get("id") == id:
			matches.append(record)
	if matches.size() != 1:
		return {}
	return matches[0].duplicate(true)


func _build_party() -> CombatParty:
	var heroes := _load_json(PARTY_PATH)
	var warden := _find_record_by_id(heroes, "warden")
	var seamstress := _find_record_by_id(heroes, "seamstress")
	var tinker := _find_record_by_id(heroes, "tinker")
	_check(not warden.is_empty(), "authored hero warden found by id")
	_check(not seamstress.is_empty(), "authored hero seamstress found by id")
	_check(not tinker.is_empty(), "authored hero tinker found by id")
	return CombatParty.new([warden.duplicate(true), seamstress.duplicate(true), tinker.duplicate(true)])


func _build_enemies() -> CombatEnemies:
	var enemies := _load_json(ENEMIES_PATH)
	var ragling := _find_record_by_id(enemies, "ragling")
	var guard := _find_record_by_id(enemies, "ragling_guard")
	_check(not ragling.is_empty(), "authored enemy ragling found by id")
	_check(not guard.is_empty(), "authored enemy ragling_guard found by id")
	return CombatEnemies.new([ragling.duplicate(true), guard.duplicate(true)])


## AC1: the on-disk schedule carries the prescribed two sources, their exact
## action dictionaries and a valid CombatEnemyIntents instance.
func _test_bobbin_skirmish_json() -> void:
	var parsed := _load_json(ENCOUNTER_PATH)
	_check(parsed.size() == 2, "bobbin_skirmish.json holds exactly two source records")

	var source1 := _find_source_by_position(parsed, 1)
	var source2 := _find_source_by_position(parsed, 2)
	_check(not source1.is_empty(), "bobbin_skirmish source 1 found by enemy_position 1")
	_check(not source2.is_empty(), "bobbin_skirmish source 2 found by enemy_position 2")
	_check(_find_source_by_position(parsed + [source1], 1).is_empty(),
		"duplicate enemy_position 1 record fails the unique-position lookup")

	_check(source1.size() == 2 and source1.has("enemy_position") and source1.has("pattern"),
		"source 1 record holds only enemy_position and pattern")
	_check(source2.size() == 2 and source2.has("enemy_position") and source2.has("pattern"),
		"source 2 record holds only enemy_position and pattern")

	var pattern1: Array = source1.get("pattern", [])
	var pattern2: Array = source2.get("pattern", [])
	_check(pattern1.size() == 3, "source 1 repeats every three enemy phases")
	_check(pattern2.size() == 2, "source 2 repeats every two enemy phases")

	_check(pattern1[0] == {"type": "attack", "amount": 1, "target_position": 2},
		"source 1 beat 0: attack amount 1 on hero 2")
	_check(pattern1[1] == {"type": "block", "amount": 1},
		"source 1 beat 1: block amount 1")
	_check(pattern1[2] == {"type": "attack", "amount": 1, "target_position": 3},
		"source 1 beat 2: attack amount 1 on hero 3")
	_check(not pattern1[1].has("target_position"), "source 1 block carries no target_position")

	_check(pattern2[0] == {"type": "attack", "amount": 1, "target_position": 1},
		"source 2 beat 0: attack amount 1 on hero 1")
	_check(pattern2[1] == {"type": "block", "amount": 1},
		"source 2 beat 1: block amount 1")
	_check(not pattern2[1].has("target_position"), "source 2 block carries no target_position")

	var scheduler := CombatEnemyIntents.new(parsed)
	_check(scheduler.is_valid(), "bobbin_skirmish schedule is a valid CombatEnemyIntents")
	_check(scheduler.get_intents().size() == 2, "bobbin_skirmish announces one action per source")

	# The normalizer must not hide drifted data: a fractional amount stays a
	# float and the schedule is then rejected fail-closed.
	var drifted: Variant = _normalize({"amount": 1.5})
	_check(drifted is Dictionary, "the normalizer returns a dictionary for a dictionary input")
	_check(drifted.get("amount") == 1.5 and not (drifted.get("amount") is int),
		"normalizer keeps a fractional amount as a float instead of truncating it")
	var drifted_scheduler := CombatEnemyIntents.new(
		[{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 1.5, "target_position": 1}]}])
	_check(not drifted_scheduler.is_valid(), "a fractional amount is rejected fail-closed")
	_check(drifted_scheduler.get_intents().is_empty(), "a rejected schedule announces nothing")
	_check(not drifted_scheduler.advance_turn(), "a rejected schedule cannot advance")


## AC2: from a fresh scheduler the six announced phases resolve in enemy-position
## order, the seventh repeats the first, two independent schedulers agree and a
## returned copy cannot mutate the scheduler.
func _test_announcement_cycle() -> void:
	var scheduler_a := CombatEnemyIntents.new(_load_json(ENCOUNTER_PATH))
	var scheduler_b := CombatEnemyIntents.new(_load_json(ENCOUNTER_PATH))
	_check(scheduler_a.is_valid() and scheduler_b.is_valid(), "both fresh schedulers are valid")

	for phase_index in range(7):
		var expected_phase: Array = EXPECTED_PHASES[phase_index % EXPECTED_PHASES.size()]
		var announced_a := scheduler_a.get_intents()
		var announced_b := scheduler_b.get_intents()
		_check(announced_a.size() == 2, "phase %d announces exactly two actions" % phase_index)
		_check(announced_a == expected_phase, "phase %d announces the prescribed actions in order" % phase_index)
		_check(announced_b == expected_phase,
			"phase %d: the second independent scheduler announces the same actions" % phase_index)
		for slot in range(announced_a.size()):
			var action: Dictionary = announced_a[slot]
			_check(action.get("enemy_position") == slot + 1,
				"phase %d slot %d announces enemy_position %d first" % [phase_index, slot, slot + 1])
			if action.get("type") == "block":
				_check(not action.has("target_position"),
					"phase %d slot %d block carries no target" % [phase_index, slot])
				_check(action.size() == 3,
					"phase %d slot %d block holds only type, amount and enemy_position" % [phase_index, slot])
			else:
				_check(action.size() == 4,
					"phase %d slot %d attack holds type, amount, target and enemy_position" % [phase_index, slot])
				_check(action.get("amount") == 1, "phase %d slot %d attack amount is 1" % [phase_index, slot])
				_check(action.get("target_position") in [1, 2, 3],
					"phase %d slot %d attack targets a valid hero position" % [phase_index, slot])
		if phase_index < EXPECTED_PHASES.size():
			_check(scheduler_a.advance_turn(), "phase %d: scheduler advances" % phase_index)
			_check(scheduler_b.advance_turn(), "phase %d: second scheduler advances" % phase_index)

	_check(scheduler_a.get_intents() == EXPECTED_PHASES[0],
		"the seventh phase repeats the first phase exactly")

	# A returned copy is a copy: mutating it cannot change the scheduler.
	var snapshot := scheduler_a.get_intents()
	snapshot[0]["amount"] = 999
	snapshot[0]["type"] = "block"
	snapshot[0]["target_position"] = 3
	snapshot[0]["enemy_position"] = 3
	snapshot.append({"type": "attack", "amount": 7, "target_position": 1, "enemy_position": 3})
	_check(scheduler_a.get_intents() == EXPECTED_PHASES[0],
		"mutating a returned announcement does not change the scheduler")

	# The constructor copies its input: mutating the source array cannot change it.
	var source := _load_json(ENCOUNTER_PATH)
	var owned := CombatEnemyIntents.new(source)
	var owned_before := owned.get_intents()
	source[0]["pattern"][0]["amount"] = 42
	source[0]["pattern"][0]["target_position"] = 3
	_check(owned.get_intents() == owned_before,
		"mutating the definitions passed to the constructor does not change the scheduler")

	# The announcements consume no randomness from the global stream.
	seed(0x5EEDBEEF)
	var baseline := randi()
	seed(0x5EEDBEEF)
	var probe := scheduler_b.get_intents()
	_check(randi() == baseline, "announcing an enemy phase consumes no global RNG")
	_check(probe.size() == 2, "the RNG probe still announced both actions")


## AC3: six real CombatEnemyPhase executions with the prescribed party and enemy
## ledger, player-turn Block resets and enemy Block accumulation.
func _test_real_phase_ledger() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	_check(party.is_valid(), "authored party is valid")
	_check(enemies.is_valid(), "authored enemies are valid")
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("hp") == 40,
		"slot 1 is the Warden with 40 HP")
	_check(party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 30,
		"slot 2 is the Seamstress with 30 HP")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 26,
		"slot 3 is the Tinker with 26 HP")
	_check(enemies.get_enemy(1).get("id") == "ragling" and enemies.get_enemy(1).get("hp") == 12,
		"enemy slot 1 is the Ragling with 12 HP")
	_check(enemies.get_enemy(2).get("id") == "ragling_guard" and enemies.get_enemy(2).get("hp") == 12,
		"enemy slot 2 is the Guard Ragling with 12 HP")

	var scheduler := CombatEnemyIntents.new(_load_json(ENCOUNTER_PATH))
	var phase := CombatEnemyPhase.new()
	_check(CombatStartingBlock.new(party).apply(), "the Warden starts combat with 6 Block")
	_check(party.get_hero(1).get("block") == 6, "the Warden holds 6 Block before the first enemy phase")

	for phase_index in range(6):
		if phase_index > 0:
			_check(party.start_player_turn(), "phase %d: the player turn resets hero Block" % phase_index)
		var announced := scheduler.get_intents()
		var result := phase.execute_phase(party, enemies, announced)
		_check(result.get("ok") == true, "phase %d executes" % phase_index)
		_check(result.get("events") == EXPECTED_EVENTS[phase_index],
			"phase %d publishes the prescribed events in enemy-position order" % phase_index)
		# The phase executor never advances the scheduler itself.
		_check(scheduler.get_intents() == EXPECTED_PHASES[phase_index],
			"phase %d: the phase executor does not advance the scheduler" % phase_index)

		var expected: Array = EXPECTED_LEDGER[phase_index]
		_check(party.get_hero(1).get("hp") == expected[0] and party.get_hero(1).get("block") == expected[1],
			"phase %d: Warden is at %d HP / %d Block" % [phase_index, expected[0], expected[1]])
		_check(party.get_hero(2).get("hp") == expected[2] and party.get_hero(2).get("block") == expected[3],
			"phase %d: Seamstress is at %d HP / %d Block" % [phase_index, expected[2], expected[3]])
		_check(party.get_hero(3).get("hp") == expected[4] and party.get_hero(3).get("block") == expected[5],
			"phase %d: Tinker is at %d HP / %d Block" % [phase_index, expected[4], expected[5]])
		_check(enemies.get_enemy(1).get("hp") == 12 and enemies.get_enemy(2).get("hp") == 12,
			"phase %d: both enemies are still at 12 HP (no player attacks here)" % phase_index)
		_check(enemies.get_enemy(1).get("block") == expected[6],
			"phase %d: Ragling holds %d Block" % [phase_index, expected[6]])
		_check(enemies.get_enemy(2).get("block") == expected[7],
			"phase %d: Guard Ragling holds %d Block" % [phase_index, expected[7]])

		_check(scheduler.advance_turn(), "phase %d: the scheduler advances once" % phase_index)

	# The cycle closes: the seventh announcement is the first one again.
	_check(scheduler.get_intents() == EXPECTED_PHASES[0], "after six phases the cycle repeats the first phase")

	# A real phase execution consumes no randomness either.
	var rng_party := _build_party()
	var rng_enemies := _build_enemies()
	var rng_scheduler := CombatEnemyIntents.new(_load_json(ENCOUNTER_PATH))
	var rng_phase := CombatEnemyPhase.new()
	seed(0x5EEDBEEF)
	var rng_baseline := randi()
	seed(0x5EEDBEEF)
	var rng_result := rng_phase.execute_phase(rng_party, rng_enemies, rng_scheduler.get_intents())
	_check(rng_result.get("ok") == true, "the RNG probe phase executes")
	_check(randi() == rng_baseline, "executing an enemy phase consumes no global RNG")


## AC4: a slain source never acts, a downed hero is neither damaged nor
## retargeted, the other living source still acts, and the named earlier
## schedules still parse and validate.
func _test_negative_and_preservation() -> void:
	# A slain Ragling cannot act; Guard Ragling's valid attack still applies.
	var party := _build_party()
	var enemies := _build_enemies()
	var scheduler := CombatEnemyIntents.new(_load_json(ENCOUNTER_PATH))
	var phase := CombatEnemyPhase.new()
	_check(enemies.apply_damage(1, 12), "the Ragling is slain before the attack beat")
	_check(enemies.is_slain(1), "the Ragling is downed")

	var result := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(result.get("ok") == true, "the phase still succeeds with a slain source")
	_check(result.get("events") == [
		{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": false},
		{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true}],
		"the slain source does not act while the living source still attacks")
	_check(party.get_hero(1).get("hp") == 39 and party.get_hero(1).get("block") == 0,
		"the Guard Ragling's attack still lands on the Warden")
	_check(party.get_hero(2).get("hp") == 30, "the Seamstress is untouched by the slain source")
	_check(party.get_hero(3).get("hp") == 26, "the Tinker is untouched by the slain source")
	_check(enemies.get_enemy(1).get("hp") == 0 and enemies.get_enemy(1).get("block") == 0,
		"the slain Ragling gains no Block")
	_check(enemies.get_enemy(2).get("hp") == 12 and enemies.get_enemy(2).get("block") == 0,
		"the Guard Ragling is unchanged after an attack beat")

	# A downed targeted hero is neither damaged nor silently retargeted.
	party = _build_party()
	enemies = _build_enemies()
	scheduler = CombatEnemyIntents.new(_load_json(ENCOUNTER_PATH))
	_check(party.apply_damage(2, 30), "the Seamstress is downed before phase 0")
	_check(party.is_downed(2), "the Seamstress stays put at 0 HP")

	result = phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(result.get("ok") == true, "the phase still succeeds with a downed target")
	_check(result.get("events") == [
		{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": false},
		{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true}],
		"the announced attack on the downed hero is unapplied and not redirected")
	_check(party.get_hero(2).get("hp") == 0, "the downed Seamstress takes no further damage")
	_check(party.get_hero(1).get("hp") == 39 and party.get_hero(1).get("block") == 0,
		"the Guard Ragling still attacks the Warden")
	_check(party.get_hero(3).get("hp") == 26, "the Tinker is not retargeted")
	_check(enemies.get_enemy(1).get("hp") == 12 and enemies.get_enemy(1).get("block") == 0,
		"the Ragling is unchanged after the downed-target phase")
	_check(enemies.get_enemy(2).get("hp") == 12 and enemies.get_enemy(2).get("block") == 0,
		"the Guard Ragling is unchanged after the downed-target phase")

	# The three named earlier schedules still parse and validate unchanged.
	var starter := _load_json(STARTER_PATH)
	var starter_source1 := _find_source_by_position(starter, 1)
	var starter_source2 := _find_source_by_position(starter, 2)
	_check(not starter_source1.is_empty() and not starter_source2.is_empty(),
		"starter_attacks.json still holds its two sources")
	_check(starter_source1.get("pattern") == [
		{"type": "attack", "amount": 1, "target_position": 1},
		{"type": "attack", "amount": 1, "target_position": 2},
		{"type": "attack", "amount": 1, "target_position": 3}],
		"starter_attacks.json source 1 keeps its three ordered attacks")
	_check(starter_source2.get("pattern") == [{"type": "block", "amount": 1}],
		"starter_attacks.json source 2 keeps its block")
	_check(CombatEnemyIntents.new(starter).is_valid(), "starter_attacks.json still validates")

	var guard := _load_json(GUARD_PATH)
	var guard_source1 := _find_source_by_position(guard, 1)
	var guard_source2 := _find_source_by_position(guard, 2)
	_check(not guard_source1.is_empty() and not guard_source2.is_empty(),
		"guard_counterattack.json still holds its two sources")
	_check(guard_source1.get("pattern") == [
		{"type": "block", "amount": 1},
		{"type": "attack", "amount": 1, "target_position": 1}],
		"guard_counterattack.json source 1 keeps its ordered block and attack")
	_check(guard_source2.get("pattern") == [
		{"type": "attack", "amount": 1, "target_position": 3},
		{"type": "block", "amount": 1}],
		"guard_counterattack.json source 2 keeps its ordered attack and block")
	_check(CombatEnemyIntents.new(guard).is_valid(), "guard_counterattack.json still validates")

	var cross := _load_json(CROSS_STITCH_PATH)
	var cross_source1 := _find_source_by_position(cross, 1)
	var cross_source2 := _find_source_by_position(cross, 2)
	_check(not cross_source1.is_empty() and not cross_source2.is_empty(),
		"cross_stitch_guard.json still holds its two sources")
	_check(cross_source1.get("pattern") == [
		{"type": "attack", "amount": 1, "target_position": 3},
		{"type": "block", "amount": 1}],
		"cross_stitch_guard.json source 1 keeps its ordered attack and block")
	_check(cross_source2.get("pattern") == [
		{"type": "block", "amount": 1},
		{"type": "attack", "amount": 1, "target_position": 1}],
		"cross_stitch_guard.json source 2 keeps its ordered block and attack")
	_check(CombatEnemyIntents.new(cross).is_valid(), "cross_stitch_guard.json still validates")
