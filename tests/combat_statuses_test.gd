extends SceneTree

var failures: Array[String] = []
var checks := 0
var rules := CombatStatuses.new()


func _initialize() -> void:
	_test_contract()
	_test_bleed()
	_test_attack_modifiers()
	_test_owner_windows()
	_test_invalid_and_snapshots()
	_test_replay()
	if failures.is_empty():
		print("combat_statuses_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_statuses_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _test_contract() -> void:
	_check(rules.has_method("adjusted_attack_damage") and rules.has_method("end_owner_turn"),
		"both public service entrypoints exist")


func _test_bleed() -> void:
	var original := {"bleed": 2}
	var snapshot: Dictionary = original.duplicate(true)
	var first := rules.end_owner_turn(10, 7, original)
	_check(first == {"ok": true, "hp": 8, "block": 7, "statuses": {"bleed": 1}, "bleed_hp_loss": 2},
		"Bleed 2 costs 2 direct HP, not Block, and ages once")
	_check(original == snapshot, "first tick never mutates caller's dictionary")
	var second := rules.end_owner_turn(first["hp"], first["block"], first["statuses"])
	_check(second == {"ok": true, "hp": 7, "block": 7, "statuses": {}, "bleed_hp_loss": 1},
		"Bleed 1 costs 1 direct HP without consuming Block and expires")
	var third := rules.end_owner_turn(second["hp"], second["block"], second["statuses"])
	_check(third == {"ok": true, "hp": 7, "block": 7, "statuses": {}, "bleed_hp_loss": 0},
		"expired Bleed never ticks again")
	_check(original == snapshot, "complete Bleed sequence preserves original dictionary")

	var lethal := rules.end_owner_turn(1, 99, {"bleed": 9223372036854775807})
	_check(lethal["ok"] and lethal["hp"] == 0 and lethal["bleed_hp_loss"] == 1 and lethal["block"] == 99,
		"overkill Bleed clamps to zero and preserves positive Block without overflow")
	_check(lethal["statuses"] == {"bleed": 9223372036854775806},
		"large positive Bleed duration decrements once")
	var at_zero := rules.end_owner_turn(0, 9, {"bleed": 2})
	_check(at_zero == {"ok": true, "hp": 0, "block": 9, "statuses": {"bleed": 1}, "bleed_hp_loss": 0},
		"zero HP cannot become negative, and Bleed still ages")

	var statuses := {"bleed": 2, "weak": 2, "exposed": 2}
	var before: Dictionary = statuses.duplicate(true)
	var bleed_with_modifiers := rules.end_owner_turn(10, 7, statuses)
	_check(bleed_with_modifiers["hp"] == 8 and bleed_with_modifiers["bleed_hp_loss"] == 2,
		"Weak and Exposed never modify direct Bleed HP loss")
	_check(statuses == before, "all three applied statuses remain untouched in caller")


func _test_attack_modifiers() -> void:
	for base in [0, 1, 2, 3, 5, 7, 8, 9, 11]:
		var expected_weak: int = (base * 3) / 4
		var expected_exposed: int = (base * 3) / 2
		var expected_both: int = (base * 9) / 8
		_check(rules.adjusted_attack_damage(base, {}, {}) == base,
			"unmodified attack retains base %d" % base)
		_check(rules.adjusted_attack_damage(base, {"weak": 1}, {}) == expected_weak,
			"Weak attack floors 3/4 for %d" % base)
		_check(rules.adjusted_attack_damage(base, {}, {"exposed": 1}) == expected_exposed,
			"Exposed defence floors 3/2 for %d" % base)
		_check(rules.adjusted_attack_damage(base, {"weak": 2}, {"exposed": 2}) == expected_both,
			"combined modifiers multiply 9/8 then floor once for %d" % base)
	_check(rules.adjusted_attack_damage(8, {"weak": 1}, {}) == 6
		and rules.adjusted_attack_damage(8, {}, {"exposed": 1}) == 12
		and rules.adjusted_attack_damage(8, {"weak": 1}, {"exposed": 1}) == 9,
		"design's explicit 8 -> 6, 12, 9 examples")
	_check(rules.adjusted_attack_damage(3, {"weak": 1}, {"exposed": 1}) == 3,
		"both active use one final floor (not chained rounding)")
	_check(rules.adjusted_attack_damage(8, {"exposed": 2, "bleed": 9}, {"weak": 2, "bleed": 6}) == 8,
		"only attacker Weak and defender Exposed contribute to an attack")
	_check(rules.adjusted_attack_damage(8, {"weak": 0}, {"exposed": 0}) == 8,
		"expired statuses cannot change damage")
	_check(rules.adjusted_attack_damage(0, {"weak": 1}, {"exposed": 1}) == 0,
		"zero attack damage remains zero")


func _test_owner_windows() -> void:
	var actor_a := {"bleed": 2, "weak": 2, "exposed": 2}
	var actor_b := {"weak": 1, "exposed": 1}
	var a_input: Dictionary = actor_a.duplicate(true)
	var b_input: Dictionary = actor_b.duplicate(true)
	_check(rules.adjusted_attack_damage(8, actor_a, actor_b) == 9,
		"both actor modifiers are active during their original turn")
	var a_first := rules.end_owner_turn(10, 4, actor_a)
	_check(a_first["ok"] and a_first["hp"] == 8 and a_first["block"] == 4
		and a_first["statuses"] == {"bleed": 1, "weak": 1, "exposed": 1},
		"ending actor A turn ages all A statuses once")
	_check(actor_a == a_input and actor_b == b_input,
		"ending A turn cannot age either supplied dictionary or actor B")
	_check(rules.adjusted_attack_damage(8, a_first["statuses"], actor_b) == 9
		and rules.adjusted_attack_damage(8, actor_b, a_first["statuses"]) == 9,
		"N=2 statuses remain active through next owner turn")
	var a_second := rules.end_owner_turn(a_first["hp"], a_first["block"], a_first["statuses"])
	_check(a_second["ok"] and a_second["hp"] == 7 and a_second["block"] == 4
		and a_second["statuses"].is_empty() and a_second["bleed_hp_loss"] == 1,
		"A's second owner turn expires all N=2 statuses")
	_check(rules.adjusted_attack_damage(8, a_second["statuses"], actor_b) == 12
		and rules.adjusted_attack_damage(8, actor_b, a_second["statuses"]) == 6,
		"expired A status no longer contributes while untouched B remains active")
	_check(actor_b == b_input, "two A turns never age B")
	var b_first := rules.end_owner_turn(16, 3, actor_b)
	_check(b_first == {"ok": true, "hp": 16, "block": 3, "statuses": {}, "bleed_hp_loss": 0},
		"B's own turn expires N=1 Weak and Exposed without HP loss")
	_check(rules.adjusted_attack_damage(8, b_first["statuses"], a_second["statuses"]) == 8,
		"both expired actors now deal unaffected attack damage")
	_check(actor_a == a_input and actor_b == b_input, "interleaved sequence never modifies inputs")


func _test_invalid_and_snapshots() -> void:
	var bad_statuses: Array[Dictionary] = [
		{"bleed": -1}, {"weak": -2}, {"exposed": -1}, {"bleed": 1.0},
		{"weak": "1"}, {"exposed": null}, {"bleed": true}, {"weak": []},
		{"bleed": {"nested": [1, 2]}}, {"Bleed": 2}, {"poison": 1},
		{1: 2}, {&"weak": 1}
	]
	for bad in bad_statuses:
		var prior: Dictionary = bad.duplicate(true)
		_check(rules.adjusted_attack_damage(8, bad, {}) == 0
			and rules.adjusted_attack_damage(8, {}, bad) == 0,
			"invalid status entries fail closed for both roles: " + str(bad))
		var rejected := rules.end_owner_turn(10, 7, bad)
		_check(rejected == {"ok": false, "hp": 10, "block": 7, "statuses": prior, "bleed_hp_loss": 0},
			"malformed status turn fails closed without partial aging: " + str(bad))
		_check(bad == prior, "rejecting malformed statuses never changes input")
		if bad.has("bleed") and bad["bleed"] is Dictionary:
			rejected["statuses"]["bleed"]["nested"].append(3)
			_check(bad == prior, "rejected state deep copy isolates nested caller data")

	for status in [{"bleed": 2}, {"weak": 2}, {}]:
		var snapshot: Dictionary = status.duplicate(true)
		for hp_block in [[-1, 7], [10, -1], [-1, -1]]:
			var result := rules.end_owner_turn(hp_block[0], hp_block[1], status)
			_check(result == {"ok": false, "hp": hp_block[0], "block": hp_block[1],
				"statuses": snapshot, "bleed_hp_loss": 0}, "negative HP or Block fails closed")
			_check(status == snapshot, "bad HP/Block never ages caller statuses")
		_check(rules.adjusted_attack_damage(-1, status, {}) == 0
			and rules.adjusted_attack_damage(-9223372036854775807, {}, status) == 0,
			"negative attack damage fails closed")
		_check(status == snapshot, "invalid attack damage never changes status input")
	_check(rules.adjusted_attack_damage(9223372036854775807, {}, {"exposed": 1}) == 0,
		"unrepresentable amplified attack fails closed rather than overflow")
	_check(rules.adjusted_attack_damage(9223372036854775807, {"weak": 1}, {}) > 0,
		"large attenuated attack is calculated without overflow")

	var zero_counts := {"bleed": 0, "weak": 0, "exposed": 0}
	var zero_snapshot: Dictionary = zero_counts.duplicate(true)
	var cleaned := rules.end_owner_turn(4, 2, zero_counts)
	_check(cleaned == {"ok": true, "hp": 4, "block": 2, "statuses": {}, "bleed_hp_loss": 0},
		"all zero counters expire without affecting HP or Block")
	_check(zero_counts == zero_snapshot, "zero count cleanup is independent")
	var valid := {"bleed": 2, "weak": 2}
	var valid_before: Dictionary = valid.duplicate(true)
	var copy := rules.end_owner_turn(6, 1, valid)
	copy["statuses"]["bleed"] = 200
	copy["statuses"]["exposed"] = 5
	_check(valid == valid_before, "editing successful returned status map cannot mutate original")


func _test_replay() -> void:
	var a := {"bleed": 2, "weak": 2, "exposed": 1}
	var b := {"exposed": 3}
	var a_before: Dictionary = a.duplicate(true)
	var b_before: Dictionary = b.duplicate(true)
	for unused in range(5):
		var left := rules.end_owner_turn(10, 7, a)
		var right := rules.end_owner_turn(10, 7, a)
		_check(left == right, "identical owner turn inputs reproduce complete same result")
		_check(rules.adjusted_attack_damage(11, a, b) == rules.adjusted_attack_damage(11, a, b),
			"identical attacker and defender inputs reproduce same damage")
		_check(a == a_before and b == b_before, "replay leaves both original dictionaries intact")
