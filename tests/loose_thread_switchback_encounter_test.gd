extends SceneTree
## M03 "Loose Thread Switchback": the authored two-Ragling Fight schedule.
##
## Data and service layer only. The test reads the shipped JSON with
## FileAccess and JSON, converts only mathematically integral JSON numbers to
## int and then drives the real CombatEnemyIntents, CombatParty, CombatEnemies
## and CombatEnemyPhase services. No live scene, run map, encounter catalog or
## Fight pool is involved: the live wiring is a separate task.
##
## Every oracle below is hard-coded here on purpose. Nothing is computed by
## the service under test, and no assertion depends on how many encounter
## files exist or on their order.

const SWITCHBACK := "res://data/encounters/loose_thread_switchback.json"
const STARTER := "res://data/encounters/starter_attacks.json"
const GUARD := "res://data/encounters/guard_counterattack.json"
const PARTY := "res://data/heroes/starter_party.json"
const ENEMIES := "res://data/enemies/starter_enemies.json"
const RNG_SEED := 0x5EED1CE

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_authored_schedule()
	_test_prior_schedules_unchanged()
	_test_twelve_beat_cycle()
	_test_phase_effects()
	_test_slain_source()
	_test_fail_closed()
	if failures.is_empty():
		print("loose_thread_switchback_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("loose_thread_switchback_encounter_test: FAIL (", failures.size(), " failures)")
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
	var text := file.get_as_text()
	file.close()
	return text


## Converts only mathematically integral JSON numbers to int. Anything else
## (non numeric, NaN, infinite, fractional or beyond exact double integers)
## fails closed, so truncation can never hide authored drift.
func _coerce_integral(record: Dictionary, field: String) -> bool:
	if not record.has(field):
		return false
	var value = record[field]
	if value is int:
		return true
	if not value is float or is_nan(value) or is_inf(value):
		return false
	if absf(value) > 9007199254740991.0 or floorf(value) != value:
		return false
	record[field] = int(value)
	return true


## Reads an encounter schedule: a JSON array of source records that each hold
## only enemy_position and pattern.
func _load_schedule(path: String) -> Array:
	var parser := JSON.new()
	if parser.parse(_load_text(path)) != OK:
		_check(false, "parses " + path + " without error")
		return []
	var parsed = parser.data
	if not parsed is Array:
		_check(false, path + " is a JSON array")
		return []
	var definitions: Array = parsed.duplicate(true)
	for definition in definitions:
		if not definition is Dictionary or definition.size() != 2 \
				or not definition.has("enemy_position") or not definition.has("pattern"):
			_check(false, path + " records hold only enemy_position and pattern")
			return []
		if not _coerce_integral(definition, "enemy_position"):
			_check(false, path + " has an integral enemy_position")
			return []
		var pattern = definition["pattern"]
		if not pattern is Array or pattern.is_empty():
			_check(false, path + " has a nonempty pattern array")
			return []
		for action in pattern:
			if not action is Dictionary or not action.has("type") \
					or not _coerce_integral(action, "amount"):
				_check(false, path + " actions carry a type and an integral amount")
				return []
			if action.has("target_position") \
					and not _coerce_integral(action, "target_position"):
				_check(false, path + " actions carry an integral target_position")
				return []
	return definitions


## Reads the actor roster (heroes or enemies) with integral max_hp.
func _load_actors(path: String) -> Array:
	var parser := JSON.new()
	if parser.parse(_load_text(path)) != OK:
		_check(false, "parses " + path + " without error")
		return []
	var parsed = parser.data
	if not parsed is Array:
		_check(false, path + " is a JSON array")
		return []
	var definitions: Array = parsed.duplicate(true)
	for definition in definitions:
		if not definition is Dictionary or not definition.has("id") \
				or not _coerce_integral(definition, "max_hp"):
			_check(false, path + " records carry an id and an integral max_hp")
			return []
	return definitions


## The single record at an enemy position; an empty dictionary when the
## position is missing or duplicated.
func _source_at(definitions: Array, position: int) -> Dictionary:
	var matches: Array = []
	for definition in definitions:
		if definition is Dictionary and definition.get("enemy_position") == position:
			matches.append(definition)
	if matches.size() != 1:
		return {}
	return matches[0].duplicate(true)


## The single actor record with an id; an empty dictionary when missing.
func _actor_by_id(definitions: Array, id: String) -> Dictionary:
	var matches: Array = []
	for definition in definitions:
		if definition is Dictionary and definition.get("id") == id:
			matches.append(definition)
	if matches.size() != 1:
		return {}
	return matches[0].duplicate(true)


## The authored switchback schedule, written out by hand.
func _expected_switchback() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 3},
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "attack", "amount": 1, "target_position": 1}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 3}]}]


## The twelve authored beats of the combined schedule, written out by hand:
## source 1 acts on a four step cycle, source 2 on a three step one, so the
## pair sequence repeats every lcm(4, 3) = 12 enemy turns.
func _expected_beats() -> Array:
	return [
		[{"type": "block", "amount": 1}, {"type": "attack", "amount": 1, "target_position": 2}],
		[{"type": "attack", "amount": 1, "target_position": 3}, {"type": "block", "amount": 1}],
		[{"type": "attack", "amount": 1, "target_position": 2}, {"type": "attack", "amount": 1, "target_position": 3}],
		[{"type": "attack", "amount": 1, "target_position": 1}, {"type": "attack", "amount": 1, "target_position": 2}],
		[{"type": "block", "amount": 1}, {"type": "block", "amount": 1}],
		[{"type": "attack", "amount": 1, "target_position": 3}, {"type": "attack", "amount": 1, "target_position": 3}],
		[{"type": "attack", "amount": 1, "target_position": 2}, {"type": "attack", "amount": 1, "target_position": 2}],
		[{"type": "attack", "amount": 1, "target_position": 1}, {"type": "block", "amount": 1}],
		[{"type": "block", "amount": 1}, {"type": "attack", "amount": 1, "target_position": 3}],
		[{"type": "attack", "amount": 1, "target_position": 3}, {"type": "attack", "amount": 1, "target_position": 2}],
		[{"type": "attack", "amount": 1, "target_position": 2}, {"type": "block", "amount": 1}],
		[{"type": "attack", "amount": 1, "target_position": 1}, {"type": "attack", "amount": 1, "target_position": 3}]]


## The announced form of one beat: the two actions in source slot order, each
## carrying its enemy position.
func _announced(beat: int) -> Array:
	var result: Array = []
	var pair: Array = _expected_beats()[beat]
	for index in range(2):
		var action: Dictionary = pair[index].duplicate(true)
		action["enemy_position"] = index + 1
		result.append(action)
	return result


## A real party, roster and scheduler built from the shipped data files.
func _fixture() -> Dictionary:
	var heroes := _load_actors(PARTY)
	var foes := _load_actors(ENEMIES)
	var schedule := _load_schedule(SWITCHBACK)
	_check(heroes.size() == 3, "the shipped party holds three heroes")
	_check(foes.size() == 2, "the shipped roster holds two enemies")
	if heroes.size() != 3 or foes.size() != 2:
		return {}
	var warden := _actor_by_id(heroes, "warden")
	var seamstress := _actor_by_id(heroes, "seamstress")
	var tinker := _actor_by_id(heroes, "tinker")
	_check(warden.get("name") == "Warden" and warden.get("max_hp") == 40,
		"Warden starts with 40 HP")
	_check(seamstress.get("name") == "Seamstress" and seamstress.get("max_hp") == 30,
		"Seamstress starts with 30 HP")
	_check(tinker.get("name") == "Tinker" and tinker.get("max_hp") == 26,
		"Tinker starts with 26 HP")
	var ragling := _actor_by_id(foes, "ragling")
	var guard := _actor_by_id(foes, "ragling_guard")
	_check(ragling.get("name") == "Ragling" and ragling.get("max_hp") == 12,
		"Ragling starts with 12 HP")
	_check(guard.get("name") == "Guard Ragling" and guard.get("max_hp") == 12,
		"Guard Ragling starts with 12 HP")
	var party := CombatParty.new(heroes)
	var enemies := CombatEnemies.new(foes)
	var intents := CombatEnemyIntents.new(schedule.duplicate(true))
	_check(party.is_valid() and enemies.is_valid() and intents.is_valid(),
		"the real party, roster and switchback scheduler initialize")
	if not party.is_valid() or not enemies.is_valid() or not intents.is_valid():
		return {}
	return {"party": party, "enemies": enemies, "intents": intents}


func _test_authored_schedule() -> void:
	var definitions := _load_schedule(SWITCHBACK)
	_check(definitions.size() == 2, "the switchback file holds exactly two source records")
	var expected := _expected_switchback()
	var source1 := _source_at(definitions, 1)
	var source2 := _source_at(definitions, 2)
	_check(not source1.is_empty(), "exactly one switchback source sits at enemy position 1")
	_check(not source2.is_empty(), "exactly one switchback source sits at enemy position 2")
	_check(source1.get("pattern") == expected[0]["pattern"],
		"source 1 is Block 1, attack 1 at hero 3, attack 1 at hero 2, attack 1 at hero 1")
	_check(source2.get("pattern") == expected[1]["pattern"],
		"source 2 is attack 1 at hero 2, Block 1, attack 1 at hero 3")
	for definition in definitions:
		_check(definition.size() == 2 and definition.has("enemy_position")
				and definition.has("pattern"),
			"a switchback record holds only enemy_position and pattern")
		for action in definition["pattern"]:
			if action.get("type") == "attack":
				_check(action.size() == 3 and action.has("amount")
						and action.has("target_position"),
					"an attack action holds only type, amount and target_position")
			else:
				_check(action.size() == 2 and action.has("amount")
						and not action.has("target_position"),
					"a block action holds only type and amount")
			_check(action.get("amount") is int and action.get("amount") == 1,
				"every switchback amount is the integer 1")
	_check(source1.get("enemy_position") == 1 and source2.get("enemy_position") == 2,
		"the switchback positions are the integers 1 and 2")
	# The real scheduler is the authority on the shape of the schedule.
	var scheduler := CombatEnemyIntents.new(definitions.duplicate(true))
	_check(scheduler.is_valid(), "the real CombatEnemyIntents accepts the authored schedule")
	_check(scheduler.get_intents().size() == 2,
		"the accepted switchback schedule announces one action per source")
	_check(scheduler.get_intents() == _announced(0),
		"the accepted schedule opens on the authored first beat")


func _test_prior_schedules_unchanged() -> void:
	var starter := _load_schedule(STARTER)
	var guard := _load_schedule(GUARD)
	_check(starter.size() == 2, "starter_attacks still holds two source records")
	_check(guard.size() == 2, "guard_counterattack still holds two source records")
	var starter1 := _source_at(starter, 1)
	var starter2 := _source_at(starter, 2)
	_check(not starter1.is_empty() and not starter2.is_empty(),
		"starter_attacks keeps one source at position 1 and one at position 2")
	_check(starter1.get("pattern") == [
		{"type": "attack", "amount": 1, "target_position": 1},
		{"type": "attack", "amount": 1, "target_position": 2},
		{"type": "attack", "amount": 1, "target_position": 3}],
		"starter_attacks source 1 is unchanged: attack 1 at hero 1, 2 then 3")
	_check(starter2.get("pattern") == [{"type": "block", "amount": 1}],
		"starter_attacks source 2 is unchanged: Block 1")
	var guard1 := _source_at(guard, 1)
	var guard2 := _source_at(guard, 2)
	_check(not guard1.is_empty() and not guard2.is_empty(),
		"guard_counterattack keeps one source at position 1 and one at position 2")
	_check(guard1.get("pattern") == [
		{"type": "block", "amount": 1},
		{"type": "attack", "amount": 1, "target_position": 1}],
		"guard_counterattack source 1 is unchanged: Block 1 then attack 1 at hero 1")
	_check(guard2.get("pattern") == [
		{"type": "attack", "amount": 1, "target_position": 3},
		{"type": "block", "amount": 1}],
		"guard_counterattack source 2 is unchanged: attack 1 at hero 3 then Block 1")
	_check(CombatEnemyIntents.new(starter.duplicate(true)).is_valid()
			and CombatEnemyIntents.new(guard.duplicate(true)).is_valid(),
		"both prior schedules still parse into valid schedulers")
	# The new file is its own addition: it does not rewrite the old ones.
	_check(_load_schedule(STARTER) == starter and _load_schedule(GUARD) == guard,
		"the prior schedules are untouched by the new encounter")


func _test_twelve_beat_cycle() -> void:
	var definitions := _load_schedule(SWITCHBACK)
	_check(definitions.size() == 2, "the switchback file loads for the twelve beat cycle")
	var pristine := definitions.duplicate(true)
	var first := CombatEnemyIntents.new(definitions)
	var second := CombatEnemyIntents.new(definitions.duplicate(true))
	_check(first.is_valid() and second.is_valid(),
		"two distinct schedulers accept the authored schedule")
	for beat in range(12):
		var expected := _announced(beat)
		var announced := first.get_intents()
		_check(announced == expected, "beat %d announces the authored ordered pair" % beat)
		_check(announced.size() == 2, "beat %d announces one action per source" % beat)
		_check(announced[0].get("enemy_position") == 1
				and announced[1].get("enemy_position") == 2,
			"beat %d announces source 1 before source 2" % beat)
		_check(first.get_intents() == expected,
			"beat %d does not progress on a second read" % beat)
		var snapshot := announced.duplicate(true)
		announced[0]["amount"] = 99
		announced[0]["enemy_position"] = 7
		announced.append({"type": "attack", "amount": 1, "target_position": 1})
		_check(first.get_intents() == snapshot,
			"beat %d returns an isolated deep copy" % beat)
		_check(second.get_intents() == expected,
			"the second scheduler announces the same beat %d" % beat)
		_check(first.advance_turn(), "the first scheduler advances after beat %d" % beat)
		_check(second.advance_turn(), "the second scheduler advances after beat %d" % beat)
	_check(first.get_intents() == _announced(0),
		"beat 12 repeats beat 0 (lcm of the four and three step cycles)")
	_check(second.get_intents() == _announced(0),
		"the second scheduler repeats the cycle as well")
	_check(definitions == pristine, "the scheduler leaves the caller schedule unchanged")
	# The schedule service draws no randomness at all.
	seed(RNG_SEED)
	var baseline := randi()
	seed(RNG_SEED)
	randi()
	_check(randi() != baseline, "the RNG probe detects an injected draw")
	seed(RNG_SEED)
	var expected_draw := randi()
	seed(RNG_SEED)
	for beat in range(12):
		first.get_intents()
		first.advance_turn()
	_check(randi() == expected_draw, "the schedule service consumes no global RNG")
	var injected := RandomNumberGenerator.new()
	injected.seed = RNG_SEED
	var injected_state := injected.state
	for beat in range(12):
		first.get_intents()
		first.advance_turn()
	_check(injected.state == injected_state, "the schedule service touches no injected RNG")


func _test_phase_effects() -> void:
	var expected_hp := [
		[40, 29, 26],
		[40, 29, 25],
		[40, 28, 24],
		[39, 27, 24],
		[39, 27, 24],
		[39, 27, 22]]
	var expected_block := [[1, 0], [1, 1], [1, 1], [1, 1], [2, 2], [2, 2]]
	var expected_events := [
		[{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true}],
		[{"type": "attack", "enemy_position": 1, "target_position": 3, "applied": true},
		{"type": "block", "enemy_position": 2, "applied": true}],
		[{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true}],
		[{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true}],
		[{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "block", "enemy_position": 2, "applied": true}],
		[{"type": "attack", "enemy_position": 1, "target_position": 3, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true}]]
	var first_trace: Array = []
	for replay in range(2):
		var fixture := _fixture()
		if fixture.is_empty():
			return
		var party: CombatParty = fixture["party"]
		var enemies: CombatEnemies = fixture["enemies"]
		var intents: CombatEnemyIntents = fixture["intents"]
		var phase := CombatEnemyPhase.new()
		# This isolated fixture runs no start of combat passive, so Warden's
		# opening +6 Block is deliberately not applied.
		_check(party.get_hero(1)["hp"] == 40 and party.get_hero(2)["hp"] == 30
				and party.get_hero(3)["hp"] == 26
				and party.get_hero(1)["block"] == 0 and party.get_hero(2)["block"] == 0
				and party.get_hero(3)["block"] == 0,
			"replay %d starts with the shipped hero HP and no hero Block" % replay)
		_check(enemies.get_enemy(1)["hp"] == 12 and enemies.get_enemy(2)["hp"] == 12
				and enemies.get_enemy(1)["block"] == 0 and enemies.get_enemy(2)["block"] == 0,
			"replay %d starts with both Raglings at 12 HP and 0 Block" % replay)
		var trace: Array = []
		for beat in range(6):
			var announced := intents.get_intents()
			var result := phase.execute_phase(party, enemies, announced)
			_check(result == {"ok": true, "events": expected_events[beat]},
				"replay %d beat %d applies the exact source ordered events" % [replay, beat])
			_check(intents.get_intents() == announced,
				"replay %d beat %d does not advance the scheduler" % [replay, beat])
			var heroes := party.get_heroes()
			for slot in range(3):
				_check(heroes[slot]["hp"] == expected_hp[beat][slot],
					"replay %d beat %d leaves hero slot %d at %d HP"
						% [replay, beat, slot + 1, expected_hp[beat][slot]])
				_check(heroes[slot]["block"] == 0,
					"replay %d beat %d leaves hero slot %d without Block" % [replay, beat, slot + 1])
			var foes := enemies.get_enemies()
			for slot in range(2):
				_check(foes[slot]["hp"] == 12,
					"replay %d beat %d leaves enemy slot %d at 12 HP" % [replay, beat, slot + 1])
				_check(foes[slot]["block"] == expected_block[beat][slot],
					"replay %d beat %d leaves enemy slot %d at %d Block"
						% [replay, beat, slot + 1, expected_block[beat][slot]])
			trace.append({"result": result, "heroes": heroes, "enemies": foes})
			if beat < 5:
				_check(intents.advance_turn(), "replay %d advances after beat %d" % [replay, beat])
		_check(party.get_hero(1)["hp"] == 39 and party.get_hero(2)["hp"] == 27
				and party.get_hero(3)["hp"] == 22
				and enemies.get_enemy(1)["block"] == 2 and enemies.get_enemy(2)["block"] == 2,
			"replay %d ends the six beat fight at Warden 39, Seamstress 27, Tinker 22 and 2 Block on both enemies"
				% replay)
		if replay == 0:
			first_trace = trace.duplicate(true)
		else:
			_check(trace == first_trace, "a fresh fixture replays the identical six beat trace")


func _test_slain_source() -> void:
	var fixture := _fixture()
	if fixture.is_empty():
		return
	var party: CombatParty = fixture["party"]
	var enemies: CombatEnemies = fixture["enemies"]
	var intents: CombatEnemyIntents = fixture["intents"]
	var phase := CombatEnemyPhase.new()
	_check(enemies.apply_damage(1, 12) and enemies.is_slain(1) and not enemies.is_slain(2),
		"source 1 is slain before the first phase")
	var dead := enemies.get_enemy(1)
	var announced := intents.get_intents()
	var result := phase.execute_phase(party, enemies, announced)
	_check(result == {"ok": true, "events": [
		{"type": "block", "enemy_position": 1, "applied": false},
		{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true}]},
		"the slain source skips its Block while source 2 still attacks the Seamstress")
	_check(enemies.get_enemy(1) == dead and enemies.get_enemy(1)["block"] == 0,
		"the slain source gains no Block and keeps its slot")
	_check(enemies.get_enemy(2)["hp"] == 12 and enemies.get_enemy(2)["block"] == 0,
		"the living source is unchanged except for its damage")
	_check(party.get_hero(2)["hp"] == 29, "the Seamstress takes exactly one damage")
	_check(party.get_hero(1)["hp"] == 40 and party.get_hero(3)["hp"] == 26,
		"the living attack is not retargeted onto another hero")


func _test_fail_closed() -> void:
	var definitions := _load_schedule(SWITCHBACK)
	_check(definitions.size() == 2, "the switchback file loads for the fail closed cases")
	_check(CombatEnemyIntents.new(definitions.duplicate(true)).is_valid(),
		"the unmodified authored schedule is accepted")
	var duplicate_position := definitions.duplicate(true)
	duplicate_position[1]["enemy_position"] = 1
	var empty_pattern := definitions.duplicate(true)
	empty_pattern[0]["pattern"] = []
	var far_target := definitions.duplicate(true)
	far_target[0]["pattern"][1]["target_position"] = 4
	var blocked_with_target := definitions.duplicate(true)
	blocked_with_target[0]["pattern"][0]["target_position"] = 2
	var fractional_amount := definitions.duplicate(true)
	fractional_amount[1]["pattern"][0]["amount"] = 1.5
	var broken := {
		"a duplicated enemy position": duplicate_position,
		"a zero length pattern": empty_pattern,
		"an attack on target 4": far_target,
		"a block carrying a target": blocked_with_target,
		"a fractional amount": fractional_amount}
	for label in broken:
		var scheduler := CombatEnemyIntents.new(broken[label])
		_check(not scheduler.is_valid(), "the real scheduler rejects " + label)
		_check(scheduler.get_intents().is_empty(),
			"a rejected schedule announces nothing for " + label)
		_check(not scheduler.advance_turn(),
			"a rejected schedule cannot advance for " + label)
	var fixture := _fixture()
	if fixture.is_empty():
		return
	var party: CombatParty = fixture["party"]
	var enemies: CombatEnemies = fixture["enemies"]
	var intents: CombatEnemyIntents = fixture["intents"]
	var phase := CombatEnemyPhase.new()
	# The rejection checks below are only meaningful when a valid phase really
	# changes the world.
	var valid_phase := phase.execute_phase(party, enemies, intents.get_intents())
	_check(valid_phase["ok"] and party.get_hero(2)["hp"] == 29
			and enemies.get_enemy(1)["block"] == 1,
		"a valid phase really changes hero HP and enemy Block")
	var party_before := party.get_heroes()
	var enemies_before := enemies.get_enemies()
	var announced_before := intents.get_intents()
	var bad_phases := {
		"an attack on target 4": [{"type": "attack", "enemy_position": 1, "amount": 1,
			"target_position": 4}],
		"a duplicated source": [{"type": "block", "enemy_position": 1, "amount": 1},
			{"type": "block", "enemy_position": 1, "amount": 1}],
		"a block carrying a target": [{"type": "block", "enemy_position": 1, "amount": 1,
			"target_position": 1}],
		"a fractional amount": [{"type": "attack", "enemy_position": 1, "amount": 1.5,
			"target_position": 2}],
		"an unknown kind": [{"type": "heal", "enemy_position": 1, "amount": 1}],
		"a missing enemy position": [{"type": "attack", "amount": 1, "target_position": 2}]}
	for label in bad_phases:
		var result := phase.execute_phase(party, enemies, bad_phases[label])
		_check(result == {"ok": false, "events": []}, "the real phase rejects " + label)
		_check(party.get_heroes() == party_before and enemies.get_enemies() == enemies_before,
			"a rejected phase writes no partial state for " + label)
		_check(intents.get_intents() == announced_before,
			"a rejected phase leaves the announced schedule untouched for " + label)
