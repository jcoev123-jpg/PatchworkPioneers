extends SceneTree
const WEIGHTED = preload("res://tests/weighted_roster_assert.gd")

const HERO_CATALOG_PATH := "res://data/heroes/starter_party.json"
const ENEMY_CATALOG_PATH := "res://data/enemies/run_enemies.json"
const SPOOLCORD_PATH := "res://data/encounters/spoolcord_triad_relay.json"
const STARTER_ATTACKS_PATH := "res://data/encounters/starter_attacks.json"
const BUTTONHOLE_HOLDOUT_PATH := "res://data/encounters/buttonhole_holdout.json"
const ENCOUNTER_ID := "spoolcord_triad_relay"

var failures: Array[String] = []


func _init() -> void:
	_verify_failure_harness()
	_run_all_checks()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("spoolcord_triad_relay_encounter_test passed")
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


func _local_roster_map() -> Dictionary:
	return {ENCOUNTER_ID: ["button_guard", "fray_scavenger", "spool_stalker"]}


func _local_typed_pool() -> Dictionary:
	return {"Fight": {ENCOUNTER_ID: SPOOLCORD_PATH}}


func _expected_pattern_1() -> Array:
	return [
		{"type": "block", "amount": 3},
		{"type": "attack", "amount": 4, "target_position": 2},
		{"type": "buff", "amount": 2},
	]


func _expected_pattern_2() -> Array:
	return [
		{"type": "attack", "amount": 3, "target_position": 3},
		{"type": "debuff", "amount": 1, "target_position": 1, "status": "weak"},
		{"type": "attack", "amount": 4, "target_position": 1},
	]


func _expected_pattern_3() -> Array:
	return [
		{"type": "attack", "amount": 2, "target_position": 2},
		{"type": "attack", "amount": 3, "target_position": 1},
		{"type": "block", "amount": 2},
	]


func _expected_definitions() -> Array:
	return [
		{"enemy_position": 1, "pattern": _expected_pattern_1()},
		{"enemy_position": 2, "pattern": _expected_pattern_2()},
		{"enemy_position": 3, "pattern": _expected_pattern_3()},
	]


func _expected_beat_0_intents() -> Array[Dictionary]:
	return [
		{"type": "block", "amount": 3, "enemy_position": 1},
		{"type": "attack", "amount": 3, "target_position": 3, "enemy_position": 2},
		{"type": "attack", "amount": 2, "target_position": 2, "enemy_position": 3},
	]


func _expected_beat_1_intents() -> Array[Dictionary]:
	return [
		{"type": "attack", "amount": 4, "target_position": 2, "enemy_position": 1},
		{"type": "debuff", "amount": 1, "target_position": 1, "status": "weak", "enemy_position": 2},
		{"type": "attack", "amount": 3, "target_position": 1, "enemy_position": 3},
	]


func _expected_beat_2_intents() -> Array[Dictionary]:
	return [
		{"type": "buff", "amount": 2, "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 2},
		{"type": "block", "amount": 2, "enemy_position": 3},
	]


func _assemble_local_enemies(definitions: Array) -> CombatEnemies:
	var typed_choice := {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": definitions.duplicate(true),
	}
	var assembled := RunTypedBattleRoster.new().assemble(
		typed_choice,
		_local_roster_map(),
		[ENEMY_CATALOG_PATH]
	)
	_check(assembled.get("ok", false), "RunTypedBattleRoster.assemble must succeed for local spoolcord_triad_relay fixture.")
	if not assembled.get("ok", false):
		return CombatEnemies.new([])
	return assembled["enemies"]


func _run_all_checks() -> void:
	var raw_hero_catalog := _load_json_array(HERO_CATALOG_PATH)
	var raw_enemy_catalog := _load_json_array(ENEMY_CATALOG_PATH)
	var raw_spoolcord := _load_json_array(SPOOLCORD_PATH)
	var hero_catalog_snapshot := raw_hero_catalog.duplicate(true)
	var enemy_catalog_snapshot := raw_enemy_catalog.duplicate(true)
	var spoolcord_snapshot := raw_spoolcord.duplicate(true)

	_verify_ac1_schedule_catalogs_and_typed_roster(raw_hero_catalog, raw_enemy_catalog)
	_verify_ac2_and_ac3_three_beat_execution_and_wraparound(raw_hero_catalog)
	_verify_ac4_slain_downed_and_parser_rejections(raw_hero_catalog)
	_verify_ac5_map_selection_replay_and_existing_schedules(raw_hero_catalog)

	_check(raw_hero_catalog == hero_catalog_snapshot, "Hero catalog snapshot must remain unmutated after all checks.")
	_check(raw_enemy_catalog == enemy_catalog_snapshot, "Enemy catalog snapshot must remain unmutated after all checks.")
	_check(_load_json_array(SPOOLCORD_PATH) == spoolcord_snapshot, "Authored spoolcord_triad_relay.json on disk must remain unmutated after all checks.")


func _verify_ac1_schedule_catalogs_and_typed_roster(hero_catalog: Array, enemy_catalog: Array) -> void:
	# 1. Verify required starter heroes and normal enemies by stable ID without total catalog size checks.
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

	var guard := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "button_guard", ENEMY_CATALOG_PATH), "button_guard")
	var scavenger := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "fray_scavenger", ENEMY_CATALOG_PATH), "fray_scavenger")
	var stalker := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "spool_stalker", ENEMY_CATALOG_PATH), "spool_stalker")
	_check(
		guard.get("name") == "Button Guard"
		and guard.get("max_hp") == 16
		and guard.get("art_path") == "res://assets/paper/enemies/button_guard.png",
		"Catalog Button Guard must retain name Button Guard, 16 max_hp, and button_guard art_path."
	)
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

	# 2. Verify raw JSON integral numeric fields before coercion, then parse via RunFightEncounterSelection._parse_schedule_text.
	var raw_text := _read_text(SPOOLCORD_PATH)
	var raw_json := _load_json_array(SPOOLCORD_PATH)
	_check(raw_json.size() == 3, "spoolcord_triad_relay.json must contain exactly 3 enemy source definitions.")
	for raw_def in raw_json:
		_check(raw_def is Dictionary, "Each raw definition in spoolcord_triad_relay.json must be a Dictionary.")
		if raw_def is Dictionary:
			_check(_is_integral_number(raw_def.get("enemy_position")), "Raw enemy_position must be integral before coercion.")
			var raw_pattern: Variant = raw_def.get("pattern", [])
			_check(raw_pattern is Array and raw_pattern.size() == 3, "Each raw pattern in spoolcord_triad_relay.json must be a 3-beat Array.")
			if raw_pattern is Array:
				for raw_action in raw_pattern:
					_check(raw_action is Dictionary, "Each raw action must be a Dictionary.")
					if raw_action is Dictionary:
						_check(_is_integral_number(raw_action.get("amount")), "Raw action amount must be integral.")
						if raw_action.has("target_position"):
							_check(_is_integral_number(raw_action.get("target_position")), "Raw target_position must be integral.")

	var definitions := RunFightEncounterSelection._parse_schedule_text(raw_text)
	_check(definitions.size() == 3, "RunFightEncounterSelection._parse_schedule_text must return 3 definitions for spoolcord_triad_relay.")
	for parsed_def in definitions:
		_check(typeof(parsed_def.get("enemy_position")) == TYPE_INT, "Parsed enemy_position must have TYPE_INT after coercion.")
		var parsed_pattern: Array = parsed_def.get("pattern", [])
		for parsed_action in parsed_pattern:
			_check(typeof(parsed_action.get("amount")) == TYPE_INT, "Parsed action amount must have TYPE_INT after coercion.")
			if parsed_action.has("target_position"):
				_check(typeof(parsed_action.get("target_position")) == TYPE_INT, "Parsed target_position must have TYPE_INT after coercion.")

	var source_1 := _find_unique_by_key(definitions, "enemy_position", 1, SPOOLCORD_PATH)
	var source_2 := _find_unique_by_key(definitions, "enemy_position", 2, SPOOLCORD_PATH)
	var source_3 := _find_unique_by_key(definitions, "enemy_position", 3, SPOOLCORD_PATH)
	_check(source_1.get("pattern") == _expected_pattern_1(), "Source 1 pattern must match exact 3-beat Button Guard schedule.")
	_check(source_2.get("pattern") == _expected_pattern_2(), "Source 2 pattern must match exact 3-beat Fray Scavenger schedule.")
	_check(source_3.get("pattern") == _expected_pattern_3(), "Source 3 pattern must match exact 3-beat Spool Stalker schedule.")
	_check(definitions == _expected_definitions(), "Normalized spoolcord_triad_relay definitions must match canonical schedule.")

	# 3. Validate through CombatEnemyIntents across full 3-beat cycle + wraparound and verify defensive copy detachment.
	var intents := CombatEnemyIntents.new(definitions)
	_check(intents.is_valid(), "CombatEnemyIntents must validate spoolcord_triad_relay definitions.")
	var expected_beat_0 := _expected_beat_0_intents()
	var expected_beat_1 := _expected_beat_1_intents()
	var expected_beat_2 := _expected_beat_2_intents()

	var beat_0_a := intents.get_intents()
	var beat_0_b := intents.get_intents()
	_check(beat_0_a == expected_beat_0, "Beat 0 intents must match expected guard block 3, scavenger attack 3 on slot 3, and stalker attack 2 on slot 2.")
	_check(beat_0_b == expected_beat_0, "Repeated get_intents() on Beat 0 must not advance implicitly.")
	if not beat_0_a.is_empty():
		beat_0_a[0]["amount"] = 999
		beat_0_a.clear()
	_check(beat_0_b == expected_beat_0, "Mutating one get_intents() result must not affect another fetched result.")
	_check(intents.get_intents() == expected_beat_0, "Mutating returned intents must not mutate CombatEnemyIntents state.")

	_check(intents.advance_turn(), "advance_turn() from Beat 0 to Beat 1 must succeed.")
	_check(intents.get_intents() == expected_beat_1, "Beat 1 intents must match expected guard attack 4 on slot 2, scavenger weak 1 on slot 1, and stalker attack 3 on slot 1.")
	_check(intents.get_intents() == expected_beat_1, "Repeated get_intents() on Beat 1 must not advance implicitly.")

	_check(intents.advance_turn(), "advance_turn() from Beat 1 to Beat 2 must succeed.")
	_check(intents.get_intents() == expected_beat_2, "Beat 2 intents must match expected guard buff 2, scavenger attack 4 on slot 1, and stalker block 2.")
	_check(intents.get_intents() == expected_beat_2, "Repeated get_intents() on Beat 2 must not advance implicitly.")

	_check(intents.advance_turn(), "advance_turn() from Beat 2 to Beat 0 wraparound must succeed.")
	_check(intents.get_intents() == expected_beat_0, "Next advance after Beat 2 must wrap around to exact Beat 0 intents.")
	_check(intents.advance_turn() and intents.get_intents() == expected_beat_1, "Post-wrap Beat 1 must match Beat 1 intents.")
	_check(intents.advance_turn() and intents.get_intents() == expected_beat_2, "Post-wrap Beat 2 must match Beat 2 intents.")

	var permuted_intents := CombatEnemyIntents.new([
		source_3.duplicate(true),
		source_1.duplicate(true),
		source_2.duplicate(true),
	])
	_check(permuted_intents.is_valid(), "CombatEnemyIntents must accept permuted source order.")
	_check(permuted_intents.get_intents() == expected_beat_0, "CombatEnemyIntents must sort announced actions by ascending enemy_position.")

	# 4. Assemble slot 1 Button Guard (16 HP), slot 2 Fray Scavenger (14 HP), and slot 3 Spool Stalker (14 HP) through RunTypedBattleRoster.
	var typed_choice := {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": definitions.duplicate(true),
	}
	var choice_before_assemble := typed_choice.duplicate(true)
	var roster_bridge := RunTypedBattleRoster.new()
	var assembled := roster_bridge.assemble(typed_choice, _local_roster_map(), [ENEMY_CATALOG_PATH])
	_check(typed_choice == choice_before_assemble, "RunTypedBattleRoster.assemble must not mutate caller typed_choice.")
	_check(
		assembled.get("ok") == true
		and assembled.get("node_type") == "Fight"
		and assembled.get("encounter_id") == ENCOUNTER_ID
		and assembled.get("definitions") == definitions,
		"RunTypedBattleRoster.assemble must return ok=true, Fight node_type, spoolcord_triad_relay ID, and exact definitions."
	)
	var assembled_enemies: Variant = assembled.get("enemies")
	_check(assembled_enemies is CombatEnemies and assembled_enemies.is_valid(), "Assembled enemies must be a valid CombatEnemies instance.")
	if assembled_enemies is CombatEnemies:
		var enemy_list: Array[Dictionary] = assembled_enemies.get_enemies()
		_check(enemy_list.size() == 3, "Assembled CombatEnemies must contain exactly 3 slots.")
		_check(
			WEIGHTED.project(assembled_enemies.get_enemy(1)) == {
				"id": "button_guard",
				"name": "Button Guard",
				"max_hp": 16,
				"art_path": "res://assets/paper/enemies/button_guard.png",
				"position": 1,
				"hp": 16,
				"block": 0,
			},
			"Slot 1 assembled enemy must be Button Guard with 16/16 HP, 0 Block, and exact art_path."
		)
		_check(
			WEIGHTED.project(assembled_enemies.get_enemy(2)) == {
				"id": "fray_scavenger",
				"name": "Fray Scavenger",
				"max_hp": 14,
				"art_path": "res://assets/paper/enemies/fray_scavenger.png",
				"position": 2,
				"hp": 14,
				"block": 0,
			},
			"Slot 2 assembled enemy must be Fray Scavenger with 14/14 HP, 0 Block, and exact art_path."
		)
		_check(
			WEIGHTED.project(assembled_enemies.get_enemy(3)) == {
				"id": "spool_stalker",
				"name": "Spool Stalker",
				"max_hp": 14,
				"art_path": "res://assets/paper/enemies/spool_stalker.png",
				"position": 3,
				"hp": 14,
				"block": 0,
			},
			"Slot 3 assembled enemy must be Spool Stalker with 14/14 HP, 0 Block, and exact art_path."
		)

	# Verify detachment of assembled definitions and negative roster assembly rejections.
	if assembled.has("definitions") and assembled["definitions"] is Array and not assembled["definitions"].is_empty():
		assembled["definitions"][0]["enemy_position"] = 99
	_check(typed_choice == choice_before_assemble, "Mutating assembled definitions must not affect caller typed_choice.")
	_check(
		roster_bridge.assemble(typed_choice, {ENCOUNTER_ID: ["button_guard", "fray_scavenger"]}, [ENEMY_CATALOG_PATH]) == {"ok": false},
		"RunTypedBattleRoster must reject mismatched 2-enemy roster for 3-source spoolcord_triad_relay."
	)
	_check(
		roster_bridge.assemble(typed_choice, {ENCOUNTER_ID: ["button_guard", "fray_scavenger", "button_guard"]}, [ENEMY_CATALOG_PATH]) == {"ok": false},
		"RunTypedBattleRoster must reject duplicate enemy IDs."
	)
	_check(
		roster_bridge.assemble(typed_choice, {ENCOUNTER_ID: ["button_guard", "fray_scavenger", "unknown_enemy"]}, [ENEMY_CATALOG_PATH]) == {"ok": false},
		"RunTypedBattleRoster must reject unknown enemy ID."
	)


func _execute_three_beat_trace(seed_value: int, hero_catalog: Array) -> Dictionary:
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = seed_value
	var local_rng_initial := local_rng.state
	seed(seed_value)
	var expected_global := randi()
	seed(seed_value)

	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(SPOOLCORD_PATH))
	var party := _build_catalog_party(hero_catalog)
	var enemies := _assemble_local_enemies(definitions)
	var starting_block := CombatStartingBlock.new(party)
	var first_block_apply := starting_block.apply()
	var second_block_apply := starting_block.apply()
	var opening_heroes := party.get_heroes()
	var opening_enemies := enemies.get_enemies()

	var intents := CombatEnemyIntents.new(definitions)
	var phase := CombatEnemyPhase.new()

	var beat_0_announced := intents.get_intents()
	var beat_0_res := phase.execute_phase(party, enemies, beat_0_announced)
	var heroes_after_0 := party.get_heroes()
	var enemies_after_0 := enemies.get_enemies()

	var reset_before_1 := party.start_player_turn()
	var advance_to_1 := intents.advance_turn()
	var beat_1_announced := intents.get_intents()
	var beat_1_res := phase.execute_phase(party, enemies, beat_1_announced)
	var heroes_after_1 := party.get_heroes()
	var enemies_after_1 := enemies.get_enemies()

	var reset_before_2 := party.start_player_turn()
	var advance_to_2 := intents.advance_turn()
	var beat_2_announced := intents.get_intents()
	var beat_2_res := phase.execute_phase(party, enemies, beat_2_announced)
	var heroes_after_2 := party.get_heroes()
	var enemies_after_2 := enemies.get_enemies()

	var advance_to_wrap := intents.advance_turn()
	var wrap_announced := intents.get_intents()
	var global_after := randi()

	return {
		"first_block_apply": first_block_apply,
		"second_block_apply": second_block_apply,
		"opening_heroes": opening_heroes,
		"opening_enemies": opening_enemies,
		"beat_0_announced": beat_0_announced,
		"beat_0_res": beat_0_res,
		"heroes_after_0": heroes_after_0,
		"enemies_after_0": enemies_after_0,
		"reset_before_1": reset_before_1,
		"advance_to_1": advance_to_1,
		"beat_1_announced": beat_1_announced,
		"beat_1_res": beat_1_res,
		"heroes_after_1": heroes_after_1,
		"enemies_after_1": enemies_after_1,
		"reset_before_2": reset_before_2,
		"advance_to_2": advance_to_2,
		"beat_2_announced": beat_2_announced,
		"beat_2_res": beat_2_res,
		"heroes_after_2": heroes_after_2,
		"enemies_after_2": enemies_after_2,
		"advance_to_wrap": advance_to_wrap,
		"wrap_announced": wrap_announced,
		"local_rng_unchanged": local_rng.state == local_rng_initial,
		"global_rng_unchanged": global_after == expected_global,
	}


func _verify_ac2_and_ac3_three_beat_execution_and_wraparound(hero_catalog: Array) -> void:
	# Prove global RNG probe detects an extra draw, then verify zero global RNG consumption across all 3 beats + wrap.
	var rng_seed := 357913579
	seed(rng_seed)
	var expected_global_draw := randi()
	seed(rng_seed)
	var _injected_draw := randi()
	_check(randi() != expected_global_draw, "Global RNG probe must detect an injected randi() draw.")

	seed(rng_seed)
	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(SPOOLCORD_PATH))
	var party := _build_catalog_party(hero_catalog)
	var enemies := _assemble_local_enemies(definitions)
	_check(party.is_valid(), "Catalog CombatParty must be valid.")
	_check(enemies.is_valid(), "Assembled CombatEnemies must be valid.")

	var starting_block := CombatStartingBlock.new(party)
	_check(starting_block.apply(), "First CombatStartingBlock.apply() must grant Warden +6 opening Block.")
	_check(not starting_block.apply(), "Second CombatStartingBlock.apply() must fail closed as one-shot.")
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
		"Opening slot 1 must be Warden with 40/40 HP and 6 Block."
	)
	_check(
		party.get_hero(2) == {
			"id": "seamstress",
			"name": "Seamstress",
			"max_hp": 30,
			"art_path": "res://assets/paper/heroes/seamstress.png",
			"position": 2,
			"hp": 30,
			"block": 0,
		},
		"Opening slot 2 must be Seamstress with 30/30 HP and 0 Block."
	)
	_check(
		party.get_hero(3) == {
			"id": "tinker",
			"name": "Tinker",
			"max_hp": 26,
			"art_path": "res://assets/paper/heroes/tinker.png",
			"position": 3,
			"hp": 26,
			"block": 0,
		},
		"Opening slot 3 must be Tinker with 26/26 HP and 0 Block."
	)

	var intents := CombatEnemyIntents.new(definitions)
	var phase := CombatEnemyPhase.new()

	# Beat 0 (AC2):
	# Slot 1 Button Guard gains 3 Block;
	# Slot 2 Fray Scavenger attacks slot 3 Tinker for 3 (26 -> 23 HP);
	# Slot 3 Spool Stalker attacks slot 2 Seamstress for 2 (30 -> 28 HP).
	var beat_0_announced := intents.get_intents()
	_check(
		beat_0_announced == _expected_beat_0_intents(),
		"Beat 0 announced intents must match slot 1 block 3, slot 2 attack 3 on pos 3, and slot 3 attack 2 on pos 2."
	)
	var beat_0_res := phase.execute_phase(party, enemies, beat_0_announced)
	var expected_beat_0_events: Array[Dictionary] = [
		{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true},
		{"type": "attack", "enemy_position": 3, "target_position": 2, "applied": true},
	]
	_check(
		beat_0_res == {"ok": true, "events": expected_beat_0_events},
		"Beat 0 execute_phase must resolve slot 1 block, slot 2 attack on Tinker, and slot 3 attack on Seamstress in ascending source order."
	)
	_check(
		party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("position") == 1
		and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 6
		and party.get_hero(1).get("statuses", {}) == {},
		"After Beat 0, Warden must remain at 40 HP, 6 Block, and no statuses."
	)
	_check(
		party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(2).get("position") == 2
		and party.get_hero(2).get("hp") == 28
		and party.get_hero(2).get("block") == 0
		and party.get_hero(2).get("statuses", {}) == {},
		"After Beat 0, Seamstress must have 28 HP, 0 Block, and no statuses."
	)
	_check(
		party.get_hero(3).get("id") == "tinker"
		and party.get_hero(3).get("position") == 3
		and party.get_hero(3).get("hp") == 23
		and party.get_hero(3).get("block") == 0
		and party.get_hero(3).get("statuses", {}) == {},
		"After Beat 0, Tinker must have 23 HP, 0 Block, and no statuses."
	)
	_check(
		enemies.get_enemy(1).get("id") == "button_guard"
		and enemies.get_enemy(1).get("position") == 1
		and enemies.get_enemy(1).get("hp") == 16
		and enemies.get_enemy(1).get("block") == 3
		and enemies.get_enemy(2).get("id") == "fray_scavenger"
		and enemies.get_enemy(2).get("position") == 2
		and enemies.get_enemy(2).get("hp") == 14
		and enemies.get_enemy(2).get("block") == 0
		and enemies.get_enemy(3).get("id") == "spool_stalker"
		and enemies.get_enemy(3).get("position") == 3
		and enemies.get_enemy(3).get("hp") == 14
		and enemies.get_enemy(3).get("block") == 0,
		"After Beat 0, Button Guard has 16 HP / 3 Block while Fray Scavenger (14 HP / 0 Block) and Spool Stalker (14 HP / 0 Block) are unchanged."
	)

	# Player-turn boundary before Beat 1 (AC3): explicitly reset hero Block, advance intents.
	_check(party.start_player_turn(), "party.start_player_turn() before Beat 1 must succeed.")
	_check(
		party.get_hero(1).get("block") == 0
		and party.get_hero(2).get("block") == 0
		and party.get_hero(3).get("block") == 0,
		"party.start_player_turn() must reset Warden's opening 6 Block to 0."
	)
	_check(intents.advance_turn(), "Advancing intents from Beat 0 to Beat 1 must succeed.")

	# Beat 1 (AC3):
	# Slot 1 Button Guard attacks Seamstress (pos 2) for 4 (28 -> 24 HP);
	# Slot 2 Fray Scavenger applies Weak 1 to living Warden (pos 1);
	# Slot 3 Spool Stalker attacks Warden (pos 1) for 3 (40 -> 37 HP).
	var beat_1_announced := intents.get_intents()
	_check(
		beat_1_announced == _expected_beat_1_intents(),
		"Beat 1 announced intents must match slot 1 attack 4 on pos 2, slot 2 debuff weak 1 on pos 1, and slot 3 attack 3 on pos 1."
	)
	var beat_1_res := phase.execute_phase(party, enemies, beat_1_announced)
	var expected_beat_1_events: Array[Dictionary] = [
		{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
		{"type": "debuff", "enemy_position": 2, "target_position": 1, "status": "weak", "applied": true},
		{"type": "attack", "enemy_position": 3, "target_position": 1, "applied": true},
	]
	_check(
		beat_1_res == {"ok": true, "events": expected_beat_1_events},
		"Beat 1 execute_phase must resolve slot 1 attack on Seamstress, slot 2 weak debuff on Warden, and slot 3 attack on Warden in source order."
	)
	_check(
		party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("position") == 1
		and party.get_hero(1).get("hp") == 37
		and party.get_hero(1).get("block") == 0
		and party.get_hero(1).get("statuses") == {"weak": 1},
		"After Beat 1, Warden must have 37 HP, 0 Block, and statuses={weak: 1}."
	)
	_check(
		party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(2).get("position") == 2
		and party.get_hero(2).get("hp") == 24
		and party.get_hero(2).get("block") == 0
		and party.get_hero(2).get("statuses", {}) == {},
		"After Beat 1, Seamstress must have 24 HP, 0 Block, and no statuses."
	)
	_check(
		party.get_hero(3).get("id") == "tinker"
		and party.get_hero(3).get("position") == 3
		and party.get_hero(3).get("hp") == 23
		and party.get_hero(3).get("block") == 0
		and party.get_hero(3).get("statuses", {}) == {},
		"After Beat 1, Tinker must remain at 23 HP, 0 Block, and no statuses."
	)
	_check(
		enemies.get_enemy(1).get("hp") == 16 and enemies.get_enemy(1).get("block") == 3
		and enemies.get_enemy(2).get("hp") == 14 and enemies.get_enemy(2).get("block") == 0
		and enemies.get_enemy(3).get("hp") == 14 and enemies.get_enemy(3).get("block") == 0,
		"After Beat 1, enemy HP and Block must remain 16/3, 14/0, and 14/0."
	)

	# Player-turn boundary before Beat 2 (AC3): explicitly reset hero Block without simulating status-turn expiry.
	_check(party.start_player_turn(), "party.start_player_turn() before Beat 2 must succeed.")
	_check(
		party.get_hero(1).get("statuses") == {"weak": 1},
		"CombatParty.start_player_turn() resets Block only and must not expire Warden's Weak 1."
	)
	_check(intents.advance_turn(), "Advancing intents from Beat 1 to Beat 2 must succeed.")

	# Beat 2 (AC3):
	# Slot 1 Button Guard buffs its own Block by 2 (3 -> 5 Block);
	# Slot 2 Fray Scavenger attacks Warden (pos 1) for 4 (37 -> 33 HP);
	# Slot 3 Spool Stalker gains 2 Block (0 -> 2 Block).
	var beat_2_announced := intents.get_intents()
	_check(
		beat_2_announced == _expected_beat_2_intents(),
		"Beat 2 announced intents must match slot 1 buff 2, slot 2 attack 4 on pos 1, and slot 3 block 2."
	)
	var beat_2_res := phase.execute_phase(party, enemies, beat_2_announced)
	var expected_beat_2_events: Array[Dictionary] = [
		{"type": "buff", "enemy_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true},
		{"type": "block", "enemy_position": 3, "applied": true},
	]
	_check(
		beat_2_res == {"ok": true, "events": expected_beat_2_events},
		"Beat 2 execute_phase must resolve slot 1 buff, slot 2 attack on Warden, and slot 3 block in source order."
	)
	_check(
		party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("position") == 1
		and party.get_hero(1).get("hp") == 33
		and party.get_hero(1).get("block") == 0
		and party.get_hero(1).get("statuses") == {"weak": 1},
		"After Beat 2, Warden must have 33 HP, 0 Block, and statuses={weak: 1}."
	)
	_check(
		party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(2).get("position") == 2
		and party.get_hero(2).get("hp") == 24
		and party.get_hero(2).get("block") == 0
		and party.get_hero(2).get("statuses", {}) == {},
		"After Beat 2, Seamstress must remain at 24 HP, 0 Block, and no statuses."
	)
	_check(
		party.get_hero(3).get("id") == "tinker"
		and party.get_hero(3).get("position") == 3
		and party.get_hero(3).get("hp") == 23
		and party.get_hero(3).get("block") == 0
		and party.get_hero(3).get("statuses", {}) == {},
		"After Beat 2, Tinker must remain at 23 HP, 0 Block, and no statuses."
	)
	_check(
		enemies.get_enemy(1).get("id") == "button_guard"
		and enemies.get_enemy(1).get("position") == 1
		and enemies.get_enemy(1).get("hp") == 16
		and enemies.get_enemy(1).get("block") == 5
		and enemies.get_enemy(2).get("id") == "fray_scavenger"
		and enemies.get_enemy(2).get("position") == 2
		and enemies.get_enemy(2).get("hp") == 14
		and enemies.get_enemy(2).get("block") == 0
		and enemies.get_enemy(3).get("id") == "spool_stalker"
		and enemies.get_enemy(3).get("position") == 3
		and enemies.get_enemy(3).get("hp") == 14
		and enemies.get_enemy(3).get("block") == 2,
		"After Beat 2, Button Guard has 16 HP / 5 Block, Fray Scavenger has 14 HP / 0 Block, and Spool Stalker has 14 HP / 2 Block."
	)

	# Advancing once more wraps announcements to Beat 0 without RNG draw.
	_check(intents.advance_turn(), "Advancing intents after Beat 2 must succeed.")
	_check(intents.get_intents() == _expected_beat_0_intents(), "Advancing after Beat 2 must wrap announcements to Beat 0.")
	_check(randi() == expected_global_draw, "All 3 beats, Block resets, and wraparound must consume zero global RNG.")

	# Compare two fresh seeded fixture traces including announcements, events, states, and untouched RNG/global RNG.
	var trace_a := _execute_three_beat_trace(864209753, hero_catalog)
	var trace_b := _execute_three_beat_trace(864209753, hero_catalog)
	_check(trace_a == trace_b, "Two fresh seeded 3-beat fixture traces must match identically across announcements, events, states, and RNG.")
	_check(
		trace_a["first_block_apply"] == true
		and trace_a["second_block_apply"] == false
		and trace_a["local_rng_unchanged"] == true
		and trace_a["global_rng_unchanged"] == true
		and trace_a["wrap_announced"] == _expected_beat_0_intents(),
		"Seeded 3-beat trace must enforce one-time opening Block, zero RNG consumption, and exact Beat 0 wraparound."
	)


func _verify_ac4_slain_downed_and_parser_rejections(hero_catalog: Array) -> void:
	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(SPOOLCORD_PATH))

	# 1. Separate fixture: Slay enemy slot 2 (Fray Scavenger, 14 HP) before Beat 1 ->
	# expect applied=false for Weak while living slot 1 and slot 3 attacks still resolve.
	var slain_s2_party := _build_catalog_party(hero_catalog)
	var slain_s2_enemies := _assemble_local_enemies(definitions)
	_check(CombatStartingBlock.new(slain_s2_party).apply(), "Opening Block must apply on slain-source-2 fixture.")
	var slain_s2_intents := CombatEnemyIntents.new(definitions)
	var phase := CombatEnemyPhase.new()
	_check(
		phase.execute_phase(slain_s2_party, slain_s2_enemies, slain_s2_intents.get_intents()).get("ok", false),
		"Beat 0 on slain-source-2 fixture must succeed."
	)
	_check(slain_s2_party.start_player_turn(), "Resetting hero Block before Beat 1 on slain-source-2 fixture must succeed.")
	_check(slain_s2_intents.advance_turn(), "Advancing to Beat 1 on slain-source-2 fixture must succeed.")
	_check(slain_s2_enemies.apply_damage(2, 14), "Slaying Fray Scavenger (14 HP) at slot 2 before Beat 1 must succeed.")
	_check(
		not slain_s2_enemies.is_slain(1)
		and slain_s2_enemies.is_slain(2)
		and not slain_s2_enemies.is_slain(3)
		and not slain_s2_enemies.is_defeated(),
		"Only slot 2 Fray Scavenger must be slain; 3-enemy roster is not defeated yet."
	)

	var beat_1_intents := slain_s2_intents.get_intents()
	var slain_s2_res := phase.execute_phase(slain_s2_party, slain_s2_enemies, beat_1_intents)
	var expected_slain_s2_events: Array[Dictionary] = [
		{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
		{"type": "debuff", "enemy_position": 2, "target_position": 1, "status": "weak", "applied": false},
		{"type": "attack", "enemy_position": 3, "target_position": 1, "applied": true},
	]
	_check(
		slain_s2_res == {"ok": true, "events": expected_slain_s2_events},
		"When slot 2 Fray Scavenger is slain before Beat 1, its Weak debuff must report applied=false while living slot 1 and slot 3 attacks resolve."
	)
	_check(
		slain_s2_party.get_hero(1).get("id") == "warden"
		and slain_s2_party.get_hero(1).get("hp") == 37
		and slain_s2_party.get_hero(1).get("block") == 0
		and slain_s2_party.get_hero(1).get("statuses", {}) == {},
		"With slot 2 slain before Beat 1, Warden takes 3 damage from slot 3 (40 -> 37 HP) and receives NO Weak status."
	)
	_check(
		slain_s2_party.get_hero(2).get("id") == "seamstress"
		and slain_s2_party.get_hero(2).get("hp") == 24
		and slain_s2_party.get_hero(2).get("block") == 0
		and slain_s2_party.get_hero(2).get("statuses", {}) == {},
		"With slot 2 slain before Beat 1, Seamstress still takes 4 damage from living slot 1 (28 -> 24 HP)."
	)
	_check(
		slain_s2_party.get_hero(3).get("id") == "tinker"
		and slain_s2_party.get_hero(3).get("hp") == 23
		and slain_s2_party.get_hero(3).get("block") == 0
		and slain_s2_party.get_hero(3).get("statuses", {}) == {},
		"Tinker remains at 23 HP and 0 Block during Beat 1."
	)
	_check(
		slain_s2_enemies.get_enemy(1).get("hp") == 16 and slain_s2_enemies.get_enemy(1).get("block") == 3
		and slain_s2_enemies.get_enemy(2).get("hp") == 0 and slain_s2_enemies.get_enemy(2).get("block") == 0
		and slain_s2_enemies.get_enemy(2).get("position") == 2
		and slain_s2_enemies.get_enemy(3).get("hp") == 14 and slain_s2_enemies.get_enemy(3).get("block") == 0,
		"Slain Fray Scavenger retains slot 2 at 0 HP while living enemies retain their slots, HP, and Block."
	)
	# Verify multi-enemy victory boundary on the 3-enemy roster:
	_check(slain_s2_enemies.apply_damage(1, 3) and slain_s2_enemies.apply_damage(1, 16), "Slaying Button Guard (3 Block + 16 HP) at slot 1 must succeed.")
	_check(slain_s2_enemies.is_slain(1) and not slain_s2_enemies.is_defeated(), "With slots 1 and 2 slain and slot 3 alive, roster is still not defeated.")
	_check(slain_s2_enemies.apply_damage(3, 14) and slain_s2_enemies.is_defeated() and slain_s2_enemies.is_victorious(), "Victory begins only after the final living enemy (slot 3) is defeated.")

	# 2. Separate fixture: Down Seamstress before Beat 1 ->
	# expect {"ok": false, "events": []} and no committed partial state, RNG, or intent advance.
	# In Beat 1, slot 1 attacks position 2 for 4, slot 2 applies Weak 1 to position 1, and slot 3 attacks position 1 for 3.
	# First swap living Seamstress (slot 2) into front slot 1 and Warden into slot 2 via CombatEnemySpecialActions shove,
	# then down Seamstress at slot 1 before Beat 1: slot 1's attack stages 4 damage on living Warden at slot 2,
	# and slot 2's Weak 1 debuff on already-downed Seamstress at slot 1 rejects the ENTIRE Beat 1 phase atomically.
	var downed_party := _build_catalog_party(hero_catalog)
	var downed_enemies := _assemble_local_enemies(definitions)
	_check(CombatStartingBlock.new(downed_party).apply(), "Opening Block must apply on downed-Seamstress fixture.")
	var downed_intents := CombatEnemyIntents.new(definitions)
	_check(
		phase.execute_phase(downed_party, downed_enemies, downed_intents.get_intents()).get("ok", false),
		"Beat 0 on downed-Seamstress fixture must succeed."
	)
	_check(downed_intents.advance_turn(), "Advancing intents to Beat 1 on downed-Seamstress fixture must succeed.")
	_check(downed_party.start_player_turn(), "Resetting hero Block before Beat 1 on downed-Seamstress fixture must succeed.")
	var swap_to_front := CombatEnemySpecialActions.new().execute_actions(
		downed_party,
		downed_enemies,
		[{"enemy_position": 1, "type": "shove", "amount": 0, "target_position": 2, "direction": -1}]
	)
	_check(
		swap_to_front.get("ok", false)
		and downed_party.get_hero(1).get("id") == "seamstress"
		and downed_party.get_hero(2).get("id") == "warden",
		"Swapping Seamstress into slot 1 and Warden into slot 2 before Beat 1 must succeed."
	)
	_check(
		downed_party.apply_damage(1, 28) and downed_party.is_downed(1),
		"Downing Seamstress (28 remaining HP) at slot 1 before Beat 1 must succeed."
	)

	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 975310
	var rng_state_before := local_rng.state
	seed(975310)
	var expected_global_after_downed := randi()
	seed(975310)

	var heroes_before_downed := downed_party.get_heroes()
	var enemies_before_downed := downed_enemies.get_enemies()
	var intents_before_downed := downed_intents.get_intents()
	var downed_beat_1_res := phase.execute_phase(downed_party, downed_enemies, intents_before_downed)
	_check(
		downed_beat_1_res == {"ok": false, "events": []},
		"Attempting Beat 1 when Weak 1 targets already-downed Seamstress must reject the entire phase with {ok: false, events: []}."
	)
	_check(
		downed_party.get_heroes() == heroes_before_downed
		and downed_party.get_hero(1).get("id") == "seamstress"
		and downed_party.get_hero(1).get("hp") == 0
		and downed_party.get_hero(1).get("statuses", {}) == {}
		and downed_party.get_hero(2).get("id") == "warden"
		and downed_party.get_hero(2).get("hp") == 40
		and downed_party.get_hero(2).get("statuses", {}) == {},
		"Rejected Beat 1 phase must roll back slot 1's staged 4-damage attack on Warden and leave all heroes unmutated."
	)
	_check(
		downed_enemies.get_enemies() == enemies_before_downed,
		"Rejected Beat 1 phase must leave all enemies unmutated."
	)
	_check(
		downed_intents.get_intents() == intents_before_downed,
		"Rejected Beat 1 phase must not mutate or advance CombatEnemyIntents."
	)
	_check(
		local_rng.state == rng_state_before and randi() == expected_global_after_downed,
		"Rejected Beat 1 phase must not consume local or global RNG."
	)

	# Also verify on a fresh unswapped party that downing slot 1 Warden before Beat 1 rejects the entire phase
	# after slot 1 Button Guard stages 4 attack damage on living slot 2 Seamstress:
	var downed_warden_party := _build_catalog_party(hero_catalog)
	var downed_warden_enemies := _assemble_local_enemies(definitions)
	_check(downed_warden_party.apply_damage(1, 40) and downed_warden_party.is_downed(1), "Downing Warden at slot 1 before Beat 1 must succeed.")
	var heroes_before_warden_down := downed_warden_party.get_heroes()
	var enemies_before_warden_down := downed_warden_enemies.get_enemies()
	var downed_warden_res := phase.execute_phase(downed_warden_party, downed_warden_enemies, intents_before_downed)
	_check(
		downed_warden_res == {"ok": false, "events": []}
		and downed_warden_party.get_heroes() == heroes_before_warden_down
		and downed_warden_party.get_hero(2).get("hp") == 30
		and downed_warden_enemies.get_enemies() == enemies_before_warden_down,
		"Attempting Beat 1 with downed slot 1 Warden must reject the entire phase and roll back slot 1's staged 4-damage attack on Seamstress."
	)

	# Also verify on an unswapped party with downed slot 2 Seamstress that:
	# (a) a phase where slot 1 stages Block 3 and slot 2 debuffs downed slot 2 Seamstress rolls back all staged changes;
	# (b) unmodified Beat 1 (where slot 1 attacks downed slot 2 Seamstress and slots 2-3 target living Warden) skips slot 1's attack (applied=false) without retargeting.
	var downed_slot2_party := _build_catalog_party(hero_catalog)
	var downed_slot2_enemies := _assemble_local_enemies(definitions)
	_check(downed_slot2_party.apply_damage(2, 30) and downed_slot2_party.is_downed(2), "Downing Seamstress at slot 2 must succeed.")
	var heroes_before_slot2 := downed_slot2_party.get_heroes()
	var enemies_before_slot2 := downed_slot2_enemies.get_enemies()
	var slot2_debuff_rollback_intents: Array[Dictionary] = [
		{"type": "block", "amount": 3, "enemy_position": 1},
		{"type": "debuff", "amount": 1, "target_position": 2, "status": "weak", "enemy_position": 2},
		{"type": "attack", "amount": 3, "target_position": 1, "enemy_position": 3},
	]
	var slot2_debuff_rollback_res := phase.execute_phase(downed_slot2_party, downed_slot2_enemies, slot2_debuff_rollback_intents)
	_check(
		slot2_debuff_rollback_res == {"ok": false, "events": []}
		and downed_slot2_party.get_heroes() == heroes_before_slot2
		and downed_slot2_enemies.get_enemies() == enemies_before_slot2,
		"When slot 1 stages Block 3 and slot 2 fails debuffing downed slot 2 Seamstress, execute_phase must roll back all staged changes."
	)
	var slot2_attack_skip_res := phase.execute_phase(downed_slot2_party, downed_slot2_enemies, intents_before_downed)
	var expected_slot2_skip_events: Array[Dictionary] = [
		{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": false},
		{"type": "debuff", "enemy_position": 2, "target_position": 1, "status": "weak", "applied": true},
		{"type": "attack", "enemy_position": 3, "target_position": 1, "applied": true},
	]
	_check(
		slot2_attack_skip_res == {"ok": true, "events": expected_slot2_skip_events}
		and downed_slot2_party.get_hero(1).get("hp") == 37
		and downed_slot2_party.get_hero(1).get("statuses") == {"weak": 1}
		and downed_slot2_party.get_hero(2).get("hp") == 0
		and downed_slot2_party.get_hero(3).get("hp") == 26,
		"When slot 2 Seamstress is downed and slot 1 Warden is alive, Beat 1 skips slot 1's attack on slot 2 (applied=false) without retargeting while slots 2 and 3 resolve on Warden."
	)

	# 3. Malformed / fractional amount / unsupported status / duplicate source position rejected via production parser,
	# intent validator, and phase executor without changing the shipped JSON.
	var invalid_json_cases: Array[Dictionary] = [
		{
			"label": "malformed JSON syntax",
			"json": '[{"enemy_position": 1, "pattern": ['
		},
		{
			"label": "fractional block amount 3.5",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "block", "amount": 3.5}]}]'
		},
		{
			"label": "fractional attack amount 4.25",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 4.25, "target_position": 2}]}]'
		},
		{
			"label": "fractional buff amount 2.5",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "buff", "amount": 2.5}]}]'
		},
		{
			"label": "fractional debuff amount 1.5",
			"json": '[{"enemy_position": 2, "pattern": [{"type": "debuff", "amount": 1.5, "target_position": 1, "status": "weak"}]}]'
		},
		{
			"label": "fractional target_position 1.5",
			"json": '[{"enemy_position": 2, "pattern": [{"type": "debuff", "amount": 1, "target_position": 1.5, "status": "weak"}]}]'
		},
		{
			"label": "fractional enemy_position 2.5",
			"json": '[{"enemy_position": 2.5, "pattern": [{"type": "block", "amount": 2}]}]'
		},
		{
			"label": "unsafe integer > 2^53 - 1",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 9007199254740992, "target_position": 1}]}]'
		},
		{
			"label": "unsupported status vulnerable",
			"json": '[{"enemy_position": 2, "pattern": [{"type": "debuff", "amount": 1, "target_position": 1, "status": "vulnerable"}]}]'
		},
		{
			"label": "unsupported status poison",
			"json": '[{"enemy_position": 2, "pattern": [{"type": "debuff", "amount": 1, "target_position": 1, "status": "poison"}]}]'
		},
		{
			"label": "empty status string",
			"json": '[{"enemy_position": 2, "pattern": [{"type": "debuff", "amount": 1, "target_position": 1, "status": ""}]}]'
		},
		{
			"label": "non-string status",
			"json": '[{"enemy_position": 2, "pattern": [{"type": "debuff", "amount": 1, "target_position": 1, "status": 1}]}]'
		},
		{
			"label": "zero buff amount",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "buff", "amount": 0}]}]'
		},
		{
			"label": "zero debuff amount",
			"json": '[{"enemy_position": 2, "pattern": [{"type": "debuff", "amount": 0, "target_position": 1, "status": "weak"}]}]'
		},
		{
			"label": "negative block amount",
			"json": '[{"enemy_position": 3, "pattern": [{"type": "block", "amount": -1}]}]'
		},
		{
			"label": "duplicate enemy_position 2",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "block", "amount": 3}]}, {"enemy_position": 2, "pattern": [{"type": "block", "amount": 2}]}, {"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]}]'
		},
		{
			"label": "target_position 4 out of range",
			"json": '[{"enemy_position": 2, "pattern": [{"type": "attack", "amount": 3, "target_position": 4}]}]'
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
			"label": "unsupported status in CombatEnemyIntents",
			"defs": [{"enemy_position": 2, "pattern": [{"type": "debuff", "amount": 1, "target_position": 1, "status": "frail"}]}]
		},
		{
			"label": "zero buff amount in CombatEnemyIntents",
			"defs": [{"enemy_position": 1, "pattern": [{"type": "buff", "amount": 0}]}]
		},
		{
			"label": "duplicate source position in CombatEnemyIntents",
			"defs": [
				{"enemy_position": 1, "pattern": [{"type": "block", "amount": 3}]},
				{"enemy_position": 1, "pattern": [{"type": "buff", "amount": 2}]},
			]
		},
	]
	for entry in invalid_intent_defs:
		var bad_intents := CombatEnemyIntents.new(entry["defs"])
		_check(not bad_intents.is_valid(), "CombatEnemyIntents must reject %s." % entry["label"])
		_check(bad_intents.get_intents().is_empty(), "Invalid CombatEnemyIntents must return empty get_intents() for %s." % entry["label"])
		_check(not bad_intents.advance_turn(), "Invalid CombatEnemyIntents must reject advance_turn() for %s." % entry["label"])

	var invalid_phase_batches: Array[Dictionary] = [
		{
			"label": "unsupported status in phase after valid slot 1 block",
			"intents": [
				{"type": "block", "amount": 3, "enemy_position": 1},
				{"type": "debuff", "amount": 1, "target_position": 1, "status": "sunder", "enemy_position": 2},
			]
		},
		{
			"label": "zero buff amount in phase after valid slot 1 attack",
			"intents": [
				{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 1},
				{"type": "buff", "amount": 0, "enemy_position": 2},
			]
		},
		{
			"label": "duplicate enemy_position in phase",
			"intents": [
				{"type": "block", "amount": 3, "enemy_position": 1},
				{"type": "buff", "amount": 2, "enemy_position": 1},
			]
		},
	]
	for batch in invalid_phase_batches:
		var bad_phase := phase.execute_phase(downed_party, downed_enemies, batch["intents"])
		_check(bad_phase == {"ok": false, "events": []}, "CombatEnemyPhase must reject %s." % batch["label"])
		_check(
			downed_party.get_heroes() == heroes_before_downed
			and downed_enemies.get_enemies() == enemies_before_downed,
			"CombatEnemyPhase rejection for %s must leave party and enemies unmutated." % batch["label"]
		)

	# Confirm the original authored file remains valid after all negative probes.
	var rechecked_defs := RunFightEncounterSelection._parse_schedule_text(_read_text(SPOOLCORD_PATH))
	_check(
		rechecked_defs == _expected_definitions() and CombatEnemyIntents.new(rechecked_defs).is_valid(),
		"Original authored spoolcord_triad_relay.json must remain valid after all negative parser/validator probes."
	)


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


func _execute_seeded_map_and_opening_phase(seed_value: int, hero_catalog: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := RunMap.new()
	var generated := map.generate(rng)
	var fight_id := _choose_reachable_fight(map)
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
	var beat_0_announced := intents.get_intents()
	var beat_0_result := CombatEnemyPhase.new().execute_phase(party, enemies, beat_0_announced)
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
		"beat_0_announced": beat_0_announced,
		"beat_0_result": beat_0_result,
		"heroes_after_beat_0": party.get_heroes(),
		"enemies_after_beat_0": enemies.get_enemies(),
		"next_rng_draw": rng.randi(),
	}


func _verify_ac5_map_selection_replay_and_existing_schedules(hero_catalog: Array) -> void:
	# 1. Seeded RunMap selection with local one-entry Fight pool, cache detachment, and rejection checks.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7182934
	var map := RunMap.new()
	var selector := RunFightEncounterSelection.new()

	# Ungenerated map rejection without RNG or route drift.
	var ungen_snap := _snapshot_map_and_selector(map, rng, selector)
	_check(
		selector.select_current_battle(map, rng, _local_typed_pool()) == {"success": false}
		and _snapshot_map_and_selector(map, rng, selector) == ungen_snap,
		"Ungenerated RunMap must fail closed in select_current_battle without RNG or state drift."
	)

	_check(map.generate(rng), "Seeded RunMap.generate(rng) must succeed.")

	# Unchosen node rejection before choose_node().
	var unchosen_snap := _snapshot_map_and_selector(map, rng, selector)
	_check(
		selector.select_current_battle(map, rng, _local_typed_pool()) == {"success": false}
		and selector.select_current_fight(map, rng, _local_typed_pool()["Fight"]) == {"success": false}
		and _snapshot_map_and_selector(map, rng, selector) == unchosen_snap,
		"Unchosen Fight node must be rejected by select_current_battle and select_current_fight without RNG or route mutation."
	)

	# Discover and choose a legitimately reachable Fight node through the real map rules.
	var chosen_fight_id := _choose_reachable_fight(map)
	_check(not chosen_fight_id.is_empty(), "Seeded RunMap must expose a legitimately reachable Fight node.")
	_check(
		map.get_current_node_id() == chosen_fight_id
		and map.get_node(chosen_fight_id).get("type") == "Fight",
		"Current chosen node must be a legal Fight node."
	)

	# Invalid-path / wrong-kind-pool / null-RNG rejections on chosen Fight node before first valid selection.
	var pre_select_snap := _snapshot_map_and_selector(map, rng, selector)
	var invalid_pools: Array[Dictionary] = [
		{"label": "empty pools dictionary", "pool": {}},
		{"label": "missing Fight pool key", "pool": {"Elite": {ENCOUNTER_ID: SPOOLCORD_PATH}}},
		{"label": "empty Fight pool", "pool": {"Fight": {}}},
		{"label": "nonexistent encounter file", "pool": {"Fight": {ENCOUNTER_ID: "res://data/encounters/does_not_exist.json"}}},
		{"label": "wrong directory path", "pool": {"Fight": {ENCOUNTER_ID: ENEMY_CATALOG_PATH}}},
		{"label": "path traversal", "pool": {"Fight": {ENCOUNTER_ID: "res://data/encounters/../enemies/run_enemies.json"}}},
		{"label": "non-json extension", "pool": {"Fight": {ENCOUNTER_ID: "res://data/encounters/spoolcord_triad_relay.tres"}}},
		{"label": "empty encounter key", "pool": {"Fight": {" ": SPOOLCORD_PATH}}},
	]
	for bad_entry in invalid_pools:
		var rejected := selector.select_current_battle(map, rng, bad_entry["pool"])
		_check(
			rejected == {"success": false}
			and _snapshot_map_and_selector(map, rng, selector) == pre_select_snap,
			"Invalid selector call (%s) must fail closed without RNG, route, or cache mutation." % bad_entry["label"]
		)
	_check(
		selector.select_current_battle(map, null, _local_typed_pool()) == {"success": false}
		and _snapshot_map_and_selector(map, rng, selector) == pre_select_snap,
		"Null RNG must fail closed without route or cache mutation."
	)

	# Valid selection on the chosen Fight node.
	var expected_choice := {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": _expected_definitions(),
	}
	var first_choice := selector.select_current_battle(map, rng, _local_typed_pool())
	var rng_after_first := rng.state
	_check(
		first_choice == expected_choice,
		"select_current_battle with local one-entry Fight pool must select spoolcord_triad_relay and return canonical definitions."
	)

	# Assemble the local 3-enemy roster directly from the selected choice.
	var selected_roster := RunTypedBattleRoster.new().assemble(
		first_choice,
		_local_roster_map(),
		[ENEMY_CATALOG_PATH]
	)
	_check(
		selected_roster.get("ok") == true
		and selected_roster.get("encounter_id") == ENCOUNTER_ID
		and selected_roster.get("enemies") is CombatEnemies
		and selected_roster["enemies"].get_enemies().size() == 3,
		"RunTypedBattleRoster.assemble must build the 3-enemy roster from select_current_battle output."
	)

	# Repeated same-node selection caches and deep-detaches without another RNG draw
	# (even when given a multi-entry pool that would advance RNG if uncached).
	var two_entry_pool := {
		"Fight": {
			ENCOUNTER_ID: SPOOLCORD_PATH,
			"starter_attacks": STARTER_ATTACKS_PATH,
		}
	}
	var second_choice := selector.select_current_battle(map, rng, two_entry_pool)
	_check(
		second_choice == expected_choice and rng.state == rng_after_first,
		"Repeated select_current_battle on same node must return cached choice and consume zero RNG."
	)
	var legacy_choice := selector.select_current_fight(map, rng, two_entry_pool["Fight"])
	_check(
		legacy_choice == {
			"success": true,
			"encounter_id": ENCOUNTER_ID,
			"definitions": _expected_definitions(),
		}
		and rng.state == rng_after_first,
		"select_current_fight on same cached Fight node must return cached choice (without node_type) and consume zero RNG."
	)

	# Mutate returned dictionaries/arrays and prove cached state is deep-detached.
	first_choice["encounter_id"] = "mutated_id"
	first_choice["definitions"][0]["pattern"][0]["amount"] = 999
	first_choice["definitions"].clear()
	second_choice["definitions"][1]["pattern"][1]["status"] = "invented"
	_check(
		selector.select_current_battle(map, rng, _local_typed_pool()) == expected_choice
		and rng.state == rng_after_first,
		"Mutating returned selection dictionaries must not corrupt selector cache or consume RNG."
	)

	# Traverse further along the map to verify wrong-type node rejection without RNG or route drift.
	var saw_non_fight := false
	for _floor_step in range(map.get_current_floor() + 1, RunMap.FLOOR_COUNT + 1):
		var legal := map.get_legal_choices()
		if legal.is_empty():
			break
		var chosen_next: String = legal[0]
		for candidate in legal:
			if map.get_node(candidate).get("type") != "Fight":
				chosen_next = candidate
				break
		_check(map.choose_node(chosen_next), "Choosing legal next node %s must succeed." % chosen_next)
		var next_type: String = map.get_node(chosen_next).get("type", "")
		if next_type != "Fight":
			saw_non_fight = true
			var wrong_kind_snap := _snapshot_map_and_selector(map, rng, selector)
			_check(
				selector.select_current_fight(map, rng, _local_typed_pool()["Fight"]) == {"success": false}
				and selector.select_current_battle(map, rng, _local_typed_pool()) == {"success": false}
				and _snapshot_map_and_selector(map, rng, selector) == wrong_kind_snap,
				"Selecting Fight on non-Fight node (%s) must reject without RNG, route, or cache drift." % next_type
			)
	_check(saw_non_fight, "Route traversal must exercise at least one non-Fight node (including terminal Boss).")

	# 2. Fresh same-seed reproduction of map generation, selection, typed assembly, and opening phase.
	var run_a := _execute_seeded_map_and_opening_phase(606060, hero_catalog)
	var run_b := _execute_seeded_map_and_opening_phase(606060, hero_catalog)
	_check(run_a == run_b, "Fresh same-seed fixture must reproduce identical map, selection, RNG states, and opening enemy phase.")
	_check(
		run_a["generated"] == true
		and not String(run_a["fight_id"]).is_empty()
		and run_a["assembled_ok"] == true
		and run_a["starting_block_ok"] == true
		and run_a["rng_after_select"] == run_a["rng_after_cached"]
		and run_a["choice"] == expected_choice,
		"Same-seed reproduction must succeed at every stage and keep RNG unchanged on cached re-read."
	)

	# 3. Independently reparse named prior starter_attacks and buttonhole_holdout schedules as positive controls.
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

	var holdout_defs := RunFightEncounterSelection._parse_schedule_text(_read_text(BUTTONHOLE_HOLDOUT_PATH))
	_check(holdout_defs.size() == 2, "buttonhole_holdout.json must still parse into 2 source definitions.")
	var holdout_s1 := _find_unique_by_key(holdout_defs, "enemy_position", 1, BUTTONHOLE_HOLDOUT_PATH)
	var holdout_s2 := _find_unique_by_key(holdout_defs, "enemy_position", 2, BUTTONHOLE_HOLDOUT_PATH)
	var expected_holdout_s1: Array = [
		{"type": "attack", "amount": 1, "target_position": 1},
		{"type": "block", "amount": 1},
		{"type": "block", "amount": 1},
		{"type": "attack", "amount": 1, "target_position": 3},
	]
	var expected_holdout_s2: Array = [
		{"type": "attack", "amount": 1, "target_position": 2},
		{"type": "attack", "amount": 1, "target_position": 2},
		{"type": "attack", "amount": 1, "target_position": 1},
		{"type": "attack", "amount": 1, "target_position": 3},
	]
	_check(holdout_s1.get("pattern") == expected_holdout_s1, "buttonhole_holdout.json source 1 pattern must remain unchanged.")
	_check(holdout_s2.get("pattern") == expected_holdout_s2, "buttonhole_holdout.json source 2 pattern must remain unchanged.")
	var holdout_intents := CombatEnemyIntents.new(holdout_defs)
	_check(holdout_intents.is_valid(), "buttonhole_holdout.json must remain valid in CombatEnemyIntents.")
	var expected_holdout_beats: Array = [
		[
			{"type": "attack", "amount": 1, "target_position": 1, "enemy_position": 1},
			{"type": "attack", "amount": 1, "target_position": 2, "enemy_position": 2},
		],
		[
			{"type": "block", "amount": 1, "enemy_position": 1},
			{"type": "attack", "amount": 1, "target_position": 2, "enemy_position": 2},
		],
		[
			{"type": "block", "amount": 1, "enemy_position": 1},
			{"type": "attack", "amount": 1, "target_position": 1, "enemy_position": 2},
		],
		[
			{"type": "attack", "amount": 1, "target_position": 3, "enemy_position": 1},
			{"type": "attack", "amount": 1, "target_position": 3, "enemy_position": 2},
		],
		[
			{"type": "attack", "amount": 1, "target_position": 1, "enemy_position": 1},
			{"type": "attack", "amount": 1, "target_position": 2, "enemy_position": 2},
		],
	]
	for expected_beat in expected_holdout_beats:
		_check(holdout_intents.get_intents() == expected_beat, "buttonhole_holdout beat announcement must remain unchanged.")
		_check(holdout_intents.advance_turn(), "buttonhole_holdout advance_turn must succeed.")
