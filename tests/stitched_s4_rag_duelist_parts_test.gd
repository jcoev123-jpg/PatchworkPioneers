extends SceneTree
## Design v4 S4 data contract: the Rag Duelist's eight wearable Stitched body parts.
##
## Reads the new, independent res://data/parts/rag_duelist_parts.json catalog. The retired v3 card
## catalogs are stable read-only provenance for the look and the numbers and are never imported
## here. The test then deep-copies the shipped S2 preview fixture in memory, appends the eight
## authored records, replaces the Warden with the 32-HP Rag Duelist and drives real StitchedRules
## turns with a fixed seed. Nothing here wires the kit into the title screen, a live fight, rewards
## or a picker: this slice is data plus a seeded rules witness, so no player-facing path is claimed.

const PARTS_PATH := "res://data/parts/rag_duelist_parts.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const MOVE_POSES_PATH := "res://data/art/move_poses.json"
const OWNER := "rag_duelist"
const SLOTS := ["head", "arms", "torso", "legs"]
const MOVE_POSES := ["attack", "attack2", "guard", "skill"]
const MIN_RANK := 1
const MAX_RANK := 4
## Hero base stats of the in-memory Rag Duelist fixture. SPEED 30 keeps the schedule deterministic.
const DUELIST_MAX_HP := 32
const DUELIST_SPEED := 30
const DUELIST_DODGE := 4
const DUELIST_ACC := 6
const HERO_COUNT_FOR_FIXTURE := 4
const REQUIRED_ABILITY_FIELDS := [
	"id", "name", "kind", "launch", "target", "target_side", "multi", "acc", "dmg",
	"crit", "effects", "self_move", "move",
]
## Retired card-system keys that must never appear as a Stitched part effect or rules word.
const RETIRED_CARD_KEYS := [
	"block", "pinned", "unravel", "tether_share_percent", "cleanse_debuff", "energy",
	"cooldown", "mana", "draw", "cost", "dodge_next_attack",
]
## The shipped S2 rank-1 foe and the accuracy of its Sack Swing attack.
const FRAY_SCAVENGER := "fray_scavenger"
const SACK_SWING_ACC := 88

## The four starter wearables: one per slot, the initial equipped kit in the fixture.
const STARTER_PARTS := {
	"head": "rag_duelist_head_feather_feint",
	"arms": "rag_duelist_arms_rapier_lunge",
	"torso": "rag_duelist_torso_cape_parry",
	"legs": "rag_duelist_legs_cape_slip",
}
## The four alternative wearables: never additional battle actions until equipped in that slot.
const ALTERNATE_PARTS := {
	"head": "rag_duelist_head_tattered_snare",
	"arms": "rag_duelist_arms_needle_prick",
	"torso": "rag_duelist_torso_duelist_reprise",
	"legs": "rag_duelist_legs_cape_flourish",
}
const ALL_PART_IDS := [
	"rag_duelist_head_feather_feint",
	"rag_duelist_head_tattered_snare",
	"rag_duelist_arms_rapier_lunge",
	"rag_duelist_arms_needle_prick",
	"rag_duelist_torso_cape_parry",
	"rag_duelist_torso_duelist_reprise",
	"rag_duelist_legs_cape_slip",
	"rag_duelist_legs_cape_flourish",
]

## The authored acceptance contract, one row per part id. "dmg", "effects" and "self_move" are
## indexed by tier - 1; the slot stat is constant across the three stitch tiers.
const EXPECTED := {
	"rag_duelist_head_feather_feint": {
		"name": "Feather Feint", "slot": "head", "stat": {"acc": 4},
		"ability_id": "rag_duelist_head_feather_feint_move", "kind": "debuff",
		"launch": [1, 2], "target": [1, 2, 3], "target_side": "enemy", "pose": "skill",
		"acc": 95,
		"dmg": [[0, 0], [0, 0], [0, 0]],
		"effects": [{"exposed": 1}, {"exposed": 2}, {"exposed": 3}],
		"self_move": [0, 0, 0],
	},
	"rag_duelist_head_tattered_snare": {
		"name": "Tattered Snare", "slot": "head", "stat": {"crit": 3},
		"ability_id": "rag_duelist_head_tattered_snare_move", "kind": "debuff",
		"launch": [1, 2], "target": [1, 2, 3], "target_side": "enemy", "pose": "skill",
		"acc": 92,
		"dmg": [[0, 0], [0, 0], [0, 0]],
		"effects": [{"tangled": 2}, {"tangled": 3}, {"tangled": 4}],
		"self_move": [0, 0, 0],
	},
	"rag_duelist_arms_rapier_lunge": {
		"name": "Rapier Lunge", "slot": "arms", "stat": {"dmg": 1},
		"ability_id": "rag_duelist_arms_rapier_lunge_move", "kind": "melee",
		"launch": [2, 3], "target": [1, 2], "target_side": "enemy", "pose": "attack2",
		"acc": 90,
		"dmg": [[4, 6], [5, 8], [7, 10]],
		"effects": [{}, {}, {}],
		"self_move": [-1, -1, -1],
	},
	"rag_duelist_arms_needle_prick": {
		"name": "Needle Prick", "slot": "arms", "stat": {"dmg": 2},
		"ability_id": "rag_duelist_arms_needle_prick_move", "kind": "melee",
		"launch": [1, 2], "target": [1, 2], "target_side": "enemy", "pose": "attack",
		"acc": 90,
		"dmg": [[3, 5], [4, 6], [5, 8]],
		"effects": [{"bleed": 2}, {"bleed": 3}, {"bleed": 4}],
		"self_move": [0, 0, 0],
	},
	"rag_duelist_torso_cape_parry": {
		"name": "Cape Parry", "slot": "torso", "stat": {"max_hp": 4, "prot": 3},
		"ability_id": "rag_duelist_torso_cape_parry_move", "kind": "buff",
		"launch": [1, 2, 3], "target": [1, 2, 3], "target_side": "self", "pose": "guard",
		"acc": 100,
		"dmg": [[0, 0], [0, 0], [0, 0]],
		"effects": [{"riposte": 2}, {"riposte": 3}, {"riposte": 4}],
		"self_move": [0, 0, 0],
	},
	"rag_duelist_torso_duelist_reprise": {
		"name": "Duelist Reprise", "slot": "torso", "stat": {"prot": 6},
		"ability_id": "rag_duelist_torso_duelist_reprise_move", "kind": "buff",
		"launch": [1, 2], "target": [1, 2], "target_side": "self", "pose": "guard",
		"acc": 100,
		"dmg": [[0, 0], [0, 0], [0, 0]],
		"effects": [{"riposte": 5}, {"riposte": 6}, {"riposte": 7}],
		"self_move": [0, 0, 0],
	},
	"rag_duelist_legs_cape_slip": {
		"name": "Cape Slip", "slot": "legs", "stat": {"dodge": 6},
		"ability_id": "rag_duelist_legs_cape_slip_move", "kind": "buff",
		"launch": [1, 2, 3], "target": [1, 2, 3], "target_side": "self", "pose": "skill",
		"acc": 100,
		"dmg": [[0, 0], [0, 0], [0, 0]],
		"effects": [
			{"dodge": 25, "duration": 1},
			{"dodge": 30, "duration": 1},
			{"dodge": 35, "duration": 1},
		],
		"self_move": [0, 0, 0],
	},
	"rag_duelist_legs_cape_flourish": {
		"name": "Cape Flourish", "slot": "legs", "stat": {"speed": 1, "dodge": 5},
		"ability_id": "rag_duelist_legs_cape_flourish_move", "kind": "buff",
		"launch": [1, 2, 3], "target": [1, 2, 3], "target_side": "self", "pose": "skill",
		"acc": 100,
		"dmg": [[0, 0], [0, 0], [0, 0]],
		"effects": [
			{"dodge": 35, "duration": 1},
			{"dodge": 40, "duration": 1},
			{"dodge": 45, "duration": 1},
		],
		"self_move": [0, 0, 0],
	},
}

## Where each part can legally be cast in the live fixture (rank 2 for Rapier Lunge's launch mask).
const LIVE_CAST := {
	"rag_duelist_head_feather_feint": {"hero_index": 0, "target": 1, "needs_hit": true},
	"rag_duelist_head_tattered_snare": {"hero_index": 0, "target": 1, "needs_hit": true},
	"rag_duelist_arms_rapier_lunge": {"hero_index": 1, "target": 1, "needs_hit": true},
	"rag_duelist_arms_needle_prick": {"hero_index": 0, "target": 1, "needs_hit": true},
	"rag_duelist_torso_cape_parry": {"hero_index": 0, "target": 1, "needs_hit": false},
	"rag_duelist_torso_duelist_reprise": {"hero_index": 0, "target": 1, "needs_hit": false},
	"rag_duelist_legs_cape_slip": {"hero_index": 0, "target": 1, "needs_hit": false},
	"rag_duelist_legs_cape_flourish": {"hero_index": 0, "target": 1, "needs_hit": false},
}

## Four real starter actions for the seeded replay trace.
const TRACE_KIT := {
	"head": "rag_duelist_head_feather_feint",
	"arms": "rag_duelist_arms_needle_prick",
	"torso": "rag_duelist_torso_cape_parry",
	"legs": "rag_duelist_legs_cape_slip",
}

var _failures: Array[String] = []
var _checks := 0
var _cached_catalog: Dictionary = {}


func _initialize() -> void:
	_test_catalog()
	_test_tiers()
	_test_negatives()
	_test_live_fixture()
	_test_live_stats()
	_test_live_tiers()
	_test_lunge_blocked()
	_test_riposte()
	_test_dodge()
	_test_status_ticks()
	_test_live_rejections()
	_test_determinism()
	if _failures.is_empty():
		print("stitched_s4_rag_duelist_parts_test: PASS (", _checks, " checks)")
	else:
		for failure in _failures:
			printerr(failure)
		print("stitched_s4_rag_duelist_parts_test: FAIL (", _failures.size(), " failures / ", _checks, " checks)")
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


# ---------------------------------------------------------------- AC1: the eight-part catalog

func _test_catalog() -> void:
	var catalog := _catalog()
	_check(bool(catalog.get("ok", false)),
		"AC1: the Rag Duelist catalog loads through StitchedParts.load_catalog: " + str(catalog.get("error", "")))
	if not bool(catalog.get("ok", false)):
		return
	var by_id: Dictionary = catalog["by_id"]
	for part_id in ALL_PART_IDS:
		_check(by_id.has(part_id), "AC1: the catalog authors the named part " + part_id)
	# This hero-only file must not silently grow beyond its eight authored wearables.
	_check(by_id.size() == ALL_PART_IDS.size(), "AC1: this catalog holds exactly the eight Rag Duelist wearables")
	for part_id in by_id:
		_check(str(part_id) in ALL_PART_IDS, "AC1: unexpected extra part in this hero kit: " + str(part_id))
	var raw: Variant = _read_json(PARTS_PATH)
	if raw is Dictionary:
		var document: Dictionary = raw
		_check(int(document.get("version", 0)) == 1, "AC1: the parts file keeps the version-1 schema")
		var raw_parts: Variant = document.get("parts")
		_check(raw_parts is Array and raw_parts.size() == ALL_PART_IDS.size(),
			"AC1: the authored parts array holds the eight named wearables")
	else:
		_check(false, "AC1: the parts file parses as a JSON object")
	var slot_counts := {}
	for slot in SLOTS:
		slot_counts[slot] = 0
	var names := {}
	var ability_ids := {}
	for part_id in ALL_PART_IDS:
		if not by_id.has(part_id):
			continue
		var part: Dictionary = by_id[part_id]
		var spec: Dictionary = EXPECTED[part_id]
		var slot := str(spec["slot"])
		slot_counts[slot] = int(slot_counts[slot]) + 1
		_check(str(part["name"]) == str(spec["name"]), "AC1: " + part_id + " carries its authored name")
		_check(str(part["slot"]) == slot, "AC1: " + part_id + " fills the authored " + slot + " slot")
		_check(str(part["owner"]) == OWNER, "AC1: " + part_id + " is owned by the rag_duelist (attribution only)")
		_check(bool(StitchedParts.validate_part(part).get("ok", false)),
			"AC1: validate_part accepts the shipped " + part_id)
		_check(_int_dict(part["stat"]) == _int_dict(spec["stat"]),
			"AC1: " + part_id + " grants its tier-I slot stat " + str(spec["stat"]))
		for key in part["stat"]:
			_check(str(key) in StitchedParts.SLOT_STATS[slot],
				"AC1: " + part_id + " never puts " + str(key) + " in the " + slot + " slot")
		var text := str(part.get("text", "")).strip_edges()
		_check(not text.is_empty(), "AC1: " + part_id + " has short rules text")
		for retired in ["Block", "block", "draw", "Draw", "energy", "card", "stamina"]:
			_check(not text.contains(retired),
				"AC1: " + part_id + " describes live turn-based rules, not the retired card term " + retired)
		var ability: Dictionary = part["ability"]
		for field in REQUIRED_ABILITY_FIELDS:
			_check(ability.has(field), "AC1: %s ability includes the mandatory field %s" % [part_id, field])
		_check(str(ability["id"]) == str(spec["ability_id"]), "AC1: " + part_id + " grants the ability " + str(spec["ability_id"]))
		_check(str(ability["kind"]) == str(spec["kind"]), "AC1: " + part_id + " uses the ability kind " + str(spec["kind"]))
		_check(str(ability["move"]) == str(spec["pose"]) and str(ability["move"]) in MOVE_POSES,
			"AC1: " + part_id + " uses its authored pose " + str(spec["pose"]))
		names[str(part["name"])] = true
		ability_ids[str(ability["id"])] = true
	for slot in SLOTS:
		_check(int(slot_counts[slot]) == 2, "AC1: exactly two authored parts fill the " + slot + " slot")
	_check(names.size() == ALL_PART_IDS.size(), "AC1: all eight part names are distinct")
	_check(ability_ids.size() == ALL_PART_IDS.size(), "AC1: all eight ability ids are distinct")
	# The four starters and the four alternatives, keyed by worn slot.
	_check(STARTER_PARTS.size() == 4 and ALTERNATE_PARTS.size() == 4,
		"AC1: the contract names four starters and four alternatives")
	for slot in SLOTS:
		var starter := str(STARTER_PARTS[slot])
		var alternate := str(ALTERNATE_PARTS[slot])
		_check(by_id.has(starter) and str(by_id[starter]["slot"]) == slot,
			"AC1: %s is the starter wearable for the %s slot" % [starter, slot])
		_check(by_id.has(alternate) and str(by_id[alternate]["slot"]) == slot,
			"AC1: %s is the alternative wearable for the %s slot" % [alternate, slot])
	# The poses really reach shipped art: authored guard/skill poses carry an art path, and the
	# attack/attack2 poses fall back to the shipped rag_duelist_attack.png.
	var pose_document: Variant = _read_json(MOVE_POSES_PATH)
	var duelist_poses: Dictionary = {}
	if pose_document is Dictionary and pose_document.get("heroes") is Dictionary:
		var heroes: Dictionary = pose_document["heroes"]
		if heroes.get(OWNER) is Dictionary:
			duelist_poses = heroes[OWNER]
	else:
		_check(false, "AC1: the shipped move_poses.json parses as a JSON object")
	for part_id in ALL_PART_IDS:
		if not by_id.has(part_id):
			continue
		var pose := str(by_id[part_id]["ability"]["move"])
		if duelist_poses.has(pose):
			_check(not str(duelist_poses[pose].get("art", "")).is_empty(),
				"AC1: " + part_id + " pose " + pose + " has a shipped rag_duelist art path")
		else:
			_check(pose in ["attack", "attack2"],
				"AC1: " + part_id + " pose " + pose + " is only legal as an attack pose with the attack fallback")


# ---------------------------------------------------------------- AC1/AC3: tiers, masks and keys

func _test_tiers() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)):
		return
	for part_id in ALL_PART_IDS:
		if not catalog["by_id"].has(part_id):
			_check(false, "AC1: tier checks need the authored part " + part_id)
			continue
		var part: Dictionary = catalog["by_id"][part_id]
		var spec: Dictionary = EXPECTED[part_id]
		var slot := str(spec["slot"])
		var tiers: Dictionary = part["tiers"]
		_check(tiers.has("2") and tiers.has("3") and not tiers.has("1"),
			"AC1: " + part_id + " authors tiers II and III as partial overrides over the tier-I base")
		for tier in [1, 2, 3]:
			var ability := StitchedParts.ability_at_tier(part, tier)
			var stat := StitchedParts.stat_at_tier(part, tier)
			var tag := "%s tier %d" % [part_id, tier]
			if ability.is_empty():
				_check(false, "AC1: " + tag + " resolves its ability")
				continue
			_check(bool(StitchedParts.validate_ability(ability).get("ok", false)), "AC1: " + tag + " ability validates")
			_check(_int_dict(stat) == _int_dict(spec["stat"]),
				"AC1: " + tag + " keeps the slot-legal stat " + str(spec["stat"]))
			for key in stat:
				_check(str(key) in StitchedParts.SLOT_STATS[slot],
					"AC1: " + tag + " stat " + str(key) + " belongs in the " + slot + " slot")
			_check(str(ability["id"]) == str(spec["ability_id"]), "AC1: " + tag + " keeps its ability id")
			_check(str(ability["name"]) == str(spec["name"]), "AC1: " + tag + " keeps its ability name")
			_check(str(ability["kind"]) == str(spec["kind"]), "AC1: " + tag + " keeps its kind")
			_check(str(ability["target_side"]) == str(spec["target_side"]), "AC1: " + tag + " keeps its target side")
			_check(str(ability["move"]) == str(spec["pose"]) and str(ability["move"]) in MOVE_POSES,
				"AC1: " + tag + " keeps its authored pose")
			_check(int(ability["acc"]) == int(spec["acc"]), "AC1: " + tag + " keeps its authored ACC")
			_check(not bool(ability["multi"]), "AC1: " + tag + " single-targets one rank")
			_check(int(ability["crit"]) == 0, "AC1: " + tag + " adds no ability crit")
			_check(int(ability["self_move"]) == int(spec["self_move"][tier - 1]),
				"AC1: " + tag + " keeps its authored self move")
			_check(_int_list(ability["launch"]) == _int_list(spec["launch"]), "AC1: " + tag + " launch ranks")
			_check(_int_list(ability["target"]) == _int_list(spec["target"]), "AC1: " + tag + " target ranks")
			var launch_mask := int(ability["launch_mask"])
			var target_mask := int(ability["target_mask"])
			_check(launch_mask == StitchedParts.rank_mask(ability["launch"]) and launch_mask != 0,
				"AC1: " + tag + " launch mask matches its authored ranks")
			_check(target_mask == StitchedParts.rank_mask(ability["target"]) and target_mask != 0,
				"AC1: " + tag + " target mask matches its authored ranks")
			_check((launch_mask | target_mask) & ~StitchedParts.ALL_RANKS_MASK == 0,
				"AC1: " + tag + " uses only ranks 1-4")
			for rank in range(MIN_RANK, MAX_RANK + 1):
				_check(StitchedParts.ranks_allowed(launch_mask, rank) == (rank in spec["launch"]),
					"%s: rank %d launch legality" % [tag, rank])
				_check(StitchedParts.ranks_allowed(target_mask, rank) == (rank in spec["target"]),
					"%s: rank %d target legality" % [tag, rank])
			_check(_int_list(ability["dmg"]) == _int_list(spec["dmg"][tier - 1]),
				"AC1: " + tag + " damage range " + str(spec["dmg"][tier - 1]))
			_check(_int_dict(ability["effects"]) == _int_dict(spec["effects"][tier - 1]),
				"AC1: " + tag + " effects " + str(spec["effects"][tier - 1]))
			var effects: Dictionary = ability["effects"]
			for key in effects:
				_check(str(key) in StitchedParts.EFFECT_KEYS, "AC1: " + tag + " effect " + str(key) + " is a registered Stitched key")
				_check(not str(key) in RETIRED_CARD_KEYS, "AC1: " + tag + " never uses retired card key " + str(key))
			if effects.has("dodge"):
				_check(int(effects.get("duration", 0)) == 1,
					"AC1: " + tag + " pairs its temporary Dodge with a one-turn duration")
			else:
				_check(not effects.has("duration"), "AC1: " + tag + " authors no standalone duration")
		# Numbers only ever rise across the three stitch tiers, and each tier really overrides values.
		var previous_dmg := _int_list(spec["dmg"][0])
		var previous_effects: Dictionary = spec["effects"][0]
		for tier in [2, 3]:
			var dmg := _int_list(spec["dmg"][tier - 1])
			var effects: Dictionary = spec["effects"][tier - 1]
			_check(dmg[0] >= previous_dmg[0] and dmg[1] >= previous_dmg[1],
				"AC1: " + part_id + " damage never falls between tiers")
			for key in effects:
				if str(key) == "duration":
					_check(int(effects[key]) == 1, "AC1: " + part_id + " keeps the one-turn dodge duration")
					continue
				_check(int(effects[key]) > int(previous_effects.get(key, 0)),
					"AC1: %s %s rises with each stitch tier" % [part_id, str(key)])
			_check(dmg != previous_dmg or effects != previous_effects,
				"AC1: %s tier %d really overrides its own damage or effects" % [part_id, tier])
			previous_dmg = dmg
			previous_effects = effects


# ---------------------------------------------------------------- AC1/AC3: fail-closed negatives

func _test_negatives() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)):
		return
	var by_id: Dictionary = catalog["by_id"]
	var head: Dictionary = by_id[STARTER_PARTS["head"]].duplicate(true)
	for bad_rank in [-1, 0, 5, 1.5]:
		var mutated := head.duplicate(true)
		mutated["ability"]["launch"] = [bad_rank]
		_check(not bool(StitchedParts.validate_part(mutated).get("ok", false)),
			"AC1: an illegal launch rank %s is refused" % str(bad_rank))
		var retarget := head.duplicate(true)
		retarget["ability"]["target"] = [bad_rank]
		_check(not bool(StitchedParts.validate_part(retarget).get("ok", false)),
			"AC1: an illegal target rank %s is refused" % str(bad_rank))
	var empty_target := head.duplicate(true)
	empty_target["ability"]["target"] = []
	_check(not bool(StitchedParts.validate_part(empty_target).get("ok", false)),
		"AC1: an empty target rank list is refused")
	var repeated := head.duplicate(true)
	repeated["ability"]["launch"] = [1, 1]
	_check(not bool(StitchedParts.validate_part(repeated).get("ok", false)),
		"AC1: a repeated launch rank is refused")
	var no_ability := head.duplicate(true)
	no_ability.erase("ability")
	_check(not bool(StitchedParts.validate_part(no_ability).get("ok", false)),
		"AC1: a part without an ability is refused")
	# Slot and stat legality.
	var bad_slot := head.duplicate(true)
	bad_slot["slot"] = "hat"
	_check(not bool(StitchedParts.validate_part(bad_slot).get("ok", false)),
		"AC1: an unknown wear slot is refused")
	var wrong_stat := head.duplicate(true)
	wrong_stat["stat"] = {"speed": 4}
	_check(not bool(StitchedParts.validate_part(wrong_stat).get("ok", false)),
		"AC1: a head part cannot grant SPEED")
	var wrong_crit := head.duplicate(true)
	wrong_crit["stat"] = {"crit": 2, "dmg": 2}
	_check(not bool(StitchedParts.validate_part(wrong_crit).get("ok", false)),
		"AC1: a head part cannot grant arms damage")
	var negative_stat := head.duplicate(true)
	negative_stat["stat"] = {"acc": -1}
	_check(not bool(StitchedParts.validate_part(negative_stat).get("ok", false)),
		"AC1: a negative stat is refused")
	var no_owner := head.duplicate(true)
	no_owner["owner"] = ""
	_check(not bool(StitchedParts.validate_part(no_owner).get("ok", false)),
		"AC1: an empty owner is refused")
	var extra_field := head.duplicate(true)
	extra_field["stamina"] = 3
	_check(not bool(StitchedParts.validate_part(extra_field).get("ok", false)),
		"AC1: an unregistered part field is refused")
	# Ability legality.
	var bad_acc := head.duplicate(true)
	bad_acc["ability"]["acc"] = 101
	_check(not bool(StitchedParts.validate_part(bad_acc).get("ok", false)),
		"AC1: an ACC above 100 is refused")
	var bad_kind := head.duplicate(true)
	bad_kind["ability"]["kind"] = "spell"
	_check(not bool(StitchedParts.validate_part(bad_kind).get("ok", false)),
		"AC1: an unknown ability kind is refused")
	var bad_side := head.duplicate(true)
	bad_side["ability"]["target_side"] = "everyone"
	_check(not bool(StitchedParts.validate_part(bad_side).get("ok", false)),
		"AC1: an unknown target side is refused")
	var bad_pose := head.duplicate(true)
	bad_pose["ability"]["move"] = "cast"
	_check(not bool(StitchedParts.validate_part(bad_pose).get("ok", false)),
		"AC1: an unknown move pose is refused")
	var bad_self_move := head.duplicate(true)
	bad_self_move["ability"]["self_move"] = -2
	_check(not bool(StitchedParts.validate_part(bad_self_move).get("ok", false)),
		"AC1: a self move beyond one rank is refused")
	var bad_dmg := head.duplicate(true)
	bad_dmg["ability"]["dmg"] = [6, 4]
	_check(not bool(StitchedParts.validate_part(bad_dmg).get("ok", false)),
		"AC1: a reversed damage range is refused")
	var negative_effect := head.duplicate(true)
	negative_effect["ability"]["effects"] = {"exposed": -1}
	_check(not bool(StitchedParts.validate_part(negative_effect).get("ok", false)),
		"AC1: a negative effect value is refused")
	for key in ["draw", "block", "energy", "cooldown", "mana", "dodge_next_attack"]:
		var mutated := head.duplicate(true)
		mutated["ability"]["effects"] = {key: 1}
		_check(not bool(StitchedParts.validate_part(mutated).get("ok", false)),
			"AC3: the retired card-only effect " + key + " is refused")
	var pinned := head.duplicate(true)
	pinned["ability"]["effects"] = {"pinned": true}
	_check(not bool(StitchedParts.validate_part(pinned).get("ok", false)),
		"AC3: the retired card-only Pinned flag is refused")
	var lonely_dodge := head.duplicate(true)
	lonely_dodge["ability"]["effects"] = {"dodge": 25}
	_check(not bool(StitchedParts.validate_part(lonely_dodge).get("ok", false)),
		"AC3: a temporary dodge without its paired duration is refused")
	var lonely_duration := head.duplicate(true)
	lonely_duration["ability"]["effects"] = {"duration": 1}
	_check(not bool(StitchedParts.validate_part(lonely_duration).get("ok", false)),
		"AC3: a duration without its temporary dodge is refused")
	var huge_dodge := head.duplicate(true)
	huge_dodge["ability"]["effects"] = {"dodge": 101, "duration": 1}
	_check(not bool(StitchedParts.validate_part(huge_dodge).get("ok", false)),
		"AC3: a temporary dodge above the engine maximum is refused")
	# Tier overrides are validated too: only 2/3, only ability/stat/text, and fail closed.
	for key in ["1", "4", "II"]:
		var mutated := head.duplicate(true)
		mutated["tiers"][key] = {"ability": {"effects": {"exposed": 2}}}
		_check(not bool(StitchedParts.validate_part(mutated).get("ok", false)),
			"AC3: tier key " + key + " is refused (tiers are only 2 and 3)")
	var flat_tier := head.duplicate(true)
	flat_tier["tiers"]["2"] = 2
	_check(not bool(StitchedParts.validate_part(flat_tier).get("ok", false)),
		"AC3: a non-dictionary tier override is refused")
	var bad_tier_field := head.duplicate(true)
	bad_tier_field["tiers"]["2"] = {"speed": 2}
	_check(not bool(StitchedParts.validate_part(bad_tier_field).get("ok", false)),
		"AC3: a tier override may only carry ability, stat or text")
	var bad_tier_stat := head.duplicate(true)
	bad_tier_stat["tiers"]["2"] = {"stat": {"speed": 2}}
	_check(not bool(StitchedParts.validate_part(bad_tier_stat).get("ok", false)),
		"AC3: a tier override cannot put SPEED on a head part")
	var invented_field := head.duplicate(true)
	invented_field["tiers"]["2"]["ability"] = {"dodge_next_attack": 1}
	_check(not bool(StitchedParts.validate_part(invented_field).get("ok", false)),
		"AC3: a tier override cannot invent an ability field")
	var bad_tier_effect := head.duplicate(true)
	bad_tier_effect["tiers"]["2"]["ability"]["effects"] = {"block": 1}
	_check(not bool(StitchedParts.validate_part(bad_tier_effect).get("ok", false)),
		"AC3: a retired effect inside a tier override fails closed")
	var bad_tier_rank := head.duplicate(true)
	bad_tier_rank["tiers"]["2"]["ability"]["launch"] = [0]
	_check(not bool(StitchedParts.validate_part(bad_tier_rank).get("ok", false)),
		"AC3: an illegal launch rank inside a tier override fails closed")
	var empty_tier_text := head.duplicate(true)
	empty_tier_text["tiers"]["2"] = {"text": "   "}
	_check(not bool(StitchedParts.validate_part(empty_tier_text).get("ok", false)),
		"AC3: empty tier text is refused")
	# Catalog-level fail-closed behaviour.
	_check(not bool(StitchedParts.build_catalog([]).get("ok", false)), "AC1: an empty catalog is refused")
	_check(not bool(StitchedParts.build_catalog([head, head]).get("ok", false)),
		"AC1: a duplicate part id is refused")
	_check(not bool(StitchedParts.load_catalog("").get("ok", false)),
		"AC1: an empty catalog path fails closed")
	_check(not bool(StitchedParts.load_catalog("res://data/parts/rag_duelist_missing.json").get("ok", false)),
		"AC1: a missing catalog file fails closed")
	# Equipping a legs part in the head slot is refused by the real battle builder.
	var mismatched_kit := STARTER_PARTS.duplicate(true)
	mismatched_kit["head"] = str(STARTER_PARTS["legs"])
	var bad_config := _preview_config(11, 1, mismatched_kit, 0)
	_check(not bad_config.is_empty(), "AC1 negative: the S2 fixture can be prepared for a slot-mismatch check")
	if not bad_config.is_empty():
		var created := StitchedRules.create(bad_config)
		_check(not bool(created.get("ok", false)),
			"AC1: a legs part cannot be worn in the head slot")
	# Corrupting in-memory copies must never touch the shipped file.
	var reloaded := StitchedParts.load_catalog(PARTS_PATH)
	_check(bool(reloaded.get("ok", false)), "AC1: the shipped catalog still loads after the negative copies")
	if bool(reloaded.get("ok", false)):
		var shipped: Dictionary = reloaded["by_id"][STARTER_PARTS["head"]]
		_check(_int_dict(shipped["stat"]) == {"acc": 4},
			"AC1: the shipped Feather Feint keeps its authored ACC 4")
		_check(_int_list(shipped["ability"]["launch"]) == [1, 2],
			"AC1: the shipped launch ranks are untouched")


# ---------------------------------------------------------------- AC2: the real 4v3 fixture

func _test_live_fixture() -> void:
	var battle := _build_battle(17, 1, STARTER_PARTS, 0)
	if battle == null:
		return
	var duelist := battle.get_unit("rag_duelist")
	_check(str(duelist["name"]) == "Rag Duelist" and int(duelist["rank"]) == 1,
		"AC2: the fixture replaces the rank-1 Warden with the Rag Duelist")
	_check(int(duelist["base_max_hp"]) == DUELIST_MAX_HP and int(duelist["max_hp"]) == DUELIST_MAX_HP + 4,
		"AC2: the fixture Duelist is the 32-HP hero plus its worn torso stat")
	for slot in SLOTS:
		_check(str(duelist["parts"][slot]["id"]) == str(STARTER_PARTS[slot]),
			"AC2: the Duelist wears its " + slot + " starter part")
	var ids := {}
	for unit in battle.get_heroes() + battle.get_foes():
		ids[str(unit["id"])] = true
	_check(ids.size() == 7, "AC2: the in-memory fixture never duplicates an actor id")


# ---------------------------------------------------------------- AC3: tiers reach live stats

func _test_live_stats() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)):
		return
	for tier in [1, 2, 3]:
		for part_id in ALL_PART_IDS:
			var kit := _kit_for(part_id)
			var battle := _build_battle(11, tier, kit, 0, false)
			if battle == null:
				_check(false, "AC3: the shipped preview builds with %s at tier %d" % [part_id, tier])
				continue
			var totals := {"acc": 0, "crit": 0, "dmg": 0, "max_hp": 0, "prot": 0, "speed": 0, "dodge": 0}
			for slot in SLOTS:
				var stat := StitchedParts.stat_at_tier(catalog["by_id"][str(kit[slot])], tier)
				for key in stat:
					totals[str(key)] = int(totals[str(key)]) + int(stat[key])
			var hero := battle.get_unit("rag_duelist")
			var tag := "%s tier %d" % [part_id, tier]
			_check(int(hero["acc"]) == DUELIST_ACC + int(totals["acc"]),
				"AC3: " + tag + " reaches live ACC")
			_check(int(hero["crit"]) == int(totals["crit"]), "AC3: " + tag + " reaches live crit")
			_check(int(hero["dmg_bonus"]) == int(totals["dmg"]),
				"AC3: " + tag + " reaches the live arms damage bonus")
			_check(int(hero["max_hp"]) == DUELIST_MAX_HP + int(totals["max_hp"]),
				"AC3: " + tag + " reaches live max HP")
			_check(int(hero["hp"]) == int(hero["max_hp"]),
				"AC3: " + tag + " really starts the hero at the raised max HP")
			_check(int(hero["prot"]) == int(totals["prot"]), "AC3: " + tag + " reaches live PROT")
			_check(int(hero["speed"]) == DUELIST_SPEED + int(totals["speed"]),
				"AC3: " + tag + " reaches live SPEED")
			_check(int(hero["dodge"]) == DUELIST_DODGE + int(totals["dodge"]),
				"AC3: " + tag + " reaches live DODGE")


# ---------------------------------------------------------------- AC2: every part on real turns

func _test_live_tiers() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)):
		return
	for part_id in ALL_PART_IDS:
		var cast: Dictionary = LIVE_CAST[part_id]
		for tier in [1, 2, 3]:
			var tag := "%s tier %d" % [part_id, tier]
			var witness := _cast_witness(part_id, tier, int(cast["hero_index"]),
				int(cast["target"]), bool(cast["needs_hit"]))
			if witness.is_empty():
				_check(false, "AC2: a fixed seed lands " + tag + " on a legal real turn")
				continue
			var battle: StitchedRules = witness["battle"]
			var receipt: Dictionary = witness["receipt"]
			var spec: Dictionary = EXPECTED[part_id]
			var result: Dictionary = receipt["results"][0]
			var effects: Dictionary = spec["effects"][tier - 1]
			_check(str(receipt.get("part", "")) == part_id, "AC2: the receipt names the equipped " + part_id)
			_check(str(receipt.get("ability", "")) == str(spec["ability_id"]),
				"AC2: " + tag + " resolves its authored ability id")
			_check(str(receipt.get("actor", "")) == "rag_duelist", "AC2: " + tag + " is used by the Rag Duelist")
			_check(bool(result.get("hit", false)), "AC2: " + tag + " reports a confirmed hit receipt")
			if str(spec["target_side"]) == "enemy":
				var target := battle.get_unit(str(result["target"]))
				_check(str(result["target_side"]) == "foe", "AC2: " + tag + " hits the enemy side")
				_check(int(result["target_rank"]) == int(cast["target"]),
					"AC2: " + tag + " resolves in its chosen foe rank")
				var damage := _int_list(spec["dmg"][tier - 1])
				var bonus := int(battle.get_unit("rag_duelist")["dmg_bonus"])
				var prot := int(target["prot"])
				var dealt := int(result["damage"])
				if damage[1] == 0:
					_check(dealt == 0,
						"AC2: " + tag + " is a pure debuff and deals no direct damage")
				else:
					var low := StitchedRules.apply_protection(damage[0] + bonus, prot)
					var high := StitchedRules.apply_protection(damage[1] + bonus, prot)
					var crit_high := StitchedRules.apply_protection(
						StitchedRules.crit_damage(damage[1]) + bonus, prot)
					_check(dealt >= low, "AC2: " + tag + " damage reaches its authored minimum")
					_check(dealt <= high or (bool(result.get("crit", false)) and dealt == crit_high),
						"AC2: " + tag + " damage stays inside the authored range plus the arms stat")
				_check(int(result["target_hp"]) == int(target["hp"]),
					"AC2: " + tag + " reports the foe's real remaining HP")
				for key in effects:
					_check(int(target["statuses"].get(str(key), 0)) == int(effects[key]),
						"AC2: %s leaves %s %d on the landed foe" % [tag, str(key), int(effects[key])])
					_check(_status_value(result.get("statuses", []), str(key)) == int(effects[key]),
						"AC2: " + tag + " reports the applied " + str(key))
			else:
				_check(str(result["target_side"]) == "hero" and str(result["target"]) == "rag_duelist",
					"AC2: " + tag + " targets the caster's own rank")
				var duelist := battle.get_unit("rag_duelist")
				for key in effects:
					if str(key) == "duration":
						continue
					if str(key) == "dodge":
						var buff: Dictionary = duelist.get("dodge_buff", {})
						_check(int(buff.get("amount", 0)) == int(effects[key]),
							"AC2: " + tag + " stores its temporary Dodge amount on the Duelist")
						_check(int(buff.get("turns", 0)) == int(effects["duration"]),
							"AC2: " + tag + " stores a one-turn temporary Dodge")
						_check(not duelist["statuses"].has("dodge"),
							"AC2: " + tag + " never invents a fake dodge status")
						_check(_status_value(result.get("statuses", []), "dodge") == int(effects[key]),
							"AC2: " + tag + " reports the temporary Dodge amount")
					else:
						_check(int(duelist["statuses"].get(str(key), 0)) == int(effects[key]),
							"AC2: %s leaves %s %d on the Duelist" % [tag, str(key), int(effects[key])])
						_check(_status_value(result.get("statuses", []), str(key)) == int(effects[key]),
							"AC2: " + tag + " reports the applied " + str(key))
			if part_id == "rag_duelist_arms_rapier_lunge":
				var move: Dictionary = receipt.get("self_move", {})
				_check(bool(move.get("ok", false)), "AC2: " + tag + " resolves its one-rank forward step")
				_check(int(move.get("from", 0)) == 2 and int(move.get("to", 0)) == 1,
					"AC2: " + tag + " steps from rank 2 to rank 1")
				_check(str(move.get("swapped", "")) == "seamstress",
					"AC2: " + tag + " swaps with the legal front ally")
				_check(int(battle.get_unit("rag_duelist")["rank"]) == 1
					and int(battle.get_unit("seamstress")["rank"]) == 2,
					"AC2: " + tag + " really moves both heroes on the board")


# ---------------------------------------------------------------- AC3: blocked swap is atomic

func _test_lunge_blocked() -> void:
	var battle := _build_battle(23, 1, STARTER_PARTS, 1)
	if battle == null:
		return
	_check(_to(battle, "rag_duelist"), "AC2: the rank-2 Duelist opens the round")
	var foe_hp := int(battle.get_unit(FRAY_SCAVENGER)["hp"])
	# A tangled front ally cannot be swapped, so the mandatory step refuses before any roll.
	battle._units["seamstress"]["statuses"]["tangled"] = 1
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var refused := battle.use_part("rag_duelist_arms_rapier_lunge", 1)
	_check(not bool(refused.get("ok", false)) and str(refused.get("error", "")).contains("self move is blocked"),
		"AC3: a tangled front ally refuses the Rapier Lunge swap")
	_check(before == battle.state_snapshot() and rng == battle.rng_state(),
		"AC3: the tangled-ally refusal preserved state, turn pointer and RNG")
	_check(int(battle.get_unit(FRAY_SCAVENGER)["hp"]) == foe_hp,
		"AC3: the refused lunge never rolled or dealt damage")
	battle._units["seamstress"]["statuses"].erase("tangled")
	# A snipped thread on that ally blocks the same step.
	battle._thread_cuts["seamstress"] = 1
	before = battle.state_snapshot()
	rng = battle.rng_state()
	refused = battle.use_part("rag_duelist_arms_rapier_lunge", 1)
	_check(not bool(refused.get("ok", false)) and str(refused.get("error", "")).contains("self move is blocked"),
		"AC3: a snipped front ally also refuses the Rapier Lunge swap")
	_check(before == battle.state_snapshot() and rng == battle.rng_state(),
		"AC3: the snipped-ally refusal is equally atomic")
	_check(int(battle.get_unit(FRAY_SCAVENGER)["hp"]) == foe_hp,
		"AC3: the blocked swap still defines the action's legality before any RNG")


# ---------------------------------------------------------------- AC2: real Riposte reaction

func _test_riposte() -> void:
	var cases := [
		{"part": "rag_duelist_torso_cape_parry", "tier": 1, "riposte": 2},
		{"part": "rag_duelist_torso_cape_parry", "tier": 3, "riposte": 4},
		{"part": "rag_duelist_torso_duelist_reprise", "tier": 3, "riposte": 7},
	]
	for entry in cases:
		var part_id := str(entry["part"])
		var tier := int(entry["tier"])
		var amount := int(entry["riposte"])
		var tag := "%s tier %d" % [part_id, tier]
		var witness := _riposte_witness(part_id, tier)
		if witness.is_empty():
			_check(false, "AC2: a fixed seed lets a foe land a hit on the " + tag + " Duelist")
			continue
		var battle: StitchedRules = witness["battle"]
		var result: Dictionary = witness["receipt"]["results"][0]
		_check(bool(result.get("hit", false)), "AC2: the foe's real hit confirms for " + tag)
		_check(str(result["target"]) == "rag_duelist", "AC2: the foe attacks the buffed Duelist")
		_check(int(result.get("riposte", 0)) == amount, "AC2: " + tag + " reflects its Riposte " + str(amount))
		var foe_hp := int(witness["foe_hp_before"])
		_check(int(result.get("attacker_hp", -1)) == foe_hp - amount,
			"AC2: " + tag + " takes exactly its authored damage back off the foe")
		_check(int(battle.get_unit(FRAY_SCAVENGER)["hp"]) == foe_hp - amount,
			"AC2: the reflected damage is real foe HP, not just a receipt field")


# ---------------------------------------------------------------- AC2: temporary Dodge in play

func _test_dodge() -> void:
	var witness := _dodge_witness("rag_duelist_legs_cape_slip", 1)
	if witness.is_empty():
		_check(false, "AC2: a fixed seed lets the rank-1 foe attack the Cape Slip Duelist")
		return
	var battle: StitchedRules = witness["battle"]
	var permanent := int(witness["permanent"])
	var duelist := battle.get_unit("rag_duelist")
	_check(int(StitchedRules.effective_dodge(duelist)) == permanent + 25,
		"AC2: Cape Slip adds its 25 temporary Dodge to effective_dodge only")
	_check(int(duelist["dodge_buff"]["turns"]) == 1,
		"AC2: the temporary Dodge lasts one of the Duelist's turns")
	_check(int(duelist["dodge"]) == permanent,
		"AC2: permanent Dodge is never raised by the buff")
	var result: Dictionary = witness["receipt"]["results"][0]
	var foe_acc := int(witness["foe_acc"])
	var miss_streak := int(witness["miss_streak"])
	var expected := StitchedRules.hit_chance(SACK_SWING_ACC + foe_acc, permanent + 25, miss_streak)
	_check(int(result.get("hit_chance", -1)) == expected,
		"AC2: the opponent's reported hit chance includes exactly the temporary Dodge")
	_check(expected < StitchedRules.hit_chance(SACK_SWING_ACC + foe_acc, permanent, miss_streak),
		"AC2: temporary Dodge lowers the reported chance without guaranteeing a miss")
	# The buff survives the foe's turn and expires after the Duelist's own next turn.
	_check(_to(battle, "rag_duelist"), "AC2: the Duelist reaches its next real turn")
	_check(int(StitchedRules.effective_dodge(battle.get_unit("rag_duelist"))) == permanent + 25,
		"AC2: the one-turn Dodge survives the intervening foe turn")
	_check(bool(battle.pass_turn().get("ok", false)), "AC2: the Duelist spends that next turn")
	_check(int(StitchedRules.effective_dodge(battle.get_unit("rag_duelist"))) == permanent,
		"AC2: the one-turn Dodge expires after that turn")
	_check(int(battle.get_unit("rag_duelist")["dodge"]) == permanent,
		"AC2: the expiry leaves permanent Dodge exactly as it was")


# ---------------------------------------------------------------- AC2: statuses tick in play

func _test_status_ticks() -> void:
	var tangled := _cast_witness("rag_duelist_head_tattered_snare", 1, 0, 1, true)
	if tangled.is_empty():
		_check(false, "AC2: a fixed seed lands Tattered Snare for the expiry witness")
	else:
		var battle: StitchedRules = tangled["battle"]
		var foe_id := str(tangled["receipt"]["results"][0]["target"])
		_check(int(battle.get_unit(foe_id)["statuses"].get("tangled", 0)) == 2,
			"AC2: a landed Tattered Snare leaves a real Tangled 2")
		_check(_to(battle, foe_id), "AC2: the Tangled foe reaches its own seeded turn")
		_check(int(battle.get_unit(foe_id)["statuses"].get("tangled", 0)) == 1,
			"AC2: Tangled 2 ticks down by exactly one foe turn")
		_check(int(battle.get_unit(foe_id)["hp"]) > 0,
			"AC2: Tattered Snare itself deals no damage")
	var bleed := _cast_witness("rag_duelist_arms_needle_prick", 3, 0, 1, true)
	if bleed.is_empty():
		_check(false, "AC2: a fixed seed lands Needle Prick for the Bleed witness")
	else:
		var battle: StitchedRules = bleed["battle"]
		var foe_id := str(bleed["receipt"]["results"][0]["target"])
		var hp_after_hit := int(battle.get_unit(foe_id)["hp"])
		_check(int(battle.get_unit(foe_id)["statuses"].get("bleed", 0)) == 4,
			"AC2: a landed tier-III Needle Prick leaves a real Bleed 4")
		_check(_to(battle, foe_id), "AC2: the bleeding foe reaches its own seeded turn")
		_check(int(battle.get_unit(foe_id)["hp"]) == hp_after_hit - 4,
			"AC2: Bleed 4 really deals four HP at the start of that foe turn")
		_check(int(battle.get_unit(foe_id)["statuses"].get("bleed", 0)) == 3,
			"AC2: the Bleed counter ticks down by one unit turn")
	var exposed := _cast_witness("rag_duelist_head_feather_feint", 3, 0, 1, true)
	if exposed.is_empty():
		_check(false, "AC2: a fixed seed lands Feather Feint for the Exposed witness")
	else:
		var battle: StitchedRules = exposed["battle"]
		var foe_id := str(exposed["receipt"]["results"][0]["target"])
		_check(int(battle.get_unit(foe_id)["statuses"].get("exposed", 0)) == 3,
			"AC2: a landed tier-III Feather Feint leaves a real Exposed 3")
		_check(_to(battle, foe_id), "AC2: the Exposed foe reaches its own seeded turn")
		_check(int(battle.get_unit(foe_id)["statuses"].get("exposed", 0)) == 2,
			"AC2: Exposed 3 ticks down by exactly one foe turn")


# ---------------------------------------------------------------- AC2/AC3: refusals are atomic

func _test_live_rejections() -> void:
	var battle := _build_battle(17, 1, STARTER_PARTS, 0)
	if battle == null:
		return
	_check(battle.current_actor_id() == "rag_duelist" and int(battle.get_unit("rag_duelist")["rank"]) == 1,
		"AC2: the seeded schedule gives the rank-1 Duelist the first turn")
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var no_foe := battle.use_part("rag_duelist_head_feather_feint", 4)
	_check(not bool(no_foe.get("ok", false)) and str(no_foe.get("error", "")).contains("no legal target in rank 4"),
		"AC2: an enemy-targeting part refuses a rank holding no foe")
	var rank_zero := battle.use_part("rag_duelist_head_feather_feint", 0)
	_check(not bool(rank_zero.get("ok", false)) and str(rank_zero.get("error", "")).contains("no legal target in rank 0"),
		"AC2: rank 0 is not a legal target rank")
	var rank_five := battle.use_part("rag_duelist_head_feather_feint", 5)
	_check(not bool(rank_five.get("ok", false)) and str(rank_five.get("error", "")).contains("no legal target in rank 5"),
		"AC2: rank 5 is not a legal target rank")
	var wrong_self := battle.use_part("rag_duelist_torso_cape_parry", 2)
	_check(not bool(wrong_self.get("ok", false)) and str(wrong_self.get("error", "")).contains("no legal target in rank 2"),
		"AC2: a self part refuses another hero's rank")
	var wrong_launch := battle.use_part("rag_duelist_arms_rapier_lunge", 1)
	_check(not bool(wrong_launch.get("ok", false)) and str(wrong_launch.get("error", "")).contains("cannot launch from rank 1"),
		"AC2: Rapier Lunge refuses to launch from rank 1")
	var unequipped_head := battle.use_part("rag_duelist_head_tattered_snare", 1)
	_check(not bool(unequipped_head.get("ok", false)) and str(unequipped_head.get("error", "")).contains("not equipped"),
		"AC2: an alternative part that is not equipped grants no battle action")
	var unequipped_arms := battle.use_part("rag_duelist_arms_needle_prick", 1)
	_check(not bool(unequipped_arms.get("ok", false)) and str(unequipped_arms.get("error", "")).contains("not equipped"),
		"AC2: the unequipped pool arms part grants no battle action")
	var unknown := battle.use_part("not_a_part", 1)
	_check(not bool(unknown.get("ok", false)) and str(unknown.get("error", "")).contains("not equipped"),
		"AC2: an unknown part id is refused")
	_check(before == battle.state_snapshot() and rng == battle.rng_state(),
		"AC2: every refused action preserved the complete state, turn pointer and RNG")
	# A torn part stays equipped but grants no action and no stat.
	var torn_kit := STARTER_PARTS.duplicate(true)
	var torn_config := _preview_config(17, 1, torn_kit, 0, "arms")
	_check(not torn_config.is_empty(), "AC3: the fixture can equip a torn part")
	if not torn_config.is_empty():
		var torn_created := StitchedRules.create(torn_config)
		_check(bool(torn_created.get("ok", false)),
			"AC3: a torn part is still a legal equipment record: " + str(torn_created.get("error", "")))
		if bool(torn_created.get("ok", false)):
			var torn_battle: StitchedRules = torn_created["battle"]
			_check(int(torn_battle.get_unit("rag_duelist")["dmg_bonus"]) == 0,
				"AC3: the torn arms part contributes no damage stat")
			var torn_before := torn_battle.state_snapshot()
			var torn_rng := torn_battle.rng_state()
			var refused := torn_battle.use_part("rag_duelist_arms_rapier_lunge", 1)
			_check(not bool(refused.get("ok", false)) and str(refused.get("error", "")).contains("torn"),
				"AC3: a torn part refuses its ability")
			_check(torn_before == torn_battle.state_snapshot() and torn_rng == torn_battle.rng_state(),
				"AC3: the torn refusal changed neither state nor RNG")
	# Tier IV and a wrong-slot kit are refused by the real battle builder.
	var tier_four := _preview_config(17, 4, STARTER_PARTS, 0)
	_check(not tier_four.is_empty(), "AC3: the fixture can carry a tier-IV request")
	if not tier_four.is_empty():
		var created := StitchedRules.create(tier_four)
		_check(not bool(created.get("ok", false)) and str(created.get("error", "")).contains("illegal tier"),
			"AC3: a tier-IV equipped part is refused")
	var wrong_slot_kit := STARTER_PARTS.duplicate(true)
	wrong_slot_kit["torso"] = str(ALTERNATE_PARTS["head"])
	var wrong_slot_config := _preview_config(17, 1, wrong_slot_kit, 0)
	_check(not wrong_slot_config.is_empty(), "AC3: the fixture can carry a wrong-slot kit")
	if not wrong_slot_config.is_empty():
		var created := StitchedRules.create(wrong_slot_config)
		_check(not bool(created.get("ok", false)) and str(created.get("error", "")).contains("cannot wear"),
			"AC3: a head part cannot be worn in the torso slot")
	var unknown_kit := STARTER_PARTS.duplicate(true)
	unknown_kit["legs"] = "rag_duelist_legs_not_a_part"
	var unknown_config := _preview_config(17, 1, unknown_kit, 0)
	if not unknown_config.is_empty():
		var created := StitchedRules.create(unknown_config)
		_check(not bool(created.get("ok", false)) and str(created.get("error", "")).contains("unknown part"),
			"AC3: an unknown equipped part id is refused")
	# A stale turn: the wearer cannot act during a foe turn.
	var stale := _build_battle(29, 1, STARTER_PARTS, 0)
	if stale != null:
		_check(_to_side(stale, "foe"), "AC2: a real foe turn follows the opening Duelist turn")
		var stale_state := stale.state_snapshot()
		var stale_rng := stale.rng_state()
		var refused := stale.use_part("rag_duelist_head_feather_feint", 1)
		_check(not bool(refused.get("ok", false)) and str(refused.get("error", "")).contains("not a hero turn"),
			"AC2: an action attempted on a stale turn is refused")
		_check(stale_state == stale.state_snapshot() and stale_rng == stale.rng_state(),
			"AC2: the stale-turn refusal preserved the complete state and RNG")


# ---------------------------------------------------------------- AC3: determinism and replay

func _test_determinism() -> void:
	var first := _trace(498)
	var second := _trace(498)
	_check(not first.is_empty() and first == second,
		"AC3: two equal-seed traces replay receipts, statuses, snapshot and RNG exactly")
	var receipts: Array = first.get("receipts", [])
	_check(receipts.size() == 4 and _all_ok(receipts),
		"AC3: the trace really executed all four tier-III part actions on real turns")
	var distinct := false
	for offset in range(1, 8):
		var other := _trace(498 + offset)
		if other.is_empty():
			continue
		if int(other["rng"]) != int(first["rng"]):
			distinct = true
			break
	_check(distinct, "AC3: a distinct seed drives a distinct RNG witness")


## Drives Feather Feint, Needle Prick, Cape Parry and Cape Slip over four real rounds at tier III.
func _trace(seed_value: int) -> Dictionary:
	var battle := _build_battle(seed_value, 3, TRACE_KIT, 0, false)
	if battle == null:
		return {}
	var receipts: Array = []
	for action in [
		["rag_duelist_head_feather_feint", 1],
		["rag_duelist_arms_needle_prick", 1],
		["rag_duelist_torso_cape_parry", 1],
		["rag_duelist_legs_cape_slip", 1],
	]:
		if not _to(battle, "rag_duelist"):
			break
		receipts.append(battle.use_part(str(action[0]), int(action[1])))
	return {"receipts": receipts, "snapshot": battle.state_snapshot(), "rng": battle.rng_state()}


# ---------------------------------------------------------------- fixture and battle helpers

func _catalog() -> Dictionary:
	if _cached_catalog.is_empty():
		_cached_catalog = StitchedParts.load_catalog(PARTS_PATH)
	return _cached_catalog


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


## The shipped S2 preview deep-copied in memory: the Warden is replaced by the Rag Duelist at the
## requested rank, the eight authored parts are appended, and only the four fitted slots are worn.
func _preview_config(seed_value: int, tier: int, kit: Dictionary, hero_index: int,
		torn_slot: String = "") -> Dictionary:
	var parsed: Variant = _read_json(PREVIEW_PATH)
	if not parsed is Dictionary:
		return {}
	var source: Dictionary = parsed
	var config: Dictionary = source.duplicate(true)
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)):
		return {}
	if not config.get("parts") is Array or not config.get("heroes") is Array or not config.get("foes") is Array:
		return {}
	config["parts"].append_array(catalog["parts"])
	config["seed"] = seed_value
	var duelist: Dictionary = {
		"id": OWNER,
		"name": "Rag Duelist",
		"max_hp": DUELIST_MAX_HP,
		"speed": DUELIST_SPEED,
		"dodge": DUELIST_DODGE,
		"acc": DUELIST_ACC,
		"prot": 0,
		"parts": {},
	}
	for slot in SLOTS:
		if not kit.has(slot):
			continue
		var worn := {"id": str(kit[slot]), "tier": tier}
		if str(slot) == torn_slot:
			worn["torn"] = true
		duelist["parts"][slot] = worn
	var companions: Array = []
	for entry in config["heroes"]:
		if str(entry.get("id", "")) == "warden":
			continue
		companions.append(entry)
	if companions.size() != 3:
		return {}
	var heroes: Array = []
	for index in range(HERO_COUNT_FOR_FIXTURE):
		if index == clampi(hero_index, 0, HERO_COUNT_FOR_FIXTURE - 1):
			heroes.append(duelist)
		else:
			heroes.append(companions.pop_front())
	config["heroes"] = heroes
	# Deterministic schedule: only the Duelist is fast, so it opens every round and the other
	# units pass in a stable seeded order.
	for hero in heroes:
		hero["speed"] = DUELIST_SPEED if str(hero.get("id", "")) == OWNER else 0
	for foe in config["foes"]:
		foe["speed"] = 0
	return config


func _build_battle(seed_value: int, tier: int = 1, kit: Dictionary = STARTER_PARTS,
		hero_index: int = 0, report: bool = true) -> StitchedRules:
	var config := _preview_config(seed_value, tier, kit, hero_index)
	if config.is_empty():
		if report:
			_check(false, "AC2: the shipped S2 preview can be prepared in memory")
		return null
	var created := StitchedRules.create(config)
	if report:
		_check(bool(created.get("ok", false)),
			"AC2: a real four-hero/three-foe Stitched battle builds with the worn kit: "
				+ str(created.get("error", "")))
	if not bool(created.get("ok", false)):
		return null
	var battle: StitchedRules = created["battle"]
	if report:
		_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 3,
			"AC2: the fixture keeps four heroes and three foes")
		_check(battle.current_actor_id() == OWNER,
			"AC2: the fast Rag Duelist opens the round")
	return battle


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


## The starter kit with the tested part fitted in its own slot; every other slot stays legal.
func _kit_for(part_id: String) -> Dictionary:
	var kit := STARTER_PARTS.duplicate(true)
	for slot in SLOTS:
		if str(ALTERNATE_PARTS[slot]) == part_id:
			kit[slot] = part_id
			return kit
	return kit


func _cast_witness(part_id: String, tier: int, hero_index: int, target_rank: int,
		needs_hit: bool) -> Dictionary:
	for seed_value in range(1, 90):
		var battle := _build_battle(seed_value, tier, _kit_for(part_id), hero_index, false)
		if battle == null:
			return {}
		if not _to(battle, OWNER):
			continue
		var receipt := battle.use_part(part_id, target_rank)
		if not bool(receipt.get("ok", false)) or receipt.get("results", []).is_empty():
			continue
		if needs_hit and not bool(receipt["results"][0].get("hit", false)):
			continue
		return {"battle": battle, "receipt": receipt, "seed": seed_value}
	return {}


## Casts a Riposte part, then lets the rank-1 foe land a real hit on the buffed Duelist.
func _riposte_witness(part_id: String, tier: int) -> Dictionary:
	for seed_value in range(1, 120):
		var battle := _build_battle(seed_value, tier, _kit_for(part_id), 0, false)
		if battle == null:
			return {}
		if not _to(battle, OWNER):
			continue
		var cast := battle.use_part(part_id, 1)
		if not bool(cast.get("ok", false)):
			continue
		if int(battle.get_unit(OWNER)["statuses"].get("riposte", 0)) <= 0:
			continue
		if not _to(battle, FRAY_SCAVENGER):
			continue
		var foe_hp := int(battle.get_unit(FRAY_SCAVENGER)["hp"])
		var attack := battle.use_foe_ability("sack_swing", 1)
		if not bool(attack.get("ok", false)) or attack.get("results", []).is_empty():
			continue
		if not bool(attack["results"][0].get("hit", false)):
			continue
		return {"battle": battle, "receipt": attack, "foe_hp_before": foe_hp, "seed": seed_value}
	return {}


## Casts a temporary Dodge part, then lets the rank-1 foe attack the buffed Duelist.
func _dodge_witness(part_id: String, tier: int) -> Dictionary:
	for seed_value in range(1, 120):
		var battle := _build_battle(seed_value, tier, _kit_for(part_id), 0, false)
		if battle == null:
			return {}
		if not _to(battle, OWNER):
			continue
		var cast := battle.use_part(part_id, 1)
		if not bool(cast.get("ok", false)):
			continue
		var duelist := battle.get_unit(OWNER)
		var permanent := int(duelist["dodge"])
		if int(duelist.get("dodge_buff", {}).get("amount", 0)) <= 0:
			continue
		if int(StitchedRules.effective_dodge(duelist)) <= permanent:
			continue
		if not _to(battle, FRAY_SCAVENGER):
			continue
		var foe := battle.get_unit(FRAY_SCAVENGER)
		var foe_acc := int(foe["acc"]) + int(battle.candle_band()["enemy_acc"])
		var miss_streak := int(foe["miss_streak"])
		var attack := battle.use_foe_ability("sack_swing", 1)
		if not bool(attack.get("ok", false)) or attack.get("results", []).is_empty():
			continue
		return {
			"battle": battle, "receipt": attack, "seed": seed_value,
			"permanent": permanent, "foe_acc": foe_acc, "miss_streak": miss_streak,
		}
	return {}


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


func _status_entry(entries: Array, status: String) -> Dictionary:
	for entry in entries:
		if entry is Dictionary and str(entry.get("status", "")) == status:
			return entry
	return {}


func _status_value(entries: Array, status: String) -> int:
	var entry := _status_entry(entries, status)
	if entry.is_empty():
		return -1
	if entry.has("amount"):
		return int(entry["amount"])
	return int(entry.get("duration", -1))


func _all_ok(receipts: Array) -> bool:
	for receipt in receipts:
		if not bool(receipt.get("ok", false)):
			return false
	return true
