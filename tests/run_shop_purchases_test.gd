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
