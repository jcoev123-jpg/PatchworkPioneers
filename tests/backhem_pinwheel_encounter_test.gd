extends SceneTree

const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMIES_PATH := "res://data/enemies/run_enemies.json"
const BACKHEM_PINWHEEL_PATH := "res://data/encounters/backhem_pinwheel.json"
const STARTER_ATTACKS_PATH := "res://data/encounters/starter_attacks.json"
const SEAMWARD_TURNABOUT_PATH := "res://data/encounters/seamward_turnabout.json"

var _failures: Array[String] = []


func _init() -> void:
	_run_all()
	if not _failures.is_empty():
		for message in _failures:
			push_error(message)
		quit(1)
		return
	print("PASS backhem_pinwheel_encounter_test")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _read_text(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		_check(false, "Missing required file: " + path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_check(false, "Unable to open file: " + path)
		return null
	var text := file.get_as_text()
	file.close()
	return text


func _normalize_actor_record(raw: Variant, label: String) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var copy: Dictionary = raw.duplicate(true)
	if not copy.has("id") or not copy["id"] is String or String(copy["id"]).is_empty():
		return {}
	if not copy.has("name") or not copy["name"] is String or String(copy["name"]).is_empty():
		return {}
	if not copy.has("art_path") or not copy["art_path"] is String or String(copy["art_path"]).is_empty():
		return {}
	if not copy.has("max_hp"):
		return {}
	var max_hp = copy["max_hp"]
	if max_hp is int:
		if max_hp <= 0:
			return {}
	elif max_hp is float:
		if is_nan(max_hp) or is_inf(max_hp) or absf(max_hp) > 9007199254740991.0 or floorf(max_hp) != max_hp:
			return {}
		var coerced := int(max_hp)
		if coerced <= 0:
			return {}
		copy["max_hp"] = coerced
	else:
		return {}
	if typeof(copy["max_hp"]) != TYPE_INT:
		_check(false, label + " max_hp must normalize to TYPE_INT")
		return {}
	return copy


func _load_json_array(path: String) -> Array:
	var raw_text = _read_text(path)
	if not raw_text is String:
		return []
	var parser := JSON.new()
	if parser.parse(raw_text) != OK or not parser.data is Array:
		_check(false, "Failed to parse JSON array from " + path)
		return []
	return parser.data


func _find_unique_actor_by_id(catalog: Array, actor_id: String, label: String) -> Dictionary:
	var matches: Array[Dictionary] = []
	for entry in catalog:
		var normalized := _normalize_actor_record(entry, label + ":" + actor_id)
		if not normalized.is_empty() and normalized["id"] == actor_id:
			matches.append(normalized)
	_check(matches.size() == 1, "%s must contain exactly one valid entry for id '%s' (found %d)" % [label, actor_id, matches.size()])
	if matches.size() != 1:
		return {}
	return matches[0].duplicate(true)


func _find_unique_source_by_position(definitions: Array, enemy_position: int, label: String) -> Dictionary:
	var matches: Array[Dictionary] = []
	for entry in definitions:
		if entry is Dictionary and entry.get("enemy_position") is int and entry["enemy_position"] == enemy_position:
			matches.append(entry.duplicate(true))
	_check(matches.size() == 1, "%s must contain exactly one entry for enemy_position %d (found %d)" % [label, enemy_position, matches.size()])
	if matches.size() != 1:
		return {}
	return matches[0]


func _load_shipped_party_definitions() -> Array[Dictionary]:
	var raw_catalog := _load_json_array(PARTY_PATH)
	var before_snapshot := raw_catalog.duplicate(true)
	_check(raw_catalog.size() == 3, "starter_party.json must define the 3-hero starter party")
	var warden := _find_unique_actor_by_id(raw_catalog, "warden", "starter_party")
	var seamstress := _find_unique_actor_by_id(raw_catalog, "seamstress", "starter_party")
	var tinker := _find_unique_actor_by_id(raw_catalog, "tinker", "starter_party")
	_check(raw_catalog == before_snapshot, "Reading starter_party catalog must not mutate raw catalog")
	if warden.is_empty() or seamstress.is_empty() or tinker.is_empty():
		return []
	_check(raw_catalog[0] is Dictionary and raw_catalog[0].get("id") == "warden", "Warden must start in hero slot 1")
	_check(raw_catalog[1] is Dictionary and raw_catalog[1].get("id") == "seamstress", "Seamstress must start in hero slot 2")
	_check(raw_catalog[2] is Dictionary and raw_catalog[2].get("id") == "tinker", "Tinker must start in hero slot 3")
	_check(warden["name"] == "Warden" and warden["max_hp"] == 40 and warden["art_path"] == "res://assets/paper/heroes/warden.png", "Warden shipped stats must match contract")
	_check(seamstress["name"] == "Seamstress" and seamstress["max_hp"] == 30 and seamstress["art_path"] == "res://assets/paper/heroes/seamstress.png", "Seamstress shipped stats must match contract")
	_check(tinker["name"] == "Tinker" and tinker["max_hp"] == 26 and tinker["art_path"] == "res://assets/paper/heroes/tinker.png", "Tinker shipped stats must match contract")
	return [warden, seamstress, tinker]


func _load_shipped_enemy_definitions() -> Array[Dictionary]:
	var raw_catalog := _load_json_array(ENEMIES_PATH)
	var before_snapshot := raw_catalog.duplicate(true)
	_check(not raw_catalog.is_empty(), "run_enemies.json must not be empty")
	var fray := _find_unique_actor_by_id(raw_catalog, "fray_scavenger", "run_enemies")
	var guard := _find_unique_actor_by_id(raw_catalog, "button_guard", "run_enemies")
	var stalker := _find_unique_actor_by_id(raw_catalog, "spool_stalker", "run_enemies")
	_check(raw_catalog == before_snapshot, "Reading run_enemies catalog must not mutate raw catalog")
	if fray.is_empty() or guard.is_empty() or stalker.is_empty():
		return []
	_check(fray["name"] == "Fray Scavenger" and fray["max_hp"] == 14 and fray["art_path"] == "res://assets/paper/enemies/fray_scavenger.png", "Fray Scavenger shipped stats must match contract")
	_check(guard["name"] == "Button Guard" and guard["max_hp"] == 16 and guard["art_path"] == "res://assets/paper/enemies/button_guard.png", "Button Guard shipped stats must match contract")
	_check(stalker["name"] == "Spool Stalker" and stalker["max_hp"] == 14 and stalker["art_path"] == "res://assets/paper/enemies/spool_stalker.png", "Spool Stalker shipped stats must match contract")
	return [fray, guard, stalker]


func _parse_encounter_file(path: String) -> Array:
	var raw_text = _read_text(path)
	if not raw_text is String:
		return []
	var definitions := RunFightEncounterSelection._parse_schedule_text(raw_text)
	_check(not definitions.is_empty(), "Encounter schedule must parse via RunFightEncounterSelection._parse_schedule_text: " + path)
	return definitions


func _build_fixture() -> Dictionary:
	var party_defs := _load_shipped_party_definitions()
	var enemy_defs := _load_shipped_enemy_definitions()
	var schedule_defs := _parse_encounter_file(BACKHEM_PINWHEEL_PATH)
	var party := CombatParty.new(party_defs)
	var enemies := CombatEnemies.new(enemy_defs)
	var starting_block := CombatStartingBlock.new(party)
	var block_applied := starting_block.apply()
	var second_apply := starting_block.apply()
	var intents := CombatEnemyIntents.new(schedule_defs)
	_check(party.is_valid(), "CombatParty fixture must be valid")
	_check(enemies.is_valid(), "CombatEnemies fixture must be valid")
	_check(block_applied, "CombatStartingBlock must grant Warden +6 opening Block once")
	_check(not second_apply, "CombatStartingBlock must reject a second apply() on the same combat start")
	_check(intents.is_valid(), "CombatEnemyIntents fixture must be valid")
	return {
		"party": party,
		"enemies": enemies,
		"intents": intents,
		"starting_block": starting_block,
		"schedule_defs": schedule_defs,
	}


func _assert_action_field_types(action: Dictionary, label: String) -> void:
	_check(action.has("type") and typeof(action["type"]) == TYPE_STRING, label + " type must be TYPE_STRING")
	_check(action.has("amount") and typeof(action["amount"]) == TYPE_INT, label + " amount must be TYPE_INT")
	if action.has("target_position"):
		_check(typeof(action["target_position"]) == TYPE_INT, label + " target_position must be TYPE_INT")
	if action.has("direction"):
		_check(typeof(action["direction"]) == TYPE_INT, label + " direction must be TYPE_INT")
	if action.has("status"):
		_check(typeof(action["status"]) == TYPE_STRING, label + " status must be TYPE_STRING")
	if action.has("enemy_position"):
		_check(typeof(action["enemy_position"]) == TYPE_INT, label + " enemy_position must be TYPE_INT")


func _assert_hero_state(
		hero: Dictionary,
		expected_id: String,
		expected_name: String,
		expected_art_path: String,
		expected_position: int,
		expected_hp: int,
		expected_max_hp: int,
		expected_block: int,
		expected_statuses: Dictionary,
		label: String) -> void:
	_check(hero.get("id") == expected_id, "%s id expected '%s', got '%s'" % [label, expected_id, str(hero.get("id"))])
	_check(hero.get("name") == expected_name, "%s name expected '%s', got '%s'" % [label, expected_name, str(hero.get("name"))])
	_check(hero.get("art_path") == expected_art_path, "%s art_path expected '%s', got '%s'" % [label, expected_art_path, str(hero.get("art_path"))])
	_check(typeof(hero.get("position")) == TYPE_INT and hero.get("position") == expected_position, "%s position expected %d, got %s" % [label, expected_position, str(hero.get("position"))])
	_check(typeof(hero.get("hp")) == TYPE_INT and hero.get("hp") == expected_hp, "%s hp expected %d, got %s" % [label, expected_hp, str(hero.get("hp"))])
	_check(typeof(hero.get("max_hp")) == TYPE_INT and hero.get("max_hp") == expected_max_hp, "%s max_hp expected %d, got %s" % [label, expected_max_hp, str(hero.get("max_hp"))])
	_check(typeof(hero.get("block")) == TYPE_INT and hero.get("block") == expected_block, "%s block expected %d, got %s" % [label, expected_block, str(hero.get("block"))])
	var statuses: Dictionary = hero.get("statuses", {})
	_check(statuses == expected_statuses, "%s statuses expected %s, got %s" % [label, str(expected_statuses), str(statuses)])


func _assert_enemy_state(
		enemy: Dictionary,
		expected_id: String,
		expected_name: String,
		expected_art_path: String,
		expected_position: int,
		expected_hp: int,
		expected_max_hp: int,
		expected_block: int,
		expected_statuses: Dictionary,
		label: String) -> void:
	_check(enemy.get("id") == expected_id, "%s id expected '%s', got '%s'" % [label, expected_id, str(enemy.get("id"))])
	_check(enemy.get("name") == expected_name, "%s name expected '%s', got '%s'" % [label, expected_name, str(enemy.get("name"))])
	_check(enemy.get("art_path") == expected_art_path, "%s art_path expected '%s', got '%s'" % [label, expected_art_path, str(enemy.get("art_path"))])
	_check(typeof(enemy.get("position")) == TYPE_INT and enemy.get("position") == expected_position, "%s position expected %d, got %s" % [label, expected_position, str(enemy.get("position"))])
	_check(typeof(enemy.get("hp")) == TYPE_INT and enemy.get("hp") == expected_hp, "%s hp expected %d, got %s" % [label, expected_hp, str(enemy.get("hp"))])
	_check(typeof(enemy.get("max_hp")) == TYPE_INT and enemy.get("max_hp") == expected_max_hp, "%s max_hp expected %d, got %s" % [label, expected_max_hp, str(enemy.get("max_hp"))])
	_check(typeof(enemy.get("block")) == TYPE_INT and enemy.get("block") == expected_block, "%s block expected %d, got %s" % [label, expected_block, str(enemy.get("block"))])
	var statuses: Dictionary = enemy.get("statuses", {})
	_check(statuses == expected_statuses, "%s statuses expected %s, got %s" % [label, str(expected_statuses), str(statuses)])


func _run_all() -> void:
	_test_ac1_schedule_and_named_prior_encounters()
	_test_ac2_beat_0_and_per_beat_fixtures()
	_test_ac3_replay_rng_downed_slain_and_negatives()


func _test_ac1_schedule_and_named_prior_encounters() -> void:
	var party_defs := _load_shipped_party_definitions()
	var enemy_defs := _load_shipped_enemy_definitions()
	_check(party_defs.size() == 3, "AC1: shipped starter party definitions must load")
	_check(enemy_defs.size() == 3, "AC1: shipped 3-enemy roster definitions must load")

	# Fractional max_hp drift probe on actor normalization helper.
	var fractional_actor := _normalize_actor_record(
		{"id": "probe", "name": "Probe", "max_hp": 14.5, "art_path": "res://assets/paper/enemies/fray_scavenger.png"},
		"fractional_probe"
	)
	_check(fractional_actor.is_empty(), "AC1: actor normalization must reject non-integral float max_hp")

	var definitions := _parse_encounter_file(BACKHEM_PINWHEEL_PATH)
	_check(definitions.size() == 3, "AC1: backhem_pinwheel.json must contain 3 enemy source entries")

	var source_1 := _find_unique_source_by_position(definitions, 1, "backhem_pinwheel")
	var source_2 := _find_unique_source_by_position(definitions, 2, "backhem_pinwheel")
	var source_3 := _find_unique_source_by_position(definitions, 3, "backhem_pinwheel")

	var expected_pattern_1: Array[Dictionary] = [
		{"type": "shove", "amount": 0, "target_position": 3, "direction": -1},
		{"type": "attack", "amount": 2, "target_position": 1},
		{"type": "block", "amount": 2},
	]
	var expected_pattern_2: Array[Dictionary] = [
		{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed"},
		{"type": "buff", "amount": 3},
		{"type": "attack", "amount": 3, "target_position": 2},
	]
	var expected_pattern_3: Array[Dictionary] = [
		{"type": "attack", "amount": 3, "target_position": 3},
		{"type": "block", "amount": 1},
		{"type": "attack", "amount": 2, "target_position": 1},
	]

	_check(source_1.size() == 2 and typeof(source_1.get("enemy_position")) == TYPE_INT, "AC1: source 1 must have integral enemy_position and pattern")
	_check(source_2.size() == 2 and typeof(source_2.get("enemy_position")) == TYPE_INT, "AC1: source 2 must have integral enemy_position and pattern")
	_check(source_3.size() == 2 and typeof(source_3.get("enemy_position")) == TYPE_INT, "AC1: source 3 must have integral enemy_position and pattern")
	_check(source_1.get("pattern") == expected_pattern_1, "AC1: source 1 pattern must match exact authored beats")
	_check(source_2.get("pattern") == expected_pattern_2, "AC1: source 2 pattern must match exact authored beats")
	_check(source_3.get("pattern") == expected_pattern_3, "AC1: source 3 pattern must match exact authored beats")

	for src_idx in range(definitions.size()):
		var def: Dictionary = definitions[src_idx]
		var pat: Array = def.get("pattern", [])
		for beat_idx in range(pat.size()):
			_assert_action_field_types(pat[beat_idx], "AC1 source[%d] beat[%d]" % [src_idx, beat_idx])

	# Reverse-order construction still announces in source order 1, 2, 3.
	var reversed_defs: Array = [source_3.duplicate(true), source_1.duplicate(true), source_2.duplicate(true)]
	var reversed_intents := CombatEnemyIntents.new(reversed_defs)
	_check(reversed_intents.is_valid(), "AC1: CombatEnemyIntents must accept valid sources regardless of input order")

	var intents := CombatEnemyIntents.new(definitions)
	_check(intents.is_valid(), "AC1: CombatEnemyIntents must accept backhem_pinwheel definitions")

	var expected_beat_0: Array[Dictionary] = [
		{"enemy_position": 1, "type": "shove", "amount": 0, "target_position": 3, "direction": -1},
		{"enemy_position": 2, "type": "debuff", "amount": 2, "target_position": 2, "status": "bleed"},
		{"enemy_position": 3, "type": "attack", "amount": 3, "target_position": 3},
	]
	var expected_beat_1: Array[Dictionary] = [
		{"enemy_position": 1, "type": "attack", "amount": 2, "target_position": 1},
		{"enemy_position": 2, "type": "buff", "amount": 3},
		{"enemy_position": 3, "type": "block", "amount": 1},
	]
	var expected_beat_2: Array[Dictionary] = [
		{"enemy_position": 1, "type": "block", "amount": 2},
		{"enemy_position": 2, "type": "attack", "amount": 3, "target_position": 2},
		{"enemy_position": 3, "type": "attack", "amount": 2, "target_position": 1},
	]

	_check(reversed_intents.get_intents() == expected_beat_0, "AC1: reversed source input must still announce in slot order 1, 2, 3")

	var beat_0_first := intents.get_intents()
	var beat_0_second := intents.get_intents()
	_check(beat_0_first == expected_beat_0, "AC1: beat 0 announced intents must match expected source order 1,2,3")
	_check(beat_0_second == expected_beat_0, "AC1: repeated get_intents() at beat 0 must not advance turn")
	for entry in beat_0_first:
		_assert_action_field_types(entry, "AC1 beat 0 intent")

	# Verify get_intents() returns deep copies and does not alias internal state.
	beat_0_first[0]["amount"] = 999
	beat_0_first[0]["type"] = "attack"
	beat_0_first.clear()
	_check(intents.get_intents() == expected_beat_0, "AC1: mutating get_intents() result must not mutate internal schedule")

	_check(intents.advance_turn(), "AC1: advance_turn() from beat 0 to beat 1 must succeed")
	var beat_1 := intents.get_intents()
	_check(beat_1 == expected_beat_1, "AC1: beat 1 announced intents must match expected source order 1,2,3")
	for entry in beat_1:
		_assert_action_field_types(entry, "AC1 beat 1 intent")

	_check(intents.advance_turn(), "AC1: advance_turn() from beat 1 to beat 2 must succeed")
	var beat_2 := intents.get_intents()
	_check(beat_2 == expected_beat_2, "AC1: beat 2 announced intents must match expected source order 1,2,3")
	for entry in beat_2:
		_assert_action_field_types(entry, "AC1 beat 2 intent")

	_check(intents.advance_turn(), "AC1: advance_turn() from beat 2 to beat 3 (wraparound) must succeed")
	var beat_3_wrap := intents.get_intents()
	_check(beat_3_wrap == expected_beat_0, "AC1: beat index 3 must wrap around to beat 0")

	# Named prior schedules starter_attacks and seamward_turnabout still parse and validate by enemy_position.
	var starter_defs := _parse_encounter_file(STARTER_ATTACKS_PATH)
	var starter_intents := CombatEnemyIntents.new(starter_defs)
	_check(starter_intents.is_valid(), "AC1: starter_attacks.json must remain valid in CombatEnemyIntents")
	var starter_pos_1 := _find_unique_source_by_position(starter_defs, 1, "starter_attacks")
	var starter_pos_2 := _find_unique_source_by_position(starter_defs, 2, "starter_attacks")
	var expected_starter_1: Array[Dictionary] = [
		{"type": "attack", "amount": 1, "target_position": 1},
		{"type": "attack", "amount": 1, "target_position": 2},
		{"type": "attack", "amount": 1, "target_position": 3},
	]
	var expected_starter_2: Array[Dictionary] = [
		{"type": "block", "amount": 1},
	]
	_check(starter_pos_1.get("pattern") == expected_starter_1, "AC1: starter_attacks enemy_position 1 pattern must remain intact")
	_check(starter_pos_2.get("pattern") == expected_starter_2, "AC1: starter_attacks enemy_position 2 pattern must remain intact")

	var seamward_defs := _parse_encounter_file(SEAMWARD_TURNABOUT_PATH)
	var seamward_intents := CombatEnemyIntents.new(seamward_defs)
	_check(seamward_intents.is_valid(), "AC1: seamward_turnabout.json must remain valid in CombatEnemyIntents")
	var seamward_pos_1 := _find_unique_source_by_position(seamward_defs, 1, "seamward_turnabout")
	var seamward_pos_2 := _find_unique_source_by_position(seamward_defs, 2, "seamward_turnabout")
	var expected_seamward_1: Array[Dictionary] = [
		{"type": "shove", "amount": 0, "target_position": 2, "direction": -1},
		{"type": "attack", "amount": 3, "target_position": 1},
		{"type": "block", "amount": 2},
	]
	var expected_seamward_2: Array[Dictionary] = [
		{"type": "attack", "amount": 4, "target_position": 1},
		{"type": "buff", "amount": 3},
		{"type": "attack", "amount": 3, "target_position": 3},
	]
	_check(seamward_pos_1.get("pattern") == expected_seamward_1, "AC1: seamward_turnabout enemy_position 1 pattern must remain intact")
	_check(seamward_pos_2.get("pattern") == expected_seamward_2, "AC1: seamward_turnabout enemy_position 2 pattern must remain intact")


func _test_ac2_beat_0_and_per_beat_fixtures() -> void:
	# Beat 0 fixture
	var fixture_0 := _build_fixture()
	var party_0: CombatParty = fixture_0["party"]
	var enemies_0: CombatEnemies = fixture_0["enemies"]
	var intents_0: CombatEnemyIntents = fixture_0["intents"]

	# Precondition check before beat 0
	_assert_hero_state(party_0.get_hero(1), "warden", "Warden", "res://assets/paper/heroes/warden.png", 1, 40, 40, 6, {}, "AC2 beat 0 pre slot 1")
	_assert_hero_state(party_0.get_hero(2), "seamstress", "Seamstress", "res://assets/paper/heroes/seamstress.png", 2, 30, 30, 0, {}, "AC2 beat 0 pre slot 2")
	_assert_hero_state(party_0.get_hero(3), "tinker", "Tinker", "res://assets/paper/heroes/tinker.png", 3, 26, 26, 0, {}, "AC2 beat 0 pre slot 3")

	var announced_0 := intents_0.get_intents()
	var phase := CombatEnemyPhase.new()
	var result_0 := phase.execute_phase(party_0, enemies_0, announced_0)
	var expected_events_0: Array[Dictionary] = [
		{"type": "shove", "enemy_position": 1, "target_position": 3, "direction": -1, "applied": true},
		{"type": "debuff", "enemy_position": 2, "target_position": 2, "status": "bleed", "applied": true},
		{"type": "attack", "enemy_position": 3, "target_position": 3, "applied": true},
	]
	_check(result_0.get("ok") == true, "AC2: beat 0 execute_phase must succeed")
	_check(result_0.get("events") == expected_events_0, "AC2: beat 0 events must match exact source-ordered shove, debuff, attack")
	_check(intents_0.get_intents() == announced_0, "AC2: CombatEnemyPhase must not advance CombatEnemyIntents")

	# After beat 0:
	# Slot 1: Warden (40 HP, 6 Block, no statuses)
	# Slot 2: Tinker (moved from 3 to 2 by shove, 26 HP, 0 Block, bleed: 2; enemy phase does not age Bleed)
	# Slot 3: Seamstress (moved from 2 to 3 by shove, then hit by attack 3 -> 27 HP, 0 Block, no statuses)
	var heroes_after_0 := party_0.get_heroes()
	_check(heroes_after_0.size() == 3, "AC2: party size must remain 3 after beat 0")
	_assert_hero_state(party_0.get_hero(1), "warden", "Warden", "res://assets/paper/heroes/warden.png", 1, 40, 40, 6, {}, "AC2 beat 0 post slot 1")
	_assert_hero_state(party_0.get_hero(2), "tinker", "Tinker", "res://assets/paper/heroes/tinker.png", 2, 26, 26, 0, {"bleed": 2}, "AC2 beat 0 post slot 2")
	_assert_hero_state(party_0.get_hero(3), "seamstress", "Seamstress", "res://assets/paper/heroes/seamstress.png", 3, 27, 30, 0, {}, "AC2 beat 0 post slot 3")
	_check(heroes_after_0[0] == party_0.get_hero(1) and heroes_after_0[1] == party_0.get_hero(2) and heroes_after_0[2] == party_0.get_hero(3), "AC2: get_heroes() must match per-slot get_hero() snapshots after beat 0")

	_assert_enemy_state(enemies_0.get_enemy(1), "fray_scavenger", "Fray Scavenger", "res://assets/paper/enemies/fray_scavenger.png", 1, 14, 14, 0, {}, "AC2 beat 0 post enemy 1")
	_assert_enemy_state(enemies_0.get_enemy(2), "button_guard", "Button Guard", "res://assets/paper/enemies/button_guard.png", 2, 16, 16, 0, {}, "AC2 beat 0 post enemy 2")
	_assert_enemy_state(enemies_0.get_enemy(3), "spool_stalker", "Spool Stalker", "res://assets/paper/enemies/spool_stalker.png", 3, 14, 14, 0, {}, "AC2 beat 0 post enemy 3")

	# Separate clean fresh fixture for Beat 1
	var fixture_1 := _build_fixture()
	var party_1: CombatParty = fixture_1["party"]
	var enemies_1: CombatEnemies = fixture_1["enemies"]
	var intents_1: CombatEnemyIntents = fixture_1["intents"]
	_check(intents_1.advance_turn(), "AC2: advancing schedule to beat 1 must succeed")

	var announced_1 := intents_1.get_intents()
	var result_1 := phase.execute_phase(party_1, enemies_1, announced_1)
	var expected_events_1: Array[Dictionary] = [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
		{"type": "buff", "enemy_position": 2, "applied": true},
		{"type": "block", "enemy_position": 3, "applied": true},
	]
	_check(result_1.get("ok") == true, "AC2: beat 1 execute_phase must succeed")
	_check(result_1.get("events") == expected_events_1, "AC2: beat 1 events must match attack, buff, block")

	_assert_hero_state(party_1.get_hero(1), "warden", "Warden", "res://assets/paper/heroes/warden.png", 1, 40, 40, 4, {}, "AC2 beat 1 post slot 1")
	_assert_hero_state(party_1.get_hero(2), "seamstress", "Seamstress", "res://assets/paper/heroes/seamstress.png", 2, 30, 30, 0, {}, "AC2 beat 1 post slot 2")
	_assert_hero_state(party_1.get_hero(3), "tinker", "Tinker", "res://assets/paper/heroes/tinker.png", 3, 26, 26, 0, {}, "AC2 beat 1 post slot 3")

	_assert_enemy_state(enemies_1.get_enemy(1), "fray_scavenger", "Fray Scavenger", "res://assets/paper/enemies/fray_scavenger.png", 1, 14, 14, 0, {}, "AC2 beat 1 post enemy 1")
	_assert_enemy_state(enemies_1.get_enemy(2), "button_guard", "Button Guard", "res://assets/paper/enemies/button_guard.png", 2, 16, 16, 3, {}, "AC2 beat 1 post enemy 2")
	_assert_enemy_state(enemies_1.get_enemy(3), "spool_stalker", "Spool Stalker", "res://assets/paper/enemies/spool_stalker.png", 3, 14, 14, 1, {}, "AC2 beat 1 post enemy 3")

	# Separate clean fresh fixture for Beat 2
	var fixture_2 := _build_fixture()
	var party_2: CombatParty = fixture_2["party"]
	var enemies_2: CombatEnemies = fixture_2["enemies"]
	var intents_2: CombatEnemyIntents = fixture_2["intents"]
	_check(intents_2.advance_turn(), "AC2: advancing schedule to beat 1 for beat 2 fixture must succeed")
	_check(intents_2.advance_turn(), "AC2: advancing schedule to beat 2 must succeed")

	var announced_2 := intents_2.get_intents()
	var result_2 := phase.execute_phase(party_2, enemies_2, announced_2)
	var expected_events_2: Array[Dictionary] = [
		{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true},
		{"type": "attack", "enemy_position": 3, "target_position": 1, "applied": true},
	]
	_check(result_2.get("ok") == true, "AC2: beat 2 execute_phase must succeed")
	_check(result_2.get("events") == expected_events_2, "AC2: beat 2 events must match block, attack slot 2, attack slot 1")

	_assert_hero_state(party_2.get_hero(1), "warden", "Warden", "res://assets/paper/heroes/warden.png", 1, 40, 40, 4, {}, "AC2 beat 2 post slot 1")
	_assert_hero_state(party_2.get_hero(2), "seamstress", "Seamstress", "res://assets/paper/heroes/seamstress.png", 2, 27, 30, 0, {}, "AC2 beat 2 post slot 2")
	_assert_hero_state(party_2.get_hero(3), "tinker", "Tinker", "res://assets/paper/heroes/tinker.png", 3, 26, 26, 0, {}, "AC2 beat 2 post slot 3")

	_assert_enemy_state(enemies_2.get_enemy(1), "fray_scavenger", "Fray Scavenger", "res://assets/paper/enemies/fray_scavenger.png", 1, 14, 14, 2, {}, "AC2 beat 2 post enemy 1")
	_assert_enemy_state(enemies_2.get_enemy(2), "button_guard", "Button Guard", "res://assets/paper/enemies/button_guard.png", 2, 16, 16, 0, {}, "AC2 beat 2 post enemy 2")
	_assert_enemy_state(enemies_2.get_enemy(3), "spool_stalker", "Spool Stalker", "res://assets/paper/enemies/spool_stalker.png", 3, 14, 14, 0, {}, "AC2 beat 2 post enemy 3")


func _run_single_replay_trace(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var initial_rng_state := rng.state

	var trace_announcements: Array = []
	var trace_events: Array = []
	var trace_heroes: Array = []
	var trace_enemies: Array = []

	var cycle_intents := CombatEnemyIntents.new(_parse_encounter_file(BACKHEM_PINWHEEL_PATH))
	var phase := CombatEnemyPhase.new()

	for beat in range(4):
		var beat_fixture := _build_fixture()
		var beat_party: CombatParty = beat_fixture["party"]
		var beat_enemies: CombatEnemies = beat_fixture["enemies"]
		var announced := cycle_intents.get_intents()
		var outcome := phase.execute_phase(beat_party, beat_enemies, announced)
		trace_announcements.append(announced)
		trace_events.append(outcome)
		trace_heroes.append(beat_party.get_heroes())
		trace_enemies.append(beat_enemies.get_enemies())
		_check(cycle_intents.advance_turn(), "AC3: cycle_intents.advance_turn() must succeed at beat %d" % beat)

	var final_rng_state := rng.state
	var next_draw := rng.randi()
	return {
		"initial_rng_state": initial_rng_state,
		"final_rng_state": final_rng_state,
		"next_draw": next_draw,
		"announcements": trace_announcements,
		"events": trace_events,
		"heroes": trace_heroes,
		"enemies": trace_enemies,
	}


func _test_ac3_replay_rng_downed_slain_and_negatives() -> void:
	# 1. Prove global RNG probe catches an extra draw (Lesson 15), then verify zero global/local RNG draws across replay.
	var global_seed := 1792586022
	seed(global_seed)
	var expected_global_draw := randi()
	seed(global_seed)
	var _injected_draw := randi()
	_check(randi() != expected_global_draw, "AC3: global RNG probe must detect an injected randi() draw")

	seed(global_seed)
	var trace_a := _run_single_replay_trace(global_seed)
	_check(randi() == expected_global_draw, "AC3: replay trace A must not consume global RNG")

	seed(global_seed)
	var trace_b := _run_single_replay_trace(global_seed)
	_check(randi() == expected_global_draw, "AC3: replay trace B must not consume global RNG")

	var reference_rng := RandomNumberGenerator.new()
	reference_rng.seed = global_seed
	var expected_local_draw := reference_rng.randi()

	_check(trace_a["initial_rng_state"] == trace_a["final_rng_state"], "AC3: trace A must leave seeded RNG state untouched")
	_check(trace_b["initial_rng_state"] == trace_b["final_rng_state"], "AC3: trace B must leave seeded RNG state untouched")
	_check(trace_a["next_draw"] == expected_local_draw and trace_b["next_draw"] == expected_local_draw, "AC3: seeded RNG first draw after trace must equal untouched reference draw")
	_check(trace_a == trace_b, "AC3: two independent fresh fixtures must replay identically across all beats and wraparound")
	# Beat 3 wraparound in trace matches beat 0
	_check(trace_a["announcements"][3] == trace_a["announcements"][0], "AC3: beat 3 announcement must equal beat 0 announcement")
	_check(trace_a["events"][3] == trace_a["events"][0], "AC3: beat 3 phase outcome must equal beat 0 phase outcome")
	_check(trace_a["heroes"][3] == trace_a["heroes"][0], "AC3: beat 3 hero snapshot must equal beat 0 hero snapshot")
	_check(trace_a["enemies"][3] == trace_a["enemies"][0], "AC3: beat 3 enemy snapshot must equal beat 0 enemy snapshot")

	# 2. Downed rear Tinker before beat 0 rejects the entire phase with no changed party, enemies, intent index, or RNG.
	var downed_fixture := _build_fixture()
	var downed_party: CombatParty = downed_fixture["party"]
	var downed_enemies: CombatEnemies = downed_fixture["enemies"]
	var downed_intents: CombatEnemyIntents = downed_fixture["intents"]

	_check(downed_party.apply_damage(3, 26), "AC3: applying 26 damage to rear Tinker must succeed")
	_check(downed_party.is_downed(3), "AC3: rear Tinker at slot 3 must be downed (0 HP)")
	_check(not downed_party.is_defeated(), "AC3: party with living Warden and Seamstress must not be defeated")

	var party_before_downed := downed_party.get_heroes()
	var enemies_before_downed := downed_enemies.get_enemies()
	var intents_before_downed := downed_intents.get_intents()
	var downed_rng := RandomNumberGenerator.new()
	downed_rng.seed = 424242
	var downed_rng_state_before := downed_rng.state
	seed(global_seed)

	var downed_result := CombatEnemyPhase.new().execute_phase(downed_party, downed_enemies, intents_before_downed)
	_check(downed_result == {"ok": false, "events": []}, "AC3: execute_phase with downed rear Tinker on beat 0 must return {ok: false, events: []}")
	_check(downed_party.get_heroes() == party_before_downed, "AC3: rejected beat 0 phase must not mutate party state")
	_check(downed_enemies.get_enemies() == enemies_before_downed, "AC3: rejected beat 0 phase must not mutate enemy state")
	_check(downed_intents.get_intents() == intents_before_downed, "AC3: rejected beat 0 phase must not advance or mutate intent schedule")
	_check(downed_rng.state == downed_rng_state_before, "AC3: rejected beat 0 phase must not consume seeded RNG")
	_check(randi() == expected_global_draw, "AC3: rejected beat 0 phase must not consume global RNG")

	# Atomic rollback when source 1 shove succeeds on staging but a later source fails (Lesson 40).
	var rollback_fixture := _build_fixture()
	var rollback_party: CombatParty = rollback_fixture["party"]
	var rollback_enemies: CombatEnemies = rollback_fixture["enemies"]
	_check(rollback_party.apply_damage(1, 46), "AC3: downing front Warden (40 HP + 6 Block) for later-source rollback check must succeed")
	_check(rollback_party.is_downed(1), "AC3: front Warden must be downed for later-source rollback check")
	var rollback_party_before := rollback_party.get_heroes()
	var rollback_enemies_before := rollback_enemies.get_enemies()
	var staged_then_fail_intents: Array[Dictionary] = [
		{"enemy_position": 1, "type": "shove", "amount": 0, "target_position": 3, "direction": -1},
		{"enemy_position": 2, "type": "debuff", "amount": 2, "target_position": 2, "status": "bleed"},
		{"enemy_position": 3, "type": "debuff", "amount": 1, "target_position": 1, "status": "bleed"},
	]
	var rollback_result := CombatEnemyPhase.new().execute_phase(rollback_party, rollback_enemies, staged_then_fail_intents)
	_check(rollback_result == {"ok": false, "events": []}, "AC3: failure at source 3 after staged source 1 shove and source 2 debuff must fail atomically")
	_check(rollback_party.get_heroes() == rollback_party_before, "AC3: atomic failure at source 3 must roll back staged source 1 swap and source 2 debuff")
	_check(rollback_enemies.get_enemies() == rollback_enemies_before, "AC3: atomic failure at source 3 must leave enemies unchanged")

	# 3. Slain source-1 Fray Scavenger before beat 0 skips shove; Bleed 2 hits original middle Seamstress and source 3 attacks original rear Tinker (26 -> 23).
	var slain_fixture := _build_fixture()
	var slain_party: CombatParty = slain_fixture["party"]
	var slain_enemies: CombatEnemies = slain_fixture["enemies"]
	var slain_intents: CombatEnemyIntents = slain_fixture["intents"]

	_check(slain_enemies.apply_damage(1, 14), "AC3: applying 14 damage to slot-1 Fray Scavenger must succeed")
	_check(slain_enemies.is_slain(1) and slain_enemies.is_dead(1), "AC3: slot-1 Fray Scavenger must be slain")
	_check(not slain_enemies.is_slain(2) and not slain_enemies.is_slain(3), "AC3: slots 2 and 3 must remain alive")
	_check(not slain_enemies.is_defeated() and not slain_enemies.is_victorious(), "AC3: enemy roster with living slots 2 and 3 must not be defeated")

	var slain_result := CombatEnemyPhase.new().execute_phase(slain_party, slain_enemies, slain_intents.get_intents())
	var expected_slain_events: Array[Dictionary] = [
		{"type": "shove", "enemy_position": 1, "target_position": 3, "direction": -1, "applied": false},
		{"type": "debuff", "enemy_position": 2, "target_position": 2, "status": "bleed", "applied": true},
		{"type": "attack", "enemy_position": 3, "target_position": 3, "applied": true},
	]
	_check(slain_result.get("ok") == true, "AC3: beat 0 with slain slot-1 enemy must succeed")
	_check(slain_result.get("events") == expected_slain_events, "AC3: slain slot-1 shove must record applied=false while slots 2 and 3 apply")

	_assert_hero_state(slain_party.get_hero(1), "warden", "Warden", "res://assets/paper/heroes/warden.png", 1, 40, 40, 6, {}, "AC3 slain slot-1 post hero 1")
	_assert_hero_state(slain_party.get_hero(2), "seamstress", "Seamstress", "res://assets/paper/heroes/seamstress.png", 2, 30, 30, 0, {"bleed": 2}, "AC3 slain slot-1 post hero 2")
	_assert_hero_state(slain_party.get_hero(3), "tinker", "Tinker", "res://assets/paper/heroes/tinker.png", 3, 23, 26, 0, {}, "AC3 slain slot-1 post hero 3")

	_assert_enemy_state(slain_enemies.get_enemy(1), "fray_scavenger", "Fray Scavenger", "res://assets/paper/enemies/fray_scavenger.png", 1, 0, 14, 0, {}, "AC3 slain slot-1 post enemy 1")
	_assert_enemy_state(slain_enemies.get_enemy(2), "button_guard", "Button Guard", "res://assets/paper/enemies/button_guard.png", 2, 16, 16, 0, {}, "AC3 slain slot-1 post enemy 2")
	_assert_enemy_state(slain_enemies.get_enemy(3), "spool_stalker", "Spool Stalker", "res://assets/paper/enemies/spool_stalker.png", 3, 14, 14, 0, {}, "AC3 slain slot-1 post enemy 3")

	# 4. Parser and validator rejection for off-board shove, duplicate enemy_position, unsupported debuff status, and fractional numbers; positive control remains valid.
	var valid_raw_text := String(_read_text(BACKHEM_PINWHEEL_PATH))
	var valid_before := RunFightEncounterSelection._parse_schedule_text(valid_raw_text)
	_check(valid_before.size() == 3, "AC3: positive control schedule must parse before negative probes")

	var off_board_shove_json := JSON.stringify([
		{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 3, "direction": 1}]},
		{"enemy_position": 2, "pattern": [{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed"}]},
		{"enemy_position": 3, "pattern": [{"type": "attack", "amount": 3, "target_position": 3}]},
	])
	var off_board_intents := CombatEnemyIntents.new([
		{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 3, "direction": 1}]},
		{"enemy_position": 2, "pattern": [{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed"}]},
		{"enemy_position": 3, "pattern": [{"type": "attack", "amount": 3, "target_position": 3}]},
	])
	_check(RunFightEncounterSelection._parse_schedule_text(off_board_shove_json).is_empty(), "AC3: _parse_schedule_text must reject off-board shove (position 3, direction +1)")
	_check(not off_board_intents.is_valid() and off_board_intents.get_intents().is_empty() and not off_board_intents.advance_turn(), "AC3: CombatEnemyIntents must reject off-board shove (position 3, direction +1)")

	var duplicate_slot_json := JSON.stringify([
		{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 3, "direction": -1}]},
		{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed"}]},
		{"enemy_position": 3, "pattern": [{"type": "attack", "amount": 3, "target_position": 3}]},
	])
	var duplicate_slot_intents := CombatEnemyIntents.new([
		{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 3, "direction": -1}]},
		{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed"}]},
		{"enemy_position": 3, "pattern": [{"type": "attack", "amount": 3, "target_position": 3}]},
	])
	_check(RunFightEncounterSelection._parse_schedule_text(duplicate_slot_json).is_empty(), "AC3: _parse_schedule_text must reject duplicate enemy_position")
	_check(not duplicate_slot_intents.is_valid() and duplicate_slot_intents.get_intents().is_empty() and not duplicate_slot_intents.advance_turn(), "AC3: CombatEnemyIntents must reject duplicate enemy_position")

	var unknown_status_json := JSON.stringify([
		{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 3, "direction": -1}]},
		{"enemy_position": 2, "pattern": [{"type": "debuff", "amount": 2, "target_position": 2, "status": "poison"}]},
		{"enemy_position": 3, "pattern": [{"type": "attack", "amount": 3, "target_position": 3}]},
	])
	var unknown_status_intents := CombatEnemyIntents.new([
		{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 3, "direction": -1}]},
		{"enemy_position": 2, "pattern": [{"type": "debuff", "amount": 2, "target_position": 2, "status": "poison"}]},
		{"enemy_position": 3, "pattern": [{"type": "attack", "amount": 3, "target_position": 3}]},
	])
	_check(RunFightEncounterSelection._parse_schedule_text(unknown_status_json).is_empty(), "AC3: _parse_schedule_text must reject unsupported debuff status")
	_check(not unknown_status_intents.is_valid() and unknown_status_intents.get_intents().is_empty() and not unknown_status_intents.advance_turn(), "AC3: CombatEnemyIntents must reject unsupported debuff status")

	var fractional_amount_json := "[{\"enemy_position\":1,\"pattern\":[{\"type\":\"attack\",\"amount\":2.5,\"target_position\":1}]}]"
	_check(RunFightEncounterSelection._parse_schedule_text(fractional_amount_json).is_empty(), "AC3: _parse_schedule_text must reject fractional amount in JSON")

	var valid_after := RunFightEncounterSelection._parse_schedule_text(valid_raw_text)
	var valid_after_intents := CombatEnemyIntents.new(valid_after)
	_check(valid_after == valid_before and valid_after_intents.is_valid(), "AC3: positive control backhem_pinwheel.json must remain valid after negative probes")
