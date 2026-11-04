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
	# AC1: only the two named base launches grow to hero rank 4; every other authored launch,
	# every tier and every named ability number stays exactly as shipped.
	var expected_launches := {
		"tinker_head_cog_shot": [2, 3, 4],
		"tinker_arms_scrap_bomb": [3, 4],
		"tinker_torso_casing_ward": [1, 2, 3],
		"tinker_legs_tune_up": [1, 2, 3, 4],
		"tinker_head_spring_clamp": [2, 3],
		"tinker_arms_overload": [2, 3],
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
	var expected_shots := {
		"tinker_head_cog_shot": {"acc": [91, 91, 95], "dmg": [[4, 6], [5, 8], [7, 10]], "mark": [2, 3, 3], "multi": false},
		"tinker_arms_scrap_bomb": {"acc": [90, 92, 95], "dmg": [[3, 4], [4, 6], [5, 7]], "mark": [0, 0, 0], "multi": true},
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
