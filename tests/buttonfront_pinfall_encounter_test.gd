extends SceneTree

## Deterministic headless coverage for the authored Buttonfront Pinfall
## encounter: slot 1 Button Guard opens with Exposed 1 on the front hero, then
## slot 2 Fray Scavenger strikes that same hero for a base 4 that Exposed turns
## into 6. Beats 2 and 3 cycle through Block, a rear strike, a middle strike
## and a rear self buff.
## Authored service coverage plus the shared Fight registration contract.

const ENCOUNTER_PATH := "res://data/encounters/buttonfront_pinfall.json"
const ENCOUNTER_ID := "buttonfront_pinfall"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMY_PATH := "res://data/enemies/run_enemies.json"
const TYPED_POOL_PATH := "res://data/encounters/m03_typed_battle_pools.json"
const COMPANION_PATH := "res://data/encounters/rearline_needlemark.json"
const RNG_SEED := 20261024
const MAP_SEED := 91733

## This encounter's own roster binding, owned by this test: slot 1 is the
## Button Guard and slot 2 the Fray Scavenger, in that order.
const LOCAL_ROSTER_MAP := {
	ENCOUNTER_ID: ["button_guard", "fray_scavenger"],
}

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_authored_schedule_and_parser()
	_test_typed_roster_assembly()
	_test_intent_cycle()
	_test_real_beat_one()
	_test_real_beats_two_and_three()
	_test_sequential_replay()
	_test_replay_determinism()
	_test_negative_fail_closed()
	_test_companion_encounter_intact()
	if failures.is_empty():
		print("buttonfront_pinfall_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("buttonfront_pinfall_encounter_test: FAIL (", failures.size(), " failures)")
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
			{"type": "debuff", "amount": 1, "target_position": 1, "status": "exposed"},
			{"type": "block", "amount": 2},
			{"type": "attack", "amount": 3, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 4, "target_position": 1},
			{"type": "attack", "amount": 3, "target_position": 3},
			{"type": "buff", "amount": 2}]},
	]


## Literal announced beats, independent of the parsed file and of the schedule.
func _expected_beat_1() -> Array:
	return [
		{"type": "debuff", "amount": 1, "target_position": 1, "status": "exposed",
			"enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 2}]


func _expected_beat_2() -> Array:
	return [
		{"type": "block", "amount": 2, "enemy_position": 1},
		{"type": "attack", "amount": 3, "target_position": 3, "enemy_position": 2}]


func _expected_beat_3() -> Array:
	return [
		{"type": "attack", "amount": 3, "target_position": 2, "enemy_position": 1},
		{"type": "buff", "amount": 2, "enemy_position": 2}]


func _expected_beat(beat: int) -> Array:
	if beat == 0:
		return _expected_beat_1()
	if beat == 1:
		return _expected_beat_2()
	return _expected_beat_3()


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


## The real three-hero party, assembled from the shipped starter party file.
func _build_party() -> CombatParty:
	var heroes := _load_catalog(PARTY_PATH)
	var definitions: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		definitions.append(_record_by_id(heroes, id))
	return CombatParty.new(definitions)


## The real two-enemy roster, in this encounter's own slot order, assembled
## from the shipped run_enemies.json records without modification.
func _build_enemies() -> CombatEnemies:
	var roster := _load_catalog(ENEMY_PATH)
	var definitions: Array = []
	for id in ["button_guard", "fray_scavenger"]:
		definitions.append(_record_by_id(roster, id))
	return CombatEnemies.new(definitions)


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


## The real hero owner-turn transition: CombatRoundFlow.end_turn applies this
## detached batch before the enemy phase, so a timed debuff ages and expires at
## its owner's turn end instead of lasting forever.
func _tick_heroes(party: CombatParty) -> bool:
	var tick := CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())
	if not tick.get("ok", false):
		return false
	var ticked: Array = tick.get("actors", [])
	if ticked.size() != party._heroes.size():
		return false
	for index in range(party._heroes.size()):
		var hero: Dictionary = party._heroes[index]
		var next: Dictionary = ticked[index]
		hero["hp"] = next["hp"]
		hero["block"] = next["block"]
		if hero.has("statuses") or not next["statuses"].is_empty():
			hero["statuses"] = next["statuses"].duplicate(true)
	return true


## The real enemy owner-turn transition, applied after the phase.
func _tick_enemies(enemies: CombatEnemies) -> bool:
	var tick := CombatStatusTurnBatch.new().tick_side("enemies", enemies.get_enemies())
	if not tick.get("ok", false):
		return false
	var ticked: Array = tick.get("actors", [])
	if ticked.size() != enemies._enemies.size():
		return false
	for index in range(enemies._enemies.size()):
		var enemy: Dictionary = enemies._enemies[index]
		var next: Dictionary = ticked[index]
		enemy["hp"] = next["hp"]
		enemy["block"] = next["block"]
		if enemy.has("statuses") or not next["statuses"].is_empty():
			enemy["statuses"] = next["statuses"].duplicate(true)
	return true


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

	# The named actors really exist with the stats this schedule is authored
	# against; no new enemy record is introduced.
	var roster := _load_catalog(ENEMY_PATH)
	var guard := _record_by_id(roster, "button_guard")
	var scavenger := _record_by_id(roster, "fray_scavenger")
	_check(guard.get("name") == "Button Guard" and guard.get("max_hp") == 16,
		"shipped button_guard is Button Guard with 16 max HP")
	_check(scavenger.get("name") == "Fray Scavenger" and scavenger.get("max_hp") == 14,
		"shipped fray_scavenger is Fray Scavenger with 14 max HP")
	_check(guard.get("art_path") == "res://assets/paper/enemies/button_guard.png",
		"shipped button_guard keeps its existing art path")
	_check(scavenger.get("art_path") == "res://assets/paper/enemies/fray_scavenger.png",
		"shipped fray_scavenger keeps its existing art path")

	# The real starter party: Warden/Seamstress/Tinker at 40/30/26 HP.
	var party := _build_party()
	_check(party.is_valid(), "the shipped starter party builds a real three-hero party")
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("max_hp") == 40
		and party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("max_hp") == 30
		and party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("max_hp") == 26,
		"starter party is Warden/Seamstress/Tinker at 40/30/26 HP in positions 1/2/3")

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

	# The live entry consumes this exact shared Fight binding.
	_check(FileAccess.file_exists(TYPED_POOL_PATH),
		"the shared typed battle pool file exists, so its contents can be inspected")
	_check(_shared_pool_registers_encounter(),
		"this encounter has its singular, exact Fight registration")


## Validate this binding and preserve named earlier entries without catalog totals.
func _shared_pool_registers_encounter() -> bool:
	var file := FileAccess.open(TYPED_POOL_PATH, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	file.close()
	if not parsed is Dictionary:
		return false
	_check(text.count('"' + ENCOUNTER_ID + '"') == 1,
		"raw catalog contains exactly one encounter ID, including duplicate JSON keys")
	_check(text.count('"' + ENCOUNTER_PATH + '"') == 1,
		"raw catalog contains exactly one schedule binding")
	var matches := 0
	for kind in parsed:
		var group = parsed[kind]
		if not group is Dictionary:
			continue
		for encounter_id in group:
			var entry = group[encounter_id]
			if not entry is Dictionary:
				continue
			if encounter_id == ENCOUNTER_ID or entry.get("schedule") == ENCOUNTER_PATH:
				matches += 1
				_check(kind == "Fight" and encounter_id == ENCOUNTER_ID
					and entry == {"schedule": ENCOUNTER_PATH,
						"enemy_ids": ["button_guard", "fray_scavenger"]},
					"exact Fight ID, schedule and ordered enemy binding")
	# Named earlier bindings remain intact; additional entries are welcome.
	var earlier := {
		"Fight": {
			"starter_attacks": ["ragling", "ragling_guard"],
			"bobbin_skirmish": ["fray_scavenger", "spool_stalker"],
			"buttonhole_holdout": ["button_guard", "seam_ripper"],
			"guard_counterattack": ["ragling_guard", "button_guard"],
			"double_hem_siege": ["fray_scavenger", "seam_ripper"],
			"triple_spool_pinch": ["fray_scavenger", "button_guard", "spool_stalker"],
			"seamshift_tripwire": ["seam_ripper", "spool_stalker", "fray_scavenger"],
			"front_hem_pivot": ["button_guard", "fray_scavenger"],
			"rear_spool_reversal": ["spool_stalker", "seam_ripper"],
			"rearline_needlemark": ["fray_scavenger", "seam_ripper"],
			"middlemark_clamp": ["spool_stalker", "seam_ripper"],
			"backhem_pinwheel": ["fray_scavenger", "button_guard", "spool_stalker"],
			"hemdrag_relay": ["seam_ripper", "button_guard"]},
		"Elite": {
			"thimble_crossfire": ["button_guard", "seam_ripper"],
			"needle_marshal_elite": ["needle_marshal", "ragling_guard"],
			"spool_hexer_elite": ["spool_hexer", "spool_stalker"]},
		"Boss": {"patchwork_behemoth": ["patchwork_behemoth"]}}
	for kind in earlier:
		for id in earlier[kind]:
			_check(parsed.get(kind, {}).get(id) == {
				"schedule": "res://data/encounters/%s.json" % id,
				"enemy_ids": earlier[kind][id]}, "earlier binding preserved: " + id)
	return matches == 1


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
		_check(slot_1.get("id") == "button_guard" and slot_1.get("name") == "Button Guard"
			and slot_1.get("position") == 1 and slot_1.get("max_hp") == 16
			and slot_1.get("hp") == 16 and slot_1.get("block") == 0,
			"assembled slot 1 is Button Guard at 16/16 HP with 0 Block")
		_check(slot_2.get("id") == "fray_scavenger" and slot_2.get("name") == "Fray Scavenger"
			and slot_2.get("position") == 2 and slot_2.get("max_hp") == 14
			and slot_2.get("hp") == 14 and slot_2.get("block") == 0,
			"assembled slot 2 is Fray Scavenger at 14/14 HP with 0 Block")
		_check(slot_1.get("art_path") == "res://assets/paper/enemies/button_guard.png"
			and slot_2.get("art_path") == "res://assets/paper/enemies/fray_scavenger.png",
			"the assembled roster keeps the existing enemy art paths")

	# The roster binding is owned by this encounter's own map, not inherited
	# from another encounter: swapping the IDs swaps the slots.
	var swapped := RunTypedBattleRoster.new().assemble(
		typed_choice.duplicate(true), {ENCOUNTER_ID: ["fray_scavenger", "button_guard"]},
		[ENEMY_PATH])
	_check(swapped.get("ok") == true,
		"an explicitly swapped roster binding still assembles")
	if swapped.get("ok") == true:
		var swapped_enemies: Variant = swapped.get("enemies")
		if swapped_enemies is CombatEnemies:
			var swapped_1: Dictionary = swapped_enemies.get_enemy(1)
			var swapped_2: Dictionary = swapped_enemies.get_enemy(2)
			_check(swapped_1.get("id") == "fray_scavenger"
				and swapped_2.get("id") == "button_guard",
				"the roster map, not the schedule, owns the slot-to-enemy binding")

	# Negative roster assembly: mismatched count, duplicate IDs, unknown ID.
	var bridge := RunTypedBattleRoster.new()
	_check(bridge.assemble(typed_choice, {ENCOUNTER_ID: ["button_guard"]}, [ENEMY_PATH])
		== {"ok": false},
		"a one-enemy roster for this two-source encounter is rejected")
	_check(bridge.assemble(typed_choice,
		{ENCOUNTER_ID: ["button_guard", "button_guard"]}, [ENEMY_PATH])
		== {"ok": false},
		"a duplicate enemy ID in the roster is rejected")
	_check(bridge.assemble(typed_choice,
		{ENCOUNTER_ID: ["button_guard", "unknown_enemy"]}, [ENEMY_PATH])
		== {"ok": false},
		"an unknown enemy ID in the roster is rejected")
	_check(bridge.assemble(typed_choice, {}, [ENEMY_PATH]) == {"ok": false},
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


## AC2: on beat 1 the slot-1 Button Guard applies Exposed 1 to the front hero
## before the slot-2 Fray Scavenger attacks that hero for a base 4, so the
## attack lands as 6 and the Warden's opening Block 6 absorbs all of it.
func _test_real_beat_one() -> void:
	var party := _build_party()
	_check(party.is_valid(), "the authored party is valid")
	var enemies := _build_enemies()
	_check(enemies.is_valid(), "the authored two-enemy roster is valid")
	_check_hero(party, 1, "warden", 40, 0, "start")
	_check_hero(party, 2, "seamstress", 30, 0, "start")
	_check_hero(party, 3, "tinker", 26, 0, "start")
	_check_enemy(enemies, 1, "button_guard", 16, 0, "start")
	_check_enemy(enemies, 2, "fray_scavenger", 14, 0, "start")

	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "the Warden opening Block 6 applies once")
	_check_hero(party, 1, "warden", 40, 6, "opening")
	_check(not opening.apply(), "the opening Block cannot be applied twice")

	var scheduler := CombatEnemyIntents.new(_parsed())
	var phase_beats := CombatEnemyPhase.new()
	var announced := scheduler.get_intents()
	_check(announced == _expected_beat_1(),
		"beat 1 announces the slot-1 Exposed before the slot-2 attack")

	seed(RNG_SEED)
	var expected_rng := randi()
	seed(RNG_SEED)
	var result := phase_beats.execute_phase(party, enemies, announced)
	_check(randi() == expected_rng, "beat 1 draws no global RNG")
	_check(result == {"ok": true, "events": _expected_events(0)},
		"beat 1 resolves the slot-1 Exposed then the slot-2 attack, in that order")

	# Exposed turns the base 4 into floor(4 * 1.5) = 6, so the Warden's 6
	# Block is exactly spent and no HP is lost.
	_check(CombatStatuses.new().adjusted_attack_damage(4, {}, {"exposed": 1}) == 6,
		"Exposed 1 raises a base 4 attack to 6")
	_check_hero(party, 1, "warden", 40, 0, "beat 1")
	_check_hero(party, 2, "seamstress", 30, 0, "beat 1")
	_check_hero(party, 3, "tinker", 26, 0, "beat 1")
	_check(party.get_hero(1).get("statuses", {}) == {"exposed": 1},
		"Exposed 1 is recorded on the Warden only")
	_check(party.get_hero(2).get("statuses", {}) == {}
		and party.get_hero(3).get("statuses", {}) == {},
		"beat 1 tags no other hero")
	_check_enemy(enemies, 1, "button_guard", 16, 0, "beat 1")
	_check_enemy(enemies, 2, "fray_scavenger", 14, 0, "beat 1")


## AC3: on fresh isolated fixtures, beat 2 gives the slot-1 enemy 2 Block and
## hits the rear hero for a base 3, beat 3 hits the middle hero for a base 3
## and gives the slot-2 enemy 2 Block.
func _test_real_beats_two_and_three() -> void:
	# Beat 2 on its own fixture.
	var party := _build_party()
	var enemies := _build_enemies()
	_check(CombatStartingBlock.new(party).apply(), "beat 2 fixture grants the opening Block")
	var scheduler := CombatEnemyIntents.new(_parsed())
	_check(scheduler.advance_turn(), "advance to beat 2")
	var announced := scheduler.get_intents()
	_check(announced == _expected_beat_2(),
		"beat 2 announces slot-1 Block 2 and the slot-2 attack 3 on the rear hero")
	seed(RNG_SEED)
	var expected_rng := randi()
	seed(RNG_SEED)
	var beat_2 := phase.execute_phase(party, enemies, announced)
	_check(randi() == expected_rng, "beat 2 draws no global RNG")
	_check(beat_2 == {"ok": true, "events": _expected_events(1)},
		"beat 2 resolves the slot-1 Block then the slot-2 attack, in that order")
	_check_hero(party, 1, "warden", 40, 6, "beat 2")
	_check_hero(party, 2, "seamstress", 30, 0, "beat 2")
	_check_hero(party, 3, "tinker", 23, 0, "beat 2")
	_check(party.get_hero(1).get("statuses", {}) == {},
		"the isolated beat-2 fixture carries no status")
	_check_enemy(enemies, 1, "button_guard", 16, 2, "beat 2")
	_check_enemy(enemies, 2, "fray_scavenger", 14, 0, "beat 2")

	# Beat 3 on its own fresh fixture.
	party = _build_party()
	enemies = _build_enemies()
	_check(CombatStartingBlock.new(party).apply(), "beat 3 fixture grants the opening Block")
	scheduler = CombatEnemyIntents.new(_parsed())
	_check(scheduler.advance_turn(), "advance to beat 2 again")
	_check(scheduler.advance_turn(), "advance to beat 3")
	announced = scheduler.get_intents()
	_check(announced == _expected_beat_3(),
		"beat 3 announces the slot-1 attack 3 on the middle hero and the slot-2 self buff 2")
	seed(RNG_SEED)
	expected_rng = randi()
	seed(RNG_SEED)
	var beat_3 := phase.execute_phase(party, enemies, announced)
	_check(randi() == expected_rng, "beat 3 draws no global RNG")
	_check(beat_3 == {"ok": true, "events": _expected_events(2)},
		"beat 3 resolves the slot-1 attack then the slot-2 buff, in that order")
	_check_hero(party, 1, "warden", 40, 6, "beat 3")
	_check_hero(party, 2, "seamstress", 27, 0, "beat 3")
	_check_hero(party, 3, "tinker", 26, 0, "beat 3")
	_check_enemy(enemies, 1, "button_guard", 16, 0, "beat 3")
	_check_enemy(enemies, 2, "fray_scavenger", 14, 2, "beat 3")

	# No third source is announced and no extra hit is dealt.
	_check(announced.size() == 2, "beat 3 announces exactly two source actions")
	_check(announced[0].get("enemy_position") == 1
		and announced[1].get("enemy_position") == 2,
		"beat 3 announces slot 1 then slot 2 and nothing else")


## AC3: the three beats also run back to back on one party and roster, with
## the real owner-turn boundary between them, so Exposed expires at the
## Warder's own turn end instead of lasting through the whole fight.
func _test_sequential_replay() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	_check(CombatStartingBlock.new(party).apply(), "sequential fixture grants the opening Block")
	var scheduler := CombatEnemyIntents.new(_parsed())
	var events: Array = []

	# Beat 1.
	events.append(phase.execute_phase(party, enemies, scheduler.get_intents()))
	_check(events[0] == {"ok": true, "events": _expected_events(0)},
		"sequential beat 1 resolves the slot-1 Exposed then the slot-2 attack")
	_check_hero(party, 1, "warden", 40, 0, "sequential beat 1")
	_check(party.get_hero(1).get("statuses", {}) == {"exposed": 1},
		"sequential beat 1 leaves Exposed 1 on the Warden")
	_check(_tick_enemies(enemies), "the enemy owner tick after beat 1 succeeds")
	_check(scheduler.advance_turn(), "advance to beat 2")
	_check(party.start_player_turn(), "the new player turn resets hero Block")

	# The hero owner turn ends here: Exposed 1 ages out at the Warder's own
	# turn boundary instead of lasting forever.
	_check(_tick_heroes(party), "the hero owner tick before beat 2 succeeds")
	_check(party.get_hero(1).get("statuses", {}) == {},
		"Exposed 1 expires at the Warden's owner-turn boundary")
	_check_hero(party, 1, "warden", 40, 0, "after the owner tick")

	# Beat 2.
	events.append(phase.execute_phase(party, enemies, scheduler.get_intents()))
	_check(events[1] == {"ok": true, "events": _expected_events(1)},
		"sequential beat 2 resolves the slot-1 Block then the slot-2 attack")
	_check_hero(party, 1, "warden", 40, 0, "sequential beat 2")
	_check_hero(party, 2, "seamstress", 30, 0, "sequential beat 2")
	_check_hero(party, 3, "tinker", 23, 0, "sequential beat 2")
	_check_enemy(enemies, 1, "button_guard", 16, 2, "sequential beat 2")
	_check_enemy(enemies, 2, "fray_scavenger", 14, 0, "sequential beat 2")
	_check(_tick_enemies(enemies), "the enemy owner tick after beat 2 succeeds")
	_check(scheduler.advance_turn(), "advance to beat 3")
	_check(party.start_player_turn(), "the next player turn resets hero Block")

	# Beat 3.
	_check(_tick_heroes(party), "the hero owner tick before beat 3 succeeds")
	events.append(phase.execute_phase(party, enemies, scheduler.get_intents()))
	_check(events[2] == {"ok": true, "events": _expected_events(2)},
		"sequential beat 3 resolves the slot-1 attack then the slot-2 buff")
	_check_hero(party, 1, "warden", 40, 0, "sequential beat 3")
	_check_hero(party, 2, "seamstress", 27, 0, "sequential beat 3")
	_check_hero(party, 3, "tinker", 23, 0, "sequential beat 3")
	_check_enemy(enemies, 1, "button_guard", 16, 2, "sequential beat 3")
	_check_enemy(enemies, 2, "fray_scavenger", 14, 2, "sequential beat 3")
	_check(scheduler.advance_turn(), "advance past the third beat")
	_check(scheduler.get_intents() == _expected_beat(0),
		"after exactly three advances the schedule announces its first intents again")


## AC3: two independently initialized copies of the same authored data agree in
## every event and every surviving field over the whole three-beat timeline.
func _play_three_beats() -> Dictionary:
	var party := _build_party()
	var enemies := _build_enemies()
	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "replay precondition: the Warden opening Block applies")
	var scheduler := CombatEnemyIntents.new(_parsed())
	var announced: Array = []
	var events: Array = []
	var hero_snapshots: Array = []
	var enemy_snapshots: Array = []
	for beat in range(3):
		_check(_tick_heroes(party), "replay hero owner tick before beat %d" % (beat + 1))
		announced.append(scheduler.get_intents().duplicate(true))
		events.append(phase.execute_phase(party, enemies, scheduler.get_intents()))
		hero_snapshots.append(party.get_heroes().duplicate(true))
		enemy_snapshots.append(enemies.get_enemies().duplicate(true))
		_check(scheduler.advance_turn(), "replay advance after beat %d" % (beat + 1))
		_check(_tick_enemies(enemies), "replay enemy owner tick after beat %d" % (beat + 1))
		if beat < 2:
			_check(party.start_player_turn(), "replay player reset after beat %d" % (beat + 1))
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
	_check(first["heroes"][0]["id"] == "warden" and first["heroes"][0]["hp"] == 40
		and first["heroes"][0]["block"] == 0
		and first["heroes"][0].get("statuses", {}) == {},
		"the replay ends with the Warden at the front, 40 HP, 0 Block and no status")
	_check(first["heroes"][1]["id"] == "seamstress" and first["heroes"][1]["hp"] == 27
		and first["heroes"][1]["block"] == 0,
		"the replay ends with the Seamstress in the middle at 27 HP and 0 Block")
	_check(first["heroes"][2]["id"] == "tinker" and first["heroes"][2]["hp"] == 23
		and first["heroes"][2]["block"] == 0,
		"the replay ends with Tinker at the rear at 23 HP and 0 Block")
	_check(first["enemies"][0]["id"] == "button_guard" and first["enemies"][0]["hp"] == 16
		and first["enemies"][0]["block"] == 2,
		"the replay ends with the Button Guard at 16 HP and 2 Block")
	_check(first["enemies"][1]["id"] == "fray_scavenger" and first["enemies"][1]["hp"] == 14
		and first["enemies"][1]["block"] == 2,
		"the replay ends with the Fray Scavenger at 14 HP and 2 Block")
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


## AC4: malformed schedules, malformed phases and illegal recipients fail
## closed without publishing a side effect on party, enemies or the RNG.
func _test_negative_fail_closed() -> void:
	var malformed: Array = []
	malformed.append({"label": "slot-1 Exposed without target_position",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": 1, "status": "exposed"})})
	malformed.append({"label": "slot-1 Exposed without status",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": 1, "target_position": 1})})
	malformed.append({"label": "slot-1 Exposed with an unknown status",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": 1, "target_position": 1,
			"status": "poison"})})
	malformed.append({"label": "slot-1 Exposed with amount 0",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": 0, "target_position": 1,
			"status": "exposed"})})
	malformed.append({"label": "slot-1 Exposed with amount -1",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": -1, "target_position": 1,
			"status": "exposed"})})
	malformed.append({"label": "slot-1 Exposed with a string amount",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": "1", "target_position": 1,
			"status": "exposed"})})
	malformed.append({"label": "slot-1 Exposed with a fractional amount",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": 1.5, "target_position": 1,
			"status": "exposed"})})
	malformed.append({"label": "slot-1 Exposed with target 0",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": 1, "target_position": 0,
			"status": "exposed"})})
	malformed.append({"label": "slot-1 Exposed with target 4",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": 1, "target_position": 4,
			"status": "exposed"})})
	malformed.append({"label": "slot-1 Exposed with a fractional target",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": 1, "target_position": 1.5,
			"status": "exposed"})})
	malformed.append({"label": "slot-1 Exposed with an extra key",
		"data": _with_beat(1, 0, {"type": "debuff", "amount": 1, "target_position": 1,
			"status": "exposed", "extra": 1})})
	malformed.append({"label": "slot-1 Block with a target",
		"data": _with_beat(1, 1, {"type": "block", "amount": 2, "target_position": 1})})
	malformed.append({"label": "slot-1 Block with a fractional amount",
		"data": _with_beat(1, 1, {"type": "block", "amount": 2.5})})
	malformed.append({"label": "slot-1 attack without target_position",
		"data": _with_beat(1, 2, {"type": "attack", "amount": 3})})
	malformed.append({"label": "slot-1 attack with target 0",
		"data": _with_beat(1, 2, {"type": "attack", "amount": 3, "target_position": 0})})
	malformed.append({"label": "slot-1 attack with target 4",
		"data": _with_beat(1, 2, {"type": "attack", "amount": 3, "target_position": 4})})
	malformed.append({"label": "slot-1 attack with an extra key",
		"data": _with_beat(1, 2, {"type": "attack", "amount": 3, "target_position": 2,
			"extra": 1})})
	malformed.append({"label": "slot-1 attack with amount -1",
		"data": _with_beat(1, 2, {"type": "attack", "amount": -1, "target_position": 2})})
	malformed.append({"label": "slot-1 attack with a string amount",
		"data": _with_beat(1, 2, {"type": "attack", "amount": "3", "target_position": 2})})
	malformed.append({"label": "slot-1 attack with a fractional amount",
		"data": _with_beat(1, 2, {"type": "attack", "amount": 3.5, "target_position": 2})})
	malformed.append({"label": "slot-2 attack without target_position",
		"data": _with_beat(2, 0, {"type": "attack", "amount": 4})})
	malformed.append({"label": "slot-2 attack with target 0",
		"data": _with_beat(2, 0, {"type": "attack", "amount": 4, "target_position": 0})})
	malformed.append({"label": "slot-2 attack with target 4",
		"data": _with_beat(2, 0, {"type": "attack", "amount": 4, "target_position": 4})})
	malformed.append({"label": "slot-2 attack with a string amount",
		"data": _with_beat(2, 0, {"type": "attack", "amount": "4", "target_position": 1})})
	malformed.append({"label": "slot-2 attack (beat 2) without target_position",
		"data": _with_beat(2, 1, {"type": "attack", "amount": 3})})
	malformed.append({"label": "slot-2 buff with amount 0",
		"data": _with_beat(2, 2, {"type": "buff", "amount": 0})})
	malformed.append({"label": "slot-2 buff with a fractional amount",
		"data": _with_beat(2, 2, {"type": "buff", "amount": 2.5})})
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
	var extra_source_key: Array = _expected_definitions().duplicate(true)
	extra_source_key[0]["note"] = "extra"
	malformed.append({"label": "source with an extra key", "data": extra_source_key})
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
	_check(_with_beat(1, 0, {"type": "debuff", "amount": 1, "target_position": 0,
		"status": "exposed"}) != _expected_definitions(),
		"negative: the beat mutation helper really produces a different schedule")

	# A downed Exposed recipient fails the whole phase closed, after the
	# earlier source would have staged a real state change.
	var party := _build_party()
	var enemies := _build_enemies()
	_check(CombatStartingBlock.new(party).apply(), "negative: the opening Block applies")
	_check(party.apply_damage(1, 46) and party.is_downed(1), "negative: the Warden is downed")
	var before_party := party.get_heroes()
	var before_enemies := enemies.get_enemies()
	seed(RNG_SEED)
	var expected_rng := randi()
	seed(RNG_SEED)
	var downed := phase.execute_phase(party, enemies,
		CombatEnemyIntents.new(_parsed()).get_intents())
	_check(randi() == expected_rng, "negative: a rejected phase draws no global RNG")
	_check(downed == {"ok": false, "events": []},
		"negative: Exposed on a downed hero rejects the whole phase")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"negative: a rejected downed-target phase changes no hero and no enemy")
	_check(party.get_hero(1).get("hp") == 0 and party.get_hero(1).get("block") == 0,
		"negative: the rejected phase neither heals nor blocks the Warden")
	_check(party.get_hero(1).get("statuses", {}) == {},
		"negative: the rejected phase applies no Exposed to the downed Warden")
	_check(party.get_hero(2).get("hp") == 30 and party.get_hero(3).get("hp") == 26,
		"negative: the rejected phase deals no damage to the other heroes")

	# A phase with a duplicated source position is rejected whole.
	party = _build_party()
	enemies = _build_enemies()
	before_party = party.get_heroes()
	before_enemies = enemies.get_enemies()
	seed(RNG_SEED)
	expected_rng = randi()
	seed(RNG_SEED)
	var duplicated := phase.execute_phase(party, enemies, [
		{"type": "debuff", "amount": 1, "target_position": 1, "status": "exposed",
			"enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 1}])
	_check(randi() == expected_rng, "negative: a duplicated source draws no global RNG")
	_check(duplicated == {"ok": false, "events": []},
		"negative: a duplicated source position rejects the phase")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"negative: the duplicated-source phase changes nothing")

	# A source outside this encounter's two-enemy roster fails closed.
	party = _build_party()
	enemies = _build_enemies()
	before_party = party.get_heroes()
	before_enemies = enemies.get_enemies()
	seed(RNG_SEED)
	expected_rng = randi()
	seed(RNG_SEED)
	var outside := phase.execute_phase(party, enemies, [
		{"type": "block", "amount": 2, "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 3}])
	_check(randi() == expected_rng, "negative: an out-of-roster source draws no global RNG")
	_check(outside == {"ok": false, "events": []},
		"negative: a source outside the roster rejects the phase")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"negative: the out-of-roster phase changes nothing")

	# A malformed action inside a phase is rejected whole.
	party = _build_party()
	enemies = _build_enemies()
	before_party = party.get_heroes()
	before_enemies = enemies.get_enemies()
	var malformed_action := _expected_beat_1().duplicate(true)
	malformed_action[1]["amount"] = "4"
	seed(RNG_SEED)
	expected_rng = randi()
	seed(RNG_SEED)
	var bad_action := phase.execute_phase(party, enemies, malformed_action)
	_check(randi() == expected_rng, "negative: a malformed action draws no global RNG")
	_check(bad_action == {"ok": false, "events": []},
		"negative: a malformed slot-2 action rejects the phase")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"negative: the malformed phase applies no Exposed and no damage")
	_check(party.get_hero(1).get("statuses", {}) == {},
		"negative: the malformed phase leaves the Warden without Exposed")


## AC4: the earlier named schedule still parses and still owns its own source
## records; this encounter never patches it.
func _test_companion_encounter_intact() -> void:
	var companion := RunFightEncounterSelection._parse_schedule_text(_read_text(COMPANION_PATH))
	_check(not companion.is_empty(), "the earlier rearline_needlemark schedule still parses")
	_check(CombatEnemyIntents.new(companion).is_valid(),
		"the earlier rearline_needlemark schedule still validates")
	_check(companion != _parsed(),
		"the new schedule differs from the earlier rearline_needlemark schedule")
	var expected_companion := [
		{"enemy_position": 1, "pattern": [
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed"},
			{"type": "block", "amount": 2},
			{"type": "attack", "amount": 2, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 4, "target_position": 3},
			{"type": "attack", "amount": 3, "target_position": 1},
			{"type": "buff", "amount": 2}]},
	]
	for position in [1, 2]:
		var matches: Array = []
		for entry in companion:
			if entry is Dictionary and entry.get("enemy_position") == position:
				matches.append(entry)
		_check(matches.size() == 1,
			"the earlier schedule still holds exactly one source at enemy_position %d" % position)
		if matches.size() == 1:
			_check(matches[0].get("pattern") == expected_companion[position - 1]["pattern"],
				"the earlier schedule's source %d keeps its own pattern" % position)
	# The authored file on disk is unchanged by any of this.
	_check(_parsed() == _expected_definitions(),
		"the new encounter JSON is unchanged after all parser reads")
	_check(RunFightEncounterSelection._parse_schedule_text(_read_text(COMPANION_PATH))
		== expected_companion,
		"the earlier rearline_needlemark JSON is unchanged after parser reads")
