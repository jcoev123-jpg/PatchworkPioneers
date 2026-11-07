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
	_test_spring_clamp_catalog()
	_test_spring_clamp_mark_setup()
	_test_spring_clamp_next_foe_attack()
	_test_spring_clamp_overload_payoff()
	_test_spring_clamp_refusals()
	_test_every_tier_in_real_combat()
	_test_scrap_bomb_exposed()
	_test_back_rank_shots()
	_test_cog_shot_rear_foe()
	_test_casing_ward_rank_four()
	_test_overload_back_rank()
	_test_heal_and_guard()
	_test_mark_overload()
	_test_gear_brace_catalog()
	_test_gear_brace_rank_four()
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
	# AC1: only the two named base launches grow to hero rank 4, and Gear Brace's tier-III
	# override is the one tier that also reaches rank 4; every other authored launch, every tier
	# and every named ability number stays exactly as shipped.
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
	var expected_targets := {
		"tinker_head_cog_shot": [1, 2, 3, 4],
		"tinker_arms_scrap_bomb": [1, 2, 3],
		"tinker_torso_casing_ward": [1, 2, 3, 4],
		"tinker_legs_tune_up": [1, 2, 3, 4],
		"tinker_head_spring_clamp": [1, 2, 3],
		"tinker_arms_overload": [1, 2, 3, 4],
		"tinker_torso_gear_brace": [1, 2, 3, 4],
		"tinker_legs_spare_screws": [2, 3],
	}
	for id in expected_launches:
		var expected: Array = expected_launches[id]
		var authored: Dictionary = accepted["by_id"][id]
		_check(authored["ability"]["launch"] == expected and int(authored["ability"]["launch_mask"]) == StitchedParts.rank_mask(expected),
			"AC1: base launch and derived mask are exactly authored for " + id)
		for tier in [1, 2, 3]:
			var tier_ability := StitchedParts.ability_at_tier(authored, tier)
			# Local exception, not a global rule: Gear Brace alone gains hero rank 4 at tier III.
			var tier_launch: Array = expected
			var tier_note := "keeps the base launch mask of "
			if id == "tinker_torso_gear_brace" and tier == 3:
				tier_launch = [1, 2, 3, 4]
				tier_note = "reaches hero rank 4 instead of the base launch mask of "
			_check(tier_ability["launch"] == tier_launch and int(tier_ability["launch_mask"]) == StitchedParts.rank_mask(tier_launch),
				"AC1: tier %d %s%s" % [tier, tier_note, id])
	for id in expected_targets:
		var expected_target: Array = expected_targets[id]
		var authored_target: Dictionary = accepted["by_id"][id]
		_check(authored_target["ability"]["target"] == expected_target
			and int(authored_target["ability"]["target_mask"]) == StitchedParts.rank_mask(expected_target),
			"AC1: base target reach and derived mask are exactly authored for " + id)
		for tier in [1, 2, 3]:
			var tier_target := StitchedParts.ability_at_tier(authored_target, tier)
			_check(tier_target["target"] == expected_target and int(tier_target["target_mask"]) == StitchedParts.rank_mask(expected_target),
				"AC1: tier %d keeps the base target reach of %s" % [tier, id])
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
		_check(tier_overload["target"] == [1, 2, 3, 4] and int(tier_overload["target_mask"]) == StitchedParts.ALL_RANKS_MASK
			and int(tier_overload["self_move"]) == 0 and str(tier_overload["move"]) == "attack2" and str(tier_overload["target_side"]) == "enemy"
			and not bool(tier_overload["multi"]),
			"AC1: tier %d Overload keeps target ranks 1-4, attack2 pose, self_move 0 and one enemy target" % tier)
		_check(int(tier_overload["mark_damage"]) == [3, 4, 5][tier - 1],
			"AC3: tier %d Overload Mark bonus is %d" % [tier, [3, 4, 5][tier - 1]])
		_check(int(overload_part["stat"].get("dmg", 0)) == 2 and int(StitchedParts.stat_at_tier(overload_part, tier).get("dmg", 0)) == 2,
			"AC3: tier %d Overload arms stat stays damage +2" % tier)
	# AC1/AC4: Cog Shot is Tinker's starter head, and its one authored change is enemy target
	# rank 4. Every other field stays exactly as shipped and every tier inherits the new range.
	var cog_part: Dictionary = accepted["by_id"]["tinker_head_cog_shot"]
	_check(str(cog_part["name"]) == "Cog Shot" and str(cog_part["slot"]) == "head"
		and str(cog_part["owner"]) == "tinker" and cog_part["stat"] == {"acc": 4}
		and str(cog_part["text"]) == "Fire a salvaged cog across the enemy line and mark its seams.",
		"AC1: Cog Shot stays Tinker's starter head with its authored ACC +4 stat and rules text")
	var all_foe_ranks: Array = [1, 2, 3, 4]
	var cog_launch: Array = [2, 3, 4]
	_check(cog_part["ability"]["id"] == "tinker_cog_shot_move" and str(cog_part["ability"]["name"]) == "Cog Shot"
		and str(cog_part["ability"]["kind"]) == "ranged"
		and cog_part["ability"]["launch"] == cog_launch and cog_part["ability"]["target"] == all_foe_ranks
		and int(cog_part["ability"]["launch_mask"]) == StitchedParts.rank_mask(cog_launch)
		and int(cog_part["ability"]["target_mask"]) == StitchedParts.ALL_RANKS_MASK
		and str(cog_part["ability"]["target_side"]) == "enemy" and not bool(cog_part["ability"]["multi"])
		and int(cog_part["ability"]["self_move"]) == 0 and str(cog_part["ability"]["move"]) == "attack2",
		"AC1: base Cog Shot keeps ranged single-target attack2 with launch 2-4 and all foe ranks")
	for tier in [1, 2, 3]:
		var tier_cog := StitchedParts.ability_at_tier(cog_part, tier)
		_check(tier_cog["target"] == all_foe_ranks and int(tier_cog["target_mask"]) == StitchedParts.ALL_RANKS_MASK
			and int(StitchedParts.ALL_RANKS_MASK) == StitchedParts.rank_mask(all_foe_ranks),
			"AC1: tier %d Cog Shot resolves target ranks 1-4 with the all-ranks mask" % tier)
		_check(tier_cog["launch"] == cog_launch and int(tier_cog["launch_mask"]) == StitchedParts.rank_mask(cog_launch),
			"AC1: tier %d Cog Shot still launches from hero ranks 2-4" % tier)
		for rank in all_foe_ranks:
			_check(StitchedParts.ranks_allowed(int(tier_cog["target_mask"]), rank),
				"AC1: tier %d Cog Shot allows enemy target rank %d" % [tier, rank])
		_check(not StitchedParts.ranks_allowed(int(tier_cog["target_mask"]), 0)
			and not StitchedParts.ranks_allowed(int(tier_cog["target_mask"]), 5),
			"AC1: tier %d Cog Shot refuses unauthored target ranks 0 and 5" % tier)
		_check(str(tier_cog["id"]) == "tinker_cog_shot_move" and str(tier_cog["name"]) == "Cog Shot"
			and str(tier_cog["kind"]) == "ranged" and str(tier_cog["target_side"]) == "enemy"
			and not bool(tier_cog["multi"]) and int(tier_cog["self_move"]) == 0
			and str(tier_cog["move"]) == "attack2" and int(tier_cog["crit"]) == 0
			and int(tier_cog["mark_damage"]) == 0 and int(tier_cog["acc"]) == [91, 91, 95][tier - 1]
			and tier_cog["dmg"] == [[4, 6], [5, 8], [7, 10]][tier - 1]
			and int(tier_cog["effects"].get("mark", 0)) == [2, 3, 3][tier - 1],
			"AC4: tier %d Cog Shot keeps ACC/damage/Mark/crit/mark_damage/pose exactly as authored" % tier)
		_check(int(StitchedParts.stat_at_tier(cog_part, tier).get("acc", 0)) == 4,
			"AC4: tier %d Cog Shot head stat stays ACC +4" % tier)
	var expected_shots := {
		"tinker_head_cog_shot": {"acc": [91, 91, 95], "dmg": [[4, 6], [5, 8], [7, 10]], "mark": [2, 3, 3], "exposed": [0, 0, 0], "multi": false, "target": [1, 2, 3, 4]},
		"tinker_arms_scrap_bomb": {"acc": [90, 92, 95], "dmg": [[3, 4], [4, 6], [5, 7]], "mark": [0, 0, 0], "exposed": [1, 1, 1], "multi": true, "target": [1, 2, 3]},
		"tinker_arms_overload": {"acc": [90, 90, 94], "dmg": [[3, 5], [4, 7], [5, 9]], "mark": [0, 0, 0], "exposed": [0, 0, 0], "multi": false, "target": [1, 2, 3, 4]},
	}
	for id in expected_shots:
		var expected_shot: Dictionary = expected_shots[id]
		for tier in [1, 2, 3]:
			var shot := StitchedParts.ability_at_tier(accepted["by_id"][id], tier)
			_check(int(shot["acc"]) == int(expected_shot["acc"][tier - 1])
				and shot["dmg"] == expected_shot["dmg"][tier - 1]
				and int(shot["effects"].get("mark", 0)) == int(expected_shot["mark"][tier - 1])
				and int(shot["effects"].get("exposed", 0)) == int(expected_shot["exposed"][tier - 1])
				and bool(shot["multi"]) == bool(expected_shot["multi"])
				and shot["target"] == expected_shot["target"]
				and int(shot["target_mask"]) == StitchedParts.rank_mask(expected_shot["target"])
				and int(shot["self_move"]) == 0
				and str(shot["target_side"]) == "enemy"
				and str(shot["move"]) == "attack2",
				"AC1: tier %d numbers, authored target ranks and attack2 pose stay authored for %s" % [tier, id])
	# AC1: Scrap Bomb is Tinker's starter arms part. Its one new authored effect is a one-turn
	# Exposed 1 applied by each landed shot; every number, reach, stat, accuracy, pose and the
	# absence of Mark stays exactly as shipped at all three stitch tiers.
	var bomb_part: Dictionary = accepted["by_id"][STARTERS["arms"]]
	var bomb_text := "Scatter scrap across every living foe in ranks one through three; each landed shot leaves that foe Exposed 1 for one turn, and no scrap ever reaches a fourth rank."
	_check(str(bomb_part["name"]) == "Scrap Bomb" and str(bomb_part["slot"]) == "arms"
		and str(bomb_part["owner"]) == "tinker" and bomb_part["stat"] == {"dmg": 1}
		and str(bomb_part["text"]) == bomb_text,
		"AC1: Scrap Bomb keeps its named arms part, damage +1 stat and one-time setup rules text")
	_check(str(bomb_part["ability"]["id"]) == "tinker_scrap_bomb_move"
		and str(bomb_part["ability"]["name"]) == "Scrap Bomb"
		and str(bomb_part["ability"]["kind"]) == "ranged"
		and str(bomb_part["ability"]["target_side"]) == "enemy"
		and bool(bomb_part["ability"]["multi"]) and int(bomb_part["ability"]["crit"]) == 0
		and int(bomb_part["ability"]["mark_damage"]) == 0
		and bomb_part["ability"]["effects"] == {"exposed": 1}
		and str(bomb_part["ability"]["move"]) == "attack2",
		"AC1: base Scrap Bomb authors only Exposed 1 with no Mark, crit or mark_damage")
	_check(bomb_part["ability"]["launch"] == [3, 4] and int(bomb_part["ability"]["launch_mask"]) == StitchedParts.rank_mask([3, 4]),
		"AC1: Scrap Bomb launches from hero ranks 3-4 only")
	_check(bomb_part["ability"]["target"] == [1, 2, 3]
		and int(bomb_part["ability"]["target_mask"]) == StitchedParts.rank_mask([1, 2, 3]),
		"AC1: Scrap Bomb targets living enemy ranks 1-3 only, never a fourth rank")
	for tier in [1, 2, 3]:
		var tier_bomb := StitchedParts.ability_at_tier(bomb_part, tier)
		_check(int(tier_bomb["acc"]) == [90, 92, 95][tier - 1]
			and tier_bomb["dmg"] == [[3, 4], [4, 6], [5, 7]][tier - 1]
			and bool(tier_bomb["multi"]) and tier_bomb["launch"] == [3, 4]
			and tier_bomb["target"] == [1, 2, 3]
			and int(tier_bomb["target_mask"]) == StitchedParts.rank_mask([1, 2, 3])
			and int(tier_bomb["mark_damage"]) == 0
			and tier_bomb["effects"] == {"exposed": 1}
			and not tier_bomb["effects"].has("mark")
			and str(tier_bomb["move"]) == "attack2",
			"AC1: tier %d Scrap Bomb keeps its original ACC/damage/reach and adds only Exposed 1" % tier)
		_check(int(StitchedParts.stat_at_tier(bomb_part, tier).get("dmg", 0)) == 1,
			"AC1: tier %d Scrap Bomb arms stat stays damage +1" % tier)
		_check(tier_bomb["effects"] == bomb_part["ability"]["effects"],
			"AC1: tier %d Scrap Bomb inherits and never increases the base Exposed 1" % tier)

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
					var exposed_receipt := false
					for status in hit.get("statuses", []):
						if str(status.get("status", "")) == "exposed" and int(status.get("duration", 0)) == 1:
							exposed_receipt = true
					if bool(hit.get("hit", false)):
						_check(exposed_receipt,
							"AC1: tier %d landed Scrap Bomb receipt applies Exposed 1 after its damage" % tier)
					else:
						_check(not exposed_receipt and int(hit.get("damage", 0)) == 0,
							"AC2: tier %d missed Scrap Bomb applies no Exposed and no damage" % tier)
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


## Builds the same seeded preview battle with the shipped Scrap Bomb ability's effects removed
## in test memory only. Everything else (seed, equipment, RNG, rolls) stays identical, so the
## control's immediate damage proves the real blast does not buff its own shot.
func _scrap_bomb_control_battle(seed_value: int) -> StitchedRules:
	var config := _config(STARTERS["arms"], 1, seed_value)
	if config.is_empty():
		return null
	for part in config["parts"]:
		if str(part.get("id", "")) == STARTERS["arms"]:
			part["ability"]["effects"] = {}
	var result := StitchedRules.create(config)
	if not bool(result.get("ok", false)):
		return null
	return result["battle"] as StitchedRules


## AC2/AC3 witness: on Tinker's genuine scheduled turn in the shipped 4v3 preview, Scrap Bomb
## makes one attempt against each living foe in enemy ranks 1-3. Landed shots apply Exposed 1
## after their own damage, a miss applies nothing, and the vacant rank 4 refuses before any
## spend. A later hero in the same round then lands a real rank-3 Needle Pin on the still-Exposed
## Moth Scribe; an equal-seed twin with only that Exposed removed deals exactly the already
## existing 50% less. Returns {} unless every precondition holds.
func _scrap_bomb_exposed_witness(seed_value: int) -> Dictionary:
	var foe_ids: Array = ["fray_scavenger", "scissor_crab", "moth_scribe"]
	var battle := _battle(STARTERS["arms"], 1, seed_value)
	if battle == null or not _to(battle, "tinker"):
		return {}
	if int(battle.get_unit("tinker")["rank"]) < 3:
		return {}
	if str(battle.get_unit("tinker")["parts"]["arms"]["id"]) != STARTERS["arms"]:
		return {}
	if battle.get_foes().size() != 3:
		return {}
	var rank := 1
	var hp_before: Dictionary = {}
	for foe_id in foe_ids:
		var foe := battle.get_unit(foe_id)
		if foe.is_empty() or bool(foe.get("dead", true)) or int(foe.get("hp", 0)) <= 0:
			return {}
		if int(foe.get("rank", 0)) != rank:
			return {}
		hp_before[foe_id] = int(foe["hp"])
		rank += 1
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var actor_before := battle.current_actor_id()
	# The normal preview leaves enemy rank 4 empty; the blast still refuses it without a spend.
	var rank_four := battle.use_part(STARTERS["arms"], 4)
	if bool(rank_four.get("ok", false)) or not str(rank_four.get("error", "")).contains("rank 4"):
		return {}
	if before != battle.state_snapshot() or rng != battle.rng_state():
		return {}
	var after_rank_four := battle.state_snapshot()
	var rng_after_rank_four := battle.rng_state()
	var shot := battle.use_part(STARTERS["arms"], 1)
	if not bool(shot.get("ok", false)):
		return {}
	var after_shot := battle.state_snapshot()
	var rng_after_shot := battle.rng_state()
	if str(shot.get("action", "")) != "ability" or str(shot.get("actor", "")) != "tinker" \
			or str(shot.get("part", "")) != STARTERS["arms"] \
			or str(shot.get("ability", "")) != "tinker_scrap_bomb_move":
		return {}
	var results: Array = shot.get("results", [])
	if results.size() != 3:
		return {}
	var seen: Dictionary = {}
	var hits := 0
	var misses := 0
	var exposed_hits: Array = []
	var live_after: Dictionary = {}
	for hit in results:
		var target_id := str(hit.get("target", ""))
		if not target_id in foe_ids or seen.has(target_id):
			return {}
		seen[target_id] = true
		if str(hit.get("target_side", "")) != "foe":
			return {}
		if int(hit.get("target_rank", 0)) != foe_ids.find(target_id) + 1:
			return {}
		var target := battle.get_unit(target_id)
		var exposed_receipt := -1
		var status_count := 0
		for status in hit.get("statuses", []):
			status_count += 1
			if str(status.get("status", "")) == "exposed":
				exposed_receipt = int(status.get("duration", 0))
		if bool(hit.get("hit", false)):
			hits += 1
			if int(hit.get("damage", 0)) <= 0 or exposed_receipt != 1 or status_count != 1:
				return {}
			if int(hit.get("target_hp", -1)) != int(target["hp"]):
				return {}
			if int(target["hp"]) != int(hp_before[target_id]) - int(hit["damage"]):
				return {}
			if int(target["statuses"].get("exposed", 0)) != 1:
				return {}
			live_after[target_id] = 1
			exposed_hits.append(target_id)
		else:
			misses += 1
			if int(hit.get("damage", 0)) != 0 or int(hit.get("target_hp", -1)) != int(hp_before[target_id]):
				return {}
			if exposed_receipt != -1 or not hit.get("statuses", []).is_empty():
				return {}
			if int(target["hp"]) != int(hp_before[target_id]):
				return {}
			if int(target["statuses"].get("exposed", 0)) != 0:
				return {}
			live_after[target_id] = 0
	if seen.size() != 3 or hits == 0 or misses == 0:
		return {}
	if not exposed_hits.has("moth_scribe"):
		return {}
	if int(battle.get_unit("moth_scribe")["statuses"].get("exposed", 0)) != 1:
		return {}
	if battle.is_over() or battle.current_actor_id() == "tinker":
		return {}
	var round_after := battle.round_number()
	var after_bomb := battle.state_snapshot()
	var order := battle.turn_order()
	var turn_index := int(after_bomb.get("turn_index", 0))
	var follow := ""
	for index in range(turn_index, order.size()):
		var next_id := str(order[index])
		if next_id == "moth_scribe":
			break
		if next_id == "seamstress" or next_id == "lantern_monk":
			follow = next_id
			break
	if follow.is_empty():
		return {}
	if str(battle.get_unit(follow)["parts"]["head"]["id"]) != "any_head_needle_pin":
		return {}
	# Equal-seed control blasts: the real shot's own immediate damage must match a twin whose
	# ability carries no Exposed effect, so the status can only follow the hit.
	var control := _scrap_bomb_control_battle(seed_value)
	if control == null or not _to(control, "tinker"):
		return {}
	var control_shot := control.use_part(STARTERS["arms"], 1)
	if not bool(control_shot.get("ok", false)) or control_shot.get("results", []).size() != 3:
		return {}
	for foe_id in foe_ids:
		if int(control.get_unit(foe_id)["statuses"].get("exposed", 0)) != 0:
			return {}
	# Equal-seed twin for the follow-up: identical blast, then only the Exposed is removed.
	var twin := _battle(STARTERS["arms"], 1, seed_value)
	if twin == null or not _to(twin, "tinker"):
		return {}
	var twin_shot := twin.use_part(STARTERS["arms"], 1)
	if twin_shot != shot:
		return {}
	twin._units["moth_scribe"]["statuses"].erase("exposed")
	if int(twin.get_unit("moth_scribe")["statuses"].get("exposed", 0)) != 0:
		return {}
	if not _to(battle, follow) or not _to(twin, follow):
		return {}
	if battle.round_number() != round_after or twin.round_number() != round_after:
		return {}
	var round_before_follow := battle.round_number()
	if int(battle.get_unit("moth_scribe")["statuses"].get("exposed", 0)) != 1:
		return {}
	if int(twin.get_unit("moth_scribe")["statuses"].get("exposed", 0)) != 0:
		return {}
	var pre_follow_rng := battle.rng_state()
	if pre_follow_rng != twin.rng_state():
		return {}
	var moth_before_follow := battle.get_unit("moth_scribe")
	var charged := battle.use_part("any_head_needle_pin", 3)
	var plain := twin.use_part("any_head_needle_pin", 3)
	if not bool(charged.get("ok", false)) or not bool(plain.get("ok", false)):
		return {}
	if charged.get("results", []).size() != 1 or plain.get("results", []).size() != 1:
		return {}
	var charged_hit: Dictionary = charged["results"][0]
	var plain_hit: Dictionary = plain["results"][0]
	if str(charged_hit.get("target", "")) != "moth_scribe" or int(charged_hit.get("target_rank", 0)) != 3:
		return {}
	if str(plain_hit.get("target", "")) != "moth_scribe" or int(plain_hit.get("target_rank", 0)) != 3:
		return {}
	if not bool(charged_hit.get("hit", false)) or not bool(plain_hit.get("hit", false)):
		return {}
	if int(charged_hit.get("roll", 0)) != int(plain_hit.get("roll", -1)) \
			or bool(charged_hit.get("crit", false)) != bool(plain_hit.get("crit", false)):
		return {}
	if int(charged_hit.get("damage", 0)) <= int(plain_hit.get("damage", 0)):
		return {}
	return {
		"battle": battle,
		"twin": twin,
		"control": control,
		"foe_ids": foe_ids,
		"hp_before": hp_before,
		"live_after": live_after,
		"before": before,
		"rng": rng,
		"actor_before": actor_before,
		"rank_four": rank_four,
		"after_rank_four": after_rank_four,
		"rng_after_rank_four": rng_after_rank_four,
		"shot": shot,
		"after_shot": after_shot,
		"rng_after_shot": rng_after_shot,
		"hits": hits,
		"misses": misses,
		"round_after": round_after,
		"round_before_follow": round_before_follow,
		"follow": follow,
		"control_shot": control_shot,
		"charged": charged,
		"plain": plain,
		"charged_hit": charged_hit,
		"plain_hit": plain_hit,
		"moth_before_follow": moth_before_follow,
		"pre_follow_rng": pre_follow_rng,
		"end_snapshot": battle.state_snapshot(),
		"rng_after": battle.rng_state(),
	}


## AC1/AC2/AC3: the shipped 4v3 preview, three living foes in ranks 1-3, one real Scrap Bomb
## on Tinker's scheduled turn from hero rank 3, a genuine miss with no status or damage, a real
## subsequent Needle Pin that takes exactly the already-existing 50% Exposed bonus, an
## identical effects-free damage control, a living rank-4 foe left untouched, and an equal-seed
## replay of every receipt, status, HP value and RNG position.
func _test_scrap_bomb_exposed() -> void:
	var witness: Dictionary = {}
	var witness_seed := 0
	for seed_value in range(499000, 499400):
		witness = _scrap_bomb_exposed_witness(seed_value)
		if not witness.is_empty():
			witness_seed = seed_value
			break
	_check(not witness.is_empty(), "AC2: real seeded Scrap Bomb Exposed witness exists in the shipped S2 preview")
	if witness.is_empty():
		return
	var battle: StitchedRules = witness["battle"]
	var shot: Dictionary = witness["shot"]
	var results: Array = shot["results"]
	var foe_ids: Array = witness["foe_ids"]
	_check(str(witness["actor_before"]) == "tinker" and battle.get_heroes().size() == 4 and battle.get_foes().size() == 3
		and witness["before"] != witness["after_shot"]
		and int(witness["rng"]) != int(witness["rng_after_shot"]),
		"AC2: the blast spends Tinker's genuine scheduled turn in the real four-hero/three-foe preview")
	_check(int(battle.get_unit("tinker")["rank"]) >= 3
		and str(battle.get_unit("tinker")["parts"]["arms"]["id"]) == STARTERS["arms"],
		"AC2: equipped rank-3/4 Tinker really launches the shipped Scrap Bomb")
	_check(not bool(witness["rank_four"].get("ok", false))
		and str(witness["rank_four"].get("error", "")).contains("rank 4")
		and witness["before"] == witness["after_rank_four"]
		and int(witness["rng"]) == int(witness["rng_after_rank_four"]),
		"AC2: Scrap Bomb refuses the vacant enemy rank 4 before any state, turn or RNG spend")
	_check(int(witness["hits"]) > 0 and int(witness["misses"]) > 0,
		"AC2: the witness genuinely contains landed and missed blast attempts")
	var seen: Dictionary = {}
	var landed := 0
	var missed := 0
	for hit in results:
		var target_id := str(hit["target"])
		seen[target_id] = true
		_check(str(hit.get("target_side", "")) == "foe"
			and int(hit.get("target_rank", 0)) == foe_ids.find(target_id) + 1
			and not str(hit.get("target", "")).begins_with("warden")
			and not str(hit.get("target", "")).begins_with("seamstress")
			and not str(hit.get("target", "")).begins_with("lantern_monk")
			and str(hit.get("target", "")) != "tinker",
			"AC2: each blast receipt is one living enemy in ranks 1-3, never an ally")
		var exposed_receipt := -1
		for status in hit.get("statuses", []):
			if str(status.get("status", "")) == "exposed":
				exposed_receipt = int(status.get("duration", 0))
		if bool(hit.get("hit", false)):
			landed += 1
			_check(exposed_receipt == 1 and int(witness["live_after"][target_id]) == 1
				and int(hit.get("damage", 0)) > 0,
				"AC3: a landed blast hit applies Exposed 1 after dealing its original damage")
		else:
			missed += 1
			_check(exposed_receipt == -1 and int(hit.get("damage", 0)) == 0
				and int(witness["live_after"][target_id]) == 0
				and int(battle.get_unit(target_id)["hp"]) == int(witness["hp_before"][target_id]),
				"AC3: a missed blast applies no Exposed and no damage")
	_check(results.size() == 3 and seen.size() == 3 and landed > 0 and missed > 0,
		"AC2: Scrap Bomb gives each living foe exactly one attempt with no extra action or foe")
	# The blast's own immediate damage is unchanged: an equal-seed battle whose ability carries
	# no Exposed effect takes identical hit rolls, crits, damage and HP.
	var control: StitchedRules = witness["control"]
	var control_results: Array = witness["control_shot"]["results"]
	var control_clean := control_results.size() == results.size()
	for index in range(mini(control_results.size(), results.size())):
		var real_hit: Dictionary = results[index]
		var control_hit: Dictionary = control_results[index]
		control_clean = control_clean and str(control_hit["target"]) == str(real_hit["target"]) \
			and bool(control_hit.get("hit", false)) == bool(real_hit.get("hit", false)) \
			and bool(control_hit.get("crit", false)) == bool(real_hit.get("crit", false)) \
			and int(control_hit.get("roll", 0)) == int(real_hit.get("roll", 0)) \
			and int(control_hit.get("damage", 0)) == int(real_hit.get("damage", 0)) \
			and int(control_hit.get("target_hp", -1)) == int(real_hit.get("target_hp", -2))
	for foe_id in foe_ids:
		control_clean = control_clean and int(control.get_unit(foe_id)["statuses"].get("exposed", 0)) == 0
	_check(control_clean,
		"AC3: the same-seed no-Exposed control proves the blast's immediate damage is original")
	# A real follow-up in the same round: a hero lands Needle Pin on the still-Exposed Moth
	# Scribe; the twin with only that Exposed removed takes exactly 50% less.
	var charged_hit: Dictionary = witness["charged_hit"]
	var plain_hit: Dictionary = witness["plain_hit"]
	var moth_before: Dictionary = witness["moth_before_follow"]
	_check(str(witness["follow"]) in ["seamstress", "lantern_monk"]
		and str(witness["charged"].get("actor", "")) == str(witness["follow"])
		and str(witness["charged"].get("part", "")) == "any_head_needle_pin"
		and str(witness["charged"].get("ability", "")) == "needle_pin"
		and int(witness["round_before_follow"]) == int(witness["round_after"]),
		"AC3: an eligible real hero in the same round lands the follow-up direct hit on the exposed foe")
	_check(str(charged_hit.get("target", "")) == "moth_scribe"
		and bool(charged_hit.get("hit", false)) and bool(plain_hit.get("hit", false))
		and int(charged_hit.get("roll", 0)) == int(plain_hit.get("roll", -1))
		and bool(charged_hit.get("crit", false)) == bool(plain_hit.get("crit", false)),
		"AC3: exposed and twin follow-up use the identical seeded hit and crit rolls")
	var expected_damage := StitchedRules.damage_after_modifiers(
		int(plain_hit.get("damage", 0)), {}, {"exposed": 1}, false, 0, int(moth_before.get("prot", 0))
	)
	_check(int(charged_hit.get("damage", 0)) == expected_damage
		and int(charged_hit.get("damage", 0)) > int(plain_hit.get("damage", 0))
		and int(moth_before["statuses"].get("mark", 0)) == 0,
		"AC3: the existing 50% Exposed modifier alone raises the follow-up damage")
	_check(int(battle.get_unit("moth_scribe")["hp"]) == int(moth_before.get("hp", 0)) - int(charged_hit.get("damage", 0))
		and int(charged_hit.get("target_hp", -1)) == int(battle.get_unit("moth_scribe")["hp"]),
		"AC3: the real Moth Scribe loses exactly the receipted follow-up damage")
	# A living foe in rank 4 is outside the authored reach: it is never hit, damaged or exposed.
	var rear := _rear_foe_battle(1, witness_seed)
	var rear_ready := rear != null and _to(rear, "tinker")
	_check(rear_ready, "AC2: rank-4 untouched witness reaches a real Tinker turn")
	if rear_ready:
		var moth_before_rear := rear.get_unit("moth_scribe")
		_check(int(moth_before_rear.get("rank", 0)) == 4
			and rear.get_foes().all(func(foe): return int(foe["rank"]) != 3),
			"AC2: only the existing Moth Scribe stands in enemy rank 4 and rank 3 is empty")
		var rear_shot := rear.use_part(STARTERS["arms"], 1)
		var rear_targets: Dictionary = {}
		for hit in rear_shot.get("results", []):
			rear_targets[str(hit["target"])] = true
		var moth_after_rear := rear.get_unit("moth_scribe")
		_check(bool(rear_shot.get("ok", false)) and rear_shot.get("results", []).size() == 2
			and rear_targets.has("fray_scavenger") and rear_targets.has("scissor_crab")
			and not rear_targets.has("moth_scribe")
			and int(moth_after_rear.get("hp", -1)) == int(moth_before_rear.get("hp", 0))
			and int(moth_after_rear.get("statuses", {}).get("exposed", 0)) == 0,
			"AC2: a living foe in rank 4 stays untouched by the blast")
	# Same seed, equipment and action replay every receipt, status, HP value and RNG position.
	var replay := _scrap_bomb_exposed_witness(witness_seed)
	_check(not replay.is_empty(), "AC3: the Scrap Bomb Exposed witness replays at seed %d" % witness_seed)
	if not replay.is_empty():
		_check(replay["shot"] == shot and replay["charged"] == witness["charged"]
			and replay["plain"] == witness["plain"]
			and replay["end_snapshot"] == witness["end_snapshot"]
			and int(replay["rng_after"]) == int(witness["rng_after"]),
			"AC3: equal-seed replay reproduces every receipt, status, HP value and exact RNG")

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
			"AC3: the vacant enemy rank 4 refuses without changing snapshot, turn or seeded RNG for " + part_id)
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
			_check(StitchedParts.ranks_allowed(int(_catalog()["by_id"][part_id]["ability"]["target_mask"]), 4),
				"AC2: Cog Shot now carries a positive enemy rank-4 target mask")
		else:
			_check(results.size() == 3 and seen.size() == 3 and seen.has("fray_scavenger") and seen.has("scissor_crab") and seen.has("moth_scribe"),
				"AC2: Scrap Bomb receipts each of the three living foes in ranks 1-3 exactly once")
			_check(not StitchedParts.ranks_allowed(int(_catalog()["by_id"][part_id]["ability"]["target_mask"]), 4),
				"AC2: Scrap Bomb still has no enemy rank-4 target")


## The shipped S2 preview 4v3 with Tinker's starter gear, where only the already-existing
## Moth Scribe moves to enemy rank 4 in test memory. Enemy ranks 1 and 2 keep their real foes,
## rank 3 is left empty and no fourth starter foe is invented; the preview file is untouched.
func _rear_foe_battle(
	tier: int, seed_value: int, head: Dictionary = {}, arms: Dictionary = {}
) -> StitchedRules:
	var config := _config("", tier, seed_value)
	if config.is_empty():
		return null
	if not head.is_empty():
		config["heroes"][2]["parts"]["head"] = head.duplicate(true)
	if not arms.is_empty():
		config["heroes"][2]["parts"]["arms"] = arms.duplicate(true)
	var built := StitchedRules.create(config)
	if not bool(built.get("ok", false)):
		return null
	var battle: StitchedRules = built["battle"]
	if battle.get_foes().size() != 3 or battle.get_unit("moth_scribe").is_empty():
		return null
	battle._units["moth_scribe"]["rank"] = 4
	return battle


## AC2 witness: on Tinker's genuine scheduled turn in the real preview, Cog Shot fires at the
## living Moth Scribe standing in enemy rank 4 and returns exactly one foe receipt for it.
## Enemy ranks 1 and 2 keep their foes untouched by the shot and rank 3 stays empty.
func _rear_cog_shot_witness(tier: int, seed_value: int) -> Dictionary:
	var battle := _rear_foe_battle(tier, seed_value)
	if battle == null or not _to(battle, "tinker"):
		return {}
	var tinker := battle.get_unit("tinker")
	if int(tinker.get("rank", 0)) != 3:
		return {}
	if str(tinker.get("parts", {}).get("head", {}).get("id", "")) != STARTERS["head"]:
		return {}
	var moth := battle.get_unit("moth_scribe")
	if int(moth.get("rank", 0)) != 4 or bool(moth.get("dead", true)) or int(moth.get("hp", 0)) <= 0:
		return {}
	var other_hp: Dictionary = {}
	for foe_id in ["fray_scavenger", "scissor_crab"]:
		other_hp[foe_id] = int(battle.get_unit(foe_id).get("hp", 0))
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var actor_before := battle.current_actor_id()
	var shot := battle.use_part(STARTERS["head"], 4)
	if not bool(shot.get("ok", false)):
		return {}
	var results: Array = shot.get("results", [])
	if results.size() != 1:
		return {}
	var hit: Dictionary = results[0]
	if str(hit.get("target", "")) != "moth_scribe" or int(hit.get("target_rank", 0)) != 4:
		return {}
	# The shot may only touch the rear foe: the two front foes keep their exact HP.
	for foe_id in other_hp:
		if int(battle.get_unit(foe_id).get("hp", -1)) != int(other_hp[foe_id]):
			return {}
	return {
		"battle": battle,
		"tier": tier,
		"moth_before": moth,
		"other_hp": other_hp,
		"before": before,
		"after": battle.state_snapshot(),
		"rng": rng,
		"rng_after": battle.rng_state(),
		"actor_before": actor_before,
		"actor_after": battle.current_actor_id(),
		"shot": shot,
	}


## True when a rank-4 Cog Shot witness landed for damage and left the authored Mark potency.
func _rear_cog_shot_lands(witness: Dictionary, potency: int) -> bool:
	var shot: Dictionary = witness.get("shot", {})
	var results: Array = shot.get("results", [])
	if results.size() != 1 or not bool(results[0].get("hit", false)) or int(results[0].get("damage", 0)) <= 0:
		return false
	var moth := (witness["battle"] as StitchedRules).get_unit("moth_scribe")
	if int(moth.get("hp", -1)) != int(witness["moth_before"].get("hp", 0)) - int(results[0]["damage"]):
		return false
	if int(results[0].get("target_hp", -1)) != int(moth.get("hp", -2)):
		return false
	var mark_receipt := false
	for status in results[0].get("statuses", []):
		if str(status.get("status", "")) == "mark" and int(status.get("duration", 0)) == potency:
			mark_receipt = true
	return mark_receipt and int(moth.get("statuses", {}).get("mark", 0)) == potency


## AC3 witness: two genuine Tinker Moves bring her from rank 3 to the forbidden launch rank 1,
## while the living Moth Scribe still stands in enemy rank 4.
func _front_rank_witness(seed_value: int) -> Dictionary:
	var battle := _rear_foe_battle(1, seed_value)
	if battle == null or not _to(battle, "tinker"):
		return {}
	if int(battle.get_unit("tinker")["rank"]) != 3:
		return {}
	var first := battle.move(-1)
	if not bool(first.get("ok", false)) or not _to(battle, "tinker") or battle.is_over():
		return {}
	var second := battle.move(-1)
	if not bool(second.get("ok", false)) or int(battle.get_unit("tinker")["rank"]) != 1:
		return {}
	if not _to(battle, "tinker") or battle.is_over():
		return {}
	if int(battle.get_unit("tinker")["rank"]) != 1:
		return {}
	if int(battle.get_unit("moth_scribe")["rank"]) != 4 or bool(battle.get_unit("moth_scribe")["dead"]):
		return {}
	return {"battle": battle, "first": first, "second": second}


## AC2/AC3, the task goal: at every stitch tier Tinker's starter Cog Shot marks a genuinely
## living foe in enemy rank 4. The shipped preview keeps its three real foes; only the existing
## Moth Scribe is moved to enemy rank 4 in test memory (rank 3 empty, ranks 1-2 untouched).
## A vacant enemy rank 4 still refuses, and torn, unequipped, rank-1 launch, ranks 0/5,
## Scrap Bomb at rank 4 and a stale repeat all fail closed without spending.
func _test_cog_shot_rear_foe() -> void:
	var mark_ladder := [2, 3, 3]
	var structure_seed := -1
	for tier in [1, 2, 3]:
		var structure: Dictionary = {}
		var landed: Dictionary = {}
		var landed_seed := 0
		for seed_value in range(499700, 499800):
			var witness := _rear_cog_shot_witness(tier, seed_value)
			if witness.is_empty():
				continue
			if structure.is_empty():
				structure = witness
				if tier == 1:
					structure_seed = seed_value
			if _rear_cog_shot_lands(witness, int(mark_ladder[tier - 1])):
				landed = witness
				landed_seed = seed_value
				break
		_check(not structure.is_empty(), "AC2: tier %d bounded fixed-seed rank-4 Cog Shot cast witness exists" % tier)
		if structure.is_empty():
			continue
		var battle: StitchedRules = structure["battle"]
		var shot: Dictionary = structure["shot"]
		var hit: Dictionary = shot["results"][0]
		_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 3
			and str(battle.get_unit("tinker")["parts"]["head"]["id"]) == STARTERS["head"],
			"AC2: tier %d witness keeps the four real heroes and three shipped foes with Cog Shot equipped" % tier)
		_check(int(battle.get_unit("moth_scribe")["rank"]) == 4
			and int(battle.get_unit("fray_scavenger")["rank"]) == 1
			and int(battle.get_unit("scissor_crab")["rank"]) == 2
			and battle.get_foes().all(func(foe): return int(foe["rank"]) != 3),
			"AC2: tier %d only the existing Moth Scribe stands in enemy rank 4 and rank 3 is empty" % tier)
		_check(str(shot.get("action", "")) == "ability" and str(shot.get("actor", "")) == "tinker"
			and str(shot.get("part", "")) == STARTERS["head"]
			and str(shot.get("ability", "")) == "tinker_cog_shot_move",
			"AC2: tier %d Cog Shot executes as Tinker's own equipped head action" % tier)
		_check(shot.get("results", []).size() == 1 and str(hit.get("target", "")) == "moth_scribe"
			and str(hit.get("target_side", "")) == "foe" and int(hit.get("target_rank", 0)) == 4,
			"AC2: tier %d Cog Shot yields exactly one receipt for the rank-4 Moth Scribe" % tier)
		var spent := str(structure["actor_before"]) == "tinker" and str(structure["actor_after"]) != "tinker"
		var advanced := int(structure["after"].get("round", -1)) != int(structure["before"].get("round", -2)) \
			or int(structure["after"].get("turn_index", -1)) != int(structure["before"].get("turn_index", -2))
		_check(spent and advanced, "AC2: tier %d accepted rank-4 shot spends one scheduled Tinker turn" % tier)
		_check(structure["before"] != structure["after"] and int(structure["rng_after"]) != int(structure["rng"]),
			"AC2: tier %d accepted rank-4 shot changes the authoritative snapshot and seeded RNG" % tier)
		var untouched := true
		for foe_id in structure["other_hp"]:
			untouched = untouched and int(battle.get_unit(foe_id).get("hp", -1)) == int(structure["other_hp"][foe_id])
		_check(untouched, "AC2: tier %d rank-4 Cog Shot never damages the two front foes" % tier)
		_check(not landed.is_empty(),
			"AC2: tier %d bounded fixed-seed Cog Shot hit and Mark witness exists on the rank-4 foe" % tier)
		if landed.is_empty():
			continue
		var landed_battle: StitchedRules = landed["battle"]
		var landed_hit: Dictionary = landed["shot"]["results"][0]
		var moth := landed_battle.get_unit("moth_scribe")
		_check(bool(landed_hit.get("hit", false)) and int(landed_hit.get("damage", 0)) > 0
			and int(moth.get("hp", 0)) == int(landed["moth_before"].get("hp", 0)) - int(landed_hit["damage"])
			and int(landed_hit.get("target_hp", -1)) == int(moth.get("hp", -2)),
			"AC2: tier %d landed rank-4 Cog Shot drops the real Moth Scribe HP by its receipted damage" % tier)
		var potency := int(mark_ladder[tier - 1])
		var mark_receipt := false
		for status in landed_hit.get("statuses", []):
			if str(status.get("status", "")) == "mark" and int(status.get("duration", 0)) == potency:
				mark_receipt = true
		_check(mark_receipt and int(moth.get("statuses", {}).get("mark", 0)) == potency,
			"AC2: tier %d landed Cog Shot applies Mark %d in receipt and on the rank-4 foe" % [tier, potency])
		var replay := _rear_cog_shot_witness(tier, landed_seed)
		_check(not replay.is_empty(), "AC3: tier %d rank-4 Cog Shot witness replays at seed %d" % [tier, landed_seed])
		if not replay.is_empty():
			_check(replay["shot"] == landed["shot"] and replay["before"] == landed["before"]
				and replay["after"] == landed["after"] and int(replay["rng_after"]) == int(landed["rng_after"]),
				"AC3: tier %d equal-seed replay reproduces the receipt, snapshot and exact RNG" % tier)
	# AC3: in the normal preview enemy rank 4 is vacant, so Cog Shot at 4 must still refuse for
	# lack of a target despite its legal rank-4 reach, without spending the turn or drawing RNG.
	var vacant := _battle()
	if vacant != null and _to(vacant, "tinker"):
		_check(vacant.get_foes().all(func(foe): return int(foe["rank"]) != 4),
			"AC3: normal preview genuinely has no foe in enemy rank 4")
		var vacant_before := vacant.state_snapshot()
		var vacant_rng := vacant.rng_state()
		var vacant_refusal := vacant.use_part(STARTERS["head"], 4)
		_check(not bool(vacant_refusal.get("ok", false)) and str(vacant_refusal.get("error", "")).contains("rank 4")
			and vacant_before == vacant.state_snapshot() and vacant_rng == vacant.rng_state()
			and vacant.current_actor_id() == "tinker",
			"AC3: Cog Shot at a vacant enemy rank 4 refuses without state, turn or RNG spend")
	else:
		_check(false, "AC3: vacant-rank refusal witness reaches a real Tinker turn")
	if structure_seed < 0:
		return
	var negative := _rear_foe_battle(1, structure_seed)
	if negative == null or not _to(negative, "tinker"):
		_check(false, "AC3: fail-closed rear-foe witness reaches a real Tinker turn")
		return
	_check(int(negative.get_unit("tinker")["rank"]) == 3 and int(negative.get_unit("moth_scribe")["rank"]) == 4,
		"AC3: rank-3 Tinker faces the real living rank-4 Moth Scribe")
	var before := negative.state_snapshot()
	var rng := negative.rng_state()
	var refusals: Array = []
	refusals.append(negative.use_part(STARTERS["head"], 0))
	refusals.append(negative.use_part(STARTERS["head"], 5))
	refusals.append(negative.use_part(STARTERS["arms"], 4))
	_check(not bool(refusals[0].get("ok", false)) and str(refusals[0].get("error", "")).contains("rank 0")
		and not bool(refusals[1].get("ok", false)) and str(refusals[1].get("error", "")).contains("rank 5")
		and not bool(refusals[2].get("ok", false)) and str(refusals[2].get("error", "")).contains("rank 4"),
		"AC3: Cog Shot refuses target ranks 0 and 5 while Scrap Bomb still refuses a living rank-4 foe")
	_check(before == negative.state_snapshot() and rng == negative.rng_state()
		and negative.current_actor_id() == "tinker",
		"AC3: those refusals change no state, spend no turn and draw no seeded RNG")
	var fired := negative.use_part(STARTERS["head"], 4)
	_check(bool(fired.get("ok", false)) and fired.get("results", []).size() == 1
		and str(fired["results"][0].get("target", "")) == "moth_scribe",
		"AC3: the same real rear foe is a legal Cog Shot target on that turn")
	var after_fire := negative.state_snapshot()
	var after_rng := negative.rng_state()
	var stale := negative.use_part(STARTERS["head"], 4)
	_check(not bool(stale.get("ok", false)) and after_fire == negative.state_snapshot()
		and after_rng == negative.rng_state() and negative.current_actor_id() != "tinker",
		"AC3: a stale second rank-4 Cog Shot after the spent turn fails closed")
	var torn := _rear_foe_battle(1, structure_seed, {"id": STARTERS["head"], "tier": 1, "torn": true})
	_check(torn != null, "AC3: a torn Cog Shot head can enter the real rear-foe battle")
	if torn != null and _to(torn, "tinker"):
		var torn_before := torn.state_snapshot()
		var torn_rng := torn.rng_state()
		var torn_shot := torn.use_part(STARTERS["head"], 4)
		_check(not bool(torn_shot.get("ok", false)) and str(torn_shot.get("error", "")).contains("torn")
			and torn_before == torn.state_snapshot() and torn_rng == torn.rng_state(),
			"AC3: a torn Cog Shot refuses the rank-4 foe without state, turn or RNG spend")
	else:
		_check(false, "AC3: torn-head witness reaches a real Tinker turn")
	var bare := _rear_foe_battle(1, structure_seed, {"id": ALTERNATES["head"], "tier": 1})
	var bare_ready := bare != null and _to(bare, "tinker")
	_check(bare_ready, "AC3: unequipped-head witness reaches a real Tinker turn")
	if bare_ready:
		var bare_before := bare.state_snapshot()
		var bare_rng := bare.rng_state()
		var unequipped := bare.use_part(STARTERS["head"], 4)
		_check(not bool(unequipped.get("ok", false)) and str(unequipped.get("error", "")).contains("not equipped")
			and bare_before == bare.state_snapshot() and bare_rng == bare.rng_state(),
			"AC3: an unequipped Cog Shot refuses the rear foe without state, turn or RNG spend")
	var overload := _rear_foe_battle(1, structure_seed, {}, {"id": ALTERNATES["arms"], "tier": 1})
	var overload_ready := overload != null and _to(overload, "tinker")
	_check(overload_ready, "AC2: Overload rear-foe witness reaches a real Tinker turn")
	if overload_ready:
		_check(StitchedParts.ranks_allowed(int(_catalog()["by_id"][ALTERNATES["arms"]]["ability"]["target_mask"]), 4),
			"AC2: Overload's authored target mask now admits foe rank 4")
		var overload_before := overload.state_snapshot()
		var overload_rng := overload.rng_state()
		var overload_shot := overload.use_part(ALTERNATES["arms"], 4)
		_check(bool(overload_shot.get("ok", false)) and overload_shot.get("results", []).size() == 1
			and str(overload_shot["results"][0].get("target", "")) == "moth_scribe"
			and int(overload_shot["results"][0].get("target_rank", 0)) == 4
			and overload_before != overload.state_snapshot() and overload_rng != overload.rng_state(),
			"AC2: Overload legally receipts the living rank-4 Moth Scribe")
	var front: Dictionary = {}
	for seed_value in range(499700, 499760):
		front = _front_rank_witness(seed_value)
		if not front.is_empty():
			break
	_check(not front.is_empty(), "AC3: a bounded fixed-seed witness really walks Tinker to launch rank 1")
	if front.is_empty():
		return
	var front_battle: StitchedRules = front["battle"]
	var front_before := front_battle.state_snapshot()
	var front_rng := front_battle.rng_state()
	var front_shot := front_battle.use_part(STARTERS["head"], 4)
	_check(not bool(front_shot.get("ok", false)) and str(front_shot.get("error", "")).contains("rank 1")
		and front_before == front_battle.state_snapshot() and front_rng == front_battle.rng_state(),
		"AC3: Cog Shot refuses a genuine hero rank-1 launch without state, turn or RNG spending")


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
	# The normal preview leaves enemy rank 4 empty (ranks 0 and 5 are invalid); the starter
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
	_check(all_refused and errors[0].contains("no legal target in rank 4") and errors[1].contains("rank 0")
		and errors[2].contains("rank 5") and errors[3].contains("not equipped"),
		"AC3: the empty rank 4, ranks 0/5 and the unequipped part each refuse for their own reason")
	_check(StitchedParts.ranks_allowed(int(_catalog()["by_id"][ALTERNATES["arms"]]["ability"]["target_mask"]), 4)
		and battle.get_foes().all(func(foe): return int(foe["rank"]) != 4),
		"AC3: the rank-4 refusal is an empty-target refusal, not an out-of-mask one")
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


## AC1: the shipped Tinker catalog's Gear Brace at all three stitch tiers. Only its tier-III
## override adds hero rank 4 to the launch ranks; the base ability, tier I and tier II stay at
## hero ranks 1-3, and the target, numbers, pose and torso stats keep their authored values.
## Casing Ward remains a separate self Thorns torso option and every other record is unchanged.
func _test_gear_brace_catalog() -> void:
	var accepted := _catalog()
	_check(bool(accepted.get("ok", false)), "AC1: StitchedParts.load_catalog accepts the revised Gear Brace catalog")
	if not bool(accepted.get("ok", false)):
		return
	var part_id := "tinker_torso_gear_brace"
	_check(accepted["by_id"].has(part_id), "AC1: Gear Brace is present in the Tinker catalog")
	if not accepted["by_id"].has(part_id):
		return
	var part: Dictionary = accepted["by_id"][part_id]
	_check(str(part["name"]) == "Gear Brace" and str(part["slot"]) == "torso"
		and str(part["owner"]) == "tinker" and part["stat"] == {"max_hp": 5, "prot": 5},
		"AC1: Gear Brace stays Tinker's named torso part with its authored base stat")
	var gear_text := "Guard one living ally in ranks one through four, taking the hits aimed at it for 2 turns at stitch tier I, 3 at tier II and 4 at tier III; tiers I and II cast from hero ranks one through three, tier III also from rank four."
	_check(str(part["text"]) == gear_text,
		"AC1: Gear Brace carries its revised, truthful rules text")
	var lowered := str(part["text"]).to_lower()
	_check(lowered.contains("ranks one through three") and lowered.contains("rank four")
		and lowered.contains("2 turns") and lowered.contains("3 at tier ii")
		and lowered.contains("4 at tier iii")
		and not lowered.contains("card") and not lowered.contains("block"),
		"AC1: Gear Brace's text explains both launch reaches and the 2/3/4 Guard ladder without a card cost or Block")
	_check(str(part["ability"]["id"]) == "tinker_gear_brace_move"
		and str(part["ability"]["name"]) == "Gear Brace"
		and str(part["ability"]["kind"]) == "guard"
		and str(part["ability"]["target_side"]) == "ally"
		and not bool(part["ability"]["multi"])
		and int(part["ability"]["crit"]) == 0 and int(part["ability"]["mark_damage"]) == 0
		and str(part["ability"]["move"]) == "guard",
		"AC1: base Gear Brace stays Tinker's single-ally guard ability in the guard pose")
	_check(part["ability"]["launch"] == [1, 2, 3]
		and int(part["ability"]["launch_mask"]) == StitchedParts.rank_mask([1, 2, 3])
		and part["ability"]["target"] == [1, 2, 3, 4]
		and int(part["ability"]["target_mask"]) == StitchedParts.ALL_RANKS_MASK
		and int(part["ability"]["effects"]["guard"]) == 2,
		"AC1: base Gear Brace launches from hero ranks 1-3 and Guards one ally in ranks 1-4 for 2")
	var expected_launch := [[1, 2, 3], [1, 2, 3], [1, 2, 3, 4]]
	var expected_guard := [2, 3, 4]
	var expected_hp := [5, 7, 9]
	var expected_prot := [5, 6, 8]
	for tier in [1, 2, 3]:
		var ability := StitchedParts.ability_at_tier(part, tier)
		_check(bool(StitchedParts.validate_ability(ability).get("ok", false)),
			"AC1: tier %d Gear Brace resolves to a valid ability" % tier)
		_check(ability["launch"] == expected_launch[tier - 1]
			and int(ability["launch_mask"]) == StitchedParts.rank_mask(expected_launch[tier - 1]),
			"AC1: tier %d Gear Brace resolves launch %s with the derived mask"
				% [tier, str(expected_launch[tier - 1])])
		_check(ability["target"] == [1, 2, 3, 4] and int(ability["target_mask"]) == StitchedParts.ALL_RANKS_MASK,
			"AC1: tier %d Gear Brace still targets one ally in ranks 1-4" % tier)
		for rank in [1, 2, 3, 4]:
			_check(StitchedParts.ranks_allowed(int(ability["target_mask"]), rank),
				"AC1: tier %d Gear Brace reaches ally rank %d" % [tier, rank])
		_check(StitchedParts.ranks_allowed(int(ability["launch_mask"]), 4) == (tier == 3)
			and StitchedParts.ranks_allowed(int(ability["launch_mask"]), 1)
			and StitchedParts.ranks_allowed(int(ability["launch_mask"]), 2)
			and StitchedParts.ranks_allowed(int(ability["launch_mask"]), 3),
			"AC1: tier %d Gear Brace launches from hero ranks 1-3%s" % [tier, " and 4" if tier == 3 else " only"])
		_check(int(ability["acc"]) == 100 and ability["dmg"] == [0, 0]
			and int(ability["crit"]) == 0 and int(ability["mark_damage"]) == 0
			and int(ability["self_move"]) == 0 and str(ability["move"]) == "guard"
			and str(ability["kind"]) == "guard" and str(ability["target_side"]) == "ally"
			and not bool(ability["multi"])
			and ability["effects"] == {"guard": expected_guard[tier - 1]},
			"AC1: tier %d Gear Brace keeps ACC 100, zero damage, no self move, Guard %d and its pose"
				% [tier, expected_guard[tier - 1]])
		var stat := StitchedParts.stat_at_tier(part, tier)
		_check(int(stat.get("max_hp", 0)) == expected_hp[tier - 1]
			and int(stat.get("prot", 0)) == expected_prot[tier - 1] and stat.size() == 2,
			"AC1: tier %d Gear Brace keeps torso max_hp %d and prot %d"
				% [tier, expected_hp[tier - 1], expected_prot[tier - 1]])
	# The tier reads never rewrite the frozen base ability kept in memory.
	_check(part["ability"]["launch"] == [1, 2, 3]
		and int(part["ability"]["launch_mask"]) == StitchedParts.rank_mask([1, 2, 3])
		and int(part["ability"]["effects"]["guard"]) == 2,
		"AC1: tier reads leave Gear Brace's base launch and Guard 2 untouched in memory")
	_check(part["tiers"]["3"]["ability"]["launch"] == [1, 2, 3, 4]
		and part["tiers"]["3"]["ability"]["effects"] == {"guard": 4},
		"AC1: the tier-III override adds only the rank-4 launch beside its Guard 4")
	# Only Gear Brace tier III changes launch ranks through a tier override; every other part
	# keeps its exact base launch and derived mask at every stitch tier.
	var launch_changes := 0
	for other_id in ALL_IDS:
		var other: Dictionary = accepted["by_id"][other_id]
		for tier in [1, 2, 3]:
			var other_ability := StitchedParts.ability_at_tier(other, tier)
			_check(bool(StitchedParts.validate_ability(other_ability).get("ok", false)),
				"AC1: %s still resolves a legal tier-%d ability" % [other_id, tier])
			if other_ability["launch"] != other["ability"]["launch"]:
				launch_changes += 1
				_check(other_id == part_id and tier == 3,
					"AC1: only tier-III Gear Brace changes launch ranks through a tier override")
			elif other_id != part_id:
				_check(other_ability["launch"] == other["ability"]["launch"]
					and int(other_ability["launch_mask"]) == int(other["ability"]["launch_mask"]),
					"AC1: unchanged %s keeps its exact base launch at tier %d" % [other_id, tier])
	_check(launch_changes == 1,
		"AC1: exactly one tier override changes launch ranks in the whole Tinker catalog")
	# The new override is validated like every other authored rank list: rank 5 fails closed.
	var bad_launch: Dictionary = part.duplicate(true)
	bad_launch["tiers"]["3"]["ability"]["launch"] = [1, 2, 3, 5]
	_check(not bool(StitchedParts.validate_part(bad_launch).get("ok", false)),
		"AC3: a tier-III Gear Brace override with rank 5 still fails validation")
	var duplicate_rank: Dictionary = part.duplicate(true)
	duplicate_rank["tiers"]["3"]["ability"]["launch"] = [1, 2, 3, 3]
	_check(not bool(StitchedParts.validate_part(duplicate_rank).get("ok", false)),
		"AC3: a tier-III Gear Brace override repeating a launch rank still fails validation")


## The shipped S2 preview with genuine four heroes and three foes where Tinker really wears the
## alternate Gear Brace torso at the requested tier plus Spare Screws legs at tier I. The
## preview file itself is never edited; only Tinker's equipped IDs change, and only the torso
## may be swapped for another part or flagged torn for the fail-closed checks.
func _gear_brace_battle(
	tier: int, seed_value: int, torso_id: String = "", torn_torso: bool = false
) -> StitchedRules:
	var config := _config(ALTERNATES["torso"], tier, seed_value)
	if config.is_empty():
		return null
	if not torso_id.is_empty():
		config["heroes"][2]["parts"]["torso"] = {"id": torso_id, "tier": tier}
	config["heroes"][2]["parts"]["legs"] = {"id": ALTERNATES["legs"], "tier": 1}
	if torn_torso:
		config["heroes"][2]["parts"]["torso"]["torn"] = true
	var result := StitchedRules.create(config)
	if not bool(result.get("ok", false)):
		return null
	return result["battle"] as StitchedRules


## A genuine Spare Screws action walks rank-3 Tinker behind the rank-4 Lantern Monk and then
## advances to her next scheduled turn, so the caller really stands there alive in rank 4.
func _gear_brace_to_back_rank(battle: StitchedRules) -> Dictionary:
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
	if battle.current_actor_id() == "tinker" or not _to(battle, "tinker") or battle.is_over():
		return {}
	var tinker := battle.get_unit("tinker")
	if int(tinker.get("rank", 0)) != 4 or bool(tinker.get("lost", false)) or int(tinker.get("hp", 0)) <= 0:
		return {}
	return {"swap": swap}


## AC2 witness: authentic 4v3 preview, tier-III Gear Brace plus Spare Screws. Tinker's own Spare
## Screws swaps her into hero rank 4; on her next genuine turn the rank-4 Guard refuses illegal
## ally ranks without a spend, then Guards the living rank-1 Warden for Guard 4, spends exactly
## one turn, and a real Fray Scavenger sack_swing is redirected onto her.
func _gear_brace_rank_four_witness(seed_value: int) -> Dictionary:
	var battle := _gear_brace_battle(3, seed_value)
	var walked := _gear_brace_to_back_rank(battle)
	if walked.is_empty():
		return {}
	var torso: Dictionary = battle.get_unit("tinker")["parts"]["torso"]
	if str(torso.get("id", "")) != ALTERNATES["torso"] or int(torso.get("tier", 0)) != 3:
		return {}
	var warden := battle.get_unit("warden")
	if warden.is_empty() or int(warden.get("rank", 0)) != 1 \
			or bool(warden.get("lost", true)) or int(warden.get("hp", 0)) <= 0:
		return {}
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var actor_before := battle.current_actor_id()
	var refusals: Array = []
	for target_rank in [0, 5]:
		refusals.append(battle.use_part(ALTERNATES["torso"], target_rank))
	var after_refusals := battle.state_snapshot()
	var actor_after_refusals := battle.current_actor_id()
	var cast := battle.use_part(ALTERNATES["torso"], 1)
	if not bool(cast.get("ok", false)) or str(cast.get("target", "")) != "warden":
		return {}
	var after := battle.state_snapshot()
	var rng_after := battle.rng_state()
	var tinker_after_cast := battle.get_unit("tinker")
	var off_turn := battle.use_part(ALTERNATES["torso"], 1)
	var after_off_turn := battle.state_snapshot()
	var rng_after_off_turn := battle.rng_state()
	var actor_after_off_turn := battle.current_actor_id()
	# A naturally scheduled living Fray Scavenger swing at the guarded rank 1 must name Tinker.
	if int(battle.get_unit("tinker")["statuses"].get("guard", 0)) <= 0 or not _to(battle, "fray_scavenger"):
		return {}
	var scavenger := battle.get_unit("fray_scavenger")
	if scavenger.is_empty() or bool(scavenger.get("dead", true)) or int(scavenger.get("hp", 0)) <= 0:
		return {}
	var warden_before_strike := int(battle.get_unit("warden")["hp"])
	var tinker_before_strike := int(battle.get_unit("tinker")["hp"])
	var strike := battle.use_foe_ability("sack_swing", 1)
	if not bool(strike.get("ok", false)) or strike.get("results", []).size() != 1:
		return {}
	if str(strike["results"][0].get("guarded_by", "")) != "tinker":
		return {}
	return {
		"battle": battle,
		"swap": walked["swap"],
		"warden_before": warden,
		"before": before,
		"rng": rng,
		"actor_before": actor_before,
		"refusals": refusals,
		"after_refusals": after_refusals,
		"actor_after_refusals": actor_after_refusals,
		"cast": cast,
		"after": after,
		"rng_after": rng_after,
		"tinker_after_cast": tinker_after_cast,
		"off_turn": off_turn,
		"after_off_turn": after_off_turn,
		"rng_after_off_turn": rng_after_off_turn,
		"actor_after_off_turn": actor_after_off_turn,
		"warden_before_strike": warden_before_strike,
		"tinker_before_strike": tinker_before_strike,
		"strike": strike,
	}


## AC3 witness: the same authentic rank-4 setup with tier-I or tier-II Gear Brace. The cast must
## be refused for its launch rank before the actor, snapshot or seeded RNG can change.
func _gear_brace_rank_four_refusal_witness(tier: int, seed_value: int) -> Dictionary:
	var battle := _gear_brace_battle(tier, seed_value)
	var walked := _gear_brace_to_back_rank(battle)
	if walked.is_empty():
		return {}
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var actor_before := battle.current_actor_id()
	var cast := battle.use_part(ALTERNATES["torso"], 1)
	return {
		"battle": battle,
		"swap": walked["swap"],
		"before": before,
		"rng": rng,
		"actor_before": actor_before,
		"cast": cast,
		"after": battle.state_snapshot(),
		"actor_after": battle.current_actor_id(),
	}


## AC3 witness: a real rank-4 Tinker whose torso slot holds another part or a torn Gear Brace.
## The Guard call must fail closed before any state, turn or RNG change.
func _gear_brace_equipment_refusal_witness(
	torso_id: String, torn_torso: bool, seed_value: int
) -> Dictionary:
	var battle := _gear_brace_battle(3, seed_value, torso_id, torn_torso)
	var walked := _gear_brace_to_back_rank(battle)
	if walked.is_empty():
		return {}
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var refusal := battle.use_part(ALTERNATES["torso"], 1)
	return {
		"battle": battle,
		"before": before,
		"rng": rng,
		"refusal": refusal,
		"after": battle.state_snapshot(),
		"actor": battle.current_actor_id(),
	}


## AC3 witness: the authentic rank-4 tier-III setup with one controlled state counterfactual in
## test memory only (like the existing Mark-erase twins): the living rank-1 Warden is marked
## lost. The Guard must refuse that empty ally rank and can never reach the living Fray
## Scavenger that holds enemy rank 1.
func _gear_brace_lost_ally_witness(seed_value: int) -> Dictionary:
	var battle := _gear_brace_battle(3, seed_value)
	var walked := _gear_brace_to_back_rank(battle)
	if walked.is_empty():
		return {}
	var warden := battle.get_unit("warden")
	if warden.is_empty() or int(warden.get("rank", 0)) != 1 or bool(warden.get("lost", false)):
		return {}
	var scavenger := battle.get_unit("fray_scavenger")
	if scavenger.is_empty() or int(scavenger.get("rank", 0)) != 1 \
			or bool(scavenger.get("dead", true)) or int(scavenger.get("hp", 0)) <= 0:
		return {}
	battle._units["warden"]["lost"] = true
	battle._units["warden"]["hp"] = 0
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var refusal := battle.use_part(ALTERNATES["torso"], 1)
	return {
		"battle": battle,
		"swap": walked["swap"],
		"before": before,
		"rng": rng,
		"refusal": refusal,
		"after": battle.state_snapshot(),
		"actor": battle.current_actor_id(),
		"scavenger_before": scavenger,
		"scavenger_after": battle.get_unit("fray_scavenger"),
	}


## AC2/AC3: tier-III Gear Brace legally Guards from real hero rank 4 after a genuine Spare
## Screws swap, is intercepted onto Tinker by a living foe's sack_swing, and replays exactly.
## Tiers I and II refuse that same rank-4 launch, and the tier-III attempts at an empty ally
## rank, the off-turn repeat, a torn torso and an unequipped torso all fail closed.
func _test_gear_brace_rank_four() -> void:
	var witness: Dictionary = {}
	var witness_seed := 0
	for seed_value in range(502000, 502080):
		witness = _gear_brace_rank_four_witness(seed_value)
		if not witness.is_empty():
			witness_seed = seed_value
			break
	_check(not witness.is_empty(),
		"AC2: real seeded rank-4 tier-III Gear Brace witness exists in the shipped 4v3 preview")
	if witness.is_empty():
		return
	var battle: StitchedRules = witness["battle"]
	var swap: Dictionary = witness["swap"]
	var cast: Dictionary = witness["cast"]
	var before: Dictionary = witness["before"]
	var after: Dictionary = witness["after"]
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 3
		and str(battle.get_unit("tinker")["parts"]["torso"]["id"]) == ALTERNATES["torso"]
		and int(battle.get_unit("tinker")["parts"]["torso"]["tier"]) == 3
		and str(battle.get_unit("tinker")["parts"]["legs"]["id"]) == ALTERNATES["legs"],
		"AC2: the witness keeps four real heroes, three foes and Tinker wearing Gear Brace plus Spare Screws")
	_check(str(swap.get("actor", "")) == "tinker" and str(swap.get("part", "")) == ALTERNATES["legs"]
		and str(swap.get("ability", "")) == "tinker_spare_screws_move"
		and int(swap["self_move"].get("from", 0)) == 3 and int(swap["self_move"].get("to", 0)) == 4
		and str(swap["self_move"].get("swapped", "")) == "lantern_monk"
		and int(battle.get_unit("tinker")["rank"]) == 4 and int(battle.get_unit("lantern_monk")["rank"]) == 3,
		"AC2: a legal Spare Screws action really swaps rank-3 Tinker behind the rank-4 Lantern Monk")
	var refusals: Array = witness["refusals"]
	var errors: Array[String] = []
	var all_refused := refusals.size() == 2
	for refusal in refusals:
		all_refused = all_refused and not bool(refusal.get("ok", false))
		errors.append(str(refusal.get("error", "")))
	_check(all_refused and errors[0].contains("rank 0") and errors[1].contains("rank 5"),
		"AC3: tier-III Gear Brace refuses ally ranks 0 and 5 before any spend")
	_check(witness["before"] == witness["after_refusals"]
		and int(witness["rng"]) == int(witness["after_refusals"].get("rng_state", -1))
		and str(witness["actor_after_refusals"]) == "tinker",
		"AC3: those refused ally ranks change no state, spend no turn and draw no seeded RNG")
	_check(str(cast.get("action", "")) == "ability" and str(cast.get("actor", "")) == "tinker"
		and str(cast.get("part", "")) == ALTERNATES["torso"]
		and str(cast.get("ability", "")) == "tinker_gear_brace_move"
		and str(cast.get("target", "")) == "warden" and not cast.has("self_move"),
		"AC2: tier-III Gear Brace casts from hero rank 4 as Tinker's own equipped torso action on Warden")
	var results: Array = cast.get("results", [])
	_check(results.size() == 1 and str(results[0].get("target", "")) == "warden"
		and str(results[0].get("target_side", "")) == "hero"
		and int(results[0].get("target_rank", 0)) == 1 and bool(results[0].get("hit", false)),
		"AC2: exactly one ally receipt names the living rank-1 Warden, never a foe")
	var guard_receipt := -1
	var guard_names := ""
	if not results.is_empty():
		for status in results[0].get("statuses", []):
			if str(status.get("status", "")) == "guard":
				guard_receipt = int(status.get("duration", 0))
				guard_names = str(status.get("guards", ""))
	_check(guard_receipt == 4 and guard_names == "warden",
		"AC2: the cast receipt carries the tier-III Guard 4 on the protected Warden")
	var tinker_after_cast: Dictionary = witness["tinker_after_cast"]
	_check(str(tinker_after_cast.get("guard_target", "")) == "warden"
		and int(tinker_after_cast.get("statuses", {}).get("guard", 0)) == 4,
		"AC2: the real Tinker holds guard_target Warden and exactly Guard 4 right after the cast")
	var tinker_after := battle.get_unit("tinker")
	_check(str(tinker_after.get("guard_target", "")) == "warden"
		and int(tinker_after.get("statuses", {}).get("guard", 0)) >= 1,
		"AC2: the Guard is still live on the real Tinker when the foe attacks, so it is turn-based")
	var warden_after := battle.get_unit("warden")
	_check(int(warden_after.get("hp", -1)) == int(witness["warden_before"].get("hp", 0)),
		"AC2: guarding costs the Warden no HP")
	var advanced_once := (int(after.get("round", -1)) == int(before.get("round", -2))
			and int(after.get("turn_index", -1)) == int(before.get("turn_index", -2)) + 1) \
		or int(after.get("round", -1)) == int(before.get("round", -2)) + 1
	_check(str(witness["actor_before"]) == "tinker" and battle.current_actor_id() != "tinker"
		and advanced_once and before != after,
		"AC2: the rank-4 Guard spends exactly one scheduled Tinker turn and changes real battle state")
	_check(not bool(witness["off_turn"].get("ok", false))
		and witness["after"] == witness["after_off_turn"]
		and int(witness["rng_after"]) == int(witness["after_off_turn"].get("rng_state", -1))
		and str(witness["actor_after_off_turn"]) != "tinker",
		"AC3: an off-turn repeat after the spent Guard refuses without any further change")
	var strike: Dictionary = witness["strike"]
	var hit: Dictionary = strike["results"][0]
	_check(str(strike.get("actor", "")) == "fray_scavenger" and str(strike.get("ability", "")) == "sack_swing",
		"AC2: a real living Fray Scavenger swings sack_swing while the Guard stands")
	_check(str(hit.get("guarded_by", "")) == "tinker" and str(hit.get("target", "")) == "tinker"
		and int(hit.get("target_rank", 0)) == 4,
		"AC2: the aimed sack_swing at Warden is redirected onto the rank-4 guardian Tinker")
	_check(int(battle.get_unit("warden")["hp"]) == int(witness["warden_before_strike"]),
		"AC2: the Warden takes none of the redirected blow")
	if bool(hit.get("hit", false)):
		_check(int(witness["tinker_before_strike"]) - int(hit.get("target_hp", -1)) == int(hit.get("damage", 0)),
			"AC2: the redirected hit lands its receipted damage on Tinker's real HP")
	var replay := _gear_brace_rank_four_witness(witness_seed)
	_check(not replay.is_empty() and replay["swap"] == swap and replay["cast"] == cast
		and replay["strike"] == strike and replay["before"] == witness["before"]
		and replay["after_refusals"] == witness["after_refusals"]
		and replay["after"] == witness["after"] and replay["after_off_turn"] == witness["after_off_turn"]
		and int(replay["rng_after_off_turn"]) == int(witness["rng_after_off_turn"])
		and int(replay["after"].get("rng_state", -1)) == int(witness["after"].get("rng_state", -2)),
		"AC3: same seed and action schedule replay the receipt, state snapshots and exact RNG")
	for tier in [1, 2]:
		var refusal_witness: Dictionary = {}
		for seed_value in range(502000, 502040):
			refusal_witness = _gear_brace_rank_four_refusal_witness(tier, seed_value)
			if not refusal_witness.is_empty():
				break
		_check(not refusal_witness.is_empty(),
			"AC3: real seeded rank-4 tier-%d Gear Brace refusal witness exists" % tier)
		if refusal_witness.is_empty():
			continue
		var refusal_battle: StitchedRules = refusal_witness["battle"]
		var refused: Dictionary = refusal_witness["cast"]
		_check(int(refusal_battle.get_unit("tinker")["rank"]) == 4
			and str(refusal_battle.get_unit("tinker")["parts"]["torso"]["id"]) == ALTERNATES["torso"]
			and int(refusal_battle.get_unit("tinker")["parts"]["torso"]["tier"]) == tier,
			"AC3: tier-%d Tinker really stands in hero rank 4 wearing Gear Brace" % tier)
		_check(not bool(refused.get("ok", false)) and str(refused.get("error", "")).contains("rank 4"),
			"AC3: tier-%d Gear Brace refuses the rank-4 launch itself (error names rank 4)" % tier)
		_check(refusal_witness["before"] == refusal_witness["after"]
			and int(refusal_witness["rng"]) == int(refusal_witness["after"].get("rng_state", -1))
			and str(refusal_witness["actor_after"]) == "tinker"
			and str(refusal_witness["actor_before"]) == "tinker",
			"AC3: tier-%d refused rank-4 cast changes no snapshot, actor or seeded RNG" % tier)
	var lost: Dictionary = {}
	for seed_value in range(502000, 502040):
		lost = _gear_brace_lost_ally_witness(seed_value)
		if not lost.is_empty():
			break
	_check(not lost.is_empty(), "AC3: real seeded rank-4 tier-III witness with an empty ally rank exists")
	if not lost.is_empty():
		var lost_battle: StitchedRules = lost["battle"]
		var lost_refusal: Dictionary = lost["refusal"]
		_check(int(lost_battle.get_unit("tinker")["rank"]) == 4
			and bool(lost_battle.get_unit("warden").get("lost", false)),
			"AC3: the rank-4 Tinker faces a genuinely emptied ally rank 1")
		_check(not bool(lost_refusal.get("ok", false))
			and str(lost_refusal.get("error", "")).contains("no legal target in rank 1"),
			"AC3: tier-III Gear Brace refuses the dead ally's rank 1 for lack of a living ally")
		_check(lost["before"] == lost["after"]
			and int(lost["rng"]) == int(lost["after"].get("rng_state", -1))
			and str(lost["actor"]) == "tinker",
			"AC3: the empty-ally refusal changes no state, spend or seeded RNG")
		_check(int(lost["scavenger_after"].get("hp", -1)) == int(lost["scavenger_before"].get("hp", -2))
			and int(lost["scavenger_after"].get("rank", 0)) == 1
			and not bool(lost["scavenger_after"].get("dead", true)),
			"AC3: the ally-side Guard never reaches across the line to the living rank-1 foe")
	var bare: Dictionary = {}
	for seed_value in range(502000, 502020):
		bare = _gear_brace_equipment_refusal_witness(STARTERS["torso"], false, seed_value)
		if not bare.is_empty():
			break
	_check(not bare.is_empty(), "AC3: the unequipped-torso witness reaches a real rank-4 Tinker turn")
	if not bare.is_empty():
		_check(not bool(bare["refusal"].get("ok", false))
			and str(bare["refusal"].get("error", "")).contains("not equipped")
			and bare["before"] == bare["after"]
			and int(bare["rng"]) == int(bare["after"].get("rng_state", -1))
			and str(bare["actor"]) == "tinker",
			"AC3: gear brace refuses from rank 4 while its torso slot holds Casing Ward, with no spend")
	var torn: Dictionary = {}
	for seed_value in range(502000, 502020):
		torn = _gear_brace_equipment_refusal_witness("", true, seed_value)
		if not torn.is_empty():
			break
	_check(not torn.is_empty(), "AC3: the torn-torso witness reaches a real rank-4 Tinker turn")
	if not torn.is_empty():
		_check(not bool(torn["refusal"].get("ok", false))
			and str(torn["refusal"].get("error", "")).contains("torn")
			and torn["before"] == torn["after"]
			and int(torn["rng"]) == int(torn["after"].get("rng_state", -1))
			and str(torn["actor"]) == "tinker",
			"AC3: a torn Gear Brace refuses from rank 4 without state, turn or RNG change")


## AC2 witness: the real shipped preview with only the existing Moth Scribe moved to enemy
## rank 4 in test memory. Tinker's scheduled Cog Shot Marks her, and on Tinker's next
## scheduled turn the equipped Overload punishes that Mark. The unmarked twin performs the
## identical Cog Shot and then loses only the Moth Scribe's Mark, so both keep equal RNG and
## the same hit/crit rolls. Returns {} unless every precondition and both landed hits hold.
func _rear_mark_overload_witness(tier: int, seed_value: int) -> Dictionary:
	var marked_battle := _rear_foe_battle(tier, seed_value, {}, {"id": ALTERNATES["arms"], "tier": tier})
	var unmarked_battle := _rear_foe_battle(tier, seed_value, {}, {"id": ALTERNATES["arms"], "tier": tier})
	if marked_battle == null or unmarked_battle == null:
		return {}
	if not _to(marked_battle, "tinker") or not _to(unmarked_battle, "tinker"):
		return {}
	if int(marked_battle.get_unit("tinker")["rank"]) != 3 or int(unmarked_battle.get_unit("tinker")["rank"]) != 3:
		return {}
	if str(marked_battle.get_unit("tinker")["parts"]["head"]["id"]) != STARTERS["head"]:
		return {}
	if str(marked_battle.get_unit("tinker")["parts"]["arms"]["id"]) != ALTERNATES["arms"]:
		return {}
	var marked_cog := marked_battle.use_part(STARTERS["head"], 4)
	var plain_cog := unmarked_battle.use_part(STARTERS["head"], 4)
	if marked_cog != plain_cog or not bool(marked_cog.get("ok", false)):
		return {}
	var cog_results: Array = marked_cog.get("results", [])
	if cog_results.size() != 1 or str(cog_results[0].get("target", "")) != "moth_scribe" \
			or int(cog_results[0].get("target_rank", 0)) != 4 or not bool(cog_results[0].get("hit", false)):
		return {}
	var moth_before := marked_battle.get_unit("moth_scribe")
	if bool(moth_before.get("dead", true)) or int(moth_before.get("statuses", {}).get("mark", 0)) <= 0:
		return {}
	# Controlled counterfactual: the twin keeps identical HP/turn/RNG but loses only that Mark.
	unmarked_battle._units["moth_scribe"]["statuses"].erase("mark")
	if not _to(marked_battle, "tinker") or not _to(unmarked_battle, "tinker"):
		return {}
	if marked_battle.is_over() or unmarked_battle.is_over():
		return {}
	if int(marked_battle.get_unit("tinker")["rank"]) != 3 or int(unmarked_battle.get_unit("tinker")["rank"]) != 3:
		return {}
	if int(marked_battle.get_unit("moth_scribe")["statuses"].get("mark", 0)) <= 0:
		return {}
	if int(unmarked_battle.get_unit("moth_scribe")["statuses"].get("mark", 0)) != 0:
		return {}
	var rng_before := marked_battle.rng_state()
	var unmarked_rng_before := unmarked_battle.rng_state()
	if rng_before != unmarked_rng_before:
		return {}
	var turn_before := marked_battle.current_actor_id()
	if turn_before != "tinker":
		return {}
	var other_hp: Dictionary = {}
	for foe_id in ["fray_scavenger", "scissor_crab"]:
		other_hp[foe_id] = int(marked_battle.get_unit(foe_id).get("hp", 0))
	var charged := marked_battle.use_part(ALTERNATES["arms"], 4)
	var plain := unmarked_battle.use_part(ALTERNATES["arms"], 4)
	if not bool(charged.get("ok", false)) or not bool(plain.get("ok", false)):
		return {}
	var charged_results: Array = charged.get("results", [])
	var plain_results: Array = plain.get("results", [])
	if charged_results.size() != 1 or plain_results.size() != 1:
		return {}
	var charged_hit: Dictionary = charged_results[0]
	var plain_hit: Dictionary = plain_results[0]
	if str(charged_hit.get("target", "")) != "moth_scribe" or int(charged_hit.get("target_rank", 0)) != 4:
		return {}
	if str(plain_hit.get("target", "")) != "moth_scribe" or int(plain_hit.get("target_rank", 0)) != 4:
		return {}
	if not bool(charged_hit.get("hit", false)) or not bool(plain_hit.get("hit", false)):
		return {}
	if int(charged_hit.get("roll", 0)) != int(plain_hit.get("roll", -1)) \
			or bool(charged_hit.get("crit", false)) != bool(plain_hit.get("crit", false)):
		return {}
	if int(charged_hit.get("damage", 0)) <= int(plain_hit.get("damage", 0)):
		return {}
	var moth_after := marked_battle.get_unit("moth_scribe")
	if bool(moth_after.get("dead", true)):
		return {}
	if int(moth_after.get("hp", -1)) != int(moth_before.get("hp", 0)) - int(charged_hit.get("damage", 0)):
		return {}
	if int(charged_hit.get("target_hp", -1)) != int(moth_after.get("hp", -2)):
		return {}
	if marked_battle.rng_state() != unmarked_battle.rng_state():
		return {}
	return {
		"marked": marked_battle,
		"unmarked": unmarked_battle,
		"marked_cog": marked_cog,
		"plain_cog": plain_cog,
		"charged": charged,
		"plain": plain,
		"charged_hit": charged_hit,
		"plain_hit": plain_hit,
		"moth_before": moth_before,
		"moth_after": moth_after,
		"other_hp": other_hp,
		"turn_before": turn_before,
		"rng_before": rng_before,
		"unmarked_rng_before": unmarked_rng_before,
		"rng_after": marked_battle.rng_state(),
		"unmarked_rng_after": unmarked_battle.rng_state(),
		"marked_snapshot": marked_battle.state_snapshot(),
		"unmarked_snapshot": unmarked_battle.state_snapshot(),
		"actor_after": marked_battle.current_actor_id(),
	}


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
	# AC2: the same real Mark follow-up now works on the occupied fourth-rank foe. The shipped
	# preview keeps its three foes; only the existing Moth Scribe moves to rank 4 in memory.
	var rear: Dictionary = {}
	var rear_seed := 0
	for seed_value in range(499900, 500100):
		rear = _rear_mark_overload_witness(2, seed_value)
		if not rear.is_empty():
			rear_seed = seed_value
			break
	_check(not rear.is_empty(), "AC2: real seeded rank-4 Cog Shot then Overload witness exists at tier II")
	if rear.is_empty():
		return
	var marked_battle: StitchedRules = rear["marked"]
	var unmarked_battle: StitchedRules = rear["unmarked"]
	var marked_cog: Dictionary = rear["marked_cog"]
	var moth_before: Dictionary = rear["moth_before"]
	var charged: Dictionary = rear["charged"]
	var plain: Dictionary = rear["plain"]
	var charged_hit: Dictionary = rear["charged_hit"]
	var plain_hit: Dictionary = rear["plain_hit"]
	var foes: Array = marked_battle.get_foes()
	var cog_mark := -1
	for status in marked_cog.get("results", [{}])[0].get("statuses", []):
		if str(status.get("status", "")) == "mark":
			cog_mark = int(status.get("duration", -1))
	_check(marked_battle.get_heroes().size() == 4 and foes.size() == 3
		and int(marked_battle.get_unit("moth_scribe")["rank"]) == 4
		and int(marked_battle.get_unit("fray_scavenger")["rank"]) == 1
		and int(marked_battle.get_unit("scissor_crab")["rank"]) == 2
		and foes.filter(func(foe): return int(foe["rank"]) == 4).size() == 1
		and foes.all(func(foe): return int(foe["rank"]) != 3),
		"AC2: tier II witness keeps four heroes and three foes, with only the Moth Scribe in rank 4")
	_check(str(marked_cog.get("action", "")) == "ability" and str(marked_cog.get("actor", "")) == "tinker"
		and str(marked_cog.get("part", "")) == STARTERS["head"] and str(marked_cog.get("ability", "")) == "tinker_cog_shot_move"
		and marked_cog.get("results", []).size() == 1
		and str(marked_cog["results"][0].get("target", "")) == "moth_scribe"
		and int(marked_cog["results"][0].get("target_rank", 0)) == 4
		and bool(marked_cog["results"][0].get("hit", false))
		and cog_mark == 3 and int(moth_before.get("statuses", {}).get("mark", 0)) > 0,
		"AC2: scheduled Cog Shot marks the occupied rank-4 Moth Scribe")
	_check(marked_cog == rear["plain_cog"], "AC2: the unmarked twin's Cog Shot receipt is identical")
	_check(str(rear["turn_before"]) == "tinker" and str(rear["actor_after"]) != "tinker"
		and int(marked_battle.get_unit("tinker")["rank"]) == 3,
		"AC2: the rank-4 Overload spends Tinker's next genuine scheduled turn from hero rank 3")
	_check(str(charged.get("action", "")) == "ability" and str(charged.get("actor", "")) == "tinker"
		and str(charged.get("part", "")) == ALTERNATES["arms"] and str(charged.get("ability", "")) == "tinker_overload_move",
		"AC2: Overload executes as Tinker's own equipped arms action on the rank-4 foe")
	_check(charged.get("results", []).size() == 1 and str(charged_hit.get("target", "")) == "moth_scribe"
		and str(charged_hit.get("target_side", "")) == "foe" and int(charged_hit.get("target_rank", 0)) == 4
		and bool(charged_hit.get("hit", false)) and int(charged_hit.get("damage", 0)) > 0,
		"AC2: the seeded rank-4 Overload lands exactly one Moth Scribe hit receipt")
	var moth_after: Dictionary = rear["moth_after"]
	_check(int(moth_after.get("hp", -1)) == int(moth_before.get("hp", 0)) - int(charged_hit.get("damage", 0))
		and int(charged_hit.get("target_hp", -1)) == int(moth_after.get("hp", -2)),
		"AC2: the real Moth Scribe loses exactly the receipted rank-4 Overload damage")
	var untouched := true
	for foe_id in rear["other_hp"]:
		untouched = untouched and int(marked_battle.get_unit(foe_id).get("hp", -1)) == int(rear["other_hp"][foe_id])
	_check(untouched, "AC2: the rank-4 Overload never damages the two front foes")
	var tinker_statuses: Dictionary = marked_battle.get_unit("tinker")["statuses"]
	var moth_statuses: Dictionary = marked_battle.get_unit("moth_scribe")["statuses"]
	_check(int(tinker_statuses.get("weak", 0)) == 0 and int(moth_statuses.get("exposed", 0)) == 0
		and int(moth_statuses.get("tangled", 0)) == 0 and int(marked_battle.get_unit("moth_scribe")["prot"]) == 0,
		"AC2: no other damage modifier is active, so the tier-II Mark bonus is the whole advantage")
	_check(int(charged_hit.get("damage", 0)) - int(plain_hit.get("damage", 0)) == 4
		and int(_catalog()["by_id"][ALTERNATES["arms"]]["tiers"]["2"]["ability"]["mark_damage"]) == 4,
		"AC2: the marked copy deals exactly the authored tier-II Mark bonus 4 more than its twin")
	_check(int(charged_hit.get("roll", 0)) == int(plain_hit.get("roll", -1))
		and bool(charged_hit.get("crit", false)) == bool(plain_hit.get("crit", false))
		and int(rear["rng_before"]) == int(rear["unmarked_rng_before"])
		and int(rear["rng_after"]) == int(rear["unmarked_rng_after"]),
		"AC2: marked and unmarked casts start from equal RNG and use equal hit/crit rolls")
	var replay := _rear_mark_overload_witness(2, rear_seed)
	_check(not replay.is_empty(), "AC3: the rank-4 Mark/Overload witness replays at seed %d" % rear_seed)
	if not replay.is_empty():
		_check(replay["marked_cog"] == marked_cog and replay["charged"] == charged and replay["plain"] == plain
			and replay["moth_after"] == moth_after and replay["marked_snapshot"] == rear["marked_snapshot"]
			and replay["unmarked_snapshot"] == rear["unmarked_snapshot"]
			and int(replay["rng_after"]) == int(rear["rng_after"])
			and str(replay["actor_after"]) == str(rear["actor_after"]),
			"AC3: equal-seed replay reproduces both receipts, both HP states, turns and exact RNG")


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


## AC1: the authored Spring Clamp part, resolved through the catalog parser at all three stitch
## tiers. Tier I stays a Weak-only clamp; tiers II/III carry the whole effects dictionary the
## parser replaces, so both Weak and Mark must be authored there. Every other number, rank,
## stat, pose and the other seven Tinker entries stay as shipped.
func _test_spring_clamp_catalog() -> void:
	var accepted := _catalog()
	_check(bool(accepted.get("ok", false)), "AC1: StitchedParts.load_catalog accepts the revised Tinker catalog")
	if not bool(accepted.get("ok", false)):
		return
	for expected_id in ALL_IDS:
		_check(accepted["by_id"].has(expected_id), "AC1: revised catalog still carries " + expected_id)
	var slot_counts := {"head": 0, "arms": 0, "torso": 0, "legs": 0}
	for raw_part in accepted["parts"]:
		var counted: Dictionary = raw_part
		if slot_counts.has(str(counted["slot"])):
			slot_counts[str(counted["slot"])] = int(slot_counts[str(counted["slot"])]) + 1
	for slot in slot_counts:
		_check(int(slot_counts[slot]) == 2, "AC1: Tinker still offers two choices in the " + slot + " slot")
	var clamp_part: Dictionary = accepted["by_id"].get(ALTERNATES["head"], {})
	_check(not clamp_part.is_empty(), "AC1: Spring Clamp remains in the Tinker catalog")
	if clamp_part.is_empty():
		return
	_check(str(clamp_part["name"]) == "Spring Clamp" and str(clamp_part["slot"]) == "head"
		and str(clamp_part["owner"]) == "tinker" and clamp_part["stat"] == {"crit": 4},
		"AC1: Spring Clamp stays Tinker's crit +4 HEAD part")
	_check(str(clamp_part["text"]).contains("Weak") and str(clamp_part["text"]).contains("Mark")
		and str(clamp_part["text"]) != "Clamp an enemy's seam and leave it Weak.",
		"AC1: Spring Clamp's short text now distinguishes the tier-I Weak clamp from the upgraded Weak-plus-Mark clamp")
	var expected_effects := [{"weak": 2}, {"weak": 2, "mark": 1}, {"weak": 2, "mark": 2}]
	var expected_weak := [2, 2, 2]
	var expected_mark := [0, 1, 2]
	var expected_acc := [90, 90, 94]
	var expected_dmg := [[3, 5], [4, 7], [5, 9]]
	for tier in [1, 2, 3]:
		var ability := StitchedParts.ability_at_tier(clamp_part, tier)
		_check(str(ability["id"]) == "tinker_spring_clamp_move" and str(ability["name"]) == "Spring Clamp"
			and str(ability["kind"]) == "ranged" and str(ability["target_side"]) == "enemy"
			and not bool(ability["multi"]),
			"AC1: tier %d Spring Clamp stays a single-target ranged enemy ability" % tier)
		_check(ability["launch"] == [2, 3] and int(ability["launch_mask"]) == StitchedParts.rank_mask([2, 3])
			and ability["target"] == [1, 2, 3]
			and int(ability["target_mask"]) == StitchedParts.rank_mask([1, 2, 3]),
			"AC1: tier %d Spring Clamp launches from hero ranks 2-3 at enemy ranks 1-3" % tier)
		_check(int(ability["acc"]) == int(expected_acc[tier - 1]) and ability["dmg"] == expected_dmg[tier - 1]
			and int(ability["crit"]) == 0 and int(ability["mark_damage"]) == 0
			and int(ability["self_move"]) == 0 and str(ability["move"]) == "attack",
			"AC1: tier %d Spring Clamp keeps ACC/damage/crit/mark_damage/self_move/attack pose" % tier)
		_check(ability["effects"] == expected_effects[tier - 1],
			"AC1: tier %d Spring Clamp resolves its complete effects dictionary" % tier)
		_check(int(ability["effects"].get("weak", 0)) == int(expected_weak[tier - 1])
			and int(ability["effects"].get("mark", 0)) == int(expected_mark[tier - 1]),
			"AC1: tier %d Spring Clamp Weak ladder is 2/2/2 and Mark ladder is 0/1/2" % tier)
		_check(int(StitchedParts.stat_at_tier(clamp_part, tier).get("crit", 0)) == 4,
			"AC1: tier %d Spring Clamp head stat stays crit +4" % tier)
	for other_id in ALL_IDS:
		if other_id == ALTERNATES["head"]:
			continue
		var other: Dictionary = accepted["by_id"][other_id]
		for tier in [1, 2, 3]:
			_check(bool(StitchedParts.validate_ability(StitchedParts.ability_at_tier(other, tier)).get("ok", false)),
				"AC1: unchanged %s still resolves to a legal tier-%d ability" % [other_id, tier])
	var overload_part: Dictionary = accepted["by_id"].get(ALTERNATES["arms"], {})
	for tier in [1, 2, 3]:
		_check(not overload_part.is_empty()
			and int(StitchedParts.ability_at_tier(overload_part, tier)["mark_damage"]) == [3, 4, 5][tier - 1]
			and int(StitchedParts.ability_at_tier(overload_part, tier)["effects"].size()) == 0,
			"AC3: tier %d Overload still authors only its 3/4/5 Mark bonus and no on-hit effects" % tier)


## Reads one receipt's duration for a named status (-1 when it is absent).
func _receipt_status(receipt: Dictionary, key: String) -> int:
	for status in receipt.get("statuses", []):
		if str(status.get("status", "")) == key:
			return int(status.get("duration", 0))
	return -1


## The shipped S2 preview with genuine four heroes and three foes where Tinker really wears the
## alternate Spring Clamp head AND the alternate Overload arms at the same stitch tier. The
## preview file itself is never edited; only Tinker's equipped IDs change.
func _clamp_overload_battle(tier: int, seed_value: int, torn_head: bool = false) -> StitchedRules:
	var config := _config(ALTERNATES["head"], tier, seed_value)
	if config.is_empty():
		return null
	config["heroes"][2]["parts"]["arms"] = {"id": ALTERNATES["arms"], "tier": tier}
	if torn_head:
		config["heroes"][2]["parts"]["head"]["torn"] = true
	var result := StitchedRules.create(config)
	if not bool(result.get("ok", false)):
		return null
	return result["battle"] as StitchedRules


## AC2 witness: rank-3 Tinker, wearing both alternate parts, takes a real scheduled turn in the
## seeded preview and clamps exactly one living foe at the requested enemy rank. Returns {} when
## the fixture or action is not exactly that legal real path.
func _clamp_cast(tier: int, seed_value: int, target_rank: int) -> Dictionary:
	var battle := _clamp_overload_battle(tier, seed_value)
	if battle == null or not _to(battle, "tinker"):
		return {}
	var tinker := battle.get_unit("tinker")
	if int(tinker.get("rank", 0)) != 3:
		return {}
	if str(tinker.get("parts", {}).get("head", {}).get("id", "")) != ALTERNATES["head"]:
		return {}
	if str(tinker.get("parts", {}).get("arms", {}).get("id", "")) != ALTERNATES["arms"]:
		return {}
	if battle.get_heroes().size() != 4 or battle.get_foes().size() != 3:
		return {}
	var victim_id := ""
	for foe in battle.get_foes():
		if int(foe.get("rank", 0)) == target_rank and not bool(foe.get("dead", true)) \
				and int(foe.get("hp", 0)) > 0:
			victim_id = str(foe["id"])
	if victim_id.is_empty():
		return {}
	var victim_before := battle.get_unit(victim_id)
	var before := battle.state_snapshot()
	var rng_before := battle.rng_state()
	var actor_before := battle.current_actor_id()
	var shot := battle.use_part(ALTERNATES["head"], target_rank)
	if str(shot.get("action", "")) != "ability" or str(shot.get("actor", "")) != "tinker" \
			or str(shot.get("part", "")) != ALTERNATES["head"] \
			or str(shot.get("ability", "")) != "tinker_spring_clamp_move":
		return {}
	var results: Array = shot.get("results", [])
	if results.size() != 1:
		return {}
	var hit: Dictionary = results[0]
	if str(hit.get("target", "")) != victim_id or int(hit.get("target_rank", 0)) != target_rank \
			or str(hit.get("target_side", "")) != "foe":
		return {}
	return {
		"battle": battle,
		"shot": shot,
		"hit_receipt": hit,
		"victim_id": victim_id,
		"victim_before": victim_before,
		"victim_after": battle.get_unit(victim_id),
		"before": before,
		"after": battle.state_snapshot(),
		"rng_before": rng_before,
		"rng_after": battle.rng_state(),
		"actor_before": actor_before,
		"actor_after": battle.current_actor_id(),
	}


## Bounded fixed-seed search over the genuine seeded fixture for Spring Clamp casts at one tier
## and one legal enemy rank. Keeps the first landed hit and the first legal miss.
func _clamp_witnesses(tier: int, target_rank: int, limit: int = 800) -> Dictionary:
	var hit: Dictionary = {}
	var miss: Dictionary = {}
	for seed_value in range(501000, 501000 + limit):
		var cast := _clamp_cast(tier, seed_value, target_rank)
		if cast.is_empty():
			continue
		cast["seed"] = seed_value
		if bool(cast["hit_receipt"].get("hit", false)):
			if hit.is_empty():
				hit = cast
		elif miss.is_empty():
			miss = cast
		if not hit.is_empty() and not miss.is_empty():
			break
	return {"hit": hit, "miss": miss}


## AC2: every tier's real cast resolves through seeded combat. Tier II and III leave Weak plus
## Mark on the one foe they hit, tier I leaves only Weak, a legal miss leaves neither, and the
## same seed/config/action replays the receipt, snapshot and RNG exactly.
func _test_spring_clamp_mark_setup() -> void:
	var expected := {1: {"weak": 2, "mark": 0}, 2: {"weak": 2, "mark": 1}, 3: {"weak": 2, "mark": 2}}
	var found := {}
	for tier in [1, 2, 3]:
		found[tier] = _clamp_witnesses(tier, 3)
		var witness: Dictionary = found[tier]["hit"]
		_check(not witness.is_empty(), "AC2: bounded fixed-seed tier %d Spring Clamp hit witness exists" % tier)
		if witness.is_empty():
			continue
		var battle: StitchedRules = witness["battle"]
		var receipt: Dictionary = witness["hit_receipt"]
		var victim_before: Dictionary = witness["victim_before"]
		var victim_after: Dictionary = witness["victim_after"]
		var weak_wanted := int(expected[tier]["weak"])
		var mark_wanted := int(expected[tier]["mark"])
		_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 3
			and int(battle.get_unit("tinker")["rank"]) == 3
			and str(battle.get_unit("tinker")["parts"]["head"]["id"]) == ALTERNATES["head"]
			and str(battle.get_unit("tinker")["parts"]["arms"]["id"]) == ALTERNATES["arms"],
			"AC2: tier %d witness keeps four real heroes, three foes and rank-3 Tinker wearing both alternate parts" % tier)
		_check(str(witness["shot"].get("action", "")) == "ability"
			and str(witness["shot"].get("actor", "")) == "tinker"
			and str(witness["shot"].get("part", "")) == ALTERNATES["head"]
			and str(witness["shot"].get("ability", "")) == "tinker_spring_clamp_move",
			"AC2: tier %d Spring Clamp runs as Tinker's own equipped head action" % tier)
		_check(bool(receipt.get("hit", false)) and int(receipt.get("damage", 0)) > 0
			and int(receipt.get("target_rank", 0)) == 3
			and str(receipt.get("target_side", "")) == "foe",
			"AC2: tier %d Spring Clamp lands exactly one real hit receipt on the living rank-3 foe" % tier)
		_check(_receipt_status(receipt, "weak") == weak_wanted,
			"AC2: tier %d hit receipt carries Weak %d" % [tier, weak_wanted])
		_check(_receipt_status(receipt, "mark") == (mark_wanted if mark_wanted > 0 else -1),
			"AC2: tier %d hit receipt carries Mark %s" % [tier, "absent" if mark_wanted == 0 else str(mark_wanted)])
		_check(receipt.get("statuses", []).size() == (2 if mark_wanted > 0 else 1),
			"AC2: tier %d clamp hit writes exactly its authored status receipts" % tier)
		_check(int(victim_after.get("statuses", {}).get("weak", 0)) == weak_wanted
			and int(victim_after.get("statuses", {}).get("mark", 0)) == mark_wanted,
			"AC2: tier %d Weak %d and Mark %d persist on that same foe" % [tier, weak_wanted, mark_wanted])
		_check(int(victim_after.get("hp", -1)) == int(victim_before.get("hp", 0)) - int(receipt.get("damage", 0))
			and int(receipt.get("target_hp", -1)) == int(victim_after.get("hp", -2)),
			"AC2: tier %d real foe HP drops by the receipted clamp damage" % tier)
		_check(str(witness["actor_before"]) == "tinker" and str(witness["actor_after"]) != "tinker"
			and witness["before"] != witness["after"]
			and int(witness["rng_before"]) != int(witness["rng_after"]),
			"AC2: tier %d cast spends exactly one scheduled Tinker turn and draws seeded RNG" % tier)
		var replay := _clamp_cast(tier, int(witness["seed"]), 3)
		_check(not replay.is_empty() and replay["shot"] == witness["shot"]
			and replay["before"] == witness["before"] and replay["after"] == witness["after"]
			and int(replay["rng_after"]) == int(witness["rng_after"]),
			"AC2: tier %d equal-seed replay reproduces the receipt, state snapshot and RNG" % tier)
	var miss: Dictionary = found[2]["miss"]
	_check(not miss.is_empty(), "AC2: a bounded fixed-seed legal Spring Clamp miss exists")
	if not miss.is_empty():
		var miss_receipt: Dictionary = miss["hit_receipt"]
		var miss_victim: Dictionary = miss["victim_after"]
		_check(not bool(miss_receipt.get("hit", false)) and int(miss_receipt.get("damage", 0)) == 0
			and int(miss_receipt.get("target_hp", -1)) == int(miss["victim_before"].get("hp", -2))
			and str(miss_receipt.get("target", "")) == str(miss["victim_id"]),
			"AC2: the seeded miss reports no damage and an unchanged target HP")
		_check(miss_receipt.get("statuses", []).is_empty()
			and int(miss_victim.get("statuses", {}).get("weak", 0)) == 0
			and int(miss_victim.get("statuses", {}).get("mark", 0)) == 0,
			"AC2: a legal Spring Clamp miss applies neither Weak nor Mark")
		_check(str(miss["actor_before"]) == "tinker" and str(miss["actor_after"]) != "tinker"
			and miss["before"] != miss["after"]
			and int(miss["rng_before"]) != int(miss["rng_after"]),
			"AC2: a legal miss still spends Tinker's turn and draws seeded RNG")



## A control catalog is constructed solely for this test: tier-II Spring Clamp still has
## its real equipment, ACC, damage and Mark 1, but omits Weak. No runtime rules or shipped
## catalog are changed, and both seeded fights use StitchedRules.create/use_part.
func _spring_clamp_no_weak_control(seed_value: int) -> StitchedRules:
	var config := _config(ALTERNATES["head"], 2, seed_value)
	if config.is_empty():
		return null
	config["heroes"][2]["parts"]["arms"] = {"id": ALTERNATES["arms"], "tier": 2}
	var replaced := 0
	for index in range(config["parts"].size()):
		var part: Dictionary = config["parts"][index]
		if str(part.get("id", "")) != ALTERNATES["head"]:
			continue
		var variant: Dictionary = part.duplicate(true)
		var effects: Dictionary = variant["tiers"]["2"]["ability"]["effects"]
		if effects != {"weak": 2, "mark": 1}:
			return null
		effects.erase("weak")
		config["parts"][index] = variant
		replaced += 1
	if replaced != 1:
		return null
	var created := StitchedRules.create(config)
	if not bool(created.get("ok", false)):
		return null
	return created["battle"] as StitchedRules


## Only accept a non-vacuous, real 4v3 witness: Tinker actually lands the equipped tier-II
## clamp on the living rank-3 Moth Scribe in both fights; that foe then gets its own actual
## turn and lands Ink Flick on the same living rank-2 hero. Both attacks must consume the
## same RNG, share hit/crit outcomes, and differ in damage only because one foe has Weak 1.
## Advance to the foe's next scheduled turn to observe natural Weak expiry, without reapplying.
func _spring_clamp_foe_reply(seed_value: int) -> Dictionary:
	var weakened := _clamp_overload_battle(2, seed_value)
	var ordinary := _spring_clamp_no_weak_control(seed_value)
	if weakened == null or ordinary == null:
		return {}
	if not _to(weakened, "tinker") or not _to(ordinary, "tinker"):
		return {}
	if weakened.get_heroes().size() != 4 or weakened.get_foes().size() != 3:
		return {}
	if ordinary.get_heroes().size() != 4 or ordinary.get_foes().size() != 3:
		return {}
	var tinker := weakened.get_unit("tinker")
	var moth := weakened.get_unit("moth_scribe")
	if tinker.is_empty() or moth.is_empty():
		return {}
	if int(tinker.get("rank", 0)) != 3 or int(moth.get("rank", 0)) != 3:
		return {}
	if int(moth.get("hp", 0)) <= 0 or bool(moth.get("dead", true)):
		return {}
	if str(tinker.get("parts", {}).get("head", {}).get("id", "")) != ALTERNATES["head"]:
		return {}
	if str(tinker.get("parts", {}).get("arms", {}).get("id", "")) != ALTERNATES["arms"]:
		return {}
	if int(tinker["parts"]["head"].get("tier", 0)) != 2:
		return {}
	if ordinary.get_unit("moth_scribe") != moth:
		return {}
	if weakened.rng_state() != ordinary.rng_state():
		return {}
	var clamp := weakened.use_part(ALTERNATES["head"], 3)
	var control_clamp := ordinary.use_part(ALTERNATES["head"], 3)
	if not bool(clamp.get("ok", false)) or not bool(control_clamp.get("ok", false)):
		return {}
	if str(clamp.get("actor", "")) != "tinker" or str(clamp.get("ability", "")) != "tinker_spring_clamp_move":
		return {}
	if clamp.get("results", []).size() != 1 or control_clamp.get("results", []).size() != 1:
		return {}
	var clamp_hit: Dictionary = clamp["results"][0]
	var control_hit: Dictionary = control_clamp["results"][0]
	if not bool(clamp_hit.get("hit", false)) or not bool(control_hit.get("hit", false)):
		return {}
	if str(clamp_hit.get("target", "")) != "moth_scribe" or str(control_hit.get("target", "")) != "moth_scribe":
		return {}
	if int(clamp_hit.get("roll", -1)) != int(control_hit.get("roll", -2)):
		return {}
	if bool(clamp_hit.get("crit", false)) != bool(control_hit.get("crit", false)):
		return {}
	if int(clamp_hit.get("damage", -1)) != int(control_hit.get("damage", -2)):
		return {}
	if _receipt_status(clamp_hit, "weak") != 2 or _receipt_status(control_hit, "weak") != -1:
		return {}
	if _receipt_status(clamp_hit, "mark") != 1 or _receipt_status(control_hit, "mark") != 1:
		return {}
	var clamped_moth := weakened.get_unit("moth_scribe")
	var unclamped_moth := ordinary.get_unit("moth_scribe")
	if int(clamped_moth["statuses"].get("weak", 0)) != 2:
		return {}
	if int(unclamped_moth["statuses"].get("weak", 0)) != 0:
		return {}
	if int(clamped_moth["statuses"].get("mark", 0)) != 1 or int(unclamped_moth["statuses"].get("mark", 0)) != 1:
		return {}
	if int(clamped_moth["hp"]) != int(unclamped_moth["hp"]):
		return {}
	# If Moth starts immediately after the clamp, the live turn-start tick has
	# already reduced Weak to 1; use a seed where Weak 2 is observable at receipt.
	if weakened.current_actor_id() == "moth_scribe":
		return {}
	if weakened.current_actor_id() != ordinary.current_actor_id() or weakened.rng_state() != ordinary.rng_state():
		return {}
	if not _to(weakened, "moth_scribe") or not _to(ordinary, "moth_scribe"):
		return {}
	var weak_attacker := weakened.get_unit("moth_scribe")
	var plain_attacker := ordinary.get_unit("moth_scribe")
	var weak_hero := weakened.get_unit("seamstress")
	var plain_hero := ordinary.get_unit("seamstress")
	if weak_attacker.is_empty() or plain_attacker.is_empty() or weak_hero.is_empty() or plain_hero.is_empty():
		return {}
	if int(weak_attacker["statuses"].get("weak", 0)) != 1:
		return {}
	if int(plain_attacker["statuses"].get("weak", 0)) != 0:
		return {}
	if int(weak_attacker.get("rank", 0)) != 3 or int(plain_attacker.get("rank", 0)) != 3:
		return {}
	if int(weak_hero.get("rank", 0)) != 2 or int(plain_hero.get("rank", 0)) != 2:
		return {}
	if int(weak_hero.get("hp", 0)) <= 0 or int(plain_hero.get("hp", 0)) <= 0:
		return {}
	if weak_hero != plain_hero or int(weak_attacker["hp"]) != int(plain_attacker["hp"]):
		return {}
	if int(weak_attacker.get("dmg_bonus", 0)) != 0 or int(plain_attacker.get("dmg_bonus", 0)) != 0:
		return {}
	if weakened.rng_state() != ordinary.rng_state():
		return {}
	var abilities: Array = weak_attacker.get("abilities", [])
	if abilities.is_empty():
		return {}
	var ink: Dictionary = abilities[0]
	if str(ink.get("id", "")) != "ink_flick":
		return {}
	var strike := weakened.use_foe_ability("ink_flick", 2)
	var normal := ordinary.use_foe_ability("ink_flick", 2)
	if not bool(strike.get("ok", false)) or not bool(normal.get("ok", false)):
		return {}
	if str(strike.get("actor", "")) != "moth_scribe" or str(normal.get("actor", "")) != "moth_scribe":
		return {}
	if strike.get("results", []).size() != 1 or normal.get("results", []).size() != 1:
		return {}
	var reduced: Dictionary = strike["results"][0]
	var unreduced: Dictionary = normal["results"][0]
	if not bool(reduced.get("hit", false)) or not bool(unreduced.get("hit", false)):
		return {}
	if str(reduced.get("target", "")) != "seamstress" or str(unreduced.get("target", "")) != "seamstress":
		return {}
	if int(reduced.get("roll", -1)) != int(unreduced.get("roll", -2)):
		return {}
	if bool(reduced.get("crit", false)) != bool(unreduced.get("crit", false)):
		return {}
	if int(unreduced.get("damage", 0)) <= int(reduced.get("damage", -1)):
		return {}
	if int(reduced.get("target_hp", -1)) != int(weak_hero["hp"]) - int(reduced["damage"]):
		return {}
	if int(unreduced.get("target_hp", -1)) != int(plain_hero["hp"]) - int(unreduced["damage"]):
		return {}
	if weakened.rng_state() != ordinary.rng_state():
		return {}
	var low := int(ink["dmg"][0])
	var high := int(ink["dmg"][1])
	if bool(reduced.get("crit", false)):
		low = StitchedRules.crit_damage(high)
		high = low
	var exact_damage := false
	for base in range(low, high + 1):
		var actual_base := StitchedS1BEffects.enemy_damage(base, weakened.candle())
		var expected_weak := StitchedRules.damage_after_modifiers(
			actual_base, weak_attacker["statuses"], weak_hero["statuses"],
			false, int(ink["mark_damage"]), int(weak_hero["prot"]))
		var expected_plain := StitchedRules.damage_after_modifiers(
			actual_base, plain_attacker["statuses"], plain_hero["statuses"],
			false, int(ink["mark_damage"]), int(plain_hero["prot"]))
		if expected_weak == int(reduced["damage"]) and expected_plain == int(unreduced["damage"]):
			exact_damage = true
	if not exact_damage:
		return {}
	if not _to(weakened, "moth_scribe") or not _to(ordinary, "moth_scribe"):
		return {}
	var expiry_weak := int(weakened.get_unit("moth_scribe")["statuses"].get("weak", 0))
	var expiry_plain := int(ordinary.get_unit("moth_scribe")["statuses"].get("weak", 0))
	if expiry_weak != 0 or expiry_plain != 0 or weakened.rng_state() != ordinary.rng_state():
		return {}
	return {
		"seed": seed_value, "clamp": clamp, "control_clamp": control_clamp,
		"weak_at_reply": int(weak_attacker["statuses"]["weak"]),
		"plain_at_reply": int(plain_attacker["statuses"].get("weak", 0)),
		"strike": strike, "normal": normal, "reduced": reduced, "unreduced": unreduced,
		"expiry_weak": expiry_weak, "expiry_plain": expiry_plain,
		"rng_after": weakened.rng_state(), "rules_match": exact_damage,
	}


func _test_spring_clamp_next_foe_attack() -> void:
	var witness: Dictionary = {}
	for seed_value in range(501000, 501800):
		witness = _spring_clamp_foe_reply(seed_value)
		if not witness.is_empty():
			break
	_check(not witness.is_empty(),
		"AC2: a real seeded 4v3 Tinker clamp gives a living Moth Scribe Weak 2 before its next landed Ink Flick")
	if witness.is_empty():
		return
	_check(int(witness["weak_at_reply"]) == 1 and int(witness["plain_at_reply"]) == 0,
		"AC2: Weak 2 has ticked to Weak 1 on the actual foe attack turn; catalog-variant control has none")
	_check(int(witness["reduced"]["damage"]) < int(witness["unreduced"]["damage"])
		and int(witness["reduced"]["roll"]) == int(witness["unreduced"]["roll"])
		and bool(witness["reduced"]["crit"]) == bool(witness["unreduced"]["crit"])
		and bool(witness["rules_match"]),
		"AC2: equal-roll landed foe attacks differ by the real Weak damage rule, not RNG or target protection")
	_check(int(witness["expiry_weak"]) == 0 and int(witness["expiry_plain"]) == 0,
		"AC2: Weak expires on the foe's next natural turn, without manual status clearing")
	var replay := _spring_clamp_foe_reply(int(witness["seed"]))
	_check(not replay.is_empty() and replay == witness,
		"AC3: same seed reproduces the real Weak-versus-control clamp, foe attack, expiry and RNG")


## AC3 witness: two identical seeded battles clamp the living rank-3 Moth Scribe at tier II; the
## control then loses only the victim's Mark, keeping Weak, HP, statuses, ranks, turns and RNG.
## Both advance legally to Tinker's next scheduled turn and land Overload on that same foe.
## Returns {} unless every precondition holds, both casts land on matching rolls and the marked
## hit deals exactly the authored tier-II Mark bonus more without killing the victim.
func _clamp_overload_witness(tier: int, seed_value: int) -> Dictionary:
	var marked := _clamp_overload_battle(tier, seed_value)
	var unmarked := _clamp_overload_battle(tier, seed_value)
	if marked == null or unmarked == null:
		return {}
	if not _to(marked, "tinker") or not _to(unmarked, "tinker"):
		return {}
	if int(marked.get_unit("tinker")["rank"]) != 3 or int(unmarked.get_unit("tinker")["rank"]) != 3:
		return {}
	if str(marked.get_unit("tinker")["parts"]["head"]["id"]) != ALTERNATES["head"] \
			or str(marked.get_unit("tinker")["parts"]["arms"]["id"]) != ALTERNATES["arms"]:
		return {}
	var moth := marked.get_unit("moth_scribe")
	if moth.is_empty() or int(moth.get("rank", 0)) != 3 or bool(moth.get("dead", true)) \
			or int(moth.get("hp", 0)) <= 0:
		return {}
	var clamp_marked := marked.use_part(ALTERNATES["head"], 3)
	var clamp_plain := unmarked.use_part(ALTERNATES["head"], 3)
	if clamp_marked != clamp_plain or not bool(clamp_marked.get("ok", false)):
		return {}
	var clamp_results: Array = clamp_marked.get("results", [])
	if clamp_results.size() != 1:
		return {}
	var clamp_hit: Dictionary = clamp_results[0]
	if str(clamp_hit.get("target", "")) != "moth_scribe" or int(clamp_hit.get("target_rank", 0)) != 3 \
			or not bool(clamp_hit.get("hit", false)):
		return {}
	var clamp_ability := StitchedParts.ability_at_tier(_catalog()["by_id"][ALTERNATES["head"]], tier)
	var mark_potency := int(clamp_ability["effects"].get("mark", 0))
	var weak_potency := int(clamp_ability["effects"].get("weak", 0))
	if mark_potency <= 0 or weak_potency <= 0:
		return {}
	var moth_marked := marked.get_unit("moth_scribe")
	if int(moth_marked.get("statuses", {}).get("mark", 0)) != mark_potency \
			or int(moth_marked.get("statuses", {}).get("weak", 0)) != weak_potency:
		return {}
	# Controlled counterfactual: the twin keeps Weak, HP, statuses, ranks, turn and RNG but
	# loses only the one Mark this clamp just applied.
	unmarked._units["moth_scribe"]["statuses"].erase("mark")
	if int(unmarked.get_unit("moth_scribe")["statuses"].get("mark", 0)) != 0:
		return {}
	if int(unmarked.get_unit("moth_scribe")["statuses"].get("weak", 0)) != weak_potency \
			or int(unmarked.get_unit("moth_scribe")["hp"]) != int(moth_marked.get("hp", -1)):
		return {}
	if not _to(marked, "tinker") or not _to(unmarked, "tinker"):
		return {}
	if marked.is_over() or unmarked.is_over():
		return {}
	if marked.current_actor_id() != "tinker" or unmarked.current_actor_id() != "tinker":
		return {}
	var remaining_mark := int(marked.get_unit("moth_scribe")["statuses"].get("mark", 0))
	if remaining_mark <= 0:
		return {}
	if int(unmarked.get_unit("moth_scribe")["statuses"].get("mark", 0)) != 0:
		return {}
	if int(marked.get_unit("moth_scribe")["statuses"].get("weak", 0)) \
			!= int(unmarked.get_unit("moth_scribe")["statuses"].get("weak", 0)):
		return {}
	if marked.round_number() != unmarked.round_number():
		return {}
	var marked_snapshot := marked.state_snapshot()
	var unmarked_snapshot := unmarked.state_snapshot()
	if int(marked_snapshot.get("turn_index", -1)) != int(unmarked_snapshot.get("turn_index", -2)):
		return {}
	var rng_before := marked.rng_state()
	if rng_before != unmarked.rng_state():
		return {}
	var moth_before := marked.get_unit("moth_scribe")
	var moth_unmarked := unmarked.get_unit("moth_scribe")
	var charged := marked.use_part(ALTERNATES["arms"], 3)
	var plain := unmarked.use_part(ALTERNATES["arms"], 3)
	if not bool(charged.get("ok", false)) or not bool(plain.get("ok", false)):
		return {}
	var charged_results: Array = charged.get("results", [])
	var plain_results: Array = plain.get("results", [])
	if charged_results.size() != 1 or plain_results.size() != 1:
		return {}
	var charged_hit: Dictionary = charged_results[0]
	var plain_hit: Dictionary = plain_results[0]
	if str(charged_hit.get("target", "")) != "moth_scribe" \
			or int(charged_hit.get("target_rank", 0)) != 3:
		return {}
	if str(plain_hit.get("target", "")) != "moth_scribe" \
			or int(plain_hit.get("target_rank", 0)) != 3:
		return {}
	if not bool(charged_hit.get("hit", false)) or not bool(plain_hit.get("hit", false)):
		return {}
	if int(charged_hit.get("roll", 0)) != int(plain_hit.get("roll", -1)) \
			or bool(charged_hit.get("crit", false)) != bool(plain_hit.get("crit", false)):
		return {}
	var mark_damage := int(
		StitchedParts.ability_at_tier(_catalog()["by_id"][ALTERNATES["arms"]], tier)["mark_damage"]
	)
	if mark_damage <= 0:
		return {}
	if int(charged_hit.get("damage", 0)) - int(plain_hit.get("damage", 0)) != mark_damage:
		return {}
	if marked.rng_state() != unmarked.rng_state():
		return {}
	var moth_after := marked.get_unit("moth_scribe")
	if bool(moth_after.get("dead", true)) or int(moth_after.get("hp", 0)) <= 0:
		return {}
	if int(moth_after.get("hp", -1)) != int(moth_before.get("hp", 0)) - int(charged_hit.get("damage", 0)):
		return {}
	if int(unmarked.get_unit("moth_scribe")["hp"]) \
			!= int(moth_before.get("hp", 0)) - int(plain_hit.get("damage", 0)):
		return {}
	if int(charged_hit.get("target_hp", -1)) != int(moth_after.get("hp", -2)):
		return {}
	return {
		"marked": marked,
		"unmarked": unmarked,
		"seed": seed_value,
		"clamp_marked": clamp_marked,
		"clamp_plain": clamp_plain,
		"clamp_hit": clamp_hit,
		"moth_marked": moth_marked,
		"moth_before": moth_before,
		"moth_unmarked": moth_unmarked,
		"moth_after": moth_after,
		"mark_potency": mark_potency,
		"weak_potency": weak_potency,
		"remaining_mark": remaining_mark,
		"marked_snapshot": marked_snapshot,
		"unmarked_snapshot": unmarked_snapshot,
		"rng_before": rng_before,
		"charged": charged,
		"plain": plain,
		"charged_hit": charged_hit,
		"plain_hit": plain_hit,
		"mark_damage": mark_damage,
		"rng_after": marked.rng_state(),
	}


## AC3: the same seeded battle pays off the tier-II Spring Clamp's Mark with the already shipped
## Overload mark_damage; a twin that differs only by that Mark takes exactly the authored bonus
## less, on identical hit/crit rolls, without killing the victim and with identical later RNG.
func _test_spring_clamp_overload_payoff() -> void:
	var witness: Dictionary = {}
	var witness_seed := 0
	for seed_value in range(501000, 502400):
		witness = _clamp_overload_witness(2, seed_value)
		if not witness.is_empty():
			witness_seed = seed_value
			break
	_check(not witness.is_empty(),
		"AC3: bounded fixed-seed tier-II Spring Clamp then Overload payoff witness exists")
	if witness.is_empty():
		return
	var marked: StitchedRules = witness["marked"]
	var unmarked: StitchedRules = witness["unmarked"]
	var clamp_hit: Dictionary = witness["clamp_hit"]
	var charged_hit: Dictionary = witness["charged_hit"]
	var plain_hit: Dictionary = witness["plain_hit"]
	var moth_unmarked: Dictionary = witness["moth_unmarked"]
	_check(marked.get_heroes().size() == 4 and marked.get_foes().size() == 3
		and int(marked.get_unit("tinker")["rank"]) == 3
		and str(marked.get_unit("tinker")["parts"]["head"]["id"]) == ALTERNATES["head"]
		and str(marked.get_unit("tinker")["parts"]["arms"]["id"]) == ALTERNATES["arms"],
		"AC3: the payoff witness keeps four real heroes, three foes and rank-3 Tinker in Spring Clamp and Overload")
	_check(str(clamp_hit.get("target", "")) == "moth_scribe"
		and int(clamp_hit.get("target_rank", 0)) == 3 and bool(clamp_hit.get("hit", false))
		and int(witness["moth_marked"].get("statuses", {}).get("weak", 0)) == 2
		and int(witness["moth_marked"].get("statuses", {}).get("mark", 0)) == 1,
		"AC3: the tier-II clamp really lands Weak 2 and Mark 1 on the living Moth Scribe")
	_check(witness["clamp_marked"] == witness["clamp_plain"]
		and int(moth_unmarked.get("statuses", {}).get("weak", 0)) == 2
		and int(moth_unmarked.get("statuses", {}).get("mark", 0)) == 0
		and int(moth_unmarked.get("hp", -1)) == int(witness["moth_marked"].get("hp", -2))
		and int(moth_unmarked.get("statuses", {}).get("weak", 0))
			== int(witness["moth_marked"].get("statuses", {}).get("weak", 0))
		and int(moth_unmarked.get("rank", 0)) == int(witness["moth_marked"].get("rank", -1)),
		"AC3: the control keeps Weak, HP, rank and every other value and loses only that Mark")
	_check(str(witness["charged"].get("action", "")) == "ability"
		and str(witness["charged"].get("actor", "")) == "tinker"
		and str(witness["charged"].get("part", "")) == ALTERNATES["arms"]
		and str(witness["charged"].get("ability", "")) == "tinker_overload_move"
		and int(witness["remaining_mark"]) == 1,
		"AC3: the shipped Overload is the later genuine Tinker action on the still-Marked foe")
	_check(int(charged_hit.get("damage", 0)) - int(plain_hit.get("damage", 0)) == int(witness["mark_damage"])
		and int(witness["mark_damage"]) == 4
		and int(_catalog()["by_id"][ALTERNATES["arms"]]["tiers"]["2"]["ability"]["mark_damage"]) == 4,
		"AC3: the Marked Overload hit deals exactly the authored tier-II Mark bonus 4 more than its twin")
	_check(int(charged_hit.get("roll", 0)) == int(plain_hit.get("roll", -1))
		and bool(charged_hit.get("crit", false)) == bool(plain_hit.get("crit", false)),
		"AC3: marked and unmarked Overload casts use matching hit and crit rolls")
	_check(marked.rng_state() == unmarked.rng_state()
		and int(witness["rng_after"]) == marked.rng_state(),
		"AC3: both battles finish the payoff with identical seeded RNG")
	_check(int(charged_hit.get("damage", 0)) > int(plain_hit.get("damage", 0))
		and int(witness["moth_after"].get("hp", 0)) > 0
		and int(charged_hit.get("target_hp", -1)) == int(witness["moth_after"].get("hp", -2)),
		"AC3: the marked payoff is strictly stronger and leaves the victim alive at its receipted HP")
	var replay := _clamp_overload_witness(2, witness_seed)
	_check(not replay.is_empty(), "AC3: the Spring Clamp/Overload payoff witness replays at seed %d" % witness_seed)
	if not replay.is_empty():
		_check(replay["clamp_marked"] == witness["clamp_marked"]
			and replay["charged"] == witness["charged"] and replay["plain"] == witness["plain"]
			and replay["marked_snapshot"] == witness["marked_snapshot"]
			and replay["unmarked_snapshot"] == witness["unmarked_snapshot"]
			and int(replay["rng_after"]) == int(witness["rng_after"]),
			"AC3: equal-seed replay reproduces both clamp receipts, both Overload receipts, state and RNG")


## AC3 refusals: Spring Clamp's authored reach and equipment are enforced before any spend. A
## living rank-4 foe, a vacant legal rank, an unequipped or torn head, a non-Tinker actor, an
## already-spent turn and a genuine hero rank-1 launch are all refused without changing the
## snapshot, drawing seeded RNG, spending the turn or writing any status.
func _test_spring_clamp_refusals() -> void:
	var seed_value := 501777
	var rear := _rear_foe_battle(2, seed_value, {"id": ALTERNATES["head"], "tier": 2},
		{"id": ALTERNATES["arms"], "tier": 2})
	var rear_ready := rear != null and _to(rear, "tinker")
	_check(rear_ready, "AC3: the Spring Clamp reach/refusal witness reaches a real rank-3 Tinker turn")
	if rear_ready:
		_check(int(rear.get_unit("tinker")["rank"]) == 3
			and int(rear.get_unit("moth_scribe")["rank"]) == 4
			and rear.get_foes().all(func(foe): return int(foe["rank"]) != 3),
			"AC3: the witness really faces a living foe in rank 4 with the legal rank 3 vacant")
		var before := rear.state_snapshot()
		var rng := rear.rng_state()
		var moth_before := rear.get_unit("moth_scribe")
		var rank_four := rear.use_part(ALTERNATES["head"], 4)
		var vacant := rear.use_part(ALTERNATES["head"], 3)
		_check(not bool(rank_four.get("ok", false)) and str(rank_four.get("error", "")).contains("rank 4")
			and not bool(vacant.get("ok", false)) and str(vacant.get("error", "")).contains("rank 3"),
			"AC3: Spring Clamp refuses the out-of-reach living rank-4 foe and the vacant legal rank 3")
		_check(before == rear.state_snapshot() and rng == rear.rng_state()
			and rear.current_actor_id() == "tinker",
			"AC3: those refusals change no state, spend no turn and draw no seeded RNG")
		_check(rear.get_unit("moth_scribe") == moth_before
			and rear.get_unit("moth_scribe")["statuses"].is_empty(),
			"AC3: the refused rank-4 foe keeps its HP and an unwritten status dictionary")
		var legal := rear.use_part(ALTERNATES["head"], 1)
		_check(bool(legal.get("ok", false)) and legal.get("results", []).size() == 1
			and rear.current_actor_id() != "tinker",
			"AC3: the same real turn still legally clamps a foe reachable in rank 1")
	var bare := _battle("", 2, seed_value)
	var bare_ready := bare != null and _to(bare, "tinker")
	_check(bare_ready, "AC3: the unequipped-head witness reaches a real Tinker turn")
	if bare_ready:
		_check(str(bare.get_unit("tinker")["parts"]["head"]["id"]) == STARTERS["head"],
			"AC3: the unequipped witness really wears a different head")
		var bare_before := bare.state_snapshot()
		var bare_rng := bare.rng_state()
		var unequipped := bare.use_part(ALTERNATES["head"], 1)
		_check(not bool(unequipped.get("ok", false)) and str(unequipped.get("error", "")).contains("not equipped")
			and bare_before == bare.state_snapshot() and bare_rng == bare.rng_state()
			and bare.current_actor_id() == "tinker",
			"AC3: an unequipped Spring Clamp refuses without state, turn or RNG spend")
	var torn := _clamp_overload_battle(2, seed_value, true)
	var torn_ready := torn != null and _to(torn, "tinker")
	_check(torn_ready, "AC3: the torn-head witness reaches a real Tinker turn")
	if torn_ready:
		var torn_before := torn.state_snapshot()
		var torn_rng := torn.rng_state()
		var torn_shot := torn.use_part(ALTERNATES["head"], 1)
		_check(not bool(torn_shot.get("ok", false)) and str(torn_shot.get("error", "")).contains("torn")
			and torn_before == torn.state_snapshot() and torn_rng == torn.rng_state()
			and torn.current_actor_id() == "tinker",
			"AC3: a torn Spring Clamp refuses without state, turn or RNG spend")
	var bystander := _clamp_overload_battle(2, seed_value)
	var other_actor := ""
	if bystander != null:
		for index in range(40):
			if bystander.is_over():
				break
			var actor := bystander.current_actor_id()
			if actor != "tinker" and str(bystander.current_side()) == "hero":
				other_actor = actor
				break
			if not bool(bystander.pass_turn().get("ok", false)):
				break
	_check(not other_actor.is_empty(), "AC3: a non-Tinker hero turn exists for the wrong-actor refusal")
	if not other_actor.is_empty():
		var actor_before := bystander.state_snapshot()
		var actor_rng := bystander.rng_state()
		var wrong_actor := bystander.use_part(ALTERNATES["head"], 1)
		_check(not bool(wrong_actor.get("ok", false)) and actor_before == bystander.state_snapshot()
			and actor_rng == bystander.rng_state()
			and bystander.current_actor_id() == other_actor,
			"AC3: Spring Clamp refuses while another hero holds the turn, with no state, turn or RNG spend")
	var spent := _clamp_overload_battle(2, seed_value)
	var spent_ready := spent != null and _to(spent, "tinker")
	if spent_ready:
		spent_ready = bool(spent.use_part(ALTERNATES["head"], 1).get("ok", false))
	_check(spent_ready and spent.current_actor_id() != "tinker",
		"AC3: a real Spring Clamp cast spends the turn for the off-turn refusal")
	if spent_ready:
		var spent_before := spent.state_snapshot()
		var spent_rng := spent.rng_state()
		var off_turn := spent.use_part(ALTERNATES["head"], 1)
		_check(not bool(off_turn.get("ok", false)) and spent_before == spent.state_snapshot()
			and spent_rng == spent.rng_state() and spent.current_actor_id() != "tinker",
			"AC3: a stale Spring Clamp after the spent turn refuses without any further change")
	var front := _clamp_overload_battle(2, seed_value)
	var front_ready := front != null and _to(front, "tinker")
	if front_ready:
		var first_step := front.move(-1)
		front_ready = bool(first_step.get("ok", false)) and _to(front, "tinker")
	if front_ready:
		var second_step := front.move(-1)
		front_ready = bool(second_step.get("ok", false)) and _to(front, "tinker")
	_check(front_ready and int(front.get_unit("tinker")["rank"]) == 1,
		"AC3: genuine adjacent Tinker Moves bring her to the forbidden launch rank 1")
	if front_ready:
		var front_before := front.state_snapshot()
		var front_rng := front.rng_state()
		var front_shot := front.use_part(ALTERNATES["head"], 1)
		_check(not bool(front_shot.get("ok", false)) and str(front_shot.get("error", "")).contains("rank 1")
			and front_before == front.state_snapshot() and front_rng == front.rng_state()
			and front.current_actor_id() == "tinker",
			"AC3: Spring Clamp refuses a genuine hero rank-1 launch without state, turn or RNG spend")
