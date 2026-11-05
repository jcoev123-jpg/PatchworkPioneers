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
	"effects": [{"tangled": 1}, {"tangled": 2}, {"tangled": 3}],
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
	"effects": [{"tangled": 1}, {"tangled": 2}, {"tangled": 3}],
}
const HEAD_SPECS := {
	"yarn_ranger_head_needle_nock": {
		"ability": "yarn_ranger_head_needle_nock_move",
		"stat": {"acc": 3},
		"dmg": [[4, 6], [5, 8], [7, 10]],
		"effects": [{"exposed": 1}, {"exposed": 1}, {"exposed": 2}],
	},
	"yarn_ranger_head_needle_arrow": {
		"ability": "yarn_ranger_head_needle_arrow_move",
		"stat": {"crit": 3},
		"dmg": [[5, 7], [7, 9], [9, 11]],
		"effects": [{"mark": 1}, {"mark": 2}, {"mark": 3}],
	},
}
const UNCHANGED_PARTS := {
	"yarn_ranger_arms_wool_bolas": {
		"launch": [2, 3, 4], "target": [1, 2, 3], "side": "enemy", "multi": false,
		"acc": 92, "dmg": [2, 4], "effects": {"tangled": 1}, "move": "attack",
		"stat": {"dmg": 1},
	},
	"yarn_ranger_legs_reel_thread": {
		"launch": [2, 3], "target": [2, 3], "side": "enemy", "multi": false,
		"acc": 94, "dmg": [0, 0], "effects": {"tangled": 1}, "move": "skill",
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
		"acc": 94, "dmg": [0, 0], "effects": {"tangled": 1}, "move": "skill",
		"stat": {"prot": 5, "max_hp": 3},
	},
	"yarn_ranger_legs_endless_skein": {
		"launch": [2, 3], "target": [1, 2, 3], "side": "enemy", "multi": true,
		"acc": 94, "dmg": [3, 5], "effects": {"tangled": 1}, "move": "attack2",
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
	_test_each_tier()
	_test_rank_four_head_launch()
	_test_rank_four_bolas_launch()
	_test_rank_four_purling_launch()
	_test_rank_four_snare_net_launch()
	_test_multi_tangled()
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


## Both needle-bow HEAD abilities keep their authored numbers at every tier while the launch
## mask gains hero rank four. Ranks 1, 0 and 5 stay illegal launches.
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
			_check(ability["dmg"] == spec["dmg"][tier - 1]
				and ability["effects"] == spec["effects"][tier - 1]
				and int(ability["acc"]) == 93 and ability["target"] == [1, 2, 3],
				"AC2: tier %d %s keeps authored damage, status, ACC and enemy targets"
					% [tier, head_id])


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
			and ability["target"] == [1, 2, 3]
			and str(ability["target_side"]) == "enemy" and not bool(ability["multi"])
			and int(ability["acc"]) == 93 and int(ability["crit"]) == 0
			and ability["dmg"] == spec["dmg"][0] and ability["effects"] == spec["effects"][0]
			and int(ability["self_move"]) == 0 and str(ability["move"]) == "attack2",
			"AC1: %s keeps every authored value except the rank-four launch" % head_id)
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
			_reject_without_spend(rear, STARTERS["legs"], 2, "rank-four Reel Thread launch illegal")
	var front := _rank_one_battle()
	_check(front != null, "AC3: same real four-hero fixture allows Ranger rank one")
	if front != null:
		var front_ranger := front.get_unit("yarn_ranger")
		_check(int(front_ranger["rank"]) == 1 and str(front_ranger["parts"]["arms"]["id"]) == BOLAS_ID,
			"AC3: front-rank Ranger wears the same Wool Bolas arms")
		_check(_to(front, "yarn_ranger"), "AC3: rank-one Ranger obtains real scheduled turn")
		if front.current_actor_id() == "yarn_ranger":
			_reject_without_spend(front, STARTERS["arms"], 1, "rank-one Wool Bolas launch")
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
