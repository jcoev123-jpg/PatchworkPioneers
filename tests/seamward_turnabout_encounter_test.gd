extends SceneTree

const HERO_CATALOG_PATH := "res://data/heroes/starter_party.json"
const ENEMY_CATALOG_PATH := "res://data/enemies/run_enemies.json"
const SEAMWARD_PATH := "res://data/encounters/seamward_turnabout.json"
const STARTER_ATTACKS_PATH := "res://data/encounters/starter_attacks.json"
const BACKSTITCH_PATH := "res://data/encounters/backstitch_displacement.json"

var failures: Array[String] = []


func _init() -> void:
	_verify_failure_harness()
	_run_all_checks()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("seamward_turnabout_encounter_test passed")
	quit(0)


func _check(condition: bool, message: String, sink: Array[String] = failures) -> void:
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
	var guard := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "button_guard", ENEMY_CATALOG_PATH), "button_guard")
	return CombatEnemies.new([scavenger, guard])


func _run_all_checks() -> void:
	var raw_hero_catalog := _load_json_array(HERO_CATALOG_PATH)
	var raw_enemy_catalog := _load_json_array(ENEMY_CATALOG_PATH)
	var hero_catalog_snapshot := raw_hero_catalog.duplicate(true)
	var enemy_catalog_snapshot := raw_enemy_catalog.duplicate(true)

	_verify_catalog_entries(raw_hero_catalog, raw_enemy_catalog)
	_verify_ac1_schedule_parsing_and_announcements()
	_verify_ac2_three_beat_combat_execution(raw_hero_catalog, raw_enemy_catalog)
	_verify_ac3_determinism_rng_downed_slain_and_rejections(raw_hero_catalog, raw_enemy_catalog)
	_verify_ac4_replay_and_existing_encounters(raw_hero_catalog, raw_enemy_catalog)

	_check(raw_hero_catalog == hero_catalog_snapshot, "Hero catalog snapshot must remain unmutated after all checks.")
	_check(raw_enemy_catalog == enemy_catalog_snapshot, "Enemy catalog snapshot must remain unmutated after all checks.")


func _verify_catalog_entries(hero_catalog: Array, enemy_catalog: Array) -> void:
	var warden := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "warden", HERO_CATALOG_PATH), "warden")
	var seamstress := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "seamstress", HERO_CATALOG_PATH), "seamstress")
	var tinker := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "tinker", HERO_CATALOG_PATH), "tinker")
	_check(warden.get("name") == "Warden" and warden.get("max_hp") == 40, "Catalog Warden must have name Warden and 40 max_hp.")
	_check(seamstress.get("name") == "Seamstress" and seamstress.get("max_hp") == 30, "Catalog Seamstress must have name Seamstress and 30 max_hp.")
	_check(tinker.get("name") == "Tinker" and tinker.get("max_hp") == 26, "Catalog Tinker must have name Tinker and 26 max_hp.")

	var scavenger := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "fray_scavenger", ENEMY_CATALOG_PATH), "fray_scavenger")
	var guard := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "button_guard", ENEMY_CATALOG_PATH), "button_guard")
	_check(
		scavenger.get("name") == "Fray Scavenger" and scavenger.get("max_hp") == 14,
		"Catalog Fray Scavenger must have name Fray Scavenger and 14 max_hp."
	)
	_check(
		guard.get("name") == "Button Guard" and guard.get("max_hp") == 16,
		"Catalog Button Guard must have name Button Guard and 16 max_hp."
	)


func _verify_ac1_schedule_parsing_and_announcements() -> void:
	var raw_text := _read_text(SEAMWARD_PATH)
	var raw_json := _load_json_array(SEAMWARD_PATH)
	_check(raw_json.size() == 2, "seamward_turnabout.json must contain exactly 2 enemy source definitions.")
	for raw_def in raw_json:
		_check(raw_def is Dictionary, "Each raw definition must be a Dictionary.")
		if raw_def is Dictionary:
			_check(_is_integral_number(raw_def.get("enemy_position")), "Raw enemy_position must be integral before coercion.")
			var raw_pattern: Variant = raw_def.get("pattern", [])
			_check(raw_pattern is Array and raw_pattern.size() == 3, "Each raw pattern must be a 3-beat Array.")
			if raw_pattern is Array:
				for raw_action in raw_pattern:
					if raw_action is Dictionary:
						_check(_is_integral_number(raw_action.get("amount")), "Raw action amount must be integral.")
						if raw_action.has("target_position"):
							_check(_is_integral_number(raw_action.get("target_position")), "Raw target_position must be integral.")
						if raw_action.has("direction"):
							_check(_is_integral_number(raw_action.get("direction")), "Raw direction must be integral.")

	var definitions := RunFightEncounterSelection._parse_schedule_text(raw_text)
	_check(definitions.size() == 2, "RunFightEncounterSelection._parse_schedule_text must return 2 definitions for seamward_turnabout.")

	var source_1 := _find_unique_by_key(definitions, "enemy_position", 1, SEAMWARD_PATH)
	var source_2 := _find_unique_by_key(definitions, "enemy_position", 2, SEAMWARD_PATH)

	var expected_pattern_1: Array = [
		{"type": "shove", "amount": 0, "target_position": 2, "direction": -1},
		{"type": "attack", "amount": 3, "target_position": 1},
		{"type": "block", "amount": 2},
	]
	var expected_pattern_2: Array = [
		{"type": "attack", "amount": 4, "target_position": 1},
		{"type": "buff", "amount": 3},
		{"type": "attack", "amount": 3, "target_position": 3},
	]
	_check(source_1.get("pattern") == expected_pattern_1, "Source 1 pattern must match exact 3-beat Fray Scavenger schedule.")
	_check(source_2.get("pattern") == expected_pattern_2, "Source 2 pattern must match exact 3-beat Button Guard schedule.")

	var intents := CombatEnemyIntents.new(definitions)
	_check(intents.is_valid(), "CombatEnemyIntents must validate seamward_turnabout definitions.")

	var expected_beat_1: Array[Dictionary] = [
		{"type": "shove", "amount": 0, "target_position": 2, "direction": -1, "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 2},
	]
	var expected_beat_2: Array[Dictionary] = [
		{"type": "attack", "amount": 3, "target_position": 1, "enemy_position": 1},
		{"type": "buff", "amount": 3, "enemy_position": 2},
	]
	var expected_beat_3: Array[Dictionary] = [
		{"type": "block", "amount": 2, "enemy_position": 1},
		{"type": "attack", "amount": 3, "target_position": 3, "enemy_position": 2},
	]

	# Verify defensive copy independence and no implicit advance on repeated reads.
	var beat_1_a := intents.get_intents()
	var beat_1_b := intents.get_intents()
	_check(beat_1_a == expected_beat_1, "Beat 1 intents must match expected forward-shove and front-attack actions.")
	_check(beat_1_b == expected_beat_1, "Repeated get_intents() on Beat 1 must not advance implicitly.")
	if not beat_1_a.is_empty():
		beat_1_a[0]["amount"] = 999
		beat_1_a.clear()
	_check(beat_1_b == expected_beat_1, "Mutating one get_intents() result must not affect another fetched result.")
	_check(intents.get_intents() == expected_beat_1, "Mutating returned intents must not mutate CombatEnemyIntents internal state.")

	_check(intents.advance_turn(), "advance_turn() from Beat 1 to Beat 2 must succeed.")
	_check(intents.get_intents() == expected_beat_2, "Beat 2 intents must match expected front attack and self-Block buff.")
	_check(intents.get_intents() == expected_beat_2, "Repeated get_intents() on Beat 2 must not advance implicitly.")

	_check(intents.advance_turn(), "advance_turn() from Beat 2 to Beat 3 must succeed.")
	_check(intents.get_intents() == expected_beat_3, "Beat 3 intents must match expected self-Block and rear attack.")
	_check(intents.get_intents() == expected_beat_3, "Repeated get_intents() on Beat 3 must not advance implicitly.")

	_check(intents.advance_turn(), "advance_turn() from Beat 3 to Beat 4 wrap must succeed.")
	_check(intents.get_intents() == expected_beat_1, "Beat 4 must wrap back to Beat 1 announcements.")
	_check(intents.advance_turn(), "advance_turn() from Beat 4 to Beat 5 must succeed.")
	_check(intents.get_intents() == expected_beat_2, "Beat 5 must match Beat 2 announcements.")
	_check(intents.advance_turn(), "advance_turn() from Beat 5 to Beat 6 must succeed.")
	_check(intents.get_intents() == expected_beat_3, "Beat 6 must match Beat 3 announcements.")

	# Verify ascending enemy_position ordering even if definitions are supplied in reverse order.
	var reversed_intents := CombatEnemyIntents.new([source_2.duplicate(true), source_1.duplicate(true)])
	_check(reversed_intents.is_valid(), "CombatEnemyIntents must accept reversed source order.")
	_check(reversed_intents.get_intents() == expected_beat_1, "CombatEnemyIntents must sort intents by ascending enemy_position.")


func _verify_ac2_three_beat_combat_execution(hero_catalog: Array, enemy_catalog: Array) -> void:
	var party := _build_catalog_party(hero_catalog)
	var enemies := _build_catalog_enemies(enemy_catalog)
	_check(party.is_valid(), "Catalog CombatParty must be valid.")
	_check(enemies.is_valid(), "Catalog CombatEnemies must be valid.")

	var starting_block := CombatStartingBlock.new(party)
	_check(starting_block.apply(), "First CombatStartingBlock.apply() must grant Warden 6 opening Block.")
	_check(not starting_block.apply(), "Second CombatStartingBlock.apply() must fail closed as one-shot.")

	_check(
		party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("position") == 1
		and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("max_hp") == 40
		and party.get_hero(1).get("block") == 6,
		"Opening slot 1 must be Warden at 40/40 HP and 6 Block."
	)
	_check(
		party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(2).get("position") == 2
		and party.get_hero(2).get("hp") == 30
		and party.get_hero(2).get("max_hp") == 30
		and party.get_hero(2).get("block") == 0,
		"Opening slot 2 must be Seamstress at 30/30 HP and 0 Block."
	)
	_check(
		party.get_hero(3).get("id") == "tinker"
		and party.get_hero(3).get("position") == 3
		and party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("max_hp") == 26
		and party.get_hero(3).get("block") == 0,
		"Opening slot 3 must be Tinker at 26/26 HP and 0 Block."
	)
	_check(
		enemies.get_enemy(1).get("id") == "fray_scavenger"
		and enemies.get_enemy(1).get("position") == 1
		and enemies.get_enemy(1).get("hp") == 14
		and enemies.get_enemy(1).get("max_hp") == 14
		and enemies.get_enemy(1).get("block") == 0,
		"Opening enemy slot 1 must be Fray Scavenger at 14/14 HP and 0 Block."
	)
	_check(
		enemies.get_enemy(2).get("id") == "button_guard"
		and enemies.get_enemy(2).get("position") == 2
		and enemies.get_enemy(2).get("hp") == 16
		and enemies.get_enemy(2).get("max_hp") == 16
		and enemies.get_enemy(2).get("block") == 0,
		"Opening enemy slot 2 must be Button Guard at 16/16 HP and 0 Block."
	)

	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(SEAMWARD_PATH))
	var intents := CombatEnemyIntents.new(definitions)
	var phase := CombatEnemyPhase.new()

	# Beat 1: Scavenger shoves slot 2 (Seamstress) forward to slot 1 (-1),
	# then Button Guard attacks slot 1 (now Seamstress) for 4 -> Seamstress 26 HP, Warden at slot 2 with 6 Block.
	var beat_1_result := phase.execute_phase(party, enemies, intents.get_intents())
	var expected_beat_1_events: Array[Dictionary] = [
		{"type": "shove", "enemy_position": 1, "target_position": 2, "direction": -1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true},
	]
	_check(
		beat_1_result == {"ok": true, "events": expected_beat_1_events},
		"Beat 1 execute_phase must return applied shove and attack events in source order."
	)
	_check(
		party.get_hero(1).get("id") == "seamstress"
		and party.get_hero(1).get("name") == "Seamstress"
		and party.get_hero(1).get("position") == 1
		and party.get_hero(1).get("hp") == 26
		and party.get_hero(1).get("max_hp") == 30
		and party.get_hero(1).get("block") == 0,
		"After Beat 1, Seamstress must be at slot 1 with 26 HP and 0 Block."
	)
	_check(
		party.get_hero(2).get("id") == "warden"
		and party.get_hero(2).get("name") == "Warden"
		and party.get_hero(2).get("position") == 2
		and party.get_hero(2).get("hp") == 40
		and party.get_hero(2).get("max_hp") == 40
		and party.get_hero(2).get("block") == 6,
		"After Beat 1, Warden must be at slot 2 with 40 HP and all 6 opening Block intact."
	)
	_check(
		party.get_hero(3).get("id") == "tinker"
		and party.get_hero(3).get("name") == "Tinker"
		and party.get_hero(3).get("position") == 3
		and party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("max_hp") == 26
		and party.get_hero(3).get("block") == 0,
		"After Beat 1, Tinker must remain at slot 3 with 26 HP and 0 Block."
	)
	_check(
		enemies.get_enemy(1).get("hp") == 14 and enemies.get_enemy(1).get("block") == 0
		and enemies.get_enemy(2).get("hp") == 16 and enemies.get_enemy(2).get("block") == 0,
		"After Beat 1, both enemies must remain at full HP and 0 Block."
	)

	# Beat 2: Scavenger attacks slot 1 (Seamstress) for 3 (23 HP); Button Guard gains 3 Block via buff.
	_check(intents.advance_turn(), "Advancing to Beat 2 must succeed.")
	var beat_2_result := phase.execute_phase(party, enemies, intents.get_intents())
	var expected_beat_2_events: Array[Dictionary] = [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
		{"type": "buff", "enemy_position": 2, "applied": true},
	]
	_check(
		beat_2_result == {"ok": true, "events": expected_beat_2_events},
		"Beat 2 execute_phase must return applied front attack and self-Block buff events."
	)
	_check(
		party.get_hero(1).get("id") == "seamstress"
		and party.get_hero(1).get("position") == 1
		and party.get_hero(1).get("hp") == 23
		and party.get_hero(1).get("block") == 0,
		"After Beat 2, Seamstress at slot 1 must have 23 HP and 0 Block."
	)
	_check(
		party.get_hero(2).get("id") == "warden"
		and party.get_hero(2).get("position") == 2
		and party.get_hero(2).get("hp") == 40
		and party.get_hero(2).get("block") == 6,
		"After Beat 2, Warden at slot 2 must retain 40 HP and 6 Block."
	)
	_check(
		party.get_hero(3).get("id") == "tinker"
		and party.get_hero(3).get("position") == 3
		and party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("block") == 0,
		"After Beat 2, Tinker at slot 3 must retain 26 HP and 0 Block."
	)
	_check(
		enemies.get_enemy(1).get("id") == "fray_scavenger"
		and enemies.get_enemy(1).get("hp") == 14
		and enemies.get_enemy(1).get("block") == 0,
		"After Beat 2, Fray Scavenger must have 14 HP and 0 Block."
	)
	_check(
		enemies.get_enemy(2).get("id") == "button_guard"
		and enemies.get_enemy(2).get("hp") == 16
		and enemies.get_enemy(2).get("block") == 3,
		"After Beat 2, Button Guard must have 16 HP and 3 Block."
	)

	# Beat 3: Scavenger gains 2 Block via block; Button Guard attacks slot 3 (Tinker) for 3 (23 HP).
	_check(intents.advance_turn(), "Advancing to Beat 3 must succeed.")
	var beat_3_result := phase.execute_phase(party, enemies, intents.get_intents())
	var expected_beat_3_events: Array[Dictionary] = [
		{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true},
	]
	_check(
		beat_3_result == {"ok": true, "events": expected_beat_3_events},
		"Beat 3 execute_phase must return applied block and rear attack events."
	)
	_check(
		party.get_hero(1).get("id") == "seamstress"
		and party.get_hero(1).get("position") == 1
		and party.get_hero(1).get("hp") == 23
		and party.get_hero(1).get("block") == 0,
		"After Beat 3, Seamstress at slot 1 must remain at 23 HP and 0 Block."
	)
	_check(
		party.get_hero(2).get("id") == "warden"
		and party.get_hero(2).get("position") == 2
		and party.get_hero(2).get("hp") == 40
		and party.get_hero(2).get("block") == 6,
		"After Beat 3, Warden at slot 2 must retain 40 HP and 6 Block."
	)
	_check(
		party.get_hero(3).get("id") == "tinker"
		and party.get_hero(3).get("position") == 3
		and party.get_hero(3).get("hp") == 23
		and party.get_hero(3).get("block") == 0,
		"After Beat 3, Tinker at slot 3 must have 23 HP and 0 Block."
	)
	_check(
		enemies.get_enemy(1).get("id") == "fray_scavenger"
		and enemies.get_enemy(1).get("hp") == 14
		and enemies.get_enemy(1).get("block") == 2,
		"After Beat 3, Fray Scavenger must have 14 HP and 2 Block."
	)
	_check(
		enemies.get_enemy(2).get("id") == "button_guard"
		and enemies.get_enemy(2).get("hp") == 16
		and enemies.get_enemy(2).get("block") == 3,
		"After Beat 3, Button Guard must retain 16 HP and 3 Block."
	)


func _verify_ac3_determinism_rng_downed_slain_and_rejections(hero_catalog: Array, enemy_catalog: Array) -> void:
	# 1. Prove global RNG probe detects an extra draw, then verify zero global RNG consumption.
	var rng_seed := 135792468
	seed(rng_seed)
	var expected_global_draw := randi()
	seed(rng_seed)
	var _injected_draw := randi()
	_check(randi() != expected_global_draw, "Global RNG probe must detect an injected randi() draw.")

	seed(rng_seed)
	var raw_text := _read_text(SEAMWARD_PATH)
	var parsed_defs := RunFightEncounterSelection._parse_schedule_text(raw_text)
	var rng_party := _build_catalog_party(hero_catalog)
	var rng_enemies := _build_catalog_enemies(enemy_catalog)
	_check(CombatStartingBlock.new(rng_party).apply(), "RNG check CombatStartingBlock must succeed.")
	var rng_intents := CombatEnemyIntents.new(parsed_defs)
	var rng_phase := CombatEnemyPhase.new()
	for _beat in range(4):
		var step_res := rng_phase.execute_phase(rng_party, rng_enemies, rng_intents.get_intents())
		_check(step_res.get("ok", false), "RNG check beat execution must succeed.")
		_check(rng_intents.advance_turn(), "RNG check advance_turn must succeed.")
	_check(randi() == expected_global_draw, "Schedule parse, intents, starting Block, and 4 beats must not consume global RNG.")

	# 2. Downed participant in opening shove (slot 2 Seamstress downed) -> all-or-nothing failed phase.
	var downed_target_party := _build_catalog_party(hero_catalog)
	var downed_target_enemies := _build_catalog_enemies(enemy_catalog)
	_check(CombatStartingBlock.new(downed_target_party).apply(), "Opening Block must apply before downing slot 2.")
	_check(downed_target_party.apply_damage(2, 30), "Damaging Seamstress for 30 must succeed.")
	_check(downed_target_party.is_downed(2), "Seamstress at slot 2 must be downed at 0 HP.")
	var heroes_before_downed_target := downed_target_party.get_heroes()
	var enemies_before_downed_target := downed_target_enemies.get_enemies()
	var beat_1_intents := CombatEnemyIntents.new(parsed_defs).get_intents()
	var downed_target_res := CombatEnemyPhase.new().execute_phase(
		downed_target_party, downed_target_enemies, beat_1_intents
	)
	_check(
		downed_target_res == {"ok": false, "events": []},
		"Beat 1 with downed slot 2 hero must fail closed with empty events."
	)
	_check(
		downed_target_party.get_heroes() == heroes_before_downed_target,
		"Failed phase with downed slot 2 hero must not mutate any hero position, HP, or Block."
	)
	_check(
		downed_target_enemies.get_enemies() == enemies_before_downed_target,
		"Failed phase with downed slot 2 hero must not mutate any enemy HP or Block."
	)

	# 3. Downed destination participant in opening shove (slot 1 Warden downed) -> all-or-nothing failed phase.
	var downed_dest_party := _build_catalog_party(hero_catalog)
	var downed_dest_enemies := _build_catalog_enemies(enemy_catalog)
	_check(CombatStartingBlock.new(downed_dest_party).apply(), "Opening Block must apply before downing slot 1.")
	_check(downed_dest_party.apply_damage(1, 46), "Damaging Warden for 46 (6 Block + 40 HP) must succeed.")
	_check(downed_dest_party.is_downed(1), "Warden at slot 1 must be downed at 0 HP.")
	var heroes_before_downed_dest := downed_dest_party.get_heroes()
	var enemies_before_downed_dest := downed_dest_enemies.get_enemies()
	var downed_dest_res := CombatEnemyPhase.new().execute_phase(
		downed_dest_party, downed_dest_enemies, beat_1_intents
	)
	_check(
		downed_dest_res == {"ok": false, "events": []},
		"Beat 1 with downed slot 1 destination hero must fail closed with empty events."
	)
	_check(
		downed_dest_party.get_heroes() == heroes_before_downed_dest,
		"Failed phase with downed slot 1 hero must not mutate any hero position, HP, or Block."
	)
	_check(
		downed_dest_enemies.get_enemies() == enemies_before_downed_dest,
		"Failed phase with downed slot 1 hero must not mutate any enemy HP or Block."
	)

	# 4. Beat 3 when rear target Tinker (slot 3) is downed: source 1 gains 2 Block (applied=true) and source 2 attack on downed slot 3 reports applied=false without party mutation.
	var downed_rear_party := _build_catalog_party(hero_catalog)
	var downed_rear_enemies := _build_catalog_enemies(enemy_catalog)
	_check(CombatStartingBlock.new(downed_rear_party).apply(), "Opening Block must apply before downing slot 3.")
	_check(downed_rear_party.apply_damage(3, 26), "Damaging Tinker for 26 must down slot 3.")
	var beat_3_intents_builder := CombatEnemyIntents.new(parsed_defs)
	beat_3_intents_builder.advance_turn()
	beat_3_intents_builder.advance_turn()
	var beat_3_intents := beat_3_intents_builder.get_intents()
	var heroes_before_downed_rear := downed_rear_party.get_heroes()
	var downed_rear_res := CombatEnemyPhase.new().execute_phase(
		downed_rear_party, downed_rear_enemies, beat_3_intents
	)
	var expected_downed_rear_events: Array[Dictionary] = [
		{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": false},
	]
	_check(
		downed_rear_res == {"ok": true, "events": expected_downed_rear_events},
		"Beat 3 with downed slot 3 target must apply source 1 block and mark source 2 attack applied=false."
	)
	_check(
		downed_rear_party.get_heroes() == heroes_before_downed_rear,
		"Beat 3 with downed slot 3 target must leave party state unchanged."
	)
	_check(
		downed_rear_enemies.get_enemy(1).get("block") == 2 and downed_rear_enemies.get_enemy(2).get("block") == 0,
		"Beat 3 with downed slot 3 target must grant Fray Scavenger 2 Block while Button Guard stays at 0 Block."
	)

	# 5. Slain first enemy's shove is skipped and live second enemy attacks unswapped Warden (6 -> 2 Block).
	var slain_first_party := _build_catalog_party(hero_catalog)
	var slain_first_enemies := _build_catalog_enemies(enemy_catalog)
	_check(CombatStartingBlock.new(slain_first_party).apply(), "Opening Block must apply for slain-first-enemy test.")
	_check(slain_first_enemies.apply_damage(1, 14), "Slaying Fray Scavenger (14 HP) at slot 1 must succeed.")
	_check(slain_first_enemies.is_slain(1) and not slain_first_enemies.is_slain(2), "Only enemy slot 1 must be slain.")
	var slain_first_res := CombatEnemyPhase.new().execute_phase(
		slain_first_party, slain_first_enemies, beat_1_intents
	)
	var expected_slain_first_events: Array[Dictionary] = [
		{"type": "shove", "enemy_position": 1, "target_position": 2, "direction": -1, "applied": false},
		{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true},
	]
	_check(
		slain_first_res == {"ok": true, "events": expected_slain_first_events},
		"When enemy 1 is slain, Beat 1 must skip shove (applied=false) and apply enemy 2's attack (applied=true)."
	)
	_check(
		slain_first_party.get_hero(1).get("id") == "warden"
		and slain_first_party.get_hero(1).get("position") == 1
		and slain_first_party.get_hero(1).get("hp") == 40
		and slain_first_party.get_hero(1).get("block") == 2,
		"Unswapped Warden at slot 1 must absorb 4 damage with 6 Block, keeping 40 HP and 2 Block."
	)
	_check(
		slain_first_party.get_hero(2).get("id") == "seamstress"
		and slain_first_party.get_hero(2).get("position") == 2
		and slain_first_party.get_hero(2).get("hp") == 30
		and slain_first_party.get_hero(2).get("block") == 0,
		"Unswapped Seamstress at slot 2 must remain at 30 HP and 0 Block."
	)
	_check(
		slain_first_party.get_hero(3).get("id") == "tinker"
		and slain_first_party.get_hero(3).get("position") == 3
		and slain_first_party.get_hero(3).get("hp") == 26
		and slain_first_party.get_hero(3).get("block") == 0,
		"Tinker at slot 3 must remain at 26 HP and 0 Block."
	)

	# 6. Slain second enemy: shove still executes, second enemy's attack is skipped.
	var slain_second_party := _build_catalog_party(hero_catalog)
	var slain_second_enemies := _build_catalog_enemies(enemy_catalog)
	_check(CombatStartingBlock.new(slain_second_party).apply(), "Opening Block must apply for slain-second-enemy test.")
	_check(slain_second_enemies.apply_damage(2, 16), "Slaying Button Guard (16 HP) at slot 2 must succeed.")
	var slain_second_res := CombatEnemyPhase.new().execute_phase(
		slain_second_party, slain_second_enemies, beat_1_intents
	)
	var expected_slain_second_events: Array[Dictionary] = [
		{"type": "shove", "enemy_position": 1, "target_position": 2, "direction": -1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": false},
	]
	_check(
		slain_second_res == {"ok": true, "events": expected_slain_second_events},
		"When enemy 2 is slain, Beat 1 must apply enemy 1's shove and skip enemy 2's attack."
	)
	_check(
		slain_second_party.get_hero(1).get("id") == "seamstress"
		and slain_second_party.get_hero(1).get("hp") == 30
		and slain_second_party.get_hero(2).get("id") == "warden"
		and slain_second_party.get_hero(2).get("hp") == 40
		and slain_second_party.get_hero(2).get("block") == 6,
		"When enemy 2 is slain, Seamstress is shoved to slot 1 unharmed (30 HP) and Warden moves to slot 2 with 6 Block."
	)

	# 7. Invalid schedules rejected via real RunFightEncounterSelection parser, CombatEnemyIntents, and CombatEnemyPhase.
	var invalid_json_cases: Array[Dictionary] = [
		{
			"label": "duplicate enemy_position 1",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 2, "direction": -1}]}, {"enemy_position": 1, "pattern": [{"type": "attack", "amount": 4, "target_position": 1}]}]'
		},
		{
			"label": "bad shove direction 0",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 2, "direction": 0}]}]'
		},
		{
			"label": "bad shove direction -2",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 2, "direction": -2}]}]'
		},
		{
			"label": "bad shove direction 2",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 2, "direction": 2}]}]'
		},
		{
			"label": "fractional shove direction -1.5",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 2, "direction": -1.5}]}]'
		},
		{
			"label": "out-of-bounds forward shove from slot 1 (1 + -1 = 0)",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 1, "direction": -1}]}]'
		},
		{
			"label": "out-of-bounds backward shove from slot 3 (3 + 1 = 4)",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 3, "direction": 1}]}]'
		},
		{
			"label": "out-of-bounds shove target_position 0",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 0, "direction": 1}]}]'
		},
		{
			"label": "out-of-bounds shove target_position 4",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 4, "direction": -1}]}]'
		},
		{
			"label": "nonzero shove amount",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 1, "target_position": 2, "direction": -1}]}]'
		},
		{
			"label": "zero buff amount",
			"json": '[{"enemy_position": 2, "pattern": [{"type": "buff", "amount": 0}]}]'
		},
		{
			"label": "negative block amount",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "block", "amount": -1}]}]'
		},
		{
			"label": "fractional attack amount",
			"json": '[{"enemy_position": 2, "pattern": [{"type": "attack", "amount": 3.5, "target_position": 1}]}]'
		},
	]
	for case_entry in invalid_json_cases:
		var parsed_invalid := RunFightEncounterSelection._parse_schedule_text(case_entry["json"])
		_check(
			parsed_invalid.is_empty(),
			"RunFightEncounterSelection._parse_schedule_text must reject %s." % case_entry["label"]
		)

	var invalid_intent_defs: Array[Dictionary] = [
		{
			"label": "duplicate source 1 in CombatEnemyIntents",
			"defs": [
				{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 2, "direction": -1}]},
				{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 4, "target_position": 1}]},
			]
		},
		{
			"label": "bad direction 0 in CombatEnemyIntents",
			"defs": [
				{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 2, "direction": 0}]},
			]
		},
		{
			"label": "out-of-bounds shove 1 + -1 in CombatEnemyIntents",
			"defs": [
				{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 1, "direction": -1}]},
			]
		},
		{
			"label": "out-of-bounds shove 3 + 1 in CombatEnemyIntents",
			"defs": [
				{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 3, "direction": 1}]},
			]
		},
	]
	for case_entry in invalid_intent_defs:
		var bad_intents := CombatEnemyIntents.new(case_entry["defs"])
		_check(not bad_intents.is_valid(), "CombatEnemyIntents must be invalid for %s." % case_entry["label"])
		_check(bad_intents.get_intents().is_empty(), "Invalid CombatEnemyIntents must return empty get_intents() for %s." % case_entry["label"])
		_check(not bad_intents.advance_turn(), "Invalid CombatEnemyIntents must fail advance_turn() for %s." % case_entry["label"])

	var guard_party := _build_catalog_party(hero_catalog)
	var guard_enemies := _build_catalog_enemies(enemy_catalog)
	_check(CombatStartingBlock.new(guard_party).apply(), "Opening Block must apply for phase rejection guard fixture.")
	var guard_heroes_snapshot := guard_party.get_heroes()
	var guard_enemies_snapshot := guard_enemies.get_enemies()
	var invalid_phase_batches: Array[Dictionary] = [
		{
			"label": "duplicate enemy_position in phase",
			"intents": [
				{"type": "shove", "amount": 0, "target_position": 2, "direction": -1, "enemy_position": 1},
				{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 1},
			]
		},
		{
			"label": "bad shove direction in phase",
			"intents": [
				{"type": "shove", "amount": 0, "target_position": 2, "direction": 0, "enemy_position": 1},
				{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 2},
			]
		},
		{
			"label": "out-of-bounds shove 1 + -1 in phase",
			"intents": [
				{"type": "shove", "amount": 0, "target_position": 1, "direction": -1, "enemy_position": 1},
				{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 2},
			]
		},
		{
			"label": "enemy_position 3 out of bounds for 2-enemy roster",
			"intents": [
				{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 3},
			]
		},
	]
	for batch in invalid_phase_batches:
		var bad_phase_res := CombatEnemyPhase.new().execute_phase(guard_party, guard_enemies, batch["intents"])
		_check(
			bad_phase_res == {"ok": false, "events": []},
			"CombatEnemyPhase.execute_phase must reject %s." % batch["label"]
		)
		_check(
			guard_party.get_heroes() == guard_heroes_snapshot,
			"CombatEnemyPhase rejection for %s must not mutate party." % batch["label"]
		)
		_check(
			guard_enemies.get_enemies() == guard_enemies_snapshot,
			"CombatEnemyPhase rejection for %s must not mutate enemies." % batch["label"]
		)


func _execute_seeded_replay(
	seed_value: int, hero_catalog: Array, enemy_catalog: Array
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var initial_rng_state := rng.state
	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(SEAMWARD_PATH))
	var intents := CombatEnemyIntents.new(definitions)
	var party := _build_catalog_party(hero_catalog)
	var enemies := _build_catalog_enemies(enemy_catalog)
	var starting_block_ok := CombatStartingBlock.new(party).apply()
	var phase := CombatEnemyPhase.new()
	var steps: Array[Dictionary] = []
	for _step in range(4):
		var announced := intents.get_intents()
		var result := phase.execute_phase(party, enemies, announced)
		var advanced := intents.advance_turn()
		steps.append({
			"announced": announced,
			"result": result,
			"advanced": advanced,
			"heroes": party.get_heroes(),
			"enemies": enemies.get_enemies(),
			"rng_state": rng.state,
		})
	return {
		"starting_block_ok": starting_block_ok,
		"initial_rng_state": initial_rng_state,
		"final_rng_state": rng.state,
		"next_draw": rng.randi(),
		"steps": steps,
	}


func _verify_ac4_replay_and_existing_encounters(hero_catalog: Array, enemy_catalog: Array) -> void:
	# 1. Fixed-seed replay across two independent instances (including 4th-beat wraparound turnabout).
	var replay_a := _execute_seeded_replay(20261021, hero_catalog, enemy_catalog)
	var replay_b := _execute_seeded_replay(20261021, hero_catalog, enemy_catalog)
	_check(replay_a == replay_b, "Two independent fixed-seed replays must produce identical state transitions across all 4 beats.")
	_check(
		replay_a["initial_rng_state"] == replay_a["final_rng_state"],
		"Seeded RandomNumberGenerator state must remain untouched across deterministic encounter replay."
	)
	var steps_a: Array = replay_a["steps"]
	_check(steps_a.size() == 4, "Replay must record 4 beats (3-beat cycle + Beat 4 wraparound).")
	if steps_a.size() == 4:
		var beat_4_heroes: Array = steps_a[3]["heroes"]
		_check(
			beat_4_heroes[0].get("id") == "warden"
			and beat_4_heroes[0].get("position") == 1
			and beat_4_heroes[0].get("hp") == 40
			and beat_4_heroes[0].get("block") == 2
			and beat_4_heroes[1].get("id") == "seamstress"
			and beat_4_heroes[1].get("position") == 2
			and beat_4_heroes[1].get("hp") == 23
			and beat_4_heroes[1].get("block") == 0
			and beat_4_heroes[2].get("id") == "tinker"
			and beat_4_heroes[2].get("position") == 3
			and beat_4_heroes[2].get("hp") == 23
			and beat_4_heroes[2].get("block") == 0,
			"Beat 4 wraparound must shove Warden back to slot 1 before Button Guard consumes 4 of his 6 Block (leaving 2)."
		)

	# 2. Existing starter_attacks.json schedule remains completely unchanged.
	var starter_defs := RunFightEncounterSelection._parse_schedule_text(_read_text(STARTER_ATTACKS_PATH))
	_check(starter_defs.size() == 2, "starter_attacks.json must still parse into 2 source definitions.")
	var starter_s1 := _find_unique_by_key(starter_defs, "enemy_position", 1, STARTER_ATTACKS_PATH)
	var starter_s2 := _find_unique_by_key(starter_defs, "enemy_position", 2, STARTER_ATTACKS_PATH)
	var expected_starter_s1: Array = [
		{"type": "attack", "amount": 1, "target_position": 1},
		{"type": "attack", "amount": 1, "target_position": 2},
		{"type": "attack", "amount": 1, "target_position": 3},
	]
	var expected_starter_s2: Array = [
		{"type": "block", "amount": 1},
	]
	_check(starter_s1.get("pattern") == expected_starter_s1, "starter_attacks.json source 1 pattern must remain unchanged.")
	_check(starter_s2.get("pattern") == expected_starter_s2, "starter_attacks.json source 2 pattern must remain unchanged.")
	var starter_intents := CombatEnemyIntents.new(starter_defs)
	_check(starter_intents.is_valid(), "starter_attacks.json must remain valid in CombatEnemyIntents.")
	for target_pos in [1, 2, 3, 1]:
		var expected_starter_beat: Array[Dictionary] = [
			{"type": "attack", "amount": 1, "target_position": target_pos, "enemy_position": 1},
			{"type": "block", "amount": 1, "enemy_position": 2},
		]
		_check(starter_intents.get_intents() == expected_starter_beat, "starter_attacks beat announcement must remain unchanged.")
		_check(starter_intents.advance_turn(), "starter_attacks advance_turn must succeed.")

	# 3. Existing backstitch_displacement.json schedule remains completely unchanged.
	var backstitch_defs := RunFightEncounterSelection._parse_schedule_text(_read_text(BACKSTITCH_PATH))
	_check(backstitch_defs.size() == 2, "backstitch_displacement.json must still parse into 2 source definitions.")
	var backstitch_s1 := _find_unique_by_key(backstitch_defs, "enemy_position", 1, BACKSTITCH_PATH)
	var backstitch_s2 := _find_unique_by_key(backstitch_defs, "enemy_position", 2, BACKSTITCH_PATH)
	var expected_backstitch_s1: Array = [
		{"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
		{"type": "attack", "amount": 2, "target_position": 2},
		{"type": "block", "amount": 1},
	]
	var expected_backstitch_s2: Array = [
		{"type": "attack", "amount": 2, "target_position": 3},
		{"type": "debuff", "amount": 1, "target_position": 2, "status": "weak"},
		{"type": "attack", "amount": 2, "target_position": 1},
	]
	_check(backstitch_s1.get("pattern") == expected_backstitch_s1, "backstitch_displacement.json source 1 pattern must remain unchanged.")
	_check(backstitch_s2.get("pattern") == expected_backstitch_s2, "backstitch_displacement.json source 2 pattern must remain unchanged.")
	var backstitch_intents := CombatEnemyIntents.new(backstitch_defs)
	_check(backstitch_intents.is_valid(), "backstitch_displacement.json must remain valid in CombatEnemyIntents.")
	var expected_backstitch_beats: Array = [
		[
			{"type": "shove", "amount": 0, "target_position": 2, "direction": 1, "enemy_position": 1},
			{"type": "attack", "amount": 2, "target_position": 3, "enemy_position": 2},
		],
		[
			{"type": "attack", "amount": 2, "target_position": 2, "enemy_position": 1},
			{"type": "debuff", "amount": 1, "target_position": 2, "status": "weak", "enemy_position": 2},
		],
		[
			{"type": "block", "amount": 1, "enemy_position": 1},
			{"type": "attack", "amount": 2, "target_position": 1, "enemy_position": 2},
		],
		[
			{"type": "shove", "amount": 0, "target_position": 2, "direction": 1, "enemy_position": 1},
			{"type": "attack", "amount": 2, "target_position": 3, "enemy_position": 2},
		],
	]
	for expected_beat in expected_backstitch_beats:
		_check(backstitch_intents.get_intents() == expected_beat, "backstitch_displacement beat announcement must remain unchanged.")
		_check(backstitch_intents.advance_turn(), "backstitch_displacement advance_turn must succeed.")
