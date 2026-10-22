extends SceneTree
## M04 Hexer status pairs: parsed authored beats, real seeded Elite admission,
## typed catalog opponents, applied phase events and owner-turn replay.

const PATHS := {
	"hexer_exposed_backline": "res://data/encounters/hexer_exposed_backline.json",
	"hexer_bleed_midguard": "res://data/encounters/hexer_bleed_midguard.json",
}
const BINDINGS := {
	"hexer_exposed_backline": ["spool_hexer", "spool_stalker"],
	"hexer_bleed_midguard": ["spool_hexer", "fray_scavenger"],
}
const CATALOGS := ["res://data/enemies/m04_elites.json", "res://data/enemies/run_enemies.json"]
const EXPOSED := [
	[{"type":"debuff","amount":1,"target_position":3,"status":"exposed"},
	 {"type":"attack","amount":4,"target_position":2},
	 {"type":"debuff","amount":1,"target_position":1,"status":"weak"},
	 {"type":"buff","amount":2}],
	[{"type":"attack","amount":3,"target_position":3},
	 {"type":"block","amount":2},
	 {"type":"attack","amount":2,"target_position":1},
	 {"type":"attack","amount":3,"target_position":2}],
]
const BLEED := [
	[{"type":"debuff","amount":2,"target_position":2,"status":"bleed"},
	 {"type":"buff","amount":3},
	 {"type":"debuff","amount":1,"target_position":1,"status":"exposed"},
	 {"type":"attack","amount":3,"target_position":2}],
	[{"type":"attack","amount":2,"target_position":2},
	 {"type":"attack","amount":3,"target_position":1},
	 {"type":"attack","amount":3,"target_position":1},
	 {"type":"block","amount":2}],
]
## Each beat: named hero HP, hero Block, exact statuses and enemy Block.
## Ticks run between beats; the first beat still has Warden's opening Block.
const EXPOSED_STATES := [
	[[40,30,22],[6,0,0],[{},{},{"exposed":1}],[0,0]],
	[[40,26,22],[0,0,0],[{},{},{}],[0,2]],
	[[38,26,22],[0,0,0],[{"weak":1},{},{}],[0,2]],
	[[38,23,22],[0,0,0],[{},{},{}],[2,2]],
	[[38,23,18],[0,0,0],[{},{},{"exposed":1}],[2,2]],
]
const BLEED_STATES := [
	[[40,28,26],[6,0,0],[{},{"bleed":2},{}],[0,0]],
	[[37,26,26],[0,0,0],[{},{"bleed":1},{}],[3,0]],
	[[33,25,26],[0,0,0],[{"exposed":1},{},{}],[3,0]],
	[[33,22,26],[0,0,0],[{},{},{}],[3,2]],
	[[33,20,26],[0,0,0],[{},{"bleed":2},{}],[3,2]],
]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_content()
	_negative()
	for id in PATHS:
		var first := _trace(id)
		var second := _trace(id)
		_check(not first.is_empty() and first == second,
			id + ": same-seed complete five-beat selection and combat replay")
	_report()


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)


func _schedule(id: String) -> Array:
	var text := FileAccess.get_file_as_string(PATHS[id])
	_check(not text.is_empty(), id + ": real encounter file exists")
	return RunFightEncounterSelection._parse_schedule_text(text)


func _content() -> void:
	for id in PATHS:
		var parsed := _schedule(id)
		_check(parsed.size() == 2, id + ": validated two-source array")
		if parsed.size() != 2:
			continue
		var patterns: Array = EXPOSED if id == "hexer_exposed_backline" else BLEED
		var sources := {}
		for source in parsed:
			var pos: int = source.get("enemy_position", -1)
			_check(pos in [1, 2] and not sources.has(pos) and source.size() == 2,
				id + ": distinct authoritative source position " + str(pos))
			sources[pos] = source.get("pattern", [])
		for pos in [1, 2]:
			_check(sources.has(pos) and sources[pos].size() == 4
				and sources[pos] == patterns[pos - 1],
				id + ": all four exact actions source " + str(pos))
		var intents := CombatEnemyIntents.new(parsed)
		_check(intents.is_valid(), id + ": real intent scheduler valid")
		if not intents.is_valid():
			continue
		for beat in range(5):
			var announced := intents.get_intents()
			_check(announced.size() == 2, id + ": two announcements beat " + str(beat))
			if announced.size() != 2:
				break
			for source in [1, 2]:
				var expected: Dictionary = patterns[source - 1][beat % 4].duplicate(true)
				expected["enemy_position"] = source
				_check(announced[source - 1] == expected,
					id + ": exact announced source " + str(source) + " beat " + str(beat))
			_check(intents.advance_turn(), id + ": advance intent beat " + str(beat))
	for existing in ["spool_hexer_elite", "hexer_backthread_guard", "hexer_reel_pincer"]:
		var text := FileAccess.get_file_as_string("res://data/encounters/" + existing + ".json")
		var parsed := RunFightEncounterSelection._parse_schedule_text(text)
		_check(not text.is_empty() and parsed.size() == 2
			and CombatEnemyIntents.new(parsed).is_valid(),
			existing + ": unchanged pre-existing Elite still parses")


func _route(seed_value: int, kind: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := RunMap.new()
	if not map.generate(rng):
		return {}
	for node_id in map.get_legal_choices():
		if map.get_node(node_id).get("type") == kind and map.choose_node(node_id):
			return {"map":map, "rng":rng, "node":node_id}
	return {}


func _seed_for(kind: String) -> int:
	for number in range(1, 129):
		if not _route(number, kind).is_empty():
			return number
	return -1


func _party() -> CombatParty:
	var records := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))
	var ordered: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		var matches := records.filter(func(entry): return entry.get("id") == id)
		_check(matches.size() == 1, "authored starter hero " + id)
		if matches.size() == 1:
			ordered.append(matches[0])
	return CombatParty.new(ordered)


func _trace(id: String) -> Dictionary:
	var seed_value := _seed_for("Elite")
	_check(seed_value > 0, id + ": seeded reachable Elite exists")
	if seed_value < 0:
		return {}
	var route := _route(seed_value, "Elite")
	if route.is_empty():
		return {}
	var map: RunMap = route.map
	var rng: RandomNumberGenerator = route.rng
	_check(map.get_node(route.node).get("type") == "Elite"
		and map.get_current_node_id() == route.node
		and map.get_route().size() == 1,
		id + ": generated, legally chosen Elite on real map")
	var selector := RunFightEncounterSelection.new()
	var choice := selector.select_current_battle(map, rng, {"Elite": {id: PATHS[id]}})
	var parsed := _schedule(id)
	_check(choice.get("success") == true and choice.get("node_type") == "Elite"
		and choice.get("encounter_id") == id and choice.get("definitions") == parsed,
		id + ": real Elite selector reads exact authored JSON")
	if not choice.get("success", false):
		return {}
	var after_select: int = rng.state
	_check(selector.select_current_battle(map, rng, {"Elite": {}}) == choice
		and rng.state == after_select, id + ": cached choice never rerolls")
	var built := RunTypedBattleRoster.new().assemble(choice, BINDINGS, CATALOGS)
	_check(built.get("ok") == true and built.get("encounter_id") == id
		and built.get("node_type") == "Elite" and built.get("definitions") == parsed,
		id + ": typed roster assembles selected source schedule")
	if not built.get("ok", false):
		return {}
	var enemies: CombatEnemies = built.enemies
	var party := _party()
	_check(party.is_valid() and enemies.is_valid(), id + ": real valid combat actors")
	if not party.is_valid() or not enemies.is_valid():
		return {}
	var names := ["Spool Hexer", "Spool Stalker" if id == "hexer_exposed_backline" else "Fray Scavenger"]
	for pos in [1, 2]:
		var enemy := enemies.get_enemy(pos)
		var hp := 24 if pos == 1 else 14
		var enemy_id: String = BINDINGS[id][pos - 1]
		_check(enemy.get("id") == enemy_id and enemy.get("name") == names[pos - 1]
			and enemy.get("position") == pos and enemy.get("hp") == hp
			and enemy.get("max_hp") == hp and enemy.get("block") == 0
			and enemy.get("art_path") == "res://assets/paper/enemies/" + enemy_id + ".png",
			id + ": authentic catalog enemy ID/name/HP/art and position " + str(pos))
	for pos in [1, 2, 3]:
		var hero := party.get_hero(pos)
		_check(hero.get("id") == ["warden","seamstress","tinker"][pos - 1]
			and hero.get("hp") == [40,30,26][pos - 1] and hero.get("block") == 0
			and hero.get("statuses", {}).is_empty(), id + ": clean real hero " + str(pos))
	var start := CombatStartingBlock.new(party)
	_check(start.apply() and party.get_hero(1).get("block") == 6
		and not start.apply(), id + ": authentic one-shot starting Warden Block")
	var intents := CombatEnemyIntents.new(built.definitions)
	_check(intents.is_valid(), id + ": selected typed intents valid")
	if not intents.is_valid():
		return {}
	var expected: Array = EXPOSED_STATES if id == "hexer_exposed_backline" else BLEED_STATES
	var history := {"selection": choice.duplicate(true), "route": map.get_route(),
		"floors":map.get_floors(), "announced":[], "events":[],
		"heroes":[], "enemies":[], "owner_ticks":[], "rng":after_select}
	for beat in range(5):
		if beat > 0:
			if id == "hexer_bleed_midguard" and beat in [1, 2]:
				_check(party.gain_block(2, 5) and party.get_hero(2).get("block") == 5,
					"Seamstress gains real Block before each Bleed owner-turn tick")
			var tick := CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())
			_check(tick.get("ok") == true and tick.get("events", []).size() == 3,
				id + ": real owner-side tick before beat " + str(beat + 1))
			if not tick.get("ok", false):
				return {}
			history.owner_ticks.append(tick.duplicate(true))
			if id == "hexer_bleed_midguard" and beat in [1, 2]:
				var loss: int = 2 if beat == 1 else 1
				_check(tick.events[1].id == "seamstress"
					and tick.events[1].bleed_hp_loss == loss
					and tick.actors[1].hp == (26 if beat == 1 else 25)
					and tick.actors[1].block == 5
					and tick.actors[1].statuses == ({"bleed":1} if beat == 1 else {}),
					"bleed owner turn " + str(beat) + ": HP bypasses Block and status ages")
			if id == "hexer_exposed_backline" and beat == 1:
				_check(tick.actors[2].statuses.is_empty() and tick.events[2].bleed_hp_loss == 0,
					"backline Exposed ages after same-phase empowered hit")
			if id == "hexer_exposed_backline" and beat == 3:
				_check(tick.actors[0].statuses.is_empty(), "Warden Weak expires at owner boundary")
			if id == "hexer_bleed_midguard" and beat == 3:
				_check(tick.actors[0].statuses.is_empty(), "Warden Exposed expires at owner boundary")
			# tick_side returns a detached proposal; publish it as round flow does.
			for index in range(3):
				party._heroes[index]["hp"] = tick.actors[index].hp
				party._heroes[index]["block"] = tick.actors[index].block
				party._heroes[index]["statuses"] = tick.actors[index].statuses.duplicate(true)
			_check(party.start_player_turn() and party.get_hero(1).get("block") == 0,
				id + ": reset opening Block at next player turn")
		var announced := intents.get_intents()
		_check(announced.size() == 2, id + ": live phase has both sources")
		if announced.size() != 2:
			return {}
		var phase := CombatEnemyPhase.new().execute_phase(party, enemies, announced)
		_check(phase.get("ok") == true and phase.get("events", []).size() == 2,
			id + ": real enemy phase applied beat " + str(beat + 1))
		if not phase.get("ok", false) or phase.events.size() != 2:
			return {}
		for source in range(2):
			var actual_event: Dictionary = phase.events[source]
			var expected_event: Dictionary = announced[source].duplicate(true)
			expected_event.erase("amount")
			expected_event["applied"] = true
			_check(actual_event == expected_event, id + ": complete ordered applied event "
				+ str(source + 1) + " beat " + str(beat + 1))
		for pos in [1, 2, 3]:
			var hero := party.get_hero(pos)
			_check(hero.get("id") == ["warden","seamstress","tinker"][pos - 1]
				and hero.get("position") == pos and hero.get("hp") == expected[beat][0][pos - 1]
				and hero.get("block") == expected[beat][1][pos - 1]
				and hero.get("statuses", {}) == expected[beat][2][pos - 1],
				id + ": actual hero ID/HP/Block/status " + str(pos) + " beat " + str(beat + 1))
		for pos in [1, 2]:
			var enemy := enemies.get_enemy(pos)
			_check(enemy.get("id") == BINDINGS[id][pos - 1]
				and enemy.get("hp") == enemy.get("max_hp")
				and enemy.get("block") == expected[beat][3][pos - 1],
				id + ": actual source HP and independent Block " + str(pos)
				+ " beat " + str(beat + 1))
		history.announced.append(announced.duplicate(true))
		history.events.append(phase.events.duplicate(true))
		history.heroes.append(party.get_heroes())
		history.enemies.append(enemies.get_enemies())
		_check(intents.advance_turn(), id + ": advance successful phase")
	_check(history.announced[0] == history.announced[4],
		id + ": wrapped fifth beat matches first announcement")
	_check(rng.state == after_select, id + ": combat and ticks spend no RNG")
	return history


func _negative() -> void:
	var original := _schedule("hexer_bleed_midguard")
	if original.size() != 2:
		return
	var fractional := original.duplicate(true)
	fractional[0].pattern[0].amount = 1.5
	_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(fractional)).is_empty(),
		"fractional authored Bleed rejected rather than truncated")
	var malformed := original.duplicate(true)
	malformed[0].pattern[0].status = "bleeding"
	_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(malformed)).is_empty(),
		"unknown status rejected by real parser")
	var bad_position := original.duplicate(true)
	bad_position[1].enemy_position = 1.5
	_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(bad_position)).is_empty(),
		"fractional source position rejected")
	var fight_seed := _seed_for("Fight")
	_check(fight_seed > 0, "genuine seeded non-Elite node exists")
	if fight_seed > 0:
		var wrong_route := _route(fight_seed, "Fight")
		var wrong_map: RunMap = wrong_route.map
		var wrong_rng: RandomNumberGenerator = wrong_route.rng
		var wrong_selector := RunFightEncounterSelection.new()
		var before_route := wrong_map.get_route()
		var before_rng: int = wrong_rng.state
		_check(wrong_selector.select_current_battle(wrong_map, wrong_rng,
			{"Elite": {"hexer_bleed_midguard":PATHS["hexer_bleed_midguard"]}})
			== {"success":false}, "wrong node kind never accepts Elite-only pool")
		_check(wrong_map.get_route() == before_route and wrong_rng.state == before_rng
			and wrong_selector._selected.is_empty() and wrong_selector._bound_map == null,
			"wrong node kind leaves map, cache and RNG unchanged")
	var seed_value := _seed_for("Elite")
	if seed_value < 0:
		return
	var route := _route(seed_value, "Elite")
	var map: RunMap = route.map
	var rng: RandomNumberGenerator = route.rng
	var selector := RunFightEncounterSelection.new()
	var choice := selector.select_current_battle(map, rng, {"Elite": {
		"hexer_bleed_midguard":PATHS["hexer_bleed_midguard"]}})
	_check(choice.get("success") == true, "negative fixture is genuine selected Elite")
	if not choice.get("success", false):
		return
	var party := _party()
	var valid := RunTypedBattleRoster.new().assemble(choice, BINDINGS, CATALOGS)
	_check(party.is_valid() and valid.get("ok") == true,
		"negative fixture uses valid authored actors")
	if not party.is_valid() or not valid.get("ok", false):
		return
	var enemies: CombatEnemies = valid.enemies
	var route_before := map.get_route()
	var rng_before: int = rng.state
	var choice_before := choice.duplicate(true)
	var party_before := party.get_heroes()
	var enemy_before := enemies.get_enemies()
	var no_binding := BINDINGS.duplicate(true)
	no_binding.erase("hexer_bleed_midguard")
	var wrong_source := BINDINGS.duplicate(true)
	wrong_source["hexer_bleed_midguard"] = ["spool_hexer", "unknown_source"]
	var short_source := BINDINGS.duplicate(true)
	short_source["hexer_bleed_midguard"] = ["spool_hexer"]
	for rejected in [no_binding, wrong_source, short_source]:
		_check(RunTypedBattleRoster.new().assemble(choice, rejected, CATALOGS)
			== {"ok":false}, "missing/wrong/mismatched source binding rejected")
		_check(map.get_route() == route_before and rng.state == rng_before
			and choice == choice_before and party.get_heroes() == party_before
			and enemies.get_enemies() == enemy_before,
			"rejected binding changes no choice, state, map or RNG")
	var scheduler := CombatEnemyIntents.new(choice.definitions)
	var announced := scheduler.get_intents()
	_check(announced.size() == 2 and announced[0].type == "debuff",
		"atomic rejection fixture first source would apply Bleed")
	if announced.size() != 2:
		return
	var invalid_phase := announced.duplicate(true)
	invalid_phase[1].target_position = 4
	_check(CombatEnemyPhase.new().execute_phase(party, enemies, invalid_phase)
		== {"ok":false, "events":[]},
		"invalid later source rejects earlier staged Bleed atomically")
	_check(party.get_heroes() == party_before and enemies.get_enemies() == enemy_before
		and scheduler.get_intents() == announced and map.get_route() == route_before
		and rng.state == rng_before, "rejected phase leaves all state, scheduler and RNG intact")


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("m04_hexer_status_pairs_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
