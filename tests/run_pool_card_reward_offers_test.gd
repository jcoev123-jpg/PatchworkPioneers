extends SceneTree
## Headless test for RunPoolCardRewardOffers (D2-1 rarity-weighted card reward offers).
## Tests base pool selection, deterministic weighted oracle replay, sparse/depleted tiers,
## and fail-closed validation. Exits 0 on pass and 1 on failure.

var failures: Array[String] = []
var checks: int = 0
const TEST_SEED: int = 413021


func _initialize() -> void:
	_test_fixtures_and_party_filtering()
	_test_weighted_oracle_replay()
	_test_depletion_and_sparse_tiers()
	_test_fail_closed_rejections()
	_test_authored_candidate_aggregation()
	_test_authored_pool_roll()
	_test_v3_pools()
	_test_v3_seamstress_living_admission()

	if failures.is_empty():
		print("run_pool_card_reward_offers_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("run_pool_card_reward_offers_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


func _test_v3_pools() -> void:
	var candidates := RunPoolCardRewardOffers.get_authored_base_candidates()
	var before := candidates.duplicate(true)
	for pool in [V3SeamstressPoolCards.new(), LanternMonkPoolCards.new(), RagDuelistPoolCards.new(), ScarecrowPoolCards.new(),
		YarnRangerPoolCards.new(), ButtonGolemPoolCards.new()]:
		var owner := ""
		for id in pool.get_base_ids():
			var definition: Dictionary = pool.get_definition(id)
			owner = definition.owner
			var required := {"id": id, "owner": owner, "rarity": definition.rarity}
			_check(candidates.count(required) == 1, "required V3 base candidate exactly once: " + id)
			_check(RunPoolCardRewardOffers.resolve_reward_definition(id) == definition,
				"V3 reward resolves full authored metadata: " + id)
			_check(RunRestStitchCards.resolve_card_definition(id) == definition,
				"V3 base stays legal in run/Rest ledger: " + id)
			var plus: String = pool.get_upgrade_id(id)
			_check(not plus.is_empty() and RunPoolCardRewardOffers.resolve_reward_definition(plus).is_empty(),
				"V3 pool upgrade never resolves as reward: " + plus)
			_check(RunRestStitchCards.resolve_card_definition(plus) == pool.get_definition(plus),
				"authored V3 pool upgrade remains legal earned deck card: " + plus)
		var party: Array[String] = [owner, "warden", "tinker"]
		var rng := _rng()
		var oracle_rng := _rng()
		var result := RunPoolCardRewardOffers.generate_from_authored_pools(rng, party)
		_check(result.ok and result.offers == _oracle(party, candidates, oracle_rng)
			and rng.state == oracle_rng.state, "V3 weighted sorted-pool oracle and exact RNG: " + owner)
		var living_rng := _rng()
		var living := RunPoolCardRewardOffers.generate_for_living_from_authored(living_rng, party, party)
		_check(living.ok and living.offers.size() == 3, "V3 living balanced reward is nonempty: " + owner)
		if living.ok:
			for i in range(3):
				_check(living.offers[i].owner == party[i], "living V3 offer preserves party order")
		var invalid := candidates.duplicate(true)
		invalid.append({"id": pool.get_upgrade_id(pool.get_base_ids()[0]), "owner": owner, "rarity": "common"})
		_assert_rejected("new V3 upgrade cannot enter candidate pool", _rng(), party, invalid)
		var admission := RunV3PartyAdmission.admit(party)
		_check(admission.ok and RunRestStitchCards.new(admission.deck, {}, 0).is_valid(),
			"V3 admitted four-per-owner starters all resolve in legal run ledger")
	_check(candidates == before, "V3 generation/resolution leaves authored candidates unchanged")


func _test_v3_seamstress_living_admission() -> void:
	var pool := V3SeamstressPoolCards.new()
	var candidates := RunPoolCardRewardOffers.get_authored_base_candidates()
	var reached := {}
	for seed_value in range(128):
		for party in [["warden", "seamstress", "tinker"], ["warden", "lantern_monk", "tinker"]]:
			for living in [party, ["warden", "tinker"]]:
				var rng := _rng(seed_value)
				var generated := RunPoolCardRewardOffers.generate_for_living_from_authored(rng, party, living)
				_check(generated.ok and generated.offers.size() == 3, "three seeded living-owner offers")
				for offer in generated.offers:
					_check(living.has(offer.owner) and not String(offer.id).ends_with("_plus"), "only living party owners and bases offered")
					if pool.has_card(offer.id):
						_check(party.has("seamstress") and living.has("seamstress"), "V3 Seamstress requires active living owner")
						reached[offer.id] = true
	for id in pool.get_base_ids():
		_check(reached.has(id), "each V3 Seamstress base reached through seeded living offers: " + id)
		var matches := 0
		for row in candidates:
			if row.id == id:
				matches += 1
		_check(matches == 1, "each V3 ID occurs exactly once regardless of record metadata")
	var rng := _rng()
	var state := rng.state
	var invalid := RunPoolCardRewardOffers.generate_for_living_from_authored(rng,
		["warden", "tinker", "lantern_monk"], ["seamstress"])
	_check(not invalid.ok and invalid.offers.is_empty() and rng.state == state,
		"nonparty Seamstress living request rejected before RNG")


func _rng(seed_value: int = TEST_SEED) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _named_fixtures() -> Array[Dictionary]:
	return [
		# Warden
		{"id": "warden_hold_the_line", "owner": "warden", "rarity": "common", "display_name": "Hold the Line"},
		{"id": "warden_draw_fire", "owner": "warden", "rarity": "uncommon", "display_name": "Draw Fire"},
		{"id": "warden_bastion_quilt", "owner": "warden", "rarity": "rare", "display_name": "Bastion Quilt"},
		# Seamstress
		{"id": "seamstress_running_stitch", "owner": "seamstress", "rarity": "common", "display_name": "Running Stitch"},
		{"id": "seamstress_hemorrhage_hem", "owner": "seamstress", "rarity": "uncommon", "display_name": "Hemorrhage Hem"},
		{"id": "seamstress_red_thread", "owner": "seamstress", "rarity": "rare", "display_name": "Red Thread"},
		# Tinker
		{"id": "tinker_rivet_shot", "owner": "tinker", "rarity": "common", "display_name": "Rivet Shot"},
		{"id": "tinker_overclock", "owner": "tinker", "rarity": "uncommon", "display_name": "Overclock"},
		{"id": "tinker_bobbin_cannon", "owner": "tinker", "rarity": "rare", "display_name": "Bobbin Cannon"},
		# Outside party hero
		{"id": "outsider_scout_shot", "owner": "fixture_nonparty", "rarity": "common", "display_name": "Scout Shot"},
		{"id": "outsider_snipe", "owner": "fixture_nonparty", "rarity": "rare", "display_name": "Snipe"}
	]


func _oracle(party: Array[String], candidates: Array[Dictionary], rng: RandomNumberGenerator) -> Array:
	var party_set: Dictionary = {}
	for pid: String in party:
		party_set[pid] = true

	var buckets: Dictionary = {
		"common": [],
		"uncommon": [],
		"rare": []
	}
	for cand: Dictionary in candidates:
		var owner: String = String(cand.get("owner", ""))
		var rarity: String = String(cand.get("rarity", ""))
		if party_set.has(owner) and buckets.has(rarity):
			(buckets[rarity] as Array).append(cand)

	var tier_order: Array[String] = ["common", "uncommon", "rare"]
	var tier_weights: Dictionary = {
		"common": 60,
		"uncommon": 30,
		"rare": 10
	}

	for tier: String in tier_order:
		var b: Array = buckets[tier]
		b.sort_custom(func(a: Dictionary, b_dict: Dictionary) -> bool:
			return String(a.get("id", "")) < String(b_dict.get("id", ""))
		)

	var result: Array = []
	for pick: int in range(3):
		var weight_sum: int = 0
		for tier: String in tier_order:
			var b: Array = buckets[tier]
			if not b.is_empty():
				weight_sum += int(tier_weights[tier])

		var roll: int = rng.randi_range(1, weight_sum)
		var chosen_tier: String = ""
		var accum: int = 0
		for tier: String in tier_order:
			var b: Array = buckets[tier]
			if b.is_empty():
				continue
			accum += int(tier_weights[tier])
			if roll <= accum:
				chosen_tier = tier
				break

		var chosen_b: Array = buckets[chosen_tier]
		var idx: int = rng.randi_range(0, chosen_b.size() - 1)
		var rec: Dictionary = chosen_b[idx]
		chosen_b.remove_at(idx)
		result.append({
			"id": String(rec["id"]),
			"owner": String(rec["owner"])
		})
	return result


## Test 1: Design v2 named fixtures, active party filtering, detachment, and no input mutation (AC1).
func _test_fixtures_and_party_filtering() -> void:
	var party: Array[String] = ["warden", "seamstress", "tinker"]
	var party_before: Array[String] = party.duplicate(true)
	var candidates: Array[Dictionary] = _named_fixtures()
	var candidates_before: Array[Dictionary] = candidates.duplicate(true)

	var rng: RandomNumberGenerator = _rng(TEST_SEED)
	var generated: Dictionary = RunPoolCardRewardOffers.generate(rng, party, candidates)

	_check(generated.get("ok", false) == true, "generation succeeds with valid named fixtures")
	var offers: Array = generated.get("offers", [])
	_check(offers.size() == 3, "returns exactly three offers")

	_check(party == party_before, "caller party array is not mutated")
	_check(candidates == candidates_before, "caller candidate descriptors are not mutated")

	var seen_ids: Dictionary = {}
	for offer_raw: Variant in offers:
		_check(offer_raw is Dictionary, "offer is a Dictionary")
		var offer: Dictionary = offer_raw
		var id: String = String(offer.get("id", ""))
		var owner: String = String(offer.get("owner", ""))

		_check(not id.is_empty(), "offer id is non-empty")
		_check(party.has(owner), "offer owner is in the active party: " + owner)
		_check(owner != "fixture_nonparty", "outside-party fixture is never offered")
		_check(not id.ends_with("_plus"), "offer is not an upgrade: " + id)
		_check(not seen_ids.has(id), "offer IDs are distinct: " + id)
		seen_ids[id] = true

		_check(offer.size() == 2 and offer.has("id") and offer.has("owner"),
			"offer dictionary contains only detached id and owner, no redundant rarity")

	# Detachment check: mutating returned result does not affect subsequent calls or original candidates
	offers[0]["id"] = "__mutated_id__"
	offers[0]["owner"] = "__mutated_owner__"
	offers.append({"id": "__extra__", "owner": "warden"})
	_check(candidates == candidates_before, "mutating returned offers does not alter original candidates")

	var fresh_gen: Dictionary = RunPoolCardRewardOffers.generate(_rng(TEST_SEED), party, candidates)
	var fresh_offers: Array = fresh_gen.get("offers", [])
	_check(fresh_offers[0]["id"] != "__mutated_id__", "new generation is detached from mutated previous result")


## Test 2: Two-draw-per-pick weighted oracle comparison and input order invariance (AC2).
func _test_weighted_oracle_replay() -> void:
	var party: Array[String] = ["warden", "seamstress", "tinker"]
	var candidates: Array[Dictionary] = _named_fixtures()

	var test_seeds: Array[int] = [TEST_SEED, 12345, 999999, 7, 54321]
	for s: int in test_seeds:
		var run_rng: RandomNumberGenerator = _rng(s)
		var oracle_rng: RandomNumberGenerator = _rng(s)
		var reorder_rng: RandomNumberGenerator = _rng(s)

		# Global RNG baseline
		seed(55443)
		var global_expected: int = randi()
		seed(55443)

		var expected: Array = _oracle(party, candidates, oracle_rng)
		var generated: Dictionary = RunPoolCardRewardOffers.generate(run_rng, party, candidates)

		_check(randi() == global_expected, "generation never touches global RNG (seed " + str(s) + ")")
		_check(generated.get("ok", false) == true, "generation succeeds (seed " + str(s) + ")")

		var offers: Array = generated.get("offers", [])
		_check(offers == expected, "offers match independent two-draw oracle (seed " + str(s) + ")")
		# Reversed candidate input ordering produces identical offers and RNG state
		var reversed_candidates: Array[Dictionary] = candidates.duplicate(true)
		reversed_candidates.reverse()
		var reordered: Dictionary = RunPoolCardRewardOffers.generate(reorder_rng, party, reversed_candidates)
		_check(reordered.get("offers", []) == expected,
			"reversed input produces identical offers (seed " + str(s) + ")")
		_check(run_rng.state == oracle_rng.state and run_rng.state == reorder_rng.state,
			"RNG state matches oracle and reordered input exactly after 6 draws (seed " + str(s) + ")")
		var oracle_next: int = oracle_rng.randi()
		_check(run_rng.randi() == oracle_next and reorder_rng.randi() == oracle_next,
			"subsequent RNG draw continuation matches oracle (seed " + str(s) + ")")


## Test 3: Rare depletion, single-tier and two-tier pools without replacement (AC3).
func _test_depletion_and_sparse_tiers() -> void:
	var party: Array[String] = ["warden", "seamstress", "tinker"]

	# 3a: Rare tier depletion: 1 rare, 1 uncommon, 2 common cards
	var depletable_pool: Array[Dictionary] = [
		{"id": "warden_bastion_quilt", "owner": "warden", "rarity": "rare"},
		{"id": "warden_draw_fire", "owner": "warden", "rarity": "uncommon"},
		{"id": "warden_hold_the_line", "owner": "warden", "rarity": "common"},
		{"id": "seamstress_running_stitch", "owner": "seamstress", "rarity": "common"}
	]

	# Find a seed where rare is chosen, verifying depletion reweights properly
	var tested_rare_depletion: bool = false
	for s: int in range(100):
		var oracle_rng: RandomNumberGenerator = _rng(s)
		var expected: Array = _oracle(party, depletable_pool, oracle_rng)
		var has_rare: bool = false
		for item: Dictionary in expected:
			if item["id"] == "warden_bastion_quilt":
				has_rare = true
				break
		if has_rare:
			var run_rng: RandomNumberGenerator = _rng(s)
			var gen: Dictionary = RunPoolCardRewardOffers.generate(run_rng, party, depletable_pool)
			_check(gen.get("ok", false) == true, "depletable pool succeeds")
			_check(gen.get("offers", []) == expected, "depletion matches oracle for seed " + str(s))
			_check(run_rng.state == oracle_rng.state, "depletion RNG state matches oracle for seed " + str(s))
			tested_rare_depletion = true
			break
	_check(tested_rare_depletion, "found and tested seed exercising rare tier depletion")

	# 3b: All-common pool: 4 common cards, 0 uncommon, 0 rare
	var all_common: Array[Dictionary] = [
		{"id": "c1", "owner": "warden", "rarity": "common"},
		{"id": "c2", "owner": "warden", "rarity": "common"},
		{"id": "c3", "owner": "seamstress", "rarity": "common"},
		{"id": "c4", "owner": "tinker", "rarity": "common"}
	]
	var ac_run_rng: RandomNumberGenerator = _rng(TEST_SEED)
	var ac_oracle_rng: RandomNumberGenerator = _rng(TEST_SEED)
	var ac_expected: Array = _oracle(party, all_common, ac_oracle_rng)
	var ac_gen: Dictionary = RunPoolCardRewardOffers.generate(ac_run_rng, party, all_common)
	_check(ac_gen.get("ok", false) == true, "all-common pool succeeds")
	var ac_offers: Array = ac_gen.get("offers", [])
	_check(ac_offers.size() == 3, "all-common pool offers 3 cards")
	_check(ac_offers == ac_expected, "all-common pool matches oracle (6 draws consumed)")
	_check(ac_run_rng.state == ac_oracle_rng.state, "all-common pool RNG state matches oracle")

	# 3c: Two-tier pool: common + rare (0 uncommon)
	var two_tier: Array[Dictionary] = [
		{"id": "c1", "owner": "warden", "rarity": "common"},
		{"id": "c2", "owner": "seamstress", "rarity": "common"},
		{"id": "r1", "owner": "tinker", "rarity": "rare"},
		{"id": "r2", "owner": "warden", "rarity": "rare"}
	]
	var tt_run_rng: RandomNumberGenerator = _rng(TEST_SEED)
	var tt_oracle_rng: RandomNumberGenerator = _rng(TEST_SEED)
	var tt_expected: Array = _oracle(party, two_tier, tt_oracle_rng)
	var tt_gen: Dictionary = RunPoolCardRewardOffers.generate(tt_run_rng, party, two_tier)
	_check(tt_gen.get("ok", false) == true, "two-tier pool succeeds")
	_check(tt_gen.get("offers", []) == tt_expected, "two-tier pool matches oracle")
	_check(tt_run_rng.state == tt_oracle_rng.state, "two-tier pool RNG state matches oracle")

	# 3d: Exactly 3 eligible cards across tiers (1 common, 1 uncommon, 1 rare)
	var exact_three: Array[Dictionary] = [
		{"id": "c1", "owner": "warden", "rarity": "common"},
		{"id": "u1", "owner": "seamstress", "rarity": "uncommon"},
		{"id": "r1", "owner": "tinker", "rarity": "rare"}
	]
	var e3_run_rng: RandomNumberGenerator = _rng(TEST_SEED)
	var e3_oracle_rng: RandomNumberGenerator = _rng(TEST_SEED)
	var e3_expected: Array = _oracle(party, exact_three, e3_oracle_rng)
	var e3_gen: Dictionary = RunPoolCardRewardOffers.generate(e3_run_rng, party, exact_three)
	_check(e3_gen.get("ok", false) == true, "exact-three pool succeeds")
	_check(e3_gen.get("offers", []) == e3_expected, "exact-three pool matches oracle")
	_check(e3_run_rng.state == e3_oracle_rng.state, "exact-three pool RNG state matches oracle")


## Helper to assert fail-closed rejection with zero RNG consumption and zero mutation.
func _assert_rejected(label: String, rng_val: Variant, party_val: Variant, candidates_val: Variant) -> void:
	var state_before: int = -1
	if rng_val is RandomNumberGenerator:
		state_before = rng_val.state

	var party_before: Variant = party_val.duplicate(true) if party_val is Array else party_val
	var candidates_before: Variant = candidates_val.duplicate(true) if candidates_val is Array else candidates_val

	seed(12345)
	var global_expected: int = randi()
	seed(12345)

	var result: Dictionary = RunPoolCardRewardOffers.generate(rng_val, party_val, candidates_val)

	_check(result.get("ok", true) == false, label + ": ok is false")
	_check((result.get("offers") as Array).is_empty(), label + ": offers is empty")

	if rng_val is RandomNumberGenerator:
		_check(rng_val.state == state_before, label + ": RNG state untouched")

	_check(randi() == global_expected, label + ": global RNG untouched")
	_check(party_val == party_before, label + ": party input untouched")
	_check(candidates_val == candidates_before, label + ": candidates input untouched")


## Test 4: Negative preflight rejection and fail-closed integrity (AC4).
func _test_fail_closed_rejections() -> void:
	var valid_party: Array[String] = ["warden", "seamstress", "tinker"]
	var valid_candidates: Array[Dictionary] = _named_fixtures()
	var test_rng: RandomNumberGenerator = _rng(TEST_SEED)

	# Invalid RNG
	_assert_rejected("null RNG", null, valid_party, valid_candidates)
	_assert_rejected("object instead of RNG", RefCounted.new(), valid_party, valid_candidates)

	# Invalid party
	_assert_rejected("null party", test_rng, null, valid_candidates)
	_assert_rejected("party of 2", test_rng, ["warden", "seamstress"], valid_candidates)
	_assert_rejected("party of 4", test_rng, ["warden", "seamstress", "tinker", "extra"], valid_candidates)
	_assert_rejected("duplicate party hero", test_rng, ["warden", "warden", "tinker"], valid_candidates)
	_assert_rejected("empty string hero", test_rng, ["warden", "", "tinker"], valid_candidates)
	_assert_rejected("non-string hero", test_rng, ["warden", 123, "tinker"], valid_candidates)

	# Invalid candidate collection
	_assert_rejected("null candidates", test_rng, valid_party, null)
	_assert_rejected("empty candidate array", test_rng, valid_party, [])
	_assert_rejected("non-dictionary candidate item", test_rng, valid_party, ["not_a_dict"])

	# Candidate item malformed shapes
	var missing_id: Array[Dictionary] = [
		{"owner": "warden", "rarity": "common"},
		{"id": "w2", "owner": "warden", "rarity": "common"},
		{"id": "w3", "owner": "warden", "rarity": "common"}
	]
	_assert_rejected("missing id", test_rng, valid_party, missing_id)

	var empty_id: Array[Dictionary] = [
		{"id": "", "owner": "warden", "rarity": "common"},
		{"id": "w2", "owner": "warden", "rarity": "common"},
		{"id": "w3", "owner": "warden", "rarity": "common"}
	]
	_assert_rejected("empty id", test_rng, valid_party, empty_id)

	var missing_owner: Array[Dictionary] = [
		{"id": "w1", "rarity": "common"},
		{"id": "w2", "owner": "warden", "rarity": "common"},
		{"id": "w3", "owner": "warden", "rarity": "common"}
	]
	_assert_rejected("missing owner", test_rng, valid_party, missing_owner)

	var empty_owner: Array[Dictionary] = [
		{"id": "w1", "owner": "", "rarity": "common"},
		{"id": "w2", "owner": "warden", "rarity": "common"},
		{"id": "w3", "owner": "warden", "rarity": "common"}
	]
	_assert_rejected("empty owner", test_rng, valid_party, empty_owner)

	var missing_rarity: Array[Dictionary] = [
		{"id": "w1", "owner": "warden"},
		{"id": "w2", "owner": "warden", "rarity": "common"},
		{"id": "w3", "owner": "warden", "rarity": "common"}
	]
	_assert_rejected("missing rarity", test_rng, valid_party, missing_rarity)

	var invalid_rarity: Array[Dictionary] = [
		{"id": "w1", "owner": "warden", "rarity": "legendary"},
		{"id": "w2", "owner": "warden", "rarity": "common"},
		{"id": "w3", "owner": "warden", "rarity": "common"}
	]
	_assert_rejected("unsupported rarity", test_rng, valid_party, invalid_rarity)

	# Upgraded candidate masquerading as base
	var upgraded_candidate: Array[Dictionary] = [
		{"id": "warden_hold_the_line_plus", "owner": "warden", "rarity": "common"},
		{"id": "w2", "owner": "warden", "rarity": "common"},
		{"id": "w3", "owner": "warden", "rarity": "common"}
	]
	_assert_rejected("upgraded candidate with _plus suffix", test_rng, valid_party, upgraded_candidate)

	# Duplicate candidate ID
	var duplicate_cand_id: Array[Dictionary] = [
		{"id": "w1", "owner": "warden", "rarity": "common"},
		{"id": "w1", "owner": "seamstress", "rarity": "common"},
		{"id": "w3", "owner": "tinker", "rarity": "common"}
	]
	_assert_rejected("duplicate candidate ID", test_rng, valid_party, duplicate_cand_id)

	# Malformed outside-party candidates are also validated and rejected
	var corrupt_outside_party: Array[Dictionary] = [
		{"id": "w1", "owner": "warden", "rarity": "common"},
		{"id": "w2", "owner": "seamstress", "rarity": "common"},
		{"id": "w3", "owner": "tinker", "rarity": "common"},
		{"id": "corrupt_outsider", "owner": "fixture_nonparty", "rarity": "mythic"}
	]
	_assert_rejected("corrupt outside-party candidate rarity", test_rng, valid_party, corrupt_outside_party)

	var upgraded_outsider: Array[Dictionary] = [
		{"id": "w1", "owner": "warden", "rarity": "common"},
		{"id": "w2", "owner": "seamstress", "rarity": "common"},
		{"id": "w3", "owner": "tinker", "rarity": "common"},
		{"id": "outsider_card_plus", "owner": "fixture_nonparty", "rarity": "common"}
	]
	_assert_rejected("upgraded outside-party candidate", test_rng, valid_party, upgraded_outsider)

	# Insufficient eligible party cards (< 3)
	var two_party_cards: Array[Dictionary] = [
		{"id": "w1", "owner": "warden", "rarity": "common"},
		{"id": "w2", "owner": "seamstress", "rarity": "common"}
	]
	_assert_rejected("only two party candidates", test_rng, valid_party, two_party_cards)

	var mostly_outsiders: Array[Dictionary] = [
		{"id": "w1", "owner": "warden", "rarity": "common"},
		{"id": "w2", "owner": "seamstress", "rarity": "common"},
		{"id": "o1", "owner": "fixture_nonparty", "rarity": "common"},
		{"id": "o2", "owner": "fixture_nonparty", "rarity": "common"},
		{"id": "o3", "owner": "fixture_nonparty", "rarity": "common"}
	]
	_assert_rejected("fewer than 3 eligible party cards despite 5 total candidates", test_rng, valid_party, mostly_outsiders)


## Authored catalog aggregation (AC1): every real base ID yields one faithful candidate.
func _test_authored_candidate_aggregation() -> void:
	var party: Array[String] = ["warden", "seamstress", "tinker"]
	var warden_catalog: WardenPoolCards = WardenPoolCards.new()
	var seamstress_catalog: SeamstressPoolCards = SeamstressPoolCards.new()
	var tinker_catalog: TinkerPoolCards = TinkerPoolCards.new()
	var starter_catalog: StarterCards = StarterCards.new()

	var candidates_before: Array[Dictionary] = RunPoolCardRewardOffers.get_authored_base_candidates()
	var catalog_ids_before: Array[String] = warden_catalog.get_base_ids()
	var seam_ids_before: Array[String] = seamstress_catalog.get_base_ids()
	var tinker_ids_before: Array[String] = tinker_catalog.get_pool_card_ids()

	# Each source base ID appears exactly once with matching owner/rarity.
	var seen: Dictionary = {}

	for base_id: String in warden_catalog.get_base_ids():
		var def: Dictionary = warden_catalog.get_definition(base_id)
		var matches: Array[Dictionary] = []
		for cand: Dictionary in RunPoolCardRewardOffers.get_authored_base_candidates():
			if String(cand.get("id", "")) == base_id:
				matches.append(cand)
		_check(matches.size() == 1, "warden base id appears exactly once: " + base_id)
		if matches.size() == 1:
			_check(String(matches[0].get("owner", "")) == String(def.get("owner", "")),
				"warden candidate owner matches definition: " + base_id)
			_check(String(matches[0].get("rarity", "")) == String(def.get("rarity", "")),
				"warden candidate rarity matches definition: " + base_id)
			_check(not String(matches[0].get("id", "")).ends_with("_plus"),
				"warden candidate is not an upgrade: " + base_id)
		_check(not seen.has(base_id), "no duplicate candidate id: " + base_id)
		seen[base_id] = true

	for base_id: String in seamstress_catalog.get_base_ids():
		var def: Dictionary = seamstress_catalog.get_definition(base_id)
		var matches: Array[Dictionary] = []
		for cand: Dictionary in RunPoolCardRewardOffers.get_authored_base_candidates():
			if String(cand.get("id", "")) == base_id:
				matches.append(cand)
		_check(matches.size() == 1, "seamstress base id appears exactly once: " + base_id)
		if matches.size() == 1:
			_check(String(matches[0].get("owner", "")) == String(def.get("owner", "")),
				"seamstress candidate owner matches definition: " + base_id)
			_check(String(matches[0].get("rarity", "")) == String(def.get("rarity", "")),
				"seamstress candidate rarity matches definition: " + base_id)
			_check(not String(matches[0].get("id", "")).ends_with("_plus"),
				"seamstress candidate is not an upgrade: " + base_id)
		_check(not seen.has(base_id), "no duplicate candidate id: " + base_id)
		seen[base_id] = true

	for base_id: String in tinker_catalog.get_pool_card_ids():
		var def: Dictionary = tinker_catalog.get_definition(base_id)
		var matches: Array[Dictionary] = []
		for cand: Dictionary in RunPoolCardRewardOffers.get_authored_base_candidates():
			if String(cand.get("id", "")) == base_id:
				matches.append(cand)
		_check(matches.size() == 1, "tinker base id appears exactly once: " + base_id)
		if matches.size() == 1:
			_check(String(matches[0].get("owner", "")) == String(def.get("owner", "")),
				"tinker candidate owner matches definition: " + base_id)
			_check(String(matches[0].get("rarity", "")) == String(def.get("rarity", "")),
				"tinker candidate rarity matches definition: " + base_id)
			_check(not String(matches[0].get("id", "")).ends_with("_plus"),
				"tinker candidate is not an upgrade: " + base_id)
		_check(not seen.has(base_id), "no duplicate candidate id: " + base_id)
		seen[base_id] = true

	# Upgrades excluded: no candidate id ends with _plus.
	for cand: Dictionary in RunPoolCardRewardOffers.get_authored_base_candidates():
		_check(not String(cand.get("id", "")).ends_with("_plus"),
			"no upgrade candidate: " + String(cand.get("id", "")))

	# Named spot checks.
	var named_expected: Dictionary = {
		"warden_hold_the_line": {"owner": "warden", "rarity": "common"},
		"warden_draw_fire": {"owner": "warden", "rarity": "uncommon"},
		"warden_bastion_quilt": {"owner": "warden", "rarity": "rare"},
		"seamstress_running_stitch": {"owner": "seamstress", "rarity": "common"},
		"seamstress_hemorrhage_hem": {"owner": "seamstress", "rarity": "uncommon"},
		"seamstress_red_thread": {"owner": "seamstress", "rarity": "rare"},
		"tinker_rivet_shot": {"owner": "tinker", "rarity": "common"},
		"tinker_overclock": {"owner": "tinker", "rarity": "uncommon"},
		"tinker_bobbin_cannon": {"owner": "tinker", "rarity": "rare"},
	}
	for id: String in named_expected:
		var found: bool = false
		for cand: Dictionary in RunPoolCardRewardOffers.get_authored_base_candidates():
			if String(cand.get("id", "")) == id:
				found = true
				var exp: Dictionary = named_expected[id]
				_check(String(cand.get("owner", "")) == String(exp["owner"]),
					"named candidate owner: " + id)
				_check(String(cand.get("rarity", "")) == String(exp["rarity"]),
					"named candidate rarity: " + id)
		_check(found, "named candidate present: " + id)

	# Source catalogs unchanged.
	_check(warden_catalog.get_base_ids() == catalog_ids_before, "warden base ids unchanged")
	_check(seamstress_catalog.get_base_ids() == seam_ids_before, "seamstress base ids unchanged")
	_check(tinker_catalog.get_pool_card_ids() == tinker_ids_before, "tinker pool ids unchanged")

	# Candidate list is detached: mutating returned array does not affect next call.
	var first_call: Array[Dictionary] = RunPoolCardRewardOffers.get_authored_base_candidates()
	var second_call: Array[Dictionary] = RunPoolCardRewardOffers.get_authored_base_candidates()
	if first_call.size() > 0:
		first_call[0]["id"] = "__mutated__"
	_check(second_call[0]["id"] != "__mutated__", "authored candidates are detached across calls")

	# Starter deck not mutated by catalog reads.
	var starter_before: Array[String] = starter_catalog.get_starting_deck()
	var _candidates: Array[Dictionary] = RunPoolCardRewardOffers.get_authored_base_candidates()
	var starter_after: Array[String] = starter_catalog.get_starting_deck()
	_check(starter_before == starter_after, "starter deck unchanged by authored candidate lookup")


## Authored pool roll delegates to generate() (AC2/AC3).
func _test_authored_pool_roll() -> void:
	var party: Array[String] = ["warden", "seamstress", "tinker"]

	# Compare adapter to direct generate() with same real candidates and seed.
	var candidates: Array[Dictionary] = RunPoolCardRewardOffers.get_authored_base_candidates()
	var rng_adapter: RandomNumberGenerator = _rng(TEST_SEED)
	var rng_direct: RandomNumberGenerator = _rng(TEST_SEED)
	var rng_oracle: RandomNumberGenerator = _rng(TEST_SEED)

	var adapter_result: Dictionary = RunPoolCardRewardOffers.generate_from_authored_pools(rng_adapter, party)
	var direct_result: Dictionary = RunPoolCardRewardOffers.generate(rng_direct, party, candidates)
	var oracle_expected: Array = _oracle(party, candidates, rng_oracle)

	_check(adapter_result.get("ok", false) == true, "authored adapter succeeds")
	_check(direct_result.get("ok", false) == true, "direct generate succeeds")
	_check(adapter_result.get("offers", []) == direct_result.get("offers", []),
		"adapter offers match direct generate offers")
	_check(adapter_result.get("offers", []) == oracle_expected,
		"authored adapter offers match oracle")
	_check(rng_adapter.state == rng_direct.state, "adapter and direct RNG state match")
	_check(rng_adapter.state == rng_oracle.state, "adapter and oracle RNG state match")

	# Six successful RNG draws consumed: verify continuation matches.
	var next_adapter: int = rng_adapter.randi()
	var next_direct: int = rng_direct.randi()
	var next_oracle: int = rng_oracle.randi()
	_check(next_adapter == next_direct and next_adapter == next_oracle,
		"post-roll RNG continuation matches (six draws)")

	# Offers are distinct party-owned base IDs.
	var seen_ids: Dictionary = {}
	for offer_raw: Variant in adapter_result.get("offers", []):
		var offer: Dictionary = offer_raw
		var id: String = String(offer.get("id", ""))
		var owner: String = String(offer.get("owner", ""))
		_check(party.has(owner), "adapter offer owner in party: " + owner)
		_check(not id.ends_with("_plus"), "adapter offer not upgrade: " + id)
		_check(not seen_ids.has(id), "adapter offer ids distinct: " + id)
		seen_ids[id] = true

	# Rejected input leaves RNG unchanged.
	var rng_reject: RandomNumberGenerator = _rng(TEST_SEED)
	var state_before: int = rng_reject.state
	var rejected: Dictionary = RunPoolCardRewardOffers.generate_from_authored_pools(rng_reject, ["warden", "seamstress"])
	_check(rejected.get("ok", true) == false, "rejected authored call ok is false")
	_check((rejected.get("offers") as Array).is_empty(), "rejected authored call offers empty")
	_check(rng_reject.state == state_before, "rejected authored call leaves RNG unchanged")

	# Aliases delegate.
	var rng_alias: RandomNumberGenerator = _rng(TEST_SEED)
	var alias_result: Dictionary = RunPoolCardRewardOffers.generate_from_pools(rng_alias, party)
	_check(alias_result.get("offers", []) == oracle_expected,
		"generate_from_pools alias matches oracle")

	# Catalogs unchanged after roll.
	var warden_catalog: WardenPoolCards = WardenPoolCards.new()
	var seamstress_catalog: SeamstressPoolCards = SeamstressPoolCards.new()
	var tinker_catalog: TinkerPoolCards = TinkerPoolCards.new()
	var warden_before: Array[String] = warden_catalog.get_base_ids()
	var seamstress_before: Array[String] = seamstress_catalog.get_base_ids()
	var tinker_before: Array[String] = tinker_catalog.get_pool_card_ids()
	var _roll: Dictionary = RunPoolCardRewardOffers.generate_from_authored_pools(_rng(TEST_SEED), party)
	_check(warden_catalog.get_base_ids() == warden_before, "warden catalog unchanged after roll")
	_check(seamstress_catalog.get_base_ids() == seamstress_before, "seamstress catalog unchanged after roll")
	_check(tinker_catalog.get_pool_card_ids() == tinker_before, "tinker catalog unchanged after roll")

	# Starter deck unchanged after roll.
	var starter: StarterCards = StarterCards.new()
	var starter_before: Array[String] = starter.get_starting_deck()
	var _roll2: Dictionary = RunPoolCardRewardOffers.generate_from_authored_pools(_rng(TEST_SEED), party)
	var starter_after: Array[String] = starter.get_starting_deck()
	_check(starter_before == starter_after, "starter deck unchanged after authored roll")
