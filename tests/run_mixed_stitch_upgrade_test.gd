extends SceneTree
## Cross-service M04 regression: earned stitched Rest ledger -> ordinary Rest
## upgrade -> durable next allocator -> real seeded CombatDeck/AttackCards.
## No scene or app wiring is exercised (that owner is reserved).

const STRIKE := "warden_strike"
const PLUS := "warden_strike_plus"
const PRICK := "seamstress_prick"
const POP := "tinker_pop_shot"
const SEED_VALUE := 826071
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	var first := _end_to_end(1)
	var replay := _end_to_end(1)
	_check(not first.is_empty() and first == replay,
		"same seed, authentic stitch and upgrade replay identical ledger and full combat transition")
	var warden_middle := _end_to_end(2)
	_check(not warden_middle.is_empty(), "Warden in authored position 2 can play earned Strike+")
	if failures.is_empty():
		print("run_mixed_stitch_upgrade_test: PASS (", checks, " checks)")
	else:
		for error in failures:
			printerr(error)
		print("run_mixed_stitch_upgrade_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _array_from_json(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "real JSON resource exists " + path)
	if file == null:
		return []
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	_check(data is Array and not data.is_empty(), "real JSON resource yields nonempty array " + path)
	return data if data is Array else []


func _ids() -> Array[String]:
	var data := _array_from_json("res://data/cards/starter_deck.json")
	var deck: Array[String] = []
	for entry in data:
		_check(entry is String, "authored starter deck contains String IDs")
		if entry is String:
			deck.append(entry)
	return deck


func _actors(path: String, wanted: int) -> Array:
	var definitions := _array_from_json(path)
	_check(definitions.size() >= wanted, "authored roster contains requested actors")
	if definitions.size() < wanted:
		return []
	var result := definitions.slice(0, wanted).duplicate(true)
	for item in result:
		if item is Dictionary:
			var health: Variant = item.get("max_hp")
			if health is float:
				_check(health == floor(health), "authored maximum HP is integral")
				item["max_hp"] = int(health)
	return result


func _party(position: int) -> CombatParty:
	var defs := _actors("res://data/heroes/starter_party.json", 3)
	if position == 2 and defs.size() == 3:
		var swap: Variant = defs[0]
		defs[0] = defs[1]
		defs[1] = swap
	elif position == 3 and defs.size() == 3:
		defs.append(defs.pop_front())
	var party := CombatParty.new(defs)
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"three real heroes form an authoritative CombatParty")
	_check(party.get_hero(position).get("id") == "warden"
		and party.get_hero(position).get("max_hp") == 40
		and party.get_hero(position).get("hp") == 40,
		"living authored Warden occupies legal attacking position")
	return party


func _enemies() -> CombatEnemies:
	var defs := _actors("res://data/enemies/run_enemies.json", 2)
	var enemies := CombatEnemies.new(defs)
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2,
		"two real authored enemies occupy positions one and two")
	_check(enemies.get_enemy(1).get("id") == "fray_scavenger"
		and enemies.get_enemy(2).get("id") == "button_guard"
		and enemies.get_enemy(2).get("hp") == 16,
		"unchanged authored target has sufficient HP for seven-damage hit")
	return enemies


func _state(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies) -> Dictionary:
	return {
		"draw": deck.draw_pile.duplicate(true),
		"hand": deck.hand.duplicate(true),
		"discard": deck.discard_pile.duplicate(true),
		"energy": deck.energy,
		"turn": deck.turn_active,
		"state_energy": deck.combat_state.energy,
		"state_turn": deck.combat_state.player_turn_active,
		"seed": deck._rng.seed,
		"rng_state": deck._rng.state,
		"party": party.get_heroes(),
		"enemies": enemies.get_enemies(),
		"victory": enemies.is_victorious()
	}


func _reject_attack(attack: CombatAttackCards, deck: CombatDeck, party: CombatParty,
		enemies: CombatEnemies, target: int, label: String) -> void:
	var before := _state(deck, party, enemies)
	_check(attack.play_attack(deck, party, enemies, PLUS, target) == {"ok": false, "hits": []},
		label + " fails closed")
	_check(_state(deck, party, enemies) == before,
		label + " leaves every deck pile, energy, RNG, party and target unchanged")


func _end_to_end(warden_position: int) -> Dictionary:
	var original := _ids()
	var catalog := StarterCards.new()
	var first_prick := original.find(PRICK)
	var first_pop := original.find(POP)
	_check(first_prick >= 0 and first_pop >= 0 and first_prick != first_pop
		and original.count(STRIKE) == 2 and original.count(PRICK) >= 2
		and original.count(POP) >= 2, "real starter deck contains two distinct-owner halves and two Strikes")
	if first_prick < 0 or first_pop < 0 or original.count(STRIKE) < 2:
		return {}
	_check(catalog.get_definition(PRICK).get("owner") == "seamstress"
		and catalog.get_definition(POP).get("owner") == "tinker"
		and catalog.get_definition(PLUS).get("effects") == {"damage": 7}
		and catalog.get_definition(PLUS).get("cost") == 1,
		"only authored cross-owner halves and Strike+ definition used")
	var original_copy := original.duplicate()
	var seeded := RandomNumberGenerator.new()
	seeded.seed = SEED_VALUE
	var initial_rng_state := seeded.state
	seed(SEED_VALUE)
	var expected_global := randi()
	seed(SEED_VALUE)
	var rest := RunRestStitchCards.new(original, {}, 3)
	_check(rest.is_valid() and not rest.is_consumed(), "3-scrap Rest stitches real plain deck")
	var before_stitch := rest.get_snapshot()
	var made := rest.choose_stitch(first_prick, first_pop, before_stitch)
	_check(made.get("ok") == true and rest.is_consumed(), "first real Rest commits a single composite")
	if not made.get("ok", false):
		return {}
	var id: String = made["stitched_id"]
	var descriptor: Dictionary = made["descriptors"][id].duplicate(true)
	var saved_json := JSON.stringify(descriptor)
	_check(id == "stitched_000001" and made["next_stitch_id"] == 2
		and made["remaining_scraps"] == 0 and made["deck"].size() == original.size() - 1,
		"first composite is unique, costs exactly three scraps and replaces two with one")
	_check(made["deck"].count(PRICK) == original.count(PRICK) - 1
		and made["deck"].count(POP) == original.count(POP) - 1
		and made["deck"].count(id) == 1,
		"half cards do not leak back into the mixed deck")
	var expected_stitched := original.duplicate()
	expected_stitched.remove_at(maxi(first_prick, first_pop))
	expected_stitched.remove_at(mini(first_prick, first_pop))
	expected_stitched.insert(mini(first_prick, first_pop), id)
	_check(made["deck"] == expected_stitched and original == original_copy,
		"first Rest preserves all survivor indices and untouched caller deck")
	_check(descriptor["half_ids"] == [PRICK, POP]
		and descriptor["owners"] == ["seamstress", "tinker"]
		and descriptor["first_half"] == catalog.get_definition(PRICK)
		and descriptor["second_half"] == catalog.get_definition(POP)
		and descriptor["cost"] == 2 and not descriptor["can_upgrade"] and not descriptor["can_stitch"],
		"canonical ordered halves, capped cost and permanent prohibition survive serialization")
	var strike_index: int = made["deck"].find(STRIKE)
	var composite_index: int = made["deck"].find(id)
	_check(strike_index >= 0 and composite_index >= 0 and made["deck"].count(STRIKE) == 2,
		"real mixed ledger retains both upgrade-eligible Strike copies")
	if strike_index < 0 or composite_index < 0:
		return {}
	var next_rest := RunRestCardUpgrade.new(made["deck"],
		{STRIKE: PLUS, id: "forged_stitched_plus"}, made["descriptors"], made["next_stitch_id"])
	var rejected := next_rest.choose_upgrade(composite_index)
	_check(rejected.get("ok") == false and rejected.get("deck") == made["deck"]
		and not next_rest.is_consumed(),
		"hostile attempt to upgrade composite leaves next Rest choice available")
	var upgraded := next_rest.choose_upgrade(strike_index)
	_check(upgraded.get("ok") == true and next_rest.is_consumed()
		and upgraded.get("original_id") == STRIKE and upgraded.get("upgraded_id") == PLUS,
		"one normal Strike becomes authored Strike+ after real stitch")
	if not upgraded.get("ok", false):
		return {}
	var expected: Array = made["deck"].duplicate()
	expected[strike_index] = PLUS
	_check(upgraded["deck"] == expected and upgraded["deck"].count(STRIKE) == 1
		and upgraded["deck"].count(PLUS) == 1 and upgraded["deck"].count(id) == 1,
		"exactly one original index changed, leaving the other Strike and composite untouched")
	_check(made["descriptors"][id] == descriptor and JSON.stringify(made["descriptors"][id]) == saved_json
		and made["next_stitch_id"] == 2 and made["remaining_scraps"] == 0
		and seeded.state == initial_rng_state and randi() == expected_global,
		"upgrade neither mutates descriptor/currency/cursor nor draws global/run RNG")
	var future_rest := RunRestStitchCards.new(upgraded["deck"], made["descriptors"], 3, made["next_stitch_id"])
	_check(future_rest.is_valid(), "independently funded future Rest reloads stitched+upgraded mixed ledger")
	var before_future := future_rest.get_snapshot()
	_check(before_future["descriptors"][id] == descriptor and before_future["next_stitch_id"] == 2,
		"future Rest loads identical descriptor and monotonic allocator")
	var next_pair := future_rest.choose_stitch(upgraded["deck"].find(PRICK),
		upgraded["deck"].find(POP), before_future)
	_check(next_pair.get("ok") == true and next_pair.get("stitched_id") == "stitched_000002"
		and next_pair.get("remaining_scraps") == 0 and next_pair.get("next_stitch_id") == 3,
		"second authentic cross-owner visit allocates the next unused stitched ID")
	_check(next_pair.get("descriptors", {}).get(id) == descriptor
		and next_pair.get("deck", []).count(id) == 1 and next_pair.get("deck", []).count("stitched_000002") == 1,
		"second craft leaves original stitched card and descriptor untouched")
	# A new battle uses the upgraded output (NOT the independently stitched
	# future-visit result), and the exact run-owned seeded CombatDeck.
	var combat_rng := RandomNumberGenerator.new()
	combat_rng.seed = SEED_VALUE
	var card_ids: Array[String] = []
	card_ids.assign(upgraded["deck"])
	var combat_deck := CombatDeck.new(card_ids, combat_rng)
	var party := _party(warden_position)
	var enemies := _enemies()
	var attack := CombatAttackCards.new()
	_check(combat_deck.start_turn() and combat_deck.hand.size() == 5
		and combat_deck.energy == 3, "real seeded battle draws five cards with three energy")
	var draw_guard := 0
	while not combat_deck.hand.has(PLUS) and not combat_deck.draw_pile.is_empty() and draw_guard < card_ids.size():
		_check(combat_deck.draw_extra(1) == 1, "real draw service moves a card into hand")
		draw_guard += 1
	_check(combat_deck.hand.has(PLUS), "the one genuine Strike+ is held after real seeded draws")
	if not combat_deck.hand.has(PLUS):
		return {}
	var accounted := combat_deck.draw_pile.duplicate()
	accounted.append_array(combat_deck.hand)
	accounted.append_array(combat_deck.discard_pile)
	accounted.sort()
	var expected_cards := card_ids.duplicate()
	expected_cards.sort()
	_check(accounted == expected_cards and accounted.count(id) == 1
		and accounted.count(PLUS) == 1 and accounted.count(PRICK) == 1 and accounted.count(POP) == 1,
		"all mixed cards and halves are accounted for in real battle piles")
	_reject_attack(attack, combat_deck, party, enemies, 0, "missing selected enemy target")
	_reject_attack(attack, combat_deck, party, enemies, 3, "illegal enemy position three")
	var displaced := _party(3)
	var hostile_roster := displaced.get_heroes()
	_check(hostile_roster[2]["id"] == "warden" and hostile_roster[2]["position"] == 3,
		"valid three-hero roster places living Warden in forbidden back slot")
	_reject_attack(attack, combat_deck, displaced, enemies, 1, "illegal Warden owner position")
	var before := _state(combat_deck, party, enemies)
	var outcome := attack.play_attack(combat_deck, party, enemies, PLUS, 2)
	_check(outcome == {"ok": true, "hits": [{"position": 2, "damage": 7,
		"block_absorbed": 0, "hp_loss": 7, "statuses": {}}]},
		"authored Strike+ hits enemy slot two for precisely seven damage")
	var after := _state(combat_deck, party, enemies)
	var expected_after := before.duplicate(true)
	expected_after["energy"] = 2
	expected_after["state_energy"] = 2
	expected_after["hand"].remove_at(expected_after["hand"].find(PLUS))
	expected_after["discard"].append(PLUS)
	expected_after["enemies"][1]["hp"] -= 7
	_check(after == expected_after, "exact combat transition changes only enemy HP, energy and one hand-to-discard copy")
	_check(combat_deck.discard_pile.count(PLUS) == 1 and not combat_deck.hand.has(PLUS)
		and enemies.get_enemy(2)["hp"] == 9 and enemies.get_enemy(1)["hp"] == before["enemies"][0]["hp"],
		"one committed discard and untouched other enemy")
	_reject_attack(attack, combat_deck, party, enemies, 2, "played Strike+ absent from hand")
	var no_energy_rng := RandomNumberGenerator.new()
	no_energy_rng.seed = SEED_VALUE
	var no_energy := CombatDeck.new(card_ids, no_energy_rng)
	_check(no_energy.start_turn(), "fresh combat deck starts for insufficient-energy negative")
	var tries := 0
	while not no_energy.hand.has(PLUS) and not no_energy.draw_pile.is_empty() and tries < card_ids.size():
		no_energy.draw_extra(1)
		tries += 1
	_check(no_energy.hand.has(PLUS) and no_energy.try_spend_energy(3)
		and no_energy.energy == 0, "zero-energy rejection starts with a truly held attack")
	_reject_attack(CombatAttackCards.new(), no_energy, _party(warden_position),
		_enemies(), 1, "real energy exhausted")
	return {
		"original": original_copy, "stitched": made["deck"],
		"descriptor": descriptor, "cursor": made["next_stitch_id"],
		"upgraded": upgraded["deck"], "future": next_pair["deck"],
		"combat_before": before, "combat_after": after, "hit": outcome
	}
