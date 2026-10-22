extends SceneTree
## Focused, deterministic regression for the standalone M04 encounter
## stitchrail_triple_turn. It exercises the real schedule parser, intent
## cycle, enemy-phase resolver, typed roster bridge and seeded map selection.
## It never wires the encounter into the live map: that is a later milestone.

const HERO_CATALOG_PATH := "res://data/heroes/starter_party.json"
const ENEMY_CATALOG_PATH := "res://data/enemies/run_enemies.json"
const STITCHRAIL_PATH := "res://data/encounters/stitchrail_triple_turn.json"
const SPOOLCORD_PATH := "res://data/encounters/spoolcord_triad_relay.json"
const ENCOUNTER_ID := "stitchrail_triple_turn"

var failures: Array[String] = []
var checks := 0


func _init() -> void:
	_verify_failure_harness()
	_run_all_checks()
	if not failures.is_empty():
		for failure in failures:
			printerr(failure)
		print("stitchrail_triple_turn_encounter_test: FAIL (", failures.size(), " failures)")
		quit(1)
		return
	print("stitchrail_triple_turn_encounter_test: PASS (", checks, " checks)")
	quit(0)


func _check(condition: bool, message: String, sink: Array[String] = failures) -> void:
	checks += 1
	if not condition:
		sink.append(message)


func _verify_failure_harness() -> void:
	var probe_failures: Array[String] = []
	_check(false, "deliberate failure probe", probe_failures)
	if probe_failures.size() != 1 or probe_failures[0] != "deliberate failure probe":
		failures.append("Failure harness did not record a deliberately failing check.")


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


func _is_integral_number(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float or is_nan(value) or is_inf(value):
		return false
	return absf(value) <= 9007199254740991.0 and floorf(value) == value


func _load_json_array(path: String) -> Array:
	var text := _read_text(path)
	if text.is_empty():
		return []
	var parser := JSON.new()
	var err := parser.parse(text)
	_check(err == OK, "Expected valid JSON in %s" % path)
	if err != OK or not parser.data is Array:
		_check(false, "Expected top-level JSON Array in %s" % path)
		return []
	return parser.data.duplicate(true)


func _find_unique_by_key(records: Array, key: String, expected_value: Variant, label: String) -> Dictionary:
	var matches: Array[Dictionary] = []
	for record in records:
		if record is Dictionary and record.get(key) == expected_value:
			matches.append(record.duplicate(true))
	_check(
		matches.size() == 1,
		"Expected exactly 1 record with %s=%s in %s, found %d" % [key, str(expected_value), label, matches.size()]
	)
	if matches.size() != 1:
		return {}
	return matches[0]


func _coerce_catalog_actor(raw: Dictionary, label: String) -> Dictionary:
	var copy := raw.duplicate(true)
	_check(copy.get("id") is String and not String(copy["id"]).is_empty(), "%s must have nonempty String id" % label)
	_check(copy.get("name") is String and not String(copy["name"]).is_empty(), "%s must have nonempty String name" % label)
	_check(copy.get("art_path") is String and not String(copy["art_path"]).is_empty(), "%s must have nonempty String art_path" % label)
	var max_hp: Variant = copy.get("max_hp")
	_check(_is_integral_number(max_hp), "%s max_hp must be integral" % label)
	if _is_integral_number(max_hp):
		copy["max_hp"] = int(max_hp)
	return copy


func _catalog_actor(catalog: Array, catalog_path: String, id: String) -> Dictionary:
	return _coerce_catalog_actor(_find_unique_by_key(catalog, "id", id, catalog_path), id)


func _build_catalog_party(hero_catalog: Array) -> CombatParty:
	var warden := _catalog_actor(hero_catalog, HERO_CATALOG_PATH, "warden")
	var seamstress := _catalog_actor(hero_catalog, HERO_CATALOG_PATH, "seamstress")
	var tinker := _catalog_actor(hero_catalog, HERO_CATALOG_PATH, "tinker")
	return CombatParty.new([warden, seamstress, tinker])


func _build_direct_enemies(enemy_catalog: Array) -> CombatEnemies:
	var guard := _catalog_actor(enemy_catalog, ENEMY_CATALOG_PATH, "button_guard")
	var stalker := _catalog_actor(enemy_catalog, ENEMY_CATALOG_PATH, "spool_stalker")
	var scavenger := _catalog_actor(enemy_catalog, ENEMY_CATALOG_PATH, "fray_scavenger")
	return CombatEnemies.new([guard, stalker, scavenger])


func _local_roster_map() -> Dictionary:
	return {ENCOUNTER_ID: ["button_guard", "spool_stalker", "fray_scavenger"]}


func _local_typed_pool() -> Dictionary:
	return {"Fight": {ENCOUNTER_ID: STITCHRAIL_PATH}}


func _expected_pattern_1() -> Array:
	return [
		{"type": "block", "amount": 3},
		{"type": "buff", "amount": 2},
		{"type": "attack", "amount": 3, "target_position": 2},
	]


func _expected_pattern_2() -> Array:
	return [
		{"type": "shove", "amount": 0, "target_position": 1, "direction": 1},
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
		{"type": "block", "amount": 2},
	]


func _expected_pattern_3() -> Array:
	return [
		{"type": "attack", "amount": 3, "target_position": 1},
		{"type": "attack", "amount": 4, "target_position": 2},
		{"type": "debuff", "amount": 2, "target_position": 1, "status": "bleed"},
	]


func _expected_definitions() -> Array:
	return [
		{"enemy_position": 1, "pattern": _expected_pattern_1()},
		{"enemy_position": 2, "pattern": _expected_pattern_2()},
		{"enemy_position": 3, "pattern": _expected_pattern_3()},
	]


func _expected_beat_1_intents() -> Array[Dictionary]:
	return [
		{"type": "block", "amount": 3, "enemy_position": 1},
		{"type": "shove", "amount": 0, "target_position": 1, "direction": 1, "enemy_position": 2},
		{"type": "attack", "amount": 3, "target_position": 1, "enemy_position": 3},
	]


func _expected_beat_2_intents() -> Array[Dictionary]:
	return [
		{"type": "buff", "amount": 2, "enemy_position": 1},
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak", "enemy_position": 2},
		{"type": "attack", "amount": 4, "target_position": 2, "enemy_position": 3},
	]


func _expected_beat_3_intents() -> Array[Dictionary]:
	return [
		{"type": "attack", "amount": 3, "target_position": 2, "enemy_position": 1},
		{"type": "block", "amount": 2, "enemy_position": 2},
		{"type": "debuff", "amount": 2, "target_position": 1, "status": "bleed", "enemy_position": 3},
	]


func _check_actor_fields(actor: Dictionary, expected: Dictionary, label: String) -> void:
	_check(not actor.is_empty(), label + ": actor must exist.")
	for key in expected:
		if key == "statuses":
			_check(
				actor.get("statuses", {}) == expected[key],
				"%s: statuses must be %s, got %s" % [label, str(expected[key]), str(actor.get("statuses", {}))]
			)
		else:
			_check(
				actor.get(key) == expected[key],
				"%s: %s must be %s, got %s" % [label, key, str(expected[key]), str(actor.get(key))]
			)


func _check_events(result: Dictionary, expected_events: Array, label: String) -> void:
	_check(result.get("ok") == true, label + ": phase must succeed.")
	_check(
		result.get("events") == expected_events,
		label + ": events must be exactly %s, got %s" % [str(expected_events), str(result.get("events"))]
	)
	var events: Array = result.get("events", [])
	var ordered := events.size() == 3
	for index in range(events.size()):
		ordered = ordered and events[index].get("enemy_position") == index + 1 \
			and events[index].get("applied") == true
	_check(ordered, label + ": applied events must arrive in ascending source order.")


func _run_all_checks() -> void:
	var hero_catalog := _load_json_array(HERO_CATALOG_PATH)
	var enemy_catalog := _load_json_array(ENEMY_CATALOG_PATH)
	var definitions := _verify_ac1_schedule_parser_and_intents(hero_catalog, enemy_catalog)
	_verify_ac2_three_beat_phase(definitions, hero_catalog, enemy_catalog)
	_verify_ac3_selection_roster_and_shove_negatives(definitions, hero_catalog, enemy_catalog)


func _verify_ac1_schedule_parser_and_intents(hero_catalog: Array, enemy_catalog: Array) -> Array:
	# Required shared definitions, checked by stable ID instead of catalog totals.
	var warden := _catalog_actor(hero_catalog, HERO_CATALOG_PATH, "warden")
	var seamstress := _catalog_actor(hero_catalog, HERO_CATALOG_PATH, "seamstress")
	var tinker := _catalog_actor(hero_catalog, HERO_CATALOG_PATH, "tinker")
	_check(
		warden.get("name") == "Warden" and warden.get("max_hp") == 40
		and warden.get("art_path") == "res://assets/paper/heroes/warden.png",
		"Catalog Warden must retain name, 40 max_hp and art_path."
	)
	_check(
		seamstress.get("name") == "Seamstress" and seamstress.get("max_hp") == 30
		and seamstress.get("art_path") == "res://assets/paper/heroes/seamstress.png",
		"Catalog Seamstress must retain name, 30 max_hp and art_path."
	)
	_check(
		tinker.get("name") == "Tinker" and tinker.get("max_hp") == 26
		and tinker.get("art_path") == "res://assets/paper/heroes/tinker.png",
		"Catalog Tinker must retain name, 26 max_hp and art_path."
	)
	var guard := _catalog_actor(enemy_catalog, ENEMY_CATALOG_PATH, "button_guard")
	var stalker := _catalog_actor(enemy_catalog, ENEMY_CATALOG_PATH, "spool_stalker")
	var scavenger := _catalog_actor(enemy_catalog, ENEMY_CATALOG_PATH, "fray_scavenger")
	_check(
		guard.get("name") == "Button Guard" and guard.get("max_hp") == 16
		and guard.get("art_path") == "res://assets/paper/enemies/button_guard.png",
		"Catalog Button Guard must retain name, 16 max_hp and art_path."
	)
	_check(
		stalker.get("name") == "Spool Stalker" and stalker.get("max_hp") == 14
		and stalker.get("art_path") == "res://assets/paper/enemies/spool_stalker.png",
		"Catalog Spool Stalker must retain name, 14 max_hp and art_path."
	)
	_check(
		scavenger.get("name") == "Fray Scavenger" and scavenger.get("max_hp") == 14
		and scavenger.get("art_path") == "res://assets/paper/enemies/fray_scavenger.png",
		"Catalog Fray Scavenger must retain name, 14 max_hp and art_path."
	)

	# The authored file must be one top-level three-source array in source order.
	var raw := _load_json_array(STITCHRAIL_PATH)
	_check(raw.size() == 3, "stitchrail_triple_turn.json must be a top-level array of exactly 3 sources.")
	var raw_positions: Array[int] = []
	for raw_def in raw:
		if not raw_def is Dictionary:
			_check(false, "Each stitchrail source must be a Dictionary.")
			continue
		_check(raw_def.size() == 2, "Each stitchrail source may contain only enemy_position and pattern.")
		_check(raw_def.has("enemy_position") and raw_def.has("pattern"), "Each source must have enemy_position and pattern.")
		_check(_is_integral_number(raw_def.get("enemy_position")), "Raw enemy_position must be integral before coercion.")
		if _is_integral_number(raw_def.get("enemy_position")):
			raw_positions.append(int(raw_def["enemy_position"]))
		var raw_pattern = raw_def.get("pattern")
		_check(raw_pattern is Array and raw_pattern.size() == 3, "Each raw pattern must be a 3-beat Array.")
		if raw_pattern is Array:
			for raw_action in raw_pattern:
				_check(raw_action is Dictionary, "Each raw action must be a Dictionary.")
				if raw_action is Dictionary:
					_check(_is_integral_number(raw_action.get("amount")), "Raw action amount must be integral.")
					if raw_action.has("target_position"):
						_check(_is_integral_number(raw_action.get("target_position")), "Raw target_position must be integral.")
					if raw_action.has("direction"):
						_check(_is_integral_number(raw_action.get("direction")), "Raw direction must be integral.")
	_check(raw_positions == [1, 2, 3], "Authored sources must be ordered by ascending enemy_position 1, 2, 3.")

	# Production parser normalization and exact per-source action dictionaries.
	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(STITCHRAIL_PATH))
	_check(definitions.size() == 3, "Production parser must return exactly 3 stitchrail definitions.")
	_check(definitions == _expected_definitions(), "Parsed stitchrail definitions must match the canonical 3-beat schedule.")
	var source_1 := _find_unique_by_key(definitions, "enemy_position", 1, STITCHRAIL_PATH)
	var source_2 := _find_unique_by_key(definitions, "enemy_position", 2, STITCHRAIL_PATH)
	var source_3 := _find_unique_by_key(definitions, "enemy_position", 3, STITCHRAIL_PATH)
	_check(source_1.get("pattern") == _expected_pattern_1(), "Source 1 must be the Button Guard guard/buff/attack pattern.")
	_check(source_2.get("pattern") == _expected_pattern_2(), "Source 2 must be the Spool Stalker shove/weak/block pattern.")
	_check(source_3.get("pattern") == _expected_pattern_3(), "Source 3 must be the Fray Scavenger attack/attack/bleed pattern.")
	for parsed_source in definitions:
		_check(typeof(parsed_source.get("enemy_position")) == TYPE_INT, "Parsed enemy_position must have TYPE_INT.")
		for parsed_action in parsed_source.get("pattern", []):
			_check(typeof(parsed_action.get("amount")) == TYPE_INT, "Parsed amount must have TYPE_INT.")
			if parsed_action.has("target_position"):
				_check(typeof(parsed_action.get("target_position")) == TYPE_INT, "Parsed target_position must have TYPE_INT.")
			if parsed_action.has("direction"):
				_check(typeof(parsed_action.get("direction")) == TYPE_INT, "Parsed direction must have TYPE_INT.")

	# Real scheduler reports the nine authored actions in source order and wraps.
	var intents := CombatEnemyIntents.new(definitions)
	_check(intents.is_valid(), "CombatEnemyIntents must validate the stitchrail schedule.")
	var beat_1 := _expected_beat_1_intents()
	_check(intents.get_intents() == beat_1, "Beat 1 must announce guard block 3, stalker shove, scavenger attack 3.")
	var mutable := intents.get_intents()
	if not mutable.is_empty():
		mutable[0]["amount"] = 999
		mutable.clear()
	_check(intents.get_intents() == beat_1, "Returned intent copies must not mutate scheduler state.")
	_check(intents.advance_turn(), "advance_turn() from beat 1 to beat 2 must succeed.")
	_check(intents.get_intents() == _expected_beat_2_intents(), "Beat 2 must announce guard buff 2, stalker Weak, scavenger attack 4.")
	_check(intents.advance_turn(), "advance_turn() from beat 2 to beat 3 must succeed.")
	_check(intents.get_intents() == _expected_beat_3_intents(), "Beat 3 must announce guard attack 3, stalker block 2, scavenger Bleed 2.")
	_check(intents.advance_turn(), "advance_turn() from beat 3 must succeed.")
	_check(intents.get_intents() == beat_1, "A fourth beat must wrap back to beat 1 exactly.")
	_check(intents.get_intents() == beat_1, "Repeated reads after wrap must not advance implicitly.")
	return definitions


func _verify_ac2_three_beat_phase(definitions: Array, hero_catalog: Array, enemy_catalog: Array) -> void:
	var party := _build_catalog_party(hero_catalog)
	var enemies := _build_direct_enemies(enemy_catalog)
	_check(party.is_valid(), "Fresh catalog CombatParty must be valid.")
	_check(enemies.is_valid() and enemies.get_enemies().size() == 3, "Fresh direct CombatEnemies must hold three slots.")
	# Pure phase fixture: Warden's combat-start Block is deliberately not applied.
	_check(
		party.get_hero(1).get("block") == 0 and party.get_hero(2).get("block") == 0
		and party.get_hero(3).get("block") == 0,
		"Pure phase fixture must begin with zero hero Block."
	)
	_check(
		party.get_hero(1).get("statuses", {}) == {} and party.get_hero(2).get("statuses", {}) == {}
		and party.get_hero(3).get("statuses", {}) == {},
		"Pure phase fixture must begin with no hero statuses."
	)

	_check_actor_fields(party.get_hero(1), {
		"id": "warden", "name": "Warden", "max_hp": 40,
		"art_path": "res://assets/paper/heroes/warden.png",
		"position": 1, "hp": 40, "block": 0, "statuses": {},
	}, "Opening slot 1")
	_check_actor_fields(party.get_hero(2), {
		"id": "seamstress", "name": "Seamstress", "max_hp": 30,
		"art_path": "res://assets/paper/heroes/seamstress.png",
		"position": 2, "hp": 30, "block": 0, "statuses": {},
	}, "Opening slot 2")
	_check_actor_fields(party.get_hero(3), {
		"id": "tinker", "name": "Tinker", "max_hp": 26,
		"art_path": "res://assets/paper/heroes/tinker.png",
		"position": 3, "hp": 26, "block": 0, "statuses": {},
	}, "Opening slot 3")
	_check_actor_fields(enemies.get_enemy(1), {
		"id": "button_guard", "name": "Button Guard", "max_hp": 16,
		"art_path": "res://assets/paper/enemies/button_guard.png",
		"position": 1, "hp": 16, "block": 0, "statuses": {},
	}, "Opening enemy 1")
	_check_actor_fields(enemies.get_enemy(2), {
		"id": "spool_stalker", "name": "Spool Stalker", "max_hp": 14,
		"art_path": "res://assets/paper/enemies/spool_stalker.png",
		"position": 2, "hp": 14, "block": 0, "statuses": {},
	}, "Opening enemy 2")
	_check_actor_fields(enemies.get_enemy(3), {
		"id": "fray_scavenger", "name": "Fray Scavenger", "max_hp": 14,
		"art_path": "res://assets/paper/enemies/fray_scavenger.png",
		"position": 3, "hp": 14, "block": 0, "statuses": {},
	}, "Opening enemy 3")

	var intents := CombatEnemyIntents.new(definitions)
	var phase := CombatEnemyPhase.new()

	# Beat 1: guard Block 3, then shove swaps Warden/Seamstress, then the
	# scavenger strikes the now-front Seamstress for 3 (30 -> 27).
	_check(intents.get_intents() == _expected_beat_1_intents(), "Phase beat 1 announcement must match the schedule.")
	var beat_1_result := phase.execute_phase(party, enemies, intents.get_intents())
	_check_events(beat_1_result, [
		{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "shove", "enemy_position": 2, "target_position": 1, "direction": 1, "applied": true},
		{"type": "attack", "enemy_position": 3, "target_position": 1, "applied": true},
	], "Beat 1")
	_check_actor_fields(party.get_hero(1), {
		"id": "seamstress", "name": "Seamstress", "max_hp": 30,
		"art_path": "res://assets/paper/heroes/seamstress.png",
		"position": 1, "hp": 27, "block": 0, "statuses": {},
	}, "After Beat 1 slot 1")
	_check_actor_fields(party.get_hero(2), {
		"id": "warden", "name": "Warden", "max_hp": 40,
		"art_path": "res://assets/paper/heroes/warden.png",
		"position": 2, "hp": 40, "block": 0, "statuses": {},
	}, "After Beat 1 slot 2")
	_check_actor_fields(party.get_hero(3), {
		"id": "tinker", "name": "Tinker", "max_hp": 26,
		"art_path": "res://assets/paper/heroes/tinker.png",
		"position": 3, "hp": 26, "block": 0, "statuses": {},
	}, "After Beat 1 slot 3")
	_check_actor_fields(enemies.get_enemy(1), {
		"id": "button_guard", "name": "Button Guard", "max_hp": 16,
		"art_path": "res://assets/paper/enemies/button_guard.png",
		"position": 1, "hp": 16, "block": 3, "statuses": {},
	}, "After Beat 1 enemy 1")
	_check_actor_fields(enemies.get_enemy(2), {
		"id": "spool_stalker", "name": "Spool Stalker", "max_hp": 14,
		"art_path": "res://assets/paper/enemies/spool_stalker.png",
		"position": 2, "hp": 14, "block": 0, "statuses": {},
	}, "After Beat 1 enemy 2")
	_check_actor_fields(enemies.get_enemy(3), {
		"id": "fray_scavenger", "name": "Fray Scavenger", "max_hp": 14,
		"art_path": "res://assets/paper/enemies/fray_scavenger.png",
		"position": 3, "hp": 14, "block": 0, "statuses": {},
	}, "After Beat 1 enemy 3")
	_check(intents.advance_turn(), "Advance from phase beat 1 to beat 2 must succeed.")

	# Beat 2: guard self-Block reaches 5, stalker marks Tinker with Weak 1,
	# scavenger strikes now-middle Warden for 4 (40 -> 36).
	_check(intents.get_intents() == _expected_beat_2_intents(), "Phase beat 2 announcement must match the schedule.")
	var beat_2_result := phase.execute_phase(party, enemies, intents.get_intents())
	_check_events(beat_2_result, [
		{"type": "buff", "enemy_position": 1, "applied": true},
		{"type": "debuff", "enemy_position": 2, "target_position": 3, "status": "weak", "applied": true},
		{"type": "attack", "enemy_position": 3, "target_position": 2, "applied": true},
	], "Beat 2")
	_check_actor_fields(party.get_hero(1), {
		"id": "seamstress", "position": 1, "hp": 27, "block": 0, "statuses": {},
	}, "After Beat 2 slot 1")
	_check_actor_fields(party.get_hero(2), {
		"id": "warden", "position": 2, "hp": 36, "block": 0, "statuses": {},
	}, "After Beat 2 slot 2")
	_check_actor_fields(party.get_hero(3), {
		"id": "tinker", "position": 3, "hp": 26, "block": 0, "statuses": {"weak": 1},
	}, "After Beat 2 slot 3")
	_check_actor_fields(enemies.get_enemy(1), {
		"id": "button_guard", "position": 1, "hp": 16, "block": 5, "statuses": {},
	}, "After Beat 2 enemy 1")
	_check_actor_fields(enemies.get_enemy(2), {
		"id": "spool_stalker", "position": 2, "hp": 14, "block": 0,
	}, "After Beat 2 enemy 2")
	_check_actor_fields(enemies.get_enemy(3), {
		"id": "fray_scavenger", "position": 3, "hp": 14, "block": 0,
	}, "After Beat 2 enemy 3")
	_check(intents.advance_turn(), "Advance from phase beat 2 to beat 3 must succeed.")

	# Beat 3: guard strikes middle Warden for 3 (36 -> 33), stalker gains
	# 2 Block, scavenger applies Bleed 2 to front Seamstress.
	_check(intents.get_intents() == _expected_beat_3_intents(), "Phase beat 3 announcement must match the schedule.")
	var beat_3_result := phase.execute_phase(party, enemies, intents.get_intents())
	_check_events(beat_3_result, [
		{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
		{"type": "block", "enemy_position": 2, "applied": true},
		{"type": "debuff", "enemy_position": 3, "target_position": 1, "status": "bleed", "applied": true},
	], "Beat 3")
	_check_actor_fields(party.get_hero(1), {
		"id": "seamstress", "name": "Seamstress", "max_hp": 30,
		"art_path": "res://assets/paper/heroes/seamstress.png",
		"position": 1, "hp": 27, "block": 0, "statuses": {"bleed": 2},
	}, "After Beat 3 slot 1")
	_check_actor_fields(party.get_hero(2), {
		"id": "warden", "name": "Warden", "max_hp": 40,
		"art_path": "res://assets/paper/heroes/warden.png",
		"position": 2, "hp": 33, "block": 0, "statuses": {},
	}, "After Beat 3 slot 2")
	_check_actor_fields(party.get_hero(3), {
		"id": "tinker", "name": "Tinker", "max_hp": 26,
		"art_path": "res://assets/paper/heroes/tinker.png",
		"position": 3, "hp": 26, "block": 0, "statuses": {"weak": 1},
	}, "After Beat 3 slot 3")
	_check_actor_fields(enemies.get_enemy(1), {
		"id": "button_guard", "name": "Button Guard", "max_hp": 16,
		"art_path": "res://assets/paper/enemies/button_guard.png",
		"position": 1, "hp": 16, "block": 5, "statuses": {},
	}, "After Beat 3 enemy 1")
	_check_actor_fields(enemies.get_enemy(2), {
		"id": "spool_stalker", "name": "Spool Stalker", "max_hp": 14,
		"art_path": "res://assets/paper/enemies/spool_stalker.png",
		"position": 2, "hp": 14, "block": 2, "statuses": {},
	}, "After Beat 3 enemy 2")
	_check_actor_fields(enemies.get_enemy(3), {
		"id": "fray_scavenger", "name": "Fray Scavenger", "max_hp": 14,
		"art_path": "res://assets/paper/enemies/fray_scavenger.png",
		"position": 3, "hp": 14, "block": 0, "statuses": {},
	}, "After Beat 3 enemy 3")
	_check(intents.advance_turn(), "Advance after phase beat 3 must succeed.")
	_check(intents.get_intents() == _expected_beat_1_intents(), "Beat 4 must repeat beat 1 action shapes.")


func _find_legal_fight(map: RunMap) -> String:
	for node_id in map.get_legal_choices():
		if map.get_node(node_id).get("type") == "Fight":
			return node_id
	return ""


func _choose_reachable_fight(map: RunMap) -> String:
	for _step in range(RunMap.FLOOR_COUNT):
		var fight_id := _find_legal_fight(map)
		if not fight_id.is_empty():
			if map.choose_node(fight_id):
				return fight_id
			return ""
		var legal := map.get_legal_choices()
		if legal.is_empty() or not map.choose_node(legal[0]):
			return ""
	return ""


func _snapshot_map_and_selector(
	map: RunMap, rng: RandomNumberGenerator, selector: RunFightEncounterSelection
) -> Dictionary:
	return {
		"floors": map.get_floors(),
		"route": map.get_route(),
		"current_id": map.get_current_node_id(),
		"current_floor": map.get_current_floor(),
		"legal_choices": map.get_legal_choices(),
		"rng_state": rng.state,
		"selected_cache": selector._selected.duplicate(true),
		"bound_map": selector._bound_map,
	}


func _verify_ac3_selection_roster_and_shove_negatives(
	definitions: Array, hero_catalog: Array, enemy_catalog: Array
) -> void:
	# Seeded, legally chosen Fight node; only a TEST-LOCAL one-entry pool is used.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1181792629
	var map := RunMap.new()
	var selector := RunFightEncounterSelection.new()
	_check(map.generate(rng), "Seeded RunMap.generate(rng) must succeed.")
	var fight_id := _choose_reachable_fight(map)
	_check(not fight_id.is_empty(), "Seeded RunMap must expose a legally reachable Fight node.")
	_check(
		map.get_current_node_id() == fight_id and map.get_node(fight_id).get("type") == "Fight",
		"Current chosen node must be a legal Fight."
	)

	var expected_choice := {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": _expected_definitions(),
	}
	var first_choice := selector.select_current_battle(map, rng, _local_typed_pool())
	_check(first_choice == expected_choice, "Local Fight pool must select stitchrail_triple_turn with canonical definitions.")
	var snapshot_after_first := _snapshot_map_and_selector(map, rng, selector)
	_check(
		snapshot_after_first["route"] == [fight_id] and not snapshot_after_first["selected_cache"].is_empty(),
		"Successful selection must bind the chosen Fight and cache its choice."
	)

	# Reselect without extra RNG or cache drift.
	var second_choice := selector.select_current_battle(map, rng, _local_typed_pool())
	_check(second_choice == expected_choice, "Repeated selection must return the cached stitchrail choice.")
	_check(
		_snapshot_map_and_selector(map, rng, selector) == snapshot_after_first,
		"Repeated selection must leave the seeded RNG, route and cached choice unchanged."
	)
	second_choice["encounter_id"] = "mutated_id"
	second_choice["definitions"].clear()
	_check(
		selector.select_current_battle(map, rng, _local_typed_pool()) == expected_choice
		and _snapshot_map_and_selector(map, rng, selector) == snapshot_after_first,
		"Mutating a returned choice must not corrupt the selector cache."
	)

	# The real typed roster bridge binds the explicit ordered IDs and stats.
	var roster_map := _local_roster_map()
	var roster_map_before := roster_map.duplicate(true)
	var assembled := RunTypedBattleRoster.new().assemble(first_choice, roster_map, [ENEMY_CATALOG_PATH])
	_check(roster_map == roster_map_before, "RunTypedBattleRoster.assemble must not mutate the caller roster map.")
	_check(
		assembled.get("ok") == true and assembled.get("node_type") == "Fight"
		and assembled.get("encounter_id") == ENCOUNTER_ID,
		"RunTypedBattleRoster.assemble must accept the selected stitchrail Fight."
	)
	_check(assembled.get("definitions") == definitions, "Assembled schedule must equal the parsed stitchrail schedule.")
	var assembled_enemies: Variant = assembled.get("enemies")
	_check(
		assembled_enemies is CombatEnemies and assembled_enemies.is_valid()
		and assembled_enemies.get_enemies().size() == 3,
		"Assembled roster must be a valid three-enemy CombatEnemies."
	)
	if assembled_enemies is CombatEnemies:
		_check_actor_fields(assembled_enemies.get_enemy(1), {
			"id": "button_guard", "name": "Button Guard", "max_hp": 16,
			"art_path": "res://assets/paper/enemies/button_guard.png",
			"position": 1, "hp": 16, "block": 0,
		}, "Assembled enemy 1")
		_check_actor_fields(assembled_enemies.get_enemy(2), {
			"id": "spool_stalker", "name": "Spool Stalker", "max_hp": 14,
			"art_path": "res://assets/paper/enemies/spool_stalker.png",
			"position": 2, "hp": 14, "block": 0,
		}, "Assembled enemy 2")
		_check_actor_fields(assembled_enemies.get_enemy(3), {
			"id": "fray_scavenger", "name": "Fray Scavenger", "max_hp": 14,
			"art_path": "res://assets/paper/enemies/fray_scavenger.png",
			"position": 3, "hp": 14, "block": 0,
		}, "Assembled enemy 3")

	# The named prior three-enemy schedule still parses, without global totals.
	var prior_definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(SPOOLCORD_PATH))
	_check(not prior_definitions.is_empty(), "Prior spoolcord_triad_relay.json must still parse.")
	_check(CombatEnemyIntents.new(prior_definitions).is_valid(), "Prior spoolcord schedule must remain valid for intents.")
	for position in [1, 2, 3]:
		var prior_source := _find_unique_by_key(prior_definitions, "enemy_position", position, SPOOLCORD_PATH)
		_check(
			prior_source.get("pattern") is Array and prior_source["pattern"].size() == 3,
			"Prior spoolcord source %d must still have a 3-beat pattern." % position
		)

	# A downed hero at either end of beat 1's adjacent shove rejects the whole
	# phase atomically, including Button Guard's already staged 3 Block.
	_verify_down_shove_rejects_beat_1(definitions, hero_catalog, enemy_catalog, 1)
	_verify_down_shove_rejects_beat_1(definitions, hero_catalog, enemy_catalog, 2)


func _verify_down_shove_rejects_beat_1(
	definitions: Array, hero_catalog: Array, enemy_catalog: Array, down_position: int
) -> void:
	var party := _build_catalog_party(hero_catalog)
	var enemies := _build_direct_enemies(enemy_catalog)
	var lethal := 40 if down_position == 1 else 30
	_check(
		party.apply_damage(down_position, lethal) and party.is_downed(down_position),
		"Precondition: downing the shove participant at position %d must succeed." % down_position
	)
	var other_position := 2 if down_position == 1 else 1
	_check(
		not party.is_downed(other_position),
		"Precondition: the adjacent shove participant at position %d must stay alive." % other_position
	)
	var heroes_before := party.get_heroes()
	var enemies_before := enemies.get_enemies()
	var intents := CombatEnemyIntents.new(definitions)
	var result := CombatEnemyPhase.new().execute_phase(party, enemies, intents.get_intents())
	_check(
		result == {"ok": false, "events": []},
		"Downed shove participant at position %d must reject the entire beat-1 phase." % down_position
	)
	_check(
		party.get_heroes() == heroes_before,
		"Rejected beat 1 with downed position %d must leave the authoritative party unchanged." % down_position
	)
	_check(
		enemies.get_enemies() == enemies_before,
		"Rejected beat 1 with downed position %d must leave the authoritative enemies unchanged." % down_position
	)
	_check(
		enemies.get_enemy(1).get("block") == 0,
		"Rejected beat 1 with downed position %d must roll back Button Guard's staged 3 Block." % down_position
	)
	_check(
		intents.get_intents() == _expected_beat_1_intents(),
		"Rejected beat 1 with downed position %d must not advance the intent cycle." % down_position
	)
