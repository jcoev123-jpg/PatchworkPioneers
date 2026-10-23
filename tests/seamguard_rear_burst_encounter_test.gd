extends SceneTree
const WEIGHTED = preload("res://tests/weighted_roster_assert.gd")

const HERO_CATALOG_PATH := "res://data/heroes/starter_party.json"
const ENEMY_CATALOG_PATH := "res://data/enemies/run_enemies.json"
const SEAMGUARD_PATH := "res://data/encounters/seamguard_rear_burst.json"
const STARTER_ATTACKS_PATH := "res://data/encounters/starter_attacks.json"
const BUTTONHOLE_HOLDOUT_PATH := "res://data/encounters/buttonhole_holdout.json"
const ENCOUNTER_ID := "seamguard_rear_burst"

var failures: Array[String] = []


func _init() -> void:
	_verify_failure_harness()
	_run_all_checks()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("seamguard_rear_burst_encounter_test passed")
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
	return {ENCOUNTER_ID: ["seam_ripper", "button_guard"]}


func _local_typed_pool() -> Dictionary:
	return {"Fight": {ENCOUNTER_ID: SEAMGUARD_PATH}}


func _expected_pattern_1() -> Array:
	return [
		{"type": "attack", "amount": 4, "target_position": 1},
		{"type": "block", "amount": 2},
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed"},
	]


func _expected_pattern_2() -> Array:
	return [
		{"type": "block", "amount": 3},
		{"type": "attack", "amount": 3, "target_position": 2},
		{"type": "attack", "amount": 4, "target_position": 3},
	]


func _expected_definitions() -> Array:
	return [
		{"enemy_position": 1, "pattern": _expected_pattern_1()},
		{"enemy_position": 2, "pattern": _expected_pattern_2()},
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
	_check(assembled.get("ok", false), "RunTypedBattleRoster.assemble must succeed for local seamguard_rear_burst fixture.")
	if not assembled.get("ok", false):
		return CombatEnemies.new([])
	return assembled["enemies"]


func _run_all_checks() -> void:
	var raw_hero_catalog := _load_json_array(HERO_CATALOG_PATH)
	var raw_enemy_catalog := _load_json_array(ENEMY_CATALOG_PATH)
	var hero_catalog_snapshot := raw_hero_catalog.duplicate(true)
	var enemy_catalog_snapshot := raw_enemy_catalog.duplicate(true)

	_verify_ac1_schedule_catalogs_and_typed_roster(raw_hero_catalog, raw_enemy_catalog)
	_verify_ac2_and_ac3_three_beat_execution_and_wraparound(raw_hero_catalog)
	_verify_ac4_slain_downed_and_parser_rejections(raw_hero_catalog)
	_verify_ac5_map_selection_replay_and_existing_schedules(raw_hero_catalog)

	_check(raw_hero_catalog == hero_catalog_snapshot, "Hero catalog snapshot must remain unmutated after all checks.")
	_check(raw_enemy_catalog == enemy_catalog_snapshot, "Enemy catalog snapshot must remain unmutated after all checks.")


func _verify_ac1_schedule_catalogs_and_typed_roster(hero_catalog: Array, enemy_catalog: Array) -> void:
	# 1. Verify required starter heroes and normal enemies by stable ID without total catalog size checks.
	var warden := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "warden", HERO_CATALOG_PATH), "warden")
	var seamstress := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "seamstress", HERO_CATALOG_PATH), "seamstress")
	var tinker := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "tinker", HERO_CATALOG_PATH), "tinker")
	_check(
		warden.get("name") == "Warden"
		and warden.get("max_hp") == 40
		and warden.get("art_path") == "res://assets/paper/heroes/warden.png",
		"Catalog Warden must retain name Warden, 40 max_hp, andwarden art_path."
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

	var ripper := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "seam_ripper", ENEMY_CATALOG_PATH), "seam_ripper")
	var guard := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "button_guard", ENEMY_CATALOG_PATH), "button_guard")
	_check(
		ripper.get("name") == "Seam Ripper"
		and ripper.get("max_hp") == 18
		and ripper.get("art_path") == "res://assets/paper/enemies/seam_ripper.png",
		"Catalog Seam Ripper must retain name Seam Ripper, 18 max_hp, and seam_ripper art_path."
	)
	_check(
		guard.get("name") == "Button Guard"
		and guard.get("max_hp") == 16
		and guard.get("art_path") == "res://assets/paper/enemies/button_guard.png",
		"Catalog Button Guard must retain name Button Guard, 16 max_hp, and button_guard art_path."
	)

	# 2. Verify raw JSON integral numeric fields before coercion, then parse via RunFightEncounterSelection.
	var raw_text := _read_text(SEAMGUARD_PATH)
	var raw_json := _load_json_array(SEAMGUARD_PATH)
	_check(raw_json.size() == 2, "seamguard_rear_burst.json must contain exactly 2 enemy source definitions.")
	for raw_def in raw_json:
		_check(raw_def is Dictionary, "Each raw definition in seamguard_rear_burst.json must be a Dictionary.")
		if raw_def is Dictionary:
			_check(_is_integral_number(raw_def.get("enemy_position")), "Raw enemy_position must be integral before coercion.")
			var raw_pattern: Variant = raw_def.get("pattern", [])
			_check(raw_pattern is Array and raw_pattern.size() == 3, "Each raw pattern in seamguard_rear_burst.json must be a 3-beat Array.")
			if raw_pattern is Array:
				for raw_action in raw_pattern:
					_check(raw_action is Dictionary, "Each raw action must be a Dictionary.")
					if raw_action is Dictionary:
						_check(_is_integral_number(raw_action.get("amount")), "Raw action amount must be integral.")
						if raw_action.has("target_position"):
							_check(_is_integral_number(raw_action.get("target_position")), "Raw target_position must be integral.")

	var definitions := RunFightEncounterSelection._parse_schedule_text(raw_text)
	_check(definitions.size() == 2, "RunFightEncounterSelection._parse_schedule_text must return 2 definitions for seamguard_rear_burst.")
	var source_1 := _find_unique_by_key(definitions, "enemy_position", 1, SEAMGUARD_PATH)
	var source_2 := _find_unique_by_key(definitions, "enemy_position", 2, SEAMGUARD_PATH)
	_check(source_1.get("pattern") == _expected_pattern_1(), "Source 1 pattern must match exact 3-beat Seam Ripper schedule.")
	_check(source_2.get("pattern") == _expected_pattern_2(), "Source 2 pattern must match exact 3-beat Button Guard schedule.")
	_check(definitions == _expected_definitions(), "Normalized seamguard_rear_burst definitions must match canonical schedule.")

	# 3. Validate through CombatEnemyIntents across full 3-beat cycle + wraparound and verify defensive copy detachment.
	var intents := CombatEnemyIntents.new(definitions)
	_check(intents.is_valid(), "CombatEnemyIntents must validate seamguard_rear_burst definitions.")
	var expected_beat_1: Array[Dictionary] = [
		{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 1},
		{"type": "block", "amount": 3, "enemy_position": 2},
	]
	var expected_beat_2: Array[Dictionary] = [
		{"type": "block", "amount": 2, "enemy_position": 1},
		{"type": "attack", "amount": 3, "target_position": 2, "enemy_position": 2},
	]
	var expected_beat_3: Array[Dictionary] = [
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed", "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 3, "enemy_position": 2},
	]

	var beat_1_a := intents.get_intents()
	var beat_1_b := intents.get_intents()
	_check(beat_1_a == expected_beat_1, "Beat 1 intents must match expected front attack and guard block.")
	_check(beat_1_b == expected_beat_1, "Repeated get_intents() on Beat 1 must not advance implicitly.")
	if not beat_1_a.is_empty():
		beat_1_a[0]["amount"] = 999
		beat_1_a.clear()
	_check(beat_1_b == expected_beat_1, "Mutating one get_intents() result must not affect another fetched result.")
	_check(intents.get_intents() == expected_beat_1, "Mutating returned intents must not mutate CombatEnemyIntents state.")

	_check(intents.advance_turn(), "advance_turn() from Beat 1 to Beat 2 must succeed.")
	_check(intents.get_intents() == expected_beat_2, "Beat 2 intents must match expected ripper block and middle attack.")
	_check(intents.get_intents() == expected_beat_2, "Repeated get_intents() on Beat 2 must not advance implicitly.")

	_check(intents.advance_turn(), "advance_turn() from Beat 2 to Beat 3 must succeed.")
	_check(intents.get_intents() == expected_beat_3, "Beat 3 intents must match expected rear exposed debuff and rear attack.")
	_check(intents.get_intents() == expected_beat_3, "Repeated get_intents() on Beat 3 must not advance implicitly.")

	_check(intents.advance_turn(), "advance_turn() from Beat 3 to Beat 4 wraparound must succeed.")
	_check(intents.get_intents() == expected_beat_1, "Beat 4 wraparound must return exact Beat 1 intents.")
	_check(intents.advance_turn() and intents.get_intents() == expected_beat_2, "Beat 5 must match Beat 2 intents.")
	_check(intents.advance_turn() and intents.get_intents() == expected_beat_3, "Beat 6 must match Beat 3 intents.")

	var reversed_intents := CombatEnemyIntents.new([source_2.duplicate(true), source_1.duplicate(true)])
	_check(reversed_intents.is_valid(), "CombatEnemyIntents must accept reversed source order.")
	_check(reversed_intents.get_intents() == expected_beat_1, "CombatEnemyIntents must sort announced actions by ascending enemy_position.")

	# 4. Assemble slot 1 Seam Ripper (18 HP) and slot 2 Button Guard (16 HP) through RunTypedBattleRoster.
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
		"RunTypedBattleRoster.assemble must return ok=true, Fight node_type, seamguard_rear_burst ID, and exact definitions."
	)
	var assembled_enemies: Variant = assembled.get("enemies")
	_check(assembled_enemies is CombatEnemies and assembled_enemies.is_valid(), "Assembled enemies must be a valid CombatEnemies instance.")
	if assembled_enemies is CombatEnemies:
		var enemy_list: Array[Dictionary] = assembled_enemies.get_enemies()
		_check(enemy_list.size() == 2, "Assembled CombatEnemies must contain exactly 2 slots.")
		_check(
			WEIGHTED.project(assembled_enemies.get_enemy(1)) == {
				"id": "seam_ripper",
				"name": "Seam Ripper",
				"max_hp": 18,
				"art_path": "res://assets/paper/enemies/seam_ripper.png",
				"position": 1,
				"hp": 18,
				"block": 0,
			},
			"Slot 1 assembled enemy must be Seam Ripper with 18/18 HP, 0 Block, and exact art_path."
		)
		_check(
			WEIGHTED.project(assembled_enemies.get_enemy(2)) == {
				"id": "button_guard",
				"name": "Button Guard",
				"max_hp": 16,
				"art_path": "res://assets/paper/enemies/button_guard.png",
				"position": 2,
				"hp": 16,
				"block": 0,
			},
			"Slot 2 assembled enemy must be Button Guard with 16/16 HP, 0 Block, and exact art_path."
		)

	# Verify detachment of assembled definitions and negative roster assembly rejections.
	if assembled.has("definitions") and assembled["definitions"] is Array and not assembled["definitions"].is_empty():
		assembled["definitions"][0]["enemy_position"] = 99
	_check(typed_choice == choice_before_assemble, "Mutating assembled definitions must not affect caller typed_choice.")
	_check(
		roster_bridge.assemble(typed_choice, {ENCOUNTER_ID: ["seam_ripper"]}, [ENEMY_CATALOG_PATH]) == {"ok": false},
		"RunTypedBattleRoster must reject mismatched 1-enemy roster for 2-source seamguard_rear_burst."
	)
	_check(
		roster_bridge.assemble(typed_choice, {ENCOUNTER_ID: ["seam_ripper", "seam_ripper"]}, [ENEMY_CATALOG_PATH]) == {"ok": false},
		"RunTypedBattleRoster must reject duplicate enemy IDs."
	)
	_check(
		roster_bridge.assemble(typed_choice, {ENCOUNTER_ID: ["seam_ripper", "unknown_enemy"]}, [ENEMY_CATALOG_PATH]) == {"ok": false},
		"RunTypedBattleRoster must reject unknown enemy ID."
	)


func _verify_ac2_and_ac3_three_beat_execution_and_wraparound(hero_catalog: Array) -> void:
	# Prove global RNG probe detects an extra draw, then verify zero global RNG consumption across all 4 beats.
	var rng_seed := 246813579
	seed(rng_seed)
	var expected_global_draw := randi()
	seed(rng_seed)
	var _injected_draw := randi()
	_check(randi() != expected_global_draw, "Global RNG probe must detect an injected randi() draw.")

	seed(rng_seed)
	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(SEAMGUARD_PATH))
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

	# Beat 1 (AC2): Source 1 Seam Ripper attacks slot 1 Warden for 4 (Block 6 -> 2, HP stays 40),
	# then Source 2 Button Guard gains 3 Block.
	var beat_1_announced := intents.get_intents()
	var expected_beat_1_intents: Array[Dictionary] = [
		{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 1},
		{"type": "block", "amount": 3, "enemy_position": 2},
	]
	_check(beat_1_announced == expected_beat_1_intents, "Beat 1 announced intents must match source 1 attack 4 on slot 1 and source 2 block 3.")
	var beat_1_res := phase.execute_phase(party, enemies, beat_1_announced)
	var expected_beat_1_events: Array[Dictionary] = [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
		{"type": "block", "enemy_position": 2, "applied": true},
	]
	_check(
		beat_1_res == {"ok": true, "events": expected_beat_1_events},
		"Beat 1 execute_phase must resolve source 1 attack before source 2 block in source order."
	)
	_check(
		party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("position") == 1
		and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 2
		and party.get_hero(1).get("statuses", {}) == {},
		"After Beat 1, Warden must have 40 HP, 2 Block, and no statuses."
	)
	_check(
		party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(2).get("position") == 2
		and party.get_hero(2).get("hp") == 30
		and party.get_hero(2).get("block") == 0
		and party.get_hero(2).get("statuses", {}) == {},
		"After Beat 1, Seamstress must remain unmutated at 30 HP and 0 Block."
	)
	_check(
		party.get_hero(3).get("id") == "tinker"
		and party.get_hero(3).get("position") == 3
		and party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("block") == 0
		and party.get_hero(3).get("statuses", {}) == {},
		"After Beat 1, Tinker must remain unmutated at 26 HP and 0 Block."
	)
	_check(
		enemies.get_enemy(1).get("id") == "seam_ripper"
		and enemies.get_enemy(1).get("position") == 1
		and enemies.get_enemy(1).get("hp") == 18
		and enemies.get_enemy(1).get("block") == 0
		and enemies.get_enemy(2).get("id") == "button_guard"
		and enemies.get_enemy(2).get("position") == 2
		and enemies.get_enemy(2).get("hp") == 16
		and enemies.get_enemy(2).get("block") == 3,
		"After Beat 1, Seam Ripper has 18 HP / 0 Block and Button Guard has 16 HP / 3 Block."
	)

	# Player-turn boundary before Beat 2 (AC3): reset hero Block, advance intents.
	_check(party.start_player_turn(), "party.start_player_turn() before Beat 2 must succeed.")
	_check(
		party.get_hero(1).get("block") == 0
		and party.get_hero(2).get("block") == 0
		and party.get_hero(3).get("block") == 0,
		"party.start_player_turn() must reset Warden's remaining 2 Block to 0."
	)
	_check(intents.advance_turn(), "Advancing intents from Beat 1 to Beat 2 must succeed.")

	# Beat 2 (AC3): Source 1 Seam Ripper gains 2 Block; Source 2 Button Guard attacks slot 2 Seamstress for 3 (HP 30 -> 27).
	var beat_2_announced := intents.get_intents()
	var expected_beat_2_intents: Array[Dictionary] = [
		{"type": "block", "amount": 2, "enemy_position": 1},
		{"type": "attack", "amount": 3, "target_position": 2, "enemy_position": 2},
	]
	_check(beat_2_announced == expected_beat_2_intents, "Beat 2 announced intents must match source 1 block 2 and source 2 attack 3 on slot 2.")
	var beat_2_res := phase.execute_phase(party, enemies, beat_2_announced)
	var expected_beat_2_events: Array[Dictionary] = [
		{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true},
	]
	_check(
		beat_2_res == {"ok": true, "events": expected_beat_2_events},
		"Beat 2 execute_phase must resolve source 1 block 2 and source 2 attack 3 on Seamstress."
	)
	_check(
		party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 0 and party.get_hero(1).get("statuses", {}) == {}
		and party.get_hero(2).get("hp") == 27 and party.get_hero(2).get("block") == 0 and party.get_hero(2).get("statuses", {}) == {}
		and party.get_hero(3).get("hp") == 26 and party.get_hero(3).get("block") == 0 and party.get_hero(3).get("statuses", {}) == {},
		"After Beat 2, Seamstress HP must be 27 while Warden (40) and Tinker (26) remain unharmed."
	)
	_check(
		enemies.get_enemy(1).get("hp") == 18 and enemies.get_enemy(1).get("block") == 2
		and enemies.get_enemy(2).get("hp") == 16 and enemies.get_enemy(2).get("block") == 3,
		"After Beat 2, Seam Ripper has 2 Block and Button Guard retains 3 Block with 18/16 HP."
	)

	# Player-turn boundary before Beat 3 (AC3): reset hero Block, advance intents.
	_check(party.start_player_turn(), "party.start_player_turn() before Beat 3 must succeed.")
	_check(intents.advance_turn(), "Advancing intents from Beat 2 to Beat 3 must succeed.")

	# Beat 3 (AC3): Source 1 Seam Ripper applies Exposed 1 to living Tinker (slot 3) before Source 2 Button Guard
	# attacks slot 3 for base 4 -> floor(4 * 1.5) = 6 -> Tinker HP 26 -> 20 with exposed=1 committed.
	var beat_3_announced := intents.get_intents()
	var expected_beat_3_intents: Array[Dictionary] = [
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed", "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 3, "enemy_position": 2},
	]
	_check(beat_3_announced == expected_beat_3_intents, "Beat 3 announced intents must match source 1 exposed debuff and source 2 rear attack.")
	var beat_3_res := phase.execute_phase(party, enemies, beat_3_announced)
	var expected_beat_3_events: Array[Dictionary] = [
		{"type": "debuff", "enemy_position": 1, "target_position": 3, "status": "exposed", "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true},
	]
	_check(
		beat_3_res == {"ok": true, "events": expected_beat_3_events},
		"Beat 3 execute_phase must apply source 1 exposed debuff before source 2 rear attack."
	)
	_check(
		party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("position") == 1
		and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 0
		and party.get_hero(1).get("statuses", {}) == {},
		"After Beat 3, Warden must remain at slot 1 with 40 HP, 0 Block, and no statuses."
	)
	_check(
		party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(2).get("position") == 2
		and party.get_hero(2).get("hp") == 27
		and party.get_hero(2).get("block") == 0
		and party.get_hero(2).get("statuses", {}) == {},
		"After Beat 3, Seamstress must remain at slot 2 with 27 HP, 0 Block, and no statuses."
	)
	_check(
		party.get_hero(3).get("id") == "tinker"
		and party.get_hero(3).get("position") == 3
		and party.get_hero(3).get("hp") == 20
		and party.get_hero(3).get("block") == 0
		and party.get_hero(3).get("statuses") == {"exposed": 1},
		"After Beat 3, Tinker must be at slot 3 with 20 HP (base 4 -> 6 under Exposed), 0 Block, and statuses={exposed: 1}."
	)
	_check(
		enemies.get_enemy(1).get("id") == "seam_ripper"
		and enemies.get_enemy(1).get("position") == 1
		and enemies.get_enemy(1).get("hp") == 18
		and enemies.get_enemy(1).get("block") == 2
		and enemies.get_enemy(2).get("id") == "button_guard"
		and enemies.get_enemy(2).get("position") == 2
		and enemies.get_enemy(2).get("hp") == 16
		and enemies.get_enemy(2).get("block") == 3,
		"After Beat 3, enemy HP remain 18/16 and earned enemy Block remains 2/3."
	)

	# Verify owner-turn status boundary behavior: CombatStatusTurnBatch.tick_side("heroes", ...) expires exposed=1
	# on its detached result, while CombatParty.start_player_turn() only resets Block and preserves statuses on party.
	var detached_tick := CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())
	_check(detached_tick.get("ok", false), "CombatStatusTurnBatch.tick_side('heroes', ...) must succeed after Beat 3.")
	if detached_tick.get("ok", false):
		var ticked_heroes: Array = detached_tick.get("actors", [])
		_check(
			ticked_heroes.size() == 3
			and ticked_heroes[2].get("id") == "tinker"
			and ticked_heroes[2].get("hp") == 20
			and ticked_heroes[2].get("statuses", {}) == {},
			"Owner-turn status tick must expire Tinker's Exposed 1 to empty statuses on the detached tick result."
		)
	_check(
		party.get_hero(3).get("statuses") == {"exposed": 1},
		"Detached CombatStatusTurnBatch.tick_side must not mutate CombatParty in place."
	)

	# Fourth-beat wraparound (AC3): advancing intents returns exact original Beat 1 intents without extra RNG.
	_check(party.start_player_turn(), "party.start_player_turn() before Beat 4 wraparound must succeed.")
	_check(
		party.get_hero(3).get("hp") == 20 and party.get_hero(3).get("statuses") == {"exposed": 1},
		"party.start_player_turn() resets Block only and leaves Tinker HP 20 and committed statuses intact."
	)
	_check(intents.advance_turn(), "Advancing intents from Beat 3 to Beat 4 wraparound must succeed.")
	_check(intents.get_intents() == expected_beat_1_intents, "Fourth beat must wrap around to exact Beat 1 intents.")
	_check(randi() == expected_global_draw, "All 3 beats, player-turn resets, status tick check, and Beat 4 wraparound must consume zero global RNG.")


func _verify_ac4_slain_downed_and_parser_rejections(hero_catalog: Array) -> void:
	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(SEAMGUARD_PATH))

	# 1. Separate fixture: Slay source 1 (Seam Ripper, 18 HP) before Beat 3 -> debuff skipped (applied=false),
	# surviving source 2 deals base 4 to unmarked Tinker (26 -> 22), no other unexpected mutation.
	var slain_s1_party := _build_catalog_party(hero_catalog)
	var slain_s1_enemies := _assemble_local_enemies(definitions)
	_check(CombatStartingBlock.new(slain_s1_party).apply(), "Opening Block must apply on slain-source-1 fixture.")
	_check(slain_s1_enemies.apply_damage(1, 18), "Slaying Seam Ripper (18 HP) at slot 1 must succeed.")
	_check(
		slain_s1_enemies.is_slain(1) and not slain_s1_enemies.is_slain(2) and not slain_s1_enemies.is_defeated(),
		"Only slot 1 Seam Ripper must be slain; roster is not yet defeated."
	)
	var slain_s1_intents := CombatEnemyIntents.new(definitions)
	_check(slain_s1_intents.advance_turn() and slain_s1_intents.advance_turn(), "Advancing to Beat 3 on slain-source-1 fixture must succeed.")
	var beat_3_intents := slain_s1_intents.get_intents()
	var slain_s1_res := CombatEnemyPhase.new().execute_phase(slain_s1_party, slain_s1_enemies, beat_3_intents)
	var expected_slain_s1_events: Array[Dictionary] = [
		{"type": "debuff", "enemy_position": 1, "target_position": 3, "status": "exposed", "applied": false},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true},
	]
	_check(
		slain_s1_res == {"ok": true, "events": expected_slain_s1_events},
		"When Seam Ripper is slain before Beat 3, its exposed debuff must be skipped (applied=false) and Button Guard's attack applied."
	)
	_check(
		slain_s1_party.get_hero(1).get("hp") == 40
		and slain_s1_party.get_hero(1).get("block") == 6
		and slain_s1_party.get_hero(1).get("statuses", {}) == {}
		and slain_s1_party.get_hero(2).get("hp") == 30
		and slain_s1_party.get_hero(2).get("block") == 0
		and slain_s1_party.get_hero(2).get("statuses", {}) == {},
		"Warden and Seamstress must remain completely unchanged in slain-source-1 Beat 3 fixture."
	)
	_check(
		slain_s1_party.get_hero(3).get("id") == "tinker"
		and slain_s1_party.get_hero(3).get("position") == 3
		and slain_s1_party.get_hero(3).get("hp") == 22
		and slain_s1_party.get_hero(3).get("block") == 0
		and slain_s1_party.get_hero(3).get("statuses", {}) == {},
		"Unmarked Tinker must take only base 4 damage (26 -> 22 HP) and remain without Exposed when source 1 is slain."
	)
	_check(
		slain_s1_enemies.get_enemy(1).get("id") == "seam_ripper"
		and slain_s1_enemies.get_enemy(1).get("position") == 1
		and slain_s1_enemies.get_enemy(1).get("hp") == 0
		and slain_s1_enemies.get_enemy(1).get("block") == 0
		and slain_s1_enemies.get_enemy(2).get("id") == "button_guard"
		and slain_s1_enemies.get_enemy(2).get("position") == 2
		and slain_s1_enemies.get_enemy(2).get("hp") == 16
		and slain_s1_enemies.get_enemy(2).get("block") == 0,
		"Slain Seam Ripper and living Button Guard must retain their slots, HP, and Block in slain-source-1 fixture."
	)

	# Also verify slaying source 2 after source 1 is slain completes victory, and Beat 3 with source 2 slain skips attack.
	var slain_s2_party := _build_catalog_party(hero_catalog)
	var slain_s2_enemies := _assemble_local_enemies(definitions)
	_check(slain_s2_enemies.apply_damage(2, 16), "Slaying Button Guard (16 HP) at slot 2 must succeed.")
	_check(not slain_s2_enemies.is_slain(1) and slain_s2_enemies.is_slain(2) and not slain_s2_enemies.is_defeated(), "Only slot 2 is slain.")
	var slain_s2_res := CombatEnemyPhase.new().execute_phase(slain_s2_party, slain_s2_enemies, beat_3_intents)
	var expected_slain_s2_events: Array[Dictionary] = [
		{"type": "debuff", "enemy_position": 1, "target_position": 3, "status": "exposed", "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": false},
	]
	_check(
		slain_s2_res == {"ok": true, "events": expected_slain_s2_events}
		and slain_s2_party.get_hero(3).get("hp") == 26
		and slain_s2_party.get_hero(3).get("statuses") == {"exposed": 1},
		"When only Button Guard is slain at Beat 3, Seam Ripper marks Tinker (exposed=1) and Guard's rear attack is skipped (HP stays 26)."
	)
	_check(slain_s2_enemies.apply_damage(1, 18) and slain_s2_enemies.is_defeated(), "Victory begins only after the final living enemy is slain.")

	# 2. Separate fixture: Down Tinker before an otherwise valid Beat 3 phase -> atomic rejection with zero state change.
	var downed_tinker_party := _build_catalog_party(hero_catalog)
	var downed_tinker_enemies := _assemble_local_enemies(definitions)
	_check(CombatStartingBlock.new(downed_tinker_party).apply(), "Opening Block must apply on downed-Tinker fixture.")
	_check(downed_tinker_enemies.gain_block(1, 2) and downed_tinker_enemies.gain_block(2, 3), "Pre-Beat-3 enemy Block setup must succeed.")
	_check(downed_tinker_party.apply_damage(2, 3), "Pre-Beat-3 Seamstress damage setup must succeed.")
	_check(downed_tinker_party.apply_damage(3, 26) and downed_tinker_party.is_downed(3), "Downing Tinker (26 damage) before Beat 3 must succeed.")
	var heroes_before_downed := downed_tinker_party.get_heroes()
	var enemies_before_downed := downed_tinker_enemies.get_enemies()
	var intents_before_downed := slain_s1_intents.get_intents()
	var downed_res := CombatEnemyPhase.new().execute_phase(downed_tinker_party, downed_tinker_enemies, beat_3_intents)
	_check(
		downed_res == {"ok": false, "events": []},
		"Beat 3 phase when live source 1 announces Exposed on downed Tinker must fail closed with empty events."
	)
	_check(
		downed_tinker_party.get_heroes() == heroes_before_downed,
		"Failed Beat 3 phase on downed Tinker must leave all hero HP, Block, and statuses unchanged with no leaked Exposed."
	)
	_check(
		downed_tinker_enemies.get_enemies() == enemies_before_downed,
		"Failed Beat 3 phase on downed Tinker must leave all enemy HP, Block, and statuses unchanged."
	)
	_check(
		slain_s1_intents.get_intents() == intents_before_downed,
		"Failed Beat 3 phase must not mutate or advance CombatEnemyIntents."
	)

	# Also prove atomic rollback when source 1 stages a real state change (attacking living Warden or gaining Block)
	# and later source 2 fails by targeting downed Tinker with a debuff.
	var rollback_intents: Array[Dictionary] = [
		{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 1},
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed", "enemy_position": 2},
	]
	var rollback_res := CombatEnemyPhase.new().execute_phase(downed_tinker_party, downed_tinker_enemies, rollback_intents)
	_check(
		rollback_res == {"ok": false, "events": []}
		and downed_tinker_party.get_heroes() == heroes_before_downed
		and downed_tinker_enemies.get_enemies() == enemies_before_downed,
		"When source 1 stages front damage and source 2 fails debuffing downed Tinker, CombatEnemyPhase must roll back source 1's staged damage."
	)

	# 3. Malformed / fractional amount / unknown status rejected via production parser, intent validator, and phase executor.
	var invalid_json_cases: Array[Dictionary] = [
		{
			"label": "malformed JSON syntax",
			"json": '[{"enemy_position": 1, "pattern": ['
		},
		{
			"label": "fractional attack amount 4.5",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 4.5, "target_position": 1}]}]'
		},
		{
			"label": "fractional debuff amount 1.25",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 1.25, "target_position": 3, "status": "exposed"}]}]'
		},
		{
			"label": "fractional block amount 2.5",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "block", "amount": 2.5}]}]'
		},
		{
			"label": "fractional target_position 3.5",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 1, "target_position": 3.5, "status": "exposed"}]}]'
		},
		{
			"label": "fractional enemy_position 1.5",
			"json": '[{"enemy_position": 1.5, "pattern": [{"type": "block", "amount": 2}]}]'
		},
		{
			"label": "unsafe integer > 2^53 - 1",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 9007199254740992, "target_position": 1}]}]'
		},
		{
			"label": "unknown status vulnerable",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 1, "target_position": 3, "status": "vulnerable"}]}]'
		},
		{
			"label": "unknown status poison",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 1, "target_position": 3, "status": "poison"}]}]'
		},
		{
			"label": "empty status string",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 1, "target_position": 3, "status": ""}]}]'
		},
		{
			"label": "non-string status",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 1, "target_position": 3, "status": 1}]}]'
		},
		{
			"label": "zero debuff amount",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 0, "target_position": 3, "status": "exposed"}]}]'
		},
		{
			"label": "negative block amount",
			"json": '[{"enemy_position": 2, "pattern": [{"type": "block", "amount": -1}]}]'
		},
		{
			"label": "duplicate enemy_position 1",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "block", "amount": 2}]}, {"enemy_position": 1, "pattern": [{"type": "block", "amount": 3}]}]'
		},
		{
			"label": "target_position 4 out of range",
			"json": '[{"enemy_position": 2, "pattern": [{"type": "attack", "amount": 4, "target_position": 4}]}]'
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
			"label": "unknown status in CombatEnemyIntents",
			"defs": [{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 1, "target_position": 3, "status": "marked"}]}]
		},
		{
			"label": "zero debuff amount in CombatEnemyIntents",
			"defs": [{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 0, "target_position": 3, "status": "exposed"}]}]
		},
		{
			"label": "missing status field on debuff in CombatEnemyIntents",
			"defs": [{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 1, "target_position": 3}]}]
		},
		{
			"label": "duplicate source position in CombatEnemyIntents",
			"defs": [
				{"enemy_position": 2, "pattern": [{"type": "block", "amount": 3}]},
				{"enemy_position": 2, "pattern": [{"type": "attack", "amount": 4, "target_position": 3}]},
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
			"label": "unknown status in phase after valid source 1 block",
			"intents": [
				{"type": "block", "amount": 2, "enemy_position": 1},
				{"type": "debuff", "amount": 1, "target_position": 3, "status": "sunder", "enemy_position": 2},
			]
		},
		{
			"label": "zero debuff amount in phase after valid source 1 attack",
			"intents": [
				{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 1},
				{"type": "debuff", "amount": 0, "target_position": 3, "status": "exposed", "enemy_position": 2},
			]
		},
		{
			"label": "duplicate enemy_position in phase",
			"intents": [
				{"type": "block", "amount": 2, "enemy_position": 1},
				{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 1},
			]
		},
	]
	for batch in invalid_phase_batches:
		var bad_phase := CombatEnemyPhase.new().execute_phase(downed_tinker_party, downed_tinker_enemies, batch["intents"])
		_check(bad_phase == {"ok": false, "events": []}, "CombatEnemyPhase must reject %s." % batch["label"])
		_check(
			downed_tinker_party.get_heroes() == heroes_before_downed
			and downed_tinker_enemies.get_enemies() == enemies_before_downed,
			"CombatEnemyPhase rejection for %s must leave party and enemies unmutated." % batch["label"]
		)


func _find_opening_fight(map: RunMap) -> String:
	for node_id in map.get_legal_choices():
		if map.get_node(node_id).get("type") == "Fight":
			return node_id
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
	var opening_id := _find_opening_fight(map)
	var chosen := map.choose_node(opening_id)
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
		"opening_id": opening_id,
		"chosen": chosen,
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


func _verify_ac5_map_selection_replay_and_existing_schedules(hero_catalog: Array) -> void:
	# 1. Seeded RunMap selection with local one-entry Fight pool, cache detachment, and rejection checks.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9051792
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
	var opening_fight_id := _find_opening_fight(map)
	_check(not opening_fight_id.is_empty(), "Generated RunMap must offer at least one legal opening Fight node.")

	# Unchosen node rejection before choose_node().
	var unchosen_snap := _snapshot_map_and_selector(map, rng, selector)
	_check(
		selector.select_current_battle(map, rng, _local_typed_pool()) == {"success": false}
		and selector.select_current_fight(map, rng, _local_typed_pool()["Fight"]) == {"success": false}
		and _snapshot_map_and_selector(map, rng, selector) == unchosen_snap,
		"Unchosen Fight node must be rejected by select_current_battle and select_current_fight without RNG or route mutation."
	)

	# Choose the legal opening Fight node.
	_check(map.choose_node(opening_fight_id), "Choosing legal opening Fight node must succeed.")
	_check(
		map.get_current_node_id() == opening_fight_id
		and map.get_current_floor() == 1
		and map.get_node(opening_fight_id).get("type") == "Fight",
		"Current chosen node must be the floor-1 Fight node."
	)

	# Invalid-path / wrong-kind-pool / null-RNG rejections on chosen Fight node before first valid selection.
	var pre_select_snap := _snapshot_map_and_selector(map, rng, selector)
	var invalid_pools: Array[Dictionary] = [
		{"label": "empty pools dictionary", "pool": {}},
		{"label": "missing Fight pool key", "pool": {"Elite": {ENCOUNTER_ID: SEAMGUARD_PATH}}},
		{"label": "empty Fight pool", "pool": {"Fight": {}}},
		{"label": "nonexistent encounter file", "pool": {"Fight": {ENCOUNTER_ID: "res://data/encounters/does_not_exist.json"}}},
		{"label": "wrong directory path", "pool": {"Fight": {ENCOUNTER_ID: ENEMY_CATALOG_PATH}}},
		{"label": "path traversal", "pool": {"Fight": {ENCOUNTER_ID: "res://data/encounters/../enemies/run_enemies.json"}}},
		{"label": "non-json extension", "pool": {"Fight": {ENCOUNTER_ID: "res://data/encounters/seamguard_rear_burst.tres"}}},
		{"label": "empty encounter key", "pool": {"Fight": {" ": SEAMGUARD_PATH}}},
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
		"select_current_battle with local one-entry Fight pool must select seamguard_rear_burst and return canonical definitions."
	)

	# Repeated same-node selection caches and deep-detaches without another RNG draw
	# (even when given a multi-entry pool that would advance RNG if uncached).
	var two_entry_pool := {
		"Fight": {
			ENCOUNTER_ID: SEAMGUARD_PATH,
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
	second_choice["definitions"][1]["pattern"][2]["status"] = "invented"
	_check(
		selector.select_current_battle(map, rng, _local_typed_pool()) == expected_choice
		and rng.state == rng_after_first,
		"Mutating returned selection dictionaries must not corrupt selector cache or consume RNG."
	)

	# Traverse further along the map to verify wrong-type node rejection without RNG or route drift.
	var saw_non_fight := false
	for _floor_step in range(2, 13):
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
	var run_a := _execute_seeded_map_and_opening_phase(424242, hero_catalog)
	var run_b := _execute_seeded_map_and_opening_phase(424242, hero_catalog)
	_check(run_a == run_b, "Fresh same-seed fixture must reproduce identical map, selection, RNG states, and opening enemy phase.")
	_check(
		run_a["generated"] == true
		and run_a["chosen"] == true
		and run_a["assembled_ok"] == true
		and run_a["starting_block_ok"] == true
		and run_a["rng_after_select"] == run_a["rng_after_cached"]
		and run_a["choice"] == expected_choice,
		"Same-seed reproduction must succeed at every stage and keep RNG unchanged on cached re-read."
	)

	# 3. Confirm named pre-existing starter_attacks and buttonhole_holdout schedules remain valid.
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
