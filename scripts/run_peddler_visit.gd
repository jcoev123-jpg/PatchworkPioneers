class_name RunPeddlerVisit
extends RefCounted
## A scene-free, single-decision Peddler map-stop visit. The caller supplies the
## authentic node ID, the run party/deck/wallet/patch ledger and the already
## sampled 3+1 Peddler stock; it then owns presenting the four purchasable
## choices plus Leave and publishing an accepted receipt exactly once.
##
## This service never samples stock, invents prices, removes cards, routes the
## map or touches the run RNG. RunShopPurchases remains the single admission
## and purchase authority: one successful card OR patch buy per visit, charged
## once at the authored quote. Everything it reads or returns is detached.
##
## Opt-in Design v4 Stitched candle-stub mode: open_stitched_candle admits a
## caller-quoted gold price for one candle stub (+25 CANDLE up to 100) or
## Leave. It shares no ledger with the legacy card-purchase path; the price
## is external run-owner input and this service never samples or draws RNG.

const INVALID := "invalid"
const OPEN := "open"
const USED := "used"
const LEFT := "left"
# Opt-in Design v4 four-hero Stitched candle-stub mode (open_stitched_candle).
# Its statuses are distinct from every legacy status, so the legacy purchase
# surface can never dereference the missing card-purchase ledger on a
# Stitched visit, and the legacy default constructor never sets these.
const STITCHED := "stitched"
const STITCHED_OPEN := "stitched_open"
const STITCHED_USED := "stitched_used"
const STITCHED_LEFT := "stitched_left"
const CANDLE_MAX := 100
const CANDLE_STUB := "candle_stub"
const CANDLE_STUB_RESTORE := 25
const BUY_CANDLE_STUB := "buy_candle_stub"
const STITCHED_LEAVE := "leave"

var _node_id: String = ""
var _status: String = INVALID
var _purchases: RunShopPurchases = null
var _paid_patch: String = ""
var _displacement_settled := false
# Stitched candle-stub mode only; never set by the legacy constructor.
var _stitched := false
var _candle := 0
var _gold := 0
var _quoted_price := 0


func _init(node_id: Variant = null, party_ids: Variant = null,
		deck_card_ids: Variant = null, owned_patch_ids: Variant = null,
		gold: Variant = null, stock: Variant = null) -> void:
	if not _valid_id(node_id) or not (stock is Dictionary):
		return
	# Only the authentic seeded 3+1 Peddler supplier's admitted stock may open
	# a visit; a rejected result or a hand-built shape stays closed.
	var sampled: Dictionary = stock
	if not (sampled.get("ok") is bool and sampled.get("ok") == true):
		return
	if not (sampled.get("cards") is Array) or not (sampled.get("patches") is Array):
		return
	# The shared purchase ledger validates the complete party, deck, wallet,
	# owned patches and stock before any visit state is published.
	var ledger := RunShopPurchases.new(party_ids, deck_card_ids, owned_patch_ids,
			gold, sampled["cards"], sampled["patches"], "peddler")
	if not ledger.is_valid():
		return
	_node_id = node_id
	_purchases = ledger
	_status = OPEN


func is_valid() -> bool:
	return _status != INVALID


func is_open() -> bool:
	return _status == OPEN or _status == STITCHED_OPEN


func is_consumed() -> bool:
	return _status == USED or _status == LEFT \
			or _status == STITCHED_USED or _status == STITCHED_LEFT


## Route teardown retires an open generation without publishing a decision.
func close() -> void:
	if _status == OPEN:
		_status = LEFT
	elif _status == STITCHED_OPEN:
		_status = STITCHED_LEFT


## Complete detached visit: the node, its lifecycle status, the current run
## ledger and the current offered stock (three cards and one patch, each with
## its authored price and sold flag).
func read_state() -> Dictionary:
	if _stitched:
		return _stitched_state()
	if _status == INVALID:
		return {"ok": false, "node_id": "", "status": INVALID, "state": {}, "stock": {}}
	return {
		"ok": true,
		"node_id": _node_id,
		"status": _status,
		"state": _purchases.get_state(),
		"stock": _purchases.get_stock(),
	}


## Buys exactly one offered card or patch. The caller must present the current
## open node and BOTH exact current snapshots, so a stale callback, a forged
## snapshot or a replay is refused without mutation. A refused buy never
## consumes the visit's Leave.
func choose_purchase(node_id: Variant, expected_state: Variant,
		expected_stock: Variant, kind: Variant, id: Variant) -> Dictionary:
	if not _matches_open_visit(node_id, expected_state, expected_stock):
		return _rejected()
	if not (kind is String) or not (kind == "card" or kind == "trinket") \
			or not _valid_id(id):
		return _rejected()
	var purchase: Dictionary = _purchases.buy(kind, id)
	if purchase.get("ok") != true or not (purchase.get("receipt") is Dictionary):
		return _rejected()
	# The accepted receipt's authored kind, ID and quote come from the shared
	# purchase ledger, never from caller-supplied values.
	var paid: Dictionary = purchase["receipt"]
	if paid.get("kind") != kind or paid.get("id") != id \
			or not (paid.get("price") is int) or paid["price"] < 0:
		return _rejected()
	_status = USED
	_paid_patch = id if kind == "trinket" else ""
	return _receipt("buy", kind, id, paid["price"])


## The sewing bridge settles the destroyed occupied patch in this SAME paid
## ledger. It cannot debit again or settle a different acquisition/replay.
func settle_displaced_patch(displaced: String, acquired: String,
		expected: Dictionary) -> bool:
	if _status != USED or _displacement_settled or _paid_patch != acquired \
		or expected != read_state():
		return false
	if not _purchases.settle_displaced_patch(displaced, acquired, expected.state):
		return false
	_displacement_settled = true
	return true


## Leaves the Peddler without spending or changing any ledger. The same exact
## open node and both current snapshots are required; a visit can be left once.
func leave(node_id: Variant, expected_state: Variant,
		expected_stock: Variant) -> Dictionary:
	if not _matches_open_visit(node_id, expected_state, expected_stock):
		return _rejected()
	_status = LEFT
	return _receipt("leave")


func _matches_open_visit(expected_node_id: Variant, expected_state: Variant,
		expected_stock: Variant) -> bool:
	if _status != OPEN or not _valid_id(expected_node_id) \
			or expected_node_id != _node_id:
		return false
	if not (expected_state is Dictionary) or not (expected_stock is Dictionary):
		return false
	var current := read_state()
	return expected_state == current["state"] and expected_stock == current["stock"]


static func _valid_id(candidate: Variant) -> bool:
	if typeof(candidate) != TYPE_STRING:
		return false
	var value: String = candidate
	return not value.is_empty() and value == value.strip_edges()


static func _rejected() -> Dictionary:
	return {"ok": false, "node_id": "", "decision": "", "state": {}, "stock": {}}


func _receipt(decision: String, kind: String = "", id: String = "",
		price: int = 0) -> Dictionary:
	var current := read_state()
	var receipt := {
		"ok": true,
		"node_id": _node_id,
		"decision": decision,
		"state": current["state"],
		"stock": current["stock"],
	}
	if decision == "buy":
		receipt["kind"] = kind
		receipt["id"] = id
		receipt["price"] = price
	return receipt


# ------------------------------------------------- Stitched candle stub


## Opt-in Design v4 Stitched Peddler candle stub: the future authoritative
## run/stock owner supplies the node, the current CANDLE, the wallet and an
## already-authorized positive gold quote. This service sells exactly one
## candle stub (+25 CANDLE capped at 100) or accepts Leave, once. It samples
## no stock, invents no price, routes nothing and touches no run RNG. The
## legacy six-argument card-purchase constructor is completely unchanged.
static func open_stitched_candle(node_id: Variant, candle: Variant,
		gold: Variant, quoted_price: Variant) -> RunPeddlerVisit:
	var visit := RunPeddlerVisit.new()
	visit._open_stitched_candle(node_id, candle, gold, quoted_price)
	return visit


func _open_stitched_candle(node_id: Variant, candle: Variant, gold: Variant,
		quoted_price: Variant) -> void:
	if not _valid_id(node_id):
		return
	if typeof(candle) != TYPE_INT or candle < 0 or candle > CANDLE_MAX:
		return
	if typeof(gold) != TYPE_INT or gold < 0:
		return
	# The price is external input: any positive integer quote is admitted and
	# later charged exactly; this service never invents a candle-stub price.
	if typeof(quoted_price) != TYPE_INT or quoted_price <= 0:
		return
	_node_id = node_id
	_stitched = true
	_candle = candle
	_gold = gold
	_quoted_price = quoted_price
	_status = STITCHED_OPEN


## Fully detached Stitched state: the node, explicit Stitched mode, lifecycle
## status, current candle, wallet, quoted item and consumed/open flag.
func _stitched_state() -> Dictionary:
	return {
		"ok": _status != INVALID,
		"node_id": _node_id,
		"status": _status,
		"mode": STITCHED,
		"candle": _candle,
		"gold": _gold,
		"item": {
			"id": CANDLE_STUB,
			"restore": CANDLE_STUB_RESTORE,
			"price": _quoted_price,
		},
		"consumed": is_consumed(),
	}


## The Stitched quote: the caller-priced candle stub plus Leave, only while
## the visit is open. A legacy card visit is outside this accessor's scope
## and fails closed with no choices.
func quote() -> Dictionary:
	if not _stitched:
		return {"ok": false, "choices": []}
	var open := _status == STITCHED_OPEN
	return {
		"ok": open,
		"mode": STITCHED,
		"node_id": _node_id,
		"item": CANDLE_STUB,
		"restore": CANDLE_STUB_RESTORE,
		"price": _quoted_price,
		"candle": _candle,
		"gold": _gold,
		"choices": [BUY_CANDLE_STUB, STITCHED_LEAVE] if open else [],
	}


## The single Stitched decision: buy_candle_stub or leave, against the exact
## open node and the complete current open-state snapshot. Any failed
## precondition, stale or forged intent refuses without mutation and keeps
## the visit open for a later legal choice; success consumes it exactly once.
func select_stitched(decision: Variant, expected_node_id: Variant,
		expected_snapshot: Variant) -> Dictionary:
	if not _matches_stitched_open(expected_node_id, expected_snapshot) \
			or not _is_stitched_decision(decision):
		return _stitched_rejected()
	if decision == BUY_CANDLE_STUB:
		# A full candle or an unaffordable quote never pays for no effect.
		if _candle >= CANDLE_MAX or _gold < _quoted_price:
			return _stitched_rejected()
		var candle_before := _candle
		_candle = mini(CANDLE_MAX, _candle + CANDLE_STUB_RESTORE)
		_gold -= _quoted_price
		_status = STITCHED_USED
		return _stitched_receipt(BUY_CANDLE_STUB, candle_before)
	_status = STITCHED_LEFT
	return _stitched_receipt(STITCHED_LEAVE, _candle)


func _matches_stitched_open(expected_node_id: Variant,
		expected_snapshot: Variant) -> bool:
	if not (_stitched and _status == STITCHED_OPEN) \
			or not _valid_id(expected_node_id) \
			or expected_node_id != _node_id \
			or not (expected_snapshot is Dictionary):
		return false
	return expected_snapshot == _stitched_state()


static func _is_stitched_decision(decision: Variant) -> bool:
	if typeof(decision) != TYPE_STRING:
		return false
	return decision == BUY_CANDLE_STUB or decision == STITCHED_LEAVE


static func _stitched_rejected() -> Dictionary:
	return {
		"ok": false,
		"decision": "",
		"node_id": "",
		"mode": "",
		"item": "",
		"price": 0,
		"charged_gold": 0,
		"candle": 0,
		"gold": 0,
	}


func _stitched_receipt(decision: String, candle_before: int) -> Dictionary:
	var receipt := {
		"ok": true,
		"decision": decision,
		"node_id": _node_id,
		"mode": STITCHED,
		"status": _status,
		"candle": _candle,
		"gold": _gold,
		"consumed": true,
		"state": _stitched_state(),
	}
	if decision == BUY_CANDLE_STUB:
		receipt["item"] = CANDLE_STUB
		receipt["price"] = _quoted_price
		receipt["charged_gold"] = _quoted_price
		receipt["candle_before"] = candle_before
		receipt["restored"] = _candle - candle_before
	else:
		receipt["item"] = ""
		receipt["price"] = 0
		receipt["charged_gold"] = 0
	return receipt
