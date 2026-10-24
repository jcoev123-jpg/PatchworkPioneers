extends SceneTree
## M02 standalone authored content: the Buttonhole Holdout Fight schedule.
##
## Two existing starter sources (Ragling in slot 1, Guard Ragling in slot 2)
## each run their own four-beat cycle built only from the existing attack and
## Block mechanics: the front source builds two Block while the rear source
## presses the middle line twice, and both share a rear attack on the fourth
## beat.
##
## This lane owns the authored data and its regression only. Registering the
## encounter in the run map / Fight pool and the live battle is later work and
## is deliberately not claimed here.

const ENCOUNTER_PATH := "res://data/encounters/buttonhole_holdout.json"
const ENCOUNTER_ID := "buttonhole_holdout"
const STARTER_PATH := "res://data/encounters/starter_attacks.json"
const GUARD_PATH := "res://data/encounters/guard_counterattack.json"
const SPOOLWHEEL_PATH := "res://data/encounters/spoolwheel_feint.json"
const HEROES_PATH := "res://data/heroes/starter_party.json"
const ENEMIES_PATH := "res://data/enemies/starter_enemies.json"

## Independently authored expectations: cumulative party HP per beat.
const EXPECTED_HP := [[39, 29, 26], [39, 28, 26], [38, 28, 26], [38, 28, 24]]
## Independently authored expectations: cumulative enemy Block per beat
## (front source, rear source).
const EXPECTED_BLOCK := [[0, 0], [1, 0], [2, 0], [2, 0]]

var failures: Array[String] = []
var checks := 0
var _number_error := false
var _authored_text := ""


func _initialize() -> void:
	_authored_text = _read_text(ENCOUNTER_PATH)
	_test_authored_file()
	_test_announcements()
	_test_combat_execution()
	_test_slain_source_and_downed_target()
	_test_rejections()
	if failures.is_empty():
		print("buttonhole_holdout_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("buttonhole_holdout_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


## JSON numbers can arrive as floats. Every numeric field is proved integral
## BEFORE it is coerced to int; a fractional value is a hard failure so a
## truncation can never make invalid authored data pass.
func _normalize_numbers(value: Variant) -> Variant:
	if value is float:
		if is_nan(value) or is_inf(value) or absf(value) > 9007199254740991.0:
			_number_error = true
			return value
		if floorf(value) != value:
			_number_error = true
			return value
		return int(value)
	if value is Array:
		var items: Array = []
		for item in value:
			items.append(_normalize_numbers(item))
		return items
	if value is Dictionary:
		var record: Dictionary = {}
		for key in value:
			record[key] = _normalize_numbers(value[key])
		return record
	return value


## Loads an authored JSON array with the integral check applied. Returns an
## empty array when the file is missing, malformed or non-integral.
func _load_definitions(path: String) -> Array:
	_check(FileAccess.file_exists(path), "authored file exists: " + path)
	return _parse_definitions_text(_read_text(path), path)


## Parses schedule text with the integral check applied before any int
## coercion. With report disabled it is the negative-case probe: a rejected
## document returns an empty array instead of recording a failure.
func _parse_definitions_text(text: String, label: String, report: bool = true) -> Array:
	if text.is_empty():
		if report:
			_check(false, "authored file is readable: " + label)
		return []
	var parser := JSON.new()
	if parser.parse(text) != OK:
		if report:
			_check(false, "authored file is valid JSON: " + label)
		return []
	var raw = parser.data
	if not raw is Array:
		if report:
			_check(false, "authored file holds a JSON array: " + label)
		return []
	_number_error = false
	var normalized: Variant = _normalize_numbers(raw)
	if _number_error:
		if report:
			_check(false, "authored numeric fields are all integral: " + label)
		return []
	if not normalized is Array:
		if report:
			_check(false, "authored file normalizes to an array: " + label)
		return []
	return normalized


func _source_at(definitions: Array, position: int) -> Dictionary:
	var matches: Array = []
	for definition in definitions:
		if definition is Dictionary and definition.get("enemy_position") == position:
			matches.append(definition)
	_check(matches.size() == 1,
		"schedule has exactly one source at enemy_position %d" % position)
	return matches[0].duplicate(true) if matches.size() == 1 else {}


func _record_by_id(records: Array, id: String) -> Dictionary:
	var matches: Array = []
	for record in records:
		if record is Dictionary and record.get("id") == id:
			matches.append(record)
	_check(matches.size() == 1, "catalog has exactly one record named " + id)
	return matches[0].duplicate(true) if matches.size() == 1 else {}


func _positions_of(announced: Array) -> Array:
	var positions: Array = []
	for action in announced:
		positions.append(action.get("enemy_position"))
	return positions


## True when every numeric leaf of the parsed JSON is an int or an integral
## float. JSON parses whole numbers as floats in some Godot versions, so the
## raw authored text is proved integral BEFORE any int coercion.
func _all_numeric_leaves_integral(value: Variant) -> bool:
	if value is float:
		return not is_nan(value) and not is_inf(value) \
			and absf(value) <= 9007199254740991.0 and floorf(value) == value
	if value is Array:
		for item in value:
			if not _all_numeric_leaves_integral(item):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not _all_numeric_leaves_integral(value[key]):
				return false
		return true
	return true


## How many numeric leaves the parsed JSON really holds, so an integrality
## audit cannot pass on an empty or numeric-free document.
func _count_numeric_leaves(value: Variant) -> int:
	if value is float or value is int:
		return 1
	var total := 0
	if value is Array:
		for item in value:
			total += _count_numeric_leaves(item)
		return total
	if value is Dictionary:
		for key in value:
			total += _count_numeric_leaves(value[key])
	return total


## The authored schedule, written out by hand rather than copied from the
## file under test.
func _expected_schedule() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "block", "amount": 1},
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 3}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "attack", "amount": 1, "target_position": 3}]},
	]


func _attack(owner: int, target: int) -> Dictionary:
	return {"type": "attack", "amount": 1, "target_position": target,
		"enemy_position": owner}


func _block(owner: int) -> Dictionary:
	return {"type": "block", "amount": 1, "enemy_position": owner}


## The exact full announcement of every beat, written out by hand.
func _expected_beats() -> Array:
	return [
		[_attack(1, 1), _attack(2, 2)],
		[_block(1), _attack(2, 2)],
		[_block(1), _attack(2, 1)],
		[_attack(1, 3), _attack(2, 3)],
		[_attack(1, 1), _attack(2, 2)],
	]


func _expected_events(beat: int) -> Array:
	var events: Array = []
	for intent in _expected_beats()[beat]:
		var event := {"type": intent["type"], "enemy_position": intent["enemy_position"],
			"applied": true}
		if intent["type"] == "attack":
			event["target_position"] = intent["target_position"]
		events.append(event)
	return events


func _named_previous_encounters() -> Array:
	return [
		{"id": "starter_attacks", "path": STARTER_PATH, "schedule": [
			{"enemy_position": 1, "pattern": [
				{"type": "attack", "amount": 1, "target_position": 1},
				{"type": "attack", "amount": 1, "target_position": 2},
				{"type": "attack", "amount": 1, "target_position": 3}]},
			{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]}]},
		{"id": "guard_counterattack", "path": GUARD_PATH, "schedule": [
			{"enemy_position": 1, "pattern": [
				{"type": "block", "amount": 1},
				{"type": "attack", "amount": 1, "target_position": 1}]},
			{"enemy_position": 2, "pattern": [
				{"type": "attack", "amount": 1, "target_position": 3},
				{"type": "block", "amount": 1}]}]},
		{"id": "spoolwheel_feint", "path": SPOOLWHEEL_PATH, "schedule": [
			{"enemy_position": 1, "pattern": [
				{"type": "block", "amount": 1},
				{"type": "attack", "amount": 1, "target_position": 2}]},
			{"enemy_position": 2, "pattern": [
				{"type": "attack", "amount": 1, "target_position": 1},
				{"type": "attack", "amount": 1, "target_position": 3},
				{"type": "block", "amount": 1}]}]},
	]


## AC1: the authored file carries exactly the two required four-beat patterns,
## the starter roster it reuses is untouched, and the file validates through
## the real CombatEnemyIntents contract.
func _test_authored_file() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH),
		"AC1: the %s authored encounter exists" % ENCOUNTER_ID)
	_check(not _authored_text.is_empty(),
		"AC1: the buttonhole_holdout authored file is readable")
	var definitions := _load_definitions(ENCOUNTER_PATH)
	_check(definitions.size() == 2,
		"AC1: buttonhole_holdout holds exactly two source records")
	if definitions.size() != 2:
		return

	var expected := _expected_schedule()
	var slot1 := _source_at(definitions, 1)
	var slot2 := _source_at(definitions, 2)
	_check(slot1 == expected[0],
		"AC1: source slot 1 is the authored front four-beat pattern")
	_check(slot2 == expected[1],
		"AC1: source slot 2 is the authored rear four-beat pattern")

	# Every authored number is integral in the raw text and an int after the
	# test-side normalization (1 == 1.0 in GDScript, so the type is asserted).
	var raw_parsed = JSON.parse_string(_authored_text)
	_check(raw_parsed is Array,
		"AC1: the raw authored text parses into a JSON array")
	_check(raw_parsed is Array and _all_numeric_leaves_integral(raw_parsed),
		"AC1: every authored numeric field is integral before any int coercion")
	_check(raw_parsed is Array and _count_numeric_leaves(raw_parsed) == 16,
		"AC1: the authored document really holds its sixteen numeric fields")
	for source in [slot1, slot2]:
		_check(source.get("enemy_position") is int,
			"AC1: an authored enemy_position is an int after the integral normalization")

	for source in [slot1, slot2]:
		_check(source.size() == 2 and source.has("enemy_position")
			and source.has("pattern"),
			"AC1: a source record carries only enemy_position and pattern")
		var pattern: Array = source.get("pattern", [])
		_check(pattern.size() == 4, "AC1: a source runs a four-beat cycle")
		for action in pattern:
			_check(action is Dictionary, "AC1: an authored action is a record")
			if not action is Dictionary:
				continue
			var kind: Variant = action.get("type")
			_check(kind == "attack" or kind == "block",
				"AC1: an authored action is an attack or a Block")
			_check(action.get("amount") is int,
				"AC1: an authored amount is an int after the integral normalization")
			_check(action.get("amount") == 1,
				"AC1: an authored action amount is exactly 1")
			if kind == "block":
				_check(action.size() == 2 and not action.has("target_position"),
					"AC1: a Block action carries no hero target")
			else:
				_check(action.size() == 3 and action.has("target_position"),
					"AC1: an attack action carries exactly one hero target")
				_check(action.get("target_position") is int,
					"AC1: an authored attack target is an int after the integral normalization")
				_check(action.get("target_position") in [1, 2, 3],
					"AC1: an attack target is a real hero slot")

	# Every beat of every source, named explicitly.
	var pattern1: Array = slot1.get("pattern", [])
	var pattern2: Array = slot2.get("pattern", [])
	_check(pattern1.size() == 4
		and pattern1[0] == {"type": "attack", "amount": 1, "target_position": 1},
		"AC1: source 1 beat 0 attacks hero position 1 for 1")
	_check(pattern1.size() == 4
		and pattern1[1] == {"type": "block", "amount": 1},
		"AC1: source 1 beat 1 is an untargeted Block of 1")
	_check(pattern1.size() == 4
		and pattern1[2] == {"type": "block", "amount": 1},
		"AC1: source 1 beat 2 is an untargeted Block of 1")
	_check(pattern1.size() == 4
		and pattern1[3] == {"type": "attack", "amount": 1, "target_position": 3},
		"AC1: source 1 beat 3 attacks hero position 3 for 1")
	_check(pattern2.size() == 4
		and pattern2[0] == {"type": "attack", "amount": 1, "target_position": 2},
		"AC1: source 2 beat 0 attacks hero position 2 for 1")
	_check(pattern2.size() == 4
		and pattern2[1] == {"type": "attack", "amount": 1, "target_position": 2},
		"AC1: source 2 beat 1 attacks hero position 2 for 1")
	_check(pattern2.size() == 4
		and pattern2[2] == {"type": "attack", "amount": 1, "target_position": 1},
		"AC1: source 2 beat 2 attacks hero position 1 for 1")
	_check(pattern2.size() == 4
		and pattern2[3] == {"type": "attack", "amount": 1, "target_position": 3},
		"AC1: source 2 beat 3 attacks hero position 3 for 1")

	_check(CombatEnemyIntents.new(definitions).is_valid(),
		"AC1: the authored schedule passes the real intent validator")

	# The two sources are the unchanged starter enemies.
	var roster := _load_definitions(ENEMIES_PATH)
	_check(roster.size() >= 2,
		"AC1: the starter enemy roster still holds at least the two sources")
	var ragling := _record_by_id(roster, "ragling")
	var guard := _record_by_id(roster, "ragling_guard")
	_check(ragling.get("name") == "Ragling" and ragling.get("max_hp") == 12,
		"AC1: slot 1 is the unchanged Ragling with 12 maximum HP")
	_check(guard.get("name") == "Guard Ragling" and guard.get("max_hp") == 12,
		"AC1: slot 2 is the unchanged Guard Ragling with 12 maximum HP")
	_check(ragling.get("art_path") == "res://assets/paper/enemies/ragling.png"
		and guard.get("art_path") == "res://assets/paper/enemies/ragling_guard.png",
		"AC1: both sources keep their own authored art path")

	# The party the encounter is balanced against is unchanged too.
	var heroes := _load_definitions(HEROES_PATH)
	var warden := _record_by_id(heroes, "warden")
	var seamstress := _record_by_id(heroes, "seamstress")
	var tinker := _record_by_id(heroes, "tinker")
	_check(warden.get("name") == "Warden" and warden.get("max_hp") == 40,
		"AC1: the unchanged Warden starts with 40 maximum HP")
	_check(seamstress.get("name") == "Seamstress" and seamstress.get("max_hp") == 30,
		"AC1: the unchanged Seamstress starts with 30 maximum HP")
	_check(tinker.get("name") == "Tinker" and tinker.get("max_hp") == 26,
		"AC1: the unchanged Tinker starts with 26 maximum HP")


## AC2: the announced intent sequence is deterministic, sorted, wrapped and
## detached from its caller.
func _test_announcements() -> void:
	var definitions := _load_definitions(ENCOUNTER_PATH)
	_check(definitions.size() == 2,
		"AC2: the authored schedule loads for the scheduler")
	if definitions.size() != 2:
		return
	var pristine := definitions.duplicate(true)
	var expected := _expected_beats()
	var scheduler := CombatEnemyIntents.new(definitions)
	_check(scheduler.is_valid(),
		"AC2: the authored schedule passes the real intent validator")
	if not scheduler.is_valid():
		return

	var timeline: Array = []
	for beat in range(5):
		var announced := scheduler.get_intents()
		timeline.append(announced.duplicate(true))
		_check(announced == expected[beat],
			"AC2: beat %d announces the exact full authored actions" % beat)
		_check(announced.size() == 2,
			"AC2: beat %d announces one action per source" % beat)
		_check(_positions_of(announced) == [1, 2],
			"AC2: beat %d announces source slot 1 before source slot 2" % beat)
		for action in announced:
			if action.get("type") == "block":
				_check(not action.has("target_position"),
					"AC2: beat %d Block announcement carries no hero target" % beat)
			else:
				_check(action.get("target_position") in [1, 2, 3],
					"AC2: beat %d attack announcement names a real hero slot" % beat)
		# A caller that edits the returned snapshot cannot corrupt the schedule.
		announced[0]["amount"] = 900
		announced[0]["type"] = "invented"
		announced[1]["enemy_position"] = 3
		announced.append({"type": "block", "amount": 5, "enemy_position": 3})
		_check(scheduler.get_intents() == expected[beat],
			"AC2: beat %d caller mutation cannot corrupt the next announcement" % beat)
		_check(scheduler.advance_turn(),
			"AC2: beat %d advances the schedule exactly one step" % beat)

	_check(timeline.size() == 5 and timeline[4] == timeline[0],
		"AC2: beat 4 wraps exactly back to the beat 0 announcement")

	# A fresh scheduler replays the whole timeline, wrap included.
	var replay := CombatEnemyIntents.new(pristine.duplicate(true))
	_check(replay.is_valid(), "AC2: a fresh scheduler is valid")
	for beat in range(5):
		_check(replay.get_intents() == expected[beat],
			"AC2: a fresh scheduler replays beat %d exactly" % beat)
		if beat < 4:
			_check(replay.advance_turn(),
				"AC2: a fresh scheduler advances beat %d" % beat)

	# Two returned snapshots are independent of each other. The replay
	# scheduler stopped on turn four, so it announces the wrapped beat 0.
	var read_a := replay.get_intents()
	var read_b := replay.get_intents()
	_check(read_a == read_b and read_a == expected[0],
		"AC2: repeated reads announce the same actions")
	read_a[0]["amount"] = 77
	read_a[0]["enemy_position"] = 3
	_check(read_b == expected[0] and replay.get_intents() == expected[0],
		"AC2: mutating one returned announcement cannot corrupt the next read")

	# The scheduler owns a deep copy of the caller's definitions.
	var caller_owned := pristine.duplicate(true)
	var guarded := CombatEnemyIntents.new(caller_owned)
	caller_owned[0]["pattern"][0]["amount"] = 42
	caller_owned[1]["pattern"].clear()
	_check(guarded.is_valid() and guarded.get_intents() == expected[0],
		"AC2: mutating the caller-owned definitions cannot corrupt the scheduler")

	_check(definitions == pristine,
		"AC2: the parsed definitions are unchanged after the whole timeline")
	_check(_read_text(ENCOUNTER_PATH) == _authored_text,
		"AC2: the authored file text is unchanged after the whole timeline")


func _party() -> CombatParty:
	return CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}])


func _enemies() -> CombatEnemies:
	return CombatEnemies.new([
		{"id": "ragling", "max_hp": 12},
		{"id": "ragling_guard", "max_hp": 12}])


func _fixture_ok(party: CombatParty, enemies: CombatEnemies, label: String) -> bool:
	var valid := party.is_valid() and enemies.is_valid()
	_check(valid,
		label + ": the three-hero party and two-enemy roster are valid")
	if not valid:
		return false
	var hero_ids := ["warden", "seamstress", "tinker"]
	var hero_hp := [40, 30, 26]
	for i in range(3):
		var hero := party.get_hero(i + 1)
		_check(hero.get("id") == hero_ids[i] and hero.get("hp") == hero_hp[i]
			and hero.get("max_hp") == hero_hp[i] and hero.get("block") == 0
			and hero.get("position") == i + 1,
			label + ": %s starts in slot %d with %d HP and no Block"
			% [hero_ids[i], i + 1, hero_hp[i]])
	var enemy_ids := ["ragling", "ragling_guard"]
	for i in range(2):
		var enemy := enemies.get_enemy(i + 1)
		_check(enemy.get("id") == enemy_ids[i] and enemy.get("hp") == 12
			and enemy.get("max_hp") == 12 and enemy.get("block") == 0
			and enemy.get("position") == i + 1,
			label + ": %s starts in slot %d with 12 HP and no Block"
			% [enemy_ids[i], i + 1])
	return true


## Runs the four authored beats against a fresh fixture and returns the whole
## observable trace, so two runs can be compared in full.
func _run_beats(label: String) -> Array:
	var party := _party()
	var enemies := _enemies()
	if not _fixture_ok(party, enemies, label):
		return []
	var scheduler := CombatEnemyIntents.new(_load_definitions(ENCOUNTER_PATH))
	_check(scheduler.is_valid(), label + ": the authored schedule instantiates")
	if not scheduler.is_valid():
		return []
	var phase := CombatEnemyPhase.new()
	var expected := _expected_beats()
	var initial_heroes := party.get_heroes()
	var initial_roster := enemies.get_enemies()
	var trace: Array = []
	for beat in range(4):
		var intents := scheduler.get_intents()
		var untouched := intents.duplicate(true)
		_check(intents == expected[beat], label + ": beat %d exact intents" % beat)
		var result := phase.execute_phase(party, enemies, intents)
		_check(result == {"ok": true, "events": _expected_events(beat)},
			label + ": beat %d exact ordered applied/target events" % beat)
		_check(intents == untouched and scheduler.get_intents() == expected[beat],
			label + ": beat %d the phase neither mutates the intents nor advances"
			% beat)
		var expected_heroes := initial_heroes.duplicate(true)
		for i in range(3):
			expected_heroes[i]["hp"] = EXPECTED_HP[beat][i]
		var expected_roster := initial_roster.duplicate(true)
		for i in range(2):
			expected_roster[i]["block"] = EXPECTED_BLOCK[beat][i]
		_check(party.get_heroes() == expected_heroes,
			label + ": beat %d exact cumulative party HP and Block" % beat)
		_check(enemies.get_enemies() == expected_roster,
			label + ": beat %d exact cumulative enemy HP and Block" % beat)
		trace.append({"intents": intents, "result": result,
			"party": party.get_heroes(), "enemies": enemies.get_enemies()})
		_check(scheduler.advance_turn(),
			label + ": beat %d advances the scheduler once" % beat)
	return trace


## AC3: four real CombatEnemyPhase calls produce the authored cumulative HP
## and Block sequences, repeat identically and draw no global RNG.
func _test_combat_execution() -> void:
	var first := _run_beats("AC3 first")
	var replay := _run_beats("AC3 replay")
	_check(first.size() == 4 and replay.size() == 4 and first == replay,
		"AC3: four complete beats replay identically from fresh fixtures")
	if first.size() == 4:
		_check(first[0]["party"][0]["hp"] == 39 and first[0]["party"][1]["hp"] == 29
			and first[0]["party"][2]["hp"] == 26,
			"AC3: after beat 0 the party HP is 39/29/26")
		_check(first[1]["party"][0]["hp"] == 39 and first[1]["party"][1]["hp"] == 28
			and first[1]["party"][2]["hp"] == 26,
			"AC3: after beat 1 the party HP is 39/28/26")
		_check(first[2]["party"][0]["hp"] == 38 and first[2]["party"][1]["hp"] == 28
			and first[2]["party"][2]["hp"] == 26,
			"AC3: after beat 2 the party HP is 38/28/26")
		_check(first[3]["party"][0]["hp"] == 38 and first[3]["party"][1]["hp"] == 28
			and first[3]["party"][2]["hp"] == 24,
			"AC3: after beat 3 the party HP is 38/28/24")
		_check(first[0]["enemies"][0]["block"] == 0 and first[1]["enemies"][0]["block"] == 1
			and first[2]["enemies"][0]["block"] == 2 and first[3]["enemies"][0]["block"] == 2,
			"AC3: the front enemy Block is 0/1/2/2 across the four beats")
		_check(first[0]["enemies"][1]["block"] == 0 and first[1]["enemies"][1]["block"] == 0
			and first[2]["enemies"][1]["block"] == 0 and first[3]["enemies"][1]["block"] == 0,
			"AC3: the rear enemy never builds Block")

	# The global RNG stream must be untouched by the encounter.
	seed(31337)
	var control_a := randi()
	seed(31337)
	var control_b := randi()
	_check(control_a == control_b,
		"AC3 control: the same global seed reproduces the same global draw")
	seed(31337)
	var oracle := randi()
	seed(31337)
	_run_beats("AC3 global RNG")
	_check(randi() == oracle,
		"AC3: the authored encounter draws no global RNG")


## AC3: a slain source skips its authored action and a downed target absorbs
## no further attack, while the original slot order is preserved.
func _test_slain_source_and_downed_target() -> void:
	var party := _party()
	var enemies := _enemies()
	if not _fixture_ok(party, enemies, "AC3 slain source"):
		return
	var scheduler := CombatEnemyIntents.new(_load_definitions(ENCOUNTER_PATH))
	_check(scheduler.is_valid(),
		"AC3: the slain-source fixture has a valid scheduler")
	if not scheduler.is_valid():
		return
	_check(enemies.apply_damage(1, 12) and enemies.is_slain(1) and not enemies.is_slain(2),
		"AC3: the front source is really slain and the rear source is alive")
	var intents := scheduler.get_intents()
	var result := CombatEnemyPhase.new().execute_phase(party, enemies, intents)
	_check(result == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "applied": false, "target_position": 1},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 2}]},
		"AC3: the slain source records an unapplied event while the other source acts")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(2).get("hp") == 29
		and party.get_hero(3).get("hp") == 26,
		"AC3: only the hero the living source attacked loses HP")
	var roster := enemies.get_enemies()
	_check(roster.size() == 2 and roster[0].get("position") == 1
		and roster[1].get("position") == 2 and roster[0].get("id") == "ragling"
		and roster[1].get("id") == "ragling_guard" and roster[0].get("hp") == 0
		and roster[1].get("hp") == 12 and roster[0].get("block") == 0,
		"AC3: the slain source keeps its slot and gains no Block")
	_check(scheduler.get_intents() == _expected_beats()[0],
		"AC3: the slain source does not advance or mutate the scheduler")

	# The slain source's own Block action is skipped as well.
	_check(scheduler.advance_turn(),
		"AC3: the scheduler advances to the second beat")
	var block_intents := scheduler.get_intents()
	var block_result := CombatEnemyPhase.new().execute_phase(party, enemies, block_intents)
	_check(block_result == {"ok": true, "events": [
		{"type": "block", "enemy_position": 1, "applied": false},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 2}]},
		"AC3: a slain source's Block is skipped and recorded as unapplied")
	_check(enemies.get_enemy(1).get("block") == 0,
		"AC3: the slain source gains no Block from its skipped action")

	# A downed hero absorbs no further attack; the other source still acts.
	var downed_party := _party()
	var downed_enemies := _enemies()
	if not _fixture_ok(downed_party, downed_enemies, "AC3 downed target"):
		return
	var downed_scheduler := CombatEnemyIntents.new(_load_definitions(ENCOUNTER_PATH))
	_check(downed_scheduler.is_valid(),
		"AC3: the downed-target fixture has a valid scheduler")
	if not downed_scheduler.is_valid():
		return
	_check(downed_party.apply_damage(2, 30) and downed_party.is_downed(2),
		"AC3: the middle hero is really downed")
	var downed_intents := downed_scheduler.get_intents()
	var downed_result := CombatEnemyPhase.new().execute_phase(
		downed_party, downed_enemies, downed_intents)
	_check(downed_result == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "applied": true, "target_position": 1},
		{"type": "attack", "enemy_position": 2, "applied": false, "target_position": 2}]},
		"AC3: a downed target absorbs no attack and records an unapplied event")
	_check(downed_party.get_hero(1).get("hp") == 39
		and downed_party.get_hero(2).get("hp") == 0
		and downed_party.get_hero(3).get("hp") == 26,
		"AC3: the living source still damages its target; the downed hero takes nothing")
	var heroes := downed_party.get_heroes()
	_check(heroes.size() == 3 and heroes[0].get("id") == "warden"
		and heroes[1].get("id") == "seamstress" and heroes[2].get("id") == "tinker"
		and heroes[0].get("position") == 1 and heroes[1].get("position") == 2
		and heroes[2].get("position") == 3,
		"AC3: the original three-slot party order is preserved")
	var downed_roster := downed_enemies.get_enemies()
	_check(downed_roster.size() == 2 and downed_roster[0].get("block") == 0
		and downed_roster[1].get("block") == 0,
		"AC3: the downed-target phase leaves both enemy slots unchanged")


## AC4: the rejected copies fail closed, the authored encounter stays valid
## and the previously authored named encounters still exist and validate.
func _test_rejections() -> void:
	var definitions := _load_definitions(ENCOUNTER_PATH)
	_check(definitions.size() == 2,
		"AC4: the authored schedule loads for the rejection fixtures")
	if definitions.size() != 2:
		return
	var pristine := definitions.duplicate(true)
	var valid := CombatEnemyIntents.new(definitions)
	_check(valid.is_valid(),
		"AC4: the authored encounter is valid before the rejected copies")
	var valid_before := valid.get_intents()

	var duplicate := pristine.duplicate(true)
	duplicate[1]["enemy_position"] = 1
	var bad_target := pristine.duplicate(true)
	bad_target[1]["pattern"][0]["target_position"] = 4
	var targeted_block := pristine.duplicate(true)
	targeted_block[0]["pattern"][1]["target_position"] = 2

	var cases := [
		{"label": "duplicate enemy source position", "definitions": duplicate},
		{"label": "out of range hero target", "definitions": bad_target},
		{"label": "a Block carrying a hero target", "definitions": targeted_block},
	]
	for case in cases:
		var label: String = case["label"]
		var broken: Array = case["definitions"]
		var snapshot := broken.duplicate(true)
		var broken_intents := CombatEnemyIntents.new(broken)
		_check(not broken_intents.is_valid(),
			"AC4: the intent validator rejects " + label)
		_check(broken_intents.get_intents().is_empty(),
			"AC4: a rejected " + label + " announces zero intents")
		_check(not broken_intents.advance_turn(),
			"AC4: a rejected " + label + " cannot advance its turn")
		_check(broken == snapshot,
			"AC4: rejecting " + label + " does not mutate the detached copy")

	_check(valid.is_valid() and valid.get_intents() == valid_before,
		"AC4: the rejected copies never corrupt the authored encounter")
	_check(definitions == pristine,
		"AC4: the authored definitions are unchanged by the rejected copies")

	# The integral check is real: an integral float is coerced, a fractional
	# one is refused before any int conversion.
	_number_error = false
	var coerced: Variant = _normalize_numbers({"amount": 2.0, "target": 3.0})
	_check(not _number_error and coerced is Dictionary
		and coerced.get("amount") == 2 and coerced.get("amount") is int
		and coerced.get("target") == 3 and coerced.get("target") is int,
		"AC4: an integral JSON float is normalized to int")
	_number_error = false
	_normalize_numbers({"amount": 1.5})
	_check(_number_error,
		"AC4: a fractional JSON number is refused instead of truncated")

	# The same rule end to end on detached copies of the authored schedule.
	var whole_float := pristine.duplicate(true)
	whole_float[0]["pattern"][0]["amount"] = 1.0
	_check(_parse_definitions_text(JSON.stringify(whole_float),
		"whole float copy", false).size() == 2,
		"AC4: a detached copy holding an integral float is normalized and accepted")
	var fractional_amount := pristine.duplicate(true)
	fractional_amount[0]["pattern"][0]["amount"] = 1.5
	_check(_parse_definitions_text(JSON.stringify(fractional_amount),
		"fractional amount copy", false).is_empty(),
		"AC4: a detached copy with a fractional amount is refused by the loader")
	var fractional_target := pristine.duplicate(true)
	fractional_target[0]["pattern"][0]["target_position"] = 1.5
	_check(_parse_definitions_text(JSON.stringify(fractional_target),
		"fractional target copy", false).is_empty(),
		"AC4: a detached copy with a fractional hero target is refused by the loader")

	# The previously authored named encounters are still present and valid.
	# No encounter total and no complete ordered catalog list is asserted.
	for entry in _named_previous_encounters():
		var id: String = entry["id"]
		var path: String = entry["path"]
		_check(FileAccess.file_exists(path),
			"AC4: the named previous encounter " + id + " still exists")
		var previous := _load_definitions(path)
		_check(not previous.is_empty(),
			"AC4: the named previous encounter " + id + " still parses")
		_check(CombatEnemyIntents.new(previous).is_valid(),
			"AC4: the named previous encounter " + id + " still passes the intent validator")
		var schedule: Array = entry["schedule"]
		for source in schedule:
			var actual := _source_at(previous, source["enemy_position"])
			_check(actual == source,
				"AC4: " + id + " source " + str(source["enemy_position"])
				+ " keeps its exact authored actions")

	_check(_read_text(ENCOUNTER_PATH) == _authored_text,
		"AC4: the authored file text is unchanged by every check")
