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
	_test_immutable_snapshots_and_replay()
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
		{"weak": []}, {"bleed": {"nested": [1, 2]}}
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
