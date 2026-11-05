extends SceneTree
## S4 Warden contract: Rivet Pummel's Tangled seam deepens with its stitch tier (I/II/III -> 1/2/3).
##
## The real Warden catalog is loaded and every tier is resolved through StitchedParts.ability_at_tier, then
## the same part is worn into a real seeded four-hero/three-foe StitchedRules fight so the landed hit's
## receipt and the authoritative foe status are checked through the shipped use_part path. Seeds are fixed
## (seed 1 hits at every tier against the shipped preview) and the target starts untangled, so a tier II/III
## result cannot pass by inheriting an older status. Records are found by named id: this test never asserts
## a catalog total or an ordered id list, so other coders may append parts in parallel.

const WARDEN_PATH := "res://data/parts/warden_parts.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const PART_ID := "warden_arms_rivet_pummel"
const ABILITY_ID := "arms_rivet_pummel_move"
const WARDEN := "warden"
const FOE_ID := "fray_scavenger"
const RANK_THREE_FOE := "moth_scribe"
const HIT_SEED := 1
const TIER_TANGLED := [1, 2, 3]
const TIER_DMG := [[5, 7], [6, 9], [8, 11]]
const TIER_ACC := [90, 90, 95]
## The seven other authored Warden parts that must stay present when this one entry changes.
const OTHER_WARDEN_IDS := [
	"warden_head_pot_helm_bonk", "warden_head_helmet_rattle", "warden_arms_shield_catch",
	"warden_torso_iron_challenge", "warden_torso_buckle_rebound", "warden_legs_rim_toss",
	"warden_legs_shield_toss",
]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_catalog_tiers()
	_test_seeded_landed_tangle()
	_test_illegal_actions_do_not_mutate()
	_test_torn_part_does_not_mutate()
	_test_off_turn_does_not_mutate()
	_test_replay()
	for failure in failures:
		printerr(failure)
	print("stitched_s4_warden_rivet_tangle_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		_check(false, "missing data file: " + path)
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		_check(false, "empty data file: " + path)
		return null
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		_check(false, "unparsable JSON: " + path)
	return parsed


func _catalog() -> Dictionary:
	var catalog := StitchedParts.load_catalog(WARDEN_PATH)
	_check(bool(catalog.get("ok", false)),
		"AC1: the real Warden catalog loads: " + str(catalog.get("error", "")))
	return catalog


func _status_entry(statuses: Array, name: String) -> Dictionary:
	for status in statuses:
		if status is Dictionary and str(status.get("status", "")) == name:
			return status
	return {}


# ---------------------------------------------------------------- AC1: data contract at every tier

func _test_catalog_tiers() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)) or not catalog.get("by_id", {}).has(PART_ID):
		_check(false, "AC1: the catalog contains " + PART_ID)
		return
	var part: Dictionary = catalog["by_id"][PART_ID]

	# Every record still validates at every tier, and the seven other Warden ids stay present.
	for raw in catalog["parts"]:
		var part_result := StitchedParts.validate_part(raw)
		_check(bool(part_result.get("ok", false)),
			"AC1: every Warden catalog part still validates: " + str(part_result.get("error", "")))
		for tier in [1, 2, 3]:
			var tier_ability := StitchedParts.ability_at_tier(raw, tier)
			_check(bool(StitchedParts.validate_ability(tier_ability).get("ok", false)),
				"AC1: every Warden part tier validates: " + str(raw.get("id", "")) + " tier "
					+ str(tier))
	for other_id in OTHER_WARDEN_IDS:
		_check(catalog["by_id"].has(other_id),
			"AC1: the other Warden part is still present: " + other_id)

	_check(str(part.get("id", "")) == PART_ID, "AC1: Rivet Pummel keeps its id")
	_check(str(part.get("name", "")) == "Rivet Pummel", "AC1: Rivet Pummel keeps its name")
	_check(str(part.get("slot", "")) == "arms", "AC1: Rivet Pummel stays in the arms slot")
	_check(str(part.get("owner", "")) == WARDEN, "AC1: Rivet Pummel stays Warden's own part")
	_check(JSON.stringify(part.get("stat")) == JSON.stringify({"dmg": 2}),
		"AC1: Rivet Pummel keeps its arms stat dmg 2")
	_check(str(part.get("text", "")) == "Double-fist a front foe and tangle its thread.",
		"AC1: Rivet Pummel keeps its authored rules text")

	var base: Dictionary = part.get("ability", {})
	_check(str(base.get("id", "")) == ABILITY_ID, "AC1: tier I is the named Rivet Pummel move")
	_check(str(base.get("name", "")) == "Rivet Pummel", "AC1: the move keeps its name")
	_check(str(base.get("kind", "")) == "melee", "AC1: the move stays melee")
	_check(str(base.get("target_side", "")) == "enemy", "AC1: the move still targets foes")
	_check(JSON.stringify(base.get("launch")) == JSON.stringify([1, 2]),
		"AC1: launch stays exactly ranks 1 and 2")
	_check(JSON.stringify(base.get("target")) == JSON.stringify([1, 2]),
		"AC1: target stays exactly ranks 1 and 2")
	_check(not bool(base.get("multi", true)), "AC1: the move stays single-target")
	_check(int(base.get("crit", -1)) == 0, "AC1: the move keeps crit 0")
	_check(int(base.get("self_move", -1)) == 0, "AC1: the move never shifts the wearer")
	_check(str(base.get("move", "")) == "attack2", "AC1: the move keeps the attack2 pose")
	_check(int(base.get("effects", {}).get("tangled", 0)) == 1,
		"AC1: tier I stays Tangled 1")

	for tier in [1, 2, 3]:
		var label := "AC1: tier " + str(tier)
		var tier_ability := StitchedParts.ability_at_tier(part, tier)
		var tier_stat := StitchedParts.stat_at_tier(part, tier)
		_check(bool(StitchedParts.validate_ability(tier_ability).get("ok", false)),
			label + " ability validates")
		_check(JSON.stringify(tier_ability.get("dmg")) == JSON.stringify(TIER_DMG[tier - 1]),
			label + " keeps the authored damage " + str(TIER_DMG[tier - 1]))
		_check(int(tier_ability.get("acc", -1)) == TIER_ACC[tier - 1],
			label + " keeps the authored ACC " + str(TIER_ACC[tier - 1]))
		_check(int(tier_ability.get("effects", {}).get("tangled", 0)) == TIER_TANGLED[tier - 1],
			label + " applies Tangled " + str(TIER_TANGLED[tier - 1]))
		_check(JSON.stringify(tier_stat) == JSON.stringify({"dmg": 2}),
			label + " keeps the arms stat dmg 2")
		_check(str(tier_ability.get("id", "")) == ABILITY_ID
			and str(tier_ability.get("name", "")) == "Rivet Pummel"
			and str(tier_ability.get("kind", "")) == "melee"
			and str(tier_ability.get("target_side", "")) == "enemy",
			label + " keeps its identity, kind and target side")
		_check(JSON.stringify(tier_ability.get("launch")) == JSON.stringify([1, 2])
			and JSON.stringify(tier_ability.get("target")) == JSON.stringify([1, 2]),
			label + " keeps its launch and target ranks")
		_check(int(tier_ability.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 2])
			and int(tier_ability.get("target_mask", 0)) == StitchedParts.rank_mask([1, 2]),
			label + " keeps the ranks 1-2 masks")
		_check(not bool(tier_ability.get("multi", true)),
			label + " stays single-target")
		_check(str(tier_ability.get("move", "")) == "attack2",
			label + " keeps the attack2 pose")
		_check(int(tier_ability.get("crit", -1)) == 0
			and int(tier_ability.get("self_move", -1)) == 0,
			label + " keeps crit 0 and self_move 0")


# ---------------------------------------------------------------- AC2: seeded live battle

func _config(catalog: Dictionary, seed_value: int, tier: int, torn: bool = false) -> Dictionary:
	var parsed: Variant = _read_json(PREVIEW_PATH)
	if not parsed is Dictionary:
		return {}
	var config: Dictionary = parsed
	config["parts"].append_array(catalog["parts"])
	config["seed"] = seed_value
	config["heroes"][0]["parts"]["arms"] = {"id": PART_ID, "tier": tier, "torn": torn}
	return config


func _battle(
	catalog: Dictionary, seed_value: int, tier: int, torn: bool = false
) -> StitchedRules:
	var config := _config(catalog, seed_value, tier, torn)
	if config.is_empty():
		return null
	var created := StitchedRules.create(config)
	_check(bool(created.get("ok", false)),
		"seeded four-hero/three-foe battle builds at tier %d: %s"
			% [tier, str(created.get("error", ""))])
	return created.get("battle") if bool(created.get("ok", false)) else null


func _to(b: StitchedRules, actor_id: String, limit: int = 30) -> bool:
	for index in range(limit):
		if b.is_over():
			return false
		if b.current_actor_id() == actor_id:
			return true
		var receipt := b.pass_turn()
		if not bool(receipt.get("ok", false)):
			return false
	return false


func _to_side(b: StitchedRules, side: String, limit: int = 30) -> bool:
	for index in range(limit):
		if b.is_over():
			return false
		if b.current_side() == side:
			return true
		var receipt := b.pass_turn()
		if not bool(receipt.get("ok", false)):
			return false
	return false


func _test_seeded_landed_tangle() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)) or not catalog["by_id"].has(PART_ID):
		return
	var part: Dictionary = catalog["by_id"][PART_ID]
	for tier in [1, 2, 3]:
		var label := "AC2: tier " + str(tier)
		var b := _battle(catalog, HIT_SEED, tier)
		if b == null:
			continue
		_check(b.get_heroes().size() == 4 and b.get_foes().size() == 3,
			label + ": the shipped 4v3 preview is intact")
		if not _to(b, WARDEN):
			_check(false, label + ": the seeded order reaches Warden's turn")
			continue
		var warden := b.get_unit(WARDEN)
		_check(int(warden["rank"]) == 1, label + ": Warden stands in legal launch rank 1")
		_check(str(warden["parts"]["arms"]["id"]) == PART_ID
			and int(warden["parts"]["arms"]["tier"]) == tier
			and not bool(warden["parts"]["arms"]["torn"]),
			label + ": Warden wears untorn Rivet Pummel at this stitch tier")
		_check(int(warden["dmg_bonus"]) == 2,
			label + ": the equipped arms stat adds its authored dmg 2")

		var foe_before := b.get_unit(FOE_ID)
		var start_hp := int(foe_before["hp"])
		_check(str(foe_before["side"]) == "foe" and int(foe_before["rank"]) == 1
			and start_hp == int(foe_before["max_hp"]) and start_hp > 0,
			label + ": the legal rank-one foe is alive at full HP")
		_check(not foe_before["statuses"].has("tangled"),
			label + ": the target starts fresh and untangled")

		var ability := StitchedParts.ability_at_tier(part, tier)
		_check(b._legal_targets(warden, ability, 1).size() == 1,
			label + ": rank 1 holds exactly one legal target for this single-target move")
		_check(StitchedParts.ranks_allowed(int(ability["target_mask"]), 1)
			and StitchedParts.ranks_allowed(int(ability["target_mask"]), 2)
			and not StitchedParts.ranks_allowed(int(ability["target_mask"]), 3),
			label + ": the target mask allows ranks 1-2 and refuses rank 3")

		var receipt := b.use_part(PART_ID, 1)
		_check(bool(receipt.get("ok", false)),
			label + ": the real use_part action executes: " + str(receipt.get("error", "")))
		if not bool(receipt.get("ok", false)):
			continue
		_check(str(receipt.get("part", "")) == PART_ID
			and str(receipt.get("ability", "")) == ABILITY_ID,
			label + ": the receipt names the equipped part and its ability")
		var results: Array = receipt.get("results", [])
		_check(results.size() == 1 and str(results[0].get("target", "")) == FOE_ID
			and int(results[0].get("target_rank", -1)) == 1,
			label + ": exactly one foe result lands on the rank-one foe")
		if results.size() != 1:
			continue
		var hit: Dictionary = results[0]
		_check(bool(hit.get("hit", false)), label + ": the fixed seed hits the legal foe")
		if not bool(hit.get("hit", false)):
			continue
		var chance := StitchedRules.hit_chance(
			int(ability["acc"]) + int(warden["acc"]),
			StitchedRules.effective_dodge(foe_before),
			int(warden["miss_streak"]))
		_check(int(hit.get("hit_chance", -1)) == chance,
			label + ": the hit chance follows ACC minus the foe's DODGE")
		_check(int(hit.get("roll", 100)) <= chance,
			label + ": the seeded roll is a genuine hit, not a forced one")
		var damage := int(hit.get("damage", 0))
		_check(damage > 0 and int(hit.get("target_hp", -1)) == start_hp - damage,
			label + ": the landed pummel deals its normal direct damage")
		var expected_min := StitchedRules.apply_protection(
			int(ability["dmg"][0]) + int(warden["dmg_bonus"]), int(foe_before["prot"]))
		var expected_max := StitchedRules.apply_protection(
			int(ability["dmg"][1]) + int(warden["dmg_bonus"]), int(foe_before["prot"]))
		var expected_crit := StitchedRules.apply_protection(
			StitchedRules.crit_damage(int(ability["dmg"][1])) + int(warden["dmg_bonus"]),
			int(foe_before["prot"]))
		if bool(hit.get("crit", false)):
			_check(damage == expected_crit,
				label + ": a critical pummel deals its authored critical damage")
		else:
			_check(damage >= expected_min and damage <= expected_max,
				label + ": the pummel's damage stays inside its authored range plus the arms stat")

		var status := _status_entry(hit.get("statuses", []), "tangled")
		_check(not status.is_empty()
			and int(status.get("duration", 0)) == TIER_TANGLED[tier - 1],
			label + ": the hit receipt records Tangled " + str(TIER_TANGLED[tier - 1]))
		var victim := b.get_unit(FOE_ID)
		_check(int(victim["statuses"].get("tangled", 0)) == TIER_TANGLED[tier - 1],
			label + ": the authoritative target carries exactly Tangled "
				+ str(TIER_TANGLED[tier - 1]))


# ---------------------------------------------------------------- AC3: fail-closed rejections

func _test_illegal_actions_do_not_mutate() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)) or not catalog["by_id"].has(PART_ID):
		return
	var b := _battle(catalog, HIT_SEED, 2)
	if b == null or not _to(b, WARDEN):
		_check(false, "AC3: the refusal witness reaches Warden's turn")
		return
	var rank_three := b.get_unit(RANK_THREE_FOE)
	_check(str(rank_three.get("side", "")) == "foe" and int(rank_three.get("rank", 0)) == 3
		and int(rank_three.get("hp", 0)) > 0,
		"AC3: a living foe really stands outside the target ranks in rank 3")
	var before := b.state_snapshot()
	var rng := b.rng_state()
	var outside_target := b.use_part(PART_ID, 3)
	var outside_rank := b.use_part(PART_ID, 0)
	var unequipped := b.use_part("warden_arms_shield_catch", 1)
	var unknown := b.use_part("not_a_real_warden_arm", 1)
	_check(not bool(outside_target.get("ok", true)),
		"AC3: target rank 3 is refused even though a living foe stands there")
	_check(not bool(outside_rank.get("ok", true)),
		"AC3: target rank 0 is refused before any roll")
	_check(not bool(unequipped.get("ok", true)),
		"AC3: a real catalog part that Warden does not wear is refused")
	_check(not bool(unknown.get("ok", true)),
		"AC3: an unknown part id is refused")
	_check(before == b.state_snapshot() and rng == b.rng_state(),
		"AC3: refused actions change neither snapshot nor seeded RNG")
	_check(b.current_actor_id() == WARDEN,
		"AC3: refused actions do not spend Warden's turn")


func _test_torn_part_does_not_mutate() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)) or not catalog["by_id"].has(PART_ID):
		return
	var b := _battle(catalog, HIT_SEED, 2, true)
	if b == null or not _to(b, WARDEN):
		_check(false, "AC3: the torn-part witness reaches Warden's turn")
		return
	var warden := b.get_unit(WARDEN)
	_check(bool(warden["parts"]["arms"]["torn"]),
		"AC3: the torn witness really wears a torn Rivet Pummel")
	var before := b.state_snapshot()
	var rng := b.rng_state()
	var refused := b.use_part(PART_ID, 1)
	_check(not bool(refused.get("ok", true)),
		"AC3: a torn equipped part refuses its ability")
	_check(before == b.state_snapshot() and rng == b.rng_state(),
		"AC3: a torn part changes neither snapshot nor seeded RNG")
	_check(b.current_actor_id() == WARDEN,
		"AC3: a torn part does not spend the turn")


func _test_off_turn_does_not_mutate() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)) or not catalog["by_id"].has(PART_ID):
		return
	var b := _battle(catalog, HIT_SEED, 2)
	if b == null or not _to_side(b, "foe"):
		_check(false, "AC3: the off-turn witness reaches a foe turn")
		return
	var actor := b.current_actor_id()
	var before := b.state_snapshot()
	var rng := b.rng_state()
	var refused := b.use_part(PART_ID, 1)
	_check(not bool(refused.get("ok", true)),
		"AC3: a hero part used on a foe turn is refused")
	_check(before == b.state_snapshot() and rng == b.rng_state(),
		"AC3: an off-turn use changes neither snapshot nor seeded RNG")
	_check(b.current_actor_id() == actor,
		"AC3: an off-turn use leaves the active actor unchanged")


# ---------------------------------------------------------------- AC3: seeded replay

func _trace(tier: int, catalog: Dictionary) -> Dictionary:
	var b := _battle(catalog, HIT_SEED, tier)
	if b == null or not _to(b, WARDEN):
		return {}
	var receipts: Array = []
	receipts.append(b.use_part(PART_ID, 3))
	receipts.append(b.use_part("warden_arms_shield_catch", 1))
	receipts.append(b.use_part(PART_ID, 1))
	var reached := _to(b, FOE_ID)
	return {
		"receipts": receipts,
		"reached_foe_turn": reached,
		"state": b.state_snapshot(),
		"rng": b.rng_state(),
	}


func _test_replay() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)) or not catalog["by_id"].has(PART_ID):
		return
	for tier in [1, 2, 3]:
		var first := _trace(tier, catalog)
		var second := _trace(tier, catalog)
		var label := "AC3: tier " + str(tier)
		_check(not first.is_empty() and first == second,
			label + ": equal seeds replay receipts, authoritative state and RNG")
		var receipts: Array = first.get("receipts", [])
		_check(receipts.size() == 3 and not bool(receipts[0].get("ok", true))
			and not bool(receipts[1].get("ok", true))
			and bool(receipts[2].get("ok", false)),
			label + ": the replay contains two refusals and one landed pummel")
		if receipts.size() == 3 and bool(receipts[2].get("ok", false)):
			var results: Array = receipts[2].get("results", [])
			var status := {}
			if results.size() == 1:
				status = _status_entry(results[0].get("statuses", []), "tangled")
			_check(results.size() == 1 and bool(results[0].get("hit", false))
				and int(status.get("duration", 0)) == TIER_TANGLED[tier - 1],
				label + ": the replay's landed pummel records Tangled "
					+ str(TIER_TANGLED[tier - 1]))
		_check(bool(first.get("reached_foe_turn", false)),
			label + ": the replay reaches the tangled foe's own turn")
