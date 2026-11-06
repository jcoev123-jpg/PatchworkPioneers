extends SceneTree

const Walk = preload("res://scripts/stitched/walk/stitched_walk_rules.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func party() -> Array:
	var dolls: Array = []
	for index in 4:
		dolls.append({"id": str(index), "rank": index + 1, "hp": 30, "max_hp": 40,
			"lost": false, "fray": 7, "parts": {
				"head": {"id": "seamstress_mending_knot_hat", "tier": 2, "torn": false},
				"arms": "seamstress_thread_prick_needle"}})
	return dolls

func pockets() -> Dictionary:
	return {"0": ["starch"], "1": ["pins", "spare_spool"], "2": [], "3": []}

func random(seed_number: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_number
	return rng

func act(walk: StitchedWalkRules, kind: String, extra: Dictionary = {}) -> Dictionary:
	var request := {"kind": kind, "actor": walk.snapshot().viewpoint}
	request.merge(extra, true)
	return walk.act(request, walk.snapshot())

func reject(walk: StitchedWalkRules, rng: RandomNumberGenerator, request: Dictionary, expected: Dictionary = {}) -> void:
	var before := walk.snapshot()
	var state := rng.state
	var receipt := walk.act(request, before if expected.is_empty() else expected)
	check(not receipt.ok and not receipt.error.is_empty() and receipt.events.is_empty(), "reject " + str(request))
	check(walk.snapshot() == before and rng.state == state and receipt.snapshot == before,
		"rejection preserves full state and borrowed RNG")
	receipt.snapshot.pockets.clear()
	check(walk.snapshot() == before, "rejected receipt detached")

func arrive(walk: StitchedWalkRules) -> void:
	var step: int = walk.snapshot().tug.step
	check(step >= 0 and step < walk.snapshot().corridor.steps, "tug scheduled at traversable position")
	while walk.snapshot().step < step:
		check(act(walk, "forward").ok, "public forward reaches tug")
	check(walk.tug_unresolved(), "arrival exposes unresolved tug")

func finish(walk: StitchedWalkRules) -> void:
	while walk.snapshot().phase == "walking":
		var receipt := act(walk, "forward")
		check(receipt.ok, "resolved tug permits exit")
		if not receipt.ok: break

func _initialize() -> void:
	var seen_steps := {}
	var seen_slots := {}
	for seed_number in range(24):
		for mimic in [false, true]:
			var control_rng := random(seed_number)
			var control := Walk.start(control_rng, "walls", party(), pockets(), null, mimic)
			var off_rng := random(seed_number)
			var off := Walk.start(off_rng, "walls", party(), pockets(), null, mimic, false)
			check(off.snapshot() == control.snapshot() and off_rng.state == control_rng.state,
				"explicit default-off preserves legacy/mimic state and exact RNG")
			reject(off, off_rng, {"kind": "tug", "actor": "0", "target": "thread_tug", "choice": "yield"})
			var expected_step := control_rng.randi_range(0, int(control.snapshot().corridor.steps) - 1)
			var rng := random(seed_number)
			var dolls := party()
			var inventory := pockets()
			var walk := Walk.start(rng, "walls", dolls, inventory, null, mimic, true)
			check(walk != null, "valid tug start")
			check(walk.snapshot().tug.step == expected_step and rng.state == control_rng.state,
				"tug adds exactly one seeded scheduling draw after legacy/mimic")
			check(dolls == party() and inventory == pockets(), "start detaches caller inputs")
			seen_steps[expected_step] = true
			if expected_step > 0:
				reject(walk, rng, {"kind": "tug", "actor": "0", "target": "thread_tug", "choice": "yield"})
			arrive(walk)
			reject(walk, rng, {"kind": "forward", "actor": "0"})
			var first := act(walk, "tug", {"target": "thread_tug", "choice": "yield"})
			check(first.ok and not walk.tug_unresolved() and first.snapshot.whirr == 5, "one required resolution costs five WHIRR")
			check(first.snapshot.pending.size() == 1 and first.snapshot.pending[0].kind == "torn_part", "yield queues one typed part effect")
			if first.snapshot.pending.size() == 1:
				seen_slots[first.snapshot.pending[0].effects.slot] = true
			var replay_rng := random(seed_number)
			var replay := Walk.start(replay_rng, "walls", party(), pockets(), null, mimic, true)
			arrive(replay)
			var second := act(replay, "tug", {"target": "thread_tug", "choice": "yield"})
			check(first == second and rng.state == replay_rng.state, "two independent seeded RNGs replay public resolution exactly")
			finish(walk)
			finish(replay)
			check(walk.snapshot() == replay.snapshot(), "complete seeded walk replays including mimic settlement")
	check(seen_steps.size() > 1 and seen_slots.size() == 2, "nonvacuous variable arrival and both genuine part representations torn")
	for choice in ["pins", "spare_spool", "yield"]:
		outcome(choice)
	edges()
	for failure in failures: printerr(failure)
	print("stitched_s8e_tug_walk_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)

func outcome(choice: String) -> void:
	var rng := random(552)
	var walk := Walk.start(rng, "walls", party(), pockets(), null, false, true)
	arrive(walk)
	var stale := walk.snapshot()
	check(act(walk, "switch", {"target": "1"}).ok and walk.tug_unresolved(), "can switch to actual item carrier without bypassing tug")
	for bad in [
		{"kind": "tug", "actor": "0", "target": "thread_tug", "choice": "yield"},
		{"kind": "tug", "actor": "forged", "target": "thread_tug", "choice": "yield"},
		{"kind": "tug", "actor": "1", "target": "forged", "choice": "yield"},
		{"kind": "tug", "actor": "1", "target": "thread_tug", "choice": "yield", "slot": 0},
		{"kind": "tug", "actor": "1", "target": "thread_tug", "choice": "pins"},
		{"kind": "tug", "actor": "1", "target": "thread_tug", "choice": "pins", "slot": -1},
		{"kind": "tug", "actor": "1", "target": "thread_tug", "choice": "pins", "slot": 2},
		{"kind": "tug", "actor": "1", "target": "thread_tug", "choice": "pins", "slot": 0.0},
		{"kind": "tug", "actor": "1", "target": "thread_tug", "choice": "pins", "slot": 1},
		{"kind": "tug", "actor": "1", "target": "thread_tug", "choice": "starch", "slot": 0},
		{"kind": "tug", "actor": "1", "target": "thread_tug", "choice": "pins", "slot": 0, "item": "pins"}]:
		reject(walk, rng, bad)
	reject(walk, rng, {"kind": "tug", "actor": "1", "target": "thread_tug", "choice": "yield"}, stale)
	# Reach 95 through public actions; resolution must cross the Machine threshold once.
	while walk.snapshot().whirr < 95: check(act(walk, "look_back").ok, "public WHIRR buildup")
	var before := walk.snapshot()
	var rng_before := rng.state
	var extra := {"target": "thread_tug", "choice": choice}
	if choice != "yield": extra.slot = 0 if choice == "pins" else 1
	var forged := before.duplicate(true)
	forged.pockets["1"] = ["pins", "pins"]
	reject(walk, rng, {"kind": "tug", "actor": "1", "target": "thread_tug", "choice": "yield"}, forged)
	var receipt := act(walk, "tug", extra)
	check(receipt.ok and receipt.snapshot.whirr == 100 and receipt.snapshot.warning, "tug retains normal charge and Machine threshold")
	var machines: Array = receipt.snapshot.pending.filter(func(p): return p.kind == "machine")
	check(machines.size() == 1, "one Machine descriptor at threshold")
	var expected_dolls: Array = before.dolls.duplicate(true)
	var expected_pockets: Dictionary = before.pockets.duplicate(true)
	if choice == "yield":
		var torn: Array = receipt.snapshot.pending.filter(func(p): return p.kind == "torn_part")
		check(torn.size() == 1, "one mendable effect")
		if torn.size() == 1:
			var effect: Dictionary = torn[0]
			check(effect.target == "3" and effect.source == "thread_tug" and not effect.consumed
				and effect.effects.mendable and effect.effects.already_applied, "typed unconsumed rear-doll mendable effect")
			var slot: String = effect.effects.slot
			var original: Variant = expected_dolls[3].parts[slot]
			if original is String: original = {"id": original, "tier": 1, "torn": false}
			original.torn = true
			expected_dolls[3].parts[slot] = original
			check(effect.effects.part == original, "effect preserves real part ID and tier")
	else:
		expected_pockets["1"].remove_at(extra.slot)
		check(rng.state == rng_before and receipt.snapshot.pending.size() == 1, "item saves part without RNG or collateral pending effects")
	check(receipt.snapshot.dolls == expected_dolls and receipt.snapshot.pockets == expected_pockets,
		"only one actual worn part or one actual item changes; no collateral resources")
	var after := walk.snapshot()
	receipt.snapshot.dolls.clear()
	receipt.events[0].clear()
	check(walk.snapshot() == after, "successful receipts detached")
	var command := {"kind": "tug", "actor": "1"}
	command.merge(extra)
	reject(walk, rng, command)
	reject(walk, rng, command, before)
	check(act(walk, "look_back").ok, "continued actions after resolution")
	check(walk.snapshot().pending.filter(func(p): return p.kind == "machine").size() == 1, "Machine remains one-shot")
	finish(walk)
	reject(walk, rng, command)

func edges() -> void:
	var rng := random(12)
	var state := rng.state
	var catalogs := Walk.load_catalogs()
	for record in catalogs.horrors:
		if record.id == "thread_tug": record.id = "other_tug"
	check(Walk.start(rng, "walls", party(), pockets(), catalogs, true, true) == null and rng.state == state,
		"missing authored tug rejects without committing even mimic RNG")
	var invalid := party()
	invalid[3].parts.head.id = "fabricated_part"
	check(Walk.start(rng, "walls", invalid, pockets(), null, false, true) == null and rng.state == state,
		"forged equipped part fails start without RNG")
	check(Walk.start(rng, "unknown", party(), pockets(), null, false, true) == null and rng.state == state, "invalid area no draw")
	for mode in ["empty", "torn", "dead_rear", "all_dead"]:
		var dolls := party()
		if mode == "empty": dolls[3].parts = {}
		if mode == "torn": dolls[3].parts = {"head": {"id": "seamstress_mending_knot_hat", "tier": 3, "torn": true}}
		if mode == "dead_rear": dolls[3].hp = 0
		if mode == "all_dead":
			for doll in dolls: doll.hp = 0
		var walk := Walk.start(rng, "walls", dolls, pockets(), null, false, true)
		arrive(walk)
		var before := walk.snapshot()
		var rng_before := rng.state
		var receipt := act(walk, "tug", {"target": "thread_tug", "choice": "yield"})
		check(receipt.ok and not walk.tug_unresolved() and receipt.snapshot.pockets == before.pockets, "safe edge resolution " + mode)
		if mode == "dead_rear":
			check(receipt.snapshot.pending.size() == 1 and receipt.snapshot.pending[0].target == "2"
				and receipt.snapshot.dolls[3] == before.dolls[3], "rearmost living doll chosen rather than dead rear")
		else:
			check(receipt.snapshot.dolls == before.dolls and receipt.snapshot.pending.is_empty() and rng.state == rng_before
				and receipt.events[0].kind == "tug_no_part", "no eligible part never fabricates, spends or rolls " + mode)
		finish(walk)
