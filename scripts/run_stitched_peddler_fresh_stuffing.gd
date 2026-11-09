class_name RunStitchedPeddlerFreshStuffing
extends RefCounted
## Scene-free Design v4 Stitched Peddler fresh-stuffing service (opt-in, one use).
## The future map-stop wiring supplies the authentic node ID, the four-doll
## roster, the four-doll Walk pocket ledger, the wallet and an already
## authorized positive gold quote. This service stocks exactly one literal
## "fresh_stuffing" pocket item into one chosen doll's pocket, or accepts a free
## Leave, once. The purchase never heals and never adds WHIRR: those effects
## belong to the later Walk use of the item. It invents no price, samples no
## stock, routes nothing and draws no RNG. Everything it reads or returns is
## deeply detached.

const INVALID := "invalid"
const OPEN := "open"
const USED := "used"
const LEFT := "left"
const MODE := "stitched"
const FRESH_STUFFING := "fresh_stuffing"
const BUY_FRESH_STUFFING := "buy_fresh_stuffing"
const LEAVE := "leave"
## Projection of the established Walk rules for a USED fresh stuffing (never applied
## here): heals 35% HP, 5 WHIRR to use a pocket item plus 10 extra = 15 total.
const EFFECT_TEXT := "Use during the Walk: heal 35% HP; costs 15 WHIRR (5 to use plus 10 extra)."
const HERO_COUNT := 4
const MIN_RANK := 1
const MAX_RANK := 4
const POCKET_CAP := 2
const ITEM_IDS: Array = ["thimble_tonic", "fresh_stuffing", "starch", "dye", "pins",
		"spare_spool"]

## Process-local monotonic counter: no clock, no RNG. Each admitted visit takes
## the next serial, so separately opened visits never share an identity.
static var _next_serial := 1

var _visit_id: String = ""
var _node_id: String = ""
var _status: String = INVALID
var _heroes: Array = []
var _pockets: Dictionary = {}
var _gold := 0
var _quoted_price := 0


## Admits a nonempty trimmed node ID, exactly four distinct dolls with ranks
## 1..4 and boolean lost flags, an exact four-doll pocket ledger of 0..2 legal
## item IDs each, a nonnegative integer wallet and a strictly positive integer
## caller quote. Anything else stays invalid and inert.
static func open_stitched(node_id: Variant, dolls: Variant, pockets: Variant,
		gold: Variant, quoted_price: Variant) -> RunStitchedPeddlerFreshStuffing:
	var visit := RunStitchedPeddlerFreshStuffing.new()
	visit._admit(node_id, dolls, pockets, gold, quoted_price)
	return visit


func _admit(node_id: Variant, dolls: Variant, pockets: Variant, gold: Variant,
		quoted_price: Variant) -> void:
	if not _valid_node_id(node_id):
		return
	var roster := _admitted_roster(dolls)
	if roster.is_empty():
		return
	var ledger := _admitted_pockets(pockets, roster)
	if ledger.is_empty():
		return
	if typeof(gold) != TYPE_INT or gold < 0:
		return
	# The price is external run-owner input: any positive integer quote is
	# admitted and later charged exactly; this service never invents one.
	if typeof(quoted_price) != TYPE_INT or quoted_price <= 0:
		return
	_node_id = node_id
	_heroes = roster
	_pockets = ledger
	_gold = gold
	_quoted_price = quoted_price
	_visit_id = "peddler-fresh-stuffing-visit-%d" \
		% RunStitchedPeddlerFreshStuffing._next_serial
	RunStitchedPeddlerFreshStuffing._next_serial += 1
	_status = OPEN


static func _valid_node_id(candidate: Variant) -> bool:
	if typeof(candidate) != TYPE_STRING:
		return false
	var value: String = candidate
	return not value.is_empty() and value == value.strip_edges()


## Deep-copied roster, or an empty Array when the authored shape is malformed.
static func _admitted_roster(dolls: Variant) -> Array:
	if not (dolls is Array) or dolls.size() != HERO_COUNT:
		return []
	var copy: Array = dolls.duplicate(true)
	var ids := {}
	var ranks := {}
	for doll in copy:
		if not (doll is Dictionary):
			return []
		var id: Variant = doll.get("id")
		var rank: Variant = doll.get("rank")
		if typeof(id) != TYPE_STRING or str(id).strip_edges().is_empty() \
				or ids.has(id):
			return []
		if typeof(rank) != TYPE_INT or rank < MIN_RANK or rank > MAX_RANK \
				or ranks.has(rank):
			return []
		if typeof(doll.get("lost")) != TYPE_BOOL:
			return []
		ids[id] = true
		ranks[rank] = true
	return copy


## Deep-copied pocket ledger keyed by exactly the roster's IDs, or an empty
## Dictionary when it is malformed.
static func _admitted_pockets(pockets: Variant, roster: Array) -> Dictionary:
	if not (pockets is Dictionary) or pockets.size() != HERO_COUNT:
		return {}
	var copy: Dictionary = pockets.duplicate(true)
	for key in copy.keys():
		if typeof(key) != TYPE_STRING:
			return {}
	for doll in roster:
		var id: String = doll["id"]
		if not copy.has(id):
			return {}
		var pocket: Variant = copy[id]
		if not (pocket is Array) or pocket.size() > POCKET_CAP:
			return {}
		for item in pocket:
			if typeof(item) != TYPE_STRING or not ITEM_IDS.has(item):
				return {}
	return copy


func is_valid() -> bool:
	return _status != INVALID


func is_open() -> bool:
	return _status == OPEN


func is_consumed() -> bool:
	return _status == USED or _status == LEFT


## Non-lost dolls with a free pocket position, in party order.
func _eligible_ids() -> Array:
	var eligible: Array = []
	for doll in _heroes:
		if doll.get("lost") == true:
			continue
		var id := str(doll["id"])
		if (_pockets[id] as Array).size() < POCKET_CAP:
			eligible.append(id)
	return eligible


## Fully detached visit state: an opaque instance-local visit_id (so a snapshot
## from one opening can never authorize a decision on another, even with identical
## economic state), node, lifecycle status, mode, wallet, caller
## quote, deep-copied roster and pocket ledger, eligible IDs and consumed flag.
func read_state() -> Dictionary:
	if _status == INVALID:
		return {"ok": false, "visit_id": "", "node_id": "", "status": INVALID,
			"mode": MODE, "gold": 0, "price": 0, "heroes": [], "pockets": {},
			"eligible": [], "consumed": false}
	return {
		"ok": true,
		"visit_id": _visit_id,
		"node_id": _node_id,
		"status": _status,
		"mode": MODE,
		"gold": _gold,
		"price": _quoted_price,
		"heroes": _heroes.duplicate(true),
		"pockets": _pockets.duplicate(true),
		"eligible": _eligible_ids(),
		"consumed": is_consumed(),
	}


## The open quote: item, caller's exact price, the affordable eligible doll IDs
## (empty when the wallet is short) and free Leave. Buy is offered only when
## actionable. Advisory only: authority stays in buy_fresh_stuffing. Closed or
## invalid visits quote no choices.
func quote() -> Dictionary:
	if _status != OPEN:
		return {"ok": false, "choices": []}
	var eligible := _eligible_ids()
	var blocked := ""
	if eligible.is_empty():
		blocked = "no doll can carry fresh stuffing"
	elif _gold < _quoted_price:
		blocked = "not enough gold"
	var can_buy := blocked.is_empty()
	var choices: Array = [BUY_FRESH_STUFFING, LEAVE] if can_buy else [LEAVE]
	return {
		"ok": true,
		"mode": MODE,
		"node_id": _node_id,
		"item": FRESH_STUFFING,
		"price": _quoted_price,
		"gold": _gold,
		"eligible": eligible if can_buy else [],
		"can_buy": can_buy,
		"blocked": blocked,
		"choices": choices,
		"effect_text": EFFECT_TEXT,
	}


## Buys one fresh_stuffingfor one eligible doll: appends a single literal
## "fresh_stuffing" string to only that doll's pocket, charges the quoted gold
## exactly once and consumes the visit. No healing, no WHIRR, nothing else.
## Any refusal changes nothing and keeps the visit open.
func buy_fresh_stuffing(doll_id: Variant, expected_node_id: Variant,
		expected_state: Variant) -> Dictionary:
	if not _matches_open(expected_node_id, expected_state):
		return _rejected()
	if typeof(doll_id) != TYPE_STRING or not _eligible_ids().has(str(doll_id)):
		return _rejected()
	if _gold < _quoted_price:
		return _rejected()
	var id := str(doll_id)
	var before: Array = (_pockets[id] as Array).duplicate(true)
	var pockets_before: Dictionary = _pockets.duplicate(true)
	(_pockets[id] as Array).append(FRESH_STUFFING)
	_gold -= _quoted_price
	_status = USED
	return {
		"ok": true,
		"decision": BUY_FRESH_STUFFING,
		"node_id": _node_id,
		"mode": MODE,
		"status": _status,
		"doll_id": id,
		"item": FRESH_STUFFING,
		"price": _quoted_price,
		"charged_gold": _quoted_price,
		"gold": _gold,
		"pocket_before": before,
		"pocket_after": (_pockets[id] as Array).duplicate(true),
		"pockets_before": pockets_before,
		"pockets_after": _pockets.duplicate(true),
		"heroes": _heroes.duplicate(true),
		"consumed": true,
	}


## Leaves for free while the visit is open, closing it exactly once.
func leave(expected_node_id: Variant, expected_state: Variant) -> Dictionary:
	if not _matches_open(expected_node_id, expected_state):
		return _rejected()
	_status = LEFT
	return {
		"ok": true,
		"decision": LEAVE,
		"node_id": _node_id,
		"mode": MODE,
		"status": _status,
		"charged_gold": 0,
		"gold": _gold,
		"heroes": _heroes.duplicate(true),
		"pockets": _pockets.duplicate(true),
		"consumed": true,
	}


func _matches_open(expected_node_id: Variant, expected_state: Variant) -> bool:
	if _status != OPEN or not _valid_node_id(expected_node_id) \
			or expected_node_id != _node_id or not (expected_state is Dictionary):
		return false
	return expected_state == read_state()


static func _rejected() -> Dictionary:
	return {"ok": false, "decision": "", "node_id": "", "charged_gold": 0, "gold": 0}
