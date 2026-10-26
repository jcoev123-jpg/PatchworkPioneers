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


func quote() -> Dictionary:
	if not is_valid():
		return {}
	return {
		"offers": _purchases.get_stock().trinkets,
		"decisions": ["buy_patch", "leave"]
	}


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
		"ledger": result.state,
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
		"ledger": _purchases.get_state(),
		"source_snapshot": _snapshot.duplicate(true)
	}
