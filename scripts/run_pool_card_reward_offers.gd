class_name RunPoolCardRewardOffers
extends RefCounted
## Deterministic, rarity-weighted post-Fight reward selector for D2-1 base card pools.
## Samples three distinct party-owned base cards without replacement using two RNG draws per pick.

const TIER_ORDER: Array[String] = ["common", "uncommon", "rare"]
const TIER_WEIGHTS: Dictionary = {
	"common": 60,
	"uncommon": 30,
	"rare": 10
}


## Fail closed before drawing from run_rng. A successful call consumes exactly
## six randi_range draws (two per pick) from run_rng.
static func generate(run_rng: Variant, party_ids: Variant, base_candidates: Variant) -> Dictionary:
	var rejected: Dictionary = {"ok": false, "offers": []}
	if not (run_rng is RandomNumberGenerator):
		return rejected
	if not (party_ids is Array) or not (base_candidates is Array):
		return rejected
	if party_ids.size() != 3:
		return rejected

	var party_set: Dictionary = {}
	for hero_id_raw: Variant in party_ids:
		if not (hero_id_raw is String):
			return rejected
		var hero_id: String = hero_id_raw
		if hero_id.is_empty() or party_set.has(hero_id):
			return rejected
		party_set[hero_id] = true

	var seen_ids: Dictionary = {}
	var eligible_records: Array[Dictionary] = []

	for item_raw: Variant in base_candidates:
		if not (item_raw is Dictionary):
			return rejected
		var item: Dictionary = item_raw

		var id_raw: Variant = item.get("id")
		var owner_raw: Variant = item.get("owner")
		var rarity_raw: Variant = item.get("rarity")

		if not (id_raw is String) or not (owner_raw is String) or not (rarity_raw is String):
			return rejected

		var card_id: String = id_raw
		var owner: String = owner_raw
		var rarity: String = rarity_raw

		if card_id.is_empty() or owner.is_empty():
			return rejected

		if card_id.ends_with("_plus"):
			return rejected

		if rarity != "common" and rarity != "uncommon" and rarity != "rare":
			return rejected

		if seen_ids.has(card_id):
			return rejected
		seen_ids[card_id] = true

		if item.has("name"):
			var name_val: Variant = item.get("name")
			if not (name_val is String) or String(name_val).is_empty():
				return rejected

		if item.has("display_name"):
			var dname_val: Variant = item.get("display_name")
			if not (dname_val is String) or String(dname_val).is_empty():
				return rejected

		if party_set.has(owner):
			eligible_records.append({
				"id": card_id,
				"owner": owner,
				"rarity": rarity
			})

	if eligible_records.size() < 3:
		return rejected

	var buckets: Dictionary = {
		"common": [],
		"uncommon": [],
		"rare": []
	}
	for rec: Dictionary in eligible_records:
		var r: String = rec["rarity"]
		var bucket: Array = buckets[r]
		bucket.append(rec)

	for tier: String in TIER_ORDER:
		var bucket: Array = buckets[tier]
		bucket.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("id", "")) < String(b.get("id", ""))
		)

	var offers: Array = []
	for pick: int in range(3):
		var weight_sum: int = 0
		for tier: String in TIER_ORDER:
			var bucket: Array = buckets[tier]
			if not bucket.is_empty():
				weight_sum += int(TIER_WEIGHTS[tier])

		var tier_roll: int = run_rng.randi_range(1, weight_sum)
		var chosen_tier: String = ""
		var running_weight: int = 0
		for tier: String in TIER_ORDER:
			var bucket: Array = buckets[tier]
			if bucket.is_empty():
				continue
			running_weight += int(TIER_WEIGHTS[tier])
			if tier_roll <= running_weight:
				chosen_tier = tier
				break

		var chosen_bucket: Array = buckets[chosen_tier]
		var card_index: int = run_rng.randi_range(0, chosen_bucket.size() - 1)
		var card_rec: Dictionary = chosen_bucket[card_index]
		chosen_bucket.remove_at(card_index)

		offers.append({
			"id": String(card_rec["id"]),
			"owner": String(card_rec["owner"])
		})

	return {"ok": true, "offers": offers}


## Catalog-backed adapter for the three authored D2-1 hero pools.
## Enumerates each real catalog's base IDs, looks up the real definition, and
## returns detached {id, owner, rarity} candidate records. Upgrades/starters are
## never included because only base IDs are enumerated.
static func get_authored_base_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var warden: WardenPoolCards = WardenPoolCards.new()
	for card_id: String in warden.get_base_ids():
		var definition: Dictionary = warden.get_definition(card_id)
		candidates.append({
			"id": card_id,
			"owner": String(definition.get("owner", "")),
			"rarity": String(definition.get("rarity", ""))
		})
	var seamstress: SeamstressPoolCards = SeamstressPoolCards.new()
	for card_id: String in seamstress.get_base_ids():
		var definition: Dictionary = seamstress.get_definition(card_id)
		candidates.append({
			"id": card_id,
			"owner": String(definition.get("owner", "")),
			"rarity": String(definition.get("rarity", ""))
		})
	var tinker: TinkerPoolCards = TinkerPoolCards.new()
	for card_id: String in tinker.get_pool_card_ids():
		var definition: Dictionary = tinker.get_definition(card_id)
		candidates.append({
			"id": card_id,
			"owner": String(definition.get("owner", "")),
			"rarity": String(definition.get("rarity", ""))
		})
	for pool in [V3SeamstressPoolCards.new(), LanternMonkPoolCards.new(), RagDuelistPoolCards.new(), ScarecrowPoolCards.new(),
		YarnRangerPoolCards.new(), ButtonGolemPoolCards.new()]:
		for card_id in pool.get_base_ids():
			var definition: Dictionary = pool.get_definition(card_id)
			candidates.append({"id": card_id, "owner": definition.owner, "rarity": definition.rarity})
	return candidates


static func get_authored_candidates() -> Array[Dictionary]:
	return get_authored_base_candidates()


static func get_base_candidates() -> Array[Dictionary]:
	return get_authored_base_candidates()


static func get_pool_base_candidates() -> Array[Dictionary]:
	return get_authored_base_candidates()


## Resolves a card ID that may legitimately appear in a run deck or a prepared
## reward receipt: any authored starter card, or a reward-eligible base card
## from one of the three D2-1 pools. Pool '+' upgrades are never awarded, so they
## resolve to {} exactly like an unknown ID.
static func resolve_reward_definition(card_id: Variant) -> Dictionary:
	if not card_id is String or String(card_id).is_empty():
		return {}
	var id: String = card_id
	# These live-hand lookup aliases are owned V3 starters, never Fight rewards.
	# Keep their pre-existing reward exclusion despite the shared face bridge.
	if CombatTinkerV3StarterAttackCards.CARDS.has(id):
		return {}
	for catalog in [StarterCards.new(), V3SeamstressStarterCards.new(), LanternMonkStarterCards.new(), RagDuelistStarterCards.new(),
		ScarecrowStarterCards.new(), YarnRangerStarterCards.new(), ButtonGolemStarterCards.new()]:
		var starter: Dictionary = catalog.get_definition(id)
		if not starter.is_empty():
			return starter
	var warden := WardenPoolCards.new()
	if warden.get_base_ids().has(id):
		return warden.get_definition(id)
	var seamstress := SeamstressPoolCards.new()
	if seamstress.get_base_ids().has(id):
		return seamstress.get_definition(id)
	var tinker := TinkerPoolCards.new()
	if tinker.get_pool_card_ids().has(id):
		return tinker.get_definition(id)
	for pool in [V3SeamstressPoolCards.new(), LanternMonkPoolCards.new(), RagDuelistPoolCards.new(), ScarecrowPoolCards.new(),
		YarnRangerPoolCards.new(), ButtonGolemPoolCards.new()]:
		if pool.get_base_ids().has(id):
			return pool.get_definition(id)
	return {}


## Delegates to generate() with the real authored base candidates.
static func generate_from_authored_pools(run_rng: Variant, party_ids: Variant) -> Dictionary:
	return generate(run_rng, party_ids, get_authored_base_candidates())


static func generate_from_authored(run_rng: Variant, party_ids: Variant) -> Dictionary:
	return generate_from_authored_pools(run_rng, party_ids)


static func generate_from_pools(run_rng: Variant, party_ids: Variant) -> Dictionary:
	return generate_from_authored_pools(run_rng, party_ids)


static func generate_authored(run_rng: Variant, party_ids: Variant) -> Dictionary:
	return generate_from_authored_pools(run_rng, party_ids)


## Living-hero-balanced weighted reward selection for D2-1 base card pools.
## Offers one card from each living hero in party order, filling remaining offers
## from the union of living heroes' remaining cards without replacement.
## Consumes exactly six randi_range draws (two per pick) from run_rng.
static func generate_for_living(run_rng: Variant, party_ids: Variant, living_ids: Variant, base_candidates: Variant) -> Dictionary:
	var rejected: Dictionary = {"ok": false, "offers": []}
	if not (run_rng is RandomNumberGenerator):
		return rejected
	if not (party_ids is Array) or not (living_ids is Array) or not (base_candidates is Array):
		return rejected
	if party_ids.size() != 3 or living_ids.is_empty() or living_ids.size() > 3:
		return rejected

	var party_set: Dictionary = {}
	for hero_id_raw: Variant in party_ids:
		if not (hero_id_raw is String):
			return rejected
		var hero_id: String = hero_id_raw
		if hero_id.is_empty() or party_set.has(hero_id):
			return rejected
		party_set[hero_id] = true

	var living_set: Dictionary = {}
	for living_id_raw: Variant in living_ids:
		if not (living_id_raw is String):
			return rejected
		var living_id: String = living_id_raw
		if living_id.is_empty() or living_set.has(living_id) or not party_set.has(living_id):
			return rejected
		living_set[living_id] = true

	var living_party_order: Array[String] = []
	for hero_id_raw: Variant in party_ids:
		var hero_id: String = hero_id_raw
		if living_set.has(hero_id):
			living_party_order.append(hero_id)

	var seen_ids: Dictionary = {}
	var living_candidates_by_owner: Dictionary = {}
	for hid: String in living_party_order:
		living_candidates_by_owner[hid] = {
			"common": [],
			"uncommon": [],
			"rare": []
		}

	for item_raw: Variant in base_candidates:
		if not (item_raw is Dictionary):
			return rejected
		var item: Dictionary = item_raw

		var id_raw: Variant = item.get("id")
		var owner_raw: Variant = item.get("owner")
		var rarity_raw: Variant = item.get("rarity")

		if not (id_raw is String) or not (owner_raw is String) or not (rarity_raw is String):
			return rejected

		var card_id: String = id_raw
		var owner: String = owner_raw
		var rarity: String = rarity_raw

		if card_id.is_empty() or owner.is_empty():
			return rejected

		if card_id.ends_with("_plus"):
			return rejected

		if rarity != "common" and rarity != "uncommon" and rarity != "rare":
			return rejected

		if seen_ids.has(card_id):
			return rejected
		seen_ids[card_id] = true

		if item.has("name"):
			var name_val: Variant = item.get("name")
			if not (name_val is String) or String(name_val).is_empty():
				return rejected

		if item.has("display_name"):
			var dname_val: Variant = item.get("display_name")
			if not (dname_val is String) or String(dname_val).is_empty():
				return rejected

		if living_candidates_by_owner.has(owner):
			var owner_buckets: Dictionary = living_candidates_by_owner[owner]
			var bucket: Array = owner_buckets[rarity]
			bucket.append({
				"id": card_id,
				"owner": owner,
				"rarity": rarity
			})

	var total_living: int = 0
	for hid: String in living_party_order:
		var owner_buckets: Dictionary = living_candidates_by_owner[hid]
		var count: int = owner_buckets["common"].size() + owner_buckets["uncommon"].size() + owner_buckets["rare"].size()
		if count < 1:
			return rejected
		total_living += count

	if total_living < 3:
		return rejected

	for hid: String in living_party_order:
		var owner_buckets: Dictionary = living_candidates_by_owner[hid]
		for tier: String in TIER_ORDER:
			var bucket: Array = owner_buckets[tier]
			bucket.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return String(a.get("id", "")) < String(b.get("id", ""))
			)

	var offers: Array = []

	# First pass: one pick per living owner in party order (up to 3)
	for hid: String in living_party_order:
		if offers.size() >= 3:
			break
		var buckets: Dictionary = living_candidates_by_owner[hid]
		var weight_sum: int = 0
		for tier: String in TIER_ORDER:
			var bucket: Array = buckets[tier]
			if not bucket.is_empty():
				weight_sum += int(TIER_WEIGHTS[tier])

		var tier_roll: int = run_rng.randi_range(1, weight_sum)
		var chosen_tier: String = ""
		var running_weight: int = 0
		for tier: String in TIER_ORDER:
			var bucket: Array = buckets[tier]
			if bucket.is_empty():
				continue
			running_weight += int(TIER_WEIGHTS[tier])
			if tier_roll <= running_weight:
				chosen_tier = tier
				break

		var chosen_bucket: Array = buckets[chosen_tier]
		var card_index: int = run_rng.randi_range(0, chosen_bucket.size() - 1)
		var card_rec: Dictionary = chosen_bucket[card_index]
		chosen_bucket.remove_at(card_index)

		offers.append({
			"id": String(card_rec["id"]),
			"owner": String(card_rec["owner"])
		})

	# Second pass: fill any remaining offers from the union of living owners' residual pools
	if offers.size() < 3:
		var union_buckets: Dictionary = {
			"common": [],
			"uncommon": [],
			"rare": []
		}
		for tier: String in TIER_ORDER:
			var u_bucket: Array = union_buckets[tier]
			for hid: String in living_party_order:
				var owner_buckets: Dictionary = living_candidates_by_owner[hid]
				var o_bucket: Array = owner_buckets[tier]
				for rec_val: Variant in o_bucket:
					u_bucket.append(rec_val)
			u_bucket.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return String(a.get("id", "")) < String(b.get("id", ""))
			)

		while offers.size() < 3:
			var weight_sum: int = 0
			for tier: String in TIER_ORDER:
				var bucket: Array = union_buckets[tier]
				if not bucket.is_empty():
					weight_sum += int(TIER_WEIGHTS[tier])

			var tier_roll: int = run_rng.randi_range(1, weight_sum)
			var chosen_tier: String = ""
			var running_weight: int = 0
			for tier: String in TIER_ORDER:
				var bucket: Array = union_buckets[tier]
				if bucket.is_empty():
					continue
				running_weight += int(TIER_WEIGHTS[tier])
				if tier_roll <= running_weight:
					chosen_tier = tier
					break

			var chosen_bucket: Array = union_buckets[chosen_tier]
			var card_index: int = run_rng.randi_range(0, chosen_bucket.size() - 1)
			var card_rec: Dictionary = chosen_bucket[card_index]
			chosen_bucket.remove_at(card_index)

			offers.append({
				"id": String(card_rec["id"]),
				"owner": String(card_rec["owner"])
			})

	return {"ok": true, "offers": offers}


static func generate_for_living_from_authored(run_rng: Variant, party_ids: Variant, living_ids: Variant) -> Dictionary:
	return generate_for_living(run_rng, party_ids, living_ids, get_authored_base_candidates())
