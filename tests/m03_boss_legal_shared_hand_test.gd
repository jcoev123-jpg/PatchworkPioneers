extends SceneTree
## A fresh authored Boss fight: no run-ledger receipt, injected hand or damage.

const FIGHT_SEED := 48
const MAX_TURNS := 16
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	# Inspect the same global stream production could accidentally consume.
	seed(880088)
	var expected_global := randi()
	seed(880088)
	var first := _fight()
	var second := _fight()
	_check(randi() == expected_global, "both complete fights leave global RNG untouched")
	_check(first.to_utf8_buffer() == second.to_utf8_buffer(),
		"fresh seeded instances reproduce byte-for-byte action/turn/final snapshots")
	# Verify the global-stream sentinel itself detects an extra draw.
	seed(880088)
	randi()
	_check(randi() != expected_global, "global RNG sentinel detects an injected draw")
	_check(_normalize(1.5) == null, "fractional JSON numbers cannot be truncated")
	_test_behemoth_phase_rules()
	for failure in failures:
		printerr(failure)
	print("m03_boss_legal_shared_hand_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _normalize(value: Variant) -> Variant:
	if value is float:
		if not is_finite(value) or value != floor(value) or abs(value) >= 9223372036854775808.0:
			return null
		return int(value)
	if value is Array:
		var array: Array = []
		for entry in value:
			var normalized: Variant = _normalize(entry)
			if normalized == null:
				return null
			array.append(normalized)
		return array
	if value is Dictionary:
		var dictionary := {}
		for key in value:
			var normalized: Variant = _normalize(value[key])
			if normalized == null:
				return null
			dictionary[key] = normalized
		return dictionary
	return value


func _load_records(path: String) -> Array:
	var parsed: Variant = _normalize(JSON.parse_string(FileAccess.get_file_as_string(path)))
	_check(parsed is Array and not parsed.is_empty(), "strict authored JSON loads: " + path)
	return parsed if parsed is Array else []


func _deck_state(deck: CombatDeck) -> Array:
	# String preserves every bit of the signed 64-bit RNG state in JSON traces.
	return [deck.draw_pile.duplicate(), deck.hand.duplicate(), deck.discard_pile.duplicate(),
		deck.energy, deck.turn_active, str(deck._rng.state)]


func _snapshot(f: Dictionary) -> Array:
	return [f.party.get_heroes(), f.enemies.get_enemies(), _deck_state(f.deck),
		f.intents.get_intents(), f.intents._turn_index, f.result.get_outcome(),
		f.flow._started, f.flow._opening_block._consumed, f.attack._tinker._consumed]


func _reject(f: Dictionary, card: String, target: int, label: String) -> void:
	var before := _snapshot(f)
	var response: Dictionary = f.attack.play_attack(f.deck, f.party, f.enemies, card, target)
	_check(response == {"ok": false, "hits": []} and _snapshot(f) == before,
		label + " rejects with actors/piles/energy/status/intent/result/bonus/RNG unchanged")


func _damage(actor: Dictionary, amount: int) -> void:
	# Expected-state arithmetic only, on detached snapshots; never a live actor.
	var absorbed := mini(actor.block, amount)
	actor.block -= absorbed
	actor.hp = maxi(0, actor.hp - (amount - absorbed))


func _tick(actor: Dictionary) -> void:
	var statuses: Dictionary = actor.get("statuses", {})
	actor.hp = maxi(0, actor.hp - int(statuses.get("bleed", 0)))
	var aged := {}
	for key in statuses:
		if statuses[key] > 1:
			aged[key] = statuses[key] - 1
	if actor.has("statuses") or not aged.is_empty():
		actor.statuses = aged


func _intent(pattern: Array, turn: int) -> Array:
	var action: Dictionary = pattern[turn % pattern.size()].duplicate(true)
	action["enemy_position"] = 1
	return [action]


func _fight() -> String:
	var heroes := _load_records("res://data/heroes/starter_party.json")
	var bosses := _load_records("res://data/enemies/boss.json").filter(
		func(entry): return entry.get("id") == "patchwork_behemoth")
	var schedule := _load_records("res://data/encounters/patchwork_behemoth.json")
	var authored_deck := _load_records("res://data/cards/starter_deck.json")
	var cards: Array[String] = []
	for id in authored_deck:
		_check(id is String and not StarterCards.new().get_definition(id).is_empty(),
			"every authored deck entry resolves to a card")
		if id is String:
			cards.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = FIGHT_SEED
	var deck := CombatDeck.new(cards, rng)
	var party := CombatParty.new(heroes)
	var enemies := CombatEnemies.new(bosses)
	var intents := CombatEnemyIntents.new(schedule)
	var result := CombatBattleResult.new(party, enemies)
	var flow := CombatRoundFlow.new(deck, party, enemies, intents, result)
	var attack := CombatAttackCards.new()
	var f := {"deck": deck, "party": party, "enemies": enemies, "intents": intents,
		"result": result, "flow": flow, "attack": attack}
	var valid := party.is_valid() and enemies.is_valid() and intents.is_valid() \
		and heroes.size() == 3 and bosses.size() == 1 and schedule.size() == 1
	_check(valid, "real authored services have complete rosters and Boss schedule")
	if not valid:
		return "invalid fixture"
	_check(party.get_hero(1).id == "warden" and party.get_hero(1).hp == 40
		and party.get_hero(2).id == "seamstress" and party.get_hero(2).hp == 30
		and party.get_hero(3).id == "tinker" and party.get_hero(3).hp == 26
		and enemies.get_enemy(1).id == "patchwork_behemoth" and enemies.get_enemy(1).hp == 84,
		"authored healthy party faces actual single-phase 84-HP Behemoth")
	_check(cards == StarterCards.new().get_starting_deck(), "deck is the complete authored starting deck")
	var pattern: Array = schedule[0].pattern
	# Independent seeded deck witnesses cadence; it never controls the real hand.
	var oracle_rng := RandomNumberGenerator.new()
	oracle_rng.seed = FIGHT_SEED
	var oracle := CombatDeck.new(cards, oracle_rng)
	var expected := _snapshot(f)
	_check(flow.begin_fight() and oracle.start_turn(), "begin real fight and normal five-card hand")
	attack.start_player_turn()
	expected[0][0].block = 6
	expected[2] = _deck_state(oracle)
	expected[6] = true
	expected[7] = true
	_check(_snapshot(f) == expected and deck.hand.size() == 5 and deck.energy == 3,
		"exact opening Block, hand, energy, intents and RNG")
	var trace: Array = [["begin", _snapshot(f)]]
	var seen := {"illegal": false, "unheld": false, "energy": false,
		"prick": false, "bleed_tick": false, "bonus": 0, "second_tinker": false, "rounds": 0}
	for turn in range(MAX_TURNS):
		if not result.can_continue():
			break
		for id in deck.hand.duplicate():
			if not id in CombatAttackCards.ATTACK_IDS:
				continue
			var definition := StarterCards.new().get_definition(id)
			var target := 0 if definition.target_kind == "enemy_all" else 1
			if definition.cost > deck.energy:
				var owner_position := 3 if definition.owner == "tinker" else (2 if definition.owner == "seamstress" else 1)
				_check(deck.hand.has(id) and not party.is_downed(
					owner_position) and definition.from_positions.has(owner_position)
					and enemies.get_enemy(1).hp > 0
					and (target == 0 or definition.to_positions.has(target)),
					"insufficient-energy probe is held with living legal owner and target")
				_reject(f, id, target, "insufficient energy before victory")
				seen.energy = true
				continue
			if not seen.illegal:
				_reject(f, id, 3, "held affordable attack with illegal Boss target")
				seen.illegal = true
			if not seen.unheld:
				for missing in CombatAttackCards.ATTACK_IDS:
					if not deck.hand.has(missing):
						var missing_def := StarterCards.new().get_definition(missing)
						if missing_def.cost <= deck.energy:
							_reject(f, missing, 0 if missing_def.target_kind == "enemy_all" else 1,
								"unheld otherwise affordable and legally targeted attack")
							seen.unheld = true
							break
			var before := _snapshot(f)
			expected = before.duplicate(true)
			var owner: Dictionary = expected[0][0 if definition.owner == "warden" else (1 if definition.owner == "seamstress" else 2)]
			_check(deck.hand.has(id) and definition.from_positions.has(owner.position)
				and owner.hp > 0 and enemies.get_enemy(1).hp > 0
				and (target == 0 or definition.to_positions.has(target)), "selected held attack is legal and affordable")
			var bonus := 3 if definition.owner == "tinker" and not before[8] else 0
			var damage: int = definition.effects.damage + bonus
			if owner.get("statuses", {}).get("weak", 0) > 0:
				damage = floori(damage * 0.75)
			var boss: Dictionary = expected[1][0]
			var absorbed := mini(boss.block, damage)
			var hp_loss := mini(boss.hp, damage - absorbed)
			_damage(boss, damage)
			var applied := {}
			for status in ["bleed", "weak"]:
				if definition.effects.has(status):
					applied[status] = definition.effects[status]
					if id == "seamstress_prick" and status == "bleed":
						applied[status] += 1 # Seamstress's authored passive.
					var statuses: Dictionary = boss.get("statuses", {}).duplicate()
					statuses[status] = statuses.get(status, 0) + applied[status]
					boss.statuses = statuses
			_check(oracle.try_spend_energy(definition.cost) and oracle.discard_played(id), "oracle charges and discards exactly one held copy")
			expected[2] = _deck_state(oracle)
			if definition.owner == "tinker":
				expected[8] = true
				seen.bonus += 1 if bonus > 0 else 0
				seen.second_tinker = seen.second_tinker or bonus == 0
			seen.prick = seen.prick or id == "seamstress_prick"
			var response := attack.play_attack(deck, party, enemies, id, target)
			_check(response == {"ok": true, "hits": [{"position": 1, "damage": damage,
				"block_absorbed": absorbed, "hp_loss": hp_loss, "statuses": applied}]}
				and _snapshot(f) == expected, "exact attack state and event: turn %d %s" % [turn, id])
			expected[5] = CombatBattleResult.VICTORY if boss.hp == 0 else CombatBattleResult.ACTIVE
			_check(flow.observe_result() == expected[5] and _snapshot(f) == expected,
				"observe actual attack result without drawing or closing hand")
			trace.append(["attack", turn, id, target, response, _snapshot(f)])
			if not result.can_continue():
				break
		if not result.can_continue():
			break
		expected = _snapshot(f)
		for hero in expected[0]:
			_tick(hero)
		var action: Dictionary = _intent(pattern, turn)[0]
		var boss: Dictionary = expected[1][0]
		if action.type == "attack":
			var amount: int = action.amount
			if boss.get("statuses", {}).get("weak", 0) > 0:
				amount = floori(amount * 0.75)
			_damage(expected[0][action.target_position - 1], amount)
		elif action.type == "block":
			boss.block += action.amount
		elif action.type == "debuff":
			var hero: Dictionary = expected[0][action.target_position - 1]
			var statuses: Dictionary = hero.get("statuses", {}).duplicate()
			statuses[action.status] = statuses.get(action.status, 0) + action.amount
			hero.statuses = statuses
		seen.bleed_tick = seen.bleed_tick or boss.get("statuses", {}).get("bleed", 0) > 0
		_tick(boss)
		_check(oracle.end_turn(), "normal end discards all remaining held cards")
		if boss.hp == 0:
			expected[5] = CombatBattleResult.VICTORY
		else:
			_check(oracle.start_turn(), "next turn draws exactly five with real seeded refill")
			for hero in expected[0]:
				hero.block = 0
			expected[3] = _intent(pattern, turn + 1)
			expected[4] = turn + 1
		expected[2] = _deck_state(oracle)
		_check(flow.end_turn() and _snapshot(f) == expected,
			"exact End Turn: announced action, Block, persisted status tick, piles, energy, intents, RNG")
		seen.rounds += 1
		if result.can_continue():
			attack.start_player_turn()
			expected[8] = false
			_check(_snapshot(f) == expected, "Tinker resets only at new player-turn boundary")
		trace.append(["end", turn, _snapshot(f)])
	_check(result.get_outcome() == CombatBattleResult.VICTORY and enemies.is_victorious()
		and not party.is_defeated(), "bounded legal shared-hand sequence defeats authored Boss")
	_check(seen.illegal and seen.unheld and seen.energy and seen.prick and seen.bleed_tick
		and seen.bonus >= 2 and seen.second_tinker and seen.rounds >= 2,
		"nonvacuous rejection, persisted Prick, repeated/reset Tinker and real rounds: " + str(seen))
	var frozen := _snapshot(f)
	_check(deck.hand.has("tinker_scrap_bomb") and deck.energy == 2 and deck.turn_active
		and party.get_hero(3).hp > 0 and not attack._tinker._consumed,
		"terminal probe has held affordable target-free Bomb, legal living owner and unused bonus")
	for id in CombatAttackCards.ATTACK_IDS:
		_reject(f, id, 0 if id == "tinker_scrap_bomb" else 1, "post-victory attack")
	_check(not flow.end_turn() and not flow.begin_fight()
		and flow.observe_result() == CombatBattleResult.VICTORY and _snapshot(f) == frozen,
		"terminal result, actors, piles, energy, intents, bonus and RNG stay frozen")
	var multiset: Array = deck.draw_pile + deck.hand + deck.discard_pile
	multiset.sort()
	var original := cards.duplicate()
	original.sort()
	_check(multiset == original, "all authored copies conserved through victory")
	trace.append(["terminal", _snapshot(f), seen])
	var actions: Array = []
	var sequence: Array = []
	for event in trace:
		if event[0] == "attack":
			actions.append([event[1], event[2], event[4]])
			sequence.append([event[1], event[2]])
	_check(sequence == [[0, "warden_shield_bash"], [0, "tinker_pop_shot"],
		[1, "tinker_scrap_bomb"], [1, "seamstress_prick"], [2, "warden_strike"],
		[2, "tinker_pop_shot"], [2, "tinker_pop_shot"], [3, "tinker_scrap_bomb"],
		[3, "seamstress_prick"], [4, "warden_strike"], [4, "tinker_pop_shot"],
		[5, "warden_strike"]],
		"fixed seed witnesses the exact twelve-attack sequence over six player turns")
	print("Boss legal actions: ", JSON.stringify(actions), "; final: ", JSON.stringify(_snapshot(f)))
	return JSON.stringify(trace)


func _test_behemoth_phase_rules() -> void:
	# RNG witness: verify the selector consumes ZERO RNG
	var witness_rng := RandomNumberGenerator.new()
	witness_rng.seed = 991199
	var witness_state_before := witness_rng.state
	seed(445566)
	var global_rand_before := randi()
	seed(445566)

	# 1. Parse both real JSON sources
	var boss_path := "res://data/enemies/boss.json"
	var p2_path := "res://data/enemies/m05_behemoth_phase_two.json"
	var boss_raw_str := FileAccess.get_file_as_string(boss_path)
	var p2_raw_str := FileAccess.get_file_as_string(p2_path)
	var boss_bytes_before := boss_raw_str.to_utf8_buffer()
	var p2_bytes_before := p2_raw_str.to_utf8_buffer()

	var parsed_boss: Variant = _normalize(JSON.parse_string(boss_raw_str))
	var parsed_p2: Variant = _normalize(JSON.parse_string(p2_raw_str))

	_check(parsed_boss is Array and not parsed_boss.is_empty(), "real boss catalog parses non-empty array")
	_check(parsed_p2 is Dictionary and not parsed_p2.is_empty(), "real phase-two JSON parses non-empty dictionary")

	# Find patchwork_behemoth without assuming catalog size or ordering
	var behemoth_def: Dictionary = {}
	for entry in (parsed_boss if parsed_boss is Array else []):
		if entry is Dictionary and entry.get("id") == "patchwork_behemoth":
			behemoth_def = entry
			break

	_check(not behemoth_def.is_empty(), "shipped boss catalog contains patchwork_behemoth definition")
	_check(behemoth_def.get("max_hp") == 84, "shipped boss definition max_hp is 84")

	# Validate Phase 1 table
	var p1_intent: Dictionary = behemoth_def.get("intent", {})
	_check(p1_intent.get("target") == "front", "shipped phase-one intent target is front")
	var p1_actions: Array = p1_intent.get("actions", [])
	_check(p1_actions.size() == 3, "shipped phase-one intent has exactly 3 actions")
	var expected_p1_actions := [
		{"type": "attack", "amount": 34, "weight": 4},
		{"type": "block", "amount": 3, "weight": 2},
		{"type": "debuff", "amount": 1, "status": "weak", "weight": 1}
	]
	_check(p1_actions == expected_p1_actions, "shipped phase-one actions match attack 34 (wt 4), block 3 (wt 2), weak 1 (wt 1)")

	# Validate Phase 2 table
	var p2_dict: Dictionary = parsed_p2 if parsed_p2 is Dictionary else {}
	_check(p2_dict.get("boss_id") == "patchwork_behemoth", "phase-two record boss_id is patchwork_behemoth")
	_check(p2_dict.get("phase") == 2, "phase-two record phase is 2")
	_check(p2_dict.get("threshold_hp") == 21, "phase-two record threshold_hp is 21")
	var p2_intent: Dictionary = p2_dict.get("intent", {})
	_check(p2_intent.get("target") == "lowest_living_hp", "phase-two intent target is lowest_living_hp")
	var p2_actions: Array = p2_intent.get("actions", [])
	_check(p2_actions.size() == 3, "phase-two intent has exactly 3 actions")
	var expected_p2_actions := [
		{"type": "attack", "amount": 40, "weight": 4},
		{"type": "block", "amount": 3, "weight": 2},
		{"type": "debuff", "amount": 1, "status": "weak", "weight": 1}
	]
	_check(p2_actions == expected_p2_actions, "phase-two actions match attack 40 (wt 4), block 3 (wt 2), weak 1 (wt 1)")

	# Snapshots before any projection
	var boss_deep_before: Variant = parsed_boss.duplicate(true)
	var behemoth_deep_before: Dictionary = behemoth_def.duplicate(true)
	var p2_deep_before: Dictionary = p2_dict.duplicate(true)

	# 2. HP Probes: 42, 22, 21, 1, 0
	# HP 42 -> Phase 1
	var res42: Dictionary = CombatBehemothPhaseRules.select_phase(behemoth_def, 42, p2_dict)
	_check(res42.get("ok") == true, "HP 42 select_phase returns ok true")
	_check(res42.get("phase") == 1, "HP 42 select_phase returns phase 1")
	_check(res42.get("intent") == p1_intent, "HP 42 intent matches phase 1 intent table")
	_check(res42.get("intent").get("target") == "front", "HP 42 intent target is front")

	var full_hp := CombatBehemothPhaseRules.select_phase(behemoth_def, 84, p2_dict)
	_check(full_hp.get("ok") == true and full_hp.get("phase") == 1 and full_hp.get("intent") == p1_intent, "full 84 HP selects exact phase one")

	# HP 22 -> Phase 1
	var res22: Dictionary = CombatBehemothPhaseRules.select_phase(behemoth_def, 22, p2_dict)
	_check(res22.get("ok") == true, "HP 22 select_phase returns ok true")
	_check(res22.get("phase") == 1, "HP 22 select_phase returns phase 1")
	_check(res22.get("intent") == p1_intent, "HP 22 intent matches phase 1 intent table")
	_check(res22.get("intent").get("target") == "front", "HP 22 intent target is front")

	# HP 21 -> Phase 2
	var res21: Dictionary = CombatBehemothPhaseRules.select_phase(behemoth_def, 21, p2_dict)
	_check(res21.get("ok") == true, "HP 21 select_phase returns ok true")
	_check(res21.get("phase") == 2, "HP 21 select_phase returns phase 2")
	_check(res21.get("intent") == p2_intent, "HP 21 intent matches phase 2 intent table")
	_check(res21.get("intent").get("target") == "lowest_living_hp", "HP 21 intent target is lowest_living_hp")

	# HP 1 -> Phase 2
	var res1: Dictionary = CombatBehemothPhaseRules.select_phase(behemoth_def, 1, p2_dict)
	_check(res1.get("ok") == true, "HP 1 select_phase returns ok true")
	_check(res1.get("phase") == 2, "HP 1 select_phase returns phase 2")
	_check(res1.get("intent") == p2_intent, "HP 1 intent matches phase 2 intent table")
	_check(res1.get("intent").get("target") == "lowest_living_hp", "HP 1 intent target is lowest_living_hp")

	# HP 0 -> Dead / Fail closed
	var res0: Dictionary = CombatBehemothPhaseRules.select_phase(behemoth_def, 0, p2_dict)
	_check(res0.get("ok") == false, "HP 0 (dead) select_phase fails closed with ok false")

	# Also verify selector accepts boss catalog array directly
	var res_catalog: Dictionary = CombatBehemothPhaseRules.select_phase(parsed_boss, 21, p2_dict)
	_check(res_catalog.get("ok") == true and res_catalog.get("phase") == 2, "selector accepts full boss catalog array")

	# 3. Source deep-equality and byte-equivalence check before and after projection
	_check(parsed_boss == boss_deep_before, "parsed boss catalog deep-equal before and after projection")
	_check(behemoth_def == behemoth_deep_before, "behemoth definition deep-equal before and after projection")
	_check(p2_dict == p2_deep_before, "parsed phase-two record deep-equal before and after projection")
	_check(FileAccess.get_file_as_string(boss_path).to_utf8_buffer() == boss_bytes_before,
		"boss.json byte-identical before and after projection")
	_check(FileAccess.get_file_as_string(p2_path).to_utf8_buffer() == p2_bytes_before,
		"m05_behemoth_phase_two.json byte-identical before and after projection")

	# 4. Detached snapshot check: mutating returned nested objects does NOT alter source or future selections
	res21.get("intent").get("actions")[0]["amount"] = 999
	res21.get("intent")["target"] = "mutated_policy"
	var res21_fresh: Dictionary = CombatBehemothPhaseRules.select_phase(behemoth_def, 21, p2_dict)
	_check(res21_fresh.get("intent").get("actions")[0].get("amount") == 40, "returned intent is deep copy; fresh query attack amount is 40")
	_check(res21_fresh.get("intent").get("target") == "lowest_living_hp", "returned intent is deep copy; fresh query target is lowest_living_hp")
	_check(p2_dict.get("intent").get("actions")[0].get("amount") == 40, "source phase-two record attack amount remains 40")
	_check(p2_dict.get("intent").get("target") == "lowest_living_hp", "source phase-two record target remains lowest_living_hp")

	# 5. Negative and fail-closed tests:
	# Malformed catalog
	_check(CombatBehemothPhaseRules.select_phase([], 22, p2_dict).get("ok") == false, "empty catalog fails closed")
	_check(CombatBehemothPhaseRules.select_phase(null, 22, p2_dict).get("ok") == false, "null catalog fails closed")
	_check(CombatBehemothPhaseRules.select_phase("not_dict", 22, p2_dict).get("ok") == false, "string catalog fails closed")
	_check(CombatBehemothPhaseRules.select_phase([{"id": "other_enemy"}], 22, p2_dict).get("ok") == false, "catalog without boss fails closed")
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, 22, null).get("ok") == false, "null phase two fails closed")
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, 22, {}).get("ok") == false, "empty phase two fails closed")
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, 22, "bad").get("ok") == false, "string phase two fails closed")

	# Unknown boss
	var wrong_boss: Dictionary = behemoth_def.duplicate(true)
	wrong_boss["id"] = "unknown_boss"
	_check(CombatBehemothPhaseRules.select_phase(wrong_boss, 22, p2_dict).get("ok") == false, "wrong boss ID fails closed")
	var wrong_p2_boss: Dictionary = p2_dict.duplicate(true)
	wrong_p2_boss["boss_id"] = "wrong_boss"
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, 21, wrong_p2_boss).get("ok") == false, "wrong phase-two boss_id fails closed")

	# Wrong max_hp
	var wrong_hp_boss: Dictionary = behemoth_def.duplicate(true)
	wrong_hp_boss["max_hp"] = 50
	_check(CombatBehemothPhaseRules.select_phase(wrong_hp_boss, 22, p2_dict).get("ok") == false, "wrong boss max_hp fails closed")

	# Noninteger / out-of-range HP
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, 21.5, p2_dict).get("ok") == false, "fractional HP fails closed")
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, "21", p2_dict).get("ok") == false, "string HP fails closed")
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, null, p2_dict).get("ok") == false, "null HP fails closed")
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, -1, p2_dict).get("ok") == false, "negative HP fails closed")
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, 85, p2_dict).get("ok") == false, "HP above max 84 fails closed")
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, 100, p2_dict).get("ok") == false, "HP 100 fails closed")

	# Invalid phase / threshold
	var bad_phase: Dictionary = p2_dict.duplicate(true)
	bad_phase["phase"] = 1
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, 21, bad_phase).get("ok") == false, "phase-two phase != 2 fails closed")
	var bad_thresh: Dictionary = p2_dict.duplicate(true)
	bad_thresh["threshold_hp"] = 20
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, 21, bad_thresh).get("ok") == false, "phase-two threshold != 21 fails closed")
	var bad_thresh2: Dictionary = p2_dict.duplicate(true)
	bad_thresh2["threshold_hp"] = 42
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, 21, bad_thresh2).get("ok") == false, "phase-two threshold 42 fails closed")

	# Unsupported policy
	var bad_policy: Dictionary = p2_dict.duplicate(true)
	bad_policy["intent"]["target"] = "back"
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, 21, bad_policy).get("ok") == false, "unsupported target policy back fails closed")
	var bad_policy2: Dictionary = p2_dict.duplicate(true)
	bad_policy2["intent"]["target"] = "random"
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, 21, bad_policy2).get("ok") == false, "non-authored policy random fails closed")
	var bad_p1_policy: Dictionary = behemoth_def.duplicate(true)
	bad_p1_policy["intent"]["target"] = "lowest_living_hp"
	_check(CombatBehemothPhaseRules.select_phase(bad_p1_policy, 22, p2_dict).get("ok") == false, "phase 1 target not front fails closed")

	# Nonpositive or fractional weights
	var bad_wt0: Dictionary = p2_dict.duplicate(true)
	bad_wt0["intent"]["actions"][0]["weight"] = 0
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, 21, bad_wt0).get("ok") == false, "weight 0 fails closed")
	var bad_wtn: Dictionary = p2_dict.duplicate(true)
	bad_wtn["intent"]["actions"][0]["weight"] = -1
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, 21, bad_wtn).get("ok") == false, "negative weight fails closed")
	var bad_wtf: Dictionary = p2_dict.duplicate(true)
	bad_wtf["intent"]["actions"][0]["weight"] = 2.5
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, 21, bad_wtf).get("ok") == false, "fractional weight fails closed")

	# Invalid action / status / amount
	var bad_act: Dictionary = p2_dict.duplicate(true)
	bad_act["intent"]["actions"][0]["type"] = "heal"
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, 21, bad_act).get("ok") == false, "invalid action type heal fails closed")
	var bad_stat: Dictionary = p2_dict.duplicate(true)
	bad_stat["intent"]["actions"][2]["status"] = "poison"
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, 21, bad_stat).get("ok") == false, "invalid status poison fails closed")
	var bad_amt: Dictionary = p2_dict.duplicate(true)
	bad_amt["intent"]["actions"][0]["amount"] = -1
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, 21, bad_amt).get("ok") == false, "negative amount fails closed")
	var bad_amt2: Dictionary = p2_dict.duplicate(true)
	bad_amt2["intent"]["actions"][0]["amount"] = 5
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, 21, bad_amt2).get("ok") == false, "attack amount 5 != 40 fails closed")
	# The repaired inversion is part of the exact contract: the old phase-one
	# 40 and the old phase-two 4 are no longer accepted by either validator.
	var old_p1_amt: Dictionary = behemoth_def.duplicate(true)
	old_p1_amt["intent"]["actions"][0]["amount"] = 40
	_check(CombatBehemothPhaseRules.select_phase(old_p1_amt, 22, p2_dict).get("ok") == false, "phase-one attack amount 40 (old inverted value) fails closed")
	var wrong_p1_amt: Dictionary = behemoth_def.duplicate(true)
	wrong_p1_amt["intent"]["actions"][0]["amount"] = 33
	_check(CombatBehemothPhaseRules.select_phase(wrong_p1_amt, 22, p2_dict).get("ok") == false, "phase-one attack amount 33 != 34 fails closed")
	var old_p2_amt: Dictionary = p2_dict.duplicate(true)
	old_p2_amt["intent"]["actions"][0]["amount"] = 4
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, 21, old_p2_amt).get("ok") == false, "phase-two attack amount 4 (old inverted value) fails closed")
	var swapped_p2_amt: Dictionary = p2_dict.duplicate(true)
	swapped_p2_amt["intent"]["actions"][0]["amount"] = 34
	_check(CombatBehemothPhaseRules.select_phase(behemoth_def, 21, swapped_p2_amt).get("ok") == false, "phase-two attack amount 34 != 40 fails closed")

	# Verify sources remained unmutated after all negative probes
	_check(parsed_boss == boss_deep_before, "boss catalog unmutated after all negative probes")
	_check(behemoth_def == behemoth_deep_before, "behemoth definition unmutated after all negative probes")
	_check(p2_dict == p2_deep_before, "phase-two record unmutated after all negative probes")

	# Verify RNG witness state remained unchanged across ALL selector and probe calls
	_check(witness_rng.state == witness_state_before, "seeded RNG witness state completely unchanged across all selector calls")
	_check(randi() == global_rand_before, "global RNG state completely unchanged across all selector calls")

