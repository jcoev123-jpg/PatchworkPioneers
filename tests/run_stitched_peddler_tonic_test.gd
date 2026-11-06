extends SceneTree

const NODE := "peddler_node_3"
const PRICE := 7
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_admission_and_quote()
	_invalid_inputs()
	_purchase()
	_refusals()
	_leave()
	_legacy_path_witness()
	_spool_offer_and_purchase()
	_spool_refusals()
	_spool_invalid_selectors()
	_spool_leave_and_determinism()
	for failure in failures:
		printerr(failure)
	print("run_stitched_peddler_tonic_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _dolls() -> Array:
	return [{"id": "a", "rank": 1, "hp": 90, "max_hp": 100, "lost": false, "fray": 3},
		{"id": "b", "rank": 2, "hp": 10, "max_hp": 101, "lost": false, "fray": 0},
		{"id": "c", "rank": 3, "hp": 0, "max_hp": 20, "lost": false, "fray": 1},
		{"id": "d", "rank": 4, "hp": 20, "max_hp": 20, "lost": true, "fray": 0}]


func _pockets() -> Dictionary:
	return {"a": ["thimble_tonic"], "b": [], "c": ["pins", "spare_spool"], "d": []}


func _open(gold: int = 20) -> RunStitchedPeddlerTonic:
	return RunStitchedPeddlerTonic.open_stitched(NODE, _dolls(), _pockets(), gold, PRICE)


func _refuse(visit: RunStitchedPeddlerTonic, receipt: Dictionary, before: Dictionary, message: String) -> void:
	_check(not receipt.ok and receipt.decision == "" and receipt.charged_gold == 0, message + ": fail-closed receipt")
	_check(visit.read_state() == before and visit.is_open(), message + ": state untouched and visit still open")


func _admission_and_quote() -> void:
	var dolls := _dolls()
	var pockets := _pockets()
	var visit := RunStitchedPeddlerTonic.open_stitched(NODE, dolls, pockets, 20, PRICE)
	_check(visit.is_valid() and visit.is_open() and not visit.is_consumed(), "valid four-doll visit opens")
	var state := visit.read_state()
	_check(state.ok and state.node_id == NODE and state.gold == 20 and state.price == PRICE, "state is truthful")
	_check(state.pockets == _pockets() and state.dolls == _dolls(), "state mirrors inputs and item order")
	# HP 0 and not LOST (doll c) is Hanging by a Thread but its pocket is full; d is LOST.
	_check(state.eligible == ["a", "b"], "eligible = not LOST with free space")
	var quote := visit.quote()
	_check(quote.ok and quote.item == "thimble_tonic" and quote.price == PRICE and quote.gold == 20, "quote shows item and price")
	_check(quote.eligible == ["a", "b"] and quote.can_buy and quote.blocked == "", "quote lists eligible dolls")
	_check(quote.choices == ["buy_thimble_tonic", "leave"], "buy and free leave offered")
	# Detachment of inputs and snapshots.
	dolls[0].hp = 0
	pockets.a.clear()
	_check(visit.read_state() == state, "constructor detaches caller inputs")
	var detached := visit.read_state()
	detached.pockets.b.append("dye")
	detached.dolls[0].rank = 9
	detached.eligible.clear()
	var q := visit.quote()
	q.eligible.clear()
	_check(visit.read_state() == state, "snapshots and quotes are detached")
	# Hanging doll with a free slot stays eligible.
	var hang := _pockets()
	hang.c = []
	var open_hang := RunStitchedPeddlerTonic.open_stitched(NODE, _dolls(), hang, 20, PRICE)
	_check(open_hang.read_state().eligible == ["a", "b", "c"], "HP-0 non-LOST doll remains a valid owner")
	# Unaffordable quote offers only Leave but discloses price.
	var poor := _open(PRICE - 1)
	var pq := poor.quote()
	_check(pq.ok and pq.price == PRICE and not pq.can_buy and pq.blocked == "not enough gold" and pq.choices == ["leave"], "unaffordable quote offers only Leave")
	# Exact-price wallet is affordable.
	_check(_open(PRICE).quote().can_buy, "wallet equal to price is affordable")


func _invalid_inputs() -> void:
	var bad_visits: Array = []
	bad_visits.append(RunStitchedPeddlerTonic.open_stitched("", _dolls(), _pockets(), 20, PRICE))
	bad_visits.append(RunStitchedPeddlerTonic.open_stitched(" n ", _dolls(), _pockets(), 20, PRICE))
	bad_visits.append(RunStitchedPeddlerTonic.open_stitched(5, _dolls(), _pockets(), 20, PRICE))
	bad_visits.append(RunStitchedPeddlerTonic.open_stitched(null, _dolls(), _pockets(), 20, PRICE))
	var three := _dolls()
	three.pop_back()
	bad_visits.append(RunStitchedPeddlerTonic.open_stitched(NODE, three, _pockets(), 20, PRICE))
	var five := _dolls()
	five.append({"id": "e", "rank": 4, "hp": 1, "max_hp": 1, "lost": false})
	bad_visits.append(RunStitchedPeddlerTonic.open_stitched(NODE, five, _pockets(), 20, PRICE))
	var dup_id := _dolls()
	dup_id[1].id = "a"
	bad_visits.append(RunStitchedPeddlerTonic.open_stitched(NODE, dup_id, _pockets(), 20, PRICE))
	var empty_id := _dolls()
	empty_id[1].id = ""
	bad_visits.append(RunStitchedPeddlerTonic.open_stitched(NODE, empty_id, _pockets(), 20, PRICE))
	var dup_rank := _dolls()
	dup_rank[1].rank = 1
	bad_visits.append(RunStitchedPeddlerTonic.open_stitched(NODE, dup_rank, _pockets(), 20, PRICE))
	for rank in [0, 5, 2.0, "2", null]:
		var bad_rank := _dolls()
		bad_rank[1].rank = rank
		bad_visits.append(RunStitchedPeddlerTonic.open_stitched(NODE, bad_rank, _pockets(), 20, PRICE))
	for lost in [0, "false", null]:
		var bad_lost := _dolls()
		bad_lost[1].lost = lost
		bad_visits.append(RunStitchedPeddlerTonic.open_stitched(NODE, bad_lost, _pockets(), 20, PRICE))
	var no_lost := _dolls()
	no_lost[0].erase("lost")
	bad_visits.append(RunStitchedPeddlerTonic.open_stitched(NODE, no_lost, _pockets(), 20, PRICE))
	bad_visits.append(RunStitchedPeddlerTonic.open_stitched(NODE, {}, _pockets(), 20, PRICE))
	bad_visits.append(RunStitchedPeddlerTonic.open_stitched(NODE, [1, 2, 3, 4], _pockets(), 20, PRICE))
	# Pockets.
	var missing := _pockets()
	missing.erase("d")
	bad_visits.append(RunStitchedPeddlerTonic.open_stitched(NODE, _dolls(), missing, 20, PRICE))
	var extra := _pockets()
	extra["e"] = []
	bad_visits.append(RunStitchedPeddlerTonic.open_stitched(NODE, _dolls(), extra, 20, PRICE))
	var swapped := _pockets()
	swapped.erase("d")
	swapped["z"] = []
	bad_visits.append(RunStitchedPeddlerTonic.open_stitched(NODE, _dolls(), swapped, 20, PRICE))
	var over := _pockets()
	over.a = ["pins", "dye", "starch"]
	bad_visits.append(RunStitchedPeddlerTonic.open_stitched(NODE, _dolls(), over, 20, PRICE))
	var unknown := _pockets()
	unknown.b = ["forged"]
	bad_visits.append(RunStitchedPeddlerTonic.open_stitched(NODE, _dolls(), unknown, 20, PRICE))
	var not_string := _pockets()
	not_string.b = [3]
	bad_visits.append(RunStitchedPeddlerTonic.open_stitched(NODE, _dolls(), not_string, 20, PRICE))
	var not_array := _pockets()
	not_array.b = "dye"
	bad_visits.append(RunStitchedPeddlerTonic.open_stitched(NODE, _dolls(), not_array, 20, PRICE))
	bad_visits.append(RunStitchedPeddlerTonic.open_stitched(NODE, _dolls(), [], 20, PRICE))
	# Wallet and price.
	for gold in [-1, 1.5, "20", null, true]:
		bad_visits.append(RunStitchedPeddlerTonic.open_stitched(NODE, _dolls(), _pockets(), gold, PRICE))
	for price in [0, -3, 2.5, "7", null, true]:
		bad_visits.append(RunStitchedPeddlerTonic.open_stitched(NODE, _dolls(), _pockets(), 20, price))
	_check(bad_visits.size() >= 35, "malformed witnesses are non-vacuous")
	for visit in bad_visits:
		_check(not visit.is_valid() and not visit.is_open(), "malformed admission fails closed")
		_check(not visit.read_state().ok and not visit.quote().ok and visit.quote().choices == [], "invalid visit quotes nothing")
		var forged: Dictionary = visit.read_state()
		_check(not visit.buy("a", NODE, forged).ok and not visit.leave(NODE, forged).ok, "invalid visit has no actionable purchase")
	# Zero gold is legal.
	_check(_open(0).is_valid(), "zero wallet is admitted")


func _purchase() -> void:
	seed(4242)
	var visit := _open()
	var before := visit.read_state()
	var receipt := visit.buy("b", NODE, before)
	_check(receipt.ok and receipt.decision == "buy_thimble_tonic" and receipt.item == "thimble_tonic", "buy succeeds")
	_check(receipt.target_id == "b" and receipt.charged_gold == PRICE and receipt.price == PRICE, "receipt names target and exact charge")
	_check(receipt.gold == 20 - PRICE, "wallet debited exactly once")
	var expected := _pockets()
	expected.b = ["thimble_tonic"]
	_check(receipt.pockets == expected, "tonic appended to ONLY the chosen pocket")
	_check(receipt.dolls == _dolls(), "dolls, ranks, HP and fray unchanged")
	_check(receipt.node_id == NODE and receipt.consumed and not visit.is_open() and visit.is_consumed(), "visit closes")
	_check(visit.read_state().pockets == expected and visit.read_state().gold == 20 - PRICE, "state commits the purchase")
	receipt.pockets.a.clear()
	receipt.dolls[0].hp = -5
	_check(visit.read_state().pockets == expected and visit.read_state().dolls == _dolls(), "receipt is detached")
	# Existing items keep order: append after the existing item.
	var visit_a := _open()
	var receipt_a := visit_a.buy("a", NODE, visit_a.read_state())
	_check(receipt_a.ok and receipt_a.pockets.a == ["thimble_tonic", "thimble_tonic"], "append keeps existing item first")
	_check(receipt_a.pockets.c == ["pins", "spare_spool"], "other pockets keep their items and order")
	# Exact-price wallet leaves zero.
	var exact := _open(PRICE)
	_check(exact.buy("a", NODE, exact.read_state()).gold == 0, "exact wallet spends to zero")
	# Hanging doll can receive.
	var hang := _pockets()
	hang.c = []
	var open_hang := RunStitchedPeddlerTonic.open_stitched(NODE, _dolls(), hang, 20, PRICE)
	var hang_receipt := open_hang.buy("c", NODE, open_hang.read_state())
	_check(hang_receipt.ok and hang_receipt.pockets.c == ["thimble_tonic"], "HP-0 non-LOST doll receives the tonic")
	# Replay determinism between independent services.
	var one := _open()
	var two := _open()
	_check(one.buy("a", NODE, one.read_state()) == two.buy("a", NODE, two.read_state()), "independent services replay identically")
	var after := randi()
	seed(4242)
	_check(after == randi(), "global RNG untouched by quote, buy and replay")
	# Consumed visit: repeat buy and leave refused with no change.
	var committed := visit.read_state()
	_check(not visit.buy("b", NODE, committed).ok and visit.read_state() == committed, "repeat buy refused")
	_check(not visit.buy("a", NODE, before).ok and visit.read_state() == committed, "stale replay buy refused")
	_check(not visit.leave(NODE, committed).ok and visit.read_state() == committed, "leave after buy refused")
	_check(not visit.quote().ok and visit.quote().choices == [], "closed visit quotes no choices")


func _refusals() -> void:
	var visit := _open()
	var before := visit.read_state()
	_refuse(visit, visit.buy("c", NODE, before), before, "full pocket")
	_refuse(visit, visit.buy("d", NODE, before), before, "LOST target")
	_refuse(visit, visit.buy("zzz", NODE, before), before, "unknown target")
	_refuse(visit, visit.buy("", NODE, before), before, "empty target")
	_refuse(visit, visit.buy(1, NODE, before), before, "non-string target")
	_refuse(visit, visit.buy(null, NODE, before), before, "null target")
	_refuse(visit, visit.buy("a", "other_node", before), before, "wrong node")
	_refuse(visit, visit.buy("a", "", before), before, "empty node")
	_refuse(visit, visit.buy("a", null, before), before, "null node")
	_refuse(visit, visit.buy("a", NODE, null), before, "null snapshot")
	_refuse(visit, visit.buy("a", NODE, {}), before, "empty snapshot")
	_refuse(visit, visit.buy("a", NODE, "state"), before, "non-dictionary snapshot")
	var forged: Dictionary = before.duplicate(true)
	forged.gold = 999
	_refuse(visit, visit.buy("a", NODE, forged), before, "forged gold")
	forged = before.duplicate(true)
	forged.pockets.a.append("dye")
	_refuse(visit, visit.buy("a", NODE, forged), before, "forged pockets")
	forged = before.duplicate(true)
	forged.dolls[0].lost = true
	_refuse(visit, visit.buy("a", NODE, forged), before, "forged lost flag")
	forged = before.duplicate(true)
	forged.price = 1
	_refuse(visit, visit.buy("a", NODE, forged), before, "forged price")
	forged = before.duplicate(true)
	forged.status = "used"
	_refuse(visit, visit.buy("a", NODE, forged), before, "forged status")
	# Refusals never spend the visit: a legal buy still works afterwards.
	var ok_receipt := visit.buy("a", NODE, before)
	_check(ok_receipt.ok and ok_receipt.gold == 20 - PRICE, "refusals leave the visit usable")
	# Insufficient funds.
	var poor := _open(PRICE - 1)
	var poor_before := poor.read_state()
	_refuse(poor, poor.buy("a", NODE, poor_before), poor_before, "insufficient funds")
	_check(poor.leave(NODE, poor_before).ok, "poor visit can still leave free")
	# No eligible doll at all.
	var full := {"a": ["pins", "dye"], "b": ["pins", "dye"], "c": ["pins", "dye"], "d": []}
	var all_full := RunStitchedPeddlerTonic.open_stitched(NODE, _dolls(), full, 50, PRICE)
	var full_before := all_full.read_state()
	var full_quote := all_full.quote()
	_check(full_before.eligible == [], "LOST doll d with space is not eligible")
	_check(not full_quote.can_buy and full_quote.blocked != "" and full_quote.choices == ["leave"], "no eligible doll offers only Leave")
	_refuse(all_full, all_full.buy("d", NODE, full_before), full_before, "only LOST doll has space")


func _leave() -> void:
	seed(99)
	var visit := _open()
	var before := visit.read_state()
	_check(not visit.leave("other", before).ok and visit.is_open(), "leave with wrong node refused")
	var stale: Dictionary = before.duplicate(true)
	stale.gold = 1
	_check(not visit.leave(NODE, stale).ok and visit.read_state() == before, "leave with stale snapshot refused")
	var receipt := visit.leave(NODE, before)
	_check(receipt.ok and receipt.decision == "leave" and receipt.charged_gold == 0 and receipt.gold == 20, "leave is free")
	_check(receipt.item == "" and receipt.target_id == "" and receipt.pockets == _pockets(), "leave leaves pockets untouched")
	_check(receipt.dolls == _dolls() and not visit.is_open() and visit.is_consumed(), "leave closes the visit")
	var closed := visit.read_state()
	_check(not visit.leave(NODE, closed).ok and not visit.buy("a", NODE, closed).ok, "closed visit refuses repeat decisions")
	_check(visit.read_state() == closed and closed.pockets == _pockets() and closed.gold == 20, "closed state stays unchanged")
	var after := randi()
	seed(99)
	_check(after == randi(), "global RNG untouched by leave")


func _open_spool(gold: int = 20, pockets: Variant = null) -> RunStitchedPeddlerTonic:
	var p: Variant = _pockets() if pockets == null else pockets
	return RunStitchedPeddlerTonic.open_stitched(NODE, _dolls(), p, gold, PRICE, "spare_spool")


func _legacy_path_witness() -> void:
	var legacy := RunStitchedPeddlerTonic.open_stitched(NODE, _dolls(), _pockets(), 20, PRICE)
	var explicit := RunStitchedPeddlerTonic.open_stitched(NODE, _dolls(), _pockets(), 20, PRICE, "thimble_tonic")
	_check(legacy.is_open() and legacy.read_state().item == "thimble_tonic", "legacy five-argument visit offers thimble_tonic")
	_check(legacy.read_state() == explicit.read_state() and legacy.quote() == explicit.quote(), "default selector equals explicit thimble_tonic")
	_check(legacy.quote().choices == ["buy_thimble_tonic", "leave"] and legacy.quote().price == PRICE, "legacy quote offers only the tonic at the supplied price")
	var receipt := legacy.buy("b", NODE, legacy.read_state())
	var expected := _pockets()
	expected.b = ["thimble_tonic"]
	_check(receipt.ok and receipt.decision == "buy_thimble_tonic" and receipt.item == "thimble_tonic" and receipt.pockets == expected, "legacy path sells exactly one tonic")
	_check(receipt.charged_gold == PRICE and receipt.gold == 20 - PRICE, "legacy path charges the quote once")


func _spool_offer_and_purchase() -> void:
	seed(5151)
	var visit := _open_spool()
	_check(visit.is_valid() and visit.is_open(), "spool visit opens")
	var state := visit.read_state()
	_check(state.item == "spare_spool" and state.price == PRICE and state.gold == 20 and state.node_id == NODE, "spool state shows item, price and wallet")
	_check(state.eligible == ["a", "b"] and state.pockets == _pockets() and state.dolls == _dolls(), "spool state mirrors inputs")
	var quote := visit.quote()
	_check(quote.ok and quote.item == "spare_spool" and quote.price == PRICE and quote.can_buy and quote.blocked == "", "spool quote advertises item and price")
	_check(quote.choices == ["buy_spare_spool", "leave"], "spool quote lists buy_spare_spool and leave")
	var receipt := visit.buy("b", NODE, state)
	_check(receipt.ok and receipt.decision == "buy_spare_spool" and receipt.item == "spare_spool", "spool buy succeeds")
	_check(receipt.target_id == "b" and receipt.price == PRICE and receipt.charged_gold == PRICE, "spool receipt names target and exact charge")
	_check(receipt.gold == 20 - PRICE, "spool wallet debited exactly once")
	var expected := _pockets()
	expected.b = ["spare_spool"]
	_check(receipt.pockets == expected, "exactly one spool appended to ONLY the chosen pocket")
	for id in ["a", "b", "c", "d"]:
		_check((receipt.pockets[id] as Array).size() == (_pockets()[id] as Array).size() + (1 if id == "b" else 0), "pocket size delta for " + id)
	_check(receipt.dolls == _dolls(), "spool purchase leaves hero records unchanged")
	_check(receipt.node_id == NODE and receipt.consumed and receipt.status == "used" and not visit.is_open() and visit.is_consumed(), "spool visit closes")
	_check(visit.read_state().pockets == expected and visit.read_state().gold == 20 - PRICE, "spool state commits the purchase")
	receipt.pockets.a.clear()
	receipt.dolls[0].hp = -5
	_check(visit.read_state().pockets == expected and visit.read_state().dolls == _dolls(), "spool receipt is detached")
	# Existing items keep their order; the spool goes last.
	var visit_a := _open_spool()
	var receipt_a := visit_a.buy("a", NODE, visit_a.read_state())
	_check(receipt_a.ok and receipt_a.pockets.a == ["thimble_tonic", "spare_spool"], "spool appended after the existing item")
	_check(receipt_a.pockets.c == ["pins", "spare_spool"], "other pockets keep items and order")
	# Exact-price wallet spends to zero.
	var exact := _open_spool(PRICE)
	_check(exact.quote().can_buy and exact.buy("a", NODE, exact.read_state()).gold == 0, "exact wallet buys a spool and spends to zero")
	# A Hanging (HP 0, not LOST) doll may receive a spool.
	var hang := _pockets()
	hang.c = []
	var open_hang := _open_spool(20, hang)
	var hang_receipt := open_hang.buy("c", NODE, open_hang.read_state())
	_check(hang_receipt.ok and hang_receipt.pockets.c == ["spare_spool"], "HP-0 non-LOST doll receives the spool")
	# Consumed visit refuses repeats.
	var committed := visit.read_state()
	_check(not visit.buy("a", NODE, committed).ok and visit.read_state() == committed, "repeat spool buy refused")
	_check(not visit.leave(NODE, committed).ok and visit.read_state() == committed, "leave after spool buy refused")
	_check(not visit.quote().ok and visit.quote().choices == [], "closed spool visit quotes nothing")
	var after := randi()
	seed(5151)
	_check(after == randi(), "global RNG untouched by the spool quote and buy")


func _spool_refusals() -> void:
	var visit := _open_spool()
	var before := visit.read_state()
	_refuse(visit, visit.buy("c", NODE, before), before, "spool full pocket")
	_refuse(visit, visit.buy("d", NODE, before), before, "spool LOST target")
	_refuse(visit, visit.buy("zzz", NODE, before), before, "spool unknown target")
	_refuse(visit, visit.buy(null, NODE, before), before, "spool null target")
	_refuse(visit, visit.buy("a", "other_node", before), before, "spool wrong node")
	_refuse(visit, visit.buy("a", NODE, null), before, "spool null snapshot")
	_refuse(visit, visit.buy("a", NODE, {}), before, "spool empty snapshot")
	var forged: Dictionary = before.duplicate(true)
	forged.gold = 999
	_refuse(visit, visit.buy("a", NODE, forged), before, "spool forged gold")
	forged = before.duplicate(true)
	forged.item = "thimble_tonic"
	_refuse(visit, visit.buy("a", NODE, forged), before, "spool forged item")
	forged = before.duplicate(true)
	forged.pockets.a.append("dye")
	_refuse(visit, visit.buy("a", NODE, forged), before, "spool forged pockets")
	forged = before.duplicate(true)
	forged.status = "used"
	_refuse(visit, visit.buy("a", NODE, forged), before, "spool forged status")
	# Cross-node: a snapshot taken from a tonic visit never authorizes a spool purchase.
	var tonic := _open()
	_refuse(visit, visit.buy("a", NODE, tonic.read_state()), before, "spool visit given a tonic snapshot")
	var other := RunStitchedPeddlerTonic.open_stitched("peddler_node_9", _dolls(), _pockets(), 20, PRICE, "spare_spool")
	_refuse(visit, visit.buy("a", NODE, other.read_state()), before, "spool visit given another node's snapshot")
	# A tonic visit refuses a spool snapshot too.
	var tonic_before := tonic.read_state()
	_refuse(tonic, tonic.buy("a", NODE, visit.read_state()), tonic_before, "tonic visit given a spool snapshot")
	# Refusals never spend the visit; a legal buy still works, and replay is refused.
	var ok_receipt := visit.buy("a", NODE, before)
	_check(ok_receipt.ok and ok_receipt.gold == 20 - PRICE and ok_receipt.decision == "buy_spare_spool", "spool refusals leave the visit usable")
	var committed := visit.read_state()
	_check(not visit.buy("a", NODE, before).ok and visit.read_state() == committed, "stale spool replay refused")
	# Unaffordable quote.
	var poor := _open_spool(PRICE - 1)
	var poor_before := poor.read_state()
	var pq := poor.quote()
	_check(pq.ok and pq.item == "spare_spool" and pq.price == PRICE and not pq.can_buy and pq.blocked == "not enough gold" and pq.choices == ["leave"], "unaffordable spool quote offers only Leave")
	_refuse(poor, poor.buy("a", NODE, poor_before), poor_before, "spool insufficient funds")
	_check(poor.leave(NODE, poor_before).ok, "poor spool visit can still leave free")
	# Full pockets / only a LOST doll with space.
	var full := {"a": ["pins", "dye"], "b": ["pins", "dye"], "c": ["pins", "dye"], "d": []}
	var all_full := _open_spool(50, full)
	var full_before := all_full.read_state()
	var full_quote := all_full.quote()
	_check(full_before.eligible == [] and not full_quote.can_buy and full_quote.choices == ["leave"], "full pockets offer only Leave")
	_refuse(all_full, all_full.buy("d", NODE, full_before), full_before, "spool only LOST doll has space")
	_refuse(all_full, all_full.buy("a", NODE, full_before), full_before, "spool all pockets full")


func _spool_invalid_selectors() -> void:
	var bad: Array = []
	for selector in ["", "Spare_Spool", " spare_spool", "spare_spool ", "fresh_stuffing", "starch", "dye", "pins",
			"forged", "buy_spare_spool", "thimble tonic", null, 5, 1.5, true, ["spare_spool"], {"item": "spare_spool"}]:
		bad.append(RunStitchedPeddlerTonic.open_stitched(NODE, _dolls(), _pockets(), 20, PRICE, selector))
	_check(bad.size() >= 15, "invalid selector witnesses are non-vacuous")
	for visit in bad:
		_check(not visit.is_valid() and not visit.is_open(), "invalid selector is inert, not recast as tonic")
		_check(not visit.read_state().ok and not visit.quote().ok and visit.quote().choices == [], "invalid selector quotes nothing")
		var forged: Dictionary = visit.read_state()
		_check(not visit.buy("a", NODE, forged).ok and not visit.leave(NODE, forged).ok, "invalid selector has no actionable decision")
	# The selector does not loosen the other admission rules.
	_check(not RunStitchedPeddlerTonic.open_stitched(NODE, _dolls(), _pockets(), 20, 0, "spare_spool").is_valid(), "spool needs a positive quote")
	_check(not RunStitchedPeddlerTonic.open_stitched(NODE, _dolls(), _pockets(), 20, "7", "spare_spool").is_valid(), "spool needs an integer quote")
	_check(not RunStitchedPeddlerTonic.open_stitched(NODE, _dolls(), _pockets(), -1, PRICE, "spare_spool").is_valid(), "spool needs a nonnegative wallet")
	_check(not RunStitchedPeddlerTonic.open_stitched("", _dolls(), _pockets(), 20, PRICE, "spare_spool").is_valid(), "spool needs a node ID")
	var three := _dolls()
	three.pop_back()
	_check(not RunStitchedPeddlerTonic.open_stitched(NODE, three, _pockets(), 20, PRICE, "spare_spool").is_valid(), "spool needs exactly four dolls")
	var dup_rank := _dolls()
	dup_rank[1].rank = 1
	_check(not RunStitchedPeddlerTonic.open_stitched(NODE, dup_rank, _pockets(), 20, PRICE, "spare_spool").is_valid(), "spool needs unique ranks")
	var unknown := _pockets()
	unknown.b = ["forged"]
	_check(not _open_spool(20, unknown).is_valid(), "spool visit rejects unrecognized pocket items")
	var over := _pockets()
	over.a = ["pins", "dye", "starch"]
	_check(not _open_spool(20, over).is_valid(), "spool visit rejects pockets over two items")


func _spool_leave_and_determinism() -> void:
	seed(8080)
	var visit := _open_spool()
	var before := visit.read_state()
	_check(not visit.leave("other", before).ok and visit.is_open(), "spool leave with wrong node refused")
	var stale: Dictionary = before.duplicate(true)
	stale.gold = 1
	_check(not visit.leave(NODE, stale).ok and visit.read_state() == before, "spool leave with stale snapshot refused")
	var receipt := visit.leave(NODE, before)
	_check(receipt.ok and receipt.decision == "leave" and receipt.charged_gold == 0 and receipt.gold == 20, "spool leave is free")
	_check(receipt.item == "" and receipt.target_id == "" and receipt.pockets == _pockets() and receipt.dolls == _dolls(), "spool leave changes nothing")
	_check(not visit.is_open() and visit.is_consumed(), "spool leave closes the visit")
	var closed := visit.read_state()
	_check(not visit.leave(NODE, closed).ok and not visit.buy("a", NODE, closed).ok, "closed spool visit refuses repeat decisions")
	_check(visit.read_state() == closed and closed.pockets == _pockets() and closed.gold == 20, "closed spool state unchanged")
	# Independent visits with identical inputs and choices replay identically.
	var one := _open_spool()
	var two := _open_spool()
	_check(one.read_state() == two.read_state() and one.quote() == two.quote(), "equal spool visits start equal")
	var r1 := one.buy("b", NODE, one.read_state())
	var r2 := two.buy("b", NODE, two.read_state())
	_check(r1.ok and r1 == r2, "equal spool visits produce equal full receipts")
	_check(one.read_state() == two.read_state(), "equal spool visits end in equal snapshots")
	var after := randi()
	seed(8080)
	_check(after == randi(), "global RNG untouched by spool leave and replay")
