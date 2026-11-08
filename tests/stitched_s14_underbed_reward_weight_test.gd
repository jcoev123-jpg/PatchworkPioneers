extends SceneTree
## S14 Underbed side-door offer weights and oracle verification.

var failures: Array[String] = []
var checks := 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _initialize() -> void:
	_test_ac1_detached_records()
	_test_ac2_oracle_and_weights()
	_test_ac3_boundaries_and_attic()
	_test_ac4_session_settlement()
	for message in failures:
		printerr(message)
	print("stitched_s14_underbed_reward_weight_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


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


func _oracle_boss_underbed(rng: RandomNumberGenerator) -> Dictionary:
	var raw_text := FileAccess.get_file_as_string("res://data/stitched/s14_side_doors.json")
	var raw_json: Dictionary = JSON.parse_string(raw_text)
	var weights := {"gold_patch": 1, "silk_patch": 5, "wren_gift": 4}
	var tickets: Array = []
	var records := {}
	for door in raw_json.get("doors", []):
		if door.get("kind") == "underbed":
			records[door.id] = door
			var w: int = int(weights.get(door.get("reward", ""), 0))
			for _i in w:
				tickets.append(door.id)
	tickets.sort()
	var draw := rng.randi_range(0, tickets.size() - 1)
	return {"id": tickets[draw], "record": records[tickets[draw]]}


func _test_ac2_oracle_and_weights() -> void:
	# AC2: Given a seeded RNG and authentic Underbed choices, the helper uses a sorted ten-ticket pool
	# with 1:5:4 weights (gold:silk:Wren gift), one range draw, deterministic replay/state, and gold
	# rarer than each other option. Prove with an independent one-draw oracle and repeated seeded test.

	# 1. Independent one-draw oracle comparison across multiple seeds
	var test_seeds := [1, 7, 42, 99, 1234, 5678, 99999, 314159, 8675309, 1000000]
	for s in test_seeds:
		var oracle_rng := RandomNumberGenerator.new()
		oracle_rng.seed = s
		var oracle_res := _oracle_boss_underbed(oracle_rng)
		var oracle_state := oracle_rng.state

		var helper_rng := RandomNumberGenerator.new()
		helper_rng.seed = s
		var helper_res := StitchedS14SideDoors.offer(helper_rng, "Boss", true)
		var helper_state := helper_rng.state

		_check(helper_res.get("id") == oracle_res.id,
			"seed %d: helper selected ID matches independent sorted-ticket oracle" % s)
		_check(helper_state == oracle_state,
			"seed %d: post-draw helper rng.state matches independent oracle exactly" % s)

	# 2. Modest deterministic sample of 400 Boss offers with underbed_taken=true
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

	# Gold (10% expected) is rarer than each of silk (50% expected) and wren_gift (40% expected)
	_check(counts["underbed_stuffing_trade"] < counts["underbed_leg_trade"],
		"gold patch trade (%d) is rarer than silk patch trade (%d)" % [counts["underbed_stuffing_trade"], counts["underbed_leg_trade"]])
	_check(counts["underbed_stuffing_trade"] < counts["underbed_fear_trade"],
		"gold patch trade (%d) is rarer than wren gift trade (%d)" % [counts["underbed_stuffing_trade"], counts["underbed_fear_trade"]])

	# 3. Deterministic replay check
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
	# Attic 3 doors are equally weighted
	var attic_total: int = side_counts["attic"]
	_check(attic_total > 0, "attic was selected at least once")
	for aid in attic_counts:
		# each should be roughly 1/3 of attic offers (expect ~100 out of ~300)
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
	# AC4: Given real existing seeded Elite and Boss flow, door offers still settle through
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
