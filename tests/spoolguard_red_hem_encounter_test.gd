extends SceneTree
## Standalone M04 Fight: Spoolguard Red Hem encounter schedule, typed roster,
## real enemy phases, detached status tick projection, downed rollback, and replay.

const SPOOLGUARD_PATH := "res://data/encounters/spoolguard_red_hem.json"
const FRAYHEM_PATH := "res://data/encounters/frayhem_bleedtrap.json"
const RUN_ENEMIES_PATH := "res://data/enemies/run_enemies.json"
const STARTER_PARTY_PATH := "res://data/heroes/starter_party.json"
const ENCOUNTER_ID := "spoolguard_red_hem"

const EXPECTED_SPOOLGUARD: Array = [
	{
		"enemy_position": 1,
		"pattern": [
			{"type": "debuff", "amount": 2, "target_position": 1, "status": "bleed"},
			{"type": "attack", "amount": 3, "target_position": 3},
			{"type": "debuff", "amount": 1, "target_position": 2, "status": "exposed"},
		],
	},
	{
		"enemy_position": 2,
		"pattern": [
			{"type": "block", "amount": 4},
			{"type": "attack", "amount": 4, "target_position": 1},
			{"type": "attack", "amount": 4, "target_position": 2},
		],
	},
]

const EXPECTED_FRAYHEM: Array = [
	{
		"enemy_position": 1,
		"pattern": [
			{"type": "debuff", "amount": 1, "target_position": 2, "status": "bleed"},
			{"type": "attack", "amount": 3, "target_position": 3},
			{"type": "block", "amount": 2},
		],
	},
	{
		"enemy_position": 2,
		"pattern": [
			{"type": "attack", "amount": 2, "target_position": 2},
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
			{"type": "attack", "amount": 2, "target_position": 1},
		],
	},
	{
		"enemy_position": 3,
		"pattern": [
			{"type": "block", "amount": 3},
			{"type": "attack", "amount": 2, "target_position": 1},
			{"type": "buff", "amount": 2},
		],
	},
]

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_ac1_schedule_parsing_and_intents()
	_test_ac2_three_phases_execution()
	_test_ac2_downed_warden_rollback()
	_test_ac2_slain_source_skip()
	_test_ac3_map_selection_and_roster()
	_test_ac3_replay_and_selector_negatives()

	if failures.is_empty():
		print("spoolguard_red_hem_encounter_test: PASS (" + str(checks) + " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("spoolguard_red_hem_encounter_test: FAIL (" + str(failures.size()) + " failures, " + str(checks) + " checks)")
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
			ordered.append(matches[0].duplicate(true))
	var party: CombatParty = CombatParty.new(ordered)
	_check(party.is_valid(), "CombatParty is valid")
	var starting_block: CombatStartingBlock = CombatStartingBlock.new(party)
	_check(starting_block.apply(), "CombatStartingBlock.apply succeeds")
	_check(party.get_hero(1).get("block") == 6, "Warden holds 6 opening Block")
	_check(party.get_hero(2).get("block") == 0, "Seamstress holds 0 opening Block")
	_check(party.get_hero(3).get("block") == 0, "Tinker holds 0 opening Block")
	return party


func _build_enemies() -> CombatEnemies:
	_check(FileAccess.file_exists(RUN_ENEMIES_PATH), "run_enemies.json exists")
	var text: String = FileAccess.get_file_as_string(RUN_ENEMIES_PATH)
	var catalog: Array = RunTypedBattleRoster._parse_catalog_text(text)
	_check(not catalog.is_empty(), "run_enemies catalog parses correctly")
	var ordered: Array = []
	for id: String in ["spool_stalker", "button_guard"]:
		var matches: Array = catalog.filter(func(enemy: Dictionary) -> bool: return enemy.get("id") == id)
		_check(matches.size() == 1, "found unique enemy for " + id)
		if matches.size() == 1:
			ordered.append(matches[0].duplicate(true))
	var enemies: CombatEnemies = CombatEnemies.new(ordered)
	_check(enemies.is_valid(), "CombatEnemies is valid")
	_check(enemies.get_enemies().size() == 2, "CombatEnemies holds exactly 2 slots")
	return enemies


func _test_ac1_schedule_parsing_and_intents() -> void:
	_check(FileAccess.file_exists(SPOOLGUARD_PATH), "AC1: spoolguard_red_hem.json exists")
	var content: String = FileAccess.get_file_as_string(SPOOLGUARD_PATH)
	_check(not content.is_empty(), "AC1: spoolguard_red_hem.json is readable and non-empty")

	# Validate raw JSON structure before parser coercion
	var raw_json: Variant = JSON.parse_string(content)
	_check(raw_json is Array, "AC1: raw JSON top-level is an Array")
	if raw_json is Array:
		_check(raw_json.size() == 2, "AC1: raw JSON holds exactly two source records")
		for raw_def in raw_json:
			_check(raw_def is Dictionary, "AC1: each definition is a Dictionary")
			if raw_def is Dictionary:
				var pos: Variant = raw_def.get("enemy_position")
				_check(pos is int or pos is float, "AC1: raw enemy_position is a number")
				if pos is int or pos is float:
					_check(int(pos) == pos, "AC1: raw enemy_position is integral")
				var pat: Variant = raw_def.get("pattern")
				_check(pat is Array and pat.size() == 3, "AC1: raw pattern is an Array of size 3")
				if pat is Array:
					for raw_act in pat:
						_check(raw_act is Dictionary, "AC1: raw action is a Dictionary")
						if raw_act is Dictionary:
							var amt: Variant = raw_act.get("amount")
							_check(amt is int or amt is float, "AC1: action amount is a number")
							if amt is int or amt is float:
								_check(int(amt) == amt, "AC1: action amount is integral")
							if raw_act.has("target_position"):
								var tgt: Variant = raw_act.get("target_position")
								_check(tgt is int or tgt is float, "AC1: target_position is a number")
								if tgt is int or tgt is float:
									_check(int(tgt) == tgt, "AC1: target_position is integral")

	var definitions: Array = RunFightEncounterSelection._parse_schedule_text(content)
	_check(definitions.size() == 2, "AC1: parsed schedule contains exactly two sources")
	_check(definitions == EXPECTED_SPOOLGUARD, "AC1: parsed schedule matches expected authored structure")

	var scheduler: CombatEnemyIntents = CombatEnemyIntents.new(definitions)
	_check(scheduler.is_valid(), "AC1: CombatEnemyIntents is valid with parsed schedule")

	# Beat 1 (0 advances)
	var pair1: Array[Dictionary] = scheduler.get_intents()
	_check(pair1.size() == 2, "AC1: beat 1 announces both sources")
	_check(pair1[0] == {"type": "debuff", "amount": 2, "target_position": 1, "status": "bleed", "enemy_position": 1},
		"AC1: beat 1 source 1 matches debuff bleed 2 on front target 1")
	_check(pair1[1] == {"type": "block", "amount": 4, "enemy_position": 2},
		"AC1: beat 1 source 2 matches block 4 on source 2")

	# Advance to Beat 2 (1 advance)
	_check(scheduler.advance_turn(), "AC1: advance_turn 1 succeeds")
	var pair2: Array[Dictionary] = scheduler.get_intents()
	_check(pair2.size() == 2, "AC1: beat 2 announces both sources")
	_check(pair2[0] == {"type": "attack", "amount": 3, "target_position": 3, "enemy_position": 1},
		"AC1: beat 2 source 1 matches attack 3 on rear target 3")
	_check(pair2[1] == {"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 2},
		"AC1: beat 2 source 2 matches attack 4 on front target 1")

	# Advance to Beat 3 (2 advances)
	_check(scheduler.advance_turn(), "AC1: advance_turn 2 succeeds")
	var pair3: Array[Dictionary] = scheduler.get_intents()
	_check(pair3.size() == 2, "AC1: beat 3 announces both sources")
	_check(pair3[0] == {"type": "debuff", "amount": 1, "target_position": 2, "status": "exposed", "enemy_position": 1},
		"AC1: beat 3 source 1 matches debuff exposed 1 on middle target 2")
	_check(pair3[1] == {"type": "attack", "amount": 4, "target_position": 2, "enemy_position": 2},
		"AC1: beat 3 source 2 matches attack 4 on middle target 2")

	# Advance to Beat 4 (3 advances wraps to beat 1)
	_check(scheduler.advance_turn(), "AC1: advance_turn 3 succeeds")
	var pair4: Array[Dictionary] = scheduler.get_intents()
	_check(pair4.size() == 2, "AC1: beat 4 announces both sources")
	_check(pair4 == pair1, "AC1: beat 4 wraps and equals beat 1")

	# Check prior frayhem_bleedtrap still parses
	_check(FileAccess.file_exists(FRAYHEM_PATH), "AC1: prior frayhem_bleedtrap.json exists")
	var frayhem_content: String = FileAccess.get_file_as_string(FRAYHEM_PATH)
	_check(not frayhem_content.is_empty(), "AC1: frayhem_bleedtrap.json is readable")
	var frayhem_defs: Array = RunFightEncounterSelection._parse_schedule_text(frayhem_content)
	_check(frayhem_defs == EXPECTED_FRAYHEM, "AC1: frayhem_bleedtrap matches expected authored pattern")
	_check(CombatEnemyIntents.new(frayhem_defs).is_valid(), "AC1: frayhem_bleedtrap validates in CombatEnemyIntents")


func _test_ac2_three_phases_execution() -> void:
	var phase_service: CombatEnemyPhase = CombatEnemyPhase.new()

	# -------------------------------------------------------------------------
	# Beat 1 on fresh fight:
	# Warden gains Bleed 2, retains 40 HP and 6 Block immediately; Guard gains 4 Block.
	# Detached CombatStatuses.end_owner_turn proposes Warden 38 HP, 6 Block, Bleed 1
	# without mutating authoritative state.
	# -------------------------------------------------------------------------
	var party1: CombatParty = _build_party()
	var enemies1: CombatEnemies = _build_enemies()
	var scheduler1: CombatEnemyIntents = CombatEnemyIntents.new(EXPECTED_SPOOLGUARD)
	var intents1: Array[Dictionary] = scheduler1.get_intents()

	var res1: Dictionary = phase_service.execute_phase(party1, enemies1, intents1)
	_check(res1.get("ok") == true, "AC2 Beat 1: phase execution succeeded")
	var events1: Array = res1.get("events", [])
	_check(events1.size() == 2, "AC2 Beat 1: two source-ordered phase events")
	_check(events1[0] == {"type": "debuff", "enemy_position": 1, "applied": true, "target_position": 1, "status": "bleed"},
		"AC2 Beat 1: event 0 matches debuff bleed on target 1 from source 1")
	_check(events1[1] == {"type": "block", "enemy_position": 2, "applied": true},
		"AC2 Beat 1: event 1 matches block on source 2")

	# Authoritative immediate post-phase state
	var warden1: Dictionary = party1.get_hero(1)
	_check(warden1.get("id") == "warden" and warden1.get("hp") == 40 and warden1.get("block") == 6,
		"AC2 Beat 1: Warden retains 40 HP and 6 Block immediately")
	_check(warden1.get("statuses", {}) == {"bleed": 2},
		"AC2 Beat 1: Warden holds Bleed 2 status attached")
	_check(party1.get_hero(2).get("hp") == 30 and party1.get_hero(2).get("block") == 0,
		"AC2 Beat 1: Seamstress untouched at 30 HP and 0 Block")
	_check(party1.get_hero(3).get("hp") == 26 and party1.get_hero(3).get("block") == 0,
		"AC2 Beat 1: Tinker untouched at 26 HP and 0 Block")

	var guard1: Dictionary = enemies1.get_enemy(2)
	_check(guard1.get("id") == "button_guard" and guard1.get("hp") == 16 and guard1.get("block") == 4,
		"AC2 Beat 1: Button Guard gains 4 Block, retains 16 HP")
	var stalker1: Dictionary = enemies1.get_enemy(1)
	_check(stalker1.get("id") == "spool_stalker" and stalker1.get("hp") == 14 and stalker1.get("block") == 0,
		"AC2 Beat 1: Spool Stalker retains 14 HP and 0 Block")

	# Detached CombatStatuses.end_owner_turn projection on beat-1 hero snapshot
	var snapshot_heroes_before: Array[Dictionary] = party1.get_heroes()
	var warden_snapshot: Dictionary = party1.get_hero(1)
	var hp_before: int = warden_snapshot.get("hp", 0)
	var block_before: int = warden_snapshot.get("block", 0)
	var statuses_before: Dictionary = warden_snapshot.get("statuses", {})

	var projection: Dictionary = CombatStatuses.new().end_owner_turn(hp_before, block_before, statuses_before)
	_check(projection.get("ok") == true, "AC2 Beat 1: detached end_owner_turn succeeds")
	_check(projection.get("hp") == 38, "AC2 Beat 1: detached projection proposes Warden 38 HP (40 - 2)")
	_check(projection.get("block") == 6, "AC2 Beat 1: detached projection preserves Warden 6 Block (Bleed ignores Block)")
	_check(projection.get("statuses") == {"bleed": 1}, "AC2 Beat 1: detached projection decrements Bleed 2 to 1")
	_check(projection.get("bleed_hp_loss") == 2, "AC2 Beat 1: detached projection reports 2 bleed_hp_loss")

	# Verify authoritative CombatParty is NOT mutated by detached end_owner_turn
	_check(party1.get_heroes() == snapshot_heroes_before,
		"AC2 Beat 1: authoritative CombatParty is not mutated by detached end_owner_turn")
	_check(party1.get_hero(1).get("hp") == 40 and party1.get_hero(1).get("block") == 6
		and party1.get_hero(1).get("statuses") == {"bleed": 2},
		"AC2 Beat 1: authoritative Warden state remains 40 HP, 6 Block, Bleed 2")

	# Also verify detached CombatStatusTurnBatch.tick_side proposes identical values without mutating party
	var batch_tick: Dictionary = CombatStatusTurnBatch.new().tick_side("heroes", party1.get_heroes())
	_check(batch_tick.get("ok") == true, "AC2 Beat 1: CombatStatusTurnBatch.tick_side succeeds")
	var batch_actors: Array = batch_tick.get("actors", [])
	_check(batch_actors.size() == 3, "AC2 Beat 1: batch tick returns 3 actors")
	_check(batch_actors[0].get("hp") == 38 and batch_actors[0].get("block") == 6
		and batch_actors[0].get("statuses") == {"bleed": 1},
		"AC2 Beat 1: batch tick proposes Warden 38 HP, 6 Block, Bleed 1")
	_check(party1.get_heroes() == snapshot_heroes_before,
		"AC2 Beat 1: authoritative CombatParty is not mutated by batch tick")

	# -------------------------------------------------------------------------
	# Beat 2 on a DIFFERENT fresh fight:
	# slot-1 Spool Stalker hits rear Tinker for 3 (26->23),
	# slot-2 Button Guard hits front Warden for 4 (6 Block->2, HP40).
	# -------------------------------------------------------------------------
	var party2: CombatParty = _build_party()
	var enemies2: CombatEnemies = _build_enemies()
	var scheduler2: CombatEnemyIntents = CombatEnemyIntents.new(EXPECTED_SPOOLGUARD)
	_check(scheduler2.advance_turn(), "AC2 Beat 2: advance to beat 2")
	var intents2: Array[Dictionary] = scheduler2.get_intents()

	var res2: Dictionary = phase_service.execute_phase(party2, enemies2, intents2)
	_check(res2.get("ok") == true, "AC2 Beat 2: phase execution succeeded")
	var events2: Array = res2.get("events", [])
	_check(events2.size() == 2, "AC2 Beat 2: two source-ordered phase events")
	_check(events2[0] == {"type": "attack", "enemy_position": 1, "applied": true, "target_position": 3},
		"AC2 Beat 2: event 0 matches attack on rear target 3 from source 1")
	_check(events2[1] == {"type": "attack", "enemy_position": 2, "applied": true, "target_position": 1},
		"AC2 Beat 2: event 1 matches attack on front target 1 from source 2")

	var warden2: Dictionary = party2.get_hero(1)
	_check(warden2.get("id") == "warden" and warden2.get("hp") == 40 and warden2.get("block") == 2,
		"AC2 Beat 2: Warden absorbs 4 damage with Block: 6 Block -> 2, HP remains 40")
	var seamstress2: Dictionary = party2.get_hero(2)
	_check(seamstress2.get("id") == "seamstress" and seamstress2.get("hp") == 30 and seamstress2.get("block") == 0,
		"AC2 Beat 2: Seamstress untouched at 30 HP and 0 Block")
	var tinker2: Dictionary = party2.get_hero(3)
	_check(tinker2.get("id") == "tinker" and tinker2.get("hp") == 23 and tinker2.get("block") == 0,
		"AC2 Beat 2: Tinker takes 3 damage: 26 HP -> 23")

	var stalker2: Dictionary = enemies2.get_enemy(1)
	_check(stalker2.get("id") == "spool_stalker" and stalker2.get("hp") == 14 and stalker2.get("block") == 0,
		"AC2 Beat 2: Spool Stalker has 14 HP, 0 Block")
	var guard2: Dictionary = enemies2.get_enemy(2)
	_check(guard2.get("id") == "button_guard" and guard2.get("hp") == 16 and guard2.get("block") == 0,
		"AC2 Beat 2: Button Guard has 16 HP, 0 Block")

	# -------------------------------------------------------------------------
	# Beat 3 on another DIFFERENT fresh fight:
	# slot 1 gives Seamstress Exposed 1, slot 2 strikes her for 4 base,
	# causing floor(4 * 1.5) = 6: Seamstress 30 -> 24.
	# -------------------------------------------------------------------------
	var party3: CombatParty = _build_party()
	var enemies3: CombatEnemies = _build_enemies()
	var scheduler3: CombatEnemyIntents = CombatEnemyIntents.new(EXPECTED_SPOOLGUARD)
	_check(scheduler3.advance_turn() and scheduler3.advance_turn(), "AC2 Beat 3: advance to beat 3")
	var intents3: Array[Dictionary] = scheduler3.get_intents()

	var res3: Dictionary = phase_service.execute_phase(party3, enemies3, intents3)
	_check(res3.get("ok") == true, "AC2 Beat 3: phase execution succeeded")
	var events3: Array = res3.get("events", [])
	_check(events3.size() == 2, "AC2 Beat 3: two source-ordered phase events")
	_check(events3[0] == {"type": "debuff", "enemy_position": 1, "applied": true, "target_position": 2, "status": "exposed"},
		"AC2 Beat 3: event 0 matches debuff exposed on target 2 from source 1")
	_check(events3[1] == {"type": "attack", "enemy_position": 2, "applied": true, "target_position": 2},
		"AC2 Beat 3: event 1 matches attack on target 2 from source 2")

	var warden3: Dictionary = party3.get_hero(1)
	_check(warden3.get("id") == "warden" and warden3.get("hp") == 40 and warden3.get("block") == 6,
		"AC2 Beat 3: Warden untouched at 40 HP and 6 Block")
	var seamstress3: Dictionary = party3.get_hero(2)
	_check(seamstress3.get("id") == "seamstress" and seamstress3.get("hp") == 24 and seamstress3.get("block") == 0,
		"AC2 Beat 3: Seamstress takes floor(4 * 1.5) = 6 damage: 30 HP -> 24")
	_check(seamstress3.get("statuses", {}) == {"exposed": 1},
		"AC2 Beat 3: Seamstress holds Exposed 1 status attached")
	var tinker3: Dictionary = party3.get_hero(3)
	_check(tinker3.get("id") == "tinker" and tinker3.get("hp") == 26 and tinker3.get("block") == 0,
		"AC2 Beat 3: Tinker untouched at 26 HP and 0 Block")

	var stalker3: Dictionary = enemies3.get_enemy(1)
	_check(stalker3.get("id") == "spool_stalker" and stalker3.get("hp") == 14 and stalker3.get("block") == 0,
		"AC2 Beat 3: Spool Stalker has 14 HP, 0 Block")
	var guard3: Dictionary = enemies3.get_enemy(2)
	_check(guard3.get("id") == "button_guard" and guard3.get("hp") == 16 and guard3.get("block") == 0,
		"AC2 Beat 3: Button Guard has 16 HP, 0 Block")


func _test_ac2_downed_warden_rollback() -> void:
	# Downed Warden before beat 1:
	# Debuff on downed target fails closed; entire phase rolls back,
	# neither Warden nor Button Guard changes (Guard does NOT gain Block).
	var party: CombatParty = _build_party()
	var enemies: CombatEnemies = _build_enemies()

	_check(party.apply_damage(1, 46), "down Warden to 0 HP through 6 Block and 40 HP")
	_check(party.is_downed(1), "precondition: Warden is downed")
	_check(party.get_hero(1).get("hp") == 0 and party.get_hero(1).get("block") == 0,
		"precondition: Warden HP is 0, Block is 0")
	_check(enemies.get_enemy(2).get("block") == 0, "precondition: Button Guard has 0 Block")

	var snapshot_heroes_before: Array[Dictionary] = party.get_heroes()
	var snapshot_enemies_before: Array[Dictionary] = enemies.get_enemies()

	var scheduler: CombatEnemyIntents = CombatEnemyIntents.new(EXPECTED_SPOOLGUARD)
	var intents: Array[Dictionary] = scheduler.get_intents()

	# Also test input order reversal to ensure position-based staging still rolls back
	var reversed_intents: Array[Dictionary] = intents.duplicate(true)
	reversed_intents.reverse()

	var phase_service: CombatEnemyPhase = CombatEnemyPhase.new()
	var fail_res: Dictionary = phase_service.execute_phase(party, enemies, reversed_intents)

	_check(fail_res == {"ok": false, "events": []},
		"AC2 Downed: phase fails closed with ok=false and empty events")
	_check(party.get_heroes() == snapshot_heroes_before,
		"AC2 Downed: party state completely untouched (atomic rollback)")
	_check(enemies.get_enemies() == snapshot_enemies_before,
		"AC2 Downed: enemies state completely untouched (atomic rollback)")
	_check(enemies.get_enemy(2).get("block") == 0,
		"AC2 Downed: Button Guard did NOT gain 4 Block on rollback")


func _test_ac2_slain_source_skip() -> void:
	# Slain source 1 (Spool Stalker):
	# Source 1 action is marked applied=false, source 2 (Button Guard) still acts
	var party: CombatParty = _build_party()
	var enemies: CombatEnemies = _build_enemies()

	_check(enemies.apply_damage(1, 14), "slay Spool Stalker (14 HP -> 0)")
	_check(enemies.is_slain(1), "precondition: Spool Stalker is slain")
	_check(not enemies.is_slain(2), "precondition: Button Guard is living")

	var scheduler: CombatEnemyIntents = CombatEnemyIntents.new(EXPECTED_SPOOLGUARD)
	var intents: Array[Dictionary] = scheduler.get_intents()

	var phase_service: CombatEnemyPhase = CombatEnemyPhase.new()
	var slain_res: Dictionary = phase_service.execute_phase(party, enemies, intents)

	_check(slain_res.get("ok") == true, "slain source phase execution succeeds")
	var events: Array = slain_res.get("events", [])
	_check(events.size() == 2, "two events recorded even with slain source")
	_check(events[0] == {"type": "debuff", "enemy_position": 1, "applied": false, "target_position": 1, "status": "bleed"},
		"slain Spool Stalker intent has applied=false")
	_check(events[1] == {"type": "block", "enemy_position": 2, "applied": true},
		"living Button Guard block intent has applied=true")

	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6
		and party.get_hero(1).get("statuses", {}).is_empty(),
		"Warden took no Bleed from slain Spool Stalker")
	_check(enemies.get_enemy(2).get("block") == 4,
		"living Button Guard gained 4 Block")


func _test_ac3_map_selection_and_roster() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261022

	var map: RunMap = RunMap.new()
	_check(map.generate(rng), "AC3: RunMap generated successfully")

	var fight_node_id: String = ""
	for candidate in map.get_legal_choices():
		var node: Dictionary = map.get_node(candidate)
		if node.get("type") == "Fight":
			fight_node_id = String(candidate)
			break
	_check(not fight_node_id.is_empty(), "AC3: found legal opening Fight node on seeded map")
	_check(map.choose_node(fight_node_id), "AC3: chose legal Fight node on map")

	var selector: RunFightEncounterSelection = RunFightEncounterSelection.new()
	var test_local_pool: Dictionary = {
		"Fight": {
			ENCOUNTER_ID: SPOOLGUARD_PATH
		}
	}

	var selected: Dictionary = selector.select_current_battle(map, rng, test_local_pool)
	_check(selected.get("success") == true, "AC3: select_current_battle succeeded")
	_check(selected.get("node_type") == "Fight", "AC3: selected node_type is Fight")
	_check(selected.get("encounter_id") == ENCOUNTER_ID, "AC3: selected encounter_id is spoolguard_red_hem")
	_check(selected.get("definitions") == EXPECTED_SPOOLGUARD, "AC3: selected definitions match authored schedule")

	# Subsequent selection returns cached dictionary without advancing RNG
	var rng_state_before: int = rng.state
	var cached_selection: Dictionary = selector.select_current_battle(map, rng, test_local_pool)
	_check(cached_selection == selected, "AC3: cached selection returns identical dictionary")
	_check(rng.state == rng_state_before, "AC3: cached selection draws no extra RNG")

	# Assemble roster via RunTypedBattleRoster
	var roster_service: RunTypedBattleRoster = RunTypedBattleRoster.new()
	var local_rosters: Dictionary = {
		ENCOUNTER_ID: ["spool_stalker", "button_guard"]
	}
	var catalogs: Array = [RUN_ENEMIES_PATH]
	var assembled: Dictionary = roster_service.assemble(selected, local_rosters, catalogs)

	_check(assembled.get("ok") == true, "AC3: RunTypedBattleRoster.assemble succeeded")
	_check(assembled.get("node_type") == "Fight", "AC3: assembled node_type is Fight")
	_check(assembled.get("encounter_id") == ENCOUNTER_ID, "AC3: assembled encounter_id is spoolguard_red_hem")
	_check(assembled.get("definitions") == EXPECTED_SPOOLGUARD, "AC3: assembled definitions match authored schedule")

	var enemies: CombatEnemies = assembled.get("enemies")
	_check(enemies != null and enemies.is_valid(), "AC3: assembled CombatEnemies is valid")
	_check(enemies.get_enemies().size() == 2, "AC3: assembled CombatEnemies holds exactly two enemies")

	# Validate exact enemy definitions in slot order
	var en1: Dictionary = enemies.get_enemy(1)
	_check(en1.get("id") == "spool_stalker", "AC3: slot 1 is spool_stalker")
	_check(en1.get("name") == "Spool Stalker", "AC3: slot 1 name is Spool Stalker")
	_check(en1.get("hp") == 14 and en1.get("max_hp") == 14, "AC3: slot 1 HP is 14/14")
	_check(en1.get("block") == 0, "AC3: slot 1 initial Block is 0")
	_check(en1.get("art_path") == "res://assets/paper/enemies/spool_stalker.png", "AC3: slot 1 art_path is valid")

	var en2: Dictionary = enemies.get_enemy(2)
	_check(en2.get("id") == "button_guard", "AC3: slot 2 is button_guard")
	_check(en2.get("name") == "Button Guard", "AC3: slot 2 name is Button Guard")
	_check(en2.get("hp") == 16 and en2.get("max_hp") == 16, "AC3: slot 2 HP is 16/16")
	_check(en2.get("block") == 0, "AC3: slot 2 initial Block is 0")
	_check(en2.get("art_path") == "res://assets/paper/enemies/button_guard.png", "AC3: slot 2 art_path is valid")


func _test_ac3_replay_and_selector_negatives() -> void:
	# Independent seeded replay verification
	var trace1: Dictionary = _execute_seed_trace(987654321)
	var trace2: Dictionary = _execute_seed_trace(987654321)
	_check(not trace1.is_empty() and not trace2.is_empty(), "AC3 Replay: both independent seeded runs succeed")
	_check(trace1 == trace2, "AC3 Replay: identical seeds produce identical traces")

	# Negative checks for RunFightEncounterSelection
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 112233
	var unchosen_map: RunMap = RunMap.new()
	_check(unchosen_map.generate(rng), "negatives: unchosen map generated")
	var picker: RunFightEncounterSelection = RunFightEncounterSelection.new()
	var local_pool: Dictionary = {"Fight": {ENCOUNTER_ID: SPOOLGUARD_PATH}}

	# 1. Unchosen node rejects
	var unchosen_rng_before: int = rng.state
	var unchosen_res: Dictionary = picker.select_current_battle(unchosen_map, rng, local_pool)
	_check(unchosen_res == {"success": false}, "negatives: unchosen node rejects")
	_check(rng.state == unchosen_rng_before, "negatives: unchosen node rejection draws no RNG")

	# 2. Chosen non-Fight node rejects
	var nonfight_node_id: String = ""
	for candidate in unchosen_map.get_legal_choices():
		var node: Dictionary = unchosen_map.get_node(candidate)
		if node.get("type") != "Fight":
			nonfight_node_id = String(candidate)
			break
	if not nonfight_node_id.is_empty() and unchosen_map.choose_node(nonfight_node_id):
		var nonfight_rng_before: int = rng.state
		var nonfight_res: Dictionary = picker.select_current_battle(unchosen_map, rng, local_pool)
		_check(nonfight_res == {"success": false}, "negatives: chosen non-Fight node rejects")
		_check(rng.state == nonfight_rng_before, "negatives: non-Fight node rejection draws no RNG")

	# 3. Missing encounter file or empty pool rejects
	var chosen_map: RunMap = RunMap.new()
	var chosen_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	chosen_rng.seed = 445566
	_check(chosen_map.generate(chosen_rng), "negatives: chosen map generated")
	for candidate in chosen_map.get_legal_choices():
		if chosen_map.get_node(candidate).get("type") == "Fight":
			chosen_map.choose_node(candidate)
			break

	_check(picker.select_current_battle(chosen_map, chosen_rng, {"Fight": {}}) == {"success": false},
		"negatives: empty Fight pool rejects")
	_check(picker.select_current_battle(chosen_map, chosen_rng, {"Fight": {"missing": "res://data/encounters/missing.json"}}) == {"success": false},
		"negatives: missing schedule file rejects")

	# Negative checks for RunTypedBattleRoster.assemble
	var roster_service: RunTypedBattleRoster = RunTypedBattleRoster.new()
	var valid_selected: Dictionary = {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": EXPECTED_SPOOLGUARD
	}
	_check(roster_service.assemble({}, {}, []).get("ok") == false,
		"negatives: empty assemble inputs reject")
	_check(roster_service.assemble(valid_selected, {}, [RUN_ENEMIES_PATH]).get("ok") == false,
		"negatives: missing encounter in roster bindings rejects")
	_check(roster_service.assemble(valid_selected, {ENCOUNTER_ID: ["spool_stalker"]}, [RUN_ENEMIES_PATH]).get("ok") == false,
		"negatives: mismatched roster count (1 enemy for 2 definitions) rejects")
	_check(roster_service.assemble(valid_selected, {ENCOUNTER_ID: ["unknown_enemy", "button_guard"]}, [RUN_ENEMIES_PATH]).get("ok") == false,
		"negatives: unknown enemy id in roster rejects")


func _execute_seed_trace(seed_val: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val

	var map: RunMap = RunMap.new()
	if not map.generate(rng):
		return {}

	var fight_id: String = ""
	for candidate in map.get_legal_choices():
		if map.get_node(candidate).get("type") == "Fight":
			fight_id = String(candidate)
			break
	if fight_id.is_empty() or not map.choose_node(fight_id):
		return {}

	var selector: RunFightEncounterSelection = RunFightEncounterSelection.new()
	var pool: Dictionary = {"Fight": {ENCOUNTER_ID: SPOOLGUARD_PATH}}
	var selected: Dictionary = selector.select_current_battle(map, rng, pool)
	if not selected.get("success", false):
		return {}

	var roster_service: RunTypedBattleRoster = RunTypedBattleRoster.new()
	var local_rosters: Dictionary = {ENCOUNTER_ID: ["spool_stalker", "button_guard"]}
	var assembled: Dictionary = roster_service.assemble(selected, local_rosters, [RUN_ENEMIES_PATH])
	if not assembled.get("ok", false):
		return {}

	var party: CombatParty = _build_party()
	var enemies: CombatEnemies = assembled.get("enemies")
	var scheduler: CombatEnemyIntents = CombatEnemyIntents.new(assembled.get("definitions"))
	var phase_service: CombatEnemyPhase = CombatEnemyPhase.new()

	var trace: Dictionary = {
		"selected": selected,
		"heroes_after_beat1": [],
		"enemies_after_beat1": [],
	}

	var res: Dictionary = phase_service.execute_phase(party, enemies, scheduler.get_intents())
	if not res.get("ok", false):
		return {}

	trace["heroes_after_beat1"] = party.get_heroes()
	trace["enemies_after_beat1"] = enemies.get_enemies()
	trace["events_beat1"] = res.get("events", [])
	return trace
