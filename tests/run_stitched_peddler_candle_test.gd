extends SceneTree
## Design v4 S6 Stitched Peddler candle-stub visit contract: the opt-in
## quoted-gold one-use buy-or-Leave decision guarded by the exact node and a
## complete open-state snapshot, fully detached state, legacy purchase
## isolation and no RNG draws. Scene-free service test.

const NODE := "route-peddler-7"
const MODE := "stitched"
const ITEM := "candle_stub"
const RESTORE := 25
const CANDLE_MAX := 100

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	seed(424242)
	var next_draw := randi()
	seed(424242)
	_test_quote_and_admission()
	_test_effective_quote()
	_test_purchase_and_leave()
	_test_refusals_and_legacy_isolation()
	_check(randi() == next_draw,
		"Stitched open, quote, buys, Leaves and every refusal draw no global RNG")
	if failures.is_empty():
		print("run_stitched_peddler_candle_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_stitched_peddler_candle_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _open(candle: Variant, gold: Variant, price: Variant,
		node: Variant = NODE) -> RunPeddlerVisit:
	return RunPeddlerVisit.open_stitched_candle(node, candle, gold, price)


func _buy(visit: RunPeddlerVisit, node: Variant, snapshot: Variant) -> Dictionary:
	return visit.select_stitched("buy_candle_stub", node, snapshot)


func _leave(visit: RunPeddlerVisit, node: Variant, snapshot: Variant) -> Dictionary:
	return visit.select_stitched("leave", node, snapshot)


## A refused Stitched request must change nothing, keep the visit's consumed
## right identical and never report a phantom charge or decision.
func _reject(visit: RunPeddlerVisit, decision: Variant, node: Variant,
		snapshot: Variant, label: String) -> void:
	var before := visit.read_state()
	var used := visit.is_consumed()
	var result := visit.select_stitched(decision, node, snapshot)
	_check(result.get("ok", true) == false, label + ": refused")
	_check(visit.read_state() == before and visit.is_consumed() == used,
		label + ": no drift in candle, wallet, status or retry right")
	_check(result.get("decision", "x") == "" and result.get("charged_gold", 1) == 0,
		label + ": no phantom decision or charge")


## AC1: a valid node, 0..100 candle, non-negative wallet and positive quoted
## integer price open the visit with an honest candle-stub quote and a deep
## detached snapshot; every malformed input fails admission.
func _test_quote_and_admission() -> void:
	var visit := _open(60, 120, 45)
	_check(visit.is_valid() and visit.is_open() and not visit.is_consumed(),
		"valid node, 0..100 candle, wallet and positive quote open the visit")
	var state := visit.read_state()
	var item: Dictionary = state.get("item", {})
	_check(state.get("ok") == true and state.get("mode") == MODE
		and state.get("node_id") == NODE and state.get("candle") == 60
		and state.get("gold") == 120 and state.get("status") == "stitched_open"
		and state.get("consumed") == false,
		"read_state carries node, Stitched mode, candle, wallet, status and open flag")
	_check(item.get("id") == ITEM and item.get("restore") == RESTORE
		and item.get("price") == 45,
		"the quoted item is candle_stub restoring 25 at the caller's price")
	var quote := visit.quote()
	_check(quote.get("ok") == true and quote.get("mode") == MODE
		and quote.get("node_id") == NODE and quote.get("item") == ITEM
		and quote.get("restore") == RESTORE and quote.get("price") == 45
		and quote.get("candle") == 60 and quote.get("gold") == 120
		and quote.get("choices") == ["buy_candle_stub", "leave"],
		"the open quote offers exactly buy_candle_stub and leave at the quoted price")
	# The deep snapshot is detached: mutating the returned state cannot forge
	# a cheaper price, another candle or another wallet.
	state["item"]["price"] = 1
	state["candle"] = 0
	state["gold"] = 99999
	var fresh := visit.read_state()
	_check(fresh["candle"] == 60 and fresh["gold"] == 120
		and fresh["item"]["price"] == 45,
		"mutating the returned deep snapshot changes nothing in the service")
	# Invalid node, candle, wallet or quote never open a visit.
	var bad_cases: Array = [
		{"candle": 60, "gold": 120, "price": 45, "node": ""},
		{"candle": 60, "gold": 120, "price": 45, "node": " " + NODE},
		{"candle": 60, "gold": 120, "price": 45, "node": NODE + " "},
		{"candle": 60, "gold": 120, "price": 45, "node": null},
		{"candle": 60, "gold": 120, "price": 45, "node": 17},
		{"candle": -1, "gold": 120, "price": 45, "node": NODE},
		{"candle": 101, "gold": 120, "price": 45, "node": NODE},
		{"candle": 60.0, "gold": 120, "price": 45, "node": NODE},
		{"candle": "60", "gold": 120, "price": 45, "node": NODE},
		{"candle": null, "gold": 120, "price": 45, "node": NODE},
		{"candle": 60, "gold": -1, "price": 45, "node": NODE},
		{"candle": 60, "gold": "120", "price": 45, "node": NODE},
		{"candle": 60, "gold": 120.0, "price": 45, "node": NODE},
		{"candle": 60, "gold": null, "price": 45, "node": NODE},
		{"candle": 60, "gold": 120, "price": 0, "node": NODE},
		{"candle": 60, "gold": 120, "price": -5, "node": NODE},
		{"candle": 60, "gold": 120, "price": 45.5, "node": NODE},
		{"candle": 60, "gold": 120, "price": "45", "node": NODE},
		{"candle": 60, "gold": 120, "price": null, "node": NODE},
	]
	for bad in bad_cases:
		var bad_visit := _open(bad["candle"], bad["gold"], bad["price"], bad["node"])
		var bad_state := bad_visit.read_state()
		_check(not bad_visit.is_valid() and not bad_visit.is_open()
			and not bad_visit.is_consumed() and bad_state.get("ok") == false,
			"invalid node/candle/wallet/quote fails admission: " + str(bad))
		_check(bad_visit.quote().get("ok", true) == false
			and bad_visit.quote().get("choices", ["x"]).is_empty(),
			"refused admission quotes no choices: " + str(bad))
		_check(bad_visit.select_stitched("buy_candle_stub", NODE,
			bad_state).get("ok", true) == false
			and bad_visit.select_stitched("leave", NODE,
			bad_state).get("ok", true) == false,
			"refused admission can neither buy nor leave: " + str(bad))
	_check(_open(0, 0, 1).is_valid() and _open(CANDLE_MAX, 0, 1).is_valid(),
		"boundary candles 0 and 100 with a zero wallet are legal openings")


## AC1: the quote reports the CURRENT effective gain min(25, 100 - candle) while
## the item's intrinsic restore stays 25, and offers Buy only for a positive
## recovery the wallet can pay; otherwise only Leave while open.
func _test_effective_quote() -> void:
	var gains := {0: 25, 75: 25, 84: 16, 90: 10, 99: 1, 100: 0}
	for candle in gains:
		var expected: int = gains[candle]
		# Exact price, above price and below price wallets.
		for gold in [40, 41, 500, 39, 0]:
			var visit := _open(candle, gold, 40)
			var state := visit.read_state()
			var quote := visit.quote()
			var label := "candle %d gold %d" % [candle, gold]
			_check(quote.get("ok") == true and quote.get("restore") == expected,
				label + ": quote restore is the true current gain " + str(expected))
			_check(state["item"]["restore"] == RESTORE
				and state["item"]["id"] == ITEM and state["item"]["price"] == 40
				and state["candle"] == candle and state["gold"] == gold
				and state["status"] == "stitched_open",
				label + ": read_state keeps the intrinsic restore 25 and exact state")
			_check(quote.get("mode") == MODE and quote.get("node_id") == NODE
				and quote.get("item") == ITEM and quote.get("price") == 40
				and quote.get("candle") == candle and quote.get("gold") == gold,
				label + ": quote metadata stays accurate")
			var actionable: bool = expected > 0 and gold >= 40
			if actionable:
				_check(quote.get("choices") == ["buy_candle_stub", "leave"],
					label + ": positive affordable recovery offers Buy and Leave")
			else:
				_check(quote.get("choices") == ["leave"],
					label + ": full or unaffordable offers Leave only")
			# The advertised list never outranks the authoritative service.
			var before := visit.read_state()
			var bought := _buy(visit, NODE, before)
			_check(bought.get("ok") == actionable,
				label + ": select_stitched agrees with the advertised Buy")
			if actionable:
				_check(bought.get("restored") == expected
					and bought.get("charged_gold") == 40
					and bought.get("candle") == mini(CANDLE_MAX, candle + RESTORE)
					and bought.get("gold") == gold - 40,
					label + ": purchase gains exactly the quoted effective restore")
			else:
				_check(visit.read_state() == before and visit.is_open(),
					label + ": refused Buy leaves the open visit untouched")
				var left := _leave(visit, NODE, visit.read_state())
				_check(left.get("ok") == true and left.get("charged_gold") == 0
					and left.get("candle") == candle and left.get("gold") == gold,
					label + ": free Leave still succeeds after the refusal")
	# Closed and invalid visits advertise no choices.
	var used := _open(60, 100, 40)
	_buy(used, NODE, used.read_state())
	var used_quote := used.quote()
	_check(used_quote.get("ok") == false and used_quote.get("choices") == [],
		"a purchased visit quotes no choices")
	var left_visit := _open(60, 100, 40)
	_leave(left_visit, NODE, left_visit.read_state())
	_check(left_visit.quote().get("ok") == false
		and left_visit.quote().get("choices") == [],
		"a Left visit quotes no choices")
	var invalid := _open(60, 100, 0)
	_check(invalid.quote().get("ok") == false
		and invalid.quote().get("choices") == [],
		"an invalid visit quotes no choices")


## AC2: one affordable buy pays exactly the quoted cost and restores
## min(25, 100 - candle); Leave consumes the visit without any change.
func _test_purchase_and_leave() -> void:
	# 60 -> 85 with a 40-gold caller quote.
	var visit := _open(60, 100, 40)
	var snap := visit.read_state()
	var paid := _buy(visit, NODE, snap)
	_check(paid.get("ok") == true and paid.get("decision") == "buy_candle_stub"
		and paid.get("item") == ITEM and paid.get("candle") == 85
		and paid.get("candle_before") == 60 and paid.get("restored") == RESTORE
		and paid.get("charged_gold") == 40 and paid.get("gold") == 60
		and paid.get("price") == 40,
		"60 CANDLE buys to 85 for exactly the quoted 40 gold")
	_check(paid.get("status") == "stitched_used" and visit.is_consumed()
		and not visit.is_open(),
		"the successful buy consumes the visit exactly once")
	_check(visit.read_state()["candle"] == 85 and visit.read_state()["gold"] == 60
		and visit.read_state()["status"] == "stitched_used",
		"the visit holds the settled candle, wallet and used status")
	_check(visit.quote().get("ok", true) == false
		and visit.quote().get("choices", ["x"]).is_empty(),
		"the consumed visit offers no further choices")
	# 90 -> 100 cap with a different caller quote.
	var capped := _open(90, 200, 65)
	var capped_paid := _buy(capped, NODE, capped.read_state())
	_check(capped_paid.get("ok") == true and capped_paid.get("candle") == CANDLE_MAX
		and capped_paid.get("candle_before") == 90 and capped_paid.get("restored") == 10
		and capped_paid.get("charged_gold") == 65 and capped_paid.get("gold") == 135,
		"90 CANDLE buys to the 100 cap, restoring only 10 for the quoted 65")
	# An exactly affordable quote spends the wallet to zero.
	var exact := _open(10, 33, 33)
	var exact_paid := _buy(exact, NODE, exact.read_state())
	_check(exact_paid.get("ok") == true and exact_paid.get("gold") == 0
		and exact_paid.get("charged_gold") == 33 and exact_paid.get("candle") == 35,
		"an exactly affordable quote spends the wallet to zero")
	# Leave consumes once without charging or restoring.
	var leaving := _open(55, 80, 40)
	var left := _leave(leaving, NODE, leaving.read_state())
	_check(left.get("ok") == true and left.get("decision") == "leave"
		and left.get("charged_gold") == 0 and left.get("price") == 0
		and left.get("candle") == 55 and left.get("gold") == 80,
		"Leave consumes the visit once without charging or restoring")
	_check(leaving.is_consumed() and leaving.read_state()["status"] == "stitched_left",
		"Leave retires the visit with the distinct Stitched-left status")
	# Route teardown retires an open Stitched generation.
	var closed := _open(30, 90, 20)
	closed.close()
	_check(closed.is_consumed() and closed.read_state()["status"] == "stitched_left"
		and _buy(closed, NODE, closed.read_state()).get("ok", true) == false,
		"route teardown retires an open Stitched generation")


## AC3: every failed precondition, stale or forged intent, replay or legacy
## card purchase on a Stitched instance refuses without mutation, drift or
## RNG use, and a refused request never spends the visit's one legal choice.
func _test_refusals_and_legacy_isolation() -> void:
	# Insufficient funds: refused without drift, visit preserved for Leave.
	var poor := _open(70, 30, 40)
	var poor_snap := poor.read_state()
	_check(poor.quote().get("ok") == true and poor.quote().get("price") == 40,
		"an unaffordable quote is still honestly disclosed")
	_reject(poor, "buy_candle_stub", NODE, poor_snap, "insufficient gold")
	var poor_left := _leave(poor, NODE, poor_snap)
	_check(poor_left.get("ok") == true and poor_left.get("charged_gold") == 0
		and poor.is_consumed(),
		"a refused buy preserves the later legal Leave")
	# The full candle never pays for a no-effect item.
	var full := _open(CANDLE_MAX, 500, 40)
	var full_snap := full.read_state()
	_reject(full, "buy_candle_stub", NODE, full_snap, "full-candle buy")
	_check(full.read_state()["gold"] == 500, "the full candle charges nothing")
	var full_left := _leave(full, NODE, full_snap)
	_check(full_left.get("ok") == true and full.is_consumed(),
		"a full-candle visit still Leaves freely")
	# Wrong node, forged decisions, stale or malformed snapshots.
	var visit := _open(50, 300, 50)
	var snap := visit.read_state()
	_reject(visit, "buy_candle_stub", "other-node", snap, "wrong node buy")
	_reject(visit, "leave", "other-node", snap, "wrong node leave")
	_reject(visit, "buy_candle_stub", "", snap, "empty node buy")
	for decision in ["", " ", "buy", "buy_candle_stub ", "BUY_CANDLE_STUB",
			"leave_shop", null, 12]:
		_reject(visit, decision, NODE, snap, "forged decision: " + str(decision))
	_reject(visit, "buy_candle_stub", NODE, {}, "omitted snapshot")
	_reject(visit, "buy_candle_stub", NODE, null, "null snapshot")
	_reject(visit, "buy_candle_stub", NODE, "not-a-dictionary", "non-dictionary snapshot")
	for field in ["candle", "gold", "status", "mode", "node_id", "consumed", "item", "ok"]:
		var stale := snap.duplicate(true)
		if field == "item":
			stale["item"]["price"] = 1
		elif field == "candle" or field == "gold":
			stale[field] += 1
		elif field == "consumed":
			stale[field] = true
		else:
			stale[field] = "wrong"
		_reject(visit, "buy_candle_stub", NODE, stale, "stale snapshot: " + field)
		_reject(visit, "leave", NODE, stale, "stale snapshot leave: " + field)
	# Another visit's differing snapshot is a stale intent here.
	var twin := _open(50, 301, 50)
	_reject(visit, "buy_candle_stub", NODE, twin.read_state(),
		"another visit's differing snapshot")
	# Every refusal preserved the exact legal choice.
	var paid := _buy(visit, NODE, visit.read_state())
	_check(paid.get("ok") == true and paid.get("gold") == 250
		and paid.get("candle") == 75,
		"after every refusal the fresh exact choice still buys legally")
	# Duplicate purchase, stale replay and post-buy Leave all refuse.
	var used_snap := visit.read_state()
	_reject(visit, "buy_candle_stub", NODE, snap, "stale pre-buy replay")
	_reject(visit, "buy_candle_stub", NODE, used_snap, "duplicate purchase")
	_reject(visit, "leave", NODE, snap, "stale leave replay")
	_reject(visit, "leave", NODE, used_snap, "leave after the buy")
	# The legacy card-purchase surface cannot act on a Stitched instance.
	var legacy_buy := visit.choose_purchase(NODE, {}, {}, "card", "warden_strike")
	_check(legacy_buy.get("ok", true) == false,
		"legacy choose_purchase is refused on a Stitched visit")
	var legacy_leave := visit.leave(NODE, {}, {})
	_check(legacy_leave.get("ok", true) == false,
		"legacy leave is refused on a Stitched visit")
	_check(not visit.settle_displaced_patch("relay_bobbin", "hearth_lining",
		visit.read_state()),
		"legacy settle_displaced_patch is refused on a Stitched visit")
	var after := visit.read_state()
	_check(after["gold"] == 250 and after["candle"] == 75
		and after["status"] == "stitched_used",
		"legacy calls cause no drift on the consumed Stitched visit")
	# A fresh open Stitched visit refuses the same legacy surface before any
	# decision, without consuming its one legal choice.
	var fresh_open := _open(20, 400, 60)
	var fresh_before := fresh_open.read_state()
	_check(fresh_open.choose_purchase(NODE, {}, {}, "card",
		"warden_strike").get("ok", true) == false
		and fresh_open.leave(NODE, {}, {}).get("ok", true) == false
		and not fresh_open.settle_displaced_patch("a", "b", fresh_before)
		and fresh_open.read_state() == fresh_before and fresh_open.is_open(),
		"legacy purchase attempts on an open Stitched visit refuse without drift")
	var fresh_paid := _buy(fresh_open, NODE, fresh_open.read_state())
	_check(fresh_paid.get("ok") == true and fresh_paid.get("candle") == 45
		and fresh_paid.get("gold") == 340,
		"the Stitched choice still completes after refused legacy attempts")
