extends SceneTree
## S4 Warden contract: Helmet Rattle's Weak seam deepens with its stitch tier (I/II/III -> 2/2/3),
## and at tier III the clanging helm also reaches enemy rank 3. Tiers I and II stay at ranks 1-2,
## so the tier-III reach is the only added rank; rank 4 is refused at every tier.
##
## The real version-1 Warden catalog is loaded through StitchedParts.load_catalog and every
## named record is resolved through StitchedParts.ability_at_tier. Records are found by id,
## never by a catalog total or an ordered id list, so other coders may append parts in
## parallel. The shipped validator is then exercised with copied invalid records (unknown
## effect, out-of-range rank, zero Weak) and the real catalog is checked again afterwards so
## the negative checks can never hide a mutation of the authored data.
##
## The same part is then worn into a real seeded four-hero/three-foe StitchedRules fight built
## from data/stitched/s2_preview.json, so legality and Weak 3 are checked through the shipped
## use_part path and the authoritative foe statuses. A bounded fixed-seed search witnesses a
## genuine tier-III hit on the living rank-three foe; tiers I/II of the same state cannot target
## rank 3, rank 4 never works, refusals are state/turn/RNG atomic, a natural miss adds no Weak,
## and duplicate seeded trials replay identical receipts, snapshots and RNG.

const WARDEN_PATH := "res://data/parts/warden_parts.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const PART_ID := "warden_head_helmet_rattle"
const ABILITY_ID := "head_helmet_rattle_move"
const WARDEN := "warden"
const RANK_ONE_FOE := "fray_scavenger"
const RANK_THREE_FOE := "moth_scribe"
const OTHER_FOES := ["fray_scavenger", "scissor_crab"]
const RANK_THREE := 3
const RANK_FOUR := 4
const TIER_WEAK := [2, 2, 3]
const TIER_DMG := [[3, 5], [5, 7], [6, 9]]
const TIER_CRIT := [0, 0, 8]
const TIER_ACC := [90, 90, 90]
const TIER_TARGET := [[1, 2], [1, 2], [1, 2, 3]]
const LAUNCH := [1, 2]
const RATTLE_TEXT := "Rattle a nearby foe into Weakness; at tier III the clang reaches enemy rank 3."
## Upper bound on the deterministic seed searches (never a wall-clock or random search).
const SEED_SEARCH_LIMIT := 200

## The seven other authored Warden parts that must keep their original tier outputs;
## Rim Toss's authorized tier-III rear-rank reach is listed per tier.
const SIBLING_EXPECTED := {
	"warden_head_pot_helm_bonk": {
		"slot": "head",
		"stat": {"acc": 5},
		"launch": [1, 2],
		"target": [1, 2],
		"side": "enemy",
		"pose": "attack",
		"dmg": [[4, 6], [5, 8], [7, 10]],
		"acc": [90, 90, 95],
		"crit": [0, 0, 0],
		"effects": [{"weak": 2}, {"weak": 2}, {"weak": 2}],
	},
	"warden_arms_shield_catch": {
		"slot": "arms",
		"stat": {"dmg": 1},
		"launch": [1, 2],
		"target": [1, 2, 3, 4],
		"side": "ally",
		"pose": "guard",
		"dmg": [[0, 0], [0, 0], [0, 0]],
		"acc": [100, 100, 100],
		"crit": [0, 0, 0],
		"effects": [{"guard": 2}, {"guard": 3}, {"guard": 4}],
	},
	"warden_arms_rivet_pummel": {
		"slot": "arms",
		"stat": {"dmg": 2},
		"launch": [1, 2],
		"target": [1, 2],
		"side": "enemy",
		"pose": "attack2",
		"dmg": [[5, 7], [6, 9], [8, 11]],
		"acc": [90, 90, 95],
		"crit": [0, 0, 0],
		"effects": [{"tangled": 1}, {"tangled": 2}, {"tangled": 3}],
	},
	"warden_torso_iron_challenge": {
		"slot": "torso",
		"stat": {"max_hp": 6, "prot": 5},
		"launch": [1],
		"target": [1],
		"side": "self",
		"pose": "guard",
		"dmg": [[0, 0], [0, 0], [0, 0]],
		"acc": [100, 100, 100],
		"crit": [0, 0, 0],
		"effects": [{"thorns": 2}, {"thorns": 3}, {"thorns": 4}],
	},
	"warden_torso_buckle_rebound": {
		"slot": "torso",
		"stat": {"max_hp": 5, "prot": 8},
		"launch": [1, 2],
		"target": [1, 2],
		"side": "self",
		"pose": "guard",
		"dmg": [[0, 0], [0, 0], [0, 0]],
		"acc": [100, 100, 100],
		"crit": [0, 0, 0],
		"effects": [
			{"thorns": 3, "riposte": 1},
			{"thorns": 4, "riposte": 2},
			{"thorns": 5, "riposte": 3},
		],
	},
	"warden_legs_rim_toss": {
		"slot": "legs",
		"stat": {"speed": 1, "dodge": 2},
		"launch": [1, 2],
		"target": [1, 2, 3],
		"target_by_tier": [[1, 2, 3], [1, 2, 3], [1, 2, 3, 4]],
		"side": "enemy",
		"pose": "attack2",
		"dmg": [[5, 8], [6, 10], [8, 12]],
		"acc": [90, 90, 90],
		"crit": [0, 0, 0],
		"effects": [{"mark": 2}, {"mark": 2}, {"mark": 2}],
	},
	"warden_legs_shield_toss": {
		"slot": "legs",
		"stat": {"speed": 2, "dodge": 3},
		"launch": [1, 2],
		"target": [1, 2, 3],
		"side": "enemy",
		"pose": "attack2",
		"dmg": [[5, 7], [6, 9], [8, 11]],
		"acc": [90, 90, 90],
		"crit": [0, 0, 0],
		"effects": [{"tangled": 1}, {"tangled": 1}, {"tangled": 2}],
	},
}

var failures: Array[String] = []
var checks := 0
## The bounded hit witness' seed, reused by the replay check so it never guesses a hit.
var witnessed_hit_seed := 0


func _initialize() -> void:
	_test_real_catalog()
	_test_base_weak_reply()
	_test_invalid_copies()
	_test_rank_three_hit_witness()
	_test_lower_tiers_cannot_reach_rank_three()
	_test_rank_four_and_launch_and_off_turn()
	_test_natural_miss_applies_no_weak()
	_test_replay()
	for failure in failures:
		printerr(failure)
	print("stitched_s4_warden_helmet_rattle_weak_test: ",
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


func _raw_part(document: Dictionary) -> Dictionary:
	for entry in document.get("parts", []):
		if entry is Dictionary and str(entry.get("id", "")) == PART_ID:
			return entry
	return {}


func _status_entry(statuses: Array, name: String) -> Dictionary:
	for status in statuses:
		if status is Dictionary and str(status.get("status", "")) == name:
			return status
	return {}


func _snapshot_unit(snapshot: Dictionary, unit_id: String) -> Dictionary:
	for unit in snapshot.get("units", []):
		if unit is Dictionary and str(unit.get("id", "")) == unit_id:
			return unit
	return {}


# ---------------------------------------------------------------- AC1/AC2: real catalog tiers

func _test_real_catalog() -> void:
	var document: Variant = _read_json(WARDEN_PATH)
	if not document is Dictionary:
		return
	_check(int(document.get("version", 0)) == 1,
		"AC1: the real Warden catalog stays version 1")

	var catalog := StitchedParts.load_catalog(WARDEN_PATH)
	_check(bool(catalog.get("ok", false)),
		"AC1: the real Warden catalog loads: " + str(catalog.get("error", "")))
	if not bool(catalog.get("ok", false)):
		return
	var by_id: Dictionary = catalog.get("by_id", {})
	_check(by_id.has(PART_ID), "AC1: the catalog contains " + PART_ID)
	for sibling_id in SIBLING_EXPECTED:
		_check(by_id.has(sibling_id), "AC2: the sibling part is still present: " + sibling_id)
	if not by_id.has(PART_ID):
		return

	var part: Dictionary = by_id[PART_ID]
	_check(bool(StitchedParts.validate_part(part).get("ok", false)),
		"AC1: Helmet Rattle validates as shipped")
	_check(str(part.get("id", "")) == PART_ID, "AC2: Helmet Rattle keeps its id")
	_check(str(part.get("name", "")) == "Helmet Rattle", "AC2: Helmet Rattle keeps its name")
	_check(str(part.get("slot", "")) == "head", "AC2: Helmet Rattle stays in the head slot")
	_check(str(part.get("owner", "")) == WARDEN, "AC2: Helmet Rattle stays Warden's own part")
	_check(part.get("stat", {}) == {"crit": 4}, "AC2: Helmet Rattle keeps its head stat crit 4")
	_check(str(part.get("text", "")) == RATTLE_TEXT,
		"AC2: Helmet Rattle states its tier-III rank-3 reach in its authored rules text")

	var base: Dictionary = part.get("ability", {})
	_check(str(base.get("id", "")) == ABILITY_ID, "AC2: tier I is the named Helmet Rattle move")
	_check(str(base.get("name", "")) == "Helmet Rattle", "AC2: the move keeps its name")
	_check(str(base.get("kind", "")) == "melee", "AC2: the move stays melee")
	_check(str(base.get("target_side", "")) == "enemy", "AC2: the move still targets foes")
	_check(base.get("launch", []) == LAUNCH, "AC2: launch stays exactly ranks 1 and 2")
	_check(base.get("target", []) == TIER_TARGET[0],
		"AC2: tier I target stays exactly ranks 1 and 2")
	_check(int(base.get("launch_mask", 0)) == StitchedParts.rank_mask(LAUNCH),
		"AC2: the launch mask is derived from ranks 1 and 2")
	_check(int(base.get("target_mask", 0)) == StitchedParts.rank_mask(TIER_TARGET[0]),
		"AC2: the tier-I target mask is derived from ranks 1 and 2")
	_check(not bool(base.get("multi", true)), "AC2: the move stays single-target")
	_check(int(base.get("acc", -1)) == 90, "AC2: tier I keeps ACC 90")
	_check(base.get("dmg", []) == [3, 5], "AC2: tier I keeps damage [3, 5]")
	_check(int(base.get("crit", -1)) == 0, "AC2: tier I keeps crit 0")
	_check(base.get("effects", {}) == {"weak": 2}, "AC1: tier I applies Weak 2")
	_check(int(base.get("self_move", -1)) == 0, "AC2: the move never shifts the wearer")
	_check(str(base.get("move", "")) == "attack2", "AC2: the move keeps the attack2 pose")

	for tier in [1, 2, 3]:
		var label := "AC1/AC2: tier " + str(tier)
		var ability := StitchedParts.ability_at_tier(part, tier)
		var stat := StitchedParts.stat_at_tier(part, tier)
		var expected_target: Array = TIER_TARGET[tier - 1]
		_check(bool(StitchedParts.validate_ability(ability).get("ok", false)),
			label + " ability validates")
		_check(int(ability.get("effects", {}).get("weak", 0)) == TIER_WEAK[tier - 1],
			label + " applies Weak " + str(TIER_WEAK[tier - 1]))
		_check(ability.get("effects", {}) == {"weak": TIER_WEAK[tier - 1]},
			label + " applies only the authored Weak effect")
		_check(ability.get("dmg", []) == TIER_DMG[tier - 1],
			label + " keeps the authored damage " + str(TIER_DMG[tier - 1]))
		_check(int(ability.get("crit", -1)) == TIER_CRIT[tier - 1],
			label + " keeps crit " + str(TIER_CRIT[tier - 1]))
		_check(int(ability.get("acc", -1)) == TIER_ACC[tier - 1],
			label + " keeps ACC " + str(TIER_ACC[tier - 1]))
		_check(ability.get("launch", []) == LAUNCH,
			label + " keeps its launch ranks 1 and 2")
		_check(ability.get("target", []) == expected_target,
			label + " targets exactly " + str(expected_target))
		_check(int(ability.get("launch_mask", 0)) == StitchedParts.rank_mask(LAUNCH),
			label + " keeps the launch mask for ranks 1 and 2")
		_check(int(ability.get("target_mask", 0)) == StitchedParts.rank_mask(expected_target),
			label + " derives the target mask from " + str(expected_target))
		_check(StitchedParts.ranks_allowed(int(ability["target_mask"]), 1)
			and StitchedParts.ranks_allowed(int(ability["target_mask"]), 2),
			label + " always reaches enemy ranks 1 and 2")
		_check(StitchedParts.ranks_allowed(int(ability["target_mask"]), RANK_THREE)
			== (tier == 3),
			label + " reaches enemy rank 3 only at tier III")
		_check(not StitchedParts.ranks_allowed(int(ability["target_mask"]), RANK_FOUR),
			label + " never reaches enemy rank 4")
		_check(str(ability.get("target_side", "")) == "enemy"
			and not bool(ability.get("multi", true)),
			label + " stays a single-target enemy move")
		_check(int(ability.get("self_move", -1)) == 0
			and str(ability.get("move", "")) == "attack2",
			label + " keeps zero self-move and the attack2 pose")
		_check(str(ability.get("id", "")) == ABILITY_ID
			and str(ability.get("name", "")) == "Helmet Rattle"
			and str(ability.get("kind", "")) == "melee",
			label + " keeps its ability identity, name and kind")
		_check(stat == {"crit": 4}, label + " keeps the head stat crit 4")

	for sibling_id in SIBLING_EXPECTED:
		if not by_id.has(sibling_id):
			continue
		var sibling: Dictionary = by_id[sibling_id]
		var expected: Dictionary = SIBLING_EXPECTED[sibling_id]
		_check(bool(StitchedParts.validate_part(sibling).get("ok", false)),
			"AC2: " + sibling_id + " still validates")
		_check(str(sibling.get("slot", "")) == str(expected["slot"]),
			"AC2: " + sibling_id + " keeps its slot")
		_check(sibling.get("stat", {}) == expected["stat"],
			"AC2: " + sibling_id + " keeps its stat " + str(expected["stat"]))
		for tier in [1, 2, 3]:
			var label: String = "AC2: " + str(sibling_id) + " tier " + str(tier)
			var ability := StitchedParts.ability_at_tier(sibling, tier)
			var expected_targets: Array = expected.get("target_by_tier", [])
			var expected_target: Array = expected["target"] if expected_targets.is_empty() \
				else expected_targets[tier - 1]
			_check(bool(StitchedParts.validate_ability(ability).get("ok", false)),
				label + " validates")
			_check(ability.get("dmg", []) == expected["dmg"][tier - 1],
				label + " keeps its original damage " + str(expected["dmg"][tier - 1]))
			_check(int(ability.get("acc", -1)) == int(expected["acc"][tier - 1]),
				label + " keeps its original ACC " + str(expected["acc"][tier - 1]))
			_check(int(ability.get("crit", -1)) == int(expected["crit"][tier - 1]),
				label + " keeps its original crit " + str(expected["crit"][tier - 1]))
			_check(ability.get("effects", {}) == expected["effects"][tier - 1],
				label + " keeps its original effects " + str(expected["effects"][tier - 1]))
			_check(ability.get("launch", []) == expected["launch"]
				and ability.get("target", []) == expected_target,
				label + " keeps its original launch and target ranks")
			_check(int(ability.get("launch_mask", 0)) == StitchedParts.rank_mask(expected["launch"])
				and int(ability.get("target_mask", 0))
					== StitchedParts.rank_mask(expected_target),
				label + " keeps its original rank masks")
			_check(str(ability.get("target_side", "")) == str(expected["side"])
				and str(ability.get("move", "")) == str(expected["pose"]),
				label + " keeps its original target side and pose")


# ---------------------------------------------------------------- seeded real battle helpers

## A copy of the shipped preview with the real Warden catalog appended and Helmet Rattle worn
## in Warden's head slot. Hero array order is hero rank, so warden_rank moves him to that rank.
func _config(
	catalog: Dictionary, seed_value: int, tier: int, warden_rank: int = 1,
	head_part: String = PART_ID
) -> Dictionary:
	var parsed: Variant = _read_json(PREVIEW_PATH)
	if not parsed is Dictionary:
		return {}
	var config: Dictionary = parsed
	config["parts"].append_array(catalog["parts"])
	config["seed"] = seed_value
	var warden_entry: Dictionary = {}
	for hero in config["heroes"]:
		if hero is Dictionary and str(hero.get("id", "")) == WARDEN:
			warden_entry = hero
	if warden_entry.is_empty():
		_check(false, "AC2: the shipped preview really contains Warden")
		return {}
	warden_entry["parts"]["head"] = {"id": head_part, "tier": tier, "torn": false}
	if warden_rank != 1:
		var reordered: Array = []
		for hero in config["heroes"]:
			if str(hero.get("id", "")) != WARDEN:
				reordered.append(hero)
		reordered.insert(clampi(warden_rank - 1, 0, reordered.size()), warden_entry)
		config["heroes"] = reordered
	return config


func _battle(
	catalog: Dictionary, seed_value: int, tier: int, warden_rank: int = 1,
	head_part: String = PART_ID
) -> StitchedRules:
	var config := _config(catalog, seed_value, tier, warden_rank, head_part)
	if config.is_empty():
		return null
	var created := StitchedRules.create(config)
	_check(bool(created.get("ok", false)),
		"AC2: the seeded four-hero/three-foe battle builds at tier %d: %s"
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


## Whether the Warden's one action was spent: the turn pointer moved on (or the round rolled
## over), and it is no longer his turn.
func _turn_spent(b: StitchedRules, before: Dictionary) -> bool:
	var after := b.state_snapshot()
	if int(after["round"]) > int(before["round"]) or b.is_over():
		return true
	return int(after["turn_index"]) > int(before["turn_index"]) \
		and b.current_actor_id() != WARDEN



# ----------------------------------------------------------- AC2/AC3: base Weak on a real foe reply

## Both head patches must keep Weak through the foe's first actual strike. A control
## battle with the same seed has Warden bonk rank 2 instead of rank 1; both bonks hit
## and consume the same RNG, but the rank-1 attacker is unweakened in the control.
## This compares real foe damage, not a fabricated damage fixture or planted Weak.
func _test_base_weak_reply() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)):
		return
	for part_id in ["warden_head_pot_helm_bonk", PART_ID]:
		var label: String = "AC2/AC3: base " + str(part_id)
		_check(catalog.get("by_id", {}).has(part_id), label + ": the real catalog contains this head")
		if not catalog.get("by_id", {}).has(part_id):
			continue

		# A bad target is refused before state, turn or RNG changes for either head.
		var illegal := _battle(catalog, 1, 1, 1, part_id)
		if illegal == null or not _to(illegal, WARDEN):
			_check(false, label + ": an equipped Warden gets a live turn for refusal")
			continue
		var before_refusal := illegal.state_snapshot()
		var rng_refusal := illegal.rng_state()
		var rejected := illegal.use_part(part_id, RANK_THREE)
		_check(not bool(rejected.get("ok", true)), label + ": base rank-three use is refused")
		_check(before_refusal == illegal.state_snapshot()
			and rng_refusal == illegal.rng_state()
			and illegal.current_actor_id() == WARDEN,
			label + ": refusal preserves authoritative state, turn and RNG")

		var hit_seen := false
		var miss_seen := false
		for seed_value in range(1, SEED_SEARCH_LIMIT):
			var b := _battle(catalog, seed_value, 1, 1, part_id)
			var baseline := _battle(catalog, seed_value, 1, 1, part_id)
			if b == null or baseline == null or not _to(b, WARDEN) or not _to(baseline, WARDEN):
				continue
			var equipped: Dictionary = b.get_unit(WARDEN).get("parts", {}).get("head", {})
			var front_before := b.get_unit(RANK_ONE_FOE)
			if str(equipped.get("id", "")) != part_id or int(equipped.get("tier", 0)) != 1 \
				or bool(equipped.get("torn", true)) or int(b.get_unit(WARDEN).get("rank", 0)) != 1 \
				or int(front_before.get("hp", 0)) <= 0 \
				or int(front_before.get("statuses", {}).get("weak", 0)) != 0:
				continue
			var before_action := b.state_snapshot()
			var attempt := b.use_part(part_id, 1)
			var control := baseline.use_part(part_id, 2)
			var results: Array = attempt.get("results", [])
			var controls: Array = control.get("results", [])
			if not bool(attempt.get("ok", false)) or results.size() != 1:
				continue
			var bonk: Dictionary = results[0]
			if not miss_seen and not bool(bonk.get("hit", true)):
				_check(int(bonk.get("roll", 0)) > int(bonk.get("hit_chance", 100)),
					label + ": a natural RNG miss exceeds the real hit chance")
				_check(int(bonk.get("damage", -1)) == 0 and bonk.get("statuses", []).is_empty()
					and b.get_unit(RANK_ONE_FOE).get("statuses", {}).get("weak", 0) == 0
					and b.get_unit(RANK_ONE_FOE).get("hp", -1) == front_before.get("hp", -2),
					label + ": a genuine miss adds no Weak or damage")
				_check(_turn_spent(b, before_action),
					label + ": a missed action still spends Warden's turn")
				miss_seen = true
			if hit_seen or not bool(bonk.get("hit", false)) or not bool(control.get("ok", false)) \
				or controls.size() != 1 or not bool(controls[0].get("hit", false)):
				if hit_seen and miss_seen:
					break
				continue
			var control_bonk: Dictionary = controls[0]
			if int(bonk.get("damage", 0)) <= 0 or int(control_bonk.get("damage", 0)) <= 0 \
				or b.get_unit(RANK_ONE_FOE).get("hp", 0) <= 0 \
				or baseline.get_unit("scissor_crab").get("hp", 0) <= 0:
				continue
			var receipt_status := _status_entry(bonk.get("statuses", []), "weak")
			var action_snapshot := b.state_snapshot()
			var action_rng := b.rng_state()
			var replay := _battle(catalog, seed_value, 1, 1, part_id)
			if replay == null or not _to(replay, WARDEN):
				continue
			var replay_receipt := replay.use_part(part_id, 1)
			_check(replay_receipt == attempt and replay.state_snapshot() == action_snapshot
				and replay.rng_state() == action_rng,
				label + ": the equipped bonk, state and RNG replay from the same seed")
			_check(int(bonk.get("roll", 100)) <= int(bonk.get("hit_chance", -1))
				and int(control_bonk.get("roll", 100)) <= int(control_bonk.get("hit_chance", -1)),
				label + ": both competing bonks are natural landed hits")
			_check(int(receipt_status.get("duration", 0)) == 2
				and int(b.get_unit(RANK_ONE_FOE).get("statuses", {}).get("weak", 0)) in [1, 2],
				label + ": a real equipped tier-I bonk applies Weak 2")
			_check(b.rng_state() == baseline.rng_state(),
				label + ": bonking different living foes consumed identical seeded RNG")
			if not _to(b, RANK_ONE_FOE) or not _to(baseline, RANK_ONE_FOE):
				continue
			var attacker := b.get_unit(RANK_ONE_FOE)
			var ordinary_attacker := baseline.get_unit(RANK_ONE_FOE)
			var hero := b.get_unit(WARDEN)
			var ordinary_hero := baseline.get_unit(WARDEN)
			if attacker.is_empty() or ordinary_attacker.is_empty() or hero.is_empty() or ordinary_hero.is_empty():
				continue
			var attack_ability: Dictionary = attacker.get("abilities", [])[0]
			if str(attack_ability.get("id", "")) != "sack_swing":
				continue
			var weak_at_strike := int(attacker.get("statuses", {}).get("weak", 0))
			var ordinary_at_strike := int(ordinary_attacker.get("statuses", {}).get("weak", 0))
			var same_rng := b.rng_state() == baseline.rng_state()
			var strike := b.use_foe_ability("sack_swing", 1)
			var ordinary := baseline.use_foe_ability("sack_swing", 1)
			var strike_results: Array = strike.get("results", [])
			var ordinary_results: Array = ordinary.get("results", [])
			if not bool(strike.get("ok", false)) or not bool(ordinary.get("ok", false)) \
				or strike_results.size() != 1 or ordinary_results.size() != 1:
				continue
			var actual: Dictionary = strike_results[0]
			var normal: Dictionary = ordinary_results[0]
			if not bool(actual.get("hit", false)) or not bool(normal.get("hit", false)):
				continue
			_check(str(strike.get("actor", "")) == RANK_ONE_FOE
				and str(strike.get("ability", "")) == "sack_swing"
				and str(actual.get("target", "")) == WARDEN,
				label + ": the actually weakened victim uses its authored foe attack")
			_check(weak_at_strike == 1 and ordinary_at_strike == 0,
				label + ": Weak 2 ticks to Weak 1, while the control has no Weak")
			_check(same_rng and int(actual.get("roll", -1)) == int(normal.get("roll", -2))
				and bool(actual.get("crit", false)) == bool(normal.get("crit", true)),
				label + ": both real foe strikes share RNG, hit roll and critical outcome")
			_check(hero.get("statuses", {}) == ordinary_hero.get("statuses", {})
				and hero.get("prot", -1) == ordinary_hero.get("prot", -2),
				label + ": both strikes face an identically protected hero")
			var lower := int(attack_ability["dmg"][0])
			var upper := int(attack_ability["dmg"][1])
			if bool(actual.get("crit", false)):
				lower = StitchedRules.crit_damage(upper)
				upper = lower
			var rules_match := false
			for raw in range(lower, upper + 1):
				var candle_base := StitchedS1BEffects.enemy_damage(raw, b.candle())
				var ordinary_damage := StitchedRules.damage_after_modifiers(
					candle_base, ordinary_attacker["statuses"], ordinary_hero["statuses"],
					false, int(attack_ability["mark_damage"]), int(ordinary_hero["prot"]))
				var weakened_damage := StitchedRules.damage_after_modifiers(
					candle_base, attacker["statuses"], hero["statuses"],
					false, int(attack_ability["mark_damage"]), int(hero["prot"]))
				if ordinary_damage == int(normal.get("damage", -1)) \
					and weakened_damage == int(actual.get("damage", -1)):
					rules_match = true
			_check(rules_match and int(normal.get("damage", 0)) > int(actual.get("damage", 0)),
				label + ": actual weakened damage is smaller than the rules' ordinary unweakened baseline")
			_check(int(actual.get("target_hp", -1)) == int(hero["hp"]) - int(actual.get("damage", -2))
				and int(normal.get("target_hp", -1)) == int(ordinary_hero["hp"]) - int(normal.get("damage", -2)),
				label + ": real damage updates both Warden HP totals")
			if not _to(b, RANK_ONE_FOE) or not _to(baseline, RANK_ONE_FOE):
				continue
			_check(int(b.get_unit(RANK_ONE_FOE).get("statuses", {}).get("weak", 0)) == 0
				and int(baseline.get_unit(RANK_ONE_FOE).get("statuses", {}).get("weak", 0)) == 0,
				label + ": Weak expires at the victim's following actual turn without reapplication")
			hit_seen = true
			if miss_seen:
				break
		_check(hit_seen, label + ": a seeded landed bonk weakens the next real foe strike and expires")
		_check(miss_seen, label + ": a seeded natural bonk miss applies no Weak")


# ---------------------------------------------------------------- AC2: tier-III rank-3 hit

func _test_rank_three_hit_witness() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)) or not catalog["by_id"].has(PART_ID):
		return
	var part: Dictionary = catalog["by_id"][PART_ID]
	var ability := StitchedParts.ability_at_tier(part, 3)
	var found: Dictionary = {}
	for seed_value in range(1, SEED_SEARCH_LIMIT):
		var b := _battle(catalog, seed_value, 3)
		if b == null:
			continue
		if not _to(b, WARDEN):
			continue
		var warden := b.get_unit(WARDEN)
		var foe := b.get_unit(RANK_THREE_FOE)
		if int(warden["rank"]) != 1 and int(warden["rank"]) != 2:
			continue
		if foe.is_empty() or int(foe["rank"]) != RANK_THREE or int(foe["hp"]) <= 0:
			continue
		var start_state := b.state_snapshot()
		var start_rng := b.rng_state()
		var attempt := b.use_part(PART_ID, RANK_THREE)
		if not bool(attempt.get("ok", false)):
			_check(false, "AC2: tier III refuses a living rank-three foe: "
				+ str(attempt.get("error", "")))
			return
		var attempt_results: Array = attempt.get("results", [])
		if attempt_results.size() != 1 or not bool(attempt_results[0].get("hit", false)):
			continue
		# Skip seeds where the victim's own turn starts right after Warden's: its turn-start
		# tick would decrement the freshly applied Weak before the authoritative read.
		if b.current_actor_id() == RANK_THREE_FOE:
			continue
		found = {
			"seed": seed_value,
			"battle": b,
			"receipt": attempt,
			"before": start_state,
			"rng": start_rng,
			"warden": warden,
			"foe": foe,
		}
		break
	_check(not found.is_empty(),
		"AC2: a bounded fixed-seed search witnesses a real tier-III rank-3 hit")
	if found.is_empty():
		return
	witnessed_hit_seed = int(found["seed"])
	var label := "AC2: tier-III rank-3 hit (seed %d)" % witnessed_hit_seed
	var witness_b: StitchedRules = found["battle"]
	var witness_receipt: Dictionary = found["receipt"]
	var before: Dictionary = found["before"]
	var witness_warden: Dictionary = found["warden"]
	var foe_before: Dictionary = found["foe"]
	var results: Array = witness_receipt.get("results", [])
	var hit: Dictionary = results[0]
	var victim := witness_b.get_unit(RANK_THREE_FOE)

	_check(witness_b.get_heroes().size() == 4 and witness_b.get_foes().size() == 3,
		label + ": the shipped 4v3 preview is intact")
	_check(str(witness_warden["parts"]["head"]["id"]) == PART_ID
		and int(witness_warden["parts"]["head"]["tier"]) == 3
		and not bool(witness_warden["parts"]["head"]["torn"]),
		label + ": Warden wears untorn tier-III Helmet Rattle in the head slot")
	_check(int(witness_warden["rank"]) == 1 or int(witness_warden["rank"]) == 2,
		label + ": Warden stands in a legal launch rank")
	_check(int(witness_warden["hp"]) > 0 and not bool(witness_warden["lost"]),
		label + ": Warden is alive when he acts")
	_check(str(foe_before["side"]) == "foe" and int(foe_before["rank"]) == RANK_THREE
		and int(foe_before["hp"]) > 0,
		label + ": a living foe occupies enemy rank 3")
	_check(witness_b.rng_state() != int(found["rng"]),
		label + ": the seeded action consumes RNG from the captured position")
	_check(str(witness_receipt.get("part", "")) == PART_ID
		and str(witness_receipt.get("ability", "")) == ABILITY_ID
		and str(witness_receipt.get("actor", "")) == WARDEN,
		label + ": the receipt names the equipped part, its ability and Warden")
	_check(results.size() == 1 and str(hit.get("target", "")) == RANK_THREE_FOE
		and int(hit.get("target_rank", -1)) == RANK_THREE,
		label + ": exactly one result lands on the chosen rank-three foe")
	var chance := StitchedRules.hit_chance(
		int(ability["acc"]) + int(witness_warden["acc"]),
		StitchedRules.effective_dodge(foe_before),
		int(witness_warden["miss_streak"]))
	_check(int(hit.get("hit_chance", -1)) == chance,
		label + ": the hit chance follows the authored ACC minus the foe's DODGE")
	_check(bool(hit.get("hit", false)) and int(hit.get("roll", 100)) <= chance,
		label + ": the fixed seed is a genuine seeded hit, not a forced one")
	var damage := int(hit.get("damage", 0))
	_check(damage > 0 and int(hit.get("target_hp", -1)) == int(foe_before["hp"]) - damage,
		label + ": the landed rattle deals direct damage to the chosen foe")
	var base_min := int(ability["dmg"][0]) + int(witness_warden["dmg_bonus"])
	var base_max := int(ability["dmg"][1]) + int(witness_warden["dmg_bonus"])
	var marked := int(foe_before["statuses"].get("mark", 0)) > 0
	var expected_min := StitchedRules.damage_after_modifiers(base_min,
		witness_warden["statuses"], foe_before["statuses"], marked,
		int(ability["mark_damage"]), int(foe_before["prot"]))
	var expected_max := StitchedRules.damage_after_modifiers(base_max,
		witness_warden["statuses"], foe_before["statuses"], marked,
		int(ability["mark_damage"]), int(foe_before["prot"]))
	var expected_crit := StitchedRules.damage_after_modifiers(
		StitchedRules.crit_damage(int(ability["dmg"][1])) + int(witness_warden["dmg_bonus"]),
		witness_warden["statuses"], foe_before["statuses"], marked,
		int(ability["mark_damage"]), int(foe_before["prot"]))
	if bool(hit.get("crit", false)):
		_check(damage == expected_crit,
			label + ": a critical rattle deals its authored critical damage")
	else:
		_check(damage >= expected_min and damage <= expected_max,
			label + ": a normal rattle stays inside its authored damage range")
	var status := _status_entry(hit.get("statuses", []), "weak")
	var weak_entries := 0
	for entry in hit.get("statuses", []):
		if entry is Dictionary and str(entry.get("status", "")) == "weak":
			weak_entries += 1
	_check(weak_entries == 1 and not status.is_empty()
		and int(status.get("duration", 0)) == 3,
		label + ": the hit receipt records exactly one Weak 3")
	var expected_weak := maxi(int(foe_before["statuses"].get("weak", 0)), 3)
	_check(int(victim["statuses"].get("weak", 0)) == expected_weak,
		label + ": the authoritative target carries Weak 3")
	_check(int(victim["hp"]) == int(foe_before["hp"]) - damage,
		label + ": the authoritative target's HP matches the receipt")
	for other_id in OTHER_FOES:
		var other_before := _snapshot_unit(before, other_id)
		var other_after := witness_b.get_unit(other_id)
		_check(int(other_after["hp"]) == int(other_before["hp"])
			and other_after["statuses"] == other_before["statuses"],
			label + ": the unselected foe " + other_id + " keeps its HP and statuses")
	_check(_turn_spent(witness_b, before),
		label + ": the one rattle spends exactly Warden's turn")


# ---------------------------------------------------------------- AC2/AC3: lower tiers refuse rank 3

func _test_lower_tiers_cannot_reach_rank_three() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)) or not catalog["by_id"].has(PART_ID):
		return
	var part: Dictionary = catalog["by_id"][PART_ID]
	for tier in [1, 2]:
		var label := "AC2/AC3: tier " + str(tier)
		var b := _battle(catalog, 1, tier)
		if b == null:
			continue
		if not _to(b, WARDEN):
			_check(false, label + ": the seeded order reaches Warden's turn")
			continue
		var foe := b.get_unit(RANK_THREE_FOE)
		_check(str(foe.get("side", "")) == "foe" and int(foe.get("rank", 0)) == RANK_THREE
			and int(foe.get("hp", 0)) > 0,
			label + ": a living legal-looking foe still occupies enemy rank 3")
		var ability := StitchedParts.ability_at_tier(part, tier)
		_check(not StitchedParts.ranks_allowed(int(ability["target_mask"]), RANK_THREE),
			label + ": the target mask refuses rank 3")
		var before := b.state_snapshot()
		var rng := b.rng_state()
		var refused := b.use_part(PART_ID, RANK_THREE)
		_check(not bool(refused.get("ok", true)),
			label + ": an equivalent lower-tier setup cannot target enemy rank 3")
		_check(before == b.state_snapshot() and rng == b.rng_state()
			and b.current_actor_id() == WARDEN,
			label + ": the lower-tier refusal changes no state, turn or seeded RNG")
		var legal := b.use_part(PART_ID, 1)
		_check(bool(legal.get("ok", false)),
			label + ": tiers I/II still use Helmet Rattle at enemy rank 1")
		var legal_results: Array = legal.get("results", [])
		_check(legal_results.size() == 1
			and str(legal_results[0].get("target", "")) == RANK_ONE_FOE,
			label + ": the legal lower-tier action lands on the rank-one foe")


# ---------------------------------------------------------------- AC3: rank 4, launch, off-turn

func _test_rank_four_and_launch_and_off_turn() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)) or not catalog["by_id"].has(PART_ID):
		return
	var part: Dictionary = catalog["by_id"][PART_ID]
	for tier in [1, 2, 3]:
		var label := "AC3: tier " + str(tier)
		var b := _battle(catalog, 1, tier)
		if b == null or not _to(b, WARDEN):
			_check(false, label + ": the rank-four witness reaches Warden's turn")
			continue
		_check(not StitchedParts.ranks_allowed(
			int(StitchedParts.ability_at_tier(part, tier)["target_mask"]), RANK_FOUR),
			label + ": the target mask refuses enemy rank 4")
		var before := b.state_snapshot()
		var rng := b.rng_state()
		var refused := b.use_part(PART_ID, RANK_FOUR)
		_check(not bool(refused.get("ok", true)),
			label + ": enemy rank 4 is refused")
		_check(before == b.state_snapshot() and rng == b.rng_state()
			and b.current_actor_id() == WARDEN,
			label + ": the rank-four refusal is state-, turn- and RNG-atomic")

	# A Warden standing in hero rank 3 is outside Helmet Rattle's authored launch ranks.
	var launch := _battle(catalog, 1, 3, RANK_THREE)
	if launch == null or not _to(launch, WARDEN):
		_check(false, "AC3: the wrong-launch witness reaches Warden's turn")
		return
	var warden := launch.get_unit(WARDEN)
	_check(int(warden["rank"]) == RANK_THREE,
		"AC3: the wrong-launch witness really stands in hero rank 3")
	var living_rank_three := launch.get_unit(RANK_THREE_FOE)
	_check(int(living_rank_three.get("hp", 0)) > 0
		and int(living_rank_three.get("rank", 0)) == RANK_THREE,
		"AC3: a living foe still occupies enemy rank 3")
	var ability := StitchedParts.ability_at_tier(part, 3)
	_check(not StitchedParts.ranks_allowed(int(ability["launch_mask"]), RANK_THREE),
		"AC3: the launch mask refuses hero rank 3")
	var launch_before := launch.state_snapshot()
	var launch_rng := launch.rng_state()
	var launch_refused := launch.use_part(PART_ID, RANK_THREE)
	_check(not bool(launch_refused.get("ok", true)),
		"AC3: an illegal launch rank is refused")
	_check(launch_before == launch.state_snapshot() and launch_rng == launch.rng_state()
		and launch.current_actor_id() == WARDEN,
		"AC3: the wrong-launch refusal changes no state, turn or seeded RNG")

	# A hero part used while a foe has the turn is refused without spending that foe's turn.
	var off_turn := _battle(catalog, 1, 3)
	if off_turn == null or not _to_side(off_turn, "foe"):
		_check(false, "AC3: the off-turn witness reaches a foe turn")
		return
	var actor := off_turn.current_actor_id()
	var off_before := off_turn.state_snapshot()
	var off_rng := off_turn.rng_state()
	var off_refused := off_turn.use_part(PART_ID, RANK_THREE)
	_check(not bool(off_refused.get("ok", true)),
		"AC3: a hero part used on a foe turn is refused")
	_check(off_before == off_turn.state_snapshot() and off_rng == off_turn.rng_state()
		and off_turn.current_actor_id() == actor,
		"AC3: an off-turn use changes no state, active actor or seeded RNG")


# ---------------------------------------------------------------- AC3: natural miss

func _test_natural_miss_applies_no_weak() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)) or not catalog["by_id"].has(PART_ID):
		return
	var witnessed := false
	for seed_value in range(1, SEED_SEARCH_LIMIT):
		var b := _battle(catalog, seed_value, 3)
		if b == null or not _to(b, WARDEN):
			continue
		var foe_before := b.get_unit(RANK_THREE_FOE)
		if foe_before.is_empty() or int(foe_before["rank"]) != RANK_THREE \
			or int(foe_before["hp"]) <= 0:
			continue
		var other_before := {}
		for other_id in OTHER_FOES:
			other_before[other_id] = b.get_unit(other_id)
		var before := b.state_snapshot()
		var receipt := b.use_part(PART_ID, RANK_THREE)
		if not bool(receipt.get("ok", false)):
			continue
		var results: Array = receipt.get("results", [])
		if results.size() != 1 or bool(results[0].get("hit", true)):
			continue
		var miss: Dictionary = results[0]
		var label := "AC3: natural miss (seed %d)" % seed_value
		var victim := b.get_unit(RANK_THREE_FOE)
		_check(int(miss.get("roll", 0)) > int(miss.get("hit_chance", 100)),
			label + ": the bounded search finds a genuine seeded miss")
		_check(int(miss.get("damage", -1)) == 0
			and int(miss.get("target_hp", -1)) == int(foe_before["hp"])
			and miss.get("statuses", []).is_empty(),
			label + ": a miss deals no damage and records no status")
		_check(int(victim["hp"]) == int(foe_before["hp"])
			and int(victim["statuses"].get("weak", 0))
				== int(foe_before["statuses"].get("weak", 0)),
			label + ": a legal miss adds no Weak to the chosen foe")
		for other_id in OTHER_FOES:
			if other_id == RANK_THREE_FOE:
				continue
			var other_after := b.get_unit(other_id)
			_check(int(other_after["hp"]) == int(other_before[other_id]["hp"])
				and other_after["statuses"] == other_before[other_id]["statuses"],
				label + ": the unselected foe " + other_id + " is untouched")
		_check(_turn_spent(b, before),
			label + ": the missed rattle still spends Warden's turn")
		witnessed = true
		break
	_check(witnessed, "AC3: a bounded fixed-seed search witnesses a real missed rattle")


# ---------------------------------------------------------------- AC3: identical-seed replay

func _trace(catalog: Dictionary, seed_value: int, tier: int) -> Dictionary:
	var b := _battle(catalog, seed_value, tier)
	if b == null or not _to(b, WARDEN):
		return {}
	var receipts: Array = []
	receipts.append(b.use_part(PART_ID, RANK_THREE))
	receipts.append(b.use_part(PART_ID, 1))
	return {
		"receipts": receipts,
		"state": b.state_snapshot(),
		"rng": b.rng_state(),
	}


func _test_replay() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)) or not catalog["by_id"].has(PART_ID):
		return
	var seed_value := witnessed_hit_seed if witnessed_hit_seed > 0 else 1
	for tier in [1, 2, 3]:
		var label := "AC3: tier %d replay" % tier
		var first := _trace(catalog, seed_value, tier)
		var second := _trace(catalog, seed_value, tier)
		_check(not first.is_empty() and first == second,
			label + ": equal seeds replay receipts, authoritative state and RNG")
		if first.is_empty():
			continue
		var receipts: Array = first.get("receipts", [])
		_check(receipts.size() == 2,
			label + ": the trace contains the two attempted actions")
		if receipts.size() != 2:
			continue
		if tier == 3:
			_check(bool(receipts[0].get("ok", false)),
				label + ": tier III accepts the living rank-three foe")
			_check(not bool(receipts[1].get("ok", true)),
				label + ": the follow-up action is refused off-turn")
			var results: Array = receipts[0].get("results", [])
			var status := {}
			if results.size() == 1:
				status = _status_entry(results[0].get("statuses", []), "weak")
			_check(results.size() == 1 and bool(results[0].get("hit", false))
				and int(status.get("duration", 0)) == 3,
				label + ": the replayed rank-three hit records Weak 3")
		else:
			_check(not bool(receipts[0].get("ok", true)),
				label + ": the lower tier refuses rank 3 in the replay")
			_check(bool(receipts[1].get("ok", false)),
				label + ": the lower tier's legal rank-one action still executes")
			var results: Array = receipts[1].get("results", [])
			_check(results.size() == 1
				and str(results[0].get("target", "")) == RANK_ONE_FOE,
				label + ": the replayed lower-tier action lands on the rank-one foe")


# ---------------------------------------------------------------- AC3: copied invalid records

func _test_invalid_copies() -> void:
	var document: Variant = _read_json(WARDEN_PATH)
	if not document is Dictionary:
		return
	var part := _raw_part(document)
	_check(not part.is_empty(), "AC3: the authored Helmet Rattle record is found in the JSON")
	if part.is_empty():
		return
	var source := JSON.stringify(part)
	_check(bool(StitchedParts.validate_part(part).get("ok", false)),
		"AC3: the untouched authored record validates before the negative checks")

	var unknown_effect := part.duplicate(true)
	unknown_effect["ability"]["effects"] = {"hex": 1}
	_check(not bool(StitchedParts.validate_part(unknown_effect).get("ok", true)),
		"AC3: an unsupported effects name is refused")

	var rank_five := part.duplicate(true)
	rank_five["ability"]["target"] = [5]
	_check(not bool(StitchedParts.validate_part(rank_five).get("ok", true)),
		"AC3: an out-of-range rank 5 is refused")

	var zero_weak := part.duplicate(true)
	zero_weak["ability"]["effects"] = {"weak": 0}
	_check(not bool(StitchedParts.validate_part(zero_weak).get("ok", true)),
		"AC3: zero Weak is refused")

	var zero_weak_tier := part.duplicate(true)
	zero_weak_tier["tiers"]["3"]["ability"]["effects"] = {"weak": 0}
	_check(not bool(StitchedParts.validate_part(zero_weak_tier).get("ok", true)),
		"AC3: zero Weak in a tier override is refused")

	_check(JSON.stringify(part) == source, "AC3: the negative checks never mutate the source record")
	var catalog := StitchedParts.load_catalog(WARDEN_PATH)
	_check(bool(catalog.get("ok", false)), "AC3: the shipped catalog still loads after the checks")
	if not bool(catalog.get("ok", false)):
		return
	for raw_part in catalog.get("parts", []):
		var id := str(raw_part.get("id", ""))
		_check(bool(StitchedParts.validate_part(raw_part).get("ok", false)),
			"AC3: the shipped part still validates: " + id)
		for tier in [1, 2, 3]:
			_check(bool(StitchedParts.validate_ability(
				StitchedParts.ability_at_tier(raw_part, tier)).get("ok", false)),
				"AC3: the shipped part still validates at tier %d: %s" % [tier, id])
