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
	_test_rng_and_equal_replay()
	_test_purchase_reconciliation()
	_test_removal_before_purchase_reconciliation()
	_test_fight_reward_sequences()
	_test_fight_reward_rejections()
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
	for method in ["open_visit", "remove_card", "close_visit", "get_state", "quote", "apply_fight_reward"]:
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
		"removal_available": false, "price": 75, "deck": deck.duplicate(), "gold": 200,
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
