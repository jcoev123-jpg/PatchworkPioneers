extends SceneTree
## Standalone M04 Elite fixtures: authored beats, typed rosters, actual phases,
## owner-turn status transitions, complete wrap/replay, and fail-closed inputs.

const PATHS := {
	"hexer_backthread_guard": "res://data/encounters/hexer_backthread_guard.json",
	"hexer_reel_pincer": "res://data/encounters/hexer_reel_pincer.json",
}
const BINDINGS := {
	"hexer_backthread_guard": ["spool_hexer", "button_guard"],
	"hexer_reel_pincer": ["spool_hexer", "seam_ripper"],
}
const CATALOGS := ["res://data/enemies/m04_elites.json", "res://data/enemies/run_enemies.json"]
const BACK := [
	[{"type":"debuff","amount":1,"target_position":3,"status":"weak"},
	 {"type":"attack","amount":3,"target_position":3},
	 {"type":"debuff","amount":1,"target_position":1,"status":"exposed"},
	 {"type":"buff","amount":2}],
	[{"type":"attack","amount":2,"target_position":2},
	 {"type":"block","amount":2},
	 {"type":"attack","amount":3,"target_position":1},
	 {"type":"attack","amount":2,"target_position":3}],
]
const REEL := [
	[{"type":"shove","amount":0,"target_position":2,"direction":1},
	 {"type":"debuff","amount":2,"target_position":3,"status":"bleed"},
	 {"type":"attack","amount":3,"target_position":2},
	 {"type":"buff","amount":2}],
	[{"type":"attack","amount":3,"target_position":3},
	 {"type":"attack","amount":2,"target_position":1},
	 {"type":"block","amount":2},
	 {"type":"attack","amount":3,"target_position":2}],
]
## Each row: current hero IDs, HP, hero Block, status dictionaries, enemy Block.
## Hero turns tick statuses and reset Block between enemy phases.
const BACK_STATES := [
	[["warden","seamstress","tinker"], [40,28,26], [6,0,0], [{},{},{"weak":1}], [0,0]],
	[["warden","seamstress","tinker"], [40,28,23], [0,0,0], [{},{},{}], [0,2]],
	[["warden","seamstress","tinker"], [36,28,23], [0,0,0], [{"exposed":1},{},{}], [0,2]],
	[["warden","seamstress","tinker"], [36,28,21], [0,0,0], [{},{},{}], [2,2]],
	[["warden","seamstress","tinker"], [36,26,21], [0,0,0], [{},{},{"weak":1}], [2,2]],
]
const REEL_STATES := [
	[["warden","tinker","seamstress"], [40,26,27], [6,0,0], [{},{},{}], [0,0]],
	[["warden","tinker","seamstress"], [38,26,27], [0,0,0], [{},{},{"bleed":2}], [0,0]],
	[["warden","tinker","seamstress"], [38,23,25], [0,0,0], [{},{},{"bleed":1}], [0,2]],
	[["warden","tinker","seamstress"], [38,20,24], [0,0,0], [{},{},{}], [2,2]],
	[["warden","seamstress","tinker"], [38,24,17], [0,0,0], [{},{},{}], [2,2]],
]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_content()
	_negative()
	for id in PATHS:
		var first := _trace(id)
		var again := _trace(id)
		_check(not first.is_empty() and first == again,
			id + ": fresh same-seed phase and wrap traces identical")
	_report()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _definitions(id: String) -> Array:
	var contents := FileAccess.get_file_as_string(PATHS[id])
	_check(not contents.is_empty(), id + ": authored file readable")
	return RunFightEncounterSelection._parse_schedule_text(contents)


func _content() -> void:
	for id in PATHS:
		var definitions := _definitions(id)
		_check(definitions.size() == 2, id + ": two valid intent sources")
		if definitions.size() != 2:
			continue
		var by_pos := {}
		for source in definitions:
			var pos: int = source.get("enemy_position", -1)
			_check(pos in [1,2] and not by_pos.has(pos)
				and source.size() == 2, id + ": unique positional source " + str(pos))
			by_pos[pos] = source.get("pattern", [])
		var expected: Array = BACK if id == "hexer_backthread_guard" else REEL
		for pos in [1,2]:
			_check(by_pos.has(pos) and by_pos[pos] == expected[pos - 1]
				and by_pos[pos].size() == 4, id + ": complete source " + str(pos) + " four beats")
		var intents := CombatEnemyIntents.new(definitions)
		_check(intents.is_valid(), id + ": CombatEnemyIntents accepts schedule")
		if not intents.is_valid():
			continue
		for beat in range(5):
			var announced := intents.get_intents()
			_check(announced.size() == 2, id + ": two announcements on " + str(beat))
			if announced.size() != 2:
				break
			for pos in [1,2]:
				var expected_action: Dictionary = expected[pos - 1][beat % 4].duplicate(true)
				expected_action["enemy_position"] = pos
				_check(announced[pos - 1] == expected_action,
					id + ": source " + str(pos) + " beat " + str(beat + 1) + " exact intent")
			_check(intents.advance_turn(), id + ": advance " + str(beat))
	for existing in ["spool_hexer_elite", "spoolhex_bleed_shift"]:
		var path: String = "res://data/encounters/" + existing + ".json"
		var parsed := RunFightEncounterSelection._parse_schedule_text(FileAccess.get_file_as_string(path))
		_check(parsed.size() == 2 and CombatEnemyIntents.new(parsed).is_valid(),
			existing + ": pre-existing encounter independently parses and validates")


func _party() -> CombatParty:
	var text := FileAccess.get_file_as_string("res://data/heroes/starter_party.json")
	var catalog := RunTypedBattleRoster._parse_catalog_text(text)
	_check(not catalog.is_empty(), "real starter hero catalog parses")
	var ordered: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		var matches := catalog.filter(func(hero): return hero.get("id") == id)
		_check(matches.size() == 1, "single authored hero " + id)
		if matches.size() == 1:
			ordered.append(matches[0])
	return CombatParty.new(ordered)


func _choice(id: String, definitions: Array) -> Dictionary:
	return {"success": true, "node_type": "Elite",
		"encounter_id": id, "definitions": definitions}


func _build(id: String, definitions: Array) -> Dictionary:
	var choice := _choice(id, definitions)
	return RunTypedBattleRoster.new().assemble(choice, BINDINGS, CATALOGS)


func _trace(id: String) -> Dictionary:
	var definitions := _definitions(id)
	if definitions.size() != 2:
		return {}
	var built := _build(id, definitions)
	_check(built.get("ok") == true and built.get("node_type") == "Elite"
		and built.get("encounter_id") == id, id + ": typed Elite roster assembles")
	if not built.get("ok", false):
		return {}
	var enemies: CombatEnemies = built.enemies
	var party := _party()
	_check(party.is_valid() and enemies.is_valid(), id + ": real rosters valid")
	if not party.is_valid() or not enemies.is_valid():
		return {}
	for pos in [1,2]:
		var enemy := enemies.get_enemy(pos)
		var expected_id: String = BINDINGS[id][pos - 1]
		var hp: int = 24 if pos == 1 else (16 if id == "hexer_backthread_guard" else 18)
		_check(enemy.get("id") == expected_id and enemy.get("position") == pos
			and enemy.get("hp") == hp and enemy.get("max_hp") == hp
			and enemy.get("block") == 0 and not enemy.get("name", "").is_empty()
			and enemy.get("art_path", "").begins_with("res://assets/paper/enemies/"),
			id + ": source " + str(pos) + " authentic catalog ID/HP/name/art")
	for pos in [1,2,3]:
		var hero := party.get_hero(pos)
		_check(hero.get("id") == ["warden","seamstress","tinker"][pos - 1]
			and hero.get("hp") == [40,30,26][pos - 1]
			and hero.get("max_hp") == hero.get("hp")
			and hero.get("block") == 0 and hero.get("statuses", {}).is_empty(),
			id + ": authentic clean opening hero " + str(pos))
	_check(CombatStartingBlock.new(party).apply()
		and party.get_hero(1).get("block") == 6, id + ": real Warden opening Block")
	var scheduler := CombatEnemyIntents.new(built.definitions)
	_check(scheduler.is_valid(), id + ": roster schedule usable")
	if not scheduler.is_valid():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1170642
	var initial_rng: int = rng.state
	var trace := {"announcements": [], "events": [], "heroes": [], "enemies": [], "ticks": []}
	var expected_states: Array = BACK_STATES if id == "hexer_backthread_guard" else REEL_STATES
	for beat in range(5):
		if beat > 0:
			# The real round-flow owner transition occurs before the next enemy phase.
			var tick := CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())
			_check(tick.get("ok") == true and tick.get("events", []).size() == 3,
				id + ": owner-turn status tick " + str(beat))
			if not tick.get("ok", false):
				return {}
			trace.ticks.append(tick.events.duplicate(true))
			if id == "hexer_reel_pincer" and beat == 2:
				_check(tick.events[2].bleed_hp_loss == 2
					and tick.actors[2].hp == 25 and tick.actors[2].statuses == {"bleed":1},
					"reel: Bleed 2 damages Seamstress, decrements to 1")
			if id == "hexer_reel_pincer" and beat == 3:
				_check(tick.events[2].bleed_hp_loss == 1
					and tick.actors[2].hp == 24 and tick.actors[2].statuses.is_empty(),
					"reel: Bleed 1 damages Seamstress and expires")
			if id == "hexer_backthread_guard" and beat == 1:
				_check(tick.actors[2].statuses.is_empty(),
					"backthread: Weak expires at Tinker's owner-turn boundary")
			if id == "hexer_backthread_guard" and beat == 3:
				_check(tick.actors[0].statuses.is_empty(),
					"backthread: Warden Exposed expires at owner's boundary")
			for index in range(3):
				party._heroes[index]["hp"] = tick.actors[index].hp
				party._heroes[index]["block"] = tick.actors[index].block
				party._heroes[index]["statuses"] = tick.actors[index].statuses.duplicate(true)
			_check(party.start_player_turn(), id + ": Block reset at player turn " + str(beat))
		var announced := scheduler.get_intents()
		_check(announced.size() == 2, id + ": phase has two sources " + str(beat))
		if announced.size() != 2:
			return {}
		var phase := CombatEnemyPhase.new().execute_phase(party, enemies, announced)
		_check(phase.get("ok") == true and phase.get("events", []).size() == 2,
			id + ": real enemy phase succeeds on beat " + str(beat + 1))
		if not phase.get("ok", false) or phase.events.size() != 2:
			return {}
		for source in range(2):
			var announced_action: Dictionary = announced[source]
			var event: Dictionary = phase.events[source]
			_check(event.get("enemy_position") == source + 1
				and event.get("type") == announced_action.type
				and event.get("applied") == true,
				id + ": ordered applied event source " + str(source + 1))
			for field in ["target_position", "status", "direction"]:
				if announced_action.has(field):
					_check(event.get(field) == announced_action[field],
						id + ": resolved event " + field + " on beat " + str(beat + 1))
		var expected: Array = expected_states[beat]
		for pos in [1,2,3]:
			var hero := party.get_hero(pos)
			_check(hero.get("position") == pos and hero.get("id") == expected[0][pos - 1]
				and hero.get("hp") == expected[1][pos - 1]
				and hero.get("block") == expected[2][pos - 1]
				and hero.get("statuses", {}) == expected[3][pos - 1],
				id + ": actual full hero state slot " + str(pos) + " beat " + str(beat + 1))
		for pos in [1,2]:
			var enemy := enemies.get_enemy(pos)
			_check(enemy.get("id") == BINDINGS[id][pos - 1]
				and enemy.get("hp") == enemy.get("max_hp")
				and enemy.get("block") == expected[4][pos - 1],
				id + ": actual enemy HP and Block source " + str(pos))
		trace.announcements.append(announced.duplicate(true))
		trace.events.append(phase.events.duplicate(true))
		trace.heroes.append(party.get_heroes())
		trace.enemies.append(enemies.get_enemies())
		_check(scheduler.advance_turn(), id + ": scheduler advances from beat " + str(beat + 1))
	_check(trace.announcements[0] == trace.announcements[4],
		id + ": complete four-beat cycle wraps to beat 1")
	_check(rng.state == initial_rng, id + ": status/phase path spends no run RNG")
	trace["rng_state"] = rng.state
	return trace


func _negative() -> void:
	var valid := _definitions("hexer_reel_pincer")
	if valid.size() != 2:
		return
	var malformed := valid.duplicate(true)
	malformed[0].pattern[0].direction = 2
	_check(not CombatEnemyIntents.new(malformed).is_valid(),
		"malformed shove direction rejects scheduler")
	var altered := valid.duplicate(true)
	altered[1].pattern[0].amount = 1.5
	_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(altered)).is_empty(),
		"fractional damage rejected by parser without integer truncation")
	var duplicate := valid.duplicate(true)
	duplicate[1].enemy_position = 1
	_check(not CombatEnemyIntents.new(duplicate).is_valid()
		and RunFightEncounterSelection._parse_schedule_text(JSON.stringify(duplicate)).is_empty(),
		"duplicate source positions rejected")
	_check(RunFightEncounterSelection._parse_schedule_text("{unparseable").is_empty(),
		"malformed JSON rejected")
	var choice := _choice("hexer_reel_pincer", valid)
	var choice_before := choice.duplicate(true)
	var bindings_before := BINDINGS.duplicate(true)
	var bad_bindings := BINDINGS.duplicate(true)
	bad_bindings["hexer_reel_pincer"] = ["spool_hexer", "unknown_enemy"]
	_check(not RunTypedBattleRoster.new().assemble(choice, bad_bindings, CATALOGS).get("ok", false),
		"unknown roster enemy rejected without phantom opponent")
	var mismatched := choice.duplicate(true)
	mismatched.definitions = valid.slice(0, 1)
	_check(not RunTypedBattleRoster.new().assemble(mismatched, BINDINGS, CATALOGS).get("ok", false),
		"roster/schedule source count mismatch rejected")
	var unknown_kind := choice.duplicate(true)
	unknown_kind.node_type = "NotElite"
	_check(not RunTypedBattleRoster.new().assemble(unknown_kind, BINDINGS, CATALOGS).get("ok", false),
		"forged battle type rejected")
	var fight_kind := choice.duplicate(true)
	fight_kind.node_type = "Fight"
	var fight := RunTypedBattleRoster.new().assemble(fight_kind, BINDINGS, CATALOGS)
	_check(fight.get("ok") == true and fight.get("node_type") == "Fight"
		and fight.get("node_type") != "Elite",
		"non-Elite type stays Fight, cannot be identified/admitted as Elite")
	_check(choice == choice_before and BINDINGS == bindings_before,
		"rejections never mutate authored choice or roster bindings")

	var party := _party()
	var built := _build("hexer_reel_pincer", valid)
	_check(party.is_valid() and built.get("ok") == true, "downed shove fixtures valid")
	if not party.is_valid() or not built.get("ok", false):
		return
	var enemies: CombatEnemies = built.enemies
	_check(CombatStartingBlock.new(party).apply(), "negative fixture opens Warden Block")
	_check(party.get_hero(2).get("hp") == 30 and not party.is_downed(2),
		"shove mover living Seamstress at position 2")
	_check(party.apply_damage(3, 26) and party.is_downed(3),
		"shove destination Tinker downed at position 3")
	var before_heroes := party.get_heroes()
	var before_enemies := enemies.get_enemies()
	var scheduler := CombatEnemyIntents.new(valid)
	var announced := scheduler.get_intents()
	var randomizer := RandomNumberGenerator.new()
	randomizer.seed = 831
	var before_rng: int = randomizer.state
	_check(CombatEnemyPhase.new().execute_phase(party, enemies, announced)
		== {"ok":false, "events":[]}, "downed neighbor forbids swapping position 2 to 3")
	_check(party.get_heroes() == before_heroes and enemies.get_enemies() == before_enemies
		and randomizer.state == before_rng,
		"downed shove rejection preserves complete rosters and seeded RNG")
	var bad_phase := announced.duplicate(true)
	bad_phase[1].target_position = 4
	_check(CombatEnemyPhase.new().execute_phase(party, enemies, bad_phase)
		== {"ok":false, "events":[]}, "invalid second source rejects entire phase")
	_check(party.get_heroes() == before_heroes and enemies.get_enemies() == before_enemies
		and randomizer.state == before_rng,
		"invalid batch leaves earlier shove, enemy and RNG untouched")


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("m04_hexer_dual_elites_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
