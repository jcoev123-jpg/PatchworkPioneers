class_name RunShopStockOffers
extends RefCounted
## Scene-free, seeded construction of one Shop visit's stock: five distinct
## party-owned card offers and two distinct trinket offers, preferring unowned
## trinkets and filling any remaining listings with owned ones.
##
## The caller owns the one seeded run RNG and supplies the priced candidate
## pools. This helper only selects offers: it never invents prices, catalog
## entries, removal prices or balance, and it never touches the live Shop.
##
## generate(rng, party_ids, card_candidates, trinket_candidates, owned_trinket_ids)
##   -> {"ok": bool,
##       "cards": [{"id": String, "owner": String, "price": int}],   # five when ok
##       "trinkets": [{"id": String, "price": int}]}                 # two when ok
##
## card_candidates are {"id": String, "price": int} entries; the offer's
## owner is the authored catalog owner, and a candidate that also carries
## "owner" must agree with that catalog. trinket_candidates are
## {"id": String, "price": int} entries. owned_trinket_ids lists the trinkets
## the party already owns: those are fallback listings, sold on admission.
##
## Every rejection happens before the first RNG draw: a failed call returns
## empty offers, leaves the caller's arrays untouched and consumes no RNG.

const CARD_OFFER_COUNT := 5
const TRINKET_OFFER_COUNT := 2


## Builds one seeded Shop stock. Returns {"ok": false, "cards": [], "trinkets": []}
## for any malformed input, so a partial stock is never published.
static func generate(rng: Variant, party_ids: Variant, card_candidates: Variant,
		trinket_candidates: Variant, owned_trinket_ids: Variant) -> Dictionary:
	var rejected: Dictionary = {"ok": false, "cards": [], "trinkets": []}
	if not (rng is RandomNumberGenerator):
		return rejected
	if not (party_ids is Array) or not (card_candidates is Array) \
			or not (trinket_candidates is Array) or not (owned_trinket_ids is Array):
		return rejected

	var catalog := StarterCards.new()
	var known_owners := {}
	for catalog_id in catalog.get_all_card_ids():
		var definition: Dictionary = catalog.get_definition(catalog_id)
		if definition.get("owner") is String:
			known_owners[definition["owner"]] = true

	# The party is exactly three distinct heroes the authored catalog knows.
	var party_set := {}
	for party_id in party_ids:
		if not (party_id is String):
			return rejected
		var hero_id: String = party_id
		if hero_id.strip_edges().is_empty() or party_set.has(hero_id) \
				or not known_owners.has(hero_id):
			return rejected
		party_set[hero_id] = true
	if party_set.size() != 3:
		return rejected

	# Validate ownership before any draws.
	var owned := {}
	for trinket_id in owned_trinket_ids:
		if not (trinket_id is String):
			return rejected
		var owned_id: String = trinket_id
		if owned_id.strip_edges().is_empty() or owned.has(owned_id):
			return rejected
		owned[owned_id] = true

	# Every supplied card candidate must be a known, party-owned catalog card
	# with a whole non-negative price. Unknown, duplicated and wrong-owner
	# candidates fail the whole call instead of shrinking the pool silently.
	var card_prices := {}
	var eligible_card_ids: Array[String] = []
	for candidate in card_candidates:
		if not (candidate is Dictionary):
			return rejected
		var entry: Dictionary = candidate
		if not entry.has("id") or not entry.has("price"):
			return rejected
		if not (entry["id"] is String):
			return rejected
		var card_id: String = entry["id"]
		if card_id.strip_edges().is_empty() or card_prices.has(card_id):
			return rejected
		var price := _read_price(entry["price"])
		if price < 0:
			return rejected
		var definition: Dictionary = catalog.get_definition(card_id)
		if definition.is_empty() or not (definition.get("owner") is String):
			return rejected
		var owner: String = definition["owner"]
		if not party_set.has(owner):
			return rejected
		if entry.has("owner"):
			if not (entry["owner"] is String) or entry["owner"] != owner:
				return rejected
		card_prices[card_id] = price
		eligible_card_ids.append(card_id)
	if eligible_card_ids.size() < CARD_OFFER_COUNT:
		return rejected

	# Trinket candidates only need a unique id and a whole non-negative price.
	var trinket_prices := {}
	var eligible_trinket_ids: Array[String] = []
	var owned_candidate_ids: Array[String] = []
	for candidate in trinket_candidates:
		if not (candidate is Dictionary):
			return rejected
		var entry: Dictionary = candidate
		if not entry.has("id") or not entry.has("price"):
			return rejected
		if not (entry["id"] is String):
			return rejected
		var trinket_id: String = entry["id"]
		if trinket_id.strip_edges().is_empty() or trinket_prices.has(trinket_id):
			return rejected
		var price := _read_price(entry["price"])
		if price < 0:
			return rejected
		trinket_prices[trinket_id] = price
		if owned.has(trinket_id):
			owned_candidate_ids.append(trinket_id)
			continue
		eligible_trinket_ids.append(trinket_id)
	if trinket_prices.size() < TRINKET_OFFER_COUNT:
		return rejected

	# Sort both pools so the same candidates in a different order always draw
	# the same stock, then take five cards and two trinkets without
	# replacement: seven randi_range draws from the caller's run RNG.
	eligible_card_ids.sort()
	eligible_trinket_ids.sort()
	owned_candidate_ids.sort()

	var cards: Array = []
	for _pick in range(CARD_OFFER_COUNT):
		var index: int = rng.randi_range(0, eligible_card_ids.size() - 1)
		var card_id: String = eligible_card_ids[index]
		eligible_card_ids.remove_at(index)
		var definition: Dictionary = catalog.get_definition(card_id)
		cards.append({"id": card_id, "owner": definition["owner"], "price": card_prices[card_id]})

	var trinkets: Array = []
	for _pick in range(TRINKET_OFFER_COUNT):
		if eligible_trinket_ids.is_empty():
			eligible_trinket_ids.assign(owned_candidate_ids)
			owned_candidate_ids.clear()
		var index: int = rng.randi_range(0, eligible_trinket_ids.size() - 1)
		var trinket_id: String = eligible_trinket_ids[index]
		eligible_trinket_ids.remove_at(index)
		trinkets.append({"id": trinket_id, "price": trinket_prices[trinket_id]})

	return {"ok": true, "cards": cards, "trinkets": trinkets}


## Reads a supplied price. JSON numbers arrive as floats, so a whole float is
## accepted and normalised to an int; a fractional, negative or non-numeric
## price is rejected instead of being truncated into a valid-looking price.
static func _read_price(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return int(value) if value >= 0 else -1
	if typeof(value) == TYPE_FLOAT:
		if not is_finite(value) or value < 0.0 or value != floor(value):
			return -1
		return int(value)
	return -1
