class_name RunShopPurchases
extends RefCounted
## One Shop, Patch Stall or Peddler visit's supplied listings. No stock rolls,
## catalog lookups, passive effects, or card removal happen here.
##
## Construct with (party_ids, deck_card_ids, owned_trinket_ids, gold,
##                 card_offers, trinket_offers[, visit_kind]).
## Default visit_kind "shop" preserves the existing five-card/two-trinket
## contract exactly. The optional "patch_stall" mode requires zero card
## offers and exactly three distinct priced patch offers, allows only one
## successful patch purchase per visit, and refuses paid removal rebases.
## "peddler" requires one distinct card per party hero and one patch, permits
## one successful purchase of either kind, and refuses paid removal rebases.
## Invalid visits expose empty state/stock and never accept purchases.
##
## get_state(): {"party_ids": Array, "deck": Array, "trinkets": Array, "gold": int}
## get_stock(): {"cards": Array[{"id", "owner", "price", "sold"}],
##               "trinkets": Array[{"id", "price", "sold"}]}
## buy(kind, id): {"ok": bool, "state": get_state(), "stock": get_stock(),
##                  "receipt": {"kind", "id", "price"} on success only}
## Every result/read is detached, including rejected transactions.

var _valid: bool = false
var _state: Dictionary = {}
var _stock: Dictionary = {}
var _removal_rebased: bool = false
var _visit_kind: String = "shop"
var _choice_used: bool = false


func _init(party_ids: Variant, deck_card_ids: Variant, owned_trinket_ids: Variant,
		gold: Variant, card_offers: Variant, trinket_offers: Variant,
		visit_kind: Variant = "shop") -> void:
	# Validate before publishing any partial state.
	if typeof(party_ids) != TYPE_ARRAY or party_ids.size() != 3:
		return
	if typeof(deck_card_ids) != TYPE_ARRAY or typeof(owned_trinket_ids) != TYPE_ARRAY:
		return
	if typeof(gold) != TYPE_INT or gold < 0:
		return
	if not visit_kind is String or not visit_kind in ["shop", "patch_stall", "peddler"]:
		return
	if typeof(card_offers) != TYPE_ARRAY or typeof(trinket_offers) != TYPE_ARRAY:
		return
	if visit_kind == "shop":
		if card_offers.size() != 5 or trinket_offers.size() != 2:
			return
	elif visit_kind == "patch_stall":
		if card_offers.size() != 0 or trinket_offers.size() != 3:
			return
	else:
		if card_offers.size() != 3 or trinket_offers.size() != 1:
			return

	var party_seen := {}
	for hero_id in party_ids:
		if not _is_id(hero_id) or party_seen.has(hero_id):
			return
		party_seen[hero_id] = true
	for card_id in deck_card_ids:
		if not _is_id(card_id):
			return
	var owned_seen := {}
	for trinket_id in owned_trinket_ids:
		if not _is_id(trinket_id) or owned_seen.has(trinket_id):
			return
		owned_seen[trinket_id] = true

	var copied_cards: Array = []
	var card_seen := {}
	var card_owners_seen := {}
	for value in card_offers:
		if typeof(value) != TYPE_DICTIONARY:
			return
		var offer: Dictionary = value
		if offer.size() != 3 or not offer.has("id") or not offer.has("owner") or not offer.has("price"):
			return
		if not _is_id(offer["id"]) or not _is_id(offer["owner"]):
			return
		if card_seen.has(offer["id"]) or not party_seen.has(offer["owner"]):
			return
		if not _is_price(offer["price"]):
			return
		if visit_kind == "peddler" and card_owners_seen.has(offer["owner"]):
			return
		card_owners_seen[offer["owner"]] = true
		card_seen[offer["id"]] = true
		copied_cards.append({
			"id": offer["id"], "owner": offer["owner"],
			"price": offer["price"], "sold": false
		})

	var copied_trinkets: Array = []
	var trinket_seen := {}
	for value in trinket_offers:
		if typeof(value) != TYPE_DICTIONARY:
			return
		var offer: Dictionary = value
		if offer.size() != 2 or not offer.has("id") or not offer.has("price"):
			return
		if not _is_id(offer["id"]) or trinket_seen.has(offer["id"]):
			return
		if not _is_price(offer["price"]):
			return
		trinket_seen[offer["id"]] = true
		copied_trinkets.append({
			"id": offer["id"], "price": offer["price"], "sold": owned_trinket_ids.has(offer["id"])
		})

	_state = {
		"party_ids": party_ids.duplicate(true),
		"deck": deck_card_ids.duplicate(true),
		"trinkets": owned_trinket_ids.duplicate(true),
		"gold": gold
	}
	_stock = {"cards": copied_cards, "trinkets": copied_trinkets}
	_visit_kind = visit_kind
	_choice_used = false
	_valid = true


## Static sampling helper for Patch Stall deterministic three-patch selection.
## Accepts the actual run RandomNumberGenerator, candidate records read by
## its caller from data/shop/initial_offers.json, and owned patch IDs.
## Returns exactly three distinct, unowned, catalog-authored power patches
## with their authored positive gold prices; never the inert starter
## slots (stitched_badge, spare_spool). On failure, no RNG is advanced.
static func sample_patch_stall_offers(rng: Variant, candidates: Variant,
		owned_ids: Variant) -> Dictionary:
	# Preflight all inputs without touching the RNG.
	if not rng is RandomNumberGenerator:
		return {"ok": false}
	if typeof(candidates) != TYPE_ARRAY or candidates.is_empty():
		print("FAIL: candidates invalid or empty, type=", typeof(candidates), ", empty=", candidates.is_empty())
		return {"ok": false}
	if typeof(owned_ids) != TYPE_ARRAY:
		print("FAIL: owned_ids not array, type=", typeof(owned_ids))
		return {"ok": false}

	# Load real power definitions; reject if any catalog is missing or invalid.
	var powers := RunAuthoredPatchDefinitions.load_power_definitions()
	if powers == null or typeof(powers) != TYPE_ARRAY or powers.is_empty():
		print("FAIL: powers empty or invalid, powers=", powers)
		return {"ok": false}

	var power_ids: Dictionary = {}
	for entry in powers:
		if not entry is Dictionary or not entry.has("id") or not entry.has("slot"):
			return {"ok": false}
		var id: Variant = entry["id"]
		if not _is_id(str(id)):
			return {"ok": false}
		power_ids[str(id)] = true

	# Validate owned IDs are strings.
	var owned_set: Dictionary = {}
	for id in owned_ids:
		if not _is_id(id):
			return {"ok": false}
		owned_set[str(id)] = true

	# Filter candidates to eligible unowned powers with positive authored prices.
	var eligible: Array = []
	var eligible_price_map: Dictionary = {}
	for value in candidates:
		if typeof(value) != TYPE_DICTIONARY:
			return {"ok": false}
		if not value.has("id") or not value.has("price"):
			return {"ok": false}
		var id_str: String = str(value["id"])
		var price: Variant = value["price"]
		if id_str.is_empty() or price == null:
			return {"ok": false}
		if not power_ids.has(id_str) or owned_set.has(id_str):
			continue
		if typeof(price) != TYPE_INT and not (typeof(price) == TYPE_FLOAT and price == int(price) and price > 0):
			return {"ok": false}
		# Ensure no duplicate eligible IDs.
		if eligible.has(id_str) or eligible_price_map.has(id_str):
			return {"ok": false}
		eligible.append(id_str)
		eligible_price_map[id_str] = int(price)

	# Must have at least three eligible candidates to draw three without replacement.
	print("ELIGIBLE COUNT BEFORE CHECK: ", eligible.size())
	if eligible.size() < 3:
		return {"ok": false}

	# Sort eligible IDs for deterministic input-order independence.
	eligible.sort()

	# Draw three distinct IDs without replacement using the supplied RNG.
	var selected_ids: Array = []
	var remaining: Array = eligible.duplicate(true)
	for i in range(3):
		if remaining.is_empty():
			return {"ok": false}
		var index: int = rng.randi_range(0, remaining.size() - 1)
		selected_ids.append(remaining[index])
		remaining.remove_at(index)

	# Build the three offer records in sorted selection order.
	var offers: Array = []
	for id_str in selected_ids:
		offers.append({"id": id_str, "price": eligible_price_map[id_str]})

	print("ABOUT TO RETURN SUCCESS, offers_size=", offers.size())
	return {"ok": true, "offers": offers}


static func _is_id(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not value.strip_edges().is_empty()


static func _is_price(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0


func is_valid() -> bool:
	return _valid


func get_stock() -> Dictionary:
	return _stock.duplicate(true)


func get_state() -> Dictionary:
	return _state.duplicate(true)


## True only once a Patch Stall visit has committed its one permitted patch
## purchase. A normal Shop always reports false: it allows many purchases.
func patch_stall_choice_used() -> bool:
	return _visit_kind == "patch_stall" and _choice_used


## Preflight the exact helper transition against this purchase ledger. A visit
## can rebase once; no caller-supplied price or partial snapshot is trusted.
##
## A stitched visit snapshot carries BOTH "descriptors" and "next_stitch_id",
## so the authentic receipt is the seven-key stitch-ledger transition: its
## registry and allocator cursor come from the visit that owns them, while the
## deck, gold and removal count are checked against this purchase ledger. A
## snapshot with NEITHER field keeps the exact legacy five-key contract, and a
## mixed or malformed field set is refused outright.
func can_rebase_removal(before: Variant, result: Variant, card_id: Variant) -> bool:
	if not _valid or _visit_kind != "shop" or _removal_rebased \
			or not before is Dictionary or not result is Dictionary or not _is_id(card_id):
		return false
	if not before.get("valid") is bool or before.get("valid") != true \
		or before.get("status") != "available" or not before.get("removal_available") is bool or before.get("removal_available") != true:
		return false
	if not before.get("gold") is int or before.get("deck") != _state.deck or before.get("gold") != _state.gold or before.get("trinkets") != _state.trinkets:
		return false
	if not result.get("ok") is bool or not result.get("price") is int \
		or not result.get("gold") is int or not result.get("prior_removals") is int:
		return false
	var count: Variant = before.get("prior_removals")
	if not count is int or count < 0:
		return false
	var has_descriptors: bool = before.has("descriptors")
	var has_cursor: bool = before.has("next_stitch_id")
	if has_descriptors != has_cursor:
		return false
	var cards: Array[String] = []
	cards.assign(_state.deck)
	var expected: Dictionary
	if has_descriptors:
		var descriptors: Variant = before["descriptors"]
		var cursor: Variant = before["next_stitch_id"]
		if not descriptors is Dictionary or not cursor is int:
			return false
		expected = RunShopCardRemoval.try_remove_with_stitch_ledger(
				cards, descriptors, cursor, _state.gold, count, card_id)
	else:
		expected = RunShopCardRemoval.try_remove(cards, _state.gold, count, card_id)
	return expected.ok and result == expected


func rebase_removal(before: Variant, result: Variant, card_id: Variant) -> bool:
	if not can_rebase_removal(before, result, card_id):
		return false
	_state.deck = result.deck.duplicate(true)
	_state.gold = result.gold
	_removal_rebased = true
	return true


func buy(kind: String, id: String) -> Dictionary:
	if not _valid or not (kind == "card" or kind == "trinket") or not _is_id(id):
		return _result(false)
	# Single-choice visits latch only after a successful purchase.
	if _visit_kind != "shop" and _choice_used:
		return _result(false)
	if _visit_kind == "patch_stall" and kind != "trinket":
		return _result(false)

	var category: String = "cards" if kind == "card" else "trinkets"
	var destination: String = "deck" if kind == "card" else "trinkets"
	var listings: Array = _stock[category]
	for listing in listings:
		if listing["id"] != id:
			continue
		if listing["sold"] or _state["gold"] < listing["price"]:
			return _result(false)
		_state["gold"] -= listing["price"]
		_state[destination].append(id)
		listing["sold"] = true
		if _visit_kind != "shop":
			_choice_used = true
		return _result(true, {"kind": kind, "id": id, "price": listing["price"]})
	return _result(false)


func _result(success: bool, paid_receipt: Dictionary = {}) -> Dictionary:
	var result := {"ok": success, "state": get_state(), "stock": get_stock()}
	if success:
		result["receipt"] = paid_receipt.duplicate(true)
	return result


## After a genuine wardrobe replacement, reconcile the destroyed old patch.
## The new paid listing remains sold; no gold, deck or stock is reset.
## The coordinator calls this only with a freshly reconciled paid receipt.
func settle_displaced_patch(displaced_id: Variant, purchased_id: Variant,
		expected_state: Variant) -> bool:
	if not _valid or not (expected_state is Dictionary) or expected_state != get_state() \
			or not _is_id(displaced_id) or not _is_id(purchased_id) \
			or displaced_id == purchased_id:
		return false
	if not _state.trinkets.has(displaced_id) or not _state.trinkets.has(purchased_id):
		return false
	var matching_paid := false
	for listing in _stock.trinkets:
		if listing.id == purchased_id and listing.sold:
			matching_paid = true
	if not matching_paid:
		return false
	_state.trinkets.erase(displaced_id)
	return true
