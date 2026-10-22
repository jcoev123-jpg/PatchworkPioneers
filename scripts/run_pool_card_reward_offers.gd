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
