extends SceneTree
## M03 standalone authored content: the Thimble Crossfire Fight schedule.
##
## Two existing starter sources (Ragling in slot 1, Guard Ragling in slot 2)
## each run their own fixed cycle built only from the existing attack and
## Block mechanics: the front source strikes the rear hero, then the middle
## hero, then blocks; the rear source strikes the front hero, then blocks.
## The two cycles interleave into one combined cycle of six enemy phases.
##
## This lane owns the authored data and its regression only. Registering the
## encounter in the run map / Fight pool and the live battle is later work and
## is deliberately not claimed here, so the Fight-selection proof below builds
## its own single-entry pool instead of touching the live registry.

const ENCOUNTER_PATH := "res://data/encounters/thimble_crossfire.json"
const ENCOUNTER_ID := "thimble_crossfire"
const GUARD_PATH := "res://data/encounters/guard_counterattack.json"
const SPOOLWHEEL_PATH := "res://data/encounters/spoolwheel_feint.json"
const HEROES_PATH := "res://data/heroes/starter_party.json"
const ENEMIES_PATH := "res://data/enemies/starter_enemies.json"
## A probe file that exists but does not parse. It is created and removed
## inside this test, never committed.
const MALFORMED_PROBE := "res://data/encounters/thimble_crossfire_probe_tmp.json"

## Independently authored expectations: cumulative party HP per beat.
const EXPECTED_HP := [
	[39, 30, 25], [39, 29, 25], [38, 29, 25],
	[38, 29, 24], [37, 28, 24], [37, 28, 24]]
## Independently authored expectations: cumulative enemy Block per beat
## (front source, rear source).
const EXPECTED_BLOCK := [
	[0, 0], [0, 1], [1, 1], [1, 2], [1, 2], [2, 3]]

var failures: Array[String] = []
var checks := 0
var _authored_text := ""


func _initialize() -> void:
	_authored_text = _read_text(ENCOUNTER_PATH)
	_test_authored_file()
	_test_announcements()
	_test_combat_execution()
	_test_slain_source_and_downed_target()
	_test_rejections()
	_test_single_pool_selection()
	# The malformed probe never survives this test, even if an earlier
	# section aborted before its own cleanup.
	_remove_probe()
	if failures.is_empty():
		print("thimble_crossfire_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("thimble_crossfire_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Removes the malformed probe file if it is still on disk.
func _remove_probe() -> void:
	if FileAccess.file_exists(MALFORMED_PROBE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MALFORMED_PROBE))


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


## The shared encounter loader used by the live Fight selection service.
func _shared_parsed(path: String) -> Array:
	return RunFightEncounterSelection._parse_schedule_text(_read_text(path))


## Exactly one source record at the given enemy slot.
func _source_at(definitions: Array, position: int) -> Dictionary:
	var matches: Array = []
	for definition in definitions:
		if definition is Dictionary and definition.get("enemy_position") == position:
			matches.append(definition)
	_check(matches.size() == 1,
		"the schedule holds exactly one source at enemy_position %d" % position)
	return matches[0].duplicate(true) if matches.size() == 1 else {}


## Exactly one catalog record with the given id.
func _record_by_id(records: Array, id: String) -> Dictionary:
	var matches: Array = []
	for record in records:
		if record is Dictionary and record.get("id") == id:
			matches.append(record)
	_check(matches.size() == 1, "the catalog holds exactly one record named " + id)
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
			{"type": "attack", "amount": 1, "target_position": 3},
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "block", "amount": 1}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "block", "amount": 1}]},
	]


func _attack(owner: int, target: int) -> Dictionary:
	return {"type": "attack", "amount": 1, "target_position": target,
		"enemy_position": owner}


func _block(owner: int) -> Dictionary:
	return {"type": "block", "amount": 1, "enemy_position": owner}


## The exact full announcement of every beat, written out by hand.
func _expected_beats() -> Array:
	return [
		[_attack(1, 3), _attack(2, 1)],
		[_attack(1, 2), _block(2)],
		[_block(1), _attack(2, 1)],
		[_attack(1, 3), _block(2)],
		[_attack(1, 2), _attack(2, 1)],
		[_block(1), _block(2)],
	]


func _expected_events(beat: int, dead_source: int = 0) -> Array:
	var events: Array = []
	for intent in _expected_beats()[beat]:
		var event := {"type": intent["type"], "enemy_position": intent["enemy_position"],
			"applied": intent["enemy_position"] != dead_source}
		if intent["type"] == "attack":
			event["target_position"] = intent["target_position"]
		events.append(event)
	return events


## The previously authored named encounters, identified by name and by source
## slot. No catalogue total and no complete ordered catalogue list is asserted.
func _named_previous_encounters() -> Array:
	return [
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


## The real authored hero and enemy catalogs, loaded from disk.
func _catalog(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(_read_text(path))
	_check(parsed is Array, "the catalog parses as an array: " + path)
	if not parsed is Array:
		return []
	# JSON represents whole-valued max_hp as a float in some Godot versions.
	# Validate it before conversion; no fractional or unsafe HP is accepted.
	var records: Array = []
	for entry in parsed:
		if not entry is Dictionary or not entry.has("max_hp"):
			return []
		var hp: Variant = entry["max_hp"]
		if hp is float:
			if is_nan(hp) or is_inf(hp) or hp <= 0 or hp > 9007199254740991.0 \
					or floorf(hp) != hp:
				return []
			entry["max_hp"] = int(hp)
		records.append(entry)
	return records


func _party() -> CombatParty:
	var records := _catalog(HEROES_PATH)
	var definitions: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		definitions.append(_record_by_id(records, id))
	return CombatParty.new(definitions)


func _enemies() -> CombatEnemies:
	var records := _catalog(ENEMIES_PATH)
	var definitions: Array = []
	for id in ["ragling", "ragling_guard"]:
		definitions.append(_record_by_id(records, id))
	return CombatEnemies.new(definitions)


## AC1: the authored file carries exactly the two required source cycles, the
## shipped two-Ragling roster and 40/30/26 heroes are untouched, and the
## shared encounter loader accepts the whole document.
func _test_authored_file() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH),
		"AC1: the %s authored encounter exists" % ENCOUNTER_ID)
	_check(not _authored_text.is_empty(),
		"AC1: the thimble_crossfire authored file is readable")
	var parsed := _shared_parsed(ENCOUNTER_PATH)
	_check(not parsed.is_empty(),
		"AC1: the shared encounter loader accepts the authored file")
	_check(parsed.size() == 2,
		"AC1: thimble_crossfire holds exactly two enemy source records")
	if parsed.size() != 2:
		return

	var slot1 := _source_at(parsed, 1)
	var slot2 := _source_at(parsed, 2)
	var expected := _expected_schedule()
	_check(slot1 == expected[0],
		"AC1: source slot 1 is the authored three-beat cycle")
	_check(slot2 == expected[1],
		"AC1: source slot 2 is the authored two-beat cycle")

	# Every authored number is integral in the raw text and an int after the
	# shared loader's normalization (1 == 1.0 in GDScript, so the type is
	# asserted explicitly).
	var raw_parsed = JSON.parse_string(_authored_text)
	_check(raw_parsed is Array,
		"AC1: the raw authored text parses into a JSON array")
	_check(raw_parsed is Array and _all_numeric_leaves_integral(raw_parsed),
		"AC1: every authored numeric field is integral before any int coercion")
	_check(raw_parsed is Array and _count_numeric_leaves(raw_parsed) == 10,
		"AC1: the authored document really holds its ten numeric fields")

	for source in [slot1, slot2]:
		_check(source.size() == 2 and source.has("enemy_position")
			and source.has("pattern"),
			"AC1: a source record carries only enemy_position and pattern")
		_check(source.get("enemy_position") is int,
			"AC1: an authored enemy_position is an int after the shared loader")
		var pattern: Array = source.get("pattern", [])
		_check(not pattern.is_empty(),
			"AC1: an authored source runs a non-empty cycle")
		for action in pattern:
			_check(action is Dictionary, "AC1: an authored action is a record")
			if not action is Dictionary:
				continue
			var kind: Variant = action.get("type")
			_check(kind == "attack" or kind == "block",
				"AC1: an authored action is an attack or a Block")
			_check(action.get("amount") is int,
				"AC1: an authored amount is an int after the shared loader")
			_check(action.get("amount") == 1,
				"AC1: an authored action amount is exactly 1")
			if kind == "block":
				_check(action.size() == 2 and not action.has("target_position"),
					"AC1: a Block action carries no hero target")
			else:
				_check(action.size() == 3 and action.has("target_position"),
					"AC1: an attack action carries exactly one hero target")
				_check(action.get("target_position") is int,
					"AC1: an authored attack target is an int after the shared loader")
				_check(action.get("target_position") in [1, 2, 3],
					"AC1: an attack target is a real hero slot")

	# Every beat of every source, named explicitly.
	var pattern1: Array = slot1.get("pattern", [])
	var pattern2: Array = slot2.get("pattern", [])
	_check(pattern1.size() == 3
		and pattern1[0] == {"type": "attack", "amount": 1, "target_position": 3},
		"AC1: source 1 beat 0 attacks hero position 3 for 1")
	_check(pattern1.size() == 3
		and pattern1[1] == {"type": "attack", "amount": 1, "target_position": 2},
		"AC1: source 1 beat 1 attacks hero position 2 for 1")
	_check(pattern1.size() == 3
		and pattern1[2] == {"type": "block", "amount": 1},
		"AC1: source 1 beat 2 is an untargeted Block of 1")
	_check(pattern2.size() == 2
		and pattern2[0] == {"type": "attack", "amount": 1, "target_position": 1},
		"AC1: source 2 beat 0 attacks hero position 1 for 1")
	_check(pattern2.size() == 2
		and pattern2[1] == {"type": "block", "amount": 1},
		"AC1: source 2 beat 1 is an untargeted Block of 1")

	_check(CombatEnemyIntents.new(parsed).is_valid(),
		"AC1: the authored schedule passes the real intent validator")

	# The two sources are the unchanged starter enemies.
	var roster := _catalog(ENEMIES_PATH)
	var ragling := _record_by_id(roster, "ragling")
	var guard := _record_by_id(roster, "ragling_guard")
	_check(ragling.get("name") == "Ragling" and ragling.get("max_hp") == 12,
		"AC1: slot 1 is the unchanged Ragling with 12 maximum HP")
	_check(guard.get("name") == "Guard Ragling" and guard.get("max_hp") == 12,
		"AC1: slot 2 is the unchanged Guard Ragling with 12 maximum HP")
	_check(ragling.get("art_path") is String and guard.get("art_path") is String
		and not String(ragling.get("art_path")).is_empty()
		and ragling.get("art_path") == guard.get("art_path"),
		"AC1: both sources keep their existing authored art path")

	# The party the encounter is balanced against is unchanged too.
	var heroes := _catalog(HEROES_PATH)
	var warden := _record_by_id(heroes, "warden")
	var seamstress := _record_by_id(heroes, "seamstress")
	var tinker := _record_by_id(heroes, "tinker")
	_check(warden.get("name") == "Warden" and warden.get("max_hp") == 40,
		"AC1: the unchanged Warden starts with 40 maximum HP")
	_check(seamstress.get("name") == "Seamstress" and seamstress.get("max_hp") == 30,
		"AC1: the unchanged Seamstress starts with 30 maximum HP")
	_check(tinker.get("name") == "Tinker" and tinker.get("max_hp") == 26,
		"AC1: the unchanged Tinker starts with 26 maximum HP")


## AC2: the announced intent sequence is deterministic, source-ordered, wraps
## after six phases and is detached from its caller.
func _test_announcements() -> void:
	var definitions := _shared_parsed(ENCOUNTER_PATH)
	_check(definitions.size() == 2,
		"AC2: the authored schedule loads for the scheduler")
	if definitions.size() != 2:
		return
	var pristine := definitions.duplicate(true)
	var expected := _expected_beats()
	var scheduler := CombatEnemyIntents.new(definitions)
	var replay := CombatEnemyIntents.new(pristine.duplicate(true))
	_check(scheduler.is_valid() and replay.is_valid(),
		"AC2: both independent schedulers are valid")
	if not scheduler.is_valid() or not replay.is_valid():
		return

	for beat in range(7):
		var announced := scheduler.get_intents()
		var replayed := replay.get_intents()
		_check(announced == expected[beat % 6],
			"AC2: beat %d announces the exact authored source-ordered pair" % beat)
		_check(replayed == expected[beat % 6],
			"AC2: a fresh scheduler replays beat %d exactly" % beat)
		_check(announced.size() == 2 and _positions_of(announced) == [1, 2],
			"AC2: beat %d announces source slot 1 before source slot 2" % beat)
		for action in announced:
			if action.get("type") == "block":
				_check(not action.has("target_position"),
					"AC2: beat %d Block announcement carries no hero target" % beat)
			else:
				_check(action.get("target_position") in [1, 2, 3],
					"AC2: beat %d attack announcement names a real hero slot" % beat)
		# A caller that edits the returned snapshot cannot corrupt the schedule.
		var dirty := announced.duplicate(true)
		dirty[0]["amount"] = 900
		dirty[0]["type"] = "invented"
		dirty[1]["enemy_position"] = 3
		dirty.append({"type": "block", "amount": 5, "enemy_position": 3})
		_check(scheduler.get_intents() == expected[beat % 6],
			"AC2: beat %d caller mutation cannot corrupt the next announcement" % beat)
		if beat < 6:
			_check(scheduler.advance_turn() and replay.advance_turn(),
				"AC2: beat %d advances the schedule exactly one step" % beat)

	_check(scheduler.get_intents() == expected[0],
		"AC2: after six phases the cycle wraps back to the first authored pair")
	_check(definitions == pristine,
		"AC2: the parsed definitions are unchanged after the whole timeline")
	_check(_read_text(ENCOUNTER_PATH) == _authored_text,
		"AC2: the authored file text is unchanged after the whole timeline")


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
	# The isolated fixture deliberately does not invoke Warden's opening
	# passive, so every hero enters the encounter with zero Block.
	_check(party.get_hero(1).get("block") == 0,
		label + ": the Warden enters without its opening passive Block")
	var enemy_ids := ["ragling", "ragling_guard"]
	for i in range(2):
		var enemy := enemies.get_enemy(i + 1)
		_check(enemy.get("id") == enemy_ids[i] and enemy.get("hp") == 12
			and enemy.get("max_hp") == 12 and enemy.get("block") == 0
			and enemy.get("position") == i + 1,
			label + ": %s starts in slot %d with 12 HP and no Block"
			% [enemy_ids[i], i + 1])
	return true


## Runs the six authored beats against a fresh fixture and returns the whole
## observable trace, so two runs can be compared in full.
func _run_beats(label: String) -> Array:
	var party := _party()
	var enemies := _enemies()
	if not _fixture_ok(party, enemies, label):
		return []
	var scheduler := CombatEnemyIntents.new(_shared_parsed(ENCOUNTER_PATH))
	_check(scheduler.is_valid(), label + ": the authored schedule instantiates")
	if not scheduler.is_valid():
		return []
	var phase := CombatEnemyPhase.new()
	var initial_heroes := party.get_heroes()
	var initial_roster := enemies.get_enemies()
	var trace: Array = []
	for beat in range(6):
		var intents := scheduler.get_intents()
		var untouched := intents.duplicate(true)
		_check(intents == _expected_beats()[beat], label + ": beat %d exact intents" % beat)
		var result := phase.execute_phase(party, enemies, intents)
		_check(result == {"ok": true, "events": _expected_events(beat)},
			label + ": beat %d exact ordered applied/target events" % beat)
		_check(intents == untouched and scheduler.get_intents() == _expected_beats()[beat],
			label + ": beat %d the phase neither mutates the intents nor advances" % beat)
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
		_check(scheduler.advance_turn(), label + ": beat %d advances the scheduler once" % beat)
	_check(scheduler.get_intents() == _expected_beats()[0],
		label + ": after six beats the cycle wraps to the first authored pair")
	return trace


## AC2: six real CombatEnemyPhase calls produce the authored cumulative HP
## and Block sequences, repeat identically and draw no global RNG.
func _test_combat_execution() -> void:
	var first := _run_beats("AC2 first")
	var replay := _run_beats("AC2 replay")
	_check(first.size() == 6 and replay.size() == 6 and first == replay,
		"AC2: six complete beats replay identically from fresh fixtures")
	if first.size() == 6:
		_check(first[5]["party"][0]["hp"] == 37
			and first[5]["party"][1]["hp"] == 28
			and first[5]["party"][2]["hp"] == 24,
			"AC2: after six phases the party HP is 37/28/24")
		_check(first[5]["enemies"][0]["block"] == 2
			and first[5]["enemies"][1]["block"] == 3,
			"AC2: after six phases the enemy Block is 2/3")
		_check(first[0]["party"][0]["hp"] == 39
			and first[0]["party"][1]["hp"] == 30
			and first[0]["party"][2]["hp"] == 25,
			"AC2: after the first phase the party HP is 39/30/25")
		_check(first[0]["enemies"][0]["block"] == 0
			and first[0]["enemies"][1]["block"] == 0,
			"AC2: after the first phase neither source has built Block")

	# The real attack and Block executors are exercised directly as well.
	var direct_party := _party()
	var direct_enemies := _enemies()
	_check(_fixture_ok(direct_party, direct_enemies, "AC2 direct executors"),
		"AC2: the direct-executor fixture is valid")
	var attack_result := CombatEnemyAttacks.new().execute_attacks(direct_party, [
		{"enemy_position": 1, "target_position": 3, "amount": 1},
		{"enemy_position": 2, "target_position": 1, "amount": 1}])
	_check(attack_result == {"ok": true, "events": [
		{"enemy_position": 1, "target_position": 3, "applied": true},
		{"enemy_position": 2, "target_position": 1, "applied": true}]},
		"AC2: the real attack executor applies the authored opening pair")
	_check(direct_party.get_hero(1).get("hp") == 39
		and direct_party.get_hero(2).get("hp") == 30
		and direct_party.get_hero(3).get("hp") == 25,
		"AC2: the real attack executor moved exactly the authored HP")
	var block_result := CombatEnemyBlocks.execute_blocks(direct_enemies, [
		{"type": "block", "amount": 1, "enemy_position": 1},
		{"type": "block", "amount": 1, "enemy_position": 2}])
	_check(block_result == {"ok": true, "events": [
		{"enemy_position": 1, "applied": true},
		{"enemy_position": 2, "applied": true}]},
		"AC2: the real Block executor applies the authored Blocks")
	_check(direct_enemies.get_enemy(1).get("block") == 1
		and direct_enemies.get_enemy(2).get("block") == 1,
		"AC2: the real Block executor moved exactly the authored Block")

	# The global RNG stream must be untouched by the encounter.
	seed(31337)
	var control_a := randi()
	seed(31337)
	var control_b := randi()
	_check(control_a == control_b,
		"AC2 control: the same global seed reproduces the same global draw")
	seed(31337)
	var oracle := randi()
	seed(31337)
	_run_beats("AC2 global RNG")
	_check(randi() == oracle,
		"AC2: the authored encounter draws no global RNG")


## AC3: a slain source skips its authored action and a downed target absorbs
## no further attack, while the original slot order is preserved.
func _test_slain_source_and_downed_target() -> void:
	var party := _party()
	var enemies := _enemies()
	if not _fixture_ok(party, enemies, "AC3 slain source"):
		return
	var scheduler := CombatEnemyIntents.new(_shared_parsed(ENCOUNTER_PATH))
	_check(scheduler.is_valid(),
		"AC3: the slain-source fixture has a valid scheduler")
	if not scheduler.is_valid():
		return
	_check(enemies.apply_damage(1, 12) and enemies.is_slain(1) and not enemies.is_slain(2),
		"AC3: the front source is really slain and the rear source is alive")
	var intents := scheduler.get_intents()
	var result := CombatEnemyPhase.new().execute_phase(party, enemies, intents)
	_check(result == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "applied": false, "target_position": 3},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 1}]},
		"AC3: the slain source's attack has no effect while the living source still acts")
	_check(party.get_hero(1).get("hp") == 39 and party.get_hero(2).get("hp") == 30
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
	_check(scheduler.advance_turn() and scheduler.advance_turn(),
		"AC3: the scheduler advances to the beat where the front source blocks")
	var block_intents := scheduler.get_intents()
	_check(block_intents == _expected_beats()[2],
		"AC3: the third beat is the front source's Block")
	var block_result := CombatEnemyPhase.new().execute_phase(party, enemies, block_intents)
	_check(block_result == {"ok": true, "events": [
		{"type": "block", "enemy_position": 1, "applied": false},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 1}]},
		"AC3: the slain source's Block is skipped and the living source still attacks")
	_check(enemies.get_enemy(1).get("block") == 0,
		"AC3: the slain source gains no Block from its skipped action")
	_check(enemies.get_enemy(2).get("block") == 0,
		"AC3: the living source attacked instead of blocking")
	_check(party.get_hero(1).get("hp") == 38,
		"AC3: the front hero takes the living source's second hit")

	# A downed hero absorbs no further attack; the other source still acts.
	var downed_party := _party()
	var downed_enemies := _enemies()
	if not _fixture_ok(downed_party, downed_enemies, "AC3 downed target"):
		return
	var downed_scheduler := CombatEnemyIntents.new(_shared_parsed(ENCOUNTER_PATH))
	_check(downed_scheduler.is_valid(),
		"AC3: the downed-target fixture has a valid scheduler")
	if not downed_scheduler.is_valid():
		return
	_check(downed_party.apply_damage(2, 30) and downed_party.is_downed(2),
		"AC3: the middle hero is really downed")
	_check(downed_scheduler.advance_turn(),
		"AC3: the downed-target fixture advances to the beat that strikes the middle hero")
	var downed_intents := downed_scheduler.get_intents()
	_check(downed_intents == _expected_beats()[1],
		"AC3: the second beat is the front source's attack on hero position 2")
	var downed_result := CombatEnemyPhase.new().execute_phase(
		downed_party, downed_enemies, downed_intents)
	_check(downed_result == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "applied": false, "target_position": 2},
		{"type": "block", "enemy_position": 2, "applied": true}]},
		"AC3: a downed target absorbs no attack and records an unapplied event")
	_check(downed_party.get_hero(1).get("hp") == 40
		and downed_party.get_hero(2).get("hp") == 0
		and downed_party.get_hero(3).get("hp") == 26,
		"AC3: the downed hero takes nothing and the other heroes are untouched")
	_check(downed_enemies.get_enemy(2).get("block") == 1,
		"AC3: the living source still builds its Block")
	var heroes := downed_party.get_heroes()
	_check(heroes.size() == 3 and heroes[0].get("id") == "warden"
		and heroes[1].get("id") == "seamstress" and heroes[2].get("id") == "tinker"
		and heroes[0].get("position") == 1 and heroes[1].get("position") == 2
		and heroes[2].get("position") == 3,
		"AC3: the original three-slot party order is preserved")


## AC3: malformed local schedules and invalid later actions fail closed with
## unchanged actors, and a failed parse or a failed pool spends no RNG.
func _test_rejections() -> void:
	var parsed := _shared_parsed(ENCOUNTER_PATH)
	_check(parsed.size() == 2,
		"AC3: the authored schedule loads for the rejection fixtures")
	if parsed.size() != 2:
		return
	var pristine := parsed.duplicate(true)

	# Malformed local schedules are refused whole, never partially accepted.
	var malformed_texts := [
		"{broken",
		"[]",
		"{}",
		JSON.stringify([pristine[0], pristine[0]]),
		JSON.stringify([{"enemy_position": 1, "pattern": []}, pristine[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1}]}, pristine[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": 1, "target_position": 2}]}, pristine[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "heal", "amount": 1}]}, pristine[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": -1, "target_position": 2}]}, pristine[1]]),
		JSON.stringify([{"enemy_position": 1.5, "pattern": [
			{"type": "block", "amount": 1}]}, pristine[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": 1.5}]}, pristine[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 2.5}]}, pristine[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": "1"}]}, pristine[1]]),
	]
	for i in range(malformed_texts.size()):
		_check(RunFightEncounterSelection._parse_schedule_text(malformed_texts[i]).is_empty(),
			"AC3: malformed local schedule %d is refused without partial data" % i)

	# Detached copies are refused by the real intent service as well.
	var duplicate := pristine.duplicate(true)
	duplicate[1]["enemy_position"] = 1
	var bad_target := pristine.duplicate(true)
	bad_target[1]["pattern"][0]["target_position"] = 4
	var targeted_block := pristine.duplicate(true)
	targeted_block[0]["pattern"][2]["target_position"] = 2
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
			"AC3: the intent validator rejects " + label)
		_check(broken_intents.get_intents().is_empty(),
			"AC3: a rejected " + label + " announces zero intents")
		_check(not broken_intents.advance_turn(),
			"AC3: a rejected " + label + " cannot advance its turn")
		_check(broken == snapshot,
			"AC3: rejecting " + label + " does not mutate the detached copy")

	# An invalid later action must not let the earlier valid action land.
	var clean_party := _party()
	var clean_enemies := _enemies()
	if not _fixture_ok(clean_party, clean_enemies, "AC3 invalid phase"):
		return
	var before_party := clean_party.get_heroes()
	var before_enemies := clean_enemies.get_enemies()
	var invalid_phases := [
		[_block(1), {"type": "attack", "amount": 1, "enemy_position": 2,
			"target_position": 4}],
		[_attack(2, 1), {"type": "block", "amount": 1, "enemy_position": 1,
			"target_position": 3}],
	]
	for i in range(invalid_phases.size()):
		var invalid_phase: Array = invalid_phases[i]
		var phase_copy := invalid_phase.duplicate(true)
		_check(CombatEnemyPhase.new().execute_phase(clean_party, clean_enemies, invalid_phase)
			== {"ok": false, "events": []},
			"AC3: invalid later action %d rejects the whole phase" % i)
		_check(clean_party.get_heroes() == before_party
			and clean_enemies.get_enemies() == before_enemies
			and invalid_phase == phase_copy,
			"AC3: invalid later action %d leaves every actor and its input intact" % i)

	# A failed parse or a failed pool must not spend the run RNG.
	var reject_rng := RandomNumberGenerator.new()
	reject_rng.seed = 909090
	var reject_map := RunMap.new()
	_check(reject_map.generate(reject_rng),
		"AC3: the rejection fixture map generates")
	var fight := _opening_fight(reject_map)
	_check(not fight.is_empty() and reject_map.get_legal_choices().has(fight),
		"AC3: the rejection fixture really offers a legal Fight")
	if fight.is_empty():
		return
	_check(reject_map.choose_node(fight),
		"AC3: the rejection fixture enters its legal Fight")
	var rng_before := reject_rng.state
	var bad_pools := [
		{},
		{"absent": "res://data/encounters/no_such_thimble_crossfire.json"},
		{"bad": "res://data/enemies/starter_enemies.json"},
		{"bad": "res://data/encounters/../encounters/starter_attacks.json"},
		{"valid": ENCOUNTER_PATH, "broken": "res://data/encounters/absent_thimble_crossfire.json"},
	]
	for pool in bad_pools:
		var picker := RunFightEncounterSelection.new()
		var answer := picker.select_current_fight(reject_map, reject_rng, pool)
		_check(answer == {"success": false},
			"AC3: a broken pool is refused: " + str(pool.keys()))
		_check(reject_rng.state == rng_before,
			"AC3: a broken pool spends no run RNG: " + str(pool.keys()))
		_check(picker._selected.is_empty() and picker._bound_map == null,
			"AC3: a broken pool leaves the selector unbound and uncached")

	# A pool entry whose file exists but does not parse fails closed too.
	var probe := FileAccess.open(MALFORMED_PROBE, FileAccess.WRITE)
	_check(probe != null, "AC3: the malformed probe file is created")
	if probe != null:
		probe.store_string("{not valid json")
		probe.close()
		_check(FileAccess.file_exists(MALFORMED_PROBE),
			"AC3: the malformed probe file really exists on disk")
		var probe_picker := RunFightEncounterSelection.new()
		var probe_answer := probe_picker.select_current_fight(
			reject_map, reject_rng, {"broken": MALFORMED_PROBE})
		_check(probe_answer == {"success": false},
			"AC3: a pool whose file fails to parse is refused")
		_check(reject_rng.state == rng_before,
			"AC3: a failed parse spends no run RNG")
		_check(probe_picker._selected.is_empty() and probe_picker._bound_map == null,
			"AC3: a failed parse leaves the selector unbound and uncached")
	_remove_probe()
	_check(not FileAccess.file_exists(MALFORMED_PROBE),
		"AC3: the malformed probe file is removed again")

	# A valid selection after all those refusals still works and spends
	# exactly its one selection draw.
	var retry_rng := RandomNumberGenerator.new()
	retry_rng.seed = 909090
	var retry_oracle := RandomNumberGenerator.new()
	retry_oracle.seed = 909090
	var retry_map := RunMap.new()
	var retry_oracle_map := RunMap.new()
	_check(retry_map.generate(retry_rng) and retry_oracle_map.generate(retry_oracle),
		"AC3: the retry fixture map generates")
	_check(retry_map.choose_node(fight), "AC3: the retry fixture enters a legal Fight")
	var retry_picker := RunFightEncounterSelection.new()
	var retry_answer := retry_picker.select_current_fight(
		retry_map, retry_rng, {ENCOUNTER_ID: ENCOUNTER_PATH})
	var retry_expected := retry_oracle.randi_range(0, 0)
	_check(retry_answer == {"success": true, "encounter_id": ENCOUNTER_ID,
		"definitions": _expected_schedule()},
		"AC3: a valid selection after the refusals returns the authored encounter")
	_check(retry_expected == 0 and retry_rng.state == retry_oracle.state,
		"AC3: the valid retry spends exactly one selection draw")

	# The previously authored named encounters are still present and valid.
	# No encounter total and no complete ordered catalogue list is asserted.
	for entry in _named_previous_encounters():
		var id: String = entry["id"]
		var path: String = entry["path"]
		_check(FileAccess.file_exists(path),
			"AC3: the named previous encounter " + id + " still exists")
		var previous := _shared_parsed(path)
		_check(not previous.is_empty(),
			"AC3: the named previous encounter " + id + " still parses")
		_check(CombatEnemyIntents.new(previous).is_valid(),
			"AC3: the named previous encounter " + id + " still passes the intent validator")
		var schedule: Array = entry["schedule"]
		for source in schedule:
			var actual := _source_at(previous, source["enemy_position"])
			_check(actual == source,
				"AC3: " + id + " source " + str(source["enemy_position"])
				+ " keeps its exact authored actions")
		_check(previous != pristine,
			"AC3: the named previous encounter " + id
			+ " is distinct from the new authored schedule")

	_check(_read_text(ENCOUNTER_PATH) == _authored_text,
		"AC3: the authored file text is unchanged by every check")


func _opening_fight(map: RunMap) -> String:
	for candidate in map.get_legal_choices():
		if map.get_node(candidate).get("type") == "Fight":
			return candidate
	return ""


## AC1: the real Fight selection service loads the new encounter from a
## single-entry pool. The pool is built here, so the live app registry is
## neither read nor changed by this lane.
func _test_single_pool_selection() -> void:
	var pool := {ENCOUNTER_ID: ENCOUNTER_PATH}
	var seed_value := 515021
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var replay_rng := RandomNumberGenerator.new()
	replay_rng.seed = seed_value
	var oracle_rng := RandomNumberGenerator.new()
	oracle_rng.seed = seed_value
	var map := RunMap.new()
	var replay_map := RunMap.new()
	var oracle_map := RunMap.new()
	_check(map.generate(rng) and replay_map.generate(replay_rng)
		and oracle_map.generate(oracle_rng),
		"AC1: two independent seeded RunMap services generated")
	_check(map.get_floors() == replay_map.get_floors()
		and map.get_floors() == oracle_map.get_floors(),
		"AC1: the same seed reproduces the same map")
	var fight := _opening_fight(map)
	_check(not fight.is_empty() and map.get_legal_choices().has(fight),
		"AC1: a real legal opening Fight exists")
	if fight.is_empty():
		return
	_check(map.choose_node(fight) and replay_map.choose_node(fight)
		and oracle_map.choose_node(fight),
		"AC1: both maps enter the same chosen Fight")
	_check(map.get_current_node_id() == fight
		and map.get_node(fight)["type"] == "Fight" and map.get_route() == [fight],
		"AC1: the selector input really is the chosen current Fight")
	var floors := map.get_floors()
	var route := map.get_route()
	var oracle_id := oracle_rng.randi_range(0, 0)
	var picker := RunFightEncounterSelection.new()
	var replay_picker := RunFightEncounterSelection.new()
	var answer := picker.select_current_fight(map, rng, pool)
	var replay := replay_picker.select_current_fight(replay_map, replay_rng, pool)
	_check(oracle_id == 0 and rng.state == oracle_rng.state,
		"AC1: the single-entry selector spends exactly one run RNG draw")
	_check(answer == {"success": true, "encounter_id": ENCOUNTER_ID,
		"definitions": _expected_schedule()},
		"AC1: the real selector returns the exact new ID and the full parsed actions")
	_check(replay == answer and replay_rng.state == rng.state,
		"AC1: an independent same-seed map and selector replay the same choice")
	_check(CombatEnemyIntents.new(answer.get("definitions", [])).is_valid(),
		"AC1: the selected schedule is immediately usable by the real intent service")
	var original := answer.duplicate(true)
	var after_pick := rng.state
	answer["definitions"][0]["pattern"][0]["amount"] = 909
	answer["definitions"].clear()
	answer["encounter_id"] = "mutated"
	var cached := picker.select_current_fight(map, rng, {})
	_check(cached == original and rng.state == after_pick,
		"AC1: the selector caches its choice without spending RNG and is isolated from caller edits")
	_check(map.get_floors() == floors and map.get_route() == route,
		"AC1: the selection changes neither the graph nor the chosen route")
