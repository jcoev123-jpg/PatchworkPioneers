extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_method_contract()
	_test_first_copy_removal_duplicates_order()
	_test_quotes_and_charges()
	_test_two_sequential_removals()
	_test_insufficient_money()
	_test_absent_or_empty_id()
	_test_empty_deck()
	_test_invalid_negative_inputs()
	_test_no_caller_mutation()
	_test_exact_complete_outputs()
	_test_replay_and_failed_no_mutation()
	_test_independent_results()
	if failures.is_empty():
		print("run_shop_card_removal_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_shop_card_removal_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _same_array(actual: Variant, expected: Array[String]) -> bool:
	if typeof(actual) != TYPE_ARRAY:
		return false
	var values: Array = actual
	if values.size() != expected.size():
		return false
	for index in range(expected.size()):
		if str(values[index]) != expected[index]:
			return false
	return true


func _test_method_contract() -> void:
	var service := RunShopCardRemoval.new()
	_check(service.has_method("try_remove"), "service exposes try_remove")
	_check(RunShopCardRemoval.new().try_remove([], 0, 0, "").has("ok"), "result has ok key")
	var result := RunShopCardRemoval.try_remove([], 0, 0, "")
	for key in ["ok", "price", "deck", "gold", "prior_removals"]:
		_check(result.has(key), "result has key " + key)


func _test_first_copy_removal_duplicates_order() -> void:
	var deck: Array[String] = ["warden_strike", "seamstress_prick", "warden_strike"]
	var input_copy: Array[String] = deck.duplicate()
	var result := RunShopCardRemoval.try_remove(deck, 100, 0, "warden_strike")
	_check(result["ok"] == true, "first copy removal succeeds")
	_check(result["price"] == 75, "first removal price is 75")
	_check(_same_array(result["deck"], ["seamstress_prick", "warden_strike"]), "removes first matching copy and preserves order")
	_check(result["gold"] == 25, "gold debited once")
	_check(result["prior_removals"] == 1, "removal count incremented once")
	_check(_same_array(deck, input_copy), "input deck unchanged after success")


func _test_quotes_and_charges() -> void:
	var deck: Array[String] = ["warden_strike"]
	for prior in [0, 1, 2]:
		var expected_price: int = 75 + 25 * int(prior)
		var result := RunShopCardRemoval.try_remove(deck, 1000, prior, "warden_strike")
		_check(result["ok"] == true, "removal succeeds for prior %d" % prior)
		_check(result["price"] == expected_price, "quoted price for prior %d" % prior)
		_check(result["gold"] == 1000 - expected_price, "single charge for prior %d" % prior)
		_check(result["prior_removals"] == prior + 1, "count increments for prior %d" % prior)


func _test_two_sequential_removals() -> void:
	var deck: Array[String] = ["a", "b", "a", "c"]
	var first := RunShopCardRemoval.try_remove(deck, 200, 0, "a")
	_check(first["ok"] == true, "first sequential removal succeeds")
	_check(_same_array(first["deck"], ["b", "a", "c"]), "first deck exact")
	_check(first["gold"] == 125, "first gold exact")
	_check(first["prior_removals"] == 1, "first count exact")

	var second := RunShopCardRemoval.try_remove(first["deck"], first["gold"], first["prior_removals"], "a")
	_check(second["ok"] == true, "second sequential removal succeeds")
	_check(_same_array(second["deck"], ["b", "c"]), "second deck exact")
	_check(second["price"] == 100, "second price exact")
	_check(second["gold"] == 25, "second gold exact")
	_check(second["prior_removals"] == 2, "second count exact")


func _test_insufficient_money() -> void:
	var deck: Array[String] = ["warden_strike", "seamstress_prick"]
	var input_copy: Array[String] = deck.duplicate()
	var result := RunShopCardRemoval.try_remove(deck, 74, 0, "warden_strike")
	_check(result["ok"] == false, "insufficient gold fails")
	_check(result["price"] == 75, "insufficient quote preserved")
	_check(_same_array(result["deck"], ["warden_strike", "seamstress_prick"]), "insufficient deck unchanged")
	_check(result["gold"] == 74, "insufficient gold unchanged")
	_check(result["prior_removals"] == 0, "insufficient count unchanged")
	_check(_same_array(deck, input_copy), "input unchanged on insufficient")


func _test_absent_or_empty_id() -> void:
	var deck: Array[String] = ["warden_strike", "seamstress_prick"]
	for card_id in ["", "missing_card"]:
		var input_copy: Array[String] = deck.duplicate()
		var result := RunShopCardRemoval.try_remove(deck, 100, 0, card_id)
		_check(result["ok"] == false, "id '%s' fails" % card_id)
		_check(_same_array(result["deck"], ["warden_strike", "seamstress_prick"]), "id '%s' deck unchanged" % card_id)
		_check(result["gold"] == 100, "id '%s' gold unchanged" % card_id)
		_check(result["prior_removals"] == 0, "id '%s' count unchanged" % card_id)
		_check(_same_array(deck, input_copy), "input unchanged for id '%s'" % card_id)


func _test_empty_deck() -> void:
	var deck: Array[String] = []
	var input_copy: Array[String] = deck.duplicate()
	var result := RunShopCardRemoval.try_remove(deck, 100, 0, "warden_strike")
	_check(result["ok"] == false, "empty deck fails")
	_check(_same_array(result["deck"], []), "empty deck result empty")
	_check(result["gold"] == 100, "empty deck gold unchanged")
	_check(result["prior_removals"] == 0, "empty deck count unchanged")
	_check(_same_array(deck, input_copy), "input unchanged on empty deck")


func _test_invalid_negative_inputs() -> void:
	var deck: Array[String] = ["warden_strike"]
	for gold in [-1, -100]:
		var result := RunShopCardRemoval.try_remove(deck, gold, 0, "warden_strike")
		_check(result["ok"] == false, "negative gold %d fails" % gold)
		_check(result["gold"] == gold, "negative gold unchanged")
	for prior in [-1, -100]:
		var result := RunShopCardRemoval.try_remove(deck, 100, prior, "warden_strike")
		_check(result["ok"] == false, "negative prior %d fails" % prior)
		_check(result["prior_removals"] == prior, "negative prior unchanged")


func _test_no_caller_mutation() -> void:
	var deck: Array[String] = ["warden_strike", "seamstress_prick", "warden_strike"]
	var before: Array[String] = deck.duplicate()
	var result := RunShopCardRemoval.try_remove(deck, 100, 0, "warden_strike")
	_check(_same_array(deck, before), "caller deck not mutated")
	var result_deck: Array = result["deck"]
	result_deck.clear()
	var second := RunShopCardRemoval.try_remove(deck, 100, 0, "warden_strike")
	_check(second["ok"] == true, "mutating returned deck does not affect later call")
	_check(_same_array(second["deck"], ["seamstress_prick", "warden_strike"]), "later result still correct")


func _test_exact_complete_outputs() -> void:
	var deck: Array[String] = ["warden_strike", "seamstress_prick", "warden_strike"]
	var result := RunShopCardRemoval.try_remove(deck, 100, 0, "warden_strike")
	_check(result["ok"] == true, "exact output succeeds")
	_check(result["price"] == 75, "exact output price")
	_check(_same_array(result["deck"], ["seamstress_prick", "warden_strike"]), "exact output deck")
	_check(result["gold"] == 25, "exact output gold")
	_check(result["prior_removals"] == 1, "exact output count")
	_check(result.size() == 5, "result has exactly five keys")


func _test_replay_and_failed_no_mutation() -> void:
	var deck: Array[String] = ["warden_strike", "seamstress_prick", "warden_strike"]
	var first := RunShopCardRemoval.try_remove(deck, 100, 0, "warden_strike")
	var second := RunShopCardRemoval.try_remove(deck, 100, 0, "warden_strike")
	_check(first["ok"] == second["ok"], "replay ok matches")
	_check(first["price"] == second["price"], "replay price matches")
	_check(_same_array(first["deck"], ["seamstress_prick", "warden_strike"]), "replay first deck")
	_check(_same_array(second["deck"], ["seamstress_prick", "warden_strike"]), "replay second deck")
	_check(first["gold"] == second["gold"], "replay gold matches")
	_check(first["prior_removals"] == second["prior_removals"], "replay count matches")
	_check(_same_array(deck, ["warden_strike", "seamstress_prick", "warden_strike"]), "caller unchanged across replay")

	# Failed attempts do not alter inputs for a later valid call.
	var working: Array[String] = ["warden_strike", "seamstress_prick", "warden_strike"]
	var before: Array[String] = working.duplicate()
	var failed_insufficient := RunShopCardRemoval.try_remove(working, 10, 0, "warden_strike")
	var failed_empty := RunShopCardRemoval.try_remove(working, 100, 0, "")
	var failed_count := RunShopCardRemoval.try_remove(working, 100, -1, "warden_strike")
	_check(failed_insufficient["ok"] == false and failed_empty["ok"] == false and failed_count["ok"] == false, "failed attempts rejected")
	_check(_same_array(working, before), "failed attempts leave caller unchanged")
	var valid := RunShopCardRemoval.try_remove(working, 100, 0, "warden_strike")
	_check(valid["ok"] == true, "valid call after failures succeeds")
	_check(_same_array(valid["deck"], ["seamstress_prick", "warden_strike"]), "valid result after failures correct")


func _test_independent_results() -> void:
	var deck: Array[String] = ["warden_strike", "seamstress_prick", "warden_strike"]
	var first := RunShopCardRemoval.try_remove(deck, 100, 0, "warden_strike")
	var second := RunShopCardRemoval.try_remove(deck, 100, 0, "warden_strike")
	var first_deck: Array = first["deck"]
	var second_deck: Array = second["deck"]
	first_deck.append("mutated")
	_check(not _same_array(second_deck, ["seamstress_prick", "warden_strike", "mutated"]), "second result not mutated by first")
	var third := RunShopCardRemoval.try_remove(deck, 100, 0, "warden_strike")
	_check(_same_array(third["deck"], ["seamstress_prick", "warden_strike"]), "fresh result unaffected by mutation")