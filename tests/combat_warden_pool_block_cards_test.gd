extends SceneTree
## Isolated, deterministic tests of the real catalog, shared deck and hero party.

const HEROES_PATH := "res://data/heroes/starter_party.json"
const CASES := [
	{"id": "warden_hold_the_line", "cost": 1, "kind": "self",
		"effects": {"block": 5, "other_ally_block": 2}, "delta": [5, 2, 2], "target": 0},
	{"id": "warden_hold_the_line_plus", "cost": 1, "kind": "self",
		"effects": {"block": 7, "other_ally_block": 3}, "delta": [7, 3, 3], "target": 0},
	{"id": "warden_patch_guard", "cost": 1, "kind": "ally_single",
		"effects": {"block": 8}, "delta": [0, 0, 8], "target": 3},
	{"id": "warden_patch_guard_plus", "cost": 1, "kind": "ally_single",
		"effects": {"block": 11}, "delta": [0, 0, 11], "target": 3},
	{"id": "warden_quick_darn", "cost": 0, "kind": "self",
		"effects": {"block": 4}, "delta": [4, 0, 0], "target": 0},
	{"id": "warden_quick_darn_plus", "cost": 0, "kind": "self",
		"effects": {"block": 6}, "delta": [6, 0, 0], "target": 0},
	{"id": "warden_iron_hem", "cost": 2, "kind": "self",
		"effects": {"block": 14}, "delta": [14, 0, 0], "target": 0},
	{"id": "warden_iron_hem_plus", "cost": 1, "kind": "self",
		"effects": {"block": 14}, "delta": [14, 0, 0], "target": 0},
	{"id": "warden_bastion_quilt", "cost": 3, "kind": "party_all",
		"effects": {"block_all": 10}, "delta": [10, 10, 10], "target": 0},
	{"id": "warden_bastion_quilt_plus", "cost": 3, "kind": "party_all",
		"effects": {"block_all": 13}, "delta": [13, 13, 13], "target": 0},
]

var failures: Array[String] = []
var checks := 0
var service := CombatWardenPoolBlockCards.new()


func _initialize() -> void:
	_test_all_ten()
	_test_targets_and_living()
	_test_current_positions()
	_test_fail_closed()
	_test_energy_and_capacity()
	_test_seeded_replay()
	for failure in failures:
		printerr(failure)
	print("combat_warden_pool_block_cards_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _party() -> CombatParty:
	var raw: String = FileAccess.get_file_as_string(HEROES_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	_check(not raw.is_empty() and parsed is Array and parsed.size() == 3,
		"real authored party file supplies all three heroes")
	if not parsed is Array or parsed.size() != 3:
		return CombatParty.new([])
	for hero in parsed:
		if hero is Dictionary and hero.get("max_hp") is float:
			hero["max_hp"] = int(hero["max_hp"])
	var party := CombatParty.new(parsed)
	_check(party.is_valid() and party.get_hero(1).get("id") == "warden"
		and party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(3).get("id") == "tinker",
		"valid real CombatParty with expected stable hero IDs")
	return party


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _deck(id: String, seed_value: int = 6452) -> CombatDeck:
	# Six cards with three matching copies guarantee two held copies and
	# one untouched draw card regardless of the seeded shuffle.
	var ids: Array[String] = [id, id, id, "filler_a", "filler_b", "filler_c"]
	var deck := CombatDeck.new(ids, _rng(seed_value))
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
		and deck.hand.size() == 5 and deck.hand.count(id) >= 2
		and deck.draw_pile.size() == 1,
		id + ": real 5-card shared hand, duplicate and seeded draw pile")
	return deck


func _snapshot(deck: CombatDeck, party: CombatParty) -> Dictionary:
	var result := {"heroes": party.get_heroes()}
	if deck != null:
		result["hand"] = deck.hand.duplicate(true)
		result["draw"] = deck.draw_pile.duplicate(true)
		result["discard"] = deck.discard_pile.duplicate(true)
		result["energy"] = deck.energy
		result["turn"] = deck.turn_active
		result["state_energy"] = deck.combat_state.energy
		result["state_turn"] = deck.combat_state.player_turn_active
		result["rng_state"] = deck._rng.state
		result["rng_seed"] = deck._rng.seed
	return result


func _expected(before: Dictionary, card_id: String, cost: int, delta: Array) -> Dictionary:
	var result: Dictionary = before.duplicate(true)
	result["energy"] -= cost
	result["state_energy"] -= cost
	var hand: Array = result["hand"]
	hand.remove_at(hand.find(card_id))
	var discard: Array = result["discard"]
	discard.append(card_id)
	for index in range(3):
		result["heroes"][index]["block"] += delta[index]
	return result


func _accepted(deck: CombatDeck, party: CombatParty, id: String, cost: int,
		target: int, delta: Array, label: String) -> void:
	var before := _snapshot(deck, party)
	_check(deck.hand.has(id) and not party.is_downed(1) and deck.energy >= cost,
		label + ": genuine active hand, living Warden and affordable cost")
	var original_count: int = deck.hand.count(id)
	var discarded_count: int = deck.discard_pile.count(id)
	var expected: Dictionary = _expected(before, id, cost, delta)
	var response: Dictionary = service.play_card(deck, party, id, target)
	_check(response.get("ok") == true, label + ": authorized play")
	_check(_snapshot(deck, party) == expected,
		label + ": full exact actors, piles, energy and injected RNG")
	_check(deck.hand.count(id) == original_count - 1
		and deck.discard_pile.count(id) == discarded_count + 1
		and deck.hand.count(id) >= 1,
		label + ": only one held matching copy discarded; duplicate remains")
	var deltas: Dictionary = response.get("block_deltas", {})
	var expected_deltas := {}
	for index in range(3):
		if delta[index] > 0:
			expected_deltas[index + 1] = delta[index]
	_check(deltas == expected_deltas, label + ": detached per-current-position deltas")
	deltas.clear()
	_check(_snapshot(deck, party) == expected, label + ": response cannot mutate the party")


func _rejected(deck: CombatDeck, party: CombatParty, id: String,
		target: int, label: String) -> void:
	var before := _snapshot(deck, party)
	var result: Dictionary = service.play_card(deck, party, id, target)
	_check(result.get("ok") == false, label + ": rejected")
	_check(_snapshot(deck, party) == before,
		label + ": atomic rejection leaves complete party/deck/seed unchanged")


func _test_all_ten() -> void:
	var catalog := WardenPoolCards.new()
	for spec in CASES:
		var id: String = spec["id"]
		var definition: Dictionary = catalog.get_definition(id)
		var base_id: String = id.trim_suffix("_plus")
		var expected_from: Array = [1, 2] if base_id in [
			"warden_hold_the_line", "warden_quick_darn"] else [1, 2, 3]
		_check(catalog.has_card(id) and definition.get("id") == id
			and definition.get("owner") == "warden"
			and definition.get("cost") == spec["cost"]
			and definition.get("target_kind") == spec["kind"]
			and definition.get("effects") == spec["effects"]
			and definition.get("from_positions") == expected_from
			and definition.get("to_positions") == []
			and definition.get("starting_copies") == 0,
			id + ": exact real authored metadata")
		if id.ends_with("_plus"):
			_check(definition.get("reward_eligible") == false
				and definition.get("upgrade_of") == base_id,
				id + ": upgrade is not a base reward")
		else:
			_check(definition.get("reward_eligible") == true
				and definition.get("upgrade_id") == id + "_plus",
				id + ": base reward and upgrade link")

		var party := _party()
		_check(party.apply_damage(2, 3) and party.gain_block(3, 4),
			id + ": prior wound and Block distinguish untouched state")
		var deck := _deck(id)
		_accepted(deck, party, id, spec["cost"], spec["target"],
			spec["delta"], id)


func _test_targets_and_living() -> void:
	var party := _party()
	var deck := _deck("warden_patch_guard")
	_accepted(deck, party, "warden_patch_guard", 1, 1, [8, 0, 0],
		"Patch Guard may target living owner as ally")

	party = _party()
	_check(party.apply_damage(2, 30) and party.is_downed(2),
		"Hold the Line fixture has a downed Seamstress")
	deck = _deck("warden_hold_the_line")
	_accepted(deck, party, "warden_hold_the_line", 1, 0, [5, 0, 2],
		"Hold the Line excludes downed non-owner without reviving")
	_check(party.get_hero(2).hp == 0, "Hold the Line keeps downed hero at zero HP")

	party = _party()
	_check(party.apply_damage(2, 30) and party.is_downed(2),
		"Bastion fixture has downed Seamstress")
	deck = _deck("warden_bastion_quilt_plus")
	_accepted(deck, party, "warden_bastion_quilt_plus", 3, 0, [13, 0, 13],
		"Bastion Quilt+ skips downed middle hero")
	_check(party.get_hero(2).hp == 0, "Bastion does not revive downed ally")


func _moved_party(position: int) -> CombatParty:
	var party := _party()
	var move_id := "fixture_warden_forward"
	var moving := CombatDeck.new([move_id, move_id], _rng(345))
	_check(moving.start_turn(), "position fixture begins a legitimate shared turn")
	var move_def := {"id": move_id, "owner": "warden", "cost": 0,
		"from_positions": [1, 2, 3], "action_kind": "adjacent_swap", "direction": 1}
	for step in range(position - 1):
		_check(CombatPositionSwaps.play_move_card(moving, party, move_id, move_def),
			"actual adjacent move shifts Warden to " + str(step + 2))
	_check(party.get_hero(position).get("id") == "warden"
		and party.get_hero(position).get("position") == position,
		"Warden identity is at actual slot " + str(position))
	return party


func _test_current_positions() -> void:
	var party := _moved_party(2)
	_accepted(_deck("warden_hold_the_line"), party, "warden_hold_the_line",
		1, 0, [2, 5, 2], "moved Warden Hold the Line at middle slot")
	party = _moved_party(2)
	_accepted(_deck("warden_quick_darn_plus"), party, "warden_quick_darn_plus",
		0, 0, [0, 6, 0], "moved Warden Quick Darn+ at middle slot")
	party = _moved_party(3)
	_rejected(_deck("warden_hold_the_line"), party,
		"warden_hold_the_line", 0, "Hold the Line illegal from rear")
	_rejected(_deck("warden_quick_darn_plus"), party,
		"warden_quick_darn_plus", 0, "Quick Darn+ illegal from rear")
	_accepted(_deck("warden_iron_hem"), party, "warden_iron_hem",
		2, 0, [0, 0, 14], "Iron Hem valid from rear")
	_accepted(_deck("warden_patch_guard"), party, "warden_patch_guard",
		1, 1, [8, 0, 0], "Patch Guard from rear targets current front ally")


func _test_fail_closed() -> void:
	var party := _party()
	var rng := _rng(414)
	var inactive := CombatDeck.new(["warden_hold_the_line"], rng)
	_rejected(inactive, party, "warden_hold_the_line", 0, "inactive turn")
	var deck := _deck("warden_hold_the_line")
	_rejected(deck, party, "warden_patch_guard", 2, "card absent from hand")
	_rejected(deck, party, "warden_hold_the_line", 1, "self target must be zero")
	_rejected(deck, party, "warden_hold_the_line", -1, "self target cannot be negative")

	deck = _deck("warden_patch_guard_plus")
	for wrong_target in [0, -1, 4]:
		_rejected(deck, party, "warden_patch_guard_plus", wrong_target,
			"Patch Guard+ requires living slot " + str(wrong_target))
	_check(party.apply_damage(3, 26) and party.is_downed(3),
		"downed target fixture is valid")
	_rejected(deck, party, "warden_patch_guard_plus", 3, "downed ally target")
	deck = _deck("warden_bastion_quilt")
	_rejected(deck, party, "warden_bastion_quilt", 2, "party-all target must be zero")

	party = _party()
	_check(party.apply_damage(1, 40) and party.is_downed(1),
		"dead owner fixture is downed")
	_rejected(_deck("warden_quick_darn"), party, "warden_quick_darn", 0,
		"downed Warden cannot play zero-cost card")

	party = _party()
	for unsupported in [
		"warden_pinning_jab", "warden_heavy_thimble",
		"warden_brass_buckle", "warden_draw_fire", "warden_seam_breaker",
		"warden_counter_stitch", "warden_pin_and_pound",
		"warden_draw_fire_plus", "warden_counter_stitch_plus",
		"warden_seam_breaker_plus", "warden_pinning_jab_plus",
		"missing_warden_card"]:
		_rejected(_deck(unsupported), party, unsupported, 0,
			"unsupported attack/status/unrecognized ID " + unsupported)


func _test_energy_and_capacity() -> void:
	var party := _party()
	var base := _deck("warden_iron_hem")
	_check(base.try_spend_energy(2) and base.energy == 1,
		"base Iron Hem test has one energy remaining")
	_rejected(base, party, "warden_iron_hem", 0,
		"two-energy Iron Hem cannot play at one energy")
	var plus := _deck("warden_iron_hem_plus")
	_check(plus.try_spend_energy(2) and plus.energy == 1,
		"Iron Hem+ test has one energy remaining")
	_accepted(plus, party, "warden_iron_hem_plus", 1, 0, [14, 0, 0],
		"one-energy Iron Hem+ plays for identical fourteen Block")

	var free := _deck("warden_quick_darn")
	_check(free.try_spend_energy(3) and free.energy == 0,
		"zero-cost test has no energy")
	_accepted(free, party, "warden_quick_darn", 0, 0, [4, 0, 0],
		"Quick Darn is playable with zero energy")

	party = _party()
	_check(party.gain_block(3, CombatParty.MAX_INT - 1),
		"team overflow fixture succeeds at MAX_INT minus one")
	_rejected(_deck("warden_hold_the_line"), party,
		"warden_hold_the_line", 0, "late Hold the Line recipient would overflow")
	_rejected(_deck("warden_bastion_quilt"), party,
		"warden_bastion_quilt", 0, "late Bastion recipient would overflow")
	_rejected(_deck("warden_patch_guard"), party,
		"warden_patch_guard", 3, "selected ally Block overflow")


func _test_seeded_replay() -> void:
	var left_party := _party()
	var right_party := _party()
	var left := _deck("warden_hold_the_line_plus", 729)
	var right := _deck("warden_hold_the_line_plus", 729)
	_check(_snapshot(left, left_party) == _snapshot(right, right_party),
		"identical seeded decks start with identical state")
	_accepted(left, left_party, "warden_hold_the_line_plus", 1, 0,
		[7, 3, 3], "seeded left replay")
	_accepted(right, right_party, "warden_hold_the_line_plus", 1, 0,
		[7, 3, 3], "seeded right replay")
	_check(_snapshot(left, left_party) == _snapshot(right, right_party),
		"replay matches complete party, piles and RNG state")
