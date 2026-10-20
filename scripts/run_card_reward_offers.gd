class_name RunCardRewardOffers
extends RefCounted
## Scene-free, seeded selection of three distinct authored post-Fight rewards.
## The caller owns the run RNG and provides the candidate catalog IDs.


## Fail closed before drawing from rng. A successful call consumes exactly
## three randi_range draws, sampling without replacement from sorted IDs.
static func generate(rng: Variant, party_ids: Variant, candidate_ids: Variant) -> Dictionary:
	var rejected := {"ok": false, "offers": []}
	if not rng is RandomNumberGenerator:
		return rejected
	if not party_ids is Array or not candidate_ids is Array:
		return rejected
	if party_ids.size() != 3:
		return rejected

	var catalog := StarterCards.new()
	var known_owners := {}
	for catalog_id in catalog.get_all_card_ids():
		var definition: Dictionary = catalog.get_definition(catalog_id)
		if definition.get("owner") is String:
			known_owners[definition["owner"]] = true

	var party_set := {}
	for party_id in party_ids:
		if not party_id is String or party_id.is_empty():
			return rejected
		if party_set.has(party_id) or not known_owners.has(party_id):
			return rejected
		party_set[party_id] = true

	# Validate *all* supplied IDs, including those owned by non-party heroes,
	# before considering a draw; only valid catalog entries can be filtered out.
	var seen_ids := {}
	var eligible_ids: Array[String] = []
	for candidate in candidate_ids:
		if not candidate is String or candidate.is_empty():
			return rejected
		if seen_ids.has(candidate):
			return rejected
		seen_ids[candidate] = true
		var definition: Dictionary = catalog.get_definition(candidate)
		if definition.is_empty() or not definition.get("owner") is String:
			return rejected
		if party_set.has(definition["owner"]):
			eligible_ids.append(candidate)
	if eligible_ids.size() < 3:
		return rejected

	eligible_ids.sort()
	var offers: Array = []
	for pick in range(3):
		var index: int = rng.randi_range(0, eligible_ids.size() - 1)
		var card_id: String = eligible_ids[index]
		eligible_ids.remove_at(index)
		var card: Dictionary = catalog.get_definition(card_id)
		offers.append({"id": card_id, "owner": card["owner"]})
	return {"ok": true, "offers": offers}
