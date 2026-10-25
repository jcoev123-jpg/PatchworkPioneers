class_name RunCampfireVisit
extends RefCounted
## A scene-free, single-decision Campfire visit. The eventual map controller
## supplies the node ID and the complete authoritative run roster, then owns
## applying a successful receipt to its ledgers. This class owns no run ledgers.

const INVALID := "invalid"
const OPEN := "open"
const HEALED := "healed"
const LEFT := "left"

var _node_id: String = ""
var _heroes: Array = []
var _status: String = INVALID


func _init(node_id: Variant = null, run_heroes: Variant = null) -> void:
	if not _valid_node_id(node_id) or typeof(run_heroes) != TYPE_ARRAY:
		return
	# Share exactly Rest's admission rules, including rejecting total defeat.
	# Validate before copying; no invalid data can become an open visit.
	if not RunRestRecovery._is_valid_roster(run_heroes):
		return
	_node_id = node_id
	_heroes = run_heroes.duplicate(true)
	_status = OPEN


func read_state() -> Dictionary:
	return {
		"ok": _status != INVALID,
		"node_id": _node_id,
		"status": _status,
		"heroes": _heroes.duplicate(true),
	}


## A receipt is always the same shape. An unsuccessful attempt has no
## committed decision or publishable roster, and leaves the visit untouched.
func choose_heal(expected_node_id: Variant, expected_heroes: Variant) -> Dictionary:
	if not _matches_open_visit(expected_node_id, expected_heroes):
		return _rejected()
	# Rest remains the single authority for revive-first, floor(30%) and caps.
	var recovery := RunRestRecovery.new(_heroes)
	var healed: Dictionary = recovery.choose_heal()
	if healed.get("ok") != true or typeof(healed.get("heroes")) != TYPE_ARRAY:
		return _rejected()
	_heroes = healed["heroes"].duplicate(true)
	_status = HEALED
	return _receipt("heal")


func leave(expected_node_id: Variant, expected_heroes: Variant) -> Dictionary:
	if not _matches_open_visit(expected_node_id, expected_heroes):
		return _rejected()
	_status = LEFT
	return _receipt("leave")


func _matches_open_visit(expected_node_id: Variant, expected_heroes: Variant) -> bool:
	return _status == OPEN and _valid_node_id(expected_node_id) \
		and expected_node_id == _node_id \
		and typeof(expected_heroes) == TYPE_ARRAY \
		and expected_heroes == _heroes


static func _valid_node_id(candidate: Variant) -> bool:
	if typeof(candidate) != TYPE_STRING:
		return false
	var value: String = candidate
	return not value.is_empty() and value == value.strip_edges()


static func _rejected() -> Dictionary:
	return {"ok": false, "decision": "", "node_id": "", "heroes": []}


func _receipt(decision: String) -> Dictionary:
	return {
		"ok": true,
		"decision": decision,
		"node_id": _node_id,
		"heroes": _heroes.duplicate(true),
	}
