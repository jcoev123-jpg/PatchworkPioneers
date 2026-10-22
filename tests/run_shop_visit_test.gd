extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_contract_and_source_fixture()
	_test_skip_close_and_node_guards()
	_test_failed_attempt_recovery_and_exact_funds()
	_test_three_distinct_purchases()
	_test_first_duplicate_and_alias_isolation()
	_test_invalid_initial_state()
	_test_duplicate_owned_admission()
	_test_rng_and_equal_replay()
	_test_purchase_reconciliation()
	_test_removal_before_purchase_reconciliation()
	_test_paid_trinket_transactions()
	_test_paid_receipt_rejections()
	_test_duplicate_trinket_recovery()
	_test_owned_stock_reconciliation()
	_test_fight_reward_sequences()
	_test_fight_reward_rejections()
	_test_typed_battle_bridge()
	_test_pool_card_fight_reward_sequences()
	_test_pool_card_typed_battle_bridge()
	_test_pool_card_rejections()
	if failures.is_empty():
		print("run_shop_visit_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_shop_visit_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _test_duplicate_owned_admission() -> void:
	var deck: Array[String] = ["warden_strike", "seamstress_prick", "warden_strike"]
	var distinct: Array[String] = ["old_badge", "other_badge"]
	var control := RunShopVisit.new(deck, 300, 1, distinct)
	_check(control.open_visit("control-shop"), "distinct ownership admits real visit with repeated deck cards")
	var shop := _paid_shop(control.get_state())
	_check(shop.is_valid(), "duplicate admission control has a valid purchase service")
	var paid := shop.buy("card", "warden_brace")
	_check(paid.ok and paid.has("receipt") and control.reconcile_purchase(paid),
		"duplicate admission control produces and reconciles a real paid receipt")
	seed(76004)
	var expected_draw := randi()
	seed(76004)
	for inventory in [["old_badge", "old_badge"], ["old_badge", "other_badge", "old_badge"]]:
		var owned: Array[String] = []
		owned.assign(inventory)
		var before_owned := owned.duplicate()
		var visit := RunShopVisit.new(deck, 300, 1, owned)
		var expected := {"valid": false, "status": "inactive", "shop_node_id": "",
			"removal_available": false, "price": 100, "deck": deck.duplicate(),
			"trinkets": owned.duplicate(), "gold": 300, "prior_removals": 1,
			"visited_ids": [], "claimed_fight_ids": []}
		_check(visit.get_state() == expected, "duplicate inventory publishes exact invalid visit snapshot")
		_check(not visit.open_visit("duplicate-shop"), "duplicate inventory cannot open a Shop")
		var paid_before := paid.duplicate(true)
		_check(not visit.reconcile_purchase(paid), "duplicate inventory rejects actual paid receipt")
		_check(not visit.remove_card("warden_strike").ok and not visit.close_visit(),
			"duplicate inventory cannot spend gold or close an unopened visit")
		_check(visit.get_state() == expected and paid == paid_before and owned == before_owned,
			"duplicate admission failures preserve complete ledger and caller inputs")
	_check(randi() == expected_draw, "duplicate visit admission and failures consume no global RNG")


func _test_purchase_reconciliation() -> void:
	var cards: Array[String] = ["warden_strike", "seamstress_prick"]
	var visit := RunShopVisit.new(cards, 200, 1)
	var result := {"ok": true, "state": {"deck": ["warden_strike", "seamstress_prick", "tinker_pop_shot"], "gold": 150}}
	var before := visit.get_state()
	_check(not visit.reconcile_purchase(result), "inactive reconciliation rejects")
	_check_state_unchanged(visit, before, "inactive reconciliation")
	_check(visit.open_visit("shop-buy"), "reconciliation opens real visit")
	before = visit.get_state()
	for invalid in [
		{"ok": false, "state": result.state}, {},
		{"ok": true, "state": {"deck": cards, "gold": 150}},
		{"ok": true, "state": {"deck": ["wrong", "seamstress_prick", "tinker_pop_shot"], "gold": 150}},
		{"ok": true, "state": {"deck": result.state.deck, "gold": -1}},
		{"ok": true, "state": {"deck": result.state.deck, "gold": 201}},
		{"ok": true, "state": {"deck": result.state.deck, "gold": 150.5}},
		{"ok": true, "state": {"deck": ["warden_strike", "seamstress_prick", 1], "gold": 150}}
	]:
		_check(not visit.reconcile_purchase(invalid), "malformed or unsuccessful purchase rejected")
		_check_state_unchanged(visit, before, "rejected reconciliation")
	_check(visit.reconcile_purchase(result), "successful purchase reconciles")
	var bought := before.duplicate(true)
	bought.deck = result.state.deck.duplicate()
	bought.gold = 150
	_check(visit.get_state() == bought and visit.quote() == 100, "reconcile changes only deck/gold, preserving node/count/quote")
	_check(visit.get_state().deck == ["warden_strike", "seamstress_prick", "tinker_pop_shot"] and visit.get_state().gold == 150, "purchase-before-removal keeps exact deck order and gold")
	_check(not visit.reconcile_purchase(result), "repeated purchase snapshot rejected")
	_check_state_unchanged(visit, bought, "repeated reconciliation")
	result.state.deck.clear()
	_check_state_unchanged(visit, bought, "purchase result detached")
	var removal := visit.remove_card("warden_strike")
	_check(removal.ok and removal.price == 100 and removal.gold == 50 and removal.prior_removals == 2, "single removal after buying costs 75 + 25 * 1")
	_check(removal.deck == ["seamstress_prick", "tinker_pop_shot"], "removal drops only the first surviving Strike copy")
	var used := visit.get_state()
	_check(used.deck == ["seamstress_prick", "tinker_pop_shot"] and used.gold == 50, "used visit holds reconciled deck and 50 gold")
	_check(used.status == "used" and not used.removal_available, "removal consumes the visit option")
	_check(used.prior_removals == 2 and used.price == 125, "removal increments the count once and quotes 125 next")
	_check(used.shop_node_id == "shop-buy" and used.visited_ids == ["shop-buy"], "removal preserves original node and visited IDs")

	var post := {"ok": true, "state": {"deck": ["seamstress_prick", "tinker_pop_shot", "warden_strike"], "gold": 0}}
	for invalid in [
		{"ok": false, "state": post.state}, {},
		{"ok": true},
		{"ok": true, "state": {"deck": post.state.deck, "gold": -1}},
		{"ok": true, "state": {"deck": post.state.deck, "gold": 51}},
		{"ok": true, "state": {"deck": post.state.deck, "gold": 0.0}},
		{"ok": true, "state": {"deck": ["tinker_pop_shot", "seamstress_prick", "warden_strike"], "gold": 0}},
		{"ok": true, "state": {"deck": ["seamstress_prick", "tinker_pop_shot"], "gold": 0}},
		{"ok": true, "state": {"deck": ["seamstress_prick", "tinker_pop_shot", "warden_strike", "warden_brace"], "gold": 0}},
		{"ok": true, "state": {"deck": ["seamstress_prick", "tinker_pop_shot", "  "], "gold": 0}},
		{"ok": true, "state": {"deck": ["seamstress_prick", "tinker_pop_shot", 7], "gold": 0}},
		{"ok": true, "state": {"deck": ["warden_strike", "seamstress_prick", "tinker_pop_shot"], "gold": 50}}
	]:
		_check(not visit.reconcile_purchase(invalid), "post-removal malformed, stale or mismatched purchase rejected")
		_check_state_unchanged(visit, used, "post-removal rejected reconciliation")
	_check(visit.reconcile_purchase(post), "post-removal purchase reconciles once")
	var expected_after := used.duplicate(true)
	expected_after.deck = post.state.deck.duplicate()
	expected_after.gold = 0
	_check(visit.get_state() == expected_after, "post-removal reconcile changes only deck/gold")
	var after := visit.get_state()
	_check(after.deck == ["seamstress_prick", "tinker_pop_shot", "warden_strike"] and after.gold == 0, "post-removal purchase appends in order and spends 50")
	_check(after.status == "used" and not after.removal_available, "post-removal purchase leaves the used visit closed to another removal")
	_check(after.prior_removals == 2 and after.price == 125, "post-removal purchase keeps the count and 125 quote")
	_check(after.shop_node_id == "shop-buy" and after.visited_ids == ["shop-buy"], "post-removal purchase preserves node and visited IDs")
	_check(not visit.reconcile_purchase(post), "replayed post-removal purchase rejected")
	_check_state_unchanged(visit, after, "replayed post-removal reconciliation")
	post.state.deck.clear()
	_check_state_unchanged(visit, after, "post-removal purchase result detached")
	_check(not visit.remove_card("seamstress_prick").ok, "used visit rejects a second removal after buying")
	_check_state_unchanged(visit, after, "second removal after post-removal purchase")
	_check(not visit.open_visit("shop-buy"), "post-removal purchase cannot reopen the same Shop")
	_check_state_unchanged(visit, after, "duplicate opening after post-removal purchase")
	_check(visit.close_visit(), "post-removal reconciled visit closes")
	var closed := visit.get_state()
	_check(closed.status == "closed" and not closed.removal_available, "closed visit disables removal")
	_check(not visit.reconcile_purchase({"ok": true, "state": {"deck": ["seamstress_prick", "tinker_pop_shot", "warden_strike", "warden_brace"], "gold": 0}}), "closed visit cannot reconcile")
	_check_state_unchanged(visit, closed, "closed reconciliation")


func _test_removal_before_purchase_reconciliation() -> void:
	var cards: Array[String] = ["warden_strike", "seamstress_prick"]
	var visit := RunShopVisit.new(cards, 200, 1)
	_check(visit.open_visit("shop-remove-first"), "removal-first visit opens")
	var removal := visit.remove_card("warden_strike")
	_check(removal.ok and removal.price == 100 and removal.gold == 100 and removal.prior_removals == 2, "removal-first charges 100 of 200 gold")
	var used := visit.get_state()
	_check(used.deck == ["seamstress_prick"] and used.gold == 100, "removal-first deck and gold exact")
	_check(used.status == "used" and not used.removal_available, "removal-first consumes the removal option")
	_check(used.prior_removals == 2 and used.price == 125, "removal-first count and next quote exact")
	_check(used.shop_node_id == "shop-remove-first" and used.visited_ids == ["shop-remove-first"], "removal-first records the node once")
	var purchase := {"ok": true, "state": {"deck": ["seamstress_prick", "tinker_pop_shot"], "gold": 40}}
	for invalid in [
		{"ok": false, "state": purchase.state},
		{"ok": true, "state": {"deck": ["seamstress_prick", "tinker_pop_shot", "warden_brace"], "gold": 0}},
		{"ok": true, "state": {"deck": ["tinker_pop_shot", "seamstress_prick"], "gold": 40}},
		{"ok": true, "state": {"deck": ["seamstress_prick", "tinker_pop_shot"], "gold": 101}},
		{"ok": true, "state": {"deck": ["seamstress_prick", "tinker_pop_shot"], "gold": -5}},
		{"ok": true, "state": {"deck": ["seamstress_prick", " "], "gold": 40}},
		{"ok": true, "state": {"deck": ["seamstress_prick"], "gold": 40}}
	]:
		_check(not visit.reconcile_purchase(invalid), "removal-first malformed, wrong-prefix or bad-gold purchase rejected")
		_check_state_unchanged(visit, used, "removal-first rejected reconciliation")
	_check(visit.reconcile_purchase(purchase), "removal-first purchase reconciles once")
	var expected := used.duplicate(true)
	expected.deck = purchase.state.deck.duplicate()
	expected.gold = 40
	_check(visit.get_state() == expected, "removal-first reconcile changes only deck/gold")
	var after := visit.get_state()
	_check(after.deck == ["seamstress_prick", "tinker_pop_shot"] and after.gold == 40, "removal-first purchase appends exactly one card and deducts its price")
	_check(after.status == "used" and not after.removal_available, "removal-first purchase does not restore the removal option")
	_check(after.prior_removals == 2 and after.price == 125, "removal-first purchase keeps the count and 125 quote")
	_check(after.shop_node_id == "shop-remove-first" and after.visited_ids == ["shop-remove-first"], "removal-first purchase preserves node and visited IDs")
	_check(not visit.reconcile_purchase(purchase), "replayed removal-first purchase rejected")
	_check_state_unchanged(visit, after, "replayed removal-first reconciliation")
	purchase.state.deck.clear()
	_check_state_unchanged(visit, after, "removal-first purchase result detached")
	_check(not visit.remove_card("seamstress_prick").ok, "removal-first visit rejects a second removal after buying")
	_check_state_unchanged(visit, after, "second removal after removal-first purchase")
	_check(visit.close_visit(), "removal-first reconciled visit closes")
	var closed := visit.get_state()
	_check(not visit.reconcile_purchase({"ok": true, "state": {"deck": ["seamstress_prick", "tinker_pop_shot", "warden_brace"], "gold": 0}}), "closed removal-first visit cannot reconcile")
	_check_state_unchanged(visit, closed, "closed removal-first reconciliation")
	_check(not visit.open_visit("shop-remove-first"), "closed removal-first visit cannot reopen the same node")
	_check_state_unchanged(visit, closed, "reopening after removal-first close")



## These are supplied Shop prices/IDs, not a trinket catalog or passive rules.
## The service is rebuilt after removal so its purchase state starts with the
## new ledger's deck/gold while the visit itself stays open and unchanged.
func _paid_shop(state: Dictionary) -> RunShopPurchases:
	return RunShopPurchases.new(
		["warden", "seamstress", "tinker"], state.deck, state.trinkets, state.gold,
		[
			{"id": "warden_brace", "owner": "warden", "price": 25},
			{"id": "tinker_pop_shot", "owner": "tinker", "price": 30},
			{"id": "seamstress_mend", "owner": "seamstress", "price": 15},
			{"id": "tinker_scrap_bomb", "owner": "tinker", "price": 20},
			{"id": "warden_shield_bash", "owner": "warden", "price": 10}
		],
		[
			{"id": "t_spool", "price": 40},
			{"id": "t_pocket", "price": 20}
		]
	)


func _paid_transaction(visit: RunShopVisit, shop: RunShopPurchases,
		kind: String, id: String, price: int, label: String) -> void:
	var before := visit.get_state()
	var stock_before := shop.get_stock()
	var service_before := shop.get_state()
	_check(shop.is_valid() and stock_before.cards.size() == 5 and stock_before.trinkets.size() == 2,
		label + " real five-card/two-trinket service exists")
	_check(service_before.deck == before.deck and service_before.trinkets == before.trinkets
		and service_before.gold == before.gold, label + " service seeded from live ledger")
	var result := shop.buy(kind, id)
	_check(result.ok and result.receipt == {"kind": kind, "id": id, "price": price},
		label + " paid receipt is exact and real")
	var stock_after := stock_before.duplicate(true)
	var key := "cards" if kind == "card" else "trinkets"
	var sold_count := 0
	for item in stock_after[key]:
		if item.id == id:
			item.sold = true
			sold_count += 1
	_check(sold_count == 1 and result.stock == stock_after and shop.get_stock() == stock_after,
		label + " exactly one offered item sold")
	var expected := before.duplicate(true)
	expected.gold -= price
	if kind == "card":
		expected.deck.append(id)
	else:
		expected.trinkets.append(id)
	_check(result.state.deck == expected.deck and result.state.trinkets == expected.trinkets
		and result.state.gold == expected.gold and expected.gold >= 0,
		label + " service state deducted exact price and appended once")
	_check(visit.reconcile_purchase(result), label + " real receipt reconciles")
	_check(visit.get_state() == expected, label + " exact complete ledger snapshot")
	var committed := visit.get_state()
	_check(not visit.reconcile_purchase(result), label + " replayed receipt rejects")
	_check_state_unchanged(visit, committed, label + " replay leaves ledger identical")
	result.receipt.id = "tampered"
	result.state.trinkets.clear()
	result.stock[key].clear()
	_check_state_unchanged(visit, committed, label + " mutating returned copies never aliases ledger")
	_check(shop.get_stock() == stock_after and shop.get_state().gold == expected.gold,
		label + " mutating result never aliases purchase service")


func _paid_sequence(reverse_order: bool) -> Dictionary:
	var deck: Array[String] = ["warden_strike", "seamstress_prick", "tinker_pop_shot"]
	var owned: Array[String] = ["old_badge"]
	var ledger := RunShopVisit.new(deck, 360, 0, owned)
	owned.append("forged")
	_check(ledger.get_state().trinkets == ["old_badge"], "initial owned array is detached")
	var initial := ledger.get_state()
	_check(initial.deck == deck and initial.gold == 360 and initial.prior_removals == 0
		and initial.trinkets == ["old_badge"] and initial.price == 75
		and initial.status == "inactive", "exact pre-open ledger snapshot")
	_check(ledger.open_visit("shop-A"), "first confirmed Shop opens")
	var open := ledger.get_state()
	_check(open.visited_ids == ["shop-A"] and open.shop_node_id == "shop-A"
		and open.status == "available" and open.price == 75, "first node/quote exact")
	var first := _paid_shop(open)
	_check(first.is_valid(), "first Shop prices supplied to real purchase service")
	if reverse_order:
		_paid_transaction(ledger, first, "card", "warden_brace", 25, "card then trinket first")
		_paid_transaction(ledger, first, "trinket", "t_spool", 40, "card then trinket second")
	else:
		_paid_transaction(ledger, first, "trinket", "t_spool", 40, "trinket then card first")
		_paid_transaction(ledger, first, "card", "warden_brace", 25, "trinket then card second")
	var paid := ledger.get_state()
	_check(paid.deck == deck + ["warden_brace"] and paid.trinkets == ["old_badge", "t_spool"]
		and paid.gold == 295 and paid.prior_removals == 0 and paid.price == 75
		and paid.status == "available" and paid.visited_ids == ["shop-A"],
		"two distinct paid kinds conserve order and exact 65 gold without spending removal option")
	var removed := ledger.remove_card("warden_strike")
	_check(removed.ok and removed.price == 75 and removed.gold == 220
		and removed.prior_removals == 1, "removal after two purchases charges original 75 once")
	var used := ledger.get_state()
	_check(used.deck == ["seamstress_prick", "tinker_pop_shot", "warden_brace"]
		and used.trinkets == paid.trinkets and used.gold == 220 and used.price == 100
		and used.status == "used" and not used.removal_available and used.prior_removals == 1,
		"removal preserves purchased inventory and increases next quote by 25")
	var post := _paid_shop(used)
	_check(post.is_valid(), "post-removal purchase service re-seeded from actual spent state")
	if reverse_order:
		_paid_transaction(ledger, post, "trinket", "t_pocket", 20, "post-removal trinket")
		_paid_transaction(ledger, post, "card", "tinker_pop_shot", 30, "post-removal card")
	else:
		_paid_transaction(ledger, post, "card", "tinker_pop_shot", 30, "post-removal card")
		_paid_transaction(ledger, post, "trinket", "t_pocket", 20, "post-removal trinket")
	var finished := ledger.get_state()
	_check(finished.gold == 170 and finished.trinkets == ["old_badge", "t_spool", "t_pocket"]
		and finished.deck == ["seamstress_prick", "tinker_pop_shot", "warden_brace", "tinker_pop_shot"]
		and finished.prior_removals == 1 and finished.status == "used" and finished.price == 100,
		"before/after removal buys conserve every trinket, card, gold and quote")
	_check(not ledger.remove_card("warden_brace").ok, "cannot remove twice despite later buying")
	_check_state_unchanged(ledger, finished, "second removal rejected")
	_check(ledger.close_visit(), "first Shop closes after all transactions")
	var closed := ledger.get_state()
	_check(not ledger.reconcile_purchase(post.buy("card", "seamstress_mend")),
		"closed Shop rejects even a freshly successful service receipt")
	_check_state_unchanged(ledger, closed, "closed receipt cannot change ledger")
	_check(not ledger.open_visit("shop-A"), "same Shop node never reopens")
	_check_state_unchanged(ledger, closed, "same-node attempt is inert")
	_check(ledger.open_visit("shop-B"), "different confirmed Shop node opens")
	var another := ledger.get_state()
	_check(another.trinkets == finished.trinkets and another.deck == finished.deck
		and another.gold == 170 and another.price == 100 and another.prior_removals == 1
		and another.visited_ids == ["shop-A", "shop-B"] and another.shop_node_id == "shop-B",
		"persistent trinket inventory and gold survive into distinct Shop")
	var later := _paid_shop(another)
	_paid_transaction(ledger, later, "card", "seamstress_mend", 15, "second Shop bought card")
	var final := ledger.get_state()
	_check(final.trinkets == finished.trinkets and final.gold == 155
		and final.visited_ids == ["shop-A", "shop-B"], "later Shop leaves trinkets intact")
	_check(ledger.close_visit(), "second Shop closes")
	return {"state": ledger.get_state(), "first_stock": first.get_stock(),
		"post_stock": post.get_stock(), "later_stock": later.get_stock()}


func _test_paid_trinket_transactions() -> void:
	seed(81462)
	var expected_rng := randi()
	seed(81462)
	var one := _paid_sequence(false)
	_check(randi() == expected_rng, "paid Shop sequence never uses global RNG")
	seed(81462)
	var two := _paid_sequence(false)
	_check(randi() == expected_rng, "replayed paid Shop sequence never uses global RNG")
	_check(one == two, "two independent seeded Shops replay exact state and sold-stock flags")
	seed(81462)
	var reverse := _paid_sequence(true)
	_check(randi() == expected_rng, "reverse receipt ordering never uses global RNG")
	_check(reverse.state == one.state and reverse.first_stock == one.first_stock
		and reverse.post_stock == one.post_stock,
		"reversed purchase order leads to same complete ledger and sold stock")


func _reject_paid(visit: RunShopVisit, shop: RunShopPurchases,
		result: Dictionary, label: String) -> void:
	var before := visit.get_state()
	var state_before := shop.get_state()
	var stock_before := shop.get_stock()
	var input_before := result.duplicate(true)
	seed(551224)
	var expected_rng := randi()
	seed(551224)
	_check(not visit.reconcile_purchase(result), label + " rejects forged purchase")
	_check(visit.get_state() == before and shop.get_state() == state_before
		and shop.get_stock() == stock_before, label + " complete ledger/state/stock unchanged")
	_check(result == input_before, label + " receipt input not mutated")
	_check(randi() == expected_rng, label + " rejected transaction uses no global RNG")


func _test_paid_receipt_rejections() -> void:
	var deck: Array[String] = ["warden_strike", "seamstress_prick"]
	var owned: Array[String] = ["old_badge"]
	var ledger := RunShopVisit.new(deck, 150, 0, owned)
	var shop := _paid_shop(ledger.get_state())
	_check(shop.is_valid(), "rejection fixture has valid supplied stock")
	var genuine := shop.buy("trinket", "t_spool")
	_check(genuine.ok and genuine.receipt == {"kind": "trinket", "id": "t_spool", "price": 40}
		and genuine.state.gold == 110 and genuine.state.trinkets == ["old_badge", "t_spool"],
		"rejection fixture uses an actual paid trinket receipt")
	_reject_paid(ledger, shop, genuine, "inactive visit")
	_check(ledger.open_visit("forgery-shop"), "forgery visit opens")
	for invalid in [
		{"ok": false, "state": genuine.state, "receipt": genuine.receipt},
		{"ok": true},
		{"ok": true, "state": null},
		{"ok": true, "state": genuine.state},
		{"ok": true, "state": genuine.state, "receipt": {}}
	]:
		_reject_paid(ledger, shop, invalid, "failed, stale or receipt-less trinket")
	for field in ["kind", "id", "price"]:
		var missing := genuine.duplicate(true)
		missing.receipt.erase(field)
		_reject_paid(ledger, shop, missing, "missing receipt " + field)
	for wrong in [
		{"kind": "card", "id": "t_spool", "price": 40},
		{"kind": "trinket", "id": "t_pocket", "price": 40},
		{"kind": "trinket", "id": "t_spool", "price": 39},
		{"kind": "trinket", "id": "t_spool", "price": 151},
		{"kind": "trinket", "id": "t_spool", "price": -1},
		{"kind": "trinket", "id": "t_spool", "price": 40.0},
		{"kind": "trinket", "id": "t_spool", "price": "40"},
		{"kind": "trinket", "id": 14, "price": 40},
		{"kind": "other", "id": "t_spool", "price": 40}
	]:
		var wrong_receipt := genuine.duplicate(true)
		wrong_receipt.receipt = wrong
		_reject_paid(ledger, shop, wrong_receipt, "wrong receipt fields")
	var extra := genuine.duplicate(true)
	extra.receipt["extra"] = true
	_reject_paid(ledger, shop, extra, "extra receipt field")
	for bad_inventory in [
		["old_badge"],
		["t_spool", "old_badge"],
		[],
		["old_badge", "t_spool", "t_pocket"],
		["foreign", "t_spool"],
		["old_badge", "t_pocket"]
	]:
		var changed := genuine.duplicate(true)
		changed.state.trinkets = bad_inventory
		_reject_paid(ledger, shop, changed, "invalid trinket append or prefix")
	for bad_deck in [["warden_strike"], ["seamstress_prick", "warden_strike"],
		["warden_strike", "seamstress_prick", "warden_brace"]]:
		var changed := genuine.duplicate(true)
		changed.state.deck = bad_deck
		_reject_paid(ledger, shop, changed, "changed deck with trinket receipt")
	for bad_gold in [-1, 151, 150, 109, 111, 110.0, "110"]:
		var changed := genuine.duplicate(true)
		changed.state.gold = bad_gold
		_reject_paid(ledger, shop, changed, "mismatched, increased or invalid gold")
	var no_trinkets := genuine.duplicate(true)
	no_trinkets.state.erase("trinkets")
	_reject_paid(ledger, shop, no_trinkets, "missing trinket state for paid receipt")
	var nil_receipt := genuine.duplicate(true)
	nil_receipt.receipt = null
	_reject_paid(ledger, shop, nil_receipt, "null receipt")
	var card_shop := _paid_shop(ledger.get_state())
	var actual_card := card_shop.buy("card", "warden_brace")
	_check(actual_card.ok and actual_card.receipt == {"kind": "card", "id": "warden_brace", "price": 25},
		"card receipt comes from real Shop stock")
	var altered_card := actual_card.duplicate(true)
	altered_card.receipt.id = "seamstress_mend"
	_reject_paid(ledger, card_shop, altered_card, "wrong card receipt ID")
	altered_card = actual_card.duplicate(true)
	altered_card.state.trinkets.append("t_spool")
	_reject_paid(ledger, card_shop, altered_card, "card cannot modify inventory")
	altered_card = actual_card.duplicate(true)
	altered_card.state.deck.append("another_card")
	_reject_paid(ledger, card_shop, altered_card, "card cannot append twice")
	_check(ledger.reconcile_purchase(genuine), "actual paid receipt accepted after all forged failures")
	var accepted := ledger.get_state()
	_check(accepted.trinkets == ["old_badge", "t_spool"] and accepted.gold == 110
		and accepted.deck == deck and accepted.status == "available", "exact acceptance state")
	_reject_paid(ledger, shop, genuine, "replayed purchased state")
	var stale := genuine.duplicate(true)
	stale.receipt.id = "t_pocket"
	_reject_paid(ledger, shop, stale, "stale receipt with new ID")
	_check(ledger.close_visit(), "forgery fixture closes")
	_reject_paid(ledger, shop, genuine, "closed Shop")
	_check(ledger.get_state().trinkets == ["old_badge", "t_spool"], "closed Shop inventory remains owned")


func _duplicate_trinket_sequence(remove_first: bool) -> Array:
	var deck: Array[String] = ["warden_strike", "seamstress_prick", "warden_strike"]
	var owned: Array[String] = ["old_badge"]
	var ledger := RunShopVisit.new(deck, 360, 0, owned)
	var timeline: Array = [ledger.get_state()]
	for i in range(2):
		var node := "duplicate-shop-%d" % i
		_check(ledger.open_visit(node), "duplicate recovery opens distinct Shop")
		if remove_first:
			var removal := ledger.remove_card("warden_strike")
			_check(removal.ok and removal.price == 75 + 25 * i,
				"duplicate recovery uses real removal at cumulative price")
		var before := ledger.get_state()
		var duplicate_id := "old_badge" if i == 0 else "t_spool"
		_check(before.trinkets.has(duplicate_id) and before.gold >= 40
			and before.status == ("used" if remove_first else "available"),
			"duplicate fixture owns ID with sufficient funds in active visit")
		var shop := _paid_shop(before)
		_check(shop.is_valid(), "duplicate recovery has live-style purchase service")
		var appended: Array = before.trinkets.duplicate()
		appended.append(duplicate_id)
		var duplicate := {"ok": true,
			"receipt": {"kind": "trinket", "id": duplicate_id, "price": 40},
			"state": {"deck": before.deck.duplicate(), "trinkets": appended,
				"gold": before.gold - 40}}
		_reject_paid(ledger, shop, duplicate, "pre-owned or prior-Shop duplicate")
		timeline.append(ledger.get_state())
		var fresh_id := "t_spool" if i == 0 else "t_pocket"
		var price := 40 if i == 0 else 20
		_check(not before.trinkets.has(fresh_id), "recovery trinket is unowned")
		seed(71831)
		var next_draw := randi()
		seed(71831)
		_paid_transaction(ledger, shop, "trinket", fresh_id, price,
			"fresh trinket after rejected duplicate")
		_check(randi() == next_draw, "legitimate recovery consumes no global RNG")
		var paid_state := shop.get_state()
		var paid_stock := shop.get_stock()
		var committed := ledger.get_state()
		_check(not shop.buy("trinket", fresh_id).ok, "recovery stock sells only once")
		_check(shop.get_state() == paid_state and shop.get_stock() == paid_stock,
			"second buy preserves exact service state and sold stock")
		_check_state_unchanged(ledger, committed, "service retry leaves visit intact")
		timeline.append({"state": ledger.get_state(), "stock": shop.get_stock()})
		_check(ledger.close_visit(), "duplicate recovery visit remains closable")
		timeline.append(ledger.get_state())
	_check(ledger.open_visit("duplicate-shop-2"), "subsequent separate Shop opens")
	var later := ledger.get_state()
	var later_shop := _paid_shop(later)
	_check(later_shop.is_valid() and later_shop.get_state().trinkets == ["old_badge", "t_spool", "t_pocket"],
		"later purchase ledger admits one copy of each previously purchased ID in order")
	var later_stock := later_shop.get_stock()
	for id in ["t_spool", "t_pocket"]:
		var denied := later_shop.buy("trinket", id)
		_check(not denied.ok and not denied.has("receipt") and not ledger.reconcile_purchase(denied),
			"later Shop cannot resell a previously purchased trinket")
	_check(later_shop.get_stock() == later_stock and later_shop.get_state().gold == later.gold
		and ledger.get_state() == later, "later duplicate attempts preserve stock, gold and removal accounting")
	_check(later.trinkets == ["old_badge", "t_spool", "t_pocket"]
		and later.deck == (["seamstress_prick"] if remove_first else deck)
		and later.gold == (125 if remove_first else 300)
		and later.prior_removals == (2 if remove_first else 0)
		and later.status == "available" and later.removal_available
		and later.shop_node_id == "duplicate-shop-2"
		and later.visited_ids == ["duplicate-shop-0", "duplicate-shop-1", "duplicate-shop-2"],
		"later Shop retains all ownership, exact charges, removal count and history")
	_check(ledger.close_visit(), "subsequent Shop closes")
	timeline.append(ledger.get_state())
	return timeline


func _test_owned_stock_reconciliation() -> void:
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
	var pool: Array = authored.get("trinkets", [])
	_check(pool.size() >= 2 and authored.get("cards", []).size() >= 5,
		"owned visit uses real authored priced pools")
	if pool.size() < 2 or authored.get("cards", []).size() < 5:
		return
	seed(76002)
	var expected_draw := randi()
	seed(76002)
	for count in [1, 2]:
		for remove_first in [false, true]:
			var deck: Array[String] = ["warden_strike", "seamstress_prick", "warden_strike"]
			var owned: Array[String] = []
			for index in range(count):
				owned.append(pool[index].id)
			var rng := RandomNumberGenerator.new()
			rng.seed = 76002
			var offers := RunShopStockOffers.generate(rng, ["warden", "seamstress", "tinker"], authored.cards, pool, owned)
			_check(offers.ok, "owned visit stock generates")
			if not offers.ok:
				continue
			var rng_after := rng.state
			var shop := RunShopPurchases.new(["warden", "seamstress", "tinker"], deck, owned, 500, offers.cards, offers.trinkets)
			var visit := RunShopVisit.new(deck, 500, 0, owned)
			_check(shop.is_valid() and visit.open_visit("owned-shop"), "owned stocked visit admits both real services")
			var expected := visit.get_state()
			for listing in shop.get_stock().trinkets:
				_check(listing.sold == owned.has(listing.id), "owned visit listing availability matches inventory")
				if listing.sold:
					var before := shop.get_state()
					var stock := shop.get_stock()
					var denied := shop.buy("trinket", listing.id)
					_check(not denied.ok and not denied.has("receipt") and not visit.reconcile_purchase(denied), "owned stock cannot produce a paid receipt")
					_check(shop.get_state() == before and shop.get_stock() == stock and visit.get_state() == expected, "owned rejection preserves both full ledgers and stock")
			for step in (["remove", "buy"] if remove_first else ["buy", "remove"]):
				if step == "remove":
					var before := visit.get_state()
					var removed := visit.remove_card("warden_strike")
					_check(removed.ok and removed.price == 75 and shop.rebase_removal(before, removed, "warden_strike"), "owned visit removal rebases purchases")
					expected.deck.remove_at(0)
					expected.gold -= 75
					expected.prior_removals = 1
					expected.price = 100
					expected.status = "used"
					expected.removal_available = false
				else:
					for listing in shop.get_stock().trinkets:
						if not listing.sold:
							var paid := shop.buy("trinket", listing.id)
							_check(paid.ok and visit.reconcile_purchase(paid), "available trinket reconciles alongside owned stock")
							expected.trinkets.append(listing.id)
							expected.gold -= listing.price
							_check(not shop.buy("trinket", listing.id).ok and not visit.reconcile_purchase(paid), "sold stock and receipt replay reject")
					var card: Dictionary = offers.cards[0]
					var paid := shop.buy("card", card.id)
					_check(paid.ok and visit.reconcile_purchase(paid), "card reconciles with owned stock")
					expected.deck.append(card.id)
					expected.gold -= card.price
				_check(visit.get_state() == expected, "owned visit exact deck gold inventory removal and history")
				_check(shop.get_state() == {"party_ids": ["warden", "seamstress", "tinker"], "deck": expected.deck, "gold": expected.gold, "trinkets": expected.trinkets}, "purchase ledger matches exact expected visit state")
			_check(rng.state == rng_after, "purchase and removal leave run RNG unchanged")
	_check(randi() == expected_draw, "owned stock visits leave global RNG untouched")


func _test_duplicate_trinket_recovery() -> void:
	for remove_first in [false, true]:
		var first := _duplicate_trinket_sequence(remove_first)
		var replay := _duplicate_trinket_sequence(remove_first)
		_check(first == replay, "duplicate rejection and recovery replay complete ledger/stock timeline")


func _starter_deck() -> Array[String]:
	var path := "res://data/cards/starter_deck.json"
	_check(FileAccess.file_exists(path), "the source starter deck exists")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var deck: Array[String] = []
	if typeof(raw) != TYPE_ARRAY:
		_check(false, "starter deck parses to an array")
		return deck
	for id in raw:
		_check(typeof(id) == TYPE_STRING, "starter deck card IDs are strings")
		if typeof(id) == TYPE_STRING:
			deck.append(id)
	return deck


func _check_state_unchanged(ledger: RunShopVisit, before: Dictionary, label: String) -> void:
	_check(ledger.get_state() == before, label + ": complete ledger state unchanged")


func _test_contract_and_source_fixture() -> void:
	var source := _starter_deck()
	_check(source.size() == 12, "source fixture has twelve cards")
	for id in ["warden_strike", "seamstress_prick", "tinker_pop_shot"]:
		_check(source.count(id) == 2, "source fixture has two " + id)
	for id in ["warden_brace", "warden_shield_bash", "seamstress_mend", "seamstress_stitch_up", "tinker_scrap_bomb", "tinker_tune_up"]:
		_check(source.count(id) == 1, "source fixture has one " + id)
	var ledger := RunShopVisit.new(source, 200, 0)
	for method in ["open_visit", "remove_card", "close_visit", "get_state", "quote", "apply_fight_reward", "reconcile_purchase"]:
		_check(ledger.has_method(method), "public visit contract exposes " + method)
	var initial := ledger.get_state()
	_check(initial["valid"] == true and initial["status"] == "inactive", "fresh ledger is valid and inactive")
	_check(initial["removal_available"] == false and initial["visited_ids"].is_empty(), "fresh ledger has no active option or visits")
	_check(initial["gold"] == 200 and initial["prior_removals"] == 0 and initial["price"] == 75, "initial gold/count/price exact")
	_check(initial["deck"] == source, "fresh ledger contains starter deck in original order")
	_check(initial["claimed_fight_ids"] == [], "fresh ledger has no Fight claims")
	_check(ledger.quote() == 75, "quote delegated for the first removal")
	_check(ledger.remove_card("warden_strike")["ok"] == false, "cannot buy before opening")
	_check_state_unchanged(ledger, initial, "buying before a visit")


func _test_skip_close_and_node_guards() -> void:
	var deck := _starter_deck()
	var ledger := RunShopVisit.new(deck, 175, 0)
	var before := ledger.get_state()
	_check(ledger.open_visit("") == false, "empty Shop node ID rejected")
	_check(ledger.open_visit("  ") == false, "blank Shop node ID rejected")
	_check(ledger.close_visit() == false, "cannot close inactive ledger")
	_check_state_unchanged(ledger, before, "invalid opening/closing")
	_check(ledger.open_visit("shop-A"), "confirmed first Shop opens")
	var available := ledger.get_state()
	_check(available["status"] == "available" and available["removal_available"], "open visit exposes exactly one removal option")
	_check(available["shop_node_id"] == "shop-A" and available["visited_ids"] == ["shop-A"], "first node ID is recorded")
	_check(ledger.open_visit("shop-B") == false, "overlapping visit rejected")
	_check(ledger.open_visit("shop-A") == false, "current node cannot reopen")
	_check_state_unchanged(ledger, available, "overlapping openings")
	_check(ledger.close_visit(), "untouched visit closes")
	var closed := ledger.get_state()
	_check(closed["status"] == "closed" and closed["removal_available"] == false, "closed state disables removal")
	_check(closed["deck"] == deck and closed["gold"] == 175 and closed["prior_removals"] == 0, "skipping changes no economy values")
	_check(ledger.remove_card("warden_strike")["ok"] == false, "cannot remove after close")
	_check(ledger.close_visit() == false, "cannot close twice")
	_check(ledger.open_visit("shop-A") == false, "visited node cannot reopen even after close")
	_check_state_unchanged(ledger, closed, "closed invalid actions")
	_check(ledger.open_visit("shop-B"), "distinct Shop node opens after skip")
	var second := ledger.get_state()
	_check(second["status"] == "available" and second["price"] == 75, "skipping did not increase the removal price")
	_check(second["visited_ids"] == ["shop-A", "shop-B"], "both Shop IDs are remembered")
	_check(ledger.close_visit(), "second skipped Shop closes")
	var after := ledger.get_state()
	_check(after["deck"] == deck and after["gold"] == 175 and after["prior_removals"] == 0, "two separate skipped Shops leave run unchanged")
	_check(_starter_deck() == deck, "source deck remains identical after two Shop visits")


func _test_failed_attempt_recovery_and_exact_funds() -> void:
	var deck: Array[String] = ["warden_strike", "seamstress_prick", "warden_strike"]
	var short_funds := RunShopVisit.new(deck, 74, 0)
	_check(short_funds.open_visit("cheap-shop"), "74-gold fixture opens")
	var before := short_funds.get_state()
	var refused := short_funds.remove_card("warden_strike")
	_check(refused["ok"] == false and refused["price"] == 75, "74 gold is insufficient for 75-gold removal")
	_check(refused["gold"] == 74 and refused["prior_removals"] == 0 and refused["deck"] == deck, "insufficient result preserves exact state")
	_check_state_unchanged(short_funds, before, "insufficient funds leaves option available")
	_check(short_funds.remove_card("missing")["ok"] == false, "absent ID fails with insufficient gold")
	_check_state_unchanged(short_funds, before, "absent card does not consume the visit")
	_check(short_funds.close_visit(), "failed-purchase visit can close without spending")

	var exact := RunShopVisit.new(deck, 75, 0)
	_check(exact.open_visit("exact-shop"), "exact-funds Shop opens")
	var fresh := exact.get_state()
	var empty := exact.remove_card("")
	_check(empty["ok"] == false, "empty card ID fails")
	_check_state_unchanged(exact, fresh, "empty card ID keeps option available")
	var absent := exact.remove_card("not_owned")
	_check(absent["ok"] == false, "absent card fails even with enough gold")
	_check_state_unchanged(exact, fresh, "absent card leaves option available")
	var paid := exact.remove_card("warden_strike")
	_check(paid["ok"] == true and paid["price"] == 75, "valid retry succeeds at exactly 75 gold")
	_check(paid["gold"] == 0 and paid["prior_removals"] == 1, "exact funds yield zero gold and one removal")
	_check(paid["deck"] == ["seamstress_prick", "warden_strike"], "only first Strike removed on retry")
	_check(exact.get_state()["status"] == "used" and not exact.get_state()["removal_available"], "successful removal consumes visit option")
	var used := exact.get_state()
	_check(exact.remove_card("warden_strike")["ok"] == false, "second purchase in same visit denied")
	_check_state_unchanged(exact, used, "second attempt after success")
	_check(exact.close_visit(), "used visit closes")
	var closed := exact.get_state()
	_check(exact.remove_card("seamstress_prick")["ok"] == false, "closed used visit denies purchase")
	_check_state_unchanged(exact, closed, "after-close removal")
	_check(deck == ["warden_strike", "seamstress_prick", "warden_strike"], "short caller deck unchanged")


func _test_three_distinct_purchases() -> void:
	var source := _starter_deck()
	var original := source.duplicate()
	var ledger := RunShopVisit.new(source, 300, 0)
	var expected: Array[String] = source.duplicate()
	var cards: Array[String] = ["warden_strike", "warden_strike", "seamstress_prick"]
	var prices: Array[int] = [75, 100, 125]
	var gold_remaining: Array[int] = [225, 125, 0]
	for i in range(3):
		_check(ledger.open_visit("shop-%d" % i), "Shop %d opens once" % i)
		_check(ledger.get_state()["price"] == prices[i], "Shop %d quote matches rising price" % i)
		var result := ledger.remove_card(cards[i])
		_check(result["ok"] == true, "Shop %d pays successfully" % i)
		_check(result["price"] == prices[i], "Shop %d charges exact price" % i)
		_check(result["gold"] == gold_remaining[i] and result["prior_removals"] == i + 1, "Shop %d exact gold/count" % i)
		expected.erase(cards[i])
		_check(result["deck"] == expected, "Shop %d removes only first match and preserves order" % i)
		var snapshot := ledger.get_state()
		_check(snapshot["deck"] == expected and snapshot["gold"] == gold_remaining[i] and snapshot["prior_removals"] == i + 1, "Shop %d ledger commits exact helper result" % i)
		_check(snapshot["status"] == "used" and not snapshot["removal_available"], "Shop %d marks option used" % i)
		if i == 0:
			_check(snapshot["deck"].count("warden_strike") == 1, "first purchase leaves second Strike intact")
		_check(ledger.close_visit(), "Shop %d closes" % i)
	_check(ledger.get_state()["visited_ids"] == ["shop-0", "shop-1", "shop-2"], "three unique node IDs persisted")
	_check(ledger.get_state()["price"] == 150, "next quote continues rising after three successes")
	_check(ledger.open_visit("shop-3"), "fourth Shop opens with empty purse")
	var fourth := ledger.get_state()
	_check(ledger.remove_card("seamstress_prick")["ok"] == false, "zero gold cannot cause a negative balance")
	_check_state_unchanged(ledger, fourth, "zero-gold attempted removal")
	_check(ledger.close_visit(), "fourth visit may be skipped")
	_check(source == original and _starter_deck() == original, "starter source and caller array never mutated")


func _test_first_duplicate_and_alias_isolation() -> void:
	var caller: Array[String] = ["a", "b", "a", "a"]
	var ledger := RunShopVisit.new(caller, 200, 0)
	caller.clear()
	_check(ledger.get_state()["deck"] == ["a", "b", "a", "a"], "constructor detaches caller input array")
	var initial := ledger.get_state()
	var state_deck: Array = initial["deck"]
	state_deck.clear()
	_check(ledger.get_state()["deck"] == ["a", "b", "a", "a"], "mutating fetched deck cannot alter ledger")
	_check(ledger.open_visit("alias-shop"), "alias fixture Shop opens")
	var seen := ledger.get_state()
	var ids: Array = seen["visited_ids"]
	ids.clear()
	_check(ledger.get_state()["visited_ids"] == ["alias-shop"], "mutating returned visited IDs cannot erase ledger history")
	var result := ledger.remove_card("a")
	_check(result["deck"] == ["b", "a", "a"], "first duplicate removed and two remain")
	var result_deck: Array = result["deck"]
	result_deck.append("injected")
	var after := ledger.get_state()
	_check(after["deck"] == ["b", "a", "a"], "mutating helper transaction result cannot modify ledger")
	var next_deck: Array = after["deck"]
	next_deck.append("tampered")
	_check(ledger.get_state()["deck"] == ["b", "a", "a"], "repeated state snapshots are independent")
	_check(ledger.close_visit(), "alias visit closes")
	_check(ledger.open_visit("next-shop"), "distinct Shop opens after alias mutation")
	_check(ledger.get_state()["visited_ids"] == ["alias-shop", "next-shop"], "visited history remains correct after alias mutation")


func _test_invalid_initial_state() -> void:
	var deck: Array[String] = ["warden_strike"]
	for pair in [[-1, 0], [75, -1], [-1, -1]]:
		var ledger := RunShopVisit.new(deck, pair[0], pair[1])
		var before := ledger.get_state()
		_check(before["valid"] == false and before["status"] == "inactive", "invalid initial economy is marked invalid")
		_check(ledger.open_visit("bad-shop") == false, "invalid initial state cannot open")
		_check(ledger.remove_card("warden_strike")["ok"] == false, "invalid initial state cannot spend")
		_check(ledger.close_visit() == false, "invalid initial state cannot close")
		_check_state_unchanged(ledger, before, "invalid initial state remains untouched")


func _scenario(seed_value: int) -> Dictionary:
	var source := _starter_deck()
	var ledger := RunShopVisit.new(source, 300, 0)
	seed(seed_value)
	var expected_next_draw := randi()
	seed(seed_value)
	var responses: Array[bool] = []
	responses.append(ledger.remove_card("warden_strike")["ok"])
	responses.append(ledger.open_visit("shop-A"))
	responses.append(ledger.remove_card("not_owned")["ok"])
	responses.append(ledger.remove_card("warden_strike")["ok"])
	var bought_a_deck: Array[String] = ledger.get_state()["deck"]
	bought_a_deck.append("tinker_tune_up")
	var bought_a := {"ok": true, "state": {"deck": bought_a_deck, "gold": 185}}
	responses.append(ledger.reconcile_purchase(bought_a))
	responses.append(ledger.reconcile_purchase(bought_a))
	responses.append(ledger.remove_card("warden_strike")["ok"])
	responses.append(ledger.close_visit())
	responses.append(ledger.open_visit("shop-B"))
	responses.append(ledger.close_visit())
	responses.append(ledger.open_visit("shop-C"))
	responses.append(ledger.remove_card("warden_strike")["ok"])
	var bought_c_deck: Array[String] = ledger.get_state()["deck"]
	bought_c_deck.append("warden_brace")
	var bought_c := {"ok": true, "state": {"deck": bought_c_deck, "gold": 55}}
	responses.append(ledger.reconcile_purchase(bought_c))
	responses.append(ledger.reconcile_purchase(bought_c))
	responses.append(ledger.close_visit())
	var observed_next_draw := randi()
	return {
		"state": ledger.get_state(),
		"responses": responses,
		"expected_rng": expected_next_draw,
		"observed_rng": observed_next_draw,
		"caller_unchanged": source == _starter_deck(),
	}


func _test_rng_and_equal_replay() -> void:
	var first := _scenario(431257)
	var second := _scenario(431257)
	_check(first["expected_rng"] == first["observed_rng"], "success, failure, skip and visit guards consume no global RNG draws")
	_check(second["expected_rng"] == second["observed_rng"], "replayed run also consumes zero global RNG draws")
	_check(first == second, "two equal seeded runs replay complete results identically")
	_check(first["caller_unchanged"] == true, "replay leaves source fixture intact")
	_check(first["state"]["gold"] == 55 and first["state"]["prior_removals"] == 2, "replay applied exactly two valid removals and two purchases")
	_check(first["state"]["status"] == "closed" and first["state"]["deck"].size() == 12, "replay ends closed with one appended card per purchased offer")
	_check(first["responses"] == [false, true, false, true, true, false, false, true, true, true, true, true, true, false, true], "replay exercises purchases before and after removal plus their rejections")


## The typed bridge must consume actual witnessed map-bound reward settlements.
## No mocked reward dictionaries appear on the positive path.
func _typed_battle_fixture() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	var map := RunMap.new()
	var route: Array[String] = []
	for map_seed in range(1, 3001):
		rng.seed = map_seed
		if not map.generate(rng):
			continue
		for fight in map.get_floors()[0]:
			if fight.type != "Fight":
				continue
			for elite_id in fight.outgoing:
				if map.get_node(elite_id).type != "Elite":
					continue
				for shop_id in map.get_node(elite_id).outgoing:
					if map.get_node(shop_id).type != "Shop":
						continue
					for second_id in map.get_node(shop_id).outgoing:
						if map.get_node(second_id).type == "Shop":
							route.assign([fight.id, elite_id, shop_id, second_id])
							break
					if not route.is_empty():
						break
				if not route.is_empty():
					break
			if not route.is_empty():
				break
		if not route.is_empty():
			break
	_check(route.size() == 4, "real map has connected Fight/Elite/Shop/Shop path")
	if route.size() != 4:
		return {}
	var heroes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))
	for hero in heroes:
		hero.max_hp = int(hero.max_hp)
	var party := CombatParty.new(heroes)
	var carry := RunPartyCarryover.new(party.get_heroes())
	var deck := _starter_deck()
	var owned: Array[String] = ["button_charm"]
	var candidates := StarterCards.new().get_all_card_ids()
	var drops := ["thread_token", "button_charm", "spool_pendant"]
	_check(party.is_valid() and carry.is_valid() and not deck.is_empty()
		and candidates.size() >= 3, "typed bridge uses real authored resources")
	var owner := RunMultiFightRewards.new(map, rng, carry, deck, 350, owned, candidates, drops)
	var ledger := RunShopVisit.new(deck, 350, 0, owned)
	return {"map": map, "rng": rng, "route": route, "party": party, "carry": carry,
		"deck": deck, "owned": owned, "candidates": candidates, "drops": drops,
		"owner": owner, "ledger": ledger}


func _typed_oracle(rng: RandomNumberGenerator, candidates: Array, elite: bool) -> Dictionary:
	var award := rng.randi_range(25, 35) if elite else rng.randi_range(10, 20)
	var pool: Array = candidates.duplicate()
	pool.sort()
	var offers: Array = []
	var catalog := StarterCards.new()
	for i in range(3):
		var id: String = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		offers.append({"id": id, "owner": catalog.get_definition(id).owner})
	var drop := ""
	if elite:
		var unowned := ["spool_pendant", "thread_token"]
		drop = unowned[rng.randi_range(0, unowned.size() - 1)]
	return {"ok": true, "gold_award": award, "offers": offers, "trinket_drop_id": drop}


func _reject_typed(f: Dictionary, id: Variant, settled: Variant, label: String) -> void:
	var ledger: RunShopVisit = f.ledger
	var before := ledger.get_state()
	var owner_state: Dictionary = f.owner.read_state()
	var carry_state: Dictionary = f.carry.read_state()
	var route: Array = f.map.get_route()
	var rng_state: int = f.rng.state
	var input_before: Variant = settled.duplicate(true) if settled is Dictionary else settled
	var deck_before: Array = f.deck.duplicate(true)
	var owned_before: Array = f.owned.duplicate(true)
	var candidates_before: Array = f.candidates.duplicate(true)
	var drops_before: Array = f.drops.duplicate(true)
	_check(not ledger.apply_battle_reward(id, settled), label + " rejects typed admission")
	_check(ledger.get_state() == before and f.owner.read_state() == owner_state
		and f.carry.read_state() == carry_state and f.map.get_route() == route
		and f.rng.state == rng_state, label + " complete Shop/source/map/RNG unchanged")
	_check(settled == input_before and f.deck == deck_before and f.owned == owned_before
		and f.candidates == candidates_before and f.drops == drops_before,
		label + " original receipt and source inventory detached")


func _typed_battle_sequence(fight_pick: bool) -> Dictionary:
	var f := _typed_battle_fixture()
	if f.is_empty():
		return {}
	var ledger: RunShopVisit = f.ledger
	_check(ledger.has_method("apply_battle_reward"), "typed battle admission public API exists")
	var oracle := RandomNumberGenerator.new()
	oracle.seed = f.rng.seed
	oracle.state = f.rng.state
	var receipts: Array = []
	var timeline: Array = [ledger.get_state()]
	for index in range(2):
		var id: String = f.route[index]
		_check(f.map.get_legal_choices().has(id) and f.map.choose_node(id),
			"actual reachable reward node is chosen")
		if index == 1:
			f.party = f.carry.create_next_fight_party()
			_check(f.party != null and f.party.is_valid(), "Elite party hydrated from real Fight carryover")
			if f.party == null:
				return {}
		var party: CombatParty = f.party
		var enemies := CombatEnemies.new([{"id": "ragling", "max_hp": 8}])
		var battle := CombatBattleResult.new(party, enemies)
		_check(battle.get_outcome() == CombatBattleResult.ACTIVE, "observed battle starts ACTIVE")
		_check(enemies.apply_damage(1, 8) and battle.get_outcome() == CombatBattleResult.ACTIVE,
			"unobserved terminal damage is not a victory receipt")
		_check(battle.evaluate() == CombatBattleResult.VICTORY, "witness actual combat VICTORY")
		var pre_reward: Dictionary = f.owner.read_state()
		var expected_offer := _typed_oracle(oracle, f.candidates, index == 1)
		var prepared: Dictionary = f.owner.prepare(id, battle, party)
		_check(prepared == expected_offer and f.rng.state == oracle.state,
			"Fight/Elite gold, offers, drop, and run RNG exactly match seeded oracle")
		var choice: String = ""
		if (index == 0 and fight_pick) or (index == 1 and not fight_pick):
			choice = expected_offer.offers[0].id
		var settled: Dictionary = f.owner.choose(id, choice)
		var typed := {"node_id": id, "node_kind": "Fight" if index == 0 else "Elite",
			"trinket_drop_id": expected_offer.trinket_drop_id}
		_check(settled.ok and settled.receipt == typed
			and settled.skipped == choice.is_empty() and settled.selected_id == choice,
			"real settled receipt binds chosen card and canonical seeded node/drop")
		var expected_run: Dictionary = pre_reward.duplicate(true)
		expected_run.gold += expected_offer.gold_award
		if not choice.is_empty():
			expected_run.deck.append(choice)
		if index == 1:
			expected_run.trinkets.append(expected_offer.trinket_drop_id)
		var carried: Array = party.get_heroes()
		for hero in carried:
			hero.block = 0
		expected_run.party = f.carry.read_state()
		_check(settled.state == expected_run and f.owner.read_state() == expected_run,
			"complete authoritative pre/post reward snapshot matches exact delta")
		var original: Dictionary = settled.duplicate(true)
		for bad_id in [null, 5, "", " wrong", id + "_foreign"]:
			_reject_typed(f, bad_id, settled, "missing/foreign/noncanonical node")
		for bad in [null, {}, {"ok": false}, {"ok": true}, []]:
			_reject_typed(f, id, bad, "missing or unsuccessful settlement")
		for field in ["ok", "skipped", "selected_id", "state", "receipt"]:
			var changed := settled.duplicate(true)
			changed.erase(field)
			_reject_typed(f, id, changed, "missing settlement " + field)
		for kind in ["Boss", "Shop", "Rest", "Event", "", "elite"]:
			var changed := settled.duplicate(true)
			changed.receipt.node_kind = kind
			_reject_typed(f, id, changed, "invalid typed node kind " + kind)
		for field in ["node_id", "node_kind", "trinket_drop_id"]:
			var changed := settled.duplicate(true)
			changed.receipt.erase(field)
			_reject_typed(f, id, changed, "missing receipt " + field)
		var wrong := settled.duplicate(true)
		wrong.receipt.node_id = f.route[1 - index]
		_reject_typed(f, id, wrong, "wrong receipt node")
		wrong = settled.duplicate(true)
		wrong.receipt.node_kind = "Elite" if index == 0 else "Fight"
		_reject_typed(f, id, wrong, "wrong actual node kind")
		wrong = settled.duplicate(true)
		wrong.skipped = not settled.skipped
		_reject_typed(f, id, wrong, "tampered Skip pairing")
		wrong = settled.duplicate(true)
		wrong.selected_id = "invented_card"
		_reject_typed(f, id, wrong, "unoffered/unknown appended selection")
		wrong = settled.duplicate(true)
		wrong.state.deck.append("invented_card")
		_reject_typed(f, id, wrong, "unexpected deck append")
		wrong = settled.duplicate(true)
		wrong.state.deck[0] = "invented_card"
		_reject_typed(f, id, wrong, "mutated existing deck prefix")
		wrong = settled.duplicate(true)
		wrong.state.gold = pre_reward.gold + (24 if index == 1 else 9)
		_reject_typed(f, id, wrong, "under-range gold award")
		wrong = settled.duplicate(true)
		wrong.state.gold = pre_reward.gold + (36 if index == 1 else 21)
		_reject_typed(f, id, wrong, "over-range gold award")
		wrong = settled.duplicate(true)
		wrong.state.gold = -1
		_reject_typed(f, id, wrong, "negative gold")
		wrong = settled.duplicate(true)
		wrong.state.gold = 9223372036854775807
		_reject_typed(f, id, wrong, "MAX_INT cannot spoof excess gold")
		wrong = settled.duplicate(true)
		wrong.state.party.completed_fights.clear()
		_reject_typed(f, id, wrong, "uncommitted carryover history")
		wrong = settled.duplicate(true)
		wrong.receipt.trinket_drop_id = "button_charm"
		_reject_typed(f, id, wrong, "wrong or already-owned trinket drop")
		wrong = settled.duplicate(true)
		wrong.state.trinkets.clear()
		_reject_typed(f, id, wrong, "missing or changed trinket inventory")
		wrong = settled.duplicate(true)
		wrong.state.trinkets.append("extra")
		_reject_typed(f, id, wrong, "extra trinket appended")
		_check(ledger.apply_battle_reward(id, settled), "valid real typed receipt succeeds after all negative retries")
		var expected_ledger: Dictionary = timeline.back().duplicate(true)
		expected_ledger.deck = expected_run.deck.duplicate(true)
		expected_ledger.gold = expected_run.gold
		expected_ledger.trinkets = expected_run.trinkets.duplicate(true)
		expected_ledger.claimed_fight_ids.append(id)
		_check(ledger.get_state() == expected_ledger, "exact atomic deck/gold/trinket/claim snapshot")
		_check(settled == original, "successful typed bridge never changes caller receipt")
		_reject_typed(f, id, settled, "typed duplicate claim")
		var legacy := {"ok": true, "skipped": true, "selected_id": "",
			"deck": ledger.get_state().deck, "gold": ledger.get_state().gold + 10}
		var unchanged := ledger.get_state()
		_check(not ledger.apply_fight_reward(id, legacy) and ledger.get_state() == unchanged,
			"legacy API cannot replay a typed claim")
		var copied := ledger.get_state()
		copied.deck.clear()
		copied.trinkets.clear()
		copied.claimed_fight_ids.clear()
		_check(ledger.get_state() == expected_ledger, "detached Shop snapshots protect accepted reward")
		receipts.append(settled.duplicate(true))
		timeline.append(ledger.get_state())
	# A legacy claim likewise blocks typed replay of the same real Fight receipt.
	var old_ledger := RunShopVisit.new(f.deck, 350, 0, f.owned)
	var fight_claim: Dictionary = receipts[0]
	var flat := {"ok": true, "skipped": fight_claim.skipped,
		"selected_id": fight_claim.selected_id,
		"deck": fight_claim.state.deck, "gold": fight_claim.state.gold}
	_check(old_ledger.apply_fight_reward(f.route[0], flat), "legacy normal Fight claim stays operational")
	var old_before := old_ledger.get_state()
	_check(not old_ledger.apply_battle_reward(f.route[0], fight_claim)
		and old_ledger.get_state() == old_before, "typed API cannot replay a legacy claim")
	var before_shops := ledger.get_state()
	_check(f.map.get_legal_choices().has(f.route[2]) and f.map.choose_node(f.route[2]),
		"real first Shop follows Elite")
	_check(ledger.open_visit(f.route[2]), "first canonical Shop visit opens")
	var shop := _paid_shop(ledger.get_state())
	_paid_transaction(ledger, shop, "card", "warden_brace", 25, "reward-funded first Shop card")
	_paid_transaction(ledger, shop, "trinket", "t_spool", 40, "reward-funded first Shop trinket")
	var before_remove := ledger.get_state()
	var removed := ledger.remove_card("warden_strike")
	_check(removed.ok and removed.price == 75 and removed.prior_removals == 1,
		"first Shop removes at base 75 after real purchases")
	var after_remove := before_remove.duplicate(true)
	after_remove.deck.erase("warden_strike")
	after_remove.gold -= 75
	after_remove.prior_removals = 1
	after_remove.price = 100
	after_remove.removal_available = false
	after_remove.status = "used"
	_check(ledger.get_state() == after_remove, "first paid removal exact snapshot")
	_check(ledger.close_visit(), "first real Shop closes")
	_check(f.map.get_legal_choices().has(f.route[3]) and f.map.choose_node(f.route[3]),
		"connected later Shop choice is genuinely legal")
	_check(ledger.open_visit(f.route[3]), "second distinct connected Shop opens")
	var before_second := ledger.get_state()
	var second_remove := ledger.remove_card("seamstress_prick")
	_check(second_remove.ok and second_remove.price == 100 and second_remove.prior_removals == 2,
		"second Shop removal rises to 75 + 25")
	var after_second := before_second.duplicate(true)
	after_second.deck.erase("seamstress_prick")
	after_second.gold -= 100
	after_second.price = 125
	after_second.prior_removals = 2
	after_second.removal_available = false
	after_second.status = "used"
	_check(ledger.get_state() == after_second, "second removal exact preserved inventory and claims")
	var next_shop := _paid_shop(ledger.get_state())
	_paid_transaction(ledger, next_shop, "card", "seamstress_mend", 15, "later Shop purchase after removal")
	_paid_transaction(ledger, next_shop, "trinket", "t_pocket", 20, "later Shop trinket after removal")
	_check(ledger.close_visit(), "second Shop closes with rewards and paid purchases")
	var final_state := ledger.get_state()
	_check(final_state.status == "closed" and final_state.prior_removals == 2
		and final_state.visited_ids == [f.route[2], f.route[3]]
		and final_state.claimed_fight_ids == [f.route[0], f.route[1]]
		and final_state.trinkets == before_shops.trinkets + ["t_spool", "t_pocket"]
		and final_state.deck.has("seamstress_mend") and final_state.gold >= 0,
		"second Shop conserves both Fight/Elite claims, drop, and complete purchase inventory")
	_check(f.owner.read_state() == receipts[1].state
		and f.deck == _starter_deck() and f.owned == ["button_charm"]
		and f.rng.state == oracle.state, "Shop bridge never mutates actual reward source or run RNG")
	timeline.append(final_state)
	return {"timeline": timeline, "receipts": receipts, "rng": f.rng.state,
		"route": f.route, "final": final_state}


func _test_typed_battle_bridge() -> void:
	seed(82179)
	var expected_global := randi()
	seed(82179)
	var picked_fight := _typed_battle_sequence(true)
	_check(not picked_fight.is_empty(), "pick Fight / Skip Elite real bridge is exercised")
	_check(randi() == expected_global, "typed Fight pick / Elite Skip draws no global RNG")
	seed(82179)
	var replay := _typed_battle_sequence(true)
	_check(randi() == expected_global and picked_fight == replay,
		"identical seeded real Fight/Elite/Shop full trace replays exactly")
	seed(82179)
	var picked_elite := _typed_battle_sequence(false)
	_check(not picked_elite.is_empty() and randi() == expected_global,
		"Fight Skip / Elite pick exercises other choices without global RNG")


func _fight_reward(deck: Array, gold: int, selected: String = "") -> Dictionary:
	var cards: Array[String] = []
	cards.assign(deck)
	if selected != "":
		cards.append(selected)
	return {"ok": true, "skipped": selected == "", "selected_id": selected, "deck": cards, "gold": gold}


func _fight_sequence() -> Array:
	var deck: Array[String] = ["warden_strike", "seamstress_prick", "warden_strike"]
	var ledger := RunShopVisit.new(deck, 200, 0)
	var expected := {"valid": true, "status": "inactive", "shop_node_id": "",
		"removal_available": false, "price": 75, "deck": deck.duplicate(), "trinkets": [], "gold": 200,
		"prior_removals": 0, "visited_ids": [], "claimed_fight_ids": []}
	_check(ledger.get_state() == expected, "Fight sequence exact initial snapshot")
	var timeline: Array = [ledger.get_state()]
	_check(ledger.apply_fight_reward("fight-0", _fight_reward(deck, 210)), "inactive Fight skip accepted")
	expected.gold = 210
	expected.claimed_fight_ids.append("fight-0")
	_check(ledger.get_state() == expected, "inactive skip changes only gold and claims")
	timeline.append(ledger.get_state())
	_check(ledger.open_visit("shop-1"), "first Shop opens")
	_check(ledger.remove_card("warden_strike").ok, "first Shop removal succeeds")
	_check(ledger.close_visit(), "first paid Shop closes")
	expected.status = "closed"
	expected.shop_node_id = "shop-1"
	expected.visited_ids.append("shop-1")
	expected.deck = ["seamstress_prick", "warden_strike"]
	expected.gold = 135
	expected.prior_removals = 1
	expected.price = 100
	_check(ledger.get_state() == expected, "first removal exact snapshot")
	timeline.append(ledger.get_state())
	var reward := _fight_reward(expected.deck, 155, "tinker_pop_shot")
	var caller_before := reward.duplicate(true)
	_check(ledger.apply_fight_reward("fight-1", reward), "closed Shop accepts chosen Fight card")
	_check(reward == caller_before, "Fight input remains unchanged")
	expected.deck.append("tinker_pop_shot")
	expected.gold = 155
	expected.claimed_fight_ids.append("fight-1")
	_check(ledger.get_state() == expected, "chosen Fight changes only deck gold and claims")
	reward.deck.clear()
	var detached := ledger.get_state()
	var independent := ledger.get_state()
	detached.claimed_fight_ids.clear()
	detached.deck.clear()
	_check(independent == expected and ledger.get_state() == expected, "Fight history and deck snapshots are defensive")
	timeline.append(ledger.get_state())
	_check(ledger.apply_fight_reward("fight-2", _fight_reward(expected.deck, 170)), "distinct closed-Shop skip accepted")
	expected.gold = 170
	expected.claimed_fight_ids.append("fight-2")
	_check(ledger.get_state() == expected, "closed skip preserves deck and both histories")
	timeline.append(ledger.get_state())
	_check(ledger.open_visit("shop-2"), "distinct later Shop opens")
	var purchase := {"ok": true, "state": {"deck": ["seamstress_prick", "warden_strike", "tinker_pop_shot", "warden_brace"], "gold": 130}}
	_check(ledger.reconcile_purchase(purchase), "later purchase uses rewarded deck and gold")
	expected.status = "available"
	expected.removal_available = true
	expected.shop_node_id = "shop-2"
	expected.visited_ids.append("shop-2")
	expected.deck = purchase.state.deck.duplicate()
	expected.gold = 130
	_check(ledger.get_state() == expected, "later purchase exact snapshot preserves Fight claims")
	timeline.append(ledger.get_state())
	var removal := ledger.remove_card("tinker_pop_shot")
	_check(removal.ok and removal.price == 100, "later removal retains cumulative 75 + 25 quote")
	expected.status = "used"
	expected.removal_available = false
	expected.deck = ["seamstress_prick", "warden_strike", "warden_brace"]
	expected.gold = 30
	expected.prior_removals = 2
	expected.price = 125
	_check(ledger.get_state() == expected, "later removal exact snapshot preserves all histories")
	_check(not ledger.remove_card("warden_strike").ok, "Fight rewards never restore used removal")
	_check_state_unchanged(ledger, expected, "used later Shop")
	_check(ledger.close_visit(), "later Shop closes")
	expected.status = "closed"
	_check(ledger.get_state() == expected, "final closed exact snapshot")
	timeline.append(ledger.get_state())
	return timeline


func _test_fight_reward_sequences() -> void:
	seed(61001)
	var next_draw := randi()
	seed(61001)
	var first := _fight_sequence()
	_check(randi() == next_draw, "successful Fight/Shop sequence consumes no global RNG")
	seed(61001)
	var second := _fight_sequence()
	_check(randi() == next_draw, "replayed Fight/Shop sequence consumes no global RNG")
	_check(first == second, "complete Fight/Shop timeline replays identically")


func _reject_fight(ledger: RunShopVisit, id: Variant, reward: Variant, label: String) -> void:
	var before := ledger.get_state()
	var input_before: Variant = reward.duplicate(true) if reward is Dictionary else reward
	seed(61002)
	var next_draw := randi()
	seed(61002)
	_check(not ledger.apply_fight_reward(id, reward), label + " rejects")
	_check(randi() == next_draw, label + " consumes no global RNG")
	_check_state_unchanged(ledger, before, label)
	_check(reward == input_before, label + " preserves caller input")


func _test_fight_reward_rejections() -> void:
	var deck: Array[String] = ["warden_strike", "seamstress_prick"]
	var ledger := RunShopVisit.new(deck, 100, 0)
	var valid := _fight_reward(deck, 110, "warden_brace")
	for id in [null, 7, true, &"fight", "", "  ", " fight", "fight "]:
		_reject_fight(ledger, id, valid, "noncanonical Fight ID")
	for reward in [null, true, 1, [], {}, {"ok": true}]:
		_reject_fight(ledger, "fight", reward, "malformed reward")
	for field in ["ok", "skipped", "selected_id", "deck", "gold"]:
		var missing := valid.duplicate(true)
		missing.erase(field)
		_reject_fight(ledger, "fight", missing, "missing " + field)
	var bad_values := {"ok": [false, 1, "true"], "skipped": [0, "false", null],
		"selected_id": [1, &"warden_brace", null, "", "invented", " warden_brace"],
		"deck": [null, "cards", PackedStringArray(deck), ["warden_strike", 1, "warden_brace"],
			["seamstress_prick", "warden_strike", "warden_brace"], ["warden_strike", "seamstress_prick"],
			["warden_strike", "seamstress_prick", "tinker_pop_shot"],
			["warden_strike", "seamstress_prick", "warden_brace", "warden_brace"]],
		"gold": [null, true, "110", 110.0, -1, 99, 100, 109, 121, 9223372036854775807]}
	for field in bad_values:
		for value in bad_values[field]:
			var bad := valid.duplicate(true)
			bad[field] = value
			_reject_fight(ledger, "fight", bad, "invalid " + field)
	var invented := _fight_reward(deck, 110, "invented")
	_reject_fight(ledger, "fight", invented, "invented appended catalog card")
	var skip := _fight_reward(deck, 110)
	skip.selected_id = "warden_brace"
	_reject_fight(ledger, "fight", skip, "skip with selection")
	skip = _fight_reward(deck, 110, "warden_brace")
	skip.skipped = true
	skip.selected_id = ""
	_reject_fight(ledger, "fight", skip, "skip with changed deck")
	_check(ledger.open_visit("shop"), "active rejection fixture opens")
	_reject_fight(ledger, "fight", valid, "available Shop reward")
	_check(ledger.remove_card("warden_strike").ok, "active rejection fixture uses removal")
	_reject_fight(ledger, "fight", _fight_reward(ledger.get_state().deck, 35), "used Shop reward")
	_check(ledger.close_visit(), "active rejection fixture closes")
	_reject_fight(ledger, "fight", valid, "stale pre-removal reward")
	var corrected := _fight_reward(ledger.get_state().deck, 35, "warden_brace")
	_check(ledger.apply_fight_reward("fight", corrected), "corrected same-ID retry succeeds after all failures")
	_reject_fight(ledger, "fight", corrected, "duplicate Fight snapshot")
	_reject_fight(ledger, "fight", _fight_reward(ledger.get_state().deck, 45), "duplicate ID with fresh snapshot")
	_check(ledger.apply_fight_reward("fight-next", _fight_reward(ledger.get_state().deck, 45)), "distinct ID succeeds after duplicate rejection")
	for start in [9223372036854775802, 9223372036854775807]:
		var overflow := RunShopVisit.new(deck, start, 0)
		_reject_fight(overflow, "overflow", _fight_reward(deck, -9223372036854775807), "wrapped gold")
		_reject_fight(overflow, "overflow", _fight_reward(deck, 9223372036854775807), "insufficient representable headroom")
	var boundary := RunShopVisit.new(deck, 9223372036854775797, 0)
	_reject_fight(boundary, "boundary", _fight_reward(deck, -9223372036854775807), "overflow before boundary retry")
	_check(boundary.apply_fight_reward("boundary", _fight_reward(deck, 9223372036854775807)), "exact MAX_INT corrected retry succeeds")
	for pair in [[-1, 0], [100, -1]]:
		_reject_fight(RunShopVisit.new(deck, pair[0], pair[1]), "fight", valid, "invalid ledger")


## Pool card reward admission through legacy apply_fight_reward (AC1).
func _test_pool_card_fight_reward_sequences() -> void:
	seed(61003)
	var next_draw := randi()
	seed(61003)
	var timeline := _pool_fight_sequence()
	_check(randi() == next_draw, "pool card Fight/Shop sequence consumes no global RNG")
	seed(61003)
	var replay := _pool_fight_sequence()
	_check(randi() == next_draw and timeline == replay, "replayed pool card Fight/Shop sequence replays identically")


## Pool card reward admission through typed apply_battle_reward (AC2).
func _test_pool_card_typed_battle_bridge() -> void:
	seed(82180)
	var expected_global := randi()
	seed(82180)
	var picked_fight := _typed_pool_battle_sequence(true)
	_check(not picked_fight.is_empty(), "pick Fight pool card / Skip Elite real bridge is exercised")
	_check(randi() == expected_global, "typed Fight pool pick / Elite Skip draws no global RNG")
	seed(82180)
	var replay := _typed_pool_battle_sequence(true)
	_check(randi() == expected_global and picked_fight == replay, "identical seeded pool Fight/Elite/Shop trace replays exactly")
	seed(82180)
	var picked_elite := _typed_pool_battle_sequence(false)
	_check(not picked_elite.is_empty() and randi() == expected_global, "Fight Skip / Elite pool pick exercises other choices without global RNG")


## Pool card reward rejections for both entry points (AC3).
func _test_pool_card_rejections() -> void:
	var deck: Array[String] = ["warden_strike", "seamstress_prick"]
	var ledger := RunShopVisit.new(deck, 100, 0)
	# Pool-plus upgrade posed as a reward
	var plus_reward := _fight_reward(deck, 110, "warden_hold_the_line_plus")
	_reject_fight(ledger, "fight", plus_reward, "pool-plus upgrade rejected by legacy")
	# Unknown ID
	var unknown_reward := _fight_reward(deck, 110, "invented_card")
	_reject_fight(ledger, "fight", unknown_reward, "invented ID rejected by legacy")
	# Valid retry after rejection
	var valid_pool := _fight_reward(deck, 110, "warden_hold_the_line")
	_check(ledger.apply_fight_reward("fight-retry", valid_pool), "valid pool retry succeeds after pool-plus rejection")
	_reject_fight(ledger, "fight-retry", valid_pool, "duplicate pool snapshot rejected")
	
	# Now test typed bridge rejections with pool card candidates
	var f := _typed_pool_battle_fixture()
	if f.is_empty():
		return
	var ledger2: RunShopVisit = f.ledger
	var oracle := RandomNumberGenerator.new()
	oracle.seed = f.rng.seed
	oracle.state = f.rng.state
	
	# Process Fight node
	var id: String = f.route[0]
	_check(f.map.get_legal_choices().has(id) and f.map.choose_node(id), "actual reachable Fight node is chosen")
	var party: CombatParty = f.party
	var enemies := CombatEnemies.new([{"id": "ragling", "max_hp": 8}])
	var battle := CombatBattleResult.new(party, enemies)
	_check(battle.get_outcome() == CombatBattleResult.ACTIVE, "observed battle starts ACTIVE")
	_check(enemies.apply_damage(1, 8) and battle.get_outcome() == CombatBattleResult.ACTIVE, "unobserved terminal damage is not a victory receipt")
	_check(battle.evaluate() == CombatBattleResult.VICTORY, "witness actual combat VICTORY")
	var pre_reward: Dictionary = f.owner.read_state()
	var expected_offer := _typed_pool_oracle(oracle, f.candidates, false)
	var prepared: Dictionary = f.owner.prepare(id, battle, party)
	_check(prepared == expected_offer and f.rng.state == oracle.state, "Fight gold, offers, drop, and run RNG exactly match seeded oracle")
	# Choose a pool card from the offers
	var pool_choice: String = ""
	for offer in expected_offer.offers:
		var def := RunPoolCardRewardOffers.resolve_reward_definition(offer.id)
		if not def.is_empty() and def.owner in ["warden", "seamstress", "tinker"] and (not def.has("rarity") or def.rarity in ["common", "uncommon", "rare"]):
			pool_choice = offer.id
			break
	_check(not pool_choice.is_empty(), "oracle offers at least one pool base card")
	var settled: Dictionary = f.owner.choose(id, pool_choice)
	var typed := {"node_id": id, "node_kind": "Fight", "trinket_drop_id": expected_offer.trinket_drop_id}
	_check(settled.ok and settled.receipt == typed and settled.skipped == false and settled.selected_id == pool_choice, "real settled receipt binds chosen pool card")
	
	# Test rejection of pool-plus via typed bridge
	var plus_settled := settled.duplicate(true)
	plus_settled.selected_id = "warden_hold_the_line_plus"
	plus_settled.state.deck = settled.state.deck.duplicate()
	plus_settled.state.deck.append("warden_hold_the_line_plus")
	_reject_typed(f, id, plus_settled, "pool-plus upgrade rejected by typed")
	
	# Test rejection of invented ID via typed bridge
	var invented_settled := settled.duplicate(true)
	invented_settled.selected_id = "invented_card"
	invented_settled.state.deck = settled.state.deck.duplicate()
	invented_settled.state.deck.append("invented_card")
	_reject_typed(f, id, invented_settled, "invented ID rejected by typed")
	
	# Valid pool card retry after rejection
	_check(ledger2.apply_battle_reward(id, settled), "valid pool card retry succeeds after typed rejection")
	_reject_typed(f, id, settled, "typed duplicate claim")
	
	# Process Elite node to reach Shop
	var elite_id: String = f.route[1]
	f.party = f.carry.create_next_fight_party()
	_check(f.party != null and f.party.is_valid(), "Elite party hydrated from real Fight carryover")
	if f.party == null:
		return
	_check(f.map.get_legal_choices().has(elite_id) and f.map.choose_node(elite_id), "actual reachable Elite node is chosen")
	party = f.party
	enemies = CombatEnemies.new([{"id": "ragling", "max_hp": 8}])
	battle = CombatBattleResult.new(party, enemies)
	_check(battle.get_outcome() == CombatBattleResult.ACTIVE, "observed Elite battle starts ACTIVE")
	_check(enemies.apply_damage(1, 8) and battle.get_outcome() == CombatBattleResult.ACTIVE, "unobserved terminal damage is not a victory receipt")
	_check(battle.evaluate() == CombatBattleResult.VICTORY, "witness actual Elite combat VICTORY")
	pre_reward = f.owner.read_state()
	expected_offer = _typed_pool_oracle(oracle, f.candidates, true)
	prepared = f.owner.prepare(elite_id, battle, party)
	_check(prepared == expected_offer and f.rng.state == oracle.state, "Elite gold, offers, drop, and run RNG exactly match seeded oracle")
	# Skip Elite reward
	var elite_settled: Dictionary = f.owner.choose(elite_id, "")
	var elite_typed := {"node_id": elite_id, "node_kind": "Elite", "trinket_drop_id": expected_offer.trinket_drop_id}
	_check(elite_settled.ok and elite_settled.receipt == elite_typed and elite_settled.skipped == true, "Elite skip receipt valid")
	_check(ledger2.apply_battle_reward(elite_id, elite_settled), "Elite skip admitted to ledger")
	
	# Continue to Shop and verify pool card retained through purchases
	var legal_shop: Array[String] = f.map.get_legal_choices()
	_check(legal_shop.has(f.route[2]) and f.map.choose_node(f.route[2]), "real first Shop follows Elite")
	_check(ledger2.open_visit(f.route[2]), "first canonical Shop visit opens")
	var shop := _paid_shop(ledger2.get_state())
	_paid_transaction(ledger2, shop, "card", "warden_brace", 25, "pool reward-funded first Shop card")
	var before_remove := ledger2.get_state()
	var removed := ledger2.remove_card("warden_strike")
	_check(removed.ok and removed.price == 75 and removed.prior_removals == 1, "first Shop removes at base 75 after real purchases")
	var after_remove := before_remove.duplicate(true)
	after_remove.deck.erase("warden_strike")
	after_remove.gold -= 75
	after_remove.prior_removals = 1
	after_remove.price = 100
	after_remove.removal_available = false
	after_remove.status = "used"
	_check(ledger2.get_state() == after_remove, "first paid removal exact snapshot")
	_check(ledger2.close_visit(), "first real Shop closes")
	# Verify pool card still in deck
	var state_after_shop := ledger2.get_state()
	_check(state_after_shop.deck.has(pool_choice), "pool reward card retained through Shop removal and purchase")
	
	# Verify RNG unchanged
	_check(f.rng.state == oracle.state, "Shop bridge never mutates run RNG")


func _pool_fight_reward(deck: Array, gold: int, selected: String = "") -> Dictionary:
	var cards: Array[String] = []
	cards.assign(deck)
	if selected != "":
		cards.append(selected)
	return {"ok": true, "skipped": selected == "", "selected_id": selected, "deck": cards, "gold": gold}


func _pool_fight_sequence() -> Array:
	var deck: Array[String] = ["warden_strike", "seamstress_prick", "warden_strike"]
	var ledger := RunShopVisit.new(deck, 200, 0)
	var expected := {"valid": true, "status": "inactive", "shop_node_id": "",
		"removal_available": false, "price": 75, "deck": deck.duplicate(), "trinkets": [], "gold": 200,
		"prior_removals": 0, "visited_ids": [], "claimed_fight_ids": []}
	_check(ledger.get_state() == expected, "pool Fight sequence exact initial snapshot")
	var timeline: Array = [ledger.get_state()]
	
	# Test each of the three representative pool base cards
	var pool_cards: Array[String] = ["warden_hold_the_line", "seamstress_darning", "tinker_rivet_shot"]
	for i in range(pool_cards.size()):
		var card := pool_cards[i]
		var reward := _pool_fight_reward(expected.deck, expected.gold + 10 + i * 5, card)
		var node_id := "fight-pool-%d" % i
		_check(ledger.apply_fight_reward(node_id, reward), "inactive pool Fight reward accepted for " + card)
		expected.gold = reward.gold
		expected.deck = reward.deck.duplicate()
		expected.claimed_fight_ids.append(node_id)
		_check(ledger.get_state() == expected, "pool Fight " + card + " changes only deck gold and claims")
		timeline.append(ledger.get_state())
	
	# Open Shop and verify pool cards retained
	_check(ledger.open_visit("shop-pool"), "Shop opens after pool rewards")
	_check(ledger.remove_card("warden_strike").ok, "Shop removal succeeds")
	_check(ledger.close_visit(), "Shop closes")
	expected.status = "closed"
	expected.shop_node_id = "shop-pool"
	expected.visited_ids.append("shop-pool")
	expected.deck.erase("warden_strike")
	expected.gold -= 75
	expected.prior_removals = 1
	expected.price = 100
	_check(ledger.get_state() == expected, "Shop removal exact snapshot with pool cards retained")
	timeline.append(ledger.get_state())
	
	# Verify all three pool cards still present
	var final_deck: Array[String] = ledger.get_state().deck
	for card in pool_cards:
		_check(final_deck.has(card), "pool card " + card + " retained through Shop visit")
	
	return timeline


func _typed_pool_battle_fixture() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	var map := RunMap.new()
	var route: Array[String] = []
	for map_seed in range(1, 3001):
		rng.seed = map_seed
		if not map.generate(rng):
			continue
		for fight in map.get_floors()[0]:
			if fight.type != "Fight":
				continue
			for elite_id in fight.outgoing:
				if map.get_node(elite_id).type != "Elite":
					continue
				for shop_id in map.get_node(elite_id).outgoing:
					if map.get_node(shop_id).type != "Shop":
						continue
					for second_id in map.get_node(shop_id).outgoing:
						if map.get_node(second_id).type == "Shop":
							route.assign([fight.id, elite_id, shop_id, second_id])
							break
					if not route.is_empty():
						break
				if not route.is_empty():
					break
			if not route.is_empty():
				break
		if not route.is_empty():
			break
	_check(route.size() == 4, "real map has connected Fight/Elite/Shop/Shop path for pool")
	if route.size() != 4:
		return {}
	var heroes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))
	for hero in heroes:
		hero.max_hp = int(hero.max_hp)
	var party := CombatParty.new(heroes)
	var carry := RunPartyCarryover.new(party.get_heroes())
	var deck := _starter_deck()
	var owned: Array[String] = ["button_charm"]
	var candidates := RunPoolCardRewardOffers.get_authored_base_candidates()
	var drops := ["thread_token", "button_charm", "spool_pendant"]
	_check(party.is_valid() and carry.is_valid() and not deck.is_empty()
		and candidates.size() >= 3, "typed pool bridge uses real authored pool candidates")
	var owner := RunMultiFightRewards.new(map, rng, carry, deck, 350, owned, candidates, drops)
	var ledger := RunShopVisit.new(deck, 350, 0, owned)
	return {"map": map, "rng": rng, "route": route, "party": party, "carry": carry,
		"deck": deck, "owned": owned, "candidates": candidates, "drops": drops,
		"owner": owner, "ledger": ledger}


func _typed_pool_oracle(rng: RandomNumberGenerator, candidates: Array, elite: bool) -> Dictionary:
	var award := rng.randi_range(25, 35) if elite else rng.randi_range(10, 20)
	var pool: Array = candidates.duplicate()
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("id", "")) < String(b.get("id", ""))
	)
	var offers: Array = []
	var party_ids: Array = ["warden", "seamstress", "tinker"]
	var living_ids: Array = ["warden", "seamstress", "tinker"]
	var generated := RunPoolCardRewardOffers.generate_for_living(rng, party_ids, living_ids, pool)
	if not generated.ok:
		return {"ok": false, "gold_award": 0, "offers": [], "trinket_drop_id": ""}
	var drop := ""
	if elite:
		var unowned := ["spool_pendant", "thread_token"]
		drop = unowned[rng.randi_range(0, unowned.size() - 1)]
	return {"ok": true, "gold_award": award, "offers": generated.offers, "trinket_drop_id": drop}


func _typed_pool_battle_sequence(fight_pick: bool) -> Dictionary:
	var f := _typed_pool_battle_fixture()
	if f.is_empty():
		return {}
	var ledger: RunShopVisit = f.ledger
	_check(ledger.has_method("apply_battle_reward"), "typed battle admission public API exists")
	var oracle := RandomNumberGenerator.new()
	oracle.seed = f.rng.seed
	oracle.state = f.rng.state
	var receipts: Array = []
	var timeline: Array = [ledger.get_state()]
	for index in range(2):
		var id: String = f.route[index]
		var legal: Array[String] = f.map.get_legal_choices()
		_check(legal.has(id) and f.map.choose_node(id), "actual reachable reward node is chosen")
		if index == 1:
			f.party = f.carry.create_next_fight_party()
			_check(f.party != null and f.party.is_valid(), "Elite party hydrated from real Fight carryover")
			if f.party == null:
				return {}
		var party: CombatParty = f.party
		var enemies := CombatEnemies.new([{"id": "ragling", "max_hp": 8}])
		var battle := CombatBattleResult.new(party, enemies)
		_check(battle.get_outcome() == CombatBattleResult.ACTIVE, "observed battle starts ACTIVE")
		_check(enemies.apply_damage(1, 8) and battle.get_outcome() == CombatBattleResult.ACTIVE, "unobserved terminal damage is not a victory receipt")
		_check(battle.evaluate() == CombatBattleResult.VICTORY, "witness actual combat VICTORY")
		var pre_reward: Dictionary = f.owner.read_state()
		var expected_offer := _typed_pool_oracle(oracle, f.candidates, index == 1)
		var prepared: Dictionary = f.owner.prepare(id, battle, party)
		_check(prepared == expected_offer and f.rng.state == oracle.state, "Fight/Elite gold, offers, drop, and run RNG exactly match seeded oracle")
		
		# Pick a pool base card if available, otherwise skip
		var choice: String = ""
		if (index == 0 and fight_pick) or (index == 1 and not fight_pick):
			for offer in expected_offer.offers:
				var def := RunPoolCardRewardOffers.resolve_reward_definition(offer.id)
				if not def.is_empty() and def.owner in ["warden", "seamstress", "tinker"] and (not def.has("rarity") or def.rarity in ["common", "uncommon", "rare"]):
					choice = offer.id
					break
		
		var settled: Dictionary = f.owner.choose(id, choice)
		var typed := {"node_id": id, "node_kind": "Fight" if index == 0 else "Elite", "trinket_drop_id": expected_offer.trinket_drop_id}
		_check(settled.ok and settled.receipt == typed and settled.skipped == choice.is_empty() and settled.selected_id == choice, "real settled receipt binds chosen card and canonical seeded node/drop")
		
		var expected_run: Dictionary = pre_reward.duplicate(true)
		expected_run.gold += expected_offer.gold_award
		if not choice.is_empty():
			expected_run.deck.append(choice)
		if index == 1:
			expected_run.trinkets.append(expected_offer.trinket_drop_id)
		var carried: Array = party.get_heroes()
		for hero in carried:
			hero.block = 0
		expected_run.party = f.carry.read_state()
		_check(settled.state == expected_run and f.owner.read_state() == expected_run, "complete authoritative pre/post reward snapshot matches exact delta")
		
		var original: Dictionary = settled.duplicate(true)
		_check(ledger.apply_battle_reward(id, settled), "valid real typed pool receipt succeeds")
		var expected_ledger: Dictionary = timeline.back().duplicate(true)
		expected_ledger.deck = expected_run.deck.duplicate(true)
		expected_ledger.gold = expected_run.gold
		expected_ledger.trinkets = expected_run.trinkets.duplicate(true)
		expected_ledger.claimed_fight_ids.append(id)
		_check(ledger.get_state() == expected_ledger, "exact atomic deck/gold/trinket/claim snapshot for pool card")
		_check(settled == original, "successful typed bridge never changes caller receipt")
		_reject_typed(f, id, settled, "typed duplicate claim")
		
		receipts.append(settled.duplicate(true))
		timeline.append(ledger.get_state())
	
	# Continue to Shops
	var before_shops := ledger.get_state()
	var legal_shop: Array[String] = f.map.get_legal_choices()
	_check(legal_shop.has(f.route[2]) and f.map.choose_node(f.route[2]), "real first Shop follows Elite")
	_check(ledger.open_visit(f.route[2]), "first canonical Shop visit opens")
	var shop := _paid_shop(ledger.get_state())
	_paid_transaction(ledger, shop, "card", "warden_brace", 25, "pool reward-funded first Shop card")
	_paid_transaction(ledger, shop, "trinket", "t_spool", 40, "pool reward-funded first Shop trinket")
	var before_remove := ledger.get_state()
	var removed := ledger.remove_card("warden_strike")
	_check(removed.ok and removed.price == 75 and removed.prior_removals == 1, "first Shop removes at base 75 after real purchases")
	var after_remove := before_remove.duplicate(true)
	after_remove.deck.erase("warden_strike")
	after_remove.gold -= 75
	after_remove.prior_removals = 1
	after_remove.price = 100
	after_remove.removal_available = false
	after_remove.status = "used"
	_check(ledger.get_state() == after_remove, "first paid removal exact snapshot")
	_check(ledger.close_visit(), "first real Shop closes")
	_check(f.map.get_legal_choices().has(f.route[3]) and f.map.choose_node(f.route[3]), "connected later Shop choice is genuinely legal")
	_check(ledger.open_visit(f.route[3]), "second distinct connected Shop opens")
	var before_second := ledger.get_state()
	var second_remove := ledger.remove_card("seamstress_prick")
	_check(second_remove.ok and second_remove.price == 100 and second_remove.prior_removals == 2, "second Shop removal rises to 75 + 25")
	var after_second := before_second.duplicate(true)
	after_second.deck.erase("seamstress_prick")
	after_second.gold -= 100
	after_second.price = 125
	after_second.prior_removals = 2
	after_second.removal_available = false
	after_second.status = "used"
	_check(ledger.get_state() == after_second, "second removal exact preserved inventory and claims")
	var next_shop := _paid_shop(ledger.get_state())
	_paid_transaction(ledger, next_shop, "card", "seamstress_mend", 15, "later Shop purchase after removal")
	_paid_transaction(ledger, next_shop, "trinket", "t_pocket", 20, "later Shop trinket after removal")
	_check(ledger.close_visit(), "second Shop closes with rewards and paid purchases")
	var final_state := ledger.get_state()
	_check(final_state.status == "closed" and final_state.prior_removals == 2
		and final_state.visited_ids == [f.route[2], f.route[3]]
		and final_state.claimed_fight_ids == [f.route[0], f.route[1]]
		and final_state.trinkets == before_shops.trinkets + ["t_spool", "t_pocket"]
		and final_state.deck.has("seamstress_mend") and final_state.gold >= 0, "second Shop conserves both Fight/Elite claims, drop, and complete purchase inventory")
	_check(f.owner.read_state() == receipts[1].state and f.deck == _starter_deck() and f.owned == ["button_charm"] and f.rng.state == oracle.state, "Shop bridge never mutates actual reward source or run RNG")
	timeline.append(final_state)
	return {"timeline": timeline, "receipts": receipts, "rng": f.rng.state, "route": f.route, "final": final_state}
