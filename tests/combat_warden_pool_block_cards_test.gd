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

const CUFF_CASES := [
	{"id": "warden_hold_the_line", "cost": 1, "kind": "self",
		"target": 0, "delta": [7, 2, 2]},
	{"id": "warden_hold_the_line_plus", "cost": 1, "kind": "self",
		"target": 0, "delta": [9, 3, 3]},
	{"id": "warden_patch_guard", "cost": 1, "kind": "ally_single",
		"target": 3, "delta": [0, 0, 10]},
	{"id": "warden_patch_guard_plus", "cost": 1, "kind": "ally_single",
		"target": 3, "delta": [0, 0, 13]},
	{"id": "warden_quick_darn", "cost": 0, "kind": "self",
		"target": 0, "delta": [6, 0, 0]},
	{"id": "warden_quick_darn_plus", "cost": 0, "kind": "self",
		"target": 0, "delta": [8, 0, 0]},
	{"id": "warden_iron_hem", "cost": 2, "kind": "self",
		"target": 0, "delta": [16, 0, 0]},
	{"id": "warden_iron_hem_plus", "cost": 1, "kind": "self",
		"target": 0, "delta": [16, 0, 0]},
	{"id": "warden_bastion_quilt", "cost": 3, "kind": "party_all",
		"target": 0, "delta": [10, 10, 10]},
	{"id": "warden_bastion_quilt_plus", "cost": 3, "kind": "party_all",
		"target": 0, "delta": [13, 13, 13]},
]

const BROWBAND_CASES := [
	{"id": "warden_hold_the_line", "cost": 1, "kind": "self",
		"target": 0, "delta": [7, 2, 2]},
	{"id": "warden_hold_the_line_plus", "cost": 1, "kind": "self",
		"target": 0, "delta": [9, 3, 3]},
	{"id": "warden_patch_guard", "cost": 1, "kind": "ally_single",
		"target": 3, "delta": [0, 0, 10]},
	{"id": "warden_patch_guard_plus", "cost": 1, "kind": "ally_single",
		"target": 3, "delta": [0, 0, 13]},
	{"id": "warden_quick_darn", "cost": 0, "kind": "self",
		"target": 0, "delta": [6, 0, 0]},
	{"id": "warden_quick_darn_plus", "cost": 0, "kind": "self",
		"target": 0, "delta": [8, 0, 0]},
	{"id": "warden_iron_hem", "cost": 2, "kind": "self",
		"target": 0, "delta": [16, 0, 0]},
	{"id": "warden_iron_hem_plus", "cost": 1, "kind": "self",
		"target": 0, "delta": [16, 0, 0]},
	{"id": "warden_bastion_quilt", "cost": 3, "kind": "party_all",
		"target": 0, "delta": [10, 10, 10]},
	{"id": "warden_bastion_quilt_plus", "cost": 3, "kind": "party_all",
		"target": 0, "delta": [13, 13, 13]},
]

const STACKED_CASES := [
	{"id": "warden_hold_the_line", "cost": 1, "kind": "self",
		"target": 0, "delta": [9, 2, 2]},
	{"id": "warden_hold_the_line_plus", "cost": 1, "kind": "self",
		"target": 0, "delta": [11, 3, 3]},
	{"id": "warden_patch_guard", "cost": 1, "kind": "ally_single",
		"target": 3, "delta": [0, 0, 12]},
	{"id": "warden_patch_guard_plus", "cost": 1, "kind": "ally_single",
		"target": 3, "delta": [0, 0, 15]},
	{"id": "warden_quick_darn", "cost": 0, "kind": "self",
		"target": 0, "delta": [8, 0, 0]},
	{"id": "warden_quick_darn_plus", "cost": 0, "kind": "self",
		"target": 0, "delta": [10, 0, 0]},
	{"id": "warden_iron_hem", "cost": 2, "kind": "self",
		"target": 0, "delta": [18, 0, 0]},
	{"id": "warden_iron_hem_plus", "cost": 1, "kind": "self",
		"target": 0, "delta": [18, 0, 0]},
	{"id": "warden_bastion_quilt", "cost": 3, "kind": "party_all",
		"target": 0, "delta": [10, 10, 10]},
	{"id": "warden_bastion_quilt_plus", "cost": 3, "kind": "party_all",
		"target": 0, "delta": [13, 13, 13]},
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
	_test_cuff_binding_ac1()
	_test_cuff_all_ten_ac2()
	_test_cuff_negative_and_stale_ac3()
	_test_head_binding_ac1()
	_test_head_all_ten_ac1()
	_test_stacked_head_arm_ac2()
	_test_head_negative_and_stale_ac3()
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


func _raw_heroes() -> Array:
	return _party().get_heroes()


func _wardrobe_fixture(owned: Array = [
			"hemguard_cuff", "pincushion_arm", "button_eye",
			"reinforced_browband", "bloodstitch_bonnet"
		],
		defs: Array = [
			{"id": "hemguard_cuff", "slot": "ARM"},
			{"id": "pincushion_arm", "slot": "ARM"},
			{"id": "button_eye", "slot": "HEAD"},
			{"id": "reinforced_browband", "slot": "HEAD"},
			{"id": "bloodstitch_bonnet", "slot": "HEAD"}
		]) -> Dictionary:
	var heroes := _raw_heroes()
	var torn := RunTornMending.new(heroes)
	var cards := ["warden_brace", "seamstress_prick", "tinker_spool_launcher"]
	var wardrobe := RunPatchWardrobe.new(heroes, owned, defs, 5, 100, cards, 8812)
	return {"wardrobe": wardrobe, "torn": torn, "heroes": heroes}


func _refresh_wardrobe_torn(wardrobe: RunPatchWardrobe, torn: RunTornMending) -> void:
	var old: Dictionary = wardrobe.get_snapshot()
	var ok: bool = wardrobe.refresh_run_context(torn.read_state()["heroes"], old["owned"],
		old["scraps"], old["gold"], old["cards"], old)
	_check(ok, "wardrobe refresh confirms torn authority's new roster")


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
	_accepted_with(service, deck, party, id, cost, target, delta, label)


func _accepted_with(svc: CombatWardenPoolBlockCards, deck: CombatDeck, party: CombatParty,
		id: String, cost: int, target: int, delta: Array, label: String) -> void:
	var before := _snapshot(deck, party)
	_check(deck.hand.has(id) and not party.is_downed(1) and deck.energy >= cost,
		label + ": genuine active hand, living Warden and affordable cost")
	var original_count: int = deck.hand.count(id)
	var discarded_count: int = deck.discard_pile.count(id)
	var expected: Dictionary = _expected(before, id, cost, delta)
	var response: Dictionary = svc.play_card(deck, party, id, target)
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
	_rejected_with(service, deck, party, id, target, label)


func _rejected_with(svc: CombatWardenPoolBlockCards, deck: CombatDeck, party: CombatParty,
		id: String, target: int, label: String) -> void:
	var before := _snapshot(deck, party)
	var result: Dictionary = svc.play_card(deck, party, id, target)
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


func _test_cuff_binding_ac1() -> void:
	var ctx := _wardrobe_fixture()
	var wardrobe: RunPatchWardrobe = ctx["wardrobe"]
	var torn: RunTornMending = ctx["torn"]
	_check(wardrobe.is_valid() and torn.is_valid(), "AC1: wardrobe and torn are valid")

	var snap_before: Dictionary = wardrobe.get_snapshot()
	var sew: Dictionary = wardrobe.sew("hemguard_cuff", "warden", "ARM", "op-ac1-sew", snap_before)
	_check(sew.get("ok") == true, "AC1: genuine owned hemguard_cuff sewn to Warden ARM")

	var w_snap: Dictionary = wardrobe.get_snapshot()
	var t_snap: Dictionary = torn.read_state()
	var patched_svc := CombatWardenPoolBlockCards.new()
	var bound: bool = patched_svc.bind_patch_wardrobe(wardrobe, torn, w_snap, t_snap)
	_check(bound, "AC1: explicit successful binding assertion with matching snapshots")
	_check(patched_svc.is_patch_binding_valid(), "AC1: resolver binding is currently valid")
	_check(patched_svc.get_patches() != null and patched_svc.get_patches().is_valid(),
		"AC1: resolver holds valid CombatPatchAttackRules")
	_check(patched_svc.get_head_patches() != null and patched_svc.get_head_patches().read_projection().get("ok") == true,
		"AC1: resolver holds valid CombatM05HeadPatchRules")
	_check(patched_svc.get_wardrobe() == wardrobe, "AC1: get_wardrobe returns bound instance")
	_check(patched_svc.get_torn() == torn, "AC1: get_torn returns bound instance")
	_check(wardrobe.get_snapshot() == w_snap, "AC1: resolver does not mutate wardrobe ledger")
	_check(torn.read_state() == t_snap, "AC1: resolver does not mutate torn ledger")


func _test_cuff_all_ten_ac2() -> void:
	var ctx := _wardrobe_fixture()
	var wardrobe: RunPatchWardrobe = ctx["wardrobe"]
	var torn: RunTornMending = ctx["torn"]
	var sew: Dictionary = wardrobe.sew("hemguard_cuff", "warden", "ARM", "op-ac2-sew", wardrobe.get_snapshot())
	_check(sew.get("ok") == true, "AC2: sew cuff onto Warden")
	var patched_svc := CombatWardenPoolBlockCards.new()
	_check(patched_svc.bind_patch_wardrobe(wardrobe, torn), "AC2: bind wardrobe to resolver")

	for spec in CUFF_CASES:
		var id: String = spec["id"]
		var party := _party()
		_check(party.apply_damage(2, 3) and party.gain_block(3, 4),
			id + ": prior wound and Block distinguish untouched state")
		var deck := _deck(id)
		_accepted_with(patched_svc, deck, party, id, spec["cost"], spec["target"],
			spec["delta"], "AC2 " + id)

	# Additional checks for AC2:
	# Patch Guard targeting Warden herself as ally: 8+2 = 10 to slot 1
	var party := _party()
	var deck := _deck("warden_patch_guard")
	_accepted_with(patched_svc, deck, party, "warden_patch_guard", 1, 1,
		[10, 0, 0], "AC2 Patch Guard targeting living Warden gets +2")

	# Hold the Line with downed Seamstress (slot 2): excludes downed hero, 5+2=7 for Warden, 2 for Tinker
	party = _party()
	_check(party.apply_damage(2, 30) and party.is_downed(2), "AC2 Seamstress downed")
	deck = _deck("warden_hold_the_line")
	_accepted_with(patched_svc, deck, party, "warden_hold_the_line", 1, 0,
		[7, 0, 2], "AC2 Hold the Line excludes downed hero while granting +2 to Warden")
	_check(party.get_hero(2).hp == 0, "AC2 Hold the Line keeps downed hero at 0 HP")

	# Bastion Quilt+ with downed Seamstress: 13 for living heroes, unaffected by cuff
	party = _party()
	_check(party.apply_damage(2, 30) and party.is_downed(2), "AC2 Seamstress downed for Bastion+")
	deck = _deck("warden_bastion_quilt_plus")
	_accepted_with(patched_svc, deck, party, "warden_bastion_quilt_plus", 3, 0,
		[13, 0, 13], "AC2 Bastion Quilt+ unaffected by cuff and skips downed hero")
	_check(party.get_hero(2).hp == 0, "AC2 Bastion+ does not revive downed ally")


func _test_cuff_negative_and_stale_ac3() -> void:
	# 1. Another hero wearing the cuff: grants no bonus to Warden cards
	var tinker_ctx := _wardrobe_fixture()
	var tinker_w: RunPatchWardrobe = tinker_ctx["wardrobe"]
	var tinker_t: RunTornMending = tinker_ctx["torn"]
	_check(tinker_w.sew("hemguard_cuff", "tinker", "ARM", "op-tinker-cuff",
		tinker_w.get_snapshot()).get("ok") == true, "AC3: sew cuff to Tinker ARM")
	var tinker_svc := CombatWardenPoolBlockCards.new()
	_check(tinker_svc.bind_patch_wardrobe(tinker_w, tinker_t), "AC3: bind Tinker cuff")
	var party := _party()
	var deck := _deck("warden_hold_the_line")
	_accepted_with(tinker_svc, deck, party, "warden_hold_the_line", 1, 0,
		[5, 2, 2], "AC3: Hold the Line has no bonus when Tinker wears cuff")
	party = _party()
	deck = _deck("warden_patch_guard")
	_accepted_with(tinker_svc, deck, party, "warden_patch_guard", 1, 3,
		[0, 0, 8], "AC3: Patch Guard has no bonus when Tinker wears cuff")

	# 2. A different ARM patch on Warden: grants no bonus to Warden Block cards
	var pin_ctx := _wardrobe_fixture()
	var pin_w: RunPatchWardrobe = pin_ctx["wardrobe"]
	var pin_t: RunTornMending = pin_ctx["torn"]
	_check(pin_w.sew("pincushion_arm", "warden", "ARM", "op-warden-pin",
		pin_w.get_snapshot()).get("ok") == true, "AC3: sew pincushion to Warden ARM")
	var pin_svc := CombatWardenPoolBlockCards.new()
	_check(pin_svc.bind_patch_wardrobe(pin_w, pin_t), "AC3: bind Pincushion Arm")
	party = _party()
	deck = _deck("warden_hold_the_line")
	_accepted_with(pin_svc, deck, party, "warden_hold_the_line", 1, 0,
		[5, 2, 2], "AC3: Hold the Line has no bonus when Warden wears Pincushion Arm")
	party = _party()
	deck = _deck("warden_iron_hem")
	_accepted_with(pin_svc, deck, party, "warden_iron_hem", 2, 0,
		[14, 0, 0], "AC3: Iron Hem has no bonus when Warden wears Pincushion Arm")

	# 3. Torn Warden in run torn ledger: bonus is suppressed
	var torn_ctx := _wardrobe_fixture()
	var torn_ledger: RunTornMending = torn_ctx["torn"]
	var b_heroes: Array = _raw_heroes()
	var b_end_w: Array = _raw_heroes()
	b_end_w[0]["hp"] = 0 # Warden drops to 0 HP (torn) in run ledger
	_check(torn_ledger.observe_battle_end("node-warden-torn", b_heroes, b_end_w).get("ok") == true,
		"AC3: battle end observed: Warden torn")
	var torn_w: RunPatchWardrobe = torn_ctx["wardrobe"]
	_refresh_wardrobe_torn(torn_w, torn_ledger)
	_check(torn_w.sew("hemguard_cuff", "warden", "ARM", "op-torn-warden-cuff",
		torn_w.get_snapshot()).get("ok") == true, "AC3: sew cuff on torn Warden")
	var torn_svc := CombatWardenPoolBlockCards.new()
	_check(torn_svc.bind_patch_wardrobe(torn_w, torn_ledger), "AC3: bind torn ledger")
	party = _party() # living combat party
	deck = _deck("warden_hold_the_line")
	_accepted_with(torn_svc, deck, party, "warden_hold_the_line", 1, 0,
		[5, 2, 2], "AC3: torn Warden in ledger suppresses cuff bonus")

	# 4. Downed Warden in combat party: rejected
	var valid_ctx := _wardrobe_fixture()
	var val_w: RunPatchWardrobe = valid_ctx["wardrobe"]
	var val_t: RunTornMending = valid_ctx["torn"]
	_check(val_w.sew("hemguard_cuff", "warden", "ARM", "op-val-cuff",
		val_w.get_snapshot()).get("ok") == true, "AC3: sew cuff")
	var cuff_svc := CombatWardenPoolBlockCards.new()
	_check(cuff_svc.bind_patch_wardrobe(val_w, val_t), "AC3: bind valid cuff")
	party = _party()
	_check(party.apply_damage(1, 40) and party.is_downed(1), "AC3: Warden downed in combat")
	_rejected_with(cuff_svc, _deck("warden_quick_darn"), party,
		"warden_quick_darn", 0, "AC3: downed Warden in combat cannot play")

	# 5. Stale binding by wardrobe replacement / re-sew: rejects play, leaves state untouched
	var replace_ctx := _wardrobe_fixture()
	var rep_w: RunPatchWardrobe = replace_ctx["wardrobe"]
	var rep_t: RunTornMending = replace_ctx["torn"]
	_check(rep_w.sew("hemguard_cuff", "warden", "ARM", "op-rep-cuff",
		rep_w.get_snapshot()).get("ok") == true, "AC3: initial sew cuff")
	var stale_svc := CombatWardenPoolBlockCards.new()
	_check(stale_svc.bind_patch_wardrobe(rep_w, rep_t), "AC3: bind initial")
	# Now mutate wardrobe via legitimate replacement:
	var rep_op: Dictionary = rep_w.sew("pincushion_arm", "warden", "ARM", "op-legit-replace", rep_w.get_snapshot())
	_check(rep_op.get("ok") == true, "AC3: legitimate replacement executed")
	_check(not stale_svc.is_patch_binding_valid(), "AC3: binding is stale after replace")
	party = _party()
	deck = _deck("warden_hold_the_line")
	_rejected_with(stale_svc, deck, party, "warden_hold_the_line", 0,
		"AC3: stale binding rejects play instead of unpatched fallback")
	# Rebind after replacement:
	_check(stale_svc.bind_patch_wardrobe(rep_w, rep_t), "AC3: rebind after replace")
	_check(stale_svc.is_patch_binding_valid(), "AC3: valid after rebind")
	_accepted_with(stale_svc, deck, party, "warden_hold_the_line", 1, 0,
		[5, 2, 2], "AC3: play succeeds after rebind with new ARM patch (pincushion -> unboosted Block)")

	# 6. Stale binding by torn ledger mutation:
	var torn_mut_ctx := _wardrobe_fixture()
	var tm_w: RunPatchWardrobe = torn_mut_ctx["wardrobe"]
	var tm_t: RunTornMending = torn_mut_ctx["torn"]
	_check(tm_w.sew("hemguard_cuff", "warden", "ARM", "op-tm-cuff",
		tm_w.get_snapshot()).get("ok") == true, "AC3: sew cuff for torn mutation test")
	var tm_svc := CombatWardenPoolBlockCards.new()
	_check(tm_svc.bind_patch_wardrobe(tm_w, tm_t), "AC3: bind tm_svc")
	# Legitimate torn ledger mutation (battle end observed):
	var b_heroes_tm: Array = _raw_heroes()
	var b_end: Array = _raw_heroes()
	b_end[1]["hp"] = 0 # Seamstress torn
	_check(tm_t.observe_battle_end("node-mut", b_heroes_tm, b_end).get("ok") == true,
		"AC3: battle end observed in torn ledger")
	_check(not tm_svc.is_patch_binding_valid(), "AC3: binding stale after torn ledger mutation")
	party = _party()
	deck = _deck("warden_hold_the_line")
	_rejected_with(tm_svc, deck, party, "warden_hold_the_line", 0,
		"AC3: stale binding from torn ledger rejects play")
	# Refresh wardrobe and rebind after torn ledger change:
	_refresh_wardrobe_torn(tm_w, tm_t)
	_check(tm_svc.bind_patch_wardrobe(tm_w, tm_t), "AC3: rebind after torn change")
	party = _party()
	deck = _deck("warden_hold_the_line")
	_accepted_with(tm_svc, deck, party, "warden_hold_the_line", 1, 0,
		[7, 2, 2], "AC3: play succeeds after rebind with cuff bonus")

	# 7. Forged / failed bindings:
	var bad_svc := CombatWardenPoolBlockCards.new()
	_check(not bad_svc.bind_patch_wardrobe(null, null), "AC3: null wardrobe binding rejected")
	_check(not bad_svc.is_patch_binding_valid(), "AC3: null binding is invalid")
	party = _party()
	deck = _deck("warden_hold_the_line")
	_rejected_with(bad_svc, deck, party, "warden_hold_the_line", 0,
		"AC3: attempted null binding rejects play")

	var bad_snap_svc := CombatWardenPoolBlockCards.new()
	_check(not bad_snap_svc.bind_patch_wardrobe(tm_w, tm_t, {"forged": 1}, null),
		"AC3: wrong expected wardrobe snapshot rejected")
	_check(not bad_snap_svc.is_patch_binding_valid(), "AC3: bad snapshot binding invalid")
	_rejected_with(bad_snap_svc, deck, party, "warden_hold_the_line", 0,
		"AC3: failed expected snapshot binding rejects play")

	_check(not bad_snap_svc.bind_patch_wardrobe(tm_w, tm_t, null, {"forged": 1}),
		"AC3: wrong expected torn state rejected")
	_rejected_with(bad_snap_svc, deck, party, "warden_hold_the_line", 0,
		"AC3: failed expected torn binding rejects play")

	_check(not bad_snap_svc.bind_patch_wardrobe("forged", tm_t), "AC3: non-wardrobe rejected")
	_check(not bad_snap_svc.bind_patch_wardrobe(tm_w, "forged"), "AC3: non-torn rejected")

	# 8. Negative combat checks with bound service:
	# Insufficient energy
	var no_energy_deck := _deck("warden_iron_hem")
	_check(no_energy_deck.try_spend_energy(3) and no_energy_deck.energy == 0, "AC3: spend all energy")
	_rejected_with(cuff_svc, no_energy_deck, party, "warden_iron_hem", 0,
		"AC3: bound cuff cannot play 2-cost iron hem at 0 energy")
	# Wrong target for self card
	_rejected_with(cuff_svc, _deck("warden_hold_the_line"), party,
		"warden_hold_the_line", 1, "AC3: hold the line target must be 0")
	# Wrong target for ally_single
	_rejected_with(cuff_svc, _deck("warden_patch_guard"), party,
		"warden_patch_guard", 0, "AC3: patch guard target cannot be 0")
	_rejected_with(cuff_svc, _deck("warden_patch_guard"), party,
		"warden_patch_guard", 4, "AC3: patch guard target cannot be 4")
	# Target downed ally
	var downed_ally_party := _party()
	_check(downed_ally_party.apply_damage(3, 26) and downed_ally_party.is_downed(3),
		"AC3: down hero 3")
	_rejected_with(cuff_svc, _deck("warden_patch_guard"), downed_ally_party,
		"warden_patch_guard", 3, "AC3: cannot target downed ally")
	# Moved party from rear (position 3)
	var rear_party := _moved_party(3)
	_rejected_with(cuff_svc, _deck("warden_hold_the_line"), rear_party,
		"warden_hold_the_line", 0, "AC3: hold the line illegal from rear")
	# Overflow preflight
	var ov_party := _party()
	_check(ov_party.gain_block(1, CombatParty.MAX_INT - 5), "AC3: overflow fixture")
	_rejected_with(cuff_svc, _deck("warden_hold_the_line"), ov_party,
		"warden_hold_the_line", 0, "AC3: recipient would overflow with cuff bonus")


func _test_head_binding_ac1() -> void:
	var ctx := _wardrobe_fixture()
	var wardrobe: RunPatchWardrobe = ctx["wardrobe"]
	var torn: RunTornMending = ctx["torn"]
	_check(wardrobe.is_valid() and torn.is_valid(), "AC1: wardrobe and torn are valid for HEAD")

	var snap_before: Dictionary = wardrobe.get_snapshot()
	var sew: Dictionary = wardrobe.sew("reinforced_browband", "warden", "HEAD", "op-ac1-head-sew", snap_before)
	_check(sew.get("ok") == true, "AC1: genuine owned reinforced_browband sewn to Warden HEAD")

	var w_snap: Dictionary = wardrobe.get_snapshot()
	var t_snap: Dictionary = torn.read_state()
	var patched_svc := CombatWardenPoolBlockCards.new()
	var bound: bool = patched_svc.bind_patch_wardrobe(wardrobe, torn, w_snap, t_snap)
	_check(bound, "AC1: explicit successful HEAD binding assertion with matching snapshots")
	_check(patched_svc.is_patch_binding_valid(), "AC1: resolver binding is valid for HEAD")
	_check(patched_svc.get_patches() != null and patched_svc.get_patches().is_valid(),
		"AC1: resolver holds valid CombatPatchAttackRules")
	_check(patched_svc.get_head_patches() != null and patched_svc.get_head_patches().read_projection().get("ok") == true,
		"AC1: resolver holds valid CombatM05HeadPatchRules")
	_check(patched_svc.get_head_patches().get_bonus("warden", "warden_hold_the_line", "block") == 2,
		"AC1: browband projects +2 block bonus for warden Hold the Line")
	_check(patched_svc.get_wardrobe() == wardrobe, "AC1: get_wardrobe returns bound instance")
	_check(patched_svc.get_torn() == torn, "AC1: get_torn returns bound instance")
	_check(wardrobe.get_snapshot() == w_snap, "AC1: resolver does not mutate wardrobe ledger")
	_check(torn.read_state() == t_snap, "AC1: resolver does not mutate torn ledger")


func _test_head_all_ten_ac1() -> void:
	var ctx := _wardrobe_fixture()
	var wardrobe: RunPatchWardrobe = ctx["wardrobe"]
	var torn: RunTornMending = ctx["torn"]
	var sew: Dictionary = wardrobe.sew("reinforced_browband", "warden", "HEAD", "op-ac1-head-all", wardrobe.get_snapshot())
	_check(sew.get("ok") == true, "AC1: sew reinforced_browband onto Warden")
	var patched_svc := CombatWardenPoolBlockCards.new()
	_check(patched_svc.bind_patch_wardrobe(wardrobe, torn), "AC1: bind wardrobe to resolver")

	for spec in BROWBAND_CASES:
		var id: String = spec["id"]
		var party := _party()
		_check(party.apply_damage(2, 3) and party.gain_block(3, 4),
			id + ": prior wound and Block distinguish untouched state")
		var deck := _deck(id)
		_accepted_with(patched_svc, deck, party, id, spec["cost"], spec["target"],
			spec["delta"], "AC1 HEAD " + id)

	# Additional checks for AC1:
	# Patch Guard targeting Warden herself as ally: 8+2 = 10 to slot 1
	var party := _party()
	var deck := _deck("warden_patch_guard")
	_accepted_with(patched_svc, deck, party, "warden_patch_guard", 1, 1,
		[10, 0, 0], "AC1 Patch Guard targeting living Warden gets +2")

	# Patch Guard+ targeting Warden herself as ally: 11+2 = 13 to slot 1
	party = _party()
	deck = _deck("warden_patch_guard_plus")
	_accepted_with(patched_svc, deck, party, "warden_patch_guard_plus", 1, 1,
		[13, 0, 0], "AC1 Patch Guard+ targeting living Warden gets +2")

	# Patch Guard targeting ally Seamstress (slot 2): 8+2 = 10 to slot 2 (recipient is not patch wearer)
	party = _party()
	deck = _deck("warden_patch_guard")
	_accepted_with(patched_svc, deck, party, "warden_patch_guard", 1, 2,
		[0, 10, 0], "AC1 Patch Guard targeting living Seamstress gets +2 on recipient")

	# Hold the Line with downed Seamstress (slot 2): excludes downed hero, 5+2=7 for Warden, 2 for Tinker
	party = _party()
	_check(party.apply_damage(2, 30) and party.is_downed(2), "AC1 Seamstress downed")
	deck = _deck("warden_hold_the_line")
	_accepted_with(patched_svc, deck, party, "warden_hold_the_line", 1, 0,
		[7, 0, 2], "AC1 Hold the Line excludes downed hero while granting +2 to Warden")
	_check(party.get_hero(2).hp == 0, "AC1 Hold the Line keeps downed hero at 0 HP")

	# Bastion Quilt+ with downed Seamstress: 13 for living heroes, unaffected by browband
	party = _party()
	_check(party.apply_damage(2, 30) and party.is_downed(2), "AC1 Seamstress downed for Bastion+")
	deck = _deck("warden_bastion_quilt_plus")
	_accepted_with(patched_svc, deck, party, "warden_bastion_quilt_plus", 3, 0,
		[13, 0, 13], "AC1 Bastion Quilt+ unaffected by browband and skips downed hero")
	_check(party.get_hero(2).hp == 0, "AC1 Bastion+ does not revive downed ally")


func _test_stacked_head_arm_ac2() -> void:
	var ctx := _wardrobe_fixture()
	var wardrobe: RunPatchWardrobe = ctx["wardrobe"]
	var torn: RunTornMending = ctx["torn"]
	_check(wardrobe.sew("reinforced_browband", "warden", "HEAD", "op-ac2-sew-head",
		wardrobe.get_snapshot()).get("ok") == true, "AC2: sew reinforced_browband onto Warden HEAD")
	_check(wardrobe.sew("hemguard_cuff", "warden", "ARM", "op-ac2-sew-arm",
		wardrobe.get_snapshot()).get("ok") == true, "AC2: sew hemguard_cuff onto Warden ARM")
	var stacked_svc := CombatWardenPoolBlockCards.new()
	_check(stacked_svc.bind_patch_wardrobe(wardrobe, torn), "AC2: bind dual-patch wardrobe to resolver")

	for spec in STACKED_CASES:
		var id: String = spec["id"]
		var party := _party()
		_check(party.apply_damage(2, 3) and party.gain_block(3, 4),
			id + ": prior wound and Block distinguish untouched state")
		var deck := _deck(id)
		_accepted_with(stacked_svc, deck, party, id, spec["cost"], spec["target"],
			spec["delta"], "AC2 STACKED " + id)

	# Patch Guard targeting Warden herself as ally: 8+4 = 12 to slot 1
	var party := _party()
	var deck := _deck("warden_patch_guard")
	_accepted_with(stacked_svc, deck, party, "warden_patch_guard", 1, 1,
		[12, 0, 0], "AC2 Patch Guard targeting living Warden gets +4")

	# Patch Guard+ targeting living Seamstress (slot 2): 11+4 = 15 to slot 2 (recipient is not patch wearer)
	party = _party()
	deck = _deck("warden_patch_guard_plus")
	_accepted_with(stacked_svc, deck, party, "warden_patch_guard_plus", 1, 2,
		[0, 15, 0], "AC2 Patch Guard+ targeting living Seamstress gets +4 on recipient")

	# Hold the Line with downed Seamstress (slot 2): 5+4=9 for Warden, 2 for Tinker, Seamstress unchanged at 0 HP
	party = _party()
	_check(party.apply_damage(2, 30) and party.is_downed(2), "AC2 Seamstress downed for stacked")
	deck = _deck("warden_hold_the_line")
	_accepted_with(stacked_svc, deck, party, "warden_hold_the_line", 1, 0,
		[9, 0, 2], "AC2 Hold the Line excludes downed hero while granting +4 to Warden")
	_check(party.get_hero(2).hp == 0, "AC2 Hold the Line keeps downed hero at 0 HP")

	# Bastion Quilt with downed Seamstress: 10 for living heroes, unaffected by browband + cuff
	party = _party()
	_check(party.apply_damage(2, 30) and party.is_downed(2), "AC2 Seamstress downed for stacked Bastion")
	deck = _deck("warden_bastion_quilt")
	_accepted_with(stacked_svc, deck, party, "warden_bastion_quilt", 3, 0,
		[10, 0, 10], "AC2 Bastion Quilt unaffected by stacked patches and skips downed hero")

	# ARM-only preserves existing +2
	var arm_ctx := _wardrobe_fixture()
	var arm_w: RunPatchWardrobe = arm_ctx["wardrobe"]
	var arm_t: RunTornMending = arm_ctx["torn"]
	_check(arm_w.sew("hemguard_cuff", "warden", "ARM", "op-ac2-arm-only",
		arm_w.get_snapshot()).get("ok") == true, "AC2: sew ARM only")
	var arm_svc := CombatWardenPoolBlockCards.new()
	_check(arm_svc.bind_patch_wardrobe(arm_w, arm_t), "AC2: bind arm-only")
	party = _party()
	deck = _deck("warden_hold_the_line")
	_accepted_with(arm_svc, deck, party, "warden_hold_the_line", 1, 0,
		[7, 2, 2], "AC2: ARM-only preserves +2 bonus (5->7)")

	# Different wearer wearing reinforced_browband: grants no bonus to Warden
	var tinker_ctx := _wardrobe_fixture()
	var tinker_w: RunPatchWardrobe = tinker_ctx["wardrobe"]
	var tinker_t: RunTornMending = tinker_ctx["torn"]
	_check(tinker_w.sew("reinforced_browband", "tinker", "HEAD", "op-ac2-tinker-head",
		tinker_w.get_snapshot()).get("ok") == true, "AC2: sew browband to Tinker HEAD")
	var tinker_head_svc := CombatWardenPoolBlockCards.new()
	_check(tinker_head_svc.bind_patch_wardrobe(tinker_w, tinker_t), "AC2: bind Tinker browband")
	party = _party()
	deck = _deck("warden_hold_the_line")
	_accepted_with(tinker_head_svc, deck, party, "warden_hold_the_line", 1, 0,
		[5, 2, 2], "AC2: Hold the Line has no bonus when Tinker wears browband")
	party = _party()
	deck = _deck("warden_patch_guard")
	_accepted_with(tinker_head_svc, deck, party, "warden_patch_guard", 1, 3,
		[0, 0, 8], "AC2: Patch Guard has no bonus when Tinker wears browband")

	# Unrelated HEAD patch on Warden (bloodstitch_bonnet gives bleed bonus, not block):
	var bonnet_ctx := _wardrobe_fixture()
	var bonnet_w: RunPatchWardrobe = bonnet_ctx["wardrobe"]
	var bonnet_t: RunTornMending = bonnet_ctx["torn"]
	_check(bonnet_w.sew("bloodstitch_bonnet", "warden", "HEAD", "op-ac2-bonnet",
		bonnet_w.get_snapshot()).get("ok") == true, "AC2: sew bonnet to Warden HEAD")
	var bonnet_svc := CombatWardenPoolBlockCards.new()
	_check(bonnet_svc.bind_patch_wardrobe(bonnet_w, bonnet_t), "AC2: bind bonnet")
	party = _party()
	deck = _deck("warden_hold_the_line")
	_accepted_with(bonnet_svc, deck, party, "warden_hold_the_line", 1, 0,
		[5, 2, 2], "AC2: Hold the Line has no bonus when Warden wears bloodstitch_bonnet")
	party = _party()
	deck = _deck("warden_iron_hem")
	_accepted_with(bonnet_svc, deck, party, "warden_iron_hem", 2, 0,
		[14, 0, 0], "AC2: Iron Hem has no bonus when Warden wears bloodstitch_bonnet")

	# Unrelated HEAD patch + unrelated ARM patch on Warden:
	_check(bonnet_w.sew("pincushion_arm", "warden", "ARM", "op-ac2-bonnet-pin",
		bonnet_w.get_snapshot()).get("ok") == true, "AC2: sew pincushion to Warden ARM")
	var dual_unrelated_svc := CombatWardenPoolBlockCards.new()
	_check(dual_unrelated_svc.bind_patch_wardrobe(bonnet_w, bonnet_t), "AC2: bind dual unrelated")
	party = _party()
	deck = _deck("warden_hold_the_line")
	_accepted_with(dual_unrelated_svc, deck, party, "warden_hold_the_line", 1, 0,
		[5, 2, 2], "AC2: Hold the Line has no bonus when Warden wears unrelated HEAD+ARM")


func _test_head_negative_and_stale_ac3() -> void:
	# 1. Torn Warden in run torn ledger: browband and stacked bonuses are suppressed
	var torn_ctx := _wardrobe_fixture()
	var torn_ledger: RunTornMending = torn_ctx["torn"]
	var b_heroes: Array = _raw_heroes()
	var b_end_w: Array = _raw_heroes()
	b_end_w[0]["hp"] = 0 # Warden drops to 0 HP (torn) in run ledger
	_check(torn_ledger.observe_battle_end("node-warden-torn-head", b_heroes, b_end_w).get("ok") == true,
		"AC3: battle end observed: Warden torn")
	var torn_w: RunPatchWardrobe = torn_ctx["wardrobe"]
	_refresh_wardrobe_torn(torn_w, torn_ledger)
	_check(torn_w.sew("reinforced_browband", "warden", "HEAD", "op-torn-head",
		torn_w.get_snapshot()).get("ok") == true, "AC3: sew browband on torn Warden")
	_check(torn_w.sew("hemguard_cuff", "warden", "ARM", "op-torn-arm",
		torn_w.get_snapshot()).get("ok") == true, "AC3: sew cuff on torn Warden")
	var torn_svc := CombatWardenPoolBlockCards.new()
	_check(torn_svc.bind_patch_wardrobe(torn_w, torn_ledger), "AC3: bind torn ledger with dual patches")
	var party := _party() # living combat party
	var deck := _deck("warden_hold_the_line")
	_accepted_with(torn_svc, deck, party, "warden_hold_the_line", 1, 0,
		[5, 2, 2], "AC3: torn Warden in ledger suppresses browband and cuff bonuses")

	# 2. Downed Warden in combat party: rejected
	var valid_ctx := _wardrobe_fixture()
	var val_w: RunPatchWardrobe = valid_ctx["wardrobe"]
	var val_t: RunTornMending = valid_ctx["torn"]
	_check(val_w.sew("reinforced_browband", "warden", "HEAD", "op-val-head",
		val_w.get_snapshot()).get("ok") == true, "AC3: sew browband")
	var head_svc := CombatWardenPoolBlockCards.new()
	_check(head_svc.bind_patch_wardrobe(val_w, val_t), "AC3: bind valid browband")
	party = _party()
	_check(party.apply_damage(1, 40) and party.is_downed(1), "AC3: Warden downed in combat")
	_rejected_with(head_svc, _deck("warden_quick_darn"), party,
		"warden_quick_darn", 0, "AC3: downed Warden in combat cannot play with browband")

	# 3. Stale binding by wardrobe replacement / re-sew:
	var replace_ctx := _wardrobe_fixture()
	var rep_w: RunPatchWardrobe = replace_ctx["wardrobe"]
	var rep_t: RunTornMending = replace_ctx["torn"]
	_check(rep_w.sew("reinforced_browband", "warden", "HEAD", "op-rep-head",
		rep_w.get_snapshot()).get("ok") == true, "AC3: initial sew browband")
	var stale_svc := CombatWardenPoolBlockCards.new()
	_check(stale_svc.bind_patch_wardrobe(rep_w, rep_t), "AC3: bind initial browband")
	# Mutate wardrobe by replacing browband with bloodstitch_bonnet:
	_check(rep_w.sew("bloodstitch_bonnet", "warden", "HEAD", "op-rep-bonnet",
		rep_w.get_snapshot()).get("ok") == true, "AC3: replacement executed on HEAD")
	_check(not stale_svc.is_patch_binding_valid(), "AC3: binding is stale after HEAD replacement")
	party = _party()
	deck = _deck("warden_hold_the_line")
	_rejected_with(stale_svc, deck, party, "warden_hold_the_line", 0,
		"AC3: stale HEAD binding rejects play")
	# Rebind after replacement:
	_check(stale_svc.bind_patch_wardrobe(rep_w, rep_t), "AC3: rebind after HEAD replace")
	_check(stale_svc.is_patch_binding_valid(), "AC3: valid after HEAD rebind")
	_accepted_with(stale_svc, deck, party, "warden_hold_the_line", 1, 0,
		[5, 2, 2], "AC3: play succeeds after rebind with new HEAD patch (bloodstitch_bonnet -> unboosted Block)")

	# 4. Stale binding by torn ledger mutation:
	var torn_mut_ctx := _wardrobe_fixture()
	var tm_w: RunPatchWardrobe = torn_mut_ctx["wardrobe"]
	var tm_t: RunTornMending = torn_mut_ctx["torn"]
	_check(tm_w.sew("reinforced_browband", "warden", "HEAD", "op-tm-head",
		tm_w.get_snapshot()).get("ok") == true, "AC3: sew browband for torn mutation test")
	var tm_svc := CombatWardenPoolBlockCards.new()
	_check(tm_svc.bind_patch_wardrobe(tm_w, tm_t), "AC3: bind tm_svc")
	# Legitimate torn ledger mutation:
	var b_heroes_tm: Array = _raw_heroes()
	var b_end: Array = _raw_heroes()
	b_end[1]["hp"] = 0 # Seamstress torn
	_check(tm_t.observe_battle_end("node-mut-head", b_heroes_tm, b_end).get("ok") == true,
		"AC3: battle end observed in torn ledger for HEAD")
	_check(not tm_svc.is_patch_binding_valid(), "AC3: binding stale after torn ledger mutation")
	party = _party()
	deck = _deck("warden_hold_the_line")
	_rejected_with(tm_svc, deck, party, "warden_hold_the_line", 0,
		"AC3: stale binding from torn ledger rejects play with HEAD patch")
	# Refresh wardrobe and rebind after torn ledger change:
	_refresh_wardrobe_torn(tm_w, tm_t)
	_check(tm_svc.bind_patch_wardrobe(tm_w, tm_t), "AC3: rebind after torn change for HEAD")
	party = _party()
	deck = _deck("warden_hold_the_line")
	_accepted_with(tm_svc, deck, party, "warden_hold_the_line", 1, 0,
		[7, 2, 2], "AC3: play succeeds after rebind with browband bonus")
	var downed_p := _party()
	_check(downed_p.apply_damage(2, 30) and downed_p.is_downed(2), "AC3: Seamstress downed in combat party")
	_accepted_with(tm_svc, _deck("warden_hold_the_line"), downed_p, "warden_hold_the_line", 1, 0,
		[7, 0, 2], "AC3: play with downed ally in party excludes downed hero from block")

	# 5. Overflow preflight with HEAD bonus (+2) and stacked (+4):
	var ov_head_party := _party()
	_check(ov_head_party.gain_block(1, CombatParty.MAX_INT - 5), "AC3: overflow fixture for HEAD")
	_rejected_with(head_svc, _deck("warden_hold_the_line"), ov_head_party,
		"warden_hold_the_line", 0, "AC3: recipient would overflow with browband bonus (5+2=7 > 5 remaining)")

	# Stacked overflow preflight (+4):
	var stacked_ctx := _wardrobe_fixture()
	var stk_w: RunPatchWardrobe = stacked_ctx["wardrobe"]
	var stk_t: RunTornMending = stacked_ctx["torn"]
	_check(stk_w.sew("reinforced_browband", "warden", "HEAD", "op-stk-ov-head",
		stk_w.get_snapshot()).get("ok") == true, "AC3: sew browband for overflow")
	_check(stk_w.sew("hemguard_cuff", "warden", "ARM", "op-stk-ov-arm",
		stk_w.get_snapshot()).get("ok") == true, "AC3: sew cuff for overflow")
	var stk_svc := CombatWardenPoolBlockCards.new()
	_check(stk_svc.bind_patch_wardrobe(stk_w, stk_t), "AC3: bind stk_svc")
	var ov_stk_party := _party()
	_check(ov_stk_party.gain_block(1, CombatParty.MAX_INT - 7), "AC3: overflow fixture for stacked")
	_rejected_with(stk_svc, _deck("warden_hold_the_line"), ov_stk_party,
		"warden_hold_the_line", 0, "AC3: recipient would overflow with stacked bonus (5+4=9 > 7 remaining)")
	var ov_target_party := _party()
	_check(ov_target_party.gain_block(3, CombatParty.MAX_INT - 10), "AC3: overflow fixture for target")
	_rejected_with(stk_svc, _deck("warden_patch_guard"), ov_target_party,
		"warden_patch_guard", 3, "AC3: selected ally would overflow with stacked bonus (8+4=12 > 10 remaining)")

	# 6. Seeded replay with HEAD patch and stacked patches:
	var left_p := _party()
	var right_p := _party()
	var left_d := _deck("warden_hold_the_line_plus", 8812)
	var right_d := _deck("warden_hold_the_line_plus", 8812)
	_accepted_with(stk_svc, left_d, left_p, "warden_hold_the_line_plus", 1, 0,
		[11, 3, 3], "AC3: seeded replay left stacked")
	_accepted_with(stk_svc, right_d, right_p, "warden_hold_the_line_plus", 1, 0,
		[11, 3, 3], "AC3: seeded replay right stacked")
	_check(_snapshot(left_d, left_p) == _snapshot(right_d, right_p),
		"AC3: seeded replay matches complete party, piles and RNG state with stacked patches")
