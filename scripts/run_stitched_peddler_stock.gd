class_name RunStitchedPeddlerStock
extends RefCounted
## S6-only deterministic foreign-part/ordinary-patch Peddler stock.
## Authored prices, enemy-part identities and the sealed run RNG are the only
## authorities; no legacy card-shop stock is constructed.

const PART_SOURCE := "res://data/parts/enemy_parts.json"
const PATCH_SOURCE := "res://data/shop/stitched_patch_offers.json"

var _node_id := ""
var _offer: Dictionary = {}
var _owned: Array = []
var _gold := 0
var _consumed := false
var _valid := false


static func _authored_patches() -> Dictionary:
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATCH_SOURCE))
	if not document is Dictionary or not document.get("trinkets") is Array:
		return {}
	var powers: Array = RunAuthoredPatchDefinitions.load_power_definitions()
	if powers.is_empty():
		return {}
	var allowed := {}
	for power in powers:
		if not power is Dictionary or not power.get("id") is String:
			return {}
		allowed[power.id] = true
	var prices := {}
	for item in document.trinkets:
		if not item is Dictionary or not item.get("id") is String or not _valid_price(item.get("price")):
			return {}
		var id: String = item.id
		if allowed.has(id):
			if prices.has(id):
				return {}
			prices[id] = int(item.price)
	return prices


static func _valid_price(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value > 0 or (
		typeof(value) == TYPE_FLOAT and is_finite(value) and value > 0
		and value == floor(value) and value <= 2147483647.0)


## Card-free Patch Stall stock: three distinct {"id", "price"} rows drawn from the
## Stitched-only authored patch source through the shared weighted sampler. Every
## input is validated before the RNG is touched; rare records are explicitly []
## and the Heirloom gate false so only this coat-only catalog is ever stocked.
## One or two unowned patches stay buyable and the rows are completed with
## truthful already-owned entries (the visit marks those SOLD). Never mutates the
## caller's owned IDs and never invents a price.
static func sample_stitched_patch_stall_offers(rng: Variant, owned_patch_ids: Variant) -> Dictionary:
	if not rng is RandomNumberGenerator or not owned_patch_ids is Array:
		return {"ok": false}
	var owned := {}
	for id in owned_patch_ids:
		if not id is String or id.strip_edges().is_empty() or owned.has(id):
			return {"ok": false}
		owned[id] = true
	var prices := _authored_patches()
	if prices.is_empty():
		return {"ok": false}
	var candidates: Array = []
	var any_unowned := false
	var ids: Array = prices.keys()
	ids.sort()
	for id in ids:
		candidates.append({"id": id, "price": int(prices[id])})
		any_unowned = any_unowned or not owned.has(id)
	if not any_unowned:
		# Exhausted ordinary stock: offer the first three validated authored rows
		# (sorted IDs, authored prices). Every one is genuinely owned, so the visit
		# marks them SOLD and advertises only Leave. No RNG draw, nothing buyable;
		# the generic sampler intentionally refuses zero unowned and is not called.
		if candidates.size() < 3:
			return {"ok": false}
		return {"ok": true, "offers": candidates.slice(0, 3)}
	return RunShopPurchases.sample_patch_stall_offers(rng, candidates,
		owned_patch_ids.duplicate(true), [], false)


## Preflight both catalogs BEFORE drawing from the caller's canonical RNG.
## A late visitwith every ordinary patch owned still sells the enemy part.
static func sample(rng: RandomNumberGenerator, catalog: Dictionary,
		owned_patches: Array, part_price: int) -> Dictionary:
	if rng == null or catalog.is_empty() or part_price <= 0:
		return {"ok": false}
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(PART_SOURCE))
	if not source is Dictionary or not source.get("parts") is Array:
		return {"ok": false}
	var foreign: Array = []
	var seen := {}
	for entry in source.parts:
		if not entry is Dictionary or not entry.get("id") is String 				or not entry.get("slot") is String or entry.get("owner") != "any":
			return {"ok": false}
		var id: String = entry.id
		if seen.has(id) or not catalog.has(id) or catalog[id].get("slot") != entry.slot:
			return {"ok": false}
		seen[id] = true
		foreign.append(id)
	if foreign.is_empty():
		return {"ok": false}
	var prices := _authored_patches()
	if prices.is_empty():
		return {"ok": false}
	var owned := {}
	for id in owned_patches:
		if not id is String:
			return {"ok": false}
		owned[id] = true
	var patches: Array = []
	for id in prices:
		if not owned.has(id):
			patches.append(id)
	foreign.sort()
	patches.sort()
	var part_id: String = foreign[rng.randi_range(0, foreign.size() - 1)]
	var patch_offer := {}
	if not patches.is_empty():
		var patch_id: String = patches[rng.randi_range(0, patches.size() - 1)]
		patch_offer = {"id": patch_id, "price": int(prices[patch_id])}
	return {"ok": true, "part": {"id": part_id, "tier": 1, "price": part_price},
		"patch": patch_offer}


static func open_stitched(node_id: String, gold: int, owned: Array,
		offer: Dictionary) -> RunStitchedPeddlerStock:
	return RunStitchedPeddlerStock.new(node_id, gold, owned, offer)


func _init(node_id: String = "", gold: int = 0, owned: Array = [], offer: Dictionary = {}) -> void:
	if node_id.is_empty() or gold < 0 or offer.size() != 2 			or not offer.get("id") is String or not _valid_price(offer.get("price")):
		return
	var prices := _authored_patches()
	if prices.is_empty() or not prices.has(offer.id) or int(offer.price) != prices[offer.id] 			or owned.has(offer.id):
		return
	for id in owned:
		if not id is String or owned.count(id) != 1:
			return
	_node_id = node_id
	_gold = gold
	_owned = owned.duplicate(true)
	_offer = {"id": offer.id, "price": int(offer.price)}
	_valid = true


func is_valid() -> bool:
	return _valid


func read_state() -> Dictionary:
	if not _valid:
		return {"ok": false}
	return {"ok": true, "node_id": _node_id, "gold": _gold, "owned": _owned.duplicate(true),
		"offer": _offer.duplicate(true), "consumed": _consumed}


func quote() -> Dictionary:
	if not _valid or _consumed:
		return {"ok": false}
	return {"ok": true, "offer": _offer.duplicate(true),
		"can_buy": _gold >= int(_offer.price)}


func buy_patch(patch_id: String, node_id: String, expected: Dictionary) -> Dictionary:
	if not _valid or _consumed or node_id != _node_id 			or expected != read_state() or patch_id != _offer.id 			or _owned.has(patch_id) or _gold < int(_offer.price):
		return {"ok": false, "charged_gold": 0}
	var before := read_state()
	var price: int = _offer.price
	_gold -= price
	_owned.append(patch_id)
	_consumed = true
	return {"ok": true, "decision": "buy_patch", "charged_gold": price,
		"price": price, "id": patch_id, "gold": _gold,
		"ledger": {"gold": _gold, "owned_patch_ids": _owned.duplicate(true)},
		"source_state": before, "state": read_state()}
