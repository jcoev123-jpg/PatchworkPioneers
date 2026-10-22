extends SceneTree
## Real catalog/deck/party/enemy regression for Tinker's five direct-fire cards.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_catalog_and_ten_variants()
	_test_rivet_order_and_duplicates()
	_test_area_original_positions()
	_test_ricochet_replay()
	_test_shared_first_attack()
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
			var resolver := CombatTinkerPoolAttacks.new(first)
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
				expected_hits.append({"position": position, "damage": hit_damage,
					"block_absorbed": absorbed, "hp_loss": lost, "statuses": statuses})
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
			var a := _ricochet_case(card_id, seed_value)
			var b := _ricochet_case(card_id, seed_value)
			_check(a == b, card_id + " same seeded real roster/actions replay exactly")
			witnessed_early_death = witnessed_early_death or a["early_death"]
	_check(witnessed_early_death, "seeded scenarios include a target slain on hit 1 or 2")
	var first := CombatTinkerFirstAttack.new()
	var deck := _deck(["tinker_ricochet"])
	var party := _party()
	var enemies := _enemies([1])
	_reject(CombatTinkerPoolAttacks.new(first), deck, party, enemies,
		first, "Ricochet cannot promise three living hits after early last kill")


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


func _reject(resolver: CombatTinkerPoolAttacks, deck: CombatDeck,
		party: CombatParty, enemies: CombatEnemies,
		first: CombatTinkerFirstAttack, reason: String,
		id: String = "tinker_ricochet", target: int = 0) -> void:
	var before := _snapshot(deck, party, enemies, first)
	_check(resolver.play_attack(deck, party, enemies, id, target)
		== {"ok": false, "hits": []}, reason + " must reject")
	_check(_snapshot(deck, party, enemies, first) == before,
		reason + " preserves complete deck, hero, enemy, RNG and latch")


func _test_atomic_rejections() -> void:
	var id := "tinker_ricochet"
	var deck := _deck([id, "tinker_scatter_bolts", "tinker_bobbin_cannon",
		"tinker_rivet_shot", "tinker_spring_trap"])
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
		"tinker_spring_trap", 1)
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
