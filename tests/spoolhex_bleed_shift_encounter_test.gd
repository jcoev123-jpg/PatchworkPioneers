extends SceneTree
## Spoolhex Bleed-and-Shift standalone M04 Elite: AC1-AC3.

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


func _selection() -> void:
	# Build roster with local Elite mapping (no live pool hookup).
	var choice := {
		"success": true,
		"node_type": "Elite",
		"encounter_id": ENCOUNTER_ID,
		"definitions": RunFightEncounterSelection._parse_schedule_text(
			FileAccess.get_file_as_string(ENCOUNTER_PATH))
	}
	var built := RunTypedBattleRoster.new().assemble(
		choice, BINDINGS, CATALOGS)
	_check(built.get("ok") == true,
		"typed roster assembles spoolhex_bleed_shift")
	if not built.get("ok", false):
		return

	_check(built.get("encounter_id") == ENCOUNTER_ID,
		"assembled encounter ID matches")
	_check(built.get("node_type") == "Elite",
		"assembled node type is Elite")

	var enemies: CombatEnemies = built.get("enemies")
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2,
		"roster has two enemy slots")

	var en1 := enemies.get_enemy(1)
	var en2 := enemies.get_enemy(2)
	_check(en1.get("id") == "spool_hexer" and en1.get("position") == 1
		and en1.get("max_hp") == 24 and en1.get("hp") == 24
		and en1.get("name") == HEXER_NAME
		and en1.get("art_path") == "res://assets/paper/enemies/spool_hexer.png"
		and en1.get("block") == 0,
		"enemy 1: spool_hexer at 1, HP 24, correct art")
	_check(en2.get("id") == "button_guard" and en2.get("position") == 2
		and en2.get("max_hp") == 16 and en2.get("hp") == 16
		and en2.get("name") == GUARD_NAME
		and en2.get("art_path") == "res://assets/paper/enemies/button_guard.png"
		and en2.get("block") == 0,
		"enemy 2: button_guard at 2, HP 16, correct art")


func _party() -> CombatParty:
	var records := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))
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


func _negative() -> void:
	# AC3: invalid actions fail before mutation; replay; downed-neighbor shove rejected.

	# Replay from fresh fixtures.
	var replay_party := _party()
	var replay_definitions := RunFightEncounterSelection._parse_schedule_text(
		FileAccess.get_file_as_string(ENCOUNTER_PATH))
	var replay_scheduler := CombatEnemyIntents.new(replay_definitions)
	var replay_choice := {
		"success": true, "node_type": "Elite",
		"encounter_id": ENCOUNTER_ID, "definitions": replay_definitions
	}
	var replay_built := RunTypedBattleRoster.new().assemble(
		replay_choice, BINDINGS, CATALOGS)
	var replay_enemies: CombatEnemies = replay_built.get("enemies")

	var replay_beat1: Array = []
	if replay_party.is_valid() and replay_enemies.is_valid():
		replay_beat1 = replay_scheduler.get_intents()
		var original_beat1 := replay_beat1.duplicate(true)
		var replay_result := CombatEnemyPhase.new().execute_phase(
			replay_party, replay_enemies, replay_beat1)
		_check(replay_result.get("ok") == true,
			"replay beat 1 succeeds on fresh fixtures")

	# Negative: bad shove direction on beat 2 (where shove actually occurs).
	var replay_scheduler2 := CombatEnemyIntents.new(replay_definitions)
	replay_scheduler2.advance_turn()  # move to beat 2
	var replay_beat2: Array = replay_scheduler2.get_intents()
	var bad_shove: Array = replay_beat2.duplicate(true)
	for action in bad_shove:
		if action.get("type") == "shove":
			action["direction"] = 2
	# The phase should reject atomically.
	var fresh_party_bad := _party()
	var fresh_built_bad := RunTypedBattleRoster.new().assemble(
		{"success": true, "node_type": "Elite",
		 "encounter_id": ENCOUNTER_ID, "definitions": replay_definitions},
		BINDINGS, CATALOGS)
	var fresh_enemies_bad: CombatEnemies = fresh_built_bad.get("enemies")
	var before_bad_party := fresh_party_bad.get_heroes()
	var before_bad_enemies := fresh_enemies_bad.get_enemies()

	var bad_result := CombatEnemyPhase.new().execute_phase(
		fresh_party_bad, fresh_enemies_bad, bad_shove)
	_check(bad_result == {"ok": false, "events": []},
		"bad shove direction rejected atomically")
	_check(fresh_party_bad.get_heroes() == before_bad_party
		and fresh_enemies_bad.get_enemies() == before_bad_enemies,
		"bad shove: no partial mutation")

	# Negative: invalid debuff status on beat 1 (where debuff actually occurs).
	var replay_beat1_for_debuff: Array = replay_scheduler.get_intents()
	var bad_debuff: Array = replay_beat1_for_debuff.duplicate(true)
	for action in bad_debuff:
		if action.get("type") == "debuff" and action.get("status") == "bleed":
			action["status"] = "unknown_status"
	var fresh_party_bad2 := _party()
	var fresh_built_bad2 := RunTypedBattleRoster.new().assemble(
		{"success": true, "node_type": "Elite",
		 "encounter_id": ENCOUNTER_ID, "definitions": replay_definitions},
		BINDINGS, CATALOGS)
	var fresh_enemies_bad2: CombatEnemies = fresh_built_bad2.get("enemies")
	var before_bad2_party := fresh_party_bad2.get_heroes()
	var before_bad2_enemies := fresh_enemies_bad2.get_enemies()

	var bad_debuff_result := CombatEnemyPhase.new().execute_phase(
		fresh_party_bad2, fresh_enemies_bad2, bad_debuff)
	_check(bad_debuff_result == {"ok": false, "events": []},
		"invalid debuff status rejected atomically")
	_check(fresh_party_bad2.get_heroes() == before_bad2_party
		and fresh_enemies_bad2.get_enemies() == before_bad2_enemies,
		"invalid debuff: no partial mutation")

	# Negative: downed hero blocks adjacent swap.
	var down_party := _party()
	# Make Seamstress (position 2) downed before attempting shove.
	_check(down_party.apply_damage(2, 30) and down_party.is_downed(2),
		"precondition: Seamstress downed at position 2")
	var down_built := RunTypedBattleRoster.new().assemble(
		{"success": true, "node_type": "Elite",
		 "encounter_id": ENCOUNTER_ID, "definitions": replay_definitions},
		BINDINGS, CATALOGS)
	var down_enemies: CombatEnemies = down_built.get("enemies")

	var down_intents := replay_scheduler.get_intents()
	# The shove on beat 2 targets position 2 (Seamstress) with direction 1.
	# Since Seamstress is downed, the swap should fail.
	# But note: on beat 1, the first source applies debuff/attack first, then source 2.
	# Let's test specifically with beat 2, since that's when shove occurs.
	_check(replay_scheduler.advance_turn(), "advance to beat 2 for down test")
	var beat2_down := replay_scheduler.get_intents()

	var before_down_party := down_party.get_heroes()
	var before_down_enemies := down_enemies.get_enemies()
	var down_result := CombatEnemyPhase.new().execute_phase(
		down_party, down_enemies, beat2_down)
	_check(down_result == {"ok": false, "events": []},
		"downed neighbor blocks shove: phase rejected atomically")
	_check(down_party.get_heroes() == before_down_party
		and down_enemies.get_enemies() == before_down_enemies,
		"downed neighbor: no partial mutation")


func _report() -> void:
	for message in failures:
		printerr(message)
	print("spoolhex_bleed_shift_encounter_test: ",
		"PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
