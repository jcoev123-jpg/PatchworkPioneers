extends SceneTree

var failures: Array[String] = []
var checks := 0

const HEROES_PATH := "res://data/heroes/starter_party.json"


func _initialize() -> void:
	_test_paid_both_pairs()
	_test_targeting_after_commits()
	_test_rejections()
	_test_seeded_replay()
	for failure in failures:
		printerr(failure)
	print("combat_positions_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _party() -> CombatParty:
	var contents := FileAccess.get_file_as_string(HEROES_PATH)
	var definitions = JSON.parse_string(contents)
	_check(not contents.is_empty() and definitions is Array and definitions.size() == 3,
		"real starter hero file has three definitions")
	if not definitions is Array or definitions.size() != 3:
		return CombatParty.new([])
	# JSON parses whole numbers to floats; normalize as the real app does.
	for hero in definitions:
		if hero is Dictionary and hero.get("max_hp") is float:
			hero["max_hp"] = int(hero["max_hp"])
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "valid authoritative party from real hero JSON")
	if party.is_valid():
		_check(_ids(party) == ["warden", "seamstress", "tinker"]
			and party.get_hero(1).hp == 40 and party.get_hero(2).hp == 30
			and party.get_hero(3).hp == 26, "real authored opening party and HP")
	return party


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _deck(cards: Array[String], seed_value: int = 4701, start := true) -> CombatDeck:
	var deck := CombatDeck.new(cards, _rng(seed_value))
	_check(deck.draw_pile.size() == cards.size(), "injected deck has all supplied cards")
	if start:
		_check(deck.start_turn() and deck.turn_active and deck.energy == 3,
			"actual player turn starts with 3 energy")
		_check(deck.hand.size() == mini(5, cards.size()), "real draw-up-to-five occurred")
	return deck


func _definition(id: String, owner: String, cost: int, from_positions: Array,
		direction: int) -> Dictionary:
	return {"id": id, "owner": owner, "cost": cost, "from_positions": from_positions,
		"action_kind": "adjacent_swap", "direction": direction}


func _ids(party: CombatParty) -> Array:
	var result: Array = []
	for hero in party.get_heroes():
		result.append(hero.get("id"))
	return result


func _roster(party: CombatParty, expected: Array, label: String) -> void:
	var heroes := party.get_heroes()
	_check(heroes.size() == 3 and _ids(party) == expected, label + ": exact slot IDs")
	var seen: Array = []
	for i in range(heroes.size()):
		var hero: Dictionary = heroes[i]
		_check(hero.get("position") == i + 1, label + ": slot " + str(i + 1) + " position field")
		_check(not seen.has(hero.get("id")) and not String(hero.get("id")).is_empty(),
			label + ": no duplicate or absent hero")
		seen.append(hero.get("id"))
	_check(seen.size() == 3, label + ": exactly three occupants")


func _decorate(party: CombatParty) -> void:
	_check(party.apply_damage(1, 5) and party.apply_damage(2, 6)
		and party.apply_damage(3, 4)
		and party.gain_block(1, 4) and party.gain_block(2, 7)
		and party.gain_block(3, 2), "real CombatParty methods wound and block each actor")
	for i in range(3):
		var hero: Dictionary = party._heroes[i]
		hero["statuses"] = {"bleed": i + 1, "weak": 2 + i, "exposed": 3 + i}
		hero["metadata"] = {"layers": [{"owner": hero["id"], "values": [i, i + 10]}]}
	_check(party.get_hero(1).hp == 35 and party.get_hero(2).hp == 24
		and party.get_hero(3).hp == 22, "non-vacuous distinguishable wounded fixture")


func _snapshot(deck: CombatDeck, party: CombatParty) -> Dictionary:
	var result := {}
	if party != null:
		result["party"] = party.get_heroes()
	if deck != null:
		result["hand"] = deck.hand.duplicate(true)
		result["draw"] = deck.draw_pile.duplicate(true)
		result["discard"] = deck.discard_pile.duplicate(true)
		result["energy"] = deck.energy
		result["turn"] = deck.turn_active
		result["state_energy"] = deck.combat_state.energy
		result["state_turn"] = deck.combat_state.player_turn_active
		result["rng_seed"] = deck._rng.seed
		result["rng_state"] = deck._rng.state
	return result


func _move(deck: CombatDeck, party: CombatParty, definition: Dictionary,
		expected_ids: Array, label: String) -> void:
	var id: String = definition["id"]
	_check(deck.hand.has(id) and deck.turn_active, label + ": card truly held and turn active")
	var refs: Dictionary = {}
	for hero in party._heroes:
		refs[hero["id"]] = hero
	var before := _snapshot(deck, party)
	var expected := before.duplicate(true)
	var expected_hand: Array = expected["hand"]
	var card_index := expected_hand.find(id)
	_check(card_index >= 0, label + ": matching copy really exists")
	if card_index < 0:
		return
	expected_hand.remove_at(card_index)
	var expected_discard: Array = expected["discard"]
	expected_discard.append(id)
	expected["energy"] = before["energy"] - definition["cost"]
	expected["state_energy"] = expected["energy"]
	var expected_heroes: Array = expected["party"]
	var mover_index := 0
	for i in range(3):
		if expected_heroes[i]["id"] == definition["owner"]:
			mover_index = i
	var other_index: int = mover_index + definition["direction"]
	if other_index < 0 or other_index >= 3:
		_check(false, label + ": expected fixture swap was on board")
		return
	var temp = expected_heroes[mover_index]
	expected_heroes[mover_index] = expected_heroes[other_index]
	expected_heroes[other_index] = temp
	expected_heroes[mover_index]["position"] = mover_index + 1
	expected_heroes[other_index]["position"] = other_index + 1

	seed(982451653)
	var expected_global: int = randi()
	seed(982451653)
	_check(CombatPositionSwaps.play_move_card(deck, party, id, definition), label + ": actual move succeeds")
	_check(randi() == expected_global, label + ": global RNG stream unchanged")
	_check(_snapshot(deck, party) == expected, label + ": only exact paid deck and swapped party deltas")
	_roster(party, expected_ids, label)
	for hero in party._heroes:
		_check(is_same(hero, refs[hero["id"]]), label + ": original actor dictionary identity kept for " + hero["id"])
	var authoritative := party.get_heroes()
	var reader := party.get_heroes()
	reader[0]["hp"] = -999
	reader[0]["statuses"]["bleed"] = 888
	reader[0]["metadata"]["layers"][0]["values"].clear()
	_check(party.get_heroes() == authoritative, label + ": nested deep-copy readers cannot change authority")


func _reject(deck: CombatDeck, party: CombatParty, id: Variant,
		definition: Variant, label: String) -> void:
	var before := _snapshot(deck, party)
	seed(2026442)
	var expected_global: int = randi()
	seed(2026442)
	_check(not CombatPositionSwaps.play_move_card(deck, party, id, definition),
		label + ": rejected")
	_check(_snapshot(deck, party) == before, label + ": exact deck, party, energy and injected RNG preserved")
	_check(randi() == expected_global, label + ": global RNG unchanged")


func _test_paid_both_pairs() -> void:
	var catalog := StarterCards.new()
	for id in ["fixture_forward", "fixture_backward", "fixture_mid_forward", "fixture_mid_backward"]:
		_check(not catalog.has_card(id) and not catalog.get_starting_deck().has(id),
			id + ": move definition is test-only, never added to starter catalog")
	var party := _party()
	_decorate(party)
	var initial := party.get_heroes()
	var deck := _deck(["fixture_forward", "fixture_backward"])
	var forward := _definition("fixture_forward", "warden", 1, [1], 1)
	var backward := _definition("fixture_backward", "warden", 2, [2], -1)
	_move(deck, party, forward, ["seamstress", "warden", "tinker"], "1 to 2 forward")
	_check(deck.energy == 2 and deck.discard_pile == ["fixture_forward"],
		"forward cost 1, exactly first card discarded")
	_move(deck, party, backward, ["warden", "seamstress", "tinker"], "2 to 1 backward after earlier move")
	_check(deck.energy == 0 and deck.hand.is_empty()
		and deck.discard_pile == ["fixture_forward", "fixture_backward"],
		"backward cost 2 exhausts turn and discards only its copy")
	_check(party.get_heroes() == initial, "forward/back restores exact statuses and metadata")

	party = _party()
	_decorate(party)
	initial = party.get_heroes()
	deck = _deck(["fixture_mid_forward", "fixture_mid_backward"])
	var mid_forward := _definition("fixture_mid_forward", "seamstress", 1, [2], 1)
	var mid_backward := _definition("fixture_mid_backward", "seamstress", 0, [3], -1)
	_move(deck, party, mid_forward, ["warden", "tinker", "seamstress"], "2 to 3 forward")
	_move(deck, party, mid_backward, ["warden", "seamstress", "tinker"], "3 to 2 backward from new slot")
	_check(party.get_heroes() == initial, "second pair round trip preserves all actor fields")
	_check(deck.energy == 2 and deck.hand.is_empty()
		and deck.discard_pile == ["fixture_mid_forward", "fixture_mid_backward"],
		"zero-cost card still discards exactly one copy")

	party = _party()
	_decorate(party)
	deck = _deck(["fixture_forward", "fixture_forward"])
	_move(deck, party, forward, ["seamstress", "warden", "tinker"], "first duplicate copy")
	_check(deck.hand == ["fixture_forward"] and deck.discard_pile == ["fixture_forward"],
		"one of two identical held copies remains after playing one")
	_reject(deck, party, "fixture_forward", forward, "remaining duplicate wrong current from-position")



	party = _party()
	_decorate(party)
	var six_cards: Array[String] = ["extra_a", "extra_b", "extra_c",
		"extra_d", "extra_e", "extra_f"]
	deck = _deck(six_cards, 193)
	_check(deck.draw_pile.size() == 1 and deck.hand.size() == 5,
		"non-vacuous surviving draw-pile fixture before real paid move")
	var full_cost_id: String = deck.hand[0]
	_move(deck, party, _definition(full_cost_id, "warden", 3, [1], 1),
		["seamstress", "warden", "tinker"], "maximum cost 3 forward")
	_check(deck.energy == 0 and deck.draw_pile.size() == 1,
		"cost 3 exhausts energy without disturbing surviving draw pile")
	var free_id: String = deck.hand[0]
	_move(deck, party, _definition(free_id, "warden", 0, [2], -1),
		["warden", "seamstress", "tinker"], "zero cost still legal with no energy")
	_check(deck.energy == 0 and deck.draw_pile.size() == 1
		and deck.discard_pile == [full_cost_id, free_id],
		"zero-cost move consumes one card after all three energy spent")

func _test_targeting_after_commits() -> void:
	var party := _party()
	_decorate(party)
	var enemies := CombatEnemies.new([
		{"id": "enemy_a", "max_hp": 11},
		{"id": "enemy_b", "max_hp": 12},
		{"id": "enemy_c", "max_hp": 13}
	])
	_check(enemies.is_valid() and enemies.get_enemies().size() == 3,
		"three actual living enemy slots for attack targeting")
	var catalog := StarterCards.new()
	var attack_ids: Array[String] = ["warden_shield_bash", "warden_strike",
		"seamstress_prick", "tinker_pop_shot", "tinker_scrap_bomb"]
	var attacks := _deck(attack_ids)
	for id in attack_ids:
		_check(attacks.hand.has(id) and catalog.has_card(id),
			"independent attack fixture truly holds authored card " + id)
	var targeting := CombatAttackTargeting.new()
	var attack_before := _snapshot(attacks, party)
	var enemy_before := enemies.get_enemies()
	_check(targeting.get_preview(attacks, party, enemies, "warden_shield_bash")
		== {"playable": true, "requires_selection": true, "target_positions": [1]},
		"initial Warden Shield Bash targets enemy slot 1 only")
	_check(targeting.get_preview(attacks, party, enemies, "warden_strike").target_positions == [1, 2]
		and targeting.get_preview(attacks, party, enemies, "seamstress_prick").target_positions == [1, 2, 3]
		and targeting.get_preview(attacks, party, enemies, "tinker_pop_shot").target_positions == [1, 2, 3],
		"authored strike, prick, pop target restrictions apply before movement")

	var moves := _deck(["w_to_2", "w_to_1", "t_to_2"], 9328)
	_move(moves, party, _definition("w_to_2", "warden", 0, [1], 1),
		["seamstress", "warden", "tinker"], "targeting Warden leaves front")
	_check(not targeting.get_preview(attacks, party, enemies, "warden_shield_bash").playable
		and targeting.get_preview(attacks, party, enemies, "warden_strike").target_positions == [1, 2],
		"committed Warden slot2 forbids bash but keeps strike")
	_move(moves, party, _definition("w_to_1", "warden", 0, [2], -1),
		["warden", "seamstress", "tinker"], "targeting Warden returns")
	_check(targeting.get_preview(attacks, party, enemies, "warden_shield_bash").target_positions == [1],
		"Shield Bash available again after authoritative return to front")
	_move(moves, party, _definition("t_to_2", "tinker", 0, [3], -1),
		["warden", "tinker", "seamstress"], "targeting Tinker moves to middle")
	_check(targeting.get_preview(attacks, party, enemies, "tinker_pop_shot").playable
		and not targeting.get_preview(attacks, party, enemies, "tinker_scrap_bomb").playable,
		"Tinker middle permits Pop Shot but not slot3-only Scrap Bomb")

	moves = _deck(["t_to_1", "t_back_2", "t_back_3"], 9331)
	_move(moves, party, _definition("t_to_1", "tinker", 0, [2], -1),
		["tinker", "warden", "seamstress"], "targeting Tinker moves to front")
	_check(not targeting.get_preview(attacks, party, enemies, "tinker_pop_shot").playable,
		"Pop Shot fails when actual Tinker owner occupies slot1")
	_move(moves, party, _definition("t_back_2", "tinker", 0, [1], 1),
		["warden", "tinker", "seamstress"], "targeting Tinker recovers slot2")
	_check(targeting.get_preview(attacks, party, enemies, "tinker_pop_shot").target_positions == [1, 2, 3],
		"Pop Shot restores full target list at slot2")
	_check(enemies.apply_damage(2, 1000) and enemies.is_slain(2), "enemy slot2 is truly slain")
	_check(targeting.get_preview(attacks, party, enemies, "tinker_pop_shot").target_positions == [1, 3]
		and targeting.get_preview(attacks, party, enemies, "warden_shield_bash").target_positions == [1],
		"attack targeting does not compact slain enemies or broaden Shield Bash")
	_move(moves, party, _definition("t_back_3", "tinker", 0, [2], 1),
		["warden", "seamstress", "tinker"], "targeting Tinker back at rear")
	_check(targeting.get_preview(attacks, party, enemies, "tinker_scrap_bomb")
		== {"playable": true, "requires_selection": false, "target_positions": [1, 3]},
		"authoritative slot3 makes all-target Scrap Bomb available against living slots")
	_check(attacks.hand == attack_before["hand"] and attacks.energy == attack_before["energy"]
		and attacks._rng.state == attack_before["rng_state"]
		and attacks.draw_pile == attack_before["draw"] and attacks.discard_pile == attack_before["discard"],
		"attack fixture hand, energy, draw, discard, RNG untouched by all moves/previews")
	_check(enemies.get_enemy(1) == enemy_before[0] and enemies.get_enemy(3) == enemy_before[2],
		"moving heroes does not mutate untouched enemies")


func _test_rejections() -> void:
	var good := _definition("held", "warden", 1, [1], 1)
	var party := _party()
	_decorate(party)
	var deck := _deck(["held", "other"])
	_reject(null, party, "held", good, "null deck")
	_reject(deck, null, "held", good, "null party")
	_reject(deck, CombatParty.new([]), "held", good, "invalid empty party")
	_reject(deck, CombatParty.new([
		{"id": "warden", "max_hp": 40}, {"id": "warden", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}]), "held", good, "invalid duplicate party constructor")
	_reject(deck, party, "", good, "empty card ID")
	_reject(deck, party, 5, good, "numeric card ID")
	_reject(deck, party, "unheld", good, "unheld card ID")
	_reject(deck, party, "held", null, "null definition")
	_reject(deck, party, "held", [], "non-dictionary definition")
	_reject(deck, party, "held", {}, "missing all definition fields")

	var broken: Array = [
		{"id": "other"}, {"id": ""}, {"id": 5}, {"id": null},
		{"owner": ""}, {"owner": 13}, {"owner": "absent"}, {"owner": null},
		{"cost": -1}, {"cost": 4}, {"cost": 1.5}, {"cost": "1"}, {"cost": null},
		{"from_positions": []}, {"from_positions": null}, {"from_positions": "1"},
		{"from_positions": [2]}, {"from_positions": [0]}, {"from_positions": [4]},
		{"from_positions": [1, 2.0]}, {"from_positions": [1, "2"]},
		{"action_kind": ""}, {"action_kind": "enemy_shove"}, {"action_kind": null},
		{"direction": 0}, {"direction": 2}, {"direction": -2},
		{"direction": 1.0}, {"direction": "1"}, {"direction": null}
	]
	for i in range(broken.size()):
		var bad := good.duplicate(true)
		bad.merge(broken[i], true)
		_reject(deck, party, "held", bad, "malformed definition case " + str(i))
	for missing in ["id", "owner", "cost", "from_positions", "action_kind", "direction"]:
		var bad := good.duplicate(true)
		bad.erase(missing)
		_reject(deck, party, "held", bad, "missing " + missing)

	var wrong := _definition("held", "seamstress", 1, [1], 1)
	_reject(deck, party, "held", wrong, "wrong owner position from actual party")
	wrong = _definition("held", "warden", 1, [2], -1)
	_reject(deck, party, "held", wrong, "wrong allowed from position")
	wrong = _definition("held", "warden", 1, [1], -1)
	_reject(deck, party, "held", wrong, "front off-board direction")
	var rear := CombatParty.new([{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}, {"id": "warden", "max_hp": 40}])
	_check(rear.is_valid() and rear.get_hero(3).id == "warden", "valid rear-edge mover fixture")
	_reject(deck, rear, "held", _definition("held", "warden", 1, [3], 1),
		"rear off-board direction")
	var missing_owner := CombatParty.new([{"id": "a", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30}, {"id": "tinker", "max_hp": 26}])
	_reject(deck, missing_owner, "held", good, "absent owner in valid party")

	var downed_mover := _party()
	_check(downed_mover.apply_damage(1, 40) and downed_mover.is_downed(1),
		"actual downed mover fixture")
	_reject(deck, downed_mover, "held", good, "downed mover")
	var downed_neighbor := _party()
	_check(downed_neighbor.apply_damage(2, 30) and downed_neighbor.is_downed(2),
		"actual downed destination fixture")
	_reject(deck, downed_neighbor, "held", good, "downed destination")

	var bad_party := _party()
	bad_party._heroes[1]["id"] = "warden"
	_reject(deck, bad_party, "held", good, "externally corrupted duplicate ID")
	bad_party = _party()
	bad_party._heroes[1]["position"] = 3
	_reject(deck, bad_party, "held", good, "externally corrupted position fields")
	bad_party = _party()
	bad_party._heroes[2]["hp"] = -3
	_reject(deck, bad_party, "held", good, "externally corrupted negative HP")

	var inactive := _deck(["held"], 812, false)
	_check(not inactive.turn_active and inactive.hand.is_empty(),
		"inactive fixture is genuinely pre-turn and undrawn")
	_reject(inactive, party, "held", good, "inactive before first turn")
	_check(inactive.start_turn() and inactive.end_turn() and not inactive.turn_active,
		"actual ended turn fixture")
	_reject(inactive, party, "held", good, "inactive after end turn")
	var in_draw := _deck(["held", "a", "b", "c", "d", "e"], 785)
	_check(not in_draw.draw_pile.is_empty() and not in_draw.hand.has(in_draw.draw_pile[0]),
		"draw-pile-only copy is not in real active hand")
	var drawn_id: String = in_draw.draw_pile[0]
	_reject(in_draw, party, drawn_id, _definition(drawn_id, "warden", 0, [1], 1),
		"card in draw pile but not held")
	_check(deck.try_spend_energy(2) and deck.energy == 1, "real fixture prep spends two energy")
	_reject(deck, party, "held", _definition("held", "warden", 2, [1], 1),
		"insufficient energy, despite legitimately held card")

	var spent := _deck(["held"])
	_move(spent, party, good, ["seamstress", "warden", "tinker"], "spent-card setup")
	_reject(spent, party, "held", good, "spent single held copy cannot play twice")
	_reject(spent, party, "held", _definition("held", "warden", 0, [2], -1),
		"already discarded ID cannot be reused even with correct current position")

	var preview_before := _snapshot(deck, party)
	var proposal := CombatPositionSwaps.preview_adjacent_swap(party, 2, -1)
	_check(proposal["ok"] and proposal["heroes"] != party.get_heroes(),
		"preview is a proposal, not mistaken for current authoritative order")
	_check(proposal["ok"] and proposal["heroes"][0]["id"] == "warden"
		and proposal["heroes"][1]["id"] == "seamstress",
		"old preview still reports detached legal reorder")
	proposal["heroes"][0]["metadata"]["layers"][0]["values"].append(500)
	proposal["heroes"][1]["hp"] = 1000
	_check(_snapshot(deck, party) == preview_before,
		"editing nested preview copies never mutates original models")
	var proposal_next := CombatPositionSwaps.preview_adjacent_swap(party, 2, -1)
	_check(proposal_next["heroes"][0]["metadata"]["layers"][0]["values"].size() == 2,
		"future proposal independent of earlier returned copies")
	_check(CombatPositionSwaps.preview_adjacent_swap(party, 1, -1)
		== {"ok": false, "heroes": []}, "old preview keeps exact rejection shape")
	_check(_snapshot(deck, party) == preview_before,
		"legal and rejected previews preserve entire state and injected RNG")


func _trace(seed_value: int) -> Array:
	var party := _party()
	_decorate(party)
	var deck := _deck(["fixture_forward", "fixture_backward"], seed_value)
	var history: Array = [_snapshot(deck, party)]
	_move(deck, party, _definition("fixture_forward", "warden", 1, [1], 1),
		["seamstress", "warden", "tinker"], "seeded forward")
	history.append(_snapshot(deck, party))
	_move(deck, party, _definition("fixture_backward", "warden", 2, [2], -1),
		["warden", "seamstress", "tinker"], "seeded backward")
	history.append(_snapshot(deck, party))
	return history


func _test_seeded_replay() -> void:
	for seed_value in [0, 42, 987654]:
		var first := _trace(seed_value)
		var second := _trace(seed_value)
		_check(first.size() == 3 and second.size() == 3 and first == second,
			"two independent seed " + str(seed_value) + " runs match exact transitions and RNG")
		_check(first[0]["hand"].size() == 2
			and first[1]["hand"].size() == 1 and first[2]["hand"].is_empty()
			and first[0]["party"] != first[1]["party"] and first[0]["party"] == first[2]["party"],
			"seed " + str(seed_value) + " replay has real paid moves and original roster restored")

