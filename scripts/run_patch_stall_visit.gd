class_name RunPatchStallVisit
extends RefCounted
## Deterministic, one-visit, one-decision Patch Stall service.
## Offers three priced power patches to choose from for gold, plus Leave.
## Relies on RunShopPurchases for stock management and transaction logic.

var _node_id: String
var _visit_id: String
var _status: String
var _snapshot: Dictionary
var _purchases: RunShopPurchases
## True only for the opt-in card-free four-hero Stitched visit.
var _stitched: bool = false

## Authored COAT effect source for the advisory Stitched benefit preview.
const COAT_PATCHES_PATH := "res://data/patches/m04_coat_patches.json"


## Opt-in card-free four-hero Stitched Patch Stall. The run owner authenticates
## the node and supplies the three prepared priced patch offers; this visit never
## samples stock, invents a price or draws RNG. It sells at most one patch (it
## does not equip it) or allows Leave. Any invalid input yields an invalid visit.
static func open_stitched(node_id: Variant, party_ids: Variant, owned_patch_ids: Variant,
		gold: Variant, prepared_three_patch_offers: Variant) -> RunPatchStallVisit:
	var invalid := RunPatchStallVisit.new(null, null, null, null, null, null)
	if typeof(party_ids) != TYPE_ARRAY or party_ids.size() != 4 \
			or typeof(owned_patch_ids) != TYPE_ARRAY \
			or typeof(prepared_three_patch_offers) != TYPE_ARRAY:
		return invalid
	for offer in prepared_three_patch_offers:
		if typeof(offer) != TYPE_DICTIONARY or typeof(offer.get("price")) != TYPE_INT or offer["price"] <= 0:
			return invalid
	var stitched := RunPatchStallVisit.new(node_id, party_ids, [], owned_patch_ids, gold, prepared_three_patch_offers)
	if not stitched.is_valid():
		return invalid
	stitched._enter_stitched_mode()
	return stitched


func _enter_stitched_mode() -> void:
	_stitched = true
	_snapshot = {
		"party_ids": _snapshot.party_ids.duplicate(true),
		"owned_patch_ids": _snapshot.owned_trinkets.duplicate(true),
		"gold": _snapshot.gold
	}
	_visit_id = var_to_str([get_instance_id(), _node_id, _snapshot, _purchases.get_stock()]).sha256_text()


## Public ledger projection: legacy keeps the purchase ledger; Stitched exposes
## only party, owned patches and gold (no deck, cards, hand or energy).
func _public_ledger(state: Dictionary) -> Dictionary:
	if not _stitched:
		return state
	return {
		"party_ids": state.party_ids.duplicate(true),
		"owned_patch_ids": state.trinkets.duplicate(true),
		"gold": state.gold
	}


func _init(node_id: Variant, party_ids: Variant, deck_ids: Variant, owned_trinkets: Variant, gold: Variant, prepared_three_patch_offers: Variant) -> void:
	_status = "invalid"
	if typeof(node_id) != TYPE_STRING or node_id.strip_edges().is_empty():
		return
	
	_purchases = RunShopPurchases.new(
		party_ids, deck_ids, owned_trinkets, gold,
		[], prepared_three_patch_offers, "patch_stall"
	)
	if not _purchases.is_valid():
		return
		
	_node_id = node_id.strip_edges()
	_snapshot = {
		"party_ids": party_ids.duplicate(true),
		"deck_ids": deck_ids.duplicate(true),
		"owned_trinkets": owned_trinkets.duplicate(true),
		"gold": gold
	}
	# Bind callbacks to this exact service, even when a node and ledger recur.
	_visit_id = var_to_str([get_instance_id(), _node_id, _snapshot, _purchases.get_stock()]).sha256_text()
	_status = "available"


func is_valid() -> bool:
	return _status != "invalid"


func is_consumed() -> bool:
	return _status == "closed"


func read_state() -> Dictionary:
	if not is_valid():
		return {}
	return {
		"node_id": _node_id,
		"visit_id": _visit_id,
		"status": _status,
		"snapshot": _snapshot.duplicate(true)
	}


## Only an available visit advertises its three priced patches and the two
## decisions. A consumed visit stays authentic (is_valid()/read_state()) but
## advertises neither stock nor actions, so a finished stall cannot be replayed.
func quote() -> Dictionary:
	if not is_valid():
		return {}
	if _status != "available":
		return {"offers": [], "decisions": []}
	var offers: Array = _purchases.get_stock().trinkets
	var decisions: Array = ["buy_patch", "leave"]
	# Stitched only: every row reports its own availability, and Buy Patch is
	# advertised only while some quoted offer is buyable from that same rule. The
	# three priced rows are never hidden or reordered.
	if _stitched:
		var rows: Array = []
		var coat_bonuses := _authored_coat_bonuses()
		var any_buyable := false
		for offer in offers:
			var row: Dictionary = offer.duplicate(true)
			_add_coat_preview(row, coat_bonuses)
			var blocked := _blocked_reason(row)
			row["can_buy"] = blocked.is_empty()
			row["blocked"] = blocked
			any_buyable = any_buyable or blocked.is_empty()
			rows.append(row)
		offers = rows
		if not any_buyable:
			decisions = ["leave"]
	return {
		"offers": offers,
		"decisions": decisions
	}


## Authored COAT max-HP bonuses by patch ID, read from the real catalog; never a
## second balance table. A missing, malformed or non-COAT record yields no entry.
static func _authored_coat_bonuses() -> Dictionary:
	var bonuses := {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COAT_PATCHES_PATH))
	if typeof(parsed) != TYPE_ARRAY:
		return bonuses
	for record in parsed:
		if typeof(record) != TYPE_DICTIONARY or typeof(record.get("id")) != TYPE_STRING \
				or record.get("slot") != "COAT":
			continue
		var bonus: Variant = record.get("max_hp_bonus")
		if (typeof(bonus) != TYPE_INT and typeof(bonus) != TYPE_FLOAT) \
				or not is_finite(float(bonus)) or floor(float(bonus)) != float(bonus) or int(bonus) <= 0:
			continue
		bonuses[record["id"]] = int(bonus)
	return bonuses


## Advisory equip preview for a recognized ordinary COAT row only. The bonus
## applies on equip, never on purchase; nothing here touches stock or gold.
static func _add_coat_preview(row: Dictionary, coat_bonuses: Dictionary) -> void:
	var id: Variant = row.get("id")
	if typeof(id) != TYPE_STRING or not coat_bonuses.has(id):
		return
	row["slot"] = "COAT"
	row["max_hp_bonus"] = coat_bonuses[id]
	row["effect_text"] = "Equip: +%d max HP" % coat_bonuses[id]


## Stitched availability of one quoted row from the service-held gold and its
## sold flag. Sold takes precedence over price; "" means genuinely buyable.
func _blocked_reason(offer: Dictionary) -> String:
	if offer.get("sold") != false:
		return "already owned"
	if typeof(offer.get("price")) != TYPE_INT or offer.price > _snapshot.gold:
		return "not enough gold"
	return ""


func _validate_request(expected_visit_id: Variant, expected_node_id: Variant, expected_snapshot: Variant) -> bool:
	if not is_valid() or _status == "closed":
		return false
	if typeof(expected_visit_id) != TYPE_STRING or expected_visit_id != _visit_id:
		return false
	if typeof(expected_node_id) != TYPE_STRING or expected_node_id != _node_id:
		return false
	if typeof(expected_snapshot) != TYPE_DICTIONARY or expected_snapshot != _snapshot:
		return false
	return true


func buy_patch(patch_id: Variant, expected_visit_id: Variant, expected_node_id: Variant, expected_snapshot: Variant) -> Dictionary:
	if not _validate_request(expected_visit_id, expected_node_id, expected_snapshot):
		return {"ok": false}
	if typeof(patch_id) != TYPE_STRING:
		return {"ok": false}
		
	var result := _purchases.buy("trinket", patch_id)
	if not result.ok:
		return {"ok": false}
		
	_status = "closed"
	return {
		"ok": true,
		"decision": "buy_patch",
		"receipt": result.receipt,
		"ledger": _public_ledger(result.state),
		"source_snapshot": _snapshot.duplicate(true)
	}


## Read-only preflight for the live atomic paid-and-sewn coordinator.
func preview_purchase(patch_id: Variant, expected_visit_id: Variant, expected_node_id: Variant, expected_snapshot: Variant) -> Dictionary:
	if not _validate_request(expected_visit_id, expected_node_id, expected_snapshot) or not patch_id is String:
		return {}
	for offer in quote().offers:
		if offer.id == patch_id and not offer.sold and _snapshot.gold >= offer.price:
			return {"kind": "trinket", "id": patch_id, "price": offer.price}
	return {}


## Consume only an identical successful atomic receipt. Never buy again or
## publish the detached gross inventory: sewing may have destroyed a patch.
func reconcile_purchase(receipt: Variant, expected_visit_id: Variant, expected_node_id: Variant, expected_snapshot: Variant) -> bool:
	if not receipt is Dictionary:
		return false
	var expected := preview_purchase(receipt.get("id"), expected_visit_id, expected_node_id, expected_snapshot)
	if expected.is_empty() or receipt != expected:
		return false
	_status = "closed"
	return true


func leave(expected_visit_id: Variant, expected_node_id: Variant, expected_snapshot: Variant) -> Dictionary:
	if not _validate_request(expected_visit_id, expected_node_id, expected_snapshot):
		return {"ok": false}
		
	_status = "closed"
	return {
		"ok": true,
		"decision": "leave",
		"ledger": _public_ledger(_purchases.get_state()),
		"source_snapshot": _snapshot.duplicate(true)
	}
