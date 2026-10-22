extends SceneTree

## Deterministic headless regression for the authored standalone M04 Fight
## fraycoil_weakback_switch: slot 1 Fray Scavenger (14 max HP) and slot 2 Seam Ripper (18 max HP).
## Beat 1: Fray Scavenger debuffs Tinker (slot 3) with Weak 1; Seam Ripper attacks
##   Seamstress (slot 2) dealing unblocked 4 damage (30 -> 26 HP).
## Beat 2: Fray Scavenger attacks Warden (slot 1) for 3; Warden's opening 6 Block absorbs
##   all 3 damage (Block 6 -> 3, HP intact at 40); Seam Ripper debuffs Warden with Bleed 2.
## Beat 3: Fray Scavenger shoves slot 2 in direction 1, swapping living Seamstress (slot 2 -> 3)
##   and Tinker (slot 3 -> 2); Tinker retains Weak 1 in slot 2. Then Seam Ripper attacks
##   slot 3 (now Seamstress) dealing 4 damage (26 -> 22 HP).
## Standalone encounter data and service verification; not wired into live battle pools.

const ENCOUNTER_PATH := "res://data/encounters/fraycoil_weakback_switch.json"
const ENCOUNTER_ID := "fraycoil_weakback_switch"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMY_PATH := "res://data/enemies/run_enemies.json"
const FRONTSEAM_PATH := "res://data/encounters/frontseam_bleed_puncture.json"
const REARHOOK_PATH := "res://data/encounters/rearhook_markshift.json"

const LOCAL_ROSTER_MAP := {
	ENCOUNTER_ID: ["fray_scavenger", "seam_ripper"],
}

const MAP_SEED := 91733
const REPLAY_SEED := 20261022

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_verify_failure_harness()
	var definitions: Array = _test_ac1_authored_schedule_and_intents()
	_test_ac2_genuine_roster_and_opening_state(definitions)
	_test_ac3_resolved_tactical_beats_and_negative_cases(definitions)
	_test_ac4_seeded_standalone_selection_and_replay(definitions)
	if failures.is_empty():
		print("fraycoil_weakback_switch_encounter_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("fraycoil_weakback_switch_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


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
		if entry is Dictionary and (entry as Dictionary).get("id") == target_id:
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
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
			{"type": "attack", "amount": 3, "target_position": 1},
			{"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
		]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 4, "target_position": 2},
			{"type": "debuff", "amount": 2, "target_position": 1, "status": "bleed"},
			{"type": "attack", "amount": 4, "target_position": 3},
		]},
	]


func _expected_beat_1_intents() -> Array:
	return [
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak", "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 2, "enemy_position": 2},
	]


func _expected_beat_2_intents() -> Array:
	return [
		{"type": "attack", "amount": 3, "target_position": 1, "enemy_position": 1},
		{"type": "debuff", "amount": 2, "target_position": 1, "status": "bleed", "enemy_position": 2},
	]


func _expected_beat_3_intents() -> Array:
	return [
		{"type": "shove", "amount": 0, "target_position": 2, "direction": 1, "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 3, "enemy_position": 2},
	]


func _build_starter_party() -> CombatParty:
	var raw_heroes: Array = _load_json_array(PARTY_PATH)
	var warden: Dictionary = _find_unique_by_id(raw_heroes, "warden", "starter_party")
	var seamstress: Dictionary = _find_unique_by_id(raw_heroes, "seamstress", "starter_party")
	var tinker: Dictionary = _find_unique_by_id(raw_heroes, "tinker", "starter_party")
	return CombatParty.new([warden, seamstress, tinker])


func _build_fraycoil_enemies() -> CombatEnemies:
	var raw_enemies: Array = _load_json_array(ENEMY_PATH)
	var scavenger: Dictionary = _find_unique_by_id(raw_enemies, "fray_scavenger", "run_enemies")
	var ripper: Dictionary = _find_unique_by_id(raw_enemies, "seam_ripper", "run_enemies")
	return CombatEnemies.new([scavenger, ripper])


## AC1 — Authored schedule: loading fraycoil_weakback_switch returns precisely two valid
## enemy source positions (1 and 2), each with the three beats specified, and named earlier
## encounter files remain independently parseable.
func _test_ac1_authored_schedule_and_intents() -> Array:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "authored encounter file exists at " + ENCOUNTER_PATH)
	_check(ENCOUNTER_PATH.get_file().get_basename() == ENCOUNTER_ID,
		"encounter file basename matches ID " + ENCOUNTER_ID)

	var raw_text: String = _read_text(ENCOUNTER_PATH)
	_check(not raw_text.strip_edges().is_empty(), "encounter file is not empty")

	var raw_array: Array = _load_json_array(ENCOUNTER_PATH)
	_check(raw_array.size() == 2, "raw encounter holds exactly 2 source definitions")
	var positions: Array[int] = []
	for raw_def: Variant in raw_array:
		_check(raw_def is Dictionary, "source definition is a Dictionary")
		if not raw_def is Dictionary:
			continue
		var raw_dict: Dictionary = raw_def as Dictionary
		_check(raw_dict.size() == 2, "each source contains only enemy_position and pattern")
		_check(raw_dict.has("enemy_position") and raw_dict.has("pattern"),
			"definition has enemy_position and pattern")
		_check(_is_integral_number(raw_dict.get("enemy_position")), "enemy_position is integral number")
		if _is_integral_number(raw_dict.get("enemy_position")):
			positions.append(int(raw_dict["enemy_position"]))
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
	_check(positions == [1, 2], "authored sources ordered by ascending enemy_position 1, 2")

	# Parse schedule with real RunFightEncounterSelection parser
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

	# CombatEnemyIntents validation and turn advancement / wrap
	var intents: CombatEnemyIntents = CombatEnemyIntents.new(parsed)
	_check(intents.is_valid(), "CombatEnemyIntents accepts parsed definitions")

	var b1: Array = intents.get_intents()
	_check(b1 == _expected_beat_1_intents(), "Beat 1 announces expected intents")
	_check(b1.size() == 2 and b1[0].get("enemy_position") == 1 and b1[1].get("enemy_position") == 2,
		"Beat 1 announcements ordered by source position 1 then 2")
	_check(b1[0].get("type") == "debuff" and b1[0].get("target_position") == 3
		and b1[0].get("status") == "weak" and b1[0].get("amount") == 1,
		"Beat 1 source 1 debuffs Tinker with Weak 1")
	_check(b1[1].get("type") == "attack" and b1[1].get("target_position") == 2 and b1[1].get("amount") == 4,
		"Beat 1 source 2 attacks Seamstress for 4")

	_check(intents.advance_turn(), "advance turn to beat 2")
	var b2: Array = intents.get_intents()
	_check(b2 == _expected_beat_2_intents(), "Beat 2 announces expected intents")
	_check(b2.size() == 2 and b2[0].get("enemy_position") == 1 and b2[1].get("enemy_position") == 2,
		"Beat 2 announcements ordered by source position 1 then 2")
	_check(b2[0].get("type") == "attack" and b2[0].get("target_position") == 1 and b2[0].get("amount") == 3,
		"Beat 2 source 1 attacks Warden for 3")
	_check(b2[1].get("type") == "debuff" and b2[1].get("target_position") == 1
		and b2[1].get("status") == "bleed" and b2[1].get("amount") == 2,
		"Beat 2 source 2 debuffs Warden with Bleed 2")

	_check(intents.advance_turn(), "advance turn to beat 3")
	var b3: Array = intents.get_intents()
	_check(b3 == _expected_beat_3_intents(), "Beat 3 announces expected intents")
	_check(b3.size() == 2 and b3[0].get("enemy_position") == 1 and b3[1].get("enemy_position") == 2,
		"Beat 3 announcements ordered by source position 1 then 2")
	_check(b3[0].get("type") == "shove" and b3[0].get("target_position") == 2 and b3[0].get("direction") == 1,
		"Beat 3 source 1 shoves slot 2 in direction 1 (2 -> 3 swap)")
	_check(b3[1].get("type") == "attack" and b3[1].get("target_position") == 3 and b3[1].get("amount") == 4,
		"Beat 3 source 2 attacks slot 3 for 4")

	_check(intents.advance_turn(), "advance turn to beat 4 (wrap)")
	var b4: Array = intents.get_intents()
	_check(b4 == _expected_beat_1_intents(), "Beat 4 wraps to exact Beat 1 intents")

	# Named earlier encounters remain independently parseable and valid (Lesson 9)
	var frontseam_raw: String = _read_text(FRONTSEAM_PATH)
	var frontseam_defs: Array = RunFightEncounterSelection._parse_schedule_text(frontseam_raw)
	_check(frontseam_defs.size() == 2, "frontseam_bleed_puncture parses into 2 sources")
	_check(CombatEnemyIntents.new(frontseam_defs).is_valid(),
		"frontseam_bleed_puncture produces valid CombatEnemyIntents")
	_check(frontseam_defs[0].get("enemy_position") == 1 and frontseam_defs[0].get("pattern").size() == 3,
		"frontseam source 1 has 3 beats")
	_check(frontseam_defs[1].get("enemy_position") == 2 and frontseam_defs[1].get("pattern").size() == 3,
		"frontseam source 2 has 3 beats")

	var rearhook_raw: String = _read_text(REARHOOK_PATH)
	var rearhook_defs: Array = RunFightEncounterSelection._parse_schedule_text(rearhook_raw)
	_check(rearhook_defs.size() == 2, "rearhook_markshift parses into 2 sources")
	_check(CombatEnemyIntents.new(rearhook_defs).is_valid(),
		"rearhook_markshift produces valid CombatEnemyIntents")
	_check(rearhook_defs[0].get("enemy_position") == 1 and rearhook_defs[0].get("pattern").size() == 3,
		"rearhook source 1 has 3 beats")
	_check(rearhook_defs[1].get("enemy_position") == 2 and rearhook_defs[1].get("pattern").size() == 3,
		"rearhook source 2 has 3 beats")

	# Malformed inputs fail closed (Lesson 23)
	_check(RunFightEncounterSelection._parse_schedule_text("").is_empty(), "empty string parse fails closed")
	_check(RunFightEncounterSelection._parse_schedule_text("[]").is_empty(), "empty array parse fails closed")
	_check(RunFightEncounterSelection._parse_schedule_text("[{}]").is_empty(), "empty dict parse fails closed")
	_check(RunFightEncounterSelection._parse_schedule_text("not json").is_empty(), "invalid json parse fails closed")

	return parsed


## AC2 — Genuine roster and opening state: RunTypedBattleRoster.assemble with LOCAL mapping
## produces Fray Scavenger (14 max HP) at position 1 and Seam Ripper (18 max HP) at position 2;
## CombatParty starts Warden 40 HP at 1, Seamstress 30 at 2, Tinker 26 at 3; CombatStartingBlock
## grants Warden exactly 6 initial Block.
func _test_ac2_genuine_roster_and_opening_state(definitions: Array) -> void:
	var raw_enemies: Array = _load_json_array(ENEMY_PATH)
	var scavenger: Dictionary = _find_unique_by_id(raw_enemies, "fray_scavenger", "run_enemies")
	var ripper: Dictionary = _find_unique_by_id(raw_enemies, "seam_ripper", "run_enemies")
	_check(scavenger.get("name") == "Fray Scavenger" and scavenger.get("max_hp") == 14,
		"Catalog Fray Scavenger has name 'Fray Scavenger' and 14 max HP")
	_check(scavenger.get("art_path") == "res://assets/paper/enemies/fray_scavenger.png",
		"Catalog Fray Scavenger has art_path res://assets/paper/enemies/fray_scavenger.png")
	_check(ripper.get("name") == "Seam Ripper" and ripper.get("max_hp") == 18,
		"Catalog Seam Ripper has name 'Seam Ripper' and 18 max HP")
	_check(ripper.get("art_path") == "res://assets/paper/enemies/seam_ripper.png",
		"Catalog Seam Ripper has art_path res://assets/paper/enemies/seam_ripper.png")

	var raw_heroes: Array = _load_json_array(PARTY_PATH)
	var warden: Dictionary = _find_unique_by_id(raw_heroes, "warden", "starter_party")
	var seamstress: Dictionary = _find_unique_by_id(raw_heroes, "seamstress", "starter_party")
	var tinker: Dictionary = _find_unique_by_id(raw_heroes, "tinker", "starter_party")
	_check(warden.get("name") == "Warden" and warden.get("max_hp") == 40,
		"Catalog Warden has name 'Warden' and 40 max HP")
	_check(seamstress.get("name") == "Seamstress" and seamstress.get("max_hp") == 30,
		"Catalog Seamstress has name 'Seamstress' and 30 max HP")
	_check(tinker.get("name") == "Tinker" and tinker.get("max_hp") == 26,
		"Catalog Tinker has name 'Tinker' and 26 max HP")

	# Assemble battle roster via RunTypedBattleRoster
	var typed_choice: Dictionary = {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": definitions.duplicate(true),
	}
	var choice_before: Dictionary = typed_choice.duplicate(true)
	var roster_map: Dictionary = LOCAL_ROSTER_MAP.duplicate(true)
	var roster_before: Dictionary = roster_map.duplicate(true)

	var roster_service: RunTypedBattleRoster = RunTypedBattleRoster.new()
	var assembled: Dictionary = roster_service.assemble(typed_choice, roster_map, [ENEMY_PATH])
	_check(typed_choice == choice_before, "RunTypedBattleRoster.assemble does not mutate typed_choice")
	_check(roster_map == roster_before, "RunTypedBattleRoster.assemble does not mutate roster_map")
	_check(assembled.get("ok") == true, "assembly succeeds with local mapping")
	_check(assembled.get("node_type") == "Fight", "assembled node_type is Fight")
	_check(assembled.get("encounter_id") == ENCOUNTER_ID, "assembled encounter_id matches " + ENCOUNTER_ID)
	_check(assembled.get("definitions") == definitions, "assembled definitions match schedule")

	var enemies: Variant = assembled.get("enemies")
	_check(enemies is CombatEnemies and (enemies as CombatEnemies).is_valid(),
		"assembled enemies is valid CombatEnemies")
	if enemies is CombatEnemies:
		var c_enemies: CombatEnemies = enemies as CombatEnemies
		_check(c_enemies.get_enemies().size() == 2, "assembled CombatEnemies has 2 enemies")
		var e1: Dictionary = c_enemies.get_enemy(1)
		var e2: Dictionary = c_enemies.get_enemy(2)
		_check(e1.get("id") == "fray_scavenger" and e1.get("max_hp") == 14 and e1.get("hp") == 14
			and e1.get("block") == 0,
			"Enemy position 1 is Fray Scavenger (14 max HP, 14 HP, 0 Block)")
		_check(e2.get("id") == "seam_ripper" and e2.get("max_hp") == 18 and e2.get("hp") == 18
			and e2.get("block") == 0,
			"Enemy position 2 is Seam Ripper (18 max HP, 18 HP, 0 Block)")

	# CombatParty initial state and CombatStartingBlock
	var party: CombatParty = _build_starter_party()
	_check(party.is_valid(), "starter CombatParty is valid")
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 0 and party.get_hero(1).get("statuses", {}) == {},
		"Opening slot 1 is Warden at 40 HP, 0 Block, no statuses")
	_check(party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 30
		and party.get_hero(2).get("block") == 0 and party.get_hero(2).get("statuses", {}) == {},
		"Opening slot 2 is Seamstress at 30 HP, 0 Block, no statuses")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("block") == 0 and party.get_hero(3).get("statuses", {}) == {},
		"Opening slot 3 is Tinker at 26 HP, 0 Block, no statuses")

	var starting_block: CombatStartingBlock = CombatStartingBlock.new(party)
	_check(starting_block.apply(), "CombatStartingBlock grants Warden opening Block")
	_check(not starting_block.apply(), "second CombatStartingBlock.apply fails closed")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6,
		"Warden has 40 HP and exactly 6 initial Block at hero position 1")
	_check(party.get_hero(2).get("hp") == 30 and party.get_hero(2).get("block") == 0,
		"Seamstress retains 30 HP and 0 Block at hero position 2")
	_check(party.get_hero(3).get("hp") == 26 and party.get_hero(3).get("block") == 0,
		"Tinker retains 26 HP and 0 Block at hero position 3")


## AC3 — Resolved tactical beats: With that valid roster, both sources alive, both swap partners alive,
## and no intervening player-turn boundary in the isolated phase fixture:
## Beat 1: Tinker gets Weak 1, Seamstress takes unblocked 4 damage (30 -> 26 HP).
## Beat 2: Warden opening Block reduced 6 -> 3 without HP loss from 3 damage; Bleed 2 applied to Warden.
## Beat 3: Seamstress shoves from slot 2 to 3 (Tinker to slot 2), Tinker's Weak 1 remains on Tinker;
##   now-slot-3 Seamstress hit for 4 more (26 -> 22 HP).
## Wrapped intents wrap back to beat 1; downed swap partner fails closed without partial mutation.
func _test_ac3_resolved_tactical_beats_and_negative_cases(definitions: Array) -> void:
	var party: CombatParty = _build_starter_party()
	var enemies: CombatEnemies = _build_fraycoil_enemies()
	var intents: CombatEnemyIntents = CombatEnemyIntents.new(definitions)
	var phase: CombatEnemyPhase = CombatEnemyPhase.new()

	_check(CombatStartingBlock.new(party).apply(), "Warden receives opening 6 Block")

	var original_warden: Dictionary = party._heroes[0]
	var original_seamstress: Dictionary = party._heroes[1]
	var original_tinker: Dictionary = party._heroes[2]

	# BEAT 1: Fray Scavenger debuffs Tinker (slot 3) with Weak 1; Seam Ripper attacks Seamstress (slot 2) for 4.
	var b1_intents: Array = intents.get_intents()
	_check(b1_intents == _expected_beat_1_intents(), "Beat 1 intents match expected")
	var b1_res: Dictionary = phase.execute_phase(party, enemies, b1_intents)
	_check(b1_res.get("ok") == true, "Beat 1 phase execution succeeds")
	_check(b1_res.get("events") == [
		{"type": "debuff", "enemy_position": 1, "applied": true, "target_position": 3, "status": "weak"},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 2},
	], "Beat 1 events: debuff(pos 1, target 3, weak) then attack(pos 2, target 2)")

	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 6 and party.get_hero(1).get("statuses", {}) == {},
		"Beat 1: Warden untouched at position 1 (40 HP, 6 Block, no statuses)")
	_check(party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 26
		and party.get_hero(2).get("block") == 0 and party.get_hero(2).get("statuses", {}) == {},
		"Beat 1: Seamstress took unblocked 4 damage (30 -> 26 HP, 0 Block)")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("block") == 0 and party.get_hero(3).get("statuses") == {"weak": 1},
		"Beat 1: Tinker gained Weak 1 (26 HP, 0 Block, statuses: {weak: 1})")
	_check(enemies.get_enemy(1).get("hp") == 14 and enemies.get_enemy(1).get("block") == 0,
		"Beat 1: Fray Scavenger at 14 HP, 0 Block")
	_check(enemies.get_enemy(2).get("hp") == 18 and enemies.get_enemy(2).get("block") == 0,
		"Beat 1: Seam Ripper at 18 HP, 0 Block")
	_check(is_same(party._heroes[0], original_warden) and is_same(party._heroes[1], original_seamstress)
		and is_same(party._heroes[2], original_tinker),
		"Beat 1: hero dictionary identities preserved")

	# BEAT 2: Fray Scavenger attacks Warden (slot 1) for 3; Seam Ripper debuffs Warden (slot 1) with Bleed 2.
	_check(intents.advance_turn(), "advance turn to Beat 2")
	var b2_intents: Array = intents.get_intents()
	_check(b2_intents == _expected_beat_2_intents(), "Beat 2 intents match expected")
	var b2_res: Dictionary = phase.execute_phase(party, enemies, b2_intents)
	_check(b2_res.get("ok") == true, "Beat 2 phase execution succeeds")
	_check(b2_res.get("events") == [
		{"type": "attack", "enemy_position": 1, "applied": true, "target_position": 1},
		{"type": "debuff", "enemy_position": 2, "applied": true, "target_position": 1, "status": "bleed"},
	], "Beat 2 events: attack(pos 1, target 1) then debuff(pos 2, target 1, bleed)")

	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 3 and party.get_hero(1).get("statuses") == {"bleed": 2},
		"Beat 2: Warden opening Block reduced 6 -> 3 without HP loss (40 HP), holds Bleed 2")
	_check(party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 26
		and party.get_hero(2).get("block") == 0 and party.get_hero(2).get("statuses", {}) == {},
		"Beat 2: Seamstress remains 26 HP, 0 Block, no statuses")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("block") == 0 and party.get_hero(3).get("statuses") == {"weak": 1},
		"Beat 2: Tinker remains 26 HP, 0 Block, holds Weak 1")
	_check(is_same(party._heroes[0], original_warden) and is_same(party._heroes[1], original_seamstress)
		and is_same(party._heroes[2], original_tinker),
		"Beat 2: hero dictionary identities preserved")

	# BEAT 3: Fray Scavenger shoves slot 2 in direction 1 (Seamstress 2 -> 3, Tinker 3 -> 2);
	# Seam Ripper attacks slot 3 (now Seamstress) dealing 4 damage (26 -> 22 HP).
	_check(intents.advance_turn(), "advance turn to Beat 3")
	var b3_intents: Array = intents.get_intents()
	_check(b3_intents == _expected_beat_3_intents(), "Beat 3 intents match expected")
	var b3_res: Dictionary = phase.execute_phase(party, enemies, b3_intents)
	_check(b3_res.get("ok") == true, "Beat 3 phase execution succeeds")
	_check(b3_res.get("events") == [
		{"type": "shove", "enemy_position": 1, "applied": true, "target_position": 2, "direction": 1},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 3},
	], "Beat 3 events: shove(pos 1, target 2, dir 1) then attack(pos 2, target 3)")

	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 3 and party.get_hero(1).get("statuses") == {"bleed": 2},
		"Beat 3: Warden at position 1 remains 40 HP, 3 Block, Bleed 2")
	_check(party.get_hero(2).get("id") == "tinker" and party.get_hero(2).get("hp") == 26
		and party.get_hero(2).get("block") == 0 and party.get_hero(2).get("statuses") == {"weak": 1},
		"Beat 3: Tinker shoved from slot 3 to 2, retains Weak 1, 26 HP, 0 Block")
	_check(party.get_hero(3).get("id") == "seamstress" and party.get_hero(3).get("hp") == 22
		and party.get_hero(3).get("block") == 0 and party.get_hero(3).get("statuses", {}) == {},
		"Beat 3: Seamstress shoved to slot 3 and took 4 damage (26 -> 22 HP, 0 Block)")
	_check(is_same(party._heroes[0], original_warden) and is_same(party._heroes[1], original_tinker)
		and is_same(party._heroes[2], original_seamstress),
		"Beat 3: hero dictionary identities moved to their new positions")

	# Intents wrap back to Beat 1
	_check(intents.advance_turn(), "advance turn past Beat 3")
	_check(intents.get_intents() == _expected_beat_1_intents(), "fourth intent query wraps to Beat 1 exactly")

	# Downed swap partner fail-closed checks (Lesson 36):
	# Case 1: Downed destination hero (slot 3 Tinker downed, slot 2 Seamstress alive) before Beat 3 shove.
	var party_downed_dest: CombatParty = _build_starter_party()
	var enemies_downed_dest: CombatEnemies = _build_fraycoil_enemies()
	_check(CombatStartingBlock.new(party_downed_dest).apply(), "starting block for destination test")
	_check(party_downed_dest.apply_damage(3, 26) and party_downed_dest.is_downed(3),
		"precondition: destination hero at slot 3 is downed")
	_check(not party_downed_dest.is_downed(2) and party_downed_dest.get_hero(2).get("hp") == 30,
		"precondition: moving hero at slot 2 is ALIVE with 30 HP (Lesson 36)")
	_check(not CombatPositionSwaps.preview_adjacent_swap(party_downed_dest, 2, 1).get("ok", true),
		"preview_adjacent_swap rejects when destination is downed")

	var dest_heroes_snap: Array[Dictionary] = party_downed_dest.get_heroes()
	var dest_enemies_snap: Array[Dictionary] = enemies_downed_dest.get_enemies()
	var reject_dest: Dictionary = phase.execute_phase(party_downed_dest, enemies_downed_dest, _expected_beat_3_intents())
	_check(reject_dest == {"ok": false, "events": []},
		"shove targeting downed destination hero rejects phase atomically")
	_check(party_downed_dest.get_heroes() == dest_heroes_snap,
		"heroes unchanged on destination-downed shove rejection")
	_check(enemies_downed_dest.get_enemies() == dest_enemies_snap,
		"enemies unchanged on destination-downed shove rejection")

	# Case 2: Downed mover hero (slot 2 Seamstress downed, slot 3 Tinker alive) before Beat 3 shove.
	var party_downed_mover: CombatParty = _build_starter_party()
	var enemies_downed_mover: CombatEnemies = _build_fraycoil_enemies()
	_check(party_downed_mover.apply_damage(2, 30) and party_downed_mover.is_downed(2),
		"precondition: mover hero at slot 2 is downed")
	_check(not party_downed_mover.is_downed(3) and party_downed_mover.get_hero(3).get("hp") == 26,
		"precondition: destination hero at slot 3 is ALIVE")
	_check(not CombatPositionSwaps.preview_adjacent_swap(party_downed_mover, 2, 1).get("ok", true),
		"preview_adjacent_swap rejects when mover is downed")

	var mover_heroes_snap: Array[Dictionary] = party_downed_mover.get_heroes()
	var mover_enemies_snap: Array[Dictionary] = enemies_downed_mover.get_enemies()
	var reject_mover: Dictionary = phase.execute_phase(party_downed_mover, enemies_downed_mover, _expected_beat_3_intents())
	_check(reject_mover == {"ok": false, "events": []},
		"shove with downed mover hero rejects phase atomically")
	_check(party_downed_mover.get_heroes() == mover_heroes_snap,
		"heroes unchanged on mover-downed shove rejection")
	_check(enemies_downed_mover.get_enemies() == mover_enemies_snap,
		"enemies unchanged on mover-downed shove rejection")

	# Invalid shove displacement checks
	var party_clean: CombatParty = _build_starter_party()
	var enemies_clean: CombatEnemies = _build_fraycoil_enemies()
	var clean_snap: Array[Dictionary] = party_clean.get_heroes()
	var invalid_shove_dir: Array[Dictionary] = [
		{"type": "shove", "enemy_position": 1, "amount": 0, "target_position": 3, "direction": 1},
	]
	_check(phase.execute_phase(party_clean, enemies_clean, invalid_shove_dir) == {"ok": false, "events": []},
		"out-of-bounds shove (pos 3 dir 1) rejects atomically")
	_check(party_clean.get_heroes() == clean_snap, "heroes unchanged on out-of-bounds shove")

	var invalid_shove_pos: Array[Dictionary] = [
		{"type": "shove", "enemy_position": 1, "amount": 0, "target_position": 4, "direction": -1},
	]
	_check(phase.execute_phase(party_clean, enemies_clean, invalid_shove_pos) == {"ok": false, "events": []},
		"out-of-bounds target_position shove rejects atomically")
	_check(party_clean.get_heroes() == clean_snap, "heroes unchanged on out-of-bounds target shove")

	# Slain source skips (Lesson 35):
	# Case A: Source 1 (Fray Scavenger) is slain before Beat 1.
	var party_slain_1: CombatParty = _build_starter_party()
	var enemies_slain_1: CombatEnemies = _build_fraycoil_enemies()
	_check(enemies_slain_1.apply_damage(1, 14) and enemies_slain_1.is_slain(1), "slay Fray Scavenger before Beat 1")
	var slain_1_res: Dictionary = phase.execute_phase(party_slain_1, enemies_slain_1, _expected_beat_1_intents())
	_check(slain_1_res.get("ok") == true, "phase succeeds with slain Source 1")
	_check(slain_1_res.get("events") == [
		{"type": "debuff", "enemy_position": 1, "applied": false, "target_position": 3, "status": "weak"},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 2},
	], "slain Source 1 debuff is skipped (applied: false), living Source 2 attacks Seamstress")
	_check(party_slain_1.get_hero(2).get("hp") == 26, "Seamstress took 4 damage from living Seam Ripper")
	_check(party_slain_1.get_hero(3).get("statuses", {}) == {}, "Tinker received no Weak from slain Fray Scavenger")

	# Case B: Source 2 (Seam Ripper) is slain before Beat 2.
	var party_slain_2: CombatParty = _build_starter_party()
	var enemies_slain_2: CombatEnemies = _build_fraycoil_enemies()
	_check(CombatStartingBlock.new(party_slain_2).apply(), "starting block for slain source 2 test")
	_check(enemies_slain_2.apply_damage(2, 18) and enemies_slain_2.is_slain(2), "slay Seam Ripper before Beat 2")
	var slain_2_res: Dictionary = phase.execute_phase(party_slain_2, enemies_slain_2, _expected_beat_2_intents())
	_check(slain_2_res.get("ok") == true, "phase succeeds with slain Source 2")
	_check(slain_2_res.get("events") == [
		{"type": "attack", "enemy_position": 1, "applied": true, "target_position": 1},
		{"type": "debuff", "enemy_position": 2, "applied": false, "target_position": 1, "status": "bleed"},
	], "living Source 1 attacks Warden (applied: true), slain Source 2 debuff is skipped (applied: false)")
	_check(party_slain_2.get_hero(1).get("block") == 3, "Warden Block reduced 6 -> 3 by living Fray Scavenger")
	_check(party_slain_2.get_hero(1).get("statuses", {}) == {}, "Warden received no Bleed from slain Seam Ripper")

	# Case C: Source 1 (Fray Scavenger) is slain before Beat 3.
	var party_slain_3: CombatParty = _build_starter_party()
	var enemies_slain_3: CombatEnemies = _build_fraycoil_enemies()
	_check(enemies_slain_3.apply_damage(1, 14) and enemies_slain_3.is_slain(1), "slay Fray Scavenger before Beat 3")
	var slain_3_res: Dictionary = phase.execute_phase(party_slain_3, enemies_slain_3, _expected_beat_3_intents())
	_check(slain_3_res.get("ok") == true, "phase succeeds with slain Source 1 on Beat 3")
	_check(slain_3_res.get("events") == [
		{"type": "shove", "enemy_position": 1, "applied": false, "target_position": 2, "direction": 1},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 3},
	], "slain Source 1 shove is skipped (applied: false), living Source 2 attacks slot 3")
	_check(party_slain_3.get_hero(2).get("id") == "seamstress" and party_slain_3.get_hero(2).get("hp") == 30,
		"Seamstress was not shoved because Source 1 was slain")
	_check(party_slain_3.get_hero(3).get("id") == "tinker" and party_slain_3.get_hero(3).get("hp") == 22,
		"Tinker remained at slot 3 and took 4 damage: 26 -> 22 HP")

	# Detached CombatStatusTurnBatch verification for Bleed and Weak rules
	var batch_party: CombatParty = _build_starter_party()
	batch_party._heroes[0]["statuses"] = {"bleed": 2}
	batch_party._heroes[0]["block"] = 3
	batch_party._heroes[2]["statuses"] = {"weak": 1}
	var turn_batch: CombatStatusTurnBatch = CombatStatusTurnBatch.new()
	var tick1: Dictionary = turn_batch.tick_side("heroes", batch_party.get_heroes())
	_check(tick1.get("ok") == true, "turn batch tick_side succeeds")
	var ticked_actors: Array = tick1.get("actors", [])
	var ticked_warden: Dictionary = ticked_actors[0]
	var ticked_tinker: Dictionary = ticked_actors[2]
	_check(ticked_warden.get("hp") == 38 and ticked_warden.get("block") == 3
		and ticked_warden.get("statuses") == {"bleed": 1},
		"Bleed 2 loses 2 HP bypassing Block (40 -> 38, Block 3 intact) and decrements to Bleed 1")
	_check(ticked_tinker.get("statuses") == {}, "Weak 1 expires on owner turn tick")
	_check(batch_party.get_hero(1).get("hp") == 40 and batch_party.get_hero(3).get("statuses") == {"weak": 1},
		"CombatParty remains unmutated by detached tick result (Lesson 20)")


## AC4 — Seeded standalone selection: With a seeded RunMap advanced to a legally reachable
## Fight and a LOCAL one-entry encounter-path dictionary, RunFightEncounterSelection selects
## this authored schedule and returns its ID/definitions; re-reading that same selection
## consumes no further RNG and reproduces the same result on a fresh seeded setup.
func _test_ac4_seeded_standalone_selection_and_replay(definitions: Array) -> void:
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

	# Attempt with empty pool before legal choice
	var reject_empty: Dictionary = selector.select_current_battle(map, rng, {})
	_check(reject_empty == {"success": false}, "empty pools_by_type rejects")
	_check(rng.state == rng_state_before, "empty pool rejection does not advance RNG")

	# Choose the legal Fight node
	_check(map.choose_node(fight_id), "map chooses opening Fight node")
	_check(map.get_current_node_id() == fight_id, "current node is chosen Fight node")

	# Attempt with unadmitted/mismatched pool type
	rng_state_before = rng.state
	var reject_wrong_type: Dictionary = selector.select_current_battle(map, rng, {
		"Elite": {ENCOUNTER_ID: ENCOUNTER_PATH},
	})
	_check(reject_wrong_type == {"success": false}, "missing chosen kind's pool rejects")
	_check(rng.state == rng_state_before, "missing pool type rejection does not advance RNG")

	# 2. Valid selection with test-local pool
	var choice: Dictionary = selector.select_current_battle(map, rng, test_local_pool)
	_check(choice.get("success") == true, "select_current_battle succeeds with test-local Fight pool")
	_check(choice.get("node_type") == "Fight", "selected node_type is Fight")
	_check(choice.get("encounter_id") == ENCOUNTER_ID, "selected encounter_id matches " + ENCOUNTER_ID)
	_check(choice.get("definitions") == definitions, "selected definitions match authored schedule")

	# 3. Cached re-query: returns identical choice and draws zero extra RNG
	var rng_state_after_choice: int = rng.state
	var cached_choice: Dictionary = selector.select_current_battle(map, rng, test_local_pool)
	_check(rng.state == rng_state_after_choice, "cached re-read consumed zero RNG draws")
	_check(cached_choice == choice, "cached re-read matches original choice")

	# Cached re-query also works via select_current_fight
	var cached_fight: Dictionary = selector.select_current_fight(map, rng, test_local_pool["Fight"])
	_check(cached_fight.get("success") == true and cached_fight.get("encounter_id") == ENCOUNTER_ID
		and cached_fight.get("definitions") == definitions,
		"cached re-query works via select_current_fight")
	_check(rng.state == rng_state_after_choice, "cached select_current_fight consumes zero RNG draws")

	# Result isolation: mutating returned dictionary does not corrupt cached data
	cached_choice["encounter_id"] = "corrupted"
	var cached_recheck: Dictionary = selector.select_current_battle(map, rng, test_local_pool)
	_check(cached_recheck.get("encounter_id") == ENCOUNTER_ID, "cached selection remains uncorrupted")

	# 4. Deterministic replay with identical seed (Lesson 6)
	var rng_replay: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_replay.seed = MAP_SEED
	var map_replay: RunMap = RunMap.new()
	_check(map_replay.generate(rng_replay), "RunMap replay generates identically")
	_check(map_replay.choose_node(fight_id), "map replay chooses same opening Fight node")
	var selector_replay: RunFightEncounterSelection = RunFightEncounterSelection.new()
	var choice_replay: Dictionary = selector_replay.select_current_battle(map_replay, rng_replay, test_local_pool)
	_check(choice_replay == choice, "identical seed replays identical selection result")
	_check(rng_replay.state == rng_state_after_choice, "identical seed leaves matching RNG state")
