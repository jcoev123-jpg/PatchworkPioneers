extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_detached_and_missing_selection()
	_test_fight_and_elite_wins()
	_test_boss_replay()
	_test_all_kind_defeats()
	_test_rejections_and_stale_binding()
	if failures.is_empty():
		print("run_act_battle_outcome_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_act_battle_outcome_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _context(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := RunMap.new()
	_check(map.generate(rng), "seeded real map generated (%d)" % seed_value)
	_check(map.is_generated() and map.get_floors().size() == 12
		and map.get_route().is_empty(), "generated map starts with 12 floors and no route")
	return {"rng": rng, "map": map, "service": RunActBattleOutcome.new(map)}


func _party() -> CombatParty:
	var text := FileAccess.get_file_as_string("res://data/heroes/starter_party.json")
	var decoded: Variant = JSON.parse_string(text)
	_check(decoded is Array and decoded.size() == 3, "authored starter party JSON loads")
	if not decoded is Array:
		return CombatParty.new([])
	# Godot JSON numbers may arrive as floats, while CombatParty requires
	# strict int max_hp. Validate integral authored values before coercion.
	var definitions: Array = []
	for item in decoded:
		if not item is Dictionary:
			_check(false, "each authored hero is a dictionary")
			continue
		var hero: Dictionary = item.duplicate(true)
		var hp: Variant = hero.get("max_hp")
		_check((hp is int and hp > 0)
			or (hp is float and hp > 0 and is_finite(hp) and floorf(hp) == hp),
			"authored maximum HP is a positive integer value")
		if hp is float and is_finite(hp) and floorf(hp) == hp:
			hero["max_hp"] = int(hp)
		definitions.append(hero)
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"real CombatParty accepts authored three heroes")
	for position in range(1, 4):
		var hero := party.get_hero(position)
		var expected_ids := ["warden", "seamstress", "tinker"]
		var expected_hp := [40, 30, 26]
		_check(hero.get("id") == expected_ids[position - 1]
			and hero.get("max_hp") == expected_hp[position - 1]
			and hero.get("hp") == expected_hp[position - 1]
			and hero.get("position") == position,
			"authored hero identity, maximum and living HP at slot %d" % position)
	return party


func _fight(healths: Array) -> Dictionary:
	var party := _party()
	var defs: Array = []
	for index in range(healths.size()):
		defs.append({"id": "test_slot_%d" % (index + 1), "max_hp": healths[index]})
	var enemies := CombatEnemies.new(defs)
	_check(enemies.is_valid() and enemies.get_enemies().size() == healths.size()
		and not enemies.is_victorious(), "real positioned living CombatEnemies fixture")
	for index in range(healths.size()):
		_check(enemies.get_enemy(index + 1).get("hp") == healths[index]
			and enemies.get_enemy(index + 1).get("position") == index + 1,
			"enemy fixture slot and actual HP %d" % (index + 1))
	var result := CombatBattleResult.new(party, enemies)
	_check(result.get_outcome() == CombatBattleResult.ACTIVE,
		"fresh authoritative combat result is ACTIVE")
	return {"party": party, "enemies": enemies, "result": result}


func _snapshot(ctx: Dictionary, battle: Dictionary = {}) -> Dictionary:
	var map: RunMap = ctx["map"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var state := {
		"service": ctx["service"].get_state(),
		"graph": map.get_floors(), "route": map.get_route(),
		"choices": map.get_legal_choices(),
		"node": map.get_current_node_id(),
		"floor": map.get_current_floor(),
		"complete": map.is_complete(),
		"rng": rng.state,
	}
	if not battle.is_empty():
		var party: CombatParty = battle["party"]
		var enemies: CombatEnemies = battle["enemies"]
		var result: CombatBattleResult = battle["result"]
		state["heroes"] = party.get_heroes()
		state["enemies"] = enemies.get_enemies()
		state["battle_outcome"] = result.get_outcome()
	return state


func _world(ctx: Dictionary, battle: Dictionary) -> Dictionary:
	var snapshot := _snapshot(ctx, battle)
	snapshot.erase("service")
	return snapshot


func _reject_begin(ctx: Dictionary, result: CombatBattleResult, battle: Dictionary, label: String) -> void:
	var before := _snapshot(ctx, battle)
	_check(not ctx["service"].begin_current_battle(result), label + " refuses begin")
	_check(_snapshot(ctx, battle) == before, label + " leaves complete snapshots/RNG unchanged")


func _reject_settle(ctx: Dictionary, battle: Dictionary, label: String) -> void:
	var before := _snapshot(ctx, battle)
	_check(not ctx["service"].settle_current_battle(), label + " refuses settle")
	_check(_snapshot(ctx, battle) == before, label + " leaves complete snapshots/RNG unchanged")


func _choose(ctx: Dictionary, node_id: String) -> void:
	var map: RunMap = ctx["map"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var legal := map.get_legal_choices()
	var before_rng := rng.state
	_check(legal.has(node_id), "requested node %s is actually a connected legal choice" % node_id)
	_check(map.choose_node(node_id), "map advances legally to %s" % node_id)
	_check(map.get_current_node_id() == node_id and rng.state == before_rng,
		"chosen node is current and map routing draws zero RNG")


func _opening_fight(ctx: Dictionary) -> String:
	var map: RunMap = ctx["map"]
	for id in map.get_legal_choices():
		if map.get_node(id).get("type") == "Fight":
			_choose(ctx, id)
			return id
	_check(false, "seeded map has a genuinely legal opening Fight")
	return ""


## Find a path from the first floor via actual authored graph edges.
## This is a test oracle, not a service method that chooses map nodes.
func _path_to(map: RunMap, kind: String, opening_kind: String = "") -> Array[String]:
	var floors := map.get_floors()
	var paths: Dictionary = {}
	for node in floors[0]:
		if opening_kind.is_empty() or node.get("type") == opening_kind:
			var first: Array[String] = [node["id"]]
			paths[node["id"]] = first
	for floor_index in range(floors.size()):
		for node in floors[floor_index]:
			if not paths.has(node["id"]):
				continue
			if node.get("type") == kind:
				return paths[node["id"]].duplicate()
			for target_id in node["outgoing"]:
				if not paths.has(target_id):
					var next_path: Array[String] = paths[node["id"]].duplicate()
					next_path.append(target_id)
					paths[target_id] = next_path
	return []


func _choose_path(ctx: Dictionary, path: Array[String]) -> void:
	_check(not path.is_empty(), "nonempty connected target path exists")
	for node_id in path:
		_choose(ctx, node_id)


func _context_for_kind(kind: String, start_seed: int = 1) -> Dictionary:
	for candidate_seed in range(start_seed, start_seed + 128):
		var ctx := _context(candidate_seed)
		if not _path_to(ctx["map"], kind).is_empty():
			return ctx
	_check(false, "no deterministic route to kind " + kind)
	return _context(start_seed)


func _observe_victory(battle: Dictionary, label: String) -> void:
	var enemies: CombatEnemies = battle["enemies"]
	var party: CombatParty = battle["party"]
	var result: CombatBattleResult = battle["result"]
	_check(result.get_outcome() == CombatBattleResult.ACTIVE
		and not party.is_defeated() and not enemies.is_victorious(),
		label + " begins with both sides alive and ACTIVE")
	for position in range(1, enemies.get_enemies().size() + 1):
		var hp: int = enemies.get_enemy(position)["hp"]
		_check(enemies.apply_damage(position, hp) and enemies.is_dead(position),
			label + " actually deals lethal enemy damage at slot %d" % position)
	_check(enemies.is_victorious() and not party.is_defeated(),
		label + " last enemy dead and heroes alive")
	_check(result.evaluate() == CombatBattleResult.VICTORY
		and result.get_outcome() == CombatBattleResult.VICTORY,
		label + " authoritative evaluate() observes VICTORY")


func _observe_defeat(battle: Dictionary, label: String) -> void:
	var party: CombatParty = battle["party"]
	var enemies: CombatEnemies = battle["enemies"]
	var result: CombatBattleResult = battle["result"]
	_check(result.get_outcome() == CombatBattleResult.ACTIVE and not enemies.is_victorious(),
		label + " begins ACTIVE with a surviving enemy")
	for position in range(1, 4):
		var hp: int = party.get_hero(position)["hp"]
		_check(party.apply_damage(position, hp) and party.is_downed(position)
			and party.get_hero(position)["hp"] == 0,
			label + " actually downs hero at position %d" % position)
	_check(party.is_defeated() and not enemies.is_victorious(),
		label + " all three real heroes down and enemy survives")
	_check(result.evaluate() == CombatBattleResult.DEFEAT
		and result.get_outcome() == CombatBattleResult.DEFEAT,
		label + " authoritative evaluate() observes DEFEAT")


func _test_detached_and_missing_selection() -> void:
	var detached := RunActBattleOutcome.new(null)
	var battle := _fight([7])
	_check(detached.has_method("begin_current_battle")
		and detached.has_method("settle_current_battle") and detached.has_method("get_state"),
		"public contract methods exist")
	var detached_before := detached.get_state()
	_check(detached_before == {"run_status": "ACTIVE", "pending_node_id": "",
		"settled_node_ids": []}, "detached state documented and initially ACTIVE")
	_check(not detached.begin_current_battle(battle["result"])
		and not detached.settle_current_battle() and detached.get_state() == detached_before,
		"detached service rejects without mutation")
	var ungenerated := RunActBattleOutcome.new(RunMap.new())
	_check(not ungenerated.begin_current_battle(battle["result"])
		and not ungenerated.settle_current_battle()
		and ungenerated.get_state() == detached_before,
		"ungenerated map cannot bind a battle")
	var ctx := _context(97)
	var before := _snapshot(ctx, battle)
	_check(not ctx["map"].choose_node("missing_node"),
		"missing map node cannot be selected")
	_check(_snapshot(ctx, battle) == before,
		"missing-node rejection preserves full map, service, combat and RNG")
	_reject_begin(ctx, battle["result"], battle, "no selected node")
	_reject_settle(ctx, battle, "no pending battle")


func _test_fight_and_elite_wins() -> void:
	var ctx := _context(1977)
	var chosen := _opening_fight(ctx)
	_check(not chosen.is_empty(), "chosen normal node is an actual Fight")
	var battle := _fight([8, 9])
	var service: RunActBattleOutcome = ctx["service"]
	var original_rng: int = ctx["rng"].state
	_check(service.begin_current_battle(battle["result"]), "Fight begins with fresh bound ACTIVE result")
	_check(service.get_state().pending_node_id == chosen
		and service.get_state().run_status == "ACTIVE", "Fight stays pending and run ACTIVE")
	_reject_begin(ctx, _fight([7])["result"], battle, "second bound result")
	_reject_settle(ctx, battle, "still ACTIVE normal fight")
	var enemies: CombatEnemies = battle["enemies"]
	_check(enemies.apply_damage(1, 8) and enemies.is_dead(1)
		and not enemies.is_victorious(), "first enemy dies while second remains alive")
	_check(battle["result"].evaluate() == CombatBattleResult.ACTIVE,
		"partial enemy deaths do not produce terminal result")
	_reject_settle(ctx, battle, "partially won Fight")
	_check(enemies.apply_damage(2, 9) and enemies.is_victorious(),
		"last enemy actually killed in normal Fight")
	_reject_settle(ctx, battle, "lethal Fight not observed by evaluate")
	_check(battle["result"].evaluate() == CombatBattleResult.VICTORY,
		"Fight result witnessed through evaluate")
	var world_before := _world(ctx, battle)
	_check(service.settle_current_battle(), "witnessed Fight VICTORY settles")
	_check(_world(ctx, battle) == world_before and ctx["rng"].state == original_rng,
		"successful Fight settlement changes no combat/map/choices/RNG")
	_check(service.get_state() == {"run_status": "ACTIVE",
		"pending_node_id": "", "settled_node_ids": [chosen]},
		"Fight records exactly once, clears pending, and run remains ACTIVE")
	_reject_settle(ctx, battle, "duplicate Fight settlement")
	_reject_begin(ctx, _fight([6])["result"], battle, "same Fight cannot rebind")
	var read_one := service.get_state()
	var read_two := service.get_state()
	read_one["settled_node_ids"].clear()
	read_one["pending_node_id"] = "fake"
	_check(read_two == service.get_state() and service.get_state().settled_node_ids == [chosen],
		"get_state returns independent defensive settled-node snapshots")

	var elite_ctx := _context_for_kind("Elite", 102)
	var elite_path := _path_to(elite_ctx["map"], "Elite")
	_check(elite_path.size() >= 1, "Elite is on a real connected graph route")
	_choose_path(elite_ctx, elite_path)
	var elite_map: RunMap = elite_ctx["map"]
	_check(elite_map.get_node(elite_map.get_current_node_id()).get("type") == "Elite"
		and elite_map.get_current_floor() < 12, "target is selected pre-Boss Elite")
	var elite_battle := _fight([10, 13, 17])
	_check(elite_ctx["service"].begin_current_battle(elite_battle["result"]),
		"Elite binds fresh ACTIVE combat result")
	_observe_victory(elite_battle, "Elite")
	var elite_world := _world(elite_ctx, elite_battle)
	_check(elite_ctx["service"].settle_current_battle(),
		"observed Elite victory settles")
	_check(_world(elite_ctx, elite_battle) == elite_world,
		"Elite settlement preserves full map/actors/run RNG")
	_check(elite_ctx["service"].get_state() == {"run_status": "ACTIVE",
		"pending_node_id": "", "settled_node_ids": [elite_path.back()]},
		"Elite records once and run stays ACTIVE")
	_reject_settle(elite_ctx, elite_battle, "duplicate Elite settlement")


func _boss_trace(seed_value: int) -> Array:
	var ctx := _context(seed_value)
	var service: RunActBattleOutcome = ctx["service"]
	var map: RunMap = ctx["map"]
	var path := _path_to(map, "Boss")
	_check(path.size() == 12, "Boss route has exactly 12 connected floors")
	var trace: Array = []
	var initial_rng: int = ctx["rng"].state
	for floor_index in range(path.size()):
		_choose(ctx, path[floor_index])
		var kind: String = map.get_node(path[floor_index]).get("type")
		_check(map.get_current_floor() == floor_index + 1,
			"Boss walk reaches exactly floor %d" % (floor_index + 1))
		_check(service.get_state().run_status == "ACTIVE",
			"selection alone cannot win the run on floor %d" % (floor_index + 1))
		trace.append(_snapshot(ctx))
		if kind == "Fight" or kind == "Elite":
			var fight := _fight([6, 11])
			_check(service.begin_current_battle(fight["result"]),
				"route Fight/Elite accepts authoritative ACTIVE result")
			_observe_victory(fight, "route floor %d" % (floor_index + 1))
			var before := _world(ctx, fight)
			_check(service.settle_current_battle(),
				"observed intermediate win is recorded")
			_check(_world(ctx, fight) == before, "intermediate win never mutates world")
			_check(service.get_state().run_status == "ACTIVE",
				"intermediate Fight/Elite win never ends run")
			trace.append(_snapshot(ctx, fight))
	_check(map.is_complete() and map.get_current_floor() == 12
		and map.get_route().size() == 12
		and map.get_node(map.get_current_node_id()).get("type") == "Boss",
		"legal route really ends at a floor-12 Boss")
	_check(ctx["rng"].state == initial_rng, "twelve floor traversal and wins use zero run RNG")
	var boss := _fight([12, 15, 19])
	var boss_id := map.get_current_node_id()
	_check(service.get_state().run_status == "ACTIVE"
		and service.get_state().pending_node_id.is_empty(),
		"Boss selection itself does not declare RUN VICTORY")
	_check(service.begin_current_battle(boss["result"]),
		"fresh ACTIVE Boss result bound to selected node")
	_check(service.get_state().pending_node_id == boss_id
		and service.get_state().run_status == "ACTIVE",
		"bound ACTIVE Boss is still not RUN VICTORY")
	_reject_settle(ctx, boss, "ACTIVE Boss")
	trace.append(_snapshot(ctx, boss))
	var enemies: CombatEnemies = boss["enemies"]
	_check(enemies.apply_damage(1, 12) and enemies.apply_damage(2, 15),
		"Boss encounter kills first two real enemies")
	_check(boss["result"].evaluate() == CombatBattleResult.ACTIVE
		and not enemies.is_victorious(), "Boss result remains ACTIVE with final living enemy")
	_reject_settle(ctx, boss, "Boss with one enemy alive")
	_check(enemies.apply_damage(3, 19) and enemies.is_victorious(),
		"Boss victory has all real enemy positions slain")
	_reject_settle(ctx, boss, "unobserved lethal Boss")
	_check(boss["result"].evaluate() == CombatBattleResult.VICTORY,
		"Boss victory actually observed by CombatBattleResult.evaluate")
	var before_boss := _world(ctx, boss)
	var before_settled: Array = service.get_state().settled_node_ids
	_check(service.settle_current_battle(), "observed Boss victory latches run VICTORY")
	_check(_world(ctx, boss) == before_boss and ctx["rng"].state == initial_rng,
		"Boss settlement preserves actor HP, route, legal choices and run RNG")
	_check(service.get_state().run_status == "VICTORY"
		and service.get_state().pending_node_id == ""
		and service.get_state().settled_node_ids == before_settled + [boss_id],
		"Boss node recorded once and run VICTORY latched")
	_reject_settle(ctx, boss, "terminal Boss replay")
	_reject_begin(ctx, _fight([7])["result"], boss, "new combat after run victory")
	trace.append(_snapshot(ctx, boss))
	return trace


func _test_boss_replay() -> void:
	var a := _boss_trace(5801)
	var b := _boss_trace(5801)
	_check(a.size() > 13 and a.size() == b.size(), "both Boss traces include actual route and combat")
	_check(a == b, "same seed and fresh services reproduce every complete state transition")


func _test_all_kind_defeats() -> void:
	for kind in ["Fight", "Elite", "Boss"]:
		var ctx := _context_for_kind(kind, 180)
		var path := _path_to(ctx["map"], kind)
		_choose_path(ctx, path)
		var map: RunMap = ctx["map"]
		_check(map.get_node(map.get_current_node_id()).get("type") == kind,
			"selected real " + kind + " for defeat")
		var battle := _fight([16, 21])
		var service: RunActBattleOutcome = ctx["service"]
		_check(service.begin_current_battle(battle["result"]),
			kind + " defeat fixture binds fresh result")
		var party: CombatParty = battle["party"]
		var enemies: CombatEnemies = battle["enemies"]
		for pos in range(1, 4):
			_check(party.apply_damage(pos, party.get_hero(pos)["hp"])
				and party.is_downed(pos), kind + " defeats real hero %d" % pos)
		_check(party.is_defeated() and not enemies.is_victorious(),
			kind + " has all heroes down with enemies surviving")
		_reject_settle(ctx, battle, kind + " lethal heroes not yet evaluated")
		_check(battle["result"].evaluate() == CombatBattleResult.DEFEAT,
			kind + " observes authoritative DEFEAT")
		var before := _world(ctx, battle)
		_check(service.settle_current_battle(), kind + " witnessed DEFEAT latches")
		_check(_world(ctx, battle) == before,
			kind + " DEFEAT settlement leaves heroes/enemies/route/RNG unchanged")
		_check(service.get_state() == {"run_status": "DEFEAT",
			"pending_node_id": "", "settled_node_ids": [path.back()]},
			kind + " DEFEAT is terminal with exact settled node")
		_reject_settle(ctx, battle, kind + " duplicate defeat")
		_reject_begin(ctx, _fight([8])["result"], battle, kind + " terminal cannot restart")


func _test_rejections_and_stale_binding() -> void:
	for kind in ["Rest", "Shop", "Event", "Treasure"]:
		var ctx := _context_for_kind(kind, 44)
		_choose_path(ctx, _path_to(ctx["map"], kind))
		var battle := _fight([7])
		_check(ctx["map"].get_node(ctx["map"].get_current_node_id()).get("type") == kind,
			"non-battle node type is actually " + kind)
		_reject_begin(ctx, battle["result"], battle, kind + " is not a battle")
		_reject_settle(ctx, battle, kind + " has no pending result")

	var ctx := _context(361)
	_opening_fight(ctx)
	var battle := _fight([11])
	var good: CombatBattleResult = battle["result"]
	_reject_begin(ctx, null, battle, "null combat result")
	var invalid_cases: Array[CombatBattleResult] = [
		CombatBattleResult.new(null, battle["enemies"]),
		CombatBattleResult.new(CombatParty.new([]), battle["enemies"]),
		CombatBattleResult.new(battle["party"], null),
		CombatBattleResult.new(battle["party"], CombatEnemies.new([]))]
	for invalid in invalid_cases:
		_check(invalid.get_outcome() == CombatBattleResult.UNRESOLVED,
			"invalid/null roster cannot produce fresh ACTIVE result")
		_reject_begin(ctx, invalid, battle, "invalid result")
	var preobserved := _fight([4])
	_observe_victory(preobserved, "preobserved")
	_reject_begin(ctx, preobserved["result"], preobserved,
		"already terminal result cannot begin")
	_check(ctx["service"].begin_current_battle(good),
		"valid fresh result can begin after every rejected input")
	var foreign := _fight([5])
	_observe_victory(foreign, "foreign")
	_reject_settle(ctx, battle, "other result terminal while bound result ACTIVE")
	_check(good.get_outcome() == CombatBattleResult.ACTIVE,
		"foreign observation does not alter bound result")
	_observe_victory(battle, "correct binding")
	_check(ctx["service"].settle_current_battle(), "bound result can settle after foreign refusal")
	_reject_settle(ctx, battle, "duplicate successful normal node")

	var stale := _context(73)
	_opening_fight(stale)
	var stale_battle := _fight([13])
	_check(stale["service"].begin_current_battle(stale_battle["result"]),
		"stale-node fixture begins at valid Fight")
	var pending_id: String = stale["map"].get_current_node_id()
	var next_id: String = stale["map"].get_legal_choices()[0]
	_choose(stale, next_id)
	_check(pending_id != next_id, "map really advances away from bound node")
	_observe_victory(stale_battle, "stale node")
	_reject_settle(stale, stale_battle, "pending node advanced elsewhere")
	_check(stale["service"].get_state().pending_node_id == pending_id,
		"stale rejection preserves prior bound pending identity")

	var tied := _context(822)
	_opening_fight(tied)
	var tie_battle := _fight([6])
	_check(tied["service"].begin_current_battle(tie_battle["result"]),
		"tie fixture binds an initially ACTIVE result")
	var tie_party: CombatParty = tie_battle["party"]
	var tie_enemies: CombatEnemies = tie_battle["enemies"]
	for pos in range(1, 4):
		_check(tie_party.apply_damage(pos, tie_party.get_hero(pos)["hp"]),
			"tie downs actual hero %d" % pos)
	_check(tie_enemies.apply_damage(1, 6) and tie_party.is_defeated()
		and tie_enemies.is_victorious(), "tie really kills BOTH sides")
	_reject_settle(tied, tie_battle, "unobserved simultaneous deaths")
	_check(tie_battle["result"].evaluate() == CombatBattleResult.UNRESOLVED,
		"observed tied result remains UNRESOLVED, never wins")
	_reject_settle(tied, tie_battle, "observed UNRESOLVED tie")

	var regen := _context(912)
	_opening_fight(regen)
	var regen_battle := _fight([8])
	_check(regen["service"].begin_current_battle(regen_battle["result"]),
		"map-regeneration fixture initially binds")
	_observe_victory(regen_battle, "regenerated")
	_check(regen["map"].generate(regen["rng"]), "external map regeneration succeeds")
	_reject_settle(regen, regen_battle, "regenerated map invalidates stale bound route")
