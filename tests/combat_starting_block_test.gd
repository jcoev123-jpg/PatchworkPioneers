extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_ac1()
	_test_ac2()
	_test_ac3()
	_test_rng_preservation()
	var first := _repeated_sequence()
	var second := _repeated_sequence()
	_check(first == second, "identical deterministic sequences produce identical full traces")
	if failures.is_empty():
		print("combat_starting_block_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_starting_block_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _defs() -> Array:
	return [{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30}, {"id": "tinker", "max_hp": 26}]


func _snap(party: CombatParty) -> Array:
	return party.get_heroes().duplicate(true)


func _test_ac1() -> void:
	var party := CombatParty.new(_defs())
	_check(party.start_player_turn(), "initial player turn resets Block")
	var helper := CombatStartingBlock.new(party)
	var before := _snap(party)
	_check(helper.apply(), "fresh helper applies once")
	var after := _snap(party)
	_check(party.get_hero(1).get("id") == "warden", "Warden remains at position 1")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6,
		"Warden has 40 HP and exactly 6 Block")
	_check(party.get_hero(2).get("hp") == 30 and party.get_hero(2).get("block") == 0,
		"Seamstress unchanged with 0 Block")
	_check(party.get_hero(3).get("hp") == 26 and party.get_hero(3).get("block") == 0,
		"Tinker unchanged with 0 Block")
	# whole-roster: only Warden block changed from 0 to 6
	var expected_before := before.duplicate(true)
	_check(after.size() == 3, "roster size unchanged")
	for position in range(1, 4):
		var b: Dictionary = before[position - 1]
		var a: Dictionary = after[position - 1]
		if position == 1:
			b["block"] = 6
		_check(a == b, "whole-roster snapshot matches expected for position %d" % position)


func _test_ac2() -> void:
	var party := CombatParty.new(_defs())
	party.gain_block(1, 2)
	var helper := CombatStartingBlock.new(party)
	var before := _snap(party)
	_check(helper.apply(), "application with existing 2 Block succeeds")
	_check(party.get_hero(1).get("block") == 8, "existing 2 Block becomes 8")
	_check(party.get_hero(1).get("hp") == 40, "HP unchanged")
	var after_first := _snap(party)
	# second apply returns false, no mutation
	var before_second := _snap(party)
	_check(not helper.apply(), "second apply returns false")
	_check(_snap(party) == before_second, "second apply leaves roster byte-for-byte equal")
	# start_player_turn clears all block; same helper still consumed
	_check(party.start_player_turn(), "turn reset clears Block")
	for position in range(1, 4):
		_check(party.get_hero(position).get("block") == 0, "Block cleared at position %d" % position)
	_check(not helper.apply(), "same helper does not reapply after turn reset")
	_check(party.get_hero(1).get("block") == 0, "no Block re-granted after reset")


func _test_ac3() -> void:
	# null party
	var null_helper := CombatStartingBlock.new(null)
	_check(not null_helper.apply(), "null party returns false")

	# invalid party
	var invalid_party := CombatParty.new([])
	var invalid_helper := CombatStartingBlock.new(invalid_party)
	_check(not invalid_party.is_valid(), "invalid party constructed")
	_check(not invalid_helper.apply(), "invalid party returns false")

	# A legitimate adjacent move transfers the Warden to slot 2.
	var swapped_party := CombatParty.new(_defs())
	var swap := CombatPositionSwaps.preview_adjacent_swap(swapped_party, 1, 1)
	_check(swap.get("ok") == true, "actual legal adjacent Warden swap to slot 2")
	if swap.get("ok") != true:
		return
	swapped_party._heroes.assign(swap["heroes"])
	var swapped_helper := CombatStartingBlock.new(swapped_party)
	var swapped_before := _snap(swapped_party)
	_check(swapped_helper.apply(), "swapped Warden receives his opening passive at slot 2")
	var swapped_expected := swapped_before.duplicate(true)
	swapped_expected[1]["block"] = 6
	_check(_snap(swapped_party) == swapped_expected, "only slot 2 Warden gains exactly 6 Block")
	_check(not swapped_helper.apply() and _snap(swapped_party) == swapped_expected,
		"moved Warden cannot receive a second grant from the same helper")
	# Two successive legal moves also place the Warden at slot 3.
	var third_party := CombatParty.new(_defs())
	var first_move := CombatPositionSwaps.preview_adjacent_swap(third_party, 1, 1)
	_check(first_move.get("ok") == true, "first move toward slot 3 is legal")
	if first_move.get("ok") != true:
		return
	third_party._heroes.assign(first_move["heroes"])
	var second_move := CombatPositionSwaps.preview_adjacent_swap(third_party, 2, 1)
	_check(second_move.get("ok") == true, "second move into slot 3 is legal")
	if second_move.get("ok") != true:
		return
	third_party._heroes.assign(second_move["heroes"])
	var third_before := _snap(third_party)
	var third_helper := CombatStartingBlock.new(third_party)
	_check(third_helper.apply(), "Warden gains his passive at slot 3")
	var third_expected := third_before.duplicate(true)
	third_expected[2]["block"] = 6
	_check(_snap(third_party) == third_expected,
		"slot 3 receives 6, with slots 1 and 2 untouched")
	_check(not third_helper.apply() and _snap(third_party) == third_expected,
		"slot 3 grant is one-use")
	# Downing the legitimately moved Warden prevents any grant.
	var moved_downed := CombatParty.new(_defs())
	moved_downed._heroes.assign(swap["heroes"].duplicate(true))
	_check(moved_downed.start_player_turn(), "moved Warden has no stale Block before downing")
	_check(moved_downed.apply_damage(2, 40) and moved_downed.is_downed(2),
		"moved Warden is actually downed in slot 2")
	var downed_moved_before := _snap(moved_downed)
	_check(not CombatStartingBlock.new(moved_downed).apply()
		and _snap(moved_downed) == downed_moved_before,
		"downed slot-2 Warden gets no opening Block")
	# Duplication or invalid Warden identity is never rewarded.
	var duplicated := CombatParty.new(_defs())
	duplicated._heroes[1]["id"] = "warden"
	var duplicated_before := _snap(duplicated)
	_check(not CombatStartingBlock.new(duplicated).apply()
		and _snap(duplicated) == duplicated_before, "duplicate Warden fails closed")
	var bad_max := CombatParty.new(_defs())
	bad_max._heroes[0]["max_hp"] = 41
	var bad_max_before := _snap(bad_max)
	_check(not CombatStartingBlock.new(bad_max).apply()
		and _snap(bad_max) == bad_max_before, "invalid Warden max HP fails closed")

	# no Warden at all
	var no_warden_defs := [{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}, {"id": "other", "max_hp": 10}]
	var no_warden_party := CombatParty.new(no_warden_defs)
	var no_warden_helper := CombatStartingBlock.new(no_warden_party)
	var no_warden_before := _snap(no_warden_party)
	_check(not no_warden_helper.apply(), "missing Warden returns false")
	_check(_snap(no_warden_party) == no_warden_before, "missing-Warden party unchanged")

	# downed Warden
	var downed_party := CombatParty.new(_defs())
	downed_party.apply_damage(1, 40)
	_check(downed_party.is_downed(1), "Warden downed")
	var downed_helper := CombatStartingBlock.new(downed_party)
	var downed_before := _snap(downed_party)
	_check(not downed_helper.apply(), "downed Warden returns false")
	_check(_snap(downed_party) == downed_before, "downed party unchanged")

	# fresh valid party/helper succeeds independently
	var fresh_party := CombatParty.new(_defs())
	fresh_party.start_player_turn()
	var fresh_helper := CombatStartingBlock.new(fresh_party)
	_check(fresh_helper.apply(), "fresh valid helper succeeds")
	_check(fresh_party.get_hero(1).get("block") == 6, "fresh grant works")


func _test_rng_preservation() -> void:
	seed(791203)
	var next_roll := randi()
	seed(791203)
	var party := CombatParty.new(_defs())
	var snapshot := _snap(party)
	var block := CombatStartingBlock.new(party)
	_check(block.apply() and not block.apply(), "RNG fixture exercises both grant and replay")
	_check(party.get_hero(1)["block"] == 6, "RNG fixture grants actual Block")
	_check(randi() == next_roll, "opening Block grant and replay consume no global RNG")
	_check(snapshot[0]["block"] == 0, "RNG fixture compares the pre-grant party")


func _repeated_sequence() -> Array:
	var party := CombatParty.new(_defs())
	party.start_player_turn()
	var helper := CombatStartingBlock.new(party)
	var trace: Array = []
	trace.append(helper.apply())
	trace.append(_snap(party))
	trace.append(helper.apply())
	trace.append(_snap(party))
	party.gain_block(1, 2)
	# new helper for new grant? Keep same helper consumed; use fresh party for second grant scenario
	var party2 := CombatParty.new(_defs())
	party2.gain_block(1, 2)
	var helper2 := CombatStartingBlock.new(party2)
	trace.append(helper2.apply())
	trace.append(_snap(party2))
	trace.append(helper2.apply())
	trace.append(_snap(party2))
	return trace
