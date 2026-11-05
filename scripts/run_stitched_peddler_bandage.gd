class_name RunStitchedPeddlerBandage
extends RefCounted
## Scene-free Design v4 Stitched Peddler bandage service (milestone S6, opt-in).
## The future map-stop wiring supplies the authentic node ID, the authoritative
## four-hero status roster, the wallet and an already-authorized positive gold
## quote. This service sells exactly one bandage — removing the integer "bleed"
## status from one chosen bleeding hero — or accepts a free Leave, once. It
## invents no price, samples no stock, routes nothing and draws no RNG.
## Everything it reads or returns is deeply detached.

const INVALID := "invalid"
const OPEN := "open"
const USED := "used"
const LEFT := "left"
const MODE := "stitched"
const BANDAGE := "bandage"
const BUY_BANDAGE := "buy_bandage"
const LEAVE := "leave"
const BLEED := "bleed"
const HERO_COUNT := 4
const MIN_RANK := 1
const MAX_RANK := 4

var _node_id: String = ""
var _status: String = INVALID
var _heroes: Array = []
var _gold := 0
var _quoted_price := 0


## Admits a nonempty trimmed node ID, exactly four distinct hero IDs with ranks
## 1..4 and Dictionary statuses, a nonnegative integer wallet and a strictly
## positive integer caller quote. Anything else stays invalid and inert.
static func open_stitched(node_id: Variant, heroes: Variant, gold: Variant,
		quoted_price: Variant) -> RunStitchedPeddlerBandage:
	var visit := RunStitchedPeddlerBandage.new()
	visit._admit(node_id, heroes, gold, quoted_price)
	return visit


func _admit(node_id: Variant, heroes: Variant, gold: Variant,
		quoted_price: Variant) -> void:
	if not _valid_node_id(node_id):
		return
	var roster := _admitted_roster(heroes)
	if roster.is_empty():
		return
	if typeof(gold) != TYPE_INT or gold < 0:
		return
	# The price is external run-owner input: any positive integer quote is
	# admitted and later charged exactly; this service never invents one.
	if typeof(quoted_price) != TYPE_INT or quoted_price <= 0:
		return
	_node_id = node_id
	_heroes = roster
	_gold = gold
	_quoted_price = quoted_price
	_status = OPEN


static func _valid_node_id(candidate: Variant) -> bool:
	if typeof(candidate) != TYPE_STRING:
		return false
	var value: String = candidate
	return not value.is_empty() and value == value.strip_edges()


## Deep-copied roster, or an empty Array when the authored shape is malformed.
## A record without a Dictionary statuses field is rejected here, so no
## missing status can ever become an actionable Bleed target.
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
		if typeof(id) != TYPE_STRING or str(id).is_empty() or ids.has(id):
			return []
		if typeof(rank) != TYPE_INT or rank < MIN_RANK or rank > MAX_RANK 				or ranks.has(rank):
			return []
		if not (hero.get("statuses") is Dictionary):
			return []
		ids[id] = true
		ranks[rank] = true
	return copy


func is_valid() -> bool:
	return _status != INVALID


func is_open() -> bool:
	return _status == OPEN


func is_consumed() -> bool:
	return _status == USED or _status == LEFT


## Only heroes whose statuses carry a positive integer "bleed" are eligible.
func _eligible_ids() -> Array:
	var eligible: Array = []
	for hero in _heroes:
		var bleed: Variant = (hero["statuses"] as Dictionary).get(BLEED)
		if typeof(bleed) == TYPE_INT and bleed > 0:
			eligible.append(str(hero["id"]))
	return eligible


## Fully detached visit state: node, lifecycle status, Stitched mode, wallet,
## caller quote, deep-copied roster, eligible hero IDs and consumed flag.
func read_state() -> Dictionary:
	if _status == INVALID:
		return {"ok": false, "node_id": "", "status": INVALID, "mode": MODE,
			"gold": 0, "price": 0, "heroes": [], "eligible": [], "consumed": false}
	return {
		"ok": true,
		"node_id": _node_id,
		"status": _status,
		"mode": MODE,
		"gold": _gold,
		"price": _quoted_price,
		"heroes": _heroes.duplicate(true),
		"eligible": _eligible_ids(),
		"consumed": is_consumed(),
	}


## The open quote: the caller's exact price and the genuinely bleeding hero IDs
## are always disclosed, but Buy is offered only when it is actionable (at least
## one bleeding hero and the wallet covers the price). Free Leave is always
## offered. "can_buy"/"blocked" explain why. This is advisory only: authority
## stays in choose_bandage. Closed or invalid visits quote no choices.
func quote() -> Dictionary:
	if _status != OPEN:
		return {"ok": false, "choices": []}
	var eligible := _eligible_ids()
	var blocked := ""
	if eligible.is_empty():
		blocked = "no bleeding heroes"
	elif _gold < _quoted_price:
		blocked = "not enough gold"
	var can_buy := blocked.is_empty()
	var choices: Array = [BUY_BANDAGE, LEAVE] if can_buy else [LEAVE]
	return {
		"ok": true,
		"mode": MODE,
		"node_id": _node_id,
		"item": BANDAGE,
		"price": _quoted_price,
		"gold": _gold,
		"eligible": eligible,
		"can_buy": can_buy,
		"blocked": blocked,
		"choices": choices,
	}


## Buys one bandage for one eligible hero: removes only that hero's integer
## "bleed" key, charges the quoted gold exactly once and consumes the visit.
## Unaffordable, unbled, wrong-node, stale or repeated buys refuse with no
## state change.
func choose_bandage(hero_id: Variant, expected_node_id: Variant,
		expected_snapshot: Variant) -> Dictionary:
	if not _matches_open(expected_node_id, expected_snapshot):
		return _rejected()
	if typeof(hero_id) != TYPE_STRING or not _eligible_ids().has(str(hero_id)):
		return _rejected()
	if _gold < _quoted_price:
		return _rejected()
	for hero in _heroes:
		if str(hero["id"]) == str(hero_id):
			(hero["statuses"] as Dictionary).erase(BLEED)
			break
	_gold -= _quoted_price
	_status = USED
	return {
		"ok": true,
		"decision": BUY_BANDAGE,
		"node_id": _node_id,
		"mode": MODE,
		"status": _status,
		"hero_id": str(hero_id),
		"item": BANDAGE,
		"price": _quoted_price,
		"charged_gold": _quoted_price,
		"gold": _gold,
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
		"node_id": _node_id,
		"mode": MODE,
		"status": _status,
		"charged_gold": 0,
		"gold": _gold,
		"heroes": _heroes.duplicate(true),
		"consumed": true,
	}


func _matches_open(expected_node_id: Variant, expected_snapshot: Variant) -> bool:
	if _status != OPEN or not _valid_node_id(expected_node_id) 			or expected_node_id != _node_id 			or not (expected_snapshot is Dictionary):
		return false
	return expected_snapshot == read_state()


static func _rejected() -> Dictionary:
	return {"ok": false, "decision": "", "node_id": "", "charged_gold": 0, "gold": 0}
