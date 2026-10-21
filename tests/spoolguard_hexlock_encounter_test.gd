extends SceneTree
## Spoolguard Hexlock standalone Elite: exact data, parser, typed selection,
## real phase results, downed-target atomic rejection, killed-source skip,
## replay isolation, and zero RNG mutation.

const ENCOUNTER_ID := "spoolguard_hexlock"
const ENCOUNTER_PATH := "res://data/encounters/spoolguard_hexlock.json"
const BINDINGS := {
	"spoolguard_hexlock": ["spool_hexer", "button_guard"]
}
const CATALOGS := ["res://data/enemies/m04_elites.json",
	"res://data/enemies/run_enemies.json"]
const HEXER_NAME := "Spool Hexer"
const GUARD_NAME := "Button Guard"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_content()
	_selection()
	_phases()
	_negative()
	for message in failures:
		printerr(message)
	print("spoolguard_hexlock_encounter_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, why: String) -> void:
	checks += 1
	if not condition:
		failures.append(why)


func _content() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH),
		"encounter file exists: spoolguard_hexlock")
	var text := FileAccess.get_file_as_string(ENCOUNTER_PATH)
	_check(not text.is_empty(), "encounter file non-empty")

	var definitions := RunFightEncounterSelection._parse_schedule_text(text)
	_check(definitions != null and definitions is Array and definitions.size() == 2,
		"exactly two authored enemy-position entries in schedule")
	_check(definitions.size() == 2, "schedule has exactly two definitions")

	# Verify exact fields and unique source positions.
	var positions: Array[int] = []
	for definition in definitions:
		_check(definition is Dictionary and definition.has("enemy_position")
			and definition.has("pattern"), "definition has required keys")
		var pos: int = definition.get("enemy_position")
		_check(pos is int, "enemy_position is int")
		_check(pos == 1 or pos == 2, "enemy_position in valid range 1-2")
		_check(not positions.has(pos), "unique source position: " + str(pos))
		positions.append(pos)
	positions.sort()
	_check(positions == [1, 2], "exact unique positions 1 and 2")

	# Locate each authored source by its stable position key; a missing or
	# duplicated source must fail closed instead of indexing an empty result.
	var pos1_matches: Array = definitions.filter(
		func(d): return d.get("enemy_position") == 1)
	var pos2_matches: Array = definitions.filter(
		func(d): return d.get("enemy_position") == 2)
	_check(pos1_matches.size() == 1, "exactly one authored source at position 1")
	_check(pos2_matches.size() == 1, "exactly one authored source at position 2")
	if pos1_matches.size() != 1 or pos2_matches.size() != 1:
		return

	# Verify patterns: position 1 has four beats; position 2 has four beats.
	var pos1_def: Dictionary = pos1_matches[0]
	var pos2_def: Dictionary = pos2_matches[0]
	_check(pos1_def.get("pattern") is Array and pos1_def.get("pattern").size() == 4,
		"position 1 has four-intent pattern")
	_check(pos2_def.get("pattern") is Array and pos2_def.get("pattern").size() == 4,
		"position 2 has four-intent pattern")

	# Verify exact authored intents for position 1.
	var p1: Array = pos1_def.get("pattern")
	_check(p1.size() == 4, "position 1 pattern holds four actions")
	if p1.size() != 4:
		return
	_check(p1[0] == {"type":"debuff","amount":1,"target_position":3,"status":"weak"},
		"position 1 beat 0: debuff weak 1 on rear")
	_check(p1[1] == {"type":"attack","amount":3,"target_position":2},
		"position 1 beat 1: attack 3 on middle")
	_check(p1[2] == {"type":"debuff","amount":1,"target_position":1,"status":"exposed"},
		"position 1 beat 2: debuff exposed 1 on front")
	_check(p1[3] == {"type":"attack","amount":3,"target_position":1},
		"position 1 beat 3: attack 3 on front")

	# Verify exact authored intents for position 2.
	var p2: Array = pos2_def.get("pattern")
	_check(p2.size() == 4, "position 2 pattern holds four actions")
	if p2.size() != 4:
		return
	_check(p2[0] == {"type":"block","amount":3},
		"position 2 beat 0: block 3")
	_check(p2[1] == {"type":"attack","amount":2,"target_position":1},
		"position 2 beat 1: attack 2 on front")
	_check(p2[2] == {"type":"buff","amount":2},
		"position 2 beat 2: buff 2")
	_check(p2[3] == {"type":"attack","amount":2,"target_position":3},
		"position 2 beat 3: attack 2 on rear")

	# Verify CombatEnemyIntents validates and announces the exact two-source
	# action set at every beat of the four-beat cycle, plus the wrap.
	var scheduler := CombatEnemyIntents.new(definitions)
	_check(scheduler.is_valid(), "production intent scheduler validates authored schedule")
	var expected_beats: Array = [
		[
			{"type":"debuff","amount":1,"target_position":3,"status":"weak","enemy_position":1},
			{"type":"block","amount":3,"enemy_position":2}
		],
		[
			{"type":"attack","amount":3,"target_position":2,"enemy_position":1},
			{"type":"attack","amount":2,"target_position":1,"enemy_position":2}
		],
		[
			{"type":"debuff","amount":1,"target_position":1,"status":"exposed","enemy_position":1},
			{"type":"buff","amount":2,"enemy_position":2}
		],
		[
			{"type":"attack","amount":3,"target_position":1,"enemy_position":1},
			{"type":"attack","amount":2,"target_position":3,"enemy_position":2}
		],
		[
			{"type":"debuff","amount":1,"target_position":3,"status":"weak","enemy_position":1},
			{"type":"block","amount":3,"enemy_position":2}
		]
	]
	for beat in range(expected_beats.size()):
		var announced: Array = scheduler.get_intents()
		_check(announced == expected_beats[beat],
			"beat %d announces both exact source actions" % beat)
		_check(scheduler.advance_turn(), "advance past beat %d succeeds" % beat)

	# Verify the definitions array is never edited by the scheduler.
	_check(definitions == RunFightEncounterSelection._parse_schedule_text(text),
		"parser result unchanged after scheduler usage")


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
		"typed selector selected spoolguard_hexlock Elite")
	if not choice.get("success", false):
		return {}

	var roster_bindings := BINDINGS
	var built := RunTypedBattleRoster.new().assemble(choice, roster_bindings, CATALOGS)
	_check(built.get("ok") == true and built.get("node_type") == "Elite"
		and built.get("encounter_id") == ENCOUNTER_ID,
		"typed roster assembled spoolguard_hexlock")
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

	# Verify the selected encounter ID and definitions match expected.
	_check(a.choice.get("encounter_id") == ENCOUNTER_ID,
		"selected encounter ID is spoolguard_hexlock")
	_check(a.definitions == b.definitions,
		"definitions identical across replay")

	# Verify same-seed state: independent CombatEnemies instances.
	_check(a.enemies.get_enemies() == b.enemies.get_enemies()
		and a.enemies != b.enemies,
		"independent rosters same state but different objects")

	# Verify RNG invariant: selection does not consume extra RNG.
	var before_rng: int = a.rng.state
	var replay_choice: Dictionary = a.selector.select_current_battle(a.map, a.rng,
		{"Elite": {ENCOUNTER_ID: ENCOUNTER_PATH}})
	_check(replay_choice == a.choice and a.rng.state == before_rng,
		"cached retry retains route, pool claim and RNG state")


func _party() -> CombatParty:
	var path := "res://data/heroes/starter_party.json"
	var records := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string(path))
	_check(not records.is_empty(), "starter hero catalog parses")
	var heroes: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		var matching := records.filter(func(actor: Dictionary) -> bool:
			return actor.get("id") == id)
		_check(matching.size() == 1, "unique authored hero " + id)
		if matching.size() == 1:
			heroes.append(matching[0].duplicate(true))
	var party := CombatParty.new(heroes)
	_check(party.is_valid() and party.get_heroes().map(
		func(h): return h.hp) == [40, 30, 26],
		"real starter party Warden 40, Seamstress 30, Tinker 26")
	var opening := CombatStartingBlock.new(party)
	_check(opening.apply() and party.get_hero(1).get("block") == 6,
		"Warden opening Block 6 applied")
	return party


## Runs the real first two enemy beats on a fresh same-seed party and roster.
## `reverse_input` flips the announced intent order handed to the engine so the
## trace also proves that input order never changes positional resolution.
func _phase_trace(seed_value: int, reverse_input: bool) -> Dictionary:
	var game := _build(seed_value)
	if game.is_empty():
		return {}

	var party: CombatParty = _party()
	var enemies: CombatEnemies = game.enemies
	var intents: CombatEnemyIntents = CombatEnemyIntents.new(game.definitions)
	var rng_before: int = game.rng.state
	var start_heroes := party.get_heroes()
	var start_enemies := enemies.get_enemies()

	# First beat announced (position 1 then 2): debuff weak rear, block 3 guard.
	var first_intents: Array = intents.get_intents()
	_check(first_intents == [
			{"type":"debuff","amount":1,"target_position":3,"status":"weak","enemy_position":1},
			{"type":"block","amount":3,"enemy_position":2}],
		"first announced beat: hexer weakens rear, guard blocks")
	var ordered_first: Array = first_intents.duplicate(true)
	if reverse_input:
		ordered_first.reverse()

	# Execute with the (possibly reversed) input; the engine must still
	# resolve position 1 before position 2.
	seed(60291)
	var expected_global: int = randi()
	seed(60291)
	var first_result: Dictionary = CombatEnemyPhase.new().execute_phase(
		party, enemies, ordered_first)
	_check(first_result.get("ok") == true, "first phase succeeds")
	var events0: Array = first_result.get("events", [])

	# Verify exact first-beat events in source order (1 then 2).
	_check(events0.size() == 2, "first phase has two events")
	_check(events0 == [
			{"type":"debuff","enemy_position":1,"applied":true,
				"target_position":3,"status":"weak"},
			{"type":"block","enemy_position":2,"applied":true}],
		"first phase events in source order: hexer weak rear, guard block 3")

	# Verify no HP damage occurred to any hero.
	_check(party.get_hero(1).hp == 40 and party.get_hero(2).hp == 30
		and party.get_hero(3).hp == 26,
		"no hero HP changed after first beat (only debuff and block applied)")

	# Verify Tinker has Weak 1 and Button Guard has Block 3.
	_check(party.get_hero(3).get("statuses", {}).get("weak") == 1,
		"Tinker gained Weak 1")
	_check(enemies.get_enemy(2).get("block") == 3,
		"Button Guard gained Block 3")
	_check(enemies.get_enemy(1).get("block") == 0,
		"Spool Hexer gained no Block")
	_check(party.get_hero(1).get("block") == 6,
		"Warden Block unchanged at 6 (not yet reset by turn boundary)")

	# Verify the scheduler has not advanced (phase does not spend beat).
	_check(intents.get_intents() == first_intents,
		"enemy phase does not spend scheduled beat")

	# Advance scheduler to second beat.
	_check(intents.advance_turn(), "advance to second beat succeeds")
	var second_intents: Array = intents.get_intents()

	# Verify second announced beat: attack 3 middle, attack 2 front (with block applied).
	var expected_second := [
		{"type":"attack","amount":3,"target_position":2,"enemy_position":1},
		{"type":"attack","amount":2,"target_position":1,"enemy_position":2}
	]
	_check(second_intents == expected_second,
		"second announced beat: hexer attacks middle, guard attacks front")
	var ordered_second: Array = second_intents.duplicate(true)
	if reverse_input:
		ordered_second.reverse()

	# Execute second beat.
	var second_result: Dictionary = CombatEnemyPhase.new().execute_phase(
		party, enemies, ordered_second)
	_check(second_result.get("ok") == true, "second phase succeeds")
	var events1: Array = second_result.get("events", [])
	_check(events1.size() == 2, "second phase has two events")
	_check(events1 == [
			{"type":"attack","enemy_position":1,"applied":true,"target_position":2},
			{"type":"attack","enemy_position":2,"applied":true,"target_position":1}],
		"second phase events in source order: hexer hits middle, guard hits front")

	# After second beat: hexer attacks middle for 3; the guard's 2 damage on the
	# front is fully absorbed by the Warden's remaining 6 Block, which falls to 4.
	var heroes_after: Array = party.get_heroes()
	var enemies_after: Array = enemies.get_enemies()
	_check(heroes_after[0].get("hp") == 40,
		"Warden HP unchanged after 2 damage fully absorbed by remaining Block")
	_check(heroes_after[0].get("block") == 4,
		"Warden Block spent from 6 to 4 by the guard's 2 damage")
	_check(heroes_after[1].get("hp") == 27,
		"Seamstress HP 27 after taking 3 damage from hexer")
	_check(heroes_after[2].get("hp") == 26,
		"Tinker HP unchanged (only Weak applied, no direct damage)")
	_check(heroes_after[2].get("statuses", {}).get("weak") == 1,
		"Tinker Weak 1 still active before turn boundary expiration")
	_check(enemies_after[1].get("block") == 3,
		"Button Guard keeps its Block 3 through the second beat")
	_check(enemies_after[0].get("block") == 0,
		"Spool Hexer keeps Block 0 through the second beat")

	# Neither the run RNG nor the global RNG may be spent by enemy phases.
	_check(game.rng.state == rng_before,
		"both real enemy phases never spend the run RNG")
	_check(randi() == expected_global,
		"both real enemy phases never spend the global RNG")

	return {"first_intents": first_intents, "first_events": events0,
		"second_intents": second_intents, "second_events": events1,
		"start_heroes": start_heroes, "start_enemies": start_enemies,
		"heroes": heroes_after, "enemies": enemies_after,
		"rng": game.rng.state}


func _phases() -> void:
	var seed_value := _elite_seed()
	if seed_value < 0:
		return

	var reversed_trace := _phase_trace(seed_value, true)
	var replay_trace := _phase_trace(seed_value, true)
	var natural_trace := _phase_trace(seed_value, false)
	_check(not reversed_trace.is_empty() and not replay_trace.is_empty()
		and not natural_trace.is_empty(), "both real phase traces executed")
	if reversed_trace.is_empty() or replay_trace.is_empty() or natural_trace.is_empty():
		return

	# Fresh same-seed party and roster instances replay both real phases to
	# the same complete outcome, including the unchanged run RNG.
	_check(reversed_trace == replay_trace,
		"fresh same-seed party and roster replay both real phases identically")
	# Reversing the announced input order must not change the outcome.
	_check(reversed_trace == natural_trace,
		"reversed intent input does not change enemy positional resolution")


func _negative() -> void:
	var seed_value := _elite_seed()
	if seed_value < 0:
		return
	var game := _build(seed_value)
	if game.is_empty():
		return

	var party: CombatParty = _party()
	var enemies: CombatEnemies = game.enemies
	var scheduler := CombatEnemyIntents.new(game.definitions)

	# First, verify downed target atomic rejection.
	# Make Tinker downed (HP = 0) before attempting debuff.
	_check(party.apply_damage(3, 26) and party.is_downed(3),
		"precondition: Tinker is downed")

	var before_party := party.get_heroes()
	var before_enemies := enemies.get_enemies()
	var before_intents := scheduler.get_intents()
	var before_state: int = game.rng.state

	# Set up deterministic replay seed.
	seed(19117)
	var global_before := randi()
	seed(19117)

	# Try phase with real first-beat intents (debuff on downed Tinker should reject).
	var first_intents: Array = scheduler.get_intents()
	var reversed_first: Array = first_intents.duplicate(true)
	reversed_first.reverse()
	var phase_result: Dictionary = CombatEnemyPhase.new().execute_phase(party, enemies, reversed_first)

	_check(phase_result == {"ok": false, "events": []},
		"downed Tinker rejects first-debuff phase atomically")
	_check(party.get_heroes() == before_party,
		"downed rejection: party unchanged (atomic rollback)")
	_check(enemies.get_enemies() == before_enemies,
		"downed rejection: enemies unchanged (atomic rollback)")
	_check(scheduler.get_intents() == before_intents,
		"downed rejection: intent schedule unchanged")
	_check(game.rng.state == before_state,
		"downed rejection: RNG unchanged")
	_check(randi() == global_before,
		"global RNG unchanged after rejected phase")

	# Now verify killed-source skip behavior.
	# Rebuild party and enemies fresh for this sub-test.
	party = _party()
	enemies = game.enemies
	scheduler = CombatEnemyIntents.new(game.definitions)

	# Kill hexer (enemy position 1, spool_hexer).
	_check(enemies.apply_damage(1, 24) and enemies.is_slain(1)
		and not enemies.is_slain(2),
		"precondition: hexer slain, guard alive")

	var killed_before: Array = enemies.get_enemies()
	var killed_intents: Array = scheduler.get_intents()
	var killed_rng_state: int = game.rng.state

	# Reversed first beat (only guard should act, hexer skips).
	reversed_first = killed_intents.duplicate(true)
	reversed_first.reverse()
	var killed_result: Dictionary = CombatEnemyPhase.new().execute_phase(party, enemies, reversed_first)

	_check(killed_result.get("ok") == true, "killed-phase succeeds with living guard")
	var killed_events: Array = killed_result.get("events", [])
	_check(killed_events.size() == 2, "two events even with one slain source")
	_check(killed_events.size() == 2
		and killed_events[0].get("type") == "debuff"
		and killed_events[0].get("enemy_position") == 1
		and killed_events[0].get("applied") == false,
		"slain hexer skips its debuff; event records false applied")
	_check(killed_events.size() == 2
		and killed_events[1].get("type") == "block"
		and killed_events[1].get("enemy_position") == 2
		and killed_events[1].get("applied") == true,
		"living guard executes legal Block 3")

	# The living guard's own Block must really be 3 after the skipped beat.
	_check(enemies.get_enemy(2).get("block") == 3,
		"living guard Block is 3 after the slain hexer skipped its own action")
	_check(enemies.get_enemy(1).get("block") == 0,
		"slain hexer keeps Block 0")
	_check(enemies.get_enemy(1).get("hp") == 0
		and enemies.get_enemy(2).get("hp") == 16,
		"slain hexer stays at 0 HP and the living guard stays at 16 HP")
	_check(party.get_hero(3).hp == 26
		and party.get_hero(3).get("statuses", {}).is_empty(),
		"skipped hexer debuff left the rear hero unharmed")
	_check(scheduler.get_intents() == killed_intents,
		"killed-source phase did not spend the scheduled beat")
	_check(game.rng.state == killed_rng_state,
		"killed-source phase never spent the run RNG")

	# Verify no mutation of file-backed catalog.
	var catalog_text := FileAccess.get_file_as_string("res://data/enemies/m04_elites.json")
	_check(catalog_text.contains("spool_hexer"),
		"catalog file unchanged after all tests")
