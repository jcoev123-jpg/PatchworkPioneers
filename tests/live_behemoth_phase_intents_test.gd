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
	for failure in failures:
		printerr(failure)
	print("live_behemoth_phase_intents_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _start_boss(seed_value: int) -> Dictionary:
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
	var selector: CombatEnemyIntents = entry.intents
	if not party.is_valid() or not enemies.is_valid() \
			or enemies.get_enemy(1).get("id") != "patchwork_behemoth" \
			or enemies.get_enemy(1).get("hp") != 42 \
			or not selector.bind_battle(enemies, party, rng):
		return {}
	return {"map": map, "rng": rng, "party": party,
		"enemies": enemies, "intents": selector}


func _hurt_to_phase_two(battle: Dictionary) -> bool:
	var enemies: CombatEnemies = battle.enemies
	return enemies.apply_damage(1, 21) and enemies.get_enemy(1).hp == 21 \
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
		and enemies.get_enemy(1).max_hp == 42,
		"real selected Boss keeps one authentic enemy slot and 42 HP")
	_check(selector._slots[0].target == "front"
		and selector._slots[0].actions[0].action.amount == 2,
		"initial first-phase action/policy are authored")
	var announced := selector.get_intents()
	var rng_before := rng.state
	_check(enemies.apply_damage(1, 20) and enemies.get_enemy(1).hp == 22
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
		and selector._slots[0].actions[0].action.amount == 4
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
	_check(intent == {"type": "attack", "amount": 4, "enemy_position": 1,
			"target_position": 2},
		"phase-two attack announces exactly 4 against lowest-HP hero 2")
	var party: CombatParty = attack.party
	_check(party.gain_block(2, 2), "target gains real Block 2 before attack")
	var result := CombatEnemyPhase.new().execute_phase(
		party, attack.enemies, attack.intents.get_intents(), null, true)
	_check(result.get("ok", false) and result.events.size() == 1
		and result.events[0].applied and result.events[0].target_position == 2,
		"cached phase-two attack executes through CombatEnemyPhase")
	_check(party.get_hero(2).hp == 3 and party.get_hero(2).block == 0
		and party.get_hero(1).hp == 8 and party.get_hero(3).hp == 8,
		"4 damage consumes 2 Block before 2 HP and spares untargeted heroes")
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
			and target.get_hero(1).hp == 4 and target.get_hero(3).hp == 8,
			"lowest-living-HP fallback chooses tied front hero and deals cached 4")
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
		if not selector.advance_turn():
			return []
		result.append({"next": selector.get_intents(), "rng": battle.rng.state})
	return result


func _test_seeded_replay() -> void:
	var first := _replay(188421)
	var second := _replay(188421)
	_check(first.size() == 16 and first == second,
		"two genuine identically seeded Boss battles replay eight action/outcome/RNG traces")
	if first.size() == 16:
		_check(first[0].intent[0].enemy_position == 1
			and first[0].enemies[0].hp == 21
			and first[0].events.size() == 1,
			"replay trace actually exercises original Boss slot at phase-two HP")


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
	_check(locked[0] == {"type": "attack", "amount": 2,
			"enemy_position": 1, "target_position": 1},
		"phase-one attack commits exact authored 2 damage to front")
	_check(enemies.apply_damage(1, 21) and enemies.get_enemy(1).hp == 21
		and selector.get_intents() == locked and battle.rng.state == state_before
		and CombatEnemyIntents.policy_for(enemies, 1) == "front",
		"crossing the threshold mid-player-turn keeps old action and fallback policy")
	var executed := CombatEnemyPhase.new().execute_phase(
		party, enemies, locked, null, true)
	_check(executed.get("ok", false) and executed.events[0].target_position == 1
		and executed.events[0].applied and party.get_hero(1).hp == 38
		and party.get_hero(3).hp == 26,
		"old front attack really executes for two despite boss now at 21 HP")
	_check(selector.advance_turn()
		and selector._slots[0].actions[0].action.amount == 4
		and CombatEnemyIntents.policy_for(enemies, 1) == "lowest_living_hp",
		"following announcement (only) upgrades the actual attack/policy")
