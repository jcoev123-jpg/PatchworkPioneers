extends SceneTree
## Standalone M04 Fight: Pinstalk Rear Snare encounter schedule, typed roster,
## real enemy phases, displacement, status attachment by ID, slain skips, and replay.

const PINSTALK_PATH := "res://data/encounters/pinstalk_rear_snare.json"
const HEMDRAG_PATH := "res://data/encounters/hemdrag_relay.json"
const SPOOLGUARD_PATH := "res://data/encounters/spoolguard_hexlock.json"
const RUN_ENEMIES_PATH := "res://data/enemies/run_enemies.json"
const STARTER_PARTY_PATH := "res://data/heroes/starter_party.json"

const EXPECTED_PINSTALK := [
	{
		"enemy_position": 1,
		"pattern": [
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed"},
			{"type": "shove", "amount": 0, "target_position": 3, "direction": -1},
			{"type": "block", "amount": 3},
		],
	},
	{
		"enemy_position": 2,
		"pattern": [
			{"type": "attack", "amount": 4, "target_position": 3},
			{"type": "debuff", "amount": 1, "target_position": 2, "status": "weak"},
			{"type": "attack", "amount": 3, "target_position": 1},
		],
	},
]

const EXPECTED_HEMDRAG := [
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

const EXPECTED_SPOOLGUARD := [
	{
		"enemy_position": 1,
		"pattern": [
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
			{"type": "attack", "amount": 3, "target_position": 2},
			{"type": "debuff", "amount": 1, "target_position": 1, "status": "exposed"},
			{"type": "attack", "amount": 3, "target_position": 1},
		],
	},
	{
		"enemy_position": 2,
		"pattern": [
			{"type": "block", "amount": 3},
			{"type": "attack", "amount": 2, "target_position": 1},
			{"type": "buff", "amount": 2},
			{"type": "attack", "amount": 2, "target_position": 3},
		],
	},
]

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_ac1_schedule_parsing_and_intents()
	_test_ac2_three_phases_execution()
	_test_ac3_slain_source_replay_and_fail_closed()
	if failures.is_empty():
		print("m04_pinstalk_rear_snare_test: PASS (" + str(checks) + " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("m04_pinstalk_rear_snare_test: FAIL (" + str(failures.size()) + " failures, " + str(checks) + " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _build_party() -> CombatParty:
	_check(FileAccess.file_exists(STARTER_PARTY_PATH), "starter_party.json exists")
	var text: String = FileAccess.get_file_as_string(STARTER_PARTY_PATH)
	var catalog: Array = RunTypedBattleRoster._parse_catalog_text(text)
	_check(not catalog.is_empty(), "starter party catalog parses correctly")
	var ordered: Array = []
	for id: String in ["warden", "seamstress", "tinker"]:
		var matches: Array = catalog.filter(func(hero: Dictionary) -> bool: return hero.get("id") == id)
		_check(matches.size() == 1, "found unique hero for " + id)
		if matches.size() == 1:
			ordered.append(matches[0])
	var party: CombatParty = CombatParty.new(ordered)
	_check(party.is_valid(), "CombatParty is valid")
	return party


func _build_roster(selected: Dictionary) -> Dictionary:
	var roster_service: RunTypedBattleRoster = RunTypedBattleRoster.new()
	var local_rosters: Dictionary = {"pinstalk_rear_snare": ["spool_stalker", "seam_ripper"]}
	var enemy_catalog_paths: Array = [RUN_ENEMIES_PATH]
	return roster_service.assemble(selected, local_rosters, enemy_catalog_paths)


func _select_fight_battle(rng: RandomNumberGenerator) -> Dictionary:
	var map: RunMap = RunMap.new()
	var generated: bool = map.generate(rng)
	_check(generated, "RunMap generated successfully")
	var fight_node_id: String = ""
	for candidate in map.get_legal_choices():
		var node: Dictionary = map.get_node(candidate)
		if node.get("type") == "Fight":
			fight_node_id = String(candidate)
			break
	_check(not fight_node_id.is_empty(), "found legal Fight node in opening choices")
	_check(map.choose_node(fight_node_id), "chose legal Fight node on map")

	var selector: RunFightEncounterSelection = RunFightEncounterSelection.new()
	var pools: Dictionary = {"Fight": {"pinstalk_rear_snare": PINSTALK_PATH}}
	var selected: Dictionary = selector.select_current_battle(map, rng, pools)
	_check(selected.get("success") == true, "select_current_battle succeeded")
	_check(selected.get("node_type") == "Fight", "selected node_type is Fight")
	_check(selected.get("encounter_id") == "pinstalk_rear_snare", "selected encounter_id is pinstalk_rear_snare")
	_check(selected.get("definitions") == EXPECTED_PINSTALK, "selected definitions match authored schedule")
	return selected


func _test_ac1_schedule_parsing_and_intents() -> void:
	_check(FileAccess.file_exists(PINSTALK_PATH), "AC1: pinstalk_rear_snare.json exists")
	var content: String = FileAccess.get_file_as_string(PINSTALK_PATH)
	_check(not content.is_empty(), "AC1: pinstalk_rear_snare.json is readable and non-empty")

	var definitions: Array = RunFightEncounterSelection._parse_schedule_text(content)
	_check(definitions.size() == 2, "AC1: parsed schedule contains exactly two sources")
	_check(definitions == EXPECTED_PINSTALK, "AC1: parsed schedule matches expected authored structure")

	var scheduler: CombatEnemyIntents = CombatEnemyIntents.new(definitions)
	_check(scheduler.is_valid(), "AC1: CombatEnemyIntents is valid with parsed schedule")

	# Announced Pair 1 (beat 0)
	var pair1: Array[Dictionary] = scheduler.get_intents()
	_check(pair1.size() == 2, "AC1: pair 1 announces both sources")
	_check(pair1[0] == {"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed", "enemy_position": 1},
		"AC1: pair 1 source 1 matches exposed debuff on target 3")
	_check(pair1[1] == {"type": "attack", "amount": 4, "target_position": 3, "enemy_position": 2},
		"AC1: pair 1 source 2 matches attack 4 on target 3")

	# Advance to Beat 1 (pair 2)
	_check(scheduler.advance_turn(), "AC1: advance_turn 1 succeeds")
	var pair2: Array[Dictionary] = scheduler.get_intents()
	_check(pair2.size() == 2, "AC1: pair 2 announces both sources")
	_check(pair2[0] == {"type": "shove", "amount": 0, "target_position": 3, "direction": -1, "enemy_position": 1},
		"AC1: pair 2 source 1 matches shove target 3 dir -1")
	_check(pair2[1] == {"type": "debuff", "amount": 1, "target_position": 2, "status": "weak", "enemy_position": 2},
		"AC1: pair 2 source 2 matches weak debuff on target 2")

	# Advance to Beat 2 (pair 3)
	_check(scheduler.advance_turn(), "AC1: advance_turn 2 succeeds")
	var pair3: Array[Dictionary] = scheduler.get_intents()
	_check(pair3.size() == 2, "AC1: pair 3 announces both sources")
	_check(pair3[0] == {"type": "block", "amount": 3, "enemy_position": 1},
		"AC1: pair 3 source 1 matches block 3")
	_check(pair3[1] == {"type": "attack", "amount": 3, "target_position": 1, "enemy_position": 2},
		"AC1: pair 3 source 2 matches attack 3 on target 1")

	# Advance to Beat 3 (pair 4 wraps to pair 1)
	_check(scheduler.advance_turn(), "AC1: advance_turn 3 succeeds")
	var pair4: Array[Dictionary] = scheduler.get_intents()
	_check(pair4.size() == 2, "AC1: pair 4 announces both sources")
	_check(pair4 == pair1, "AC1: pair 4 wraps and equals pair 1")

	# Check prior encounters still exist and match their authored schedules
	_check(FileAccess.file_exists(HEMDRAG_PATH), "AC1: prior hemdrag_relay.json exists")
	var hemdrag_defs: Array = RunFightEncounterSelection._parse_schedule_text(
		FileAccess.get_file_as_string(HEMDRAG_PATH))
	_check(hemdrag_defs == EXPECTED_HEMDRAG, "AC1: hemdrag_relay matches expected authored pattern")

	_check(FileAccess.file_exists(SPOOLGUARD_PATH), "AC1: prior spoolguard_hexlock.json exists")
	var spoolguard_defs: Array = RunFightEncounterSelection._parse_schedule_text(
		FileAccess.get_file_as_string(SPOOLGUARD_PATH))
	_check(spoolguard_defs == EXPECTED_SPOOLGUARD, "AC1: spoolguard_hexlock matches expected authored pattern")


func _test_ac2_three_phases_execution() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 120749

	var selected: Dictionary = _select_fight_battle(rng)
	var assembled: Dictionary = _build_roster(selected)
	_check(assembled.get("ok") == true, "AC2: RunTypedBattleRoster.assemble succeeded")
	_check(assembled.get("node_type") == "Fight", "AC2: assembled node_type is Fight")
	_check(assembled.get("encounter_id") == "pinstalk_rear_snare", "AC2: assembled encounter_id is pinstalk_rear_snare")

	var enemies: CombatEnemies = assembled.get("enemies")
	_check(enemies != null and enemies.is_valid(), "AC2: assembled CombatEnemies is valid")
	_check(enemies.get_enemies().size() == 2, "AC2: enemy roster size is 2")

	var enemy1: Dictionary = enemies.get_enemy(1)
	_check(enemy1.get("id") == "spool_stalker", "AC2: enemy 1 id is spool_stalker")
	_check(enemy1.get("name") == "Spool Stalker", "AC2: enemy 1 name is Spool Stalker")
	_check(enemy1.get("hp") == 14 and enemy1.get("max_hp") == 14, "AC2: enemy 1 HP is 14/14")
	_check(enemy1.get("block") == 0, "AC2: enemy 1 starting block is 0")

	var enemy2: Dictionary = enemies.get_enemy(2)
	_check(enemy2.get("id") == "seam_ripper", "AC2: enemy 2 id is seam_ripper")
	_check(enemy2.get("name") == "Seam Ripper", "AC2: enemy 2 name is Seam Ripper")
	_check(enemy2.get("hp") == 18 and enemy2.get("max_hp") == 18, "AC2: enemy 2 HP is 18/18")
	_check(enemy2.get("block") == 0, "AC2: enemy 2 starting block is 0")

	var party: CombatParty = _build_party()
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("hp") == 40, "AC2: Warden 40 HP at pos 1")
	_check(party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 30, "AC2: Seamstress 30 HP at pos 2")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 26, "AC2: Tinker 26 HP at pos 3")

	var starting_block_service: CombatStartingBlock = CombatStartingBlock.new(party)
	_check(starting_block_service.apply(), "AC2: CombatStartingBlock.apply succeeds")
	_check(party.get_hero(1).get("block") == 6, "AC2: Warden has 6 starting Block")
	_check(party.get_hero(2).get("block") == 0, "AC2: Seamstress has 0 Block")
	_check(party.get_hero(3).get("block") == 0, "AC2: Tinker has 0 Block")

	var scheduler: CombatEnemyIntents = CombatEnemyIntents.new(assembled.get("definitions"))
	_check(scheduler.is_valid(), "AC2: scheduler initialized from assembled definitions")
	var phase_service: CombatEnemyPhase = CombatEnemyPhase.new()

	# -------------------------------------------------------------------------
	# Beat 0: Stalker Exposes Tinker (target 3), Ripper attacks target 3 for 4 (+50% -> 6)
	# -------------------------------------------------------------------------
	var intents0: Array[Dictionary] = scheduler.get_intents()
	var res0: Dictionary = phase_service.execute_phase(party, enemies, intents0)
	_check(res0.get("ok") == true, "AC2: phase 1 execution succeeded")
	var events0: Array = res0.get("events", [])
	_check(events0.size() == 2, "AC2: phase 1 returned two events")
	_check(events0[0] == {"type": "debuff", "enemy_position": 1, "applied": true, "target_position": 3, "status": "exposed"},
		"AC2: phase 1 event 0 matches applied debuff exposed on target 3")
	_check(events0[1] == {"type": "attack", "enemy_position": 2, "applied": true, "target_position": 3},
		"AC2: phase 1 event 1 matches applied attack on target 3")

	# Tinker at pos 3: took 6 damage (4 + 50% = 6), 26 -> 20 HP, exposed: 1
	var hero1_b0: Dictionary = party.get_hero(1)
	_check(hero1_b0.get("id") == "warden" and hero1_b0.get("hp") == 40 and hero1_b0.get("block") == 6,
		"AC2: beat 0 Warden unchanged at 40 HP and 6 Block")
	var hero2_b0: Dictionary = party.get_hero(2)
	_check(hero2_b0.get("id") == "seamstress" and hero2_b0.get("hp") == 30 and hero2_b0.get("block") == 0,
		"AC2: beat 0 Seamstress unchanged at 30 HP and 0 Block")
	var hero3_b0: Dictionary = party.get_hero(3)
	_check(hero3_b0.get("id") == "tinker" and hero3_b0.get("hp") == 20 and hero3_b0.get("block") == 0,
		"AC2: beat 0 Tinker HP 26 -> 20 from Exposed +4 attack")
	_check(hero3_b0.get("statuses", {}) == {"exposed": 1},
		"AC2: beat 0 Tinker has exposed 1 attached")
	_check(enemies.get_enemy(1).get("hp") == 14 and enemies.get_enemy(1).get("block") == 0,
		"AC2: beat 0 Stalker HP 14, Block 0")
	_check(enemies.get_enemy(2).get("hp") == 18 and enemies.get_enemy(2).get("block") == 0,
		"AC2: beat 0 Ripper HP 18, Block 0")

	_check(scheduler.advance_turn(), "AC2: advance_turn after beat 0")

	# -------------------------------------------------------------------------
	# Beat 1: Stalker shoves Tinker (target 3, dir -1) to pos 2 (swapping with Seamstress),
	#         Ripper applies Weak 1 to target 2 (now Tinker!)
	# -------------------------------------------------------------------------
	var intents1: Array[Dictionary] = scheduler.get_intents()
	var res1: Dictionary = phase_service.execute_phase(party, enemies, intents1)
	_check(res1.get("ok") == true, "AC2: phase 2 execution succeeded")
	var events1: Array = res1.get("events", [])
	_check(events1.size() == 2, "AC2: phase 2 returned two events")
	_check(events1[0] == {"type": "shove", "enemy_position": 1, "applied": true, "target_position": 3, "direction": -1},
		"AC2: phase 2 event 0 matches applied shove")
	_check(events1[1] == {"type": "debuff", "enemy_position": 2, "applied": true, "target_position": 2, "status": "weak"},
		"AC2: phase 2 event 1 matches applied weak debuff on target 2")

	# Check actual hero ID at middle/rear after shove:
	var hero1_b1: Dictionary = party.get_hero(1)
	_check(hero1_b1.get("id") == "warden" and hero1_b1.get("hp") == 40 and hero1_b1.get("block") == 6,
		"AC2: beat 1 Warden at pos 1 with 40 HP and 6 Block")
	var hero2_b1: Dictionary = party.get_hero(2)
	_check(hero2_b1.get("id") == "tinker" and hero2_b1.get("hp") == 20 and hero2_b1.get("block") == 0,
		"AC2: beat 1 Tinker is now at pos 2 (middle) after shove")
	_check(hero2_b1.get("statuses", {}) == {"exposed": 1, "weak": 1},
		"AC2: beat 1 Tinker retains Exposed and gains Weak attached by ID")
	var hero3_b1: Dictionary = party.get_hero(3)
	_check(hero3_b1.get("id") == "seamstress" and hero3_b1.get("hp") == 30 and hero3_b1.get("block") == 0,
		"AC2: beat 1 Seamstress is now at pos 3 (rear) after shove, HP 30")
	_check(hero3_b1.get("statuses", {}).is_empty(),
		"AC2: beat 1 Seamstress has no statuses")
	_check(enemies.get_enemy(1).get("hp") == 14 and enemies.get_enemy(1).get("block") == 0,
		"AC2: beat 1 Stalker HP 14, Block 0")
	_check(enemies.get_enemy(2).get("hp") == 18 and enemies.get_enemy(2).get("block") == 0,
		"AC2: beat 1 Ripper HP 18, Block 0")

	_check(scheduler.advance_turn(), "AC2: advance_turn after beat 1")

	# -------------------------------------------------------------------------
	# Beat 2: Stalker gains Block 3, Ripper attacks target 1 (Warden) for 3
	#         Warden Block 6 -> 3, no HP loss
	# -------------------------------------------------------------------------
	var intents2: Array[Dictionary] = scheduler.get_intents()
	var res2: Dictionary = phase_service.execute_phase(party, enemies, intents2)
	_check(res2.get("ok") == true, "AC2: phase 3 execution succeeded")
	var events2: Array = res2.get("events", [])
	_check(events2.size() == 2, "AC2: phase 3 returned two events")
	_check(events2[0] == {"type": "block", "enemy_position": 1, "applied": true},
		"AC2: phase 3 event 0 matches applied block on source 1")
	_check(events2[1] == {"type": "attack", "enemy_position": 2, "applied": true, "target_position": 1},
		"AC2: phase 3 event 1 matches applied attack on target 1")

	var hero1_b2: Dictionary = party.get_hero(1)
	_check(hero1_b2.get("id") == "warden" and hero1_b2.get("hp") == 40 and hero1_b2.get("block") == 3,
		"AC2: beat 2 Warden Block 6 -> 3, HP remains 40 without loss")
	var hero2_b2: Dictionary = party.get_hero(2)
	_check(hero2_b2.get("id") == "tinker" and hero2_b2.get("hp") == 20 and hero2_b2.get("block") == 0,
		"AC2: beat 2 Tinker HP remains 20 at middle pos 2")
	_check(hero2_b2.get("statuses", {}) == {"exposed": 1, "weak": 1},
		"AC2: beat 2 Tinker retains Exposed and Weak attached by ID")
	var hero3_b2: Dictionary = party.get_hero(3)
	_check(hero3_b2.get("id") == "seamstress" and hero3_b2.get("hp") == 30 and hero3_b2.get("block") == 0,
		"AC2: beat 2 Seamstress HP remains 30 at rear pos 3")
	_check(enemies.get_enemy(1).get("hp") == 14 and enemies.get_enemy(1).get("block") == 3,
		"AC2: beat 2 Stalker HP 14, Block gained 3")
	_check(enemies.get_enemy(2).get("hp") == 18 and enemies.get_enemy(2).get("block") == 0,
		"AC2: beat 2 Ripper HP 18, Block 0")

	_check(scheduler.advance_turn(), "AC2: advance_turn after beat 2")


func _test_ac3_slain_source_replay_and_fail_closed() -> void:
	# -------------------------------------------------------------------------
	# AC3 Part 1: Fresh party & roster, Stalker slain before phase 1
	# -------------------------------------------------------------------------
	var fresh_party: CombatParty = _build_party()
	var starting_block: CombatStartingBlock = CombatStartingBlock.new(fresh_party)
	_check(starting_block.apply(), "AC3: starting block applied on fresh party")

	var local_enemies_arr: Array = [
		{"id": "spool_stalker", "name": "Spool Stalker", "max_hp": 14, "art_path": "res://assets/paper/enemies/spool_stalker.png"},
		{"id": "seam_ripper", "name": "Seam Ripper", "max_hp": 18, "art_path": "res://assets/paper/enemies/seam_ripper.png"}
	]
	var fresh_enemies: CombatEnemies = CombatEnemies.new(local_enemies_arr)
	_check(fresh_enemies.is_valid(), "AC3: fresh enemies object is valid")

	# Kill Spool Stalker via CombatEnemies.apply_damage(1, 14) BEFORE the first enemy phase
	_check(fresh_enemies.apply_damage(1, 14), "AC3: apply_damage 14 to enemy 1 succeeds")
	_check(fresh_enemies.is_slain(1), "AC3: enemy 1 is slain (HP 0)")
	_check(fresh_enemies.get_enemy(1).get("hp") == 0, "AC3: enemy 1 HP is 0")
	_check(fresh_enemies.get_enemy(2).get("hp") == 18, "AC3: enemy 2 HP is 18")

	var fresh_scheduler: CombatEnemyIntents = CombatEnemyIntents.new(EXPECTED_PINSTALK)
	_check(fresh_scheduler.is_valid(), "AC3: fresh scheduler is valid")
	var intents_beat0: Array[Dictionary] = fresh_scheduler.get_intents()

	var phase_service: CombatEnemyPhase = CombatEnemyPhase.new()
	var slain_res: Dictionary = phase_service.execute_phase(fresh_party, fresh_enemies, intents_beat0)
	_check(slain_res.get("ok") == true, "AC3: phase execution succeeds with dead source 1")
	var slain_events: Array = slain_res.get("events", [])
	_check(slain_events.size() == 2, "AC3: two events recorded")

	# Stalker intent must have applied=false
	_check(slain_events[0] == {"type": "debuff", "enemy_position": 1, "applied": false, "target_position": 3, "status": "exposed"},
		"AC3: dead Stalker exposed intent has applied=false")

	# Living Ripper attack still executes at raw 4, leaving Tinker HP 22, not Exposed
	_check(slain_events[1] == {"type": "attack", "enemy_position": 2, "applied": true, "target_position": 3},
		"AC3: living Ripper attack intent has applied=true")

	var tinker_hero: Dictionary = fresh_party.get_hero(3)
	_check(tinker_hero.get("id") == "tinker" and tinker_hero.get("hp") == 22,
		"AC3: Tinker takes raw 4 damage (26 -> 22 HP)")
	_check(tinker_hero.get("statuses", {}).is_empty(),
		"AC3: Tinker has no statuses attached (not Exposed)")
	_check(fresh_party.get_hero(1).get("hp") == 40 and fresh_party.get_hero(1).get("block") == 6,
		"AC3: Warden remains 40 HP and 6 Block")
	_check(fresh_party.get_hero(2).get("hp") == 30 and fresh_party.get_hero(2).get("block") == 0,
		"AC3: Seamstress remains 30 HP and 0 Block")

	# -------------------------------------------------------------------------
	# AC3 Part 2: Independent fixed-seed replay and no RNG consumption
	# -------------------------------------------------------------------------
	var trace1: Dictionary = _execute_trace(20261022)
	var trace2: Dictionary = _execute_trace(20261022)
	_check(not trace1.is_empty(), "AC3: trace1 succeeded")
	_check(not trace2.is_empty(), "AC3: trace2 succeeded")
	_check(trace1 == trace2, "AC3: independent fixed-seed traces replay identically")

	# -------------------------------------------------------------------------
	# AC3 Part 3: Focused negative checks (downed target shove & malformed inputs)
	# -------------------------------------------------------------------------
	_test_downed_target_shove_rejection()
	_test_malformed_inputs()


func _execute_trace(seed_val: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val

	var selected: Dictionary = _select_fight_battle(rng)
	var assembled: Dictionary = _build_roster(selected)
	if not assembled.get("ok", false):
		return {}

	var enemies: CombatEnemies = assembled.get("enemies")
	var party: CombatParty = _build_party()
	CombatStartingBlock.new(party).apply()

	var scheduler: CombatEnemyIntents = CombatEnemyIntents.new(assembled.get("definitions"))
	var phase_service: CombatEnemyPhase = CombatEnemyPhase.new()

	var rng_before_phases: int = rng.state
	var trace: Dictionary = {
		"intents": [],
		"events": [],
		"heroes": [],
		"enemies": [],
	}

	for beat: int in range(3):
		var announced: Array[Dictionary] = scheduler.get_intents()
		var res: Dictionary = phase_service.execute_phase(party, enemies, announced)
		if not res.get("ok", false):
			return {}
		trace["intents"].append(announced.duplicate(true))
		trace["events"].append(res.get("events", []).duplicate(true))
		trace["heroes"].append(party.get_heroes())
		trace["enemies"].append(enemies.get_enemies())
		scheduler.advance_turn()

	var rng_after_phases: int = rng.state
	_check(rng_before_phases == rng_after_phases, "AC3: phase execution consumes no RNG")
	trace["rng_conserved"] = (rng_before_phases == rng_after_phases)
	return trace


func _test_downed_target_shove_rejection() -> void:
	# Downed target shove: Seamstress at pos 2 is downed (HP 0), Tinker at pos 3 is alive.
	# Stalker attempts shove pos 3 with direction -1 (destination pos 2 is downed).
	# Must reject fail-closed: return {"ok": false, "events": []} and leave party/enemies untouched.
	var party: CombatParty = _build_party()
	CombatStartingBlock.new(party).apply()
	# Apply damage to down Seamstress (HP 30 -> 0)
	_check(party.apply_damage(2, 30), "negative: down Seamstress to 0 HP")
	_check(party.is_downed(2), "negative: Seamstress is downed")
	_check(not party.is_downed(3), "negative: Tinker is alive")

	var local_enemies_arr: Array = [
		{"id": "spool_stalker", "name": "Spool Stalker", "max_hp": 14},
		{"id": "seam_ripper", "name": "Seam Ripper", "max_hp": 18}
	]
	var enemies: CombatEnemies = CombatEnemies.new(local_enemies_arr)

	var snapshot_party_before: Array[Dictionary] = party.get_heroes()
	var snapshot_enemies_before: Array[Dictionary] = enemies.get_enemies()

	var shove_intents: Array[Dictionary] = [
		{"type": "shove", "amount": 0, "target_position": 3, "direction": -1, "enemy_position": 1},
		{"type": "debuff", "amount": 1, "target_position": 2, "status": "weak", "enemy_position": 2}
	]
	var phase_service: CombatEnemyPhase = CombatEnemyPhase.new()
	var fail_res: Dictionary = phase_service.execute_phase(party, enemies, shove_intents)
	_check(fail_res.get("ok") == false and fail_res.get("events", []).is_empty(),
		"negative: shove into downed destination rejects fail-closed with empty events")
	_check(party.get_heroes() == snapshot_party_before,
		"negative: party state completely untouched on shove rejection")
	_check(enemies.get_enemies() == snapshot_enemies_before,
		"negative: enemies state completely untouched on shove rejection")


func _test_malformed_inputs() -> void:
	# Malformed schedule parsing
	_check(RunFightEncounterSelection._parse_schedule_text("").is_empty(),
		"negative: empty string schedule yields empty definitions")
	_check(RunFightEncounterSelection._parse_schedule_text("not json").is_empty(),
		"negative: invalid json schedule yields empty definitions")
	_check(RunFightEncounterSelection._parse_schedule_text("[]").is_empty(),
		"negative: empty array schedule yields empty definitions")
	_check(RunFightEncounterSelection._parse_schedule_text("[{\"enemy_position\": 1}]").is_empty(),
		"negative: missing pattern schedule yields empty definitions")

	# Malformed roster assembly
	var roster_service: RunTypedBattleRoster = RunTypedBattleRoster.new()
	var valid_choice: Dictionary = {
		"success": true,
		"node_type": "Fight",
		"encounter_id": "pinstalk_rear_snare",
		"definitions": EXPECTED_PINSTALK
	}
	_check(roster_service.assemble({}, {}, []).get("ok") == false,
		"negative: empty assemble inputs reject")
	_check(roster_service.assemble(valid_choice, {}, [RUN_ENEMIES_PATH]).get("ok") == false,
		"negative: missing encounter ID in roster binding rejects")
	_check(roster_service.assemble(valid_choice, {"pinstalk_rear_snare": ["spool_stalker"]}, [RUN_ENEMIES_PATH]).get("ok") == false,
		"negative: mismatched roster count (1 enemy for 2 definitions) rejects")
