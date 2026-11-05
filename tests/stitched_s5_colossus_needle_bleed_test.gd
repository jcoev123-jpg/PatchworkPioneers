extends SceneTree
## S5 focused contract: the Sewing-Machine Colossus trophy, "Colossus Needle Arm", must be more than
## a generic hit. The real boss record names the real enemy-part catalog entry, that entry validates at
## every stitch tier as a rank-sensitive Bleed attack, and the live StitchedRules battle applies the
## tiered Bleed on a landed hit and ticks it on the victim's next own turn.
##
## Records are found by named id: this test never asserts a catalog total or an ordered id list, so
## other coders may append parts in parallel. Seeds are fixed; the hit seed 1 and the miss seed 12 were
## each verified against the shipped four-hero/three-foe preview before being written here.

const ENEMY_PATH := "res://data/parts/enemy_parts.json"
const BOSS_PATH := "res://data/enemies/boss.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const PART_ID := "sewing_machine_colossus_needle_arm"
const PART_NAME := "Colossus Needle Arm"
const ABILITY_ID := "colossus_needle"
const ABILITY_NAME := "Colossus Needle"
const PART_TEXT := "Fire a sewing-machine needle into a foe and leave Bleed 1; higher stitch tiers deepen the seam."
const HIT_SEED := 1
const MISS_SEED := 12
const WARDEN := "warden"
const FOE_ID := "fray_scavenger"
## Earlier catalog records that must keep their authored identity when this one entry changes.
const EARLIER_ABILITIES := {
	"scissor_crab_claw_arm": "snip",
	"moth_swarm_wings": "flutter_back",
	"felt_bulwark_button_shield": "button_shield",
	"thread_biter_lint_gland": "lint_spit",
	"patchwork_behemoth_heart_torso": "behemoth_heart",
	"moth_queen_wing_crown": "queen_dust",
}
const TIER_DMG := [[5, 8], [6, 9], [7, 10]]
const TIER_STAT_DMG := [3, 4, 5]
const TIER_BLEED := [1, 2, 3]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_boss_trophy_and_catalog()
	_test_seeded_landed_bleed()
	_test_seeded_miss_applies_no_bleed()
	_test_illegal_actions_do_not_mutate()
	_test_illegal_launch_rank_does_not_mutate()
	_test_replay()
	for failure in failures:
		printerr(failure)
	print("stitched_s5_colossus_needle_bleed_test: ",
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


## The trophy the real boss record promises (never an index or a copied total).
func _boss_trophy() -> String:
	var parsed: Variant = _read_json(BOSS_PATH)
	if not parsed is Array:
		_check(false, "boss catalog is not a JSON array")
		return ""
	for raw in parsed:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		if str(entry.get("id", "")) != "sewing_machine_colossus":
			continue
		var stitched: Variant = entry.get("stitched", {})
		if not stitched is Dictionary:
			_check(false, "the Colossus record has no stitched profile")
			return ""
		var profile: Dictionary = stitched
		_check(str(profile.get("trophy", "")) == PART_ID,
			"AC1: the real Colossus trophy is " + PART_ID)
		var barrage: Dictionary = {}
		for ability in profile.get("abilities", []):
			if ability is Dictionary and str(ability.get("id", "")) == "colossus_barrage":
				barrage = ability
		_check(int(barrage.get("effects", {}).get("bleed", 0)) == 1,
			"AC1: the Colossus's own Needle Barrage keeps its authored Bleed 1")
		return str(profile.get("trophy", ""))
	_check(false, "the boss catalog still authors sewing_machine_colossus")
	return ""


func _catalog() -> Dictionary:
	var catalog := StitchedParts.load_catalog(ENEMY_PATH)
	_check(bool(catalog.get("ok", false)),
		"AC1: the real enemy part catalog loads: " + str(catalog.get("error", "")))
	return catalog


# ---------------------------------------------------------------- AC1: data contract at every tier

func _test_boss_trophy_and_catalog() -> void:
	var trophy := _boss_trophy()
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)) or trophy.is_empty():
		return
	_check(trophy == PART_ID, "AC1: the boss trophy selects the named needle arm by id")
	if not catalog["by_id"].has(trophy):
		_check(false, "AC1: the boss trophy resolves in the enemy catalog: " + trophy)
		return
	var part: Dictionary = catalog["by_id"][trophy]

	# Every catalog record still validates, and the earlier named records keep their abilities.
	for raw in catalog["parts"]:
		var result := StitchedParts.validate_part(raw)
		_check(bool(result.get("ok", false)),
			"AC1: every catalog part still validates: " + str(result.get("error", "")))
	for earlier_id in EARLIER_ABILITIES:
		_check(catalog["by_id"].has(earlier_id),
			"AC1: the earlier catalog id is still present: " + earlier_id)
		if catalog["by_id"].has(earlier_id):
			var earlier: Dictionary = catalog["by_id"][earlier_id]
			_check(str(earlier.get("ability", {}).get("id", "")) ==
				str(EARLIER_ABILITIES[earlier_id]),
				"AC1: the earlier part keeps its authored ability: " + earlier_id)

	_check(str(part.get("id", "")) == PART_ID, "AC1: the trophy keeps its id")
	_check(str(part.get("name", "")) == PART_NAME, "AC1: the trophy keeps its name")
	_check(str(part.get("text", "")) == PART_TEXT,
		"AC1: the trophy's text promises Bleed 1 and deeper seams")
	_check(str(part.get("owner", "")) == "any",
		"AC1: the trophy stays owner any, wearable by any hero")
	_check(str(part.get("slot", "")) == "arms", "AC1: the trophy stays in the arms slot")

	var ability: Dictionary = part.get("ability", {})
	_check(str(ability.get("id", "")) == ABILITY_ID, "AC1: tier I is the named Colossus Needle")
	_check(str(ability.get("name", "")) == ABILITY_NAME, "AC1: the ability keeps its name")
	_check(str(ability.get("kind", "")) == "ranged", "AC1: the ability stays ranged")
	_check(str(ability.get("target_side", "")) == "enemy",
		"AC1: the ability still targets foes")
	_check(JSON.stringify(ability.get("launch")) == JSON.stringify([1, 4]),
		"AC1: launch stays exactly ranks 1 and 4, not a range")
	_check(JSON.stringify(ability.get("target")) == JSON.stringify([1, 3]),
		"AC1: target stays exactly ranks 1 and 3, not a range")
	_check(not bool(ability.get("multi", true)),
		"AC1: the ability stays single-target")
	_check(int(ability.get("acc", -1)) == 85, "AC1: tier I keeps ACC 85")
	_check(int(ability.get("crit", -1)) == 0, "AC1: tier I keeps crit 0")
	_check(int(ability.get("self_move", -1)) == 0,
		"AC1: the ability never moves the wearer")
	_check(str(ability.get("move", "")) == "attack2",
		"AC1: the ability keeps the authored attack2 pose")
	_check(StitchedParts.MOVE_POSES.has(str(ability.get("move", ""))),
		"AC1: the pose is one of the authored move_poses values")
	_check(JSON.stringify(part.get("stat")) == JSON.stringify({"dmg": 3}),
		"AC1: tier I arms stat is dmg 3")

	var launch_mask := int(ability.get("launch_mask", 0))
	var target_mask := int(ability.get("target_mask", 0))
	_check(launch_mask == StitchedParts.rank_mask([1, 4]),
		"AC1: the launch mask marks only ranks 1 and 4")
	_check(target_mask == StitchedParts.rank_mask([1, 3]),
		"AC1: the target mask marks only ranks 1 and 3")
	for rank in [1, 4]:
		_check(StitchedParts.ranks_allowed(launch_mask, rank),
			"AC1: launch rank " + str(rank) + " stays legal")
	for rank in [2, 3]:
		_check(not StitchedParts.ranks_allowed(launch_mask, rank),
			"AC1: launch rank " + str(rank) + " stays illegal")
	for rank in [1, 3]:
		_check(StitchedParts.ranks_allowed(target_mask, rank),
			"AC1: target rank " + str(rank) + " stays legal")
	for rank in [2, 4]:
		_check(not StitchedParts.ranks_allowed(target_mask, rank),
			"AC1: target rank " + str(rank) + " stays illegal")

	for tier in [1, 2, 3]:
		var label := "AC1: tier " + str(tier)
		var tier_ability := StitchedParts.ability_at_tier(part, tier)
		var tier_stat := StitchedParts.stat_at_tier(part, tier)
		_check(bool(StitchedParts.validate_ability(tier_ability).get("ok", false)),
			label + " ability validates")
		_check(JSON.stringify(tier_ability.get("dmg")) == JSON.stringify(TIER_DMG[tier - 1]),
			label + " deals its authored damage " + str(TIER_DMG[tier - 1]))
		_check(int(tier_ability.get("effects", {}).get("bleed", 0)) == TIER_BLEED[tier - 1],
			label + " applies Bleed " + str(TIER_BLEED[tier - 1]))
		_check(JSON.stringify(tier_stat) == JSON.stringify({"dmg": TIER_STAT_DMG[tier - 1]}),
			label + " arms stat is dmg " + str(TIER_STAT_DMG[tier - 1]))
		# The tier override deepens only the seam; every other authored field is retained.
		_check(JSON.stringify(tier_ability.get("launch")) == JSON.stringify([1, 4])
			and JSON.stringify(tier_ability.get("target")) == JSON.stringify([1, 3]),
			label + " keeps its rank masks")
		_check(not bool(tier_ability.get("multi", true)),
			label + " stays single-target")
		_check(str(tier_ability.get("move", "")) == "attack2",
			label + " keeps the attack2 pose")
		_check(str(tier_ability.get("id", "")) == ABILITY_ID
			and str(tier_ability.get("target_side", "")) == "enemy"
			and int(tier_ability.get("acc", -1)) == 85
			and int(tier_ability.get("crit", -1)) == 0
			and int(tier_ability.get("self_move", -1)) == 0,
			label + " keeps its identity, accuracy, crit and self_move")


# ---------------------------------------------------------------- AC2: seeded live battle

func _config(catalog: Dictionary, seed_value: int, tier: int, trophy: String) -> Dictionary:
	var parsed: Variant = _read_json(PREVIEW_PATH)
	if not parsed is Dictionary:
		return {}
	var config: Dictionary = parsed
	config["parts"].append_array(catalog["parts"])
	config["seed"] = seed_value
	config["heroes"][0]["parts"]["arms"] = {"id": trophy, "tier": tier}
	return config


func _battle(catalog: Dictionary, seed_value: int, tier: int, trophy: String) -> StitchedRules:
	var config := _config(catalog, seed_value, tier, trophy)
	if config.is_empty():
		return null
	var created := StitchedRules.create(config)
	_check(bool(created.get("ok", false)),
		"AC2: seeded four-hero/three-foe battle builds at tier %d: %s"
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


func _status_entry(statuses: Array, name: String) -> Dictionary:
	for status in statuses:
		if status is Dictionary and str(status.get("status", "")) == name:
			return status
	return {}


func _test_seeded_landed_bleed() -> void:
	var trophy := PART_ID
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)) or not catalog["by_id"].has(trophy):
		return
	for tier in [1, 2, 3]:
		var b := _battle(catalog, HIT_SEED, tier, trophy)
		if b == null:
			continue
		var label := "AC2: tier " + str(tier)
		_check(b.get_heroes().size() == 4 and b.get_foes().size() == 3,
			label + ": the shipped 4v3 preview is intact")
		if not _to(b, WARDEN):
			_check(false, label + ": the seeded order reaches Warden's turn")
			continue
		var warden := b.get_unit(WARDEN)
		_check(int(warden["rank"]) == 1, label + ": Warden stands in legal launch rank 1")
		_check(str(warden["parts"]["arms"]["id"]) == trophy
			and int(warden["parts"]["arms"]["tier"]) == tier,
			label + ": Warden wears the real trophy at this stitch tier")
		_check(int(warden["dmg_bonus"]) == TIER_STAT_DMG[tier - 1],
			label + ": the equipped arms stat adds dmg " + str(TIER_STAT_DMG[tier - 1]))
		var foe_before := b.get_unit(FOE_ID)
		var start_hp := int(foe_before["hp"])
		var foe_prot := int(foe_before["prot"])
		_check(str(foe_before["side"]) == "foe" and int(foe_before["rank"]) == 1
			and start_hp == int(foe_before["max_hp"]) and foe_prot > 0
			and foe_before["statuses"].is_empty(),
			label + ": the legal rank-one foe is alive at full HP behind PROT, with no status")
		var ability := StitchedParts.ability_at_tier(catalog["by_id"][trophy], tier)
		_check(b._legal_targets(warden, ability, 1).size() == 1,
			label + ": rank 1 holds exactly one legal target for this single-target needle")
		var receipt := b.use_part(trophy, 1)
		_check(bool(receipt.get("ok", false)),
			label + ": the real use_part action executes: " + str(receipt.get("error", "")))
		if not bool(receipt.get("ok", false)):
			continue
		_check(str(receipt.get("part", "")) == trophy
			and str(receipt.get("ability", "")) == ABILITY_ID,
			label + ": the receipt names the equipped trophy and its ability")
		var results: Array = receipt.get("results", [])
		_check(results.size() == 1 and str(results[0].get("target", "")) == FOE_ID
			and int(results[0].get("target_rank", -1)) == 1,
			label + ": the single hit lands on the rank-one foe")
		if results.is_empty():
			continue
		var hit: Dictionary = results[0]
		_check(bool(hit.get("hit", false)), label + ": the fixed seed hits the legal foe")
		if not bool(hit.get("hit", false)):
			continue
		var chance := StitchedRules.hit_chance(
			85 + int(warden["acc"]),
			StitchedRules.effective_dodge(foe_before),
			int(warden["miss_streak"]))
		_check(int(hit.get("hit_chance", -1)) == chance,
			label + ": the hit chance follows ACC minus the foe's DODGE")
		_check(int(hit.get("roll", 100)) <= chance,
			label + ": the seeded roll is a genuine hit, not a forced one")
		var damage := int(hit.get("damage", 0))
		_check(damage > 0 and int(hit.get("target_hp", -1)) == start_hp - damage,
			label + ": the landed needle deals its normal direct damage")
		var expected_min := StitchedRules.apply_protection(
			int(ability["dmg"][0]) + int(warden["dmg_bonus"]), foe_prot)
		var expected_max := StitchedRules.apply_protection(
			int(ability["dmg"][1]) + int(warden["dmg_bonus"]), foe_prot)
		var expected_crit := StitchedRules.apply_protection(
			StitchedRules.crit_damage(int(ability["dmg"][1])) + int(warden["dmg_bonus"]), foe_prot)
		if bool(hit.get("crit", false)):
			_check(damage == expected_crit,
				label + ": a critical needle deals its authored critical damage")
		else:
			_check(damage >= expected_min and damage <= expected_max,
				label + ": the needle's damage stays inside its authored range plus the arms stat")
		var status := _status_entry(hit.get("statuses", []), "bleed")
		_check(not status.is_empty() and int(status.get("duration", 0)) == TIER_BLEED[tier - 1],
			label + ": the hit receipt records Bleed " + str(TIER_BLEED[tier - 1]))
		var victim := b.get_unit(FOE_ID)
		_check(int(victim["statuses"].get("bleed", 0)) == TIER_BLEED[tier - 1],
			label + ": the victim carries Bleed " + str(TIER_BLEED[tier - 1]) + " before its turn")
		var hp_after_hit := int(hit["target_hp"])
		if not _to(b, FOE_ID):
			_check(false, label + ": the bleeding foe reaches its own next turn")
			continue
		var ticked := b.get_unit(FOE_ID)
		_check(int(ticked["hp"]) == hp_after_hit - TIER_BLEED[tier - 1],
			label + ": the foe's own turn ticks exactly the tier's Bleed HP")
		_check(int(ticked["prot"]) == foe_prot,
			label + ": the Bleed tick ignores the foe's PROT")
		var remaining: int = int(TIER_BLEED[tier - 1]) - 1
		if remaining > 0:
			_check(int(ticked["statuses"].get("bleed", 0)) == remaining,
				label + ": a deeper seam keeps Bleed " + str(remaining) + " after one tick")
		else:
			_check(not ticked["statuses"].has("bleed"),
				label + ": Bleed 1 is fully consumed by one tick")


func _test_seeded_miss_applies_no_bleed() -> void:
	var trophy := PART_ID
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)) or not catalog["by_id"].has(trophy):
		return
	var b := _battle(catalog, MISS_SEED, 2, trophy)
	if b == null or not _to(b, WARDEN):
		_check(false, "AC3: the miss witness reaches Warden's turn")
		return
	var warden := b.get_unit(WARDEN)
	var foe_before := b.get_unit(FOE_ID)
	var start_hp := int(foe_before["hp"])
	var receipt := b.use_part(trophy, 1)
	_check(bool(receipt.get("ok", false)),
		"AC3: the miss witness still resolves a legal action: " + str(receipt.get("error", "")))
	if not bool(receipt.get("ok", false)) or receipt.get("results", []).is_empty():
		_check(false, "AC3: the miss witness produces one attack result")
		return
	var hit: Dictionary = receipt["results"][0]
	_check(not bool(hit.get("hit", true)), "AC3: the fixed miss seed misses the foe")
	var chance := StitchedRules.hit_chance(
		85 + int(warden["acc"]),
		StitchedRules.effective_dodge(foe_before),
		int(warden["miss_streak"]))
	_check(int(hit.get("hit_chance", -1)) == chance,
		"AC3: a miss still reports the real ACC-minus-DODGE chance")
	_check(int(hit.get("roll", 0)) > chance,
		"AC3: the miss roll genuinely exceeds the hit chance")
	_check(int(hit.get("damage", -1)) == 0
		and int(hit.get("target_hp", -1)) == start_hp,
		"AC3: a miss deals no damage and leaves the foe's HP untouched")
	_check(_status_entry(hit.get("statuses", []), "bleed").is_empty(),
		"AC3: a miss records no Bleed on the receipt")
	_check(int(b.get_unit(FOE_ID)["statuses"].get("bleed", 0)) == 0,
		"AC3: a miss puts no Bleed status on the foe")
	if _to(b, FOE_ID):
		_check(int(b.get_unit(FOE_ID)["hp"]) == start_hp
			and int(b.get_unit(FOE_ID)["statuses"].get("bleed", 0)) == 0,
			"AC3: the missed foe's own turn ticks no phantom Bleed")


# ---------------------------------------------------------------- AC3: fail-closed rejections

func _test_illegal_actions_do_not_mutate() -> void:
	var trophy := PART_ID
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)) or not catalog["by_id"].has(trophy):
		return
	var b := _battle(catalog, HIT_SEED, 2, trophy)
	if b == null or not _to(b, WARDEN):
		_check(false, "AC3: the refusal witness reaches Warden's turn")
		return
	var before := b.state_snapshot()
	var rng := b.rng_state()
	var illegal_target := b.use_part(trophy, 2)
	var outside_ranks := b.use_part(trophy, 0)
	var unknown := b.use_part("not_a_real_needle", 1)
	var unequipped := b.use_part("scissor_crab_claw_arm", 1)
	_check(not bool(illegal_target.get("ok", true)),
		"AC3: target rank 2 is refused by the authored target mask")
	_check(not bool(outside_ranks.get("ok", true)),
		"AC3: target rank 0 is refused before any roll")
	_check(not bool(unknown.get("ok", true)),
		"AC3: an unknown part id is refused")
	_check(not bool(unequipped.get("ok", true)),
		"AC3: a real catalog part that is not equipped is refused")
	_check(before == b.state_snapshot() and rng == b.rng_state(),
		"AC3: refused actions change neither snapshot nor seeded RNG")
	_check(b.current_actor_id() == WARDEN,
		"AC3: refused actions do not spend Warden's turn")


func _test_illegal_launch_rank_does_not_mutate() -> void:
	var trophy := PART_ID
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)) or not catalog["by_id"].has(trophy):
		return
	var b := _battle(catalog, HIT_SEED, 2, trophy)
	if b == null or not _to(b, WARDEN):
		_check(false, "AC3: the launch-rank witness reaches Warden's turn")
		return
	_check(bool(b.move(1).get("ok", false)),
		"AC3: Warden legally swaps back to rank 2 for the launch-rank witness")
	if not _to(b, WARDEN):
		_check(false, "AC3: the swapped Warden reaches its next turn at rank 2")
		return
	var warden := b.get_unit(WARDEN)
	_check(int(warden["rank"]) == 2, "AC3: the witness really stands in rank 2")
	var before := b.state_snapshot()
	var rng := b.rng_state()
	var refused := b.use_part(trophy, 1)
	_check(not bool(refused.get("ok", true)),
		"AC3: launching the needle from rank 2 is refused by the launch mask")
	_check(before == b.state_snapshot() and rng == b.rng_state(),
		"AC3: a refused launch rank changes neither snapshot nor seeded RNG")
	_check(b.current_actor_id() == WARDEN,
		"AC3: a refused launch rank does not spend the turn")


# ---------------------------------------------------------------- AC3: seeded replay

## The same refused attempts plus the same landed needle: receipts, state and RNG must replay.
func _trace(tier: int, catalog: Dictionary) -> Dictionary:
	var b := _battle(catalog, HIT_SEED, tier, PART_ID)
	if b == null or not _to(b, WARDEN):
		return {}
	var receipts: Array = []
	receipts.append(b.use_part(PART_ID, 2))
	receipts.append(b.use_part("not_a_real_needle", 1))
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
			label + ": the seeded refused/landed sequence replays receipts, state and RNG")
		var receipts: Array = first.get("receipts", [])
		_check(receipts.size() == 3 and not bool(receipts[0].get("ok", true))
			and not bool(receipts[1].get("ok", true))
			and bool(receipts[2].get("ok", false)),
			label + ": the replay contains two refusals and one landed needle")
		_check(bool(first.get("reached_foe_turn", false)),
			label + ": the replay reaches the bleeding foe's own turn")
