extends SceneTree
const WEIGHTED = preload("res://tests/weighted_roster_assert.gd")

const HEMDRAG_PATH := "res://data/encounters/hemdrag_relay.json"
const STARTER_ATTACKS_PATH := "res://data/encounters/starter_attacks.json"
const SPOOL_SNARE_PATH := "res://data/encounters/spool_snare_relay.json"
const RUN_ENEMIES_PATH := "res://data/enemies/run_enemies.json"
const STARTER_PARTY_PATH := "res://data/heroes/starter_party.json"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_ac1_catalog_and_schedule_validation()
	_test_ac2_three_beat_execution_and_detached_bleed_tick()
	_test_ac3_downed_shove_rejection_slain_skip_and_malformed_failures()
	_test_ac4_two_seeded_fixtures_replay_and_zero_rng_drift()
	if failures.is_empty():
		print("hemdrag_relay_encounter_test: PASS (", checks, " checks)")
	else:
		for message in failures:
			printerr(message)
		print("hemdrag_relay_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _is_integral_number(value: Variant) -> bool:
	if value is int:
		return true
	if value is float and not is_nan(value) and not is_inf(value):
		return absf(value) <= 9007199254740991.0 and floorf(value) == value
	return false


func _read_text(path: String, label: String) -> String:
	_check(FileAccess.file_exists(path), label + ": file exists at " + path)
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, label + ": file opens at " + path)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	_check(not text.strip_edges().is_empty(), label + ": file is non-empty")
	return text


func _load_json_array(path: String, label: String) -> Array:
	var text := _read_text(path, label)
	if text.is_empty():
		return []
	var parser := JSON.new()
	_check(parser.parse(text) == OK, label + ": valid JSON syntax")
	_check(parser.data is Array and not (parser.data as Array).is_empty(),
		label + ": top-level JSON is a non-empty Array")
	if not parser.data is Array:
		return []
	return (parser.data as Array).duplicate(true)


func _find_unique_record_by_id(catalog: Array, target_id: String, label: String) -> Dictionary:
	var matches: Array[Dictionary] = []
	for entry in catalog:
		_check(entry is Dictionary, label + ": catalog entry is Dictionary")
		if entry is Dictionary and entry.get("id") == target_id:
			var copy: Dictionary = (entry as Dictionary).duplicate(true)
			_check(_is_integral_number(copy.get("max_hp")),
				label + " (" + target_id + "): max_hp is integral before int conversion")
			if _is_integral_number(copy.get("max_hp")):
				copy["max_hp"] = int(copy["max_hp"])
			matches.append(copy)
	_check(matches.size() == 1,
		label + ": exactly one record matches id '" + target_id + "'")
	if matches.size() != 1:
		return {}
	return matches[0]


func _find_unique_source(definitions: Array, enemy_position: int, label: String) -> Dictionary:
	var matches: Array[Dictionary] = []
	for entry in definitions:
		_check(entry is Dictionary, label + ": schedule entry is Dictionary")
		if entry is Dictionary and entry.get("enemy_position") == enemy_position:
			matches.append((entry as Dictionary).duplicate(true))
	_check(matches.size() == 1,
		label + ": exactly one schedule record for enemy_position " + str(enemy_position))
	if matches.size() != 1:
		return {}
	return matches[0]


func _expected_hemdrag_definitions() -> Array:
	return [
		{
			"enemy_position": 1,
			"pattern": [
				{"type": "debuff", "amount": 1, "target_position": 2, "status": "bleed"},
				{"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
				{"type": "attack", "amount": 3, "target_position": 2},
			],
		},
		{
			"enemy_position": 2,
			"pattern": [
				{"type": "block", "amount": 2},
				{"type": "attack", "amount": 3, "target_position": 3},
				{"type": "buff", "amount": 3},
			],
		},
	]


func _expected_starter_attacks_definitions() -> Array:
	return [
		{
			"enemy_position": 1,
			"pattern": [
				{"type": "attack", "amount": 1, "target_position": 1},
				{"type": "attack", "amount": 1, "target_position": 2},
				{"type": "attack", "amount": 1, "target_position": 3},
			],
		},
		{
			"enemy_position": 2,
			"pattern": [
				{"type": "block", "amount": 1},
			],
		},
	]


func _expected_spool_snare_definitions() -> Array:
	return [
		{
			"enemy_position": 1,
			"pattern": [
				{"type": "debuff", "amount": 2, "target_position": 1, "status": "exposed"},
				{"type": "attack", "amount": 3, "target_position": 1},
				{"type": "attack", "amount": 2, "target_position": 3},
			],
		},
		{
			"enemy_position": 2,
			"pattern": [
				{"type": "attack", "amount": 2, "target_position": 2},
				{"type": "debuff", "amount": 2, "target_position": 3, "status": "weak"},
				{"type": "block", "amount": 2},
			],
		},
	]


func _expected_hemdrag_beat_intents(beat_index: int) -> Array[Dictionary]:
	match beat_index % 3:
		0:
			return [
				{"type": "debuff", "amount": 1, "target_position": 2, "status": "bleed", "enemy_position": 1},
				{"type": "block", "amount": 2, "enemy_position": 2},
			]
		1:
			return [
				{"type": "shove", "amount": 0, "target_position": 2, "direction": 1, "enemy_position": 1},
				{"type": "attack", "amount": 3, "target_position": 3, "enemy_position": 2},
			]
		_:
			return [
				{"type": "attack", "amount": 3, "target_position": 2, "enemy_position": 1},
				{"type": "buff", "amount": 3, "enemy_position": 2},
			]


func _assert_all_numeric_fields_are_int(definitions: Array, label: String) -> void:
	for definition in definitions:
		_check(definition is Dictionary, label + ": definition is Dictionary")
		if not definition is Dictionary:
			continue
		_check(typeof(definition.get("enemy_position")) == TYPE_INT,
			label + ": enemy_position is TYPE_INT")
		var pattern: Variant = definition.get("pattern", [])
		_check(pattern is Array and not (pattern as Array).is_empty(),
			label + ": pattern is non-empty Array")
		if not pattern is Array:
			continue
		for action in pattern:
			_check(action is Dictionary, label + ": action is Dictionary")
			if not action is Dictionary:
				continue
			_check(typeof(action.get("amount")) == TYPE_INT,
				label + ": action amount is TYPE_INT")
			if action.has("target_position"):
				_check(typeof(action.get("target_position")) == TYPE_INT,
					label + ": action target_position is TYPE_INT")
			if action.has("direction"):
				_check(typeof(action.get("direction")) == TYPE_INT,
					label + ": action direction is TYPE_INT")


func _load_canonical_party_definitions() -> Array[Dictionary]:
	var raw_party := _load_json_array(STARTER_PARTY_PATH, "starter_party.json")
	_check(raw_party.size() == 3, "starter_party.json has 3 ordered hero records")
	var warden := _find_unique_record_by_id(raw_party, "warden", "starter_party")
	var seamstress := _find_unique_record_by_id(raw_party, "seamstress", "starter_party")
	var tinker := _find_unique_record_by_id(raw_party, "tinker", "starter_party")
	_check(warden == {
		"id": "warden",
		"name": "Warden",
		"max_hp": 40,
		"art_path": "res://assets/paper/heroes/warden.png",
	}, "starter_party: Warden record matches canonical 40 HP definition")
	_check(seamstress == {
		"id": "seamstress",
		"name": "Seamstress",
		"max_hp": 30,
		"art_path": "res://assets/paper/heroes/seamstress.png",
	}, "starter_party: Seamstress record matches canonical 30 HP definition")
	_check(tinker == {
		"id": "tinker",
		"name": "Tinker",
		"max_hp": 26,
		"art_path": "res://assets/paper/heroes/tinker.png",
	}, "starter_party: Tinker record matches canonical 26 HP definition")
	if raw_party.size() == 3:
		_check((raw_party[0] as Dictionary).get("id") == "warden"
			and (raw_party[1] as Dictionary).get("id") == "seamstress"
			and (raw_party[2] as Dictionary).get("id") == "tinker",
			"starter_party: authored order is Warden (1), Seamstress (2), Tinker (3)")
	return [warden, seamstress, tinker]


func _load_hemdrag_enemy_definitions() -> Array[Dictionary]:
	var raw_enemies := _load_json_array(RUN_ENEMIES_PATH, "run_enemies.json")
	var seam_ripper := _find_unique_record_by_id(raw_enemies, "seam_ripper", "run_enemies")
	var button_guard := _find_unique_record_by_id(raw_enemies, "button_guard", "run_enemies")
	_check(WEIGHTED.project(seam_ripper) == {
		"id": "seam_ripper",
		"name": "Seam Ripper",
		"max_hp": 18,
		"art_path": "res://assets/paper/enemies/seam_ripper.png",
	}, "run_enemies: Seam Ripper matches canonical 18 HP and art_path")
	_check(WEIGHTED.project(button_guard) == {
		"id": "button_guard",
		"name": "Button Guard",
		"max_hp": 16,
		"art_path": "res://assets/paper/enemies/button_guard.png",
	}, "run_enemies: Button Guard matches canonical 16 HP and art_path")
	return [seam_ripper, button_guard]


func _enter_opening_fight(map: RunMap, label: String) -> String:
	for node_id in map.get_legal_choices():
		if map.get_node(node_id).get("type") == "Fight":
			_check(map.choose_node(node_id), label + ": chooses legal opening Fight node")
			_check(map.get_current_node_id() == node_id
				and map.get_node(node_id).get("type") == "Fight",
				label + ": chosen node is current Fight")
			return node_id
	_check(false, label + ": expected at least one legal opening Fight node")
	return ""


func _verify_named_encounter_schedule(
		path: String, expected_definitions: Array, label: String) -> void:
	var raw_text := _read_text(path, label)
	var parsed := RunFightEncounterSelection._parse_schedule_text(raw_text)
	_check(not parsed.is_empty(), label + ": canonical parser accepts schedule text")
	_assert_all_numeric_fields_are_int(parsed, label)
	_check(parsed.size() == expected_definitions.size(),
		label + ": expected source count matches")
	for expected_source in expected_definitions:
		var pos: int = expected_source["enemy_position"]
		var actual_source := _find_unique_source(parsed, pos, label)
		_check(actual_source == expected_source,
			label + ": source " + str(pos) + " pattern matches exact authored actions")
	_check(parsed == expected_definitions, label + ": full parsed schedule matches expected")

	var intents := CombatEnemyIntents.new(parsed)
	_check(intents.is_valid(), label + ": CombatEnemyIntents accepts parsed schedule")
	for turn in range(6):
		var announced := intents.get_intents()
		var expected_turn: Array[Dictionary] = []
		for source_def in expected_definitions:
			var pattern: Array = source_def["pattern"]
			var beat: Dictionary = (pattern[turn % pattern.size()] as Dictionary).duplicate(true)
			beat["enemy_position"] = source_def["enemy_position"]
			expected_turn.append(beat)
		_check(announced == expected_turn,
			label + ": turn " + str(turn) + " announcements match including wrap")
		_check(intents.advance_turn(), label + ": advance_turn succeeds on turn " + str(turn))


func _test_ac1_catalog_and_schedule_validation() -> void:
	var enemies_before := _load_json_array(RUN_ENEMIES_PATH, "run_enemies snapshot before")
	var party_before := _load_json_array(STARTER_PARTY_PATH, "starter_party snapshot before")
	var hemdrag_text_before := _read_text(HEMDRAG_PATH, "hemdrag_relay raw text before")

	var party_defs := _load_canonical_party_definitions()
	var enemy_defs := _load_hemdrag_enemy_definitions()
	var party := CombatParty.new(party_defs)
	var enemies := CombatEnemies.new(enemy_defs)
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"AC1: CombatParty valid from starter_party.json")
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2,
		"AC1: CombatEnemies valid from run_enemies.json [seam_ripper, button_guard]")
	_check(WEIGHTED.project(enemies.get_enemy(1)) == {
		"id": "seam_ripper",
		"name": "Seam Ripper",
		"max_hp": 18,
		"hp": 18,
		"block": 0,
		"position": 1,
		"art_path": "res://assets/paper/enemies/seam_ripper.png",
	}, "AC1: slot 1 enemy is Seam Ripper (seam_ripper, 18 HP) with authored art_path")
	_check(WEIGHTED.project(enemies.get_enemy(2)) == {
		"id": "button_guard",
		"name": "Button Guard",
		"max_hp": 16,
		"hp": 16,
		"block": 0,
		"position": 2,
		"art_path": "res://assets/paper/enemies/button_guard.png",
	}, "AC1: slot 2 enemy is Button Guard (button_guard, 16 HP) with authored art_path")

	_verify_named_encounter_schedule(
		HEMDRAG_PATH, _expected_hemdrag_definitions(), "AC1 hemdrag_relay")
	_verify_named_encounter_schedule(
		STARTER_ATTACKS_PATH, _expected_starter_attacks_definitions(), "AC1 starter_attacks")
	_verify_named_encounter_schedule(
		SPOOL_SNARE_PATH, _expected_spool_snare_definitions(), "AC1 spool_snare_relay")

	# Also verify selection through real RunFightEncounterSelection on a chosen Fight node.
	var rng := _rng(18704)
	var map := RunMap.new()
	_check(map.generate(rng), "AC1: RunMap generates with seeded RNG")
	var fight_id := _enter_opening_fight(map, "AC1 selector")
	_check(not fight_id.is_empty(), "AC1: opening Fight node chosen")
	var selector := RunFightEncounterSelection.new()
	var selected := selector.select_current_fight(
		map, rng, {"hemdrag_relay": HEMDRAG_PATH})
	_check(selected == {
		"success": true,
		"encounter_id": "hemdrag_relay",
		"definitions": _expected_hemdrag_definitions(),
	}, "AC1: RunFightEncounterSelection.select_current_fight loads canonical hemdrag_relay")
	_assert_all_numeric_fields_are_int(selected.get("definitions", []), "AC1 selected definitions")

	# Verify CombatEnemyIntents source-order sorting and detached snapshot isolation.
	var reversed_defs := _expected_hemdrag_definitions()
	reversed_defs.reverse()
	var reversed_input := reversed_defs.duplicate(true)
	var intents := CombatEnemyIntents.new(reversed_defs)
	_check(intents.is_valid(), "AC1: CombatEnemyIntents accepts reversed-order definitions")
	_check(reversed_defs == reversed_input, "AC1: CombatEnemyIntents does not mutate caller array")
	for cycle_step in range(6):
		var first_read := intents.get_intents()
		var second_read := intents.get_intents()
		var expected_beat := _expected_hemdrag_beat_intents(cycle_step)
		_check(first_read == expected_beat and second_read == expected_beat,
			"AC1: repeated get_intents() on step " + str(cycle_step) + " returns ascending source-ordered beat without advancing")
		first_read[0]["amount"] = 999
		first_read[0]["status"] = "mutated"
		first_read.clear()
		_check(second_read == expected_beat and intents.get_intents() == expected_beat,
			"AC1: mutating returned intent snapshot does not affect other snapshots or service state")
		_check(intents.advance_turn(), "AC1: explicit advance_turn succeeds on step " + str(cycle_step))

	var enemies_after := _load_json_array(RUN_ENEMIES_PATH, "run_enemies snapshot after")
	var party_after := _load_json_array(STARTER_PARTY_PATH, "starter_party snapshot after")
	var hemdrag_text_after := _read_text(HEMDRAG_PATH, "hemdrag_relay raw text after")
	_check(enemies_after == enemies_before and party_after == party_before
		and hemdrag_text_after == hemdrag_text_before,
		"AC1: catalogs and encounter files remain completely unmodified")


func _test_ac2_three_beat_execution_and_detached_bleed_tick() -> void:
	var party := CombatParty.new(_load_canonical_party_definitions())
	var enemies := CombatEnemies.new(_load_hemdrag_enemy_definitions())
	var raw_defs := RunFightEncounterSelection._parse_schedule_text(
		_read_text(HEMDRAG_PATH, "AC2 schedule"))
	var intents := CombatEnemyIntents.new(raw_defs)
	var phase := CombatEnemyPhase.new()
	_check(party.is_valid() and enemies.is_valid() and intents.is_valid(),
		"AC2 precondition: valid party, enemies, and intents")

	# Retain original actor dictionary references to verify identity preservation across shoves.
	var original_warden: Dictionary = party._heroes[0]
	var original_seamstress: Dictionary = party._heroes[1]
	var original_tinker: Dictionary = party._heroes[2]

	var opening_block := CombatStartingBlock.new(party)
	_check(opening_block.apply(), "AC2: Warden receives once-only 6 opening Block")
	_check(not opening_block.apply(), "AC2: second CombatStartingBlock.apply() is rejected")
	_check(party.get_hero(1)["hp"] == 40 and party.get_hero(1)["block"] == 6
		and party.get_hero(2)["hp"] == 30 and party.get_hero(2)["block"] == 0
		and party.get_hero(3)["hp"] == 26 and party.get_hero(3)["block"] == 0,
		"AC2 precondition: party starts at 40/30/26 HP with Warden at 6 Block")

	# Beat 1: Seam Ripper applies Bleed 1 to Seamstress (slot 2); Button Guard gains 2 Block.
	var beat1_intents := intents.get_intents()
	var beat1_intents_copy := beat1_intents.duplicate(true)
	_check(beat1_intents == _expected_hemdrag_beat_intents(0),
		"AC2 beat 1: announced intents match source 1 Bleed 1 -> pos 2, source 2 Block 2")
	var beat1_result := phase.execute_phase(party, enemies, beat1_intents)
	_check(beat1_result == {
		"ok": true,
		"events": [
			{"type": "debuff", "enemy_position": 1, "applied": true, "target_position": 2, "status": "bleed"},
			{"type": "block", "enemy_position": 2, "applied": true},
		],
	}, "AC2 beat 1: events record debuff(bleed->2) then block(source 2)")
	_check(beat1_intents == beat1_intents_copy and intents.get_intents() == beat1_intents_copy,
		"AC2 beat 1: phase does not mutate input intents or advance schedule")
	_check(party.get_heroes() == [
		{
			"id": "warden",
			"name": "Warden",
			"max_hp": 40,
			"hp": 40,
			"block": 6,
			"position": 1,
			"art_path": "res://assets/paper/heroes/warden.png",
		},
		{
			"id": "seamstress",
			"name": "Seamstress",
			"max_hp": 30,
			"hp": 30,
			"block": 0,
			"position": 2,
			"art_path": "res://assets/paper/heroes/seamstress.png",
			"statuses": {"bleed": 1},
		},
		{
			"id": "tinker",
			"name": "Tinker",
			"max_hp": 26,
			"hp": 26,
			"block": 0,
			"position": 3,
			"art_path": "res://assets/paper/heroes/tinker.png",
		},
	], "AC2 beat 1: Seamstress has 30 HP and Bleed 1 without immediate HP loss; Warden keeps 40 HP/6 Block")
	_check(WEIGHTED.project(enemies.get_enemies()) == [
		{
			"id": "seam_ripper",
			"name": "Seam Ripper",
			"max_hp": 18,
			"hp": 18,
			"block": 0,
			"position": 1,
			"art_path": "res://assets/paper/enemies/seam_ripper.png",
		},
		{
			"id": "button_guard",
			"name": "Button Guard",
			"max_hp": 16,
			"hp": 16,
			"block": 2,
			"position": 2,
			"art_path": "res://assets/paper/enemies/button_guard.png",
		},
	], "AC2 beat 1: Button Guard gains 2 Block; Seam Ripper stays at 0 Block")

	# Beat 2: Seam Ripper shoves slot 2 -> slot 3 (Seamstress 2->3 with Bleed 1, Tinker 3->2);
	# then Button Guard attacks slot 3 (newly rear Seamstress) for 3 (30 -> 27 HP).
	_check(intents.advance_turn(), "AC2: explicit advance to beat 2")
	var beat2_intents := intents.get_intents()
	var beat2_intents_copy := beat2_intents.duplicate(true)
	_check(beat2_intents == _expected_hemdrag_beat_intents(1),
		"AC2 beat 2: announced intents match source 1 shove(pos 2, dir +1), source 2 attack(pos 3, 3)")
	var beat2_result := phase.execute_phase(party, enemies, beat2_intents)
	_check(beat2_result == {
		"ok": true,
		"events": [
			{"type": "shove", "enemy_position": 1, "applied": true, "target_position": 2, "direction": 1},
			{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 3},
		],
	}, "AC2 beat 2: events record shove(pos 2, dir 1) then attack(pos 3)")
	_check(beat2_intents == beat2_intents_copy and intents.get_intents() == beat2_intents_copy,
		"AC2 beat 2: phase does not mutate input intents or advance schedule")
	_check(party.get_heroes() == [
		{
			"id": "warden",
			"name": "Warden",
			"max_hp": 40,
			"hp": 40,
			"block": 6,
			"position": 1,
			"art_path": "res://assets/paper/heroes/warden.png",
		},
		{
			"id": "tinker",
			"name": "Tinker",
			"max_hp": 26,
			"hp": 26,
			"block": 0,
			"position": 2,
			"art_path": "res://assets/paper/heroes/tinker.png",
		},
		{
			"id": "seamstress",
			"name": "Seamstress",
			"max_hp": 30,
			"hp": 27,
			"block": 0,
			"position": 3,
			"art_path": "res://assets/paper/heroes/seamstress.png",
			"statuses": {"bleed": 1},
		},
	], "AC2 beat 2: Seamstress moves 2->3 with Bleed 1 and takes 3 damage (30->27 HP); Tinker moves 3->2 unhurt (26 HP)")
	_check(is_same(party._heroes[0], original_warden)
		and is_same(party._heroes[1], original_tinker)
		and is_same(party._heroes[2], original_seamstress),
		"AC2 beat 2: hero dictionary identities follow swapped positions")

	# Beat 3: Seam Ripper attacks slot 2 (newly middle Tinker) for 3 (26 -> 23 HP);
	# Button Guard buffs own Block by 3 (2 -> 5 Block). Warden stays at 40 HP / 6 Block.
	_check(intents.advance_turn(), "AC2: explicit advance to beat 3")
	var beat3_intents := intents.get_intents()
	var beat3_intents_copy := beat3_intents.duplicate(true)
	_check(beat3_intents == _expected_hemdrag_beat_intents(2),
		"AC2 beat 3: announced intents match source 1 attack(pos 2, 3), source 2 buff(3)")
	var beat3_result := phase.execute_phase(party, enemies, beat3_intents)
	_check(beat3_result == {
		"ok": true,
		"events": [
			{"type": "attack", "enemy_position": 1, "applied": true, "target_position": 2},
			{"type": "buff", "enemy_position": 2, "applied": true},
		],
	}, "AC2 beat 3: events record attack(pos 2) then buff(source 2)")
	_check(beat3_intents == beat3_intents_copy and intents.get_intents() == beat3_intents_copy,
		"AC2 beat 3: phase does not mutate input intents or advance schedule")
	var expected_post_beat3_heroes: Array[Dictionary] = [
		{
			"id": "warden",
			"name": "Warden",
			"max_hp": 40,
			"hp": 40,
			"block": 6,
			"position": 1,
			"art_path": "res://assets/paper/heroes/warden.png",
		},
		{
			"id": "tinker",
			"name": "Tinker",
			"max_hp": 26,
			"hp": 23,
			"block": 0,
			"position": 2,
			"art_path": "res://assets/paper/heroes/tinker.png",
		},
		{
			"id": "seamstress",
			"name": "Seamstress",
			"max_hp": 30,
			"hp": 27,
			"block": 0,
			"position": 3,
			"art_path": "res://assets/paper/heroes/seamstress.png",
			"statuses": {"bleed": 1},
		},
	]
	var expected_post_beat3_enemies: Array[Dictionary] = [
		{
			"id": "seam_ripper",
			"name": "Seam Ripper",
			"max_hp": 18,
			"hp": 18,
			"block": 0,
			"position": 1,
			"art_path": "res://assets/paper/enemies/seam_ripper.png",
		},
		{
			"id": "button_guard",
			"name": "Button Guard",
			"max_hp": 16,
			"hp": 16,
			"block": 5,
			"position": 2,
			"art_path": "res://assets/paper/enemies/button_guard.png",
		},
	]
	_check(party.get_heroes() == expected_post_beat3_heroes,
		"AC2 beat 3: Tinker falls 26->23 HP, Seamstress stays 27 HP with Bleed 1 at pos 3, Warden stays 40 HP/6 Block")
	_check(WEIGHTED.project(enemies.get_enemies()) == expected_post_beat3_enemies,
		"AC2 beat 3: Button Guard Block increases 2->5; Seam Ripper remains 18 HP/0 Block")

	# Detached CombatStatusTurnBatch hero tick: Seamstress loses 1 HP from Bleed (27->26)
	# and Bleed 1 decays/expires, while CombatParty remains untouched.
	var batch := CombatStatusTurnBatch.new()
	var caller_heroes := party.get_heroes()
	var caller_heroes_copy := caller_heroes.duplicate(true)
	var tick_result := batch.tick_side("heroes", caller_heroes)
	_check(tick_result == {
		"ok": true,
		"actors": [
			{
				"id": "warden",
				"name": "Warden",
				"max_hp": 40,
				"hp": 40,
				"block": 6,
				"position": 1,
				"art_path": "res://assets/paper/heroes/warden.png",
				"statuses": {},
			},
			{
				"id": "tinker",
				"name": "Tinker",
				"max_hp": 26,
				"hp": 23,
				"block": 0,
				"position": 2,
				"art_path": "res://assets/paper/heroes/tinker.png",
				"statuses": {},
			},
			{
				"id": "seamstress",
				"name": "Seamstress",
				"max_hp": 30,
				"hp": 26,
				"block": 0,
				"position": 3,
				"art_path": "res://assets/paper/heroes/seamstress.png",
				"statuses": {},
			},
		],
		"events": [
			{"side": "heroes", "position": 1, "id": "warden", "bleed_hp_loss": 0},
			{"side": "heroes", "position": 2, "id": "tinker", "bleed_hp_loss": 0},
			{"side": "heroes", "position": 3, "id": "seamstress", "bleed_hp_loss": 1},
		],
	}, "AC2 detached tick: Seamstress Bleed 1 lowers HP 27->26 and expires to {}")
	_check(caller_heroes == caller_heroes_copy
		and party.get_heroes() == expected_post_beat3_heroes
		and WEIGHTED.project(enemies.get_enemies()) == expected_post_beat3_enemies,
		"AC2 detached tick: does not mutate caller array or silently publish to CombatParty")

	# Also prove on a detached snapshot with Block on Seamstress that Bleed ignores Block.
	var shielded_snapshot := party.get_heroes()
	shielded_snapshot[2]["block"] = 4
	var shielded_tick := batch.tick_side("heroes", shielded_snapshot)
	_check(shielded_tick.get("ok", false)
		and shielded_tick["actors"][2]["hp"] == 26
		and shielded_tick["actors"][2]["block"] == 4
		and shielded_tick["actors"][2]["statuses"] == {}
		and shielded_tick["events"][2]["bleed_hp_loss"] == 1,
		"AC2 detached tick with Block: Bleed 1 ignores Seamstress Block (4 stays 4) and lowers HP 27->26")
	_check(party.get_heroes() == expected_post_beat3_heroes,
		"AC2: CombatParty still holds pre-tick 27 HP and Bleed 1 after detached checks")


func _test_ac3_downed_shove_rejection_slain_skip_and_malformed_failures() -> void:
	var phase := CombatEnemyPhase.new()
	var schedule := RunFightEncounterSelection._parse_schedule_text(
		_read_text(HEMDRAG_PATH, "AC3 schedule"))

	# 1. Downed Seamstress immediately before beat 2 rejects the whole phase atomically.
	var party_downed := CombatParty.new(_load_canonical_party_definitions())
	var enemies_downed := CombatEnemies.new(_load_hemdrag_enemy_definitions())
	var intents_downed := CombatEnemyIntents.new(schedule)
	_check(CombatStartingBlock.new(party_downed).apply(),
		"AC3 downed fixture: Warden gets 6 opening Block")
	_check(phase.execute_phase(party_downed, enemies_downed, intents_downed.get_intents()).get("ok", false),
		"AC3 downed fixture: beat 1 succeeds")
	_check(intents_downed.advance_turn(), "AC3 downed fixture: advance to beat 2")
	_check(party_downed.apply_damage(2, 30) and party_downed.is_downed(2)
		and party_downed.get_hero(2)["hp"] == 0
		and party_downed.get_hero(2).get("statuses", {}) == {"bleed": 1},
		"AC3 downed fixture: Seamstress at slot 2 is downed with 0 HP and Bleed 1 before beat 2")

	var heroes_before_reject := party_downed.get_heroes()
	var enemies_before_reject := enemies_downed.get_enemies()
	var beat2_input := intents_downed.get_intents()
	var beat2_input_copy := beat2_input.duplicate(true)
	var run_rng := _rng(55109)
	var run_rng_state_before := run_rng.state
	seed(661234)
	var expected_global := randi()
	seed(661234)
	var reject_result := phase.execute_phase(party_downed, enemies_downed, beat2_input)
	_check(randi() == expected_global and run_rng.state == run_rng_state_before,
		"AC3 downed Seamstress: rejection draws zero global or run RNG")
	_check(reject_result == {"ok": false, "events": []},
		"AC3 downed Seamstress: source-1 shove on downed Seamstress rejects entire beat 2 phase")
	_check(party_downed.get_heroes() == heroes_before_reject
		and enemies_downed.get_enemies() == enemies_before_reject
		and beat2_input == beat2_input_copy
		and intents_downed.get_intents() == beat2_input_copy,
		"AC3 downed Seamstress: both complete rosters, caller intents, and scheduler are preserved (source 2 does not attack Tinker)")
	_check(party_downed.get_hero(3)["id"] == "tinker" and party_downed.get_hero(3)["hp"] == 26,
		"AC3 downed Seamstress: rear Tinker remains unhurt at 26 HP")

	# Also verify rollback when an earlier source stages a valid state change and a later source shoves a downed hero (Lesson 40).
	var staged_rollback_intents := [
		{"type": "block", "enemy_position": 1, "amount": 4},
		{"type": "shove", "enemy_position": 2, "amount": 0, "target_position": 2, "direction": 1},
	]
	var staged_rollback_copy := staged_rollback_intents.duplicate(true)
	_check(phase.execute_phase(party_downed, enemies_downed, staged_rollback_intents) == {"ok": false, "events": []}
		and party_downed.get_heroes() == heroes_before_reject
		and enemies_downed.get_enemies() == enemies_before_reject
		and staged_rollback_intents == staged_rollback_copy,
		"AC3 atomic rollback: earlier source 1 staged Block is rolled back when source 2 shove targets downed Seamstress")

	# 2. Slain Seam Ripper immediately before beat 2 skips shove while Button Guard hits unchanged rear Tinker for 3.
	var party_slain := CombatParty.new(_load_canonical_party_definitions())
	var enemies_slain := CombatEnemies.new(_load_hemdrag_enemy_definitions())
	var intents_slain := CombatEnemyIntents.new(schedule)
	_check(CombatStartingBlock.new(party_slain).apply(),
		"AC3 slain fixture: Warden gets 6 opening Block")
	_check(phase.execute_phase(party_slain, enemies_slain, intents_slain.get_intents()).get("ok", false),
		"AC3 slain fixture: beat 1 attaches Bleed 1 to Seamstress and 2 Block to Button Guard")
	_check(intents_slain.advance_turn(), "AC3 slain fixture: advance to beat 2")
	_check(enemies_slain.apply_damage(1, 18) and enemies_slain.is_slain(1)
		and not enemies_slain.is_slain(2) and not enemies_slain.is_defeated(),
		"AC3 slain fixture: Seam Ripper (source 1) is slain immediately before beat 2")

	var slain_beat2_intents := intents_slain.get_intents()
	var slain_beat2_copy := slain_beat2_intents.duplicate(true)
	var slain_result := phase.execute_phase(party_slain, enemies_slain, slain_beat2_intents)
	_check(slain_result == {
		"ok": true,
		"events": [
			{"type": "shove", "enemy_position": 1, "applied": false, "target_position": 2, "direction": 1},
			{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 3},
		],
	}, "AC3 slain Seam Ripper: source 1 shove is skipped (applied: false) and source 2 attack applies to slot 3")
	_check(party_slain.get_heroes() == [
		{
			"id": "warden",
			"name": "Warden",
			"max_hp": 40,
			"hp": 40,
			"block": 6,
			"position": 1,
			"art_path": "res://assets/paper/heroes/warden.png",
		},
		{
			"id": "seamstress",
			"name": "Seamstress",
			"max_hp": 30,
			"hp": 30,
			"block": 0,
			"position": 2,
			"art_path": "res://assets/paper/heroes/seamstress.png",
			"statuses": {"bleed": 1},
		},
		{
			"id": "tinker",
			"name": "Tinker",
			"max_hp": 26,
			"hp": 23,
			"block": 0,
			"position": 3,
			"art_path": "res://assets/paper/heroes/tinker.png",
		},
	], "AC3 slain Seam Ripper: Bleeding Seamstress stays at position 2 (30 HP) and still-rear Tinker takes 3 (26->23 HP)")
	_check(enemies_slain.get_enemy(1)["hp"] == 0 and enemies_slain.get_enemy(1)["position"] == 1
		and enemies_slain.get_enemy(2)["hp"] == 16 and enemies_slain.get_enemy(2)["block"] == 2
		and slain_beat2_intents == slain_beat2_copy,
		"AC3 slain Seam Ripper: enemy slots and caller intents remain intact")

	# 3. Malformed duplicate slot, fractional amount, illegal shove direction, and off-board target fail closed.
	var malformed_json_cases: Array[String] = [
		# Duplicate enemy slots
		JSON.stringify([
			{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 1, "target_position": 2, "status": "bleed"}]},
			{"enemy_position": 1, "pattern": [{"type": "block", "amount": 2}]},
		]),
		JSON.stringify([
			{"enemy_position": 2, "pattern": [{"type": "block", "amount": 2}]},
			{"enemy_position": 2, "pattern": [{"type": "buff", "amount": 3}]},
		]),
		# Nonintegral / fractional action amounts, positions, and directions
		"[{\"enemy_position\":1,\"pattern\":[{\"type\":\"debuff\",\"amount\":1.5,\"target_position\":2,\"status\":\"bleed\"}]}]",
		"[{\"enemy_position\":1,\"pattern\":[{\"type\":\"shove\",\"amount\":0.5,\"target_position\":2,\"direction\":1}]}]",
		"[{\"enemy_position\":1,\"pattern\":[{\"type\":\"attack\",\"amount\":3.25,\"target_position\":2}]}]",
		"[{\"enemy_position\":1.5,\"pattern\":[{\"type\":\"block\",\"amount\":2}]}]",
		"[{\"enemy_position\":1,\"pattern\":[{\"type\":\"attack\",\"amount\":3,\"target_position\":2.5}]}]",
		"[{\"enemy_position\":1,\"pattern\":[{\"type\":\"shove\",\"amount\":0,\"target_position\":2,\"direction\":1.5}]}]",
		"[{\"enemy_position\":1,\"pattern\":[{\"type\":\"attack\",\"amount\":9007199254740992,\"target_position\":2}]}]",
		# Illegal shove directions and nonzero shove amount
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 2, "direction": 0}]}]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 2, "direction": 2}]}]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 2, "direction": -2}]}]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 1, "target_position": 2, "direction": 1}]}]),
		# Off-board targets and shoves pushing off-board
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 1, "target_position": 0, "status": "bleed"}]}]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 1, "target_position": 4, "status": "bleed"}]}]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 3, "target_position": 0}]}]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 3, "target_position": 4}]}]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 1, "direction": -1}]}]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 3, "direction": 1}]}]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 0, "direction": 1}]}]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 4, "direction": -1}]}]),
	]
	for index in range(malformed_json_cases.size()):
		var parsed := RunFightEncounterSelection._parse_schedule_text(malformed_json_cases[index])
		_check(parsed.is_empty(),
			"AC3 malformed JSON case " + str(index) + " rejected by _parse_schedule_text")

	# Direct validator & phase checks with non-mutating fail-closed guarantees.
	var malformed_schedules: Array[Array] = [
		[
			{"enemy_position": 1, "pattern": [{"type": "block", "amount": 2}]},
			{"enemy_position": 1, "pattern": [{"type": "buff", "amount": 3}]},
		],
		[
			{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 3.0, "target_position": 2}]},
		],
		[
			{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 2, "direction": 0}]},
		],
		[
			{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 3, "direction": 1}]},
		],
		[
			{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 1, "direction": -1}]},
		],
		[
			{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 3, "target_position": 4}]},
		],
		[
			{"enemy_position": 1, "pattern": [{"type": "debuff", "amount": 1, "target_position": 0, "status": "bleed"}]},
		],
	]
	for idx in range(malformed_schedules.size()):
		var raw_schedule: Array = malformed_schedules[idx]
		var snapshot := raw_schedule.duplicate(true)
		var invalid_intents := CombatEnemyIntents.new(raw_schedule)
		_check(not invalid_intents.is_valid()
			and invalid_intents.get_intents().is_empty()
			and not invalid_intents.advance_turn()
			and raw_schedule == snapshot,
			"AC3 malformed schedule " + str(idx) + " fails CombatEnemyIntents without mutating caller input")

	var party_before_bad_phase := party_slain.get_heroes()
	var enemies_before_bad_phase := enemies_slain.get_enemies()
	var bad_phase_batches: Array[Array] = [
		[
			{"type": "block", "enemy_position": 1, "amount": 2},
			{"type": "buff", "enemy_position": 1, "amount": 3},
		],
		[
			{"type": "attack", "enemy_position": 2, "amount": 3.5, "target_position": 3},
		],
		[
			{"type": "shove", "enemy_position": 2, "amount": 0, "target_position": 2, "direction": 0},
		],
		[
			{"type": "shove", "enemy_position": 2, "amount": 0, "target_position": 3, "direction": 1},
		],
		[
			{"type": "attack", "enemy_position": 2, "amount": 3, "target_position": 4},
		],
	]
	for idx in range(bad_phase_batches.size()):
		var batch_input: Array = bad_phase_batches[idx]
		var batch_copy := batch_input.duplicate(true)
		_check(phase.execute_phase(party_slain, enemies_slain, batch_input) == {"ok": false, "events": []}
			and party_slain.get_heroes() == party_before_bad_phase
			and enemies_slain.get_enemies() == enemies_before_bad_phase
			and batch_input == batch_copy,
			"AC3 bad phase batch " + str(idx) + " fails closed without mutating rosters or input")


func _run_seeded_hemdrag_fixture(seed_value: int, label: String) -> Dictionary:
	var rng := _rng(seed_value)
	var map := RunMap.new()
	_check(map.generate(rng), label + ": map generates from seed")
	var fight_node := _enter_opening_fight(map, label)
	var selector := RunFightEncounterSelection.new()
	var selected := selector.select_current_fight(
		map, rng, {"hemdrag_relay": HEMDRAG_PATH})
	_check(selected.get("success", false) and selected.get("encounter_id") == "hemdrag_relay",
		label + ": selector chooses hemdrag_relay")
	var post_select_rng_state := rng.state

	var party := CombatParty.new(_load_canonical_party_definitions())
	var enemies := CombatEnemies.new(_load_hemdrag_enemy_definitions())
	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), label + ": Warden opening Block 6 applied")
	var intents := CombatEnemyIntents.new(selected.get("definitions", []))
	var phase := CombatEnemyPhase.new()
	_check(party.is_valid() and enemies.is_valid() and intents.is_valid(),
		label + ": combat models and intents valid")

	# Prove global RNG probe is active and non-vacuous.
	seed(774411)
	var probe_first := randi()
	var probe_second := randi()
	_check(probe_first != probe_second, label + ": global RNG probe advances when drawn")

	seed(774411)
	var expected_global := randi()
	seed(774411)

	var announced_beats: Array = []
	var phase_results: Array = []
	var hero_snapshots: Array = []
	var enemy_snapshots: Array = []

	for beat in range(3):
		var before_read := intents.get_intents()
		var repeated_read := intents.get_intents()
		_check(before_read == repeated_read and before_read == _expected_hemdrag_beat_intents(beat),
			label + ": beat " + str(beat + 1) + " get_intents() is deterministic and does not advance")
		announced_beats.append(before_read)
		var res := phase.execute_phase(party, enemies, before_read)
		phase_results.append(res)
		hero_snapshots.append(party.get_heroes())
		enemy_snapshots.append(enemies.get_enemies())
		_check(intents.get_intents() == before_read,
			label + ": execute_phase on beat " + str(beat + 1) + " does not advance schedule")
		_check(intents.advance_turn(),
			label + ": explicit advance_turn after beat " + str(beat + 1))
		_check(rng.state == post_select_rng_state,
			label + ": beat " + str(beat + 1) + " consumes zero run RNG")

	var wrapped_intents := intents.get_intents()
	_check(wrapped_intents == _expected_hemdrag_beat_intents(0),
		label + ": after 3 explicit advances, schedule wraps to beat 1")
	var detached_tick := CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())
	_check(randi() == expected_global,
		label + ": entire 3-beat execution, wrap, and status tick consume zero global RNG")
	_check(rng.state == post_select_rng_state,
		label + ": run RNG state unchanged after wrap and status tick")

	return {
		"fight_node": fight_node,
		"post_select_rng_state": post_select_rng_state,
		"announced_beats": announced_beats,
		"phase_results": phase_results,
		"hero_snapshots": hero_snapshots,
		"enemy_snapshots": enemy_snapshots,
		"wrapped_intents": wrapped_intents,
		"detached_tick": detached_tick,
		"final_party": party.get_heroes(),
		"final_enemies": enemies.get_enemies(),
	}


func _test_ac4_two_seeded_fixtures_replay_and_zero_rng_drift() -> void:
	var fixture_a := _run_seeded_hemdrag_fixture(87041, "AC4 fixture A")
	var fixture_b := _run_seeded_hemdrag_fixture(87041, "AC4 fixture B")

	_check(fixture_a == fixture_b,
		"AC4: two independently built same-seed fixtures produce identical events, snapshots, wrap, and RNG state")
	_check(fixture_a["phase_results"] == [
		{
			"ok": true,
			"events": [
				{"type": "debuff", "enemy_position": 1, "applied": true, "target_position": 2, "status": "bleed"},
				{"type": "block", "enemy_position": 2, "applied": true},
			],
		},
		{
			"ok": true,
			"events": [
				{"type": "shove", "enemy_position": 1, "applied": true, "target_position": 2, "direction": 1},
				{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 3},
			],
		},
		{
			"ok": true,
			"events": [
				{"type": "attack", "enemy_position": 1, "applied": true, "target_position": 2},
				{"type": "buff", "enemy_position": 2, "applied": true},
			],
		},
	], "AC4: literal three-beat events match expected sequence")
	_check(fixture_a["wrapped_intents"] == _expected_hemdrag_beat_intents(0),
		"AC4: literal wrapped intents match beat 1")
	_check(fixture_a["detached_tick"]["ok"]
		and fixture_a["detached_tick"]["actors"][2]["id"] == "seamstress"
		and fixture_a["detached_tick"]["actors"][2]["hp"] == 26
		and fixture_a["detached_tick"]["actors"][2]["statuses"] == {}
		and fixture_a["final_party"][2]["hp"] == 27
		and fixture_a["final_party"][2]["statuses"] == {"bleed": 1},
		"AC4: detached tick proposes 27->26 HP and Bleed decay while live party remains at 27 HP / Bleed 1")
