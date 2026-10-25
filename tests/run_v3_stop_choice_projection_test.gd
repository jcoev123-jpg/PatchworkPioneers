extends SceneTree
## v3-3 projected stop choices: legacy Rest previews as Campfire and legacy
## Shop as Peddler on the already-generated run map, while every native stop
## keeps its own kind. Drives authentic seeded map prefixes and proves the
## adapter is a pure read: identical real topology, route, revision, choices
## and RNG, detached dictionaries, and fail-closed empty results.
## The adapter is not wired into live play yet; these are scene-free tests.

const SEED_RANGE := 64
const ALIASES := {"Rest": "Campfire", "Shop": "Peddler"}
const NATIVE_SPLIT_KINDS := ["Campfire", "SewingCircle", "PatchStall", "Unpicker"]
const NON_STOP_KINDS := ["Fight", "Elite", "Event", "Treasure"]

var failures: Array[String] = []
var checks := 0
var seen_kinds: Dictionary = {}


func _initialize() -> void:
	_test_invalid_and_terminal_maps()
	_test_projected_legal_routes()
	_test_matched_seeded_routes()
	_test_detached_snapshots()
	_test_rng_isolation()
	_finish()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("run_v3_stop_choice_projection_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_v3_stop_choice_projection_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Every real state a projection must never change, keyed for exact comparison.
func _snapshot(map: RunMap, rng: RandomNumberGenerator) -> Dictionary:
	return {
		"graph": map.get_floors(),
		"route": map.get_route(),
		"node": map.get_current_node_id(),
		"floor": map.get_current_floor(),
		"revision": map.get_generation_revision(),
		"choices": map.get_legal_choices(),
		"complete": map.is_complete(),
		"generated": map.is_generated(),
		"rng": rng.state,
	}


## Independent oracle: the source record exactly, plus only the aliased kind.
func _expected(source: Dictionary) -> Dictionary:
	var kind: String = str(source["type"])
	var expected := source.duplicate(true)
	expected["v3_kind"] = ALIASES.get(kind, kind)
	return expected


func _record(kind: String) -> void:
	seen_kinds[kind] = int(seen_kinds.get(kind, 0)) + 1


func _global_draws(count: int) -> Array:
	var draws: Array = []
	for index in range(count):
		draws.append(randi())
	return draws


func _test_invalid_and_terminal_maps() -> void:
	_check(RunV3StopChoiceProjection.project_legal_choices(null).is_empty(),
		"null map projects no choices")
	var rng := _rng(7)
	var map := RunMap.new()
	_check(RunV3StopChoiceProjection.project_legal_choices(map).is_empty(),
		"ungenerated map projects no choices")
	_check(not map.generate(null), "null RNG is still rejected by the real map")
	_check(RunV3StopChoiceProjection.project_legal_choices(map).is_empty(),
		"rejected generation leaves the projection empty")
	_check(map.generate(rng), "terminal fixture generated")
	var opening := _snapshot(map, rng)
	var opening_projection := RunV3StopChoiceProjection.project_legal_choices(map)
	_check(not opening_projection.is_empty() and opening_projection.size() == map.get_legal_choices().size(),
		"an incomplete generated map still projects every real legal choice")
	_check(_snapshot(map, rng) == opening, "projecting an incomplete map changes nothing")
	for step in range(RunMap.FLOOR_COUNT):
		if map.is_complete():
			break
		var legal := map.get_legal_choices()
		_check(not legal.is_empty(), "route step %d still has a legal choice" % step)
		if legal.is_empty():
			break
		_check(map.choose_node(legal[0]), "real map advances through step %d" % step)
	_check(map.is_complete(), "fixture reaches the floor-12 boss")
	var terminal := _snapshot(map, rng)
	_check(terminal["choices"].is_empty(), "completed map exposes no real legal choices")
	_check(RunV3StopChoiceProjection.project_legal_choices(map).is_empty(),
		"completed map projects no choices")
	_check(_snapshot(map, rng) == terminal, "projecting a completed map changes nothing")


## Walk every bounded seed to the boss. At each prefix compare each projected
## entry with its own real source node, then traverse the real map normally.
func _test_projected_legal_routes() -> void:
	for value in range(1, SEED_RANGE + 1):
		var rng := _rng(value)
		var map := RunMap.new()
		_check(map.generate(rng), "seed %d generates" % value)
		for step in range(RunMap.FLOOR_COUNT):
			var before := _snapshot(map, rng)
			var legal := map.get_legal_choices()
			_check(not legal.is_empty(), "seed %d step %d has a legal next choice" % [value, step])
			if legal.is_empty():
				break
			var projected := RunV3StopChoiceProjection.project_legal_choices(map)
			_check(_snapshot(map, rng) == before,
				"seed %d step %d: projection preserves graph, route, revision, choices and RNG" % [value, step])
			_check(projected.size() == legal.size() and not projected.is_empty(),
				"seed %d step %d: one projected entry per real legal choice, same count" % [value, step])
			for index in range(mini(projected.size(), legal.size())):
				var node_id: String = legal[index]
				var source := map.get_node(node_id)
				var entry: Dictionary = projected[index]
				var kind: String = str(source["type"])
				_record(kind)
				_check(entry.get("id") == node_id and entry.get("type") == kind
					and entry.get("floor") == source["floor"]
					and entry.get("position") == source["position"]
					and entry.get("outgoing") == source["outgoing"],
					"seed %d step %d: real id, type, floor, position and outgoing retained for %s"
						% [value, step, node_id])
				_check(entry == _expected(source),
					"seed %d step %d: %s differs from its source only by v3_kind" % [value, step, node_id])
				_check(entry.size() == source.size() + 1 and entry.has("v3_kind"),
					"seed %d step %d: exactly one added field for %s" % [value, step, node_id])
				if kind == "Rest":
					_check(entry.get("v3_kind") == "Campfire",
						"seed %d step %d: real Rest aliases to Campfire" % [value, step])
				elif kind == "Shop":
					_check(entry.get("v3_kind") == "Peddler",
						"seed %d step %d: real Shop aliases to Peddler" % [value, step])
				else:
					_check(entry.get("v3_kind") == kind,
						"seed %d step %d: %s keeps its own v3 kind" % [value, step, kind])
				_check(not map.get_node(node_id).has("v3_kind"),
					"seed %d step %d: source node is not relabelled for %s" % [value, step, node_id])
			# The read adapter must not consume or alter the genuine traversal.
			var choice: String = legal[(value + step) % legal.size()]
			_check(map.choose_node(choice),
				"seed %d step %d: a real legal choice still commits after projection" % [value, step])
			_check(map.get_current_node_id() == choice and map.get_current_floor() == step + 1,
				"seed %d step %d: real route advances exactly once" % [value, step])
		_check(map.is_complete() and map.get_route().size() == RunMap.FLOOR_COUNT,
			"seed %d reaches the boss through authentic choices" % value)
	_check(int(seen_kinds.get("Rest", 0)) > 0,
		"bounded seeded legal choices genuinely include legacy Rest")
	_check(int(seen_kinds.get("Shop", 0)) > 0,
		"bounded seeded legal choices genuinely include legacy Shop")
	for kind in NATIVE_SPLIT_KINDS:
		_check(int(seen_kinds.get(kind, 0)) > 0,
			"bounded seeded legal choices genuinely include native " + kind)
	for kind in NON_STOP_KINDS:
		_check(int(seen_kinds.get(kind, 0)) > 0,
			"bounded seeded legal choices genuinely include non-stop " + kind)
	_check(int(seen_kinds.get("Boss", 0)) > 0,
		"authentic traversal exposes the terminal Boss as a legal choice")


## Projection may only read: two identically seeded maps must stay step-for-step
## identical when one of them is projected before every decision.
func _test_matched_seeded_routes() -> void:
	for value in [3, 11, 29, 47]:
		var read_rng := _rng(value)
		var plain_rng := _rng(value)
		var read_map := RunMap.new()
		var plain_map := RunMap.new()
		_check(read_map.generate(read_rng) and plain_map.generate(plain_rng),
			"matched pair %d generated" % value)
		_check(read_map.get_floors() == plain_map.get_floors() and read_rng.state == plain_rng.state,
			"matched pair %d starts identical" % value)
		for step in range(RunMap.FLOOR_COUNT):
			var legal := plain_map.get_legal_choices()
			if legal.is_empty():
				break
			var projected := RunV3StopChoiceProjection.project_legal_choices(read_map)
			var projected_ids: Array[String] = []
			for entry in projected:
				projected_ids.append(str(entry.get("id", "")))
			_check(projected_ids == legal,
				"matched pair %d step %d: projection mirrors the real legal order" % [value, step])
			var choice: String = legal[0]
			_check(read_map.choose_node(choice) and plain_map.choose_node(choice),
				"matched pair %d step %d commits the same authentic choice" % [value, step])
			_check(read_map.get_floors() == plain_map.get_floors()
				and read_map.get_route() == plain_map.get_route()
				and read_map.get_generation_revision() == plain_map.get_generation_revision()
				and read_map.get_legal_choices() == plain_map.get_legal_choices()
				and read_rng.state == plain_rng.state,
				"matched pair %d step %d: projected reads leave topology, route and seed untouched" % [value, step])
		_check(read_map.is_complete() and plain_map.is_complete(),
			"matched pair %d completes identically" % value)


func _test_detached_snapshots() -> void:
	var rng := _rng(90210)
	var map := RunMap.new()
	_check(map.generate(rng), "detachment fixture generated")
	var before := _snapshot(map, rng)
	var first := RunV3StopChoiceProjection.project_legal_choices(map)
	var second := RunV3StopChoiceProjection.project_legal_choices(map)
	_check(not first.is_empty(), "detachment fixture has real legal choices")
	_check(first == second, "repeated reads agree")
	_check(map.get_legal_choices().has(str(first[0].get("id", ""))),
		"projected id is one of the real legal ids")
	var forged_id := "f99_n9"
	var rejected := _snapshot(map, rng)
	_check(not map.choose_node(forged_id),
		"a projected-only forged id is not a real legal choice")
	_check(_snapshot(map, rng) == rejected,
		"rejected forged choice leaves the real map untouched")
	for entry in first:
		entry["id"] = forged_id
		entry["type"] = "Mutated"
		entry["floor"] = 99
		entry["position"] = 99
		entry["v3_kind"] = "Mutated"
		var edges: Array = entry["outgoing"]
		edges.append(forged_id)
		if not edges.is_empty():
			edges[0] = "f99_n8"
	_check(_snapshot(map, rng) == before,
		"mutating every projected entry and nested outgoing array cannot edit RunMap")
	_check(RunV3StopChoiceProjection.project_legal_choices(map) == second,
		"a fresh projection is unchanged after mutating the earlier snapshot")
	for index in range(second.size()):
		var node_id := str(second[index].get("id", ""))
		var source := map.get_node(node_id)
		_check(not source.has("v3_kind") and second[index] == _expected(source),
			"real source record %s is never rewritten" % node_id)


func _test_rng_isolation() -> void:
	# Establish a known global stream, rewind to it, then prove the reads drew nothing.
	seed(731942)
	var expected_global := _global_draws(8)
	seed(731942)
	var rng := _rng(4815)
	var map := RunMap.new()
	_check(map.generate(rng), "RNG isolation fixture generated")
	var state := rng.state
	var before := _snapshot(map, rng)
	RunV3StopChoiceProjection.project_legal_choices(map)
	RunV3StopChoiceProjection.project_legal_choices(null)
	RunV3StopChoiceProjection.project_legal_choices(RunMap.new())
	_check(rng.state == state, "projection never advances the supplied run RNG")
	_check(_snapshot(map, rng) == before,
		"projection leaves the real graph, route, revision and legal choices untouched")
	_check(_global_draws(8) == expected_global,
		"projection never draws from Godot's global RNG stream")
