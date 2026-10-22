extends SceneTree
## Deterministic headless coverage for the authored Spoolbridge Staggered
## Exposure encounter: slot 1 Spool Stalker shoves the middle hero back and
## then tags the displaced rear hero Exposed 1; slot 2 Seam Ripper hits that
## rear hero for a base 4, then for a base 5 that Exposed turns into 7.
## Authored-source/phase coverage with the encounter now registered in the
## real typed Fight pool. The isolated fixture keeps zero hero Block on purpose,
## so the exact damage numbers are observable
## without presuming the Warden's start-of-combat passive.

const ENCOUNTER_PATH := "res://data/encounters/spoolbridge_staggered_exposure.json"
const ENCOUNTER_ID := "spoolbridge_staggered_exposure"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMY_PATH := "res://data/enemies/run_enemies.json"
const TYPED_POOL_PATH := "res://data/encounters/m03_typed_battle_pools.json"
const BUTTONFRONT_PATH := "res://data/encounters/buttonfront_pinfall.json"
const SPOOLPIN_PATH := "res://data/encounters/spoolpin_pullfire.json"
const RNG_SEED := 20261025
const MAP_SEED := 93117

## This encounter's own roster binding, owned by this test: slot 1 is the
## Spool Stalker and slot 2 the Seam Ripper, in that order.
const LOCAL_ROSTER_MAP := {
	ENCOUNTER_ID: ["spool_stalker", "seam_ripper"],
}

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_authored_schedule_and_parser()
	_test_existing_encounters_intact()
	_test_typed_roster_assembly()
	_test_intent_cycle()
	_test_real_beat_one()
	_test_real_beats_two_and_three()
	_test_replay_determinism()
	_test_negative_fail_closed()
	if failures.is_empty():
		print("spoolbridge_staggered_exposure_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("spoolbridge_staggered_exposure_test: FAIL (", failures.size(), " failures)")
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
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed"},
			{"type": "attack", "amount": 3, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 4, "target_position": 3},
			{"type": "attack", "amount": 5, "target_position": 3},
			{"type": "buff", "amount": 2}]},
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


func _expected_events(beat: int, dead_source: int = 0) -> Array:
	var events: Array = []
	for intent in _expected_beat(beat):
		var event := {"type": intent["type"], "enemy_position": intent["enemy_position"],
			"applied": intent["enemy_position"] != dead_source}
		for field in ["target_position", "status", "direction"]:
			if intent.has(field):
				event[field] = intent[field]
		events.append(event)
	return events


## The real three-hero party, assembled from the shipped starter party file.
## No opening passive is applied here: the fixture keeps zero hero Block so
## the exact damage numbers stay observable.
func _build_party() -> CombatParty:
	var heroes := _load_catalog(PARTY_PATH)
	var definitions: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		definitions.append(_record_by_id(heroes, id))
	return CombatParty.new(definitions)


## The real two-enemy roster, in this encounter's own slot order, assembled
## by the real typed-roster bridge from the shipped run_enemies.json records.
func _assemble_enemies() -> CombatEnemies:
	var typed_choice := {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": _parsed().duplicate(true),
	}
	var assembled := RunTypedBattleRoster.new().assemble(
		typed_choice, LOCAL_ROSTER_MAP.duplicate(true), [ENEMY_PATH])
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


## The complete expected party snapshot for a beat: the given hero order with
## the given HP, zero Block and optional statuses, keeping every other
## authored field of the real hero record.
func _expected_party(initial: Array, order: Array, hp_by_id: Dictionary,
		statuses_by_id: Dictionary) -> Array:
	var by_id: Dictionary = {}
	for hero in initial:
		by_id[hero["id"]] = hero
	var expected: Array = []
	for index in range(order.size()):
		var id: String = order[index]
		var hero: Dictionary = by_id[id].duplicate(true)
		hero["position"] = index + 1
		hero["hp"] = hp_by_id[id]
		hero["block"] = 0
		if statuses_by_id.has(id):
			hero["statuses"] = statuses_by_id[id].duplicate(true)
		expected.append(hero)
	return expected


## The complete expected enemy snapshot: the same records with the given
## Block per enemy id. Enemy HP never changes in this encounter.
func _expected_enemies(initial: Array, block_by_id: Dictionary) -> Array:
	var expected: Array = []
	for enemy in initial:
		var copy: Dictionary = enemy.duplicate(true)
		copy["block"] = block_by_id.get(copy["id"], 0)
		expected.append(copy)
	return expected


## AC1: the shipped file is exactly the prescribed two-source, three-beat
## schedule, and the two named enemies already exist in the shipped catalog.
func _test_authored_schedule_and_parser() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "the authored encounter file exists")
	_check(ENCOUNTER_PATH.get_file().get_basename() == ENCOUNTER_ID,
		"the schedule file name carries the canonical encounter ID %s" % ENCOUNTER_ID)

	var raw_text := _read_text(ENCOUNTER_PATH)
	var raw: Variant = JSON.parse_string(raw_text)
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
			# Every beat of that source, in order, is checked by index.
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
			if action.has("direction"):
				_check(action.get("direction") is int,
					"parsed beat direction is an int, not a JSON float")

	# The named actors really exist with the stats this schedule is authored
	# against; no new enemy record is introduced.
	var roster := _load_catalog(ENEMY_PATH)
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
	_check(party.get_hero(1).get("block") == 0 and party.get_hero(2).get("block") == 0
		and party.get_hero(3).get("block") == 0,
		"the isolated fixture starts every hero with zero Block")

	# The real Fight loader accepts this authored file as a schedule.
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

	# The real production Fight pool must bind this ID to its exact schedule
	# and ordered roster, without depending on any other catalog entries.
	_check(FileAccess.file_exists(TYPED_POOL_PATH),
		"the shared typed battle pool exists")
	var pools: Variant = JSON.parse_string(_read_text(TYPED_POOL_PATH))
	_check(pools is Dictionary and pools.get("Fight") is Dictionary,
		"production registry exposes a valid Fight pool")
	if pools is Dictionary and pools.get("Fight") is Dictionary:
		_check(pools["Fight"].get(ENCOUNTER_ID) == {
			"schedule": ENCOUNTER_PATH, "enemy_ids": LOCAL_ROSTER_MAP[ENCOUNTER_ID]},
			"Spoolbridge has the exact live Fight schedule and ordered roster binding")

	# The authored bytes on disk are unchanged by every parser read.
	_check(_read_text(ENCOUNTER_PATH) == raw_text,
		"the authored encounter file bytes are unchanged after validation")


## AC1: the two earlier named encounters still parse and still validate on
## their own data. This never asserts a catalog total or a pool order.
func _test_existing_encounters_intact() -> void:
	for path in [BUTTONFRONT_PATH, SPOOLPIN_PATH]:
		var text := _read_text(path)
		var parsed := RunFightEncounterSelection._parse_schedule_text(text)
		_check(not parsed.is_empty(), "the earlier schedule still parses: " + path)
		_check(CombatEnemyIntents.new(parsed).is_valid(),
			"the earlier schedule still validates: " + path)
		_check(parsed.size() == 2, "the earlier schedule still holds two sources: " + path)
		var positions: Array = []
		for entry in parsed:
			if entry is Dictionary:
				positions.append(entry.get("enemy_position"))
		_check(positions.size() == 2 and positions.has(1) and positions.has(2),
			"the earlier schedule still holds one source per slot 1 and 2: " + path)
		for entry in parsed:
			if not entry is Dictionary:
				continue
			var pattern: Array = entry.get("pattern", [])
			for action in pattern:
				_check(CombatEnemyIntents.valid_action(action),
					"every action of the earlier schedule is still a valid action: " + path)
		_check(parsed != _parsed(),
			"the new schedule differs from the earlier schedule: " + path)
		_check(_read_text(path) == text,
			"the earlier schedule file bytes are unchanged: " + path)
	# Controls, so the checks above cannot pass vacuously.
	_check(_parsed() == _expected_definitions(),
		"control: the new authored file still parses exactly")
	_check(CombatEnemyIntents.new(_expected_definitions()).is_valid(),
		"control: the new prescription is still a valid schedule")


## AC2: the real typed roster bridge binds this encounter's two named enemies.
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
		typed_choice, LOCAL_ROSTER_MAP.duplicate(true), [ENEMY_PATH])
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

	# The assembled definitions are a copy: editing them leaves the caller's
	# typed choice and a freshly assembled roster untouched.
	var assembled_definitions: Array = assembled.get("definitions", [])
	if not assembled_definitions.is_empty():
		assembled_definitions[0]["pattern"][0]["amount"] = 909
		_check(typed_choice == choice_snapshot,
			"editing the assembled definitions cannot reach the caller's typed choice")
		var reassembled := RunTypedBattleRoster.new().assemble(
			typed_choice, LOCAL_ROSTER_MAP.duplicate(true), [ENEMY_PATH])
		_check(reassembled.get("definitions") == _expected_definitions(),
			"a freshly assembled roster still carries the exact authored definitions")

	# The roster binding is owned by this encounter's own map, not inherited
	# from another encounter: swapping the IDs swaps the slots.
	var swapped := RunTypedBattleRoster.new().assemble(
		typed_choice.duplicate(true), {ENCOUNTER_ID: ["seam_ripper", "spool_stalker"]},
		[ENEMY_PATH])
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
	_check(bridge.assemble(typed_choice, {ENCOUNTER_ID: ["spool_stalker"]}, [ENEMY_PATH])
		== {"ok": false},
		"a one-enemy roster for this two-source encounter is rejected")
	_check(bridge.assemble(typed_choice,
		{ENCOUNTER_ID: ["spool_stalker", "spool_stalker"]}, [ENEMY_PATH])
		== {"ok": false},
		"a duplicate enemy ID in the roster is rejected")
	_check(bridge.assemble(typed_choice,
		{ENCOUNTER_ID: ["spool_stalker", "unknown_enemy"]}, [ENEMY_PATH])
		== {"ok": false},
		"an unknown enemy ID in the roster is rejected")
	_check(bridge.assemble(typed_choice, {}, [ENEMY_PATH]) == {"ok": false},
		"a missing roster binding for this encounter is rejected")
	_check(bridge.assemble(typed_choice, LOCAL_ROSTER_MAP.duplicate(true),
		["res://data/enemies/missing_catalog.json"]) == {"ok": false},
		"a missing enemy catalog file is rejected")

	# A fractional HP in the real catalog text is rejected by the real
	# catalog parser, so no truncated value can ever reach a roster.
	var catalog_text := _read_text(ENEMY_PATH)
	_check(not RunTypedBattleRoster._parse_catalog_text(catalog_text).is_empty(),
		"the shipped enemy catalog still parses through the real catalog parser")
	var drifted := catalog_text.replace('"max_hp": 14', '"max_hp": 14.5')
	_check(drifted != catalog_text, "the drift probe really changed the catalog text")
	_check(RunTypedBattleRoster._parse_catalog_text(drifted).is_empty(),
		"a fractional max_hp in the enemy catalog is rejected, not truncated")


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
	_check(snapshot == _expected_beat(0), "a detached announcement is the exact first beat")
	snapshot[0]["amount"] = 99
	snapshot[0]["type"] = "block"
	snapshot.append({"enemy_position": 3, "type": "block", "amount": 5})
	_check(snapshot_selector.get_intents() == _expected_beat(0),
		"mutating a returned announcement cannot alter later intents")
	_check(definitions == _expected_definitions(), "the parsed schedule keeps its prescribed source")
	var isolated := CombatEnemyIntents.new(definitions)
	var parsed_pattern: Array = definitions[0]["pattern"]
	parsed_pattern[0]["amount"] = 7
	_check(isolated.get_intents() == _expected_beat(0),
		"mutating the parsed source cannot alter an independently built selector")


## AC3: beat 1 shoves the living middle hero back and the rear strike then
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
	var announced := scheduler.get_intents()
	_check(announced == _expected_beat(0),
		"beat 1 announces the slot-1 shove before the slot-2 attack")
	var announced_snapshot := announced.duplicate(true)

	seed(RNG_SEED)
	var expected_rng := randi()
	seed(RNG_SEED)
	var result := phase.execute_phase(party, enemies, announced)
	_check(randi() == expected_rng, "beat 1 draws no global RNG")
	_check(result == {"ok": true, "events": _expected_events(0)},
		"beat 1 resolves the slot-1 shove then the slot-2 attack, in that order")
	_check(announced == announced_snapshot,
		"beat 1 leaves the caller's announced intents unmutated")
	_check(scheduler.get_intents() == _expected_beat(0),
		"beat 1 does not advance the scheduler on its own")

	# The shove displaces the Seamstress to the rear; the middle is now Tinker.
	_check_hero(party, 1, "warden", 40, 0, "beat 1")
	_check_hero(party, 2, "tinker", 26, 0, "beat 1")
	_check_hero(party, 3, "seamstress", 26, 0, "beat 1")
	_check(party.get_hero(3).get("max_hp") == 30,
		"the displaced Seamstress keeps its own 30 max HP")
	_check(party.get_hero(2).get("name") == "Tinker"
		and party.get_hero(3).get("name") == "Seamstress",
		"the swap keeps each hero's own identity")
	_check(party.get_hero(2).get("art_path") == "res://assets/paper/heroes/tinker.png"
		and party.get_hero(3).get("art_path") == "res://assets/paper/heroes/seamstress.png",
		"the swap keeps each hero's own art path")
	_check(party.get_hero(1).get("statuses", {}) == {}
		and party.get_hero(2).get("statuses", {}) == {}
		and party.get_hero(3).get("statuses", {}) == {},
		"beat 1 tags no hero with a status")
	_check_enemy(enemies, 1, "spool_stalker", 14, 0, "beat 1")
	_check_enemy(enemies, 2, "seam_ripper", 18, 0, "beat 1")

	# The complete party and roster snapshots after beat 1.
	var initial_party := _build_party().get_heroes()
	var initial_enemies := enemies.get_enemies()
	_check(party.get_heroes() == _expected_party(initial_party,
		["warden", "tinker", "seamstress"],
		{"warden": 40, "tinker": 26, "seamstress": 26}, {}),
		"beat 1 leaves the complete party snapshot: Warden 40, Tinker 26, Seamstress 26")
	_check(enemies.get_enemies() == _expected_enemies(initial_enemies,
		{"spool_stalker": 0, "seam_ripper": 0}),
		"beat 1 leaves the complete enemy snapshot with zero Block on both sources")


## AC3: beat 2 tags the rear hero Exposed and the following strike turns a
## base 5 into floor(5 * 1.5) = 7; beat 3 hits the middle hero for 3 and the
## rear enemy gains exactly 2 Block.
func _test_real_beats_two_and_three() -> void:
	var party := _build_party()
	var enemies := _assemble_enemies()
	var scheduler := CombatEnemyIntents.new(_parsed())
	var initial_party := party.get_heroes()
	var initial_enemies := enemies.get_enemies()

	# Beat 1, so the later beats run on the real displaced formation.
	var beat_1 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(beat_1 == {"ok": true, "events": _expected_events(0)}, "beat 1 succeeds")
	_check(scheduler.advance_turn(), "advance to beat 2")

	seed(RNG_SEED)
	var expected_rng := randi()
	seed(RNG_SEED)
	var beat_2_announced := scheduler.get_intents()
	_check(beat_2_announced == _expected_beat(1),
		"beat 2 announces the slot-1 Exposed before the slot-2 attack")
	var beat_2 := phase.execute_phase(party, enemies, beat_2_announced)
	_check(randi() == expected_rng, "beat 2 draws no global RNG")
	_check(beat_2 == {"ok": true, "events": _expected_events(1)},
		"beat 2 resolves the slot-1 Exposed then the slot-2 attack, in that order")
	_check_hero(party, 1, "warden", 40, 0, "beat 2")
	_check_hero(party, 2, "tinker", 26, 0, "beat 2")
	_check_hero(party, 3, "seamstress", 19, 0, "beat 2")
	_check(party.get_hero(3).get("statuses", {}) == {"exposed": 1},
		"beat 2 tags the displaced rear hero with Exposed 1")
	_check(party.get_hero(1).get("statuses", {}) == {}
		and party.get_hero(2).get("statuses", {}) == {},
		"beat 2 tags no other hero")
	_check(CombatStatuses.new().adjusted_attack_damage(5, {}, {"exposed": 1}) == 7,
		"Exposed 1 raises a base 5 attack to 7")
	_check(party.get_heroes() == _expected_party(initial_party,
		["warden", "tinker", "seamstress"],
		{"warden": 40, "tinker": 26, "seamstress": 19},
		{"seamstress": {"exposed": 1}}),
		"beat 2 leaves the complete party snapshot: Seamstress 19 with Exposed 1")
	_check(enemies.get_enemies() == _expected_enemies(initial_enemies,
		{"spool_stalker": 0, "seam_ripper": 0}),
		"beat 2 leaves the complete enemy snapshot with zero Block on both sources")

	_check(scheduler.advance_turn(), "advance to beat 3")
	seed(RNG_SEED)
	expected_rng = randi()
	seed(RNG_SEED)
	var beat_3_announced := scheduler.get_intents()
	_check(beat_3_announced == _expected_beat(2),
		"beat 3 announces the slot-1 attack on the middle hero and the slot-2 self buff")
	var beat_3 := phase.execute_phase(party, enemies, beat_3_announced)
	_check(randi() == expected_rng, "beat 3 draws no global RNG")
	_check(beat_3 == {"ok": true, "events": _expected_events(2)},
		"beat 3 resolves the slot-1 attack then the slot-2 buff, in that order")
	_check_hero(party, 1, "warden", 40, 0, "beat 3")
	_check_hero(party, 2, "tinker", 23, 0, "beat 3")
	_check_hero(party, 3, "seamstress", 19, 0, "beat 3")
	_check(party.get_hero(3).get("statuses", {}) == {"exposed": 1},
		"beat 3 keeps the Exposed 1 tag: an enemy phase does not age statuses")
	_check_enemy(enemies, 1, "spool_stalker", 14, 0, "beat 3")
	_check_enemy(enemies, 2, "seam_ripper", 18, 2, "beat 3")
	_check(party.get_heroes() == _expected_party(initial_party,
		["warden", "tinker", "seamstress"],
		{"warden": 40, "tinker": 23, "seamstress": 19},
		{"seamstress": {"exposed": 1}}),
		"beat 3 leaves the complete party snapshot: Tinker 23, Seamstress 19")
	_check(enemies.get_enemies() == _expected_enemies(initial_enemies,
		{"spool_stalker": 0, "seam_ripper": 2}),
		"beat 3 leaves the complete enemy snapshot: only the Seam Ripper holds 2 Block")

	# The announcement cycle wraps back to the first pattern.
	_check(scheduler.advance_turn(), "advance past the third beat")
	_check(scheduler.get_intents() == _expected_beat(0),
		"after exactly three advances the schedule announces its first intents again")


## The three beats played on a fresh fixture, with the complete trace of
## announcements, events, party snapshots and roster snapshots.
func _play_three_beats() -> Dictionary:
	var party := _build_party()
	var enemies := _assemble_enemies()
	var scheduler := CombatEnemyIntents.new(_parsed())
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


## AC3: two independently initialized copies of the same authored data agree in
## every event and every surviving field over the whole three-beat timeline,
## and no service in the chain consumes the seeded RNG.
func _test_replay_determinism() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED
	var state_before := rng.state
	seed(RNG_SEED)
	var expected_rng := randi()
	seed(RNG_SEED)
	var first := _play_three_beats()
	_check(randi() == expected_rng, "three real enemy phases draw no global RNG")
	_check(rng.state == state_before,
		"the seeded run RNG is untouched by the schedule and the phase")
	var second := _play_three_beats()
	_check(rng.state == state_before,
		"the seeded run RNG is still untouched after a second replay")

	_check(first["announced"].size() == 3 and second["announced"].size() == 3,
		"each replay announced exactly three beats")
	_check(first["announced"][0] == _expected_beat(0)
		and first["announced"][1] == _expected_beat(1)
		and first["announced"][2] == _expected_beat(2),
		"the replay announces the exact first, second and third beats")
	_check(first["events"][0].get("events") == _expected_events(0)
		and first["events"][1].get("events") == _expected_events(1)
		and first["events"][2].get("events") == _expected_events(2),
		"the replay resolves the exact first, second and third beat events")

	# A literal end state, so two equally broken runs cannot satisfy the
	# comparison below.
	_check(first["heroes"].size() == 3 and first["enemies"].size() == 2,
		"the replay ends with the complete authored formation")
	_check(first["heroes"][0]["id"] == "warden" and first["heroes"][0]["hp"] == 40
		and first["heroes"][0]["block"] == 0,
		"the replay ends with the Warden at the front, 40 HP and 0 Block")
	_check(first["heroes"][1]["id"] == "tinker" and first["heroes"][1]["hp"] == 23
		and first["heroes"][1]["block"] == 0,
		"the replay ends with Tinker in the middle at 23 HP and 0 Block")
	_check(first["heroes"][2]["id"] == "seamstress" and first["heroes"][2]["hp"] == 19
		and first["heroes"][2]["block"] == 0
		and first["heroes"][2].get("statuses", {}) == {"exposed": 1},
		"the replay ends with the Seamstress at the rear at 19 HP with Exposed 1")
	_check(first["enemies"][0]["id"] == "spool_stalker" and first["enemies"][0]["hp"] == 14
		and first["enemies"][0]["block"] == 0,
		"the replay ends with the Spool Stalker at 14 HP and 0 Block")
	_check(first["enemies"][1]["id"] == "seam_ripper" and first["enemies"][1]["hp"] == 18
		and first["enemies"][1]["block"] == 2,
		"the replay ends with the Seam Ripper at 18 HP and exactly 2 Block")
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
	var roster_before := _load_catalog(ENEMY_PATH)
	var heroes_before := _load_catalog(PARTY_PATH)
	_play_three_beats()
	_check(_load_catalog(ENEMY_PATH) == roster_before,
		"the shipped enemy catalog is unchanged by the encounter")
	_check(_load_catalog(PARTY_PATH) == heroes_before,
		"the shipped hero catalog is unchanged by the encounter")


## Deep copy of the prescription with one beat replaced in place.
func _with_beat(position: int, beat: int, replacement: Dictionary) -> Array:
	var data: Array = _expected_definitions().duplicate(true)
	for entry in data:
		if entry["enemy_position"] == position:
			var pattern: Array = entry["pattern"]
			pattern[beat] = replacement
	return data


## AC3/AC4: malformed schedules, illegal phases and illegal recipients fail
## closed without publishing a side effect on party, enemies or the RNG.
func _test_negative_fail_closed() -> void:
	var malformed: Array = []
	malformed.append({"label": "slot-1 attack on position 4",
		"data": _with_beat(1, 2, {"type": "attack", "amount": 3, "target_position": 4})})
	malformed.append({"label": "slot-2 attack on position 4",
		"data": _with_beat(2, 0, {"type": "attack", "amount": 4, "target_position": 4})})
	malformed.append({"label": "slot-2 attack on position 0",
		"data": _with_beat(2, 0, {"type": "attack", "amount": 4, "target_position": 0})})
	malformed.append({"label": "slot-1 Exposed on position 4",
		"data": _with_beat(1, 1, {"type": "debuff", "amount": 1, "target_position": 4,
			"status": "exposed"})})
	malformed.append({"label": "slot-1 shove off the rear edge",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 3,
			"direction": 1})})
	malformed.append({"label": "slot-1 shove off the front edge",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 1,
			"direction": -1})})
	malformed.append({"label": "slot-1 shove with direction 0",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 2,
			"direction": 0})})
	malformed.append({"label": "slot-1 shove with direction 2",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 2,
			"direction": 2})})
	malformed.append({"label": "slot-1 shove with a nonzero amount",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 1, "target_position": 2,
			"direction": 1})})
	malformed.append({"label": "slot-1 shove without a direction",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 2})})
	malformed.append({"label": "slot-1 shove with an extra key",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 2,
			"direction": 1, "extra": 1})})
	malformed.append({"label": "slot-1 shove with a fractional direction",
		"data": _with_beat(1, 0, {"type": "shove", "amount": 0, "target_position": 2,
			"direction": 1.5})})
	malformed.append({"label": "slot-1 Exposed without target_position",
		"data": _with_beat(1, 1, {"type": "debuff", "amount": 1, "status": "exposed"})})
	malformed.append({"label": "slot-1 Exposed without status",
		"data": _with_beat(1, 1, {"type": "debuff", "amount": 1, "target_position": 3})})
	malformed.append({"label": "slot-1 Exposed with an unknown status",
		"data": _with_beat(1, 1, {"type": "debuff", "amount": 1, "target_position": 3,
			"status": "poison"})})
	malformed.append({"label": "slot-1 Exposed with amount 0",
		"data": _with_beat(1, 1, {"type": "debuff", "amount": 0, "target_position": 3,
			"status": "exposed"})})
	malformed.append({"label": "slot-1 Exposed with a string amount",
		"data": _with_beat(1, 1, {"type": "debuff", "amount": "1", "target_position": 3,
			"status": "exposed"})})
	malformed.append({"label": "slot-1 Exposed with a fractional amount",
		"data": _with_beat(1, 1, {"type": "debuff", "amount": 1.5, "target_position": 3,
			"status": "exposed"})})
	malformed.append({"label": "slot-2 buff with amount 0",
		"data": _with_beat(2, 2, {"type": "buff", "amount": 0})})
	malformed.append({"label": "slot-2 buff with a fractional amount",
		"data": _with_beat(2, 2, {"type": "buff", "amount": 2.5})})
	malformed.append({"label": "slot-2 attack with a string amount",
		"data": _with_beat(2, 0, {"type": "attack", "amount": "4", "target_position": 3})})
	var empty_pattern: Array = _expected_definitions().duplicate(true)
	empty_pattern[0]["pattern"].clear()
	malformed.append({"label": "empty slot-1 pattern", "data": empty_pattern})
	var duplicate_positions: Array = _expected_definitions().duplicate(true)
	duplicate_positions[1]["enemy_position"] = 1
	malformed.append({"label": "duplicate source position", "data": duplicate_positions})
	var zero_position: Array = _expected_definitions().duplicate(true)
	zero_position[0]["enemy_position"] = 0
	malformed.append({"label": "source position 0", "data": zero_position})
	var fourth_position: Array = _expected_definitions().duplicate(true)
	fourth_position[1]["enemy_position"] = 4
	malformed.append({"label": "source position 4", "data": fourth_position})
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
	_check(_with_beat(1, 2, {"type": "attack", "amount": 3, "target_position": 4})
		!= _expected_definitions(),
		"negative: the beat mutation helper really produces a different schedule")

	# A phase whose second source attacks off the party is rejected whole,
	# after the first source would have staged a real state change.
	var party := _build_party()
	var enemies := _assemble_enemies()
	var before_party := party.get_heroes()
	var before_enemies := enemies.get_enemies()
	seed(RNG_SEED)
	var expected_rng := randi()
	seed(RNG_SEED)
	var illegal_target := phase.execute_phase(party, enemies, [
		{"type": "attack", "amount": 4, "target_position": 3, "enemy_position": 1},
		{"type": "attack", "amount": 5, "target_position": 4, "enemy_position": 2}])
	_check(randi() == expected_rng, "negative: a rejected phase draws no global RNG")
	_check(illegal_target == {"ok": false, "events": []},
		"negative: an attack on position 4 rejects the whole phase")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"negative: the rejected phase changes no hero and no enemy")
	_check(party.get_hero(3).get("hp") == 26,
		"negative: the earlier staged attack is rolled back")

	# A phase whose second source shoves off the back of the party is
	# rejected whole, after the first source would have staged damage.
	party = _build_party()
	enemies = _assemble_enemies()
	before_party = party.get_heroes()
	before_enemies = enemies.get_enemies()
	seed(RNG_SEED)
	expected_rng = randi()
	seed(RNG_SEED)
	var illegal_shove := phase.execute_phase(party, enemies, [
		{"type": "attack", "amount": 4, "target_position": 3, "enemy_position": 1},
		{"type": "shove", "amount": 0, "target_position": 3, "direction": 1,
			"enemy_position": 2}])
	_check(randi() == expected_rng, "negative: an out-of-bounds shove draws no global RNG")
	_check(illegal_shove == {"ok": false, "events": []},
		"negative: an out-of-bounds shove rejects the whole phase")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"negative: the rejected shove changes no hero and no enemy")
	_check(party.get_hero(3).get("hp") == 26,
		"negative: the staged attack before the illegal shove is rolled back")
	_check(party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(3).get("id") == "tinker",
		"negative: the rejected shove leaves the party order untouched")

	# A swap with a downed hero fails the whole phase closed, after an
	# earlier source would have staged a real state change.
	party = _build_party()
	enemies = _assemble_enemies()
	_check(party.apply_damage(3, 26) and party.is_downed(3), "negative: Tinker is downed")
	before_party = party.get_heroes()
	before_enemies = enemies.get_enemies()
	seed(RNG_SEED)
	expected_rng = randi()
	seed(RNG_SEED)
	var downed_swap := phase.execute_phase(party, enemies, [
		{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 1},
		{"type": "shove", "amount": 0, "target_position": 2, "direction": 1,
			"enemy_position": 2}])
	_check(randi() == expected_rng, "negative: a downed swap target draws no global RNG")
	_check(downed_swap == {"ok": false, "events": []},
		"negative: swapping a downed hero rejects the whole phase")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"negative: the rejected swap changes no hero and no enemy")
	_check(party.get_hero(1).get("hp") == 40,
		"negative: the staged attack before the downed swap is rolled back")
	_check(party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(3).get("id") == "tinker",
		"negative: the rejected swap leaves the party order untouched")

	# The authored beat 1 with a downed swap partner fails closed as well.
	party = _build_party()
	enemies = _assemble_enemies()
	_check(party.apply_damage(3, 26) and party.is_downed(3),
		"negative: the authored beat 1 fixture downs Tinker")
	before_party = party.get_heroes()
	before_enemies = enemies.get_enemies()
	var authored_down := phase.execute_phase(party, enemies,
		CombatEnemyIntents.new(_parsed()).get_intents())
	_check(authored_down == {"ok": false, "events": []},
		"negative: the authored shove with a downed partner rejects the whole phase")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"negative: the rejected authored phase changes no hero and no enemy")
	_check(party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(2).get("hp") == 30,
		"negative: the rejected authored phase deals no damage to the Seamstress")

	# A slain source does not act, while the living source still acts.
	party = _build_party()
	enemies = _assemble_enemies()
	_check(enemies.apply_damage(1, 14) and enemies.is_slain(1)
		and not enemies.is_slain(2), "negative: the slot-1 source is really slain")
	before_party = party.get_heroes()
	before_enemies = enemies.get_enemies()
	seed(RNG_SEED)
	expected_rng = randi()
	seed(RNG_SEED)
	var slain := phase.execute_phase(party, enemies,
		CombatEnemyIntents.new(_parsed()).get_intents())
	_check(randi() == expected_rng, "negative: a phase with a slain source draws no global RNG")
	_check(slain == {"ok": true, "events": _expected_events(0, 1)},
		"negative: the slain source is skipped while the living source still acts")
	_check(party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(3).get("id") == "tinker",
		"negative: the skipped shove leaves the party order untouched")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 22,
		"negative: the living source hits the rear hero for its base 4")
	_check(party.get_hero(2).get("hp") == 30,
		"negative: the living source deals no damage to the middle hero")
	_check(enemies.get_enemy(1).get("block") == 0,
		"negative: the slain source gains no Block")
	_check(enemies.get_enemies()[0].get("hp") == 0
		and enemies.get_enemies()[1].get("block") == 0,
		"negative: the slain roster keeps its own HP and gains no Block")

	# A source outside this encounter's two-enemy roster fails closed.
	party = _build_party()
	enemies = _assemble_enemies()
	before_party = party.get_heroes()
	before_enemies = enemies.get_enemies()
	seed(RNG_SEED)
	expected_rng = randi()
	seed(RNG_SEED)
	var outside := phase.execute_phase(party, enemies, [
		{"type": "attack", "amount": 4, "target_position": 3, "enemy_position": 1},
		{"type": "attack", "amount": 5, "target_position": 3, "enemy_position": 3}])
	_check(randi() == expected_rng, "negative: an out-of-roster source draws no global RNG")
	_check(outside == {"ok": false, "events": []},
		"negative: a source outside the roster rejects the phase")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"negative: the out-of-roster phase changes nothing")

	# A malformed action inside a phase is rejected whole.
	party = _build_party()
	enemies = _assemble_enemies()
	before_party = party.get_heroes()
	before_enemies = enemies.get_enemies()
	var malformed_action := _expected_beat(0).duplicate(true)
	malformed_action[1]["amount"] = "4"
	seed(RNG_SEED)
	expected_rng = randi()
	seed(RNG_SEED)
	var bad_action := phase.execute_phase(party, enemies, malformed_action)
	_check(randi() == expected_rng, "negative: a malformed action draws no global RNG")
	_check(bad_action == {"ok": false, "events": []},
		"negative: a malformed slot-2 action rejects the phase")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"negative: the malformed phase applies no shove and no damage")
	_check(party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(3).get("id") == "tinker",
		"negative: the malformed phase leaves the party order untouched")
