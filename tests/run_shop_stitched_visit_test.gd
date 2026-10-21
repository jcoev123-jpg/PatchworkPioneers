extends SceneTree
## Rest -> run-owned Shop -> Rest, using canonical starter definitions.

const PRICK := "seamstress_prick"
const POP := "tinker_pop_shot"
const MEND := "seamstress_mend"
const BOMB := "tinker_scrap_bomb"
const STRIKE := "warden_strike"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_whole_composite_and_future_rest()
	_test_mixed_shop_route_purchases_rewards()
	_test_unavailable_and_bad_admission()
	_test_rejected_purchase_and_reward()
	_test_deterministic_replay()
	if failures.is_empty():
		print("run_shop_stitched_visit_test: PASS (", checks, " checks)")
	else:
		for reason in failures:
			printerr(reason)
		print("run_shop_stitched_visit_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures.append(reason)


func _stitch_two(scraps: int = 9) -> Dictionary:
	var catalog := StarterCards.new()
	var deck := catalog.get_starting_deck()
	_check(deck.count(STRIKE) == 2 and deck.has(PRICK) and deck.has(POP)
		and deck.has(MEND) and deck.has(BOMB), "real repeated cards and two cross-owner pairs")
	_check(catalog.get_definition(PRICK).owner == "seamstress"
		and catalog.get_definition(PRICK).effects == {"damage": 3, "bleed": 2}
		and catalog.get_definition(POP).owner == "tinker"
		and catalog.get_definition(POP).effects == {"damage": 5},
		"stitches use authoritative first/second effects and owners")
	var first := RunRestStitchCards.new(deck, {}, scraps)
	_check(first.is_valid() and not first.is_consumed(), "first Rest takes actual starter deck")
	if not first.is_valid():
		return {}
	var one := first.choose_stitch(deck.find(PRICK), deck.find(POP), first.get_snapshot())
	_check(one.ok and one.stitched_id == "stitched_000001"
		and one.descriptor.display_name == "Prick / Pop Shot"
		and one.descriptor.cost == 2 and one.remaining_scraps == scraps - 3,
		"real Rest generates first canonical composite at 3 scraps")
	if not one.ok:
		return {}
	var next := RunRestStitchCards.new(one.deck, one.descriptors,
		one.remaining_scraps, one.next_stitch_id)
	_check(next.is_valid(), "second Rest accepts full committed ledger")
	if not next.is_valid():
		return {}
	var two := next.choose_stitch(one.deck.find(MEND), one.deck.find(BOMB), next.get_snapshot())
	_check(two.ok and two.stitched_id == "stitched_000002"
		and two.descriptors.size() == 2 and two.next_stitch_id == 3,
		"second authentic composite gets a distinct monotonically increasing ID")
	if not two.ok:
		return {}
	return {"source_deck": deck, "one": one, "two": two}


func _visit(receipt: Dictionary, gold: int = 400, count: int = 0,
		trinkets: Array[String] = []) -> RunShopVisit:
	var deck: Array[String] = []
	deck.assign(receipt.deck)
	return RunShopVisit.new(deck, gold, count, trinkets,
		receipt.descriptors, receipt.next_stitch_id)


func _check_rejected(visit: RunShopVisit, id: String, reason: String) -> void:
	var before := visit.get_state()
	var rejection := visit.remove_card(id)
	_check(rejection.keys().size() == 7 and rejection.keys().has("descriptors")
		and rejection.keys().has("next_stitch_id") and rejection.ok == false,
		reason + ": rejected seven-field receipt")
	_check(rejection.deck == before.deck and rejection.descriptors == before.descriptors
		and rejection.next_stitch_id == before.next_stitch_id
		and rejection.gold == before.gold and rejection.prior_removals == before.prior_removals,
		reason + ": exact unchanged removal transaction")
	_check(visit.get_state() == before, reason + ": entire Shop, visits and inventory unchanged")


func _test_whole_composite_and_future_rest() -> void:
	var pair := _stitch_two()
	if pair.is_empty():
		return
	var one: Dictionary = pair.one
	var original := one.duplicate(true)
	var own: Array[String] = []
	own.assign(one.deck)
	var owned_registry: Dictionary = one.descriptors.duplicate(true)
	var visit := _visit(one, 75)
	_check(visit.get_state().valid and visit.get_state().descriptors == owned_registry
		and visit.get_state().next_stitch_id == 2, "optional mode validates and snapshots owned ledger")
	_check(visit.open_visit("shop-whole") and visit.quote() == 75, "real first Shop opens with exact base quote")
	_check_rejected(visit, "stitched_999999", "unowned serial prefix impostor")
	_check_rejected(visit, "", "empty selection")
	_check_rejected(visit, "not_owned", "absent ordinary selection")
	var before := visit.get_state()
	var result := visit.remove_card(one.stitched_id)
	var expected_deck: Array = before.deck.duplicate()
	expected_deck.erase(one.stitched_id)
	_check(result.size() == 7 and result.ok and result.price == 75
		and result.deck == expected_deck and result.descriptors == {}
		and result.next_stitch_id == 2 and result.gold == 0
		and result.prior_removals == 1, "whole-card removal returns exact seven-key 75-gold receipt")
	var state := visit.get_state()
	_check(state.deck == expected_deck and state.descriptors == {}
		and state.next_stitch_id == 2 and state.gold == 0 and state.price == 100
		and state.prior_removals == 1 and state.status == "used"
		and not state.removal_available and state.visited_ids == ["shop-whole"],
		"Shop persists exact paid removal, cursor and one-use latch")
	_check(state.deck.size() == before.deck.size() - 1
		and state.deck.count(one.stitched_id) == 0 and state.deck.count(PRICK) == 1
		and state.deck.count(POP) == 1 and state.trinkets == [],
		"only whole composite removed; original consumed halves not refunded")
	_check(own == original.deck and owned_registry == original.descriptors,
		"constructor and removal do not mutate caller's nested source")
	var result2 := result.duplicate(true)
	result.deck.clear()
	result.descriptors["forged"] = {"first_half": {"effects": {"damage": 99}}}
	state.deck.clear()
	state.descriptors["forged"] = {}
	_check(visit.get_state().deck == result2.deck and visit.get_state().descriptors == {},
		"mutating returned transaction and read snapshot cannot corrupt owned state")
	_check_rejected(visit, STRIKE, "already-used removal option")
	_check(visit.close_visit(), "used Shop closes without other changes")
	_check_rejected(visit, STRIKE, "closed Shop cannot remove")
	var later_state := visit.get_state()
	var later := RunRestStitchCards.new(later_state.deck, later_state.descriptors,
		3, later_state.next_stitch_id)
	_check(later.is_valid(), "later Rest accepts paid removal's empty registry and retained cursor")
	if not later.is_valid():
		return
	var repeat := later.choose_stitch(later_state.deck.find(PRICK), later_state.deck.find(POP),
		later.get_snapshot())
	_check(repeat.ok and repeat.stitched_id == "stitched_000002"
		and repeat.next_stitch_id == 3 and repeat.remaining_scraps == 0
		and repeat.descriptors.size() == 1 and repeat.descriptors.has("stitched_000002"),
		"later Rest spends scraps normally and cannot reuse retired stitched_000001")


func _stock(state: Dictionary) -> RunShopPurchases:
	return RunShopPurchases.new(
		["warden", "seamstress", "tinker"], state.deck, state.trinkets, state.gold,
		[
			{"id": "warden_brace", "owner": "warden", "price": 25},
			{"id": "tinker_pop_shot", "owner": "tinker", "price": 30},
			{"id": "seamstress_mend", "owner": "seamstress", "price": 15},
			{"id": "tinker_scrap_bomb", "owner": "tinker", "price": 20},
			{"id": "warden_shield_bash", "owner": "warden", "price": 10}
		],
		[{"id": "t_spool", "price": 40}, {"id": "t_pocket", "price": 20}]
	)


func _purchase(visit: RunShopVisit, kind: String, id: String, price: int) -> void:
	var before := visit.get_state()
	var shop := _stock(before)
	_check(shop.is_valid() and shop.get_stock().cards.size() == 5
		and shop.get_stock().trinkets.size() == 2, "authentic five-card/two-trinket stock")
	var receipt := shop.buy(kind, id)
	_check(receipt.ok and receipt.receipt == {"kind": kind, "id": id, "price": price}
		and receipt.state.gold == before.gold - price,
		"purchase is a real priced stock transaction")
	_check(visit.reconcile_purchase(receipt), "actual stock receipt is reconciled")
	var after := visit.get_state()
	_check(after.gold == before.gold - price
		and after.descriptors == before.descriptors
		and after.next_stitch_id == before.next_stitch_id
		and after.prior_removals == before.prior_removals
		and after.claimed_fight_ids == before.claimed_fight_ids
		and after.visited_ids == before.visited_ids,
		"stock purchase retains stitched allocator, registry, counts and visits")
	if kind == "card":
		_check(after.deck == before.deck + [id] and after.trinkets == before.trinkets,
			"card purchase appends one card and preserves trinkets")
	else:
		_check(after.deck == before.deck and after.trinkets == before.trinkets + [id],
			"trinket purchase appends one owned item and preserves deck")
	_check(not visit.reconcile_purchase(receipt) and visit.get_state() == after,
		"paid purchase receipt cannot be replayed")
	receipt.state.deck.clear()
	receipt.state.trinkets.clear()
	_check(visit.get_state() == after, "purchase receipt mutation cannot alter visit")


func _test_mixed_shop_route_purchases_rewards() -> void:
	var pair := _stitch_two()
	if pair.is_empty():
		return
	var made: Dictionary = pair.two
	var one_id: String = pair.one.stitched_id
	var two_id: String = made.stitched_id
	var scraps: int = made.remaining_scraps
	var owned: Array[String] = ["button_charm"]
	var visit := _visit(made, 400, 0, owned)
	var expected := visit.get_state()
	_check(visit.open_visit("shop-first"), "first distinct Shop opens")
	_purchase(visit, "card", "warden_brace", 25)
	var first_before := visit.get_state()
	var first := visit.remove_card(STRIKE)
	var first_deck: Array = first_before.deck.duplicate()
	first_deck.erase(STRIKE)
	_check(first.ok and first.price == 75 and first.gold == 300
		and first.prior_removals == 1 and first.deck == first_deck
		and first.descriptors == made.descriptors and first.next_stitch_id == 3,
		"ordinary first-match duplicate removal keeps both real composites")
	_check(first.deck.count(STRIKE) == 1 and first.deck.count(one_id) == 1
		and first.deck.count(two_id) == 1, "first duplicate only retired; two descriptors owned")
	first.descriptors[one_id]["first_half"]["effects"]["damage"] = 909
	var detached := visit.get_state()
	_check(detached.descriptors[one_id]["first_half"]["effects"]["damage"] == 3,
		"ordinary removal receipt deep-copies surviving nested descriptor")
	detached.descriptors[one_id]["second_half"]["effects"]["damage"] = 808
	_check(visit.get_state().descriptors[one_id]["second_half"]["effects"]["damage"] == 5,
		"two state reads never share nested Rest descriptors")
	_check_rejected(visit, two_id, "one removal maximum per Shop")
	_purchase(visit, "trinket", "t_spool", 40)
	_check(visit.close_visit(), "first Shop closes after post-removal purchase")
	var before_fight := visit.get_state()
	var fight_cards: Array = before_fight.deck.duplicate()
	fight_cards.append(POP)
	var reward := {"ok": true, "skipped": false, "selected_id": POP,
		"deck": fight_cards, "gold": before_fight.gold + 15}
	_check(visit.apply_fight_reward("fight-after-shop", reward),
		"closed Shop accepts canonical Fight gold and selected card")
	var after_fight := visit.get_state()
	_check(after_fight.gold == before_fight.gold + 15
		and after_fight.deck == fight_cards
		and after_fight.descriptors == before_fight.descriptors
		and after_fight.next_stitch_id == before_fight.next_stitch_id
		and after_fight.claimed_fight_ids == ["fight-after-shop"]
		and after_fight.trinkets == before_fight.trinkets,
		"Fight reward preserves complete stitched ownership and visited history")
	_check(not visit.apply_fight_reward("fight-after-shop", reward)
		and visit.get_state() == after_fight, "duplicate Fight reward never claims twice")
	_check(visit.open_visit("shop-second") and visit.quote() == 100,
		"second distinct Shop opens at escalated 100 gold")
	_purchase(visit, "card", "seamstress_mend", 15)
	var second_before := visit.get_state()
	var second := visit.remove_card(one_id)
	var second_deck: Array = second_before.deck.duplicate()
	second_deck.erase(one_id)
	var next_registry: Dictionary = made.descriptors.duplicate(true)
	next_registry.erase(one_id)
	_check(second.ok and second.size() == 7 and second.price == 100
		and second.gold == second_before.gold - 100 and second.prior_removals == 2
		and second.deck == second_deck and second.descriptors == next_registry
		and second.next_stitch_id == 3, "second Shop retires only selected authentic descriptor")
	_check(visit.get_state().descriptors == next_registry
		and visit.get_state().trinkets == ["button_charm", "t_spool"]
		and visit.get_state().visited_ids == ["shop-first", "shop-second"]
		and visit.get_state().claimed_fight_ids == ["fight-after-shop"],
		"other composite, patch, both Shops and Fight claim survive")
	_check(visit.close_visit() and visit.open_visit("shop-third")
		and visit.quote() == 125, "third distinct Shop quotes 125 without rewinding history")
	var third := visit.remove_card(two_id)
	_check(third.ok and third.price == 125 and third.prior_removals == 3
		and third.descriptors == {} and third.next_stitch_id == 3,
		"125-gold removal retires last composite but never reuses a serial")
	var after := visit.get_state()
	_check(after.gold >= 0 and after.trinkets == ["button_charm", "t_spool"]
		and scraps == 3 and after.descriptors == {} and after.next_stitch_id == 3,
		"gold remains nonnegative; scraps unchanged across all Shops")
	_check(visit.close_visit(), "third Shop closes")
	var future := RunRestStitchCards.new(after.deck, after.descriptors, scraps, after.next_stitch_id)
	_check(future.is_valid(), "future Rest receives complete mixed-deck ledger")
	if future.is_valid():
		var rest_again := future.choose_stitch(after.deck.find(PRICK),
			after.deck.find(POP), future.get_snapshot())
		_check(rest_again.ok and rest_again.stitched_id == "stitched_000003"
			and rest_again.remaining_scraps == 0 and rest_again.next_stitch_id == 4,
			"future Rest continues from serial 3, using 3 actual scraps")
	_check(expected.descriptors == made.descriptors and owned == ["button_charm"],
		"original stitched Rest and owned patch inputs stay detached")


func _test_unavailable_and_bad_admission() -> void:
	var pair := _stitch_two()
	if pair.is_empty():
		return
	var made: Dictionary = pair.one
	var instance := _visit(made, 74)
	_check_rejected(instance, made.stitched_id, "unopened Shop")
	_check(instance.open_visit("poor") and instance.quote() == 75, "74-gold Shop available")
	_check_rejected(instance, made.stitched_id, "insufficient gold")
	_check(instance.get_state().removal_available and instance.close_visit(),
		"failed choice does not consume Shop")
	_check(not instance.open_visit("poor"), "same confirmed Shop ID cannot reopen")
	var retry := _visit(made, 75)
	_check(retry.open_visit("recovery"), "separate funded Shop opens")
	_check_rejected(retry, "stitched_000099", "prefix alone grants no ownership")
	_check(retry.remove_card(made.stitched_id).ok, "valid retry succeeds after forged choice")
	var bad_registry: Dictionary = made.descriptors.duplicate(true)
	bad_registry[made.stitched_id]["first_half"]["effects"]["damage"] = 999
	var orphaned: Array[String] = []
	orphaned.assign(made.deck)
	orphaned.erase(made.stitched_id)
	var imposter: Array[String] = []
	imposter.assign(made.deck)
	imposter.append("stitched_000099")
	var bad_cursor := made.duplicate(true)
	bad_cursor.next_stitch_id = 1
	var incomplete := RunShopVisit.new(made.deck, 100, 0, [], made.descriptors)
	var wrong_reg := RunShopVisit.new(made.deck, 100, 0, [], bad_registry, made.next_stitch_id)
	var orphan := RunShopVisit.new(orphaned, 100, 0, [], made.descriptors, made.next_stitch_id)
	var fake := RunShopVisit.new(imposter, 100, 0, [], made.descriptors, made.next_stitch_id)
	var stale := _visit(bad_cursor, 100)
	var negative := _visit(made, -1)
	for invalid in [incomplete, wrong_reg, orphan, fake, stale, negative]:
		var before: Dictionary = invalid.get_state()
		_check(not before.valid and before.has("descriptors")
			and before.has("next_stitch_id"), "malformed ledger/initial gold cannot initialize")
		_check(not invalid.open_visit("rejected"), "malformed input cannot open Shop")
		_check_rejected(invalid, made.stitched_id, "invalid admitted Shop cannot spend")
		_check(not invalid.close_visit() and invalid.get_state() == before,
			"invalid Shop remains inactive without modifying owner state")


func _test_rejected_purchase_and_reward() -> void:
	var pair := _stitch_two()
	if pair.is_empty():
		return
	var visit := _visit(pair.one, 225)
	_check(visit.open_visit("receipt-shop"), "receipt-negative Shop opens")
	var before := visit.get_state()
	var bogus: Array = before.deck.duplicate()
	bogus.append("stitched_555555")
	var forged := {"ok": true, "state": {"deck": bogus, "gold": 200}}
	_check(not visit.reconcile_purchase(forged) and visit.get_state() == before,
		"forged prefixed card cannot enter run through receipt-less purchase")
	var bogus_receipt := {"ok": true,
		"state": {"deck": bogus, "gold": 200, "trinkets": before.trinkets},
		"receipt": {"kind": "card", "id": "stitched_555555", "price": 25}}
	_check(not visit.reconcile_purchase(bogus_receipt) and visit.get_state() == before,
		"forged prefix cannot enter via priced purchase either")
	_check(visit.remove_card(pair.one.stitched_id).ok,
		"rejected purchase preserves removal and future valid retry")
	_check(visit.close_visit(), "purchase-negative Shop closes")
	var after := visit.get_state()
	var invalid_reward := {"ok": true, "skipped": false, "selected_id": "fake",
		"deck": after.deck + ["fake"], "gold": after.gold + 10}
	_check(not visit.apply_fight_reward("fight-invalid", invalid_reward)
		and visit.get_state() == after, "forged Fight card reward cannot change cursor/registry")
	var accepted := {"ok": true, "skipped": true, "selected_id": "",
		"deck": after.deck.duplicate(), "gold": after.gold + 10}
	_check(visit.apply_fight_reward("fight-invalid", accepted)
		and visit.get_state().descriptors == after.descriptors
		and visit.get_state().next_stitch_id == after.next_stitch_id,
		"corrected Fight receipt accepted without ledger reset")
	_check(not visit.apply_fight_reward("fight-invalid", accepted),
		"same Fight claim cannot pay a second time")


func _trace(seed_value: int) -> Dictionary:
	var pair := _stitch_two()
	if pair.is_empty():
		return {}
	seed(seed_value)
	var next_global := randi()
	seed(seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var before_rng := rng.state
	var visit := _visit(pair.one, 200)
	var choices: Array = []
	choices.append(visit.remove_card(STRIKE))
	choices.append(visit.open_visit("shop-alpha"))
	choices.append(visit.remove_card("stitched_555555"))
	choices.append(visit.remove_card(pair.one.stitched_id))
	choices.append(visit.remove_card(STRIKE))
	choices.append(visit.close_visit())
	choices.append(visit.open_visit("shop-beta"))
	choices.append(visit.remove_card(STRIKE))
	return {"choices": choices, "state": visit.get_state(), "source": pair.one,
		"global_unchanged": randi() == next_global, "local_unchanged": rng.state == before_rng}


func _test_deterministic_replay() -> void:
	var first := _trace(720111)
	var second := _trace(720111)
	_check(not first.is_empty() and first == second,
		"two fresh Rest-Shop timelines return identical complete state and receipts")
	_check(first.get("global_unchanged") and first.get("local_unchanged")
		and second.get("global_unchanged") and second.get("local_unchanged"),
		"success and failure draw neither real global nor injected run RNG")
