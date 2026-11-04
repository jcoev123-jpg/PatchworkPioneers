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
