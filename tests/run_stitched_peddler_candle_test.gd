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
	_test_two_visit_identity()
	_test_band_forecast()
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


## AC1-AC2: two independently opened visits with identical node, candle, wallet
## and price carry distinct private identities, so a callback captured from the
## first can neither buy nor leave on the second.
func _test_two_visit_identity() -> void:
	var a := _open(60, 120, 45)
	var b := _open(60, 120, 45)
	var a_snap := a.read_state()
	var b_snap := b.read_state()
	var a_id: Variant = a_snap.get("visit_id")
	var b_id: Variant = b_snap.get("visit_id")
	_check(a_id is String and b_id is String and not str(a_id).is_empty()
		and not str(b_id).is_empty() and a_id != b_id,
		"twin visits carry distinct nonempty visit_id values")
	_check(a.read_state() == a_snap and b.read_state() == b_snap
		and a.read_state()["visit_id"] == a_id and b.read_state()["visit_id"] == b_id,
		"each visit_id is stable across repeated reads")
	var detached := a.read_state()
	detached["visit_id"] = "forged"
	_check(a.read_state()["visit_id"] == a_id,
		"mutating a returned snapshot cannot alter the visit identity")
	_check(not a.quote().has("visit_id"),
		"the identity is not part of the player-facing quote")
	# Old callbacks from visit A are refused on the identical visit B.
	var b_before := b.read_state()
	_reject(b, "buy_candle_stub", NODE, a_snap, "old visit snapshot buy")
	_reject(b, "leave", NODE, a_snap, "old visit snapshot leave")
	_check(b.read_state() == b_before and b.is_open() and not b.is_consumed()
		and b.read_state()["gold"] == 120 and b.read_state()["candle"] == 60,
		"the second visit stays open and unchanged after both old callbacks")
	# Forged identity or altered fields cannot bypass the gate.
	var forged := b_snap.duplicate(true)
	forged["visit_id"] = a_id
	_reject(b, "buy_candle_stub", NODE, forged, "forged identity buy")
	var missing := b_snap.duplicate(true)
	missing.erase("visit_id")
	_reject(b, "buy_candle_stub", NODE, missing, "missing identity buy")
	var repriced := a_snap.duplicate(true)
	repriced["visit_id"] = b_id
	repriced["item"]["price"] = 1
	_reject(b, "buy_candle_stub", NODE, repriced, "repriced own identity")
	_reject(b, "buy_candle_stub", "other-node", b_snap, "own snapshot wrong node")
	# Visit A can still decide against its own snapshot.
	var a_paid := _buy(a, NODE, a_snap)
	_check(a_paid.get("ok") == true and a_paid.get("candle") == 85
		and a_paid.get("gold") == 75 and a.is_consumed()
		and a.read_state()["visit_id"] == a_id,
		"the first visit still buys with its own snapshot; identity survives")
	# B's own fresh snapshot buys exactly once.
	var b_paid := _buy(b, NODE, b.read_state())
	_check(b_paid.get("ok") == true and b_paid.get("candle") == 85
		and b_paid.get("gold") == 75 and b_paid.get("charged_gold") == 45
		and b_paid.get("restored") == RESTORE and b.is_consumed()
		and b.read_state()["visit_id"] == b_id,
		"the second visit's own snapshot buys +25 for exactly 45 once")
	_reject(b, "buy_candle_stub", NODE, b_snap, "replay of the open snapshot")
	_reject(b, "leave", NODE, b.read_state(), "leave after the buy")
	# Leave path on a third twin with its own snapshot.
	var c := _open(60, 120, 45)
	var d := _open(60, 120, 45)
	var c_snap := c.read_state()
	_check(c_snap["visit_id"] != d.read_state()["visit_id"],
		"further twins also get distinct identities")
	_reject(d, "leave", NODE, c_snap, "twin leave with foreign snapshot")
	var d_left := _leave(d, NODE, d.read_state())
	_check(d_left.get("ok") == true and d_left.get("charged_gold") == 0
		and d.is_consumed() and d.read_state()["gold"] == 120,
		"the second twin's own snapshot leaves free and once")
	# Legacy constructor state gains no Stitched visit identity.
	var legacy := RunPeddlerVisit.new()
	_check(not legacy.read_state().has("visit_id"),
		"the legacy constructor state has no visit identity")


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


## AC1-AC3: the quote forecasts one purchase's candle and canonical light band
## without granting, spending or drawing; the real buy then matches it.
func _test_band_forecast() -> void:
	# candle, restore, after, band before, band after, crosses
	var cases: Array = [
		[0, 25, 25, "snuffed", "dark", true],
		[25, 25, 50, "dark", "gloom", true],
		[26, 25, 51, "gloom", "dim", true],
		[50, 25, 75, "gloom", "dim", true],
		[51, 25, 76, "dim", "bright", true],
		[75, 25, 100, "dim", "bright", true],
		[76, 24, 100, "bright", "bright", false],
		[99, 1, 100, "bright", "bright", false],
		[100, 0, 100, "bright", "bright", false],
	]
	seed(909090)
	var expected_rng := randi()
	seed(909090)
	for row in cases:
		var candle: int = row[0]
		var label := "forecast candle %d" % candle
		var visit := _open(candle, 120, 45)
		var before := visit.read_state()
		var quote := visit.quote()
		_check(quote.get("ok") == true and quote.get("restore") == row[1]
			and quote.get("candle") == candle and quote.get("candle_after") == row[2]
			and quote.get("band_before") == row[3] and quote.get("band_after") == row[4]
			and quote.get("crosses_band") == row[5],
			label + ": exact restore, candle_after, bands and crossing")
		_check(quote.get("band_before") == StitchedS1BEffects.candle_band(candle)["name"]
			and quote.get("band_after")
			== StitchedS1BEffects.candle_band(int(quote.get("candle_after")))["name"],
			label + ": bands equal the canonical StitchedS1BEffects names")
		_check(quote.get("mode") == MODE and quote.get("node_id") == NODE
			and quote.get("item") == ITEM and quote.get("price") == 45
			and quote.get("gold") == 120,
			label + ": legacy quote keys are preserved")
		var expect_choices: Array = ["leave"] if candle == CANDLE_MAX \
			else ["buy_candle_stub", "leave"]
		_check(quote.get("choices") == expect_choices,
			label + ": Buy gating is unchanged by the forecast")
		_check(visit.read_state() == before and visit.is_open()
			and visit.quote() == quote,
			label + ": quoting is read-only and repeatable")
	# An unaffordable visit still forecasts the purchase but offers Leave only.
	var poor := _open(51, 10, 45)
	var poor_quote := poor.quote()
	_check(poor_quote.get("choices") == ["leave"]
		and poor_quote.get("candle_after") == 76
		and poor_quote.get("band_before") == "dim"
		and poor_quote.get("band_after") == "bright"
		and poor_quote.get("crosses_band") == true,
		"an unaffordable visit forecasts the buy yet offers Leave only")
	_reject(poor, "buy_candle_stub", NODE, poor.read_state(), "unaffordable forecast")
	# Closed visits quote no choices and stay state-neutral.
	var closed := _open(51, 120, 45)
	_leave(closed, NODE, closed.read_state())
	_check(closed.quote().get("ok") == false and closed.quote().get("choices") == [],
		"a Left visit still quotes no choices")
	# One affordable public buy matches the prior forecast exactly.
	var buyer := _open(51, 120, 45)
	var forecast := buyer.quote()
	var snapshot := buyer.read_state()
	var receipt := _buy(buyer, NODE, snapshot)
	var after := buyer.read_state()
	_check(receipt.get("ok") == true and receipt.get("charged_gold") == 45
		and receipt.get("price") == 45 and receipt.get("candle_before") == 51
		and receipt.get("restored") == forecast.get("restore")
		and receipt.get("candle") == 76 and receipt.get("gold") == 75
		and receipt.get("candle") == forecast.get("candle_after"),
		"the 51 CANDLE buy charges 45 once and lands on the forecast 76")
	_check(after["candle"] == 76 and after["gold"] == 75 and buyer.is_consumed()
		and not buyer.is_open() and after["status"] == "stitched_used"
		and StitchedS1BEffects.candle_band(after["candle"])["name"]
		== forecast.get("band_after"),
		"the settled state is consumed and in the forecast canonical band")
	_check(randi() == expected_rng,
		"forecasts, rejections and the buy leave the caller RNG state unchanged")
	seed(424242) # Restore the suite's shared global RNG witness.
