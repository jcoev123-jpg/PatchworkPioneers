extends SceneTree
const WEIGHTED = preload("res://tests/weighted_roster_assert.gd")

## Deterministic headless coverage for the authored Needlelace Wearline M04 Fight:
## slot 1 Button Guard (16 HP) and slot 2 Spool Stalker (14 HP) on a three-beat cycle
## guarding Bleed on the middle hero, then backline Weak and split-position attacks.
## Data/service only: not yet registered in live Fight pools.

const ENCOUNTER_PATH := "res://data/encounters/needlelace_wearline.json"
const ENCOUNTER_ID := "needlelace_wearline"
const HERO_CATALOG_PATH := "res://data/heroes/starter_party.json"
const ENEMY_CATALOG_PATH := "res://data/enemies/run_enemies.json"
const FRONTSEAM_PATH := "res://data/encounters/frontseam_bleed_puncture.json"

var failures: Array[String] = []
var checks := 0


func _init() -> void:
	_verify_failure_harness()
	_run_all_checks()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
			printerr(failure)
		print("needlelace_wearline_encounter_test: FAIL (", failures.size(), " failures)")
		quit(1)
		return
	print("needlelace_wearline_encounter_test: PASS (", checks, " checks)")
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
	var guard := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "button_guard", ENEMY_CATALOG_PATH), "button_guard")
	var stalker := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "spool_stalker", ENEMY_CATALOG_PATH), "spool_stalker")
	return CombatEnemies.new([guard, stalker])


func _expected_pattern_1() -> Array:
	return [
		{"type": "block", "amount": 3},
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
		{"type": "attack", "amount": 3, "target_position": 2},
	]


func _expected_pattern_2() -> Array:
	return [
		{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed"},
		{"type": "attack", "amount": 4, "target_position": 1},
		{"type": "attack", "amount": 4, "target_position": 3},
	]


func _expected_definitions() -> Array:
	return [
		{"enemy_position": 1, "pattern": _expected_pattern_1()},
		{"enemy_position": 2, "pattern": _expected_pattern_2()},
	]


func _expected_beat_1_intents() -> Array[Dictionary]:
	return [
		{"type": "block", "amount": 3, "enemy_position": 1},
		{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed", "enemy_position": 2},
	]


func _expected_beat_2_intents() -> Array[Dictionary]:
	return [
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak", "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 2},
	]


func _expected_beat_3_intents() -> Array[Dictionary]:
	return [
		{"type": "attack", "amount": 3, "target_position": 2, "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 3, "enemy_position": 2},
	]


func _expected_beat_1_events() -> Array[Dictionary]:
	return [
		{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "debuff", "enemy_position": 2, "target_position": 2, "status": "bleed", "applied": true},
	]


func _expected_beat_2_events() -> Array[Dictionary]:
	return [
		{"type": "debuff", "enemy_position": 1, "target_position": 3, "status": "weak", "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true},
	]


func _expected_beat_3_events() -> Array[Dictionary]:
	return [
		{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true},
	]


func _run_all_checks() -> void:
	var raw_hero_catalog := _load_json_array(HERO_CATALOG_PATH)
	var raw_enemy_catalog := _load_json_array(ENEMY_CATALOG_PATH)
	var raw_encounter := _load_json_array(ENCOUNTER_PATH)
	var hero_catalog_snapshot := raw_hero_catalog.duplicate(true)
	var enemy_catalog_snapshot := raw_enemy_catalog.duplicate(true)
	var encounter_snapshot := raw_encounter.duplicate(true)

	_verify_ac1_parse_and_definitions(raw_hero_catalog, raw_enemy_catalog, raw_encounter)
	_verify_ac2_intent_announcements_and_cycle(raw_enemy_catalog)
	_verify_ac3_three_beat_combat_phase(raw_hero_catalog, raw_enemy_catalog)
	_verify_ac4_roster_assembly_and_companion_parse(raw_hero_catalog, raw_enemy_catalog)

	_check(raw_hero_catalog == hero_catalog_snapshot, "Hero catalog snapshot must remain unmutated after all checks.")
	_check(raw_enemy_catalog == enemy_catalog_snapshot, "Enemy catalog snapshot must remain unmutated after all checks.")
	_check(_load_json_array(ENCOUNTER_PATH) == encounter_snapshot, "Authored needlelace_wearline.json on disk must remain unmutated after all checks.")


## AC1: needlelace_wearline.json parses through RunFightEncounterSelection as exactly
## two sources, slots 1 and 2, with the specified three-beat patterns.
func _verify_ac1_parse_and_definitions(hero_catalog: Array, enemy_catalog: Array, raw_encounter: Array) -> void:
	var warden := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "warden", HERO_CATALOG_PATH), "warden")
	var seamstress := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "seamstress", HERO_CATALOG_PATH), "seamstress")
	var tinker := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "tinker", HERO_CATALOG_PATH), "tinker")
	_check(
		warden.get("max_hp") == 40 and seamstress.get("max_hp") == 30 and tinker.get("max_hp") == 26,
		"Catalog heroes must retain Warden 40, Seamstress 30, Tinker 26 max_hp."
	)

	var guard := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "button_guard", ENEMY_CATALOG_PATH), "button_guard")
	var stalker := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "spool_stalker", ENEMY_CATALOG_PATH), "spool_stalker")
	_check(
		guard.get("max_hp") == 16 and stalker.get("max_hp") == 14,
		"Catalog enemies must retain Button Guard 16 and Spool Stalker 14 max_hp."
	)

	var raw_text := _read_text(ENCOUNTER_PATH)
	var raw_json := _load_json_array(ENCOUNTER_PATH)
	_check(raw_json.size() == 2, "needlelace_wearline.json must contain exactly 2 enemy source definitions.")
	for raw_def in raw_json:
		_check(raw_def is Dictionary, "Each raw definition must be a Dictionary.")
		if raw_def is Dictionary:
			_check(_is_integral_number(raw_def.get("enemy_position")), "Raw enemy_position must be integral before coercion.")
			var raw_pattern: Variant = raw_def.get("pattern", [])
			_check(raw_pattern is Array and raw_pattern.size() == 3, "Each raw pattern must be a 3-beat Array.")
			if raw_pattern is Array:
				for raw_action in raw_pattern:
					_check(raw_action is Dictionary, "Each raw action must be a Dictionary.")
					if raw_action is Dictionary:
						_check(_is_integral_number(raw_action.get("amount")), "Raw action amount must be integral.")
						if raw_action.has("target_position"):
							_check(_is_integral_number(raw_action.get("target_position")), "Raw target_position must be integral.")

	var definitions := RunFightEncounterSelection._parse_schedule_text(raw_text)
	_check(definitions.size() == 2, "_parse_schedule_text must return 2 definitions for needlelace_wearline.")
	for parsed_def in definitions:
		_check(typeof(parsed_def.get("enemy_position")) == TYPE_INT, "Parsed enemy_position must be TYPE_INT after coercion.")
		var parsed_pattern: Array = parsed_def.get("pattern", [])
		_check(parsed_pattern.size() == 3, "Each parsed source pattern must contain 3 actions.")
		for parsed_action in parsed_pattern:
			_check(typeof(parsed_action.get("amount")) == TYPE_INT, "Parsed action amount must be TYPE_INT after coercion.")
			if parsed_action.has("target_position"):
				_check(typeof(parsed_action.get("target_position")) == TYPE_INT, "Parsed target_position must be TYPE_INT after coercion.")

	var source_1 := _find_unique_by_key(definitions, "enemy_position", 1, ENCOUNTER_PATH)
	var source_2 := _find_unique_by_key(definitions, "enemy_position", 2, ENCOUNTER_PATH)
	_check(source_1.get("pattern") == _expected_pattern_1(), "Source 1 (Button Guard) pattern must match exact 3-beat block/weak/attack schedule.")
	_check(source_2.get("pattern") == _expected_pattern_2(), "Source 2 (Spool Stalker) pattern must match exact 3-beat bleed/attack/attack schedule.")
	_check(definitions == _expected_definitions(), "Normalized needlelace_wearline definitions must match canonical schedule.")


## AC2: CombatEnemyIntents announces one action per enemy in source-slot order:
## beat 1 Block 3 then Bleed 2 on pos 2, beat 2 Weak 1 on pos 3 then attack 4 on pos 1,
## beat 3 attack 3 on pos 2 then attack 4 on pos 3, wraparound to beat 1 on turn 4.
func _verify_ac2_intent_announcements_and_cycle(enemy_catalog: Array) -> void:
	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	var caller_definitions := definitions.duplicate(true)
	var intents := CombatEnemyIntents.new(caller_definitions)
	_check(intents.is_valid(), "CombatEnemyIntents must validate needlelace_wearline definitions.")

	caller_definitions[0]["pattern"][0]["amount"] = 999
	caller_definitions[1]["pattern"].clear()
	_check(intents.is_valid() and intents.get_intents() == _expected_beat_1_intents(),
		"Mutating caller definition array after construction must not corrupt CombatEnemyIntents.")

	var b1_read_a := intents.get_intents()
	var b1_read_b := intents.get_intents()
	_check(b1_read_a == _expected_beat_1_intents(), "Turn 1 intents must match block 3 then bleed 2 on pos 2.")
	_check(b1_read_b == _expected_beat_1_intents(), "Repeated get_intents() on Turn 1 must not advance implicitly.")
	_check(
		b1_read_a.size() == 2 and b1_read_a[0].get("enemy_position") == 1 and b1_read_a[1].get("enemy_position") == 2,
		"Turn 1 intents must be ordered by ascending enemy_position 1 then 2."
	)
	if not b1_read_a.is_empty():
		b1_read_a[0]["amount"] = 777
		b1_read_a[0]["status"] = "invented"
		b1_read_a.append({"type": "block", "amount": 9, "enemy_position": 3})
	_check(b1_read_b == _expected_beat_1_intents(), "Mutating one get_intents() result must not affect another fetched result.")
	_check(intents.get_intents() == _expected_beat_1_intents(), "Mutating returned intents must not mutate CombatEnemyIntents state.")

	_check(intents.advance_turn(), "advance_turn() from Turn 1 to Turn 2 must succeed.")
	_check(intents.get_intents() == _expected_beat_2_intents(), "Turn 2 intents must match weak 1 on pos 3 then attack 4 on pos 1.")
	_check(intents.get_intents() == _expected_beat_2_intents(), "Repeated get_intents() on Turn 2 must not advance implicitly.")

	_check(intents.advance_turn(), "advance_turn() from Turn 2 to Turn 3 must succeed.")
	_check(intents.get_intents() == _expected_beat_3_intents(), "Turn 3 intents must match attack 3 on pos 2 then attack 4 on pos 3.")
	_check(intents.get_intents() == _expected_beat_3_intents(), "Repeated get_intents() on Turn 3 must not advance implicitly.")

	_check(intents.advance_turn(), "advance_turn() from Turn 3 to Turn 4 (wraparound) must succeed.")
	_check(intents.get_intents() == _expected_beat_1_intents(), "Turn 4 announcement must wrap around to exact Turn 1 intents.")
	_check(intents.advance_turn() and intents.get_intents() == _expected_beat_2_intents(), "Turn 5 must continue cycle to Turn 2 intents.")
	_check(intents.advance_turn() and intents.get_intents() == _expected_beat_3_intents(), "Turn 6 must continue cycle to Turn 3 intents.")

	var reversed_intents := CombatEnemyIntents.new([
		_find_unique_by_key(definitions, "enemy_position", 2, ENCOUNTER_PATH).duplicate(true),
		_find_unique_by_key(definitions, "enemy_position", 1, ENCOUNTER_PATH).duplicate(true),
	])
	_check(reversed_intents.is_valid(), "CombatEnemyIntents must accept reversed source order.")
	_check(reversed_intents.get_intents() == _expected_beat_1_intents(), "CombatEnemyIntents must sort announced actions by ascending enemy_position.")

	seed(20261022)
	var expected_global := randi()
	seed(20261022)
	var rng_probe := CombatEnemyIntents.new(definitions)
	for _turn in range(6):
		rng_probe.get_intents()
		rng_probe.advance_turn()
	_check(randi() == expected_global, "CombatEnemyIntents construction, reading, and advancing must consume zero global RNG.")


## AC3: CombatEnemyPhase on living Warden/Seamstress/Tinker (40/30/26 HP,
## Warden given start-of-combat 6 Block) through all three beats.
func _verify_ac3_three_beat_combat_phase(hero_catalog: Array, enemy_catalog: Array) -> void:
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
	_check(enemies.is_valid(), "Two-enemy CombatEnemies must be valid.")

	var starting_block := CombatStartingBlock.new(party)
	_check(starting_block.apply(), "First CombatStartingBlock.apply() must grant Warden +6 opening Block.")
	var opened_heroes := party.get_heroes()
	_check(not starting_block.apply(), "Second CombatStartingBlock.apply() must fail closed as one-shot.")
	_check(party.get_heroes() == opened_heroes, "Rejected second CombatStartingBlock.apply() must not mutate party.")
	_check(
		party.get_hero(1) == {
			"id": "warden", "name": "Warden", "max_hp": 40,
			"art_path": "res://assets/paper/heroes/warden.png",
			"position": 1, "hp": 40, "block": 6,
		}
		and party.get_hero(2) == {
			"id": "seamstress", "name": "Seamstress", "max_hp": 30,
			"art_path": "res://assets/paper/heroes/seamstress.png",
			"position": 2, "hp": 30, "block": 0,
		}
		and party.get_hero(3) == {
			"id": "tinker", "name": "Tinker", "max_hp": 26,
			"art_path": "res://assets/paper/heroes/tinker.png",
			"position": 3, "hp": 26, "block": 0,
		},
		"Opening party must be Warden (40 HP, 6 Block), Seamstress (30 HP, 0 Block), Tinker (26 HP, 0 Block)."
	)

	var intents := CombatEnemyIntents.new(definitions)
	var phase := CombatEnemyPhase.new()

	# Beat 1: Button Guard gains 3 Block; Spool Stalker applies Bleed 2 to Seamstress (pos 2).
	var b1_intents := intents.get_intents()
	var b1_intents_copy := b1_intents.duplicate(true)
	_check(b1_intents == _expected_beat_1_intents(), "Beat 1 intents must match block 3 and bleed 2 on pos 2.")
	var b1_res := phase.execute_phase(party, enemies, b1_intents)
	_check(b1_intents == b1_intents_copy, "execute_phase must not mutate caller intents array.")
	_check(
		b1_res == {"ok": true, "events": _expected_beat_1_events()},
		"Beat 1 execute_phase must resolve block then debuff in ascending enemy_position order."
	)
	_check(
		party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 6
		and party.get_hero(1).get("statuses", {}) == {},
		"After Beat 1, Warden must have 40 HP, 6 Block, and no statuses."
	)
	_check(
		party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(2).get("hp") == 30
		and party.get_hero(2).get("block") == 0
		and party.get_hero(2).get("statuses") == {"bleed": 2},
		"After Beat 1, Seamstress must have 30 HP, 0 Block, and statuses={bleed: 2}."
	)
	_check(
		party.get_hero(3).get("id") == "tinker"
		and party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("block") == 0
		and party.get_hero(3).get("statuses", {}) == {},
		"After Beat 1, Tinker must have 26 HP, 0 Block, and no statuses."
	)
	_check(
		enemies.get_enemy(1).get("id") == "button_guard"
		and enemies.get_enemy(1).get("hp") == 16
		and enemies.get_enemy(1).get("block") == 3,
		"After Beat 1, Button Guard must have 16 HP and 3 Block."
	)
	_check(
		enemies.get_enemy(2).get("id") == "spool_stalker"
		and enemies.get_enemy(2).get("hp") == 14
		and enemies.get_enemy(2).get("block") == 0,
		"After Beat 1, Spool Stalker must have 14 HP and 0 Block."
	)

	# Beat 2: Button Guard applies Weak 1 to Tinker (pos 3); Spool Stalker attacks Warden (pos 1) for 4,
	# absorbed by Warden's 6 Block -> Warden stays 40 HP, Block drops to 2.
	_check(intents.advance_turn(), "Advancing intents from Beat 1 to Beat 2 must succeed.")
	var b2_intents := intents.get_intents()
	_check(b2_intents == _expected_beat_2_intents(), "Beat 2 intents must match weak 1 on pos 3 and attack 4 on pos 1.")
	var b2_res := phase.execute_phase(party, enemies, b2_intents)
	_check(
		b2_res == {"ok": true, "events": _expected_beat_2_events()},
		"Beat 2 execute_phase must resolve debuff then attack in ascending enemy_position order."
	)
	_check(
		party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 2
		and party.get_hero(1).get("statuses", {}) == {},
		"After Beat 2, Warden must be at 40 HP, 2 Block (4 absorbed), no statuses."
	)
	_check(
		party.get_hero(2).get("hp") == 30
		and party.get_hero(2).get("block") == 0
		and party.get_hero(2).get("statuses") == {"bleed": 2},
		"After Beat 2, Seamstress must remain at 30 HP, 0 Block, Bleed 2."
	)
	_check(
		party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("block") == 0
		and party.get_hero(3).get("statuses") == {"weak": 1},
		"After Beat 2, Tinker must be at 26 HP, 0 Block, Weak 1."
	)

	# Beat 3: Button Guard attacks Seamstress (pos 2) for 3; Spool Stalker attacks Tinker (pos 3) for 4.
	# No Block on Seamstress or Tinker: raw damage lands.
	_check(intents.advance_turn(), "Advancing intents from Beat 2 to Beat 3 must succeed.")
	var b3_intents := intents.get_intents()
	_check(b3_intents == _expected_beat_3_intents(), "Beat 3 intents must match attack 3 on pos 2 and attack 4 on pos 3.")
	var b3_res := phase.execute_phase(party, enemies, b3_intents)
	_check(
		b3_res == {"ok": true, "events": _expected_beat_3_events()},
		"Beat 3 execute_phase must resolve both attacks in ascending enemy_position order."
	)
	_check(
		party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 2
		and party.get_hero(1).get("statuses", {}) == {},
		"After Beat 3, Warden must remain at 40 HP, 2 Block, no statuses."
	)
	_check(
		party.get_hero(2).get("hp") == 27
		and party.get_hero(2).get("block") == 0
		and party.get_hero(2).get("statuses") == {"bleed": 2},
		"After Beat 3, Seamstress must be at 27 HP (30 - 3), 0 Block, Bleed 2."
	)
	_check(
		party.get_hero(3).get("hp") == 22
		and party.get_hero(3).get("block") == 0
		and party.get_hero(3).get("statuses") == {"weak": 1},
		"After Beat 3, Tinker must be at 22 HP (26 - 4), 0 Block, Weak 1."
	)
	_check(
		enemies.get_enemy(1).get("block") == 3,
		"After Beat 3, Button Guard Block must persist at 3."
	)
	_check(
		enemies.get_enemy(2).get("block") == 0,
		"After Beat 3, Spool Stalker Block must remain 0."
	)

	# Beat 4 wraps to Beat 1 announcements.
	_check(intents.advance_turn(), "Advancing intents from Beat 3 to Beat 4 must succeed.")
	_check(intents.get_intents() == _expected_beat_1_intents(), "Beat 4 must wrap around and announce Beat 1 intents again.")
	_check(randi() == expected_global_draw, "Executing Beats 1-3 and wraparound must consume zero global RNG.")

	# Second identical fixture for deterministic replay.
	var party_b := _build_catalog_party(hero_catalog)
	var enemies_b := _build_catalog_enemies(enemy_catalog)
	_check(CombatStartingBlock.new(party_b).apply(), "Replay fixture opening Block must apply.")
	var intents_b := CombatEnemyIntents.new(definitions)
	var phase_b := CombatEnemyPhase.new()
	var b1_b := phase_b.execute_phase(party_b, enemies_b, intents_b.get_intents())
	_check(intents_b.advance_turn(), "Replay fixture advance to Beat 2 must succeed.")
	var b2_b := phase_b.execute_phase(party_b, enemies_b, intents_b.get_intents())
	_check(intents_b.advance_turn(), "Replay fixture advance to Beat 3 must succeed.")
	var b3_b := phase_b.execute_phase(party_b, enemies_b, intents_b.get_intents())
	_check(b1_b == b1_res, "Replay Beat 1 result must match primary Beat 1 result.")
	_check(b2_b == b2_res, "Replay Beat 2 result must match primary Beat 2 result.")
	_check(b3_b == b3_res, "Replay Beat 3 result must match primary Beat 3 result.")
	_check(party_b.get_hero(2).get("hp") == 27, "Replay Seamstress must be at 27 HP after Beat 3.")
	_check(party_b.get_hero(3).get("hp") == 22, "Replay Tinker must be at 22 HP after Beat 3.")

	# No hero-turn Bleed tick inside this phase-only fixture: statuses persist unchanged across beats.
	_check(party.get_hero(2).get("statuses") == {"bleed": 2}, "Bleed 2 must persist on Seamstress across Beats 1-3 without owner-turn tick.")
	_check(party.get_hero(3).get("statuses") == {"weak": 1}, "Weak 1 must persist on Tinker across Beats 2-3 without owner-turn tick.")


## AC4: RunTypedBattleRoster assembles the test-local Fight binding;
## frontseam_bleed_puncture.json still parses; regressions intact.
func _verify_ac4_roster_assembly_and_companion_parse(hero_catalog: Array, enemy_catalog: Array) -> void:
	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))

	var typed_choice := {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": definitions,
	}
	var choice_snapshot := typed_choice.duplicate(true)
	var assembled := RunTypedBattleRoster.new().assemble(
		typed_choice,
		{ENCOUNTER_ID: ["button_guard", "spool_stalker"]},
		[ENEMY_CATALOG_PATH]
	)
	_check(assembled.get("ok") == true, "RunTypedBattleRoster.assemble must succeed for needlelace_wearline Fight.")
	_check(assembled.get("node_type") == "Fight", "Assembled node_type must be Fight.")
	_check(assembled.get("encounter_id") == ENCOUNTER_ID, "Assembled encounter_id must be needlelace_wearline.")
	_check(assembled.get("definitions") == _expected_definitions(), "Assembled definitions must match canonical schedule.")
	_check(typed_choice == choice_snapshot, "RunTypedBattleRoster.assemble must not mutate caller typed_choice.")

	var assembled_enemies: Variant = assembled.get("enemies")
	_check(assembled_enemies is CombatEnemies and assembled_enemies.is_valid(), "Assembled enemies must be a valid CombatEnemies instance.")
	if assembled_enemies is CombatEnemies:
		var enemy_list: Array[Dictionary] = assembled_enemies.get_enemies()
		_check(enemy_list.size() == 2, "Assembled CombatEnemies must contain exactly 2 enemies.")
		_check(
			WEIGHTED.project(assembled_enemies.get_enemy(1)) == {
				"id": "button_guard", "name": "Button Guard", "max_hp": 16,
				"art_path": "res://assets/paper/enemies/button_guard.png",
				"position": 1, "hp": 16, "block": 0,
			},
			"Slot 1 assembled enemy must be Button Guard with 16/16 HP, 0 Block."
		)
		_check(
			WEIGHTED.project(assembled_enemies.get_enemy(2)) == {
				"id": "spool_stalker", "name": "Spool Stalker", "max_hp": 14,
				"art_path": "res://assets/paper/enemies/spool_stalker.png",
				"position": 2, "hp": 14, "block": 0,
			},
			"Slot 2 assembled enemy must be Spool Stalker with 14/14 HP, 0 Block."
		)

	# The existing named frontseam_bleed_puncture.json remains parseable.
	var frontseam_defs := RunFightEncounterSelection._parse_schedule_text(_read_text(FRONTSEAM_PATH))
	_check(frontseam_defs.size() == 2, "frontseam_bleed_puncture.json must still parse with 2 sources.")
	_check(CombatEnemyIntents.new(frontseam_defs).is_valid(), "frontseam_bleed_puncture definitions must pass CombatEnemyIntents validation.")

	# Negative assembly rejections stay intact.
	_check(
		RunTypedBattleRoster.new().assemble(typed_choice, {ENCOUNTER_ID: ["button_guard"]}, [ENEMY_CATALOG_PATH]) == {"ok": false},
		"RunTypedBattleRoster must reject 1-enemy roster for 2-source needlelace_wearline."
	)
	_check(
		RunTypedBattleRoster.new().assemble(typed_choice, {ENCOUNTER_ID: ["button_guard", "unknown_enemy"]}, [ENEMY_CATALOG_PATH]) == {"ok": false},
		"RunTypedBattleRoster must reject unknown enemy ID."
	)
