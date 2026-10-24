extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_ac1()
	_test_ac2()
	_test_ac3()
	_test_bulwark_replacement()
	_test_vanguard_contract()
	_test_carryover_caps()
	_test_receipt_rejections()
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


func _test_bulwark_replacement() -> void:
	var choice := RunWardenPathChoice.new()
	_check(choice.is_valid(), "fresh RunWardenPathChoice is valid for Bulwark")
	var bulwark_receipt := choice.choose("bulwark")
	_check(bulwark_receipt.get("ok") == true, "authored Bulwark choice succeeds")
	_check(bulwark_receipt.get("path_id") == "bulwark", "receipt path_id is bulwark")
	_check(bulwark_receipt.get("owner") == "warden", "receipt owner is warden")

	# Position 1 baseline grant: 10 Block instead of 6, never 16
	var party := CombatParty.new(_defs())
	_check(party.start_player_turn(), "player turn resets party block")
	var helper := CombatStartingBlock.new(party, bulwark_receipt)
	_check(helper.get_path_receipt() == bulwark_receipt, "helper retains Bulwark receipt")
	_check(not helper.is_consumed(), "helper initially unconsumed")
	var before := _snap(party)
	_check(helper.apply(), "Bulwark helper applies once")
	_check(helper.is_consumed(), "helper consumed after successful apply")
	var after := _snap(party)
	_check(party.get_hero(1).get("id") == "warden", "Warden remains at position 1")
	_check(party.get_hero(1).get("hp") == 40, "Warden HP unchanged at 40")
	_check(party.get_hero(1).get("block") == 10, "Bulwark grants exactly 10 Block, not 6 and not 16")
	_check(party.get_hero(2).get("hp") == 30 and party.get_hero(2).get("block") == 0,
		"Seamstress unchanged with 0 Block under Bulwark")
	_check(party.get_hero(3).get("hp") == 26 and party.get_hero(3).get("block") == 0,
		"Tinker unchanged with 0 Block under Bulwark")

	# whole-roster snapshot check
	var expected_after := before.duplicate(true)
	expected_after[0]["block"] = 10
	_check(after == expected_after, "whole-roster snapshot matches exact Bulwark 10 block grant")

	# repeat apply returns false, leaves roster byte-for-byte unchanged
	var before_repeat := _snap(party)
	_check(not helper.apply(), "second apply with Bulwark returns false")
	_check(_snap(party) == before_repeat, "second apply with Bulwark leaves roster unchanged")

	# Existing 2 Block becomes 12 (2 + 10, never 2 + 16 or 2 + 6)
	var party_existing := CombatParty.new(_defs())
	party_existing.gain_block(1, 2)
	var helper_existing := CombatStartingBlock.new(party_existing, bulwark_receipt)
	_check(helper_existing.apply(), "Bulwark applies with existing 2 block")
	_check(party_existing.get_hero(1).get("block") == 12, "existing 2 Block becomes 12 (2 + 10, not 18)")
	_check(party_existing.get_hero(1).get("hp") == 40, "HP unchanged")
	_check(not helper_existing.apply(), "repeat apply on existing block helper fails")
	_check(party_existing.get_hero(1).get("block") == 12, "block remains 12 on repeat")
	_check(party_existing.start_player_turn(), "start_player_turn resets block")
	_check(not helper_existing.apply(), "same helper does not reapply after reset")
	_check(party_existing.get_hero(1).get("block") == 0, "block remains 0 after reset")

	# Swapped Warden at position 2
	var swapped_party := CombatParty.new(_defs())
	var swap := CombatPositionSwaps.preview_adjacent_swap(swapped_party, 1, 1)
	_check(swap.get("ok") == true, "legal adjacent Warden swap to slot 2")
	swapped_party._heroes.assign(swap["heroes"])
	var swapped_before := _snap(swapped_party)
	var swapped_helper := CombatStartingBlock.new(swapped_party, bulwark_receipt)
	_check(swapped_helper.apply(), "Bulwark applies to swapped Warden at slot 2")
	var swapped_expected := swapped_before.duplicate(true)
	swapped_expected[1]["block"] = 10
	_check(_snap(swapped_party) == swapped_expected, "only slot 2 Warden gains 10 Block with Bulwark")
	_check(not swapped_helper.apply() and _snap(swapped_party) == swapped_expected,
		"slot 2 Bulwark cannot reapply")

	# Swapped Warden at position 3
	var third_party := CombatParty.new(_defs())
	var move1 := CombatPositionSwaps.preview_adjacent_swap(third_party, 1, 1)
	third_party._heroes.assign(move1["heroes"])
	var move2 := CombatPositionSwaps.preview_adjacent_swap(third_party, 2, 1)
	third_party._heroes.assign(move2["heroes"])
	var third_before := _snap(third_party)
	var third_helper := CombatStartingBlock.new(third_party, bulwark_receipt)
	_check(third_helper.apply(), "Bulwark applies to Warden at slot 3")
	var third_expected := third_before.duplicate(true)
	third_expected[2]["block"] = 10
	_check(_snap(third_party) == third_expected, "only slot 3 Warden gains 10 Block with Bulwark")
	_check(not third_helper.apply() and _snap(third_party) == third_expected,
		"slot 3 Bulwark cannot reapply")

	# Backward compatible setter usage
	var party_setter := CombatParty.new(_defs())
	var helper_setter := CombatStartingBlock.new(party_setter)
	helper_setter.set_path_receipt(bulwark_receipt)
	_check(helper_setter.apply(), "helper configured via set_path_receipt applies Bulwark")
	_check(party_setter.get_hero(1).get("block") == 10, "Bulwark via setter grants 10 Block")

	# Backward compatible apply(receipt) usage
	var party_override := CombatParty.new(_defs())
	var helper_override := CombatStartingBlock.new(party_override)
	_check(helper_override.apply(bulwark_receipt), "helper passed receipt directly in apply()")
	_check(party_override.get_hero(1).get("block") == 10, "Bulwark via apply arg grants 10 Block")


func _test_vanguard_contract() -> void:
	var choice := RunWardenPathChoice.new()
	_check(choice.is_valid(), "fresh RunWardenPathChoice is valid for Vanguard")
	var vanguard_receipt := choice.choose("vanguard")
	_check(vanguard_receipt.get("ok") == true, "authored Vanguard choice succeeds")
	_check(vanguard_receipt.get("path_id") == "vanguard", "receipt path_id is vanguard")
	_check(vanguard_receipt.get("owner") == "warden", "receipt owner is warden")

	var party := CombatParty.new(_defs())
	_check(party.start_player_turn(), "player turn resets party block")
	var before := _snap(party)
	var helper := CombatStartingBlock.new(party, vanguard_receipt)
	_check(helper.apply() and helper.is_consumed(),
		"genuine zero-Block Vanguard result succeeds and latches once")
	var after := _snap(party)
	_check(party.get_hero(1).get("hp") == 40, "Warden HP unchanged at 40")
	_check(party.get_hero(1).get("block") == 0, "Vanguard replaces base 6 with no opening Block")
	_check(party.get_hero(2).get("hp") == 30 and party.get_hero(2).get("block") == 0, "Seamstress unchanged")
	_check(party.get_hero(3).get("hp") == 26 and party.get_hero(3).get("block") == 0, "Tinker unchanged")

	# Verify no extra Pinned or status effects applied by this helper
	for position in range(1, 4):
		var hero := party.get_hero(position)
		_check(hero.get("statuses", {}).is_empty(), "Hero %d has no statuses attached by helper" % position)
		_check(not hero.get("pinned", false), "Hero %d has no pinned flag attached" % position)

	var expected_after := before.duplicate(true)
	_check(after == expected_after, "Vanguard zero opening leaves entire roster unchanged")
	_check(not helper.apply(), "repeat apply with Vanguard returns false")
	_check(_snap(party) == after, "repeat apply leaves Vanguard party unchanged")

	# Moved Warden with Vanguard receipt in slot 2
	var swapped_party := CombatParty.new(_defs())
	var swap := CombatPositionSwaps.preview_adjacent_swap(swapped_party, 1, 1)
	swapped_party._heroes.assign(swap["heroes"])
	var swapped_before := _snap(swapped_party)
	var swapped_helper := CombatStartingBlock.new(swapped_party, vanguard_receipt)
	_check(swapped_helper.apply(), "Vanguard applies to moved Warden in slot 2")
	var swapped_expected := swapped_before.duplicate(true)
	_check(_snap(swapped_party) == swapped_expected and swapped_helper.is_consumed(),
		"slot 2 Warden receives no Block, zero result consumes latch")
	_check(not swapped_helper.apply(), "slot 2 Vanguard cannot reapply")

	# Two legal adjacent moves put Warden at slot 3 with no Vanguard grant.
	var third_party := CombatParty.new(_defs())
	var first_move := CombatPositionSwaps.preview_adjacent_swap(third_party, 1, 1)
	_check(first_move.get("ok") == true, "Vanguard first move to slot 2 is legal")
	if first_move.get("ok") != true:
		return
	third_party._heroes.assign(first_move["heroes"])
	var second_move := CombatPositionSwaps.preview_adjacent_swap(third_party, 2, 1)
	_check(second_move.get("ok") == true, "Vanguard second move to slot 3 is legal")
	if second_move.get("ok") != true:
		return
	third_party._heroes.assign(second_move["heroes"])
	var third_before := _snap(third_party)
	var third_helper := CombatStartingBlock.new(third_party, vanguard_receipt)
	_check(third_helper.apply() and third_helper.is_consumed()
		and _snap(third_party) == third_before,
		"slot 3 Vanguard consumes zero opening with no foreign changes")
	_check(not third_helper.apply() and _snap(third_party) == third_before,
		"slot 3 Vanguard cannot replay zero opening")
	# Unlike a grant, Vanguard must not change even pre-existing Block.
	var existing := CombatParty.new(_defs())
	_check(existing.gain_block(1, 2), "Vanguard existing Block precondition")
	var existing_before := _snap(existing)
	var existing_helper := CombatStartingBlock.new(existing, vanguard_receipt)
	_check(existing_helper.apply() and existing_helper.is_consumed()
		and _snap(existing) == existing_before,
		"Vanguard does not add to pre-existing Block")
	_check(existing.start_player_turn() and not existing_helper.apply()
		and existing.get_hero(1)["block"] == 0,
		"Vanguard latch stays consumed after next turn resets Block")

	# Compare default (+6), Vanguard (zero), and Bulwark (+10) on seeded fixtures
	seed(88101)
	var party_default := CombatParty.new(_defs())
	party_default.start_player_turn()
	var helper_default := CombatStartingBlock.new(party_default)
	_check(helper_default.apply(), "seeded default helper applies")
	var snap_default := _snap(party_default)

	seed(88102)
	var party_vanguard := CombatParty.new(_defs())
	party_vanguard.start_player_turn()
	var helper_vanguard := CombatStartingBlock.new(party_vanguard, vanguard_receipt)
	_check(helper_vanguard.apply(), "seeded Vanguard helper applies")
	var snap_vanguard := _snap(party_vanguard)

	seed(88103)
	var bulwark_receipt_fresh := RunWardenPathChoice.new().choose("bulwark")
	var party_bulwark := CombatParty.new(_defs())
	party_bulwark.start_player_turn()
	var helper_bulwark := CombatStartingBlock.new(party_bulwark, bulwark_receipt_fresh)
	_check(helper_bulwark.apply(), "seeded Bulwark helper applies")
	var snap_bulwark := _snap(party_bulwark)

	_check(snap_default[0]["block"] == 6 and snap_vanguard[0]["block"] == 0,
		"seeded default 6 and Vanguard zero are genuinely different")
	var adjusted_default := snap_default.duplicate(true)
	adjusted_default[0]["block"] = 0
	_check(snap_vanguard == adjusted_default,
		"seeded Vanguard changes only Warden's original opening Block")
	_check(snap_bulwark[0]["block"] == 10 and snap_default[0]["block"] == 6,
		"Bulwark grants 10 Block vs default 6")
	_check(snap_bulwark[1] == snap_default[1], "Seamstress identical between Bulwark and default")
	_check(snap_bulwark[2] == snap_default[2], "Tinker identical between Bulwark and default")


func _test_carryover_caps() -> void:
	var initial := CombatParty.new(_defs()).get_heroes()
	var torn := RunTornCarryover.new(initial)
	var first := torn.create_next_fight_party()
	var enemies := CombatEnemies.new([{"id": "carryover_probe", "max_hp": 10}])
	var result := CombatBattleResult.new(first, enemies)
	_check(torn.is_valid() and first != null
		and torn.begin_battle("first-fight", result, first),
		"real carryover ledger admits an opening battle")
	if first == null:
		return
	_check(first.apply_damage(1, 9999) and first.is_downed(1)
		and enemies.apply_damage(1, 9999)
		and result.evaluate() == CombatBattleResult.VICTORY
		and torn.commit_victory("first-fight", result, first).ok
		and torn.apply_reward("first-fight", result, first).ok
		and torn.choose_rest_heal("rest-after-tear").ok,
		"actual tear, reward and Rest produce an alive reduced-cap Warden")
	var mended := torn.create_next_fight_party()
	_check(mended != null and mended.get_hero(1).max_hp == 37
		and mended.get_hero(1).hp > 0, "authentic mended Warden starts under 40")

	var coat := RunTornCarryover.new(initial)
	var definitions: Array = JSON.parse_string(FileAccess.get_file_as_string(
		CombatShopPatchRules.SLOTS_CATALOG))
	definitions.append({"id": "quilted_coat", "slot": "COAT"})
	var wardrobe := RunPatchWardrobe.new(initial, ["quilted_coat"], definitions, 0)
	_check(wardrobe.is_valid() and wardrobe.sew("quilted_coat", "warden", "COAT",
		"wear-coat", wardrobe.get_snapshot()).ok
		and coat.bind_wardrobe(wardrobe, coat.torn, wardrobe.get_snapshot()),
		"genuine Warden COAT sewn and bound to same run ledger")
	var projected := coat.create_next_fight_party()
	_check(projected != null and projected.get_hero(1).max_hp == 46
		and projected.has_meta("shop_patch_projection"),
		"real COAT creates over-40 Warden with validated same-party projection")
	for kind in ["mended", "coat"]:
		for option in [
			{"name": "unselected", "receipt": null, "amount": 6},
			{"name": "bulwark", "receipt": RunWardenPathChoice.new().choose("bulwark"), "amount": 10},
			{"name": "vanguard", "receipt": RunWardenPathChoice.new().choose("vanguard"), "amount": 0}]:
			var party: CombatParty = (torn if kind == "mended" else coat).create_next_fight_party()
			if party == null:
				_check(false, kind + " retains an authentic fresh party per Path")
				continue
			var label: String = kind + " " + option.name
			var before := _snap(party)
			var expected := before.duplicate(true)
			expected[0].block = option.amount
			var helper := CombatStartingBlock.new(party, option.receipt)
			_check(helper.can_open(), label + " valid roster and receipt preflight")
			_check(helper.apply() and helper.is_consumed()
				and _snap(party) == expected,
				label + " grants exact Warden opening with no foreign changes")
			_check(not helper.apply() and _snap(party) == expected,
				label + " opening stays consumed")

	# An ordinary three-actor over-cap roster without a projection is forged.
	var forged := CombatParty.new(_defs())
	forged._heroes[0].max_hp = 41
	_check(not CombatStartingBlock.new(forged).can_open(),
		"raw 41-HP Warden cannot pass passive preflight")
	var invalid_projected := coat.create_next_fight_party()
	if invalid_projected != null:
		invalid_projected._heroes[0].max_hp = 47
		var before := _snap(invalid_projected)
		var helper := CombatStartingBlock.new(invalid_projected)
		_check(not helper.can_open() and not helper.apply()
			and not helper.is_consumed() and _snap(invalid_projected) == before,
			"COAT snapshot mismatched to 47 cap fails closed without Block or latch")


func _test_receipt_rejections() -> void:
	var catalog := StarterCards.new()
	var base_deck: Array[String] = catalog.get_starting_deck()
	var bulwark_receipt := RunWardenPathChoice.new().choose("bulwark")

	var party := CombatParty.new(_defs())
	party.start_player_turn()

	# 1. Unclaimed receipt (empty dict from get_receipt before choose)
	var unclaimed := RunWardenPathChoice.new().get_receipt()
	_assert_rejection(party, unclaimed, "unclaimed receipt", base_deck)

	# 2. Replayed receipt on already claimed RunWardenPathChoice
	var choice_replay := RunWardenPathChoice.new()
	choice_replay.choose("bulwark")
	var replayed_receipt := choice_replay.choose("bulwark")
	_assert_rejection(party, replayed_receipt, "replayed choice receipt (ok: false)", base_deck)

	# 3. Tampered starting block 16
	var tampered_block := bulwark_receipt.duplicate(true)
	tampered_block["passive"]["starting_block"] = 16
	_assert_rejection(party, tampered_block, "tampered starting block 16", base_deck)

	# 4. Tampered starting block 0
	var tampered_zero := bulwark_receipt.duplicate(true)
	tampered_zero["passive"]["starting_block"] = 0
	_assert_rejection(party, tampered_zero, "tampered starting block 0", base_deck)

	# 5. Tampered replaced block
	var tampered_replaced := bulwark_receipt.duplicate(true)
	tampered_replaced["passive"]["replaced_starting_block"] = 10
	_assert_rejection(party, tampered_replaced, "tampered replaced_starting_block", base_deck)

	# 6. Tampered passive kind
	var tampered_kind := bulwark_receipt.duplicate(true)
	tampered_kind["passive"]["kind"] = "starting_block"
	_assert_rejection(party, tampered_kind, "tampered passive kind", base_deck)

	# 7. Foreign owner seamstress
	var foreign_seamstress := bulwark_receipt.duplicate(true)
	foreign_seamstress["owner"] = "seamstress"
	_assert_rejection(party, foreign_seamstress, "foreign owner seamstress", base_deck)

	# 8. Foreign owner tinker
	var foreign_tinker := bulwark_receipt.duplicate(true)
	foreign_tinker["owner"] = "tinker"
	_assert_rejection(party, foreign_tinker, "foreign owner tinker", base_deck)

	# 9. Wrong path ID
	var wrong_path := bulwark_receipt.duplicate(true)
	wrong_path["path_id"] = "berserker"
	_assert_rejection(party, wrong_path, "unknown path ID", base_deck)

	# 10. Tampered card cost
	var tampered_cost := bulwark_receipt.duplicate(true)
	tampered_cost["card"]["cost"] = 0
	_assert_rejection(party, tampered_cost, "tampered card cost", base_deck)

	# 11. Tampered card effects
	var tampered_effects := bulwark_receipt.duplicate(true)
	tampered_effects["card"]["effects"]["block"] = 99
	_assert_rejection(party, tampered_effects, "tampered card effects", base_deck)

	# 12. Tampered display_name
	var tampered_name := bulwark_receipt.duplicate(true)
	tampered_name["display_name"] = "Cheater"
	_assert_rejection(party, tampered_name, "tampered display_name", base_deck)

	# 13. Tampered starter_deck
	var tampered_deck := bulwark_receipt.duplicate(true)
	tampered_deck["starter_deck"] = []
	_assert_rejection(party, tampered_deck, "tampered empty starter_deck", base_deck)

	# 14. Extra unexpected field
	var extra_field := bulwark_receipt.duplicate(true)
	extra_field["extra_cheat"] = true
	_assert_rejection(party, extra_field, "extra unexpected field", base_deck)

	# 15. Missing ok field
	var missing_ok := bulwark_receipt.duplicate(true)
	missing_ok.erase("ok")
	_assert_rejection(party, missing_ok, "missing ok field", base_deck)

	# 16. ok is false
	var ok_false := bulwark_receipt.duplicate(true)
	ok_false["ok"] = false
	_assert_rejection(party, ok_false, "ok=false receipt", base_deck)

	# 17. Non-dictionary receipts
	_assert_rejection(party, "bulwark", "string receipt", base_deck)
	_assert_rejection(party, ["bulwark"], "array receipt", base_deck)
	_assert_rejection(party, 10, "int receipt", base_deck)
	_assert_rejection(party, {}, "empty dict receipt", base_deck)
	_assert_rejection(party, {"ok": true}, "partial dict receipt", base_deck)

	# Roster refusals with genuine Bulwark receipt
	# 18. Downed Warden at position 1
	var downed_party := CombatParty.new(_defs())
	downed_party.apply_damage(1, 40)
	_check(downed_party.is_downed(1), "Warden downed in slot 1")
	_assert_rejection(downed_party, bulwark_receipt, "downed Warden with Bulwark", base_deck)

	# 19. Downed Warden swapped to slot 2
	var swap := CombatPositionSwaps.preview_adjacent_swap(CombatParty.new(_defs()), 1, 1)
	var moved_downed := CombatParty.new(_defs())
	moved_downed._heroes.assign(swap["heroes"].duplicate(true))
	moved_downed.apply_damage(2, 40)
	_check(moved_downed.is_downed(2), "moved Warden downed in slot 2")
	_assert_rejection(moved_downed, bulwark_receipt, "downed slot-2 Warden with Bulwark", base_deck)

	# 20. Missing Warden
	var no_warden_defs := [{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}, {"id": "other", "max_hp": 10}]
	var no_warden_party := CombatParty.new(no_warden_defs)
	_assert_rejection(no_warden_party, bulwark_receipt, "missing Warden with Bulwark", base_deck)

	# 21. Duplicate Warden
	var duplicated := CombatParty.new(_defs())
	duplicated._heroes[1]["id"] = "warden"
	_assert_rejection(duplicated, bulwark_receipt, "duplicate Warden with Bulwark", base_deck)

	# 22. Invalid Warden max HP
	var bad_max := CombatParty.new(_defs())
	bad_max._heroes[0]["max_hp"] = 41
	_assert_rejection(bad_max, bulwark_receipt, "invalid Warden max HP with Bulwark", base_deck)

	# 23. Null party
	var null_helper := CombatStartingBlock.new(null, bulwark_receipt)
	_check(not null_helper.apply(), "null party with Bulwark returns false")

	# 24. Invalid party (empty roster)
	var invalid_party := CombatParty.new([])
	var invalid_helper := CombatStartingBlock.new(invalid_party, bulwark_receipt)
	_check(not invalid_helper.apply(), "invalid party with Bulwark returns false")


func _assert_rejection(party: CombatParty, receipt: Variant, description: String, deck_snap: Array[String]) -> void:
	var before := _snap(party)
	seed(12345)
	var expected_rand := randi()
	seed(12345)
	var helper := CombatStartingBlock.new(party, receipt)
	_check(not helper.apply(), description + ": apply() returns false")
	_check(_snap(party) == before, description + ": party unchanged")
	_check(not helper.is_consumed(), description + ": helper not consumed")
	var current_deck := StarterCards.new().get_starting_deck()
	_check(current_deck == deck_snap, description + ": deck state unchanged")
	_check(randi() == expected_rand, description + ": RNG not consumed")


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

	# Test Bulwark RNG preservation
	seed(791204)
	var next_roll_bulwark := randi()
	seed(791204)
	var bulwark_receipt := RunWardenPathChoice.new().choose("bulwark")
	var party_bulwark := CombatParty.new(_defs())
	var snap_b := _snap(party_bulwark)
	var block_b := CombatStartingBlock.new(party_bulwark, bulwark_receipt)
	_check(block_b.apply() and not block_b.apply(), "Bulwark RNG fixture exercises both grant and replay")
	_check(party_bulwark.get_hero(1)["block"] == 10, "Bulwark RNG fixture grants 10 Block")
	_check(randi() == next_roll_bulwark, "Bulwark grant and replay consume no global RNG")
	_check(snap_b[0]["block"] == 0, "Bulwark RNG fixture compares pre-grant party")


func _repeated_sequence() -> Array:
	var trace: Array = []

	# Default sequence
	var party := CombatParty.new(_defs())
	party.start_player_turn()
	var helper := CombatStartingBlock.new(party)
	trace.append(helper.apply())
	trace.append(_snap(party))
	trace.append(helper.apply())
	trace.append(_snap(party))
	party.gain_block(1, 2)
	var party2 := CombatParty.new(_defs())
	party2.gain_block(1, 2)
	var helper2 := CombatStartingBlock.new(party2)
	trace.append(helper2.apply())
	trace.append(_snap(party2))
	trace.append(helper2.apply())
	trace.append(_snap(party2))

	# Bulwark sequence
	var bulwark_receipt := RunWardenPathChoice.new().choose("bulwark")
	var party_b := CombatParty.new(_defs())
	party_b.start_player_turn()
	var helper_b := CombatStartingBlock.new(party_b, bulwark_receipt)
	trace.append(helper_b.apply())
	trace.append(_snap(party_b))
	trace.append(helper_b.apply())
	trace.append(_snap(party_b))

	# Vanguard sequence
	var vanguard_receipt := RunWardenPathChoice.new().choose("vanguard")
	var party_v := CombatParty.new(_defs())
	party_v.start_player_turn()
	var helper_v := CombatStartingBlock.new(party_v, vanguard_receipt)
	trace.append(helper_v.apply())
	trace.append(_snap(party_v))
	trace.append(helper_v.apply())
	trace.append(_snap(party_v))

	# Rejection sequence
	var party_rej := CombatParty.new(_defs())
	var helper_rej := CombatStartingBlock.new(party_rej, {"bad": true})
	trace.append(helper_rej.apply())
	trace.append(_snap(party_rej))

	return trace
