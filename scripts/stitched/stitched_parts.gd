class_name StitchedParts
extends RefCounted
## Scene-free data rules for Design v4 "Stitched" body parts (STITCHED_DESIGN.md section 4).
##
## One part entry is authored as plain JSON/dictionary data:
##   {"id", "name", "slot": "head|arms|torso|legs", "owner": "<hero_id>|any",
##    "stat": {"acc"|"crit"|"dmg"|"max_hp"|"prot"|"speed"|"dodge": n},
##    "ability": {"id", "name", "kind", "launch": [ranks], "target": [ranks],
##                "target_side": "enemy|ally|self", "multi", "acc", "dmg": [min, max],
##                "crit", "mark_damage", "effects": {...}, "self_move", "move"},
##    "tiers": {"2": {...overrides...}, "3": {...overrides...}}, "text"}
##
## Every entry is validated before a battle can use it, and validation fails closed with a
## readable error. Owner is informational only: STITCHED_DESIGN.md lets any hero wear a
## foreign part, so a part's slot is the only hard equipment constraint.
## Ranks are authored as 1..4 lists and are also exposed as bit masks (bit N = rank N) so
## the rules core can answer launch/target legality with one integer test.
## Nothing here reads a scene, rolls randomness or mutates state.

const SLOTS := ["head", "arms", "torso", "legs"]
const STAT_KEYS := ["acc", "crit", "dmg", "max_hp", "prot", "speed", "dodge"]
const ABILITY_KINDS := ["melee", "ranged", "heal", "guard", "buff", "debuff", "move"]
const TARGET_SIDES := ["enemy", "ally", "self"]
const EFFECT_KEYS := [
	"bleed", "weak", "exposed", "tangled", "stun", "mark", "thorns", "riposte", "blind",
	"guard", "heal", "fray", "snip", "push", "pull", "tear", "dodge", "duration", "rot",
]
const MOVE_POSES := ["attack", "attack2", "attack3", "attack4", "guard", "skill"]
const MIN_TIER := 1
const MAX_TIER := 3
const MIN_RANK := 1
const MAX_RANK := 4
const ALL_RANKS_MASK := 0b11110  # bits 1-4
const MAX_ACCURACY := 100
const MAX_TEMP_DODGE := 100
const MAX_DODGE_TURNS := 8
const PART_FIELDS := ["id", "name", "slot", "owner", "stat", "ability", "tiers", "text"]
const ABILITY_FIELDS := [
	"id", "name", "kind", "launch", "target", "target_side", "multi", "acc", "dmg",
	"crit", "mark_damage", "effects", "self_move", "move",
]
## Derived rank masks: validate_ability always recomputes them, so a catalog that already
## passed validation (and therefore carries masks) can be validated again unchanged.
const DERIVED_ABILITY_FIELDS := ["launch_mask", "target_mask"]
const SLOT_STATS := {
	"head": ["acc", "crit"],
	"arms": ["dmg"],
	"torso": ["max_hp", "prot"],
	"legs": ["speed", "dodge"],
}


## Reads one authored parts file ({"parts": [...]}) and validates the whole catalog.
## A missing, unreadable or malformed file fails closed; it never returns partial data.
static func load_catalog(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return _catalog_error("missing parts file: " + path)
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		return _catalog_error("empty parts file: " + path)
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		return _catalog_error("parts file is not a JSON object: " + path)
	if not parsed.has("parts"):
		return _catalog_error("parts file has no parts array: " + path)
	return build_catalog(parsed["parts"])


## Validates every part in the array. Duplicate ids are refused, and the returned
## "by_id" index is the only lookup the battle rules use.
static func build_catalog(entries: Variant) -> Dictionary:
	if not entries is Array:
		return _catalog_error("parts catalog is not an array")
	if entries.is_empty():
		return _catalog_error("parts catalog is empty")
	var parts: Array = []
	var by_id: Dictionary = {}
	for index in range(entries.size()):
		var result := validate_part(entries[index], "part %d" % index)
		if not result["ok"]:
			return _catalog_error(str(result["error"]))
		var part: Dictionary = result["part"]
		var id := str(part["id"])
		if by_id.has(id):
			return _catalog_error("duplicate part id: " + id)
		by_id[id] = part
		parts.append(part)
	return {"ok": true, "error": "", "parts": parts, "by_id": by_id}


## One part entry, fully validated and normalised (ints for every number, masks for ranks).
static func validate_part(entry: Variant, label: String = "part") -> Dictionary:
	if not entry is Dictionary:
		return _part_error(label + " is not a dictionary")
	for field in entry:
		if not field is String or not field in PART_FIELDS:
			return _part_error(label + " has an unknown field: " + str(field))
	var id := _valid_text(entry.get("id"))
	if id.is_empty():
		return _part_error(label + " needs a nonempty id")
	var name := _valid_text(entry.get("name"))
	if name.is_empty():
		return _part_error("part " + id + " needs a nonempty name")
	var slot := _valid_text(entry.get("slot"))
	if not slot in SLOTS:
		return _part_error("part " + id + " has an illegal slot: " + str(entry.get("slot")))
	var owner := _valid_text(entry.get("owner"))
	if owner.is_empty():
		return _part_error("part " + id + " needs an owner id or any")
	var stat_result := _validate_stat(entry.get("stat", {}), slot, "part " + id)
	if not stat_result["ok"]:
		return _part_error(str(stat_result["error"]))
	var ability_result := validate_ability(entry.get("ability"), "part " + id + " ability")
	if not ability_result["ok"]:
		return _part_error(str(ability_result["error"]))
	var tiers_result := _validate_tiers(
		entry.get("tiers", {}), slot, ability_result["ability"], "part " + id
	)
	if not tiers_result["ok"]:
		return _part_error(str(tiers_result["error"]))
	var text := _valid_text(entry.get("text"))
	if text.is_empty():
		return _part_error("part " + id + " needs rules text")
	return {
		"ok": true,
		"error": "",
		"part": {
			"id": id,
			"name": name,
			"slot": slot,
			"owner": owner,
			"stat": stat_result["stat"],
			"ability": ability_result["ability"],
			"tiers": tiers_result["tiers"],
			"text": text,
		},
	}


## One ability (a part's ability or an enemy action), validated and normalised.
## "launch_mask" and "target_mask" are derived, never authored.
static func validate_ability(entry: Variant, label: String = "ability") -> Dictionary:
	if not entry is Dictionary:
		return _ability_error(label + " is not a dictionary")
	for field in entry:
		if not field is String:
			return _ability_error(label + " has an unknown field: " + str(field))
		if not field in ABILITY_FIELDS and not field in DERIVED_ABILITY_FIELDS:
			return _ability_error(label + " has an unknown field: " + str(field))
	var id := _valid_text(entry.get("id"))
	if id.is_empty():
		return _ability_error(label + " needs a nonempty id")
	var name := _valid_text(entry.get("name"))
	if name.is_empty():
		return _ability_error("ability " + id + " needs a nonempty name")
	var kind := _valid_text(entry.get("kind"))
	if not kind in ABILITY_KINDS:
		return _ability_error("ability " + id + " has an illegal kind: " + str(entry.get("kind")))
	var launch_result := _validate_ranks(entry.get("launch"), "ability " + id + " launch")
	if not launch_result["ok"]:
		return _ability_error(str(launch_result["error"]))
	var target_result := _validate_ranks(entry.get("target"), "ability " + id + " target")
	if not target_result["ok"]:
		return _ability_error(str(target_result["error"]))
	var side := _valid_text(entry.get("target_side"))
	if not side in TARGET_SIDES:
		return _ability_error(
			"ability " + id + " has an illegal target_side: " + str(entry.get("target_side"))
		)
	var multi: Variant = entry.get("multi", false)
	if not multi is bool:
		return _ability_error("ability " + id + " multi must be a boolean")
	var acc_value: Variant = entry.get("acc")
	if not _integral(acc_value) or int(acc_value) < 0 or int(acc_value) > MAX_ACCURACY:
		return _ability_error("ability " + id + " needs acc 0-%d" % MAX_ACCURACY)
	var dmg: Variant = entry.get("dmg")
	if not dmg is Array or dmg.size() != 2:
		return _ability_error("ability " + id + " needs a dmg [min, max] pair")
	if not _integral(dmg[0]) or not _integral(dmg[1]):
		return _ability_error("ability " + id + " dmg values must be integers")
	var minimum := int(dmg[0])
	var maximum := int(dmg[1])
	if minimum < 0 or maximum < minimum:
		return _ability_error("ability " + id + " needs 0 <= dmg min <= max")
	var crit: Variant = entry.get("crit", 0)
	if not _integral(crit) or int(crit) < 0:
		return _ability_error("ability " + id + " crit must be a nonnegative integer")
	var mark_damage: Variant = entry.get("mark_damage", 0)
	if not _integral(mark_damage) or int(mark_damage) < 0:
		return _ability_error("ability " + id + " mark_damage must be a nonnegative integer")
	var effects_result := _validate_effects(entry.get("effects", {}), "ability " + id)
	if not effects_result["ok"]:
		return _ability_error(str(effects_result["error"]))
	var self_move: Variant = entry.get("self_move", 0)
	if not _integral(self_move) or int(self_move) < -1 or int(self_move) > 1:
		return _ability_error("ability " + id + " self_move must be -1, 0 or 1")
	var pose: Variant = entry.get("move", "attack")
	if not pose is String or not pose in MOVE_POSES:
		return _ability_error("ability " + id + " has an unknown move pose: " + str(pose))
	return {
		"ok": true,
		"error": "",
		"ability": {
			"id": id,
			"name": name,
			"kind": kind,
			"launch": launch_result["ranks"],
			"launch_mask": int(launch_result["mask"]),
			"target": target_result["ranks"],
			"target_mask": int(target_result["mask"]),
			"target_side": side,
			"multi": bool(multi),
			"acc": int(acc_value),
			"dmg": [minimum, maximum],
			"crit": int(crit),
			"mark_damage": int(mark_damage),
			"effects": effects_result["effects"],
			"self_move": int(self_move),
			"move": pose,
		},
	}


## Bit mask of authored ranks (bit N set for rank N), or 0 when the list is malformed.
static func rank_mask(ranks: Variant) -> int:
	if not ranks is Array or ranks.is_empty():
		return 0
	var mask := 0
	for item in ranks:
		if not _integral(item):
			return 0
		var rank := int(item)
		if rank < MIN_RANK or rank > MAX_RANK:
			return 0
		var bit := 1 << rank
		if mask & bit:
			return 0
		mask |= bit
	return mask


static func ranks_allowed(mask: int, rank: int) -> bool:
	if rank < MIN_RANK or rank > MAX_RANK:
		return false
	return (mask & (1 << rank)) != 0


## The ability a part grants at a stitch tier. Tier 1 is the base ability; tiers 2 and 3
## override authored ability fields. Unknown tiers fall back to the base ability.
static func ability_at_tier(part: Dictionary, tier: int) -> Dictionary:
	if not part.has("ability"):
		return {}
	var ability: Dictionary = part["ability"].duplicate(true)
	var tiers: Dictionary = part.get("tiers", {})
	var key := str(tier)
	if tier <= MIN_TIER or not tiers.has(key):
		return ability
	var override: Dictionary = tiers[key]
	if not override.has("ability"):
		return ability
	var fields: Dictionary = override["ability"]
	for field in fields:
		var value: Variant = fields[field]
		if value is Array or value is Dictionary:
			ability[field] = value.duplicate(true)
		else:
			ability[field] = value
	return ability


## The stat a part grants at a stitch tier; tier overrides replace base values.
static func stat_at_tier(part: Dictionary, tier: int) -> Dictionary:
	var stat: Dictionary = part.get("stat", {}).duplicate(true)
	var tiers: Dictionary = part.get("tiers", {})
	var key := str(tier)
	if tier <= MIN_TIER or not tiers.has(key):
		return stat
	var override: Dictionary = tiers[key]
	if not override.has("stat"):
		return stat
	for field in override["stat"]:
		stat[field] = int(override["stat"][field])
	return stat


static func _validate_ranks(value: Variant, label: String) -> Dictionary:
	if not value is Array or value.is_empty():
		return {"ok": false, "error": label + " needs a nonempty rank array", "ranks": [], "mask": 0}
	var ranks: Array = []
	var mask := 0
	for item in value:
		if not _integral(item):
			return {"ok": false, "error": label + " ranks must be integers", "ranks": [], "mask": 0}
		var rank := int(item)
		if rank < MIN_RANK or rank > MAX_RANK:
			return {
				"ok": false,
				"error": label + " has an illegal rank %d" % rank,
				"ranks": [],
				"mask": 0,
			}
		var bit := 1 << rank
		if mask & bit:
			return {
				"ok": false,
				"error": label + " repeats rank %d" % rank,
				"ranks": [],
				"mask": 0,
			}
		mask |= bit
		ranks.append(rank)
	ranks.sort()
	return {"ok": true, "error": "", "ranks": ranks, "mask": mask}


static func _validate_stat(value: Variant, slot: String, label: String) -> Dictionary:
	if not value is Dictionary:
		return {"ok": false, "error": label + " stat is not a dictionary", "stat": {}}
	var allowed: Array = SLOT_STATS.get(slot, [])
	var stat: Dictionary = {}
	for key in value:
		if not key is String or not key in STAT_KEYS:
			return {"ok": false, "error": label + " has an unknown stat: " + str(key), "stat": {}}
		if not key in allowed:
			return {
				"ok": false,
				"error": "%s cannot grant %s in the %s slot" % [label, str(key), slot],
				"stat": {},
			}
		if not _integral(value[key]) or int(value[key]) < 0:
			return {
				"ok": false,
				"error": label + " stat " + str(key) + " must be a nonnegative integer",
				"stat": {},
			}
		stat[key] = int(value[key])
	return {"ok": true, "error": "", "stat": stat}


static func _validate_effects(value: Variant, label: String) -> Dictionary:
	if not value is Dictionary:
		return {"ok": false, "error": label + " effects are not a dictionary", "effects": {}}
	# Dodge has one bounded duration; neither half is a standalone status.
	if value.has("dodge") != value.has("duration"):
		return {"ok": false, "error": label + " dodge needs a matching duration", "effects": {}}
	var effects: Dictionary = {}
	for key in value:
		if not key is String or not key in EFFECT_KEYS:
			return {"ok": false, "error": label + " has an unknown effect: " + str(key), "effects": {}}
		if not _integral(value[key]) or int(value[key]) < 1:
			return {
				"ok": false,
				"error": label + " effect " + str(key) + " must be a positive integer",
				"effects": {},
			}
		if str(key) == "dodge" and int(value[key]) > MAX_TEMP_DODGE:
			return {"ok": false, "error": label + " dodge exceeds maximum", "effects": {}}
		if str(key) == "duration" and (int(value[key]) < 1 or int(value[key]) > MAX_DODGE_TURNS):
			return {"ok": false, "error": label + " duration must be 1-%d" % MAX_DODGE_TURNS, "effects": {}}
		if str(key) in ["snip", "tear", "push", "pull"] and int(value[key]) != 1:
			return {"ok": false, "error": label + " effect " + str(key) + " must be one step", "effects": {}}
		effects[key] = int(value[key])
	return {"ok": true, "error": "", "effects": effects}


static func _validate_tiers(
	value: Variant, slot: String, base_ability: Dictionary, label: String
) -> Dictionary:
	if not value is Dictionary:
		return {"ok": false, "error": label + " tiers are not a dictionary", "tiers": {}}
	var tiers: Dictionary = {}
	for key in value:
		if not key is String or not key in ["2", "3"]:
			return {
				"ok": false,
				"error": label + " has an illegal tier key: " + str(key),
				"tiers": {},
			}
		var override: Variant = value[key]
		if not override is Dictionary:
			return {"ok": false, "error": label + " tier " + str(key) + " is not a dictionary", "tiers": {}}
		var cleaned: Dictionary = {}
		for field in override:
			if not field is String or not field in ["ability", "stat", "text"]:
				return {
					"ok": false,
					"error": label + " tier " + str(key) + " has an unknown field: " + str(field),
					"tiers": {},
				}
		if override.has("ability"):
			if not override["ability"] is Dictionary:
				return {
					"ok": false,
					"error": label + " tier " + str(key) + " ability is not a dictionary",
					"tiers": {},
				}
			var raw: Dictionary = _raw_ability(base_ability)
			for field in override["ability"]:
				if field in StitchedParts.DERIVED_ABILITY_FIELDS:
					continue
				if not field is String or not field in raw:
					return {
						"ok": false,
						"error": label + " tier " + str(key) + " has an unknown ability field: "
							+ str(field),
						"tiers": {},
					}
				var field_value: Variant = override["ability"][field]
				if field_value is Array or field_value is Dictionary:
					raw[field] = field_value.duplicate(true)
				else:
					raw[field] = field_value
			var merged := validate_ability(raw, label + " tier " + str(key))
			if not merged["ok"]:
				return {"ok": false, "error": str(merged["error"]), "tiers": {}}
			cleaned["ability"] = merged["ability"]
		if override.has("stat"):
			var stat_result := _validate_stat(
				override["stat"], slot, label + " tier " + str(key)
			)
			if not stat_result["ok"]:
				return {"ok": false, "error": str(stat_result["error"]), "tiers": {}}
			cleaned["stat"] = stat_result["stat"]
		if override.has("text"):
			var text := _valid_text(override["text"])
			if text.is_empty():
				return {
					"ok": false,
					"error": label + " tier " + str(key) + " text must be nonempty",
					"tiers": {},
				}
			cleaned["text"] = text
		tiers[str(key)] = cleaned
	return {"ok": true, "error": "", "tiers": tiers}


static func _raw_ability(ability: Dictionary) -> Dictionary:
	var raw: Dictionary = ability.duplicate(true)
	raw.erase("launch_mask")
	raw.erase("target_mask")
	return raw


static func _integral(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value)


static func _valid_text(value: Variant) -> String:
	if typeof(value) != TYPE_STRING:
		return ""
	var text: String = value
	if text.is_empty() or text != text.strip_edges():
		return ""
	return text


static func _part_error(message: String) -> Dictionary:
	return {"ok": false, "error": message, "part": {}}


static func _ability_error(message: String) -> Dictionary:
	return {"ok": false, "error": message, "ability": {}}


static func _catalog_error(message: String) -> Dictionary:
	return {"ok": false, "error": message, "parts": [], "by_id": {}}
