extends SceneTree
## Real catalog/deck/party/enemy regression for Tinker's six direct-fire cards and Pinned interactions.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_catalog_and_ten_variants()
	_test_rivet_order_and_duplicates()
	_test_area_original_positions()
	_test_scatter_bolts_lethal_area_victory()
	_test_ricochet_replay()
	_test_ricochet_hit2_finish()
	_test_shared_first_attack()
	_test_spring_trap_cases()
	_test_cross_owner_follow_up_cases()
	_test_ricochet_pinned_cases()
	_test_atomic_rejections()
	for failure in failures:
		printerr(failure)
	print("combat_tinker_pool_attacks_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _deck(ids: Array, seed_value: int = 774) -> CombatDeck:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var card_ids: Array[String] = []
	card_ids.assign(ids)
	var deck := CombatDeck.new(card_ids, rng)
	_check(deck.start_turn() and deck.energy == 3 and deck.hand.size() == ids.size(),
		"real seeded CombatDeck starts with actual drawn held cards")
	return deck


func _party(order: Array = ["warden", "seamstress", "tinker"]) -> CombatParty:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/heroes/starter_party.json"))
	_check(raw is Array and raw.size() == 3, "real starter_party JSON has three heroes")
	var definitions: Array = []
	if raw is Array:
		for id in order:
			for hero in raw:
				if hero.get("id") == id:
					# JSON.parse_string produces numeric Variants; party requires int HP.
					var definition: Dictionary = hero.duplicate(true)
					definition["max_hp"] = int(hero["max_hp"])
					definitions.append(definition)
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"authentic party precondition and assigned slots")
	return party


func _enemies(hps: Array = [70, 70, 70]) -> CombatEnemies:
	var definitions: Array = []
	for index in range(hps.size()):
		definitions.append({"id": "foe_%d" % index, "max_hp": hps[index]})
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid() and enemies.get_enemies().size() == hps.size(),
		"real fixed-slot enemy roster is valid and nonempty")
	return enemies


func _snapshot(deck: CombatDeck, party: CombatParty,
		enemies: CombatEnemies, first: CombatTinkerFirstAttack) -> Dictionary:
	return {"draw": deck.draw_pile.duplicate(), "hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(), "energy": deck.energy,
		"turn": deck.turn_active, "state_energy": deck.combat_state.energy,
		"state_turn": deck.combat_state.player_turn_active,
		"rng": deck._rng.state, "party": party.get_heroes(),
		"enemies": enemies.get_enemies(), "consumed": first._consumed}


func _rows() -> Array[Dictionary]:
	return [
		{"base": "tinker_rivet_shot", "damage": [4, 6], "cost": 1,
			"from": [2, 3], "kind": "enemy_single"},
		{"base": "tinker_spring_trap", "damage": [3, 4], "cost": 1,
			"from": [2, 3], "kind": "enemy_single"},
		{"base": "tinker_scatter_bolts", "damage": [3, 4], "cost": 1,
			"from": [3], "kind": "enemy_all"},
		{"base": "tinker_long_barrel", "damage": [12, 16], "cost": 2,
			"from": [3], "kind": "enemy_single"},
		{"base": "tinker_ricochet", "damage": [4, 6], "cost": 1,
			"from": [2, 3], "kind": "enemy_random"},
		{"base": "tinker_bobbin_cannon", "damage": [20, 26], "cost": 3,
			"from": [3], "kind": "enemy_single"}
	]


func _test_catalog_and_ten_variants() -> void:
	var catalog := TinkerPoolCards.new()
	for row in _rows():
		for upgrade in [false, true]:
			var card_id: String = row["base"] + ("_plus" if upgrade else "")
			var raw_damage: int = row["damage"][1 if upgrade else 0]
			var definition: Dictionary = catalog.get_definition(card_id)
			_check(not definition.is_empty() and definition.get("id") == card_id
				and definition.get("owner") == "tinker"
				and definition.get("cost") == row["cost"]
				and definition.get("starting_copies") == 0
				and definition.get("from_positions") == row["from"]
				and definition.get("to_positions") == [1, 2, 3]
				and definition.get("target_kind") == row["kind"]
				and definition.get("effects", {}).get("damage") == raw_damage,
				card_id + " matches complete authoritative core descriptor")
			var first := CombatTinkerFirstAttack.new()
			var pinned := CombatPinned.new()
			var resolver := CombatTinkerPoolAttacks.new(first, pinned)
			_check(first.bonus_for_attack(card_id) == 3,
				card_id + " classified as first Tinker attack")
			var party := _party(["warden", "tinker", "seamstress"]
				if row["from"].has(2) else ["warden", "seamstress", "tinker"])
			var tinker_slot := 2 if row["from"].has(2) else 3
			_check(party.get_hero(tinker_slot)["id"] == "tinker",
				card_id + " acts from its actual current slot")
			party._heroes[tinker_slot - 1]["statuses"] = {"weak": 1}
			var enemies := _enemies()
			_check(enemies.gain_block(1, 2) and enemies.gain_block(2, 4)
				and enemies.apply_statuses({1: {"exposed": 1}}),
				card_id + " starts against actual Block and Exposed")
			var deck := _deck([card_id, "warden_brace"])
			var before := _snapshot(deck, party, enemies, first)
			var positions: Array[int] = []
			if row["kind"] == "enemy_single":
				positions.assign([1])
			else:
				positions.assign([1, 2, 3])
			if row["kind"] == "enemy_random":
				var oracle := _oracle_random(before["rng"], enemies.get_enemies(),
					raw_damage + 3, {"weak": 1}, 3)
				positions.assign(oracle["positions"])
			var expected_enemies: Array = before["enemies"].duplicate(true)
			var expected_hits: Array = []
			for position in positions:
				var actor: Dictionary = expected_enemies[position - 1]
				var exposed: bool = actor.get("statuses", {}).get("exposed", 0) > 0
				var hit_damage: int = (raw_damage + 3) * 9 / 8 if exposed else (raw_damage + 3) * 3 / 4
				var absorbed: int = mini(actor["block"], hit_damage)
				var lost: int = mini(actor["hp"], hit_damage - absorbed)
				actor["block"] -= absorbed
				actor["hp"] -= lost
				var statuses: Dictionary = {}
				if row["base"] == "tinker_rivet_shot":
					statuses = {"exposed": 1}
					actor["statuses"]["exposed"] += 1
				var hit_dict: Dictionary = {
					"position": position, "damage": hit_damage,
					"block_absorbed": absorbed, "hp_loss": lost, "statuses": statuses
				}
				if row["base"] == "tinker_spring_trap":
					hit_dict["pinned"] = true
				expected_hits.append(hit_dict)
			var result: Dictionary = resolver.play_attack(deck, party, enemies, card_id,
				1 if row["kind"] == "enemy_single" else 0)
			_check(result == {"ok": true, "hits": expected_hits},
				card_id + " exact ordered hit/status/Block/HP events")
			_check(enemies.get_enemies() == expected_enemies,
				card_id + " authoritative roster equals independent hit oracle")
			_check(deck.energy == 3 - row["cost"]
				and deck.hand == ["warden_brace"] and deck.discard_pile == [card_id]
				and first._consumed and party.get_heroes() == before["party"],
				card_id + " charges exactly once, discards once and preserves party")
			if row["kind"] != "enemy_random":
				_check(deck._rng.state == before["rng"],
					card_id + " nonrandom attack uses no run RNG")
			if row["base"] == "tinker_spring_trap":
				_check(pinned.pinner_for_enemy(1) == "tinker",
					card_id + " recorded pin on enemy 1 in CombatPinned")
				_check(not enemies.get_enemy(1)["statuses"].has("pinned"),
					card_id + " CombatEnemies has no pinned status key")
				_check(not (result["hits"][0]["statuses"] as Dictionary).has("pinned"),
					card_id + " hit statuses dictionary has no pinned key")
			else:
				_check(pinned.pinner_for_enemy(1) == "",
					card_id + " did not pin enemy 1")
				_check(not (result["hits"][0] as Dictionary).has("pinned"),
					card_id + " non-Spring-Trap hit has no pinned receipt key")


func _test_rivet_order_and_duplicates() -> void:
	var id := "tinker_rivet_shot"
	var first := CombatTinkerFirstAttack.new()
	var resolver := CombatTinkerPoolAttacks.new(first)
	var deck := _deck([id, id, "warden_strike"])
	var party := _party()
	var enemies := _enemies([30])
	var rng_before := deck._rng.state
	var a: Dictionary = resolver.play_attack(deck, party, enemies, id, 1)
	_check(a == {"ok": true, "hits": [
		{"position": 1, "damage": 7, "block_absorbed": 0, "hp_loss": 7,
			"statuses": {"exposed": 1}}]},
		"Rivet first damage excludes Exposed applied after the hit")
	_check(enemies.get_enemy(1)["statuses"] == {"exposed": 1}
		and deck.hand.count(id) == 1 and deck.discard_pile.count(id) == 1,
		"Rivet persists status and retains one duplicate held copy")
	var b: Dictionary = resolver.play_attack(deck, party, enemies, id, 1)
	_check(b == {"ok": true, "hits": [
		{"position": 1, "damage": 6, "block_absorbed": 0, "hp_loss": 6,
			"statuses": {"exposed": 1}}]}
		and enemies.get_enemy(1)["hp"] == 17
		and enemies.get_enemy(1)["statuses"] == {"exposed": 2},
		"second Rivet is unboosted but benefits from pre-existing Exposed")
	_check(deck.energy == 1 and deck.discard_pile.count(id) == 2
		and deck.hand == ["warden_strike"] and deck._rng.state == rng_before,
		"two separate plays spend once each, keep unrelated card and never draw RNG")


func _test_area_original_positions() -> void:
	var first := CombatTinkerFirstAttack.new()
	var resolver := CombatTinkerPoolAttacks.new(first)
	var deck := _deck(["tinker_scatter_bolts_plus"])
	var party := _party()
	var enemies := _enemies([15, 1, 17])
	_check(enemies.apply_damage(2, 1) and enemies.is_slain(2)
		and enemies.get_enemy(3)["position"] == 3, "middle slot slain, slot 3 unchanged")
	var result: Dictionary = resolver.play_attack(deck, party, enemies,
		"tinker_scatter_bolts_plus")
	_check(result == {"ok": true, "hits": [
		{"position": 1, "damage": 7, "block_absorbed": 0, "hp_loss": 7, "statuses": {}},
		{"position": 3, "damage": 7, "block_absorbed": 0, "hp_loss": 7, "statuses": {}}]},
		"Scatter+ hits surviving original slots once each, with first bonus")
	_check(enemies.get_enemy(2)["hp"] == 0 and enemies.get_enemy(3)["hp"] == 10,
		"dead centre remains dead and third enemy uses original slot number")


func _test_scatter_bolts_lethal_area_victory() -> void:
	for upgrade in [false, true]:
		var card_id: String = "tinker_scatter_bolts_plus" if upgrade else "tinker_scatter_bolts"
		var raw_damage: int = 4 if upgrade else 3
		var first := CombatTinkerFirstAttack.new()
		var resolver := CombatTinkerPoolAttacks.new(first)
		var deck := _deck([card_id, "warden_strike"])
		var party := _party()
		var enemies := _enemies([5, 6])
		_check(enemies.gain_block(1, 1), card_id + " enemy 1 gains 1 block")
		var rng_before: int = deck._rng.state
		var result: Dictionary = resolver.play_attack(deck, party, enemies, card_id)
		var expected_dmg: int = raw_damage + 3
		_check(result.get("ok", false) and result["hits"].size() == 2,
			card_id + " lethal area attack executes both living enemy hits")
		_check(result["hits"][0] == {"position": 1, "damage": expected_dmg,
			"block_absorbed": 1, "hp_loss": 5, "statuses": {}},
			card_id + " enemy 1 absorbs block and takes lethal HP loss")
		_check(result["hits"][1] == {"position": 2, "damage": expected_dmg,
			"block_absorbed": 0, "hp_loss": 6, "statuses": {}},
			card_id + " enemy 2 takes lethal HP loss")
		_check(enemies.is_slain(1) and enemies.is_slain(2) and enemies.is_victorious(),
			card_id + " all enemies slain commits real victory")
		_check(deck.energy == 2 and deck.hand == ["warden_strike"] and deck.discard_pile == [card_id],
			card_id + " charges once and discards once")
		_check(first._consumed, card_id + " consumes first-attack latch")
		_check(deck._rng.state == rng_before,
			card_id + " area victory leaves run RNG completely untouched")


## Independent seeded oracle advances a copied RNG, computes current living
## selection before EACH hit and simulates Block/HP (without touching service).
func _oracle_random(state: int, starting: Array[Dictionary], base_damage: int,
		attacker: Dictionary, count: int) -> Dictionary:
	var clone := RandomNumberGenerator.new()
	clone.state = state
	var simulated: Array[Dictionary] = starting.duplicate(true)
	var picks: Array[int] = []
	for i in range(count):
		var candidates: Array[int] = []
		for index in range(simulated.size()):
			if simulated[index]["hp"] > 0:
				candidates.append(index + 1)
		if candidates.is_empty():
			return {"positions": picks, "state": clone.state, "roster": simulated}
		var position: int = candidates[clone.randi_range(0, candidates.size() - 1)]
		picks.append(position)
		var actor: Dictionary = simulated[position - 1]
		var damage := base_damage
		if attacker.get("weak", 0) > 0 and actor.get("statuses", {}).get("exposed", 0) > 0:
			damage = base_damage * 9 / 8
		elif attacker.get("weak", 0) > 0:
			damage = base_damage * 3 / 4
		elif actor.get("statuses", {}).get("exposed", 0) > 0:
			damage = base_damage * 3 / 2
		var absorbed: int = mini(actor["block"], damage)
		actor["block"] -= absorbed
		actor["hp"] -= mini(actor["hp"], damage - absorbed)
	return {"positions": picks, "state": clone.state, "roster": simulated}


func _oracle_random_pinned(state: int, starting: Array[Dictionary], base_damage: int,
		attacker: Dictionary, count: int, initial_pins: Dictionary) -> Dictionary:
	var clone := RandomNumberGenerator.new()
	clone.state = state
	var simulated: Array[Dictionary] = starting.duplicate(true)
	var pins: Dictionary = initial_pins.duplicate()
	var picks: Array[int] = []
	var hit_events: Array[Dictionary] = []
	for i in range(count):
		var candidates: Array[int] = []
		for index in range(simulated.size()):
			if simulated[index]["hp"] > 0:
				candidates.append(index + 1)
		if candidates.is_empty():
			return {"positions": picks, "state": clone.state, "roster": simulated, "hits": hit_events, "pins": pins}
		var position: int = candidates[clone.randi_range(0, candidates.size() - 1)]
		picks.append(position)
		var actor: Dictionary = simulated[position - 1]
		var pin_bonus: int = 0
		if pins.get(position, "") != "" and pins[position] != "tinker":
			pin_bonus = 5
			pins.erase(position)
		var hit_base: int = base_damage + pin_bonus
		var damage: int = hit_base
		if attacker.get("weak", 0) > 0 and actor.get("statuses", {}).get("exposed", 0) > 0:
			damage = hit_base * 9 / 8
		elif attacker.get("weak", 0) > 0:
			damage = hit_base * 3 / 4
		elif actor.get("statuses", {}).get("exposed", 0) > 0:
			damage = hit_base * 3 / 2
		var absorbed: int = mini(actor["block"], damage)
		var lost: int = mini(actor["hp"], damage - absorbed)
		actor["block"] -= absorbed
		actor["hp"] -= lost
		hit_events.append({"position": position, "damage": damage,
			"block_absorbed": absorbed, "hp_loss": lost, "statuses": {}})
	return {"positions": picks, "state": clone.state, "roster": simulated, "hits": hit_events, "pins": pins}


func _ricochet_case(card_id: String, seed_value: int) -> Dictionary:
	var first := CombatTinkerFirstAttack.new()
	var deck := _deck([card_id], seed_value)
	var party := _party(["warden", "tinker", "seamstress"])
	var enemies := _enemies([7, 1, 80])
	var damage_base := 6 if card_id.ends_with("_plus") else 4
	_check(enemies.gain_block(3, 2), "Ricochet scenario has live Block on stable slot 3")
	var before := _snapshot(deck, party, enemies, first)
	var oracle := _oracle_random(before["rng"], enemies.get_enemies(), damage_base + 3, {}, 3)
	_check(oracle["positions"].size() == 3, "seeded fixture retains a target for all three hits")
	var result: Dictionary = CombatTinkerPoolAttacks.new(first).play_attack(
		deck, party, enemies, card_id)
	var picked: Array[int] = []
	for hit in result.get("hits", []):
		picked.append(hit["position"])
	_check(result.get("ok", false) and result["hits"].size() == 3
		and picked == oracle["positions"] and deck._rng.state == oracle["state"]
		and deck._rng.state != before["rng"],
		card_id + " selects three living recipients and consumes precisely three run draws")
	_check(enemies.get_enemies() == oracle["roster"],
		card_id + " seeded simulation matches authoritative HP, Block and surviving slots")
	var early_death := false
	for index in range(2):
		var position: int = picked[index]
		if position == 1 or position == 2:
			early_death = true
			_check(not picked.slice(index + 1).has(position),
				card_id + " slain early target is absent from later random picks")
	_check(deck.energy == 2 and deck.discard_pile == [card_id]
		and first._consumed and party.get_heroes() == before["party"],
		card_id + " spends a single energy and single first-attack latch")
	for hit in result.get("hits", []):
		_check(hit["statuses"] == {} and hit["damage"] == damage_base + 3,
			card_id + " each sequential hit has the same first-card bonus")
	return {"result": result, "enemies": enemies.get_enemies(),
		"rng": deck._rng.state, "start_rng": before["rng"], "early_death": early_death}


func _test_ricochet_replay() -> void:
	var witnessed_early_death := false
	for card_id in ["tinker_ricochet", "tinker_ricochet_plus"]:
		for seed_value in [1, 9, 39]:
			var a: Dictionary = _ricochet_case(card_id, seed_value)
			var b: Dictionary = _ricochet_case(card_id, seed_value)
			_check(a == b, card_id + " same seeded real roster/actions replay exactly")
			witnessed_early_death = witnessed_early_death or a["early_death"]
	_check(witnessed_early_death, "seeded scenarios include a target slain on hit 1 or 2")

	# Replace obsolete expectation: Ricochet against a single 1-HP enemy must succeed on hit 1,
	# committing a real victory with 1 spend, 1 discard, 1 RNG selection, and no phantom hits.
	for upgrade in [false, true]:
		var card_id: String = "tinker_ricochet_plus" if upgrade else "tinker_ricochet"
		var base_dmg: int = 6 if upgrade else 4
		var first := CombatTinkerFirstAttack.new()
		var deck := _deck([card_id, "warden_strike"])
		var party := _party()
		var enemies := _enemies([1])
		var party_before: Array = party.get_heroes()
		var rng_clone := RandomNumberGenerator.new()
		rng_clone.state = deck._rng.state
		var oracle: Dictionary = _oracle_random(rng_clone.state, enemies.get_enemies(), base_dmg + 3, {}, 3)
		var oracle_clone := RandomNumberGenerator.new()
		oracle_clone.state = oracle["state"]
		var expected_next_randi: int = oracle_clone.randi()

		var result: Dictionary = CombatTinkerPoolAttacks.new(first).play_attack(
			deck, party, enemies, card_id)
		_check(result.get("ok", false) and result["hits"].size() == 1,
			card_id + " terminal stop on single 1-HP enemy commits exactly one hit")
		_check(result["hits"][0] == {"position": 1, "damage": base_dmg + 3, "block_absorbed": 0,
			"hp_loss": 1, "statuses": {}},
			card_id + " first-hit kill applies correct first-attack damage and status receipt")
		_check(enemies.is_slain(1) and enemies.is_victorious(),
			card_id + " lone enemy slain and victory committed on hit 1")
		_check(deck.energy == 2 and deck.hand == ["warden_strike"] and deck.discard_pile == [card_id],
			card_id + " hit 1 finish spends once and discards once")
		_check(first._consumed and party.get_heroes() == party_before,
			card_id + " first-attack latch consumed and party state preserved")
		_check(deck._rng.state == oracle["state"],
			card_id + " RNG advanced by precisely one random selection matching oracle")
		_check(deck._rng.randi() == expected_next_randi,
			card_id + " subsequent random draws match cloned oracle exactly")


func _test_ricochet_hit2_finish() -> void:
	# Fixture 1: Lone survivor with Block falls on hit 2, hit 3 never executes
	for upgrade in [false, true]:
		var card_id: String = "tinker_ricochet_plus" if upgrade else "tinker_ricochet"
		var base_dmg: int = 6 if upgrade else 4
		var first := CombatTinkerFirstAttack.new()
		var deck := _deck([card_id, "warden_brace"])
		var party := _party()
		# Base deals 7 dmg (4+3). Enemy has 5 HP and 4 Block:
		# Hit 1: 4 absorbed, 3 lost -> 2 HP left. Hit 2: 0 absorbed, 2 lost -> dead!
		# Plus deals 9 dmg (6+3). Enemy has 7 HP and 5 Block:
		# Hit 1: 5 absorbed, 4 lost -> 3 HP left. Hit 2: 0 absorbed, 3 lost -> dead!
		var starting_hp: int = 7 if upgrade else 5
		var starting_block: int = 5 if upgrade else 4
		var enemies := _enemies([starting_hp])
		_check(enemies.gain_block(1, starting_block), card_id + " lone enemy has starting block")
		var party_before: Array = party.get_heroes()
		var oracle: Dictionary = _oracle_random(deck._rng.state, enemies.get_enemies(), base_dmg + 3, {}, 3)
		var oracle_clone := RandomNumberGenerator.new()
		oracle_clone.state = oracle["state"]
		var exp_next_randi: int = oracle_clone.randi()

		var result: Dictionary = CombatTinkerPoolAttacks.new(first).play_attack(
			deck, party, enemies, card_id)
		_check(result.get("ok", false) and result["hits"].size() == 2,
			card_id + " lone blocked enemy falls on hit 2, stopping before hit 3")
		_check(result["hits"][0] == {"position": 1, "damage": base_dmg + 3,
			"block_absorbed": starting_block, "hp_loss": (base_dmg + 3) - starting_block, "statuses": {}},
			card_id + " hit 1 absorbs block")
		_check(result["hits"][1] == {"position": 1, "damage": base_dmg + 3,
			"block_absorbed": 0, "hp_loss": starting_hp - ((base_dmg + 3) - starting_block), "statuses": {}},
			card_id + " hit 2 is lethal")
		_check(enemies.is_slain(1) and enemies.is_victorious(),
			card_id + " enemy slain and victory committed on hit 2")
		_check(enemies.get_enemies() == oracle["roster"],
			card_id + " authoritative roster matches oracle on hit 2 finish")
		_check(deck.energy == 2 and deck.hand == ["warden_brace"] and deck.discard_pile == [card_id],
			card_id + " spends once and discards once")
		_check(first._consumed and party.get_heroes() == party_before,
			card_id + " consumed latch and preserved party")
		_check(deck._rng.state == oracle["state"],
			card_id + " RNG advanced by precisely two selections")
		_check(deck._rng.randi() == exp_next_randi,
			card_id + " next RNG state matches oracle clone")

	# Fixture 2: Seeded 2-enemy fixture where enemy 1 dies on hit 1, enemy 2 has Block and dies on hit 2
	var found_seed: int = -1
	for s in range(1, 100):
		var test_rng := RandomNumberGenerator.new()
		test_rng.seed = s
		if test_rng.randi_range(0, 1) == 0:
			found_seed = s
			break
	_check(found_seed > 0, "found deterministic seed selecting enemy 1 first")
	for replay_pass in [1, 2]:
		var first_multi := CombatTinkerFirstAttack.new()
		var deck_multi := _deck(["tinker_ricochet"], found_seed)
		var party_multi := _party(["warden", "tinker", "seamstress"])
		# Enemy 1: 5 HP, 0 Block (dies on hit 1 from 7 damage)
		# Enemy 2: 2 HP, 4 Block (dies on hit 2: 4 absorbed, 2 lost)
		var enemies_multi := _enemies([5, 2])
		_check(enemies_multi.gain_block(2, 4), "enemy 2 has 4 block")
		var oracle_multi: Dictionary = _oracle_random(deck_multi._rng.state, enemies_multi.get_enemies(), 7, {}, 3)
		var oracle_multi_clone := RandomNumberGenerator.new()
		oracle_multi_clone.state = oracle_multi["state"]
		var exp_multi_next: int = oracle_multi_clone.randi()

		var result_multi: Dictionary = CombatTinkerPoolAttacks.new(first_multi).play_attack(
			deck_multi, party_multi, enemies_multi, "tinker_ricochet")
		_check(result_multi.get("ok", false) and result_multi["hits"].size() == 2,
			"pass %d: 2-enemy Ricochet finishes on hit 2" % replay_pass)
		var actual_positions: Array[int] = []
		for h in result_multi["hits"]:
			actual_positions.append(int(h["position"]))
		_check(actual_positions == oracle_multi["positions"] and actual_positions == [1, 2],
			"pass %d: hits selected enemy 1 then enemy 2" % replay_pass)
		_check(enemies_multi.is_slain(1) and enemies_multi.is_slain(2) and enemies_multi.is_victorious(),
			"pass %d: both enemies slain on hit 2" % replay_pass)
		_check(deck_multi.energy == 2 and deck_multi.discard_pile == ["tinker_ricochet"],
			"pass %d: single spend and single discard" % replay_pass)
		_check(deck_multi._rng.state == oracle_multi["state"] and deck_multi._rng.randi() == exp_multi_next,
			"pass %d: exactly 2 RNG draws consumed" % replay_pass)

	# Fixture 3: Hit 2 finish WITHOUT first attack bonus (base 4 damage)
	var first_unboosted := CombatTinkerFirstAttack.new()
	first_unboosted.record_successful_attack("tinker_pop_shot")
	_check(first_unboosted.bonus_for_attack("tinker_ricochet") == 0, "unboosted preview is 0")
	var deck_unboosted := _deck(["tinker_ricochet"])
	var party_unboosted := _party()
	# Enemy: 3 HP, 2 Block. Hit 1 deals 4 (2 absorbed, 2 lost -> 1 HP). Hit 2 deals 4 (0 absorbed, 1 lost -> dead).
	var enemies_unboosted := _enemies([3])
	_check(enemies_unboosted.gain_block(1, 2), "enemy has 2 block")
	var oracle_unb: Dictionary = _oracle_random(deck_unboosted._rng.state, enemies_unboosted.get_enemies(), 4, {}, 3)
	var res_unb: Dictionary = CombatTinkerPoolAttacks.new(first_unboosted).play_attack(
		deck_unboosted, party_unboosted, enemies_unboosted, "tinker_ricochet")
	_check(res_unb.get("ok", false) and res_unb["hits"].size() == 2,
		"unboosted Ricochet finishes on hit 2")
	_check(res_unb["hits"][0]["damage"] == 4 and res_unb["hits"][1]["damage"] == 4,
		"both hits use unboosted base damage 4")
	_check(enemies_unboosted.is_victorious(), "unboosted victory on hit 2")
	_check(deck_unboosted._rng.state == oracle_unb["state"], "unboosted RNG matches oracle")

	# Fixture 4: All 3 hits occur when living survivors remain
	var first_3hits := CombatTinkerFirstAttack.new()
	var deck_3hits := _deck(["tinker_ricochet"])
	var party_3hits := _party()
	var enemies_3hits := _enemies([50, 50, 50])
	var oracle_3hits: Dictionary = _oracle_random(deck_3hits._rng.state, enemies_3hits.get_enemies(), 7, {}, 3)
	var res_3hits: Dictionary = CombatTinkerPoolAttacks.new(first_3hits).play_attack(
		deck_3hits, party_3hits, enemies_3hits, "tinker_ricochet")
	_check(res_3hits.get("ok", false) and res_3hits["hits"].size() == 3,
		"when survivors remain all 3 hits resolve")
	_check(not enemies_3hits.is_victorious(), "enemies survive all 3 hits")
	_check(deck_3hits._rng.state == oracle_3hits["state"], "3 hits consume 3 RNG selections")


func _test_shared_first_attack() -> void:
	for starter_first in [true, false]:
		var first := CombatTinkerFirstAttack.new()
		var resolver := CombatTinkerPoolAttacks.new(first)
		var deck := _deck(["tinker_long_barrel", "tinker_rivet_shot"])
		var party := _party()
		var enemies := _enemies([100])
		if starter_first:
			_check(first.record_successful_attack("tinker_pop_shot"),
				"starter Pop Shot consumes shared latch before pool play")
		var result: Dictionary = resolver.play_attack(deck, party, enemies,
			"tinker_long_barrel", 1)
		_check(result.get("ok", false) and result["hits"][0]["damage"] ==
			(12 if starter_first else 15), "starter/pool order governs same +3")
		_check(first.bonus_for_attack("tinker_pop_shot") == 0
			and first.bonus_for_attack("tinker_rivet_shot") == 0,
			"pool and starter share one consumed latch")
		first.start_player_turn()
		_check(first.bonus_for_attack("tinker_pop_shot") == 3
			and first.bonus_for_attack("tinker_rivet_shot_plus") == 3,
			"turn boundary restores both starter and upgraded pool bonus")
		result = resolver.play_attack(deck, party, enemies, "tinker_rivet_shot", 1)
		_check(result["ok"] and result["hits"][0]["damage"] == 7
			and first.bonus_for_attack("tinker_pop_shot") == 0,
			"reset pool play gains bonus, then starter preview is zero")


func _test_spring_trap_cases() -> void:
	# AC1: Base and + variant resolve against actual models from legal FROM/TO slots
	for upgrade in [false, true]:
		var card_id: String = "tinker_spring_trap_plus" if upgrade else "tinker_spring_trap"
		var raw_damage: int = 4 if upgrade else 3
		var first := CombatTinkerFirstAttack.new()
		var pinned := CombatPinned.new()
		var resolver := CombatTinkerPoolAttacks.new(first, pinned)
		var deck := _deck([card_id, "warden_strike"])
		var party := _party(["warden", "seamstress", "tinker"])
		var enemies := _enemies([30])
		_check(enemies.gain_block(1, 4), "enemy gains 4 block")

		var expected_damage: int = raw_damage + 3
		var expected_absorbed: int = 4
		var expected_hp_loss: int = expected_damage - 4
		var result: Dictionary = resolver.play_attack(deck, party, enemies, card_id, 1)
		_check(result == {"ok": true, "hits": [{
			"position": 1,
			"damage": expected_damage,
			"block_absorbed": expected_absorbed,
			"hp_loss": expected_hp_loss,
			"statuses": {},
			"pinned": true
		}]}, card_id + " exact hit result with block absorption and pinned flag")
		_check(enemies.get_enemy(1)["block"] == 0, card_id + " block reduced to 0")
		_check(enemies.get_enemy(1)["hp"] == 30 - expected_hp_loss, card_id + " exact hp loss")
		_check(pinned.pinner_for_enemy(1) == "tinker", card_id + " pinned recorded in CombatPinned")
		_check(first._consumed, card_id + " consumed first-attack latch")
		_check(deck.energy == 2 and deck.hand == ["warden_strike"] and deck.discard_pile == [card_id],
			card_id + " spent 1 energy and discarded once")

	# Subsequent Tinker plays in same turn share and consume the latch
	var first_shared := CombatTinkerFirstAttack.new()
	var pinned_shared := CombatPinned.new()
	var resolver_shared := CombatTinkerPoolAttacks.new(first_shared, pinned_shared)
	var deck_shared := _deck(["tinker_spring_trap", "tinker_spring_trap_plus"])
	var party_shared := _party()
	var enemies_shared := _enemies([50])
	var res1: Dictionary = resolver_shared.play_attack(deck_shared, party_shared, enemies_shared, "tinker_spring_trap", 1)
	_check(res1.get("ok", false) and res1["hits"][0]["damage"] == 6, "first Spring Trap gets +3 bonus (3+3=6)")
	_check(first_shared.bonus_for_attack("tinker_spring_trap_plus") == 0, "first attack latch now 0")
	var res2: Dictionary = resolver_shared.play_attack(deck_shared, party_shared, enemies_shared, "tinker_spring_trap_plus", 1)
	_check(res2.get("ok", false) and res2["hits"][0]["damage"] == 4, "second Spring Trap gets base 4 only (no +3)")

	# Lethal Spring Trap does not install a new pin on a dead enemy
	var first_lethal := CombatTinkerFirstAttack.new()
	var pinned_lethal := CombatPinned.new()
	var resolver_lethal := CombatTinkerPoolAttacks.new(first_lethal, pinned_lethal)
	var deck_lethal := _deck(["tinker_spring_trap"])
	var party_lethal := _party()
	var enemies_lethal := _enemies([5])
	var res_lethal: Dictionary = resolver_lethal.play_attack(deck_lethal, party_lethal, enemies_lethal, "tinker_spring_trap", 1)
	_check(res_lethal.get("ok", false) and res_lethal["hits"][0]["hp_loss"] == 5, "lethal Spring Trap dealt 5 hp loss")
	_check(enemies_lethal.is_slain(1), "enemy 1 is slain")
	_check(pinned_lethal.pinner_for_enemy(1) == "", "dead enemy is NOT pinned")
	_check(res_lethal["hits"][0]["pinned"] == false, "lethal hit receipt indicates pinned is false")


func _test_cross_owner_follow_up_cases() -> void:
	# AC2: Pinned by Warden or Seamstress grants Tinker's confirmed hit +5 before Weak/Exposed, consumed once
	for pinner in ["warden", "seamstress"]:
		var first := CombatTinkerFirstAttack.new()
		first.record_successful_attack("tinker_pop_shot")
		var pinned := CombatPinned.new()
		var resolver := CombatTinkerPoolAttacks.new(first, pinned)
		var deck := _deck(["tinker_rivet_shot"])
		var party := _party()
		var enemies := _enemies([50])
		_check(pinned.pin_enemy(enemies, 1, pinner), "pinned enemy 1 with " + pinner)
		_check(pinned.pinner_for_enemy(1) == pinner, "pinner is " + pinner)

		var res: Dictionary = resolver.play_attack(deck, party, enemies, "tinker_rivet_shot", 1)
		_check(res.get("ok", false), "Rivet Shot succeeds against pinned")
		_check(res["hits"][0]["damage"] == 9, "Rivet Shot deals 4 + 5 = 9 damage")
		_check(enemies.get_enemy(1)["hp"] == 41, "enemy HP reduced by 9 to 41")
		_check(pinned.pinner_for_enemy(1) == "", "pinned token consumed after hit")

		# Prove +5 applies BEFORE Weak: (4 + 5) * 3 / 4 = 6
		var first_w := CombatTinkerFirstAttack.new()
		first_w.record_successful_attack("tinker_pop_shot")
		var pinned_w := CombatPinned.new()
		var res_w := CombatTinkerPoolAttacks.new(first_w, pinned_w)
		var deck_w := _deck(["tinker_rivet_shot"])
		var party_w := _party()
		party_w._heroes[2]["statuses"] = {"weak": 1}
		var enemies_w := _enemies([50])
		_check(pinned_w.pin_enemy(enemies_w, 1, pinner), "pinned with " + pinner)
		var r_w: Dictionary = res_w.play_attack(deck_w, party_w, enemies_w, "tinker_rivet_shot", 1)
		_check(r_w["hits"][0]["damage"] == 6, "weak applies after +5: (4+5)*0.75 = 6")
		_check(pinned_w.pinner_for_enemy(1) == "", "pin consumed on weak hit")

		# Prove +5 applies BEFORE Exposed: (4 + 5) * 3 / 2 = 13
		var first_e := CombatTinkerFirstAttack.new()
		first_e.record_successful_attack("tinker_pop_shot")
		var pinned_e := CombatPinned.new()
		var res_e := CombatTinkerPoolAttacks.new(first_e, pinned_e)
		var deck_e := _deck(["tinker_rivet_shot"])
		var party_e := _party()
		var enemies_e := _enemies([50])
		_check(enemies_e.apply_statuses({1: {"exposed": 1}}), "enemy 1 exposed")
		_check(pinned_e.pin_enemy(enemies_e, 1, pinner), "pinned with " + pinner)
		var r_e: Dictionary = res_e.play_attack(deck_e, party_e, enemies_e, "tinker_rivet_shot", 1)
		_check(r_e["hits"][0]["damage"] == 13, "exposed applies after +5: floor((4+5)*1.5) = 13")
		_check(pinned_e.pinner_for_enemy(1) == "", "pin consumed on exposed hit")

	# Same-owner token: no extra +5 and no consumption by ordinary same-owner attack
	var first_same := CombatTinkerFirstAttack.new()
	first_same.record_successful_attack("tinker_pop_shot")
	var pinned_same := CombatPinned.new()
	var resolver_same := CombatTinkerPoolAttacks.new(first_same, pinned_same)
	var deck_same := _deck(["tinker_rivet_shot"])
	var party_same := _party()
	var enemies_same := _enemies([50])
	_check(pinned_same.pin_enemy(enemies_same, 1, "tinker"), "pinned enemy 1 with tinker")
	var res_same: Dictionary = resolver_same.play_attack(deck_same, party_same, enemies_same, "tinker_rivet_shot", 1)
	_check(res_same["hits"][0]["damage"] == 4, "Tinker attack on Tinker pin deals base 4 (no +5 bonus)")
	_check(pinned_same.pinner_for_enemy(1) == "tinker", "Tinker pin is NOT consumed by Tinker attack")

	# Spring Trap replaces cross-owner pin with Tinker pin after hit, other enemy unaffected
	var first_rep := CombatTinkerFirstAttack.new()
	var pinned_rep := CombatPinned.new()
	var resolver_rep := CombatTinkerPoolAttacks.new(first_rep, pinned_rep)
	var deck_rep := _deck(["tinker_spring_trap"])
	var party_rep := _party()
	var enemies_rep := _enemies([50, 50])
	_check(pinned_rep.pin_enemy(enemies_rep, 1, "warden"), "enemy 1 pinned by warden")
	_check(pinned_rep.pin_enemy(enemies_rep, 2, "seamstress"), "enemy 2 pinned by seamstress")
	var res_rep: Dictionary = resolver_rep.play_attack(deck_rep, party_rep, enemies_rep, "tinker_spring_trap", 1)
	_check(res_rep["hits"][0]["damage"] == 11, "Spring Trap deals 3 + 3 (first) + 5 (pin) = 11")
	_check(pinned_rep.pinner_for_enemy(1) == "tinker", "enemy 1 re-pinned by tinker")
	_check(pinned_rep.pinner_for_enemy(2) == "seamstress", "enemy 2 token completely unaffected")

	# Lethal hit on cross-owner pin consumes token, does NOT place Tinker pin
	var first_ck := CombatTinkerFirstAttack.new()
	first_ck.record_successful_attack("tinker_pop_shot")
	var pinned_ck := CombatPinned.new()
	var resolver_ck := CombatTinkerPoolAttacks.new(first_ck, pinned_ck)
	var deck_ck := _deck(["tinker_spring_trap"])
	var party_ck := _party()
	var enemies_ck := _enemies([7])
	_check(pinned_ck.pin_enemy(enemies_ck, 1, "warden"), "enemy 1 pinned by warden")
	var res_ck: Dictionary = resolver_ck.play_attack(deck_ck, party_ck, enemies_ck, "tinker_spring_trap", 1)
	_check(res_ck["hits"][0]["damage"] == 8 and res_ck["hits"][0]["hp_loss"] == 7, "lethal cross hit")
	_check(enemies_ck.is_slain(1), "enemy 1 slain")
	_check(pinned_ck.pinner_for_enemy(1) == "", "cross-owner pin consumed and dead enemy not pinned")

	# Scatter Bolts against multiple independently pinned targets and an unpinned target
	var first_sb := CombatTinkerFirstAttack.new()
	first_sb.record_successful_attack("tinker_pop_shot")
	var pinned_sb := CombatPinned.new()
	var resolver_sb := CombatTinkerPoolAttacks.new(first_sb, pinned_sb)
	var deck_sb := _deck(["tinker_scatter_bolts"])
	var party_sb := _party()
	var enemies_sb := _enemies([30, 30, 30])
	_check(pinned_sb.pin_enemy(enemies_sb, 1, "warden"), "slot 1 pinned by warden")
	_check(pinned_sb.pin_enemy(enemies_sb, 3, "seamstress"), "slot 3 pinned by seamstress")
	var res_sb: Dictionary = resolver_sb.play_attack(deck_sb, party_sb, enemies_sb, "tinker_scatter_bolts", 0)
	_check(res_sb.get("ok", false) and res_sb["hits"].size() == 3, "Scatter hits all 3 enemies")
	_check(res_sb["hits"][0]["position"] == 1 and res_sb["hits"][0]["damage"] == 8, "enemy 1 takes 3 + 5 = 8")
	_check(res_sb["hits"][1]["position"] == 2 and res_sb["hits"][1]["damage"] == 3, "enemy 2 takes base 3")
	_check(res_sb["hits"][2]["position"] == 3 and res_sb["hits"][2]["damage"] == 8, "enemy 3 takes 3 + 5 = 8")
	_check(pinned_sb.pinner_for_enemy(1) == "", "enemy 1 pin consumed")
	_check(pinned_sb.pinner_for_enemy(2) == "", "enemy 2 remained unpinned")
	_check(pinned_sb.pinner_for_enemy(3) == "", "enemy 3 pin consumed")

	# Two Tinker hits on same target: token cannot be claimed twice
	var first_two := CombatTinkerFirstAttack.new()
	first_two.record_successful_attack("tinker_pop_shot")
	var pinned_two := CombatPinned.new()
	var resolver_two := CombatTinkerPoolAttacks.new(first_two, pinned_two)
	var deck_two := _deck(["tinker_rivet_shot", "tinker_rivet_shot"])
	var party_two := _party()
	var enemies_two := _enemies([50])
	_check(pinned_two.pin_enemy(enemies_two, 1, "warden"), "enemy 1 pinned by warden")
	var hit1: Dictionary = resolver_two.play_attack(deck_two, party_two, enemies_two, "tinker_rivet_shot", 1)
	_check(hit1["hits"][0]["damage"] == 9, "first hit claims +5 (4+5=9)")
	_check(pinned_two.pinner_for_enemy(1) == "", "pin consumed")
	var hit2: Dictionary = resolver_two.play_attack(deck_two, party_two, enemies_two, "tinker_rivet_shot", 1)
	_check(hit2["hits"][0]["damage"] == 6, "second hit gets no pin bonus (4*1.5=6)")


func _test_ricochet_pinned_cases() -> void:
	# AC3: Independent oracle replay with pinned state and cloned RNG
	for seed_val in [1, 9, 39, 77]:
		var first := CombatTinkerFirstAttack.new()
		var pinned := CombatPinned.new()
		var deck := _deck(["tinker_ricochet"], seed_val)
		var party := _party(["warden", "tinker", "seamstress"])
		var enemies := _enemies([50, 50, 50])
		_check(pinned.pin_enemy(enemies, 1, "warden"), "enemy 1 pinned by warden")
		var initial_pins: Dictionary = {1: "warden"}
		var oracle: Dictionary = _oracle_random_pinned(deck._rng.state, enemies.get_enemies(),
			4 + 3, {}, 3, initial_pins)
		var resolver := CombatTinkerPoolAttacks.new(first, pinned)
		var result: Dictionary = resolver.play_attack(deck, party, enemies, "tinker_ricochet")
		_check(result.get("ok", false), "seeded Ricochet succeeds")
		var actual_picks: Array[int] = []
		for hit in result["hits"]:
			actual_picks.append(int(hit["position"]))
		_check(actual_picks == oracle["positions"], "actual picks match oracle exactly")
		_check(result["hits"] == oracle["hits"], "actual hit receipts match oracle hits")
		_check(enemies.get_enemies() == oracle["roster"], "final enemy state matches oracle roster")
		_check(deck._rng.state == oracle["state"], "final RNG state matches oracle")

	# Pinned recipient struck twice gets +5 only on first hit
	var first_twice := CombatTinkerFirstAttack.new()
	first_twice.record_successful_attack("tinker_pop_shot")
	var pinned_twice := CombatPinned.new()
	var deck_twice := _deck(["tinker_ricochet"], 1)
	var party_twice := _party(["warden", "tinker", "seamstress"])
	var enemies_twice := _enemies([50, 50])
	_check(pinned_twice.pin_enemy(enemies_twice, 1, "warden"), "enemy 1 pinned by warden")
	var resolver_twice := CombatTinkerPoolAttacks.new(first_twice, pinned_twice)
	var res_twice: Dictionary = resolver_twice.play_attack(deck_twice, party_twice, enemies_twice, "tinker_ricochet")
	_check(res_twice.get("ok", false) and res_twice["hits"].size() == 3, "3 hits generated")
	var count_enemy_1: int = 0
	for h in res_twice["hits"]:
		if int(h["position"]) == 1:
			count_enemy_1 += 1
			if count_enemy_1 == 1:
				_check(h["damage"] == 9, "first hit on enemy 1 gets 4 + 5 = 9")
			else:
				_check(h["damage"] == 4, "subsequent hit on enemy 1 gets base 4 only")
	_check(count_enemy_1 >= 1, "enemy 1 was hit at least once")
	_check(pinned_twice.pinner_for_enemy(1) == "", "pin consumed after play")

	# Pin bonus changes survival: preflight predicts early kill correctly
	for candidate_seed in range(1, 50):
		var rng_test := RandomNumberGenerator.new()
		rng_test.seed = candidate_seed
		if rng_test.randi_range(0, 2) == 0:
			var f := CombatTinkerFirstAttack.new()
			var p := CombatPinned.new()
			var d := _deck(["tinker_ricochet"], candidate_seed)
			var pty := _party(["warden", "tinker", "seamstress"])
			var ens := _enemies([10, 50, 50])
			_check(p.pin_enemy(ens, 1, "warden"), "seed target with pin")
			var r: Dictionary = CombatTinkerPoolAttacks.new(f, p).play_attack(d, pty, ens, "tinker_ricochet")
			_check(r.get("ok", false), "preflight accepted with early kill")
			_check(r["hits"][0]["position"] == 1 and r["hits"][0]["damage"] == 12, "hit 1 kills enemy 1 with 12 damage")
			_check(ens.is_slain(1), "enemy 1 is slain")
			_check(r["hits"][1]["position"] != 1, "hit 2 did not select slain enemy 1")
			_check(r["hits"][2]["position"] != 1, "hit 3 did not select slain enemy 1")
			break

	# Lone pinned enemy killed on hit 1: commits victory, consumes token, stops early
	var f_pin := CombatTinkerFirstAttack.new()
	var p_pin := CombatPinned.new()
	var d_pin := _deck(["tinker_ricochet"])
	var pty_pin := _party(["warden", "tinker", "seamstress"])
	var ens_pin := _enemies([5])
	_check(p_pin.pin_enemy(ens_pin, 1, "warden"), "pinned lone enemy with warden")
	var oracle_pin: Dictionary = _oracle_random_pinned(d_pin._rng.state, ens_pin.get_enemies(),
		4 + 3, {}, 3, {1: "warden"})
	var oracle_pin_clone := RandomNumberGenerator.new()
	oracle_pin_clone.state = oracle_pin["state"]
	var exp_pin_next: int = oracle_pin_clone.randi()

	var res_pin: Dictionary = CombatTinkerPoolAttacks.new(f_pin, p_pin).play_attack(
		d_pin, pty_pin, ens_pin, "tinker_ricochet")
	_check(res_pin.get("ok", false) and res_pin["hits"].size() == 1,
		"lone pinned enemy hit 1 kill succeeds with exactly 1 hit")
	_check(res_pin["hits"] == oracle_pin["hits"],
		"pinned early kill hit receipt matches oracle")
	_check(ens_pin.get_enemies() == oracle_pin["roster"] and ens_pin.is_victorious(),
		"lone pinned enemy is slain and victory committed")
	_check(p_pin.pinner_for_enemy(1) == "",
		"cross-owner pin consumed on lethal first hit")
	_check(d_pin.energy == 2 and d_pin.discard_pile == ["tinker_ricochet"],
		"lone pinned kill spends once and discards once")
	_check(d_pin._rng.state == oracle_pin["state"] and d_pin._rng.randi() == exp_pin_next,
		"lone pinned kill advances RNG by exactly one roll")

	# Pinned 2-hit finish fixture:
	# Enemy 1 has 10 HP pinned by Warden. First attack already consumed.
	# Hit 1: 4 (base) + 5 (pinned) = 9 damage -> 1 HP left, pin consumed.
	# Hit 2: 4 (base) damage -> 1 HP loss -> enemy 1 dies on hit 2!
	# Hit 3: stops! Total hits: 2.
	var f_pin2 := CombatTinkerFirstAttack.new()
	f_pin2.record_successful_attack("tinker_pop_shot")
	var p_pin2 := CombatPinned.new()
	var d_pin2 := _deck(["tinker_ricochet"])
	var pty_pin2 := _party(["warden", "tinker", "seamstress"])
	var ens_pin2 := _enemies([10])
	_check(p_pin2.pin_enemy(ens_pin2, 1, "warden"), "pinned enemy with warden for 2-hit finish")
	var oracle_pin2: Dictionary = _oracle_random_pinned(d_pin2._rng.state, ens_pin2.get_enemies(),
		4, {}, 3, {1: "warden"})
	var oracle_pin2_clone := RandomNumberGenerator.new()
	oracle_pin2_clone.state = oracle_pin2["state"]
	var exp_pin2_next: int = oracle_pin2_clone.randi()

	var res_pin2: Dictionary = CombatTinkerPoolAttacks.new(f_pin2, p_pin2).play_attack(
		d_pin2, pty_pin2, ens_pin2, "tinker_ricochet")
	_check(res_pin2.get("ok", false) and res_pin2["hits"].size() == 2,
		"pinned 2-hit finish generates exactly 2 hits")
	_check(res_pin2["hits"] == oracle_pin2["hits"],
		"pinned 2-hit receipts match oracle exactly")
	_check(ens_pin2.get_enemies() == oracle_pin2["roster"] and ens_pin2.is_victorious(),
		"enemy slain on hit 2 and victory committed")
	_check(p_pin2.pinner_for_enemy(1) == "",
		"pin consumed after hit 1")
	_check(d_pin2.energy == 2 and d_pin2.discard_pile == ["tinker_ricochet"],
		"pinned 2-hit finish spends once and discards once")
	_check(d_pin2._rng.state == oracle_pin2["state"] and d_pin2._rng.randi() == exp_pin2_next,
		"pinned 2-hit finish advances RNG by exactly 2 rolls")


func _reject(resolver: CombatTinkerPoolAttacks, deck: CombatDeck,
		party: CombatParty, enemies: CombatEnemies,
		first: CombatTinkerFirstAttack, reason: String,
		id: String = "tinker_ricochet", target: int = 0) -> void:
	var before := _snapshot(deck, party, enemies, first)
	_check(resolver.play_attack(deck, party, enemies, id, target)
		== {"ok": false, "hits": []}, reason + " must reject")
	_check(_snapshot(deck, party, enemies, first) == before,
		reason + " preserves complete deck, hero, enemy, RNG and latch")


func _reject_pinned(resolver: CombatTinkerPoolAttacks, deck: CombatDeck,
		party: CombatParty, enemies: CombatEnemies,
		first: CombatTinkerFirstAttack, pinned: CombatPinned, reason: String,
		id: String, target: int = 0) -> void:
	var before := _snapshot(deck, party, enemies, first)
	var pins_before: Dictionary = pinned._pinner_by_position.duplicate()
	_check(resolver.play_attack(deck, party, enemies, id, target)
		== {"ok": false, "hits": []}, reason + " must reject")
	_check(_snapshot(deck, party, enemies, first) == before,
		reason + " preserves complete deck, hero, enemy, RNG and latch")
	_check(pinned._pinner_by_position == pins_before,
		reason + " preserves complete token ownership")


func _test_atomic_rejections() -> void:
	var id := "tinker_ricochet"
	var deck := _deck([id, "tinker_scatter_bolts", "tinker_bobbin_cannon",
		"tinker_rivet_shot", "tinker_spare_parts"])
	var party := _party()
	var enemies := _enemies()
	var first := CombatTinkerFirstAttack.new()
	var resolver := CombatTinkerPoolAttacks.new(first)
	_reject(resolver, deck, party, enemies, first, "invalid explicit Ricochet selection", id, 1)
	_reject(resolver, deck, party, enemies, first, "area requires zero selection",
		"tinker_scatter_bolts", 2)
	_reject(resolver, deck, party, enemies, first, "dead/illegal single target",
		"tinker_rivet_shot", 0)
	_reject(resolver, deck, party, enemies, first, "out-of-range target",
		"tinker_rivet_shot", 4)
	_reject(resolver, deck, party, enemies, first, "unsupported pool card",
		"tinker_spare_parts", 1)
	var no_pinned_deck := _deck(["tinker_spring_trap"])
	_reject(resolver, no_pinned_deck, _party(), _enemies(), first,
		"Spring Trap without Pinned dependency", "tinker_spring_trap", 1)
	_reject(resolver, deck, party, enemies, first, "not held plus card",
		"tinker_ricochet_plus", 0)
	_check(enemies.apply_damage(2, 70), "dead-selection fixture prepared")
	_reject(resolver, deck, party, enemies, first, "slain selected slot",
		"tinker_rivet_shot", 2)
	_check(party.apply_damage(3, 26) and party.is_downed(3),
		"Tinker downed fixture prepared via real damage")
	_reject(resolver, deck, party, enemies, first, "downed Tinker")
	var different := _party(["tinker", "warden", "seamstress"])
	_check(different.get_hero(1)["id"] == "tinker", "front-slot fixture prepared")
	_reject(resolver, deck, different, enemies, first, "front-position Tinker")
	var empty_deck := _deck(["tinker_bobbin_cannon"])
	_check(empty_deck.try_spend_energy(1) and empty_deck.energy == 2,
		"insufficient energy precondition")
	_reject(resolver, empty_deck, _party(), _enemies(), first,
		"insufficient energy for Bobbin", "tinker_bobbin_cannon", 1)
	var inactive := _deck([id])
	_check(inactive.end_turn() and not inactive.turn_active,
		"inactive-turn fixture is really inactive")
	_reject(resolver, inactive, _party(), _enemies(), first, "inactive turn")
	var missing := _deck(["warden_strike"])
	_reject(resolver, missing, _party(), _enemies(), first, "missing held card")
	var empty_enemies := _enemies([1])
	_check(empty_enemies.apply_damage(1, 1) and empty_enemies.is_victorious(),
		"victory state precondition")
	_reject(resolver, _deck([id]), _party(), empty_enemies, first, "empty living targets")

	# Pinned-equipped atomic failure cases
	var pinned_all := CombatPinned.new()
	var resolver_pinned := CombatTinkerPoolAttacks.new(first, pinned_all)
	var deck_p := _deck(["tinker_spring_trap"])
	var party_p := _party()
	var enemies_p := _enemies([50, 50, 50])
	_check(pinned_all.pin_enemy(enemies_p, 1, "warden"), "pinned enemy 1")
	_check(pinned_all.pin_enemy(enemies_p, 2, "seamstress"), "pinned enemy 2")
	_reject_pinned(resolver_pinned, deck_p, party_p, enemies_p, first, pinned_all,
		"Spring Trap with invalid position 0", "tinker_spring_trap", 0)
	_reject_pinned(resolver_pinned, deck_p, party_p, enemies_p, first, pinned_all,
		"Spring Trap with out-of-range position 4", "tinker_spring_trap", 4)
	_check(enemies_p.apply_damage(3, 100), "kill enemy 3")
	_reject_pinned(resolver_pinned, deck_p, party_p, enemies_p, first, pinned_all,
		"Spring Trap with slain position 3", "tinker_spring_trap", 3)

	# Ricochet with Pinned rejects atomically when all targets are dead BEFORE play
	var empty_pinned_enemies := _enemies([1])
	_check(empty_pinned_enemies.apply_damage(1, 1) and empty_pinned_enemies.is_victorious(),
		"already victorious before play precondition")
	_reject_pinned(resolver_pinned, _deck([id]), _party(), empty_pinned_enemies, first, pinned_all,
		"Ricochet with empty living targets before play", id, 0)
