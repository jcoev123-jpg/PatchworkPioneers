extends SceneTree

const M02_MIXED_PATH := "res://data/encounters/m02_mixed_intents.json"

var failures: Array[String] = []
var checks := 0
var helper := CombatIncomingAttackPreview.new()
var authored: Array = []


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
	_mixed_cases()
	_four_foe_cases()


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


## Authored mixed-intent beats are read from the shipped encounter and legally
## re-homed onto source slots; no timing relation beyond one beat per source.
func _load_authored() -> void:
	authored = JSON.parse_string(FileAccess.get_file_as_string(M02_MIXED_PATH))
	_check(authored is Array and authored.size() == 2, "authored mixed encounter announces two sources")
	if not authored is Array or authored.size() != 2:
		return
	for definition in authored:
		_check(definition["enemy_position"] == floor(definition["enemy_position"]),
			"authored enemy position is integral before conversion")
		definition["enemy_position"] = int(definition["enemy_position"])
		for action in definition["pattern"]:
			for field in ["amount", "target_position", "direction"]:
				if action.has(field):
					_check(action[field] == floor(action[field]), "authored " + field + " is integral before conversion")
					action[field] = int(action[field])


func _beat(origin_source: int, beat: int) -> Dictionary:
	var action: Dictionary = authored[origin_source - 1]["pattern"][beat].duplicate(true)
	action["enemy_position"] = origin_source
	return action


func _beat_at(origin_source: int, beat: int, source: int) -> Dictionary:
	var action := _beat(origin_source, beat)
	action["enemy_position"] = source
	return action


## One announced beat per source, produced by a real CombatEnemyIntents.
func _scheduled(actions: Array) -> Array:
	var definitions: Array = []
	for action in actions:
		var pattern: Dictionary = action.duplicate(true)
		var source: int = pattern["enemy_position"]
		pattern.erase("enemy_position")
		definitions.append({"enemy_position": source, "pattern": [pattern]})
	var scheduler := CombatEnemyIntents.new(definitions)
	_check(scheduler.is_valid(), "legal authored mixed schedule " + str(actions))
	return scheduler.get_intents()


func _three_enemies() -> CombatEnemies:
	return CombatEnemies.new([{"id": "one", "max_hp": 12}, {"id": "two", "max_hp": 12},
		{"id": "three", "max_hp": 12}])


## Forecast purity plus the real committed phase, compared by original hero id.
func _compare_mixed(party: CombatParty, enemies: CombatEnemies, intents: Array, label: String) -> Dictionary:
	_check(party.is_valid() and enemies.is_valid() and intents.size() == enemies.get_enemies().size(),
		label + ": real combat preconditions")
	var heroes := party.get_heroes()
	var roster := enemies.get_enemies()
	var presented: Array = heroes.duplicate(true)
	var heroes_before := heroes.duplicate(true)
	var roster_before := roster.duplicate(true)
	var intents_before := intents.duplicate(true)
	seed(73451)
	var expected_random := randi()
	seed(73451)
	var result := helper.forecast(heroes, roster, intents)
	for refresh in range(4):
		_check(helper.forecast(heroes, roster, intents) == result, label + ": repeated mixed forecast identical")
	_check(heroes == heroes_before and roster == roster_before and intents == intents_before
		and party.get_heroes() == heroes_before and enemies.get_enemies() == roster_before,
		label + ": mixed forecast leaves every caller record and owner state unchanged")
	_check(randi() == expected_random, label + ": mixed forecast uses no global seeded RNG")
	_check(result["ok"] and result["heroes"].size() == CombatParty.PARTY_SIZE,
		label + ": valid mixed roster is forecast, never unavailable")
	if not result["ok"]:
		return result
	# Equivalent preconditions for the real phase: the ordered End Turn flow
	# advances and commits the hero owner tick before the announced phase.
	var tick := CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())
	_check(tick["ok"], label + ": real hero owner tick preflight")
	if not tick["ok"]:
		return result
	for index in range(CombatParty.PARTY_SIZE):
		party._heroes[index]["hp"] = tick["actors"][index]["hp"]
		party._heroes[index]["block"] = tick["actors"][index]["block"]
		party._heroes[index]["statuses"] = tick["actors"][index]["statuses"]
	var phase := CombatEnemyPhase.new().execute_phase(party, enemies, intents)
	_check(phase["ok"], label + ": real CombatEnemyPhase accepts the same mixed roster")
	if not phase["ok"]:
		return result
	var actual: Dictionary = {}
	for hero in party.get_heroes():
		actual[hero["id"]] = hero
	for index in range(CombatParty.PARTY_SIZE):
		var hero_id: String = presented[index]["id"]
		var predicted: Dictionary = result["heroes"][index]
		var after: Dictionary = actual[hero_id]
		_check(predicted["position"] == index + 1 and predicted["downed"] == (after["hp"] == 0),
			label + ": entry " + hero_id + " stays on its presented slot")
		_check(predicted["hp_remaining"] == after["hp"] and predicted["block_remaining"] == after["block"],
			label + ": predicted HP and Block belong to original hero " + hero_id)
		_check(predicted["block_absorbed"] + predicted["hp_lost"] <= predicted["incoming"]
			and predicted["hp_lost"] <= presented[index]["hp"] and predicted["block_absorbed"] >= 0,
			label + ": attack totals stay consistent for " + hero_id)
	return result


func _reject_mixed(party: CombatParty, enemies: CombatEnemies, intents: Array, label: String) -> void:
	var models := [party.get_heroes(), enemies.get_enemies()]
	_reject(party.get_heroes(), enemies.get_enemies(), intents, label)
	_check(party.is_valid() and enemies.is_valid()
		and [party.get_heroes(), enemies.get_enemies()] == models,
		label + ": rejected mixed forecast retains both real models")


func _mixed_cases() -> void:
	_load_authored()
	if authored.size() != 2:
		return
	# Shuffled announcement: Enemy 1 shoves the front back, then Enemy 2 attacks
	# the NEW front occupant. Totals must follow hero identity, not the slot.
	var party := _party()
	var enemies := _enemies()
	_check(CombatStartingBlock.new(party).apply() and party.gain_block(2, 2),
		"Warden six Block and Seamstress two Block preconditions")
	var shuffled := _scheduled([_beat(1, 0), _beat(2, 1)])
	shuffled.reverse()
	var result := _compare_mixed(party, enemies, shuffled, "shove then attack new occupant")
	_check(result["ok"] and result["heroes"][0] == {"position": 1, "downed": false, "incoming": 0,
		"block_absorbed": 0, "hp_lost": 0, "hp_remaining": 40, "block_remaining": 6},
		"unattacked Warden keeps his own six Block and full HP")
	_check(result["ok"] and result["heroes"][1] == {"position": 2, "downed": false, "incoming": 5,
		"block_absorbed": 2, "hp_lost": 3, "hp_remaining": 27, "block_remaining": 0},
		"attack after shove is Seamstress's by id, never Warden's by slot")
	_check(result["ok"] and result["heroes"][2] == {"position": 3, "downed": false, "incoming": 0,
		"block_absorbed": 0, "hp_lost": 0, "hp_remaining": 26, "block_remaining": 0},
		"uninvolved Tinker keeps an independent identical row")
	_check(party.get_hero(1)["id"] == "seamstress" and party.get_hero(2)["id"] == "warden"
		and party.get_hero(1)["hp"] == 27 and party.get_hero(1)["block"] == 0
		and party.get_hero(2)["hp"] == 40 and party.get_hero(2)["block"] == 6,
		"real phase itself swaps identities and attributes the absorbed/lost points")

	# Authored Exposed debuff legally announced before the authored 5 damage.
	party = _party()
	enemies = _enemies()
	result = _compare_mixed(party, enemies, _scheduled([_beat_at(2, 0, 1), _beat(2, 1)]),
		"Exposed then attack")
	_check(result["ok"] and result["heroes"][0]["incoming"] == 7
		and result["heroes"][0]["hp_lost"] == 7 and result["heroes"][0]["hp_remaining"] == 33,
		"same-phase Exposed raises the later attack to floor(5 * 3/2)")
	_check(party.get_hero(1)["statuses"] == {"exposed": 2},
		"real phase keeps the applied Exposed count on Warden's id")

	# Weak and Exposed combine before a single floor: floor(5 * 9/8) = 5.
	party = _party()
	enemies = _enemies()
	enemies._enemies[1]["statuses"] = {"weak": 1}
	party._heroes[0]["statuses"] = {"exposed": 2}
	result = _compare_mixed(party, enemies, _scheduled([_beat(1, 1), _beat(2, 1)]),
		"weak and exposed attacker")
	_check(result["ok"] and result["heroes"][0]["incoming"] == 5
		and result["heroes"][0]["hp_lost"] == 5,
		"Weak and Exposed multiply then round down exactly once")

	# A downed target stays in its slot and no attack is redirected to it.
	party = _party()
	enemies = _enemies()
	_check(party.apply_damage(2, 30), "downed attack target precondition")
	var downed_attack := _beat(2, 1)
	downed_attack["target_position"] = 2
	result = _compare_mixed(party, enemies, [_beat(1, 1), downed_attack],
		"downed attack target")
	_check(result["ok"] and result["heroes"][1]["downed"]
		and result["heroes"][1]["incoming"] == 0 and result["heroes"][0]["incoming"] == 0
		and result["heroes"][2]["incoming"] == 0,
		"attack on a downed hero is skipped without attacking another slot")

	# A non-damaging Block source plus a Weak attacker.
	party = _party()
	enemies = _enemies()
	enemies._enemies[1]["statuses"] = {"weak": 1}
	result = _compare_mixed(party, enemies, _scheduled([_beat(1, 2), _beat(2, 1)]),
		"Block source and Weak attacker")
	_check(result["ok"] and result["heroes"][0]["incoming"] == 3
		and result["heroes"][0]["hp_lost"] == 3 and result["heroes"][0]["hp_remaining"] == 37,
		"Weak lowers the enemy attack to floor(5 * 3/4)")
	_check(enemies.get_enemy(1)["block"] == 2,
		"real phase commits the authored Block on its own source")

	# Non-damaging buff and Block sources forecast zero hero incoming.
	party = _party()
	enemies = _enemies()
	result = _compare_mixed(party, enemies, _scheduled([_beat(1, 1), _beat(2, 4)]),
		"buff and Block sources")
	_check(result["ok"] and result["heroes"][0]["incoming"] == 0
		and result["heroes"][1]["incoming"] == 0 and result["heroes"][2]["incoming"] == 0,
		"valid buff and Block roster is forecast with no plausible hero damage")
	_check(enemies.get_enemy(1)["block"] == 3 and enemies.get_enemy(2)["block"] == 1,
		"real phase adds buff and Block to their respective enemies")

	# Enemy-applied Bleed is deferred owner-turn loss, never attack HP loss.
	party = _party()
	enemies = _enemies()
	result = _compare_mixed(party, enemies, _scheduled([_beat_at(2, 2, 1), _beat(2, 4)]),
		"Bleed debuff")
	_check(result["ok"] and result["heroes"][1]["incoming"] == 0
		and result["heroes"][1]["hp_lost"] == 0 and result["heroes"][1]["hp_remaining"] == 30,
		"Bleed applied by an enemy is not an immediate incoming attack loss")
	_check(party.get_hero(2)["statuses"] == {"bleed": 2}
		and CombatStatuses.new().end_owner_turn(30, 0, {"bleed": 2})["bleed_hp_loss"] == 2,
		"real phase stores Bleed for the owner's own later turn end")

	# A slain source acts on nothing; the line does not move and nobody retargets.
	party = _party()
	enemies = _enemies()
	_check(CombatStartingBlock.new(party).apply() and enemies.apply_damage(1, 12),
		"slain mixed source preconditions")
	result = _compare_mixed(party, enemies, _scheduled([_beat(1, 0), _beat(2, 1)]),
		"slain shove source")
	_check(result["ok"] and result["heroes"][0]["incoming"] == 5
		and result["heroes"][0]["block_absorbed"] == 5 and result["heroes"][0]["hp_lost"] == 0
		and result["heroes"][0]["hp_remaining"] == 40,
		"slain shove source does nothing and the fixed front absorbs the attack")
	_check(party.get_hero(1)["id"] == "warden" and result["heroes"][1]["incoming"] == 0,
		"no swap or retarget follows a slain source")

	# A slain source's would-be illegal shove is inert, exactly like the phase.
	party = _party()
	enemies = _enemies()
	_check(party.apply_damage(2, 30) and enemies.apply_damage(1, 12),
		"downed neighbour and slain shove source preconditions")
	result = _compare_mixed(party, enemies, _scheduled([_beat(1, 0), _beat(2, 1)]),
		"slain illegal shove stays inert")
	_check(result["ok"] and party.get_hero(1)["id"] == "warden"
		and result["heroes"][0]["incoming"] == 5 and result["heroes"][1]["incoming"] == 0,
		"slain shove does not reject a roster the committed phase accepts")

	# Three sources, announced out of order, still resolve in ascending order.
	party = _party()
	enemies = _three_enemies()
	var three := _scheduled([_beat(1, 1), _beat(2, 3), _beat_at(2, 4, 3)])
	var shuffled_three: Array = [three[2], three[0], three[1]]
	result = _compare_mixed(party, enemies, shuffled_three, "three shuffled mixed sources")
	_check(result["ok"] and result["heroes"][2]["incoming"] == 4
		and result["heroes"][2]["hp_remaining"] == 22 and result["heroes"][0]["incoming"] == 0,
		"shuffled three-source roster keeps ascending per-source effects")
	_check(enemies.get_enemy(1)["block"] == 3 and enemies.get_enemy(3)["block"] == 1,
		"real phase offsets the buff and Block onto their own slots")

	# A single valid source is still forecast, not treated as unsupported.
	party = _party()
	var single := CombatEnemies.new([{"id": "one", "max_hp": 12}])
	result = _compare_mixed(party, single, _scheduled([_beat(1, 1)]), "single buff source")
	_check(result["ok"] and result["heroes"][0]["incoming"] == 0
		and single.get_enemy(1)["block"] == 3, "one-source mixed roster stays available")

	# Illegal mixed rosters fail closed without touching models or both RNGs.
	party = _party()
	enemies = _enemies()
	_check(party.apply_damage(2, 30), "downed middle precondition")
	_reject_mixed(party, enemies, _scheduled([_beat(1, 0), _beat(2, 1)]),
		"authored shove into a downed neighbour")
	party = _party()
	enemies = _enemies()
	_reject_mixed(party, enemies, [_beat(1, 0), {"type": "shove", "enemy_position": 2,
		"amount": 0, "target_position": 3, "direction": 1}], "authored-style shove off the back edge")
	party = _party()
	enemies = _enemies()
	_check(party.apply_damage(1, 40), "downed front precondition")
	_reject_mixed(party, enemies, _scheduled([_beat_at(2, 0, 1), _beat(2, 1)]),
		"debuff against a downed hero")
	party = _party()
	enemies = _enemies()
	_reject_mixed(party, enemies, [_beat(1, 0), _beat_at(1, 1, 1)], "duplicate mixed source")
	_reject_mixed(party, enemies, [_beat(1, 0)], "missing mixed source")
	party = _party()
	enemies = _enemies()
	_check(party.apply_damage(3, 26), "downed back precondition")
	_reject_mixed(party, enemies, [_beat(1, 1), {"type": "debuff", "enemy_position": 2,
		"amount": 2, "target_position": 3, "status": "bleed"}],
		"invalid late mixed action after an earlier legal source")
	_reject_mixed(party, enemies, [_beat(1, 1), {"type": "heal", "enemy_position": 2, "amount": 3}],
		"late unknown mixed kind")
	_reject_mixed(party, enemies, [_beat(1, 1), {"type": "shove", "enemy_position": 2,
		"amount": 0, "target_position": 3, "direction": 1}], "late mixed shove at the edge")
	for bad in [
		{"type": "debuff", "enemy_position": 1, "amount": 2, "target_position": 1, "status": "poison"},
		{"type": "debuff", "enemy_position": 1, "amount": 0, "target_position": 1, "status": "exposed"},
		{"type": "debuff", "enemy_position": 1, "amount": 1.5, "target_position": 1, "status": "exposed"},
		{"type": "debuff", "enemy_position": 1, "amount": 2, "target_position": 1},
		{"type": "debuff", "enemy_position": 1, "amount": 2, "target_position": 1, "status": "weak", "extra": 1},
		{"type": "shove", "enemy_position": 1, "amount": 1, "target_position": 1, "direction": 1},
		{"type": "shove", "enemy_position": 1, "amount": 0, "target_position": 1, "direction": 0},
		{"type": "shove", "enemy_position": 1, "amount": 0, "target_position": 1, "direction": 2},
		{"type": "buff", "enemy_position": 1, "amount": 0},
		{"type": "buff", "enemy_position": 1, "amount": 3, "target_position": 1},
		{"type": "block", "enemy_position": 1, "amount": 1, "target_position": 1},
	]:
		_reject_mixed(party, enemies, [bad, _beat(2, 1)], "malformed mixed action " + str(bad))

## Real run-catalog four-slot authority, not a fifth actor jammed into a
## legacy three-slot fixture. The committed phase, not a second arithmetic
## oracle, supplies the exact HP/Block proof.
func _four_foe_cases() -> void:
	var catalog: Array = RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
	var ids := ["fray_scavenger", "button_guard", "spool_stalker", "seam_ripper"]
	var definitions: Array = []
	for id in ids:
		for candidate in catalog:
			if candidate is Dictionary and candidate.get("id") == id:
				definitions.append(candidate.duplicate(true))
				break
	_check(definitions.size() == 4, "four original, distinct run-catalog enemy records exist")
	if definitions.size() != 4:
		return
	# Keep the eight-damage status/Block witness authentic now that this source
	# authenticates named moves: floor-5 Ripper Throw truncates 7 * 1.25 to 8.
	for raw in definitions[3].intent.actions:
		if raw.type == "attack":
			raw.amount = RunNormalAttackFloorScaling.scale_normal_attack(int(raw.amount), 5).amount
	var party := _party()
	var enemies := CombatEnemies.new(definitions, CombatEnemies.OPT_IN_MAX_ENEMIES)
	_check(party.is_valid() and enemies.is_valid() and enemies.get_capacity() == 4
		and enemies.get_enemies().size() == 4 and enemies.get_enemy(4)["id"] == ids[3],
		"real four-capacity enemy authority has a living fourth combat source")
	_check(party.gain_block(3, 3) and party.get_hero(3)["block"] == 3,
		"real third hero begins with absorbable Block")
	party._heroes[2]["statuses"] = {"exposed": 2}
	enemies._enemies[3]["statuses"] = {"weak": 1}
	# The fourth authentic source targets the lowest-HP living hero (Tinker).
	var actions: Array = [_block(1, 2), _block(2, 0), _block(3, 0), _attack(4, 8, 3)]
	actions[3]["move"] = "attack3"
	var heroes := party.get_heroes()
	var roster := enemies.get_enemies()
	var pristine := [heroes.duplicate(true), roster.duplicate(true), actions.duplicate(true)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 433224
	var rng_before := rng.state
	seed(433225)
	var global_expected := randi()
	seed(433225)
	var forecast := helper.forecast(heroes, roster, actions, true)
	_check(forecast.get("ok", false) and forecast["heroes"].size() == 3,
		"complete four-slot single-hit/Block announcements forecast every fixed hero")
	for repeat in range(3):
		_check(helper.forecast(heroes, roster, actions, true) == forecast,
			"four-slot projected phase repeats exactly without RNG draws")
	_check([heroes, roster, actions] == pristine and party.get_heroes() == heroes
		and enemies.get_enemies() == roster and rng.state == rng_before
		and randi() == global_expected,
		"four-slot forecast never edits caller actors, intents or either RNG")
	if not forecast.get("ok", false):
		return
	var third: Dictionary = forecast["heroes"][2]
	_check(third["incoming"] == 9 and third["block_absorbed"] == 3
		and third["hp_lost"] == 6 and third["hp_remaining"] == 20
		and third["block_remaining"] == 0,
		"fourth source's Weak and hero Exposed multiply once, then three Block absorb")
	for index in range(2):
		_check(forecast["heroes"][index]["incoming"] == 0
			and forecast["heroes"][index]["hp_lost"] == 0,
			"enemy Block beats do not become phantom incoming hero damage")
	var tick := CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())
	_check(tick["ok"] and CombatStatusTurnBatch.new().tick_side(
		"enemies", enemies.get_enemies(), enemies.get_capacity())["ok"],
		"actual four-slot pre-phase status validation accepts all four records")
	if not tick["ok"]:
		return
	party._heroes.assign(tick["actors"].duplicate(true))
	var phase := CombatEnemyPhase.new().execute_phase(party, enemies, actions, null, true)
	_check(phase["ok"] and phase["events"].size() == 4
		and phase["events"][3].get("enemy_position") == 4
		and phase["events"][3].get("applied", false),
		"committed real phase executes fourth-slot single hit, not an inert preview")
	if phase["ok"]:
		for index in range(3):
			var result: Dictionary = forecast["heroes"][index]
			var actual := party.get_hero(index + 1)
			_check(result["hp_remaining"] == actual["hp"]
				and result["block_remaining"] == actual["block"],
				"committed four-foe phase matches detached hero HP/Block %d" % (index + 1))
	# Fail-closed batches must not publish even a zero-damage invented ticket.
	_reject(heroes, roster, actions.slice(0, 3), "four foes with missing fourth beat")
	var duplicate := actions.duplicate(true)
	duplicate[1]["enemy_position"] = 4
	_reject(heroes, roster, duplicate, "four foes with duplicate source four")
	var out_of_range := actions.duplicate(true)
	out_of_range[3]["enemy_position"] = 5
	_reject(heroes, roster, out_of_range, "fifth source on four-foe roster")
	var fifth := roster.duplicate(true)
	var extra: Dictionary = definitions[0].duplicate(true)
	extra["id"] = "extra_catalog_witness"
	extra["position"] = 5
	extra["hp"] = extra["max_hp"]
	extra["block"] = 0
	fifth.append(extra)
	_reject(heroes, fifth, actions + [_block(5, 1)], "five foes cannot opt in")
	var malformed := roster.duplicate(true)
	malformed[3]["statuses"] = {"weak": -1}
	_reject(heroes, malformed, actions, "invalid fourth-slot status")
	var unexecutable := actions.duplicate(true)
	unexecutable[3] = {"type": "shove", "amount": 0,
		"enemy_position": 4, "target_position": 3, "direction": 1}
	_reject(heroes, roster, unexecutable, "fourth-slot off-edge shove")
	var multi := actions.duplicate(true)
	multi[3]["hits"] = 2
	_reject(heroes, roster, multi, "multi-hit fourth-slot cannot be modeled as one hit")
	var spawn := actions.duplicate(true)
	spawn[3] = {"type": "summon", "amount": 0, "enemy_position": 4}
	_reject(heroes, roster, spawn, "fourth-slot summon cannot be predicted")
	var blinded := roster.duplicate(true)
	blinded[3]["statuses"] = {"blind_next_attack": 1}
	_reject(heroes, blinded, actions, "Blind attack cannot be forecast as a hit")
	for complex_id in ["shearwing_mantis", "spoolback_hound", "spindle_ram"]:
		var complex_roster := roster.duplicate(true)
		for record in catalog:
			if record is Dictionary and record.get("id") == complex_id:
				var fourth: Dictionary = record.duplicate(true)
				fourth["position"] = 4
				fourth["hp"] = fourth["max_hp"]
				fourth["block"] = 0
				if complex_id == "spoolback_hound":
					fourth["enrage_stacks"] = 2
				complex_roster[3] = fourth
				break
		_check(complex_roster[3]["id"] == complex_id,
			"genuine complex enemy %s supplies fourth-slot precondition" % complex_id)
		_reject(heroes, complex_roster, actions,
			"complex fourth-slot attack %s cannot produce misleading damage" % complex_id)
