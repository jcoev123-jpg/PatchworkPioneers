class_name RunUnpickerVisit
extends RefCounted
## Scene-free, one-use Unpicker gold removal or Leave. The eventual run owner
## authenticates the Unpicker node and atomically applies a successful receipt.
## This service never routes, spends scraps, substitutes HP, or draws randomness.

const MAX_INT := 9223372036854775807

var _node_id: String = ""
var _visit_id: String = ""
var _deck: Array[String] = []
var _descriptors: Dictionary = {}
var _gold: int = 0
var _prior_removals: int = 0
var _next_stitch_id: int = 1
var _valid := false
var _consumed := false
var _source_snapshot: Dictionary = {}


func _init(node_id: Variant = null, deck_ids: Variant = null, gold: Variant = null,
        prior_removals: Variant = null, descriptors: Variant = null,
        next_stitch_id: Variant = 1) -> void:
    # The caller confirms the node's actual route type. Never infer it here.
    if typeof(node_id) != TYPE_STRING or node_id.is_empty() or node_id != node_id.strip_edges():
        return
    if typeof(deck_ids) != TYPE_ARRAY or typeof(descriptors) != TYPE_DICTIONARY:
        return
    if typeof(gold) != TYPE_INT or gold < 0 or typeof(prior_removals) != TYPE_INT or prior_removals < 0:
        return
    if prior_removals > (MAX_INT - RunShopCardRemoval.BASE_PRICE) / RunShopCardRemoval.PRICE_STEP:
        return
    if typeof(next_stitch_id) != TYPE_INT:
        return
    var ledger := RunRestStitchCards.new(deck_ids, descriptors, 0, next_stitch_id)
    if not ledger.is_valid():
        return
    _node_id = node_id
    _deck.assign(deck_ids)
    _descriptors = descriptors.duplicate(true)
    _gold = gold
    _prior_removals = prior_removals
    _next_stitch_id = next_stitch_id
    _valid = true
    # Fresh instance-only identity: two independently opened visits can carry the
    # same node, deck, descriptors, gold, prior count and cursor. Their shared
    # economic receipt stays stable, but the visit_id must be unique per instance
    # so an intent captured on an earlier visit cannot authorize this one. The
    # object identity is deterministic and this service still draws no randomness.
    _visit_id = JSON.stringify([get_instance_id(), _node_id, _ledger_receipt()]).sha256_text()
    _source_snapshot = read_state()


func is_valid() -> bool:
    return _valid


func is_consumed() -> bool:
    return _consumed


func _ledger_receipt() -> String:
    if not _valid:
        return ""
    var ids: Array = _descriptors.keys()
    ids.sort()
    var sorted_registry: Array = []
    for id in ids:
        sorted_registry.append([id, _descriptors[id]])
    return JSON.stringify([_node_id, _deck, sorted_registry, _gold,
            _prior_removals, _next_stitch_id]).sha256_text()


## Complete detached source/current state. Supply this as expected_snapshot
## along with its visit_id and node_id for either decision.
func read_state() -> Dictionary:
    return {
        "valid": _valid,
        "consumed": _consumed,
        "visit_id": _visit_id,
        "node_id": _node_id,
        "deck": _deck.duplicate(),
        "descriptors": _descriptors.duplicate(true),
        "gold": _gold,
        "prior_removals": _prior_removals,
        "next_stitch_id": _next_stitch_id,
        "price": RunShopCardRemoval.BASE_PRICE + RunShopCardRemoval.PRICE_STEP * _prior_removals,
        "receipt": _ledger_receipt(),
    }


## Exactly two available decisions; selecting the card is part of remove_card.
func quote() -> Dictionary:
    return {
        "ok": _valid and not _consumed,
        "visit_id": _visit_id,
        "node_id": _node_id,
        "price": RunShopCardRemoval.BASE_PRICE + RunShopCardRemoval.PRICE_STEP * _prior_removals,
        "choices": ["remove_card", "leave"] if _valid and not _consumed else [],
    }


func _matches_source(expected_visit_id: Variant, expected_node_id: Variant,
        expected_snapshot: Variant) -> bool:
    return _valid and not _consumed and typeof(expected_visit_id) == TYPE_STRING \
            and typeof(expected_node_id) == TYPE_STRING \
            and typeof(expected_snapshot) == TYPE_DICTIONARY \
            and expected_visit_id == _visit_id and expected_node_id == _node_id \
            and expected_snapshot == _source_snapshot


## Guard for a staged twin of a still-mounted visit: the ledger the twin was
## built from must still reproduce the source state captured when the visit
## opened, apart from the per-instance fresh visit identity embedded in
## visit_id. This is a drift check only; it never authenticates a decision, so
## an intent captured on a different visit is still refused by the visit's own
## visit_id and snapshot comparison.
func matches_mounted_source(snapshot: Variant) -> bool:
    if not _valid or _consumed or typeof(snapshot) != TYPE_DICTIONARY or snapshot.is_empty():
        return false
    var current := read_state()
    for key in snapshot:
        if key == "visit_id":
            continue
        if current.get(key) != snapshot[key]:
            return false
    return true


## The result is a detached typed-state receipt with an immutable source
## snapshot/receipt for the future route owner's compare-and-swap reconciliation.
func _receipt(ok: bool, action: String = "", removed_card_id: String = "",
        charged_gold: int = 0) -> Dictionary:
    var result := read_state()
    result["ok"] = ok
    result["action"] = action
    result["removed_card_id"] = removed_card_id
    result["charged_gold"] = charged_gold
    result["source_snapshot"] = _source_snapshot.duplicate(true)
    result["source_receipt"] = _source_snapshot.get("receipt", "")
    return result


func remove_card(card_id: Variant, expected_visit_id: Variant,
        expected_node_id: Variant, expected_snapshot: Variant) -> Dictionary:
    if not _matches_source(expected_visit_id, expected_node_id, expected_snapshot):
        return _receipt(false)
    if typeof(card_id) != TYPE_STRING or card_id.is_empty() or card_id != card_id.strip_edges():
        return _receipt(false)
    # Always use the stitch-aware paid helper, even for ordinary cards.
    var paid := RunShopCardRemoval.try_remove_with_stitch_ledger(
            _deck, _descriptors, _next_stitch_id, _gold, _prior_removals, card_id)
    if not paid["ok"]:
        return _receipt(false)
    _deck.assign(paid["deck"])
    _descriptors = paid["descriptors"].duplicate(true)
    _gold = paid["gold"]
    _prior_removals = paid["prior_removals"]
    _next_stitch_id = paid["next_stitch_id"]
    _consumed = true
    return _receipt(true, "remove_card", card_id, paid["price"])


func leave(expected_visit_id: Variant, expected_node_id: Variant,
        expected_snapshot: Variant) -> Dictionary:
    if not _matches_source(expected_visit_id, expected_node_id, expected_snapshot):
        return _receipt(false)
    _consumed = true
    return _receipt(true, "leave")
