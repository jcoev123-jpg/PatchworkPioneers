extends SceneTree
## S5 boss-trophy contract: Behemoth Heart may mend an ally from any hero rank 1-4.
##
## The real enemy-parts catalog is loaded through StitchedParts. For each stitch tier I/II/III
## the authored launch list must be the explicit ranks [1,2,3,4] (never the old [1,4] pair), and
## the derived launch mask must allow ranks 1-4 while still rejecting 0 and 5.
##
## The battle cases build the shipped four-hero/three-foe S2 preview with the real catalog
## appended, equip the trophy in the acting hero's torso slot, wound one living ally, and drive
## the actual public StitchedRules.use_part() API from hero rank 2 and rank 3 at every tier.
## Failed actions are compared against state_snapshot, rng_state and current_actor_id so a
## rejection can never silently spend the turn or the seeded RNG.

const ENEMY_PATH := "res://data/parts/enemy_parts.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const PART_ID := "patchwork_behemoth_heart_torso"
const ABILITY_ID := "behemoth_heart"
const ALL_RANKS := [1, 2, 3, 4]
const HEALS := [6, 7, 8]
const STATS := [
	{"max_hp": 8, "prot": 6},
	{"max_hp": 10, "prot": 7},
	{"max_hp": 12, "prot": 8},
]
## Earlier enemy-drop parts that must stay present and identifiable, checked by id.
const OTHER_PARTS := {
	"scissor_crab_claw_arm": ["Scissor Claw", "arms", "snip"],
	"moth_swarm_wings": ["Tatter Wings", "legs", "flutter_back"],
	"felt_bulwark_button_shield": ["Button Shield Torso", "torso", "button_shield"],
}

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_catalog()
	for tier in [1, 2, 3]:
		for actor_rank in [2, 3]:
			_test_heal(tier, actor_rank, 20)
			_test_heal(tier, actor_rank, 3)
	_test_negative_gates()
	_test_replay()
	for failure in failures:
		printerr(failure)
	print("stitched_s3_behemoth_heart_middle_rank_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _catalog() -> Dictionary:
	return StitchedParts.load_catalog(ENEMY_PATH)


# ---------------------------------------------------------------- catalog

func _test_catalog() -> void:
	var catalog := _catalog()
	_check(bool(catalog.get("ok", false)),
		"AC1: the real enemy-parts catalog loads: " + str(catalog.get("error", "")))
	if not bool(catalog.get("ok", false)):
		return
	_check(catalog["by_id"].has(PART_ID), "AC1: the named Behemoth Heart trophy is present")
	if not catalog["by_id"].has(PART_ID):
		return
	var part: Dictionary = catalog["by_id"][PART_ID]
	_check(str(part["name"]) == "Behemoth Heart" and str(part["slot"]) == "torso"
		and str(part["owner"]) == "any", "AC4: the trophy keeps its name, torso slot and owner any")
	_check(str(part["text"]) == "Pump a heavy stitched heart and mend an ally for 6.",
		"AC4: the trophy keeps its short rules text")
	var full_mask := StitchedParts.rank_mask(ALL_RANKS)
	_check(full_mask == StitchedParts.ALL_RANKS_MASK, "AC1: ranks 1-4 form the full rank mask")
	for tier in [1, 2, 3]:
		var ability := StitchedParts.ability_at_tier(part, tier)
		var stat := StitchedParts.stat_at_tier(part, tier)
		var label := "AC1: Behemoth Heart tier %d" % tier
		_check(bool(StitchedParts.validate_ability(ability).get("ok", false)),
			label + " resolves to a valid ability")
		_check(ability["launch"] == ALL_RANKS,
			label + " launches from the explicit full-rank list [1,2,3,4]")
		_check(int(ability["launch_mask"]) == full_mask
			and StitchedParts.rank_mask(ability["launch"]) == full_mask,
			label + " derives the full-rank launch mask")
		for rank in ALL_RANKS:
			_check(StitchedParts.ranks_allowed(int(ability["launch_mask"]), rank),
				label + " allows launch rank " + str(rank))
		for rank in [0, 5]:
			_check(not StitchedParts.ranks_allowed(int(ability["launch_mask"]), rank),
				label + " rejects launch rank " + str(rank))
		_check(ability["target"] == ALL_RANKS and int(ability["target_mask"]) == full_mask,
			label + " still targets living allies in ranks 1-4")
		_check(str(ability["id"]) == ABILITY_ID and str(ability["name"]) == "Behemoth Heart",
			label + " keeps its ability identity")
		_check(str(ability["kind"]) == "heal" and str(ability["target_side"]) == "ally",
			label + " stays a single-side ally heal")
		_check(not bool(ability["multi"]) and int(ability["acc"]) == 100
			and ability["dmg"] == [0, 0] and int(ability["crit"]) == 0,
			label + " keeps multi false, ACC 100, DMG [0,0] and crit 0")
		_check(int(ability["self_move"]) == 0 and str(ability["move"]) == "skill",
			label + " keeps self_move 0 and the skill pose")
		_check(ability["effects"] == {"heal": HEALS[tier - 1]},
			label + " keeps its authored heal " + str(HEALS[tier - 1]))
		_check(stat == STATS[tier - 1],
			label + " keeps its authored max_hp/prot stat " + str(STATS[tier - 1]))
	for other_id in OTHER_PARTS:
		_check(catalog["by_id"].has(other_id),
			"AC4: earlier named enemy part stays present: " + other_id)
		if not catalog["by_id"].has(other_id):
			continue
		var other: Dictionary = catalog["by_id"][other_id]
		var expected: Array = OTHER_PARTS[other_id]
		_check(str(other["name"]) == str(expected[0]) and str(other["slot"]) == str(expected[1])
			and str(other["ability"]["id"]) == str(expected[2]),
			"AC4: earlier named enemy part stays unchanged: " + other_id)


# ---------------------------------------------------------------- fixtures

func _base_config(seed_value: int) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_PATH))
	if not parsed is Dictionary:
		_check(false, "the shipped S2 4v3 preview configuration exists")
		return {}
	var config: Dictionary = parsed
	var accepted := _catalog()
	if not bool(accepted.get("ok", false)):
		_check(false, "the real catalog appends to the battle config: "
			+ str(accepted.get("error", "")))
		return {}
	config["parts"].append_array(accepted["parts"])
	config["seed"] = seed_value
	return config


func _hero_at_rank(b: StitchedRules, rank: int) -> Dictionary:
	for hero in b.get_heroes():
		if int(hero["rank"]) == rank and not bool(hero["lost"]):
			return hero
	return {}


## Fresh real 4v3 battle where the hero in actor_rank (2 or 3) has SPEED 100, so its own
## turn is legally first. The actor wears the real trophy in its torso slot. A living ally in
## another rank is wounded by `missing` HP without ever reaching LOST or Hanging.
func _battle(
	tier: int, actor_rank: int, missing: int, seed_value: int = 733, equip: bool = true
) -> StitchedRules:
	var config := _base_config(seed_value)
	if config.is_empty():
		return null
	var actor_index := actor_rank - 1
	var actor_id := str(config["heroes"][actor_index]["id"])
	if equip:
		config["heroes"][actor_index]["parts"]["torso"] = {"id": PART_ID, "tier": tier}
	for index in range(config["heroes"].size()):
		config["heroes"][index]["speed"] = 100 if index == actor_index else 0
	for foe in config["foes"]:
		foe["speed"] = 0
	var created := StitchedRules.create(config)
	_check(bool(created.get("ok", false)),
		"AC2: the real catalog forms a valid 4v3 battle: " + str(created.get("error", "")))
	if not bool(created.get("ok", false)):
		return null
	var b: StitchedRules = created["battle"]
	_check(b.get_heroes().size() == 4 and b.get_foes().size() == 3,
		"AC2: the shipped four heroes and three foes are present")
	_check(b.current_actor_id() == actor_id and b.current_side() == "hero",
		"AC2: the rank-%d wearer's own turn is first" % actor_rank)
	if equip:
		var actor := b.get_unit(actor_id)
		_check(str(actor["parts"]["torso"]["id"]) == PART_ID
			and int(actor["parts"]["torso"]["tier"]) == tier
			and not bool(actor["parts"]["torso"]["torn"]),
			"AC2: the wearer has an untorn Behemoth Heart torso at tier %d" % tier)
	if missing > 0:
		var target_rank := 1 if actor_rank != 1 else 2
		var ally := _hero_at_rank(b, target_rank)
		_check(not ally.is_empty() and str(ally["id"]) != actor_id,
			"AC2: a different living ally stands in target rank %d" % target_rank)
		if ally.is_empty():
			return b
		ally["hp"] = int(ally["max_hp"]) - missing
		_check(int(ally["hp"]) > 0 and not bool(ally["hanging"]) and not bool(ally["lost"]),
			"AC2: the wounded ally stays a living, non-Hanging target")
	return b


func _hp_map(b: StitchedRules) -> Dictionary:
	var hp := {}
	for hero in b.get_heroes():
		hp[str(hero["id"])] = int(hero["hp"])
	for foe in b.get_foes():
		hp[str(foe["id"])] = int(foe["hp"])
	return hp


func _rank_map(b: StitchedRules) -> Dictionary:
	var ranks := {}
	for hero in b.get_heroes():
		ranks[str(hero["id"])] = int(hero["rank"])
	for foe in b.get_foes():
		ranks[str(foe["id"])] = int(foe["rank"])
	return ranks


func _statuses(receipt: Dictionary) -> Array:
	return receipt.get("results", [])[0].get("statuses", []) if not receipt.get("results", []).is_empty() else []


# ---------------------------------------------------------------- middle-rank heals

func _test_heal(tier: int, actor_rank: int, missing: int) -> void:
	var b := _battle(tier, actor_rank, missing)
	if b == null:
		return
	var actor_id := b.current_actor_id()
	var actor := b.get_unit(actor_id)
	var target_rank := 1 if actor_rank != 1 else 2
	var target := _hero_at_rank(b, target_rank)
	var label := "AC2: tier %d heal from rank %d (missing %d)" % [tier, actor_rank, missing]
	if target.is_empty() or str(target["id"]) == actor_id:
		_check(false, label + " needs a different living ally in its target rank")
		return
	var target_id := str(target["id"])
	var expected := mini(missing, HEALS[tier - 1])
	var hp_before := _hp_map(b)
	var ranks_before := _rank_map(b)
	var snapshot_before := b.state_snapshot()
	var rng_before := b.rng_state()
	var ability := StitchedParts.ability_at_tier(_catalog()["by_id"][PART_ID], tier)
	_check(StitchedParts.ranks_allowed(int(ability["launch_mask"]), actor_rank),
		label + " is a legal launch rank in the real derived mask")
	for rank in [1, 4]:
		_check(StitchedParts.ranks_allowed(int(ability["launch_mask"]), rank),
			label + " keeps the original launch rank " + str(rank) + " allowed")
	var receipt := b.use_part(PART_ID, target_rank)
	_check(bool(receipt.get("ok", false)), label + " is one successful use_part action")
	if not bool(receipt.get("ok", false)):
		return
	_check(str(receipt.get("action", "")) == "ability" and str(receipt.get("actor", "")) == actor_id,
		label + " spends the acting hero's action")
	_check(str(receipt.get("part", "")) == PART_ID
		and str(receipt.get("ability", "")) == ABILITY_ID,
		label + " names the equipped trophy and its ability")
	_check(str(receipt.get("target", "")) == target_id,
		label + " resolves on the wounded ally")
	var results: Array = receipt.get("results", [])
	_check(results.size() == 1 and bool(results[0].get("hit", false))
		and str(results[0].get("target", "")) == target_id
		and int(results[0].get("target_rank", -1)) == target_rank,
		label + " resolves exactly one healing hit on the intended rank")
	_check(_statuses(receipt) == [{"status": "heal", "amount": expected}],
		label + " heals exactly min(missing HP, %d) = %d" % [HEALS[tier - 1], expected])
	_check(not receipt.has("self_move"), label + " never moves the acting doll")
	var hp_after := _hp_map(b)
	for unit_id in hp_before:
		if unit_id == target_id:
			_check(int(hp_after[unit_id]) == int(hp_before[unit_id]) + expected,
				label + " raises only the target's HP by the healed amount")
		else:
			_check(int(hp_after[unit_id]) == int(hp_before[unit_id]),
				label + " leaves " + unit_id + " HP untouched")
	for foe in b.get_foes():
		_check(int(foe["hp"]) == int(hp_before[str(foe["id"])]),
			label + " deals no damage to foe " + str(foe["id"]))
	_check(_rank_map(b) == ranks_before, label + " leaves every rank in place")
	var after_snapshot := b.state_snapshot()
	_check(int(after_snapshot["turn_index"]) == int(snapshot_before["turn_index"]) + 1
		and int(after_snapshot["round"]) == int(snapshot_before["round"]),
		label + " advances exactly one turn")
	_check(b.current_actor_id() != actor_id and not b.is_over(),
		label + " hands the turn to another unit")
	_check(b.rng_state() == rng_before,
		label + " heals without borrowing any seeded RNG")


# ---------------------------------------------------------------- failure gates

func _expect_rejected(b: StitchedRules, target_rank: int, label: String) -> void:
	var before := b.state_snapshot()
	var rng := b.rng_state()
	var actor := b.current_actor_id()
	var receipt := b.use_part(PART_ID, target_rank)
	_check(not bool(receipt.get("ok", false)), label + " is rejected through the public API")
	_check(str(receipt.get("error", "")) != "", label + " returns a readable rejection")
	_check(before == b.state_snapshot() and rng == b.rng_state()
		and actor == b.current_actor_id(), label + " changes no state, HP, turn or RNG")


func _test_negative_gates() -> void:
	var outside := _battle(1, 2, 0)
	if outside != null:
		_expect_rejected(outside, 0, "AC3: target rank 0")
		_expect_rejected(outside, 5, "AC3: target rank 5")

	var absent := _battle(1, 2, 0)
	if absent != null:
		var missing_ally := _hero_at_rank(absent, 1)
		_check(not missing_ally.is_empty(), "AC3: the absent-ally fixture starts with a rank-one doll")
		if not missing_ally.is_empty():
			missing_ally["lost"] = true
			_expect_rejected(absent, 1, "AC3: a LOST ally leaves no target in that rank")

	var wrong_actor := _battle(1, 2, 0)
	if wrong_actor != null:
		var foe_turn := false
		for step in range(12):
			if wrong_actor.current_side() == "foe":
				foe_turn = true
				break
			if not bool(wrong_actor.pass_turn().get("ok", false)):
				break
		_check(foe_turn, "AC3: the wrong-actor fixture reaches a foe turn")
		if foe_turn:
			_expect_rejected(wrong_actor, 1, "AC3: a foe's turn")

	var unequipped := _battle(1, 2, 0, 733, false)
	if unequipped != null:
		_expect_rejected(unequipped, 1, "AC3: an unequipped trophy")

	var torn := _battle(1, 2, 0)
	if torn != null:
		var wearer := _hero_at_rank(torn, 2)
		_check(not wearer.is_empty(), "AC3: the torn fixture starts with the rank-two wearer")
		if not wearer.is_empty():
			wearer["parts"]["torso"]["torn"] = true
			_expect_rejected(torn, 1, "AC3: a torn trophy")


# ---------------------------------------------------------------- seeded replay

func _trace(seed_value: int) -> Dictionary:
	var b := _battle(2, 3, 20, seed_value)
	if b == null:
		return {}
	var target_rank := 1
	var receipt := b.use_part(PART_ID, target_rank)
	return {
		"receipt": receipt,
		"state": b.state_snapshot(),
		"rng": b.rng_state(),
	}


func _test_replay() -> void:
	var first := _trace(81243)
	var second := _trace(81243)
	_check(not first.is_empty() and first == second,
		"AC3: the same seed, fixture and legal action replay identical receipts, state and RNG")
	if not first.is_empty():
		_check(bool(first.get("receipt", {}).get("ok", false)),
			"AC3: the replayed middle-rank heal actually executed")
