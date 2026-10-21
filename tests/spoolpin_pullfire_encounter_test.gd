extends SceneTree

## Deterministic headless coverage for the authored Spoolpin Pullfire encounter:
## slot 1 Spool Stalker shoves the middle hero backwards before slot 2 Seam
## Ripper strikes the displaced rear hero for 4 raw damage.
## Data/service only: this file never registers the encounter in the shared
## typed pool and never wires it into live play.

const ENCOUNTER_PATH := "res://data/encounters/spoolpin_pullfire.json"
const ENCOUNTER_ID := "spoolpin_pullfire"
const HERO_CATALOG_PATH := "res://data/heroes/starter_party.json"
const ENEMY_CATALOG_PATH := "res://data/enemies/run_enemies.json"
const TYPED_POOL_PATH := "res://data/encounters/m03_typed_battle_pools.json"
const COMPANION_PATH := "res://data/encounters/rearline_needlemark.json"
const RNG_SEED := 20261023
const MAP_SEED := 88231

## This encounter's own typed roster binding, owned by this test: slot 1 is the
## Spool Stalker and slot 2 the Seam Ripper, in that order.
const LOCAL_ROSTER_MAP := {
	ENCOUNTER_ID: ["spool_stalker", "seam_ripper"],
}

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_authored_schedule_and_parser()
	_test_typed_roster_assembly()
	_test_intent_cycle()
	_test_real_beat_one()
	_test_real_beats_two_and_three()
	_test_replay_determinism()
	_test_negative_fail_closed()
	if failures.is_empty():
		print("spoolpin_pullfire_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("spoolpin_pullfire_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "expected file to open: " + path)
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
			{"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
			{"type": "block", "amount": 2},
			{"type": "attack", "amount": 3, "target_position": 1}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 4, "target_position": 3},
			{"type": "debuff", "amount": 1, "target_position": 2, "status": "weak"},
			{"type": "buff", "amount": 2}]},
	]


## Literal announced beats, independent of the parsed file and of the schedule.
func _expected_beat_1() -> Array:
	return [
		{"type": "shove", "amount": 0, "target_position": 2, "direction": 1, "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 3, "enemy_position": 2}]


func _expected_beat_2() -> Array:
	return [
		{"type": "block", "amount": 2, "enemy_position": 1},
		{"type": "debuff", "amount": 1, "target_position": 2, "status": "weak", "enemy_position": 2}]


func _expected_beat_3() -> Array:
	return [
		{"type": "attack", "amount": 3, "target_position": 1, "enemy_position": 1},
		{"type": "buff", "amount": 2, "enemy_position": 2}]


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


func _expected_beat(beat: int) -> Array:
	var actions: Array = []
	for definition in _expected_definitions():
		var pattern: Array = definition["pattern"]
		var action: Dictionary = pattern[beat % pattern.size()].duplicate(true)
		action["enemy_position"] = definition["enemy_position"]
		actions.append(action)
	return actions


func _build_party() -> CombatParty:
	var heroes := _load_catalog(HERO_CATALOG_PATH)
	var definitions: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		definitions.append(_record_by_id(heroes, id))
	return CombatParty.new(definitions)


## The real two-enemy roster, assembled from this encounter's own typed roster
## map and the shipped run_enemies.json catalog.
func _assemble_enemies() -> CombatEnemies:
	var typed_choice := {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": _parsed().duplicate(true),
	}
	var assembled := RunTypedBattleRoster.new().assemble(
		typed_choice, LOCAL_ROSTER_MAP.duplicate(true), [ENEMY_CATALOG_PATH])
	_check(assembled.get("ok") == true, "the typed roster assembles this encounter's two enemies")
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


## AC1: the shipped file is exactly the prescribed two-source, three-beat
## schedule, and the two named enemies already exist in the shipped catalog.
func _test_authored_schedule_and_parser() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "the authored encounter file exists")
	_check(ENCOUNTER_PATH.get_file().get_basename() == ENCOUNTER_ID,
		"the schedule file name carries the canonical encounter ID %s" % ENCOUNTER_ID)

	var raw: Variant = JSON.parse_string(_read_text(ENCOUNTER_PATH))
	_check(raw is Array and raw.size() == 2,
		"the authored file holds exactly this encounter's two source records")
	if raw is Array:
		for raw_definition in raw:
			_check(raw_definition is Dictionary and raw_definition.size() == 2
				and raw_definition.has("enemy_position") and raw_definition.has("pattern"),
				"each authored source holds exactly enemy_position and pattern")
			if raw_definition is Dictionary:
				var raw_pattern: Variant = raw_definition.get("pattern", [])
				_check(raw_pattern is Array and raw_pattern.size() == 3,
					"each authored source holds a three-beat pattern")

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
			_check(entry.get("pattern") == _expected_definitions()[position - 1]["pattern"],
				"source %d is exactly the prescribed three-beat pattern" % position)

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
			if action.has("direction"):
				_check(action.get("direction") is int,
					"parsed beat direction is an int, not a JSON float")

	# The named actors really exist with the stats and art paths this
	# schedule is authored against; no new enemy record is introduced.
	var roster := _load_catalog(ENEMY_CATALOG_PATH)
	var stalker := _record_by_id(roster, "spool_stalker")
	var ripper := _record_by_id(roster, "seam_ripper")
	_check(stalker.get("name") == "Spool Stalker" and stalker.get("max_hp") == 14,
		"shipped spool_stalker is Spool Stalker with 14 max HP")
	_check(ripper.get("name") == "Seam Ripper" and ripper.get("max_hp") == 18,
		"shipped seam_ripper is Seam Ripper with 18 max HP")
	_check(stalker.get("art_path") == "res://assets/paper/enemies/spool_stalker.png",
		"shipped spool_stalker keeps its existing art path")
	_check(ripper.get("art_path") == "res://assets/paper/enemies/seam_ripper.png",
		"shipped seam_ripper keeps its existing art path")

	# The real starter party: Warden/Seamstress/Tinker at 40/30/26 HP.
	var party := _build_party()
	_check(party.is_valid(), "the shipped starter party builds a real three-hero party")
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("max_hp") == 40
		and party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("max_hp") == 30
		and party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("max_hp") == 26,
		"starter party is Warden/Seamstress/Tinker at 40/30/26 HP in positions 1/2/3")

	# The real loader picks this authored file up from a canonical path.
	var map := RunMap.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = MAP_SEED
	_check(map.generate(rng), "a real run map generates for the loader check")
	var fight_id := ""
	for candidate in map.get_legal_choices():
		if map.get_node(candidate).get("type") == "Fight":
			fight_id = candidate
			break
	_check(not fight_id.is_empty(), "the generated map offers a legal opening Fight")
	if not fight_id.is_empty():
		_check(map.choose_node(fight_id), "the route chooses the opening Fight")
		var choice := RunFightEncounterSelection.new().select_current_fight(
			map, rng, {ENCOUNTER_ID: ENCOUNTER_PATH})
		_check(choice.get("success") == true
			and choice.get("encounter_id") == ENCOUNTER_ID
			and choice.get("definitions") == _expected_definitions(),
			"the real Fight loader returns this encounter's exact authored schedule")

	# The encounter is standalone: it is not registered in the shared typed pool.
	_check(FileAccess.file_exists(TYPED_POOL_PATH),
		"the shared typed battle pool file exists, so its contents can be inspected")
	_check(not _shared_pool_registers_encounter(),
		"this encounter stays out of the shared typed battle pool")

	# An earlier named schedule still parses by its own data.
	var companion := RunFightEncounterSelection._parse_schedule_text(_read_text(COMPANION_PATH))
	_check(CombatEnemyIntents.new(companion).is_valid(),
		"the earlier rearline_needlemark schedule still parses and validates")
	_check(companion != parsed,
		"the new schedule differs from the earlier rearline_needlemark schedule")


## True only when the shared typed pool file registers this encounter.
func _shared_pool_registers_encounter() -> bool:
	var file := FileAccess.open(TYPED_POOL_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
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


## AC1: the real typed roster bridge binds this encounter's two named enemies.
func _test_typed_roster_assembly() -> void:
	var typed_choice := {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": _parsed().duplicate(true),
	}
	var choice_snapshot := typed_choice.duplicate(true)
	var roster_map_snapshot := LOCAL_ROSTER_MAP.duplicate(true)
	var assembled := RunTypedBattleRoster.new().assemble(
		typed_choice, LOCAL_ROSTER_MAP.duplicate(true), [ENEMY_CATALOG_PATH])
	_check(typed_choice == choice_snapshot,
		"RunTypedBattleRoster.assemble must not mutate the caller's typed choice")
	_check(LOCAL_ROSTER_MAP == roster_map_snapshot,
		"RunTypedBattleRoster.assemble must not mutate the caller's roster map")
	_check(assembled.get("ok") == true
		and assembled.get("node_type") == "Fight"
		and assembled.get("encounter_id") == ENCOUNTER_ID
		and assembled.get("definitions") == _expected_definitions(),
		"the typed Fight choice assembles with Fight node_type and the exact definitions")
	var enemies: Variant = assembled.get("enemies")
	_check(enemies is CombatEnemies and enemies.is_valid(),
		"the assembled roster is a valid CombatEnemies instance")
	if enemies is CombatEnemies:
		_check(enemies.get_enemies().size() == 2, "the assembled roster holds exactly two slots")
		var slot_1: Dictionary = enemies.get_enemy(1)
		var slot_2: Dictionary = enemies.get_enemy(2)
		_check(slot_1.get("id") == "spool_stalker" and slot_1.get("name") == "Spool Stalker"
			and slot_1.get("position") == 1 and slot_1.get("max_hp") == 14
			and slot_1.get("hp") == 14 and slot_1.get("block") == 0,
			"assembled slot 1 is Spool Stalker at 14/14 HP with 0 Block")
		_check(slot_2.get("id") == "seam_ripper" and slot_2.get("name") == "Seam Ripper"
			and slot_2.get("position") == 2 and slot_2.get("max_hp") == 18
			and slot_2.get("hp") == 18 and slot_2.get("block") == 0,
			"assembled slot 2 is Seam Ripper at 18/18 HP with 0 Block")
		_check(slot_1.get("art_path") == "res://assets/paper/enemies/spool_stalker.png"
			and slot_2.get("art_path") == "res://assets/paper/enemies/seam_ripper.png",
			"the assembled roster keeps the existing enemy art paths")

	# The roster binding is owned by this encounter's own map, not inherited
	# from another encounter: swapping the IDs swaps the slots.
	var swapped := RunTypedBattleRoster.new().assemble(
		typed_choice.duplicate(true), {ENCOUNTER_ID: ["seam_ripper", "spool_stalker"]},
		[ENEMY_CATALOG_PATH])
	_check(swapped.get("ok") == true,
		"an explicitly swapped roster binding still assembles")
	if swapped.get("ok") == true:
		var swapped_enemies: Variant = swapped.get("enemies")
		if swapped_enemies is CombatEnemies:
			var swapped_1: Dictionary = swapped_enemies.get_enemy(1)
			var swapped_2: Dictionary = swapped_enemies.get_enemy(2)
			_check(swapped_1.get("id") == "seam_ripper"
				and swapped_2.get("id") == "spool_stalker",
				"the roster map, not the schedule, owns the slot-to-enemy binding")

	# Negative roster assembly: mismatched count, duplicate IDs, unknown ID.
	var bridge := RunTypedBattleRoster.new()
	_check(bridge.assemble(typed_choice, {ENCOUNTER_ID: ["spool_stalker"]}, [ENEMY_CATALOG_PATH])
		== {"ok": false},
		"a one-enemy roster for this two-source encounter is rejected")
	_check(bridge.assemble(typed_choice,
		{ENCOUNTER_ID: ["spool_stalker", "spool_stalker"]}, [ENEMY_CATALOG_PATH])
		== {"ok": false},
		"a duplicate enemy ID in the roster is rejected")
	_check(bridge.assemble(typed_choice,
		{ENCOUNTER_ID: ["spool_stalker", "unknown_enemy"]}, [ENEMY_CATALOG_PATH])
		== {"ok": false},
		"an unknown enemy ID in the roster is rejected")
	_check(bridge.assemble(typed_choice, {}, [ENEMY_CATALOG_PATH]) == {"ok": false},
		"a missing roster binding for this encounter is rejected")


## AC1/AC3: three announced beats in ascending source order, then an exact
## repeat, with no global RNG consumption and no aliasing of caller data.
func _test_intent_cycle() -> void:
	var definitions := _parsed()
	var intents := CombatEnemyIntents.new(definitions)
	for beat in range(3):
		_check(intents.get_intents() == _expected_beat(beat),
			"beat %d announces the exact authored actions" % (beat + 1))
		_check(intents.advance_turn(), "advance to beat %d" % (beat + 2))
	_check(intents.get_intents() == _expected_beat(0),
		"beat 4 repeats the first announced intents exactly")

	for beat in range(4):
		var announced := intents.get_intents()
		_check(announced.size() == 2
			and announced[0].get("enemy_position") == 1
			and announced[1].get("enemy_position") == 2,
			"announcement %d lists slot 1 then slot 2" % (beat + 1))
		intents.advance_turn()

	# The whole fixed cycle, viewed and advanced, draws no global RNG.
	seed(RNG_SEED)
	var baseline := randi()
	seed(RNG_SEED)
	var probe := CombatEnemyIntents.new(definitions)
	for turn in range(7):
		probe.get_intents()
		probe.advance_turn()
	_check(randi() == baseline,
		"constructing, viewing and advancing this schedule draws no global RNG")
	seed(RNG_SEED)
	var without_extra := randi()
	seed(RNG_SEED)
	randi()
	_check(randi() != without_extra, "the global RNG probe detects an injected extra draw")

	# Returned announcements and the parsed source cannot alias the selector.
	var snapshot_selector := CombatEnemyIntents.new(_expected_definitions().duplicate(true))
	var snapshot := snapshot_selector.get_intents()
	_check(snapshot == _expected_beat_1(), "a detached announcement is the exact first beats")
	snapshot[0]["amount"] = 99
	snapshot[0]["type"] = "block"
	snapshot.append({"enemy_position": 3, "type": "block", "amount": 5})
	_check(snapshot_selector.get_intents() == _expected_beat_1(),
		"mutating a returned announcement cannot alter later intents")
	_check(definitions == _expected_definitions(), "the parsed schedule keeps its prescribed source")
	var isolated := CombatEnemyIntents.new(definitions)
	var parsed_pattern: Array = definitions[0]["pattern"]
	parsed_pattern[0]["amount"] = 7
	_check(isolated.get_intents() == _expected_beat_1(),
		"mutating the parsed source cannot alter an independently built selector")


## AC2: beat 1 shoves the living middle hero back and the rear strike then
## hits that displaced hero for exactly 4 raw damage with zero Block.
func _test_real_beat_one() -> void:
	var party := _build_party()
	_check(party.is_valid(), "the authored party is valid")
	var enemies := _assemble_enemies()
	_check(enemies.is_valid(), "the assembled two-enemy roster is valid")
	_check_hero(party, 1, "warden", 40, 0, "start")
	_check_hero(party, 2, "seamstress", 30, 0, "start")
	_check_hero(party, 3, "tinker", 26, 0, "start")
	_check_enemy(enemies, 1, "spool_stalker", 14, 0, "start")
	_check_enemy(enemies, 2, "seam_ripper", 18, 0, "start")

	var scheduler := CombatEnemyIntents.new(_parsed())
	var phase := CombatEnemyPhase.new()
	var announced := scheduler.get_intents()
	_check(announced == _expected_beat_1(),
		"beat 1 announces the slot-1 shove before the slot-2 attack")

	seed(RNG_SEED)
	var expected_rng := randi()
	seed(RNG_SEED)
	var result := phase.execute_phase(party, enemies, announced)
	_check(randi() == expected_rng, "beat 1 draws no global RNG")
	_check(result == {"ok": true, "events": _expected_events(0)},
		"beat 1 resolves the slot-1 shove then the slot-2 attack, in that order")

	# The shove displaces the Seamstress to the rear; the middle is now Tinker.
	_check_hero(party, 1, "warden", 40, 0, "beat 1")
	_check_hero(party, 2, "tinker", 26, 0, "beat 1")
	_check_hero(party, 3, "seamstress", 26, 0, "beat 1")
	_check(party.get_hero(3).get("max_hp") == 30,
		"the displaced Seamstress keeps its own 30 max HP")
	_check(party.get_hero(2).get("statuses", {}) == {}
		and party.get_hero(3).get("statuses", {}) == {},
		"beat 1 tags no hero with a status")
	_check(party.get_hero(2).get("name") == "Tinker"
		and party.get_hero(3).get("name") == "Seamstress",
		"the swap keeps each hero's own identity")
	_check(party.get_hero(2).get("art_path") == "res://assets/paper/heroes/tinker.png"
		and party.get_hero(3).get("art_path") == "res://assets/paper/heroes/seamstress.png",
		"the swap keeps each hero's own art path")
	_check_enemy(enemies, 1, "spool_stalker", 14, 0, "beat 1")
	_check_enemy(enemies, 2, "seam_ripper", 18, 0, "beat 1")


## AC3: beat 2 blocks for the front enemy and tags the current middle hero
## with Weak; beat 3 pressures the front hero and buffs the rear enemy.
func _test_real_beats_two_and_three() -> void:
	var party := _build_party()
	var enemies := _assemble_enemies()
	var scheduler := CombatEnemyIntents.new(_parsed())
	var phase := CombatEnemyPhase.new()

	# Reach beat 2 through the real beat 1.
	var beat_1 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(beat_1 == {"ok": true, "events": _expected_events(0)}, "beat 1 succeeds")
	_check(scheduler.advance_turn(), "advance to beat 2")

	seed(RNG_SEED)
	var expected_rng := randi()
	seed(RNG_SEED)
	var beat_2_announced := scheduler.get_intents()
	_check(beat_2_announced == _expected_beat_2(),
		"beat 2 announces slot-1 Block 2 and slot-2 Weak 1 on the middle position")
	var beat_2 := phase.execute_phase(party, enemies, beat_2_announced)
	_check(randi() == expected_rng, "beat 2 draws no global RNG")
	_check(beat_2 == {"ok": true, "events": _expected_events(1)},
		"beat 2 resolves the slot-1 Block then the slot-2 Weak, in that order")
	_check_hero(party, 1, "warden", 40, 0, "beat 2")
	_check_hero(party, 2, "tinker", 26, 0, "beat 2")
	_check_hero(party, 3, "seamstress", 26, 0, "beat 2")
	_check(party.get_hero(2).get("statuses", {}) == {"weak": 1},
		"beat 2 tags the hero now in the middle with Weak 1")
	_check(party.get_hero(1).get("statuses", {}) == {}
		and party.get_hero(3).get("statuses", {}) == {},
		"beat 2 tags no other hero")
	_check_enemy(enemies, 1, "spool_stalker", 14, 2, "beat 2")
	_check_enemy(enemies, 2, "seam_ripper", 18, 0, "beat 2")

	_check(scheduler.advance_turn(), "advance to beat 3")
	seed(RNG_SEED)
	expected_rng = randi()
	seed(RNG_SEED)
	var beat_3_announced := scheduler.get_intents()
	_check(beat_3_announced == _expected_beat_3(),
		"beat 3 announces slot-1 attack 3 on the front and slot-2 self-buff 2")
	var beat_3 := phase.execute_phase(party, enemies, beat_3_announced)
	_check(randi() == expected_rng, "beat 3 draws no global RNG")
	_check(beat_3 == {"ok": true, "events": _expected_events(2)},
		"beat 3 resolves the slot-1 attack then the slot-2 buff, in that order")
	_check_hero(party, 1, "warden", 37, 0, "beat 3")
	_check_hero(party, 2, "tinker", 26, 0, "beat 3")
	_check_hero(party, 3, "seamstress", 26, 0, "beat 3")
	_check(party.get_hero(2).get("statuses", {}) == {"weak": 1},
		"beat 3 keeps the Weak 1 tag: an enemy phase does not age statuses")
	_check_enemy(enemies, 1, "spool_stalker", 14, 2, "beat 3")
	_check_enemy(enemies, 2, "seam_ripper", 18, 2, "beat 3")

	# Weak 1 really reduces outgoing damage while it is active.
	_check(CombatStatuses.new().adjusted_attack_damage(8,
		party.get_hero(2).get("statuses", {}), {}) == 6,
		"Weak 1 reduces 8 outgoing damage to 6 while active")

	_check(scheduler.advance_turn(), "advance past the third beat")
	_check(scheduler.get_intents() == _expected_beat(0),
		"after exactly three advances the schedule announces its first intents again")


## AC3: two independently initialized copies of the same authored data agree in
## every event and every surviving field over the whole three-beat timeline.
func _play_three_beats() -> Dictionary:
	var party := _build_party()
	var enemies := _assemble_enemies()
	var scheduler := CombatEnemyIntents.new(_parsed())
	var phase := CombatEnemyPhase.new()
	var announced: Array = []
	var events: Array = []
	var hero_snapshots: Array = []
	var enemy_snapshots: Array = []
	for beat in range(3):
		announced.append(scheduler.get_intents().duplicate(true))
		events.append(phase.execute_phase(party, enemies, scheduler.get_intents()))
		hero_snapshots.append(party.get_heroes().duplicate(true))
		enemy_snapshots.append(enemies.get_enemies().duplicate(true))
		_check(scheduler.advance_turn(), "replay advance after beat %d" % (beat + 1))
	return {"announced": announced, "events": events,
		"hero_snapshots": hero_snapshots, "enemy_snapshots": enemy_snapshots,
		"heroes": party.get_heroes(), "enemies": enemies.get_enemies(),
		"repeating": scheduler.get_intents()}


func _test_replay_determinism() -> void:
	seed(RNG_SEED)
	var expected_rng := randi()
	seed(RNG_SEED)
	var first := _play_three_beats()
	_check(randi() == expected_rng, "three real enemy phases draw no global RNG")
	var second := _play_three_beats()

	_check(first["announced"].size() == 3 and second["announced"].size() == 3,
		"each replay announced exactly three beats")
	_check(first["announced"][0] == _expected_beat_1()
		and first["announced"][1] == _expected_beat_2()
		and first["announced"][2] == _expected_beat_3(),
		"the replay announces the exact first, second and third beats")
	_check(first["events"][0].get("events") == _expected_events(0)
		and first["events"][1].get("events") == _expected_events(1)
		and first["events"][2].get("events") == _expected_events(2),
		"the replay resolves the exact first, second and third beat events")

	# A literal end state, so two equally broken runs cannot satisfy the
	# comparison below.
	_check(first["heroes"].size() == 3 and first["enemies"].size() == 2,
		"the replay ends with the complete authored formation")
	_check(first["heroes"][0]["id"] == "warden" and first["heroes"][0]["hp"] == 37
		and first["heroes"][0]["block"] == 0,
		"the replay ends with the Warden at the front, 37 HP and 0 Block")
	_check(first["heroes"][1]["id"] == "tinker" and first["heroes"][1]["hp"] == 26
		and first["heroes"][1]["block"] == 0
		and first["heroes"][1].get("statuses", {}) == {"weak": 1},
		"the replay ends with Tinker in the middle, 26 HP, 0 Block and Weak 1")
	_check(first["heroes"][2]["id"] == "seamstress" and first["heroes"][2]["hp"] == 26
		and first["heroes"][2]["block"] == 0,
		"the replay ends with the Seamstress at the rear, 26 HP and 0 Block")
	_check(first["enemies"][0]["id"] == "spool_stalker" and first["enemies"][0]["hp"] == 14
		and first["enemies"][0]["block"] == 2,
		"the replay ends with the Spool Stalker at 14 HP and 2 Block")
	_check(first["enemies"][1]["id"] == "seam_ripper" and first["enemies"][1]["hp"] == 18
		and first["enemies"][1]["block"] == 2,
		"the replay ends with the Seam Ripper at 18 HP and 2 Block")
	_check(first["repeating"] == _expected_beat(0)
		and second["repeating"] == _expected_beat(0),
		"both copies return to the first announced intents on beat 4")
	_check(first["events"] == second["events"],
		"two independently initialized copies produce identical phase results")
	_check(first["hero_snapshots"] == second["hero_snapshots"]
		and first["enemy_snapshots"] == second["enemy_snapshots"],
		"two independently initialized copies produce identical per-beat snapshots")
	_check(first["heroes"] == second["heroes"] and first["enemies"] == second["enemies"],
		"two independently initialized copies end in identical party and enemy state")

	# The shared catalogs are never mutated by any of this.
	var roster_before := _load_catalog(ENEMY_CATALOG_PATH)
	var heroes_before := _load_catalog(HERO_CATALOG_PATH)
	_play_three_beats()
	_check(_load_catalog(ENEMY_CATALOG_PATH) == roster_before,
		"the shipped enemy catalog is unchanged by the encounter")
	_check(_load_catalog(HERO_CATALOG_PATH) == heroes_before,
		"the shipped hero catalog is unchanged by the encounter")


## Deep copy of the prescription with one beat replaced in place.
func _with_beat(position: int, beat: int, replacement: Dictionary) -> Array:
	var data: Array = _expected_definitions().duplicate(true)
	for entry in data:
		if entry["enemy_position"] == position:
			var pattern: Array = entry["pattern"]
			pattern[beat] = replacement
	return data


## AC3: malformed schedules, malformed phases and illegal rosters fail closed
## without publishing a side effect on party, enemies or the RNG.
func _test_negative_fail_closed() -> void:
	var malformed: Array = []
	malformed.append({"label": "slot-1 shove with direction 0",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 2, "direction": 0})})
	malformed.append({"label": "slot-1 shove with direction 2",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 2, "direction": 2})})
	malformed.append({"label": "slot-1 shove off the rear edge",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 3, "direction": 1})})
	malformed.append({"label": "slot-1 shove off the front edge",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 1, "direction": -1})})
	malformed.append({"label": "slot-1 shove with a nonzero amount",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 1, "target_position": 2, "direction": 1})})
	malformed.append({"label": "slot-1 shove without a direction",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 2})})
	malformed.append({"label": "slot-1 shove with an extra key",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 2, "direction": 1,
			"extra": 1})})
	malformed.append({"label": "slot-1 shove with a fractional direction",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 2, "direction": 1.5})})
	malformed.append({"label": "slot-1 block with a target",
		"data": _with_beat(1, 1, {"type": "block", "amount": 2, "target_position": 1})})
	malformed.append({"label": "slot-1 attack without a target",
		"data": _with_beat(1, 2, {"type": "attack", "amount": 3})})
	malformed.append({"label": "slot-2 attack with a target of 0",
		"data": _with_beat(2, 0, {"type": "attack", "amount": 4, "target_position": 0})})
	malformed.append({"label": "slot-2 attack with a target of 4",
		"data": _with_beat(2, 0, {"type": "attack", "amount": 4, "target_position": 4})})
	malformed.append({"label": "slot-2 Weak without a status",
		"data": _with_beat(2, 1, {"type": "debuff", "amount": 1, "target_position": 2})})
	malformed.append({"label": "slot-2 Weak with an unknown status",
		"data": _with_beat(2, 1, {"type": "debuff", "amount": 1, "target_position": 2, "status": "poison"})})
	malformed.append({"label": "slot-2 Weak with a zero amount",
		"data": _with_beat(2, 1, {"type": "debuff", "amount": 0, "target_position": 2, "status": "weak"})})
	malformed.append({"label": "slot-2 buff with a zero amount",
		"data": _with_beat(2, 2, {"type": "buff", "amount": 0})})
	var empty_pattern: Array = _expected_definitions().duplicate(true)
	empty_pattern[0]["pattern"].clear()
	malformed.append({"label": "empty slot-1 pattern", "data": empty_pattern})
	var duplicate_positions: Array = _expected_definitions().duplicate(true)
	duplicate_positions[1]["enemy_position"] = 1
	malformed.append({"label": "duplicate source position", "data": duplicate_positions})
	var zero_position: Array = _expected_definitions().duplicate(true)
	zero_position[0]["enemy_position"] = 0
	malformed.append({"label": "source position 0", "data": zero_position})
	for entry_case in malformed:
		var label: String = entry_case["label"]
		var data: Array = entry_case["data"]
		var pristine: Array = data.duplicate(true)
		_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(data)).is_empty(),
			"negative: " + label + " is rejected by the real JSON loader")
		_check(not CombatEnemyIntents.new(data).is_valid(),
			"negative: " + label + " is rejected by the intent validator")
		var rejected := CombatEnemyIntents.new(data)
		_check(rejected.get_intents().is_empty(),
			"negative: " + label + " announces no intents at all")
		_check(not rejected.advance_turn(),
			"negative: " + label + " cannot advance its beat")
		_check(data == pristine,
			"negative: " + label + " leaves the caller's schedule unmutated")
	# Controls, so the rejections above cannot pass vacuously.
	_check(_parsed() == _expected_definitions(),
		"negative: the unmodified authored file still parses exactly")
	_check(CombatEnemyIntents.new(_expected_definitions()).is_valid(),
		"negative: the unmodified prescription is still a valid schedule")
	_check(_with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 2, "direction": 0})
		!= _expected_definitions(),
		"negative: the beat mutation helper really produces a different schedule")

	# A malformed shove in a phase is rejected whole, without staging the
	# earlier source's damage.
	var party := _build_party()
	var enemies := _assemble_enemies()
	var before_party := party.get_heroes()
	var before_enemies := enemies.get_enemies()
	seed(RNG_SEED)
	var expected_rng := randi()
	seed(RNG_SEED)
	var bad_phase := CombatEnemyPhase.new().execute_phase(party, enemies, [
		{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 1},
		{"type": "shove", "amount": 0, "target_position": 2, "direction": 0, "enemy_position": 2}])
	_check(randi() == expected_rng, "negative: a rejected phase draws no global RNG")
	_check(bad_phase == {"ok": false, "events": []},
		"negative: a malformed shove rejects the whole phase")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"negative: a rejected phase changes no hero and no enemy")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 0,
		"negative: the earlier staged attack is rolled back")
	_check(party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(3).get("id") == "tinker",
		"negative: the rejected shove leaves the party order untouched")

	# A shove participant that is downed fails the whole phase closed.
	party = _build_party()
	enemies = _assemble_enemies()
	_check(party.apply_damage(3, 26) and party.is_downed(3), "negative: Tinker is downed")
	before_party = party.get_heroes()
	before_enemies = enemies.get_enemies()
	seed(RNG_SEED)
	expected_rng = randi()
	seed(RNG_SEED)
	var downed_phase := CombatEnemyPhase.new().execute_phase(party, enemies,
		CombatEnemyIntents.new(_parsed()).get_intents())
	_check(randi() == expected_rng, "negative: a downed shove participant draws no global RNG")
	_check(downed_phase == {"ok": false, "events": []},
		"negative: a downed shove participant rejects the whole phase")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"negative: the rejected phase changes no hero and no enemy")
	_check(party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(2).get("hp") == 30,
		"negative: the rejected phase deals no damage to the unshuffled Seamstress")

	# A downed debuff target fails the whole phase closed as well.
	party = _build_party()
	enemies = _assemble_enemies()
	_check(party.apply_damage(2, 30) and party.is_downed(2), "negative: the middle hero is downed")
	before_party = party.get_heroes()
	before_enemies = enemies.get_enemies()
	var downed_scheduler := CombatEnemyIntents.new(_parsed())
	_check(downed_scheduler.advance_turn(), "negative: advance to the Weak beat")
	seed(RNG_SEED)
	expected_rng = randi()
	seed(RNG_SEED)
	var downed_weak := CombatEnemyPhase.new().execute_phase(party, enemies,
		downed_scheduler.get_intents())
	_check(randi() == expected_rng, "negative: a downed Weak target draws no global RNG")
	_check(downed_weak == {"ok": false, "events": []},
		"negative: a downed Weak target rejects the whole phase")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"negative: the rejected Weak phase changes no hero and no enemy")

	# A source outside this encounter's two-enemy roster fails closed.
	party = _build_party()
	enemies = _assemble_enemies()
	before_party = party.get_heroes()
	before_enemies = enemies.get_enemies()
	seed(RNG_SEED)
	expected_rng = randi()
	seed(RNG_SEED)
	var outside := CombatEnemyPhase.new().execute_phase(party, enemies, [
		{"type": "block", "amount": 2, "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 3, "enemy_position": 3}])
	_check(randi() == expected_rng, "negative: an out-of-roster source draws no global RNG")
	_check(outside == {"ok": false, "events": []},
		"negative: a source outside the roster rejects the phase")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"negative: the out-of-roster phase changes nothing")
