class_name RunShopPurchases
extends RefCounted
## One Shop visit's supplied five card and two trinket listings. No stock rolls,
## catalog lookups, passive effects, or card removal happen here.
##
## Construct with (party_ids, deck_card_ids, owned_trinket_ids, gold,
##                 card_offers, trinket_offers).
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


func _init(party_ids: Variant, deck_card_ids: Variant, owned_trinket_ids: Variant,
		gold: Variant, card_offers: Variant, trinket_offers: Variant) -> void:
	# Validate before publishing any partial state.
	if typeof(party_ids) != TYPE_ARRAY or party_ids.size() != 3:
		return
	if typeof(deck_card_ids) != TYPE_ARRAY or typeof(owned_trinket_ids) != TYPE_ARRAY:
		return
	if typeof(gold) != TYPE_INT or gold < 0:
		return
	if typeof(card_offers) != TYPE_ARRAY or card_offers.size() != 5:
		return
	if typeof(trinket_offers) != TYPE_ARRAY or trinket_offers.size() != 2:
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
	_valid = true


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


## Preflight the exact helper transition against this purchase ledger. A visit
## can rebase once; no caller-supplied price or partial snapshot is trusted.
func can_rebase_removal(before: Variant, result: Variant, card_id: Variant) -> bool:
	if not _valid or _removal_rebased or not before is Dictionary or not result is Dictionary or not _is_id(card_id):
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
	var cards: Array[String] = []
	cards.assign(_state.deck)
	var expected := RunShopCardRemoval.try_remove(cards, _state.gold, count, card_id)
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
		return _result(true, {"kind": kind, "id": id, "price": listing["price"]})
	return _result(false)


func _result(success: bool, paid_receipt: Dictionary = {}) -> Dictionary:
	var result := {"ok": success, "state": get_state(), "stock": get_stock()}
	if success:
		result["receipt"] = paid_receipt.duplicate(true)
	return result
