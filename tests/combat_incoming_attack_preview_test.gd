extends SceneTree

var failures: Array[String] = []
var checks := 0
var helper := CombatIncomingAttackPreview.new()


func _initialize() -> void:
	_run()
	for problem in failures:
		printerr(problem)
	print("combat_incoming_attack_preview_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _party() -> CombatParty:
	return CombatParty.new([{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30}, {"id": "tinker", "max_hp": 26}])


func _enemies() -> CombatEnemies:
	return CombatEnemies.new([{"id": "one", "max_hp": 12}, {"id": "two", "max_hp": 12}])


func _attack(source: int, amount: int, target: int) -> Dictionary:
	return {"type": "attack", "enemy_position": source, "amount": amount, "target_position": target}


func _block(source: int, amount: int) -> Dictionary:
	return {"type": "block", "enemy_position": source, "amount": amount}


func _compare(party: CombatParty, enemies: CombatEnemies, intents: Array, label: String) -> Dictionary:
	_check(party.is_valid() and enemies.is_valid() and intents.size() == enemies.get_enemies().size(),
		label + ": real combat preconditions")
	var heroes := party.get_heroes()
	var roster := enemies.get_enemies()
	var heroes_before := heroes.duplicate(true)
	var roster_before := roster.duplicate(true)
	var intents_before := intents.duplicate(true)
	seed(73451)
	var expected_random := randi()
	seed(73451)
	var result := helper.forecast(heroes, roster, intents)
	_check(result["ok"] and result["heroes"].size() == 3, label + ": supported forecast has all fixed hero positions")
	_check(heroes == heroes_before and roster == roster_before and intents == intents_before
		and party.get_heroes() == heroes_before and enemies.get_enemies() == roster_before,
		label + ": all caller records and owner states remain exactly unchanged")
	_check(randi() == expected_random, label + ": forecast uses no global seeded RNG")
	if not result["ok"]:
		return result
	var round_result := CombatEnemyPhase.new().execute_phase(party, enemies, intents)
	_check(round_result["ok"], label + ": real CombatEnemyPhase accepts identical intents")
	for index in range(3):
		var actual := party.get_hero(index + 1)
		var predicted: Dictionary = result["heroes"][index]
		_check(predicted["position"] == index + 1 and predicted["hp_remaining"] == actual["hp"]
			and predicted["block_remaining"] == actual["block"], label + ": predicted immediate HP/Block matches real hero " + str(index + 1))
		_check(predicted["block_absorbed"] + predicted["hp_lost"] <= predicted["incoming"],
			label + ": absorbed and lost never exceed incoming")
	return result


func _reject(heroes: Array, enemies: Array, intents: Array, label: String) -> void:
	var snapshot := [heroes.duplicate(true), enemies.duplicate(true), intents.duplicate(true)]
	seed(185)
	var expected_random := randi()
	seed(185)
	var result := helper.forecast(heroes, enemies, intents)
	_check(result == {"ok": false, "heroes": []}, label + ": fails closed with no plausible prediction")
	_check([heroes, enemies, intents] == snapshot and randi() == expected_random,
		label + ": invalid read does not mutate inputs or RNG")


func _run() -> void:
	_check(helper.has_method("forecast"), "public scene-free forecast method available")
	var party := _party()
	var enemies := _enemies()
	_check(CombatStartingBlock.new(party).apply(), "real Warden starts at six Block")
	var result := _compare(party, enemies, [_attack(2, 5, 1), _attack(1, 4, 1)], "two hits shuffled")
	_check(result["ok"] and result["heroes"][0] == {"position": 1, "downed": false,
		"incoming": 9, "block_absorbed": 6, "hp_lost": 3, "hp_remaining": 37, "block_remaining": 0},
		"4 then 5 consume six Block and exactly three Warden HP")
	_check(result["heroes"][1]["incoming"] == 0 and result["heroes"][2]["hp_remaining"] == 26,
		"unattacked positions retain independent states")

	party = _party()
	enemies = _enemies()
	_check(party.gain_block(2, 2) and enemies.apply_damage(1, 12),
		"one source slain, protected second target preconditions")
	result = _compare(party, enemies, [_attack(1, 99, 1), _attack(2, 5, 2)], "slain source")
	_check(result["heroes"][0]["incoming"] == 0 and result["heroes"][1]["block_absorbed"] == 2
		and result["heroes"][1]["hp_lost"] == 3, "slain source skipped, living position two honored")
	party = _party()
	enemies = _enemies()
	_check(party.apply_damage(2, 30) and party.gain_block(3, 3), "downed stays at position two")
	result = _compare(party, enemies, [_attack(1, 8, 2), _attack(2, 4, 3)], "downed target")
	_check(result["heroes"][1]["downed"] and result["heroes"][1]["incoming"] == 0
		and result["heroes"][2]["block_absorbed"] == 3 and result["heroes"][2]["hp_lost"] == 1,
		"no target compaction, separate living target takes attack")
	party = _party()
	enemies = _enemies()
	result = _compare(party, enemies, [_attack(1, 0, 1), _block(2, 5)], "zero attack and Block intent")
	_check(result["heroes"][0]["incoming"] == 0 and enemies.get_enemy(2)["block"] == 5,
		"zero attack harmless; enemy Block action never adds hero incoming")
	party = _party()
	enemies = _enemies()
	_check(party.apply_damage(1, 36), "lethal sequence setup")
	result = _compare(party, enemies, [_attack(1, 9, 1), _attack(2, 5, 1)], "lethal first hit")
	_check(result["heroes"][0]["incoming"] == 9 and result["heroes"][0]["hp_lost"] == 4
		and result["heroes"][0]["hp_remaining"] == 0, "later source skips newly downed target")

	var heroes := _party().get_heroes()
	var roster := _enemies().get_enemies()
	var normal := [_attack(1, 1, 1), _block(2, 1)]
	_reject([], roster, normal, "empty heroes")
	_reject(heroes, [], normal, "empty enemies")
	_reject(heroes, roster, [], "missing announcements")
	var wrong_hero := heroes.duplicate(true)
	wrong_hero[0]["position"] = 0
	_reject(wrong_hero, roster, normal, "zero hero position")
	wrong_hero = heroes.duplicate(true)
	wrong_hero[1]["position"] = 1
	_reject(wrong_hero, roster, normal, "duplicated hero position")
	var wrong_enemy := roster.duplicate(true)
	wrong_enemy[1]["position"] = 3
	_reject(heroes, wrong_enemy, normal, "out-of-roster enemy position")
	for bad in [
		[_attack(1, 1, 0), _block(2, 1)],
		[_attack(1, 1, 4), _block(2, 1)],
		[_attack(1, -1, 1), _block(2, 1)],
		[_attack(1, 1, 1), _block(1, 1)],
		[_attack(1, 1, 1), _block(3, 1)],
		[{"type": "heal", "enemy_position": 1, "amount": 3}, _block(2, 1)],
		[_attack(1, 1, 1), {"type": "block", "enemy_position": 2, "amount": 1, "target_position": 1}],
		[_attack(1, 1, 1), {"type": "attack", "enemy_position": 2, "amount": 4}],
		[_attack(1, 1, 1), {"type": "block", "enemy_position": 2, "amount": 1.0}],
		[_attack(1, 1, 1), null]
	]:
		_reject(heroes, roster, bad, "bad intent " + str(bad))
