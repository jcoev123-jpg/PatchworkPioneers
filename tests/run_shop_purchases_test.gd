extends SceneTree

const PRICK := "seamstress_prick"
const POP := "tinker_pop_shot"
const MEND := "seamstress_mend"
const BOMB := "tinker_scrap_bomb"
const STRIKE := "warden_strike"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_contract_initial_snapshots()
	_test_reads_and_inputs_are_detached()
	_test_purchase_sequence()
	_test_owned_listings()
	_test_price_boundaries()
	_test_rejected_attempts()
	_test_invalid_visits()
	_test_replay_and_rng()
	_test_removal_rebase()
	_test_stitched_removal_rebase()
	_test_stitched_forged_receipts()
	_test_legacy_quote_and_rebase()
	_test_patch_stall_contract()
	_test_patch_stall_purchase()
	_test_patch_stall_rejections()
	_test_four_hero_patch_stall()
	_test_patch_stall_sampling()
	_test_peddler()
	if failures.is_empty():
		print("run_shop_purchases_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_shop_purchases_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _peddler(f: Dictionary) -> RunShopPurchases:
	return RunShopPurchases.new(f.party_ids, f.deck, f.trinkets, f.gold,
		f.cards, f.offers_trinkets, "peddler")


func _peddler_fixture(rng: RandomNumberGenerator, owned: Array = []) -> Dictionary:
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/shop/initial_offers.json"))
	var party := ["warden", "seamstress", "tinker"]
	var stock := RunShopStockOffers.generate_peddler_stock(
		rng, party, authored.cards, authored.trinkets, owned)
	_check(stock.ok and stock.cards.size() == 3 and stock.patches.size() == 1,
		"authentic seeded Peddler supplier succeeds")
	return {"party_ids": party, "deck": [STRIKE, PRICK, POP],
		"trinkets": owned.duplicate(), "gold": 500,
		"cards": stock.cards, "offers_trinkets": stock.patches}


func _peddler_refuses_removal(shop: RunShopPurchases) -> void:
	var state := shop.get_state()
	var stock := shop.get_stock()
	var cards: Array[String] = []
	cards.assign(state.deck)
	var owned: Array[String] = []
	owned.assign(state.trinkets)
	var visit := RunShopVisit.new(cards, state.gold, 0, owned)
	_check(visit.open_visit("peddler-removal"), "Peddler removal fixture opens")
	var before := visit.get_state()
	var result := RunShopCardRemoval.try_remove(cards, state.gold, 0, STRIKE)
	_check(result.ok and before.trinkets == state.trinkets,
		"Peddler removal receipt is otherwise legal and matches inventory")
	_check(not shop.can_rebase_removal(before, result, STRIKE), "Peddler removal preflight refused")
	_check(not shop.rebase_removal(before, result, STRIKE), "Peddler removal rebase refused")
	_assert_model(shop, state, stock, "Peddler removal refusal")


func _test_peddler() -> void:
	seed(256031)
	var expected_global := randi()
	seed(256031)
	var rng := RandomNumberGenerator.new()
	rng.seed = 256031
	var fixture := _peddler_fixture(rng)
	var after_stock := rng.state
	var canonical := fixture.duplicate(true)
	var shop := _peddler(fixture)
	_check(shop.is_valid(), "authentic 3+1 Peddler admits")
	var initial_state := shop.get_state()
	var initial_stock := shop.get_stock()
	_check(initial_state == {"party_ids": fixture.party_ids, "deck": fixture.deck,
		"trinkets": [], "gold": 500}, "Peddler initial ledger is exact")
	var owners: Array = []
	for i in range(3):
		var offer: Dictionary = initial_stock.cards[i]
		owners.append(offer.owner)
		_check(offer == {"id": fixture.cards[i].id, "owner": fixture.cards[i].owner,
			"price": fixture.cards[i].price, "sold": false}, "Peddler card retains supplied price")
	_check(owners == fixture.party_ids, "one seeded card per party owner")
	_check(initial_stock.trinkets == [{"id": fixture.offers_trinkets[0].id,
		"price": fixture.offers_trinkets[0].price, "sold": false}], "one priced unsold patch")
	fixture.cards[0].price = 0
	fixture.offers_trinkets[0].id = "forged_patch"
	fixture.deck.clear()
	fixture.party_ids.clear()
	fixture.trinkets.append("forged_owned")
	var detached := shop.get_stock()
	detached.cards[0].sold = true
	detached.trinkets.clear()
	var detached_state := shop.get_state()
	detached_state.deck.clear()
	detached_state.gold = 0
	_assert_model(shop, initial_state, initial_stock, "Peddler inputs and reads detached")
	_peddler_refuses_removal(shop)

	# Each card slot and the patch are independent single-purchase alternatives.
	for choice in range(4):
		var kind := "card" if choice < 3 else "trinket"
		var category := "cards" if choice < 3 else "trinkets"
		var index := choice if choice < 3 else 0
		var offer: Dictionary = initial_stock[category][index]
		var fresh := _peddler(canonical)
		var expected_state := initial_state.duplicate(true)
		expected_state.gold -= offer.price
		expected_state["deck" if choice < 3 else "trinkets"].append(offer.id)
		var expected_stock := initial_stock.duplicate(true)
		expected_stock[category][index].sold = true
		var paid := fresh.buy(kind, offer.id)
		_assert_result(paid, true, expected_state, expected_stock, "Peddler chosen purchase",
			{"kind": kind, "id": offer.id, "price": offer.price})
		paid.receipt.price = -1
		paid.state.deck.clear()
		paid.stock[category][index].sold = false
		_assert_model(fresh, expected_state, expected_stock, "Peddler paid result detached")
		for repeat in range(2):
			for card in canonical.cards:
				_assert_result(fresh.buy("card", card.id), false, expected_state,
					expected_stock, "Peddler later card selection")
			_assert_result(fresh.buy("trinket", canonical.offers_trinkets[0].id), false,
				expected_state, expected_stock, "Peddler later patch selection")
		_peddler_refuses_removal(fresh)
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = 256031
		var replay_fixture := _peddler_fixture(replay_rng)
		_check(replay_fixture == canonical and replay_rng.state == after_stock,
			"Peddler supplier replay identical")
		var replay := _peddler(replay_fixture)
		_assert_result(replay.buy(kind, offer.id), true, expected_state, expected_stock,
			"Peddler deterministic purchase replay", {"kind": kind, "id": offer.id, "price": offer.price})
		_check(replay_rng.state == after_stock, "Peddler replay purchase consumes no run RNG")

	# Failed, foreign and forged snapshot choices cannot change or latch the visit.
	for action in [["card", "unknown"], ["trinket", "unknown"],
		["card", ""], ["patch", canonical.offers_trinkets[0].id],
		["trinket", canonical.cards[0].id], ["card", canonical.offers_trinkets[0].id],
		["card", "foreign_card"], ["trinket", "forged_patch"]]:
		var rejected := shop.buy(action[0], action[1])
		_assert_result(rejected, false, initial_state, initial_stock, "Peddler invalid selection")
		rejected.state.gold = 99999
		rejected.stock.cards[0].price = 0
		_assert_model(shop, initial_state, initial_stock, "Peddler rejection result detached")
	_check(shop.buy("card", canonical.cards[0].id).ok, "Peddler refusals never latch")
	var owned_fixture := canonical.duplicate(true)
	owned_fixture.trinkets = [canonical.offers_trinkets[0].id]
	var owned := _peddler(owned_fixture)
	_check(owned.is_valid() and owned.get_stock().trinkets[0].sold, "Peddler owned patch starts sold")
	var owned_state := owned.get_state()
	var owned_stock := owned.get_stock()
	_assert_result(owned.buy("trinket", canonical.offers_trinkets[0].id), false,
		owned_state, owned_stock, "Peddler owned patch rejection")
	_assert_model(owned, owned_state, owned_stock, "Peddler owned patch no mutation")
	_check(owned.buy("card", canonical.cards[1].id).ok, "owned patch rejection leaves card choice available")
	var poor_fixture := canonical.duplicate(true)
	poor_fixture.gold = 0
	var poor := _peddler(poor_fixture)
	var poor_state := poor.get_state()
	var poor_stock := poor.get_stock()
	for card in canonical.cards:
		_check(card.price > 0, "authentic unaffordable card has positive price")
		_assert_result(poor.buy("card", card.id), false, poor_state, poor_stock, "Peddler unaffordable card")
	_check(canonical.offers_trinkets[0].price > 0, "authentic unaffordable patch has positive price")
	_assert_result(poor.buy("trinket", canonical.offers_trinkets[0].id), false,
		poor_state, poor_stock, "Peddler unaffordable patch")
	_assert_model(poor, poor_state, poor_stock, "Peddler unaffordable no mutation")
	# A cheaper card remains affordable after either kind of unaffordable attempt.
	var mixed_fixture := canonical.duplicate(true)
	mixed_fixture.gold = 50
	mixed_fixture.cards[0].price = 51
	mixed_fixture.cards[1].price = 50
	mixed_fixture.offers_trinkets[0].price = 51
	var mixed := _peddler(mixed_fixture)
	var mixed_state := mixed.get_state()
	var mixed_stock := mixed.get_stock()
	for action in [["card", mixed_fixture.cards[0].id], ["trinket", mixed_fixture.offers_trinkets[0].id]]:
		_assert_result(mixed.buy(action[0], action[1]), false, mixed_state, mixed_stock, "Peddler insufficient gold does not latch")
		_assert_model(mixed, mixed_state, mixed_stock, "Peddler insufficient gold no mutation")
	_check(mixed.buy("card", mixed_fixture.cards[1].id).ok and mixed.get_state().gold == 0,
		"exact-price Peddler buy still succeeds after unaffordable attempts")

	# Reject malformed admission before publishing any state or stock.
	var invalid: Array = []
	for field in ["cards", "offers_trinkets"]:
		for count in [-1, 1]:
			var bad := canonical.duplicate(true)
			if count < 0:
				bad[field].pop_back()
			else:
				bad[field].append(bad[field][0].duplicate(true))
			invalid.append(bad)
	for field in ["cards", "offers_trinkets"]:
		for price in [-1, 1.5, 100.0, "100", true, null]:
			var bad := canonical.duplicate(true)
			bad[field][0].price = price
			invalid.append(bad)
		for value in [null, {}, {"id": "forged", "price": 10, "sold": false}]:
			var bad := canonical.duplicate(true)
			bad[field][0] = value
			invalid.append(bad)
	for owner in ["foreign_hero", canonical.cards[1].owner, "", 7]:
		var bad := canonical.duplicate(true)
		bad.cards[0].owner = owner
		invalid.append(bad)
	var duplicate := canonical.duplicate(true)
	duplicate.cards[0].id = duplicate.cards[1].id
	invalid.append(duplicate)
	for bad in invalid:
		var rejected := _peddler(bad)
		_check(not rejected.is_valid(), "malformed Peddler fails closed")
		_assert_model(rejected, {}, {}, "invalid Peddler publishes nothing")
		_assert_result(rejected.buy("card", canonical.cards[0].id), false, {}, {}, "invalid Peddler refuses card")
		_assert_result(rejected.buy("trinket", canonical.offers_trinkets[0].id), false, {}, {}, "invalid Peddler refuses patch")
	_check(rng.state == after_stock, "Peddler admission and all transactions consume no run RNG")
	_check(randi() == expected_global, "Peddler operations consume no global RNG")


func _fixture() -> Dictionary:
	return {
		"party_ids": ["warden", "seamstress", "tinker"],
		"deck": ["w_start", "s_start", "w_start", "t_start"],
		"trinkets": ["old_badge"],
		"gold": 130,
		"cards": [
			{"id": "c_zero", "owner": "warden", "price": 0},
			{"id": "c_exact", "owner": "seamstress", "price": 60},
			{"id": "c_costly", "owner": "tinker", "price": 140},
			{"id": "c_more", "owner": "warden", "price": 10},
			{"id": "c_final", "owner": "seamstress", "price": 130}
		],
		"offers_trinkets": [
			{"id": "t_spool", "price": 50},
			{"id": "t_pocket", "price": 20}
		]
	}


func _shop(fixture: Dictionary) -> RunShopPurchases:
	return RunShopPurchases.new(
		fixture["party_ids"], fixture["deck"], fixture["trinkets"],
		fixture["gold"], fixture["cards"], fixture["offers_trinkets"]
	)


func _state() -> Dictionary:
	return {
		"party_ids": ["warden", "seamstress", "tinker"],
		"deck": ["w_start", "s_start", "w_start", "t_start"],
		"trinkets": ["old_badge"],
		"gold": 130
	}


func _stock() -> Dictionary:
	return {
		"cards": [
			{"id": "c_zero", "owner": "warden", "price": 0, "sold": false},
			{"id": "c_exact", "owner": "seamstress", "price": 60, "sold": false},
			{"id": "c_costly", "owner": "tinker", "price": 140, "sold": false},
			{"id": "c_more", "owner": "warden", "price": 10, "sold": false},
			{"id": "c_final", "owner": "seamstress", "price": 130, "sold": false}
		],
		"trinkets": [
			{"id": "t_spool", "price": 50, "sold": false},
			{"id": "t_pocket", "price": 20, "sold": false}
		]
	}


func _assert_model(shop: RunShopPurchases, expected_state: Dictionary,
		expected_stock: Dictionary, label: String) -> void:
	_check(shop.get_state() == expected_state, label + " complete run state")
	_check(shop.get_stock() == expected_stock, label + " complete seven-listing stock")


func _assert_result(result: Dictionary, ok: bool, expected_state: Dictionary,
		expected_stock: Dictionary, label: String, receipt: Dictionary = {}) -> void:
	var expected := {"ok": ok, "state": expected_state, "stock": expected_stock}
	if ok:
		expected["receipt"] = receipt
	_check(result == expected, label + " complete detached transaction result")
	_check(result.has("receipt") == ok, label + " success-only receipt")


func _test_removal_rebase() -> void:
	seed(730073)
	var expected_draw := randi()
	seed(730073)
	for purchase_first in [false, true]:
		var f := _fixture()
		f.gold = 300
		var shop := _shop(f)
		var cards: Array[String] = []
		cards.assign(f.deck)
		var owned: Array[String] = []
		owned.assign(f.trinkets)
		var visit := RunShopVisit.new(cards, f.gold, 0, owned)
		_check(visit.open_visit("first_shop"), "removal fixture opens real visit")
		var receipt: Dictionary = {}
		if purchase_first:
			receipt = shop.buy("card", "c_exact")
			_check(receipt.ok and visit.reconcile_purchase(receipt), "paid purchase reconciles before removal")
		var before := visit.get_state()
		cards.assign(before.deck)
		var result := RunShopCardRemoval.try_remove(cards, before.gold, before.prior_removals, "w_start")
		var stock := shop.get_stock()
		var state := shop.get_state()
		for field in ["ok", "price", "deck", "gold", "prior_removals"]:
			var malformed := result.duplicate(true)
			malformed[field] = false if field == "ok" else ( [] if field == "deck" else result[field] + 1 )
			_check(not shop.rebase_removal(before, malformed, "w_start"), "reject altered removal " + field)
			_assert_model(shop, state, stock, "malformed removal leaves all state")
		for field in ["price", "gold", "prior_removals"]:
			var malformed := result.duplicate(true)
			malformed[field] = float(result[field])
			_check(not shop.rebase_removal(before, malformed, "w_start"), "numeric type mismatch rejects " + field)
			_assert_model(shop, state, stock, "numeric mismatch leaves all state")
		for field in ["deck", "gold", "trinkets", "prior_removals", "status"]:
			var stale := before.duplicate(true)
			stale[field] = [] if field in ["deck", "trinkets"] else ("closed" if field == "status" else -1)
			_check(not shop.rebase_removal(stale, result, "w_start"), "reject stale before " + field)
			_assert_model(shop, state, stock, "stale removal leaves all state")
		_check(not shop.rebase_removal(before, result, "absent"), "foreign removal ID rejected")
		_check(not shop.rebase_removal(null, result, "w_start") and not shop.rebase_removal(before, [], "w_start"), "malformed containers reject")
		_check(shop.can_rebase_removal(before, result, "w_start"), "valid removal preflight")
		_assert_model(shop, state, stock, "preflight is read only")
		_check(visit.remove_card("w_start") == result and shop.rebase_removal(before, result, "w_start"), "exact helper transition committed by both ledgers")
		state.deck = result.deck.duplicate()
		state.gold = result.gold
		_assert_model(shop, state, stock, "removal changes only exact deck and gold")
		_check(not shop.rebase_removal(before, result, "w_start"), "removal replay rejects")
		var next_before := visit.get_state()
		next_before.status = "available"
		next_before.removal_available = true
		cards.assign(next_before.deck)
		var next_result := RunShopCardRemoval.try_remove(cards, next_before.gold, next_before.prior_removals, "s_start")
		_check(next_result.ok and not shop.rebase_removal(next_before, next_result, "s_start"), "second otherwise legal removal cannot rebase same stock")
		_assert_model(shop, state, stock, "replays leave complete state")
		if purchase_first:
			_check(not visit.reconcile_purchase(receipt), "pre-removal receipt replay rejected")
			_check(not shop.buy("card", "c_exact").ok, "sold stock stays sold after removal")
		var paid := shop.buy("card", "c_more")
		_check(paid.ok and paid.receipt.price == 10 and visit.reconcile_purchase(paid), "distinct paid purchase works after removal")
		state.deck.append("c_more")
		state.gold -= 10
		stock.cards[3].sold = true
		_assert_model(shop, state, stock, "post-removal purchase exact full state")
		var ledger := visit.get_state()
		_check(ledger.deck == state.deck and ledger.gold == state.gold and ledger.trinkets == state.trinkets and ledger.prior_removals == 1 and ledger.status == "used", "both ledgers agree exactly")
		_check(not visit.reconcile_purchase(paid) and visit.get_state() == ledger, "post-removal receipt replay leaves ledger unchanged")
		var poor_fixture := _fixture()
		poor_fixture.gold = 74
		var poor := _shop(poor_fixture)
		cards.assign(poor_fixture.deck)
		var poor_visit := RunShopVisit.new(cards, 74, 0, owned)
		_check(poor_visit.open_visit("poor_shop"), "unaffordable removal has an otherwise valid visit")
		var poor_before := poor_visit.get_state()
		var denied := RunShopCardRemoval.try_remove(cards, 74, 0, "w_start")
		_check(not denied.ok and not poor.rebase_removal(poor_before, denied, "w_start"), "unaffordable helper removal rejects")
		denied.ok = true
		_check(not poor.rebase_removal(poor_before, denied, "w_start"), "forged unaffordable success rejects")
		_assert_model(poor, {"party_ids": poor_fixture.party_ids, "deck": poor_fixture.deck, "trinkets": poor_fixture.trinkets, "gold": 74}, _stock(), "unaffordable rebase leaves complete state")
	_check(randi() == expected_draw, "removal rebases and purchases consume no global RNG")


func _test_contract_initial_snapshots() -> void:
	var shop := _shop(_fixture())
	_check(shop.has_method("is_valid") and shop.has_method("get_stock")
			and shop.has_method("get_state") and shop.has_method("buy"), "four public methods exist")
	_check(shop.is_valid(), "full seven-offer visit is valid")
	_assert_model(shop, _state(), _stock(), "initial")
	_check(shop.get_stock()["cards"].size() == 5, "exactly five cards offered")
	_check(shop.get_stock()["trinkets"].size() == 2, "exactly two trinkets offered")
	_check(shop.get_stock()["cards"][2]["owner"] == "tinker", "all three party owners accepted")
	_check(shop.get_state()["party_ids"] == ["warden", "seamstress", "tinker"],
		"party order preserved and no positioning state modified")


func _test_reads_and_inputs_are_detached() -> void:
	var fixture := _fixture()
	var shop := _shop(fixture)
	fixture["party_ids"][0] = "intruder"
	fixture["deck"].append("foreign")
	fixture["trinkets"].clear()
	fixture["cards"][0]["id"] = "forged"
	fixture["cards"][1]["price"] = 999
	fixture["offers_trinkets"][0]["price"] = 999
	fixture["cards"].clear()
	_assert_model(shop, _state(), _stock(), "mutated caller data")

	var state_one := shop.get_state()
	var state_two := shop.get_state()
	var stock_one := shop.get_stock()
	var stock_two := shop.get_stock()
	state_one["party_ids"][0] = "forged"
	state_one["deck"].append("forged")
	state_one["trinkets"][0] = "forged"
	state_one["gold"] = 9999
	stock_one["cards"][0]["sold"] = true
	stock_one["cards"][1]["price"] = 0
	stock_one["trinkets"][0]["id"] = "forged"
	stock_one["cards"].remove_at(3)
	_check(state_two == _state(), "second state read is detached")
	_check(stock_two == _stock(), "second stock read is detached")
	_assert_model(shop, _state(), _stock(), "mutated reader copies")

	var denied := shop.buy("card", "absent")
	denied["state"]["gold"] = -1
	denied["stock"]["cards"][0]["sold"] = true
	_assert_model(shop, _state(), _stock(), "mutated rejected result")


func _test_owned_listings() -> void:
	seed(76001)
	var expected_draw := randi()
	seed(76001)
	for count in [1, 2]:
		var fixture := _fixture()
		for index in range(count):
			fixture.trinkets.append(fixture.offers_trinkets[index].id)
		# Even a free owned listing must remain unavailable.
		fixture.offers_trinkets[0].price = 0
		var shop := _shop(fixture)
		_check(shop.is_valid(), "owned listings admit a valid visit")
		var state := _state()
		state.trinkets = fixture.trinkets.duplicate()
		var stock := _stock()
		stock.trinkets[0].price = 0
		for index in range(count):
			stock.trinkets[index].sold = true
		_assert_model(shop, state, stock, "owned listings initially sold")
		for index in range(count):
			var denied := shop.buy("trinket", fixture.offers_trinkets[index].id)
			_assert_result(denied, false, state, stock, "owned purchase denied without receipt")
			denied.state.trinkets.clear()
			denied.stock.trinkets[index].sold = false
			_assert_model(shop, state, stock, "denied owned result remains detached")
		if count == 1:
			state.trinkets.append("t_pocket")
			state.gold -= 20
			stock.trinkets[1].sold = true
			_assert_result(shop.buy("trinket", "t_pocket"), true, state, stock,
				"unowned listing sells once", {"kind": "trinket", "id": "t_pocket", "price": 20})
			_assert_result(shop.buy("trinket", "t_pocket"), false, state, stock, "resale rejected")
		state.deck.append("c_exact")
		state.gold -= 60
		stock.cards[1].sold = true
		_assert_result(shop.buy("card", "c_exact"), true, state, stock,
			"card purchases remain intact", {"kind": "card", "id": "c_exact", "price": 60})
		_assert_model(shop, state, stock, "owned and available purchase final state")
	_check(randi() == expected_draw, "owned admission and all purchase attempts consume no global RNG")


func _test_purchase_sequence() -> void:
	var shop := _shop(_fixture())
	var state := _state()
	var stock := _stock()
	# First card, then a trinket, then another distinct card. All unchanged
	# positions/order and HP are absent from this backend state.
	state["gold"] = 70
	state["deck"].append("c_exact")
	stock["cards"][1]["sold"] = true
	var first := shop.buy("card", "c_exact")
	_assert_result(first, true, state, stock, "first paid card", {"kind": "card", "id": "c_exact", "price": 60})
	_assert_model(shop, state, stock, "first paid card")

	state["gold"] = 20
	state["trinkets"].append("t_spool")
	stock["trinkets"][0]["sold"] = true
	var second := shop.buy("trinket", "t_spool")
	_assert_result(second, true, state, stock, "paid trinket", {"kind": "trinket", "id": "t_spool", "price": 50})
	_assert_model(shop, state, stock, "paid trinket")

	state["gold"] = 10
	state["deck"].append("c_more")
	stock["cards"][3]["sold"] = true
	var third := shop.buy("card", "c_more")
	_assert_result(third, true, state, stock, "second distinct paid card", {"kind": "card", "id": "c_more", "price": 10})
	_assert_model(shop, state, stock, "second distinct paid card")

	# A previous result cannot mutate later state or stock.
	first["state"]["deck"].clear()
	first["stock"]["cards"][4]["price"] = -99
	second["state"]["trinkets"].clear()
	second["receipt"]["id"] = "forged"
	second["receipt"]["price"] = 1
	first["receipt"]["kind"] = "trinket"
	var untouched := shop.buy("trinket", "t_pocket")
	_check(not untouched.ok and not untouched.has("receipt"), "failed trinket cannot mint receipt")
	_assert_model(shop, state, stock, "after mutating earlier successful results")
	_rejected(shop, "card", "c_exact", "already sold card")
	_rejected(shop, "trinket", "t_spool", "already sold trinket")
	_rejected(shop, "trinket", "t_pocket", "now unaffordable other trinket")


func _test_price_boundaries() -> void:
	var free_shop := _shop(_fixture())
	var state := _state()
	var stock := _stock()
	state["deck"].append("c_zero")
	stock["cards"][0]["sold"] = true
	_assert_result(free_shop.buy("card", "c_zero"), true, state, stock, "zero price card", {"kind": "card", "id": "c_zero", "price": 0})
	_assert_model(free_shop, state, stock, "zero price card")
	_rejected(free_shop, "card", "c_zero", "free card cannot be purchased twice")

	# Exactly affordable final card consumes all 130 gold, with no other change.
	var exact_shop := _shop(_fixture())
	var exact_state := _state()
	var exact_stock := _stock()
	exact_state["gold"] = 0
	exact_state["deck"].append("c_final")
	exact_stock["cards"][4]["sold"] = true
	_assert_result(exact_shop.buy("card", "c_final"), true, exact_state,
		exact_stock, "exact affordability", {"kind": "card", "id": "c_final", "price": 130})
	_assert_model(exact_shop, exact_state, exact_stock, "exact affordability")
	_rejected(exact_shop, "trinket", "t_pocket", "no gold remaining")
	# A free card is still purchasable after exhausting funds.
	exact_state["deck"].append("c_zero")
	exact_stock["cards"][0]["sold"] = true
	_assert_result(exact_shop.buy("card", "c_zero"), true, exact_state,
		exact_stock, "free after zero gold", {"kind": "card", "id": "c_zero", "price": 0})

	var poor_shop := _shop(_fixture())
	_rejected(poor_shop, "card", "c_costly", "140 price exceeds 130 gold")


func _rejected(shop: RunShopPurchases, kind: String, id: String, label: String) -> void:
	var before_state := shop.get_state()
	var before_stock := shop.get_stock()
	var result := shop.buy(kind, id)
	_assert_result(result, false, before_state, before_stock, label)
	_assert_model(shop, before_state, before_stock, label)
	result["state"]["deck"].append("forged")
	result["stock"]["trinkets"].clear()
	_assert_model(shop, before_state, before_stock, label + " result isolation")


func _test_rejected_attempts() -> void:
	var shop := _shop(_fixture())
	for action in [
		["card", "not_in_stock", "unknown card"],
		["trinket", "unknown", "unknown trinket"],
		["card", "t_spool", "trinket ID with card kind"],
		["trinket", "c_exact", "card ID with trinket kind"],
		["", "c_exact", "blank category"],
		["Card", "c_exact", "noncanonical category"],
		["other", "c_exact", "unknown category"],
		["card", "", "empty ID"],
		["card", " ", "whitespace ID"]
	]:
		_rejected(shop, action[0], action[1], action[2])


func _invalid(label: String, fixture: Dictionary) -> void:
	var original: Dictionary = fixture.duplicate(true)
	var shop := _shop(fixture)
	_check(not shop.is_valid(), label + " invalid visit rejected")
	_check(shop.get_state() == {} and shop.get_stock() == {},
		label + " no partial state published")
	_assert_result(shop.buy("card", "c_zero"), false, {}, {}, label + " refused card")
	_assert_result(shop.buy("trinket", "t_spool"), false, {}, {}, label + " refused trinket")
	_check(fixture == original, label + " original input untouched")


func _patch_invalid(label: String, field: String, value: Variant) -> void:
	var f := _fixture()
	f[field] = value
	_invalid(label, f)


func _test_invalid_visits() -> void:
	seed(76003)
	var expected_draw := randi()
	seed(76003)
	for owned in [["old_badge", "old_badge"], ["t_spool", "old_badge", "t_spool"],
			["outside_pool", "old_badge", "outside_pool"]]:
		_patch_invalid("duplicate owned inventory", "trinkets", owned)
	_check(randi() == expected_draw, "duplicate inventory admission and rejected buys consume no global RNG")
	_patch_invalid("party too small", "party_ids", ["warden", "tinker"])
	_patch_invalid("party extra", "party_ids", ["warden", "seamstress", "tinker", "other"])
	_patch_invalid("duplicate party", "party_ids", ["warden", "warden", "tinker"])
	_patch_invalid("blank party", "party_ids", ["warden", "", "tinker"])
	_patch_invalid("whitespace party", "party_ids", ["warden", "  ", "tinker"])
	_patch_invalid("nonstr party", "party_ids", ["warden", 3, "tinker"])
	_patch_invalid("nonarray party", "party_ids", "warden")
	_patch_invalid("negative gold", "gold", -1)
	_patch_invalid("float gold", "gold", 130.0)
	_patch_invalid("bool gold", "gold", true)
	_patch_invalid("nonarray deck", "deck", "w_start")
	_patch_invalid("invalid deck id", "deck", ["w_start", ""])
	_patch_invalid("invalid trinket id", "trinkets", [7])
	_patch_invalid("nonarray trinkets", "trinkets", {})
	_patch_invalid("four cards", "cards", _fixture()["cards"].slice(0, 4))
	var extra_cards: Array = _fixture()["cards"].duplicate(true)
	extra_cards.append({"id": "sixth", "owner": "warden", "price": 0})
	_patch_invalid("six cards", "cards", extra_cards)
	_patch_invalid("one trinket", "offers_trinkets", [_fixture()["offers_trinkets"][0]])
	var extra_trinkets: Array = _fixture()["offers_trinkets"].duplicate(true)
	extra_trinkets.append({"id": "third", "price": 0})
	_patch_invalid("three trinkets", "offers_trinkets", extra_trinkets)

	var f := _fixture()
	f["cards"][0]["owner"] = "outsider"
	_invalid("nonparty owner", f)
	f = _fixture()
	f["cards"][0]["owner"] = ""
	_invalid("empty owner", f)
	f = _fixture()
	f["cards"][0]["owner"] = 7
	_invalid("nonstr owner", f)
	f = _fixture()
	f["cards"][0]["id"] = f["cards"][1]["id"]
	_invalid("duplicate card ID", f)
	f = _fixture()
	f["offers_trinkets"][0]["id"] = f["offers_trinkets"][1]["id"]
	_invalid("duplicate trinket ID", f)
	f = _fixture()
	f["cards"][0]["id"] = " "
	_invalid("blank card ID", f)
	f = _fixture()
	f["offers_trinkets"][0]["id"] = ""
	_invalid("blank trinket ID", f)
	f = _fixture()
	f["cards"][0]["id"] = 17
	_invalid("nonstr card ID", f)
	f = _fixture()
	f["offers_trinkets"][0]["id"] = 17
	_invalid("nonstr trinket ID", f)

	for price in [-1, 0.5, 12.0, true, "12", null]:
		f = _fixture()
		f["cards"][0]["price"] = price
		_invalid("invalid card price " + str(price), f)
		f = _fixture()
		f["offers_trinkets"][0]["price"] = price
		_invalid("invalid trinket price " + str(price), f)
	f = _fixture()
	f["cards"][0].erase("price")
	_invalid("missing card price", f)
	f = _fixture()
	f["offers_trinkets"][0].erase("id")
	_invalid("missing trinket ID", f)
	f = _fixture()
	f["cards"][0]["sold"] = true
	_invalid("caller injected card sold flag", f)
	f = _fixture()
	f["offers_trinkets"][0]["sold"] = true
	_invalid("caller injected trinket sold flag", f)
	f = _fixture()
	f["cards"][1] = "c_exact"
	_invalid("non-dictionary card offer", f)
	f = _fixture()
	f["offers_trinkets"][1] = null
	_invalid("non-dictionary trinket offer", f)


func _test_replay_and_rng() -> void:
	var sequence := [
		["card", "c_zero"], ["card", "c_exact"], ["card", "c_exact"],
		["trinket", "t_spool"], ["card", "c_costly"],
		["card", "c_more"], ["trinket", "t_pocket"],
		["trinket", "unknown"], ["card", "t_spool"]
	]
	var left := _shop(_fixture())
	var right := _shop(_fixture())
	_check(left.is_valid() and right.is_valid(), "both replay visits valid")
	seed(73604)
	var expected_global_draw := randi()
	seed(73604)
	for action in sequence:
		var a := left.buy(action[0], action[1])
		var b := right.buy(action[0], action[1])
		_check(a == b, "replay transaction " + str(action))
		_check(left.get_state() == right.get_state(), "replay state " + str(action))
		_check(left.get_stock() == right.get_stock(), "replay stock " + str(action))
	_check(randi() == expected_global_draw, "transactions consume no global RNG")
	_check(left.get_state()["gold"] >= 0, "replay gold never negative")
	_check(left.get_stock()["cards"].size() == 5
			and left.get_stock()["trinkets"].size() == 2, "replay stock counts preserved")


func _forged(base: Dictionary, field: String, value: Variant) -> Dictionary:
	var copy: Dictionary = base.duplicate(true)
	copy[field] = value
	return copy


## Two authentic Rest composites owned by a real run ledger.
func _stitched_fixture() -> Dictionary:
	var catalog := StarterCards.new()
	var deck: Array[String] = []
	deck.assign(catalog.get_starting_deck())
	_check(deck.count(STRIKE) == 2 and deck.has(PRICK) and deck.has(POP)
		and deck.has(MEND) and deck.has(BOMB),
		"stitched fixture takes the real repeated starter deck")
	var first := RunRestStitchCards.new(deck, {}, 9)
	_check(first.is_valid(), "stitched fixture Rest accepts the starter ledger")
	if not first.is_valid():
		return {}
	var one := first.choose_stitch(deck.find(PRICK), deck.find(POP), first.get_snapshot())
	_check(one.ok and one.stitched_id == "stitched_000001" and one.descriptors.size() == 1,
		"stitched fixture canonically stitches Prick / Pop Shot")
	if not one.ok:
		return {}
	var second := RunRestStitchCards.new(one.deck, one.descriptors, one.remaining_scraps,
		one.next_stitch_id)
	_check(second.is_valid(), "stitched fixture second Rest accepts the committed ledger")
	if not second.is_valid():
		return {}
	var two := second.choose_stitch(one.deck.find(MEND), one.deck.find(BOMB),
		second.get_snapshot())
	_check(two.ok and two.stitched_id == "stitched_000002"
		and two.descriptors.size() == 2 and two.next_stitch_id == 3,
		"stitched fixture owns two distinct canonical composites")
	if not two.ok:
		return {}
	return two


## A compatible five-card/two-trinket stock drawn from the visit's own ledger.
func _stitched_shop(visit_state: Dictionary, gold: int = -1) -> RunShopPurchases:
	var shop_gold: int = visit_state.gold if gold < 0 else gold
	return RunShopPurchases.new(
		["warden", "seamstress", "tinker"], visit_state.deck, visit_state.trinkets, shop_gold,
		[
			{"id": "warden_brace", "owner": "warden", "price": 25},
			{"id": "tinker_pop_shot", "owner": "tinker", "price": 30},
			{"id": "seamstress_mend", "owner": "seamstress", "price": 15},
			{"id": "tinker_scrap_bomb", "owner": "tinker", "price": 20},
			{"id": "warden_shield_bash", "owner": "warden", "price": 10}
		],
		[{"id": "t_spool", "price": 40}, {"id": "t_pocket", "price": 20}]
	)


func _test_stitched_removal_rebase() -> void:
	seed(730188)
	var expected_draw := randi()
	seed(730188)
	var made := _stitched_fixture()
	if made.is_empty():
		return
	var retired_id: String = "stitched_000001"
	var kept_id: String = made.stitched_id
	_check(kept_id == "stitched_000002" and made.descriptors.size() == 2,
		"fixture owns serials 1 and 2 with a cursor of 3")
	var deck: Array[String] = []
	deck.assign(made.deck)
	var visit := RunShopVisit.new(deck, 400, 0, [], made.descriptors, made.next_stitch_id)
	_check(visit.get_state().valid and visit.open_visit("stitched-shop"),
		"real stitched run ledger opens its first Shop")
	_check(visit.quote() == 75, "first stitched Shop quotes 75 gold")
	var shop := _stitched_shop(visit.get_state())
	_check(shop.is_valid(), "purchase ledger admits the real stitched visit")

	# Buy before removal: both ledgers must stay equal.
	var bought := shop.buy("card", "warden_brace")
	_check(bought.ok and bought.receipt == {"kind": "card", "id": "warden_brace", "price": 25},
		"authentic stock card purchase before removal")
	_check(visit.reconcile_purchase(bought), "visit reconciles the paid purchase")
	var before := visit.get_state()
	_check(before.has("descriptors") and before.has("next_stitch_id")
		and before.descriptors == made.descriptors and before.next_stitch_id == 3,
		"stitched snapshot keeps descriptor and cursor authority")
	_check(before.removal_available and before.price == 75, "removal is still quoted at 75")
	var paid_state := {
		"party_ids": ["warden", "seamstress", "tinker"],
		"deck": before.deck.duplicate(true),
		"trinkets": before.trinkets.duplicate(true),
		"gold": before.gold
	}
	_check(shop.get_state() == paid_state and paid_state.gold == 375
		and paid_state.deck.size() == before.deck.size(),
		"purchase ledger deck and gold agree with the visit after the buy")

	var ordinary := visit.remove_card(STRIKE)
	_check(ordinary.size() == 7 and ordinary.ok and ordinary.price == 75
		and ordinary.descriptors == made.descriptors and ordinary.next_stitch_id == 3
		and ordinary.gold == 300 and ordinary.prior_removals == 1,
		"ordinary seven-field removal keeps both composites and charges 75")
	_check(ordinary.deck.count(STRIKE) == 1 and ordinary.deck.count(retired_id) == 1
		and ordinary.deck.count(kept_id) == 1 and ordinary.descriptors.size() == 2,
		"only the first STRIKE copy is retired; a different composite survives")
	var frozen_state := shop.get_state()
	var frozen_stock := shop.get_stock()
	_check(shop.can_rebase_removal(before, ordinary, STRIKE),
		"authentic seven-field ordinary receipt passes preflight")
	_check(shop.get_state() == frozen_state and shop.get_stock() == frozen_stock,
		"stitched preflight is read only")
	_check(not shop.can_rebase_removal(before, ordinary, "seamstress_prick"),
		"foreign card ID cannot preflight the same receipt")
	_check(shop.rebase_removal(before, ordinary, STRIKE),
		"authentic seven-field ordinary receipt rebases once")
	_check(shop.get_state().deck == visit.get_state().deck
		and shop.get_state().gold == visit.get_state().gold
		and shop.get_state().trinkets == visit.get_state().trinkets,
		"purchase ledger agrees exactly with the visit after the rebase")
	_check(shop.get_stock() == frozen_stock, "rebasing a removal leaves stock untouched")
	_check(not shop.can_rebase_removal(before, ordinary, STRIKE)
		and not shop.rebase_removal(before, ordinary, STRIKE),
		"the same seven-field receipt cannot rebase twice")
	var visited := visit.get_state()
	_check(visited.descriptors == made.descriptors and visited.next_stitch_id == 3
		and visited.status == "used" and not visited.removal_available,
		"visit keeps both composites, its cursor and the one-use latch")

	# Buy after removal: both ledgers still agree.
	var later_buy := shop.buy("card", "warden_shield_bash")
	_check(later_buy.ok and later_buy.receipt.price == 10 and visit.reconcile_purchase(later_buy),
		"purchase after the rebase reconciles")
	_check(shop.get_state().deck == visit.get_state().deck
		and shop.get_state().gold == visit.get_state().gold,
		"both ledgers stay equal through a post-removal purchase")

	# Second Shop: 100-gold composite retirement on a fresh purchase ledger.
	_check(visit.close_visit() and visit.open_visit("stitched-shop-two") and visit.quote() == 100,
		"second stitched Shop quotes 100 without rewinding removals")
	var retire_shop := _stitched_shop(visit.get_state())
	_check(retire_shop.is_valid(), "second purchase ledger admits the stitched visit")
	var retire_before := visit.get_state()
	var retired := visit.remove_card(retired_id)
	var retired_deck: Array = retire_before.deck.duplicate()
	retired_deck.erase(retired_id)
	var kept_registry: Dictionary = {kept_id: made.descriptors[kept_id]}
	_check(retired.size() == 7 and retired.ok and retired.price == 100
		and retired.deck == retired_deck and retired.descriptors == kept_registry
		and retired.next_stitch_id == 3 and retired.gold == retire_before.gold - 100
		and retired.prior_removals == 2,
		"composite retirement is an exact seven-field 100-gold receipt")
	_check(retire_shop.can_rebase_removal(retire_before, retired, retired_id)
		and retire_shop.rebase_removal(retire_before, retired, retired_id),
		"composite retirement rebases through the purchase ledger")
	_check(retire_shop.get_state().deck == visit.get_state().deck
		and retire_shop.get_state().gold == visit.get_state().gold,
		"composite rebase keeps deck and gold equal")
	var retired_state := visit.get_state()
	_check(retired_state.descriptors == kept_registry and retired_state.next_stitch_id == 3
		and retired_state.visited_ids == ["stitched-shop", "stitched-shop-two"]
		and retired_state.claimed_fight_ids == [] and retired_state.status == "used",
		"visit retires only that descriptor without rewinding the cursor")
	var future := RunRestStitchCards.new(retired_state.deck, retired_state.descriptors, 3,
		retired_state.next_stitch_id)
	_check(future.is_valid(), "a later Rest accepts the rebased stitched ledger")
	if future.is_valid():
		var resewn := future.choose_stitch(retired_state.deck.find(PRICK),
			retired_state.deck.find(POP), future.get_snapshot())
		_check(resewn.ok and resewn.stitched_id == "stitched_000003"
			and resewn.next_stitch_id == 4 and resewn.descriptors.has(kept_id),
			"a retired serial is never reused while the other composite survives")
	_check(randi() == expected_draw, "the stitched rebase path consumes no global RNG")


func _test_stitched_forged_receipts() -> void:
	seed(730189)
	var expected_draw := randi()
	seed(730189)
	var made := _stitched_fixture()
	if made.is_empty():
		return
	var deck: Array[String] = []
	deck.assign(made.deck)
	var visit := RunShopVisit.new(deck, 200, 0, [], made.descriptors, made.next_stitch_id)
	_check(visit.open_visit("forged-shop"), "forgery Shop opens on a real stitched ledger")
	var shop := _stitched_shop(visit.get_state())
	_check(shop.is_valid(), "forgery purchase ledger is valid")
	var before := visit.get_state()
	var authentic := visit.remove_card(STRIKE)
	_check(authentic.size() == 7 and authentic.ok and authentic.price == 75
		and authentic.gold == 125 and authentic.next_stitch_id == 3,
		"authentic seven-field receipt captured before tampering")
	var baseline := shop.get_state()
	var baseline_stock := shop.get_stock()

	var tampered: Array = []
	tampered.append(["price", _forged(authentic, "price", 76)])
	tampered.append(["gold", _forged(authentic, "gold", 126)])
	tampered.append(["prior_removals", _forged(authentic, "prior_removals", 2)])
	tampered.append(["ok", _forged(authentic, "ok", false)])
	tampered.append(["float gold", _forged(authentic, "gold", 125.0)])
	tampered.append(["cursor", _forged(authentic, "next_stitch_id", 4)])
	tampered.append(["rewound cursor", _forged(authentic, "next_stitch_id", 1)])
	tampered.append(["float cursor", _forged(authentic, "next_stitch_id", 3.0)])
	tampered.append(["descriptors", _forged(authentic, "descriptors", {})])
	tampered.append(["deck", _forged(authentic, "deck", authentic.deck + [STRIKE])])
	tampered.append(["foreign deck", _forged(authentic, "deck", authentic.deck + ["foreign_card"])])
	var extra_key: Dictionary = authentic.duplicate(true)
	extra_key["receipt"] = {}
	tampered.append(["extra receipt key", extra_key])
	var extra_snapshot: Dictionary = authentic.duplicate(true)
	extra_snapshot["status"] = "used"
	tampered.append(["extra snapshot key", extra_snapshot])
	var missing_descriptors: Dictionary = authentic.duplicate(true)
	missing_descriptors.erase("descriptors")
	tampered.append(["missing descriptors", missing_descriptors])
	var missing_cursor: Dictionary = authentic.duplicate(true)
	missing_cursor.erase("next_stitch_id")
	tampered.append(["missing cursor", missing_cursor])
	var missing_price: Dictionary = authentic.duplicate(true)
	missing_price.erase("price")
	tampered.append(["missing price", missing_price])
	var forged_registry: Dictionary = authentic.duplicate(true)
	forged_registry["descriptors"]["stitched_000001"]["cost"] = 0
	tampered.append(["forged descriptor", forged_registry])
	var forged_half: Dictionary = authentic.duplicate(true)
	forged_half["descriptors"]["stitched_000001"]["first_half"]["effects"]["damage"] = 99
	tampered.append(["forged half", forged_half])
	var partial_registry: Dictionary = authentic.duplicate(true)
	partial_registry["descriptors"].erase("stitched_000001")
	tampered.append(["incomplete registry", partial_registry])
	for entry in tampered:
		var label: String = entry[0]
		var receipt: Dictionary = entry[1]
		_check(not shop.can_rebase_removal(before, receipt, STRIKE),
			"tampered " + label + " receipt cannot preflight")
		_check(not shop.rebase_removal(before, receipt, STRIKE),
			"tampered " + label + " receipt cannot rebase")
		_check(shop.get_state() == baseline and shop.get_stock() == baseline_stock,
			"tampered " + label + " receipt leaves state and stock")

	# Stale or malformed source snapshots.
	var stale: Array = []
	var no_registry: Dictionary = before.duplicate(true)
	no_registry["descriptors"] = {}
	stale.append(["dropped descriptor", no_registry])
	var changed_cursor: Dictionary = before.duplicate(true)
	changed_cursor["next_stitch_id"] = 5
	stale.append(["legal but changed cursor", changed_cursor])
	var rewound: Dictionary = before.duplicate(true)
	rewound["next_stitch_id"] = 1
	stale.append(["rewound cursor", rewound])
	var string_cursor: Dictionary = before.duplicate(true)
	string_cursor["next_stitch_id"] = "2"
	stale.append(["string cursor", string_cursor])
	var array_registry: Dictionary = before.duplicate(true)
	array_registry["descriptors"] = []
	stale.append(["array registry", array_registry])
	var no_cursor: Dictionary = before.duplicate(true)
	no_cursor.erase("next_stitch_id")
	stale.append(["mixed fields", no_cursor])
	var no_descriptors: Dictionary = before.duplicate(true)
	no_descriptors.erase("descriptors")
	stale.append(["other mixed fields", no_descriptors])
	var forged_source: Dictionary = before.duplicate(true)
	forged_source["descriptors"]["stitched_000001"]["half_ids"] = [STRIKE, STRIKE]
	stale.append(["forged source descriptor", forged_source])
	var stale_deck: Dictionary = before.duplicate(true)
	stale_deck["deck"] = before.deck.slice(1)
	stale.append(["stale deck", stale_deck])
	var stale_gold: Dictionary = before.duplicate(true)
	stale_gold["gold"] = before.gold + 1
	stale.append(["stale gold", stale_gold])
	var stale_count: Dictionary = before.duplicate(true)
	stale_count["prior_removals"] = 1
	stale.append(["stale removal count", stale_count])
	var stale_status: Dictionary = before.duplicate(true)
	stale_status["status"] = "closed"
	stale.append(["stale status", stale_status])
	for entry in stale:
		var label: String = entry[0]
		var snapshot: Dictionary = entry[1]
		_check(not shop.can_rebase_removal(snapshot, authentic, STRIKE),
			"stale " + label + " cannot preflight a genuine receipt")
		_check(not shop.rebase_removal(snapshot, authentic, STRIKE),
			"stale " + label + " cannot rebase")
		_check(shop.get_state() == baseline and shop.get_stock() == baseline_stock,
			"stale " + label + " leaves state and stock")

	# Foreign IDs and the wrong receipt shape for this snapshot.
	_check(not shop.can_rebase_removal(before, authentic, MEND),
		"foreign card ID cannot claim the receipt")
	_check(not shop.can_rebase_removal(before, authentic, ""),
		"blank card ID cannot claim the receipt")
	var legacy_cards: Array[String] = []
	legacy_cards.assign(before.deck)
	var five_field := RunShopCardRemoval.try_remove(legacy_cards, before.gold,
		before.prior_removals, STRIKE)
	_check(five_field.size() == 5 and five_field.ok,
		"legacy five-field receipt computed for the same removal")
	_check(not shop.can_rebase_removal(before, five_field, STRIKE)
		and not shop.rebase_removal(before, five_field, STRIKE),
		"five-field receipt cannot rebase a stitched snapshot")
	_check(shop.get_state() == baseline and shop.get_stock() == baseline_stock,
		"wrong-shape receipts leave state and stock")

	# Unaffordable and forged-success attempts.
	var poor_deck: Array[String] = []
	poor_deck.assign(made.deck)
	var poor_visit := RunShopVisit.new(poor_deck, 74, 0, [], made.descriptors,
		made.next_stitch_id)
	_check(poor_visit.open_visit("poor-stitched") and poor_visit.quote() == 75,
		"74-gold stitched visit is otherwise available")
	var poor_shop := _stitched_shop(poor_visit.get_state())
	var poor_before := poor_visit.get_state()
	var poor_shop_before := poor_shop.get_state()
	var poor_stock_before := poor_shop.get_stock()
	var denied := poor_visit.remove_card(STRIKE)
	_check(denied.size() == 7 and not denied.ok and denied.price == 75 and denied.gold == 74,
		"unaffordable stitched removal echoes an exact seven-field rejection")
	_check(not poor_shop.can_rebase_removal(poor_before, denied, STRIKE),
		"unaffordable seven-field receipt cannot preflight")
	var forced_success: Dictionary = denied.duplicate(true)
	forced_success["ok"] = true
	_check(not poor_shop.can_rebase_removal(poor_before, forced_success, STRIKE)
		and not poor_shop.rebase_removal(poor_before, forced_success, STRIKE),
		"forged success flag on a poor receipt rejects")
	_check(poor_shop.get_state() == poor_shop_before and poor_shop.get_stock() == poor_stock_before,
		"unaffordable attempts leave the purchase ledger untouched")
	_check(poor_visit.get_state() == poor_before, "unaffordable attempts leave the visit untouched")

	# The genuine receipt still commits after every forgery.
	_check(shop.can_rebase_removal(before, authentic, STRIKE)
		and shop.rebase_removal(before, authentic, STRIKE),
		"genuine receipt still commits after every forgery")
	var committed := shop.get_state()
	_check(committed.deck == visit.get_state().deck and committed.gold == visit.get_state().gold
		and not committed.has("descriptors") and not committed.has("next_stitch_id"),
		"committed purchase ledger agrees with the visit and holds no descriptor authority")
	_check(shop.get_stock() == baseline_stock, "forgeries and the genuine rebase never change stock")

	# Returned snapshots and receipts stay detached.
	baseline["descriptors"] = {"forged": {}}
	baseline_stock["cards"][0]["sold"] = true
	authentic["descriptors"]["stitched_000001"]["cost"] = 9
	_check(shop.get_state() == committed and not shop.get_stock()["cards"][0]["sold"],
		"mutating returned snapshots and receipts cannot corrupt the purchase ledger")
	_check(visit.get_state().descriptors == made.descriptors,
		"mutating the removal receipt cannot corrupt the visit registry")
	_check(randi() == expected_draw, "every stitched forgery attempt consumes no global RNG")


const PATCH_STALL_PARTY := ["warden", "seamstress", "tinker"]
const PATCH_STALL_DECK := ["w_start", "s_start", "w_start", "t_start"]
const PATCH_STALL_IDS := ["stitched_badge", "spare_spool", "quilted_coat"]
const RARE_PATCH_CATALOG := "res://data/patches/mpw_synergy_patches.json"
## One eligible ordinary power patch is worth 100 tickets at a Patch Stall.
const ORDINARY_TICKETS := 100
const RARE_PATCH_IDS := ["relay_bobbin", "hearth_lining"]
const RETAINED_ORDINARY_IDS := ["button_eye", "frayfinder_mitt", "borrowed_button"]


## The shipped P8 rare records, read straight from their authored catalog.
func _rare_records() -> Array:
	var text := FileAccess.get_file_as_string(RARE_PATCH_CATALOG)
	_check(not text.is_empty(), "shipped P8 rare catalog is readable")
	var parsed: Variant = JSON.parse_string(text)
	_check(typeof(parsed) == TYPE_ARRAY and not parsed.is_empty(),
		"shipped P8 rare catalog parses to authored records")
	return parsed if typeof(parsed) == TYPE_ARRAY else []


## Independent integer-ticket oracle for the Patch Stall stock sampler:
## every eligible unowned ordinary power carries 100 tickets, every eligible
## unowned P8 rare its authored percentage of ONE ordinary patch, sorted IDs,
## one ticket draw per selection without replacement, all from the supplied
## RNG only.
func _ticket_oracle(rng: RandomNumberGenerator, candidates: Array, owned: Array,
		rare: Array) -> Array:
	var power_slots := _power_slots()
	var rare_tickets := {}
	var prices := {}
	for record in rare:
		rare_tickets[record.id] = ORDINARY_TICKETS * int(record.stock_weight_percent) / 100
		prices[record.id] = int(record.shop_price_gold)
	var weights := {}
	for offer in candidates:
		if not power_slots.has(offer.id) or owned.has(offer.id) or rare_tickets.has(offer.id):
			continue
		weights[offer.id] = ORDINARY_TICKETS
		prices[offer.id] = int(offer.price)
	for id in rare_tickets:
		if not owned.has(id):
			weights[id] = rare_tickets[id]
	var remaining: Array = weights.keys()
	remaining.sort()
	var offers: Array = []
	for i in range(3):
		var total := 0
		for id in remaining:
			total += weights[id]
		var ticket := rng.randi_range(0, total - 1)
		var walked := 0
		var chosen := ""
		for id in remaining:
			walked += weights[id]
			if ticket < walked:
				chosen = id
				break
		offers.append({"id": chosen, "price": prices[chosen]})
		remaining.erase(chosen)
	return offers


func _power_slots() -> Dictionary:
	var slots := {}
	for entry in RunAuthoredPatchDefinitions.load_power_definitions():
		slots[entry.id] = entry.slot
	return slots


func _sampled_ids(result: Dictionary) -> Array:
	var ids: Array = []
	if result.get("ok") != true:
		return ids
	for offer in result.get("offers", []):
		ids.append(offer.get("id"))
	return ids


func _offer_ids(candidates: Array, wanted: Array) -> Array:
	var found: Array = []
	for offer in candidates:
		if wanted.has(offer.get("id")):
			found.append(offer.duplicate(true))
	return found


func _seeded_rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _rare_variant(record: Dictionary, field: String, value: Variant) -> Dictionary:
	var copy: Dictionary = record.duplicate(true)
	copy[field] = value
	return copy


func _patch_stall_fixture(gold: int = 150, trinkets: Array = ["button_eye"]) -> Dictionary:
	return {
		"party_ids": PATCH_STALL_PARTY.duplicate(),
		"deck": PATCH_STALL_DECK.duplicate(),
		"trinkets": trinkets.duplicate(),
		"gold": gold,
		"cards": [],
		"offers_trinkets": [
			{"id": "stitched_badge", "price": 100},
			{"id": "spare_spool", "price": 100},
			{"id": "quilted_coat", "price": 100}
		]
	}


func _patch_stall(fixture: Dictionary) -> RunShopPurchases:
	return RunShopPurchases.new(
		fixture["party_ids"], fixture["deck"], fixture["trinkets"],
		fixture["gold"], fixture["cards"], fixture["offers_trinkets"], "patch_stall"
	)


func _patch_stall_state(gold: int = 150, trinkets: Array = ["button_eye"]) -> Dictionary:
	return {
		"party_ids": PATCH_STALL_PARTY.duplicate(),
		"deck": PATCH_STALL_DECK.duplicate(),
		"trinkets": trinkets.duplicate(),
		"gold": gold
	}


func _patch_stall_stock() -> Dictionary:
	return {
		"cards": [],
		"trinkets": [
			{"id": "stitched_badge", "price": 100, "sold": false},
			{"id": "spare_spool", "price": 100, "sold": false},
			{"id": "quilted_coat", "price": 100, "sold": false}
		]
	}


func _assert_stall_model(shop: RunShopPurchases, expected_state: Dictionary,
		expected_stock: Dictionary, label: String) -> void:
	_check(shop.get_state() == expected_state, label + " complete stall state")
	_check(shop.get_stock() == expected_stock, label + " complete three-patch stock")


func _stall_rejected(shop: RunShopPurchases, kind: String, id: String,
		label: String) -> void:
	var before_state := shop.get_state()
	var before_stock := shop.get_stock()
	var result := shop.buy(kind, id)
	_assert_result(result, false, before_state, before_stock, label)
	_assert_stall_model(shop, before_state, before_stock, label)
	result["state"]["deck"].append("forged")
	result["stock"]["trinkets"].clear()
	_assert_stall_model(shop, before_state, before_stock, label + " result isolation")


func _patch_stall_invalid(label: String, fixture: Dictionary) -> void:
	var original: Dictionary = fixture.duplicate(true)
	var stall := _patch_stall(fixture)
	_check(not stall.is_valid(), label + " patch stall invalid")
	_check(stall.get_state() == {} and stall.get_stock() == {},
		label + " no partial stall state published")
	_check(not stall.patch_stall_choice_used(),
		label + " invalid stall never reports a used choice")
	_assert_result(stall.buy("trinket", "stitched_badge"), false, {}, {},
		label + " refused patch")
	_check(fixture == original, label + " original stall input untouched")


func _test_patch_stall_contract() -> void:
	seed(76007)
	var expected_draw := randi()
	seed(76007)
	var stall := _patch_stall(_patch_stall_fixture())
	_check(stall.is_valid(), "three-patch stall accepts zero cards and three patches")
	_check(stall.has_method("patch_stall_choice_used"),
		"read-only choice-used query exists")
	_check(not stall.patch_stall_choice_used(), "fresh stall reports choice unused")
	_assert_stall_model(stall, _patch_stall_state(), _patch_stall_stock(),
		"patch stall initial")
	_check(stall.get_stock()["cards"].size() == 0, "patch stall offers zero cards")
	_check(stall.get_stock()["trinkets"].size() == 3,
		"patch stall offers exactly three patches")

	var authored: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
	var by_id := {}
	if authored is Dictionary:
		for entry in authored["trinkets"]:
			by_id[entry["id"]] = entry["price"]
	for listing in stall.get_stock()["trinkets"]:
		_check(by_id.get(listing["id"]) == listing["price"],
			"authored 100-gold price matches " + str(listing["id"]))
	for patch in PATCH_STALL_IDS:
		_check(by_id.get(patch) == 100, "shipped candidate is authored " + patch)

	# The ordinary Shop keeps its exact 5/2 stock on the same run context.
	var normal_shop := RunShopPurchases.new(
		PATCH_STALL_PARTY.duplicate(), PATCH_STALL_DECK.duplicate(), ["button_eye"], 150,
		[
			{"id": "s_zero", "owner": "warden", "price": 0},
			{"id": "s_exact", "owner": "seamstress", "price": 60},
			{"id": "s_costly", "owner": "tinker", "price": 140},
			{"id": "s_more", "owner": "warden", "price": 10},
			{"id": "s_final", "owner": "seamstress", "price": 130}
		],
		[{"id": "t_spool", "price": 50}, {"id": "t_pocket", "price": 20}]
	)
	_check(normal_shop.is_valid(), "normal Shop still admits the same run context")
	_check(normal_shop.get_stock()["cards"].size() == 5
		and normal_shop.get_stock()["trinkets"].size() == 2,
		"normal Shop still requires five cards and two patches")
	_check(normal_shop.get_state()["deck"] == PATCH_STALL_DECK,
		"normal Shop keeps the supplied deck")
	_check(not normal_shop.patch_stall_choice_used(),
		"normal Shop never reports a patch-stall choice")

	# Fail-closed Patch Stall shapes.
	for cards in [[{"id": "c_a", "owner": "warden", "price": 5}],
			[{}, {}, {}, {}, {}]]:
		var f := _patch_stall_fixture()
		f["cards"] = cards
		_patch_stall_invalid("nonempty stall cards", f)
	for count in [0, 2, 4]:
		var f := _patch_stall_fixture()
		f["offers_trinkets"] = [
			{"id": "stitched_badge", "price": 100},
			{"id": "spare_spool", "price": 100},
			{"id": "quilted_coat", "price": 100},
			{"id": "button_eye", "price": 100}
		].slice(0, count)
		_patch_stall_invalid(str(count) + "-patch stall", f)
	var dup := _patch_stall_fixture()
	dup["offers_trinkets"] = [
		{"id": "stitched_badge", "price": 100},
		{"id": "stitched_badge", "price": 100},
		{"id": "spare_spool", "price": 100}
	]
	_patch_stall_invalid("duplicate patch listing", dup)
	for price in [-1, 0.5, "100", true, null]:
		var f := _patch_stall_fixture()
		f["offers_trinkets"][0]["price"] = price
		_patch_stall_invalid("invalid patch price " + str(price), f)
	for gold in [-1, 1.5, "150", true]:
		var f := _patch_stall_fixture()
		f["gold"] = gold
		_patch_stall_invalid("invalid stall gold " + str(gold), f)
	for mode in ["", "Shop", "stall", "patch-stall", 7, null]:
		var f := _patch_stall_fixture()
		var bad := RunShopPurchases.new(f["party_ids"], f["deck"], f["trinkets"],
			f["gold"], f["cards"], f["offers_trinkets"], mode)
		_check(not bad.is_valid(), "unknown visit kind " + str(mode) + " rejects")
		_check(bad.get_state() == {} and bad.get_stock() == {},
			"unknown visit kind " + str(mode) + " publishes nothing")
		_check(not bad.patch_stall_choice_used(),
			"unknown visit kind " + str(mode) + " never reports a used choice")
	_check(randi() == expected_draw, "patch stall admission consumes no global RNG")


func _test_patch_stall_purchase() -> void:
	seed(76011)
	var expected_draw := randi()
	seed(76011)
	var stall := _patch_stall(_patch_stall_fixture())
	_check(stall.is_valid(), "purchase fixture stall valid")
	var state := _patch_stall_state()
	var stock := _patch_stall_stock()
	state["trinkets"].append("stitched_badge")
	state["gold"] = 50
	stock["trinkets"][0]["sold"] = true
	_assert_result(stall.buy("trinket", "stitched_badge"), true, state, stock,
		"authored 100-gold stitched_badge",
		{"kind": "trinket", "id": "stitched_badge", "price": 100})
	_check(stall.patch_stall_choice_used(), "successful purchase latches the choice")
	_check(stall.get_state()["trinkets"].count("stitched_badge") == 1,
		"exactly one added patch")
	_check(stall.get_state()["gold"] == 50, "exactly 50 gold after the purchase")

	var replay_before := stall.get_state()
	var replay_stock := stall.get_stock()
	_assert_result(stall.buy("trinket", "stitched_badge"), false,
		replay_before, replay_stock, "replay of chosen patch")
	_check(stall.patch_stall_choice_used(), "replay keeps the choice latched")
	_check(stall.get_state() == replay_before and stall.get_stock() == replay_stock,
		"replay spends nothing")
	for other in ["spare_spool", "quilted_coat"]:
		_assert_result(stall.buy("trinket", other), false,
			replay_before, replay_stock, "alternate listing " + other + " after choice")
	_check(not stall.get_stock()["trinkets"][1]["sold"]
		and not stall.get_stock()["trinkets"][2]["sold"],
		"other two listings remain unsold")
	_assert_result(stall.buy("card", "stitched_badge"), false,
		replay_before, replay_stock, "card kind at the stall")
	_assert_result(stall.buy("card", "anything"), false,
		replay_before, replay_stock, "empty card stock at the stall")
	_check(randi() == expected_draw, "stall purchase and replays consume no global RNG")

	for patch in PATCH_STALL_IDS:
		var fresh := _patch_stall(_patch_stall_fixture())
		var paid := fresh.buy("trinket", patch)
		_check(paid.ok
			and paid.receipt == {"kind": "trinket", "id": patch, "price": 100}
			and fresh.get_state()["gold"] == 50,
			"authored stall can charge any single patch " + patch)
		_check(fresh.patch_stall_choice_used(), "single-use latch per " + patch)
		_check(fresh.get_state()["trinkets"] == ["button_eye", patch],
			"only the chosen patch is added " + patch)


func _test_patch_stall_rejections() -> void:
	seed(76013)
	var expected_draw := randi()
	seed(76013)
	var owned := _patch_stall(_patch_stall_fixture(150, ["button_eye", "spare_spool"]))
	_check(owned.is_valid(), "owned-listing stall still admits")
	_check(owned.get_stock()["trinkets"][1]["sold"], "owned listing starts sold")
	_assert_result(owned.buy("trinket", "spare_spool"), false,
		owned.get_state(), owned.get_stock(), "owned patch cannot be bought")
	_check(not owned.patch_stall_choice_used(),
		"rejected owned purchase does not latch")

	var poor := _patch_stall(_patch_stall_fixture(99))
	_assert_result(poor.buy("trinket", "stitched_badge"), false,
		poor.get_state(), poor.get_stock(),
		"99-gold cannot afford a 100-gold patch")
	_check(not poor.patch_stall_choice_used(),
		"rejected unaffordable purchase does not latch")
	_check(poor.get_state()["gold"] == 99, "unaffordable rejection spends nothing")

	var stall := _patch_stall(_patch_stall_fixture())
	for action in [["trinket", "not_in_stock", "unknown trinket"],
			["trinket", "", "empty ID"], ["trinket", " ", "whitespace ID"],
			["", "stitched_badge", "blank kind"],
			["Trinket", "stitched_badge", "noncanonical kind"],
			["other", "stitched_badge", "other kind"]]:
		_stall_rejected(stall, action[0], action[1], "stall reject " + action[2])
	_check(not stall.patch_stall_choice_used(),
		"every stall rejection leaves the choice unused")
	_check(stall.get_stock()["trinkets"].all(func(l): return not l["sold"]),
		"rejected stall attempts leave every listing unsold")
	_check(stall.get_state()["gold"] == 150, "rejected stall attempts spend nothing")

	# Paid removal rebase does not operate at a Patch Stall.
	var stall_cards: Array[String] = []
	stall_cards.assign(stall.get_state()["deck"])
	var visit := RunShopVisit.new(stall_cards, stall.get_state()["gold"], 0)
	_check(visit.open_visit("stall-removal"),
		"real visit still opens on the stall ledger")
	var before := visit.get_state()
	var removed := RunShopCardRemoval.try_remove(stall_cards, before.gold, 0, "w_start")
	var frozen_state := stall.get_state()
	var frozen_stock := stall.get_stock()
	_check(removed.ok, "otherwise legal removal helper result computed")
	_check(not stall.can_rebase_removal(before, removed, "w_start"),
		"stall can_rebase_removal refuses the legal removal")
	_check(not stall.rebase_removal(before, removed, "w_start"),
		"stall rebase_removal refuses the legal removal")
	_check(stall.get_state() == frozen_state and stall.get_stock() == frozen_stock,
		"stall rebase attempts do not mutate state or stock")
	_check(not stall.patch_stall_choice_used(),
		"stall removal rebase attempt does not latch the patch choice")

	# Genuine wardrobe replacement via settle_displaced_patch.
	var bought := _patch_stall(_patch_stall_fixture())
	_check(bought.buy("trinket", "stitched_badge").ok,
		"stall permits the first paid patch for the settle test")
	var heroes := [
		{"id": "warden", "position": 1, "hp": 40, "max_hp": 40, "block": 0,
			"statuses": {}},
		{"id": "seamstress", "position": 2, "hp": 30, "max_hp": 30, "block": 0,
			"statuses": {}},
		{"id": "tinker", "position": 3, "hp": 26, "max_hp": 26, "block": 0,
			"statuses": {}}
	]
	var definitions := [
		{"id": "stitched_badge", "slot": "HEAD"},
		{"id": "button_eye", "slot": "HEAD"}
	]
	var wardrobe := RunPatchWardrobe.new(heroes,
		["button_eye", "stitched_badge"], definitions, 0,
		bought.get_state()["gold"], bought.get_state()["deck"], 0, true)
	_check(wardrobe.is_valid(), "wardrobe admits the stall-posted inventory")
	var first_sew := wardrobe.sew("button_eye", "warden", "HEAD", "sew-old",
		wardrobe.get_snapshot())
	_check(first_sew.ok, "prior old patch sewn at HEAD")
	var replacement := wardrobe.sew("stitched_badge", "warden", "HEAD", "sew-new",
		wardrobe.get_snapshot())
	_check(replacement.ok and replacement.receipt.displaced_id == "button_eye",
		"genuine wardrobe replacement displaces the old patch")
	_check(not wardrobe.get_snapshot()["owned"].has("button_eye"),
		"wardrobe destroys the old patch from ownership")
	_check(bought.settle_displaced_patch("button_eye", "stitched_badge",
		bought.get_state()),
		"stall settles the displaced patch after the wardrobe sew")
	_check(bought.get_state()["trinkets"] == ["stitched_badge"],
		"one patch owner remains after settle and no second charge")
	_check(bought.get_state()["gold"] == 50, "settle does not charge a second time")
	_check(not bought.settle_displaced_patch("button_eye", "stitched_badge",
		bought.get_state()), "settle cannot be replayed")
	# Non-vacuous fail-closed case: both IDs are genuinely owned, but the
	# "purchased" one was never sold at this stall, so settle must refuse.
	var stranger := _patch_stall(_patch_stall_fixture(150, ["button_eye", "padded_vest"]))
	_check(stranger.buy("trinket", "stitched_badge").ok,
		"stall sale recorded before the unsold-listing check")
	var stranger_before := stranger.get_state()
	_check(stranger_before.trinkets == ["button_eye", "padded_vest", "stitched_badge"],
		"unsold-listing fixture owns both settle operands")
	_check(not stranger.settle_displaced_patch("button_eye", "padded_vest",
		stranger_before), "settle refuses a patch never sold at this stall")
	_check(stranger.get_state() == stranger_before,
		"refused settle leaves ownership unchanged")

	_check(randi() == expected_draw,
		"stall rejections, removal rebases and settle consume no global RNG")


const STITCHED_PARTY := ["warden", "seamstress", "tinker", "lantern_monk"]


## Authentic seeded Stitched stock: the real sampler over the authored candidates.
func _stitched_stall_stock(rng: RandomNumberGenerator, owned: Array) -> Array:
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/shop/initial_offers.json"))
	var sampled := RunShopPurchases.sample_patch_stall_offers(rng, authored.trinkets, owned)
	_check(sampled.ok and sampled.offers.size() == 3,
		"seeded Stitched stall sampler returns three authored offers")
	return sampled.offers if sampled.ok else []


func _stitched_stall(party: Array, deck: Array, owned: Array, gold: Variant,
		offers: Array) -> RunShopPurchases:
	return RunShopPurchases.new(party.duplicate(true), deck.duplicate(true),
		owned.duplicate(true), gold, [], offers.duplicate(true), "patch_stall")


func _test_four_hero_patch_stall() -> void:
	seed(495011)
	var expected_draw := randi()
	seed(495011)
	var rng := _seeded_rng(495011)
	var owned := ["button_eye"]
	var offers := _stitched_stall_stock(rng, owned)
	var after_stock := rng.state
	_check(offers.size() == 3, "four-hero fixture has three seeded offers")
	if offers.size() != 3:
		return
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/shop/initial_offers.json"))
	var authored_prices := {}
	for entry in authored.trinkets:
		authored_prices[entry.id] = int(entry.price)
	var seen := {}
	for offer in offers:
		_check(not seen.has(offer.id) and not owned.has(offer.id)
			and offer.price is int and offer.price > 0,
			"seeded offer is distinct, unowned and priced " + str(offer.id))
		seen[offer.id] = true
		if authored_prices.has(offer.id):
			_check(authored_prices[offer.id] == offer.price,
				"ordinary offer keeps its authored price " + str(offer.id))
	var price: int = offers[0].price

	# AC1: admission preserves all four heroes in order, zero cards, three patches.
	var stall := _stitched_stall(STITCHED_PARTY, [], owned, 500, offers)
	_check(stall.is_valid(), "four-hero empty-deck Patch Stall admits")
	var initial_state := stall.get_state()
	var initial_stock := stall.get_stock()
	_check(initial_state == {"party_ids": STITCHED_PARTY, "deck": [],
		"trinkets": owned, "gold": 500}, "four-hero ledger exact and in order")
	var expected_stock := {"cards": [], "trinkets": []}
	for offer in offers:
		expected_stock.trinkets.append({"id": offer.id, "price": offer.price, "sold": false})
	_check(initial_stock == expected_stock, "stock is the exact three seeded priced patches")
	_check(not stall.patch_stall_choice_used(), "fresh four-hero stall has no used choice")

	# Inputs and reads are detached.
	var fixture_party := STITCHED_PARTY.duplicate()
	var fixture_offers := offers.duplicate(true)
	var detached := RunShopPurchases.new(fixture_party, [], owned.duplicate(), 500, [],
		fixture_offers, "patch_stall")
	fixture_party[3] = "intruder"
	fixture_offers[0].price = 0
	fixture_offers[1].id = "forged"
	_check(detached.get_state() == initial_state and detached.get_stock() == initial_stock,
		"four-hero admission copies caller data")
	var read_state := detached.get_state()
	var read_stock := detached.get_stock()
	read_state.party_ids.clear()
	read_state.gold = 1
	read_stock.trinkets[0].sold = true
	read_stock.trinkets.pop_back()
	_check(detached.get_state() == initial_state and detached.get_stock() == initial_stock,
		"four-hero reads are detached")

	# AC2: one affordable purchase spends exactly its price once.
	var expected_state := initial_state.duplicate(true)
	expected_state.gold -= price
	expected_state.trinkets.append(offers[0].id)
	var paid_stock := initial_stock.duplicate(true)
	paid_stock.trinkets[0].sold = true
	var paid := stall.buy("trinket", offers[0].id)
	_assert_result(paid, true, expected_state, paid_stock, "four-hero purchase",
		{"kind": "trinket", "id": offers[0].id, "price": price})
	_check(stall.patch_stall_choice_used(), "four-hero purchase latches the choice")
	_check(stall.get_state().deck == [] and stall.get_state().party_ids == STITCHED_PARTY,
		"purchase leaves empty deck and party intact")
	paid.receipt.price = -1
	paid.state.party_ids.clear()
	paid.stock.trinkets.clear()
	_assert_stall_model(stall, expected_state, paid_stock, "four-hero paid result detached")
	for repeat in range(2):
		for offer in offers:
			_assert_result(stall.buy("trinket", offer.id), false, expected_state,
				paid_stock, "four-hero later buy " + str(offer.id))
	_assert_result(stall.buy("card", "anything"), false, expected_state, paid_stock,
		"four-hero card kind refused")

	# Exact-price purchase empties the wallet; every other offer stays buyable data.
	var exact := _stitched_stall(STITCHED_PARTY, [], owned, price, offers)
	_check(exact.buy("trinket", offers[0].id).ok and exact.get_state().gold == 0,
		"exact-wallet four-hero purchase succeeds")

	# AC3: unaffordable, unoffered, owned/sold and malformed selections change nothing.
	var poor := _stitched_stall(STITCHED_PARTY, [], owned, price - 1, offers)
	_check(poor.is_valid(), "four-hero poor stall admits")
	_stall_rejected(poor, "trinket", offers[0].id, "four-hero unaffordable")
	_check(not poor.patch_stall_choice_used() and poor.get_state().gold == price - 1,
		"unaffordable four-hero buy neither latches nor spends")
	for action in [["trinket", "not_in_stock"], ["trinket", ""], ["trinket", " "],
			["", offers[0].id], ["Trinket", offers[0].id], ["card", offers[0].id]]:
		_stall_rejected(poor, action[0], action[1], "four-hero refused " + str(action))
	_check(not poor.patch_stall_choice_used(), "four-hero refusals never latch")
	var sold_stall := _stitched_stall(STITCHED_PARTY, [], owned + [offers[1].id], 500, offers)
	_check(sold_stall.is_valid() and sold_stall.get_stock().trinkets[1].sold,
		"already-owned four-hero listing starts sold")
	_stall_rejected(sold_stall, "trinket", offers[1].id, "four-hero already sold")
	_check(not sold_stall.patch_stall_choice_used(), "sold-listing refusal does not latch")

	# AC4: cardinality only widens for Patch Stall; all other bounds stay closed.
	_check(_stitched_stall(PATCH_STALL_PARTY, PATCH_STALL_DECK, owned, 500, offers).is_valid(),
		"three-hero Patch Stall remains valid")
	for bad_party in [[], ["warden"], ["warden", "seamstress"],
			STITCHED_PARTY + ["scarecrow"]]:
		var bad := _stitched_stall(bad_party, [], owned, 500, offers)
		_check(not bad.is_valid() and bad.get_state() == {} and bad.get_stock() == {},
			"Patch Stall refuses a party of " + str(bad_party.size()))
	for bad_party in [
			["warden", "warden", "tinker", "lantern_monk"],
			["warden", "seamstress", "", "lantern_monk"],
			["warden", "seamstress", "  ", "lantern_monk"],
			["warden", "seamstress", "tinker", 7],
			["warden", "seamstress", "tinker", null]]:
		var bad := _stitched_stall(bad_party, [], owned, 500, offers)
		_check(not bad.is_valid() and bad.get_state() == {} and bad.get_stock() == {},
			"four-hero Patch Stall refuses bad IDs " + str(bad_party))
	var bad_stock_cases: Array = [offers.slice(0, 2), offers + [offers[0]],
		[offers[0], offers[0], offers[1]],
		[{"id": offers[0].id, "price": -1}, offers[1], offers[2]],
		[{"id": offers[0].id, "price": 1.5}, offers[1], offers[2]]]
	for stock_case in bad_stock_cases:
		_check(not _stitched_stall(STITCHED_PARTY, [], owned, 500, stock_case).is_valid(),
			"four-hero Patch Stall refuses invalid stock")
	var with_cards := RunShopPurchases.new(STITCHED_PARTY.duplicate(), [], owned.duplicate(),
		500, [{"id": "c_a", "owner": "warden", "price": 5}], offers.duplicate(true), "patch_stall")
	_check(not with_cards.is_valid(), "four-hero Patch Stall refuses card offers")
	for gold in [-1, 1.5, "500", null]:
		_check(not _stitched_stall(STITCHED_PARTY, [], owned, gold, offers).is_valid(),
			"four-hero Patch Stall refuses gold " + str(gold))
	# Shop and Peddler still require exactly three actors, with otherwise legal stock.
	var shop_fixture := _fixture()
	shop_fixture.party_ids = STITCHED_PARTY.duplicate()
	_check(not _shop(shop_fixture).is_valid(), "Shop refuses a four-hero party")
	var peddler_fixture := _peddler_fixture(_seeded_rng(256031))
	var peddler_four: Dictionary = peddler_fixture.duplicate(true)
	_check(_peddler(peddler_fixture).is_valid(), "three-hero Peddler control still admits")
	peddler_four.party_ids = STITCHED_PARTY.duplicate()
	_check(not _peddler(peddler_four).is_valid(), "Peddler refuses a four-hero party")
	for kind in ["", "stall", "Patch_Stall", 7, null]:
		var odd := RunShopPurchases.new(STITCHED_PARTY.duplicate(), [], owned.duplicate(),
			500, [], offers.duplicate(true), kind)
		_check(not odd.is_valid(), "four-hero unknown kind " + str(kind) + " refuses")
	_check(rng.state == after_stock, "four-hero admission and purchases consume no run RNG")
	_check(randi() == expected_draw, "four-hero admission and purchases consume no global RNG")


func _test_legacy_quote_and_rebase() -> void:
	seed(730190)
	var expected_draw := randi()
	seed(730190)
	var deck: Array[String] = ["w_start", "s_start", "w_start", "t_start"]
	var visit := RunShopVisit.new(deck, 200, 1)
	_check(visit.open_visit("legacy-shop") and visit.quote() == 100,
		"legacy visit still quotes 100 after one prior removal")
	var shop := RunShopPurchases.new(
		["warden", "seamstress", "tinker"], deck, [], 200,
		[
			{"id": "c_a", "owner": "warden", "price": 5},
			{"id": "c_b", "owner": "seamstress", "price": 6},
			{"id": "c_c", "owner": "tinker", "price": 7},
			{"id": "c_d", "owner": "warden", "price": 8},
			{"id": "c_e", "owner": "seamstress", "price": 9}
		],
		[{"id": "t_one", "price": 10}, {"id": "t_two", "price": 11}]
	)
	var before := visit.get_state()
	_check(not before.has("descriptors") and not before.has("next_stitch_id"),
		"legacy snapshot carries neither stitched field")
	var frozen := shop.get_state()
	var result := visit.remove_card("w_start")
	_check(result.size() == 5 and result.ok and result.price == 100
		and result.gold == 100 and result.prior_removals == 2,
		"legacy removal returns the exact five-field 100-gold receipt")
	_check(shop.can_rebase_removal(before, result, "w_start"),
		"legacy five-field preflight still passes")
	var stitched_shaped: Dictionary = result.duplicate(true)
	stitched_shaped["descriptors"] = {}
	stitched_shaped["next_stitch_id"] = 2
	_check(not shop.can_rebase_removal(before, stitched_shaped, "w_start"),
		"seven-field receipt against a legacy snapshot rejects")
	_check(shop.get_state() == frozen, "rejected wrong-shape legacy rebase is read only")
	_check(shop.rebase_removal(before, result, "w_start")
		and shop.get_state().deck == visit.get_state().deck
		and shop.get_state().gold == visit.get_state().gold,
		"legacy five-field removal still rebases deck and gold")
	_check(not shop.rebase_removal(before, result, "w_start"), "legacy replay still rejects")
	_check(result.deck.count("w_start") == 1 and visit.get_state().prior_removals == 2,
		"legacy first-copy semantics and removal count preserved")
	_check(randi() == expected_draw, "legacy rebase consumes no global RNG")


func _test_patch_stall_sampling() -> void:
	# Read the shipped candidate catalog from initial_offers.json.
	var authored_text := FileAccess.get_file_as_string("res://data/shop/initial_offers.json")
	_check(authored_text != null and not authored_text.is_empty(),
		"sampling reads initial_offers.json")
	var authored: Variant = JSON.parse_string(authored_text)
	_check(typeof(authored) == TYPE_DICTIONARY and authored.has("trinkets"),
		"initial_offers.json has trinket candidates")

	var candidates: Array = authored.get("trinkets", [])

	# Real power definitions must exclude the inert starter slots.
	var powers := RunAuthoredPatchDefinitions.load_power_definitions()
	_check(typeof(powers) == TYPE_ARRAY and not powers.is_empty(),
		"power definitions loaded")
	var has_inert: bool = false
	var real_power_ids: Array = []
	for entry in powers:
		var id_str: String = str(entry.get("id", ""))
		if id_str == "stitched_badge" or id_str == "spare_spool":
			has_inert = true
		else:
			real_power_ids.append(id_str)
	_check(not has_inert, "initial starter slots excluded from real powers")

	# Helper must return exactly three offers for a genuine seed and candidates.
	seed(88001)
	var expected_draw := randi()
	seed(88001)

	var rng := RandomNumberGenerator.new()
	rng.seed = 88001

	var owned: Array = ["button_eye"]
	var result := RunShopPurchases.sample_patch_stall_offers(rng, candidates, owned)
	_check(result.get("ok") == true, "genuine sampling succeeds with real candidates")
	_check(result.has("offers"), "success carries offers array")
	_check(result.get("offers").size() == 3, "exactly three offers returned")

	# Every returned offer must be a real unowned power with a positive price.
	var selected_ids: Array = []
	for offer in result.get("offers"):
		_check(typeof(offer) == TYPE_DICTIONARY, "offer is dictionary")
		_check(offer.has("id") and offer.has("price"), "offer has id and price")
		var id_str: String = str(offer.get("id"))
		var price: int = int(offer.get("price"))
		_check(price > 0, "positive authored price " + id_str)
		_check(not selected_ids.has(id_str), "distinct selected id " + id_str)
		# The selected IDs should not include owned or inert entries.
		_check(not id_str.is_empty(), "non-empty selected id")
		_check(id_str != "stitched_badge" and id_str != "spare_spool",
			"never selects inert starter slot")
		_check(not owned.has(id_str), "selected id not owned")
		_check(real_power_ids.has(id_str), "selected id is a catalog power")
		selected_ids.append(id_str)

	# Same seed + same owned + same candidates yields identical offers.
	var replay_result := RunShopPurchases.sample_patch_stall_offers(
		RandomNumberGenerator.new(), candidates, owned)
	# Replay needs a new RNG; use the same seed for deterministic replay.
	var replay_rng := RandomNumberGenerator.new()
	replay_rng.seed = 88001
	replay_result = RunShopPurchases.sample_patch_stall_offers(
		replay_rng, candidates, owned)
	_check(replay_result.get("ok") == true, "replay with same seed succeeds")
	_check(replay_result.get("offers") == result.get("offers"),
		"same seed yields same three offers")

	# Reversed candidate order replay must still yield the same offers.
	var reversed_candidates: Array = candidates.duplicate(true)
	reversed_candidates.reverse()
	var reversed_result := RunShopPurchases.sample_patch_stall_offers(
		RandomNumberGenerator.new(), reversed_candidates, owned)
	var reversed_rng := RandomNumberGenerator.new()
	reversed_rng.seed = 88001
	reversed_result = RunShopPurchases.sample_patch_stall_offers(
		reversed_rng, reversed_candidates, owned)
	_check(reversed_result.get("ok") == true,
		"reversed candidates with same seed succeeds")
	_check(reversed_result.get("offers") == result.get("offers"),
		"reversed-candidate replay yields same offers (input-order independent)")

	# The three unique unowned prices should all be the authored 100 gold.
	var prices: Array = []
	for offer in result.get("offers"):
		prices.append(offer.get("price"))
	_check(prices.size() == 3 and prices[0] == 100 and prices[1] == 100
		and prices[2] == 100, "three unique unowned prices are authored 100 gold")

	var rare := _rare_records()
	var power_slots := _power_slots()
	var unowned: Array = []
	# The two shipped rares are registered catalog powers in their authored
	# slots, and now also have the same 100-gold quote in shared priced stock.
	for record in rare:
		_check(power_slots.get(record.id) == record.slot,
			"registered P8 power slot matches " + str(record.id))
		var listed := candidates.filter(func(offer): return offer.get("id") == record.id)
		_check(listed.size() == 1 and listed[0].price == record.shop_price_gold,
			"rare has one shared price matching its own authored catalog: " + str(record.id))
	for id in RARE_PATCH_IDS:
		_check(power_slots.has(id), "shipped rare is a registered power: " + id)

	# AC1: a bounded seeded search witnesses BOTH rares as genuine three-offer
	# stock, alongside the retained named ordinary candidates.
	var witness_targets: Array = RARE_PATCH_IDS + RETAINED_ORDINARY_IDS
	var witnesses := {}
	var witness_offers := {}
	for value in range(1, 601):
		var sweep_rng := RandomNumberGenerator.new()
		sweep_rng.seed = value
		var sampled := RunShopPurchases.sample_patch_stall_offers(
			sweep_rng, candidates, unowned, rare)
		if sampled.get("ok") != true or sampled.get("offers").size() != 3:
			_check(false, "bounded witness sampling succeeds for seed " + str(value))
			break
		var seen := {}
		for offer in sampled.get("offers"):
			_check(typeof(offer.get("id")) == TYPE_STRING and typeof(offer.get("price")) == TYPE_INT,
				"witness offer is an authored id and whole-gold price")
			_check(not seen.has(offer.get("id")), "witness sample has three distinct IDs")
			seen[offer.get("id")] = true
			if witness_targets.has(offer.get("id")) and not witnesses.has(offer.get("id")):
				witnesses[offer.get("id")] = value
				witness_offers[offer.get("id")] = offer.duplicate(true)
		if witnesses.size() == witness_targets.size():
			break
	for id in witness_targets:
		_check(witnesses.has(id), "bounded seeded search witnesses " + id)
	_check(power_slots.get("relay_bobbin") == "HEAD"
		and power_slots.get("hearth_lining") == "COAT",
		"the witnessed rares are genuine HEAD and COAT powers")
	# The three named earlier ordinary candidates are still stocked at the
	# authored 100-gold quote alongside the rares.
	for entry in _offer_ids(candidates, RETAINED_ORDINARY_IDS):
		_check(witnesses.has(entry.get("id")),
			"retained ordinary candidate is still offered: " + str(entry.get("id")))
		if not witnesses.has(entry.get("id")):
			continue
		_check(entry.get("price") == 100
			and witness_offers[entry.get("id")].get("price") == int(entry.get("price")),
			"retained ordinary candidate keeps its authored quote: " + str(entry.get("id")))
	for record in rare:
		if not witnesses.has(record.id):
			continue
		var offer: Dictionary = witness_offers[record.id]
		_check(offer.get("price") == int(record.shop_price_gold),
			"witnessed rare keeps its authored 100-gold quote: " + str(record.id))
		_check(power_slots.get(record.id) == record.slot,
			"witnessed rare keeps its authored slot: " + str(record.id))
		# The same three-offer sample is genuinely purchasable at that price.
		var rare_sample := RunShopPurchases.sample_patch_stall_offers(
			_seeded_rng(witnesses[record.id]), candidates, unowned, rare)
		var rare_stall := RunShopPurchases.new(PATCH_STALL_PARTY.duplicate(),
			PATCH_STALL_DECK.duplicate(), unowned.duplicate(), int(record.shop_price_gold),
			[], rare_sample.get("offers", []), "patch_stall")
		_check(rare_stall.is_valid(), "witnessed rare sample is a valid stall: " + str(record.id))
		_check(rare_stall.get_stock()["trinkets"].size() == 3,
			"witnessed rare sample keeps exactly three offers: " + str(record.id))
		var paid := rare_stall.buy("trinket", record.id)
		_check(paid.get("ok") == true and paid.get("receipt") == {
			"kind": "trinket", "id": record.id, "price": int(record.shop_price_gold)},
			"rare purchase records its authored receipt once: " + str(record.id))
		_check(rare_stall.get_state().gold == 0
			and rare_stall.get_state().trinkets == [record.id]
			and rare_stall.patch_stall_choice_used(),
			"rare purchase spends exactly 100 gold and latches: " + str(record.id))
		var again := rare_stall.buy("trinket", record.id)
		_check(again.get("ok") != true and not again.has("receipt")
			and rare_stall.get_state().gold == 0,
			"rare patch cannot be bought twice and gold never goes negative")
		var sold := 0
		for listing in rare_stall.get_stock()["trinkets"]:
			if listing.get("id") == record.id and listing.get("sold") == true:
				sold += 1
		_check(sold == 1, "rare sale is recorded exactly once in the stock ledger")
		# One gold short of the authored quote can never take the rare.
		var short_stall := RunShopPurchases.new(PATCH_STALL_PARTY.duplicate(),
			PATCH_STALL_DECK.duplicate(), unowned.duplicate(),
			int(record.shop_price_gold) - 1, [], rare_sample.get("offers", []), "patch_stall")
		var short_paid := short_stall.buy("trinket", record.id)
		_check(short_paid.get("ok") != true and not short_paid.has("receipt")
			and short_stall.get_state().gold == int(record.shop_price_gold) - 1
			and not short_stall.patch_stall_choice_used()
			and short_stall.get_state().trinkets.is_empty(),
			"one gold short never buys a rare and never latches")
		# Leave-safe: every other offer is refused once the single choice is used.
		for other in rare_sample.get("offers", []):
			if other.get("id") != record.id:
				_check(rare_stall.buy("trinket", other.get("id")).get("ok") != true,
					"second paid purchase refused after a rare")

	# AC2: exact relative weights against the independent ticket oracle.
	# Each P8 rare is authored at 10% of ONE ordinary patch's 100 tickets.
	for record in rare:
		_check(ORDINARY_TICKETS * int(record.stock_weight_percent) / 100 == 10,
			"rare weight is 10% of one ordinary patch: " + str(record.id))
	var oracle_seeds := [1, 7, 4242, 88001, 999983]
	for value in oracle_seeds:
		var actual_rng := _seeded_rng(value)
		var oracle_rng := _seeded_rng(value)
		var expected := _ticket_oracle(oracle_rng, candidates, unowned, rare)
		var actual := RunShopPurchases.sample_patch_stall_offers(
			actual_rng, candidates, unowned, rare)
		_check(actual.get("ok") == true and actual.get("offers") == expected,
			"weighted ticket oracle matches sampler for seed " + str(value))
		_check(actual_rng.state == oracle_rng.state,
			"sampler consumes exactly the oracle's draws for seed " + str(value))
		var reversed: Array = candidates.duplicate(true)
		reversed.reverse()
		var reversed_rng_actual := _seeded_rng(value)
		var reversed_oracle_rng := _seeded_rng(value)
		var reversed_expected := _ticket_oracle(reversed_oracle_rng, reversed, unowned, rare)
		var reversed_actual := RunShopPurchases.sample_patch_stall_offers(
			reversed_rng_actual, reversed, unowned, rare)
		_check(reversed_actual.get("ok") == true and reversed_actual.get("offers") == expected
			and reversed_expected == expected,
			"reversed offer data keeps the sorted-ID ticket draws for seed " + str(value))
		_check(reversed_rng_actual.state == oracle_rng.state,
			"reversed offer data consumes the same draws for seed " + str(value))

	# A three-ordinary/two-rare pool isolates the relative weight: the rares
	# hold 20 of 320 tickets, so the FIRST draw is rare about one time in 16.
	var subset: Array = _offer_ids(candidates, RETAINED_ORDINARY_IDS)
	_check(subset.size() == 3, "three retained ordinary candidates form the weight subset")
	var rare_firsts := 0
	for value in range(1, 321):
		var subset_result := RunShopPurchases.sample_patch_stall_offers(
			_seeded_rng(value), subset, unowned, rare)
		_check(subset_result.get("ok") == true
			and subset_result.get("offers").size() == 3,
			"three-ordinary/two-rare subset still stocks three")
		if RARE_PATCH_IDS.has(subset_result.get("offers")[0].get("id")):
			rare_firsts += 1
	_check(rare_firsts >= 8 and rare_firsts <= 40,
		"first draw treats both rares as one tenth of one ordinary (saw "
		+ str(rare_firsts) + "/320)")

	# AC4: owned rares leave the pool without collapsing the ordinary stock.
	for value in [3, 11, 97]:
		var owned_result := RunShopPurchases.sample_patch_stall_offers(
			_seeded_rng(value), candidates, RARE_PATCH_IDS.duplicate(), rare)
		_check(owned_result.get("ok") == true
			and owned_result.get("offers").size() == 3
			and _sampled_ids(owned_result).all(func(id): return not RARE_PATCH_IDS.has(id)),
			"owned rares are never restocked while ordinary stock continues")

	# AC4: fewer than three total eligible unowned powers fail closed with no
	# RNG consumed; the two-ordinary pool is genuinely smaller than three.
	var two_ordinary: Array = _offer_ids(candidates, ["button_eye", "frayfinder_mitt"])
	_check(two_ordinary.size() == 2, "two-ordinary pool fixture is non-vacuous")
	var short_rng := _seeded_rng(5150)
	var short_state := short_rng.state
	_check(RunShopPurchases.sample_patch_stall_offers(short_rng, two_ordinary,
			RARE_PATCH_IDS.duplicate(), rare) == {"ok": false}
		and short_rng.state == short_state,
		"two eligible unowned powers reject before any draw")
	_check(RunShopPurchases.sample_patch_stall_offers(short_rng, two_ordinary,
			unowned, []) == {"ok": false} and short_rng.state == short_state,
		"empty rare catalog still requires three eligible powers")

	# AC4: malformed rare catalog records refuse the stall, never a fallback.
	var malformed_rare: Array = []
	for field in ["id", "slot", "rarity", "shop_price_gold", "stock_weight_percent",
			"stock_weight_basis", "stock_competes_for_existing_slot"]:
		var missing: Dictionary = rare[0].duplicate(true)
		missing.erase(field)
		malformed_rare.append(["missing " + field, [missing]])
	malformed_rare.append(["wrong slot", [_rare_variant(rare[0], "slot", "COAT")]])
	malformed_rare.append(["unauthored id",
		[_rare_variant(_rare_variant(rare[0], "id", "unauthored_rare"), "slot", "HEAD")]])
	malformed_rare.append(["duplicate record", [rare[0], rare[0]]])
	malformed_rare.append(["not rare", [_rare_variant(rare[0], "rarity", "common")]])
	malformed_rare.append(["wrong weight basis",
		[_rare_variant(rare[0], "stock_weight_basis", "whole_stock")]])
	malformed_rare.append(["does not compete",
		[_rare_variant(rare[0], "stock_competes_for_existing_slot", false)]])
	malformed_rare.append(["zero price", [_rare_variant(rare[0], "shop_price_gold", 0)]])
	malformed_rare.append(["fractional price", [_rare_variant(rare[0], "shop_price_gold", 99.5)]])
	malformed_rare.append(["string price", [_rare_variant(rare[0], "shop_price_gold", "100")]])
	malformed_rare.append(["zero weight", [_rare_variant(rare[0], "stock_weight_percent", 0)]])
	malformed_rare.append(["negative weight", [_rare_variant(rare[0], "stock_weight_percent", -10)]])
	malformed_rare.append(["fractional weight", [_rare_variant(rare[0], "stock_weight_percent", 2.5)]])
	malformed_rare.append(["non-dictionary record", [null]])
	malformed_rare.append(["string record", ["relay_bobbin"]])
	malformed_rare.append(["non-array catalog", {"records": rare.duplicate(true)}])
	for entry in malformed_rare:
		var denied_rng := _seeded_rng(7321)
		var denied_state := denied_rng.state
		_check(RunShopPurchases.sample_patch_stall_offers(denied_rng, candidates,
				unowned, entry[1]) == {"ok": false} and denied_rng.state == denied_state,
			"malformed rare catalog rejects without a draw: " + str(entry[0]))

	# AC4: corrupt or duplicate ordinary offers refuse before any draw too.
	var corrupt: Array = []
	var power_candidates: Array = _offer_ids(candidates, RETAINED_ORDINARY_IDS)
	_check(power_candidates.size() == 3, "corrupt-offer fixture uses real power candidates")
	var duplicate_offer: Array = power_candidates.duplicate(true)
	duplicate_offer.append(power_candidates[0].duplicate(true))
	corrupt.append(["duplicate offer", duplicate_offer])
	var missing_price: Array = candidates.duplicate(true)
	missing_price[0].erase("price")
	corrupt.append(["missing price", missing_price])
	var missing_id: Array = candidates.duplicate(true)
	missing_id[0].erase("id")
	corrupt.append(["missing id", missing_id])
	for price in [0, -1, 1.5, "100", true, null]:
		var bad_price: Array = candidates.duplicate(true)
		bad_price[0]["price"] = price
		corrupt.append(["price " + str(price), bad_price])
	var bad_id: Array = candidates.duplicate(true)
	bad_id[0]["id"] = 17
	corrupt.append(["numeric id", bad_id])
	var bad_entry: Array = candidates.duplicate(true)
	bad_entry[0] = "button_eye"
	corrupt.append(["non-dictionary offer", bad_entry])
	for entry in corrupt:
		var denied_rng := _seeded_rng(9081)
		var denied_state := denied_rng.state
		_check(RunShopPurchases.sample_patch_stall_offers(denied_rng, entry[1],
				unowned, rare) == {"ok": false} and denied_rng.state == denied_state,
			"corrupt offer data rejects without a draw: " + str(entry[0]))

	# AC4: same seed and eligible set replay; returned offers stay detached.
	var first_rng := _seeded_rng(31337)
	var first := RunShopPurchases.sample_patch_stall_offers(first_rng, candidates, unowned, rare)
	var replay_rng2 := _seeded_rng(31337)
	var second := RunShopPurchases.sample_patch_stall_offers(replay_rng2, candidates, unowned, rare)
	_check(first == second and first_rng.state == replay_rng2.state,
		"same seed and eligible set replay identical weighted offers")
	first["offers"][0]["id"] = "forged"
	first["offers"][0]["price"] = -1
	first["offers"].clear()
	var third := RunShopPurchases.sample_patch_stall_offers(_seeded_rng(31337),
		candidates, unowned, rare)
	_check(third == second, "mutating a returned sample cannot corrupt later stock")

	# Feed the result to the existing purchase constructor for patch_stall.
	var stall_fixture := {
		"party_ids": PATCH_STALL_PARTY.duplicate(),
		"deck": PATCH_STALL_DECK.duplicate(),
		"trinkets": ["button_eye"],
		"gold": 150,
		"cards": [],
		"offers_trinkets": []
	}
	# Build three patch offers from the sampled result.
	var sampled_offers: Array = result.get("offers")
	stall_fixture["offers_trinkets"] = []
	for offer in sampled_offers:
		stall_fixture["offers_trinkets"].append({
			"id": offer.get("id"), "price": offer.get("price")
		})

	var stall := RunShopPurchases.new(
		stall_fixture["party_ids"], stall_fixture["deck"],
		stall_fixture["trinkets"], stall_fixture["gold"],
		stall_fixture["cards"], stall_fixture["offers_trinkets"], "patch_stall"
	)
	_check(stall.is_valid(), "patch stall constructed from sampled offers is valid")
	_check(stall.get_stock()["cards"].is_empty(), "patch stall has zero cards")
	_check(stall.get_stock()["trinkets"].size() == 3,
		"patch stall has exactly three trinket offers")

	# Exact-one-purchase receipt and gold/stock checks.
	var purchase_target: String = str(sampled_offers[0].get("id"))
	var purchase_result := stall.buy("trinket", purchase_target)
	_check(purchase_result.get("ok") == true,
		"patch stall buys the first sampled patch")
	_check(purchase_result.has("receipt"), "purchase returns receipt")
	_check(purchase_result.get("receipt").get("kind") == "trinket",
		"receipt kind is trinket")
	_check(purchase_result.get("receipt").get("id") == purchase_target,
		"receipt matches purchased patch id")
	_check(purchase_result.get("receipt").get("price") == 100,
		"receipt price is authored 100 gold")
	_check(stall.get_state()["gold"] == 50,
		"gold debited exactly 100 from 150")
	_check(stall.get_state()["trinkets"].has(purchase_target),
		"purchased patch added to trinkets")
	_check(stall.get_state()["trinkets"].count(purchase_target) == 1,
		"exactly one copy of purchased patch in inventory")
	_check(stall.patch_stall_choice_used(), "choice latched after purchase")

	# A second purchase must be rejected.
	var second_purchase := stall.buy("trinket", str(sampled_offers[1].get("id")))
	_check(not second_purchase.get("ok"), "second patch purchase rejected")
	_check(not second_purchase.has("receipt"), "rejected second purchase has no receipt")

	# Rejected attempts must not advance the RNG.
	seed(99001)
	var expected_draw2 := randi()
	seed(99001)
	var bad_candidates: Array = [{"id": "unknown_patch", "price": 100}]
	var bad_result := RunShopPurchases.sample_patch_stall_offers(
		RandomNumberGenerator.new(), bad_candidates, owned)
	# The bad result must fail; verify no RNG was moved by comparing draws.
	_check(randi() == expected_draw2, "failed preflight consumes no global RNG")

	# Rejection for unknown/duplicate/malformed offers.
	var malformed_candidates: Array = [
		{"id": "button_eye", "price": 100},
		{"id": "button_eye", "price": 100},  # duplicate
	]
	var malformed_result := RunShopPurchases.sample_patch_stall_offers(
		RandomNumberGenerator.new(), malformed_candidates, owned)
	_check(not malformed_result.get("ok"), "duplicate candidate IDs rejected")

	# Invalid owned IDs must fail.
	var invalid_owned_result := RunShopPurchases.sample_patch_stall_offers(
		RandomNumberGenerator.new(), candidates, ["not_a_string", 7, true])
	_check(not invalid_owned_result.get("ok"), "invalid owned IDs rejected")

	# Invalid RNG must fail (not RandomNumberGenerator).
	var invalid_rng_result := RunShopPurchases.sample_patch_stall_offers(
		"not_an_rng", candidates, owned)
	_check(not invalid_rng_result.get("ok"), "invalid RNG rejected")

	# Unavailable three-offer stock (fewer than 3 eligible unowned powers).
	var too_few_candidates := [
		{"id": "stitched_badge", "price": 100},
		{"id": "spare_spool", "price": 100},
	]
	var too_few_result := RunShopPurchases.sample_patch_stall_offers(
		RandomNumberGenerator.new(), too_few_candidates, [])
	_check(not too_few_result.get("ok"),
		"fewer than three eligible power candidates rejected")

	# Prior Shop behavior must remain intact.
	var normal_shop := RunShopPurchases.new(
		PATCH_STALL_PARTY.duplicate(), PATCH_STALL_DECK.duplicate(), ["button_eye"], 150,
		[
			{"id": "warden_brace", "owner": "warden", "price": 25},
			{"id": "tinker_pop_shot", "owner": "tinker", "price": 30},
			{"id": "seamstress_mend", "owner": "seamstress", "price": 15},
			{"id": "tinker_scrap_bomb", "owner": "tinker", "price": 20},
			{"id": "warden_shield_bash", "owner": "warden", "price": 10}
		],
		[{"id": "t_spool", "price": 40}, {"id": "t_pocket", "price": 20}]
	)
	_check(normal_shop.is_valid(), "normal Shop with 5 cards and 2 patches stays valid")

	# Owned-patch behaviors still pass.
	var owned_stall := _patch_stall(_patch_stall_fixture(150, ["button_eye", "spare_spool"]))
	_check(owned_stall.is_valid(), "owned-listing stall admits")
	_check(owned_stall.get_stock()["trinkets"][1]["sold"],
		"owned listing starts sold")

	_test_patch_stall_scarce_owned_rares()

	# Restore the original seed to verify the helper never touched global RNG.
	seed(88001)
	_check(randi() == expected_draw, "sampling tests consume no global RNG")


## Scarce stock: one buyable ordinary power remains and both owned P8 rares are
## explicitly supplied, so they fill truthful SOLD rows at their catalog price.
func _test_patch_stall_scarce_owned_rares() -> void:
	var authored: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/shop/initial_offers.json"))
	_check(typeof(authored) == TYPE_DICTIONARY and authored.has("trinkets"),
		"scarce fixture reads the actual initial offers")
	var rare := _rare_records()
	var rare_price := {}
	for record in rare:
		rare_price[record.id] = int(record.shop_price_gold)
	for id in RARE_PATCH_IDS:
		_check(rare_price.get(id) == 100, "actual rare catalog prices " + id + " at 100")
	var power_slots := _power_slots()
	var candidates := _offer_ids(authored.get("trinkets", []),
		["button_eye", "relay_bobbin", "hearth_lining"])
	var candidate_ids: Array = candidates.map(func(offer): return offer.get("id"))
	for id in ["button_eye", "relay_bobbin", "hearth_lining"]:
		_check(candidate_ids.has(id) and power_slots.has(id),
			"actual authored candidate is a real power: " + id)
	_check(candidates.size() == 3, "scarce fixture filters exactly the three authored candidates")
	var owned: Array = RARE_PATCH_IDS.duplicate()
	var seed_value := 60417

	var rng := _seeded_rng(seed_value)
	var initial_state := rng.state
	var sampled := RunShopPurchases.sample_patch_stall_offers(rng, candidates, owned)
	_check(sampled.get("ok") == true and sampled.get("offers", []).size() == 3,
		"owned rares explicitly supplied still complete three offers")
	var sampled_ids := _sampled_ids(sampled)
	var unique := {}
	for id in sampled_ids:
		unique[id] = true
	_check(unique.size() == 3 and sampled_ids.has("button_eye")
		and sampled_ids.has("relay_bobbin") and sampled_ids.has("hearth_lining"),
		"stock holds three unique IDs: the buyable one and both owned rares")
	for offer in sampled.get("offers", []):
		_check(offer.get("price") == 100, "every scarce offer is priced 100: " + str(offer.get("id")))

	# One real unowned draw only, identical for reversed candidate order.
	var oracle := _seeded_rng(seed_value)
	oracle.randi_range(0, ORDINARY_TICKETS - 1)
	_check(rng.state == oracle.state and rng.state != initial_state,
		"exactly one ticket is drawn, for the single unowned power")
	var reversed_candidates: Array = candidates.duplicate(true)
	reversed_candidates.reverse()
	var reversed_rng := _seeded_rng(seed_value)
	var reversed := RunShopPurchases.sample_patch_stall_offers(
		reversed_rng, reversed_candidates, owned)
	_check(reversed == sampled and reversed_rng.state == rng.state,
		"same seed and reversed candidates give identical stock and run RNG state")

	# The authored catalog price, not a supplied price, prices an owned rare.
	var repriced: Array = candidates.duplicate(true)
	for offer in repriced:
		if offer.get("id") == "relay_bobbin":
			offer["price"] = 77
	var repriced_result := RunShopPurchases.sample_patch_stall_offers(
		_seeded_rng(seed_value), repriced, owned)
	_check(repriced_result.get("ok") == true and repriced_result.get("offers") == sampled.get("offers"),
		"an owned rare keeps its verified catalog price")

	# Admit through the real purchase ledger.
	var offers: Array = sampled.get("offers", [])
	var stall := RunShopPurchases.new(PATCH_STALL_PARTY.duplicate(),
		PATCH_STALL_DECK.duplicate(), owned.duplicate(), 100, [], offers, "patch_stall")
	_check(stall.is_valid(), "scarce owned-rare stock admits as a patch_stall visit")
	var stock := stall.get_stock()
	var sold_ids: Array = []
	var unsold_ids: Array = []
	for row in stock.trinkets:
		_check(row.price == 100, "ledger row price is the 100 catalog price: " + str(row.id))
		if row.sold:
			sold_ids.append(row.id)
		else:
			unsold_ids.append(row.id)
	sold_ids.sort()
	_check(stock.cards.is_empty() and stock.trinkets.size() == 3
		and sold_ids == ["hearth_lining", "relay_bobbin"] and unsold_ids == ["button_eye"],
		"both owned rares are SOLD and button_eye stays buyable")

	# Neither SOLD rare can be bought: nothing changes anywhere.
	var before_state := stall.get_state()
	var before_stock := stall.get_stock()
	for id in RARE_PATCH_IDS:
		var refused := stall.buy("trinket", id)
		_assert_result(refused, false, before_state, before_stock, "SOLD rare refused: " + id)
		_assert_model(stall, before_state, before_stock, "SOLD rare refusal leaves the stall: " + id)
		_check(not stall.patch_stall_choice_used(), "refused SOLD rare never latches: " + id)

	# The one real purchase debits exactly 100 once and latches the visit.
	var expected_state := before_state.duplicate(true)
	expected_state.gold = 0
	expected_state.trinkets.append("button_eye")
	var expected_stock := before_stock.duplicate(true)
	for row in expected_stock.trinkets:
		if row.id == "button_eye":
			row.sold = true
	_assert_result(stall.buy("trinket", "button_eye"), true, expected_state, expected_stock,
		"button_eye purchase", {"kind": "trinket", "id": "button_eye", "price": 100})
	_check(stall.patch_stall_choice_used(), "the paid choice latches the visit")
	for id in ["button_eye", "relay_bobbin", "hearth_lining"]:
		_assert_result(stall.buy("trinket", id), false, expected_state, expected_stock,
			"replay refused: " + id)
	_assert_model(stall, expected_state, expected_stock, "replay leaves the settled stall")

	# Fail-closed neighbours: an unsupplied owned rare is never fabricated.
	var one_rare_supplied := _offer_ids(authored.get("trinkets", []),
		["button_eye", "relay_bobbin"])
	var short_rng := _seeded_rng(seed_value)
	var short_state := short_rng.state
	_check(RunShopPurchases.sample_patch_stall_offers(short_rng, one_rare_supplied, owned)
		== {"ok": false} and short_rng.state == short_state,
		"an unsupplied owned rare is not fabricated into the stock before any draw")
	# All three owned leaves no buyable power: refused before any draw.
	var all_owned_rng := _seeded_rng(seed_value)
	var all_owned_state := all_owned_rng.state
	_check(RunShopPurchases.sample_patch_stall_offers(all_owned_rng, candidates,
			owned + ["button_eye"]) == {"ok": false} and all_owned_rng.state == all_owned_state,
		"all supplied powers owned refuses without a draw")
	# A supplied owned rare plus two unowned ordinary powers is still honest.
	var mixed := _offer_ids(authored.get("trinkets", []),
		["button_eye", "frayfinder_mitt", "relay_bobbin"])
	var mixed_result := RunShopPurchases.sample_patch_stall_offers(
		_seeded_rng(seed_value), mixed, owned)
	_check(mixed_result.get("ok") == true and not _sampled_ids(mixed_result).has("hearth_lining")
		and _sampled_ids(mixed_result).has("relay_bobbin"),
		"only explicitly supplied owned rares fill SOLD rows")
