extends SceneTree
## Two authored standalone Elite schedules: exact beats, real rosters/phases,
## hero owner-turn status boundaries, wraparound, seeded replay, and rejection.

const PATHS := {
	"marshal_threadclamp_elite": "res://data/encounters/marshal_threadclamp_elite.json",
	"hexer_patchguard_elite": "res://data/encounters/hexer_patchguard_elite.json",
}
const BINDINGS := {
	"marshal_threadclamp_elite": ["needle_marshal", "spool_stalker"],
	"hexer_patchguard_elite": ["spool_hexer", "button_guard"],
}
const CATALOGS := ["res://data/enemies/m04_elites.json", "res://data/enemies/run_enemies.json"]
const MARSHAL := [
	[{"type":"shove","amount":0,"target_position":1,"direction":1},
	 {"type":"attack","amount":4,"target_position":2},
	 {"type":"buff","amount":3},
	 {"type":"debuff","amount":1,"target_position":3,"status":"weak"}],
	[{"type":"block","amount":2},
	 {"type":"attack","amount":3,"target_position":3},
	 {"type":"attack","amount":2,"target_position":1},
	 {"type":"attack","amount":2,"target_position":2}],
]
const HEXER := [
	[{"type":"debuff","amount":1,"target_position":2,"status":"exposed"},
	 {"type":"attack","amount":3,"target_position":2},
	 {"type":"debuff","amount":1,"target_position":3,"status":"bleed"},
	 {"type":"attack","amount":3,"target_position":3}],
	[{"type":"block","amount":3},
	 {"type":"attack","amount":2,"target_position":1},
	 {"type":"buff","amount":2},
	 {"type":"attack","amount":2,"target_position":3}],
]
## At end of each enemy beat: ordered hero IDs / HP / Block / statuses,
## and enemy Block. Owner-turn tick and player Block reset precede each next beat.
const MARSHAL_STATES := [
	[["seamstress","warden","tinker"], [30,40,26], [0,6,0], [{},{},{}], [0,2]],
	[["seamstress","warden","tinker"], [30,36,23], [0,0,0], [{},{"bleed":1},{}], [0,2]],
	[["seamstress","warden","tinker"], [28,35,23], [0,0,0], [{},{},{}], [3,2]],
	[["seamstress","warden","tinker"], [28,33,23], [0,0,0], [{},{},{"weak":1}], [3,2]],
	[["warden","seamstress","tinker"], [33,28,23], [0,0,0], [{},{},{}], [3,4]],
]
const HEXER_STATES := [
	[["warden","seamstress","tinker"], [40,30,26], [6,0,0], [{},{"exposed":1},{}], [0,3]],
	[["warden","seamstress","tinker"], [38,27,26], [0,0,0], [{},{},{}], [0,3]],
	[["warden","seamstress","tinker"], [38,27,26], [0,0,0], [{},{},{"bleed":1}], [0,5]],
	[["warden","seamstress","tinker"], [38,27,20], [0,0,0], [{},{},{}], [0,5]],
	[["warden","seamstress","tinker"], [38,27,20], [0,0,0], [{},{"exposed":1},{}], [0,8]],
]
const META := {
	"needle_marshal": ["Needle Marshal", 28, "res://assets/paper/enemies/needle_marshal.png"],
	"spool_stalker": ["Spool Stalker", 14, "res://assets/paper/enemies/spool_stalker.png"],
	"spool_hexer": ["Spool Hexer", 24, "res://assets/paper/enemies/spool_hexer.png"],
	"button_guard": ["Button Guard", 16, "res://assets/paper/enemies/button_guard.png"],
}

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_content()
	for encounter_id in PATHS:
		var first: Dictionary = _trace(encounter_id)
		var replay: Dictionary = _trace(encounter_id)
		_check(not first.is_empty() and first == replay,
			encounter_id + ": fresh independent same-seed full traces match")
	_negative()
	_report()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _definitions(encounter_id: String) -> Array:
	var authored := FileAccess.get_file_as_string(PATHS[encounter_id])
	_check(not authored.is_empty(), encounter_id + ": authored JSON exists")
	return RunFightEncounterSelection._parse_schedule_text(authored)


func _pattern(encounter_id: String) -> Array:
	return MARSHAL if encounter_id == "marshal_threadclamp_elite" else HEXER


func _content() -> void:
	for encounter_id in PATHS:
		var definitions := _definitions(encounter_id)
		_check(definitions.size() == 2, encounter_id + ": two parsed sources")
		if definitions.size() != 2:
			continue
		for index in range(2):
			var source: Dictionary = definitions[index]
			_check(source.size() == 2 and source.enemy_position == index + 1
				and source.pattern is Array and source.pattern.size() == 4
				and source.pattern == _pattern(encounter_id)[index],
				encounter_id + ": ordered source " + str(index + 1) + " exact four actions")
		var intents := CombatEnemyIntents.new(definitions)
		_check(intents.is_valid(), encounter_id + ": valid scheduler")
		if not intents.is_valid():
			continue
		for beat in range(5):
			var actual := intents.get_intents()
			_check(actual.size() == 2, encounter_id + ": two announced intents")
			if actual.size() != 2:
				break
			for source in range(2):
				var expected: Dictionary = _pattern(encounter_id)[source][beat % 4].duplicate(true)
				expected["enemy_position"] = source + 1
				_check(actual[source] == expected,
					encounter_id + ": source " + str(source + 1)
					+ " announced exact beat " + str(beat + 1))
			_check(intents.advance_turn(), encounter_id + ": scheduler advances")


func _party() -> CombatParty:
	var catalog := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))
	_check(not catalog.is_empty(), "authored hero catalog parses")
	var ordered: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		var matches := catalog.filter(func(entry): return entry.get("id") == id)
		_check(matches.size() == 1, "exactly one authored hero " + id)
		if matches.size() == 1:
			ordered.append(matches[0])
	return CombatParty.new(ordered)


func _build(encounter_id: String, definitions: Array) -> Dictionary:
	return RunTypedBattleRoster.new().assemble(
		{"success":true, "node_type":"Elite",
		 "encounter_id":encounter_id, "definitions":definitions},
		BINDINGS, CATALOGS)


func _trace(encounter_id: String) -> Dictionary:
	var definitions := _definitions(encounter_id)
	if definitions.size() != 2:
		return {}
	var built := _build(encounter_id, definitions)
	_check(built.get("ok") == true and built.get("node_type") == "Elite"
		and built.get("encounter_id") == encounter_id,
		encounter_id + ": typed Elite roster assembled")
	if not built.get("ok", false):
		return {}
	var enemies: CombatEnemies = built.enemies
	var party := _party()
	_check(party.is_valid() and enemies.is_valid(), encounter_id + ": real combat rosters")
	if not party.is_valid() or not enemies.is_valid():
		return {}
	for pos in [1,2]:
		var enemy := enemies.get_enemy(pos)
		var expected_id: String = BINDINGS[encounter_id][pos - 1]
		var expected: Array = META[expected_id]
		_check(enemy.get("position") == pos and enemy.get("id") == expected_id
			and enemy.get("name") == expected[0] and enemy.get("max_hp") == expected[1]
			and enemy.get("hp") == expected[1] and enemy.get("block") == 0
			and enemy.get("art_path") == expected[2],
			encounter_id + ": authentic enemy slot " + str(pos) + " ID/name/HP/art")
	for pos in [1,2,3]:
		var hero := party.get_hero(pos)
		_check(hero.get("position") == pos
			and hero.get("id") == ["warden","seamstress","tinker"][pos - 1]
			and hero.get("max_hp") == [40,30,26][pos - 1]
			and hero.get("hp") == hero.get("max_hp") and hero.get("block") == 0
			and hero.get("statuses", {}).is_empty(),
			encounter_id + ": clean real hero at slot " + str(pos))
	_check(CombatStartingBlock.new(party).apply()
		and party.get_hero(1).get("block") == 6,
		encounter_id + ": Warden receives real one-time opening Block")
	var scheduler := CombatEnemyIntents.new(built.definitions)
	_check(scheduler.is_valid(), encounter_id + ": typed schedule is valid")
	if not scheduler.is_valid():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1200600
	var before_rng: int = rng.state
	var trace := {"announcements":[], "events":[], "heroes":[], "enemies":[], "ticks":[]}
	var expected_states: Array = MARSHAL_STATES if encounter_id == "marshal_threadclamp_elite" else HEXER_STATES
	for beat in range(5):
		if beat > 0:
			# Match round-flow: detached hero owner tick, publish, then reset Block.
			var tick := CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())
			_check(tick.get("ok") == true and tick.get("events", []).size() == 3,
				encounter_id + ": real owner-turn status tick " + str(beat))
			if not tick.get("ok", false):
				return {}
			trace.ticks.append(tick.events.duplicate(true))
			if encounter_id == "hexer_patchguard_elite":
				if beat == 1:
					_check(tick.actors[1].statuses.is_empty(),
						"Hexer: Exposed expires on Seamstress owner boundary")
				if beat == 3:
					_check(tick.events[2].bleed_hp_loss == 1
						and tick.actors[2].hp == 25 and tick.actors[2].statuses.is_empty(),
						"Hexer: Bleed 1 directly takes Tinker HP then expires")
			elif beat == 2:
				_check(tick.events[1].bleed_hp_loss == 1
					and tick.actors[1].hp == 35 and tick.actors[1].statuses.is_empty(),
					"Marshal: the sting's Bleed 1 takes 1 HP at the owner boundary then expires")
			elif beat == 4:
				_check(tick.actors[2].statuses.is_empty(),
					"Marshal: Weak expires at Tinker's next owner boundary")
			for index in range(3):
				party._heroes[index]["hp"] = tick.actors[index].hp
				party._heroes[index]["block"] = tick.actors[index].block
				party._heroes[index]["statuses"] = tick.actors[index].statuses.duplicate(true)
			_check(party.start_player_turn(), encounter_id + ": player Block reset " + str(beat))
		var announced := scheduler.get_intents()
		_check(announced.size() == 2, encounter_id + ": actual two-source phase")
		if announced.size() != 2:
			return {}
		var phase := CombatEnemyPhase.new().execute_phase(party, enemies, announced)
		_check(phase.get("ok") == true and phase.get("events", []).size() == 2,
			encounter_id + ": resolved enemy phase " + str(beat + 1))
		if not phase.get("ok", false) or phase.events.size() != 2:
			return {}
		for index in range(2):
			var action: Dictionary = announced[index]
			var event: Dictionary = phase.events[index]
			_check(event.get("type") == action.type
				and event.get("enemy_position") == index + 1 and event.get("applied") == true,
				encounter_id + ": applied action in source order beat " + str(beat + 1))
			for field in ["target_position", "direction", "status"]:
				if action.has(field):
					_check(event.get(field) == action[field],
						encounter_id + ": applied event " + field + " beat " + str(beat + 1))
		var state: Array = expected_states[beat]
		for pos in [1,2,3]:
			var hero := party.get_hero(pos)
			_check(hero.get("position") == pos and hero.get("id") == state[0][pos - 1]
				and hero.get("hp") == state[1][pos - 1]
				and hero.get("block") == state[2][pos - 1]
				and hero.get("statuses", {}) == state[3][pos - 1],
				encounter_id + ": exact hero identity/HP/Block/status slot "
				+ str(pos) + " beat " + str(beat + 1))
		for pos in [1,2]:
			var enemy := enemies.get_enemy(pos)
			_check(enemy.get("id") == BINDINGS[encounter_id][pos - 1]
				and enemy.get("hp") == META[enemy.id][1]
				and enemy.get("block") == state[4][pos - 1],
				encounter_id + ": exact enemy HP/Block source "
				+ str(pos) + " beat " + str(beat + 1))
		trace.announcements.append(announced.duplicate(true))
		trace.events.append(phase.events.duplicate(true))
		trace.heroes.append(party.get_heroes())
		trace.enemies.append(enemies.get_enemies())
		_check(scheduler.advance_turn(), encounter_id + ": advance beat " + str(beat + 1))
	_check(trace.announcements.size() == 5
		and trace.announcements[0] == trace.announcements[4],
		encounter_id + ": beat five wraps to beat one for both sources")
	_check(rng.state == before_rng, encounter_id + ": actual phase uses no RNG")
	trace["rng_state"] = rng.state
	return trace


func _negative() -> void:
	var marshal := _definitions("marshal_threadclamp_elite")
	var built := _build("marshal_threadclamp_elite", marshal)
	var party := _party()
	if not built.get("ok", false) or not party.is_valid():
		_check(false, "illegal shove fixture must assemble")
		return
	var enemies: CombatEnemies = built.enemies
	_check(CombatStartingBlock.new(party).apply(), "illegal shove fixture grants Block")
	_check(party.apply_damage(2, 30) and party.is_downed(2)
		and not party.is_downed(1),
		"illegal shove: living Warden cannot swap with downed Seamstress")
	var scheduler := CombatEnemyIntents.new(marshal)
	var announced := scheduler.get_intents()
	var before_heroes := party.get_heroes()
	var before_enemies := enemies.get_enemies()
	var before_intents := scheduler.get_intents()
	var seeded := RandomNumberGenerator.new()
	seeded.seed = 6120
	var rng_before: int = seeded.state
	_check(CombatEnemyPhase.new().execute_phase(party, enemies, announced)
		== {"ok":false, "events":[]},
		"illegal shove returns empty rejected phase, not a silent successful swap")
	_check(party.get_heroes() == before_heroes and enemies.get_enemies() == before_enemies
		and scheduler.get_intents() == before_intents and seeded.state == rng_before,
		"failed shove preserves entire party/enemy/scheduler/RNG state")

	# A valid first shove would move the two living front heroes, but a
	# later valid-shape shove into a DOWNED Tinker must fail atomically.
	var later_party := _party()
	var later_built := _build("marshal_threadclamp_elite", marshal)
	_check(later_party.is_valid() and later_built.get("ok") == true,
		"late shove rollback fixture loads authentic rosters")
	if not later_party.is_valid() or not later_built.get("ok", false):
		return
	var later_enemies: CombatEnemies = later_built.enemies
	_check(CombatStartingBlock.new(later_party).apply()
		and later_party.apply_damage(3, 26) and later_party.is_downed(3)
		and not later_party.is_downed(1) and not later_party.is_downed(2),
		"later shove has two living front heroes and a downed destination")
	var later_scheduler := CombatEnemyIntents.new(marshal)
	var actions := later_scheduler.get_intents()
	_check(actions.size() == 2 and actions[0].type == "shove"
		and actions[0].target_position == 1,
		"earlier source announces authentic, independently legal shove")
	if actions.size() != 2:
		return
	actions[1] = {"enemy_position":2, "type":"shove", "amount":0,
		"target_position":2, "direction":1}
	var later_action: Dictionary = actions[1].duplicate(true)
	later_action.erase("enemy_position")
	_check(CombatEnemyIntents.valid_action(later_action),
		"later source has valid shape; only downed destination makes it illegal")
	var prior_heroes := later_party.get_heroes()
	var prior_enemies := later_enemies.get_enemies()
	var prior_actions := later_scheduler.get_intents()
	var later_rng := RandomNumberGenerator.new()
	later_rng.seed = 6121
	var prior_rng: int = later_rng.state
	_check(CombatEnemyPhase.new().execute_phase(later_party, later_enemies, actions)
		== {"ok":false, "events":[]},
		"illegal later shove rejects whole batch after legal staged displacement")
	_check(later_party.get_heroes() == prior_heroes
		and later_enemies.get_enemies() == prior_enemies
		and later_scheduler.get_intents() == prior_actions
		and later_rng.state == prior_rng,
		"late shove rejection rolls back earlier swap, Block, enemy, intents and RNG")


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("m04_elite_threadclamp_pair_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
