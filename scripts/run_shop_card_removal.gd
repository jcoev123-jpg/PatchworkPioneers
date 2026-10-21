class_name RunShopCardRemoval
extends RefCounted
## Scene-free paid removal of one card from a run deck. The caller owns gold and
## the removal count; this helper only validates and returns the next state.


const BASE_PRICE := 75
const PRICE_STEP := 25
const MAX_INT := 9223372036854775807


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


## Stitch-ledger-aware removal of one card from a run deck.
##
## The whole source ledger (deck, owned stitched descriptors and the allocator
## cursor) must satisfy the Rest stitch contract before any gold is quoted or
## spent; an illegal ledger is rejected and never silently pruned. The quote,
## the debit and the first-match deck removal are delegated to try_remove, so
## the established 75/100/125 pricing and single-copy behaviour are unchanged.
##
## A genuinely owned composite is retired in the same transaction: its deck
## entry AND its descriptor disappear together, so the run never keeps a
## descriptor for a card the player no longer owns. Ordinary cards leave the
## whole registry untouched. The allocator cursor never changes: a removed
## composite does not free its serial number, and no scraps are read or spent.
##
## The returned dictionary always has the same seven keys for successes and
## failures, and every container in it is detached from the caller's inputs.
static func try_remove_with_stitch_ledger(deck_ids: Variant, descriptors: Variant,
		next_stitch_id: Variant, gold: Variant, prior_removals: Variant, card_id: Variant) -> Dictionary:
	var deck_copy: Array[String] = []
	var deck_ok := typeof(deck_ids) == TYPE_ARRAY
	if deck_ok:
		for entry in deck_ids:
			if typeof(entry) != TYPE_STRING:
				deck_ok = false
				break
			deck_copy.append(entry)

	var descriptor_copy: Dictionary = {}
	var descriptors_ok := typeof(descriptors) == TYPE_DICTIONARY
	if descriptors_ok:
		descriptor_copy = descriptors.duplicate(true)

	var cursor := 0
	var cursor_is_int := typeof(next_stitch_id) == TYPE_INT
	if cursor_is_int:
		cursor = next_stitch_id

	var gold_value := 0
	var gold_is_int := typeof(gold) == TYPE_INT
	if gold_is_int:
		gold_value = gold

	var prior := 0
	var prior_is_int := typeof(prior_removals) == TYPE_INT
	if prior_is_int:
		prior = prior_removals

	var card := ""
	var card_ok := typeof(card_id) == TYPE_STRING
	if card_ok:
		card = card_id

	var price := BASE_PRICE + PRICE_STEP * prior
	# Fail closed on untrusted or negative inputs. The echoed snapshot repeats
	# the caller's numbers, so a rejected attempt shows exactly what was asked.
	if not deck_ok or not descriptors_ok or not cursor_is_int or not gold_is_int \
			or not prior_is_int or not card_ok \
			or gold_value < 0 or prior < 0 or cursor < 1 or cursor >= MAX_INT:
		return _ledger_result(false, price, deck_copy, descriptor_copy, cursor, gold_value, prior)

	# The complete source ledger must satisfy the Rest stitch contract. The
	# scrap pile is irrelevant here (a shop removal never spends scraps) and
	# the Rest service only validates currency shape, so zero is passed.
	var ledger := RunRestStitchCards.new(deck_copy, descriptor_copy, 0, cursor)
	if not ledger.is_valid():
		return _ledger_result(false, price, deck_copy, descriptor_copy, cursor, gold_value, prior)

	var base := try_remove(deck_copy, gold_value, prior, card)
	if not base["ok"]:
		return _ledger_result(false, base["price"], deck_copy, descriptor_copy, cursor,
				base["gold"], base["prior_removals"])

	var removed_deck: Array[String] = []
	removed_deck.assign(base["deck"])
	var next_descriptors := descriptor_copy.duplicate(true)
	# Only a genuinely owned composite retires its descriptor. The ledger check
	# above proved every registry key is an authentic owned composite, so a
	# name that merely starts with "stitched_" cannot pass here.
	if next_descriptors.has(card):
		next_descriptors.erase(card)
	return _ledger_result(true, base["price"], removed_deck, next_descriptors, cursor,
			base["gold"], base["prior_removals"])


## The stable seven-key receipt of a stitch-ledger-aware removal.
static func _ledger_result(ok: bool, price: int, deck: Array[String], descriptors: Dictionary,
		next_stitch_id: int, gold: int, prior_removals: int) -> Dictionary:
	return {
		"ok": ok,
		"price": price,
		"deck": deck,
		"descriptors": descriptors,
		"next_stitch_id": next_stitch_id,
		"gold": gold,
		"prior_removals": prior_removals,
	}