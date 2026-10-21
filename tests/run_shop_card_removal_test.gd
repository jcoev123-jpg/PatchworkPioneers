extends SceneTree

const PRICK := "seamstress_prick"
const POP := "tinker_pop_shot"
const MEND := "seamstress_mend"
const BOMB := "tinker_scrap_bomb"
const STRIKE := "warden_strike"
const BRACE := "warden_brace"
const TUNE := "tinker_tune_up"

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
	_test_stitch_ledger_contract()
	_test_owned_composite_removal()
	_test_ordinary_removal_preserves_ledger()
	_test_rejections_are_fail_closed()
	_test_legacy_helper_unchanged()
	_test_rest_stays_stitchable()
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


func _json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "open shipped JSON " + path)
	if file == null:
		return null
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	_check(data is Array, "shipped JSON array " + path)
	return data


func _starter_deck() -> Array[String]:
	var content: Variant = _json("res://data/cards/starter_deck.json")
	var result: Array[String] = []
	if content is Array:
		for id in content:
			_check(id is String, "starting deck contains string-only IDs")
			if id is String:
				result.append(id)
	return result


func _party() -> Array[Dictionary]:
	var definitions: Variant = _json("res://data/heroes/starter_party.json")
	if not definitions is Array:
		return []
	for definition in definitions:
		if definition is Dictionary and typeof(definition.get("max_hp")) == TYPE_FLOAT:
			definition["max_hp"] = int(definition["max_hp"])
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "real CombatParty created from shipped hero definitions")
	return party.get_heroes()


func _index(deck: Array, card: String, nth: int = 0) -> int:
	var count := 0
	for i in range(deck.size()):
		if deck[i] == card:
			if count == nth:
				return i
			count += 1
	return -1


## Two genuine Rest stitches over the shipped starter deck: a Prick / Pop Shot
## composite and a Mend / Scrap Bomb composite with their real descriptors,
## built by two actual choose_stitch transactions with genuine receipts.
func _two_composite_ledger() -> Dictionary:
	var deck := _starter_deck()
	var first := RunRestStitchCards.new(deck, {}, 3)
	if not first.is_valid():
		return {}
	var one := first.choose_stitch(_index(deck, PRICK), _index(deck, POP), first.get_snapshot())
	if not one.get("ok", false):
		return {}
	var stitched_deck: Array = one["deck"]
	var second := RunRestStitchCards.new(stitched_deck, one["descriptors"], 3, one["next_stitch_id"])
	if not second.is_valid():
		return {}
	var two := second.choose_stitch(_index(stitched_deck, MEND), _index(stitched_deck, BOMB), second.get_snapshot())
	if not two.get("ok", false):
		return {}
	return {
		"deck": two["deck"],
		"descriptors": two["descriptors"],
		"next_stitch_id": two["next_stitch_id"],
		"ids": [one["stitched_id"], two["stitched_id"]],
	}


func _test_stitch_ledger_contract() -> void:
	_check(RunShopCardRemoval.new().has_method("try_remove_with_stitch_ledger"),
		"the service exposes the stitch-ledger-aware removal entry point")
	var fixture := _two_composite_ledger()
	_check(not fixture.is_empty(), "the two-composite Rest fixture is built")
	if fixture.is_empty():
		return
	var deck: Array[String] = []
	deck.assign(fixture["deck"])
	var descriptors: Dictionary = fixture["descriptors"]
	var cursor: int = fixture["next_stitch_id"]
	var ids: Array = fixture["ids"]
	var removed_id: String = ids[0]

	var success := RunShopCardRemoval.try_remove_with_stitch_ledger(deck, descriptors, cursor, 200, 0, removed_id)
	var failure := RunShopCardRemoval.try_remove_with_stitch_ledger(deck, descriptors, cursor, 0, 0, removed_id)
	_check(success["ok"] == true, "the contract fixture succeeds")
	_check(failure["ok"] == false, "the contract fixture failure is rejected")
	for label in ["success", "failure"]:
		var result: Dictionary = success if label == "success" else failure
		_check(result.size() == 7, "the stitch-aware " + label + " receipt has exactly seven keys")
		for key in ["ok", "price", "deck", "descriptors", "next_stitch_id", "gold", "prior_removals"]:
			_check(result.has(key), "the stitch-aware " + label + " receipt has key " + key)
	_check(not success.has("remaining_scraps") and not failure.has("remaining_scraps"),
		"the stitch-aware receipt never carries scraps")


func _test_owned_composite_removal() -> void:
	var fixture := _two_composite_ledger()
	_check(not fixture.is_empty(), "two real composites are built through two actual Rest stitches")
	if fixture.is_empty():
		return
	var deck: Array[String] = []
	deck.assign(fixture["deck"])
	var descriptors: Dictionary = fixture["descriptors"]
	var cursor: int = fixture["next_stitch_id"]
	var ids: Array = fixture["ids"]
	var removed_id: String = ids[0]
	var kept_id: String = ids[1]
	_check(removed_id == "stitched_000001" and kept_id == "stitched_000002",
		"the two real stitches own durable sequential composite IDs")
	_check(cursor == 3, "the allocator cursor advanced once per stitch")
	_check(deck.count(removed_id) == 1 and deck.count(kept_id) == 1,
		"the source deck still contains both composite IDs before the Shop removal")
	_check(descriptors.size() == 2 and descriptors.has(removed_id) and descriptors.has(kept_id),
		"the source registry owns both composite descriptors")
	var deck_before := deck.duplicate()
	var descriptors_before := descriptors.duplicate(true)

	seed(20261023)
	var expected_draw := randi()
	seed(20261023)
	var result := RunShopCardRemoval.try_remove_with_stitch_ledger(deck, descriptors, cursor, 200, 0, removed_id)
	_check(randi() == expected_draw, "the paid composite removal draws no global RNG")
	_check(result["ok"] == true, "a genuinely owned composite is removable")
	_check(result["price"] == 75, "the first removal quotes 75 gold")
	_check(result["gold"] == 125, "the first removal debits exactly 75 gold")
	_check(result["prior_removals"] == 1, "the first removal raises the removal count to one")
	_check(result["next_stitch_id"] == cursor, "the allocator cursor is unchanged")
	var result_deck: Array = result["deck"]
	_check(result_deck.size() == deck_before.size() - 1, "exactly one deck entry disappears")
	_check(result_deck.count(removed_id) == 0, "the removed composite leaves the deck")
	_check(result_deck.count(kept_id) == 1, "the other composite stays in the deck")
	var expected_deck := deck_before.duplicate()
	expected_deck.remove_at(expected_deck.find(removed_id))
	_check(_same_array(result_deck, expected_deck), "the surviving deck keeps its order")
	var result_descriptors: Dictionary = result["descriptors"]
	_check(not result_descriptors.has(removed_id), "the removed composite's descriptor is retired")
	_check(result_descriptors.size() == descriptors_before.size() - 1, "exactly one descriptor is retired")
	_check(result_descriptors[kept_id] == descriptors_before[kept_id], "the surviving descriptor is untouched")
	_check(deck == deck_before, "the caller's deck is unchanged")
	_check(descriptors == descriptors_before, "the caller's descriptor registry is unchanged")

	# The survivor is still a legal, playable composite of the remaining run.
	var later := RunRestStitchCards.new(result["deck"], result["descriptors"], 3, result["next_stitch_id"])
	_check(later.is_valid(), "the remaining run still satisfies the Rest stitch contract")
	var heroes := _party()
	if heroes.size() == 3:
		var legal := later.preview_play(kept_id, heroes)
		_check(legal.get("ok") == true, "the surviving composite is still playable with the real party")
		_check(legal.get("cost", 0) == 3, "the surviving composite keeps its authored cost")

	# The returned snapshot is detached: mutating it cannot reach the caller.
	var mend_definition := StarterCards.new().get_definition(MEND)
	var returned: Dictionary = result["descriptors"]
	returned[kept_id]["first_half"]["effects"]["heal"] = 999
	_check(descriptors[kept_id]["first_half"] == mend_definition,
		"mutating a returned descriptor snapshot does not touch the owned registry")
	var fresh := RunShopCardRemoval.try_remove_with_stitch_ledger(deck, descriptors, cursor, 200, 0, STRIKE)
	_check(fresh["descriptors"][kept_id]["first_half"] == mend_definition,
		"a later result still carries the untouched owned descriptor")


func _test_ordinary_removal_preserves_ledger() -> void:
	var fixture := _two_composite_ledger()
	_check(not fixture.is_empty(), "the mixed deck fixture is built")
	if fixture.is_empty():
		return
	var deck: Array[String] = []
	deck.assign(fixture["deck"])
	var descriptors: Dictionary = fixture["descriptors"]
	var cursor: int = fixture["next_stitch_id"]
	var ids: Array = fixture["ids"]
	var composite_id: String = ids[0]
	var kept_id: String = ids[1]
	_check(deck.count(STRIKE) == 2, "the mixed deck holds two copies of a starter attack")
	_check(descriptors.size() == 2, "the mixed deck owns two stitched descriptors")

	var current_deck: Array = deck.duplicate()
	var current_descriptors: Dictionary = descriptors.duplicate(true)
	var prior := 0
	var expected_prices := [75, 100, 125]
	var targets := [composite_id, STRIKE, BRACE]
	for step in range(3):
		var result := RunShopCardRemoval.try_remove_with_stitch_ledger(
				current_deck, current_descriptors, cursor, 500, prior, targets[step])
		_check(result["ok"] == true, "removal %d of the chain succeeds" % step)
		_check(result["price"] == expected_prices[step],
				"removal %d quotes %d gold for %d prior removals" % [step, expected_prices[step], prior])
		_check(result["gold"] == 500 - expected_prices[step], "removal %d debits %d gold once" % [step, expected_prices[step]])
		_check(result["prior_removals"] == prior + 1, "removal %d raises the removal count" % step)
		_check(result["next_stitch_id"] == cursor, "removal %d keeps the allocator cursor" % step)
		var before: Array = current_deck.duplicate()
		var expected: Array = before.duplicate()
		expected.remove_at(expected.find(targets[step]))
		_check(_same_array(result["deck"], expected), "removal %d removes exactly the first matching copy" % step)
		if step == 0:
			_check(not result["descriptors"].has(composite_id), "the composite's descriptor is retired with it")
			_check(result["descriptors"].has(kept_id), "the other descriptor stays owned")
		else:
			_check(result["descriptors"] == current_descriptors, "an ordinary removal preserves every descriptor")
			_check(result["descriptors"].has(kept_id),
					"an ordinary removal preserves the surviving composite descriptor")
			_check(not result["descriptors"].has(composite_id),
					"an ordinary removal never resurrects a retired descriptor")
		_check(result["deck"].count(kept_id) == 1, "an ordinary removal keeps the surviving composite in the deck")
		current_deck = result["deck"]
		current_descriptors = result["descriptors"]
		prior = result["prior_removals"]
	_check(current_deck.count(STRIKE) == 1, "only one of the two starter attack copies was removed")
	_check(current_descriptors.size() == 1 and current_descriptors.has(kept_id),
			"the stitch ledger survives ordinary removals with only the owned composite left")

	# The quote follows the removal count, never the deck or catalog size.
	var tiny := RunShopCardRemoval.try_remove_with_stitch_ledger([STRIKE], {}, 1, 500, 2, STRIKE)
	_check(tiny["ok"] == true and tiny["price"] == 125 and tiny["gold"] == 375,
		"the quote follows the removal count, not the deck size or the catalog size")


func _test_rejections_are_fail_closed() -> void:
	var fixture := _two_composite_ledger()
	_check(not fixture.is_empty(), "the rejection fixture is built")
	if fixture.is_empty():
		return
	var deck: Array[String] = []
	deck.assign(fixture["deck"])
	var descriptors: Dictionary = fixture["descriptors"]
	var cursor: int = fixture["next_stitch_id"]
	var ids: Array = fixture["ids"]
	var composite_id: String = ids[0]
	var kept_id: String = ids[1]

	var forged: Dictionary = descriptors.duplicate(true)
	forged[kept_id]["first_half"]["effects"]["heal"] = 999
	var swapped: Dictionary = descriptors.duplicate(true)
	swapped[composite_id] = descriptors[kept_id].duplicate(true)
	var orphan_deck: Array = deck.duplicate()
	orphan_deck.erase(kept_id)
	var forged_name_deck: Array = deck.duplicate()
	forged_name_deck[forged_name_deck.find(kept_id)] = "stitched_000009"
	var forged_name_registry: Dictionary = descriptors.duplicate(true)
	forged_name_registry.erase(kept_id)

	var cases: Array = [
		{"label": "insufficient gold", "deck": deck, "descriptors": descriptors, "cursor": cursor,
			"gold": 74, "prior": 0, "card": composite_id, "gold_expected": 74, "prior_expected": 0,
			"cursor_expected": cursor, "price_expected": 75},
		{"label": "empty card ID", "deck": deck, "descriptors": descriptors, "cursor": cursor,
			"gold": 500, "prior": 0, "card": "", "gold_expected": 500, "prior_expected": 0,
			"cursor_expected": cursor, "price_expected": 75},
		{"label": "absent card ID", "deck": deck, "descriptors": descriptors, "cursor": cursor,
			"gold": 500, "prior": 0, "card": "not_a_real_card", "gold_expected": 500, "prior_expected": 0,
			"cursor_expected": cursor, "price_expected": 75},
		{"label": "forged descriptor contents", "deck": deck, "descriptors": forged, "cursor": cursor,
			"gold": 500, "prior": 0, "card": kept_id, "gold_expected": 500, "prior_expected": 0,
			"cursor_expected": cursor, "price_expected": 75},
		{"label": "swapped descriptor pair", "deck": deck, "descriptors": swapped, "cursor": cursor,
			"gold": 500, "prior": 0, "card": composite_id, "gold_expected": 500, "prior_expected": 0,
			"cursor_expected": cursor, "price_expected": 75},
		{"label": "orphaned descriptor", "deck": orphan_deck, "descriptors": descriptors, "cursor": cursor,
			"gold": 500, "prior": 0, "card": composite_id, "gold_expected": 500, "prior_expected": 0,
			"cursor_expected": cursor, "price_expected": 75},
		{"label": "forged composite name without an owned descriptor", "deck": forged_name_deck,
			"descriptors": forged_name_registry, "cursor": cursor, "gold": 500, "prior": 0,
			"card": "stitched_000009", "gold_expected": 500, "prior_expected": 0,
			"cursor_expected": cursor, "price_expected": 75},
		{"label": "allocator cursor behind the registry", "deck": deck, "descriptors": descriptors, "cursor": 1,
			"gold": 500, "prior": 0, "card": composite_id, "gold_expected": 500, "prior_expected": 0,
			"cursor_expected": 1, "price_expected": 75},
		{"label": "allocator cursor at zero", "deck": deck, "descriptors": descriptors, "cursor": 0,
			"gold": 500, "prior": 0, "card": composite_id, "gold_expected": 500, "prior_expected": 0,
			"cursor_expected": 0, "price_expected": 75},
		{"label": "allocator cursor of the wrong type", "deck": deck, "descriptors": descriptors, "cursor": "3",
			"gold": 500, "prior": 0, "card": composite_id, "gold_expected": 500, "prior_expected": 0,
			"cursor_expected": 0, "price_expected": 75},
		{"label": "negative removal count", "deck": deck, "descriptors": descriptors, "cursor": cursor,
			"gold": 500, "prior": -1, "card": composite_id, "gold_expected": 500, "prior_expected": -1,
			"cursor_expected": cursor, "price_expected": 50},
		{"label": "removal count of the wrong type", "deck": deck, "descriptors": descriptors, "cursor": cursor,
			"gold": 500, "prior": "one", "card": composite_id, "gold_expected": 500, "prior_expected": 0,
			"cursor_expected": cursor, "price_expected": 75},
		{"label": "negative gold", "deck": deck, "descriptors": descriptors, "cursor": cursor,
			"gold": -5, "prior": 0, "card": composite_id, "gold_expected": -5, "prior_expected": 0,
			"cursor_expected": cursor, "price_expected": 75},
	]

	seed(20261022)
	var expected_draw := randi()
	seed(20261022)
	for case in cases:
		var label: String = case["label"]
		var deck_before: Array = case["deck"].duplicate(true)
		var descriptors_before: Dictionary = case["descriptors"].duplicate(true)
		var result := RunShopCardRemoval.try_remove_with_stitch_ledger(
				case["deck"], case["descriptors"], case["cursor"], case["gold"], case["prior"], case["card"])
		_check(result["ok"] == false, label + " is rejected")
		_check(result.size() == 7, label + " returns the same seven-key receipt")
		_check(result["deck"] == deck_before, label + " leaves the deck unchanged")
		_check(result["descriptors"] == descriptors_before, label + " leaves the descriptor registry unchanged")
		_check(result["gold"] == case["gold_expected"], label + " leaves the gold unchanged")
		_check(result["prior_removals"] == case["prior_expected"], label + " leaves the removal count unchanged")
		_check(result["next_stitch_id"] == case["cursor_expected"], label + " leaves the allocator cursor unchanged")
		_check(result["price"] == case["price_expected"], label + " keeps the exact quote")
		# The returned snapshots are detached: emptying them cannot reach the caller.
		var returned_deck: Array = result["deck"]
		returned_deck.clear()
		var returned_descriptors: Dictionary = result["descriptors"]
		returned_descriptors.clear()
		_check(case["deck"] == deck_before and case["descriptors"] == descriptors_before,
				label + " does not mutate the caller's inputs")

	var first_replay := RunShopCardRemoval.try_remove_with_stitch_ledger(
			deck, descriptors, cursor, 500, 0, composite_id)
	var second_replay := RunShopCardRemoval.try_remove_with_stitch_ledger(
			deck, descriptors, cursor, 500, 0, composite_id)
	_check(randi() == expected_draw, "no global RNG draw happened during the rejected attempts or the valid retry")
	_check(first_replay == second_replay, "the same input replays to an identical receipt")
	_check(first_replay["ok"] == true, "a fresh valid call on the original input still succeeds")
	_check(first_replay["descriptors"].has(kept_id) and not first_replay["descriptors"].has(composite_id),
			"the legal retry removes the composite and retires only its descriptor")
	_check(deck.count(composite_id) == 1 and deck.count(kept_id) == 1,
			"the rejected attempts left the caller's deck intact")


func _test_legacy_helper_unchanged() -> void:
	var deck: Array[String] = ["warden_strike", "seamstress_prick", "warden_strike"]
	var result := RunShopCardRemoval.try_remove(deck, 100, 0, "warden_strike")
	_check(result.size() == 5, "the legacy receipt still has exactly five keys")
	for key in ["ok", "price", "deck", "gold", "prior_removals"]:
		_check(result.has(key), "the legacy receipt still has key " + key)
	_check(result["ok"] == true and result["price"] == 75 and result["gold"] == 25
			and result["prior_removals"] == 1, "the legacy receipt keeps its 75-gold first removal")
	_check(_same_array(result["deck"], ["seamstress_prick", "warden_strike"]),
			"the legacy receipt still removes only the first copy")
	_check(RunShopCardRemoval.try_remove(deck, 74, 0, "warden_strike")["ok"] == false,
			"the legacy helper still fails closed on insufficient gold")
	_check(RunShopCardRemoval.try_remove(deck, 100, -1, "warden_strike")["ok"] == false,
			"the legacy helper still fails closed on a negative removal count")
	_check(RunShopCardRemoval.try_remove(deck, 100, 0, "")["ok"] == false,
			"the legacy helper still fails closed on an empty card ID")


func _test_rest_stays_stitchable() -> void:
	var fixture := _two_composite_ledger()
	_check(not fixture.is_empty(), "the stitchability fixture is built")
	if fixture.is_empty():
		return
	var deck: Array[String] = []
	deck.assign(fixture["deck"])
	var descriptors: Dictionary = fixture["descriptors"]
	var cursor: int = fixture["next_stitch_id"]
	var ids: Array = fixture["ids"]
	var composite_id: String = ids[0]
	var kept_id: String = ids[1]

	var result := RunShopCardRemoval.try_remove_with_stitch_ledger(deck, descriptors, cursor, 300, 0, composite_id)
	_check(result["ok"] == true, "the paid composite removal succeeds")
	var later := RunRestStitchCards.new(result["deck"], result["descriptors"], 3, result["next_stitch_id"])
	_check(later.is_valid(), "the remaining run is still stitchable after paying to remove a composite")
	var next_id := later.choose_stitch(_index(result["deck"], STRIKE), _index(result["deck"], TUNE),
			later.get_snapshot())
	_check(next_id.get("ok", false) == true, "a later Rest visit can stitch two surviving different-owner cards")
	_check(next_id.get("stitched_id", "") == "stitched_000003",
			"the allocator hands out the next unused ID instead of reusing the retired serial")
	_check(next_id.get("descriptors", {}).has(kept_id),
			"the surviving composite descriptor is still owned after the later stitch")
	_check(next_id.get("descriptors", {}).size() == 2, "the later stitch adds exactly one descriptor")
	_check(not next_id.get("descriptors", {}).has(composite_id),
			"the retired composite descriptor never comes back")