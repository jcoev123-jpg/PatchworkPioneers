extends SceneTree

const Walk = preload("res://scripts/stitched/walk/stitched_walk_rules.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_catalogs_and_inputs()
	_replay_and_completion()
	_action_replay()
	_pockets_and_viewpoint()
	_thresholds()
	_invalid_actions()
	for failure in failures:
		printerr(failure)
	print("stitched_s8a_walk_core_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _rng(seed_number: int = 547) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = seed_number
	return random


func _dolls() -> Array:
	return [{"id": "a", "rank": 1, "hp": 90, "max_hp": 100, "lost": false, "fray": 0},
		{"id": "b", "rank": 2, "hp": 10, "max_hp": 101, "lost": false, "fray": 0},
		{"id": "c", "rank": 3, "hp": 0, "max_hp": 20, "lost": false, "fray": 0},
		{"id": "d", "rank": 4, "hp": 20, "max_hp": 20, "lost": false, "fray": 0}]


func _pockets() -> Dictionary:
	return {"a": ["thimble_tonic", "fresh_stuffing"], "b": ["starch", "dye"],
		"c": ["pins", "spare_spool"], "d": []}


func _act(walk: RefCounted, kind: String, extra: Dictionary = {}) -> Dictionary:
	var command := {"kind": kind, "actor": walk.snapshot().viewpoint}
	command.merge(extra)
	return walk.act(command, walk.snapshot())


func _reject(walk: RefCounted, command: Dictionary, expected: Dictionary = {}) -> void:
	var before: Dictionary = walk.snapshot()
	var receipt: Dictionary = walk.act(command, before if expected.is_empty() else expected)
	_check(not receipt.ok and not receipt.error.is_empty() and receipt.events.is_empty(), "rejected command has fail-closed receipt " + str(command))
	_check(walk.snapshot() == before and receipt.snapshot == before, "rejection preserves every state and inventory field")


func _bad_start(dolls: Array, pockets: Dictionary, catalogs: Dictionary, area: String = "walls") -> void:
	var random := _rng()
	var state := random.state
	var before := [dolls.duplicate(true), pockets.duplicate(true), catalogs.duplicate(true)]
	_check(Walk.start(random, area, dolls, pockets, catalogs) == null, "invalid start fails closed")
	_check(random.state == state and before == [dolls, pockets, catalogs], "invalid start preserves inputs and RNG")


func _catalogs_and_inputs() -> void:
	var catalogs: Dictionary = Walk.load_catalogs()
	_check(not catalogs.is_empty() and Walk.validate_catalogs(catalogs), "all authored records validate")
	_bad_start(_dolls(), _pockets(), {})
	for group in ["curios", "horrors", "corridors"]:
		var bad := catalogs.duplicate(true)
		bad[group].append(bad[group][0].duplicate(true))
		_bad_start(_dolls(), _pockets(), bad)
		bad = catalogs.duplicate(true)
		bad[group][-1].name = ""
		_bad_start(_dolls(), _pockets(), bad)
		bad = catalogs.duplicate(true)
		bad[group][-1]["unknown"] = true
		_bad_start(_dolls(), _pockets(), bad)
	for steps in [2, 7, 3.5, "4", null]:
		var bad := catalogs.duplicate(true)
		bad.corridors[-1].steps = steps
		_bad_start(_dolls(), _pockets(), bad)
	var bad := catalogs.duplicate(true)
	bad.corridors[-1].curios = ["forged"]
	_bad_start(_dolls(), _pockets(), bad)
	for group in ["curios", "horrors"]:
		bad = catalogs.duplicate(true)
		bad[group][-1].kind = "forged"
		_bad_start(_dolls(), _pockets(), bad)
	_bad_start(_dolls(), _pockets(), catalogs, "unknown_area")
	for field in ["id", "rank", "hp", "max_hp", "lost"]:
		var dolls := _dolls()
		dolls[0].erase(field)
		_bad_start(dolls, _pockets(), catalogs)
	var dolls := _dolls()
	dolls[0].lost = true
	dolls[0].hp = 0
	_bad_start(dolls, _pockets(), catalogs)
	dolls = _dolls()
	dolls[1].id = "a"
	_bad_start(dolls, _pockets(), catalogs)
	dolls = _dolls()
	dolls[1].rank = 1
	_bad_start(dolls, _pockets(), catalogs)
	for hp in [-1, 101, 1.5]:
		dolls = _dolls()
		dolls[0].hp = hp
		_bad_start(dolls, _pockets(), catalogs)
	var pockets := _pockets()
	pockets.a.append("pins")
	_bad_start(_dolls(), pockets, catalogs)
	pockets = _pockets()
	pockets.d = ["forged"]
	_bad_start(_dolls(), pockets, catalogs)
	pockets = _pockets()
	pockets.erase("d")
	_bad_start(_dolls(), pockets, catalogs)
	_check(Walk.start(null, "walls", _dolls(), _pockets()) == null, "null RNG rejected")


func _replay_and_completion() -> void:
	var lengths: Dictionary = {}
	var counts: Dictionary = {}
	var variants: Dictionary = {}
	for seed_number in range(1, 65):
		for area in ["walls", "floorboards", "sewing_basket"]:
			var first_rng := _rng(seed_number)
			var second_rng := _rng(seed_number)
			var first = Walk.start(first_rng, area, _dolls(), _pockets())
			var second = Walk.start(second_rng, area, _dolls(), _pockets())
			_check(first != null and second != null, "independent seeded services start")
			if first == null or second == null:
				continue
			var initial: Dictionary = first.snapshot()
			var state := first_rng.state
			_check(initial == second.snapshot() and first_rng.state == second_rng.state, "same seed yields identical corridor, placements and RNG")
			lengths[int(initial.corridor.steps)] = true
			counts[initial.curios.size()] = true
			variants[initial.corridor.id] = true
			_check(initial.step == 0 and initial.whirr == 0 and initial.curios.size() <= 2, "walk begins before first forward step")
			var occupied: Array = []
			for curio in initial.curios:
				_check(curio.step >= 1 and curio.step <= initial.corridor.steps and not curio.step in occupied, "at most one curio per valid step")
				occupied.append(curio.step)
			var detached: Dictionary = first.snapshot()
			detached.dolls[0].hp = -100
			detached.pockets.a.clear()
			detached.corridor.steps = 100
			_check(first.snapshot() == initial and first_rng.state == state, "snapshot is detached and never draws RNG")
			for step in range(1, int(initial.corridor.steps) + 1):
				var receipt: Dictionary = _act(first, "forward")
				_check(receipt == _act(second, "forward") and receipt.ok, "independent public forward receipts replay")
				_check(receipt.snapshot.step == step and receipt.snapshot.whirr == 0, "forward is zero WHIRR")
				_check((receipt.snapshot.phase == "complete") == (step == initial.corridor.steps), "completion occurs exactly at final boundary")
			_reject(first, {"kind": "forward", "actor": "a"})
			_reject(first, {"kind": "look_back", "actor": "a"})
			_reject(first, {"kind": "switch", "actor": "a", "target": "b"})
			_reject(first, {"kind": "use_item", "actor": "a", "slot": 0, "target": "a"})
			_check(first_rng.state == state and second_rng.state == state, "completion and rejected actions draw no RNG")
	for steps in [3, 4, 5, 6]:
		_check(lengths.has(steps), "seeded witnesses exercise length " + str(steps))
	for count in [0, 1, 2]:
		_check(counts.has(count), "seeded witnesses exercise curio count " + str(count))
	for corridor in Walk.load_catalogs().corridors:
		_check(variants.has(corridor.id), "seeded witnesses exercise corridor " + corridor.id)


func _pockets_and_viewpoint() -> void:
	var random := _rng()
	var dolls := _dolls()
	var pockets := _pockets()
	var walk = Walk.start(random, "walls", dolls, pockets)
	_check(walk != null, "item walk starts")
	if walk == null:
		return
	var state := random.state
	dolls[0].hp = 0
	pockets.a.clear()
	_check(walk.snapshot().dolls[0].hp == 90 and walk.snapshot().pockets.a.size() == 2, "start detaches caller inputs")
	_check(_act(walk, "look_back").snapshot.looking_back, "LOOK BACK exposes trailing formation")
	var receipt := _act(walk, "use_item", {"slot": 0, "target": "a"})
	_check(receipt.ok and receipt.snapshot.dolls[0].hp == 100 and receipt.events[0].amount == 10 and receipt.snapshot.whirr == 10, "tonic caps HP and costs five")
	receipt = _act(walk, "use_item", {"slot": 0, "target": "b"})
	_check(receipt.ok and receipt.snapshot.dolls[1].hp == 45 and receipt.snapshot.whirr == 25, "stuffing heals whole 35 percent on any doll and costs fifteen")
	_reject(walk, {"kind": "use_item", "actor": "a", "slot": 0, "target": "a"})
	receipt = _act(walk, "switch", {"target": "b"})
	_check(receipt.ok and receipt.snapshot.viewpoint == "b" and not receipt.snapshot.looking_back and receipt.snapshot.whirr == 30, "SWITCH changes eye and pocket for five")
	for kind in ["starch", "dye"]:
		receipt = _act(walk, "use_item", {"slot": 0, "target": "c"})
		var pending: Dictionary = receipt.snapshot.pending[-1]
		_check(receipt.ok and pending.kind == kind and not pending.consumed and not pending.effects.is_empty(), "future item creates explicit unconsumed effects " + kind)
	_check(walk.snapshot().dolls[2].hp == 0 and walk.snapshot().dolls[2].fray == 0, "pending items leave future battle effects unapplied")
	_act(walk, "switch", {"target": "c"})
	_reject(walk, {"kind": "use_item", "actor": "c", "slot": 0, "target": "forged_curio"})
	# Find an authored, seeded curio witness through public start and forward calls.
	var pin_witness := false
	for seed_number in range(1, 65):
		var candidate = Walk.start(_rng(seed_number), "walls", _dolls(), _pockets())
		for curio in candidate.snapshot().curios:
			if curio.step >= candidate.snapshot().corridor.steps:
				continue
			for step in int(curio.step):
				_act(candidate, "forward")
			_act(candidate, "switch", {"target": "c"})
			receipt = _act(candidate, "use_item", {"slot": 0, "target": curio.instance})
			_check(receipt.ok and receipt.snapshot.whirr == 10 and receipt.snapshot.pending[-1].effects.pin_shut, "pins target current curio and queue effect for five")
			receipt = _act(candidate, "use_item", {"slot": 0, "target": "d"})
			_check(receipt.ok and receipt.snapshot.pending[-1].effects.cancel_snip_or_save_tug_part and receipt.snapshot.whirr == 15, "spare spool queues thread protection for five")
			pin_witness = true
			break
		if pin_witness:
			break
	_check(pin_witness, "legal pins and spool paths have real seeded witness")
	var formation: Array = walk.snapshot().dolls.map(func(doll: Dictionary) -> Array: return [doll.id, doll.rank])
	_check(formation == [["a", 1], ["b", 2], ["c", 3], ["d", 4]] and random.state == state, "viewpoint and items preserve all ranks and RNG")
	var cap_pockets := _pockets()
	cap_pockets.a = ["fresh_stuffing", "thimble_tonic"]
	var capped = Walk.start(_rng(), "walls", _dolls(), cap_pockets)
	_check(_act(capped, "use_item", {"slot": 0, "target": "a"}).snapshot.dolls[0].hp == 100, "stuffing also caps HP")
	_check(_act(capped, "use_item", {"slot": 0, "target": "b"}).snapshot.dolls[1].hp == 25, "tonic rounds fractional fifteen percent down")


func _action_replay() -> void:
	var first_rng := _rng(87)
	var second_rng := _rng(87)
	var first = Walk.start(first_rng, "floorboards", _dolls(), _pockets())
	var second = Walk.start(second_rng, "floorboards", _dolls(), _pockets())
	var commands: Array = [
		{"kind": "look_back", "actor": "a"},
		{"kind": "use_item", "actor": "a", "slot": 0, "target": "c"},
		{"kind": "use_item", "actor": "a", "slot": 0, "target": "b"},
		{"kind": "switch", "actor": "a", "target": "b"},
		{"kind": "use_item", "actor": "b", "slot": 0, "target": "d"},
		{"kind": "use_item", "actor": "b", "slot": 0, "target": "b"}]
	for index in 20:
		commands.append({"kind": "look_back", "actor": "b"})
	for command in commands:
		var receipt: Dictionary = first.act(command, first.snapshot())
		_check(receipt.ok and receipt == second.act(command, second.snapshot()), "independent item/switch/threshold receipts replay")
		_check(first_rng.state == second_rng.state, "independent action replay preserves identical RNG")
	_check(first.snapshot().warning and first.snapshot().whirr == 100, "action replay reaches both thresholds")
	for step in int(first.snapshot().corridor.steps):
		_check(_act(first, "forward") == _act(second, "forward"), "replay completes after item and Machine descriptors")
	_check(first.snapshot().phase == "complete" and first.snapshot() == second.snapshot(), "full action replay completes identically")


func _thresholds() -> void:
	var walk = Walk.start(_rng(), "walls", _dolls(), _pockets())
	var original: Dictionary = walk.snapshot()
	var warnings := 0
	var machines := 0
	for index in range(1, 24):
		var receipt := _act(walk, "look_back")
		_check(receipt.ok and receipt.snapshot.whirr == mini(100, index * 5), "WHIRR cost and saturation")
		_check(receipt.snapshot.warning == (index >= 10), "warning begins exactly at fifty")
		for event in receipt.events:
			warnings += int(event.kind == "whirr_warning")
			machines += int(event.kind == "machine_pending")
		_check(receipt.snapshot.pending.size() == (1 if index >= 20 else 0), "single Machine begins exactly at one hundred")
	_check(warnings == 1 and machines == 1, "threshold receipts emitted once")
	var pending: Dictionary = walk.snapshot().pending[0]
	_check(pending.kind == "machine" and not pending.consumed and pending.effects == {"next_fight_extra_foes": 1, "party_fray": 10}, "Machine queues exact future consequences")
	_check(walk.snapshot().dolls == original.dolls and walk.snapshot().pockets == original.pockets, "Machine leaves formation HP fray and pockets unchanged")
	var fresh = Walk.start(_rng(), "walls", _dolls(), _pockets())
	_check(fresh.snapshot().whirr == 0 and fresh.snapshot().pending.is_empty(), "each walk resets WHIRR and Machine")


func _invalid_actions() -> void:
	var random := _rng()
	var walk = Walk.start(random, "walls", _dolls(), _pockets())
	var initial: Dictionary = walk.snapshot()
	for command in [{}, {"kind": "unknown", "actor": "a"}, {"kind": "forward", "actor": "forged"},
		{"kind": "look_back", "actor": "b"}, {"kind": "switch", "actor": "a", "target": "forged"},
		{"kind": "switch", "actor": "a", "target": "a"}, {"kind": "forward", "actor": "a", "extra": 1},
		{"kind": "use_item", "actor": "a", "slot": -1, "target": "a"},
		{"kind": "use_item", "actor": "a", "slot": 2, "target": "a"},
		{"kind": "use_item", "actor": "a", "slot": 0.0, "target": "a"},
		{"kind": "use_item", "actor": "a", "slot": 0, "target": "forged"}]:
		_reject(walk, command)
	var forged := initial.duplicate(true)
	forged.dolls[1].lost = true
	_reject(walk, {"kind": "switch", "actor": "a", "target": "b"}, forged)
	forged = initial.duplicate(true)
	forged.pockets.a.append("pins")
	_reject(walk, {"kind": "forward", "actor": "a"}, forged)
	_act(walk, "look_back")
	_reject(walk, {"kind": "forward", "actor": "a"}, initial)
	_check(random.state == initial.rng, "all invalid/forged/stale actions preserve caller RNG")
	random.randi()
	var externally_advanced := random.state
	_reject(walk, {"kind": "forward", "actor": "a"})
	_check(random.state == externally_advanced, "external RNG drift fails closed without rewinding caller RNG")
	var bare = Walk.new()
	_check(not bare.act({"kind": "forward", "actor": "a"}, {}).ok, "unstarted service fails closed")
