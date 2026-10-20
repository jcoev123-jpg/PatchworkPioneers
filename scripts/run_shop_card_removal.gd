class_name RunShopCardRemoval
extends RefCounted
## Scene-free paid removal of one card from a run deck. The caller owns gold and
## the removal count; this helper only validates and returns the next state.


const BASE_PRICE := 75
const PRICE_STEP := 25


## Remove one first matching card from a run deck. Returns a result dictionary
## with ok, price, deck, gold and prior_removals. The returned deck is always an
## independent copy; failed transactions leave deck, gold and count unchanged.
static func try_remove(deck_ids: Array[String], gold: int, prior_removals: int, card_id: String) -> Dictionary:
	var price := BASE_PRICE + PRICE_STEP * prior_removals

	var deck_copy: Array[String] = []
	deck_copy.assign(deck_ids)

	# Fail closed on invalid numeric inputs or an overflowed quote.
	if prior_removals < 0 or gold < 0 or price < BASE_PRICE:
		return {
			"ok": false,
			"price": price,
			"deck": deck_copy,
			"gold": gold,
			"prior_removals": prior_removals,
		}

	if card_id.is_empty():
		return {
			"ok": false,
			"price": price,
			"deck": deck_copy,
			"gold": gold,
			"prior_removals": prior_removals,
		}

	var index := deck_copy.find(card_id)
	if index < 0:
		return {
			"ok": false,
			"price": price,
			"deck": deck_copy,
			"gold": gold,
			"prior_removals": prior_removals,
		}

	if gold < price:
		return {
			"ok": false,
			"price": price,
			"deck": deck_copy,
			"gold": gold,
			"prior_removals": prior_removals,
		}

	deck_copy.remove_at(index)
	return {
		"ok": true,
		"price": price,
		"deck": deck_copy,
		"gold": gold - price,
		"prior_removals": prior_removals + 1,
	}