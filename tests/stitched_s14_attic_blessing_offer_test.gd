extends SceneTree
## The S14 side-door provider offers an Attic blessing only when the caller says it has a benefit.

const ATTIC_BY_FLAG := {
	"candle": "attic_waxlight",
	"mend": "attic_rethread",
	"head_guard": "attic_headward",
}
const ATTIC_IDS := ["attic_waxlight", "attic_rethread", "attic_headward"]
const UNDERBED_IDS := ["underbed_stuffing_trade", "underbed_leg_trade", "underbed_fear_trade"]

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_catalog_precondition()
	_attic_singletons()
	_nothing_available()
	_underbed_only()
	_underbed_taken()
	_invalid_inputs()
	_legacy_paths()
	for message in failures:
		printerr(message)
	print("stitched_s14_attic_blessing_offer_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _rng(seed_number: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_number
	return rng


## Attic flags in candle, mend, head_guard order.
func _offer(rng: RandomNumberGenerator, kind: String, taken: bool, payers: bool, candle: bool,
		mend: bool, head_guard: bool) -> Dictionary:
	return StitchedS14SideDoors.offer(rng, kind, taken, payers, payers, payers, candle, mend, head_guard)


func _catalog_precondition() -> void:
	var entries := StitchedS14SideDoors.catalog()
	for id in ATTIC_IDS + UNDERBED_IDS:
		_check(entries.has(id), "shipped catalog has %s" % id)
	if entries.has("attic_waxlight"):
		_check(entries.attic_waxlight.reward == "candle" and entries.attic_waxlight.cost == "none",
			"waxlight is the free candle blessing")
	if entries.has("attic_rethread"):
		_check(entries.attic_rethread.reward == "mend", "rethread is the mend blessing")
	if entries.has("attic_headward"):
		_check(entries.attic_headward.reward == "head_guard", "headward is the head guard blessing")


func _attic_singletons() -> void:
	for flag in ATTIC_BY_FLAG:
		var expected: String = ATTIC_BY_FLAG[flag]
		var seen := {}
		for seed_number in 40:
			var rng := _rng(seed_number)
			var picked := _offer(rng, "Boss", false, false, flag == "candle", flag == "mend",
				flag == "head_guard")
			_check(picked.get("id", "") == expected,
				"%s singleton seed %d offers %s, got %s" % [flag, seed_number, expected, picked.get("id", "")])
			seen[picked.get("id", "")] = true
		_check(seen.size() == 1 and seen.has(expected), "%s singleton always offers only %s" % [flag, expected])
		# The offer is a detached copy of the authored row.
		var row := _offer(_rng(1), "Boss", false, false, flag == "candle", flag == "mend",
			flag == "head_guard")
		row["reward"] = "tampered"
		_check(StitchedS14SideDoors.catalog()[expected].reward != "tampered", "%s offer is detached" % flag)
	# Two available benefits never leak the third, and both appear across seeds.
	for missing in ATTIC_BY_FLAG:
		var ids := {}
		for seed_number in 80:
			var picked := _offer(_rng(seed_number), "Boss", false, false, missing != "candle",
				missing != "mend", missing != "head_guard")
			ids[picked.get("id", "")] = true
		_check(not ids.has(ATTIC_BY_FLAG[missing]), "filtered %s blessing is never offered" % missing)
		_check(ids.size() == 2, "the two remaining Attic blessings both stay reachable without %s" % missing)


func _nothing_available() -> void:
	for kind in ["Boss", "Elite"]:
		for seed_number in 30:
			var rng := _rng(seed_number)
			var control := _rng(seed_number)
			var picked := _offer(rng, kind, false, false, false, false, false)
			_check(picked.is_empty(), "%s with nothing available offers {} (seed %d)" % [kind, seed_number])
			if kind == "Boss":
				_check(rng.state == control.state, "empty Boss pool draws no RNG (seed %d)" % seed_number)
			else:
				# Only the historical 70% gate may be drawn for an Elite.
				control.randi_range(1, 100)
				_check(rng.state == control.state, "empty Elite pool draws only the gate (seed %d)" % seed_number)
	# Underbed already taken as well: still nothing and no draw.
	var rng := _rng(7)
	var control := _rng(7)
	_check(_offer(rng, "Boss", true, false, false, false, false).is_empty(), "taken and empty offers {}")
	_check(rng.state == control.state, "taken and empty draws no RNG")


func _underbed_only() -> void:
	var ids := {}
	for seed_number in 200:
		var picked := _offer(_rng(seed_number), "Boss", false, true, false, false, false)
		_check(not picked.is_empty() and picked.id in UNDERBED_IDS,
			"Underbed-only pool never returns an Attic id (seed %d)" % seed_number)
		ids[picked.get("id", "")] = true
	_check(ids.size() == 3, "all Underbed deals stay reachable when only Underbed is offered")
	# Underbed-only draws exactly one pick, no family coin.
	var rng := _rng(11)
	var control := _rng(11)
	_offer(rng, "Boss", false, true, false, false, false)
	control.randi_range(0, 9)
	_check(rng.state == control.state, "Underbed-only pool draws a single weighted pick")


func _underbed_taken() -> void:
	for seed_number in 100:
		var picked := _offer(_rng(seed_number), "Boss", true, true, true, true, true)
		_check(not picked.is_empty() and picked.id in UNDERBED_IDS,
			"underbed_taken never offers Attic (seed %d)" % seed_number)
		var elite := _offer(_rng(seed_number), "Elite", true, true, true, true, true)
		_check(elite.is_empty() or elite.id in UNDERBED_IDS,
			"underbed_taken Elite never offers Attic (seed %d)" % seed_number)


func _invalid_inputs() -> void:
	for kind in ["", "Fight", "boss", "Event", "Stop"]:
		var rng := _rng(5)
		var control := _rng(5)
		_check(_offer(rng, kind, false, true, true, true, true).is_empty(), "bad kind '%s' returns {}" % kind)
		_check(rng.state == control.state, "bad kind '%s' draws no RNG" % kind)
	_check(StitchedS14SideDoors.offer(null, "Boss", false).is_empty(), "null rng returns {}")


## The pre-change algorithm, kept here as the historical reference trajectory.
func _legacy(rng: RandomNumberGenerator, kind: String, taken: bool, leg: bool, stuffing: bool,
		fear: bool) -> Dictionary:
	var entries := StitchedS14SideDoors.catalog()
	if not kind in ["Elite", "Boss"]:
		return {}
	if kind == "Elite" and rng.randi_range(1, 100) > 70:
		return {}
	var underbed: Array = []
	for entry in entries.values():
		if entry.kind != "underbed":
			continue
		if entry.cost == "limb" and not leg:
			continue
		if entry.cost == "max_hp" and not stuffing:
			continue
		if entry.cost == "fear" and not fear:
			continue
		for _i in int(StitchedS14SideDoors.UNDERBED_WEIGHTS[entry.reward]):
			underbed.append(entry.id)
	underbed.sort()
	var attic: Array = []
	if not taken:
		for entry in entries.values():
			if entry.kind == "attic":
				attic.append(entry.id)
		attic.sort()
	var pool: Array
	if not underbed.is_empty() and not attic.is_empty():
		pool = underbed if rng.randi_range(0, 1) == 0 else attic
	elif not underbed.is_empty():
		pool = underbed
	elif not attic.is_empty():
		pool = attic
	else:
		return {}
	return entries[pool[rng.randi_range(0, pool.size() - 1)]].duplicate(true)


func _legacy_paths() -> void:
	var counts := {}
	var elite_admitted := 0
	var elite_total := 400
	var attic_seen := 0
	for seed_number in 400:
		for kind in ["Boss", "Elite"]:
			for taken in [false, true]:
				for payers in [[true, true, true], [false, true, true], [true, false, true],
						[true, true, false], [false, false, false]]:
					var a := _rng(seed_number)
					var b := _rng(seed_number)
					var c := _rng(seed_number)
					var d := _rng(seed_number)
					var omitted := StitchedS14SideDoors.offer(a, kind, taken, payers[0], payers[1], payers[2])
					var all_true := StitchedS14SideDoors.offer(b, kind, taken, payers[0], payers[1], payers[2],
						true, true, true)
					var defaults := StitchedS14SideDoors.offer(c, kind, taken)
					var legacy := _legacy(d, kind, taken, payers[0], payers[1], payers[2])
					_check(omitted == legacy and a.state == d.state,
						"omitted flags match legacy (seed %d %s)" % [seed_number, kind])
					_check(all_true == legacy and b.state == d.state,
						"all-true flags match legacy (seed %d %s)" % [seed_number, kind])
					if payers == [true, true, true]:
						var e := _rng(seed_number)
						_check(defaults == _legacy(e, kind, taken, true, true, true) and c.state == e.state,
							"default arguments match legacy (seed %d %s)" % [seed_number, kind])
					if not omitted.is_empty() and omitted.id in ATTIC_IDS:
						attic_seen += 1
		# Underbed weight ratio 1:5:4 on the Underbed-only draw.
		var rng := _rng(seed_number)
		var picked := StitchedS14SideDoors.offer(rng, "Boss", true)
		counts[picked.get("reward", "")] = int(counts.get(picked.get("reward", ""), 0)) + 1
		var gate := _rng(seed_number)
		if gate.randi_range(1, 100) <= 70:
			elite_admitted += 1
	_check(attic_seen > 0, "legacy paths still offer Attic blessings")
	# Exact weights: each draw is one randi_range(0, 9) over fear x4, leg x5, stuffing x1.
	var expected := {"gold_patch": 0, "silk_patch": 0, "wren_gift": 0}
	for seed_number in 400:
		var rng := _rng(seed_number)
		var index := rng.randi_range(0, 9)
		var reward := "wren_gift" if index < 4 else ("silk_patch" if index < 9 else "gold_patch")
		expected[reward] += 1
	for reward in expected:
		_check(int(counts.get(reward, 0)) == expected[reward],
			"Underbed %s share matches the 1:5:4 weights (%d)" % [reward, int(counts.get(reward, 0))])
	_check(int(counts.get("silk_patch", 0)) > int(counts.get("wren_gift", 0))
			and int(counts.get("wren_gift", 0)) > int(counts.get("gold_patch", 0)) * 2,
		"Underbed ratio is ordered silk > wren > gold")
	_check(elite_admitted > 0 and elite_admitted < elite_total, "Elite gate admits some and refuses some")
	# Elite 70% admission: refused exactly when the first draw exceeds 70.
	for seed_number in 200:
		var rng := _rng(seed_number)
		var control := _rng(seed_number)
		var refused := control.randi_range(1, 100) > 70
		var picked := StitchedS14SideDoors.offer(rng, "Elite", false)
		_check(picked.is_empty() == refused, "Elite admission follows the 70%% gate (seed %d)" % seed_number)
		if refused:
			_check(rng.state == control.state, "refused Elite draws only the gate (seed %d)" % seed_number)
