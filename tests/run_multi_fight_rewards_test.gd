extends SceneTree

var failures: Array[String] = []
var checks := 0
const TRINKETS := ["thread_token", "button_charm", "spool_pendant"]


func _initialize() -> void:
	seed(92177)
	var expected_global := randi()
	seed(92177)
	_check(_replay() == _replay(), "same-seed replay includes both real settlements and RNG")
	_check(randi() == expected_global, "both complete settlements consume no global RNG")
	_test_rejections()
	for failure in failures:
		printerr(failure)
	print("run_multi_fight_rewards_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _fixture() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	# Find a generated, connected opening Fight -> Elite, without editing maps.
	var map := RunMap.new()
	var path: Array = []
	for seed_value in range(1, 1000):
		rng.seed = seed_value
		_check(map.generate(rng), "generate real map")
		for node in map.get_floors()[0]:
			if node["type"] != "Fight":
				continue
			for target in node["outgoing"]:
				if map.get_node(target)["type"] == "Elite":
					path = [node["id"], target]
					break
			if not path.is_empty():
				break
		if not path.is_empty():
			break
	_check(path.size() == 2, "generated opening has connected Fight and Elite")
	var heroes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))
	for hero in heroes:
		hero["max_hp"] = int(hero["max_hp"])
	var party := CombatParty.new(heroes)
	_check(party.is_valid(), "real authored party valid")
	var carry := RunPartyCarryover.new(party.get_heroes())
	var deck: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/starter_deck.json"))
	var candidates := StarterCards.new().get_all_card_ids()
	_check(deck.size() > 0 and candidates.size() >= 3 and carry.is_valid(), "nonempty authored resources")
	var owner := RunMultiFightRewards.new(map, rng, carry, deck, 7, ["button_charm"], candidates, TRINKETS)
	return {"map": map, "rng": rng, "carry": carry, "party": party, "owner": owner,
		"path": path, "deck": deck, "candidates": candidates}


func _battle(party: CombatParty) -> CombatBattleResult:
	var result := CombatBattleResult.new(party, CombatEnemies.new([{"id": "ragling", "max_hp": 8}]))
	_check(result.get_outcome() == CombatBattleResult.ACTIVE, "real battle begins ACTIVE")
	return result


func _win(result: CombatBattleResult) -> void:
	_check(result._enemies.apply_damage(1, 8), "real lethal damage")
	_check(result.evaluate() == CombatBattleResult.VICTORY, "witness real victory")


func _oracle(rng: RandomNumberGenerator, candidates: Array, elite: bool) -> Dictionary:
	var award := rng.randi_range(25, 35) if elite else rng.randi_range(10, 20)
	var pool := candidates.duplicate()
	pool.sort()
	var offers: Array = []
	var catalog := StarterCards.new()
	for i in range(3):
		var index := rng.randi_range(0, pool.size() - 1)
		var id: String = pool.pop_at(index)
		offers.append({"id": id, "owner": catalog.get_definition(id)["owner"]})
	var drop := ""
	if elite:
		var eligible := ["spool_pendant", "thread_token"]
		drop = eligible[rng.randi_range(0, 1)]
	return {"ok": true, "gold_award": award, "offers": offers, "trinket_drop_id": drop}


func _reject(f: Dictionary, action: Callable, message: String) -> void:
	var state: Dictionary = f.owner.read_state()
	var ledger: Dictionary = f.carry.read_state()
	var heroes: Array = f.party.get_heroes()
	var route: Array = f.map.get_route()
	var rng_state: int = f.rng.state
	_check(action.call().get("ok") == false, message + " rejects")
	_check(f.owner.read_state() == state and f.carry.read_state() == ledger
		and f.party.get_heroes() == heroes and f.map.get_route() == route
		and f.rng.state == rng_state, message + " preserves all authoritative state and RNG")


func _replay() -> Dictionary:
	var f := _fixture()
	var owner: RunMultiFightRewards = f.owner
	var oracle := RandomNumberGenerator.new()
	oracle.seed = f.rng.seed
	oracle.state = f.rng.state
	var expected_deck: Array = f.deck.duplicate()
	var expected_gold := 7
	var final_drop := ""
	var outputs: Array = []
	for index in range(2):
		var id: String = f.path[index]
		_check(f.map.get_legal_choices().has(id) and f.map.choose_node(id), "legal connected selection")
		if index == 1:
			f.party = f.carry.create_next_fight_party()
			_check(f.party != null and f.party.get_heroes() == owner.read_state().party.heroes,
				"subsequent battle hydrates carried party")
			if f.party == null:
				return {}
			# A previous battle is not a new victory just because the route advanced.
			var old_result: CombatBattleResult = outputs[0]["battle"]
			_reject(f, func(): return owner.prepare(id, old_result, old_result._party), "paid battle reused on another node")
		var party: CombatParty = f.party
		var result := _battle(party)
		_reject(f, func(): return owner.choose(id, ""), "choice before preparation")
		_check(party.apply_damage(1, 3), "battle damages carried front hero")
		# Combat can alter positions/statuses; persistence must retain the full snapshot.
		if index == 0:
			var roster := party.get_heroes()
			var first: Dictionary = roster[0]
			roster[0] = roster[1]
			roster[1] = first
			roster[0]["position"] = 1
			roster[1]["position"] = 2
			roster[1]["statuses"] = {"bleed": 2}
			party._heroes.assign(roster)
		_check(party.gain_block(2, 5), "battle earns temporary Block")
		_win(result)
		var before := owner.read_state()
		var expected := _oracle(oracle, f.candidates, index == 1)
		var prepared := owner.prepare(id, result, party)
		_check(prepared == expected and f.rng.state == oracle.state, "independent exact award/offers/drop/RNG")
		_check(owner.read_state() == before, "prepare publishes no resources or heroes")
		var held_rng: int = f.rng.state
		_check(owner.prepare(id, result, party) == expected and f.rng.state == held_rng, "duplicate prepare caches without draws")
		prepared["offers"][0]["id"] = "corrupt"
		_check(owner.prepare(id, result, party) == expected, "offers detached")
		_reject(f, func(): return owner.choose(id, "unknown_card"), "invalid offered ID")
		_reject(f, func(): return owner.choose(id, null), "non-string skip")
		_reject(f, func(): return owner.choose("wrong_node", ""), "stale node callback")
		var selected: String = expected.offers[0].id if index == 0 else ""
		if index == 0:
			expected_deck.append(selected)
		expected_gold += expected.gold_award
		var carried := party.get_heroes()
		for hero in carried:
			hero["block"] = 0
		var settled := owner.choose(id, selected)
		_check(settled.get("ok") == true and settled.get("skipped") == (index == 1), "pick then explicit Skip settle")
		var state := owner.read_state()
		_check(state.deck == expected_deck and state.gold == expected_gold and state.party.heroes == carried
			and f.carry.read_state() == state.party and f.rng.state == oracle.state, "atomic cumulative state and zero transit Block")
		if index == 1:
			final_drop = expected.trinket_drop_id
			_check(state.trinkets == ["button_charm", final_drop], "Elite adds cached unowned trinket")
		_check(state.party.completed_fights == f.path.slice(0, index + 1), "distinct nodes committed once")
		_reject(f, func(): return owner.choose(id, selected), "duplicate choice")
		_reject(f, func(): return owner.prepare(id, result, party), "paid prepare")
		var fresh := RunMultiFightRewards.new(f.map, f.rng, f.carry, state.deck, state.gold, state.trinkets, f.candidates, TRINKETS)
		_reject(f, func(): return fresh.prepare(id, result, party), "fresh owner cannot reuse ledger node")
		var snapshot := owner.read_state()
		snapshot.deck.clear()
		snapshot.trinkets.clear()
		snapshot.party.heroes[0].hp = 999
		settled.state.party.heroes.clear()
		_check(owner.read_state() == state, "nested run and returned settlement snapshots detached")
		outputs.append({"state": state, "battle": result})
	_check(owner.read_state().party.heroes[1].hp == 37
		and owner.read_state().party.heroes[0].hp == 27
		and owner.read_state().party.heroes[1].statuses == {"bleed": 2}, "damage, swapped positions and statuses survive both battles")
	return {"outputs": [outputs[0].state, outputs[1].state], "rng": f.rng.state, "drop": final_drop}


func _test_rejections() -> void:
	seed(3812)
	var next_global := randi()
	seed(3812)
	for scenario in ["active", "defeat", "foreign", "route", "pending_other", "party_changed", "ledger_changed", "consumed", "consumed_pending", "identities", "enemies_changed", "no_selection", "rest", "bad_pool"]:
		var f := _fixture()
		var owner: RunMultiFightRewards = f.owner
		var id: String = f.path[0]
		if scenario != "no_selection":
			_check(f.map.choose_node(id), "negative fixture selected real Fight")
		var party: CombatParty = f.party
		var result := _battle(party)
		if scenario == "active" or scenario == "no_selection":
			_reject(f, func(): return owner.prepare(id, result, party), scenario)
			continue
		if scenario == "defeat":
			for position in range(1, 4):
				_check(party.apply_damage(position, party.get_hero(position).hp), "down real hero")
			_check(result.evaluate() == CombatBattleResult.DEFEAT, "witness defeat")
			_reject(f, func(): return owner.prepare(id, result, party), scenario)
			continue
		_win(result)
		if scenario == "foreign":
			var foreign: CombatParty = _fixture().party
			_reject(f, func(): return owner.prepare(id, result, foreign), scenario)
			continue
		if scenario == "identities":
			party._heroes[0]["max_hp"] += 1
			_reject(f, func(): return owner.prepare(id, result, party), scenario)
			continue
		if scenario == "rest":
			# Select a real generated noncombat node along the route.
			var found := false
			while not f.map.is_complete():
				var choices: Array = f.map.get_legal_choices()
				var target: String = choices[0]
				for option in choices:
					if f.map.get_node(option).type not in ["Fight", "Elite"]:
						target = option
						found = true
				_check(f.map.choose_node(target), "legal noncombat fixture traversal")
				if found:
					break
			_check(found, "actual noncombat selection exists")
			_reject(f, func(): return owner.prepare(f.map.get_current_node_id(), result, party), scenario)
			continue
		if scenario == "bad_pool":
			owner = RunMultiFightRewards.new(f.map, f.rng, f.carry, f.deck, 7, [], ["missing"])
			_reject(f, func(): return owner.prepare(id, result, party), scenario)
			continue
		if scenario == "consumed":
			_check(f.carry.commit_victory(id, result, party).ok, "external ledger consumes real node")
			_reject(f, func(): return owner.prepare(id, result, party), scenario)
			continue
		_check(owner.prepare(id, result, party).get("ok") == true, "negative fixture really prepares offers")
		if scenario in ["route", "pending_other"]:
			_check(f.map.choose_node(f.path[1]), "advance to connected Elite while pending")
			_reject(f, func(): return owner.prepare(f.path[1], result, party), "other node blocked by pending")
		elif scenario == "party_changed":
			_check(party.apply_damage(1, 1), "change authoritative party after prepare")
		elif scenario == "consumed_pending":
			_check(f.carry.commit_victory(id, result, party).ok, "consume ledger node after preparation")
		elif scenario == "enemies_changed":
			result._enemies._enemies[0]["hp"] = 1
		else:
			_check(f.carry.choose_rest_heal("external_rest").ok, "change authoritative ledger after prepare")
		_reject(f, func(): return owner.choose(id, ""), scenario + " choose")
		_reject(f, func(): return owner.prepare(id, result, party), scenario + " reprepare")
	_check(randi() == next_global, "all accepted/rejected coordinator paths leave global RNG untouched")
