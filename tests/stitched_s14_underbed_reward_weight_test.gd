extends SceneTree
## S14 Underbed side-door offer weights and oracle verification.

var failures: Array[String] = []
var checks := 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _initialize() -> void:
	_test_ac1_catalog_fail_closed()
	_test_ac1_detached_records()
	_test_ac1_eligibility_boundaries()
	_test_ac2_oracle_and_weights()
	_test_ac3_boundaries_and_attic()
	_test_ac4_session_settlement()
	for message in failures:
		printerr(message)
	print("stitched_s14_underbed_reward_weight_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _shipped_doors_copy() -> Dictionary:
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/stitched/s14_side_doors.json"))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


## AC1: Impossible kind/reward/amount combinations fail closed through the public
## catalog parser. Every negative fixture starts from a deep copy of the shipped
## document and changes exactly one field while keeping both door families present,
## so only the tightened invariants can reject it. The shipped records and valid
## appended records still validate, without a fixed catalog total.
func _test_ac1_catalog_fail_closed() -> void:
	var valid: Dictionary = StitchedS14SideDoors.catalog(_shipped_doors_copy())
	_check(not valid.is_empty(), "valid control: unchanged deep copy of the shipped catalog validates")
	for door_id in ["underbed_stuffing_trade", "underbed_leg_trade", "underbed_fear_trade",
			"attic_waxlight", "attic_rethread", "attic_headward"]:
		_check(valid.has(door_id), "valid control: shipped door " + door_id + " still validates")

	# Future valid appends validate too; no fixed total is required.
	var appended := _shipped_doors_copy()
	appended.doors.append({"id": "underbed_spare_trade", "kind": "underbed", "cost": "max_hp",
		"amount": 6, "reward": "gold_patch"})
	var appended_catalog: Dictionary = StitchedS14SideDoors.catalog(appended)
	_check(appended_catalog.has("underbed_spare_trade")
		and appended_catalog.size() == valid.size() + 1,
		"valid appended underbed record validates without a fixed catalog total")
	var appended_attic := _shipped_doors_copy()
	appended_attic.doors.append({"id": "attic_spare_cache", "kind": "attic", "cost": "none",
		"amount": 0, "reward": "mend"})
	_check(StitchedS14SideDoors.catalog(appended_attic).has("attic_spare_cache"),
		"valid appended free Attic record validates without a fixed catalog total")

	# One-field negatives: each fixture keeps both door families, so family absence
	# can never be the reason the catalog fails closed.
	var negatives := [
		{"row": "underbed_stuffing_trade", "field": "reward", "value": "candle",
			"label": "underbed reward from the free Attic family fails closed"},
		{"row": "underbed_leg_trade", "field": "reward", "value": "head_guard",
			"label": "underbed reward outside the weighted family fails closed"},
		{"row": "underbed_fear_trade", "field": "reward", "value": "mend",
			"label": "underbed reward without a draw weight fails closed"},
		{"row": "attic_waxlight", "field": "reward", "value": "gold_patch",
			"label": "Attic reward from the weighted Underbed family fails closed"},
		{"row": "attic_rethread", "field": "reward", "value": "silk_patch",
			"label": "Attic reward outside the free family fails closed"},
		{"row": "attic_headward", "field": "amount", "value": 2,
			"label": "nonzero free Attic amount fails closed"},
		{"row": "underbed_leg_trade", "field": "amount", "value": 2,
			"label": "limb price other than exactly one limb fails closed"},
		{"row": "underbed_leg_trade", "field": "amount", "value": 0,
			"label": "zero-amount Underbed deal fails closed (preserved amount check)"},
	]
	for negative_case in negatives:
		var document := _shipped_doors_copy()
		var mutated := false
		for door in document.doors:
			if door.id == negative_case.row:
				door[negative_case.field] = negative_case.value
				mutated = true
		var kinds := {}
		for door in document.doors:
			kinds[door.kind] = true
		_check(mutated and kinds.has("underbed") and kinds.has("attic"),
			negative_case.label + " (fixture mutates one field and keeps both door families)")
		_check(StitchedS14SideDoors.catalog(document).is_empty(), negative_case.label)


func _test_ac1_detached_records() -> void:
	# AC1: Given the shipped S14 catalog, Boss and underbed_taken=true, the live-used helper offers
	# exactly one of underbed_stuffing_trade (gold_patch/max_hp/6), underbed_leg_trade (silk_patch/limb/1),
	# underbed_fear_trade (wren_gift/fear/15), returning an unchanged detached record.
	var raw_text := FileAccess.get_file_as_string("res://data/stitched/s14_side_doors.json")
	var raw_json: Dictionary = JSON.parse_string(raw_text)
	_check(raw_json.has("doors") and raw_json.doors is Array, "shipped side door catalog parsed successfully")

	var raw_underbed := {}
	for door in raw_json.get("doors", []):
		if door.get("kind") == "underbed":
			raw_underbed[door.get("id")] = door

	_check(raw_underbed.has("underbed_stuffing_trade"), "catalog contains underbed_stuffing_trade")
	_check(raw_underbed.has("underbed_leg_trade"), "catalog contains underbed_leg_trade")
	_check(raw_underbed.has("underbed_fear_trade"), "catalog contains underbed_fear_trade")

	# Verify expected costs, amounts, and rewards in raw JSON
	var stuffing: Dictionary = raw_underbed.get("underbed_stuffing_trade", {})
	_check(stuffing.get("cost") == "max_hp" and stuffing.get("amount") == 6 and stuffing.get("reward") == "gold_patch",
		"underbed_stuffing_trade has gold_patch/max_hp/6")

	var leg: Dictionary = raw_underbed.get("underbed_leg_trade", {})
	_check(leg.get("cost") == "limb" and leg.get("amount") == 1 and leg.get("reward") == "silk_patch",
		"underbed_leg_trade has silk_patch/limb/1")

	var fear: Dictionary = raw_underbed.get("underbed_fear_trade", {})
	_check(fear.get("cost") == "fear" and fear.get("amount") == 15 and fear.get("reward") == "wren_gift",
		"underbed_fear_trade has wren_gift/fear/15")

	# Sample with Boss and underbed_taken=true to observe all 3 offers and check integrity and detachment
	var rng := RandomNumberGenerator.new()
	rng.seed = 98765
	var observed := {}
	for _i in 300:
		var offer := StitchedS14SideDoors.offer(rng, "Boss", true)
		_check(not offer.is_empty(), "Boss underbed offer is nonempty")
		var door_id: String = offer.get("id", "")
		_check(raw_underbed.has(door_id), "offered door is an authentic underbed door")
		if not observed.has(door_id):
			observed[door_id] = offer
			var raw_record: Dictionary = raw_underbed[door_id]
			_check(offer.get("kind") == raw_record.get("kind") \
				and offer.get("cost") == raw_record.get("cost") \
				and offer.get("amount") == raw_record.get("amount") \
				and offer.get("reward") == raw_record.get("reward"),
				"offered " + door_id + " matches raw catalog record exactly")
		if observed.size() == 3:
			break

	_check(observed.size() == 3, "all three underbed doors witnessed from helper")

	# Verify records returned are detached clones, not references to internal catalog
	var test_rng := RandomNumberGenerator.new()
	test_rng.seed = 111
	var first_offer := StitchedS14SideDoors.offer(test_rng, "Boss", true)
	first_offer["injected_flag"] = true
	first_offer["amount"] = 9999
	var catalog_after := StitchedS14SideDoors.catalog()
	_check(not catalog_after[first_offer.id].has("injected_flag"),
		"returned offer is detached from catalog cache")
	_check(catalog_after[first_offer.id].amount != 9999,
		"mutating offer amount does not mutate catalog cache")

	test_rng.seed = 111
	var repeat_offer := StitchedS14SideDoors.offer(test_rng, "Boss", true)
	_check(not repeat_offer.has("injected_flag") and repeat_offer.amount != 9999,
		"repeated offer on same seed is fresh detached record")


func _test_ac1_eligibility_boundaries() -> void:
	# AC1: Given a real settled Elite/Boss state, only non-LOST heroes with base_max_hp - 6 >= 10 can support
	# underbed_stuffing_trade; only non-LOST heroes with untorn legs can support underbed_leg_trade;
	# underbed_fear_trade is eligible only when Wren fear <= 85, a living hero exists and an unequipped gift exists.
	# A deterministic boundary test on each price and the live session verifies offer never names a currently
	# unpayable Underbed deal.

	# 1. Direct helper eligibility filtering on each trade type
	# Only stuffing payable (leg=false, stuffing=true, fear=false)
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 1001
	for _i in 50:
		var off := StitchedS14SideDoors.offer(rng1, "Boss", true, false, true, false)
		_check(off.get("id") == "underbed_stuffing_trade", "only stuffing payable offers only stuffing trade")

	# Only leg payable (leg=true, stuffing=false, fear=false)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 1002
	for _i in 50:
		var off := StitchedS14SideDoors.offer(rng2, "Boss", true, true, false, false)
		_check(off.get("id") == "underbed_leg_trade", "only leg payable offers only leg trade")

	# Only fear payable (leg=false, stuffing=false, fear=true)
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 1003
	for _i in 50:
		var off := StitchedS14SideDoors.offer(rng3, "Boss", true, false, false, true)
		_check(off.get("id") == "underbed_fear_trade", "only fear payable offers only fear trade")

	# Fully exhausted underbed with underbed_taken=true
	var rng4 := RandomNumberGenerator.new()
	rng4.seed = 1004
	for _i in 50:
		var state_before := rng4.state
		var off := StitchedS14SideDoors.offer(rng4, "Boss", true, false, false, false)
		_check(off.is_empty(), "exhausted underbed with underbed_taken=true returns empty offer")
		_check(rng4.state == state_before, "exhausted underbed with underbed_taken=true consumes 0 RNG draws")

	# Fully exhausted underbed with underbed_taken=false
	var rng5 := RandomNumberGenerator.new()
	rng5.seed = 1005
	for _i in 50:
		var off := StitchedS14SideDoors.offer(rng5, "Boss", false, false, false, false)
		_check(off.get("kind") == "attic", "exhausted underbed with underbed_taken=false offers Attic")

	# 2. Live session battle boundary tests
	# Case A: max-HP insufficient at base_max_hp 15 versus eligible at 16
	# Seed 6 reaches Elite victory and chooses Underbed.
	var s16 := StitchedRunSession.start(6)
	var elite_id := ""
	for id in s16.choices():
		if s16.map.get_node(id).type == "Elite":
			elite_id = id
			break
	_check(s16.enter(elite_id, s16.snapshot()), "s16 enters Elite")
	_check(_play_live_battle(s16) and s16.battle.outcome() == "victory", "s16 wins live Elite battle")
	for u in s16.battle._units.values():
		if u.get("side") == "hero":
			u["parts"]["legs"]["torn"] = true
			u["base_max_hp"] = 16
	for h in s16.heroes:
		h.parts.legs.torn = true
		h.base_max_hp = 16
	s16._kid_fear._fear = 86
	s16.gift_slots = s16.gift_pool.duplicate()
	s16._seal()
	_check(s16.settle_battle(s16.battle), "s16 settles battle")
	_check(s16.door_offer.get("id") == "underbed_stuffing_trade",
		"base_max_hp 16 satisfies 16 - 6 >= 10: stuffing trade offered in live session")

	var s15 := StitchedRunSession.start(6)
	_check(s15.enter(elite_id, s15.snapshot()), "s15 enters Elite")
	_check(_play_live_battle(s15) and s15.battle.outcome() == "victory", "s15 wins live Elite battle")
	for u in s15.battle._units.values():
		if u.get("side") == "hero":
			u["parts"]["legs"]["torn"] = true
			u["base_max_hp"] = 15
	for h in s15.heroes:
		h.parts.legs.torn = true
		h.base_max_hp = 15
	s15._kid_fear._fear = 86
	s15.gift_slots = s15.gift_pool.duplicate()
	s15._seal()
	_check(s15.settle_battle(s15.battle), "s15 settles battle")
	_check(s15.door_offer.get("id") != "underbed_stuffing_trade" \
		and s15.door_offer.get("kind") == "attic",
		"base_max_hp 15 fails 15 - 6 >= 10: stuffing trade is never offered; Attic offered instead")

	# Case B: fear 85 versus 86
	# Seed 7 reaches Elite victory and chooses fear trade when eligible.
	var sf85 := StitchedRunSession.start(7)
	var elite_id7 := ""
	for id in sf85.choices():
		if sf85.map.get_node(id).type == "Elite":
			elite_id7 = id
			break
	_check(sf85.enter(elite_id7, sf85.snapshot()), "sf85 enters Elite")
	_check(_play_live_battle(sf85) and sf85.battle.outcome() == "victory", "sf85 wins live Elite battle")
	for u in sf85.battle._units.values():
		if u.get("side") == "hero":
			u["parts"]["legs"]["torn"] = true
			u["base_max_hp"] = 15
	for h in sf85.heroes:
		h.parts.legs.torn = true
		h.base_max_hp = 15
	sf85._kid_fear._fear = 85
	sf85.gift_slots = []
	sf85._seal()
	_check(sf85.settle_battle(sf85.battle), "sf85 settles battle")
	_check(sf85.door_offer.get("id") == "underbed_fear_trade",
		"fear 85 <= 85 with living dolls and available gifts: fear trade offered in live session")

	var sf86 := StitchedRunSession.start(7)
	_check(sf86.enter(elite_id7, sf86.snapshot()), "sf86 enters Elite")
	_check(_play_live_battle(sf86) and sf86.battle.outcome() == "victory", "sf86 wins live Elite battle")
	for u in sf86.battle._units.values():
		if u.get("side") == "hero":
			u["parts"]["legs"]["torn"] = true
			u["base_max_hp"] = 15
	for h in sf86.heroes:
		h.parts.legs.torn = true
		h.base_max_hp = 15
	sf86._kid_fear._fear = 86
	sf86.gift_slots = []
	sf86._seal()
	_check(sf86.settle_battle(sf86.battle), "sf86 settles battle")
	_check(sf86.door_offer.get("id") != "underbed_fear_trade",
		"fear 86 > 85: fear trade is never offered in live session")

	# Case C: no free gift versus an available gift
	var s_no_gift := StitchedRunSession.start(7)
	_check(s_no_gift.enter(elite_id7, s_no_gift.snapshot()), "s_no_gift enters Elite")
	_check(_play_live_battle(s_no_gift) and s_no_gift.battle.outcome() == "victory", "s_no_gift wins live Elite battle")
	for u in s_no_gift.battle._units.values():
		if u.get("side") == "hero":
			u["parts"]["legs"]["torn"] = true
			u["base_max_hp"] = 15
	for h in s_no_gift.heroes:
		h.parts.legs.torn = true
		h.base_max_hp = 15
	s_no_gift._kid_fear._fear = 80
	s_no_gift.gift_slots = s_no_gift.gift_pool.duplicate()
	s_no_gift._seal()
	_check(s_no_gift.settle_battle(s_no_gift.battle), "s_no_gift settles battle")
	_check(s_no_gift.door_offer.get("id") != "underbed_fear_trade",
		"when all gifts are equipped: fear trade is never offered in live session")

	# Case D: all legs torn versus an intact leg
	# On seed 6 without modification, underbed_leg_trade was offered.
	var s_intact := StitchedRunSession.start(6)
	_check(s_intact.enter(elite_id, s_intact.snapshot()), "s_intact enters Elite")
	_check(_play_live_battle(s_intact) and s_intact.battle.outcome() == "victory", "s_intact wins live battle")
	_check(s_intact.settle_battle(s_intact.battle), "s_intact settles battle")
	_check(s_intact.door_offer.get("id") == "underbed_leg_trade",
		"intact legs present: leg trade offered on seed 6")

	var s_torn := StitchedRunSession.start(6)
	_check(s_torn.enter(elite_id, s_torn.snapshot()), "s_torn enters Elite")
	_check(_play_live_battle(s_torn) and s_torn.battle.outcome() == "victory", "s_torn wins live battle")
	for u in s_torn.battle._units.values():
		if u.get("side") == "hero":
			u["parts"]["legs"]["torn"] = true
	for h in s_torn.heroes:
		h.parts.legs.torn = true
	s_torn._seal()
	_check(s_torn.settle_battle(s_torn.battle), "s_torn settles battle")
	_check(s_torn.door_offer.get("id") != "underbed_leg_trade",
		"all legs torn: leg trade is never offered on seed 6")

	# Case E: all living dolls LOST
	var s_lost := StitchedRunSession.start(6)
	_check(s_lost.enter(elite_id, s_lost.snapshot()), "s_lost enters Elite")
	_check(_play_live_battle(s_lost) and s_lost.battle.outcome() == "victory", "s_lost wins live battle")
	for u in s_lost.battle._units.values():
		if u.get("side") == "hero":
			u["lost"] = true
	for h in s_lost.heroes:
		h.lost = true
	s_lost.underbed_taken = true
	s_lost._seal()
	_check(s_lost.settle_battle(s_lost.battle), "s_lost settles battle")
	_check(s_lost.door_offer.is_empty(),
		"all heroes LOST: living_hero is false, no underbed deal offered")


func _oracle_boss_underbed(rng: RandomNumberGenerator, leg: bool = true, stuffing: bool = true, fear: bool = true) -> Dictionary:
	var raw_text := FileAccess.get_file_as_string("res://data/stitched/s14_side_doors.json")
	var raw_json: Dictionary = JSON.parse_string(raw_text)
	var weights := {"gold_patch": 1, "silk_patch": 5, "wren_gift": 4}
	var tickets: Array = []
	var records := {}
	for door in raw_json.get("doors", []):
		if door.get("kind") == "underbed":
			if door.cost == "limb" and not leg:
				continue
			if door.cost == "max_hp" and not stuffing:
				continue
			if door.cost == "fear" and not fear:
				continue
			records[door.id] = door
			var w: int = int(weights.get(door.get("reward", ""), 0))
			for _i in w:
				tickets.append(door.id)
	tickets.sort()
	if tickets.is_empty():
		return {}
	var draw := rng.randi_range(0, tickets.size() - 1)
	return {"id": tickets[draw], "record": records[tickets[draw]]}


func _test_ac2_oracle_and_weights() -> void:
	# AC2: Given any filtered payable Underbed set, keep gold_patch:silk_patch:wren_gift original
	# ticket weights 1:5:4 among remaining choices, sorted tickets, single choice RNG and deep-detached
	# records. Independent oracle IDs and post-draw RNG state match on fixed seeds; unfiltered calls
	# with omitted new args retain all old expectations.

	# 1. Independent sorted-ticket oracle comparison across all 8 combinations of payable subsets
	var combos := [
		{"leg": true, "stuffing": true, "fear": true, "label": "all 3 payable"},
		{"leg": true, "stuffing": true, "fear": false, "label": "silk + gold"},
		{"leg": true, "stuffing": false, "fear": true, "label": "silk + wren"},
		{"leg": false, "stuffing": true, "fear": true, "label": "gold + wren"},
		{"leg": true, "stuffing": false, "fear": false, "label": "silk only"},
		{"leg": false, "stuffing": true, "fear": false, "label": "gold only"},
		{"leg": false, "stuffing": false, "fear": true, "label": "wren only"},
		{"leg": false, "stuffing": false, "fear": false, "label": "none payable"},
	]
	var test_seeds := [1, 7, 42, 99, 1234, 5678, 99999, 314159, 8675309, 1000000]
	for combo in combos:
		for s in test_seeds:
			var oracle_rng := RandomNumberGenerator.new()
			oracle_rng.seed = s
			var oracle_res := _oracle_boss_underbed(oracle_rng, combo.leg, combo.stuffing, combo.fear)
			var oracle_state := oracle_rng.state

			var helper_rng := RandomNumberGenerator.new()
			helper_rng.seed = s
			var helper_res := StitchedS14SideDoors.offer(helper_rng, "Boss", true, combo.leg, combo.stuffing, combo.fear)
			var helper_state := helper_rng.state

			_check(helper_res.get("id", "") == oracle_res.get("id", ""),
				"seed %d (%s): helper selected ID matches oracle" % [s, combo.label])
			_check(helper_state == oracle_state,
				"seed %d (%s): post-draw helper rng.state matches oracle exactly" % [s, combo.label])

	# 2. Unfiltered default signature comparison against all-3 oracle across same seeds
	for s in test_seeds:
		var oracle_rng := RandomNumberGenerator.new()
		oracle_rng.seed = s
		var oracle_res := _oracle_boss_underbed(oracle_rng, true, true, true)
		var oracle_state := oracle_rng.state

		var helper_rng := RandomNumberGenerator.new()
		helper_rng.seed = s
		var helper_res := StitchedS14SideDoors.offer(helper_rng, "Boss", true)
		var helper_state := helper_rng.state

		_check(helper_res.get("id") == oracle_res.id,
			"seed %d (unfiltered): helper selected ID matches independent oracle" % s)
		_check(helper_state == oracle_state,
			"seed %d (unfiltered): post-draw helper rng.state matches independent oracle exactly" % s)

	# 3. Sampling frequency tests verifying weights in restricted pools
	# 3a. All 3 payable: 400 sample, gold (1) < silk (5), gold (1) < wren (4)
	var sample_rng := RandomNumberGenerator.new()
	sample_rng.seed = 20261108
	var counts := {
		"underbed_stuffing_trade": 0,
		"underbed_leg_trade": 0,
		"underbed_fear_trade": 0,
	}
	var sequence: Array[String] = []
	for _i in 400:
		var off := StitchedS14SideDoors.offer(sample_rng, "Boss", true)
		var off_id: String = off.get("id", "")
		_check(counts.has(off_id), "sample offer has valid underbed ID")
		counts[off_id] += 1
		sequence.append(off_id)

	_check(counts["underbed_stuffing_trade"] > 0,
		"gold_patch trade appears in 400 sample (%d times)" % counts["underbed_stuffing_trade"])
	_check(counts["underbed_leg_trade"] > 0,
		"silk_patch trade appears in 400 sample (%d times)" % counts["underbed_leg_trade"])
	_check(counts["underbed_fear_trade"] > 0,
		"wren_gift trade appears in 400 sample (%d times)" % counts["underbed_fear_trade"])
	_check(counts["underbed_stuffing_trade"] < counts["underbed_leg_trade"],
		"gold patch trade (%d) is rarer than silk patch trade (%d)" % [counts["underbed_stuffing_trade"], counts["underbed_leg_trade"]])
	_check(counts["underbed_stuffing_trade"] < counts["underbed_fear_trade"],
		"gold patch trade (%d) is rarer than wren gift trade (%d)" % [counts["underbed_stuffing_trade"], counts["underbed_fear_trade"]])

	# 3b. Restricted pool: gold (1) + wren (4), leg excluded
	var no_leg_rng := RandomNumberGenerator.new()
	no_leg_rng.seed = 20261109
	var no_leg_counts := {"underbed_stuffing_trade": 0, "underbed_fear_trade": 0}
	for _i in 300:
		var off := StitchedS14SideDoors.offer(no_leg_rng, "Boss", true, false, true, true)
		var oid: String = off.get("id", "")
		_check(oid != "underbed_leg_trade", "no leg trade offered when leg unpayable")
		if no_leg_counts.has(oid):
			no_leg_counts[oid] += 1
	_check(no_leg_counts["underbed_stuffing_trade"] > 0 and no_leg_counts["underbed_fear_trade"] > 0,
		"both stuffing and fear trades appear when leg excluded")
	_check(no_leg_counts["underbed_stuffing_trade"] < no_leg_counts["underbed_fear_trade"],
		"gold trade (%d) is rarer than wren gift trade (%d) in 1:4 restricted pool" % [
			no_leg_counts["underbed_stuffing_trade"], no_leg_counts["underbed_fear_trade"]])

	# 3c. Restricted pool: silk (5) + wren (4), stuffing excluded
	var no_stuffing_rng := RandomNumberGenerator.new()
	no_stuffing_rng.seed = 20261110
	var no_stuffing_counts := {"underbed_leg_trade": 0, "underbed_fear_trade": 0}
	for _i in 300:
		var off := StitchedS14SideDoors.offer(no_stuffing_rng, "Boss", true, true, false, true)
		var oid: String = off.get("id", "")
		_check(oid != "underbed_stuffing_trade", "no stuffing trade offered when stuffing unpayable")
		if no_stuffing_counts.has(oid):
			no_stuffing_counts[oid] += 1
	_check(no_stuffing_counts["underbed_leg_trade"] > 0 and no_stuffing_counts["underbed_fear_trade"] > 0,
		"both leg and fear trades appear when stuffing excluded")

	# 3d. Restricted pool: gold (1) + silk (5), fear excluded
	var no_fear_rng := RandomNumberGenerator.new()
	no_fear_rng.seed = 20261111
	var no_fear_counts := {"underbed_stuffing_trade": 0, "underbed_leg_trade": 0}
	for _i in 300:
		var off := StitchedS14SideDoors.offer(no_fear_rng, "Boss", true, true, true, false)
		var oid: String = off.get("id", "")
		_check(oid != "underbed_fear_trade", "no fear trade offered when fear unpayable")
		if no_fear_counts.has(oid):
			no_fear_counts[oid] += 1
	_check(no_fear_counts["underbed_stuffing_trade"] > 0 and no_fear_counts["underbed_leg_trade"] > 0,
		"both stuffing and leg trades appear when fear excluded")
	_check(no_fear_counts["underbed_stuffing_trade"] < no_fear_counts["underbed_leg_trade"],
		"gold trade (%d) is rarer than silk trade (%d) in 1:5 restricted pool" % [
			no_fear_counts["underbed_stuffing_trade"], no_fear_counts["underbed_leg_trade"]])

	# 3e. Only one payable kind: 100% of draws pick that kind
	var single_rng := RandomNumberGenerator.new()
	single_rng.seed = 20261112
	var all_stuffing := true
	var all_leg := true
	var all_fear := true
	for _i in 100:
		if StitchedS14SideDoors.offer(single_rng, "Boss", true, false, true, false).get("id") != "underbed_stuffing_trade":
			all_stuffing = false
		if StitchedS14SideDoors.offer(single_rng, "Boss", true, true, false, false).get("id") != "underbed_leg_trade":
			all_leg = false
		if StitchedS14SideDoors.offer(single_rng, "Boss", true, false, false, true).get("id") != "underbed_fear_trade":
			all_fear = false
	_check(all_stuffing, "only stuffing payable offers underbed_stuffing_trade 100% of the time")
	_check(all_leg, "only leg payable offers underbed_leg_trade 100% of the time")
	_check(all_fear, "only fear payable offers underbed_fear_trade 100% of the time")

	# 4. Deterministic replay check
	var replay_rng := RandomNumberGenerator.new()
	replay_rng.seed = 20261108
	var replay_sequence: Array[String] = []
	for _i in 400:
		var off := StitchedS14SideDoors.offer(replay_rng, "Boss", true)
		replay_sequence.append(off.get("id", ""))
	_check(replay_sequence == sequence, "repeated 400 draws replay identically with same seed")
	_check(replay_rng.state == sample_rng.state, "post-sample RNG state matches replay RNG state")


func _test_ac3_boundaries_and_attic() -> void:
	# AC3: Given a valid catalog, an untaken Hell deal still permits either current 50/50 side,
	# Attic still samples its three free records uniformly, a taken Hell deal never admits Attic,
	# Elite still opens on <=70 of a percentile roll and Boss unconditionally, and invalid
	# kind/null RNG draws nothing. Prove with seed/negative headless assertions.

	# 1. Null RNG
	_check(StitchedS14SideDoors.offer(null, "Boss", true).is_empty(), "null RNG returns empty dict")
	_check(StitchedS14SideDoors.offer(null, "Elite", false).is_empty(), "null RNG on Elite returns empty dict")

	# 2. Invalid kinds consume no RNG
	var dummy_rng := RandomNumberGenerator.new()
	dummy_rng.seed = 54321
	for bad_kind in ["Fight", "Event", "Shop", "Campfire", "Rest", "", "boss", "elite", "invalid"]:
		var before_state := dummy_rng.state
		var bad_offer := StitchedS14SideDoors.offer(dummy_rng, bad_kind, false)
		_check(bad_offer.is_empty(), "bad kind '%s' returns empty dict" % bad_kind)
		_check(dummy_rng.state == before_state, "bad kind '%s' leaves RNG state untouched" % bad_kind)

	# 3. Taken Hell deal never admits Attic
	var taken_rng := RandomNumberGenerator.new()
	taken_rng.seed = 123456
	var all_underbed := true
	for _i in 200:
		var off := StitchedS14SideDoors.offer(taken_rng, "Boss", true)
		if off.get("kind") != "underbed":
			all_underbed = false
			break
	_check(all_underbed, "underbed_taken=true never admits Attic across 200 draws")

	# 4. Untaken Hell deal permits either 50/50 side, and Attic samples uniformly
	var untaken_rng := RandomNumberGenerator.new()
	untaken_rng.seed = 777
	var side_counts := {"underbed": 0, "attic": 0}
	var attic_counts := {
		"attic_waxlight": 0,
		"attic_rethread": 0,
		"attic_headward": 0,
	}
	for _i in 600:
		var off := StitchedS14SideDoors.offer(untaken_rng, "Boss", false)
		var kind: String = off.get("kind", "")
		if side_counts.has(kind):
			side_counts[kind] += 1
		if kind == "attic":
			var aid: String = off.get("id", "")
			if attic_counts.has(aid):
				attic_counts[aid] += 1
			_check(off.get("cost") == "none" and off.get("amount") == 0,
				"attic offer cost is none and amount is 0")

	_check(side_counts["underbed"] > 0 and side_counts["attic"] > 0,
		"both underbed (%d) and attic (%d) offered when underbed_taken=false" % [side_counts["underbed"], side_counts["attic"]])
	_check(abs(side_counts["underbed"] - side_counts["attic"]) < 100,
		"underbed and attic side choices are roughly 50/50 (%d vs %d)" % [side_counts["underbed"], side_counts["attic"]])

	_check(attic_counts["attic_waxlight"] > 0 and attic_counts["attic_rethread"] > 0 and attic_counts["attic_headward"] > 0,
		"all three Attic doors appeared when attic selected")
	var attic_total: int = side_counts["attic"]
	_check(attic_total > 0, "attic was selected at least once")
	for aid in attic_counts:
		_check(attic_counts[aid] > 40 and attic_counts[aid] < 160,
			"attic door %s uniformly sampled (%d / %d)" % [aid, attic_counts[aid], attic_total])

	# 5. Elite opens on <= 70 percentile roll, Boss unconditionally
	var elite_witness_open := false
	var elite_witness_closed := false
	for test_seed in 50:
		var test_rng := RandomNumberGenerator.new()
		test_rng.seed = test_seed
		var roll_rng := RandomNumberGenerator.new()
		roll_rng.seed = test_seed
		var first_roll := roll_rng.randi_range(1, 100)
		var elite_res := StitchedS14SideDoors.offer(test_rng, "Elite", true)
		if first_roll <= 70:
			_check(not elite_res.is_empty(), "Elite opens when percentile roll <= 70 (roll was %d)" % first_roll)
			elite_witness_open = true
		else:
			_check(elite_res.is_empty(), "Elite does not open when percentile roll > 70 (roll was %d)" % first_roll)
			_check(test_rng.state == roll_rng.state, "closed Elite consumes exactly one percentile draw")
			elite_witness_closed = true

	_check(elite_witness_open and elite_witness_closed, "both open (<=70) and closed (>70) Elite cases witnessed")

	# Boss unconditionally offers: never empty for valid catalog and RNG
	var boss_all_nonempty := true
	for test_seed in 50:
		var b_rng := RandomNumberGenerator.new()
		b_rng.seed = test_seed
		var b_offer := StitchedS14SideDoors.offer(b_rng, "Boss", false)
		if b_offer.is_empty():
			boss_all_nonempty = false
			break
	_check(boss_all_nonempty, "Boss offers unconditionally across all test seeds")

	# 6. AC4: Fully exhausted Underbed behavior
	# 6a. underbed_taken=true: never admits Attic, returns empty dict, 0 draws consumed for Boss
	var exh_taken_rng := RandomNumberGenerator.new()
	exh_taken_rng.seed = 333
	for _i in 100:
		var before_st := exh_taken_rng.state
		var off := StitchedS14SideDoors.offer(exh_taken_rng, "Boss", true, false, false, false)
		_check(off.is_empty(), "exhausted Underbed with underbed_taken=true returns empty dict for Boss")
		_check(exh_taken_rng.state == before_st,
			"exhausted Underbed with underbed_taken=true consumes 0 RNG draws for Boss")

	# 6b. underbed_taken=false: Attic unconditionally offered for Boss, uniform 3 choices, exactly 1 draw consumed
	var exh_untaken_rng := RandomNumberGenerator.new()
	exh_untaken_rng.seed = 444
	var exh_attic_counts := {"attic_waxlight": 0, "attic_rethread": 0, "attic_headward": 0}
	for _i in 300:
		var before_st := exh_untaken_rng.state
		var off := StitchedS14SideDoors.offer(exh_untaken_rng, "Boss", false, false, false, false)
		_check(off.get("kind") == "attic", "exhausted Underbed with underbed_taken=false offers Attic")
		_check(off.get("cost") == "none" and off.get("amount") == 0, "Attic offer is free")
		var aid: String = off.get("id", "")
		if exh_attic_counts.has(aid):
			exh_attic_counts[aid] += 1
		var verify_rng := RandomNumberGenerator.new()
		verify_rng.state = before_st
		var _d := verify_rng.randi_range(0, 2)
		_check(exh_untaken_rng.state == verify_rng.state,
			"exhausted Underbed Attic offer consumes exactly 1 draw (no spurious coin flip)")
	_check(exh_attic_counts["attic_waxlight"] > 40 and exh_attic_counts["attic_rethread"] > 40 and exh_attic_counts["attic_headward"] > 40,
		"all three Attic doors uniformly sampled when Underbed exhausted")

	# 6c. Elite with exhausted Underbed:
	# underbed_taken=true: always returns empty, consumes exactly 1 percentile draw
	for test_seed in 50:
		var e_rng := RandomNumberGenerator.new()
		e_rng.seed = test_seed
		var roll_rng := RandomNumberGenerator.new()
		roll_rng.seed = test_seed
		var _roll := roll_rng.randi_range(1, 100)
		var e_off := StitchedS14SideDoors.offer(e_rng, "Elite", true, false, false, false)
		_check(e_off.is_empty(), "Elite with exhausted Underbed and underbed_taken=true always returns empty")
		_check(e_rng.state == roll_rng.state,
			"Elite with exhausted Underbed and underbed_taken=true consumes exactly 1 percentile draw")

	# underbed_taken=false: opens on <= 70 and offers Attic (2 draws: percentile + attic), closed on > 70 (1 draw)
	for test_seed in 50:
		var e_rng := RandomNumberGenerator.new()
		e_rng.seed = test_seed
		var roll_rng := RandomNumberGenerator.new()
		roll_rng.seed = test_seed
		var roll := roll_rng.randi_range(1, 100)
		var e_off := StitchedS14SideDoors.offer(e_rng, "Elite", false, false, false, false)
		if roll <= 70:
			_check(e_off.get("kind") == "attic", "Elite opens and offers Attic when underbed exhausted")
			var _attic_roll := roll_rng.randi_range(0, 2)
			_check(e_rng.state == roll_rng.state,
				"open Elite with exhausted Underbed consumes exactly 2 draws (70%% roll + attic draw)")
		else:
			_check(e_off.is_empty(), "Elite closed on roll > 70")
			_check(e_rng.state == roll_rng.state, "closed Elite consumes exactly 1 draw")


func _play_live_battle(session: StitchedRunSession) -> bool:
	var battle: StitchedRules = session.battle
	for _turn in 220:
		if battle.is_over():
			return true
		var actor := battle.get_unit(battle.current_actor_id())
		if actor.is_empty():
			return false
		var best: Dictionary = {}
		var best_score := -10000
		for ability in actor.abilities:
			if not StitchedParts.ranks_allowed(int(ability.launch_mask), int(actor.rank)):
				continue
			if actor.side == "hero" and actor.parts.has(ability.slot) and actor.parts[ability.slot].torn:
				continue
			for rank in range(1, 5):
				if battle._legal_targets(actor, ability, rank).is_empty() \
						or not battle._self_move_gate(actor, ability).is_empty():
					continue
				var score := 1
				if ability.target_side == "enemy":
					score = 20 + int(ability.dmg[1]) * 5
				elif ability.effects.has("heal"):
					for ally in battle.get_heroes():
						if int(ally.rank) == rank and not ally.lost:
							score = 5 + int(ally.max_hp) - int(ally.hp)
				if score > best_score:
					best_score = score
					best = {"ability": ability.id, "rank": rank}
		var result: Dictionary = {}
		if best.is_empty():
			result = battle.pass_turn()
		elif actor.side == "hero":
			result = battle.use_ability(best.ability, best.rank)
		else:
			result = battle.use_foe_ability(best.ability, best.rank)
		if not result.get("ok", false):
			return false
	return battle.is_over()


func _test_ac4_session_settlement() -> void:
	# AC3/AC4: Given real existing seeded Elite and Boss flow, door offers still settle through
	# unchanged session with once-only claims and authentic costs; departure, rejection and
	# saved replay stay deterministic.
	var witness := false
	for seed_number in 80:
		var session := StitchedRunSession.start(seed_number)
		if session == null:
			continue
		var elite_id := ""
		for id in session.choices():
			if session.map.get_node(id).type == "Elite":
				elite_id = id
				break
		if elite_id.is_empty() or not session.enter(elite_id, session.snapshot()):
			continue
		if not _play_live_battle(session) or session.battle.outcome() != "victory":
			continue
		if not session.settle_battle(session.battle) or session.door_offer.is_empty():
			continue

		var offered: Dictionary = session.door_offer.duplicate(true)

		# AC1: Assert the offer's requirements can be paid at the time it appears
		if offered.cost == "max_hp":
			var payable := false
			for h in session.heroes:
				if not h.lost and int(h.base_max_hp) - int(offered.amount) >= 10:
					payable = true
					break
			_check(payable, "live offered max_hp door has a non-lost hero who can pay base_max_hp - 6 >= 10")
		elif offered.cost == "limb":
			var payable := false
			for h in session.heroes:
				if not h.lost and h.parts.has("legs") and not h.parts.legs.torn:
					payable = true
					break
			_check(payable, "live offered limb door has a non-lost hero with untorn legs")
		elif offered.cost == "fear":
			var living := false
			for h in session.heroes:
				if not h.lost:
					living = true
					break
			var has_gift := session.gift_pool.any(func(g: Variant) -> bool: return not g in session.gift_slots)
			_check(living and session.kid_fear() <= 85 and has_gift,
				"live offered fear door has living hero, fear <= 85, and unequipped gift")

		var hero_id := ""
		if offered.cost != "none" or offered.reward == "head_guard":
			for hero in session.heroes:
				if hero.lost:
					continue
				if offered.cost == "max_hp" and int(hero.base_max_hp) - int(offered.amount) < 10:
					continue
				if offered.cost == "limb" and hero.parts.legs.torn:
					continue
				hero_id = hero.id
				break
			if hero_id.is_empty():
				continue

		var prior := session.snapshot()
		var before_rng := session.rng.state
		_check(not session.choose_door("fake_door", hero_id, prior)
			and session.snapshot() == prior and session.rng.state == before_rng,
			"live forged door choice preserves RNG and inventory")

		# Negative test: stale expected state fails atomically
		var stale := prior.duplicate(true)
		stale.gold += 1
		_check(not session.choose_door(str(offered.id), hero_id, stale)
			and session.snapshot() == prior and session.rng.state == before_rng,
			"live stale door choice preserves RNG and inventory")

		# Negative test: unpayable hero cannot be chosen
		if offered.cost == "limb":
			# A nonexistent or lost hero cannot pay
			_check(not session.choose_door(str(offered.id), "nonexistent_doll", prior)
				and session.snapshot() == prior and session.rng.state == before_rng,
				"nonexistent hero cannot pay limb trade")

		if not session.choose_door(str(offered.id), hero_id, prior):
			continue

		witness = true
		var committed := session.snapshot()
		_check(session.door_offer.is_empty() and session.door_history.size() == 1,
			"real Elite victory permits one authenticated side door")
		_check(not session.choose_door(str(offered.id), hero_id, prior)
			and session.snapshot() == committed, "live spent door refuses double transaction")
		var saved := StitchedRunSave.capture(session)
		_check(not saved.is_empty() and session.journal.back().action == "door",
			"real Elite transaction enters deterministic journal")
		var restored := StitchedRunSave.restore(saved)
		_check(restored != null and restored.snapshot() == committed,
			"real Elite and door purchase roundtrip through replay")
		break

	_check(witness, "seeded authentic Elite battle settlement and side door witnessed")
