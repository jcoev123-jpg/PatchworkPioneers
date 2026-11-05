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
# Opt-in Stitched FRAY-calming mode (see open_stitched). Never set by the legacy
# constructor, so every six-argument card-removal visit is unchanged.
var _stitched := false
var _heroes: Array = []
var _quoted_price: int = 0
# Opt-in expanded Stitched mode: spare body parts may be unpicked into scraps for a
# caller-supplied positive yield quote. Unset for the original four-argument visit.
var _expanded := false
var _satchel: Array = []
var _scraps: int = 0
var _scrap_yield: int = 0

const SATCHEL_MAX := 6
const SPARE_SLOTS := ["head", "arms", "torso", "legs"]
const STITCHED_PARTY_SIZE := 4
const FRAY_MAX := 200
const CALM_AMOUNT := 50


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


## Opt-in Stitched Unpicker: pay an already-authorized, caller-supplied gold quote
## to calm exactly ONE of four ranked heroes by 50 FRAY, or Leave. The price is
## external input (the run owner's approved quote), never assigned here. Returns
## an invalid visit when any input is malformed. Scene-free, no RNG.
static func open_stitched(node_id: Variant, heroes: Variant, gold: Variant,
        quoted_price: Variant, satchel: Variant = null, scraps: Variant = null,
        quoted_scrap_yield: Variant = null) -> RunUnpickerVisit:
    var visit := RunUnpickerVisit.new()
    visit._open_stitched(node_id, heroes, gold, quoted_price, satchel, scraps, quoted_scrap_yield)
    return visit


## True when the optional satchel, scraps and scrap-yield quote are all well formed.
static func _valid_scrap_inputs(satchel: Variant, scraps: Variant, scrap_yield: Variant) -> bool:
    if typeof(satchel) != TYPE_ARRAY or satchel.size() > SATCHEL_MAX:
        return false
    if typeof(scraps) != TYPE_INT or scraps < 0:
        return false
    if typeof(scrap_yield) != TYPE_INT or scrap_yield <= 0 or scraps > MAX_INT - scrap_yield:
        return false
    for spare in satchel:
        if typeof(spare) != TYPE_DICTIONARY or spare.size() != 4:
            return false
        var id: Variant = spare.get("id")
        var slot: Variant = spare.get("slot")
        var tier: Variant = spare.get("tier")
        var torn: Variant = spare.get("torn")
        if typeof(id) != TYPE_STRING or id.is_empty() or id != id.strip_edges():
            return false
        if typeof(slot) != TYPE_STRING or not SPARE_SLOTS.has(slot):
            return false
        if typeof(tier) != TYPE_INT or tier < 1 or tier > 3 or typeof(torn) != TYPE_BOOL:
            return false
    return true


func _open_stitched(node_id: Variant, heroes: Variant, gold: Variant, quoted_price: Variant,
        satchel: Variant = null, scraps: Variant = null, quoted_scrap_yield: Variant = null) -> void:
    # All three optional inputs omitted keeps the original behavior; all three must
    # be supplied (and valid) to opt in. Any partial set fails closed.
    var supplied := 0
    for extra in [satchel, scraps, quoted_scrap_yield]:
        if extra != null:
            supplied += 1
    if supplied != 0 and (supplied != 3 or not _valid_scrap_inputs(satchel, scraps, quoted_scrap_yield)):
        return
    if typeof(node_id) != TYPE_STRING or node_id.is_empty() or node_id != node_id.strip_edges():
        return
    if typeof(heroes) != TYPE_ARRAY or heroes.size() != STITCHED_PARTY_SIZE:
        return
    if typeof(gold) != TYPE_INT or gold < 0 or typeof(quoted_price) != TYPE_INT or quoted_price <= 0:
        return
    var ids: Dictionary = {}
    var positions: Dictionary = {}
    for hero in heroes:
        if typeof(hero) != TYPE_DICTIONARY:
            return
        var id: Variant = hero.get("id")
        var position: Variant = hero.get("position")
        var fray: Variant = hero.get("fray")
        if typeof(id) != TYPE_STRING or id.is_empty() or id != id.strip_edges() or ids.has(id):
            return
        if typeof(position) != TYPE_INT or position < 1 or position > STITCHED_PARTY_SIZE \
                or positions.has(position):
            return
        if typeof(fray) != TYPE_INT or fray < 0 or fray > FRAY_MAX:
            return
        ids[id] = true
        positions[position] = true
    _node_id = node_id
    _stitched = true
    _heroes = heroes.duplicate(true)
    _gold = gold
    _quoted_price = quoted_price
    if supplied == 3:
        _expanded = true
        _satchel = satchel.duplicate(true)
        _scraps = scraps
        _scrap_yield = quoted_scrap_yield
    _valid = true
    _visit_id = JSON.stringify([get_instance_id(), _node_id, _ledger_receipt()]).sha256_text()
    _source_snapshot = read_state()


func is_valid() -> bool:
    return _valid


func is_consumed() -> bool:
    return _consumed


func _ledger_receipt() -> String:
    if not _valid:
        return ""
    if _stitched:
        if _expanded:
            return JSON.stringify(["stitched", _node_id, _heroes, _gold, _quoted_price,
                    _satchel, _scraps, _scrap_yield]).sha256_text()
        return JSON.stringify(["stitched", _node_id, _heroes, _gold, _quoted_price]).sha256_text()
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
    if _stitched:
        # Stitched mode exposes its own full state; the legacy shape is untouched.
        var state := {
            "valid": _valid,
            "consumed": _consumed,
            "visit_id": _visit_id,
            "node_id": _node_id,
            "mode": "stitched",
            "heroes": _heroes.duplicate(true),
            "gold": _gold,
            "price": _quoted_price,
            "calm_amount": CALM_AMOUNT,
            "receipt": _ledger_receipt(),
        }
        if _expanded:
            state["satchel"] = _satchel.duplicate(true)
            state["scraps"] = _scraps
            state["scrap_yield"] = _scrap_yield
        return state
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
    if _stitched:
        var open := _valid and not _consumed
        # Only name heroes the paid calm can actually help: the party must afford
        # the quote and the hero must have FRAY to remove. Held roster order.
        var hero_ids: Array = []
        if open and _gold >= _quoted_price:
            for hero in _heroes:
                if int(hero["fray"]) > 0:
                    hero_ids.append(hero["id"])
        var choices: Array = []
        if open:
            if not hero_ids.is_empty():
                choices.append("calm_hero")
            if _expanded and not _satchel.is_empty():
                choices.append("unpick_spare")
            choices.append("leave")
        var quoted := {
            "ok": open,
            "visit_id": _visit_id,
            "node_id": _node_id,
            "price": _quoted_price,
            "calm_amount": CALM_AMOUNT,
            "hero_ids": hero_ids,
            "choices": choices,
        }
        if _expanded:
            var spares: Array = []
            var indices: Array = []
            if open:
                for i in _satchel.size():
                    var spare: Dictionary = _satchel[i]
                    indices.append(i)
                    spares.append({"index": i, "id": spare["id"], "slot": spare["slot"],
                            "tier": spare["tier"], "torn": spare["torn"]})
            quoted["spare_indices"] = indices
            quoted["spares"] = spares
            quoted["scrap_yield"] = _scrap_yield
            quoted["scraps"] = _scraps
        return quoted
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
    if _stitched:
        result["calmed_hero_id"] = ""
        result["fray_before"] = 0
        result["fray_after"] = 0
        if _expanded:
            result["removed_part"] = {}
            result["scraps_before"] = _scraps
            result["scraps_after"] = _scraps
            result["credited_scraps"] = 0
    else:
        result["removed_card_id"] = removed_card_id
    result["charged_gold"] = charged_gold
    result["source_snapshot"] = _source_snapshot.duplicate(true)
    result["source_receipt"] = _source_snapshot.get("receipt", "")
    return result


## Stitched mode only: calm exactly one named hero by 50 FRAY (never below zero)
## for the quoted gold. An unaffordable, stale or invalid attempt changes nothing
## and leaves the visit open for Leave. A hero already at 0 FRAY is refused so no
## gold is paid for no effect.
func calm_hero(hero_id: Variant, expected_visit_id: Variant,
        expected_node_id: Variant, expected_snapshot: Variant) -> Dictionary:
    if not _stitched or not _matches_source(expected_visit_id, expected_node_id, expected_snapshot):
        return _receipt(false)
    if typeof(hero_id) != TYPE_STRING or hero_id.is_empty() or hero_id != hero_id.strip_edges():
        return _receipt(false)
    if _gold < _quoted_price:
        return _receipt(false)
    var index := -1
    for i in _heroes.size():
        if _heroes[i]["id"] == hero_id:
            index = i
    if index < 0 or int(_heroes[index]["fray"]) <= 0:
        return _receipt(false)
    var before: int = _heroes[index]["fray"]
    var after: int = maxi(0, before - CALM_AMOUNT)
    _heroes[index]["fray"] = after
    _gold -= _quoted_price
    _consumed = true
    var result := _receipt(true, "calm_hero", "", _quoted_price)
    result["calmed_hero_id"] = hero_id
    result["fray_before"] = before
    result["fray_after"] = after
    return result


## Expanded Stitched mode only: dismantle exactly one spare satchel part (selected
## by index, so repeated IDs stay distinct) into the caller-quoted scrap yield.
## Gold and every hero field are untouched. Any invalid request changes nothing
## and leaves the visit open for Leave.
func unpick_spare(satchel_index: Variant, expected_visit_id: Variant,
        expected_node_id: Variant, expected_snapshot: Variant) -> Dictionary:
    if not _stitched or not _expanded \
            or not _matches_source(expected_visit_id, expected_node_id, expected_snapshot):
        return _receipt(false)
    if typeof(satchel_index) != TYPE_INT or satchel_index < 0 or satchel_index >= _satchel.size():
        return _receipt(false)
    var removed: Dictionary = _satchel[satchel_index].duplicate(true)
    var before := _scraps
    _satchel.remove_at(satchel_index)
    _scraps = before + _scrap_yield
    _consumed = true
    var result := _receipt(true, "unpick_spare")
    result["removed_part"] = removed
    result["scraps_before"] = before
    result["scraps_after"] = _scraps
    result["credited_scraps"] = _scrap_yield
    return result


func remove_card(card_id: Variant, expected_visit_id: Variant,
        expected_node_id: Variant, expected_snapshot: Variant) -> Dictionary:
    if _stitched:
        return _receipt(false)
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
