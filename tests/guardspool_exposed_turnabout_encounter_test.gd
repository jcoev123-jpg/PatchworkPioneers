extends SceneTree

## Deterministic headless coverage for the authored Guardspool Exposed Turnabout
## M04 Fight: slot 1 Button Guard (16 max HP) and slot 2 Spool Stalker (14 max HP).
## On Beat 1, Button Guard gains 4 Block and Spool Stalker shoves the middle hero
## forward (slot 2 -> slot 1, swapping Warden and Seamstress).
## On Beat 2, Button Guard applies Exposed 2 to the new slot-1 hero (Seamstress),
## and Spool Stalker attacks slot 1 for base 4 (amplified to 6 under Exposed 2).
## On Beat 3, Button Guard attacks slot 2 (Warden, absorbed by opening Block) for 3,
## and Spool Stalker attacks slot 1 (Seamstress) for base 4 (6 under Exposed 2).
## Standalone data and service contract: not registered in live battle pools.

const ENCOUNTER_PATH := "res://data/encounters/guardspool_exposed_turnabout.json"
const ENCOUNTER_ID := "guardspool_exposed_turnabout"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMY_PATH := "res://data/enemies/run_enemies.json"
const BUTTONFRONT_PATH := "res://data/encounters/buttonfront_pinfall.json"
const HEMDRAG_PATH := "res://data/encounters/hemdrag_relay.json"
const STARTER_ATTACKS_PATH := "res://data/encounters/starter_attacks.json"

const LOCAL_ROSTER_MAP := {
	ENCOUNTER_ID: ["button_guard", "spool_stalker"],
}

const MAP_SEED := 91733
const REPLAY_SEED := 20261022

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_ac1_catalog_parser_and_roster()
	_test_ac2_three_beat_execution_and_cycle_wrap()
	_test_ac3_seeded_selection_replay_and_failure_cases()
	if failures.is_empty():
		print("guardspool_exposed_turnabout_encounter_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("guardspool_exposed_turnabout_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _read_text(path: String) -> String:
	_check(FileAccess.file_exists(path), "expected file to exist: " + path)
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	_check(file != null, "expected file to open: " + path)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _is_integral_number(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float or is_nan(value) or is_inf(value):
		return false
	return absf(value) <= 9007199254740991.0 and floorf(value) == value


func _load_json_array(path: String) -> Array:
	var text: String = _read_text(path)
	if text.is_empty():
		return []
	var parser: JSON = JSON.new()
	var err: Error = parser.parse(text)
	_check(err == OK, "expected valid JSON syntax in: " + path)
	if err != OK or not parser.data is Array:
		_check(false, "expected top-level JSON Array in: " + path)
		return []
	return (parser.data as Array).duplicate(true)


func _find_unique_by_id(catalog: Array, target_id: String, label: String) -> Dictionary:
	var matches: Array[Dictionary] = []
	for entry: Variant in catalog:
		if entry is Dictionary and entry.get("id") == target_id:
			var copy: Dictionary = (entry as Dictionary).duplicate(true)
			var max_hp: Variant = copy.get("max_hp")
			_check(_is_integral_number(max_hp), label + " (" + target_id + "): max_hp is integral")
			if _is_integral_number(max_hp):
				copy["max_hp"] = int(max_hp)
			matches.append(copy)
	_check(matches.size() == 1, label + ": exactly one record matches id '" + target_id + "'")
	if matches.size() != 1:
		return {}
	return matches[0]


func _expected_pattern_1() -> Array:
	return [
		{"type": "block", "amount": 4},
		{"type": "debuff", "amount": 2, "target_position": 1, "status": "exposed"},
		{"type": "attack", "amount": 3, "target_position": 2},
	]


func _expected_pattern_2() -> Array:
	return [
		{"type": "shove", "amount": 0, "target_position": 2, "direction": -1},
		{"type": "attack", "amount": 4, "target_position": 1},
		{"type": "attack", "amount": 4, "target_position": 1},
	]


func _expected_definitions() -> Array:
	return [
		{"enemy_position": 1, "pattern": _expected_pattern_1()},
		{"enemy_position": 2, "pattern": _expected_pattern_2()},
	]


func _expected_beat_1_intents() -> Array[Dictionary]:
	return [
		{"type": "block", "amount": 4, "enemy_position": 1},
		{"type": "shove", "amount": 0, "target_position": 2, "direction": -1, "enemy_position": 2},
	]


func _expected_beat_2_intents() -> Array[Dictionary]:
	return [
		{"type": "debuff", "amount": 2, "target_position": 1, "status": "exposed", "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 2},
	]


func _expected_beat_3_intents() -> Array[Dictionary]:
	return [
		{"type": "attack", "amount": 3, "target_position": 2, "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 2},
	]


func _build_starter_party() -> CombatParty:
	var raw_heroes: Array = _load_json_array(PARTY_PATH)
	var warden: Dictionary = _find_unique_by_id(raw_heroes, "warden", "starter_party")
	var seamstress: Dictionary = _find_unique_by_id(raw_heroes, "seamstress", "starter_party")
	var tinker: Dictionary = _find_unique_by_id(raw_heroes, "tinker", "starter_party")
	return CombatParty.new([warden, seamstress, tinker])


func _build_guardspool_enemies() -> CombatEnemies:
	var raw_enemies: Array = _load_json_array(ENEMY_PATH)
	var guard: Dictionary = _find_unique_by_id(raw_enemies, "button_guard", "run_enemies")
	var stalker: Dictionary = _find_unique_by_id(raw_enemies, "spool_stalker", "run_enemies")
	return CombatEnemies.new([guard, stalker])


## AC1: The encounter parses cleanly through RunFightEncounterSelection._parse_schedule_text,
## produces valid CombatEnemyIntents, binds genuine two-enemy roster via RunTypedBattleRoster,
## and earlier encounters remain valid without asserting catalog totals or pool order.
func _test_ac1_catalog_parser_and_roster() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "authored encounter file exists at " + ENCOUNTER_PATH)
	_check(ENCOUNTER_PATH.get_file().get_basename() == ENCOUNTER_ID, "encounter file matches ID " + ENCOUNTER_ID)

	var raw_text: String = _read_text(ENCOUNTER_PATH)
	_check(not raw_text.strip_edges().is_empty(), "encounter file is not empty")

	var raw_array: Array = _load_json_array(ENCOUNTER_PATH)
	_check(raw_array.size() == 2, "raw encounter holds exactly 2 source definitions")
	for raw_def: Variant in raw_array:
		_check(raw_def is Dictionary, "source definition is Dictionary")
		if not raw_def is Dictionary:
			continue
		var raw_dict: Dictionary = raw_def as Dictionary
		_check(raw_dict.has("enemy_position") and raw_dict.has("pattern"), "definition has enemy_position and pattern")
		_check(_is_integral_number(raw_dict.get("enemy_position")), "enemy_position is integral number")
		var raw_pattern: Variant = raw_dict.get("pattern")
		_check(raw_pattern is Array and (raw_pattern as Array).size() == 3, "pattern is Array of 3 actions")
		if raw_pattern is Array:
			for raw_action: Variant in raw_pattern:
				_check(raw_action is Dictionary, "pattern action is Dictionary")
				if raw_action is Dictionary:
					var act_dict: Dictionary = raw_action as Dictionary
					_check(act_dict.has("type") and act_dict.has("amount"), "action has type and amount")
					_check(_is_integral_number(act_dict.get("amount")), "action amount is integral number")
					if act_dict.has("target_position"):
						_check(_is_integral_number(act_dict.get("target_position")), "action target_position is integral")
					if act_dict.has("direction"):
						_check(_is_integral_number(act_dict.get("direction")), "action direction is integral")

	var parsed: Array = RunFightEncounterSelection._parse_schedule_text(raw_text)
	_check(parsed.size() == 2, "parsed schedule contains exactly 2 sources")
	_check(parsed == _expected_definitions(), "parsed schedule matches expected definitions exactly")

	for def_entry: Variant in parsed:
		var def_dict: Dictionary = def_entry as Dictionary
		_check(typeof(def_dict.get("enemy_position")) == TYPE_INT, "parsed enemy_position has TYPE_INT")
		var pattern: Array = def_dict.get("pattern", [])
		for action_entry: Variant in pattern:
			var act_dict: Dictionary = action_entry as Dictionary
			_check(typeof(act_dict.get("amount")) == TYPE_INT, "parsed amount has TYPE_INT")
			if act_dict.has("target_position"):
				_check(typeof(act_dict.get("target_position")) == TYPE_INT, "parsed target_position has TYPE_INT")
			if act_dict.has("direction"):
				_check(typeof(act_dict.get("direction")) == TYPE_INT, "parsed direction has TYPE_INT")

	var intents: CombatEnemyIntents = CombatEnemyIntents.new(parsed)
	_check(intents.is_valid(), "CombatEnemyIntents accepts parsed definitions")

	var raw_enemies: Array = _load_json_array(ENEMY_PATH)
	var guard: Dictionary = _find_unique_by_id(raw_enemies, "button_guard", "run_enemies")
	var stalker: Dictionary = _find_unique_by_id(raw_enemies, "spool_stalker", "run_enemies")
	_check(guard.get("name") == "Button Guard" and guard.get("max_hp") == 16,
		"Button Guard is 16 max HP")
	_check(stalker.get("name") == "Spool Stalker" and stalker.get("max_hp") == 14,
		"Spool Stalker is 14 max HP")
	_check(guard.get("art_path") == "res://assets/paper/enemies/button_guard.png",
		"Button Guard art_path intact")
	_check(stalker.get("art_path") == "res://assets/paper/enemies/spool_stalker.png",
		"Spool Stalker art_path intact")

	var raw_party: Array = _load_json_array(PARTY_PATH)
	var warden: Dictionary = _find_unique_by_id(raw_party, "warden", "starter_party")
	var seamstress: Dictionary = _find_unique_by_id(raw_party, "seamstress", "starter_party")
	var tinker: Dictionary = _find_unique_by_id(raw_party, "tinker", "starter_party")
	_check(warden.get("name") == "Warden" and warden.get("max_hp") == 40, "Warden is 40 max HP")
	_check(seamstress.get("name") == "Seamstress" and seamstress.get("max_hp") == 30, "Seamstress is 30 max HP")
	_check(tinker.get("name") == "Tinker" and tinker.get("max_hp") == 26, "Tinker is 26 max HP")

	var party: CombatParty = _build_starter_party()
	_check(party.is_valid(), "starter CombatParty is valid")
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(3).get("id") == "tinker", "heroes in positions 1, 2, 3")

	var typed_choice: Dictionary = {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": parsed.duplicate(true),
	}
	var roster_service: RunTypedBattleRoster = RunTypedBattleRoster.new()
	var roster_res: Dictionary = roster_service.assemble(typed_choice, LOCAL_ROSTER_MAP.duplicate(true), [ENEMY_PATH])
	_check(roster_res.get("ok") == true, "RunTypedBattleRoster.assemble succeeds with local mapping")
	_check(roster_res.get("node_type") == "Fight", "roster assembly node_type is Fight")
	_check(roster_res.get("encounter_id") == ENCOUNTER_ID, "roster assembly encounter_id matches")
	var assembled_enemies: CombatEnemies = roster_res.get("enemies")
	_check(assembled_enemies != null and assembled_enemies.is_valid(), "assembled CombatEnemies is valid")
	_check(assembled_enemies.get_enemies().size() == 2, "assembled CombatEnemies has 2 enemies")
	_check(assembled_enemies.get_enemy(1).get("id") == "button_guard" and assembled_enemies.get_enemy(1).get("max_hp") == 16,
		"assembled slot 1 is Button Guard (16 max HP)")
	_check(assembled_enemies.get_enemy(2).get("id") == "spool_stalker" and assembled_enemies.get_enemy(2).get("max_hp") == 14,
		"assembled slot 2 is Spool Stalker (14 max HP)")

	# Named earlier encounters still parse without asserting catalog totals or ordering.
	var buttonfront_defs: Array = RunFightEncounterSelection._parse_schedule_text(_read_text(BUTTONFRONT_PATH))
	_check(buttonfront_defs.size() == 2, "buttonfront_pinfall parses into 2 sources")
	_check(CombatEnemyIntents.new(buttonfront_defs).is_valid(), "buttonfront_pinfall produces valid CombatEnemyIntents")

	var hemdrag_defs: Array = RunFightEncounterSelection._parse_schedule_text(_read_text(HEMDRAG_PATH))
	_check(hemdrag_defs.size() == 2, "hemdrag_relay parses into 2 sources")
	_check(CombatEnemyIntents.new(hemdrag_defs).is_valid(), "hemdrag_relay produces valid CombatEnemyIntents")

	var starter_defs: Array = RunFightEncounterSelection._parse_schedule_text(_read_text(STARTER_ATTACKS_PATH))
	_check(starter_defs.size() == 2, "starter_attacks parses into 2 sources")
	_check(CombatEnemyIntents.new(starter_defs).is_valid(), "starter_attacks produces valid CombatEnemyIntents")


## AC2: Beat 1 grants Button Guard 4 Block and shoves hero 2 to 1 (swapping Warden and Seamstress).
## Beat 2 applies Exposed 2 to slot 1 before attacking slot 1 for base 4 (6 damage under Exposed).
## Beat 3 attacks slot 2 (base 3) and slot 1 (base 4, 6 under Exposed 2). Intents repeat after beat 3.
func _test_ac2_three_beat_execution_and_cycle_wrap() -> void:
	var party: CombatParty = _build_starter_party()
	var enemies: CombatEnemies = _build_guardspool_enemies()
	var definitions: Array = RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	var intents: CombatEnemyIntents = CombatEnemyIntents.new(definitions)
	var phase: CombatEnemyPhase = CombatEnemyPhase.new()

	_check(party.is_valid() and enemies.is_valid() and intents.is_valid(), "preconditions valid")

	var starting_block: CombatStartingBlock = CombatStartingBlock.new(party)
	_check(starting_block.apply(), "Warden receives opening 6 Block")
	_check(not starting_block.apply(), "second CombatStartingBlock.apply fails closed")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6,
		"Warden starts at 40 HP and 6 Block")
	_check(party.get_hero(2).get("hp") == 30 and party.get_hero(2).get("block") == 0,
		"Seamstress starts at 30 HP and 0 Block")
	_check(party.get_hero(3).get("hp") == 26 and party.get_hero(3).get("block") == 0,
		"Tinker starts at 26 HP and 0 Block")

	var original_warden: Dictionary = party._heroes[0]
	var original_seamstress: Dictionary = party._heroes[1]
	var original_tinker: Dictionary = party._heroes[2]

	# BEAT 1: Button Guard block 4, Spool Stalker shove slot 2 dir -1 (swaps Seamstress to 1, Warden to 2).
	var b1_intents: Array = intents.get_intents()
	_check(b1_intents == _expected_beat_1_intents(), "Beat 1 intents match expected")
	var b1_res: Dictionary = phase.execute_phase(party, enemies, b1_intents)
	_check(b1_res.get("ok") == true, "Beat 1 phase execution succeeds")
	_check(b1_res.get("events") == [
		{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "shove", "enemy_position": 2, "applied": true, "target_position": 2, "direction": -1},
	], "Beat 1 events match block(source 1) then shove(source 2, pos 2, dir -1)")

	_check(enemies.get_enemy(1).get("block") == 4, "Button Guard has 4 Block after Beat 1")
	_check(enemies.get_enemy(2).get("block") == 0, "Spool Stalker has 0 Block after Beat 1")

	# Verify hero swap: Seamstress at 1 (30 HP, 0 Block), Warden at 2 (40 HP, 6 Block), Tinker at 3 (26 HP, 0 Block).
	_check(party.get_hero(1).get("id") == "seamstress" and party.get_hero(1).get("hp") == 30
		and party.get_hero(1).get("block") == 0, "hero slot 1 is Seamstress (30 HP, 0 Block)")
	_check(party.get_hero(2).get("id") == "warden" and party.get_hero(2).get("hp") == 40
		and party.get_hero(2).get("block") == 6, "hero slot 2 is Warden (40 HP, 6 Block)")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("block") == 0, "hero slot 3 is Tinker (26 HP, 0 Block)")
	_check(is_same(party._heroes[0], original_seamstress) and is_same(party._heroes[1], original_warden)
		and is_same(party._heroes[2], original_tinker), "hero dictionary identities follow swaps")

	# BEAT 2: Button Guard debuff Exposed 2 on slot 1 (Seamstress), Spool Stalker attack 4 on slot 1.
	_check(intents.advance_turn(), "advance turn to Beat 2 succeeds")
	var b2_intents: Array = intents.get_intents()
	_check(b2_intents == _expected_beat_2_intents(), "Beat 2 intents match expected")

	# Confirm formula: floor(4 * 1.5) = 6 damage.
	_check(CombatStatuses.new().adjusted_attack_damage(4, {}, {"exposed": 2}) == 6,
		"CombatStatuses computes 6 damage for base 4 with Exposed 2")

	var b2_res: Dictionary = phase.execute_phase(party, enemies, b2_intents)
	_check(b2_res.get("ok") == true, "Beat 2 phase execution succeeds")
	_check(b2_res.get("events") == [
		{"type": "debuff", "enemy_position": 1, "applied": true, "target_position": 1, "status": "exposed"},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 1},
	], "Beat 2 events match debuff(exposed 2 on slot 1) then attack(slot 1)")

	# Seamstress at slot 1 took 6 unblocked damage: 30 -> 24 HP, status exposed: 2.
	_check(party.get_hero(1).get("id") == "seamstress" and party.get_hero(1).get("hp") == 24
		and party.get_hero(1).get("block") == 0 and party.get_hero(1).get("statuses") == {"exposed": 2},
		"Seamstress at slot 1 took 6 damage (30 -> 24 HP) and carries Exposed 2")
	_check(party.get_hero(2).get("id") == "warden" and party.get_hero(2).get("hp") == 40
		and party.get_hero(2).get("block") == 6, "Warden at slot 2 remains untouched at 40 HP and 6 Block")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("block") == 0, "Tinker at slot 3 remains untouched at 26 HP")
	_check(enemies.get_enemy(1).get("block") == 4, "Button Guard Block remains 4")

	# BEAT 3: Button Guard attack 3 on slot 2 (Warden), Spool Stalker attack 4 on slot 1 (Seamstress).
	_check(intents.advance_turn(), "advance turn to Beat 3 succeeds")
	var b3_intents: Array = intents.get_intents()
	_check(b3_intents == _expected_beat_3_intents(), "Beat 3 intents match expected")

	var b3_res: Dictionary = phase.execute_phase(party, enemies, b3_intents)
	_check(b3_res.get("ok") == true, "Beat 3 phase execution succeeds")
	_check(b3_res.get("events") == [
		{"type": "attack", "enemy_position": 1, "applied": true, "target_position": 2},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 1},
	], "Beat 3 events match attack(pos 2) then attack(pos 1)")

	# Warden at slot 2 had 6 Block, absorbs attack of 3: Block becomes 3, HP remains 40.
	_check(party.get_hero(2).get("id") == "warden" and party.get_hero(2).get("hp") == 40
		and party.get_hero(2).get("block") == 3, "Warden at slot 2 absorbed 3 Block (6 -> 3 Block, 40 HP intact)")
	# Seamstress at slot 1 still has Exposed 2, takes 6 unblocked damage: 24 -> 18 HP.
	_check(party.get_hero(1).get("id") == "seamstress" and party.get_hero(1).get("hp") == 18
		and party.get_hero(1).get("block") == 0 and party.get_hero(1).get("statuses") == {"exposed": 2},
		"Seamstress at slot 1 took 6 damage (24 -> 18 HP) under Exposed 2")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 26,
		"Tinker at slot 3 remains at 26 HP")

	# CYCLE WRAP: Turn 4 wraps to Beat 1 intents; Turn 5 to Beat 2; Turn 6 to Beat 3.
	_check(intents.advance_turn(), "advance turn to Beat 4 (wrap) succeeds")
	_check(intents.get_intents() == _expected_beat_1_intents(), "Turn 4 wraps to exact Beat 1 intents")

	# Execute Turn 4 (wrapped Beat 1) on live battle:
	# Button Guard gains 4 Block (4 -> 8 Block).
	# Spool Stalker shoves slot 2 (now Warden) in direction -1 (swapping Warden and Seamstress back!).
	var b4_res: Dictionary = phase.execute_phase(party, enemies, intents.get_intents())
	_check(b4_res.get("ok") == true, "wrapped Beat 1 phase execution succeeds")
	_check(enemies.get_enemy(1).get("block") == 8, "Button Guard Block increased from 4 to 8")
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 3, "slot 1 swapped back to Warden (40 HP, 3 Block)")
	_check(party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 18
		and party.get_hero(2).get("block") == 0 and party.get_hero(2).get("statuses", {}) == {"exposed": 2},
		"slot 2 swapped back to Seamstress (18 HP, 0 Block, Exposed 2)")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 26,
		"slot 3 is Tinker (26 HP)")

	_check(intents.advance_turn(), "advance turn to Beat 5 succeeds")
	_check(intents.get_intents() == _expected_beat_2_intents(), "Turn 5 continues to Beat 2 intents")
	_check(intents.advance_turn(), "advance turn to Beat 6 succeeds")
	_check(intents.get_intents() == _expected_beat_3_intents(), "Turn 6 continues to Beat 3 intents")

	# Replay timeline from fresh instance to verify deterministic cyclic intent service (Lesson 4).
	var fresh_intents: CombatEnemyIntents = CombatEnemyIntents.new(definitions)
	_check(fresh_intents.get_intents() == _expected_beat_1_intents(), "fresh intents start at Beat 1")
	_check(fresh_intents.advance_turn() and fresh_intents.get_intents() == _expected_beat_2_intents(), "fresh step 2")
	_check(fresh_intents.advance_turn() and fresh_intents.get_intents() == _expected_beat_3_intents(), "fresh step 3")
	_check(fresh_intents.advance_turn() and fresh_intents.get_intents() == _expected_beat_1_intents(), "fresh step 4 wrap")
	_check(fresh_intents.advance_turn() and fresh_intents.get_intents() == _expected_beat_2_intents(), "fresh step 5")
	_check(fresh_intents.advance_turn() and fresh_intents.get_intents() == _expected_beat_3_intents(), "fresh step 6")


## AC3: Seeded selection & replay with one-entry local candidate pool; zero extra RNG draw
## on cached re-read; illegal shove with downed adjacent destination hero prevents shove atomically
## without mutating party/enemies; and slain sources do not act while living allies still act.
func _test_ac3_seeded_selection_replay_and_failure_cases() -> void:
	# 1. Seeded Fight selection with single candidate pool.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = MAP_SEED
	var map: RunMap = RunMap.new()
	_check(map.generate(rng), "RunMap generates with seeded RNG")

	var fight_id: String = ""
	for candidate: String in map.get_legal_choices():
		if map.get_node(candidate).get("type") == "Fight":
			fight_id = candidate
			break
	_check(not fight_id.is_empty(), "found legal opening Fight node on generated map")
	_check(map.choose_node(fight_id), "map chooses opening Fight node")

	var selector: RunFightEncounterSelection = RunFightEncounterSelection.new()
	var candidate_pool: Dictionary = {ENCOUNTER_ID: ENCOUNTER_PATH}
	var choice: Dictionary = selector.select_current_fight(map, rng, candidate_pool)
	_check(choice.get("success") == true, "select_current_fight succeeds")
	_check(choice.get("encounter_id") == ENCOUNTER_ID, "selected encounter_id matches")
	_check(choice.get("definitions") == _expected_definitions(), "selected definitions match authored schedule")

	# Cached re-read: draws zero extra RNG.
	var rng_state_before: int = rng.state
	var cached_choice: Dictionary = selector.select_current_fight(map, rng, candidate_pool)
	_check(rng.state == rng_state_before, "cached re-read consumed zero RNG draws")
	_check(cached_choice == choice, "cached re-read matches original choice")

	# Mutation of choice dictionary does not corrupt cached data.
	cached_choice["encounter_id"] = "corrupted"
	var cached_choice_recheck: Dictionary = selector.select_current_fight(map, rng, candidate_pool)
	_check(cached_choice_recheck.get("encounter_id") == ENCOUNTER_ID, "cached selection remains uncorrupted")

	# Deterministic replay with identical explicit RNG seed (Lesson 8).
	var rng_replay: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_replay.seed = MAP_SEED
	var map_replay: RunMap = RunMap.new()
	_check(map_replay.generate(rng_replay), "RunMap replay generates with identical seed")
	_check(map_replay.choose_node(fight_id), "map replay chooses same opening Fight node")
	var selector_replay: RunFightEncounterSelection = RunFightEncounterSelection.new()
	var choice_replay: Dictionary = selector_replay.select_current_fight(map_replay, rng_replay, candidate_pool)
	_check(choice_replay == choice, "identical seed replays identical selection result")

	# 2. Illegal shove with downed adjacent destination hero:
	# Keep moving hero (slot 2 Seamstress) ALIVE, while downing the adjacent destination hero
	# (slot 1 Warden) before Beat 1 (Lesson 38).
	var phase: CombatEnemyPhase = CombatEnemyPhase.new()
	var party_downed: CombatParty = _build_starter_party()
	var enemies_downed: CombatEnemies = _build_guardspool_enemies()
	_check(CombatStartingBlock.new(party_downed).apply(), "Warden gets starting Block")

	# Down adjacent destination hero (slot 1 Warden): 40 HP + 6 Block = 46 damage downing him to 0 HP.
	_check(party_downed.apply_damage(1, 46), "apply 46 damage to Warden")
	_check(party_downed.is_downed(1) and party_downed.get_hero(1).get("hp") == 0,
		"fixture precondition: destination hero at slot 1 is downed")
	_check(not party_downed.is_downed(2) and party_downed.get_hero(2).get("hp") == 30,
		"fixture precondition: moving hero at slot 2 is ALIVE (Lesson 38)")

	var heroes_snapshot: Array[Dictionary] = party_downed.get_heroes()
	var enemies_snapshot: Array[Dictionary] = enemies_downed.get_enemies()
	var b1_downed_intents: Array[Dictionary] = _expected_beat_1_intents()
	var b1_downed_copy: Array = b1_downed_intents.duplicate(true)

	var reject_result: Dictionary = phase.execute_phase(party_downed, enemies_downed, b1_downed_intents)
	_check(reject_result == {"ok": false, "events": []},
		"illegal shove targeting downed destination hero rejects phase atomically")
	_check(party_downed.get_heroes() == heroes_snapshot, "party snapshot unchanged on shove rejection")
	_check(enemies_downed.get_enemies() == enemies_snapshot, "enemy snapshot unchanged on shove rejection")
	_check(enemies_downed.get_enemy(1).get("block") == 0,
		"Source 1 staged 4 Block is rolled back on Source 2 illegal shove rejection")
	_check(b1_downed_intents == b1_downed_copy, "intents array unmutated on rejection")

	# Downed mover hero (slot 2 Seamstress downed, destination slot 1 alive): also rejects atomically.
	var party_downed_mover: CombatParty = _build_starter_party()
	var enemies_downed_mover: CombatEnemies = _build_guardspool_enemies()
	_check(party_downed_mover.apply_damage(2, 30), "down Seamstress at slot 2")
	_check(party_downed_mover.is_downed(2) and not party_downed_mover.is_downed(1),
		"fixture precondition: mover is downed, destination is alive")
	var mover_heroes_snap: Array[Dictionary] = party_downed_mover.get_heroes()
	var mover_enemies_snap: Array[Dictionary] = enemies_downed_mover.get_enemies()
	_check(phase.execute_phase(party_downed_mover, enemies_downed_mover, b1_downed_intents) == {"ok": false, "events": []},
		"shove with downed mover hero rejects atomically")
	_check(party_downed_mover.get_heroes() == mover_heroes_snap
		and enemies_downed_mover.get_enemies() == mover_enemies_snap,
		"snapshots unchanged when mover is downed")

	# Invalid shove direction / out-of-bounds target fails closed.
	var invalid_shove_intents: Array[Dictionary] = [
		{"type": "shove", "enemy_position": 2, "amount": 0, "target_position": 1, "direction": -1},
	]
	var party_clean: CombatParty = _build_starter_party()
	var enemies_clean: CombatEnemies = _build_guardspool_enemies()
	var clean_heroes_snap: Array[Dictionary] = party_clean.get_heroes()
	_check(phase.execute_phase(party_clean, enemies_clean, invalid_shove_intents) == {"ok": false, "events": []},
		"out-of-bounds shove (pos 1 dir -1) rejects atomically")
	_check(party_clean.get_heroes() == clean_heroes_snap, "party unchanged on out-of-bounds shove")

	# 3. Slain-source skips:
	# Case A: Source 1 (Button Guard) is slain before Beat 1.
	var party_slain_1: CombatParty = _build_starter_party()
	var enemies_slain_1: CombatEnemies = _build_guardspool_enemies()
	_check(CombatStartingBlock.new(party_slain_1).apply(), "Warden gets starting Block")
	_check(enemies_slain_1.apply_damage(1, 16) and enemies_slain_1.is_slain(1), "Button Guard slain before Beat 1")
	var slain_1_res: Dictionary = phase.execute_phase(party_slain_1, enemies_slain_1, _expected_beat_1_intents())
	_check(slain_1_res.get("ok") == true, "phase succeeds with slain Source 1")
	_check(slain_1_res.get("events") == [
		{"type": "block", "enemy_position": 1, "applied": false},
		{"type": "shove", "enemy_position": 2, "applied": true, "target_position": 2, "direction": -1},
	], "Source 1 Block is skipped (applied: false), Source 2 shove is applied")
	_check(enemies_slain_1.get_enemy(1).get("block") == 0, "slain Button Guard gains no Block")
	_check(party_slain_1.get_hero(1).get("id") == "seamstress" and party_slain_1.get_hero(2).get("id") == "warden",
		"living Spool Stalker successfully shoves Seamstress to slot 1 despite slain ally")

	# Case B: Source 2 (Spool Stalker) is slain before Beat 1.
	var party_slain_2: CombatParty = _build_starter_party()
	var enemies_slain_2: CombatEnemies = _build_guardspool_enemies()
	_check(CombatStartingBlock.new(party_slain_2).apply(), "Warden gets starting Block")
	_check(enemies_slain_2.apply_damage(2, 14) and enemies_slain_2.is_slain(2), "Spool Stalker slain before Beat 1")
	var slain_2_res: Dictionary = phase.execute_phase(party_slain_2, enemies_slain_2, _expected_beat_1_intents())
	_check(slain_2_res.get("ok") == true, "phase succeeds with slain Source 2")
	_check(slain_2_res.get("events") == [
		{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "shove", "enemy_position": 2, "applied": false, "target_position": 2, "direction": -1},
	], "Source 1 Block is applied, Source 2 shove is skipped (applied: false)")
	_check(enemies_slain_2.get_enemy(1).get("block") == 4, "living Button Guard gains 4 Block")
	_check(party_slain_2.get_hero(1).get("id") == "warden" and party_slain_2.get_hero(2).get("id") == "seamstress",
		"heroes do not swap when Spool Stalker is slain")

	# Case C: Source 1 (Button Guard) is slain before Beat 2.
	var party_slain_b2: CombatParty = _build_starter_party()
	var enemies_slain_b2: CombatEnemies = _build_guardspool_enemies()
	_check(CombatStartingBlock.new(party_slain_b2).apply(), "Warden gets starting Block")
	_check(enemies_slain_b2.apply_damage(1, 16) and enemies_slain_b2.is_slain(1), "Button Guard slain before Beat 2")
	var slain_b2_res: Dictionary = phase.execute_phase(party_slain_b2, enemies_slain_b2, _expected_beat_2_intents())
	_check(slain_b2_res.get("ok") == true, "Beat 2 succeeds with slain Source 1")
	_check(slain_b2_res.get("events") == [
		{"type": "debuff", "enemy_position": 1, "applied": false, "target_position": 1, "status": "exposed"},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 1},
	], "Source 1 debuff skipped (applied: false), Source 2 attacks slot 1")
	# Since Exposed was skipped, Warden at slot 1 takes base 4 damage without +50% amp: 6 Block absorbs 4 -> 2 Block remaining.
	_check(party_slain_b2.get_hero(1).get("id") == "warden" and party_slain_b2.get_hero(1).get("hp") == 40
		and party_slain_b2.get_hero(1).get("block") == 2 and party_slain_b2.get_hero(1).get("statuses", {}) == {},
		"Warden takes base 4 damage (6 -> 2 Block, 40 HP intact, no Exposed status) because debuff was skipped")
