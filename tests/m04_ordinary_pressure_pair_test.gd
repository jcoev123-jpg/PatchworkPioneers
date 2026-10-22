extends SceneTree
## Standalone ordinary M04 Fight records: canonical catalogs, complete fixed
## schedules, real enemy phases and owner turns, replay, slain and bad inputs.

const PATHS := {
	"loosehem_bleedrelay": "res://data/encounters/loosehem_bleedrelay.json",
	"pinrail_weakward": "res://data/encounters/pinrail_weakward.json",
}
const BINDINGS := {
	"loosehem_bleedrelay": ["seam_ripper", "fray_scavenger"],
	"pinrail_weakward": ["button_guard", "spool_stalker", "fray_scavenger"],
}
const ENEMY_CATALOG := "res://data/enemies/run_enemies.json"
const HERO_CATALOG := "res://data/heroes/starter_party.json"
const ENEMY_DATA := {
	"seam_ripper": [18, "Seam Ripper", "res://assets/paper/enemies/seam_ripper.png"],
	"fray_scavenger": [14, "Fray Scavenger", "res://assets/paper/enemies/fray_scavenger.png"],
	"button_guard": [16, "Button Guard", "res://assets/paper/enemies/button_guard.png"],
	"spool_stalker": [14, "Spool Stalker", "res://assets/paper/enemies/spool_stalker.png"],
}
const LOOSE := [
	[{"type":"debuff","amount":1,"target_position":2,"status":"bleed"},
	 {"type":"attack","amount":2,"target_position":2},
	 {"type":"block","amount":2},
	 {"type":"attack","amount":3,"target_position":1}],
	[{"type":"attack","amount":2,"target_position":3},
	 {"type":"debuff","amount":1,"target_position":3,"status":"weak"},
	 {"type":"attack","amount":3,"target_position":3},
	 {"type":"buff","amount":2}],
]
const PIN := [
	[{"type":"block","amount":2},
	 {"type":"debuff","amount":1,"target_position":1,"status":"exposed"},
	 {"type":"attack","amount":3,"target_position":1},
	 {"type":"buff","amount":2}],
	[{"type":"debuff","amount":1,"target_position":3,"status":"weak"},
	 {"type":"attack","amount":2,"target_position":3},
	 {"type":"attack","amount":2,"target_position":2},
	 {"type":"block","amount":3}],
	[{"type":"attack","amount":2,"target_position":2},
	 {"type":"block","amount":2},
	 {"type":"attack","amount":2,"target_position":1},
	 {"type":"attack","amount":2,"target_position":3}],
]
## Full actual state after each resolved beat, including wrap. Each row is:
## hero HP, hero Block, hero statuses, enemy Block. Owner-turn status ticks
## and player-turn Block resets occur BETWEEN beats, as in CombatRoundFlow.
const LOOSE_STATES := [
	[[40,30,24], [6,4,0], [{},{"bleed":1},{}], [0,0]],
	[[40,27,24], [0,0,0], [{},{},{"weak":1}], [0,0]],
	[[40,27,21], [0,0,0], [{},{},{}], [2,0]],
	[[37,27,21], [0,0,0], [{},{},{}], [2,2]],
	[[37,27,19], [0,0,0], [{},{"bleed":1},{}], [2,2]],
]
const PIN_STATES := [
	[[40,28,26], [6,0,0], [{},{},{"weak":1}], [2,0,0]],
	[[40,28,24], [0,0,0], [{"exposed":1},{},{}], [2,0,2]],
	[[35,26,24], [0,0,0], [{},{},{}], [2,0,2]],
	[[35,26,22], [0,0,0], [{},{},{}], [4,3,2]],
	[[35,24,22], [0,0,0], [{},{},{"weak":1}], [6,3,2]],
]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_content()
	for id in PATHS:
		var first: Dictionary = _trace(id, 120749)
		var second: Dictionary = _trace(id, 120749)
		_check(not first.is_empty() and first == second,
			id + ": two independent same-seed map/selection/phase traces replay")
		_slain_source(id)
	_negative()
	for failure in failures:
		printerr(failure)
	print("m04_ordinary_pressure_pair_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _patterns(id: String) -> Array:
	return LOOSE if id == "loosehem_bleedrelay" else PIN


func _definitions(id: String) -> Array:
	_check(FileAccess.file_exists(PATHS[id]), id + ": authored JSON exists")
	var content: String = FileAccess.get_file_as_string(PATHS[id])
	_check(not content.is_empty(), id + ": authored JSON readable")
	return RunFightEncounterSelection._parse_schedule_text(content)


func _content() -> void:
	for id in PATHS:
		var definitions: Array = _definitions(id)
		var expected_patterns: Array = _patterns(id)
		_check(definitions.size() == expected_patterns.size(),
			id + ": authentic count of ordered enemy sources")
		if definitions.size() != expected_patterns.size():
			continue
		var expected: Array = []
		for index in range(expected_patterns.size()):
			expected.append({"enemy_position":index + 1, "pattern":expected_patterns[index]})
		_check(definitions == expected, id + ": exact slots and EVERY typed action/amount/target/status")
		var scheduler := CombatEnemyIntents.new(definitions)
		_check(scheduler.is_valid(), id + ": normalized definitions valid")
		if not scheduler.is_valid():
			continue
		for beat in range(5):
			var announcements: Array[Dictionary] = scheduler.get_intents()
			_check(announcements.size() == expected_patterns.size(),
				id + ": every source announces on beat " + str(beat + 1))
			if announcements.size() != expected_patterns.size():
				break
			for index in range(expected_patterns.size()):
				var expected_action: Dictionary = expected_patterns[index][beat % 4].duplicate(true)
				expected_action["enemy_position"] = index + 1
				_check(announcements[index] == expected_action,
					id + ": source " + str(index + 1) + " complete beat " + str(beat + 1))
			_check(scheduler.advance_turn(), id + ": scheduler advances " + str(beat))


func _party() -> CombatParty:
	var catalog: Array = RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string(HERO_CATALOG))
	_check(not catalog.is_empty(), "starter hero JSON parses")
	var ordered: Array = []
	for index in range(3):
		var id: String = ["warden", "seamstress", "tinker"][index]
		var matches: Array = catalog.filter(func(hero): return hero.get("id") == id)
		_check(matches.size() == 1, "starter catalog contains one " + id)
		if matches.size() == 1:
			var hero: Dictionary = matches[0]
			_check(hero.get("name") == ["Warden","Seamstress","Tinker"][index]
				and hero.get("max_hp") == [40,30,26][index]
				and hero.get("art_path") == "res://assets/paper/heroes/" + id + ".png",
				id + ": actual name, health and art from starter catalog")
			ordered.append(hero)
	return CombatParty.new(ordered)


func _selection(id: String, rng: RandomNumberGenerator) -> Dictionary:
	var map := RunMap.new()
	_check(map.generate(rng), id + ": seeded run map generates")
	var opening := ""
	for candidate in map.get_legal_choices():
		if map.get_node(candidate).get("type") == "Fight":
			opening = String(candidate)
			break
	_check(not opening.is_empty(), id + ": actual legal Fight exists")
	if opening.is_empty():
		return {}
	_check(map.choose_node(opening), id + ": choose real Fight")
	var pool := {}
	pool[id] = PATHS[id]
	var result: Dictionary = RunFightEncounterSelection.new().select_current_battle(
		map, rng, {"Fight": pool})
	_check(result.get("success") == true and result.get("node_type") == "Fight"
		and result.get("encounter_id") == id, id + ": public selector loads authored Fight")
	_check(result.get("definitions", []) == _definitions(id),
		id + ": selector's parsed definitions match disk")
	return result


func _build(id: String, selected: Dictionary) -> Dictionary:
	var built: Dictionary = RunTypedBattleRoster.new().assemble(
		selected, BINDINGS, [ENEMY_CATALOG])
	_check(built.get("ok") == true and built.get("node_type") == "Fight"
		and built.get("encounter_id") == id, id + ": actual typed normal Fight assembles")
	if not built.get("ok", false):
		return {}
	var enemies: CombatEnemies = built.enemies
	var expected: Array = BINDINGS[id]
	_check(enemies.is_valid() and enemies.get_enemies().size() == expected.size(),
		id + ": real enemy roster count")
	for index in range(expected.size()):
		var actor: Dictionary = enemies.get_enemy(index + 1)
		var stats: Array = ENEMY_DATA[expected[index]]
		_check(actor.get("position") == index + 1 and actor.get("id") == expected[index]
			and actor.get("hp") == stats[0] and actor.get("max_hp") == stats[0]
			and actor.get("block") == 0 and actor.get("name") == stats[1]
			and actor.get("art_path") == stats[2],
			id + ": slot " + str(index + 1) + " actual catalog HP/name/art")
	return built


func _trace(id: String, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var selected: Dictionary = _selection(id, rng)
	if not selected.get("success", false):
		return {}
	var built: Dictionary = _build(id, selected)
	if not built.get("ok", false):
		return {}
	var enemies: CombatEnemies = built.enemies
	var party: CombatParty = _party()
	_check(party.is_valid() and enemies.is_valid(), id + ": real hero and enemy objects")
	if not party.is_valid() or not enemies.is_valid():
		return {}
	for pos in range(1, 4):
		var hero: Dictionary = party.get_hero(pos)
		_check(hero.get("id") == ["warden","seamstress","tinker"][pos - 1]
			and hero.get("position") == pos
			and hero.get("hp") == [40,30,26][pos - 1]
			and hero.get("block") == 0 and hero.get("statuses", {}).is_empty(),
			id + ": authentic initial hero at " + str(pos))
	_check(CombatStartingBlock.new(party).apply()
		and party.get_hero(1).get("block") == 6, id + ": Warden gains true opening Block")
	var scheduler := CombatEnemyIntents.new(built.definitions)
	_check(scheduler.is_valid(), id + ": resolved real schedule valid")
	if not scheduler.is_valid():
		return {}
	var phase := CombatEnemyPhase.new()
	var tick_service := CombatStatusTurnBatch.new()
	var phase_rng_state: int = rng.state
	var trace := {"intents": [], "events": [], "heroes": [], "enemies": [],
		"owner_ticks": [], "rng_after_selection": phase_rng_state}
	var expected_states: Array = LOOSE_STATES if id == "loosehem_bleedrelay" else PIN_STATES
	for beat in range(5):
		if beat > 0:
			var tick: Dictionary = tick_service.tick_side("heroes", party.get_heroes())
			_check(tick.get("ok") == true and tick.get("actors", []).size() == 3,
				id + ": valid real owner tick before beat " + str(beat + 1))
			if not tick.get("ok", false):
				return {}
			if id == "loosehem_bleedrelay" and beat == 1:
				_check(tick.events[1].bleed_hp_loss == 1
					and tick.actors[1].hp == 29 and tick.actors[1].block == 4
					and tick.actors[1].statuses.is_empty(),
					"Loosehem: Bleed bypasses 4 real Seamstress Block, then expires")
			if id == "pinrail_weakward" and beat == 1:
				_check(tick.actors[2].statuses.is_empty(),
					"Pinrail: Weak expires at Tinker's owner boundary")
			if id == "pinrail_weakward" and beat == 2:
				_check(tick.actors[0].statuses.is_empty(),
					"Pinrail: Exposed expires at Warden's owner boundary")
			for index in range(3):
				party._heroes[index]["hp"] = tick.actors[index].hp
				party._heroes[index]["block"] = tick.actors[index].block
				party._heroes[index]["statuses"] = tick.actors[index].statuses.duplicate(true)
			_check(party.start_player_turn(), id + ": Block resets at player turn")
			trace.owner_ticks.append(tick.events.duplicate(true))
		var announced: Array[Dictionary] = scheduler.get_intents()
		_check(announced.size() == BINDINGS[id].size(),
			id + ": living roster announces all sources on beat " + str(beat + 1))
		if announced.size() != BINDINGS[id].size():
			return {}
		var result: Dictionary = phase.execute_phase(party, enemies, announced)
		_check(result.get("ok") == true and result.get("events", []).size() == announced.size(),
			id + ": real enemy phase resolves beat " + str(beat + 1))
		if not result.get("ok", false) or result.events.size() != announced.size():
			return {}
		for index in range(announced.size()):
			var expected_event := {"type": announced[index].type,
				"enemy_position": index + 1, "applied": true}
			for field in ["target_position", "status", "direction"]:
				if announced[index].has(field):
					expected_event[field] = announced[index][field]
			_check(result.events[index] == expected_event,
				id + ": ordered and applied complete event source " + str(index + 1)
					+ " beat " + str(beat + 1))
		# Put real Block on a Bleeding hero for an actual owner-boundary probe,
		# without altering the authored enemy action or status.
		if id == "loosehem_bleedrelay" and beat == 0:
			_check(party.gain_block(2, 4), "Loosehem: Seamstress gains real Block before Bleed tick")
		var expected_state: Array = expected_states[beat]
		for pos in range(1, 4):
			var hero: Dictionary = party.get_hero(pos)
			_check(hero.get("id") == ["warden","seamstress","tinker"][pos - 1]
				and hero.get("hp") == expected_state[0][pos - 1]
				and hero.get("block") == expected_state[1][pos - 1]
				and hero.get("statuses", {}) == expected_state[2][pos - 1],
				id + ": exact HP, Block and statuses hero " + str(pos)
					+ " after beat " + str(beat + 1))
		for pos in range(1, BINDINGS[id].size() + 1):
			var enemy: Dictionary = enemies.get_enemy(pos)
			_check(enemy.get("id") == BINDINGS[id][pos - 1]
				and enemy.get("hp") == ENEMY_DATA[enemy.id][0]
				and enemy.get("block") == expected_state[3][pos - 1],
				id + ": exact HP/Block enemy " + str(pos) + " after beat " + str(beat + 1))
		trace.intents.append(announced.duplicate(true))
		trace.events.append(result.events.duplicate(true))
		trace.heroes.append(party.get_heroes())
		trace.enemies.append(enemies.get_enemies())
		_check(scheduler.advance_turn(), id + ": scheduler advanced beat " + str(beat + 1))
	_check(trace.intents.size() == 5 and trace.intents[0] == trace.intents[4],
		id + ": all four beats and modulo-four restart identical")
	_check(rng.state == phase_rng_state, id + ": phase/ticks use no RNG")
	trace["rng_final"] = rng.state
	return trace


func _slain_source(id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 29011
	var selected: Dictionary = _selection(id, rng)
	if not selected.get("success", false):
		return
	var built: Dictionary = _build(id, selected)
	if not built.get("ok", false):
		return
	var enemies: CombatEnemies = built.enemies
	var party: CombatParty = _party()
	if not party.is_valid():
		_check(false, id + ": defeated-source party built")
		return
	var slain_position := 1 if id == "loosehem_bleedrelay" else 2
	var current: Dictionary = enemies.get_enemy(slain_position)
	_check(enemies.apply_damage(slain_position, current.hp)
		and enemies.is_slain(slain_position), id + ": actual enemy killed before its action")
	var announced: Array[Dictionary] = CombatEnemyIntents.new(built.definitions).get_intents()
	var result: Dictionary = CombatEnemyPhase.new().execute_phase(party, enemies, announced)
	_check(result.get("ok") == true and result.get("events", []).size() == announced.size(),
		id + ": phase runs with dead source in its original slot")
	if not result.get("ok", false):
		return
	for index in range(announced.size()):
		_check(result.events[index].enemy_position == index + 1
			and result.events[index].applied == (index + 1 != slain_position),
			id + ": slain source skipped and other sources still act")
	_check(enemies.is_slain(slain_position)
		and (party.get_hero(2).get("statuses", {}).is_empty()
			if id == "loosehem_bleedrelay" else
			party.get_hero(3).get("statuses", {}).is_empty()),
		id + ": slain source adds no Bleed/Weak")
	_check(party.get_hero(3).hp == (24 if id == "loosehem_bleedrelay" else 26)
		and party.get_hero(2).hp == (30 if id == "loosehem_bleedrelay" else 28),
		id + ": remaining sources execute actual damage")


func _negative() -> void:
	var id := "loosehem_bleedrelay"
	var definitions: Array = _definitions(id)
	if definitions.size() != 2:
		_check(false, "negative: valid two-source prerequisite")
		return
	var invalid: Array = definitions.duplicate(true)
	invalid[1].pattern[0].target_position = 4
	_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(invalid)).is_empty(),
		"malformed existing-action target rejected by real JSON parser")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77193
	var selected: Dictionary = _selection(id, rng)
	if not selected.get("success", false):
		return
	var built: Dictionary = _build(id, selected)
	if not built.get("ok", false):
		return
	var party: CombatParty = _party()
	var enemies: CombatEnemies = built.enemies
	if not party.is_valid():
		return
	_check(CombatStartingBlock.new(party).apply(), "negative: genuine opening Block")
	var scheduler := CombatEnemyIntents.new(built.definitions)
	var announced: Array[Dictionary] = scheduler.get_intents()
	_check(announced.size() == 2 and announced[0].type == "debuff"
		and announced[1].type == "attack", "negative: first valid action would apply Bleed")
	if announced.size() != 2:
		return
	var before_heroes: Array[Dictionary] = party.get_heroes()
	var before_enemies: Array[Dictionary] = enemies.get_enemies()
	var before_intents: Array[Dictionary] = scheduler.get_intents()
	var before_rng: int = rng.state
	var bad: Array[Dictionary] = announced.duplicate(true)
	bad[1].amount = -1
	_check(CombatEnemyPhase.new().execute_phase(party, enemies, bad)
		== {"ok": false, "events": []},
		"later invalid amount rejects entire enemy phase after valid earlier source")
	_check(party.get_heroes() == before_heroes and enemies.get_enemies() == before_enemies
		and scheduler.get_intents() == before_intents and rng.state == before_rng,
		"rejection leaves full party/enemy state, scheduler and RNG unchanged")
	_check(not CombatEnemyIntents.new(invalid).is_valid(),
		"malformed action rejected by schedule validator")
