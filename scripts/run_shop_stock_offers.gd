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
## The shipped priced catalog covers all eight v3 heroes, so every candidate
## is validated against its authored catalog first and a correctly authored
## card owned by a hero outside the chosen party is then ignored for selection.
## Malformed, unknown, duplicated, wrong-owner and upgrade candidates still
## reject the whole call, never a silent skip.
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

	# Build catalog references and known owners from every authored hero
	# catalog: StarterCards, all eight v3 pool catalogs and the three
	# look-driven raw v3 printings.
	var catalogs: Array = _peddler_catalogs()
	var known_owners: Dictionary = _build_known_owners(catalogs)

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

	# Every supplied card candidate is validated against its authored catalog
	# before any draw: unknown, duplicated, wrong-owner, upgrade and bad-price
	# candidates fail the whole call instead of shrinking the pool silently.
	# Only AFTER that check is a correctly authored card owned by a hero
	# outside the chosen party skipped, because the Shop JSON carries priced
	# cards for every hero while one visit offers only this party's stock.
	# Pool upgrade cards (ending in _plus) are not valid Shop candidates.
	# StarterCards upgrade cards (like warden_strike_plus) ARE valid.
	var card_prices := {}
	var card_owners := {}
	var seen_card_ids := {}
	var eligible_card_ids: Array[String] = []
	for candidate in card_candidates:
		var validated: Dictionary = _validate_card_candidate(candidate, catalogs,
			known_owners, party_set, seen_card_ids)
		if not validated.get("ok", false):
			return rejected
		if not validated["in_party"]:
			continue
		var card_id: String = validated["id"]
		card_prices[card_id] = validated["price"]
		card_owners[card_id] = validated["owner"]
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
		cards.append({"id": card_id, "owner": card_owners[card_id],
			"price": card_prices[card_id]})

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
## malformed input, leaving the caller's arrays and RNG untouched. Correctly
## authored cards for heroes outside the party are validated and then skipped.
static func generate_peddler_cards(rng: Variant, party_ids: Variant,
		card_candidates: Variant) -> Dictionary:
	var rejected: Dictionary = {"ok": false, "cards": []}
	if not (rng is RandomNumberGenerator):
		return rejected
	if not (party_ids is Array) or not (card_candidates is Array):
		return rejected

	var catalogs: Array = _peddler_catalogs()
	var known_owners: Dictionary = _build_known_owners(catalogs)

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
	# Every candidate is validated against its authored catalog first; only a
	# correctly authored card for another hero is then skipped, so one Peddler
	# visit still offers exactly this party's stock.
	var card_prices := {}
	var eligible_by_hero := {}
	var seen_card_ids := {}
	for hero_id in party_order:
		eligible_by_hero[hero_id] = []

	for candidate in card_candidates:
		var validated: Dictionary = _validate_card_candidate(candidate, catalogs,
			known_owners, party_set, seen_card_ids)
		if not validated.get("ok", false):
			return rejected
		if not validated["in_party"]:
			continue
		var card_id: String = validated["id"]
		card_prices[card_id] = validated["price"]
		eligible_by_hero[validated["owner"]].append(card_id)

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
## fallback listings, sold on admission. Correctly authored cards for heroes
## outside the chosen party are validated and then skipped, so the shipped
## eight-hero priced catalog can feed any three-hero party.
##
## Only authored POWER patches are payable stock: the shared power-only
## projection still validates every catalog in full but withholds the inert
## starter-slot records, so a priced starter record is accepted as a candidate
## and then filtered out of both the unowned and the owned fallback pool
## instead of being offered as a powerless purchase. An ID that projection does
## not know is never promoted to a payable power either.
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

	var catalogs: Array = _peddler_catalogs()
	var known_owners: Dictionary = _build_known_owners(catalogs)

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
	# Only authored power patches are payable stock. The shared power-only
	# projection validates every authored catalog in full but withholds the
	# inert starter-slot records, so the shipped superset candidate list is
	# accepted whole while its two powerless starter records are filtered out
	# of BOTH draw pools. An unknown or inert candidate is never promoted to a
	# payable power.
	var power_patch_ids := _power_patch_ids()
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
		if not power_patch_ids.has(patch_id):
			continue
		if owned.has(patch_id):
			owned_candidate_patch_ids.append(patch_id)
			continue
		eligible_patch_ids.append(patch_id)
	# No candidate record at all, or none with a real authored power, refuses
	# the whole visit before any draw: a partial 3+1 stock is never published.
	if patch_prices.is_empty():
		return rejected
	if eligible_patch_ids.is_empty() and owned_candidate_patch_ids.is_empty():
		return rejected

	# Sort patch pools so candidate order cannot affect the draw.
	eligible_patch_ids.sort()
	owned_candidate_patch_ids.sort()

	# --- CARD CANDIDATE VALIDATION (same as generate_peddler_cards) ---
	# Eligible card IDs grouped by their catalog owner, plus their prices.
	# Every candidate is validated against its authored catalog first; only a
	# correctly authored card for another hero is then skipped, so one Peddler
	# visit still offers exactly this party's stock.
	var card_prices := {}
	var eligible_by_hero := {}
	var seen_card_ids := {}
	for hero_id in party_order:
		eligible_by_hero[hero_id] = []

	for candidate in card_candidates:
		var validated: Dictionary = _validate_card_candidate(candidate, catalogs,
			known_owners, party_set, seen_card_ids)
		if not validated.get("ok", false):
			return rejected
		if not validated["in_party"]:
			continue
		var card_id: String = validated["id"]
		card_prices[card_id] = validated["price"]
		eligible_by_hero[validated["owner"]].append(card_id)

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
	var patch_index: int = draw_patch_index(rng, patch_pool)
	var chosen_patch: String = patch_pool[patch_index]
	var patches: Array = [{"id": chosen_patch, "price": patch_prices[chosen_patch]}]

	return {"ok": true, "cards": cards, "patches": patches}


## One existing-slot draw, with P8 weighted 10 against each ordinary 100.
## Preserve legacy streams when a supplied pool contains no P8 candidates.
static func draw_patch_index(rng: RandomNumberGenerator, ids: Array) -> int:
	if not ids.has("relay_bobbin") and not ids.has("hearth_lining"):
		return rng.randi_range(0, ids.size() - 1)
	var total := 0
	for id in ids:
		total += 10 if id in ["relay_bobbin", "hearth_lining"] else 100
	var roll := rng.randi_range(0, total - 1)
	for index in range(ids.size()):
		roll -= 10 if ids[index] in ["relay_bobbin", "hearth_lining"] else 100
		if roll < 0:
			return index
	return -1


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


## The authored power-only patch IDs from the shared projection. Its validation
## pass still covers the whole starter catalog (including records authored
## there later) but withholds every entry of it, so an inert starter-slot
## record can never be priced as a patch offer. An unreadable catalog yields an
## empty set, which refuses the visit instead of offering a powerless patch.
static func _power_patch_ids() -> Dictionary:
	var ids := {}
	for definition in RunAuthoredPatchDefinitions.load_power_definitions():
		if definition is Dictionary and definition.get("id") is String:
			ids[definition["id"]] = true
	return ids


## Every authored card catalog a priced Shop/Peddler candidate may come from:
## the starter catalog, the eight live hero pools and the three look-driven v3
## printings (Warden, Seamstress, Tinker). Adding a v3 raw print here only makes
## its authored owner resolvable; selection still offers one card per party hero.
static func _peddler_catalogs() -> Array:
	return [
		StarterCards.new(),
		WardenPoolCards.new(),
		SeamstressPoolCards.new(),
		TinkerPoolCards.new(),
		LanternMonkPoolCards.new(),
		RagDuelistPoolCards.new(),
		ScarecrowPoolCards.new(),
		YarnRangerPoolCards.new(),
		ButtonGolemPoolCards.new(),
		V3WardenPoolCards.new(),
		V3SeamstressPoolCards.new(),
		V3TinkerPoolCards.new()
	]


static func _build_known_owners(catalogs: Array) -> Dictionary:
	var known_owners := {}
	for catalog: Variant in catalogs:
		var ids: Array
		if catalog.has_method("get_pool_card_ids"):
			ids = catalog.get_pool_card_ids()
		else:
			ids = catalog.get_all_card_ids()
		for catalog_id: String in ids:
			var definition: Dictionary = catalog.get_definition(catalog_id)
			if definition.get("owner") is String:
				known_owners[definition["owner"]] = true
		if catalog.has_method("get_pool_card_ids"):
			for base_id: String in catalog.get_pool_card_ids():
				var upgrade_id: String = catalog.get_upgrade_id(base_id)
				if upgrade_id:
					var definition: Dictionary = catalog.get_definition(upgrade_id)
					if definition.get("owner") is String:
						known_owners[definition["owner"]] = true
	return known_owners


static func _find_card_definition(card_id: String, catalogs: Array) -> Dictionary:
	for i in range(catalogs.size()):
		var catalog: Variant = catalogs[i]
		if catalog.has_card(card_id):
			return {"def": catalog.get_definition(card_id), "is_pool": i > 0}
	return {}


## Validates one supplied priced card candidate against the authentically
## authored catalogs, in this order: shape, non-empty unique ID, whole
## non-negative quote, authored definition, known owner, base-only pool card
## and (when supplied) the exact catalog owner. Only a fully valid record can
## then be reported as out of party, and only then is it skipped for selection.
## Returns {"ok": false} for any malformed candidate, so a partly valid list can
## never publish a partial stock, and {"ok": true, "in_party": false} for a
## correctly authored other-hero card. seen_ids accumulates the accepted IDs.
static func _validate_card_candidate(candidate: Variant, catalogs: Array,
		known_owners: Dictionary, party_set: Dictionary,
		seen_ids: Dictionary) -> Dictionary:
	var invalid: Dictionary = {"ok": false}
	if not (candidate is Dictionary):
		return invalid
	var entry: Dictionary = candidate
	if not entry.has("id") or not entry.has("price"):
		return invalid
	if not (entry["id"] is String):
		return invalid
	var card_id: String = entry["id"]
	if card_id.strip_edges().is_empty() or seen_ids.has(card_id):
		return invalid
	var price := _read_price(entry["price"])
	if price < 0:
		return invalid
	var found := _find_card_definition(card_id, catalogs)
	if found.is_empty():
		return invalid
	var definition: Dictionary = found["def"]
	if definition.is_empty():
		return invalid
	var owner: String = definition.get("owner", "")
	if owner.is_empty() or not known_owners.has(owner):
		return invalid
	# Pool upgrade cards (ending in _plus) are never ordinary stock.
	# StarterCards upgrade cards remain valid per the legacy rules.
	if found["is_pool"] and card_id.ends_with("_plus"):
		return invalid
	if entry.has("owner"):
		if not (entry["owner"] is String) or entry["owner"] != owner:
			return invalid
	seen_ids[card_id] = true
	return {"ok": true, "id": card_id, "owner": owner, "price": price,
		"in_party": party_set.has(owner)}
