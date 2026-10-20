extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_method_contract()
	_test_normal_victory_payout()
	_test_elite_victory_payout_and_reproducibility()
	_test_failed_claims_keep_claim_open()
	_test_initially_active_then_victory()
	_test_repeated_and_independent_claims()
	_test_null_result_and_null_rng()
	_test_state_and_actor_snapshots()
	if failures.is_empty():
		print("run_victory_gold_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_victory_gold_test: FAIL (", failures.size(), " failures)")
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


func _snapshot(party: CombatParty, enemies: CombatEnemies, rng: RandomNumberGenerator) -> Array:
	return [party.get_heroes(), enemies.get_enemies(), rng.state]


func _kill_all(enemies: CombatEnemies) -> void:
	for position in range(1, enemies.get_enemies().size() + 1):
		var enemy := enemies.get_enemy(position)
		enemies.apply_damage(position, enemy.get("hp", 0) + enemy.get("block", 0))


func _test_method_contract() -> void:
	var service := RunVictoryGold.new(null)
	_check(service.has_method("claim_gold"), "service exposes claim_gold")
	_check(service.has_method("is_claimed"), "service exposes claim status")
	_check(service.claim_gold(false, null) == 0, "null result claim returns zero")
	_check(not service.is_claimed(), "null claim leaves claim open")


func _test_normal_victory_payout() -> void:
	var party := _party()
	var enemies := _enemies([12])
	var result := CombatBattleResult.new(party, enemies)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7001
	var reference := RandomNumberGenerator.new()
	reference.seed = 7001
	var service := RunVictoryGold.new(result)

	_check(result.evaluate() == CombatBattleResult.ACTIVE, "fresh fight starts active")
	_check(service.claim_gold(false, rng) == 0, "unobserved active claim returns zero")
	_check(rng.state == reference.state, "failed active claim consumes no RNG")

	enemies.apply_damage(1, 12)
	_check(enemies.is_victorious(), "enemy is actually dead")
	_check(result.evaluate() == CombatBattleResult.VICTORY, "evaluate reports victory")

	var expected := reference.randi_range(10, 20)
	var actual := service.claim_gold(false, rng)
	_check(actual == expected, "normal payout matches one reference draw")
	_check(actual >= 10 and actual <= 20, "normal payout is within 10..20")
	_check(rng.state == reference.state, "successful claim consumes exactly one draw")
	_check(service.is_claimed(), "successful claim latches")


func _test_elite_victory_payout_and_reproducibility() -> void:
	var payouts: Array[int] = []
	for seed_value in [9001, 9002]:
		var party := _party()
		var enemies := _enemies([7, 9])
		var result := CombatBattleResult.new(party, enemies)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var reference := RandomNumberGenerator.new()
		reference.seed = seed_value
		var service := RunVictoryGold.new(result)

		_kill_all(enemies)
		_check(result.evaluate() == CombatBattleResult.VICTORY, "multi-enemy fight observes victory")

		var expected := reference.randi_range(25, 35)
		var actual := service.claim_gold(true, rng)
		_check(actual == expected, "elite payout matches one reference draw for seed " + str(seed_value))
		_check(actual >= 25 and actual <= 35, "elite payout is within 25..35")
		_check(rng.state == reference.state, "elite claim consumes exactly one draw")
		payouts.append(actual)

	# Fixed-seed replay: recreate identical fights and RNGs.
	var party_a := _party()
	var enemies_a := _enemies([7, 9])
	var result_a := CombatBattleResult.new(party_a, enemies_a)
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 4242
	var service_a := RunVictoryGold.new(result_a)
	_kill_all(enemies_a)
	result_a.evaluate()

	var party_b := _party()
	var enemies_b := _enemies([7, 9])
	var result_b := CombatBattleResult.new(party_b, enemies_b)
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 4242
	var service_b := RunVictoryGold.new(result_b)
	_kill_all(enemies_b)
	result_b.evaluate()

	var gold_a := service_a.claim_gold(true, rng_a)
	var gold_b := service_b.claim_gold(true, rng_b)
	_check(gold_a == gold_b, "identical seeded fights reproduce the same elite payout")
	_check(rng_a.state == rng_b.state, "identical seeded fights leave RNG states equal")


func _test_failed_claims_keep_claim_open() -> void:
	# ACTIVE with one dead enemy while another lives.
	var party := _party()
	var enemies := _enemies([7, 9])
	var result := CombatBattleResult.new(party, enemies)
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	var reference := RandomNumberGenerator.new()
	reference.seed = 101
	var service := RunVictoryGold.new(result)

	enemies.apply_damage(1, 7)
	_check(enemies.is_dead(1) and not enemies.is_victorious(), "first enemy dead, second lives")
	_check(result.evaluate() == CombatBattleResult.ACTIVE, "partial kill stays active")
	var before_rng := rng.state
	var before_party := party.get_heroes()
	var before_enemies := enemies.get_enemies()
	_check(service.claim_gold(false, rng) == 0, "partial-kill active claim returns zero")
	_check(rng.state == before_rng and rng.state == reference.state, "partial-kill claim consumes no RNG")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"partial-kill claim does not mutate actors")
	_check(not service.is_claimed(), "partial-kill claim keeps claim open")

	# DEFEAT.
	var defeat_party := _party()
	var defeat_enemies := _enemies([12])
	var defeat_result := CombatBattleResult.new(defeat_party, defeat_enemies)
	var defeat_rng := RandomNumberGenerator.new()
	defeat_rng.seed = 202
	var defeat_reference := RandomNumberGenerator.new()
	defeat_reference.seed = 202
	var defeat_service := RunVictoryGold.new(defeat_result)
	for position in range(1, 4):
		defeat_party.apply_damage(position, defeat_party.get_hero(position).get("hp", 0))
	_check(defeat_party.is_defeated(), "party is actually defeated")
	_check(defeat_result.evaluate() == CombatBattleResult.DEFEAT, "evaluate reports defeat")
	var defeat_before_rng := defeat_rng.state
	var defeat_before_party := defeat_party.get_heroes()
	var defeat_before_enemies := defeat_enemies.get_enemies()
	_check(defeat_service.claim_gold(false, defeat_rng) == 0, "defeat claim returns zero")
	_check(defeat_rng.state == defeat_before_rng and defeat_rng.state == defeat_reference.state,
		"defeat claim consumes no RNG")
	_check(defeat_party.get_heroes() == defeat_before_party
		and defeat_enemies.get_enemies() == defeat_before_enemies,
		"defeat claim does not mutate actors")
	_check(not defeat_service.is_claimed(), "defeat claim keeps claim open")

	# UNRESOLVED via invalid roster.
	var invalid_service := RunVictoryGold.new(CombatBattleResult.new(null, _enemies([12])))
	var unresolved_rng := RandomNumberGenerator.new()
	unresolved_rng.seed = 303
	var unresolved_reference := RandomNumberGenerator.new()
	unresolved_reference.seed = 303
	var unresolved_before := unresolved_rng.state
	_check(invalid_service.claim_gold(false, unresolved_rng) == 0, "invalid result claim returns zero")
	_check(unresolved_rng.state == unresolved_before and unresolved_rng.state == unresolved_reference.state,
		"invalid result claim consumes no RNG")
	_check(not invalid_service.is_claimed(), "invalid result keeps claim open")

	# UNRESOLVED via preexisting tie.
	var tie_party := _party()
	var tie_enemies := _enemies([12])
	for position in range(1, 4):
		tie_party.apply_damage(position, tie_party.get_hero(position).get("hp", 0))
	tie_enemies.apply_damage(1, 12)
	var tie_result := CombatBattleResult.new(tie_party, tie_enemies)
	var tie_service := RunVictoryGold.new(tie_result)
	var tie_rng := RandomNumberGenerator.new()
	tie_rng.seed = 404
	var tie_reference := RandomNumberGenerator.new()
	tie_reference.seed = 404
	var tie_before := tie_rng.state
	_check(tie_result.evaluate() == CombatBattleResult.UNRESOLVED, "preexisting tie is unresolved")
	_check(tie_service.claim_gold(false, tie_rng) == 0, "unresolved claim returns zero")
	_check(tie_rng.state == tie_before and tie_rng.state == tie_reference.state,
		"unresolved claim consumes no RNG")
	_check(not tie_service.is_claimed(), "unresolved claim keeps claim open")


func _test_initially_active_then_victory() -> void:
	var party := _party()
	var enemies := _enemies([12])
	var result := CombatBattleResult.new(party, enemies)
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	var reference := RandomNumberGenerator.new()
	reference.seed = 505
	var service := RunVictoryGold.new(result)

	_check(result.get_outcome() == CombatBattleResult.ACTIVE, "service created while active")
	_check(service.claim_gold(false, rng) == 0, "active service cannot claim before observation")
	_check(not service.is_claimed(), "failed active claim leaves service open")

	enemies.apply_damage(1, 12)
	_check(result.evaluate() == CombatBattleResult.VICTORY, "later observation reports victory")
	var expected := reference.randi_range(10, 20)
	var actual := service.claim_gold(false, rng)
	_check(actual == expected, "same instance claims after later victory")
	_check(rng.state == reference.state, "later claim consumes exactly one draw")
	_check(service.is_claimed(), "later claim latches")


func _test_repeated_and_independent_claims() -> void:
	var party := _party()
	var enemies := _enemies([12])
	var result := CombatBattleResult.new(party, enemies)
	var rng := RandomNumberGenerator.new()
	rng.seed = 606
	var service := RunVictoryGold.new(result)
	enemies.apply_damage(1, 12)
	result.evaluate()

	var first := service.claim_gold(false, rng)
	_check(first >= 10 and first <= 20, "first claim succeeds")
	var after_first_state := rng.state
	var after_first_party := party.get_heroes()
	var after_first_enemies := enemies.get_enemies()

	_check(service.claim_gold(false, rng) == 0, "repeated claim returns zero")
	_check(rng.state == after_first_state, "repeated claim consumes no RNG")
	_check(party.get_heroes() == after_first_party and enemies.get_enemies() == after_first_enemies,
		"repeated claim does not mutate actors")
	_check(service.is_claimed(), "repeated claim remains latched")

	# Different victorious fight claims independently.
	var party2 := _party()
	var enemies2 := _enemies([5])
	var result2 := CombatBattleResult.new(party2, enemies2)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 707
	var service2 := RunVictoryGold.new(result2)
	enemies2.apply_damage(1, 5)
	result2.evaluate()
	_check(service2.claim_gold(false, rng2) >= 10, "independent fight can claim")
	_check(service2.is_claimed(), "independent claim latches independently")


func _test_null_result_and_null_rng() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var reference := RandomNumberGenerator.new()
	reference.seed = 808

	var null_result_service := RunVictoryGold.new(null)
	_check(null_result_service.claim_gold(false, rng) == 0, "null result returns zero")
	_check(rng.state == reference.state, "null result consumes no RNG")
	_check(not null_result_service.is_claimed(), "null result keeps claim open")

	var party := _party()
	var enemies := _enemies([12])
	var result := CombatBattleResult.new(party, enemies)
	enemies.apply_damage(1, 12)
	result.evaluate()
	var null_rng_service := RunVictoryGold.new(result)
	var before := rng.state
	_check(null_rng_service.claim_gold(false, null) == 0, "null RNG returns zero")
	_check(rng.state == before and rng.state == reference.state, "null RNG consumes no RNG")
	_check(not null_rng_service.is_claimed(), "null RNG keeps claim open")

	# Claim can still succeed afterwards with a valid RNG.
	var expected := reference.randi_range(10, 20)
	var actual := null_rng_service.claim_gold(false, rng)
	_check(actual == expected, "claim succeeds after earlier null RNG")
	_check(rng.state == reference.state, "successful later claim consumes one draw")


func _test_state_and_actor_snapshots() -> void:
	var party := _party()
	var enemies := _enemies([3, 4])
	var result := CombatBattleResult.new(party, enemies)
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var service := RunVictoryGold.new(result)

	# Block on enemies/hero and partial kill.
	party.gain_block(1, 5)
	enemies.gain_block(2, 2)
	enemies.apply_damage(1, 3)
	_check(result.evaluate() == CombatBattleResult.ACTIVE, "two-enemy partial state stays active")

	var before := _snapshot(party, enemies, rng)
	_check(service.claim_gold(true, rng) == 0, "active claim returns zero")
	var after := _snapshot(party, enemies, rng)
	_check(after == before, "failed claim preserves heroes, enemies, positions, Block and RNG")

	# Victory observation then claim and verify positions/Block survive.
	enemies.apply_damage(2, 6)
	_check(result.evaluate() == CombatBattleResult.VICTORY, "final enemy death observes victory")
	var before_v := _snapshot(party, enemies, rng)
	_check(service.claim_gold(true, rng) >= 25, "victory claim succeeds")
	var after_v := _snapshot(party, enemies, rng)
	_check(after_v[0] == before_v[0] and after_v[1] == before_v[1],
		"successful claim preserves all hero/enemy HP, Block and positions")