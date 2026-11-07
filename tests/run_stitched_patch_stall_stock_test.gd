extends SceneTree
## Card-free Stitched Patch Stall sampler: deterministic three-offer stock from the
## Stitched-only patch source, driven through the real four-hero visit service.

const SOURCE := "res://data/shop/stitched_patch_offers.json"
const COAT_SOURCE := "res://data/patches/m04_coat_patches.json"
const COATS := {
	"quilted_coat": 6, "padded_vest": 4, "double_quilt_coat": 8, "scrap_lined_vest": 3,
	"wool_patch_cloak": 5, "chain_stitched_coat": 7, "reinforced_patchcoat": 9,
	"thick_felt_mantle": 10,
}
const PARTY := ["warden", "seamstress", "tinker", "yarn_ranger"]
const NODE := "patch_stall_node"

var _checks := 0
var _failures := []


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("run_stitched_patch_stall_stock_test: PASS (", _checks, " checks)")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("run_stitched_patch_stall_stock_test: FAIL (", _checks, " checks)")
		quit(1)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _source_prices() -> Dictionary:
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var prices := {}
	if document is Dictionary and document.get("trinkets") is Array:
		for item in document.trinkets:
			prices[item.id] = int(item.price)
	return prices


func _foreign_ids() -> Dictionary:
	# Card-era / rare / Heirloom / starter identities that must never be stocked.
	var blocked := {"stitched_badge": true, "spare_spool": true}
	for id in RunAuthoredPatchDefinitions.HEIRLOOM_IDS:
		blocked[id] = true
	for path in ["res://data/patches/mpw_synergy_patches.json",
			"res://data/patches/mpw_heirloom_patches.json",
			"res://data/patches/initial_patch_slots.json"]:
		var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if records is Array:
			for record in records:
				if record is Dictionary and record.get("id") is String:
					blocked[record.id] = true
	return blocked


func _others(excluded: Array) -> Array:
	var owned: Array = []
	var ids: Array = COATS.keys()
	ids.sort()
	for id in ids:
		if not excluded.has(id):
			owned.append(id)
	return owned


func _ids(offers: Array) -> Array:
	var ids: Array = []
	for offer in offers:
		ids.append(offer.id)
	return ids


func _run() -> void:
	var prices := _source_prices()
	var coat_records: Variant = JSON.parse_string(FileAccess.get_file_as_string(COAT_SOURCE))
	_check(coat_records is Array and not coat_records.is_empty(), "coat power source loads")
	var coat_slots := {}
	if coat_records is Array:
		for record in coat_records:
			coat_slots[record.id] = record.slot
	for id in COATS:
		_check(prices.has(id) and prices[id] == 100, "named coat %s is authored at 100 gold" % id)
		_check(coat_slots.get(id) == "COAT", "named coat %s is a COAT power" % id)
	_check(not prices.is_empty(), "Stitched patch source is non-empty")

	_check_membership_and_determinism(prices)
	_check_every_coat_eligible()
	_check_scarce(["quilted_coat"], "one")
	_check_scarce(["padded_vest", "thick_felt_mantle"], "two")
	_check_all_owned()
	_check_bad_inputs()
	_check_visit_failures()


func _check_membership_and_determinism(prices: Dictionary) -> void:
	var blocked := _foreign_ids()
	for seed_value in [1, 7, 42, 1337, 90210]:
		var rng := _rng(seed_value)
		var before := rng.state
		var owned: Array = []
		var result := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(rng, owned)
		_check(result.get("ok") == true and result.get("offers") is Array, "seed %d samples" % seed_value)
		if result.get("ok") != true:
			continue
		var offers: Array = result.offers
		_check(offers.size() == 3 and _ids(offers).size() == 3, "seed %d draws three rows" % seed_value)
		var seen := {}
		for offer in offers:
			_check(offer.size() == 2 and offer.get("id") is String and typeof(offer.get("price")) == TYPE_INT,
				"seed %d row is a strict id/price pair" % seed_value)
			_check(prices.has(offer.id) and offer.price == prices[offer.id] and offer.price > 0,
				"seed %d row %s carries its authored price" % [seed_value, offer.id])
			_check(not blocked.has(offer.id), "seed %d row %s is not card-era/rare/Heirloom" % [seed_value, offer.id])
			_check(not seen.has(offer.id), "seed %d rows are distinct" % seed_value)
			seen[offer.id] = true
		_check(rng.state != before, "seed %d consumes the supplied RNG" % seed_value)
		_check(owned.is_empty(), "seed %d leaves the caller's owned IDs untouched" % seed_value)

		var rng_b := _rng(seed_value)
		var again := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(rng_b, [])
		_check(again == result and rng_b.state == rng.state,
			"seed %d: equal seed and inputs give equal offers and final RNG state" % seed_value)

	var owned_a := ["quilted_coat", "padded_vest"]
	var owned_b := ["padded_vest", "quilted_coat"]
	var rng_a := _rng(555)
	var rng_c := _rng(555)
	var first := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(rng_a, owned_a)
	var second := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(rng_c, owned_b)
	_check(first.get("ok") == true and first == second and rng_a.state == rng_c.state,
		"owned-ID input order does not change offers or RNG use")
	if first.get("ok") == true:
		for id in _ids(first.offers):
			_check(not owned_a.has(id), "partial ledger keeps owned %s out of three-unowned stock" % id)
	_check(owned_a == ["quilted_coat", "padded_vest"], "owned input is not mutated by a sample")


func _check_every_coat_eligible() -> void:
	# Each named coat, when the only unowned one, is offered once at 100 gold.
	for id in COATS:
		var owned := _others([id])
		var snapshot := owned.duplicate(true)
		var result := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(_rng(31), owned)
		_check(result.get("ok") == true, "%s remains eligible when unowned" % id)
		if result.get("ok") != true:
			continue
		_check(_ids(result.offers).count(id) == 1, "%s appears exactly once as the sole unowned coat" % id)
		for offer in result.offers:
			if offer.id == id:
				_check(offer.price == 100, "%s is offered at the 100-gold quote" % id)
		_check(owned == snapshot, "%s fixture owned list is not mutated" % id)


func _check_scarce(unowned: Array, label: String) -> void:
	var owned := _others(unowned)
	var snapshot := owned.duplicate(true)
	var rng := _rng(2026)
	var result := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(rng, owned)
	_check(result.get("ok") == true, "%s remaining coat(s): sampler succeeds" % label)
	if result.get("ok") != true:
		return
	var offers: Array = result.offers
	var ids := _ids(offers)
	_check(offers.size() == 3 and ids.size() == 3, "%s remaining: three rows" % label)
	var distinct := {}
	for id in ids:
		distinct[id] = true
	_check(distinct.size() == 3, "%s remaining: rows are distinct" % label)
	for id in unowned:
		_check(ids.count(id) == 1, "%s remaining: unowned %s appears once" % [label, id])
	for offer in offers:
		_check(offer.price == 100, "%s remaining: %s keeps its honest 100 price" % [label, offer.id])
		if not unowned.has(offer.id):
			_check(owned.has(offer.id), "%s remaining: filler %s is truly owned" % [label, offer.id])
	_check(owned == snapshot, "%s remaining: caller's owned IDs not mutated" % label)

	var gold := 150
	var visit := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), owned, gold, offers)
	_check(visit.is_valid(), "%s remaining: real four-hero visit opens" % label)
	if not visit.is_valid():
		return
	var state := visit.read_state()
	var quote := visit.quote()
	_check(quote.offers.size() == 3 and quote.decisions == ["buy_patch", "leave"],
		"%s remaining: quote shows three rows with buy and leave" % label)
	var buyable := 0
	for row in quote.offers:
		if unowned.has(row.id):
			buyable += 1
			_check(row.sold == false and row.can_buy == true and row.blocked == "",
				"%s remaining: unowned %s is buyable" % [label, row.id])
		else:
			_check(row.sold == true and row.can_buy == false and row.blocked == "already owned",
				"%s remaining: filler %s is SOLD and blocked" % [label, row.id])
	_check(buyable == unowned.size(), "%s remaining: only unowned rows are buyable" % label)

	# SOLD fillers cannot be bought and leave the visit untouched.
	for row in quote.offers:
		if not unowned.has(row.id):
			var refused := visit.buy_patch(row.id, state.visit_id, state.node_id, state.snapshot)
			_check(refused.get("ok") != true, "%s remaining: SOLD filler %s buy refused" % [label, row.id])
			_check(visit.read_state() == state and not visit.is_consumed(),
				"%s remaining: refused filler buy leaves visit available" % label)

	# One authentic 100-gold purchase of the real unowned patch, exactly once.
	var target: String = unowned[0]
	var bought := visit.buy_patch(target, state.visit_id, state.node_id, state.snapshot)
	_check(bought.get("ok") == true and bought.decision == "buy_patch", "%s remaining: real purchase succeeds" % label)
	if bought.get("ok") == true:
		_check(bought.receipt == {"kind": "trinket", "id": target, "price": 100},
			"%s remaining: receipt is the authentic 100-gold quote" % label)
		_check(bought.ledger.gold == gold - 100 and bought.ledger.owned_patch_ids.count(target) == 1,
			"%s remaining: charged once and owns the patch once" % label)
		_check(bought.ledger.party_ids == PARTY and not bought.ledger.has("deck"),
			"%s remaining: ledger is card-free with the four heroes" % label)
	_check(visit.is_consumed(), "%s remaining: visit consumed" % label)
	var closed_state := visit.read_state()
	_check(visit.buy_patch(target, state.visit_id, state.node_id, state.snapshot).get("ok") != true,
		"%s remaining: replayed buy refused" % label)
	_check(visit.leave(state.visit_id, state.node_id, state.snapshot).get("ok") != true,
		"%s remaining: leave after purchase refused" % label)
	_check(visit.quote().offers == [] and visit.quote().decisions == [] and visit.read_state() == closed_state,
		"%s remaining: consumed visit advertises nothing and stays inert" % label)
	_check(owned == snapshot, "%s remaining: visit left caller's owned IDs untouched" % label)


func _check_all_owned() -> void:
	var owned: Array = COATS.keys()
	var snapshot := owned.duplicate(true)
	var rng := _rng(99)
	var before := rng.state
	var result := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(rng, owned)
	_check(result == {"ok": false}, "all authored patches owned: no-offer refusal")
	_check(rng.state == before, "all-owned refusal does not advance the RNG")
	_check(owned == snapshot, "all-owned refusal does not mutate owned IDs")


func _check_bad_inputs() -> void:
	var bad_rngs: Array = [null, 5, "rng", {}, RefCounted.new()]
	for bad in bad_rngs:
		var owned := ["quilted_coat"]
		var result := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(bad, owned)
		_check(result == {"ok": false}, "bad RNG %s refused" % str(bad))
		_check(owned == ["quilted_coat"], "bad RNG leaves owned input untouched")

	var bad_owned: Array = [
		null, "quilted_coat", 7, {"id": "quilted_coat"},
		[1], [null], [""], ["   "], ["quilted_coat", 2], [["quilted_coat"]],
		["quilted_coat", "quilted_coat"], ["padded_vest", "quilted_coat", "padded_vest"],
	]
	for bad in bad_owned:
		var rng := _rng(808)
		var before := rng.state
		var copy: Variant = bad.duplicate(true) if (bad is Array or bad is Dictionary) else bad
		var result := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(rng, bad)
		_check(result == {"ok": false}, "bad owned input %s refused" % str(bad))
		_check(rng.state == before, "bad owned input %s does not consume RNG" % str(bad))
		_check(typeof(bad) == typeof(copy) and bad == copy, "bad owned input %s not mutated" % str(bad))


func _check_visit_failures() -> void:
	var owned := ["quilted_coat"]
	var sample := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(_rng(4), owned)
	_check(sample.get("ok") == true, "failure fixture samples")
	if sample.get("ok") != true:
		return
	var offers: Array = sample.offers
	var target: String = offers[0].id

	# Stale / wrong-node / wrong-snapshot / wrong-type purchases are inert.
	var visit := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), owned, 250, offers)
	_check(visit.is_valid(), "failure fixture visit opens")
	var state := visit.read_state()
	var quote := visit.quote()
	var bad_snapshot: Dictionary = state.snapshot.duplicate(true)
	bad_snapshot.gold = 9999
	var stale_snapshot: Dictionary = state.snapshot.duplicate(true)
	stale_snapshot.owned_patch_ids = []
	var attempts: Array = [
		["wrong visit id", target, "stale_visit", state.node_id, state.snapshot],
		["wrong node", target, state.visit_id, "other_node", state.snapshot],
		["inflated snapshot", target, state.visit_id, state.node_id, bad_snapshot],
		["stale snapshot", target, state.visit_id, state.node_id, stale_snapshot],
		["null snapshot", target, state.visit_id, state.node_id, null],
		["non-string patch", 5, state.visit_id, state.node_id, state.snapshot],
		["unoffered patch", "not_a_patch", state.visit_id, state.node_id, state.snapshot],
	]
	for attempt in attempts:
		var refused := visit.buy_patch(attempt[1], attempt[2], attempt[3], attempt[4])
		_check(refused.get("ok") != true, "%s purchase refused" % attempt[0])
		_check(visit.read_state() == state and visit.quote() == quote and not visit.is_consumed(),
			"%s purchase leaves the visit untouched" % attempt[0])
	# Another visit's identity never authorizes this one.
	var other := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), owned, 250, offers)
	_check(visit.buy_patch(target, other.read_state().visit_id, state.node_id, state.snapshot).get("ok") != true,
		"another visit's id cannot buy here")
	_check(visit.leave("stale_visit", state.node_id, state.snapshot).get("ok") != true
		and visit.leave(state.visit_id, "other_node", state.snapshot).get("ok") != true
		and visit.leave(state.visit_id, state.node_id, bad_snapshot).get("ok") != true,
		"stale, wrong-node and wrong-snapshot Leave refused")
	_check(visit.read_state() == state and not visit.is_consumed(), "refused Leave attempts leave the visit open")

	# Failed low-gold attempt, then free Leave and replay refusal.
	var poor := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), owned, 99, offers)
	_check(poor.is_valid(), "low-gold visit opens")
	var poor_state := poor.read_state()
	var poor_quote := poor.quote()
	var any_buyable := false
	for row in poor_quote.offers:
		any_buyable = any_buyable or row.can_buy
	_check(not any_buyable and poor_quote.decisions == ["leave"], "99 gold quotes no buyable row and only Leave")
	var short := poor.buy_patch(target, poor_state.visit_id, poor_state.node_id, poor_state.snapshot)
	_check(short.get("ok") != true, "low-gold purchase refused")
	_check(poor.read_state() == poor_state and poor.quote() == poor_quote and not poor.is_consumed(),
		"failed low-gold attempt charges nothing and leaves the visit open")
	var left := poor.leave(poor_state.visit_id, poor_state.node_id, poor_state.snapshot)
	_check(left.get("ok") == true and left.decision == "leave", "Leave is free at the Patch Stall")
	if left.get("ok") == true:
		_check(left.ledger.gold == 99 and left.ledger.owned_patch_ids == owned,
			"Leave keeps gold and owned patches unchanged")
	_check(poor.is_consumed(), "Leave closes the visit")
	_check(poor.leave(poor_state.visit_id, poor_state.node_id, poor_state.snapshot).get("ok") != true
		and poor.buy_patch(target, poor_state.visit_id, poor_state.node_id, poor_state.snapshot).get("ok") != true,
		"replayed Leave and buy after Leave refused")
	_check(poor.quote().offers == [] and owned == ["quilted_coat"], "closed visit is inert and owned input untouched")
