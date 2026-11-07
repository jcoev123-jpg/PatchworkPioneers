extends SceneTree
## S4 Yarn Ranger: independent native eight-part catalog, seeded four-hero / three-foe combat.
const CATALOG_PATH := "res://data/parts/yarn_ranger_parts.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const STARTERS := {
	"head": "yarn_ranger_head_needle_nock",
	"arms": "yarn_ranger_arms_wool_bolas",
	"torso": "yarn_ranger_torso_hood_knit",
	"legs": "yarn_ranger_legs_reel_thread",
}
const ALTERNATES := {
	"head": "yarn_ranger_head_needle_arrow",
	"arms": "yarn_ranger_arms_purling_barrage",
	"torso": "yarn_ranger_torso_snare_net",
	"legs": "yarn_ranger_legs_endless_skein",
}
const IDS := [
	"yarn_ranger_head_needle_nock", "yarn_ranger_arms_wool_bolas",
	"yarn_ranger_legs_reel_thread", "yarn_ranger_torso_hood_knit",
	"yarn_ranger_head_needle_arrow", "yarn_ranger_arms_purling_barrage",
	"yarn_ranger_torso_snare_net", "yarn_ranger_legs_endless_skein",
]

const HEAD_LAUNCH := [2, 3, 4]
const BOLAS_ID := "yarn_ranger_arms_wool_bolas"
const BOLAS_LAUNCH := [2, 3, 4]
const BOLAS_SPECS := {
	"dmg": [[2, 4], [3, 5], [4, 7]],
	"effects": [{"tangled": 2}, {"tangled": 3}, {"tangled": 4}],
}
const PURLING_ID := "yarn_ranger_arms_purling_barrage"
const PURLING_LAUNCH := [3, 4]
const PURLING_SPECS := {
	"dmg": [[5, 8], [7, 10], [9, 12]],
	"effects": [{"exposed": 1}, {"exposed": 2}, {"exposed": 3}],
}
const SNARE_ID := "yarn_ranger_torso_snare_net"
const SNARE_LAUNCH := [2, 3, 4]
const SNARE_SPECS := {
	"acc": [94, 97, 100],
	"effects": [{"tangled": 2}, {"tangled": 3}, {"tangled": 4}],
}
const REEL_ID := "yarn_ranger_legs_reel_thread"
const REEL_LAUNCH := [2, 3, 4]
const REEL_TARGET := [2, 3, 4]
const REEL_SPECS := {
	"acc": [94, 97, 100],
	"effects": [{"tangled": 2}, {"tangled": 3}, {"tangled": 4, "mark": 1}],
}
const HEAD_SPECS := {
	"yarn_ranger_head_needle_nock": {
		"ability": "yarn_ranger_head_needle_nock_move",
		"stat": {"acc": 3},
		"target": [1, 2, 3],
		"dmg": [[4, 6], [5, 8], [7, 10]],
		"mark_damage": [0, 0, 0],
		"effects": [{"exposed": 2}, {"exposed": 2}, {"exposed": 3}],
	},
	"yarn_ranger_head_needle_arrow": {
		"ability": "yarn_ranger_head_needle_arrow_move",
		"stat": {"crit": 3},
		"target": [1, 2, 3, 4],
		"dmg": [[5, 7], [7, 9], [9, 11]],
		"mark_damage": [2, 3, 4],
		"effects": [{"mark": 1}, {"mark": 2}, {"mark": 3}],
	},
}
const UNCHANGED_PARTS := {
	"yarn_ranger_arms_wool_bolas": {
		"launch": [2, 3, 4], "target": [1, 2, 3], "side": "enemy", "multi": false,
		"acc": 92, "dmg": [2, 4], "effects": {"tangled": 2}, "move": "attack",
		"stat": {"dmg": 1},
	},
	"yarn_ranger_legs_reel_thread": {
		"launch": [2, 3, 4], "target": [2, 3, 4], "side": "enemy", "multi": false,
		"acc": 94, "dmg": [0, 0], "effects": {"tangled": 2}, "move": "skill",
		"stat": {"speed": 1},
	},
	"yarn_ranger_torso_hood_knit": {
		"launch": [1, 2, 3], "target": [1, 2, 3, 4], "side": "ally", "multi": false,
		"acc": 100, "dmg": [0, 0], "effects": {"guard": 2}, "move": "guard",
		"stat": {"max_hp": 5, "prot": 3},
	},
	"yarn_ranger_arms_purling_barrage": {
		"launch": [3, 4], "target": [1, 2, 3], "side": "enemy", "multi": false,
		"acc": 92, "dmg": [5, 8], "effects": {"exposed": 1}, "move": "attack",
		"stat": {"dmg": 2},
	},
	"yarn_ranger_torso_snare_net": {
		"launch": [2, 3, 4], "target": [1, 2, 3], "side": "enemy", "multi": true,
		"acc": 94, "dmg": [0, 0], "effects": {"tangled": 2}, "move": "skill",
		"stat": {"prot": 5, "max_hp": 3},
	},
	"yarn_ranger_legs_endless_skein": {
		"launch": [2, 3], "target": [1, 2, 3], "side": "enemy", "multi": true,
		"acc": 94, "dmg": [3, 5], "effects": {"tangled": 2}, "move": "attack2",
		"stat": {"dodge": 4, "speed": 1},
	},
}
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_catalog()
	_test_head_launch_tiers()
	_test_arms_launch_tiers()
	_test_purling_launch_tiers()
	_test_snare_net_launch_tiers()
	_test_reel_thread_launch_tiers()
	_test_each_tier()
	_test_rank_four_head_launch()
	_test_needle_arrow_rank_four_target()
	_test_needle_arrow_premarked_bonus()
	_test_rank_four_bolas_launch()
	_test_rank_four_purling_launch()
	_test_rank_four_snare_net_launch()
	_test_rank_four_reel_thread_launch()
	_test_reel_thread_rank_four_target()
	_test_multi_tangled()
	_test_tangled_next_turn()
	_test_needle_nock_exposed_reply()
	_test_guard_interception()
	_test_invalid_and_no_spend()
	_test_replay()
	for failure in failures:
		printerr(failure)
	print("stitched_s4_yarn_ranger_parts_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _catalog() -> Dictionary:
	return StitchedParts.load_catalog(CATALOG_PATH)


## Only an in-memory S2 copy changes: replace the original rank-3 Tinker,
## preserving four heroes and all three actual preview foes. S6 owns player-facing admission.
func _config(selected: String = "", tier: int = 1, seed_value: int = 502040) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_PATH))
	if not parsed is Dictionary:
		_check(false, "S2 preview fixture must be a dictionary")
		return {}
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		_check(false, "Yarn Ranger catalog loads: " + str(cat.get("error", "")))
		return {}
	var config: Dictionary = parsed
	_check(config["heroes"].size() == 4 and config["foes"].size() == 3
		and str(config["heroes"][2]["id"]) == "tinker",
		"AC2: original S2 fixture has exactly four heroes, Tinker at rank three, and three foes")
	config["parts"].append_array(cat["parts"])
	config["seed"] = seed_value
	var ranger := {"id": "yarn_ranger", "name": "Yarn Ranger", "max_hp": 27,
		"speed": 7, "dodge": 8, "acc": 7, "prot": 0, "parts": {}}
	var gear: Dictionary = {}
	for slot in STARTERS:
		var part_id: String = STARTERS[slot]
		if not selected.is_empty() and cat["by_id"].has(selected) and str(cat["by_id"][selected]["slot"]) == slot:
			part_id = selected
		gear[slot] = {"id": part_id, "tier": tier}
	ranger["parts"] = gear
	config["heroes"][2] = ranger
	return config


func _battle(selected: String = "", tier: int = 1, seed_value: int = 502040) -> StitchedRules:
	var config := _config(selected, tier, seed_value)
	if config.is_empty():
		return null
	var created := StitchedRules.create(config)
	_check(bool(created.get("ok", false)), "AC2: native seeded battle accepts Ranger gear: " + str(created.get("error", "")))
	if not bool(created.get("ok", false)):
		return null
	var b: StitchedRules = created["battle"]
	var ranger := b.get_unit("yarn_ranger")
	_check(b.get_heroes().size() == 4 and b.get_foes().size() == 3 and int(ranger.get("rank", 0)) == 3
		and ranger.get("parts", {}).size() == 4,
		"AC2: real four-hero/three-foe combat equips four Ranger parts at rank 3")
	return b


func _to(b: StitchedRules, actor_id: String, limit: int = 55) -> bool:
	for _step in range(limit):
		if b.is_over():
			return false
		if b.current_actor_id() == actor_id:
			return true
		if not bool(b.pass_turn().get("ok", false)):
			return false
	return false


## A fresh in-memory copy of the same four-hero / three-foe S2 fixture, with the equipped
## Ranger taken out of rank three and appended at hero rank four. S6 owns live admission.
func _rank_four_config(selected_part: String, tier: int = 1, seed_value: int = 504040) -> Dictionary:
	var config := _config(selected_part, tier, seed_value)
	if config.is_empty():
		return {}
	var ranger: Dictionary = config["heroes"].pop_at(2)
	config["heroes"].append(ranger)
	return config


func _rank_four_battle(selected_part: String, tier: int = 1, seed_value: int = 504040) -> StitchedRules:
	var config := _rank_four_config(selected_part, tier, seed_value)
	if config.is_empty():
		return null
	var created := StitchedRules.create(config)
	if not bool(created.get("ok", false)):
		return null
	var battle: StitchedRules = created["battle"]
	return battle


## A fresh in-memory copy of the same fixture with the equipped Ranger moved to hero rank one.
func _rank_one_battle(selected_part: String = "", tier: int = 1, seed_value: int = 505040) -> StitchedRules:
	var config := _config(selected_part, tier, seed_value)
	if config.is_empty():
		return null
	var ranger: Dictionary = config["heroes"].pop_at(2)
	config["heroes"].insert(0, ranger)
	var created := StitchedRules.create(config)
	if not bool(created.get("ok", false)):
		return null
	var battle: StitchedRules = created["battle"]
	return battle


## A fresh in-memory copy of the same fixture with the equipped Ranger moved to hero rank two.
func _rank_two_battle(selected_part: String, tier: int = 1, seed_value: int = 505040) -> StitchedRules:
	var config := _config(selected_part, tier, seed_value)
	if config.is_empty():
		return null
	var ranger: Dictionary = config["heroes"].pop_at(2)
	config["heroes"].insert(1, ranger)
	var created := StitchedRules.create(config)
	if not bool(created.get("ok", false)):
		return null
	var battle: StitchedRules = created["battle"]
	return battle


## A fresh in-memory copy of the same four-hero / three-foe S2 fixture with one real foe
## standing in enemy rank four. The battle still opens with exactly three foes and is created
## through the ordinary StitchedRules path; only the in-memory rank slot changes. S6 owns
## player-facing admission of any extra rank, so this fixture never asks for four starting foes.
func _rank_four_foe_battle(selected_part: String, tier: int = 1, seed_value: int = 507040) -> StitchedRules:
	var config := _config(selected_part, tier, seed_value)
	if config.is_empty():
		return null
	var created := StitchedRules.create(config)
	if not bool(created.get("ok", false)):
		return null
	var battle: StitchedRules = created["battle"]
	if battle.get_unit("moth_scribe").is_empty():
		return null
	battle._units["moth_scribe"]["rank"] = 4
	return battle


## The same fresh three-foe fixture with the equipped Ranger at hero rank one and one real foe
## moved into enemy rank four. Her HEAD launch mask must refuse the shot even though a living
## rear-rank target now exists.
func _front_rank_four_foe_battle(
		selected_part: String, tier: int = 1, seed_value: int = 508040) -> StitchedRules:
	var battle := _rank_one_battle(selected_part, tier, seed_value)
	if battle == null:
		return null
	if battle.get_unit("moth_scribe").is_empty():
		return null
	battle._units["moth_scribe"]["rank"] = 4
	return battle


## Both needle-bow HEAD abilities keep their authored numbers at every tier while the launch
## mask gains hero rank four. Needle Nock still stops at enemy rank three; only Needle Arrow
## admits a fourth-rank foe. Ranks 1, 0 and 5 stay illegal launches.
func _test_head_launch_tiers() -> void:
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		return
	for head_id in HEAD_SPECS:
		var part: Dictionary = cat["by_id"][head_id]
		var spec: Dictionary = HEAD_SPECS[head_id]
		for tier in [1, 2, 3]:
			var ability := StitchedParts.ability_at_tier(part, tier)
			var mask := int(ability["launch_mask"])
			var reachable := true
			for rank in HEAD_LAUNCH:
				reachable = reachable and StitchedParts.ranks_allowed(mask, rank)
			var excluded := true
			for rank in [0, 1, 5]:
				excluded = excluded and not StitchedParts.ranks_allowed(mask, rank)
			_check(ability["launch"] == HEAD_LAUNCH
				and mask == StitchedParts.rank_mask(HEAD_LAUNCH) and reachable and excluded,
				"AC2: tier %d %s launch mask allows 2,3,4 and refuses 0,1,5" % [tier, head_id])
			var target_mask := int(ability["target_mask"])
			var targets_reachable := true
			for rank in spec["target"]:
				targets_reachable = targets_reachable and StitchedParts.ranks_allowed(
					target_mask, rank)
			_check(targets_reachable
				and target_mask == StitchedParts.rank_mask(spec["target"])
				and not StitchedParts.ranks_allowed(target_mask, 0)
				and not StitchedParts.ranks_allowed(target_mask, 5),
				"AC1: tier %d %s target mask covers exactly its authored enemy ranks %s"
					% [tier, head_id, str(spec["target"])])
			_check(StitchedParts.ranks_allowed(target_mask, 4) == (head_id == ALTERNATES["head"]),
				"AC1: tier %d %s %s enemy rank four" % [tier, head_id,
					"reaches" if head_id == ALTERNATES["head"] else "refuses"])
			_check(ability["dmg"] == spec["dmg"][tier - 1]
				and ability["effects"] == spec["effects"][tier - 1]
				and int(ability["acc"]) == 93 and ability["target"] == spec["target"],
				"AC2: tier %d %s keeps authored damage, status, ACC and enemy targets"
					% [tier, head_id])
			_check(StitchedParts.stat_at_tier(part, tier) == spec["stat"]
				and str(ability["id"]) == str(spec["ability"])
				and str(ability["kind"]) == "ranged"
				and str(ability["target_side"]) == "enemy" and not bool(ability["multi"])
				and int(ability["crit"]) == 0
				and int(ability["self_move"]) == 0 and str(ability["move"]) == "attack2",
				"AC4: tier %d %s keeps its authored stat, ranged single-target attack, no self move and attack2 pose"
					% [tier, head_id])
			_check(int(ability.get("mark_damage", -1)) == int(spec["mark_damage"][tier - 1]),
				"AC1: tier %d %s carries the authored mark_damage %d"
					% [tier, head_id, int(spec["mark_damage"][tier - 1])])


## Wool Bolas keeps its single-target authored numbers at every tier while its launch mask
## gains hero rank four. Ranks 1, 0 and 5 stay illegal launches.
func _test_arms_launch_tiers() -> void:
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		return
	var part: Dictionary = cat["by_id"][BOLAS_ID]
	for tier in [1, 2, 3]:
		var ability := StitchedParts.ability_at_tier(part, tier)
		var mask := int(ability["launch_mask"])
		var reachable := true
		for rank in BOLAS_LAUNCH:
			reachable = reachable and StitchedParts.ranks_allowed(mask, rank)
		var excluded := true
		for rank in [0, 1, 5]:
			excluded = excluded and not StitchedParts.ranks_allowed(mask, rank)
		_check(ability["launch"] == BOLAS_LAUNCH
			and mask == StitchedParts.rank_mask(BOLAS_LAUNCH) and reachable and excluded,
			"AC1: tier %d Wool Bolas launch mask allows 2,3,4 and refuses 0,1,5" % tier)
		_check(ability["target"] == [1, 2, 3]
			and int(ability["target_mask"]) == StitchedParts.rank_mask([1, 2, 3])
			and str(ability["target_side"]) == "enemy" and not bool(ability["multi"])
			and int(ability["acc"]) == 92 and int(ability["crit"]) == 0,
			"AC1: tier %d Wool Bolas stays a single-target enemy 1-3 attack" % tier)
		_check(ability["dmg"] == BOLAS_SPECS["dmg"][tier - 1]
			and ability["effects"] == BOLAS_SPECS["effects"][tier - 1]
			and str(ability["move"]) == "attack" and int(ability["self_move"]) == 0,
			"AC1: tier %d Wool Bolas keeps authored damage, Tangled and pose" % tier)


## Purling Barrage keeps its authored single-target numbers at every tier while its launch
## mask gains hero rank four. Rank two stays illegal, and enemy reach stays ranks 1-3.
func _test_purling_launch_tiers() -> void:
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		return
	var part: Dictionary = cat["by_id"][PURLING_ID]
	_check(str(part["slot"]) == "arms" and str(part["owner"]) == "yarn_ranger"
		and part["stat"] == {"dmg": 2},
		"AC1: Purling Barrage stays a Yarn Ranger arms part with its authored dmg stat")
	for tier in [1, 2, 3]:
		var ability := StitchedParts.ability_at_tier(part, tier)
		var mask := int(ability["launch_mask"])
		var reachable := true
		for rank in PURLING_LAUNCH:
			reachable = reachable and StitchedParts.ranks_allowed(mask, rank)
		var excluded := true
		for rank in [0, 1, 2, 5]:
			excluded = excluded and not StitchedParts.ranks_allowed(mask, rank)
		_check(ability["launch"] == PURLING_LAUNCH
			and mask == StitchedParts.rank_mask(PURLING_LAUNCH) and reachable and excluded,
			"AC1: tier %d Purling Barrage launches from 3,4 and refuses 0,1,2,5" % tier)
		_check(ability["target"] == [1, 2, 3]
			and int(ability["target_mask"]) == StitchedParts.rank_mask([1, 2, 3])
			and str(ability["target_side"]) == "enemy" and not bool(ability["multi"])
			and int(ability["acc"]) == 92 and int(ability["crit"]) == 0
			and int(ability["self_move"]) == 0 and str(ability["move"]) == "attack",
			"AC1: tier %d Purling Barrage stays a single-target enemy 1-3 attack" % tier)
		_check(ability["dmg"] == PURLING_SPECS["dmg"][tier - 1]
			and ability["effects"] == PURLING_SPECS["effects"][tier - 1],
			"AC1: tier %d Purling Barrage keeps authored damage and Exposed" % tier)


## Snare Net keeps its multi-target enemy 1-3 debuff at every tier while its launch mask
## gains hero rank four. Ranks 1, 0 and 5 stay illegal launches.
func _test_snare_net_launch_tiers() -> void:
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		return
	var part: Dictionary = cat["by_id"][SNARE_ID]
	_check(str(part["slot"]) == "torso" and str(part["owner"]) == "yarn_ranger"
		and part["stat"] == {"prot": 5, "max_hp": 3},
		"AC1: Snare Net stays a Yarn Ranger torso part with its authored stat")
	for tier in [1, 2, 3]:
		var ability := StitchedParts.ability_at_tier(part, tier)
		var mask := int(ability["launch_mask"])
		var reachable := true
		for rank in SNARE_LAUNCH:
			reachable = reachable and StitchedParts.ranks_allowed(mask, rank)
		var excluded := true
		for rank in [0, 1, 5]:
			excluded = excluded and not StitchedParts.ranks_allowed(mask, rank)
		_check(ability["launch"] == SNARE_LAUNCH
			and mask == StitchedParts.rank_mask(SNARE_LAUNCH) and reachable and excluded,
			"AC1: tier %d Snare Net launch mask allows 2,3,4 and refuses 0,1,5" % tier)
		_check(ability["target"] == [1, 2, 3]
			and int(ability["target_mask"]) == StitchedParts.rank_mask([1, 2, 3])
			and str(ability["target_side"]) == "enemy" and bool(ability["multi"])
			and str(ability["kind"]) == "debuff"
			and int(ability["acc"]) == int(SNARE_SPECS["acc"][tier - 1])
			and ability["dmg"] == [0, 0] and int(ability["crit"]) == 0
			and int(ability["self_move"]) == 0 and str(ability["move"]) == "skill"
			and ability["effects"] == SNARE_SPECS["effects"][tier - 1],
			"AC1: tier %d Snare Net keeps its enemy 1-3 multi debuff, ACC and Tangled" % tier)


## Reel Thread launches from hero rank four as well as ranks two and three at every stitch
## tier, while its enemy target lock stays exactly ranks 2-3 and its authored numbers,
## statuses and skill pose are untouched.
func _test_reel_thread_launch_tiers() -> void:
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		return
	var part: Dictionary = cat["by_id"][REEL_ID]
	_check(str(part["slot"]) == "legs" and str(part["owner"]) == "yarn_ranger"
		and str(part["name"]) == "Reel Thread" and part["stat"] == {"speed": 1},
		"AC1: Reel Thread stays a Yarn Ranger legs part with its authored speed stat")
	for tier in [1, 2, 3]:
		var ability := StitchedParts.ability_at_tier(part, tier)
		var mask := int(ability["launch_mask"])
		var reachable := true
		for rank in REEL_LAUNCH:
			reachable = reachable and StitchedParts.ranks_allowed(mask, rank)
		var excluded := true
		for rank in [0, 1, 5]:
			excluded = excluded and not StitchedParts.ranks_allowed(mask, rank)
		_check(ability["launch"] == REEL_LAUNCH
			and mask == StitchedParts.rank_mask(REEL_LAUNCH) and reachable and excluded,
			"AC1: tier %d Reel Thread launch mask allows 2,3,4 and refuses 0,1,5" % tier)
		var enemy_reachable := true
		for rank in REEL_TARGET:
			enemy_reachable = enemy_reachable and StitchedParts.ranks_allowed(
				int(ability["target_mask"]), rank)
		var enemy_excluded := true
		for rank in [0, 1, 5]:
			enemy_excluded = enemy_excluded and not StitchedParts.ranks_allowed(
				int(ability["target_mask"]), rank)
		_check(ability["target"] == REEL_TARGET
			and int(ability["target_mask"]) == StitchedParts.rank_mask(REEL_TARGET)
			and enemy_reachable and enemy_excluded
			and str(ability["target_side"]) == "enemy" and not bool(ability["multi"])
			and str(ability["kind"]) == "debuff"
			and str(ability["id"]) == "yarn_ranger_legs_reel_thread_move"
			and int(ability["acc"]) == int(REEL_SPECS["acc"][tier - 1])
			and ability["dmg"] == [0, 0] and int(ability["crit"]) == 0
			and ability["effects"] == REEL_SPECS["effects"][tier - 1]
			and int(ability["self_move"]) == 0 and str(ability["move"]) == "skill",
			"AC1: tier %d Reel Thread keeps enemy targets 2-4, ACC, Tangled, Mark and skill pose"
				% tier)


## The authentic seeded battle: the same four heroes and three foes, Ranger at rank four
## wearing her alternate Snare Net torso. One cast resolves independently against every foe.
func _test_rank_four_snare_net_launch() -> void:
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		return
	for tier in [1, 2, 3]:
		var expected := int(SNARE_SPECS["effects"][tier - 1]["tangled"])
		var b := _rank_four_battle(SNARE_ID, tier)
		_check(b != null,
			"AC2: fresh S2 battle equips rank-four Ranger with tier %d Snare Net" % tier)
		if b == null:
			continue
		var ranger := b.get_unit("yarn_ranger")
		_check(b.get_heroes().size() == 4 and b.get_foes().size() == 3
			and int(ranger["rank"]) == 4
			and str(ranger["parts"]["torso"]["id"]) == SNARE_ID,
			"AC2: tier %d Snare Net is worn in the torso slot at hero rank four" % tier)
		_check(_to(b, "yarn_ranger"),
			"AC2: rank-four Ranger reaches her actual turn for tier %d Snare Net" % tier)
		if b.current_actor_id() != "yarn_ranger":
			continue
		var before := b.state_snapshot()
		var receipt := b.use_part(SNARE_ID, 1)
		var after := b.state_snapshot()
		var results: Array = receipt.get("results", [])
		var seen_targets: Dictionary = {}
		var seen_ranks: Dictionary = {}
		for item in results:
			seen_targets[str(item.get("target", ""))] = true
			seen_ranks[int(item.get("target_rank", 0))] = true
		_check(bool(receipt.get("ok", false)) and str(receipt.get("action", "")) == "ability"
			and str(receipt.get("actor", "")) == "yarn_ranger"
			and str(receipt.get("part", "")) == SNARE_ID
			and str(receipt.get("ability", "")) == "yarn_ranger_torso_snare_net_move"
			and results.size() == 3 and seen_targets.size() == 3
			and seen_ranks.has(1) and seen_ranks.has(2) and seen_ranks.has(3)
			and results.all(func(item): return str(item.get("target_side", "")) == "foe"),
			"AC2: rank-four tier %d Snare Net legally casts on three distinct foes at ranks 1-3: %s"
				% [tier, str(receipt.get("error", ""))])
		_check(after != before and (int(after["round"]) > int(before["round"])
			or (int(after["round"]) == int(before["round"])
				and int(after["turn_index"]) > int(before["turn_index"]))),
			"AC2: rank-four tier %d Snare Net advances the real turn" % tier)
		# A bounded explicit seed window witnesses one cast hitting all three foes, each
		# independently carrying the tier's Tangled amount; the same seed must replay exactly.
		var witness_seed := -1
		for seed_value in range(506040, 506072):
			var shot_battle := _rank_four_battle(SNARE_ID, tier, seed_value)
			if shot_battle == null or not _to(shot_battle, "yarn_ranger"):
				continue
			var shot := shot_battle.use_part(SNARE_ID, 1)
			if not bool(shot.get("ok", false)) or shot.get("results", []).size() != 3:
				continue
			var hit_targets: Dictionary = {}
			var all_hit := true
			for result in shot["results"]:
				var target_id := str(result.get("target", ""))
				var foe := shot_battle.get_unit(target_id)
				if not bool(result.get("hit", false)) or target_id.is_empty() \
						or int(foe["statuses"].get("tangled", 0)) < expected \
						or not result.get("statuses", []).any(
							func(s): return str(s.get("status", "")) == "tangled"):
					all_hit = false
					break
				hit_targets[target_id] = true
			if not all_hit or hit_targets.size() != 3:
				continue
			var replay := _rank_four_battle(SNARE_ID, tier, seed_value)
			if replay == null or not _to(replay, "yarn_ranger"):
				continue
			var replay_shot := replay.use_part(SNARE_ID, 1)
			if shot == replay_shot and shot_battle.state_snapshot() == replay.state_snapshot() \
					and shot_battle.rng_state() == replay.rng_state():
				witness_seed = seed_value
				break
		_check(witness_seed >= 0,
			"AC2: a bounded real seed shows rank-four tier %d Snare Net Tangling all three foes for %d, with an identical replay"
				% [tier, expected])
		if witness_seed >= 0:
			print("AC2 Snare Net tier %d witness seed %d" % [tier, witness_seed])
	# Rank one is a legal position for other parts, but Snare Net's launch mask must refuse it
	# before any hit roll, state change or turn spend.
	var front := _rank_one_battle(SNARE_ID)
	_check(front != null, "AC3: same real four-hero fixture allows Ranger rank one with Snare Net")
	if front == null:
		return
	var front_ranger := front.get_unit("yarn_ranger")
	_check(int(front_ranger["rank"]) == 1
		and str(front_ranger["parts"]["torso"]["id"]) == SNARE_ID,
		"AC3: rank-one Ranger wears Snare Net in the torso slot")
	_check(_to(front, "yarn_ranger"), "AC3: rank-one Snare Net Ranger obtains a real scheduled turn")
	if front.current_actor_id() == "yarn_ranger":
		_reject_without_spend(front, SNARE_ID, 1, "rank-one Snare Net launch")


## The authentic seeded battle: the same four heroes and three foes, Ranger at rank four
## wearing her alternate Purling Barrage arms. A genuine seeded miss is a legal shot.
func _test_rank_four_purling_launch() -> void:
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		return
	for tier in [1, 2, 3]:
		var b := _rank_four_battle(PURLING_ID, tier)
		_check(b != null, "AC2: fresh S2 battle equips rank-four Ranger with tier %d Purling Barrage" % tier)
		if b == null:
			continue
		var ranger := b.get_unit("yarn_ranger")
		_check(b.get_heroes().size() == 4 and b.get_foes().size() == 3
			and int(ranger["rank"]) == 4
			and str(ranger["parts"]["arms"]["id"]) == PURLING_ID,
			"AC2: tier %d Purling Barrage is worn in the arms slot at hero rank four" % tier)
		_check(_to(b, "yarn_ranger"),
			"AC2: rank-four Ranger reaches her actual turn for tier %d Purling Barrage" % tier)
		if b.current_actor_id() != "yarn_ranger":
			continue
		var before := b.state_snapshot()
		var receipt := b.use_part(PURLING_ID, 1)
		var after := b.state_snapshot()
		var results: Array = receipt.get("results", [])
		_check(bool(receipt.get("ok", false)) and str(receipt.get("action", "")) == "ability"
			and str(receipt.get("actor", "")) == "yarn_ranger"
			and str(receipt.get("part", "")) == PURLING_ID
			and str(receipt.get("ability", "")) == "yarn_ranger_arms_purling_barrage_move"
			and results.size() == 1
			and str(results[0].get("target_side", "")) == "foe"
			and int(results[0].get("target_rank", 0)) == 1,
			"AC2: rank-four tier %d Purling Barrage legally fires one shot at the living rank-one foe: %s"
				% [tier, str(receipt.get("error", ""))])
		_check(after != before and (int(after["round"]) > int(before["round"])
			or (int(after["round"]) == int(before["round"])
				and int(after["turn_index"]) > int(before["turn_index"]))),
			"AC2: rank-four tier %d Purling Barrage advances the real turn" % tier)
		# A bounded explicit seed window witnesses an actual hit, damage and the tier's
		# Exposed from rank four; the matching fresh battle must replay identically.
		var witnessed := false
		for seed_value in range(504040, 504072):
			var shot_battle := _rank_four_battle(PURLING_ID, tier, seed_value)
			if shot_battle == null or not _to(shot_battle, "yarn_ranger"):
				continue
			var shot := shot_battle.use_part(PURLING_ID, 1)
			if not bool(shot.get("ok", false)) or shot.get("results", []).size() != 1:
				continue
			var result: Dictionary = shot["results"][0]
			if not bool(result.get("hit", false)) or int(result.get("damage", 0)) <= 0:
				continue
			var target_id := str(result.get("target", ""))
			if target_id.is_empty():
				continue
			var foe := shot_battle.get_unit(target_id)
			var exposed := int(PURLING_SPECS["effects"][tier - 1]["exposed"])
			if int(foe["statuses"].get("exposed", 0)) < exposed:
				continue
			var replay := _rank_four_battle(PURLING_ID, tier, seed_value)
			if replay == null or not _to(replay, "yarn_ranger"):
				continue
			var replay_shot := replay.use_part(PURLING_ID, 1)
			witnessed = shot == replay_shot \
				and shot_battle.state_snapshot() == replay.state_snapshot() \
				and shot_battle.rng_state() == replay.rng_state()
			if witnessed:
				break
		_check(witnessed,
			"AC2: a bounded real seed shows rank-four tier %d Purling Barrage hitting rank one for damage and Exposed %d, with an identical replay"
				% [tier, int(PURLING_SPECS["effects"][tier - 1]["exposed"])])


## The authentic seeded battle: the same four heroes and the same three foes, Ranger at rank
## four. Each HEAD part fires from there during her actual scheduled turn. A genuine seeded
## miss is a legal shot, never a rejected launch.
func _test_rank_four_head_launch() -> void:
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		return
	for head_id in HEAD_SPECS:
		var spec: Dictionary = HEAD_SPECS[head_id]
		var ability_id := str(spec["ability"])
		var b := _rank_four_battle(head_id)
		_check(b != null, "AC2: fresh S2 battle equips rank-four Ranger with " + head_id)
		if b == null:
			continue
		var ranger := b.get_unit("yarn_ranger")
		_check(b.get_heroes().size() == 4 and b.get_foes().size() == 3
			and int(ranger["rank"]) == 4
			and str(ranger["parts"]["head"]["id"]) == head_id,
			"AC2: %s is worn at hero rank four against the same three foes" % head_id)
		_check(_to(b, "yarn_ranger"), "AC2: rank-four Ranger reaches her actual turn for " + head_id)
		if b.current_actor_id() != "yarn_ranger":
			continue
		var before := b.state_snapshot()
		var receipt := b.use_part(head_id, 1)
		var after := b.state_snapshot()
		var results: Array = receipt.get("results", [])
		_check(bool(receipt.get("ok", false)) and str(receipt.get("action", "")) == "ability"
			and str(receipt.get("actor", "")) == "yarn_ranger"
			and str(receipt.get("part", "")) == head_id
			and str(receipt.get("ability", "")) == ability_id
			and results.size() == 1
			and str(results[0].get("target_side", "")) == "foe"
			and int(results[0].get("target_rank", 0)) == 1,
			"AC2: rank-four %s legally fires one shot at the living rank-one foe: %s"
				% [head_id, str(receipt.get("error", ""))])
		_check(after != before and (int(after["round"]) > int(before["round"])
			or (int(after["round"]) == int(before["round"])
				and int(after["turn_index"]) > int(before["turn_index"]))),
			"AC2: rank-four %s advances the real turn" % head_id)
	# A bounded explicit seed window witnesses an actual hit and status from rank four; the
	# rules are untouched, so a genuine miss is skipped only while searching for that witness.
	for head_id in HEAD_SPECS:
		var head_spec: Dictionary = HEAD_SPECS[head_id]
		var effect := str(head_spec["effects"][0].keys()[0])
		var witnessed := false
		for seed_value in range(504040, 504072):
			var shot_battle := _rank_four_battle(head_id, 1, seed_value)
			if shot_battle == null or not _to(shot_battle, "yarn_ranger"):
				continue
			var shot := shot_battle.use_part(head_id, 1)
			if not bool(shot.get("ok", false)) or shot.get("results", []).size() != 1:
				continue
			var result: Dictionary = shot["results"][0]
			if not bool(result.get("hit", false)):
				continue
			if not result["statuses"].any(
					func(s): return str(s.get("status", "")) == effect):
				continue
			var foe := shot_battle.get_unit(str(result["target"]))
			if int(foe["statuses"].get(effect, 0)) >= int(head_spec["effects"][0][effect]):
				witnessed = true
				break
		_check(witnessed, "AC2: a bounded real seed shows rank-four %s hitting rank one with %s"
			% [head_id, effect])


## The task goal: at every stitch tier the alternate Needle Arrow reaches the living moth_scribe
## in enemy rank four from the Ranger's real scheduled turn in the ordinary three-foe battle.
## A seeded miss is a legal shot, while a bounded seed window must witness damage plus the
## tier's exact Mark and an identical receipt/snapshot/RNG replay. Absent, front-rank, torn,
## unequipped and out-of-bounds shots remain atomic refusals.
func _test_needle_arrow_rank_four_target() -> void:
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		return
	var arrow := ALTERNATES["head"]
	var ability_id := str(HEAD_SPECS[arrow]["ability"])
	for tier in [1, 2, 3]:
		var expected_mark := int(HEAD_SPECS[arrow]["effects"][tier - 1]["mark"])
		var b := _rank_four_foe_battle(arrow, tier)
		_check(b != null,
			"AC2: fresh three-foe battle equips tier %d Needle Arrow with a living foe at enemy rank 4"
				% tier)
		if b == null:
			continue
		var ranger := b.get_unit("yarn_ranger")
		var rear := b.get_unit("moth_scribe")
		_check(b.get_heroes().size() == 4 and b.get_foes().size() == 3
			and int(ranger["rank"]) == 3 and str(ranger["parts"]["head"]["id"]) == arrow
			and int(rear["rank"]) == 4 and int(rear["hp"]) > 0,
			"AC2: tier %d Ranger launches legally while the real fourth-rank foe lives" % tier)
		_check(_to(b, "yarn_ranger"),
			"AC2: Ranger reaches her actual scheduled turn for tier %d rank-four Needle Arrow"
				% tier)
		if b.current_actor_id() != "yarn_ranger":
			continue
		for bad_rank in [0, 5]:
			_reject_without_spend(b, arrow, bad_rank,
				"tier %d Needle Arrow target rank %d outside 1..4" % [tier, bad_rank])
		var other_before := {}
		for foe in b.get_foes():
			if str(foe["id"]) != "moth_scribe":
				other_before[str(foe["id"])] = {
					"hp": int(foe["hp"]),
					"statuses": foe["statuses"].duplicate(true),
				}
		var rear_hp_before := int(b.get_unit("moth_scribe")["hp"])
		var before := b.state_snapshot()
		var receipt := b.use_part(arrow, 4)
		var after := b.state_snapshot()
		var results: Array = receipt.get("results", [])
		_check(bool(receipt.get("ok", false)) and str(receipt.get("action", "")) == "ability"
			and str(receipt.get("actor", "")) == "yarn_ranger"
			and str(receipt.get("part", "")) == arrow
			and str(receipt.get("ability", "")) == ability_id
			and results.size() == 1
			and str(results[0].get("target", "")) == "moth_scribe"
			and str(results[0].get("target_side", "")) == "foe"
			and int(results[0].get("target_rank", 0)) == 4,
			"AC2: tier %d Needle Arrow legally resolves on the single enemy at rank four: %s"
				% [tier, str(receipt.get("error", ""))])
		_check(after != before and (int(after["round"]) > int(before["round"])
			or (int(after["round"]) == int(before["round"])
				and int(after["turn_index"]) > int(before["turn_index"])))
			and b.current_actor_id() != "yarn_ranger",
			"AC2: tier %d rank-four Needle Arrow spends exactly one Ranger turn" % tier)
		var untouched := true
		for foe in b.get_foes():
			var foe_id := str(foe["id"])
			if foe_id == "moth_scribe":
				continue
			var prior: Dictionary = other_before.get(foe_id, {})
			if prior.is_empty() or int(foe["hp"]) != int(prior["hp"]) \
					or foe["statuses"] != prior["statuses"]:
				untouched = false
		_check(untouched, "AC2: tier %d Needle Arrow touches no other foe" % tier)
		if results.size() != 1:
			continue
		var result: Dictionary = results[0]
		if bool(result.get("hit", false)):
			var marked: bool = result.get("statuses", []).any(
				func(s): return str(s.get("status", "")) == "mark" \
					and int(s.get("duration", 0)) == expected_mark)
			_check(int(result.get("damage", 0)) > 0
				and int(result.get("target_hp", -1))
					== rear_hp_before - int(result.get("damage", 0)) and marked,
				"AC2: tier %d Needle Arrow's hit on the rank-four foe deals its damage and Mark %d"
					% [tier, expected_mark])
		else:
			_check(int(result.get("damage", -1)) == 0
				and int(result.get("target_hp", -1)) == rear_hp_before,
				"AC2: tier %d Needle Arrow's legal miss leaves the rank-four foe unharmed" % tier)
		# A bounded explicit seed window witnesses a real hit that carries exactly the tier's
		# Mark, no collateral on the other two foes, and an identical replay.
		var witness_seed := -1
		for seed_value in range(507040, 507096):
			var shot_battle := _rank_four_foe_battle(arrow, tier, seed_value)
			if shot_battle == null or not _to(shot_battle, "yarn_ranger"):
				continue
			var shot_others := {}
			for foe in shot_battle.get_foes():
				if str(foe["id"]) != "moth_scribe":
					shot_others[str(foe["id"])] = {
						"hp": int(foe["hp"]),
						"statuses": foe["statuses"].duplicate(true),
					}
			var shot_rear_before := shot_battle.get_unit("moth_scribe")
			var shot := shot_battle.use_part(arrow, 4)
			if not bool(shot.get("ok", false)) or shot.get("results", []).size() != 1:
				continue
			var shot_result: Dictionary = shot["results"][0]
			if not bool(shot_result.get("hit", false)) \
					or int(shot_result.get("damage", 0)) <= 0 \
					or str(shot_result.get("target", "")) != "moth_scribe" \
					or int(shot_result.get("target_rank", 0)) != 4:
				continue
			if not shot_result.get("statuses", []).any(
					func(s): return str(s.get("status", "")) == "mark" \
						and int(s.get("duration", 0)) == expected_mark):
				continue
			var shot_foe := shot_battle.get_unit("moth_scribe")
			if int(shot_foe["rank"]) != 4 or int(shot_foe["hp"]) <= 0 \
					or int(shot_foe["hp"]) != int(shot_rear_before["hp"]) \
						- int(shot_result.get("damage", 0)) \
					or int(shot_foe["statuses"].get("mark", 0)) != expected_mark:
				continue
			var collateral := false
			for foe in shot_battle.get_foes():
				var foe_id := str(foe["id"])
				if foe_id == "moth_scribe":
					continue
				var prior: Dictionary = shot_others.get(foe_id, {})
				if prior.is_empty() or int(foe["hp"]) != int(prior["hp"]) \
						or foe["statuses"] != prior["statuses"]:
					collateral = true
			if collateral:
				continue
			var replay := _rank_four_foe_battle(arrow, tier, seed_value)
			if replay == null or not _to(replay, "yarn_ranger"):
				continue
			var replay_shot := replay.use_part(arrow, 4)
			if shot == replay_shot and shot_battle.state_snapshot() == replay.state_snapshot() \
					and shot_battle.rng_state() == replay.rng_state():
				witness_seed = seed_value
				break
		_check(witness_seed >= 0,
			"AC2: a bounded real seed shows tier %d Needle Arrow hitting the rank-four foe for damage and Mark %d, with an identical replay"
				% [tier, expected_mark])
		if witness_seed >= 0:
			print("AC2 Needle Arrow rank-four foe tier %d witness seed %d"
				% [tier, witness_seed])
	# A fresh three-foe fixture has no living foe in enemy rank four, so the expanded target
	# mask still refuses the shot without spending anything.
	for tier in [1, 2, 3]:
		var absent := _battle(arrow, tier)
		_check(absent != null,
			"AC3: fresh three-foe battle equips tier %d Needle Arrow with no rear-rank foe"
				% tier)
		if absent == null:
			continue
		_check(_to(absent, "yarn_ranger"),
			"AC3: tier %d Needle Arrow Ranger obtains a real scheduled turn" % tier)
		if absent.current_actor_id() == "yarn_ranger":
			_check(absent.get_foes().size() == 3
				and absent.get_foes().all(func(foe): return int(foe["rank"]) != 4),
				"AC3: tier %d fixture really has no foe at enemy rank four" % tier)
			_reject_without_spend(absent, arrow, 4,
				"tier %d Needle Arrow enemy rank 4 has no living foe" % tier)
	# Needle Arrow still launches only from hero ranks two to four: the front rank cannot fire
	# even when a living enemy really stands at rank four.
	for tier in [1, 2, 3]:
		var front := _front_rank_four_foe_battle(arrow, tier, 508040 + tier)
		_check(front != null,
			"AC3: fresh fixture allows tier %d rank-one Ranger with a real rear foe" % tier)
		if front == null:
			continue
		var front_ranger := front.get_unit("yarn_ranger")
		var rear_foe := front.get_unit("moth_scribe")
		_check(int(front_ranger["rank"]) == 1
			and str(front_ranger["parts"]["head"]["id"]) == arrow
			and int(rear_foe["rank"]) == 4 and int(rear_foe["hp"]) > 0,
			"AC3: tier %d front-rank Ranger really faces a living enemy at rank four" % tier)
		_check(_to(front, "yarn_ranger"),
			"AC3: tier %d rank-one Needle Arrow Ranger obtains a real scheduled turn" % tier)
		if front.current_actor_id() == "yarn_ranger":
			_reject_without_spend(front, arrow, 4,
				"tier %d rank-one Needle Arrow launch" % tier)
	# A torn alternate head and an unequipped alternate head never spend the turn.
	var torn_config := _config(arrow, 1, 509040)
	if not torn_config.is_empty():
		torn_config["heroes"][2]["parts"]["head"]["torn"] = true
		var torn_created := StitchedRules.create(torn_config)
		_check(bool(torn_created.get("ok", false)),
			"AC3: real torn Needle Arrow admitted as equipment")
		if bool(torn_created.get("ok", false)):
			var torn_battle: StitchedRules = torn_created["battle"]
			_check(_to(torn_battle, "yarn_ranger"),
				"AC3: torn Needle Arrow Ranger obtains a real scheduled turn")
			if torn_battle.current_actor_id() == "yarn_ranger":
				_reject_without_spend(torn_battle, arrow, 4, "torn Needle Arrow")
	var unequipped := _battle("", 1, 509041)
	_check(unequipped != null, "AC3: starter three-foe battle exists for the unequipped check")
	if unequipped != null and _to(unequipped, "yarn_ranger"):
		_reject_without_spend(unequipped, arrow, 4, "unequipped Needle Arrow")


## Both siblings are copies of the same seeded three-foe battle, brought to the Ranger's real
## scheduled turn without acting. Only the marked twin's rank-four Moth Scribe receives a
## controlled starting Mark; setting a status draws no RNG, so both shots resolve from the same
## seeded position.
func _arrow_marked_pair(seed_value: int) -> Dictionary:
	var marked := _rank_four_foe_battle(ALTERNATES["head"], 2, seed_value)
	var plain := _rank_four_foe_battle(ALTERNATES["head"], 2, seed_value)
	if marked == null or plain == null:
		return {}
	if not _to(marked, "yarn_ranger") or not _to(plain, "yarn_ranger"):
		return {}
	if marked.current_actor_id() != "yarn_ranger" or plain.current_actor_id() != "yarn_ranger":
		return {}
	if not marked.get_unit("moth_scribe").has("statuses"):
		return {}
	marked._units["moth_scribe"]["statuses"]["mark"] = 1
	return {"marked": marked, "plain": plain}


## Fires the equipped tier-II Needle Arrow at enemy rank four in both twins and returns their
## receipts plus the resulting authoritative state and RNG position.
func _arrow_marked_signature(seed_value: int) -> Dictionary:
	var pair := _arrow_marked_pair(seed_value)
	if pair.is_empty():
		return {}
	var marked: StitchedRules = pair["marked"]
	var plain: StitchedRules = pair["plain"]
	var marked_receipt := marked.use_part(ALTERNATES["head"], 4)
	var plain_receipt := plain.use_part(ALTERNATES["head"], 4)
	var marked_results: Array = marked_receipt.get("results", [])
	var plain_results: Array = plain_receipt.get("results", [])
	if marked_results.size() != 1 or plain_results.size() != 1:
		return {}
	return {
		"marked_receipt": marked_receipt,
		"plain_receipt": plain_receipt,
		"marked_results": marked_results,
		"plain_results": plain_results,
		"marked_state": marked.state_snapshot(),
		"plain_state": plain.state_snapshot(),
		"marked_rng": marked.rng_state(),
		"plain_rng": plain.rng_state(),
	}


## The task goal: Needle Arrow's authored mark_damage punishes a foe that already carries Mark.
## A bounded seed window finds one real paired rank-four hit at tier II; the marked and clean
## twins then prove exactly +3 damage, identical seeded rolls, exact target HP, one spent turn
## and the clean foe's original Mark 2 applied only after that damage.
func _test_needle_arrow_premarked_bonus() -> void:
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		return
	var arrow := ALTERNATES["head"]
	var tier := 2
	var expected_mark := int(HEAD_SPECS[arrow]["effects"][tier - 1]["mark"])
	var bonus := int(HEAD_SPECS[arrow]["mark_damage"][tier - 1])
	var witness_seed := -1
	for seed_value in range(507040, 507136):
		var signature := _arrow_marked_signature(seed_value)
		if signature.is_empty():
			continue
		var marked_result: Dictionary = signature["marked_results"][0]
		var plain_result: Dictionary = signature["plain_results"][0]
		if not bool(marked_result.get("hit", false)) \
				or not bool(plain_result.get("hit", false)) \
				or int(marked_result.get("damage", 0)) <= 0 \
				or int(plain_result.get("damage", 0)) <= 0 \
				or str(marked_result.get("target", "")) != "moth_scribe" \
				or str(plain_result.get("target", "")) != "moth_scribe" \
				or int(marked_result.get("target_rank", 0)) != 4 \
				or int(plain_result.get("target_rank", 0)) != 4:
			continue
		witness_seed = seed_value
		break
	_check(witness_seed >= 0,
		"AC2: a bounded real seed witnesses paired tier-II Needle Arrow hits on the rank-four foe")
	if witness_seed < 0:
		return
	print("AC2 Needle Arrow pre-Marked bonus tier II witness seed %d" % witness_seed)

	var pair := _arrow_marked_pair(witness_seed)
	if pair.is_empty():
		_check(false, "AC2: the witness seed rebuilds a marked/clean Needle Arrow pair")
		return
	var marked: StitchedRules = pair["marked"]
	var plain: StitchedRules = pair["plain"]
	var marked_ranger := marked.get_unit("yarn_ranger")
	var plain_ranger := plain.get_unit("yarn_ranger")
	var marked_foe := marked.get_unit("moth_scribe")
	var plain_foe := plain.get_unit("moth_scribe")
	_check(int(marked_ranger["rank"]) == 3 and int(plain_ranger["rank"]) == 3
		and str(marked_ranger["parts"]["head"]["id"]) == arrow
		and str(plain_ranger["parts"]["head"]["id"]) == arrow,
		"AC2: both real Ranger witnesses wear tier-II Needle Arrow at hero rank three")
	_check(int(marked_foe["rank"]) == 4 and int(plain_foe["rank"]) == 4
		and int(marked_foe["hp"]) > 0 and int(marked_foe["hp"]) == int(plain_foe["hp"])
		and int(marked_foe["prot"]) == 0 and int(plain_foe["prot"]) == 0,
		"AC2: both legal rank-four targets start alive at the same HP with zero PROT")
	for status in ["weak", "exposed", "tangled"]:
		_check(int(marked_foe["statuses"].get(status, 0)) == 0
			and int(plain_foe["statuses"].get(status, 0)) == 0
			and int(marked_ranger["statuses"].get(status, 0)) == 0
			and int(plain_ranger["statuses"].get(status, 0)) == 0,
			"AC2: no " + status + " distorts the paired comparison")
	_check(int(marked_foe["statuses"].get("mark", 0)) == 1
		and int(plain_foe["statuses"].get("mark", 0)) == 0,
		"AC2: only the marked witness's foe carries Mark before the shot")
	_check(marked.rng_state() == plain.rng_state(),
		"AC2: both shots start from the identical seeded RNG position")
	var ability := StitchedParts.ability_at_tier(cat["by_id"][arrow], tier)
	_check(int(ability.get("mark_damage", 0)) == bonus and bonus == 3,
		"AC1: the equipped tier-II Needle Arrow ability carries mark_damage 3")
	var marked_before := marked.state_snapshot()
	var plain_before := plain.state_snapshot()
	var start_hp := int(marked_foe["hp"])

	var marked_receipt := marked.use_part(arrow, 4)
	var plain_receipt := plain.use_part(arrow, 4)
	var marked_results: Array = marked_receipt.get("results", [])
	var plain_results: Array = plain_receipt.get("results", [])
	_check(bool(marked_receipt.get("ok", false)) and bool(plain_receipt.get("ok", false))
		and str(marked_receipt.get("action", "")) == "ability"
		and str(plain_receipt.get("action", "")) == "ability"
		and str(marked_receipt.get("part", "")) == arrow
		and str(plain_receipt.get("part", "")) == arrow
		and str(marked_receipt.get("ability", "")) == "yarn_ranger_head_needle_arrow_move"
		and str(plain_receipt.get("ability", "")) == "yarn_ranger_head_needle_arrow_move"
		and marked_results.size() == 1 and plain_results.size() == 1,
		"AC2: both real tier-II shots resolve one legal receipt: %s%s"
			% [str(marked_receipt.get("error", "")), str(plain_receipt.get("error", ""))])
	if marked_results.size() != 1 or plain_results.size() != 1:
		return
	var marked_hit: Dictionary = marked_results[0]
	var plain_hit: Dictionary = plain_results[0]
	_check(str(marked_hit.get("target", "")) == "moth_scribe"
		and str(plain_hit.get("target", "")) == "moth_scribe"
		and str(marked_hit.get("target_side", "")) == "foe"
		and str(plain_hit.get("target_side", "")) == "foe"
		and int(marked_hit.get("target_rank", 0)) == 4
		and int(plain_hit.get("target_rank", 0)) == 4,
		"AC2: each shot is a true single-target receipt on the rank-four foe")
	_check(bool(marked_hit.get("hit", false)) and bool(plain_hit.get("hit", false))
		and int(marked_hit.get("roll", 0)) == int(plain_hit.get("roll", 0))
		and int(marked_hit.get("hit_chance", 0)) == int(plain_hit.get("hit_chance", 0))
		and bool(marked_hit.get("crit", false)) == bool(plain_hit.get("crit", false)),
		"AC2: the paired shots share identical seeded hit and crit decisions")
	var marked_damage := int(marked_hit.get("damage", -1))
	var plain_damage := int(plain_hit.get("damage", -1))
	_check(marked_damage == plain_damage + bonus,
		"AC2: the already-Marked foe takes exactly +%d direct damage" % bonus)
	_check(marked_damage == StitchedRules.damage_after_modifiers(
		plain_damage, {}, {}, true, bonus, 0),
		"AC2: the Mark bonus is added before Weak/Exposed/Tangled/PROT, exactly matching the resolver")
	var arms_bonus := int(plain_ranger.get("dmg_bonus", 0))
	var crit_high := StitchedRules.crit_damage(int(ability["dmg"][1])) + arms_bonus
	_check((not bool(plain_hit.get("crit", false))
			and plain_damage >= int(ability["dmg"][0]) + arms_bonus
			and plain_damage <= int(ability["dmg"][1]) + arms_bonus)
		or (bool(plain_hit.get("crit", false)) and plain_damage == crit_high),
		"AC3: the clean shot keeps the authored tier-II damage and gains no self-Mark bonus")
	_check(int(marked_hit.get("target_hp", -1)) == start_hp - marked_damage
		and int(plain_hit.get("target_hp", -1)) == start_hp - plain_damage
		and int(marked.get_unit("moth_scribe")["hp"]) == start_hp - marked_damage
		and int(plain.get_unit("moth_scribe")["hp"]) == start_hp - plain_damage,
		"AC2: the target receipt and authoritative HP reflect each shot exactly")
	_check(plain_hit.get("statuses", []).any(func(s): return str(s.get("status", "")) == "mark" \
			and int(s.get("duration", 0)) == expected_mark)
		and int(plain.get_unit("moth_scribe")["statuses"].get("mark", 0)) == expected_mark,
		"AC3: the clean foe gains only its original Mark %d after that damage" % expected_mark)
	_check(marked_hit.get("statuses", []).any(func(s): return str(s.get("status", "")) == "mark" \
			and int(s.get("duration", 0)) == expected_mark)
		and int(marked.get_unit("moth_scribe")["statuses"].get("mark", 0)) == expected_mark,
		"AC2: the already-Marked foe ends with the authored Mark %d as well" % expected_mark)
	var untouched := true
	for foe_id in ["fray_scavenger", "scissor_crab"]:
		for battle in [marked, plain]:
			var foe: Dictionary = battle.get_unit(foe_id)
			if foe.is_empty() or int(foe["hp"]) != int(foe["max_hp"]) \
					or not foe["statuses"].is_empty():
				untouched = false
	_check(untouched, "AC2: the paired shots damage and Mark no other foe")
	var marked_after := marked.state_snapshot()
	var plain_after := plain.state_snapshot()
	_check((int(marked_after["round"]) > int(marked_before["round"])
			or int(marked_after["turn_index"]) > int(marked_before["turn_index"]))
		and (int(plain_after["round"]) > int(plain_before["round"])
			or int(plain_after["turn_index"]) > int(plain_before["turn_index"]))
		and marked.current_actor_id() != "yarn_ranger"
		and plain.current_actor_id() != "yarn_ranger",
		"AC2: each shot consumes exactly one Ranger turn")
	var first := _arrow_marked_signature(witness_seed)
	var second := _arrow_marked_signature(witness_seed)
	_check(not first.is_empty() and first == second,
		"AC4: equal seed, kit, foe ranks and Mark precondition replay identical receipts, HP, turn and RNG")


## The authentic seeded battle: the same four heroes and three foes, Ranger at rank four
## wearing her own starter Wool Bolas in the arms slot. A genuine seeded miss is a legal shot.
func _test_rank_four_bolas_launch() -> void:
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		return
	var b := _rank_four_battle(BOLAS_ID)
	_check(b != null, "AC2: fresh S2 battle equips rank-four Ranger with Wool Bolas")
	if b == null:
		return
	var ranger := b.get_unit("yarn_ranger")
	_check(b.get_heroes().size() == 4 and b.get_foes().size() == 3
		and int(ranger["rank"]) == 4
		and str(ranger["parts"]["arms"]["id"]) == BOLAS_ID,
		"AC2: Wool Bolas is worn in the arms slot at hero rank four against the same three foes")
	_check(_to(b, "yarn_ranger"), "AC2: rank-four Ranger reaches her actual turn for Wool Bolas")
	if b.current_actor_id() != "yarn_ranger":
		return
	var before := b.state_snapshot()
	var receipt := b.use_part(BOLAS_ID, 1)
	var after := b.state_snapshot()
	var results: Array = receipt.get("results", [])
	_check(bool(receipt.get("ok", false)) and str(receipt.get("action", "")) == "ability"
		and str(receipt.get("actor", "")) == "yarn_ranger"
		and str(receipt.get("part", "")) == BOLAS_ID
		and str(receipt.get("ability", "")) == "yarn_ranger_arms_wool_bolas_move"
		and results.size() == 1
		and str(results[0].get("target_side", "")) == "foe"
		and int(results[0].get("target_rank", 0)) == 1,
		"AC2: rank-four Wool Bolas legally fires one shot at the living rank-one foe: "
			+ str(receipt.get("error", "")))
	_check(after != before and (int(after["round"]) > int(before["round"])
		or (int(after["round"]) == int(before["round"])
			and int(after["turn_index"]) > int(before["turn_index"]))),
		"AC2: rank-four Wool Bolas advances the real turn")
	# A bounded explicit seed window witnesses an actual hit and Tangled from rank four; the
	# rules are untouched, so a genuine miss is skipped only while searching for that witness.
	var witnessed := false
	for seed_value in range(504040, 504072):
		var shot_battle := _rank_four_battle(BOLAS_ID, 1, seed_value)
		if shot_battle == null or not _to(shot_battle, "yarn_ranger"):
			continue
		var shot := shot_battle.use_part(BOLAS_ID, 1)
		if not bool(shot.get("ok", false)) or shot.get("results", []).size() != 1:
			continue
		var result: Dictionary = shot["results"][0]
		if not bool(result.get("hit", false)):
			continue
		if not result["statuses"].any(func(s): return str(s.get("status", "")) == "tangled"):
			continue
		var target_id := str(result.get("target", ""))
		if target_id.is_empty():
			continue
		var foe := shot_battle.get_unit(target_id)
		if int(foe["statuses"].get("tangled", 0)) >= 1:
			witnessed = true
			break
	_check(witnessed, "AC2: a bounded real seed shows rank-four Wool Bolas hitting rank one with Tangled")


## The authentic seeded battle: the same four heroes and three foes, Ranger at rank four
## wearing her own starter Reel Thread. From the rear rank she may now snare the living
## rank-two foe at every tier; hero ranks two and three stay legal launch positions.
func _test_rank_four_reel_thread_launch() -> void:
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		return
	for tier in [1, 2, 3]:
		var expected: Dictionary = REEL_SPECS["effects"][tier - 1]
		var b := _rank_four_battle(REEL_ID, tier)
		_check(b != null,
			"AC2: fresh S2 battle equips rank-four Ranger with tier %d Reel Thread" % tier)
		if b == null:
			continue
		var ranger := b.get_unit("yarn_ranger")
		var rank_two_foes := b.get_foes().filter(
			func(foe): return int(foe["rank"]) == 2 and int(foe["hp"]) > 0)
		_check(b.get_heroes().size() == 4 and b.get_foes().size() == 3
			and int(ranger["rank"]) == 4
			and str(ranger["parts"]["legs"]["id"]) == REEL_ID
			and rank_two_foes.size() == 1,
			"AC2: tier %d Reel Thread is worn in the legs slot at hero rank four with a living enemy at rank two"
				% tier)
		_check(_to(b, "yarn_ranger"),
			"AC2: rank-four Ranger reaches her actual turn for tier %d Reel Thread" % tier)
		if b.current_actor_id() != "yarn_ranger":
			continue
		var before := b.state_snapshot()
		var receipt := b.use_part(REEL_ID, 2)
		var after := b.state_snapshot()
		var results: Array = receipt.get("results", [])
		_check(bool(receipt.get("ok", false)) and str(receipt.get("action", "")) == "ability"
			and str(receipt.get("actor", "")) == "yarn_ranger"
			and str(receipt.get("part", "")) == REEL_ID
			and str(receipt.get("ability", "")) == "yarn_ranger_legs_reel_thread_move"
			and results.size() == 1
			and str(results[0].get("target_side", "")) == "foe"
			and int(results[0].get("target_rank", 0)) == 2,
			"AC2: rank-four tier %d Reel Thread legally snares the living rank-two foe: %s"
				% [tier, str(receipt.get("error", ""))])
		_check(after != before and (int(after["round"]) > int(before["round"])
			or (int(after["round"]) == int(before["round"])
				and int(after["turn_index"]) > int(before["turn_index"]))),
			"AC2: rank-four tier %d Reel Thread spends exactly one Ranger turn" % tier)
		# A bounded explicit seed window witnesses an actual hit that does not pull the foe
		# and carries exactly the tier's Tangled (plus Mark 1 at tier III); the same seed
		# must replay the identical receipts, snapshot and RNG position.
		var witness_seed := -1
		for seed_value in range(504040, 504072):
			var shot_battle := _rank_four_battle(REEL_ID, tier, seed_value)
			if shot_battle == null or not _to(shot_battle, "yarn_ranger"):
				continue
			var shot := shot_battle.use_part(REEL_ID, 2)
			if not bool(shot.get("ok", false)) or shot.get("results", []).size() != 1:
				continue
			var result: Dictionary = shot["results"][0]
			var target_id := str(result.get("target", ""))
			if not bool(result.get("hit", false)) or target_id.is_empty() \
					or int(result.get("target_rank", 0)) != 2:
				continue
			var statuses: Array = result.get("statuses", [])
			if not statuses.any(func(s): return str(s.get("status", "")) == "tangled"):
				continue
			if expected.has("mark") and not statuses.any(
					func(s): return str(s.get("status", "")) == "mark"):
				continue
			var foe := shot_battle.get_unit(target_id)
			if int(foe["rank"]) != 2 or int(foe["hp"]) <= 0:
				continue
			if int(foe["statuses"].get("tangled", 0)) != int(expected["tangled"]) \
					or int(foe["statuses"].get("mark", 0)) != int(expected.get("mark", 0)):
				continue
			var replay := _rank_four_battle(REEL_ID, tier, seed_value)
			if replay == null or not _to(replay, "yarn_ranger"):
				continue
			var replay_shot := replay.use_part(REEL_ID, 2)
			if shot == replay_shot and shot_battle.state_snapshot() == replay.state_snapshot() \
					and shot_battle.rng_state() == replay.rng_state():
				witness_seed = seed_value
				break
		_check(witness_seed >= 0,
			"AC2: a bounded real seed shows rank-four tier %d Reel Thread hitting the rank-two foe with Tangled %d%s, no pull, and an identical replay"
				% [tier, int(expected["tangled"]),
					" and Mark 1" if expected.has("mark") else ""])
		if witness_seed >= 0:
			print("AC2 Reel Thread tier %d witness seed %d" % [tier, witness_seed])
	# The starter legs keep their already-legal launches from hero ranks two and three.
	var rank_two := _rank_two_battle(REEL_ID)
	_check(rank_two != null, "AC2: same real four-hero fixture allows Ranger rank two with Reel Thread")
	if rank_two != null:
		_check(_to(rank_two, "yarn_ranger"),
			"AC2: rank-two Reel Thread Ranger obtains a real scheduled turn")
		if rank_two.current_actor_id() == "yarn_ranger":
			var mid_before := rank_two.state_snapshot()
			var mid := rank_two.use_part(REEL_ID, 2)
			var mid_results: Array = mid.get("results", [])
			_check(bool(mid.get("ok", false)) and str(mid.get("part", "")) == REEL_ID
				and mid_results.size() == 1 and int(mid_results[0].get("target_rank", 0)) == 2
				and rank_two.state_snapshot() != mid_before,
				"AC2: Reel Thread still launches legally from hero rank two: "
					+ str(mid.get("error", "")))
	var rank_three := _battle(REEL_ID, 1)
	_check(rank_three != null, "AC2: same real four-hero fixture allows Ranger rank three with Reel Thread")
	if rank_three != null:
		_check(_to(rank_three, "yarn_ranger"),
			"AC2: rank-three Reel Thread Ranger obtains a real scheduled turn")
		if rank_three.current_actor_id() == "yarn_ranger":
			var back_before := rank_three.state_snapshot()
			var back := rank_three.use_part(REEL_ID, 2)
			var back_results: Array = back.get("results", [])
			_check(bool(back.get("ok", false)) and str(back.get("part", "")) == REEL_ID
				and back_results.size() == 1 and int(back_results[0].get("target_rank", 0)) == 2
				and rank_three.state_snapshot() != back_before,
				"AC2: Reel Thread still launches legally from hero rank three: "
					+ str(back.get("error", "")))


## The task goal: Reel Thread now reaches a living foe in enemy rank four in a real seeded
## battle that opens with exactly three foes. Each tier is cast from the Ranger's actual
## scheduled turn; the illegal front rank is refused first and must spend nothing.
func _test_reel_thread_rank_four_target() -> void:
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		return
	# The supported special arrival is the existing Walk intruder standing in enemy rank four.
	# The ambush rule gives it round one's first turn and it flees on that turn (S8c), so the
	# sustained per-turn casts below use a real stationary foe already authored in that slot.
	var ambush_config := _config(REEL_ID, 1, 507040)
	ambush_config["walk_mimic"] = true
	var ambush := StitchedRules.create(ambush_config)
	_check(bool(ambush.get("ok", false)),
		"AC2: real three-foe battle admits the supported Walk intruder at enemy rank four")
	if bool(ambush.get("ok", false)):
		var ambush_battle: StitchedRules = ambush["battle"]
		var intruder := ambush_battle.get_unit(StitchedRules.WALK_MIMIC_ID)
		var ambush_ability := StitchedParts.ability_at_tier(cat["by_id"][REEL_ID], 1)
		_check(ambush_battle.get_foes().size() == 4 and int(intruder.get("rank", 0)) == 4
			and bool(intruder.get("walk_intruder", false))
			and StitchedParts.ranks_allowed(int(ambush_ability["target_mask"]), 4),
			"AC1: Reel Thread's authored target mask admits the supported rank-four intruder slot")
	for tier in [1, 2, 3]:
		var expected: Dictionary = REEL_SPECS["effects"][tier - 1]
		var b := _rank_four_foe_battle(REEL_ID, tier)
		_check(b != null,
			"AC2: fresh three-foe battle equips tier %d Reel Thread with a living foe at enemy rank 4"
				% tier)
		if b == null:
			continue
		var ranger := b.get_unit("yarn_ranger")
		var rear := b.get_unit("moth_scribe")
		_check(b.get_heroes().size() == 4 and b.get_foes().size() == 3
			and int(ranger["rank"]) == 3 and str(ranger["parts"]["legs"]["id"]) == REEL_ID
			and int(rear["rank"]) == 4 and int(rear["hp"]) > 0,
			"AC2: tier %d Ranger launches legally while the real fourth-rank foe lives" % tier)
		_check(_to(b, "yarn_ranger"),
			"AC2: Ranger reaches her actual scheduled turn for tier %d rank-four Reel Thread" % tier)
		if b.current_actor_id() != "yarn_ranger":
			continue
		# The illegal front rank is refused first on the same untouched turn and RNG.
		_reject_without_spend(b, REEL_ID, 1, "tier %d Reel Thread front-rank target" % tier)
		var before := b.state_snapshot()
		var receipt := b.use_part(REEL_ID, 4)
		var after := b.state_snapshot()
		var results: Array = receipt.get("results", [])
		_check(bool(receipt.get("ok", false)) and str(receipt.get("action", "")) == "ability"
			and str(receipt.get("actor", "")) == "yarn_ranger"
			and str(receipt.get("part", "")) == REEL_ID
			and str(receipt.get("ability", "")) == "yarn_ranger_legs_reel_thread_move"
			and results.size() == 1
			and str(results[0].get("target", "")) == "moth_scribe"
			and str(results[0].get("target_side", "")) == "foe"
			and int(results[0].get("target_rank", 0)) == 4
			and int(results[0].get("damage", -1)) == 0,
			"AC2: tier %d Reel Thread legally resolves on the enemy at rank four, one target and no damage: %s"
				% [tier, str(receipt.get("error", ""))])
		_check(after != before and (int(after["round"]) > int(before["round"])
			or (int(after["round"]) == int(before["round"])
				and int(after["turn_index"]) > int(before["turn_index"]))),
			"AC2: tier %d rank-four Reel Thread spends exactly one Ranger turn" % tier)
		var moved := b.get_unit("moth_scribe")
		_check(int(moved["rank"]) == 4 and int(moved["hp"]) == int(rear["hp"]),
			"AC2: tier %d Reel Thread neither pulls nor damages the rank-four foe" % tier)
		# A bounded explicit seed window witnesses a real hit that carries exactly the tier's
		# Tangled (plus Mark 1 at tier III), no HP damage, no displacement and no collateral
		# statuses; the same seed must replay the identical receipt, snapshot and RNG position.
		var witness_seed := -1
		for seed_value in range(507040, 507072):
			var shot_battle := _rank_four_foe_battle(REEL_ID, tier, seed_value)
			if shot_battle == null or not _to(shot_battle, "yarn_ranger"):
				continue
			var foe_before := shot_battle.get_unit("moth_scribe")
			var shot := shot_battle.use_part(REEL_ID, 4)
			if not bool(shot.get("ok", false)) or shot.get("results", []).size() != 1:
				continue
			var result: Dictionary = shot["results"][0]
			if not bool(result.get("hit", false)) \
					or str(result.get("target", "")) != "moth_scribe" \
					or int(result.get("target_rank", 0)) != 4:
				continue
			var statuses: Array = result.get("statuses", [])
			if not statuses.any(func(s): return str(s.get("status", "")) == "tangled"):
				continue
			if expected.has("mark") and not statuses.any(
					func(s): return str(s.get("status", "")) == "mark"):
				continue
			var foe := shot_battle.get_unit("moth_scribe")
			if int(foe["rank"]) != 4 or int(foe["hp"]) != int(foe_before["hp"]):
				continue
			if int(foe["statuses"].get("tangled", 0)) != int(expected["tangled"]) \
					or int(foe["statuses"].get("mark", 0)) != int(expected.get("mark", 0)):
				continue
			var collateral := false
			for other_id in ["fray_scavenger", "scissor_crab"]:
				var other := shot_battle.get_unit(other_id)
				if int(other["statuses"].get("tangled", 0)) != 0 \
						or int(other["statuses"].get("mark", 0)) != 0:
					collateral = true
			if collateral:
				continue
			var replay := _rank_four_foe_battle(REEL_ID, tier, seed_value)
			if replay == null or not _to(replay, "yarn_ranger"):
				continue
			var replay_shot := replay.use_part(REEL_ID, 4)
			if shot == replay_shot and shot_battle.state_snapshot() == replay.state_snapshot() \
					and shot_battle.rng_state() == replay.rng_state():
				witness_seed = seed_value
				break
		_check(witness_seed >= 0,
			"AC2: a bounded real seed shows tier %d Reel Thread hitting the rank-four foe with Tangled %d%s, no damage, no pull and an identical replay"
				% [tier, int(expected["tangled"]),
					" and Mark 1" if expected.has("mark") else ""])
		if witness_seed >= 0:
			print("AC2 Reel Thread rank-four foe tier %d witness seed %d" % [tier, witness_seed])


func _test_catalog() -> void:
	var cat := _catalog()
	_check(bool(cat.get("ok", false)), "AC1: complete Yarn Ranger JSON validates with StitchedParts")
	if not bool(cat.get("ok", false)):
		return
	var counts := {"head": 0, "arms": 0, "torso": 0, "legs": 0}
	var part_ids := {}
	var ability_ids := {}
	_check(cat["parts"].size() == 8, "AC1: dedicated eight-part Ranger catalog")
	for id in IDS:
		_check(cat["by_id"].has(id), "AC1: required original-card-inspired name: " + id)
	for part in cat["parts"]:
		var id := str(part["id"])
		var slot := str(part["slot"])
		_check(id in IDS and not part_ids.has(id) and str(part["owner"]) == "yarn_ranger",
			"AC1: unique Ranger part " + id)
		part_ids[id] = true
		if counts.has(slot):
			counts[slot] += 1
		var ability: Dictionary = part["ability"]
		var aid := str(ability["id"])
		_check(aid.begins_with("yarn_ranger_") and not ability_ids.has(aid),
			"AC1: separate unique ability ID for " + id)
		ability_ids[aid] = true
		_check(str(ability["move"]) in StitchedParts.MOVE_POSES
			and int(ability["launch_mask"]) == StitchedParts.rank_mask(ability["launch"])
			and int(ability["target_mask"]) == StitchedParts.rank_mask(ability["target"])
			and int(ability["launch_mask"]) > 0 and int(ability["target_mask"]) > 0
			and StitchedParts.ranks_allowed(int(ability["launch_mask"]), 3),
			"AC1: real launch/target rank masks and a valid move pose for " + id)
		_check(part["tiers"].has("2") and part["tiers"].has("3"),
			"AC1: authored tier II and III on " + id)
		var first := StitchedParts.ability_at_tier(part, 1)
		var second := StitchedParts.ability_at_tier(part, 2)
		var third := StitchedParts.ability_at_tier(part, 3)
		_check(first != second and second != third,
			"AC1: every tier changes ability mechanics for " + id)
		for tier in [1, 2, 3]:
			var ab := StitchedParts.ability_at_tier(part, tier)
			var stat := StitchedParts.stat_at_tier(part, tier)
			_check(bool(StitchedParts.validate_ability(ab).get("ok", false)) and not stat.is_empty(),
				"AC1: fully validated tier %d for %s" % [tier, id])
			for key in stat:
				_check(str(key) in StitchedParts.SLOT_STATS[slot],
					"AC1: slot-compatible stat at tier %d on %s" % [tier, id])
			for retired in ["draw", "block", "unravel", "pull_forward", "hit_count", "requires_target_status"]:
				_check(not ab.has(retired) and not ab["effects"].has(retired),
					"AC1: unsupported card-only claim %s absent on %s" % [retired, id])
	for head_id in HEAD_SPECS:
		var part: Dictionary = cat["by_id"][head_id]
		var spec: Dictionary = HEAD_SPECS[head_id]
		var ability: Dictionary = part["ability"]
		_check(str(part["slot"]) == "head" and str(part["owner"]) == "yarn_ranger"
			and part["stat"] == spec["stat"],
			"AC1: %s stays a Yarn Ranger head part with its authored stat" % head_id)
		_check(str(ability["id"]) == str(spec["ability"]) and str(ability["kind"]) == "ranged"
			and ability["launch"] == HEAD_LAUNCH
			and int(ability["launch_mask"]) == StitchedParts.rank_mask(HEAD_LAUNCH)
			and ability["target"] == spec["target"]
			and int(ability["target_mask"]) == StitchedParts.rank_mask(spec["target"])
			and str(ability["target_side"]) == "enemy" and not bool(ability["multi"])
			and int(ability["acc"]) == 93 and int(ability["crit"]) == 0
			and ability["dmg"] == spec["dmg"][0] and ability["effects"] == spec["effects"][0]
			and int(ability["mark_damage"]) == int(spec["mark_damage"][0])
			and int(ability["self_move"]) == 0 and str(ability["move"]) == "attack2",
			"AC1: %s keeps every authored value and its own target ranks" % head_id)
	_check(str(cat["by_id"][ALTERNATES["head"]]["text"]).contains("ALREADY-Marked foe harder"),
		"AC1: Needle Arrow's rules text says it hits an ALREADY-Marked foe harder")
	for other_id in UNCHANGED_PARTS:
		var other: Dictionary = cat["by_id"][other_id]
		var expected: Dictionary = UNCHANGED_PARTS[other_id]
		var other_ability: Dictionary = other["ability"]
		_check(other_ability["launch"] == expected["launch"]
			and other_ability["target"] == expected["target"]
			and str(other_ability["target_side"]) == str(expected["side"])
			and bool(other_ability["multi"]) == bool(expected["multi"])
			and int(other_ability["acc"]) == int(expected["acc"])
			and other_ability["dmg"] == expected["dmg"]
			and other_ability["effects"] == expected["effects"]
			and str(other_ability["move"]) == str(expected["move"])
			and int(other_ability.get("mark_damage", 0)) == 0
			and other["stat"] == expected["stat"],
			"AC1: %s keeps its authored launch, targets, numbers and stat" % other_id)
	for slot in counts:
		_check(int(counts[slot]) == 2 and str(cat["by_id"][STARTERS[slot]]["slot"]) == slot
			and str(cat["by_id"][ALTERNATES[slot]]["slot"]) == slot,
			"AC1: two catalog parts per slot, starter and nonstarter, at " + slot)
	for id in [ALTERNATES["torso"], ALTERNATES["legs"]]:
		var ab: Dictionary = cat["by_id"][id]["ability"]
		_check(bool(ab["multi"]) and ab["target"] == [1, 2, 3] and str(ab["target_side"]) == "enemy"
			and int(ab["effects"].get("tangled", 0)) > 0,
			"AC1: enemy-all Snare Net / Endless Skein use native multi Tangled")
	_check(str(cat["by_id"][STARTERS["torso"]]["ability"]["kind"]) == "guard",
		"AC1: Hood Knit maps old block/draw into an actual ally Guard ability")
	var bad_entries: Array = cat["parts"].duplicate(true)
	bad_entries.append(cat["parts"][0].duplicate(true))
	_check(not bool(StitchedParts.build_catalog(bad_entries).get("ok", false)),
		"AC3: duplicate part IDs fail closed")
	for invalid in ["draw", "block", "unravel"]:
		var malformed: Dictionary = cat["parts"][0].duplicate(true)
		var illegal_effects := {}
		illegal_effects[invalid] = 1
		malformed["ability"]["effects"] = illegal_effects
		_check(not bool(StitchedParts.validate_part(malformed).get("ok", false)),
			"AC3: unsupported %s is never admitted as a Ranger card translation" % invalid)
	var wrong_rank: Dictionary = cat["parts"][0].duplicate(true)
	wrong_rank["ability"]["target"] = [1, 5]
	_check(not bool(StitchedParts.validate_part(wrong_rank).get("ok", false)),
		"AC3: invalid target mask fails closed")
	for malformed_launch in [[2, 3, 4, 5], [2, 3, 4, 4]]:
		var malformed_head: Dictionary = cat["by_id"][STARTERS["head"]].duplicate(true)
		malformed_head["ability"]["launch"] = malformed_launch
		_check(not bool(StitchedParts.validate_part(malformed_head).get("ok", false)),
			"AC3: malformed head launch %s fails closed" % str(malformed_launch))
	for malformed_reel_launch in [[2, 3, 4, 5], [2, 3, 4, 4], [0, 2, 3, 4]]:
		var malformed_legs: Dictionary = cat["by_id"][REEL_ID].duplicate(true)
		malformed_legs["ability"]["launch"] = malformed_reel_launch
		_check(not bool(StitchedParts.validate_part(malformed_legs).get("ok", false)),
			"AC3: malformed Reel Thread launch %s fails closed" % str(malformed_reel_launch))
	for malformed_reel_targets in [[2, 5], [0, 2, 3], [2, 2], [2, 3, 4, 4]]:
		var malformed_reel_target: Dictionary = cat["by_id"][REEL_ID].duplicate(true)
		malformed_reel_target["ability"]["target"] = malformed_reel_targets
		_check(not bool(StitchedParts.validate_part(malformed_reel_target).get("ok", false)),
			"AC3: malformed Reel Thread target mask %s fails closed" % str(malformed_reel_targets))
	var wrong_tier: Dictionary = cat["parts"][0].duplicate(true)
	wrong_tier["tiers"]["4"] = {"ability": {"acc": 100}}
	_check(not bool(StitchedParts.validate_part(wrong_tier).get("ok", false)),
		"AC3: illegal authored tier IV fails closed")


## Every part in every tier must land its effect on a real scheduled Ranger turn.
## Search short independent seed windows to avoid treating a genuine 5% miss as pass.
func _test_each_tier() -> void:
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		return
	for id in IDS:
		for tier in [1, 2, 3]:
			var witnessed := false
			for seed_value in range(502500 + tier * 100, 502514 + tier * 100):
				var b := _battle(id, tier, seed_value)
				if b == null or not _to(b, "yarn_ranger"):
					continue
				var part: Dictionary = cat["by_id"][id]
				var ab := StitchedParts.ability_at_tier(part, tier)
				var target_rank := 2 if id == STARTERS["legs"] else 1
				var prior := b.state_snapshot()
				var result := b.use_part(id, target_rank)
				if not bool(result.get("ok", false)):
					continue
				var receipts: Array = result.get("results", [])
				var expected := 3 if bool(ab["multi"]) else 1
				if receipts.size() != expected or prior == b.state_snapshot():
					continue
				if str(result.get("actor", "")) != "yarn_ranger" or str(result.get("part", "")) != id \
						or str(result.get("ability", "")) != str(ab["id"]):
					continue
				var seen_targets: Dictionary = {}
				var good := true
				for item in receipts:
					var target_id := str(item.get("target", ""))
					seen_targets[target_id] = true
					if not bool(item.get("hit", false)):
						good = false
						break
					for effect in ab["effects"]:
						if not item.get("statuses", []).any(func(s): return str(s.get("status", "")) == str(effect)):
							good = false
					if str(ab["target_side"]) == "enemy":
						var foe := b.get_unit(target_id)
						for effect in ab["effects"]:
							if int(foe["statuses"].get(effect, 0)) < int(ab["effects"][effect]):
								good = false
						if int(ab["dmg"][1]) > 0 and (int(item.get("damage", 0)) <= 0
								or int(foe["hp"]) >= int(foe["max_hp"])):
							good = false
					elif str(ab["kind"]) == "guard":
						if str(b.get_unit("yarn_ranger")["guard_target"]) != "warden" \
								or int(b.get_unit("yarn_ranger")["statuses"].get("guard", 0)) < int(ab["effects"]["guard"]):
							good = false
				if bool(ab["multi"]):
					good = good and seen_targets.has("fray_scavenger") and seen_targets.has("scissor_crab") \
						and seen_targets.has("moth_scribe") and seen_targets.size() == 3
				if good:
					witnessed = true
					break
			_check(witnessed, "AC2: actual tier %d %s lands receipts, battle-state statuses/damage and advances turn" % [tier, id])


func _test_multi_tangled() -> void:
	for id in [ALTERNATES["torso"], ALTERNATES["legs"]]:
		var found := false
		for seed_value in range(503000, 503032):
			var b := _battle(id, 3, seed_value)
			if b == null or not _to(b, "yarn_ranger"):
				continue
			var action := b.use_part(id, 1)
			if not bool(action.get("ok", false)) or action.get("results", []).size() != 3:
				continue
			var actual := {}
			for receipt in action["results"]:
				var foe_id := str(receipt["target"])
				if bool(receipt["hit"]) and receipt["statuses"].any(func(s): return str(s.get("status", "")) == "tangled") \
						and int(b.get_unit(foe_id)["statuses"].get("tangled", 0)) >= 3:
					actual[foe_id] = true
			if actual.has("fray_scavenger") and actual.has("scissor_crab") and actual.has("moth_scribe"):
				found = true
				break
		_check(found, "AC2: tier-III %s applies actual Tangled to all three distinct foes" % id)


func _test_guard_interception() -> void:
	var found := false
	for seed_value in range(503100, 503140):
		var b := _battle(STARTERS["torso"], 2, seed_value)
		if b == null or not _to(b, "yarn_ranger"):
			continue
		var guard := b.use_part(STARTERS["torso"], 1)
		if not bool(guard.get("ok", false)) or str(b.get_unit("yarn_ranger")["guard_target"]) != "warden":
			continue
		if not _to(b, "fray_scavenger"):
			continue
		var warden_before := int(b.get_unit("warden")["hp"])
		var ranger_before := int(b.get_unit("yarn_ranger")["hp"])
		var strike := b.use_foe_ability("sack_swing", 1)
		found = bool(strike.get("ok", false)) and strike.get("results", []).size() == 1 \
			and str(strike["results"][0].get("guarded_by", "")) == "yarn_ranger" \
			and int(b.get_unit("warden")["hp"]) == warden_before \
			and int(b.get_unit("yarn_ranger")["hp"]) <= ranger_before
		if found:
			break
	_check(found, "AC2: enemy Sack Swing on Warden is redirected by actual Ranger Guard")


func _reject_without_spend(b: StitchedRules, part: String, rank: int, label: String) -> void:
	var turn := b.current_actor_id()
	var snapshot := b.state_snapshot()
	var rng := b.rng_state()
	var receipt := b.use_part(part, rank)
	_check(not bool(receipt.get("ok", false)) and not str(receipt.get("error", "")).is_empty()
		and b.current_actor_id() == turn and b.state_snapshot() == snapshot and b.rng_state() == rng,
		"AC3: %s refused without turn, state or RNG spend" % label)


func _test_invalid_and_no_spend() -> void:
	var config := _config()
	if config.is_empty():
		return
	config["heroes"][2]["parts"]["head"] = {"id": STARTERS["arms"], "tier": 1}
	_check(not bool(StitchedRules.create(config).get("ok", false)), "AC3: wrong equipment slot rejected")
	config = _config()
	config["heroes"][2]["parts"]["head"] = {"id": STARTERS["head"], "tier": 4}
	_check(not bool(StitchedRules.create(config).get("ok", false)), "AC3: equipped tier IV rejected")
	config = _config()
	config["heroes"][2]["parts"]["head"] = {"id": "yarn_ranger_missing", "tier": 1}
	_check(not bool(StitchedRules.create(config).get("ok", false)), "AC3: missing catalog part rejected")
	config = _config()
	config["heroes"][2]["parts"]["head"] = {"id": STARTERS["head"], "tier": 1, "torn": true}
	var torn := StitchedRules.create(config)
	_check(bool(torn.get("ok", false)), "AC3: real torn part admitted as equipment")
	if bool(torn.get("ok", false)):
		var torn_battle: StitchedRules = torn["battle"]
		_check(_to(torn_battle, "yarn_ranger"), "AC3: real torn Ranger gets a scheduled turn")
		if torn_battle.current_actor_id() == "yarn_ranger":
			_reject_without_spend(torn_battle, STARTERS["head"], 1, "torn part")
	var b := _battle()
	if b == null or not _to(b, "yarn_ranger"):
		_check(false, "AC3: valid active Ranger needed for negative actions")
		return
	_reject_without_spend(b, STARTERS["head"], 4, "enemy target rank 4 has no living foe")
	_reject_without_spend(b, STARTERS["arms"], 4, "Wool Bolas enemy target rank 4 has no living foe")
	_reject_without_spend(b, STARTERS["torso"], 0, "ally target rank 0 invalid")
	_reject_without_spend(b, STARTERS["legs"], 1, "reel thread cannot target front foe rank 1")
	_reject_without_spend(b, "missing_part", 1, "unequipped part")
	var snap := b.state_snapshot()
	var rng := b.rng_state()
	var turn := b.current_actor_id()
	var wrong_side := b.use_foe_ability("sack_swing", 1)
	_check(not bool(wrong_side.get("ok", false)) and b.state_snapshot() == snap
		and b.rng_state() == rng and b.current_actor_id() == turn,
		"AC3: wrong-side foe action rejected with full snapshot and RNG equality")
	var legal := b.use_part(STARTERS["head"], 1)
	_check(bool(legal.get("ok", false)), "AC3: legal action does spend Ranger turn")
	if bool(legal.get("ok", false)):
		_reject_without_spend(b, STARTERS["arms"], 1, "off-turn hero action")
	config = _config()
	var ranger: Dictionary = config["heroes"].pop_at(2)
	config["heroes"].append(ranger)
	var relocated := StitchedRules.create(config)
	_check(bool(relocated.get("ok", false)), "AC3: same real four-hero fixture allows Ranger rank four")
	if bool(relocated.get("ok", false)):
		var rear: StitchedRules = relocated["battle"]
		_check(_to(rear, "yarn_ranger"), "AC3: rank-four Ranger obtains real scheduled turn")
		if rear.current_actor_id() == "yarn_ranger":
			_reject_without_spend(rear, STARTERS["legs"], 4,
				"Reel Thread enemy target rank 4 has no living foe")
	var front := _rank_one_battle()
	_check(front != null, "AC3: same real four-hero fixture allows Ranger rank one")
	if front != null:
		var front_ranger := front.get_unit("yarn_ranger")
		_check(int(front_ranger["rank"]) == 1 and str(front_ranger["parts"]["arms"]["id"]) == BOLAS_ID,
			"AC3: front-rank Ranger wears the same Wool Bolas arms")
		_check(_to(front, "yarn_ranger"), "AC3: rank-one Ranger obtains real scheduled turn")
		if front.current_actor_id() == "yarn_ranger":
			_reject_without_spend(front, STARTERS["arms"], 1, "rank-one Wool Bolas launch")
	var front_legs := _rank_one_battle(STARTERS["legs"])
	_check(front_legs != null,
		"AC3: same real four-hero fixture allows Ranger rank one with Reel Thread")
	if front_legs != null:
		var legs_ranger := front_legs.get_unit("yarn_ranger")
		var legs_target := front_legs.get_unit("scissor_crab")
		_check(int(legs_ranger["rank"]) == 1
			and str(legs_ranger["parts"]["legs"]["id"]) == REEL_ID
			and int(legs_target["rank"]) == 2 and int(legs_target["hp"]) > 0,
			"AC3: rank-one Ranger wears Reel Thread while a living enemy waits at target rank two")
		_check(_to(front_legs, "yarn_ranger"),
			"AC3: rank-one Reel Thread Ranger obtains real scheduled turn")
		if front_legs.current_actor_id() == "yarn_ranger":
			_reject_without_spend(front_legs, STARTERS["legs"], 2, "rank-one Reel Thread launch")
	var rank_two := _rank_two_battle(PURLING_ID)
	_check(rank_two != null, "AC3: same real four-hero fixture allows Ranger rank two")
	if rank_two != null:
		var two_ranger := rank_two.get_unit("yarn_ranger")
		_check(int(two_ranger["rank"]) == 2
			and str(two_ranger["parts"]["arms"]["id"]) == PURLING_ID,
			"AC3: rank-two Ranger wears Purling Barrage in the arms slot")
		_check(_to(rank_two, "yarn_ranger"), "AC3: rank-two Ranger obtains real scheduled turn")
		if rank_two.current_actor_id() == "yarn_ranger":
			var front_foe := rank_two.get_unit("fray_scavenger")
			_check(int(front_foe["rank"]) == 1 and int(front_foe["hp"]) > 0,
				"AC3: rank-two Purling refusal still has a living enemy at target rank one")
			_reject_without_spend(rank_two, PURLING_ID, 1, "rank-two Purling Barrage launch")
	var rear_purling := _rank_four_battle(PURLING_ID)
	_check(rear_purling != null, "AC3: fresh rank-four Purling Barrage battle exists")
	if rear_purling != null:
		_check(_to(rear_purling, "yarn_ranger"),
			"AC3: rank-four Purling Ranger obtains real scheduled turn")
		if rear_purling.current_actor_id() == "yarn_ranger":
			_reject_without_spend(rear_purling, PURLING_ID, 4,
				"Purling Barrage enemy target rank 4 has no living foe")


func _trace(seed_value: int) -> Dictionary:
	var b := _battle("", 2, seed_value)
	if b == null:
		return {}
	var receipts: Array = []
	for action in [[STARTERS["head"], 1], [STARTERS["arms"], 2],
			[STARTERS["torso"], 1], [STARTERS["legs"], 2]]:
		if not _to(b, "yarn_ranger"):
			return {}
		receipts.append(b.use_part(str(action[0]), int(action[1])))
	return {"receipts": receipts, "state": b.state_snapshot(), "rng": b.rng_state()}


func _test_replay() -> void:
	var first := _trace(503999)
	var second := _trace(503999)
	_check(not first.is_empty() and first == second and first.get("receipts", []).size() == 4,
		"AC3: seeded four-action Ranger replay equals all receipts, snapshot and RNG")
	for receipt in first.get("receipts", []):
		_check(bool(receipt.get("ok", false)), "AC3: each real replayed action was legal")


## The four binding abilities use the existing start-of-turn countdown: landing two
## Tangled must still leave one at the victim's first real scheduled turn. Compare
## per-foe hit/miss receipts with actual state, not fabricated rolls or flags.
func _tangled_tick_trial(part_id: String, seed_value: int) -> Dictionary:
	var b := _battle(part_id, 1, seed_value)
	if b == null or not _to(b, "yarn_ranger"):
		return {}
	var multi: bool = part_id == SNARE_ID or part_id == ALTERNATES["legs"]
	var selected := ["fray_scavenger"]
	var rank := 1
	if part_id == REEL_ID:
		selected = ["scissor_crab"]
		rank = 2
	elif multi:
		selected = ["fray_scavenger", "scissor_crab", "moth_scribe"]
	var foe_ranks := {"fray_scavenger": 1, "scissor_crab": 2, "moth_scribe": 3}
	var ranger := b.get_unit("yarn_ranger")
	if b.get_heroes().size() != 4 or b.get_foes().size() != 3 \
			or int(ranger.get("rank", 0)) != 3 or b.current_actor_id() != "yarn_ranger":
		return {}
	for foe_id in foe_ranks:
		var foe := b.get_unit(foe_id)
		if foe.is_empty() or int(foe.get("rank", 0)) != int(foe_ranks[foe_id]) \
				or int(foe.get("hp", 0)) <= 0 \
				or int(foe.get("statuses", {}).get("tangled", 0)) != 0:
			return {}
	var before := b.state_snapshot()
	var receipt := b.use_part(part_id, rank)
	var results: Array = receipt.get("results", [])
	if not bool(receipt.get("ok", false)) or str(receipt.get("action", "")) != "ability" \
			or str(receipt.get("actor", "")) != "yarn_ranger" \
			or str(receipt.get("part", "")) != part_id \
			or results.size() != selected.size() or b.state_snapshot() == before:
		return {}
	var hits := {}
	var misses := {}
	for result in results:
		var foe_id := str(result.get("target", ""))
		if not foe_id in selected or hits.has(foe_id) or misses.has(foe_id) \
				or str(result.get("target_side", "")) != "foe" \
				or int(result.get("target_rank", 0)) != int(foe_ranks[foe_id]):
			return {}
		var status := int(b.get_unit(foe_id)["statuses"].get("tangled", 0))
		if bool(result.get("hit", false)):
			if not result.get("statuses", []).any(
					func(s): return str(s.get("status", "")) == "tangled" \
						and int(s.get("duration", 0)) == 2) \
					or not status in [1, 2]:
				return {}
			hits[foe_id] = true
		else:
			if result.get("statuses", []).any(
					func(s): return str(s.get("status", "")) == "tangled") or status != 0:
				return {}
			misses[foe_id] = true
	if hits.size() + misses.size() != selected.size():
		return {}
	# Non-selected foes are not collateral victims of the single-target bindings.
	for foe_id in foe_ranks:
		if not foe_id in selected and int(b.get_unit(foe_id)["statuses"].get("tangled", 0)) != 0:
			return {}
	# pass_turn enters the following actor's turn and performs its real status tick.
	# Capture each struck/missed foe on its FIRST upcoming turn, even across rounds.
	var pending := selected.duplicate()
	var at_tick := {}
	for _step in range(55):
		if b.is_over():
			return {}
		var actor := b.current_actor_id()
		if actor in pending:
			at_tick[actor] = int(b.get_unit(actor)["statuses"].get("tangled", 0))
			pending.erase(actor)
		if pending.is_empty():
			break
		if not bool(b.pass_turn().get("ok", false)):
			return {}
	if not pending.is_empty():
		return {}
	for foe_id in selected:
		if int(at_tick.get(foe_id, -1)) != (1 if hits.has(foe_id) else 0):
			return {}
	return {
		"receipt": receipt, "hits": hits.keys(), "misses": misses.keys(),
		"at_tick": at_tick, "state": b.state_snapshot(), "rng": b.rng_state(),
	}


func _test_tangled_next_turn() -> void:
	var cat := _catalog()
	_check(bool(cat.get("ok", false)), "AC1: real Ranger catalog available for Tangled turn witnesses")
	if not bool(cat.get("ok", false)):
		return
	for part_id in [BOLAS_ID, REEL_ID, SNARE_ID, ALTERNATES["legs"]]:
		var part: Dictionary = cat["by_id"][part_id]
		for tier in [1, 2, 3]:
			var ability := StitchedParts.ability_at_tier(part, tier)
			_check(int(ability["effects"].get("tangled", -1)) == tier + 1
				and (part_id != REEL_ID or tier != 3 or int(ability["effects"].get("mark", 0)) == 1),
				"AC1: %s tier %d has exact Tangled %d, keeping tier-III Reel Mark"
					% [part_id, tier, tier + 1])
		var valid_rank := 2 if part_id == REEL_ID else 1
		var front := _rank_one_battle(part_id, 1, 509120)
		_check(front != null, "AC3: real rank-one launch refusal battle exists for " + part_id)
		if front != null:
			_check(int(front.get_unit("yarn_ranger").get("rank", 0)) == 1
				and _to(front, "yarn_ranger"),
				"AC3: real rank-one Ranger reaches her turn for " + part_id)
			if front.current_actor_id() == "yarn_ranger":
				_reject_without_spend(front, part_id, valid_rank, part_id + " illegal rank-one launch")
		var invalid := _battle(part_id, 1, 509121)
		_check(invalid != null, "AC3: real target-refusal battle exists for " + part_id)
		if invalid != null:
			_check(_to(invalid, "yarn_ranger"),
				"AC3: Ranger reaches target-refusal turn for " + part_id)
			if invalid.current_actor_id() == "yarn_ranger":
				for bad_target in [0, 5, 1 if part_id == REEL_ID else 4]:
					_reject_without_spend(invalid, part_id, bad_target,
						part_id + " illegal enemy rank %d" % bad_target)
		var multi: bool = part_id == SNARE_ID or part_id == ALTERNATES["legs"]
		var hit_seed := -1
		var miss_seed := -1
		var mixed_seed := -1
		for seed_value in range(509200, 509300):
			var trial := _tangled_tick_trial(part_id, seed_value)
			_check(not trial.is_empty(),
				"AC2: %s seed %d resolves legal foes and first real Tangled tick" % [part_id, seed_value])
			if trial.is_empty():
				continue
			if hit_seed < 0 and not trial["hits"].is_empty():
				hit_seed = seed_value
				_check(trial == _tangled_tick_trial(part_id, seed_value),
					"AC3: %s landed seed %d replays exact receipts, next-turn state and RNG"
						% [part_id, seed_value])
			if miss_seed < 0 and not trial["misses"].is_empty():
				miss_seed = seed_value
				_check(trial == _tangled_tick_trial(part_id, seed_value),
					"AC3: %s natural miss seed %d replays exact receipts, state and RNG"
						% [part_id, seed_value])
			if multi and mixed_seed < 0 and not trial["hits"].is_empty() \
					and not trial["misses"].is_empty():
				mixed_seed = seed_value
			if hit_seed >= 0 and miss_seed >= 0 and (not multi or mixed_seed >= 0):
				break
		_check(hit_seed >= 0 and miss_seed >= 0,
			"AC2: %s has real tier-I hits (Tangled 1 next turn) and misses (no Tangled)"
				% part_id)
		if multi:
			_check(mixed_seed >= 0,
				"AC2: %s mixed-hit multi cast leaves only struck foes Tangled after their tick"
					% part_id)


## The same real S2 fixture authors the different doll whose ordinary scheduled attack must
## still find the exposed foe: Warden's Iron Helm Bash (it only adds Weak, so the exposure is
## never reapplied and the target takes no damage over time).
func _preview_parts() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_PATH))
	if not parsed is Dictionary:
		return {}
	var built := StitchedParts.build_catalog(parsed.get("parts", []))
	if not bool(built.get("ok", false)):
		return {}
	return built["by_id"]


## One completely real Needle Nock witness for the requested tier: the equipped Ranger lands a
## genuine seeded shot from her scheduled turn, the struck foe takes its own first scheduled
## turn (ordinary StitchedRules turns only, never a private tick), Warden then lands a real
## Iron Helm Bash on that same foe, and the foe keeps taking its natural turns until the
## Exposed counter runs out. Returns {} unless every step happened as authored.
func _needle_nock_reply_chain(tier: int, seed_value: int) -> Dictionary:
	var head_id := STARTERS["head"]
	var b := _battle(head_id, tier, seed_value)
	if b == null or not _to(b, "yarn_ranger") or b.current_actor_id() != "yarn_ranger":
		return {}
	var ranger := b.get_unit("yarn_ranger")
	var foe := b.get_unit("fray_scavenger")
	if int(ranger["rank"]) != 3 or str(ranger["parts"]["head"]["id"]) != head_id \
			or int(foe["rank"]) != 1 or int(foe["hp"]) <= 0:
		return {}
	var shot_before := b.state_snapshot()
	var shot := b.use_part(head_id, 1)
	var shot_after := b.state_snapshot()
	var results: Array = shot.get("results", [])
	if not bool(shot.get("ok", false)) or str(shot.get("action", "")) != "ability" \
			or str(shot.get("actor", "")) != "yarn_ranger" or str(shot.get("part", "")) != head_id \
			or str(shot.get("ability", "")) != "yarn_ranger_head_needle_nock_move" \
			or results.size() != 1:
		return {}
	var hit: Dictionary = results[0]
	if not bool(hit.get("hit", false)) or str(hit.get("target", "")) != "fray_scavenger" \
			or str(hit.get("target_side", "")) != "foe" or int(hit.get("target_rank", 0)) != 1:
		return {}
	var exposed_after := int(b.get_unit("fray_scavenger")["statuses"].get("exposed", 0))
	if exposed_after <= 0:
		return {}
	# Only ordinary scheduled turns from here on: the first real turn start of the victim ticks.
	if not _to(b, "fray_scavenger") or b.current_actor_id() != "fray_scavenger":
		return {}
	var at_first_tick := int(b.get_unit("fray_scavenger")["statuses"].get("exposed", 0))
	if at_first_tick != exposed_after - 1:
		return {}
	# A different doll's real scheduled turn must still find the seam open; nothing may have
	# reapplied it in between.
	if not _to(b, "warden") or b.current_actor_id() != "warden":
		return {}
	var warden := b.get_unit("warden")
	var target := b.get_unit("fray_scavenger")
	if int(warden["rank"]) != 1 or int(target["rank"]) != 1 or int(target["hp"]) <= 0:
		return {}
	var exposed_at_reply := int(target["statuses"].get("exposed", 0))
	if exposed_at_reply != at_first_tick:
		return {}
	var hp_before := int(target["hp"])
	var reply := b.use_part("warden_head_iron_helm", 1)
	var reply_results: Array = reply.get("results", [])
	if not bool(reply.get("ok", false)) or reply_results.size() != 1:
		return {}
	var landed: Dictionary = reply_results[0]
	var damaged := int(landed.get("damage", 0))
	if not bool(landed.get("hit", false)) or str(landed.get("target", "")) != "fray_scavenger" \
			or damaged <= 0 or int(landed.get("target_hp", -1)) != hp_before - damaged:
		return {}
	var after_reply := b.get_unit("fray_scavenger")
	if after_reply.is_empty() or int(after_reply["hp"]) <= 0:
		return {}
	# The counter now has to run out on the foe's later natural turn starts, unaided.
	var expiry: Array = []
	for _step in range(120):
		if expiry.size() >= exposed_after - 1:
			break
		if b.is_over():
			return {}
		if b.current_actor_id() == "fray_scavenger":
			expiry.append(int(b.get_unit("fray_scavenger")["statuses"].get("exposed", 0)))
		if not bool(b.pass_turn().get("ok", false)):
			return {}
	if expiry.size() != exposed_after - 1:
		return {}
	return {
		"ok": true,
		"shot": shot,
		"shot_before": shot_before,
		"shot_after": shot_after,
		"exposed_after": exposed_after,
		"at_first_tick": at_first_tick,
		"foe_statuses": target["statuses"].duplicate(true),
		"foe_prot": int(target["prot"]),
		"hp_before_reply": hp_before,
		"exposed_at_reply": exposed_at_reply,
		"reply": reply,
		"reply_crit": bool(landed.get("crit", false)),
		"reply_damage": damaged,
		"reply_target_hp": int(landed.get("target_hp", -1)),
		"warden_bonus": int(warden["dmg_bonus"]),
		"warden_resolve": str(warden.get("resolve", "")),
		"expiry": expiry,
		"state": b.state_snapshot(),
		"rng": b.rng_state(),
	}


## The task goal: Needle Nock's Exposed must survive the struck foe's own first turn so a real
## ally can exploit it. At tiers I/II/III the catalog resolves Exposed 2/2/3; one bounded seed
## per tier gives a genuine landed shot, the foe's first natural turn start leaves 1/1/2, a
## different doll's real hit then deals exactly the documented 3/2 direct damage before PROT,
## and the status expires at the foe's second/second/third natural tick with no reapplication.
func _test_needle_nock_exposed_reply() -> void:
	var cat := _catalog()
	_check(bool(cat.get("ok", false)), "AC1: real Ranger catalog available for Needle Nock timing")
	if not bool(cat.get("ok", false)):
		return
	var head_id := STARTERS["head"]
	var preview := _preview_parts()
	var warden_head: Dictionary = preview.get("warden_head_iron_helm", {})
	_check(not warden_head.is_empty(),
		"AC2: the same real S2 fixture authors Warden's Iron Helm follow-up attack")
	if warden_head.is_empty():
		return
	var warden_ability := StitchedParts.ability_at_tier(warden_head, 1)
	# The authored file itself, not just the merged tier view: tier II stays a damage-only
	# override, so I/II/III inherit exactly 2/2/3 and the part text is untouched.
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	var raw_record: Dictionary = {}
	if raw is Dictionary:
		for entry in raw.get("parts", []):
			if entry is Dictionary and str(entry.get("id", "")) == head_id:
				raw_record = entry
	var raw_effects := int(raw_record.get("ability", {}).get("effects", {}).get("exposed", 0))
	var t2_keys: Array = raw_record.get("tiers", {}).get("2", {}).get("ability", {}).keys()
	var t3_ability: Dictionary = raw_record.get("tiers", {}).get("3", {}).get("ability", {})
	var t3_dmg: Array = t3_ability.get("dmg", [])
	var t3_effects := int(t3_ability.get("effects", {}).get("exposed", 0))
	_check(not raw_record.is_empty() and raw_effects == 2 and t2_keys == ["dmg"]
		and t3_dmg.size() == 2 and int(t3_dmg[0]) == 7 and int(t3_dmg[1]) == 10
		and t3_effects == 3
		and str(raw_record.get("text", "")) == "Nock a threaded needle and pierce a foe's defences, leaving it Exposed.",
		"AC1: authored Needle Nock keeps a damage-only tier II so tiers I/II/III resolve Exposed 2/2/3")
	for tier in [1, 2, 3]:
		var expected := int(HEAD_SPECS[head_id]["effects"][tier - 1]["exposed"])
		var ability := StitchedParts.ability_at_tier(cat["by_id"][head_id], tier)
		_check(int(ability["effects"].get("exposed", 0)) == expected
			and expected == [2, 2, 3][tier - 1],
			"AC1: Needle Nock tier %d resolves Exposed %d for a real surviving reply"
				% [tier, expected])
		var chain: Dictionary = {}
		var witness_seed := -1
		for seed_value in range(510040, 510136):
			chain = _needle_nock_reply_chain(tier, seed_value)
			if not bool(chain.get("ok", false)) or int(chain["exposed_after"]) != expected:
				continue
			witness_seed = seed_value
			break
		_check(witness_seed >= 0,
			"AC2: a bounded real seed shows tier %d Needle Nock Exposed %d surviving the foe's first turn and boosting a real ally hit"
				% [tier, expected])
		if witness_seed < 0:
			continue
		print("AC2 Needle Nock Exposed reply tier %d witness seed %d" % [tier, witness_seed])
		var shot: Dictionary = chain["shot"]
		var shot_result: Dictionary = shot["results"][0]
		_check(str(shot_result.get("target", "")) == "fray_scavenger"
			and int(shot_result.get("damage", 0)) > 0
			and shot_result.get("statuses", []).any(
				func(s): return str(s.get("status", "")) == "exposed" \
					and int(s.get("duration", 0)) == expected)
			and int(chain["exposed_after"]) == expected,
			"AC2: tier %d landed Needle Nock really leaves Exposed %d on its legal rank-one foe"
				% [tier, expected])
		_check(int(chain["shot_after"]["turn_index"]) != int(chain["shot_before"]["turn_index"])
			or int(chain["shot_after"]["round"]) != int(chain["shot_before"]["round"]),
			"AC2: tier %d Needle Nock spends exactly the Ranger's real scheduled turn" % tier)
		# The foe's own first scheduled turn start, not a private countdown call, must leave one
		# point of Exposed for the following ally.
		_check(int(chain["at_first_tick"]) == expected - 1,
			"AC2: tier %d Exposed %d becomes %d at the struck foe's real first turn start"
				% [tier, expected, expected - 1])
		var statuses: Dictionary = chain["foe_statuses"]
		_check(int(statuses.get("exposed", 0)) == expected - 1 and statuses.size() == 1,
			"AC2: tier %d only the shot's own Exposed remains on the foe at the ally's turn"
				% tier)
		_check(str(chain["warden_resolve"]) == "",
			"AC2: tier %d the Warden's reply is an ordinary attack with no resolve modifier" % tier)
		# Warden's real Iron Helm Bash: reconstruct the raw roll from the authored range and its
		# flat arms bonus, then require exactly the documented 3/2 before the PROT cut.
		var bonus := int(chain["warden_bonus"])
		var prot := int(chain["foe_prot"])
		var damaged := int(chain["reply_damage"])
		var base := -1
		if bool(chain["reply_crit"]):
			var crit_base := StitchedRules.crit_damage(int(warden_ability["dmg"][1])) + bonus
			if StitchedRules.damage_after_modifiers(
					crit_base, {}, {"exposed": 1}, false, 0, prot) == damaged:
				base = crit_base
		else:
			for candidate in range(int(warden_ability["dmg"][0]) + bonus,
					int(warden_ability["dmg"][1]) + bonus + 1):
				if StitchedRules.damage_after_modifiers(
						candidate, {}, {"exposed": 1}, false, 0, prot) == damaged:
					base = candidate
					break
		_check(base >= 0,
			"AC2: tier %d the Warden's real hit deals the exposed 3/2 damage before PROT" % tier)
		if base >= 0:
			var plain := StitchedRules.damage_after_modifiers(base, {}, {}, false, 0, prot)
			_check(plain < damaged
				and damaged == StitchedRules.damage_after_modifiers(
					base, {}, {"exposed": 1}, false, 0, prot)
				and int(chain["reply_target_hp"]) == int(chain["hp_before_reply"]) - damaged,
				"AC2: tier %d the exploiting hit gains the documented 50%% over the unexposed hit"
					% tier)
		var expiry: Array = chain["expiry"]
		var expected_expiry: Array = []
		for step in range(expected - 1):
			expected_expiry.append(maxi(0, expected - 1 - (step + 1)))
		_check(expiry == expected_expiry,
			"AC2: tier %d Exposed expires at the foe's natural tick %d and not earlier: %s"
				% [tier, expected, str(expiry)])
		_check(_needle_nock_reply_chain(tier, witness_seed) == chain,
			"AC4: tier %d equal seed and actions replay identical receipts, states and RNG" % tier)
	# A genuine seeded miss never exposes a foe but still spends the Ranger's legal action.
	var miss_seed := -1
	for seed_value in range(511040, 511120):
		var missed := _battle(head_id, 1, seed_value)
		if missed == null or not _to(missed, "yarn_ranger") \
				or missed.current_actor_id() != "yarn_ranger":
			continue
		var before := missed.state_snapshot()
		var shot := missed.use_part(head_id, 1)
		var results: Array = shot.get("results", [])
		if not bool(shot.get("ok", false)) or results.size() != 1 \
				or bool(results[0].get("hit", false)):
			continue
		var any_exposed := false
		for foe in missed.get_foes():
			any_exposed = any_exposed or int(foe["statuses"].get("exposed", 0)) > 0
		var spent := missed.state_snapshot() != before \
			and missed.current_actor_id() != "yarn_ranger"
		miss_seed = seed_value if not any_exposed and spent else -1
		if miss_seed >= 0:
			_check(int(results[0].get("damage", -1)) == 0
				and str(results[0].get("target", "")) == "fray_scavenger",
				"AC3: a genuine Needle Nock miss deals no damage to its legal target")
			break
	_check(miss_seed >= 0,
		"AC3: a bounded real seed shows a genuine Needle Nock miss exposing no foe while spending the turn")
	# Fail-closed refusals: torn, unequipped, rank-one launch, illegal target ranks and off-turn.
	var torn_config := _config(head_id, 1, 512040)
	if not torn_config.is_empty():
		torn_config["heroes"][2]["parts"]["head"]["torn"] = true
		var torn := StitchedRules.create(torn_config)
		_check(bool(torn.get("ok", false)), "AC3: real torn Needle Nock admitted as equipment")
		if bool(torn.get("ok", false)):
			var torn_battle: StitchedRules = torn["battle"]
			_check(_to(torn_battle, "yarn_ranger"),
				"AC3: torn Needle Nock Ranger obtains a real scheduled turn")
			if torn_battle.current_actor_id() == "yarn_ranger":
				_reject_without_spend(torn_battle, head_id, 1, "torn Needle Nock")
	var front := _rank_one_battle(head_id, 1, 512041)
	_check(front != null, "AC3: real fixture allows rank-one Ranger with Needle Nock")
	if front != null:
		_check(int(front.get_unit("yarn_ranger")["rank"]) == 1 and _to(front, "yarn_ranger"),
			"AC3: rank-one Needle Nock Ranger obtains a real scheduled turn")
		if front.current_actor_id() == "yarn_ranger":
			_check(int(front.get_unit("fray_scavenger")["rank"]) == 1
				and int(front.get_unit("fray_scavenger")["hp"]) > 0,
				"AC3: rank-one refusal still faces a living enemy at the legal target rank")
			_reject_without_spend(front, head_id, 1, "rank-one Needle Nock launch")
	var live := _battle(head_id, 1, 512042)
	_check(live != null and _to(live, "yarn_ranger"),
		"AC3: real Needle Nock battle reaches its scheduled turn for refusals")
	if live != null and live.current_actor_id() == "yarn_ranger":
		var statuses_before := {}
		for foe in live.get_foes():
			statuses_before[str(foe["id"])] = foe["statuses"].duplicate(true)
		for bad_rank in [0, 4, 5]:
			_reject_without_spend(live, head_id, bad_rank,
				"Needle Nock enemy target rank %d" % bad_rank)
		_reject_without_spend(live, "yarn_ranger_head_needle_arrow", 1,
			"unequipped Needle Nock")
		var untouched := true
		for foe in live.get_foes():
			untouched = untouched and foe["statuses"] == statuses_before[str(foe["id"])]
		_check(untouched, "AC3: refused Needle Nock attempts expose no foe at all")
		var legal := live.use_part(head_id, 1)
		_check(bool(legal.get("ok", false)), "AC3: a legal Needle Nock still spends the turn")
		if bool(legal.get("ok", false)):
			_reject_without_spend(live, head_id, 1, "off-turn Needle Nock")
