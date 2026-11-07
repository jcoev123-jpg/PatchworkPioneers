class_name RunStitchedPeddlerWalkSupplies
extends RefCounted
## Scene-free Design v4 Stitched Peddler Walk-supplies service (opt-in, one use).
## The future map-stop wiring supplies the authentic node ID, the four-doll
## roster, the four-doll Walk pocket ledger, the wallet and exactly two already
## quoted prepared offers: one "starch" and one "spare_spool". This service sells
## at most one of them into one chosen doll's pocket, or accepts a free Leave,
## once. Neither item's effect fires on purchase and no WHIRR is spent here; the
## Walk applies those when the item is used. It invents no price, samples no
## stock, routes nothing and draws no RNG. Everything it reads or returns is
## deeply detached.

const INVALID := "invalid"
const OPEN := "open"
const USED := "used"
const LEFT := "left"
const MODE := "stitched"
const STARCH := "starch"
const SPARE_SPOOL := "spare_spool"
const BUY := "buy"
const LEAVE := "leave"
const HERO_COUNT := 4
const MIN_RANK := 1
const MAX_RANK := 4
const POCKET_CAP := 2
const OFFER_IDS: Array = [STARCH, SPARE_SPOOL]
const ITEM_IDS: Array = ["thimble_tonic", "fresh_stuffing", "starch", "dye", "pins",
		"spare_spool"]
## Display-only text for the quote: what the item does when USED during a Walk.
## Buying never uses the item; the Walk applies the real effect.
const EFFECT_TEXT: Dictionary = {
	STARCH: "Use during the Walk: this doll starts the next fight with Guard.",
	SPARE_SPOOL: "Use during the Walk: repair a snipped thread or save a part from a Tug.",
}

## Process-local counter that makes every opened visit's ID unique (no RNG).
static var _visits_opened := 0

var _visit_id: String = ""
var _node_id: String = ""
var _status: String = INVALID
var _heroes: Array = []
var _pockets: Dictionary = {}
var _gold := 0
var _offers: Array = []
var _purchased: String = ""


## Admits a nonempty trimmed node ID, exactly four distinct dolls with ranks
## 1..4 and boolean lost flags, an exact four-doll pocket ledger of 0..2 legal
## item IDs each, a nonnegative integer wallet and exactly two prepared offers
## (one starch, one spare_spool) with caller-quoted positive integer prices.
## Anything else stays invalid and inert.
static func open_stitched(node_id: Variant, heroes: Variant, pockets: Variant,
		gold: Variant, prepared_offers: Variant) -> RunStitchedPeddlerWalkSupplies:
	var visit := RunStitchedPeddlerWalkSupplies.new()
	visit._admit(node_id, heroes, pockets, gold, prepared_offers)
	return visit


func _admit(node_id: Variant, heroes: Variant, pockets: Variant, gold: Variant,
		prepared_offers: Variant) -> void:
	if not _valid_node_id(node_id):
		return
	var roster := _admitted_roster(heroes)
	if roster.is_empty():
		return
	var ledger := _admitted_pockets(pockets, roster)
	if ledger.is_empty():
		return
	if typeof(gold) != TYPE_INT or gold < 0:
		return
	var offers := _admitted_offers(prepared_offers)
	if offers.is_empty():
		return
	_visits_opened += 1
	_visit_id = "walk-supplies-" + str(_visits_opened)
	_node_id = node_id
	_heroes = roster
	_pockets = ledger
	_gold = gold
	_offers = offers
	_status = OPEN


static func _valid_node_id(candidate: Variant) -> bool:
	if typeof(candidate) != TYPE_STRING:
		return false
	var value: String = candidate
	return not value.is_empty() and value == value.strip_edges()


## Deep-copied rows in input order, or an empty Array when the shape is wrong.
## The prices are external run-owner input; this service never invents one.
static func _admitted_offers(prepared_offers: Variant) -> Array:
	if not (prepared_offers is Array) or prepared_offers.size() != OFFER_IDS.size():
		return []
	var rows: Array = []
	var seen := {}
	for entry in prepared_offers:
		if not (entry is Dictionary):
			return []
		var id: Variant = entry.get("id")
		var price: Variant = entry.get("price")
		if typeof(id) != TYPE_STRING or not OFFER_IDS.has(id) or seen.has(id):
			return []
		if typeof(price) != TYPE_INT or price <= 0:
			return []
		seen[id] = true
		rows.append({"id": id, "price": price})
	return rows


## Deep-copied roster, or an empty Array when the authored shape is malformed.
static func _admitted_roster(heroes: Variant) -> Array:
	if not (heroes is Array) or heroes.size() != HERO_COUNT:
		return []
	var copy: Array = heroes.duplicate(true)
	var ids := {}
	var ranks := {}
	for hero in copy:
		if not (hero is Dictionary):
			return []
		var id: Variant = hero.get("id")
		var rank: Variant = hero.get("rank")
		if typeof(id) != TYPE_STRING or str(id).strip_edges().is_empty() \
				or ids.has(id):
			return []
		if typeof(rank) != TYPE_INT or rank < MIN_RANK or rank > MAX_RANK \
				or ranks.has(rank):
			return []
		if typeof(hero.get("lost")) != TYPE_BOOL:
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
	for hero in roster:
		var id: String = hero["id"]
		if not copy.has(id):
			return {}
		var pocket: Variant = copy[id]
		if not (pocket is Array) or pocket.size() > POCKET_CAP:
			return {}
		for item in pocket:
			if typeof(item) != TYPE_STRING or not ITEM_IDS.has(item):
				return {}
	for key in copy.keys():
		if typeof(key) != TYPE_STRING:
			return {}
	return copy


func is_valid() -> bool:
	return _status != INVALID


func is_open() -> bool:
	return _status == OPEN


func is_consumed() -> bool:
	return _status == USED or _status == LEFT


## Non-lost dolls with a free pocket slot, in party order.
func _eligible_ids() -> Array:
	var eligible: Array = []
	for hero in _heroes:
		if hero.get("lost") == true:
			continue
		var id := str(hero["id"])
		if (_pockets[id] as Array).size() < POCKET_CAP:
			eligible.append(id)
	return eligible


func _offer_price(item_id: String) -> int:
	for row in _offers:
		if row["id"] == item_id:
			return int(row["price"])
	return 0


## Empty when the offer can actually be bought right now, else the reason.
func _blocked_reason(item_id: String, eligible: Array) -> String:
	if eligible.is_empty():
		return "no doll can carry " + item_id
	if _gold < _offer_price(item_id):
		return "not enough gold"
	return ""


## Fully detached visit state: one-time visit ID, node, lifecycle status, mode,
## wallet, the two quoted rows in input order, deep-copied roster and pocket
## ledger, eligible IDs, the purchased item (once used) and consumed flag.
func read_state() -> Dictionary:
	if _status == INVALID:
		return {"ok": false, "visit_id": "", "node_id": "", "status": INVALID,
			"mode": MODE, "gold": 0, "offers": [], "heroes": [], "pockets": {},
			"eligible": [], "purchased": "", "consumed": false}
	return {
		"ok": true,
		"visit_id": _visit_id,
		"node_id": _node_id,
		"status": _status,
		"mode": MODE,
		"gold": _gold,
		"offers": _offers.duplicate(true),
		"heroes": _heroes.duplicate(true),
		"pockets": _pockets.duplicate(true),
		"eligible": _eligible_ids(),
		"purchased": _purchased,
		"consumed": is_consumed(),
	}


## The open quote: both prepared rows with their exact caller prices and whether
## each can actually be bought, the eligible IDs and a free Leave. Advisory
## only: authority stays in buy. Closed or invalid visits quote no choices.
func quote() -> Dictionary:
	if _status != OPEN:
		return {"ok": false, "choices": []}
	var eligible := _eligible_ids()
	var rows: Array = []
	var choices: Array = []
	for offer in _offers:
		var id: String = offer["id"]
		var blocked := _blocked_reason(id, eligible)
		rows.append({"id": id, "price": offer["price"], "can_buy": blocked.is_empty(),
			"blocked": blocked, "effect_text": str(EFFECT_TEXT[id])})
		if blocked.is_empty():
			choices.append(BUY + "_" + id)
	choices.append(LEAVE)
	return {
		"ok": true,
		"mode": MODE,
		"visit_id": _visit_id,
		"node_id": _node_id,
		"gold": _gold,
		"offers": rows,
		"eligible": eligible,
		"choices": choices,
	}


## Buys one quoted offer for one eligible doll: appends a single item string to
## only that doll's pocket, charges that offer's quoted gold exactly once and
## consumes the whole visit. Any refusal changes nothing and keeps it open.
func buy(item_id: Variant, hero_id: Variant, expected_node_id: Variant,
		expected_snapshot: Variant) -> Dictionary:
	if not _matches_open(expected_node_id, expected_snapshot):
		return _rejected()
	if typeof(item_id) != TYPE_STRING or not OFFER_IDS.has(item_id):
		return _rejected()
	if typeof(hero_id) != TYPE_STRING or not _eligible_ids().has(str(hero_id)):
		return _rejected()
	var item := str(item_id)
	var price := _offer_price(item)
	if price <= 0 or _gold < price:
		return _rejected()
	var id := str(hero_id)
	var before: Array = (_pockets[id] as Array).duplicate(true)
	var pockets_before: Dictionary = _pockets.duplicate(true)
	var gold_before := _gold
	(_pockets[id] as Array).append(item)
	_gold -= price
	_purchased = item
	_status = USED
	return {
		"ok": true,
		"decision": BUY,
		"visit_id": _visit_id,
		"node_id": _node_id,
		"mode": MODE,
		"status": _status,
		"hero_id": id,
		"item": item,
		"price": price,
		"charged_gold": price,
		"gold_before": gold_before,
		"gold": _gold,
		"pocket_before": before,
		"pocket_after": (_pockets[id] as Array).duplicate(true),
		"pockets_before": pockets_before,
		"pockets_after": _pockets.duplicate(true),
		"heroes": _heroes.duplicate(true),
		"consumed": true,
	}


## Leaves for free while the visit is open, closing it exactly once.
func leave(expected_node_id: Variant, expected_snapshot: Variant) -> Dictionary:
	if not _matches_open(expected_node_id, expected_snapshot):
		return _rejected()
	_status = LEFT
	return {
		"ok": true,
		"decision": LEAVE,
		"visit_id": _visit_id,
		"node_id": _node_id,
		"mode": MODE,
		"status": _status,
		"charged_gold": 0,
		"gold": _gold,
		"heroes": _heroes.duplicate(true),
		"pockets": _pockets.duplicate(true),
		"consumed": true,
	}


func _matches_open(expected_node_id: Variant, expected_snapshot: Variant) -> bool:
	if _status != OPEN or not _valid_node_id(expected_node_id) \
			or expected_node_id != _node_id or not (expected_snapshot is Dictionary):
		return false
	return expected_snapshot == read_state()


static func _rejected() -> Dictionary:
	return {"ok": false, "decision": "", "node_id": "", "charged_gold": 0, "gold": 0}
