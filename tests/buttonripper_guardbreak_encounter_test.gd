extends SceneTree
## M04 standalone authored content: the Buttonripper Guardbreak Fight schedule.
##
## Two existing run enemies (Button Guard in slot 1, Seam Ripper in slot 2)
## each run their own four-beat cycle: the Guard opens with Block, Exposes the
## front hero before the Ripper's amplified strike, hits the middle hero while
## the Ripper Weakens the rear hero, and finally buffs his own Block while the
## Ripper Bleeds the middle hero.
##
## This lane owns the authored data and its regression only. Registering the
## encounter in the shared typed Fight pool / run map and the live battle is
## later work and is deliberately not claimed here; the test-local one-entry
## pool below never reaches the live game.

const ENCOUNTER_PATH := "res://data/encounters/buttonripper_guardbreak.json"
const ENCOUNTER_ID := "buttonripper_guardbreak"
const HEROES_PATH := "res://data/heroes/starter_party.json"
const ENEMIES_PATH := "res://data/enemies/run_enemies.json"
const BUTTONHOLE_PATH := "res://data/encounters/buttonhole_holdout.json"
const TYPED_POOL_PATH := "res://data/encounters/m03_typed_battle_pools.json"
const MAP_SEED := 4103
const RNG_SEED := 20261022

## This encounter's own roster binding, owned by this test: slot 1 is the
## Button Guard and slot 2 the Seam Ripper, in that order.
const LOCAL_ROSTER_MAP := {
	ENCOUNTER_ID: ["button_guard", "seam_ripper"],
}

## Independently authored expectations: per-beat hero HP, hero Block and hero
## statuses, in slot order Warden/Seamstress/Tinker.
const EXPECTED_HERO_HP := [
	[40, 30, 21],
	[40, 30, 21],
	[40, 27, 21],
	[40, 27, 21],
]
const EXPECTED_HERO_BLOCK := [
	[6, 0, 0],
	[0, 0, 0],
	[0, 0, 0],
	[0, 0, 0],
]
const EXPECTED_HERO_STATUSES := [
	[{}, {}, {}],
	[{"exposed": 1}, {}, {}],
	[{"exposed": 1}, {}, {"weak": 1}],
	[{"exposed": 1}, {"bleed": 2}, {"weak": 1}],
]
## Enemy Block per beat, in slot order Button Guard/Seam Ripper. Enemy HP never
## changes in this encounter.
const EXPECTED_ENEMY_BLOCK := [
	[4, 0],
	[4, 0],
	[4, 0],
	[6, 0],
]

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_authored_schedule_and_parser()
	_test_prior_encounter_intact()
	_test_announcements()
	_test_real_four_phases()
	_test_typed_selection_and_roster()
	_test_fail_closed_fourth_beat()
	if failures.is_empty():
		print("buttonripper_guardbreak_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("buttonripper_guardbreak_encounter_test: FAIL (", failures.size(), " failures)")
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


## Godot's JSON parser may yield whole numbers as floats; the real model
## services require ints for max_hp, so catalog data is normalized exactly.
func _normalize(data: Variant) -> Variant:
	if data is Array:
		var result: Array = []
		for item in data:
			result.append(_normalize(item))
		return result
	if data is Dictionary:
		var result: Dictionary = {}
		for key in data:
			result[key] = _normalize(data[key])
		return result
	if data is float and is_finite(data) and floorf(data) == data:
		return int(data)
	return data


func _load_catalog(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(_read_text(path))
	if not parsed is Array:
		_check(false, "expected a JSON Array in " + path)
		return []
	return _normalize(parsed)


## One named record, located by its own stable id (never by list order or by a
## catalog total, which parallel lanes also append to).
func _record_by_id(records: Array, id: String) -> Dictionary:
	var matches: Array = []
	for record in records:
		if record is Dictionary and record.get("id") == id:
			matches.append(record)
	_check(matches.size() == 1, "catalog has exactly one record named " + id)
	return matches[0].duplicate(true) if matches.size() == 1 else {}


func _parsed() -> Array:
	return RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))


## The exact prescribed schedule for this encounter's own two sources.
func _expected_definitions() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": 4},
			{"type": "debuff", "amount": 1, "target_position": 1, "status": "exposed"},
			{"type": "attack", "amount": 3, "target_position": 2},
			{"type": "buff", "amount": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 5, "target_position": 3},
			{"type": "attack", "amount": 4, "target_position": 1},
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
			{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed"}]},
	]


## Literal announced beats, independent of the parsed file and of the schedule.
func _expected_beat(beat: int) -> Array:
	var actions: Array = []
	for definition in _expected_definitions():
		var pattern: Array = definition["pattern"]
		var action: Dictionary = pattern[beat % pattern.size()].duplicate(true)
		action["enemy_position"] = definition["enemy_position"]
		actions.append(action)
	return actions


func _expected_events(beat: int) -> Array:
	var events: Array = []
	for intent in _expected_beat(beat):
		var event := {"type": intent["type"], "enemy_position": intent["enemy_position"],
			"applied": true}
		for field in ["target_position", "status", "direction"]:
			if intent.has(field):
				event[field] = intent[field]
		events.append(event)
	return events


func _positions_of(announced: Array) -> Array:
	var positions: Array = []
	for action in announced:
		positions.append(action.get("enemy_position"))
	return positions


## The real three-hero party assembled from the shipped starter party file.
func _build_party() -> CombatParty:
	var heroes := _load_catalog(HEROES_PATH)
	var definitions: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		definitions.append(_record_by_id(heroes, id))
	return CombatParty.new(definitions)


## The real two-enemy roster in this encounter's own slot order, assembled by
## the real typed-roster bridge from the shipped run_enemies.json records.
func _assemble_enemies() -> CombatEnemies:
	var typed_choice := {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": _parsed().duplicate(true),
	}
	var assembled := RunTypedBattleRoster.new().assemble(
		typed_choice, LOCAL_ROSTER_MAP.duplicate(true), [ENEMIES_PATH])
	_check(assembled.get("ok") == true,
		"the typed roster assembles this encounter's two enemies")
	var enemies: Variant = assembled.get("enemies")
	if enemies is CombatEnemies:
		return enemies
	_check(false, "the assembled roster is a real CombatEnemies instance")
	return CombatEnemies.new([])


func _check_hero(party: CombatParty, position: int, id: String, hp: int, block: int,
		label: String) -> void:
	var hero := party.get_hero(position)
	_check(hero.get("id") == id and hero.get("hp") == hp and hero.get("block") == block,
		"%s: slot %d is %s with %d HP and %d Block (got %s %d/%d)"
			% [label, position, id, hp, block, hero.get("id"), hero.get("hp"), hero.get("block")])


func _check_enemy(enemies: CombatEnemies, position: int, id: String, hp: int, block: int,
		label: String) -> void:
	var enemy := enemies.get_enemy(position)
	_check(enemy.get("id") == id and enemy.get("hp") == hp and enemy.get("block") == block,
		"%s: enemy slot %d is %s with %d HP and %d Block (got %s %d/%d)"
			% [label, position, id, hp, block, enemy.get("id"), enemy.get("hp"), enemy.get("block")])


## The same identity/HP/Block assertions on a detached party snapshot.
func _check_hero_snapshot(heroes: Array, position: int, id: String, hp: int, block: int,
		label: String) -> void:
	var hero: Dictionary = heroes[position - 1]
	_check(hero.get("id") == id and hero.get("hp") == hp and hero.get("block") == block,
		"%s: slot %d is %s with %d HP and %d Block (got %s %d/%d)"
			% [label, position, id, hp, block, hero.get("id"), hero.get("hp"), hero.get("block")])


## The same identity/HP/Block assertions on a detached enemy snapshot.
func _check_enemy_snapshot(roster: Array, position: int, id: String, hp: int, block: int,
		label: String) -> void:
	var enemy: Dictionary = roster[position - 1]
	_check(enemy.get("id") == id and enemy.get("hp") == hp and enemy.get("block") == block,
		"%s: enemy slot %d is %s with %d HP and %d Block (got %s %d/%d)"
			% [label, position, id, hp, block, enemy.get("id"), enemy.get("hp"), enemy.get("block")])


## The complete expected party snapshot for a beat: the same actor records in
## their slot order with the prescribed HP, Block and optional statuses.
func _expected_party(initial: Array, hp: Array, block: Array, statuses: Array) -> Array:
	var expected: Array = []
	for index in range(initial.size()):
		var hero: Dictionary = initial[index].duplicate(true)
		hero["position"] = index + 1
		hero["hp"] = hp[index]
		hero["block"] = block[index]
		if not statuses[index].is_empty():
			hero["statuses"] = statuses[index].duplicate(true)
		expected.append(hero)
	return expected


## The complete expected enemy snapshot: the same records with the prescribed
## Block per slot. Enemy HP never changes in this encounter.
func _expected_enemies(initial: Array, block: Array) -> Array:
	var expected: Array = []
	for index in range(initial.size()):
		var enemy: Dictionary = initial[index].duplicate(true)
		enemy["block"] = block[index]
		expected.append(enemy)
	return expected


func _shared_pool() -> Variant:
	var file := FileAccess.open(TYPED_POOL_PATH, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed


## True only when the shared typed pool registers this encounter by its own ID
## or by its schedule path. The pool is a shared catalog other lanes append to,
## so this looks the encounter up by its own identity, never by a total.
func _shared_pool_registers_encounter() -> bool:
	var parsed: Variant = _shared_pool()
	if not parsed is Dictionary:
		return false
	for kind in parsed:
		var group = parsed[kind]
		if not group is Dictionary:
			continue
		for encounter_id in group:
			var entry = group[encounter_id]
			if not entry is Dictionary:
				continue
			if encounter_id == ENCOUNTER_ID or entry.get("schedule") == ENCOUNTER_PATH:
				return true
	return false


## AC1: the shipped file is exactly the prescribed two-source, four-beat
## schedule, the real parser and intent validator accept it, and the two named
## catalog actors and the starter party are untouched.
func _test_authored_schedule_and_parser() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "the authored encounter file exists")
	_check(ENCOUNTER_PATH.get_file().get_basename() == ENCOUNTER_ID,
		"the schedule file name carries the canonical encounter ID %s" % ENCOUNTER_ID)

	var raw_text := _read_text(ENCOUNTER_PATH)
	_check(not raw_text.is_empty(), "the authored encounter file is readable")
	var raw: Variant = JSON.parse_string(raw_text)
	_check(raw is Array and raw.size() == 2,
		"the authored file holds exactly this encounter's two source records")
	if raw is Array:
		_check(raw.size() == 2 and raw[0] is Dictionary and raw[1] is Dictionary
			and raw[0].get("enemy_position") == 1 and raw[1].get("enemy_position") == 2,
			"the authored sources are ordered by enemy_position 1 then 2")
		for raw_definition in raw:
			_check(raw_definition is Dictionary and raw_definition.size() == 2
				and raw_definition.has("enemy_position") and raw_definition.has("pattern"),
				"each authored source holds exactly enemy_position and pattern")
			if raw_definition is Dictionary:
				var raw_pattern: Variant = raw_definition.get("pattern", [])
				_check(raw_pattern is Array and raw_pattern.size() == 4,
					"each authored source holds a four-beat pattern")

	var parsed := _parsed()
	_check(parsed == _expected_definitions(),
		"the real parser accepts the file as the exact prescribed schedule")
	_check(parsed.size() == 2, "the parsed schedule has exactly two sources")
	_check(CombatEnemyIntents.new(parsed).is_valid(),
		"CombatEnemyIntents.is_valid() for the new authored JSON")

	# Each owned entry is located by its own enemy_position, never by list order.
	for position in [1, 2]:
		var matches: Array = []
		for entry in parsed:
			if entry is Dictionary and entry.get("enemy_position") == position:
				matches.append(entry)
		_check(matches.size() == 1, "exactly one parsed source at enemy_position %d" % position)
		if matches.size() == 1:
			var entry: Dictionary = matches[0]
			_check(entry.size() == 2 and entry.has("enemy_position") and entry.has("pattern"),
				"source %d holds exactly enemy_position and pattern" % position)
			var expected_pattern: Array = _expected_definitions()[position - 1]["pattern"]
			var pattern: Array = entry["pattern"]
			for beat in range(expected_pattern.size()):
				_check(pattern[beat] == expected_pattern[beat],
					"source %d beat %d is exactly the prescribed action" % [position, beat])

	# The loader normalizes every JSON whole number to a real int.
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

	# The named actors really exist with the stats this schedule is authored
	# against; no new enemy record is introduced.
	var roster := _load_catalog(ENEMIES_PATH)
	var guard := _record_by_id(roster, "button_guard")
	var ripper := _record_by_id(roster, "seam_ripper")
	_check(guard.get("name") == "Button Guard" and guard.get("max_hp") == 16,
		"shipped button_guard is Button Guard with 16 max HP")
	_check(ripper.get("name") == "Seam Ripper" and ripper.get("max_hp") == 18,
		"shipped seam_ripper is Seam Ripper with 18 max HP")
	_check(guard.get("art_path") == "res://assets/paper/enemies/button_guard.png",
		"shipped button_guard keeps its existing art path")
	_check(ripper.get("art_path") == "res://assets/paper/enemies/seam_ripper.png",
		"shipped seam_ripper keeps its existing art path")

	# The real starter party: Warden/Seamstress/Tinker at 40/30/26 HP.
	var party := _build_party()
	_check(party.is_valid(), "the shipped starter party builds a real three-hero party")
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("max_hp") == 40
		and party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("max_hp") == 30
		and party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("max_hp") == 26,
		"starter party is Warden/Seamstress/Tinker at 40/30/26 HP in positions 1/2/3")
	_check(party.get_hero(1).get("block") == 0 and party.get_hero(2).get("block") == 0
		and party.get_hero(3).get("block") == 0,
		"the isolated fixture starts every hero with zero Block")
	_check(party.get_hero(1).get("statuses", {}) == {}
		and party.get_hero(2).get("statuses", {}) == {}
		and party.get_hero(3).get("statuses", {}) == {},
		"the isolated fixture starts every hero without statuses")

	# The encounter is standalone: the shared typed pool does not register it,
	# so nothing claims live availability for it yet.
	_check(FileAccess.file_exists(TYPED_POOL_PATH),
		"the shared typed battle pool file exists, so its contents can be inspected")
	_check(_shared_pool() is Dictionary,
		"the shared typed battle pool parses as a real JSON object")
	_check(not _shared_pool_registers_encounter(),
		"this encounter stays out of the shared typed battle pool")

	# The authored bytes on disk are unchanged by every parser read.
	_check(_read_text(ENCOUNTER_PATH) == raw_text,
		"the authored encounter file bytes are unchanged after validation")


## AC1/AC3: the prior four-beat Buttonhole Holdout encounter still parses into
## a valid scheduler, independently of any Fight-pool total or ordering.
func _test_prior_encounter_intact() -> void:
	var text := _read_text(BUTTONHOLE_PATH)
	_check(FileAccess.file_exists(BUTTONHOLE_PATH), "the prior Buttonhole Holdout file exists")
	var parsed := RunFightEncounterSelection._parse_schedule_text(text)
	_check(parsed.size() == 2, "the prior encounter still parses into two sources")
	_check(CombatEnemyIntents.new(parsed).is_valid(),
		"the prior encounter still passes the real intent validator")
	var expected := [
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
	_check(parsed == expected, "the prior encounter keeps its exact authored actions")
	var scheduler := CombatEnemyIntents.new(parsed)
	var first := scheduler.get_intents()
	_check(first.size() == 2 and first[0].get("enemy_position") == 1
		and first[1].get("enemy_position") == 2,
		"the prior encounter still announces slot 1 before slot 2")
	_check(parsed != _parsed(), "the prior encounter is genuinely a different schedule")
	_check(_read_text(BUTTONHOLE_PATH) == text, "the prior encounter file bytes are unchanged")


## AC1: the announced intent sequence is deterministic, sorted, wrapped and
## detached from its caller after four explicit advances.
func _test_announcements() -> void:
	var authored_text := _read_text(ENCOUNTER_PATH)
	var definitions := _parsed()
	_check(definitions == _expected_definitions(),
		"the authored schedule loads for the scheduler")
	var pristine := definitions.duplicate(true)
	var scheduler := CombatEnemyIntents.new(definitions)
	_check(scheduler.is_valid(),
		"the authored schedule passes the real intent validator")
	if not scheduler.is_valid():
		return

	seed(RNG_SEED)
	var expected_global := randi()
	seed(RNG_SEED)
	var announced_timeline: Array = []
	for beat in range(5):
		var announced := scheduler.get_intents()
		announced_timeline.append(announced.duplicate(true))
		_check(announced == _expected_beat(beat),
			"beat %d announces the exact full authored pair" % beat)
		_check(announced.size() == 2, "beat %d announces one action per source" % beat)
		_check(_positions_of(announced) == [1, 2],
			"beat %d announces source slot 1 before source slot 2" % beat)
		# A caller that edits the returned snapshot cannot corrupt the schedule.
		announced[0]["amount"] = 900
		announced[0]["type"] = "invented"
		announced[1]["enemy_position"] = 3
		announced.append({"type": "block", "amount": 5, "enemy_position": 3})
		_check(scheduler.get_intents() == _expected_beat(beat),
			"beat %d caller mutation cannot corrupt the next announcement" % beat)
		if beat < 4:
			_check(scheduler.advance_turn(),
				"beat %d advances the schedule exactly one step" % beat)
	_check(randi() == expected_global,
		"constructing, viewing and advancing this schedule draws no global RNG")

	_check(announced_timeline.size() == 5 and announced_timeline[4] == announced_timeline[0],
		"after four advances the fifth announcement equals the first including enemy_position")
	_check(_positions_of(announced_timeline[4]) == [1, 2],
		"the wrapped announcement still lists source slot 1 then slot 2")

	# The scheduler owns a deep copy of the caller's definitions.
	var caller_owned := pristine.duplicate(true)
	var guarded := CombatEnemyIntents.new(caller_owned)
	caller_owned[0]["pattern"][0]["amount"] = 42
	caller_owned[1]["pattern"].clear()
	_check(guarded.is_valid() and guarded.get_intents() == _expected_beat(0),
		"mutating the caller-owned definitions cannot corrupt the scheduler")
	_check(definitions == pristine,
		"the parsed definitions are unchanged after the whole timeline")
	_check(_read_text(ENCOUNTER_PATH) == authored_text,
		"the authored file bytes are unchanged after the whole timeline")


## The complete four-beat trace with the real opening Block service applied
## exactly once, four isolated enemy phases and an explicit advance after each.
func _play_four_beats(label: String) -> Array:
	var party := _build_party()
	var enemies := _assemble_enemies()
	_check(party.is_valid() and party.get_heroes().size() == 3,
		label + ": the three-hero party is valid")
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2,
		label + ": the two-enemy roster is valid")
	if not party.is_valid() or not enemies.is_valid():
		return []
	_check_hero(party, 1, "warden", 40, 0, label + " before opening")
	_check_hero(party, 2, "seamstress", 30, 0, label + " before opening")
	_check_hero(party, 3, "tinker", 26, 0, label + " before opening")
	_check_enemy(enemies, 1, "button_guard", 16, 0, label + " before opening")
	_check_enemy(enemies, 2, "seam_ripper", 18, 0, label + " before opening")

	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), label + ": Warden receives the real opening Block exactly once")
	_check(not opening.apply(), label + ": the opening Block service cannot apply twice")
	_check_hero(party, 1, "warden", 40, 6, label + " opening")
	_check_hero(party, 2, "seamstress", 30, 0, label + " opening")
	_check_hero(party, 3, "tinker", 26, 0, label + " opening")

	var scheduler := CombatEnemyIntents.new(_parsed())
	_check(scheduler.is_valid(), label + ": the authored schedule instantiates")
	if not scheduler.is_valid():
		return []
	var initial_party := party.get_heroes()
	var initial_enemies := enemies.get_enemies()
	var trace: Array = []
	for beat in range(4):
		var intents := scheduler.get_intents()
		var untouched := intents.duplicate(true)
		_check(intents == _expected_beat(beat),
			label + ": beat %d exact announced pair" % (beat + 1))
		_check(_positions_of(intents) == [1, 2],
			label + ": beat %d announces slot 1 before slot 2" % (beat + 1))
		seed(RNG_SEED)
		var expected_rng := randi()
		seed(RNG_SEED)
		var result := phase.execute_phase(party, enemies, intents)
		_check(randi() == expected_rng, label + ": beat %d draws no global RNG" % (beat + 1))
		_check(result == {"ok": true, "events": _expected_events(beat)},
			label + ": beat %d resolves the exact ordered applied events" % (beat + 1))
		_check(intents == untouched and scheduler.get_intents() == _expected_beat(beat),
			label + ": beat %d neither mutates the intents nor advances the scheduler"
			% (beat + 1))
		var expected_heroes := _expected_party(initial_party, EXPECTED_HERO_HP[beat],
			EXPECTED_HERO_BLOCK[beat], EXPECTED_HERO_STATUSES[beat])
		var expected_roster := _expected_enemies(initial_enemies, EXPECTED_ENEMY_BLOCK[beat])
		_check(party.get_heroes() == expected_heroes,
			label + ": beat %d exact cumulative hero HP, Block and statuses" % (beat + 1))
		_check(enemies.get_enemies() == expected_roster,
			label + ": beat %d exact cumulative enemy HP and Block" % (beat + 1))
		trace.append({"intents": intents, "result": result,
			"party": party.get_heroes(), "enemies": enemies.get_enemies()})
		_check(scheduler.advance_turn(),
			label + ": the caller advances the scheduler once after beat %d" % (beat + 1))
	_check(scheduler.get_intents() == _expected_beat(0),
		label + ": the fifth announcement repeats the first pair after four advances")
	return trace


## AC2: one real opening Block grant, four isolated real CombatEnemyPhase
## calls, no player turn or status boundary, exact intermediate snapshots and
## an identical replay from fresh fixtures.
func _test_real_four_phases() -> void:
	var run_rng := RandomNumberGenerator.new()
	run_rng.seed = RNG_SEED
	var run_state := run_rng.state
	var first := _play_four_beats("AC2 first")
	_check(run_rng.state == run_state,
		"AC2: the seeded run RNG is untouched by the schedule and the phases")
	var replay := _play_four_beats("AC2 replay")
	_check(run_rng.state == run_state,
		"AC2: the seeded run RNG is still untouched after the replay")
	_check(first.size() == 4 and replay.size() == 4 and first == replay,
		"AC2: four complete beats replay identically from fresh fixtures")
	if first.size() != 4:
		return

	# Literal per-beat states, so two equally broken runs cannot satisfy the
	# comparison above.
	for beat in range(4):
		_check(first[beat]["result"]["events"] == _expected_events(beat),
			"AC2: beat %d carries exactly its two applied events in source order" % (beat + 1))
		_check(first[beat]["party"][0]["id"] == "warden"
			and first[beat]["party"][0]["hp"] == EXPECTED_HERO_HP[beat][0]
			and first[beat]["party"][0]["block"] == EXPECTED_HERO_BLOCK[beat][0],
			"AC2: beat %d leaves the Warden at the authored HP and Block" % (beat + 1))
		_check(first[beat]["party"][1]["id"] == "seamstress"
			and first[beat]["party"][1]["hp"] == EXPECTED_HERO_HP[beat][1],
			"AC2: beat %d leaves the Seamstress at the authored HP" % (beat + 1))
		_check(first[beat]["party"][2]["id"] == "tinker"
			and first[beat]["party"][2]["hp"] == EXPECTED_HERO_HP[beat][2],
			"AC2: beat %d leaves Tinker at the authored HP" % (beat + 1))
		_check(first[beat]["enemies"][0]["id"] == "button_guard"
			and first[beat]["enemies"][0]["hp"] == 16
			and first[beat]["enemies"][0]["block"] == EXPECTED_ENEMY_BLOCK[beat][0],
			"AC2: beat %d leaves the Button Guard at 16 HP and the authored Block" % (beat + 1))
		_check(first[beat]["enemies"][1]["id"] == "seam_ripper"
			and first[beat]["enemies"][1]["hp"] == 18
			and first[beat]["enemies"][1]["block"] == EXPECTED_ENEMY_BLOCK[beat][1],
			"AC2: beat %d leaves the Seam Ripper at 18 HP and the authored Block" % (beat + 1))

	# Beat 1: Guard Block 4 and a real 5-damage strike on Tinker.
	_check_hero_snapshot(first[0]["party"], 1, "warden", 40, 6, "AC2 beat 1")
	_check_hero_snapshot(first[0]["party"], 2, "seamstress", 30, 0, "AC2 beat 1")
	_check_hero_snapshot(first[0]["party"], 3, "tinker", 21, 0, "AC2 beat 1")

	# Beat 2: Guard Exposes Warden BEFORE the Ripper's 4 becomes floor(4*1.5)=6,
	# which exactly consumes his opening 6 Block.
	_check(CombatStatuses.new().adjusted_attack_damage(4, {}, {"exposed": 1}) == 6,
		"AC2: Exposed 1 turns the authored base 4 strike into exactly 6")
	_check(first[1]["party"][0]["hp"] == 40 and first[1]["party"][0]["block"] == 0
		and first[1]["party"][0].get("statuses", {}) == {"exposed": 1},
		"AC2: beat 2 leaves Warden at 40 HP with Exposed 1 and his 6 Block exactly consumed")
	_check(first[1]["party"][1]["hp"] == 30 and first[1]["party"][2]["hp"] == 21,
		"AC2: the Exposed-amplified strike hits only the Warden")

	# Beat 3: Guard strikes the Seamstress for 3 and the Ripper Weakens Tinker.
	_check_hero_snapshot(first[2]["party"], 2, "seamstress", 27, 0, "AC2 beat 3")
	_check(first[2]["party"][2].get("statuses", {}) == {"weak": 1},
		"AC2: beat 3 puts Weak 1 on Tinker")
	_check(first[2]["party"][0].get("statuses", {}) == {"exposed": 1},
		"AC2: no status tick runs between the isolated enemy phases")

	# Beat 4: Guard buffs his own Block 4 -> 6 and the Ripper Bleeds Seamstress.
	_check_enemy_snapshot(first[3]["enemies"], 1, "button_guard", 16, 6, "AC2 beat 4")
	_check(first[3]["party"][1].get("statuses", {}) == {"bleed": 2},
		"AC2: beat 4 puts Bleed 2 on the Seamstress with no Bleed tick applied")
	_check(first[3]["party"][2].get("statuses", {}) == {"weak": 1},
		"AC2: Tinker keeps Weak 1 through the isolated phases")
	_check(first[3]["party"][0].get("statuses", {}) == {"exposed": 1},
		"AC2: Warden keeps Exposed 1 through the isolated phases")


## AC3: a genuinely legal seed-4103 opening Fight, the test-local one-entry
## pool selected and cached through the real services without extra RNG, and a
## real typed roster of the two named enemies.
func _test_typed_selection_and_roster() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = MAP_SEED
	var map := RunMap.new()
	_check(map.generate(rng), "AC3: the seeded run map generates")
	var fight_id := ""
	for candidate in map.get_legal_choices():
		if map.get_node(candidate).get("type") == "Fight":
			fight_id = candidate
			break
	_check(not fight_id.is_empty() and map.get_legal_choices().has(fight_id),
		"AC3: the generated map offers a genuine legal opening Fight")
	if fight_id.is_empty():
		return
	_check(map.choose_node(fight_id), "AC3: the route chooses that opening Fight")
	_check(map.get_current_node_id() == fight_id and map.get_current_floor() == 1
		and map.get_node(fight_id).get("type") == "Fight",
		"AC3: the chosen current node really is a first-floor Fight")

	var picker := RunFightEncounterSelection.new()
	var pool := {"Fight": {ENCOUNTER_ID: ENCOUNTER_PATH}}
	var choice := picker.select_current_battle(map, rng, pool)
	_check(choice.get("success") == true and choice.get("node_type") == "Fight"
		and choice.get("encounter_id") == ENCOUNTER_ID
		and choice.get("definitions") == _expected_definitions(),
		"AC3: typed selection picks this encounter and its complete JSON")
	if not choice.get("success", false):
		return
	_check(CombatEnemyIntents.new(choice.get("definitions", [])).is_valid(),
		"AC3: the selected definitions instantiate a real valid scheduler")
	var state_after_first := rng.state
	var before_cache := choice.duplicate(true)

	# The cached result is returned again with no further RNG draw.
	var cached := picker.select_current_battle(map, rng, {"Fight": {}})
	_check(cached == before_cache and cached.get("encounter_id") == ENCOUNTER_ID
		and cached.get("definitions") == _expected_definitions(),
		"AC3: the cached ID and definitions are returned again from the same node")
	_check(rng.state == state_after_first,
		"AC3: reading the cached selection consumes no additional RNG")

	# A caller cannot corrupt the cache or consume RNG by mutating its copy.
	choice["definitions"][0]["pattern"][0]["amount"] = 900
	choice["definitions"][0]["pattern"][0]["type"] = "invented"
	choice["encounter_id"] = "mutated"
	_check(picker.select_current_battle(map, rng, pool) == before_cache,
		"AC3: caller mutation cannot affect later cached reads")
	_check(rng.state == state_after_first,
		"AC3: mutating and re-reading the cached result consumes zero RNG")

	# The real typed roster bridge binds the two named run enemies in order.
	var roster_snapshot := LOCAL_ROSTER_MAP.duplicate(true)
	var assembled := RunTypedBattleRoster.new().assemble(
		before_cache, LOCAL_ROSTER_MAP.duplicate(true), [ENEMIES_PATH])
	_check(assembled.get("ok") == true and assembled.get("node_type") == "Fight"
		and assembled.get("encounter_id") == ENCOUNTER_ID
		and assembled.get("definitions") == _expected_definitions(),
		"AC3: RunTypedBattleRoster assembles the exact selected Fight choice")
	var enemies: Variant = assembled.get("enemies")
	_check(enemies is CombatEnemies and enemies.is_valid(),
		"AC3: the assembled roster is a valid CombatEnemies instance")
	if enemies is CombatEnemies:
		_check(enemies.get_enemies().size() == 2,
			"AC3: the assembled roster holds exactly two slots")
		var slot_1: Dictionary = enemies.get_enemy(1)
		var slot_2: Dictionary = enemies.get_enemy(2)
		_check(slot_1.get("id") == "button_guard" and slot_1.get("name") == "Button Guard"
			and slot_1.get("position") == 1 and slot_1.get("max_hp") == 16
			and slot_1.get("hp") == 16 and slot_1.get("block") == 0,
			"AC3: assembled slot 1 is Button Guard at 16/16 HP with 0 Block")
		_check(slot_2.get("id") == "seam_ripper" and slot_2.get("name") == "Seam Ripper"
			and slot_2.get("position") == 2 and slot_2.get("max_hp") == 18
			and slot_2.get("hp") == 18 and slot_2.get("block") == 0,
			"AC3: assembled slot 2 is Seam Ripper at 18/18 HP with 0 Block")
		_check(slot_1.get("art_path") == "res://assets/paper/enemies/button_guard.png"
			and slot_2.get("art_path") == "res://assets/paper/enemies/seam_ripper.png",
			"AC3: the assembled roster keeps the existing enemy art paths")
	_check(LOCAL_ROSTER_MAP == roster_snapshot,
		"AC3: roster assembly does not mutate the test-local binding")
	_check(rng.state == state_after_first,
		"AC3: roster assembly consumes no run RNG")
	_check(map.get_current_node_id() == fight_id and map.get_route() == [fight_id],
		"AC3: selection and assembly never advance the route")

	# Still standalone: the live shared pool must not publish this fight yet.
	_check(not _shared_pool_registers_encounter(),
		"AC3: the new fight is not published to the live Fight pool")


## AC3: with the Seamstress downed at 0 HP, the fourth beat stages the Guard's
## legal self-buff and then the Ripper's illegal Bleed, so the whole real phase
## fails closed without publishing anything.
func _test_fail_closed_fourth_beat() -> void:
	# Control: the Guard's opening action really is legal on a fresh roster.
	var control_party := _build_party()
	var control_enemies := _assemble_enemies()
	var control_heroes := control_party.get_heroes()
	var buff_control := phase.execute_phase(control_party, control_enemies,
		[{"type": "buff", "enemy_position": 1, "amount": 2}])
	_check(buff_control == {"ok": true,
		"events": [{"type": "buff", "enemy_position": 1, "applied": true}]},
		"AC3 control: the fourth-beat Guard self-buff is a legal first action")
	_check(control_party.get_heroes() == control_heroes
		and control_enemies.get_enemy(1).get("block") == 2,
		"AC3 control: the legal self-buff alone really grants 2 Block")

	var party := _build_party()
	var enemies := _assemble_enemies()
	_check(party.apply_damage(2, 30) and party.is_downed(2)
		and party.get_hero(2).get("hp") == 0,
		"AC3 negative: the Seamstress is really downed at 0 HP")
	_check(not enemies.is_slain(1) and not enemies.is_slain(2),
		"AC3 negative: both enemy sources are still alive")
	var scheduler := CombatEnemyIntents.new(_parsed())
	_check(scheduler.is_valid(),
		"AC3 negative: the authored schedule instantiates for the fourth beat")
	if not scheduler.is_valid():
		return
	for step in range(3):
		_check(scheduler.advance_turn(),
			"AC3 negative: advance to beat %d" % (step + 2))
	var intents := scheduler.get_intents()
	_check(intents == _expected_beat(3),
		"AC3 negative: the fourth beat announces the Guard buff then the Ripper Bleed")
	_check(_positions_of(intents) == [1, 2],
		"AC3 negative: the fourth beat lists the Guard before the Ripper")
	if intents != _expected_beat(3):
		return
	var before_party := party.get_heroes()
	var before_enemies := enemies.get_enemies()
	var intents_snapshot := intents.duplicate(true)
	var result := phase.execute_phase(party, enemies, intents)
	_check(result == {"ok": false, "events": []},
		"AC3 negative: the Bleed on the downed Seamstress rejects the whole phase")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"AC3 negative: no authoritative hero or enemy HP, Block, status, position or record changes")
	_check(party.get_hero(2).get("hp") == 0
		and party.get_hero(2).get("statuses", {}) == {},
		"AC3 negative: the downed Seamstress receives no Bleed")
	_check(enemies.get_enemy(1).get("block") == 0,
		"AC3 negative: the Guard's staged +2 Block is rolled back")
	_check(party.is_downed(2) and party.get_hero(1).get("statuses", {}) == {}
		and party.get_hero(3).get("statuses", {}) == {},
		"AC3 negative: no other hero is touched by the rejected phase")
	_check(intents == intents_snapshot and scheduler.get_intents() == _expected_beat(3),
		"AC3 negative: the rejected phase neither mutates nor advances the scheduler")
