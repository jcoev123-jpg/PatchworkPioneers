extends SceneTree
## Design v4 S4-preparation data contract: the Seamstress's eight wearable Stitched parts.
##
## This test reads the new, independent res://data/parts/seamstress_parts.json catalog. The retired
## v3 card catalogs are stable read-only provenance for the numbers and are never imported here.
## It then loads the shipped S2 preview fixture into memory, appends the eight authored records,
## equips only the four starters on the existing seamstress hero and drives real StitchedRules
## turns. Nothing here wires the kit into the title screen, a live fight, rewards or a picker:
## this slice is data plus a seeded rules witness, so no player-facing path is claimed.
##
## The rear-rank support slice additionally proves that the three ally-support abilities keep
## working after the Seamstress is displaced into the fourth hero rank: a real foe hit wounds
## the rank-1 Warden, two real Moves carry her back to rank 4, and her next real turn casts the
## equipped Mending Knot, Shielding Hem or Patchwork Poultice on that Warden.
##
## The Needle Rain slice proves the alternative ARMS part is the only multi-target record in this
## kit: one real use_part("needle_rain", 1) turn showers every living foe in enemy ranks 1-4
## exactly once each, each struck foe resolves its own damage and Bleed, and a miss leaves no
## Bleed. The seven other parts keep single-target receipts. Its detached fixture moves the
## existing third preview foe (moth_scribe) from enemy rank 3 into enemy rank 4 in that battle's
## own memory, leaving rank 3 vacant: the same three foes, never an invented fourth, and the
## shared preview file is untouched. A second slice carries the Seamstress back to hero rank 4
## with two genuine Move turns and proves the same shower still reaches the rank-4 foe from the
## rear rank without ever striking the ally standing in hero rank 4.
##
## The Mark slice pairs two equal-seed tier-II showers that differ only by an in-memory existing
## Mark 2 on the shipped rank-3 Moth Scribe: the already-marked foe loses exactly three more HP,
## the two unmarked foes take identical damage and Bleed 4, the pre-existing Mark survives and
## the shower never applies a new Mark.

const PARTS_PATH := "res://data/parts/seamstress_parts.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const OWNER := "seamstress"
const SLOTS := ["head", "arms", "torso", "legs"]
const MOVE_POSES := ["attack", "attack2", "guard", "skill"]
const MIN_RANK := 1
const MAX_RANK := 4
const REQUIRED_ABILITY_FIELDS := [
	"id", "name", "kind", "launch", "target", "target_side", "multi", "acc", "dmg",
	"crit", "mark_damage", "effects", "self_move", "move",
]
## Retired card-system keys that must never appear as a Stitched part effect.
const RETIRED_CARD_KEYS := [
	"block", "pinned", "unravel", "tether_share_percent", "cleanse_debuff", "energy",
	"cooldown", "mana", "draw", "cost",
]

## The four starter wearables: one per slot, the initial equipped kit in the test fixture.
const STARTER_PARTS := {
	"head": "seamstress_mending_knot_hat",
	"arms": "seamstress_thread_prick_needle",
	"torso": "seamstress_shielding_hem_coat",
	"legs": "seamstress_tether_loop_spools",
}
## The four alternative wearables: never additional battle actions until equipped.
const ALTERNATE_PARTS := {
	"head": "seamstress_scarlet_knot_hat",
	"arms": "seamstress_needle_rain_needle",
	"torso": "seamstress_poultice_apron",
	"legs": "seamstress_bobbin_snag_spools",
}
const ALL_PART_IDS := [
	"seamstress_mending_knot_hat",
	"seamstress_scarlet_knot_hat",
	"seamstress_thread_prick_needle",
	"seamstress_needle_rain_needle",
	"seamstress_shielding_hem_coat",
	"seamstress_poultice_apron",
	"seamstress_tether_loop_spools",
	"seamstress_bobbin_snag_spools",
]
## The three ally-support abilities that must keep working from the rear hero rank 4, with their
## tier-I heal and Guard numbers. Only their base launch arrays changed in the catalog.
const REAR_SUPPORT_CASES := {
	"seamstress_mending_knot_hat": {"heal": 4, "guard": 0},
	"seamstress_shielding_hem_coat": {"heal": 2, "guard": 2},
	"seamstress_poultice_apron": {"heal": 3, "guard": 1},
}
## The Poultice is the alternative torso, so its own fresh battle wears it instead of the coat.
const POULTICE_KIT := {
	"head": "seamstress_mending_knot_hat",
	"arms": "seamstress_thread_prick_needle",
	"torso": "seamstress_poultice_apron",
	"legs": "seamstress_tether_loop_spools",
}
## The alternative arms part is the one multi-target record: every other slot stays as shipped.
const NEEDLE_KIT := {
	"head": "seamstress_mending_knot_hat",
	"arms": "seamstress_needle_rain_needle",
	"torso": "seamstress_shielding_hem_coat",
	"legs": "seamstress_tether_loop_spools",
}
## The shipped S2 preview foes and the rank each one occupies.
const NEEDLE_FOE_RANKS := {
	"fray_scavenger": 1,
	"scissor_crab": 2,
	"moth_scribe": 3,
}
## The same three shipped foes after the detached-fixture relocation used for rank-4 reach: the
## existing third foe stands in enemy rank 4 and enemy rank 3 is left vacant. No foe is added,
## removed or re-authored, and the shared preview file is never edited.
const NEEDLE_RANK4_FOE_RANKS := {
	"fray_scavenger": 1,
	"scissor_crab": 2,
	"moth_scribe": 4,
}

## The authored acceptance contract, one row per part id, indexed by tier - 1.
const EXPECTED := {
	"seamstress_mending_knot_hat": {
		"name": "Mending Knot Hat", "slot": "head", "stat_key": "acc", "stat": [2, 3, 4],
		"ability_id": "mending_knot", "ability_name": "Mending Knot", "kind": "heal",
		"launch": [2, 3, 4], "target": [1, 2, 3, 4], "target_side": "ally", "pose": "skill",
		"multi": false,
		"acc": 100,
		"mark": [0, 0, 0],
		"dmg": [[0, 0], [0, 0], [0, 0]],
		"effects": [{"heal": 4}, {"heal": 6}, {"heal": 8}],
	},
	"seamstress_scarlet_knot_hat": {
		"name": "Scarlet Knot Hat", "slot": "head", "stat_key": "crit", "stat": [2, 3, 4],
		"ability_id": "scarlet_knot", "ability_name": "Scarlet Knot", "kind": "debuff",
		"launch": [1, 2, 3], "target": [1, 2, 3], "target_side": "enemy", "pose": "skill",
		"multi": false,
		"acc": 90,
		"mark": [0, 0, 0],
		"dmg": [[0, 0], [0, 0], [0, 0]],
		"effects": [
			{"bleed": 2, "weak": 1},
			{"bleed": 3, "weak": 1},
			{"bleed": 4, "weak": 2},
		],
	},
	"seamstress_thread_prick_needle": {
		"name": "Thread Prick Needle", "slot": "arms", "stat_key": "dmg", "stat": [1, 2, 3],
		"ability_id": "thread_prick", "ability_name": "Thread Prick", "kind": "ranged",
		"launch": [1, 2, 3], "target": [1, 2, 3], "target_side": "enemy", "pose": "attack",
		"multi": false,
		"acc": 90,
		"mark": [0, 0, 0],
		"dmg": [[2, 3], [3, 4], [4, 5]],
		"effects": [{"bleed": 2}, {"bleed": 3}, {"bleed": 4}],
	},
	"seamstress_needle_rain_needle": {
		"name": "Needle Rain Needle", "slot": "arms", "stat_key": "dmg", "stat": [1, 2, 3],
		"ability_id": "needle_rain", "ability_name": "Needle Rain", "kind": "ranged",
		"launch": [1, 2, 3, 4], "target": [1, 2, 3, 4], "target_side": "enemy", "pose": "attack2",
		"multi": true,
		"acc": 90,
		"mark": [2, 3, 4],
		"dmg": [[1, 2], [2, 3], [3, 4]],
		"effects": [{"bleed": 3}, {"bleed": 4}, {"bleed": 5}],
	},
	"seamstress_shielding_hem_coat": {
		"name": "Shielding Hem Coat", "slot": "torso", "stat_key": "max_hp", "stat": [4, 6, 8],
		"ability_id": "shielding_hem", "ability_name": "Shielding Hem", "kind": "guard",
		"launch": [1, 2, 3, 4], "target": [1, 2, 3, 4], "target_side": "ally", "pose": "guard",
		"multi": false,
		"acc": 100,
		"mark": [0, 0, 0],
		"dmg": [[0, 0], [0, 0], [0, 0]],
		"effects": [
			{"guard": 2, "heal": 2},
			{"guard": 3, "heal": 3},
			{"guard": 4, "heal": 4},
		],
	},
	"seamstress_poultice_apron": {
		"name": "Patchwork Poultice Apron", "slot": "torso", "stat_key": "prot", "stat": [5, 7, 9],
		"ability_id": "patchwork_poultice", "ability_name": "Patchwork Poultice", "kind": "guard",
		"launch": [2, 3, 4], "target": [1, 2, 3, 4], "target_side": "ally", "pose": "guard",
		"multi": false,
		"acc": 100,
		"mark": [0, 0, 0],
		"dmg": [[0, 0], [0, 0], [0, 0]],
		"effects": [
			{"heal": 3, "guard": 1},
			{"heal": 4, "guard": 2},
			{"heal": 5, "guard": 3},
		],
	},
	"seamstress_tether_loop_spools": {
		"name": "Tether Loop Spools", "slot": "legs", "stat_key": "speed", "stat": [1, 2, 3],
		"ability_id": "tether_loop", "ability_name": "Tether Loop", "kind": "debuff",
		"launch": [2, 3], "target": [1, 2, 3], "target_side": "enemy", "pose": "skill",
		"multi": false,
		"acc": 90,
		"mark": [0, 0, 0],
		"dmg": [[0, 0], [0, 0], [0, 0]],
		"effects": [{"tangled": 1}, {"tangled": 2}, {"tangled": 3}],
	},
	"seamstress_bobbin_snag_spools": {
		"name": "Bobbin Snag Spools", "slot": "legs", "stat_key": "dodge", "stat": [3, 4, 5],
		"ability_id": "bobbin_snag", "ability_name": "Bobbin Snag", "kind": "debuff",
		"launch": [2, 3], "target": [1, 2, 3], "target_side": "enemy", "pose": "skill",
		"multi": false,
		"acc": 90,
		"mark": [0, 0, 0],
		"dmg": [[0, 0], [0, 0], [0, 0]],
		"effects": [
			{"mark": 1, "tangled": 1},
			{"mark": 2, "tangled": 1},
			{"mark": 3, "tangled": 1},
		],
	},
}

var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	_test_catalog()
	_test_tiers()
	_test_live_tier_stats()
	_test_negatives()
	_test_live_starters()
	_test_live_rejections()
	_test_needle_rain_multi()
	_test_needle_rain_mark_bonus()
	_test_needle_rain_rear_launch()
	_test_needle_rain_rejections()
	_test_rear_launch_masks()
	_test_rear_rank_support()
	_test_rear_illegal_forward_launch()
	_test_determinism()
	if _failures.is_empty():
		print("stitched_s4_seamstress_parts_test: PASS (", _checks, " checks)")
	else:
		for failure in _failures:
			printerr(failure)
		print("stitched_s4_seamstress_parts_test: FAIL (", _failures.size(), " failures / ", _checks, " checks)")
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


# ---------------------------------------------------------------- AC1: the eight-part catalog

func _test_catalog() -> void:
	var catalog := _catalog()
	_check(bool(catalog.get("ok", false)), "AC1: the Seamstress catalog loads through StitchedParts.load_catalog")
	if not bool(catalog.get("ok", false)):
		return
	var by_id: Dictionary = catalog["by_id"]
	for part_id in ALL_PART_IDS:
		_check(by_id.has(part_id), "AC1: the catalog authors the named part " + part_id)
	if by_id.size() != ALL_PART_IDS.size():
		_check(false, "AC1: the catalog holds only the eight named Seamstress wearables")
	for part_id in by_id:
		_check(str(part_id) in ALL_PART_IDS, "AC1: unexpected extra part in this kit catalog: " + str(part_id))
	# The brief names the contract IDs exactly; the earlier invented torso id must be gone.
	_check(not by_id.has("seamstress_patchwork_poultice_apron"),
		"AC1: the invented torso id seamstress_patchwork_poultice_apron is absent")
	_check(by_id.has("seamstress_poultice_apron"),
		"AC1: the contract torso id seamstress_poultice_apron is authored")
	# Every loaded record must still pass the engine's own single-entry validator.
	var parts: Array = catalog["parts"]
	for part in parts:
		var record: Dictionary = part
		_check(str(record["owner"]) == OWNER, "AC1: " + str(record["id"]) + " is owned by the seamstress")
		_check(bool(StitchedParts.validate_part(record).get("ok", false)),
			"AC1: validate_part accepts the shipped " + str(record["id"]))
	var names: Dictionary = {}
	var ability_ids: Dictionary = {}
	var slot_counts: Dictionary = {"head": 0, "arms": 0, "torso": 0, "legs": 0}
	for part_id in ALL_PART_IDS:
		if not by_id.has(part_id):
			continue
		var part: Dictionary = by_id[part_id]
		var spec: Dictionary = EXPECTED[part_id]
		var slot := str(spec["slot"])
		slot_counts[slot] = int(slot_counts[slot]) + 1
		_check(str(part["slot"]) == slot, "AC1: " + part_id + " fills the authored " + slot + " slot")
		_check(str(part["name"]) == str(spec["name"]), "AC1: " + part_id + " carries its authored name")
		var stat_keys: Array = part["stat"].keys()
		_check(stat_keys.size() == 1 and str(stat_keys[0]) == str(spec["stat_key"]),
			"AC1: " + part_id + " grants exactly the slot-legal stat " + str(spec["stat_key"]))
		_check(stat_keys.size() == 1 and str(stat_keys[0]) in StitchedParts.SLOT_STATS[slot],
			"AC1: " + part_id + " never puts a stat in the wrong slot")
		_check(not str(part.get("text", "")).strip_edges().is_empty(), "AC1: " + part_id + " has rules text")
		var ability: Dictionary = part["ability"]
		for field in REQUIRED_ABILITY_FIELDS:
			_check(ability.has(field), "AC1: %s ability includes the mandatory field %s" % [part_id, field])
		_check(ability["multi"] is bool and bool(ability["multi"]) == bool(spec["multi"]),
			"AC1: %s authors multi=%s; only Needle Rain may strike more than one foe"
				% [part_id, str(spec["multi"])])
		_check(int(ability["crit"]) == 0, "AC1: " + part_id + " keeps crit 0 so the head ACC/crit stat is the only crit source")
		_check(int(ability["self_move"]) == 0, "AC1: " + part_id + " takes no unstated self move")
		_check(str(ability["move"]) in MOVE_POSES, "AC1: " + part_id + " uses an existing authored move pose")
		_check(str(ability["move"]) == str(spec["pose"]), "AC1: " + part_id + " uses its authored pose " + str(spec["pose"]))
		_check(str(ability["id"]) == str(spec["ability_id"]), "AC1: " + part_id + " grants the ability " + str(spec["ability_id"]))
		_check(str(ability["name"]) == str(spec["ability_name"]), "AC1: " + part_id + " names its ability " + str(spec["ability_name"]))
		_check(str(ability["kind"]) == str(spec["kind"]), "AC1: " + part_id + " uses the ability kind " + str(spec["kind"]))
		_check(str(ability["target_side"]) == str(spec["target_side"]), "AC1: " + part_id + " targets the " + str(spec["target_side"]) + " side")
		_check(int(ability["acc"]) == int(spec["acc"]), "AC1: " + part_id + " keeps its authored ACC")
		_check(int(ability["mark_damage"]) == int(spec["mark"][0]),
			"AC1: " + part_id + " authors its tier-I mark_damage " + str(spec["mark"][0]))
		_check(_int_list(ability["launch"]) == _int_list(spec["launch"]), "AC1: " + part_id + " launches from its authored ranks")
		_check(_int_list(ability["target"]) == _int_list(spec["target"]), "AC1: " + part_id + " aims at its authored target ranks")
		names[str(part["name"])] = true
		ability_ids[str(ability["id"])] = true
	# Slot spread: one starter and one alternative in each of the four slots.
	for slot in SLOTS:
		_check(int(slot_counts[slot]) == 2, "AC1: exactly two authored parts fill the " + slot + " slot")
	_check(names.size() == ALL_PART_IDS.size(), "AC1: all eight part names are distinct")
	_check(ability_ids.size() == ALL_PART_IDS.size(), "AC1: all eight ability ids are distinct")
	_check(names.has("Mending Knot Hat") and names.has("Scarlet Knot Hat")
		and names.has("Thread Prick Needle") and names.has("Needle Rain Needle")
		and names.has("Shielding Hem Coat") and names.has("Patchwork Poultice Apron")
		and names.has("Tether Loop Spools") and names.has("Bobbin Snag Spools"),
		"AC1: the look-driven names cover both hats, needles, coats and spools")
	# The four explicitly identified starters and the four alternatives, keyed by slot.
	for slot in SLOTS:
		var starter := str(STARTER_PARTS[slot])
		var alternate := str(ALTERNATE_PARTS[slot])
		_check(by_id.has(starter) and str(by_id[starter]["slot"]) == slot,
			"AC1: %s is the starter wearable for the %s slot" % [starter, slot])
		_check(by_id.has(alternate) and str(by_id[alternate]["slot"]) == slot,
			"AC1: %s is the alternative wearable for the %s slot" % [alternate, slot])
	# The one edited description really explains the rank 1-4 shower from hero ranks 1-4, plus damage and Bleed.
	var rain_text := str(by_id["seamstress_needle_rain_needle"]["text"]).to_lower()
	_check(rain_text.contains("each living foe") and rain_text.contains("enemy ranks 1-4"),
		"AC1: the Needle Rain text names every living foe in enemy ranks 1-4")
	_check(not rain_text.contains("enemy ranks 1-3"),
		"AC1: the Needle Rain text no longer stops the shower at enemy rank 3")
	_check(rain_text.contains("once"),
		"AC1: the Needle Rain text keeps exactly one hit attempt per living foe")
	_check(rain_text.contains("hero ranks 1-4"),
		"AC1: the Needle Rain text names its new launch reach from hero ranks 1-4")
	_check(rain_text.contains("1-2") and rain_text.contains("bleed 3"),
		"AC1: the Needle Rain text keeps its authored tier-I 1-2 damage and Bleed 3")
	_check(rain_text.contains("damage") and rain_text.contains("bleed"),
		"AC1: the Needle Rain text names its damage and its Bleed")
	_check(not rain_text.contains("one foe") and not rain_text.contains("single"),
		"AC1: the Needle Rain text no longer claims a single foe")
	_check(rain_text.contains("already marked") and rain_text.contains("bonus damage"),
		"AC1: the Needle Rain text names its bonus against an already-Marked foe")
	var raw: Variant = _read_json(PARTS_PATH)
	if raw is Dictionary:
		var document: Dictionary = raw
		_check(int(document.get("version", 0)) == 1, "AC1: the parts file keeps the version-1 schema")
		var raw_parts: Variant = document.get("parts")
		_check(raw_parts is Array and raw_parts.size() == ALL_PART_IDS.size(),
			"AC1: the authored parts array holds exactly the eight named wearables")
		if raw_parts is Array:
			var raw_needle := _raw_part_for(raw_parts, "seamstress_needle_rain_needle")
			_check(not raw_needle.is_empty(), "AC1: the raw JSON authors the Needle Rain Needle record")
			if not raw_needle.is_empty():
				var raw_ability: Dictionary = raw_needle.get("ability", {})
				_check(int(raw_ability.get("mark_damage", -1)) == 2,
					"AC1: the authored Needle Rain base mark_damage is 2")
				var raw_tiers: Dictionary = raw_needle.get("tiers", {})
				var raw_tier_two: Dictionary = raw_tiers.get("2", {})
				var raw_tier_three: Dictionary = raw_tiers.get("3", {})
				var raw_tier_two_ability: Dictionary = raw_tier_two.get("ability", {})
				var raw_tier_three_ability: Dictionary = raw_tier_three.get("ability", {})
				_check(int(raw_tier_two_ability.get("mark_damage", -1)) == 3,
					"AC1: the authored Needle Rain tier-II mark_damage override is 3")
				_check(int(raw_tier_three_ability.get("mark_damage", -1)) == 4,
					"AC1: the authored Needle Rain tier-III mark_damage override is 4")
			for other_id in ALL_PART_IDS:
				if other_id == "seamstress_needle_rain_needle":
					continue
				var other_raw := _raw_part_for(raw_parts, other_id)
				var other_ability: Dictionary = other_raw.get("ability", {})
				_check(not other_ability.has("mark_damage")
					or int(other_ability.get("mark_damage", -1)) == 0,
					"AC1: the authored " + other_id + " carries no mark bonus of its own")
	else:
		_check(false, "AC1: the parts file parses as a JSON object")


# ---------------------------------------------------------------- AC3: tiers, masks and keys

func _test_tiers() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)):
		return
	for part_id in ALL_PART_IDS:
		if not catalog["by_id"].has(part_id):
			_check(false, "AC3: tier checks need the authored part " + part_id)
			continue
		var part: Dictionary = catalog["by_id"][part_id]
		var spec: Dictionary = EXPECTED[part_id]
		var tiers: Dictionary = part["tiers"]
		_check(tiers.has("2") and tiers.has("3") and not tiers.has("1"),
			"AC3: " + part_id + " authors tiers II and III as partial overrides over the tier-I base")
		for tier in [1, 2, 3]:
			var ability := StitchedParts.ability_at_tier(part, tier)
			var stat := StitchedParts.stat_at_tier(part, tier)
			var tag := "%s tier %d" % [part_id, tier]
			_check(not ability.is_empty(), "AC3: " + tag + " resolves its ability")
			if ability.is_empty():
				continue
			_check(bool(StitchedParts.validate_ability(ability).get("ok", false)), "AC3: " + tag + " ability validates")
			_check(_int_dict(stat) == _int_dict({str(spec["stat_key"]): int(spec["stat"][tier - 1])}),
				"AC3: " + tag + " stat is %s %d" % [str(spec["stat_key"]), int(spec["stat"][tier - 1])])
			# Identity and rank masks carry through the merge unchanged.
			_check(str(ability["id"]) == str(spec["ability_id"]), "AC3: " + tag + " keeps its ability id")
			_check(str(ability["kind"]) == str(spec["kind"]), "AC3: " + tag + " keeps its kind")
			_check(str(ability["target_side"]) == str(spec["target_side"]), "AC3: " + tag + " keeps its target side")
			_check(str(ability["move"]) == str(spec["pose"]) and str(ability["move"]) in MOVE_POSES,
				"AC3: " + tag + " keeps an existing move pose")
			_check(int(ability["acc"]) == int(spec["acc"]), "AC3: " + tag + " keeps its authored ACC")
			_check(bool(ability["multi"]) == bool(spec["multi"]),
				"AC3: " + tag + " keeps its authored multi flag " + str(spec["multi"]))
			_check(int(ability["crit"]) == 0 and int(ability["self_move"]) == 0,
				"AC3: " + tag + " adds no crit or self move")
			_check(_int_list(ability["launch"]) == _int_list(spec["launch"]), "AC3: " + tag + " launch ranks")
			_check(_int_list(ability["target"]) == _int_list(spec["target"]), "AC3: " + tag + " target ranks")
			var launch_mask := int(ability["launch_mask"])
			var target_mask := int(ability["target_mask"])
			_check(launch_mask == StitchedParts.rank_mask(ability["launch"]) and launch_mask != 0,
				"AC3: " + tag + " launch mask matches its authored ranks")
			_check(target_mask == StitchedParts.rank_mask(ability["target"]) and target_mask != 0,
				"AC3: " + tag + " target mask matches its authored ranks")
			_check((launch_mask | target_mask) & ~StitchedParts.ALL_RANKS_MASK == 0,
				"AC3: " + tag + " uses only ranks 1-4")
			for rank in range(MIN_RANK, MAX_RANK + 1):
				_check(StitchedParts.ranks_allowed(launch_mask, rank) == (rank in spec["launch"]),
					"%s: rank %d launch legality" % [tag, rank])
				_check(StitchedParts.ranks_allowed(target_mask, rank) == (rank in spec["target"]),
					"%s: rank %d target legality" % [tag, rank])
			_check(_int_list(ability["dmg"]) == _int_list(spec["dmg"][tier - 1]),
				"AC3: " + tag + " damage range " + str(spec["dmg"][tier - 1]))
			_check(int(ability["mark_damage"]) == int(spec["mark"][tier - 1]),
				"AC3: " + tag + " mark_damage " + str(spec["mark"][tier - 1]))
			_check(_int_dict(ability["effects"]) == _int_dict(spec["effects"][tier - 1]),
				"AC3: " + tag + " effects " + str(spec["effects"][tier - 1]))
			for key in ability["effects"]:
				_check(str(key) in StitchedParts.EFFECT_KEYS, "AC3: " + tag + " effect " + str(key) + " is a registered Stitched key")
				_check(not str(key) in RETIRED_CARD_KEYS, "AC3: " + tag + " never uses retired card key " + str(key))
			_check(not ability["effects"].has("dodge") and not ability["effects"].has("duration"),
				"AC3: " + tag + " authors no temporary-dodge metadata")
		# Numbers only ever rise across the three stitch tiers, and each tier really overrides values.
		var stats := [int(spec["stat"][0]), int(spec["stat"][1]), int(spec["stat"][2])]
		_check(stats[0] < stats[1] and stats[1] < stats[2], "AC3: " + part_id + " stat rises each tier")
		var previous_damage := _int_list(spec["dmg"][0])
		var previous_effects: Dictionary = spec["effects"][0]
		for tier in [2, 3]:
			var dmg := _int_list(spec["dmg"][tier - 1])
			var effects: Dictionary = spec["effects"][tier - 1]
			_check(dmg[0] >= previous_damage[0] and dmg[1] >= previous_damage[1],
				"AC3: " + part_id + " damage never falls below the previous tier")
			for key in effects:
				_check(int(effects[key]) >= _effect_value(previous_effects, str(key)),
					"AC3: %s %s never falls between tiers" % [part_id, str(key)])
			_check(dmg != previous_damage or effects != previous_effects,
				"AC3: %s tier %d really overrides its own damage or effects" % [part_id, tier])
			previous_damage = dmg
			previous_effects = effects


func _effect_value(effects: Dictionary, key: String) -> int:
	return int(effects.get(key, 0))


# ---------------------------------------------------------------- AC3: tiers reach live stats

## Tier III really reaches live hero stats through the engine's own merge, not only the lookup.
func _test_live_tier_stats() -> void:
	var tier_one := _build_battle(31, 1, STARTER_PARTS)
	var tier_three := _build_battle(31, 3, STARTER_PARTS)
	if tier_one == null or tier_three == null:
		return
	var low := tier_one.get_unit("seamstress")
	var high := tier_three.get_unit("seamstress")
	_check(int(low["parts"]["head"]["tier"]) == 1 and int(high["parts"]["head"]["tier"]) == 3,
		"AC3: the fixture equips the same starter kit at tiers I and III")
	_check(int(low["acc"]) == int(low["base_acc"]) + 2,
		"AC3: tier-I Mending Knot adds its ACC 2 to the live hero")
	_check(int(high["acc"]) == int(high["base_acc"]) + 4,
		"AC3: tier-III Mending Knot adds its ACC 4 to the live hero")
	_check(int(low["dmg_bonus"]) == 1 and int(high["dmg_bonus"]) == 3,
		"AC3: the needle damage stat reaches live damage at tiers I and III")
	_check(int(low["max_hp"]) == int(low["base_max_hp"]) + 4
		and int(high["max_hp"]) == int(high["base_max_hp"]) + 8,
		"AC3: Shielding Hem adds its live max HP at tiers I and III")
	_check(int(low["speed"]) == int(low["base_speed"]) + 1
		and int(high["speed"]) == int(high["base_speed"]) + 3,
		"AC3: Tether Loop adds its live SPEED at tiers I and III")
	_check(int(high["hp"]) == int(high["max_hp"]),
		"AC3: a tier-III hero really starts at the raised max HP")


# ---------------------------------------------------------------- AC1/AC3: fail-closed negatives

func _test_negatives() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)):
		return
	var by_id: Dictionary = catalog["by_id"]
	var head: Dictionary = by_id["seamstress_mending_knot_hat"].duplicate(true)
	for bad_rank in [-1, 0, 5, 1.5]:
		var mutated := head.duplicate(true)
		mutated["ability"]["launch"] = [bad_rank]
		_check(not bool(StitchedParts.validate_part(mutated).get("ok", false)),
			"AC1: an illegal launch rank %s is refused" % str(bad_rank))
		var retarget := head.duplicate(true)
		retarget["ability"]["target"] = [bad_rank]
		_check(not bool(StitchedParts.validate_part(retarget).get("ok", false)),
			"AC1: an illegal target rank %s is refused" % str(bad_rank))
	var repeated := head.duplicate(true)
	repeated["ability"]["launch"] = [2, 2]
	_check(not bool(StitchedParts.validate_part(repeated).get("ok", false)),
		"AC1: a repeated launch rank is refused")
	# A slot/stat mismatch (a head part trying to grant SPEED) is refused.
	var wrong_stat := head.duplicate(true)
	wrong_stat["stat"] = {"speed": 4}
	_check(not bool(StitchedParts.validate_part(wrong_stat).get("ok", false)),
		"AC1: a head part cannot grant SPEED")
	var wrong_crit := head.duplicate(true)
	wrong_crit["stat"] = {"crit": 2, "dmg": 2}
	_check(not bool(StitchedParts.validate_part(wrong_crit).get("ok", false)),
		"AC1: a head part cannot grant arms damage")
	# Unsupported retired card effects are refused, never silently carried into Stitched data.
	for key in ["cleanse_debuff", "block", "unravel", "tether_share_percent", "energy", "cooldown", "mana"]:
		var mutated := head.duplicate(true)
		mutated["ability"]["effects"] = {key: 1}
		_check(not bool(StitchedParts.validate_part(mutated).get("ok", false)),
			"AC3: the retired card-only effect " + key + " is refused")
	var pinned := head.duplicate(true)
	pinned["ability"]["effects"] = {"pinned": true}
	_check(not bool(StitchedParts.validate_part(pinned).get("ok", false)),
		"AC3: the retired card-only Pinned flag is refused")
	# Tier overrides are validated too: an unsupported effect inside tier III fails closed.
	var broken_tier := head.duplicate(true)
	broken_tier["tiers"]["3"]["ability"]["effects"] = {"cleanse_debuff": 1}
	_check(not bool(StitchedParts.validate_part(broken_tier).get("ok", false)),
		"AC3: an unsupported effect in a tier override fails closed")
	# Equipping a legs part in the head slot is refused by the real battle builder.
	var mismatched_kit := {
		"head": "seamstress_tether_loop_spools",
		"arms": "seamstress_thread_prick_needle",
		"torso": "seamstress_shielding_hem_coat",
		"legs": "seamstress_tether_loop_spools",
	}
	var bad_config := _preview_config(11, 1, mismatched_kit)
	_check(not bad_config.is_empty(), "AC1 negative: the S2 fixture can be prepared for a slot-mismatch check")
	if not bad_config.is_empty():
		var created := StitchedRules.create(bad_config)
		_check(not bool(created.get("ok", false)), "AC1: a legs part cannot be worn in the head slot")
	# Corrupting in-memory copies must never touch the shipped file.
	var reloaded := _catalog()
	_check(bool(reloaded.get("ok", false)), "AC1: the shipped catalog still loads after the negative copies")
	if bool(reloaded.get("ok", false)):
		var shipped: Dictionary = reloaded["by_id"]["seamstress_mending_knot_hat"]
		_check(_int_dict(shipped["stat"]) == {"acc": 2}, "AC1: the shipped Mending Knot Hat keeps its authored ACC 2")
		_check(_int_list(shipped["ability"]["launch"]) == [2, 3, 4],
			"AC1: the shipped Mending Knot launch ranks now reach the rear hero rank 4")


# ---------------------------------------------------------------- AC2: real starter actions

func _test_live_starters() -> void:
	_thread_prick_witness()
	_tether_loop_witness()
	_heal_witness(false)
	_heal_witness(true)


## Thread Prick damages and Bleeds one enemy, and the Bleed really ticks on that foe's turn.
func _thread_prick_witness() -> void:
	var witness := _first_hit("seamstress_thread_prick_needle", 1)
	_check(not witness.is_empty(), "AC2: a fixed seed lands Thread Prick on the rank-1 foe")
	if witness.is_empty():
		return
	var battle: StitchedRules = witness["battle"]
	var receipt: Dictionary = witness["receipt"]
	var result: Dictionary = receipt["results"][0]
	_check(str(receipt.get("part", "")) == "seamstress_thread_prick_needle",
		"AC2: the receipt names the equipped Thread Prick part")
	_check(receipt["results"].size() == 1,
		"AC2: the starter Thread Prick stays single-target with exactly one foe result")
	_check(str(result["target"]) == "fray_scavenger" and str(result["target_side"]) == "foe",
		"AC2: Thread Prick aims at the enemy side in the chosen rank")
	var damage := int(result["damage"])
	_check(damage >= 3 and damage <= 5, "AC2: Thread Prick deals its 2-3 range plus the +1 arms damage")
	_check(int(result["target_hp"]) == int(battle.get_unit("fray_scavenger")["max_hp"]) - damage,
		"AC2: the foe's HP drops by exactly the dealt damage")
	_check(int(battle.get_unit("fray_scavenger")["statuses"].get("bleed", 0)) == 2,
		"AC2: a landed Thread Prick leaves a real Bleed 2 on the foe")
	_check(_has_status(result.get("statuses", []), "bleed"), "AC2: the receipt reports the applied Bleed status")
	var hp_after_hit := int(battle.get_unit("fray_scavenger")["hp"])
	_check(_to(battle, "fray_scavenger"), "AC2: the bleeding foe reaches its own seeded turn")
	_check(int(battle.get_unit("fray_scavenger")["hp"]) == hp_after_hit - 2,
		"AC2: Bleed 2 really deals two HP on the foe's turn")
	_check(not battle.get_unit("fray_scavenger")["statuses"].has("bleed")
		or int(battle.get_unit("fray_scavenger")["statuses"]["bleed"]) == 1,
		"AC2: the Bleed counter ticks down by one unit turn")


## Tether Loop Tangles exactly one enemy for one of its turns.
func _tether_loop_witness() -> void:
	var witness := _first_hit("seamstress_tether_loop_spools", 1)
	_check(not witness.is_empty(), "AC2: a fixed seed lands Tether Loop on the rank-1 foe")
	if witness.is_empty():
		return
	var battle: StitchedRules = witness["battle"]
	var receipt: Dictionary = witness["receipt"]
	var result: Dictionary = receipt["results"][0]
	_check(str(receipt.get("part", "")) == "seamstress_tether_loop_spools",
		"AC2: the receipt names the equipped Tether Loop part")
	_check(str(result["target"]) == "fray_scavenger" and str(result["target_side"]) == "foe",
		"AC2: Tether Loop picks exactly one enemy in the chosen rank")
	_check(int(battle.get_unit("fray_scavenger")["statuses"].get("tangled", 0)) == 1,
		"AC2: a landed Tether Loop leaves a real Tangled 1 on the foe")
	_check(_has_status(result.get("statuses", []), "tangled"), "AC2: the receipt reports the applied Tangled status")
	_check(int(battle.get_unit("fray_scavenger")["hp"]) == int(battle.get_unit("fray_scavenger")["max_hp"]),
		"AC2: Tether Loop itself deals no damage")
	_check(_to(battle, "fray_scavenger"), "AC2: the Tangled foe reaches its own seeded turn")
	_check(not battle.get_unit("fray_scavenger")["statuses"].has("tangled"),
		"AC2: Tangled 1 expires at the start of that one foe turn, not on a later hero")


## Mending Knot heals one living ally; Shielding Hem heals and Guards one living ally.
func _heal_witness(shielding: bool) -> void:
	var wounded := _wounded_ally()
	_check(not wounded.is_empty(),
		"AC2: a fixed seed lets the rank-1 foe wound the Warden for the %s witness"
			% ("Shielding Hem" if shielding else "Mending Knot"))
	if wounded.is_empty():
		return
	var battle: StitchedRules = wounded["battle"]
	var part_id := "seamstress_shielding_hem_coat" if shielding else "seamstress_mending_knot_hat"
	var expected_heal := 2 if shielding else 4
	var before := int(battle.get_unit("warden")["hp"])
	var receipt := battle.use_part(part_id, 1)
	_check(bool(receipt.get("ok", false)), "AC2: %s casts on a living ally" % part_id)
	if not bool(receipt.get("ok", false)) or receipt.get("results", []).is_empty():
		return
	var result: Dictionary = receipt["results"][0]
	_check(str(result["target"]) == "warden" and str(result["target_side"]) == "hero",
		"AC2: %s heals the chosen living hero, never a foe at the same rank" % part_id)
	_check(_status_amount(result.get("statuses", []), "heal") == expected_heal,
		"AC2: %s heals exactly %d" % [part_id, expected_heal])
	_check(int(battle.get_unit("warden")["hp"]) == before + expected_heal,
		"AC2: the Warden's real HP rises by the healed amount")
	if not shielding:
		_check(not battle.get_unit("seamstress")["statuses"].has("guard"),
			"AC2: Mending Knot never guards; it is a pure heal")
		return
	var entry := _status_entry(result.get("statuses", []), "guard")
	_check(not entry.is_empty() and int(entry.get("duration", 0)) == 2,
		"AC2: Shielding Hem applies Guard 2 through the receipt")
	_check(str(entry.get("guards", "")) == "warden", "AC2: the Guard names the healed living ally")
	var actor := battle.get_unit("seamstress")
	_check(str(actor["guard_target"]) == "warden" and int(actor["statuses"].get("guard", 0)) == 2,
		"AC2: the real guard status and target live on the Seamstress")
	_check(_to(battle, "fray_scavenger"), "AC2: a foe reaches a real turn while the Guard stands")
	var guarded := battle.use_foe_ability("sack_swing", 1)
	if bool(guarded.get("ok", false)) and not guarded["results"].is_empty():
		var hit: Dictionary = guarded["results"][0]
		_check(str(hit.get("guarded_by", "")) == "seamstress",
			"AC2: the aimed hit at the guarded Warden is redirected to the Seamstress")
		_check(str(hit.get("target", "")) == "seamstress",
			"AC2: the redirected hit really resolves against the Seamstress")
	else:
		_check(false, "AC2: the guarded ally's foe attack could not be attempted")


func _first_hit(part_id: String, target_rank: int) -> Dictionary:
	for seed_value in range(1, 90):
		var battle := _build_battle(seed_value, 1, STARTER_PARTS, false)
		if battle == null:
			return {}
		if not _to(battle, "seamstress"):
			continue
		var receipt := battle.use_part(part_id, target_rank)
		if not bool(receipt.get("ok", false)) or receipt.get("results", []).is_empty():
			continue
		if not bool(receipt["results"][0].get("hit", false)):
			continue
		return {"battle": battle, "receipt": receipt, "seed": seed_value}
	return {}


## The Seamstress passes her opening turn, a real foe hit wounds the Warden, and play returns to
## her next turn. Only the shipped fixture plus the eight authored parts are used.
func _wounded_ally() -> Dictionary:
	for seed_value in range(1, 90):
		var battle := _build_battle(seed_value, 1, STARTER_PARTS, false)
		if battle == null:
			return {}
		if not _to(battle, "seamstress"):
			continue
		if not bool(battle.pass_turn().get("ok", false)):
			continue
		if not _to(battle, "fray_scavenger"):
			continue
		var attack := battle.use_foe_ability("sack_swing", 1)
		if not bool(attack.get("ok", false)) or attack.get("results", []).is_empty():
			continue
		if not bool(attack["results"][0].get("hit", false)):
			continue
		if not _to(battle, "seamstress"):
			continue
		var warden := battle.get_unit("warden")
		if int(warden["hp"]) <= 0 or int(warden["hp"]) >= int(warden["max_hp"]):
			continue
		return {"battle": battle, "seed": seed_value}
	return {}


# ---------------------------------------------------------------- AC2: refusals are atomic

func _test_live_rejections() -> void:
	var battle := _build_battle(17)
	if battle == null:
		return
	_check(battle.current_actor_id() == "seamstress" and int(battle.get_unit("seamstress")["rank"]) == 2,
		"AC2: the seeded schedule gives the rank-2 Seamstress the first turn")
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	_check(not bool(battle.use_part("seamstress_thread_prick_needle", 4).get("ok", false)),
		"AC2: an enemy-targeting part refuses a rank with no foe")
	_check(not bool(battle.use_part("seamstress_thread_prick_needle", 0).get("ok", false)),
		"AC2: rank 0 is not a legal target rank")
	_check(not bool(battle.use_part("seamstress_thread_prick_needle", 5).get("ok", false)),
		"AC2: rank 5 is not a legal target rank")
	_check(not bool(battle.use_part("seamstress_mending_knot_hat", 9).get("ok", false)),
		"AC2: an ally-targeting part also refuses an out-of-range rank")
	# Rank 4 holds a living ally, so an enemy-side part must not reach across the side boundary.
	var wrong_side := battle.use_part("seamstress_tether_loop_spools", 4)
	_check(not bool(wrong_side.get("ok", false)),
		"AC2: Tether Loop cannot target the living ally standing in rank 4")
	_check(not bool(battle.use_part("seamstress_scarlet_knot_hat", 1).get("ok", false)),
		"AC2: an alternative part that is not equipped grants no battle action")
	_check(not bool(battle.use_part("not_a_part", 1).get("ok", false)),
		"AC2: an unknown part id is refused")
	_check(before == battle.state_snapshot() and rng == battle.rng_state(),
		"AC2: every refused action preserved the complete state, turn pointer and RNG")
	# Ally-side and enemy-side targeting stay distinct on the same rank.
	var ally_cast := battle.use_part("seamstress_mending_knot_hat", 1)
	_check(bool(ally_cast.get("ok", false)) and not ally_cast.get("results", []).is_empty()
		and str(ally_cast["results"][0]["target"]) == "warden"
		and str(ally_cast["results"][0]["target_side"]) == "hero",
		"AC2: Mending Knot targets the rank-1 ally, not the foe sharing that rank")
	if _to(battle, "seamstress"):
		var enemy_cast := battle.use_part("seamstress_thread_prick_needle", 1)
		_check(bool(enemy_cast.get("ok", false)) and not enemy_cast.get("results", []).is_empty()
			and str(enemy_cast["results"][0]["target"]) == "fray_scavenger"
			and str(enemy_cast["results"][0]["target_side"]) == "foe",
			"AC2: Thread Prick targets the rank-1 foe, not the ally sharing that rank")
	else:
		_check(false, "AC2: the Seamstress reaches a second real turn for the enemy-side cast")
	# Launch ranks: after a real Move into rank 1, Tether Loop (ranks 2-3) refuses before any roll.
	var moved := _build_battle(23)
	if moved != null:
		_check(_to(moved, "seamstress"), "AC2: the moved Seamstress opens the round")
		var step := moved.move(-1)
		_check(bool(step.get("ok", false)) and int(moved.get_unit("seamstress")["rank"]) == 1,
			"AC2: a real Move swaps the Seamstress into rank 1")
		if _to(moved, "seamstress"):
			var moved_state := moved.state_snapshot()
			var moved_rng := moved.rng_state()
			var refused := moved.use_part("seamstress_tether_loop_spools", 1)
			_check(not bool(refused.get("ok", false))
				and str(refused.get("error", "")).contains("cannot launch from rank 1"),
				"AC2: Tether Loop refuses to launch from rank 1")
			_check(moved_state == moved.state_snapshot() and moved_rng == moved.rng_state(),
				"AC2: the illegal launch preserved the complete state and RNG")
		else:
			_check(false, "AC2: the moved Seamstress reaches her next real turn")
	# A stale turn: the wearer cannot act during a foe turn.
	var stale := _build_battle(29)
	if stale != null:
		_check(_to_side(stale, "foe"), "AC2: a real foe turn follows the opening Seamstress turn")
		var stale_state := stale.state_snapshot()
		var stale_rng := stale.rng_state()
		var refused := stale.use_part("seamstress_thread_prick_needle", 1)
		_check(not bool(refused.get("ok", false))
			and str(refused.get("error", "")).contains("not a hero turn"),
			"AC2: an action attempted on a stale turn is refused")
		_check(stale_state == stale.state_snapshot() and stale_rng == stale.rng_state(),
			"AC2: the stale-turn refusal preserved the complete state and RNG")


# ---------------------------------------------------------------- AC2: Needle Rain showers 1-4

## One real turn of the alternative Needle Rain arms part showers each living foe in enemy ranks
## 1-4 exactly once. The detached fixture moves the existing third preview foe into enemy rank 4
## (rank 3 left vacant), so the rank-four reach is exercised by a real foe and never an invented
## fourth. The witness needs a seed where all three seeded attacks land, so every struck foe can
## be checked for its own damage and tier Bleed.
func _test_needle_rain_multi() -> void:
	for tier in [1, 2, 3]:
		var witness := _needle_witness(tier)
		var label := "Needle Rain tier %d" % tier
		_check(not witness.is_empty(), "AC2: a fixed seed lands all three " + label + " needles")
		if witness.is_empty():
			continue
		var battle: StitchedRules = witness["battle"]
		var receipt: Dictionary = witness["receipt"]
		var results: Array = receipt["results"]
		var ranks: Dictionary = witness["ranks"]
		_check(str(receipt.get("action", "")) == "ability"
			and str(receipt.get("actor", "")) == "seamstress"
			and str(receipt.get("part", "")) == "seamstress_needle_rain_needle"
			and str(receipt.get("ability", "")) == "needle_rain",
			"AC2: " + label + " resolves as the Seamstress's equipped needle_rain action")
		_check(results.size() == 3,
			"AC2: " + label + " yields exactly three foe results in one receipt")
		# The relocation really happened, and it stayed three foes: no fourth enemy was authored.
		_check(battle.get_foes().size() == 3,
			"AC2: " + label + " never invents a fourth foe for the rear rank")
		_check(int(battle.get_unit("moth_scribe")["rank"]) == MAX_RANK,
			"AC2: " + label + " moves the existing moth_scribe into enemy rank 4")
		_check(_no_foe_at(battle, 3),
			"AC2: " + label + " leaves enemy rank 3 vacant, as the detached fixture intends")
		var seen: Dictionary = {}
		var seen_ranks: Dictionary = {}
		for result in results:
			seen[str(result["target"])] = true
			seen_ranks[int(result["target_rank"])] = true
			_check(str(result["target_side"]) == "foe"
				and int(result["target_rank"]) == int(ranks.get(str(result["target"]), -1)),
				"AC2: " + label + " hits its own foe at its detached rank")
		_check(seen.size() == 3 and seen.has("fray_scavenger")
			and seen.has("scissor_crab") and seen.has("moth_scribe"),
			"AC2: " + label + " receipts each of the three living foes exactly once")
		_check(not seen_ranks.has(3),
			"AC2: " + label + " never receipts a target in the vacant enemy rank 3")
		_check(seen_ranks.has(1) and seen_ranks.has(2) and seen_ranks.has(4),
			"AC2: " + label + " resolves enemy ranks 1, 2 and the rank-4 foe")
		# Tier numbers: the authored damage band plus the arms stat, up to a critical maximum.
		var part: Dictionary = _catalog()["by_id"]["seamstress_needle_rain_needle"]
		var ability := StitchedParts.ability_at_tier(part, tier)
		var bonus := int(StitchedParts.stat_at_tier(part, tier).get("dmg", 0))
		var low := int(ability["dmg"][0]) + bonus
		var high := StitchedRules.crit_damage(int(ability["dmg"][1])) + bonus
		var bleed := int(ability["effects"].get("bleed", 0))
		for result in results:
			var hit: Dictionary = result
			var foe := battle.get_unit(str(hit["target"]))
			var damage := int(hit["damage"])
			_check(bool(hit.get("hit", false)), "AC2: " + label + " really lands on " + str(hit["target"]))
			_check(damage >= low and damage <= high,
				"AC2: " + label + " deals its %d-%d band to %s" % [low, high, str(hit["target"])])
			_check(int(hit["target_hp"]) == int(foe["max_hp"]) - damage,
				"AC2: " + label + " drops " + str(hit["target"]) + " by exactly its dealt damage")
			_check(_status_duration(hit.get("statuses", []), "bleed") == bleed,
				"AC2: " + label + " reports its own Bleed %d on %s" % [bleed, str(hit["target"])])
			_check(int(foe["statuses"].get("bleed", 0)) == bleed,
				"AC2: " + label + " leaves a real Bleed %d on %s" % [bleed, str(hit["target"])])
		# The rank-4 foe is wounded exactly like the front foes, and the allied rank 4 is untouched.
		var rear_foe := battle.get_unit("moth_scribe")
		_check(int(rear_foe["rank"]) == MAX_RANK and int(rear_foe["hp"]) < int(rear_foe["max_hp"]),
			"AC2: " + label + " really wounds the living foe standing in enemy rank 4")
		var ally_after := battle.get_unit("lantern_monk")
		var ally_before: Dictionary = witness["ally_before"]
		_check(not ally_before.is_empty() and int(ally_before["rank"]) == MAX_RANK
			and ally_after == ally_before,
			"AC2: " + label + " never strikes the allied lantern_monk sharing hero rank 4")
		# One action, one spent hero turn.
		_check(battle.current_actor_id() != "seamstress",
			"AC2: " + label + " consumes exactly one Seamstress turn")
		# Same seed, same receipt, state and RNG position.
		var replay := _needle_witness(tier)
		_check(not replay.is_empty()
			and replay["receipt"] == receipt
			and replay["battle"].state_snapshot() == battle.state_snapshot()
			and replay["battle"].rng_state() == battle.rng_state(),
			"AC3: the same seed replays the identical " + label + " receipt, state and RNG")
	# A miss never applies Bleed, while the other needles of the same shower still resolve. This
	# mixed witness keeps the shipped three-foe layout in ranks 1-3.
	var missed := _needle_miss_witness()
	_check(not missed.is_empty(), "AC2: a fixed seed misses at least one Needle Rain needle")
	if not missed.is_empty():
		var miss_battle: StitchedRules = missed["battle"]
		var miss: Dictionary = missed["missed"]
		for foe_id in NEEDLE_FOE_RANKS:
			_check(int(miss_battle.get_unit(str(foe_id))["rank"]) == int(NEEDLE_FOE_RANKS[foe_id]),
				"AC2: the mixed-hit fixture keeps the shipped rank of " + str(foe_id))
		_check(not bool(miss.get("hit", false)) and int(miss.get("damage", -1)) == 0,
			"AC2: a missed needle deals no damage")
		_check(not _has_status(miss.get("statuses", []), "bleed"),
			"AC2: a missed needle reports no Bleed status")
		var missed_foe := miss_battle.get_unit(str(miss["target"]))
		_check(not missed_foe["statuses"].has("bleed"),
			"AC2: a missed needle leaves no Bleed on its target")
		_check(int(missed_foe["hp"]) == int(missed_foe["max_hp"]),
			"AC2: a missed needle leaves the foe's HP untouched")
		var mixed: Array = missed["receipt"]["results"]
		var landed := 0
		for result in mixed:
			if bool(result.get("hit", false)):
				landed += 1
				_check(_status_duration(result.get("statuses", []), "bleed") == 3,
					"AC2: each landed needle of a mixed shower still Bleeds 3")
		_check(mixed.size() == 3 and landed >= 1 and landed <= 2,
			"AC2: a mixed shower still resolves all three foes with at least one hit and one miss")


# ---------------------------------------------------------------- AC2: Mark bonus on struck foes

## One real tier-II Needle Rain cast in two equal-seed battles: the clean copy leaves Moth Scribe
## unmarked, while a detached in-memory copy gives the same living Moth Scribe an existing Mark 2
## just before the cast. Every seeded hit and crit decision is shared, so only the mark bonus may
## differ: the marked rank-3 Moth Scribe loses exactly three more HP, the two unmarked foes take
## identical damage, every landed foe still gains Bleed 4 and the pre-existing Mark is untouched.
func _test_needle_rain_mark_bonus() -> void:
	var witness := _needle_mark_witness()
	_check(not witness.is_empty(),
		"AC2: a bounded seed gives a paired tier-II Needle Rain where all three needles land")
	if witness.is_empty():
		return
	var clean: StitchedRules = witness["clean"]
	var marked: StitchedRules = witness["marked"]
	var clean_receipt: Dictionary = witness["clean_receipt"]
	var marked_receipt: Dictionary = witness["marked_receipt"]
	var clean_foe_before: Dictionary = witness["clean_foe_before"]
	var marked_foe_before: Dictionary = witness["marked_foe_before"]
	_check(bool(clean_receipt.get("ok", false)) and bool(marked_receipt.get("ok", false)),
		"AC2: both paired casts resolve as real use_part actions")
	_check(str(clean_receipt.get("part", "")) == "seamstress_needle_rain_needle"
		and str(marked_receipt.get("part", "")) == "seamstress_needle_rain_needle"
		and str(clean_receipt.get("ability", "")) == "needle_rain"
		and str(marked_receipt.get("ability", "")) == "needle_rain",
		"AC2: both receipts name the equipped tier-II needle_rain action")
	# Real preconditions: three shipped foes, Moth Scribe alive at rank 3 with PROT 0.
	_check(clean.get_foes().size() == 3 and marked.get_foes().size() == 3,
		"AC2: the paired battles keep exactly the three shipped foes")
	for foe_id in NEEDLE_FOE_RANKS:
		_check(int(clean.get_unit(str(foe_id))["rank"]) == int(NEEDLE_FOE_RANKS[foe_id]),
			"AC2: the clean battle keeps the shipped rank of " + str(foe_id))
		_check(int(marked.get_unit(str(foe_id))["rank"]) == int(NEEDLE_FOE_RANKS[foe_id]),
			"AC2: the marked battle keeps the shipped rank of " + str(foe_id))
	var moth := clean.get_unit("moth_scribe")
	_check(int(moth["rank"]) == 3 and int(moth["hp"]) > 0 and int(moth["prot"]) == 0
		and int(moth["max_hp"]) == 19 and int(moth["dodge"]) == 12,
		"AC2: Moth Scribe is alive at enemy rank 3 with 19 HP, 12 DODGE and PROT 0")
	# The only deliberate difference is the already-present Mark 2 on the marked copy.
	_check(not clean_foe_before["statuses"].has("mark"),
		"AC2: the clean Moth Scribe starts with no Mark")
	_check(int(marked_foe_before["statuses"].get("mark", 0)) == 2,
		"AC2: the paired copy gives Moth Scribe an existing Mark 2 before the cast")
	_check(int(clean_foe_before["hp"]) == int(marked_foe_before["hp"]),
		"AC2: both Moth Scribes start the cast at the same HP")
	var results := _results_by_target(marked_receipt, clean_receipt)
	_check(not results.is_empty(),
		"AC2: both receipts resolve the same three targets exactly once")
	if results.is_empty():
		return
	_check(marked_receipt["results"].size() == 3 and clean_receipt["results"].size() == 3,
		"AC2: each cast yields exactly one result per living foe")
	for target in results:
		var hits: Dictionary = results[target]
		var clean_hit: Dictionary = hits["clean"]
		var marked_hit: Dictionary = hits["marked"]
		_check(bool(clean_hit.get("hit", false)) and bool(marked_hit.get("hit", false)),
			"AC2: " + str(target) + " is struck in both paired casts")
		_check(bool(clean_hit.get("crit", false)) == bool(marked_hit.get("crit", false)),
			"AC2: " + str(target) + " shares the same crit decision in both casts")
		if str(target) == "moth_scribe":
			_check(int(marked_hit["damage"]) == int(clean_hit["damage"]) + 3,
				"AC2: the already-Marked Moth Scribe takes exactly three more damage")
			_check(int(marked_hit["target_hp"]) == int(clean_hit["target_hp"]) - 3
				and int(marked.get_unit("moth_scribe")["hp"])
					== int(clean.get_unit("moth_scribe")["hp"]) - 3,
				"AC2: the already-Marked Moth Scribe loses exactly three more real HP")
		else:
			_check(int(marked_hit["damage"]) == int(clean_hit["damage"])
				and int(marked.get_unit(str(target))["hp"]) == int(clean.get_unit(str(target))["hp"]),
				"AC2: the unmarked " + str(target) + " takes identical damage in both casts")
		_check(_status_duration(clean_hit.get("statuses", []), "bleed") == 4
			and _status_duration(marked_hit.get("statuses", []), "bleed") == 4,
			"AC2: " + str(target) + " reports Bleed 4 in both casts")
		_check(int(clean.get_unit(str(target))["statuses"].get("bleed", 0)) == 4
			and int(marked.get_unit(str(target))["statuses"].get("bleed", 0)) == 4,
			"AC2: " + str(target) + " really carries Bleed 4 in both casts")
	# Mark is never consumed by the shower and never applied by it.
	_check(int(marked.get_unit("moth_scribe")["statuses"].get("mark", 0)) == 2,
		"AC2: the pre-existing Mark 2 survives the shower unchanged")
	_check(not clean.get_unit("moth_scribe")["statuses"].has("mark"),
		"AC2: Needle Rain never adds Mark to the clean Moth Scribe")
	for foe_id in ["fray_scavenger", "scissor_crab"]:
		_check(not clean.get_unit(str(foe_id))["statuses"].has("mark")
			and not marked.get_unit(str(foe_id))["statuses"].has("mark"),
			"AC2: Needle Rain never adds Mark to an unmarked " + str(foe_id))
	# One action, one Seamstress turn, the same next actor in both copies.
	_check(clean.current_actor_id() == marked.current_actor_id()
		and clean.current_actor_id() != "seamstress",
		"AC2: one shower spends only the Seamstress turn in both copies")
	_check(int(clean.state_snapshot()["turn_index"]) == int(witness["turn_before"]) + 1
		and int(marked.state_snapshot()["turn_index"]) == int(witness["turn_before"]) + 1,
		"AC2: each cast advances the shared turn pointer by exactly one")
	# Full determinism: the same seed reproduces both casts, receipts, state and RNG.
	var replay := _needle_mark_at(int(witness["seed"]))
	_check(not replay.is_empty()
		and replay["clean_receipt"] == clean_receipt
		and replay["marked_receipt"] == marked_receipt
		and replay["clean"].state_snapshot() == clean.state_snapshot()
		and replay["marked"].state_snapshot() == marked.state_snapshot()
		and replay["clean"].rng_state() == clean.rng_state()
		and replay["marked"].rng_state() == marked.rng_state(),
		"AC4: the same seed replays both paired receipts, state and RNG exactly")


## Searches a fixed small seed range for the paired tier-II witness.
func _needle_mark_witness() -> Dictionary:
	for seed_value in range(1, 200):
		var pair := _needle_mark_at(seed_value)
		if pair.is_empty():
			continue
		var clean_receipt: Dictionary = pair["clean_receipt"]
		var marked_receipt: Dictionary = pair["marked_receipt"]
		if not bool(clean_receipt.get("ok", false)) or not bool(marked_receipt.get("ok", false)):
			continue
		if clean_receipt.get("results", []).size() != 3 \
				or marked_receipt.get("results", []).size() != 3:
			continue
		var results := _results_by_target(marked_receipt, clean_receipt)
		if results.size() != 3:
			continue
		var matched := true
		for target in results:
			var hits: Dictionary = results[target]
			var clean_hit: Dictionary = hits["clean"]
			var marked_hit: Dictionary = hits["marked"]
			if not bool(clean_hit.get("hit", false)) or not bool(marked_hit.get("hit", false)):
				matched = false
				break
			if bool(clean_hit.get("crit", false)) != bool(marked_hit.get("crit", false)):
				matched = false
				break
			if str(target) == "moth_scribe":
				if int(marked_hit["damage"]) != int(clean_hit["damage"]) + 3:
					matched = false
					break
			elif int(marked_hit["damage"]) != int(clean_hit["damage"]):
				matched = false
				break
			if _status_duration(clean_hit.get("statuses", []), "bleed") != 4 \
					or _status_duration(marked_hit.get("statuses", []), "bleed") != 4:
				matched = false
				break
		if not matched:
			continue
		var clean: StitchedRules = pair["clean"]
		var marked: StitchedRules = pair["marked"]
		if not _shower_unticked(clean, clean_receipt["results"]):
			continue
		if not _shower_unticked(marked, marked_receipt["results"]):
			continue
		if int(marked.get_unit("moth_scribe")["statuses"].get("mark", 0)) != 2:
			continue
		if clean.get_unit("moth_scribe")["statuses"].has("mark"):
			continue
		return {
			"seed": seed_value,
			"clean": clean,
			"marked": marked,
			"clean_receipt": clean_receipt,
			"marked_receipt": marked_receipt,
			"clean_foe_before": pair["clean_foe_before"],
			"marked_foe_before": pair["marked_foe_before"],
			"turn_before": pair["turn_before"],
		}
	return {}


## Builds two equal-seed tier-II Needle Rain battles, differs only by an in-memory existing Mark 2
## on the shipped rank-3 Moth Scribe, and casts one real shower in each.
func _needle_mark_at(seed_value: int) -> Dictionary:
	var clean := _build_battle(seed_value, 2, NEEDLE_KIT, false)
	var marked := _build_battle(seed_value, 2, NEEDLE_KIT, false)
	if clean == null or marked == null:
		return {}
	# Same seed, same equipment, same foe ranks/HP and the same actor/RNG position before the cast.
	if clean.state_snapshot() != marked.state_snapshot():
		return {}
	if not _to(clean, "seamstress") or not _to(marked, "seamstress"):
		return {}
	if clean.state_snapshot() != marked.state_snapshot():
		return {}
	if int(clean.get_unit("moth_scribe")["rank"]) != 3:
		return {}
	var clean_foe_before := clean.get_unit("moth_scribe")
	# The one deliberate difference: an existing Mark 2 in this battle's own memory only.
	marked._units["moth_scribe"]["statuses"]["mark"] = 2
	var marked_foe_before := marked.get_unit("moth_scribe")
	var turn_before := int(clean.state_snapshot()["turn_index"])
	var clean_receipt := clean.use_part("seamstress_needle_rain_needle", 1)
	var marked_receipt := marked.use_part("seamstress_needle_rain_needle", 1)
	return {
		"clean": clean,
		"marked": marked,
		"clean_receipt": clean_receipt,
		"marked_receipt": marked_receipt,
		"clean_foe_before": clean_foe_before,
		"marked_foe_before": marked_foe_before,
		"turn_before": turn_before,
	}


## Indexes two three-foe receipts by target id, keeping each copy's own result.
func _results_by_target(marked_receipt: Dictionary, clean_receipt: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for result in clean_receipt.get("results", []):
		out[str(result["target"])] = {"clean": result}
	for result in marked_receipt.get("results", []):
		var target := str(result["target"])
		if not out.has(target):
			return {}
		out[target]["marked"] = result
	for target in out:
		if not out[target].has("marked"):
			return {}
	return out


## A fixed small seed range yields a real shower where all three living foes are hit, with the
## existing third foe relocated into enemy rank 4 in this detached battle's own memory.
func _needle_witness(tier: int) -> Dictionary:
	for seed_value in range(1, 120):
		var battle := _build_battle(seed_value, tier, NEEDLE_KIT, false, true)
		if battle == null:
			continue
		if not _to(battle, "seamstress"):
			continue
		if int(battle.get_unit("seamstress")["rank"]) != 2:
			continue
		var ally_before := battle.get_unit("lantern_monk")
		var receipt := battle.use_part("seamstress_needle_rain_needle", 1)
		if not bool(receipt.get("ok", false)) or receipt.get("results", []).size() != 3:
			continue
		var all_hit := true
		for result in receipt["results"]:
			if not bool(result.get("hit", false)):
				all_hit = false
				break
		if not all_hit:
			continue
		# Seed selection only: the live foe state must still be exactly what the receipt wrote,
		# so no target's own start-of-turn tick has already aged it before the assertions run.
		if not _shower_unticked(battle, receipt["results"]):
			continue
		return {
			"battle": battle,
			"receipt": receipt,
			"seed": seed_value,
			"ranks": NEEDLE_RANK4_FOE_RANKS,
			"ally_before": ally_before,
		}
	return {}


## A fixed small seed range yields a real shower that both lands and misses.
func _needle_miss_witness() -> Dictionary:
	for seed_value in range(1, 120):
		var battle := _build_battle(seed_value, 1, NEEDLE_KIT, false)
		if battle == null:
			continue
		if not _to(battle, "seamstress"):
			continue
		var receipt := battle.use_part("seamstress_needle_rain_needle", 1)
		if not bool(receipt.get("ok", false)) or receipt.get("results", []).size() != 3:
			continue
		var landed := 0
		var missed: Dictionary = {}
		for result in receipt["results"]:
			if bool(result.get("hit", false)):
				landed += 1
			elif missed.is_empty():
				missed = result
		if landed == 0 or missed.is_empty():
			continue
		return {"battle": battle, "receipt": receipt, "missed": missed, "seed": seed_value}
	return {}


## The rear hero rank 4 is a real launch rank: the alternate needle seats its shower there.
## A fixed seed wounds the rank-1 Warden and carries the Seamstress back through two genuine Move
## turns; from hero rank 4 one Needle Rain action showers each living foe in enemy ranks 1-4
## exactly once, per tier, including the same existing foe relocated to enemy rank 4. The allied
## lantern_monk sharing hero rank 4 is never struck.
func _test_needle_rain_rear_launch() -> void:
	for tier in [1, 2, 3]:
		var label := "rank-4 Needle Rain tier %d" % tier
		var witness := _needle_rear_witness(tier)
		_check(not witness.is_empty(), "AC2: a fixed seed lands all three " + label + " needles")
		if witness.is_empty():
			continue
		var battle: StitchedRules = witness["battle"]
		var receipt: Dictionary = witness["receipt"]
		var seat := battle.get_unit("seamstress")
		_check(int(seat["rank"]) == MAX_RANK,
			"AC2: " + label + " is cast by the Seamstress standing in hero rank 4")
		_check(_worn_part_id(seat, "seamstress_needle_rain_needle") == "seamstress_needle_rain_needle",
			"AC2: the rear battle really equips the Needle Rain Needle")
		_check(str(receipt.get("part", "")) == "seamstress_needle_rain_needle"
			and str(receipt.get("ability", "")) == "needle_rain"
			and str(receipt.get("actor", "")) == "seamstress",
			"AC2: " + label + " resolves as the equipped needle_rain action from rank 4")
		var results: Array = receipt["results"]
		_check(results.size() == 3,
			"AC2: " + label + " yields one independent result per living foe")
		var seen: Dictionary = {}
		var ally_before: Dictionary = witness["ally_before"]
		for result in results:
			seen[str(result["target"])] = true
			_check(str(result["target_side"]) == "foe"
				and int(result["target_rank"]) == int(NEEDLE_RANK4_FOE_RANKS.get(str(result["target"]), -1)),
				"AC2: " + label + " hits its own foe at its detached rank")
			_check(int(result["target_rank"]) != MAX_RANK or str(result["target"]) == "moth_scribe",
				"AC2: " + label + " only reaches the rank-4 foe on the enemy side")
			_check(result.has("roll") and bool(result.get("hit", false)),
				"AC2: " + label + " rolls its own hit for " + str(result["target"]))
		_check(seen.size() == 3 and seen.has("fray_scavenger")
			and seen.has("scissor_crab") and seen.has("moth_scribe"),
			"AC2: " + label + " receipts each of the three living foes exactly once")
		_check(_no_foe_at(battle, 3) and int(battle.get_unit("moth_scribe")["rank"]) == MAX_RANK,
			"AC2: " + label + " reaches the rank-4 foe with enemy rank 3 vacant")
		_check(battle.get_foes().size() == 3,
			"AC2: " + label + " still fields exactly the three shipped foes")
		var ally_after := battle.get_unit("lantern_monk")
		_check(not ally_before.is_empty()
			and int(ally_after["hp"]) == int(ally_before["hp"])
			and ally_after["statuses"] == ally_before["statuses"],
			"AC2: " + label + " never strikes the allied lantern_monk with the rank-4 shower")
		var part: Dictionary = _catalog()["by_id"]["seamstress_needle_rain_needle"]
		var ability := StitchedParts.ability_at_tier(part, tier)
		var bonus := int(StitchedParts.stat_at_tier(part, tier).get("dmg", 0))
		var low := int(ability["dmg"][0]) + bonus
		var high := StitchedRules.crit_damage(int(ability["dmg"][1])) + bonus
		var bleed := int(ability["effects"].get("bleed", 0))
		for result in results:
			var hit: Dictionary = result
			var foe := battle.get_unit(str(hit["target"]))
			var damage := int(hit["damage"])
			_check(damage >= low and damage <= high,
				"AC2: " + label + " deals its %d-%d band to %s" % [low, high, str(hit["target"])])
			_check(int(hit["target_hp"]) == int(foe["max_hp"]) - damage,
				"AC2: " + label + " drops " + str(hit["target"]) + " by exactly its dealt damage")
			_check(_status_duration(hit.get("statuses", []), "bleed") == bleed,
				"AC2: " + label + " reports its own Bleed %d on %s" % [bleed, str(hit["target"])])
			_check(int(foe["statuses"].get("bleed", 0)) == bleed,
				"AC2: " + label + " leaves a real Bleed %d on %s" % [bleed, str(hit["target"])])
		_check(battle.current_actor_id() != "seamstress",
			"AC2: " + label + " consumes exactly one Seamstress turn")
		var replay_battle := _rear_needle_at(int(witness["seed"]), tier)
		_check(replay_battle != null, "AC3: the " + label + " seed replays the same rear setup")
		if replay_battle != null:
			var replay := replay_battle.use_part("seamstress_needle_rain_needle", 1)
			_check(replay == receipt
				and replay_battle.state_snapshot() == battle.state_snapshot()
				and replay_battle.rng_state() == battle.rng_state(),
				"AC3: the same seed replays the identical " + label + " receipt, state and RNG")
	# Both reach masks cover ranks 1-4 now, so the shower can be launched from and aimed at the
	# rear rank; ranks 0 and 5 stay outside the authored masks.
	var mask_part: Dictionary = _catalog()["by_id"]["seamstress_needle_rain_needle"]
	for mask_tier in [1, 2, 3]:
		var mask_ability := StitchedParts.ability_at_tier(mask_part, mask_tier)
		var launch_mask := int(mask_ability["launch_mask"])
		var target_mask := int(mask_ability["target_mask"])
		for rank in [1, 2, 3, 4]:
			_check(StitchedParts.ranks_allowed(launch_mask, rank),
				"AC1: Needle Rain tier %d launches from hero rank %d" % [mask_tier, rank])
			_check(StitchedParts.ranks_allowed(target_mask, rank),
				"AC1: Needle Rain tier %d targets enemy rank %d" % [mask_tier, rank])
		_check(target_mask == StitchedParts.rank_mask([1, 2, 3, 4]),
			"AC1: Needle Rain tier %d covers the enemy target mask ranks 1-4" % mask_tier)
		for rank in [0, 5]:
			_check(not StitchedParts.ranks_allowed(target_mask, rank),
				"AC1: Needle Rain tier %d never targets rank %d" % [mask_tier, rank])
	# Anchoring enemy rank 4 itself on the relocated fixture really receipts the rank-4 foe.
	var anchored := _build_battle(37, 1, NEEDLE_KIT, false, true)
	_check(anchored != null, "AC1: the relocated fixture builds for the rank-4 anchor witness")
	if anchored != null:
		_check(_to(anchored, "seamstress"),
			"AC1: the Seamstress reaches a real turn on the relocated fixture")
		var anchored_cast := anchored.use_part("seamstress_needle_rain_needle", 4)
		var anchored_results: Array = anchored_cast.get("results", [])
		var anchored_ranks: Dictionary = {}
		var anchored_rear_hit := false
		for result in anchored_results:
			anchored_ranks[int(result["target_rank"])] = true
			if str(result["target"]) == "moth_scribe" and int(result["target_rank"]) == MAX_RANK:
				anchored_rear_hit = true
		_check(bool(anchored_cast.get("ok", false)) and anchored_results.size() == 3
			and anchored_ranks.has(1) and anchored_ranks.has(2) and anchored_ranks.has(4)
			and not anchored_ranks.has(3),
			"AC1: anchoring enemy rank 4 showers the living foes in ranks 1, 2 and 4 only")
		_check(anchored_rear_hit,
			"AC1: anchoring enemy rank 4 really receipts the existing rank-4 foe")
	# A rear-rank shower can still miss: the missed needle deals nothing and leaves no Bleed,
	# while the other needles of the same action still land from hero rank 4.
	var mixed := _needle_rear_miss_witness()
	_check(not mixed.is_empty(), "AC2: a fixed seed misses at least one needle from hero rank 4")
	if not mixed.is_empty():
		var mixed_battle: StitchedRules = mixed["battle"]
		var mixed_receipt: Dictionary = mixed["receipt"]
		var missed: Dictionary = mixed["missed"]
		_check(not bool(missed.get("hit", false)) and int(missed.get("damage", -1)) == 0,
			"AC2: a rank-4 needle miss deals no damage")
		_check(not _has_status(missed.get("statuses", []), "bleed"),
			"AC2: a rank-4 needle miss reports no Bleed status")
		var missed_foe := mixed_battle.get_unit(str(missed["target"]))
		_check(not missed_foe["statuses"].has("bleed")
			and int(missed_foe["hp"]) == int(missed_foe["max_hp"]),
			"AC2: a rank-4 needle miss leaves its foe at full HP with no Bleed")
		var landed := 0
		var mixed_ranks: Dictionary = {}
		for result in mixed_receipt["results"]:
			mixed_ranks[int(result["target_rank"])] = true
			_check(str(result["target_side"]) == "foe",
				"AC2: the rank-4 mixed shower only resolves foes")
			if bool(result.get("hit", false)):
				landed += 1
				_check(_status_duration(result.get("statuses", []), "bleed") == 3,
					"AC2: each landed needle of the rank-4 mixed shower still Bleeds 3")
		_check(mixed_receipt["results"].size() == 3 and landed >= 1 and landed <= 2,
			"AC2: a rank-4 mixed shower resolves all three foes with at least one hit and one miss")
		_check(mixed_ranks.has(1) and mixed_ranks.has(2) and mixed_ranks.has(4)
			and not mixed_ranks.has(3),
			"AC2: a rank-4 mixed shower covers enemy ranks 1, 2 and 4 and never the vacant rank 3")


## A fixed seed range yields a real rear-rank shower that both lands and misses.
func _needle_rear_miss_witness() -> Dictionary:
	for seed_value in range(1, 150):
		var battle := _rear_needle_at(seed_value, 1)
		if battle == null:
			continue
		var receipt := battle.use_part("seamstress_needle_rain_needle", 1)
		if not bool(receipt.get("ok", false)) or receipt.get("results", []).size() != 3:
			continue
		var landed := 0
		var missed: Dictionary = {}
		for result in receipt["results"]:
			if bool(result.get("hit", false)):
				landed += 1
			elif missed.is_empty():
				missed = result
		if landed == 0 or missed.is_empty():
			continue
		return {"battle": battle, "receipt": receipt, "missed": missed, "seed": seed_value}
	return {}


## Searches a fixed seed range for a rear-rank shower where all three needles land, so every
## struck foe can be checked for its own tier damage and Bleed.
func _needle_rear_witness(tier: int) -> Dictionary:
	for seed_value in range(1, 150):
		var battle := _rear_needle_at(seed_value, tier)
		if battle == null:
			continue
		var ally_before := battle.get_unit("lantern_monk")
		var receipt := battle.use_part("seamstress_needle_rain_needle", 1)
		if not bool(receipt.get("ok", false)) or receipt.get("results", []).size() != 3:
			continue
		var all_hit := true
		for result in receipt["results"]:
			if not bool(result.get("hit", false)):
				all_hit = false
				break
		if not all_hit:
			continue
		if not _shower_unticked(battle, receipt["results"]):
			continue
		return {
			"battle": battle,
			"receipt": receipt,
			"seed": seed_value,
			"ally_before": ally_before,
		}
	return {}


## True when every target's live HP and Bleed still match the receipt it just received, i.e. no
## target's own start-of-turn tick has run between the shower and the assertions.
func _shower_unticked(battle: StitchedRules, results: Array) -> bool:
	for result in results:
		var foe: Dictionary = battle.get_unit(str(result["target"]))
		if foe.is_empty() or int(foe["hp"]) != int(result["target_hp"]):
			return false
		var applied := maxi(0, _status_duration(result.get("statuses", []), "bleed"))
		if applied != int(foe["statuses"].get("bleed", 0)):
			return false
	return true


## The same real setup _rear_support_witness uses, for one explicit seed: a foe hit wounds the
## rank-1 Warden, two genuine Move turns carry the Seamstress 2 -> 3 -> 4, and play returns to
## her scheduled turn in the rear rank with the three preview foes still alive and in place. The
## detached fixture has already moved the existing third foe into enemy rank 4 (rank 3 vacant).
func _rear_needle_at(seed_value: int, tier: int) -> StitchedRules:
	var battle := _build_battle(seed_value, tier, NEEDLE_KIT, false, true)
	if battle == null:
		return null
	if not _to(battle, "fray_scavenger"):
		return null
	var attack := battle.use_foe_ability("sack_swing", 1)
	if not bool(attack.get("ok", false)) or attack.get("results", []).is_empty():
		return null
	if not bool(attack["results"][0].get("hit", false)):
		return null
	if str(attack["results"][0].get("target", "")) != "warden":
		return null
	var wounded := battle.get_unit("warden")
	if int(wounded["hp"]) <= 0 or int(wounded["hp"]) >= int(wounded["max_hp"]):
		return null
	if not _to(battle, "seamstress") or int(battle.get_unit("seamstress")["rank"]) != 2:
		return null
	var first := battle.move(1)
	if not bool(first.get("ok", false)) or int(first.get("to", 0)) != 3:
		return null
	if not _to(battle, "seamstress"):
		return null
	var second := battle.move(1)
	if not bool(second.get("ok", false)) or int(second.get("to", 0)) != 4:
		return null
	if not _to(battle, "seamstress"):
		return null
	for foe_id in NEEDLE_RANK4_FOE_RANKS:
		var foe := battle.get_unit(str(foe_id))
		if int(foe["hp"]) <= 0 or bool(foe["dead"]) or int(foe["rank"]) != int(NEEDLE_RANK4_FOE_RANKS[foe_id]):
			return null
	return battle


## Every Needle Rain refusal leaves the battle, the acting turn and the seeded RNG untouched.
func _test_needle_rain_rejections() -> void:
	# The alternative is not equipped in the shipped starter kit, so it grants no action.
	var starter_battle := _build_battle(17)
	if starter_battle != null:
		_check(starter_battle.current_actor_id() == "seamstress",
			"AC3: the rank-2 Seamstress opens the unequipped-needle check")
		var starter_state := starter_battle.state_snapshot()
		var starter_rng := starter_battle.rng_state()
		var unequipped := starter_battle.use_part("seamstress_needle_rain_needle", 1)
		_check(not bool(unequipped.get("ok", false))
			and str(unequipped.get("error", "")).contains("not equipped"),
			"AC3: an unequipped Needle Rain is refused")
		_check(starter_state == starter_battle.state_snapshot()
			and starter_rng == starter_battle.rng_state()
			and starter_battle.current_actor_id() == "seamstress",
			"AC3: the unequipped refusal preserved state, turn and RNG")
	# Equipped: the enemy mask now covers rank 4, so only ranks outside 1-4 are refused.
	var battle := _build_battle(17, 1, NEEDLE_KIT)
	if battle == null:
		return
	_check(battle.current_actor_id() == "seamstress"
		and int(battle.get_unit("lantern_monk")["rank"]) == 4,
		"AC3: the equipped-needle witness starts on the Seamstress's turn with an ally in rank 4")
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var turn := battle.current_actor_id()
	for bad_rank in [0, 5]:
		var refused := battle.use_part("seamstress_needle_rain_needle", bad_rank)
		_check(not bool(refused.get("ok", false))
			and str(refused.get("error", "")).contains("no legal target in rank %d" % bad_rank),
			"AC3: Needle Rain refuses the out-of-bounds target rank %d" % bad_rank)
		_check(before == battle.state_snapshot() and rng == battle.rng_state()
			and turn == battle.current_actor_id(),
			"AC3: the rank-%d refusal preserved snapshot, turn and seeded RNG" % bad_rank)
	# A rank with no enemy is still refused for a single-target enemy part, even though the living
	# ally stands in the same-numbered hero rank 4 and the shower now covers enemy rank 4.
	var vacant := battle.use_part("seamstress_tether_loop_spools", 4)
	_check(not bool(vacant.get("ok", false))
		and str(vacant.get("error", "")).contains("no legal target in rank 4"),
		"AC3: an enemy rank with no foe is refused while an ally stands in hero rank 4")
	_check(before == battle.state_snapshot() and rng == battle.rng_state()
		and turn == battle.current_actor_id(),
		"AC3: the vacant enemy rank refusal preserved snapshot, turn and seeded RNG")
	# The refused calls spent nothing: the same turn still casts the real shower.
	var shower := battle.use_part("seamstress_needle_rain_needle", 1)
	_check(bool(shower.get("ok", false)) and shower.get("results", []).size() == 3,
		"AC3: the untouched turn still casts the real three-foe shower")
	_check(battle.current_actor_id() != "seamstress",
		"AC3: only the accepted shower spent the Seamstress's turn")
	# Enemy rank 4 is now a legal anchor. In the shipped three-foe layout it still showers only
	# the living foes and never the allied lantern_monk standing in hero rank 4.
	var anchor := _build_battle(17, 1, NEEDLE_KIT)
	if anchor == null:
		return
	_check(anchor.current_actor_id() == "seamstress",
		"AC3: the rank-4 anchor witness starts on the Seamstress's real turn")
	var ally_before := anchor.get_unit("lantern_monk")
	var anchored := anchor.use_part("seamstress_needle_rain_needle", 4)
	_check(bool(anchored.get("ok", false)) and anchored.get("results", []).size() == 3,
		"AC3: the legal enemy rank 4 anchors the same three-foe shower")
	var anchored_foes_only := true
	for result in anchored.get("results", []):
		if str(result.get("target_side", "")) != "foe":
			anchored_foes_only = false
	_check(anchored_foes_only,
		"AC3: the rank-4 anchor only resolves results on the enemy side")
	_check(anchor.get_unit("lantern_monk") == ally_before,
		"AC3: the rank-4 anchor leaves the allied hero in rank 4 untouched")
	_check(anchor.current_actor_id() != "seamstress",
		"AC3: the accepted rank-4 anchor spends exactly one Seamstress turn")
	# A stale turn: the wearer cannot act during a foe turn.
	if not _to_side(battle, "foe"):
		_check(false, "AC3: a real foe turn follows the shower")
		return
	var stale_state := battle.state_snapshot()
	var stale_rng := battle.rng_state()
	var stale := battle.use_part("seamstress_needle_rain_needle", 1)
	_check(not bool(stale.get("ok", false))
		and str(stale.get("error", "")).contains("not a hero turn"),
		"AC3: Needle Rain is refused on a stale foe turn")
	_check(stale_state == battle.state_snapshot() and stale_rng == battle.rng_state(),
		"AC3: the stale-turn refusal preserved the complete state and RNG")
	# From the rear hero rank 4 the out-of-bounds ranks stay atomic refusals, and the legal enemy
	# rank 4 anchor reaches only the enemy side, never the ally behind the Seamstress.
	var rear := _rear_support_witness(NEEDLE_KIT)
	_check(not rear.is_empty(), "AC3: a fixed seed carries the needle Seamstress back to rank 4")
	if rear.is_empty():
		return
	var rear_battle: StitchedRules = rear["battle"]
	_check(int(rear_battle.get_unit("seamstress")["rank"]) == 4,
		"AC3: the rear witness really stands in hero rank 4")
	for bad_rank in [0, 5]:
		var rear_state := rear_battle.state_snapshot()
		var rear_rng := rear_battle.rng_state()
		var refused := rear_battle.use_part("seamstress_needle_rain_needle", bad_rank)
		_check(not bool(refused.get("ok", false))
			and str(refused.get("error", "")).contains("no legal target in rank %d" % bad_rank),
			"AC3: Needle Rain refuses the out-of-bounds target rank %d from hero rank 4" % bad_rank)
		_check(rear_state == rear_battle.state_snapshot() and rear_rng == rear_battle.rng_state()
			and rear_battle.current_actor_id() == "seamstress",
			"AC3: the rear rank-%d refusal preserved snapshot, turn and seeded RNG" % bad_rank)
	var rear_ally_before := rear_battle.get_unit("lantern_monk")
	var rear_anchor := rear_battle.use_part("seamstress_needle_rain_needle", 4)
	_check(bool(rear_anchor.get("ok", false))
		and rear_anchor.get("results", []).size() == 3,
		"AC3: enemy rank 4 is a legal target rank from the rear hero rank 4")
	var rear_foes_only := true
	for result in rear_anchor.get("results", []):
		if str(result.get("target_side", "")) != "foe":
			rear_foes_only = false
	_check(rear_foes_only,
		"AC3: the rear rank-4 anchor only resolves results on the enemy side")
	_check(rear_battle.get_unit("lantern_monk") == rear_ally_before,
		"AC3: the rear rank-4 anchor never strikes the allied lantern_monk")


# ---------------------------------------------------------------- AC1/AC2: rear-rank launch masks

## The three edited support records, resolved at tiers I-III, admit the rear hero rank 4 while
## keeping their ally target masks at ranks 1-4. Only the base launch arrays changed.
func _test_rear_launch_masks() -> void:
	var raw: Variant = _read_json(PARTS_PATH)
	var catalog := _catalog()
	_check(bool(catalog.get("ok", false)),
		"AC1: the edited catalog still loads through StitchedParts.load_catalog")
	if not bool(catalog.get("ok", false)) or not raw is Dictionary:
		return
	var document: Dictionary = raw
	var raw_parts: Variant = document.get("parts", [])
	for part_id in REAR_SUPPORT_CASES:
		var part: Dictionary = catalog["by_id"][part_id]
		var spec: Dictionary = EXPECTED[part_id]
		_check(_int_list(part["ability"]["launch"]) == _int_list(spec["launch"]),
			"AC1: the shipped %s base launch array is %s" % [part_id, str(spec["launch"])])
		_check(_int_list(part["ability"]["target"]) == _int_list(spec["target"]),
			"AC1: the shipped " + part_id + " still targets ally ranks 1-4")
		_check(_raw_launch_for(raw_parts, part_id) == _int_list(spec["launch"]),
			"AC1: the authored JSON record of " + part_id + " carries the edited launch array")
		for tier in [1, 2, 3]:
			var ability := StitchedParts.ability_at_tier(part, tier)
			var tag := "%s tier %d" % [part_id, tier]
			var launch_mask := int(ability["launch_mask"])
			# A stitched tier overrides numbers only, never the launch reach.
			_check(_int_list(ability["launch"]) == _int_list(spec["launch"]),
				"AC2: " + tag + " keeps the rear-rank launch array")
			_check(launch_mask == StitchedParts.rank_mask(_int_list(ability["launch"])),
				"AC2: " + tag + " launch mask is derived from its authored ranks")
			_check(StitchedParts.ranks_allowed(launch_mask, MAX_RANK),
				"AC2: " + tag + " validates a launch from the rear hero rank 4")
			var target_mask := int(ability["target_mask"])
			for rank in range(MIN_RANK, MAX_RANK + 1):
				_check(StitchedParts.ranks_allowed(target_mask, rank),
					"AC2: " + tag + " still targets allied rank %d" % rank)
		var base_mask := int(part["ability"]["launch_mask"])
		if part_id == "seamstress_shielding_hem_coat":
			_check(StitchedParts.ranks_allowed(base_mask, 1),
				"AC1: Shielding Hem still launches from rank 1")
		else:
			_check(not StitchedParts.ranks_allowed(base_mask, 1),
				"AC1: " + part_id + " still refuses a rank-1 launch")
	# The one description that named the old reach now names ranks 2-4.
	_check(str(catalog["by_id"]["seamstress_mending_knot_hat"]["text"]).contains("ranks 2-4"),
		"AC1: the Mending Knot description names its new reach from ranks 2-4")
	# The other five parts keep their exact authored launch ranks (Needle Rain only gained rank 4).
	for part_id in ALL_PART_IDS:
		if REAR_SUPPORT_CASES.has(part_id):
			continue
		_check(_int_list(catalog["by_id"][part_id]["ability"]["launch"])
			== _int_list(EXPECTED[part_id]["launch"]),
			"AC1: the other " + part_id + " keeps its authored launch ranks")


func _raw_part_for(raw_parts: Variant, part_id: String) -> Dictionary:
	if not raw_parts is Array:
		return {}
	for entry in raw_parts:
		if entry is Dictionary and str(entry.get("id", "")) == part_id:
			return entry
	return {}


func _raw_launch_for(raw_parts: Variant, part_id: String) -> Array:
	if not raw_parts is Array:
		return []
	for entry in raw_parts:
		if entry is Dictionary and str(entry.get("id", "")) == part_id:
			var ability: Variant = entry.get("ability")
			if ability is Dictionary:
				return _int_list(ability.get("launch"))
			return []
	return []


# ---------------------------------------------------------------- AC2: real rear-rank support

## One fresh seeded battle per support part: a real foe hit wounds the rank-1 Warden, two real
## Moves carry the Seamstress back to rank 4, and her next turn casts the support part on that
## Warden. The shipped preview file is never edited; the wound is prepared in the in-memory copy.
func _test_rear_rank_support() -> void:
	for part_id in REAR_SUPPORT_CASES:
		var kit: Dictionary = POULTICE_KIT if part_id == "seamstress_poultice_apron" else STARTER_PARTS
		var spec: Dictionary = REAR_SUPPORT_CASES[part_id]
		var witness := _rear_support_witness(kit)
		_check(not witness.is_empty(),
			"AC2: a fixed seed gives the %s a real wound and two legal Moves back to rank 4" % part_id)
		if witness.is_empty():
			continue
		var battle: StitchedRules = witness["battle"]
		var seamstress := battle.get_unit("seamstress")
		_check(int(seamstress["rank"]) == MAX_RANK,
			"AC2: " + part_id + " is worn by the Seamstress standing in the rear hero rank 4")
		_check(_worn_part_id(seamstress, part_id) == part_id,
			"AC2: the fresh battle really equips " + part_id)
		var warden_before := battle.get_unit("warden")
		var before_hp := int(warden_before["hp"])
		_check(int(warden_before["rank"]) == 1 and before_hp > 0
			and before_hp < int(warden_before["max_hp"]),
			"AC2: the rank-1 Warden is living and deliberately wounded before the cast")
		_check(battle.current_actor_id() == "seamstress",
			"AC2: the Seamstress reaches her own real turn in rank 4")
		var receipt := battle.use_part(part_id, 1)
		_check(bool(receipt.get("ok", false)),
			"AC2: " + part_id + " casts on the rank-1 ally from rank 4")
		if not bool(receipt.get("ok", false)) or receipt.get("results", []).is_empty():
			continue
		_check(str(receipt.get("part", "")) == part_id,
			"AC2: the receipt names the equipped part " + part_id)
		var result: Dictionary = receipt["results"][0]
		_check(str(result["target"]) == "warden" and str(result["target_side"]) == "hero"
			and int(result["target_rank"]) == 1,
			"AC2: " + part_id + " reaches the wounded Warden in rank 1 on the hero side")
		var expected_heal := int(spec["heal"])
		_check(_status_amount(result.get("statuses", []), "heal") == expected_heal,
			"AC2: %s heals exactly its tier-I %d HP" % [part_id, expected_heal])
		var warden_after := battle.get_unit("warden")
		_check(int(warden_after["hp"])
			== mini(int(warden_after["max_hp"]), before_hp + expected_heal),
			"AC2: the Warden's real HP rises by the healed %d" % expected_heal)
		var guard := int(spec["guard"])
		if guard == 0:
			_check(not _has_status(result.get("statuses", []), "guard")
				and not battle.get_unit("seamstress")["statuses"].has("guard"),
				"AC2: Mending Knot applies no Guard; it stays a pure heal")
			continue
		var entry := _status_entry(result.get("statuses", []), "guard")
		_check(not entry.is_empty() and int(entry.get("duration", 0)) == guard
			and str(entry.get("guards", "")) == "warden",
			"AC2: %s applies Guard %d over the Warden through the receipt" % [part_id, guard])
		var actor := battle.get_unit("seamstress")
		_check(int(actor["statuses"].get("guard", 0)) == guard
			and str(actor["guard_target"]) == "warden",
			"AC2: the real Guard %d status on the Seamstress names the Warden" % guard)


## A real foe hit on the in-memory copy wounds the Warden, then two real Moves carry the
## Seamstress from rank 2 through 3 into 4 on her own turns.
func _rear_support_witness(kit: Dictionary) -> Dictionary:
	for seed_value in range(1, 150):
		var battle := _build_battle(seed_value, 1, kit, false)
		if battle == null:
			return {}
		if not _to(battle, "fray_scavenger"):
			continue
		var attack := battle.use_foe_ability("sack_swing", 1)
		if not bool(attack.get("ok", false)) or attack.get("results", []).is_empty():
			continue
		if not bool(attack["results"][0].get("hit", false)):
			continue
		if str(attack["results"][0].get("target", "")) != "warden":
			continue
		var wounded := battle.get_unit("warden")
		if int(wounded["hp"]) <= 0 or int(wounded["hp"]) >= int(wounded["max_hp"]):
			continue
		if not _to(battle, "seamstress"):
			continue
		if int(battle.get_unit("seamstress")["rank"]) != 2:
			continue
		var first := battle.move(1)
		if not bool(first.get("ok", false)) or int(first.get("to", 0)) != 3:
			continue
		if not _to(battle, "seamstress"):
			continue
		var second := battle.move(1)
		if not bool(second.get("ok", false)) or int(second.get("to", 0)) != 4:
			continue
		if not _to(battle, "seamstress"):
			continue
		return {"battle": battle, "seed": seed_value, "moves": [first, second]}
	return {}


func _worn_part_id(unit: Dictionary, part_id: String) -> String:
	var worn: Dictionary = unit.get("parts", {})
	for slot in worn:
		if str(worn[slot].get("id", "")) == part_id:
			return part_id
	return ""


## After a real Move forward into rank 1, Mending Knot (launch 2-4) fails atomically.
func _test_rear_illegal_forward_launch() -> void:
	var battle := _build_battle(23)
	if battle == null:
		return
	if not _to(battle, "seamstress"):
		_check(false, "AC3: the rank-2 Seamstress reaches her first real turn")
		return
	_check(int(battle.get_unit("seamstress")["rank"]) == 2,
		"AC3: the forward-launch witness starts from rank 2")
	var step := battle.move(-1)
	_check(bool(step.get("ok", false)) and int(battle.get_unit("seamstress")["rank"]) == 1,
		"AC3: a real Move swaps the Seamstress forward into rank 1")
	if not _to(battle, "seamstress"):
		_check(false, "AC3: the moved Seamstress reaches her next real turn")
		return
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var turn := battle.current_actor_id()
	var round_number := battle.round_number()
	var refused := battle.use_part("seamstress_mending_knot_hat", 1)
	_check(not bool(refused.get("ok", false))
		and str(refused.get("error", "")).contains("cannot launch from rank 1"),
		"AC3: Mending Knot refuses to launch from rank 1 after the real move forward")
	_check(state == battle.state_snapshot() and rng == battle.rng_state()
		and turn == battle.current_actor_id() and round_number == battle.round_number(),
		"AC3: the illegal rank-1 launch preserved the snapshot, turn, round and seeded RNG")


# ---------------------------------------------------------------- AC3: determinism and tracing

func _test_determinism() -> void:
	var first := _trace(498)
	var second := _trace(498)
	_check(not first.is_empty() and first == second,
		"AC3: two equal-seed traces of four real part actions replay receipts, statuses and RNG exactly")
	var receipts: Array = first.get("receipts", [])
	_check(receipts.size() == 4 and _all_ok(receipts),
		"AC3: the trace really executed all four starter actions on real turns")
	var distinct := false
	for offset in range(1, 8):
		var other := _trace(498 + offset)
		if other.is_empty():
			continue
		if int(other["rng"]) != int(first["rng"]):
			distinct = true
			break
	_check(distinct, "AC3: a distinct seed drives a distinct RNG witness")


## Drives one Thread Prick, Tether Loop, Mending Knot and Shielding Hem over four real rounds.
func _trace(seed_value: int) -> Dictionary:
	var battle := _build_battle(seed_value, 1, STARTER_PARTS, false)
	if battle == null:
		return {}
	var receipts: Array = []
	for part_id in [
		"seamstress_thread_prick_needle",
		"seamstress_tether_loop_spools",
		"seamstress_mending_knot_hat",
		"seamstress_shielding_hem_coat",
	]:
		if not _to(battle, "seamstress"):
			break
		receipts.append(battle.use_part(str(part_id), 1))
	return {"receipts": receipts, "snapshot": battle.state_snapshot(), "rng": battle.rng_state()}


func _all_ok(receipts: Array) -> bool:
	for receipt in receipts:
		if not bool(receipt.get("ok", false)):
			return false
	return true


# ---------------------------------------------------------------- fixture and battle helpers

func _catalog() -> Dictionary:
	return StitchedParts.load_catalog(PARTS_PATH)


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
		return null
	return parsed


## The shipped S2 preview, copied in memory, with the eight authored parts appended and only the
## four starter wearables equipped on the existing seamstress hero in rank 2.
func _preview_config(seed_value: int, tier: int, kit: Dictionary) -> Dictionary:
	var parsed: Variant = _read_json(PREVIEW_PATH)
	if not parsed is Dictionary:
		return {}
	var config: Dictionary = parsed
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)):
		return {}
	if not config.get("parts") is Array or not config.get("heroes") is Array or not config.get("foes") is Array:
		return {}
	config["parts"].append_array(catalog["parts"])
	config["seed"] = seed_value
	var heroes: Array = config["heroes"]
	if heroes.size() != 4 or not heroes[1] is Dictionary:
		return {}
	var seamstress: Dictionary = heroes[1]
	if str(seamstress.get("id", "")) != "seamstress" or not seamstress.get("parts") is Dictionary:
		return {}
	for slot in kit:
		seamstress["parts"][slot] = {"id": str(kit[slot]), "tier": tier}
	# Deterministic schedule: only the Seamstress is fast, so she opens every round and the other
	# units pass in a stable seeded order.
	seamstress["speed"] = 40
	for index in [0, 2, 3]:
		heroes[index]["speed"] = 0
	for foe in config["foes"]:
		foe["speed"] = 0
	return config


## Builds one real battle from the detached preview copy. With rank_four_foe the existing third
## preview foe is moved into enemy rank 4 in this battle's own memory (see _relocate_third_foe);
## the shared preview file and every enemy definition stay untouched.
func _build_battle(seed_value: int, tier: int = 1, kit: Dictionary = STARTER_PARTS,
		report: bool = true, rank_four_foe: bool = false) -> StitchedRules:
	var config := _preview_config(seed_value, tier, kit)
	if config.is_empty():
		if report:
			_check(false, "AC2: the shipped S2 preview can be prepared in memory")
		return null
	var created := StitchedRules.create(config)
	if report:
		_check(bool(created.get("ok", false)),
			"AC2: a real four-hero/three-foe Stitched battle builds with the equipped kit: "
				+ str(created.get("error", "")))
	if not bool(created.get("ok", false)):
		return null
	var battle: StitchedRules = created["battle"]
	if rank_four_foe and not _relocate_third_foe(battle):
		if report:
			_check(false, "AC2: the detached fixture moves the third foe into enemy rank 4")
		return null
	if report:
		_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 3,
			"AC2: the fixture keeps four heroes and three foes")
		_check(battle.current_actor_id() == "seamstress" and int(battle.get_unit("seamstress")["rank"]) == 2,
			"AC2: the Seamstress opens the round from rank 2")
	return battle


## Detached-fixture relocation for rank-4 reach: the existing third preview foe (moth_scribe) is
## moved from enemy rank 3 into enemy rank 4 in this battle's own unit table only, leaving rank 3
## vacant. Three foes stay three foes; no enemy is added, removed or re-authored, and the shared
## preview file is never edited.
func _relocate_third_foe(battle: StitchedRules) -> bool:
	if not battle._units.has("moth_scribe"):
		return false
	battle._units["moth_scribe"]["rank"] = MAX_RANK
	if int(battle.get_unit("moth_scribe")["rank"]) != MAX_RANK:
		return false
	if battle.get_foes().size() != 3:
		return false
	return _no_foe_at(battle, 3)


## True when no living foe stands in that enemy rank (an ally on the hero side is irrelevant).
func _no_foe_at(battle: StitchedRules, rank: int) -> bool:
	for foe in battle.get_foes():
		if int(foe["rank"]) == rank and int(foe["hp"]) > 0 and not bool(foe["dead"]):
			return false
	return true


func _to(battle: StitchedRules, actor_id: String, limit: int = 60) -> bool:
	for step in range(limit):
		if battle.is_over():
			return false
		if battle.current_actor_id() == actor_id:
			return true
		if not bool(battle.pass_turn().get("ok", false)):
			return false
	return false


func _to_side(battle: StitchedRules, side: String, limit: int = 60) -> bool:
	for step in range(limit):
		if battle.is_over():
			return false
		if battle.current_side() == side:
			return true
		if not bool(battle.pass_turn().get("ok", false)):
			return false
	return false


# ---------------------------------------------------------------- value helpers

func _is_int(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(value) and float(value) == floorf(float(value))


func _int_list(value: Variant) -> Array:
	var out: Array = []
	if not value is Array:
		return out
	var source: Array = value
	for item in source:
		if not _is_int(item):
			return []
		out.append(int(item))
	return out


func _int_dict(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not value is Dictionary:
		return out
	var source: Dictionary = value
	for key in source:
		if not key is String or not _is_int(source[key]):
			return {}
		out[str(key)] = int(source[key])
	return out


func _has_status(entries: Array, status: String) -> bool:
	return not _status_entry(entries, status).is_empty()


func _status_entry(entries: Array, status: String) -> Dictionary:
	for entry in entries:
		if entry is Dictionary and str(entry.get("status", "")) == status:
			return entry
	return {}


func _status_amount(entries: Array, status: String) -> int:
	var entry := _status_entry(entries, status)
	if entry.is_empty() or not entry.has("amount"):
		return -1
	return int(entry["amount"])


func _status_duration(entries: Array, status: String) -> int:
	var entry := _status_entry(entries, status)
	if entry.is_empty() or not entry.has("duration"):
		return -1
	return int(entry["duration"])
