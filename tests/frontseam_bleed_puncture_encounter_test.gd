extends SceneTree

## Deterministic headless coverage for the authored Frontseam Bleed Puncture encounter:
## slot 1 Fray Scavenger (14 HP) and slot 2 Button Guard (16 HP) on a three-beat cycle
## demonstrating two different consequences of the opening assault on Warden (40 HP, 6 Block):
## Button Guard's 4-damage attack is absorbed by Warden's opening Block (leaving 40 HP, 2 Block),
## while Fray Scavenger's Bleed 2 later subtracts 2 HP directly on the hero owner-turn tick
## even with 2 Block remaining. Data/service only: not yet registered in live pools.

const ENCOUNTER_PATH := "res://data/encounters/frontseam_bleed_puncture.json"
const ENCOUNTER_ID := "frontseam_bleed_puncture"
const HERO_CATALOG_PATH := "res://data/heroes/starter_party.json"
const ENEMY_CATALOG_PATH := "res://data/enemies/run_enemies.json"
const STARTER_ATTACKS_PATH := "res://data/encounters/starter_attacks.json"
const BUTTONHOLE_HOLDOUT_PATH := "res://data/encounters/buttonhole_holdout.json"
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
		print("frontseam_bleed_puncture_encounter_test: FAIL (", failures.size(), " failures)")
		quit(1)
		return
	print("frontseam_bleed_puncture_encounter_test: PASS (", checks, " checks)")
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
	var guard := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "button_guard", ENEMY_CATALOG_PATH), "button_guard")
	return CombatEnemies.new([scavenger, guard])


func _local_roster_map() -> Dictionary:
	return {ENCOUNTER_ID: ["fray_scavenger", "button_guard"]}


func _local_typed_pool() -> Dictionary:
	return {"Fight": {ENCOUNTER_ID: ENCOUNTER_PATH}}


func _expected_pattern_1() -> Array:
	return [
		{"type": "debuff", "amount": 2, "target_position": 1, "status": "bleed"},
		{"type": "attack", "amount": 3, "target_position": 3},
		{"type": "block", "amount": 2},
	]


func _expected_pattern_2() -> Array:
	return [
		{"type": "attack", "amount": 4, "target_position": 1},
		{"type": "buff", "amount": 3},
		{"type": "attack", "amount": 5, "target_position": 2},
	]


func _expected_definitions() -> Array:
	return [
		{"enemy_position": 1, "pattern": _expected_pattern_1()},
		{"enemy_position": 2, "pattern": _expected_pattern_2()},
	]


func _expected_beat_1_intents() -> Array[Dictionary]:
	return [
		{"type": "debuff", "amount": 2, "target_position": 1, "status": "bleed", "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 2},
	]


func _expected_beat_2_intents() -> Array[Dictionary]:
	return [
		{"type": "attack", "amount": 3, "target_position": 3, "enemy_position": 1},
		{"type": "buff", "amount": 3, "enemy_position": 2},
	]


func _expected_beat_3_intents() -> Array[Dictionary]:
	return [
		{"type": "block", "amount": 2, "enemy_position": 1},
		{"type": "attack", "amount": 5, "target_position": 2, "enemy_position": 2},
	]


func _expected_beat_1_events() -> Array[Dictionary]:
	return [
		{"type": "debuff", "enemy_position": 1, "target_position": 1, "status": "bleed", "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true},
	]


func _expected_beat_2_events() -> Array[Dictionary]:
	return [
		{"type": "attack", "enemy_position": 1, "target_position": 3, "applied": true},
		{"type": "buff", "enemy_position": 2, "applied": true},
	]


func _expected_beat_3_events() -> Array[Dictionary]:
	return [
		{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true},
	]


func _run_all_checks() -> void:
	var raw_hero_catalog := _load_json_array(HERO_CATALOG_PATH)
	var raw_enemy_catalog := _load_json_array(ENEMY_CATALOG_PATH)
	var raw_encounter := _load_json_array(ENCOUNTER_PATH)
	var hero_catalog_snapshot := raw_hero_catalog.duplicate(true)
	var enemy_catalog_snapshot := raw_enemy_catalog.duplicate(true)
	var encounter_snapshot := raw_encounter.duplicate(true)

	_verify_ac1_schedule_parser_and_intents(raw_hero_catalog, raw_enemy_catalog)
	_verify_ac2_map_selection_and_roster_assembly(raw_hero_catalog)
	_verify_ac3_three_beat_combat_and_bleed_projection(raw_hero_catalog, raw_enemy_catalog)
	_verify_ac4_negative_cases_and_companion_schedules(raw_hero_catalog, raw_enemy_catalog)

	_check(raw_hero_catalog == hero_catalog_snapshot, "Hero catalog snapshot must remain unmutated after all checks.")
	_check(raw_enemy_catalog == enemy_catalog_snapshot, "Enemy catalog snapshot must remain unmutated after all checks.")
	_check(_load_json_array(ENCOUNTER_PATH) == encounter_snapshot, "Authored frontseam_bleed_puncture.json on disk must remain unmutated after all checks.")


## AC1: Parse frontseam_bleed_puncture.json, verify integer normalization,
## two source slots 1/2, three-beat actions, turns 1/2/3/1 cadence, and deep-copy isolation.
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
	var guard := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "button_guard", ENEMY_CATALOG_PATH), "button_guard")
	_check(
		scavenger.get("name") == "Fray Scavenger"
		and scavenger.get("max_hp") == 14
		and scavenger.get("art_path") == "res://assets/paper/enemies/fray_scavenger.png",
		"Catalog Fray Scavenger must retain name Fray Scavenger, 14 max_hp, and fray_scavenger art_path."
	)
	_check(
		guard.get("name") == "Button Guard"
		and guard.get("max_hp") == 16
		and guard.get("art_path") == "res://assets/paper/enemies/button_guard.png",
		"Catalog Button Guard must retain name Button Guard, 16 max_hp, and button_guard art_path."
	)

	# Verify raw JSON integral numeric fields before coercion, then parse via RunFightEncounterSelection._parse_schedule_text.
	var raw_text := _read_text(ENCOUNTER_PATH)
	var raw_json := _load_json_array(ENCOUNTER_PATH)
	_check(raw_json.size() == 2, "frontseam_bleed_puncture.json must contain exactly 2 enemy source definitions.")
	for raw_def in raw_json:
		_check(raw_def is Dictionary, "Each raw definition in frontseam_bleed_puncture.json must be a Dictionary.")
		if raw_def is Dictionary:
			_check(_is_integral_number(raw_def.get("enemy_position")), "Raw enemy_position must be integral before coercion.")
			var raw_pattern: Variant = raw_def.get("pattern", [])
			_check(raw_pattern is Array and raw_pattern.size() == 3, "Each raw pattern in frontseam_bleed_puncture.json must be a 3-beat Array.")
			if raw_pattern is Array:
				for raw_action in raw_pattern:
					_check(raw_action is Dictionary, "Each raw action must be a Dictionary.")
					if raw_action is Dictionary:
						_check(_is_integral_number(raw_action.get("amount")), "Raw action amount must be integral.")
						if raw_action.has("target_position"):
							_check(_is_integral_number(raw_action.get("target_position")), "Raw target_position must be integral.")

	var definitions := RunFightEncounterSelection._parse_schedule_text(raw_text)
	_check(definitions.size() == 2, "RunFightEncounterSelection._parse_schedule_text must return 2 definitions for frontseam_bleed_puncture.")
	for parsed_def in definitions:
		_check(typeof(parsed_def.get("enemy_position")) == TYPE_INT, "Parsed enemy_position must have TYPE_INT after coercion.")
		var parsed_pattern: Array = parsed_def.get("pattern", [])
		_check(parsed_pattern.size() == 3, "Each parsed source pattern must contain 3 actions.")
		for parsed_action in parsed_pattern:
			_check(typeof(parsed_action.get("amount")) == TYPE_INT, "Parsed action amount must have TYPE_INT after coercion.")
			if parsed_action.has("target_position"):
				_check(typeof(parsed_action.get("target_position")) == TYPE_INT, "Parsed target_position must have TYPE_INT after coercion.")

	var source_1 := _find_unique_by_key(definitions, "enemy_position", 1, ENCOUNTER_PATH)
	var source_2 := _find_unique_by_key(definitions, "enemy_position", 2, ENCOUNTER_PATH)
	_check(source_1.get("pattern") == _expected_pattern_1(), "Source 1 pattern must match exact 3-beat Fray Scavenger schedule.")
	_check(source_2.get("pattern") == _expected_pattern_2(), "Source 2 pattern must match exact 3-beat Button Guard schedule.")
	_check(definitions == _expected_definitions(), "Normalized frontseam_bleed_puncture definitions must match canonical schedule.")

	# Validate through CombatEnemyIntents across full 3-beat cycle + wraparound (turns 1, 2, 3, 1) and verify deep-copy isolation.
	var caller_definitions := definitions.duplicate(true)
	var intents := CombatEnemyIntents.new(caller_definitions)
	_check(intents.is_valid(), "CombatEnemyIntents must validate frontseam_bleed_puncture definitions.")

	# Mutating caller definitions after construction must not affect CombatEnemyIntents.
	caller_definitions[0]["pattern"][0]["amount"] = 999
	caller_definitions[1]["pattern"].clear()
	_check(intents.is_valid() and intents.get_intents() == _expected_beat_1_intents(), "Mutating caller definition array after construction must not corrupt CombatEnemyIntents.")

	var expected_b1 := _expected_beat_1_intents()
	var expected_b2 := _expected_beat_2_intents()
	var expected_b3 := _expected_beat_3_intents()

	var b1_read_a := intents.get_intents()
	var b1_read_b := intents.get_intents()
	_check(b1_read_a == expected_b1, "Turn 1 intents must match source 1 bleed 2 on pos 1 and source 2 attack 4 on pos 1.")
	_check(b1_read_b == expected_b1, "Repeated get_intents() on Turn 1 must not advance implicitly.")
	_check(
		b1_read_a.size() == 2 and b1_read_a[0].get("enemy_position") == 1 and b1_read_a[1].get("enemy_position") == 2,
		"Turn 1 intents must be ordered by ascending enemy_position 1 then 2."
	)
	if not b1_read_a.is_empty():
		b1_read_a[0]["amount"] = 777
		b1_read_a[0]["status"] = "invented"
		b1_read_a.append({"type": "block", "amount": 9, "enemy_position": 3})
	_check(b1_read_b == expected_b1, "Mutating one get_intents() result must not affect another fetched result.")
	_check(intents.get_intents() == expected_b1, "Mutating returned intents must not mutate CombatEnemyIntents state.")

	_check(intents.advance_turn(), "advance_turn() from Turn 1 to Turn 2 must succeed.")
	_check(intents.get_intents() == expected_b2, "Turn 2 intents must match source 1 attack 3 on pos 3 and source 2 buff 3.")
	_check(intents.get_intents() == expected_b2, "Repeated get_intents() on Turn 2 must not advance implicitly.")

	_check(intents.advance_turn(), "advance_turn() from Turn 2 to Turn 3 must succeed.")
	_check(intents.get_intents() == expected_b3, "Turn 3 intents must match source 1 block 2 and source 2 attack 5 on pos 2.")
	_check(intents.get_intents() == expected_b3, "Repeated get_intents() on Turn 3 must not advance implicitly.")

	_check(intents.advance_turn(), "advance_turn() from Turn 3 to Turn 4 (wraparound) must succeed.")
	_check(intents.get_intents() == expected_b1, "Turn 4 announcement must wrap around to exact Turn 1 intents.")
	_check(intents.advance_turn() and intents.get_intents() == expected_b2, "Turn 5 announcement must continue cycle to Turn 2 intents.")
	_check(intents.advance_turn() and intents.get_intents() == expected_b3, "Turn 6 announcement must continue cycle to Turn 3 intents.")

	# Verify reversed source order still announces in ascending enemy_position order.
	var reversed_intents := CombatEnemyIntents.new([source_2.duplicate(true), source_1.duplicate(true)])
	_check(reversed_intents.is_valid(), "CombatEnemyIntents must accept reversed source order.")
	_check(reversed_intents.get_intents() == expected_b1, "CombatEnemyIntents must sort announced actions by ascending enemy_position.")

	# Verify zero global RNG consumption during CombatEnemyIntents construction, reading, and advancing.
	seed(20261022)
	var expected_global := randi()
	seed(20261022)
	var rng_probe := CombatEnemyIntents.new(definitions)
	for _turn in range(6):
		rng_probe.get_intents()
		rng_probe.advance_turn()
	_check(randi() == expected_global, "CombatEnemyIntents construction, reading, and advancing must consume zero global RNG.")


func _find_legal_fight(map: RunMap) -> String:
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


func _execute_seeded_map_selection_and_assembly(seed_value: int, hero_catalog: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := RunMap.new()
	var generated := map.generate(rng)
	var fight_id := _find_legal_fight(map)
	var chose_ok := map.choose_node(fight_id)
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
		"chose_ok": chose_ok,
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


## AC2: Fixed-seed RunMap (seed 4271), legal opening Fight, local singleton Fight pool
## for frontseam_bleed_puncture, cache repeat without extra RNG draw, fresh same-seed
## map replay, and RunTypedBattleRoster.assemble producing 14/16-HP enemies.
func _verify_ac2_map_selection_and_roster_assembly(hero_catalog: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_VALUE
	var map := RunMap.new()
	var selector := RunFightEncounterSelection.new()

	# Ungenerated map rejection without RNG or route drift.
	var ungen_snap := _snapshot_map_and_selector(map, rng, selector)
	_check(
		selector.select_current_battle(map, rng, _local_typed_pool()) == {"success": false}
		and _snapshot_map_and_selector(map, rng, selector) == ungen_snap,
		"Ungenerated RunMap must fail closed in select_current_battle without RNG or state drift."
	)

	_check(map.generate(rng), "RunMap.generate(rng) with seed %d must succeed." % SEED_VALUE)

	# Unchosen node rejection before choose_node().
	var unchosen_snap := _snapshot_map_and_selector(map, rng, selector)
	_check(
		selector.select_current_battle(map, rng, _local_typed_pool()) == {"success": false}
		and selector.select_current_fight(map, rng, _local_typed_pool()["Fight"]) == {"success": false}
		and _snapshot_map_and_selector(map, rng, selector) == unchosen_snap,
		"Unchosen Fight node must be rejected by select_current_battle and select_current_fight without RNG or route mutation."
	)

	var fight_id := _find_legal_fight(map)
	_check(not fight_id.is_empty(), "Seeded RunMap must expose a legal opening Fight node in get_legal_choices().")
	_check(map.choose_node(fight_id), "Choosing legal opening Fight node %s must succeed." % fight_id)
	_check(
		map.get_current_node_id() == fight_id and map.get_node(fight_id).get("type") == "Fight",
		"Current chosen node must be the legal opening Fight node."
	)

	# Pre-selection negative checks on chosen Fight node must not consume RNG or mutate state.
	var pre_select_snap := _snapshot_map_and_selector(map, rng, selector)
	var invalid_pools: Array[Dictionary] = [
		{"label": "empty pools dictionary", "pool": {}},
		{"label": "missing Fight pool key", "pool": {"Elite": {ENCOUNTER_ID: ENCOUNTER_PATH}}},
		{"label": "empty Fight pool", "pool": {"Fight": {}}},
		{"label": "nonexistent encounter file", "pool": {"Fight": {ENCOUNTER_ID: "res://data/encounters/does_not_exist.json"}}},
		{"label": "wrong directory path", "pool": {"Fight": {ENCOUNTER_ID: ENEMY_CATALOG_PATH}}},
		{"label": "path traversal", "pool": {"Fight": {ENCOUNTER_ID: "res://data/encounters/../enemies/run_enemies.json"}}},
		{"label": "non-json extension", "pool": {"Fight": {ENCOUNTER_ID: "res://data/encounters/frontseam_bleed_puncture.tres"}}},
		{"label": "empty encounter key", "pool": {"Fight": {" ": ENCOUNTER_PATH}}},
	]
	for bad_entry in invalid_pools:
		var rejected := selector.select_current_battle(map, rng, bad_entry["pool"])
		_check(
			rejected == {"success": false}
			and _snapshot_map_and_selector(map, rng, selector) == pre_select_snap,
			"Invalid selector call (%s) must fail closed without RNG, route, or cache mutation." % bad_entry["label"]
		)

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
		"select_current_battle with local singleton Fight pool must return node_type=Fight, encounter_id=frontseam_bleed_puncture, and exact schedule."
	)

	# Repeated selection on the same current node is cached without an extra RNG draw, even with a two-entry pool.
	var two_entry_pool := {
		"Fight": {
			ENCOUNTER_ID: ENCOUNTER_PATH,
			"starter_attacks": STARTER_ATTACKS_PATH,
		}
	}
	var cached_choice := selector.select_current_battle(map, rng, two_entry_pool)
	_check(
		cached_choice == expected_choice and rng.state == rng_after_first,
		"Repeated select_current_battle on the same node must return cached choice with unchanged rng.state."
	)
	var cached_legacy := selector.select_current_fight(map, rng, two_entry_pool["Fight"])
	_check(
		cached_legacy == {
			"success": true,
			"encounter_id": ENCOUNTER_ID,
			"definitions": _expected_definitions(),
		}
		and rng.state == rng_after_first,
		"select_current_fight on the same cached node must return cached choice without node_type and consume zero RNG."
	)

	# Mutate returned choice and confirm selector cache is deep-detached.
	var choice_for_assemble := choice.duplicate(true)
	choice["encounter_id"] = "mutated_id"
	choice["definitions"][0]["pattern"][0]["amount"] = 999
	choice["definitions"].clear()
	_check(
		selector.select_current_battle(map, rng, _local_typed_pool()) == expected_choice
		and rng.state == rng_after_first,
		"Mutating returned selection dictionary must not corrupt selector cache or advance RNG."
	)

	# Assemble roster via RunTypedBattleRoster.assemble.
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
		"RunTypedBattleRoster.assemble must succeed with Fight node_type, frontseam_bleed_puncture ID, and exact definitions."
	)
	var assembled_enemies: Variant = assembled.get("enemies")
	_check(assembled_enemies is CombatEnemies and assembled_enemies.is_valid(), "Assembled enemies must be a valid CombatEnemies instance.")
	if assembled_enemies is CombatEnemies:
		var enemy_list: Array[Dictionary] = assembled_enemies.get_enemies()
		_check(enemy_list.size() == 2, "Assembled CombatEnemies must contain exactly 2 enemies.")
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
			"Slot 1 assembled enemy must be Fray Scavenger (fray_scavenger) with 14/14 HP, 0 Block, and exact art_path."
		)
		_check(
			assembled_enemies.get_enemy(2) == {
				"id": "button_guard",
				"name": "Button Guard",
				"max_hp": 16,
				"art_path": "res://assets/paper/enemies/button_guard.png",
				"position": 2,
				"hp": 16,
				"block": 0,
			},
			"Slot 2 assembled enemy must be Button Guard (button_guard) with 16/16 HP, 0 Block, and exact art_path."
		)

	# Verify detachment of assembled definitions and negative roster assembly rejections.
	if assembled.has("definitions") and assembled["definitions"] is Array and not assembled["definitions"].is_empty():
		assembled["definitions"][0]["enemy_position"] = 99
	_check(choice_for_assemble == choice_snapshot, "Mutating assembled definitions must not affect caller typed_choice.")
	_check(
		roster_bridge.assemble(choice_for_assemble, {ENCOUNTER_ID: ["fray_scavenger"]}, [ENEMY_CATALOG_PATH]) == {"ok": false},
		"RunTypedBattleRoster must reject mismatched 1-enemy roster for 2-source frontseam_bleed_puncture."
	)
	_check(
		roster_bridge.assemble(choice_for_assemble, {ENCOUNTER_ID: ["fray_scavenger", "fray_scavenger"]}, [ENEMY_CATALOG_PATH]) == {"ok": false},
		"RunTypedBattleRoster must reject duplicate enemy IDs."
	)
	_check(
		roster_bridge.assemble(choice_for_assemble, {ENCOUNTER_ID: ["fray_scavenger", "unknown_enemy"]}, [ENEMY_CATALOG_PATH]) == {"ok": false},
		"RunTypedBattleRoster must reject unknown enemy ID."
	)

	# Fresh map with the same seed reproduces the exact selection, RNG states, roster, and opening phase.
	var replay_a := _execute_seeded_map_selection_and_assembly(SEED_VALUE, hero_catalog)
	var replay_b := _execute_seeded_map_selection_and_assembly(SEED_VALUE, hero_catalog)
	_check(replay_a == replay_b, "Second fresh same-seed map and selector must reproduce identical selection, RNG state, roster, and Beat 1 outcome.")
	_check(
		replay_a["generated"] == true
		and replay_a["chose_ok"] == true
		and replay_a["assembled_ok"] == true
		and replay_a["starting_block_ok"] == true
		and replay_a["rng_after_select"] == rng_after_first
		and replay_a["rng_after_select"] == replay_a["rng_after_cached"]
		and replay_a["choice"] == expected_choice,
		"Same-seed replay must match primary selection RNG state and cached zero-draw behavior."
	)


func _execute_three_beat_trace(seed_value: int, hero_catalog: Array, enemy_catalog: Array) -> Dictionary:
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = seed_value
	var local_rng_initial := local_rng.state
	seed(seed_value)
	var expected_global := randi()
	seed(seed_value)

	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	var party := _build_catalog_party(hero_catalog)
	var enemies := _build_catalog_enemies(enemy_catalog)
	var starting_block := CombatStartingBlock.new(party)
	var first_block_apply := starting_block.apply()
	var second_block_apply := starting_block.apply()
	var opening_heroes := party.get_heroes()
	var opening_enemies := enemies.get_enemies()

	var intents := CombatEnemyIntents.new(definitions)
	var phase := CombatEnemyPhase.new()
	var batch := CombatStatusTurnBatch.new()

	var beat_1_announced := intents.get_intents()
	var beat_1_res := phase.execute_phase(party, enemies, beat_1_announced)
	var heroes_after_1 := party.get_heroes()
	var enemies_after_1 := enemies.get_enemies()
	var tick_1 := batch.tick_side("heroes", party.get_heroes())
	var heroes_after_tick_1_check := party.get_heroes()

	var advance_to_2 := intents.advance_turn()
	var beat_2_announced := intents.get_intents()
	var beat_2_res := phase.execute_phase(party, enemies, beat_2_announced)
	var heroes_after_2 := party.get_heroes()
	var enemies_after_2 := enemies.get_enemies()

	var advance_to_3 := intents.advance_turn()
	var beat_3_announced := intents.get_intents()
	var beat_3_res := phase.execute_phase(party, enemies, beat_3_announced)
	var heroes_after_3 := party.get_heroes()
	var enemies_after_3 := enemies.get_enemies()

	var advance_to_4 := intents.advance_turn()
	var beat_4_announced := intents.get_intents()
	var global_after := randi()

	return {
		"first_block_apply": first_block_apply,
		"second_block_apply": second_block_apply,
		"opening_heroes": opening_heroes,
		"opening_enemies": opening_enemies,
		"beat_1_announced": beat_1_announced,
		"beat_1_res": beat_1_res,
		"heroes_after_1": heroes_after_1,
		"enemies_after_1": enemies_after_1,
		"tick_1": tick_1,
		"heroes_after_tick_1_check": heroes_after_tick_1_check,
		"advance_to_2": advance_to_2,
		"beat_2_announced": beat_2_announced,
		"beat_2_res": beat_2_res,
		"heroes_after_2": heroes_after_2,
		"enemies_after_2": enemies_after_2,
		"advance_to_3": advance_to_3,
		"beat_3_announced": beat_3_announced,
		"beat_3_res": beat_3_res,
		"heroes_after_3": heroes_after_3,
		"enemies_after_3": enemies.get_enemies(),
		"advance_to_4": advance_to_4,
		"beat_4_announced": beat_4_announced,
		"local_rng_unchanged": local_rng.state == local_rng_initial,
		"global_rng_unchanged": global_after == expected_global,
	}


## AC3: Starter party (40/30/26 HP) + Warden once-only 6 Block;
## Beat 1 applies Bleed 2 to Warden then blocks Button Guard's 4 attack damage (Warden 40 HP, 2 Block, Bleed 2);
## Separate CombatStatusTurnBatch.tick_side("heroes", party.get_heroes()) projects Warden 38 HP, 2 Block, Bleed 1
## with bleed_hp_loss=2 without mutating CombatParty;
## Beat 2 deals 3 to Tinker (23 HP) and buffs Button Guard +3 Block;
## Beat 3 gives Fray Scavenger +2 Block and deals 5 to Seamstress (25 HP);
## Beat 4 wraps to Beat 1.
func _verify_ac3_three_beat_combat_and_bleed_projection(hero_catalog: Array, enemy_catalog: Array) -> void:
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
	_check(enemies.is_valid(), "Two-enemy CombatEnemies must be valid.")

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
		"Opening party must be Warden (40 HP, 6 Block), Seamstress (30 HP, 0 Block), Tinker (26 HP, 0 Block)."
	)

	var intents := CombatEnemyIntents.new(definitions)
	var phase := CombatEnemyPhase.new()

	# Beat 1: Source 1 inflicts Bleed 2 on Warden; Source 2 attacks position 1 for 4 (absorbed by 6 Block -> 2 Block).
	var b1_intents := intents.get_intents()
	var b1_intents_copy := b1_intents.duplicate(true)
	_check(b1_intents == _expected_beat_1_intents(), "Beat 1 intents must match expected debuff bleed 2 and attack 4 on pos 1.")
	var b1_res := phase.execute_phase(party, enemies, b1_intents)
	_check(b1_intents == b1_intents_copy, "CombatEnemyPhase.execute_phase must not mutate caller intents array.")
	_check(
		b1_res == {"ok": true, "events": _expected_beat_1_events()},
		"Beat 1 execute_phase must resolve source 1 bleed debuff then source 2 attack in ascending enemy_position order."
	)
	_check(
		party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("position") == 1
		and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 2
		and party.get_hero(1).get("statuses") == {"bleed": 2},
		"After Beat 1, Warden must have 40 HP, 2 Block, and statuses={bleed: 2}."
	)
	_check(
		party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(2).get("hp") == 30
		and party.get_hero(2).get("block") == 0
		and party.get_hero(2).get("statuses", {}) == {}
		and party.get_hero(3).get("id") == "tinker"
		and party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("block") == 0
		and party.get_hero(3).get("statuses", {}) == {},
		"After Beat 1, Seamstress (30 HP, 0 Block) and Tinker (26 HP, 0 Block) must be unharmed with no statuses."
	)
	_check(
		enemies.get_enemy(1).get("id") == "fray_scavenger"
		and enemies.get_enemy(1).get("hp") == 14
		and enemies.get_enemy(1).get("block") == 0
		and enemies.get_enemy(2).get("id") == "button_guard"
		and enemies.get_enemy(2).get("hp") == 16
		and enemies.get_enemy(2).get("block") == 0,
		"After Beat 1, enemy HP and Block must remain 14/0 and 16/0."
	)

	# Project one subsequent HERO owner-end tick separately with CombatStatusTurnBatch.tick_side("heroes", party.get_heroes()).
	var party_before_projection := party.get_heroes()
	var caller_heroes_arg := party.get_heroes()
	var caller_heroes_snapshot := caller_heroes_arg.duplicate(true)
	var batch := CombatStatusTurnBatch.new()
	var tick_1 := batch.tick_side("heroes", caller_heroes_arg)
	_check(caller_heroes_arg == caller_heroes_snapshot, "CombatStatusTurnBatch.tick_side must not mutate the passed actors array.")
	_check(party.get_heroes() == party_before_projection, "Projection alone must NOT commit back to CombatParty (Warden stays 40 HP, 2 Block, Bleed 2).")
	_check(tick_1.get("ok") == true, "CombatStatusTurnBatch.tick_side('heroes', ...) must succeed.")
	var projected_actors: Array = tick_1.get("actors", [])
	_check(projected_actors.size() == 3, "Projected hero tick must return 3 hero records.")
	if projected_actors.size() == 3:
		_check(
			projected_actors[0].get("id") == "warden"
			and projected_actors[0].get("position") == 1
			and projected_actors[0].get("hp") == 38
			and projected_actors[0].get("block") == 2
			and projected_actors[0].get("statuses") == {"bleed": 1},
			"Projected Warden after 1 hero owner-turn tick must have 38 HP (2 bypassed Block), 2 Block still remaining, and Bleed decremented to 1."
		)
		_check(
			projected_actors[1].get("id") == "seamstress"
			and projected_actors[1].get("hp") == 30
			and projected_actors[1].get("block") == 0
			and projected_actors[1].get("statuses") == {}
			and projected_actors[2].get("id") == "tinker"
			and projected_actors[2].get("hp") == 26
			and projected_actors[2].get("block") == 0
			and projected_actors[2].get("statuses") == {},
			"Projected Seamstress and Tinker must remain at 30/26 HP and 0 Block."
		)
	_check(
		tick_1.get("events") == [
			{"side": "heroes", "position": 1, "id": "warden", "bleed_hp_loss": 2},
			{"side": "heroes", "position": 2, "id": "seamstress", "bleed_hp_loss": 0},
			{"side": "heroes", "position": 3, "id": "tinker", "bleed_hp_loss": 0},
		],
		"Projected hero tick events must report bleed_hp_loss=2 on Warden and 0 on Seamstress/Tinker."
	)

	# Second projected owner-turn tick on the detached actors array expires Bleed (1 -> 0) and loses 1 more HP (38 -> 37) while keeping Block 2.
	var tick_2 := batch.tick_side("heroes", projected_actors)
	_check(
		tick_2.get("ok") == true
		and tick_2.get("actors", []).size() == 3
		and tick_2["actors"][0].get("hp") == 37
		and tick_2["actors"][0].get("block") == 2
		and tick_2["actors"][0].get("statuses") == {}
		and tick_2.get("events") == [
			{"side": "heroes", "position": 1, "id": "warden", "bleed_hp_loss": 1},
			{"side": "heroes", "position": 2, "id": "seamstress", "bleed_hp_loss": 0},
			{"side": "heroes", "position": 3, "id": "tinker", "bleed_hp_loss": 0},
		],
		"Second projected owner-turn tick on detached actors must bring Warden to 37 HP, 2 Block, and empty statuses={}."
	)
	_check(
		party.get_heroes() == party_before_projection
		and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 2
		and party.get_hero(1).get("statuses") == {"bleed": 2},
		"Original CombatParty must still retain Warden at 40 HP, 2 Block, and Bleed 2 after detached projections."
	)

	# Beat 2 (advancing CombatEnemyIntents on preserved party state):
	# Source 1 attacks Tinker (pos 3) for 3 (26 -> 23 HP); Source 2 buffs itself for 3 Block (0 -> 3 Block).
	_check(intents.advance_turn(), "Advancing intents from Beat 1 to Beat 2 must succeed.")
	var b2_intents := intents.get_intents()
	_check(b2_intents == _expected_beat_2_intents(), "Beat 2 intents must match source 1 attack 3 on pos 3 and source 2 buff 3.")
	var b2_res := phase.execute_phase(party, enemies, b2_intents)
	_check(
		b2_res == {"ok": true, "events": _expected_beat_2_events()},
		"Beat 2 execute_phase must resolve source 1 attack on Tinker then source 2 self-buff in ascending source order."
	)
	_check(
		party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 2
		and party.get_hero(1).get("statuses") == {"bleed": 2}
		and party.get_hero(2).get("hp") == 30
		and party.get_hero(2).get("block") == 0
		and party.get_hero(2).get("statuses", {}) == {}
		and party.get_hero(3).get("hp") == 23
		and party.get_hero(3).get("block") == 0
		and party.get_hero(3).get("statuses", {}) == {},
		"After Beat 2, Tinker must be at 23 HP while Warden (40 HP, 2 Block, Bleed 2) and Seamstress (30 HP, 0 Block) are unchanged."
	)
	_check(
		enemies.get_enemy(1).get("id") == "fray_scavenger"
		and enemies.get_enemy(1).get("hp") == 14
		and enemies.get_enemy(1).get("block") == 0
		and enemies.get_enemy(2).get("id") == "button_guard"
		and enemies.get_enemy(2).get("hp") == 16
		and enemies.get_enemy(2).get("block") == 3,
		"After Beat 2, Button Guard must have 16 HP and 3 Block while Fray Scavenger remains at 14 HP and 0 Block."
	)

	# Beat 3 (advancing CombatEnemyIntents):
	# Source 1 gains 2 Block (0 -> 2 Block); Source 2 attacks Seamstress (pos 2) for 5 (30 -> 25 HP).
	_check(intents.advance_turn(), "Advancing intents from Beat 2 to Beat 3 must succeed.")
	var b3_intents := intents.get_intents()
	_check(b3_intents == _expected_beat_3_intents(), "Beat 3 intents must match source 1 block 2 and source 2 attack 5 on pos 2.")
	var b3_res := phase.execute_phase(party, enemies, b3_intents)
	_check(
		b3_res == {"ok": true, "events": _expected_beat_3_events()},
		"Beat 3 execute_phase must resolve source 1 block 2 then source 2 attack 5 on Seamstress in ascending source order."
	)
	_check(
		party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 2
		and party.get_hero(1).get("statuses") == {"bleed": 2}
		and party.get_hero(2).get("hp") == 25
		and party.get_hero(2).get("block") == 0
		and party.get_hero(2).get("statuses", {}) == {}
		and party.get_hero(3).get("hp") == 23
		and party.get_hero(3).get("block") == 0
		and party.get_hero(3).get("statuses", {}) == {},
		"After Beat 3, Seamstress must be at 25 HP, Tinker at 23 HP, and Warden at 40 HP / 2 Block / Bleed 2."
	)
	_check(
		enemies.get_enemy(1).get("id") == "fray_scavenger"
		and enemies.get_enemy(1).get("hp") == 14
		and enemies.get_enemy(1).get("block") == 2
		and enemies.get_enemy(2).get("id") == "button_guard"
		and enemies.get_enemy(2).get("hp") == 16
		and enemies.get_enemy(2).get("block") == 3,
		"After Beat 3, Fray Scavenger has 14 HP / 2 Block and Button Guard has 16 HP / 3 Block."
	)

	# Beat 4 announces Beat 1 again without RNG consumption.
	_check(intents.advance_turn(), "Advancing intents from Beat 3 to Beat 4 must succeed.")
	_check(intents.get_intents() == _expected_beat_1_intents(), "Beat 4 must wrap around and announce Beat 1 intents again.")
	_check(randi() == expected_global_draw, "Executing Beats 1-3, status projection, and wraparound must consume zero global RNG.")

	# Compare two independent deterministic 3-beat replays.
	var trace_a := _execute_three_beat_trace(975318642, hero_catalog, enemy_catalog)
	var trace_b := _execute_three_beat_trace(975318642, hero_catalog, enemy_catalog)
	_check(trace_a == trace_b, "Two independent 3-beat replays must produce identical announcements, events, rosters, projections, and RNG states.")
	_check(
		trace_a["first_block_apply"] == true
		and trace_a["second_block_apply"] == false
		and trace_a["local_rng_unchanged"] == true
		and trace_a["global_rng_unchanged"] == true
		and trace_a["beat_4_announced"] == _expected_beat_1_intents(),
		"Replay trace must confirm one-time opening Block, untouched local/global RNG, and Beat 4 wraparound."
	)


## AC4: Downed Warden before opening Block rejects Beat 1 atomically;
## Slain Fray Scavenger skips Bleed (applied=false) while living Button Guard consumes 4 of Warden's 6 Block;
## Duplicate source positions and invalid debuff status/target fail the real parser and validator;
## Existing starter_attacks.json and buttonhole_holdout.json still parse and cycle cleanly.
func _verify_ac4_negative_cases_and_companion_schedules(hero_catalog: Array, enemy_catalog: Array) -> void:
	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	var phase := CombatEnemyPhase.new()

	# 1. Downed-target negative case: Warden downed at 0 HP BEFORE applying any opening Block.
	var downed_party := _build_catalog_party(hero_catalog)
	var downed_enemies := _build_catalog_enemies(enemy_catalog)
	_check(
		downed_party.apply_damage(1, 40) and downed_party.is_downed(1) and downed_party.get_hero(1).get("hp") == 0,
		"Downing Warden (40 HP) at position 1 before applying any opening Block must succeed."
	)
	_check(
		not CombatStartingBlock.new(downed_party).apply() and downed_party.get_hero(1).get("block") == 0,
		"CombatStartingBlock.apply() must reject when Warden is already downed."
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
		"With Warden downed at 0 HP before Beat 1, source 1's Bleed target is invalid and the entire phase must return {ok: false, events: []}."
	)
	_check(
		downed_party.get_heroes() == downed_heroes_snapshot
		and downed_party.get_hero(1).get("hp") == 0
		and downed_party.get_hero(1).get("block") == 0
		and downed_party.get_hero(1).get("statuses", {}) == {},
		"Rejected downed-target phase must preserve authoritative hero roster without adding Bleed or mutating HP/Block."
	)
	_check(
		downed_enemies.get_enemies() == downed_enemies_snapshot,
		"Rejected downed-target phase must preserve authoritative enemy roster."
	)
	_check(
		downed_intents == downed_intents_snapshot
		and downed_scheduler.get_intents() == _expected_beat_1_intents()
		and downed_scheduler._turn_index == 0,
		"Rejected downed-target phase must preserve passed intent snapshot and scheduler turn state."
	)
	_check(
		downed_rng.state == downed_rng_state and randi() == expected_global,
		"Rejected downed-target phase must preserve local seeded RNG state and consume zero global RNG."
	)

	# Also verify atomic rollback when source 1 stages a real state change on living Warden
	# and source 2 fails on a downed debuff target (Lesson 39).
	var rollback_party := _build_catalog_party(hero_catalog)
	var rollback_enemies := _build_catalog_enemies(enemy_catalog)
	_check(CombatStartingBlock.new(rollback_party).apply(), "Opening Block must apply on rollback fixture.")
	_check(rollback_party.apply_damage(2, 30) and rollback_party.is_downed(2), "Downing Seamstress at position 2 must succeed.")
	var rollback_heroes_before := rollback_party.get_heroes()
	var rollback_enemies_before := rollback_enemies.get_enemies()
	var rollback_batch: Array[Dictionary] = [
		{"type": "debuff", "amount": 2, "target_position": 1, "status": "bleed", "enemy_position": 1},
		{"type": "debuff", "amount": 1, "target_position": 2, "status": "weak", "enemy_position": 2},
	]
	var rollback_batch_snapshot := rollback_batch.duplicate(true)
	var rollback_res := phase.execute_phase(rollback_party, rollback_enemies, rollback_batch)
	_check(
		rollback_res == {"ok": false, "events": []}
		and rollback_party.get_heroes() == rollback_heroes_before
		and rollback_party.get_hero(1).get("statuses", {}) == {}
		and rollback_enemies.get_enemies() == rollback_enemies_before
		and rollback_batch == rollback_batch_snapshot,
		"When source 1 stages Bleed 2 on living Warden and source 2 targets downed Seamstress with debuff, the entire phase must roll back atomically."
	)

	# 2. Slain-source negative case: defeat enemy position 1 (Fray Scavenger, 14 HP) before a fresh Beat 1.
	var slain_party := _build_catalog_party(hero_catalog)
	var slain_enemies := _build_catalog_enemies(enemy_catalog)
	_check(CombatStartingBlock.new(slain_party).apply(), "Opening Block must apply on slain-source fixture.")
	_check(
		slain_enemies.apply_damage(1, 14)
		and slain_enemies.is_slain(1)
		and slain_enemies.is_dead(1)
		and not slain_enemies.is_slain(2)
		and not slain_enemies.is_defeated()
		and not slain_enemies.is_victorious(),
		"Defeating Fray Scavenger (14 HP) at position 1 must mark only slot 1 slain while the 2-enemy roster is not yet defeated."
	)
	var slain_scheduler := CombatEnemyIntents.new(definitions)
	var slain_intents := slain_scheduler.get_intents()
	var slain_res := phase.execute_phase(slain_party, slain_enemies, slain_intents)
	var expected_slain_events: Array[Dictionary] = [
		{"type": "debuff", "enemy_position": 1, "target_position": 1, "status": "bleed", "applied": false},
		{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true},
	]
	_check(
		slain_res == {"ok": true, "events": expected_slain_events},
		"When Fray Scavenger at position 1 is slain before Beat 1, its Bleed event has applied=false while living Button Guard's attack has applied=true."
	)
	_check(
		slain_party.get_hero(1).get("id") == "warden"
		and slain_party.get_hero(1).get("hp") == 40
		and slain_party.get_hero(1).get("block") == 2
		and slain_party.get_hero(1).get("statuses", {}) == {},
		"After slain-source Beat 1, Button Guard's 4-damage attack consumes 4 of Warden's opening 6 Block, leaving Warden at 40 HP, 2 Block, and no Bleed."
	)
	_check(
		slain_party.get_hero(2).get("hp") == 30
		and slain_party.get_hero(3).get("hp") == 26
		and slain_enemies.get_enemy(1).get("position") == 1
		and slain_enemies.get_enemy(1).get("hp") == 0
		and slain_enemies.get_enemy(2).get("position") == 2
		and slain_enemies.get_enemy(2).get("hp") == 16
		and slain_enemies.get_enemy(2).get("block") == 0,
		"Slain Fray Scavenger keeps slot 1 at 0 HP while Seamstress, Tinker, and Button Guard remain untouched."
	)
	# Verify victory boundary when final enemy is slain.
	_check(
		slain_enemies.apply_damage(2, 16)
		and slain_enemies.is_slain(2)
		and slain_enemies.is_defeated()
		and slain_enemies.is_victorious(),
		"Defeating the remaining Button Guard (16 HP) at slot 2 transitions the roster to defeated/victorious."
	)

	# 3. Parser and validator rejections: duplicate source positions, invalid debuff status, invalid debuff target, fractional amounts, etc.
	var invalid_json_cases: Array[Dictionary] = [
		{
			"label": "duplicate enemy_position 1",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 2, "target_position": 1, "status": "bleed"}]}, {"enemy_position": 1, "pattern": [{"type": "attack", "amount": 4, "target_position": 1}]}]'
		},
		{
			"label": "duplicate enemy_position 2",
			"json": '[{"enemy_position": 2, "pattern": [{"type": "block", "amount": 2}]}, {"enemy_position": 2, "pattern": [{"type": "buff", "amount": 3}]}]'
		},
		{
			"label": "invalid debuff status poison",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 2, "target_position": 1, "status": "poison"}]}]'
		},
		{
			"label": "invalid debuff status vulnerable",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 2, "target_position": 1, "status": "vulnerable"}]}]'
		},
		{
			"label": "empty debuff status",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 2, "target_position": 1, "status": ""}]}]'
		},
		{
			"label": "non-string debuff status",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 2, "target_position": 1, "status": 2}]}]'
		},
		{
			"label": "invalid debuff target_position 0",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 2, "target_position": 0, "status": "bleed"}]}]'
		},
		{
			"label": "invalid debuff target_position 4",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 2, "target_position": 4, "status": "bleed"}]}]'
		},
		{
			"label": "missing debuff target_position",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 2, "status": "bleed"}]}]'
		},
		{
			"label": "zero debuff amount",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 0, "target_position": 1, "status": "bleed"}]}]'
		},
		{
			"label": "negative debuff amount",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": -2, "target_position": 1, "status": "bleed"}]}]'
		},
		{
			"label": "zero buff amount",
			"json": '[{"enemy_position": 2, "pattern": [{"type": "buff", "amount": 0}]}]'
		},
		{
			"label": "fractional debuff amount 2.5",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 2.5, "target_position": 1, "status": "bleed"}]}]'
		},
		{
			"label": "fractional debuff target_position 1.5",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 2, "target_position": 1.5, "status": "bleed"}]}]'
		},
		{
			"label": "fractional enemy_position 1.5",
			"json": '[{"enemy_position": 1.5, "pattern": [{"type": "block", "amount": 2}]}]'
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
			"label": "duplicate source position in CombatEnemyIntents",
			"defs": [
				{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 2, "target_position": 1, "status": "bleed"}]},
				{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 4, "target_position": 1}]},
			]
		},
		{
			"label": "invalid debuff status in CombatEnemyIntents",
			"defs": [
				{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 2, "target_position": 1, "status": "burn"}]},
			]
		},
		{
			"label": "invalid debuff target 0 in CombatEnemyIntents",
			"defs": [
				{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 2, "target_position": 0, "status": "bleed"}]},
			]
		},
		{
			"label": "invalid debuff target 4 in CombatEnemyIntents",
			"defs": [
				{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 2, "target_position": 4, "status": "bleed"}]},
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

	# 4. Positive parsing and full cycle verification of unchanged starter_attacks.json and buttonhole_holdout.json.
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

	var holdout_defs := RunFightEncounterSelection._parse_schedule_text(_read_text(BUTTONHOLE_HOLDOUT_PATH))
	_check(holdout_defs.size() == 2, "buttonhole_holdout.json must still parse into 2 source definitions.")
	var holdout_s1 := _find_unique_by_key(holdout_defs, "enemy_position", 1, BUTTONHOLE_HOLDOUT_PATH)
	var holdout_s2 := _find_unique_by_key(holdout_defs, "enemy_position", 2, BUTTONHOLE_HOLDOUT_PATH)
	_check(
		holdout_s1.get("pattern") == [
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "block", "amount": 1},
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 3},
		],
		"buttonhole_holdout.json source 1 pattern must remain unchanged."
	)
	_check(
		holdout_s2.get("pattern") == [
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "attack", "amount": 1, "target_position": 3},
		],
		"buttonhole_holdout.json source 2 pattern must remain unchanged."
	)
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
