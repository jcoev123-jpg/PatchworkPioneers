class_name RunStitchedPeddlerPart
extends RefCounted
## Scene-free Design v4 (Stitched) Peddler body-part purchase: ONE visit, ONE pre-approved
## tier-I part at a caller-quoted gold price, then buy-or-Leave.
##
## The caller (a later S6 wiring step) must authenticate the real map node, choose the stock and
## the price (the price is NOT decided here: any strictly positive integer is accepted), pass the
## authoritative wallet and the satchel, and commit an accepted receipt. Nothing here touches the
## live run, a scene, cards or randomness, and no clock or token is used.
##
## Satchel records (same shape RunStitchedSewingSwap consumes), at most SATCHEL_CAP of them:
##   {"id": part_id, "slot": "head|arms|torso|legs", "tier": 1|2|3, "torn": bool}
## The offered part is validated against the catalog; its name, slot and owner are derived from
## the catalog entry, never from the caller. A purchase appends exactly
##   {"id": offered_part_id, "slot": catalog_slot, "tier": 1, "torn": false}
## after the existing records, which are preserved in order and untouched.
##
## API: open_stitched(node_id, gold, satchel, catalog_by_id, offered_part_id, quoted_price),
## read_state(), quote(), buy(expected_node_id, expected_state), leave(expected_node_id,
## expected_state). A decision must name the genuine node and present the exact state last
## published (read_state() or a previous receipt's "state"). A stale or forged state, a wrong node,
## a closed (already decided) visit, too little gold or a full satchel fails with
## {"ok": false, "error": ..., "decision": "", "charged_gold": 0} and changes nothing; an
## unaffordable or full-satchel Buy leaves the visit open for a later free Leave.

const SATCHEL_CAP := 6
const OFFER_TIER := 1
const DECISION_BUY := "buy_part"
const DECISION_LEAVE := "leave"
const STATUS_OPEN := "stitched_open"
const STATUS_BOUGHT := "stitched_bought"
const STATUS_LEFT := "stitched_left"
const SATCHEL_FIELDS := ["id", "slot", "tier", "torn"]

var _node_id := ""
var _gold := 0
var _price := 0
var _satchel: Array = []
var _catalog: Dictionary = {}
var _offer_id := ""
var _status := STATUS_OPEN
var _error := ""


## Opens a visit; invalid input yields a closed, unusable visit that reports its error.
static func open_stitched(node_id: Variant, gold: Variant, satchel: Variant, catalog_by_id: Variant,
		offered_part_id: Variant, quoted_price: Variant) -> RunStitchedPeddlerPart:
	return RunStitchedPeddlerPart.new(node_id, gold, satchel, catalog_by_id, offered_part_id, quoted_price)


func _init(node_id: Variant = "", gold: Variant = 0, satchel: Variant = [], catalog_by_id: Variant = {},
		offered_part_id: Variant = "", quoted_price: Variant = 0) -> void:
	_error = _setup(node_id, gold, satchel, catalog_by_id, offered_part_id, quoted_price)


func is_valid() -> bool:
	return _error.is_empty()


func is_open() -> bool:
	return _error.is_empty() and _status == STATUS_OPEN


func is_consumed() -> bool:
	return _error.is_empty() and _status != STATUS_OPEN


## The authoritative snapshot (deep copy). Pass it back as expected_state.
func read_state() -> Dictionary:
	if not _error.is_empty():
		return {"ok": false, "error": _error}
	return {
		"ok": true,
		"node_id": _node_id,
		"status": _status,
		"open": _status == STATUS_OPEN,
		"gold": _gold,
		"satchel": _satchel.duplicate(true),
		"offer": _offer_summary(),
	}


## What the player may do right now. An unaffordable or full-satchel offer is still disclosed
## honestly (with "can_buy": false and a reason); a closed or invalid visit offers no choices.
func quote() -> Dictionary:
	if not _error.is_empty():
		return {"ok": false, "error": _error, "choices": []}
	if _status != STATUS_OPEN:
		return {"ok": false, "error": "visit is closed", "choices": []}
	var blocked := _buy_block()
	return {
		"ok": true,
		"node_id": _node_id,
		"offer": _offer_summary(),
		"price": _price,
		"gold": _gold,
		"satchel_count": _satchel.size(),
		"satchel_max": SATCHEL_CAP,
		"can_buy": blocked.is_empty(),
		"blocked": blocked,
		"choices": [DECISION_BUY, DECISION_LEAVE],
		"state": read_state(),
	}


## Buys the offered tier-I part for exactly the quoted gold, once, and closes the visit.
func buy(expected_node_id: Variant, expected_state: Variant) -> Dictionary:
	var gate := _gate(expected_node_id, expected_state)
	if not gate.is_empty():
		return _fail(gate)
	var blocked := _buy_block()
	if not blocked.is_empty():
		return _fail(blocked)
	var before := read_state()
	var catalog_slot := str(_catalog[_offer_id]["slot"])
	var record := {"id": _offer_id, "slot": catalog_slot, "tier": OFFER_TIER, "torn": false}
	_satchel.append(record)
	_gold -= _price
	_status = STATUS_BOUGHT
	var after := read_state()
	return {
		"ok": true,
		"error": "",
		"decision": DECISION_BUY,
		"node_id": _node_id,
		"price": _price,
		"charged_gold": _price,
		"gold_before": int(before["gold"]),
		"gold": _gold,
		"part": record.duplicate(true),
		"satchel_index": _satchel.size() - 1,
		"satchel": after["satchel"],
		"status": _status,
		"source_state": before,
		"state": after,
	}


## Ends the visit without any charge or equipment change.
func leave(expected_node_id: Variant, expected_state: Variant) -> Dictionary:
	var gate := _gate(expected_node_id, expected_state)
	if not gate.is_empty():
		return _fail(gate)
	var before := read_state()
	_status = STATUS_LEFT
	var after := read_state()
	return {
		"ok": true,
		"error": "",
		"decision": DECISION_LEAVE,
		"node_id": _node_id,
		"price": 0,
		"charged_gold": 0,
		"gold_before": _gold,
		"gold": _gold,
		"satchel": after["satchel"],
		"status": _status,
		"source_state": before,
		"state": after,
	}


func _buy_block() -> String:
	if _gold < _price:
		return "not enough gold"
	if _satchel.size() >= SATCHEL_CAP:
		return "satchel is full"
	return ""


func _gate(expected_node_id: Variant, expected_state: Variant) -> String:
	if not _error.is_empty():
		return _error
	if _status != STATUS_OPEN:
		return "visit is closed"
	if typeof(expected_node_id) != TYPE_STRING or str(expected_node_id) != _node_id:
		return "wrong node"
	if not expected_state is Dictionary:
		return "expected state must be a dictionary"
	if JSON.stringify(expected_state, "", true) != JSON.stringify(read_state(), "", true):
		return "stale or forged state"
	return ""


func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "decision": "", "charged_gold": 0, "state": read_state()}


func _offer_summary() -> Dictionary:
	var entry: Dictionary = _catalog[_offer_id]
	var ability: Dictionary = StitchedParts.ability_at_tier(entry, OFFER_TIER)
	return {
		"id": _offer_id,
		"name": str(entry["name"]),
		"slot": str(entry["slot"]),
		"owner": str(entry["owner"]),
		"tier": OFFER_TIER,
		"torn": false,
		"price": _price,
		"ability": {"id": str(ability["id"]), "name": str(ability["name"]), "kind": str(ability["kind"])},
		"stat": StitchedParts.stat_at_tier(entry, OFFER_TIER),
		"text": str(entry["text"]),
	}


func _setup(node_id: Variant, gold: Variant, satchel: Variant, catalog_by_id: Variant,
		offered_part_id: Variant, quoted_price: Variant) -> String:
	if typeof(node_id) != TYPE_STRING or str(node_id).is_empty() or str(node_id) != str(node_id).strip_edges():
		return "node id must be a nonempty trimmed string"
	if typeof(gold) != TYPE_INT or int(gold) < 0:
		return "gold must be a nonnegative integer"
	if typeof(quoted_price) != TYPE_INT or int(quoted_price) <= 0:
		return "quoted price must be a positive integer"
	if not catalog_by_id is Dictionary or catalog_by_id.is_empty():
		return "catalog is missing"
	for key in catalog_by_id:
		var entry: Variant = catalog_by_id[key]
		if typeof(key) != TYPE_STRING or not entry is Dictionary:
			return "catalog entry is malformed"
		if str(entry.get("id", "")) != str(key) or not str(entry.get("slot", "")) in StitchedParts.SLOTS:
			return "catalog entry is malformed: " + str(key)
		if not entry.get("ability") is Dictionary or not entry.has("name") or not entry.has("owner") \
				or not entry.has("text"):
			return "catalog entry is incomplete: " + str(key)
		if not entry["ability"].has("id") or not entry["ability"].has("name") or not entry["ability"].has("kind"):
			return "catalog ability is incomplete: " + str(key)
	if typeof(offered_part_id) != TYPE_STRING or not catalog_by_id.has(str(offered_part_id)):
		return "offered part is not in the catalog"
	if not satchel is Array or satchel.size() > SATCHEL_CAP:
		return "satchel holds at most %d parts" % SATCHEL_CAP
	var clean_satchel: Array = []
	for raw in satchel:
		var result := _normalize_spare(raw, catalog_by_id)
		if not bool(result["ok"]):
			return "satchel: " + str(result["error"])
		clean_satchel.append(result["part"])
	_catalog = catalog_by_id.duplicate(true)
	_satchel = clean_satchel
	_node_id = str(node_id)
	_gold = int(gold)
	_price = int(quoted_price)
	_offer_id = str(offered_part_id)
	_status = STATUS_OPEN
	return ""


## Validates one satchel record against the catalog; only the four known fields are accepted.
func _normalize_spare(raw: Variant, catalog_by_id: Dictionary) -> Dictionary:
	if not raw is Dictionary or raw.size() != SATCHEL_FIELDS.size():
		return {"ok": false, "error": "record is missing or malformed", "part": {}}
	for field in SATCHEL_FIELDS:
		if not raw.has(field):
			return {"ok": false, "error": "record is missing " + field, "part": {}}
	if typeof(raw["id"]) != TYPE_STRING or not catalog_by_id.has(str(raw["id"])):
		return {"ok": false, "error": "unknown part id", "part": {}}
	var catalog_slot := str(catalog_by_id[str(raw["id"])]["slot"])
	if typeof(raw["slot"]) != TYPE_STRING or str(raw["slot"]) != catalog_slot:
		return {"ok": false, "error": "part %s does not fit its slot" % str(raw["id"]), "part": {}}
	var tier: Variant = raw["tier"]
	var tier_ok := typeof(tier) == TYPE_INT
	if typeof(tier) == TYPE_FLOAT:
		var tier_float := float(tier)
		tier_ok = is_finite(tier_float) and tier_float == floorf(tier_float)
	if not tier_ok or int(tier) < StitchedParts.MIN_TIER or int(tier) > StitchedParts.MAX_TIER:
		return {"ok": false, "error": "invalid tier", "part": {}}
	if typeof(raw["torn"]) != TYPE_BOOL:
		return {"ok": false, "error": "torn must be a boolean", "part": {}}
	return {
		"ok": true,
		"error": "",
		"part": {"id": str(raw["id"]), "slot": catalog_slot, "tier": int(tier), "torn": bool(raw["torn"])},
	}
