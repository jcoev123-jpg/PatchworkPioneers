extends SceneTree
## Spoolhex Bleed-and-Shift standalone M04 Elite: exact data, parser, typed selection,
## real three-beat phase results, downed-neighbor atomic rejection,
## replay isolation, and zero RNG mutation.

const ENCOUNTER_ID := "spoolhex_bleed_shift"
const ENCOUNTER_PATH := "res://data/encounters/spoolhex_bleed_shift.json"
const BINDINGS := {
	"spoolhex_bleed_shift": ["spool_hexer", "button_guard"]
}
const CATALOGS := [
	"res://data/enemies/m04_elites.json",
	"res://data/enemies/run_enemies.json"
]
const HEXER_NAME := "Spool Hexer"
const GUARD_NAME := "Button Guard"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_content()
	_selection()
	_phases()
	_replays()
	_negative()
	_report()


func _check(condition: bool, why: String) -> void:
	checks += 1
	if not condition:
		failures.append(why)


func _content() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH),
		"encounter file exists")
	var text := FileAccess.get_file_as_string(ENCOUNTER_PATH)
	_check(not text.is_empty(), "encounter file non-empty")

	var definitions := RunFightEncounterSelection._parse_schedule_text(text)
	_check(definitions is Array and definitions.size() == 2,
		"exactly two authored source entries")

	var positions: Array[int] = []
	for definition in definitions:
		_check(definition is Dictionary
			and definition.has("enemy_position")
			and definition.has("pattern"),
			"definition has required keys")
		var pos: int = definition.get("enemy_position")
		_check(pos is int and (pos == 1 or pos == 2),
			"enemy_position int 1 or 2")
		_check(not positions.has(pos),
			"unique source position: " + str(pos))
		positions.append(pos)

	var p1 := definitions.filter(func(d): return d.get("enemy_position") == 1)
	var p2 := definitions.filter(func(d): return d.get("enemy_position") == 2)
	_check(p1.size() == 1 and p2.size() == 1,
		"exactly one source at each position 1 and 2")

	var pattern1: Array = p1[0].get("pattern")
	var pattern2: Array = p2[0].get("pattern")
	_check(pattern1 is Array and pattern1.size() == 3,
		"source 1 three-beat pattern")
	_check(pattern2 is Array and pattern2.size() == 3,
		"source 2 three-beat pattern")

	# Exact authored beats.
	_check(pattern1[0] == {"type":"debuff","amount":2,"target_position":3,"status":"bleed"},
		"beat 1 source 1: debuff bleed 2 on position 3")
	_check(pattern1[1] == {"type":"shove","amount":0,"target_position":2,"direction":1},
		"beat 2 source 1: shove target 2 direction 1")
	_check(pattern1[2] == {"type":"buff","amount":3},
		"beat 3 source 1: buff 3")

	_check(pattern2[0] == {"type":"attack","amount":4,"target_position":3},
		"beat 1 source 2: attack 4 on position 3")
	_check(pattern2[1] == {"type":"debuff","amount":1,"target_position":3,"status":"weak"},
		"beat 2 source 2: debuff weak 1 on position 3")
	_check(pattern2[2] == {"type":"attack","amount":3,"target_position":1},
		"beat 3 source 2: attack 3 on position 1")

	# Verify previous authored Elite still parses independently.
	var spoolguard_path := "res://data/encounters/spoolguard_hexlock.json"
	var spoolguard_text := FileAccess.get_file_as_string(spoolguard_path)
	var spoolguard_def := RunFightEncounterSelection._parse_schedule_text(spoolguard_text)
	_check(spoolguard_def is Array and spoolguard_def.size() == 2,
		"previous spoolguard_hexlock still parses")

	# Verify CombatEnemyIntents validates the new schedule.
	var scheduler := CombatEnemyIntents.new(definitions)
	_check(scheduler.is_valid(), "new schedule validates with CombatEnemyIntents")


func _elite_seed() -> int:
	for value in range(1, 129):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		if map.generate(rng):
			for node_id in map.get_legal_choices():
				if map.get_node(node_id).get("type") == "Elite" and map.choose_node(node_id):
					return value
	return -1


func _route(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := RunMap.new()
	if not map.generate(rng):
		return {}
	for node_id in map.get_legal_choices():
		if map.get_node(node_id).get("type") == "Elite" and map.choose_node(node_id):
			return {"map": map, "rng": rng, "node": node_id}
	return {}


func _build(seed_value: int) -> Dictionary:
	var route := _route(seed_value)
	_check(not route.is_empty(), "generated legal Elite path")
	if route.is_empty():
		return {}
	var map: RunMap = route.map
	_check(map.get_node(route.node).get("type") == "Elite"
		and map.get_route() == [route.node] and map.get_current_floor() == 1,
		"selector input is actual chosen Elite node")

	var picker := RunFightEncounterSelection.new()
	var local_pool := {"Elite": {ENCOUNTER_ID: ENCOUNTER_PATH}}
	var choice := picker.select_current_battle(map, route.rng, local_pool)
	_check(choice.get("success") == true and choice.get("node_type") == "Elite"
		and choice.get("encounter_id") == ENCOUNTER_ID,
		"typed selector selected spoolhex_bleed_shift Elite")
	if not choice.get("success", false):
		return {}

	var roster_bindings := BINDINGS
	var built := RunTypedBattleRoster.new().assemble(choice, roster_bindings, CATALOGS)
	_check(built.get("ok") == true and built.get("node_type") == "Elite"
		and built.get("encounter_id") == ENCOUNTER_ID,
		"typed roster assembled spoolhex_bleed_shift")
	if not built.get("ok", false):
		return {}
	var enemies: CombatEnemies = built.enemies
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2,
		"assembled battle has two enemy slots")

	# Verify exact enemy IDs/HP/names/art paths.
	var en1 := enemies.get_enemy(1)
	var en2 := enemies.get_enemy(2)
	_check(en1.get("id") == "spool_hexer" and en1.get("position") == 1
		and en1.get("max_hp") == 24 and en1.get("hp") == 24
		and en1.get("name") == HEXER_NAME
		and en1.get("art_path") == "res://assets/paper/enemies/spool_hexer.png"
		and en1.get("block") == 0,
		"enemy 1: spool_hexer at position 1, HP 24, Spool Hexer, correct art, zero Block")
	_check(en2.get("id") == "button_guard" and en2.get("position") == 2
		and en2.get("max_hp") == 16 and en2.get("hp") == 16
		and en2.get("name") == GUARD_NAME
		and en2.get("art_path") == "res://assets/paper/enemies/button_guard.png"
		and en2.get("block") == 0,
		"enemy 2: button_guard at position 2, HP 16, Button Guard, correct art, zero Block")

	return {"map": map, "rng": route.rng, "selector": picker, "choice": choice,
		"enemies": enemies, "definitions": choice.get("definitions"),
		"roster_bindings": roster_bindings}


func _selection() -> void:
	var seed_value := _elite_seed()
	_check(seed_value > 0, "bounded seed search found actual legal Elite")
	if seed_value < 0:
		return

	var a := _build(seed_value)
	var b := _build(seed_value)
	_check(not a.is_empty() and not b.is_empty(),
		"independent same-seed builds succeed")
	if a.is_empty() or b.is_empty():
		return

	_check(a.map.get_floors() == b.map.get_floors()
		and a.map.get_route() == b.map.get_route()
		and a.rng.state == b.rng.state and a.choice == b.choice,
		"two independent same-seed Elite selections replay exactly")

	_check(a.choice.get("encounter_id") == ENCOUNTER_ID,
		"selected encounter ID matches spoolhex_bleed_shift")
	_check(a.definitions == b.definitions,
		"definitions identical across replay")

	_check(a.enemies.get_enemies() == b.enemies.get_enemies()
		and a.enemies != b.enemies,
		"independent rosters same state but different objects")

	var before_rng: int = a.rng.state
	var replay_choice: Dictionary = a.selector.select_current_battle(a.map, a.rng,
		{"Elite": {ENCOUNTER_ID: ENCOUNTER_PATH}})
	_check(replay_choice == a.choice and a.rng.state == before_rng,
		"cached retry retains route, pool claim and RNG state")


func _party() -> CombatParty:
	var records := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))
	_check(not records.is_empty(), "starter hero catalog parses")
	var heroes: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		var match := records.filter(func(r): return r.get("id") == id)
		_check(match.size() == 1, "hero catalog has unique " + id)
		if match.size() == 1:
			heroes.append(match[0].duplicate(true))
	return CombatParty.new(heroes)


func _fixture_check(party: CombatParty, enemies: CombatEnemies, label: String) -> bool:
	var ok := party.is_valid() and enemies.is_valid()
	_check(ok, label + ": fixtures valid")
	if not ok:
		return false
	for i in range(3):
		var hero: Dictionary = party.get_hero(i + 1)
		var hp: int = [40, 30, 26][i]
		var id: String = ["warden", "seamstress", "tinker"][i]
		_check(hero.get("id") == id and hero.get("hp") == hp
			and hero.get("max_hp") == hp and hero.get("block") == 0
			and hero.get("position") == i + 1,
			label + ": hero %d %s correct" % [i + 1, id])
	for i in range(2):
		var enemy: Dictionary = enemies.get_enemy(i + 1)
		var id: String = ["spool_hexer", "button_guard"][i]
		var max_hp: int = [24, 16][i]
		_check(enemy.get("id") == id and enemy.get("hp") == max_hp
			and enemy.get("max_hp") == max_hp and enemy.get("position") == i + 1
			and enemy.get("block") == 0,
			label + ": enemy %d %s HP %d" % [i + 1, id, max_hp])
	return true


func _phases() -> void:
	# AC2: three-beat tactical behavior.
	var party := _party()
	var definitions := RunFightEncounterSelection._parse_schedule_text(
		FileAccess.get_file_as_string(ENCOUNTER_PATH))
	var scheduler := CombatEnemyIntents.new(definitions)

	# Assemble real enemies.
	var choice := {
		"success": true, "node_type": "Elite",
		"encounter_id": ENCOUNTER_ID, "definitions": definitions
	}
	var built := RunTypedBattleRoster.new().assemble(
		choice, BINDINGS, CATALOGS)
	var enemies: CombatEnemies = built.get("enemies")

	if not _fixture_check(party, enemies, "AC2 pre"):
		return

	# Apply Warden opening block per starter rules.
	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "Warden opening block applied")
	_check(party.get_hero(1).get("block") == 6, "Warden starting block is 6")

	# Beat 1.
	var beat1 := scheduler.get_intents()
	_check(beat1.size() == 2, "beat 1 has two intents")
	_check(beat1[0]["enemy_position"] == 1, "beat 1 first source position 1")
	_check(beat1[1]["enemy_position"] == 2, "beat 1 second source position 2")

	var phase1 := CombatEnemyPhase.new().execute_phase(party, enemies, beat1)
	_check(phase1.get("ok") == true, "beat 1 phase succeeds")
	var events1: Array = phase1.get("events", [])
	_check(events1.size() == 2, "beat 1 produces two events")

	# Source 1 debuff bleed 2 on Tinker (position 3).
	_check(events1[0].get("type") == "debuff"
		and events1[0].get("enemy_position") == 1
		and events1[0].get("applied") == true
		and events1[0].get("target_position") == 3
		and events1[0].get("status") == "bleed",
		"beat 1 event 0: debuff bleed 2 applied to position 3")

	# Source 2 attack 4 on Tinker at position 3 (before swap).
	_check(events1[1].get("type") == "attack"
		and events1[1].get("enemy_position") == 2
		and events1[1].get("applied") == true
		and events1[1].get("target_position") == 3,
		"beat 1 event 1: attack 4 applied to position 3")

	# After beat 1: Tinker has Bleed 2 and took 4 raw damage (26 -> 22).
	# (Block is 0 initially, so full 4 applies; Warden has Block 6 from opening.)
	var hero_after1 := party.get_heroes()
	_check(hero_after1[2].get("hp") == 22,
		"beat 1: Tinker HP 26 - 4 = 22 (no block)")
	_check(hero_after1[2].get("statuses", {}).get("bleed") == 2,
		"beat 1: Tinker has Bleed 2")
	_check(hero_after1[0].get("hp") == 40,
		"beat 1: Warden HP unchanged")
	_check(party.get_hero(2).get("hp") == 30,
		"beat 1: Seamstress HP unchanged")

	# Advance scheduler.
	_check(scheduler.advance_turn(), "advance to beat 2")

	# Beat 2.
	var beat2 := scheduler.get_intents()
	_check(beat2.size() == 2, "beat 2 has two intents")
	# Source 1 shove target 2 direction 1.
	_check(beat2[0].get("type") == "shove"
		and beat2[0].get("enemy_position") == 1
		and beat2[0].get("target_position") == 2
		and beat2[0].get("direction") == 1,
		"beat 2 source 1: shove target 2 direction 1")
	# Source 2 debuff weak 1 on position 3.
	_check(beat2[1].get("type") == "debuff"
		and beat2[1].get("enemy_position") == 2
		and beat2[1].get("target_position") == 3
		and beat2[1].get("status") == "weak"
		and beat2[1].get("amount") == 1,
		"beat 2 source 2: debuff weak 1 on position 3")

	var phase2 := CombatEnemyPhase.new().execute_phase(party, enemies, beat2)
	_check(phase2.get("ok") == true, "beat 2 phase succeeds")

	# After beat 2: Seamstress (pos 2) and Tinker (pos 3) swapped.
	# The hero at original position 3 (Tinker) moved to position 2,
	# so Tinker's Bleed 2 follows her to position 2.
	# The hero now at position 3 (Seamstress) receives Weak 1.
	var hero_after2 := party.get_heroes()
	_check(hero_after2[0].get("id") == "warden",
		"beat 2: Warden stays at position 1")
	_check(hero_after2[1].get("id") == "tinker",
		"beat 2: Tinker moved to position 2 after shove")
	_check(hero_after2[2].get("id") == "seamstress",
		"beat 2: Seamstress moved to position 3 after shove")

	# Statuses follow identity, not slot.
	_check(hero_after2[1].get("statuses", {}).get("bleed") == 2,
		"beat 2: Tinker's Bleed 2 followed her to position 2")
	_check(hero_after2[2].get("statuses", {}).get("weak") == 1,
		"beat 2: Seamstress at position 3 has Weak 1")

	# Advance to beat 3.
	_check(scheduler.advance_turn(), "advance to beat 3")

	# Beat 3.
	var beat3 := scheduler.get_intents()
	_check(beat3[0].get("enemy_position") == 1,
		"beat 3 first source position 1")
	_check(beat3[1].get("enemy_position") == 2,
		"beat 3 second source position 2")

	_check(beat3[0].get("type") == "buff"
		and beat3[0].get("amount") == 3,
		"beat 3 source 1: buff 3")
	_check(beat3[1].get("type") == "attack"
		and beat3[1].get("target_position") == 1
		and beat3[1].get("amount") == 3,
		"beat 3 source 2: attack 3 on position 1")

	var phase3 := CombatEnemyPhase.new().execute_phase(party, enemies, beat3)
	_check(phase3.get("ok") == true, "beat 3 phase succeeds")

	# After beat 3: enemy 1 has Block 3; Warden takes 3 raw damage.
	# Warden's opening Block 6 was untouched by previous beats (no attacks on her).
	# So 3 damage is fully absorbed by Block: 6 -> 3, HP stays 40.
	var hero_after3 := party.get_heroes()
	_check(hero_after3[0].get("hp") == 40,
		"beat 3: Warden HP unchanged (3 absorbed by Block 6 -> 3)")
	_check(hero_after3[0].get("block") == 3,
		"beat 3: Warden Block reduced from 6 to 3")

	var enemy_after3 := enemies.get_enemies()
	_check(enemy_after3[0].get("block") == 3,
		"beat 3: source 1 (spool_hexer) gained Block 3")

	# Beat 4 should wrap to first beat.
	_check(scheduler.advance_turn(), "advance to beat 4")
	var beat4 := scheduler.get_intents()
	_check(beat4 == beat1,
		"beat 4 wraps exactly to beat 1")


func _phase_trace(seed_value: int, reverse_input: bool = false) -> Dictionary:
	var game := _build(seed_value)
	if game.is_empty():
		return {}

	var party := _party()
	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "Warden opening block applied in trace")

	var enemies: CombatEnemies = game.enemies
	var intents := CombatEnemyIntents.new(game.definitions)
	_check(intents.is_valid(), "intents scheduler valid in phase trace")

	var rng_before: int = game.rng.state

	seed(51839)
	var expected_global: int = randi()
	seed(51839)

	var announcements: Array = []
	var receipts: Array = []

	# Beat 1: Debuff bleed 2 on Tinker at position 3, attack 4 on Tinker at position 3.
	var announced1: Array = intents.get_intents()
	announcements.append(announced1)
	var input1: Array = announced1.duplicate(true)
	if reverse_input:
		input1.reverse()
	var res1: Dictionary = CombatEnemyPhase.new().execute_phase(party, enemies, input1)
	_check(res1.get("ok") == true, "trace beat 1 phase succeeds")
	receipts.append(res1.get("events", []))
	_check(intents.advance_turn(), "trace advance to beat 2")

	# Beat 2: Shove position 2 direction 1 (swap Seamstress/Tinker), debuff weak 1 on position 3 (now Seamstress).
	var announced2: Array = intents.get_intents()
	announcements.append(announced2)
	var input2: Array = announced2.duplicate(true)
	if reverse_input:
		input2.reverse()
	var res2: Dictionary = CombatEnemyPhase.new().execute_phase(party, enemies, input2)
	_check(res2.get("ok") == true, "trace beat 2 phase succeeds")
	receipts.append(res2.get("events", []))
	_check(intents.advance_turn(), "trace advance to beat 3")

	# Beat 3: Enemy 1 buff 3 Block, enemy 2 attack 3 on position 1 (Warden).
	var announced3: Array = intents.get_intents()
	announcements.append(announced3)
	var input3: Array = announced3.duplicate(true)
	if reverse_input:
		input3.reverse()
	var res3: Dictionary = CombatEnemyPhase.new().execute_phase(party, enemies, input3)
	_check(res3.get("ok") == true, "trace beat 3 phase succeeds")
	receipts.append(res3.get("events", []))
	_check(intents.advance_turn(), "trace advance to beat 4")

	# Beat 4 wrap check.
	var announced4: Array = intents.get_intents()
	announcements.append(announced4)
	_check(announced4 == announced1, "trace beat 4 wraps to beat 1")

	# Capture and assert unchanged run RNG state and expected global RNG draw across phase execution.
	_check(game.rng.state == rng_before,
		"three-beat phase cycle never spends run RNG")
	_check(randi() == expected_global,
		"three-beat phase cycle never spends global RNG")

	return {
		"announcements": announcements,
		"receipts": receipts,
		"heroes": party.get_heroes(),
		"enemies": enemies.get_enemies(),
		"rng_state": game.rng.state,
	}


func _replays() -> void:
	var seed_value := _elite_seed()
	_check(seed_value > 0, "bounded seed found for replays")
	if seed_value < 0:
		return

	var trace1 := _phase_trace(seed_value, false)
	var trace2 := _phase_trace(seed_value, false)
	var trace_rev := _phase_trace(seed_value, true)

	_check(not trace1.is_empty() and not trace2.is_empty() and not trace_rev.is_empty(),
		"two independent seeded replays and reversed input trace ran successfully")
	if trace1.is_empty() or trace2.is_empty() or trace_rev.is_empty():
		return

	# Assert equal announcements across the three-beat cycle.
	_check(trace1.announcements == trace2.announcements,
		"replays announce identical intent batches across all three beats")

	# Assert ordered phase event receipts across all three beats.
	_check(trace1.receipts == trace2.receipts,
		"replays produce identical ordered phase event receipts")

	# Assert full final hero/enemy states.
	_check(trace1.heroes == trace2.heroes,
		"replays produce identical full final hero states")
	_check(trace1.enemies == trace2.enemies,
		"replays produce identical full final enemy states")

	# Assert unchanged run RNG state.
	_check(trace1.rng_state == trace2.rng_state,
		"replays maintain identical run RNG state")

	# Complete equality of the two traces.
	_check(trace1 == trace2,
		"two independent same-seed three-beat replays match completely")

	# Input order invariance.
	_check(trace1 == trace_rev,
		"reversed announced intent order yields identical phase receipts and actor state")

	# Explicit verification of final hero states after the three-beat cycle:
	var heroes: Array = trace1.heroes
	_check(heroes[0].get("id") == "warden" and heroes[0].get("position") == 1
		and heroes[0].get("hp") == 40 and heroes[0].get("block") == 3
		and heroes[0].get("statuses", {}).is_empty(),
		"final hero 1: Warden HP 40, Block 3 (absorbed 3 from attack 3)")
	_check(heroes[1].get("id") == "tinker" and heroes[1].get("position") == 2
		and heroes[1].get("hp") == 22 and heroes[1].get("block") == 0
		and heroes[1].get("statuses", {}).get("bleed") == 2,
		"final hero 2: Tinker at position 2, HP 22 (took 4 from beat 1), Bleed 2 follows")
	_check(heroes[2].get("id") == "seamstress" and heroes[2].get("position") == 3
		and heroes[2].get("hp") == 30 and heroes[2].get("block") == 0
		and heroes[2].get("statuses", {}).get("weak") == 1,
		"final hero 3: Seamstress at position 3, HP 30, Weak 1 from beat 2")

	# Explicit verification of final enemy states after the three-beat cycle:
	var enemies: Array = trace1.enemies
	_check(enemies[0].get("id") == "spool_hexer" and enemies[0].get("position") == 1
		and enemies[0].get("hp") == 24 and enemies[0].get("block") == 3,
		"final enemy 1: Spool Hexer HP 24, Block 3 from beat 3 buff")
	_check(enemies[1].get("id") == "button_guard" and enemies[1].get("position") == 2
		and enemies[1].get("hp") == 16 and enemies[1].get("block") == 0,
		"final enemy 2: Button Guard HP 16, Block 0")


func _negative() -> void:
	var definitions := RunFightEncounterSelection._parse_schedule_text(
		FileAccess.get_file_as_string(ENCOUNTER_PATH))
	var scheduler := CombatEnemyIntents.new(definitions)

	# Beat 1 announced intents.
	var beat1_intents: Array = scheduler.get_intents()
	_check(scheduler.advance_turn(), "advance to beat 2 for negative fixtures")
	# Beat 2 announced intents: shove target 2 direction 1, debuff weak 1 target 3.
	var beat2_intents: Array = scheduler.get_intents()

	# Scenario 1: Bad shove target outside 1..3 on beat 2 (target_position = 4).
	var party_bad_target := _party()
	var built_bad_target := RunTypedBattleRoster.new().assemble(
		{"success": true, "node_type": "Elite",
		 "encounter_id": ENCOUNTER_ID, "definitions": definitions},
		BINDINGS, CATALOGS)
	var enemies_bad_target: CombatEnemies = built_bad_target.get("enemies")
	var before_party_bad_target := party_bad_target.get_heroes()
	var before_enemies_bad_target := enemies_bad_target.get_enemies()

	var bad_target_shove := beat2_intents.duplicate(true)
	for action in bad_target_shove:
		if action.get("type") == "shove":
			action["target_position"] = 4

	var bad_target_res := CombatEnemyPhase.new().execute_phase(
		party_bad_target, enemies_bad_target, bad_target_shove)
	_check(bad_target_res == {"ok": false, "events": []},
		"shove target 4 outside 1..3 rejected atomically")
	_check(party_bad_target.get_heroes() == before_party_bad_target
		and enemies_bad_target.get_enemies() == before_enemies_bad_target,
		"shove bad target: complete party and enemy snapshots unchanged")

	# Also test target_position = 0 (outside 1..3).
	var bad_zero_shove := beat2_intents.duplicate(true)
	for action in bad_zero_shove:
		if action.get("type") == "shove":
			action["target_position"] = 0
	var bad_zero_res := CombatEnemyPhase.new().execute_phase(
		party_bad_target, enemies_bad_target, bad_zero_shove)
	_check(bad_zero_res == {"ok": false, "events": []},
		"shove target 0 outside 1..3 rejected atomically")
	_check(party_bad_target.get_heroes() == before_party_bad_target
		and enemies_bad_target.get_enemies() == before_enemies_bad_target,
		"shove target 0: complete party and enemy snapshots unchanged")

	# Scenario 2: Separately tested bad shove direction on beat 2 (direction = 2).
	var party_bad_dir := _party()
	var built_bad_dir := RunTypedBattleRoster.new().assemble(
		{"success": true, "node_type": "Elite",
		 "encounter_id": ENCOUNTER_ID, "definitions": definitions},
		BINDINGS, CATALOGS)
	var enemies_bad_dir: CombatEnemies = built_bad_dir.get("enemies")
	var before_party_bad_dir := party_bad_dir.get_heroes()
	var before_enemies_bad_dir := enemies_bad_dir.get_enemies()

	var bad_dir_shove := beat2_intents.duplicate(true)
	for action in bad_dir_shove:
		if action.get("type") == "shove":
			action["direction"] = 2

	var bad_dir_res := CombatEnemyPhase.new().execute_phase(
		party_bad_dir, enemies_bad_dir, bad_dir_shove)
	_check(bad_dir_res == {"ok": false, "events": []},
		"bad shove direction 2 rejected atomically")
	_check(party_bad_dir.get_heroes() == before_party_bad_dir
		and enemies_bad_dir.get_enemies() == before_enemies_bad_dir,
		"bad shove direction: complete party and enemy snapshots unchanged")

	# Scenario 3: Invalid debuff status on beat 1.
	var party_bad_debuff := _party()
	var built_bad_debuff := RunTypedBattleRoster.new().assemble(
		{"success": true, "node_type": "Elite",
		 "encounter_id": ENCOUNTER_ID, "definitions": definitions},
		BINDINGS, CATALOGS)
	var enemies_bad_debuff: CombatEnemies = built_bad_debuff.get("enemies")
	var before_party_bad_debuff := party_bad_debuff.get_heroes()
	var before_enemies_bad_debuff := enemies_bad_debuff.get_enemies()

	var bad_debuff := beat1_intents.duplicate(true)
	for action in bad_debuff:
		if action.get("type") == "debuff" and action.get("status") == "bleed":
			action["status"] = "unknown_status"

	var bad_debuff_res := CombatEnemyPhase.new().execute_phase(
		party_bad_debuff, enemies_bad_debuff, bad_debuff)
	_check(bad_debuff_res == {"ok": false, "events": []},
		"invalid debuff status rejected atomically")
	_check(party_bad_debuff.get_heroes() == before_party_bad_debuff
		and enemies_bad_debuff.get_enemies() == before_enemies_bad_debuff,
		"invalid debuff: complete party and enemy snapshots unchanged")

	# Scenario 4: Downed destination neighbor blocks shove on beat 2.
	# Authored shove targets position 2 (Seamstress) with direction 1 toward destination position 3 (Tinker).
	# Leave Seamstress at position 2 alive (HP 30), and down Tinker at destination position 3 (HP 0).
	var down_neighbor_party := _party()
	var built_down := RunTypedBattleRoster.new().assemble(
		{"success": true, "node_type": "Elite",
		 "encounter_id": ENCOUNTER_ID, "definitions": definitions},
		BINDINGS, CATALOGS)
	var down_neighbor_enemies: CombatEnemies = built_down.get("enemies")

	_check(not down_neighbor_party.is_downed(2) and down_neighbor_party.get_hero(2).get("hp") == 30,
		"precondition: Seamstress is alive at mover position 2")
	_check(down_neighbor_party.apply_damage(3, 26) and down_neighbor_party.is_downed(3),
		"precondition: Tinker is downed at destination position 3")

	var before_down_party := down_neighbor_party.get_heroes()
	var before_down_enemies := down_neighbor_enemies.get_enemies()

	seed(42819)
	var global_before := randi()
	seed(42819)

	var down_neighbor_res := CombatEnemyPhase.new().execute_phase(
		down_neighbor_party, down_neighbor_enemies, beat2_intents)
	_check(down_neighbor_res == {"ok": false, "events": []},
		"downed destination neighbor blocks shove: phase rejected atomically")
	_check(down_neighbor_party.get_heroes() == before_down_party,
		"downed neighbor: complete party snapshot unchanged (no partial publication)")
	_check(down_neighbor_enemies.get_enemies() == before_down_enemies,
		"downed neighbor: complete enemies snapshot unchanged")
	_check(randi() == global_before,
		"downed neighbor rejection never spends global RNG")

	# Scenario 5: Downed target for debuff on beat 1.
	var down_target_party := _party()
	var built_down_target := RunTypedBattleRoster.new().assemble(
		{"success": true, "node_type": "Elite",
		 "encounter_id": ENCOUNTER_ID, "definitions": definitions},
		BINDINGS, CATALOGS)
	var down_target_enemies: CombatEnemies = built_down_target.get("enemies")
	_check(down_target_party.apply_damage(3, 26) and down_target_party.is_downed(3),
		"precondition: Tinker is downed at position 3 for beat-1 debuff")
	var before_down_target_party := down_target_party.get_heroes()
	var before_down_target_enemies := down_target_enemies.get_enemies()

	var down_target_res := CombatEnemyPhase.new().execute_phase(
		down_target_party, down_target_enemies, beat1_intents)
	_check(down_target_res == {"ok": false, "events": []},
		"downed target for debuff rejected atomically")
	_check(down_target_party.get_heroes() == before_down_target_party
		and down_target_enemies.get_enemies() == before_down_target_enemies,
		"downed target debuff: complete party and enemy snapshots unchanged")


func _report() -> void:
	for message in failures:
		printerr(message)
	print("spoolhex_bleed_shift_encounter_test: ",
		"PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
