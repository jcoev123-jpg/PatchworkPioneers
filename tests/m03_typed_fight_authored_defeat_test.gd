extends SceneTree
## Scene-free authored loss: only normal End Turns change the live combat.

const SEED_LIMIT := 256
const MAX_TURNS := 48
const ENCOUNTER := "double_hem_siege"
const ROSTER := ["fray_scavenger", "seam_ripper"]
const PATTERNS := [
	[
		{"type": "attack", "amount": 3, "target_position": 1},
		{"type": "block", "amount": 2},
		{"type": "attack", "amount": 2, "target_position": 3},
		{"type": "attack", "amount": 2, "target_position": 2},
	],
	[
		{"type": "attack", "amount": 3, "target_position": 1},
		{"type": "attack", "amount": 2, "target_position": 2},
		{"type": "block", "amount": 2},
		{"type": "attack", "amount": 2, "target_position": 3},
	],
]
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	seed(89003)
	var expected_global := randi()
	seed(89003)
	var choice := _find_opening()
	_check(not choice.is_empty(), "bounded seeds 1..256 select real pooled opening Double-Hem")
	if not choice.is_empty():
		var first := _replay(choice)
		var second := _replay(choice)
		_check(not first.is_empty() and first.to_utf8_buffer() == second.to_utf8_buffer(),
			"two fresh runs match complete byte-for-byte turn and settlement traces")
	_check(randi() == expected_global, "search, combat, rewards and rejections never spend global RNG")
	seed(89003)
	randi()
	_check(randi() != expected_global, "global RNG sentinel detects an extra draw")
	for failure in failures:
		printerr(failure)
	print("m03_typed_fight_authored_defeat_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _find_opening() -> Dictionary:
	for seed_value in range(1, SEED_LIMIT + 1):
		# A fresh map, run RNG and selector for every candidate; never reduce the pool.
		var rng := _rng(seed_value)
		var map := RunMap.new()
		_check(map.generate(rng), "search generates fresh seeded map")
		for id in map.get_legal_choices():
			if map.get_node(id).type != "Fight":
				continue
			_check(map.choose_node(id), "search publicly commits a legal opening Fight")
			var entry := RunAuthoredBattleEntry.new().entry_current_battle(
				map, rng, RunFightEncounterSelection.new())
			_check(entry.get("success", false), "search real full typed pool is valid")
			if entry.get("encounter_id") == ENCOUNTER:
				print("Authored defeat opening: seed=", seed_value, " node=", id)
				return {"seed": seed_value, "node": id, "graph": map.get_floors(),
					"selection_rng": str(rng.state)}
			break # Deterministically use the first legal opening Fight per seed.
	return {}


func _definitions() -> Array:
	return [{"enemy_position": 1, "pattern": PATTERNS[0].duplicate(true)},
		{"enemy_position": 2, "pattern": PATTERNS[1].duplicate(true)}]


func _announced(turn: int) -> Array:
	var actions: Array = []
	for index in range(2):
		var action: Dictionary = PATTERNS[index][turn % 4].duplicate(true)
		action.enemy_position = index + 1
		actions.append(action)
	return actions


func _deck_state(deck: CombatDeck) -> Dictionary:
	return {"draw": deck.draw_pile.duplicate(), "hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(), "energy": deck.energy,
		"active": deck.turn_active}


func _snapshot(f: Dictionary) -> Dictionary:
	return {"heroes": f.party.get_heroes(), "enemies": f.enemies.get_enemies(),
		"deck": _deck_state(f.deck), "rng": str(f.rng.state), "seed": str(f.rng.seed),
		"intents": f.intents.get_intents(), "turn": f.intents._turn_index,
		"definitions": f.intents._definitions.duplicate(true),
		"result": f.result.get_outcome(), "started": f.flow._started,
		"opening_consumed": f.flow._opening_block._consumed,
		"graph": f.map.get_floors(), "route": f.map.get_route(),
		"node": f.map.get_current_node_id(), "floor": f.map.get_current_floor(),
		"choices": f.map.get_legal_choices(), "complete": f.map.is_complete(),
		"revision": f.map.get_generation_revision(), "act": f.act.get_state(),
		"selection": f.selector._selected.duplicate(true),
		"carry": f.carry.read_state(), "rewards": f.rewards.read_state(),
		"pending_reward": f.rewards._pending != null,
		"paid_count": f.rewards._paid_battles.size()}


func _reject(f: Dictionary, action: Callable, label: String,
		expected_dictionary: Dictionary = {"ok": false}) -> void:
	var before := _snapshot(f)
	var reply: Variant = action.call()
	_check((reply is bool and not reply) or (reply is Dictionary and reply == expected_dictionary),
		label + " rejects")
	_check(_snapshot(f) == before, label + " preserves every combat/run/resource/RNG snapshot")


func _replay(choice: Dictionary) -> String:
	var rng := _rng(choice.seed)
	var map := RunMap.new()
	_check(map.generate(rng) and map.get_floors() == choice.graph, "fresh run regenerates exact graph")
	_check(map.get_legal_choices().has(choice.node) and map.choose_node(choice.node)
		and map.get_current_floor() == 1 and map.get_node(choice.node).type == "Fight",
		"replay selects the legal first-floor Fight publicly")
	var selector := RunFightEncounterSelection.new()
	var entry := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, selector)
	var valid: bool = entry.get("success", false) and entry.get("node_type") == "Fight" \
		and entry.get("encounter_id") == ENCOUNTER
	_check(valid and str(rng.state) == choice.selection_rng, "fresh full-pool selection replays encounter and RNG")
	if not valid:
		return ""
	var pool: Variant = JSON.parse_string(FileAccess.get_file_as_string(RunAuthoredBattleEntry.POOLS_PATH))
	_check(pool is Dictionary and pool.get("Fight") is Dictionary, "real typed pool parses")
	if not pool is Dictionary or not pool.get("Fight") is Dictionary:
		return ""
	_check(pool.Fight.get(ENCOUNTER) == {"schedule": "res://data/encounters/double_hem_siege.json",
		"enemy_ids": ROSTER}, "real pool binds exact authored schedule and roster")
	for id in ["starter_attacks", "bobbin_skirmish", "buttonhole_holdout", "guard_counterattack",
			"triple_spool_pinch"]:
		_check(pool.Fight.has(id), "selection retains other real Fight candidate " + id)
	_check(entry.definitions == _definitions(), "both complete four-beat authored schedules match")
	var heroes: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))
	_check(heroes is Array and heroes.size() == 3, "three real authored hero definitions load")
	if not heroes is Array or heroes.size() != 3:
		return ""
	for hero in heroes:
		_check(RunFightEncounterSelection._coerce_integral_field(hero, "max_hp"), "authored HP is integral")
	var party := CombatParty.new(heroes)
	var raw_cards: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/starter_deck.json"))
	_check(raw_cards is Array and raw_cards == StarterCards.new().get_starting_deck()
		and raw_cards.size() == 12, "actual twelve-copy shared starter deck loads")
	if not raw_cards is Array:
		return ""
	var cards: Array[String] = []
	cards.assign(raw_cards)
	for id in cards:
		_check(not StarterCards.new().get_definition(id).is_empty(), "authored card resolves: " + id)
	# A separate expected-pile witness starts at the post-map/selection RNG state.
	# It never supplies the live hand or changes the run's sole RNG.
	var oracle_rng := _rng(choice.seed)
	oracle_rng.state = rng.state
	var oracle := CombatDeck.new(cards, oracle_rng)
	var deck := CombatDeck.new(cards, rng)
	var enemies: CombatEnemies = entry.enemies
	var intents: CombatEnemyIntents = entry.intents
	var result := CombatBattleResult.new(party, enemies)
	var flow := CombatRoundFlow.new(deck, party, enemies, intents, result)
	var carry := RunPartyCarryover.new(party.get_heroes())
	var rewards := RunMultiFightRewards.new(map, rng, carry, cards, 0, [],
		StarterCards.new().get_all_card_ids())
	var act := RunActBattleOutcome.new(map)
	var f := {"rng": rng, "map": map, "selector": selector, "party": party,
		"enemies": enemies, "intents": intents, "deck": deck, "result": result,
		"flow": flow, "carry": carry, "rewards": rewards, "act": act}
	valid = party.is_valid() and enemies.is_valid() and intents.is_valid() and carry.is_valid()
	_check(valid and enemies.get_enemies().size() == 2, "valid real services and two-enemy roster")
	if not valid or enemies.get_enemies().size() != 2:
		return ""
	for index in range(3):
		var hero := party.get_hero(index + 1)
		_check(hero.id == ["warden", "seamstress", "tinker"][index]
			and hero.hp == [40, 30, 26][index] and hero.max_hp == hero.hp
			and hero.block == 0 and hero.position == index + 1, "healthy authored hero in original slot")
	# Replay the public selector and floor-band draws without consulting the entry service.
	var band_rng := _rng(choice.seed)
	var band_map := RunMap.new()
	_check(band_map.generate(band_rng) and band_map.choose_node(choice.node),
		"independent seeded route commits the same Fight for floor-band sampling")
	var encounter_ids: Array = pool.Fight.keys()
	encounter_ids.sort()
	_check(encounter_ids[band_rng.randi_range(0, encounter_ids.size() - 1)] == ENCOUNTER,
		"independent sorted selector retains Double-Hem encounter binding")
	var group: Array = preload("res://tests/floor_band_oracle.gd").group(
		band_map.get_current_floor(), 2, band_rng)
	var normal_records: Dictionary = preload("res://tests/floor_band_oracle.gd").records()
	_check(group.size() == 2 and preload("res://tests/floor_band_oracle.gd").legal_group(
		group, 1) and str(band_rng.state) == choice.selection_rng,
		"two legal independent band draws reproduce full entry RNG state")
	for index in range(2):
		var enemy := enemies.get_enemy(index + 1)
		_check(enemy.id == group[index] and enemy.hp == int(normal_records[group[index]].max_hp)
			and enemy.name == normal_records[group[index]].name
			and enemy.max_hp == enemy.hp and enemy.block == 0
			and enemy.position == index + 1, "exact living band-selected source with authored record")
	_check(result.get_outcome() == CombatBattleResult.ACTIVE and act.begin_current_battle(result),
		"bind selected opening node to actual ACTIVE result")
	var expected := _snapshot(f)
	_check(flow.begin_fight() and oracle.start_turn(), "normal begin_fight deals first hand")
	expected.heroes[0].block = 6
	expected.deck = _deck_state(oracle)
	expected.rng = str(oracle_rng.state)
	expected.started = true
	expected.opening_consumed = true
	_check(_snapshot(f) == expected and deck.hand.size() == 5 and deck.energy == 3,
		"exact opening Warden Block, untouched HP, announced sources, seeded hand and energy")
	var trace: Array = [["begin", _snapshot(f)]]
	var completed := 0
	var declining := [false, false, false]
	var downed_at := [0, 0, 0]
	while result.can_continue() and completed < MAX_TURNS:
		var turn := completed
		_reject(f, func(): return act.settle_current_battle(), "ACTIVE turn cannot settle")
		_reject(f, func(): return rewards.prepare(choice.node, result, party), "ACTIVE turn cannot prepare Fight payout")
		var before := _snapshot(f)
		_check(before.intents == _announced(turn) and before.turn == turn,
			"both source announcements match full cyclic schedule before execution")
		_check(deck.hand.size() == 5 and deck.energy == 3 and deck.turn_active,
			"each normal player turn holds five unplayed cards and unspent energy")
		expected = before.duplicate(true)
		# Expected arithmetic touches detached snapshots only, never live HP or intents.
		for action in _announced(turn):
			if action.type == "block":
				expected.enemies[action.enemy_position - 1].block += action.amount
			else:
				var hero: Dictionary = expected.heroes[action.target_position - 1]
				var absorbed := mini(hero.block, action.amount)
				hero.block -= absorbed
				hero.hp = maxi(0, hero.hp - (action.amount - absorbed))
		var defeated: bool = expected.heroes.all(func(hero: Dictionary) -> bool: return hero.hp == 0)
		_check(oracle.end_turn(), "expected piles discard the entire unplayed hand in order")
		if defeated:
			expected.result = CombatBattleResult.DEFEAT
		else:
			for hero in expected.heroes:
				hero.block = 0
			expected.intents = _announced(turn + 1)
			expected.turn = turn + 1
			_check(oracle.start_turn(), "expected next hand uses normal seeded draw/refill")
		expected.deck = _deck_state(oracle)
		expected.rng = str(oracle_rng.state)
		var advanced := flow.end_turn()
		_check(advanced and _snapshot(f) == expected,
			"End Turn %d exactly matches HP/Block, piles, energy, announcements, outcome, route and RNG" % (turn + 1))
		if not advanced:
			return ""
		completed += 1
		for index in range(3):
			var hp: int = party.get_hero(index + 1).hp
			declining[index] = declining[index] or hp < before.heroes[index].hp
			if hp == 0 and downed_at[index] == 0:
				downed_at[index] = completed
		var conserved: Array = deck.draw_pile + deck.hand + deck.discard_pile
		conserved.sort()
		var original := cards.duplicate()
		original.sort()
		_check(conserved == original, "every authored card copy conserved without playing or resetting piles")
		_check(flow.observe_result() == expected.result and _snapshot(f) == expected,
			"public observation is read-only after actual enemy turn")
		trace.append(["end", completed, before, _snapshot(f)])
	_check(completed == 30 and completed <= MAX_TURNS and declining == [true, true, true]
		and downed_at == [29, 30, 27], "all original slots decline and fall on authored turns 29/30/27")
	_check(result.get_outcome() == CombatBattleResult.DEFEAT and party.is_defeated()
		and not enemies.is_victorious() and deck.hand.is_empty() and not deck.turn_active
		and deck.energy == 0, "ordinary enemy turns witness all-downed DEFEAT without a terminal draw")
	_check(act.get_state() == {"run_status": "ACTIVE", "pending_node_id": choice.node,
		"settled_node_ids": []}, "combat observation alone never settles run")
	expected = _snapshot(f)
	_check(act.settle_current_battle(), "settle the witnessed actual defeat exactly once")
	expected.act = {"run_status": "DEFEAT", "pending_node_id": "", "settled_node_ids": [choice.node]}
	_check(_snapshot(f) == expected, "settlement changes only run outcome and witnessed-node latch")
	var fresh := CombatBattleResult.new(CombatParty.new(heroes), enemies)
	_check(fresh.get_outcome() == CombatBattleResult.ACTIVE and not map.get_legal_choices().is_empty(),
		"continuation probe has a valid ACTIVE result and connected future nodes")
	for attempt in range(2):
		_reject(f, func(): return act.settle_current_battle(), "repeated defeat settlement")
		_reject(f, func(): return act.begin_current_battle(fresh), "terminal run refuses another battle")
		_reject(f, func(): return flow.end_turn(), "post-terminal End Turn")
		_reject(f, func(): return flow.begin_fight(), "post-terminal restart")
		_reject(f, func(): return rewards.prepare(choice.node, result, party), "defeat Fight reward preparation")
		_reject(f, func(): return rewards.choose(choice.node, ""), "defeat cannot skip into payout")
		_reject(f, func(): return carry.commit_victory(choice.node, result, party),
			"defeat cannot commit winning carryover", {"ok": false, "heroes": []})
	_check(rewards.read_state().gold == 0 and rewards.read_state().deck == cards
		and rewards.read_state().trinkets.is_empty() and carry.read_state().completed_fights.is_empty()
		and map.get_route() == [choice.node] and not map.is_complete(),
		"no gold/card/trinket payout, survivor commit or route continuation after loss")
	trace.append(["terminal", completed, downed_at, _snapshot(f)])
	print("Authored defeat: ", completed, " End Turns; downed slots=", downed_at,
		"; HP=", party.get_heroes().map(func(hero: Dictionary) -> int: return hero.hp))
	return JSON.stringify(trace)
