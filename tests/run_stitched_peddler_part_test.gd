extends SceneTree
## Design v4 S6 Stitched Peddler body-part purchase contract: one pre-approved tier-I part at a
## caller-quoted price, append-only satchel receipt, buy-or-Leave guarded by the exact node and a
## complete state snapshot, detached state and no RNG draws. Scene-free service test.

const NODE := "route-peddler-9"
const HEAD := "warden_head_helmet_rattle"
const ARMS := "warden_arms_shield_catch"
const TORSO := "warden_torso_iron_challenge"
const LEGS := "warden_legs_rim_toss"
const PRICE := 70  # test fixture only, not an approved game-wide price
const TIER_PRICE := 95  # test fixture only for the tier-II/III offers, not a new global price

var failures: Array[String] = []
var checks := 0
var catalog: Dictionary = {}


func _initialize() -> void:
	seed(515151)
	var next_draw := randi()
	seed(515151)
	var loaded := StitchedParts.load_catalog("res://data/parts/warden_parts.json")
	_check(bool(loaded.get("ok", false)), "the real Warden part catalog loads")
	catalog = loaded.get("by_id", {})
	_check(catalog.has(HEAD) and catalog.has(ARMS) and catalog.has(TORSO) and catalog.has(LEGS),
		"the named catalog entries exist")
	if catalog.has(HEAD):
		_test_admission_and_quote()
		_test_purchase_and_leave()
		_test_capacity_and_funds()
		_test_refusals_and_replay()
		_test_offer_tiers()
		_test_choice_availability()
		_test_full_ability_quotes()
	_check(randi()== next_draw, "open, quote, buy, leave and refusals draw no global RNG")
	if failures.is_empty():
		print("run_stitched_peddler_part_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_stitched_peddler_part_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _spare(id: String, slot: String, tier: int = 1, torn: bool = false) -> Dictionary:
	return {"id": id, "slot": slot, "tier": tier, "torn": torn}


func _spares(count: int) -> Array:
	var all: Array = [
		_spare(ARMS, "arms", 2, true), _spare(TORSO, "torso", 3), _spare(LEGS, "legs"),
		_spare(HEAD, "head", 2), _spare(ARMS, "arms"), _spare(TORSO, "torso", 1, true),
	]
	return all.slice(0, count)


func _open(gold: Variant = 200, satchel: Variant = [], offer: Variant = HEAD,
		price: Variant = PRICE, node: Variant = NODE, cat: Variant = null) -> RunStitchedPeddlerPart:
	var use_catalog: Variant = catalog if cat == null else cat
	return RunStitchedPeddlerPart.open_stitched(node, gold, satchel, use_catalog, offer, price)


## A refused request changes nothing and reports no charge or decision.
func _reject(visit: RunStitchedPeddlerPart, buying: bool, node: Variant, snapshot: Variant,
		label: String) -> void:
	var before := visit.read_state()
	var was_open := visit.is_open()
	var result := visit.buy(node, snapshot) if buying else visit.leave(node, snapshot)
	_check(result.get("ok", true) == false, label + ": refused")
	_check(visit.read_state() == before and visit.is_open() == was_open,
		label + ": no drift in gold, satchel or status")
	_check(result.get("decision", "x") == "" and result.get("charged_gold", 1) == 0,
		label + ": no phantom decision or charge")


## AC1: exact catalogued offer and quote in detached snapshots; malformed admissions never open.
func _test_admission_and_quote() -> void:
	var satchel := _spares(2)
	var visit := _open(120, satchel)
	_check(visit.is_valid() and visit.is_open() and not visit.is_consumed(),
		"valid node, wallet, satchel, offer and quote open the visit")
	var state := visit.read_state()
	var offer: Dictionary = state.get("offer", {})
	_check(state.get("ok") == true and state.get("node_id") == NODE and state.get("gold") == 120
		and state.get("open") == true and state.get("status") == "stitched_open"
		and state.get("satchel") == satchel,
		"read_state carries node, wallet, status and the unchanged satchel")
	_check(offer.get("id") == HEAD and offer.get("name") == "Helmet Rattle"
		and offer.get("slot") == "head" and offer.get("owner") == "warden"
		and offer.get("tier") == 1 and offer.get("torn") == false and offer.get("price") == PRICE,
		"the offer is the catalogued tier-I untorn Helmet Rattle at the caller's price")
	var quote := visit.quote()
	_check(quote.get("ok") == true and quote.get("price") == PRICE and quote.get("gold") == 120
		and quote.get("offer", {}).get("id") == HEAD and quote.get("satchel_count") == 2
		and quote.get("satchel_max") == 6 and quote.get("can_buy") == true
		and quote.get("choices") == ["buy_part", "leave"],
		"the open quote offers exactly buy and leave at the quoted price")
	var arms := _open(120, [], ARMS, 33)
	var arms_offer: Dictionary = arms.read_state().get("offer", {})
	_check(arms.is_open() and arms_offer.get("name") == "Shield Catch"
		and arms_offer.get("slot") == "arms" and arms_offer.get("price") == 33,
		"a second slot derives its name and slot from the catalog")
	# Detached state: mutating returned dictionaries cannot touch the service.
	state["gold"] = 99999
	state["offer"]["price"] = 1
	state["satchel"].append({"id": "x"})
	quote["offer"]["slot"] = "legs"
	var fresh := visit.read_state()
	_check(fresh["gold"] == 120 and fresh["offer"]["price"] == PRICE and fresh["satchel"] == satchel
		and fresh["offer"]["slot"] == "head", "mutating returned snapshots changes nothing")
	# Detached admissions: mutating the caller's inputs after opening changes nothing.
	var input_satchel := _spares(1)
	var input_catalog: Dictionary = catalog.duplicate(true)
	var admitted := _open(100, input_satchel, HEAD, PRICE, NODE, input_catalog)
	input_satchel[0]["tier"] = 3
	input_satchel.append(_spare(LEGS, "legs"))
	input_catalog[HEAD]["name"] = "Forged"
	input_catalog[HEAD]["slot"] = "legs"
	var admitted_state := admitted.read_state()
	_check(admitted_state["satchel"] == _spares(1) and admitted_state["offer"]["name"] == "Helmet Rattle"
		and admitted_state["offer"]["slot"] == "head", "admitted satchel and catalog are deep copies")
	var bought := admitted.buy(NODE, admitted_state)
	_check(bought.get("ok") == true and bought.get("part", {}).get("slot") == "head",
		"a later caller catalog mutation cannot change the purchased slot")
	# Malformed admissions never open and can neither buy nor leave.
	var bad_cases: Array = [
		{"label": "empty node", "node": ""},
		{"label": "padded node", "node": " " + NODE},
		{"label": "null node", "node": null},
		{"label": "int node", "node": 17},
		{"label": "negative gold", "gold": -1},
		{"label": "float gold", "gold": 120.0},
		{"label": "string gold", "gold": "120"},
		{"label": "null gold", "gold": null},
		{"label": "zero price", "price": 0},
		{"label": "negative price", "price": -5},
		{"label": "float price", "price": 70.0},
		{"label": "string price", "price": "70"},
		{"label": "null price", "price": null},
		{"label": "unknown offer", "offer": "no_such_part"},
		{"label": "empty offer", "offer": ""},
		{"label": "null offer", "offer": null},
		{"label": "int offer", "offer": 3},
		{"label": "null satchel", "satchel": null},
		{"label": "dictionary satchel", "satchel": {}},
		{"label": "seven spares", "satchel": _spares(6) + [_spare(LEGS, "legs")]},
		{"label": "non-dictionary record", "satchel": ["x"]},
		{"label": "unknown record id", "satchel": [_spare("ghost_part", "head")]},
		{"label": "wrong record slot", "satchel": [_spare(HEAD, "legs")]},
		{"label": "missing record slot", "satchel": [{"id": HEAD, "tier": 1, "torn": false}]},
		{"label": "tier zero", "satchel": [_spare(HEAD, "head", 0)]},
		{"label": "tier four", "satchel": [_spare(HEAD, "head", 4)]},
		{"label": "string tier", "satchel": [{"id": HEAD, "slot": "head", "tier": "1", "torn": false}]},
		{"label": "fractional tier", "satchel": [{"id": HEAD, "slot": "head", "tier": 1.5, "torn": false}]},
		{"label": "torn not bool", "satchel": [{"id": HEAD, "slot": "head", "tier": 1, "torn": 0}]},
		{"label": "extra record field", "satchel": [{"id": HEAD, "slot": "head", "tier": 1, "torn": false, "x": 1}]},
		{"label": "null catalog", "catalog": {}},
		{"label": "non-dictionary catalog entry", "catalog": {HEAD: 5}},
		{"label": "catalog id mismatch", "catalog": {HEAD: {"id": "other", "slot": "head"}}},
	]
	for bad in bad_cases:
		var bad_visit := _open(bad.get("gold", 120), bad.get("satchel", []), bad.get("offer", HEAD),
			bad.get("price", PRICE), bad.get("node", NODE), bad.get("catalog"))
		var label := str(bad["label"])
		var bad_state := bad_visit.read_state()
		_check(not bad_visit.is_valid() and not bad_visit.is_open() and not bad_visit.is_consumed()
			and bad_state.get("ok") == false, "invalid admission does not open: " + label)
		_check(bad_visit.quote().get("ok", true) == false
			and bad_visit.quote().get("choices", ["x"]).is_empty(), "refused admission quotes no choices: " + label)
		_check(bad_visit.buy(NODE, bad_state).get("ok", true) == false
			and bad_visit.leave(NODE, bad_state).get("ok", true) == false,
			"refused admission can neither buy nor leave: " + label)
	_check(_open(0, [], HEAD, 1).is_valid() and _open(0, _spares(6)).is_valid(),
		"a zero wallet, a price of one and a full satchel are legal openings")
	var folk := _open(100, [_spare(HEAD, "head"), _spare(ARMS, "arms", 3, true)])
	_check(folk.is_valid(), "valid existing records of any owner, tier and torn state are admitted")


## AC2: Buy appends one matching untorn tier-I spare and charges once; Leave changes nothing.
func _test_purchase_and_leave() -> void:
	var existing := _spares(3)
	var visit := _open(120, existing)
	var snap := visit.read_state()
	var paid := visit.buy(NODE, snap)
	_check(paid.get("ok") == true and paid.get("decision") == "buy_part" and paid.get("price") == PRICE
		and paid.get("charged_gold") == PRICE and paid.get("gold_before") == 120 and paid.get("gold") == 50,
		"Buy charges exactly the quoted gold once")
	_check(paid.get("part") == {"id": HEAD, "slot": "head", "tier": 1, "torn": false}
		and paid.get("satchel_index") == 3, "the receipt part is the exact tier-I untorn record at the end")
	var after: Array = paid.get("satchel", [])
	_check(after.size() == 4 and after.slice(0, 3) == existing
		and after[3] == {"id": HEAD, "slot": "head", "tier": 1, "torn": false},
		"existing records are preserved in order and the new part is appended")
	_check(visit.is_consumed() and not visit.is_open() and paid.get("status") == "stitched_bought"
		and visit.read_state()["gold"] == 50 and visit.read_state()["satchel"] == after
		and paid.get("state") == visit.read_state() and paid.get("source_state") == snap,
		"the successful Buy closes the visit and the receipt state is authoritative")
	_check(visit.quote().get("ok", true) == false and visit.quote().get("choices", ["x"]).is_empty(),
		"the closed visit offers no further choices")
	# Mutating the receipt cannot change the service.
	paid["satchel"].clear()
	paid["state"]["gold"] = 9999
	paid["part"]["tier"] = 3
	_check(visit.read_state()["gold"] == 50 and visit.read_state()["satchel"].size() == 4
		and visit.read_state()["satchel"][3]["tier"] == 1, "receipts are deep copies")
	# Exactly affordable quote spends the wallet to zero; second slot appends an arms spare.
	var exact := _open(33, [], ARMS, 33)
	var exact_paid := exact.buy(NODE, exact.read_state())
	_check(exact_paid.get("ok") == true and exact_paid.get("gold") == 0
		and exact_paid.get("part") == {"id": ARMS, "slot": "arms", "tier": 1, "torn": false}
		and exact_paid.get("satchel_index") == 0, "an exactly affordable quote spends the wallet to zero")
	# Leave: no debit, no satchel change.
	var leaving := _open(80, existing)
	var left := leaving.leave(NODE, leaving.read_state())
	_check(left.get("ok") == true and left.get("decision") == "leave" and left.get("charged_gold") == 0
		and left.get("price") == 0 and left.get("gold") == 80 and left.get("satchel") == existing,
		"Leave charges nothing and keeps the satchel")
	_check(leaving.is_consumed() and leaving.read_state()["status"] == "stitched_left"
		and leaving.read_state()["gold"] == 80 and leaving.read_state()["satchel"] == existing,
		"Leave closes the visit with the Stitched-left status")
	_reject(leaving, true, NODE, leaving.read_state(), "buy after leave")


## Five-to-six and full-six boundaries, and unaffordable Buy followed by a legal Leave.
func _test_capacity_and_funds() -> void:
	var five := _spares(5)
	var visit := _open(70, five)
	var paid := visit.buy(NODE, visit.read_state())
	_check(paid.get("ok") == true and paid.get("satchel", []).size() == 6
		and paid.get("satchel", [])[5].get("id") == HEAD and paid.get("gold") == 0,
		"five spares plus the purchase reach the six-part limit")
	var six := _spares(6)
	var full := _open(500, six)
	var full_snap := full.read_state()
	_check(full.quote().get("ok") == true and full.quote().get("can_buy") == false
		and full.quote().get("blocked") == "satchel is full" and full.quote().get("satchel_count") == 6,
		"a full satchel discloses that Buy is blocked")
	_reject(full, true, NODE, full_snap, "buy into a full satchel")
	_check(full.read_state()["gold"] == 500 and full.read_state()["satchel"] == six,
		"the full-satchel refusal charges nothing and keeps all six parts")
	var full_left := full.leave(NODE, full_snap)
	_check(full_left.get("ok") == true and full.is_consumed() and full_left.get("satchel") == six,
		"a full-satchel visit still Leaves freely")
	var poor := _open(69, _spares(2))
	var poor_snap := poor.read_state()
	_check(poor.quote().get("ok") == true and poor.quote().get("can_buy") == false
		and poor.quote().get("price") == PRICE, "an unaffordable offer is still disclosed")
	_reject(poor, true, NODE, poor_snap, "unaffordable buy")
	var poor_left := poor.leave(NODE, poor_snap)
	_check(poor_left.get("ok") == true and poor_left.get("charged_gold") == 0 and poor.is_consumed()
		and poor.read_state()["gold"] == 69, "a refused unaffordable Buy preserves the later free Leave")
	var broke := _open(0, [])
	_reject(broke, true, NODE, broke.read_state(), "empty wallet buy")


## AC3: wrong node, forged/stale snapshots, bad decisions and replays refuse without change.
func _test_refusals_and_replay() -> void:
	var visit := _open(300, _spares(2))
	var snap := visit.read_state()
	_reject(visit, true, "other-node", snap, "wrong node buy")
	_reject(visit, false, "other-node", snap, "wrong node leave")
	_reject(visit, true, "", snap, "empty node buy")
	_reject(visit, true, null, snap, "null node buy")
	_reject(visit, true, NODE + " ", snap, "padded node buy")
	for bad_snapshot in [{}, null, "not-a-dictionary", [], 7]:
		_reject(visit, true, NODE, bad_snapshot, "malformed snapshot buy: " + str(bad_snapshot))
		_reject(visit, false, NODE, bad_snapshot, "malformed snapshot leave: " + str(bad_snapshot))
	for field in ["node_id", "status", "open", "gold", "satchel", "offer", "ok"]:
		var stale: Dictionary = snap.duplicate(true)
		match field:
			"gold":
				stale["gold"] += 1
			"open":
				stale["open"] = false
			"satchel":
				stale["satchel"][0]["torn"] = false
			"offer":
				stale["offer"]["price"] = 1
			_:
				stale[field] = "wrong"
		_reject(visit, true, NODE, stale, "stale snapshot buy: " + field)
		_reject(visit, false, NODE, stale, "stale snapshot leave: " + field)
	var forged_offer: Dictionary = snap.duplicate(true)
	forged_offer["offer"]["id"] = ARMS
	forged_offer["offer"]["name"] = "Shield Catch"
	_reject(visit, true, NODE, forged_offer, "forged substituted offer")
	var forged_extra: Dictionary = snap.duplicate(true)
	forged_extra["extra"] = 1
	_reject(visit, true, NODE, forged_extra, "snapshot with an extra field")
	var twin := _open(301, _spares(2))
	_reject(visit, true, NODE, twin.read_state(), "another visit's differing snapshot")
	# Every refusal preserved the one legal choice.
	var paid := visit.buy(NODE, visit.read_state())
	_check(paid.get("ok") == true and paid.get("gold") == 230 and paid.get("satchel", []).size() == 3,
		"after every refusal the fresh exact snapshot still buys legally")
	var used := visit.read_state()
	_reject(visit, true, NODE, snap, "stale pre-buy replay")
	_reject(visit, true, NODE, used, "duplicate purchase")
	_reject(visit, false, NODE, snap, "stale leave replay")
	_reject(visit, false, NODE, used, "leave after the buy")
	_check(visit.read_state() == used and used["gold"] == 230 and used["satchel"].size() == 3,
		"replays leave exactly one charge and one appended part")
	# Leave then replay.
	var leaving := _open(100, [])
	var leave_snap := leaving.read_state()
	_check(leaving.leave(NODE, leave_snap).get("ok") == true, "a fresh Leave succeeds once")
	_reject(leaving, false, NODE, leave_snap, "repeated leave")
	_reject(leaving, false, NODE, leaving.read_state(), "repeated leave with fresh state")
	_reject(leaving, true, NODE, leave_snap, "buy after leave with the old state")


## Buy is offered only when it can actually succeed; Leave is always offered on an open visit.
func _test_choice_availability() -> void:
	var funded_cases: Array = [
		{"label": "0 spares, rich", "gold": 200, "count": 0, "tier": 1, "price": PRICE},
		{"label": "3 spares, rich", "gold": 200, "count": 3, "tier": 1, "price": PRICE},
		{"label": "5 spares, exact gold", "gold": PRICE, "count": 5, "tier": 1, "price": PRICE},
		{"label": "0 spares, exact gold", "gold": PRICE, "count": 0, "tier": 1, "price": PRICE},
		{"label": "tier II, exact gold", "gold": TIER_PRICE, "count": 2, "tier": 2, "price": TIER_PRICE},
		{"label": "price of one, one gold", "gold": 1, "count": 0, "tier": 1, "price": 1},
	]
	for funded in funded_cases:
		var label := str(funded["label"])
		var price := int(funded["price"])
		var visit := _open_tier(funded["tier"], funded["gold"], _spares(int(funded["count"])), price)
		var quote := visit.quote()
		_check(visit.is_open() and quote.get("ok") == true and quote.get("can_buy") == true
			and quote.get("blocked") == "" and quote.get("choices") == ["buy_part", "leave"]
			and quote.get("price") == price and quote.get("offer", {}).get("tier") == funded["tier"],
			"funded quote offers exactly buy and leave: " + label)
		var paid := visit.buy(NODE, quote.get("state"))
		var expected := {"id": HEAD, "slot": "head", "tier": funded["tier"], "torn": false}
		_check(paid.get("ok") == true and paid.get("part") == expected and paid.get("charged_gold") == price
			and paid.get("gold") == int(funded["gold"]) - price
			and paid.get("satchel", []).size() == int(funded["count"]) + 1
			and paid.get("satchel", [])[int(funded["count"])] == expected,
			"funded buy appends the exact untorn record and charges once: " + label)
		_check(visit.is_consumed() and visit.quote().get("ok", true) == false
			and visit.quote().get("choices", ["x"]).is_empty(), "bought quote closes with no choices: " + label)
	var blocked_cases: Array = [
		{"label": "six spares, rich", "gold": 500, "count": 6, "tier": 1, "price": PRICE,
			"reason": "satchel is full"},
		{"label": "six spares, exact gold", "gold": PRICE, "count": 6, "tier": 1, "price": PRICE,
			"reason": "satchel is full"},
		{"label": "tier II six spares", "gold": 500, "count": 6, "tier": 2, "price": TIER_PRICE,
			"reason": "satchel is full"},
		{"label": "two spares, one gold short", "gold": PRICE - 1, "count": 2, "tier": 1, "price": PRICE,
			"reason": "not enough gold"},
		{"label": "tier II, one gold short", "gold": TIER_PRICE - 1, "count": 1, "tier": 2, "price": TIER_PRICE,
			"reason": "not enough gold"},
		{"label": "five spares, no gold", "gold": 0, "count": 5, "tier": 1, "price": PRICE,
			"reason": "not enough gold"},
		{"label": "tier II, no gold", "gold": 0, "count": 0, "tier": 2, "price": TIER_PRICE,
			"reason": "not enough gold"},
	]
	for blocked in blocked_cases:
		var label := str(blocked["label"])
		var gold := int(blocked["gold"])
		var spares := _spares(int(blocked["count"]))
		var price := int(blocked["price"])
		var visit := _open_tier(blocked["tier"], gold, spares, price)
		var snap := visit.read_state()
		var quote := visit.quote()
		_check(visit.is_open() and quote.get("ok") == true and quote.get("can_buy") == false
			and quote.get("blocked") == blocked["reason"] and quote.get("choices") == ["leave"],
			"blocked quote offers only leave with its reason: " + label)
		_check(quote.get("offer", {}).get("id") == HEAD and quote.get("offer", {}).get("tier") == blocked["tier"]
			and quote.get("offer", {}).get("price") == price and quote.get("price") == price
			and quote.get("gold") == gold and quote.get("satchel_count") == spares.size()
			and quote.get("satchel_max") == 6 and quote.get("state") == snap,
			"blocked quote keeps the genuine offer, price, wallet and satchel count: " + label)
		_reject(visit, true, NODE, snap, "direct buy on a blocked quote: " + label)
		_check(visit.is_open() and visit.read_state() == snap and visit.quote().get("choices") == ["leave"]
			and visit.read_state()["gold"] == gold and visit.read_state()["satchel"] == spares,
			"the rejected buy leaves offer, wallet, satchel and Leave rights intact: " + label)
		var left := visit.leave(NODE, visit.read_state())
		_check(left.get("ok") == true and left.get("decision") == "leave" and left.get("charged_gold") == 0
			and left.get("gold") == gold and left.get("satchel") == spares and visit.is_consumed(),
			"Leave then succeeds free: " + label)
		_check(visit.quote().get("ok", true) == false and visit.quote().get("choices", ["x"]).is_empty(),
			"a left visit offers no choices: " + label)
		_reject(visit, false, NODE, visit.read_state(), "second leave: " + label)
		_reject(visit, true, NODE, visit.read_state(), "buy after leave: " + label)


func _open_tier(tier: Variant, gold: Variant = 200, satchel: Variant = [], price: Variant = TIER_PRICE,
		node: Variant = NODE, offer: Variant = HEAD) -> RunStitchedPeddlerPart:
	return RunStitchedPeddlerPart.open_stitched(node, gold, satchel, catalog, offer, price, tier)


## Tier-aware offers: legacy 6-arg calls stay tier I; explicit integer tiers 1..3 agree across
## read_state, quote, projection and the purchased record; malformed tiers never open.
func _test_offer_tiers() -> void:
	var before_catalog: Dictionary = catalog.duplicate(true)
	# Legacy six-argument call is tier I, equal to an explicit tier 1.
	var legacy := _open(120, _spares(2))
	var explicit_one := _open_tier(1, 120, _spares(2), PRICE)
	var legacy_offer: Dictionary = legacy.read_state().get("offer", {})
	_check(legacy.is_open() and legacy_offer.get("tier") == 1
		and legacy_offer.get("ability", {}).get("dmg") == [3, 5]
		and legacy.read_state() == explicit_one.read_state(),
		"a six-argument call is the tier-I offer, identical to an explicit tier 1")
	var legacy_paid := legacy.buy(NODE, legacy.read_state())
	_check(legacy_paid.get("ok") == true and legacy_paid.get("gold") == 50
		and legacy_paid.get("part") == {"id": HEAD, "slot": "head", "tier": 1, "torn": false},
		"the six-argument call still buys the untorn tier-I part for the quote")
	# Tier II open, quote, projection and buy.
	var existing := _spares(3)
	var visit := _open_tier(2, 200, existing)
	_check(visit.is_valid() and visit.is_open(), "an explicit tier 2 opens the visit")
	var state := visit.read_state()
	var offer: Dictionary = state.get("offer", {})
	_check(offer.get("id") == HEAD and offer.get("name") == "Helmet Rattle" and offer.get("slot") == "head"
		and offer.get("owner") == "warden" and offer.get("tier") == 2 and offer.get("torn") == false
		and offer.get("price") == TIER_PRICE, "read_state offers the tier-II warden head part at the quote")
	_check(offer.get("ability", {}).get("dmg") == [5, 7] and offer.get("ability", {}).get("crit") == 0
		and offer.get("stat") == {"crit": 4}, "tier II projects damage [5,7] and crit +4")
	var tier_one_dmg: Array = StitchedParts.ability_at_tier(catalog[HEAD], 1)["dmg"]
	_check(tier_one_dmg == [3, 5] and offer["ability"]["dmg"] != tier_one_dmg,
		"the tier-II damage differs from the tier-I damage")
	var quote := visit.quote()
	_check(quote.get("ok") == true and quote.get("offer") == offer and quote.get("price") == TIER_PRICE
		and quote.get("can_buy") == true and quote.get("choices") == ["buy_part", "leave"]
		and quote.get("state") == state, "quote agrees with read_state on the selected tier and price")
	var paid := visit.buy(NODE, state)
	var record := {"id": HEAD, "slot": "head", "tier": 2, "torn": false}
	_check(paid.get("ok") == true and paid.get("decision") == "buy_part" and paid.get("part") == record
		and paid.get("price") == TIER_PRICE and paid.get("charged_gold") == TIER_PRICE
		and paid.get("gold_before") == 200 and paid.get("gold") == 200 - TIER_PRICE
		and paid.get("satchel_index") == 3, "Buy debits exactly the quote and returns the tier-II record")
	var after: Array = paid.get("satchel", [])
	_check(after.size() == 4 and after.slice(0, 3) == existing and after[3] == record
		and visit.is_consumed() and paid.get("state", {}).get("offer", {}).get("tier") == 2,
		"the tier-II record is appended after untouched existing spares and the visit closes")
	# Replay and refusals against the tier-II state.
	var used := visit.read_state()
	_reject(visit, true, NODE, state, "tier-II stale pre-buy replay")
	_reject(visit, true, NODE, used, "tier-II duplicate purchase")
	_reject(visit, false, NODE, used, "tier-II leave after the buy")
	_check(visit.read_state() == used and used["gold"] == 200 - TIER_PRICE and used["satchel"].size() == 4,
		"tier-II replays leave one charge and one part")
	var guarded := _open_tier(2, 200, _spares(2))
	var guarded_snap := guarded.read_state()
	var tier_one_state := _open_tier(1, 200, _spares(2)).read_state()
	_reject(guarded, true, NODE, tier_one_state, "tier-I snapshot against a tier-II visit")
	var forged: Dictionary = guarded_snap.duplicate(true)
	forged["offer"]["tier"] = 3
	_reject(guarded, true, NODE, forged, "forged higher tier snapshot")
	var forged_dmg: Dictionary = guarded_snap.duplicate(true)
	forged_dmg["offer"]["ability"]["dmg"] = [3, 5]
	_reject(guarded, true, NODE, forged_dmg, "forged tier-II damage projection")
	_reject(guarded, true, "other-node", guarded_snap, "tier-II wrong node")
	var guarded_paid := guarded.buy(NODE, guarded.read_state())
	_check(guarded_paid.get("ok") == true and guarded_paid.get("part", {}).get("tier") == 2,
		"after refusals the exact tier-II snapshot still buys")
	var poor := _open_tier(2, TIER_PRICE - 1, _spares(1))
	_check(poor.quote().get("can_buy") == false and poor.quote().get("blocked") == "not enough gold"
		and poor.quote().get("offer", {}).get("tier") == 2, "an unaffordable tier-II offer is disclosed")
	_reject(poor, true, NODE, poor.read_state(), "unaffordable tier-II buy")
	var poor_left := poor.leave(NODE, poor.read_state())
	_check(poor_left.get("ok") == true and poor_left.get("charged_gold") == 0
		and poor_left.get("gold") == TIER_PRICE - 1 and poor_left.get("satchel") == _spares(1),
		"tier-II Leave is free after a refused Buy")
	var full := _open_tier(2, 500, _spares(6))
	_check(full.quote().get("blocked") == "satchel is full" and full.quote().get("can_buy") == false,
		"a full satchel blocks the tier-II Buy")
	_reject(full, true, NODE, full.read_state(), "tier-II buy into a full satchel")
	_check(full.leave(NODE, full.read_state()).get("ok") == true, "a full-satchel tier-II visit Leaves freely")
	var exact := _open_tier(2, TIER_PRICE, [])
	var exact_paid := exact.buy(NODE, exact.read_state())
	_check(exact_paid.get("ok") == true and exact_paid.get("gold") == 0
		and exact_paid.get("satchel", []) == [record], "an exactly affordable tier-II quote spends to zero")
	# Tier III projection.
	var third := _open_tier(3)
	var third_offer: Dictionary = third.read_state().get("offer", {})
	_check(third_offer.get("tier") == 3 and third_offer.get("ability", {}).get("dmg") == [6, 9]
		and third_offer.get("ability", {}).get("crit") == 8 and third_offer.get("stat") == {"crit": 4},
		"tier III projects damage [6,9] and ability crit +8")
	var third_paid := third.buy(NODE, third.read_state())
	_check(third_paid.get("ok") == true and third_paid.get("part", {}).get("tier") == 3,
		"a tier-III offer buys a tier-III record")
	# Another catalogued part keeps catalog-derived identity at a higher tier.
	var arms := _open_tier(3, 100, [], 40, NODE, ARMS)
	var arms_offer: Dictionary = arms.read_state().get("offer", {})
	_check(arms_offer.get("tier") == 3 and arms_offer.get("slot") == "arms" and arms_offer.get("name") == "Shield Catch"
		and arms.buy(NODE, arms.read_state()).get("part") == {"id": ARMS, "slot": "arms", "tier": 3, "torn": false},
		"another part at tier III derives its slot and name from the catalog")
	# Malformed explicit tiers never open and can neither buy nor leave.
	var bad_tiers: Array = [0, 4, -1, 1.0, 2.0, 1.5, "2", "", null, true, [2], {}]
	for bad in bad_tiers:
		var bad_visit := _open_tier(bad)
		var bad_state := bad_visit.read_state()
		var label := "malformed tier " + str(bad) + " (type " + str(typeof(bad)) + ")"
		_check(not bad_visit.is_valid() and not bad_visit.is_open() and not bad_visit.is_consumed()
			and bad_state.get("ok") == false and bad_visit.quote().get("ok", true) == false
			and bad_visit.quote().get("choices", ["x"]).is_empty(), label + " does not open")
		_check(bad_visit.buy(NODE, bad_state).get("ok", true) == false
			and bad_visit.leave(NODE, bad_state).get("ok", true) == false,
			label + " can neither buy nor leave")
	# Inputs and returned snapshots stay detached from the service and the catalog.
	state["offer"]["ability"]["dmg"][0] = 99
	_check(_open_tier(2).read_state()["offer"]["ability"]["dmg"] == [5, 7] and catalog == before_catalog,
		"tier projections never mutate the catalog or share state")


## The quote and snapshot disclose the COMPLETE tier-resolved ability (equal to the real resolver's
## output), for a Warden head part and a foreign owner:"any" Scissor Claw, detached from the service.
func _test_full_ability_quotes() -> void:
	var claw_id := "scissor_crab_claw_arm"
	var foreign := StitchedParts.load_catalog("res://data/parts/enemy_parts.json")
	_check(bool(foreign.get("ok", false)) and foreign.get("by_id", {}).has(claw_id),
		"the real foreign catalog loads and holds the Scissor Claw")
	if not foreign.get("by_id", {}).has(claw_id):
		return
	var merged: Dictionary = catalog.duplicate(true)
	merged[claw_id] = foreign["by_id"][claw_id].duplicate(true)
	var merged_before: Dictionary = merged.duplicate(true)
	var witnesses: Array = [
		{"id": HEAD, "key": "weak", "amounts": [1, 2, 3], "dmg": [[3, 5], [5, 7], [6, 9]], "crit": [0, 0, 8],
			"target": [[1, 2], [1, 2], [1, 2, 3]]},
		{"id": claw_id, "key": "bleed", "amounts": [2, 3, 4], "dmg": [[4, 7], [5, 8], [6, 9]], "crit": [0, 0, 0],
			"target": [[1, 2], [1, 2], [1, 2]]},
	]
	for witness in witnesses:
		var part_id := str(witness["id"])
		for tier in [1, 2, 3]:
			var label := part_id + " tier " + str(tier)
			var visit := _open_tier(tier, 200, _spares(1), TIER_PRICE, NODE, part_id) if part_id == HEAD \
				else RunStitchedPeddlerPart.open_stitched(NODE, 200, _spares(1), merged, part_id, TIER_PRICE, tier)
			var expected: Dictionary = StitchedParts.ability_at_tier(merged[part_id], tier)
			_check(visit.is_open() and not expected.is_empty(), "visit opens with a resolved ability: " + label)
			var state_ability: Dictionary = visit.read_state().get("offer", {}).get("ability", {})
			var quote_ability: Dictionary = visit.quote().get("offer", {}).get("ability", {})
			_check(state_ability == expected and quote_ability == expected,
				"read_state and quote carry the complete tier-resolved ability: " + label)
			for field in ["launch", "target", "target_side", "multi", "acc", "effects", "self_move", "move"]:
				_check(expected.has(field) and state_ability.has(field),
					"the disclosed ability has " + field + ": " + label)
			var idx: int = tier - 1
			_check(state_ability.get("dmg") == witness["dmg"][idx] and state_ability.get("crit") == witness["crit"][idx]
				and state_ability.get("effects", {}).get(str(witness["key"])) == witness["amounts"][idx]
				and state_ability.get("launch") == [1, 2]
				and state_ability.get("target") == witness["target"][idx]
				and state_ability.get("target_side") == "enemy" and state_ability.get("acc") == 90,
				"authored damage, crit, status and unchanged ranks show at: " + label)
			# Mutating the returned nested arrays and effects drifts nothing.
			var snap := visit.read_state()
			state_ability["launch"].append(4)
			state_ability["target"][0] = 4
			state_ability["effects"]["bleed"] = 99
			state_ability["effects"]["weak"] = 99
			state_ability["dmg"][0] = 99
			quote_ability["effects"].clear()
			quote_ability["launch"].clear()
			_check(visit.read_state() == snap and visit.quote().get("offer", {}).get("ability") == expected
				and merged == merged_before, "mutating returned nested ability data drifts nothing: " + label)
			var paid := visit.buy(NODE, snap)
			_check(paid.get("ok") == true and paid.get("part") == {"id": part_id,
				"slot": str(merged[part_id]["slot"]), "tier": tier, "torn": false}
				and paid.get("state", {}).get("offer", {}).get("ability") == expected,
				"buy still charges the quote and the receipt keeps the full ability: " + label)
	# A forged partial ability projection is refused as a stale snapshot.
	var guarded := _open_tier(2)
	var forged: Dictionary = guarded.read_state().duplicate(true)
	forged["offer"]["ability"]["effects"]["weak"] = 1
	_reject(guarded, true, NODE, forged, "forged effect projection")
	var short: Dictionary = guarded.read_state().duplicate(true)
	short["offer"]["ability"].erase("launch")
	_reject(guarded, true, NODE, short, "snapshot missing a rank field")
	_check(guarded.buy(NODE, guarded.read_state()).get("ok") == true, "the exact snapshot still buys after forgeries")
