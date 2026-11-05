extends SceneTree
## S4 Tinker contract: real seeded Stitched 4v3 combat, all eight parts at all tiers.
const CATALOG_PATH := "res://data/parts/tinker_parts.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const STARTERS := {
	"head": "tinker_head_cog_shot",
	"arms": "tinker_arms_scrap_bomb",
	"torso": "tinker_torso_casing_ward",
	"legs": "tinker_legs_tune_up",
}
const ALTERNATES := {
	"head": "tinker_head_spring_clamp",
	"arms": "tinker_arms_overload",
	"torso": "tinker_torso_gear_brace",
	"legs": "tinker_legs_spare_screws",
}
const ALL_IDS := [
	"tinker_head_cog_shot", "tinker_arms_scrap_bomb", "tinker_torso_casing_ward",
	"tinker_legs_tune_up", "tinker_head_spring_clamp", "tinker_arms_overload",
	"tinker_torso_gear_brace", "tinker_legs_spare_screws",
]
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_catalog()
	_test_every_tier_in_real_combat()
	_test_back_rank_shots()
	_test_casing_ward_rank_four()
	_test_overload_back_rank()
	_test_heal_and_guard()
	_test_mark_overload()
	_test_invalid_actions_and_equipment()
	_test_replay()
	for message in failures:
		printerr(message)
	print("stitched_s4_tinker_gear_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _catalog() -> Dictionary:
	return StitchedParts.load_catalog(CATALOG_PATH)


func _config(selected: String = "", tier: int = 1, seed_value: int = 499041) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_PATH))
	if not parsed is Dictionary:
		_check(false, "shipped S2 preview parses into a dictionary")
		return {}
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)):
		_check(false, "S4 Tinker catalog loads: " + str(catalog.get("error", "")))
		return {}
	var config: Dictionary = parsed
	config["parts"].append_array(catalog["parts"])
	config["seed"] = seed_value
	var gear: Dictionary = {}
	for slot in STARTERS:
		var id: String = STARTERS[slot]
		if not selected.is_empty() and str(catalog["by_id"][selected]["slot"]) == slot:
			id = selected
		gear[slot] = {"id": id, "tier": tier}
	# Only Tinker's four prototype equipped IDs change; other heroes/foes are the real S2 preview.
	config["heroes"][2]["parts"] = gear
	return config


func _battle(selected: String = "", tier: int = 1, seed_value: int = 499041) -> StitchedRules:
	var config := _config(selected, tier, seed_value)
	if config.is_empty():
		return null
	var result := StitchedRules.create(config)
	_check(bool(result.get("ok", false)), "real preview battle with %s tier %d: %s" % [selected, tier, result.get("error", "")])
	if not bool(result.get("ok", false)):
		return null
	var battle: StitchedRules = result["battle"]
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 3,
		"real four heroes and exactly three foes, without an invented fourth")
	_check(battle.get_unit("tinker").get("parts", {}).size() == 4,
		"Tinker wears actual equipment in all four slots")
	return battle


func _to(battle: StitchedRules, actor_id: String, limit: int = 48) -> bool:
	for index in range(limit):
		if battle.is_over():
			return false
		if battle.current_actor_id() == actor_id:
			return true
		var passed := battle.pass_turn()
		if not bool(passed.get("ok", false)):
			return false
	return false


func _test_catalog() -> void:
	var accepted := _catalog()
	_check(bool(accepted.get("ok", false)), "AC1: StitchedParts.load_catalog accepts Tinker")
	if not bool(accepted.get("ok", false)):
		return
	var ids: Dictionary = {}
	var moves: Dictionary = {}
	var counts := {"head": 0, "arms": 0, "torso": 0, "legs": 0}
	_check(accepted["parts"].size() == ALL_IDS.size(), "AC1: private Tinker catalog contains only the required eight")
	for expected in ALL_IDS:
		_check(accepted["by_id"].has(expected), "AC1: required ID is present: " + expected)
	for raw_part in accepted["parts"]:
		var part: Dictionary = raw_part
		var id := str(part["id"])
		_check(not ids.has(id) and id.begins_with("tinker_") and str(part["owner"]) == "tinker",
			"AC1: Tinker owns uniquely prefixed part " + id)
		ids[id] = true
		var slot := str(part["slot"])
		if counts.has(slot):
			counts[slot] = int(counts[slot]) + 1
		_check(bool(STARTERS.values().has(id) or ALTERNATES.values().has(id)),
			"AC1: only named starter/alternate parts appear: " + id)
		var base: Dictionary = part["ability"]
		var move_id := str(base["id"])
		_check(move_id.begins_with("tinker_") and not moves.has(move_id),
			"AC1: unique Tinker ability ID: " + move_id)
		moves[move_id] = true
		_check(str(base["move"]) in StitchedParts.MOVE_POSES,
			"AC1: Tinker move pose is named and legal for " + id)
		_check(not StitchedParts.rank_mask(base["launch"]) == 0 and not StitchedParts.rank_mask(base["target"]) == 0,
			"AC1: nonempty legal launch and target rank masks for " + id)
		_check(int(base["launch_mask"]) == StitchedParts.rank_mask(base["launch"]) and int(base["target_mask"]) == StitchedParts.rank_mask(base["target"]),
			"AC1: authored rank masks agree with validated derived masks for " + id)
		_check(part["tiers"].has("2") and part["tiers"].has("3"),
			"AC1: both higher stitch tiers are authored for " + id)
		for tier in [1, 2, 3]:
			var tier_ability := StitchedParts.ability_at_tier(part, tier)
			_check(bool(StitchedParts.validate_ability(tier_ability).get("ok", false)),
				"AC1: legal tier %d ability of %s" % [tier, id])
			_check(tier == 1 or tier_ability != base,
				"AC1: stitch tier %d upgrades native ability numbers for %s" % [tier, id])
			_check(not StitchedParts.stat_at_tier(part, tier).is_empty(),
				"AC1: tier %d has slot-compatible stat for %s" % [tier, id])
	for slot in counts:
		_check(int(counts[slot]) == 2, "AC1: exactly two Tinker parts for " + slot)
	for slot in STARTERS:
		var starter: Dictionary = accepted["by_id"].get(STARTERS[slot], {})
		_check(not starter.is_empty() and str(starter.get("slot", "")) == slot,
			"AC1: named starter equipped in proper " + slot + " slot")
	_check(bool(accepted["by_id"]["tinker_arms_scrap_bomb"]["ability"]["multi"]) and accepted["by_id"]["tinker_arms_scrap_bomb"]["ability"]["target"] == [1, 2, 3],
		"AC1: Scrap Bomb is enemy-wide through rank 3, never a fourth foe")
	_check(int(accepted["by_id"]["tinker_arms_overload"]["ability"]["mark_damage"]) > 0,
		"AC1: Overload uses native mark_damage rather than Combat Scrap")
	_check(int(accepted["by_id"]["tinker_legs_spare_screws"]["ability"]["self_move"]) == 1,
		"AC1: Spare Screws steps exactly one rank backward")
	# AC1: Casing Ward's single self-buff works from every allied rank 1-4 at every stitch tier,
	# while its numbers, pose and self-only targeting stay exactly as shipped.
	var ward_part: Dictionary = accepted["by_id"]["tinker_torso_casing_ward"]
	_check(str(ward_part["name"]) == "Casing Ward" and str(ward_part["slot"]) == "torso"
		and str(ward_part["owner"]) == "tinker"
		and str(ward_part["text"]) == "Fold metal casing around yourself; Thorns answer each landed blow.",
		"AC1: Casing Ward stays Tinker's named torso part with its authored rules text")
	var all_hero_ranks: Array = [1, 2, 3, 4]
	for tier in [1, 2, 3]:
		var tier_ward := StitchedParts.ability_at_tier(ward_part, tier)
		var ward_launch := int(tier_ward["launch_mask"])
		var ward_target := int(tier_ward["target_mask"])
		_check(tier_ward["launch"] == all_hero_ranks and ward_launch == StitchedParts.rank_mask(all_hero_ranks),
			"AC1: tier %d Casing Ward launches from hero ranks 1-4 with a derived mask" % tier)
		_check(tier_ward["target"] == all_hero_ranks and ward_target == StitchedParts.rank_mask(all_hero_ranks),
			"AC1: tier %d Casing Ward targets hero ranks 1-4 with a derived mask" % tier)
		for rank in all_hero_ranks:
			_check(StitchedParts.ranks_allowed(ward_launch, rank) and StitchedParts.ranks_allowed(ward_target, rank),
				"AC1: tier %d Casing Ward allows rank %d launch and target" % [tier, rank])
		_check(not StitchedParts.ranks_allowed(ward_launch, 0) and not StitchedParts.ranks_allowed(ward_target, 0)
			and not StitchedParts.ranks_allowed(ward_launch, 5) and not StitchedParts.ranks_allowed(ward_target, 5),
			"AC1: tier %d Casing Ward refuses unauthored ranks 0 and 5" % tier)
		_check(str(tier_ward["id"]) == "tinker_casing_ward_move" and str(tier_ward["name"]) == "Casing Ward"
			and str(tier_ward["kind"]) == "buff" and str(tier_ward["target_side"]) == "self"
			and not bool(tier_ward["multi"]) and int(tier_ward["acc"]) == 100
			and tier_ward["dmg"] == [0, 0] and int(tier_ward["crit"]) == 0
			and int(tier_ward["mark_damage"]) == 0 and int(tier_ward["self_move"]) == 0
			and str(tier_ward["move"]) == "guard",
			"AC1: tier %d Casing Ward stays one self-only guard-pose buff with 100 ACC and no damage or move" % tier)
		var tier_ward_stat := StitchedParts.stat_at_tier(ward_part, tier)
		_check(int(tier_ward_stat.get("max_hp", 0)) == [5, 7, 9][tier - 1]
			and int(tier_ward_stat.get("prot", 0)) == [4, 5, 7][tier - 1]
			and int(tier_ward["effects"].get("thorns", 0)) == [2, 3, 4][tier - 1],
			"AC1: tier %d Casing Ward keeps its authored HP/PROT/Thorns ladder" % tier)
	# AC1: only the two named base launches grow to hero rank 4; every other authored launch,
	# every tier and every named ability number stays exactly as shipped.
	var expected_launches := {
		"tinker_head_cog_shot": [2, 3, 4],
		"tinker_arms_scrap_bomb": [3, 4],
		"tinker_torso_casing_ward": [1, 2, 3, 4],
		"tinker_legs_tune_up": [1, 2, 3, 4],
		"tinker_head_spring_clamp": [2, 3],
		"tinker_arms_overload": [2, 3, 4],
		"tinker_torso_gear_brace": [1, 2, 3],
		"tinker_legs_spare_screws": [2, 3],
	}
	for id in expected_launches:
		var expected: Array = expected_launches[id]
		var authored: Dictionary = accepted["by_id"][id]
		_check(authored["ability"]["launch"] == expected and int(authored["ability"]["launch_mask"]) == StitchedParts.rank_mask(expected),
			"AC1: base launch and derived mask are exactly authored for " + id)
		for tier in [1, 2, 3]:
			var tier_ability := StitchedParts.ability_at_tier(authored, tier)
			_check(tier_ability["launch"] == expected and int(tier_ability["launch_mask"]) == StitchedParts.rank_mask(expected),
				"AC1: tier %d keeps the base launch mask of %s" % [tier, id])
	var cog_mask := int(accepted["by_id"]["tinker_head_cog_shot"]["ability"]["launch_mask"])
	_check(StitchedParts.ranks_allowed(cog_mask, 2) and StitchedParts.ranks_allowed(cog_mask, 3) and StitchedParts.ranks_allowed(cog_mask, 4) and not StitchedParts.ranks_allowed(cog_mask, 1),
		"AC1: Cog Shot launches from ranks 2-4, never rank 1")
	var bomb_mask := int(accepted["by_id"]["tinker_arms_scrap_bomb"]["ability"]["launch_mask"])
	_check(StitchedParts.ranks_allowed(bomb_mask, 3) and StitchedParts.ranks_allowed(bomb_mask, 4) and not StitchedParts.ranks_allowed(bomb_mask, 1) and not StitchedParts.ranks_allowed(bomb_mask, 2),
		"AC1: Scrap Bomb launches from ranks 3-4, never ranks 1-2")
	# AC1/AC3: the alternate arms now launch from the hero back rank too; every tier inherits it.
	var overload_part: Dictionary = accepted["by_id"]["tinker_arms_overload"]
	_check(str(overload_part["name"]) == "Overload" and str(overload_part["slot"]) == "arms" and str(overload_part["owner"]) == "tinker"
		and str(overload_part["ability"]["id"]) == "tinker_overload_move" and str(overload_part["ability"]["name"]) == "Overload"
		and str(overload_part["ability"]["kind"]) == "ranged" and not bool(overload_part["ability"]["multi"]),
		"AC1: Overload stays Tinker's single-target ranged arms ability")
	_check(str(overload_part["text"]) == "Discharge a charged tool; a Marked target takes extra damage, with no card or scrap cost.",
		"AC1: Overload keeps its short authored rules text")
	for tier in [1, 2, 3]:
		var tier_overload := StitchedParts.ability_at_tier(overload_part, tier)
		var tier_mask := int(tier_overload["launch_mask"])
		_check(StitchedParts.ranks_allowed(tier_mask, 2) and StitchedParts.ranks_allowed(tier_mask, 3) and StitchedParts.ranks_allowed(tier_mask, 4)
			and not StitchedParts.ranks_allowed(tier_mask, 1) and not StitchedParts.ranks_allowed(tier_mask, 0) and not StitchedParts.ranks_allowed(tier_mask, 5),
			"AC1: tier %d Overload launch mask accepts ranks 2-4 and refuses rank 1/0/5" % tier)
		_check(tier_overload["target"] == [1, 2, 3] and int(tier_overload["target_mask"]) == StitchedParts.rank_mask([1, 2, 3])
			and int(tier_overload["self_move"]) == 0 and str(tier_overload["move"]) == "attack2" and str(tier_overload["target_side"]) == "enemy"
			and not bool(tier_overload["multi"]),
			"AC1: tier %d Overload keeps target ranks 1-3, attack2 pose, self_move 0 and one enemy target" % tier)
		_check(int(tier_overload["mark_damage"]) == [3, 4, 5][tier - 1],
			"AC3: tier %d Overload Mark bonus is %d" % [tier, [3, 4, 5][tier - 1]])
		_check(int(overload_part["stat"].get("dmg", 0)) == 2 and int(StitchedParts.stat_at_tier(overload_part, tier).get("dmg", 0)) == 2,
			"AC3: tier %d Overload arms stat stays damage +2" % tier)
	var expected_shots := {
		"tinker_head_cog_shot": {"acc": [91, 91, 95], "dmg": [[4, 6], [5, 8], [7, 10]], "mark": [2, 3, 3], "multi": false},
		"tinker_arms_scrap_bomb": {"acc": [90, 92, 95], "dmg": [[3, 4], [4, 6], [5, 7]], "mark": [0, 0, 0], "multi": true},
		"tinker_arms_overload": {"acc": [90, 90, 94], "dmg": [[3, 5], [4, 7], [5, 9]], "mark": [0, 0, 0], "multi": false},
	}
	for id in expected_shots:
		var expected_shot: Dictionary = expected_shots[id]
		for tier in [1, 2, 3]:
			var shot := StitchedParts.ability_at_tier(accepted["by_id"][id], tier)
			_check(int(shot["acc"]) == int(expected_shot["acc"][tier - 1])
				and shot["dmg"] == expected_shot["dmg"][tier - 1]
				and int(shot["effects"].get("mark", 0)) == int(expected_shot["mark"][tier - 1])
				and bool(shot["multi"]) == bool(expected_shot["multi"])
				and shot["target"] == [1, 2, 3]
				and int(shot["target_mask"]) == StitchedParts.rank_mask([1, 2, 3])
				and int(shot["self_move"]) == 0
				and str(shot["target_side"]) == "enemy"
				and str(shot["move"]) == "attack2",
				"AC1: tier %d numbers, target ranks 1-3 and attack2 pose stay authored for %s" % [tier, id])
	for id in ALL_IDS:
		var part: Dictionary = accepted["by_id"][id]
		var copied := part.duplicate(true)
		copied["tiers"]["4"] = {"ability": {"acc": 99}}
		_check(not bool(StitchedParts.validate_part(copied).get("ok", false)),
			"AC3: invalid tier key fails closed for " + id)
	var bad_dodge: Dictionary = accepted["by_id"]["tinker_legs_tune_up"].duplicate(true)
	bad_dodge["tiers"]["2"]["ability"]["effects"] = {"dodge": 7}
	_check(not bool(StitchedParts.validate_part(bad_dodge).get("ok", false)),
		"AC3: malformed tier-II Dodge without duration rejects")
	var bad_rank: Dictionary = accepted["by_id"]["tinker_arms_scrap_bomb"].duplicate(true)
	bad_rank["ability"]["target"] = [1, 2, 3, 5]
	_check(not bool(StitchedParts.validate_part(bad_rank).get("ok", false)),
		"AC3: invented fourth foe rank beyond legal ranks rejects")
	for id in [STARTERS["head"], STARTERS["arms"]]:
		for bad_launch in [[2, 3, 4, 5], [2, 3, 4, 4]]:
			var bad_launch_part: Dictionary = accepted["by_id"][id].duplicate(true)
			bad_launch_part["ability"]["launch"] = bad_launch.duplicate()
			_check(not bool(StitchedParts.validate_part(bad_launch_part).get("ok", false)),
				"AC3: malformed launch %s rejects for %s" % [str(bad_launch), id])
	for key in ["cost", "block", "draw", "combat_scrap_gain"]:
		for part in accepted["parts"]:
			_check(not part.has(key) and not part["ability"].has(key) and not part["ability"]["effects"].has(key),
				"AC1: retired card resources absent from " + str(part["id"]) + ": " + key)


func _test_every_tier_in_real_combat() -> void:
	var hit_witness: Dictionary = {}
	for id in ALL_IDS:
		hit_witness[id] = 0
		for tier in [1, 2, 3]:
			var b := _battle(id, tier, 499041 + tier)
			if b == null:
				continue
			_check(_to(b, "tinker"), "AC2: Tinker receives a real scheduled turn for %s tier %d" % [id, tier])
			if b.current_actor_id() != "tinker":
				continue
			var ability: Dictionary = _catalog()["by_id"][id]["ability"]
			var target_rank := 1 if str(ability["target_side"]) != "self" else int(b.get_unit("tinker")["rank"])
			var snapshot := b.state_snapshot()
			var rng := b.rng_state()
			var result := b.use_part(id, target_rank)
			_check(bool(result.get("ok", false)) and str(result.get("part", "")) == id and str(result.get("actor", "")) == "tinker" and str(result.get("ability", "")).begins_with("tinker_"),
				"AC2: actual equipped tier %d %s grants a successful named turn" % [tier, id])
			if not bool(result.get("ok", false)):
				continue
			_check(snapshot != b.state_snapshot() and not result.get("results", []).is_empty(),
				"AC2: authoritative battle snapshot and receipts change on real ability " + id)
			var results: Array = result["results"]
			if id == "tinker_arms_scrap_bomb":
				var seen: Dictionary = {}
				for hit in results:
					seen[str(hit["target"])] = true
					_check(str(hit["target_side"]) == "foe" and int(hit["target_rank"]) <= 3,
						"AC2: Scrap Bomb only hits legal enemy ranks 1-3")
				_check(results.size() == 3 and seen.size() == 3 and seen.has("fray_scavenger") and seen.has("scissor_crab") and seen.has("moth_scribe") and b.get_foes().size() == 3,
					"AC2: Scrap Bomb receipts target all three living foes exactly once")
			elif id == "tinker_legs_spare_screws":
				_check(bool(result.get("self_move", {}).get("ok", false)) and int(b.get_unit("tinker")["rank"]) == 4 and int(b.get_unit("lantern_monk")["rank"]) == 3,
					"AC2: Spare Screws performs real adjacent backward swap")
				_check(int(b.get_unit("tinker")["dodge_buff"].get("amount", 0)) > 0,
					"AC2: Spare Screws grants temporary Dodge, not a card draw")
			elif id == "tinker_legs_tune_up":
				_check(int(b.get_unit("tinker")["dodge_buff"].get("amount", 0)) > 0 and int(b.get_unit("tinker")["dodge_buff"].get("turns", 0)) == 1 and results[0]["statuses"].size() >= 2,
					"AC2: Tune Up heals and applies bounded temporary Dodge in real receipt")
			elif id == "tinker_torso_casing_ward":
				_check(int(b.get_unit("tinker")["statuses"].get("thorns", 0)) > 0 and str(results[0]["target"]) == "tinker",
					"AC2: Casing Ward casts self Thorns, not Block")
			elif id == "tinker_torso_gear_brace":
				_check(str(b.get_unit("tinker")["guard_target"]) == "warden" and int(b.get_unit("tinker")["statuses"].get("guard", 0)) > 0,
					"AC2: Gear Brace sets ally Guard through battle rules")
			if str(ability["target_side"]) == "enemy":
				for hit in results:
					if bool(hit.get("hit", false)):
						hit_witness[id] = int(hit_witness[id]) + 1
						if id in ["tinker_head_cog_shot", "tinker_head_spring_clamp"]:
							_check(not hit.get("statuses", []).is_empty(),
								"AC2: landed %s applies native status in receipt" % id)
			_check(not result.has("cards") and not result.has("scrap") and not result.has("combat_scrap") and rng != b.rng_state() or
				(str(ability["target_side"]) != "enemy" and not result.has("cards") and not result.has("scrap") and not result.has("combat_scrap")),
				"AC2: equipment action has no card or Combat Scrap resource receipt")
	for id in ["tinker_head_cog_shot", "tinker_arms_scrap_bomb", "tinker_head_spring_clamp", "tinker_arms_overload"]:
		_check(int(hit_witness[id]) > 0,
			"AC2: nonvacuous seeded hit/status witness for " + id)


## AC2 witness: a real seeded 4v3 battle where rank-3 Tinker swaps backward with Spare Screws,
## survives to his next scheduled turn and fires the named shot from hero rank 4.
func _back_rank_witness(part_id: String, seed_value: int) -> Dictionary:
	var battle := _battle(ALTERNATES["legs"], 1, seed_value)
	if battle == null or not _to(battle, "tinker"):
		return {}
	if int(battle.get_unit("tinker")["rank"]) != 3:
		return {}
	var swap := battle.use_part(ALTERNATES["legs"], 3)
	if not bool(swap.get("ok", false)) \
		or str(swap.get("actor", "")) != "tinker" \
		or str(swap.get("part", "")) != ALTERNATES["legs"] \
		or str(swap.get("ability", "")) != "tinker_spare_screws_move":
		return {}
	if not bool(swap.get("self_move", {}).get("ok", false)) or int(swap["self_move"].get("to", 0)) != 4:
		return {}
	if int(battle.get_unit("tinker")["rank"]) != 4 or int(battle.get_unit("lantern_monk")["rank"]) != 3:
		return {}
	if battle.current_actor_id() == "tinker":
		return {}
	if not _to(battle, "tinker") or battle.is_over():
		return {}
	if int(battle.get_unit("tinker")["rank"]) != 4:
		return {}
	for foe_id in ["fray_scavenger", "scissor_crab", "moth_scribe"]:
		var foe := battle.get_unit(foe_id)
		if bool(foe.get("dead", true)) or int(foe.get("hp", 0)) <= 0:
			return {}
	if int(battle.get_unit("fray_scavenger")["rank"]) != 1:
		return {}
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var actor_before := battle.current_actor_id()
	# Enemy rank 4 stays outside both shots' target arrays: refused before any spend.
	var refused := battle.use_part(part_id, 4)
	var after_refusal := battle.state_snapshot()
	var actor_after_refusal := battle.current_actor_id()
	var shot := battle.use_part(part_id, 1)
	if not bool(shot.get("ok", false)):
		return {}
	return {
		"battle": battle,
		"swap": swap,
		"refused": refused,
		"shot": shot,
		"before": before,
		"rng": rng,
		"actor_before": actor_before,
		"after_refusal": after_refusal,
		"actor_after_refusal": actor_after_refusal,
	}


func _test_back_rank_shots() -> void:
	var expected := {
		STARTERS["head"]: {"ability": "tinker_cog_shot_move", "results": 1},
		STARTERS["arms"]: {"ability": "tinker_scrap_bomb_move", "results": 3},
	}
	for part_id in expected:
		var wanted: Dictionary = expected[part_id]
		var witness: Dictionary = {}
		for seed_value in range(499400, 499440):
			witness = _back_rank_witness(part_id, seed_value)
			if not witness.is_empty():
				break
		_check(not witness.is_empty(), "AC2: real seeded back-rank witness exists for " + part_id)
		if witness.is_empty():
			continue
		var battle: StitchedRules = witness["battle"]
		var swap: Dictionary = witness["swap"]
		var shot: Dictionary = witness["shot"]
		_check(str(swap.get("actor", "")) == "tinker" and str(swap.get("part", "")) == ALTERNATES["legs"] and str(swap.get("ability", "")) == "tinker_spare_screws_move",
			"AC2: Spare Screws is Tinker's own legs ability action for " + part_id)
		_check(int(battle.get_unit("tinker")["rank"]) == 4 and int(battle.get_unit("lantern_monk")["rank"]) == 3,
			"AC2: Spare Screws swaps rank-3 Tinker behind rank-4 Lantern Monk for " + part_id)
		_check(str(shot.get("action", "")) == "ability" and str(shot.get("actor", "")) == "tinker"
			and str(shot.get("part", "")) == part_id and str(shot.get("ability", "")) == str(wanted["ability"]),
			"AC2: the named shot executes as Tinker's real equipment action for " + part_id)
		_check(str(witness["actor_before"]) == "tinker" and battle.current_actor_id() != "tinker" and int(battle.get_unit("tinker")["rank"]) == 4,
			"AC2: the rank-4 shot consumes Tinker's scheduled turn for " + part_id)
		_check(not bool(witness["refused"].get("ok", false))
			and witness["before"] == witness["after_refusal"]
			and int(witness["rng"]) == int(witness["after_refusal"].get("rng_state", -1))
			and str(witness["actor_after_refusal"]) == "tinker",
			"AC3: enemy rank-4 target refuses without changing snapshot, turn or seeded RNG for " + part_id)
		var results: Array = shot.get("results", [])
		_check(results.size() == int(wanted["results"]),
			"AC2: %s yields %d target receipt(s) from hero rank 4" % [part_id, int(wanted["results"])])
		var seen: Dictionary = {}
		for hit in results:
			seen[str(hit["target"])] = true
			_check(str(hit["target_side"]) == "foe" and int(hit["target_rank"]) >= 1 and int(hit["target_rank"]) <= 3,
				"AC2: %s only receipts living enemy ranks 1-3" % part_id)
		if part_id == STARTERS["head"]:
			_check(results.size() == 1 and str(results[0]["target"]) == "fray_scavenger" and int(results[0]["target_rank"]) == 1,
				"AC2: Cog Shot yields exactly one receipt for the living rank-1 foe")
		else:
			_check(results.size() == 3 and seen.size() == 3 and seen.has("fray_scavenger") and seen.has("scissor_crab") and seen.has("moth_scribe"),
				"AC2: Scrap Bomb receipts each of the three living foes in ranks 1-3 exactly once")
			_check(not StitchedParts.ranks_allowed(int(_catalog()["by_id"][part_id]["ability"]["target_mask"]), 4),
				"AC2: Scrap Bomb still has no enemy rank-4 target")


## Builds the shipped S2 preview with Tinker wearing the Casing Ward torso and Spare Screws legs at
## the requested stitch tier. The preview fixture file itself is never edited; only Tinker's four
## prototype equipped IDs change, and only the torso may be flagged torn for the fail-closed check.
func _rank_four_ward_battle(tier: int, seed_value: int, torn_torso: bool = false) -> StitchedRules:
	var config := _config(ALTERNATES["legs"], tier, seed_value)
	if config.is_empty():
		return null
	if torn_torso:
		config["heroes"][2]["parts"]["torso"]["torn"] = true
	var result := StitchedRules.create(config)
	if not bool(result.get("ok", false)):
		return null
	return result["battle"] as StitchedRules


## AC2 witness: rank-3 Tinker, wearing Casing Ward and Spare Screws, swaps backward with Spare
## Screws on her genuine turn, survives to her next scheduled turn at hero rank 4 and raises
## Casing Ward on her own rank 4. Refusals (an ally at rank 3, ranks 0/5, the unequipped Tune Up
## legs) are recorded just before the successful cast so the test can prove they spend nothing.
func _rank_four_ward_witness(tier: int, seed_value: int) -> Dictionary:
	var battle := _rank_four_ward_battle(tier, seed_value)
	if battle == null or not _to(battle, "tinker"):
		return {}
	if int(battle.get_unit("tinker")["rank"]) != 3:
		return {}
	var swap := battle.use_part(ALTERNATES["legs"], 3)
	if not bool(swap.get("ok", false)) \
		or str(swap.get("actor", "")) != "tinker" \
		or str(swap.get("part", "")) != ALTERNATES["legs"] \
		or str(swap.get("ability", "")) != "tinker_spare_screws_move":
		return {}
	if not bool(swap.get("self_move", {}).get("ok", false)) or int(swap["self_move"].get("to", 0)) != 4:
		return {}
	if int(battle.get_unit("tinker")["rank"]) != 4 or int(battle.get_unit("lantern_monk")["rank"]) != 3:
		return {}
	if battle.current_actor_id() == "tinker":
		return {}
	if not _to(battle, "tinker") or battle.is_over():
		return {}
	if int(battle.get_unit("tinker")["rank"]) != 4:
		return {}
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var actor_before := battle.current_actor_id()
	var refusals: Array = []
	for target_rank in [3, 0, 5]:
		refusals.append(battle.use_part(STARTERS["torso"], target_rank))
	refusals.append(battle.use_part(STARTERS["legs"], 4))
	var after_refusals := battle.state_snapshot()
	var actor_after_refusals := battle.current_actor_id()
	var cast := battle.use_part(STARTERS["torso"], 4)
	if not bool(cast.get("ok", false)):
		return {}
	return {
		"battle": battle,
		"swap": swap,
		"before": before,
		"rng": rng,
		"actor_before": actor_before,
		"refusals": refusals,
		"after_refusals": after_refusals,
		"actor_after_refusals": actor_after_refusals,
		"cast": cast,
		"after": battle.state_snapshot(),
		"rng_after": battle.rng_state(),
	}


## AC3 witness: the same real rank-4 setup but with the worn Casing Ward torso torn; the cast
## must refuse before spending the turn or drawing seeded RNG.
func _rank_four_torn_ward_witness(tier: int, seed_value: int) -> Dictionary:
	var battle := _rank_four_ward_battle(tier, seed_value, true)
	if battle == null or not _to(battle, "tinker"):
		return {}
	if int(battle.get_unit("tinker")["rank"]) != 3:
		return {}
	var swap := battle.use_part(ALTERNATES["legs"], 3)
	if not bool(swap.get("ok", false)) or int(battle.get_unit("tinker")["rank"]) != 4:
		return {}
	if not _to(battle, "tinker") or battle.is_over():
		return {}
	if int(battle.get_unit("tinker")["rank"]) != 4:
		return {}
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var refusal := battle.use_part(STARTERS["torso"], 4)
	return {
		"battle": battle,
		"refusal": refusal,
		"before": before,
		"rng": rng,
		"after": battle.state_snapshot(),
		"actor": battle.current_actor_id(),
	}


## AC2/AC3: all three stitch tiers raise Casing Ward on Tinker's own rank 4 through real seeded
## Stitched combat, spend exactly one genuine turn, apply 2/3/4 Thorns to the actual Tinker, replay
## identically at the same seed, and refuse an ally/rank 0/rank 5/unequipped/torn call with no spend.
func _test_casing_ward_rank_four() -> void:
	for tier in [1, 2, 3]:
		var witness: Dictionary = {}
		var witness_seed := 0
		for seed_value in range(499600, 499660):
			witness = _rank_four_ward_witness(tier, seed_value)
			if not witness.is_empty():
				witness_seed = seed_value
				break
		_check(not witness.is_empty(), "AC2: real seeded rank-4 Casing Ward witness exists at tier %d" % tier)
		if witness.is_empty():
			continue
		var battle: StitchedRules = witness["battle"]
		var swap: Dictionary = witness["swap"]
		var cast: Dictionary = witness["cast"]
		_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 3,
			"AC2: tier %d witness keeps the shipped four-hero/three-foe preview" % tier)
		_check(str(swap.get("actor", "")) == "tinker" and str(swap.get("part", "")) == ALTERNATES["legs"]
			and str(swap.get("ability", "")) == "tinker_spare_screws_move"
			and int(swap["self_move"].get("from", 0)) == 3 and int(swap["self_move"].get("to", 0)) == 4
			and str(swap["self_move"].get("swapped", "")) == "lantern_monk",
			"AC2: tier %d Spare Screws really swaps rank-3 Tinker behind the rank-4 Lantern Monk" % tier)
		_check(int(battle.get_unit("tinker")["rank"]) == 4 and int(battle.get_unit("lantern_monk")["rank"]) == 3,
			"AC2: tier %d Tinker stays in rank 4 with the Lantern Monk in rank 3" % tier)
		_check(str(witness["actor_before"]) == "tinker" and battle.current_actor_id() != "tinker",
			"AC2: tier %d Casing Ward succeeds on a genuine Tinker turn and spends exactly one" % tier)
		_check(str(cast.get("action", "")) == "ability" and str(cast.get("actor", "")) == "tinker"
			and str(cast.get("part", "")) == STARTERS["torso"]
			and str(cast.get("ability", "")) == "tinker_casing_ward_move" and not cast.has("self_move"),
			"AC2: tier %d Casing Ward executes as Tinker's own equipped torso action" % tier)
		var results: Array = cast.get("results", [])
		_check(results.size() == 1 and str(cast.get("target", "")) == "tinker"
			and str(results[0].get("target", "")) == "tinker"
			and str(results[0].get("target_side", "")) == "hero"
			and int(results[0].get("target_rank", 0)) == 4 and bool(results[0].get("hit", false)),
			"AC2: tier %d Casing Ward yields exactly one self receipt at Tinker's own rank 4" % tier)
		_check(int(battle.get_unit("tinker")["statuses"].get("thorns", 0)) == [2, 3, 4][tier - 1],
			"AC2: tier %d Casing Ward leaves the actual Tinker with Thorns %d" % [tier, [2, 3, 4][tier - 1]])
		var refusals: Array = witness["refusals"]
		var errors: Array[String] = []
		var all_refused := refusals.size() == 4
		for refusal in refusals:
			all_refused = all_refused and not bool(refusal.get("ok", false))
			errors.append(str(refusal.get("error", "")))
		_check(all_refused and errors[0].contains("rank 3") and errors[1].contains("rank 0")
			and errors[2].contains("rank 5") and errors[3].contains("not equipped"),
			"AC3: tier %d Casing Ward refuses an ally at rank 3, ranks 0/5 and the unequipped legs" % tier)
		_check(witness["before"] == witness["after_refusals"]
			and int(witness["rng"]) == int(witness["after_refusals"].get("rng_state", -1))
			and str(witness["actor_after_refusals"]) == "tinker",
			"AC3: tier %d refused casts change no state, spend no turn and draw no seeded RNG" % tier)
		_check(not (witness["before"] == witness["after"])
			and int(witness["after"].get("rng_state", -1)) == int(witness["rng_after"]),
			"AC2: tier %d successful self-buff changes authoritative battle state" % tier)
		var replay := _rank_four_ward_witness(tier, witness_seed)
		_check(not replay.is_empty(), "AC3: tier %d rank-4 Casing Ward witness replays at seed %d" % [tier, witness_seed])
		if not replay.is_empty():
			_check(replay["swap"] == swap and replay["cast"] == cast
				and replay["before"] == witness["before"]
				and replay["after_refusals"] == witness["after_refusals"]
				and replay["after"] == witness["after"]
				and int(replay["rng_after"]) == int(witness["rng_after"]),
				"AC3: tier %d equal-seed replay reproduces the swap, cast receipt, all state and exact RNG" % tier)
		var torn: Dictionary = {}
		for seed_value in range(499600, 499660):
			torn = _rank_four_torn_ward_witness(tier, seed_value)
			if not torn.is_empty():
				break
		_check(not torn.is_empty(), "AC3: tier %d torn Casing Ward witness reaches real rank 4" % tier)
		if not torn.is_empty():
			var torn_refusal: Dictionary = torn["refusal"]
			_check(not bool(torn_refusal.get("ok", false)) and str(torn_refusal.get("error", "")).contains("torn")
				and torn["before"] == torn["after"] and int(torn["rng"]) == int(torn["after"].get("rng_state", -1))
				and str(torn["actor"]) == "tinker",
				"AC3: tier %d torn Casing Ward refuses from rank 4 without state, turn or RNG change" % tier)


## Builds the shipped S2 preview battle with Tinker's alternate Overload arms and Spare Screws
## legs swapped in memory; the preview fixture file itself is never edited.
func _overload_battle(tier: int = 1, seed_value: int = 499041, torn_arms: bool = false) -> StitchedRules:
	var config := _config("", tier, seed_value)
	if config.is_empty():
		return null
	var arms: Dictionary = {"id": ALTERNATES["arms"], "tier": tier}
	if torn_arms:
		arms["torn"] = true
	config["heroes"][2]["parts"]["arms"] = arms
	config["heroes"][2]["parts"]["legs"] = {"id": ALTERNATES["legs"], "tier": tier}
	var result := StitchedRules.create(config)
	if not bool(result.get("ok", false)):
		return null
	return result["battle"] as StitchedRules


## AC2 witness: rank-3 Tinker swaps backward with Spare Screws, then on her next genuine turn
## fires Overload from hero rank 4 at the living rank-1 foe. Refusals are recorded around the
## successful cast so the test can prove they neither spend the turn nor advance the RNG.
func _overload_back_rank_witness(seed_value: int) -> Dictionary:
	var battle := _overload_battle(1, seed_value)
	if battle == null or not _to(battle, "tinker"):
		return {}
	if int(battle.get_unit("tinker")["rank"]) != 3:
		return {}
	# A self-side legs ability aimed at an enemy rank is refused before any spend.
	var turn_start := battle.state_snapshot()
	var turn_rng := battle.rng_state()
	var wrong_side := battle.use_part(ALTERNATES["legs"], 1)
	var after_wrong_side := battle.state_snapshot()
	var swap := battle.use_part(ALTERNATES["legs"], 3)
	if not bool(swap.get("ok", false)) \
		or str(swap.get("actor", "")) != "tinker" \
		or str(swap.get("part", "")) != ALTERNATES["legs"] \
		or str(swap.get("ability", "")) != "tinker_spare_screws_move":
		return {}
	if not bool(swap.get("self_move", {}).get("ok", false)) or int(swap["self_move"].get("to", 0)) != 4:
		return {}
	if int(battle.get_unit("tinker")["rank"]) != 4 or int(battle.get_unit("lantern_monk")["rank"]) != 3:
		return {}
	if battle.current_actor_id() == "tinker":
		return {}
	if not _to(battle, "tinker") or battle.is_over():
		return {}
	if int(battle.get_unit("tinker")["rank"]) != 4:
		return {}
	for foe_id in ["fray_scavenger", "scissor_crab", "moth_scribe"]:
		var foe := battle.get_unit(foe_id)
		if bool(foe.get("dead", true)) or int(foe.get("hp", 0)) <= 0:
			return {}
	if int(battle.get_unit("fray_scavenger")["rank"]) != 1:
		return {}
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var actor_before := battle.current_actor_id()
	var foe_before := battle.get_unit("fray_scavenger")
	# Enemy rank 4, plus ranks 0 and 5, stay outside Overload's target [1,2,3]; the starter
	# Scrap Bomb arms are no longer equipped. Every request refuses before any spend.
	var refusals: Array = []
	for target_rank in [4, 0, 5]:
		refusals.append(battle.use_part(ALTERNATES["arms"], target_rank))
	refusals.append(battle.use_part(STARTERS["arms"], 1))
	var after_refusals := battle.state_snapshot()
	var actor_after_refusals := battle.current_actor_id()
	var shot := battle.use_part(ALTERNATES["arms"], 1)
	if not bool(shot.get("ok", false)) or shot.get("results", []).is_empty():
		return {}
	if not bool(shot["results"][0].get("hit", false)) or int(shot["results"][0].get("damage", 0)) <= 0:
		return {}
	if battle.current_actor_id() == "tinker":
		return {}
	return {
		"battle": battle,
		"wrong_side": wrong_side,
		"turn_start": turn_start,
		"turn_rng": turn_rng,
		"after_wrong_side": after_wrong_side,
		"swap": swap,
		"before": before,
		"rng": rng,
		"actor_before": actor_before,
		"foe_before": foe_before,
		"refusals": refusals,
		"after_refusals": after_refusals,
		"actor_after_refusals": actor_after_refusals,
		"shot": shot,
		"after": battle.state_snapshot(),
		"rng_after": battle.rng_state(),
	}


## AC2/AC3: the real preview, both alternate Tinker parts, a landed rank-4 Overload, its
## fail-closed peers (wrong side, target ranks 4/0/5, unequipped and torn part, stale turn)
## and a rank-1 launch refusal that may never spend anything.
func _test_overload_back_rank() -> void:
	var witness: Dictionary = {}
	var witness_seed := 0
	for seed_value in range(499500, 499580):
		witness = _overload_back_rank_witness(seed_value)
		if not witness.is_empty():
			witness_seed = seed_value
			break
	_check(not witness.is_empty(), "AC2: real seeded Overload rank-4 cast witness exists in the shipped S2 preview")
	if witness.is_empty():
		return
	var battle: StitchedRules = witness["battle"]
	var swap: Dictionary = witness["swap"]
	var shot: Dictionary = witness["shot"]
	var wrong_side: Dictionary = witness["wrong_side"]
	_check(not bool(wrong_side.get("ok", false)) and str(wrong_side.get("error", "")).contains("rank 1")
		and witness["turn_start"] == witness["after_wrong_side"]
		and int(witness["turn_rng"]) == int(witness["after_wrong_side"].get("rng_state", -1)),
		"AC3: wrong-side Spare Screws target refuses without changing state, turn or seeded RNG")
	_check(str(swap.get("actor", "")) == "tinker" and str(swap.get("part", "")) == ALTERNATES["legs"]
		and str(swap.get("ability", "")) == "tinker_spare_screws_move",
		"AC2: Spare Screws is Tinker's own equipped legs ability action")
	_check(int(swap["self_move"].get("from", 0)) == 3 and int(swap["self_move"].get("to", 0)) == 4
		and str(swap["self_move"].get("swapped", "")) == "lantern_monk",
		"AC2: her rank-3 turn swaps Tinker behind the rank-4 Lantern Monk")
	_check(int(battle.get_unit("tinker")["rank"]) == 4 and int(battle.get_unit("lantern_monk")["rank"]) == 3,
		"AC2: Tinker stays in rank 4 and the Lantern Monk in rank 3 after the cast")
	_check(str(shot.get("action", "")) == "ability" and str(shot.get("actor", "")) == "tinker"
		and str(shot.get("part", "")) == ALTERNATES["arms"] and str(shot.get("ability", "")) == "tinker_overload_move"
		and not shot.has("self_move"),
		"AC2: Overload executes as Tinker's one named equipment action from rank 4")
	_check(str(witness["actor_before"]) == "tinker" and battle.current_actor_id() != "tinker",
		"AC2: the rank-4 Overload spends exactly one scheduled Tinker turn")
	var refusals: Array = witness["refusals"]
	var all_refused := refusals.size() == 4
	var errors: Array[String] = []
	for refusal in refusals:
		all_refused = all_refused and not bool(refusal.get("ok", false))
		errors.append(str(refusal.get("error", "")))
	_check(all_refused and errors[0].contains("rank 4") and errors[1].contains("rank 0")
		and errors[2].contains("rank 5") and errors[3].contains("not equipped"),
		"AC3: target ranks 4/0/5 and the unequipped part each refuse for their own reason")
	_check(witness["before"] == witness["after_refusals"] and int(witness["rng"]) == int(witness["after_refusals"].get("rng_state", -1))
		and str(witness["actor_after_refusals"]) == "tinker",
		"AC3: refused launches change no battle state, spend no turn and draw no seeded RNG")
	var results: Array = shot.get("results", [])
	var foe_before: Dictionary = witness["foe_before"]
	_check(results.size() == 1 and str(results[0].get("target", "")) == "fray_scavenger"
		and str(results[0].get("target_side", "")) == "foe" and int(results[0].get("target_rank", 0)) == 1,
		"AC2: Overload yields exactly one receipt for the living rank-1 foe")
	_check(bool(results[0].get("hit", false)) and int(results[0].get("damage", 0)) > 0,
		"AC2: the seeded rank-4 Overload really lands for damage")
	var dealt := int(results[0].get("damage", 0))
	var foe_after := battle.get_unit("fray_scavenger")
	_check(int(foe_after.get("hp", -1)) == int(foe_before.get("hp", 0)) - dealt
		and int(results[0].get("target_hp", -1)) == int(foe_after.get("hp", -2)),
		"AC2: actual foe HP drops by the receipted damage")
	_check(int(witness["rng_after"]) != int(witness["rng"]), "AC2: the landed cast consumed seeded RNG draws")
	var stale := battle.use_part(ALTERNATES["arms"], 1)
	_check(not bool(stale.get("ok", false)) and witness["after"] == battle.state_snapshot()
		and int(witness["rng_after"]) == battle.rng_state() and battle.current_actor_id() != "tinker",
		"AC3: stale Overload after the spent rank-4 turn refuses without state or RNG change")
	var replay := _overload_back_rank_witness(witness_seed)
	_check(not replay.is_empty(), "AC3: the rank-4 Overload witness replays at seed %d" % witness_seed)
	if not replay.is_empty():
		_check(replay["swap"] == swap and replay["shot"] == shot and replay["before"] == witness["before"]
			and replay["after_refusals"] == witness["after_refusals"] and replay["after"] == witness["after"]
			and int(replay["rng_after"]) == int(witness["rng_after"]),
			"AC3: equal-seed replay reproduces the swap, cast receipts, all state and exact RNG")
	var torn := _overload_battle(1, witness_seed, true)
	_check(torn != null, "AC3: real torn Overload arms can enter the seeded preview battle")
	if torn != null:
		var torn_ready := _to(torn, "tinker")
		_check(torn_ready and int(torn.get_unit("tinker")["rank"]) == 3,
			"AC3: torn-arms witness reaches Tinker's real rank-3 turn")
		var torn_swap := torn.use_part(ALTERNATES["legs"], 3) if torn_ready else {}
		var torn_at_rank_4 := bool(torn_swap.get("ok", false)) and int(torn.get_unit("tinker")["rank"]) == 4 and _to(torn, "tinker")
		_check(torn_at_rank_4, "AC3: torn-arms witness still reaches rank 4 on her next turn")
		if torn_at_rank_4:
			var torn_before := torn.state_snapshot()
			var torn_rng := torn.rng_state()
			var torn_shot := torn.use_part(ALTERNATES["arms"], 1)
			_check(not bool(torn_shot.get("ok", false)) and str(torn_shot.get("error", "")).contains("torn")
				and torn_before == torn.state_snapshot() and torn_rng == torn.rng_state(),
				"AC3: torn Overload refuses without spending the turn or advancing seeded RNG")
	var front := _overload_battle(1, witness_seed)
	_check(front != null, "AC3: rank-1 launch witness builds from the seeded preview")
	if front != null:
		var front_ready := _to(front, "tinker")
		var first_step := front.move(-1)
		var second_ready := bool(first_step.get("ok", false)) and _to(front, "tinker")
		var second_step := front.move(-1) if second_ready else {}
		var at_front := bool(second_step.get("ok", false)) and int(front.get_unit("tinker")["rank"]) == 1 and _to(front, "tinker")
		_check(front_ready and second_ready and bool(second_step.get("ok", false)) and int(front.get_unit("tinker")["rank"]) == 1,
			"AC3: genuine adjacent Tinker Moves bring her to forbidden launch rank 1")
		if at_front:
			var front_before := front.state_snapshot()
			var front_rng := front.rng_state()
			var front_shot := front.use_part(ALTERNATES["arms"], 1)
			_check(not bool(front_shot.get("ok", false)) and str(front_shot.get("error", "")).contains("rank 1")
				and front_before == front.state_snapshot() and front_rng == front.rng_state(),
				"AC3: Overload refuses a genuine rank-1 launch without state, turn or RNG spending")


func _test_heal_and_guard() -> void:
	var healed := false
	var guarded := false
	var thorned := false
	for seed_value in range(499100, 499120):
		if not healed:
			var b := _battle("tinker_legs_tune_up", 2, seed_value)
			if b != null and _to(b, "moth_scribe"):
				var before_hp := int(b.get_unit("tinker")["hp"])
				var strike := b.use_foe_ability("ink_flick", 3)
				if bool(strike.get("ok", false)) and not strike.get("results", []).is_empty() and bool(strike["results"][0]["hit"]):
					var wounded := int(b.get_unit("tinker")["hp"])
					if wounded < before_hp and _to(b, "tinker"):
						var mend := b.use_part(STARTERS["legs"], 3)
						var restored := int(b.get_unit("tinker")["hp"])
						healed = bool(mend.get("ok", false)) and restored > wounded and restored == mini(int(b.get_unit("tinker")["max_hp"]), wounded + 4) and int(b.get_unit("tinker")["dodge_buff"].get("amount", 0)) == 7 and int(StitchedRules.effective_dodge(b.get_unit("tinker"))) > int(b.get_unit("tinker")["dodge"]) and mend.get("results", []).size() == 1
		if not guarded:
			var g := _battle("tinker_torso_gear_brace", 1, seed_value)
			if g != null and _to(g, "tinker"):
				var brace := g.use_part(ALTERNATES["torso"], 1)
				if bool(brace.get("ok", false)) and _to(g, "fray_scavenger"):
					var attack := g.use_foe_ability("sack_swing", 1)
					guarded = bool(attack.get("ok", false)) and not attack.get("results", []).is_empty() and str(attack["results"][0].get("guarded_by", "")) == "tinker"
		if not thorned:
			var t := _battle("tinker_torso_casing_ward", 1, seed_value)
			if t != null and _to(t, "tinker"):
				var casing := t.use_part(STARTERS["torso"], 3)
				if bool(casing.get("ok", false)) and _to(t, "moth_scribe"):
					var attacked := t.use_foe_ability("ink_flick", 3)
					thorned = bool(attacked.get("ok", false)) and not attacked.get("results", []).is_empty() and bool(attacked["results"][0].get("hit", false)) and int(attacked["results"][0].get("thorns", 0)) == 2
		if healed and guarded and thorned:
			break
	_check(healed, "AC2: genuine foe wound then Tinker Tune Up restores HP and grants temporary Dodge")
	_check(guarded, "AC2: live foe attack on protected Warden is intercepted by Tinker's Gear Brace")
	_check(thorned, "AC2: live foe hit on Tinker's Casing Ward triggers Thorns retaliation")


func _test_mark_overload() -> void:
	var witness := false
	for seed_value in range(499200, 499232):
		var marked := _battle(ALTERNATES["arms"], 1, seed_value)
		var unmarked := _battle(ALTERNATES["arms"], 1, seed_value)
		if marked == null or unmarked == null or not _to(marked, "tinker") or not _to(unmarked, "tinker"):
			continue
		var first := marked.use_part(STARTERS["head"], 1)
		var twin := unmarked.use_part(STARTERS["head"], 1)
		if first != twin or not bool(first.get("ok", false)) or first.get("results", []).is_empty():
			continue
		if not bool(first["results"][0]["hit"]):
			continue
		# Controlled counterfactual: both real battles performed the same successful Mark
		# action and have identical RNG, but one removes only the applied Mark before Overload.
		unmarked._units["fray_scavenger"]["statuses"].erase("mark")
		if not _to(marked, "tinker") or not _to(unmarked, "tinker"):
			continue
		if int(marked.get_unit("fray_scavenger")["statuses"].get("mark", 0)) == 0:
			continue
		var rng_before := marked.rng_state()
		if rng_before != unmarked.rng_state():
			continue
		var charged := marked.use_part(ALTERNATES["arms"], 1)
		var plain := unmarked.use_part(ALTERNATES["arms"], 1)
		if bool(charged.get("ok", false)) and bool(plain.get("ok", false)) and not charged.get("results", []).is_empty() and not plain.get("results", []).is_empty() and bool(charged["results"][0]["hit"]) and bool(plain["results"][0]["hit"]):
			witness = int(charged["results"][0]["damage"]) > int(plain["results"][0]["damage"]) and marked.rng_state() == unmarked.rng_state()
			if witness:
				break
	_check(witness, "AC2: real Cog Shot Mark makes follow-up Overload deal extra damage with equal RNG")


func _test_invalid_actions_and_equipment() -> void:
	var bad := _config()
	if bad.is_empty():
		return
	bad["heroes"][2]["parts"]["arms"] = {"id": STARTERS["head"], "tier": 1}
	_check(not bool(StitchedRules.create(bad).get("ok", false)),
		"AC3: Tinker head cannot be equipped in arms slot")
	bad = _config()
	bad["heroes"][2]["parts"]["head"] = {"id": STARTERS["head"], "tier": 4}
	_check(not bool(StitchedRules.create(bad).get("ok", false)),
		"AC3: tier IV equipment is rejected at creation")
	bad = _config()
	bad["heroes"][2]["parts"]["head"] = {"id": "tinker_head_missing", "tier": 1}
	_check(not bool(StitchedRules.create(bad).get("ok", false)),
		"AC3: unknown equipment ID rejects at setup")
	bad = _config()
	bad["heroes"][2]["parts"]["arms"] = {"id": STARTERS["arms"], "tier": 1, "torn": true}
	var torn_result := StitchedRules.create(bad)
	_check(bool(torn_result.get("ok", false)), "AC3: real torn equipment can enter the battle")
	if bool(torn_result.get("ok", false)):
		var torn: StitchedRules = torn_result["battle"]
		var torn_ready := _to(torn, "tinker")
		_check(torn_ready, "AC3: torn Tinker genuinely receives a scheduled turn")
		if torn_ready:
			var before := torn.state_snapshot()
			var rng := torn.rng_state()
			var refused := torn.use_part(STARTERS["arms"], 1)
			_check(not bool(refused.get("ok", false)) and before == torn.state_snapshot() and rng == torn.rng_state(),
				"AC3: torn equipped ability refuses before state and RNG spending")
	var b := _battle()
	if b == null:
		return
	var ready := _to(b, "tinker")
	_check(ready, "AC3: invalid-action witness reaches a real Tinker turn")
	if not ready:
		return
	for request in [[STARTERS["arms"], 4], [STARTERS["legs"], 2], ["unknown_tinker_part", 1]]:
		var before := b.state_snapshot()
		var rng := b.rng_state()
		var refusal := b.use_part(str(request[0]), int(request[1]))
		_check(not bool(refusal.get("ok", false)) and before == b.state_snapshot() and rng == b.rng_state(),
			"AC3: wrong foe rank/side, wrong self target or unknown part refuses without spend: " + str(request))
	var played := b.use_part(STARTERS["head"], 1)
	_check(bool(played.get("ok", false)), "AC3: Tinker first makes a real legal ability action")
	if bool(played.get("ok", false)) and b.current_actor_id() != "tinker":
		var before := b.state_snapshot()
		var rng := b.rng_state()
		var stale := b.use_part(STARTERS["arms"], 1)
		_check(not bool(stale.get("ok", false)) and before == b.state_snapshot() and rng == b.rng_state(), "AC3: stale action after spending turn is fail-closed")
	var p := _battle(ALTERNATES["head"])
	if p != null:
		var walking_ready := _to(p, "tinker")
		_check(walking_ready, "AC3: rank-gate witness reaches a real Tinker turn")
		if not walking_ready:
			return
		var walked := p.move(1)
		_check(bool(walked.get("ok", false)) and int(p.get_unit("tinker")["rank"]) == 4,
			"AC3: genuine adjacent Tinker Move to forbidden launch rank 4")
		if bool(walked.get("ok", false)) and _to(p, "tinker"):
			var before := p.state_snapshot()
			var rng := p.rng_state()
			var wrong_launch := p.use_part(ALTERNATES["head"], 1)
			_check(not bool(wrong_launch.get("ok", false)) and before == p.state_snapshot() and rng == p.rng_state(), "AC3: Spring Clamp rank-4 launch refuses without spend")


func _trace(seed_value: int) -> Dictionary:
	var b := _battle("", 2, seed_value)
	if b == null:
		return {}
	var receipts: Array = []
	for action in [[STARTERS["head"], 1], [STARTERS["arms"], 2], [STARTERS["torso"], 3], [STARTERS["legs"], 3]]:
		if not _to(b, "tinker"):
			break
		receipts.append(b.use_part(str(action[0]), int(action[1])))
	return {"receipts": receipts, "snapshot": b.state_snapshot(), "rng": b.rng_state()}


func _test_replay() -> void:
	var first := _trace(499919)
	var second := _trace(499919)
	_check(not first.is_empty() and first == second and first.get("receipts", []).size() == 4,
		"AC3: equal-seed four-ability trace replays receipts, all state and exact RNG")
	for receipt in first.get("receipts", []):
		_check(bool(receipt.get("ok", false)), "AC3: replay trace's every action executes")
