extends SceneTree

var _checks := 0
var _failures := []

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)

func _init() -> void:
	_run()
	if _failures.is_empty():
		print("run_patch_stall_visit_test: PASS (", _checks, " checks)")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("run_patch_stall_visit_test: FAIL (", _checks, " checks)")
		quit(1)

func _run() -> void:
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	
	var party := ["warden", "seamstress", "tinker"]
	var deck := ["warden_strike", "tinker_pop_shot"]
	var owned := ["quilted_coat"]
	var gold := 200
	var broke_gold := 50
	
	var sample_result := RunShopPurchases.sample_patch_stall_offers(rng, authored.trinkets, owned)
	_check(sample_result.ok, "sampled patch stall offers successfully")
	var offers: Array = sample_result.offers
	var rng_state := rng.state

	# AC1: Initialization and quote
	var old_visit := RunPatchStallVisit.new("node_1", party, deck, owned, gold, offers)
	var old_source := old_visit.read_state()
	var visit := RunPatchStallVisit.new("node_1", party, deck, owned, gold, offers)
	_check(visit.is_valid(), "valid visit created")
	var state := visit.read_state()
	_check(old_visit.is_valid() and visit.is_valid(), "both identical-source visits are valid")
	_check(state.node_id == "node_1" and not state.visit_id.is_empty(), "source issues node and visit IDs")
	_check(state.snapshot == old_source.snapshot and visit.quote() == old_visit.quote(), "distinct visits have identical source and sampled offers")
	_check(state.visit_id != old_source.visit_id, "identical-source instances have distinct visit identities")
	_check(visit.read_state() == state and old_visit.read_state() == old_source, "visit identities are stable on repeated reads")
	_check(rng.state == rng_state, "identical-source construction draws no run RNG")
	_check_stale_requests(old_source.visit_id, visit, offers[0].id)
	_check_stale_requests(state.visit_id, old_visit, offers[0].id)
	
	var quote := visit.quote()
	_check(quote.decisions == ["buy_patch", "leave"], "quotes exactly buy_patch and leave decisions")
	_check(quote.offers.size() == 3, "quotes exactly three distinct offers")
	
	var prices_match := true
	var exact_stock := true
	for i in range(quote.offers.size()):
		var offer: Dictionary = quote.offers[i]
		var found := false
		for a in authored.trinkets:
			if a.id == offer.id and int(a.price) == int(offer.price):
				found = true
				break
		if not found:
			prices_match = false
		# The open quote is exactly the seeded three-offer stock in source order.
		exact_stock = exact_stock and i < offers.size() and offer.id == offers[i].id \
			and int(offer.price) == int(offers[i].price) and offer.sold == false
	_check(prices_match, "prices match authored initial_offers.json exactly")
	_check(exact_stock, "open quote retains the exact three sampled priced power patches")
	var expected_quote: Array = []
	for offer in offers:
		expected_quote.append({"id": offer.id, "price": offer.price, "sold": false})
	_check(not visit.is_consumed() and quote == {"offers": expected_quote,
		"decisions": ["buy_patch", "leave"]}, "open quote is the authentic source stock and both decisions")
	
	# AC3: Negatives and rejection
	var bad_visit := RunPatchStallVisit.new("", party, deck, owned, gold, offers)
	_check(not bad_visit.is_valid(), "empty node id rejected")
	
	var bad_offers := RunPatchStallVisit.new("node_1", party, deck, owned, gold, [])
	_check(not bad_offers.is_valid(), "empty offers rejected")
	
	var snapshot: Dictionary = state.snapshot
	var bad_snapshot := snapshot.duplicate(true)
	bad_snapshot.gold += 10
	
	_check(not visit.buy_patch(offers[0].id, "wrong_visit", "node_1", snapshot).ok, "wrong visit id rejected")
	_check(not visit.buy_patch(offers[0].id, state.visit_id, "wrong_node", snapshot).ok, "wrong node id rejected")
	_check(not visit.buy_patch(offers[0].id, state.visit_id, "node_1", bad_snapshot).ok, "mutated snapshot rejected")
	_check(not visit.buy_patch("forged_id", state.visit_id, "node_1", snapshot).ok, "forged patch id rejected")
	_check(visit.read_state() == state and visit.quote() == quote, "invalid purchases preserve state and stock")
	
	var broke_visit := RunPatchStallVisit.new("node_1", party, deck, owned, broke_gold, offers)
	var broke_state := broke_visit.read_state()
	var broke_quote := broke_visit.quote()
	_check(not broke_visit.buy_patch(offers[0].id, broke_state.visit_id, "node_1", broke_state.snapshot).ok, "insufficient gold purchase rejected")
	_check(not broke_visit.is_consumed(), "failed purchase does not consume visit")
	_check(broke_visit.preview_purchase(offers[0].id, broke_state.visit_id, "node_1", broke_state.snapshot).is_empty(), "unaffordable preview refuses without consuming")
	_check(broke_visit.read_state() == broke_state and broke_visit.quote() == broke_quote, "unaffordable actions preserve state and stock")

	var atomic_visit := RunPatchStallVisit.new("node_1", party, deck, owned, gold, offers)
	var atomic_source := atomic_visit.read_state()
	var atomic_open_quote := atomic_visit.quote()
	_check_stale_requests(old_source.visit_id, atomic_visit, offers[0].id)
	var receipt := atomic_visit.preview_purchase(offers[0].id, atomic_source.visit_id, "node_1", snapshot)
	_check(receipt == {"kind": "trinket", "id": offers[0].id, "price": offers[0].price}
		and atomic_visit.read_state() == atomic_source, "preview is exact and read-only")
	for bad in [{}, {"kind": "card", "id": offers[0].id, "price": offers[0].price},
		{"kind": "trinket", "id": offers[0].id, "price": offers[0].price + 1},
		{"kind": "trinket", "id": "forged", "price": offers[0].price},
		{"kind": "trinket", "id": offers[0].id, "price": offers[0].price, "extra": true}]:
		_check(not atomic_visit.reconcile_purchase(bad, atomic_source.visit_id, "node_1", snapshot)
			and atomic_visit.read_state() == atomic_source, "nonidentical atomic receipt leaves service open")
	_check(not atomic_visit.reconcile_purchase(receipt, "foreign", "node_1", snapshot)
		and not atomic_visit.reconcile_purchase(receipt, atomic_source.visit_id, "foreign", snapshot)
		and not atomic_visit.reconcile_purchase(receipt, atomic_source.visit_id, "node_1", bad_snapshot), "foreign and stale reconciliation refused")
	_check(atomic_visit.quote() == atomic_open_quote and not atomic_visit.is_consumed(),
		"refused reconciliation keeps the open three-offer quote")
	_check(atomic_visit.reconcile_purchase(receipt, atomic_source.visit_id, "node_1", snapshot)
		and atomic_visit.is_consumed(), "identical atomic receipt consumes service")
	_check(not atomic_visit.reconcile_purchase(receipt, atomic_source.visit_id, "node_1", snapshot), "duplicate atomic receipt refused")
	_check(atomic_visit.read_state().visit_id == atomic_source.visit_id, "atomic close preserves visit identity")
	_check(atomic_visit.preview_purchase(offers[1].id, atomic_source.visit_id, "node_1", snapshot).is_empty(),
		"closed atomic visit previews no further patch")
	_check_closed_quote(atomic_visit, atomic_open_quote, atomic_source, "authenticated paid-and-sewn reconciliation")
	
	# AC2: Successful Leave
	var leave_visit := RunPatchStallVisit.new("node_1", party, deck, owned, gold, offers)
	var leave_source := leave_visit.read_state()
	var leave_open_quote := leave_visit.quote()
	_check_stale_requests(old_source.visit_id, leave_visit, offers[0].id)
	var leave_receipt := leave_visit.leave(leave_source.visit_id, "node_1", leave_source.snapshot)
	_check(leave_receipt.ok and leave_receipt.decision == "leave", "successful leave receipt")
	_check(leave_receipt.ledger.gold == gold, "leave does not spend gold")
	_check(leave_receipt.ledger.trinkets == owned, "leave does not add patches")
	_check(leave_visit.is_consumed(), "leave closes the visit")
	_check(not leave_visit.leave(leave_source.visit_id, "node_1", leave_source.snapshot).ok, "leave latches once")
	_check(leave_visit.read_state().visit_id == leave_source.visit_id, "Leave preserves visit identity")
	_check(not leave_visit.buy_patch(offers[0].id, leave_source.visit_id, "node_1", leave_visit.read_state().snapshot).ok, "cannot buy after leave")
	_check_closed_quote(leave_visit, leave_open_quote, leave_source, "Leave")
	
	# AC2: Successful Buy
	var buy_open_quote := visit.quote()
	var buy_receipt := visit.buy_patch(offers[0].id, state.visit_id, "node_1", snapshot)
	_check(buy_receipt.ok and buy_receipt.decision == "buy_patch", "successful buy receipt")
	_check(buy_receipt.receipt.id == offers[0].id, "receipt matches chosen patch")
	_check(buy_receipt.ledger.gold == gold - offers[0].price, "gold reduced by exact patch price")
	_check(buy_receipt.ledger.trinkets.size() == owned.size() + 1 and buy_receipt.ledger.trinkets.has(offers[0].id), "one new owned patch in ledger")
	_check(buy_receipt.ledger.deck == deck, "unchanged deck")
	_check(visit.is_consumed(), "buy closes the visit")
	_check(visit.read_state().visit_id == state.visit_id, "paid close preserves visit identity")
	_check(not visit.buy_patch(offers[1].id, state.visit_id, "node_1", snapshot).ok, "cannot buy second patch after closing")
	_check_closed_quote(visit, buy_open_quote, state, "direct buy")
	
	# AC4: Global/Run RNG isolation
	_check(rng.state == rng_state, "visit creation and actions do not consume global or run RNG")
	_run_four_hero_stitched()
	_run_open_stitched()


## Four-hero Stitched Patch Stall: warden, seamstress, tinker, lantern_monk, an
## empty deck and authentic seeded stock from the real sampler. The wrapper is
## unchanged; the helper now admits the four actors.
func _run_four_hero_stitched() -> void:
	seed(495021)
	var expected_global := randi()
	seed(495021)
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 495021
	var party := ["warden", "seamstress", "tinker", "lantern_monk"]
	var deck: Array = []
	var owned := ["button_eye"]
	var gold := 500
	var sampled := RunShopPurchases.sample_patch_stall_offers(rng, authored.trinkets, owned)
	_check(sampled.ok and sampled.offers.size() == 3, "four-hero seeded sampler returns three offers")
	if not sampled.ok:
		return
	var offers: Array = sampled.offers
	var rng_state := rng.state
	var authored_prices := {}
	for entry in authored.trinkets:
		authored_prices[entry.id] = int(entry.price)
	for offer in offers:
		_check(offer.price is int and offer.price > 0 and not owned.has(offer.id),
			"four-hero offer is priced and unowned " + str(offer.id))
		if authored_prices.has(offer.id):
			_check(authored_prices[offer.id] == offer.price,
				"four-hero ordinary offer keeps authored price " + str(offer.id))
	var price: int = offers[0].price

	# AC1: admission, party order, empty deck, exactly three priced patches plus Leave.
	var old_visit := RunPatchStallVisit.new("node_4", party, deck, owned, gold, offers)
	var visit := RunPatchStallVisit.new("node_4", party, deck, owned, gold, offers)
	_check(old_visit.is_valid() and visit.is_valid(), "four-hero Stitched visits are valid")
	var state := visit.read_state()
	var old_state := old_visit.read_state()
	_check(state.snapshot == {"party_ids": party, "deck_ids": [], "owned_trinkets": owned, "gold": gold},
		"four-hero snapshot keeps all four IDs in order and the empty deck")
	_check(state.visit_id != old_state.visit_id and state.status == "available",
		"four-hero identical-source visits have distinct identities")
	var expected_quote: Array = []
	for offer in offers:
		expected_quote.append({"id": offer.id, "price": offer.price, "sold": false})
	var quote := visit.quote()
	_check(quote == {"offers": expected_quote, "decisions": ["buy_patch", "leave"]}
		and quote.offers.size() == 3, "four-hero quote is exactly three priced patches plus Leave")
	_check_stale_requests(old_state.visit_id, visit, offers[0].id)
	_check_stale_requests(state.visit_id, old_visit, offers[0].id)

	# Quotes and reads are detached from the caller and from the service.
	var detached_offers: Array = offers.duplicate(true)
	var detached_party: Array = party.duplicate()
	var detached := RunPatchStallVisit.new("node_4", detached_party, deck.duplicate(), owned.duplicate(), gold, detached_offers)
	var detached_state := detached.read_state()
	var detached_quote := detached.quote()
	detached_party[0] = "intruder"
	detached_offers[0].price = 0
	var read := detached.read_state()
	read.snapshot.party_ids.clear()
	read.snapshot.gold = 0
	var read_quote := detached.quote()
	read_quote.offers[0].sold = true
	read_quote.offers.pop_back()
	read_quote.decisions.clear()
	_check(detached.read_state() == detached_state and detached.quote() == detached_quote,
		"four-hero caller data and returned reads are detached")

	# AC3: forged, stale, wrong node, unoffered and unaffordable attempts change nothing.
	var snapshot: Dictionary = state.snapshot
	var bad_snapshot := snapshot.duplicate(true)
	bad_snapshot.gold += 1
	var short_party_snapshot := snapshot.duplicate(true)
	short_party_snapshot.party_ids = party.slice(0, 3)
	_check(not visit.buy_patch(offers[0].id, "wrong_visit", "node_4", snapshot).ok, "four-hero wrong visit refused")
	_check(not visit.buy_patch(offers[0].id, state.visit_id, "wrong_node", snapshot).ok, "four-hero wrong node refused")
	_check(not visit.buy_patch(offers[0].id, state.visit_id, "node_4", bad_snapshot).ok, "four-hero mutated gold snapshot refused")
	_check(not visit.buy_patch(offers[0].id, state.visit_id, "node_4", short_party_snapshot).ok, "four-hero truncated party snapshot refused")
	_check(not visit.buy_patch("forged_id", state.visit_id, "node_4", snapshot).ok, "four-hero forged patch refused")
	_check(not visit.buy_patch("", state.visit_id, "node_4", snapshot).ok and not visit.buy_patch(7, state.visit_id, "node_4", snapshot).ok,
		"four-hero blank and non-string patch refused")
	_check(not visit.leave("wrong_visit", "node_4", snapshot).ok and not visit.leave(state.visit_id, "wrong_node", snapshot).ok
		and not visit.leave(state.visit_id, "node_4", bad_snapshot).ok, "four-hero forged Leave refused")
	_check(visit.read_state() == state and visit.quote() == quote and not visit.is_consumed(),
		"four-hero refusals preserve ledger, quote and usable Leave")
	var owned_visit := RunPatchStallVisit.new("node_4", party, deck, owned + [offers[1].id], gold, offers)
	var owned_state := owned_visit.read_state()
	var owned_quote := owned_visit.quote()
	_check(owned_visit.is_valid() and owned_quote.offers[1].sold, "four-hero owned listing starts sold")
	_check(not owned_visit.buy_patch(offers[1].id, owned_state.visit_id, "node_4", owned_state.snapshot).ok
		and owned_visit.preview_purchase(offers[1].id, owned_state.visit_id, "node_4", owned_state.snapshot).is_empty(),
		"four-hero already-sold patch refused and not previewable")
	_check(owned_visit.read_state() == owned_state and owned_visit.quote() == owned_quote and not owned_visit.is_consumed(),
		"four-hero sold-listing refusal changes nothing")

	var poor_visit := RunPatchStallVisit.new("node_4", party, deck, owned, price - 1, offers)
	var poor_state := poor_visit.read_state()
	var poor_quote := poor_visit.quote()
	_check(poor_visit.is_valid() and poor_quote.offers.size() == 3, "four-hero poor visit is valid and quotes three")
	_check(not poor_visit.buy_patch(offers[0].id, poor_state.visit_id, "node_4", poor_state.snapshot).ok,
		"four-hero unaffordable buy refused")
	_check(poor_visit.preview_purchase(offers[0].id, poor_state.visit_id, "node_4", poor_state.snapshot).is_empty()
		and not poor_visit.reconcile_purchase({"kind": "trinket", "id": offers[0].id, "price": price},
			poor_state.visit_id, "node_4", poor_state.snapshot),
		"four-hero unaffordable preview and reconcile refused")
	_check(not poor_visit.is_consumed() and poor_visit.read_state() == poor_state and poor_visit.quote() == poor_quote,
		"four-hero unaffordable attempts keep ledger, quote and open Leave")
	var poor_leave := poor_visit.leave(poor_state.visit_id, "node_4", poor_state.snapshot)
	_check(poor_leave.ok and poor_leave.ledger == {"party_ids": party, "deck": [], "trinkets": owned, "gold": price - 1},
		"rejected unaffordable four-hero buy still permits one exact Leave")
	_check(not poor_visit.leave(poor_state.visit_id, "node_4", poor_state.snapshot).ok, "four-hero Leave latches once")
	_check_closed_quote(poor_visit, poor_quote, poor_state, "four-hero unaffordable then Leave")

	# AC2: one purchase spends exactly the authored quote once; Leave spends nothing.
	var leave_visit := RunPatchStallVisit.new("node_4", party, deck, owned, gold, offers)
	var leave_state := leave_visit.read_state()
	var leave_quote := leave_visit.quote()
	var leave_receipt := leave_visit.leave(leave_state.visit_id, "node_4", leave_state.snapshot)
	_check(leave_receipt.ok and leave_receipt.decision == "leave"
		and leave_receipt.ledger == {"party_ids": party, "deck": [], "trinkets": owned, "gold": gold}
		and leave_receipt.source_snapshot == leave_state.snapshot, "four-hero Leave changes no wallet or inventory")
	_check(not leave_visit.buy_patch(offers[0].id, leave_state.visit_id, "node_4", leave_state.snapshot).ok, "four-hero cannot buy after Leave")
	_check_closed_quote(leave_visit, leave_quote, leave_state, "four-hero Leave")

	var buy_receipt := visit.buy_patch(offers[0].id, state.visit_id, "node_4", snapshot)
	_check(buy_receipt.ok and buy_receipt.decision == "buy_patch"
		and buy_receipt.receipt == {"kind": "trinket", "id": offers[0].id, "price": price},
		"four-hero buy returns the exact authored receipt")
	_check(buy_receipt.ledger == {"party_ids": party, "deck": [], "trinkets": owned + [offers[0].id], "gold": gold - price},
		"four-hero buy spends the exact price once and adds only that patch")
	_check(visit.is_consumed() and visit.read_state().visit_id == state.visit_id, "four-hero buy consumes the visit")
	for offer in offers:
		_check(not visit.buy_patch(offer.id, state.visit_id, "node_4", snapshot).ok, "four-hero later buy refused " + str(offer.id))
	_check(not visit.leave(state.visit_id, "node_4", snapshot).ok, "four-hero Leave refused after buying")
	_check_closed_quote(visit, quote, state, "four-hero direct buy")
	buy_receipt.receipt.price = -1
	buy_receipt.ledger.party_ids.clear()
	buy_receipt.source_snapshot.gold = 0
	_check(visit.read_state() == {"node_id": "node_4", "visit_id": state.visit_id, "status": "closed", "snapshot": snapshot},
		"four-hero buy receipt is detached from the service")

	# The atomic paid-and-sewn route reconciles exactly once.
	var atomic := RunPatchStallVisit.new("node_4", party, deck, owned, gold, offers)
	var atomic_state := atomic.read_state()
	var atomic_quote := atomic.quote()
	var atomic_receipt := atomic.preview_purchase(offers[2].id, atomic_state.visit_id, "node_4", atomic_state.snapshot)
	_check(atomic_receipt == {"kind": "trinket", "id": offers[2].id, "price": offers[2].price}
		and atomic.read_state() == atomic_state, "four-hero preview is exact and read-only")
	_check(not atomic.reconcile_purchase({"kind": "trinket", "id": offers[2].id, "price": offers[2].price + 1},
		atomic_state.visit_id, "node_4", atomic_state.snapshot) and not atomic.is_consumed(),
		"four-hero forged receipt leaves the service open")
	_check(atomic.reconcile_purchase(atomic_receipt, atomic_state.visit_id, "node_4", atomic_state.snapshot)
		and not atomic.reconcile_purchase(atomic_receipt, atomic_state.visit_id, "node_4", atomic_state.snapshot),
		"four-hero identical receipt reconciles once and replay is refused")
	_check_closed_quote(atomic, atomic_quote, atomic_state, "four-hero atomic reconcile")

	# Cardinality is still bounded at the wrapper: two or five heroes, bad IDs and stock refuse.
	for bad_party in [party.slice(0, 2), party + ["scarecrow"],
			["warden", "warden", "tinker", "lantern_monk"], ["warden", "seamstress", "", "lantern_monk"]]:
		var bad := RunPatchStallVisit.new("node_4", bad_party, deck, owned, gold, offers)
		_check(not bad.is_valid() and bad.read_state() == {} and bad.quote() == {},
			"Patch Stall visit refuses party " + str(bad_party))
	_check(not RunPatchStallVisit.new("node_4", party, deck, owned, gold, offers.slice(0, 2)).is_valid(),
		"four-hero visit refuses two-patch stock")
	_check(rng.state == rng_state, "four-hero visits and actions consume no run RNG")
	_check(randi() == expected_global, "four-hero visits and actions consume no global RNG")


## Every terminal route (direct buy, atomic paid-and-sewn reconcile, Leave) must
## close the visit without erasing its authentic source, and must stop
## advertising both the three priced patches and the two decisions.
func _check_closed_quote(visit: RunPatchStallVisit, open_quote: Dictionary, source: Dictionary, label: String) -> void:
	_check(open_quote.offers.size() == 3 and open_quote.decisions == ["buy_patch", "leave"],
		label + " fixture quoted a genuine open decision")
	_check(visit.is_valid() and visit.is_consumed(), label + " closes the one-decision visit")
	var closed_state := visit.read_state()
	_check(closed_state.status == "closed" and not closed_state.visit_id.is_empty() \
		and closed_state.node_id == source.node_id and closed_state.visit_id == source.visit_id \
		and closed_state.snapshot == source.snapshot,
		label + " keeps an authentic valid closed identity and source")
	var closed_quote := visit.quote()
	_check(closed_quote.get("offers") is Array and closed_quote.offers.is_empty() \
		and closed_quote.get("decisions") is Array and closed_quote.decisions.is_empty(),
		label + " advertises neither stock nor decisions")
	_check(closed_quote != open_quote and not open_quote.offers.is_empty(),
		label + " cannot keep advertising the consumed three-offer quote")
	_check(visit.quote() == closed_quote and visit.read_state() == closed_state,
		label + " closed quote and identity are stable on repeated reads")


func _check_stale_requests(old_id: String, current: RunPatchStallVisit, patch_id: String) -> void:
	var before := current.read_state()
	var stock := current.quote()
	_check(current.is_valid() and not current.is_consumed() and old_id != before.visit_id,
		"stale request fixture is a distinct open visit")
	var receipt := current.preview_purchase(patch_id, before.visit_id, before.node_id, before.snapshot)
	_check(not receipt.is_empty(), "stale request fixture has an authentic affordable receipt")
	_check(not current.buy_patch(patch_id, old_id, before.node_id, before.snapshot).ok,
		"old visit cannot buy from identical-source visit")
	_check(current.read_state() == before and current.quote() == stock, "stale buy preserves state and stock")
	_check(not current.leave(old_id, before.node_id, before.snapshot).ok,
		"old visit cannot Leave identical-source visit")
	_check(current.read_state() == before and current.quote() == stock, "stale Leave preserves state and stock")
	_check(current.preview_purchase(patch_id, old_id, before.node_id, before.snapshot).is_empty(),
		"old visit cannot preview identical-source visit")
	_check(current.read_state() == before and current.quote() == stock, "stale preview preserves state and stock")
	_check(not current.reconcile_purchase(receipt, old_id, before.node_id, before.snapshot),
		"old visit cannot reconcile authentic receipt on identical-source visit")
	_check(current.read_state() == before and current.quote() == stock, "stale reconcile preserves state and stock")


func _authored_price(authored: Dictionary, id: String) -> int:
	for entry in authored.trinkets:
		if entry.id == id:
			return int(entry.price)
	return -1


func _has_card_keys(value: Variant) -> bool:
	var text := var_to_str(value)
	for banned in ["deck", "card", "hand", "energy"]:
		if text.contains(banned):
			return true
	return false


## Opt-in card-free Stitched factory: named authored patches, no deck argument.
func _run_open_stitched() -> void:
	seed(7741)
	var expected_global := randi()
	seed(7741)
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
	var ids := ["quilted_coat", "button_eye", "pincushion_arm"]
	var offers: Array = []
	for id in ids:
		var price := _authored_price(authored, id)
		_check(price == 100, "authored price for " + id)
		offers.append({"id": id, "price": price})
	_check(_authored_price(authored, "stitched_badge") > 0 and _authored_price(authored, "spare_spool") > 0,
		"earlier authored entries remain available")
	var party := ["warden", "seamstress", "tinker", "lantern_monk"]
	var owned := ["stitched_badge"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var rng_state := rng.state

	var visit := RunPatchStallVisit.open_stitched("node_s", party, owned, 150, offers)
	var twin := RunPatchStallVisit.open_stitched("node_s", party, owned, 150, offers)
	_check(visit.is_valid() and twin.is_valid(), "open_stitched opens")
	var state := visit.read_state()
	_check(state.snapshot == {"party_ids": party, "owned_patch_ids": owned, "gold": 150}, "stitched snapshot is card-free")
	_check(state.visit_id != twin.read_state().visit_id, "stitched visits have distinct identities")
	var quote := visit.quote()
	_check(quote == {"offers": [
			{"id": "quilted_coat", "price": 100, "sold": false, "can_buy": true, "blocked": ""},
			{"id": "button_eye", "price": 100, "sold": false, "can_buy": true, "blocked": ""},
			{"id": "pincushion_arm", "price": 100, "sold": false, "can_buy": true, "blocked": ""}],
		"decisions": ["buy_patch", "leave"]}, "stitched quote is three authored patches plus Buy Patch/Leave")
	# Detached projection: mutating a returned quote never reaches the service.
	var detached_quote := visit.quote()
	detached_quote.offers[0].can_buy = false
	detached_quote.offers[0].blocked = "forged"
	detached_quote.offers.pop_back()
	detached_quote.decisions.clear()
	_check(visit.quote() == quote, "stitched quote rows are detached from the service")
	_check(not _has_card_keys(state) and not _has_card_keys(quote), "stitched state and quote have no deck/card/hand/energy")

	# AC3 rejections.
	var bad_snap: Dictionary = state.snapshot.duplicate(true)
	bad_snap.gold = 151
	_check(not visit.buy_patch("quilted_coat", "x", "node_s", state.snapshot).ok, "stitched wrong visit refused")
	_check(not visit.buy_patch("quilted_coat", state.visit_id, "other", state.snapshot).ok, "stitched wrong node refused")
	_check(not visit.buy_patch("quilted_coat", state.visit_id, "node_s", bad_snap).ok, "stitched stale snapshot refused")
	_check(not visit.buy_patch("forged", state.visit_id, "node_s", state.snapshot).ok, "stitched forged offer refused")
	_check(not visit.buy_patch("quilted_coat", twin.read_state().visit_id, "node_s", state.snapshot).ok, "stitched cross-visit refused")
	_check(not visit.leave(twin.read_state().visit_id, "node_s", state.snapshot).ok, "stitched cross-visit Leave refused")
	_check(visit.read_state() == state and visit.quote() == quote and not visit.is_consumed(), "stitched refusals change nothing")
	var bad_inputs := [
		RunPatchStallVisit.open_stitched("", party, owned, 150, offers),
		RunPatchStallVisit.open_stitched("n", party.slice(0, 3), owned, 150, offers),
		RunPatchStallVisit.open_stitched("n", party + ["scarecrow"], owned, 150, offers),
		RunPatchStallVisit.open_stitched("n", ["warden", "warden", "tinker", "lantern_monk"], owned, 150, offers),
		RunPatchStallVisit.open_stitched("n", party, owned, -1, offers),
		RunPatchStallVisit.open_stitched("n", party, owned, 150.0, offers),
		RunPatchStallVisit.open_stitched("n", party, owned, 150, offers.slice(0, 2)),
		RunPatchStallVisit.open_stitched("n", party, owned, 150, [offers[0], offers[0], offers[1]]),
		RunPatchStallVisit.open_stitched("n", party, owned, 150, [offers[0], offers[1], {"id": "pincushion_arm", "price": 0}]),
		RunPatchStallVisit.open_stitched("n", party, ["quilted_coat", "quilted_coat"], 150, offers),
		RunPatchStallVisit.open_stitched("n", "party", owned, 150, offers)]
	for bad in bad_inputs:
		_check(not bad.is_valid() and bad.read_state() == {} and bad.quote() == {}, "invalid stitched open refused")

	# Already-owned and unaffordable stock.
	var owned_visit := RunPatchStallVisit.open_stitched("node_s", party, ["button_eye"], 150, offers)
	var owned_state := owned_visit.read_state()
	_check(not owned_visit.buy_patch("button_eye", owned_state.visit_id, "node_s", owned_state.snapshot).ok
		and owned_visit.preview_purchase("button_eye", owned_state.visit_id, "node_s", owned_state.snapshot).is_empty(),
		"stitched owned patch unavailable")
	var poor := RunPatchStallVisit.open_stitched("node_s", party, owned, 99, offers)
	var poor_state := poor.read_state()
	_check(not poor.buy_patch("quilted_coat", poor_state.visit_id, "node_s", poor_state.snapshot).ok
		and poor.read_state() == poor_state, "stitched unaffordable buy refused")
	var poor_leave := poor.leave(poor_state.visit_id, "node_s", poor_state.snapshot)
	_check(poor_leave.ok and poor_leave.ledger == {"party_ids": party, "owned_patch_ids": owned, "gold": 99}
		and not _has_card_keys(poor_leave), "refused buy still permits a card-free Leave")

	# AC2: each named patch buys once for exactly 100, no equip, then closes.
	for id in ids:
		var v := RunPatchStallVisit.open_stitched("node_s", party, owned, 150, offers)
		var s := v.read_state()
		var q := v.quote()
		var r := v.buy_patch(id, s.visit_id, "node_s", s.snapshot)
		_check(r.ok and r.decision == "buy_patch" and r.receipt == {"kind": "trinket", "id": id, "price": 100},
			"stitched buy receipt " + id)
		_check(r.ledger == {"party_ids": party, "owned_patch_ids": owned + [id], "gold": 50},
			"stitched buy leaves 50 gold and adds only " + id)
		_check(r.source_snapshot == s.snapshot and not _has_card_keys(r), "stitched receipt is card-free with source snapshot")
		_check(v.is_consumed() and not v.buy_patch(id, s.visit_id, "node_s", s.snapshot).ok
			and not v.leave(s.visit_id, "node_s", s.snapshot).ok, "stitched buy closes and refuses replay")
		_check_closed_quote(v, q, s, "stitched buy " + id)
		r.ledger.party_ids.clear()
		_check(v.read_state().snapshot == s.snapshot, "stitched receipt detached")
	var lv := RunPatchStallVisit.open_stitched("node_s", party, owned, 150, offers)
	var ls := lv.read_state()
	var lq := lv.quote()
	var lr := lv.leave(ls.visit_id, "node_s", ls.snapshot)
	_check(lr.ok and lr.decision == "leave" and lr.ledger == {"party_ids": party, "owned_patch_ids": owned, "gold": 150}
		and not _has_card_keys(lr), "stitched Leave leaves gold and inventory unchanged")
	_check(not lv.leave(ls.visit_id, "node_s", ls.snapshot).ok, "stitched Leave latches")
	_check_closed_quote(lv, lq, ls, "stitched Leave")

	# Decision gating: Buy Patch only while an unsold offer is affordable (real authored 100-gold rows).
	_check_stitched_decision_gating(authored, party)

	# AC4: preview then reconcile exactly once.
	var av := RunPatchStallVisit.open_stitched("node_s", party, owned, 150, offers)
	var as_ := av.read_state()
	var aq := av.quote()
	var pre := av.preview_purchase("button_eye", as_.visit_id, "node_s", as_.snapshot)
	_check(pre == {"kind": "trinket", "id": "button_eye", "price": 100} and av.read_state() == as_, "stitched preview exact and read-only")
	for forged in [{}, {"kind": "card", "id": "button_eye", "price": 100}, {"kind": "trinket", "id": "button_eye", "price": 99},
			{"kind": "trinket", "id": "quilted_coat", "price": 100, "x": 1}, {"kind": "trinket", "id": "nope", "price": 100}]:
		_check(not av.reconcile_purchase(forged, as_.visit_id, "node_s", as_.snapshot) and not av.is_consumed(),
			"stitched forged receipt refused")
	_check(not av.reconcile_purchase(pre, as_.visit_id, "node_s", bad_snap), "stitched stale reconcile refused")
	_check(av.reconcile_purchase(pre, as_.visit_id, "node_s", as_.snapshot)
		and not av.reconcile_purchase(pre, as_.visit_id, "node_s", as_.snapshot), "stitched reconcile once, no replay")
	_check(av.read_state().snapshot == as_.snapshot, "reconcile does not debit the source snapshot")
	_check_closed_quote(av, aq, as_, "stitched reconcile")

	_check(rng.state == rng_state and randi() == expected_global, "stitched service draws no global or run RNG")


## Stitched quote advertises Buy Patch only when some offered patch is unsold and
## affordable; the three priced rows (and sold flags) are always kept.
func _check_stitched_decision_gating(authored: Dictionary, party: Array) -> void:
	var ids := ["stitched_badge", "button_eye", "quilted_coat"]
	var offers: Array = []
	for id in ids:
		var price := _authored_price(authored, id)
		_check(price == 100, "gating fixture authored price " + id)
		offers.append({"id": id, "price": price})

	# Mixed: two owned (sold) beside one genuinely purchasable offer, exactly 100 gold.
	var mixed_owned := ["stitched_badge", "button_eye"]
	var mixed := RunPatchStallVisit.open_stitched("node_g", party, mixed_owned, 100, offers)
	_check(mixed.is_valid(), "mixed gating visit opens")
	var mixed_state := mixed.read_state()
	var mixed_quote := mixed.quote()
	_check(mixed_quote == {"offers": [
			{"id": "stitched_badge", "price": 100, "sold": true, "can_buy": false, "blocked": "already owned"},
			{"id": "button_eye", "price": 100, "sold": true, "can_buy": false, "blocked": "already owned"},
			{"id": "quilted_coat", "price": 100, "sold": false, "can_buy": true, "blocked": ""}],
		"decisions": ["buy_patch", "leave"]}, "mixed owned/unowned exact-100 quote keeps three rows and Buy Patch")
	for sold_id in mixed_owned:
		_check(not mixed.buy_patch(sold_id, mixed_state.visit_id, "node_g", mixed_state.snapshot).ok
			and mixed.preview_purchase(sold_id, mixed_state.visit_id, "node_g", mixed_state.snapshot).is_empty(),
			"owned patch refused and not previewable " + sold_id)
	_check(mixed.read_state() == mixed_state and mixed.quote() == mixed_quote and not mixed.is_consumed(),
		"rejected owned buys change nothing")
	var buy := mixed.buy_patch("quilted_coat", mixed_state.visit_id, "node_g", mixed_state.snapshot)
	_check(buy.ok and buy.receipt == {"kind": "trinket", "id": "quilted_coat", "price": 100}
		and buy.ledger == {"party_ids": party, "owned_patch_ids": mixed_owned + ["quilted_coat"], "gold": 0},
		"exact-100 buy spends exactly 100 and adds only the unsold patch")
	_check(mixed.is_consumed() and not mixed.buy_patch("quilted_coat", mixed_state.visit_id, "node_g", mixed_state.snapshot).ok
		and not mixed.leave(mixed_state.visit_id, "node_g", mixed_state.snapshot).ok,
		"purchase closes the visit and refuses replay and Leave")
	var mixed_closed := mixed.quote()
	_check(mixed_closed == {"offers": [], "decisions": []}, "closed mixed quote is actionless")

	# 99 gold against three 100-gold offers: rows kept, only Leave.
	var poor := RunPatchStallVisit.open_stitched("node_g", party, [], 99, offers)
	var poor_state := poor.read_state()
	var poor_quote := poor.quote()
	_check(poor.is_valid() and poor_quote == {"offers": [
			{"id": "stitched_badge", "price": 100, "sold": false, "can_buy": false, "blocked": "not enough gold"},
			{"id": "button_eye", "price": 100, "sold": false, "can_buy": false, "blocked": "not enough gold"},
			{"id": "quilted_coat", "price": 100, "sold": false, "can_buy": false, "blocked": "not enough gold"}],
		"decisions": ["leave"]}, "99-gold quote keeps three priced rows but only Leave")
	for id in ids:
		_check(not poor.buy_patch(id, poor_state.visit_id, "node_g", poor_state.snapshot).ok
			and poor.preview_purchase(id, poor_state.visit_id, "node_g", poor_state.snapshot).is_empty(),
			"99-gold buy refused and preview empty " + id)
	_check(poor.read_state() == poor_state and poor.quote() == poor_quote and not poor.is_consumed(),
		"99-gold refusals are nonmutating")
	var poor_leave := poor.leave(poor_state.visit_id, "node_g", poor_state.snapshot)
	_check(poor_leave.ok and poor_leave.ledger == {"party_ids": party, "owned_patch_ids": [], "gold": 99}
		and poor.is_consumed() and not poor.leave(poor_state.visit_id, "node_g", poor_state.snapshot).ok
		and poor.quote() == {"offers": [], "decisions": []}, "99-gold Leave closes once and quote is actionless")

	# All offered patches already owned with ample gold: rows flagged sold, only Leave.
	var all_owned := RunPatchStallVisit.open_stitched("node_g", party, ids.duplicate(), 500, offers)
	var all_state := all_owned.read_state()
	var all_quote := all_owned.quote()
	_check(all_owned.is_valid() and all_quote == {"offers": [
			{"id": "stitched_badge", "price": 100, "sold": true, "can_buy": false, "blocked": "already owned"},
			{"id": "button_eye", "price": 100, "sold": true, "can_buy": false, "blocked": "already owned"},
			{"id": "quilted_coat", "price": 100, "sold": true, "can_buy": false, "blocked": "already owned"}],
		"decisions": ["leave"]}, "all-owned quote keeps sold rows but only Leave")
	for id in ids:
		_check(not all_owned.buy_patch(id, all_state.visit_id, "node_g", all_state.snapshot).ok
			and all_owned.preview_purchase(id, all_state.visit_id, "node_g", all_state.snapshot).is_empty(),
			"all-owned buy refused and preview empty " + id)
	_check(all_owned.read_state() == all_state and all_owned.quote() == all_quote and not all_owned.is_consumed(),
		"all-owned refusals are nonmutating")
	var all_leave := all_owned.leave(all_state.visit_id, "node_g", all_state.snapshot)
	_check(all_leave.ok and all_leave.ledger == {"party_ids": party, "owned_patch_ids": ids, "gold": 500}
		and all_owned.is_consumed() and not all_owned.leave(all_state.visit_id, "node_g", all_state.snapshot).ok,
		"all-owned Leave closes once without spending")

	# Mixed price list: an unsold offer above the wallet does not hide a cheaper affordable one.
	var tiered := [{"id": "stitched_badge", "price": 100}, {"id": "button_eye", "price": 60}, {"id": "quilted_coat", "price": 100}]
	var tiered_visit := RunPatchStallVisit.open_stitched("node_g", party, [], 70, tiered)
	_check(tiered_visit.quote().decisions == ["buy_patch", "leave"] and tiered_visit.quote().offers.size() == 3,
		"any affordable unsold offer keeps Buy Patch")
	var tiered_owned := RunPatchStallVisit.open_stitched("node_g", party, ["button_eye"], 70, tiered)
	_check(tiered_owned.quote().decisions == ["leave"] and tiered_owned.quote().offers.size() == 3,
		"owned cheap offer plus unaffordable others leaves only Leave")

	# Per-row availability with a sold, an unaffordable unsold and an affordable
	# unsold patch together (test-only fixture price of 60; no production balance).
	var avail := [{"id": "stitched_badge", "price": 100}, {"id": "quilted_coat", "price": 100}, {"id": "button_eye", "price": 60}]
	var avail_visit := RunPatchStallVisit.open_stitched("node_g", party, ["stitched_badge"], 70, avail)
	var avail_state := avail_visit.read_state()
	var avail_quote := avail_visit.quote()
	_check(avail_visit.is_valid() and avail_quote == {"offers": [
			{"id": "stitched_badge", "price": 100, "sold": true, "can_buy": false, "blocked": "already owned"},
			{"id": "quilted_coat", "price": 100, "sold": false, "can_buy": false, "blocked": "not enough gold"},
			{"id": "button_eye", "price": 60, "sold": false, "can_buy": true, "blocked": ""}],
		"decisions": ["buy_patch", "leave"]}, "mixed sold/unaffordable/affordable rows keep order and flags")
	_check(avail_quote.offers.size() == 3 and avail_quote.offers[0].can_buy is bool and avail_quote.offers[0].blocked is String,
		"availability fields are a bool and a string on each row")
	_check(not avail_visit.buy_patch("stitched_badge", avail_state.visit_id, "node_g", avail_state.snapshot).ok
		and not avail_visit.buy_patch("quilted_coat", avail_state.visit_id, "node_g", avail_state.snapshot).ok
		and avail_visit.preview_purchase("stitched_badge", avail_state.visit_id, "node_g", avail_state.snapshot).is_empty()
		and avail_visit.preview_purchase("quilted_coat", avail_state.visit_id, "node_g", avail_state.snapshot).is_empty(),
		"blocked rows are refused by the authoritative purchase and preview")
	_check(avail_visit.read_state() == avail_state and avail_visit.quote() == avail_quote and not avail_visit.is_consumed(),
		"blocked attempts leave the mixed quote unchanged")
	_check(avail_visit.preview_purchase("button_eye", avail_state.visit_id, "node_g", avail_state.snapshot)
		== {"kind": "trinket", "id": "button_eye", "price": 60}, "the buyable row previews at its prepared price")
	var avail_buy := avail_visit.buy_patch("button_eye", avail_state.visit_id, "node_g", avail_state.snapshot)
	_check(avail_buy.ok and avail_buy.ledger == {"party_ids": party, "owned_patch_ids": ["stitched_badge", "button_eye"], "gold": 10}
		and avail_visit.quote() == {"offers": [], "decisions": []}, "buyable row sells once at 60 and the quote closes")
	# Inclusive boundary: gold equal to the price is buyable, one less is not.
	var edge_ok := RunPatchStallVisit.open_stitched("node_g", party, [], 60, [{"id": "button_eye", "price": 60},
		{"id": "quilted_coat", "price": 100}, {"id": "stitched_badge", "price": 100}])
	var edge_low := RunPatchStallVisit.open_stitched("node_g", party, [], 59, [{"id": "button_eye", "price": 60},
		{"id": "quilted_coat", "price": 100}, {"id": "stitched_badge", "price": 100}])
	_check(edge_ok.quote().offers[0].can_buy == true and edge_ok.quote().offers[0].blocked == ""
		and edge_ok.quote().offers[1].blocked == "not enough gold" and edge_ok.quote().decisions == ["buy_patch", "leave"],
		"price equal to gold is buyable with an empty reason")
	_check(edge_low.quote().offers[0].can_buy == false and edge_low.quote().offers[0].blocked == "not enough gold"
		and edge_low.quote().decisions == ["leave"], "one gold short is blocked and only Leave remains")
	# Sold beats price: an owned row that is also unaffordable reads "already owned".
	var sold_poor := RunPatchStallVisit.open_stitched("node_g", party, ["quilted_coat"], 0, offers)
	_check(sold_poor.quote().offers[2].blocked == "already owned" and sold_poor.quote().offers[0].blocked == "not enough gold"
		and sold_poor.quote().decisions == ["leave"], "sold takes precedence over price and zero gold only leaves")
