class_name RunRestStitchPairOptions
extends RefCounted
## Read-only, instance-indexed Rest choice model. Never commits the transaction.

var _service: RunRestStitchCards
var _source: Dictionary = {}
var _catalog := StarterCards.new()


func _init(service: RunRestStitchCards = null, source_snapshot: Variant = null) -> void:
	bind(service, source_snapshot)


func bind(service: RunRestStitchCards, source_snapshot: Variant) -> void:
	_service = service
	_source = {}
	if typeof(source_snapshot) == TYPE_DICTIONARY:
		_source = source_snapshot.duplicate(true)


func clear() -> void:
	_service = null
	_source.clear()


func is_available() -> bool:
	if _service == null or not is_instance_valid(_service):
		return false
	if not _service.is_valid() or _service.is_consumed():
		return false
	var current: Dictionary = _service.get_snapshot()
	if _source.is_empty() or current != _source or current.get("receipt", "") == "":
		return false
	# choose_stitch itself insists on the original source snapshot, not
	# merely a newly generated receipt after illicit ledger drift.
	if _service._source_snapshot != _source:
		return false
	if typeof(_source.get("remaining_scraps")) != TYPE_INT or _source["remaining_scraps"] < RunRestStitchCards.SCRAP_COST:
		return false
	if typeof(_source.get("deck")) != TYPE_ARRAY or typeof(_source.get("descriptors")) != TYPE_DICTIONARY:
		return false
	if typeof(_source.get("next_stitch_id")) != TYPE_INT or typeof(_source.get("receipt")) != TYPE_STRING:
		return false
	return true


func source_snapshot() -> Dictionary:
	return _source.duplicate(true) if is_available() else {}


func first_options() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_available():
		return result
	var deck: Array = _source["deck"]
	for index in range(deck.size()):
		var item := _original(index)
		if item.is_empty():
			continue
		# Only show an original with at least one legal cross-owner partner.
		if not _partners(index).is_empty():
			result.append(item)
	return result


func second_options(first_index: Variant) -> Array[Dictionary]:
	if not is_available() or typeof(first_index) != TYPE_INT:
		return []
	return _partners(first_index)


func preview(first_index: Variant, second_index: Variant) -> Dictionary:
	if not is_available() or typeof(first_index) != TYPE_INT or typeof(second_index) != TYPE_INT:
		return {}
	var first := _original(first_index)
	var second := _original(second_index)
	if first.is_empty() or second.is_empty() or first_index == second_index:
		return {}
	if first["owner"] == second["owner"]:
		return {}
	var cost: int = mini(3, maxi(first["cost"], second["cost"]) + 1)
	return {
		"first_index": first_index,
		"second_index": second_index,
		"first_id": first["id"],
		"second_id": second["id"],
		"first_owner": first["owner"],
		"second_owner": second["owner"],
		"first_name": first["name"],
		"second_name": second["name"],
		"first_cost": first["cost"],
		"second_cost": second["cost"],
		# Return the complete original catalog definitions in play order. Each
		# lookup gives a fresh, deep-detached copy (including arrays/effects);
		# the authoritative Rest service alone performs the transaction.
		"first_half": _catalog.get_definition(first["id"]),
		"second_half": _catalog.get_definition(second["id"]),
		"display_name": first["name"] + " / " + second["name"],
		"energy_cost": cost,
		"scrap_cost": RunRestStitchCards.SCRAP_COST,
		"source_receipt": _source["receipt"],
		"source_snapshot": _source.duplicate(true),
	}


func _partners(first_index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var first := _original(first_index)
	if first.is_empty():
		return result
	for index in range(_source["deck"].size()):
		if index == first_index:
			continue
		var second := _original(index)
		if not second.is_empty() and second["owner"] != first["owner"]:
			result.append(second)
	return result


func _original(index: int) -> Dictionary:
	var deck: Array = _source.get("deck", [])
	if index < 0 or index >= deck.size() or typeof(deck[index]) != TYPE_STRING:
		return {}
	var id: String = deck[index]
	# A stitched ID can be a valid deck member, but is never an original.
	if not _catalog.has_card(id):
		return {}
	var definition := _catalog.get_definition(id)
	if definition.is_empty():
		return {}
	return {"index": index, "id": id, "owner": definition["owner"],
		"name": definition["display_name"], "cost": definition["cost"]}
