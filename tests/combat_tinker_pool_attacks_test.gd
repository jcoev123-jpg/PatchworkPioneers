extends SceneTree
## Real catalog/deck/party/enemy regression for Tinker's six direct-fire cards and Pinned interactions.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_catalog_and_ten_variants()
	_test_rivet_order_and_duplicates()
	_test_area_original_positions()
	_test_scatter_bolts_lethal_area_victory()
	_test_ricochet_route_quote()
	_test_ricochet_replay()
	_test_ricochet_hit2_finish()
	_test_shared_first_attack()
	_test_spring_trap_cases()
	_test_cross_owner_follow_up_cases()
	_test_ricochet_pinned_cases()
	_test_atomic_rejections()
	_test_worn_pincushion_attacks()
	_test_worn_pincushion_ricochet_lethal_and_rejections()
	_test_worn_pincushion_foreign_pins()
	_test_button_eye_twelve_catalog_attacks()
	_test_button_eye_latch_and_rejections()
	_test_button_eye_overflow_and_lethal()
	_test_visor_rivet_shot_variants()
	_test_visor_other_five_families_and_alternate_wearers()
	_test_visor_stale_failed_and_torn_rejections()
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



## A quote must agree with independent genuine play on separate seeded combat
## authorities, without ever spending, consuming a pin or advancing the RNG.
func _test_ricochet_route_quote() -> void:
	for card_id in ["tinker_ricochet", "tinker_ricochet_plus"]:
		for scenario in ["one_kill", "one_block", "two", "three_hole", "three"]:
			var hps: Array = [1] if scenario == "one_kill" else (
				[7 if card_id == "tinker_ricochet" else 9] if scenario == "one_block"
				else [5, 60] if scenario == "two" else [60, 1, 60]
				if scenario == "three_hole" else [80, 80, 80])
			var outcomes: Array = []
			for independent in [false, true]:
				var first := CombatTinkerFirstAttack.new()
				if scenario == "three":
					first.record_successful_attack("tinker_pop_shot")
				var pin := CombatPinned.new()
				var deck := _deck([card_id, "warden_brace"], 39)
				var party := _party(["warden", "tinker", "seamstress"] if scenario == "two"
					else ["warden", "seamstress", "tinker"])
				var enemies := _enemies(hps)
				if scenario == "one_block":
					_check(enemies.gain_block(1, 4 if card_id == "tinker_ricochet" else 5),
						"quote blocked lone survivor precondition")
				if scenario == "three_hole":
					_check(enemies.apply_damage(2, 1) and enemies.is_slain(2),
						"quote fixture preserves the dead original slot 2")
					party._heroes[2]["statuses"] = {"weak": 1}
					_check(enemies.apply_statuses({3: {"exposed": 1}})
						and pin.pin_enemy(enemies, 1, "warden"),
						"quote fixture has Weak, Exposed and a foreign Pinned bonus")
				var resolver := CombatTinkerPoolAttacks.new(first, pin)
				if not independent:
					var before := _snapshot(deck, party, enemies, first)
					var pins_before: Dictionary = pin._pinner_by_position.duplicate(true)
					var path_before: int = first.path_bonus()
					var quote: Dictionary = resolver.preview_ricochet_route(
						deck, party, enemies, card_id)
					var again: Dictionary = resolver.preview_ricochet_route(
						deck, party, enemies, card_id)
					_check(quote.get("ok", false) and quote.positions is Array
						and quote.positions.size() >= 1 and quote.positions.size() <= 3
						and quote == again,
						card_id + " " + scenario + ": repeated quote is legal and stable")
					_check(_snapshot(deck, party, enemies, first) == before
						and pin._pinner_by_position == pins_before
						and first.path_bonus() == path_before,
						card_id + " " + scenario + ": quote leaves all battle and pin state intact")
					if quote.get("ok", false):
						if scenario == "one_kill":
							_check(quote.positions == [1], "terminal hit 1 quote truncates")
						elif scenario == "one_block":
							_check(quote.positions == [1, 1], "blocked terminal hit 2 quote truncates")
						elif scenario == "three_hole":
							_check(not quote.positions.has(2), "dead original slot 2 is never forecast")
						elif scenario == "three":
							_check(quote.positions.size() == 3, "three surviving targets keep all hits")
					outcomes.append(quote.get("positions", []))
				var played: Dictionary = resolver.play_attack(deck, party, enemies, card_id)
				_check(played.get("ok", false) and not played.get("hits", []).is_empty(),
					card_id + " " + scenario + ": genuine independent cast succeeded")
				var positions: Array[int] = []
				for hit in played.get("hits", []):
					positions.append(hit["position"])
				outcomes.append(positions)
			_check(outcomes.size() == 3 and outcomes[0] == outcomes[1]
				and outcomes[1] == outcomes[2],
				card_id + " " + scenario + ": read-only quote equals two genuine seeded plays")

	# Unheld/unsupported, affordability, dead-roster and inactive-turn refusals
	# are as nondestructive as positive quotes.
	for rejection in ["unsupported", "unheld", "energy", "dead", "inactive", "bad_slot"]:
		var id := "tinker_ricochet"
		var deck := _deck([id])
		var party := _party()
		var enemies := _enemies([30, 30])
		var first := CombatTinkerFirstAttack.new()
		var resolver := CombatTinkerPoolAttacks.new(first)
		if rejection == "unheld":
			_check(deck.discard_played(id), "unheld rejection actually removed card")
		elif rejection == "energy":
			deck.combat_state.energy = 0
		elif rejection == "dead":
			_check(enemies.apply_damage(1, 30) and enemies.apply_damage(2, 30),
				"dead-roster rejection actually has no living target")
		elif rejection == "inactive":
			_check(deck.end_turn(), "inactive-turn rejection actually closed the turn")
		elif rejection == "bad_slot":
			var moved := CombatPositionSwaps.preview_adjacent_swap(party, 3, -1)
			_check(moved.get("ok", false), "bad-slot fixture can move Tinker to slot 2")
			party._heroes.assign(moved.heroes)
			moved = CombatPositionSwaps.preview_adjacent_swap(party, 2, -1)
			_check(moved.get("ok", false), "bad-slot fixture can move Tinker to slot 1")
			party._heroes.assign(moved.heroes)
		var before := _snapshot(deck, party, enemies, first)
		var quote := resolver.preview_ricochet_route(deck, party, enemies,
			"tinker_scatter_bolts" if rejection == "unsupported" else id)
		_check(quote == {"ok": false, "positions": []}
			and before == _snapshot(deck, party, enemies, first),
			"failed Ricochet quote has no guessed hits and no state mutation: " + rejection)


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

## Construct the real sewn run ledger, not a synthetic or manually populated projection.
func _pincushion_context(party: CombatParty, wearer: String = "tinker",
		owned: bool = true) -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_attack_patches.json"))
	_check(raw is Array and raw.size() >= 2, "authored M04 attack patch metadata parsed")
	var definitions: Array = []
	for entry in raw:
		definitions.append({"id": entry["id"], "slot": entry["slot"]})
	var torn := RunTornMending.new(party.get_heroes())
	var wardrobe := RunPatchWardrobe.new(party.get_heroes(),
		["pincushion_arm"] if owned else [], definitions, 3)
	_check(torn.is_valid() and wardrobe.is_valid(), "genuine three-hero run patch ledgers valid")
	if owned:
		var sewn: Dictionary = wardrobe.sew("pincushion_arm", wearer, "ARM",
			"sew_pincushion", wardrobe.get_snapshot())
		_check(sewn.get("ok", false) and sewn["state"]["worn"][wearer]["ARM"] == "pincushion_arm",
			"unique authored ARM patch sewn on actual wearer")
	return {"wardrobe": wardrobe, "torn": torn}


func _test_worn_pincushion_attacks() -> void:
	# Every base and upgrade uses its own catalog damage and applies +1 on every hit.
	for row in _rows():
		for upgrade in [false, true]:
			var id: String = row["base"] + ("_plus" if upgrade else "")
			var definition: Dictionary = TinkerPoolCards.new().get_definition(id)
			var raw_damage: int = definition["effects"]["damage"]
			var first := CombatTinkerFirstAttack.new()
			var pinned := CombatPinned.new()
			var resolver := CombatTinkerPoolAttacks.new(first, pinned)
			var party := _party()
			var ctx := _pincushion_context(party)
			_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn)
				and resolver._patches.damage_bonus("tinker") == 1
				and resolver._patches.damage_bonus("warden") == 0,
				id + " binds live-wearer-only patch projection")
			var foes := _enemies([100, 100, 100])
			# Weak and Exposed run through the actual authoritative rosters.
			party._heroes[2]["statuses"] = {"weak": 1}
			foes._enemies[0]["statuses"] = {"exposed": 1}
			_check(foes.gain_block(1, 2) and foes.gain_block(2, 3),
				id + " blocked enemies prepared")
			var deck := _deck([id], 39)
			var before := _snapshot(deck, party, foes, first)
			var expected_roster: Array = before["enemies"].duplicate(true)
			var positions: Array[int] = []
			if row["kind"] == "enemy_single":
				positions.assign([1])
			elif row["kind"] == "enemy_all":
				positions.assign([1, 2, 3])
			else:
				var random_oracle: Dictionary = _oracle_random(before["rng"], foes.get_enemies(),
					raw_damage + 3 + 1, {"weak": 1}, 3)
				positions.assign(random_oracle["positions"])
			var expected_hits: Array = []
			for position in positions:
				var actor: Dictionary = expected_roster[position - 1]
				var damage: int = CombatStatuses.new().adjusted_attack_damage(raw_damage + 3 + 1,
					{"weak": 1}, actor.get("statuses", {}))
				var absorbed: int = mini(actor["block"], damage)
				var lost: int = mini(actor["hp"], damage - absorbed)
				actor["block"] -= absorbed
				actor["hp"] -= lost
				var applied: Dictionary = {}
				if row["base"] == "tinker_rivet_shot":
					applied = {"exposed": 1}
					actor["statuses"]["exposed"] = actor["statuses"].get("exposed", 0) + 1
				var hit: Dictionary = {"position": position, "damage": damage,
					"block_absorbed": absorbed, "hp_loss": lost, "statuses": applied}
				if row["base"] == "tinker_spring_trap":
					hit["pinned"] = true
				expected_hits.append(hit)
			var result: Dictionary = resolver.play_attack(deck, party, foes, id,
				1 if row["kind"] == "enemy_single" else 0)
			_check(result == {"ok": true, "hits": expected_hits},
				id + " exact patched ordered hit and status arithmetic")
			_check(foes.get_enemies() == expected_roster and party.get_heroes() == before["party"],
				id + " patched HP/Block/owner status transition matches independent oracle")
			_check(deck.energy == 3 - definition["cost"] and deck.discard_pile == [id]
				and first._consumed and ctx.wardrobe.get_snapshot()["worn"]["tinker"]["ARM"] == "pincushion_arm",
				id + " single spend, first passive latch and unchanged wardrobe")
			if row["kind"] == "enemy_random":
				var oracle: Dictionary = _oracle_random(before["rng"], before["enemies"],
					raw_damage + 4, {"weak": 1}, 3)
				_check(deck._rng.state == oracle["state"] and positions == oracle["positions"],
					id + " seeded Ricochet draws exactly as patched simulation")
			else:
				_check(deck._rng.state == before["rng"], id + " patched nonrandom cast draws no RNG")
			if row["base"] == "tinker_spring_trap":
				_check(pinned.pinner_for_enemy(1) == "tinker",
					id + " preserved Spring Trap pin effect")

	# Second Tinker attack in the same turn has +1 patch but no +3 passive.
	var party := _party()
	var ctx := _pincushion_context(party)
	var first := CombatTinkerFirstAttack.new()
	var resolver := CombatTinkerPoolAttacks.new(first)
	_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn), "double-attack bind")
	var deck := _deck(["tinker_long_barrel", "tinker_rivet_shot"])
	var foes := _enemies([100])
	var a: Dictionary = resolver.play_attack(deck, party, foes, "tinker_long_barrel", 1)
	var b: Dictionary = resolver.play_attack(deck, party, foes, "tinker_rivet_shot", 1)
	_check(a["ok"] and a["hits"][0]["damage"] == 16 and b["ok"]
		and b["hits"][0]["damage"] == 5 and first._consumed and foes.get_enemy(1)["hp"] == 79,
		"first +3 applies once, permanent +1 remains on second attack without early Exposed")

	# Different wearer and owned-but-unsown patch never leaks to Tinker.
	for mode in ["warden", "absent", "torn_warden"]:
		party = _party()
		ctx = _pincushion_context(party, "warden", mode != "absent")
		if mode == "torn_warden":
			var start: Array = ctx.torn.read_state()["heroes"]
			_check(party.apply_damage(1, 999) and party.is_downed(1),
				"torn other-wearer actually downed in CombatParty")
			_check(ctx.torn.observe_battle_end("tear_warden", start, party.get_heroes())["ok"],
				"torn ledger records downed other wearer")
			var ts_torn = ctx.torn.read_state()
			var w_snap = ctx.wardrobe.get_snapshot()
			_check(ctx.wardrobe.refresh_run_context(ts_torn.heroes, w_snap.owned, w_snap.scraps, w_snap.gold, w_snap.cards, w_snap),
				"wardrobe torn sync")
		resolver = CombatTinkerPoolAttacks.new()
		_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn)
			and resolver._patches.damage_bonus("tinker") == 0,
			mode + " valid projection grants no Tinker bonus")
		deck = _deck(["tinker_long_barrel"])
		foes = _enemies()
		var result: Dictionary = resolver.play_attack(deck, party, foes, "tinker_long_barrel", 1)
		_check(result.get("ok", false) and result["hits"][0]["damage"] == 15,
			mode + " retains unpatched first-attack +3 damage")


func _test_worn_pincushion_ricochet_lethal_and_rejections() -> void:
	# A +1-patched first hit kills enemy 1 where the unpatched one would not;
	# preflight must then draw hit 2 from only survivors, with identical run RNG.
	for upgrade in [false, true]:
		var id := "tinker_ricochet_plus" if upgrade else "tinker_ricochet"
		var first_damage: int = 10 if upgrade else 8
		var selected_seed := -1
		for trial in range(1, 100):
			var check_rng := RandomNumberGenerator.new()
			check_rng.seed = trial
			if check_rng.randi_range(0, 2) == 0:
				selected_seed = trial
				break
		_check(selected_seed > 0, "seed selects patch-lethal enemy 1 first")
		var replay: Dictionary = {}
		for attempt in 2:
			var party := _party()
			var ctx := _pincushion_context(party)
			var first := CombatTinkerFirstAttack.new()
			var resolver := CombatTinkerPoolAttacks.new(first)
			_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn), "Ricochet valid sewn bind")
			var deck := _deck([id], selected_seed)
			var foes := _enemies([first_damage, 50, 50])
			var oracle: Dictionary = _oracle_random(deck._rng.state, foes.get_enemies(),
				first_damage, {}, 3)
			var result: Dictionary = resolver.play_attack(deck, party, foes, id)
			var picks: Array[int] = []
			for hit in result.get("hits", []):
				picks.append(hit["position"])
			_check(result.get("ok", false) and picks == oracle["positions"]
				and picks.size() == 3 and picks[0] == 1
				and not picks.slice(1).has(1) and foes.is_slain(1),
				id + " patched hit-1 lethal recomputes living target pool")
			_check(foes.get_enemies() == oracle["roster"] and deck._rng.state == oracle["state"]
				and deck.energy == 2 and first._consumed,
				id + " preflight and commit share exact patched selection and RNG")
			var outcome := {"result": result, "foes": foes.get_enemies(), "rng": deck._rng.state}
			if attempt == 0:
				replay = outcome
			else:
				_check(outcome == replay, id + " patch lethal full seeded replay")

	# A failed explicit binding cannot turn into a playable unpatched resolver.
	var party := _party()
	var ctx := _pincushion_context(party)
	var first := CombatTinkerFirstAttack.new()
	var resolver := CombatTinkerPoolAttacks.new(first, CombatPinned.new())
	_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn), "reject fixture bound initially")
	var deck := _deck(["tinker_ricochet"])
	var foes := _enemies()
	_check(not resolver.bind_patch_wardrobe(null, ctx.torn)
		and not resolver._patches.is_valid(), "invalid explicit patch binding fails closed")
	var before := _snapshot(deck, party, foes, first)
	_check(resolver.play_attack(deck, party, foes, "tinker_ricochet") == {"ok": false, "hits": []}
		and _snapshot(deck, party, foes, first) == before,
		"invalid binding preserves cards, RNG, party, foes, pinned and first latch")
	_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn),
		"valid rebind can recover explicitly")
	_check(deck.try_spend_energy(3), "energy-negative precondition really spent energy")
	before = _snapshot(deck, party, foes, first)
	_check(not resolver.play_attack(deck, party, foes, "tinker_ricochet")["ok"]
		and _snapshot(deck, party, foes, first) == before,
		"patched Ricochet insufficient energy is atomic")
	deck.energy = 3
	deck.combat_state.energy = 3
	before = _snapshot(deck, party, foes, first)
	_check(not resolver.play_attack(deck, party, foes, "tinker_ricochet", 4)["ok"]
		and _snapshot(deck, party, foes, first) == before,
		"patched Ricochet invalid target cannot partially hit or draw RNG")

func _test_worn_pincushion_foreign_pins() -> void:
	# Patched area damage combines +1 and foreign Pinned +5 before both status floors.
	var party := _party()
	var ctx := _pincushion_context(party)
	var pinned := CombatPinned.new()
	var first := CombatTinkerFirstAttack.new()
	var resolver := CombatTinkerPoolAttacks.new(first, pinned)
	_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn),
		"patched Scatter binds authentic wardrobe")
	var foes := _enemies([70, 70, 70])
	var deck := _deck(["tinker_scatter_bolts"])
	party._heroes[2]["statuses"] = {"weak": 1}
	foes._enemies[0]["statuses"] = {"exposed": 1}
	_check(foes.gain_block(1, 3), "foreign-pinned exposed target has 3 Block")
	_check(pinned.pin_enemy(foes, 1, "warden") and pinned.pin_enemy(foes, 2, "tinker"),
		"foreign and same-owner pins exist before Scatter")
	var rng_before: int = deck._rng.state
	var actual: Dictionary = resolver.play_attack(deck, party, foes, "tinker_scatter_bolts")
	var expected_first: int = CombatStatuses.new().adjusted_attack_damage(3 + 3 + 1 + 5,
		{"weak": 1}, {"exposed": 1})
	var expected_rest: int = CombatStatuses.new().adjusted_attack_damage(3 + 3 + 1,
		{"weak": 1}, {})
	_check(actual == {"ok": true, "hits": [
		{"position": 1, "damage": expected_first, "block_absorbed": 3,
			"hp_loss": expected_first - 3, "statuses": {}},
		{"position": 2, "damage": expected_rest, "block_absorbed": 0,
			"hp_loss": expected_rest, "statuses": {}},
		{"position": 3, "damage": expected_rest, "block_absorbed": 0,
			"hp_loss": expected_rest, "statuses": {}}]},
		"patched Scatter applies +1 per hit and foreign +5 once before Weak/Exposed")
	_check(pinned.pinner_for_enemy(1).is_empty() and pinned.pinner_for_enemy(2) == "tinker"
		and deck._rng.state == rng_before and first._consumed,
		"foreign pin consumed but same-owner pin and RNG preserved")
	_check(foes.get_enemy(1)["hp"] == 70 - expected_first + 3
		and foes.get_enemy(2)["hp"] == 70 - expected_rest
		and foes.get_enemy(3)["hp"] == 70 - expected_rest,
		"patched Scatter roster matches cross-owner hit arithmetic")

	# Sequential Ricochet preflight also snapshots and consumes foreign Pinned
	# on its actual picked target, never on an unchosen slot.
	for id in ["tinker_ricochet", "tinker_ricochet_plus"]:
		var raw: int = TinkerPoolCards.new().get_definition(id)["effects"]["damage"]
		var seed := -1
		for trial in range(1, 100):
			var rng := RandomNumberGenerator.new()
			rng.seed = trial
			if rng.randi_range(0, 2) == 0:
				seed = trial
				break
		_check(seed > 0, "seed picks foreign-pinned slot first")
		var reference: Dictionary = {}
		for repeat in 2:
			party = _party()
			ctx = _pincushion_context(party)
			pinned = CombatPinned.new()
			first = CombatTinkerFirstAttack.new()
			resolver = CombatTinkerPoolAttacks.new(first, pinned)
			_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn),
				id + " worn Ricochet projection accepted")
			foes = _enemies([100, 100, 100])
			foes._enemies[0]["statuses"] = {"exposed": 1}
			party._heroes[2]["statuses"] = {"weak": 1}
			_check(pinned.pin_enemy(foes, 1, "seamstress")
				and pinned.pin_enemy(foes, 2, "tinker"), "different/same-owner Ricochet pins active")
			deck = _deck([id], seed)
			var oracle: Dictionary = _oracle_random_pinned(deck._rng.state, foes.get_enemies(),
				raw + 3 + 1, {"weak": 1}, 3, pinned._pinner_by_position)
			actual = resolver.play_attack(deck, party, foes, id)
			_check(actual == {"ok": true, "hits": oracle["hits"]}
				and foes.get_enemies() == oracle["roster"]
				and deck._rng.state == oracle["state"],
				id + " exact patched Ricochet + foreign pin ordered hit and replay oracle")
			_check(pinned._pinner_by_position == oracle["pins"]
				and pinned.pinner_for_enemy(1).is_empty()
				and pinned.pinner_for_enemy(2) == "tinker",
				id + " consumes selected foreign pin only and leaves same-owner pin")
			var outcome := {"events": actual, "roster": foes.get_enemies(), "rng": deck._rng.state}
			if repeat == 0:
				reference = outcome
			else:
				_check(reference == outcome, id + " independent patched foreign-pin replay exact")

## Sew the authored HEAD patch onto the actual run wardrobe. Optional ARM
## coverage proves that both independent powers can share one bound projection.
func _button_context(party: CombatParty, wearer: String = "tinker",
		sew_button: bool = true, sew_arm: bool = false) -> Dictionary:
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_attack_patches.json"))
	_check(catalog is Array and catalog.size() >= 2,
		"Button Eye fixture reads real M04 patch catalog")
	var definitions: Array = []
	for entry in catalog:
		definitions.append({"id": entry["id"], "slot": entry["slot"]})
	var owned: Array = []
	if sew_button:
		owned.append("button_eye")
	if sew_arm:
		owned.append("pincushion_arm")
	var torn := RunTornMending.new(party.get_heroes())
	var wardrobe := RunPatchWardrobe.new(party.get_heroes(), owned, definitions, 3)
	_check(torn.is_valid() and wardrobe.is_valid(), "Button Eye genuine run ledgers valid")
	if sew_button:
		var result: Dictionary = wardrobe.sew("button_eye", wearer, "HEAD",
			"sew_button_eye", wardrobe.get_snapshot())
		_check(result.get("ok", false)
			and wardrobe.get_snapshot()["worn"][wearer]["HEAD"] == "button_eye",
			"Button Eye sewn on actual HEAD slot")
	if sew_arm:
		var result: Dictionary = wardrobe.sew("pincushion_arm", "tinker", "ARM",
			"sew_button_arm", wardrobe.get_snapshot())
		_check(result.get("ok", false)
			and wardrobe.get_snapshot()["worn"]["tinker"]["ARM"] == "pincushion_arm",
			"independent Pincushion sewn on real ARM slot")
	return {"wardrobe": wardrobe, "torn": torn}


func _button_snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		first: CombatTinkerFirstAttack, resolver: CombatTinkerPoolAttacks,
		ctx: Dictionary, pinned: CombatPinned) -> Dictionary:
	var result: Dictionary = _snapshot(deck, party, enemies, first)
	result["patch_latches"] = resolver._patches.latch_snapshot()
	result["patch_active"] = resolver._patches.active_snapshot()
	result["wardrobe"] = ctx.wardrobe.get_snapshot()
	result["torn"] = ctx.torn.read_state()
	result["pins"] = pinned._pinner_by_position.duplicate(true)
	return result


func _button_reject(resolver: CombatTinkerPoolAttacks, deck: CombatDeck,
		party: CombatParty, enemies: CombatEnemies, first: CombatTinkerFirstAttack,
		ctx: Dictionary, pinned: CombatPinned, card_id: String, target: int,
		label: String) -> void:
	var before: Dictionary = _button_snapshot(deck, party, enemies, first,
		resolver, ctx, pinned)
	_check(resolver.play_attack(deck, party, enemies, card_id, target) == _failed_play(),
		label + " rejected in production resolver")
	_check(_button_snapshot(deck, party, enemies, first, resolver, ctx, pinned) == before,
		label + " rejects atomically (both latches, cards, energy, rosters, pins, RNG and ledgers)")


func _failed_play() -> Dictionary:
	return {"ok": false, "hits": []}


func _test_button_eye_twelve_catalog_attacks() -> void:
	var catalog := TinkerPoolCards.new()
	for row in _rows():
		for upgrade in [false, true]:
			var id: String = row["base"] + ("_plus" if upgrade else "")
			var definition: Dictionary = catalog.get_definition(id)
			_check(definition.get("id") == id and definition.get("effects", {}).get("damage")
				== row["damage"][1 if upgrade else 0] and definition["cost"] == row["cost"]
				and definition["from_positions"] == row["from"]
				and definition["to_positions"] == [1, 2, 3]
				and definition["target_kind"] == row["kind"],
				id + " uses genuine full base/+ definition and legal from/to/cost")
			var party := _party(["warden", "tinker", "seamstress"]
				if row["from"].has(2) else ["warden", "seamstress", "tinker"])
			# Run ledgers begin at the canonical starter lineup; battle positions
			# may change independently after combat has begun.
			var ctx := _button_context(_party())
			var first := CombatTinkerFirstAttack.new()
			var pinned := CombatPinned.new()
			var resolver := CombatTinkerPoolAttacks.new(first, pinned)
			_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn)
				and resolver._patches.active_snapshot()["tinker"] == ["button_eye"]
				and resolver._patches.exposed_for_first_hit("tinker") == {"exposed": 1}
				and not resolver._patches.latch_snapshot().get("tinker", false),
				id + " binds owned, living HEAD effect not yet consumed")
			var enemies := _enemies([120, 120, 120])
			if row["kind"] == "enemy_all":
				_check(enemies.apply_damage(1, 120) and enemies.is_slain(1),
					id + " area precondition skips original dead slot 1")
			_check(enemies.gain_block(2, 2) and enemies.gain_block(3, 3)
				and enemies.apply_statuses({3: {"exposed": 1}}),
				id + " live original enemy slots retain Block and preexisting Exposed")
			party._heroes[1 if row["from"].has(2) else 2]["statuses"] = {"weak": 1}
			var deck := _deck([id, "warden_brace"], 39)
			var before := _button_snapshot(deck, party, enemies, first, resolver, ctx, pinned)
			var positions: Array[int] = []
			var expected_rng: int = before["rng"]
			if row["kind"] == "enemy_single":
				positions.assign([2])
			elif row["kind"] == "enemy_all":
				positions.assign([2, 3])
			else:
				var oracle := _oracle_random(before["rng"], enemies.get_enemies(),
					int(definition["effects"]["damage"]) + 3, {"weak": 1}, 3)
				positions.assign(oracle["positions"])
				expected_rng = oracle["state"]
				_check(positions.size() == 3,
					id + " seeded three-hit Ricochet has three living high-HP targets")
			var expected_enemies: Array = before["enemies"].duplicate(true)
			var expected_hits: Array = []
			for position in positions:
				var actor: Dictionary = expected_enemies[position - 1]
				var damage: int = CombatStatuses.new().adjusted_attack_damage(
					int(definition["effects"]["damage"]) + 3, {"weak": 1},
					actor.get("statuses", {}))
				var absorbed: int = mini(actor["block"], damage)
				var lost: int = mini(actor["hp"], damage - absorbed)
				actor["block"] -= absorbed
				actor["hp"] -= lost
				var receipt: Dictionary = {"position": position, "damage": damage,
					"block_absorbed": absorbed, "hp_loss": lost, "statuses": {}}
				if row["base"] == "tinker_spring_trap":
					receipt["pinned"] = true
				expected_hits.append(receipt)
			var first_target: int = positions[0]
			var added: int = 2 if row["base"] == "tinker_rivet_shot" else 1
			expected_hits[0]["statuses"] = {"exposed": added}
			var recipient: Dictionary = expected_enemies[first_target - 1]
			if not recipient.has("statuses"):
				recipient["statuses"] = {}
			recipient["statuses"]["exposed"] = recipient["statuses"].get("exposed", 0) + added
			var result: Dictionary = resolver.play_attack(deck, party, enemies, id,
				2 if row["kind"] == "enemy_single" else 0)
			_check(result == {"ok": true, "hits": expected_hits},
				id + " exact first-hit patch receipt, hit order and unmodified damage")
			_check(enemies.get_enemies() == expected_enemies,
				id + " exact original-position HP/Block/Exposed final roster")
			_check(result.get("ok", false) and result["hits"][0]["position"] == first_target
				and enemies.get_enemy(first_target)["statuses"]["exposed"]
					== before["enemies"][first_target - 1].get("statuses", {}).get("exposed", 0) + added,
				id + " patch attaches once to FIRST actual original enemy hit")
			_check(deck.energy == before["energy"] - definition["cost"]
				and deck.hand == ["warden_brace"] and deck.discard_pile == [id]
				and deck._rng.state == expected_rng and first._consumed,
				id + " one card spend, unchanged independent first-turn passive and exact RNG")
			_check(party.get_heroes() == before["party"]
				and ctx.wardrobe.get_snapshot() == before["wardrobe"]
				and ctx.torn.read_state() == before["torn"]
				and resolver._patches.latch_snapshot().get("tinker", false)
				and resolver._patches.exposed_for_first_hit("tinker").is_empty(),
				id + " correct run ledger remains detached and combat-only patch latch consumed")
			if row["base"] == "tinker_spring_trap":
				_check(pinned.pinner_for_enemy(first_target) == "tinker",
					id + " Spring Trap still pins confirmed first target")
			if row["kind"] == "enemy_random":
				_check(result["hits"].size() == 3
					and result["hits"][1]["statuses"] == {}
					and result["hits"][2]["statuses"] == {},
					id + " only first Ricochet hit owns patch receipt even with repeat picks")


func _test_button_eye_latch_and_rejections() -> void:
	var party := _party()
	var ctx := _button_context(party)
	var first := CombatTinkerFirstAttack.new()
	var pinned := CombatPinned.new()
	var resolver := CombatTinkerPoolAttacks.new(first, pinned)
	_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn), "latch fixture binds")
	var deck := _deck(["tinker_scatter_bolts", "tinker_rivet_shot_plus",
		"tinker_long_barrel", "warden_brace"])
	var enemies := _enemies([120, 120, 120])
	_check(pinned.pin_enemy(enemies, 1, "warden"), "rejection protects foreign pin token")
	_button_reject(resolver, deck, party, enemies, first, ctx, pinned,
		"tinker_rivet_shot_plus", 0, "first attempt wrong target")
	_button_reject(resolver, deck, party, enemies, first, ctx, pinned,
		"tinker_scatter_bolts_plus", 0, "first attempt not held")
	_button_reject(resolver, deck, party, enemies, first, ctx, pinned,
		"tinker_scatter_bolts", 2, "area cannot select an explicit enemy")
	_check(not resolver._patches.latch_snapshot().get("tinker", false) and not first._consumed,
		"all precommit failures leave both first attack powers ready")
	# First cast consumes Button Eye, foreign Pinned, and Tinker +3 independently.
	var first_play: Dictionary = resolver.play_attack(deck, party, enemies,
		"tinker_scatter_bolts")
	_check(first_play.get("ok", false) and first_play["hits"].size() == 3
		and first_play["hits"][0]["position"] == 1
		and first_play["hits"][0]["damage"] == 11
		and first_play["hits"][0]["statuses"] == {"exposed": 1}
		and enemies.get_enemy(1)["statuses"] == {"exposed": 1}
		and pinned.pinner_for_enemy(1).is_empty()
		and resolver._patches.latch_snapshot().get("tinker", false) and first._consumed,
		"successful Scatter consumes both independent latches and foreign Pinned")
	var second: Dictionary = resolver.play_attack(deck, party, enemies,
		"tinker_rivet_shot_plus", 1)
	_check(second == {"ok": true, "hits": [
		{"position": 1, "damage": 9, "block_absorbed": 0, "hp_loss": 9,
			"statuses": {"exposed": 1}}]}
		and enemies.get_enemy(1)["statuses"] == {"exposed": 2}
		and deck.energy == 1 and deck.discard_pile == [
			"tinker_scatter_bolts", "tinker_rivet_shot_plus"],
		"second held attack applies only authored Rivet status, with neither first bonus")
	_check(deck.end_turn(), "turn boundary ends shared deck turn")
	first.start_player_turn()
	_check(deck.start_turn() and deck.hand.has("tinker_long_barrel"),
		"next player turn genuinely redraws the held legal third Tinker card")
	# Remainder of same combat: first-per-turn +3 returns but Button Eye cannot.
	var third: Dictionary = resolver.play_attack(deck, party, enemies,
		"tinker_long_barrel", 2)
	_check(third.get("ok", false) and third["hits"][0]["damage"] == 15
		and third["hits"][0]["statuses"] == {}
		and enemies.get_enemy(2).get("statuses", {}) == {}
		and resolver._patches.latch_snapshot().get("tinker", false)
		and deck.energy == 1,
		"new turn refreshes Tinker +3, never same-combat Button Eye")

	# Invalid contexts with a bound and still-unspent patch cannot change state.
	for reason in ["wrong_slot", "insufficient_energy", "unheld",
			"slain_target", "downed_wearer"]:
		party = _party()
		ctx = _button_context(party)
		first = CombatTinkerFirstAttack.new()
		pinned = CombatPinned.new()
		resolver = CombatTinkerPoolAttacks.new(first, pinned)
		_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn),
			reason + " valid projection before negative case")
		deck = _deck(["tinker_bobbin_cannon", "tinker_rivet_shot"])
		enemies = _enemies([50, 50, 50])
		_check(pinned.pin_enemy(enemies, 1, "warden"),
			reason + " precondition sets actual foreign Pinned")
		var test_id := "tinker_bobbin_cannon"
		var target := 1
		match reason:
			"wrong_slot":
				party = _party(["tinker", "warden", "seamstress"])
				_check(party.get_hero(1)["id"] == "tinker",
					"wrong-slot negative uses genuine current Tinker position")
			"insufficient_energy":
				_check(deck.try_spend_energy(1) and deck.energy == 2,
					"Bobbin energy negative is really unaffordable")
			"unheld":
				test_id = "tinker_bobbin_cannon_plus"
				_check(not deck.hand.has(test_id), "unheld negative lacks exact plus card")
			"slain_target":
				_check(enemies.apply_damage(1, 50) and enemies.is_slain(1),
					"slain-target negative uses actual enemy death")
			"downed_wearer":
				_check(party.apply_damage(3, 26) and party.is_downed(3),
					"downed-wearer negative has actually downed Tinker")
		_button_reject(resolver, deck, party, enemies, first, ctx, pinned,
			test_id, target, reason)

	# A valid foreign or unsown Button Eye never applies to Tinker.
	for mode in ["foreign", "unsown", "torn"]:
		party = _party()
		ctx = _button_context(party, "warden" if mode == "foreign" else "tinker",
			mode != "unsown")
		if mode == "torn":
			var start: Array = ctx.torn.read_state()["heroes"]
			_check(party.apply_damage(3, 26) and party.is_downed(3),
				"torn case actually downs Tinker")
			_check(ctx.torn.observe_battle_end("tear_tinker", start,
				party.get_heroes()).get("ok", false),
				"run torn ledger observes genuinely downed Button Eye wearer")
			var ts_torn: Dictionary = ctx.torn.read_state()
			var w_snap: Dictionary = ctx.wardrobe.get_snapshot()
			_check(ctx.wardrobe.refresh_run_context(ts_torn.heroes, w_snap.owned, w_snap.scraps, w_snap.gold, w_snap.cards, w_snap),
				"wardrobe torn sync")
		first = CombatTinkerFirstAttack.new()
		pinned = CombatPinned.new()
		resolver = CombatTinkerPoolAttacks.new(first, pinned)
		_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn)
			and resolver._patches.exposed_for_first_hit("tinker") == {},
			mode + " projection masks Tinker's patch before any cast")
		deck = _deck(["tinker_long_barrel"])
		enemies = _enemies()
		if mode == "torn":
			_button_reject(resolver, deck, party, enemies, first, ctx, pinned,
				"tinker_long_barrel", 1, "torn-down wearer")
		else:
			var played: Dictionary = resolver.play_attack(deck, party, enemies,
				"tinker_long_barrel", 1)
			_check(played.get("ok", false) and played["hits"][0]["damage"] == 15
				and played["hits"][0]["statuses"] == {}
				and enemies.get_enemy(1).get("statuses", {}) == {}
				and not resolver._patches.latch_snapshot().get("tinker", false),
				mode + " first confirmed attack has no borrowed Exposed effect")


func _test_button_eye_overflow_and_lethal() -> void:
	# Rivet's authored +1 must be combined with Button Eye +1 in preflight.
	for id in ["tinker_rivet_shot", "tinker_rivet_shot_plus",
			"tinker_ricochet", "tinker_scatter_bolts"]:
		var party := _party()
		var ctx := _button_context(party, "tinker", true, true)
		var first := CombatTinkerFirstAttack.new()
		var pinned := CombatPinned.new()
		var resolver := CombatTinkerPoolAttacks.new(first, pinned)
		_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn)
			and resolver._patches.damage_bonus("tinker") == 1,
			id + " double-patch wearer has independent Pincushion +1")
		var foes := _enemies([150, 150, 150])
		var target := 1 if id.begins_with("tinker_rivet") else 0
		if id == "tinker_scatter_bolts":
			_check(foes.apply_damage(1, 150), "overflow Scatter starts with slain original slot 1")
			foes._enemies[1]["statuses"] = {"exposed": CombatEnemies.MAX_INT}
		else:
			foes._enemies[0]["statuses"] = {
				"exposed": CombatEnemies.MAX_INT - (1 if id.begins_with("tinker_rivet") else 0)}
		var deck := _deck([id], 39)
		# Ricochet's first candidate is computed with cloned run RNG, never guessed.
		if id == "tinker_ricochet":
			var oracle: Dictionary = _oracle_random(deck._rng.state, foes.get_enemies(),
				8, {}, 3)
			var first_pos: int = oracle["positions"][0]
			foes._enemies[0].erase("statuses")
			foes._enemies[first_pos - 1]["statuses"] = {"exposed": CombatEnemies.MAX_INT}
		_check(pinned.pin_enemy(foes, 2, "warden"),
			id + " overflow fixture establishes foreign Pinned token")
		_button_reject(resolver, deck, party, foes, first, ctx, pinned,
			id, target, id + " Exposed bound overflow")

	# Button Eye's lethal first hit still attaches Exposed to original slain slot.
	for id in ["tinker_ricochet", "tinker_ricochet_plus"]:
		var party := _party()
		var ctx := _button_context(party)
		var first := CombatTinkerFirstAttack.new()
		var resolver := CombatTinkerPoolAttacks.new(first)
		_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn),
			id + " lethal Button Eye binding")
		var foes := _enemies([1])
		var deck := _deck([id], 774)
		var oracle := _oracle_random(deck._rng.state, foes.get_enemies(),
			int(TinkerPoolCards.new().get_definition(id)["effects"]["damage"]) + 3, {}, 3)
		var actual: Dictionary = resolver.play_attack(deck, party, foes, id)
		_check(actual.get("ok", false) and actual["hits"].size() == 1
			and actual["hits"][0]["position"] == 1
			and actual["hits"][0]["statuses"] == {"exposed": 1}
			and foes.is_victorious() and foes.get_enemy(1)["statuses"] == {"exposed": 1}
			and deck._rng.state == oracle["state"] and resolver._patches.latch_snapshot().get("tinker", false),
			id + " lethal first hit still persists status, consumes once and advances one RNG roll")

	# Both real sewn patches coexist: every hit has +1 raw damage and only
	# the first hit in the combat gets Button Eye status.
	var party := _party()
	var ctx := _button_context(party, "tinker", true, true)
	var first := CombatTinkerFirstAttack.new()
	var pinned := CombatPinned.new()
	var resolver := CombatTinkerPoolAttacks.new(first, pinned)
	_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn)
		and resolver._patches.active_snapshot()["tinker"].has("button_eye")
		and resolver._patches.active_snapshot()["tinker"].has("pincushion_arm"),
		"both HEAD and ARM powers active in same genuine wardrobe")
	var foes := _enemies([120, 120, 120])
	var deck := _deck(["tinker_ricochet_plus"], 39)
	var oracle := _oracle_random(deck._rng.state, foes.get_enemies(), 6 + 3 + 1, {}, 3)
	var play: Dictionary = resolver.play_attack(deck, party, foes, "tinker_ricochet_plus")
	_check(play.get("ok", false) and play["hits"].size() == 3
		and deck._rng.state == oracle["state"] and first._consumed
		and resolver._patches.latch_snapshot().get("tinker", false),
		"combined patches preserve three seeded selections and both latches")
	var first_pos: int = oracle["positions"][0]
	var expected_foes: Array = oracle["roster"].duplicate(true)
	expected_foes[first_pos - 1]["statuses"] = {"exposed": 1}
	for index in range(3):
		_check(play["hits"][index]["position"] == oracle["positions"][index]
			and play["hits"][index]["damage"] == 10
			and play["hits"][index]["statuses"] == ({"exposed": 1} if index == 0 else {}),
			"combined patches Ricochet hit %d keeps +1 raw and post-card status" % index)
	_check(foes.get_enemies() == expected_foes,
		"combined-patch Ricochet final roster is identical to unexposed 3-hit oracle plus one status")


func _visor_context(wearer: String = "tinker",
		sew_visor: bool = true, sew_arm: bool = false) -> Dictionary:
	var raw_m05: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m05_head_patches.json"))
	var raw_m04: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_attack_patches.json"))
	_check(raw_m05 is Array and raw_m04 is Array, "patch catalogs loaded as arrays")
	var definitions: Array = []
	var visor_found := false
	if raw_m05 is Array:
		for entry in raw_m05:
			if entry is Dictionary and entry.has("id") and entry.has("slot"):
				definitions.append({"id": entry["id"], "slot": entry["slot"]})
				if entry["id"] == "button_glass_visor":
					visor_found = true
	if raw_m04 is Array:
		for entry in raw_m04:
			if entry is Dictionary and entry.has("id") and entry.has("slot"):
				definitions.append({"id": entry["id"], "slot": entry["slot"]})
	_check(visor_found, "button_glass_visor defined in M05 head catalog")
	var owned: Array = []
	if sew_visor:
		owned.append("button_glass_visor")
	if sew_arm:
		owned.append("pincushion_arm")
	var starter_heroes: Array = _party().get_heroes()
	var torn := RunTornMending.new(starter_heroes)
	var wardrobe := RunPatchWardrobe.new(starter_heroes, owned, definitions, 3)
	_check(torn.is_valid() and wardrobe.is_valid(), "genuine run ledgers valid for Visor")
	if sew_visor:
		var result: Dictionary = wardrobe.sew("button_glass_visor", wearer, "HEAD",
			"sew_button_glass_visor", wardrobe.get_snapshot())
		_check(result.get("ok", false)
			and wardrobe.get_snapshot()["worn"][wearer]["HEAD"] == "button_glass_visor",
			"Button Glass Visor sewn on actual HEAD slot of " + wearer)
	if sew_arm:
		var result: Dictionary = wardrobe.sew("pincushion_arm", "tinker", "ARM",
			"sew_arm_with_visor", wardrobe.get_snapshot())
		_check(result.get("ok", false)
			and wardrobe.get_snapshot()["worn"]["tinker"]["ARM"] == "pincushion_arm",
			"pincushion_arm sewn on actual ARM slot")
	return {"wardrobe": wardrobe, "torn": torn}


func _visor_snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		first: CombatTinkerFirstAttack, resolver: CombatTinkerPoolAttacks,
		ctx: Dictionary, pinned: CombatPinned) -> Dictionary:
	var result: Dictionary = _snapshot(deck, party, enemies, first)
	if resolver._patches != null:
		result["patch_latches"] = resolver._patches.latch_snapshot()
		result["patch_active"] = resolver._patches.active_snapshot()
	if resolver.get_head_patches() != null:
		result["head_projection"] = resolver.get_head_patches().read_projection()
	result["wardrobe"] = ctx.wardrobe.get_snapshot()
	result["torn"] = ctx.torn.read_state()
	result["pins"] = pinned._pinner_by_position.duplicate(true)
	return result


func _visor_reject(resolver: CombatTinkerPoolAttacks, deck: CombatDeck,
		party: CombatParty, enemies: CombatEnemies, first: CombatTinkerFirstAttack,
		ctx: Dictionary, pinned: CombatPinned, card_id: String, target: int,
		label: String) -> void:
	var before: Dictionary = _visor_snapshot(deck, party, enemies, first,
		resolver, ctx, pinned)
	_check(resolver.play_attack(deck, party, enemies, card_id, target) == _failed_play(),
		label + " rejected in production resolver")
	_check(_visor_snapshot(deck, party, enemies, first, resolver, ctx, pinned) == before,
		label + " rejects atomically (latches, cards, energy, rosters, pins, RNG and ledgers)")


func _test_visor_rivet_shot_variants() -> void:
	# AC1: With a genuine RunPatchWardrobe/RunTornMending pair showing Button Glass Visor sewn
	# on the living Tinker, an actually held and legal Rivet Shot or Rivet Shot+ applies
	# Exposed 2 (authored 1 + HEAD 1) to its chosen enemy after the hit, reports the same
	# amount in its hit receipt, and otherwise keeps authored damage, Tinker's first-attack +3,
	# cost, position, energy and discard.
	for upgrade in [false, true]:
		for tinker_slot in [2, 3]:
			var card_id := "tinker_rivet_shot_plus" if upgrade else "tinker_rivet_shot"
			var base_damage := 6 if upgrade else 4
			var party_order := ["warden", "tinker", "seamstress"] if tinker_slot == 2 else ["warden", "seamstress", "tinker"]
			var party := _party(party_order)
			_check(party.get_hero(tinker_slot)["id"] == "tinker", "Tinker at legal position %d" % tinker_slot)
			
			var ctx := _visor_context("tinker", true, false)
			var first := CombatTinkerFirstAttack.new()
			var pinned := CombatPinned.new()
			var resolver := CombatTinkerPoolAttacks.new(first, pinned)
			_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn), card_id + " visor bound successfully")
			_check(resolver.get_head_patches() != null and resolver.get_head_patches().read_projection().get("ok", false),
				card_id + " head projection is valid")
			_check(resolver.get_head_patches().get_bonus("tinker", card_id, "exposed") == 1,
				card_id + " head bonus is exactly 1")

			# Target enemy 1 has 2 block and 50 HP.
			var enemies := _enemies([50, 50, 50])
			_check(enemies.gain_block(1, 2), "enemy 1 gains 2 block")
			
			var deck := _deck([card_id, "warden_strike"], 774)
			var rng_before: int = deck._rng.state
			var energy_before: int = deck.energy

			var play: Dictionary = resolver.play_attack(deck, party, enemies, card_id, 1)
			_check(play.get("ok", false), card_id + " play succeeds")
			_check(play.get("hits", []).size() == 1, card_id + " exactly one hit")
			
			var hit: Dictionary = play["hits"][0]
			_check(hit["position"] == 1, card_id + " hit position is target enemy 1")
			var expected_damage: int = base_damage + 3 # first attack bonus +3
			_check(hit["damage"] == expected_damage, card_id + " hit damage %d matches base %d + first-attack 3" % [hit["damage"], base_damage])
			_check(hit["block_absorbed"] == 2, card_id + " block absorbed 2")
			_check(hit["hp_loss"] == expected_damage - 2, card_id + " hp loss matches damage minus block")
			_check(hit["statuses"] == {"exposed": 2}, card_id + " hit receipt reports Exposed 2")

			# Assert target enemy status AFTER damage has Exposed 2
			_check(enemies.get_enemy(1).get("statuses", {}) == {"exposed": 2}, card_id + " enemy 1 has Exposed 2 after hit")
			_check(enemies.get_enemy(1)["hp"] == 50 - (expected_damage - 2), card_id + " enemy 1 hp correctly decremented")
			_check(enemies.get_enemy(1)["block"] == 0, card_id + " enemy 1 block absorbed")

			# Assert energy, discard, first-attack consumed, and NO extra RNG
			_check(deck.energy == energy_before - 1, card_id + " energy deducted by cost 1")
			_check(deck.discard_pile == [card_id], card_id + " card moved to discard once")
			_check(not deck.hand.has(card_id), card_id + " card removed from hand")
			_check(first._consumed, card_id + " first-attack latch consumed")
			_check(deck._rng.state == rng_before, card_id + " non-random attack draws no RNG")

	# Second attack in same turn: first-attack +3 is consumed, but Visor Exposed 2 continues!
	var party2 := _party(["warden", "tinker", "seamstress"])
	var ctx2 := _visor_context("tinker", true, false)
	var first2 := CombatTinkerFirstAttack.new()
	var resolver2 := CombatTinkerPoolAttacks.new(first2)
	_check(resolver2.bind_patch_wardrobe(ctx2.wardrobe, ctx2.torn), "two-attack visor bind")
	var deck2 := _deck(["tinker_rivet_shot", "tinker_rivet_shot_plus"])
	var enemies2 := _enemies([100, 100, 100])
	
	var play1: Dictionary = resolver2.play_attack(deck2, party2, enemies2, "tinker_rivet_shot", 1)
	_check(play1["ok"] and play1["hits"][0]["damage"] == 7 and play1["hits"][0]["statuses"] == {"exposed": 2},
		"first attack gets +3 damage and applies Exposed 2")
	_check(enemies2.get_enemy(1).get("statuses", {}) == {"exposed": 2}, "enemy 1 has Exposed 2")
	_check(enemies2.get_enemy(1)["hp"] == 93, "enemy 1 hp is 100 - 7 = 93")

	# Second attack against same enemy: enemy already has Exposed 2 (+50% damage!).
	# Rivet Shot+ deals 6 raw damage. Since enemy is Exposed, 6 * 1.5 = 9 damage!
	# (first-attack bonus is consumed: 0 bonus).
	# And Rivet Shot+ applies another Exposed 2 (enemy now has Exposed 4).
	var play2: Dictionary = resolver2.play_attack(deck2, party2, enemies2, "tinker_rivet_shot_plus", 1)
	_check(play2["ok"], "second attack succeeds")
	_check(play2["hits"][0]["damage"] == 9, "second attack deals 9 damage (6 raw + 50% from preexisting Exposed)")
	_check(play2["hits"][0]["statuses"] == {"exposed": 2}, "second attack hit receipt reports Exposed 2")
	_check(enemies2.get_enemy(1).get("statuses", {}) == {"exposed": 4}, "enemy 1 has cumulative Exposed 4")
	_check(enemies2.get_enemy(1)["hp"] == 84, "enemy 1 hp is 93 - 9 = 84")
	_check(deck2.energy == 1, "two energy spent total")
	_check(deck2.discard_pile == ["tinker_rivet_shot", "tinker_rivet_shot_plus"], "both cards discarded")


func _test_visor_other_five_families_and_alternate_wearers() -> void:
	# AC2: With no visor, a different wearer, or one of the other five Tinker direct-fire
	# families (base or +), the HEAD Exposed increment is zero. Existing M04 Button Eye/Pincushion,
	# Pinned, seeded Ricochet, area-hit and Tinker-first-attack behavior stays unchanged.
	var non_rivet_rows := [
		{"base": "tinker_spring_trap", "damage": [3, 4], "cost": 1, "from": [2, 3], "kind": "enemy_single"},
		{"base": "tinker_scatter_bolts", "damage": [3, 4], "cost": 1, "from": [3], "kind": "enemy_all"},
		{"base": "tinker_long_barrel", "damage": [12, 16], "cost": 2, "from": [3], "kind": "enemy_single"},
		{"base": "tinker_ricochet", "damage": [4, 6], "cost": 1, "from": [2, 3], "kind": "enemy_random"},
		{"base": "tinker_bobbin_cannon", "damage": [20, 26], "cost": 3, "from": [3], "kind": "enemy_single"}
	]
	for row in non_rivet_rows:
		for upgrade in [false, true]:
			var id: String = row["base"] + ("_plus" if upgrade else "")
			var raw_dmg: int = row["damage"][1 if upgrade else 0]
			var party := _party(["warden", "seamstress", "tinker"])
			var ctx := _visor_context("tinker", true, false)
			var first := CombatTinkerFirstAttack.new()
			var pinned := CombatPinned.new()
			var resolver := CombatTinkerPoolAttacks.new(first, pinned)
			_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn), id + " visor bound")
			_check(resolver.get_head_patches().get_bonus("tinker", id, "exposed") == 0,
				id + " non-rivet direct-fire card gains zero HEAD exposed bonus")

			var enemies := _enemies([80, 80, 80])
			var deck := _deck([id], 39)
			var before_rng: int = deck._rng.state
			var target: int = 1 if row["kind"] == "enemy_single" else 0
			var play: Dictionary = resolver.play_attack(deck, party, enemies, id, target)
			_check(play.get("ok", false), id + " played with visor sewn")
			
			for hit in play.get("hits", []):
				_check(hit.get("statuses", {}) == {}, id + " hit has no exposed status")
			for enemy in enemies.get_enemies():
				_check(enemy.get("statuses", {}).get("exposed", 0) == 0, id + " enemy has no exposed")

			if row["base"] == "tinker_spring_trap":
				_check(pinned.pinner_for_enemy(1) == "tinker", id + " Spring Trap sets pin")
			elif row["base"] == "tinker_scatter_bolts":
				_check(play["hits"].size() == 3, id + " hits all 3 enemies")
			elif row["base"] == "tinker_ricochet":
				_check(play["hits"].size() == 3, id + " hits 3 random targets")

	# Visor sewn to another living hero (Warden): Tinker Rivet Shot retains authored Exposed 1
	for upgrade in [false, true]:
		var id: String = "tinker_rivet_shot" + ("_plus" if upgrade else "")
		var party := _party(["warden", "tinker", "seamstress"])
		var ctx := _visor_context("warden", true, false)
		var first := CombatTinkerFirstAttack.new()
		var resolver := CombatTinkerPoolAttacks.new(first)
		_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn), id + " foreign visor bind")
		_check(resolver.get_head_patches().get_bonus("tinker", id, "exposed") == 0,
			id + " foreign visor grants 0 bonus to Tinker")
		var enemies := _enemies([50, 50, 50])
		var deck := _deck([id])
		var play: Dictionary = resolver.play_attack(deck, party, enemies, id, 1)
		_check(play.get("ok", false) and play["hits"][0]["statuses"] == {"exposed": 1},
			id + " foreign visor Rivet retains authored Exposed 1")
		_check(enemies.get_enemy(1).get("statuses", {}) == {"exposed": 1},
			id + " foreign visor target has authored Exposed 1")

	# Ordinary unbound resolver: Rivet retains authored Exposed 1
	for upgrade in [false, true]:
		var id: String = "tinker_rivet_shot" + ("_plus" if upgrade else "")
		var party := _party(["warden", "tinker", "seamstress"])
		var first := CombatTinkerFirstAttack.new()
		var resolver := CombatTinkerPoolAttacks.new(first)
		_check(resolver.get_head_patches() == null, id + " unbound resolver has null head patches")
		var enemies := _enemies([50, 50, 50])
		var deck := _deck([id])
		var play: Dictionary = resolver.play_attack(deck, party, enemies, id, 1)
		_check(play.get("ok", false) and play["hits"][0]["statuses"] == {"exposed": 1},
			id + " unbound Rivet retains authored Exposed 1")
		_check(enemies.get_enemy(1).get("statuses", {}) == {"exposed": 1},
			id + " unbound target has authored Exposed 1")

	# Co-wearing Button Glass Visor (HEAD) and Pincushion Arm (ARM)
	var party_co := _party(["warden", "tinker", "seamstress"])
	var ctx_co := _visor_context("tinker", true, true)
	var first_co := CombatTinkerFirstAttack.new()
	var pinned_co := CombatPinned.new()
	var resolver_co := CombatTinkerPoolAttacks.new(first_co, pinned_co)
	_check(resolver_co.bind_patch_wardrobe(ctx_co.wardrobe, ctx_co.torn), "co-worn bind")
	_check(resolver_co._patches.damage_bonus("tinker") == 1, "Pincushion provides +1 damage bonus")
	_check(resolver_co.get_head_patches().get_bonus("tinker", "tinker_rivet_shot", "exposed") == 1,
		"Visor provides +1 exposed bonus")
	var foes_co := _enemies([50, 50, 50])
	var deck_co := _deck(["tinker_rivet_shot", "tinker_spring_trap"])
	# Rivet Shot: 4 base + 3 first + 1 pincushion = 8 damage, Exposed 2
	var play_rivet: Dictionary = resolver_co.play_attack(deck_co, party_co, foes_co, "tinker_rivet_shot", 1)
	_check(play_rivet.get("ok", false) and play_rivet["hits"][0]["damage"] == 8
		and play_rivet["hits"][0]["statuses"] == {"exposed": 2},
		"co-worn Rivet gets +1 damage and Exposed 2")
	# Spring Trap: 3 base + 0 first + 1 pincushion = 4 damage, Exposed 0
	var play_trap: Dictionary = resolver_co.play_attack(deck_co, party_co, foes_co, "tinker_spring_trap", 2)
	_check(play_trap.get("ok", false) and play_trap["hits"][0]["damage"] == 4
		and play_trap["hits"][0]["statuses"] == {},
		"co-worn Spring Trap gets +1 damage and no exposed")

	# Foreign Pinned with Visor sewn: +5 before weak/exposed, consumed on hit
	var party_pin := _party(["warden", "tinker", "seamstress"])
	var ctx_pin := _visor_context("tinker", true, false)
	var first_pin := CombatTinkerFirstAttack.new()
	var pinned_pin := CombatPinned.new()
	var resolver_pin := CombatTinkerPoolAttacks.new(first_pin, pinned_pin)
	_check(resolver_pin.bind_patch_wardrobe(ctx_pin.wardrobe, ctx_pin.torn), "pin visor bind")
	var foes_pin := _enemies([50, 50, 50])
	_check(pinned_pin.pin_enemy(foes_pin, 1, "warden"), "warden pins enemy 1")
	var deck_pin := _deck(["tinker_rivet_shot"])
	# 4 base + 3 first + 5 foreign pin = 12 damage, Exposed 2
	var play_pin: Dictionary = resolver_pin.play_attack(deck_pin, party_pin, foes_pin, "tinker_rivet_shot", 1)
	_check(play_pin.get("ok", false) and play_pin["hits"][0]["damage"] == 12
		and play_pin["hits"][0]["statuses"] == {"exposed": 2},
		"pinned Rivet gets +5 damage and Exposed 2")
	_check(pinned_pin.pinner_for_enemy(1).is_empty(), "pinned token consumed on hit")


func _test_visor_stale_failed_and_torn_rejections() -> void:
	# AC3: An explicitly failed, stale or torn run HEAD binding cannot be treated as
	# an unpatched valid cast; refusal leaves hand, energy, discard, enemy HP/Block/statuses,
	# first-attack latch, patch ledgers and RNG unchanged. Unbound ordinary play remains authored vanilla.

	# 1. Stale binding via Rest/re-sew
	var party := _party(["warden", "tinker", "seamstress"])
	var ctx := _visor_context("tinker", true, false)
	var first := CombatTinkerFirstAttack.new()
	var pinned := CombatPinned.new()
	var resolver := CombatTinkerPoolAttacks.new(first, pinned)
	_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn), "stale resew bind")
	# Perform real Rest/re-sew moving visor from Tinker to Warden
	_check(ctx.wardrobe.start_rest("rest_1", ctx.wardrobe.get_snapshot()).get("ok", false), "start rest")
	var resew_res: Dictionary = ctx.wardrobe.re_sew("button_glass_visor", "tinker", "warden",
		"rest_1", "resew_to_warden", ctx.wardrobe.get_snapshot())
	_check(resew_res.get("ok", false), "real rest resew succeeds")
	_check(ctx.wardrobe.end_rest("rest_1", ctx.wardrobe.get_snapshot()).get("ok", false), "end rest")
	var deck := _deck(["tinker_rivet_shot"])
	var foes := _enemies([50, 50, 50])
	_visor_reject(resolver, deck, party, foes, first, ctx, pinned,
		"tinker_rivet_shot", 1, "stale resew wardrobe")

	# 2. Stale binding via tear
	party = _party(["warden", "tinker", "seamstress"])
	ctx = _visor_context("tinker", true, false)
	first = CombatTinkerFirstAttack.new()
	pinned = CombatPinned.new()
	resolver = CombatTinkerPoolAttacks.new(first, pinned)
	_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn), "stale tear bind")
	var start_roster: Array = ctx.torn.read_state()["heroes"]
	_check(party.apply_damage(1, 999) and party.is_downed(1), "down warden in party")
	_check(ctx.torn.observe_battle_end("tear_warden", start_roster, party.get_heroes())["ok"],
		"torn ledger records battle end tear")
	deck = _deck(["tinker_rivet_shot"])
	foes = _enemies([50, 50, 50])
	_visor_reject(resolver, deck, party, foes, first, ctx, pinned,
		"tinker_rivet_shot", 1, "stale tear ledger")

	# 3. Explicit failed binding
	party = _party(["warden", "tinker", "seamstress"])
	ctx = _visor_context("tinker", true, false)
	first = CombatTinkerFirstAttack.new()
	pinned = CombatPinned.new()
	resolver = CombatTinkerPoolAttacks.new(first, pinned)
	_check(not resolver.bind_patch_wardrobe(null, ctx.torn), "bind null wardrobe fails")
	_check(resolver.get_head_patches() != null and not resolver.get_head_patches().read_projection().get("ok", false),
		"head patches invalid after failed bind")
	deck = _deck(["tinker_rivet_shot"])
	foes = _enemies([50, 50, 50])
	_visor_reject(resolver, deck, party, foes, first, ctx, pinned,
		"tinker_rivet_shot", 1, "explicit null bind")

	# 4. Torn Tinker wearer at bind time
	party = _party()
	ctx = _visor_context("tinker", true, false)
	var start_h: Array = ctx.torn.read_state()["heroes"]
	_check(party.apply_damage(3, 26) and party.is_downed(3), "down tinker in combat")
	_check(ctx.torn.observe_battle_end("tear_tinker", start_h, party.get_heroes())["ok"],
		"record torn tinker")
	var ts_torn: Dictionary = ctx.torn.read_state()
	var w_snap: Dictionary = ctx.wardrobe.get_snapshot()
	_check(ctx.wardrobe.refresh_run_context(ts_torn.heroes, w_snap.owned, w_snap.scraps, w_snap.gold, w_snap.cards, w_snap),
		"sync wardrobe for torn tinker")
	first = CombatTinkerFirstAttack.new()
	pinned = CombatPinned.new()
	resolver = CombatTinkerPoolAttacks.new(first, pinned)
	_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn), "bind succeeds with torn tinker")
	deck = _deck(["tinker_rivet_shot"])
	foes = _enemies([50, 50, 50])
	_visor_reject(resolver, deck, party, foes, first, ctx, pinned,
		"tinker_rivet_shot", 1, "torn tinker wearer")

	# Divergent party test (Lesson 39): party has living Tinker, but torn ledger has Tinker torn
	var fresh_party := _party(["warden", "tinker", "seamstress"])
	_check(not fresh_party.is_downed(2), "fresh party has living Tinker")
	var fresh_deck := _deck(["tinker_rivet_shot"])
	var fresh_foes := _enemies([50, 50, 50])
	_visor_reject(resolver, fresh_deck, fresh_party, fresh_foes, first, ctx, pinned,
		"tinker_rivet_shot", 1, "divergent party with torn ledger tinker")

	# 5. Status capacity overflow refusal
	party = _party(["warden", "tinker", "seamstress"])
	ctx = _visor_context("tinker", true, false)
	first = CombatTinkerFirstAttack.new()
	pinned = CombatPinned.new()
	resolver = CombatTinkerPoolAttacks.new(first, pinned)
	_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn), "overflow bind")
	foes = _enemies([100, 100, 100])
	# Set enemy 1 Exposed to MAX_INT - 1 (adding 2 would overflow MAX_INT)
	foes._enemies[0]["statuses"] = {"exposed": CombatEnemies.MAX_INT - 1}
	deck = _deck(["tinker_rivet_shot"])
	_visor_reject(resolver, deck, party, foes, first, ctx, pinned,
		"tinker_rivet_shot", 1, "Exposed status capacity overflow")

	# 6. Recovery with fresh valid rebind
	party = _party(["warden", "tinker", "seamstress"])
	ctx = _visor_context("tinker", true, false)
	_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn), "recovery rebind")
	foes = _enemies([50, 50, 50])
	deck = _deck(["tinker_rivet_shot"])
	var play_recovered: Dictionary = resolver.play_attack(deck, party, foes, "tinker_rivet_shot", 1)
	_check(play_recovered.get("ok", false) and play_recovered["hits"][0]["statuses"] == {"exposed": 2},
		"recovered resolver plays Rivet with Exposed 2")
