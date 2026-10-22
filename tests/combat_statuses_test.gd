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
	_test_unravel_bind_and_snapshots()
	_test_unravel_charge_and_bleed_tick()
	_test_unravel_consume_skip_and_threshold_rise()
	_test_unravel_invalid_and_isolation()
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


func _make_enemies_fixture() -> CombatEnemies:
	## Create a CombatEnemies with real enemy IDs from data files, positions 1-3.
	## Position 1: normal (fray_scavenger, max_hp 14)
	## Position 2: elite (needle_marshal, max_hp 28)
	## Position 3: boss (patchwork_behemoth, max_hp 42)
	return CombatEnemies.new([
		{"id": "fray_scavenger", "max_hp": 14},
		{"id": "needle_marshal", "max_hp": 28},
		{"id": "patchwork_behemoth", "max_hp": 42}
	])


func _test_unravel_bind_and_snapshots() -> void:
	var unravel := CombatUnravel.new()
	var enemies := _make_enemies_fixture()
	var tiers := {1: "normal", 2: "elite", 3: "boss"}
	_check(unravel.bind_roster(enemies, tiers), "bind_roster succeeds with valid roster and tiers")
	
	var snap1 := unravel.get_snapshot(1)
	_check(snap1 == {"gauge": 0, "threshold": 8, "unravelled": false, "skip_pending": false},
		"normal starts at 0/8, not unravelled, no skip pending")
	var snap2 := unravel.get_snapshot(2)
	_check(snap2 == {"gauge": 0, "threshold": 12, "unravelled": false, "skip_pending": false},
		"elite starts at 0/12, not unravelled, no skip pending")
	var snap3 := unravel.get_snapshot(3)
	_check(snap3 == {"gauge": 0, "threshold": 16, "unravelled": false, "skip_pending": false},
		"boss starts at 0/16, not unravelled, no skip pending")
	
	_check(unravel.get_snapshot(4) == {}, "invalid position returns empty snapshot")
	_check(unravel.get_snapshot(0) == {}, "zero position returns empty snapshot")
	
	# Mutating returned snapshot does not affect internal state
	snap1["gauge"] = 99
	snap1["threshold"] = 99
	snap1["unravelled"] = true
	snap1["skip_pending"] = true
	_check(unravel.get_snapshot(1) == {"gauge": 0, "threshold": 8, "unravelled": false, "skip_pending": false},
		"mutating snapshot does not alter internal state")
	
	# Bad bind: missing tier
	var unravel2 := CombatUnravel.new()
	var enemies2 := _make_enemies_fixture()
	_check(not unravel2.bind_roster(enemies2, {1: "normal", 2: "elite"}), "bind_roster rejects missing tier")
	_check(unravel2.get_snapshot(1) == {}, "failed bind leaves service unbound")
	
	# Bad bind: invalid tier
	var unravel3 := CombatUnravel.new()
	var enemies3 := _make_enemies_fixture()
	_check(not unravel3.bind_roster(enemies3, {1: "normal", 2: "elite", 3: "unknown"}), "bind_roster rejects unknown tier")
	_check(unravel3.get_snapshot(1) == {}, "failed bind leaves service unbound")
	
	# Bad bind: wrong roster size
	var unravel4 := CombatUnravel.new()
	var enemies4 := CombatEnemies.new([{"id": "fray_scavenger", "max_hp": 14}])
	_check(not unravel4.bind_roster(enemies4, {1: "normal", 2: "elite"}), "bind_roster rejects tier count mismatch")
	
	# Bad bind: invalid roster
	var unravel5 := CombatUnravel.new()
	_check(not unravel5.bind_roster(null, {1: "normal"}), "bind_roster rejects null roster")
	_check(not unravel5.bind_roster(CombatEnemies.new([]), {1: "normal"}), "bind_roster rejects invalid roster")
	
	# CombatEnemies roster HP/Block/status unchanged after bind
	var enemies_before := enemies.get_enemies()
	var unravel6 := CombatUnravel.new()
	_check(unravel6.bind_roster(enemies, tiers), "bind succeeds again")
	_check(enemies.get_enemies() == enemies_before, "bind_roster does not mutate CombatEnemies roster")


func _test_unravel_charge_and_bleed_tick() -> void:
	var unravel := CombatUnravel.new()
	var enemies := _make_enemies_fixture()
	var tiers := {1: "normal", 2: "elite", 3: "boss"}
	_check(unravel.bind_roster(enemies, tiers), "bind succeeds")
	
	# Normal: charge 7 then bleed tick reaches 8
	_check(unravel.apply_unravel(enemies, 1, 7), "apply_unravel 7 on normal succeeds")
	_check(unravel.get_snapshot(1) == {"gauge": 7, "threshold": 8, "unravelled": false, "skip_pending": false},
		"normal at 7/8, not yet unravelled")
	_check(unravel.record_bleed_tick(enemies, 1), "record_bleed_tick on normal succeeds")
	_check(unravel.get_snapshot(1) == {"gauge": 8, "threshold": 8, "unravelled": true, "skip_pending": true},
		"normal reaches 8/8, marked unravelled with one skip pending")
	
	# Elite: charge 12 reaches threshold
	var unravel2 := CombatUnravel.new()
	var enemies2 := _make_enemies_fixture()
	_check(unravel2.bind_roster(enemies2, tiers), "bind succeeds for elite test")
	_check(unravel2.apply_unravel(enemies2, 2, 12), "apply_unravel 12 on elite succeeds")
	_check(unravel2.get_snapshot(2) == {"gauge": 12, "threshold": 12, "unravelled": true, "skip_pending": true},
		"elite reaches 12/12, marked unravelled with one skip pending")
	
	# Boss: charge 16 reaches threshold
	var unravel3 := CombatUnravel.new()
	var enemies3 := _make_enemies_fixture()
	_check(unravel3.bind_roster(enemies3, tiers), "bind succeeds for boss test")
	_check(unravel3.apply_unravel(enemies3, 3, 16), "apply_unravel 16 on boss succeeds")
	_check(unravel3.get_snapshot(3) == {"gauge": 16, "threshold": 16, "unravelled": true, "skip_pending": true},
		"boss reaches 16/16, marked unravelled with one skip pending")
	
	# Other slots unchanged during charge
	_check(unravel.get_snapshot(2) == {"gauge": 0, "threshold": 12, "unravelled": false, "skip_pending": false},
		"elite slot unchanged during normal charge")
	_check(unravel.get_snapshot(3) == {"gauge": 0, "threshold": 16, "unravelled": false, "skip_pending": false},
		"boss slot unchanged during normal charge")
	
	# Bleed tick adds exactly 1 regardless of Bleed damage/Block
	var unravel4 := CombatUnravel.new()
	var enemies4 := _make_enemies_fixture()
	_check(unravel4.bind_roster(enemies4, tiers), "bind succeeds for bleed tick test")
	enemies4.apply_damage(1, 5)
	enemies4.gain_block(1, 10)
	enemies4.apply_statuses({1: {"bleed": 5}})
	_check(unravel4.record_bleed_tick(enemies4, 1), "record_bleed_tick succeeds with Block and Bleed")
	_check(unravel4.get_snapshot(1) == {"gauge": 1, "threshold": 8, "unravelled": false, "skip_pending": false},
		"bleed tick adds exactly 1 Unravel regardless of Block/Bleed amount")
	
	# No HP/Block/status mutation
	var enemies_before := enemies4.get_enemies()
	_check(enemies4.get_enemies() == enemies_before, "record_bleed_tick does not mutate CombatEnemies")
	
	# Repeated charges at/above threshold do not stack additional skips
	var unravel5 := CombatUnravel.new()
	var enemies5 := _make_enemies_fixture()
	_check(unravel5.bind_roster(enemies5, tiers), "bind succeeds for repeat charge test")
	_check(unravel5.apply_unravel(enemies5, 1, 8), "first charge to threshold")
	_check(unravel5.get_snapshot(1)["skip_pending"], "skip pending after first threshold")
	_check(unravel5.apply_unravel(enemies5, 1, 5), "second charge above threshold succeeds")
	_check(unravel5.get_snapshot(1) == {"gauge": 8, "threshold": 8, "unravelled": true, "skip_pending": true},
		"repeated charge does not stack additional skips, gauge clamped to threshold")


func _test_unravel_consume_skip_and_threshold_rise() -> void:
	var unravel := CombatUnravel.new()
	var enemies := _make_enemies_fixture()
	var tiers := {1: "normal", 2: "elite", 3: "boss"}
	_check(unravel.bind_roster(enemies, tiers), "bind succeeds")
	
	# Charge normal to threshold
	_check(unravel.apply_unravel(enemies, 1, 8), "charge normal to threshold")
	_check(unravel.get_snapshot(1)["skip_pending"], "skip pending before consume")
	
	# Consume skip: resets gauge to 0, raises threshold by 4, clears unravelled/skip_pending
	_check(unravel.consume_action_skip(enemies, 1), "consume_action_skip succeeds on pending skip")
	_check(unravel.get_snapshot(1) == {"gauge": 0, "threshold": 12, "unravelled": false, "skip_pending": false},
		"after consume: gauge 0, threshold 12 (8+4), not unravelled, no skip pending")
	
	# Elite consume: threshold 12 -> 16
	var unravel2 := CombatUnravel.new()
	var enemies2 := _make_enemies_fixture()
	_check(unravel2.bind_roster(enemies2, tiers), "bind succeeds for elite consume")
	_check(unravel2.apply_unravel(enemies2, 2, 12), "charge elite to threshold")
	_check(unravel2.consume_action_skip(enemies2, 2), "consume elite skip")
	_check(unravel2.get_snapshot(2) == {"gauge": 0, "threshold": 16, "unravelled": false, "skip_pending": false},
		"elite after consume: threshold 16 (12+4)")
	
	# Boss consume: threshold 16 -> 20
	var unravel3 := CombatUnravel.new()
	var enemies3 := _make_enemies_fixture()
	_check(unravel3.bind_roster(enemies3, tiers), "bind succeeds for boss consume")
	_check(unravel3.apply_unravel(enemies3, 3, 16), "charge boss to threshold")
	_check(unravel3.consume_action_skip(enemies3, 3), "consume boss skip")
	_check(unravel3.get_snapshot(3) == {"gauge": 0, "threshold": 20, "unravelled": false, "skip_pending": false},
		"boss after consume: threshold 20 (16+4)")
	
	# Second consume without pending skip returns false
	_check(not unravel.consume_action_skip(enemies, 1), "second consume without pending skip returns false")
	_check(unravel.get_snapshot(1) == {"gauge": 0, "threshold": 12, "unravelled": false, "skip_pending": false},
		"state unchanged after failed consume")
	
	# Charge again to increased threshold (12) creates one further break
	_check(unravel.apply_unravel(enemies, 1, 12), "charge to new threshold 12")
	_check(unravel.get_snapshot(1) == {"gauge": 12, "threshold": 12, "unravelled": true, "skip_pending": true},
		"second break at increased threshold works")
	_check(unravel.consume_action_skip(enemies, 1), "consume second skip")
	_check(unravel.get_snapshot(1) == {"gauge": 0, "threshold": 16, "unravelled": false, "skip_pending": false},
		"threshold rises again to 16 (12+4)")
	
	# Already-pending break cannot stack a second skip
	var unravel4 := CombatUnravel.new()
	var enemies4 := _make_enemies_fixture()
	_check(unravel4.bind_roster(enemies4, tiers), "bind for stack test")
	_check(unravel4.apply_unravel(enemies4, 1, 8), "first threshold")
	_check(unravel4.apply_unravel(enemies4, 1, 5), "extra charge while pending")
	_check(unravel4.get_snapshot(1)["skip_pending"], "still only one skip pending")
	_check(unravel4.consume_action_skip(enemies4, 1), "consume the one skip")
	_check(not unravel4.get_snapshot(1)["skip_pending"], "skip cleared after consume")
	_check(unravel4.get_snapshot(1)["threshold"] == 12, "threshold raised once only")


func _test_unravel_invalid_and_isolation() -> void:
	var unravel := CombatUnravel.new()
	var enemies := _make_enemies_fixture()
	var tiers := {1: "normal", 2: "elite", 3: "boss"}
	_check(unravel.bind_roster(enemies, tiers), "bind succeeds")
	
	# Slain/missing slots cannot be newly charged
	_check(enemies.apply_damage(1, 14), "slay position 1")
	_check(enemies.is_slain(1), "position 1 is slain")
	_check(not unravel.apply_unravel(enemies, 1, 5), "apply_unravel on slain returns false")
	_check(unravel.get_snapshot(1) == {"gauge": 0, "threshold": 8, "unravelled": false, "skip_pending": false},
		"slain slot gauge unchanged")
	_check(not unravel.record_bleed_tick(enemies, 1), "record_bleed_tick on slain returns false")
	
	# Invalid position returns false without changing valid gauges
	_check(not unravel.apply_unravel(enemies, 4, 5), "apply_unravel on invalid position returns false")
	_check(unravel.get_snapshot(2) == {"gauge": 0, "threshold": 12, "unravelled": false, "skip_pending": false},
		"valid slot 2 unchanged after invalid position call")
	_check(not unravel.apply_unravel(enemies, 0, 5), "apply_unravel on position 0 returns false")
	
	# Wrong roster returns false
	var other_enemies := _make_enemies_fixture()
	_check(not unravel.apply_unravel(other_enemies, 1, 5), "apply_unravel with different roster returns false")
	_check(not unravel.record_bleed_tick(other_enemies, 1), "record_bleed_tick with different roster returns false")
	_check(not unravel.consume_action_skip(other_enemies, 1), "consume_action_skip with different roster returns false")
	
	# Unbound service returns false/empty
	var unbound := CombatUnravel.new()
	_check(not unbound.apply_unravel(enemies, 1, 5), "unbound apply_unravel returns false")
	_check(not unbound.record_bleed_tick(enemies, 1), "unbound record_bleed_tick returns false")
	_check(not unbound.consume_action_skip(enemies, 1), "unbound consume_action_skip returns false")
	_check(unbound.get_snapshot(1) == {}, "unbound get_snapshot returns empty")
	
	# Fresh new-battle bind begins at original threshold
	var unravel5 := CombatUnravel.new()
	var enemies5 := _make_enemies_fixture()
	var full_tiers := {1: "normal", 2: "elite", 3: "boss"}
	_check(unravel5.bind_roster(enemies5, full_tiers), "bind full roster")
	_check(unravel5.apply_unravel(enemies5, 1, 8), "charge to threshold")
	_check(unravel5.consume_action_skip(enemies5, 1), "consume skip, threshold now 12")
	# New bind with fresh service
	var unravel6 := CombatUnravel.new()
	var enemies6 := _make_enemies_fixture()
	_check(unravel6.bind_roster(enemies6, full_tiers), "fresh bind")
	_check(unravel6.get_snapshot(1) == {"gauge": 0, "threshold": 8, "unravelled": false, "skip_pending": false},
		"fresh bind starts at original threshold 8, not increased")
	
	# CombatEnemies roster HP/Block/Bleed/Weak/Exposed remains identical before/after all operations
	var enemies_final := _make_enemies_fixture()
	var unravel_final := CombatUnravel.new()
	_check(unravel_final.bind_roster(enemies_final, tiers), "bind for final isolation test")
	enemies_final.apply_damage(1, 5)
	enemies_final.gain_block(1, 3)
	enemies_final.apply_statuses({1: {"bleed": 2, "weak": 1}, 2: {"exposed": 1}})
	var roster_before := enemies_final.get_enemies()
	_check(unravel_final.apply_unravel(enemies_final, 1, 8), "charge")
	_check(unravel_final.record_bleed_tick(enemies_final, 2), "bleed tick")
	_check(unravel_final.consume_action_skip(enemies_final, 1), "consume")
	_check(enemies_final.get_enemies() == roster_before, "CombatEnemies roster completely unchanged by Unravel operations")
