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

## The shipped legs starter whose tier III alone reaches enemy rank 4.
const TETHER_LOOP_PART := "seamstress_tether_loop_spools"

## S14 sewn-cloth appearance copy for the two head patches and the two arms patches. These are
## never cast promises: the Seamstress's four signature abilities live in
## data/stitched/s14_hero_abilities.json.
const MENDING_KNOT_ID := "seamstress_mending_knot_hat"
const SCARLET_KNOT_ID := "seamstress_scarlet_knot_hat"
const THREAD_PRICK_ID := "seamstress_thread_prick_needle"
const NEEDLE_RAIN_ID := "seamstress_needle_rain_needle"
const EXPECTED_MENDING_KNOT_TEXT := "A cream pincushion hat wears a dusty-purple darning knot, with red thread tucked beneath uneven brim stitches."
const EXPECTED_SCARLET_KNOT_TEXT := "A fat scarlet knot pins a torn plum felt brim to a cream patch, its loose red threads held by crooked cross-stitches."
## One oversized needle on cream cloth versus a fan of fine needles on plum felt.
const EXPECTED_THREAD_PRICK_TEXT := "The Seamstress's oversized silver needle is fastened to a cream sleeve with dark-red blanket stitches; a loose crimson thread trails from its eye."
const EXPECTED_NEEDLE_RAIN_TEXT := "A fan of slender silver needles rests across dusty-plum felt on the Seamstress's long sleeve, each shaft caught under cream stitches and red thread."
const ARMS_PATCH_IDS := [THREAD_PRICK_ID, NEEDLE_RAIN_ID]
## S14 sewn-cloth appearance copy for the two TORSO patches: a cream apron hem bound to a
## dusty-purple chest patch, and dried herbs sewn under a cream linen apron pocket. Like the
## head and arms rows these are appearance sentences, never part-cast promises.
const SHIELDING_HEM_ID := "seamstress_shielding_hem_coat"
const POULTICE_APRON_ID := "seamstress_poultice_apron"
const TORSO_PATCH_IDS := [SHIELDING_HEM_ID, POULTICE_APRON_ID]
const EXPECTED_SHIELDING_HEM_TEXT := "A cream apron-hem folds over a dusty-purple chest patch, with red running stitches binding its loose linen edges to the dress."
const EXPECTED_POULTICE_APRON_TEXT := "A small bundle of dried herbs is sewn beneath a cream linen apron pocket, tied to dusty-purple felt with a knotted red thread."
## The retired cast instructions the two torso patches used to print, kept only as witnesses.
const RETIRED_SHIELDING_HEM_TEXT := "Stitch a hem over one living ally: heal 2 and Guard the hits aimed at it for 2 turns."
const RETIRED_POULTICE_APRON_TEXT := "Darned herbs for one living ally: heal 3 and Guard it for 1 turn."
## Whole words that would turn this appearance copy back into an obsolete combat promise.
const FORBIDDEN_COPY_WORDS := [
	"ability", "cast", "rank", "ranks", "tier", "tiers", "heal", "heals", "hp",
	"bleed", "weak", "damage", "dodge", "guard", "stun", "move", "moves", "turn",
	"turns", "target", "foe", "ally", "strike", "attack",
]
## The brief's fuller forbidden vocabulary for the two torso sentences: every whole word that
## would still read as a part-granted combat instruction, rank/tier promise or ability outcome.
const TORSO_FORBIDDEN_COPY_WORDS := [
	"rank", "ranks", "tier", "tiers", "heal", "heals", "guard", "target", "targets",
	"foe", "foes", "ally", "allies", "attack", "attacks", "hit", "hits", "damage",
	"dodge", "bleed", "weak", "stun", "mark", "move", "moves", "ability", "abilities",
	"action", "actions", "turn", "turns", "buff", "buffs", "effect", "effects",
	"duration", "self", "cast",
]
## S14 sewn-cloth appearance copy for the two LEGS patches. The Seamstress's four fixed
## signature abilities live in data/stitched/s14_hero_abilities.json; these two records only
## describe the spools and bobbins sewn to her boots, never a part-granted snare.
const TETHER_SPOOLS_ID := "seamstress_tether_loop_spools"
const BOBBIN_SNAG_ID := "seamstress_bobbin_snag_spools"
const LEG_PATCH_IDS := [TETHER_SPOOLS_ID, BOBBIN_SNAG_ID]
const EXPECTED_TETHER_SPOOLS_TEXT := "Two cream spools are stitched to a dusty-purple boot cuff, their scarlet threads looped together beneath a crooked silver pin."
const EXPECTED_BOBBIN_SNAG_TEXT := "Three mismatched plum bobbins crowd a cream ankle patch, with loose red thread snagged beneath uneven cross-stitches."
## The retired cast instructions the two leg patches used to print, kept only as witnesses.
const RETIRED_TETHER_SPOOLS_TEXT := "Loop trailing thread around one foe in ranks 1-3 for Tangled 2; at stitch tier III reach rank 4 with Tangled 3."
const RETIRED_BOBBIN_SNAG_TEXT := "Snag one foe in ranks 1-3 on knotted bobbins: Mark 2 and Tangled 2."
const RETIRED_BOBBIN_SNAG_TIER_TEXT := "Snag one foe in ranks 1-3 on knotted bobbins: Mark 3 and Tangled 2."
## Whole words that would turn a leg appearance sentence back into an obsolete part-action
## promise. Matched whole (and after splitting hyphens) so ordinary cloth words never trip it.
const LEG_FORBIDDEN_COPY_WORDS := [
	"rank", "ranks", "tier", "tiers", "foe", "foes", "enemy", "enemies",
	"tangled", "mark", "marks", "damage", "dodge", "ability", "abilities",
	"skill", "skills", "target", "targets", "cast", "casts", "attack", "attacks",
	"heal", "heals", "turn", "turns",
]

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
			{"bleed": 2, "weak": 2},
			{"bleed": 3, "weak": 2},
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
		# Tether Loop is the one tier-scaled reach in this kit: tiers I and II stay on the
		# front ranks [1, 2, 3] and ONLY tier III adds enemy rank 4.
		"target_by_tier": [[1, 2, 3], [1, 2, 3], [1, 2, 3, 4]],
		"multi": false,
		"acc": 90,
		"mark": [0, 0, 0],
		"dmg": [[0, 0], [0, 0], [0, 0]],
		"effects": [{"tangled": 2}, {"tangled": 2}, {"tangled": 3}],
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
			{"mark": 2, "tangled": 2},
			{"mark": 2, "tangled": 2},
			{"mark": 3, "tangled": 2},
		],
	},
}

var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	_test_catalog()
	_test_torso_patch_appearance_text()
	_test_leg_patch_appearance_text()
	_test_tiers()
	_test_live_tier_stats()
	_test_negatives()
	_test_live_starters()
	_test_scarlet_knot_timeline()
	_test_scarlet_knot_rejections()
	_test_live_rejections()
	_test_needle_rain_multi()
	_test_needle_rain_mark_bonus()
	_test_bobbin_needle_followup()
	_test_needle_rain_rear_launch()
	_test_needle_rain_rejections()
	_test_rear_launch_masks()
	_test_rear_rank_support()
	_test_rear_illegal_forward_launch()
	_test_rear_tether_reach()
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
	var mending_text := str(by_id[MENDING_KNOT_ID]["text"])
	var scarlet_text := str(by_id[SCARLET_KNOT_ID]["text"])
	_check(mending_text == EXPECTED_MENDING_KNOT_TEXT,
		"AC1: Mending Knot Hat keeps its exact authored sewn-cloth description")
	_check(scarlet_text == EXPECTED_SCARLET_KNOT_TEXT,
		"AC1: Scarlet Knot Hat keeps its exact authored sewn-cloth description")
	_check(mending_text != scarlet_text,
		"AC2: the two head patches describe visually distinct sewn cloth")
	for head_id in [MENDING_KNOT_ID, SCARLET_KNOT_ID]:
		_check(str(by_id[head_id]["owner"]) == OWNER and str(by_id[head_id]["slot"]) == "head",
			"AC1: " + head_id + " stays a seamstress head patch")
		_check(str(by_id[head_id]["name"]) == str(EXPECTED[head_id]["name"]),
			"AC1: " + head_id + " keeps its authored name")
		_check(bool(StitchedParts.validate_part(by_id[head_id]).get("ok", false)),
			"AC1: " + head_id + " still validates with its sewn-cloth description")
	var mending_low := mending_text.to_lower()
	var scarlet_low := scarlet_text.to_lower()
	_check((mending_low.contains("hat") or mending_low.contains("brim"))
		and (mending_low.contains("thread") or mending_low.contains("stitches"))
		and (mending_low.contains("cream") or mending_low.contains("plum")
			or mending_low.contains("scarlet") or mending_low.contains("purple")),
		"AC2: Mending Knot text names a stitched cream/plum/scarlet/purple hat or brim")
	_check((scarlet_low.contains("hat") or scarlet_low.contains("brim"))
		and (scarlet_low.contains("thread") or scarlet_low.contains("stitches"))
		and (scarlet_low.contains("cream") or scarlet_low.contains("plum")
			or scarlet_low.contains("scarlet") or scarlet_low.contains("purple")),
		"AC2: Scarlet Knot text names a stitched cream/plum/scarlet/purple hat or brim")
	for word in FORBIDDEN_COPY_WORDS:
		_check(not _contains_whole_word(mending_low, word),
			"AC2: Mending Knot cloth copy never names the combat word " + word)
		_check(not _contains_whole_word(scarlet_low, word),
			"AC2: Scarlet Knot cloth copy never names the combat word " + word)
	_check(not _contains_digit(mending_low) and not _contains_digit(scarlet_low),
		"AC2: both head-patch descriptions contain no numeric combat digits")
	# The two ARMS patches carry the same S14 sewn-cloth treatment: one oversized needle on cream
	# cloth versus a fan of fine needles on plum felt. Neither describes a part-ability outcome,
	# even though the historic stat/ability numbers stay authored above.
	var prick_text := str(by_id[THREAD_PRICK_ID]["text"])
	var rain_text := str(by_id[NEEDLE_RAIN_ID]["text"])
	_check(prick_text == EXPECTED_THREAD_PRICK_TEXT,
		"AC1: Thread Prick Needle carries its exact authored sewn-cloth description")
	_check(rain_text == EXPECTED_NEEDLE_RAIN_TEXT,
		"AC1: Needle Rain Needle carries its exact authored sewn-cloth description")
	_check(prick_text != rain_text,
		"AC2: the two arms patches describe visually distinct sewn cloth")
	for arms_id in ARMS_PATCH_IDS:
		_check(str(by_id[arms_id]["owner"]) == OWNER and str(by_id[arms_id]["slot"]) == "arms",
			"AC1: " + arms_id + " stays a seamstress arms patch")
		_check(str(by_id[arms_id]["name"]) == str(EXPECTED[arms_id]["name"]),
			"AC1: " + arms_id + " keeps its authored name")
		_check(bool(StitchedParts.validate_part(by_id[arms_id]).get("ok", false)),
			"AC1: " + arms_id + " still validates with its sewn-cloth description")
	var prick_low := prick_text.to_lower()
	var rain_low := rain_text.to_lower()
	_check(prick_low.contains("needle") and prick_low.contains("sleeve")
		and prick_low.contains("cream") and prick_low.contains("thread"),
		"AC1: Thread Prick text names one silver needle, a cream sleeve and trailing thread")
	_check(rain_low.contains("needles") and rain_low.contains("felt")
		and rain_low.contains("plum") and rain_low.contains("stitches"),
		"AC1: Needle Rain text names several slender needles on dusty-plum felt under stitches")
	_check(not prick_low.contains("needles") and not rain_low.contains("oversized"),
		"AC1: the single-needle and many-needle descriptions stay visually distinct")
	for word in FORBIDDEN_COPY_WORDS:
		_check(not _contains_whole_word(prick_low, word),
			"AC2: Thread Prick cloth copy never names the combat word " + word)
		_check(not _contains_whole_word(rain_low, word),
			"AC2: Needle Rain cloth copy never names the combat word " + word)
	_check(not _contains_digit(prick_low) and not _contains_digit(rain_low),
		"AC2: both arms-patch descriptions contain no numeric combat digits")
	var raw: Variant = _read_json(PARTS_PATH)
	if raw is Dictionary:
		var document: Dictionary = raw
		_check(int(document.get("version", 0)) == 1, "AC1: the parts file keeps the version-1 schema")
		var raw_parts: Variant = document.get("parts")
		_check(raw_parts is Array and raw_parts.size() == ALL_PART_IDS.size(),
			"AC1: the authored parts array holds exactly the eight named wearables")
		if raw_parts is Array:
			for arms_id in ARMS_PATCH_IDS:
				var raw_arms := _raw_part_for(raw_parts, arms_id)
				_check(not raw_arms.is_empty(), "AC3: the raw JSON authors the " + arms_id + " record")
				if raw_arms.is_empty():
					continue
				var expected_raw_text := EXPECTED_THREAD_PRICK_TEXT if arms_id == THREAD_PRICK_ID else EXPECTED_NEEDLE_RAIN_TEXT
				_check(str(raw_arms.get("text", "")) == expected_raw_text,
					"AC1: the raw " + arms_id + " text is exactly the authored sewn-cloth sentence")
				_check(_int_dict(raw_arms.get("stat", {})) == {"dmg": 1},
					"AC3: the raw " + arms_id + " keeps its authored dmg 1 stat")
				var raw_arms_ability: Dictionary = raw_arms.get("ability", {})
				_check(str(raw_arms_ability.get("id", "")) == str(EXPECTED[arms_id]["ability_id"]),
					"AC3: the raw " + arms_id + " keeps its complete legacy ability object")
				var raw_arms_tiers: Dictionary = raw_arms.get("tiers", {})
				_check(raw_arms_tiers.has("2") and raw_arms_tiers.has("3"),
					"AC3: the raw " + arms_id + " keeps both authored tier overrides")
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


# ---------------------------------------------------------------- AC1/AC2: torso sewn patches

## The two TORSO wearables now read as sewn cloth patches, exactly like the head and arms rows.
## The legacy stat/ability/tier dictionaries above are compatibility contracts and are proven by
## _test_catalog/_test_tiers; this helper only proves the two top-level appearance sentences.
func _test_torso_patch_appearance_text() -> void:
	var catalog := _catalog()
	_check(bool(catalog.get("ok", false)),
		"AC1: the Seamstress catalog loads for the torso patch appearance contract")
	if not bool(catalog.get("ok", false)):
		return
	var by_id: Dictionary = catalog["by_id"]
	var expected := {
		SHIELDING_HEM_ID: EXPECTED_SHIELDING_HEM_TEXT,
		POULTICE_APRON_ID: EXPECTED_POULTICE_APRON_TEXT,
	}
	var retired := {
		SHIELDING_HEM_ID: RETIRED_SHIELDING_HEM_TEXT,
		POULTICE_APRON_ID: RETIRED_POULTICE_APRON_TEXT,
	}
	for part_id in TORSO_PATCH_IDS:
		_check(by_id.has(part_id), "AC1: the catalog authors the torso patch " + part_id)
		if not by_id.has(part_id):
			continue
		var part: Dictionary = by_id[part_id]
		var spec: Dictionary = EXPECTED[part_id]
		var want := str(expected[part_id])
		_check(str(part["id"]) == part_id, "AC1: " + part_id + " keeps its authored id")
		_check(str(part["name"]) == str(spec["name"]), "AC1: " + part_id + " keeps its authored name")
		_check(str(part["owner"]) == OWNER and str(part["slot"]) == "torso",
			"AC1: " + part_id + " stays a seamstress torso patch")
		_check(bool(StitchedParts.validate_part(part).get("ok", false)),
			"AC1: " + part_id + " still validates with its sewn-patch description")
		_check(str(part["text"]) == want,
			"AC1: " + part_id + " carries its exact authored sewn-patch description")
		# The retired healing/Guard instruction survives nowhere on this record.
		_check(not str(part["text"]).contains(str(retired[part_id])),
			"AC2: " + part_id + " no longer prints its retired cast instruction")
		# Materials and palette: matte cream linen, dusty purple felt and red thread on both.
		var low := str(part["text"]).to_lower()
		for word in ["cream", "dusty", "purple", "red", "linen"]:
			_check(_contains_whole_word(low, word),
				"AC2: " + part_id + " names the cloth word " + word)
		var sewn_context := false
		for word in ["patch", "stitches", "sewn"]:
			if _contains_whole_word(low, word):
				sewn_context = true
		_check(sewn_context, "AC2: " + part_id + " names a visible sewn patch, stitches or seam")
		# No numeric combat digits and no whole-word combat promise of any kind.
		_check(not _contains_digit(low),
			"AC2: " + part_id + " cloth copy contains no numeric digits")
		for word in TORSO_FORBIDDEN_COPY_WORDS:
			_check(not _contains_whole_word(low, word),
				"AC2: " + part_id + " cloth copy never names the combat word " + word)
	# The two torso patches describe different garments, not the same sentence twice.
	_check(str(by_id[SHIELDING_HEM_ID]["text"]) != str(by_id[POULTICE_APRON_ID]["text"]),
		"AC2: the two torso patches describe visually distinct sewn cloth")
	# Per-patch physical details, split on the hyphenated cloth words apron-hem / dusty-purple.
	var hem_low := str(by_id[SHIELDING_HEM_ID]["text"]).to_lower()
	for word in ["chest", "patch", "apron", "stitches", "dress"]:
		_check(_contains_whole_word(hem_low, word),
			"AC2: the Shielding Hem patch names the sewn detail " + word)
	var apron_low := str(by_id[POULTICE_APRON_ID]["text"]).to_lower()
	for word in ["herbs", "sewn", "apron", "pocket", "felt", "thread"]:
		_check(_contains_whole_word(apron_low, word),
			"AC2: the Poultice patch names the sewn detail " + word)
	# Neither retired sentence reappears anywhere in the eight authored texts, and no other
	# record duplicates either new sentence.
	for part_id in ALL_PART_IDS:
		if not by_id.has(part_id):
			continue
		var text := str(by_id[part_id]["text"])
		for retired_id in TORSO_PATCH_IDS:
			_check(not text.contains(str(retired[retired_id])),
				"AC2: %s does not reprint the retired %s instruction" % [part_id, retired_id])
		if part_id in TORSO_PATCH_IDS:
			continue
		_check(text != EXPECTED_SHIELDING_HEM_TEXT and text != EXPECTED_POULTICE_APRON_TEXT,
			"AC2: the other " + part_id + " does not duplicate a torso patch sentence")
	# Required appearance text still fails closed on a deep clone of each real part, and the
	# shipped record is left untouched by the rejected validations.
	for part_id in TORSO_PATCH_IDS:
		var shipped_text := str(by_id[part_id]["text"])
		for blank in ["", "   "]:
			var blanked: Dictionary = by_id[part_id].duplicate(true)
			blanked["text"] = blank
			_check(not bool(StitchedParts.validate_part(blanked).get("ok", false)),
				"AC3: %s with %s top-level text is refused" % [part_id, "blank" if blank.is_empty() else "whitespace-only"])
		var after: Dictionary = by_id[part_id]
		_check(str(after["text"]) == shipped_text,
			"AC3: the rejected blank text never changes the shipped " + part_id + " record")
		_check(_int_dict(StitchedParts.stat_at_tier(after, 1)) == _int_dict({str(EXPECTED[part_id]["stat_key"]): int(EXPECTED[part_id]["stat"][0])})
			and str(after["ability"]["id"]) == str(EXPECTED[part_id]["ability_id"]),
			"AC3: " + part_id + " keeps its legacy tier-I stat and ability after the validation")


# ---------------------------------------------------------------- AC1/AC2/AC3: leg sewn patches

## Both LEGS wearables now read as sewn spool patches, exactly like the head, arms and torso rows.
## Their legacy stat/ability/tier dictionaries above stay as compatibility contracts and are
## proven by _test_catalog/_test_tiers/_test_snare_timelines; this helper proves the two top-level
## appearance sentences, the tier-resolved copy, and the raw JSON shape of Bobbin's tier III.
func _test_leg_patch_appearance_text() -> void:
	var catalog := _catalog()
	_check(bool(catalog.get("ok", false)),
		"AC1: the Seamstress catalog loads for the leg patch appearance contract")
	if not bool(catalog.get("ok", false)):
		return
	var by_id: Dictionary = catalog["by_id"]
	var expected := {
		TETHER_SPOOLS_ID: {
			"name": "Tether Loop Spools", "text": EXPECTED_TETHER_SPOOLS_TEXT,
			"retired": RETIRED_TETHER_SPOOLS_TEXT,
			"motifs": ["cream", "spools", "stitched", "dusty", "purple", "boot",
				"cuff", "scarlet", "threads", "silver", "pin"],
		},
		BOBBIN_SNAG_ID: {
			"name": "Bobbin Snag Spools", "text": EXPECTED_BOBBIN_SNAG_TEXT,
			"retired": RETIRED_BOBBIN_SNAG_TEXT,
			"motifs": ["plum", "bobbins", "cream", "ankle", "patch", "red",
				"thread", "cross", "stitches"],
		},
	}
	for part_id in LEG_PATCH_IDS:
		_check(by_id.has(part_id), "AC1: the catalog authors the leg patch " + part_id)
		if not by_id.has(part_id):
			continue
		var part: Dictionary = by_id[part_id]
		var spec: Dictionary = expected[part_id]
		var spec_numbers: Dictionary = EXPECTED[part_id]
		var want := str(spec["text"])
		_check(str(part["id"]) == part_id, "AC1: " + part_id + " keeps its authored id")
		_check(str(part["name"]) == str(spec["name"]), "AC1: " + part_id + " keeps its authored name")
		_check(str(part["owner"]) == OWNER and str(part["slot"]) == "legs",
			"AC1: " + part_id + " stays a seamstress legs patch")
		_check(bool(StitchedParts.validate_part(part).get("ok", false)),
			"AC1: " + part_id + " still validates with its sewn-patch description")
		_check(str(part["text"]) == want,
			"AC1: " + part_id + " carries its exact authored sewn-patch description")
		# The retired spool-snare instruction survives nowhere on this record.
		_check(not str(part["text"]).contains(str(spec["retired"])),
			"AC2: " + part_id + " no longer prints its retired cast instruction")
		# Materials and palette: cream spools on a purple boot cuff, plum bobbins on a cream patch.
		var low := str(part["text"]).to_lower()
		for word in spec["motifs"]:
			_check(_contains_whole_word(low, str(word)),
				"AC2: " + part_id + " names the sewn detail " + str(word))
		_check(_leg_copy_violation(low).is_empty(),
			"AC2: %s promises no rank/tier/status/action/number (%s)"
				% [part_id, _leg_copy_violation(low)])
		# Compatibility only: every legacy stat, ability and tier number stays exactly as shipped.
		_check(_int_dict(part["stat"])
			== {str(spec_numbers["stat_key"]): int(spec_numbers["stat"][0])},
			"AC3: " + part_id + " keeps its tier-I stat")
		_check(str(part["ability"]["id"]) == str(spec_numbers["ability_id"])
			and _int_list(part["ability"]["launch"]) == _int_list(spec_numbers["launch"])
			and _int_list(part["ability"]["target"]) == _int_list(spec_numbers["target"])
			and _int_dict(part["ability"]["effects"])
				== _int_dict(spec_numbers["effects"][0]),
			"AC3: " + part_id + " keeps its legacy ability id, ranks and effects")
		_check(_int_dict(StitchedParts.stat_at_tier(part, 3))
			== {str(spec_numbers["stat_key"]): int(spec_numbers["stat"][2])}
			and _int_dict(StitchedParts.ability_at_tier(part, 3)["effects"])
				== _int_dict(spec_numbers["effects"][2]),
			"AC3: " + part_id + " keeps its tier-III stat and effect numbers")
		# Every tier's appearance copy resolves to the new base sentence through the runtime cue
		# helper, including Bobbin tier III now that its obsolete tier text override is gone.
		for tier in [1, 2, 3]:
			var cue := StitchedPartActionCues.format_action(
				{"id": "seamstress", "name": "Seamstress", "rank": 2},
				"legs", {"id": part_id, "tier": tier, "torn": false}, by_id, true, "")
			var full := str(cue.get("full", ""))
			_check(full.contains(want),
				"AC2: %s tier %d resolves the new base patch sentence" % [part_id, tier])
			_check(not full.contains(str(spec["retired"]))
				and not full.contains(RETIRED_BOBBIN_SNAG_TIER_TEXT),
				"AC2: %s tier %d resolves no retired cast instruction" % [part_id, tier])
		# Deep-copy fail-closed: a blank patch description is still refused, and the shipped
		# record is left untouched by the rejected validations.
		var shipped_text := str(part["text"])
		for blank in ["", "   "]:
			var blanked: Dictionary = part.duplicate(true)
			blanked["text"] = blank
			_check(not bool(StitchedParts.validate_part(blanked).get("ok", false)),
				"AC3: %s with %s top-level text is refused"
					% [part_id, "blank" if blank.is_empty() else "whitespace-only"])
		_check(str(by_id[part_id]["text"]) == shipped_text,
			"AC3: the rejected blank text never changes the shipped " + part_id + " record")
	# The two leg patches describe different spool clusters, not the same sentence twice, and no
	# other part reprints either new sentence.
	var tether_low := str(by_id[TETHER_SPOOLS_ID]["text"]).to_lower()
	var bobbin_low := str(by_id[BOBBIN_SNAG_ID]["text"]).to_lower()
	_check(tether_low != bobbin_low,
		"AC2: the two leg patches describe visually distinct sewn cloth")
	_check(_contains_whole_word(tether_low, "spools") and _contains_whole_word(tether_low, "boot")
		and _contains_whole_word(tether_low, "pin") and _contains_whole_word(tether_low, "cuff"),
		"AC2: Tether Loop names its cream spools, boot cuff and crooked silver pin")
	_check(_contains_whole_word(bobbin_low, "bobbins") and _contains_whole_word(bobbin_low, "ankle")
		and _contains_whole_word(bobbin_low, "stitches"),
		"AC2: Bobbin Snag names its plum bobbins, ankle patch and uneven cross-stitches")
	_check(not _contains_whole_word(tether_low, "bobbins")
		and not _contains_whole_word(bobbin_low, "spools")
		and not _contains_whole_word(bobbin_low, "pin"),
		"AC2: the spool-cluster and bobbin-cluster descriptions stay visually distinct")
	for part_id in ALL_PART_IDS:
		if part_id in LEG_PATCH_IDS or not by_id.has(part_id):
			continue
		var other := str(by_id[part_id]["text"])
		_check(other != EXPECTED_TETHER_SPOOLS_TEXT and other != EXPECTED_BOBBIN_SNAG_TEXT,
			"AC2: the other " + part_id + " does not duplicate a leg patch sentence")
	# The whole-word gate is proven, not vacuous: every retired instruction and a plain digit fail
	# it, while ordinary stitched-cloth prose never trips on an accidental substring.
	for retired in [RETIRED_TETHER_SPOOLS_TEXT, RETIRED_BOBBIN_SNAG_TEXT,
			RETIRED_BOBBIN_SNAG_TIER_TEXT]:
		_check(not _leg_copy_violation(str(retired).to_lower()).is_empty(),
			"AC2: the retired leg cast instruction fails the appearance gate: " + str(retired))
	_check(not _leg_copy_violation("The patch holds 2 spools.").is_empty(),
		"AC2: a stated digit fails the leg appearance gate")
	_check(_leg_copy_violation("Two cream spools looped on a dusty-purple boot cuff.").is_empty(),
		"AC2: plain stitched-spool prose passes the leg appearance gate")
	# Raw JSON: both new sentences are authored verbatim, and Bobbin's tier-III object stays with
	# its stat/ability numbers but no text field.
	var raw: Variant = _read_json(PARTS_PATH)
	if raw is Dictionary:
		var document: Dictionary = raw
		var raw_parts: Variant = document.get("parts")
		_check(raw_parts is Array, "AC3: the raw parts file holds the authored parts array")
		if raw_parts is Array:
			var raw_tether := _raw_part_for(raw_parts, TETHER_SPOOLS_ID)
			var raw_bobbin := _raw_part_for(raw_parts, BOBBIN_SNAG_ID)
			_check(not raw_tether.is_empty() and not raw_bobbin.is_empty(),
				"AC1: the raw JSON authors both leg records")
			var tether_index := _raw_index_of(raw_parts, TETHER_SPOOLS_ID)
			var bobbin_index := _raw_index_of(raw_parts, BOBBIN_SNAG_ID)
			_check(tether_index >= 0 and bobbin_index == tether_index + 1,
				"AC3: the two legs records keep their authored adjacent order")
			if not raw_tether.is_empty() and not raw_bobbin.is_empty():
				_check(str(raw_tether.get("text", "")) == EXPECTED_TETHER_SPOOLS_TEXT,
					"AC1: the raw Tether Loop text is exactly the new sewn-cloth sentence")
				_check(str(raw_bobbin.get("text", "")) == EXPECTED_BOBBIN_SNAG_TEXT,
					"AC1: the raw Bobbin Snag text is exactly the new sewn-cloth sentence")
				var raw_tiers: Dictionary = raw_bobbin.get("tiers", {})
				var raw_third: Dictionary = raw_tiers.get("3", {})
				_check(not raw_third.is_empty(),
					"AC2: the raw Bobbin Snag tier-III object is retained")
				_check(not raw_third.has("text"),
					"AC2: the raw Bobbin Snag tier-III override carries no text field")
				var raw_third_stat: Dictionary = raw_third.get("stat", {})
				var raw_third_ability: Dictionary = raw_third.get("ability", {})
				_check(_int_dict(raw_third_stat) == {"dodge": 5},
					"AC2: the raw Bobbin Snag tier-III stat stays Dodge 5")
				var raw_third_effects: Dictionary = raw_third_ability.get("effects", {})
				_check(_int_dict(raw_third_effects) == {"mark": 3, "tangled": 2},
					"AC2: the raw Bobbin Snag tier-III effects stay Mark 3 and Tangled 2")
				var tether_tiers: Dictionary = raw_tether.get("tiers", {})
				var tether_third: Dictionary = tether_tiers.get("3", {})
				var bobbin_second: Dictionary = raw_tiers.get("2", {})
				_check(not tether_third.has("text") and not bobbin_second.has("text"),
					"AC2: no other leg tier override prints obsolete tier text")


## The first whole-word combat promise or numeric digit in a leg-patch sentence, or "" when the
## copy is pure stitched-cloth appearance. The retired instructions are run through it so the gate
## is proven to catch real violations rather than passing on an empty list.
func _leg_copy_violation(lowered: String) -> String:
	if _contains_digit(lowered):
		return "digit"
	for word in LEG_FORBIDDEN_COPY_WORDS:
		if _contains_whole_word(lowered, word):
			return word
	return ""


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
			# Only the parts that author a per-tier reach (the Tether Loop's tier-III rear rank)
			# deviate from their base target array; every other part keeps spec["target"].
			var tier_target: Array = spec["target"]
			if spec.has("target_by_tier"):
				tier_target = spec["target_by_tier"][tier - 1]
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
			_check(_int_list(ability["target"]) == _int_list(tier_target), "AC3: " + tag + " target ranks")
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
				_check(StitchedParts.ranks_allowed(target_mask, rank) == (rank in tier_target),
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
			if part_id == "seamstress_tether_loop_spools" and tier == 2:
				_check(_int_dict(part["tiers"]["2"]["ability"]["effects"]) == {"tangled": 2},
					"AC3: tier-II Tether explicitly retains Tangled 2 while its speed stat rises")
			elif part_id == "seamstress_bobbin_snag_spools" and tier == 2:
				_check(_int_dict(part["tiers"]["2"]["ability"]["effects"])
					== {"mark": 2, "tangled": 2}
					and int(part["tiers"]["2"]["stat"]["dodge"]) == 4,
					"AC3: tier-II Bobbin explicitly retains Mark 2/Tangled 2 while Dodge rises to 4")
			else:
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
	# The S14 appearance copy is still required rules text: a blank top-level text fails closed.
	for head_id in [MENDING_KNOT_ID, SCARLET_KNOT_ID]:
		var blanked: Dictionary = by_id[head_id].duplicate(true)
		blanked["text"] = ""
		_check(not bool(StitchedParts.validate_part(blanked).get("ok", false)),
			"AC3: " + head_id + " with blank top-level text is refused")
	# The two ARMS patches carry required sewn-cloth text too: blanking either one fails closed.
	for arms_id in ARMS_PATCH_IDS:
		var blanked_arms: Dictionary = by_id[arms_id].duplicate(true)
		blanked_arms["text"] = ""
		_check(not bool(StitchedParts.validate_part(blanked_arms).get("ok", false)),
			"AC3: " + arms_id + " with blank top-level text is refused")
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
	_test_snare_timelines()
	_test_snare_rejections()
	_heal_witness(false)
	_heal_witness(true)


## The alternate head is really worn by the rank-2 Seamstress. All trials use the
## shipped four-hero/three-foe preview and normal turn sequencing, never a stand-in cast.
func _scarlet_trial(seed_value: int, tier: int) -> Dictionary:
	var kit := STARTER_PARTS.duplicate(true)
	kit["head"] = "seamstress_scarlet_knot_hat"
	var battle := _build_battle(seed_value, tier, kit, false)
	if battle == null or battle.get_heroes().size() != 4 or battle.get_foes().size() != 3:
		return {}
	if not _to(battle, "seamstress"):
		return {}
	var wearer := battle.get_unit("seamstress")
	var foe := battle.get_unit("fray_scavenger")
	if int(wearer.get("rank", 0)) != 2 or _worn_part_id(wearer, "seamstress_scarlet_knot_hat") != "seamstress_scarlet_knot_hat":
		return {}
	if int(foe.get("rank", 0)) != 1 or int(foe.get("hp", 0)) <= 0:
		return {}
	if foe["statuses"].has("bleed") or foe["statuses"].has("weak"):
		return {}
	var before := battle.state_snapshot()
	var rng_before := battle.rng_state()
	var receipt := battle.use_part("seamstress_scarlet_knot_hat", 1)
	var results: Array = receipt.get("results", [])
	if not bool(receipt.get("ok", false)) or results.size() != 1:
		return {}
	if str(receipt.get("actor", "")) != "seamstress" or str(receipt.get("part", "")) != "seamstress_scarlet_knot_hat":
		return {}
	if str(results[0].get("target", "")) != "fray_scavenger" or str(results[0].get("target_side", "")) != "foe":
		return {}
	return {
		"battle": battle, "receipt": receipt, "seed": seed_value,
		"before": before, "rng_before": rng_before, "before_foe": foe,
		"after_cast": battle.state_snapshot(), "rng_after_cast": battle.rng_state(),
	}


## A bounded seed search must exhibit BOTH a real Scarlet Knot hit and a later
## landed Sack Swing with measurably lower damage than an equal-seed control.
## The sole control mutation is removing Weak immediately before that attack.
func _test_scarlet_knot_timeline() -> void:
	for tier in [1, 2, 3]:
		var label := "Scarlet Knot tier %d" % tier
		var expected_bleed: int = tier + 1
		var witness: Dictionary = {}
		for seed_value in range(1, 256):
			var trial := _scarlet_trial(seed_value, tier)
			if trial.is_empty():
				continue
			var cast: Dictionary = trial["receipt"]
			var cast_result: Dictionary = cast["results"][0]
			if not bool(cast_result.get("hit", false)):
				continue
			var battle: StitchedRules = trial["battle"]
			var foe := battle.get_unit("fray_scavenger")
			if int(foe["statuses"].get("weak", 0)) != 2 or int(foe["statuses"].get("bleed", 0)) != expected_bleed:
				continue
			var control := _scarlet_trial(seed_value, tier)
			if control.is_empty() or control["receipt"] != cast or control["after_cast"] != trial["after_cast"]:
				continue
			var normal: StitchedRules = control["battle"]
			if not _to(battle, "fray_scavenger") or not _to(normal, "fray_scavenger"):
				continue
			var turn_start := battle.get_unit("fray_scavenger")
			var untouched_start := normal.state_snapshot()
			var untouched_rng := normal.rng_state()
			if turn_start != normal.get_unit("fray_scavenger") or battle.state_snapshot() != untouched_start or battle.rng_state() != untouched_rng:
				continue
			if int(turn_start["statuses"].get("weak", 0)) != 1 or int(turn_start["statuses"].get("bleed", 0)) != expected_bleed - 1:
				continue
			if int(turn_start["hp"]) != int(trial["before_foe"]["hp"]) - expected_bleed:
				continue
			var warden_before: int = int(battle.get_unit("warden")["hp"])
			normal._units["fray_scavenger"]["statuses"].erase("weak")
			var weakened_attack := battle.use_foe_ability("sack_swing", 1)
			var normal_attack := normal.use_foe_ability("sack_swing", 1)
			if not bool(weakened_attack.get("ok", false)) or not bool(normal_attack.get("ok", false)):
				continue
			if weakened_attack.get("results", []).size() != 1 or normal_attack.get("results", []).size() != 1:
				continue
			var weaker: Dictionary = weakened_attack["results"][0]
			var stronger: Dictionary = normal_attack["results"][0]
			if not bool(weaker.get("hit", false)) or not bool(stronger.get("hit", false)):
				continue
			if str(weaker.get("target", "")) != "warden" or str(stronger.get("target", "")) != "warden":
				continue
			if int(weaker.get("damage", -1)) >= int(stronger.get("damage", -1)):
				continue
			witness = {
				"trial": trial, "control": control, "cast_result": cast_result,
				"turn_start": turn_start, "pre_attack_snapshot": untouched_start,
				"pre_attack_rng": untouched_rng, "warden_before": warden_before,
				"weakened_attack": weakened_attack, "normal_attack": normal_attack,
			}
			break
		_check(not witness.is_empty(), "AC2: bounded equal-seed " + label + " lands its cast and a damage-reduced Sack Swing")
		if witness.is_empty():
			continue
		var trial: Dictionary = witness["trial"]
		var battle: StitchedRules = trial["battle"]
		var control: StitchedRules = witness["control"]["battle"]
		var cast_result: Dictionary = witness["cast_result"]
		var cast: Dictionary = trial["receipt"]
		var weakened_attack: Dictionary = witness["weakened_attack"]
		var normal_attack: Dictionary = witness["normal_attack"]
		var weaker: Dictionary = weakened_attack["results"][0]
		var stronger: Dictionary = normal_attack["results"][0]
		_check(bool(cast_result["hit"]) and cast_result.has("roll") and cast_result.has("hit_chance")
			and int(cast_result["roll"]) <= int(cast_result["hit_chance"])
			and str(cast.get("ability", "")) == "scarlet_knot",
			"AC2: " + label + " genuinely rolls a hit with the equipped head")
		_check(_status_duration(cast_result.get("statuses", []), "bleed") == expected_bleed
			and _status_duration(cast_result.get("statuses", []), "weak") == 2,
			"AC2: " + label + " cast receipt reports Bleed and Weak 2")
		_check(int(witness["turn_start"]["hp"]) == int(trial["before_foe"]["hp"]) - expected_bleed
			and int(witness["turn_start"]["statuses"].get("bleed", 0)) == expected_bleed - 1
			and int(witness["turn_start"]["statuses"].get("weak", 0)) == 1,
			"AC2: " + label + " takes the normal Bleed tick while Weak survives its first foe turn-start")
		_check(witness["control"]["receipt"] == cast
			and witness["control"]["after_cast"] == trial["after_cast"]
			and witness["control"]["rng_after_cast"] == trial["rng_after_cast"]
			and witness["control"]["before"] == trial["before"]
			and witness["control"]["rng_before"] == trial["rng_before"],
			"AC3: " + label + " starts with identical casts, full state, and RNG")
		_check(weaker.has("roll") and stronger.has("roll")
			and int(weaker["roll"]) == int(stronger["roll"])
			and int(weaker["damage"]) < int(stronger["damage"])
			and battle.rng_state() == control.rng_state(),
			"AC2: matched landed Sack Swings share a roll/RNG but Weak lowers damage")
		_check(int(battle.get_unit("warden")["hp"]) == int(witness["warden_before"]) - int(weaker["damage"])
			and int(control.get_unit("warden")["hp"]) == int(witness["warden_before"]) - int(stronger["damage"]),
			"AC2: the reduced Sack Swing damages the actual rank-1 Warden less")
		_check(int(battle.get_unit("fray_scavenger")["statuses"].get("weak", 0)) == 1,
			"AC2: " + label + " remains Weak during its landed strike")
		var previous_hp: int = int(battle.get_unit("fray_scavenger")["hp"])
		var following := _to(battle, "fray_scavenger")
		_check(following and battle.current_actor_id() == "fray_scavenger",
			"AC2: " + label + " reaches the same foe's following actual turn")
		if not following:
			continue
		_check(not battle.get_unit("fray_scavenger")["statuses"].has("weak")
			and int(battle.get_unit("fray_scavenger")["hp"]) == previous_hp - (expected_bleed - 1),
			"AC2: unrefreshed Weak expires on the following foe turn with its next normal Bleed tick")
		var replay := _scarlet_trial(int(trial["seed"]), tier)
		_check(not replay.is_empty(), "AC3: " + label + " can rebuild its full seeded replay")
		if replay.is_empty():
			continue
		var replay_battle: StitchedRules = replay["battle"]
		var replay_reached := _to(replay_battle, "fray_scavenger")
		var replay_attack := replay_battle.use_foe_ability("sack_swing", 1) if replay_reached else {}
		var replay_following := _to(replay_battle, "fray_scavenger") if bool(replay_attack.get("ok", false)) else false
		_check(replay["before"] == trial["before"] and replay["rng_before"] == trial["rng_before"]
			and replay["receipt"] == cast and replay["after_cast"] == trial["after_cast"]
			and replay["rng_after_cast"] == trial["rng_after_cast"]
			and replay_reached and replay_attack == weakened_attack and replay_following
			and replay_battle.state_snapshot() == battle.state_snapshot()
			and replay_battle.rng_state() == battle.rng_state(),
			"AC3: " + label + " replays real cast/strike/two foe turns, receipts, state and RNG exactly")


func _test_scarlet_knot_rejections() -> void:
	for tier in [1, 2, 3]:
		var label := "Scarlet Knot tier %d" % tier
		var miss: Dictionary = {}
		for seed_value in range(1, 256):
			var candidate := _scarlet_trial(seed_value, tier)
			if not candidate.is_empty() and not bool(candidate["receipt"]["results"][0].get("hit", true)):
				miss = candidate
				break
		_check(not miss.is_empty(), "AC3: a bounded natural " + label + " miss exists")
		if miss.is_empty():
			continue
		var result: Dictionary = miss["receipt"]["results"][0]
		var battle: StitchedRules = miss["battle"]
		var foe := battle.get_unit("fray_scavenger")
		_check(result.has("roll") and result.has("hit_chance")
			and int(result["roll"]) > int(result["hit_chance"]),
			"AC3: " + label + " miss comes from a genuine failed roll")
		_check(not _has_status(result.get("statuses", []), "bleed")
			and not _has_status(result.get("statuses", []), "weak")
			and not foe["statuses"].has("bleed") and not foe["statuses"].has("weak")
			and int(foe["hp"]) == int(miss["before_foe"]["hp"]),
			"AC3: " + label + " miss inflicts no Bleed, Weak or HP loss")
		var repeat := _scarlet_trial(int(miss["seed"]), tier)
		_check(not repeat.is_empty() and repeat["receipt"] == miss["receipt"]
			and repeat["before"] == miss["before"] and repeat["rng_before"] == miss["rng_before"]
			and repeat["after_cast"] == miss["after_cast"] and repeat["rng_after_cast"] == miss["rng_after_cast"],
			"AC3: " + label + " miss replays receipt, complete state and RNG")
	var kit := STARTER_PARTS.duplicate(true)
	kit["head"] = "seamstress_scarlet_knot_hat"
	var illegal := _build_battle(17, 1, kit)
	if illegal == null:
		return
	_check(illegal.current_actor_id() == "seamstress"
		and int(illegal.get_unit("seamstress")["rank"]) == 2,
		"AC3: an equipped Scarlet Knot starts a legal rank-2 caster turn")
	var before := illegal.state_snapshot()
	var rng_before := illegal.rng_state()
	for rank in [0, 4, 5]:
		_check(not bool(illegal.use_part("seamstress_scarlet_knot_hat", rank).get("ok", false)),
			"AC3: Scarlet Knot refuses illegal or unreachable foe rank %d" % rank)
	_check(not bool(illegal.use_part("seamstress_mending_knot_hat", 1).get("ok", false)),
		"AC3: the unequipped Mending Knot cannot be cast with Scarlet Knot worn")
	_check(before == illegal.state_snapshot() and rng_before == illegal.rng_state()
		and illegal.current_actor_id() == "seamstress",
		"AC3: all illegal Scarlet actions preserve full state, caster turn and RNG")


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


## Tether Loop retains Tangled through the foe's next real turn-start.
func _tether_loop_witness() -> void:
	var witness := _snare_witness("seamstress_tether_loop_spools", 1, true)
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
	_check(int(battle.get_unit("fray_scavenger")["statuses"].get("tangled", 0)) == 2,
		"AC1: a landed tier-I Tether Loop leaves Tangled 2 on the foe")
	_check(_has_status(result.get("statuses", []), "tangled"), "AC2: the receipt reports the applied Tangled status")
	_check(int(battle.get_unit("fray_scavenger")["hp"]) == int(battle.get_unit("fray_scavenger")["max_hp"]),
		"AC2: Tether Loop itself deals no damage")
	_check(_to(battle, "fray_scavenger"), "AC2: the Tangled foe reaches its own seeded turn")
	_check(int(battle.get_unit("fray_scavenger")["statuses"].get("tangled", 0)) == 1,
		"AC1: Tangled 2 falls to 1 at the foe's next actual turn-start")
	var pass_result := battle.pass_turn()
	_check(bool(pass_result.get("ok", false)), "AC1: the affected foe spends its own turn")
	if bool(pass_result.get("ok", false)):
		_check(_to(battle, "fray_scavenger"), "AC1: the same foe reaches its following actual turn")
		_check(battle.current_actor_id() == "fray_scavenger"
			and not battle.get_unit("fray_scavenger")["statuses"].has("tangled"),
			"AC1: the following foe turn-start fully expires Tether Loop Tangled")


## Real snare turns: tick-down happens at each target's start, not at cast time.
## All trials equip the selected legs part in the four-hero preview and pass only
## through the public battle actions on actual scheduled turns.
func _snare_trial(part_id: String, tier: int, seed_value: int) -> Dictionary:
	var kit := STARTER_PARTS.duplicate(true)
	kit["legs"] = part_id
	var battle := _build_battle(seed_value, tier, kit, false)
	if battle == null or battle.get_heroes().size() != 4 or battle.get_foes().size() != 3:
		return {}
	if not _to(battle, "seamstress"):
		return {}
	var wearer := battle.get_unit("seamstress")
	var foe := battle.get_unit("fray_scavenger")
	if int(wearer.get("rank", 0)) != 2 or _worn_part_id(wearer, part_id) != part_id:
		return {}
	if int(foe.get("rank", 0)) != 1 or int(foe.get("hp", 0)) <= 0:
		return {}
	if foe["statuses"].has("tangled") or foe["statuses"].has("mark"):
		return {}
	var before := battle.state_snapshot()
	var rng_before := battle.rng_state()
	var receipt := battle.use_part(part_id, 1)
	var results: Array = receipt.get("results", [])
	if not bool(receipt.get("ok", false)) or results.size() != 1:
		return {}
	if str(receipt.get("actor", "")) != "seamstress" or str(receipt.get("part", "")) != part_id:
		return {}
	var result: Dictionary = results[0]
	if str(result.get("target", "")) != "fray_scavenger" or str(result.get("target_side", "")) != "foe":
		return {}
	return {
		"battle": battle, "receipt": receipt, "seed": seed_value,
		"before": before, "rng_before": rng_before,
		"before_foe": foe,
	}


func _snare_witness(part_id: String, tier: int, want_hit: bool) -> Dictionary:
	var expected_tangled := 3 if part_id == "seamstress_tether_loop_spools" and tier == 3 else 2
	for seed_value in range(1, 200):
		var trial := _snare_trial(part_id, tier, seed_value)
		if trial.is_empty():
			continue
		var hit: bool = bool(trial["receipt"]["results"][0].get("hit", false))
		if hit != want_hit:
			continue
		var candidate_battle: StitchedRules = trial["battle"]
		var foe: Dictionary = candidate_battle.get_unit("fray_scavenger")
		# Select a witness that has not already entered the target's next turn.
		if hit and int(foe["statuses"].get("tangled", 0)) != expected_tangled:
			continue
		if not hit and (foe["statuses"].has("tangled") or foe["statuses"].has("mark")):
			continue
		return trial
	return {}


func _test_snare_timelines() -> void:
	for part_id in ["seamstress_tether_loop_spools", "seamstress_bobbin_snag_spools"]:
		for tier in [1, 2, 3]:
			var label := "%s tier %d" % [part_id, tier]
			var expected_tangled := 3 if part_id == "seamstress_tether_loop_spools" and tier == 3 else 2
			var expected_mark: int = (maxi(2, tier) if part_id == "seamstress_bobbin_snag_spools" else 0)
			var witness := _snare_witness(part_id, tier, true)
			_check(not witness.is_empty(), "AC1/2: a real seeded four-hero battle lands " + label)
			if witness.is_empty():
				continue
			var battle: StitchedRules = witness["battle"]
			var receipt: Dictionary = witness["receipt"]
			var result: Dictionary = receipt["results"][0]
			var foe_before: Dictionary = witness["before_foe"]
			var foe := battle.get_unit("fray_scavenger")
			_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 3
				and int(battle.get_unit("seamstress")["rank"]) == 2
				and _worn_part_id(battle.get_unit("seamstress"), part_id) == part_id
				and int(foe["rank"]) == 1 and int(foe_before["hp"]) > 0,
				"AC1/2: " + label + " uses its legally equipped rank-2 actor and living rank-1 foe")
			_check(bool(result.get("hit", false)) and result.has("roll") and result.has("hit_chance")
				and int(result["roll"]) <= int(result["hit_chance"])
				and str(receipt.get("ability", "")) == ("bobbin_snag" if expected_mark > 0 else "tether_loop")
				and str(result["target"]) == "fray_scavenger" and str(result["target_side"]) == "foe",
				"AC1/2: " + label + " has a real seeded hit roll, action and foe-side receipt")
			_check(_status_duration(result.get("statuses", []), "tangled") == expected_tangled
				and int(foe["statuses"].get("tangled", 0)) == expected_tangled,
				"AC1/2: " + label + " receipts and applies Tangled " + str(expected_tangled))
			_check(int(foe["hp"]) == int(foe_before["hp"]) and int(result.get("damage", -1)) == 0,
				"AC1/2: " + label + " is a nondamaging snare")
			if expected_mark > 0:
				_check(_status_duration(result.get("statuses", []), "mark") == expected_mark
					and int(foe["statuses"].get("mark", 0)) == expected_mark,
					"AC2: " + label + " receipts and applies Mark " + str(expected_mark))
			else:
				_check(not foe["statuses"].has("mark") and not _has_status(result.get("statuses", []), "mark"),
					"AC1: Tether Loop applies no Mark")
			_check(witness["before"] != battle.state_snapshot()
				and battle.current_actor_id() != "seamstress",
				"AC3: " + label + " spends exactly the caster's real turn")
			var replay := _snare_trial(part_id, tier, int(witness["seed"]))
			_check(not replay.is_empty() and replay["receipt"] == receipt
				and replay["before"] == witness["before"]
				and replay["rng_before"] == witness["rng_before"]
				and replay["battle"].state_snapshot() == battle.state_snapshot()
				and replay["battle"].rng_state() == battle.rng_state(),
				"AC3: " + label + " replays its seeded hit, complete state and RNG")
			var reached := _to(battle, "fray_scavenger")
			_check(reached and battle.current_actor_id() == "fray_scavenger",
				"AC1/2: " + label + " reaches the targeted foe's actual next turn")
			if not reached:
				continue
			_check(int(battle.get_unit("fray_scavenger")["statuses"].get("tangled", 0))
				== expected_tangled - 1,
				"AC1/2: " + label + " survives its first foe turn-start after exactly one tick")
			var passed := battle.pass_turn()
			_check(bool(passed.get("ok", false)), "AC1/2: " + label + " passes the affected foe turn")
			if not bool(passed.get("ok", false)):
				continue
			var following := _to(battle, "fray_scavenger")
			_check(following and battle.current_actor_id() == "fray_scavenger",
				"AC1/2: " + label + " reaches the same foe's following turn")
			if following:
				_check(int(battle.get_unit("fray_scavenger")["statuses"].get("tangled", 0))
					== expected_tangled - 2,
					"AC1/2: " + label + " ticks again and expires after turn two for Tangled 2")
			if not replay.is_empty():
				var replay_battle: StitchedRules = replay["battle"]
				var replay_reached := _to(replay_battle, "fray_scavenger")
				var replay_passed := replay_battle.pass_turn() if replay_reached else {}
				var replay_following := _to(replay_battle, "fray_scavenger") if bool(replay_passed.get("ok", false)) else false
				_check(replay_reached and bool(replay_passed.get("ok", false)) and replay_following
					and replay_battle.state_snapshot() == battle.state_snapshot()
					and replay_battle.rng_state() == battle.rng_state(),
					"AC3: " + label + " replays the same two natural foe turns and RNG")
	# Every Bobbin tier must also have a genuine miss that cannot apply either status.
	for tier in [1, 2, 3]:
		var label := "Bobbin Snag tier %d miss" % tier
		var miss := _snare_witness("seamstress_bobbin_snag_spools", tier, false)
		_check(not miss.is_empty(), "AC2: a seeded natural " + label + " occurs")
		if miss.is_empty():
			continue
		var battle: StitchedRules = miss["battle"]
		var receipt: Dictionary = miss["receipt"]
		var result: Dictionary = receipt["results"][0]
		var foe := battle.get_unit("fray_scavenger")
		_check(bool(receipt.get("ok", false)) and not bool(result.get("hit", true))
			and result.has("roll") and result.has("hit_chance")
			and int(result["roll"]) > int(result["hit_chance"]),
			"AC2: " + label + " is an actual failed seeded hit roll")
		_check(not foe["statuses"].has("mark") and not foe["statuses"].has("tangled")
			and not _has_status(result.get("statuses", []), "mark")
			and not _has_status(result.get("statuses", []), "tangled")
			and int(foe["hp"]) == int(miss["before_foe"]["hp"]),
			"AC2: " + label + " applies neither effect nor damage")
		var replay := _snare_trial("seamstress_bobbin_snag_spools", tier, int(miss["seed"]))
		_check(not replay.is_empty() and replay["receipt"] == receipt
			and replay["battle"].state_snapshot() == battle.state_snapshot()
			and replay["battle"].rng_state() == battle.rng_state(),
			"AC3: " + label + " replays its miss, state and RNG")
		var reached := _to(battle, "fray_scavenger")
		_check(reached and not battle.get_unit("fray_scavenger")["statuses"].has("tangled")
			and not battle.get_unit("fray_scavenger")["statuses"].has("mark"),
			"AC2: " + label + " leaves its next natural foe turn unmarked and untangled")


func _test_snare_rejections() -> void:
	var kit := STARTER_PARTS.duplicate(true)
	kit["legs"] = "seamstress_bobbin_snag_spools"
	for tier in [1, 2, 3]:
		var battle := _build_battle(17, tier, kit)
		if battle == null:
			continue
		_check(_to(battle, "seamstress"), "AC3: equipped Bobbin Snag reaches its natural caster turn")
		var before := battle.state_snapshot()
		var rng := battle.rng_state()
		var turn := battle.current_actor_id()
		for rank in [0, 4, 5]:
			var refused := battle.use_part("seamstress_bobbin_snag_spools", rank)
			_check(not bool(refused.get("ok", false))
				and battle.state_snapshot() == before and battle.rng_state() == rng
				and battle.current_actor_id() == turn,
				"AC3: tier %d Bobbin refuses invalid/ally-only rank %d without spending state or RNG" % [tier, rank])
		var unequipped := battle.use_part("seamstress_tether_loop_spools", 1)
		_check(not bool(unequipped.get("ok", false))
			and battle.state_snapshot() == before and battle.rng_state() == rng,
			"AC3: tier %d cannot cast the swapped-out Tether Loop" % tier)
		var starter := _build_battle(17, tier, STARTER_PARTS)
		if starter != null:
			var starter_before := starter.state_snapshot()
			var starter_rng := starter.rng_state()
			_check(not bool(starter.use_part("seamstress_bobbin_snag_spools", 1).get("ok", false))
				and starter.state_snapshot() == starter_before and starter.rng_state() == starter_rng,
				"AC3: tier %d cannot cast Bobbin Snag until it is equipped" % tier)
		var moved := _build_battle(23, tier, kit)
		if moved == null:
			continue
		var step := moved.move(-1)
		_check(bool(step.get("ok", false)) and int(moved.get_unit("seamstress")["rank"]) == 1,
			"AC3: tier %d Bobbin caster makes a real Move into the illegal launch rank 1" % tier)
		if not _to(moved, "seamstress"):
			_check(false, "AC3: moved Bobbin caster gets its next natural turn")
			continue
		var moved_before := moved.state_snapshot()
		var moved_rng := moved.rng_state()
		var rejected := moved.use_part("seamstress_bobbin_snag_spools", 1)
		_check(not bool(rejected.get("ok", false))
			and moved.state_snapshot() == moved_before and moved.rng_state() == moved_rng,
			"AC3: tier %d Bobbin rejects a rank-1 launch atomically" % tier)


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


## AC2: Bobbin's tier-I Mark lasts through its target's first natural turn start, so the
## real follow-up Needle Rain can still claim the existing +2 bonus. Both live battles wear
## the authentic alternative arms AND legs; only the control's already-ticked Mark is erased.
func _test_bobbin_needle_followup() -> void:
	var witness := _bobbin_needle_witness()
	_check(not witness.is_empty(),
		"AC2: bounded seeds produce landed tier-I Bobbin, foe turn-start, and three-hit Needle Rain")
	if witness.is_empty():
		return
	var marked: StitchedRules = witness["marked"]
	var clean: StitchedRules = witness["clean"]
	var bobbin: Dictionary = witness["bobbin"]
	var marked_rain: Dictionary = witness["marked_rain"]
	var clean_rain: Dictionary = witness["clean_rain"]
	_check(marked.get_heroes().size() == 4 and marked.get_foes().size() == 3
		and clean.get_heroes().size() == 4 and clean.get_foes().size() == 3,
		"AC2: both seeded battles retain four real heroes and three real foes")
	_check(_worn_part_id(marked.get_unit("seamstress"), "seamstress_bobbin_snag_spools")
			== "seamstress_bobbin_snag_spools"
		and _worn_part_id(marked.get_unit("seamstress"), "seamstress_needle_rain_needle")
			== "seamstress_needle_rain_needle"
		and int(marked.get_unit("seamstress")["rank"]) == 2
		and int(marked.get_unit("moth_scribe")["rank"]) == 3
		and int(marked.get_unit("moth_scribe")["prot"]) == 0,
		"AC2: the real alternate arms/legs launch at ranks 2/3 against the unarmoured rank-3 foe")
	var snag_result: Dictionary = bobbin["results"][0]
	_check(bool(bobbin.get("ok", false)) and str(bobbin.get("ability", "")) == "bobbin_snag"
		and str(snag_result.get("target", "")) == "moth_scribe"
		and str(snag_result.get("target_side", "")) == "foe"
		and bool(snag_result.get("hit", false)) and snag_result.has("roll")
		and int(snag_result["roll"]) <= int(snag_result["hit_chance"])
		and _status_duration(snag_result.get("statuses", []), "mark") == 2
		and _status_duration(snag_result.get("statuses", []), "tangled") == 2,
		"AC2: real tier-I Bobbin receipts its landed Mark 2 and Tangled 2")
	_check(int(witness["first_mark"]) == 1 and int(witness["first_tangled"]) == 1
		and int(witness["pre_rain_mark"]) == 1 and int(witness["pre_rain_clean"]) == 0,
		"AC2: its actual first foe start ticks Mark 2 to 1; only the control loses Mark")
	_check(bool(marked_rain.get("ok", false)) and bool(clean_rain.get("ok", false))
		and str(marked_rain.get("ability", "")) == "needle_rain"
		and str(clean_rain.get("ability", "")) == "needle_rain"
		and str(marked_rain.get("part", "")) == "seamstress_needle_rain_needle"
		and str(clean_rain.get("part", "")) == "seamstress_needle_rain_needle"
		and marked_rain["results"].size() == 3 and clean_rain["results"].size() == 3,
		"AC2: both legal multi-target showers spend a real Seamstress turn and receipt all foes")
	var results := _results_by_target(marked_rain, clean_rain)
	_check(results.size() == 3 and results.has("moth_scribe")
		and results.has("fray_scavenger") and results.has("scissor_crab"),
		"AC2: both showers resolve each of the three shipped foes exactly once")
	if results.size() != 3:
		return
	for target in results:
		var both: Dictionary = results[target]
		var extra: Dictionary = both["marked"]
		var baseline: Dictionary = both["clean"]
		_check(bool(extra.get("hit", false)) and bool(baseline.get("hit", false))
			and bool(extra.get("crit", false)) == bool(baseline.get("crit", false)),
			"AC2: both same-seed copies land the same Needle Rain hit and crit on " + str(target))
		_check(_status_duration(extra.get("statuses", []), "bleed") == 3
			and _status_duration(baseline.get("statuses", []), "bleed") == 3,
			"AC2: both showers apply the original tier-I Bleed 3 on " + str(target))
		if str(target) == "moth_scribe":
			_check(int(extra["damage"]) == int(baseline["damage"]) + 2
				and int(extra["target_hp"]) == int(baseline["target_hp"]) - 2
				and int(marked.get_unit(str(target))["hp"])
					== int(clean.get_unit(str(target))["hp"]) - 2,
				"AC2: Mark 1 after the foe tick causes exactly +2 direct Needle Rain damage and HP loss")
			_check(extra.get("statuses", []) == baseline.get("statuses", [])
				and int(marked.get_unit(str(target))["statuses"].get("mark", 0)) == 1
				and not clean.get_unit(str(target))["statuses"].has("mark"),
				"AC2: Needle Rain applies identical Bleed, neither refreshes nor consumes Bobbin Mark")
		else:
			_check(extra == baseline
				and marked.get_unit(str(target)) == clean.get_unit(str(target)),
				"AC2: unmarked " + str(target) + " has identical entire receipt and outcome")
	_check(marked.rng_state() == clean.rng_state()
		and marked.current_actor_id() == clean.current_actor_id()
		and marked.current_actor_id() != "seamstress",
		"AC2: the Mark-only control consumes identical RNG and exactly one real shower turn")
	var second_marked := _to(marked, "moth_scribe")
	var second_clean := _to(clean, "moth_scribe")
	_check(second_marked and second_clean
		and marked.current_actor_id() == "moth_scribe"
		and clean.current_actor_id() == "moth_scribe"
		and not marked.get_unit("moth_scribe")["statuses"].has("mark")
		and not clean.get_unit("moth_scribe")["statuses"].has("mark"),
		"AC2: with no reapplication, Bobbin Mark expires on the foe's second natural start")
	_check(marked.rng_state() == clean.rng_state(),
		"AC2: advancing to expiry does not diverge same-seed RNG")
	var replay := _bobbin_needle_at(int(witness["seed"]))
	_check(not replay.is_empty()
		and replay["bobbin"] == bobbin
		and replay["clean_rain"] == clean_rain
		and replay["marked_rain"] == marked_rain,
		"AC3: the same seed reproduces both real Bobbin and Needle Rain receipts")
	if not replay.is_empty():
		var replay_marked: StitchedRules = replay["marked"]
		var replay_clean: StitchedRules = replay["clean"]
		var replay_ticked := _to(replay_marked, "moth_scribe") and _to(replay_clean, "moth_scribe")
		_check(replay_ticked
			and replay_marked.state_snapshot() == marked.state_snapshot()
			and replay_clean.state_snapshot() == clean.state_snapshot()
			and replay_marked.rng_state() == marked.rng_state()
			and replay_clean.rng_state() == clean.rng_state(),
			"AC3: both paired combats replay all turns, expiry, complete state and RNG")


func _bobbin_needle_witness() -> Dictionary:
	for seed_value in range(1, 200):
		var pair := _bobbin_needle_at(seed_value)
		if pair.is_empty():
			continue
		var results := _results_by_target(pair["marked_rain"], pair["clean_rain"])
		if results.size() != 3:
			continue
		var all_landed := true
		for target in results:
			if not bool(results[target]["marked"].get("hit", false)) \
					or not bool(results[target]["clean"].get("hit", false)):
				all_landed = false
				break
		if all_landed:
			return pair
	return {}


## Natural turn-start and legal use_part actions are identical in both copies. Clearing only
## Mark AFTER its first foe tick isolates the +2 bonus without touching RNG or protection.
func _bobbin_needle_at(seed_value: int) -> Dictionary:
	var kit := NEEDLE_KIT.duplicate(true)
	kit["legs"] = "seamstress_bobbin_snag_spools"
	var marked := _build_battle(seed_value, 1, kit, false)
	var clean := _build_battle(seed_value, 1, kit, false)
	if marked == null or clean == null or marked.state_snapshot() != clean.state_snapshot():
		return {}
	if not _to(marked, "seamstress") or not _to(clean, "seamstress"):
		return {}
	if marked.state_snapshot() != clean.state_snapshot() or marked.rng_state() != clean.rng_state():
		return {}
	if marked.get_foes().size() != 3 or marked.get_heroes().size() != 4:
		return {}
	if _worn_part_id(marked.get_unit("seamstress"), "seamstress_needle_rain_needle") \
			!= "seamstress_needle_rain_needle":
		return {}
	if _worn_part_id(marked.get_unit("seamstress"), "seamstress_bobbin_snag_spools") \
			!= "seamstress_bobbin_snag_spools":
		return {}
	if int(marked.get_unit("seamstress")["rank"]) != 2 \
			or int(marked.get_unit("moth_scribe")["rank"]) != 3 \
			or int(marked.get_unit("moth_scribe")["prot"]) != 0:
		return {}
	var bobbin := marked.use_part("seamstress_bobbin_snag_spools", 3)
	var bobbin_control := clean.use_part("seamstress_bobbin_snag_spools", 3)
	if bobbin != bobbin_control or not bool(bobbin.get("ok", false)) \
			or bobbin.get("results", []).size() != 1 \
			or not bool(bobbin["results"][0].get("hit", false)):
		return {}
	if int(marked.get_unit("moth_scribe")["statuses"].get("mark", 0)) != 2 \
			or int(clean.get_unit("moth_scribe")["statuses"].get("mark", 0)) != 2 \
			or int(marked.get_unit("moth_scribe")["statuses"].get("tangled", 0)) != 2:
		return {}
	if not _to(marked, "moth_scribe") or not _to(clean, "moth_scribe"):
		return {}
	var first_mark := int(marked.get_unit("moth_scribe")["statuses"].get("mark", 0))
	var first_tangled := int(marked.get_unit("moth_scribe")["statuses"].get("tangled", 0))
	if first_mark != 1 or first_tangled != 1 \
			or first_mark != int(clean.get_unit("moth_scribe")["statuses"].get("mark", 0)) \
			or marked.state_snapshot() != clean.state_snapshot() \
			or marked.rng_state() != clean.rng_state():
		return {}
	clean._units["moth_scribe"]["statuses"].erase("mark")
	if not _to(marked, "seamstress") or not _to(clean, "seamstress"):
		return {}
	var pre_rain_mark := int(marked.get_unit("moth_scribe")["statuses"].get("mark", 0))
	var pre_rain_clean := int(clean.get_unit("moth_scribe")["statuses"].get("mark", 0))
	if pre_rain_mark != 1 or pre_rain_clean != 0 \
			or marked.rng_state() != clean.rng_state():
		return {}
	if marked.get_unit("moth_scribe")["hp"] != clean.get_unit("moth_scribe")["hp"] \
			or marked.get_unit("moth_scribe")["statuses"].get("tangled", 0) \
				!= clean.get_unit("moth_scribe")["statuses"].get("tangled", 0):
		return {}
	for other_id in ["fray_scavenger", "scissor_crab"]:
		if marked.get_unit(other_id) != clean.get_unit(other_id):
			return {}
	var marked_rain := marked.use_part("seamstress_needle_rain_needle", 1)
	var clean_rain := clean.use_part("seamstress_needle_rain_needle", 1)
	if not bool(marked_rain.get("ok", false)) or not bool(clean_rain.get("ok", false)) \
			or marked_rain.get("results", []).size() != 3 \
			or clean_rain.get("results", []).size() != 3:
		return {}
	var results := _results_by_target(marked_rain, clean_rain)
	if results.size() != 3 or not results.has("moth_scribe"):
		return {}
	var marked_hit: Dictionary = results["moth_scribe"]["marked"]
	var clean_hit: Dictionary = results["moth_scribe"]["clean"]
	if not bool(marked_hit.get("hit", false)) or not bool(clean_hit.get("hit", false)) \
			or int(marked_hit["damage"]) != int(clean_hit["damage"]) + 2 \
			or int(marked_hit["target_hp"]) != int(clean_hit["target_hp"]) - 2 \
			or marked.rng_state() != clean.rng_state() \
			or not _shower_unticked(marked, marked_rain["results"]) \
			or not _shower_unticked(clean, clean_rain["results"]):
		return {}
	for other_id in ["fray_scavenger", "scissor_crab"]:
		if not results.has(other_id) \
				or results[other_id]["marked"] != results[other_id]["clean"] \
				or marked.get_unit(other_id) != clean.get_unit(other_id):
			return {}
	return {
		"seed": seed_value, "marked": marked, "clean": clean,
		"bobbin": bobbin, "marked_rain": marked_rain, "clean_rain": clean_rain,
		"first_mark": first_mark, "first_tangled": first_tangled,
		"pre_rain_mark": pre_rain_mark, "pre_rain_clean": pre_rain_clean,
	}


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
	# S14 sewn-cloth copy: the head patch describes cloth, never a cast or a rank reach.
	_check(str(catalog["by_id"][MENDING_KNOT_ID]["text"]) == EXPECTED_MENDING_KNOT_TEXT,
		"AC1: the Mending Knot description is the authored sewn-cloth sentence, not a cast promise")
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


func _raw_index_of(raw_parts: Variant, part_id: String) -> int:
	if not raw_parts is Array:
		return -1
	for index in range(raw_parts.size()):
		var entry: Variant = raw_parts[index]
		if entry is Dictionary and str(entry.get("id", "")) == part_id:
			return index
	return -1


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


# ---------------------------------------------- AC1-AC4: tier-III Tether Loop rear-rank reach

## Tier contract plus real battle witnesses for the one reach this slice adds: at stitch tier III
## the equipped Tether Loop may snare the existing foe standing in enemy rank 4, while tiers I/II
## stay on enemy ranks 1-3 and every refusal is atomic.
func _test_rear_tether_reach() -> void:
	_test_tether_reach_contract()
	_test_rear_tether_hit()
	_test_rear_tether_rejections()
	_test_rear_tether_miss()


## The authored and tier-resolved contract of the named legs part: only tier III adds rank 4.
func _test_tether_reach_contract() -> void:
	var catalog := _catalog()
	_check(bool(catalog.get("ok", false)),
		"AC1: the Seamstress catalog loads for the Tether Loop reach contract")
	if not bool(catalog.get("ok", false)):
		return
	var by_id: Dictionary = catalog["by_id"]
	_check(by_id.has(TETHER_LOOP_PART), "AC1: the catalog authors " + TETHER_LOOP_PART)
	if not by_id.has(TETHER_LOOP_PART):
		return
	var part: Dictionary = by_id[TETHER_LOOP_PART]
	_check(str(part["slot"]) == "legs" and str(part["owner"]) == OWNER,
		"AC1: Tether Loop Spools stays the Seamstress's legs part")
	_check(_int_dict(part["stat"]) == {"speed": 1},
		"AC1: the authored Tether Loop Spools stat stays SPEED 1")
	var base_ability: Dictionary = part["ability"]
	_check(_int_list(base_ability["launch"]) == [2, 3] and _int_list(base_ability["target"]) == [1, 2, 3],
		"AC1: the base Tether Loop record keeps launch 2-3 and target ranks 1-3")
	# Tiers I and II: front ranks only, unchanged numbers, no rank-4 mask bit.
	for tier in [1, 2]:
		var ability := StitchedParts.ability_at_tier(part, tier)
		var tag := "tier %d" % tier
		_check(_int_list(ability["target"]) == [1, 2, 3],
			"AC1: " + tag + " Tether Loop still targets only enemy ranks 1-3")
		_check(not StitchedParts.ranks_allowed(int(ability["target_mask"]), MAX_RANK),
			"AC1: " + tag + " Tether Loop has no rank-4 target bit")
		_check(int(ability["target_mask"]) == StitchedParts.rank_mask([1, 2, 3]),
			"AC1: " + tag + " Tether Loop derives its target mask from ranks 1-3")
		_check(StitchedParts.ranks_allowed(int(ability["launch_mask"]), 2)
			and StitchedParts.ranks_allowed(int(ability["launch_mask"]), 3)
			and not StitchedParts.ranks_allowed(int(ability["launch_mask"]), 1)
			and not StitchedParts.ranks_allowed(int(ability["launch_mask"]), MAX_RANK),
			"AC1: " + tag + " Tether Loop keeps the hero launch ranks 2-3")
		_check(int(ability["acc"]) == 90 and _int_list(ability["dmg"]) == [0, 0]
			and not bool(ability["multi"]) and str(ability["target_side"]) == "enemy"
			and str(ability["move"]) == "skill",
			"AC1: " + tag + " Tether Loop keeps ACC 90, zero damage, one enemy target and the skill pose")
		_check(int(ability["effects"].get("tangled", 0)) == 2,
			"AC1: " + tag + " Tether Loop applies Tangled 2")
		_check(int(StitchedParts.stat_at_tier(part, tier).get("speed", 0)) == tier,
			"AC1: " + tag + " Tether Loop Spools grants SPEED " + str(tier))
	# Tier III: the one added reach, with its own derived mask.
	var third := StitchedParts.ability_at_tier(part, 3)
	_check(_int_list(third["target"]) == [1, 2, 3, 4],
		"AC1: tier-III Tether Loop targets enemy ranks 1-4")
	_check(int(third["target_mask"]) == StitchedParts.rank_mask([1, 2, 3, 4])
		and StitchedParts.ranks_allowed(int(third["target_mask"]), MAX_RANK),
		"AC1: tier-III Tether Loop derives a target mask with the rank-4 bit set")
	for rank in [1, 2, 3]:
		_check(StitchedParts.ranks_allowed(int(third["target_mask"]), rank),
			"AC1: tier-III Tether Loop still targets enemy rank %d" % rank)
	for rank in [0, 5]:
		_check(not StitchedParts.ranks_allowed(int(third["target_mask"]), rank),
			"AC1: tier-III Tether Loop never targets rank %d" % rank)
	_check(_int_list(third["launch"]) == [2, 3] and int(third["acc"]) == 90
		and _int_list(third["dmg"]) == [0, 0] and not bool(third["multi"])
		and str(third["target_side"]) == "enemy" and str(third["move"]) == "skill"
		and int(third["effects"].get("tangled", 0)) == 3
		and int(StitchedParts.stat_at_tier(part, 3).get("speed", 0)) == 3,
		"AC1: tier-III Tether Loop keeps launch 2-3, ACC 90, zero damage, Tangled 3 and SPEED 3")
	# The authored override is narrow: only tier III authors a target array.
	var raw: Variant = _read_json(PARTS_PATH)
	if raw is Dictionary:
		var document: Dictionary = raw
		var raw_parts: Variant = document.get("parts", [])
		var raw_part := _raw_part_for(raw_parts, TETHER_LOOP_PART)
		_check(not raw_part.is_empty(), "AC1: the raw JSON authors the Tether Loop Spools record")
		if not raw_part.is_empty():
			var raw_base: Dictionary = raw_part.get("ability", {})
			_check(_int_list(raw_base.get("launch")) == [2, 3]
				and _int_list(raw_base.get("target")) == [1, 2, 3],
				"AC1: the authored base Tether Loop record stays launch 2-3 / target ranks 1-3")
			var raw_tiers: Dictionary = raw_part.get("tiers", {})
			var raw_tier_two: Dictionary = raw_tiers.get("2", {})
			var raw_tier_three: Dictionary = raw_tiers.get("3", {})
			var raw_two_ability: Dictionary = raw_tier_two.get("ability", {})
			var raw_three_ability: Dictionary = raw_tier_three.get("ability", {})
			_check(not raw_two_ability.has("target"),
				"AC1: tier-II authors no target override, so it keeps enemy ranks 1-3")
			_check(int(raw_two_ability.get("effects", {}).get("tangled", 0)) == 2,
				"AC1: the authored tier-II effects override stays Tangled 2")
			_check(_int_list(raw_three_ability.get("target")) == [1, 2, 3, 4],
				"AC1: the authored tier-III target override is the one rank-4 reach")
			_check(int(raw_three_ability.get("effects", {}).get("tangled", 0)) == 3,
				"AC1: the authored tier-III effects override is Tangled 3")
			_check(not raw_three_ability.has("launch") and not raw_three_ability.has("acc")
				and not raw_three_ability.has("dmg") and not raw_three_ability.has("move"),
				"AC1: the tier-III override touches no launch, ACC, damage or pose")
			_check(not raw_three_ability.has("target_mask"),
				"AC1: the authored tier-III override never hard-codes a derived mask")
	# The legs row now prints sewn-cloth appearance copy instead of a retired snare instruction.
	# The tier-III rank-4 reach stays proven above by the ability numbers and masks, and in real
	# combat by the rear-Tether hit/miss/rejection witnesses below.
	var text := str(part["text"])
	_check(text == EXPECTED_TETHER_SPOOLS_TEXT,
		"AC1: the Tether Loop text is the S14 sewn-cloth patch sentence")
	_check(not text.contains("Tangled 1"),
		"AC1: the Tether Loop text claims no obsolete Tangled 1")
	_check(text == text.strip_edges() and not text.is_empty(),
		"AC1: the Tether Loop text stays nonempty trimmed rules text")
	_check(_leg_copy_violation(text.to_lower()).is_empty(),
		"AC1: the Tether Loop text promises no rank/tier/status/action or digit")
	# The seven sibling records keep their exact tier-resolved target ranks and text.
	for other_id in ALL_PART_IDS:
		if other_id == TETHER_LOOP_PART:
			continue
		for tier in [1, 2, 3]:
			_check(_int_list(StitchedParts.ability_at_tier(by_id[other_id], tier)["target"])
				== _int_list(EXPECTED[other_id]["target"]),
				"AC1: %s tier %d keeps its authored target ranks" % [other_id, tier])
		_check(str(by_id[other_id]["text"]) == str(by_id[other_id]["text"]).strip_edges()
			and not str(by_id[other_id]["text"]).is_empty(),
			"AC1: the sibling " + other_id + " keeps nonempty rules text")


## Builds the detached four-hero/three-foe fixture with the existing moth_scribe moved into enemy
## rank 4 (rank 3 vacant) and attempts one real Tether Loop at enemy rank 4 on the Seamstress's
## own rank-2 turn. Everything before the cast is captured for atomic-refusal comparisons.
func _rear_tether_at(seed_value: int, tier: int, kit: Dictionary = STARTER_PARTS) -> Dictionary:
	var battle := _build_battle(seed_value, tier, kit, false, true)
	if battle == null:
		return {}
	if not _to(battle, "seamstress"):
		return {}
	var wearer := battle.get_unit("seamstress")
	if int(wearer["rank"]) != 2:
		return {}
	if _worn_part_id(wearer, TETHER_LOOP_PART) != TETHER_LOOP_PART:
		return {}
	if int(wearer["parts"]["legs"]["tier"]) != tier:
		return {}
	var rear := battle.get_unit("moth_scribe")
	if rear.is_empty() or int(rear["rank"]) != MAX_RANK or int(rear["hp"]) <= 0:
		return {}
	if not _no_foe_at(battle, 3):
		return {}
	var before := battle.state_snapshot()
	var rng_before := battle.rng_state()
	var foes_before: Dictionary = {}
	for foe in battle.get_foes():
		foes_before[str(foe["id"])] = foe.duplicate(true)
	var ally_before := battle.get_unit("lantern_monk")
	var receipt := battle.use_part(TETHER_LOOP_PART, MAX_RANK)
	return {
		"battle": battle, "receipt": receipt, "seed": seed_value,
		"before": before, "rng_before": rng_before,
		"foes_before": foes_before, "ally_before": ally_before,
	}


## A bounded fixed-seed scan for a genuine landed tier-III snare on the relocated rank-4 foe.
func _rear_tether_hit_witness() -> Dictionary:
	for seed_value in range(1, 300):
		var trial := _rear_tether_at(seed_value, 3)
		if trial.is_empty():
			continue
		var receipt: Dictionary = trial["receipt"]
		var results: Array = receipt.get("results", [])
		if not bool(receipt.get("ok", false)) or results.size() != 1:
			continue
		var result: Dictionary = results[0]
		if not bool(result.get("hit", false)):
			continue
		if str(result.get("target", "")) != "moth_scribe" \
				or int(result.get("target_rank", 0)) != MAX_RANK:
			continue
		var battle: StitchedRules = trial["battle"]
		if int(battle.get_unit("moth_scribe")["statuses"].get("tangled", 0)) != 3:
			continue
		return trial
	return {}


## The real AC2 witness: a landed tier-III snare on the rank-4 foe, its first natural turn-start
## tick to Tangled 2, its remaining natural ticks to expiry, and an exact equal-seed replay.
func _test_rear_tether_hit() -> void:
	var witness := _rear_tether_hit_witness()
	_check(not witness.is_empty(),
		"AC2: a fixed seed lands a real tier-III Tether Loop on the enemy rank-4 moth_scribe")
	if witness.is_empty():
		return
	var battle: StitchedRules = witness["battle"]
	var receipt: Dictionary = witness["receipt"]
	var result: Dictionary = receipt["results"][0]
	var foes_before: Dictionary = witness["foes_before"]
	var before: Dictionary = witness["before"]
	# Real preconditions: a genuine 4v3 fight, a legally equipped rank-2 caster and a living rear foe.
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 3,
		"AC2: the rear reach is proven in a genuine four-hero / three-foe battle")
	_check(_worn_part_id(battle.get_unit("seamstress"), TETHER_LOOP_PART) == TETHER_LOOP_PART
		and int(battle.get_unit("seamstress")["rank"]) == 2,
		"AC2: the equipped, untorn Tether Loop acts from the legal rank-2 hero seat")
	_check(int(battle.get_unit("moth_scribe")["rank"]) == MAX_RANK and int(battle.get_unit("moth_scribe")["hp"]) > 0,
		"AC2: the existing moth_scribe really stands alive in enemy rank 4")
	_check(_no_foe_at(battle, 3),
		"AC2: enemy rank 3 is vacant, so rank 4 is the only rear target")
	# The action receipt itself.
	_check(bool(receipt.get("ok", false)),
		"AC2: the tier-III rank-4 use_part call is an accepted real action")
	_check(str(receipt.get("action", "")) == "ability"
		and str(receipt.get("actor", "")) == "seamstress"
		and str(receipt.get("part", "")) == TETHER_LOOP_PART
		and str(receipt.get("ability", "")) == "tether_loop",
		"AC2: the receipt names the Seamstress's equipped tier-III tether_loop action")
	_check(receipt["results"].size() == 1
		and str(result.get("target", "")) == "moth_scribe"
		and str(result.get("target_side", "")) == "foe"
		and int(result.get("target_rank", 0)) == MAX_RANK,
		"AC2: the receipt resolves exactly one enemy result on the rank-4 moth_scribe")
	_check(bool(result.get("hit", false)) and result.has("roll") and result.has("hit_chance")
		and int(result["roll"]) <= int(result["hit_chance"]),
		"AC2: the snare is a genuine seeded hit roll, not a forced hit")
	# Tangled 3 only on the target; no damage; the other foes and the allied rear hero untouched.
	_check(_status_duration(result.get("statuses", []), "tangled") == 3,
		"AC2: the receipt reports Tangled 3")
	_check(int(battle.get_unit("moth_scribe")["statuses"].get("tangled", 0)) == 3,
		"AC2: the rank-4 moth_scribe really carries Tangled 3 after the hit")
	_check(int(result.get("damage", -1)) == 0
		and int(result.get("target_hp", -1)) == int(foes_before["moth_scribe"]["hp"]),
		"AC2: the snare deals no damage to the rank-4 foe")
	for foe_id in foes_before:
		if str(foe_id) == "moth_scribe":
			continue
		var foe_after := battle.get_unit(str(foe_id))
		var foe_before: Dictionary = foes_before[foe_id]
		_check(int(foe_after["hp"]) == int(foe_before["hp"])
			and foe_after["statuses"] == foe_before["statuses"],
			"AC2: the other foe " + str(foe_id) + " keeps its HP and statuses")
	var ally_after := battle.get_unit("lantern_monk")
	var ally_before: Dictionary = witness["ally_before"]
	_check(ally_after == ally_before,
		"AC2: the allied lantern_monk in hero rank 4 is untouched by the enemy-side snare")
	_check(battle.current_actor_id() != "seamstress" and before != battle.state_snapshot(),
		"AC2: the accepted snare spends exactly the Seamstress's own turn")
	# Same seed, same kit and same legal sequence: identical receipt, state, order and RNG.
	var replay := _rear_tether_at(int(witness["seed"]), 3)
	_check(not replay.is_empty()
		and replay["receipt"] == receipt
		and replay["before"] == before
		and replay["rng_before"] == witness["rng_before"]
		and replay["battle"].state_snapshot() == battle.state_snapshot()
		and replay["battle"].rng_state() == battle.rng_state()
		and replay["battle"].turn_order() == battle.turn_order(),
		"AC4: the same seed replays the identical rank-4 receipt, foe statuses, turn order and RNG")
	# The foe's own scheduled turn start ticks Tangled 3 -> 2, then the remaining natural ticks expire it.
	var reached := _to(battle, "moth_scribe")
	_check(reached and battle.current_actor_id() == "moth_scribe",
		"AC2: the snarled rank-4 foe reaches its own naturally scheduled turn")
	if not reached:
		return
	_check(int(battle.get_unit("moth_scribe")["statuses"].get("tangled", 0)) == 2,
		"AC2: its first actual turn-start reduces Tangled 3 to 2")
	_check(int(battle.get_unit("moth_scribe")["hp"]) == int(foes_before["moth_scribe"]["hp"]),
		"AC2: the tick still deals no damage")
	var expected_tick := 1
	for tick in range(2):
		var passed := battle.pass_turn()
		_check(bool(passed.get("ok", false)),
			"AC2: the snarled foe spends its real turn for tick %d" % expected_tick)
		if not bool(passed.get("ok", false)):
			return
		var following := _to(battle, "moth_scribe")
		_check(following and battle.current_actor_id() == "moth_scribe",
			"AC2: the same foe reaches its following scheduled turn for tick %d" % expected_tick)
		if not following:
			return
		var live := battle.get_unit("moth_scribe")
		if int(live["hp"]) <= 0 or bool(live["dead"]):
			_check(false, "AC2: the rank-4 foe must survive its natural ticks")
			return
		var tangled := int(live["statuses"].get("tangled", 0))
		_check(tangled == expected_tick,
			"AC2: the foe's natural turn-start ticks Tangled down to %d" % expected_tick)
		expected_tick -= 1
	_check(not battle.get_unit("moth_scribe")["statuses"].has("tangled"),
		"AC2: the tier-III Tangled 3 expires after its third natural foe turn-start")


## Every illegal tier-III rank-4 cast and the early-tier rank-4 refusal are atomic, and a legal
## tier-III miss still spends the turn.
func _test_rear_tether_rejections() -> void:
	# Tiers I and II against the same occupied enemy rank 4.
	for tier in [1, 2]:
		var battle := _build_battle(37, tier, STARTER_PARTS, false, true)
		_check(battle != null, "AC3: the relocated fixture builds for tier-%d Tether Loop" % tier)
		if battle == null:
			continue
		_check(_to(battle, "seamstress") and int(battle.get_unit("seamstress")["rank"]) == 2,
			"AC3: tier-%d Tether Loop reaches a real rank-2 caster turn" % tier)
		_check(int(battle.get_unit("moth_scribe")["rank"]) == MAX_RANK
			and not _no_foe_at(battle, MAX_RANK),
			"AC3: enemy rank 4 really holds the living moth_scribe for the tier-%d refusal" % tier)
		var before := battle.state_snapshot()
		var rng := battle.rng_state()
		var actor := battle.current_actor_id()
		var refused := battle.use_part(TETHER_LOOP_PART, MAX_RANK)
		_check(not bool(refused.get("ok", false))
			and str(refused.get("error", "")).contains("no legal target in rank 4"),
			"AC3: tier-%d Tether Loop refuses the occupied enemy rank 4" % tier)
		_check(before == battle.state_snapshot() and rng == battle.rng_state()
			and actor == battle.current_actor_id(),
			"AC3: the tier-%d rank-4 refusal spends no state, turn or RNG" % tier)
		_check(not battle.get_unit("moth_scribe")["statuses"].has("tangled"),
			"AC3: the tier-%d rank-4 refusal leaves the rear foe untangled" % tier)
		# The untouched turn still casts the legal front-rank snare.
		var legal := battle.use_part(TETHER_LOOP_PART, 1)
		var legal_results: Array = legal.get("results", [])
		_check(bool(legal.get("ok", false)) and legal_results.size() == 1
			and int(legal_results[0].get("target_rank", -1)) == 1,
			"AC3: after the tier-%d refusal the same turn still acts on enemy rank 1" % tier)
	# Tier III: the vacant enemy rank 3 and the out-of-range ranks stay atomic.
	var battle := _build_battle(41, 3, STARTER_PARTS, false, true)
	_check(battle != null, "AC3: the relocated fixture builds for the tier-III negatives")
	if battle != null:
		_check(_to(battle, "seamstress"), "AC3: the tier-III caster reaches her own real turn")
		var before := battle.state_snapshot()
		var rng := battle.rng_state()
		var actor := battle.current_actor_id()
		for bad_rank in [3, 0, 5]:
			var refused := battle.use_part(TETHER_LOOP_PART, bad_rank)
			_check(not bool(refused.get("ok", false))
				and str(refused.get("error", "")).contains("no legal target in rank %d" % bad_rank),
				"AC3: tier-III Tether Loop refuses the illegal or vacant rank %d" % bad_rank)
			_check(before == battle.state_snapshot() and rng == battle.rng_state()
				and actor == battle.current_actor_id(),
				"AC3: the tier-III rank-%d refusal preserved snapshot, actor and RNG" % bad_rank)
		_check(not battle.get_unit("moth_scribe")["statuses"].has("tangled")
			and not battle.get_unit("fray_scavenger")["statuses"].has("tangled"),
			"AC3: the tier-III illegal ranks applied no Tangled anywhere")
		# Ally-side misuse: in the shipped layout enemy rank 4 is empty and the allied hero stands there.
		var shipped := _build_battle(41, 3, STARTER_PARTS, false, false)
		_check(shipped != null, "AC3: the shipped three-foe layout builds for the ally-side refusal")
		if shipped != null and _to(shipped, "seamstress"):
			var ally_before := shipped.get_unit("lantern_monk")
			_check(int(ally_before["rank"]) == MAX_RANK and _no_foe_at(shipped, MAX_RANK),
				"AC3: the ally-side witness has the lantern_monk in hero rank 4 and no foe there")
			var shipped_state := shipped.state_snapshot()
			var shipped_rng := shipped.rng_state()
			var ally_refused := shipped.use_part(TETHER_LOOP_PART, MAX_RANK)
			_check(not bool(ally_refused.get("ok", false))
				and str(ally_refused.get("error", "")).contains("no legal target in rank 4"),
				"AC3: tier-III Tether Loop never reaches across the side boundary to the allied rank 4")
			_check(shipped_state == shipped.state_snapshot() and shipped_rng == shipped.rng_state()
				and shipped.current_actor_id() == "seamstress"
				and shipped.get_unit("lantern_monk") == ally_before,
				"AC3: the ally-side refusal spends nothing and leaves the ally untouched")
		else:
			_check(false, "AC3: the ally-side witness reaches a real Seamstress turn")
		# Unequipped: the alternative Bobbin Snag legs grant no Tether Loop action.
		var other_kit := STARTER_PARTS.duplicate(true)
		other_kit["legs"] = "seamstress_bobbin_snag_spools"
		var unequipped := _build_battle(43, 3, other_kit, false, true)
		_check(unequipped != null, "AC3: the relocated fixture builds with the other legs part")
		if unequipped != null and _to(unequipped, "seamstress"):
			var unequipped_state := unequipped.state_snapshot()
			var unequipped_rng := unequipped.rng_state()
			var refused := unequipped.use_part(TETHER_LOOP_PART, MAX_RANK)
			_check(not bool(refused.get("ok", false))
				and str(refused.get("error", "")).contains("not equipped"),
				"AC3: an unequipped Tether Loop is refused at the rear rank")
			_check(unequipped_state == unequipped.state_snapshot()
				and unequipped_rng == unequipped.rng_state()
				and unequipped.current_actor_id() == "seamstress",
				"AC3: the unequipped refusal spends no state, turn or RNG")
		# Torn: the same worn descriptor refuses its ability through the real equipment path.
		var torn_kit := STARTER_PARTS.duplicate(true)
		torn_kit["legs"] = {"id": TETHER_LOOP_PART, "tier": 3, "torn": true}
		var torn := _build_battle(43, 3, torn_kit, false, true)
		_check(torn != null, "AC3: the relocated fixture builds with a torn legs descriptor")
		if torn != null:
			_check(bool(torn.get_unit("seamstress")["parts"]["legs"]["torn"]),
				"AC3: the torn witness really wears the torn Tether Loop")
			if _to(torn, "seamstress"):
				var torn_state := torn.state_snapshot()
				var torn_rng := torn.rng_state()
				var refused := torn.use_part(TETHER_LOOP_PART, MAX_RANK)
				_check(not bool(refused.get("ok", false))
					and str(refused.get("error", "")).contains("torn"),
					"AC3: a torn Tether Loop is refused at the rear rank")
				_check(torn_state == torn.state_snapshot() and torn_rng == torn.rng_state()
					and torn.current_actor_id() == "seamstress",
					"AC3: the torn refusal spends no state, turn or RNG")
		# Wrong launch: after a real Move into hero rank 1, the rear cast fails before any roll.
		var moved := _build_battle(47, 3, STARTER_PARTS, false, true)
		if moved != null and _to(moved, "seamstress"):
			var step := moved.move(-1)
			_check(bool(step.get("ok", false)) and int(moved.get_unit("seamstress")["rank"]) == 1,
				"AC3: a real Move puts the tier-III Seamstress into the illegal launch rank 1")
			if _to(moved, "seamstress"):
				var moved_state := moved.state_snapshot()
				var moved_rng := moved.rng_state()
				var refused := moved.use_part(TETHER_LOOP_PART, MAX_RANK)
				_check(not bool(refused.get("ok", false))
					and str(refused.get("error", "")).contains("cannot launch from rank 1"),
					"AC3: tier-III Tether Loop refuses the rear cast from launch rank 1")
				_check(moved_state == moved.state_snapshot() and moved_rng == moved.rng_state()
					and moved.current_actor_id() == "seamstress",
					"AC3: the wrong-launch refusal spends no state, turn or RNG")
			else:
				_check(false, "AC3: the moved tier-III Seamstress reaches her next real turn")
		else:
			_check(false, "AC3: the wrong-launch witness reaches the Seamstress's real turn")
	# Off-turn: after a real use the wearer cannot act during a foe turn.
	var off := _build_battle(53, 3, STARTER_PARTS, false, true)
	if off != null and _to(off, "seamstress"):
		var legal_cast := off.use_part(TETHER_LOOP_PART, MAX_RANK)
		_check(bool(legal_cast.get("ok", false)),
			"AC3: the off-turn witness first spends a real legal tier-III snare")
		_check(_to_side(off, "foe"), "AC3: a real foe turn follows the legal snare")
		if off.current_side() == "foe":
			var off_state := off.state_snapshot()
			var off_rng := off.rng_state()
			var actor := off.current_actor_id()
			var refused := off.use_part(TETHER_LOOP_PART, MAX_RANK)
			_check(not bool(refused.get("ok", false))
				and str(refused.get("error", "")).contains("not a hero turn"),
				"AC3: the tier-III rear snare is refused off-turn")
			_check(off_state == off.state_snapshot() and off_rng == off.rng_state()
				and actor == off.current_actor_id(),
				"AC3: the off-turn refusal spends no state, turn or RNG")
	else:
		_check(false, "AC3: the off-turn witness reaches the Seamstress's real turn")


## A bounded fixed-seed scan for a genuine tier-III miss at enemy rank 4: the legal attempt spends
## the turn but never tangles any foe.
func _rear_tether_miss_witness() -> Dictionary:
	for seed_value in range(1, 400):
		var trial := _rear_tether_at(seed_value, 3)
		if trial.is_empty():
			continue
		var receipt: Dictionary = trial["receipt"]
		var results: Array = receipt.get("results", [])
		if not bool(receipt.get("ok", false)) or results.size() != 1:
			continue
		var result: Dictionary = results[0]
		if bool(result.get("hit", true)):
			continue
		if str(result.get("target", "")) != "moth_scribe":
			continue
		var battle: StitchedRules = trial["battle"]
		var tangled := false
		for foe in battle.get_foes():
			if foe["statuses"].has("tangled"):
				tangled = true
		if tangled:
			continue
		return trial
	return {}


## AC3: a real tier-III miss at the rear rank spends the turn but applies no Tangled or damage.
func _test_rear_tether_miss() -> void:
	var witness := _rear_tether_miss_witness()
	_check(not witness.is_empty(),
		"AC3: a fixed seed produces a genuine tier-III Tether Loop miss on the rank-4 foe")
	if witness.is_empty():
		return
	var battle: StitchedRules = witness["battle"]
	var receipt: Dictionary = witness["receipt"]
	var result: Dictionary = receipt["results"][0]
	var before: Dictionary = witness["before"]
	_check(bool(receipt.get("ok", false))
		and str(result.get("target", "")) == "moth_scribe"
		and int(result.get("target_rank", 0)) == MAX_RANK,
		"AC3: the miss is a legal real action aimed at the rank-4 moth_scribe")
	_check(not bool(result.get("hit", true)) and result.has("roll") and result.has("hit_chance")
		and int(result["roll"]) > int(result["hit_chance"]),
		"AC3: the miss is an actual failed seeded hit roll, not a rejected helper")
	_check(int(result.get("damage", -1)) == 0
		and not _has_status(result.get("statuses", []), "tangled"),
		"AC3: the missed snare reports no damage and no Tangled")
	for foe in battle.get_foes():
		_check(not foe["statuses"].has("tangled"),
			"AC3: the miss leaves " + str(foe["id"]) + " untangled")
	var rear := battle.get_unit("moth_scribe")
	_check(int(rear["hp"]) == int(witness["foes_before"]["moth_scribe"]["hp"])
		and int(result.get("target_hp", -1)) == int(rear["hp"]),
		"AC3: the missed rear snare leaves the moth_scribe's HP untouched")
	_check(battle.current_actor_id() != "seamstress" and before != battle.state_snapshot(),
		"AC3: the legal miss still spends exactly the Seamstress's turn")
	var replay := _rear_tether_at(int(witness["seed"]), 3)
	_check(not replay.is_empty()
		and replay["receipt"] == receipt
		and replay["battle"].state_snapshot() == battle.state_snapshot()
		and replay["battle"].rng_state() == battle.rng_state(),
		"AC4: the same seed replays the identical rear-rank miss, state and RNG")


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


## Lowercase words and numbers only, so hyphenated cloth words such as "cross-stitches" split
## cleanly and whole-word exclusions cannot pass or fail by accident on a substring.
func _copy_tokens(text: String) -> Array[String]:
	var tokens: Array[String] = []
	var current := ""
	for index in range(text.length()):
		var ch := text.substr(index, 1)
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			current += ch
		elif not current.is_empty():
			tokens.append(current)
			current = ""
	if not current.is_empty():
		tokens.append(current)
	return tokens


func _contains_whole_word(text: String, word: String) -> bool:
	return word in _copy_tokens(text)


func _contains_digit(text: String) -> bool:
	for token in _copy_tokens(text):
		for index in range(token.length()):
			var ch := token.substr(index, 1)
			if ch >= "0" and ch <= "9":
				return true
	return false


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
		var worn: Variant = kit[slot]
		# A plain part id wears it at the requested tier; a dictionary lets one witness wear a
		# deliberately torn descriptor through the same validated equipment path.
		if worn is Dictionary:
			seamstress["parts"][slot] = worn.duplicate(true)
		else:
			seamstress["parts"][slot] = {"id": str(worn), "tier": tier}
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
