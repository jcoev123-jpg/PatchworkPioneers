extends SceneTree

## Deterministic headless coverage for the authored Threadseal Marked Volley
## M04 Fight: slot 1 Spool Stalker (14 max HP) and slot 2 Seam Ripper (18 max HP).
## Beat 1: Spool Stalker applies Exposed 1 to Seamstress (slot 2), then Seam Ripper
## attacks slot 2 for base 4, amplified to 6 under Exposed 1 (Seamstress 30 -> 24 HP).
## Beat 2: Spool Stalker attacks Tinker (slot 3) for 3 (26 -> 23 HP);
## Seam Ripper applies Weak 1 to Warden (slot 1).
## Beat 3: Spool Stalker gains 2 Block; Seam Ripper attacks Warden (slot 1) for 3 (40 -> 37 HP).
## Beat 4 wraps to beat 1 intents. Standalone data and service contract: not registered in live pools.

const ENCOUNTER_PATH := "res://data/encounters/threadseal_marked_volley.json"
const ENCOUNTER_ID := "threadseal_marked_volley"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMY_PATH := "res://data/enemies/run_enemies.json"
const HEXER_EXPOSED_PATH := "res://data/encounters/hexer_exposed_backline.json"

const MAP_SEED := 91733
const REPLAY_SEED := 20261022

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_ac1_catalog_parser_and_intents()
	_test_ac2_three_beat_execution_and_cycle_wrap()
	_test_ac3_deterministic_replay_and_slain_source()
	_test_ac4_isolation_and_hexer_regression()
	if failures.is_empty():
		print("threadseal_marked_volley_encounter_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("threadseal_marked_volley_encounter_test: FAIL (", failures.size(), " failures)")
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
		{"type": "debuff", "amount": 1, "target_position": 2, "status": "exposed"},
		{"type": "attack", "amount": 3, "target_position": 3},
		{"type": "block", "amount": 2},
	]


func _expected_pattern_2() -> Array:
	return [
		{"type": "attack", "amount": 4, "target_position": 2},
		{"type": "debuff", "amount": 1, "target_position": 1, "status": "weak"},
		{"type": "attack", "amount": 3, "target_position": 1},
	]


func _expected_definitions() -> Array:
	return [
		{"enemy_position": 1, "pattern": _expected_pattern_1()},
		{"enemy_position": 2, "pattern": _expected_pattern_2()},
	]


func _expected_beat_1_intents() -> Array[Dictionary]:
	return [
		{"type": "debuff", "amount": 1, "target_position": 2, "status": "exposed", "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 2, "enemy_position": 2},
	]


func _expected_beat_2_intents() -> Array[Dictionary]:
	return [
		{"type": "attack", "amount": 3, "target_position": 3, "enemy_position": 1},
		{"type": "debuff", "amount": 1, "target_position": 1, "status": "weak", "enemy_position": 2},
	]


func _expected_beat_3_intents() -> Array[Dictionary]:
	return [
		{"type": "block", "amount": 2, "enemy_position": 1},
		{"type": "attack", "amount": 3, "target_position": 1, "enemy_position": 2},
	]


func _build_starter_party() -> CombatParty:
	var raw_heroes: Array = _load_json_array(PARTY_PATH)
	var warden: Dictionary = _find_unique_by_id(raw_heroes, "warden", "starter_party")
	var seamstress: Dictionary = _find_unique_by_id(raw_heroes, "seamstress", "starter_party")
	var tinker: Dictionary = _find_unique_by_id(raw_heroes, "tinker", "starter_party")
	return CombatParty.new([warden, seamstress, tinker])


func _build_threadseal_enemies() -> CombatEnemies:
	var raw_enemies: Array = _load_json_array(ENEMY_PATH)
	var stalker: Dictionary = _find_unique_by_id(raw_enemies, "spool_stalker", "run_enemies")
	var ripper: Dictionary = _find_unique_by_id(raw_enemies, "seam_ripper", "run_enemies")
	return CombatEnemies.new([stalker, ripper])


## AC1: The encounter parses cleanly through RunFightEncounterSelection._parse_schedule_text,
## produces valid CombatEnemyIntents, and the earlier hexer_exposed_backline remains valid.
func _test_ac1_catalog_parser_and_intents() -> void:
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

	var intents: CombatEnemyIntents = CombatEnemyIntents.new(parsed)
	_check(intents.is_valid(), "CombatEnemyIntents accepts parsed definitions")

	var raw_enemies: Array = _load_json_array(ENEMY_PATH)
	var stalker: Dictionary = _find_unique_by_id(raw_enemies, "spool_stalker", "run_enemies")
	var ripper: Dictionary = _find_unique_by_id(raw_enemies, "seam_ripper", "run_enemies")
	_check(stalker.get("name") == "Spool Stalker" and stalker.get("max_hp") == 14, "Spool Stalker is 14 max HP")
	_check(ripper.get("name") == "Seam Ripper" and ripper.get("max_hp") == 18, "Seam Ripper is 18 max HP")
	_check(stalker.get("art_path") == "res://assets/paper/enemies/spool_stalker.png", "Spool Stalker art_path intact")
	_check(ripper.get("art_path") == "res://assets/paper/enemies/seam_ripper.png", "Seam Ripper art_path intact")

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

	# Named earlier encounter still parses without asserting catalog totals or ordering.
	var hexer_defs: Array = RunFightEncounterSelection._parse_schedule_text(_read_text(HEXER_EXPOSED_PATH))
	_check(hexer_defs.size() == 2, "hexer_exposed_backline parses into 2 sources")
	_check(CombatEnemyIntents.new(hexer_defs).is_valid(), "hexer_exposed_backline produces valid CombatEnemyIntents")


## AC2: Beat 1 resolves Spool Stalker's Exposed 1 on Seamstress BEFORE Seam Ripper's
## base-4 attack on slot 2, dealing floor(4 * 1.5) = 6 HP (Seamstress 30 -> 24 HP, Exposed 1).
## Beat 2 deals 3 to Tinker (26 -> 23) and puts Weak 1 on Warden.
## Beat 3 grants 2 Block to Spool Stalker and attacks Warden for 3 (40 -> 37 HP).
## Cycle wraps to beat 1; two fresh fixtures replay identically without RNG use.
func _test_ac2_three_beat_execution_and_cycle_wrap() -> void:
	var party: CombatParty = _build_starter_party()
	var enemies: CombatEnemies = _build_threadseal_enemies()
	var definitions: Array = RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	var intents: CombatEnemyIntents = CombatEnemyIntents.new(definitions)
	var phase: CombatEnemyPhase = CombatEnemyPhase.new()

	_check(party.is_valid() and enemies.is_valid() and intents.is_valid(), "preconditions valid")

	# Isolated test deliberately does NOT run CombatStartingBlock, no opening Warden +6 Block.
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 0, "Warden starts at 40 HP, 0 Block")
	_check(party.get_hero(2).get("hp") == 30 and party.get_hero(2).get("block") == 0, "Seamstress starts at 30 HP, 0 Block")
	_check(party.get_hero(3).get("hp") == 26 and party.get_hero(3).get("block") == 0, "Tinker starts at 26 HP, 0 Block")

	var original_warden: Dictionary = party._heroes[0]
	var original_seamstress: Dictionary = party._heroes[1]
	var original_tinker: Dictionary = party._heroes[2]

	# BEAT 1: Spool Stalker debuff Exposed 1 on slot 2 (Seamstress), Seam Ripper attack 4 on slot 2.
	var b1_intents: Array = intents.get_intents()
	_check(b1_intents == _expected_beat_1_intents(), "Beat 1 intents match expected")
	var b1_res: Dictionary = phase.execute_phase(party, enemies, b1_intents)
	_check(b1_res.get("ok") == true, "Beat 1 phase execution succeeds")
	_check(b1_res.get("events") == [
		{"type": "debuff", "enemy_position": 1, "applied": true, "target_position": 2, "status": "exposed"},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 2},
	], "Beat 1 events match debuff(exposed 1 on slot 2) then attack(slot 2)")

	# Confirm formula: floor(4 * 1.5) = 6 damage.
	_check(CombatStatuses.new().adjusted_attack_damage(4, {}, {"exposed": 1}) == 6,
		"CombatStatuses computes 6 damage for base 4 with Exposed 1")

	# Seamstress at slot 2 took 6 unblocked damage: 30 -> 24 HP, status exposed: 1.
	_check(party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 24
		and party.get_hero(2).get("block") == 0 and party.get_hero(2).get("statuses") == {"exposed": 1},
		"Seamstress at slot 2 took 6 damage (30 -> 24 HP) and carries Exposed 1")
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 0, "Warden at slot 1 remains at 40 HP, 0 Block")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("block") == 0, "Tinker at slot 3 remains at 26 HP, 0 Block")
	_check(enemies.get_enemy(1).get("block") == 0, "Spool Stalker Block remains 0")
	_check(enemies.get_enemy(2).get("block") == 0, "Seam Ripper Block remains 0")

	# BEAT 2: Spool Stalker attack 3 on slot 3 (Tinker), Seam Ripper debuff Weak 1 on slot 1 (Warden).
	_check(intents.advance_turn(), "advance turn to Beat 2 succeeds")
	var b2_intents: Array = intents.get_intents()
	_check(b2_intents == _expected_beat_2_intents(), "Beat 2 intents match expected")
	var b2_res: Dictionary = phase.execute_phase(party, enemies, b2_intents)
	_check(b2_res.get("ok") == true, "Beat 2 phase execution succeeds")
	_check(b2_res.get("events") == [
		{"type": "attack", "enemy_position": 1, "applied": true, "target_position": 3},
		{"type": "debuff", "enemy_position": 2, "applied": true, "target_position": 1, "status": "weak"},
	], "Beat 2 events match attack(pos 3) then debuff(weak 1 on pos 1)")

	# Tinker at slot 3 took 3 damage: 26 -> 23 HP.
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 23
		and party.get_hero(3).get("block") == 0, "Tinker at slot 3 took 3 damage (26 -> 23 HP)")
	# Warden at slot 1 gets Weak 1.
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 0 and party.get_hero(1).get("statuses") == {"weak": 1},
		"Warden at slot 1 carries Weak 1")
	# Seamstress at slot 2 keeps Exposed 1 (no owner-turn expiry in this isolated phase fixture).
	_check(party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 24
		and party.get_hero(2).get("block") == 0 and party.get_hero(2).get("statuses") == {"exposed": 1},
		"Seamstress at slot 2 retains Exposed 1 (no expiry between direct phase calls)")

	# BEAT 3: Spool Stalker block 2, Seam Ripper attack 3 on slot 1 (Warden).
	_check(intents.advance_turn(), "advance turn to Beat 3 succeeds")
	var b3_intents: Array = intents.get_intents()
	_check(b3_intents == _expected_beat_3_intents(), "Beat 3 intents match expected")
	var b3_res: Dictionary = phase.execute_phase(party, enemies, b3_intents)
	_check(b3_res.get("ok") == true, "Beat 3 phase execution succeeds")
	_check(b3_res.get("events") == [
		{"type": "block", "enemy_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 1},
	], "Beat 3 events match block(source 1) then attack(source 2, pos 1)")

	# Warden at slot 1 took 3 unblocked damage: 40 -> 37 HP.
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("hp") == 37
		and party.get_hero(1).get("block") == 0 and party.get_hero(1).get("statuses") == {"weak": 1},
		"Warden at slot 1 took 3 damage (40 -> 37 HP), Weak 1 persists")
	_check(party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 24
		and party.get_hero(2).get("block") == 0 and party.get_hero(2).get("statuses") == {"exposed": 1},
		"Seamstress at slot 2 unchanged at 24 HP, Exposed 1")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 23,
		"Tinker at slot 3 unchanged at 23 HP")
	_check(enemies.get_enemy(1).get("block") == 2, "Spool Stalker gains 2 Block")
	_check(enemies.get_enemy(2).get("block") == 0, "Seam Ripper Block remains 0")

	# CYCLE WRAP: Turn 4 wraps to Beat 1 intents; Turn 5 to Beat 2; Turn 6 to Beat 3.
	_check(intents.advance_turn(), "advance turn to Beat 4 (wrap) succeeds")
	_check(intents.get_intents() == _expected_beat_1_intents(), "Turn 4 wraps to exact Beat 1 intents")

	_check(intents.advance_turn(), "advance turn to Beat 5 succeeds")
	_check(intents.get_intents() == _expected_beat_2_intents(), "Turn 5 continues to Beat 2 intents")

	_check(intents.advance_turn(), "advance turn to Beat 6 succeeds")
	_check(intents.get_intents() == _expected_beat_3_intents(), "Turn 6 continues to Beat 3 intents")

	# Replay timeline from fresh instance to verify deterministic cyclic intent service.
	var fresh_intents: CombatEnemyIntents = CombatEnemyIntents.new(definitions)
	_check(fresh_intents.get_intents() == _expected_beat_1_intents(), "fresh intents start at Beat 1")
	_check(fresh_intents.advance_turn() and fresh_intents.get_intents() == _expected_beat_2_intents(), "fresh step 2")
	_check(fresh_intents.advance_turn() and fresh_intents.get_intents() == _expected_beat_3_intents(), "fresh step 3")
	_check(fresh_intents.advance_turn() and fresh_intents.get_intents() == _expected_beat_1_intents(), "fresh step 4 wrap")
	_check(fresh_intents.advance_turn() and fresh_intents.get_intents() == _expected_beat_2_intents(), "fresh step 5")
	_check(fresh_intents.advance_turn() and fresh_intents.get_intents() == _expected_beat_3_intents(), "fresh step 6")


## AC3: Deterministic replay with identical explicit RNG seed; and slain-source unmarked 4 damage.
## If Spool Stalker is slain before beat 1, its Exposed is skipped and Seam Ripper's unmodified 4
## hits Seamstress, showing that a dead source cannot apply a mark.
func _test_ac3_deterministic_replay_and_slain_source() -> void:
	# 1. Deterministic replay with identical explicit RNG seed (Lesson 8).
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = REPLAY_SEED
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

	# Deterministic replay with identical explicit RNG seed.
	var rng_replay: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_replay.seed = REPLAY_SEED
	var map_replay: RunMap = RunMap.new()
	_check(map_replay.generate(rng_replay), "RunMap replay generates with identical seed")
	_check(map_replay.choose_node(fight_id), "map replay chooses same opening Fight node")
	var selector_replay: RunFightEncounterSelection = RunFightEncounterSelection.new()
	var choice_replay: Dictionary = selector_replay.select_current_fight(map_replay, rng_replay, candidate_pool)
	_check(choice_replay == choice, "identical seed replays identical selection result")

	# 2. Slain source: Spool Stalker (source 1) slain before Beat 1.
	var phase: CombatEnemyPhase = CombatEnemyPhase.new()
	var party_slain: CombatParty = _build_starter_party()
	var enemies_slain: CombatEnemies = _build_threadseal_enemies()

	# Slay Spool Stalker (14 HP).
	_check(enemies_slain.apply_damage(1, 14) and enemies_slain.is_slain(1), "Spool Stalker slain before Beat 1")

	var slain_res: Dictionary = phase.execute_phase(party_slain, enemies_slain, _expected_beat_1_intents())
	_check(slain_res.get("ok") == true, "phase succeeds with slain Source 1")
	_check(slain_res.get("events") == [
		{"type": "debuff", "enemy_position": 1, "applied": false, "target_position": 2, "status": "exposed"},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 2},
	], "Source 1 Exposed is skipped (applied: false), Source 2 attacks slot 2")

	# Since Exposed was skipped, Seamstress takes base 4 damage: 30 -> 26 HP, no Exposed status.
	_check(party_slain.get_hero(2).get("id") == "seamstress" and party_slain.get_hero(2).get("hp") == 26
		and party_slain.get_hero(2).get("block") == 0 and party_slain.get_hero(2).get("statuses", {}) == {},
		"Seamstress takes base 4 damage (30 -> 26 HP, no Exposed status) because source 1 was slain")
	_check(party_slain.get_hero(1).get("id") == "warden" and party_slain.get_hero(1).get("hp") == 40,
		"Warden unchanged at 40 HP")
	_check(party_slain.get_hero(3).get("id") == "tinker" and party_slain.get_hero(3).get("hp") == 26,
		"Tinker unchanged at 26 HP")


## AC4: Isolation and regressions. New encounter is standalone only, not advertised in a routed
## Fight pool or wired through the app; no enemy definition, shared catalog, scripted service,
## existing encounter or existing test is edited. hexer_exposed_backline remains loadable.
func _test_ac4_isolation_and_hexer_regression() -> void:
	# Verify the new encounter file is standalone (not in any pool file).
	var m03_pool_path := "res://data/encounters/m03_typed_battle_pools.json"
	var m03_text: String = _read_text(m03_pool_path)
	_check(m03_text.find(ENCOUNTER_ID) == -1, ENCOUNTER_ID + " not present in m03_typed_battle_pools.json")

	var m02_pool_path := "res://data/encounters/m02_mixed_intents.json"
	var m02_text: String = _read_text(m02_pool_path)
	_check(m02_text.find(ENCOUNTER_ID) == -1, ENCOUNTER_ID + " not present in m02_mixed_intents.json")

	# Verify hexer_exposed_backline still loads and validates.
	var hexer_defs: Array = RunFightEncounterSelection._parse_schedule_text(_read_text(HEXER_EXPOSED_PATH))
	_check(hexer_defs.size() == 2, "hexer_exposed_backline still parses into 2 sources")
	_check(CombatEnemyIntents.new(hexer_defs).is_valid(), "hexer_exposed_backline still produces valid CombatEnemyIntents")

	# Verify existing enemy catalogs are unchanged.
	var raw_enemies: Array = _load_json_array(ENEMY_PATH)
	_check(_find_unique_by_id(raw_enemies, "spool_stalker", "run_enemies").get("max_hp") == 14, "Spool Stalker unchanged")
	_check(_find_unique_by_id(raw_enemies, "seam_ripper", "run_enemies").get("max_hp") == 18, "Seam Ripper unchanged")

	# Verify existing hero catalogs are unchanged.
	var raw_party: Array = _load_json_array(PARTY_PATH)
	_check(_find_unique_by_id(raw_party, "warden", "starter_party").get("max_hp") == 40, "Warden unchanged")
	_check(_find_unique_by_id(raw_party, "seamstress", "starter_party").get("max_hp") == 30, "Seamstress unchanged")
	_check(_find_unique_by_id(raw_party, "tinker", "starter_party").get("max_hp") == 26, "Tinker unchanged")