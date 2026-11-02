extends SceneTree
## MPW P12: a completed-run unlock admits the two authored Heirloom powers
## into the ordinary Patch Stall seeded three-offer draw. No live wiring:
## the real map entry still supplies no unlock flag.

const ORDINARY_TICKETS := 100
## Independently authored expectation table for the two P12 records:
## ID, slot, exact gold price and 100% ordinary stock weighting.
const HEIRLOOM_EXPECTED := [
	{"id": "needle_echo", "slot": "HEAD", "price": 100, "percent": 100},
	{"id": "shared_hem", "slot": "ARM", "price": 100, "percent": 100},
]
const HEIRLOOM_IDS := ["needle_echo", "shared_hem"]
const P8_RARE_CATALOG := "res://data/patches/mpw_synergy_patches.json"
const P8_RARE_IDS := ["relay_bobbin", "hearth_lining"]
const INERT_STARTER_IDS := ["stitched_badge", "spare_spool"]
const RETAINED_ORDINARY_IDS := ["button_eye", "frayfinder_mitt", "borrowed_button"]
const PARTY := ["warden", "seamstress", "tinker"]
const DECK := ["warden_strike", "seamstress_prick", "tinker_pop_shot"]

var checks := 0
var failures: Array[String] = []


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _seeded_rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _init() -> void:
	_run()
	if failures.is_empty():
		print("mpw_patch_stall_heirloom_stock_test: PASS (", checks, " checks)")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
		print("mpw_patch_stall_heirloom_stock_test: FAIL (", failures.size(), " failures)")
		quit(1)


func _run() -> void:
	var candidates := _initial_trinkets()
	var rare := _p8_rare_records()
	_test_locked_default_matches_explicit_false(candidates)
	_test_locked_stockability(candidates, rare)
	_test_locked_supplied_heirloom_cannot_leak(candidates)
	var witnesses := _test_unlocked_witnesses(candidates, rare)
	_test_unlocked_ticket_oracle(candidates, rare)
	_test_unlocked_weight_subset(candidates, rare)
	_test_supplied_heirloom_enters_once(candidates, rare)
	_test_owned_heirloom_leaves_pool(candidates, rare)
	_test_unlocked_visit_purchase(candidates, rare, witnesses)
	_test_fail_closed_before_draw(candidates, rare)


func _initial_trinkets() -> Array:
	var text := FileAccess.get_file_as_string("res://data/shop/initial_offers.json")
	var authored: Variant = JSON.parse_string(text)
	if typeof(authored) != TYPE_DICTIONARY or typeof(authored.get("trinkets")) != TYPE_ARRAY:
		_check(false, "real initial_offers.json trinket candidates load")
		return []
	var trinkets: Array = authored["trinkets"]
	_check(not trinkets.is_empty(), "real initial_offers.json trinket candidates load")
	var listed := {}
	for offer in trinkets:
		listed[offer.get("id")] = true
	for id in HEIRLOOM_IDS:
		_check(not listed.has(id), "shared initial catalog does not list " + id)
	for id in RETAINED_ORDINARY_IDS + P8_RARE_IDS:
		_check(listed.has(id), "shared initial catalog still lists " + id)
	return trinkets


func _p8_rare_records() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(P8_RARE_CATALOG))
	if typeof(parsed) != TYPE_ARRAY:
		_check(false, "shipped P8 rare catalog parses to authored records")
		return []
	var records: Array = parsed
	_check(not records.is_empty(), "shipped P8 rare catalog parses to authored records")
	return records


func _sampled_ids(result: Dictionary) -> Array:
	var ids: Array = []
	if result.get("ok") != true:
		return ids
	for offer in result.get("offers", []):
		ids.append(offer.get("id"))
	return ids


func _oracle_power_slots(unlocked: bool) -> Dictionary:
	var slots := {}
	for entry in RunAuthoredPatchDefinitions.load_eligible_power_definitions(unlocked):
		slots[entry.id] = entry.slot
	return slots


## Independently authored sorted ticket-draw oracle: every eligible unowned
## ordinary power carries 100 tickets, every eligible unowned P8 rare its
## authored percentage of ONE ordinary patch, every unlocked Heirloom its
## independently expected 100 tickets, three draws without replacement from
## the supplied RNG only.
func _ticket_oracle(rng: RandomNumberGenerator, candidates: Array, owned: Array,
		rare: Array, unlocked: bool) -> Array:
	var slots := _oracle_power_slots(unlocked)
	var weights := {}
	var prices := {}
	for record in rare:
		if owned.has(record.id):
			continue
		weights[record.id] = ORDINARY_TICKETS * int(record.stock_weight_percent) / 100
		prices[record.id] = int(record.shop_price_gold)
	if unlocked:
		for spec in HEIRLOOM_EXPECTED:
			if owned.has(spec.id):
				continue
			weights[spec.id] = ORDINARY_TICKETS * int(spec.percent) / 100
			prices[spec.id] = int(spec.price)
	for offer in candidates:
		if not slots.has(offer.id) or owned.has(offer.id) or weights.has(offer.id):
			continue
		weights[offer.id] = ORDINARY_TICKETS
		prices[offer.id] = int(offer.price)
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


## Part 1: the legacy four-argument call is replay-identical to an explicit
## locked draw, offers and final RNG state alike.
func _test_locked_default_matches_explicit_false(candidates: Array) -> void:
	for value in [88001, 1337, 4242, 77, 999983]:
		var default_rng := _seeded_rng(value)
		var explicit_rng := _seeded_rng(value)
		var legacy := RunShopPurchases.sample_patch_stall_offers(default_rng, candidates, [])
		var locked := RunShopPurchases.sample_patch_stall_offers(
				explicit_rng, candidates, [], null, false)
		_check(legacy.get("ok") == true and locked.get("ok") == true
			and legacy.get("offers") == locked.get("offers"),
			"legacy four-argument call equals explicit locked draw for seed " + str(value))
		_check(default_rng.state == explicit_rng.state,
			"legacy and explicit locked calls consume identical draws for seed " + str(value))


## Part 1: inert starters never appear; the old P8 rare IDs and known
## ordinary IDs remain stockable in a bounded seeded witness sweep.
func _test_locked_stockability(candidates: Array, rare: Array) -> void:
	var targets: Array = P8_RARE_IDS + RETAINED_ORDINARY_IDS
	var witnesses := {}
	for value in range(1, 601):
		var sampled := RunShopPurchases.sample_patch_stall_offers(
				_seeded_rng(value), candidates, [], rare)
		if sampled.get("ok") != true or sampled.get("offers").size() != 3:
			_check(false, "locked sweep sampling succeeds for seed " + str(value))
			return
		var seen := {}
		for offer in sampled.get("offers"):
			var id: String = offer.get("id")
			_check(not seen.has(id), "locked sweep draws three distinct IDs for seed " + str(value))
			seen[id] = true
			_check(not INERT_STARTER_IDS.has(id), "locked sweep never offers inert starter " + id)
			_check(not HEIRLOOM_IDS.has(id), "locked sweep never offers a Heirloom: " + id)
			if targets.has(id):
				witnesses[id] = true
		if witnesses.size() == targets.size():
			break
	for id in targets:
		_check(witnesses.has(id), "locked sweep witnesses stockable " + id)


## Part 1: explicitly supplied P12 candidate records cannot leak into a
## locked run's draw.
func _test_locked_supplied_heirloom_cannot_leak(candidates: Array) -> void:
	var spiked: Array = candidates.duplicate(true)
	for spec in HEIRLOOM_EXPECTED:
		spiked.append({"id": spec.id, "price": int(spec.price)})
	for value in [5, 601, 90210, 4711]:
		var spiked_rng := _seeded_rng(value)
		var plain_rng := _seeded_rng(value)
		var spiked_result := RunShopPurchases.sample_patch_stall_offers(
				spiked_rng, spiked, [])
		var plain_result := RunShopPurchases.sample_patch_stall_offers(
				plain_rng, candidates, [])
		_check(spiked_result.get("ok") == true and plain_result.get("ok") == true
			and spiked_result.get("offers") == plain_result.get("offers"),
			"a locked run cannot leak supplied P12 candidates for seed " + str(value))
		_check(spiked_rng.state == plain_rng.state,
			"supplied P12 candidates never change a locked draw for seed " + str(value))


## Part 2: a bounded seeded sweep witnesses both newly eligible IDs as
## genuine three-offer stock at their exact 100-gold catalog price, while
## named historical entries remain eligible.
func _test_unlocked_witnesses(candidates: Array, rare: Array) -> Dictionary:
	var witnesses := {}
	var witness_offers := {}
	var targets: Array = HEIRLOOM_IDS + RETAINED_ORDINARY_IDS
	for value in range(1, 601):
		var sampled := RunShopPurchases.sample_patch_stall_offers(
				_seeded_rng(value), candidates, [], rare, true)
		if sampled.get("ok") != true or sampled.get("offers").size() != 3:
			_check(false, "unlocked sweep sampling succeeds for seed " + str(value))
			return witnesses
		var seen := {}
		for offer in sampled.get("offers"):
			var id: String = offer.get("id")
			_check(typeof(offer.get("price")) == TYPE_INT and offer.get("price") > 0,
				"unlocked sweep offers whole priced gold: " + id)
			_check(not seen.has(id), "unlocked sweep draws three distinct priced offers")
			seen[id] = true
			_check(not INERT_STARTER_IDS.has(id), "unlocked sweep never offers inert starter " + id)
			if targets.has(id) and not witnesses.has(id):
				witnesses[id] = value
				witness_offers[id] = offer.duplicate(true)
		if witnesses.size() == targets.size():
			break
	for spec in HEIRLOOM_EXPECTED:
		_check(witnesses.has(spec.id), "unlocked sweep witnesses " + spec.id)
		if not witnesses.has(spec.id):
			continue
		var offer: Dictionary = witness_offers[spec.id]
		_check(offer.get("price") == spec.price,
			"witnessed Heirloom quotes its exact 100-gold catalog price: " + spec.id)
		_check(_oracle_power_slots(true).get(spec.id) == spec.slot,
			"witnessed Heirloom keeps its authored " + spec.slot + " slot: " + spec.id)
	for id in RETAINED_ORDINARY_IDS:
		_check(witnesses.has(id), "unlocked sweep still witnesses ordinary " + id)
	return witnesses


## Part 2: fixed seeded samples match the independent ticket oracle, with
## identical run RNG states and reversed candidate input; the shipped rare
## catalog and the explicitly supplied records agree on an unlocked draw.
func _test_unlocked_ticket_oracle(candidates: Array, rare: Array) -> void:
	for value in [1, 7, 4242, 88001, 999983]:
		var actual_rng := _seeded_rng(value)
		var oracle_rng := _seeded_rng(value)
		var expected := _ticket_oracle(oracle_rng, candidates, [], rare, true)
		var actual := RunShopPurchases.sample_patch_stall_offers(
				actual_rng, candidates, [], rare, true)
		_check(actual.get("ok") == true and actual.get("offers") == expected,
			"independent 100-ordinary/10-P8/100-P12 ticket oracle matches for seed " + str(value))
		_check(actual_rng.state == oracle_rng.state,
			"unlocked sampler consumes exactly the oracle's draws for seed " + str(value))
		var reversed: Array = candidates.duplicate(true)
		reversed.reverse()
		var reversed_rng := _seeded_rng(value)
		var reversed_expected := _ticket_oracle(_seeded_rng(value), reversed, [], rare, true)
		var reversed_actual := RunShopPurchases.sample_patch_stall_offers(
				reversed_rng, reversed, [], rare, true)
		_check(reversed_actual.get("ok") == true
			and reversed_actual.get("offers") == expected
			and reversed_expected == expected,
			"reversed candidates keep the sorted-ID unlocked draws for seed " + str(value))
		_check(reversed_rng.state == oracle_rng.state,
			"reversed candidates consume the same unlocked draws for seed " + str(value))
	var default_rng := _seeded_rng(555)
	var supplied_rng := _seeded_rng(555)
	var default_draw := RunShopPurchases.sample_patch_stall_offers(
			default_rng, candidates, [], null, true)
	var supplied_draw := RunShopPurchases.sample_patch_stall_offers(
			supplied_rng, candidates, [], rare, true)
	_check(default_draw.get("ok") == true and default_draw == supplied_draw,
		"unlocked draw with the shipped rare catalog matches the supplied records")


## Part 2: a three-ordinary/two-rare/two-Heirloom pool isolates the exact
## relative weights: the P8 rares stay at 10% of one ordinary patch while
## each unlocked Heirloom draws at its full ordinary weight.
func _test_unlocked_weight_subset(candidates: Array, rare: Array) -> void:
	var subset: Array = []
	for offer in candidates:
		if RETAINED_ORDINARY_IDS.has(offer.get("id")):
			subset.append(offer.duplicate(true))
	_check(subset.size() == 3, "weight subset uses the three retained ordinary candidates")
	var rare_firsts := 0
	var heirloom_firsts := 0
	for value in range(1, 241):
		var sampled := RunShopPurchases.sample_patch_stall_offers(
				_seeded_rng(value), subset, [], rare, true)
		if sampled.get("ok") != true or sampled.get("offers").size() != 3:
			_check(false, "weight subset still stocks three unlocked offers")
			return
		var first_id: String = sampled.get("offers")[0].get("id")
		if P8_RARE_IDS.has(first_id):
			rare_firsts += 1
		if HEIRLOOM_IDS.has(first_id):
			heirloom_firsts += 1
	_check(rare_firsts >= 2 and rare_firsts <= 30,
		"P8 rares stay at 10% of one ordinary in the unlocked pool (saw "
		+ str(rare_firsts) + "/240 first draws)")
	_check(heirloom_firsts >= 50 and heirloom_firsts <= 130,
		"unlocked Heirlooms draw at their full ordinary weight (saw "
		+ str(heirloom_firsts) + "/240 first draws)")


## Part 2: a Heirloom also supplied as an ordinary candidate enters the
## weighted pool exactly once, at its catalog-authored price.
func _test_supplied_heirloom_enters_once(candidates: Array, rare: Array) -> void:
	var spiked: Array = candidates.duplicate(true)
	spiked.append({"id": "needle_echo", "price": 50})
	spiked.append({"id": "shared_hem", "price": 50})
	spiked.append({"id": "needle_echo", "price": 50})
	for value in [21, 404, 5150]:
		var spiked_rng := _seeded_rng(value)
		var plain_rng := _seeded_rng(value)
		var spiked_result := RunShopPurchases.sample_patch_stall_offers(
				spiked_rng, spiked, [], rare, true)
		var plain_result := RunShopPurchases.sample_patch_stall_offers(
				plain_rng, candidates, [], rare, true)
		_check(spiked_result.get("ok") == true and plain_result.get("ok") == true
			and spiked_result.get("offers") == plain_result.get("offers"),
			"supplied Heirloom candidates enter the pool once at catalog price for seed " + str(value))
		_check(spiked_rng.state == plain_rng.state,
			"supplied Heirloom duplicates never change the unlocked draw for seed " + str(value))


## Owned Heirlooms leave the pool while ordinary stock continues.
func _test_owned_heirloom_leaves_pool(candidates: Array, rare: Array) -> void:
	for value in [3, 11, 97]:
		var sampled := RunShopPurchases.sample_patch_stall_offers(
				_seeded_rng(value), candidates, HEIRLOOM_IDS.duplicate(), rare, true)
		_check(sampled.get("ok") == true and sampled.get("offers").size() == 3
			and _sampled_ids(sampled).all(func(id): return not HEIRLOOM_IDS.has(id)),
			"owned Heirlooms are never restocked while ordinary stock continues")


## Part 3: a witnessed unlocked three-offer sample flows through the real
## RunPatchStallVisit service for both P12 patches, funded and refused.
func _test_unlocked_visit_purchase(candidates: Array, rare: Array,
		witnesses: Dictionary) -> void:
	for spec in HEIRLOOM_EXPECTED:
		if not witnesses.has(spec.id):
			continue
		var sample_rng := _seeded_rng(witnesses[spec.id])
		var sampled := RunShopPurchases.sample_patch_stall_offers(
				sample_rng, candidates, [], rare, true)
		var frozen_rng_state: int = sample_rng.state
		var offers: Array = sampled.get("offers")
		_check(offers.size() == 3, "witnessed unlocked sample has three offers: " + spec.id)
		var visit := RunPatchStallVisit.new("heirloom_stall", PARTY, DECK, [], 100, offers)
		_check(visit.is_valid(), "funded unlocked visit is valid: " + spec.id)
		var state := visit.read_state()
		var quote := visit.quote()
		_check(quote.get("decisions") == ["buy_patch", "leave"],
			"visit quotes both decisions: " + spec.id)
		_check(quote.get("offers").size() == 3,
			"open visit quotes three priced offers: " + spec.id)
		var preview := visit.preview_purchase(spec.id, state.visit_id,
			"heirloom_stall", state.snapshot)
		_check(preview == {"kind": "trinket", "id": spec.id, "price": spec.price},
			"preview quotes the exact 100-gold Heirloom receipt: " + spec.id)
		var paid := visit.buy_patch(spec.id, state.visit_id,
			"heirloom_stall", state.snapshot)
		_check(paid.get("ok") == true and paid.get("receipt") == {"kind": "trinket",
			"id": spec.id, "price": spec.price},
			"purchase records one exact 100-gold catalog receipt: " + spec.id)
		_check(paid.get("ledger", {}).get("gold") == 0,
			"exactly 100 gold is deducted: " + spec.id)
		var owned_after: Array = paid.get("ledger", {}).get("trinkets", [])
		_check(owned_after.size() == 1 and owned_after[0] == spec.id,
			"exactly one ownership addition: " + spec.id)
		_check(visit.is_consumed(), "purchase consumes the visit: " + spec.id)
		_check(visit.quote() == {"offers": [], "decisions": []},
			"closed visit advertises neither stock nor actions: " + spec.id)
		_check(not visit.buy_patch(spec.id, state.visit_id,
				"heirloom_stall", state.snapshot).get("ok", true),
			"no second purchase after close: " + spec.id)
		_check(visit.read_state().visit_id == state.visit_id,
			"closed visit keeps its authentic identity: " + spec.id)
		# Stale identity and wrong snapshot never buy.
		var stale := RunPatchStallVisit.new("heirloom_stall", PARTY, DECK, [], 100, offers)
		var stale_state := stale.read_state()
		var stale_quote := stale.quote()
		_check(not stale.buy_patch(spec.id, "wrong_visit", "heirloom_stall",
				stale_state.snapshot).get("ok", true),
			"stale visit identity cannot buy: " + spec.id)
		_check(not stale.buy_patch(spec.id, stale_state.visit_id, "wrong_node",
				stale_state.snapshot).get("ok", true),
			"stale node identity cannot buy: " + spec.id)
		var wrong_snapshot: Dictionary = stale_state.snapshot.duplicate(true)
		wrong_snapshot.gold += 10
		_check(not stale.buy_patch(spec.id, stale_state.visit_id, "heirloom_stall",
				wrong_snapshot).get("ok", true),
			"wrong snapshot cannot buy: " + spec.id)
		_check(not stale.is_consumed() and stale.read_state() == stale_state
			and stale.quote() == stale_quote,
			"refused purchases preserve state, gold and stock: " + spec.id)
		# One gold short never takes the Heirloom.
		var broke := RunPatchStallVisit.new("heirloom_stall", PARTY, DECK, [], 99, offers)
		var broke_state := broke.read_state()
		var broke_quote := broke.quote()
		_check(broke.preview_purchase(spec.id, broke_state.visit_id,
				"heirloom_stall", broke_state.snapshot).is_empty(),
			"99 gold previews nothing: " + spec.id)
		_check(not broke.buy_patch(spec.id, broke_state.visit_id, "heirloom_stall",
				broke_state.snapshot).get("ok", true),
			"99 gold cannot buy the 100-gold Heirloom: " + spec.id)
		_check(not broke.is_consumed() and broke.read_state() == broke_state
			and broke.quote() == broke_quote
			and broke.read_state().get("snapshot", {}).get("gold") == 99,
			"refused 99-gold purchase preserves gold, stock and visit: " + spec.id)
		# An already-owned Heirloom listing is admitted sold and never payable.
		var preowned := RunPatchStallVisit.new("heirloom_stall", PARTY, DECK,
			[spec.id], 100, offers)
		var preowned_state := preowned.read_state()
		var preowned_quote := preowned.quote()
		_check(preowned.is_valid(), "pre-owned Heirloom visit is still valid: " + spec.id)
		var sold := 0
		for listing in preowned_quote.get("offers", []):
			if listing.get("id") == spec.id and listing.get("sold") == true:
				sold += 1
		_check(sold == 1, "pre-owned Heirloom listing is admitted sold: " + spec.id)
		_check(not preowned.buy_patch(spec.id, preowned_state.visit_id,
				"heirloom_stall", preowned_state.snapshot).get("ok", true),
			"pre-owned Heirloom is not payable again: " + spec.id)
		_check(not preowned.is_consumed() and preowned.read_state() == preowned_state
			and preowned.quote() == preowned_quote
			and preowned.read_state().get("snapshot", {}).get("gold") == 100,
			"refused pre-owned purchase preserves gold, stock and visit: " + spec.id)
		# Leave closes the visit without spending gold.
		var leaving := RunPatchStallVisit.new("heirloom_stall", PARTY, DECK, [], 100, offers)
		var leave_state := leaving.read_state()
		var left := leaving.leave(leave_state.visit_id, "heirloom_stall",
			leave_state.snapshot)
		_check(left.get("ok") == true and leaving.is_consumed(),
			"leave closes the visit: " + spec.id)
		_check(left.get("ledger", {}).get("gold") == 100,
			"leave never spends gold: " + spec.id)
		_check(not leaving.buy_patch(spec.id, leave_state.visit_id,
				"heirloom_stall", leave_state.snapshot).get("ok", true),
			"no purchase after leave: " + spec.id)
		_check(sample_rng.state == frozen_rng_state,
			"the whole visit flow advances no run RNG: " + spec.id)


## Part 4: a wrong unlock flag and malformed supplied records refuse
## before any draw; corrupt P12 source negatives stay covered by the
## existing RunAuthoredPatchDefinitions catalog-validation tests.
func _test_fail_closed_before_draw(candidates: Array, rare: Array) -> void:
	for bad_unlock in [1, 0, "true", null, {}, 1.0]:
		var refused_rng := _seeded_rng(606)
		var refused_state: int = refused_rng.state
		var refused := RunShopPurchases.sample_patch_stall_offers(
				refused_rng, candidates, [], rare, bad_unlock)
		_check(refused == {"ok": false} and refused_rng.state == refused_state,
			"invalid unlock flag refuses before any draw: " + str(bad_unlock))
	var malformed: Array = []
	var duplicate: Array = candidates.duplicate(true)
	duplicate.append({"id": "button_eye", "price": 100})
	malformed.append(["duplicate ordinary candidate", duplicate])
	var missing_price: Array = candidates.duplicate(true)
	missing_price[0].erase("price")
	malformed.append(["missing price", missing_price])
	var bad_price: Array = candidates.duplicate(true)
	bad_price[0]["price"] = 99.5
	malformed.append(["fractional price", bad_price])
	var zero_price: Array = candidates.duplicate(true)
	zero_price[0]["price"] = 0
	malformed.append(["zero price", zero_price])
	var bad_id: Array = candidates.duplicate(true)
	bad_id[0]["id"] = 17
	malformed.append(["numeric id", bad_id])
	var non_dictionary: Array = candidates.duplicate(true)
	non_dictionary[0] = "button_eye"
	malformed.append(["non-dictionary offer", non_dictionary])
	for entry in malformed:
		var denied_rng := _seeded_rng(9081)
		var denied_state: int = denied_rng.state
		var denied := RunShopPurchases.sample_patch_stall_offers(
				denied_rng, entry[1], [], rare, true)
		_check(denied == {"ok": false} and denied_rng.state == denied_state,
			"malformed supplied candidate refuses an unlocked stall before any draw: "
			+ str(entry[0]))
	var wrong_slot: Dictionary = rare[0].duplicate(true)
	wrong_slot["slot"] = "COAT"
	var denied_rare_rng := _seeded_rng(4321)
	var denied_rare_state: int = denied_rare_rng.state
	_check(RunShopPurchases.sample_patch_stall_offers(
				denied_rare_rng, candidates, [], [wrong_slot], true) == {"ok": false}
			and denied_rare_rng.state == denied_rare_state,
		"malformed supplied rare refuses an unlocked stall before any draw")
