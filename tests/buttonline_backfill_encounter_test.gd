extends SceneTree

const BUTTONLINE_BACKFILL_PATH := "res://data/encounters/buttonline_backfill.json"
const STARTER_ATTACKS_PATH := "res://data/encounters/starter_attacks.json"
const FRAYGUARD_ATTRITION_PATH := "res://data/encounters/frayguard_attrition.json"
const STARTER_PARTY_PATH := "res://data/heroes/starter_party.json"
const RUN_ENEMIES_PATH := "res://data/enemies/run_enemies.json"

var _failures: Array[String] = []


func _initialize() -> void:
	_verify_failure_probe_harnesses()
	_test_ac1_buttonline_backfill_parse_and_catalog_identities()
	_test_ac2_three_beat_action_services_over_real_catalog_actors()
	_test_ac3_intent_cycle_wrap_replay_no_rng_and_fail_closed_rejections()
	_test_ac4_existing_encounters_preserved_and_standalone_boundary()

	if _failures.is_empty():
		print("PASS buttonline_backfill_encounter_test")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String, sink: Array[String] = _failures) -> void:
	if not condition:
		sink.append(message)


func _is_integral_number(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float or is_nan(value) or is_inf(value):
		return false
	return absf(value) <= 9007199254740991.0 and floorf(value) == value


func _read_text(path: String, sink: Array[String] = _failures) -> String:
	_check(FileAccess.file_exists(path), "Expected file to exist: %s" % path, sink)
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "Expected file to open: %s" % path, sink)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _load_actor_catalog(path: String, sink: Array[String] = _failures) -> Array[Dictionary]:
	var text := _read_text(path, sink)
	if text.is_empty():
		return []
	var parser := JSON.new()
	var err := parser.parse(text)
	_check(err == OK, "Expected valid JSON in %s" % path, sink)
	if err != OK or not parser.data is Array:
		_check(false, "Expected top-level Array in %s" % path, sink)
		return []
	var raw_entries: Array = parser.data
	var entries: Array[Dictionary] = []
	for raw_entry in raw_entries:
		if not raw_entry is Dictionary:
			_check(false, "Expected Dictionary actor entry in %s" % path, sink)
			return []
		var entry: Dictionary = raw_entry.duplicate(true)
		var id_val = entry.get("id")
		var name_val = entry.get("name")
		var max_hp_val = entry.get("max_hp")
		var art_path_val = entry.get("art_path")
		if not id_val is String or id_val.is_empty() or not name_val is String or name_val.is_empty():
			_check(false, "Expected non-empty String id/name in %s" % path, sink)
			return []
		if not art_path_val is String or art_path_val.is_empty():
			_check(false, "Expected non-empty String art_path in %s" % path, sink)
			return []
		if not _is_integral_number(max_hp_val):
			_check(false, "Expected integral max_hp in %s for %s" % [path, str(id_val)], sink)
			return []
		entry["max_hp"] = int(max_hp_val)
		entries.append(entry)
	return entries


func _find_unique_actor_by_id(
		catalog: Array[Dictionary], actor_id: String, label: String,
		sink: Array[String] = _failures) -> Dictionary:
	var matches: Array[Dictionary] = []
	for entry in catalog:
		if entry.get("id") == actor_id:
			matches.append(entry.duplicate(true))
	_check(matches.size() == 1,
		"%s must contain exactly one '%s' entry (found %d)" % [label, actor_id, matches.size()],
		sink)
	if matches.size() != 1:
		return {}
	return matches[0]


func _find_unique_source_definition(
		definitions: Array, enemy_position: int, label: String,
		sink: Array[String] = _failures) -> Dictionary:
	var matches: Array[Dictionary] = []
	for entry in definitions:
		if entry is Dictionary and entry.get("enemy_position") == enemy_position:
			matches.append(entry.duplicate(true))
	_check(matches.size() == 1,
		"%s must contain exactly one enemy_position=%d entry (found %d)" % [
			label, enemy_position, matches.size()
		],
		sink)
	if matches.size() != 1:
		return {}
	return matches[0]


func _assert_hero_slot(
		party: CombatParty, slot: int, expected_id: String, expected_name: String,
		expected_hp: int, expected_max_hp: int, expected_block: int,
		expected_statuses: Dictionary, context: String,
		sink: Array[String] = _failures) -> void:
	var hero := party.get_hero(slot)
	_check(not hero.is_empty(), "%s: hero slot %d must exist" % [context, slot], sink)
	_check(hero.get("id") == expected_id,
		"%s: slot %d expected id '%s', got '%s'" % [context, slot, expected_id, str(hero.get("id"))],
		sink)
	_check(hero.get("name") == expected_name,
		"%s: slot %d expected name '%s', got '%s'" % [context, slot, expected_name, str(hero.get("name"))],
		sink)
	_check(hero.get("position") == slot,
		"%s: slot %d expected position %d, got %s" % [context, slot, slot, str(hero.get("position"))],
		sink)
	_check(hero.get("hp") == expected_hp,
		"%s: slot %d (%s) expected hp %d, got %s" % [context, slot, expected_id, expected_hp, str(hero.get("hp"))],
		sink)
	_check(hero.get("max_hp") == expected_max_hp,
		"%s: slot %d (%s) expected max_hp %d, got %s" % [
			context, slot, expected_id, expected_max_hp, str(hero.get("max_hp"))
		],
		sink)
	_check(hero.get("block") == expected_block,
		"%s: slot %d (%s) expected block %d, got %s" % [
			context, slot, expected_id, expected_block, str(hero.get("block"))
		],
		sink)
	var actual_statuses: Dictionary = hero.get("statuses", {})
	_check(actual_statuses == expected_statuses,
		"%s: slot %d (%s) expected statuses %s, got %s" % [
			context, slot, expected_id, str(expected_statuses), str(actual_statuses)
		],
		sink)


func _assert_enemy_slot(
		enemies: CombatEnemies, slot: int, expected_id: String, expected_name: String,
		expected_hp: int, expected_max_hp: int, expected_block: int,
		expected_statuses: Dictionary, context: String,
		sink: Array[String] = _failures) -> void:
	var enemy := enemies.get_enemy(slot)
	_check(not enemy.is_empty(), "%s: enemy slot %d must exist" % [context, slot], sink)
	_check(enemy.get("id") == expected_id,
		"%s: enemy slot %d expected id '%s', got '%s'" % [
			context, slot, expected_id, str(enemy.get("id"))
		],
		sink)
	_check(enemy.get("name") == expected_name,
		"%s: enemy slot %d expected name '%s', got '%s'" % [
			context, slot, expected_name, str(enemy.get("name"))
		],
		sink)
	_check(enemy.get("position") == slot,
		"%s: enemy slot %d expected position %d, got %s" % [
			context, slot, slot, str(enemy.get("position"))
		],
		sink)
	_check(enemy.get("hp") == expected_hp,
		"%s: enemy slot %d (%s) expected hp %d, got %s" % [
			context, slot, expected_id, expected_hp, str(enemy.get("hp"))
		],
		sink)
	_check(enemy.get("max_hp") == expected_max_hp,
		"%s: enemy slot %d (%s) expected max_hp %d, got %s" % [
			context, slot, expected_id, expected_max_hp, str(enemy.get("max_hp"))
		],
		sink)
	_check(enemy.get("block") == expected_block,
		"%s: enemy slot %d (%s) expected block %d, got %s" % [
			context, slot, expected_id, expected_block, str(enemy.get("block"))
		],
		sink)
	var actual_statuses: Dictionary = enemy.get("statuses", {})
	_check(actual_statuses == expected_statuses,
		"%s: enemy slot %d (%s) expected statuses %s, got %s" % [
			context, slot, expected_id, str(expected_statuses), str(actual_statuses)
		],
		sink)


func _verify_failure_probe_harnesses() -> void:
	var probe_failures: Array[String] = []
	_check(false, "deliberate probe failure", probe_failures)
	_check(probe_failures.size() == 1, "Failure harness must record failed assertions")

	# Prove fractional max_hp in actor data is rejected by integral guard before int conversion.
	_check(not _is_integral_number(16.5), "Fractional float 16.5 must fail integral check")
	_check(not _is_integral_number(NAN), "NaN must fail integral check")
	_check(not _is_integral_number(INF), "INF must fail integral check")
	_check(_is_integral_number(16), "Integer 16 must pass integral check")
	_check(_is_integral_number(16.0), "Integral float 16.0 must pass integral check")

	# Prove global RNG draw detector catches an injected draw.
	var probe_seed := 918273645
	seed(probe_seed)
	var expected_next := randi()
	seed(probe_seed)
	var _injected_draw := randi()
	var after_injected_draw := randi()
	_check(after_injected_draw != expected_next,
		"Global RNG probe must detect an injected randi() draw")


func _test_ac1_buttonline_backfill_parse_and_catalog_identities() -> void:
	var enemy_catalog := _load_actor_catalog(RUN_ENEMIES_PATH)
	var enemy_catalog_snapshot := enemy_catalog.duplicate(true)
	_check(not enemy_catalog.is_empty(), "run_enemies.json catalog must load")

	var button_guard := _find_unique_actor_by_id(enemy_catalog, "button_guard", "run_enemies.json")
	var spool_stalker := _find_unique_actor_by_id(enemy_catalog, "spool_stalker", "run_enemies.json")
	_check(button_guard.get("name") == "Button Guard", "button_guard name must be Button Guard")
	_check(button_guard.get("max_hp") == 16, "button_guard max_hp must be 16")
	_check(spool_stalker.get("name") == "Spool Stalker", "spool_stalker name must be Spool Stalker")
	_check(spool_stalker.get("max_hp") == 14, "spool_stalker max_hp must be 14")

	var enemies := CombatEnemies.new([button_guard, spool_stalker])
	_check(enemies.is_valid(), "CombatEnemies([button_guard, spool_stalker]) must be valid")
	_assert_enemy_slot(enemies, 1, "button_guard", "Button Guard", 16, 16, 0, {}, "AC1 initial slot 1")
	_assert_enemy_slot(enemies, 2, "spool_stalker", "Spool Stalker", 14, 14, 0, {}, "AC1 initial slot 2")
	_check(enemies.get_enemy(3).is_empty(), "Two-enemy encounter must have no slot 3 enemy")

	var raw_schedule := _read_text(BUTTONLINE_BACKFILL_PATH)
	var definitions := RunFightEncounterSelection._parse_schedule_text(raw_schedule)
	_check(definitions.size() == 2,
		"buttonline_backfill.json must parse to 2 enemy source definitions, got %d" % definitions.size())

	var source_1 := _find_unique_source_definition(definitions, 1, "buttonline_backfill.json")
	var source_2 := _find_unique_source_definition(definitions, 2, "buttonline_backfill.json")
	if definitions.size() == 2:
		_check(definitions[0].get("enemy_position") == 1,
			"buttonline_backfill.json first source must be enemy_position 1")
		_check(definitions[1].get("enemy_position") == 2,
			"buttonline_backfill.json second source must be enemy_position 2")

	var expected_pattern_1: Array = [
		{"type": "block", "amount": 3},
		{"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
		{"type": "attack", "amount": 3, "target_position": 3},
	]
	var expected_pattern_2: Array = [
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
		{"type": "attack", "amount": 4, "target_position": 2},
		{"type": "buff", "amount": 2},
	]
	_check(source_1.get("pattern") == expected_pattern_1,
		"Slot 1 (Button Guard) pattern must be [block 3, shove 2->3, attack 3@3], got %s" % str(
			source_1.get("pattern")))
	_check(source_2.get("pattern") == expected_pattern_2,
		"Slot 2 (Spool Stalker) pattern must be [weak 1@3, attack 4@2, buff 2], got %s" % str(
			source_2.get("pattern")))

	var intents := CombatEnemyIntents.new(definitions)
	_check(intents.is_valid(), "CombatEnemyIntents for buttonline_backfill.json must be valid")

	# Prove returned intent Dictionaries are independent copies.
	var first_read := intents.get_intents()
	var second_read := intents.get_intents()
	_check(first_read == second_read and first_read.size() == 2,
		"Repeated get_intents() calls must return identical 2-source arrays")
	if not first_read.is_empty():
		first_read[0]["amount"] = 999
	_check(intents.get_intents() == second_read,
		"Mutating a returned get_intents() Dictionary must not mutate CombatEnemyIntents")
	_check(enemy_catalog == enemy_catalog_snapshot,
		"Enemy catalog snapshot must remain unchanged after AC1 checks")


func _build_live_fixture() -> Dictionary:
	var hero_catalog := _load_actor_catalog(STARTER_PARTY_PATH)
	var enemy_catalog := _load_actor_catalog(RUN_ENEMIES_PATH)
	var warden := _find_unique_actor_by_id(hero_catalog, "warden", "starter_party.json")
	var seamstress := _find_unique_actor_by_id(hero_catalog, "seamstress", "starter_party.json")
	var tinker := _find_unique_actor_by_id(hero_catalog, "tinker", "starter_party.json")
	var button_guard := _find_unique_actor_by_id(enemy_catalog, "button_guard", "run_enemies.json")
	var spool_stalker := _find_unique_actor_by_id(enemy_catalog, "spool_stalker", "run_enemies.json")

	var party := CombatParty.new([warden, seamstress, tinker])
	var starting_block := CombatStartingBlock.new(party)
	var enemies := CombatEnemies.new([button_guard, spool_stalker])
	var definitions := RunFightEncounterSelection._parse_schedule_text(
		_read_text(BUTTONLINE_BACKFILL_PATH))
	var intents := CombatEnemyIntents.new(definitions)
	var special_actions := CombatEnemySpecialActions.new()
	var attack_service := CombatEnemyAttacks.new()

	return {
		"hero_catalog": hero_catalog,
		"enemy_catalog": enemy_catalog,
		"party": party,
		"starting_block": starting_block,
		"enemies": enemies,
		"definitions": definitions,
		"intents": intents,
		"special_actions": special_actions,
		"attack_service": attack_service,
	}


func _test_ac2_three_beat_action_services_over_real_catalog_actors() -> void:
	var fixture := _build_live_fixture()
	var hero_catalog_before: Array = fixture["hero_catalog"].duplicate(true)
	var enemy_catalog_before: Array = fixture["enemy_catalog"].duplicate(true)
	var party: CombatParty = fixture["party"]
	var starting_block: CombatStartingBlock = fixture["starting_block"]
	var enemies: CombatEnemies = fixture["enemies"]
	var intents: CombatEnemyIntents = fixture["intents"]
	var special_actions: CombatEnemySpecialActions = fixture["special_actions"]
	var attack_service: CombatEnemyAttacks = fixture["attack_service"]

	_check(party.is_valid(), "Starter party must be valid")
	_check(enemies.is_valid(), "Encounter enemies must be valid")
	_check(intents.is_valid(), "Encounter intents must be valid")

	# One-time opening 6 Block on Warden at slot 1.
	_check(starting_block.apply(), "Warden opening 6 Block must apply on fresh party")
	_check(not starting_block.apply(), "Warden opening 6 Block must be one-time and reject second apply()")

	_assert_hero_slot(party, 1, "warden", "Warden", 40, 40, 6, {}, "AC2 opening")
	_assert_hero_slot(party, 2, "seamstress", "Seamstress", 30, 30, 0, {}, "AC2 opening")
	_assert_hero_slot(party, 3, "tinker", "Tinker", 26, 26, 0, {}, "AC2 opening")
	_assert_enemy_slot(enemies, 1, "button_guard", "Button Guard", 16, 16, 0, {}, "AC2 opening")
	_assert_enemy_slot(enemies, 2, "spool_stalker", "Spool Stalker", 14, 14, 0, {}, "AC2 opening")

	# Beat 1: Slot 1 Button Guard Block 3; Slot 2 Spool Stalker gives Weak 1 to hero slot 3 (Tinker).
	var beat_1 := intents.get_intents()
	var expected_beat_1: Array[Dictionary] = [
		{"enemy_position": 1, "type": "block", "amount": 3},
		{"enemy_position": 2, "type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
	]
	_check(beat_1 == expected_beat_1, "Beat 1 intents must match authored turn 1 actions")

	var beat_1_block_res := CombatEnemyBlocks.execute_blocks(enemies, [beat_1[0]])
	_check(beat_1_block_res == {
		"ok": true,
		"events": [{"enemy_position": 1, "applied": true}],
	}, "Beat 1 Button Guard Block 3 must apply with event applied=true")

	var beat_1_debuff_res := special_actions.execute_actions(party, enemies, [beat_1[1]])
	_check(beat_1_debuff_res == {
		"ok": true,
		"events": [{
			"type": "debuff",
			"enemy_position": 2,
			"applied": true,
			"target_position": 3,
			"status": "weak",
		}],
	}, "Beat 1 Spool Stalker Weak 1 on slot 3 must apply with event applied=true")

	_assert_hero_slot(party, 1, "warden", "Warden", 40, 40, 6, {}, "AC2 after Beat 1")
	_assert_hero_slot(party, 2, "seamstress", "Seamstress", 30, 30, 0, {}, "AC2 after Beat 1")
	_assert_hero_slot(party, 3, "tinker", "Tinker", 26, 26, 0, {"weak": 1}, "AC2 after Beat 1")
	_assert_enemy_slot(enemies, 1, "button_guard", "Button Guard", 16, 16, 3, {}, "AC2 after Beat 1")
	_assert_enemy_slot(enemies, 2, "spool_stalker", "Spool Stalker", 14, 14, 0, {}, "AC2 after Beat 1")

	# Beat 2: Slot 1 Button Guard shoves hero slot 2 to 3; Slot 2 Spool Stalker attacks hero slot 2 for 4.
	_check(intents.advance_turn(), "advance_turn() to Beat 2 must succeed")
	var beat_2 := intents.get_intents()
	var expected_beat_2: Array[Dictionary] = [
		{"enemy_position": 1, "type": "shove", "amount": 0, "target_position": 2, "direction": 1},
		{"enemy_position": 2, "type": "attack", "amount": 4, "target_position": 2},
	]
	_check(beat_2 == expected_beat_2, "Beat 2 intents must match authored turn 2 actions")

	var beat_2_shove_res := special_actions.execute_actions(party, enemies, [beat_2[0]])
	_check(beat_2_shove_res == {
		"ok": true,
		"events": [{
			"type": "shove",
			"enemy_position": 1,
			"applied": true,
			"target_position": 2,
			"direction": 1,
		}],
	}, "Beat 2 Button Guard shove 2->3 must apply with event applied=true")

	# Verify intermediate state right after shove and BEFORE Stalker's 4-damage attack on slot 2.
	_assert_hero_slot(party, 1, "warden", "Warden", 40, 40, 6, {}, "AC2 Beat 2 after shove")
	_assert_hero_slot(party, 2, "tinker", "Tinker", 26, 26, 0, {"weak": 1}, "AC2 Beat 2 after shove")
	_assert_hero_slot(party, 3, "seamstress", "Seamstress", 30, 30, 0, {}, "AC2 Beat 2 after shove")

	var beat_2_attack_res := attack_service.execute_attacks(party, [beat_2[1]])
	_check(beat_2_attack_res == {
		"ok": true,
		"events": [{"enemy_position": 2, "target_position": 2, "applied": true}],
	}, "Beat 2 Spool Stalker attack 4 on slot 2 must apply with event applied=true")

	_assert_hero_slot(party, 1, "warden", "Warden", 40, 40, 6, {}, "AC2 after Beat 2")
	_assert_hero_slot(party, 2, "tinker", "Tinker", 22, 26, 0, {"weak": 1}, "AC2 after Beat 2")
	_assert_hero_slot(party, 3, "seamstress", "Seamstress", 30, 30, 0, {}, "AC2 after Beat 2")
	_assert_enemy_slot(enemies, 1, "button_guard", "Button Guard", 16, 16, 3, {}, "AC2 after Beat 2")
	_assert_enemy_slot(enemies, 2, "spool_stalker", "Spool Stalker", 14, 14, 0, {}, "AC2 after Beat 2")

	# Beat 3: Slot 1 Button Guard attacks hero slot 3 for 3; Slot 2 Spool Stalker self-buffs Block 2.
	_check(intents.advance_turn(), "advance_turn() to Beat 3 must succeed")
	var beat_3 := intents.get_intents()
	var expected_beat_3: Array[Dictionary] = [
		{"enemy_position": 1, "type": "attack", "amount": 3, "target_position": 3},
		{"enemy_position": 2, "type": "buff", "amount": 2},
	]
	_check(beat_3 == expected_beat_3, "Beat 3 intents must match authored turn 3 actions")

	var beat_3_attack_res := attack_service.execute_attacks(party, [beat_3[0]])
	_check(beat_3_attack_res == {
		"ok": true,
		"events": [{"enemy_position": 1, "target_position": 3, "applied": true}],
	}, "Beat 3 Button Guard attack 3 on slot 3 must apply with event applied=true")

	var beat_3_buff_res := special_actions.execute_actions(party, enemies, [beat_3[1]])
	_check(beat_3_buff_res == {
		"ok": true,
		"events": [{"type": "buff", "enemy_position": 2, "applied": true}],
	}, "Beat 3 Spool Stalker self-buff Block 2 must apply with event applied=true")

	_assert_hero_slot(party, 1, "warden", "Warden", 40, 40, 6, {}, "AC2 after Beat 3")
	_assert_hero_slot(party, 2, "tinker", "Tinker", 22, 26, 0, {"weak": 1}, "AC2 after Beat 3")
	_assert_hero_slot(party, 3, "seamstress", "Seamstress", 27, 30, 0, {}, "AC2 after Beat 3")
	_assert_enemy_slot(enemies, 1, "button_guard", "Button Guard", 16, 16, 3, {}, "AC2 after Beat 3")
	_assert_enemy_slot(enemies, 2, "spool_stalker", "Spool Stalker", 14, 14, 2, {}, "AC2 after Beat 3")

	_check(not party.is_defeated(), "Party must not be defeated after 3 beats")
	_check(not enemies.is_defeated() and not enemies.is_victorious(),
		"Enemies must not be defeated after 3 beats")
	_check(fixture["hero_catalog"] == hero_catalog_before, "Hero catalog must remain unmutated")
	_check(fixture["enemy_catalog"] == enemy_catalog_before, "Enemy catalog must remain unmutated")


func _run_seeded_three_beat_trace(rng_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var initial_rng_seed := rng.seed
	var initial_rng_state := rng.state

	var fixture := _build_live_fixture()
	var party: CombatParty = fixture["party"]
	var starting_block: CombatStartingBlock = fixture["starting_block"]
	var enemies: CombatEnemies = fixture["enemies"]
	var intents: CombatEnemyIntents = fixture["intents"]
	var special_actions: CombatEnemySpecialActions = fixture["special_actions"]
	var attack_service: CombatEnemyAttacks = fixture["attack_service"]

	var starting_block_applied := starting_block.apply()

	var t1_intents := intents.get_intents()
	var t1_intents_repeat := intents.get_intents()
	var b1_block := CombatEnemyBlocks.execute_blocks(enemies, [t1_intents[0]])
	var b1_debuff := special_actions.execute_actions(party, enemies, [t1_intents[1]])
	var snap_after_t1 := {
		"heroes": party.get_heroes(),
		"enemies": enemies.get_enemies(),
	}

	var adv_1 := intents.advance_turn()
	var t2_intents := intents.get_intents()
	var t2_intents_repeat := intents.get_intents()
	var b2_shove := special_actions.execute_actions(party, enemies, [t2_intents[0]])
	var snap_after_t2_shove := {
		"heroes": party.get_heroes(),
		"enemies": enemies.get_enemies(),
	}
	var b2_attack := attack_service.execute_attacks(party, [t2_intents[1]])
	var snap_after_t2 := {
		"heroes": party.get_heroes(),
		"enemies": enemies.get_enemies(),
	}

	var adv_2 := intents.advance_turn()
	var t3_intents := intents.get_intents()
	var t3_intents_repeat := intents.get_intents()
	var b3_attack := attack_service.execute_attacks(party, [t3_intents[0]])
	var b3_buff := special_actions.execute_actions(party, enemies, [t3_intents[1]])
	var snap_after_t3 := {
		"heroes": party.get_heroes(),
		"enemies": enemies.get_enemies(),
	}

	# Advance to Turn 4 wrap and full second cycle (Turns 4, 5, 6)
	var adv_3 := intents.advance_turn()
	var t4_wrap_intents := intents.get_intents()
	var adv_4 := intents.advance_turn()
	var t5_wrap_intents := intents.get_intents()
	var adv_5 := intents.advance_turn()
	var t6_wrap_intents := intents.get_intents()

	return {
		"rng_seed_unchanged": rng.seed == initial_rng_seed,
		"rng_state_unchanged": rng.state == initial_rng_state,
		"starting_block_applied": starting_block_applied,
		"t1_intents": t1_intents,
		"t1_intents_repeat": t1_intents_repeat,
		"b1_block": b1_block,
		"b1_debuff": b1_debuff,
		"snap_after_t1": snap_after_t1,
		"adv_1": adv_1,
		"t2_intents": t2_intents,
		"t2_intents_repeat": t2_intents_repeat,
		"b2_shove": b2_shove,
		"snap_after_t2_shove": snap_after_t2_shove,
		"b2_attack": b2_attack,
		"snap_after_t2": snap_after_t2,
		"adv_2": adv_2,
		"t3_intents": t3_intents,
		"t3_intents_repeat": t3_intents_repeat,
		"b3_attack": b3_attack,
		"b3_buff": b3_buff,
		"snap_after_t3": snap_after_t3,
		"adv_3": adv_3,
		"t4_wrap_intents": t4_wrap_intents,
		"adv_4": adv_4,
		"t5_wrap_intents": t5_wrap_intents,
		"adv_5": adv_5,
		"t6_wrap_intents": t6_wrap_intents,
	}


func _test_ac3_intent_cycle_wrap_replay_no_rng_and_fail_closed_rejections() -> void:
	# Global RNG stream non-consumption check across full parse + 3 beats + wrap.
	var global_seed := 135792468
	seed(global_seed)
	var expected_global_draw := randi()
	seed(global_seed)

	var trace_a := _run_seeded_three_beat_trace(20261021)
	var trace_b := _run_seeded_three_beat_trace(20261021)
	var actual_global_draw := randi()
	_check(actual_global_draw == expected_global_draw,
		"Schedule parse, intent cycle, and action services must not draw from global RNG")

	_check(trace_a == trace_b, "Two fresh seeded fixtures must produce identical full traces")
	_check(trace_a["rng_seed_unchanged"] and trace_a["rng_state_unchanged"],
		"Fixture A local RandomNumberGenerator seed and state must remain untouched")
	_check(trace_b["rng_seed_unchanged"] and trace_b["rng_state_unchanged"],
		"Fixture B local RandomNumberGenerator seed and state must remain untouched")

	# Verify no implicit advance on repeated get_intents() reads, and exact Turn 4/5/6 wrap.
	_check(trace_a["t1_intents"] == trace_a["t1_intents_repeat"],
		"Turn 1 get_intents() must not advance implicitly")
	_check(trace_a["t2_intents"] == trace_a["t2_intents_repeat"],
		"Turn 2 get_intents() must not advance implicitly")
	_check(trace_a["t3_intents"] == trace_a["t3_intents_repeat"],
		"Turn 3 get_intents() must not advance implicitly")
	_check(trace_a["t4_wrap_intents"] == trace_a["t1_intents"],
		"Turn 4 wrap must announce exact Turn 1 source-ordered actions")
	_check(trace_a["t5_wrap_intents"] == trace_a["t2_intents"],
		"Turn 5 wrap must announce exact Turn 2 source-ordered actions")
	_check(trace_a["t6_wrap_intents"] == trace_a["t3_intents"],
		"Turn 6 wrap must announce exact Turn 3 source-ordered actions")

	# Illegal shove of a downed swap participant fails closed without mutating party or enemies.
	# Case A: Shoved target (slot 2 Seamstress) is downed.
	var downed_slot2_fixture := _build_live_fixture()
	var party_slot2_down: CombatParty = downed_slot2_fixture["party"]
	var enemies_slot2_down: CombatEnemies = downed_slot2_fixture["enemies"]
	var special_slot2_down: CombatEnemySpecialActions = downed_slot2_fixture["special_actions"]
	_check(downed_slot2_fixture["starting_block"].apply(), "Opening block on slot 2 downed fixture")
	_check(party_slot2_down.apply_damage(2, 30) and party_slot2_down.is_downed(2),
		"Slot 2 Seamstress must be downed at 0 HP")
	var heroes_before_slot2_shove := party_slot2_down.get_heroes()
	var enemies_before_slot2_shove := enemies_slot2_down.get_enemies()
	var shove_action := {
		"enemy_position": 1,
		"type": "shove",
		"amount": 0,
		"target_position": 2,
		"direction": 1,
	}
	var res_down_slot2 := special_slot2_down.execute_actions(
		party_slot2_down, enemies_slot2_down, [shove_action])
	_check(res_down_slot2 == {"ok": false, "events": []},
		"Shoving downed slot 2 hero must fail closed")
	_check(party_slot2_down.get_heroes() == heroes_before_slot2_shove,
		"Failed shove of downed slot 2 hero must not mutate party state")
	_check(enemies_slot2_down.get_enemies() == enemies_before_slot2_shove,
		"Failed shove of downed slot 2 hero must not mutate enemy state")

	# Case B: Destination swap participant (slot 3 Tinker) is downed, and batch includes a valid buff on slot 2.
	var downed_slot3_fixture := _build_live_fixture()
	var party_slot3_down: CombatParty = downed_slot3_fixture["party"]
	var enemies_slot3_down: CombatEnemies = downed_slot3_fixture["enemies"]
	var special_slot3_down: CombatEnemySpecialActions = downed_slot3_fixture["special_actions"]
	_check(downed_slot3_fixture["starting_block"].apply(), "Opening block on slot 3 downed fixture")
	_check(party_slot3_down.apply_damage(3, 26) and party_slot3_down.is_downed(3),
		"Slot 3 Tinker must be downed at 0 HP")
	var heroes_before_slot3_shove := party_slot3_down.get_heroes()
	var enemies_before_slot3_shove := enemies_slot3_down.get_enemies()
	var buff_action := {"enemy_position": 2, "type": "buff", "amount": 2}
	var res_down_slot3 := special_slot3_down.execute_actions(
		party_slot3_down, enemies_slot3_down, [shove_action, buff_action])
	_check(res_down_slot3 == {"ok": false, "events": []},
		"Shoving into downed slot 3 destination hero must fail entire batch closed")
	_check(party_slot3_down.get_heroes() == heroes_before_slot3_shove,
		"Failed shove into downed slot 3 destination must not mutate party state")
	_check(enemies_slot3_down.get_enemies() == enemies_before_slot3_shove,
		"Failed shove into downed slot 3 destination must not apply companion enemy buff")

	# Case C: Debuff targeting a downed hero fails closed without mutating party or enemies.
	var debuff_action := {
		"enemy_position": 2,
		"type": "debuff",
		"amount": 1,
		"target_position": 3,
		"status": "weak",
	}
	var res_down_debuff := special_slot3_down.execute_actions(
		party_slot3_down, enemies_slot3_down, [debuff_action])
	_check(res_down_debuff == {"ok": false, "events": []},
		"Debuff targeting downed slot 3 hero must fail closed")
	_check(party_slot3_down.get_heroes() == heroes_before_slot3_shove,
		"Failed debuff on downed slot 3 hero must not mutate party state")
	_check(enemies_slot3_down.get_enemies() == enemies_before_slot3_shove,
		"Failed debuff on downed slot 3 hero must not mutate enemy state")

	# Malformed schedule rejections via RunFightEncounterSelection._parse_schedule_text and CombatEnemyIntents.
	var malformed_schedules: Array[Dictionary] = [
		{
			"name": "duplicate enemy_position 1",
			"json": JSON.stringify([
				{"enemy_position": 1, "pattern": [{"type": "block", "amount": 3}]},
				{"enemy_position": 1, "pattern": [{"type": "buff", "amount": 2}]},
			]),
		},
		{
			"name": "invalid shove direction 0",
			"json": JSON.stringify([
				{"enemy_position": 1, "pattern": [
					{"type": "shove", "amount": 0, "target_position": 2, "direction": 0}
				]},
			]),
		},
		{
			"name": "invalid shove direction out of bounds 3->4",
			"json": JSON.stringify([
				{"enemy_position": 1, "pattern": [
					{"type": "shove", "amount": 0, "target_position": 3, "direction": 1}
				]},
			]),
		},
		{
			"name": "invalid shove non-zero amount",
			"json": JSON.stringify([
				{"enemy_position": 1, "pattern": [
					{"type": "shove", "amount": 1, "target_position": 2, "direction": 1}
				]},
			]),
		},
		{
			"name": "invalid debuff status name",
			"json": JSON.stringify([
				{"enemy_position": 2, "pattern": [
					{"type": "debuff", "amount": 1, "target_position": 3, "status": "poison"}
				]},
			]),
		},
		{
			"name": "invalid debuff zero amount",
			"json": JSON.stringify([
				{"enemy_position": 2, "pattern": [
					{"type": "debuff", "amount": 0, "target_position": 3, "status": "weak"}
				]},
			]),
		},
		{
			"name": "fractional amount in schedule JSON",
			"json": "[{\"enemy_position\":1,\"pattern\":[{\"type\":\"block\",\"amount\":3.5}]}]",
		},
		{
			"name": "fractional enemy_position in schedule JSON",
			"json": "[{\"enemy_position\":1.5,\"pattern\":[{\"type\":\"block\",\"amount\":3}]}]",
		},
		{
			"name": "fractional target_position in schedule JSON",
			"json": "[{\"enemy_position\":1,\"pattern\":[{\"type\":\"attack\",\"amount\":3,\"target_position\":2.5}]}]",
		},
		{
			"name": "fractional direction in schedule JSON",
			"json": "[{\"enemy_position\":1,\"pattern\":[{\"type\":\"shove\",\"amount\":0,\"target_position\":2,\"direction\":0.5}]}]",
		},
	]
	for item in malformed_schedules:
		var parsed := RunFightEncounterSelection._parse_schedule_text(item["json"])
		_check(parsed.is_empty(),
			"Malformed schedule (%s) must parse to empty array" % item["name"])
		var invalid_intents := CombatEnemyIntents.new(parsed)
		_check(not invalid_intents.is_valid(),
			"CombatEnemyIntents on rejected schedule (%s) must be invalid" % item["name"])
		_check(invalid_intents.get_intents().is_empty(),
			"Invalid CombatEnemyIntents (%s) must return empty intents" % item["name"])
		_check(not invalid_intents.advance_turn(),
			"Invalid CombatEnemyIntents (%s) must reject advance_turn()" % item["name"])

	# Also verify malformed runtime actions passed directly to services fail closed without state mutation.
	var service_guard_fixture := _build_live_fixture()
	var guard_party: CombatParty = service_guard_fixture["party"]
	var guard_enemies: CombatEnemies = service_guard_fixture["enemies"]
	var guard_special: CombatEnemySpecialActions = service_guard_fixture["special_actions"]
	var guard_attacks: CombatEnemyAttacks = service_guard_fixture["attack_service"]
	_check(service_guard_fixture["starting_block"].apply(), "Opening block on service guard fixture")
	var guard_heroes_snap := guard_party.get_heroes()
	var guard_enemies_snap := guard_enemies.get_enemies()

	_check(CombatEnemyBlocks.execute_blocks(guard_enemies, [
		{"enemy_position": 1, "type": "block", "amount": 2},
		{"enemy_position": 1, "type": "block", "amount": 1},
	]) == {"ok": false, "events": []}, "Duplicate source in execute_blocks must fail closed")
	_check(guard_special.execute_actions(guard_party, guard_enemies, [
		{"enemy_position": 1, "type": "shove", "amount": 0, "target_position": 2, "direction": 2},
	]) == {"ok": false, "events": []}, "Invalid shove direction in execute_actions must fail closed")
	_check(guard_special.execute_actions(guard_party, guard_enemies, [
		{"enemy_position": 2, "type": "debuff", "amount": 1, "target_position": 3, "status": "stun"},
	]) == {"ok": false, "events": []}, "Invalid debuff status in execute_actions must fail closed")
	_check(guard_special.execute_actions(guard_party, guard_enemies, [
		{"enemy_position": 1, "type": "buff", "amount": 2},
		{"enemy_position": 1, "type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
	]) == {"ok": false, "events": []}, "Duplicate source in execute_actions must fail closed")
	_check(guard_attacks.execute_attacks(guard_party, [
		{"enemy_position": 1, "target_position": 1, "amount": 2},
		{"enemy_position": 1, "target_position": 2, "amount": 2},
	]) == {"ok": false, "events": []}, "Duplicate source in execute_attacks must fail closed")
	_check(guard_party.get_heroes() == guard_heroes_snap,
		"Rejected service actions must leave party state untouched")
	_check(guard_enemies.get_enemies() == guard_enemies_snap,
		"Rejected service actions must leave enemy state untouched")


func _test_ac4_existing_encounters_preserved_and_standalone_boundary() -> void:
	# Verify starter_attacks.json retains its exact named source entries and intents.
	var starter_defs := RunFightEncounterSelection._parse_schedule_text(
		_read_text(STARTER_ATTACKS_PATH))
	_check(starter_defs.size() == 2, "starter_attacks.json must parse to 2 sources")
	var starter_s1 := _find_unique_source_definition(starter_defs, 1, "starter_attacks.json")
	var starter_s2 := _find_unique_source_definition(starter_defs, 2, "starter_attacks.json")
	_check(starter_s1.get("pattern") == [
		{"type": "attack", "amount": 1, "target_position": 1},
		{"type": "attack", "amount": 1, "target_position": 2},
		{"type": "attack", "amount": 1, "target_position": 3},
	], "starter_attacks.json source 1 pattern must remain intact")
	_check(starter_s2.get("pattern") == [
		{"type": "block", "amount": 1},
	], "starter_attacks.json source 2 pattern must remain intact")

	var starter_intents := CombatEnemyIntents.new(starter_defs)
	_check(starter_intents.is_valid(), "starter_attacks.json intents must be valid")
	_check(starter_intents.get_intents() == [
		{"enemy_position": 1, "type": "attack", "amount": 1, "target_position": 1},
		{"enemy_position": 2, "type": "block", "amount": 1},
	], "starter_attacks.json turn 1 intents must remain intact")
	_check(starter_intents.advance_turn(), "starter_attacks.json advance to turn 2")
	_check(starter_intents.get_intents() == [
		{"enemy_position": 1, "type": "attack", "amount": 1, "target_position": 2},
		{"enemy_position": 2, "type": "block", "amount": 1},
	], "starter_attacks.json turn 2 intents must remain intact")
	_check(starter_intents.advance_turn(), "starter_attacks.json advance to turn 3")
	_check(starter_intents.get_intents() == [
		{"enemy_position": 1, "type": "attack", "amount": 1, "target_position": 3},
		{"enemy_position": 2, "type": "block", "amount": 1},
	], "starter_attacks.json turn 3 intents must remain intact")
	_check(starter_intents.advance_turn(), "starter_attacks.json advance to turn 4 wrap")
	_check(starter_intents.get_intents() == [
		{"enemy_position": 1, "type": "attack", "amount": 1, "target_position": 1},
		{"enemy_position": 2, "type": "block", "amount": 1},
	], "starter_attacks.json turn 4 wrap must remain intact")

	# Verify frayguard_attrition.json retains its exact named source entries and intents.
	var frayguard_defs := RunFightEncounterSelection._parse_schedule_text(
		_read_text(FRAYGUARD_ATTRITION_PATH))
	_check(frayguard_defs.size() == 2, "frayguard_attrition.json must parse to 2 sources")
	var frayguard_s1 := _find_unique_source_definition(frayguard_defs, 1, "frayguard_attrition.json")
	var frayguard_s2 := _find_unique_source_definition(frayguard_defs, 2, "frayguard_attrition.json")
	_check(frayguard_s1.get("pattern") == [
		{"type": "debuff", "amount": 2, "target_position": 3, "status": "bleed"},
		{"type": "attack", "amount": 3, "target_position": 3},
		{"type": "attack", "amount": 2, "target_position": 2},
	], "frayguard_attrition.json source 1 pattern must remain intact")
	_check(frayguard_s2.get("pattern") == [
		{"type": "block", "amount": 4},
		{"type": "attack", "amount": 2, "target_position": 1},
		{"type": "buff", "amount": 2},
	], "frayguard_attrition.json source 2 pattern must remain intact")

	var frayguard_intents := CombatEnemyIntents.new(frayguard_defs)
	_check(frayguard_intents.is_valid(), "frayguard_attrition.json intents must be valid")
	_check(frayguard_intents.get_intents() == [
		{"enemy_position": 1, "type": "debuff", "amount": 2, "target_position": 3, "status": "bleed"},
		{"enemy_position": 2, "type": "block", "amount": 4},
	], "frayguard_attrition.json turn 1 intents must remain intact")
	_check(frayguard_intents.advance_turn(), "frayguard_attrition.json advance to turn 2")
	_check(frayguard_intents.get_intents() == [
		{"enemy_position": 1, "type": "attack", "amount": 3, "target_position": 3},
		{"enemy_position": 2, "type": "attack", "amount": 2, "target_position": 1},
	], "frayguard_attrition.json turn 2 intents must remain intact")
	_check(frayguard_intents.advance_turn(), "frayguard_attrition.json advance to turn 3")
	_check(frayguard_intents.get_intents() == [
		{"enemy_position": 1, "type": "attack", "amount": 2, "target_position": 2},
		{"enemy_position": 2, "type": "buff", "amount": 2},
	], "frayguard_attrition.json turn 3 intents must remain intact")
	_check(frayguard_intents.advance_turn(), "frayguard_attrition.json advance to turn 4 wrap")
	_check(frayguard_intents.get_intents() == [
		{"enemy_position": 1, "type": "debuff", "amount": 2, "target_position": 3, "status": "bleed"},
		{"enemy_position": 2, "type": "block", "amount": 4},
	], "frayguard_attrition.json turn 4 wrap must remain intact")
