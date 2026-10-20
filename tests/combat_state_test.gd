extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_lifecycle()
	var first := _repeated_sequence()
	var second := _repeated_sequence()
	_check(first == second, "identical deterministic sequences produce identical full traces")
	if failures.is_empty():
		print("combat_state_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_state_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _state(combat: CombatState) -> Array:
	return [combat.energy, combat.player_turn_active]


func _reject(combat: CombatState, operation: Callable, message: String) -> void:
	var before := _state(combat)
	_check(not operation.call(), message + " returns false")
	_check(_state(combat) == before, message + " preserves full state")


func _test_lifecycle() -> void:
	var combat := CombatState.new()
	_check(CombatState.TURN_ENERGY == 3, "design grants exactly three energy")
	_check(_state(combat) == [0, false], "construction is inactive with zero energy")
	for cost in [-1, 0, 1, 3, 4]:
		_reject(combat, combat.try_spend_energy.bind(cost), "inactive spending %d" % cost)
	_reject(combat, combat.end_player_turn, "initial inactive end")
	_check(combat.start_player_turn(), "first start succeeds")
	_check(_state(combat) == [3, true], "start grants three and activates")
	_reject(combat, combat.start_player_turn, "duplicate start at full energy")
	_reject(combat, combat.try_spend_energy.bind(-1), "negative active cost")
	_reject(combat, combat.try_spend_energy.bind(4), "overspending at full energy")
	_check(combat.try_spend_energy(0), "zero cost succeeds")
	_check(_state(combat) == [3, true], "zero cost preserves full energy")
	_check(combat.try_spend_energy(1), "affordable positive cost succeeds")
	_check(_state(combat) == [2, true], "positive cost deducts exactly")
	_reject(combat, combat.start_player_turn, "duplicate start cannot refill spent energy")
	_reject(combat, combat.try_spend_energy.bind(3), "overspending after spending")
	_check(combat.try_spend_energy(2), "exact remaining cost succeeds")
	_check(_state(combat) == [0, true], "exhaustion keeps turn active")
	_check(combat.try_spend_energy(0), "zero cost succeeds when exhausted")
	_check(_state(combat) == [0, true], "zero cost preserves exhausted state")
	_reject(combat, combat.try_spend_energy.bind(1), "positive cost when exhausted")
	_reject(combat, combat.try_spend_energy.bind(-1), "negative cost when exhausted")
	_reject(combat, combat.start_player_turn, "duplicate start when exhausted")
	_check(combat.end_player_turn(), "exhausted turn ends")
	_check(_state(combat) == [0, false], "end deactivates exhausted turn")
	_reject(combat, combat.end_player_turn, "duplicate end")
	_check(combat.start_player_turn(), "next turn starts")
	_check(_state(combat) == [3, true], "next turn refreshes to three")
	_check(combat.try_spend_energy(1), "spend before ending with unused energy")
	_check(_state(combat) == [2, true], "unused energy exists before end")
	_check(combat.end_player_turn(), "partly spent turn ends")
	_check(_state(combat) == [0, false], "end clears unused energy")
	_reject(combat, combat.try_spend_energy.bind(0), "zero cost after end")
	_reject(combat, combat.end_player_turn, "second duplicate end")


func _repeated_sequence() -> Array:
	var combat := CombatState.new()
	var trace: Array = [_state(combat)]
	# Exercise every affordable cost, including wholly unused and exhausted turns.
	for cost in [0, 1, 2, 3, 1, 0, 3, 2]:
		_check(combat.start_player_turn(), "repeated start succeeds")
		_check(_state(combat) == [3, true], "repeated start refreshes without accumulation")
		trace.append(_state(combat))
		_check(combat.try_spend_energy(cost), "repeated affordable spending succeeds")
		_check(_state(combat) == [3 - cost, true], "repeated spending deducts exact cost")
		trace.append(_state(combat))
		_reject(combat, combat.start_player_turn, "repeated duplicate start")
		_reject(combat, combat.try_spend_energy.bind(4 - cost), "repeated overspend by one")
		_reject(combat, combat.try_spend_energy.bind(-1), "repeated negative spending")
		_check(combat.end_player_turn(), "repeated end succeeds")
		_check(_state(combat) == [0, false], "repeated end clears all remaining energy")
		trace.append(_state(combat))
		_reject(combat, combat.end_player_turn, "repeated inactive end")
		_reject(combat, combat.try_spend_energy.bind(0), "repeated inactive zero cost")
	return trace
