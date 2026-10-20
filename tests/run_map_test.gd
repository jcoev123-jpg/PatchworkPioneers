extends SceneTree

var failures: Array[String] = []
var checks := 0

const NORMAL_TYPES := ["Fight", "Elite", "Rest", "Shop", "Event", "Treasure"]


func _initialize() -> void:
	_test_ungenerated_and_invalid_rng()
	_test_seeded_replay_and_structure()
	_test_defensive_snapshots()
	_test_traversal_and_rejections()
	if failures.is_empty():
		print("run_map_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_map_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _snapshot(map: RunMap, rng: RandomNumberGenerator) -> Dictionary:
	return {
		"graph": map.get_floors(),
		"route": map.get_route(),
		"node": map.get_current_node_id(),
		"floor": map.get_current_floor(),
		"choices": map.get_legal_choices(),
		"complete": map.is_complete(),
		"generated": map.is_generated(),
		"rng": rng.state,
	}


func _reject(map: RunMap, rng: RandomNumberGenerator, id: String, label: String) -> void:
	var before := _snapshot(map, rng)
	_check(not map.choose_node(id), label + " must be rejected")
	_check(_snapshot(map, rng) == before, label + " leaves graph/progress/choices/RNG untouched")


func _test_ungenerated_and_invalid_rng() -> void:
	var map := RunMap.new()
	var rng := _rng(9)
	_check(not map.is_generated() and not map.is_complete(), "new map ungenerated and incomplete")
	_check(map.get_floors().is_empty() and map.get_legal_choices().is_empty(),
		"ungenerated map has no nodes or choices")
	_check(map.get_node("f01_n0").is_empty() and map.get_route().is_empty()
		and map.get_current_node_id() == "" and map.get_current_floor() == 0,
		"ungenerated progress and lookup are empty")
	_reject(map, rng, "f01_n0", "select on ungenerated map")
	_check(not map.generate(null), "null RNG is rejected")
	_check(not map.is_generated() and rng.state == _rng(9).state,
		"invalid generation leaves map and unrelated RNG unchanged")


func _test_seeded_replay_and_structure() -> void:
	var first_rng := _rng(2048)
	var second_rng := _rng(2048)
	var first := RunMap.new()
	var second := RunMap.new()
	# An injected run RNG must not touch Godot's unrelated global stream.
	seed(456123)
	var expected_global := randi()
	seed(456123)
	_check(first.generate(first_rng), "first generation succeeds")
	_check(randi() == expected_global, "generation never uses global RNG")
	_check(second.generate(second_rng), "second generation succeeds")
	_check(first.is_generated() and second.is_generated(), "both graphs generated")
	_check(first.get_floors() == second.get_floors(), "same seed builds identical complete graphs")
	_check(first_rng.state == second_rng.state, "same seed consumes identical run RNG state")
	_check(first.get_legal_choices() == second.get_legal_choices(),
		"same seed starts with identical choices")
	_check(first.get_legal_choices().size() == first.get_floors()[0].size(),
		"all first-floor nodes are selectable")
	_check(first.get_route().is_empty() and first.get_current_floor() == 0,
		"generation starts before the first node")
	_check(first_rng.state != _rng(2048).state, "generation actually consumes supplied RNG")
	_check(first.get_node("does_not_exist").is_empty(), "unknown node lookup is empty")
	_assert_graph(first)

	var before_rng := first_rng.state
	var choice: String = first.get_legal_choices()[0]
	_check(first.choose_node(choice) and second.choose_node(choice),
		"matched seeded maps accept the same opening route")
	_check(first.get_legal_choices() == second.get_legal_choices()
		and first.get_route() == second.get_route(), "matched maps agree after traversal")
	_check(first_rng.state == before_rng and second_rng.state == before_rng,
		"traversal never consumes run RNG")
	var unchanged := _snapshot(first, first_rng)
	_check(not first.generate(null) and _snapshot(first, first_rng) == unchanged,
		"invalid regeneration preserves populated graph and route")


func _assert_graph(map: RunMap) -> void:
	var floors: Array = map.get_floors()
	_check(floors.size() == 12, "exactly twelve floors")
	if floors.size() != 12:
		return
	var known: Dictionary = {}
	for floor_index in range(floors.size()):
		var row: Array = floors[floor_index]
		_check(row.size() >= 3 and row.size() <= 4, "floor %d has 3-4 nodes" % (floor_index + 1))
		for pos in range(row.size()):
			var node: Dictionary = row[pos]
			var id: String = node.get("id", "")
			_check(not id.is_empty() and not known.has(id), "unique nonempty ID " + id)
			known[id] = true
			_check(node.get("floor") == floor_index + 1 and node.get("position") == pos,
				"correct floor and zero-based position for " + id)
			_check((node.get("type") == "Boss") if floor_index == 11
				else NORMAL_TYPES.has(node.get("type")), "valid kind for " + id)
			_check(node.get("outgoing") is Array, "outgoing array exists for " + id)
			_check(map.get_node(id) == node, "lookup agrees with graph record for " + id)

	var incoming: Dictionary = {}
	var branched := false
	var crossed := false
	for floor_index in range(floors.size()):
		var row: Array = floors[floor_index]
		for node in row:
			var id: String = node["id"]
			var links: Array = node["outgoing"]
			_check(links.size() == 0 if floor_index == 11 else links.size() > 0,
				"boss has no exits, earlier node has an exit: " + id)
			if links.size() >= 2:
				branched = true
			var distinct := {}
			for target_id in links:
				_check(not distinct.has(target_id), "edge not duplicated: " + id)
				distinct[target_id] = true
				var target: Dictionary = map.get_node(target_id)
				_check(not target.is_empty(), "edge target exists: " + str(target_id))
				if not target.is_empty():
					_check(target["floor"] == floor_index + 2,
						"edge moves exactly one floor: " + id)
					incoming[target_id] = int(incoming.get(target_id, 0)) + 1
		if floor_index == 11:
			continue
		# Crossed routes: source A lies left of source B, but A's edge
		# terminates to the right of an edge from B.
		for i in range(row.size()):
			for j in range(i + 1, row.size()):
				for a_id in row[i]["outgoing"]:
					for b_id in row[j]["outgoing"]:
						var a: Dictionary = map.get_node(a_id)
						var b: Dictionary = map.get_node(b_id)
						if not a.is_empty() and not b.is_empty() and a["position"] > b["position"]:
							crossed = true
	for floor_index in range(1, floors.size()):
		for node in floors[floor_index]:
			_check(int(incoming.get(node["id"], 0)) > 0,
				"every post-first node has an entrance: " + str(node["id"]))
	_check(branched, "at least one node branches")
	_check(crossed, "at least one pair of edges geometrically crosses")
	# Induction: every first-floor node is selectable and every next node
	# has an incoming edge from a reachable previous floor.
	_check(map.get_legal_choices().size() == floors[0].size(),
		"no first-floor node is inaccessible")


func _test_defensive_snapshots() -> void:
	var rng := _rng(783)
	var map := RunMap.new()
	_check(map.generate(rng), "snapshot fixture generated")
	var original := map.get_floors()
	var original_node: Dictionary = map.get_node(original[0][0]["id"])
	var original_choices := map.get_legal_choices()
	var read_one := map.get_floors()
	var read_two := map.get_floors()
	read_one[0][0]["id"] = "altered"
	read_one[0][0]["type"] = "not_a_kind"
	read_one[0][0]["outgoing"].clear()
	read_one[0].clear()
	read_one.clear()
	_check(read_two == original and map.get_floors() == original,
		"deep graph snapshot mutation does not affect another snapshot or internal graph")
	var node_read := map.get_node(original_node["id"])
	node_read["outgoing"].clear()
	node_read["type"] = "mutated"
	_check(map.get_node(original_node["id"]) == original_node,
		"node/edge lookup is deep copied")
	var choices_read := map.get_legal_choices()
	choices_read.clear()
	choices_read.append("fake")
	_check(map.get_legal_choices() == original_choices, "legal choices cannot be edited externally")
	var chosen: String = original_choices[0]
	var before_rng := rng.state
	_check(map.choose_node(chosen), "snapshot route fixture selects opening")
	var saved_route := map.get_route()
	var route_read := map.get_route()
	route_read.clear()
	route_read.append("fake")
	_check(map.get_route() == saved_route and map.get_current_node_id() == chosen,
		"route mutation cannot change internal traversal")
	_check(rng.state == before_rng, "defensive reads and selection do not draw randomness")


func _test_traversal_and_rejections() -> void:
	var rng := _rng(1234567)
	var map := RunMap.new()
	_check(map.generate(rng), "traversal fixture generated")
	var floors: Array = map.get_floors()
	var first_choice: String = ""
	var forbidden: String = ""
	# Pick a concrete first-floor node with a disconnected second-floor
	# candidate. The test must fail explicitly if the fixture lacks one.
	for candidate in floors[0]:
		for next_node in floors[1]:
			if not candidate["outgoing"].has(next_node["id"]):
				first_choice = candidate["id"]
				forbidden = next_node["id"]
				break
		if not first_choice.is_empty():
			break
	_check(not first_choice.is_empty() and not forbidden.is_empty(),
		"fixture includes a genuinely disconnected second-floor candidate")
	if first_choice.is_empty():
		return
	var legal_opening := map.get_legal_choices()
	_check(legal_opening.has(first_choice) and legal_opening.size() == floors[0].size(),
		"all floor-one nodes legal initially")
	_reject(map, rng, floors[2][0]["id"], "initial floor skip")
	_reject(map, rng, "unknown", "initial unknown ID")
	var rng_state := rng.state
	_check(map.choose_node(first_choice), "legal first-floor selection succeeds")
	_check(map.get_current_node_id() == first_choice and map.get_current_floor() == 1
		and map.get_route() == [first_choice], "first choice records exact progress")
	_check(map.get_legal_choices() == map.get_node(first_choice)["outgoing"],
		"only selected node's successors are legal")
	_check(rng.state == rng_state, "first selection consumes no randomness")
	_reject(map, rng, forbidden, "disconnected next-floor node")
	_reject(map, rng, floors[0][0]["id"], "same floor cannot be selected twice")
	_reject(map, rng, first_choice, "replay chosen node")
	_reject(map, rng, floors[3][0]["id"], "later floor skip")
	_reject(map, rng, "nonexistent_node", "unknown during route")
	for target_floor in range(2, 13):
		var legal := map.get_legal_choices()
		_check(not legal.is_empty(), "there is a legal route onto floor %d" % target_floor)
		if legal.is_empty():
			return
		var chosen: String = legal[0]
		var before: Array[String] = map.get_route()
		var state_before := rng.state
		_check(map.choose_node(chosen), "choose legal node on floor %d" % target_floor)
		before.append(chosen)
		_check(map.get_route() == before and map.get_current_floor() == target_floor
			and map.get_current_node_id() == chosen, "route advances exactly once on floor %d" % target_floor)
		_check(rng.state == state_before, "selection has zero RNG draws on floor %d" % target_floor)
		if target_floor < 12:
			_check(map.get_legal_choices() == map.get_node(chosen)["outgoing"],
				"next choices are precisely outgoing links on floor %d" % target_floor)
		else:
			_check(map.get_node(chosen)["type"] == "Boss", "terminal choice is a Boss")
	_check(map.is_complete() and map.get_route().size() == 12
		and map.get_current_floor() == 12 and map.get_legal_choices().is_empty(),
		"boss completes a twelve-node route with no further choices")
	_reject(map, rng, map.get_current_node_id(), "replay terminal boss")
	_reject(map, rng, floors[11][0]["id"], "any boss selection after completion")
	_reject(map, rng, floors[0][0]["id"], "restart route after boss")
	_reject(map, rng, "unknown", "unknown after boss")
