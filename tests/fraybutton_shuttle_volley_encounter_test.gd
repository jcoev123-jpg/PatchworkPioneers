extends SceneTree

## Deterministic headless coverage for the authored Fraybutton Shuttle Volley
## M04 Fight: slot 1 Fray Scavenger (14 max HP) and slot 2 Button Guard (16 max HP).
## On Beat 1, Fray Scavenger debuffs Tinker with Weak 2, Button Guard gains 3 Block.
## On Beat 2, Fray Scavenger shoves slot 1 forward (direction 1), swapping living
## Warden and Seamstress (Warden moves to slot 2 retaining his 6 Block). Then
## Button Guard attacks slot 1 (now Seamstress) dealing 4 damage (30 -> 26 HP).
## On Beat 3, Fray Scavenger debuffs Tinker with Exposed 1. Then Button Guard
## attacks slot 3 for base 4, amplified to floor(4 * 1.5) = 6 damage (26 -> 20 HP).
## Standalone data and service contract: not registered in live battle pools.

const ENCOUNTER_PATH := "res://data/encounters/fraybutton_shuttle_volley.json"
const ENCOUNTER_ID := "fraybutton_shuttle_volley"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMY_PATH := "res://data/enemies/run_enemies.json"
const BUTTONFRONT_PATH := "res://data/encounters/buttonfront_pinfall.json"
const GUARDSPOOL_PATH := "res://data/encounters/guardspool_exposed_turnabout.json"

const LOCAL_ROSTER_MAP := {
	ENCOUNTER_ID: ["fray_scavenger", "button_guard"],
}

const MAP_SEED := 91733
const REPLAY_SEED := 20261022

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_ac1_catalog_parser_and_intents()
	_test_ac2_real_combat_enemy_phase_and_status()
	_test_ac3_run_map_selection_and_fail_closed()
	if failures.is_empty():
		print("fraybutton_shuttle_volley_encounter_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("fraybutton_shuttle_volley_encounter_test: FAIL (", failures.size(), " failures)")
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


func _expected_definitions() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "debuff", "amount": 2, "target_position": 3, "status": "weak"},
			{"type": "shove", "amount": 0, "target_position": 1, "direction": 1},
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed"},
		]},
		{"enemy_position": 2, "pattern": [
			{"type": "block", "amount": 3},
			{"type": "attack", "amount": 4, "target_position": 1},
			{"type": "attack", "amount": 4, "target_position": 3},
		]},
	]


func _expected_beat_1_intents() -> Array:
	return [
		{"type": "debuff", "amount": 2, "target_position": 3, "status": "weak", "enemy_position": 1},
		{"type": "block", "amount": 3, "enemy_position": 2},
	]


func _expected_beat_2_intents() -> Array:
	return [
		{"type": "shove", "amount": 0, "target_position": 1, "direction": 1, "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 2},
	]


func _expected_beat_3_intents() -> Array:
	return [
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed", "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 3, "enemy_position": 2},
	]


func _build_starter_party() -> CombatParty:
	var raw_heroes: Array = _load_json_array(PARTY_PATH)
	var warden: Dictionary = _find_unique_by_id(raw_heroes, "warden", "starter_party")
	var seamstress: Dictionary = _find_unique_by_id(raw_heroes, "seamstress", "starter_party")
	var tinker: Dictionary = _find_unique_by_id(raw_heroes, "tinker", "starter_party")
	return CombatParty.new([warden, seamstress, tinker])


func _build_fraybutton_enemies() -> CombatEnemies:
	var raw_enemies: Array = _load_json_array(ENEMY_PATH)
	var scavenger: Dictionary = _find_unique_by_id(raw_enemies, "fray_scavenger", "run_enemies")
	var guard: Dictionary = _find_unique_by_id(raw_enemies, "button_guard", "run_enemies")
	return CombatEnemies.new([scavenger, guard])


## AC1: authored record and enemy definitions by ID; parse schedule with
## RunFightEncounterSelection._parse_schedule_text and CombatEnemyIntents;
## assert the exact three announcements plus wrap to beat 1, with ordered source slots.
func _test_ac1_catalog_parser_and_intents() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "authored encounter file exists at " + ENCOUNTER_PATH)
	_check(ENCOUNTER_PATH.get_file().get_basename() == ENCOUNTER_ID,
		"encounter file basename matches ID " + ENCOUNTER_ID)

	var raw_text: String = _read_text(ENCOUNTER_PATH)
	_check(not raw_text.strip_edges().is_empty(), "encounter file is not empty")

	var raw_array: Array = _load_json_array(ENCOUNTER_PATH)
	_check(raw_array.size() == 2, "raw encounter holds exactly 2 source definitions")
	for raw_def: Variant in raw_array:
		_check(raw_def is Dictionary, "source definition is a Dictionary")
		if not raw_def is Dictionary:
			continue
		var raw_dict: Dictionary = raw_def as Dictionary
		_check(raw_dict.has("enemy_position") and raw_dict.has("pattern"),
			"definition has enemy_position and pattern")
		_check(_is_integral_number(raw_dict.get("enemy_position")), "enemy_position is integral number")
		var raw_pattern: Variant = raw_dict.get("pattern")
		_check(raw_pattern is Array and (raw_pattern as Array).size() == 3,
			"pattern is an Array of exactly 3 actions")
		if raw_pattern is Array:
			for raw_action: Variant in raw_pattern:
				_check(raw_action is Dictionary, "pattern action is a Dictionary")
				if raw_action is Dictionary:
					var act_dict: Dictionary = raw_action as Dictionary
					_check(act_dict.has("type") and act_dict.has("amount"), "action has type and amount")
					_check(_is_integral_number(act_dict.get("amount")), "action amount is integral number")
					if act_dict.has("target_position"):
						_check(_is_integral_number(act_dict.get("target_position")),
							"action target_position is integral number")
					if act_dict.has("direction"):
						_check(_is_integral_number(act_dict.get("direction")),
							"action direction is integral number")

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
				_check(typeof(act_dict.get("target_position")) == TYPE_INT,
					"parsed target_position has TYPE_INT")
			if act_dict.has("direction"):
				_check(typeof(act_dict.get("direction")) == TYPE_INT,
					"parsed direction has TYPE_INT")

	var intents: CombatEnemyIntents = CombatEnemyIntents.new(parsed)
	_check(intents.is_valid(), "CombatEnemyIntents accepts parsed definitions")

	# Announcements for beats 1, 2, 3, and wrap on beat 4
	var b1: Array = intents.get_intents()
	_check(b1 == _expected_beat_1_intents(), "Beat 1 announces expected intents")
	_check(b1.size() == 2 and b1[0].get("enemy_position") == 1 and b1[1].get("enemy_position") == 2,
		"Beat 1 announcements ordered by source position 1 then 2")
	_check(b1[0].get("target_position") == 3 and b1[0].get("status") == "weak" and b1[0].get("amount") == 2,
		"Beat 1 source 1 targets Tinker (slot 3) with Weak 2")
	_check(b1[1].get("type") == "block" and b1[1].get("amount") == 3,
		"Beat 1 source 2 grants Guard 3 Block")

	_check(intents.advance_turn(), "advance turn to beat 2")
	var b2: Array = intents.get_intents()
	_check(b2 == _expected_beat_2_intents(), "Beat 2 announces expected intents")
	_check(b2.size() == 2 and b2[0].get("enemy_position") == 1 and b2[1].get("enemy_position") == 2,
		"Beat 2 announcements ordered by source position 1 then 2")
	_check(b2[0].get("type") == "shove" and b2[0].get("target_position") == 1 and b2[0].get("direction") == 1,
		"Beat 2 source 1 shoves slot 1 in direction 1")
	_check(b2[1].get("type") == "attack" and b2[1].get("amount") == 4 and b2[1].get("target_position") == 1,
		"Beat 2 source 2 attacks slot 1 for base 4")

	_check(intents.advance_turn(), "advance turn to beat 3")
	var b3: Array = intents.get_intents()
	_check(b3 == _expected_beat_3_intents(), "Beat 3 announces expected intents")
	_check(b3.size() == 2 and b3[0].get("enemy_position") == 1 and b3[1].get("enemy_position") == 2,
		"Beat 3 announcements ordered by source position 1 then 2")
	_check(b3[0].get("type") == "debuff" and b3[0].get("target_position") == 3
		and b3[0].get("status") == "exposed" and b3[0].get("amount") == 1,
		"Beat 3 source 1 debuffs Tinker (slot 3) with Exposed 1")
	_check(b3[1].get("type") == "attack" and b3[1].get("amount") == 4 and b3[1].get("target_position") == 3,
		"Beat 3 source 2 attacks slot 3 for base 4")

	_check(intents.advance_turn(), "advance turn to beat 4 (wrap)")
	var b4: Array = intents.get_intents()
	_check(b4 == _expected_beat_1_intents(), "Beat 4 wraps to exact Beat 1 intents")

	# Shipped enemy definitions by ID
	var raw_enemies: Array = _load_json_array(ENEMY_PATH)
	var scavenger: Dictionary = _find_unique_by_id(raw_enemies, "fray_scavenger", "run_enemies")
	var guard: Dictionary = _find_unique_by_id(raw_enemies, "button_guard", "run_enemies")
	_check(scavenger.get("name") == "Fray Scavenger" and scavenger.get("max_hp") == 14,
		"Fray Scavenger is 14 max HP")
	_check(guard.get("name") == "Button Guard" and guard.get("max_hp") == 16,
		"Button Guard is 16 max HP")
	_check(scavenger.get("art_path") == "res://assets/paper/enemies/fray_scavenger.png",
		"Fray Scavenger art_path intact")
	_check(guard.get("art_path") == "res://assets/paper/enemies/button_guard.png",
		"Button Guard art_path intact")

	# Shipped starter party by ID
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

	# Typed roster assembly with local mapping
	var typed_choice: Dictionary = {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": parsed.duplicate(true),
	}
	var roster_service: RunTypedBattleRoster = RunTypedBattleRoster.new()
	var roster_res: Dictionary = roster_service.assemble(
		typed_choice, LOCAL_ROSTER_MAP.duplicate(true), [ENEMY_PATH])
	_check(roster_res.get("ok") == true, "RunTypedBattleRoster.assemble succeeds with local mapping")
	_check(roster_res.get("node_type") == "Fight", "roster assembly node_type is Fight")
	_check(roster_res.get("encounter_id") == ENCOUNTER_ID, "roster assembly encounter_id matches")
	var assembled_enemies: CombatEnemies = roster_res.get("enemies")
	_check(assembled_enemies != null and assembled_enemies.is_valid(), "assembled CombatEnemies is valid")
	_check(assembled_enemies.get_enemies().size() == 2, "assembled CombatEnemies has 2 enemies")
	_check(assembled_enemies.get_enemy(1).get("id") == "fray_scavenger"
		and assembled_enemies.get_enemy(1).get("max_hp") == 14,
		"assembled slot 1 is Fray Scavenger (14 max HP)")
	_check(assembled_enemies.get_enemy(2).get("id") == "button_guard"
		and assembled_enemies.get_enemy(2).get("max_hp") == 16,
		"assembled slot 2 is Button Guard (16 max HP)")

	# Named earlier encounters still parse without assuming fixed pool sizes or ordering
	var buttonfront_defs: Array = RunFightEncounterSelection._parse_schedule_text(_read_text(BUTTONFRONT_PATH))
	_check(buttonfront_defs.size() == 2, "buttonfront_pinfall parses into 2 sources")
	_check(CombatEnemyIntents.new(buttonfront_defs).is_valid(), "buttonfront_pinfall produces valid CombatEnemyIntents")

	var guardspool_defs: Array = RunFightEncounterSelection._parse_schedule_text(_read_text(GUARDSPOOL_PATH))
	_check(guardspool_defs.size() == 2, "guardspool_exposed_turnabout parses into 2 sources")
	_check(CombatEnemyIntents.new(guardspool_defs).is_valid(), "guardspool_exposed_turnabout produces valid CombatEnemyIntents")


## AC2: assemble real CombatParty/CombatEnemies, grant Warden 6 Block via CombatStartingBlock,
## drive CombatEnemyPhase with Beat 1 then Beat 2 then Beat 3 announcements; compare source-ordered
## events, named hero positions/HP/Block and Guard Block with consequences. Explicitly omit player actions
## in that fixture; separately use CombatStatusTurnBatch to test Weak 2 -> 1 at owner turn-end.
func _test_ac2_real_combat_enemy_phase_and_status() -> void:
	var party: CombatParty = _build_starter_party()
	var enemies: CombatEnemies = _build_fraybutton_enemies()
	var definitions: Array = RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	var intents: CombatEnemyIntents = CombatEnemyIntents.new(definitions)
	var phase: CombatEnemyPhase = CombatEnemyPhase.new()

	_check(party.is_valid() and enemies.is_valid() and intents.is_valid(), "preconditions valid")

	var starting_block: CombatStartingBlock = CombatStartingBlock.new(party)
	_check(starting_block.apply(), "Warden receives opening 6 Block")
	_check(not starting_block.apply(), "second CombatStartingBlock.apply fails closed")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6,
		"Warden starts at 40 HP and 6 Block at position 1")
	_check(party.get_hero(2).get("hp") == 30 and party.get_hero(2).get("block") == 0,
		"Seamstress starts at 30 HP and 0 Block at position 2")
	_check(party.get_hero(3).get("hp") == 26 and party.get_hero(3).get("block") == 0,
		"Tinker starts at 26 HP and 0 Block at position 3")

	var original_warden: Dictionary = party._heroes[0]
	var original_seamstress: Dictionary = party._heroes[1]
	var original_tinker: Dictionary = party._heroes[2]

	# BEAT 1: Fray Scavenger debuffs Tinker (slot 3) with Weak 2; Button Guard gains 3 Block.
	# (Explicitly omitting player actions in this fixture as specified by the brief)
	var b1_intents: Array = intents.get_intents()
	_check(b1_intents == _expected_beat_1_intents(), "Beat 1 intents match expected")
	var b1_res: Dictionary = phase.execute_phase(party, enemies, b1_intents)
	_check(b1_res.get("ok") == true, "Beat 1 phase execution succeeds")
	_check(b1_res.get("events") == [
		{"type": "debuff", "enemy_position": 1, "applied": true, "target_position": 3, "status": "weak"},
		{"type": "block", "enemy_position": 2, "applied": true},
	], "Beat 1 events match ascending source order: debuff(pos 1) then block(pos 2)")

	_check(enemies.get_enemy(1).get("block") == 0, "Fray Scavenger has 0 Block")
	_check(enemies.get_enemy(2).get("block") == 3, "Button Guard has 3 Block after Beat 1")

	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 6 and party.get_hero(1).get("statuses", {}) == {},
		"Warden remains at position 1 with 40 HP, 6 Block, no status")
	_check(party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 30
		and party.get_hero(2).get("block") == 0 and party.get_hero(2).get("statuses", {}) == {},
		"Seamstress remains at position 2 with 30 HP, 0 Block, no status")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("block") == 0 and party.get_hero(3).get("statuses") == {"weak": 2},
		"Tinker at position 3 has 26 HP, 0 Block, and Weak 2")

	# BEAT 2: Fray Scavenger shoves slot 1 in direction 1 (swapping Warden and Seamstress);
	# Button Guard attacks position 1 (now Seamstress) dealing base 4 damage (30 -> 26 HP).
	# Warden moves to position 2 with his surviving 6 Block.
	_check(intents.advance_turn(), "advance turn to Beat 2")
	var b2_intents: Array = intents.get_intents()
	_check(b2_intents == _expected_beat_2_intents(), "Beat 2 intents match expected")
	var b2_res: Dictionary = phase.execute_phase(party, enemies, b2_intents)
	_check(b2_res.get("ok") == true, "Beat 2 phase execution succeeds")
	_check(b2_res.get("events") == [
		{"type": "shove", "enemy_position": 1, "applied": true, "target_position": 1, "direction": 1},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 1},
	], "Beat 2 events match ascending source order: shove(pos 1) then attack(pos 2)")

	_check(party.get_hero(1).get("id") == "seamstress" and party.get_hero(1).get("hp") == 26
		and party.get_hero(1).get("block") == 0,
		"Seamstress is now at position 1, took 4 damage: 30 -> 26 HP, 0 Block")
	_check(party.get_hero(2).get("id") == "warden" and party.get_hero(2).get("hp") == 40
		and party.get_hero(2).get("block") == 6,
		"Warden moved to position 2 with his surviving 6 Block and 40 HP")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("statuses") == {"weak": 2},
		"Tinker remains at position 3 with 26 HP and Weak 2")
	_check(is_same(party._heroes[0], original_seamstress) and is_same(party._heroes[1], original_warden)
		and is_same(party._heroes[2], original_tinker), "hero dictionary identities preserved across swap")
	_check(enemies.get_enemy(2).get("block") == 3, "Button Guard retains 3 Block")

	# BEAT 3: Fray Scavenger applies Exposed 1 to rear Tinker; Button Guard attacks position 3
	# for base 4 raised to floor(4 * 1.5) = 6, unblocked Tinker goes 26 -> 20 HP.
	_check(intents.advance_turn(), "advance turn to Beat 3")
	var b3_intents: Array = intents.get_intents()
	_check(b3_intents == _expected_beat_3_intents(), "Beat 3 intents match expected")

	# Confirm Exposed damage formula in isolation
	_check(CombatStatuses.new().adjusted_attack_damage(4, {}, {"exposed": 1}) == 6,
		"base 4 attack against Exposed 1 yields floor(4 * 1.5) = 6 damage")

	var b3_res: Dictionary = phase.execute_phase(party, enemies, b3_intents)
	_check(b3_res.get("ok") == true, "Beat 3 phase execution succeeds")
	_check(b3_res.get("events") == [
		{"type": "debuff", "enemy_position": 1, "applied": true, "target_position": 3, "status": "exposed"},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 3},
	], "Beat 3 events match ascending source order: debuff(pos 1) then attack(pos 2)")

	_check(party.get_hero(1).get("id") == "seamstress" and party.get_hero(1).get("hp") == 26
		and party.get_hero(1).get("block") == 0, "Seamstress at position 1 remains 26 HP, 0 Block")
	_check(party.get_hero(2).get("id") == "warden" and party.get_hero(2).get("hp") == 40
		and party.get_hero(2).get("block") == 6, "Warden at position 2 remains 40 HP, 6 Block")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 20
		and party.get_hero(3).get("block") == 0
		and party.get_hero(3).get("statuses") == {"weak": 2, "exposed": 1},
		"Tinker took 6 damage (26 -> 20 HP) under Exposed 1, holds Weak 2 and Exposed 1")
	_check(enemies.get_enemy(2).get("block") == 3, "Button Guard Block remains 3")

	# SEPARATE REAL CombatStatusTurnBatch OWNER-TURN FIXTURE:
	# Test Weak 2 -> Weak 1 tick at owner turn-end using the real status service
	var batch_party: CombatParty = _build_starter_party()
	batch_party._heroes[2]["statuses"] = {"weak": 2}
	_check(batch_party.get_hero(3).get("statuses") == {"weak": 2},
		"batch fixture precondition: Tinker has Weak 2")

	var turn_batch: CombatStatusTurnBatch = CombatStatusTurnBatch.new()
	var tick1: Dictionary = turn_batch.tick_side("heroes", batch_party.get_heroes())
	_check(tick1.get("ok") == true, "CombatStatusTurnBatch.tick_side succeeds for heroes")
	var ticked_actors1: Array = tick1.get("actors", [])
	_check(ticked_actors1.size() == 3, "ticked heroes count is 3")
	var ticked_tinker1: Dictionary = ticked_actors1[2]
	_check(ticked_tinker1.get("id") == "tinker" and ticked_tinker1.get("statuses") == {"weak": 1},
		"Weak 2 decrements to Weak 1 at owner turn-end on detached batch result")
	_check(batch_party.get_hero(3).get("statuses") == {"weak": 2},
		"CombatParty remains unmutated by detached tick result (Lesson 22)")

	# Second owner turn tick: Weak 1 expires
	var tick2: Dictionary = turn_batch.tick_side("heroes", ticked_actors1)
	_check(tick2.get("ok") == true, "second CombatStatusTurnBatch.tick_side succeeds")
	var ticked_actors2: Array = tick2.get("actors", [])
	var ticked_tinker2: Dictionary = ticked_actors2[2]
	_check(ticked_tinker2.get("statuses") == {}, "Weak 1 expires to empty status dict on second tick")

	# Fresh isolated fixture for Beat 2
	var party_iso2: CombatParty = _build_starter_party()
	var enemies_iso2: CombatEnemies = _build_fraybutton_enemies()
	_check(CombatStartingBlock.new(party_iso2).apply(), "isolated Beat 2 Warden receives starting Block")
	var iso2_res: Dictionary = phase.execute_phase(party_iso2, enemies_iso2, _expected_beat_2_intents())
	_check(iso2_res.get("ok") == true, "isolated Beat 2 phase succeeds")
	_check(party_iso2.get_hero(1).get("id") == "seamstress" and party_iso2.get_hero(1).get("hp") == 26,
		"isolated Beat 2: Seamstress moved to 1 and took 4 damage (30 -> 26 HP)")
	_check(party_iso2.get_hero(2).get("id") == "warden" and party_iso2.get_hero(2).get("hp") == 40
		and party_iso2.get_hero(2).get("block") == 6,
		"isolated Beat 2: Warden moved to 2 with 6 Block intact")

	# Fresh isolated fixture for Beat 3
	var party_iso3: CombatParty = _build_starter_party()
	var enemies_iso3: CombatEnemies = _build_fraybutton_enemies()
	var iso3_res: Dictionary = phase.execute_phase(party_iso3, enemies_iso3, _expected_beat_3_intents())
	_check(iso3_res.get("ok") == true, "isolated Beat 3 phase succeeds")
	_check(party_iso3.get_hero(3).get("id") == "tinker" and party_iso3.get_hero(3).get("hp") == 20
		and party_iso3.get_hero(3).get("statuses") == {"exposed": 1},
		"isolated Beat 3: Tinker took 6 damage (26 -> 20 HP) under newly applied Exposed 1")

	# Timeline replay from fresh instance (Lesson 4)
	var fresh_intents: CombatEnemyIntents = CombatEnemyIntents.new(definitions)
	_check(fresh_intents.get_intents() == _expected_beat_1_intents(), "replay beat 1")
	_check(fresh_intents.advance_turn() and fresh_intents.get_intents() == _expected_beat_2_intents(), "replay beat 2")
	_check(fresh_intents.advance_turn() and fresh_intents.get_intents() == _expected_beat_3_intents(), "replay beat 3")
	_check(fresh_intents.advance_turn() and fresh_intents.get_intents() == _expected_beat_1_intents(), "replay beat 4 wrap")


## AC3: seeded RunMap with legally selected Fight node, test-local Fight pool
## containing only fraybutton_shuttle_volley, local roster binding [fray_scavenger, button_guard];
## selector returns and caches this exact schedule without second RNG draw;
## RunTypedBattleRoster.assemble produces those two ordered shipped enemies;
## unadmitted/non-Fight attempts fail closed without advancing RNG;
## displacement negative tests (Lesson 38) and slain-source skips.
func _test_ac3_run_map_selection_and_fail_closed() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = MAP_SEED
	var map: RunMap = RunMap.new()
	_check(map.generate(rng), "RunMap generates with seeded RNG")

	var selector: RunFightEncounterSelection = RunFightEncounterSelection.new()
	var test_local_pool: Dictionary = {
		"Fight": {ENCOUNTER_ID: ENCOUNTER_PATH},
	}

	# 1. Preselection rejection before choosing node: fails closed without advancing RNG
	var rng_state_before: int = rng.state
	var reject_unchosen: Dictionary = selector.select_current_battle(map, rng, test_local_pool)
	_check(reject_unchosen == {"success": false}, "preselection without chosen node rejects")
	_check(rng.state == rng_state_before, "preselection rejection does not advance RNG")

	# Find a legal Fight node
	var fight_id: String = ""
	for candidate: String in map.get_legal_choices():
		if map.get_node(candidate).get("type") == "Fight":
			fight_id = candidate
			break
	_check(not fight_id.is_empty(), "found legal opening Fight node on generated map")

	# Attempt with non-Fight node or invalid pool before legal choice
	var reject_empty: Dictionary = selector.select_current_battle(map, rng, {})
	_check(reject_empty == {"success": false}, "empty pools_by_type rejects")
	_check(rng.state == rng_state_before, "empty pool rejection does not advance RNG")

	# Choose the legal Fight node
	_check(map.choose_node(fight_id), "map chooses opening Fight node")
	_check(map.get_current_node_id() == fight_id, "current node is chosen Fight node")

	# Attempt with unadmitted/missing pool type (e.g. pool has only Elite)
	rng_state_before = rng.state
	var reject_wrong_type: Dictionary = selector.select_current_battle(map, rng, {
		"Elite": {ENCOUNTER_ID: ENCOUNTER_PATH},
	})
	_check(reject_wrong_type == {"success": false}, "missing chosen kind's pool rejects")
	_check(rng.state == rng_state_before, "missing pool type rejection does not advance RNG")

	# 2. Valid selection with test-local pool: exactly one RNG draw
	var choice: Dictionary = selector.select_current_battle(map, rng, test_local_pool)
	_check(choice.get("success") == true, "select_current_battle succeeds with test-local Fight pool")
	_check(choice.get("node_type") == "Fight", "selected node_type is Fight")
	_check(choice.get("encounter_id") == ENCOUNTER_ID, "selected encounter_id matches " + ENCOUNTER_ID)
	_check(choice.get("definitions") == _expected_definitions(), "selected definitions match authored schedule")

	# 3. Cached re-query: returns identical choice and draws zero extra RNG
	var rng_state_after_choice: int = rng.state
	var cached_choice: Dictionary = selector.select_current_battle(map, rng, test_local_pool)
	_check(rng.state == rng_state_after_choice, "cached re-read consumed zero RNG draws")
	_check(cached_choice == choice, "cached re-read matches original choice")

	# Cached re-query also works via select_current_fight
	var cached_fight: Dictionary = selector.select_current_fight(map, rng, test_local_pool["Fight"])
	_check(cached_fight.get("success") == true and cached_fight.get("encounter_id") == ENCOUNTER_ID,
		"cached re-query works via select_current_fight")
	_check(rng.state == rng_state_after_choice, "cached select_current_fight consumes zero RNG draws")

	# Result isolation: mutating returned dictionary does not corrupt cached data
	cached_choice["encounter_id"] = "corrupted"
	var cached_recheck: Dictionary = selector.select_current_battle(map, rng, test_local_pool)
	_check(cached_recheck.get("encounter_id") == ENCOUNTER_ID, "cached selection remains uncorrupted")

	# 4. RunTypedBattleRoster.assemble produces the two ordered shipped enemies
	var roster_res: Dictionary = RunTypedBattleRoster.new().assemble(
		choice, LOCAL_ROSTER_MAP.duplicate(true), [ENEMY_PATH])
	_check(roster_res.get("ok") == true, "RunTypedBattleRoster.assemble succeeds")
	_check(roster_res.get("node_type") == "Fight", "assembled node_type is Fight")
	_check(roster_res.get("encounter_id") == ENCOUNTER_ID, "assembled encounter_id matches")
	var assembled_enemies: CombatEnemies = roster_res.get("enemies")
	_check(assembled_enemies != null and assembled_enemies.is_valid(), "assembled CombatEnemies is valid")
	_check(assembled_enemies.get_enemies().size() == 2, "assembled CombatEnemies has 2 enemies")
	_check(assembled_enemies.get_enemy(1).get("id") == "fray_scavenger"
		and assembled_enemies.get_enemy(1).get("max_hp") == 14
		and assembled_enemies.get_enemy(1).get("hp") == 14 and assembled_enemies.get_enemy(1).get("block") == 0,
		"assembled slot 1 is Fray Scavenger at 14/14 HP, 0 Block")
	_check(assembled_enemies.get_enemy(2).get("id") == "button_guard"
		and assembled_enemies.get_enemy(2).get("max_hp") == 16
		and assembled_enemies.get_enemy(2).get("hp") == 16 and assembled_enemies.get_enemy(2).get("block") == 0,
		"assembled slot 2 is Button Guard at 16/16 HP, 0 Block")

	# 5. Deterministic replay with identical seed (Lesson 8)
	var rng_replay: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_replay.seed = MAP_SEED
	var map_replay: RunMap = RunMap.new()
	_check(map_replay.generate(rng_replay), "RunMap replay generates identically")
	_check(map_replay.choose_node(fight_id), "map replay chooses same opening Fight node")
	var selector_replay: RunFightEncounterSelection = RunFightEncounterSelection.new()
	var choice_replay: Dictionary = selector_replay.select_current_battle(map_replay, rng_replay, test_local_pool)
	_check(choice_replay == choice, "identical seed replays identical selection result")
	_check(rng_replay.state == rng_state_after_choice, "identical seed leaves matching RNG state")

	# 6. Displacement negative tests (Lesson 38):
	# Downing adjacent destination hero (slot 2 Seamstress) while keeping moving hero
	# (slot 1 Warden) ALIVE before Beat 2 shove.
	var phase: CombatEnemyPhase = CombatEnemyPhase.new()
	var party_downed: CombatParty = _build_starter_party()
	var enemies_downed: CombatEnemies = _build_fraybutton_enemies()
	_check(CombatStartingBlock.new(party_downed).apply(), "Warden gets starting Block")

	# Down adjacent destination hero (slot 2 Seamstress: 30 damage)
	_check(party_downed.apply_damage(2, 30), "down Seamstress at slot 2")
	_check(party_downed.is_downed(2) and party_downed.get_hero(2).get("hp") == 0,
		"precondition: destination hero at slot 2 is downed")
	_check(not party_downed.is_downed(1) and party_downed.get_hero(1).get("hp") == 40
		and party_downed.get_hero(1).get("block") == 6,
		"precondition: moving hero at slot 1 is ALIVE with 40 HP and 6 Block (Lesson 38)")

	var heroes_snap: Array[Dictionary] = party_downed.get_heroes()
	var enemies_snap: Array[Dictionary] = enemies_downed.get_enemies()
	var b2_intents_copy: Array = _expected_beat_2_intents().duplicate(true)

	var reject_downed_dest: Dictionary = phase.execute_phase(party_downed, enemies_downed, b2_intents_copy)
	_check(reject_downed_dest == {"ok": false, "events": []},
		"shove targeting downed destination hero rejects phase atomically")
	_check(party_downed.get_heroes() == heroes_snap, "heroes unchanged on destination-downed shove rejection")
	_check(enemies_downed.get_enemies() == enemies_snap, "enemies unchanged on destination-downed shove rejection")

	# Downing the mover hero (slot 1 Warden downed, destination slot 2 alive)
	var party_downed_mover: CombatParty = _build_starter_party()
	var enemies_downed_mover: CombatEnemies = _build_fraybutton_enemies()
	_check(party_downed_mover.apply_damage(1, 40), "down Warden at slot 1")
	_check(party_downed_mover.is_downed(1) and not party_downed_mover.is_downed(2),
		"precondition: mover is downed, destination is alive")
	var mover_heroes_snap: Array[Dictionary] = party_downed_mover.get_heroes()
	var mover_enemies_snap: Array[Dictionary] = enemies_downed_mover.get_enemies()
	_check(phase.execute_phase(party_downed_mover, enemies_downed_mover, b2_intents_copy) == {"ok": false, "events": []},
		"shove with downed mover hero rejects atomically")
	_check(party_downed_mover.get_heroes() == mover_heroes_snap
		and enemies_downed_mover.get_enemies() == mover_enemies_snap,
		"snapshots unchanged when mover is downed")

	# Invalid shove direction / out-of-bounds target fails closed
	var invalid_shove: Array[Dictionary] = [
		{"type": "shove", "enemy_position": 1, "amount": 0, "target_position": 1, "direction": -1},
	]
	var party_clean: CombatParty = _build_starter_party()
	var enemies_clean: CombatEnemies = _build_fraybutton_enemies()
	var clean_snap: Array[Dictionary] = party_clean.get_heroes()
	_check(phase.execute_phase(party_clean, enemies_clean, invalid_shove) == {"ok": false, "events": []},
		"out-of-bounds shove (pos 1 dir -1) rejects atomically")
	_check(party_clean.get_heroes() == clean_snap, "heroes unchanged on out-of-bounds shove")

	# Downed debuff recipient (Tinker downed before Beat 1 debuff)
	var party_downed_debuff: CombatParty = _build_starter_party()
	var enemies_downed_debuff: CombatEnemies = _build_fraybutton_enemies()
	_check(party_downed_debuff.apply_damage(3, 26), "down Tinker at slot 3")
	_check(party_downed_debuff.is_downed(3), "precondition: Tinker is downed")
	var debuff_heroes_snap: Array[Dictionary] = party_downed_debuff.get_heroes()
	var debuff_enemies_snap: Array[Dictionary] = enemies_downed_debuff.get_enemies()
	var reject_downed_debuff: Dictionary = phase.execute_phase(
		party_downed_debuff, enemies_downed_debuff, _expected_beat_1_intents())
	_check(reject_downed_debuff == {"ok": false, "events": []},
		"debuff targeting downed hero rejects phase atomically")
	_check(party_downed_debuff.get_heroes() == debuff_heroes_snap,
		"heroes unchanged on downed-target debuff rejection")
	_check(enemies_downed_debuff.get_enemies() == debuff_enemies_snap,
		"enemies unchanged on downed-target debuff rejection")
	_check(enemies_downed_debuff.get_enemy(2).get("block") == 0,
		"Button Guard does not gain Block when phase is rejected")

	# 7. Slain-source skips:
	# Case A: Source 1 (Fray Scavenger) is slain before Beat 1.
	var party_slain_1: CombatParty = _build_starter_party()
	var enemies_slain_1: CombatEnemies = _build_fraybutton_enemies()
	_check(CombatStartingBlock.new(party_slain_1).apply(), "Warden gets starting Block")
	_check(enemies_slain_1.apply_damage(1, 14) and enemies_slain_1.is_slain(1),
		"Fray Scavenger slain before Beat 1")
	var slain_1_res: Dictionary = phase.execute_phase(party_slain_1, enemies_slain_1, _expected_beat_1_intents())
	_check(slain_1_res.get("ok") == true, "phase succeeds with slain Source 1")
	_check(slain_1_res.get("events") == [
		{"type": "debuff", "enemy_position": 1, "applied": false, "target_position": 3, "status": "weak"},
		{"type": "block", "enemy_position": 2, "applied": true},
	], "Source 1 debuff is skipped (applied: false), living Source 2 block is applied")
	_check(enemies_slain_1.get_enemy(2).get("block") == 3, "living Button Guard gains 3 Block")
	_check(party_slain_1.get_hero(3).get("statuses", {}) == {}, "Tinker receives no Weak from slain source")

	# Case B: Source 2 (Button Guard) is slain before Beat 2.
	var party_slain_2: CombatParty = _build_starter_party()
	var enemies_slain_2: CombatEnemies = _build_fraybutton_enemies()
	_check(CombatStartingBlock.new(party_slain_2).apply(), "Warden gets starting Block")
	_check(enemies_slain_2.apply_damage(2, 16) and enemies_slain_2.is_slain(2),
		"Button Guard slain before Beat 2")
	var slain_2_res: Dictionary = phase.execute_phase(party_slain_2, enemies_slain_2, _expected_beat_2_intents())
	_check(slain_2_res.get("ok") == true, "phase succeeds with slain Source 2")
	_check(slain_2_res.get("events") == [
		{"type": "shove", "enemy_position": 1, "applied": true, "target_position": 1, "direction": 1},
		{"type": "attack", "enemy_position": 2, "applied": false, "target_position": 1},
	], "living Source 1 shove is applied, slain Source 2 attack is skipped (applied: false)")
	_check(party_slain_2.get_hero(1).get("id") == "seamstress" and party_slain_2.get_hero(1).get("hp") == 30,
		"living Fray Scavenger shoves Seamstress to 1, but slain Guard does not attack: 30 HP intact")

	# Case C: Source 1 (Fray Scavenger) is slain before Beat 3.
	var party_slain_3: CombatParty = _build_starter_party()
	var enemies_slain_3: CombatEnemies = _build_fraybutton_enemies()
	_check(enemies_slain_3.apply_damage(1, 14) and enemies_slain_3.is_slain(1),
		"Fray Scavenger slain before Beat 3")
	var slain_3_res: Dictionary = phase.execute_phase(party_slain_3, enemies_slain_3, _expected_beat_3_intents())
	_check(slain_3_res.get("ok") == true, "phase succeeds with slain Source 1 on Beat 3")
	_check(slain_3_res.get("events") == [
		{"type": "debuff", "enemy_position": 1, "applied": false, "target_position": 3, "status": "exposed"},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 3},
	], "Source 1 debuff skipped (applied: false), living Guard attacks slot 3")
	_check(party_slain_3.get_hero(3).get("id") == "tinker" and party_slain_3.get_hero(3).get("hp") == 22
		and party_slain_3.get_hero(3).get("statuses", {}) == {},
		"Tinker takes base 4 damage (26 -> 22 HP) without Exposed amplification because debuff was skipped")

	# 8. Malformed parser inputs fail closed
	_check(RunFightEncounterSelection._parse_schedule_text("").is_empty(), "empty text rejected")
	_check(RunFightEncounterSelection._parse_schedule_text("[]").is_empty(), "empty array rejected")
	_check(RunFightEncounterSelection._parse_schedule_text("[{}]").is_empty(), "empty dict rejected")
	_check(RunFightEncounterSelection._parse_schedule_text("invalid json").is_empty(), "invalid json rejected")
