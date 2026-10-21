extends SceneTree

## Deterministic headless coverage for the authored Crossspool Mark Transfer M03 Fight:
## slot 1 Fray Scavenger (14 HP), slot 2 Spool Stalker (14 HP), and slot 3 Seam Ripper (18 HP)
## on a three-beat cycle whose Beat 1 identity is the in-phase sequence:
##   1) Source 1 applies Exposed 1 to middle Seamstress at hero slot 2;
##   2) Source 2 shoves middle Seamstress (+1 direction) so Seamstress moves to rear slot 3
##      while retaining Exposed 1 and Tinker moves to middle slot 2;
##   3) Source 3 attacks hero slot 3 for base 4, amplified by Seamstress's transferred
##      Exposed 1 to floor(4 * 1.5) = 6 damage (30 -> 24 HP).
## Standalone data/service scope: not yet published in m03_typed_battle_pools.json or app.gd.

const ENCOUNTER_PATH := "res://data/encounters/crossspool_mark_transfer.json"
const ENCOUNTER_ID := "crossspool_mark_transfer"
const HERO_CATALOG_PATH := "res://data/heroes/starter_party.json"
const ENEMY_CATALOG_PATH := "res://data/enemies/run_enemies.json"
const STARTER_ATTACKS_PATH := "res://data/encounters/starter_attacks.json"
const BACKHEM_PINWHEEL_PATH := "res://data/encounters/backhem_pinwheel.json"
const SEED_VALUE := 4271

var failures: Array[String] = []
var checks := 0


func _init() -> void:
	_verify_failure_harness()
	_run_all_checks()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
			printerr(failure)
		print("crossspool_mark_transfer_encounter_test: FAIL (", failures.size(), " failures)")
		quit(1)
		return
	print("crossspool_mark_transfer_encounter_test: PASS (", checks, " checks)")
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


func _build_catalog_party(hero_catalog: Array) -> CombatParty:
	var warden := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "warden", HERO_CATALOG_PATH), "warden")
	var seamstress := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "seamstress", HERO_CATALOG_PATH), "seamstress")
	var tinker := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "tinker", HERO_CATALOG_PATH), "tinker")
	return CombatParty.new([warden, seamstress, tinker])


func _build_catalog_enemies(enemy_catalog: Array) -> CombatEnemies:
	var scavenger := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "fray_scavenger", ENEMY_CATALOG_PATH), "fray_scavenger")
	var stalker := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "spool_stalker", ENEMY_CATALOG_PATH), "spool_stalker")
	var ripper := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "seam_ripper", ENEMY_CATALOG_PATH), "seam_ripper")
	return CombatEnemies.new([scavenger, stalker, ripper])


func _local_roster_map() -> Dictionary:
	return {ENCOUNTER_ID: ["fray_scavenger", "spool_stalker", "seam_ripper"]}


func _local_typed_pool() -> Dictionary:
	return {"Fight": {ENCOUNTER_ID: ENCOUNTER_PATH}}


func _expected_pattern_1() -> Array:
	return [
		{"type": "debuff", "amount": 1, "target_position": 2, "status": "exposed"},
		{"type": "attack", "amount": 2, "target_position": 1},
		{"type": "block", "amount": 2},
	]


func _expected_pattern_2() -> Array:
	return [
		{"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
		{"type": "attack", "amount": 3, "target_position": 2},
	]


func _expected_pattern_3() -> Array:
	return [
		{"type": "attack", "amount": 4, "target_position": 3},
		{"type": "buff", "amount": 3},
		{"type": "attack", "amount": 2, "target_position": 1},
	]


func _expected_definitions() -> Array:
	return [
		{"enemy_position": 1, "pattern": _expected_pattern_1()},
		{"enemy_position": 2, "pattern": _expected_pattern_2()},
		{"enemy_position": 3, "pattern": _expected_pattern_3()},
	]


func _expected_beat_1_intents() -> Array[Dictionary]:
	return [
		{"type": "debuff", "amount": 1, "target_position": 2, "status": "exposed", "enemy_position": 1},
		{"type": "shove", "amount": 0, "target_position": 2, "direction": 1, "enemy_position": 2},
		{"type": "attack", "amount": 4, "target_position": 3, "enemy_position": 3},
	]


func _expected_beat_2_intents() -> Array[Dictionary]:
	return [
		{"type": "attack", "amount": 2, "target_position": 1, "enemy_position": 1},
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak", "enemy_position": 2},
		{"type": "buff", "amount": 3, "enemy_position": 3},
	]


func _expected_beat_3_intents() -> Array[Dictionary]:
	return [
		{"type": "block", "amount": 2, "enemy_position": 1},
		{"type": "attack", "amount": 3, "target_position": 2, "enemy_position": 2},
		{"type": "attack", "amount": 2, "target_position": 1, "enemy_position": 3},
	]


func _expected_beat_1_events() -> Array[Dictionary]:
	return [
		{"type": "debuff", "enemy_position": 1, "target_position": 2, "status": "exposed", "applied": true},
		{"type": "shove", "enemy_position": 2, "target_position": 2, "direction": 1, "applied": true},
		{"type": "attack", "enemy_position": 3, "target_position": 3, "applied": true},
	]


func _expected_beat_2_events() -> Array[Dictionary]:
	return [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
		{"type": "debuff", "enemy_position": 2, "target_position": 3, "status": "weak", "applied": true},
		{"type": "buff", "enemy_position": 3, "applied": true},
	]


func _expected_beat_3_events() -> Array[Dictionary]:
	return [
		{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true},
		{"type": "attack", "enemy_position": 3, "target_position": 1, "applied": true},
	]


func _run_all_checks() -> void:
	var raw_hero_catalog := _load_json_array(HERO_CATALOG_PATH)
	var raw_enemy_catalog := _load_json_array(ENEMY_CATALOG_PATH)
	var raw_encounter := _load_json_array(ENCOUNTER_PATH)
	var hero_catalog_snapshot := raw_hero_catalog.duplicate(true)
	var enemy_catalog_snapshot := raw_enemy_catalog.duplicate(true)
	var encounter_snapshot := raw_encounter.duplicate(true)

	_verify_ac1_schedule_parser_and_intents(raw_hero_catalog, raw_enemy_catalog)
	_verify_ac2_beat_1_mark_transfer_execution(raw_hero_catalog, raw_enemy_catalog)
	_verify_ac3_independent_beats_and_negative_cases(raw_hero_catalog, raw_enemy_catalog)
	_verify_ac4_map_selection_and_roster_assembly(raw_hero_catalog)

	_check(raw_hero_catalog == hero_catalog_snapshot, "Hero catalog snapshot must remain unmutated after all checks.")
	_check(raw_enemy_catalog == enemy_catalog_snapshot, "Enemy catalog snapshot must remain unmutated after all checks.")
	_check(_load_json_array(ENCOUNTER_PATH) == encounter_snapshot, "Authored crossspool_mark_transfer.json on disk must remain unmutated after all checks.")


## AC1: Parse crossspool_mark_transfer.json through RunFightEncounterSelection._parse_schedule_text,
## verify exact 3 sources (enemy_position 1, 2, 3), 3-beat actions, CombatEnemyIntents validity,
## ascending announced slots across beats 1-3 and beat-1 wraparound, and confirm starter_attacks
## and backhem_pinwheel remain valid without shared catalog total-count or full-list assertions.
func _verify_ac1_schedule_parser_and_intents(hero_catalog: Array, enemy_catalog: Array) -> void:
	# Verify required catalog actors by stable ID without assuming fixed catalog total size.
	var warden := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "warden", HERO_CATALOG_PATH), "warden")
	var seamstress := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "seamstress", HERO_CATALOG_PATH), "seamstress")
	var tinker := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "tinker", HERO_CATALOG_PATH), "tinker")
	_check(
		warden.get("name") == "Warden"
		and warden.get("max_hp") == 40
		and warden.get("art_path") == "res://assets/paper/heroes/warden.png",
		"Catalog Warden must retain name Warden, 40 max_hp, and warden art_path."
	)
	_check(
		seamstress.get("name") == "Seamstress"
		and seamstress.get("max_hp") == 30
		and seamstress.get("art_path") == "res://assets/paper/heroes/seamstress.png",
		"Catalog Seamstress must retain name Seamstress, 30 max_hp, and seamstress art_path."
	)
	_check(
		tinker.get("name") == "Tinker"
		and tinker.get("max_hp") == 26
		and tinker.get("art_path") == "res://assets/paper/heroes/tinker.png",
		"Catalog Tinker must retain name Tinker, 26 max_hp, and tinker art_path."
	)

	var scavenger := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "fray_scavenger", ENEMY_CATALOG_PATH), "fray_scavenger")
	var stalker := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "spool_stalker", ENEMY_CATALOG_PATH), "spool_stalker")
	var ripper := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "seam_ripper", ENEMY_CATALOG_PATH), "seam_ripper")
	_check(
		scavenger.get("name") == "Fray Scavenger"
		and scavenger.get("max_hp") == 14
		and scavenger.get("art_path") == "res://assets/paper/enemies/fray_scavenger.png",
		"Catalog Fray Scavenger must retain name Fray Scavenger, 14 max_hp, and fray_scavenger art_path."
	)
	_check(
		stalker.get("name") == "Spool Stalker"
		and stalker.get("max_hp") == 14
		and stalker.get("art_path") == "res://assets/paper/enemies/spool_stalker.png",
		"Catalog Spool Stalker must retain name Spool Stalker, 14 max_hp, and spool_stalker art_path."
	)
	_check(
		ripper.get("name") == "Seam Ripper"
		and ripper.get("max_hp") == 18
		and ripper.get("art_path") == "res://assets/paper/enemies/seam_ripper.png",
		"Catalog Seam Ripper must retain name Seam Ripper, 18 max_hp, and seam_ripper art_path."
	)

	# Verify raw JSON integral numeric fields before coercion, then parse via RunFightEncounterSelection._parse_schedule_text.
	var raw_text := _read_text(ENCOUNTER_PATH)
	var raw_json := _load_json_array(ENCOUNTER_PATH)
	_check(raw_json.size() == 3, "crossspool_mark_transfer.json must contain exactly 3 enemy source definitions.")
	for raw_def in raw_json:
		_check(raw_def is Dictionary, "Each raw definition in crossspool_mark_transfer.json must be a Dictionary.")
		if raw_def is Dictionary:
			_check(_is_integral_number(raw_def.get("enemy_position")), "Raw enemy_position must be integral before coercion.")
			var raw_pattern: Variant = raw_def.get("pattern", [])
			_check(raw_pattern is Array and raw_pattern.size() == 3, "Each raw pattern in crossspool_mark_transfer.json must be a 3-beat Array.")
			if raw_pattern is Array:
				for raw_action in raw_pattern:
					_check(raw_action is Dictionary, "Each raw action must be a Dictionary.")
					if raw_action is Dictionary:
						_check(_is_integral_number(raw_action.get("amount")), "Raw action amount must be integral.")
						if raw_action.has("target_position"):
							_check(_is_integral_number(raw_action.get("target_position")), "Raw target_position must be integral.")
						if raw_action.has("direction"):
							_check(_is_integral_number(raw_action.get("direction")), "Raw direction must be integral.")

	var definitions := RunFightEncounterSelection._parse_schedule_text(raw_text)
	_check(definitions.size() == 3, "RunFightEncounterSelection._parse_schedule_text must return 3 definitions for crossspool_mark_transfer.")
	for parsed_def in definitions:
		_check(typeof(parsed_def.get("enemy_position")) == TYPE_INT, "Parsed enemy_position must have TYPE_INT after coercion.")
		var parsed_pattern: Array = parsed_def.get("pattern", [])
		_check(parsed_pattern.size() == 3, "Each parsed source pattern must contain 3 actions.")
		for parsed_action in parsed_pattern:
			_check(typeof(parsed_action.get("amount")) == TYPE_INT, "Parsed action amount must have TYPE_INT after coercion.")
			if parsed_action.has("target_position"):
				_check(typeof(parsed_action.get("target_position")) == TYPE_INT, "Parsed target_position must have TYPE_INT after coercion.")
			if parsed_action.has("direction"):
				_check(typeof(parsed_action.get("direction")) == TYPE_INT, "Parsed direction must have TYPE_INT after coercion.")

	var source_1 := _find_unique_by_key(definitions, "enemy_position", 1, ENCOUNTER_PATH)
	var source_2 := _find_unique_by_key(definitions, "enemy_position", 2, ENCOUNTER_PATH)
	var source_3 := _find_unique_by_key(definitions, "enemy_position", 3, ENCOUNTER_PATH)
	_check(source_1.get("pattern") == _expected_pattern_1(), "Source 1 pattern must match exact 3-beat Fray Scavenger schedule.")
	_check(source_2.get("pattern") == _expected_pattern_2(), "Source 2 pattern must match exact 3-beat Spool Stalker schedule.")
	_check(source_3.get("pattern") == _expected_pattern_3(), "Source 3 pattern must match exact 3-beat Seam Ripper schedule.")
	_check(definitions == _expected_definitions(), "Normalized crossspool_mark_transfer definitions must match canonical schedule.")

	# Validate through CombatEnemyIntents across full 3-beat cycle + wraparound (turns 1, 2, 3, 1) and verify deep-copy isolation.
	var caller_definitions := definitions.duplicate(true)
	var intents := CombatEnemyIntents.new(caller_definitions)
	_check(intents.is_valid(), "CombatEnemyIntents must validate crossspool_mark_transfer definitions.")

	caller_definitions[0]["pattern"][0]["amount"] = 999
	caller_definitions[1]["pattern"].clear()
	_check(
		intents.is_valid() and intents.get_intents() == _expected_beat_1_intents(),
		"Mutating caller definition array after construction must not corrupt CombatEnemyIntents."
	)

	var expected_b1 := _expected_beat_1_intents()
	var expected_b2 := _expected_beat_2_intents()
	var expected_b3 := _expected_beat_3_intents()

	var b1_read_a := intents.get_intents()
	var b1_read_b := intents.get_intents()
	_check(b1_read_a == expected_b1, "Beat 1 intents must match source 1 exposed 1 on pos 2, source 2 shove pos 2 dir +1, and source 3 attack 4 on pos 3.")
	_check(b1_read_b == expected_b1, "Repeated get_intents() on Beat 1 must not advance implicitly.")
	_check(
		b1_read_a.size() == 3
		and b1_read_a[0].get("enemy_position") == 1
		and b1_read_a[1].get("enemy_position") == 2
		and b1_read_a[2].get("enemy_position") == 3,
		"Beat 1 intents must be ordered by ascending enemy_position 1, 2, 3."
	)
	if not b1_read_a.is_empty():
		b1_read_a[0]["amount"] = 777
		b1_read_a[0]["status"] = "invented"
		b1_read_a.append({"type": "block", "amount": 9, "enemy_position": 4})
	_check(b1_read_b == expected_b1, "Mutating one get_intents() result must not affect another fetched result.")
	_check(intents.get_intents() == expected_b1, "Mutating returned intents must not mutate CombatEnemyIntents state.")

	_check(intents.advance_turn(), "advance_turn() from Beat 1 to Beat 2 must succeed.")
	var b2_read := intents.get_intents()
	_check(b2_read == expected_b2, "Beat 2 intents must match source 1 attack 2 on pos 1, source 2 weak 1 on pos 3, and source 3 buff 3.")
	_check(
		b2_read.size() == 3
		and b2_read[0].get("enemy_position") == 1
		and b2_read[1].get("enemy_position") == 2
		and b2_read[2].get("enemy_position") == 3,
		"Beat 2 intents must be ordered by ascending enemy_position 1, 2, 3."
	)
	_check(intents.get_intents() == expected_b2, "Repeated get_intents() on Beat 2 must not advance implicitly.")

	_check(intents.advance_turn(), "advance_turn() from Beat 2 to Beat 3 must succeed.")
	var b3_read := intents.get_intents()
	_check(b3_read == expected_b3, "Beat 3 intents must match source 1 block 2, source 2 attack 3 on pos 2, and source 3 attack 2 on pos 1.")
	_check(
		b3_read.size() == 3
		and b3_read[0].get("enemy_position") == 1
		and b3_read[1].get("enemy_position") == 2
		and b3_read[2].get("enemy_position") == 3,
		"Beat 3 intents must be ordered by ascending enemy_position 1, 2, 3."
	)
	_check(intents.get_intents() == expected_b3, "Repeated get_intents() on Beat 3 must not advance implicitly.")

	_check(intents.advance_turn(), "advance_turn() from Beat 3 to Beat 4 (wraparound) must succeed.")
	_check(intents.get_intents() == expected_b1, "Fourth announcement (after 3 advance_turn calls) must wrap around to exact Beat 1 intents.")
	_check(intents.advance_turn() and intents.get_intents() == expected_b2, "Fifth announcement must continue cycle to Beat 2 intents.")
	_check(intents.advance_turn() and intents.get_intents() == expected_b3, "Sixth announcement must continue cycle to Beat 3 intents.")

	# Verify reversed source order still announces in ascending enemy_position order.
	var reversed_intents := CombatEnemyIntents.new([
		source_3.duplicate(true),
		source_1.duplicate(true),
		source_2.duplicate(true),
	])
	_check(reversed_intents.is_valid(), "CombatEnemyIntents must accept scrambled source order.")
	_check(reversed_intents.get_intents() == expected_b1, "CombatEnemyIntents must sort announced actions by ascending enemy_position 1, 2, 3.")

	# Verify zero global RNG consumption during CombatEnemyIntents construction, reading, and advancing.
	seed(20261022)
	var expected_global := randi()
	seed(20261022)
	var rng_probe := CombatEnemyIntents.new(definitions)
	for _turn in range(6):
		rng_probe.get_intents()
		rng_probe.advance_turn()
	_check(randi() == expected_global, "CombatEnemyIntents construction, reading, and advancing must consume zero global RNG.")

	# Confirm named earlier starter_attacks.json and backhem_pinwheel.json remain valid.
	var starter_defs := RunFightEncounterSelection._parse_schedule_text(_read_text(STARTER_ATTACKS_PATH))
	_check(starter_defs.size() == 2, "starter_attacks.json must still parse into 2 source definitions.")
	var starter_s1 := _find_unique_by_key(starter_defs, "enemy_position", 1, STARTER_ATTACKS_PATH)
	var starter_s2 := _find_unique_by_key(starter_defs, "enemy_position", 2, STARTER_ATTACKS_PATH)
	_check(
		starter_s1.get("pattern") == [
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "attack", "amount": 1, "target_position": 3},
		],
		"starter_attacks.json source 1 pattern must remain unchanged."
	)
	_check(
		starter_s2.get("pattern") == [
			{"type": "block", "amount": 1},
		],
		"starter_attacks.json source 2 pattern must remain unchanged."
	)
	var starter_intents := CombatEnemyIntents.new(starter_defs)
	_check(starter_intents.is_valid(), "starter_attacks.json must remain valid in CombatEnemyIntents.")
	for target_pos in [1, 2, 3, 1]:
		var expected_starter_beat: Array[Dictionary] = [
			{"type": "attack", "amount": 1, "target_position": target_pos, "enemy_position": 1},
			{"type": "block", "amount": 1, "enemy_position": 2},
		]
		_check(starter_intents.get_intents() == expected_starter_beat, "starter_attacks beat announcement must remain unchanged.")
		_check(starter_intents.advance_turn(), "starter_attacks advance_turn must succeed.")

	var pinwheel_defs := RunFightEncounterSelection._parse_schedule_text(_read_text(BACKHEM_PINWHEEL_PATH))
	_check(pinwheel_defs.size() == 3, "backhem_pinwheel.json must still parse into 3 source definitions.")
	var pinwheel_s1 := _find_unique_by_key(pinwheel_defs, "enemy_position", 1, BACKHEM_PINWHEEL_PATH)
	var pinwheel_s2 := _find_unique_by_key(pinwheel_defs, "enemy_position", 2, BACKHEM_PINWHEEL_PATH)
	var pinwheel_s3 := _find_unique_by_key(pinwheel_defs, "enemy_position", 3, BACKHEM_PINWHEEL_PATH)
	_check(
		pinwheel_s1.get("pattern") == [
			{"type": "shove", "amount": 0, "target_position": 3, "direction": -1},
			{"type": "attack", "amount": 2, "target_position": 1},
			{"type": "block", "amount": 2},
		],
		"backhem_pinwheel.json source 1 pattern must remain unchanged."
	)
	_check(
		pinwheel_s2.get("pattern") == [
			{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed"},
			{"type": "buff", "amount": 3},
			{"type": "attack", "amount": 3, "target_position": 2},
		],
		"backhem_pinwheel.json source 2 pattern must remain unchanged."
	)
	_check(
		pinwheel_s3.get("pattern") == [
			{"type": "attack", "amount": 3, "target_position": 3},
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 2, "target_position": 1},
		],
		"backhem_pinwheel.json source 3 pattern must remain unchanged."
	)
	var pinwheel_intents := CombatEnemyIntents.new(pinwheel_defs)
	_check(pinwheel_intents.is_valid(), "backhem_pinwheel.json must remain valid in CombatEnemyIntents.")
	var expected_pinwheel_beats: Array = [
		[
			{"type": "shove", "amount": 0, "target_position": 3, "direction": -1, "enemy_position": 1},
			{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed", "enemy_position": 2},
			{"type": "attack", "amount": 3, "target_position": 3, "enemy_position": 3},
		],
		[
			{"type": "attack", "amount": 2, "target_position": 1, "enemy_position": 1},
			{"type": "buff", "amount": 3, "enemy_position": 2},
			{"type": "block", "amount": 1, "enemy_position": 3},
		],
		[
			{"type": "block", "amount": 2, "enemy_position": 1},
			{"type": "attack", "amount": 3, "target_position": 2, "enemy_position": 2},
			{"type": "attack", "amount": 2, "target_position": 1, "enemy_position": 3},
		],
		[
			{"type": "shove", "amount": 0, "target_position": 3, "direction": -1, "enemy_position": 1},
			{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed", "enemy_position": 2},
			{"type": "attack", "amount": 3, "target_position": 3, "enemy_position": 3},
		],
	]
	for expected_beat in expected_pinwheel_beats:
		_check(pinwheel_intents.get_intents() == expected_beat, "backhem_pinwheel beat announcement must remain unchanged.")
		_check(pinwheel_intents.advance_turn(), "backhem_pinwheel advance_turn must succeed.")


## AC2: Fresh living Warden/Seamstress/Tinker party at slots 1/2/3 (40/30/26 HP) with Warden's
## one-time opening 6 Block and [fray_scavenger, spool_stalker, seam_ripper] at enemy slots 1/2/3.
## Executing Beat 1 with real CombatEnemyPhase:
##   1) Source 1 gives middle Seamstress (slot 2) Exposed 1;
##   2) Source 2 swaps middle Seamstress with rear Tinker (slot 2 <-> slot 3);
##   3) Source 3 attacks now-rear Exposed Seamstress at slot 3 for floor(4 * 1.5) = 6 HP.
## Authoritative party finishes: Warden at 1 (40 HP, 6 Block), Tinker at 2 (26 HP, 0 Block),
## Seamstress at 3 (24 HP, 0 Block, Exposed 1). Source positions never swap.
func _verify_ac2_beat_1_mark_transfer_execution(hero_catalog: Array, enemy_catalog: Array) -> void:
	# Prove global RNG probe detects an extra draw before checking zero RNG consumption.
	var rng_seed := 24681357
	seed(rng_seed)
	var expected_global_draw := randi()
	seed(rng_seed)
	var _injected_draw := randi()
	_check(randi() != expected_global_draw, "Global RNG probe must detect an injected randi() draw.")

	seed(rng_seed)
	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	var party := _build_catalog_party(hero_catalog)
	var enemies := _build_catalog_enemies(enemy_catalog)
	_check(party.is_valid(), "Starter CombatParty must be valid.")
	_check(enemies.is_valid(), "Three-enemy CombatEnemies must be valid.")

	var starting_block := CombatStartingBlock.new(party)
	_check(starting_block.apply(), "First CombatStartingBlock.apply() must grant Warden +6 opening Block.")
	var opened_heroes := party.get_heroes()
	_check(not starting_block.apply(), "Second CombatStartingBlock.apply() must fail closed as one-shot.")
	_check(party.get_heroes() == opened_heroes, "Rejected second CombatStartingBlock.apply() must not mutate party.")
	_check(
		party.get_hero(1) == {
			"id": "warden",
			"name": "Warden",
			"max_hp": 40,
			"art_path": "res://assets/paper/heroes/warden.png",
			"position": 1,
			"hp": 40,
			"block": 6,
		}
		and party.get_hero(2) == {
			"id": "seamstress",
			"name": "Seamstress",
			"max_hp": 30,
			"art_path": "res://assets/paper/heroes/seamstress.png",
			"position": 2,
			"hp": 30,
			"block": 0,
		}
		and party.get_hero(3) == {
			"id": "tinker",
			"name": "Tinker",
			"max_hp": 26,
			"art_path": "res://assets/paper/heroes/tinker.png",
			"position": 3,
			"hp": 26,
			"block": 0,
		},
		"Opening party must be Warden (40 HP, 6 Block) at 1, Seamstress (30 HP, 0 Block) at 2, Tinker (26 HP, 0 Block) at 3."
	)
	_check(
		enemies.get_enemy(1) == {
			"id": "fray_scavenger",
			"name": "Fray Scavenger",
			"max_hp": 14,
			"art_path": "res://assets/paper/enemies/fray_scavenger.png",
			"position": 1,
			"hp": 14,
			"block": 0,
		}
		and enemies.get_enemy(2) == {
			"id": "spool_stalker",
			"name": "Spool Stalker",
			"max_hp": 14,
			"art_path": "res://assets/paper/enemies/spool_stalker.png",
			"position": 2,
			"hp": 14,
			"block": 0,
		}
		and enemies.get_enemy(3) == {
			"id": "seam_ripper",
			"name": "Seam Ripper",
			"max_hp": 18,
			"art_path": "res://assets/paper/enemies/seam_ripper.png",
			"position": 3,
			"hp": 18,
			"block": 0,
		},
		"Opening enemies must be Fray Scavenger (14 HP) at 1, Spool Stalker (14 HP) at 2, Seam Ripper (18 HP) at 3."
	)

	# Capture original dictionary references to confirm swaps move actor identities rather than replacing dictionaries.
	var warden_ref: Dictionary = party._heroes[0]
	var seamstress_ref: Dictionary = party._heroes[1]
	var tinker_ref: Dictionary = party._heroes[2]

	# Confirm CombatStatuses formula for base 4 against Exposed 1 is floor(4 * 1.5) = 6.
	_check(
		CombatStatuses.new().adjusted_attack_damage(4, {}, {"exposed": 1}) == 6,
		"CombatStatuses.adjusted_attack_damage(4, {}, {exposed: 1}) must equal 6."
	)

	var intents := CombatEnemyIntents.new(definitions)
	var phase := CombatEnemyPhase.new()
	var b1_intents := intents.get_intents()
	var b1_intents_copy := b1_intents.duplicate(true)
	_check(b1_intents == _expected_beat_1_intents(), "Beat 1 intents must match expected debuff -> shove -> attack schedule.")

	var b1_res := phase.execute_phase(party, enemies, b1_intents)
	_check(b1_intents == b1_intents_copy, "CombatEnemyPhase.execute_phase must not mutate caller intents array.")
	_check(
		b1_res == {"ok": true, "events": _expected_beat_1_events()},
		"Beat 1 execute_phase must return {ok: true, events: [...]} in ascending source order 1, 2, 3."
	)
	_check(
		party.get_hero(1) == {
			"id": "warden",
			"name": "Warden",
			"max_hp": 40,
			"art_path": "res://assets/paper/heroes/warden.png",
			"position": 1,
			"hp": 40,
			"block": 6,
		},
		"After Beat 1, slot 1 must be Warden with 40 HP, 6 Block, and no statuses."
	)
	_check(
		party.get_hero(2) == {
			"id": "tinker",
			"name": "Tinker",
			"max_hp": 26,
			"art_path": "res://assets/paper/heroes/tinker.png",
			"position": 2,
			"hp": 26,
			"block": 0,
		},
		"After Beat 1, slot 2 must be swapped Tinker with 26 HP, 0 Block, and no statuses."
	)
	_check(
		party.get_hero(3) == {
			"id": "seamstress",
			"name": "Seamstress",
			"max_hp": 30,
			"art_path": "res://assets/paper/heroes/seamstress.png",
			"position": 3,
			"hp": 24,
			"block": 0,
			"statuses": {"exposed": 1},
		},
		"After Beat 1, slot 3 must be swapped Seamstress with 24 HP (30 - floor(4 * 1.5)), 0 Block, and statuses={exposed: 1}."
	)
	_check(
		is_same(party._heroes[0], warden_ref)
		and is_same(party._heroes[1], tinker_ref)
		and is_same(party._heroes[2], seamstress_ref),
		"Authoritative hero dictionary references must move with their actor identities across the swap."
	)
	_check(
		enemies.get_enemy(1).get("id") == "fray_scavenger"
		and enemies.get_enemy(1).get("position") == 1
		and enemies.get_enemy(1).get("hp") == 14
		and enemies.get_enemy(1).get("block") == 0
		and enemies.get_enemy(2).get("id") == "spool_stalker"
		and enemies.get_enemy(2).get("position") == 2
		and enemies.get_enemy(2).get("hp") == 14
		and enemies.get_enemy(2).get("block") == 0
		and enemies.get_enemy(3).get("id") == "seam_ripper"
		and enemies.get_enemy(3).get("position") == 3
		and enemies.get_enemy(3).get("hp") == 18
		and enemies.get_enemy(3).get("block") == 0,
		"Enemy source positions and HP/Block must remain unchanged after Beat 1 (14/0, 14/0, 18/0 at slots 1/2/3)."
	)
	_check(randi() == expected_global_draw, "Beat 1 announcement and execution must consume zero global RNG.")


func _execute_independent_beats_trace(seed_value: int, hero_catalog: Array, enemy_catalog: Array) -> Dictionary:
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = seed_value
	var local_rng_initial := local_rng.state
	seed(seed_value)
	var expected_global := randi()
	seed(seed_value)

	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	var scheduler := CombatEnemyIntents.new(definitions)
	var phase := CombatEnemyPhase.new()

	# Beat 1 on fresh fixture 1
	var party_1 := _build_catalog_party(hero_catalog)
	var enemies_1 := _build_catalog_enemies(enemy_catalog)
	var block_1_first := CombatStartingBlock.new(party_1)
	var block_1_ok := block_1_first.apply()
	var block_1_second := block_1_first.apply()
	var b1_intents := scheduler.get_intents()
	var b1_res := phase.execute_phase(party_1, enemies_1, b1_intents)

	# Beat 2 on fresh fixture 2
	var adv_1 := scheduler.advance_turn()
	var party_2 := _build_catalog_party(hero_catalog)
	var enemies_2 := _build_catalog_enemies(enemy_catalog)
	var block_2_ok := CombatStartingBlock.new(party_2).apply()
	var b2_intents := scheduler.get_intents()
	var b2_res := phase.execute_phase(party_2, enemies_2, b2_intents)

	# Beat 3 on fresh fixture 3
	var adv_2 := scheduler.advance_turn()
	var party_3 := _build_catalog_party(hero_catalog)
	var enemies_3 := _build_catalog_enemies(enemy_catalog)
	var block_3_ok := CombatStartingBlock.new(party_3).apply()
	var b3_intents := scheduler.get_intents()
	var b3_res := phase.execute_phase(party_3, enemies_3, b3_intents)

	# Wraparound after 3 advance_turn calls
	var adv_3 := scheduler.advance_turn()
	var b4_intents := scheduler.get_intents()
	var global_after := randi()

	return {
		"block_1_ok": block_1_ok,
		"block_1_second": block_1_second,
		"b1_intents": b1_intents,
		"b1_res": b1_res,
		"heroes_1": party_1.get_heroes(),
		"enemies_1": enemies_1.get_enemies(),
		"adv_1": adv_1,
		"block_2_ok": block_2_ok,
		"b2_intents": b2_intents,
		"b2_res": b2_res,
		"heroes_2": party_2.get_heroes(),
		"enemies_2": enemies_2.get_enemies(),
		"adv_2": adv_2,
		"block_3_ok": block_3_ok,
		"b3_intents": b3_intents,
		"b3_res": b3_res,
		"heroes_3": party_3.get_heroes(),
		"enemies_3": enemies_3.get_enemies(),
		"adv_3": adv_3,
		"b4_intents": b4_intents,
		"local_rng_unchanged": local_rng.state == local_rng_initial,
		"global_rng_unchanged": global_after == expected_global,
	}


## AC3: Independently reset real fixtures resolve Beat 2 and Beat 3;
## Slain source-2 Spool Stalker before Beat 1 skips its shove (applied=false), keeping Seamstress
## at slot 2 with Exposed 1 while rear Tinker takes unamplified 4 damage (22 HP);
## Downed middle target or illegal authored action fails without party/enemy/RNG mutation;
## Two independently seeded repeated traces match announcements, phase outputs, parties, enemies, and RNG state.
func _verify_ac3_independent_beats_and_negative_cases(hero_catalog: Array, enemy_catalog: Array) -> void:
	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	var phase := CombatEnemyPhase.new()

	# 1. Beat 2 on a fresh independent fixture:
	# Source 1 attacks Warden (slot 1) for 2 -> Warden Block 6 -> 4, 40 HP;
	# Source 2 debuffs Tinker (original rear slot 3) with Weak 1;
	# Source 3 buffs Seam Ripper (enemy slot 3) with 3 Block.
	var party_b2 := _build_catalog_party(hero_catalog)
	var enemies_b2 := _build_catalog_enemies(enemy_catalog)
	_check(CombatStartingBlock.new(party_b2).apply(), "Opening Block must apply on fresh Beat 2 fixture.")
	var scheduler_b2 := CombatEnemyIntents.new(definitions)
	_check(scheduler_b2.advance_turn(), "Advancing scheduler once to Beat 2 must succeed.")
	var b2_intents := scheduler_b2.get_intents()
	_check(b2_intents == _expected_beat_2_intents(), "Beat 2 intents must match expected Beat 2 schedule.")
	var b2_res := phase.execute_phase(party_b2, enemies_b2, b2_intents)
	_check(
		b2_res == {"ok": true, "events": _expected_beat_2_events()},
		"Beat 2 execute_phase must resolve source 1 attack, source 2 weak debuff, and source 3 buff in ascending source order."
	)
	_check(
		party_b2.get_hero(1) == {
			"id": "warden",
			"name": "Warden",
			"max_hp": 40,
			"art_path": "res://assets/paper/heroes/warden.png",
			"position": 1,
			"hp": 40,
			"block": 4,
		}
		and party_b2.get_hero(2) == {
			"id": "seamstress",
			"name": "Seamstress",
			"max_hp": 30,
			"art_path": "res://assets/paper/heroes/seamstress.png",
			"position": 2,
			"hp": 30,
			"block": 0,
		}
		and party_b2.get_hero(3) == {
			"id": "tinker",
			"name": "Tinker",
			"max_hp": 26,
			"art_path": "res://assets/paper/heroes/tinker.png",
			"position": 3,
			"hp": 26,
			"block": 0,
			"statuses": {"weak": 1},
		},
		"Independent Beat 2 must leave Warden at 40 HP / 4 Block, Seamstress at 30 HP / 0 Block, and Tinker at slot 3 with 26 HP / 0 Block / Weak 1."
	)
	_check(
		enemies_b2.get_enemy(1).get("id") == "fray_scavenger"
		and enemies_b2.get_enemy(1).get("hp") == 14
		and enemies_b2.get_enemy(1).get("block") == 0
		and enemies_b2.get_enemy(2).get("id") == "spool_stalker"
		and enemies_b2.get_enemy(2).get("hp") == 14
		and enemies_b2.get_enemy(2).get("block") == 0
		and enemies_b2.get_enemy(3).get("id") == "seam_ripper"
		and enemies_b2.get_enemy(3).get("hp") == 18
		and enemies_b2.get_enemy(3).get("block") == 3,
		"Independent Beat 2 must give Seam Ripper at slot 3 +3 Block (18 HP, 3 Block) while slots 1 and 2 remain at 14 HP / 0 Block."
	)

	# 2. Beat 3 on a fresh independent fixture:
	# Source 1 gives Fray Scavenger (enemy slot 1) 2 Block;
	# Source 2 attacks middle Seamstress (slot 2) for 3 -> Seamstress HP 30 -> 27;
	# Source 3 attacks front Warden (slot 1) for 2 -> Warden Block 6 -> 4, 40 HP.
	var party_b3 := _build_catalog_party(hero_catalog)
	var enemies_b3 := _build_catalog_enemies(enemy_catalog)
	_check(CombatStartingBlock.new(party_b3).apply(), "Opening Block must apply on fresh Beat 3 fixture.")
	var scheduler_b3 := CombatEnemyIntents.new(definitions)
	_check(scheduler_b3.advance_turn() and scheduler_b3.advance_turn(), "Advancing scheduler twice to Beat 3 must succeed.")
	var b3_intents := scheduler_b3.get_intents()
	_check(b3_intents == _expected_beat_3_intents(), "Beat 3 intents must match expected Beat 3 schedule.")
	var b3_res := phase.execute_phase(party_b3, enemies_b3, b3_intents)
	_check(
		b3_res == {"ok": true, "events": _expected_beat_3_events()},
		"Beat 3 execute_phase must resolve source 1 block, source 2 attack on slot 2, and source 3 attack on slot 1 in ascending source order."
	)
	_check(
		party_b3.get_hero(1) == {
			"id": "warden",
			"name": "Warden",
			"max_hp": 40,
			"art_path": "res://assets/paper/heroes/warden.png",
			"position": 1,
			"hp": 40,
			"block": 4,
		}
		and party_b3.get_hero(2) == {
			"id": "seamstress",
			"name": "Seamstress",
			"max_hp": 30,
			"art_path": "res://assets/paper/heroes/seamstress.png",
			"position": 2,
			"hp": 27,
			"block": 0,
		}
		and party_b3.get_hero(3) == {
			"id": "tinker",
			"name": "Tinker",
			"max_hp": 26,
			"art_path": "res://assets/paper/heroes/tinker.png",
			"position": 3,
			"hp": 26,
			"block": 0,
		},
		"Independent Beat 3 must leave Warden at 40 HP / 4 Block, Seamstress at 27 HP / 0 Block, and Tinker at 26 HP / 0 Block."
	)
	_check(
		enemies_b3.get_enemy(1).get("id") == "fray_scavenger"
		and enemies_b3.get_enemy(1).get("hp") == 14
		and enemies_b3.get_enemy(1).get("block") == 2
		and enemies_b3.get_enemy(2).get("id") == "spool_stalker"
		and enemies_b3.get_enemy(2).get("hp") == 14
		and enemies_b3.get_enemy(2).get("block") == 0
		and enemies_b3.get_enemy(3).get("id") == "seam_ripper"
		and enemies_b3.get_enemy(3).get("hp") == 18
		and enemies_b3.get_enemy(3).get("block") == 0,
		"Independent Beat 3 must give Fray Scavenger at slot 1 +2 Block (14 HP, 2 Block) while slots 2 and 3 remain at 0 Block."
	)
	_check(scheduler_b3.advance_turn(), "Advancing scheduler after Beat 3 must succeed.")
	_check(scheduler_b3.get_intents() == _expected_beat_1_intents(), "Next announced beat after Beat 3 must wrap to Beat 1.")

	# 3. Slain source-2 Spool Stalker before Beat 1:
	# Its shove is skipped (applied=false), exposed middle Seamstress stays in slot 2,
	# and source-3 attack hits unexposed rear Tinker for 4, to 22 HP.
	var slain_party := _build_catalog_party(hero_catalog)
	var slain_enemies := _build_catalog_enemies(enemy_catalog)
	_check(CombatStartingBlock.new(slain_party).apply(), "Opening Block must apply on slain-source fixture.")
	_check(
		slain_enemies.apply_damage(2, 14)
		and slain_enemies.is_slain(2)
		and slain_enemies.is_dead(2)
		and not slain_enemies.is_slain(1)
		and not slain_enemies.is_slain(3)
		and not slain_enemies.is_defeated()
		and not slain_enemies.is_victorious(),
		"Killing source-2 Spool Stalker (14 HP) via apply_damage(2, 14) must mark only slot 2 slain while the roster is not defeated."
	)
	var slain_scheduler := CombatEnemyIntents.new(definitions)
	var slain_intents := slain_scheduler.get_intents()
	var slain_res := phase.execute_phase(slain_party, slain_enemies, slain_intents)
	var expected_slain_events: Array[Dictionary] = [
		{"type": "debuff", "enemy_position": 1, "target_position": 2, "status": "exposed", "applied": true},
		{"type": "shove", "enemy_position": 2, "target_position": 2, "direction": 1, "applied": false},
		{"type": "attack", "enemy_position": 3, "target_position": 3, "applied": true},
	]
	_check(
		slain_res == {"ok": true, "events": expected_slain_events},
		"When source-2 Spool Stalker is slain before Beat 1, its shove event must report applied=false while sources 1 and 3 apply."
	)
	_check(
		slain_party.get_hero(1) == {
			"id": "warden",
			"name": "Warden",
			"max_hp": 40,
			"art_path": "res://assets/paper/heroes/warden.png",
			"position": 1,
			"hp": 40,
			"block": 6,
		}
		and slain_party.get_hero(2) == {
			"id": "seamstress",
			"name": "Seamstress",
			"max_hp": 30,
			"art_path": "res://assets/paper/heroes/seamstress.png",
			"position": 2,
			"hp": 30,
			"block": 0,
			"statuses": {"exposed": 1},
		}
		and slain_party.get_hero(3) == {
			"id": "tinker",
			"name": "Tinker",
			"max_hp": 26,
			"art_path": "res://assets/paper/heroes/tinker.png",
			"position": 3,
			"hp": 22,
			"block": 0,
		},
		"With source-2 slain, Exposed Seamstress stays in slot 2 at 30 HP and unexposed Tinker in slot 3 takes unamplified 4 damage to 22 HP."
	)
	_check(
		slain_enemies.get_enemy(1).get("position") == 1
		and slain_enemies.get_enemy(1).get("hp") == 14
		and slain_enemies.get_enemy(2).get("position") == 2
		and slain_enemies.get_enemy(2).get("hp") == 0
		and slain_enemies.get_enemy(3).get("position") == 3
		and slain_enemies.get_enemy(3).get("hp") == 18,
		"Slain Spool Stalker retains slot 2 at 0 HP while living sources 1 and 3 remain at 14 and 18 HP."
	)
	# Verify multi-enemy victory boundary only after all 3 enemies are slain.
	_check(
		slain_enemies.apply_damage(1, 14)
		and slain_enemies.is_slain(1)
		and not slain_enemies.is_defeated()
		and not slain_enemies.is_victorious(),
		"Defeating second enemy (slot 1) while slot 3 lives must not yet trigger victory."
	)
	_check(
		slain_enemies.apply_damage(3, 18)
		and slain_enemies.is_slain(3)
		and slain_enemies.is_defeated()
		and slain_enemies.is_victorious(),
		"Defeating final living enemy (slot 3 Seam Ripper, 18 HP) transitions roster to defeated/victorious."
	)

	# 4. Freshly downed Seamstress in original middle slot 2 before Beat 1:
	# Atomic phase rejection, leaving snapshots and RNG unchanged.
	var downed_party := _build_catalog_party(hero_catalog)
	var downed_enemies := _build_catalog_enemies(enemy_catalog)
	_check(CombatStartingBlock.new(downed_party).apply(), "Opening Block must apply before downing middle Seamstress.")
	_check(
		downed_party.apply_damage(2, 30) and downed_party.is_downed(2) and downed_party.get_hero(2).get("hp") == 0,
		"Downing Seamstress (30 HP) in original middle slot 2 must succeed."
	)
	var downed_scheduler := CombatEnemyIntents.new(definitions)
	var downed_intents := downed_scheduler.get_intents()
	var downed_intents_snapshot := downed_intents.duplicate(true)
	var downed_heroes_snapshot := downed_party.get_heroes()
	var downed_enemies_snapshot := downed_enemies.get_enemies()
	var downed_rng := RandomNumberGenerator.new()
	downed_rng.seed = 135792468
	var downed_rng_state := downed_rng.state
	seed(135792468)
	var expected_global := randi()
	seed(135792468)

	var downed_res := phase.execute_phase(downed_party, downed_enemies, downed_intents)
	_check(
		downed_res == {"ok": false, "events": []},
		"With freshly downed Seamstress in middle slot 2 before Beat 1, execute_phase must reject atomically with {ok: false, events: []}."
	)
	_check(
		downed_party.get_heroes() == downed_heroes_snapshot
		and downed_party.get_hero(1).get("hp") == 40
		and downed_party.get_hero(1).get("block") == 6
		and downed_party.get_hero(2).get("id") == "seamstress"
		and downed_party.get_hero(2).get("hp") == 0
		and downed_party.get_hero(2).get("statuses", {}) == {}
		and downed_party.get_hero(3).get("id") == "tinker"
		and downed_party.get_hero(3).get("hp") == 26,
		"Rejected phase with downed middle Seamstress must leave all hero positions, HP, Block, and statuses completely unchanged."
	)
	_check(
		downed_enemies.get_enemies() == downed_enemies_snapshot,
		"Rejected phase with downed middle Seamstress must leave enemy roster unchanged."
	)
	_check(
		downed_intents == downed_intents_snapshot
		and downed_scheduler.get_intents() == _expected_beat_1_intents()
		and downed_scheduler._turn_index == 0,
		"Rejected phase must leave caller intents and scheduler state unchanged."
	)
	_check(
		downed_rng.state == downed_rng_state and randi() == expected_global,
		"Rejected phase must leave local seeded RNG state and global RNG stream unchanged."
	)

	# Also prove atomic rollback when Source 1 stages Exposed 1 on living middle Seamstress
	# and Source 2's shove fails because rear Tinker at destination slot 3 is downed (Lesson 39).
	var rollback_party := _build_catalog_party(hero_catalog)
	var rollback_enemies := _build_catalog_enemies(enemy_catalog)
	_check(CombatStartingBlock.new(rollback_party).apply(), "Opening Block must apply on later-source rollback fixture.")
	_check(
		rollback_party.apply_damage(3, 26) and rollback_party.is_downed(3),
		"Downing Tinker (26 HP) at rear slot 3 must succeed."
	)
	var rollback_heroes_before := rollback_party.get_heroes()
	var rollback_enemies_before := rollback_enemies.get_enemies()
	var rollback_intents := CombatEnemyIntents.new(definitions).get_intents()
	var rollback_intents_before := rollback_intents.duplicate(true)
	var rollback_res := phase.execute_phase(rollback_party, rollback_enemies, rollback_intents)
	_check(
		rollback_res == {"ok": false, "events": []}
		and rollback_party.get_heroes() == rollback_heroes_before
		and rollback_party.get_hero(2).get("id") == "seamstress"
		and rollback_party.get_hero(2).get("statuses", {}) == {}
		and rollback_enemies.get_enemies() == rollback_enemies_before
		and rollback_intents == rollback_intents_before,
		"When Source 1 stages Exposed 1 on living Seamstress at slot 2 and Source 2 fails shoving into downed slot 3, the phase must roll back Source 1's staged debuff atomically."
	)

	# 5. Confirm invalid authored off-board shove, unsupported status, and nonintegral amounts
	# fail parsing and CombatEnemyIntents, while unmodified positive control still passes.
	var invalid_json_cases: Array[Dictionary] = [
		{
			"label": "off-board shove from slot 3 direction +1",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 3, "direction": 1}]}]'
		},
		{
			"label": "off-board shove from slot 1 direction -1",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 1, "direction": -1}]}]'
		},
		{
			"label": "shove with nonzero amount",
			"json": '[{"enemy_position": 2, "pattern": [{"type": "shove", "amount": 1, "target_position": 2, "direction": 1}]}]'
		},
		{
			"label": "shove with non-adjacent direction 2",
			"json": '[{"enemy_position": 2, "pattern": [{"type": "shove", "amount": 0, "target_position": 1, "direction": 2}]}]'
		},
		{
			"label": "unsupported debuff status poison",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 1, "target_position": 2, "status": "poison"}]}]'
		},
		{
			"label": "unsupported debuff status vulnerable",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 1, "target_position": 2, "status": "vulnerable"}]}]'
		},
		{
			"label": "empty debuff status",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 1, "target_position": 2, "status": ""}]}]'
		},
		{
			"label": "non-string debuff status",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 1, "target_position": 2, "status": 1}]}]'
		},
		{
			"label": "nonintegral debuff amount 1.5",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 1.5, "target_position": 2, "status": "exposed"}]}]'
		},
		{
			"label": "nonintegral attack amount 4.25",
			"json": '[{"enemy_position": 3, "pattern": [{"type": "attack", "amount": 4.25, "target_position": 3}]}]'
		},
		{
			"label": "nonintegral target_position 2.5",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 1, "target_position": 2.5, "status": "exposed"}]}]'
		},
		{
			"label": "nonintegral shove direction 0.5",
			"json": '[{"enemy_position": 2, "pattern": [{"type": "shove", "amount": 0, "target_position": 2, "direction": 0.5}]}]'
		},
		{
			"label": "nonintegral enemy_position 2.5",
			"json": '[{"enemy_position": 2.5, "pattern": [{"type": "block", "amount": 2}]}]'
		},
		{
			"label": "duplicate enemy_position 2",
			"json": '[{"enemy_position": 2, "pattern": [{"type": "block", "amount": 2}]}, {"enemy_position": 2, "pattern": [{"type": "buff", "amount": 3}]}]'
		},
		{
			"label": "fifth/fourth enemy_position 4",
			"json": '[{"enemy_position": 4, "pattern": [{"type": "block", "amount": 2}]}]'
		},
		{
			"label": "malformed JSON syntax",
			"json": '[{"enemy_position": 1, "pattern": ['
		},
	]
	for entry in invalid_json_cases:
		var parsed := RunFightEncounterSelection._parse_schedule_text(entry["json"])
		_check(
			parsed.is_empty(),
			"RunFightEncounterSelection._parse_schedule_text must reject %s." % entry["label"]
		)

	var invalid_intent_defs: Array[Dictionary] = [
		{
			"label": "off-board shove from slot 3 direction +1 in CombatEnemyIntents",
			"defs": [
				{"enemy_position": 2, "pattern": [{"type": "shove", "amount": 0, "target_position": 3, "direction": 1}]},
			]
		},
		{
			"label": "off-board shove from slot 1 direction -1 in CombatEnemyIntents",
			"defs": [
				{"enemy_position": 2, "pattern": [{"type": "shove", "amount": 0, "target_position": 1, "direction": -1}]},
			]
		},
		{
			"label": "unsupported status in CombatEnemyIntents",
			"defs": [
				{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 1, "target_position": 2, "status": "marked"}]},
			]
		},
		{
			"label": "nonintegral float amount in CombatEnemyIntents",
			"defs": [
				{"enemy_position": 3, "pattern": [{"type": "attack", "amount": 4.5, "target_position": 3}]},
			]
		},
		{
			"label": "duplicate enemy_position in CombatEnemyIntents",
			"defs": [
				{"enemy_position": 1, "pattern": [{"type": "block", "amount": 2}]},
				{"enemy_position": 1, "pattern": [{"type": "buff", "amount": 3}]},
			]
		},
	]
	for entry in invalid_intent_defs:
		var defs_copy: Array = entry["defs"].duplicate(true)
		var defs_snapshot := defs_copy.duplicate(true)
		var bad_intents := CombatEnemyIntents.new(defs_copy)
		_check(not bad_intents.is_valid(), "CombatEnemyIntents must reject %s." % entry["label"])
		_check(bad_intents.get_intents().is_empty(), "Invalid CombatEnemyIntents must return empty get_intents() for %s." % entry["label"])
		_check(not bad_intents.advance_turn(), "Invalid CombatEnemyIntents must reject advance_turn() for %s." % entry["label"])
		_check(defs_copy == defs_snapshot, "CombatEnemyIntents rejection must not mutate caller definitions for %s." % entry["label"])

	# Positive control still passes after all negative parser/intents checks.
	var positive_control_defs := RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	var positive_control_intents := CombatEnemyIntents.new(positive_control_defs)
	_check(
		positive_control_defs == _expected_definitions()
		and positive_control_intents.is_valid()
		and positive_control_intents.get_intents() == _expected_beat_1_intents(),
		"Unmodified positive control crossspool_mark_transfer schedule must still parse and validate cleanly."
	)

	# 6. Two independently seeded repeated traces: compare announcements, phase outputs, parties, enemies, and untouched run-RNG state.
	var trace_a := _execute_independent_beats_trace(975318642, hero_catalog, enemy_catalog)
	var trace_b := _execute_independent_beats_trace(975318642, hero_catalog, enemy_catalog)
	_check(trace_a == trace_b, "Two independently seeded repeated traces must produce identical announcements, phase outputs, parties, enemies, and RNG state.")
	_check(
		trace_a["block_1_ok"] == true
		and trace_a["block_1_second"] == false
		and trace_a["local_rng_unchanged"] == true
		and trace_a["global_rng_unchanged"] == true
		and trace_a["b4_intents"] == _expected_beat_1_intents(),
		"Repeated trace must confirm once-only starting Block, untouched local/global RNG state, and Beat 1 wraparound."
	)


func _choose_legal_fight_deterministically(map: RunMap) -> String:
	while not map.is_complete():
		var legal: Array[String] = map.get_legal_choices()
		if legal.is_empty():
			return ""
		for node_id in legal:
			if map.get_node(node_id).get("type") == "Fight":
				if map.choose_node(node_id):
					return node_id
				return ""
		if not map.choose_node(legal[0]):
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


func _execute_seeded_map_selection_and_assembly(seed_value: int, hero_catalog: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := RunMap.new()
	var generated := map.generate(rng)
	var fight_id := _choose_legal_fight_deterministically(map)
	var rng_before_select := rng.state
	var selector := RunFightEncounterSelection.new()
	var choice := selector.select_current_battle(map, rng, _local_typed_pool())
	var rng_after_select := rng.state
	var cached := selector.select_current_battle(map, rng, _local_typed_pool())
	var rng_after_cached := rng.state
	var assembled := RunTypedBattleRoster.new().assemble(choice, _local_roster_map(), [ENEMY_CATALOG_PATH])
	var party := _build_catalog_party(hero_catalog)
	var starting_block_ok := CombatStartingBlock.new(party).apply()
	var enemies: CombatEnemies = assembled.get("enemies")
	var intents := CombatEnemyIntents.new(assembled.get("definitions", []))
	var beat_1_announced := intents.get_intents()
	var beat_1_result := CombatEnemyPhase.new().execute_phase(party, enemies, beat_1_announced)
	return {
		"generated": generated,
		"floors": map.get_floors(),
		"fight_id": fight_id,
		"route": map.get_route(),
		"rng_before_select": rng_before_select,
		"rng_after_select": rng_after_select,
		"rng_after_cached": rng_after_cached,
		"choice": choice,
		"cached": cached,
		"assembled_ok": assembled.get("ok", false),
		"starting_block_ok": starting_block_ok,
		"beat_1_announced": beat_1_announced,
		"beat_1_result": beat_1_result,
		"heroes_after_beat_1": party.get_heroes(),
		"enemies_after_beat_1": enemies.get_enemies(),
		"next_rng_draw": rng.randi(),
	}


## AC4: From a real seeded RunMap's legally selected Fight node, a test-local one-entry Fight pool
## selects crossspool_mark_transfer and RunTypedBattleRoster.assemble builds the shipped
## Fray Scavenger / Spool Stalker / Seam Ripper in enemy slots 1/2/3.
## Independent same-seed trials reproduce selection, beat/event/state traces, and RNG state;
## repeated cached selection spends no further RNG and its returned records are detached;
## before-choice and malformed selection fail closed without map/RNG mutation.
func _verify_ac4_map_selection_and_roster_assembly(hero_catalog: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_VALUE
	var map := RunMap.new()
	var selector := RunFightEncounterSelection.new()

	# 1. Ungenerated map rejection without RNG or state drift.
	var ungen_snap := _snapshot_map_and_selector(map, rng, selector)
	_check(
		selector.select_current_battle(map, rng, _local_typed_pool()) == {"success": false}
		and _snapshot_map_and_selector(map, rng, selector) == ungen_snap,
		"Ungenerated RunMap must fail closed in select_current_battle without RNG or state drift."
	)

	_check(map.generate(rng), "RunMap.generate(rng) with seed %d must succeed." % SEED_VALUE)

	# 2. Before choose_node() in a fresh fixture: assert {"success": false} and no map/RNG state changes.
	var unchosen_snap := _snapshot_map_and_selector(map, rng, selector)
	_check(
		selector.select_current_battle(map, rng, _local_typed_pool()) == {"success": false}
		and selector.select_current_fight(map, rng, _local_typed_pool()["Fight"]) == {"success": false}
		and _snapshot_map_and_selector(map, rng, selector) == unchosen_snap,
		"Calling selection before choose_node() must return {success: false} without map or RNG mutation."
	)

	# Choose an actually legal Fight node from get_legal_choices() via choose_node().
	var fight_id := _choose_legal_fight_deterministically(map)
	_check(not fight_id.is_empty(), "Seeded RunMap must provide a legal Fight node via get_legal_choices() and choose_node().")
	_check(
		map.get_current_node_id() == fight_id and map.get_node(fight_id).get("type") == "Fight",
		"Current chosen node must be a legal Fight node."
	)

	# 3. Malformed pool checks in a separate fresh fixture: assert {"success": false} and no map/RNG state changes.
	var bad_rng := RandomNumberGenerator.new()
	bad_rng.seed = SEED_VALUE
	var bad_map := RunMap.new()
	_check(bad_map.generate(bad_rng), "Malformed-pool fixture RunMap.generate must succeed.")
	var bad_fight_id := _choose_legal_fight_deterministically(bad_map)
	_check(bad_fight_id == fight_id, "Malformed-pool fixture with same seed must choose the same legal Fight node.")
	var bad_selector := RunFightEncounterSelection.new()
	var pre_bad_snap := _snapshot_map_and_selector(bad_map, bad_rng, bad_selector)
	var invalid_pools: Array[Dictionary] = [
		{"label": "empty pools dictionary", "pool": {}},
		{"label": "missing Fight pool key", "pool": {"Elite": {ENCOUNTER_ID: ENCOUNTER_PATH}}},
		{"label": "non-dictionary Fight pool", "pool": {"Fight": [ENCOUNTER_PATH]}},
		{"label": "empty Fight pool", "pool": {"Fight": {}}},
		{"label": "nonexistent encounter file", "pool": {"Fight": {ENCOUNTER_ID: "res://data/encounters/does_not_exist.json"}}},
		{"label": "wrong directory path", "pool": {"Fight": {ENCOUNTER_ID: ENEMY_CATALOG_PATH}}},
		{"label": "path traversal", "pool": {"Fight": {ENCOUNTER_ID: "res://data/encounters/../enemies/run_enemies.json"}}},
		{"label": "non-json extension", "pool": {"Fight": {ENCOUNTER_ID: "res://data/encounters/crossspool_mark_transfer.tres"}}},
		{"label": "blank encounter key", "pool": {"Fight": {"   ": ENCOUNTER_PATH}}},
	]
	for bad_entry in invalid_pools:
		var rejected := bad_selector.select_current_battle(bad_map, bad_rng, bad_entry["pool"])
		_check(
			rejected == {"success": false}
			and _snapshot_map_and_selector(bad_map, bad_rng, bad_selector) == pre_bad_snap,
			"Malformed selector pool (%s) must return {success: false} without map, route, selector, or RNG state changes." % bad_entry["label"]
		)

	# 4. Positive selection with isolated one-entry pool.
	var expected_choice := {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": _expected_definitions(),
	}
	seed(842109)
	var expected_global := randi()
	seed(842109)
	var choice := selector.select_current_battle(map, rng, _local_typed_pool())
	_check(randi() == expected_global, "select_current_battle must not draw from Godot global RNG.")
	var rng_after_first := rng.state
	_check(
		choice == expected_choice,
		"select_current_battle with local one-entry Fight pool must select crossspool_mark_transfer with exact definitions."
	)

	# Repeated cached selection spends no further RNG even if passed a multi-entry pool.
	var two_entry_pool := {
		"Fight": {
			ENCOUNTER_ID: ENCOUNTER_PATH,
			"starter_attacks": STARTER_ATTACKS_PATH,
		}
	}
	var cached_choice := selector.select_current_battle(map, rng, two_entry_pool)
	_check(
		cached_choice == expected_choice and rng.state == rng_after_first,
		"Repeated select_current_battle on the same chosen node must return cached choice and spend zero RNG."
	)
	var cached_legacy := selector.select_current_fight(map, rng, two_entry_pool["Fight"])
	_check(
		cached_legacy == {
			"success": true,
			"encounter_id": ENCOUNTER_ID,
			"definitions": _expected_definitions(),
		}
		and rng.state == rng_after_first,
		"select_current_fight on the same chosen node must return cached choice without node_type and spend zero RNG."
	)

	# Prove returned definitions are deep-copied / detached from selector cache.
	var choice_for_assemble := choice.duplicate(true)
	choice["encounter_id"] = "mutated_id"
	choice["definitions"][0]["pattern"][0]["amount"] = 999
	choice["definitions"].clear()
	_check(
		selector.select_current_battle(map, rng, _local_typed_pool()) == expected_choice
		and rng.state == rng_after_first,
		"Mutating returned selection dictionary must not corrupt selector cache or advance RNG."
	)

	# 5. Assemble typed battle roster with ordered enemy IDs and real catalog.
	var choice_snapshot := choice_for_assemble.duplicate(true)
	var roster_bridge := RunTypedBattleRoster.new()
	var assembled := roster_bridge.assemble(
		choice_for_assemble,
		_local_roster_map(),
		[ENEMY_CATALOG_PATH]
	)
	_check(choice_for_assemble == choice_snapshot, "RunTypedBattleRoster.assemble must not mutate caller typed_choice.")
	_check(
		assembled.get("ok") == true
		and assembled.get("node_type") == "Fight"
		and assembled.get("encounter_id") == ENCOUNTER_ID
		and assembled.get("definitions") == _expected_definitions(),
		"RunTypedBattleRoster.assemble must succeed with Fight node_type, crossspool_mark_transfer ID, and unchanged source order."
	)
	var assembled_enemies: Variant = assembled.get("enemies")
	_check(assembled_enemies is CombatEnemies and assembled_enemies.is_valid(), "Assembled enemies must be a valid CombatEnemies instance.")
	if assembled_enemies is CombatEnemies:
		var enemy_list: Array[Dictionary] = assembled_enemies.get_enemies()
		_check(enemy_list.size() == 3, "Assembled CombatEnemies must contain exactly 3 enemies.")
		_check(
			assembled_enemies.get_enemy(1) == {
				"id": "fray_scavenger",
				"name": "Fray Scavenger",
				"max_hp": 14,
				"art_path": "res://assets/paper/enemies/fray_scavenger.png",
				"position": 1,
				"hp": 14,
				"block": 0,
			},
			"Slot 1 assembled enemy must be Fray Scavenger (14/14 HP, 0 Block)."
		)
		_check(
			assembled_enemies.get_enemy(2) == {
				"id": "spool_stalker",
				"name": "Spool Stalker",
				"max_hp": 14,
				"art_path": "res://assets/paper/enemies/spool_stalker.png",
				"position": 2,
				"hp": 14,
				"block": 0,
			},
			"Slot 2 assembled enemy must be Spool Stalker (14/14 HP, 0 Block)."
		)
		_check(
			assembled_enemies.get_enemy(3) == {
				"id": "seam_ripper",
				"name": "Seam Ripper",
				"max_hp": 18,
				"art_path": "res://assets/paper/enemies/seam_ripper.png",
				"position": 3,
				"hp": 18,
				"block": 0,
			},
			"Slot 3 assembled enemy must be Seam Ripper (18/18 HP, 0 Block)."
		)

	# Verify detachment of assembled definitions and negative roster assembly rejections.
	if assembled.has("definitions") and assembled["definitions"] is Array and not assembled["definitions"].is_empty():
		assembled["definitions"][0]["enemy_position"] = 99
	_check(choice_for_assemble == choice_snapshot, "Mutating assembled definitions must not affect caller typed_choice.")
	_check(
		roster_bridge.assemble(choice_for_assemble, {ENCOUNTER_ID: ["fray_scavenger", "spool_stalker"]}, [ENEMY_CATALOG_PATH]) == {"ok": false},
		"RunTypedBattleRoster must reject mismatched 2-enemy roster for 3-source crossspool_mark_transfer."
	)
	_check(
		roster_bridge.assemble(choice_for_assemble, {ENCOUNTER_ID: ["fray_scavenger", "spool_stalker", "fray_scavenger"]}, [ENEMY_CATALOG_PATH]) == {"ok": false},
		"RunTypedBattleRoster must reject duplicate enemy IDs."
	)
	_check(
		roster_bridge.assemble(choice_for_assemble, {ENCOUNTER_ID: ["fray_scavenger", "spool_stalker", "unknown_enemy"]}, [ENEMY_CATALOG_PATH]) == {"ok": false},
		"RunTypedBattleRoster must reject unknown enemy ID."
	)
	_check(
		roster_bridge.assemble({"success": false}, _local_roster_map(), [ENEMY_CATALOG_PATH]) == {"ok": false},
		"RunTypedBattleRoster must reject unsuccessful selection dictionary."
	)

	# 6. Independent same-seed trials reproduce selection, beat/event/state traces, and RNG state.
	var replay_a := _execute_seeded_map_selection_and_assembly(SEED_VALUE, hero_catalog)
	var replay_b := _execute_seeded_map_selection_and_assembly(SEED_VALUE, hero_catalog)
	_check(replay_a == replay_b, "Two independent same-seed RunMap/selection/roster/combat trials must produce identical traces and RNG states.")
	_check(
		replay_a["generated"] == true
		and replay_a["assembled_ok"] == true
		and replay_a["starting_block_ok"] == true
		and replay_a["rng_after_select"] == rng_after_first
		and replay_a["rng_after_select"] == replay_a["rng_after_cached"]
		and replay_a["choice"] == expected_choice
		and replay_a["beat_1_result"] == {"ok": true, "events": _expected_beat_1_events()}
		and replay_a["heroes_after_beat_1"][2].get("id") == "seamstress"
		and replay_a["heroes_after_beat_1"][2].get("hp") == 24
		and replay_a["heroes_after_beat_1"][2].get("statuses") == {"exposed": 1},
		"Same-seed trial must confirm exact selection, zero-draw cache hit, and Beat 1 mark-transfer combat resolution."
	)
