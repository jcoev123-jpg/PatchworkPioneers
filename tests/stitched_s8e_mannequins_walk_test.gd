extends SceneTree

const Walk = preload("res://scripts/stitched/walk/stitched_walk_rules.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)

func random(seed_number: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_number
	return rng

func party() -> Array:
	var dolls: Array = []
	for index in 4:
		dolls.append({"id": str(index), "rank": index + 1, "hp": 30,
			"max_hp": 40, "lost": false, "fray": 0})
	return dolls

func pockets() -> Dictionary:
	return {"0": [], "1": [], "2": [], "3": []}

func act(walk: StitchedWalkRules, kind: String, extra: Dictionary = {}) -> Dictionary:
	var command := {"kind": kind, "actor": walk.snapshot().viewpoint}
	command.merge(extra, true)
	return walk.act(command, walk.snapshot())

func reject(walk: StitchedWalkRules, rng: RandomNumberGenerator, command: Dictionary,
		expected: Dictionary = {}) -> void:
	var before := walk.snapshot()
	var rng_before := rng.state
	var receipt := walk.act(command, before if expected.is_empty() else expected)
	check(not receipt.ok and not receipt.error.is_empty() and receipt.events.is_empty(),
		"invalid action rejects: " + str(command))
	check(walk.snapshot() == before and receipt.snapshot == before and rng.state == rng_before,
		"invalid action preserves state, WHIRR, RNG and pending")
	receipt.snapshot.clear()
	check(walk.snapshot() == before, "rejected receipt is detached")

func finish(walk: StitchedWalkRules) -> void:
	while walk.snapshot().phase == "walking":
		var result: Dictionary
		if walk.tug_unresolved():
			result = act(walk, "tug", {"target": "thread_tug", "choice": "yield"})
		else:
			result = act(walk, "forward")
		check(result.ok, "public Walk reaches completion")
		if not result.ok:
			break

func mannequin_effects(walk: StitchedWalkRules) -> Array:
	return walk.snapshot().pending.filter(func(p): return p.kind == "mannequins")

func has_event(events: Array, kind: String, stage: int = -1) -> bool:
	for event in events:
		if event.kind == kind and (stage < 0 or event.get("stage") == stage):
			return true
	return false

func any_mannequins_event(events: Array) -> bool:
	for event in events:
		if event.kind.begins_with("mannequins"):
			return true
	return false

func exercise(seed_number: int, mimic: bool, tug: bool) -> void:
	var baseline_rng := random(seed_number)
	var baseline = Walk.start(baseline_rng, "walls", party(), pockets(), null, mimic, tug)
	var off_rng := random(seed_number)
	var off = Walk.start(off_rng, "walls", party(), pockets(), null, mimic, tug, false)
	check(baseline != null and off != null and baseline.snapshot() == off.snapshot()
		and baseline_rng.state == off_rng.state, "default-off byte-for-byte schedule/RNG unchanged")
	check(not off.snapshot().has("mannequins"), "disabled Walk has no extra state")
	var expected_present := baseline_rng.randi_range(0, 1) == 1
	var expected_step := baseline_rng.randi_range(0, int(baseline.snapshot().corridor.steps) - 1)
	var a_rng := random(seed_number)
	var b_rng := random(seed_number)
	var a = Walk.start(a_rng, "walls", party(), pockets(), null, mimic, tug, true)
	var b = Walk.start(b_rng, "walls", party(), pockets(), null, mimic, tug, true)
	check(a != null and b != null, "both independent opt-in Walks start")
	if a == null or b == null:
		return
	var initial := a.snapshot()
	check(initial == b.snapshot() and a_rng.state == b_rng.state
		and a_rng.state == baseline_rng.state and initial.rng == baseline_rng.state,
		"seeded schedules reproducible with exactly two appended RNG draws")
	check(initial.mannequins.id == "following_forms" and initial.mannequins.name == "Mannequins"
		and initial.mannequins.present == expected_present
		and initial.mannequins.step == expected_step and initial.mannequins.stage == 0
		and initial.pending.is_empty(), "authored present/absent witness at traversable step")
	var caller_copy := initial.duplicate(true)
	caller_copy.mannequins.stage = 3
	caller_copy.pending.append({"kind": "forged"})
	check(a.snapshot() == initial, "public start snapshot detached")
	var untouched = Walk.start(random(seed_number), "walls", party(), pockets(), null, mimic, tug, true)
	finish(untouched)
	check(untouched.snapshot().phase == "complete" and untouched.snapshot().mannequins.stage == 0
		and mannequin_effects(untouched).is_empty(), "no-look completion never spawns an effect")
	if not expected_present:
		for idx in 5:
			var x := act(a, "look_back")
			var y := act(b, "look_back")
			check(x.ok and x == y and a_rng.state == b_rng.state, "absent LOOK BACK replay")
		check(a.snapshot().mannequins.stage == 0 and mannequin_effects(a).is_empty(),
			"absent witness ignores repeated looks")
		finish(a)
		finish(b)
		check(a.snapshot() == b.snapshot() and mannequin_effects(a).is_empty(),
			"absent completion replay remains effect-free")
		return
	if expected_step > 0:
		var premature := act(a, "look_back")
		check(premature.ok and a.snapshot().mannequins.stage == 0
			and mannequin_effects(a).is_empty(), "look before encounter step cannot escalate")
		check(premature == act(b, "look_back"), "early LOOK BACK replays")
	while a.snapshot().step < expected_step:
		if a.tug_unresolved():
			check(act(a, "tug", {"target": "thread_tug", "choice": "yield"}) ==
				act(b, "tug", {"target": "thread_tug", "choice": "yield"}),
				"tug resolution replays on route to mannequins")
		else:
			check(act(a, "forward") == act(b, "forward"), "public forward scheduling replay")
	check(a.mannequins_visible() and b.mannequins_visible(),
		"present witness actually reached through public Walk")
	var at_step := a.snapshot()
	reject(a, a_rng, {"kind": "look_back", "actor": "forged"})
	reject(a, a_rng, {"kind": "look_back", "actor": "1"})
	reject(a, a_rng, {"kind": "look_back", "actor": "0", "extra": true})
	var forged := at_step.duplicate(true)
	forged.mannequins.stage = 2
	reject(a, a_rng, {"kind": "look_back", "actor": "0"}, forged)
	var receipts: Array = []
	for stage in range(1, 6):
		var before := a.snapshot()
		var ra := act(a, "look_back")
		var rb := act(b, "look_back")
		receipts.append(ra.duplicate(true))
		check(ra.ok and ra == rb and a_rng.state == b_rng.state
			and a_rng.state == initial.rng, "identical seed action/receipt replay")
		check(ra.snapshot.mannequins.stage == mini(stage, 3)
			and ra.snapshot.whirr == before.whirr + 5, "each legal look adds WHIRR, caps escalation at three")
		var effects := mannequin_effects(a)
		check(effects.size() == (1 if stage >= 3 else 0),
			"exactly one future encounter only from third LOOK BACK")
		if stage <= 3:
			check(has_event(ra.events, "mannequins_stage", stage),
				"receipt names actual escalation stage")
		else:
			check(not any_mannequins_event(ra.events),
				"fourth and fifth looks cannot re-emit effect")
		if stage == 3 and effects.size() == 1:
			check(effects[0] == {"kind": "mannequins", "source": "following_forms",
				"consumed": false, "effects": {"next_fight": true,
				"position": "party_back_rank"}}, "typed unconsumed next-fight party-rear encounter")
			check(has_event(ra.events, "mannequins_pending"),
				"third look exposes one pending receipt")
	var stable := a.snapshot()
	receipts[2].snapshot.mannequins.stage = 99
	receipts[2].events.clear()
	receipts[2].snapshot.pending.clear()
	check(a.snapshot() == stable, "successful returned receipts are fully detached")
	reject(a, a_rng, {"kind": "look_back", "actor": "0"}, at_step)
	finish(a)
	finish(b)
	check(a.snapshot() == b.snapshot() and mannequin_effects(a).size() == 1,
		"completion preserves one staged effect and full replay")
	reject(a, a_rng, {"kind": "look_back", "actor": "0"})
	reject(a, a_rng, {"kind": "forward", "actor": "0"})

func thresholds() -> void:
	var witness := -1
	for seed_number in 128:
		var w = Walk.start(random(seed_number), "walls", party(), pockets(),
			null, false, false, true)
		if w.snapshot().mannequins.present and w.snapshot().mannequins.step == 0:
			witness = seed_number
			break
	check(witness >= 0, "actual seeded immediate mannequin witness for WHIRR threshold")
	if witness < 0:
		return
	var rng := random(witness)
	var walk = Walk.start(rng, "walls", party(), pockets(), null, false, false, true)
	var initial_rng := rng.state
	var warning_count := 0
	var machine_count := 0
	var mannequin_count := 0
	for index in 22:
		var result := act(walk, "look_back")
		for event in result.events:
			if event.kind == "whirr_warning": warning_count += 1
			if event.kind == "machine_pending": machine_count += 1
			if event.kind == "mannequins_pending": mannequin_count += 1
		check(result.ok and result.snapshot.whirr == mini(100, (index + 1) * 5),
			"WHIRR saturates exactly as legacy S8a")
	check(warning_count == 1 and machine_count == 1 and mannequin_count == 1
		and walk.snapshot().pending.filter(func(p): return p.kind == "machine").size() == 1
		and mannequin_effects(walk).size() == 1 and rng.state == initial_rng,
		"Machine, warning and third-look effect coexist one-shot with no RNG draws")

func missing_horror() -> void:
	var rng := random(553)
	var baseline := rng.state
	var catalogs := Walk.load_catalogs()
	for record in catalogs.horrors:
		if record.id == "following_forms":
			record.id = "forged_forms"
	check(Walk.start(rng, "walls", party(), pockets(), catalogs, true, true, true) == null
		and rng.state == baseline, "missing authored ID fails atomically even after other opt-in draws")
	var dolls := party()
	dolls[0].id = "following_forms"
	check(Walk.start(rng, "walls", dolls,
		{"following_forms": [], "1": [], "2": [], "3": []},
		null, false, false, true) == null and rng.state == baseline,
		"authored horror cannot alias a real doll, preserving RNG")

func _initialize() -> void:
	var present := 0
	var absent := 0
	for seed_number in 32:
		for combo in [[false, false], [true, false], [false, true], [true, true]]:
			var w = Walk.start(random(seed_number), "walls", party(), pockets(),
				null, combo[0], combo[1], true)
			if w.snapshot().mannequins.present:
				present += 1
			else:
				absent += 1
			exercise(seed_number, combo[0], combo[1])
	check(present > 0 and absent > 0, "nonvacuous present and absent seeded witnesses")
	thresholds()
	missing_horror()
	for failure in failures:
		printerr(failure)
	print("stitched_s8e_mannequins_walk_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
