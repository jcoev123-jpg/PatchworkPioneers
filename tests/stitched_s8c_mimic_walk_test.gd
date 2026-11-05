extends SceneTree

const Walk = preload("res://scripts/stitched/walk/stitched_walk_rules.gd")
var checks := 0
var failures: Array[String] = []


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _party() -> Array:
	var dolls: Array = []
	for index in 4:
		dolls.append({"id": str(index), "rank": index + 1, "hp": 30, "max_hp": 40, "lost": false, "fray": 7})
	return dolls


func _pockets() -> Dictionary:
	return {"0": ["starch"], "1": [], "2": [], "3": []}


func _random(seed_number: int) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = seed_number
	return random


func _act(walk: StitchedWalkRules, kind: String, extra: Dictionary = {}) -> Dictionary:
	var request := {"kind": kind, "actor": walk.snapshot().viewpoint}
	request.merge(extra, true)
	return walk.act(request, walk.snapshot())


func _reject(walk: StitchedWalkRules, request: Dictionary, expected: Dictionary = {}) -> void:
	var before := walk.snapshot()
	var receipt := walk.act(request, before if expected.is_empty() else expected)
	_check(not receipt.ok and not receipt.error.is_empty() and receipt.events.is_empty(), "negative action rejected " + str(request))
	_check(walk.snapshot() == before and receipt.snapshot == before, "rejection preserves full state including RNG, WHIRR, HP, pockets, ranks and pending")


func _initialize() -> void:
	var shadow_seed := -1
	var ordinary_seed := -1
	for seed_number in range(32):
		var random := _random(seed_number)
		var dolls := _party()
		var pockets := _pockets()
		var walk := Walk.start(random, "walls", dolls, pockets, null, true)
		_check(walk != null, "valid opt-in start")
		var initial := walk.snapshot()
		_check(dolls == _party() and pockets == _pockets(), "start leaves caller inputs detached")
		var legacy_rng := _random(seed_number)
		var legacy := Walk.start(legacy_rng, "walls", dolls, pockets)
		_check(not legacy.snapshot().has("shadow"), "default S8a start has no shadow or additional state")
		# Independently replay the exact three scheduling draws after the S8a schedule.
		var present := legacy_rng.randi_range(0, 1) == 1
		var step := legacy_rng.randi_range(0, int(initial.corridor.steps) - 1)
		var disguise := str(legacy_rng.randi_range(1, 3))
		_check(initial.shadow.present == present and initial.shadow.step == step and initial.shadow.disguise == disguise
			and initial.rng == legacy_rng.state and random.state == legacy_rng.state, "exact seeded schedule and RNG draw budget")
		if present:
			shadow_seed = seed_number
		else:
			ordinary_seed = seed_number
		var detached := initial.duplicate(true)
		detached.shadow.present = not present
		detached.dolls[0].hp = 0
		_check(walk.snapshot() == initial, "snapshot edits cannot mutate service")
		_reject(walk, {"kind": "snip", "actor": "0", "target": "extra_thread_shadow"})
	_check(shadow_seed >= 0 and ordinary_seed >= 0, "seeded shadow and ordinary witnesses both exist")
	if shadow_seed >= 0 and ordinary_seed >= 0:
		_outcomes(shadow_seed)
		var unseen := Walk.start(_random(shadow_seed), "walls", _party(), _pockets(), null, true)
		_complete(unseen)
		_check(not unseen.snapshot().shadow.revealed and unseen.snapshot().pending.size() == 1
			and unseen.snapshot().pending[0].kind == "mimic", "never looking back still queues exactly one unresolved mimic")
		var ordinary := Walk.start(_random(ordinary_seed), "walls", _party(), _pockets(), null, true)
		_act(ordinary, "look_back")
		_check(not ordinary.shadow_visible() and ordinary.snip_targets().is_empty(), "ordinary look back offers no snip")
		_reject(ordinary, {"kind": "snip", "actor": "0", "target": "extra_thread_shadow"})
		_complete(ordinary)
		_check(ordinary.snapshot().pending.is_empty(), "ordinary completion queues no mimic")
	_invalid_start()
	for failure in failures:
		printerr(failure)
	print("stitched_s8c_mimic_walk_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _complete(walk: StitchedWalkRules) -> void:
	while walk.snapshot().phase == "walking":
		_check(_act(walk, "forward").ok, "forward completes walk")


func _outcomes(seed_number: int) -> void:
	for outcome in ["correct", "wrong", "unresolved"]:
		var replay: Array = []
		for repeat in 2:
			var random := _random(seed_number)
			var walk := Walk.start(random, "walls", _party(), _pockets(), null, true)
			var initial := walk.snapshot()
			while walk.snapshot().step < initial.shadow.step:
				_act(walk, "forward")
			var stale := walk.snapshot()
			var receipt := _act(walk, "look_back")
			_check(receipt.ok and walk.shadow_visible() and receipt.events[0].kind == "shadow_revealed"
				and receipt.events[0].targets == ["1", "2", "3", "extra_thread_shadow"], "stable revealed shadow and target receipt")
			_check(walk.snapshot().whirr == 5 and random.state == initial.rng, "LOOK BACK costs exactly 5 and draws no RNG")
			var targets := walk.snip_targets()
			targets.clear()
			receipt.snapshot.shadow.removed = true
			receipt.events[0].shadow.removed = true
			_check(walk.shadow_visible() and walk.snip_targets().size() == 4, "receipts and targets detached")
			for bad in [{"kind": "snip", "actor": "forged", "target": "1"},
				{"kind": "snip", "actor": "0", "target": "forged"},
				{"kind": "snip", "actor": "0", "target": "0"},
				{"kind": "snip", "actor": "0", "target": "1", "extra": true},
				{"kind": "snip", "actor": "0"}]:
				_reject(walk, bad)
			_reject(walk, {"kind": "snip", "actor": "0", "target": "extra_thread_shadow"}, stale)
			var before := walk.snapshot()
			if outcome != "unresolved":
				var target := "extra_thread_shadow" if outcome == "correct" else "2"
				receipt = _act(walk, "snip", {"target": target})
				_check(receipt.ok and receipt.snapshot.whirr == 10 and random.state == initial.rng, "SNIP costs exactly 5 without RNG")
				var expected_dolls: Array = before.dolls.duplicate(true)
				if outcome == "wrong":
					expected_dolls[2].fray += 20
				_check(receipt.snapshot.dolls == expected_dolls and receipt.snapshot.pockets == before.pockets, "only chosen real doll gains exactly 20 fray; HP, ranks and pockets unchanged")
				_check(receipt.snapshot.shadow.removed == (outcome == "correct"), "only correct snip removes mimic")
				_reject(walk, {"kind": "snip", "actor": "0", "target": target})
				_reject(walk, {"kind": "snip", "actor": "0", "target": target}, before)
				if outcome == "wrong":
					_check(walk.snapshot().pending == [{"kind": "cut_thread", "target": "2", "source": "extra_thread_shadow",
						"consumed": false, "effects": {"until_re_tied": true}}], "wrong snip queues exactly chosen cut until re-tied")
			_complete(walk)
			var final := walk.snapshot()
			var mimics: Array = final.pending.filter(func(effect): return effect.kind == "mimic")
			_check(mimics.size() == (0 if outcome == "correct" else 1), "exactly one unresolved next-fight mimic, none after correct snip")
			_check(final.pending.size() == {"correct": 0, "wrong": 2, "unresolved": 1}[outcome], "no extra or duplicated pending effects")
			if outcome != "correct":
				_check(mimics[0] == {"kind": "mimic", "source": "extra_thread_shadow", "consumed": false,
					"effects": {"next_fight": true, "position": "party_back_rank", "round": 1, "sequence": ["attack", "flee"]}}, "explicit unconsumed round-one back-rank hit-then-flee descriptor")
			_check(final.rng == initial.rng and random.state == initial.rng and final.whirr == (5 if outcome == "unresolved" else 10), "completion draws no RNG and exact total WHIRR")
			for kind in ["forward", "look_back", "snip", "switch", "use_item"]:
				_reject(walk, {"kind": kind, "actor": "0", "target": "extra_thread_shadow"})
			if repeat == 0:
				replay = [final, receipt]
			else:
				_check(replay == [final, receipt], "outcome snapshot and receipt replay exactly " + outcome)


func _invalid_start() -> void:
	var random := _random(549)
	var state := random.state
	var catalogs := Walk.load_catalogs()
	for horror in catalogs.horrors:
		if horror.id == "extra_thread_shadow":
			horror.id = "other_mimic"
	_check(Walk.start(random, "walls", _party(), _pockets(), catalogs, true) == null and random.state == state,
		"missing authored horror fails before committing RNG")
	var dolls := _party()
	dolls[1].fray = "forged"
	_check(Walk.start(random, "walls", dolls, _pockets(), null, true) == null and random.state == state,
		"invalid fray fails closed before schedule commits")
