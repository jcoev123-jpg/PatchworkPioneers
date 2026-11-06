extends SceneTree

const Walk = preload("res://scripts/stitched/walk/stitched_walk_rules.gd")
var failures: Array[String] = []
var checks := 0
var witnessed: Dictionary = {}
var catalogs: Dictionary

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func party(equipped: bool = true) -> Array:
	var result: Array = []
	for index in 4:
		result.append({"id": str(index), "rank": index + 1, "hp": 30, "max_hp": 40,
			"lost": false, "fray": 0, "glass_eye": true, "needle_hand": true})
	if equipped:
		result[0].parts = {"head": {"id": "seamstress_mending_knot_hat", "tier": 1, "torn": false},
			"arms": {"id": "seamstress_thread_prick_needle", "tier": 1, "torn": false}}
	return result

func start(seed_number: int, area: String, equipped: bool = true) -> StitchedWalkRules:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_number
	return Walk.start(rng, area, party(equipped), {"0": ["pins", "dye"], "1": [], "2": [], "3": []}, catalogs)

func act(walk: StitchedWalkRules, kind: String, extra: Dictionary = {}) -> Dictionary:
	var command := {"kind": kind, "actor": walk.snapshot().viewpoint}
	command.merge(extra)
	return walk.act(command, walk.snapshot())

func choose(walk: StitchedWalkRules, curio: Dictionary, choice: String) -> Dictionary:
	return act(walk, "curio", {"target": curio.instance, "choice": choice})

func reject(walk: StitchedWalkRules, command: Dictionary, expected: Dictionary = {}) -> void:
	var before := walk.snapshot()
	var rng := walk._rng.state
	var result := walk.act(command, before if expected.is_empty() else expected)
	check(not result.ok and not result.error.is_empty() and result.events.is_empty(), "reject invalid action " + str(command))
	check(walk.snapshot() == before and walk._rng.state == rng and result.snapshot == before,
		"rejection spends no RNG, items, WHIRR or awards")

func record_effects(walk: StitchedWalkRules, curio: Dictionary) -> void:
	for effect in walk.snapshot().pending:
		if effect.source != curio.instance or effect.kind in ["pins", "dye"]: continue
		check(not effect.consumed, "new consequences await S8f")
		witnessed[effect.kind] = true
		if effect.kind == "curio_loot":
			witnessed[effect.effects.kind] = true
		if effect.kind == "curio_fray":
			check(effect.effects == {"amount": 15, "already_applied": true}
				and walk.snapshot().dolls[0].fray == 15, "puller pays exactly fifteen fray once")
		if effect.kind == "curio_trap":
			check(effect.target == "0" and effect.effects == {"status": "bleed", "amount": 2}, "explicit ragbag Bleed on reacher")

func exercise(seed_number: int, area: String, id: String, mode: String = "normal") -> Array:
	var walk := start(seed_number, area)
	check(walk != null, "authored catalogs start a real Walk")
	if walk == null: return []
	var found: Dictionary = {}
	for curio in walk.snapshot().curios:
		if curio.id == id: found = curio
	if found.is_empty(): return []
	var curio := found
	if curio.step > 0:
		reject(walk, {"kind": "curio", "actor": "0", "target": curio.instance, "choice": "leave"})
	while walk.snapshot().step < curio.step: check(act(walk, "forward").ok, "public approach")
	check(walk.snapshot().phase == "walking", "scheduled curio remains reachable")
	if curio.step == walk.snapshot().corridor.steps - 1: witnessed[id + "_end"] = true
	var command := {"kind": "curio", "actor": "0", "target": curio.instance, "choice": "leave"}
	for bad in [{"kind": "curio", "actor": "0", "target": id, "choice": "leave"},
		{"kind": "curio", "actor": "forged", "target": curio.instance, "choice": "leave"},
		{"kind": "curio", "actor": "0", "target": curio.instance, "choice": "forged"},
		{"kind": "curio", "actor": "0", "target": curio.instance, "choice": "leave", "needle_hand": true}]:
		reject(walk, bad)
	var forged := walk.snapshot()
	forged.dolls[0].parts = {"arms": "needle_wasp_stinger"}
	reject(walk, command, forged)
	var stale := walk.snapshot()
	check(act(walk, "look_back").ok, "make genuine stale snapshot")
	reject(walk, command, stale)
	var trace: Array = []
	if mode == "pins":
		check(act(walk, "use_item", {"slot": 0, "target": curio.instance}).ok, "pin real active bag")
	elif mode == "dye":
		check(act(walk, "use_item", {"slot": 1, "target": "0"}).ok, "dye actual reacher")
	var before := walk.snapshot()
	if mode == "leave":
		trace.append(choose(walk, curio, "leave"))
		check(walk.snapshot().rng == before.rng and walk.snapshot().pending == before.pending, "leave creates no loot or RNG draws")
	else:
		match id:
			"pin_nest":
				for pull in 4:
					var expected := walk.snapshot()
					var receipt := choose(walk, curio, "pull")
					trace.append(receipt)
					check(receipt.ok and receipt.snapshot.whirr == mini(100, before.whirr + (pull + 1) * 5), "accepted pull adds exactly five WHIRR")
					reject(walk, {"kind": "curio", "actor": "0", "target": curio.instance, "choice": "pull"}, expected)
					if walk.curio_choices(curio.instance).is_empty(): break
			"borrowed_shape":
				var inspect := choose(walk, curio, "inspect")
				trace.append(inspect)
				check(inspect.ok and inspect.events[0].kind == "dummy_inspected" and inspect.events[0].mimic is bool, "glass eye reveals seeded mimic truth")
				witnessed["dummy_" + str(inspect.events[0].mimic)] = true
				reject(walk, {"kind": "curio", "actor": "0", "target": curio.instance, "choice": "inspect"})
				var take := choose(walk, curio, "take")
				trace.append(take)
				check(take.ok, "take inspected dummy once")
				var effect: Dictionary = take.snapshot.pending[-1]
				check(effect.kind == ("curio_fight" if inspect.events[0].mimic else "curio_part"), "revealed truth matches actual consequence")
				if effect.kind == "curio_part":
					check(StitchedWalkCurios.parts().has(effect.effects.id) and effect.effects.tier == 1, "award genuine droppable part")
			"biting_bundle":
				check(choose(walk, curio, "reach").ok, "reach seeded ragbag")
				if mode in ["pins", "dye"]:
					check(walk.snapshot().pending.filter(func(e): return e.kind == "curio_trap").is_empty(), "pins/dye protects trap")
					var protection: Dictionary = walk.snapshot().pending[0]
					check(protection.consumed if mode == "pins" else not protection.effects.skip_one_curio_trap,
						"protection consumed once")
					if mode == "dye": check(protection.effects.skip_next_fight_first_strike and not protection.consumed, "dye retains battle protection")
			"pattern_scraps":
				check(choose(walk, curio, "read").ok, "read wall patterns")
				check(walk.snapshot().pending[-1].effects == {"area": area, "marker": "wall_pattern_secret"}, "floor-specific secret marker")
			"sewn_threshold":
				check(choose(walk, curio, "unpick").ok, "equipped needle arm unpicks door")
				check(walk.snapshot().pending[-2].kind == "side_room" and walk.snapshot().pending[-2].effects.area == area,
					"door queues side room with authored curio and loot")
	var resolved := walk.snapshot()
	check(walk.curio_choices(curio.instance).is_empty(), "resolved choices unavailable")
	reject(walk, command)
	reject(walk, command, before)
	record_effects(walk, curio)
	var detached := walk.snapshot()
	detached.pending.clear()
	check(walk.snapshot() == resolved, "consequences detached")
	while walk.snapshot().phase == "walking": check(act(walk, "forward").ok, "reach exit after resolution")
	reject(walk, command)
	trace.append(walk.snapshot())
	return trace

func curio_test(id: String, area: String) -> void:
	var count := 0
	for seed_number in 96:
		var trace := exercise(seed_number, area, id)
		if trace.is_empty(): continue
		count += 1
		check(trace == exercise(seed_number, area, id), "independent seeded action/receipt replay: " + id)
		if count == 1:
			exercise(seed_number, area, id, "leave")
			if id == "biting_bundle":
				for mode in ["pins", "dye"]: check(exercise(seed_number, area, id, mode) == exercise(seed_number, area, id, mode), "protected seeded replay")
	check(count > 0, "nonvacuous authored curio witness " + id)
	check(witnessed.has(id + "_end"), "last traversable position reachable " + id)

func negatives() -> void:
	for id in ["borrowed_shape", "sewn_threshold"]:
		var found := false
		for seed_number in 96:
			var walk := start(seed_number, "walls", false)
			for curio in walk.snapshot().curios:
				if curio.id != id: continue
				while walk.snapshot().step < curio.step: act(walk, "forward")
				reject(walk, {"kind": "curio", "actor": "0", "target": curio.instance,
					"choice": "inspect" if id == "borrowed_shape" else "unpick"})
				if id == "borrowed_shape":
					check(choose(walk, curio, "take").ok, "ordinary head can take without glass inspection")
					check(walk.snapshot().pending[-1].kind in ["curio_part", "curio_fight"], "uninspected take resolves real seeded outcome")
				found = true
				break
			if found: break
		check(found, "boolean capability spoof rejected with real instance " + id)
	var torn_party := party()
	torn_party[0].parts.arms.torn = true
	torn_party[0].parts.head.torn = true
	check(StitchedWalkCurios.valid_doll(torn_party[0]), "torn equipment remains a valid doll")
	check(not StitchedWalkCurios.capable(torn_party[0], ["seamstress_thread_prick_needle"], "arms")
		and not StitchedWalkCurios.capable(torn_party[0], ["seamstress_mending_knot_hat"], "head"), "torn parts grant no capabilities")
	for malformed in [{"arms": "seamstress_mending_knot_hat"}, {"head": "forged"},
		{"arms": {"id": "needle_wasp_stinger", "tier": 0, "torn": false}}]:
		var invalid_party := party()
		invalid_party[0].parts = malformed
		var rng := RandomNumberGenerator.new()
		rng.seed = 551
		var before := rng.state
		check(Walk.start(rng, "walls", invalid_party, {"0": [], "1": [], "2": [], "3": []}, catalogs) == null
			and rng.state == before, "invalid equipped metadata fails before schedule draws")
	for field in ["wake_chances", "loot", "glass_heads", "needle_arms", "room_curios", "bleed_chance"]:
		var bad := catalogs.duplicate(true)
		for record in bad.curios:
			if record.rules.has(field): record.rules[field] = ["forged"] if field != "bleed_chance" else -1
		var rng := RandomNumberGenerator.new()
		rng.seed = 551
		var before := rng.state
		check(Walk.start(rng, "walls", party(), {"0": [], "1": [], "2": [], "3": []}, bad) == null and rng.state == before,
			"malformed authored metadata rejects before RNG: " + field)

func _initialize() -> void:
	catalogs = Walk.load_catalogs()
	check(Walk.validate_catalogs(catalogs), "authored catalog validates")
	if Walk.validate_catalogs(catalogs):
		curio_test("pin_nest", "walls")
		curio_test("borrowed_shape", "walls")
		curio_test("biting_bundle", "floorboards")
		curio_test("pattern_scraps", "walls")
		curio_test("sewn_threshold", "walls")
		negatives()
		for outcome in ["curio_fight", "curio_fray", "curio_loot", "gold", "scraps", "pocket_item", "curio_part", "dummy_true", "dummy_false", "curio_trap", "secret_room", "side_room"]:
			check(witnessed.has(outcome), "authored seeded outcome actually witnessed " + outcome)
	for failure in failures: printerr(failure)
	print("stitched_s8d_curios_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
