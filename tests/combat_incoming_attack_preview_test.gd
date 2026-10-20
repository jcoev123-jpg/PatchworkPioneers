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
	for repeat in range(3):
		_check(helper.forecast(heroes, enemies, intents) == result, label + ": repeat rejects identically")
	_check([heroes, enemies, intents] == snapshot and randi() == expected_random,
		label + ": invalid read does not mutate inputs or RNG")


func _run() -> void:
	_round_flow_cases()
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
	for bad_status in [null, [], {"bleed": -1}, {"weak": 1.5}, {"exposed": true}, {"unknown": 1}, {1: 2}]:
		for side in ["heroes", "enemies"]:
			var bad_heroes := heroes.duplicate(true)
			var bad_enemies := roster.duplicate(true)
			(bad_heroes if side == "heroes" else bad_enemies)[-1]["statuses"] = bad_status
			_reject(bad_heroes, bad_enemies, normal, "invalid late status " + side + str(bad_status))
	for field in ["id", "max_hp", "hp", "block"]:
		var bad_actor := heroes.duplicate(true)
		bad_actor[-1][field] = null
		_reject(bad_actor, roster, normal, "invalid actor " + field)
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


func _load_actors(path: String) -> Array:
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	for record in records:
		record["max_hp"] = int(record["max_hp"])
	return records


func _flow_state(flow: CombatRoundFlow, rng: RandomNumberGenerator) -> Array:
	return [flow._party.get_heroes(), flow._enemies.get_enemies(),
		flow._deck.hand.duplicate(), flow._deck.draw_pile.duplicate(),
		flow._deck.discard_pile.duplicate(), flow._deck.energy, flow._deck.turn_active,
		flow._intents._definitions.duplicate(true), flow._intents._turn_index,
		flow.get_outcome(), rng.state]


func _round_flow_cases() -> void:
	for scenario in ["weak", "exposed2", "exposed1", "combined", "bleed_slot", "lethal_bleed", "mixed", "ordered"]:
		var replay: Array = []
		for repeat in range(2):
			var party := CombatParty.new(_load_actors("res://data/heroes/starter_party.json"))
			var enemies := CombatEnemies.new(_load_actors("res://data/enemies/starter_enemies.json"))
			var rng := RandomNumberGenerator.new()
			rng.seed = 49049
			var deck := CombatDeck.new(StarterCards.new().get_starting_deck(), rng)
			var second := {"type": "block", "amount": 1}
			if scenario == "ordered":
				second = {"type": "attack", "amount": 5, "target_position": 1}
			var scheduler := CombatEnemyIntents.new([
				{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 7, "target_position": 1}]},
				{"enemy_position": 2, "pattern": [second]}])
			var outcome := CombatBattleResult.new(party, enemies)
			var flow := CombatRoundFlow.new(deck, party, enemies, scheduler, outcome)
			_check(party.is_valid() and enemies.is_valid() and scheduler.is_valid() and flow.begin_fight(), scenario + ": real authored fight begins")
			if scenario in ["weak", "combined", "mixed"]:
				enemies._enemies[0]["statuses"] = {"weak": 1, "bleed": 1}
			if scenario in ["exposed2", "combined", "mixed"]:
				party._heroes[0]["statuses"] = {"exposed": 2, "bleed": 2}
			if scenario == "exposed1":
				party._heroes[0]["statuses"] = {"exposed": 1}
			if scenario in ["bleed_slot", "lethal_bleed"]:
				for index in range(3 if scenario == "lethal_bleed" else 1):
					party._heroes[index]["hp"] = 2
					party._heroes[index]["statuses"] = {"bleed": 3}
			if scenario == "ordered":
				party._heroes[0]["hp"] = 1
			var before := _flow_state(flow, rng)
			var heroes := party.get_heroes()
			var roster := enemies.get_enemies()
			var intents := scheduler.get_intents()
			intents.reverse() # Forecast must preserve source order even for shuffled input.
			var inputs := [heroes.duplicate(true), roster.duplicate(true), intents.duplicate(true)]
			var invalid_roster := roster.duplicate(true)
			invalid_roster[-1]["statuses"] = {"weak": -1}
			_reject(heroes, invalid_roster, intents, scenario + ": invalid last enemy after hero Bleed preflight")
			var invalid_intents := intents.duplicate(true)
			invalid_intents[-1]["amount"] = -1
			_reject(heroes, roster, invalid_intents, scenario + ": invalid announcement after owner tick")
			_check(_flow_state(flow, rng) == before, scenario + ": rejected previews preserve complete live battle")
			seed(493)
			var expected_global := randi()
			seed(493)
			var prediction := helper.forecast(heroes, roster, intents)
			for refresh in range(4):
				_check(helper.forecast(heroes, roster, intents) == prediction, scenario + ": repeated forecast identical")
			_check(prediction["ok"] and [heroes, roster, intents] == inputs
				and _flow_state(flow, rng) == before and randi() == expected_global, scenario + ": exact full-state and RNG purity")
			if not prediction["ok"]:
				continue
			var expected_incoming := 7
			if scenario == "weak":
				expected_incoming = 5
			elif scenario == "exposed2":
				expected_incoming = 10
			elif scenario in ["combined", "mixed"]:
				expected_incoming = 7 # floor(7 * 9/8), not floor(7 * 3/4) * 3/2.
			elif scenario in ["bleed_slot", "lethal_bleed"]:
				expected_incoming = 0
			_check(prediction["heroes"][0]["incoming"] == expected_incoming, scenario + ": exact adjusted attack amount")
			_check(flow.end_turn(), scenario + ": real End Turn commits")
			for index in range(3):
				var predicted: Dictionary = prediction["heroes"][index]
				var actual := party.get_hero(index + 1)
				var bleed_loss: int = mini(heroes[index]["hp"], heroes[index].get("statuses", {}).get("bleed", 0))
				_check(actual["hp"] == predicted["hp_remaining"]
					and heroes[index]["hp"] - actual["hp"] == bleed_loss + predicted["hp_lost"], scenario + ": attack HP excludes Bleed exactly once")
				_check(predicted["block_remaining"] == heroes[index]["block"] - predicted["block_absorbed"]
					and actual["block"] == (0 if outcome.can_continue() else predicted["block_remaining"]), scenario + ": Block absorption then next-player reset")
			if scenario == "lethal_bleed":
				_check(flow.get_outcome() == CombatBattleResult.DEFEAT and enemies.get_enemy(2)["block"] == 0
					and scheduler._turn_index == 0 and not deck.turn_active, "lethal owner Bleed skips complete enemy phase and draw")
			else:
				_check(enemies.get_enemy(2)["block"] == (0 if scenario == "ordered" else 1), scenario + ": mixed enemy Block committed")
			var after := _flow_state(flow, rng)
			if repeat == 0:
				replay = after
			else:
				_check(after == replay, scenario + ": same-seed full-state replay")
