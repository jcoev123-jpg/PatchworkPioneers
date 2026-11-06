class_name RunStitchedPeddlerTonic
extends RefCounted
## Scene-free Design v4 Stitched Peddler thimble-tonic service (S8f prerequisite, opt-in).
## The future map-stop wiring supplies the authentic node ID, the four dolls, the Walk
## pockets (Dictionary doll ID -> Array of item IDs), the wallet and an already-authorized
## positive gold quote. This service sells exactly one selected pocket item
## (thimble_tonic, spare_spool or starch) into ONE chosen not-LOST doll's pocket
## (max two items) or accepts a free Leave, once.
## It only places the item: it never heals, consumes the item, changes WHIRR, ranks or
## HP, rolls randomness, invents a price or samples stock. Everything it reads or
## returns is deeply detached. It is NOT wired into live play yet.

const INVALID := "invalid"
const OPEN := "open"
const USED := "used"
const LEFT := "left"
const MODE := "stitched"
const THIMBLE_TONIC := "thimble_tonic"
const BUY_THIMBLE_TONIC := "buy_thimble_tonic"
const SPARE_SPOOL := "spare_spool"
const BUY_SPARE_SPOOL := "buy_spare_spool"
const STARCH := "starch"
const BUY_STARCH := "buy_starch"
const OFFERS := ["thimble_tonic", "spare_spool", "starch"]
const BUY_LABELS := {THIMBLE_TONIC: BUY_THIMBLE_TONIC, SPARE_SPOOL: BUY_SPARE_SPOOL, STARCH: BUY_STARCH}
const LEAVE := "leave"
const DOLL_COUNT := 4
const MIN_RANK := 1
const MAX_RANK := 4
const POCKET_CAP := 2
const WALK_ITEMS := ["thimble_tonic", "fresh_stuffing", "starch", "dye", "pins", "spare_spool"]

var _node_id: String = ""
var _status: String = INVALID
var _dolls: Array = []
var _pockets: Dictionary = {}
var _gold := 0
var _quoted_price := 0
var _item: String = THIMBLE_TONIC


## Admitsa nonempty trimmed node ID, exactly four distinct dolls with unique ranks 1..4
## and boolean lost flags, one pocket Array (0..2 recognized items) per doll ID, a
## nonnegative integer wallet and a strictly positive integer quote. Else invalid/inert.
## The optional trailing item selects the single offer: "thimble_tonic" (default),
## "spare_spool" or "starch"; any other selector is inert (never recast as a tonic). The
## item is only placed in a pocket here; its later Walk effect (the spool's thread repair,
## starch's next-fight Guard) happens when it is used in a later Walk.
static func open_stitched(node_id: Variant, dolls: Variant, pockets: Variant, gold: Variant,
		quoted_price: Variant, item: Variant = THIMBLE_TONIC) -> RunStitchedPeddlerTonic:
	var visit := RunStitchedPeddlerTonic.new()
	visit._admit(node_id, dolls, pockets, gold, quoted_price, item)
	return visit


func _admit(node_id: Variant, dolls: Variant, pockets: Variant, gold: Variant,
		quoted_price: Variant, item: Variant = THIMBLE_TONIC) -> void:
	if typeof(item) != TYPE_STRING or not OFFERS.has(item):
		return
	if not _valid_id(node_id):
		return
	var ids := _admitted_ids(dolls)
	if ids.is_empty():
		return
	if not _valid_pockets(pockets, ids):
		return
	if typeof(gold) != TYPE_INT or gold < 0:
		return
	# The price is external run-owner input: any positive integer quote is admitted
	# and later charged exactly; this service never invents a tonic price.
	if typeof(quoted_price) != TYPE_INT or quoted_price <= 0:
		return
	_node_id = node_id
	_dolls = (dolls as Array).duplicate(true)
	_pockets = (pockets as Dictionary).duplicate(true)
	_gold = gold
	_quoted_price = quoted_price
	_item = item
	_status = OPEN


static func _valid_id(candidate: Variant) -> bool:
	if typeof(candidate) != TYPE_STRING:
		return false
	var value: String = candidate
	return not value.is_empty() and value == value.strip_edges()


## The four doll IDs in roster order, or an empty Array when the shape is malformed.
static func _admitted_ids(dolls: Variant) -> Array:
	if not (dolls is Array) or (dolls as Array).size() != DOLL_COUNT:
		return []
	var ids: Array = []
	var ranks := {}
	for doll in dolls:
		if not (doll is Dictionary):
			return []
		var id: Variant = doll.get("id")
		var rank: Variant = doll.get("rank")
		if not _valid_id(id) or ids.has(id):
			return []
		if typeof(rank) != TYPE_INT or rank < MIN_RANK or rank > MAX_RANK or ranks.has(rank):
			return []
		if typeof(doll.get("lost")) != TYPE_BOOL:
			return []
		ids.append(id)
		ranks[rank] = true
	return ids


static func _valid_pockets(pockets: Variant, ids: Array) -> bool:
	if not (pockets is Dictionary) or (pockets as Dictionary).size() != DOLL_COUNT:
		return false
	for id in ids:
		if not (pockets as Dictionary).has(id):
			return false
		var pocket: Variant = pockets[id]
		if not (pocket is Array) or (pocket as Array).size() > POCKET_CAP:
			return false
		for item in pocket:
			if typeof(item) != TYPE_STRING or not WALK_ITEMS.has(item):
				return false
	return true


func is_valid() -> bool:
	return _status != INVALID


func is_open() -> bool:
	return _status == OPEN


func is_consumed() -> bool:
	return _status == USED or _status == LEFT


## Doll IDs that are not LOST (HP 0 alone stays valid) and have a free pocket slot.
func _eligible_ids() -> Array:
	var eligible: Array = []
	for doll in _dolls:
		if doll["lost"] == true:
			continue
		if (_pockets[doll["id"]] as Array).size() < POCKET_CAP:
			eligible.append(doll["id"])
	return eligible


## Fully detached visit state: node, lifecycle status, mode, wallet, quoted price, item,
## dolls, pockets, eligible doll IDs and the consumed flag.
func read_state() -> Dictionary:
	if _status == INVALID:
		return {"ok": false, "node_id": "", "status": INVALID, "mode": MODE, "item": THIMBLE_TONIC,
			"gold": 0, "price": 0, "dolls": [], "pockets": {}, "eligible": [], "consumed": false}
	return {
		"ok": true,
		"node_id": _node_id,
		"status": _status,
		"mode": MODE,
		"item": _item,
		"gold": _gold,
		"price": _quoted_price,
		"dolls": _dolls.duplicate(true),
		"pockets": _pockets.duplicate(true),
		"eligible": _eligible_ids(),
		"consumed": is_consumed(),
	}


## The open quote: the caller's exact price and the doll IDs that could receive the item
## are always disclosed; Buy is offered only when actionable. Leave is always offered
## while open. "can_buy"/"blocked" explain why. Advisory only: authority stays in buy().
func quote() -> Dictionary:
	if _status != OPEN:
		return {"ok": false, "choices": []}
	var eligible := _eligible_ids()
	var blocked := ""
	if eligible.is_empty():
		blocked = "no doll can carry another item"
	elif _gold < _quoted_price:
		blocked = "not enough gold"
	var can_buy := blocked.is_empty()
	return {
		"ok": true,
		"mode": MODE,
		"node_id": _node_id,
		"item": _item,
		"price": _quoted_price,
		"gold": _gold,
		"eligible": eligible,
		"can_buy": can_buy,
		"blocked": blocked,
		"choices": [_buy_label(), LEAVE] if can_buy else [LEAVE],
	}


func _buy_label() -> String:
	return BUY_LABELS.get(_item, BUY_THIMBLE_TONIC)


## Buys one of the selected offer item for one eligible doll: appends it to ONLY that pocket, charges the
## quoted gold exactly once and closes the visit. Any refusal changes nothing.
func buy(doll_id: Variant, expected_node_id: Variant, expected_snapshot: Variant) -> Dictionary:
	if not _matches_open(expected_node_id, expected_snapshot):
		return _rejected()
	if typeof(doll_id) != TYPE_STRING or not _eligible_ids().has(doll_id):
		return _rejected()
	if _gold < _quoted_price:
		return _rejected()
	(_pockets[doll_id] as Array).append(_item)
	_gold -= _quoted_price
	_status = USED
	var receipt := _receipt(_buy_label())
	receipt["item"] = _item
	receipt["target_id"] = doll_id
	receipt["price"] = _quoted_price
	receipt["charged_gold"] = _quoted_price
	return receipt


## Leaves for free while the visit is open, closing it exactly once.
func leave(expected_node_id: Variant, expected_snapshot: Variant) -> Dictionary:
	if not _matches_open(expected_node_id, expected_snapshot):
		return _rejected()
	_status = LEFT
	var receipt := _receipt(LEAVE)
	receipt["item"] = ""
	receipt["target_id"] = ""
	receipt["price"] = 0
	receipt["charged_gold"] = 0
	return receipt


func _receipt(decision: String) -> Dictionary:
	return {
		"ok": true,
		"decision": decision,
		"node_id": _node_id,
		"mode": MODE,
		"status": _status,
		"gold": _gold,
		"pockets": _pockets.duplicate(true),
		"dolls": _dolls.duplicate(true),
		"consumed": true,
	}


func _matches_open(expected_node_id: Variant, expected_snapshot: Variant) -> bool:
	if _status != OPEN or not _valid_id(expected_node_id) \
			or expected_node_id != _node_id or not (expected_snapshot is Dictionary):
		return false
	return expected_snapshot == read_state()


static func _rejected() -> Dictionary:
	return {"ok": false, "decision": "", "node_id": "", "item": "", "target_id": "",
		"price": 0, "charged_gold": 0, "gold": 0, "pockets": {}}
