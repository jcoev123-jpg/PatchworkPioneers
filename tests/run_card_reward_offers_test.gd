extends SceneTree
## Headless seeded Fight rewards: real StarterCards, actual starter party/deck,
## independent RNG oracle, fail-closed validation and one-time choice claims.

var failures: Array[String] = []
var checks: int = 0
const SEED: int = 413021


func _initialize() -> void:
	var party := _load_party()
	var deck := _load_deck()
	var catalog := StarterCards.new()
	var candidates: Array[String] = catalog.get_all_card_ids()
	_check(party.size() == 3 and party.has("warden") and party.has("seamstress") and party.has("tinker"),
		"real starter party contains the three distinct active heroes")
	_check(deck.size() == 12, "authored starter deck has 12 copies")
	_check(candidates.size() >= 3, "actual StarterCards has at least three authored cards")
	if party.size() == 3 and deck.size() == 12 and candidates.size() >= 3:
		_test_seeded_offers(party, candidates, catalog)
		_test_rejections(party, candidates, deck, catalog)
		_test_choice(party, candidates, deck, catalog)
	else:
		_check(false, "preconditions for non-vacuous reward tests failed")
	if failures.is_empty():
		print("run_card_reward_offers_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_card_reward_offers_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


func _load_party() -> Array[String]:
	var result: Array[String] = []
	var file := FileAccess.open("res://data/heroes/starter_party.json", FileAccess.READ)
	_check(file != null, "starter_party.json opened")
	if file == null:
		return result
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	_check(data is Array, "starter party is JSON array")
	if data is Array:
		for hero in data:
			if hero is Dictionary and hero.get("id") is String:
				result.append(hero["id"])
	return result


func _load_deck() -> Array[String]:
	var result: Array[String] = []
	var file := FileAccess.open("res://data/cards/starter_deck.json", FileAccess.READ)
	_check(file != null, "starter_deck.json opened")
	if file == null:
		return result
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	_check(data is Array, "starter deck is JSON array")
	if data is Array:
		for id in data:
			if id is String:
				result.append(id)
	return result


func _catalog_snapshot(catalog: StarterCards) -> Dictionary:
	var result := {}
	for card_id in catalog.get_all_card_ids():
		result[card_id] = catalog.get_definition(card_id)
	return result


func _rng(seed_value: int = SEED) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _offer_ids(offers: Array) -> Array[String]:
	var ids: Array[String] = []
	for offer in offers:
		if offer is Dictionary and offer.get("id") is String:
			ids.append(offer["id"])
	return ids


func _oracle(catalog: StarterCards, party: Array[String], candidates: Array[String], rng: RandomNumberGenerator) -> Array:
	var pool: Array[String] = []
	for id in candidates:
		if party.has(catalog.get_definition(id).get("owner", "")):
			pool.append(id)
	pool.sort()
	var result: Array = []
	for pick in range(3):
		var index: int = rng.randi_range(0, pool.size() - 1)
		var id: String = pool[index]
		pool.remove_at(index)
		result.append({"id": id, "owner": catalog.get_definition(id)["owner"]})
	return result


func _test_seeded_offers(party: Array[String], candidates: Array[String], catalog: StarterCards) -> void:
	var catalog_before := _catalog_snapshot(catalog)
	var party_before := party.duplicate(true)
	var pool_before := candidates.duplicate(true)
	var shuffled_pool := candidates.duplicate()
	shuffled_pool.reverse()
	var run_rng := _rng()
	var reorder_rng := _rng()
	var oracle_rng := _rng()

	# Global RNG is not a source of random Fight rewards.
	seed(76123)
	var global_expected := randi()
	seed(76123)
	var expected: Array = _oracle(catalog, party, candidates, oracle_rng)
	var generated: Dictionary = RunCardRewardOffers.generate(run_rng, party, candidates)
	var reordered: Dictionary = RunCardRewardOffers.generate(reorder_rng, party, shuffled_pool)
	_check(randi() == global_expected, "generator never touches global RNG")
	_check(generated.get("ok", false) == true, "valid pool generates")
	_check(reordered.get("ok", false) == true, "reordered pool generates")
	var offers: Array = generated.get("offers", [])
	_check(offers.size() == 3, "exactly three offers")
	_check(offers == expected, "offers match independently drawn three-index RNG oracle")
	_check(offers == reordered.get("offers", []), "reordered candidate pool produces same offers")
	_check(run_rng.state == reorder_rng.state and run_rng.state == oracle_rng.state,
		"same seed, reordered pool and oracle leave identical RNG state")
	_check(run_rng.randi() == oracle_rng.randi(), "next RNG draw matches oracle")
	_check(party == party_before and candidates == pool_before,
		"ordered caller party and pool remain unchanged")
	_check(catalog_before == _catalog_snapshot(catalog), "whole authored catalog remains untouched")
	var ids: Array[String] = _offer_ids(offers)
	_check(ids.size() == 3 and ids[0] != ids[1] and ids[0] != ids[2] and ids[1] != ids[2],
		"all three IDs distinct")
	for offer in offers:
		var id = offer.get("id", "")
		var definition: Dictionary = catalog.get_definition(id) if id is String else {}
		_check(not definition.is_empty(), "offered card exists in authored catalog")
		_check(offer.get("owner") == definition.get("owner") and party.has(offer.get("owner")),
			"offer uses actual catalog owner in the party: " + str(id))
		_check(offer.size() == 2 and offer.has("id") and offer.has("owner"),
			"offer contains only copied id and owner")

	# When the catalog grows a new hero, explicitly prove the valid outside-party
	# entry can be supplied but is excluded. Never invent an unauthored ID.
	var outsiders: Array[String] = []
	for id in candidates:
		if not party.has(catalog.get_definition(id).get("owner", "")):
			outsiders.append(id)
	if not outsiders.is_empty():
		var with_outside := candidates.duplicate()
		var outside_rng := _rng()
		var filtered := RunCardRewardOffers.generate(outside_rng, party, with_outside)
		_check(filtered.get("ok", false), "mixed-party catalog pool is accepted")
		for offered in filtered.get("offers", []):
			_check(not outsiders.has(offered.get("id")), "valid outside-party card excluded")
	else:
		_check(true, "catalog has no outside-party cards to inject; do not invent one")

	# Caller can corrupt returned dictionaries without touching prior inputs
	# or a separate generated result.
	offers[0]["id"] = "__modified_result__"
	offers.append({"id": "__extra__", "owner": "warden"})
	_check(generated["offers"] != reordered["offers"], "mutated result detached from another call")
	_check(reordered["offers"] == expected, "independent offer snapshots unaffected")
	_check(party == party_before and candidates == pool_before and catalog_before == _catalog_snapshot(catalog),
		"returned mutation cannot alter caller inputs or definitions")


func _reject(label: String, party_input: Variant, pool_input: Variant,
		catalog: StarterCards, base_deck: Array[String], rng_input: Variant = null) -> void:
	var local_rng = rng_input
	if local_rng == null:
		local_rng = _rng(56822)
	var state_before: int = local_rng.state if local_rng is RandomNumberGenerator else -1
	var party_before = party_input.duplicate(true) if party_input is Array else party_input
	var pool_before = pool_input.duplicate(true) if pool_input is Array else pool_input
	var catalog_before := _catalog_snapshot(catalog)
	var deck_before := base_deck.duplicate(true)
	var result: Dictionary = RunCardRewardOffers.generate(local_rng, party_input, pool_input)
	_check(result.get("ok") == false, label + ": rejects")
	_check(result.get("offers", ["bad"]).is_empty(), label + ": empty offers")
	if local_rng is RandomNumberGenerator:
		_check(local_rng.state == state_before, label + ": no RNG consumption")
	_check(party_input == party_before and pool_input == pool_before,
		label + ": full ordered inputs unchanged")
	_check(base_deck == deck_before and catalog_before == _catalog_snapshot(catalog),
		label + ": no deck/catalog mutation")


func _test_rejections(party: Array[String], candidates: Array[String],
		deck: Array[String], catalog: StarterCards) -> void:
	var three: Array = candidates.slice(0, 3)
	var null_rng_result: Dictionary = RunCardRewardOffers.generate(null, party, candidates)
	_check(not null_rng_result.get("ok", true) and null_rng_result.get("offers", ["bad"]).is_empty(),
		"null RNG rejected with empty offers")
	_reject("wrong party count", party.slice(0, 2), candidates, catalog, deck)
	_reject("duplicate party", [party[0], party[0], party[2]], candidates, catalog, deck)
	_reject("empty party id", [party[0], "", party[2]], candidates, catalog, deck)
	_reject("numeric party id", [party[0], 17, party[2]], candidates, catalog, deck)
	_reject("unknown party id", [party[0], party[1], "__unknown_hero__"], candidates, catalog, deck)
	_reject("null party list", null, candidates, catalog, deck)
	_reject("null candidate list", party, null, catalog, deck)
	_reject("numeric candidate", party, three + [127], catalog, deck)
	_reject("empty candidate", party, three + [""], catalog, deck)
	_reject("unknown candidate", party, three + ["__unknown_card__"], catalog, deck)
	_reject("duplicate candidate", party, three + [three[0]], catalog, deck)
	_reject("insufficient eligible candidates", party, three.slice(0, 2), catalog, deck)
	_reject("empty pool", party, [], catalog, deck)

	# Wrong-type RNG must reject, too; explicitly check the supplied run RNG
	# is never involved and the global RNG isn't silently consumed.
	var original_rng := _rng(56822)
	var state := original_rng.state
	var wrong_rng: Variant = RefCounted.new()
	var rejected: Dictionary = RunCardRewardOffers.generate(wrong_rng, party, candidates)
	_check(not rejected.get("ok", true) and rejected.get("offers", ["bad"]).is_empty(),
		"non-RNG object is rejected")
	_check(original_rng.state == state, "wrong-type RNG does not alter independent run RNG")
	seed(3819)
	var expected_global := randi()
	seed(3819)
	RunCardRewardOffers.generate(null, party, candidates)
	RunCardRewardOffers.generate(_rng(), party, three + ["__bad__"])
	_check(randi() == expected_global, "rejection paths do not consume global RNG")


func _test_choice(party: Array[String], candidates: Array[String],
		deck: Array[String], catalog: StarterCards) -> void:
	var rng_a := _rng(99172)
	var rng_b := _rng(99172)
	var factory_a := RunCardRewardChoice.from_seeded_pool(rng_a, party, candidates)
	var factory_b := RunCardRewardChoice.from_seeded_pool(rng_b, party, candidates)
	_check(factory_a != null and factory_b != null, "factories yield choice objects")
	if factory_a == null or factory_b == null:
		return
	_check(factory_a.is_valid() and factory_b.is_valid(), "seeded factories yield valid choices")
	_check(factory_a.has_method("get_offers"), "copied offer getter exists")
	var offered: Array = factory_a.get_offers()
	var replay: Array = factory_b.get_offers()
	_check(offered.size() == 3 and replay.size() == 3, "factory stores three copied offers")
	_check(offered == replay and rng_a.state == rng_b.state, "factory same-seed offers and final RNG state replay")
	var ids := _offer_ids(offered)
	for item in offered:
		var card_id: String = item.get("id", "")
		_check(catalog.has_card(card_id) and party.has(item.get("owner")),
			"factory offers authored party card: " + card_id)
		_check(catalog.get_definition(card_id).get("owner") == item.get("owner"),
			"factory offer matches catalog owner")

	var stale_snapshot: Array = factory_a.get_offers()
	offered[0]["id"] = "__caller_mutation__"
	offered[1]["owner"] = "outsider"
	offered.clear()
	_check(factory_a.get_offers() == stale_snapshot, "deep copy protects service from mutated getter")
	var second_snapshot := factory_a.get_offers()
	second_snapshot[0]["owner"] = "bad_owner"
	_check(factory_a.get_offers() == stale_snapshot, "each getter call is a new deep copy")

	# Construct separate fresh services to claim any of the three presented IDs.
	for id in ids:
		var attempt := RunCardRewardChoice.from_seeded_pool(_rng(99172), party, candidates)
		_check(attempt.is_valid() and _offer_ids(attempt.get_offers()).has(id),
			"fresh seeded choice contains selected real ID " + id)
		var input_deck := deck.duplicate()
		var expected_deck := deck.duplicate()
		expected_deck.append(id)
		var result: Dictionary = attempt.claim(input_deck, id)
		_check(result.get("ok", false) and not result.get("skipped", true)
			and result.get("selected_id") == id, "selected card claim succeeds: " + id)
		_check(result.get("deck", []) == expected_deck, "exact deck prefix plus one card: " + id)
		_check(input_deck == deck and deck.size() == 12, "source starter deck untouched: " + id)
		_check(attempt.is_claimed() and not attempt.is_valid(), "successful claim latches: " + id)
		var repeated: Dictionary = attempt.claim(input_deck, id)
		_check(not repeated.get("ok", true) and repeated.get("deck", []) == deck,
			"repeated claim cannot change deck: " + id)
		_check(not attempt.claim(input_deck, "").get("ok", true),
			"skip after a selection is rejected: " + id)
		_check(not attempt.claim(input_deck, "__foreign__").get("ok", true),
			"foreign claim after latch rejected: " + id)

	var skip_choice := RunCardRewardChoice.from_seeded_pool(_rng(99172), party, candidates)
	var skipped: Dictionary = skip_choice.claim(deck, "")
	_check(skipped.get("ok", false) and skipped.get("skipped", false),
		"skip is a successful claim")
	_check(skipped.get("deck", []) == deck and deck.size() == 12,
		"skip leaves starter deck untouched")
	_check(skip_choice.is_claimed() and not skip_choice.claim(deck, ids[0]).get("ok", true),
		"skip latches and prevents later selection")

	var retry_choice := RunCardRewardChoice.from_seeded_pool(_rng(99172), party, candidates)
	var invalid: Dictionary = retry_choice.claim(deck, "__foreign_reward__")
	_check(not invalid.get("ok", true) and invalid.get("deck", []) == deck
		and not retry_choice.is_claimed(), "foreign offer rejected without consuming claim")
	var not_offered := ""
	for candidate in candidates:
		if not ids.has(candidate):
			not_offered = candidate
			break
	if not_offered.is_empty():
		var stale: Dictionary = retry_choice.claim(deck, not_offered)
		_check(not stale.get("ok", true) and stale.get("deck", []) == deck
			and not retry_choice.is_claimed(), "stale catalog ID not present in offer rejected")
	var valid_after: Dictionary = retry_choice.claim(deck, ids[0])
	_check(valid_after.get("ok", false), "valid choice succeeds after rejected selections")
	_check(valid_after.get("deck", []).size() == deck.size() + 1, "one copy added after bad selection")
	_check(factory_a.get_offers() == stale_snapshot, "snapshots remain unchanged after separate claims")
	_check(factory_b.get_offers() == replay, "independent factory state unchanged")
	_check(catalog.get_definition(ids[0]).get("owner") == stale_snapshot[0].get("owner"),
		"authored catalog and chosen service agree after mutation attempts")

	var bad_pool: Array = candidates.duplicate()
	bad_pool.append(candidates[0])
	var failed_rng := _rng(99172)
	var before_state := failed_rng.state
	var failed_factory := RunCardRewardChoice.from_seeded_pool(failed_rng, party, bad_pool)
	_check(failed_factory != null and not failed_factory.is_valid(), "malformed pool makes unclaimable factory")
	_check(failed_factory.get_offers().is_empty(), "invalid factory has no displayed offers")
	_check(not failed_factory.claim(deck, ids[0]).get("ok", true),
		"invalid factory cannot claim")
	_check(failed_rng.state == before_state and deck.size() == 12,
		"failed factory consumes no RNG and cannot alter starter deck")

	# Mutate original arrays *after* factory construction; no retrospective
	# changes to its offers or party eligibility may be possible.
	var mutable_party := party.duplicate()
	var mutable_pool := candidates.duplicate()
	var independent := RunCardRewardChoice.from_seeded_pool(_rng(99172), mutable_party, mutable_pool)
	var original_shown := independent.get_offers()
	mutable_party.clear()
	mutable_pool.clear()
	_check(independent.is_valid() and independent.get_offers() == original_shown,
		"factory owns copies of caller arrays and offered dictionaries")
