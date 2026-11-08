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
## The shipped rank-3 preview foe whose Ink Flick can reach a rank-4 hero, and the three real
## companions left in the fixture once the Warden is replaced by the Rag Duelist.
const MOTH_SCRIBE := "moth_scribe"
const INK_FLICK_ACC := 88
const RANK_FOUR_COMPANIONS := ["seamstress", "tinker", "lantern_monk"]

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
## The two legs patches are the only wearables whose slot stat climbs with the stitch tier: tiers
## II and III add persistent Dodge over the tier-I record. Every other part keeps one stat.
const TIER_STATS := {
	"rag_duelist_legs_cape_slip": [{"dodge": 6}, {"dodge": 8}, {"dodge": 10}],
	"rag_duelist_legs_cape_flourish": [
		{"speed": 1, "dodge": 5}, {"speed": 1, "dodge": 7}, {"speed": 1, "dodge": 9},
	],
}

## S14: the S4 cape-leg records are worn limbs and S13 sewn-patch identities, so their
## player-readable text is a sewn-fabric description rather than a part-granted combat move.
const CAPE_LEG_TEXT := {
	"rag_duelist_legs_cape_slip": "A narrow strip of black cape cloth is sewn across a crimson boot cuff, its frayed hem held by crooked gold stitches.",
	"rag_duelist_legs_cape_flourish": "A broad ragged cape-tail is patched to a black boot with crimson thread and one tarnished gold button.",
}

## Whole words the two cape-leg descriptions must never promise, matched case-insensitively on
## word boundaries so prose like "patched" or "cuff" cannot satisfy or trip a check by accident.
const CAPE_LEG_FORBIDDEN_WORDS := [
	"rank", "ranks", "tier", "tiers", "attack", "hit", "dodge", "turn", "duration",
	"ability", "move", "target", "damage", "guard", "heal", "weak", "bleed", "status",
	"skill", "step", "forward", "backward", "swap", "swapping", "ally", "gain", "grants",
	"temporary", "chance", "evade", "evasion", "effect", "spend", "action",
]

## S14: the two head patches are worn sewn-cloth identities too, so their player-readable text is
## a sewn-fabric description rather than the part-granted combat move their legacy data still holds.
const HEAD_PATCH_TEXT := {
	"rag_duelist_head_feather_feint": "A crimson hat feather leans over a black button eyepatch, secured with crooked gold stitches.",
	"rag_duelist_head_tattered_snare": "A knotted black rag ribbon wraps the hatband beneath the Duelist's feather, its frayed tail sewn in crimson thread.",
}

## Visible sewn-cloth words each head description must name, so the copy stays a description of the
## worn patch rather than a generic nonempty string.
const HEAD_PATCH_WORDS := {
	"rag_duelist_head_feather_feint": ["feather", "eyepatch", "stitches"],
	"rag_duelist_head_tattered_snare": ["ribbon", "sewn", "thread"],
}

## Whole combat words the two head descriptions must never promise, matched case-insensitively on
## word boundaries so "stitches" or "button" cannot trip a check by accident. The retired
## Exposed/Mark/Tangled/Weak statuses are named explicitly: the legacy abilities keep them, the
## cloth copy must not advertise them.
const HEAD_PATCH_FORBIDDEN_WORDS := [
	"rank", "ranks", "tier", "tiers", "exposed", "mark", "marked", "tangled", "weak",
	"damage", "hit", "hits", "attack", "attacks", "dodge", "turn", "turns", "duration",
	"ability", "abilities", "move", "moves", "target", "targets", "guard", "heal", "bleed",
	"status", "statuses", "skill", "skills", "step", "forward", "backward", "swap",
	"swapping", "ally", "gain", "grants", "temporary", "chance", "evade", "evasion",
	"effect", "effects", "spend", "action", "actions",
]

## The authored acceptance contract, one row per part id. "dmg", "effects" and "self_move" are
## indexed by tier - 1; "stat" is the tier-I slot stat (the two legs patches climb through
## TIER_STATS), and every other part's slot stat is constant across the three stitch tiers.
const EXPECTED := {
	"rag_duelist_head_feather_feint": {
		"name": "Feather Feint", "slot": "head", "stat": {"acc": 4},
		"ability_id": "rag_duelist_head_feather_feint_move", "kind": "debuff",
		"launch": [1, 2], "target": [1, 2, 3], "target_side": "enemy", "pose": "skill",
		"acc": 95,
		"dmg": [[0, 0], [0, 0], [0, 0]],
		"effects": [{"exposed": 2}, {"exposed": 2, "mark": 1}, {"exposed": 3, "mark": 2}],
		"self_move": [0, 0, 0],
	},
	"rag_duelist_head_tattered_snare": {
		"name": "Tattered Snare", "slot": "head", "stat": {"crit": 3},
		"ability_id": "rag_duelist_head_tattered_snare_move", "kind": "debuff",
		"launch": [1, 2], "target": [1, 2, 3], "target_side": "enemy", "pose": "skill",
		"acc": 92,
		"dmg": [[0, 0], [0, 0], [0, 0]],
		"effects": [{"tangled": 2}, {"tangled": 3, "weak": 2}, {"tangled": 4, "weak": 2}],
		"self_move": [0, 0, 0],
	},
	"rag_duelist_arms_rapier_lunge": {
		"name": "Rapier Lunge", "slot": "arms", "stat": {"dmg": 1},
		"ability_id": "rag_duelist_arms_rapier_lunge_move", "kind": "melee",
		"launch": [2, 3], "target": [1, 2], "target_side": "enemy", "pose": "attack2",
		"acc": 90,
		"dmg": [[4, 6], [5, 8], [7, 10]],
		"mark_damage": [0, 3, 5],
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
		"launch": [1, 2, 3, 4], "target": [1, 2, 3, 4], "target_side": "self", "pose": "skill",
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
		"self_move": [1, 1, 1],
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
	_test_legs_tier_stats()
	_test_lunge_mark_contract()
	_test_flourish_catalog()
	_test_cape_legs_text()
	_test_head_patch_text()
	_test_rapier_lunge_text()
	_test_negatives()
	_test_live_fixture()
	_test_live_stats()
	_test_live_tiers()
	_test_flourish_retreat()
	_test_flourish_blocked()
	_test_lunge_blocked()
	_test_riposte()
	_test_dodge()
	_test_cape_slip_rank_four()
	_test_status_ticks()
	_test_feint_followup_window()
	_test_snare_weak_reply()
	_test_lunge_mark_payoff()
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
			# The two named legs patches are the only exception to the tier-constant stat; their
			# full ladders are asserted independently in _test_legs_tier_stats.
			var expected_stat := _expected_stat(part_id, tier)
			_check(_int_dict(stat) == _int_dict(expected_stat),
				"AC1: " + tag + " keeps the slot-legal stat " + str(expected_stat))
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
			var mark_ladder: Array = spec.get("mark_damage", [0, 0, 0])
			_check(int(ability.get("mark_damage", -1)) == int(mark_ladder[tier - 1]),
				"AC1: " + tag + " mark_damage " + str(mark_ladder[tier - 1]))
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
				var last := int(previous_effects.get(key, 0))
				var now := int(effects[key])
				# Snare Weak and tier-II Feather Feint Exposed keep their authored plateaus; other effects grow.
				var snare_weak_plateau: bool = part_id == "rag_duelist_head_tattered_snare" \
					and str(key) == "weak" and tier == 3 and last == 2 and now == 2
				var feint_exposed_plateau: bool = part_id == "rag_duelist_head_feather_feint" \
					and str(key) == "exposed" and tier == 2 and last == 2 and now == 2
				_check(now > last or snare_weak_plateau or feint_exposed_plateau,
					"AC1: %s %s grows or preserves its authored tier-II/III plateau" % [part_id, str(key)])
			_check(dmg != previous_dmg or effects != previous_effects,
				"AC1: %s tier %d really overrides its own damage or effects" % [part_id, tier])
			previous_dmg = dmg
			previous_effects = effects


# ---------------------------------------------------------------- AC1: the two legs tier stat ladders

## Only the Cape Slip starter and the Cape Flourish alternative gain persistent Dodge at stitch
## tiers II and III: this asserts each complete per-tier stat dictionary by named id, that the
## raw authored file carries exactly those two new stat overrides beside the untouched ability
## overrides, and that the other six parts keep one tier-constant stat.
func _test_legs_tier_stats() -> void:
	var catalog := _catalog()
	_check(bool(catalog.get("ok", false)),
		"AC1: the catalog loads for the two legs tier-stat ladders")
	if not bool(catalog.get("ok", false)):
		return
	var slip_id := str(STARTER_PARTS["legs"])
	var flourish_id := str(ALTERNATE_PARTS["legs"])
	_check(slip_id == "rag_duelist_legs_cape_slip" and flourish_id == "rag_duelist_legs_cape_flourish",
		"AC1: the ladders name Cape Slip and Cape Flourish by id, never by list position")
	for part_id in TIER_STATS:
		var id := str(part_id)
		_check(catalog["by_id"].has(id), "AC1: the catalog authors the ladder part " + id)
		if not catalog["by_id"].has(id):
			continue
		var part: Dictionary = catalog["by_id"][id]
		var ladder: Array = TIER_STATS[id]
		_check(_int_dict(part["stat"]) == _int_dict(ladder[0]),
			"AC1: %s keeps its unchanged tier-I base stat %s" % [id, str(ladder[0])])
		for tier in [1, 2, 3]:
			var stat := StitchedParts.stat_at_tier(part, tier)
			_check(_int_dict(stat) == _int_dict(ladder[tier - 1]),
				"AC1: %s tier %d stat is exactly %s" % [id, tier, str(ladder[tier - 1])])
			for key in stat:
				_check(str(key) in StitchedParts.SLOT_STATS["legs"],
					"AC1: %s tier %d stat %s belongs in the legs slot" % [id, tier, str(key)])
	# Cape Slip's persistent Dodge climbs 6/8/10 with no other stat at any tier.
	var slip: Dictionary = catalog["by_id"][slip_id]
	for tier in [1, 2, 3]:
		var slip_stat := StitchedParts.stat_at_tier(slip, tier)
		_check(slip_stat.size() == 1 and int(slip_stat.get("dodge", -1)) == 6 + 2 * (tier - 1),
			"AC1: Cape Slip tier %d grants only Dodge %d" % [tier, 6 + 2 * (tier - 1)])
	# Cape Flourish inherits the base SPEED +1 unchanged while its Dodge climbs 5/7/9.
	var flourish: Dictionary = catalog["by_id"][flourish_id]
	for tier in [1, 2, 3]:
		var flourish_stat := StitchedParts.stat_at_tier(flourish, tier)
		_check(int(flourish_stat.get("speed", 0)) == 1,
			"AC1: Cape Flourish keeps exactly +1 SPEED at tier %d" % tier)
		_check(int(flourish_stat.get("dodge", -1)) == 5 + 2 * (tier - 1),
			"AC1: Cape Flourish tier %d grants Dodge %d" % [tier, 5 + 2 * (tier - 1)])
	# The raw authored file: only the two legs records put a stat dictionary in tiers II and III,
	# and their ability overrides are the ones they already had.
	var raw: Variant = _read_json(PARTS_PATH)
	var raw_by_id := {}
	if raw is Dictionary and raw.get("parts") is Array:
		for entry in raw["parts"]:
			if entry is Dictionary:
				raw_by_id[str(entry.get("id", ""))] = entry
	else:
		_check(false, "AC1: the parts file parses as a JSON object for the raw tier overrides")
	for part_id in ALL_PART_IDS:
		var entry: Dictionary = raw_by_id.get(part_id, {})
		_check(not entry.is_empty(), "AC1: the raw parts file still authors " + part_id)
		if entry.is_empty():
			continue
		var overrides: Dictionary = entry.get("tiers", {})
		var spec: Dictionary = EXPECTED[part_id]
		var expects_stat: bool = TIER_STATS.has(part_id)
		for tier_key in ["2", "3"]:
			var override: Dictionary = overrides.get(tier_key, {})
			_check(not override.is_empty(), "AC1: raw %s authors tier %s" % [part_id, tier_key])
			_check(override.has("stat") == expects_stat,
				"AC1: only the two legs patches author a raw tier-%s stat override: %s"
					% [tier_key, part_id])
			if not expects_stat:
				continue
			var expected: Dictionary = TIER_STATS[part_id][int(tier_key) - 1]
			var expected_dodge := int(expected.get("dodge", -1))
			var raw_stat: Dictionary = override.get("stat", {})
			_check(raw_stat.size() == 1 and _int_dict(raw_stat) == {"dodge": expected_dodge},
				"AC1: raw %s tier %s overrides only Dodge %d, never SPEED"
					% [part_id, tier_key, expected_dodge])
			var ability_override: Dictionary = override.get("ability", {})
			_check(override.size() == 2 and ability_override.size() == 1
				and ability_override.has("effects"),
				"AC1: raw %s tier %s keeps only its existing effects ability override"
					% [part_id, tier_key])
			_check(_int_dict(ability_override.get("effects", {}))
				== _int_dict(spec["effects"][int(tier_key) - 1]),
				"AC1: raw %s tier %s ability effects are unchanged" % [part_id, tier_key])
		_check(_int_dict(entry.get("stat", {})) == _int_dict(spec["stat"]),
			"AC1: raw %s keeps its unchanged base stat" % part_id)


## The expected stat for one part at one tier: the explicit legs ladders, or the tier-constant
## authored slot stat for the other six wearables.
func _expected_stat(part_id: String, tier: int) -> Dictionary:
	if TIER_STATS.has(part_id):
		var ladder: Array = TIER_STATS[part_id]
		var ladder_stat: Dictionary = ladder[tier - 1]
		return ladder_stat
	var spec: Dictionary = EXPECTED[part_id]
	var base_stat: Dictionary = spec["stat"]
	return base_stat


# ---------------------------------------------------------------- AC1: Rapier Lunge Mark payoff contract

## The named arms part is the only Rapier Lunge record and the only wearable in this kit with a
## Mark payoff: tiers II and III author mark_damage 3 and 5, tier I keeps the validated default 0,
## and its damage, ranks, ACC, arms stat, forward step and attack2 pose stay exactly as before.
func _test_lunge_mark_contract() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)):
		_check(false, "AC1: the shipped catalog loads for the Rapier Lunge Mark contract")
		return
	var lunge_id := str(STARTER_PARTS["arms"])
	_check(lunge_id == "rag_duelist_arms_rapier_lunge",
		"AC1: the starter arms part is the named Rapier Lunge")
	if not catalog["by_id"].has(lunge_id):
		_check(false, "AC1: the catalog authors the named Rapier Lunge arms part")
		return
	var part: Dictionary = catalog["by_id"][lunge_id]
	var damage_ladder := [[4, 6], [5, 8], [7, 10]]
	var mark_ladder := [0, 3, 5]
	_check(_int_dict(part["stat"]) == {"dmg": 1},
		"AC1: Rapier Lunge keeps its +1 arms damage stat at every tier")
	for tier in [1, 2, 3]:
		var ability := StitchedParts.ability_at_tier(part, tier)
		var tag := "Rapier Lunge tier %d" % tier
		_check(int(ability.get("mark_damage", -1)) == int(mark_ladder[tier - 1]),
			"AC1: " + tag + " resolves mark_damage " + str(mark_ladder[tier - 1]))
		_check(_int_list(ability["dmg"]) == _int_list(damage_ladder[tier - 1]),
			"AC1: " + tag + " keeps its authored damage range")
		_check(int(ability["acc"]) == 90 and _int_list(ability["launch"]) == [2, 3]
			and _int_list(ability["target"]) == [1, 2],
			"AC1: " + tag + " keeps ACC 90 and its rank 2-3 launch / rank 1-2 target masks")
		_check(int(ability["self_move"]) == -1 and str(ability["move"]) == "attack2",
			"AC1: " + tag + " keeps its one-rank forward step and attack2 pose")
		_check(_int_dict(ability["effects"]) == {} and not bool(ability["multi"])
			and int(ability["crit"]) == 0,
			"AC1: " + tag + " adds no on-hit effect, crit or multi-target")
	# The other seven wearables keep the validated default: no Mark payoff anywhere else.
	for part_id in ALL_PART_IDS:
		if str(part_id) == lunge_id:
			continue
		for tier in [1, 2, 3]:
			var ability := StitchedParts.ability_at_tier(catalog["by_id"][part_id], tier)
			_check(int(ability.get("mark_damage", -1)) == 0,
				"AC1: %s tier %d keeps the default mark_damage 0" % [str(part_id), tier])
	# The authored JSON puts the overrides only on the two upgraded tiers.
	var raw: Variant = _read_json(PARTS_PATH)
	var authored: Dictionary = {}
	if raw is Dictionary and raw.get("parts") is Array:
		for entry in raw["parts"]:
			if entry is Dictionary and str(entry.get("id", "")) == lunge_id:
				authored = entry
	if authored.is_empty() or not authored.get("ability") is Dictionary:
		_check(false, "AC1: the authored JSON still holds the Rapier Lunge entry")
		return
	_check(not authored["ability"].has("mark_damage"),
		"AC1: tier I authors no mark_damage override and keeps the validated default 0")
	var tiers: Dictionary = authored.get("tiers", {})
	_check(tiers.has("2") and tiers.has("3"),
		"AC1: Rapier Lunge authors both upgraded stitch tiers")
	if tiers.has("2") and tiers.has("3"):
		var tier_two: Dictionary = tiers["2"].get("ability", {})
		var tier_three: Dictionary = tiers["3"].get("ability", {})
		_check(int(tier_two.get("mark_damage", -1)) == 3,
			"AC1: the authored tier-II override carries mark_damage 3")
		_check(int(tier_three.get("mark_damage", -1)) == 5,
			"AC1: the authored tier-III override carries mark_damage 5")
		_check(int(tier_two.get("self_move", -99)) == -1
			and int(tier_three.get("self_move", -99)) == -1,
			"AC1: both upgrade tiers preserve the authored forward step")


# ---------------------------------------------------------------- AC1: Cape Flourish backward step

## The named alternative legs part is the only backward-moving wearable: its base +1 is inherited
## by every stitch tier while the starter Cape Slip stays stationary and weaker.
func _test_flourish_catalog() -> void:
	var catalog := StitchedParts.load_catalog(PARTS_PATH)
	_check(bool(catalog.get("ok", false)),
		"AC1: the shipped catalog loads for the Cape Flourish contract: " + str(catalog.get("error", "")))
	if not bool(catalog.get("ok", false)):
		return
	var by_id: Dictionary = catalog["by_id"]
	var flourish_id := str(ALTERNATE_PARTS["legs"])
	var slip_id := str(STARTER_PARTS["legs"])
	_check(flourish_id == "rag_duelist_legs_cape_flourish" and slip_id == "rag_duelist_legs_cape_slip",
		"AC1: the contract names Cape Flourish and Cape Slip by id, never by list position")
	_check(by_id.has(flourish_id), "AC1: the catalog authors the named Cape Flourish entry")
	_check(by_id.has(slip_id), "AC1: the catalog still authors the Cape Slip starter")
	if not by_id.has(flourish_id) or not by_id.has(slip_id):
		return
	var flourish: Dictionary = by_id[flourish_id]
	var slip: Dictionary = by_id[slip_id]
	_check(str(flourish["name"]) == "Cape Flourish" and str(flourish["slot"]) == "legs"
		and str(flourish["owner"]) == OWNER,
		"AC1: Cape Flourish keeps its name, legs slot and owner")
	_check(_int_dict(flourish["stat"]) == {"speed": 1, "dodge": 5},
		"AC1: Cape Flourish keeps its authored base stat")
	var flourish_dodge := [35, 40, 45]
	var expected_mask := StitchedParts.rank_mask([1, 2, 3])
	for tier in [1, 2, 3]:
		var ability := StitchedParts.ability_at_tier(flourish, tier)
		var tag := "Cape Flourish tier %d" % tier
		_check(not ability.is_empty(), "AC1: " + tag + " resolves through ability_at_tier")
		if ability.is_empty():
			continue
		_check(str(ability["id"]) == "rag_duelist_legs_cape_flourish_move",
			"AC1: " + tag + " keeps its ability id")
		_check(str(ability["move"]) == "skill", "AC1: " + tag + " keeps its authored skill pose")
		_check(_int_list(ability["launch"]) == [1, 2, 3],
			"AC1: " + tag + " keeps the authored launch ranks")
		_check(_int_list(ability["target"]) == [1, 2, 3],
			"AC1: " + tag + " keeps the authored target ranks")
		_check(int(ability["launch_mask"]) == expected_mask and int(ability["target_mask"]) == expected_mask,
			"AC1: " + tag + " keeps the authored launch and target masks")
		_check(not StitchedParts.ranks_allowed(int(ability["launch_mask"]), MAX_RANK),
			"AC1: " + tag + " cannot launch from rank 4")
		_check(int(ability["self_move"]) == 1 and int(ability["self_move"]) == int(EXPECTED[flourish_id]["self_move"][tier - 1]),
			"AC1: " + tag + " inherits the base one-rank backward step")
		_check(_int_dict(ability["effects"]) == {"dodge": flourish_dodge[tier - 1], "duration": 1},
			"AC1: " + tag + " keeps its one-turn temporary Dodge %d" % flourish_dodge[tier - 1])
	# Cape Slip is the stationary starter with its own weaker Dodge ladder. Its widened base ranks
	# let a displaced Duelist cast it from rank 4, with both derived masks covering exactly 1-4.
	var slip_dodge := [25, 30, 35]
	var slip_mask := StitchedParts.rank_mask([1, 2, 3, 4])
	_check(slip_mask == StitchedParts.ALL_RANKS_MASK,
		"AC1: the Cape Slip rank list derives one mask for all four hero ranks")
	for tier in [1, 2, 3]:
		var ability := StitchedParts.ability_at_tier(slip, tier)
		var tag := "Cape Slip tier %d" % tier
		_check(not ability.is_empty(), "AC1: " + tag + " resolves through ability_at_tier")
		if ability.is_empty():
			continue
		_check(int(ability.get("self_move", -99)) == 0,
			"AC1: " + tag + " still never moves its wearer")
		_check(_int_list(ability["launch"]) == [1, 2, 3, 4],
			"AC1: " + tag + " really launches from ranks 1-4")
		_check(_int_list(ability["target"]) == [1, 2, 3, 4],
			"AC1: " + tag + " really self-targets in ranks 1-4")
		var launch_mask := int(ability["launch_mask"])
		var target_mask := int(ability["target_mask"])
		_check(launch_mask == slip_mask and target_mask == slip_mask,
			"AC1: " + tag + " derives both rank masks from the authored 1-4 lists")
		for rank in range(MIN_RANK, MAX_RANK + 1):
			_check(StitchedParts.ranks_allowed(launch_mask, rank),
				"AC1: %s launches from rank %d" % [tag, rank])
			_check(StitchedParts.ranks_allowed(target_mask, rank),
				"AC1: %s targets rank %d" % [tag, rank])
		for rank in [0, MAX_RANK + 1]:
			_check(not StitchedParts.ranks_allowed(launch_mask, rank),
				"AC1: %s cannot launch from rank %d" % [tag, rank])
			_check(not StitchedParts.ranks_allowed(target_mask, rank),
				"AC1: %s cannot target rank %d" % [tag, rank])
		_check(_int_dict(ability["effects"]) == {"dodge": slip_dodge[tier - 1], "duration": 1},
			"AC1: " + tag + " keeps its authored one-turn Dodge %d" % slip_dodge[tier - 1])
	# No other wearable in this hero kit gained a backward step from this change.
	var backward := 0
	for part_id in by_id:
		var ability := StitchedParts.ability_at_tier(by_id[part_id], 1)
		var self_move := int(ability.get("self_move", 0))
		if str(part_id) == flourish_id:
			continue
		_check(self_move <= 0, "AC1: only Cape Flourish steps backward: " + str(part_id))
		if self_move == 1:
			backward += 1
	_check(backward == 0, "AC1: no other Rag Duelist part authors a backward self move")
	_check(int(StitchedParts.ability_at_tier(by_id[flourish_id], 1).get("self_move", 0)) == 1,
		"AC1: Cape Flourish is the single backward-moving part in this kit")


# ---------------------------------------------------------------- AC1/AC2: the two cape-leg texts

## S14 keeps the S4 part records as worn limbs and S13 sewn-patch identities while the hero fights
## with its fixed signature kit, so the two player-readable cape-leg descriptions are sewn-fabric
## copy only: no rank, tier, Dodge, movement, turn count, target, status or numeric combat promise.
## Both named records are checked against the authored sentences, their identity fields and the
## hero's crimson/black/gold palette, using whole words (never accidental substrings) for the
## forbidden combat vocabulary.
func _test_cape_legs_text() -> void:
	var catalog := StitchedParts.load_catalog(PARTS_PATH)
	_check(bool(catalog.get("ok", false)),
		"AC1: the complete shipped catalog loads for the cape-leg text check: "
			+ str(catalog.get("error", "")))
	if not bool(catalog.get("ok", false)):
		return
	var by_id: Dictionary = catalog["by_id"]
	for part_id in CAPE_LEG_TEXT:
		var id := str(part_id)
		var sentence := str(CAPE_LEG_TEXT[id])
		_check(by_id.has(id), "AC1: the catalog authors the named cape-leg record " + id)
		if not by_id.has(id):
			continue
		var part: Dictionary = by_id[id]
		var spec: Dictionary = EXPECTED[id]
		_check(bool(StitchedParts.validate_part(part).get("ok", false)),
			"AC3: validate_part accepts the shipped " + id)
		_check(str(part.get("id", "")) == id, "AC1: " + id + " keeps its authored id")
		_check(str(part.get("name", "")) == str(spec["name"]),
			"AC1: " + id + " keeps its authored name " + str(spec["name"]))
		_check(str(part.get("owner", "")) == OWNER, "AC1: " + id + " stays owned by the rag_duelist")
		_check(str(part.get("slot", "")) == "legs", "AC1: " + id + " stays a legs patch")
		var text := str(part.get("text", ""))
		_check(text == sentence, "AC1: " + id + " carries its authored sewn-fabric sentence: " + text)
		var words := _whole_words(text)
		# Visible cape cloth and stitching: a cape and a boot, plus cloth-and-stitch or thread.
		for word in ["cape", "boot"]:
			_check(word in words, "AC2: " + id + " names the visible " + word + ": " + text)
		var stitched_cloth: bool = "cloth" in words \
			and ("stitch" in words or "stitches" in words)
		_check(stitched_cloth or "thread" in words,
			"AC2: " + id + " names the sewn cloth or thread that holds the patch: " + text)
		_check("sewn" in words or "patched" in words,
			"AC2: " + id + " says the patch is sewn on rather than granted: " + text)
		for colour in ["crimson", "black", "gold"]:
			_check(colour in words, "AC2: " + id + " keeps the hero palette word " + colour + ": " + text)
		for word in CAPE_LEG_FORBIDDEN_WORDS:
			_check(not str(word) in words,
				"AC2: " + id + " promises no combat term " + str(word) + ": " + text)
		for digit in range(10):
			_check(not text.contains(str(digit)),
				"AC2: " + id + " states no number " + str(digit) + ": " + text)
		_check(text.find("rank") < 0 and text.find("1-4") < 0 and text.find("1-3") < 0,
			"AC2: " + id + " no longer advertises a rank or rank band: " + text)
		# The same record cloned in memory with its text emptied still fails closed.
		var blank := part.duplicate(true)
		blank["text"] = ""
		_check(not bool(StitchedParts.validate_part(blank).get("ok", false)),
			"AC3: " + id + " with empty text is refused")
		var whitespace := part.duplicate(true)
		whitespace["text"] = "   "
		_check(not bool(StitchedParts.validate_part(whitespace).get("ok", false)),
			"AC3: " + id + " with whitespace-only text is refused")


# ---------------------------------------------------------------- AC1/AC2: the two head-patch texts

## S14 retires the two head parts' combat role while S13 keeps them as sewn patches, so both
## player-readable head descriptions are sewn-fabric copy only: no rank, tier, Exposed, Mark,
## Tangled, Weak, damage, hit or other combat promise, and no number. Each named record is checked
## against its authored sentence, its identity fields and the visible cloth it names, using whole
## words (never accidental substrings) for the forbidden combat vocabulary.
func _test_head_patch_text() -> void:
	var catalog := _catalog()
	_check(bool(catalog.get("ok", false)),
		"AC1: the shipped catalog loads for the two head-patch text checks")
	if not bool(catalog.get("ok", false)):
		return
	var by_id: Dictionary = catalog["by_id"]
	for part_id in HEAD_PATCH_TEXT:
		var id := str(part_id)
		var sentence := str(HEAD_PATCH_TEXT[id])
		_check(by_id.has(id), "AC1: the catalog authors the named head-patch record " + id)
		if not by_id.has(id):
			continue
		var part: Dictionary = by_id[id]
		var spec: Dictionary = EXPECTED[id]
		_check(bool(StitchedParts.validate_part(part).get("ok", false)),
			"AC3: validate_part accepts the shipped " + id)
		_check(str(part.get("id", "")) == id, "AC1: " + id + " keeps its authored id")
		_check(str(part.get("name", "")) == str(spec["name"]),
			"AC1: " + id + " keeps its authored name " + str(spec["name"]))
		_check(str(part.get("owner", "")) == OWNER, "AC1: " + id + " stays owned by the rag_duelist")
		_check(str(part.get("slot", "")) == "head", "AC1: " + id + " stays a head patch")
		_check(_int_dict(part["stat"]) == _int_dict(spec["stat"]),
			"AC3: " + id + " keeps its legacy tier-I slot stat " + str(spec["stat"]))
		_check(str(part["ability"]["id"]) == str(spec["ability_id"]),
			"AC3: " + id + " keeps its legacy ability " + str(spec["ability_id"]))
		_check(part["tiers"].has("2") and part["tiers"].has("3"),
			"AC3: " + id + " keeps its legacy tiers II and III overrides")
		var text := str(part.get("text", ""))
		_check(text == sentence, "AC1: " + id + " carries its authored sewn-cloth sentence: " + text)
		var words := _whole_words(text)
		for word in HEAD_PATCH_WORDS[id]:
			_check(str(word) in words,
				"AC2: " + id + " names the visible sewn cloth " + str(word) + ": " + text)
		for word in HEAD_PATCH_FORBIDDEN_WORDS:
			_check(not str(word) in words,
				"AC2: " + id + " promises no combat term " + str(word) + ": " + text)
		for digit in range(10):
			_check(not text.contains(str(digit)),
				"AC2: " + id + " states no number " + str(digit) + ": " + text)
		# The same record cloned in memory with its text emptied still fails closed.
		for bad_text in ["", "   "]:
			var blank := part.duplicate(true)
			blank["text"] = bad_text
			_check(not bool(StitchedParts.validate_part(blank).get("ok", false)),
				"AC3: " + id + " with blank text is refused: " + text)
	# Neither head description may be reused by—or leak onto—the other six wearables.
	for other_id in ALL_PART_IDS:
		if HEAD_PATCH_TEXT.has(other_id):
			continue
		var other_text := str(by_id[other_id].get("text", ""))
		for head_id in HEAD_PATCH_TEXT:
			_check(other_text != str(HEAD_PATCH_TEXT[head_id]),
				"AC3: the head description stays on " + str(head_id) + ", never on " + str(other_id))


# ---------------------------------------------------------------- AC1: Rapier Lunge rules text

## The upgraded Rapier Lunge copy must name the Mark payoff, say it arrives with the stitch tiers,
## and keep describing its one-rank forward step. It must not adopt another part's effect.
func _test_rapier_lunge_text() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)):
		_check(false, "AC1: the shipped catalog loads for the Rapier Lunge text check")
		return
	var lunge_id := str(STARTER_PARTS["arms"])
	if not catalog["by_id"].has(lunge_id):
		_check(false, "AC1: the Rapier Lunge text check needs the starter arms part")
		return
	var text := str(catalog["by_id"][lunge_id].get("text", "")).strip_edges()
	_check(not text.is_empty(), "AC1: Rapier Lunge carries rules text")
	var lower := text.to_lower()
	_check(lower.contains("mark"), "AC1: Rapier Lunge text names the Mark it exploits: " + text)
	_check(lower.contains(" ii") and lower.contains(" iii"),
		"AC1: Rapier Lunge text names the upgrading stitch tiers II and III: " + text)
	_check(lower.contains("bite") or lower.contains("harder"),
		"AC1: Rapier Lunge text says upgraded Lunge bites harder against Mark: " + text)
	_check(lower.contains("step") or lower.contains("forward"),
		"AC1: Rapier Lunge text still describes its one-rank forward step: " + text)
	_check(not lower.contains("exposed") and not lower.contains("tangled")
		and not lower.contains("bleed") and not lower.contains("weak"),
		"AC1: Rapier Lunge text never claims another part's status: " + text)


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
			# S13: matching patch threads add their small hidden bonus on top of the parts.
			var hidden := StitchedSewnPatches.hidden_bonus("rag_duelist", hero["parts"], hero.get("patch_wear", {}))
			for key in hidden:
				totals[str(key)] = int(totals[str(key)]) + int(hidden[key])
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
	# AC2: independent real-actor witness for the two legs patches. The living Duelist's persistent
	# Dodge must be the fixture base 4 plus the explicit ladder value plus only the S13 hidden
	# bonus, so a tier override that never reaches the battle cannot pass this check.
	for part_id in TIER_STATS:
		var legs_id := str(part_id)
		for tier in [1, 2, 3]:
			var tag := "worn %s tier %d" % [legs_id, tier]
			var battle := _build_battle(11, tier, _kit_for(legs_id), 0, false)
			if battle == null:
				_check(false, "AC2: the shipped preview builds with the " + tag)
				continue
			var hero := battle.get_unit(OWNER)
			_check(str(hero["parts"]["legs"]["id"]) == legs_id
				and int(hero["parts"]["legs"]["tier"]) == tier,
				"AC2: the live Duelist really wears the " + tag)
			var hidden := StitchedSewnPatches.hidden_bonus(
				OWNER, hero["parts"], hero.get("patch_wear", {}))
			var ladder_stat: Dictionary = TIER_STATS[legs_id][tier - 1]
			var expected_dodge := DUELIST_DODGE + int(ladder_stat.get("dodge", 0)) \
				+ int(hidden.get("dodge", 0))
			_check(int(hero["dodge"]) == expected_dodge,
				"AC2: " + tag + " reaches exactly live DODGE %d" % expected_dodge)
			var expected_speed := DUELIST_SPEED + int(ladder_stat.get("speed", 0)) \
				+ int(hidden.get("speed", 0))
			_check(int(hero["speed"]) == expected_speed,
				"AC2: " + tag + " reaches exactly live SPEED %d" % expected_speed)
			_check(int(hero["dodge"]) == DUELIST_DODGE
				+ int(StitchedParts.stat_at_tier(_catalog()["by_id"][legs_id], tier).get("dodge", 0))
				+ int(hidden.get("dodge", 0)),
				"AC2: " + tag + " live DODGE matches the resolved tier stat and only the hidden bonus")


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


# ---------------------------------------------------------------- AC2: a real backward dodge step

## A worn Cape Flourish is cast on the Duelist's own rank on three genuine scheduled turns of one
## in-memory S2 fixture: rank 1 to 2, then 2 to 3, then 3 to 4, each with a real adjacent swap.
func _test_flourish_retreat() -> void:
	var flourish_id := str(ALTERNATE_PARTS["legs"])
	var companions := ["seamstress", "tinker", "lantern_monk"]
	var flourish_dodge := [35, 40, 45]
	for tier in [1, 2, 3]:
		var battle := _build_battle(31, tier, _kit_for(flourish_id), 0, false)
		if battle == null:
			_check(false, "AC2: the four-hero/three-foe fixture builds with Cape Flourish at tier %d" % tier)
			continue
		_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 3,
			"AC2: the Cape Flourish fixture keeps four heroes and three foes at tier %d" % tier)
		_check(str(battle.get_unit(OWNER)["parts"]["legs"]["id"]) == flourish_id,
			"AC2: the Duelist wears Cape Flourish in its legs slot at tier %d" % tier)
		for step in range(3):
			var from_rank := step + 1
			var ally := str(companions[step])
			var tag := "Cape Flourish tier %d rank %d" % [tier, from_rank]
			if not _to(battle, OWNER):
				_check(false, "AC2: " + tag + " reaches a genuine scheduled Duelist turn")
				break
			_check(int(battle.get_unit(OWNER)["rank"]) == from_rank,
				"AC2: " + tag + " really starts the Duelist at that rank")
			_check(int(battle.get_unit(ally)["rank"]) == from_rank + 1,
				"AC2: " + tag + " has the authored adjacent ally behind the Duelist")
			var receipt := battle.use_part(flourish_id, from_rank)
			_check(bool(receipt.get("ok", false)),
				"AC2: " + tag + " casts on the Duelist's own rank: " + str(receipt.get("error", "")))
			if not bool(receipt.get("ok", false)):
				break
			_check(str(receipt.get("part", "")) == flourish_id,
				"AC2: " + tag + " reports the equipped Cape Flourish")
			_check(str(receipt.get("ability", "")) == "rag_duelist_legs_cape_flourish_move",
				"AC2: " + tag + " resolves the authored ability id")
			_check(str(receipt.get("actor", "")) == OWNER,
				"AC2: " + tag + " is used by the Rag Duelist")
			var move: Dictionary = receipt.get("self_move", {})
			_check(bool(move.get("ok", false)), "AC2: " + tag + " resolves its one-rank backward step")
			_check(int(move.get("from", 0)) == from_rank and int(move.get("to", 0)) == from_rank + 1,
				"AC2: " + tag + " steps exactly one rank backward")
			_check(str(move.get("swapped", "")) == ally,
				"AC2: " + tag + " swaps with the adjacent ally behind it")
			_check(int(battle.get_unit(OWNER)["rank"]) == from_rank + 1
				and int(battle.get_unit(ally)["rank"]) == from_rank,
				"AC2: " + tag + " really moves both heroes on the board")
			var duelist := battle.get_unit(OWNER)
			var buff: Dictionary = duelist.get("dodge_buff", {})
			_check(int(buff.get("amount", 0)) == flourish_dodge[tier - 1],
				"AC2: " + tag + " stores its temporary Dodge %d" % flourish_dodge[tier - 1])
			_check(int(buff.get("turns", 0)) == 1,
				"AC2: " + tag + " grants one turn of temporary Dodge")
			_check(_status_value(receipt["results"][0].get("statuses", []), "dodge") == flourish_dodge[tier - 1],
				"AC2: " + tag + " reports the granted Dodge")
		# The rank-4 Duelist is one step past the authored launch mask.
		if not _to(battle, OWNER):
			_check(false, "AC3: the rank-4 Duelist still reaches a genuine scheduled turn at tier %d" % tier)
			continue
		_check(int(battle.get_unit(OWNER)["rank"]) == MAX_RANK,
			"AC3: the back-stepping Duelist ends at rank 4 at tier %d" % tier)
		var before := battle.state_snapshot()
		var rng := battle.rng_state()
		var buff_before: Dictionary = battle.get_unit(OWNER).get("dodge_buff", {}).duplicate(true)
		var refused := battle.use_part(flourish_id, MAX_RANK)
		_check(not bool(refused.get("ok", false))
			and str(refused.get("error", "")).contains("cannot launch from rank 4"),
			"AC3: Cape Flourish refuses to launch from rank 4 at tier %d" % tier)
		_check(before == battle.state_snapshot() and rng == battle.rng_state(),
			"AC3: the rank-4 refusal preserved state, turn pointer and RNG")
		_check(battle.current_actor_id() == OWNER,
			"AC3: the rank-4 refusal never spends the Duelist's turn")
		_check(battle.get_unit(OWNER).get("dodge_buff", {}) == buff_before,
			"AC3: the rank-4 refusal applies no new temporary Dodge")


# ---------------------------------------------------------------- AC3: blocked backward step is atomic

## Every current preflight reason refuses the Cape Flourish step before its Dodge, movement,
## turn or RNG, at each authored launch rank.
func _test_flourish_blocked() -> void:
	var flourish_id := str(ALTERNATE_PARTS["legs"])
	var companions := ["seamstress", "tinker", "lantern_monk"]
	var block_kinds := ["tangled wearer", "tangled ally", "snipped wearer thread", "snipped ally thread"]
	for rank in [MIN_RANK, 2, 3]:
		var ally := str(companions[rank - 1])
		for kind in block_kinds:
			var tag := "rank %d %s" % [rank, kind]
			var battle := _build_battle(43 + rank, 2, _kit_for(flourish_id), rank - 1, false)
			if battle == null:
				_check(false, "AC3: the Cape Flourish fixture builds for the " + tag)
				continue
			if not _to(battle, OWNER):
				_check(false, "AC3: the Duelist reaches its genuine scheduled turn for the " + tag)
				continue
			_check(int(battle.get_unit(OWNER)["rank"]) == rank
				and int(battle.get_unit(ally)["rank"]) == rank + 1,
				"AC3: the " + tag + " fixture really places the wearer and the destination ally")
			match kind:
				"tangled wearer":
					battle._units[OWNER]["statuses"]["tangled"] = 1
				"tangled ally":
					battle._units[ally]["statuses"]["tangled"] = 1
				"snipped wearer thread":
					battle._thread_cuts[OWNER] = rank
				"snipped ally thread":
					battle._thread_cuts[ally] = rank
			var before := battle.state_snapshot()
			var rng := battle.rng_state()
			var refused := battle.use_part(flourish_id, rank)
			_check(not bool(refused.get("ok", false))
				and str(refused.get("error", "")).contains("self move is blocked"),
				"AC3: a " + tag + " refuses the mandatory backward step")
			_check(before == battle.state_snapshot() and rng == battle.rng_state(),
				"AC3: the " + tag + " refusal preserved state, turn pointer and RNG")
			_check(battle.current_actor_id() == OWNER,
				"AC3: the " + tag + " refusal never spends the turn")
			var duelist := battle.get_unit(OWNER)
			_check(int(duelist.get("dodge_buff", {}).get("amount", 0)) == 0,
				"AC3: the " + tag + " refusal grants no temporary Dodge")
			_check(int(duelist["rank"]) == rank and int(battle.get_unit(ally)["rank"]) == rank + 1,
				"AC3: the " + tag + " refusal moves nobody")


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


# ---------------------------------------------------------------- AC2/AC3: Cape Slip from rank 4

## A worn Cape Slip is cast on the Duelist's genuine scheduled rank-4 turn at each stitch tier.
## The shipped fixture keeps its four heroes and three foes; a real Moth Scribe then aims at rank 4,
## and the temporary Dodge expires only after the Duelist's own following completed turn.
func _test_cape_slip_rank_four() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)):
		_check(false, "AC2: the shipped catalog loads for the rank-4 Cape Slip witness")
		return
	var slip_id := str(STARTER_PARTS["legs"])
	var slip_dodge := [25, 30, 35]
	for tier in [1, 2, 3]:
		var seed_value: int = 41 + int(tier)
		var tag := "Cape Slip tier %d rank %d" % [tier, MAX_RANK]
		var battle := _build_battle(seed_value, tier, STARTER_PARTS, MAX_RANK - 1, false)
		if battle == null:
			_check(false, "AC2: the four-hero/three-foe fixture builds for " + tag)
			continue
		_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 3,
			"AC2: " + tag + " keeps four heroes and three foes")
		_check(str(battle.get_unit(OWNER)["parts"]["legs"]["id"]) == slip_id,
			"AC2: the rank-4 Duelist really wears the starter Cape Slip")
		if not _to(battle, OWNER):
			_check(false, "AC2: " + tag + " reaches a genuine scheduled Duelist turn")
			continue
		_check(int(battle.get_unit(OWNER)["rank"]) == MAX_RANK,
			"AC2: " + tag + " really starts with the living Duelist at rank 4")
		var ability := StitchedParts.ability_at_tier(catalog["by_id"][slip_id], tier)
		_check(int(ability.get("self_move", -99)) == 0,
			"AC2: " + tag + " keeps its authored zero self move")
		_check(StitchedParts.ranks_allowed(int(ability["launch_mask"]), MAX_RANK)
			and StitchedParts.ranks_allowed(int(ability["target_mask"]), MAX_RANK),
			"AC2: " + tag + " derives launch AND target legality from rank 4")
		_check(not StitchedParts.ranks_allowed(int(ability["launch_mask"]), 0)
			and not StitchedParts.ranks_allowed(int(ability["target_mask"]), 0)
			and not StitchedParts.ranks_allowed(int(ability["launch_mask"]), MAX_RANK + 1)
			and not StitchedParts.ranks_allowed(int(ability["target_mask"]), MAX_RANK + 1),
			"AC2: " + tag + " refuses ranks outside 1-4")
		var permanent := int(battle.get_unit(OWNER)["dodge"])
		var heroes_before := {}
		for hero_id in RANK_FOUR_COMPANIONS:
			heroes_before[hero_id] = battle.get_unit(hero_id)
		# A self-only buff refuses every rank but the caster's own, before any mutation.
		var before := battle.state_snapshot()
		var rng := battle.rng_state()
		for bad_rank in [MIN_RANK, MAX_RANK - 1, 0, MAX_RANK + 1]:
			var refused := battle.use_part(slip_id, bad_rank)
			_check(not bool(refused.get("ok", false))
				and str(refused.get("error", "")).contains("no legal target in rank %d" % bad_rank),
				"AC2: %s refuses self-target rank %d" % [tag, bad_rank])
		_check(before == battle.state_snapshot() and rng == battle.rng_state(),
			"AC2: " + tag + " refusals preserved state, turn pointer and RNG")
		_check(battle.current_actor_id() == OWNER,
			"AC2: " + tag + " refusals never spend the Duelist's action")
		var receipt := battle.use_part(slip_id, MAX_RANK)
		_check(bool(receipt.get("ok", false)),
			"AC2: " + tag + " really casts from rank 4: " + str(receipt.get("error", "")))
		if not bool(receipt.get("ok", false)):
			continue
		var snapshot_after_cast := battle.state_snapshot()
		_check(str(receipt.get("part", "")) == slip_id, "AC2: " + tag + " reports the equipped part")
		_check(str(receipt.get("ability", "")) == "rag_duelist_legs_cape_slip_move",
			"AC2: " + tag + " resolves the authored ability id")
		_check(str(receipt.get("actor", "")) == OWNER, "AC2: " + tag + " is used by the Rag Duelist")
		var results: Array = receipt.get("results", [])
		_check(results.size() == 1, "AC2: " + tag + " produces one self-ally receipt")
		if results.size() == 1:
			var result: Dictionary = results[0]
			_check(str(result.get("target", "")) == OWNER and str(result.get("target_side", "")) == "hero"
				and int(result.get("target_rank", 0)) == MAX_RANK,
				"AC2: " + tag + " targets the Duelist in his own rank 4")
			_check(bool(result.get("hit", false)) and int(result.get("damage", -1)) == 0,
				"AC2: " + tag + " is a confirmed non-damaging self buff")
			_check(_status_value(result.get("statuses", []), "dodge") == slip_dodge[tier - 1],
				"AC2: " + tag + " reports its temporary Dodge")
			_check(int(result.get("target_hp", -1)) == int(battle.get_unit(OWNER)["hp"]),
				"AC2: " + tag + " leaves the Duelist's HP untouched")
		var duelist := battle.get_unit(OWNER)
		_check(int(duelist["rank"]) == MAX_RANK, "AC2: " + tag + " leaves the Duelist in rank 4")
		_check(int(duelist["dodge"]) == permanent, "AC2: " + tag + " never raises permanent Dodge")
		_check(not duelist["statuses"].has("dodge"), "AC2: " + tag + " invents no fake dodge status")
		var buff: Dictionary = duelist.get("dodge_buff", {})
		_check(int(buff.get("amount", 0)) == slip_dodge[tier - 1],
			"AC2: " + tag + " stores temporary Dodge %d" % slip_dodge[tier - 1])
		_check(int(buff.get("turns", 0)) == 1, "AC2: " + tag + " stores a one-turn duration")
		_check(battle.current_actor_id() != OWNER, "AC2: " + tag + " consumes the Duelist's one action")
		for hero_id in RANK_FOUR_COMPANIONS:
			_check(battle.get_unit(hero_id) == heroes_before[hero_id],
				"AC2: " + tag + " leaves " + hero_id + " unchanged")
		# A real preview foe (Moth Scribe) can aim at rank 4; its chance must include the buff.
		_check(_to(battle, MOTH_SCRIBE), "AC3: " + tag + " reaches a genuine Moth Scribe turn")
		var foe := battle.get_unit(MOTH_SCRIBE)
		var foe_acc := int(foe["acc"]) + int(battle.candle_band()["enemy_acc"])
		var miss_streak := int(foe["miss_streak"])
		var attack := battle.use_foe_ability("ink_flick", MAX_RANK)
		_check(bool(attack.get("ok", false)),
			"AC3: " + tag + " lets the foe attack the rank-4 Duelist: " + str(attack.get("error", "")))
		if bool(attack.get("ok", false)) and not attack.get("results", []).is_empty():
			var attack_result: Dictionary = attack["results"][0]
			var expected := StitchedRules.hit_chance(
				INK_FLICK_ACC + foe_acc, permanent + slip_dodge[tier - 1], miss_streak)
			_check(str(attack_result.get("target", "")) == OWNER,
				"AC3: " + tag + " foe attack really aims at the Duelist")
			_check(int(attack_result.get("hit_chance", -1)) == expected,
				"AC3: " + tag + " foe hit chance includes exactly the temporary Dodge")
			_check(expected < StitchedRules.hit_chance(INK_FLICK_ACC + foe_acc, permanent, miss_streak),
				"AC3: " + tag + " temporary Dodge lowers the chance without guaranteeing a miss")
			_check(int(battle.get_unit(OWNER)["dodge"]) == permanent,
				"AC3: " + tag + " foe attack leaves permanent Dodge unchanged")
		# The buff survives that foe turn and expires after the Duelist's own next turn.
		_check(_to(battle, OWNER), "AC3: " + tag + " reaches the Duelist's following real turn")
		_check(int(StitchedRules.effective_dodge(battle.get_unit(OWNER))) == permanent + slip_dodge[tier - 1],
			"AC3: " + tag + " keeps its temporary Dodge through the foe turn")
		_check(bool(battle.pass_turn().get("ok", false)), "AC3: " + tag + " Duelist spends that next turn")
		_check(int(StitchedRules.effective_dodge(battle.get_unit(OWNER))) == permanent,
			"AC3: " + tag + " temporary Dodge expires after the Duelist's own turn")
		# An equal-seed replay casts identically, so the widened ranks add no hidden randomness.
		var replay := _build_battle(seed_value, tier, STARTER_PARTS, MAX_RANK - 1, false)
		if replay == null or not _to(replay, OWNER):
			_check(false, "AC4: " + tag + " replays on a second equal-seed fixture")
			continue
		var replay_receipt := replay.use_part(slip_id, MAX_RANK)
		_check(replay_receipt == receipt and replay.state_snapshot() == snapshot_after_cast,
			"AC4: " + tag + " replays its receipt, state and RNG exactly")


## AC2: exercise the real foe reply, not just the countdown icon. Two battles run the
## same seeded actions; only the control fixture's Weak status is erased after the foe's
## start-of-turn tick. This isolates Weak's actual damage reduction without changing rules.
func _test_snare_weak_reply() -> void:
	var snare_id := str(ALTERNATE_PARTS["head"])
	var witnessed := false
	for seed_value in range(1, 120):
		var kit := _kit_for(snare_id)
		var weakened := _build_battle(seed_value, 2, kit, 0, false)
		var control := _build_battle(seed_value, 2, kit, 0, false)
		if weakened == null or control == null:
			continue
		var initial_foe := weakened.get_unit(FRAY_SCAVENGER)
		if weakened.current_actor_id() != OWNER or control.current_actor_id() != OWNER \
				or initial_foe.is_empty() or int(initial_foe.get("hp", 0)) <= 0 \
				or int(initial_foe.get("rank", 0)) != 1:
			continue
		var cast := weakened.use_part(snare_id, 1)
		var control_cast := control.use_part(snare_id, 1)
		if not bool(cast.get("ok", false)) or cast.get("results", []).is_empty() \
				or cast != control_cast or weakened.state_snapshot() != control.state_snapshot():
			continue
		var snare_hit: Dictionary = cast["results"][0]
		if not bool(snare_hit.get("hit", false)) \
				or str(snare_hit.get("target", "")) != FRAY_SCAVENGER:
			continue
		var landed_foe := weakened.get_unit(FRAY_SCAVENGER)
		if int(landed_foe["statuses"].get("weak", 0)) != 2 \
				or int(landed_foe["statuses"].get("tangled", 0)) != 3:
			continue
		if not _to(weakened, FRAY_SCAVENGER) or not _to(control, FRAY_SCAVENGER):
			continue
		var foe := weakened.get_unit(FRAY_SCAVENGER)
		if int(foe.get("hp", 0)) <= 0 or int(foe.get("rank", 0)) != 1 \
				or int(foe["statuses"].get("weak", 0)) != 1:
			continue
		# The two fixtures are identical before the control-only status removal.
		if weakened.state_snapshot() != control.state_snapshot():
			continue
		var rng_before := weakened.rng_state()
		var expected_without_weak := weakened.state_snapshot()
		for unit in expected_without_weak["units"]:
			if str(unit["id"]) == FRAY_SCAVENGER:
				unit["statuses"].erase("weak")
		# This is the ONLY fixture mutation: no target, roll, stats, or turn is altered.
		var control_statuses: Dictionary = control._units[FRAY_SCAVENGER]["statuses"]
		control_statuses.erase("weak")
		var only_weak_differs := control.state_snapshot() == expected_without_weak
		var control_rng_before := control.rng_state()
		if not only_weak_differs or control_rng_before != rng_before:
			continue
		var weak_reply := weakened.use_foe_ability("sack_swing", 1)
		var plain_reply := control.use_foe_ability("sack_swing", 1)
		if not bool(weak_reply.get("ok", false)) or not bool(plain_reply.get("ok", false)) \
				or weak_reply.get("results", []).is_empty() or plain_reply.get("results", []).is_empty():
			continue
		var weak_hit: Dictionary = weak_reply["results"][0]
		var plain_hit: Dictionary = plain_reply["results"][0]
		if not bool(weak_hit.get("hit", false)) or not bool(plain_hit.get("hit", false)) \
				or str(weak_hit.get("target", "")) != OWNER \
				or str(plain_hit.get("target", "")) != OWNER:
			continue
		witnessed = true
		_check(str(cast.get("actor", "")) == OWNER and str(cast.get("part", "")) == snare_id,
			"AC2: a real equipped tier-II Snare was cast by the living Duelist")
		_check(int(snare_hit.get("damage", -1)) == 0 and int(landed_foe["hp"]) == int(initial_foe["hp"]),
			"AC2: the landed Snare does not directly damage the living rank-1 foe")
		_check(int(landed_foe["statuses"].get("weak", 0)) == 2 \
			and int(landed_foe["statuses"].get("tangled", 0)) == 3,
			"AC2: the tier-II hit really lands Weak 2 and Tangled 3")
		_check(int(foe["statuses"].get("weak", 0)) == 1 and weakened.current_actor_id() != FRAY_SCAVENGER,
			"AC2: Weak 1 survived the foe's real turn start and the foe used its turn")
		_check(only_weak_differs and rng_before == control_rng_before,
			"AC2: the seeded control differed only by removal of Weak, not state or RNG")
		_check(str(weak_reply.get("actor", "")) == FRAY_SCAVENGER \
			and str(plain_reply.get("actor", "")) == FRAY_SCAVENGER \
			and str(weak_reply.get("ability", "")) == "sack_swing" \
			and str(plain_reply.get("ability", "")) == "sack_swing",
			"AC2: the legally scheduled living foe uses the same real Sack Swing in both runs")
		_check(int(weak_hit.get("damage", 0)) > 0 \
			and int(weak_hit.get("damage", 0)) < int(plain_hit.get("damage", 0)),
			"AC2: landed Weak reduces real Sack Swing damage against the seeded control")
		_check(weakened.rng_state() == control.rng_state(),
			"AC2: both same-seed foe attacks consume identical RNG")
		var next_turn := _to(weakened, FRAY_SCAVENGER)
		_check(next_turn, "AC2: the Snared foe reaches its following real turn without reapplication")
		if next_turn:
			var expired := weakened.get_unit(FRAY_SCAVENGER)
			_check(int(expired.get("hp", 0)) > 0 and int(expired["statuses"].get("weak", 0)) == 0 \
				and not expired["statuses"].has("weak"),
				"AC2: Weak expires at the following foe turn, without a new Snare")
		break
	_check(witnessed, "AC2: a bounded same-seed live Snare/Sack Swing pair must land and expose Weak's damage reduction")


# ---------------------------------------------------------------- AC2: statuses tick in play

func _test_status_ticks() -> void:
	var snare_id := "rag_duelist_head_tattered_snare"
	## Authored tier ladder: Tangled rises each tier, Weak only appears from tier II.
	var snare_ladder := [
		{"landed": {"tangled": 2, "weak": 0}, "after": {"tangled": 1, "weak": 0}},
		{"landed": {"tangled": 3, "weak": 2}, "after": {"tangled": 2, "weak": 1}},
		{"landed": {"tangled": 4, "weak": 2}, "after": {"tangled": 3, "weak": 1}},
	]
	for tier in [1, 2, 3]:
		var expected: Dictionary = snare_ladder[tier - 1]
		var landed: Dictionary = expected["landed"]
		var after: Dictionary = expected["after"]
		var tag := "Tattered Snare tier %d" % tier
		var snare := _cast_witness(snare_id, tier, 0, 1, true)
		if snare.is_empty():
			_check(false, "AC2: a fixed seed lands " + tag + " for the expiry witness")
			continue
		var battle: StitchedRules = snare["battle"]
		var result: Dictionary = snare["receipt"]["results"][0]
		var foe_id := str(result["target"])
		var foe := battle.get_unit(foe_id)
		_check(int(result.get("damage", -1)) == 0,
			"AC2: " + tag + " is a zero-damage debuff")
		_check(int(foe["hp"]) == int(snare["foe_hp_before"].get(foe_id, -1)),
			"AC2: " + tag + " leaves the landed foe's HP untouched")
		_check(int(foe["statuses"].get("tangled", 0)) == int(landed["tangled"]),
			"AC2: " + tag + " leaves a real Tangled %d" % int(landed["tangled"]))
		_check(int(foe["statuses"].get("weak", 0)) == int(landed["weak"]),
			"AC2: " + tag + " leaves Weak %d" % int(landed["weak"]))
		if int(landed["weak"]) == 0:
			_check(not foe["statuses"].has("weak"),
				"AC2: " + tag + " never adds a Weak status")
		_check(_status_value(result.get("statuses", []), "tangled") == int(landed["tangled"]),
			"AC2: " + tag + " reports the applied Tangled")
		_check(_status_value(result.get("statuses", []), "weak") ==
			(-1 if int(landed["weak"]) == 0 else int(landed["weak"])),
			"AC2: " + tag + " reports exactly its applied Weak")
		for other in battle.get_foes():
			if str(other["id"]) == foe_id:
				continue
			_check(int(other["statuses"].get("tangled", 0)) == 0
				and int(other["statuses"].get("weak", 0)) == 0,
				"AC2: " + tag + " debuffs only the chosen foe, not " + str(other["id"]))
		var caster := battle.get_unit(OWNER)
		_check(int(caster["statuses"].get("tangled", 0)) == 0
			and int(caster["statuses"].get("weak", 0)) == 0,
			"AC2: " + tag + " leaves no debuff on the caster")
		_check(_to(battle, foe_id), "AC2: the " + tag + " foe reaches its own seeded turn")
		_check(int(battle.get_unit(foe_id)["statuses"].get("tangled", 0)) == int(after["tangled"]),
			"AC2: " + tag + " Tangled ticks down by exactly one foe turn")
		_check(int(battle.get_unit(foe_id)["statuses"].get("weak", 0)) == int(after["weak"]),
			"AC2: " + tag + " Weak ticks down by exactly one foe turn")
		_check(int(battle.get_unit(foe_id)["hp"]) > 0,
			"AC2: " + tag + " itself deals no damage")
	# A missed roll spends the action but applies neither status.
	var missed := _cast_witness(snare_id, 3, 0, 1, false, true)
	if missed.is_empty():
		_check(false, "AC3: a fixed seed makes a tier-III Tattered Snare miss for the fail-closed witness")
	else:
		var miss_battle: StitchedRules = missed["battle"]
		var miss_result: Dictionary = missed["receipt"]["results"][0]
		var miss_foe_id := str(miss_result["target"])
		_check(not bool(miss_result.get("hit", true)), "AC3: the Tattered Snare miss witness really missed")
		_check(miss_result.get("statuses", []).is_empty(),
			"AC3: a missed Tattered Snare reports no applied status")
		var miss_foe := miss_battle.get_unit(miss_foe_id)
		_check(int(miss_foe["statuses"].get("tangled", 0)) == 0
			and int(miss_foe["statuses"].get("weak", 0)) == 0,
			"AC3: a missed Tattered Snare adds neither Tangled nor Weak")
		_check(int(miss_foe["hp"]) == int(missed["foe_hp_before"].get(miss_foe_id, -1)),
			"AC3: a missed pure debuff deals no HP damage")
		_check(miss_battle.current_actor_id() != OWNER,
			"AC3: the missed roll still spends the Duelist's action")
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
	## Feather Feint: tier I only Exposes the foe; tiers II and III also Mark that same seam, so a
	## later mark_damage follow-up can find it. Both counters tick down one on that foe's real turn.
	## S14 keeps that legacy ladder in the record, but its player-readable copy is now the sewn-cloth
	## description checked here instead of the retired combat promise.
	var feint_id := str(STARTER_PARTS["head"])
	var feint_text := str(_catalog()["by_id"][feint_id]["text"])
	_check(feint_text == str(HEAD_PATCH_TEXT[feint_id]),
		"AC1: Feather Feint carries its authored sewn-cloth sentence: " + feint_text)
	var feint_words := _whole_words(feint_text)
	for word in HEAD_PATCH_FORBIDDEN_WORDS:
		_check(not str(word) in feint_words,
			"AC1: Feather Feint promises no combat term " + str(word) + ": " + feint_text)
	var feint_ladder := [
		{"exposed": 2, "mark": 0},
		{"exposed": 2, "mark": 1},
		{"exposed": 3, "mark": 2},
	]
	for tier in [1, 2, 3]:
		var landed: Dictionary = feint_ladder[tier - 1]
		var exposed_amount := int(landed["exposed"])
		var mark_amount := int(landed["mark"])
		var tag := "Feather Feint tier %d" % tier
		var feint := _cast_witness(feint_id, tier, 0, 1, true)
		if feint.is_empty():
			_check(false, "AC2: a fixed seed lands " + tag + " for the Exposed/Mark witness")
			continue
		var battle: StitchedRules = feint["battle"]
		var receipt: Dictionary = feint["receipt"]
		var result: Dictionary = receipt["results"][0]
		var foe_id := str(result["target"])
		_check(str(receipt.get("part", "")) == feint_id,
			"AC2: " + tag + " casts the worn starter head part")
		_check(str(receipt.get("ability", "")) == "rag_duelist_head_feather_feint_move",
			"AC2: " + tag + " resolves the authored ability id")
		_check(str(receipt.get("actor", "")) == OWNER, "AC2: " + tag + " is used by the Rag Duelist")
		_check(bool(result.get("hit", false)), "AC2: " + tag + " landed on a real seeded roll")
		_check(int(result.get("damage", -1)) == 0, "AC2: " + tag + " stays a zero-damage debuff")
		var foe := battle.get_unit(foe_id)
		_check(int(foe["hp"]) == int(feint["foe_hp_before"].get(foe_id, -1)),
			"AC2: " + tag + " leaves the landed foe's HP untouched")
		_check(int(foe["statuses"].get("exposed", 0)) == exposed_amount,
			"AC2: %s leaves a real Exposed %d" % [tag, exposed_amount])
		_check(int(foe["statuses"].get("mark", 0)) == mark_amount,
			"AC2: %s leaves a real Mark %d" % [tag, mark_amount])
		if mark_amount == 0:
			_check(not foe["statuses"].has("mark"), "AC2: " + tag + " never adds a Mark")
		var receipt_statuses: Array = result.get("statuses", [])
		_check(receipt_statuses.size() == (1 if mark_amount == 0 else 2),
			"AC2: " + tag + " receipt reports exactly its applied debuffs")
		_check(_status_value(receipt_statuses, "exposed") == exposed_amount,
			"AC2: " + tag + " reports the applied Exposed")
		_check(_status_value(receipt_statuses, "mark") == (-1 if mark_amount == 0 else mark_amount),
			"AC2: " + tag + " reports exactly its applied Mark")
		for other in battle.get_foes():
			if str(other["id"]) == foe_id:
				continue
			_check(int(other["statuses"].get("exposed", 0)) == 0
				and int(other["statuses"].get("mark", 0)) == 0,
				"AC2: " + tag + " debuffs only the chosen foe, not " + str(other["id"]))
		# An equal-seed replay casts identically, so the added Mark adds no hidden randomness.
		var snapshot_after_cast := battle.state_snapshot()
		var rng_after_cast := battle.rng_state()
		var replay := _build_battle(int(feint["seed"]), tier, _kit_for(feint_id), 0, false)
		if replay == null or not _to(replay, OWNER):
			_check(false, "AC4: " + tag + " replays on a second equal-seed fixture")
			continue
		var replay_receipt := replay.use_part(feint_id, 1)
		_check(replay_receipt == receipt and replay.state_snapshot() == snapshot_after_cast
			and replay.rng_state() == rng_after_cast,
			"AC4: " + tag + " replays its receipt, state and RNG exactly")
		# Both counters tick down exactly one on the affected foe's own next real turn.
		_check(_to(battle, foe_id), "AC2: the " + tag + " foe reaches its own seeded turn")
		_check(int(battle.get_unit(foe_id)["statuses"].get("exposed", 0)) == exposed_amount - 1,
			"AC2: %s Exposed ticks down by exactly one foe turn" % tag)
		_check(int(battle.get_unit(foe_id)["statuses"].get("mark", 0)) == maxi(mark_amount - 1, 0),
			"AC2: %s Mark ticks down by exactly one foe turn" % tag)
	# A missed Feint spends the action but applies neither Exposed nor Mark, at its upgraded tier.
	var missed_feint := _cast_witness(feint_id, 3, 0, 1, false, true)
	if missed_feint.is_empty():
		_check(false, "AC3: a fixed seed makes a tier-III Feather Feint miss for the fail-closed witness")
	else:
		var miss_battle: StitchedRules = missed_feint["battle"]
		var miss_result: Dictionary = missed_feint["receipt"]["results"][0]
		var miss_foe_id := str(miss_result["target"])
		_check(not bool(miss_result.get("hit", true)), "AC3: the Feather Feint miss witness really missed")
		_check(miss_result.get("statuses", []).is_empty(),
			"AC3: a missed Feather Feint reports no applied status")
		var miss_foe := miss_battle.get_unit(miss_foe_id)
		_check(int(miss_foe["statuses"].get("exposed", 0)) == 0
			and int(miss_foe["statuses"].get("mark", 0)) == 0,
			"AC3: a missed Feather Feint adds neither Exposed nor Mark")
		_check(int(miss_foe["hp"]) == int(missed_feint["foe_hp_before"].get(miss_foe_id, -1)),
			"AC3: a missed Feint deals no HP damage either")
		_check(miss_battle.current_actor_id() != OWNER,
			"AC3: the missed Feint still spends the Duelist's action")



# ---------------------------------------------------------------- AC2: tier-I Feather Feint opens a real follow-up window

## Two genuine equal-seed battles cast the same equipped Feint, then advance through the
## Fray Scavenger's first turn-start tick. Removing Exposed from only the control immediately
## before the next scheduled Needle Prick isolates the damage modifier from rolls and tempo.
func _test_feint_followup_window() -> void:
	var feint_id := str(STARTER_PARTS["head"])
	var prick_id := str(ALTERNATE_PARTS["arms"])
	var witness: Dictionary = {}
	for seed_value in range(1, 240):
		var battle := _build_battle(seed_value, 1, _kit_for(prick_id), 0, false)
		var control := _build_battle(seed_value, 1, _kit_for(prick_id), 0, false)
		if battle == null or control == null or not _to(battle, OWNER) or not _to(control, OWNER):
			continue
		var initial_equal := battle.state_snapshot() == control.state_snapshot() \
			and battle.rng_state() == control.rng_state()
		var hp_before_feint := int(battle.get_unit(FRAY_SCAVENGER)["hp"])
		var feint := battle.use_part(feint_id, 1)
		var control_feint := control.use_part(feint_id, 1)
		if not bool(feint.get("ok", false)) or feint.get("results", []).size() != 1 \
			or not bool(feint["results"][0].get("hit", false)):
			continue
		var after_feint_equal := feint == control_feint \
			and battle.state_snapshot() == control.state_snapshot() \
			and battle.rng_state() == control.rng_state()
		var landed_foe := battle.get_unit(FRAY_SCAVENGER)
		var landed_exposed := int(landed_foe["statuses"].get("exposed", 0))
		var landed_mark := int(landed_foe["statuses"].get("mark", 0))
		if not _to(battle, FRAY_SCAVENGER) or not _to(control, FRAY_SCAVENGER):
			continue
		var first_tick := int(battle.get_unit(FRAY_SCAVENGER)["statuses"].get("exposed", 0))
		if not _to(battle, OWNER) or not _to(control, OWNER):
			continue
		var at_followup_equal := battle.state_snapshot() == control.state_snapshot() \
			and battle.rng_state() == control.rng_state()
		var at_followup_exposed := int(battle.get_unit(FRAY_SCAVENGER)["statuses"].get("exposed", 0))
		var before_hp := int(battle.get_unit(FRAY_SCAVENGER)["hp"])
		var rng_before := battle.rng_state()
		control._units[FRAY_SCAVENGER]["statuses"].erase("exposed")
		var normalized := battle.state_snapshot()
		for unit in normalized["units"]:
			if str(unit.get("id", "")) == FRAY_SCAVENGER:
				unit["statuses"].erase("exposed")
		var only_exposed_diff := normalized == control.state_snapshot() \
			and control.rng_state() == rng_before
		var control_exposed := int(control.get_unit(FRAY_SCAVENGER)["statuses"].get("exposed", 0))
		var prick := battle.use_part(prick_id, 1)
		var plain := control.use_part(prick_id, 1)
		if not bool(prick.get("ok", false)) or not bool(plain.get("ok", false)) \
			or prick.get("results", []).size() != 1 or plain.get("results", []).size() != 1 \
			or not bool(prick["results"][0].get("hit", false)) \
			or not bool(plain["results"][0].get("hit", false)) \
			or int(battle.get_unit(FRAY_SCAVENGER)["hp"]) <= 2:
			continue
		witness = {
			"seed": seed_value, "battle": battle, "control": control,
			"initial_equal": initial_equal, "after_feint_equal": after_feint_equal,
			"at_followup_equal": at_followup_equal, "only_exposed_diff": only_exposed_diff,
			"feint": feint, "hp_before_feint": hp_before_feint,
			"landed_exposed": landed_exposed, "landed_mark": landed_mark,
			"first_tick": first_tick, "at_followup_exposed": at_followup_exposed,
			"control_exposed": control_exposed, "before_hp": before_hp,
			"rng_before": rng_before, "prick": prick, "plain": plain,
		}
		break
	_check(not witness.is_empty(),
		"AC2: a fixed seed lands tier-I Feint and both legal post-foe-turn Needle Prick hits on the living rank-1 Fray Scavenger")
	if witness.is_empty():
		return
	var battle: StitchedRules = witness["battle"]
	var control: StitchedRules = witness["control"]
	var feint: Dictionary = witness["feint"]
	var feint_result: Dictionary = feint["results"][0]
	var prick: Dictionary = witness["prick"]
	var plain: Dictionary = witness["plain"]
	var hit: Dictionary = prick["results"][0]
	var plain_hit: Dictionary = plain["results"][0]
	var foe := battle.get_unit(FRAY_SCAVENGER)
	var control_foe := control.get_unit(FRAY_SCAVENGER)
	var damage := int(hit.get("damage", 0))
	var base_damage := int(plain_hit.get("damage", 0))
	_check(bool(witness["initial_equal"]) and bool(witness["after_feint_equal"])
		and bool(witness["at_followup_equal"]) and bool(witness["only_exposed_diff"]),
		"AC2: equal-seed real battle states/RNG match through the first foe turn; only Exposed is removed in the control")
	_check(str(feint.get("part", "")) == feint_id and str(feint.get("actor", "")) == OWNER
		and str(feint_result.get("target", "")) == FRAY_SCAVENGER
		and int(feint_result.get("target_rank", 0)) == 1
		and bool(feint_result.get("hit", false)) and int(feint_result.get("damage", -1)) == 0,
		"AC2: equipped tier-I Feather Feint lands a zero-damage hit on the actual rank-1 Fray Scavenger")
	_check(int(witness["landed_exposed"]) == 2 and int(witness["landed_mark"]) == 0
		and _status_value(feint_result.get("statuses", []), "exposed") == 2
		and _status_value(feint_result.get("statuses", []), "mark") == -1
		and int(witness["hp_before_feint"]) == int(witness["before_hp"]),
		"AC2: that Feint leaves exactly Exposed 2, no Mark and no lost foe HP")
	_check(int(witness["first_tick"]) == 1 and int(witness["at_followup_exposed"]) == 1
		and int(witness["control_exposed"]) == 0,
		"AC2: its first real foe start ticks Exposed 2 to 1, preserved for the next Duelist turn but removed in the control")
	_check(str(prick.get("part", "")) == prick_id and str(plain.get("part", "")) == prick_id
		and str(prick.get("actor", "")) == OWNER and str(plain.get("actor", "")) == OWNER
		and str(foe["id"]) == FRAY_SCAVENGER and int(foe["rank"]) == 1
		and str(battle.get_unit(OWNER)["parts"]["arms"]["id"]) == prick_id
		and int(battle.get_unit(OWNER)["parts"]["arms"]["tier"]) == 1,
		"AC2: the legal follow-up really uses equipped tier-I Needle Prick against the same rank-1 foe")
	_check(bool(hit["hit"]) and bool(plain_hit["hit"]) and hit.get("roll") == plain_hit.get("roll")
		and bool(hit.get("crit", false)) == bool(plain_hit.get("crit", false))
		and battle.rng_state() == control.rng_state(),
		"AC2: both landed follow-ups use identical hit rolls, crit outcomes and post-action RNG")
	var normalized_reply := prick.duplicate(true)
	normalized_reply["results"][0]["damage"] = base_damage
	normalized_reply["results"][0]["target_hp"] = int(plain_hit["target_hp"])
	_check(normalized_reply == plain,
		"AC2: the follow-up receipts differ only in damage and target HP, not hit, status or side effects")
	_check(base_damage > 0 and damage > base_damage,
		"AC2: the surviving Exposed 1 strictly boosts the matched legal Needle Prick damage")
	_check(int(hit["target_hp"]) == int(witness["before_hp"]) - damage
		and int(plain_hit["target_hp"]) == int(witness["before_hp"]) - base_damage,
		"AC2: at impact, each real foe HP drops by only its own reported Needle Prick damage")
	# Resolving Needle Prick can advance directly into the foe\'s next turn and tick Bleed/Exposed
	# before use_part returns. Otherwise the tick occurs below while advancing to that turn.
	var second_tick_already_entered := battle.current_actor_id() == FRAY_SCAVENGER
	_check(second_tick_already_entered == (control.current_actor_id() == FRAY_SCAVENGER),
		"AC2: the two equal-seed battles have the same next scheduled foe turn")
	_check(int(foe["hp"]) == int(control_foe["hp"]) - (damage - base_damage)
		and int(foe["statuses"].get("exposed", 0)) == (0 if second_tick_already_entered else 1)
		and int(foe["statuses"].get("bleed", 0)) == (1 if second_tick_already_entered else 2)
		and int(control_foe["statuses"].get("bleed", 0)) == (1 if second_tick_already_entered else 2)
		and not control_foe["statuses"].has("exposed")
		and _status_value(hit.get("statuses", []), "bleed") == 2
		and _status_value(plain_hit.get("statuses", []), "bleed") == 2,
		"AC2: matched HP difference and Bleed side effects survive the legal action; Exposed is never refreshed")
	var reached_second_tick := _to(battle, FRAY_SCAVENGER)
	_check(reached_second_tick,
		"AC2: the living Fray Scavenger reaches its natural second start-of-turn after the follow-up")
	if reached_second_tick:
		_check(not battle.get_unit(FRAY_SCAVENGER)["statuses"].has("exposed")
			and int(battle.get_unit(FRAY_SCAVENGER)["statuses"].get("exposed", 0)) == 0,
			"AC2: unrefreshed Feather Feint Exposed expires naturally on the foe's second turn")

# ---------------------------------------------------------------- AC2/AC3: Feather Feint -> Lunge Mark payoff

## The concrete head-to-arms combo: a genuine tier-III Feather Feint Marks a living foe, that
## foe's own real turn ticks Mark 2 down to 1, and the Duelist's next scheduled rank-2 turn lands
## an upgraded Rapier Lunge on the still-Marked foe. Tier II proves the authored +3 and tier III
## the authored +5, both added before Exposed and PROT. An identical-seed twin that Feints another
## rank keeps the same damage roll and shows no bonus at all on the unmarked target.
func _test_lunge_mark_payoff() -> void:
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)):
		_check(false, "AC2: the shipped catalog loads for the Rapier Lunge Mark payoff")
		return
	var lunge_id := str(STARTER_PARTS["arms"])
	var mark_ladder := [0, 3, 5]
	var last_witness := {}
	for tier in [2, 3]:
		var tag := "Rapier Lunge tier %d on a Feather-Feint Mark" % tier
		var witness := _lunge_payoff_witness(tier, 1, 1)
		if witness.is_empty():
			_check(false, "AC2: a fixed seed lands " + tag)
			continue
		last_witness = witness
		var battle: StitchedRules = witness["battle"]
		var receipt: Dictionary = witness["receipt"]
		var result: Dictionary = receipt["results"][0]
		var foe_id := str(witness["foe"])
		var target := battle.get_unit(foe_id)
		var before: Dictionary = witness["statuses_before"]
		var ability := StitchedParts.ability_at_tier(catalog["by_id"][lunge_id], tier)
		var mark_damage := int(ability["mark_damage"])
		var prot := int(target["prot"])
		var bonus := int(battle.get_unit(OWNER)["dmg_bonus"])
		var dealt := int(result["damage"])
		var bases := _base_roll_candidates(ability, bonus, bool(result.get("crit", false)))
		_check(bool(witness["feint"].get("ok", false)),
			"AC2: " + tag + " really starts from a landed real Feather Feint")
		var worn: Dictionary = battle.get_unit(OWNER)["parts"]
		_check(int(worn["arms"]["tier"]) == tier and str(worn["arms"]["id"]) == lunge_id,
			"AC2: " + tag + " the live Duelist really wears the tested Rapier Lunge tier")
		_check(int(worn["head"]["tier"]) == 3
			and str(worn["head"]["id"]) == str(STARTER_PARTS["head"]),
			"AC2: " + tag + " the Mark came from the live tier-III Feather Feint head")
		_check(str(receipt.get("part", "")) == lunge_id,
			"AC2: " + tag + " casts the worn Rapier Lunge arms part")
		_check(str(receipt.get("ability", "")) == "rag_duelist_arms_rapier_lunge_move",
			"AC2: " + tag + " resolves the authored Rapier Lunge ability id")
		_check(str(receipt.get("actor", "")) == OWNER, "AC2: " + tag + " is used by the Rag Duelist")
		_check(str(result.get("target", "")) == foe_id and str(result.get("target_side", "")) == "foe"
			and int(result.get("target_rank", 0)) == 1,
			"AC2: " + tag + " hits the Marked rank-1 foe")
		_check(bool(result.get("hit", false)), "AC2: " + tag + " reports a confirmed hit")
		_check(int(before.get("mark", 0)) == 1,
			"AC2: the real tier-III Feather Feint Mark survives one foe turn as Mark 1")
		_check(int(before.get("exposed", 0)) == 2,
			"AC2: the tier-III Exposed 3 survives the same foe turn as Exposed 2")
		_check(int(before.get("weak", 0)) == 0 and int(before.get("tangled", 0)) == 0,
			"AC2: " + tag + " target carries no other damage modifier")
		_check(mark_damage == int(mark_ladder[tier - 1]),
			"AC2: " + tag + " resolves its authored Mark bonus %d" % mark_ladder[tier - 1])
		var matched: Array = _matching_bases(bases, before, true, mark_damage, prot, dealt)
		_check(not matched.is_empty(),
			"AC2: " + tag + " damage equals its seeded base + Mark bonus, then Exposed and PROT")
		for base in matched:
			_check(dealt != base + mark_damage,
				"AC2: " + tag + " reports post-modifier damage, not the raw base plus Mark bonus")
			_check(dealt > StitchedRules.damage_after_modifiers(base, {}, before, false, 0, prot),
				"AC2: " + tag + " the Marked target takes more than the same base would unmarked")
		# Mark-before-Exposed is observably different from adding the bonus after the multiplier.
		var ordered := false
		for base in matched:
			var mark_first := StitchedRules.damage_after_modifiers(base, {}, before, true, mark_damage, prot)
			var mark_last := _mark_after_exposed(base, before, mark_damage, prot)
			if mark_first != mark_last:
				ordered = true
				_check(dealt == mark_first,
					"AC2: " + tag + " applies the Mark bonus before the Exposed multiplier")
		_check(ordered, "AC2: " + tag + " really distinguishes Mark-first from Mark-last ordering")
		_check(int(result.get("target_hp", -1)) == int(target["hp"]),
			"AC2: " + tag + " reports the foe's real remaining HP")
		_check(int(target["hp"]) == int(witness["hp_before"]) - dealt,
			"AC2: " + tag + " the foe's HP really drops by exactly the reported damage")
		_check(int(target["hp"]) > 0, "AC2: " + tag + " leaves the Marked foe alive")
		_check(result.get("statuses", []).is_empty(),
			"AC2: " + tag + " applies no status that could consume or refresh the Mark")
		# The mandatory +1 forward step swaps with the legal front ally.
		var move: Dictionary = receipt.get("self_move", {})
		_check(bool(move.get("ok", false)), "AC2: " + tag + " resolves its one-rank forward step")
		_check(int(move.get("from", 0)) == 2 and int(move.get("to", 0)) == 1,
			"AC2: " + tag + " steps from rank 2 to rank 1")
		_check(str(move.get("swapped", "")) == "seamstress",
			"AC2: " + tag + " swaps with the legal front ally")
		_check(int(battle.get_unit(OWNER)["rank"]) == 1
			and int(battle.get_unit("seamstress")["rank"]) == 2,
			"AC2: " + tag + " really moves both heroes on the board")
		# AC4: the same seed and the same legal actions replay receipt, state and RNG exactly.
		var replay := _lunge_payoff_witness(tier, 1, 1, true, true, false, int(witness["seed"]))
		_check(not replay.is_empty() and int(replay["seed"]) == int(witness["seed"]),
			"AC4: " + tag + " replays on the same fixed seed")
		if not replay.is_empty():
			var replay_battle: StitchedRules = replay["battle"]
			_check(replay["receipt"] == receipt
				and replay_battle.state_snapshot() == battle.state_snapshot()
				and replay_battle.rng_state() == battle.rng_state(),
				"AC4: " + tag + " replays its receipt, complete state and RNG exactly")
		# AC3: an otherwise identical unmarked target at the same tier and seed gets no bonus.
		var twin := _lunge_payoff_witness(tier, 2, 1, false, true, false, int(witness["seed"]))
		if twin.is_empty():
			_check(false, "AC3: a fixed seed lands the unmarked twin of " + tag)
			continue
		_check(int(twin["seed"]) == int(witness["seed"]),
			"AC3: the unmarked twin runs the identical fixed seed")
		var twin_result: Dictionary = twin["receipt"]["results"][0]
		var twin_before: Dictionary = twin["statuses_before"]
		var twin_dealt := int(twin_result["damage"])
		_check(bool(twin_result.get("hit", false)),
			"AC3: the unmarked twin lands its Lunge on the same seeded roll")
		_check(bool(twin_result.get("crit", false)) == bool(result.get("crit", false)),
			"AC3: the unmarked twin shares the marked Lunge's crit roll")
		_check(int(twin_before.get("mark", 0)) == 0 and int(twin_before.get("exposed", 0)) == 0,
			"AC3: the twin's Lunge target really carries no Mark")
		var twin_feint_result: Dictionary = twin["feint"]["results"][0]
		_check(bool(twin_feint_result.get("hit", false))
			and int(twin_feint_result.get("damage", -1)) == 0
			and _status_value(twin_feint_result.get("statuses", []), "mark") == 2,
			"AC3: the twin Mark sits on the other foe, so the missing bonus is target-specific")
		var twin_ability := StitchedParts.ability_at_tier(catalog["by_id"][lunge_id], tier)
		var twin_bases := _base_roll_candidates(twin_ability, bonus, bool(twin_result.get("crit", false)))
		var twin_prot := int(twin["battle"].get_unit(str(twin["foe"]))["prot"])
		var twin_matched: Array = _matching_bases(
			twin_bases, twin_before, false, mark_damage, twin_prot, twin_dealt)
		var shared := false
		for base in matched:
			if not (base in twin_matched):
				continue
			shared = true
			_check(twin_dealt == StitchedRules.damage_after_modifiers(
				base, {}, twin_before, false, mark_damage, twin_prot),
				"AC3: the unmarked twin adds no mark_damage to the identical seeded base")
			_check(StitchedRules.damage_after_modifiers(
				base, {}, twin_before, true, mark_damage, twin_prot) > twin_dealt,
				"AC3: the same base would have dealt more had the twin's target been Marked")
		_check(shared, "AC3: the marked and unmarked witnesses roll the same seeded base damage")
	# Tier I stays the validated default: no bonus even on a Marked target.
	var tier_one := _lunge_payoff_witness(1, 1, 1)
	if tier_one.is_empty():
		_check(false, "AC3: a fixed seed lands a tier-I Lunge on a Marked foe")
	else:
		var battle: StitchedRules = tier_one["battle"]
		var result: Dictionary = tier_one["receipt"]["results"][0]
		var before: Dictionary = tier_one["statuses_before"]
		var ability := StitchedParts.ability_at_tier(catalog["by_id"][lunge_id], 1)
		var dealt := int(result["damage"])
		var bonus := int(battle.get_unit(OWNER)["dmg_bonus"])
		var prot := int(battle.get_unit(str(tier_one["foe"]))["prot"])
		_check(int(ability.get("mark_damage", -1)) == 0,
			"AC3: tier-I Rapier Lunge resolves the validated default mark_damage 0")
		_check(int(before.get("mark", 0)) == 1 and bool(result.get("hit", false)),
			"AC3: the tier-I witness really hits a Marked foe")
		var bases := _base_roll_candidates(ability, bonus, bool(result.get("crit", false)))
		var matched: Array = _matching_bases(bases, before, true, 0, prot, dealt)
		_check(not matched.is_empty(),
			"AC3: tier-I damage uses no Mark bonus")
		for base in matched:
			_check(StitchedRules.damage_after_modifiers(base, {}, before, true, 3, prot) > dealt,
				"AC3: a tier-II Mark bonus would have raised the same tier-I hit's damage")
	# A missed upgraded Lunge deals no damage and keeps the Mark for a later attempt.
	var missed := _lunge_payoff_witness(3, 1, 1, true, false, true)
	if missed.is_empty():
		_check(false, "AC3: a fixed seed makes a Marked Rapier Lunge miss")
	else:
		var miss_battle: StitchedRules = missed["battle"]
		var miss_result: Dictionary = missed["receipt"]["results"][0]
		var miss_foe := str(missed["foe"])
		_check(not bool(miss_result.get("hit", true)), "AC3: the Marked Lunge miss witness really missed")
		_check(int(miss_result.get("damage", -1)) == 0,
			"AC3: a missed upgraded Lunge deals no damage")
		_check(int(miss_battle.get_unit(miss_foe)["hp"]) == int(missed["hp_before"]),
			"AC3: a missed upgraded Lunge leaves the Marked foe's HP untouched")
		_check(int(missed["statuses_before"].get("mark", 0)) == 1
			and miss_result.get("statuses", []).is_empty(),
			"AC3: a missed Lunge neither consumes nor reapplies the Mark")
		_check(miss_battle.current_actor_id() != OWNER,
			"AC3: the missed Lunge still spends the Duelist's action")
	# Illegal target ranks, an illegal launch rank and a blocked forward swap are atomic.
	var prepared := {}
	if last_witness.is_empty():
		_check(false, "AC3: the marked payoff witness exists for the refusal checks")
	else:
		prepared = _feint_then_lunge(int(last_witness["seed"]), 3, 1)
	if prepared.is_empty():
		_check(false, "AC3: the marked payoff fixture can be rebuilt for refusals")
	else:
		var refusal_battle: StitchedRules = prepared["battle"]
		var foe_id := str(prepared["foe"])
		var mark_before := int(refusal_battle.get_unit(foe_id)["statuses"].get("mark", 0))
		var hp_before := int(refusal_battle.get_unit(foe_id)["hp"])
		var state := refusal_battle.state_snapshot()
		var rng := refusal_battle.rng_state()
		var bad_rank := refusal_battle.use_part(lunge_id, 3)
		_check(not bool(bad_rank.get("ok", false))
			and str(bad_rank.get("error", "")).contains("no legal target in rank 3"),
			"AC3: an upgraded Lunge refuses a rank outside its authored 1-2 target mask")
		_check(state == refusal_battle.state_snapshot() and rng == refusal_battle.rng_state(),
			"AC3: the illegal target rank preserved state, turn pointer and RNG")
		refusal_battle._units["seamstress"]["statuses"]["tangled"] = 1
		state = refusal_battle.state_snapshot()
		rng = refusal_battle.rng_state()
		var blocked := refusal_battle.use_part(lunge_id, 1)
		_check(not bool(blocked.get("ok", false))
			and str(blocked.get("error", "")).contains("self move is blocked"),
			"AC3: a tangled front ally refuses the upgraded Lunge swap")
		_check(state == refusal_battle.state_snapshot() and rng == refusal_battle.rng_state(),
			"AC3: the blocked-swap refusal preserved state, turn pointer and RNG")
		_check(refusal_battle.current_actor_id() == OWNER,
			"AC3: the blocked swap never spends the Duelist's turn")
		_check(int(refusal_battle.get_unit(foe_id)["hp"]) == hp_before
			and int(refusal_battle.get_unit(foe_id)["statuses"].get("mark", 0)) == mark_before,
			"AC3: the blocked swap rolls no damage and never consumes the Mark")
	# A rank-1 wearer may still Feint, but the upgraded Lunge refuses that launch rank.
	var front := {}
	for candidate in range(1, 240):
		front = _feint_then_lunge(candidate, 3, 1, 0)
		if not front.is_empty():
			break
	if front.is_empty():
		_check(false, "AC3: a fixed seed lands a rank-1 Feather Feint in front")
	else:
		var front_battle: StitchedRules = front["battle"]
		var front_foe := str(front["foe"])
		_check(int(front_battle.get_unit(OWNER)["rank"]) == 1,
			"AC3: the front-rank fixture really places the Duelist in rank 1")
		var state := front_battle.state_snapshot()
		var rng := front_battle.rng_state()
		var refused := front_battle.use_part(lunge_id, 1)
		_check(not bool(refused.get("ok", false))
			and str(refused.get("error", "")).contains("cannot launch from rank 1"),
			"AC3: the upgraded Lunge refuses to launch from rank 1")
		_check(state == front_battle.state_snapshot() and rng == front_battle.rng_state(),
			"AC3: the illegal launch rank preserved state, turn pointer and RNG")
		_check(int(front_battle.get_unit(front_foe)["statuses"].get("mark", 0)) == 1,
			"AC3: the illegal launch rank leaves the Marked foe untouched")
		_check(front_battle.current_actor_id() == OWNER,
			"AC3: the illegal launch rank never spends the Duelist's turn")


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
	# Feather Feint only launches from ranks 1-2, so a displaced Duelist is refused atomically.
	for hero_rank in [3, 4]:
		var displaced := _build_battle(53 + hero_rank, 1, STARTER_PARTS, hero_rank - 1)
		if displaced == null:
			continue
		_check(_to(displaced, OWNER),
			"AC3: the rank-%d Duelist reaches a genuine scheduled turn" % hero_rank)
		_check(int(displaced.get_unit(OWNER)["rank"]) == hero_rank,
			"AC3: the fixture really places the Duelist at rank %d" % hero_rank)
		var displaced_before := displaced.state_snapshot()
		var displaced_rng := displaced.rng_state()
		var feint_launch := displaced.use_part("rag_duelist_head_feather_feint", 1)
		_check(not bool(feint_launch.get("ok", false))
			and str(feint_launch.get("error", "")).contains("cannot launch from rank %d" % hero_rank),
			"AC3: Feather Feint refuses to launch from rank %d" % hero_rank)
		_check(displaced_before == displaced.state_snapshot()
			and displaced_rng == displaced.rng_state(),
			"AC3: the rank-%d Feint refusal preserved state, turn pointer and RNG" % hero_rank)
		_check(displaced.current_actor_id() == OWNER,
			"AC3: the rank-%d Feint refusal never spends the Duelist's turn" % hero_rank)
		for foe in displaced.get_foes():
			_check(int(foe["statuses"].get("exposed", 0)) == 0
				and int(foe["statuses"].get("mark", 0)) == 0,
				"AC3: the rank-%d Feint refusal debuffs no foe" % hero_rank)
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
## `slot_tiers` may override the stitch tier of one or more slots (for example a tier-III Feather
## Feint head with a tier-II Rapier Lunge arms); every other slot keeps `tier`.
func _preview_config(seed_value: int, tier: int, kit: Dictionary, hero_index: int,
		torn_slot: String = "", slot_tiers: Dictionary = {}) -> Dictionary:
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
		var worn := {"id": str(kit[slot]), "tier": int(slot_tiers.get(slot, tier))}
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
		hero_index: int = 0, report: bool = true,
		slot_tiers: Dictionary = {}) -> StitchedRules:
	var config := _preview_config(seed_value, tier, kit, hero_index, "", slot_tiers)
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
		needs_hit: bool, require_miss: bool = false) -> Dictionary:
	for seed_value in range(1, 240):
		var battle := _build_battle(seed_value, tier, _kit_for(part_id), hero_index, false)
		if battle == null:
			return {}
		if not _to(battle, OWNER):
			continue
		var foe_hp_before := {}
		for foe in battle.get_foes():
			foe_hp_before[str(foe["id"])] = int(foe["hp"])
		var receipt := battle.use_part(part_id, target_rank)
		if not bool(receipt.get("ok", false)) or receipt.get("results", []).is_empty():
			continue
		var hit := bool(receipt["results"][0].get("hit", false))
		if needs_hit and not hit:
			continue
		if require_miss and hit:
			continue
		return {
			"battle": battle, "receipt": receipt, "seed": seed_value,
			"foe_hp_before": foe_hp_before,
		}
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


# ---------------------------------------------------------------- Mark payoff helpers

## Builds the seeded fixture with a genuine tier-III Feather Feint head and the requested Rapier
## Lunge tier fitted in the arms slot, lands the Feint on the foe in `feint_rank`, then walks the
## real schedule (passing the intervening turns) to the Duelist's next turn. Nothing is forced:
## the Feint must hit on a real roll, apply a real Mark, and survive that foe's own status tick.
func _feint_then_lunge(seed_value: int, lunge_tier: int, feint_rank: int,
		hero_index: int = 1) -> Dictionary:
	var battle := _build_battle(seed_value, 3, STARTER_PARTS, hero_index, false,
		{"arms": lunge_tier})
	if battle == null:
		return {}
	if not _to(battle, OWNER):
		return {}
	var feint := battle.use_part(str(STARTER_PARTS["head"]), feint_rank)
	if not bool(feint.get("ok", false)) or feint.get("results", []).is_empty():
		return {}
	var feint_result: Dictionary = feint["results"][0]
	if not bool(feint_result.get("hit", false)) or int(feint_result.get("damage", -1)) != 0:
		return {}
	var foe_id := str(feint_result["target"])
	if int(battle.get_unit(foe_id)["statuses"].get("mark", 0)) <= 0:
		return {}
	if not _to(battle, OWNER):
		return {}
	return {"battle": battle, "feint": feint, "feint_result": feint_result, "foe": foe_id}


## Repeats the Feint-then-Lunge setup over fixed seeds until the real upgraded Lunge hits (or,
## when asked, misses) the foe at `lunge_rank`. A tier-II Feint Mark 1 would expire on the foe's
## own turn, so the head stays the authored tier-III Feather Feint (Mark 2 -> Mark 1) while the
## arms keep the tested tier. Returns the receipt and the exact pre-attack target state.
func _lunge_payoff_witness(lunge_tier: int, feint_rank: int, lunge_rank: int,
		expect_target_marked: bool = true, require_hit: bool = true,
		require_miss: bool = false, start_seed: int = 1) -> Dictionary:
	for seed_value in range(start_seed, start_seed + 240):
		var prepared := _feint_then_lunge(seed_value, lunge_tier, feint_rank)
		if prepared.is_empty():
			continue
		var battle: StitchedRules = prepared["battle"]
		var target := {}
		for foe in battle.get_foes():
			if int(foe["rank"]) == lunge_rank:
				target = foe
		if target.is_empty():
			continue
		if expect_target_marked != (int(target["statuses"].get("mark", 0)) > 0):
			continue
		var hp_before := int(target["hp"])
		var statuses_before: Dictionary = target["statuses"].duplicate(true)
		var snapshot_before := battle.state_snapshot()
		var rng_before := battle.rng_state()
		var receipt := battle.use_part(str(STARTER_PARTS["arms"]), lunge_rank)
		if not bool(receipt.get("ok", false)) or receipt.get("results", []).is_empty():
			continue
		var hit := bool(receipt["results"][0].get("hit", false))
		if require_hit and not hit:
			continue
		if require_miss and hit:
			continue
		return {
			"battle": battle, "receipt": receipt, "foe": str(target["id"]),
			"seed": seed_value, "hp_before": hp_before,
			"statuses_before": statuses_before, "snapshot_before": snapshot_before,
			"rng_before": rng_before, "feint": prepared["feint"],
		}
	return {}


## Every base damage number a receipt can carry: each seeded damage roll in the authored range,
## or the fixed crit value, plus the worn arms stat.
func _base_roll_candidates(ability: Dictionary, bonus: int, critical: bool) -> Array:
	var out: Array = []
	var damage := _int_list(ability.get("dmg", []))
	if damage.size() != 2:
		return out
	if critical:
		out.append(StitchedRules.crit_damage(damage[1]) + bonus)
		return out
	for value in range(damage[0], damage[1] + 1):
		out.append(value + bonus)
	return out


## The base rolls that reproduce a receipt's damage under the real mark -> Weak/Exposed ->
## Tangled -> PROT order.
func _matching_bases(bases: Array, statuses: Dictionary, marked: bool, mark_damage: int,
		prot: int, dealt: int) -> Array:
	var matched: Array = []
	for base in bases:
		if StitchedRules.damage_after_modifiers(base, {}, statuses, marked, mark_damage, prot) == dealt:
			matched.append(int(base))
	return matched


## Counterfactual ordering witness: the Exposed multiplier first, then the Mark bonus (before
## PROT). The real rules add the bonus first, so these differ whenever the witness is sound.
func _mark_after_exposed(base: int, statuses: Dictionary, mark_damage: int, prot: int) -> int:
	var damage := base
	if int(statuses.get("exposed", 0)) > 0:
		@warning_ignore("integer_division")
		var whole: int = damage / 2
		@warning_ignore("integer_division")
		var partial: int = (damage % 2) * 3 / 2
		damage = whole * 3 + partial
	damage += mark_damage
	if int(statuses.get("tangled", 0)) > 0 and damage > 0:
		damage += 2
	return StitchedRules.apply_protection(damage, prot)


# ---------------------------------------------------------------- value helpers

## Case-insensitive word tokens of a sentence, split on anything that is not a letter, so
## "cape-tail" yields "cape" and "tail" and prose like "patched"/"cuff" never matches "patch"/"cut".
func _whole_words(text: String) -> Array:
	var out: Array = []
	var current := ""
	var lower := text.to_lower()
	for index in range(lower.length()):
		var code := lower.unicode_at(index)
		if code >= 97 and code <= 122:
			current += lower[index]
		else:
			if not current.is_empty():
				out.append(current)
			current = ""
	if not current.is_empty():
		out.append(current)
	return out


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
