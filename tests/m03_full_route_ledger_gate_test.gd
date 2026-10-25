extends SceneTree
## Service integration only: public combat damage witnesses outcomes, not UI play.
## Search seeds 1..612, depth at most twelve, using generated public graph data.
const SEED_LIMIT := 612
const TRINKETS := ["thread_token", "button_charm", "spool_pendant"]
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	seed(87003)
	var expected_global := randi()
	_check(randi() != expected_global, "global RNG guard detects an injected extra draw")
	seed(87003)
	var route := _find_route()
	_check(not route.is_empty(), "bounded seed search finds required generated route")
	if not route.is_empty():
		var first := _replay(route, false)
		var second := _replay(route, false)
		_check(not first.is_empty() and first == second, "independent winning replays match every snapshot and RNG")
		_replay(route, true)
	_check(randi() == expected_global, "search, wins, defeat and rejected actions preserve global RNG")
	for failure in failures:
		printerr(failure)
	print("m03_full_route_ledger_gate_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _find_route() -> Dictionary:
	for seed_value in range(1, SEED_LIMIT + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var map := RunMap.new()
		_check(map.generate(rng), "search generates map")
		var path := _search(map, map.get_legal_choices(), [], {"Fight": 0, "Elite": 0, "Rest": 0, "Shop": 0})
		if not path.is_empty():
			print("twelve-floor ledger route seed=", seed_value, " path=", path)
			return {"seed": seed_value, "path": path, "graph": map.get_floors(), "rng": rng.state}
	return {}


func _search(map: RunMap, choices: Array, prefix: Array, counts: Dictionary) -> Array:
	for id in choices:
		var node := map.get_node(id)
		var kind: String = node.type
		if prefix.is_empty() and kind != "Fight":
			continue
		var path := prefix.duplicate()
		path.append(id)
		if kind == "Boss":
			if path.size() == 12 and counts.Fight >= 2 and counts.Elite == 1 and counts.Rest > 0 and counts.Shop > 0:
				return path
			continue
		# Keep the gate focused on services in this brief; no unhandled Events/Treasure.
		if not counts.has(kind) or (kind == "Elite" and counts.Elite == 1):
			continue
		var next := counts.duplicate()
		next[kind] += 1
		var found := _search(map, node.outgoing, path, next)
		if not found.is_empty():
			return found
	return []


func _authored(path: String) -> Array:
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(decoded is Array and not decoded.is_empty(), "nonempty authored roster: " + path)
	if not decoded is Array:
		return []
	for actor in decoded:
		var hp: Variant = actor.get("max_hp")
		_check((hp is int or hp is float) and hp > 0 and floorf(hp) == hp, "authored HP is positive integral")
		actor.max_hp = int(hp)
	return decoded


func _snapshot(f: Dictionary) -> Dictionary:
	return {"graph": f.map.get_floors(), "route": f.map.get_route(),
		"choices": f.map.get_legal_choices(), "floor": f.map.get_current_floor(),
		"node": f.map.get_current_node_id(), "complete": f.map.is_complete(),
		"revision": f.map.get_generation_revision(), "act": f.act.get_state(),
		"carry": f.carry.read_state(), "shop": f.shop.get_state(),
		"rewards": f.owner.read_state(), "heroes": f.party.get_heroes(),
		"enemies": [] if f.enemies == null else f.enemies.get_enemies(),
		"battle": "" if f.result == null else f.result.get_outcome(),
		"seed": f.rng.seed, "rng": f.rng.state}


func _reject(f: Dictionary, action: Callable, label: String) -> void:
	var before := _snapshot(f)
	var reply: Variant = action.call()
	_check((reply is bool and not reply) or (reply is Dictionary and reply.get("ok") == false), label + " rejects")
	_check(_snapshot(f) == before, label + " preserves full detached state and RNG")


func _owner(f: Dictionary) -> RunMultiFightRewards:
	var resources: Dictionary = f.shop.get_state()
	return RunMultiFightRewards.new(f.map, f.rng, f.carry, resources.deck, resources.gold,
		resources.trinkets, StarterCards.new().get_all_card_ids(), TRINKETS)


func _replay(route: Dictionary, lose: bool) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = route.seed
	var map := RunMap.new()
	_check(map.generate(rng) and map.get_floors() == route.graph and rng.state == route.rng, "fresh same-seed generated graph and RNG")
	var party := CombatParty.new(_authored("res://data/heroes/starter_party.json"))
	_check(party.is_valid() and party.get_heroes().size() == 3, "authored party valid")
	var deck: Array[String] = []
	deck.assign(JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/starter_deck.json")))
	_check(not deck.is_empty(), "authored starting deck nonempty")
	for id in deck:
		_check(not StarterCards.new().get_definition(id).is_empty(), "authored card ID exists")
	var f := {"map": map, "rng": rng, "party": party,
		"carry": RunPartyCarryover.new(party.get_heroes()),
		"shop": RunShopVisit.new(deck, 7, 0, ["button_charm"]),
		"act": RunActBattleOutcome.new(map), "enemies": null, "result": null}
	f.owner = _owner(f)
	_check(f.carry.is_valid() and f.shop.get_state().valid, "real ledgers valid")
	var trace: Array = [_snapshot(f)]
	var fought := 0
	var elites := 0
	var rests := 0
	var shops := 0
	var settled_ids: Array = []
	for index in range(route.path.size()):
		var id: String = route.path[index]
		_check(f.act.get_state().run_status == "ACTIVE", "run ACTIVE before each legal advance")
		_reject(f, func(): return map.choose_node("missing_node"), "unknown route choice")
		_check(map.get_legal_choices().has(id) and map.choose_node(id), "choose only actual legal connected node")
		_check(map.get_current_floor() == index + 1 and map.get_route() == route.path.slice(0, index + 1), "advance one floor with exact route prefix")
		_reject(f, func(): return map.choose_node(id), "duplicate route choice")
		var kind: String = map.get_node(id).type
		trace.append(_snapshot(f))
		if kind == "Shop":
			shops += 1
			_check(f.shop.open_visit(id), "public Shop opens selected node")
			_reject(f, func(): return f.shop.open_visit(id), "duplicate Shop open")
			_reject(f, func(): return f.shop.remove_card("missing_card"), "invalid Shop removal")
			_check(f.shop.close_visit(), "public Shop closes")
			_reject(f, func(): return f.shop.close_visit(), "duplicate Shop close")
			_reject(f, func(): return f.shop.open_visit(id), "revisit closed Shop")
		elif kind == "Rest":
			rests += 1
			var before: Array = f.carry.read_state().heroes
			if rests == 1:
				_check(before[2].hp == 0 and before[0].hp < before[0].max_hp, "first Rest exercises both revive and damaged survivor healing")
			var visit := RunRestRecovery.new(before)
			var oracle := visit.choose_heal()
			_check(oracle.ok and visit.is_consumed(), "public Rest service consumes real recovery")
			var healed: Array = before.duplicate(true)
			for hero in healed:
				hero.hp = mini(hero.max_hp, (1 if hero.hp == 0 else hero.hp) + int(floor(hero.max_hp * 0.3)))
			_check(oracle.heroes == healed, "Rest revives at one then heals capped thirty percent")
			_reject(f, func(): return visit.choose_heal(), "repeated Rest service recovery")
			_check(f.carry.choose_rest_heal(id).get("heroes") == healed, "carry ledger commits actual Rest recovery")
			_reject(f, func(): return f.carry.choose_rest_heal(id), "duplicate Rest ledger transaction")
			f.owner = _owner(f) # Rest changes the ledger; refresh its resource binding.
		else:
			_check(kind in ["Fight", "Elite", "Boss"], "every node has an exercised service")
			if fought > 0:
				f.party = f.carry.create_next_fight_party()
				_check(f.party != null, "next battle hydrates surviving carry snapshot")
				if f.party == null:
					return []
			_check(f.party.get_heroes() == f.carry.read_state().heroes, "battle starts with exact carried heroes")
			var source := "res://data/enemies/boss.json" if kind == "Boss" else "res://data/enemies/starter_enemies.json"
			f.enemies = CombatEnemies.new(_authored(source))
			_check(f.enemies.is_valid() and not f.enemies.is_victorious(), "authored enemies begin alive")
			f.result = CombatBattleResult.new(f.party, f.enemies)
			_check(f.result.get_outcome() == CombatBattleResult.ACTIVE and f.act.begin_current_battle(f.result), "bind fresh ACTIVE battle before observation")
			f.owner = _owner(f)
			_reject(f, func(): return f.act.settle_current_battle(), "premature ACTIVE settlement")
			_reject(f, func(): return f.owner.prepare(id, f.result, f.party), "unwon reward preparation")
			_reject(f, func(): return f.owner.choose(id, ""), "choice without preparation")
			if lose:
				for position in range(1, 4):
					_check(f.party.apply_damage(position, f.party.get_hero(position).hp), "real lethal party damage")
				_reject(f, func(): return f.act.settle_current_battle(), "unobserved party defeat")
				_check(f.party.is_defeated() and not f.enemies.is_victorious() and f.result.evaluate() == CombatBattleResult.DEFEAT, "witness actual party DEFEAT")
				var unpaid: Dictionary = f.shop.get_state()
				var uncarried: Dictionary = f.carry.read_state()
				_check(f.act.settle_current_battle() and f.act.get_state().run_status == "DEFEAT", "observed defeat alone latches terminal DEFEAT")
				_reject(f, func(): return f.owner.prepare(id, f.result, f.party), "defeat cannot earn rewards")
				_reject(f, func(): return f.owner.choose(id, ""), "defeat cannot pay")
				_reject(f, func(): return f.act.settle_current_battle(), "duplicate defeat settlement")
				var fresh := CombatBattleResult.new(CombatParty.new(_authored("res://data/heroes/starter_party.json")), f.enemies)
				_check(fresh.get_outcome() == CombatBattleResult.ACTIVE, "terminal continuation probe is otherwise valid ACTIVE combat")
				_reject(f, func(): return f.act.begin_current_battle(fresh), "terminal defeat cannot continue")
				_check(f.shop.get_state() == unpaid and f.carry.read_state() == uncarried and map.get_route().size() == 1, "defeat pays nothing, carries nothing and stops before Boss")
				return [_snapshot(f)]
			# Public damage models combat losses, including a downed survivor for Rest.
			for position in range(1, 4):
				if not f.party.is_downed(position):
					var damage: int = f.party.get_hero(position).hp if fought == 0 and position == 3 else 2
					_check(f.party.apply_damage(position, damage), "battle damage affects actual carried hero")
			_check(f.party.gain_block(1, 4), "temporary battle Block earned")
			for enemy in f.enemies.get_enemies():
				_check(f.enemies.apply_damage(enemy.position, enemy.hp), "kill actual authored enemy")
			_reject(f, func(): return f.act.settle_current_battle(), "lethal enemies require observed victory")
			_check(f.result.evaluate() == CombatBattleResult.VICTORY and not f.party.is_defeated(), "witness real VICTORY with survivors")
			trace.append(_snapshot(f))
			_check(f.act.settle_current_battle(), "settle witnessed battle")
			settled_ids.append(id)
			_check(f.act.get_state().settled_node_ids == settled_ids, "all witnessed settlements recorded in route order")
			_reject(f, func(): return f.act.settle_current_battle(), "duplicate victory settlement")
			if kind == "Boss":
				_check(index == 11 and f.act.get_state().run_status == "VICTORY", "only observed floor-twelve Boss win ends run")
				_reject(f, func(): return f.owner.prepare(id, f.result, f.party), "Boss has no Fight reward")
				_check(f.carry.commit_victory(id, f.result, f.party).ok, "Boss survivor snapshot committed without reward")
				_reject(f, func(): return f.carry.commit_victory(id, f.result, f.party), "duplicate Boss carry")
			else:
				_check(f.act.get_state().run_status == "ACTIVE", "intermediate win leaves run ACTIVE")
				trace.append(_reward(f, id, kind, fought))
				if kind == "Elite":
					elites += 1
			fought += 1
		trace.append(_snapshot(f))
		var detached := _snapshot(f)
		detached.carry.heroes.clear()
		detached.shop.deck.clear()
		detached.act.settled_node_ids.clear()
		_check(_snapshot(f) == trace.back(), "nested snapshots detached from all authoritative services")
	_check(map.is_complete() and map.get_route() == route.path and map.get_current_floor() == 12, "complete connected twelve-floor route")
	_check(fought >= 4 and elites == 1 and rests > 0 and shops > 0, "nonvacuous repeated Fight, Elite, Rest, Shop and Boss coverage")
	_check(f.carry.read_state().completed_fights == settled_ids, "carry ledger includes every witnessed win")
	_check(f.carry.read_state().completed_rests.size() == rests and f.shop.get_state().visited_ids.size() == shops, "every Rest and Shop transacted")
	_check(f.shop.get_state().trinkets.size() == 2, "eligible Elite trinket persisted cumulatively")
	_check(f.act.get_state().run_status == "VICTORY", "winning replay terminal VICTORY")
	return trace


func _reward(f: Dictionary, id: String, kind: String, fought: int) -> Dictionary:
	var before := _snapshot(f)
	var prepared: Dictionary = f.owner.prepare(id, f.result, f.party)
	_check(prepared.get("ok") == true and prepared.get("offers", []).size() == 3, "real seeded reward offers prepared")
	if not prepared.get("ok") or prepared.get("offers", []).is_empty():
		return {}
	_check(f.shop.get_state() == before.shop and f.carry.read_state() == before.carry, "prepare pays no resources or survivors")
	var cached := _snapshot(f)
	_check(f.owner.prepare(id, f.result, f.party) == prepared and _snapshot(f) == cached, "repeated prepare caches exact offers without RNG")
	prepared.offers[0].id = "corrupt"
	prepared = f.owner.prepare(id, f.result, f.party)
	_check(prepared.offers[0].id != "corrupt", "prepared offers detached")
	_reject(f, func(): return f.owner.choose(id, "unknown_card"), "invalid reward card")
	var selected: String = prepared.offers[0].id if fought % 2 == 0 else ""
	var settled: Dictionary = f.owner.choose(id, selected)
	_check(settled.get("ok") == true, "real prepare/choose settles reward")
	if not settled.get("ok"):
		return {}
	var expected_deck: Array = before.shop.deck.duplicate()
	if not selected.is_empty():
		_check(not StarterCards.new().get_definition(selected).is_empty(), "chosen reward is actual authored card")
		expected_deck.append(selected)
	var expected_heroes: Array = f.party.get_heroes()
	for hero in expected_heroes:
		hero.block = 0
	_check(settled.state.deck == expected_deck and settled.state.gold == before.shop.gold + prepared.gold_award
		and settled.state.party.heroes == expected_heroes, "exact cumulative card, gold and Block-free survivor transaction")
	_check(prepared.gold_award >= (25 if kind == "Elite" else 10) and prepared.gold_award <= (35 if kind == "Elite" else 20), "authored reward range")
	var expected_trinkets: Array = before.shop.trinkets.duplicate()
	if kind == "Elite":
		_check(TRINKETS.has(prepared.trinket_drop_id) and not expected_trinkets.has(prepared.trinket_drop_id), "eligible unowned Elite trinket")
		expected_trinkets.append(prepared.trinket_drop_id)
	_check(settled.state.trinkets == expected_trinkets, "exact cumulative trinkets")
	_check(f.shop.apply_battle_reward(id, settled), "Shop ledger reconciles genuine committed settlement")
	_check(f.shop.get_state().deck == expected_deck and f.shop.get_state().gold == settled.state.gold
		and f.shop.get_state().trinkets == expected_trinkets, "both resource ledgers agree exactly")
	_reject(f, func(): return f.shop.apply_battle_reward(id, settled), "duplicate reward reconciliation")
	_reject(f, func(): return f.owner.choose(id, selected), "duplicate reward choice")
	_reject(f, func(): return f.owner.prepare(id, f.result, f.party), "paid reward preparation")
	var replay := {"prepared": prepared.duplicate(true), "cached_state": cached,
		"settlement": settled.duplicate(true), "final_state": _snapshot(f)}
	settled.state.party.heroes.clear()
	settled.receipt.node_id = "corrupt"
	_check(_snapshot(f) == replay.final_state, "settlement receipt and nested state detached")
	return replay
