extends SceneTree
## Scene-free V3-2 Charge regressions: the two-beat wind-up/strike projection,
## its exact x2.5 damage table, fail-closed refusal, statelessness, immutability
## and RNG purity. The test fabricates no Charge enemy record and never calls the
## live enemy phase: wiring the projection into enemy intents is a separate task.

var failures: Array[String] = []
var checks := 0
var rules := CombatEnemyKeywordRules.new()


func _initialize() -> void:
	_test_two_beat_cycles()
	_test_damage_table()
	_test_already_scaled_amount()
	_test_fail_closed_inputs()
	_test_immutability_replay_and_rng()
	_test_neighbour_keywords_untouched()
	if failures.is_empty():
		print("combat_charge_keyword_projection_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_charge_keyword_projection_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _wind_up() -> Dictionary:
	return {"ok": true, "kind": "wind_up", "damage": 0, "armed_next": true}


func _strike(damage: int) -> Dictionary:
	return {"ok": true, "kind": "attack", "damage": damage, "armed_next": false}


func _refusal() -> Dictionary:
	return {"ok": false, "kind": "", "damage": 0, "armed_next": false}


## Every projection must return the documented detached receipt shape.
func _project(amount: int, armed: Variant, label: String) -> Dictionary:
	var receipt := rules.project_charge_step(amount, armed)
	_check(receipt.get("ok") is bool and receipt.get("kind") is String
		and receipt.get("damage") is int and receipt.get("armed_next") is bool,
		label + ": returns a typed {ok, kind, damage, armed_next} receipt")
	return receipt


## AC1/AC2: a call with the unarmed bit telegraphs and returns the armed bit; the
## next call with that returned bit strikes instead of winding up again. Two full
## cycles prove the alternation without an extra attack.
func _test_two_beat_cycles() -> void:
	_check(rules.has_method("project_charge_step"),
		"the scene-free keyword rules expose the documented Charge projection")
	for cycle in range(2):
		var wind := _project(5, false, "cycle %d wind-up" % cycle)
		_check(wind == _wind_up(),
			"cycle %d: an unarmed amount 5 telegraphs a wind-up with zero damage" % cycle)
		_check(wind["armed_next"] is bool and wind["armed_next"] == true,
			"cycle %d: the wind-up returns a strict boolean armed bit" % cycle)
		var strike := _project(5, wind["armed_next"], "cycle %d strike" % cycle)
		_check(strike == _strike(12),
			"cycle %d: the armed 5 strikes for exactly 12" % cycle)
		_check(strike["armed_next"] is bool and strike["armed_next"] == false,
			"cycle %d: the strike returns the unarmed bit" % cycle)
		_check(_project(5, strike["armed_next"], "cycle %d rewind" % cycle) == _wind_up(),
			"cycle %d: the following action winds up again instead of attacking twice" % cycle)
	# A long sequence that only feeds the returned bit back in.
	var sequence: Array[Dictionary] = []
	var armed: Variant = false
	for step in range(6):
		var projected := rules.project_charge_step(9, armed)
		sequence.append(projected)
		armed = projected["armed_next"]
	_check(sequence == [_wind_up(), _strike(22), _wind_up(), _strike(22),
		_wind_up(), _strike(22)],
		"six projections alternate wind-up and strike with no extra attack")


## AC2: the independent floor-1-to-4 table from the brief. The expected values are
## authored here, not recomputed from the rule, so a wrong multiplier fails.
func _test_damage_table() -> void:
	var table := [[5, 12], [6, 15], [7, 17], [8, 20], [9, 22]]
	for row in table:
		var amount: int = row[0]
		var expected: int = row[1]
		_check(rules.project_charge_step(amount, false) == _wind_up(),
			"table %d: an unarmed amount winds up for zero damage" % amount)
		_check(rules.project_charge_step(amount, true) == _strike(expected),
			"table %d: the armed strike deals exactly %d" % [amount, expected])


## AC2: the helper trusts the caller's already floor-scaled amount. 10 is the
## floor-5-to-8 band's scaled attack for base 8, so Charge returns 25 and never
## applies the band a second time.
func _test_already_scaled_amount() -> void:
	_check(rules.project_charge_step(10, false) == _wind_up(),
		"an already scaled 10 still winds up first")
	_check(rules.project_charge_step(10, true) == _strike(25),
		"an already scaled 10 strikes for exactly 25")


## AC3: negative amounts and any non-boolean armed state fail closed with the
## stable refusal receipt, no mutation and no sticky state.
func _test_fail_closed_inputs() -> void:
	for amount in [-1, -5, -9, -1234]:
		for armed in [false, true]:
			_check(_project(amount, armed, "negative amount %d" % amount) == _refusal(),
				"negative amount %d with armed %s fails closed"
					% [amount, str(armed)])
	for armed in [0, 1, -1, 0.0, 1.0, "", "true", "false", null, [], {},
			[true], {"armed": true}]:
		var armed_before: Variant = null
		if armed is Array or armed is Dictionary:
			armed_before = armed.duplicate(true)
		_check(_project(9, armed, "non-boolean armed " + str(armed)) == _refusal(),
			"non-boolean armed %s fails closed" % str(armed))
		if armed_before != null:
			_check(armed == armed_before,
				"non-boolean armed collection %s is left unchanged" % str(armed))
	# Refusals keep no state: the same valid calls still project normally.
	_check(rules.project_charge_step(5, false) == _wind_up(),
		"a refusal leaves no armed residue behind")
	_check(rules.project_charge_step(5, true) == _strike(12),
		"a refusal leaves no damage residue behind")


## AC3: identical inputs replay the same receipt, returned receipts are detached,
## and neither valid nor refused projections touch a roster or any RNG.
func _test_immutability_replay_and_rng() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77123
	var state_before := rng.state
	rng.randi()
	_check(rng.state != state_before,
		"fixture: the seeded RandomNumberGenerator really advances when drawn")
	rng.state = state_before
	seed(24601)
	var next_global := randi()
	seed(24601)
	# A real roster proves a projection cannot touch combat state.
	var roster := CombatEnemies.new([{"id": "charge_probe", "max_hp": 30}])
	_check(roster.is_valid() and roster.get_enemy(1).get("hp") == 30,
		"fixture: a living roster to observe untouched combat state")
	var roster_before := roster.get_enemies()
	var first_wind_up: Dictionary = {}
	var first_strike: Dictionary = {}
	for repeat in range(3):
		var wind := _project(7, false, "replay %d wind-up" % repeat)
		var strike := _project(7, true, "replay %d strike" % repeat)
		_check(wind == _wind_up() and strike == _strike(17),
			"replay %d: identical inputs project the same wind-up and strike" % repeat)
		if repeat == 0:
			first_wind_up = wind.duplicate(true)
			first_strike = strike.duplicate(true)
			wind["armed_next"] = false
			strike["damage"] = 999
			strike["armed_next"] = true
			_check(rules.project_charge_step(7, false) == first_wind_up
				and rules.project_charge_step(7, true) == first_strike,
				"mutating a returned receipt cannot leak into the next projection")
		else:
			_check(wind == first_wind_up and strike == first_strike,
				"replay %d: both receipts replay exactly" % repeat)
	_check(roster.get_enemies() == roster_before,
		"valid projections change no roster HP, Block or statuses")
	_check(rules.project_charge_step(-3, false) == _refusal()
		and rules.project_charge_step(7, "armed") == _refusal(),
		"refused projections return the same stable failure receipt")
	_check(roster.get_enemies() == roster_before,
		"refused projections change no roster HP, Block or statuses")
	_check(rng.state == state_before, "Charge projections consume no local seeded RNG")
	_check(randi() == next_global, "Charge projections consume no global RNG")


## The Charge projection is additive: the older keyword services and their
## authored numbers stay exactly as they were.
func _test_neighbour_keywords_untouched() -> void:
	for method in ["resolve_thorns_retaliation", "quote_enrage_after_hit",
			"commit_enrage_after_hit", "resolve_drain_after_hit"]:
		_check(rules.has_method(method),
			"existing keyword service still exposed: " + method)
	_check(CombatEnemyKeywordRules.ENRAGE_MAX_STACKS == 3
		and CombatEnemyKeywordRules.ENRAGE_ATTACK_BONUS_PER_STACK == 2,
		"Enrage keeps its authored three-stack cap and +2 per stack")
