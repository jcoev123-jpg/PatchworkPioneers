extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_single_enemy_victory()
	_test_multi_enemy_victory()
	_test_defeat()
	_test_terminal_latch_and_fresh_fight()
	_test_invalid_and_unobserved_tie()
	_test_seeded_replay()
	if failures.is_empty():
		print("combat_battle_result_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_battle_result_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _party() -> CombatParty:
	return CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}])


func _enemies(healths: Array) -> CombatEnemies:
	var definitions: Array = []
	for index in range(healths.size()):
		definitions.append({"id": "test_enemy_%d" % (index + 1), "max_hp": healths[index]})
	return CombatEnemies.new(definitions)


func _fight(healths: Array) -> Dictionary:
	var party := _party()
	var enemies := _enemies(healths)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var cards: Array[String] = ["a", "a", "b", "c", "d", "e", "f", "g"]
	var deck := CombatDeck.new(cards, rng)
	_check(deck.start_turn() and deck.hand.size() == 5 and deck.energy == 3,
		"real deck starts with 5 cards and 3 energy")
	_check(deck.discard_played(deck.hand[0]) and deck.end_turn() and deck.start_turn(),
		"real deck cycles draw/hand/discard with seeded refill")
	_check(deck.try_spend_energy(1) and deck.energy == 2 and deck.hand.size() == 5,
		"snapshot includes a partly spent real turn")
	_check(party.is_valid() and party.get_heroes().size() == 3 and not party.is_defeated(),
		"fixture contains three actual living heroes")
	_check(enemies.is_valid() and enemies.get_enemies().size() == healths.size()
		and not enemies.is_victorious(), "fixture has requested living enemy slots")
	for position in range(1, healths.size() + 1):
		_check(enemies.get_enemy(position).get("hp") == healths[position - 1],
			"fixture enemy has its declared HP, not live authored balance")
	return {"party": party, "enemies": enemies, "rng": rng, "deck": deck,
		"result": CombatBattleResult.new(party, enemies)}


func _snapshot(fight: Dictionary) -> Array:
	var party: CombatParty = fight["party"]
	var enemies: CombatEnemies = fight["enemies"]
	var deck: CombatDeck = fight["deck"]
	var rng: RandomNumberGenerator = fight["rng"]
	return [party.get_heroes(), enemies.get_enemies(), deck.draw_pile.duplicate(),
		deck.hand.duplicate(), deck.discard_pile.duplicate(), deck.energy, deck.turn_active,
		deck.combat_state.energy, deck.combat_state.player_turn_active, rng.state]


## Assert every result observation is read-only on the authoritative actors,
## every shared deck pile, both energy readers, and the injected run RNG.
func _probe(fight: Dictionary, expected: String, allowed: bool, label: String) -> void:
	var battle: CombatBattleResult = fight["result"]
	var before := _snapshot(fight)
	_check(battle.evaluate() == expected, label + ": checked outcome")
	_check(battle.get_outcome() == expected, label + ": exposed outcome")
	_check(battle.can_continue() == allowed, label + ": continuation gate")
	_check(battle.is_finished() == (expected == CombatBattleResult.VICTORY
		or expected == CombatBattleResult.DEFEAT), label + ": finished query")
	_check(_snapshot(fight) == before, label + ": evaluate and queries are read-only")
	_check(battle.check_outcome() == expected and battle.can_continue() == allowed,
		label + ": repeat check preserves outcome and gate")
	_check(_snapshot(fight) == before, label + ": repeated check is read-only")


func _test_single_enemy_victory() -> void:
	var fight := _fight([12])
	var enemies: CombatEnemies = fight["enemies"]
	_check(fight["result"].has_method("evaluate") and fight["result"].has_method("check_outcome")
		and fight["result"].has_method("get_outcome") and fight["result"].has_method("can_continue"),
		"battle exposes observation, result and action gate APIs")
	_probe(fight, CombatBattleResult.ACTIVE, true, "one enemy starts active")
	_check(enemies.apply_damage(1, 11) and enemies.get_enemy(1)["hp"] == 1,
		"11 of 12 fixture HP is nonlethal")
	_probe(fight, CombatBattleResult.ACTIVE, true, "one enemy at 1 HP")
	_check(enemies.apply_damage(1, 1) and enemies.is_dead(1) and enemies.is_victorious(),
		"final 1 damage actually kills the sole enemy")
	_probe(fight, CombatBattleResult.VICTORY, false, "exact final enemy death")
	_probe(fight, CombatBattleResult.VICTORY, false, "victory repeat")


func _test_multi_enemy_victory() -> void:
	var fight := _fight([7, 9, 12])
	var enemies: CombatEnemies = fight["enemies"]
	_probe(fight, CombatBattleResult.ACTIVE, true, "three enemies start active")
	_check(enemies.apply_damage(1, 7) and enemies.is_dead(1)
		and enemies.get_enemies().size() == 3, "slain enemy stays in its slot")
	_probe(fight, CombatBattleResult.ACTIVE, true, "first enemy death")
	_check(enemies.apply_damage(2, 9) and enemies.is_dead(2)
		and not enemies.is_victorious(), "second enemy dead, third living")
	_probe(fight, CombatBattleResult.ACTIVE, true, "second enemy death")
	_check(enemies.gain_block(3, 5) and enemies.get_enemy(3)["block"] == 5,
		"final living enemy gains real Block")
	_check(enemies.apply_damage(3, 12) and enemies.get_enemy(3)["hp"] == 5
		and enemies.get_enemy(3)["block"] == 0, "five Block absorbs before seven HP damage")
	_probe(fight, CombatBattleResult.ACTIVE, true, "last enemy protected to 5 HP")
	_check(enemies.apply_damage(3, 4) and enemies.get_enemy(3)["hp"] == 1,
		"nonlethal damage leaves exactly 1 HP")
	_probe(fight, CombatBattleResult.ACTIVE, true, "last enemy at 1 HP")
	_check(enemies.apply_damage(3, 1) and enemies.is_dead(3)
		and enemies.is_victorious(), "all three actual enemy slots now dead")
	for position in range(1, 4):
		_check(enemies.get_enemy(position)["position"] == position and enemies.is_dead(position),
			"victory retains all slain enemy positions")
	_probe(fight, CombatBattleResult.VICTORY, false, "third enemy final HP")


func _test_defeat() -> void:
	var fight := _fight([12])
	var party: CombatParty = fight["party"]
	var enemies: CombatEnemies = fight["enemies"]
	var attacks := CombatEnemyAttacks.new()
	_check(enemies.gain_block(1, 9) and party.gain_block(1, 6),
		"enemy and Warden both have Block")
	_probe(fight, CombatBattleResult.ACTIVE, true, "protected combat active")
	_check(attacks.execute_attacks(party, [
		{"enemy_position": 1, "target_position": 1, "amount": 5}])["ok"],
		"real enemy attack phase resolves blocked hit")
	_check(party.get_hero(1)["hp"] == 40 and party.get_hero(1)["block"] == 1,
		"Warden Block absorbs attack before HP")
	_probe(fight, CombatBattleResult.ACTIVE, true, "Warden fully blocked")
	_check(attacks.execute_attacks(party, [
		{"enemy_position": 1, "target_position": 1, "amount": 41}])["ok"]
		and party.is_downed(1), "real attack consumes remaining Block and downs Warden")
	_probe(fight, CombatBattleResult.ACTIVE, true, "only Warden down")
	_check(party.apply_damage(2, 30) and party.is_downed(2) and not party.is_defeated(),
		"Seamstress down at exactly zero; Tinker still living")
	_probe(fight, CombatBattleResult.ACTIVE, true, "two heroes down")
	_check(party.apply_damage(3, 26) and party.is_downed(3) and party.is_defeated(),
		"Tinker down at exact zero makes party defeated")
	_check(enemies.get_enemy(1)["hp"] == 12 and enemies.get_enemy(1)["block"] == 9,
		"enemy remains living and blocked at defeat")
	for position in range(1, 4):
		var hero := party.get_hero(position)
		_check(hero["position"] == position and hero["hp"] == 0 and party.is_downed(position),
			"downed hero retains fixed 1-based slot")
	_probe(fight, CombatBattleResult.DEFEAT, false, "final Tinker down")
	_probe(fight, CombatBattleResult.DEFEAT, false, "defeat repeat")


func _test_terminal_latch_and_fresh_fight() -> void:
	var victory := _fight([12])
	var enemies: CombatEnemies = victory["enemies"]
	var party: CombatParty = victory["party"]
	_check(enemies.apply_damage(1, 12), "prepare terminal victory")
	_probe(victory, CombatBattleResult.VICTORY, false, "first victory observation")
	for position in range(1, 4):
		_check(party.apply_damage(position, party.get_hero(position)["hp"]),
			"later unrelated direct party mutation succeeds")
	_check(party.is_defeated() and enemies.is_victorious(),
		"later direct API operations produce simultaneous dead states")
	_probe(victory, CombatBattleResult.VICTORY, false, "victory remains latched despite later tie")
	var defeat := _fight([12])
	var defeated_party: CombatParty = defeat["party"]
	var survivor: CombatEnemies = defeat["enemies"]
	for position in range(1, 4):
		_check(defeated_party.apply_damage(position, defeated_party.get_hero(position)["hp"]),
			"prepare observed defeat")
	_probe(defeat, CombatBattleResult.DEFEAT, false, "first defeat observation")
	_check(survivor.apply_damage(1, 12) and survivor.is_victorious(),
		"unrelated direct enemy API still independent after defeat")
	_probe(defeat, CombatBattleResult.DEFEAT, false, "defeat remains latched despite later tie")
	var new_fight := _fight([12])
	_probe(new_fight, CombatBattleResult.ACTIVE, true, "new independent fight starts active")
	_check(new_fight["result"] != victory["result"] and new_fight["result"] != defeat["result"],
		"results are distinct objects rather than singleton state")


func _test_invalid_and_unobserved_tie() -> void:
	var good_party := _party()
	var good_enemies := _enemies([12])
	var invalid_party := CombatParty.new([])
	var invalid_enemies := CombatEnemies.new([])
	_check(good_party.is_valid() and good_enemies.is_valid()
		and not invalid_party.is_valid() and not invalid_enemies.is_valid(),
		"valid and invalid fixtures have real expected preconditions")
	var cases: Array = [
		CombatBattleResult.new(null, good_enemies),
		CombatBattleResult.new(good_party, null),
		CombatBattleResult.new(null, null),
		CombatBattleResult.new(invalid_party, good_enemies),
		CombatBattleResult.new(good_party, invalid_enemies)]
	var party_before := good_party.get_heroes()
	var enemies_before := good_enemies.get_enemies()
	for result in cases:
		_check(result.get_outcome() == CombatBattleResult.UNRESOLVED
			and not result.can_continue() and not result.is_finished(),
			"invalid/null constructor fails closed, without a playable winner")
		_check(result.evaluate() == CombatBattleResult.UNRESOLVED
			and result.check_outcome() == CombatBattleResult.UNRESOLVED
			and not result.can_continue(), "invalid/null checks never fabricate outcome")
	_check(good_party.get_heroes() == party_before and good_enemies.get_enemies() == enemies_before,
		"invalid result observations preserve valid actors")
	var both_down_party := _party()
	var both_down_enemies := _enemies([12])
	for position in range(1, 4):
		_check(both_down_party.apply_damage(position, both_down_party.get_hero(position)["hp"]),
			"preexisting tie downs each real hero")
	_check(both_down_enemies.apply_damage(1, 12) and both_down_party.is_defeated()
		and both_down_enemies.is_victorious(), "preexisting tie has both sides truly dead")
	var preexisting := CombatBattleResult.new(both_down_party, both_down_enemies)
	_check(preexisting.evaluate() == CombatBattleResult.UNRESOLVED
		and not preexisting.can_continue() and not preexisting.is_finished(),
		"preexisting simultaneous deaths never pick a winner")
	_check(preexisting.check_outcome() == CombatBattleResult.UNRESOLVED,
		"tie outcome remains unresolved on repeat")
	var unobserved := _fight([12])
	var unobserved_party: CombatParty = unobserved["party"]
	var unobserved_enemies: CombatEnemies = unobserved["enemies"]
	for position in range(1, 4):
		_check(unobserved_party.apply_damage(position, unobserved_party.get_hero(position)["hp"]),
			"unobserved tie downs real heroes")
	_check(unobserved_enemies.apply_damage(1, 12), "unobserved tie kills real enemy")
	_probe(unobserved, CombatBattleResult.UNRESOLVED, false, "unobserved tie fails closed")


func _replay() -> Array:
	var fight := _fight([11, 7])
	var party: CombatParty = fight["party"]
	var enemies: CombatEnemies = fight["enemies"]
	var deck: CombatDeck = fight["deck"]
	var attacks := CombatEnemyAttacks.new()
	var history: Array = []
	_probe(fight, CombatBattleResult.ACTIVE, true, "replay initial")
	history.append([fight["result"].get_outcome(), fight["result"].can_continue(), _snapshot(fight)])
	_check(party.gain_block(1, 5), "replay gains Warden Block")
	_probe(fight, CombatBattleResult.ACTIVE, true, "replay blocked Warden")
	history.append([fight["result"].get_outcome(), fight["result"].can_continue(), _snapshot(fight)])
	_check(attacks.execute_attacks(party, [
		{"enemy_position": 2, "target_position": 1, "amount": 4}])["ok"],
		"replay executes real attack phase")
	_probe(fight, CombatBattleResult.ACTIVE, true, "replay first enemy attack")
	history.append([fight["result"].get_outcome(), fight["result"].can_continue(), _snapshot(fight)])
	_check(enemies.apply_damage(1, 11) and enemies.is_dead(1), "replay first enemy dies")
	_probe(fight, CombatBattleResult.ACTIVE, true, "replay one survivor")
	history.append([fight["result"].get_outcome(), fight["result"].can_continue(), _snapshot(fight)])
	_check(enemies.gain_block(2, 3) and enemies.apply_damage(2, 9)
		and enemies.get_enemy(2)["hp"] == 1, "replay second enemy Block absorbs 3")
	_check(deck.end_turn() and deck.start_turn() and deck.try_spend_energy(2),
		"replay advances real shared deck with seeded refill and energy spending")
	_probe(fight, CombatBattleResult.ACTIVE, true, "replay second at 1 HP")
	history.append([fight["result"].get_outcome(), fight["result"].can_continue(), _snapshot(fight)])
	_check(enemies.apply_damage(2, 1) and enemies.is_victorious(),
		"replay kills the final enemy exactly")
	_probe(fight, CombatBattleResult.VICTORY, false, "replay terminal")
	history.append([fight["result"].get_outcome(), fight["result"].can_continue(), _snapshot(fight)])
	_check(party.apply_damage(1, 40), "replay direct late API change")
	_probe(fight, CombatBattleResult.VICTORY, false, "replay terminal latch")
	history.append([fight["result"].get_outcome(), fight["result"].can_continue(), _snapshot(fight)])
	return history


func _test_seeded_replay() -> void:
	var a := _replay()
	var b := _replay()
	_check(a.size() == 7 and b.size() == 7, "both replays have seven actual observations")
	_check(a == b, "identical seeded operations reproduce all outcome transitions, "
		+ "hero/enemy states, deck piles, energy and RNG state")
	_check(a[0][0] == CombatBattleResult.ACTIVE and a[5][0] == CombatBattleResult.VICTORY
		and a[6][1] == false, "replay actually crosses terminal boundary and closes gate")