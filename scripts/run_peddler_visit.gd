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

const INVALID := "invalid"
const OPEN := "open"
const USED := "used"
const LEFT := "left"

var _node_id: String = ""
var _status: String = INVALID
var _purchases: RunShopPurchases = null
var _paid_patch: String = ""
var _displacement_settled := false


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
	return _status == OPEN


func is_consumed() -> bool:
	return _status == USED or _status == LEFT


## Route teardown retires an open generation without publishing a decision.
func close() -> void:
	if _status == OPEN:
		_status = LEFT


## Complete detached visit: the node, its lifecycle status, the current run
## ledger and the current offered stock (three cards and one patch, each with
## its authored price and sold flag).
func read_state() -> Dictionary:
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
