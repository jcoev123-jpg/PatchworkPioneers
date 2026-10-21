extends SceneTree

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
