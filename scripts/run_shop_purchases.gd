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


const RARE_CATALOG_PATH := "res://data/patches/mpw_synergy_patches.json"
## One ordinary eligible power patch is always worth this many tickets. A
## P8 rare's authored stock_weight_percent is a percentage of ONE ordinary
## patch's weight, never a share of the whole stock or a reserved slot.
const ORDINARY_PATCH_TICKETS := 100
const ORDINARY_WEIGHT_BASIS := "ordinary_patch"


## The shipped P8 rare records, or {"ok": false} when the catalog is missing
## or unparseable. The sampler fails closed instead of quietly stocking
## ordinary patches only.
static func _shipped_rare_records() -> Dictionary:
	if not FileAccess.file_exists(RARE_CATALOG_PATH):
		return {"ok": false}
	var text := FileAccess.get_file_as_string(RARE_CATALOG_PATH)
	if text.is_empty():
		return {"ok": false}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		return {"ok": false}
	return {"ok": true, "records": parsed}


## Static sampling helper for Patch Stall deterministic three-patch selection.
## Accepts the actual run RandomNumberGenerator, candidate records read by
## its caller from data/shop/initial_offers.json, owned patch IDs and,
## optionally, the authored P8 rare records (production passes nothing and the
## shipped catalog is loaded). Returns exactly three distinct, unowned,
## catalog-authored power patches with their authored positive gold prices;
## never the inert starter slots (stitched_badge, spare_spool).
##
## Every eligible ordinary patch carries ORDINARY_PATCH_TICKETS tickets; every
## eligible unowned P8 rare carries its authored percentage of one ordinary
## patch (10 tickets for the shipped 10%). Three tickets are drawn without
## replacement from the sorted eligible IDs, always through the supplied run
## RNG. All inputs and catalog fields are validated before the first draw, and
## on failure no RNG is advanced.
static func sample_patch_stall_offers(rng: Variant, candidates: Variant,
		owned_ids: Variant, rare_records: Variant = null) -> Dictionary:
	# Preflight all inputs without touching the RNG.
	if not rng is RandomNumberGenerator:
		return {"ok": false}
	if typeof(candidates) != TYPE_ARRAY or candidates.is_empty():
		return {"ok": false}
	if typeof(owned_ids) != TYPE_ARRAY:
		return {"ok": false}

	# Load real power definitions; reject if any catalog is missing or invalid.
	var powers := RunAuthoredPatchDefinitions.load_power_definitions()
	if typeof(powers) != TYPE_ARRAY or powers.is_empty():
		return {"ok": false}

	var power_slots: Dictionary = {}
	for entry in powers:
		if not entry is Dictionary or not entry.has("id") or not entry.has("slot"):
			return {"ok": false}
		var id: Variant = entry["id"]
		var slot: Variant = entry["slot"]
		if not _is_id(id) or typeof(slot) != TYPE_STRING or power_slots.has(id):
			return {"ok": false}
		power_slots[id] = slot

	# Validate owned IDs are strings.
	var owned_set: Dictionary = {}
	for id in owned_ids:
		if not _is_id(id):
			return {"ok": false}
		owned_set[str(id)] = true

	# Validate the P8 rare records (shipped by default) before any draw. A
	# malformed rare record refuses the whole stall rather than falling back
	# to an unauthored or merely ordinary item.
	var rare_source: Variant = rare_records
	if rare_source == null:
		var shipped := _shipped_rare_records()
		if shipped.get("ok") != true:
			return {"ok": false}
		rare_source = shipped["records"]
	if typeof(rare_source) != TYPE_ARRAY:
		return {"ok": false}
	var rare_tickets: Dictionary = {}
	var rare_prices: Dictionary = {}
	for value in rare_source:
		if typeof(value) != TYPE_DICTIONARY:
			return {"ok": false}
		var record: Dictionary = value
		var rare_id: Variant = record.get("id")
		var rare_slot: Variant = record.get("slot")
		if not _is_id(rare_id) or typeof(rare_slot) != TYPE_STRING:
			return {"ok": false}
		if not power_slots.has(rare_id) or power_slots[rare_id] != rare_slot:
			return {"ok": false}
		if rare_tickets.has(rare_id):
			return {"ok": false}
		if record.get("rarity") != "rare" \
				or record.get("stock_weight_basis") != ORDINARY_WEIGHT_BASIS \
				or record.get("stock_competes_for_existing_slot") != true:
			return {"ok": false}
		var rare_price: Variant = _positive_int(record.get("shop_price_gold"))
		var rare_percent: Variant = _positive_int(record.get("stock_weight_percent"))
		if rare_price == null or rare_percent == null:
			return {"ok": false}
		var tickets: int = ORDINARY_PATCH_TICKETS * rare_percent / 100
		if tickets <= 0:
			return {"ok": false}
		rare_tickets[rare_id] = tickets
		rare_prices[rare_id] = rare_price

	# Validate every supplied candidate, then keep the eligible unowned powers.
	var weights: Dictionary = {}
	var prices: Dictionary = {}
	for value in candidates:
		if typeof(value) != TYPE_DICTIONARY:
			return {"ok": false}
		var offer: Dictionary = value
		if not offer.has("id") or not offer.has("price"):
			return {"ok": false}
		var id_str: Variant = offer["id"]
		var price: Variant = _positive_int(offer["price"])
		if not _is_id(id_str) or price == null:
			return {"ok": false}
		if owned_set.has(id_str) or not power_slots.has(id_str):
			continue
		# A rare listed among ordinary data stays one rare entry at its
		# authored rare price and weight, never a duplicate ordinary ticket.
		if rare_tickets.has(id_str):
			continue
		if weights.has(id_str):
			return {"ok": false}
		weights[id_str] = ORDINARY_PATCH_TICKETS
		prices[id_str] = price

	# Admit each unowned rare from its validated catalog record. Ordinary
	# data never needs to list it, and owning it removes it from the pool.
	for rare_id in rare_tickets:
		if owned_set.has(rare_id):
			continue
		weights[rare_id] = rare_tickets[rare_id]
		prices[rare_id] = rare_prices[rare_id]

	# Three distinct IDs are required; otherwise no draw may be consumed.
	var remaining: Array = weights.keys()
	if remaining.size() < 3:
		return {"ok": false}

	# Sort eligible IDs for deterministic input-order independence.
	remaining.sort()

	# Draw three tickets without replacement using the supplied RNG.
	var selected_ids: Array = []
	var total := 0
	for id in remaining:
		total += weights[id]
	for i in range(3):
		if total <= 0 or remaining.is_empty():
			return {"ok": false}
		var ticket: int = rng.randi_range(0, total - 1)
		var chosen := ""
		var walked := 0
		for id in remaining:
			walked += weights[id]
			if ticket < walked:
				chosen = id
				break
		if chosen.is_empty():
			return {"ok": false}
		selected_ids.append(chosen)
		total -= weights[chosen]
		remaining.erase(chosen)

	# Build the three offer records in selection order.
	var offers: Array = []
	for id_str in selected_ids:
		offers.append({"id": id_str, "price": prices[id_str]})
	return {"ok": true, "offers": offers}


static func _is_id(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not value.strip_edges().is_empty()


## Authored JSON numbers parse as floats, so a whole positive price, weight or
## percentage is accepted as either an integer or an integral float.
static func _positive_int(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value if value > 0 else null
	if typeof(value) == TYPE_FLOAT and value == floor(value) and value > 0:
		return int(value)
	return null


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
