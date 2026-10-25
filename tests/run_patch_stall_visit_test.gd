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
	var visit := RunPatchStallVisit.new("node_1", party, deck, owned, gold, offers)
	_check(visit.is_valid(), "valid visit created")
	var state := visit.read_state()
	_check(state.node_id == "node_1" and state.visit_id == "node_1", "stable node and visit IDs")
	
	var quote := visit.quote()
	_check(quote.decisions == ["buy_patch", "leave"], "quotes exactly buy_patch and leave decisions")
	_check(quote.offers.size() == 3, "quotes exactly three distinct offers")
	
	var prices_match := true
	for offer in quote.offers:
		var found := false
		for a in authored.trinkets:
			if a.id == offer.id and int(a.price) == int(offer.price):
				found = true
				break
		if not found:
			prices_match = false
	_check(prices_match, "prices match authored initial_offers.json exactly")
	
	# AC3: Negatives and rejection
	var bad_visit := RunPatchStallVisit.new("", party, deck, owned, gold, offers)
	_check(not bad_visit.is_valid(), "empty node id rejected")
	
	var bad_offers := RunPatchStallVisit.new("node_1", party, deck, owned, gold, [])
	_check(not bad_offers.is_valid(), "empty offers rejected")
	
	var snapshot: Dictionary = state.snapshot
	var bad_snapshot := snapshot.duplicate(true)
	bad_snapshot.gold += 10
	
	_check(not visit.buy_patch(offers[0].id, "wrong_visit", "node_1", snapshot).ok, "wrong visit id rejected")
	_check(not visit.buy_patch(offers[0].id, "node_1", "wrong_node", snapshot).ok, "wrong node id rejected")
	_check(not visit.buy_patch(offers[0].id, "node_1", "node_1", bad_snapshot).ok, "mutated snapshot rejected")
	_check(not visit.buy_patch("forged_id", "node_1", "node_1", snapshot).ok, "forged patch id rejected")
	
	var broke_visit := RunPatchStallVisit.new("node_1", party, deck, owned, broke_gold, offers)
	var broke_state := broke_visit.read_state()
	_check(not broke_visit.buy_patch(offers[0].id, "node_1", "node_1", broke_state.snapshot).ok, "insufficient gold purchase rejected")
	_check(not broke_visit.is_consumed(), "failed purchase does not consume visit")
	_check(broke_visit.preview_purchase(offers[0].id, "node_1", "node_1", broke_state.snapshot).is_empty(), "unaffordable preview refuses without consuming")

	var atomic_visit := RunPatchStallVisit.new("node_1", party, deck, owned, gold, offers)
	var atomic_source := atomic_visit.read_state()
	var receipt := atomic_visit.preview_purchase(offers[0].id, "node_1", "node_1", snapshot)
	_check(receipt == {"kind": "trinket", "id": offers[0].id, "price": offers[0].price}
		and atomic_visit.read_state() == atomic_source, "preview is exact and read-only")
	for bad in [{}, {"kind": "card", "id": offers[0].id, "price": offers[0].price},
		{"kind": "trinket", "id": offers[0].id, "price": offers[0].price + 1},
		{"kind": "trinket", "id": "forged", "price": offers[0].price},
		{"kind": "trinket", "id": offers[0].id, "price": offers[0].price, "extra": true}]:
		_check(not atomic_visit.reconcile_purchase(bad, "node_1", "node_1", snapshot)
			and atomic_visit.read_state() == atomic_source, "nonidentical atomic receipt leaves service open")
	_check(not atomic_visit.reconcile_purchase(receipt, "foreign", "node_1", snapshot)
		and not atomic_visit.reconcile_purchase(receipt, "node_1", "foreign", snapshot)
		and not atomic_visit.reconcile_purchase(receipt, "node_1", "node_1", bad_snapshot), "foreign and stale reconciliation refused")
	_check(atomic_visit.reconcile_purchase(receipt, "node_1", "node_1", snapshot)
		and atomic_visit.is_consumed(), "identical atomic receipt consumes service")
	_check(not atomic_visit.reconcile_purchase(receipt, "node_1", "node_1", snapshot), "duplicate atomic receipt refused")
	
	# AC2: Successful Leave
	var leave_visit := RunPatchStallVisit.new("node_1", party, deck, owned, gold, offers)
	var leave_receipt := leave_visit.leave("node_1", "node_1", leave_visit.read_state().snapshot)
	_check(leave_receipt.ok and leave_receipt.decision == "leave", "successful leave receipt")
	_check(leave_receipt.ledger.gold == gold, "leave does not spend gold")
	_check(leave_receipt.ledger.trinkets == owned, "leave does not add patches")
	_check(leave_visit.is_consumed(), "leave closes the visit")
	_check(not leave_visit.buy_patch(offers[0].id, "node_1", "node_1", leave_visit.read_state().snapshot).ok, "cannot buy after leave")
	
	# AC2: Successful Buy
	var buy_receipt := visit.buy_patch(offers[0].id, "node_1", "node_1", snapshot)
	_check(buy_receipt.ok and buy_receipt.decision == "buy_patch", "successful buy receipt")
	_check(buy_receipt.receipt.id == offers[0].id, "receipt matches chosen patch")
	_check(buy_receipt.ledger.gold == gold - offers[0].price, "gold reduced by exact patch price")
	_check(buy_receipt.ledger.trinkets.size() == owned.size() + 1 and buy_receipt.ledger.trinkets.has(offers[0].id), "one new owned patch in ledger")
	_check(buy_receipt.ledger.deck == deck, "unchanged deck")
	_check(visit.is_consumed(), "buy closes the visit")
	_check(not visit.buy_patch(offers[1].id, "node_1", "node_1", snapshot).ok, "cannot buy second patch after closing")
	
	# AC4: Global/Run RNG isolation
	_check(rng.state == rng_state, "visit creation and actions do not consume global or run RNG")
