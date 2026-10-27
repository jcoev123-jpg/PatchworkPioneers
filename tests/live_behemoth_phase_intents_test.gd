extends SceneTree
## Runs the real floor-12 Boss entry's selector and CombatEnemyPhase against
## canonical actor models. No substitute scheduler, UI text or edited JSON.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_real_boss_threshold()
	_test_locked_phase_one_attack()
	_test_phase_two_actions()
	_test_seeded_replay()
	_test_round_phase_crossing()
	_test_round_unravel_action_kinds()
	_test_round_bleed_delayed_skip()
	_test_round_down_target_fallback()
	_test_round_rejections_and_replay()
	_test_quilt_phases()
	for failure in failures:
		printerr(failure)
	print("live_behemoth_phase_intents_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _start_boss(seed_value: int, with_round_flow := false, tier: int = 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := RunMap.new()
	if not map.generate(rng):
		return {}
	for floor_index in range(RunMap.FLOOR_COUNT):
		var choices := map.get_legal_choices()
		if choices.is_empty() or not map.choose_node(choices[0]):
			return {}
	if map.get_current_floor() != RunMap.FLOOR_COUNT \
			or map.get_node(map.get_current_node_id()).get("type") != "Boss":
		return {}
	# Real RunAuthoredBattleEntry (not an injected roster/schedule).
	var entry := RunAuthoredBattleEntry.new().entry_current_battle(
		map, rng, RunFightEncounterSelection.new())
	if not entry.get("success", false) or entry.get("node_type") != "Boss" \
			or entry.get("encounter_id") != "patchwork_behemoth":
		return {}
	var heroes: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/heroes/starter_party.json"))
	if not heroes is Array or heroes.size() != 3:
		return {}
	for hero in heroes:
		hero["max_hp"] = int(hero["max_hp"])
	var party := CombatParty.new(heroes)
	var enemies: CombatEnemies = entry.enemies
	var difficulty := RunDifficulty.new()
	if not difficulty.restore_state({"selected_tier": tier, "highest_cleared_tier": tier - 1}):
		return {}
	if tier > 0:
		enemies = CombatEnemies.new(difficulty.scale_definitions(enemies.get_enemies()))
	var selector: CombatEnemyIntents = entry.intents
	# Genuine rounds shuffle the shared deck before the first weighted draw.
	var deck: CombatDeck = null
	if with_round_flow:
		deck = CombatDeck.new(StarterCards.new().get_starting_deck(), rng)
	if not party.is_valid() or not enemies.is_valid() \
			or enemies.get_enemy(1).get("id") != "patchwork_behemoth" \
			or enemies.get_enemy(1).get("hp") != 84 + int(ceil(84 * [0, 10, 20][tier] / 100.0)) \
			or not selector.bind_battle(enemies, party, rng, difficulty):
		return {}
	var battle := {"map": map, "rng": rng, "party": party,
		"enemies": enemies, "intents": selector}
	if with_round_flow:
		var gauge := CombatUnravel.new()
		if not gauge.bind_roster(enemies, {1: "boss"}):
			return {}
		var result := CombatBattleResult.new(party, enemies)
		battle["deck"] = deck
		battle["unravel"] = gauge
		battle["result"] = result
		battle["flow"] = CombatRoundFlow.new(deck, party, enemies, selector,
			result, gauge)
	return battle


func _test_quilt_phases() -> void:
	for tier in [0, 1, 2]:
		var battle := _start_boss(184006, false, tier)
		var replay := _start_boss(184006, false, tier)
		_check(not battle.is_empty() and not replay.is_empty(), "earned tier binds genuine routed Boss: %d" % tier)
		if battle.is_empty() or replay.is_empty():
			continue
		var baseline := _start_boss(184006)
		_check(battle.rng.state == baseline.rng.state, "tier bonuses add no Boss RNG draws")
		for intent in battle.enemies.get_enemy(1).intent.actions:
			if intent.type == "attack":
				_check(intent.amount == 34 + tier, "phase one adds the tier exactly once")
		for current in [battle, replay]:
			var hp: int = current.enemies.get_enemy(1).hp
			_check(current.enemies.apply_damage(1, hp - 21) and current.intents.advance_turn(),
				"scaled Boss crosses authored phase threshold through real enemy state")
		_check(battle.rng.state == replay.rng.state and battle.intents.get_intents() == replay.intents.get_intents(),
			"same tier and seed reproduce phase-two announcement and RNG")
		var maximum: int = battle.enemies.get_enemy(1).max_hp
		for turn in range(3):
			for intent in battle.enemies.get_enemy(1).intent.actions:
				if intent.type == "attack":
					_check(intent.amount == 40 + tier, "phase two retains exactly one bonus across turns")
			_check(battle.enemies.get_enemy(1).max_hp == maximum and battle.intents.advance_turn(),
				"phase changes and repeated announcements never scale HP again")


func _hurt_to_phase_two(battle: Dictionary) -> bool:
	var enemies: CombatEnemies = battle.enemies
	return enemies.apply_damage(1, 63) and enemies.get_enemy(1).hp == 21 \
		and battle.intents.advance_turn()


func _test_real_boss_threshold() -> void:
	var battle := _start_boss(184006)
	_check(not battle.is_empty(), "floor-12 route selects authentic Boss and binds live selector")
	if battle.is_empty():
		return
	var rng: RandomNumberGenerator = battle.rng
	var enemies: CombatEnemies = battle.enemies
	var selector: CombatEnemyIntents = battle.intents
	_check(battle.map.get_route().size() == 12
		and selector.is_bound() and selector._boss_slot == 1
		and enemies.get_enemy(1).max_hp == 84,
		"real selected Boss keeps one authentic enemy slot and 84 HP")
	_check(selector._slots[0].target == "front"
		and selector._slots[0].actions[0].action.amount == 34,
		"initial first-phase action/policy are authored")
	var announced := selector.get_intents()
	var rng_before := rng.state
	_check(enemies.apply_damage(1, 62) and enemies.get_enemy(1).hp == 22
		and selector.get_intents() == announced and rng.state == rng_before,
		"damage to 22 does not refresh an already announced action")
	_check(selector.advance_turn() and selector._slots[0].target == "front",
		"next roll at 22 stays phase one")
	announced = selector.get_intents()
	rng_before = rng.state
	_check(enemies.apply_damage(1, 1) and enemies.get_enemy(1).hp == 21
		and announced == selector.get_intents() and rng_before == rng.state
		and CombatEnemyIntents.policy_for(enemies, 1) == "front",
		"crossing to 21 locks current announcement, RNG and front policy")
	_check(selector.advance_turn() and selector._slots[0].target == "lowest_living_hp"
		and selector._slots[0].actions[0].action.amount == 40
		and CombatEnemyIntents.policy_for(enemies, 1) == "lowest_living_hp",
		"next real Boss roll publishes phase-two amount and policy together")
	announced = selector.get_intents()
	rng_before = rng.state
	_check(announced == selector.get_intents() and rng_before == rng.state,
		"repeated live read is detached and RNG-stable")


## Find a fixed seeded run whose genuine weighted next roll announces each
## particular authored action. The action is then executed by the production
## executor with no test-only modifications to the weighted catalog.
func _seeded_phase_action(kind: String) -> Dictionary:
	for seed_value in range(1, 130):
		var battle := _start_boss(seed_value)
		if battle.is_empty():
			return {}
		var party: CombatParty = battle.party
		if not party.apply_damage(1, 32) or not party.apply_damage(2, 25) \
				or not party.apply_damage(3, 18):
			return {}
		if not _hurt_to_phase_two(battle):
			return {}
		var announcement: Array[Dictionary] = battle.intents.get_intents()
		if announcement.size() == 1 and announcement[0].get("type") == kind:
			battle["seed"] = seed_value
			return battle
	return {}


func _test_phase_two_actions() -> void:
	var attack := _seeded_phase_action("attack")
	var block := _seeded_phase_action("block")
	var weak := _seeded_phase_action("debuff")
	_check(not attack.is_empty() and not block.is_empty() and not weak.is_empty(),
		"real Boss seeded phase-two announcements include attack, Block and Weak")
	if attack.is_empty() or block.is_empty() or weak.is_empty():
		return
	for battle in [attack, block, weak]:
		_check(battle.enemies.get_enemy(1).hp == 21
			and battle.intents._boss_phase == 2
			and CombatEnemyIntents.policy_for(battle.enemies, 1) == "lowest_living_hp",
			"each seeded real Boss encounter is committed to phase two")
	var intent: Dictionary = attack.intents.get_intents()[0]
	_check(intent == {"type": "attack", "amount": 40, "enemy_position": 1,
			"target_position": 2},
		"phase-two attack announces exactly 40 against lowest-HP hero 2")
	var party: CombatParty = attack.party
	_check(party.gain_block(2, 2), "target gains real Block 2 before attack")
	var result := CombatEnemyPhase.new().execute_phase(
		party, attack.enemies, attack.intents.get_intents(), null, true)
	_check(result.get("ok", false) and result.events.size() == 1
		and result.events[0].applied and result.events[0].target_position == 2,
		"cached phase-two attack executes through CombatEnemyPhase")
	_check(party.get_hero(2).hp == 0 and party.get_hero(2).block == 0
		and party.get_hero(1).hp == 8 and party.get_hero(3).hp == 8,
		"40 damage consumes 2 Block then downs announced hero 2 and spares untargeted heroes")
	# The announced target can fall during the player turn. Tied fallback HP
	# chooses front position 1 over back position 3 (both at 8).
	var fallback := _seeded_phase_action("attack")
	_check(not fallback.is_empty(), "identical seeded attack replay exists for fallback")
	if not fallback.is_empty():
		var target: CombatParty = fallback.party
		var before: Array[Dictionary] = fallback.intents.get_intents()
		_check(target.apply_damage(2, 5) and target.is_downed(2)
			and before == fallback.intents.get_intents(),
			"announced hero 2 goes down without rerolling")
		var fallback_result := CombatEnemyPhase.new().execute_phase(
			target, fallback.enemies, before, null, true)
		_check(fallback_result.get("ok", false)
			and fallback_result.events[0].target_position == 1
			and fallback_result.events[0].applied
			and target.get_hero(1).hp == 0 and target.get_hero(3).hp == 8,
			"lowest-living-HP fallback chooses tied front hero and deals cached 40")
	var block_intent: Dictionary = block.intents.get_intents()[0]
	_check(block_intent == {"type": "block", "amount": 3, "enemy_position": 1},
		"phase-two Block 3 has no hero target")
	var blocked := CombatEnemyPhase.new().execute_phase(
		block.party, block.enemies, block.intents.get_intents(), null, true)
	_check(blocked.get("ok", false) and blocked.events[0].applied
		and block.enemies.get_enemy(1).block == 3,
		"authored Block 3 resolves on real boss actor")
	_check(block.enemies.apply_damage(1, 2) and block.enemies.get_enemy(1).hp == 21
		and block.enemies.get_enemy(1).block == 1,
		"Block absorbs damage without retriggering HP threshold")
	var weak_intent: Dictionary = weak.intents.get_intents()[0]
	_check(weak_intent == {"type": "debuff", "amount": 1, "status": "weak",
			"target_position": 2, "enemy_position": 1},
		"phase-two Weak 1 targets lowest living HP hero")
	var debuffed := CombatEnemyPhase.new().execute_phase(
		weak.party, weak.enemies, weak.intents.get_intents(), null, true)
	_check(debuffed.get("ok", false) and debuffed.events[0].applied
		and weak.party.get_hero(2).get("statuses", {}).get("weak", 0) == 1,
		"authored Weak 1 resolves using real special-action/status service")


func _replay(seed_value: int) -> Array:
	var battle := _start_boss(seed_value)
	if battle.is_empty() or not _hurt_to_phase_two(battle):
		return []
	var result: Array = []
	var selector: CombatEnemyIntents = battle.intents
	var party: CombatParty = battle.party
	var enemies: CombatEnemies = battle.enemies
	for turn in range(8):
		var announced := selector.get_intents()
		var rng_before: int = battle.rng.state
		var copied := selector.get_intents()
		if copied.is_empty():
			return []
		copied[0]["amount"] = 999
		if selector.get_intents() != announced or battle.rng.state != rng_before:
			return []
		var resolved := CombatEnemyPhase.new().execute_phase(
			party, enemies, announced, null, true)
		if not resolved.get("ok", false):
			return []
		result.append({"intent": announced, "events": resolved.events,
			"heroes": party.get_heroes(), "enemies": enemies.get_enemies(),
			"rng_before": rng_before, "rng_after": battle.rng.state})
		# Phase-two attacks hit for more than any hero's maximum HP, so the
		# authentic fight ends once the third attack downs the last hero and
		# there is no living target for a following announcement.
		if party.is_defeated():
			break
		if not selector.advance_turn():
			return []
		result.append({"next": selector.get_intents(), "rng": battle.rng.state})
	return result


func _test_seeded_replay() -> void:
	var first := _replay(188421)
	var second := _replay(188421)
	_check(first.size() == 7 and first == second,
		"two genuine identically seeded Boss battles replay seven ordered action/outcome/RNG traces to authentic defeat")
	if first.size() == 7:
		_check(first[0].intent[0].enemy_position == 1
			and first[0].enemies[0].hp == 21
			and first[0].events.size() == 1,
			"replay trace actually exercises original Boss slot at phase-two HP")
		var downed := true
		for hero in first[6].heroes:
			downed = downed and hero.hp == 0
		_check(downed and first[6].events[0].applied
			and first[1].rng != first[0].rng_after
			and first[3].rng != first[2].rng_after
			and first[5].rng != first[4].rng_after
			and first[2].rng_before == first[1].rng
			and first[4].rng_before == first[3].rng
			and first[6].rng_before == first[5].rng,
			"revised phase-two attacks end the party with exactly one weighted draw per committed turn")


func _test_locked_phase_one_attack() -> void:
	var battle: Dictionary = {}
	for seed_value in range(1, 65):
		var candidate := _start_boss(seed_value)
		if candidate.is_empty():
			break
		var intent: Array[Dictionary] = candidate.intents.get_intents()
		if intent.size() == 1 and intent[0].get("type") == "attack":
			battle = candidate
			break
	_check(not battle.is_empty(), "seeded real Boss initially announces a phase-one attack")
	if battle.is_empty():
		return
	var party: CombatParty = battle.party
	var enemies: CombatEnemies = battle.enemies
	var selector: CombatEnemyIntents = battle.intents
	var locked := selector.get_intents()
	var state_before: int = battle.rng.state
	_check(locked[0] == {"type": "attack", "amount": 34,
			"enemy_position": 1, "target_position": 1},
		"phase-one attack commits exact authored 34 damage to front")
	_check(enemies.apply_damage(1, 63) and enemies.get_enemy(1).hp == 21
		and selector.get_intents() == locked and battle.rng.state == state_before
		and CombatEnemyIntents.policy_for(enemies, 1) == "front",
		"crossing the threshold mid-player-turn keeps old action and fallback policy")
	var executed := CombatEnemyPhase.new().execute_phase(
		party, enemies, locked, null, true)
	_check(executed.get("ok", false) and executed.events[0].target_position == 1
		and executed.events[0].applied and party.get_hero(1).hp == 6
		and party.get_hero(3).hp == 26,
		"old front attack really executes for 34 despite boss now at 21 HP")
	_check(selector.advance_turn()
		and selector._slots[0].actions[0].action.amount == 40
		and CombatEnemyIntents.policy_for(enemies, 1) == "lowest_living_hp",
		"following announcement (only) upgrades the actual attack/policy")


## These round fixtures extend the routed floor-12 admission above. They keep
## its one real Boss slot, the same run RNG for deck and weighted scheduler,
## and a Boss-tier CombatUnravel bound to that *same* CombatEnemies instance.
func _round_boss_with_action(kind: String) -> Dictionary:
	for seed_value in range(1, 160):
		var battle := _start_boss(seed_value, true)
		if battle.is_empty():
			return {}
		var announced: Array[Dictionary] = battle.intents.get_intents()
		if announced.size() == 1 and announced[0].get("type") == kind:
			battle["seed"] = seed_value
			return battle
	return {}


func _round_snapshot(battle: Dictionary) -> Dictionary:
	var deck: CombatDeck = battle.deck
	var intents: CombatEnemyIntents = battle.intents
	return {
		"heroes": battle.party.get_heroes(),
		"enemies": battle.enemies.get_enemies(),
		"hand": deck.hand.duplicate(true),
		"draw": deck.draw_pile.duplicate(true),
		"discard": deck.discard_pile.duplicate(true),
		"energy": deck.energy, "active": deck.turn_active,
		"rng": battle.rng.state, "announced": intents.get_intents(),
		"phase": intents._boss_phase, "slots": intents._slots.duplicate(true),
		"turn_index": intents._turn_index,
		"unravel": battle.unravel.get_snapshot(1),
		"outcome": battle.result.get_outcome(),
		"started": battle.flow._started
	}


## Independent weighted oracle: the authored phase selector supplies the
## genuine JSON actions/weights. A COPY of the live pre-advance RNG state
## makes exactly one legitimate 1..total weighted draw. No guessed action.
func _next_phase_two_oracle(battle: Dictionary, rng_state: int) -> Dictionary:
	var choice := CombatBehemothPhaseRules.select_phase(
		battle.intents._boss_definition, 21, battle.intents._phase_two_record)
	if not choice.get("ok", false) or choice.get("phase") != 2:
		return {}
	var weighted := CombatEnemyIntents._weighted_slot(1, choice.intent)
	if weighted.is_empty() or weighted.target != "lowest_living_hp":
		return {}
	var total := 0
	for entry in weighted.actions:
		total += int(entry.weight)
	var oracle_rng := RandomNumberGenerator.new()
	oracle_rng.state = rng_state
	var roll := oracle_rng.randi_range(1, total)
	var action: Dictionary = {}
	for entry in weighted.actions:
		roll -= int(entry.weight)
		if roll <= 0:
			action = entry.action.duplicate(true)
			break
	if action.is_empty():
		return {}
	action["enemy_position"] = 1
	if action.type in ["attack", "debuff", "shove"]:
		action["target_position"] = CombatEnemyIntents.priority_target(
			battle.party, weighted.target)
	return {"intent": action, "rng": oracle_rng.state}


func _test_round_phase_crossing() -> void:
	var battle := _round_boss_with_action("attack")
	_check(not battle.is_empty(), "real floor-12 round admits a seeded phase-one attack")
	if battle.is_empty():
		return
	var flow: CombatRoundFlow = battle.flow
	var deck: CombatDeck = battle.deck
	var party: CombatParty = battle.party
	var enemies: CombatEnemies = battle.enemies
	var intents: CombatEnemyIntents = battle.intents
	_check(battle.map.get_current_floor() == 12 and intents.is_bound()
		and intents._boss_slot == 1 and battle.unravel._bound_enemies == enemies
		and battle.unravel.get_snapshot(1).threshold == 16
		and deck._rng == battle.rng and enemies.get_enemy(1).max_hp == 84
		and party.get_hero(1).max_hp == 40 and party.get_hero(2).max_hp == 30
		and party.get_hero(3).max_hp == 26,
		"round uses authentic boss, three original heroes, shared RNG and Boss gauge")
	_check(flow.begin_fight() and deck.turn_active and deck.energy == 3
		and deck.hand.size() == 5 and deck.draw_pile.size() >= 5
		and party.get_hero(1).block == 6,
		"real active first hand is opened before the threshold crossing")
	var locked := intents.get_intents()
	_check(locked.size() == 1 and locked[0] == {"type": "attack", "amount": 34,
		"enemy_position": 1, "target_position": 1}
		and intents._boss_phase == 1 and CombatEnemyIntents.policy_for(enemies, 1) == "front",
		"bound phase-one attack is already committed against front Warden")
	var state: int = battle.rng.state
	_check(enemies.apply_damage(1, 62) and enemies.get_enemy(1).hp == 22
		and intents.get_intents() == locked and battle.rng.state == state,
		"at 22 HP the real battle keeps its phase-one announcement")
	_check(enemies.apply_damage(1, 1) and enemies.get_enemy(1).hp == 21
		and party.apply_damage(1, 6) and party.get_hero(1).block == 0
		and party.apply_damage(2, 16) and party.get_hero(2).hp == 14
		and intents.get_intents() == locked and intents._boss_phase == 1
		and CombatEnemyIntents.policy_for(enemies, 1) == "front"
		and battle.rng.state == state,
		"22-to-21 player-turn change leaves bound action, policy and RNG untouched")
	var oracle := _next_phase_two_oracle(battle, state)
	_check(not oracle.is_empty() and oracle.intent.get("enemy_position") == 1
		and (not oracle.intent.has("target_position") or oracle.intent.target_position == 2),
		"authored phase-two weighted oracle targets the lowest living HP hero")
	_check(flow.end_turn(), "real round commits previously announced phase-one attack")
	_check(party.get_hero(1).hp == 6 and party.get_hero(2).hp == 14
		and enemies.get_enemy(1).hp == 21 and battle.unravel.get_snapshot(1).gauge == 0,
		"old 34-damage front attack executes despite the Boss being at 21")
	# The same pre-advance RNG state reproduces the one weighted draw, now
	# resolved against the party as it stands after the committed attack.
	var next_oracle := _next_phase_two_oracle(battle, state)
	_check(intents._boss_phase == 2 and intents._slots[0].target == "lowest_living_hp"
		and CombatEnemyIntents.policy_for(enemies, 1) == "lowest_living_hp"
		and not next_oracle.is_empty()
		and intents.get_intents() == [next_oracle.get("intent")]
		and battle.rng.state == next_oracle.get("rng")
		and intents.get_intents()[0].get("target_position", 1) == 1,
		"only successful advance draws genuine phase-two action once against lowest living HP")
	var before := _round_snapshot(battle)
	var detached := intents.get_intents()
	detached[0]["amount"] = 999
	_check(_round_snapshot(battle) == before and intents.get_intents() == before.announced,
		"repeated phase-two inspection neither spends RNG nor mutates cached intent")


func _test_round_unravel_action_kinds() -> void:
	for kind in ["attack", "block", "debuff"]:
		var battle := _round_boss_with_action(kind)
		_check(not battle.is_empty(), "routed Boss yields a genuine phase-one " + kind)
		if battle.is_empty():
			continue
		var flow: CombatRoundFlow = battle.flow
		var party: CombatParty = battle.party
		var enemies: CombatEnemies = battle.enemies
		var intents: CombatEnemyIntents = battle.intents
		var gauge: CombatUnravel = battle.unravel
		_check(flow.begin_fight() and party.apply_damage(2, 16)
			and enemies.apply_damage(1, 63) and enemies.get_enemy(1).hp == 21
			and gauge.apply_unravel(enemies, 1, 16),
			"active Boss turn crosses phase and reaches the 16-gauge break: " + kind)
		var locked := intents.get_intents()
		var snapshot := gauge.get_snapshot(1)
		var heroes_before := party.get_heroes()
		var enemy_before := enemies.get_enemy(1)
		var rng_before: int = battle.rng.state
		var oracle := _next_phase_two_oracle(battle, rng_before)
		_check(locked.size() == 1 and locked[0].type == kind
			and intents._boss_phase == 1 and snapshot == {"gauge": 16,
				"threshold": 16, "unravelled": true, "skip_pending": true}
			and not oracle.is_empty(), "phase-one " + kind + " is locked with one pending skip")
		_check(flow.end_turn(), "Boss skips its real announced " + kind + " exactly once")
		_check(party.get_hero(1).hp == heroes_before[0].hp
			and party.get_hero(2).hp == heroes_before[1].hp
			and party.get_hero(3).hp == heroes_before[2].hp
			and party.get_hero(1).get("statuses", {}) == heroes_before[0].get("statuses", {})
			and enemies.get_enemy(1).block == enemy_before.block
			and enemies.get_enemy(1).hp == enemy_before.hp,
			"skipped " + kind + " causes no attack, Block or Weak action effect")
		_check(gauge.get_snapshot(1) == {"gauge": 0, "threshold": 20,
				"unravelled": false, "skip_pending": false}
			and intents._boss_phase == 2 and intents._slots[0].target == "lowest_living_hp"
			and intents.get_intents() == [oracle.get("intent")]
			and battle.rng.state == oracle.get("rng"),
			"skipped " + kind + " consumes break then draws exactly one phase-two intent")
		# Execute the next real announcement independently on detached actors,
		# then prove the live next turn does not silently skip again.
		var expected_party := CombatParty.new(party.get_heroes())
		expected_party._heroes.assign(party.get_heroes())
		var expected_enemies := CombatEnemies.new(enemies.get_enemies())
		expected_enemies._enemies.assign(enemies.get_enemies())
		var resolved := CombatEnemyPhase.new().execute_phase(
			expected_party, expected_enemies, intents.get_intents(), null, true)
		_check(resolved.get("ok", false) and resolved.events.size() == 1
			and resolved.events[0].applied, "next phase-two " + kind + " is genuinely executable")
		_check(flow.end_turn(), "Boss acts on turn after skipped " + kind)
		var actual_heroes := party.get_heroes()
		var predicted_heroes := expected_party.get_heroes()
		var equivalent := true
		for slot in range(3):
			equivalent = equivalent and actual_heroes[slot].hp == predicted_heroes[slot].hp
			equivalent = equivalent and actual_heroes[slot].get("statuses", {}) == predicted_heroes[slot].get("statuses", {})
		_check(equivalent and enemies.get_enemy(1).block == expected_enemies.get_enemy(1).block
			and gauge.get_snapshot(1).gauge == 0 and gauge.get_snapshot(1).threshold == 20
			and not gauge.get_snapshot(1).skip_pending,
			"following phase-two action executes once; no phantom second skip: " + kind)


func _test_round_bleed_delayed_skip() -> void:
	var battle := _round_boss_with_action("attack")
	_check(not battle.is_empty(), "surviving Bleed fixture routes the actual Boss attacker")
	if battle.is_empty():
		return
	var party: CombatParty = battle.party
	var enemies: CombatEnemies = battle.enemies
	var intents: CombatEnemyIntents = battle.intents
	var gauge: CombatUnravel = battle.unravel
	var flow: CombatRoundFlow = battle.flow
	_check(flow.begin_fight() and party.apply_damage(1, 6)
		and enemies.apply_damage(1, 62) and enemies.get_enemy(1).hp == 22
		and enemies.gain_block(1, 4)
		and enemies.apply_statuses({1: {"bleed": 1}})
		and gauge.apply_unravel(enemies, 1, 15),
		"at 22 HP boss has surviving Bleed, Block 4 and 15/16 gauge")
	var locked := intents.get_intents()
	_check(locked.size() == 1 and locked[0].type == "attack"
		and locked[0].amount == 34 and locked[0].target_position == 1
		and not gauge.get_snapshot(1).skip_pending,
		"Bleed has not preemptively skipped the already-announced front attack")
	_check(flow.end_turn(), "owner turn executes committed attack then enemy Bleed tick")
	_check(party.get_hero(1).hp == 6 and enemies.get_enemy(1).hp == 21
		and enemies.get_enemy(1).block == 4
		and enemies.get_enemy(1).get("statuses", {}).get("bleed", 0) == 0
		and gauge.get_snapshot(1) == {"gauge": 16, "threshold": 16,
			"unravelled": true, "skip_pending": true}
		and intents._boss_phase == 2 and intents._slots[0].target == "lowest_living_hp",
		"surviving Bleed bypasses Block, adds exactly 1 gauge AFTER attack and upgrades next phase")
	var hp_before := party.get_heroes()
	var block_before: int = enemies.get_enemy(1).block
	var announced := intents.get_intents()
	_check(flow.end_turn() and party.get_hero(1).hp == hp_before[0].hp
		and party.get_hero(2).hp == hp_before[1].hp
		and party.get_hero(3).hp == hp_before[2].hp
		and enemies.get_enemy(1).block == block_before
		and gauge.get_snapshot(1) == {"gauge": 0, "threshold": 20,
			"unravelled": false, "skip_pending": false}
		and announced.size() == 1 and intents._boss_phase == 2,
		"only FOLLOWING phase-two announced action is skipped and threshold rises to 20")
	# At the raised 20-gauge boundary, surviving Bleed must again apply
	# AFTER this turn's genuine committed phase-two action.
	_check(gauge.apply_unravel(enemies, 1, 19)
		and enemies.apply_statuses({1: {"bleed": 1}})
		and gauge.get_snapshot(1).gauge == 19
		and not gauge.get_snapshot(1).skip_pending,
		"surviving Boss approaches its raised 20-gauge break")
	var committed := intents.get_intents()
	var expected_party := CombatParty.new(party.get_heroes())
	expected_party._heroes.assign(party.get_heroes())
	var expected_enemies := CombatEnemies.new(enemies.get_enemies())
	expected_enemies._enemies.assign(enemies.get_enemies())
	var simulated := CombatEnemyPhase.new().execute_phase(
		expected_party, expected_enemies, committed, null, true)
	_check(simulated.get("ok", false) and simulated.events.size() == 1
		and simulated.events[0].applied,
		"current genuine phase-two action is executable before 20-gauge Bleed")
	_check(flow.end_turn() and enemies.get_enemy(1).hp == 20
		and enemies.get_enemy(1).block == expected_enemies.get_enemy(1).block
		and party.get_hero(1).hp == expected_party.get_hero(1).hp
		and party.get_hero(2).hp == expected_party.get_hero(2).hp
		and party.get_hero(3).hp == expected_party.get_hero(3).hp
		and gauge.get_snapshot(1) == {"gauge": 20, "threshold": 20,
			"unravelled": true, "skip_pending": true},
		"20-gauge Bleed follows phase-two action despite Block")
	var after_20_heroes := party.get_heroes()
	var after_20_block: int = enemies.get_enemy(1).block
	_check(flow.end_turn() and party.get_heroes() == after_20_heroes
		and enemies.get_enemy(1).block == after_20_block
		and gauge.get_snapshot(1) == {"gauge": 0, "threshold": 24,
			"unravelled": false, "skip_pending": false},
		"next action skips once at 20, never at the earlier Bleed tick")


func _test_round_rejections_and_replay() -> void:
	var battle := _start_boss(188421, true)
	var foreign := _start_boss(188421, true)
	_check(not battle.is_empty() and not foreign.is_empty(),
		"independent real run battles exist for mismatch and replay guards")
	if battle.is_empty() or foreign.is_empty():
		return
	var flow: CombatRoundFlow = battle.flow
	var gauge: CombatUnravel = battle.unravel
	var enemies: CombatEnemies = battle.enemies
	var start_state := _round_snapshot(battle)
	_check(not flow.end_turn() and _round_snapshot(battle) == start_state,
		"end-turn before admission rejects without consuming the first weighted intent")
	_check(flow.begin_fight() and enemies.apply_damage(1, 63)
		and gauge.apply_unravel(enemies, 1, 16)
		and gauge.get_snapshot(1).skip_pending,
		"malformed and mismatched end-turn guards start with a genuine pending Boss skip")
	var before := _round_snapshot(battle)
	_check(not gauge.apply_unravel(foreign.enemies, 1, 1)
		and _round_snapshot(battle) == before,
		"wrong Unravel source cannot charge a different routed boss")
	gauge._bound_enemies = foreign.enemies
	before = _round_snapshot(battle)
	_check(not flow.end_turn() and _round_snapshot(battle) == before
		and gauge.get_snapshot(1).skip_pending,
		"mismatched battle-bound gauge rejects without actor, deck, RNG or skip spend")
	gauge._bound_enemies = enemies
	var original := gauge.get_snapshot(1)
	gauge._gauges[1] = {"gauge": 16, "threshold": 16}
	before = _round_snapshot(battle)
	_check(not flow.end_turn() and _round_snapshot(battle) == before,
		"malformed bound Boss gauge rejects atomically before its phase")
	gauge._gauges[1] = original
	_check(battle.deck.end_turn() and not battle.deck.turn_active,
		"externally closed turn is an actual stale/duplicate end-turn precondition")
	before = _round_snapshot(battle)
	_check(not flow.end_turn() and _round_snapshot(battle) == before,
		"stale duplicate end-turn cannot consume a pending skip or weighted RNG")

	var terminal := _start_boss(188421, true)
	_check(not terminal.is_empty(), "terminal guard has an independent routed Boss")
	if not terminal.is_empty():
		_check(terminal.flow.begin_fight()
			and terminal.unravel.apply_unravel(terminal.enemies, 1, 16)
			and terminal.enemies.apply_damage(1, 84)
			and terminal.result.evaluate() == CombatBattleResult.VICTORY,
			"terminal victory is latched while the Boss's skip remains pending")
		var end_state := _round_snapshot(terminal)
		_check(not terminal.flow.end_turn() and _round_snapshot(terminal) == end_state,
			"terminal end-turn leaves pending skip, actors, hand and RNG untouched")

	var first := _round_replay(751829)
	var second := _round_replay(751829)
	_check(first.size() == 4 and second.size() == 4 and first == second,
		"two independent real Boss rounds replay ordered intents, actors, deck, gauge and RNG")
	if first.size() == 4:
		_check(first[0].phase == 1 and first[1].phase == 1
			and first[1].enemies[0].hp == 21
			and first[1].announced == first[0].announced
			and first[1].rng == first[0].rng
			and first[2].phase == 2 and first[2].unravel.threshold == 20
			and first[2].unravel.gauge == 0 and first[2].rng != first[1].rng
			and first[3].turn_index == first[2].turn_index + 1,
			"replay genuinely crosses phase, skips once and advances single seeded weighted roll")


func _round_replay(seed_value: int) -> Array:
	var battle := _start_boss(seed_value, true)
	if battle.is_empty() or not battle.flow.begin_fight():
		return []
	var first := _round_snapshot(battle)
	if not battle.enemies.apply_damage(1, 63) or not battle.party.apply_damage(2, 16) \
			or not battle.unravel.apply_unravel(battle.enemies, 1, 16):
		return []
	var crossed := _round_snapshot(battle)
	var oracle := _next_phase_two_oracle(battle, battle.rng.state)
	if oracle.is_empty() or not battle.flow.end_turn():
		return []
	var after_skip := _round_snapshot(battle)
	if after_skip.announced != [oracle.intent] or after_skip.rng != oracle.rng:
		return []
	if not battle.flow.end_turn():
		return []
	return [first, crossed, after_skip, _round_snapshot(battle)]


## The bound target stays announced when its hero falls mid-hand; execution
## chooses a still-living recipient using the already-committed phase policy.
func _test_round_down_target_fallback() -> void:
	var selected: Dictionary = {}
	for seed_value in range(1, 90):
		var battle := _start_boss(seed_value, true)
		if battle.is_empty():
			break
		if not battle.flow.begin_fight() or not battle.party.apply_damage(2, 16) \
				or not battle.enemies.apply_damage(1, 63) \
				or not battle.unravel.apply_unravel(battle.enemies, 1, 16) \
				or not battle.flow.end_turn():
			break
		var announced: Array[Dictionary] = battle.intents.get_intents()
		if announced.size() == 1 and announced[0].get("target_position") == 2:
			selected = battle
			break
	_check(not selected.is_empty(),
		"seeded routed phase-two Boss commits a living target for downed fallback")
	if selected.is_empty():
		return
	var party: CombatParty = selected.party
	var intents: CombatEnemyIntents = selected.intents
	var gauge: CombatUnravel = selected.unravel
	var original := intents.get_intents()
	var rng_before: int = selected.rng.state
	_check(original.size() == 1 and original[0].target_position == 2
		and party.get_hero(2).hp == 14 and party.apply_damage(2, 14)
		and party.is_downed(2) and intents.get_intents() == original
		and selected.rng.state == rng_before,
		"announced living hero 2 falls during player turn without retarget or new RNG")
	var expected_party := CombatParty.new(party.get_heroes())
	expected_party._heroes.assign(party.get_heroes())
	var expected_enemies := CombatEnemies.new(selected.enemies.get_enemies())
	expected_enemies._enemies.assign(selected.enemies.get_enemies())
	var executed := CombatEnemyPhase.new().execute_phase(
		expected_party, expected_enemies, original, null, true)
	_check(executed.get("ok", false) and executed.events.size() == 1
		and executed.events[0].applied and executed.events[0].target_position == 3,
		"real phase executor falls back to lowest living HP hero 3")
	_check(selected.flow.end_turn()
		and party.is_downed(2) and party.get_hero(2).hp == 0
		and party.get_hero(3).hp == expected_party.get_hero(3).hp
		and party.get_hero(3).get("statuses", {}) == expected_party.get_hero(3).get("statuses", {})
		and selected.enemies.get_enemy(1).block == expected_enemies.get_enemy(1).block
		and gauge.get_snapshot(1).threshold == 20
		and not gauge.get_snapshot(1).skip_pending,
		"live fallback never targets fallen hero 2 and does not skip again")
