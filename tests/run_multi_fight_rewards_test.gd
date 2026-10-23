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
	_test_stitched()
	for failure in failures:
		printerr(failure)
	print("run_multi_fight_rewards_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


## An authentic composite issued by the canonical Rest transaction, with exactly
## the ledger the routed run owns afterwards.
func _stitched_ledger(deck: Array) -> Dictionary:
	var source := RunRestStitchCards.new(deck, {}, RunRestStitchCards.SCRAP_COST, 1)
	_check(source.is_valid(), "funded authentic Rest ledger admits a stitch")
	if not source.is_valid():
		return {}
	var first: int = deck.find("seamstress_prick")
	var second: int = deck.find("tinker_pop_shot")
	_check(first >= 0 and second >= 0 and first != second,
		"authored cross-owner originals are owned instances")
	if first < 0 or second < 0 or first == second:
		return {}
	var made: Dictionary = source.choose_stitch(first, second, source.get_snapshot())
	_check(made.get("ok", false) and made.get("next_stitch_id") == 2,
		"canonical Rest transaction issues one composite and advances the cursor")
	if not made.get("ok", false):
		return {}
	return {"deck": made["deck"].duplicate(), "descriptors": made["descriptors"].duplicate(true),
		"next_stitch_id": made["next_stitch_id"], "id": made["stitched_id"]}


## The routed multi-Fight coordinator must carry the run's Rest stitch ledger, so
## an owned composite prepares, picks and Skips normally and malformed ledgers
## fail closed with no spend, no RNG drift and no replay.
func _test_stitched() -> void:
	var f := _fixture()
	var ledger := _stitched_ledger(f.deck)
	if ledger.is_empty():
		return
	var composite: String = ledger["id"]
	var source_deck: Array = ledger["deck"].duplicate()
	var source_descriptors: Dictionary = ledger["descriptors"].duplicate(true)
	_check(source_deck.count(composite) == 1 and source_deck.size() == f.deck.size() - 1,
		"authentic composite replaces exactly the two consumed originals")
	var owner := RunMultiFightRewards.new(f.map, f.rng, f.carry, ledger["deck"], 7,
		["button_charm"], f.candidates, TRINKETS, ledger["descriptors"], ledger["next_stitch_id"])
	f.owner = owner
	var id: String = f.path[0]
	_check(f.map.choose_node(id), "composite fixture selects the real opening Fight")
	var party: CombatParty = f.party
	var result := _battle(party)
	_win(result)
	var oracle := RandomNumberGenerator.new()
	oracle.seed = f.rng.seed
	oracle.state = f.rng.state
	var expected := _oracle(oracle, f.candidates, false)
	var prepared := owner.prepare(id, result, party)
	_check(prepared == expected and f.rng.state == oracle.state,
		"composite deck prepares the exact gold, offers and RNG")
	_check(owner.read_state().deck == ledger["deck"]
		and owner.read_state().deck.count(composite) == 1 and owner.read_state().gold == 7,
		"preparation keeps the composite once and pays nothing")
	var held_rng: int = f.rng.state
	_check(owner.prepare(id, result, party) == expected and f.rng.state == held_rng,
		"repeated composite prepare neither rerolls nor advances RNG")
	var selected: String = expected.offers[0].id
	var expected_deck: Array = ledger["deck"].duplicate()
	expected_deck.append(selected)
	var settled := owner.choose(id, selected)
	_check(settled.get("ok", false) and settled.get("selected_id") == selected
		and owner.read_state().deck == expected_deck
		and owner.read_state().gold == 7 + expected.gold_award
		and f.rng.state == oracle.state,
		"composite pick settles exactly once with one card and one award")
	_check(owner.read_state().deck.count(composite) == 1,
		"settled deck keeps the authentic composite exactly once")
	_check(ledger["deck"] == source_deck and ledger["descriptors"] == source_descriptors,
		"settlement never rewrites the source run ledger")
	_reject(f, func(): return owner.choose(id, selected), "duplicate composite claim")
	_reject(f, func(): return owner.prepare(id, result, party), "paid composite prepare")
	# An explicit Skip keeps the composite as the only copy of that member.
	var skip_f := _fixture()
	var skip_ledger := _stitched_ledger(skip_f.deck)
	if skip_ledger.is_empty():
		return
	var skip_owner := RunMultiFightRewards.new(skip_f.map, skip_f.rng, skip_f.carry,
		skip_ledger["deck"], 7, ["button_charm"], skip_f.candidates, TRINKETS,
		skip_ledger["descriptors"], skip_ledger["next_stitch_id"])
	skip_f.owner = skip_owner
	var skip_id: String = skip_f.path[0]
	_check(skip_f.map.choose_node(skip_id), "skip fixture selects the real opening Fight")
	var skip_result := _battle(skip_f.party)
	_win(skip_result)
	var skip_expected := skip_owner.prepare(skip_id, skip_result, skip_f.party)
	_check(skip_expected.get("ok", false), "composite skip fixture really prepares")
	var skipped := skip_owner.choose(skip_id, "")
	_check(skipped.get("ok", false) and skipped.get("skipped", false)
		and skip_owner.read_state().deck == skip_ledger["deck"]
		and skip_owner.read_state().deck.count(skip_ledger["id"]) == 1
		and skip_owner.read_state().gold == 7 + skip_expected.gold_award,
		"composite Skip keeps it once and pays exactly one award")
	# Every malformed ledger rejects before any draw or publication.
	for scenario in ["forged_id", "tampered_effect", "orphan", "cursor", "null_ledger",
			"duplicate_copy"]:
		var g := _fixture()
		var g_ledger := _stitched_ledger(g.deck)
		if g_ledger.is_empty():
			return
		var g_descriptors: Variant = g_ledger["descriptors"].duplicate(true)
		var g_deck: Array = g_ledger["deck"].duplicate()
		var g_cursor: Variant = g_ledger["next_stitch_id"]
		match scenario:
			"forged_id":
				g_deck.append("stitched_000007")
			"tampered_effect":
				g_descriptors[g_ledger["id"]]["second_half"]["effects"]["damage"] = 999
			"orphan":
				var orphan_copy: Dictionary = g_ledger["descriptors"][g_ledger["id"]].duplicate(true)
				orphan_copy["id"] = "stitched_000002"
				g_descriptors["stitched_000002"] = orphan_copy
				g_cursor = 3
			"cursor":
				g_cursor = 1
			"null_ledger":
				g_descriptors = null
			"duplicate_copy":
				g_deck.append(g_ledger["id"])
		var g_owner := RunMultiFightRewards.new(g.map, g.rng, g.carry, g_deck, 7,
			["button_charm"], g.candidates, TRINKETS, g_descriptors, g_cursor)
		g.owner = g_owner
		_check(not (g_deck == g_ledger["deck"] and g_descriptors == g_ledger["descriptors"]
			and g_cursor == g_ledger["next_stitch_id"]),
			"stitched " + scenario + " fixture genuinely differs from the canonical ledger")
		_check(g.map.choose_node(g.path[0]), "negative composite fixture selects real Fight")
		var g_result := _battle(g.party)
		_win(g_result)
		_reject(g, func(): return g_owner.prepare(g.path[0], g_result, g.party),
			"stitched " + scenario)
		_reject(g, func(): return g_owner.choose(g.path[0], ""), "stitched " + scenario + " claim")
	# The constructor freezes its own copy of the ledger.
	var frozen := _fixture()
	var frozen_ledger := _stitched_ledger(frozen.deck)
	if frozen_ledger.is_empty():
		return
	var live_descriptors: Dictionary = frozen_ledger["descriptors"].duplicate(true)
	var frozen_owner := RunMultiFightRewards.new(frozen.map, frozen.rng, frozen.carry,
		frozen_ledger["deck"], 7, ["button_charm"], frozen.candidates, TRINKETS,
		live_descriptors, frozen_ledger["next_stitch_id"])
	frozen.owner = frozen_owner
	live_descriptors.clear()
	_check(frozen.map.choose_node(frozen.path[0]), "frozen fixture selects real Fight")
	var frozen_result := _battle(frozen.party)
	_win(frozen_result)
	var frozen_oracle := RandomNumberGenerator.new()
	frozen_oracle.seed = frozen.rng.seed
	frozen_oracle.state = frozen.rng.state
	var frozen_expected := _oracle(frozen_oracle, frozen.candidates, false)
	_check(frozen_owner.prepare(frozen.path[0], frozen_result, frozen.party) == frozen_expected
		and frozen.rng.state == frozen_oracle.state,
		"constructor freezes the stitch ledger beside the deck and gold")
	# Legacy calls without a ledger keep rejecting a stitched deck.
	var legacy := _fixture()
	var legacy_ledger := _stitched_ledger(legacy.deck)
	if legacy_ledger.is_empty():
		return
	legacy.owner = RunMultiFightRewards.new(legacy.map, legacy.rng, legacy.carry,
		legacy_ledger["deck"], 7, ["button_charm"], legacy.candidates, TRINKETS)
	_check(legacy.map.choose_node(legacy.path[0]), "legacy fixture selects real Fight")
	var legacy_result := _battle(legacy.party)
	_win(legacy_result)
	_reject(legacy, func(): return legacy.owner.prepare(legacy.path[0], legacy_result, legacy.party),
		"stitched deck without a ledger")


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
	var rejected: Dictionary = action.call()
	_check(rejected.get("ok") == false, message + " rejects")
	_check(not rejected.has("receipt"), message + " has no usable receipt")
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
		var receipt := {"node_id": id, "node_kind": "Fight" if index == 0 else "Elite",
			"trinket_drop_id": expected.trinket_drop_id}
		_check(settled.get("receipt") == receipt and settled.get("selected_id") == selected,
			"successful receipt binds exact seeded Fight/Elite node and cached trinket")
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
		settled.receipt.node_id = "corrupted"
		settled.receipt.trinket_drop_id = "corrupted"
		_check(owner.read_state() == state, "nested run and returned settlement snapshots detached")
		_check(f.carry.read_state().completed_fights.back() == id and
			f.map.get_current_node_id() == id, "mutated receipt cannot alter authoritative claim or route")
		outputs.append({"state": state, "battle": result})
	_check(owner.read_state().party.heroes[1].hp == 37
		and owner.read_state().party.heroes[0].hp == 27
		and owner.read_state().party.heroes[1].statuses == {"bleed": 2}, "damage, swapped positions and statuses survive both battles")
	return {"outputs": [outputs[0].state, outputs[1].state], "rng": f.rng.state, "drop": final_drop}


func _test_rejections() -> void:
	seed(3812)
	var next_global := randi()
	seed(3812)
	for scenario in ["active", "defeat", "foreign", "route", "map_regenerated", "pending_other", "party_changed", "ledger_changed", "consumed", "consumed_pending", "identities", "enemies_changed", "no_selection", "rest", "bad_pool"]:
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
		elif scenario == "map_regenerated":
			var rebuilt_rng := RandomNumberGenerator.new()
			rebuilt_rng.seed = f.rng.seed
			# Regenerate the SAME layout and route: only the revision distinguishes it.
			_check(f.map.generate(rebuilt_rng) and f.map.get_floors() == owner._graph,
				"stale fixture regenerated identical real map")
			_check(f.map.choose_node(id) and f.map.get_route() == owner._route,
				"stale fixture restores identical selected route")
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
