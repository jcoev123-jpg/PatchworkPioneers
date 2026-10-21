extends SceneTree
## Headless M04 Shop stock generation: the shipped Warden/Seamstress/Tinker
## party, the real StarterCards catalog, priced candidate pools, an
## independent sorted-pool RNG oracle, a real RunShopPurchases visit and
## fail-closed rejection paths. No live Shop screen is involved.

var failures: Array[String] = []
var checks: int = 0
const SEED: int = 55021
## Trinket IDs and prices are supplied by the caller and are not authored
## content; these fixture IDs only ever appear in this test.
const FIXTURE_TRINKETS := {
	"fixture_pin_badge": 90,
	"fixture_spare_spool": 110,
	"fixture_brass_button": 120,
	"fixture_owned_charm": 85,
}
## Authored starter cards that the shop has no price for yet get a fixture
## price in the candidate pool; the generator only ever uses the supplied one.
const FIXTURE_CARD_PRICES := {
	"warden_brace": 40,
	"seamstress_mend": 45,
	"seamstress_stitch_up": 45,
	"tinker_tune_up": 35,
}
const DEFAULT_FIXTURE_PRICE := 50


func _initialize() -> void:
	var party := _load_party()
	var deck := _load_deck()
	var catalog := StarterCards.new()
	_check(party.size() == 3 and party.has("warden") and party.has("seamstress") and party.has("tinker"),
		"real starter party contains the three distinct active heroes")
	var deck_is_authored := deck.size() > 0
	for card_id in deck:
		if not catalog.has_card(card_id):
			deck_is_authored = false
	_check(deck_is_authored, "the authored starter deck holds real catalog cards")
	if party.size() == 3 and deck.size() > 0:
		_test_generated_stock(party, deck, catalog)
		_test_seeded_replay(party, catalog)
		_test_purchases(party, deck, catalog)
		_test_rejections(party, catalog)
	else:
		_check(false, "preconditions for non-vacuous shop stock tests failed")
	if failures.is_empty():
		print("run_shop_stock_offers_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_shop_stock_offers_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


func _load_party() -> Array[String]:
	var result: Array[String] = []
	var file := FileAccess.open("res://data/heroes/starter_party.json", FileAccess.READ)
	_check(file != null, "starter_party.json opened")
	if file == null:
		return result
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	_check(data is Array, "starter party is JSON array")
	if data is Array:
		for hero in data:
			if hero is Dictionary and hero.get("id") is String:
				result.append(hero["id"])
	return result


func _load_deck() -> Array[String]:
	var result: Array[String] = []
	var file := FileAccess.open("res://data/cards/starter_deck.json", FileAccess.READ)
	_check(file != null, "starter_deck.json opened")
	if file == null:
		return result
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	_check(data is Array, "starter deck is JSON array")
	if data is Array:
		for id in data:
			if id is String:
				result.append(id)
	return result


func _catalog_snapshot(catalog: StarterCards) -> Dictionary:
	var result := {}
	for card_id in catalog.get_all_card_ids():
		result[card_id] = catalog.get_definition(card_id)
	return result


func _rng(seed_value: int = SEED) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Reads a whole price out of JSON without truncating a fractional value.
func _whole_price(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return int(value) if value >= 0 else -1
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value >= 0.0 and value == floor(value):
		return int(value)
	return -1


## The authored shop pool, used only for the prices it already carries.
func _authored_shop_offers() -> Dictionary:
	var file := FileAccess.open("res://data/shop/initial_offers.json", FileAccess.READ)
	if file == null:
		return {}
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	return data if data is Dictionary else {}


## A priced candidate pool of real authored cards owned by the party.
func _card_pool(catalog: StarterCards, party: Array[String], authored: Dictionary) -> Array:
	var authored_prices := {}
	for entry in authored.get("cards", []):
		if entry is Dictionary and entry.get("id") is String:
			var price := _whole_price(entry.get("price"))
			if price >= 0:
				authored_prices[entry["id"]] = price
	var pool: Array = []
	for card_id in catalog.get_all_card_ids():
		var definition: Dictionary = catalog.get_definition(card_id)
		var owner: String = definition.get("owner", "")
		if not party.has(owner):
			continue
		var price: int = authored_prices.get(card_id, FIXTURE_CARD_PRICES.get(card_id, DEFAULT_FIXTURE_PRICE))
		pool.append({"id": card_id, "owner": owner, "price": price})
	return pool


## A priced candidate pool of supplied trinket IDs.
func _trinket_pool(authored: Dictionary) -> Array:
	var pool: Array = []
	for entry in authored.get("trinkets", []):
		if entry is Dictionary and entry.get("id") is String:
			var price := _whole_price(entry.get("price"))
			if price >= 0:
				pool.append({"id": entry["id"], "price": price})
	for trinket_id in FIXTURE_TRINKETS:
		pool.append({"id": trinket_id, "price": FIXTURE_TRINKETS[trinket_id]})
	return pool


func _owned_trinkets() -> Array[String]:
	return ["fixture_owned_charm"]


func _pool_price(pool: Array, id: String) -> int:
	for entry in pool:
		if entry is Dictionary and entry.get("id") == id:
			return int(entry.get("price", -1))
	return -1


## A copy of the candidate pool with one entry replaced, so a malformed
## candidate is the only possible reason the whole call fails.
func _with_card(pool: Array, index: int, entry: Variant) -> Array:
	var copy := pool.duplicate(true)
	copy[index] = entry
	return copy


func _with_trinket(pool: Array, index: int, entry: Variant) -> Array:
	var copy := pool.duplicate(true)
	copy[index] = entry
	return copy


## An independent implementation of the expected stock: sorted pools, five
## card draws and then two trinket draws, each without replacement.
func _oracle(catalog: StarterCards, party: Array[String], card_pool: Array, trinket_pool: Array,
		owned: Array, rng: RandomNumberGenerator) -> Dictionary:
	var card_ids: Array[String] = []
	for entry in card_pool:
		var card_id: String = entry["id"]
		if party.has(catalog.get_definition(card_id).get("owner", "")):
			card_ids.append(card_id)
	card_ids.sort()
	var cards: Array = []
	for _pick in range(5):
		var index: int = rng.randi_range(0, card_ids.size() - 1)
		var card_id: String = card_ids[index]
		card_ids.remove_at(index)
		var definition: Dictionary = catalog.get_definition(card_id)
		cards.append({"id": card_id, "owner": definition["owner"], "price": _pool_price(card_pool, card_id)})

	var trinket_ids: Array[String] = []
	for entry in trinket_pool:
		var trinket_id: String = entry["id"]
		if not owned.has(trinket_id):
			trinket_ids.append(trinket_id)
	trinket_ids.sort()
	var trinkets: Array = []
	for _pick in range(2):
		var index: int = rng.randi_range(0, trinket_ids.size() - 1)
		var trinket_id: String = trinket_ids[index]
		trinket_ids.remove_at(index)
		trinkets.append({"id": trinket_id, "price": _pool_price(trinket_pool, trinket_id)})
	return {"cards": cards, "trinkets": trinkets}


func _test_generated_stock(party: Array[String], deck: Array[String], catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var card_pool := _card_pool(catalog, party, authored)
	var trinket_pool := _trinket_pool(authored)
	var owned := _owned_trinkets()
	var unowned := 0
	for entry in trinket_pool:
		if not owned.has(entry["id"]):
			unowned += 1
	_check(card_pool.size() >= 5, "at least five party-owned priced card candidates are supplied")
	_check(unowned >= 2, "at least two unowned trinket candidates are supplied")
	_check(card_pool.size() > 5, "the card pool holds more than the five offered cards")
	_check(unowned > 2, "the trinket pool holds more than the two offered trinkets")

	var catalog_before := _catalog_snapshot(catalog)
	var card_pool_before := card_pool.duplicate(true)
	var trinket_pool_before := trinket_pool.duplicate(true)
	var owned_before := owned.duplicate(true)
	var rng := _rng()
	var result: Dictionary = RunShopStockOffers.generate(rng, party, card_pool, trinket_pool, owned)
	_check(result.get("ok", false), "valid pools generate a stock")
	var cards: Array = result.get("cards", [])
	var trinkets: Array = result.get("trinkets", [])
	_check(cards.size() == 5, "exactly five card offers")
	_check(trinkets.size() == 2, "exactly two trinket offers")

	var card_ids: Array[String] = []
	for offer in cards:
		_check(offer is Dictionary and offer.size() == 3, "card offer holds only id, owner and price")
		var card_id: String = offer.get("id", "")
		card_ids.append(card_id)
		var definition: Dictionary = catalog.get_definition(card_id)
		_check(not definition.is_empty(), "offered card exists in the authored catalog: " + card_id)
		_check(offer.get("owner") == definition.get("owner"), "offer uses the catalog owner: " + card_id)
		_check(party.has(offer.get("owner")), "offered card belongs to the party: " + card_id)
		_check(offer.get("price") == _pool_price(card_pool, card_id),
			"offer keeps the supplied price: " + card_id)
	_check(card_ids.size() == 5 and card_ids[0] != card_ids[1] and card_ids[0] != card_ids[2]
			and card_ids[0] != card_ids[3] and card_ids[0] != card_ids[4]
			and card_ids[1] != card_ids[2] and card_ids[1] != card_ids[3] and card_ids[1] != card_ids[4]
			and card_ids[2] != card_ids[3] and card_ids[2] != card_ids[4] and card_ids[3] != card_ids[4],
		"all five offered card IDs are distinct")

	var trinket_ids: Array[String] = []
	for offer in trinkets:
		_check(offer is Dictionary and offer.size() == 2, "trinket offer holds only id and price")
		var trinket_id: String = offer.get("id", "")
		trinket_ids.append(trinket_id)
		_check(not owned.has(trinket_id), "an already owned trinket is never offered: " + trinket_id)
		_check(offer.get("price") == _pool_price(trinket_pool, trinket_id),
			"trinket offer keeps the supplied price: " + trinket_id)
	_check(trinket_ids.size() == 2 and trinket_ids[0] != trinket_ids[1],
		"the two offered trinket IDs are distinct")
	_check(not trinket_ids.has("fixture_owned_charm"), "the owned trinket in the pool is excluded")

	# The generated stock has to be a real shop visit, not just data.
	var purchases := RunShopPurchases.new(party, deck, owned, 400, cards, trinkets)
	_check(purchases.is_valid(), "generated stock constructs a valid RunShopPurchases visit")
	var stock: Dictionary = purchases.get_stock()
	_check(stock.get("cards", []).size() == 5 and stock.get("trinkets", []).size() == 2,
		"the shop visit holds the seven generated offers")
	for index in range(cards.size()):
		var listed: Dictionary = stock["cards"][index]
		var offered: Dictionary = cards[index]
		_check(listed["id"] == offered["id"] and listed["owner"] == offered["owner"]
			and listed["price"] == offered["price"] and listed["sold"] == false,
			"the shop visit lists the generated card offer unchanged: " + str(offered.get("id", "")))
	for index in range(trinkets.size()):
		var listed: Dictionary = stock["trinkets"][index]
		var offered: Dictionary = trinkets[index]
		_check(listed["id"] == offered["id"] and listed["price"] == offered["price"]
			and listed["sold"] == false,
			"the shop visit lists the generated trinket offer unchanged: " + str(offered.get("id", "")))
	_check(purchases.get_state()["deck"] == deck and purchases.get_state()["trinkets"] == owned
		and purchases.get_state()["gold"] == 400, "the shop visit starts from the supplied run state")

	_check(catalog_before == _catalog_snapshot(catalog), "the whole authored catalog remains untouched")
	_check(card_pool == card_pool_before, "the supplied card pool is unchanged")
	_check(trinket_pool == trinket_pool_before, "the supplied trinket pool is unchanged")
	_check(owned == owned_before, "the supplied owned trinket list is unchanged")

	# A whole JSON price is accepted and normalised to the integer the shop
	# visit requires; a fractional price is rejected instead of truncated.
	var float_pool := card_pool.duplicate(true)
	for entry in float_pool:
		entry["price"] = float(entry["price"])
	var float_result: Dictionary = RunShopStockOffers.generate(_rng(SEED + 7), party, float_pool,
		trinket_pool, owned)
	_check(float_result.get("ok", false), "whole float prices are accepted")
	for offer in float_result.get("cards", []):
		_check(typeof(offer.get("price")) == TYPE_INT, "an accepted price is a whole integer")
		_check(offer.get("price") == _pool_price(card_pool, offer.get("id", "")),
			"a whole float price keeps its value: " + str(offer.get("id", "")))


func _test_seeded_replay(party: Array[String], catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var card_pool := _card_pool(catalog, party, authored)
	var trinket_pool := _trinket_pool(authored)
	var owned := _owned_trinkets()
	var reordered_cards := card_pool.duplicate(true)
	reordered_cards.reverse()
	var reordered_trinkets := trinket_pool.duplicate(true)
	reordered_trinkets.reverse()

	var rng_a := _rng()
	var rng_b := _rng()
	var oracle_rng := _rng()
	var first: Dictionary = RunShopStockOffers.generate(rng_a, party, card_pool, trinket_pool, owned)
	var second: Dictionary = RunShopStockOffers.generate(rng_b, party, reordered_cards, reordered_trinkets, owned)
	_check(first.get("ok", false) and second.get("ok", false), "both candidate orders generate")
	_check(first.get("cards", []) == second.get("cards", []),
		"a reordered card pool produces the same card offers")
	_check(first.get("trinkets", []) == second.get("trinkets", []),
		"a reordered trinket pool produces the same trinket offers")
	_check(rng_a.state == rng_b.state, "both runs leave the same run RNG state")

	var oracle := _oracle(catalog, party, card_pool, trinket_pool, owned, oracle_rng)
	_check(first.get("cards", []) == oracle["cards"],
		"the card offers match an independent sorted-pool oracle")
	_check(first.get("trinkets", []) == oracle["trinkets"],
		"the trinket offers match an independent sorted-pool oracle")
	_check(rng_a.state == oracle_rng.state, "five card draws and two trinket draws leave the oracle RNG state")
	_check(rng_a.randi() == oracle_rng.randi(), "the next RNG draw still matches the oracle")

	# The global RNG stream is never a source of shop stock.
	seed(91513)
	var expected_global := randi()
	seed(91513)
	RunShopStockOffers.generate(_rng(), party, card_pool, trinket_pool, owned)
	_check(randi() == expected_global, "generation never touches the global RNG")


func _test_purchases(party: Array[String], deck: Array[String], catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var card_pool := _card_pool(catalog, party, authored)
	var trinket_pool := _trinket_pool(authored)
	var owned := _owned_trinkets()
	var result: Dictionary = RunShopStockOffers.generate(_rng(SEED + 3), party, card_pool, trinket_pool, owned)
	_check(result.get("ok", false), "stock generated for the purchase test")
	if not result.get("ok", false):
		return
	var cards: Array = result["cards"]
	var trinkets: Array = result["trinkets"]
	var purchases := RunShopPurchases.new(party, deck, owned, 400, cards, trinkets)
	_check(purchases.is_valid(), "the generated stock opens a valid shop visit")

	var card_offer: Dictionary = cards[0]
	var trinket_offer: Dictionary = trinkets[0]
	_check(catalog.has_card(card_offer["id"]), "the bought card offer is an authored card")

	# One paid card purchase appends exactly one card and charges its price.
	var before_state := purchases.get_state()
	var before_stock := purchases.get_stock()
	var buy_card := purchases.buy("card", card_offer["id"])
	_check(buy_card.get("ok", false), "the offered card can be bought")
	var after_state := purchases.get_state()
	var after_stock := purchases.get_stock()
	_check(after_state["deck"].size() == before_state["deck"].size() + 1, "one card is appended")
	_check(after_state["deck"].back() == card_offer["id"], "the appended card is the offered card")
	_check(after_state["deck"].slice(0, before_state["deck"].size()) == before_state["deck"],
		"the rest of the deck is unchanged")
	_check(after_state["gold"] == before_state["gold"] - card_offer["price"], "the card price is charged")
	_check(after_state["trinkets"] == before_state["trinkets"], "a card purchase adds no trinket")
	_check(after_state["gold"] >= 0, "gold stays non-negative after a card purchase")
	_check(after_stock["cards"][0]["sold"] == true, "the bought card is marked sold")
	var other_cards_unsold := true
	for index in range(1, after_stock["cards"].size()):
		if after_stock["cards"][index]["sold"]:
			other_cards_unsold = false
	_check(other_cards_unsold, "only the bought card is marked sold")
	_check(not after_stock["trinkets"][0]["sold"] and not after_stock["trinkets"][1]["sold"],
		"no trinket is marked sold by a card purchase")

	# One paid trinket purchase appends exactly one trinket and charges its price.
	var mid_state := purchases.get_state()
	var mid_stock := purchases.get_stock()
	var buy_trinket := purchases.buy("trinket", trinket_offer["id"])
	_check(buy_trinket.get("ok", false), "the offered trinket can be bought")
	var bought_state := purchases.get_state()
	var bought_stock := purchases.get_stock()
	_check(bought_state["trinkets"].size() == mid_state["trinkets"].size() + 1, "one trinket is appended")
	_check(bought_state["trinkets"].back() == trinket_offer["id"], "the appended trinket is the offered trinket")
	_check(bought_state["trinkets"].slice(0, mid_state["trinkets"].size()) == mid_state["trinkets"],
		"the owned trinkets are unchanged")
	_check(bought_state["gold"] == mid_state["gold"] - trinket_offer["price"], "the trinket price is charged")
	_check(bought_state["deck"] == mid_state["deck"], "a trinket purchase adds no card")
	_check(bought_state["gold"] >= 0, "gold stays non-negative after a trinket purchase")
	_check(bought_stock["trinkets"][0]["sold"] == true, "the bought trinket is marked sold")
	_check(not bought_stock["trinkets"][1]["sold"], "only the bought trinket is marked sold")
	_check(bought_stock["cards"][0]["sold"] and not bought_stock["cards"][1]["sold"]
		and not bought_stock["cards"][2]["sold"] and not bought_stock["cards"][3]["sold"]
		and not bought_stock["cards"][4]["sold"], "the earlier card sale is unchanged by a trinket purchase")

	# Repeated, unknown and unaffordable purchases change nothing.
	var repeat_state := purchases.get_state()
	var repeat_stock := purchases.get_stock()
	var repeat_card := purchases.buy("card", card_offer["id"])
	_check(not repeat_card.get("ok", true), "a card cannot be bought twice")
	_check(purchases.get_state() == repeat_state and purchases.get_stock() == repeat_stock,
		"a repeated purchase leaves deck, trinkets, gold and stock unchanged")
	var unknown_card := purchases.buy("card", "__not_in_stock__")
	_check(not unknown_card.get("ok", true), "an unknown card is refused")
	var unknown_trinket := purchases.buy("trinket", "__unknown_trinket__")
	_check(not unknown_trinket.get("ok", true), "an unknown trinket is refused")
	var wrong_kind := purchases.buy("trinket", card_offer["id"])
	_check(not wrong_kind.get("ok", true), "a card ID cannot be bought as a trinket")
	_check(purchases.get_state() == repeat_state and purchases.get_stock() == repeat_stock,
		"refused purchases leave deck, trinkets, gold and stock unchanged")

	# A visit without gold refuses every priced offer and keeps gold at zero.
	var poor := RunShopPurchases.new(party, deck, owned, 0, cards, trinkets)
	_check(poor.is_valid(), "a goldless shop visit is still valid")
	var poor_state := poor.get_state()
	var poor_stock := poor.get_stock()
	var denied := poor.buy("card", card_offer["id"])
	_check(not denied.get("ok", true), "an unaffordable card purchase is refused")
	var denied_trinket := poor.buy("trinket", trinket_offer["id"])
	_check(not denied_trinket.get("ok", true), "an unaffordable trinket purchase is refused")
	_check(poor.get_state() == poor_state and poor.get_stock() == poor_stock,
		"an unaffordable purchase leaves deck, trinkets, gold and stock unchanged")
	_check(poor.get_state()["gold"] == 0, "gold never becomes negative")


func _reject(label: String, rng_input: Variant, party_input: Variant, cards_input: Variant,
		trinkets_input: Variant, owned_input: Variant) -> void:
	var state_before: int = rng_input.state if rng_input is RandomNumberGenerator else -1
	var party_before = party_input.duplicate(true) if party_input is Array else party_input
	var cards_before = cards_input.duplicate(true) if cards_input is Array else cards_input
	var trinkets_before = trinkets_input.duplicate(true) if trinkets_input is Array else trinkets_input
	var owned_before = owned_input.duplicate(true) if owned_input is Array else owned_input
	var global_expected := -1
	if not (rng_input is RandomNumberGenerator):
		seed(48213)
		global_expected = randi()
		seed(48213)
	var result: Dictionary = RunShopStockOffers.generate(rng_input, party_input, cards_input,
		trinkets_input, owned_input)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("cards", ["bad"]).is_empty() and result.get("trinkets", ["bad"]).is_empty(),
		label + ": no offers are published")
	if rng_input is RandomNumberGenerator:
		_check(rng_input.state == state_before, label + ": no RNG is consumed")
	if global_expected >= 0:
		_check(randi() == global_expected, label + ": the global RNG is untouched")
	_check(party_input == party_before, label + ": the party is unchanged")
	_check(cards_input == cards_before, label + ": the card candidates are unchanged")
	_check(trinkets_input == trinkets_before, label + ": the trinket candidates are unchanged")
	_check(owned_input == owned_before, label + ": the owned trinkets are unchanged")


func _test_rejections(party: Array[String], catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var card_pool := _card_pool(catalog, party, authored)
	var trinket_pool := _trinket_pool(authored)
	var owned := _owned_trinkets()
	var catalog_before := _catalog_snapshot(catalog)

	_reject("null RNG", null, party, card_pool, trinket_pool, owned)
	_reject("wrong-type RNG", RefCounted.new(), party, card_pool, trinket_pool, owned)

	_reject("party too small", _rng(), party.slice(0, 2), card_pool, trinket_pool, owned)
	_reject("duplicate party", _rng(), [party[0], party[0], party[2]], card_pool, trinket_pool, owned)
	_reject("empty party id", _rng(), [party[0], "", party[2]], card_pool, trinket_pool, owned)
	_reject("whitespace party id", _rng(), [party[0], "  ", party[2]], card_pool, trinket_pool, owned)
	_reject("numeric party id", _rng(), [party[0], 17, party[2]], card_pool, trinket_pool, owned)
	_reject("unknown party id", _rng(), [party[0], party[1], "__unknown_hero__"], card_pool, trinket_pool, owned)
	_reject("null party", _rng(), null, card_pool, trinket_pool, owned)
	_reject("nonarray party", _rng(), "warden", card_pool, trinket_pool, owned)

	_reject("null card pool", _rng(), party, null, trinket_pool, owned)
	_reject("nonarray card pool", _rng(), party, {}, trinket_pool, owned)
	# Each malformed candidate replaces one entry of a full-size pool, so the
	# rejected rule is the only one that can fail the whole call.
	_reject("non-dictionary card candidate", _rng(), party,
		_with_card(card_pool, 0, "warden_strike"), trinket_pool, owned)
	_reject("card candidate without price", _rng(), party,
		_with_card(card_pool, 0, {"id": card_pool[0]["id"], "owner": card_pool[0]["owner"]}), trinket_pool, owned)
	_reject("card candidate without id", _rng(), party,
		_with_card(card_pool, 0, {"owner": card_pool[0]["owner"], "price": 50}), trinket_pool, owned)
	_reject("empty card candidate id", _rng(), party,
		_with_card(card_pool, 0, {"id": "", "price": 50}), trinket_pool, owned)
	_reject("whitespace card candidate id", _rng(), party,
		_with_card(card_pool, 0, {"id": "  ", "price": 50}), trinket_pool, owned)
	_reject("numeric card candidate id", _rng(), party,
		_with_card(card_pool, 0, {"id": 17, "price": 50}), trinket_pool, owned)
	_reject("unknown card candidate", _rng(), party,
		_with_card(card_pool, 0, {"id": "__unknown_card__", "price": 50}), trinket_pool, owned)
	_reject("duplicate card candidate", _rng(), party,
		_with_card(card_pool, 1, {"id": card_pool[0]["id"], "price": 60}), trinket_pool, owned)
	_reject("wrong-owner card candidate", _rng(), party,
		_with_card(card_pool, 0, {"id": card_pool[0]["id"], "owner": "__other_hero__", "price": 50}),
		trinket_pool, owned)
	for price in [-1, 12.5, "50", true, null]:
		_reject("invalid card price " + str(price), _rng(), party,
			_with_card(card_pool, 0, {"id": card_pool[0]["id"], "owner": card_pool[0]["owner"], "price": price}),
			trinket_pool, owned)
	_reject("too few card candidates", _rng(), party, card_pool.slice(0, 4), trinket_pool, owned)
	_reject("empty card pool", _rng(), party, [], trinket_pool, owned)

	# A catalog card owned by a hero outside the party is refused as soon as
	# the shared catalog grows one; never invent an unauthored card ID.
	var outsiders: Array[String] = []
	for card_id in catalog.get_all_card_ids():
		if not party.has(catalog.get_definition(card_id).get("owner", "")):
			outsiders.append(card_id)
	if outsiders.is_empty():
		_check(true, "the catalog has no outside-party card to inject; do not invent one")
	else:
		_reject("outside-party card candidate", _rng(), party,
			_with_card(card_pool, 0, {"id": outsiders[0], "price": 50}), trinket_pool, owned)

	_reject("null trinket pool", _rng(), party, card_pool, null, owned)
	_reject("nonarray trinket pool", _rng(), party, card_pool, "trinkets", owned)
	_reject("non-dictionary trinket candidate", _rng(), party, card_pool,
		_with_trinket(trinket_pool, 0, "fixture_pin_badge"), owned)
	_reject("trinket candidate without price", _rng(), party, card_pool,
		_with_trinket(trinket_pool, 0, {"id": "fixture_pin_badge"}), owned)
	_reject("trinket candidate without id", _rng(), party, card_pool,
		_with_trinket(trinket_pool, 0, {"price": 50}), owned)
	_reject("empty trinket candidate id", _rng(), party, card_pool,
		_with_trinket(trinket_pool, 0, {"id": "", "price": 50}), owned)
	_reject("numeric trinket candidate id", _rng(), party, card_pool,
		_with_trinket(trinket_pool, 0, {"id": 17, "price": 50}), owned)
	_reject("duplicate trinket candidate", _rng(), party, card_pool,
		_with_trinket(trinket_pool, 1, {"id": trinket_pool[0]["id"], "price": 60}), owned)
	for price in [-1, 12.5, "50", true, null]:
		_reject("invalid trinket price " + str(price), _rng(), party, card_pool,
			_with_trinket(trinket_pool, 0, {"id": trinket_pool[0]["id"], "price": price}), owned)
	_reject("too few unowned trinkets", _rng(), party, card_pool,
		[{"id": "fixture_pin_badge", "price": 50}, {"id": "fixture_owned_charm", "price": 60}], owned)
	_reject("empty trinket pool", _rng(), party, card_pool, [], owned)

	_reject("null owned trinkets", _rng(), party, card_pool, trinket_pool, null)
	_reject("nonarray owned trinkets", _rng(), party, card_pool, trinket_pool, "owned")
	_reject("numeric owned trinket", _rng(), party, card_pool, trinket_pool, [17])
	_reject("empty owned trinket id", _rng(), party, card_pool, trinket_pool, [""])

	_check(catalog_before == _catalog_snapshot(catalog), "the whole authored catalog survives every rejection")
