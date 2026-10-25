class_name RunSewingCircleVisit
extends RefCounted
## Scene-free single decision. The route owner authenticates the node kind and
## atomically applies the complete successful receipt against source_snapshot.

var _node_id := ""
var _visit_id := ""
var _valid := false
var _consumed := false
var _ledger: Dictionary = {}
var _source: Dictionary = {}


func _init(node_id: Variant = null, deck_ids: Variant = null,
		descriptors: Variant = null, scraps: Variant = null,
		next_stitch_id: Variant = 1) -> void:
	if typeof(node_id) != TYPE_STRING or node_id.is_empty() or node_id != node_id.strip_edges():
		return
	var rest := RunRestStitchCards.new(deck_ids, descriptors, scraps, next_stitch_id)
	if not rest.is_valid():
		return
	_node_id = node_id
	_ledger = rest.get_snapshot()
	_valid = true
	# Instance identity retires callbacks even if a later visit has the same
	# node and ledger. It consumes neither the run RNG nor global randomness.
	_visit_id = JSON.stringify([get_instance_id(), _node_id, _ledger.receipt]).sha256_text()
	_source = read_state()


func is_valid() -> bool:
	return _valid


func is_consumed() -> bool:
	return _consumed


func read_state() -> Dictionary:
	var state := _ledger.duplicate(true)
	state.merge({"valid": _valid, "consumed": _consumed,
		"node_id": _node_id, "visit_id": _visit_id})
	return state


func quote() -> Dictionary:
	return {"ok": _valid and not _consumed, "node_id": _node_id,
		"visit_id": _visit_id, "scrap_cost": RunRestStitchCards.SCRAP_COST,
		"choices": ["upgrade", "stitch", "leave"] if _valid and not _consumed else []}


func upgrade_options() -> Array:
	if not _valid or _consumed:
		return []
	return RunRestCardUpgrade.list_authored_choices(
		_ledger.deck, _ledger.descriptors, _ledger.next_stitch_id).choices


func _stitch_service() -> RunRestStitchCards:
	return RunRestStitchCards.new(_ledger.deck, _ledger.descriptors,
		_ledger.remaining_scraps, _ledger.next_stitch_id)


func stitch_first_options() -> Array:
	if not _valid or _consumed:
		return []
	var rest := _stitch_service()
	return RunRestStitchPairOptions.new(rest, rest.get_snapshot()).first_options()


func stitch_second_options(first_index: Variant) -> Array:
	if not _valid or _consumed:
		return []
	var rest := _stitch_service()
	return RunRestStitchPairOptions.new(rest, rest.get_snapshot()).second_options(first_index)


func stitch_preview(first_index: Variant, second_index: Variant) -> Dictionary:
	if not _valid or _consumed:
		return {}
	var rest := _stitch_service()
	return RunRestStitchPairOptions.new(rest, rest.get_snapshot()).preview(first_index, second_index)


func _matches(visit_id: Variant, node_id: Variant, snapshot: Variant) -> bool:
	return _valid and not _consumed and typeof(visit_id) == TYPE_STRING \
		and typeof(node_id) == TYPE_STRING and typeof(snapshot) == TYPE_DICTIONARY \
		and visit_id == _visit_id and node_id == _node_id and snapshot == _source \
		and read_state() == _source


func choose_upgrade(index: Variant, visit_id: Variant, node_id: Variant,
		snapshot: Variant) -> Dictionary:
	if not _matches(visit_id, node_id, snapshot):
		return {"ok": false}
	var choices := RunRestCardUpgrade.list_authored_choices(
		_ledger.deck, _ledger.descriptors, _ledger.next_stitch_id)
	var rest := RunRestCardUpgrade.new(_ledger.deck, choices.permitted_upgrades,
		_ledger.descriptors, _ledger.next_stitch_id)
	var result := rest.choose_upgrade(index)
	if not result.get("ok", false):
		return {"ok": false}
	_ledger = RunRestStitchCards.new(result.deck, _ledger.descriptors,
		_ledger.remaining_scraps, _ledger.next_stitch_id).get_snapshot()
	return _commit("upgrade", result)


func choose_stitch(first_index: Variant, second_index: Variant, visit_id: Variant,
		node_id: Variant, snapshot: Variant) -> Dictionary:
	if not _matches(visit_id, node_id, snapshot):
		return {"ok": false}
	var rest := _stitch_service()
	var result := rest.choose_stitch(first_index, second_index, _ledger)
	if not result.get("ok", false):
		return {"ok": false}
	_ledger = rest.get_snapshot()
	return _commit("stitch", result)


func leave(visit_id: Variant, node_id: Variant, snapshot: Variant) -> Dictionary:
	if not _matches(visit_id, node_id, snapshot):
		return {"ok": false}
	return _commit("leave", {})


func _commit(action: String, transaction: Dictionary) -> Dictionary:
	_consumed = true
	var result := read_state()
	result.merge({"ok": true, "action": action, "transaction": transaction.duplicate(true),
		"source_snapshot": _source.duplicate(true), "source_receipt": _source.receipt,
		"charged_scraps": RunRestStitchCards.SCRAP_COST if action == "stitch" else 0})
	return result
