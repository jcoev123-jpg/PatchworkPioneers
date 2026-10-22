extends SceneTree
## Standalone M04 Fight regression for the unregistered encounter
## "spoolfray_crosscut" (Fray Scavenger + Spool Stalker).
##
## Scope: data and services only. This encounter is bound here in a
## test-local typed Fight choice and roster map, so the shared typed battle
## pools, the app flow and every other encounter stay untouched.
##
## The test drives the real services only:
##   RunFightEncounterSelection._parse_schedule_text -> authored schedule
##   CombatEnemyIntents                           -> fixed-cycle announcements
##   CombatEnemyPhase                             -> staged, published phase
##   RunTypedBattleRoster                         -> real catalog roster

const HERO_CATALOG_PATH := "res://data/heroes/starter_party.json"
const ENEMY_CATALOG_PATH := "res://data/enemies/run_enemies.json"
const ENCOUNTER_PATH := "res://data/encounters/spoolfray_crosscut.json"
const PRIOR_ENCOUNTER_PATH := "res://data/encounters/spoolbridge_staggered_exposure.json"
const ENCOUNTER_ID := "spoolfray_crosscut"

## This encounter's own roster binding, owned by this test: source slot 1 is
## the Fray Scavenger and source slot 2 the Spool Stalker, in that order.
const LOCAL_ROSTER_MAP := {
	ENCOUNTER_ID: ["fray_scavenger", "spool_stalker"],
}

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_verify_failure_harness()
	_verify_ac1_authored_schedule_and_cycle()
	_verify_ac2_typed_roster_assembly()
	_verify_ac3_three_beat_phase_ledger()
	_verify_ac4_downed_shove_rejection_and_prior_schedule()
	if failures.is_empty():
		print("spoolfray_crosscut_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("spoolfray_crosscut_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String, sink: Array[String] = failures) -> void:
	checks += 1
	if not condition:
		sink.append(message)


## A failing check must really reach the failure list, so a green run cannot
## hide an assertion that never fires.
func _verify_failure_harness() -> void:
	var probe_failures: Array[String] = []
	_check(false, "deliberate failure probe", probe_failures)
	_check(probe_failures.size() == 1 and probe_failures[0] == "deliberate failure probe",
		"Failure harness did not record a deliberately failing check.")


# --- shared helpers -------------------------------------------------------

func _read_text(path: String) -> String:
	_check(FileAccess.file_exists(path), "Expected file to exist: %s" % path)
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "Expected file to open: %s" % path)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


## Godot's JSON parser may yield whole numbers as floats. Verify a number is
## integral before any coercion, so truncated data can never pass as authored.
func _is_integral_number(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float or is_nan(value) or is_inf(value):
		return false
	return absf(value) <= 9007199254740991.0 and floorf(value) == value


## The real model services require ints, so catalog numbers are normalized
## exactly and only when they are already whole.
func _normalize_numbers(data: Variant) -> Variant:
	if data is Array:
		var items: Array = []
		for item in data:
			items.append(_normalize_numbers(item))
		return items
	if data is Dictionary:
		var record: Dictionary = {}
		for key in data:
			record[key] = _normalize_numbers(data[key])
		return record
	if data is float and is_finite(data) and floorf(data) == data:
		return int(data)
	return data


func _load_json_array(path: String) -> Array:
	var text := _read_text(path)
	if text.is_empty():
		return []
	var parser := JSON.new()
	var err := parser.parse(text)
	_check(err == OK, "Expected valid JSON in %s" % path)
	if err != OK or not parser.data is Array:
		_check(false, "Expected a top-level JSON Array in %s" % path)
		return []
	var normalized: Variant = _normalize_numbers(parser.data)
	if not normalized is Array:
		return []
	return normalized


## Locate a record by a stable key and require EXACTLY one match, so a
## duplicated record can never pass as the intended one. Catalog totals and
## ordered catalog lists are never asserted: other lanes append to them.
func _find_unique_by_key(records: Array, key: String, expected_value: Variant, label: String) -> Dictionary:
	var matches: Array[Dictionary] = []
	for record in records:
		if record is Dictionary and record.get(key) == expected_value:
			matches.append(record.duplicate(true))
	_check(matches.size() == 1, "Expected exactly 1 record with %s=%s in %s, found %d"
		% [key, str(expected_value), label, matches.size()])
	if matches.size() != 1:
		return {}
	return matches[0]


## The shipped starter party, in slot order, built from the real catalog.
func _build_catalog_party() -> CombatParty:
	var heroes := _load_json_array(HERO_CATALOG_PATH)
	var definitions: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		definitions.append(_find_unique_by_key(heroes, "id", id, HERO_CATALOG_PATH))
	return CombatParty.new(definitions)


## The real two-enemy roster for this encounter, assembled by the real
## typed-roster bridge from the shipped run-enemy catalog records.
func _assemble_local_enemies(definitions: Array) -> CombatEnemies:
	var typed_choice := {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": definitions.duplicate(true),
	}
	var assembled := RunTypedBattleRoster.new().assemble(
		typed_choice, LOCAL_ROSTER_MAP.duplicate(true), [ENEMY_CATALOG_PATH])
	_check(assembled.get("ok", false), "RunTypedBattleRoster must assemble this encounter's two enemies.")
	if not assembled.get("ok", false):
		return CombatEnemies.new([])
	var enemies: Variant = assembled.get("enemies")
	if enemies is CombatEnemies:
		return enemies
	_check(false, "The assembled roster must be a real CombatEnemies instance.")
	return CombatEnemies.new([])


# --- the prescribed schedule, written out literally ------------------------

## The exact authored schedule, independent of the file on disk.
func _expected_definitions() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "debuff", "amount": 1, "target_position": 2, "status": "exposed"},
			{"type": "block", "amount": 3},
			{"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
		]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 4, "target_position": 2},
			{"type": "attack", "amount": 4, "target_position": 3},
			{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed"},
		]},
	]


## The literal announced beat, built from the prescription above.
func _expected_beat(beat: int) -> Array:
	var actions: Array = []
	for definition in _expected_definitions():
		var pattern: Array = definition["pattern"]
		var action: Dictionary = pattern[beat % pattern.size()].duplicate(true)
		action["enemy_position"] = definition["enemy_position"]
		actions.append(action)
	return actions


## The literal published phase events of one beat.
func _expected_events(beat: int) -> Array:
	var events: Array = []
	for intent in _expected_beat(beat):
		var event := {"type": intent["type"], "enemy_position": intent["enemy_position"], "applied": true}
		for field in ["target_position", "status", "direction"]:
			if intent.has(field):
				event[field] = intent[field]
		events.append(event)
	return events


## The complete expected party snapshot: the given hero order with the given
## HP, Block and statuses, keeping every other authored field of the real
## hero record.
func _expected_party(order: Array, hp_by_id: Dictionary, block_by_id: Dictionary,
		statuses_by_id: Dictionary) -> Array:
	var by_id: Dictionary = {}
	for hero in _load_json_array(HERO_CATALOG_PATH):
		by_id[hero["id"]] = hero
	var expected: Array = []
	for index in range(order.size()):
		var id: String = order[index]
		var hero: Dictionary = by_id[id].duplicate(true)
		hero["position"] = index + 1
		hero["hp"] = hp_by_id[id]
		hero["block"] = block_by_id.get(id, 0)
		if statuses_by_id.has(id):
			hero["statuses"] = statuses_by_id[id].duplicate(true)
		expected.append(hero)
	return expected


## One hero of the authoritative party: id, position, HP, Block and statuses.
func _hero_state(party: CombatParty, position: int) -> Dictionary:
	var hero: Dictionary = party.get_hero(position)
	return {"id": hero.get("id"), "position": hero.get("position"), "hp": hero.get("hp"),
		"block": hero.get("block"), "statuses": hero.get("statuses", {})}


# --- AC1: the authored schedule and the 1/2/3/1 cycle ----------------------

func _verify_ac1_authored_schedule_and_cycle() -> void:
	var raw_text := _read_text(ENCOUNTER_PATH)
	_check(not raw_text.is_empty(), "The authored encounter file must exist and be readable.")

	# 1. The authored file itself: exactly two source records of three actions
	#    each, with integral numbers before any coercion.
	var raw := _load_json_array(ENCOUNTER_PATH)
	_check(raw.size() == 2, "spoolfray_crosscut.json must hold exactly two enemy source records.")
	for raw_definition in raw:
		_check(raw_definition is Dictionary, "Each authored source record must be a Dictionary.")
		if not raw_definition is Dictionary:
			continue
		_check(_is_integral_number(raw_definition.get("enemy_position")),
			"Each raw enemy_position must be integral before coercion.")
		var raw_pattern: Variant = raw_definition.get("pattern", [])
		_check(raw_pattern is Array and raw_pattern.size() == 3,
			"Each raw pattern must be a three-action Array.")
		if not raw_pattern is Array:
			continue
		for raw_action in raw_pattern:
			_check(raw_action is Dictionary, "Each raw action must be a Dictionary.")
			if not raw_action is Dictionary:
				continue
			_check(_is_integral_number(raw_action.get("amount")), "Each raw amount must be integral.")
			if raw_action.has("target_position"):
				_check(_is_integral_number(raw_action.get("target_position")),
					"Each raw target_position must be integral.")
			if raw_action.has("direction"):
				_check(_is_integral_number(raw_action.get("direction")),
					"Each raw direction must be integral.")

	# 2. The production parser accepts the file and normalizes it.
	var definitions := RunFightEncounterSelection._parse_schedule_text(raw_text)
	_check(definitions.size() == 2, "RunFightEncounterSelection._parse_schedule_text must return two definitions.")
	_check(definitions == _expected_definitions(), "The parsed schedule must equal the prescribed schedule exactly.")
	for parsed_definition in definitions:
		_check(typeof(parsed_definition.get("enemy_position")) == TYPE_INT,
			"A parsed enemy_position must be TYPE_INT after coercion.")
		var parsed_pattern: Array = parsed_definition.get("pattern", [])
		for parsed_action in parsed_pattern:
			_check(typeof(parsed_action.get("amount")) == TYPE_INT,
				"A parsed action amount must be TYPE_INT after coercion.")
			if parsed_action.has("target_position"):
				_check(typeof(parsed_action.get("target_position")) == TYPE_INT,
					"A parsed target_position must be TYPE_INT after coercion.")
			if parsed_action.has("direction"):
				_check(typeof(parsed_action.get("direction")) == TYPE_INT,
					"A parsed direction must be TYPE_INT after coercion.")

	# 3. Every source is located by its own position and keeps its exact
	#    three-beat pattern.
	for position in [1, 2]:
		var source := _find_unique_by_key(definitions, "enemy_position", position, ENCOUNTER_PATH)
		_check(source.get("pattern") == _expected_definitions()[position - 1]["pattern"],
			"Source %d must keep its exact prescribed three-beat pattern." % position)

	# 4. The real intent validator accepts the schedule.
	var intents := CombatEnemyIntents.new(definitions)
	_check(intents.is_valid(), "CombatEnemyIntents must validate the parsed schedule.")

	# 5. The fixed cycle announces beats 1, 2, 3 and then repeats beat 1.
	var timeline: Array = []
	for beat in range(5):
		var announced: Array[Dictionary] = intents.get_intents()
		_check(announced == _expected_beat(beat), "Beat %d must announce the prescribed actions." % (beat + 1))
		_check(announced.size() == 2 and announced[0].get("enemy_position") == 1
				and announced[1].get("enemy_position") == 2,
			"Beat %d must announce source slot 1 before source slot 2." % (beat + 1))
		timeline.append(announced)
		_check(intents.advance_turn(), "The schedule must advance past beat %d." % (beat + 1))
	_check(timeline[3] == _expected_beat(0), "The fourth announced beat must repeat beat 1.")
	_check(timeline[4] == _expected_beat(1), "The fifth announced beat must continue with beat 2.")

	# A fresh instance replays the identical timeline, including the wrap.
	var replay_timeline: Array = []
	var replay_intents := CombatEnemyIntents.new(definitions)
	for _beat in range(5):
		replay_timeline.append(replay_intents.get_intents())
		replay_intents.advance_turn()
	_check(replay_timeline == timeline, "A fresh CombatEnemyIntents must replay the identical 1/2/3/1 timeline.")

	# The authored file is still valid after every read.
	_check(RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH)) == _expected_definitions(),
		"The authored schedule must remain valid after all parser reads.")


# --- AC2: the typed roster -------------------------------------------------

func _verify_ac2_typed_roster_assembly() -> void:
	# The two named run enemies exist by ID in the shipped catalog. No catalog
	# total and no ordered catalog list is asserted.
	var catalog := _load_json_array(ENEMY_CATALOG_PATH)
	var scavenger := _find_unique_by_key(catalog, "id", "fray_scavenger", ENEMY_CATALOG_PATH)
	var stalker := _find_unique_by_key(catalog, "id", "spool_stalker", ENEMY_CATALOG_PATH)
	_check(scavenger.get("name") == "Fray Scavenger" and scavenger.get("max_hp") == 14,
		"The shipped Fray Scavenger must keep its name and 14 max HP.")
	_check(stalker.get("name") == "Spool Stalker" and stalker.get("max_hp") == 14,
		"The shipped Spool Stalker must keep its name and 14 max HP.")
	_check(scavenger.get("art_path") == "res://assets/paper/enemies/fray_scavenger.png",
		"The shipped Fray Scavenger must keep its existing art path.")
	_check(stalker.get("art_path") == "res://assets/paper/enemies/spool_stalker.png",
		"The shipped Spool Stalker must keep its existing art path.")

	# The test-local typed Fight choice and the local roster binding.
	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	var typed_choice := {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": definitions.duplicate(true),
	}
	var bound_ids: Array = LOCAL_ROSTER_MAP.get(ENCOUNTER_ID, [])
	_check(bound_ids == ["fray_scavenger", "spool_stalker"],
		"The local roster must bind the Fray Scavenger to source 1 and the Spool Stalker to source 2.")

	var assembled := RunTypedBattleRoster.new().assemble(
		typed_choice, LOCAL_ROSTER_MAP.duplicate(true), [ENEMY_CATALOG_PATH])
	_check(assembled.get("ok") == true, "RunTypedBattleRoster.assemble must succeed for the local fixture.")
	_check(assembled.get("node_type") == "Fight", "The assembled roster must report the Fight node type.")
	_check(assembled.get("encounter_id") == ENCOUNTER_ID, "The assembled roster must report this encounter's own ID.")
	_check(assembled.get("definitions") == _expected_definitions(),
		"The assembled roster must carry the exact parsed definitions.")

	var enemies: Variant = assembled.get("enemies")
	_check(enemies is CombatEnemies, "The assembled roster must be a real CombatEnemies instance.")
	if enemies is CombatEnemies:
		_check(enemies.is_valid(), "The assembled roster must be valid.")
		_check(enemies.get_enemies().size() == 2, "The assembled roster must hold exactly two source slots.")
		var slot_1: Dictionary = enemies.get_enemy(1)
		var slot_2: Dictionary = enemies.get_enemy(2)
		_check(slot_1.get("id") == "fray_scavenger" and slot_1.get("position") == 1
				and slot_1.get("max_hp") == 14 and slot_1.get("hp") == 14 and slot_1.get("block") == 0,
			"Source slot 1 must be the Fray Scavenger with 14/14 HP and 0 Block.")
		_check(slot_2.get("id") == "spool_stalker" and slot_2.get("position") == 2
				and slot_2.get("max_hp") == 14 and slot_2.get("hp") == 14 and slot_2.get("block") == 0,
			"Source slot 2 must be the Spool Stalker with 14/14 HP and 0 Block.")

	# The assembled roster is independent of the caller's choice.
	_check(typed_choice.get("definitions") == _expected_definitions(),
		"Assembling the roster must not change the caller's typed choice.")


# --- AC3: three real enemy-phase beats -------------------------------------

func _verify_ac3_three_beat_phase_ledger() -> void:
	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	_check(definitions == _expected_definitions(), "The parsed schedule must be canonical before the beats run.")

	var party := _build_catalog_party()
	var enemies := _assemble_local_enemies(definitions)
	_check(party.is_valid(), "The catalog party must be a valid CombatParty.")
	_check(enemies.is_valid(), "The assembled roster must be a valid CombatEnemies.")

	# The Warden's start-of-combat passive is applied exactly once.
	var starting_block := CombatStartingBlock.new(party)
	_check(starting_block.apply(), "CombatStartingBlock.apply() must grant the Warden 6 opening Block.")
	_check(not starting_block.apply(), "A second CombatStartingBlock.apply() must fail closed as one-shot.")
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("hp") == 40
			and party.get_hero(1).get("block") == 6 and party.get_hero(1).get("statuses", {}) == {},
		"Opening slot 1 must be the Warden with 40 HP, 6 Block and no statuses.")
	_check(party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 30
			and party.get_hero(2).get("block") == 0 and party.get_hero(2).get("statuses", {}) == {},
		"Opening slot 2 must be the Seamstress with 30 HP, 0 Block and no statuses.")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 26
			and party.get_hero(3).get("block") == 0 and party.get_hero(3).get("statuses", {}) == {},
		"Opening slot 3 must be the Tinker with 26 HP, 0 Block and no statuses.")
	_check(enemies.get_enemy(1).get("hp") == 14 and enemies.get_enemy(1).get("block") == 0
			and enemies.get_enemy(2).get("hp") == 14 and enemies.get_enemy(2).get("block") == 0,
		"Both enemy sources must start at 14 HP with 0 Block.")

	# Exposed N raises incoming attack damage by 50%, rounded down.
	_check(CombatStatuses.new().adjusted_attack_damage(4, {}, {"exposed": 1}) == 6,
		"Exposed 1 must raise a base 4 attack to floor(4 * 1.5) = 6.")

	var intents := CombatEnemyIntents.new(definitions)
	var phase := CombatEnemyPhase.new()

	# Beat 1: source 1 Exposes the Seamstress (slot 2), then source 2's base
	# 4 attack on that slot becomes 6.
	var beat_1 := phase.execute_phase(party, enemies, intents.get_intents())
	_check(beat_1 == {"ok": true, "events": _expected_events(0)},
		"Beat 1 must publish the Exposed debuff and the 6-damage hit in source order.")
	_check(beat_1.get("events", []).size() == 2, "Beat 1 must publish exactly two events.")
	_check(_hero_state(party, 1) == {"id": "warden", "position": 1, "hp": 40, "block": 6, "statuses": {}},
		"After beat 1 the Warden must keep 40 HP, 6 Block and no statuses.")
	_check(_hero_state(party, 2) == {"id": "seamstress", "position": 2, "hp": 24, "block": 0,
			"statuses": {"exposed": 1}},
		"After beat 1 the Seamstress must be at 24 HP with Exposed 1.")
	_check(_hero_state(party, 3) == {"id": "tinker", "position": 3, "hp": 26, "block": 0, "statuses": {}},
		"After beat 1 the Tinker must keep 26 HP, 0 Block and no statuses.")
	_check(enemies.get_enemy(1).get("id") == "fray_scavenger" and enemies.get_enemy(1).get("hp") == 14
			and enemies.get_enemy(1).get("block") == 0,
		"After beat 1 the Fray Scavenger must keep 14 HP and 0 Block.")
	_check(enemies.get_enemy(2).get("id") == "spool_stalker" and enemies.get_enemy(2).get("hp") == 14
			and enemies.get_enemy(2).get("block") == 0,
		"After beat 1 the Spool Stalker must keep 14 HP and 0 Block.")

	# Beat 2: source 1 gains 3 Block, source 2 hits the Tinker (slot 3) for 4.
	_check(intents.advance_turn(), "Advancing the schedule from beat 1 to beat 2 must succeed.")
	var beat_2 := phase.execute_phase(party, enemies, intents.get_intents())
	_check(beat_2 == {"ok": true, "events": _expected_events(1)},
		"Beat 2 must publish the enemy Block and the 4-damage hit in source order.")
	_check(beat_2.get("events", []).size() == 2, "Beat 2 must publish exactly two events.")
	_check(_hero_state(party, 1) == {"id": "warden", "position": 1, "hp": 40, "block": 6, "statuses": {}},
		"After beat 2 the Warden must keep 40 HP, 6 Block and no statuses.")
	_check(_hero_state(party, 2) == {"id": "seamstress", "position": 2, "hp": 24, "block": 0,
			"statuses": {"exposed": 1}},
		"After beat 2 the Seamstress must keep 24 HP and her Exposed 1.")
	_check(_hero_state(party, 3) == {"id": "tinker", "position": 3, "hp": 22, "block": 0, "statuses": {}},
		"After beat 2 the Tinker must be at 22 HP with no status.")
	_check(enemies.get_enemy(1).get("id") == "fray_scavenger" and enemies.get_enemy(1).get("hp") == 14
			and enemies.get_enemy(1).get("block") == 3,
		"After beat 2 the Fray Scavenger must hold exactly 3 Block.")
	_check(enemies.get_enemy(2).get("id") == "spool_stalker" and enemies.get_enemy(2).get("hp") == 14
			and enemies.get_enemy(2).get("block") == 0,
		"After beat 2 the Spool Stalker must keep 14 HP and 0 Block.")

	# Beat 3: source 1 shoves slot 2 back, then source 2 attaches Bleed 2 to
	# the new occupant of slot 2.
	_check(intents.advance_turn(), "Advancing the schedule from beat 2 to beat 3 must succeed.")
	var beat_3 := phase.execute_phase(party, enemies, intents.get_intents())
	_check(beat_3 == {"ok": true, "events": _expected_events(2)},
		"Beat 3 must publish the shove and the Bleed in source order.")
	_check(beat_3.get("events", []).size() == 2, "Beat 3 must publish exactly two events.")
	_check(_hero_state(party, 1) == {"id": "warden", "position": 1, "hp": 40, "block": 6, "statuses": {}},
		"After beat 3 the Warden must hold slot 1 with 40 HP, 6 Block and no statuses.")
	_check(_hero_state(party, 2) == {"id": "tinker", "position": 2, "hp": 22, "block": 0,
			"statuses": {"bleed": 2}},
		"After beat 3 the Tinker must hold slot 2 with 22 HP and Bleed 2.")
	_check(_hero_state(party, 3) == {"id": "seamstress", "position": 3, "hp": 24, "block": 0,
			"statuses": {"exposed": 1}},
		"After beat 3 the Seamstress must hold slot 3 with 24 HP and her Exposed 1.")
	_check(enemies.get_enemy(1).get("id") == "fray_scavenger" and enemies.get_enemy(1).get("hp") == 14
			and enemies.get_enemy(1).get("block") == 3,
		"After beat 3 the Fray Scavenger must still hold exactly 3 Block.")
	_check(enemies.get_enemy(2).get("id") == "spool_stalker" and enemies.get_enemy(2).get("hp") == 14
			and enemies.get_enemy(2).get("block") == 0,
		"After beat 3 the Spool Stalker must keep 14 HP and 0 Block.")

	# The complete party snapshot after the three beats.
	_check(party.get_heroes() == _expected_party(["warden", "tinker", "seamstress"],
			{"warden": 40, "tinker": 22, "seamstress": 24},
			{"warden": 6, "tinker": 0, "seamstress": 0},
			{"tinker": {"bleed": 2}, "seamstress": {"exposed": 1}}),
		"After beat 3 the complete party snapshot must be Warden 40/6, Tinker 22 with Bleed 2, "
		+ "Seamstress 24 with Exposed 1.")

	# Bleed does not bite inside the enemy phase: the Tinker still holds 22 HP.
	_check(party.get_hero(2).get("hp") == 22,
		"No Bleed HP loss may happen before the Ticker's own turn ends.")

	# The announced cycle wraps back to the first beat.
	_check(intents.advance_turn(), "Advancing the schedule after beat 3 must succeed.")
	_check(intents.get_intents() == _expected_beat(0), "The announcements must wrap from beat 3 back to beat 1.")


# --- AC4: the atomic rejection of an illegal shove -------------------------

func _verify_ac4_downed_shove_rejection_and_prior_schedule() -> void:
	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	var party := _build_catalog_party()
	var enemies := _assemble_local_enemies(definitions)
	_check(CombatStartingBlock.new(party).apply(), "The opening Block must apply on the downed-destination fixture.")

	# Fixture preconditions: the shove mover (slot 2) stays alive while the
	# shove destination (slot 3) is the downed Tinker; both enemies live.
	_check(party.apply_damage(3, 26), "Downing the Tinker at slot 3 must succeed.")
	_check(party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 30
			and not party.is_downed(2),
		"The shove mover in slot 2 must stay alive before the phase runs.")
	_check(party.get_hero(3).get("id") == "tinker" and party.is_downed(3),
		"The shove destination in slot 3 must be the downed Tinker before the phase runs.")
	_check(not enemies.is_slain(1) and not enemies.is_slain(2),
		"Both enemy sources must stay alive before the phase runs.")

	# Announce only the third beat: the shove and the Bleed that follows it.
	var intents := CombatEnemyIntents.new(definitions)
	_check(intents.advance_turn(), "The schedule must advance to beat 2.")
	_check(intents.advance_turn(), "The schedule must advance to beat 3.")
	var beat_3: Array[Dictionary] = intents.get_intents()
	_check(beat_3 == _expected_beat(2),
		"The announced beat 3 must be the prescribed slot-2 shove followed by the slot-2 Bleed.")

	var party_before := party.get_heroes()
	var enemies_before := enemies.get_enemies()
	var phase := CombatEnemyPhase.new()
	var rejected := phase.execute_phase(party, enemies, beat_3)
	_check(rejected == {"ok": false, "events": []},
		"A shove into a downed destination must reject the whole beat with {ok: false, events: []}.")
	_check(party.get_heroes() == party_before,
		"The rejected beat must leave the authoritative party snapshot unchanged.")
	_check(enemies.get_enemies() == enemies_before,
		"The rejected beat must leave the authoritative enemy snapshot unchanged.")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6,
		"The rejected beat must not touch the Warden's HP or Block.")
	_check(party.get_hero(2).get("id") == "seamstress" and party.get_hero(3).get("id") == "tinker",
		"The rejected beat must leave the party order untouched.")
	_check(party.get_hero(2).get("statuses", {}) == {} and party.get_hero(3).get("statuses", {}) == {},
		"The rejected beat must not attach Bleed to the new slot-2 occupant.")

	# The named earlier encounter keeps its exact schedule and still parses.
	var prior := RunFightEncounterSelection._parse_schedule_text(_read_text(PRIOR_ENCOUNTER_PATH))
	_check(prior.size() == 2, "The named earlier schedule must still parse into two source records.")
	_check(prior == _expected_prior_definitions(),
		"The named earlier schedule must keep its exact per-source patterns.")
	_check(CombatEnemyIntents.new(prior).is_valid(),
		"The named earlier schedule must still validate in CombatEnemyIntents.")
	for position in [1, 2]:
		var source := _find_unique_by_key(prior, "enemy_position", position, PRIOR_ENCOUNTER_PATH)
		_check(source.get("pattern") == _expected_prior_definitions()[position - 1]["pattern"],
			"The named earlier schedule must keep source %d's exact three-beat pattern." % position)


## The named earlier encounter's own schedule, written out literally.
func _expected_prior_definitions() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed"},
			{"type": "attack", "amount": 3, "target_position": 2},
		]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 4, "target_position": 3},
			{"type": "attack", "amount": 5, "target_position": 3},
			{"type": "buff", "amount": 2},
		]},
	]
