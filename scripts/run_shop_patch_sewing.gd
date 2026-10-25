class_name RunShopPatchSewing
extends RefCounted
## Scene-free bridge for a CONFIRMED, open Shop node. The caller passes all
## three live ledgers and their complete, current optimistic snapshots.
## purchase_and_sew does not stock-roll, invoke Rest re_sew, or project stats.
##
## Its synchronous preflight proves every downstream mutation can complete:
## paid buy -> exact visit receipt reconciliation -> wardrobe context refresh
## -> free sew. Rejected proposals neither spend nor claim operation IDs.
## After success the paid stock is sold, so the same purchase cannot replay.

const SLOTS := ["HEAD", "ARM", "COAT"]
const MAX_INT := 9223372036854775807


static func purchase_and_sew(purchases: RunShopPurchases, visit: RunShopVisit,
		wardrobe: RunPatchWardrobe, shop_node_id: Variant, patch_id: Variant,
		hero_id: Variant, slot: Variant, operation_id: Variant,
		expected_purchase: Variant, expected_stock: Variant,
		expected_visit: Variant, expected_wardrobe: Variant) -> Dictionary:
	var rejected := {"ok": false}
	if purchases != null and purchases.patch_stall_choice_used():
		return rejected
	if purchases == null or visit == null or wardrobe == null 			or not purchases.is_valid() or not wardrobe.is_valid():
		return rejected
	# Equality to complete fresh reads also checks the wardrobe's own receipt
	# hash and operation history. Never trust isolated caller-supplied fields.
	var p: Dictionary = purchases.get_state()
	var stock: Dictionary = purchases.get_stock()
	var v: Dictionary = visit.get_state()
	var w: Dictionary = wardrobe.get_snapshot()
	if not (expected_purchase is Dictionary) or expected_purchase != p 			or not (expected_stock is Dictionary) or expected_stock != stock 			or not (expected_visit is Dictionary) or expected_visit != v 			or not (expected_wardrobe is Dictionary) or expected_wardrobe != w:
		return rejected
	if not _id(shop_node_id) or not _id(patch_id) or not _id(hero_id) 			or not _id(operation_id) or not (slot is String) or not SLOTS.has(slot):
		return rejected
	if v.get("valid") != true or not ["available", "used"].has(v.get("status")) 			or v.get("shop_node_id") != shop_node_id 			or not (v.get("visited_ids") is Array) 			or not v["visited_ids"].has(shop_node_id):
		return rejected
	# Both paid ledgers and the wardrobe must refer to precisely the same
	# *ordered* inventories, not merely equivalent totals.
	if not (p.get("deck") is Array) or not (p.get("trinkets") is Array) 			or not (p.get("party_ids") is Array) or not (p.get("gold") is int) 			or p["gold"] < 0 or v.get("deck") != p["deck"] 			or v.get("trinkets") != p["trinkets"] or v.get("gold") != p["gold"] 			or w.get("cards") != p["deck"] or w.get("owned") != p["trinkets"] 			or w.get("gold") != p["gold"]:
		return rejected
	if not (w.get("heroes") is Array) or w["heroes"].size() != 3 			or p["party_ids"].size() != 3 or not (w.get("operation_ids") is Array) 			or w["operation_ids"].has(operation_id) or w.get("rest_id") != "":
		return rejected
	for i in range(3):
		if not (w["heroes"][i] is Dictionary) 				or w["heroes"][i].get("id") != p["party_ids"][i]:
			return rejected
	if not p["party_ids"].has(hero_id) or p["trinkets"].has(patch_id):
		return rejected
	if not (w.get("definitions") is Dictionary) or not (w.get("worn") is Dictionary) 			or w["definitions"].get(patch_id) != slot:
		return rejected
	# Validate all worn metadata before any paid action, including previous
	# wearers. A replacement must be guaranteed to be sewable after refresh.
	var worn: Dictionary = w["worn"]
	var definitions: Dictionary = w["definitions"]
	var seen := {}
	for owner in p["party_ids"]:
		if not (worn.get(owner) is Dictionary) or worn[owner].size() != 3:
			return rejected
		for named_slot in SLOTS:
			var worn_id: Variant = worn[owner].get(named_slot)
			if not (worn_id is String):
				return rejected
			if worn_id == "":
				continue
			if seen.has(worn_id) or not p["trinkets"].has(worn_id) 					or definitions.get(worn_id) != named_slot:
				return rejected
			seen[worn_id] = true
	if worn.size() != 3 or seen.has(patch_id):
		return rejected
	var displaced: String = worn[hero_id][slot]
	if not (w.get("scraps") is int) or w["scraps"] < 0 			or (displaced != "" and w["scraps"] == MAX_INT):
		return rejected
	# Only one of the *two actually stocked* trinket offers is purchasable;
	# a third authored candidate is never a stock item for this visit.
	var offer: Dictionary = {}
	for listing in stock.get("trinkets", []):
		if not (listing is Dictionary):
			return rejected
		if listing.get("id") == patch_id:
			offer = listing
			break
	if offer.is_empty() or offer.get("sold") != false 			or not (offer.get("price") is int) or offer["price"] <= 0 			or p["gold"] < offer["price"]:
		return rejected

	# A legal buy appends exactly one patch and debits this quoted price.
	# Reconcile therefore accepts its genuine three-field receipt; refresh
	# accepts the same nonnegative gold and the exact old-owned prefix; and
	# sew accepts the fresh owned, unworn ID and declared recipient slot.
	var bought: Dictionary = purchases.buy("trinket", patch_id)
	var reconciled: bool = visit.reconcile_purchase(bought)
	var refreshed: bool = wardrobe.refresh_run_context(
		w["heroes"], bought["state"]["trinkets"], w["scraps"],
		bought["state"]["gold"], bought["state"]["deck"], w)
	var sewn: Dictionary = wardrobe.sew(
		patch_id, hero_id, slot, operation_id, wardrobe.get_snapshot())
	# Wardrobe sewing destroys an occupied patch. Mirror that exact removal
	# into BOTH upstream ownership ledgers or a later run publication would
	# resurrect the displaced patch. This never changes the paid receipt.
	var settled_purchase := true
	var settled_visit := true
	if displaced != "":
		settled_purchase = purchases.settle_displaced_patch(
			displaced, patch_id, purchases.get_state())
		settled_visit = visit.settle_displaced_patch(
			displaced, patch_id, visit.get_state())
	# All three are guaranteed by the preflight in this synchronous call.
	# Do not publish a success receipt unless the real underlying receipts
	# and ledgers have committed.
	assert(bought.get("ok") == true and reconciled and refreshed and sewn.get("ok") == true and settled_purchase and settled_visit,
		"Shop patch preflight must admit only fully committable transactions")
	return {
		"ok": true,
		"purchase_receipt": bought["receipt"].duplicate(true),
		"sew_receipt": sewn["receipt"].duplicate(true),
		"purchase_state": purchases.get_state(),
		"purchase_stock": purchases.get_stock(),
		"visit_state": visit.get_state(),
		"wardrobe_state": wardrobe.get_snapshot(),
	}


static func _id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value == value.strip_edges()
