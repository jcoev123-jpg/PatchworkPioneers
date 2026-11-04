extends SceneTree
## Design v4 S4-preparation data contract: the Seamstress's eight wearable Stitched parts.
##
## This test reads the new, independent res://data/parts/seamstress_parts.json catalog. The retired
## v3 card catalogs are stable read-only provenance for the numbers and are never imported here.
## It then loads the shipped S2 preview fixture into memory, appends the eight authored records,
## equips only the four starters on the existing seamstress hero and drives real StitchedRules
## turns. Nothing here wires the kit into the title screen, a live fight, rewards or a picker:
## this slice is data plus a seeded rules witness, so no player-facing path is claimed.

const PARTS_PATH := "res://data/parts/seamstress_parts.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const OWNER := "seamstress"
const SLOTS := ["head", "arms", "torso", "legs"]
const MOVE_POSES := ["attack", "attack2", "guard", "skill"]
const MIN_RANK := 1
const MAX_RANK := 4
const REQUIRED_ABILITY_FIELDS := [
	"id", "name", "kind", "launch", "target", "target_side", "multi", "acc", "dmg",
	"crit", "effects", "self_move", "move",
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

## The authored acceptance contract, one row per part id, indexed by tier - 1.
const EXPECTED := {
	"seamstress_mending_knot_hat": {
		"name": "Mending Knot Hat", "slot": "head", "stat_key": "acc", "stat": [2, 3, 4],
		"ability_id": "mending_knot", "ability_name": "Mending Knot", "kind": "heal",
		"launch": [2, 3], "target": [1, 2, 3, 4], "target_side": "ally", "pose": "skill",
		"acc": 100,
		"dmg": [[0, 0], [0, 0], [0, 0]],
		"effects": [{"heal": 4}, {"heal": 6}, {"heal": 8}],
	},
	"seamstress_scarlet_knot_hat": {
		"name": "Scarlet Knot Hat", "slot": "head", "stat_key": "crit", "stat": [2, 3, 4],
		"ability_id": "scarlet_knot", "ability_name": "Scarlet Knot", "kind": "debuff",
		"launch": [1, 2, 3], "target": [1, 2, 3], "target_side": "enemy", "pose": "skill",
		"acc": 90,
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
		"acc": 90,
		"dmg": [[2, 3], [3, 4], [4, 5]],
		"effects": [{"bleed": 2}, {"bleed": 3}, {"bleed": 4}],
	},
	"seamstress_needle_rain_needle": {
		"name": "Needle Rain Needle", "slot": "arms", "stat_key": "dmg", "stat": [1, 2, 3],
		"ability_id": "needle_rain", "ability_name": "Needle Rain", "kind": "ranged",
		"launch": [1, 2, 3], "target": [1, 2, 3], "target_side": "enemy", "pose": "attack2",
		"acc": 90,
		"dmg": [[1, 2], [2, 3], [3, 4]],
		"effects": [{"bleed": 3}, {"bleed": 4}, {"bleed": 5}],
	},
	"seamstress_shielding_hem_coat": {
		"name": "Shielding Hem Coat", "slot": "torso", "stat_key": "max_hp", "stat": [4, 6, 8],
		"ability_id": "shielding_hem", "ability_name": "Shielding Hem", "kind": "guard",
		"launch": [1, 2, 3], "target": [1, 2, 3, 4], "target_side": "ally", "pose": "guard",
		"acc": 100,
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
		"launch": [2, 3], "target": [1, 2, 3, 4], "target_side": "ally", "pose": "guard",
		"acc": 100,
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
		"acc": 90,
		"dmg": [[0, 0], [0, 0], [0, 0]],
		"effects": [{"tangled": 1}, {"tangled": 2}, {"tangled": 3}],
	},
	"seamstress_bobbin_snag_spools": {
		"name": "Bobbin Snag Spools", "slot": "legs", "stat_key": "dodge", "stat": [3, 4, 5],
		"ability_id": "bobbin_snag", "ability_name": "Bobbin Snag", "kind": "debuff",
		"launch": [2, 3], "target": [1, 2, 3], "target_side": "enemy", "pose": "skill",
		"acc": 90,
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
		_check(ability["multi"] is bool and not bool(ability["multi"]),
			"AC1: " + part_id + " single-targets one rank (multi is authored false)")
		_check(int(ability["crit"]) == 0, "AC1: " + part_id + " keeps crit 0 so the head ACC/crit stat is the only crit source")
		_check(int(ability["self_move"]) == 0, "AC1: " + part_id + " takes no unstated self move")
		_check(str(ability["move"]) in MOVE_POSES, "AC1: " + part_id + " uses an existing authored move pose")
		_check(str(ability["move"]) == str(spec["pose"]), "AC1: " + part_id + " uses its authored pose " + str(spec["pose"]))
		_check(str(ability["id"]) == str(spec["ability_id"]), "AC1: " + part_id + " grants the ability " + str(spec["ability_id"]))
		_check(str(ability["name"]) == str(spec["ability_name"]), "AC1: " + part_id + " names its ability " + str(spec["ability_name"]))
		_check(str(ability["kind"]) == str(spec["kind"]), "AC1: " + part_id + " uses the ability kind " + str(spec["kind"]))
		_check(str(ability["target_side"]) == str(spec["target_side"]), "AC1: " + part_id + " targets the " + str(spec["target_side"]) + " side")
		_check(int(ability["acc"]) == int(spec["acc"]), "AC1: " + part_id + " keeps its authored ACC")
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
	var raw: Variant = _read_json(PARTS_PATH)
	if raw is Dictionary:
		var document: Dictionary = raw
		_check(int(document.get("version", 0)) == 1, "AC1: the parts file keeps the version-1 schema")
		var raw_parts: Variant = document.get("parts")
		_check(raw_parts is Array and raw_parts.size() == ALL_PART_IDS.size(),
			"AC1: the authored parts array holds exactly the eight named wearables")
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
			_check(not bool(ability["multi"]), "AC3: " + tag + " stays single target")
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
		_check(_int_list(shipped["ability"]["launch"]) == [2, 3], "AC1: the shipped launch ranks are untouched")


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


func _build_battle(seed_value: int, tier: int = 1, kit: Dictionary = STARTER_PARTS,
		report: bool = true) -> StitchedRules:
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
	if report:
		_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 3,
			"AC2: the fixture keeps four heroes and three foes")
		_check(battle.current_actor_id() == "seamstress" and int(battle.get_unit("seamstress")["rank"]) == 2,
			"AC2: the Seamstress opens the round from rank 2")
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
