extends SceneTree

var failures: Array[String] = []
var checks := 0
var attacks := CombatStatusAttacks.new()


func _initialize() -> void:
	_test_contract_and_enemy_modifiers()
	_test_hero_modifiers()
	_test_zero_overkill_and_bleed()
	_test_invalid_rosters_and_targets()
	_test_status_validation()
	_test_riposte_compatibility()
	_test_immutable_snapshots_and_replay()
	_test_tangled_bonus_and_ageing()
	_test_thorns_retaliation()
	if failures.is_empty():
		print("combat_status_attacks_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_status_attacks_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _party() -> CombatParty:
	var party := CombatParty.new([
		{"id": "warden", "max_hp": 40}, {"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}])
	_check(party.is_valid() and party.get_heroes().size() == 3
		and party.get_hero(1)["hp"] == 40 and party.get_hero(2)["hp"] == 30
		and party.get_hero(3)["hp"] == 26, "fixture has all three real heroes")
	return party


func _enemies() -> CombatEnemies:
	var enemies := CombatEnemies.new([
		{"id": "patch_imp", "max_hp": 12}, {"id": "stitch_foe", "max_hp": 17},
		{"id": "paper_foe", "max_hp": 21}])
	_check(enemies.is_valid() and enemies.get_enemies().size() == 3
		and enemies.get_enemy(1)["hp"] == 12, "fixture has three living real enemies")
	return enemies


func _event(damage: int, absorbed: int, loss: int) -> Dictionary:
	return {"ok": true, "damage": damage, "block_absorbed": absorbed, "hp_loss": loss}


func _failure() -> Dictionary:
	return {"ok": false, "damage": 0, "block_absorbed": 0, "hp_loss": 0}


func _test_contract_and_enemy_modifiers() -> void:
	_check(attacks.has_method("resolve_vs_enemy") and attacks.has_method("resolve_vs_hero"),
		"both exact public methods exist")
	var scenarios := [
		{"attack": {}, "defend": {}, "damage": 6, "loss": 2, "absorbed": 4},
		{"attack": {"weak": 1}, "defend": {}, "damage": 4, "loss": 0, "absorbed": 4},
		{"attack": {}, "defend": {"exposed": 1}, "damage": 9, "loss": 5, "absorbed": 4},
		{"attack": {"weak": 2}, "defend": {"exposed": 2}, "damage": 6, "loss": 2, "absorbed": 4}
	]
	for scenario in scenarios:
		var enemies := _enemies()
		_check(enemies.gain_block(1, 4), "set enemy Block fixture")
		var other: Array[Dictionary] = [enemies.get_enemy(2), enemies.get_enemy(3)]
		var attacker: Dictionary = scenario["attack"]
		var defender: Dictionary = scenario["defend"]
		var attacker_before := attacker.duplicate(true)
		var defender_before := defender.duplicate(true)
		var result := attacks.resolve_vs_enemy(enemies, 1, 6, attacker, defender)
		_check(result == _event(scenario["damage"], scenario["absorbed"], scenario["loss"]),
			"enemy exact status+Block split: " + str(scenario))
		_check(enemies.get_enemy(1)["hp"] == 12 - scenario["loss"]
			and enemies.get_enemy(1)["block"] == 4 - scenario["absorbed"],
			"enemy authoritative HP and Block updated exactly")
		_check([enemies.get_enemy(2), enemies.get_enemy(3)] == other,
			"enemy other positions untouched")
		_check(attacker == attacker_before and defender == defender_before,
			"no status aging or input mutation during enemy hit")


func _test_hero_modifiers() -> void:
	var scenarios := [
		{"attack": {}, "defend": {}, "damage": 8, "loss": 2},
		{"attack": {"weak": 1}, "defend": {}, "damage": 6, "loss": 0},
		{"attack": {}, "defend": {"exposed": 1}, "damage": 12, "loss": 6},
		{"attack": {"weak": 1}, "defend": {"exposed": 1}, "damage": 9, "loss": 3}
	]
	for scenario in scenarios:
		var party := _party()
		_check(party.gain_block(1, 6), "assign Warden opening Block")
		var unaffected: Array[Dictionary] = [party.get_hero(2), party.get_hero(3)]
		var attacker: Dictionary = scenario["attack"]
		var defender: Dictionary = scenario["defend"]
		var attacker_before := attacker.duplicate(true)
		var defender_before := defender.duplicate(true)
		var result := attacks.resolve_vs_hero(party, 1, 8, attacker, defender)
		_check(result == _event(scenario["damage"], 6, scenario["loss"]),
			"Warden 8->6/12/9 uses final-floor rules before six Block: " + str(scenario))
		_check(party.get_hero(1)["hp"] == 40 - scenario["loss"]
			and party.get_hero(1)["block"] == 0, "real Warden HP and Block after attack")
		_check([party.get_hero(2), party.get_hero(3)] == unaffected,
			"other heroes untouched by single target attack")
		_check(attacker == attacker_before and defender == defender_before,
			"hero attack does not age status dictionaries")


func _test_zero_overkill_and_bleed() -> void:
	var enemies := _enemies()
	_check(enemies.gain_block(1, 5), "prepare positive enemy Block")
	var before := enemies.get_enemies()
	_check(attacks.resolve_vs_enemy(enemies, 1, 0, {"weak": 2}, {"exposed": 1})
		== _event(0, 0, 0), "zero hit succeeds on living enemy")
	_check(enemies.get_enemies() == before, "zero hit preserves positive Block and all enemy HP")
	_check(attacks.resolve_vs_enemy(enemies, 1, 6, {"bleed": 3}, {"bleed": 2})
		== _event(6, 5, 1), "Bleed-only modifiers leave attack damage unchanged")
	_check(enemies.get_enemy(1)["hp"] == 11 and enemies.get_enemy(1)["block"] == 0,
		"Bleed doesn't tick direct HP or consume any additional Block")
	_check(attacks.resolve_vs_enemy(enemies, 1, 100, {}, {}) == _event(100, 0, 11),
		"lethal enemy hit reports actual loss, not overkill amount")
	_check(enemies.is_slain(1) and enemies.get_enemy(1)["hp"] == 0,
		"slain enemy remains at zero HP and same position")
	var party := _party()
	_check(party.gain_block(1, 6), "prepare positive hero Block")
	before = party.get_heroes()
	_check(attacks.resolve_vs_hero(party, 1, 0, {}, {"exposed": 2}) == _event(0, 0, 0),
		"zero hit succeeds on living hero with Exposed")
	_check(party.get_heroes() == before, "zero hit preserves all hero state including Block")
	_check(attacks.resolve_vs_hero(party, 1, 7, {"bleed": 2}, {"bleed": 3})
		== _event(7, 6, 1), "Bleed-only hero attack changes neither damage nor status")
	_check(attacks.resolve_vs_hero(party, 1, 100, {}, {}) == _event(100, 0, 39),
		"overkill hero hit reports actual HP loss after prior hit")
	_check(party.is_downed(1) and party.get_hero(1)["hp"] == 0,
		"downed Warden stays in place at zero HP")


func _reject_enemy(enemies: CombatEnemies, pos: int, amount: int,
		attacker: Dictionary, defender: Dictionary, reason: String) -> void:
	var before: Array[Dictionary] = []
	if enemies != null:
		before = enemies.get_enemies()
	var attack_before: Dictionary = attacker.duplicate(true)
	var defend_before: Dictionary = defender.duplicate(true)
	_check(attacks.resolve_vs_enemy(enemies, pos, amount, attacker, defender) == _failure(),
		"enemy rejection: " + reason)
	if enemies != null:
		_check(enemies.get_enemies() == before, "enemy roster unchanged: " + reason)
	_check(attacker == attack_before and defender == defend_before,
		"status inputs unchanged: " + reason)


func _reject_hero(party: CombatParty, pos: int, amount: int,
		attacker: Dictionary, defender: Dictionary, reason: String) -> void:
	var before: Array[Dictionary] = []
	if party != null:
		before = party.get_heroes()
	var attack_before: Dictionary = attacker.duplicate(true)
	var defend_before: Dictionary = defender.duplicate(true)
	_check(attacks.resolve_vs_hero(party, pos, amount, attacker, defender) == _failure(),
		"hero rejection: " + reason)
	if party != null:
		_check(party.get_heroes() == before, "hero roster unchanged: " + reason)
	_check(attacker == attack_before and defender == defend_before,
		"status inputs unchanged: " + reason)


func _test_invalid_rosters_and_targets() -> void:
	_reject_enemy(null, 1, 6, {}, {}, "null enemy roster")
	_reject_hero(null, 1, 8, {}, {}, "null hero roster")
	var invalid_enemies := CombatEnemies.new([])
	var invalid_party := CombatParty.new([])
	_check(not invalid_enemies.is_valid() and not invalid_party.is_valid(),
		"invalid roster fixtures really are invalid")
	_reject_enemy(invalid_enemies, 1, 6, {}, {}, "invalid enemy roster")
	_reject_hero(invalid_party, 1, 8, {}, {}, "invalid hero roster")
	var enemies := _enemies()
	var party := _party()
	_check(enemies.gain_block(1, 4) and party.gain_block(1, 6),
		"negative-case Block fixtures prepared")
	for pos in [-1, 0, 4, 100]:
		_reject_enemy(enemies, pos, 6, {}, {}, "missing enemy slot %d" % pos)
		_reject_hero(party, pos, 8, {}, {}, "missing hero slot %d" % pos)
	_reject_enemy(CombatEnemies.new([{"id": "solo", "max_hp": 12}]), 2, 6, {}, {},
		"unoccupied enemy slot two on valid shorter roster")
	_check(enemies.apply_damage(2, 17) and enemies.is_slain(2),
		"slain enemy slot retained")
	_check(party.apply_damage(2, 30) and party.is_downed(2),
		"downed hero slot retained")
	_reject_enemy(enemies, 2, 0, {}, {}, "slain enemy cannot receive even zero attack")
	_reject_enemy(enemies, 2, 50, {}, {}, "slain enemy cannot receive damaging attack")
	_reject_hero(party, 2, 0, {}, {}, "downed hero cannot receive zero attack")
	_reject_hero(party, 2, 50, {}, {}, "downed hero cannot receive damaging attack")
	_reject_enemy(enemies, 1, -1, {}, {}, "negative enemy damage")
	_reject_hero(party, 1, -1, {}, {}, "negative hero damage")


func _test_status_validation() -> void:
	var enemies := _enemies()
	var party := _party()
	_check(enemies.gain_block(1, 4) and party.gain_block(1, 6),
		"malformed status fixtures have Block and living targets")
	var invalid_statuses: Array[Dictionary] = [
		{"poison": 1}, {"Bleed": 1}, {1: 2}, {&"weak": 1},
		{"weak": -1}, {"exposed": -1}, {"bleed": -1},
		{"weak": 1.5}, {"exposed": 1.0}, {"bleed": 0.5},
		{"weak": "1"}, {"exposed": null}, {"bleed": true},
		{"weak": []}, {"bleed": {"nested": [1, 2]}},
		{"riposte": -1}, {"riposte": 2.0}, {"riposte": true}, {"riposte": "3"},
		{"riposte": null}, {"riposte": []}, {"Riposte": 1}, {"riposte": 1, "poison": 1}
	]
	for bad in invalid_statuses:
		_reject_enemy(enemies, 1, 6, bad, {}, "malformed enemy attacker: " + str(bad))
		_reject_enemy(enemies, 1, 6, {}, bad, "malformed enemy defender: " + str(bad))
		_reject_hero(party, 1, 8, bad, {}, "malformed hero attacker: " + str(bad))
		_reject_hero(party, 1, 8, {}, bad, "malformed hero defender: " + str(bad))
	# Zeros and valid counters are legal and still never tick in this service.
	_check(attacks.resolve_vs_enemy(enemies, 1, 0,
		{"bleed": 0, "weak": 0, "exposed": 0}, {"bleed": 1}) == _event(0, 0, 0),
		"nonnegative zero counters accepted on enemy")
	_check(attacks.resolve_vs_hero(party, 1, 0,
		{"bleed": 3, "weak": 0}, {"exposed": 0}) == _event(0, 0, 0),
		"legal status counters accepted on hero")
	# Canonical nonnegative Riposte is now legal on either side and never adds
	# damage; every value resolves to the same zero-damage receipt.
	for riposte_value in [0, 2, 3]:
		var riposte_map := {"riposte": riposte_value}
		_check(attacks.resolve_vs_enemy(enemies, 1, 0, riposte_map, {}) == _event(0, 0, 0),
			"valid enemy attacker riposte %d accepted" % riposte_value)
		_check(attacks.resolve_vs_enemy(enemies, 1, 0, {}, riposte_map) == _event(0, 0, 0),
			"valid enemy defender riposte %d accepted" % riposte_value)
		_check(attacks.resolve_vs_hero(party, 1, 0, riposte_map, {}) == _event(0, 0, 0),
			"valid hero attacker riposte %d accepted" % riposte_value)
		_check(attacks.resolve_vs_hero(party, 1, 0, {}, riposte_map) == _event(0, 0, 0),
			"valid hero defender riposte %d accepted" % riposte_value)
		_check(attacks.resolve_vs_enemy(enemies, 1, 0, riposte_map, riposte_map) == _event(0, 0, 0),
			"valid enemy both-side riposte %d accepted" % riposte_value)
		_check(attacks.resolve_vs_hero(party, 1, 0, riposte_map, riposte_map) == _event(0, 0, 0),
			"valid hero both-side riposte %d accepted" % riposte_value)


## AC1: Riposte is not an attack modifier on this bridge. A canonical nonnegative
## counter on the attacker, the defender, or both (beside Weak/Exposed/Tangled)
## changes no receipt, Block absorption or HP loss, and neither supplied status
## map is consumed or mutated. Both directions use the real authoritative rosters.
func _test_riposte_compatibility() -> void:
	var bases: Array[Dictionary] = [
		{"attack": {"weak": 1}, "defend": {}},
		{"attack": {}, "defend": {"exposed": 1}},
		{"attack": {"weak": 1}, "defend": {"exposed": 1, "tangled": 2}},
	]
	for base in bases:
		var base_attack: Dictionary = base["attack"].duplicate(true)
		var base_defend: Dictionary = base["defend"].duplicate(true)
		var control_enemies := _enemies()
		var control_party := _party()
		_check(control_enemies.gain_block(1, 4) and control_party.gain_block(1, 6),
			"riposte control fixtures have real Block")
		var expected_enemy := attacks.resolve_vs_enemy(
			control_enemies, 1, 6, base_attack, base_defend)
		var expected_hero := attacks.resolve_vs_hero(
			control_party, 1, 8, base_attack, base_defend)
		_check(expected_enemy["ok"] and expected_hero["ok"],
			"riposte control receipts succeed on living real targets")
		_check(expected_enemy["block_absorbed"] == 4 and expected_hero["block_absorbed"] == 6,
			"riposte control hits absorb the full real Block fixture")
		for placement in ["attacker", "defender", "both"]:
			var attack: Dictionary = base_attack.duplicate(true)
			var defend: Dictionary = base_defend.duplicate(true)
			if placement != "defender":
				attack["riposte"] = 2
			if placement != "attacker":
				defend["riposte"] = 3
			var attack_before := attack.duplicate(true)
			var defend_before := defend.duplicate(true)
			var enemies := _enemies()
			var party := _party()
			_check(enemies.gain_block(1, 4) and party.gain_block(1, 6),
				"riposte fixtures repeat the control Block")
			var enemy_result := attacks.resolve_vs_enemy(enemies, 1, 6, attack, defend)
			var hero_result := attacks.resolve_vs_hero(party, 1, 8, attack, defend)
			_check(enemy_result == expected_enemy and hero_result == expected_hero,
				"riposte on %s leaves both receipts identical to the riposte-free control" % placement)
			_check(enemies.get_enemies() == control_enemies.get_enemies()
				and party.get_heroes() == control_party.get_heroes(),
				"riposte on %s produces the same rosters as the control" % placement)
			_check(attack == attack_before and defend == defend_before,
				"riposte on %s is neither consumed nor mutated" % placement)

	# The canonical counters also live on the real roster records themselves, not
	# only in caller-supplied maps: both directions read the records' own status
	# dictionaries and leave those counters intact after the hit.
	var record_enemies := _enemies()
	var record_party := _party()
	record_enemies._enemies[0]["statuses"] = {"riposte": 3}
	record_party._heroes[0]["statuses"] = {"riposte": 2}
	_check(record_enemies.gain_block(1, 4) and record_party.gain_block(1, 6),
		"record-backed Riposte fixtures hold real Block")
	var record_enemy_hit := attacks.resolve_vs_enemy(record_enemies, 1, 6,
		record_party.get_hero(1)["statuses"], record_enemies.get_enemy(1)["statuses"])
	var record_hero_hit := attacks.resolve_vs_hero(record_party, 1, 8,
		record_party.get_hero(1)["statuses"], record_enemies.get_enemy(1)["statuses"])
	_check(record_enemy_hit == _event(6, 4, 2) and record_hero_hit == _event(8, 6, 2),
		"record-backed Riposte hits keep the plain floor-rounded receipts")
	_check(record_party.get_hero(1)["statuses"] == {"riposte": 2}
		and record_enemies.get_enemy(1)["statuses"] == {"riposte": 3},
		"both roster records keep their Riposte counters after the hits")
	_check(record_party.get_hero(1)["hp"] == 38 and record_party.get_hero(1)["block"] == 0
		and record_enemies.get_enemy(1)["hp"] == 10 and record_enemies.get_enemy(1)["block"] == 0,
		"record-backed Riposte hits spend Block before HP on both rosters")

	# Deterministic replay in two independent, freshly built fixtures.
	var enemy_receipts: Array[Dictionary] = []
	var hero_receipts: Array[Dictionary] = []
	var enemy_rosters: Array = []
	var hero_rosters: Array = []
	for repeat in range(2):
		var replay_enemies := _enemies()
		var replay_party := _party()
		_check(replay_enemies.gain_block(1, 4) and replay_party.gain_block(1, 6),
			"riposte replay fixtures prepared identically")
		var replay_attack := {"riposte": 2, "bleed": 1}
		var replay_defend := {"riposte": 3, "tangled": 1}
		enemy_receipts.append(attacks.resolve_vs_enemy(
			replay_enemies, 1, 6, replay_attack, replay_defend))
		enemy_rosters.append(replay_enemies.get_enemies())
		hero_receipts.append(attacks.resolve_vs_hero(
			replay_party, 1, 8, replay_attack, replay_defend))
		hero_rosters.append(replay_party.get_heroes())
	_check(enemy_receipts[0] == _event(8, 4, 4) and hero_receipts[0] == _event(10, 6, 4),
		"Riposte beside Tangled keeps Tangled's +2 and unchanged Block absorption")
	_check(enemy_receipts[0] == enemy_receipts[1] and hero_receipts[0] == hero_receipts[1]
		and enemy_rosters[0] == enemy_rosters[1] and hero_rosters[0] == hero_rosters[1],
		"independent identical Riposte fixtures replay receipts and rosters")


func _test_immutable_snapshots_and_replay() -> void:
	var attacker := {"weak": 1, "bleed": 2}
	var defender := {"exposed": 1, "bleed": 3}
	var attack_original := attacker.duplicate(true)
	var defend_original := defender.duplicate(true)
	var enemy_state: Array[Dictionary] = []
	var hero_state: Array[Dictionary] = []
	var expected_enemy: Dictionary = {}
	var expected_hero: Dictionary = {}
	for repeat in range(4):
		var enemies := _enemies()
		var party := _party()
		_check(enemies.gain_block(1, 4) and party.gain_block(1, 6),
			"replay fixtures prepared identically")
		var untouched_enemies: Array[Dictionary] = [enemies.get_enemy(2), enemies.get_enemy(3)]
		var untouched_heroes: Array[Dictionary] = [party.get_hero(2), party.get_hero(3)]
		var enemy_result := attacks.resolve_vs_enemy(enemies, 1, 8, attacker, defender)
		var hero_result := attacks.resolve_vs_hero(party, 1, 8, attacker, defender)
		_check(enemy_result == _event(9, 4, 5)
			and hero_result == _event(9, 6, 3), "both directions have correct one-floor replay result")
		_check([enemies.get_enemy(2), enemies.get_enemy(3)] == untouched_enemies
			and [party.get_hero(2), party.get_hero(3)] == untouched_heroes,
			"replay does not mutate unrelated positions")
		if repeat == 0:
			enemy_state = enemies.get_enemies()
			hero_state = party.get_heroes()
			expected_enemy = enemy_result.duplicate(true)
			expected_hero = hero_result.duplicate(true)
		else:
			_check(enemy_result == expected_enemy and hero_result == expected_hero
				and enemies.get_enemies() == enemy_state and party.get_heroes() == hero_state,
				"independent identical fixtures replay complete results and roster snapshots")
		_check(attacker == attack_original and defender == defend_original,
			"both caller dictionaries preserve all status counts across replay")


## AC1-AC3: Tangled's flat +2 after the Weak/Exposed floor, on both the direct
## rules and the authoritative roster bridge, plus actor-local owner-turn ageing.
func _test_tangled_bonus_and_ageing() -> void:
	var rules := CombatStatuses.new()
	_check(rules.has_method("adjusted_attack_damage") and rules.has_method("end_owner_turn"),
		"tangled fixture drives the real CombatStatuses service")
	var direct_scenarios: Array[Dictionary] = [
		{"attacker": {}, "defender": {"tangled": 1}, "damage": 10,
			"label": "Tangled alone adds a flat 2"},
		{"attacker": {}, "defender": {"tangled": 3}, "damage": 10,
			"label": "Tangled N=3 still adds 2 once, never per stack"},
		{"attacker": {}, "defender": {"tangled": 0}, "damage": 8,
			"label": "Tangled 0 is inactive"},
		{"attacker": {"tangled": 5}, "defender": {}, "damage": 8,
			"label": "attacker-only Tangled adds nothing"},
		{"attacker": {"weak": 1}, "defender": {"tangled": 2}, "damage": 8,
			"label": "Weak floors 8 to 6 then adds 2"},
		{"attacker": {}, "defender": {"exposed": 1, "tangled": 1}, "damage": 14,
			"label": "Exposed raises 8 to 12 then adds 2"},
		{"attacker": {"weak": 1}, "defender": {"exposed": 1, "tangled": 1}, "damage": 11,
			"label": "Weak+Exposed floor once to 9 then adds 2"}
	]
	for scenario in direct_scenarios:
		var attacker: Dictionary = scenario["attacker"]
		var defender: Dictionary = scenario["defender"]
		var attacker_before := attacker.duplicate(true)
		var defender_before := defender.duplicate(true)
		_check(rules.adjusted_attack_damage(8, attacker, defender) == scenario["damage"],
			"8-base direct status maths: " + scenario["label"])
		_check(attacker == attacker_before and defender == defender_before,
			"direct 8-base status maths never mutates input: " + scenario["label"])
	_check(rules.adjusted_attack_damage(0, {}, {"tangled": 5}) == 0,
		"zero base damage never gains Tangled's 2")
	_check(rules.adjusted_attack_damage(1, {"weak": 1}, {"tangled": 5}) == 2,
		"positive base still gains Tangled after a single floor to zero")
	_check(rules.adjusted_attack_damage(9223372036854775807, {}, {"tangled": 1}) == 0,
		"unrepresentable Tangled-boosted damage fails closed instead of overflowing")

	# Real enemy: 6 base + Tangled 2 against four Block -> 4 absorbed, 4 HP lost.
	var enemies := _enemies()
	_check(enemies.gain_block(1, 4), "tangled enemy fixture has four Block")
	var untouched_enemies: Array[Dictionary] = [enemies.get_enemy(2), enemies.get_enemy(3)]
	var attacker := {"bleed": 1}
	var defender := {"tangled": 1}
	var attacker_before := attacker.duplicate(true)
	var defender_before := defender.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 246813579
	var rng_before := rng.state
	_check(attacks.resolve_vs_enemy(enemies, 1, 6, attacker, defender) == _event(8, 4, 4),
		"real enemy 6 + Tangled 2 absorbs four Block then loses four HP")
	_check(enemies.get_enemy(1)["hp"] == 8 and enemies.get_enemy(1)["block"] == 0,
		"real enemy authoritative HP and Block after Tangled hit")
	_check([enemies.get_enemy(2), enemies.get_enemy(3)] == untouched_enemies,
		"Tangled enemy hit leaves other positions untouched")
	_check(attacker == attacker_before and defender == defender_before,
		"Tangled enemy hit never ages or mutates supplied statuses")
	_check(rng.state == rng_before, "Tangled status attack leaves the run RNG untouched")

	# Control and inactive cases on fresh real enemies prove the +2 happens exactly once.
	var control := _enemies()
	_check(control.gain_block(1, 4), "control enemy fixture has four Block")
	_check(attacks.resolve_vs_enemy(control, 1, 6, {"tangled": 2}, {}) == _event(6, 4, 2),
		"attacker-only Tangled leaves the real enemy hit unchanged")
	var zero := _enemies()
	_check(zero.gain_block(1, 4), "zero-base enemy fixture has four Block")
	var zero_before := zero.get_enemies()
	_check(attacks.resolve_vs_enemy(zero, 1, 0, {}, {"tangled": 3}) == _event(0, 0, 0),
		"zero-base hit against Tangled is a successful zero result")
	_check(zero.get_enemies() == zero_before, "zero-base Tangled hit changes no HP or Block")
	var replay_a := _enemies()
	var replay_b := _enemies()
	_check(replay_a.gain_block(1, 4) and replay_b.gain_block(1, 4),
		"replay enemy fixtures both have four Block")
	_check(attacks.resolve_vs_enemy(replay_a, 1, 6, {}, {"tangled": 1})
		== attacks.resolve_vs_enemy(replay_b, 1, 6, {}, {"tangled": 1})
		and replay_a.get_enemies() == replay_b.get_enemies()
		and replay_a.get_enemy(1)["hp"] == 8,
		"independent identical Tangled hits produce the same receipt and roster")

	# Real hero: 8 base + Tangled 2 against six Block -> 6 absorbed, 4 HP lost.
	var party := _party()
	_check(party.gain_block(1, 6), "tangled hero fixture has six Block")
	var untouched_heroes: Array[Dictionary] = [party.get_hero(2), party.get_hero(3)]
	var hero_attacker := {}
	var hero_defender := {"tangled": 2}
	var hero_attacker_before := hero_attacker.duplicate(true)
	var hero_defender_before := hero_defender.duplicate(true)
	_check(attacks.resolve_vs_hero(party, 1, 8, hero_attacker, hero_defender) == _event(10, 6, 4),
		"real Warden absorbs six Block then loses four HP from 8 + Tangled 2")
	_check(party.get_hero(1)["hp"] == 36 and party.get_hero(1)["block"] == 0,
		"real Warden authoritative HP and Block after Tangled hit")
	_check([party.get_hero(2), party.get_hero(3)] == untouched_heroes,
		"Tangled hero hit leaves other heroes untouched")
	_check(hero_attacker == hero_attacker_before and hero_defender == hero_defender_before,
		"Tangled hero hit never ages or mutates supplied statuses")
	var plain_party := _party()
	_check(plain_party.gain_block(1, 6), "plain hero control has six Block")
	_check(attacks.resolve_vs_hero(plain_party, 1, 8, {"weak": 1}, {}) == _event(6, 6, 0),
		"the same weak hero hit without Tangled keeps its old 6 damage")

	# AC3: owner-local ageing, independent of Bleed, beside the other statuses.
	var statuses := {"tangled": 2}
	var statuses_before := statuses.duplicate(true)
	var first := rules.end_owner_turn(10, 7, statuses)
	_check(first == {"ok": true, "hp": 10, "block": 7,
		"statuses": {"tangled": 1}, "bleed_hp_loss": 0},
		"first owner turn ages Tangled 2 to 1 without touching HP or Block")
	var second := rules.end_owner_turn(first["hp"], first["block"], first["statuses"])
	_check(second == {"ok": true, "hp": 10, "block": 7,
		"statuses": {}, "bleed_hp_loss": 0},
		"second owner turn expires Tangled without touching HP or Block")
	_check(statuses == statuses_before, "two owner turns never mutate the caller's Tangled map")
	var mixed := {"bleed": 2, "weak": 1, "exposed": 2, "tangled": 2}
	var mixed_before := mixed.duplicate(true)
	var mixed_first := rules.end_owner_turn(10, 5, mixed)
	_check(mixed_first == {"ok": true, "hp": 8, "block": 5,
		"statuses": {"bleed": 1, "exposed": 1, "tangled": 1}, "bleed_hp_loss": 2},
		"Tangled ages beside Bleed/Weak/Exposed with unchanged Block")
	var mixed_second := rules.end_owner_turn(mixed_first["hp"], mixed_first["block"],
		mixed_first["statuses"])
	_check(mixed_second == {"ok": true, "hp": 7, "block": 5,
		"statuses": {}, "bleed_hp_loss": 1},
		"mixed statuses all expire after their owner turns")
	_check(mixed == mixed_before, "mixed owner-turn sequence preserves the caller's dictionary")
	var zero_turn := rules.end_owner_turn(4, 2, {"tangled": 0})
	_check(zero_turn == {"ok": true, "hp": 4, "block": 2,
		"statuses": {}, "bleed_hp_loss": 0},
		"Tangled 0 expires cleanly without affecting HP or Block")

	# AC4: malformed counters fail closed in both the rules and the real bridge.
	var bad_enemies := _enemies()
	var bad_party := _party()
	_check(bad_enemies.gain_block(1, 4) and bad_party.gain_block(1, 6),
		"malformed Tangled fixtures have living targets and Block")
	var bad_counters: Array[Dictionary] = [
		{"tangled": -1}, {"tangled": 1.5}, {"tangled": "1"}, {"tangled": true},
		{"tangled": null}, {"tangled": []}, {"tangled": {"n": 1}}, {"Tangled": 1},
		{"poison": 1}, {1: 2}
	]
	for bad in bad_counters:
		_check(rules.adjusted_attack_damage(8, {}, bad) == 0
			and rules.adjusted_attack_damage(8, bad, {}) == 0,
			"malformed Tangled fails closed for both roles: " + str(bad))
		var rejected := rules.end_owner_turn(10, 7, bad)
		_check(rejected["ok"] == false and rejected["statuses"] == bad,
			"malformed Tangled owner turn fails closed: " + str(bad))
		_reject_enemy(bad_enemies, 1, 6, {}, bad, "malformed Tangled defender: " + str(bad))
		_reject_enemy(bad_enemies, 1, 6, bad, {}, "malformed Tangled attacker: " + str(bad))
		_reject_hero(bad_party, 1, 8, {}, bad, "malformed Tangled hero defender: " + str(bad))
		_reject_hero(bad_party, 1, 8, bad, {}, "malformed Tangled hero attacker: " + str(bad))
	var dead_enemies := _enemies()
	_check(dead_enemies.apply_damage(2, 17) and dead_enemies.is_slain(2),
		"slain enemy fixture for Tangled is genuinely dead")
	_reject_enemy(dead_enemies, 2, 6, {}, {"tangled": 2},
		"slain enemy cannot receive a Tangled-boosted hit")
	var downed_party := _party()
	_check(downed_party.apply_damage(2, 30) and downed_party.is_downed(2),
		"downed hero fixture for Tangled is genuinely downed")
	_reject_hero(downed_party, 2, 8, {}, {"tangled": 2},
		"downed hero cannot receive a Tangled-boosted hit")


func _thorns_result(thorns: int, absorbed: int, loss: int) -> Dictionary:
	return {"ok": true, "applied": true, "thorns": thorns,
		"block_absorbed": absorbed, "hp_loss": loss}


func _no_thorns(thorns: int) -> Dictionary:
	return {"ok": true, "applied": false, "thorns": thorns,
		"block_absorbed": 0, "hp_loss": 0}


func _thorns_failure() -> Dictionary:
	return {"ok": false, "applied": false, "thorns": 0,
		"block_absorbed": 0, "hp_loss": 0}


## Real roster whose first enemy carries the representative Thorns fixture value.
## Pass null to omit the keyword entirely.
func _thorns_enemies(thorns: Variant) -> CombatEnemies:
	var definitions: Array = [
		{"id": "patch_imp", "max_hp": 12}, {"id": "stitch_foe", "max_hp": 17},
		{"id": "paper_foe", "max_hp": 21}]
	if thorns != null:
		definitions[0]["thorns"] = thorns
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid(), "thorns fixture roster is valid")
	return enemies


func _reject_thorns(rules: CombatEnemyKeywordRules, party: CombatParty, pos: int,
		enemy_record: Dictionary, receipt: Dictionary, reason: String) -> void:
	var heroes_before: Array[Dictionary] = []
	if party != null and party.is_valid():
		heroes_before = party.get_heroes()
	var enemy_before := enemy_record.duplicate(true)
	var receipt_before := receipt.duplicate(true)
	_check(rules.resolve_thorns_retaliation(party, pos, enemy_record, receipt) == _thorns_failure(),
		"thorns rejection: " + reason)
	if party != null and party.is_valid():
		_check(party.get_heroes() == heroes_before, "party unchanged on thorns rejection: " + reason)
	_check(enemy_record == enemy_before and receipt == receipt_before,
		"inputs unchanged on thorns rejection: " + reason)


func _test_thorns_retaliation() -> void:
	var rules := CombatEnemyKeywordRules.new()
	_check(rules.has_method("resolve_thorns_retaliation"),
		"scene-free Thorns rule exposes its documented method")
	_test_thorns_positive_paths(rules)
	_test_thorns_fail_closed(rules)
	_test_thorns_replay_and_rng(rules)


func _test_thorns_positive_paths(rules: CombatEnemyKeywordRules) -> void:
	# AC1: hero Block absorbs retaliation before HP (Block 2 vs Thorns 3 -> 1 HP lost).
	var party := _party()
	var enemies := _thorns_enemies(3)
	_check(party.gain_block(1, 2), "thorns fixture: Warden opens with Block 2")
	var pre_hit := enemies.get_enemy(1)
	var receipt := attacks.resolve_vs_enemy(enemies, 1, 5, {}, {})
	_check(receipt == _event(5, 0, 5), "thorns fixture: authentic confirmed 5-damage hit")
	var roster_before := enemies.get_enemies()
	var pre_hit_before := pre_hit.duplicate(true)
	var receipt_before := receipt.duplicate(true)
	var result := rules.resolve_thorns_retaliation(party, 1, pre_hit, receipt)
	_check(result == _thorns_result(3, 2, 1), "hero Block 2 absorbs Thorns 3 before HP (loss 1)")
	_check(party.get_hero(1)["hp"] == 39 and party.get_hero(1)["block"] == 0,
		"Warden authoritative HP and Block after retaliation")
	_check(party.get_hero(2)["hp"] == 30 and party.get_hero(3)["hp"] == 26,
		"unrelated heroes keep full HP after thorns")
	_check(enemies.get_enemies() == roster_before, "enemy ledger untouched by thorns")
	_check(pre_hit == pre_hit_before and receipt == receipt_before,
		"thorns leaves the pre-hit snapshot and receipt dictionaries intact")
	# A positive hit fully absorbed by ENEMY Block still triggers Thorns.
	var absorbed_party := _party()
	var absorbed_enemies := _thorns_enemies(3)
	_check(absorbed_enemies.gain_block(1, 10), "thorns fixture: enemy Block 10")
	var absorbed_pre := absorbed_enemies.get_enemy(1)
	var absorbed_hit := attacks.resolve_vs_enemy(absorbed_enemies, 1, 5, {}, {})
	_check(absorbed_hit == _event(5, 5, 0),
		"thorns fixture: positive hit fully absorbed by enemy Block")
	var absorbed_result := rules.resolve_thorns_retaliation(
		absorbed_party, 1, absorbed_pre, absorbed_hit)
	_check(absorbed_result == _thorns_result(3, 0, 3),
		"fully absorbed positive hit still triggers Thorns 3")
	_check(absorbed_party.get_hero(1)["hp"] == 37 and absorbed_party.get_hero(1)["block"] == 0,
		"Warden loses 3 HP to Thorns after an absorbed hit")
	# A lethal hit still triggers retaliation exactly once.
	var lethal_party := _party()
	var lethal_enemies := _thorns_enemies(3)
	var lethal_pre := lethal_enemies.get_enemy(1)
	var lethal_hit := attacks.resolve_vs_enemy(lethal_enemies, 1, 100, {}, {})
	_check(lethal_hit == _event(100, 0, 12) and lethal_enemies.is_slain(1),
		"thorns fixture: authentic lethal hit")
	var lethal_result := rules.resolve_thorns_retaliation(lethal_party, 1, lethal_pre, lethal_hit)
	_check(lethal_result == _thorns_result(3, 0, 3),
		"lethal hit triggers Thorns exactly once using the pre-hit snapshot")
	_check(lethal_party.get_hero(1)["hp"] == 37,
		"lethal-hit retaliation damages the living attacker")
	# Two separate confirmed hits each trigger their own retaliation, never aggregated.
	var split_party := _party()
	var split_enemies := _thorns_enemies(3)
	var first_pre := split_enemies.get_enemy(1)
	var first_hit := attacks.resolve_vs_enemy(split_enemies, 1, 4, {}, {})
	var first_result := rules.resolve_thorns_retaliation(split_party, 1, first_pre, first_hit)
	var second_pre := split_enemies.get_enemy(1)
	var second_hit := attacks.resolve_vs_enemy(split_enemies, 1, 4, {}, {})
	var second_result := rules.resolve_thorns_retaliation(split_party, 1, second_pre, second_hit)
	_check(first_result == _thorns_result(3, 0, 3) and second_result == _thorns_result(3, 0, 3),
		"each separate confirmed hit triggers its own Thorns 3")
	_check(split_party.get_hero(1)["hp"] == 34,
		"two hits cost 6 HP total instead of one aggregated retaliation")


func _test_thorns_fail_closed(rules: CombatEnemyKeywordRules) -> void:
	var good := _event(5, 0, 5)
	# AC2: explicit Thorns 0 is a successful zero-effect receipt.
	var zero_party := _party()
	var zero_enemies := _thorns_enemies(0)
	var zero_pre := zero_enemies.get_enemy(1)
	var zero_hit := attacks.resolve_vs_enemy(zero_enemies, 1, 5, {}, {})
	var zero_before := zero_party.get_heroes()
	_check(zero_hit == good, "zero-thorns fixture has a confirmed hit")
	_check(rules.resolve_thorns_retaliation(zero_party, 1, zero_pre, zero_hit) == _no_thorns(0),
		"explicit Thorns 0 returns a zero-effect receipt")
	_check(zero_party.get_heroes() == zero_before, "Thorns 0 leaves every hero untouched")
	# AC2: omitted Thorns is a successful zero-effect receipt.
	var plain_party := _party()
	var plain_enemies := _thorns_enemies(null)
	var plain_pre := plain_enemies.get_enemy(1)
	_check(not plain_pre.has("thorns"), "omitted-thorns fixture really has no keyword")
	var plain_hit := attacks.resolve_vs_enemy(plain_enemies, 1, 5, {}, {})
	var plain_before := plain_party.get_heroes()
	_check(plain_hit == good, "omitted-thorns fixture has a confirmed hit")
	_check(rules.resolve_thorns_retaliation(plain_party, 1, plain_pre, plain_hit) == _no_thorns(0),
		"absent Thorns returns a zero-effect receipt quoting 0")
	_check(plain_party.get_heroes() == plain_before, "absent Thorns leaves every hero untouched")
	# AC2: a confirmed zero-damage result never retaliates.
	var zd_party := _party()
	var zd_enemies := _thorns_enemies(3)
	var zd_pre := zd_enemies.get_enemy(1)
	var zd_hit := attacks.resolve_vs_enemy(zd_enemies, 1, 0, {}, {})
	var zd_before := zd_party.get_heroes()
	_check(zd_hit == _event(0, 0, 0), "zero-damage fixture is a successful zero hit")
	_check(rules.resolve_thorns_retaliation(zd_party, 1, zd_pre, zd_hit) == _no_thorns(3),
		"confirmed zero damage causes no retaliation")
	_check(zd_party.get_heroes() == zd_before, "zero-damage hit leaves every hero untouched")
	# AC2: failed attacks are rejected, never treated as a zero-effect hit.
	var failed_party := _party()
	var failed_enemies := _thorns_enemies(3)
	_check(failed_enemies.apply_damage(1, 12) and failed_enemies.is_slain(1),
		"failed-attack fixture has a slain defender")
	var failed_pre := failed_enemies.get_enemy(1)
	var failed_hit := attacks.resolve_vs_enemy(failed_enemies, 1, 5, {}, {})
	_check(failed_hit == _failure(), "failed-attack fixture really fails")
	_reject_thorns(rules, failed_party, 1, failed_pre, failed_hit, "failed attack receipt")
	# AC2: malformed receipts fail closed.
	var malformed_party := _party()
	var enemy_record := {"id": "patch_imp", "hp": 12, "block": 0, "thorns": 3}
	var malformed: Array[Dictionary] = [
		{}, {"ok": true}, {"damage": 5, "block_absorbed": 0, "hp_loss": 5},
		{"ok": "yes", "damage": 5, "block_absorbed": 0, "hp_loss": 5},
		{"ok": 1, "damage": 5, "block_absorbed": 0, "hp_loss": 5},
		{"ok": true, "damage": -1, "block_absorbed": 0, "hp_loss": 0},
		{"ok": true, "damage": 5.5, "block_absorbed": 0, "hp_loss": 5},
		{"ok": true, "damage": 5, "block_absorbed": -1, "hp_loss": 5},
		{"ok": true, "damage": 5, "block_absorbed": 0, "hp_loss": -1},
		{"ok": true, "damage": 5, "block_absorbed": 0, "hp_loss": 5.0}
	]
	for bad_receipt in malformed:
		_reject_thorns(rules, malformed_party, 1, enemy_record, bad_receipt,
			"malformed receipt " + str(bad_receipt))
	# AC2: malformed enemy records fail closed.
	var enemy_party := _party()
	for bad_enemy in [{}, {"hp": -1, "thorns": 3}, {"hp": 12, "block": -2, "thorns": 3},
			{"hp": "12", "thorns": 3}]:
		_reject_thorns(rules, enemy_party, 1, bad_enemy, good,
			"malformed enemy record " + str(bad_enemy))
	# AC2: negative/noninteger Thorns values are rejected.
	for bad_thorns in [-1, 1.5, "3", true]:
		_reject_thorns(rules, enemy_party, 1,
			{"id": "patch_imp", "hp": 12, "block": 0, "thorns": bad_thorns}, good,
			"invalid Thorns " + str(bad_thorns))
	# AC2: bad attacker positions and a downed attacker fail closed.
	var pos_party := _party()
	for pos in [-1, 0, 4]:
		_reject_thorns(rules, pos_party, pos, enemy_record, good,
			"bad attacker position %d" % pos)
	var downed_party := _party()
	_check(downed_party.apply_damage(1, 40) and downed_party.is_downed(1),
		"downed-attacker fixture really is downed")
	_reject_thorns(rules, downed_party, 1, enemy_record, good, "downed attacker")
	# AC2: null and invalid parties fail closed.
	_reject_thorns(rules, null, 1, enemy_record, good, "null party")
	var invalid_party := CombatParty.new([])
	_check(not invalid_party.is_valid(), "invalid party fixture really is invalid")
	_reject_thorns(rules, invalid_party, 1, enemy_record, good, "invalid party")


func _test_thorns_replay_and_rng(rules: CombatEnemyKeywordRules) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 987654321
	var state_before := rng.state
	var first_receipt: Dictionary = {}
	var first_heroes: Array[Dictionary] = []
	for repeat in range(2):
		var party := _party()
		_check(party.gain_block(1, 2), "replay fixture: Warden Block 2")
		var enemies := _thorns_enemies(3)
		var pre_hit := enemies.get_enemy(1)
		var hit := attacks.resolve_vs_enemy(enemies, 1, 5, {}, {})
		var result := rules.resolve_thorns_retaliation(party, 1, pre_hit, hit)
		_check(result == _thorns_result(3, 2, 1),
			"replay %d: deterministic thorns receipt" % repeat)
		if repeat == 0:
			first_receipt = result.duplicate(true)
			first_heroes = party.get_heroes()
		else:
			_check(result == first_receipt and party.get_heroes() == first_heroes,
				"independent identical fixtures replay identical receipt and party snapshot")
	_check(rng.state == state_before, "Thorns rule leaves the run RNG untouched")
