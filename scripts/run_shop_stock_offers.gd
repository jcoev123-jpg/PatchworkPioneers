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

	# Build catalog references and known owners from all four catalogs.
	var starter_catalog := StarterCards.new()
	var warden_pool := WardenPoolCards.new()
	var seamstress_pool := SeamstressPoolCards.new()
	var tinker_pool := TinkerPoolCards.new()
	var known_owners := {}
	for catalog_id in starter_catalog.get_all_card_ids():
		var definition: Dictionary = starter_catalog.get_definition(catalog_id)
		if definition.get("owner") is String:
			known_owners[definition["owner"]] = true
	for catalog_id in warden_pool.get_all_card_ids():
		var definition: Dictionary = warden_pool.get_definition(catalog_id)
		if definition.get("owner") is String:
			known_owners[definition["owner"]] = true
	for catalog_id in seamstress_pool.get_all_card_ids():
		var definition: Dictionary = seamstress_pool.get_definition(catalog_id)
		if definition.get("owner") is String:
			known_owners[definition["owner"]] = true
	# TinkerPoolCards uses get_pool_card_ids() for base cards, but get_all_card_ids() doesn't exist.
	# We need to check both base and upgrade cards for known owners.
	for catalog_id in tinker_pool.get_pool_card_ids():
		var definition: Dictionary = tinker_pool.get_definition(catalog_id)
		if definition.get("owner") is String:
			known_owners[definition["owner"]] = true
	# Also check upgrade cards for owners (they have the same owner).
	for base_id in tinker_pool.get_pool_card_ids():
		var upgrade_id: String = tinker_pool.get_upgrade_id(base_id)
		if upgrade_id:
			var definition: Dictionary = tinker_pool.get_definition(upgrade_id)
			if definition.get("owner") is String:
				known_owners[definition["owner"]] = true

	# The party is exactly three distinct heroes the authored catalogs know.
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
	# Pool upgrade cards (ending in _plus) are not valid Shop candidates.
	# StarterCards upgrade cards (like warden_strike_plus) ARE valid.
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
		# Look up the card definition across all four catalogs.
		var definition: Dictionary = {}
		var catalog_owner: String = ""
		var is_pool_card: bool = false
		if starter_catalog.has_card(card_id):
			definition = starter_catalog.get_definition(card_id)
			catalog_owner = definition.get("owner", "")
		elif warden_pool.has_card(card_id):
			definition = warden_pool.get_definition(card_id)
			catalog_owner = definition.get("owner", "")
			is_pool_card = true
		elif seamstress_pool.has_card(card_id):
			definition = seamstress_pool.get_definition(card_id)
			catalog_owner = definition.get("owner", "")
			is_pool_card = true
		elif tinker_pool.has_card(card_id):
			definition = tinker_pool.get_definition(card_id)
			catalog_owner = definition.get("owner", "")
			is_pool_card = true
		else:
			return rejected
		if definition.is_empty() or catalog_owner.is_empty():
			return rejected
		# Pool upgrade cards (ending in _plus) are not valid Shop candidates.
		# StarterCards upgrade cards ARE valid.
		if is_pool_card and card_id.ends_with("_plus"):
			return rejected
		var owner: String = catalog_owner
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
		# Look up the card definition across all four catalogs to get the owner.
		var owner: String = ""
		if starter_catalog.has_card(card_id):
			owner = starter_catalog.get_definition(card_id).get("owner", "")
		elif warden_pool.has_card(card_id):
			owner = warden_pool.get_definition(card_id).get("owner", "")
		elif seamstress_pool.has_card(card_id):
			owner = seamstress_pool.get_definition(card_id).get("owner", "")
		elif tinker_pool.has_card(card_id):
			owner = tinker_pool.get_definition(card_id).get("owner", "")
		cards.append({"id": card_id, "owner": owner, "price": card_prices[card_id]})

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


## Builds one seeded Peddler card stock: exactly one authored card offer for
## each of the three party heroes. Returns {"ok": false, "cards": []} for any
## malformed input, leaving the caller's arrays and RNG untouched.
static func generate_peddler_cards(rng: Variant, party_ids: Variant,
		card_candidates: Variant) -> Dictionary:
	var rejected: Dictionary = {"ok": false, "cards": []}
	if not (rng is RandomNumberGenerator):
		return rejected
	if not (party_ids is Array) or not (card_candidates is Array):
		return rejected

	# Build catalog references and known owners from all four catalogs.
	var starter_catalog := StarterCards.new()
	var warden_pool := WardenPoolCards.new()
	var seamstress_pool := SeamstressPoolCards.new()
	var tinker_pool := TinkerPoolCards.new()
	var known_owners := {}
	for catalog_id in starter_catalog.get_all_card_ids():
		var definition: Dictionary = starter_catalog.get_definition(catalog_id)
		if definition.get("owner") is String:
			known_owners[definition["owner"]] = true
	for catalog_id in warden_pool.get_all_card_ids():
		var definition: Dictionary = warden_pool.get_definition(catalog_id)
		if definition.get("owner") is String:
			known_owners[definition["owner"]] = true
	for catalog_id in seamstress_pool.get_all_card_ids():
		var definition: Dictionary = seamstress_pool.get_definition(catalog_id)
		if definition.get("owner") is String:
			known_owners[definition["owner"]] = true
	for catalog_id in tinker_pool.get_pool_card_ids():
		var definition: Dictionary = tinker_pool.get_definition(catalog_id)
		if definition.get("owner") is String:
			known_owners[definition["owner"]] = true
	for base_id in tinker_pool.get_pool_card_ids():
		var upgrade_id: String = tinker_pool.get_upgrade_id(base_id)
		if upgrade_id:
			var definition: Dictionary = tinker_pool.get_definition(upgrade_id)
			if definition.get("owner") is String:
				known_owners[definition["owner"]] = true

	# The party is exactly three distinct heroes the authored catalogs know.
	var party_set := {}
	var party_order: Array[String] = []
	for party_id in party_ids:
		if not (party_id is String):
			return rejected
		var hero_id: String = party_id
		if hero_id.strip_edges().is_empty() or party_set.has(hero_id) \
				or not known_owners.has(hero_id):
			return rejected
		party_set[hero_id] = true
		party_order.append(hero_id)
	if party_set.size() != 3:
		return rejected

	# Eligible card IDs grouped by their catalog owner, plus their prices.
	var card_prices := {}
	var eligible_by_hero := {}
	for hero_id in party_order:
		eligible_by_hero[hero_id] = []

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

		var definition: Dictionary = {}
		var catalog_owner: String = ""
		var is_pool_card: bool = false
		if starter_catalog.has_card(card_id):
			definition = starter_catalog.get_definition(card_id)
			catalog_owner = definition.get("owner", "")
		elif warden_pool.has_card(card_id):
			definition = warden_pool.get_definition(card_id)
			catalog_owner = definition.get("owner", "")
			is_pool_card = true
		elif seamstress_pool.has_card(card_id):
			definition = seamstress_pool.get_definition(card_id)
			catalog_owner = definition.get("owner", "")
			is_pool_card = true
		elif tinker_pool.has_card(card_id):
			definition = tinker_pool.get_definition(card_id)
			catalog_owner = definition.get("owner", "")
			is_pool_card = true
		else:
			return rejected
		if definition.is_empty() or catalog_owner.is_empty():
			return rejected
		# Pool upgrade cards (ending in _plus) are not valid Peddler stock.
		# StarterCards upgrade cards remain valid per the legacy rules.
		if is_pool_card and card_id.ends_with("_plus"):
			return rejected
		var owner: String = catalog_owner
		if not party_set.has(owner):
			return rejected
		if entry.has("owner"):
			if not (entry["owner"] is String) or entry["owner"] != owner:
				return rejected
		card_prices[card_id] = price
		eligible_by_hero[owner].append(card_id)

	# Require at least one eligible card for each party hero.
	for hero_id in party_order:
		if eligible_by_hero[hero_id].is_empty():
			return rejected

	# Sort each hero's eligible IDs so candidate order cannot affect the draw.
	for hero_id in party_order:
		eligible_by_hero[hero_id].sort()

	# One randi_range draw per hero, in party order.
	var cards: Array = []
	for hero_id in party_order:
		var ids: Array = eligible_by_hero[hero_id]
		var index: int = rng.randi_range(0, ids.size() - 1)
		var chosen: String = ids[index]
		cards.append({"id": chosen, "owner": hero_id, "price": card_prices[chosen]})

	return {"ok": true, "cards": cards}


## Builds one seeded Peddler stock: exactly one priced card for each of the three
## party heroes plus one priced patch. Returns {"ok": false, "cards": [], "patches": []}
## for any malformed input, leaving the caller's arrays and RNG untouched.
##
## card_candidates are {"id": String, "price": int} entries; the offer's owner
## is the authored catalog owner, and a candidate that also carries "owner" must
## agree with that catalog. patch_candidates are {"id": String, "price": int}
## entries. owned_patch_ids lists the patches the party already owns: those are
## fallback listings, sold on admission.
##
## Every rejection happens before the first RNG draw: a failed call returns
## empty offers, leaves the caller's arrays untouched and consumes no RNG.
static func generate_peddler_stock(rng: Variant, party_ids: Variant,
		card_candidates: Variant, patch_candidates: Variant,
		owned_patch_ids: Variant) -> Dictionary:
	var rejected: Dictionary = {"ok": false, "cards": [], "patches": []}
	if not (rng is RandomNumberGenerator):
		return rejected
	if not (party_ids is Array) or not (card_candidates is Array) \
			or not (patch_candidates is Array) or not (owned_patch_ids is Array):
		return rejected

	# Build catalog references and known owners from all four catalogs.
	var starter_catalog := StarterCards.new()
	var warden_pool := WardenPoolCards.new()
	var seamstress_pool := SeamstressPoolCards.new()
	var tinker_pool := TinkerPoolCards.new()
	var known_owners := {}
	for catalog_id in starter_catalog.get_all_card_ids():
		var definition: Dictionary = starter_catalog.get_definition(catalog_id)
		if definition.get("owner") is String:
			known_owners[definition["owner"]] = true
	for catalog_id in warden_pool.get_all_card_ids():
		var definition: Dictionary = warden_pool.get_definition(catalog_id)
		if definition.get("owner") is String:
			known_owners[definition["owner"]] = true
	for catalog_id in seamstress_pool.get_all_card_ids():
		var definition: Dictionary = seamstress_pool.get_definition(catalog_id)
		if definition.get("owner") is String:
			known_owners[definition["owner"]] = true
	for catalog_id in tinker_pool.get_pool_card_ids():
		var definition: Dictionary = tinker_pool.get_definition(catalog_id)
		if definition.get("owner") is String:
			known_owners[definition["owner"]] = true
	for base_id in tinker_pool.get_pool_card_ids():
		var upgrade_id: String = tinker_pool.get_upgrade_id(base_id)
		if upgrade_id:
			var definition: Dictionary = tinker_pool.get_definition(upgrade_id)
			if definition.get("owner") is String:
				known_owners[definition["owner"]] = true

	# The party is exactly three distinct heroes the authored catalogs know.
	var party_set := {}
	var party_order: Array[String] = []
	for party_id in party_ids:
		if not (party_id is String):
			return rejected
		var hero_id: String = party_id
		if hero_id.strip_edges().is_empty() or party_set.has(hero_id) \
				or not known_owners.has(hero_id):
			return rejected
		party_set[hero_id] = true
		party_order.append(hero_id)
	if party_set.size() != 3:
		return rejected

	# Validate ownership before any draws.
	var owned := {}
	for patch_id in owned_patch_ids:
		if not (patch_id is String):
			return rejected
		var owned_id: String = patch_id
		if owned_id.strip_edges().is_empty() or owned.has(owned_id):
			return rejected
		owned[owned_id] = true

	# --- PATCH CANDIDATE PREVALIDATION (before any RNG draw) ---
	var patch_prices := {}
	var eligible_patch_ids: Array[String] = []
	var owned_candidate_patch_ids: Array[String] = []
	for candidate in patch_candidates:
		if not (candidate is Dictionary):
			return rejected
		var entry: Dictionary = candidate
		if not entry.has("id") or not entry.has("price"):
			return rejected
		if not (entry["id"] is String):
			return rejected
		var patch_id: String = entry["id"]
		if patch_id.strip_edges().is_empty() or patch_prices.has(patch_id):
			return rejected
		var price := _read_price(entry["price"])
		if price < 0:
			return rejected
		patch_prices[patch_id] = price
		if owned.has(patch_id):
			owned_candidate_patch_ids.append(patch_id)
			continue
		eligible_patch_ids.append(patch_id)
	if patch_prices.is_empty():
		return rejected

	# Sort patch pools so candidate order cannot affect the draw.
	eligible_patch_ids.sort()
	owned_candidate_patch_ids.sort()

	# --- CARD CANDIDATE VALIDATION (same as generate_peddler_cards) ---
	# Eligible card IDs grouped by their catalog owner, plus their prices.
	var card_prices := {}
	var eligible_by_hero := {}
	for hero_id in party_order:
		eligible_by_hero[hero_id] = []

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

		var definition: Dictionary = {}
		var catalog_owner: String = ""
		var is_pool_card: bool = false
		if starter_catalog.has_card(card_id):
			definition = starter_catalog.get_definition(card_id)
			catalog_owner = definition.get("owner", "")
		elif warden_pool.has_card(card_id):
			definition = warden_pool.get_definition(card_id)
			catalog_owner = definition.get("owner", "")
			is_pool_card = true
		elif seamstress_pool.has_card(card_id):
			definition = seamstress_pool.get_definition(card_id)
			catalog_owner = definition.get("owner", "")
			is_pool_card = true
		elif tinker_pool.has_card(card_id):
			definition = tinker_pool.get_definition(card_id)
			catalog_owner = definition.get("owner", "")
			is_pool_card = true
		else:
			return rejected
		if definition.is_empty() or catalog_owner.is_empty():
			return rejected
		# Pool upgrade cards (ending in _plus) are not valid Peddler stock.
		# StarterCards upgrade cards remain valid per the legacy rules.
		if is_pool_card and card_id.ends_with("_plus"):
			return rejected
		var owner: String = catalog_owner
		if not party_set.has(owner):
			return rejected
		if entry.has("owner"):
			if not (entry["owner"] is String) or entry["owner"] != owner:
				return rejected
		card_prices[card_id] = price
		eligible_by_hero[owner].append(card_id)

	# Require at least one eligible card for each party hero.
	for hero_id in party_order:
		if eligible_by_hero[hero_id].is_empty():
			return rejected

	# Sort each hero's eligible IDs so candidate order cannot affect the draw.
	for hero_id in party_order:
		eligible_by_hero[hero_id].sort()

	# --- RNG DRAWS: exactly four randi_range calls (three cards + one patch) ---
	# One randi_range draw per hero, in party order.
	var cards: Array = []
	for hero_id in party_order:
		var ids: Array = eligible_by_hero[hero_id]
		var index: int = rng.randi_range(0, ids.size() - 1)
		var chosen: String = ids[index]
		cards.append({"id": chosen, "owner": hero_id, "price": card_prices[chosen]})

	# One randi_range draw for the patch.
	# Prefer unowned patches; fall back to owned if none are unowned.
	var patch_pool: Array[String] = eligible_patch_ids
	if patch_pool.is_empty():
		patch_pool = owned_candidate_patch_ids
	if patch_pool.is_empty():
		return rejected
	var patch_index: int = rng.randi_range(0, patch_pool.size() - 1)
	var chosen_patch: String = patch_pool[patch_index]
	var patches: Array = [{"id": chosen_patch, "price": patch_prices[chosen_patch]}]

	return {"ok": true, "cards": cards, "patches": patches}


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
