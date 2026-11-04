extends SceneTree
## S4 Lantern Monk: private eight-part contract in real seeded S2 4v3 rules combat.
const CATALOG_PATH := "res://data/parts/lantern_monk_parts.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const STARTERS := {
	"head": "lantern_monk_head_moth_wink",
	"arms": "lantern_monk_arms_wick_spark",
	"torso": "lantern_monk_torso_lamplight_wash",
	"legs": "lantern_monk_legs_pole_shelter",
}
const ALTERNATES := {
	"head": "lantern_monk_head_moth_cloud",
	"arms": "lantern_monk_arms_snuff_flame",
	"torso": "lantern_monk_torso_vigil_ring",
	"legs": "lantern_monk_legs_moth_shroud",
}
const IDS := [
	"lantern_monk_head_moth_wink", "lantern_monk_arms_wick_spark",
	"lantern_monk_torso_lamplight_wash", "lantern_monk_legs_pole_shelter",
	"lantern_monk_head_moth_cloud", "lantern_monk_arms_snuff_flame",
	"lantern_monk_torso_vigil_ring", "lantern_monk_legs_moth_shroud",
]
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_catalog()
	_test_each_tier()
	_test_multi_blind()
	_test_blind_next_attack()
	_test_real_healing()
	_test_guard_and_shroud()
	_test_rejection_no_spend()
	_test_replay()
	for failure in failures:
		printerr(failure)
	print("stitched_s4_lantern_monk_parts_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _catalog() -> Dictionary:
	return StitchedParts.load_catalog(CATALOG_PATH)


## S2's shipped fixture is NOT modified: move the same four existing heroes in memory
## so Lantern Monk occupies legal back-line launch rank 2, and give him actual gear.
func _config(selected: String = "", tier: int = 1, seed_value: int = 500040) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_PATH))
	if not parsed is Dictionary:
		_check(false, "shipped S2 4v3 fixture is a dictionary")
		return {}
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)):
		_check(false, "Lantern Monk catalog validates: " + str(catalog.get("error", "")))
		return {}
	var config: Dictionary = parsed
	config["parts"].append_array(catalog["parts"])
	config["seed"] = seed_value
	var monk: Dictionary = config["heroes"].pop_back()
	_check(str(monk.get("id", "")) == "lantern_monk", "real S2 fourth hero is Lantern Monk")
	config["heroes"].insert(1, monk)
	var gear: Dictionary = {}
	for slot in STARTERS:
		var part_id: String = STARTERS[slot]
		if not selected.is_empty() and catalog["by_id"].has(selected) and str(catalog["by_id"][selected]["slot"]) == slot:
			part_id = selected
		gear[slot] = {"id": part_id, "tier": tier}
	config["heroes"][1]["parts"] = gear
	return config


func _battle(selected: String = "", tier: int = 1, seed_value: int = 500040) -> StitchedRules:
	var config := _config(selected, tier, seed_value)
	if config.is_empty():
		return null
	var created := StitchedRules.create(config)
	_check(bool(created.get("ok", false)), "real seeded Lantern Monk creation: " + str(created.get("error", "")))
	if not bool(created.get("ok", false)):
		return null
	var b: StitchedRules = created["battle"]
	_check(b.get_heroes().size() == 4 and b.get_foes().size() == 3 and int(b.get_unit("lantern_monk").get("rank", -1)) == 2,
		"real four-hero/three-foe S2 battle, Lantern Monk in rank 2")
	_check(b.get_unit("lantern_monk").get("parts", {}).size() == 4,
		"real Lantern Monk has four actually equipped slots")
	return b


func _to(b: StitchedRules, actor_id: String, limit: int = 55) -> bool:
	for step in range(limit):
		if b.is_over():
			return false
		if b.current_actor_id() == actor_id:
			return true
		if not bool(b.pass_turn().get("ok", false)):
			return false
	return false


func _test_catalog() -> void:
	var cat := _catalog()
	_check(bool(cat.get("ok", false)), "AC1: StitchedParts validates real Lantern Monk JSON")
	if not bool(cat.get("ok", false)):
		return
	var counts := {"head": 0, "arms": 0, "torso": 0, "legs": 0}
	var seen: Dictionary = {}
	var seen_moves: Dictionary = {}
	for id in IDS:
		_check(cat["by_id"].has(id), "AC1: required named part present: " + id)
	for part in cat["parts"]:
		var id := str(part["id"])
		_check(not seen.has(id) and id in IDS and str(part["owner"]) == "lantern_monk",
			"AC1: unique exclusively Lantern Monk-owned part " + id)
		seen[id] = true
		var slot: String = str(part["slot"])
		if counts.has(slot):
			counts[slot] += 1
		_check(str(part["ability"]["id"]).begins_with("lantern_monk_") and not seen_moves.has(str(part["ability"]["id"])),
			"AC1: one unique native ability per " + id)
		seen_moves[str(part["ability"]["id"])] = true
		var ab: Dictionary = part["ability"]
		_check(str(ab["move"]) in StitchedParts.MOVE_POSES
			and int(ab["launch_mask"]) == StitchedParts.rank_mask(ab["launch"])
			and int(ab["target_mask"]) == StitchedParts.rank_mask(ab["target"])
			and int(ab["launch_mask"]) != 0 and int(ab["target_mask"]) != 0,
			"AC1: named existing pose and valid launch/target rank masks " + id)
		_check(part["tiers"].has("2") and part["tiers"].has("3"),
			"AC1: explicit stitch tier II and III for " + id)
		for tier in [1, 2, 3]:
			var a := StitchedParts.ability_at_tier(part, tier)
			var s := StitchedParts.stat_at_tier(part, tier)
			_check(bool(StitchedParts.validate_ability(a).get("ok", false)),
				"AC1: tier %d ability validates %s" % [tier, id])
			_check(not s.is_empty(), "AC1: slot-compatible tier %d stat %s" % [tier, id])
			_check(tier == 1 or a != ab, "AC1: tier %d has numeric progression %s" % [tier, id])
			for key in s:
				_check(str(key) in StitchedParts.SLOT_STATS[slot], "AC1: slot-valid stat at every tier")
			for retired in ["draw", "block", "cost", "energy", "exhaust", "cleanse_debuff"]:
				_check(not a.has(retired) and not a["effects"].has(retired), "AC1: no unimplemented card effect " + retired)
	for slot in counts:
		_check(int(counts[slot]) == 2, "AC1: exactly two Lantern Monk parts in " + slot)
		_check(str(cat["by_id"][STARTERS[slot]]["slot"]) == slot
			and str(cat["by_id"][ALTERNATES[slot]]["slot"]) == slot,
			"AC1: four named starters plus four alternative names in matching slots")
	_check(bool(cat["by_id"][ALTERNATES["head"]]["ability"]["multi"])
		and cat["by_id"][ALTERNATES["head"]]["ability"]["target"] == [1, 2, 3],
		"AC1: Moth Cloud is authoritative multi-target Blind against real three-foe ranks")
	for id in [STARTERS["torso"], ALTERNATES["torso"]]:
		_check(bool(cat["by_id"][id]["ability"]["multi"]) and str(cat["by_id"][id]["ability"]["target_side"]) == "ally",
			"AC1: whole-party lantern healing uses native multi targeting")
	_check(cat["by_id"][ALTERNATES["legs"]]["ability"]["effects"].has("duration"),
		"AC1: temporary Moth Shroud Dodge has bounded duration")
	for id in IDS:
		var malformed: Dictionary = cat["by_id"][id].duplicate(true)
		malformed["tiers"]["4"] = {"ability": {"acc": 99}}
		_check(not bool(StitchedParts.validate_part(malformed).get("ok", false)),
			"AC3: illegal tier IV rejects every catalog part")
	var bad_dodge: Dictionary = cat["by_id"][ALTERNATES["legs"]].duplicate(true)
	bad_dodge["tiers"]["2"]["ability"]["effects"] = {"dodge": 5}
	_check(not bool(StitchedParts.validate_part(bad_dodge).get("ok", false)),
		"AC3: tier-II Dodge without paired duration rejects")
	var bad_mask: Dictionary = cat["by_id"][ALTERNATES["head"]].duplicate(true)
	bad_mask["ability"]["target"] = [1, 2, 3, 5]
	_check(not bool(StitchedParts.validate_part(bad_mask).get("ok", false)),
		"AC3: out-of-bounds target rank rejects")


func _test_each_tier() -> void:
	var hits: Dictionary = {}
	for id in IDS:
		hits[id] = 0
		for tier in [1, 2, 3]:
			var b := _battle(id, tier, 500041 + tier)
			if b == null or not _to(b, "lantern_monk"):
				_check(false, "AC2: scheduled Lantern Monk turn for %s tier %d" % [id, tier])
				continue
			var part: Dictionary = _catalog()["by_id"][id]
			var ability: Dictionary = StitchedParts.ability_at_tier(part, tier)
			var before := b.state_snapshot()
			var result := b.use_part(id, 1)
			_check(bool(result.get("ok", false)) and str(result.get("part", "")) == id
				and str(result.get("actor", "")) == "lantern_monk"
				and str(result.get("ability", "")) == str(ability["id"]),
				"AC2: actual equipped part executes from legal rank at tier %d: %s" % [tier, id])
			if not bool(result.get("ok", false)):
				continue
			var receipts: Array = result.get("results", [])
			_check(not receipts.is_empty() and before != b.state_snapshot(),
				"AC2: real battle state and nonempty target receipts for " + id)
			if bool(ability["multi"]):
				var expected_count := 3 if str(ability["target_side"]) == "enemy" else 4
				var targets: Dictionary = {}
				for receipt in receipts:
					targets[str(receipt["target"])] = true
				_check(receipts.size() == expected_count and targets.size() == expected_count,
					"AC2: native multi resolves all real targets once for " + id)
			else:
				_check(receipts.size() == 1, "AC2: non-multi ability resolves exactly one target for " + id)
			for receipt in receipts:
				if bool(receipt.get("hit", false)):
					hits[id] += 1
					for effect in ability["effects"]:
						if str(effect) == "duration":
							continue
						_check(receipt.get("statuses", []).any(func(s): return str(s.get("status", "")) == str(effect)),
							"AC2: actual landed effect %s appears in receipt for %s" % [effect, id])
					if str(ability["target_side"]) == "enemy":
						_check(int(b.get_unit(str(receipt["target"]))["statuses"].get("blind", 0)) > 0,
							"AC2: Blind lives on enemy battle state following the hit " + id)
			if id == ALTERNATES["legs"]:
				_check(int(b.get_unit("warden")["dodge_buff"].get("amount", 0)) > 0,
					"AC2: targeted Moth Shroud creates actual temporary Dodge on rank-1 ally")
			if id == STARTERS["legs"]:
				_check(str(b.get_unit("lantern_monk")["guard_target"]) == "warden",
					"AC2: Pole Shelter assigns the actual Guard target")
	for id in IDS:
		_check(int(hits[id]) > 0, "AC2: nonvacuous tier I-III hit/effect witness for " + id)


func _test_multi_blind() -> void:
	var witness := false
	for seed_value in range(500130, 500160):
		var b := _battle(ALTERNATES["head"], 1, seed_value)
		if b == null or not _to(b, "lantern_monk"):
			continue
		var cast := b.use_part(ALTERNATES["head"], 1)
		if not bool(cast.get("ok", false)) or cast.get("results", []).size() != 3:
			continue
		var affected := 0
		var seen: Dictionary = {}
		for receipt in cast["results"]:
			seen[str(receipt["target"])] = true
			if int(b.get_unit(str(receipt["target"]))["statuses"].get("blind", 0)) > 0:
				affected += 1
		witness = seen.has("fray_scavenger") and seen.has("scissor_crab") and seen.has("moth_scribe") and affected == 3
		if witness:
			break
	_check(witness, "AC2: real Moth Cloud Blinds all three distinct living foes via multi receipts")



func _test_blind_next_attack() -> void:
	var witnessed := false
	for seed_value in range(500380, 500420):
		var b := _battle(STARTERS["head"], 1, seed_value)
		if b == null or not _to(b, "lantern_monk"):
			continue
		var blink := b.use_part(STARTERS["head"], 1)
		if not bool(blink.get("ok", false)) or blink.get("results", []).is_empty():
			continue
		if not bool(blink["results"][0].get("hit", false)):
			continue
		if not _to(b, "fray_scavenger"):
			continue
		var before := int(b.get_unit("warden")["hp"])
		var strike := b.use_foe_ability("sack_swing", 1)
		if not bool(strike.get("ok", false)) or strike.get("results", []).is_empty():
			continue
		var receipt: Dictionary = strike["results"][0]
		witnessed = bool(receipt.get("blinded", false)) and not bool(receipt.get("hit", true))
		witnessed = witnessed and not receipt.has("roll") and int(b.get_unit("warden")["hp"]) == before
		witnessed = witnessed and not b.get_unit("fray_scavenger")["statuses"].has("blind")
		if witnessed:
			break
	_check(witnessed, "AC2: real Blind survives target's turn start, cancels its next attack without hit roll, then is consumed")


func _test_real_healing() -> void:
	for id in [STARTERS["torso"], ALTERNATES["torso"]]:
		var witnessed := false
		for seed_value in range(500200, 500245):
			var b := _battle(id, 2, seed_value)
			if b == null or not _to(b, "fray_scavenger"):
				continue
			var before := int(b.get_unit("warden")["hp"])
			var strike := b.use_foe_ability("sack_swing", 1)
			var wounded := int(b.get_unit("warden")["hp"])
			if not bool(strike.get("ok", false)) or wounded >= before or not _to(b, "lantern_monk"):
				continue
			var other_hp := int(b.get_unit("seamstress")["hp"])
			var heal := b.use_part(id, 1)
			var after := int(b.get_unit("warden")["hp"])
			if not bool(heal.get("ok", false)) or heal.get("results", []).size() != 4:
				continue
			var restored_receipt := false
			for receipt in heal["results"]:
				if str(receipt["target"]) == "warden":
					restored_receipt = receipt.get("statuses", []).any(func(s): return str(s.get("status", "")) == "heal" and int(s.get("amount", 0)) > 0)
			witnessed = after > wounded and restored_receipt
			witnessed = witnessed and int(b.get_unit("seamstress")["hp"]) == other_hp
			if id == ALTERNATES["torso"]:
				witnessed = witnessed and int(b.get_unit("warden")["dodge_buff"].get("amount", 0)) > 0
				witnessed = witnessed and heal["results"][0]["statuses"].any(func(s): return str(s.get("status", "")) == "dodge")
			if witnessed:
				break
		_check(witnessed, "AC2: genuine foe wound is restored by four-target %s with real heal/defence receipts" % id)


func _test_guard_and_shroud() -> void:
	var guard_witness := false
	for seed_value in range(500301, 500336):
		var b := _battle(STARTERS["legs"], 1, seed_value)
		if b == null or not _to(b, "lantern_monk"):
			continue
		var cast := b.use_part(STARTERS["legs"], 1)
		if not bool(cast.get("ok", false)) or str(b.get_unit("lantern_monk")["guard_target"]) != "warden":
			continue
		if not _to(b, "fray_scavenger"):
			continue
		var strike := b.use_foe_ability("sack_swing", 1)
		guard_witness = bool(strike.get("ok", false)) and strike.get("results", []).size() == 1 \
			and str(strike["results"][0].get("guarded_by", "")) == "lantern_monk"
		if guard_witness:
			break
	_check(guard_witness, "AC2: real enemy attack on Warden is intercepted by Pole Shelter guardian")
	var buff := _battle(ALTERNATES["legs"], 2, 500365)
	if buff != null and _to(buff, "lantern_monk"):
		var original := int(buff.get_unit("warden")["dodge"])
		var cast := buff.use_part(ALTERNATES["legs"], 1)
		_check(bool(cast.get("ok", false)) and int(StitchedRules.effective_dodge(buff.get_unit("warden"))) > original
			and int(buff.get_unit("warden")["dodge_buff"].get("turns", 0)) == 2,
			"AC2: Moth Shroud gives an actual bounded Dodge modifier to one real ally")


func _test_rejection_no_spend() -> void:
	var config := _config()
	if config.is_empty():
		return
	config["heroes"][1]["parts"]["arms"] = {"id": STARTERS["head"], "tier": 1}
	_check(not bool(StitchedRules.create(config).get("ok", false)), "AC3: head cannot equip to arms slot")
	config = _config()
	config["heroes"][1]["parts"]["head"] = {"id": STARTERS["head"], "tier": 4}
	_check(not bool(StitchedRules.create(config).get("ok", false)), "AC3: invalid tier IV rejects at battle creation")
	config = _config()
	config["heroes"][1]["parts"]["head"] = {"id": "lantern_monk_head_missing", "tier": 1}
	_check(not bool(StitchedRules.create(config).get("ok", false)), "AC3: non-catalog gear rejects")
	config = _config()
	config["heroes"][1]["parts"]["head"] = {"id": STARTERS["head"], "tier": 1, "torn": true}
	var created := StitchedRules.create(config)
	_check(bool(created.get("ok", false)), "AC3: a real torn Lantern Monk can enter battle")
	if bool(created.get("ok", false)):
		var torn: StitchedRules = created["battle"]
		if _to(torn, "lantern_monk"):
			_reject_without_spend(torn, STARTERS["head"], 1, "torn part")
		else:
			_check(false, "AC3: torn part witness receives a real scheduled turn")
	var b := _battle()
	if b == null or not _to(b, "lantern_monk"):
		_check(false, "AC3: illegal-action witness receives a real turn")
		return
	for action in [[STARTERS["head"], 4], [STARTERS["arms"], 4], [STARTERS["legs"], 0], ["missing_part", 1]]:
		_reject_without_spend(b, str(action[0]), int(action[1]), "illegal target/side/rank or unequipped part")
	var legal := b.use_part(STARTERS["head"], 1)
	_check(bool(legal.get("ok", false)), "AC3: a lawful action actually consumes the Monk turn")
	if bool(legal.get("ok", false)):
		_reject_without_spend(b, STARTERS["arms"], 1, "stale off-turn")
	var back := _config()
	if back.is_empty():
		return
	# Preserve the same real roster but restore original S2 rank 4, illegal for Wick Spark.
	var monk: Dictionary = back["heroes"].pop_at(1)
	back["heroes"].append(monk)
	var back_result := StitchedRules.create(back)
	_check(bool(back_result.get("ok", false)), "AC3: original preview positioning is a real valid four-rank battle")
	if bool(back_result.get("ok", false)):
		var far: StitchedRules = back_result["battle"]
		if _to(far, "lantern_monk"):
			_reject_without_spend(far, STARTERS["arms"], 1, "forbidden launch rank 4")
		else:
			_check(false, "AC3: rank-4 witness has a scheduled turn")


func _reject_without_spend(b: StitchedRules, id: String, rank: int, label: String) -> void:
	var turn := b.current_actor_id()
	var snapshot := b.state_snapshot()
	var rng := b.rng_state()
	var receipt := b.use_part(id, rank)
	_check(not bool(receipt.get("ok", false)) and str(receipt.get("error", "")) != ""
		and b.current_actor_id() == turn and b.state_snapshot() == snapshot and b.rng_state() == rng,
		"AC3: " + label + " rejects without any turn, state or RNG spend")


func _trace(seed_value: int) -> Dictionary:
	var b := _battle("", 2, seed_value)
	if b == null:
		return {}
	var receipts: Array = []
	for action in [[STARTERS["head"], 1], [STARTERS["arms"], 2], [STARTERS["torso"], 1], [STARTERS["legs"], 1]]:
		if not _to(b, "lantern_monk"):
			break
		receipts.append(b.use_part(str(action[0]), int(action[1])))
	return {"receipts": receipts, "snapshot": b.state_snapshot(), "rng": b.rng_state()}


func _test_replay() -> void:
	var first := _trace(500919)
	var second := _trace(500919)
	_check(not first.is_empty() and first == second and first.get("receipts", []).size() == 4,
		"AC3: identical seeds and real four-part action sequence replay receipts, snapshot and RNG")
	for receipt in first.get("receipts", []):
		_check(bool(receipt.get("ok", false)), "AC3: each replayed equipped-part action succeeds")
