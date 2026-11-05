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
const NORMAL_TYPES := ["Fight", "Elite", "Rest", "Shop", "Event", "Treasure", "SewingCircle", "Campfire", "PatchStall", "Unpicker"]

var _floor_ids: Array = []
var _nodes: Dictionary = {}
var _route: Array[String] = []
var _generation_revision := 0


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
	_generation_revision += 1
	return true


static func _add_edge(nodes: Dictionary, source_id: String, target_id: String) -> void:
	var source: Dictionary = nodes[source_id]
	var edges: Array = source["outgoing"]
	if not edges.has(target_id):
		edges.append(target_id)


## Changes on every successful generation, even when the same seed rebuilds
## an identical graph. Views use this to invalidate old requests.
func get_generation_revision() -> int:
	return _generation_revision


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


## Detached, versioned-compatible snapshot used by the run save boundary.
## The snapshot contains no RNG state because map traversal never draws RNG.
func export_state() -> Dictionary:
	return {
		"floors": _floor_ids.duplicate(true),
		"nodes": _nodes.duplicate(true),
		"route": _route.duplicate(),
		"generation_revision": _generation_revision,
	}


## Restore an exact generated map without generating it again or touching RNG.
## Every field is validated into local values before the live map is replaced.
func restore_state(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 4:
		return false
	var raw_floors: Variant = value.get("floors")
	var raw_nodes: Variant = value.get("nodes")
	var raw_route: Variant = value.get("route")
	var revision: Variant = value.get("generation_revision")
	if not raw_floors is Array or raw_floors.size() != FLOOR_COUNT \
			or not raw_nodes is Dictionary or not raw_route is Array \
			or raw_route.size() > FLOOR_COUNT \
			or typeof(revision) != TYPE_INT or int(revision) <= 0:
		return false

	var floors: Array = []
	for floor_index in range(FLOOR_COUNT):
		var raw_floor: Variant = raw_floors[floor_index]
		if not raw_floor is Array or raw_floor.size() < MIN_NODES \
				or raw_floor.size() > MAX_NODES:
			return false
		var floor_ids: Array[String] = []
		for position in range(raw_floor.size()):
			var node_id: Variant = raw_floor[position]
			if typeof(node_id) != TYPE_STRING:
				return false
			var expected_id := "f%02d_n%d" % [floor_index + 1, position]
			if node_id != expected_id:
				return false
			floor_ids.append(node_id)
		floors.append(floor_ids)

	var nodes: Dictionary = {}
	for floor_index in range(FLOOR_COUNT):
		for position in range(floors[floor_index].size()):
			var node_id: String = floors[floor_index][position]
			if nodes.has(node_id) or not raw_nodes.has(node_id):
				return false
			var raw_node: Variant = raw_nodes[node_id]
			if not raw_node is Dictionary or raw_node.size() != 5 \
					or typeof(raw_node.get("id")) != TYPE_STRING \
					or raw_node.get("id") != node_id \
					or typeof(raw_node.get("floor")) != TYPE_INT \
					or int(raw_node["floor"]) != floor_index + 1 \
					or typeof(raw_node.get("position")) != TYPE_INT \
					or int(raw_node["position"]) != position \
					or typeof(raw_node.get("type")) != TYPE_STRING \
					or (str(raw_node["type"]) == "Boss") != (floor_index == FLOOR_COUNT - 1) \
					or (floor_index < FLOOR_COUNT - 1 \
						and not str(raw_node["type"]) in NORMAL_TYPES) \
					or not raw_node.get("outgoing") is Array:
				return false
			var outgoing: Array = raw_node["outgoing"]
			var edge_seen: Dictionary = {}
			if floor_index == FLOOR_COUNT - 1 and not outgoing.is_empty():
				return false
			if floor_index < FLOOR_COUNT - 1 and outgoing.is_empty():
				return false
			for target_id in outgoing:
				if typeof(target_id) != TYPE_STRING or edge_seen.has(target_id):
					return false
				edge_seen[target_id] = true
				var target_floor: Array = floors[floor_index + 1]
				if not target_floor.has(target_id):
					return false
			nodes[node_id] = raw_node.duplicate(true)
	if nodes.size() != raw_nodes.size():
		return false

	# Every node on the next floor must be reachable from the previous floor.
	for floor_index in range(1, FLOOR_COUNT):
		var incoming: Dictionary = {}
		for source_id in floors[floor_index - 1]:
			for target_id in nodes[source_id]["outgoing"]:
				incoming[target_id] = true
		for target_id in floors[floor_index]:
			if not incoming.has(target_id):
				return false

	var route: Array[String] = []
	var visited: Dictionary = {}
	for route_index in range(raw_route.size()):
		var node_id: Variant = raw_route[route_index]
		if typeof(node_id) != TYPE_STRING or visited.has(node_id) \
				or not floors[route_index].has(node_id):
			return false
		if route_index > 0 and not nodes[route[route_index - 1]]["outgoing"].has(node_id):
			return false
		visited[node_id] = true
		route.append(node_id)

	_floor_ids = floors
	_nodes = nodes
	_route = route
	_generation_revision = int(revision)
	return true
