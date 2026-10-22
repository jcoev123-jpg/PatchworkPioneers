class_name RunRestStitchCards
extends RefCounted
## Scene-free one-choice Rest stitch transaction. The run owner must commit the
## returned deck, descriptor registry, scraps and allocator cursor atomically.
## Pass the CURRENT authoritative ledger snapshot to choose_stitch: a stale
## snapshot/receipt is rejected rather than overwriting an intervening change.
## No target selection, half effects, passives, combat or RNG occur here.

const SCRAP_COST := 3
const ID_PREFIX := "stitched_"
const MAX_INT := 9223372036854775807

var _catalog := StarterCards.new()
var _deck: Array[String] = []
var _descriptors: Dictionary = {}
var _scraps: int = 0
var _next_id: int = 1
var _valid := false
var _consumed := false
var _source_snapshot: Dictionary = {}


func _init(deck_ids: Variant = null, descriptors: Variant = null, scraps: Variant = null, next_stitch_id: Variant = 1) -> void:
	if typeof(deck_ids) != TYPE_ARRAY or typeof(descriptors) != TYPE_DICTIONARY:
		return
	if typeof(scraps) != TYPE_INT or scraps < 0:
		return
	if typeof(next_stitch_id) != TYPE_INT or next_stitch_id < 1 or next_stitch_id >= MAX_INT:
		return
	_descriptors = descriptors.duplicate(true)
	if not _validate_input(deck_ids, _descriptors, next_stitch_id):
		_descriptors.clear()
		return
	_deck.assign(deck_ids)
	_scraps = scraps
	_next_id = next_stitch_id
	_valid = true
	_source_snapshot = get_snapshot()


## A detached, exact run-ledger/receipt snapshot for optimistic concurrency.
## Retain next_stitch_id even if an owned stitched card is later removed at Shop.
func get_snapshot() -> Dictionary:
	var snapshot := {
		"deck": _deck.duplicate(),
		"descriptors": _descriptors.duplicate(true),
		"remaining_scraps": _scraps,
		"next_stitch_id": _next_id,
		"receipt": "",
	}
	if _valid:
		var sorted_ids: Array = _descriptors.keys()
		sorted_ids.sort()
		var sorted_registry: Array = []
		for id in sorted_ids:
			sorted_registry.append([id, _descriptors[id]])
		snapshot["receipt"] = JSON.stringify([_deck, sorted_registry, _scraps, _next_id]).sha256_text()
	return snapshot


func is_valid() -> bool:
	return _valid


func is_consumed() -> bool:
	return _consumed


## The two indices refer to distinct ORIGINAL instances, not card ID matches.
## Expected snapshot must be the run owner's current deck/registry/currency/
## allocator/receipt at the moment of choice; rejected attempts never latch.
func choose_stitch(first_index: Variant, second_index: Variant, expected_snapshot: Variant) -> Dictionary:
	if not _valid or _consumed or typeof(expected_snapshot) != TYPE_DICTIONARY:
		return _result(false)
	if expected_snapshot != _source_snapshot:
		return _result(false)
	if typeof(first_index) != TYPE_INT or typeof(second_index) != TYPE_INT:
		return _result(false)
	if first_index < 0 or second_index < 0 or first_index >= _deck.size() or second_index >= _deck.size() or first_index == second_index:
		return _result(false)
	if _scraps < SCRAP_COST:
		return _result(false)
	var first_id: String = _deck[first_index]
	var second_id: String = _deck[second_index]
	# Stitched IDs are never catalog cards and cannot be stitched again.
	if not _catalog.has_card(first_id) or not _catalog.has_card(second_id):
		return _result(false)
	var first: Dictionary = _catalog.get_definition(first_id)
	var second: Dictionary = _catalog.get_definition(second_id)
	if first.is_empty() or second.is_empty() or first["owner"] == second["owner"]:
		return _result(false)
	var stitched_id := _format_id(_next_id)
	if _deck.has(stitched_id) or _descriptors.has(stitched_id):
		return _result(false)

	var descriptor := _make_descriptor(stitched_id, first, second)
	# Preserve survivor ordering, inserting the composite at the earlier index.
	var next_deck := _deck.duplicate()
	var insertion_index: int = mini(first_index, second_index)
	next_deck.remove_at(maxi(first_index, second_index))
	next_deck.remove_at(insertion_index)
	next_deck.insert(insertion_index, stitched_id)
	_deck.assign(next_deck)
	_descriptors[stitched_id] = descriptor
	_scraps -= SCRAP_COST
	_next_id += 1
	_consumed = true
	var result := _result(true)
	result["stitched_id"] = stitched_id
	result["descriptor"] = descriptor.duplicate(true)
	result["consumed_indices"] = [first_index, second_index]
	result["consumed_ids"] = [first_id, second_id]
	return result


## Pure legality and ordered definition preview. No spend, targets, effects,
## energy, discard, owner passives or mutable references escape this function.
func preview_play(stitched_id: Variant, hero_snapshots: Variant) -> Dictionary:
	var failure := {"ok": false, "cost": 0, "first_half": {}, "second_half": {}, "halves": []}
	if not _valid or typeof(stitched_id) != TYPE_STRING or not _descriptors.has(stitched_id) or not _deck.has(stitched_id):
		return failure
	if typeof(hero_snapshots) != TYPE_ARRAY or hero_snapshots.size() != CombatParty.PARTY_SIZE:
		return failure
	var by_id: Dictionary = {}
	var slots: Array[int] = []
	for hero in hero_snapshots:
		if typeof(hero) != TYPE_DICTIONARY:
			return failure
		var id: Variant = hero.get("id")
		var position: Variant = hero.get("position")
		var hp: Variant = hero.get("hp")
		if typeof(id) != TYPE_STRING or id.is_empty() or by_id.has(id):
			return failure
		if typeof(position) != TYPE_INT or position < 1 or position > CombatParty.PARTY_SIZE or slots.has(position):
			return failure
		if typeof(hp) != TYPE_INT or hp < 0:
			return failure
		by_id[id] = hero
		slots.append(position)
	var descriptor: Dictionary = _descriptors[stitched_id]
	var first: Dictionary = descriptor["first_half"]
	var second: Dictionary = descriptor["second_half"]
	for half in [first, second]:
		var owner: String = half["owner"]
		if not by_id.has(owner):
			return failure
		var actor: Dictionary = by_id[owner]
		if actor["hp"] <= 0 or not half["from_positions"].has(actor["position"]):
			return failure
	return {
		"ok": true,
		"cost": descriptor["cost"],
		"first_half": first.duplicate(true),
		"second_half": second.duplicate(true),
		"halves": [first.duplicate(true), second.duplicate(true)],
	}


func _result(ok: bool) -> Dictionary:
	var snapshot := get_snapshot()
	snapshot["ok"] = ok
	snapshot["consumed"] = _consumed
	snapshot["stitched_id"] = ""
	snapshot["descriptor"] = {}
	snapshot["consumed_indices"] = []
	snapshot["consumed_ids"] = []
	snapshot["source_receipt"] = _source_snapshot.get("receipt", "")
	return snapshot


func _format_id(number: int) -> String:
	return ID_PREFIX + ("%06d" % number)


func _make_descriptor(id: String, first: Dictionary, second: Dictionary) -> Dictionary:
	return {
		"id": id,
		"display_name": first["display_name"] + " / " + second["display_name"],
		"cost": mini(3, maxi(first["cost"], second["cost"]) + 1),
		"owners": [first["owner"], second["owner"]],
		"half_ids": [first["id"], second["id"]],
		"first_half": first.duplicate(true),
		"second_half": second.duplicate(true),
		"can_upgrade": false,
		"can_stitch": false,
		"illustration_path": first["illustration_path"],
	}


func _validate_input(deck_ids: Array, registry: Dictionary, next_stitch_id: int) -> bool:
	if deck_ids.is_empty():
		return false
	var counts: Dictionary = {}
	for id in deck_ids:
		if typeof(id) != TYPE_STRING or id.is_empty():
			return false
		# A live run deck may carry reward-eligible D2-1 pool base cards as well
		# as starter cards and owned composites. Only authored cards are legal;
		# pool upgrades and unknown IDs still fail closed.
		if not _catalog.has_card(id) and not registry.has(id) \
				and RunPoolCardRewardOffers.resolve_reward_definition(id).is_empty():
			return false
		counts[id] = counts.get(id, 0) + 1
	for id in registry:
		if typeof(id) != TYPE_STRING or not id.begins_with(ID_PREFIX):
			return false
		var suffix: String = id.trim_prefix(ID_PREFIX)
		if not suffix.is_valid_int():
			return false
		var serial: int = suffix.to_int()
		if serial < 1 or serial >= next_stitch_id or _format_id(serial) != id:
			return false
		if counts.get(id, 0) != 1 or _catalog.has_card(id):
			return false
		var descriptor: Variant = registry[id]
		if typeof(descriptor) != TYPE_DICTIONARY:
			return false
		var ids: Variant = descriptor.get("half_ids")
		if typeof(ids) != TYPE_ARRAY or ids.size() != 2:
			return false
		if typeof(ids[0]) != TYPE_STRING or typeof(ids[1]) != TYPE_STRING:
			return false
		if not _catalog.has_card(ids[0]) or not _catalog.has_card(ids[1]):
			return false
		var first: Dictionary = _catalog.get_definition(ids[0])
		var second: Dictionary = _catalog.get_definition(ids[1])
		if first["owner"] == second["owner"]:
			return false
		if descriptor != _make_descriptor(id, first, second):
			return false
	return true
