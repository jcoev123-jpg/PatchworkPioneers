class_name RunActBattleOutcome
extends RefCounted
## Scene-independent M03 battle-to-run outcome latch. The RunMap remains the
## authority for route selection; CombatBattleResult remains the authority for
## battle outcomes. Neither map, combat actors nor RNG are mutated here.
##
## get_state() returns a fresh Dictionary:
##   run_status: "ACTIVE", "VICTORY" or "DEFEAT" (run-level outcome)
##   pending_node_id: selected battle node awaiting settlement, or ""
##   settled_node_ids: ordered, copy-safe Array[String] of witnessed battles
##
## A selected Boss, including one with an ACTIVE battle, is not a run victory.
## A lethal change to actors must FIRST be observed by result.evaluate() in
## the combat pipeline; settle_current_battle() never creates that observation.

const ACTIVE := "ACTIVE"
const VICTORY := "VICTORY"
const DEFEAT := "DEFEAT"

var _map: RunMap
var _run_status: String = ACTIVE
var _pending_node_id: String = ""
var _pending_result: CombatBattleResult
var _pending_route: Array[String] = []
var _pending_floors: Array = []
var _pending_generation_revision: int = 0
var _settled_node_ids: Array[String] = []


func _init(run_map: RunMap) -> void:
	_map = run_map


func begin_current_battle(result: CombatBattleResult) -> bool:
	if _map == null or not _map.is_generated() or _run_status != ACTIVE:
		return false
	if not _pending_node_id.is_empty() or _pending_result != null:
		return false
	if result == null or result.get_outcome() != CombatBattleResult.ACTIVE:
		return false
	var node_id := _map.get_current_node_id()
	if node_id.is_empty() or _settled_node_ids.has(node_id):
		return false
	var node := _map.get_node(node_id)
	if node.is_empty() or node.get("id") != node_id:
		return false
	if node.get("floor") != _map.get_current_floor():
		return false
	var kind: Variant = node.get("type")
	if kind != "Fight" and kind != "Elite" and kind != "Boss":
		return false
	if kind == "Boss" and _map.get_current_floor() != RunMap.FLOOR_COUNT:
		return false

	_pending_node_id = node_id
	_pending_result = result
	_pending_route = _map.get_route()
	_pending_floors = _map.get_floors()
	_pending_generation_revision = _map.get_generation_revision()
	return true


func settle_current_battle() -> bool:
	if _map == null or _run_status != ACTIVE:
		return false
	if _pending_result == null or _pending_node_id.is_empty():
		return false
	# Identical seeded graphs/routes still belong to distinct generations.
	# Reject before observing the result or changing any pending/run state.
	if _map.get_generation_revision() != _pending_generation_revision:
		return false
	if not _map.is_generated() or _map.get_current_node_id() != _pending_node_id:
		return false
	# Detect a stale binding even when an external traversal/generation has
	# reused the same ID. No map undo or implicit choice is attempted.
	if _map.get_route() != _pending_route or _map.get_floors() != _pending_floors:
		return false
	var node := _map.get_node(_pending_node_id)
	if node.is_empty() or node.get("floor") != _map.get_current_floor():
		return false
	var kind: Variant = node.get("type")
	if kind != "Fight" and kind != "Elite" and kind != "Boss":
		return false
	if kind == "Boss" and _map.get_current_floor() != RunMap.FLOOR_COUNT:
		return false

	# The caller's combat loop must have called evaluate() already. Calling
	# evaluate() without checking the observed outcome first could manufacture
	# a winner from an unobserved lethal/tied state.
	var observed := _pending_result.get_outcome()
	if observed != CombatBattleResult.VICTORY and observed != CombatBattleResult.DEFEAT:
		return false
	if _pending_result.evaluate() != observed:
		return false

	_settled_node_ids.append(_pending_node_id)
	if observed == CombatBattleResult.DEFEAT:
		_run_status = DEFEAT
	elif kind == "Boss":
		_run_status = VICTORY
	_pending_node_id = ""
	_pending_result = null
	_pending_route.clear()
	_pending_floors.clear()
	_pending_generation_revision = 0
	return true


func get_state() -> Dictionary:
	return {
		"run_status": _run_status,
		"pending_node_id": _pending_node_id,
		"settled_node_ids": _settled_node_ids.duplicate(),
	}
