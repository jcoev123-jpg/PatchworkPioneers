extends SceneTree
## S4 Warden contract: Helmet Rattle's Weak seam deepens with its stitch tier (I/II/III -> 1/2/3).
##
## The real version-1 Warden catalog is loaded through StitchedParts.load_catalog and every
## named record is resolved through StitchedParts.ability_at_tier. Records are found by id,
## never by a catalog total or an ordered id list, so other coders may append parts in
## parallel. The shipped validator is then exercised with copied invalid records (unknown
## effect, out-of-range rank, zero Weak) and the real catalog is checked again afterwards so
## the negative checks can never hide a mutation of the authored data.

const WARDEN_PATH := "res://data/parts/warden_parts.json"
const PART_ID := "warden_head_helmet_rattle"
const ABILITY_ID := "head_helmet_rattle_move"
const WARDEN := "warden"
const TIER_WEAK := [1, 2, 3]
const TIER_DMG := [[3, 5], [5, 7], [6, 9]]
const TIER_CRIT := [0, 0, 8]
const TIER_ACC := [90, 90, 90]
const LAUNCH := [1, 2]
const TARGET := [1, 2]

## The seven other authored Warden parts that must keep their original tier outputs.
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
		"effects": [{"weak": 1}, {"weak": 1}, {"weak": 1}],
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
		"side": "enemy",
		"pose": "attack2",
		"dmg": [[5, 8], [6, 10], [8, 12]],
		"acc": [90, 90, 90],
		"crit": [0, 0, 0],
		"effects": [{"mark": 1}, {"mark": 1}, {"mark": 2}],
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


func _initialize() -> void:
	_test_real_catalog()
	_test_invalid_copies()
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


func _raw_part(document: Dictionary) -> Dictionary:
	for entry in document.get("parts", []):
		if entry is Dictionary and str(entry.get("id", "")) == PART_ID:
			return entry
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
	_check(str(part.get("text", "")) == "Rattle a nearby foe into Weakness.",
		"AC2: Helmet Rattle keeps its authored rules text")

	var base: Dictionary = part.get("ability", {})
	_check(str(base.get("id", "")) == ABILITY_ID, "AC2: tier I is the named Helmet Rattle move")
	_check(str(base.get("name", "")) == "Helmet Rattle", "AC2: the move keeps its name")
	_check(str(base.get("kind", "")) == "melee", "AC2: the move stays melee")
	_check(str(base.get("target_side", "")) == "enemy", "AC2: the move still targets foes")
	_check(base.get("launch", []) == LAUNCH, "AC2: launch stays exactly ranks 1 and 2")
	_check(base.get("target", []) == TARGET, "AC2: target stays exactly ranks 1 and 2")
	_check(int(base.get("launch_mask", 0)) == StitchedParts.rank_mask(LAUNCH),
		"AC2: the launch mask is derived from ranks 1 and 2")
	_check(int(base.get("target_mask", 0)) == StitchedParts.rank_mask(TARGET),
		"AC2: the target mask is derived from ranks 1 and 2")
	_check(not bool(base.get("multi", true)), "AC2: the move stays single-target")
	_check(int(base.get("acc", -1)) == 90, "AC2: tier I keeps ACC 90")
	_check(base.get("dmg", []) == [3, 5], "AC2: tier I keeps damage [3, 5]")
	_check(int(base.get("crit", -1)) == 0, "AC2: tier I keeps crit 0")
	_check(base.get("effects", {}) == {"weak": 1}, "AC1: tier I applies Weak 1")
	_check(int(base.get("self_move", -1)) == 0, "AC2: the move never shifts the wearer")
	_check(str(base.get("move", "")) == "attack2", "AC2: the move keeps the attack2 pose")

	for tier in [1, 2, 3]:
		var label := "AC1/AC2: tier " + str(tier)
		var ability := StitchedParts.ability_at_tier(part, tier)
		var stat := StitchedParts.stat_at_tier(part, tier)
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
		_check(ability.get("launch", []) == LAUNCH and ability.get("target", []) == TARGET,
			label + " keeps its launch and target ranks")
		_check(int(ability.get("launch_mask", 0)) == StitchedParts.rank_mask(LAUNCH)
			and int(ability.get("target_mask", 0)) == StitchedParts.rank_mask(TARGET),
			label + " keeps the ranks 1-2 masks")
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
				and ability.get("target", []) == expected["target"],
				label + " keeps its original launch and target ranks")
			_check(int(ability.get("launch_mask", 0)) == StitchedParts.rank_mask(expected["launch"])
				and int(ability.get("target_mask", 0))
					== StitchedParts.rank_mask(expected["target"]),
				label + " keeps its original rank masks")
			_check(str(ability.get("target_side", "")) == str(expected["side"])
				and str(ability.get("move", "")) == str(expected["pose"]),
				label + " keeps its original target side and pose")


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
