class_name RunMap
extends RefCounted
## Scene-independent, one-act map. The caller supplies the run's seeded RNG;
## only generate() draws from it. Reading/traversing never draws randomness.
##
## API:
##   generate(rng) -> bool: build/reset a 12-floor graph; null RNG is rejected.
##   get_floors() -> Array[Array[Dictionary]]: deep snapshot in floor/position order.
##   get_node(id) -> Dictionary: deep snapshot, or {} for an unknown ID.
##   get_legal_choices() -> Array[String]: currently selectable node IDs.
##   choose_node(id) -> bool: advance exactly one floor or reject without changes.
##   get_route(), get_current_node_id(), get_current_floor(), is_complete().
##
## Positions are zero-based within each floor; IDs (f01_n0 etc.) are stable
## within a generated graph. A new generate() starts a new route.

const FLOOR_COUNT := 12
const MIN_NODES := 3
const MAX_NODES := 4
const NORMAL_TYPES := ["Fight", "Elite", "Rest", "Shop", "Event", "Treasure"]

var _floor_ids: Array = []
var _nodes: Dictionary = {}
var _route: Array[String] = []


func generate(rng: RandomNumberGenerator) -> bool:
	if rng == null:
		return false

	var new_floors: Array = []
	var new_nodes: Dictionary = {}
	for floor_index in range(FLOOR_COUNT):
		var floor_ids: Array[String] = []
		var count: int = rng.randi_range(MIN_NODES, MAX_NODES)
		for position in range(count):
			var node_id := "f%02d_n%d" % [floor_index + 1, position]
			var kind := "Boss"
			if floor_index < FLOOR_COUNT - 1:
				kind = NORMAL_TYPES[rng.randi_range(0, NORMAL_TYPES.size() - 1)]
			new_nodes[node_id] = {
				"id": node_id,
				"floor": floor_index + 1,
				"position": position,
				"type": kind,
				"outgoing": [],
			}
			floor_ids.append(node_id)
		new_floors.append(floor_ids)

	for floor_index in range(FLOOR_COUNT - 1):
		var sources: Array = new_floors[floor_index]
		var targets: Array = new_floors[floor_index + 1]
		# Both passes matter: every source gets an exit and every target
		# gets an entrance, even when adjacent floors differ in width.
		for source_index in range(sources.size()):
			_add_edge(new_nodes, sources[source_index],
				targets[mini(source_index, targets.size() - 1)])
		for target_index in range(targets.size()):
			_add_edge(new_nodes,
				sources[mini(target_index, sources.size() - 1)], targets[target_index])
		# These two edges cross geometrically, rather than merely branching
		# into parallel lanes; every map contains a crossing and a branch.
		if floor_index == 0:
			_add_edge(new_nodes, sources[0], targets[1])
			_add_edge(new_nodes, sources[1], targets[0])
		# Additional seeded links vary routes without dictating kind weights.
		for source_index in range(sources.size()):
			if rng.randi_range(0, 1) == 1:
				_add_edge(new_nodes, sources[source_index],
					targets[rng.randi_range(0, targets.size() - 1)])

	# Guarantee a supported opening without rerolling the graph or spending RNG.
	var has_opening_fight := false
	for node_id in new_floors[0]:
		if new_nodes[node_id]["type"] == "Fight":
			has_opening_fight = true
			break
	if not has_opening_fight:
		new_nodes[new_floors[0][0]]["type"] = "Fight"

	_floor_ids = new_floors
	_nodes = new_nodes
	_route.clear()
	return true


static func _add_edge(nodes: Dictionary, source_id: String, target_id: String) -> void:
	var source: Dictionary = nodes[source_id]
	var edges: Array = source["outgoing"]
	if not edges.has(target_id):
		edges.append(target_id)


func is_generated() -> bool:
	return not _floor_ids.is_empty()


func get_floors() -> Array:
	var result: Array = []
	for ids in _floor_ids:
		var floor_nodes: Array = []
		for node_id in ids:
			var node: Dictionary = _nodes[node_id]
			floor_nodes.append(node.duplicate(true))
		result.append(floor_nodes)
	return result


func get_node(node_id: String) -> Dictionary:
	if not _nodes.has(node_id):
		return {}
	var node: Dictionary = _nodes[node_id]
	return node.duplicate(true)


func get_legal_choices() -> Array[String]:
	var choices: Array[String] = []
	if not is_generated() or is_complete():
		return choices
	if _route.is_empty():
		choices.assign(_floor_ids[0])
	else:
		choices.assign(_nodes[_route.back()]["outgoing"])
	return choices


func choose_node(node_id: String) -> bool:
	if not get_legal_choices().has(node_id):
		return false
	_route.append(node_id)
	return true


func get_route() -> Array[String]:
	return _route.duplicate()


## Roll back only the caller's just-committed choice, with its exact prior route.
## A mismatched ID, prior route, or advanced route is inert; never draws RNG.
func undo_choice(node_id: String, prior_route: Array[String]) -> bool:
	if _route.is_empty() or _route.back() != node_id or _route.size() != prior_route.size() + 1:
		return false
	if _route.slice(0, -1) != prior_route:
		return false
	_route.pop_back()
	return true


func get_current_node_id() -> String:
	return "" if _route.is_empty() else _route.back()


## 0 before the first choice, 1..12 after choosing on that floor.
func get_current_floor() -> int:
	return _route.size()


func is_complete() -> bool:
	return is_generated() and _route.size() == FLOOR_COUNT
